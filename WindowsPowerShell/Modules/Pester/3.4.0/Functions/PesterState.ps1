function New-PesterState
{
    param (
        [String[]]$TagFilter,
        [String[]]$ExcludeTagFilter,
        [String[]]$TestNameFilter,
        [System.Management.Automation.SessionState]$SessionState,
        [Switch]$Strict,
        [Switch]$Quiet,
        [object]$PesterOption
    )

    if ($null -eq $SessionState) { $SessionState = $ExecutionContext.SessionState }

    if ($null -eq $PesterOption)
    {
        $PesterOption = New-PesterOption
    }
    elseif ($PesterOption -is [System.Collections.IDictionary])
    {
        try
        {
            $PesterOption = New-PesterOption @PesterOption
        }
        catch
        {
            throw
        }
    }

    & $SafeCommands['New-Module'] -Name Pester -AsCustomObject -ScriptBlock {
        param (
            [String[]]$_tagFilter,
            [String[]]$_excludeTagFilter,
            [String[]]$_testNameFilter,
            [System.Management.Automation.SessionState]$_sessionState,
            [Switch]$Strict,
            [Switch]$Quiet,
            [object]$PesterOption
        )

        #public read-only
        $TagFilter = $_tagFilter
        $ExcludeTagFilter = $_excludeTagFilter
        $TestNameFilter = $_testNameFilter

        $script:SessionState = $_sessionState
        $script:CurrentContext = ""
        $script:CurrentDescribe = ""
        $script:CurrentTest = ""
        $script:Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $script:MostRecentTimestamp = 0
        $script:CommandCoverage = @()
        $script:BeforeEach = @()
        $script:AfterEach = @()
        $script:BeforeAll = @()
        $script:AfterAll = @()
        $script:Strict = $Strict
        $script:Quiet = $Quiet

        $script:TestResult = @()

        $script:TotalCount = 0
        $script:Time = [timespan]0
        $script:PassedCount = 0
        $script:FailedCount = 0
        $script:SkippedCount = 0
        $script:PendingCount = 0
        $script:InconclusiveCount = 0

        $script:IncludeVSCodeMarker = $PesterOption.IncludeVSCodeMarker

        $script:SafeCommands = @{}

        $script:SafeCommands['New-Object']          = & (Pester\SafeGetCommand) -Name New-Object          -Module Microsoft.PowerShell.Utility -CommandType Cmdlet
        $script:SafeCommands['Select-Object']       = & (Pester\SafeGetCommand) -Name Select-Object       -Module Microsoft.PowerShell.Utility -CommandType Cmdlet
        $script:SafeCommands['Export-ModuleMember'] = & (Pester\SafeGetCommand) -Name Export-ModuleMember -Module Microsoft.PowerShell.Core    -CommandType Cmdlet
        $script:SafeCommands['Add-Member']          = & (Pester\SafeGetCommand) -Name Add-Member          -Module Microsoft.PowerShell.Utility -CommandType Cmdlet

        function EnterDescribe([string]$Name)
        {
            if ($CurrentDescribe)
            {
                throw & $SafeCommands['New-Object'] InvalidOperationException "You already are in Describe, you cannot enter Describe twice"
            }
            $script:CurrentDescribe = $Name
        }

        function LeaveDescribe
        {
            if ( $CurrentContext ) {
                throw & $SafeCommands['New-Object'] InvalidOperationException "Cannot leave Describe before leaving Context"
            }

            $script:CurrentDescribe = $null
        }

        function EnterContext([string]$Name)
        {
            if ( -not $CurrentDescribe )
            {
                throw & $SafeCommands['New-Object'] InvalidOperationException "Cannot enter Context before entering Describe"
            }

            if ( $CurrentContext )
            {
                throw & $SafeCommands['New-Object'] InvalidOperationException "You already are in Context, you cannot enter Context twice"
            }

            if ($CurrentTest)
            {
                throw & $SafeCommands['New-Object'] InvalidOperationException "You already are in It, you cannot enter Context inside It"
            }

            $script:CurrentContext = $Name
        }

        function LeaveContext
        {
            if ($CurrentTest)
            {
                throw & $SafeCommands['New-Object'] InvalidOperationException "Cannot leave Context before leaving It"
            }

            $script:CurrentContext = $null
        }

        function EnterTest([string]$Name)
        {
            if (-not $script:CurrentDescribe)
            {
                throw & $SafeCommands['New-Object'] InvalidOperationException "Cannot enter It before entering Describe"
            }

            if ( $CurrentTest )
            {
                throw & $SafeCommands['New-Object'] InvalidOperationException "You already are in It, you cannot enter It twice"
            }

            $script:CurrentTest = $Name
        }

        function LeaveTest
        {
            $script:CurrentTest = $null
        }

        function AddTestResult
        {
            param (
                [string]$Name,
                [ValidateSet("Failed","Passed","Skipped","Pending","Inconclusive")]
                [string]$Result,
                [Nullable[TimeSpan]]$Time,
                [string]$FailureMessage,
                [string]$StackTrace,
                [string] $ParameterizedSuiteName,
                [System.Collections.IDictionary] $Parameters,
                [System.Management.Automation.ErrorRecord] $ErrorRecord
            )

            $previousTime = $script:MostRecentTimestamp
            $script:MostRecentTimestamp = $script:Stopwatch.Elapsed

            if ($null -eq $Time)
            {
                $Time = $script:MostRecentTimestamp - $previousTime
            }

            if (-not $script:Strict)
            {
                $Passed = "Passed","Skipped","Pending" -contains $Result
            }
            else
            {
                $Passed = $Result -eq "Passed"
                if (($Result -eq "Skipped") -or ($Result -eq "Pending"))
                {
                    $FailureMessage = "The test failed because the test was executed in Strict mode and the result '$result' was translated to Failed."
                    $Result = "Failed"
                }

            }

            $script:TotalCount++
            $script:Time += $Time

            switch ($Result)
            {
                Passed  { $script:PassedCount++; break; }
                Failed  { $script:FailedCount++; break; }
                Skipped { $script:SkippedCount++; break; }
                Pending { $script:PendingCount++; break; }
                Inconclusive { $script:InconclusiveCount++; break; }
            }

            $Script:TestResult += & $SafeCommands['New-Object'] -TypeName PsObject -Property @{
                Describe               = $CurrentDescribe
                Context                = $CurrentContext
                Name                   = $Name
                Passed                 = $Passed
                Result                 = $Result
                Time                   = $Time
                FailureMessage         = $FailureMessage
                StackTrace             = $StackTrace
                ErrorRecord            = $ErrorRecord
                ParameterizedSuiteName = $ParameterizedSuiteName
                Parameters             = $Parameters
            } | & $SafeCommands['Select-Object'] Describe, Context, Name, Result, Passed, Time, FailureMessage, StackTrace, ErrorRecord, ParameterizedSuiteName, Parameters
        }

        $ExportedVariables = "TagFilter",
        "ExcludeTagFilter",
        "TestNameFilter",
        "TestResult",
        "CurrentContext",
        "CurrentDescribe",
        "CurrentTest",
        "SessionState",
        "CommandCoverage",
        "BeforeEach",
        "AfterEach",
        "BeforeAll",
        "AfterAll",
        "Strict",
        "Quiet",
        "Time",
        "TotalCount",
        "PassedCount",
        "FailedCount",
        "SkippedCount",
        "PendingCount",
        "InconclusiveCount",
        "IncludeVSCodeMarker"

        $ExportedFunctions = "EnterContext",
        "LeaveContext",
        "EnterDescribe",
        "LeaveDescribe",
        "EnterTest",
        "LeaveTest",
        "AddTestResult"

        & $SafeCommands['Export-ModuleMember'] -Variable $ExportedVariables -function $ExportedFunctions
    } -ArgumentList $TagFilter, $ExcludeTagFilter, $TestNameFilter, $SessionState, $Strict, $Quiet, $PesterOption |
    & $SafeCommands['Add-Member'] -MemberType ScriptProperty -Name Scope -Value {
        if ($this.CurrentTest) { 'It' }
        elseif ($this.CurrentContext)  { 'Context' }
        elseif ($this.CurrentDescribe) { 'Describe' }
        else { $null }
    } -Passthru |
    & $SafeCommands['Add-Member'] -MemberType ScriptProperty -Name ParentScope -Value {
        $parentScope = $null
        $scope = $this.Scope

        if ($scope -eq 'It' -and $this.CurrentContext)
        {
            $parentScope = 'Context'
        }

        if ($null -eq $parentScope -and $scope -ne 'Describe' -and $this.CurrentDescribe)
        {
            $parentScope = 'Describe'
        }

        return $parentScope
    } -PassThru
}

function Write-Describe
{
    param (
        [Parameter(mandatory=$true, valueFromPipeline=$true)]$Name
    )
    process {
        Write-Screen Describing $Name -OutputType Header
    }
}

function Write-Context
{
    param (
        [Parameter(mandatory=$true, valueFromPipeline=$true)]$Name
    )
    process {
        $margin = " " * 3
        Write-Screen ${margin}Context $Name -OutputType Header
    }
}

function Write-PesterResult
{
    param (
        [Parameter(mandatory=$true, valueFromPipeline=$true)]
        $TestResult
    )
    process {
        $testDepth = if ( $TestResult.Context ) { 4 } elseif ( $TestResult.Describe ) { 1 } else { 0 }

        $margin = " " * $TestDepth
        $error_margin = $margin + "  "
        $output = $TestResult.name
        $humanTime = Get-HumanTime $TestResult.Time.TotalSeconds

        switch ($TestResult.Result)
        {
            Passed {
                "$margin[+] $output $humanTime" | Write-Screen -OutputType Passed
                break
            }
            Failed {
                "$margin[-] $output $humanTime" | Write-Screen -OutputType Failed

                $failureLines = $TestResult.ErrorRecord | ConvertTo-FailureLines

                if ($Pester.IncludeVSCodeMarker)
                {
                    $marker = $failureLines |
                              & $script:SafeCommands['Select-Object'] -First 1 -ExpandProperty Trace |
                              & $script:SafeCommands['Select-Object'] -First 1

                    Write-Screen -OutputType Failed $($marker -replace '(?m)^',$error_margin)
                }

                $failureLines |
                    & $SafeCommands['ForEach-Object'] {$_.Message + $_.Trace} |
                    & $SafeCommands['ForEach-Object'] { Write-Screen -OutputType Failed $($_ -replace '(?m)^',$error_margin) }
            }
            Skipped {
                "$margin[!] $output $humanTime" | Write-Screen -OutputType Skipped
                break
            }
            Pending {
                "$margin[?] $output $humanTime" | Write-Screen -OutputType Pending
                break
            }
            Inconclusive {
                "$margin[?] $output $humanTime" | Write-Screen -OutputType Inconclusive
                if ($testresult.FailureMessage) {
                    Write-Screen -OutputType Inconclusive $($TestResult.failureMessage -replace '(?m)^',$error_margin)
                }

                Write-Screen -OutputType Inconclusive $($TestResult.stackTrace -replace '(?m)^',$error_margin)
                break
            }
        }
    }
}

function ConvertTo-FailureLines
{
    param (
        [Parameter(mandatory=$true, valueFromPipeline=$true)]
        $ErrorRecord
    )
    process {
        $lines = & $script:SafeCommands['New-Object'] psobject -Property @{
            Message = @()
            Trace = @()
        }

        ## convert the exception messages
        $exception = $ErrorRecord.Exception
        $exceptionLines = @()
        while ($exception)
        {
            $exceptionName = $exception.GetType().Name
            $thisLines = $exception.Message.Split([Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)
            if ($ErrorRecord.FullyQualifiedErrorId -ne 'PesterAssertionFailed')
            {
                $thisLines[0] = "$exceptionName`: $($thisLines[0])"
            }
            [array]::Reverse($thisLines)
            $exceptionLines += $thisLines
            $exception = $exception.InnerException
        }
        [array]::Reverse($exceptionLines)
        $lines.Message += $exceptionLines
        if ($ErrorRecord.FullyQualifiedErrorId -eq 'PesterAssertionFailed')
        {
            $lines.Message += "$($ErrorRecord.TargetObject.Line)`: $($ErrorRecord.TargetObject.LineText)".Split([Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)
        }

        if ( -not ($ErrorRecord | & $SafeCommands['Get-Member'] -Name ScriptStackTrace) )
        {
            if ($ErrorRecord.FullyQualifiedErrorID -eq 'PesterAssertionFailed')
            {
                $lines.Trace += "at line: $($ErrorRecord.TargetObject.Line) in $($ErrorRecord.TargetObject.File)"
            }
            else
            {
                $lines.Trace += "at line: $($ErrorRecord.InvocationInfo.ScriptLineNumber) in $($ErrorRecord.InvocationInfo.ScriptName)"
            }
            return $lines
        }

        ## convert the stack trace
        $traceLines = $ErrorRecord.ScriptStackTrace.Split([Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)

        # omit the lines internal to Pester
        foreach ( $line in $traceLines )
        {
            if ( $line -match '^at (Invoke-Test|Context|Describe|InModuleScope|Invoke-Pester), .*\\Functions\\.*.ps1: line [0-9]*$' )
            {
                break
            }
            $count ++
        }
        $lines.Trace += $traceLines |
            & $SafeCommands['Select-Object'] -First $count |
            & $SafeCommands['Where-Object'] {
                $_ -notmatch '^at Should<End>, .*\\Functions\\Assertions\\Should.ps1: line [0-9]*$' -and
                $_ -notmatch '^at Assert-MockCalled, .*\\Functions\\Mock.ps1: line [0-9]*$'
            }

        return $lines
    }
}

function Write-PesterReport
{
    param (
        [Parameter(mandatory=$true, valueFromPipeline=$true)]
        $PesterState
    )

    Write-Screen "Tests completed in $(Get-HumanTime $PesterState.Time.TotalSeconds)"
    Write-Screen ("Passed: {0} Failed: {1} Skipped: {2} Pending: {3} Inconclusive: {4}" -f
                  $PesterState.PassedCount,
                  $PesterState.FailedCount,
                  $PesterState.SkippedCount,
                  $PesterState.PendingCount,
                  $PesterState.InconclusiveCount)
}

function Write-Screen {
    #wraps the Write-Host cmdlet to control if the output is written to screen from one place
    param(
        #Write-Host parameters
        [Parameter(Position=0, ValueFromPipeline=$true, ValueFromRemainingArguments=$true)]
        [Object] $Object,
        [Switch] $NoNewline,
        [Object] $Separator,
        #custom parameters
        [Switch] $Quiet = $pester.Quiet,
        [ValidateSet("Failed","Passed","Skipped","Pending","Inconclusive","Header","Standard")]
        [String] $OutputType = "Standard"
    )

    begin
    {
        if ($Quiet) { return }

        #make the bound parameters compatible with Write-Host
        if ($PSBoundParameters.ContainsKey('Quiet')) { $PSBoundParameters.Remove('Quiet') | & $SafeCommands['Out-Null'] }
        if ($PSBoundParameters.ContainsKey('OutputType')) { $PSBoundParameters.Remove('OutputType') | & $SafeCommands['Out-Null'] }

        if ($OutputType -ne "Standard")
        {
            #create the key first to make it work in strict mode
            if (-not $PSBoundParameters.ContainsKey('ForegroundColor'))
            {
                $PSBoundParameters.Add('ForegroundColor', $null)
            }



            switch ($Host.Name)
            {
                #light background
                "PowerGUIScriptEditorHost" {
                    $ColorSet = @{
                        Failed       = [ConsoleColor]::Red
                        Passed       = [ConsoleColor]::DarkGreen
                        Skipped      = [ConsoleColor]::DarkGray
                        Pending      = [ConsoleColor]::DarkCyan
                        Inconclusive = [ConsoleColor]::DarkCyan
                        Header       = [ConsoleColor]::Magenta
                    }
                }
                #dark background
                { "Windows PowerShell ISE Host", "ConsoleHost" -contains $_ } {
                    $ColorSet = @{
                        Failed       = [ConsoleColor]::Red
                        Passed       = [ConsoleColor]::Green
                        Skipped      = [ConsoleColor]::Gray
                        Pending      = [ConsoleColor]::Cyan
                        Inconclusive = [ConsoleColor]::Cyan
                        Header       = [ConsoleColor]::Magenta
                    }
                }
                default {
                    $ColorSet = @{
                        Failed       = [ConsoleColor]::Red
                        Passed       = [ConsoleColor]::DarkGreen
                        Skipped      = [ConsoleColor]::Gray
                        Pending      = [ConsoleColor]::Gray
                        Inconclusive = [ConsoleColor]::Gray
                        Header       = [ConsoleColor]::Magenta
                    }
                }

             }


            $PSBoundParameters.ForegroundColor = $ColorSet.$OutputType
        }

        try {
            $outBuffer = $null
            if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
            {
                $PSBoundParameters['OutBuffer'] = 1
            }
            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Write-Host', [System.Management.Automation.CommandTypes]::Cmdlet)
            $scriptCmd = {& $wrappedCmd @PSBoundParameters }
            $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
            $steppablePipeline.Begin($PSCmdlet)
        } catch {
            throw
        }
    }

    process
    {
        if ($Quiet) { return }
        try {
            $steppablePipeline.Process($_)
        } catch {
            throw
        }
    }

    end
    {
        if ($Quiet) { return }
        try {
            $steppablePipeline.End()
        } catch {
            throw
        }
    }
}

# SIG # Begin signature block
# MIInVAYJKoZIhvcNAQcCoIInRTCCJ0ECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDPZLreddgR0Geh
# u1WfGwwONHXVHGKZRDPrAFEgyifb1qCCC8MwggXaMIIEwqADAgECAhMzAAABP8rF
# KBkLiTVYAAAAAAE/MA0GCSqGSIb3DQEBCwUAMIGOMQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMTgwNgYDVQQDEy9NaWNyb3NvZnQgV2luZG93cyBU
# aGlyZCBQYXJ0eSBDb21wb25lbnQgQ0EgMjAxMjAeFw0yNTExMTMxOTU5NDJaFw0y
# NjExMTAxOTU5NDJaMIGEMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMS4wLAYDVQQDEyVNaWNyb3NvZnQgV2luZG93cyAzcmQgcGFydHkgQ29tcG9u
# ZW50MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA2Zy0BnZmL5lF9IDS
# IFBJ81NqCWCPLo2bRGJObUnrlezQw+FWEDU9+poMEyRjgbgafifNKY4TJ3e9Od4p
# q56xMXBcGYVIe546gz4p68MQG4iXqqSBB4kk5jwk5U7igTCfZIga6PFElV6Wm7kv
# Bdw14NVgdJZZDdmIc9TdaWbxrxAda9IMjZNQYfJZ/WVinf0mPnYM2hQwj4Gl4DGC
# 0/KO6U+ayXHAtcS9qj2UJYB7rCyteNydGWHaMa5B8fzOpSNS3ioJfYcBwSjfcBRD
# pemnEb5BcIF10FVuNA4foeMz5emIZaGGl8XxVC9K79Xwkc571Sv899qEdYP8ZFW9
# yVXY8l1ptvk4nD52nq9ld4HjWA+FHmhbhKggbjEVymQee7fOgEWKE3Uc73YnTMGf
# TXzDwH9jYip5fwls08LWs0HCINu/iA/OG/vm1jrJdK5wcBgX2B0fZPdwgLTEgs0R
# rSIyv9WucI0S6XffXJuUH+lziAX7RmCPhy5kZR1R3LB0GnBlAgMBAAGjggG3MIIB
# szATBgNVHSUEDDAKBggrBgEFBQcDAzAdBgNVHQ4EFgQUt3RSDxhJIhKufhwaOyWL
# 3nMDoeUwVAYDVR0RBE0wS6RJMEcxLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5k
# IE9wZXJhdGlvbnMgTGltaXRlZDEWMBQGA1UEBRMNMjMwODA5KzUwNjIzOTAfBgNV
# HSMEGDAWgBRhcaeHr/9p1SF2T1KTKAC+eRKrhDB0BgNVHR8EbTBrMGmgZ6BlhmNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBX
# aW5kb3dzJTIwVGhpcmQlMjBQYXJ0eSUyMENvbXBvbmVudCUyMENBJTIwMjAxMi5j
# cmwwgYEGCCsGAQUFBwEBBHUwczBxBggrBgEFBQcwAoZlaHR0cDovL3d3dy5taWNy
# b3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBXaW5kb3dzJTIwVGhp
# cmQlMjBQYXJ0eSUyMENvbXBvbmVudCUyMENBJTIwMjAxMi5jcnQwDAYDVR0TAQH/
# BAIwADANBgkqhkiG9w0BAQsFAAOCAQEAk+iGdVNjQ2VMiNXhflILGybQmTUMM+qd
# BZ3KErdJ9wkVTN/fMukvmp9y1iF8Sz1NUqDNqiKLofcL0XukOu5W3zAofFlAs2tR
# vf0ArWKgRP5gjpqXeo3xWRM/1LBYTDhwDmylfh36AnfErB+aHyoIr9an+2KqeIqj
# 5VvFPgwJ1n6ZTXZMhjvYnIol/P+vwVroo2XKwbOL1/c79xRj7X8Lqw+7sVoIA9/P
# ytqdSDV1ClBjltkRpdgwvbSDPzycfvN8V5pPFfkrqrcIHjaL2pe76nqRsEIPqiVQ
# SmqiaJV6iprCSDGJYC4/4EMLIDZ4uf+m0XHW3Qzlr7RLlMdsJKny7jCCBeEwggPJ
# oAMCAQICCmELqsEAAAAAAAkwDQYJKoZIhvcNAQELBQAwgYgxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBSb290
# IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDEwMB4XDTEyMDQxODIzNDgzOFoXDTI3
# MDQxODIzNTgzOFowgY4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xODA2BgNVBAMTL01pY3Jvc29mdCBXaW5kb3dzIFRoaXJkIFBhcnR5IENvbXBv
# bmVudCBDQSAyMDEyMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAo5ww
# hAmnYy7PCkfw6iT5ozAgD15XMSaBmjEHslDUzmcJCGUKWqVLrtXtEC7npZm1n2gv
# mItYAqwgtCnEcb0oHKX9PJtk5MXr32ElvPDuaL/Rp8t+KgKBTmRcDFOGeVcZN2G3
# mPkMoE4iWZv5Gy1nPCc8VpBm4/1/ZX0Phr01R+iKzPTajulqTqunVeyiiR7VM0VT
# y/med73NLPkFuH90AR3o+xjhQ9EN6arcN2+9/rgP7R1NAUZOCqz8gujsVoMTjjoB
# 7RRkdOpksmYQtmhtyHAAfVBILj1D7uAklcbNjsf9uOSVz91++5VeoQHNQ7EH16Qw
# 7puGGipuwQtZonRviwIDAQABo4IBQzCCAT8wEAYJKwYBBAGCNxUBBAMCAQAwHQYD
# VR0OBBYEFGFxp4ev/2nVIXZPUpMoAL55EquEMBkGCSsGAQQBgjcUAgQMHgoAUwB1
# AGIAQwBBMAsGA1UdDwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaA
# FNX2VsuP6KJcYmjRPZSQW9fOmhjEMFYGA1UdHwRPME0wS6BJoEeGRWh0dHA6Ly9j
# cmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dF8y
# MDEwLTA2LTIzLmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYBBQUHMAKGPmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljUm9vQ2VyQXV0XzIwMTAt
# MDYtMjMuY3J0MA0GCSqGSIb3DQEBCwUAA4ICAQBaimfazNX9DSZBd78KRni0s94S
# aSt3I8JlLwFf0gP0YbpQnS6MOXLzbD5qsR52bey384LczLvFaXAoc2YXP1Tr7gEW
# SMRG2RuAroE6jQ95bWiwnuotPznTyjh+vV58CG4Z3MbC9DgzaGHiUkeD4QABVtK6
# y4eCBTEKQYtO539fX+1f0zktReuiE7/9HsKYQXFhFl/ICnAlfFlpMSTkcecKuwQX
# 959yHsnSuxq+PQL+CQyyQ7RZGplTk5YhX+DWtyYBQpU2rCf9vvSFd2g9GL30vpiI
# IhGGUhbzRewDlxBwh6NwQ3E828mGAxcM9XNbxn3hXGTt18VI1+0y4tGq08+n9ldO
# Yfl362fyiLPeANoDj9CKNDc+HdhiuNKx8+Evi3I7gZZ8b/zsZnZyYBsk8qCJbVtt
# AC7vKN2GhwXCtLnlvmTCKvJKFVyY4sQnhf9S42J+D7ICC9dmxwqy0z0gBBRQMlmD
# Cn2b7Vo4EgFSui9eIHKOSvH953ECjDvhB77Jc/TdR9i077SkszC5iT52yrkAmFZ+
# q+qKuKXQOKtpdxMLFC/pqkEf97q9Ois0iu4Kq2PmY/eIJI4gDSs7nePCSVKsnx8O
# OTtd1G5QauZ9UjqqfDMVKQ0mXgFYp06pPXqEb3Q/YJ/kMk82AK9tcdM+pkZlX4F0
# 8f7BcdpMoEFagt3xHzGCGucwghrjAgEBMIGmMIGOMQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMTgwNgYDVQQDEy9NaWNyb3NvZnQgV2luZG93cyBU
# aGlyZCBQYXJ0eSBDb21wb25lbnQgQ0EgMjAxMgITMwAAAT/KxSgZC4k1WAAAAAAB
# PzANBglghkgBZQMEAgEFAKCB+jAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAv
# BgkqhkiG9w0BCQQxIgQgD/DeTnDG+LNsksn6/w3zgFW6Ofn67wEuOg6aoSgx2nkw
# UAYKKwYBBAGCNwoDHDFCDEA4M0U3MzRGRTNDNjlCMEM0NEU3MEFEQkZBRTlGN0M4
# NjRFOTMyMkMxN0FBNjlCODM1RTFCRDkwQzY0QURFOUJDMFoGCisGAQQBgjcCAQwx
# TDBKoCSAIgBNAGkAYwByAG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggGA
# qGv8tnn9LSIy1o+kMy+sUZrVroe7I5sMynSNN+iZozSb0V7P+AC9mZrjfOpS+KdI
# rsTr74KfMmdY2DKfBGrIBOXP5Wj58O7k3vyw7DLKu9QPCMfKmzxg90qELKZZTAW3
# yRLHFYTMtFN9cXG6VkzHCquhCgIrjPky+13xYiTzWzfHUhUPeGObsz+/dAlbkl4k
# sgTWEBsolPRWvpdStOo0qwLszrZBIDzWIOseYS7inNx742uTQVBcKko1XuHYOkCM
# kuEWQ88A8OOCS2ZXGVDuegOfkQGx8+RB7w+8MOQjs2sYrj/uQ7MyxNM1oZO4dpeL
# FYWXGnygJJYgK8a6oK/aoLd+gsMr90nkoidy7JlyWA6woxoDqG06oBAFsglYuB20
# uB+L5eQbU/adH4nDoo0oR7ibrToF+R1oTip50LGPO6BtNMVd9mo5utqUzTZWgSWD
# H2B0rL+GCgRA1FUqklVH2CG8IBDMI6tQXo+V8Ni3AQc3Hml4GIRT6F2GPI8+n5R0
# oYIXlDCCF5AGCisGAQQBgjcDAwExgheAMIIXfAYJKoZIhvcNAQcCoIIXbTCCF2kC
# AQMxDzANBglghkgBZQMEAgEFADCCAVIGCyqGSIb3DQEJEAEEoIIBQQSCAT0wggE5
# AgEBBgorBgEEAYRZCgMBMDEwDQYJYIZIAWUDBAIBBQAEIDEqThWvoyUz/fIify+w
# JXiNZYxuEdEdGycMbwkppjNIAgZqqi8ORlwYEzIwMjYxMDEwMDgzNjM1LjM4NVow
# BIACAfSggdGkgc4wgcsxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNV
# BAsTHm5TaGllbGQgVFNTIEVTTjo4OTAwLTA1RTAtRDk0NzElMCMGA1UEAxMcTWlj
# cm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaCCEeowggcgMIIFCKADAgECAhMzAAAC
# IkHS9qr/yLX/AAEAAAIiMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFBDQSAyMDEwMB4XDTI2MDIxOTE5Mzk1NloXDTI3MDUxNzE5Mzk1Nlowgcsx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1p
# Y3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNT
# IEVTTjo4OTAwLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3Rh
# bXAgU2VydmljZTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBALW54om6
# Qi5SwAAmj8BjkNlGoftuGC/sJYY2UR1tEaghOt0Tpayfns1o27UFN2MFsVy/tF+L
# G17TH4dG9dKqwP5Z5Jf/r/L3ATQzP7FE9MYhjbQrtpANrrw7LNXJR5QLKnJkL+Bb
# /fK079k6dT0fauLvuQk/wAGurLLVTFf86x4SC8eyPzKKRZPQBG2uNZtcwcXNI6jm
# FBx9SYxcqpZbPr43T5TKeEbLWf52hbhZmCkfxjlbuGlKiRaPUz8u7jCLejoPP29V
# a6RyBQUaMsCXhhmk6FqHse6IL9qVciYxB/wLcDyr/r/WEWh4hkHhQaTLDEH85JM5
# Kwvr7f2kOrMzsKA6l/hXv32Q33jIz25ckjlP9KIDkx0hkiERbT5uHzlGoOHlhbf+
# hq/nhE/HDk4+UfrhBXoomSXQUgSUxWgs2jxRZFBwwPXv3HtYBKMLouxo1nvIrSpw
# RIiwvXCJCZ19AHFyqsUKkhB+eZAWQ6n0jJdRarNry2anPwTppeD1vV6IBPc9VOCs
# 6U+L+FhkJ8/Ff/qMa3I+PLUKLA6YlqaiGZJT/8I4B6d9FPYbYcxFSkJfXOz4CYOZ
# 1AzVdFpvhhIAssCUPMYKyAjvuee4mOhcCWIma/s1+u9YBwDkqoJQ5ZDqRI+3mvbw
# x8pdYkmlJe0V5L8yQPMnL+IlFXIdwXL8H4y3AgMBAAGjggFJMIIBRTAdBgNVHQ4E
# FgQUWQfAagMnllsQSK7wqy2K6ypqjNAwHwYDVR0jBBgwFoAUn6cVXQBeYl2D9OXS
# ZacbUzUZ6XIwXwYDVR0fBFgwVjBUoFKgUIZOaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIw
# MTAoMSkuY3JsMGwGCCsGAQUFBwEBBGAwXjBcBggrBgEFBQcwAoZQaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBUaW1lLVN0
# YW1wJTIwUENBJTIwMjAxMCgxKS5jcnQwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8E
# DDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcNAQELBQADggIB
# AGIAz6equnAbb23FJe/jaj4KxN7YLhuhpF8WO70lpaQtMfCrumSc040vef5QbfH8
# HTzcQpeIVisCa6XsFMcIZdTrf/FGxnbCPdmZHQDh32d/2xoIlWbiO49UUFqL+iS0
# 45gfaP7X7MzvTCg3mieAH+m/LtfwB9jokHhc+9vzRDPt9jl511ufCPODWxmFQ8Vt
# tzB5Z4AIg2vOoUrraYx5cqaG258ytqiiAl4ld9ZjfHj+lu5uAQ1Pf6ldPrnbTcI8
# X2R90oTsYoAhFjLfGQFMO8V3x25+M6kKffycrqoyVW2cGMOFZAbQ8zcT+jEGzlQG
# sjqkFiSYge1uOJ8Oq4dP5OFpVXvEdzoiehJzdo3Nfj0kdSBCa68N0yMuRthd4DT/
# WrkjFKDZT7JxkE68CLe51k8qEDlXM4ON/+5y7+8W1ethxGSYYo3eO6Norf/IxmLY
# m7k0QvchJaivCntGN5mD4kwgrR+iy5WP5gKbmvrgsf8P1AkMCP5d9lo14V2/3Qrk
# DRBFEY/+mgH3JMhWMReP+4nOnwvgN3jiwCq6oM6Id2QuDF8ryc+qkJJY9n0b5EI+
# bzmj1wB/EQ22tK47BynIrPGxEJgIv48rj73yiuK30RUn8sugJ4b6MuWPQpoPhDLq
# xl7itYyvVutAuixMFk3AWdfE2MicJYF3SLuKzXJNL/ipMIIHcTCCBVmgAwIBAgIT
# MwAAABXF52ueAptJmQAAAAAAFTANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJv
# b3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5IDIwMTAwHhcNMjEwOTMwMTgyMjI1WhcN
# MzAwOTMwMTgzMjI1WjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDCCAiIw
# DQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAOThpkzntHIhC3miy9ckeb0O1YLT
# /e6cBwfSqWxOdcjKNVf2AX9sSuDivbk+F2Az/1xPx2b3lVNxWuJ+Slr+uDZnhUYj
# DLWNE893MsAQGOhgfWpSg0S3po5GawcU88V29YZQ3MFEyHFcUTE3oAo4bo3t1w/Y
# JlN8OWECesSq/XJprx2rrPY2vjUmZNqYO7oaezOtgFt+jBAcnVL+tuhiJdxqD89d
# 9P6OU8/W7IVWTe/dvI2k45GPsjksUZzpcGkNyjYtcI4xyDUoveO0hyTD4MmPfrVU
# j9z6BVWYbWg7mka97aSueik3rMvrg0XnRm7KMtXAhjBcTyziYrLNueKNiOSWrAFK
# u75xqRdbZ2De+JKRHh09/SDPc31BmkZ1zcRfNN0Sidb9pSB9fvzZnkXftnIv231f
# gLrbqn427DZM9ituqBJR6L8FA6PRc6ZNN3SUHDSCD/AQ8rdHGO2n6Jl8P0zbr17C
# 89XYcz1DTsEzOUyOArxCaC4Q6oRRRuLRvWoYWmEBc8pnol7XKHYC4jMYctenIPDC
# +hIK12NvDMk2ZItboKaDIV1fMHSRlJTYuVD5C4lh8zYGNRiER9vcG9H9stQcxWv2
# XFJRXRLbJbqvUAV6bMURHXLvjflSxIUXk8A8FdsaN8cIFRg/eKtFtvUeh17aj54W
# cmnGrnu3tz5q4i6tAgMBAAGjggHdMIIB2TASBgkrBgEEAYI3FQEEBQIDAQABMCMG
# CSsGAQQBgjcVAgQWBBQqp1L+ZMSavoKRPEY1Kc8Q/y8E7jAdBgNVHQ4EFgQUn6cV
# XQBeYl2D9OXSZacbUzUZ6XIwXAYDVR0gBFUwUzBRBgwrBgEEAYI3TIN9AQEwQTA/
# BggrBgEFBQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9Eb2Nz
# L1JlcG9zaXRvcnkuaHRtMBMGA1UdJQQMMAoGCCsGAQUFBwMIMBkGCSsGAQQBgjcU
# AgQMHgoAUwB1AGIAQwBBMAsGA1UdDwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8G
# A1UdIwQYMBaAFNX2VsuP6KJcYmjRPZSQW9fOmhjEMFYGA1UdHwRPME0wS6BJoEeG
# RWh0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jv
# b0NlckF1dF8yMDEwLTA2LTIzLmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYBBQUH
# MAKGPmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljUm9vQ2Vy
# QXV0XzIwMTAtMDYtMjMuY3J0MA0GCSqGSIb3DQEBCwUAA4ICAQCdVX38Kq3hLB9n
# ATEkW+Geckv8qW/qXBS2Pk5HZHixBpOXPTEztTnXwnE2P9pkbHzQdTltuw8x5MKP
# +2zRoZQYIu7pZmc6U03dmLq2HnjYNi6cqYJWAAOwBb6J6Gngugnue99qb74py27Y
# P0h1AdkY3m2CDPVtI1TkeFN1JFe53Z/zjj3G82jfZfakVqr3lbYoVSfQJL1AoL8Z
# thISEV09J+BAljis9/kpicO8F7BUhUKz/AyeixmJ5/ALaoHCgRlCGVJ1ijbCHcNh
# cy4sa3tuPywJeBTpkbKpW99Jo3QMvOyRgNI95ko+ZjtPu4b6MhrZlvSP9pEB9s7G
# dP32THJvEKt1MMU0sHrYUP4KWN1APMdUbZ1jdEgssU5HLcEUBHG/ZPkkvnNtyo4J
# vbMBV0lUZNlz138eW0QBjloZkWsNn6Qo3GcZKCS6OEuabvshVGtqRRFHqfG3rsjo
# iV5PndLQTHa1V1QJsWkBRH58oWFsc/4Ku+xBZj1p/cvBQUl+fpO+y/g75LcVv7TO
# PqUxUYS8vwLBgqJ7Fx0ViY1w/ue10CgaiQuPNtq6TPmb/wrpNPgkNWcr4A245oyZ
# 1uEi6vAnQj0llOZ0dFtq0Z4+7X6gMTN9vMvpe784cETRkPHIqzqKOghif9lwY1NN
# je6CbaUFEMFxBmoQtB1VM1izoXBm8qGCA00wggI1AgEBMIH5oYHRpIHOMIHLMQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNy
# b3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBF
# U046ODkwMC0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFNlcnZpY2WiIwoBATAHBgUrDgMCGgMVALvJxdVnHduwOkmSvtW5yCmSyjO4oIGD
# MIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQG
# A1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwDQYJKoZIhvcNAQEL
# BQACBQDudE2MMCIYDzIwMjYxMDEwMDUzNzE2WhgPMjAyNjEwMTEwNTM3MTZaMHQw
# OgYKKwYBBAGEWQoEATEsMCowCgIFAO50TYwCAQAwBwIBAAICCvowBwIBAAICE2sw
# CgIFAO51nwwCAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAKMAgC
# AQACAwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0BAQsFAAOCAQEAnu6ism2/eqMP
# qex29/ri+GXQCnqUfmGPNd/LR1k8wNRIiti1heGeGyvPb82bqzW+7oc2p7Iq5sGS
# lfAr634s5IVloin3GwPB6kNzsYoZy8LWrJg1Fd1F88u+oM//IeYRMRqe7TebdeiF
# P8+BFJrMKKifiLT/R42c1sBvs2ZFiGvwXed5/ylKnCs4J7o/au9u3IsnhLaWc+Ws
# t9Zmudzib9rCWENrlp6GWiv6OcOdqL7Vbpaj5jzkFRNoyT4X3sOrG3rpa22kjcFm
# qLiqoWrWCzZ8DPPyJwXfowo4pfP27vXfznO63i9MIhQ3gLT60GUrOGMp6DlwgRc+
# mIduhxmBRDGCBA0wggQJAgEBMIGTMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpX
# YXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQg
# Q29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAy
# MDEwAhMzAAACIkHS9qr/yLX/AAEAAAIiMA0GCWCGSAFlAwQCAQUAoIIBSjAaBgkq
# hkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIEIJysPBqtEeFh
# cEVRpgHSRZbNcUk8IA4yHA9WOhnEmDjRMIH6BgsqhkiG9w0BCRACLzGB6jCB5zCB
# 5DCBvQQgBWBdAQoE58aCM2ySYM6ZtwQg6ccY3AD5BxG58NHkCRMwgZgwgYCkfjB8
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1N
# aWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAiJB0vaq/8i1/wABAAAC
# IjAiBCCbFh0Xr7rnyjp4Dr/O6B80ynzINwPNl6flf/BWS8sVzzANBgkqhkiG9w0B
# AQsFAASCAgACHEP/czUNUrtHx/EcMbUFRAThjMCYA7ujL6Kp6VXI4fz0qkjohbhb
# 4zOb0a4R4TWVqZ8ChOKsV2sli8/HapMLyNV/5JTBTg5ZkWJFIq78VRszznAkF96j
# 0bGJL9njGzjDUxJbbipi22Pf7u6hHfZbG9Kz9jnOkkF+WvvA9xs6X1bywD0N9dgt
# aAYhiIcz4nTEWxl13i0riZYOL4OhevylsTkXIFbBJNXfHeScsoHLEbpR7jyUf8rt
# YJ5uU9ziObaJhT2y50APFabYDfo/hNflZH2MrHnHgZSWnAODIry7+tIsII/B1Xj0
# 1MFUpux99XWSZCMryYSLYLDZy5NasRr3ymNHXcnS6gPnj1wtvX6ffKiSbZEU0RF3
# o1B4+C5GVnbPPGLcgFLDvzMxGxILfSi3s9qD5tPOYLATaE7pTOTobheeBaswIDc4
# NbLIPkxPdKOkkGRQassFGeuY+T/oQA6kxwQiYcZPYocLwrhYPZcsXU/yB7c6Pawc
# cZCm5X5tmwMz2LI058MmhX+Yb9HDcgEywQ27TyYzxiLnS3y10fdt03a3SOb1vhPw
# f0SYosqh+NK+6gsXSF8Z3vqwq0M58ph2Xe5rqp60Ba3t8tRg5qx5QUn3V1aP+QjM
# rzPgqqj+Jn7UiWuM6kk+hsknFyOZPF9last9byku4pVQjzQhaYncaw==
# SIG # End signature block
