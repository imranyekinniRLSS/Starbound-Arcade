function InModuleScope
{
<#
.SYNOPSIS
   Allows you to execute parts of a test script within the
   scope of a PowerShell script module.
.DESCRIPTION
   By injecting some test code into the scope of a PowerShell
   script module, you can use non-exported functions, aliases
   and variables inside that module, to perform unit tests on
   its internal implementation.

   InModuleScope may be used anywhere inside a Pester script,
   either inside or outside a Describe block.
.PARAMETER ModuleName
   The name of the module into which the test code should be
   injected. This module must already be loaded into the current
   PowerShell session.
.PARAMETER ScriptBlock
   The code to be executed within the script module.
.EXAMPLE
    # The script module:
    function PublicFunction
    {
        # Does something
    }

    function PrivateFunction
    {
        return $true
    }

    Export-ModuleMember -Function PublicFunction

    # The test script:

    Import-Module MyModule

    InModuleScope MyModule {
        Describe 'Testing MyModule' {
            It 'Tests the Private function' {
                PrivateFunction | Should Be $true
            }
        }
    }

    Normally you would not be able to access "PrivateFunction" from
    the powershell session, because the module only exported
    "PublicFunction".  Using InModuleScope allowed this call to
    "PrivateFunction" to work successfully.
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ModuleName,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock
    )

    if ($null -eq (& $SafeCommands['Get-Variable'] -Name Pester -ValueOnly -ErrorAction $script:IgnoreErrorPreference))
    {
        # User has executed a test script directly instead of calling Invoke-Pester
        $Pester = New-PesterState -Path (& $SafeCommands['Resolve-Path'] .) -TestNameFilter $null -TagFilter @() -ExcludeTagFilter @() -SessionState $PSCmdlet.SessionState
        $script:mockTable = @{}
    }

    $module = Get-ScriptModule -ModuleName $ModuleName -ErrorAction Stop

    $originalState = $Pester.SessionState
    $originalScriptBlockScope = Get-ScriptBlockScope -ScriptBlock $ScriptBlock

    try
    {
        $Pester.SessionState = $module.SessionState

        Set-ScriptBlockScope -ScriptBlock $ScriptBlock -SessionState $module.SessionState

        do
        {
            & $ScriptBlock
        } until ($true)
    }
    finally
    {
        $Pester.SessionState = $originalState
        Set-ScriptBlockScope -ScriptBlock $ScriptBlock -SessionStateInternal $originalScriptBlockScope
    }
}

function Get-ScriptModule
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ModuleName
    )

    try
    {
        $modules = @(& $SafeCommands['Get-Module'] -Name $ModuleName -All -ErrorAction Stop)
    }
    catch
    {
        throw "No module named '$ModuleName' is currently loaded."
    }

    $scriptModules = @($modules | & $SafeCommands['Where-Object'] { $_.ModuleType -eq 'Script' })

    if ($scriptModules.Count -gt 1)
    {
        throw "Multiple Script modules named '$ModuleName' are currently loaded.  Make sure to remove any extra copies of the module from your session before testing."
    }

    if ($scriptModules.Count -eq 0)
    {
        $actualTypes = @(
            $modules |
            & $SafeCommands['Where-Object'] { $_.ModuleType -ne 'Script' } |
            & $SafeCommands['Select-Object'] -ExpandProperty ModuleType -Unique
        )

        $actualTypes = $actualTypes -join ', '

        throw "Module '$ModuleName' is not a Script module.  Detected modules of the following types: '$actualTypes'"
    }

    return $scriptModules[0]
}

# SIG # Begin signature block
# MIInXgYJKoZIhvcNAQcCoIInTzCCJ0sCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB3Q4hXkxxZ4Tab
# o0y0Lblf/mm0vpcqy+zsdIlhsReRv6CCC7QwggXLMIIEs6ADAgECAhMzAAABQGf2
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
# gxDhlJtbYJCJSzGcejXG9xyd7muZZgQ0C3VBWsHfIekwUAYKKwYBBAGCNwoDHDFC
# DEBERDQwQTUxNzlGNjg4MzM3RUExNDkzMUFFNkJDOUY1RDNDMTQ1MkYyM0Q4NDk5
# RTlDREI2OUEyRDNENTYwREIyMFoGCisGAQQBgjcCAQwxTDBKoCSAIgBNAGkAYwBy
# AG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0cDovL3d3dy5taWNyb3Nv
# ZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggGAccwhACkUPBsAKk4cBAlZ
# YlOVXR1a7MNZCNf2VLAlDeAmYaEc4Sesua7y2X0uZ2Vv3W6/IaUoh2xfWFH9uOEk
# /f120cjXw3UwDtkw4ubMx4bORFirIoUYZHi5xVnyWwGPn0irE7WlQ619/st362n6
# G+zRg2oZE1mZGzTe7XQ8ArxsEjNGIpN+octYhELI4pxSmfpOFU7yy39Vu+da2uxR
# SDzWY58j5cEWCJSQ5wQBWSvdkR5MjRZi1uYNB4uH4SruonM8uYTLQ9MnfJ8Tg2wm
# uXpeINwBEkjlianXkgIM4atsI6LbRcbUlJxXhqa9OcATvCSl2J6SvgsyNn8GOFM1
# HHAJxt4LubT7pLBhQ9o4HR6nNW2U0t8yVRemVkX9FASV5Yr4fUfaro3hqHkwNQel
# A4FT/VFbQpyfK9opJSv6QX9icpYMRpWD152Hx0ZcyrqCWMHDYz+Ut8NtHIwU3/SA
# 6K2WADMm1VvtxuNrmLsIotRZ9rnkOUnu55RqoEY4fHOpoYIXrTCCF6kGCisGAQQB
# gjcDAwExgheZMIIXlQYJKoZIhvcNAQcCoIIXhjCCF4ICAQMxDzANBglghkgBZQME
# AgEFADCCAVoGCyqGSIb3DQEJEAEEoIIBSQSCAUUwggFBAgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIP2sToI3WC41305KZ5s+Lr87/4qtNq7TjNV6vz9o
# K9EVAgZqiNzfL5AYEzIwMjYwOTE4MDQwMDE4LjI5NFowBIACAfSggdmkgdYwgdMx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1p
# Y3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEnMCUGA1UECxMeblNo
# aWVsZCBUU1MgRVNOOjQwMUEtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQg
# VGltZS1TdGFtcCBTZXJ2aWNloIIR+zCCBygwggUQoAMCAQICEzMAAAIZXrLYVHX0
# sY0AAQAAAhkwDQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENB
# IDIwMTAwHhcNMjUwODE0MTg0ODI2WhcNMjYxMTEzMTg0ODI2WjCB0zELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWljcm9zb2Z0
# IElyZWxhbmQgT3BlcmF0aW9ucyBMaW1pdGVkMScwJQYDVQQLEx5uU2hpZWxkIFRT
# UyBFU046NDAxQS0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCmoUjJ
# STMjLGkvdDTdaYu7Lgb1ghRJzOeEqv5wc5P7+7s9qvEj3qDHFvVata4DEHyqMYt+
# xsibHxXei4rWdRx/5H+eyddqzn+JOBX9OXdBNEZPQN65cE1ukepz7ALU2JPIDvqA
# ueKu9IESgHOWuk1AUSe7B1s8sIulNLcpZIK7knTZv5EVZH+RwXNXGeGgTeAhp5RG
# 2sYoYFkYosFe+qCCQMQ20qS+29FPfbEu8C8v9GlF67nPXxmiMKzvZlKhrvgPLxht
# pawObc5k6klFnFmw8oIdnrE2qAUp/TE0ePS32/RDdb7bPmABVpqwkkK9HnZKXRcn
# YA5/eXQtJ61eBQDmAPkhDVG8SyVOY2dKi5OsYgPcPWeNjuYG7Sm6Ih08raMr/VZ5
# 5/b5hHhxClZCR4FmZeJ2H0C5Z2XDEpAvXksnorZ3DzL+388GGYvK3pAB/QJ6lZF2
# BmczK1UBS5YfCVlFX0ktjtpfwPnl4v35w4ulfdsY06Y3bhSkhbyq1lqpdp6wW8g5
# bbck0uFppBW85uvV67sYT/kyfjd778Nu11iX9ss/YhDXFgQl1JtxSQMV9bcqVkSH
# 6cEoO1pGc1GRuAiDEhsp1Pfw4pDBn9oDi5KyICDqcQ+JYEca7K0ijnBTvkzlV2OE
# SqpMd9di7wEmLoZPO9ZP716R8xd7OoKSSzFobwIDAQABo4IBSTCCAUUwHQYDVR0O
# BBYEFIBo6jkdZq03OpmfUgXV9wPqevchMB8GA1UdIwQYMBaAFJ+nFV0AXmJdg/Tl
# 0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly93d3cubWljcm9zb2Z0
# LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAy
# MDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYIKwYBBQUHMAKGUGh0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwVGltZS1T
# dGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/
# BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUAA4IC
# AQBfHNVkstcEV+gIIJOJjswdd1vtyK8lJN+sdgkLk6TY03vk2nNMxP1XZNwhCN9D
# cAVRuHU0EBi0xS7DELoPhx4RcbmVcCdu+QL1iN4tUNHIiZdhiZ+3vP5CmX23cL/x
# rS2Kqc7PxR7z8Ngu0xOC9Yyeyos2MgsNoiY5+ccjfpMsKMYV7xFgtcZ0JR04uV8B
# 0wZ4/FJMDdMAA5z4ZBuY9aOuC4tZvG+eXc1WNG+sFlWTEUyhVkfR/uobAM5KGOme
# /mdidDjy58vS4HPnZFs8Z1fgW/35QY6sGmuZwfOYi60W0l5zZjiS6M21MrbAEaBa
# xwQ5WEWJpV2N7xUsnsxU0oTlOay4YzeNMuvWe5HkAUazdQqQ/uDdxAPhwcrtd0uJ
# Obt7rTpAn5ap5CwANgT129T3AhRsj0OXhRwgSsXD4UdpZJOuR8nhK8uaEqeXmSGG
# knWwXfPp7UHF6lSWJcerNEuIdaKFYhYRIXwgcSUXc87Fs/hUmocGJi9pcxXRLJGD
# CgPrNd11tSdf1ZHokvYGWoCOMfEg3B6Wyn9WHEBZOHO4wDnwvG8T9UDON8UXhabt
# rVkAuYlXDegv+z+7GjU6ni1xP6F9n243WG0LUk3gO5GoV8u22O6gCZRChs7nNQVH
# O8KfwKT+GI75vNHXmyqSOXEszIyOmRz95/hJRSKQPjry9TCCB3EwggVZoAMCAQIC
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
# aWVsZCBUU1MgRVNOOjQwMUEtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQg
# VGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQAxdin9aqp3JvR6eKCs
# t/GXQicDPqCBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0G
# CSqGSIb3DQEBCwUAAgUA7lbxAjAiGA8yMDI2MDkxNzIzMDY0MloYDzIwMjYwOTE4
# MjMwNjQyWjB0MDoGCisGAQQBhFkKBAExLDAqMAoCBQDuVvECAgEAMAcCAQACAgWb
# MAcCAQACAhPlMAoCBQDuWEKCAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQB
# hFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEB
# AECsyuUllY1XMszjyElwjsK5NiSbdMZ69dInKXt5lyNDEXqq/50Hvjp5pm0U0/0P
# Vq1/GUkJgiABBHnLVopkX75gvCp5QH3r3pTmCPWf8y54OE+7e35zHYfDl4Clxnn8
# cVPjGufJl9M6nyq+K+i2QpiD90ScRYqMqJ1u/pNQBIg+hiGncevIq6YezezY/VHV
# oULZDuznfKzMKjgeb0uBBw8CwG7ogcueBzEs7K2onOeAo8l9J/CI5odChEAc+u9+
# t21faGl3xPn956g12hsrL4tnFjdb8/7z9VocDQxavTVWc5fVi8Kc1IcNRxAjwZCm
# ra7zjoso076y+VDx/b7dwr4xggQNMIIECQIBATCBkzB8MQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1T
# dGFtcCBQQ0EgMjAxMAITMwAAAhlesthUdfSxjQABAAACGTANBglghkgBZQMEAgEF
# AKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJBDEi
# BCAB+YZYL7JbXuEtbFEhXyzLtTL9k97m6QpHaJnnQZQFhTCB+gYLKoZIhvcNAQkQ
# Ai8xgeowgecwgeQwgb0EINyRfrfcTXLUQXfZXXzNByuyCPMj37ct7uaW+TY55u2G
# MIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAO
# BgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEm
# MCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAIZXrLY
# VHX0sY0AAQAAAhkwIgQgVpvrQmHHNSxf1kd4k+xM414UlCXIOqs3EBXkcDjxQbgw
# DQYJKoZIhvcNAQELBQAEggIAPQd1W3fLMUSB0adqrjqgv+l5G0cTZxnOhEH0GgEw
# zH/jvI9sN4hO5tplKnag6BUd51aSg09FJq9kwkb8kRfX4bLk5pELvsrkLX1RahcT
# b3WefnH1QKZ/WGtQYCJPUF9lg5Y9bCOHfuXWI9spRFcMABNJdOZKAkjXc0lUm0oi
# CXvfICoqkAUhO+m6At7VDrAnVBjJVn30a8c6k+XG9v/s0uKSGJfmrIghaaFaOgf3
# N1aNbV3Nz0cjCrh9iZsj4VLXfXwXsW74+mJRg+mhZiZbSSTN7xlar6noiIqP5ypO
# wk6PWs4iaW2eA0BYEm28wyIyvichNkOtp2gRaSayX6KXnIqcdFr5NlCfa3TkdOtX
# trTiVZcmMaVONuJn02CUjZcqK9w5WWfr+8ujyZ6sgK+MeXdU3FJsi2TZh2P2cNQ9
# L0HmCdQHE+1aw6j0G84xPuAp8bXJHrkXJ3QOyRd8mz61H8ryVGnFexjhQr4Pb11b
# Yx2kr/m5+amHEZzI+9N3aHl/c9jQArp16qhIunRYW33Sc6BcqAwKf/Leo+Ys93UQ
# pAnlIHVdU6HtcWqx2lSmZh0tYAMYUoTd2fu3kc9ulY4qVJ40zaKOAcjFt3QBX5ae
# TF7AsbrLLmIv9tyZktD7bzc9/7RjwhkmyHaWxcEZn4aBzp7V9GGM7CGs0Onrr5AW
# 550=
# SIG # End signature block
