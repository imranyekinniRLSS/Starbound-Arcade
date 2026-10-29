function Describe {
<#
.SYNOPSIS
Creates a logical group of tests.  All Mocks and TestDrive contents
defined within a Describe block are scoped to that Describe; they
will no longer be present when the Describe block exits.  A Describe
block may contain any number of Context and It blocks.

.PARAMETER Name
The name of the test group. This is often an expressive phrase describing the scenario being tested.

.PARAMETER Fixture
The actual test script. If you are following the AAA pattern (Arrange-Act-Assert), this
typically holds the arrange and act sections. The Asserts will also lie in this block but are
typically nested each in its own It block. Assertions are typically performed by the Should
command within the It blocks.

.PARAMETER Tags
Optional parameter containing an array of strings.  When calling Invoke-Pester, it is possible to
specify a -Tag parameter which will only execute Describe blocks containing the same Tag.

.EXAMPLE
function Add-Numbers($a, $b) {
    return $a + $b
}

Describe "Add-Numbers" {
    It "adds positive numbers" {
        $sum = Add-Numbers 2 3
        $sum | Should Be 5
    }

    It "adds negative numbers" {
        $sum = Add-Numbers (-2) (-2)
        $sum | Should Be (-4)
    }

    It "adds one negative number to positive number" {
        $sum = Add-Numbers (-2) 2
        $sum | Should Be 0
    }

    It "concatenates strings if given strings" {
        $sum = Add-Numbers two three
        $sum | Should Be "twothree"
    }
}

.LINK
It
Context
Invoke-Pester
about_Should
about_Mocking
about_TestDrive

#>

    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Name,
        $Tags=@(),
        [Parameter(Position = 1)]
        [ValidateNotNull()]
        [ScriptBlock] $Fixture = $(Throw "No test script block is provided. (Have you put the open curly brace on the next line?)")
    )

    if ($null -eq (& $SafeCommands['Get-Variable'] -Name Pester -ValueOnly -ErrorAction $script:IgnoreErrorPreference))
    {
        # User has executed a test script directly instead of calling Invoke-Pester
        $Pester = New-PesterState -Path (& $SafeCommands['Resolve-Path'] .) -TestNameFilter $null -TagFilter @() -SessionState $PSCmdlet.SessionState
        $script:mockTable = @{}
    }

    if($Pester.TestNameFilter-and -not ($Pester.TestNameFilter | & $SafeCommands['Where-Object'] { $Name -like $_ }))
    {
        #skip this test
        return
    }

    #TODO add test to test tags functionality
    if($Pester.TagFilter -and @(& $SafeCommands['Compare-Object'] $Tags $Pester.TagFilter -IncludeEqual -ExcludeDifferent).count -eq 0) {return}
    if($Pester.ExcludeTagFilter -and @(& $SafeCommands['Compare-Object'] $Tags $Pester.ExcludeTagFilter -IncludeEqual -ExcludeDifferent).count -gt 0) {return}

    $Pester.EnterDescribe($Name)

    $Pester.CurrentDescribe | Write-Describe
    $testDriveAdded = $false

    try
    {
        New-TestDrive
        $testDriveAdded = $true

        Add-SetupAndTeardown -ScriptBlock $Fixture
        Invoke-TestGroupSetupBlocks -Scope $pester.Scope

        do
        {
            $null = & $Fixture
        } until ($true)
    }
    catch
    {
        $firstStackTraceLine = $_.InvocationInfo.PositionMessage.Trim() -split '\r?\n' | & $SafeCommands['Select-Object'] -First 1
        $Pester.AddTestResult('Error occurred in Describe block', "Failed", $null, $_.Exception.Message, $firstStackTraceLine, $null, $null, $_)
        $Pester.TestResult[-1] | Write-PesterResult
    }
    finally
    {
        Invoke-TestGroupTeardownBlocks -Scope $pester.Scope
        if ($testDriveAdded) { Remove-TestDrive }
    }

    Clear-SetupAndTeardown
    Exit-MockScope
    $Pester.LeaveDescribe()
}

function Assert-DescribeInProgress
{
    param ($CommandName)
    if ($null -eq $Pester -or [string]::IsNullOrEmpty($Pester.CurrentDescribe))
    {
        throw "The $CommandName command may only be used inside a Describe block."
    }
}

# SIG # Begin signature block
# MIInYQYJKoZIhvcNAQcCoIInUjCCJ04CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCClpO2nXjORG9DH
# C75dW2xlobh4sV1kKTEAb4tQyegcA6CCC7QwggXLMIIEs6ADAgECAhMzAAABQGf2
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
# GwMwghr/AgEBMIGmMIGOMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMTgwNgYDVQQDEy9NaWNyb3NvZnQgV2luZG93cyBUaGlyZCBQYXJ0eSBDb21w
# b25lbnQgQ0EgMjAxMgITMwAAAUBn9phrMQi4cgAAAAABQDANBglghkgBZQMEAgEF
# AKCB+jAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAvBgkqhkiG9w0BCQQxIgQg
# g6XZ21LUPuD8e7YuiGQqsXsN8AeDS98tISTkezFypB8wUAYKKwYBBAGCNwoDHDFC
# DEAzODU3OTA5OUY5MUU3MjBGRDQxQUJEMzIwODY0NTE4QkNGNzk4NkI1MDZFRjND
# MTVCNTkyM0IyOEI3QkZFQjMzMFoGCisGAQQBgjcCAQwxTDBKoCSAIgBNAGkAYwBy
# AG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0cDovL3d3dy5taWNyb3Nv
# ZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggGAqp9jCNtB5S39glgETj4z
# PCnaRYqDZT0rX0Pevq41IlJHbPyOn8EsPBIYxrRXA+93NDeejvKSnWQCDVcDpVNU
# 2QTOcr3OwXgvsC7XF/Y5yCBNBACw/IQKqgzJg9HJfXUdqKY48zXJt787zCyNK6W3
# GwjJGLkmIKMJRyLz0Wzguu0mbuREx6lV84o4ktgwURfSbK+p+EhrrAXIzLlgB9Op
# HySFDPfJoKDF4X0OpMr91MtFVpGQ1gD/79I/wSntw8aBTVzK0UeyodsR5v3H8fdB
# Jw301uHtuumAXywVU29tiT33nvRefqyR4sD2Cj0UPBsbnxxZKz5G6IiUcvs+dRvr
# 3ug5999MA76l1MUiBOzsd8OduIGgf1ycgUnIOrRdA91YTdYOi0g/SQp/nmF6BjuB
# 35++P92UujTOlGoxInmmdAJl3/MtQ+xjlTNnqWj/AvJyuOoQfjDEjuLSsr3HIZt8
# 4Q/lgaOsRN2QoHNl4giBiGKp8Sbj59+diS4/bD4zscsHoYIXsDCCF6wGCisGAQQB
# gjcDAwExghecMIIXmAYJKoZIhvcNAQcCoIIXiTCCF4UCAQMxDzANBglghkgBZQME
# AgEFADCCAVoGCyqGSIb3DQEJEAEEoIIBSQSCAUUwggFBAgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIKy87yxxbBtzBN/3E6xrc4P8rKXVjgkK0NvQD4ua
# 4o5CAgZqxOUyk4EYEzIwMjYxMDEwMDgzNjM2Ljg0MVowBIACAfSggdmkgdYwgdMx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1p
# Y3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEnMCUGA1UECxMeblNo
# aWVsZCBUU1MgRVNOOjMyMUEtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQg
# VGltZS1TdGFtcCBTZXJ2aWNloIIR/jCCBygwggUQoAMCAQICEzMAAAIaqaAdBqAP
# Q6oAAQAAAhowDQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENB
# IDIwMTAwHhcNMjUwODE0MTg0ODI4WhcNMjYxMTEzMTg0ODI4WjCB0zELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWljcm9zb2Z0
# IElyZWxhbmQgT3BlcmF0aW9ucyBMaW1pdGVkMScwJQYDVQQLEx5uU2hpZWxkIFRT
# UyBFU046MzIxQS0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCZgQDB
# JPPv2rZXdlbNDkS/tEqBp1C0wHLv5XddDxHQ0vxH2a6nFyolD8o95kYlMRH71Cr+
# 3sc5B8FsPLp7RN6m8EVX9FjfD4s48wqfRSiHb/wi91JsnyoBZFWjPZL1WsnNmkHz
# 9/mtBxEROBf+3w3roPYmURe/h9lAHtfNwkxevWm6G5ds631FgTI3VDdntiNGSF8G
# xFz5IP8L0XiLBmp9CCjzYYbjCC4iGMlTv5cx+u/i/EAU1WDeafU+gxYZlaKj57Xj
# 48Zg9UsqVp37QiF0crkCA/JcqSoCERmliFhhUQi0c46+qvC6TFUAlcy9YDcZq1aR
# FmffdYMlW2CEJbpc8uLVwMqIYTlRxdlJXg6NAhQHy+nYtQxFe53kjj0UgFwT2dPT
# TPwD4R6Ss8z44CTTtoN/Blt2ZnnqPu5vl80Mt/zIhvxDFnwyvhHBbL9zMG5XmuRZ
# BD6ayMnkAq1hnEl2dpl6FSBQ0CtT+7fpIfV5coxAZFev/F4oUYjy++/kmXWSdnxS
# oRCv0/ENuKzs5enZZIwrmUsZ1hUfxWjCdgXexs6JGTHlDkZoTJN6E5CnZJ91uwlm
# WDRJeYemEaehbX+BD/k/oGBKrg8BYhloMmPoC8ssJ1tRGBHlqk1BB53bNhSBRuMA
# ID9OiYDwuXsCuu/ahkaJQ7lV2LjHG0DcFFNBNQIDAQABo4IBSTCCAUUwHQYDVR0O
# BBYEFPCrIgndAyg9qwNwZ0ai9tpjwiU2MB8GA1UdIwQYMBaAFJ+nFV0AXmJdg/Tl
# 0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly93d3cubWljcm9zb2Z0
# LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAy
# MDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYIKwYBBQUHMAKGUGh0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwVGltZS1T
# dGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/
# BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUAA4IC
# AQDVrvZYWrsHpslPdU4nbWedOg8n07+rnVvDVuE99DLru7L5/zHxqSKnM0vaTlvq
# a3G49tkakGqkEqC4PBCbFWlfxwaZp96jfAavhrxiTpLLT20SH83DCWzKrsFGsk2f
# psY4HyIbg5PL6mYxSHsV6M09GC+B6j84/K2bg02swyD3xRWWtnEY05iyJ+lEkWDm
# MT9i7qWoVrWVOb1we49jFZragTALSwQCxMVvr2Iqk3Sw7X3EFkKvSHkKVT0+Cjp6
# SIlvtAmgPOsOg9AfBs0DzsK2jtMu6mGPSb2X8jvSAuMSrndIeO5RHPCmY3F2bXxC
# D6uWRowLpjYq6Q58nugJK729w0ZAz6KeX2Cw2CKtnrImT1WxcSyhO2hHt8w1To/L
# q58lAYxOarpkKrZ4gY5dYwFvv1kXq2IpNripqaLdRLSZNjjUnXb1eYCCVXL66NJm
# Qe7aUckNEezsWOchdlVQTmmXrJQiXbeMbnR9FMtBxK13Bj8u8lSAQcIjOO+UtOou
# 3olVHltyzlo3gOHRg8b3kH2IMxmuriuWLlKcY1Z6/ksuwNjV9usrq5WkP6my9Iuw
# 2mG3btBwdGxh0AwAtcz4c2zPYtnzGI5/C3qs6xVZeiIdXzr9N4zLlNkVSXuoHn0g
# 2gxImANGVp1Vd5P1/A66KsUiiqCMoaTe87ZsQutgw3RBXDCCB3EwggVZoAMCAQIC
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
# TY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggNZMIICQQIBATCCAQGhgdmkgdYwgdMx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1p
# Y3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEnMCUGA1UECxMeblNo
# aWVsZCBUU1MgRVNOOjMyMUEtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQg
# VGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQDxiu62YqlKu5sJoBix
# Tim3UW3wNqCBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0G
# CSqGSIb3DQEBCwUAAgUA7nQAcTAiGA8yMDI2MTAxMDAwMDgxN1oYDzIwMjYxMDEx
# MDAwODE3WjB3MD0GCisGAQQBhFkKBAExLzAtMAoCBQDudABxAgEAMAoCAQACAgDq
# AgH/MAcCAQACAhK0MAoCBQDudVHxAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisG
# AQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQAD
# ggEBALk7Mlh2mmAdg7prUEklIaBwzvX5MXnCnGIR8oKjTCyUxgLNmyP2rgW47OcE
# d8qhOhLQ+OYmvjfOPGyOn4F53gFVzPlAX2XVfNEScfSqoFRfQOlOcrnS65dKrhF3
# eGhIdeq89zHfcQCAAUiZnrMDz3QQX2ZEgdU29Wc3LFYZV8YRoheRBTq4qLQ8gYuQ
# +5Uz3cce5soWJRyGeP4IuKIlYoIZ0wlhqmHc8/drvwIBE3bszLZgpbkkH/OZyH0I
# 3ESnm8QdJgMztHyuCsEn3cskwZ5BE861neUJLf6Ya+fpvzLWPgZn23PieTPsf0WN
# 1v06ColnXsZB3UpYlgfqQt0Y+8oxggQNMIIECQIBATCBkzB8MQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBQQ0EgMjAxMAITMwAAAhqpoB0GoA9DqgABAAACGjANBglghkgBZQME
# AgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJ
# BDEiBCDJFNC1mIW3NOfdaizH/54Li1ik34P8DQNvDauY1Cs72jCB+gYLKoZIhvcN
# AQkQAi8xgeowgecwgeQwgb0EIJ16Icetu2kpzAHbR2hVTz1Ycg4fxLvDfu5odwOZ
# 6Yr7MIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAIa
# qaAdBqAPQ6oAAQAAAhowIgQgRG9fh7F2oZwU2LMrej52jvjhZCQGmb9DKITdbjQL
# FvowDQYJKoZIhvcNAQELBQAEggIAYp/5MbksRcaZZuhLCVGC7CZsRA7QtVItFdNn
# onoND8KEFU1n6Rf9rTXwuywEn4LZ9cApm7KkW8ySwdhRvc6tNgipYp1h56XdBTiK
# 0cvim+i2K/1Y1keBmNU52AJdg8uVi7pJp7+NglVIghGdteMaI3qMe9ECu7cRKggQ
# /QIU8wxJClzYKZhMnB+Ez1FVlG9MPaQWuk7U0Asw422lUt+ak0o6Y8y9bsQm5n6s
# XVgjy7Jl33oCbe/uoVXzrCH/x3RZoICmiXasanMORmRUfXLGiqLTjikhDu1oT4cm
# bkvv3PtwFY6itbNq2F08fBpNJdCNAMeaQO92CXFEk+/ippIwfa+VkdvBV1LFHPjT
# QX5w+JopZLedpl9yzr4YiEqzzN+YUd6sp69pMy76mLfVs1JeyXHqIHczVVGfxVe8
# R8S4gY4AXo6HbUu8ZpdH8Ve3ymu8WqHcMHOUj6gp0VzMnO4RDnTa1MRrNcwBuMKg
# vsz+bkWaLivOIl2SmpKz5c29kEiIrdM72MDG/f5Y026Sh3YbS3I0K94PNmPI/7sS
# /Z8gmE5OUMU3QFNEbYX8GssaXH6Yzz8ZgZAc1Wy/I9QHYSiCIVw0B9iSfiOF6ph+
# QM/DuNFC1qO9snD9ii1KwlsS78igKMoY8zJ5TqmuYOxSh27u1CTsLbIQdZo00ffn
# 28kFRns=
# SIG # End signature block
