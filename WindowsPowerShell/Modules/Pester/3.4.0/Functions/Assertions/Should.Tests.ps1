Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "Parse-ShouldArgs" {
        It "sanitizes assertions functions" {
            $parsedArgs = Parse-ShouldArgs TestFunction
            $parsedArgs.AssertionMethod | Should Be PesterTestFunction
        }

        It "works with strict mode when using 'switch' style tests" {
            Set-StrictMode -Version Latest
            { throw 'Test' } | Should Throw
        }

        Context "for positive assertions" {

            $parsedArgs = Parse-ShouldArgs testMethod, 1

            It "gets the expected value from the 2nd argument" {
                $ParsedArgs.ExpectedValue | Should Be 1
            }

            It "marks the args as a positive assertion" {
                $ParsedArgs.PositiveAssertion | Should Be $true
            }
        }

        Context "for negative assertions" {

            $parsedArgs = Parse-ShouldArgs Not, testMethod, 1

            It "gets the expected value from the third argument" {
                $ParsedArgs.ExpectedValue | Should Be 1
            }

            It "marks the args as a negative assertion" {
                $ParsedArgs.PositiveAssertion | Should Be $false
            }
        }

        Context "for the throw assertion" {

            $parsedArgs = Parse-ShouldArgs Throw

            It "translates the Throw assertion to PesterThrow" {
                $ParsedArgs.AssertionMethod | Should Be PesterThrow
            }

        }
    }

    Describe "Get-TestResult" {
        Context "for positive assertions" {
            function PesterTest { return $true }
            $shouldArgs = Parse-ShouldArgs Test

            It "returns false if the test returns true" {
                Get-TestResult $shouldArgs | Should Be $false
            }
        }

        Context "for negative assertions" {
            function PesterTest { return $false }
            $shouldArgs = Parse-ShouldArgs Not, Test

            It "returns false if the test returns false" {
                Get-TestResult $shouldArgs | Should Be $false
            }
        }
    }

    Describe "Get-FailureMessage" {
        Context "for positive assertions" {
            function PesterTestFailureMessage($v, $e) { return "slime $e $v" }
            $shouldArgs = Parse-ShouldArgs Test, 1

            It "should return the postive assertion failure message" {
                Get-FailureMessage $shouldArgs 2 | Should Be "slime 1 2"
            }
        }

        Context "for negative assertions" {
            function NotPesterTestFailureMessage($v, $e) { return "not slime $e $v" }
            $shouldArgs = Parse-ShouldArgs Not, Test, 1

            It "should return the negative assertion failure message" {
              Get-FailureMessage $shouldArgs 2 | Should Be "not slime 1 2"
            }
        }

    }

    Describe -Tag "Acceptance" "Should" {
        It "can use the Be assertion" {
            1 | Should Be 1
        }

        It "can use the Not Be assertion" {
            1 | Should Not Be 2
        }

        It "can use the BeNullOrEmpty assertion" {
            $null | Should BeNullOrEmpty
            @()   | Should BeNullOrEmpty
            ""    | Should BeNullOrEmpty
        }

        It "can use the Not BeNullOrEmpty assertion" {
            @("foo") | Should Not BeNullOrEmpty
            "foo"    | Should Not BeNullOrEmpty
            "   "    | Should Not BeNullOrEmpty
            @(1,2,3) | Should Not BeNullOrEmpty
            12345    | Should Not BeNullOrEmpty
            $item1 = New-Object PSObject -Property @{Id=1; Name="foo"}
            $item2 = New-Object PSObject -Property @{Id=2; Name="bar"}
            @($item1, $item2) | Should Not BeNullOrEmpty
        }

        It "can handle exception thrown assertions" {
            { foo } | Should Throw
        }

        It "can handle exception should not be thrown assertions" {
            { $foo = 1 } | Should Not Throw
        }

        It "can handle Exist assertion" {
            $TestDrive | Should Exist
        }

        It "can handle the Match assertion" {
            "abcd1234" | Should Match "d1"
        }

        It "can test for file contents" {
            Setup -File "test.foo" "expected text"
            "$TestDrive\test.foo" | Should Contain "expected text"
        }

        It "ensures all assertion functions provide failure messages" {
            $assertionFunctions = @("PesterBe", "PesterThrow", "PesterBeNullOrEmpty", "PesterExist",
                "PesterMatch", "PesterContain")
            $assertionFunctions | % {
                "function:$($_)FailureMessage" | Should Exist
                "function:Not$($_)FailureMessage" | Should Exist
            }
        }

        # TODO understand the purpose of this test, perhaps some better wording
        It "can process functions with empty output as input" {
            function ReturnNothing {}

            # TODO figure out why this is the case
            if ($PSVersionTable.PSVersion -eq "2.0") {
                { $(ReturnNothing) | Should Not BeNullOrEmpty } | Should Not Throw
            } else {
                { $(ReturnNothing) | Should Not BeNullOrEmpty } | Should Throw
            }
        }

    }
}

# SIG # Begin signature block
# MIInbQYJKoZIhvcNAQcCoIInXjCCJ1oCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDeyEEHvAd2qbXv
# 0sMhs9VQZslkyLMVmq7f0pfYSsyQi6CCC8MwggXaMIIEwqADAgECAhMzAAABP8rF
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
# 8f7BcdpMoEFagt3xHzGCGwAwghr8AgEBMIGmMIGOMQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMTgwNgYDVQQDEy9NaWNyb3NvZnQgV2luZG93cyBU
# aGlyZCBQYXJ0eSBDb21wb25lbnQgQ0EgMjAxMgITMwAAAT/KxSgZC4k1WAAAAAAB
# PzANBglghkgBZQMEAgEFAKCB+jAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAv
# BgkqhkiG9w0BCQQxIgQg5vFDuRO/uxsktBYaiwPhW2RNIcyyYD5Fffe7IQS60UMw
# UAYKKwYBBAGCNwoDHDFCDEBDQjIxMzBFN0FFQzQ4N0RGOTVDN0U4N0NBNDVEMjA2
# M0U1QTFCQ0ZFRDlDMEE5Rjk0QjlGNjc5M0M3RjQyQjY4MFoGCisGAQQBgjcCAQwx
# TDBKoCSAIgBNAGkAYwByAG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggGA
# dE94FSc7AE1DX6rkXthBhZ+3bFGeYgvW+eAXSEaJtYsoUnbcjmogz6pjskUMW7EL
# m7xrRrAyEYfhkZIudVU4RFLkSkW048XeFKYy6DEHBpsCL47VrSEcafK8yZosnvWJ
# 9OGwh/VmpYuXFUly0lo2pAGmc9aj0E7j0MGCjkgD6unN2hGrd12UxQFm1ZP482uS
# nXoXSfcN2Gkw+K5bc9mLVJ+r2O+VKoV+uNKGHz9fbi1yVDbUuzxHA3FhhubuXwiL
# Vd7WriYb1iyaSytN+k45mCs1Z0yZ9irm1H+N/OkESmK6y5kifuq+Cr+k5sPq5Uix
# nvKFMHr+44llO44+/3j5igt7s1kgji0WxSBO9tNtM79+xgG792q8XT3cWk7HrYQ4
# VUcGj9AZSWjNse/YHBA0ZfAzbFsxTmiMs75VJxbsV4fuNmsfppkth8CgpdXZNd7B
# gBLb10kMo0e2bu6NIFwxMyTZBYwvV7kvJFDY0YPuzKzeYsAghwzBga3OBs43K8hF
# oYIXrTCCF6kGCisGAQQBgjcDAwExgheZMIIXlQYJKoZIhvcNAQcCoIIXhjCCF4IC
# AQMxDzANBglghkgBZQMEAgEFADCCAVoGCyqGSIb3DQEJEAEEoIIBSQSCAUUwggFB
# AgEBBgorBgEEAYRZCgMBMDEwDQYJYIZIAWUDBAIBBQAEINjhweFuVLjCDa+YLeo2
# zlnu/91MVQaYtHJJKTfERYSjAgZqrrEH4CoYEzIwMjYxMDEwMDgzNjM0LjUzNFow
# BIACAfSggdmkgdYwgdMxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRl
# ZDEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjQzMUEtMDVFMC1EOTQ3MSUwIwYD
# VQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloIIR+zCCBygwggUQoAMC
# AQICEzMAAAIdS8CShziFfjkAAQAAAh0wDQYJKoZIhvcNAQELBQAwfDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcNMjUwODE0MTg0ODMzWhcNMjYxMTEzMTg0
# ODMzWjCB0zELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEtMCsG
# A1UECxMkTWljcm9zb2Z0IElyZWxhbmQgT3BlcmF0aW9ucyBMaW1pdGVkMScwJQYD
# VQQLEx5uU2hpZWxkIFRTUyBFU046NDMxQS0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1p
# Y3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUAA4IC
# DwAwggIKAoICAQCitKBoADyg6XimHnvjPDb16BQ3wMN6lEctfwUzXMc0mZcboqtK
# pQrDNwpp+im5h09MRNMK9v1ol8RK4BTSIY1QUj8PpHSS91+l7ag9f4TextNC8aLg
# k8fmp0hhRonjlX/hup7x429tbOkL5kqMfX3cN6IjVcAj3XwmhCYGGURej9OifXvb
# WW5kmCKdyx/kuMxjeNfzhbJdRJfd2xLuH/vFUj7DXKODulr7TLej+Z7ZOy/pQlR1
# JNBqnk5EZJ8KdyWc/XPciKJYhavdWjtog9ayAnOrebkbGnFQcJCTyrNSGTnTL+4H
# 4sYTdYgrYLvuLL2IWxJ9ItSfIwTMZENb2ZcdPg8fs7PPoIepASI2/BweqW+UKHWk
# dCHU1dBICo6hUGzmaLp5qx/rLFZN97kOtHv3nTevylTpWoLZj1cxFTjAf1Bthdiw
# hRnfcmad3LbZbUsEMBvEE9AcIGWdwYNTcGB2FVRUt7zSaCAU73wV2RaGjrvDiQ90
# JNGS92+Rjw+tBgT+dCMdcJrSDstwy21lvp6Mwd9D61RZe/r6dnhieSvY6RrFyUUL
# DhEhg0xYPboBZtCP9YR3OBrXx8q3DrovmDNc/NrqMUF88l4oTcfxAC7CmKuYfiaz
# 7mdSM01A6Y2ComfRTX7difsKWzAPv1g3Svd91tgEwMCkFkmk2UrursddGwIDAQAB
# o4IBSTCCAUUwHQYDVR0OBBYEFIRZ8HE0RqZm1ebyCX3ZirzSN/FdMB8GA1UdIwQY
# MBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRpbWUt
# U3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYIKwYB
# BQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWlj
# cm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1UdEwEB
# /wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeAMA0G
# CSqGSIb3DQEBCwUAA4ICAQCR3B4HjLG8uyksqrQP6aLIPhDQRzFUWk1m4nGJHniB
# ZGR5MMO7KY14HTcmGWwGlvBJgnm5lKAMEK/AcQPZUvyUmkWU6msnPGxdYLY1N8D4
# 7487kWTmPDoseHqN4EAMMR1ADHceqLtmbQnC9D3fPl/p23GSbb1ao5wdhdFd8BDD
# LWFKstfJ95uWpHrqOk//2fR8KRZTiCCxSNClDY2CPUNXT0nhjfLun013zX5ezqpi
# j77tEqbyqIH/k0N6KA4uOUB4WCIRchFQlb6YnKqlDD445GVqpwWNHwe7Qb7/tsx1
# 6Trxhf6Q+kMGTtR74j/GCJgnXFwNEGf+9zMu03vb5EiUPhSBdgu4FIKT/+kMQ9fn
# Pf0Kv6uRzoThjbwU+TgGGWgDK+nrbw/jF8SVBjxNzGtpRtlKHKmhwTqfL3kPUrUG
# SW1masdUoLGaCWe46UzXk0oitcWVcLN2qkK0jBDjXvA0BUX9AM+/PNu6Y91OLp9v
# S0ttJxihtXrO9sGwywoQwThOPVv2ghcLx3JsmridtugRdilHCLVABulI2uf4/EZb
# 25/WrrcWcwm7iCbc6HreeNb+JV/vbeq7PIetKKNYyBjQeJGIdCLQnK7SHwx2FFSn
# ubFuYtByQ+I4XACUhpQ3+TvbnL9otamRFTp+qYuUQ7IflanIt3bcBjL2vy/5Chtr
# qzCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZIhvcNAQEL
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
# 0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggNWMIICPgIB
# ATCCAQGhgdmkgdYwgdMxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRl
# ZDEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjQzMUEtMDVFMC1EOTQ3MSUwIwYD
# VQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoD
# FQC6g74Ept9fOrJ+L0YsR1YeQIt5P6CBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA7nQz9TAiGA8yMDI2MTAxMDAz
# NDgwNVoYDzIwMjYxMDExMDM0ODA1WjB0MDoGCisGAQQBhFkKBAExLDAqMAoCBQDu
# dDP1AgEAMAcCAQACAi20MAcCAQACAhNzMAoCBQDudYV1AgEAMDYGCisGAQQBhFkK
# BAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJ
# KoZIhvcNAQELBQADggEBAIilSW5ShDASdqvQ61bNzBQUXMrZAgzuMV6R5jvG+utk
# L/oisAsykayLZJErV29EYtCNJcKguX4VuGmZdkEtJKv63LTgMdDwFtSlSRkMql0e
# iUcaoeAfFerFwt5m1Y5saWukrSLkN2cEmkG+Jary1zjf3hiGK34Ys9+XU1lW98Y/
# DAez6Qzs8wLHqAquyNVdEWTITmo5hRSCMPvT5L3rQ0XhhmzpbynfbXNQ/qnbiwh7
# zIDmVd68Qmdkf9d7Ob2kkuFnBMyCGjbXrDfmVpQoTYJvPiaPwcn4OUWOON8iDXTJ
# Zl4tousvM6DxFN5iK7RIibGirXTFQCWybwNwthGmpekxggQNMIIECQIBATCBkzB8
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1N
# aWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAh1LwJKHOIV+OQABAAAC
# HTANBglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEE
# MC8GCSqGSIb3DQEJBDEiBCDBAwn+y46VjHq63RGHEcJU0GcxuJhZ5O0LCFxGaKPX
# 0zCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EILG2lcxcSIsnOuozvt6nitM3
# Csw6PqClY32Fm+mPlAVRMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENB
# IDIwMTACEzMAAAIdS8CShziFfjkAAQAAAh0wIgQg7cY5IlanUW9mTuLYT+ubrO1E
# QygPMzdQROcMCg1/XTIwDQYJKoZIhvcNAQELBQAEggIASowh1aM2nGMSpJ9a3Etv
# clfd6jwbpUIMYGFRPyED/gOdIQOuFN9UdIsz6zbUKiLZ4ZxxwSozcXFUBA+bbH/b
# FoGCYj1B2/JbsFFFoA2oaFPUhe6iy2D6BPm/YUtZmVgPo0iQZHu2c/0WqZMsn0BS
# KAyFgSDB7H36APZkiTG9fb7lQ4rVtwyD0fdsmj7ZPeEhXe9rCUBsVYT84lPen7+M
# DCDg2001kWnqRF2LP+VN5fDGOBmMBTp7u9XdgT6Y4bq3Q7Bze7ce0RkmITXznNgI
# ZrVXmH95wv1NeYvOSOz/dUGr3vQyDbWqolu1BFxaL8/DkYMCFnmfoMAtqqpuP08l
# thnjF88wK465HjCpUgbItNUJjLyAMx/3B10iS16UoxhW/7MxaVdmwG2E23ZHULBV
# l7+YxDETk25mS+YG70ol0vunhsc/TerL7OGPvIfv/L9W1WZl6ZY37cDFrA4Yv7ef
# dHMUgvz2Yc446XgkADnK+jXqjIHq0FFTVrxlHMTHTam84irjx0wEug2C1iSp3DNx
# AXkVJDRmr/HfCGXpssZ6wlttYKTe3/TyyeQrdiocrPmdtQdPzLaSXC92HbBtH3i/
# jhF2CLMTsMokgZUQxezzVhIhQu0Wvhl7irVyZUwbNkNBQz6X5g5mnpxnW3+n3k04
# BY45HeU/qbK0sPwVkYN3EE0=
# SIG # End signature block
