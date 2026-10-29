@{

# Script module or binary module file associated with this manifest.
ModuleToProcess = 'Pester.psm1'

# Version number of this module.
ModuleVersion = '3.4.0'

# ID used to uniquely identify this module
GUID = 'a699dea5-2c73-4616-a270-1f7abb777e71'

# Author of this module
Author = 'Pester Team'

# Company or vendor of this module
CompanyName = 'Pester'

# Copyright statement for this module
Copyright = 'Copyright (c) 2016 by Pester Team, licensed under Apache 2.0 License.'

# Description of the functionality provided by this module
Description = 'Pester provides a framework for running BDD style Tests to execute and validate PowerShell commands inside of PowerShell and offers a powerful set of Mocking Functions that allow tests to mimic and mock the functionality of any command inside of a piece of powershell code being tested. Pester tests can execute any command or script that is accesible to a pester test file. This can include functions, Cmdlets, Modules and scripts. Pester can be run in ad hoc style in a console or it can be integrated into the Build scripts of a Continuous Integration system.'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '2.0'

# Functions to export from this module
FunctionsToExport = @(
    'Describe',
    'Context',
    'It',
    'Should',
    'Mock',
    'Assert-MockCalled',
    'Assert-VerifiableMocks',
    'New-Fixture',
    'Get-TestDriveItem',
    'Invoke-Pester',
    'Setup',
    'In',
    'InModuleScope',
    'Invoke-Mock',
    'BeforeEach',
    'AfterEach',
    'BeforeAll',
    'AfterAll'
    'Get-MockDynamicParameters',
    'Set-DynamicParameterVariables',
    'Set-TestInconclusive',
    'SafeGetCommand',
    'New-PesterOption'
)

# # Cmdlets to export from this module
# CmdletsToExport = '*'

# Variables to export from this module
VariablesToExport = @(
    'Path',
    'TagFilter',
    'ExcludeTagFilter',
    'TestNameFilter',
    'TestResult',
    'CurrentContext',
    'CurrentDescribe',
    'CurrentTest',
    'SessionState',
    'CommandCoverage',
    'BeforeEach',
    'AfterEach',
    'Strict'
)

# # Aliases to export from this module
# AliasesToExport = '*'

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

PrivateData = @{
    # PSData is module packaging and gallery metadata embedded in PrivateData
    # It's for rebuilding PowerShellGet (and PoshCode) NuGet-style packages
    # We had to do this because it's the only place we're allowed to extend the manifest
    # https://connect.microsoft.com/PowerShell/feedback/details/421837
    PSData = @{
        # The primary categorization of this module (from the TechNet Gallery tech tree).
        Category = "Scripting Techniques"

        # Keyword tags to help users find this module via navigations and search.
        Tags = @('powershell','unit testing','bdd','tdd','mocking')

        # The web address of an icon which can be used in galleries to represent this module
        # Removing it because of BUG 59114280.
        # IconUri = "http://pesterbdd.com/images/Pester.png"

        # The web address of this module's project or support homepage.
        ProjectUri = "https://github.com/Pester/Pester"

        # The web address of this module's license. Points to a page that's embeddable and linkable.
        LicenseUri = "http://www.apache.org/licenses/LICENSE-2.0.html"

        # Release notes for this particular version of the module
        # ReleaseNotes = False

        # If true, the LicenseUrl points to an end-user license (not just a source license) which requires the user agreement before use.
        # RequireLicenseAcceptance = ""

        # Indicates this is a pre-release/testing version of the module.
        IsPrerelease = 'False'
    }
}

# HelpInfo URI of this module
HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

# SIG # Begin signature block
# MIIncAYJKoZIhvcNAQcCoIInYTCCJ10CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBKOUNkvlthAOlT
# gS2vhmkJ2eOOtw8Tx+d1uWuD9RDXk6CCC8MwggXaMIIEwqADAgECAhMzAAABP8rF
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
# 8f7BcdpMoEFagt3xHzGCGwMwghr/AgEBMIGmMIGOMQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMTgwNgYDVQQDEy9NaWNyb3NvZnQgV2luZG93cyBU
# aGlyZCBQYXJ0eSBDb21wb25lbnQgQ0EgMjAxMgITMwAAAT/KxSgZC4k1WAAAAAAB
# PzANBglghkgBZQMEAgEFAKCB+jAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAv
# BgkqhkiG9w0BCQQxIgQgKanoXZ8vOTB9mQeqk3GYNOsy1hA1k55Fjizobzl6NZsw
# UAYKKwYBBAGCNwoDHDFCDEAxMjlFOEIyMzQ0M0Q2QjJGNjQ5OTA3MzVDNzkyNDBE
# MzVFRkYwNzVCODI3M0JERkY0OEQ5MjQwOUNDMUEyNEIyMFoGCisGAQQBgjcCAQwx
# TDBKoCSAIgBNAGkAYwByAG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggGA
# PSmZdqpUlFQbZoJI0a7oDrXuUWaBfAQbSmV3hoDtet0wwmR/8o+4CL3hCr5I/zJO
# EByAz/A4fk+wW+JOn+nz2bVUL8CNBRwYk9ZZ32r/kgtMRHEMnMzTnRfVy7Y652D8
# dVhBsD/HMgipr4skelSLREChsepnIDMZFS8QjPAjHlQiLNQcPAg6hsUMOiWR21L/
# KCGQtV10XXOzwsQhPzVKIwBfja7u7KJ8HiZSAXpyUUZQIt2FBm0eLKezhmUbsWeP
# aadltQrTvMPY1pxWuME/r2VZG0WXmmMXLfmirPruR0JrATY12WsCPbRIt/b6LexA
# k5oCw5YokZ1ZFtti8k/tK7UPM7xA+xRBNv4HM+SgRKQLNgTzTlHgXlKdqCdKlZE1
# W+OW8mszXyh0Iue+lhNZrieZH+xt8oZrUiCAe3CYYhnspu5nzU+DCyJ68S40O0/c
# BqaUvkPV5kZL4/tWDsXNCsVLQeNIlzxNzH5mGEn0apwnkPdHAxKgopSxQcVwT3eJ
# oYIXsDCCF6wGCisGAQQBgjcDAwExghecMIIXmAYJKoZIhvcNAQcCoIIXiTCCF4UC
# AQMxDzANBglghkgBZQMEAgEFADCCAVoGCyqGSIb3DQEJEAEEoIIBSQSCAUUwggFB
# AgEBBgorBgEEAYRZCgMBMDEwDQYJYIZIAWUDBAIBBQAEIJzWxqwmUsW2DWT+7Ez0
# fsXY5649XShYnTIWNhsIt3b8AgZqrya/NnQYEzIwMjYxMDEwMDgzNjM0LjA3Mlow
# BIACAfSggdmkgdYwgdMxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRl
# ZDEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjU1MUEtMDVFMC1EOTQ3MSUwIwYD
# VQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloIIR/jCCBygwggUQoAMC
# AQICEzMAAAIb0LK4Amf3cs8AAQAAAhswDQYJKoZIhvcNAQELBQAwfDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcNMjUwODE0MTg0ODMwWhcNMjYxMTEzMTg0
# ODMwWjCB0zELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEtMCsG
# A1UECxMkTWljcm9zb2Z0IElyZWxhbmQgT3BlcmF0aW9ucyBMaW1pdGVkMScwJQYD
# VQQLEx5uU2hpZWxkIFRTUyBFU046NTUxQS0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1p
# Y3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUAA4IC
# DwAwggIKAoICAQCOxZ3nZlmTMHld7mD+XYaw6MDPfSyDqNXF8UlX7DjEgNXJojcs
# 7xsimbNi6XcBkeDnRQhDw+tJFkalCoWRE276jdgoniDa4ZgFGSwecdhHS5VIJCDn
# xOGRjJ6mUZfegC8ZFW48ilC0CJOxHvoD+B2hTscPARtvvdsnBPKtsoeFH5ZozL0N
# AcjiTlCjj5tkOzSSPvpu+Em90ZT5LzPFAGntQCGMmcWorEi6xIhMTvMIJHjbYQuG
# SFVU4WorbDqHUwC8gt7vqHFEhw+PRIEvavw723HmeNTj62DasB1TXnembKGprN2l
# RxxgET3ANEVR3970KhbHtN2dSJwH4xqLtFPqqx7t7loapfUHtueP9ke+ut8X4EkQ
# iVL2INcBSB6S9dn4VmaO8vA/5037T9yuH76vh7wWScXsRfogl+eY14M3/rxnn2Rt
# onV/4/macph/J0J5mbGsalLS1paQOTfoPeM9Vl+W/Gtz7WuEIiUzm/1qAsQUjXZC
# IFN+k4E4GvcAYI+T54fT6Vq2NBqO6D7b8EPXapvzbnTQtDK1RZPai1r8didGBK/W
# O9nT92aXUWzFZjM6cKuN90H/s3qk3JK3i+f48Y3p0UuKbuTGiz4H1Z9A97MmLd+4
# rLIMAH3NIc+PVm7ydl95xkn26bjOPsMWC8ldMNOcbmqUbhl1sVFr+ut/OQIDAQAB
# o4IBSTCCAUUwHQYDVR0OBBYEFLa+n3f+XEumk0rw6Rq4nYC82YhQMB8GA1UdIwQY
# MBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRpbWUt
# U3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYIKwYB
# BQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWlj
# cm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1UdEwEB
# /wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeAMA0G
# CSqGSIb3DQEBCwUAA4ICAQBmRTVfFAPg5MzcZOG3fZNdKEh88Ggx9KwWwFCoU5mo
# sk7HIk6WUgEWmam860Y0+QLlnyV0bxoKm+AU2j+MNZ5PkWJbnd0CP0qdnGmxDc9/
# l9HNIYdFzEQw51chXMMnBxlRfRyN/GdrvJ02/x5cH9eTobpLKtHY4fpLUscxbXWb
# dS8oX54uMg+XjmvGKa4MKgR35p3SU4BcDn+9k4o3mf949h4/QtFyFlfRDofyf9mZ
# I8yVuWLcw7znVDT1GZP9kYdr78V3L5YsOvBxjKRX2ZTL/hNvArDoW11Hpk8fEx0i
# LWmTxjaYL8bMKrQsKwfS5MV5DpDs1zcxGYRH/eYtZSFtpYeBfUVthyG9HbZv4G6n
# 5g9HlD/QGFpoA3oAgF9waz67+cmggHLJkoDxxPIKadQj/i9boPi/LCDdcEV/h/YP
# AUfL96+wL7nwoyX6TbBrTlfaQrRP9sI8uFqi/1lfKhtrB804tgaJq4pPYVa9vBnM
# cgUJPGMHDDo+3m5G8IT+OdRx//GGU4YyfqIo71e3j29lMTZJ8gGT/fiItNEEnoft
# oY9NNCfNrc59a7X91HJwLpaXmiezc+OcZdNIpLFeWUk+aDpH+6Uaic/9QJignqY3
# 4ReN/IMs9cuqyv3X5VMbWtjNEKM/AEUAe/gQjBoTRqMKt/vl5QYjf6hdTRQ/quWh
# nzCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZIhvcNAQEL
# BQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH
# EwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNV
# BAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDEwMB4X
# DTIxMDkzMDE4MjIyNVoXDTMwMDkzMDE4MzIyNVowfDELMAkGA1UEBhMCVVMxEzAR
# BgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1p
# Y3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3Rh
# bXAgUENBIDIwMTAwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDk4aZM
# 57RyIQt5osvXJHm9DtWC0/3unAcH0qlsTnXIyjVX9gF/bErg4r25PhdgM/9cT8dm
# 95VTcVrifkpa/rg2Z4VGIwy1jRPPdzLAEBjoYH1qUoNEt6aORmsHFPPFdvWGUNzB
# RMhxXFExN6AKOG6N7dcP2CZTfDlhAnrEqv1yaa8dq6z2Nr41JmTamDu6GnszrYBb
# fowQHJ1S/rboYiXcag/PXfT+jlPP1uyFVk3v3byNpOORj7I5LFGc6XBpDco2LXCO
# Mcg1KL3jtIckw+DJj361VI/c+gVVmG1oO5pGve2krnopN6zL64NF50ZuyjLVwIYw
# XE8s4mKyzbnijYjklqwBSru+cakXW2dg3viSkR4dPf0gz3N9QZpGdc3EXzTdEonW
# /aUgfX782Z5F37ZyL9t9X4C626p+Nuw2TPYrbqgSUei/BQOj0XOmTTd0lBw0gg/w
# EPK3Rxjtp+iZfD9M269ewvPV2HM9Q07BMzlMjgK8QmguEOqEUUbi0b1qGFphAXPK
# Z6Je1yh2AuIzGHLXpyDwwvoSCtdjbwzJNmSLW6CmgyFdXzB0kZSU2LlQ+QuJYfM2
# BjUYhEfb3BvR/bLUHMVr9lxSUV0S2yW6r1AFemzFER1y7435UsSFF5PAPBXbGjfH
# CBUYP3irRbb1Hode2o+eFnJpxq57t7c+auIurQIDAQABo4IB3TCCAdkwEgYJKwYB
# BAGCNxUBBAUCAwEAATAjBgkrBgEEAYI3FQIEFgQUKqdS/mTEmr6CkTxGNSnPEP8v
# BO4wHQYDVR0OBBYEFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMFwGA1UdIARVMFMwUQYM
# KwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0
# LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAKBggrBgEF
# BQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYD
# VR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTV9lbLj+iiXGJo0T2UkFvXzpoYxDBW
# BgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2Ny
# bC9wcm9kdWN0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcmwwWgYIKwYBBQUH
# AQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtp
# L2NlcnRzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNydDANBgkqhkiG9w0BAQsF
# AAOCAgEAnVV9/Cqt4SwfZwExJFvhnnJL/Klv6lwUtj5OR2R4sQaTlz0xM7U518Jx
# Nj/aZGx80HU5bbsPMeTCj/ts0aGUGCLu6WZnOlNN3Zi6th542DYunKmCVgADsAW+
# iehp4LoJ7nvfam++Kctu2D9IdQHZGN5tggz1bSNU5HhTdSRXud2f8449xvNo32X2
# pFaq95W2KFUn0CS9QKC/GbYSEhFdPSfgQJY4rPf5KYnDvBewVIVCs/wMnosZiefw
# C2qBwoEZQhlSdYo2wh3DYXMuLGt7bj8sCXgU6ZGyqVvfSaN0DLzskYDSPeZKPmY7
# T7uG+jIa2Zb0j/aRAfbOxnT99kxybxCrdTDFNLB62FD+CljdQDzHVG2dY3RILLFO
# Ry3BFARxv2T5JL5zbcqOCb2zAVdJVGTZc9d/HltEAY5aGZFrDZ+kKNxnGSgkujhL
# mm77IVRrakURR6nxt67I6IleT53S0Ex2tVdUCbFpAUR+fKFhbHP+CrvsQWY9af3L
# wUFJfn6Tvsv4O+S3Fb+0zj6lMVGEvL8CwYKiexcdFYmNcP7ntdAoGokLjzbaukz5
# m/8K6TT4JDVnK+ANuOaMmdbhIurwJ0I9JZTmdHRbatGePu1+oDEzfbzL6Xu/OHBE
# 0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggNZMIICQQIB
# ATCCAQGhgdmkgdYwgdMxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRl
# ZDEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjU1MUEtMDVFMC1EOTQ3MSUwIwYD
# VQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoD
# FQCGhXqvj0zgYF3jUrVFgHVnR/jO4KCBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA7nQA6jAiGA8yMDI2MTAxMDAw
# MTAxOFoYDzIwMjYxMDExMDAxMDE4WjB3MD0GCisGAQQBhFkKBAExLzAtMAoCBQDu
# dADqAgEAMAoCAQACAgfGAgH/MAcCAQACAhMNMAoCBQDudVJqAgEAMDYGCisGAQQB
# hFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAw
# DQYJKoZIhvcNAQELBQADggEBAAYxLHIpqyu1EGLnA4ivA46lMJ56XLDCQLZzNlGR
# GBV/BzsXjgs6NIVcO8fei2WyFhfN2LFSYOBeOYbLR/v+4/uEZPZf02WFR1Td05RD
# wo85lpxBMTzVHNlPa0CKNfVbKKFgJzk3MHNJv2BCc8K/ReqoYAEOJP022E9TpzxF
# wAYsgk/2AcpwSlpyk53LpilkyPDakZ+e5kwerrjRw1a8qLnY4UFHi0S16lTbW8mg
# eKSCkpmiDW14e37noJqI68nVfZ+eRus6bdt8HqiyUatGcVTcYEXc6f5PdgP92nV9
# iTmF5ZgYLJPtg9f5kDauiacxFx6FArwIN2dzMWi7G0yisqIxggQNMIIECQIBATCB
# kzB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAhvQsrgCZ/dyzwAB
# AAACGzANBglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJ
# EAEEMC8GCSqGSIb3DQEJBDEiBCBEC1i6uzL2DyuwFpxaK3cZpaykdwEBkkm8+hE7
# ov0Y3TCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIDAlFJW4PaOYxxAIVd0u
# 4kDAOlRU1nptzp18lTzdDYuAMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAg
# UENBIDIwMTACEzMAAAIb0LK4Amf3cs8AAQAAAhswIgQgJ57s1PUD6N1AqmXW07ub
# eG8gWF0/kzN0MqpCABVWKmwwDQYJKoZIhvcNAQELBQAEggIAdc1PoekVhXhpCBVJ
# d0/Qag4znyhHCEsvwCTB6NpWDkJdKcgOin+pBdgwPLDU8/zZhGllM+Q+AuwjEvbn
# 4qu3T7oddiBFt/tupLzS9sN++jxULm3P55sSf96rnbqWS8DhRiuqYfjw5iqO5ENb
# eEZQiW3PNwS2G0AtvKb58P+5227AadZEGOt3rJAvX+SiddqK0+Sad1J4XYGstuv1
# ha9URaQEcizAAdeRTH9qcMwg6xGoZ3Nkj2igzNF5iFLdehb5gRl299kFpeF+y4BC
# royrVblbu4JPcXDCBwIga6r57WMfJmvoP7V4wwXuZHhSUkXbvCT8RErvjGXGKEYA
# kdmlLoeXf1CH//2P3OyGp7zLb5SjFTHQpvyPTA0hP2hiSPW6pE9Xb/NdetX1CFnp
# 075magas8LnQzTqSLCjUdaD7UgdacfvQekb6prU7gXwbDbaTzW+lDC+gKElDciCv
# ilm7HuRaJ3+PgcujeWyCe6w/H3sKlurI04dxlTlXikcQ1QhHbU7PVpSTIB3yl5ZH
# lYZxe3NXjaBB7iqbVKGCsRe4yEWECUk1UcCTiyWskRQoqrXFh6g109SZPP9Ba6xZ
# VjIdrnYY1UmUspzjp5O1B7dBwx4Z7a7uPnltVYZsnbpvj6RfCPv8vPioxIqAzaXt
# YBqE6hRXJ9zPUg+PEGptTAUIO3s=
# SIG # End signature block
