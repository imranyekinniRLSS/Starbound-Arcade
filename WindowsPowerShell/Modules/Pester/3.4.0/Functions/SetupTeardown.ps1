function BeforeEach
{
<#
.SYNOPSIS
    Defines a series of steps to perform at the beginning of every It block within
    the current Context or Describe block.

.DESCRIPTION
    BeforeEach, AfterEach, BeforeAll, and AfterAll are unique in that they apply
    to the entire Context or Describe block, regardless of the order of the
    statements in the Context or Describe.  For a full description of this
    behavior, as well as how multiple BeforeEach or AfterEach blocks interact
    with each other, please refer to the about_BeforeEach_AfterEach help file.

.LINK
    about_BeforeEach_AfterEach
#>
    Assert-DescribeInProgress -CommandName BeforeEach
}

function AfterEach
{
<#
.SYNOPSIS
    Defines a series of steps to perform at the end of every It block within
    the current Context or Describe block.

.DESCRIPTION
    BeforeEach, AfterEach, BeforeAll, and AfterAll are unique in that they apply
    to the entire Context or Describe block, regardless of the order of the
    statements in the Context or Describe.  For a full description of this
    behavior, as well as how multiple BeforeEach or AfterEach blocks interact
    with each other, please refer to the about_BeforeEach_AfterEach help file.

.LINK
    about_BeforeEach_AfterEach
#>
    Assert-DescribeInProgress -CommandName AfterEach
}

function BeforeAll
{
<#
.SYNOPSIS
    Defines a series of steps to perform at the beginning of the current Context
    or Describe block.

.DESCRIPTION
    BeforeEach, AfterEach, BeforeAll, and AfterAll are unique in that they apply
    to the entire Context or Describe block, regardless of the order of the
    statements in the Context or Describe.

.LINK
    about_BeforeEach_AfterEach
#>
    Assert-DescribeInProgress -CommandName BeforeAll
}

function AfterAll
{
<#
.SYNOPSIS
    Defines a series of steps to perform at the end of every It block within
    the current Context or Describe block.

.DESCRIPTION
    BeforeEach, AfterEach, BeforeAll, and AfterAll are unique in that they apply
    to the entire Context or Describe block, regardless of the order of the
    statements in the Context or Describe.

.LINK
    about_BeforeEach_AfterEach
#>
    Assert-DescribeInProgress -CommandName AfterAll
}

function Clear-SetupAndTeardown
{
    $pester.BeforeEach = @( $pester.BeforeEach | & $SafeCommands['Where-Object'] { $_.Scope -ne $pester.Scope } )
    $pester.AfterEach  = @( $pester.AfterEach  | & $SafeCommands['Where-Object'] { $_.Scope -ne $pester.Scope } )
    $pester.BeforeAll  = @( $pester.BeforeAll  | & $SafeCommands['Where-Object'] { $_.Scope -ne $pester.Scope } )
    $pester.AfterAll   = @( $pester.AfterAll   | & $SafeCommands['Where-Object'] { $_.Scope -ne $pester.Scope } )
}

function Invoke-TestCaseSetupBlocks
{
    $orderedSetupBlocks = @(
        $pester.BeforeEach | & $SafeCommands['Where-Object'] { $_.Scope -eq 'Describe' } | & $SafeCommands['Select-Object'] -ExpandProperty ScriptBlock
        $pester.BeforeEach | & $SafeCommands['Where-Object'] { $_.Scope -eq 'Context'  } | & $SafeCommands['Select-Object'] -ExpandProperty ScriptBlock
    )

    Invoke-Blocks -ScriptBlock $orderedSetupBlocks
}

function Invoke-TestCaseTeardownBlocks
{
    $orderedTeardownBlocks = @(
        $pester.AfterEach | & $SafeCommands['Where-Object'] { $_.Scope -eq 'Context'  } | & $SafeCommands['Select-Object'] -ExpandProperty ScriptBlock
        $pester.AfterEach | & $SafeCommands['Where-Object'] { $_.Scope -eq 'Describe' } | & $SafeCommands['Select-Object'] -ExpandProperty ScriptBlock
    )

    Invoke-Blocks -ScriptBlock $orderedTeardownBlocks
}

function Invoke-TestGroupSetupBlocks
{
    param ([string] $Scope)

    $scriptBlocks = $pester.BeforeAll |
                    & $SafeCommands['Where-Object'] { $_.Scope -eq $Scope } |
                    & $SafeCommands['Select-Object'] -ExpandProperty ScriptBlock

    Invoke-Blocks -ScriptBlock $scriptBlocks
}

function Invoke-TestGroupTeardownBlocks
{
    param ([string] $Scope)

    $scriptBlocks = $pester.AfterAll |
                    & $SafeCommands['Where-Object'] { $_.Scope -eq $Scope } |
                    & $SafeCommands['Select-Object'] -ExpandProperty ScriptBlock

    Invoke-Blocks -ScriptBlock $scriptBlocks
}

function Invoke-Blocks
{
    param ([scriptblock[]] $ScriptBlock)

    foreach ($block in $ScriptBlock)
    {
        if ($null -eq $block) { continue }
        $null = . $block
    }
}

function Add-SetupAndTeardown
{
    param (
        [scriptblock] $ScriptBlock
    )

    if ($PSVersionTable.PSVersion.Major -le 2)
    {
        Add-SetupAndTeardownV2 -ScriptBlock $ScriptBlock
    }
    else
    {
        Add-SetupAndTeardownV3 -ScriptBlock $ScriptBlock
    }
}

function Add-SetupAndTeardownV3
{
    param (
        [scriptblock] $ScriptBlock
    )

    $pattern = '^(?:Before|After)(?:Each|All)$'
    $predicate = {
        param ([System.Management.Automation.Language.Ast] $Ast)

        $Ast -is [System.Management.Automation.Language.CommandAst] -and
        $Ast.CommandElements.Count -eq 2 -and
        $Ast.CommandElements[0].ToString() -match $pattern -and
        $Ast.CommandElements[1] -is [System.Management.Automation.Language.ScriptBlockExpressionAst]
    }

    $searchNestedBlocks = $false

    $calls = $ScriptBlock.Ast.FindAll($predicate, $searchNestedBlocks)

    foreach ($call in $calls)
    {
        # For some reason, calling ScriptBlockAst.GetScriptBlock() sometimes blows up due to failing semantics
        # checks, even though the code is perfectly valid.  So we'll poke around with reflection again to skip
        # that part and just call the internal ScriptBlock constructor that we need

        $iPmdProviderType = [scriptblock].Assembly.GetType('System.Management.Automation.Language.IParameterMetadataProvider')

        $flags = [System.Reflection.BindingFlags]'Instance, NonPublic'
        $constructor = [scriptblock].GetConstructor($flags, $null, [Type[]]@($iPmdProviderType, [bool]), $null)

        $block = $constructor.Invoke(@($call.CommandElements[1].ScriptBlock, $false))

        Set-ScriptBlockScope -ScriptBlock $block -SessionState $pester.SessionState
        $commandName = $call.CommandElements[0].ToString()
        Add-SetupOrTeardownScriptBlock -CommandName $commandName -ScriptBlock $block
    }
}

function Add-SetupAndTeardownV2
{
    param (
        [scriptblock] $ScriptBlock
    )

    $codeText = $ScriptBlock.ToString()
    $tokens = @(ParseCodeIntoTokens -CodeText $codeText)

    for ($i = 0; $i -lt $tokens.Count; $i++)
    {
        $token = $tokens[$i]
        $type = $token.Type
        if ($type -eq [System.Management.Automation.PSTokenType]::Command -and
            (IsSetupOrTeardownCommand -CommandName $token.Content))
        {
            $openBraceIndex, $closeBraceIndex = Get-BraceIndecesForCommand -Tokens $tokens -CommandIndex $i

            $block = Get-ScriptBlockFromTokens -Tokens $Tokens -OpenBraceIndex $openBraceIndex -CloseBraceIndex $closeBraceIndex -CodeText $codeText
            Add-SetupOrTeardownScriptBlock -CommandName $token.Content -ScriptBlock $block

            $i = $closeBraceIndex
        }
        elseif ($type -eq [System.Management.Automation.PSTokenType]::GroupStart)
        {
            # We don't want to parse Setup or Teardown commands in child scopes here, so anything
            # bounded by a GroupStart / GroupEnd token pair which is not immediately preceded by
            # a setup / teardown command name is ignored.
            $i = Get-GroupCloseTokenIndex -Tokens $tokens -GroupStartTokenIndex $i
        }
    }
}

function ParseCodeIntoTokens
{
    param ([string] $CodeText)

    $parseErrors = $null
    $tokens = [System.Management.Automation.PSParser]::Tokenize($CodeText, [ref] $parseErrors)

    if ($parseErrors.Count -gt 0)
    {
        $currentScope = $pester.Scope
        throw "The current $currentScope block contains syntax errors."
    }

    return $tokens
}

function IsSetupOrTeardownCommand
{
    param ([string] $CommandName)
    return (IsSetupCommand -CommandName $CommandName) -or (IsTeardownCommand -CommandName $CommandName)
}

function IsSetupCommand
{
    param ([string] $CommandName)
    return $CommandName -eq 'BeforeEach' -or $CommandName -eq 'BeforeAll'
}

function IsTeardownCommand
{
    param ([string] $CommandName)
    return $CommandName -eq 'AfterEach' -or $CommandName -eq 'AfterAll'
}

function IsTestGroupCommand
{
    param ([string] $CommandName)
    return $CommandName -eq 'BeforeAll' -or $CommandName -eq 'AfterAll'
}

function Get-BraceIndecesForCommand
{
    param (
        [System.Management.Automation.PSToken[]] $Tokens,
        [int] $CommandIndex
    )

    $openingGroupTokenIndex = Get-GroupStartTokenForCommand -Tokens $Tokens -CommandIndex $CommandIndex
    $closingGroupTokenIndex = Get-GroupCloseTokenIndex -Tokens $Tokens -GroupStartTokenIndex $openingGroupTokenIndex

    return $openingGroupTokenIndex, $closingGroupTokenIndex
}

function Get-GroupStartTokenForCommand
{
    param (
        [System.Management.Automation.PSToken[]] $Tokens,
        [int] $CommandIndex
    )

    # We may want to allow newlines, other parameters, etc at some point.  For now it's good enough to
    # just verify that the next token after our BeforeEach or AfterEach command is an opening curly brace.

    $commandName = $Tokens[$CommandIndex].Content

    if ($CommandIndex + 1 -ge $tokens.Count -or
        $tokens[$CommandIndex + 1].Type -ne [System.Management.Automation.PSTokenType]::GroupStart -or
        $tokens[$CommandIndex + 1].Content -ne '{')
    {
        throw "The $commandName command must be immediately followed by the opening brace of a script block."
    }

    return $CommandIndex + 1
}

& $SafeCommands['Add-Type'] -TypeDefinition @'
    namespace Pester
    {
        using System;
        using System.Management.Automation;

        public static class ClosingBraceFinder
        {
            public static int GetClosingBraceIndex(PSToken[] tokens, int startIndex)
            {
                int groupLevel = 1;
                int len = tokens.Length;

                for (int i = startIndex + 1; i < len; i++)
                {
                    PSTokenType type = tokens[i].Type;
                    if (type == PSTokenType.GroupStart)
                    {
                        groupLevel++;
                    }
                    else if (type == PSTokenType.GroupEnd)
                    {
                        groupLevel--;

                        if (groupLevel <= 0) { return i; }
                    }
                }

                return -1;
            }
        }
    }
'@

function Get-GroupCloseTokenIndex
{
    param (
        [System.Management.Automation.PSToken[]] $Tokens,
        [int] $GroupStartTokenIndex
    )

    $closeIndex = [Pester.ClosingBraceFinder]::GetClosingBraceIndex($Tokens, $GroupStartTokenIndex)

    if ($closeIndex -lt 0)
    {
        throw 'No corresponding GroupEnd token was found.'
    }

    return $closeIndex
}

function Get-ScriptBlockFromTokens
{
    param (
        [System.Management.Automation.PSToken[]] $Tokens,
        [int] $OpenBraceIndex,
        [int] $CloseBraceIndex,
        [string] $CodeText
    )

    $blockStart = $Tokens[$OpenBraceIndex + 1].Start
    $blockLength = $Tokens[$CloseBraceIndex].Start - $blockStart
    $setupOrTeardownCodeText = $codeText.Substring($blockStart, $blockLength)

    $scriptBlock = [scriptblock]::Create($setupOrTeardownCodeText)
    Set-ScriptBlockScope -ScriptBlock $scriptBlock -SessionState $pester.SessionState

    return $scriptBlock
}

function Add-SetupOrTeardownScriptBlock
{
    param (
        [string] $CommandName,
        [scriptblock] $ScriptBlock
    )

    $isSetupCommand = IsSetupCommand -CommandName $CommandName
    $isGroupCommand = IsTestGroupCommand -CommandName $CommandName

    if ($isSetupCommand)
    {
        if ($isGroupCommand)
        {
            Add-BeforeAll -ScriptBlock $ScriptBlock
        }
        else
        {
            Add-BeforeEach -ScriptBlock $ScriptBlock
        }
    }
    else
    {
        if ($isGroupCommand)
        {
            Add-AfterAll -ScriptBlock $ScriptBlock
        }
        else
        {
            Add-AfterEach -ScriptBlock $ScriptBlock
        }
    }
}

function Add-BeforeEach
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock
    )

    $props = @{
        Scope       = $pester.Scope
        ScriptBlock = $ScriptBlock
    }

    $pester.BeforeEach += @(& $SafeCommands['New-Object'] psobject -Property $props)
}

function Add-AfterEach
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock
    )

    $props = @{
        Scope       = $pester.Scope
        ScriptBlock = $ScriptBlock
    }

    $pester.AfterEach += @(& $SafeCommands['New-Object'] psobject -Property $props)
}

function Add-BeforeAll
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock
    )

    $props = @{
        Scope       = $pester.Scope
        ScriptBlock = $ScriptBlock
    }

    $pester.BeforeAll += @(& $SafeCommands['New-Object'] psobject -Property $props)
}

function Add-AfterAll
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock
    )

    $props = @{
        Scope       = $pester.Scope
        ScriptBlock = $ScriptBlock
    }

    $pester.AfterAll += @(& $SafeCommands['New-Object'] psobject -Property $props)
}

# SIG # Begin signature block
# MIInXgYJKoZIhvcNAQcCoIInTzCCJ0sCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCXY4Q7g3V96Vnk
# uJlLiTyJAgqODpDvSo9oFPM3kG+TBKCCC7QwggXLMIIEs6ADAgECAhMzAAABQGf2
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
# V2Tt+dsyg2aUJSPh0fJYAL8QrcswJBZNFmQ/uD4lbVwwUAYKKwYBBAGCNwoDHDFC
# DEA3Q0E2MUIwQzUyQzFFRENENzE4MUQxQjhGNjdGQjdDMkVERTc3MzY1MTMyRTMw
# OEMxNjNEQzIzRjkyNDUzNzEyMFoGCisGAQQBgjcCAQwxTDBKoCSAIgBNAGkAYwBy
# AG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0cDovL3d3dy5taWNyb3Nv
# ZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggGALb3NLnyD1MGK/BfvzzQ4
# X6wgNoSeQ1TyJWizfkfiLtTRKaOhzOfn72KP5FJdOMdGC3M67kj5QEsLBY+MUGoe
# K0Qj0vfjkqhFoEfueyDUxEjm32PMAnEAv0Wr6t6eZ/VSFo4G7+T1R4bxBaB/6Akm
# MX98sdHPNwDC4xfR5EDVvhl7xdjMTzbpKjOq+I1AeaLoFGak6XroWHRQphh6/8X4
# 4alya56CZ7M5WVNNC9raJObpFqfIzAEG5ASyu3vENrn9cLGF6hWWZWPZaNJs4qw2
# hzOJMblODe3EdVC0SENEnVTz7EzFWzNg8K0+8l8+fhiNCSwH/IVSg6yoMKCcg0uo
# qreLarucSPr8lJFTRyA1reFDa/cg+2XQ0Dik2Gz/yOh4DTfvYduouGfTJ44gKsDO
# ub54PgSWPdBTiEhhKoHfjSLGBLZtt6Yp6XeucJtzydu/W8RV/P06e/8WN1/LGPuU
# KU0/UXLIVus/AReN0D+1Fda4BqmAHFEKtDiaPg5PUHT8oYIXrTCCF6kGCisGAQQB
# gjcDAwExgheZMIIXlQYJKoZIhvcNAQcCoIIXhjCCF4ICAQMxDzANBglghkgBZQME
# AgEFADCCAVoGCyqGSIb3DQEJEAEEoIIBSQSCAUUwggFBAgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIFvEMnYTdbwA5F3ZkEKx/9SmwhCVdyRfigH2p//T
# iOYNAgZqrmIEoSoYEzIwMjYxMDEwMDgzNjQzLjk3MVowBIACAfSggdmkgdYwgdMx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1p
# Y3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEnMCUGA1UECxMeblNo
# aWVsZCBUU1MgRVNOOjRDMUEtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQg
# VGltZS1TdGFtcCBTZXJ2aWNloIIR+zCCBygwggUQoAMCAQICEzMAAAIYJdmSBeLn
# 5eQAAQAAAhgwDQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENB
# IDIwMTAwHhcNMjUwODE0MTg0ODI1WhcNMjYxMTEzMTg0ODI1WjCB0zELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWljcm9zb2Z0
# IElyZWxhbmQgT3BlcmF0aW9ucyBMaW1pdGVkMScwJQYDVQQLEx5uU2hpZWxkIFRT
# UyBFU046NEMxQS0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCx3Ojq
# 65AmoB/Eue8QF8i+PqScr6npucxcQVn9CM84XLCVyMN/MjwODWfMOXGbv+mpu+Na
# HK9rMqYXI7qps/AKV9GcjnuHk4KLGCk44IYklAhlJOIyC6LcHwM+IW0k9x/NG3cW
# yfGMtfAEiMaCeMZ+ZCXvN6MDVahgv+oGZCHD8UMVNZ5vF+jibREII7F/arCPfVo6
# NzZphR4+0sxcexco8UfS2nlIogX/20nFFKDQ1gS9CpWKWN7xpCQ93erMC7HYxzkc
# xIrg0xO1VUJgBYNRnin7qIMj23kE0IEix/migU1Ra3EKqekViItiQd8V/GFVQFnw
# sYbFiwDfqycPrmzYd/i3zqTR7xZ6Uf+6x+Fio4zfPbJojyuDTzrfUiTCpTPJCgQ+
# oyweAF6bXGmY4ZIhSdW9OwC/6WYQIvZGqtw5mVlrHwrRqKKPyHpSRYE3YgD+KRpy
# RNIZVEFCZZZm4sVZX9PjG43OxwLRfvGjh962CmypoQDSNj9B6+RO8u/g6U03144v
# ws2HtWbRHrk/uhps5AOq1QUDAKCOA8nSJX+NAJowBw7dJikbnBIBiImSThcuM1KU
# 3FTYh2OzWw5GGXuzssLqE5vttUAdXA43vgbF8U2IQgDoF+50A2OlAnSdRz+mkRel
# PimAMEexi1Xw7IpKMqwjE50VHt8gkiMNzwO9SQIDAQABo4IBSTCCAUUwHQYDVR0O
# BBYEFCQuocRcOhtjt0e6hAIFrixftovRMB8GA1UdIwQYMBaAFJ+nFV0AXmJdg/Tl
# 0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly93d3cubWljcm9zb2Z0
# LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAy
# MDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYIKwYBBQUHMAKGUGh0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwVGltZS1T
# dGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/
# BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUAA4IC
# AQCeSNGGPA+B2gim+3hiKhP+PQta4HEXcBEEpcMQ2CCtoq8LShE/BuMCaxec8Sa2
# 6jkwPy4n1fD15ivGqqQrgMX2ydkyscx+ijEJr77WKsvPxiijMLi1yL5rg3ftJuR7
# Wm3XGz2pm2+Q+BkZafkFzBV+YDBJkseLYK5nTpjT9f63p80GetsxWi81oNfhY93I
# j0YTPF8iCAOxyTYimjhVcv8CtzPunYXtsRkZG7LGOAwL7CgKQMlof/KT/BxmkCyL
# F7g8503QNbplvfk7cODf5rqmsA0xzdYh298oOXvk/RqpxBtABHtvR/iAfg0yRRy3
# RabgY3kqGwTVgrtX/ACoMqYriPHfMvPdrwezFr0cHcbKK2WYLmwOE6XhBMY3mRGL
# qgKhXiEr6QgWCeRaMeFJE2ibPfpCdsJIb8EcsSbYZFT27f8jjNR30TUAL3sgkQZ/
# Bv7Q1ZvdARyuTKl0Z1bCXQsQ5uGtBH0HVXv551zI2axfSnYFfSsWl3U+RclJvF/w
# hwSLD9uQ2BqBkT5WUO3Fd6u4t2jmTeUY6/us9i44RqhljEO9m2kc/0/frCZbgg2N
# Ho0iefZQz6Ss//F4udFsMGSb1GyWegOFWtqWIoMfrYHGFyAv22JGA4eVwjTCq9VY
# t2/zJbyvGRrA6WEJGpPcQoQJbyS1QA/A1sFQuRP6hZy8FzCCB3EwggVZoAMCAQIC
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
# aWVsZCBUU1MgRVNOOjRDMUEtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQg
# VGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQCda0atdaK40TxCsp+b
# gK0avnvP6aCBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0G
# CSqGSIb3DQEBCwUAAgUA7nPk+TAiGA8yMDI2MTAwOTIyMTEwNVoYDzIwMjYxMDEw
# MjIxMTA1WjB0MDoGCisGAQQBhFkKBAExLDAqMAoCBQDuc+T5AgEAMAcCAQACAg0I
# MAcCAQACAhLhMAoCBQDudTZ5AgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQB
# hFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEB
# ACb3+MMBXNq2cZUjldOz/WefBTvewg5apSpw0Yt1mGsx7DrUDHKce3OmBKwStf4Y
# BVo2ETQnBYnHdpQVABFIlVyXchLbjxBKw8szZFEGHMZ7zTOl83l0LMnREVYESK3x
# B+ZwgR4mWVxLG9sj9ca5ttvEyCzinzGDAxyqSkOiu1g7ojESGSk2jYaQMU7K8bEz
# AJML9qXavjBO246Zas8sbt9lmTDZp1OR619ezitkytT8uz5tAeKdv5YQFUzttSqZ
# B45wtsxdNcdbfAiLm4TkpLKfuW8rvvtxgxiHKMc1/lnQ/4i+fX9GOtekkhRTLOAb
# UXpuywaGe7zVk90MXC7+bPcxggQNMIIECQIBATCBkzB8MQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1T
# dGFtcCBQQ0EgMjAxMAITMwAAAhgl2ZIF4ufl5AABAAACGDANBglghkgBZQMEAgEF
# AKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJBDEi
# BCDNAoBxvKzoIYbF/S61aP9p5mGuCnmKXb53IO4t1KcykzCB+gYLKoZIhvcNAQkQ
# Ai8xgeowgecwgeQwgb0EIJkT3Im45Mi0jBZoRLqXMYorVdxKjPXKdHNo5XPH14Vq
# MIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAO
# BgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEm
# MCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAIYJdmS
# BeLn5eQAAQAAAhgwIgQgfeCxLFMj36K8gqKUlSDJUD0CuEQ9Qcxrbr5lXU4vMecw
# DQYJKoZIhvcNAQELBQAEggIANqEsYQAneoyjYO/LkJSStOVsIxoWli9k9Vyuu1eZ
# bkO7xSRkT9/fj9NLvEvy2vN76MIRY/0KvHgNUWZkugK346zSaWT5DWzDR4t8/Fg/
# dDAAg/SuFF3rxS7IHCMAZ+UbRfUC/UJ0BrhoSn9XKJS3CYmRQVGNh5PZrq7aGtiH
# Ck9JHF/0JeYUnnW273rBLMo5Z0L+i9ZzorABaYAq273KFEAPd6hQvbGsucAMygEC
# hFgtcTVSpR56GqrGND3jl1K3iC7zXWZGAiH8CYWddO8stt5KIfiaVsOxOGT3tJDq
# fZ9Juwxpxdd3iSxhgXapio03zLJwhcssjeuPBpNAfbhQmpJI5nFcGjzwfHWRXQUW
# J7VlUbhtsJh62cR4s4bVGHNs2P1A9fbubDIHsoI1bPRLHNcWoAjna/KBRaJ0geVU
# hepSaHYW9A5gWXHYaCzt4fRscwUb1FLgTPx9TnjYRXNSKsRnCIsF5dmZyutLC7av
# UXmgTXtnwPpNWZ3I3NMojgeBPsYqM4HaGZShZIlRmA95bnmwKOwhZgpvbfR/7Xr0
# XBWIs/DdAGmQhC5erQnUJgRBDbnTsOye1abpwzt/VGs8SHaj8L7l1O77rszJgONe
# JViNLEnQxu2TNmPLT3Z4RUHnXOVsBHmBWqbFsTy883lSf411p5cWISh/9P8vjQu7
# 3Bc=
# SIG # End signature block
