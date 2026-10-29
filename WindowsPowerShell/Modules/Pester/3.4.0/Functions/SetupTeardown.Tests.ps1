Describe 'Describe-Scoped Test Case setup' {
    BeforeEach {
        $testVariable = 'From BeforeEach'
    }

    $testVariable = 'Set in Describe'

    It 'Assigns the correct value in first test' {
        $testVariable | Should Be 'From BeforeEach'
        $testVariable = 'Set in It'
    }

    It 'Assigns the correct value in subsequent tests' {
        $testVariable | Should Be 'From BeforeEach'
    }
}

Describe 'Context-scoped Test Case setup' {
    $testVariable = 'Set in Describe'

    Context 'The context' {
        BeforeEach {
            $testVariable = 'From BeforeEach'
        }

        It 'Assigns the correct value inside the context' {
            $testVariable | Should Be 'From BeforeEach'
        }
    }

    It 'Reports the original value after the Context' {
        $testVariable | Should Be 'Set in Describe'
    }
}

Describe 'Multiple Test Case setup blocks' {
    $testVariable = 'Set in Describe'

    BeforeEach {
        $testVariable = 'Set in Describe BeforeEach'
    }

    Context 'The context' {
        It 'Executes Describe setup blocks first, then Context blocks in the order they were defined (even if they are defined after the It block.)' {
            $testVariable | Should Be 'Set in the second Context BeforeEach'
        }

        BeforeEach {
            $testVariable = 'Set in the first Context BeforeEach'
        }

        BeforeEach {
            $testVariable = 'Set in the second Context BeforeEach'
        }
    }

    It 'Continues to execute Describe setup blocks after the Context' {
        $testVariable | Should Be 'Set in Describe BeforeEach'
    }
}

Describe 'Describe-scoped Test Case teardown' {
    $testVariable = 'Set in Describe'

    AfterEach {
        $testVariable = 'Set in AfterEach'
    }

    It 'Does not modify the variable before the first test' {
        $testVariable | Should Be 'Set in Describe'
    }

    It 'Modifies the variable after the first test' {
        $testVariable | Should Be 'Set in AfterEach'
    }
}

Describe 'Multiple Test Case teardown blocks' {
    $testVariable = 'Set in Describe'

    AfterEach {
        $testVariable = 'Set in Describe AfterEach'
    }

    Context 'The context' {
        AfterEach {
            $testVariable = 'Set in the first Context AfterEach'
        }

        It 'Performs a test in Context' { "some output to prevent the It being marked as Pending and failing because of Strict mode"}

        It 'Executes Describe teardown blocks after Context teardown blocks' {
            $testVariable | Should Be 'Set in the second Describe AfterEach'
        }
    }

    AfterEach {
        $testVariable = 'Set in the second Describe AfterEach'
    }
}

$script:DescribeBeforeAllCounter = 0
$script:DescribeAfterAllCounter  = 0
$script:ContextBeforeAllCounter  = 0
$script:ContextAfterAllCounter   = 0

Describe 'Test Group Setup and Teardown' {
    It 'Executed the Describe BeforeAll regardless of definition order' {
        $script:DescribeBeforeAllCounter | Should Be 1
    }

    It 'Did not execute any other block yet' {
        $script:DescribeAfterAllCounter | Should Be 0
        $script:ContextBeforeAllCounter | Should Be 0
        $script:ContextAfterAllCounter  | Should Be 0
    }

    BeforeAll {
        $script:DescribeBeforeAllCounter++
    }

    AfterAll {
        $script:DescribeAfterAllCounter++
    }

    Context 'Context scoped setup and teardown' {
        BeforeAll {
            $script:ContextBeforeAllCounter++
        }

        AfterAll {
            $script:ContextAfterAllCounter++
        }

        It 'Executed the Context BeforeAll block' {
            $script:ContextBeforeAllCounter | Should Be 1
        }

        It 'Has not executed any other blocks yet' {
            $script:DescribeBeforeAllCounter | Should Be 1
            $script:DescribeAfterAllCounter  | Should Be 0
            $script:ContextAfterAllCounter   | Should Be 0
        }
    }

    It 'Executed the Context AfterAll block' {
        $script:ContextAfterAllCounter | Should Be 1
    }
}

Describe 'Finishing TestGroup Setup and Teardown tests' {
    It 'Executed each Describe and Context group block once' {
        $script:DescribeBeforeAllCounter | Should Be 1
        $script:DescribeAfterAllCounter  | Should Be 1
        $script:ContextBeforeAllCounter  | Should Be 1
        $script:ContextAfterAllCounter   | Should Be 1
    }
}


if ($PSVersionTable.PSVersion.Major -ge 3)
{
    $thisTestScriptFilePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($PSCommandPath)

    Describe 'Script Blocks and file association (testing automatic variables)' {
        BeforeEach {
            $commandPath = $PSCommandPath
        }

        $beforeEachBlock = InModuleScope Pester {
            $pester.BeforeEach[0].ScriptBlock
        }

        It 'Creates script block objects associated with the proper file' {
            $scriptBlockFilePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($beforeEachBlock.File)

            $scriptBlockFilePath | Should Be $thisTestScriptFilePath
        }

        It 'Has the correct automatic variable values inside the BeforeEach block' {
            $commandPath | Should Be $PSCommandPath
        }
    }
}

#Testing if failing setup or teardown will fail 'It' is done in the TestsRunningInCleanRunspace.Tests.ps1 file

# SIG # Begin signature block
# MIInbQYJKoZIhvcNAQcCoIInXjCCJ1oCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAuMr2lGMekvHLf
# +pJ03VWUau1QIy87P40nhLpns6ETnKCCC8MwggXaMIIEwqADAgECAhMzAAABP8rF
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
# BgkqhkiG9w0BCQQxIgQgt/ThmHMA36xthBAcvt1/04eG3bCXqC+or9whkYtTR58w
# UAYKKwYBBAGCNwoDHDFCDEA0MjdCQkJCMEUzQkQzNUYwMjgxNjRFRjdDNEI0REY3
# NUJBNzM1REU4M0NGQzg2Mzg2MEU4NkRBRDk1RDI0ODA4MFoGCisGAQQBgjcCAQwx
# TDBKoCSAIgBNAGkAYwByAG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggGA
# PPi+vBzdY82vzYEPhMbVg6SvYLKgcn6oevboJDZ9KLkHFADc+plhrnwF1VIKcYNL
# RQy0Ll+tOdY1akV61Z0ywwIuH+Vbj8NJMFs0JIbo3yn5mNbjp63+f7MiMqmw+SGp
# WlLdgTjOVPmrzXDSm5R+ANxyy9FkuqAqNNGP+/GV8DD74TI83/e9Nz2LZj+lGmni
# sxuo/GVZnr0Q7301ZJzevzDZeyk5aQAVr/utLCTBG29dyCrrJRozKf5Cl9I96HoC
# QN5e5ucQzYmZUBYScLVGVmdB5zCtt6FSVCpd8LYMwwEBHgjDZaUIrxj/evRwUVM/
# cpOwST6DBb2tqTccgv/WsC1HBt/NBa3wfcw/O0yFqrg3IIUTdb1OUENuHHFQrP1H
# vxrTbfxZUyauC4Th+y/QNVeqriWJYJa7AJK65Gfg45/DUqRz9k7Sj/jpKcoCfsEb
# lBx5N1FjP3PcXYjD716gTyp+o0JagB+ifjo9F6u9u4wD5fhtMYyXCzIMDzJLHeD5
# oYIXrTCCF6kGCisGAQQBgjcDAwExgheZMIIXlQYJKoZIhvcNAQcCoIIXhjCCF4IC
# AQMxDzANBglghkgBZQMEAgEFADCCAVoGCyqGSIb3DQEJEAEEoIIBSQSCAUUwggFB
# AgEBBgorBgEEAYRZCgMBMDEwDQYJYIZIAWUDBAIBBQAEIEiUur33G/I+K5RQmSJd
# hawClOxP+NQbsTNMWWEjdhupAgZqrmIEoH4YEzIwMjYxMDEwMDgzNjM2LjE0M1ow
# BIACAfSggdmkgdYwgdMxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRl
# ZDEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjRDMUEtMDVFMC1EOTQ3MSUwIwYD
# VQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloIIR+zCCBygwggUQoAMC
# AQICEzMAAAIYJdmSBeLn5eQAAQAAAhgwDQYJKoZIhvcNAQELBQAwfDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcNMjUwODE0MTg0ODI1WhcNMjYxMTEzMTg0
# ODI1WjCB0zELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEtMCsG
# A1UECxMkTWljcm9zb2Z0IElyZWxhbmQgT3BlcmF0aW9ucyBMaW1pdGVkMScwJQYD
# VQQLEx5uU2hpZWxkIFRTUyBFU046NEMxQS0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1p
# Y3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUAA4IC
# DwAwggIKAoICAQCx3Ojq65AmoB/Eue8QF8i+PqScr6npucxcQVn9CM84XLCVyMN/
# MjwODWfMOXGbv+mpu+NaHK9rMqYXI7qps/AKV9GcjnuHk4KLGCk44IYklAhlJOIy
# C6LcHwM+IW0k9x/NG3cWyfGMtfAEiMaCeMZ+ZCXvN6MDVahgv+oGZCHD8UMVNZ5v
# F+jibREII7F/arCPfVo6NzZphR4+0sxcexco8UfS2nlIogX/20nFFKDQ1gS9CpWK
# WN7xpCQ93erMC7HYxzkcxIrg0xO1VUJgBYNRnin7qIMj23kE0IEix/migU1Ra3EK
# qekViItiQd8V/GFVQFnwsYbFiwDfqycPrmzYd/i3zqTR7xZ6Uf+6x+Fio4zfPbJo
# jyuDTzrfUiTCpTPJCgQ+oyweAF6bXGmY4ZIhSdW9OwC/6WYQIvZGqtw5mVlrHwrR
# qKKPyHpSRYE3YgD+KRpyRNIZVEFCZZZm4sVZX9PjG43OxwLRfvGjh962CmypoQDS
# Nj9B6+RO8u/g6U03144vws2HtWbRHrk/uhps5AOq1QUDAKCOA8nSJX+NAJowBw7d
# JikbnBIBiImSThcuM1KU3FTYh2OzWw5GGXuzssLqE5vttUAdXA43vgbF8U2IQgDo
# F+50A2OlAnSdRz+mkRelPimAMEexi1Xw7IpKMqwjE50VHt8gkiMNzwO9SQIDAQAB
# o4IBSTCCAUUwHQYDVR0OBBYEFCQuocRcOhtjt0e6hAIFrixftovRMB8GA1UdIwQY
# MBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRpbWUt
# U3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYIKwYB
# BQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWlj
# cm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1UdEwEB
# /wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeAMA0G
# CSqGSIb3DQEBCwUAA4ICAQCeSNGGPA+B2gim+3hiKhP+PQta4HEXcBEEpcMQ2CCt
# oq8LShE/BuMCaxec8Sa26jkwPy4n1fD15ivGqqQrgMX2ydkyscx+ijEJr77WKsvP
# xiijMLi1yL5rg3ftJuR7Wm3XGz2pm2+Q+BkZafkFzBV+YDBJkseLYK5nTpjT9f63
# p80GetsxWi81oNfhY93Ij0YTPF8iCAOxyTYimjhVcv8CtzPunYXtsRkZG7LGOAwL
# 7CgKQMlof/KT/BxmkCyLF7g8503QNbplvfk7cODf5rqmsA0xzdYh298oOXvk/Rqp
# xBtABHtvR/iAfg0yRRy3RabgY3kqGwTVgrtX/ACoMqYriPHfMvPdrwezFr0cHcbK
# K2WYLmwOE6XhBMY3mRGLqgKhXiEr6QgWCeRaMeFJE2ibPfpCdsJIb8EcsSbYZFT2
# 7f8jjNR30TUAL3sgkQZ/Bv7Q1ZvdARyuTKl0Z1bCXQsQ5uGtBH0HVXv551zI2axf
# SnYFfSsWl3U+RclJvF/whwSLD9uQ2BqBkT5WUO3Fd6u4t2jmTeUY6/us9i44Rqhl
# jEO9m2kc/0/frCZbgg2NHo0iefZQz6Ss//F4udFsMGSb1GyWegOFWtqWIoMfrYHG
# FyAv22JGA4eVwjTCq9VYt2/zJbyvGRrA6WEJGpPcQoQJbyS1QA/A1sFQuRP6hZy8
# FzCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZIhvcNAQEL
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
# ZDEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjRDMUEtMDVFMC1EOTQ3MSUwIwYD
# VQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoD
# FQCda0atdaK40TxCsp+bgK0avnvP6aCBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA7nPk+TAiGA8yMDI2MTAwOTIy
# MTEwNVoYDzIwMjYxMDEwMjIxMTA1WjB0MDoGCisGAQQBhFkKBAExLDAqMAoCBQDu
# c+T5AgEAMAcCAQACAg0IMAcCAQACAhLhMAoCBQDudTZ5AgEAMDYGCisGAQQBhFkK
# BAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJ
# KoZIhvcNAQELBQADggEBACb3+MMBXNq2cZUjldOz/WefBTvewg5apSpw0Yt1mGsx
# 7DrUDHKce3OmBKwStf4YBVo2ETQnBYnHdpQVABFIlVyXchLbjxBKw8szZFEGHMZ7
# zTOl83l0LMnREVYESK3xB+ZwgR4mWVxLG9sj9ca5ttvEyCzinzGDAxyqSkOiu1g7
# ojESGSk2jYaQMU7K8bEzAJML9qXavjBO246Zas8sbt9lmTDZp1OR619ezitkytT8
# uz5tAeKdv5YQFUzttSqZB45wtsxdNcdbfAiLm4TkpLKfuW8rvvtxgxiHKMc1/lnQ
# /4i+fX9GOtekkhRTLOAbUXpuywaGe7zVk90MXC7+bPcxggQNMIIECQIBATCBkzB8
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1N
# aWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAhgl2ZIF4ufl5AABAAAC
# GDANBglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEE
# MC8GCSqGSIb3DQEJBDEiBCBArK3lPIx7I9JDJOMrTVdrf+W4+kcnsmKk0cFEdnUU
# 2jCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIJkT3Im45Mi0jBZoRLqXMYor
# VdxKjPXKdHNo5XPH14VqMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENB
# IDIwMTACEzMAAAIYJdmSBeLn5eQAAQAAAhgwIgQgfeCxLFMj36K8gqKUlSDJUD0C
# uEQ9Qcxrbr5lXU4vMecwDQYJKoZIhvcNAQELBQAEggIAj9jjDtN5IJROGOxcxtPN
# O+Ei/8TOfzlw5C/P+jwWMvhr5LgW2pfR/Eti3t5CcXRoWsx9XFjI/Py9m1HEOVl1
# fg8fAMAKKdbGdcj09Q8+8blul6wk/aJFeOpBMf1Yao2C/89BlcSPFBtnmhJu0Gxy
# Ey1eFLnakjKGmstlmXF64o88Q+cfQqIBV0yce3mx8IllCSLohvISUgNi+3MsQCIV
# tn6nRsO89Sg7DXqlwC+PSlXRK4SMEMn2ST0JCuIZ/u5OvBPD0hpVW4u/lDp4oIPG
# sctP74Nx2996+WBEKv70nlYAKm8yxY3rLuweLkKkSKj07p4RA8a3sOCbs1Nlw1Og
# y4aUtdxUpwzUYhVDZzj9QUtwz55vtfw0WqvxnEfDddnKYn9uiTckx95uXWsVaLj3
# +Af5pEw9evpWprRnjSInfu8OtAHgOrTKt9gPtCyYHCJVz4SfsdxPDYY1zabxb8xL
# Kwy8+6Ki7lLBFI2P3oRt3VxJeAdcYpn7/IRn3ebzvqKVRAbOjQkY0ubI5zuvui66
# DV/EjAHPAZDYkBRem49zkh0Plzqv21FM+ZSNtfxjqN1LYvjcWSgMhosB62DUQluj
# kf5YHbRuNHXPoViMpUGGbViFPLDO2Rwge0+EkuNeWwWjwQNV58kyZoBK5uDTDB5p
# IJ9mTRMryUOboXvOS+z7Z6o=
# SIG # End signature block
