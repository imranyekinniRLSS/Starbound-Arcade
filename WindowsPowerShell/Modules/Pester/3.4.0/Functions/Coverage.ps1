if ($PSVersionTable.PSVersion.Major -le 2)
{
    function Exit-CoverageAnalysis { }
    function Get-CoverageReport { }
    function Show-CoverageReport { }
    function Enter-CoverageAnalysis {
        param ( $CodeCoverage )

        if ($CodeCoverage) { & $SafeCommands['Write-Error'] 'Code coverage analysis requires PowerShell 3.0 or later.' }
    }

    return
}

function Enter-CoverageAnalysis
{
    [CmdletBinding()]
    param (
        [object[]] $CodeCoverage,
        [object] $PesterState
    )

    $coverageInfo =
    foreach ($object in $CodeCoverage)
    {
        Get-CoverageInfoFromUserInput -InputObject $object
    }

    $PesterState.CommandCoverage = @(Get-CoverageBreakpoints -CoverageInfo $coverageInfo)
}

function Exit-CoverageAnalysis
{
    param ([object] $PesterState)

    & $SafeCommands['Set-StrictMode'] -Off

    $breakpoints = @($PesterState.CommandCoverage.Breakpoint) -ne $null
    if ($breakpoints.Count -gt 0)
    {
        & $SafeCommands['Remove-PSBreakpoint'] -Breakpoint $breakpoints
    }
}

function Get-CoverageInfoFromUserInput
{
    param (
        [Parameter(Mandatory = $true)]
        [object]
        $InputObject
    )

    if ($InputObject -is [System.Collections.IDictionary])
    {
        $unresolvedCoverageInfo = Get-CoverageInfoFromDictionary -Dictionary $InputObject
    }
    else
    {
        $unresolvedCoverageInfo = New-CoverageInfo -Path ([string]$InputObject)
    }

    Resolve-CoverageInfo -UnresolvedCoverageInfo $unresolvedCoverageInfo
}

function New-CoverageInfo
{
    param ([string] $Path, [string] $Function = $null, [int] $StartLine = 0, [int] $EndLine = 0)

    return [pscustomobject]@{
        Path = $Path
        Function = $Function
        StartLine = $StartLine
        EndLine = $EndLine
    }
}

function Get-CoverageInfoFromDictionary
{
    param ([System.Collections.IDictionary] $Dictionary)

    [string] $path = Get-DictionaryValueFromFirstKeyFound -Dictionary $Dictionary -Key 'Path', 'p'
    if ([string]::IsNullOrEmpty($path))
    {
        throw "Coverage value '$Dictionary' is missing required Path key."
    }

    $startLine = Get-DictionaryValueFromFirstKeyFound -Dictionary $Dictionary -Key 'StartLine', 'Start', 's'
    $endLine = Get-DictionaryValueFromFirstKeyFound -Dictionary $Dictionary -Key 'EndLine', 'End', 'e'
    [string] $function = Get-DictionaryValueFromFirstKeyFound -Dictionary $Dictionary -Key 'Function', 'f'

    $startLine = Convert-UnknownValueToInt -Value $startLine -DefaultValue 0
    $endLine = Convert-UnknownValueToInt -Value $endLine -DefaultValue 0

    return New-CoverageInfo -Path $path -StartLine $startLine -EndLine $endLine -Function $function
}

function Convert-UnknownValueToInt
{
    param ([object] $Value, [int] $DefaultValue = 0)

    try
    {
        return [int] $Value
    }
    catch
    {
        return $DefaultValue
    }
}

function Resolve-CoverageInfo
{
    param ([psobject] $UnresolvedCoverageInfo)

    $path = $UnresolvedCoverageInfo.Path

    try
    {
        $resolvedPaths = & $SafeCommands['Resolve-Path'] -Path $path -ErrorAction Stop
    }
    catch
    {
        & $SafeCommands['Write-Error'] "Could not resolve coverage path '$path': $($_.Exception.Message)"
        return
    }

    $filePaths =
    foreach ($resolvedPath in $resolvedPaths)
    {
        $item = & $SafeCommands['Get-Item'] -LiteralPath $resolvedPath
        if ($item -is [System.IO.FileInfo] -and ('.ps1','.psm1') -contains $item.Extension)
        {
            $item.FullName
        }
        elseif (-not $item.PsIsContainer)
        {
            & $SafeCommands['Write-Warning'] "CodeCoverage path '$path' resolved to a non-PowerShell file '$($item.FullName)'; this path will not be part of the coverage report."
        }
    }

    $params = @{
        StartLine = $UnresolvedCoverageInfo.StartLine
        EndLine = $UnresolvedCoverageInfo.EndLine
        Function = $UnresolvedCoverageInfo.Function
    }

    foreach ($filePath in $filePaths)
    {
        $params['Path'] = $filePath
        New-CoverageInfo @params
    }
}

function Get-CoverageBreakpoints
{
    [CmdletBinding()]
    param (
        [object[]] $CoverageInfo
    )

    $fileGroups = @($CoverageInfo | & $SafeCommands['Group-Object'] -Property Path)
    foreach ($fileGroup in $fileGroups)
    {
        & $SafeCommands['Write-Verbose'] "Initializing code coverage analysis for file '$($fileGroup.Name)'"
        $totalCommands = 0
        $analyzedCommands = 0

        :commandLoop
        foreach ($command in Get-CommandsInFile -Path $fileGroup.Name)
        {
            $totalCommands++

            foreach ($coverageInfoObject in $fileGroup.Group)
            {
                if (Test-CoverageOverlapsCommand -CoverageInfo $coverageInfoObject -Command $command)
                {
                    $analyzedCommands++
                    New-CoverageBreakpoint -Command $command
                    continue commandLoop
                }
            }
        }

        & $SafeCommands['Write-Verbose'] "Analyzing $analyzedCommands of $totalCommands commands in file '$($fileGroup.Name)' for code coverage"
    }
}

function Get-CommandsInFile
{
    param ([string] $Path)

    $errors = $null
    $tokens = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref] $tokens, [ref] $errors)

    if ($PSVersionTable.PSVersion.Major -ge 5)
    {
        # In PowerShell 5.0, dynamic keywords for DSC configurations are represented by the DynamicKeywordStatementAst
        # class.  They still trigger breakpoints, but are not a child class of CommandBaseAst anymore.

        $predicate = {
            $args[0] -is [System.Management.Automation.Language.DynamicKeywordStatementAst] -or
            $args[0] -is [System.Management.Automation.Language.CommandBaseAst]
        }
    }
    else
    {
        $predicate = { $args[0] -is [System.Management.Automation.Language.CommandBaseAst] }
    }

    $searchNestedScriptBlocks = $true
    $ast.FindAll($predicate, $searchNestedScriptBlocks)
}

function Test-CoverageOverlapsCommand
{
    param ([object] $CoverageInfo, [System.Management.Automation.Language.Ast] $Command)

    if ($CoverageInfo.Function)
    {
        Test-CommandInsideFunction -Command $Command -Function $CoverageInfo.Function
    }
    else
    {
        Test-CoverageOverlapsCommandByLineNumber @PSBoundParameters
    }

}

function Test-CommandInsideFunction
{
    param ([System.Management.Automation.Language.Ast] $Command, [string] $Function)

    for ($ast = $Command; $null -ne $ast; $ast = $ast.Parent)
    {
        $functionAst = $ast -as [System.Management.Automation.Language.FunctionDefinitionAst]
        if ($null -ne $functionAst -and $functionAst.Name -like $Function)
        {
            return $true
        }
    }

    return $false
}

function Test-CoverageOverlapsCommandByLineNumber
{
    param ([object] $CoverageInfo, [System.Management.Automation.Language.Ast] $Command)

    $commandStart = $Command.Extent.StartLineNumber
    $commandEnd = $Command.Extent.EndLineNumber
    $coverStart = $CoverageInfo.StartLine
    $coverEnd = $CoverageInfo.EndLine

    # An EndLine value of 0 means to cover the entire rest of the file from StartLine
    # (which may also be 0)
    if ($coverEnd -le 0) { $coverEnd = [int]::MaxValue }

    return (Test-RangeContainsValue -Value $commandStart -Min $coverStart -Max $coverEnd) -or
           (Test-RangeContainsValue -Value $commandEnd -Min $coverStart -Max $coverEnd)
}

function Test-RangeContainsValue
{
    param ([int] $Value, [int] $Min, [int] $Max)
    return $Value -ge $Min -and $Value -le $Max
}

function New-CoverageBreakpoint
{
    param ([System.Management.Automation.Language.Ast] $Command)

    if (IsIgnoredCommand -Command $Command) { return }

    $params = @{
        Script = $Command.Extent.File
        Line   = $Command.Extent.StartLineNumber
        Column = $Command.Extent.StartColumnNumber
        Action = { }
    }

    $breakpoint = & $SafeCommands['Set-PSBreakpoint'] @params

    [pscustomobject] @{
        File       = $Command.Extent.File
        Function   = Get-ParentFunctionName -Ast $Command
        Line       = $Command.Extent.StartLineNumber
        Command    = Get-CoverageCommandText -Ast $Command
        Breakpoint = $breakpoint
    }
}

function IsIgnoredCommand
{
    param ([System.Management.Automation.Language.Ast] $Command)

    if (-not $Command.Extent.File)
    {
        # This can happen if the script contains "configuration" or any similarly implemented
        # dynamic keyword.  PowerShell modifies the script code and reparses it in memory, leading
        # to AST elements with no File in their Extent.
        return $true
    }

    if ($PSVersionTable.PSVersion.Major -ge 4)
    {
        if ($Command.Extent.Text -eq 'Configuration')
        {
            # More DSC voodoo.  Calls to "configuration" generate breakpoints, but their HitCount
            # stays zero (even though they are executed.)  For now, ignore them, unless we can come
            # up with a better solution.
            return $true
        }

        if (IsChildOfHashtableDynamicKeyword -Command $Command)
        {
            # The lines inside DSC resource declarations don't trigger their breakpoints when executed,
            # just like the "configuration" keyword itself.  I don't know why, at this point, but just like
            # configuration, we'll ignore it so it doesn't clutter up the coverage analysis with useless junk.
            return $true
        }
    }

    if (IsClosingLoopCondition -Command $Command)
    {
        # For some reason, the closing expressions of do/while and do/until loops don't trigger their breakpoints.
        # To avoid useless clutter, we'll ignore those lines as well.
        return $true
    }

    return $false
}

function IsChildOfHashtableDynamicKeyword
{
    param ([System.Management.Automation.Language.Ast] $Command)

    for ($ast = $Command.Parent; $null -ne $ast; $ast = $ast.Parent)
    {
        if ($PSVersionTable.PSVersion.Major -ge 5)
        {
            # The ast behaves differently for DSC resources with version 5+.  There's a new DynamicKeywordStatementAst class,
            # and they no longer are represented by CommandAst objects.

            if ($ast -is [System.Management.Automation.Language.DynamicKeywordStatementAst] -and
                $ast.CommandElements[-1] -is [System.Management.Automation.Language.HashtableAst])
            {
                return $true
            }
        }
        else
        {
            if ($ast -is [System.Management.Automation.Language.CommandAst] -and
                $null -ne $ast.DefiningKeyword -and
                $ast.DefiningKeyword.BodyMode -eq [System.Management.Automation.Language.DynamicKeywordBodyMode]::Hashtable)
            {
                return $true
            }
        }
    }

    return $false
}

function IsClosingLoopCondition
{
    param ([System.Management.Automation.Language.Ast] $Command)

    $ast = $Command

    while ($null -ne $ast.Parent)
    {
        if (($ast.Parent -is [System.Management.Automation.Language.DoWhileStatementAst] -or
            $ast.Parent -is [System.Management.Automation.Language.DoUntilStatementAst]) -and
            $ast.Parent.Condition -eq $ast)
        {
            return $true
        }

        $ast = $ast.Parent
    }

    return $false
}

function Get-ParentFunctionName
{
    param ([System.Management.Automation.Language.Ast] $Ast)

    $parent = $Ast.Parent

    while ($null -ne $parent -and $parent -isnot [System.Management.Automation.Language.FunctionDefinitionAst])
    {
        $parent = $parent.Parent
    }

    if ($null -eq $parent)
    {
        return ''
    }
    else
    {
        return $parent.Name
    }
}

function Get-CoverageCommandText
{
    param ([System.Management.Automation.Language.Ast] $Ast)

    $reportParentExtentTypes = @(
        [System.Management.Automation.Language.ReturnStatementAst]
        [System.Management.Automation.Language.ThrowStatementAst]
        [System.Management.Automation.Language.AssignmentStatementAst]
        [System.Management.Automation.Language.IfStatementAst]
    )

    $parent = Get-ParentNonPipelineAst -Ast $Ast

    if ($null -ne $parent)
    {
        if ($parent -is [System.Management.Automation.Language.HashtableAst])
        {
            return Get-KeyValuePairText -HashtableAst $parent -ChildAst $Ast
        }
        elseif ($reportParentExtentTypes -contains $parent.GetType())
        {
            return $parent.Extent.Text
        }
    }

    return $Ast.Extent.Text
}

function Get-ParentNonPipelineAst
{
    param ([System.Management.Automation.Language.Ast] $Ast)

    $parent = $null
    if ($null -ne $Ast) { $parent = $Ast.Parent }

    while ($parent -is [System.Management.Automation.Language.PipelineAst])
    {
        $parent = $parent.Parent
    }

    return $parent
}

function Get-KeyValuePairText
{
    param (
        [System.Management.Automation.Language.HashtableAst] $HashtableAst,
        [System.Management.Automation.Language.Ast] $ChildAst
    )

    & $SafeCommands['Set-StrictMode'] -Off

    foreach ($keyValuePair in $HashtableAst.KeyValuePairs)
    {
        if ($keyValuePair.Item2.PipelineElements -contains $ChildAst)
        {
            return '{0} = {1}' -f $keyValuePair.Item1.Extent.Text, $keyValuePair.Item2.Extent.Text
        }
    }

    # This shouldn't happen, but just in case, default to the old output of just the expression.
    return $ChildAst.Extent.Text
}

function Get-CoverageMissedCommands
{
    param ([object[]] $CommandCoverage)
    $CommandCoverage | & $SafeCommands['Where-Object'] { $_.Breakpoint.HitCount -eq 0 }
}

function Get-CoverageHitCommands
{
    param ([object[]] $CommandCoverage)
    $CommandCoverage | & $SafeCommands['Where-Object'] { $_.Breakpoint.HitCount -gt 0 }
}

function Get-CoverageReport
{
    param ([object] $PesterState)

    $totalCommandCount = $PesterState.CommandCoverage.Count

    $missedCommands = @(Get-CoverageMissedCommands -CommandCoverage $PesterState.CommandCoverage | & $SafeCommands['Select-Object'] File, Line, Function, Command)
    $hitCommands = @(Get-CoverageHitCommands -CommandCoverage $PesterState.CommandCoverage | & $SafeCommands['Select-Object'] File, Line, Function, Command)
    $analyzedFiles = @($PesterState.CommandCoverage | & $SafeCommands['Select-Object'] -ExpandProperty File -Unique)
    $fileCount = $analyzedFiles.Count

    $executedCommandCount = $totalCommandCount - $missedCommands.Count

    [pscustomobject] @{
        NumberOfCommandsAnalyzed = $totalCommandCount
        NumberOfFilesAnalyzed    = $fileCount
        NumberOfCommandsExecuted = $executedCommandCount
        NumberOfCommandsMissed   = $missedCommands.Count
        MissedCommands           = $missedCommands
        HitCommands              = $hitCommands
        AnalyzedFiles            = $analyzedFiles
    }
}

function Show-CoverageReport
{
    param ([object] $CoverageReport)

    if ($null -eq $CoverageReport -or $CoverageReport.NumberOfCommandsAnalyzed -eq 0)
    {
        return
    }

    $totalCommandCount = $CoverageReport.NumberOfCommandsAnalyzed
    $fileCount = $CoverageReport.NumberOfFilesAnalyzed
    $executedPercent = ($CoverageReport.NumberOfCommandsExecuted / $CoverageReport.NumberOfCommandsAnalyzed).ToString("P2")

    $commandPlural = $filePlural = ''
    if ($totalCommandCount -gt 1) { $commandPlural = 's' }
    if ($fileCount -gt 1) { $filePlural = 's' }

    $commonParent = Get-CommonParentPath -Path $CoverageReport.AnalyzedFiles
    $report = $CoverageReport.MissedCommands | & $SafeCommands['Select-Object'] -Property @(
        @{ Name = 'File'; Expression = { Get-RelativePath -Path $_.File -RelativeTo $commonParent } }
        'Function'
        'Line'
        'Command'
    )

    Write-Screen ''
    Write-Screen 'Code coverage report:'
    Write-Screen "Covered $executedPercent of $totalCommandCount analyzed command$commandPlural in $fileCount file$filePlural."

    if ($CoverageReport.MissedCommands.Count -gt 0)
    {
        Write-Screen ''
        Write-Screen 'Missed commands:'
        $report | & $SafeCommands['Format-Table'] -AutoSize | & $SafeCommands['Out-String'] | Write-Screen
    }
}

function Get-CommonParentPath
{
    param ([string[]] $Path)

    $pathsToTest = @( $Path | & $SafeCommands['Select-Object'] -Unique )

    if ($pathsToTest.Count -gt 0)
    {
        $parentPath = & $SafeCommands['Split-Path'] -Path $pathsToTest[0] -Parent

        while ($parentPath.Length -gt 0)
        {
            $nonMatches = $pathsToTest -notmatch "^$([regex]::Escape($parentPath))"

            if ($nonMatches.Count -eq 0)
            {
                return $parentPath
            }
            else
            {
                $parentPath = & $SafeCommands['Split-Path'] -Path $parentPath -Parent
            }
        }
    }

    return [string]::Empty
}

function Get-RelativePath
{
    param ( [string] $Path, [string] $RelativeTo )
    return $Path -replace "^$([regex]::Escape($RelativeTo))\\?"
}

# SIG # Begin signature block
# MIInXgYJKoZIhvcNAQcCoIInTzCCJ0sCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCqG+zazlxP++cv
# 0EUGZRX6zP2XM6BmoNh/fiywwj2BLqCCC7QwggXLMIIEs6ADAgECAhMzAAABQGf2
# mGsxCLhyAAAAAAFAMA0GCSqGSIb3DQEBCwUAMIGOMQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMTgwNgYDVQQDEy9NaWNyb3NvZnQgV2luZG93cyBU
# aGlyZCBQYXJ0eSBDb21wb25lbnQgQ0EgMjAxMjAeFw0yNTExMTMxOTU5NDNaFw0y
# NjExMTAxOTU5NDNaMIGEMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMS4wLAYDVQQDEyVNaWNyb3NvZnQgV2luZG93cyAzcmQgcGFydHkgQ29tcG9u
# ZW50MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEArGt4Hrjs3D7+IIab
# GkPGtg4XeWQFi8nKsdeF+N6nkYF9wsmw0qPk4OovEiJnCSRiEtLfYy3Icn4iOp7L
# 24oCa0zlgYCND3OnNfYOuVpMsq3CSkXYg3H+VMiB11hOLcctTu4RWy4ZRKsL5NVI
# AduJFgd/1Qs2mQpUuOyFfLKhu/+Z+T2c9YALxsfnPvqn8Tn8Tt8wdZuFwz7kK3jl
# e2T3YBofybAR2aH678TnOxhLe2/hEpTdKaVfcqyrIX0Mw/LwqEJnj4G8amBbQ7OG
# RnKm1VNd4nMpRt1SflNlVo1Q3Qqnj9K6mSPw99YGMCTaVr6jKPylsWyW4nsvu8m0
# MbBJJiLOi0sOTHtwQEVcBH6WM7xbODqwPaklS1wDbED1wfzImIUR8WsXJVjDm7Fg
# x4JDo8oLIjKFrEvzBfrYWsvlDg8p9XgR7EB/IJwXGuJbFzo/S+r3D5DkUZXX/72k
# XA4FeRJAgLePAuGChPvyQiLtKJeJm9ftJeukrIcs7JpJVHObAgMBAAGjggGoMIIB
# pDATBgNVHSUEDDAKBggrBgEFBQcDAzAdBgNVHQ4EFgQUB9FDBUZ0W11vsv6qqb9t
# vKspCIowRQYDVR0RBD4wPKQ6MDgxHjAcBgNVBAsTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEWMBQGA1UEBRMNMjMwODA5KzUwNjIyOTAfBgNVHSMEGDAWgBRhcaeHr/9p
# 1SF2T1KTKAC+eRKrhDB0BgNVHR8EbTBrMGmgZ6BlhmNodHRwOi8vd3d3Lm1pY3Jv
# c29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBXaW5kb3dzJTIwVGhpcmQl
# MjBQYXJ0eSUyMENvbXBvbmVudCUyMENBJTIwMjAxMi5jcmwwgYEGCCsGAQUFBwEB
# BHUwczBxBggrBgEFBQcwAoZlaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBXaW5kb3dzJTIwVGhpcmQlMjBQYXJ0eSUyMENv
# bXBvbmVudCUyMENBJTIwMjAxMi5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0B
# AQsFAAOCAQEAmFzJPKhkAXPOcfy9S4q1nP3XCvmABVGv/VRzFZ1e+oVtVzOFkbZ6
# osY1OpZqa9CEvtgcrtciv1y9mV1SpxAMwfEqq+Nhw2GdZ3IWqFzWFsEe2S9U196s
# XRIRIxglZMBWyzdy8rQ+P7L2+LciW4qcaw2wtv6YoI0q1isgk0t1OF5kEL0t9hhx
# UrBavTdoqZ3b5JtwDqzmIsxuLtGbE9Pqbz2gx/me+7yduYpIcYlmEmPQkg3gmWkZ
# lnSRePu7/5RXS2TGW1O5JP8aqVcMn0ZkHEhtT368pE/CxQVAkAYHNz6+enP9n+HC
# 2udu395c0fVlRHy/d53f32RukfbjakH8uzCCBeEwggPJoAMCAQICCmELqsEAAAAA
# AAkwDQYJKoZIhvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNo
# aW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1
# dGhvcml0eSAyMDEwMB4XDTEyMDQxODIzNDgzOFoXDTI3MDQxODIzNTgzOFowgY4x
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xODA2BgNVBAMTL01p
# Y3Jvc29mdCBXaW5kb3dzIFRoaXJkIFBhcnR5IENvbXBvbmVudCBDQSAyMDEyMIIB
# IjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAo5wwhAmnYy7PCkfw6iT5ozAg
# D15XMSaBmjEHslDUzmcJCGUKWqVLrtXtEC7npZm1n2gvmItYAqwgtCnEcb0oHKX9
# PJtk5MXr32ElvPDuaL/Rp8t+KgKBTmRcDFOGeVcZN2G3mPkMoE4iWZv5Gy1nPCc8
# VpBm4/1/ZX0Phr01R+iKzPTajulqTqunVeyiiR7VM0VTy/med73NLPkFuH90AR3o
# +xjhQ9EN6arcN2+9/rgP7R1NAUZOCqz8gujsVoMTjjoB7RRkdOpksmYQtmhtyHAA
# fVBILj1D7uAklcbNjsf9uOSVz91++5VeoQHNQ7EH16Qw7puGGipuwQtZonRviwID
# AQABo4IBQzCCAT8wEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFGFxp4ev/2nV
# IXZPUpMoAL55EquEMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1UdDwQE
# AwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFNX2VsuP6KJcYmjRPZSQ
# W9fOmhjEMFYGA1UdHwRPME0wS6BJoEeGRWh0dHA6Ly9jcmwubWljcm9zb2Z0LmNv
# bS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNybDBa
# BggrBgEFBQcBAQROMEwwSgYIKwYBBQUHMAKGPmh0dHA6Ly93d3cubWljcm9zb2Z0
# LmNvbS9wa2kvY2VydHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3J0MA0GCSqG
# SIb3DQEBCwUAA4ICAQBaimfazNX9DSZBd78KRni0s94SaSt3I8JlLwFf0gP0YbpQ
# nS6MOXLzbD5qsR52bey384LczLvFaXAoc2YXP1Tr7gEWSMRG2RuAroE6jQ95bWiw
# nuotPznTyjh+vV58CG4Z3MbC9DgzaGHiUkeD4QABVtK6y4eCBTEKQYtO539fX+1f
# 0zktReuiE7/9HsKYQXFhFl/ICnAlfFlpMSTkcecKuwQX959yHsnSuxq+PQL+CQyy
# Q7RZGplTk5YhX+DWtyYBQpU2rCf9vvSFd2g9GL30vpiIIhGGUhbzRewDlxBwh6Nw
# Q3E828mGAxcM9XNbxn3hXGTt18VI1+0y4tGq08+n9ldOYfl362fyiLPeANoDj9CK
# NDc+HdhiuNKx8+Evi3I7gZZ8b/zsZnZyYBsk8qCJbVttAC7vKN2GhwXCtLnlvmTC
# KvJKFVyY4sQnhf9S42J+D7ICC9dmxwqy0z0gBBRQMlmDCn2b7Vo4EgFSui9eIHKO
# SvH953ECjDvhB77Jc/TdR9i077SkszC5iT52yrkAmFZ+q+qKuKXQOKtpdxMLFC/p
# qkEf97q9Ois0iu4Kq2PmY/eIJI4gDSs7nePCSVKsnx8OOTtd1G5QauZ9UjqqfDMV
# KQ0mXgFYp06pPXqEb3Q/YJ/kMk82AK9tcdM+pkZlX4F08f7BcdpMoEFagt3xHzGC
# GwAwghr8AgEBMIGmMIGOMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMTgwNgYDVQQDEy9NaWNyb3NvZnQgV2luZG93cyBUaGlyZCBQYXJ0eSBDb21w
# b25lbnQgQ0EgMjAxMgITMwAAAUBn9phrMQi4cgAAAAABQDANBglghkgBZQMEAgEF
# AKCB+jAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAvBgkqhkiG9w0BCQQxIgQg
# I43BYpcft2y60jClV3MZsLYmW2Xl+pWs2B5o0UCvf2AwUAYKKwYBBAGCNwoDHDFC
# DEBCNUY0N0ZEMzUyN0VBMjcxQTJBQ0JGNEYyNjFBQ0YwNkFGQTBCMTQ5Q0E5NkIy
# NkIwMEQ1NjQ0NjkzOUYxMUIxMFoGCisGAQQBgjcCAQwxTDBKoCSAIgBNAGkAYwBy
# AG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0cDovL3d3dy5taWNyb3Nv
# ZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggGAo26SsUyJwERtLbfqiltp
# tVUh+h7/o8p6CtfABjgB8HuuQSueDOUhT/vI47p4FxOY9Sn26W7kGQ6hUVqy+Bjr
# sxoDHR6mSDr4rQLoscb/B835fARYZgSLwF7UDNKxXszHYFCe2kg5LKUe4Wb6Q8To
# 2Opd3ckQjAstenWQsL8RrDeechuZiX3b+5ZEedvxFkPcAWEEsnPml+EopU9njh1G
# ig0AcikKXd9rxXJtu5Tn1JEK5ANIt5/OqTVj1vw8dxM5zQf5SJj1J96A3VNHBKa1
# ddA80Fp3uGk2zZ3oPB6rIDMYc94AcVxLH+tE4SOpBSTzAOBKc8cLHABae7VkTuXm
# NvMJuoaAIEprUSmjwnYkpZcd+hDKpZWehAo9Fa5WNhUlqphR0FaPIlHdBeQfWVV/
# 94Au5zDplpY0l7k+AQISv0bEMdM1pyQ3crAU7BAuevMdUvjnCobu3jAIfSSoArpu
# AeorlnGq014P9SDkozOkcQt31RJxR251aLHJSNXjeMmAoYIXrTCCF6kGCisGAQQB
# gjcDAwExgheZMIIXlQYJKoZIhvcNAQcCoIIXhjCCF4ICAQMxDzANBglghkgBZQME
# AgEFADCCAVoGCyqGSIb3DQEJEAEEoIIBSQSCAUUwggFBAgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIMZJ0gGQ4pMTl81jn88xt4JAcb8xcnUl8zvqb9k9
# hnUpAgZqrrEH4CUYEzIwMjYxMDEwMDgzNjM0LjQ4MlowBIACAfSggdmkgdYwgdMx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1p
# Y3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEnMCUGA1UECxMeblNo
# aWVsZCBUU1MgRVNOOjQzMUEtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQg
# VGltZS1TdGFtcCBTZXJ2aWNloIIR+zCCBygwggUQoAMCAQICEzMAAAIdS8CShziF
# fjkAAQAAAh0wDQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENB
# IDIwMTAwHhcNMjUwODE0MTg0ODMzWhcNMjYxMTEzMTg0ODMzWjCB0zELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWljcm9zb2Z0
# IElyZWxhbmQgT3BlcmF0aW9ucyBMaW1pdGVkMScwJQYDVQQLEx5uU2hpZWxkIFRT
# UyBFU046NDMxQS0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCitKBo
# ADyg6XimHnvjPDb16BQ3wMN6lEctfwUzXMc0mZcboqtKpQrDNwpp+im5h09MRNMK
# 9v1ol8RK4BTSIY1QUj8PpHSS91+l7ag9f4TextNC8aLgk8fmp0hhRonjlX/hup7x
# 429tbOkL5kqMfX3cN6IjVcAj3XwmhCYGGURej9OifXvbWW5kmCKdyx/kuMxjeNfz
# hbJdRJfd2xLuH/vFUj7DXKODulr7TLej+Z7ZOy/pQlR1JNBqnk5EZJ8KdyWc/XPc
# iKJYhavdWjtog9ayAnOrebkbGnFQcJCTyrNSGTnTL+4H4sYTdYgrYLvuLL2IWxJ9
# ItSfIwTMZENb2ZcdPg8fs7PPoIepASI2/BweqW+UKHWkdCHU1dBICo6hUGzmaLp5
# qx/rLFZN97kOtHv3nTevylTpWoLZj1cxFTjAf1BthdiwhRnfcmad3LbZbUsEMBvE
# E9AcIGWdwYNTcGB2FVRUt7zSaCAU73wV2RaGjrvDiQ90JNGS92+Rjw+tBgT+dCMd
# cJrSDstwy21lvp6Mwd9D61RZe/r6dnhieSvY6RrFyUULDhEhg0xYPboBZtCP9YR3
# OBrXx8q3DrovmDNc/NrqMUF88l4oTcfxAC7CmKuYfiaz7mdSM01A6Y2ComfRTX7d
# ifsKWzAPv1g3Svd91tgEwMCkFkmk2UrursddGwIDAQABo4IBSTCCAUUwHQYDVR0O
# BBYEFIRZ8HE0RqZm1ebyCX3ZirzSN/FdMB8GA1UdIwQYMBaAFJ+nFV0AXmJdg/Tl
# 0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly93d3cubWljcm9zb2Z0
# LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAy
# MDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYIKwYBBQUHMAKGUGh0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwVGltZS1T
# dGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/
# BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUAA4IC
# AQCR3B4HjLG8uyksqrQP6aLIPhDQRzFUWk1m4nGJHniBZGR5MMO7KY14HTcmGWwG
# lvBJgnm5lKAMEK/AcQPZUvyUmkWU6msnPGxdYLY1N8D47487kWTmPDoseHqN4EAM
# MR1ADHceqLtmbQnC9D3fPl/p23GSbb1ao5wdhdFd8BDDLWFKstfJ95uWpHrqOk//
# 2fR8KRZTiCCxSNClDY2CPUNXT0nhjfLun013zX5ezqpij77tEqbyqIH/k0N6KA4u
# OUB4WCIRchFQlb6YnKqlDD445GVqpwWNHwe7Qb7/tsx16Trxhf6Q+kMGTtR74j/G
# CJgnXFwNEGf+9zMu03vb5EiUPhSBdgu4FIKT/+kMQ9fnPf0Kv6uRzoThjbwU+TgG
# GWgDK+nrbw/jF8SVBjxNzGtpRtlKHKmhwTqfL3kPUrUGSW1masdUoLGaCWe46UzX
# k0oitcWVcLN2qkK0jBDjXvA0BUX9AM+/PNu6Y91OLp9vS0ttJxihtXrO9sGwywoQ
# wThOPVv2ghcLx3JsmridtugRdilHCLVABulI2uf4/EZb25/WrrcWcwm7iCbc6Hre
# eNb+JV/vbeq7PIetKKNYyBjQeJGIdCLQnK7SHwx2FFSnubFuYtByQ+I4XACUhpQ3
# +TvbnL9otamRFTp+qYuUQ7IflanIt3bcBjL2vy/5ChtrqzCCB3EwggVZoAMCAQIC
# EzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZIhvcNAQELBQAwgYgxCzAJBgNVBAYT
# AlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBS
# b290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDEwMB4XDTIxMDkzMDE4MjIyNVoX
# DTMwMDkzMDE4MzIyNVowfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwggIi
# MA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDk4aZM57RyIQt5osvXJHm9DtWC
# 0/3unAcH0qlsTnXIyjVX9gF/bErg4r25PhdgM/9cT8dm95VTcVrifkpa/rg2Z4VG
# Iwy1jRPPdzLAEBjoYH1qUoNEt6aORmsHFPPFdvWGUNzBRMhxXFExN6AKOG6N7dcP
# 2CZTfDlhAnrEqv1yaa8dq6z2Nr41JmTamDu6GnszrYBbfowQHJ1S/rboYiXcag/P
# XfT+jlPP1uyFVk3v3byNpOORj7I5LFGc6XBpDco2LXCOMcg1KL3jtIckw+DJj361
# VI/c+gVVmG1oO5pGve2krnopN6zL64NF50ZuyjLVwIYwXE8s4mKyzbnijYjklqwB
# Sru+cakXW2dg3viSkR4dPf0gz3N9QZpGdc3EXzTdEonW/aUgfX782Z5F37ZyL9t9
# X4C626p+Nuw2TPYrbqgSUei/BQOj0XOmTTd0lBw0gg/wEPK3Rxjtp+iZfD9M269e
# wvPV2HM9Q07BMzlMjgK8QmguEOqEUUbi0b1qGFphAXPKZ6Je1yh2AuIzGHLXpyDw
# wvoSCtdjbwzJNmSLW6CmgyFdXzB0kZSU2LlQ+QuJYfM2BjUYhEfb3BvR/bLUHMVr
# 9lxSUV0S2yW6r1AFemzFER1y7435UsSFF5PAPBXbGjfHCBUYP3irRbb1Hode2o+e
# FnJpxq57t7c+auIurQIDAQABo4IB3TCCAdkwEgYJKwYBBAGCNxUBBAUCAwEAATAj
# BgkrBgEEAYI3FQIEFgQUKqdS/mTEmr6CkTxGNSnPEP8vBO4wHQYDVR0OBBYEFJ+n
# FV0AXmJdg/Tl0mWnG1M1GelyMFwGA1UdIARVMFMwUQYMKwYBBAGCN0yDfQEBMEEw
# PwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9j
# cy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAKBggrBgEFBQcDCDAZBgkrBgEEAYI3
# FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAf
# BgNVHSMEGDAWgBTV9lbLj+iiXGJo0T2UkFvXzpoYxDBWBgNVHR8ETzBNMEugSaBH
# hkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNS
# b29DZXJBdXRfMjAxMC0wNi0yMy5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUF
# BzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0Nl
# ckF1dF8yMDEwLTA2LTIzLmNydDANBgkqhkiG9w0BAQsFAAOCAgEAnVV9/Cqt4Swf
# ZwExJFvhnnJL/Klv6lwUtj5OR2R4sQaTlz0xM7U518JxNj/aZGx80HU5bbsPMeTC
# j/ts0aGUGCLu6WZnOlNN3Zi6th542DYunKmCVgADsAW+iehp4LoJ7nvfam++Kctu
# 2D9IdQHZGN5tggz1bSNU5HhTdSRXud2f8449xvNo32X2pFaq95W2KFUn0CS9QKC/
# GbYSEhFdPSfgQJY4rPf5KYnDvBewVIVCs/wMnosZiefwC2qBwoEZQhlSdYo2wh3D
# YXMuLGt7bj8sCXgU6ZGyqVvfSaN0DLzskYDSPeZKPmY7T7uG+jIa2Zb0j/aRAfbO
# xnT99kxybxCrdTDFNLB62FD+CljdQDzHVG2dY3RILLFORy3BFARxv2T5JL5zbcqO
# Cb2zAVdJVGTZc9d/HltEAY5aGZFrDZ+kKNxnGSgkujhLmm77IVRrakURR6nxt67I
# 6IleT53S0Ex2tVdUCbFpAUR+fKFhbHP+CrvsQWY9af3LwUFJfn6Tvsv4O+S3Fb+0
# zj6lMVGEvL8CwYKiexcdFYmNcP7ntdAoGokLjzbaukz5m/8K6TT4JDVnK+ANuOaM
# mdbhIurwJ0I9JZTmdHRbatGePu1+oDEzfbzL6Xu/OHBE0ZDxyKs6ijoIYn/ZcGNT
# TY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggNWMIICPgIBATCCAQGhgdmkgdYwgdMx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1p
# Y3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEnMCUGA1UECxMeblNo
# aWVsZCBUU1MgRVNOOjQzMUEtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQg
# VGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQC6g74Ept9fOrJ+L0Ys
# R1YeQIt5P6CBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0G
# CSqGSIb3DQEBCwUAAgUA7nQz9TAiGA8yMDI2MTAxMDAzNDgwNVoYDzIwMjYxMDEx
# MDM0ODA1WjB0MDoGCisGAQQBhFkKBAExLDAqMAoCBQDudDP1AgEAMAcCAQACAi20
# MAcCAQACAhNzMAoCBQDudYV1AgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQB
# hFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEB
# AIilSW5ShDASdqvQ61bNzBQUXMrZAgzuMV6R5jvG+utkL/oisAsykayLZJErV29E
# YtCNJcKguX4VuGmZdkEtJKv63LTgMdDwFtSlSRkMql0eiUcaoeAfFerFwt5m1Y5s
# aWukrSLkN2cEmkG+Jary1zjf3hiGK34Ys9+XU1lW98Y/DAez6Qzs8wLHqAquyNVd
# EWTITmo5hRSCMPvT5L3rQ0XhhmzpbynfbXNQ/qnbiwh7zIDmVd68Qmdkf9d7Ob2k
# kuFnBMyCGjbXrDfmVpQoTYJvPiaPwcn4OUWOON8iDXTJZl4tousvM6DxFN5iK7RI
# ibGirXTFQCWybwNwthGmpekxggQNMIIECQIBATCBkzB8MQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1T
# dGFtcCBQQ0EgMjAxMAITMwAAAh1LwJKHOIV+OQABAAACHTANBglghkgBZQMEAgEF
# AKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJBDEi
# BCBu8agvIW1jqUS0SWc1Ol0NYcXKU7JwTArJMxkxAhIP0DCB+gYLKoZIhvcNAQkQ
# Ai8xgeowgecwgeQwgb0EILG2lcxcSIsnOuozvt6nitM3Csw6PqClY32Fm+mPlAVR
# MIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAO
# BgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEm
# MCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAIdS8CS
# hziFfjkAAQAAAh0wIgQg7cY5IlanUW9mTuLYT+ubrO1EQygPMzdQROcMCg1/XTIw
# DQYJKoZIhvcNAQELBQAEggIAmL1g9VAYxhYsBNOC5aI1jNIjQOZS7R/POFpaJ1D4
# okYb4smFMKfvmEHgZ2cBgw56AzevWF1yRmUzH8SpVV82+0Ur9BL5Fy+YIAjokmcf
# 6X3ou907WoI2N3ldACtPxvAW7oClunx1knB3DU2ggicf3yWuhrIBpMM77S23v5ay
# 8n54Re/fLF9Cu4y+wm2J4PmcdpsnIAzZM0NO0Cj/w2DiZj3atvqdCcXWKSRgiJaV
# PAEnvLVmhw+9xYwDTnrWESGsSvuLed66K6sGHmZ3SvI/4Ie0To+DIANhVxIrEgYo
# i6C3k4s6m3ksWAilpiADHblTETSPrWm62lYAuYN3QQPV6iIhur5HUWvQD1Zt/StO
# 6hHguhcupQXJ3C1omMTX+9IrhQdDk8i9kC0X1XrrcdSaNRgS5Kblf+sSReyhFeev
# uELZ9s9Na9te0ccoopcbMYgL3a/b1wbFR8afSAkvqNKKA4hXllW8uwcCWFxrkSko
# gYM6mZ9PmXMMahvk2DzNal7NtSONHlShJvfH4mckUf3YUe3w1S7Xe5/NZDFCqnso
# B6ASXPgzf2NE4eOXZYGCuLEhhx2r6mjEL058j6zlcmILg7RXXui+dG7CokiXvHAL
# 4sgix8brvYRZdX9e5oW/Q601+B3yixm7v8s3tVpw8gy/0bFaeoUDN8RPc9xbJpr0
# YuE=
# SIG # End signature block
