Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "PesterThrow" {
        It "returns true if the statement throws an exception" {
            Test-PositiveAssertion (PesterThrow { throw })
        }

        It "returns false if the statement does not throw an exception" {
            Test-NegativeAssertion (PesterThrow { 1 + 1 })
        }

        It "returns true if the statement throws an exception and the actual error text matches the expected error text" {
            $expectedErrorMessage = "expected error message"
            Test-PositiveAssertion (PesterThrow { throw $expectedErrorMessage } $expectedErrorMessage)
        }

        It "returns false if the statement throws an exception and the actual error does not match the expected error text" {
            $unexpectedErrorMessage = "unexpected error message"
            $expectedErrorMessage = "some expected error message"
            Test-NegativeAssertion (PesterThrow { throw $unexpectedErrorMessage} $expectedErrorMessage)
        }

        It "returns true if the statement throws an exception and the actual error text matches the expected error pattern" {
            Test-PositiveAssertion (PesterThrow { throw "expected error"} "error")
        }
    }

    Describe "Get-DoMessagesMatch" {
        It "returns true if the actual message is the same as the expected message" {
            $expectedErrorMessage = "expected"
            $actualErrorMesage = "expected"
            $result = Get-DoMessagesMatch $actualErrorMesage $expectedErrorMessage
            $result | Should Be $True
        }

        It "returns false if the actual message is not the same as the expected message" {
            $expectedErrorMessage = "some expected message"
            $actualErrorMesage = "unexpected"
            $result = Get-DoMessagesMatch $actualErrorMesage $expectedErrorMessage
            $result | Should Be $False
        }

        It "returns false is there's no expectation" {
            $result = Get-DoMessagesMatch "" ""
            $result | Should Be $False
        }

        It "returns true if the expected error is contained in the actual message" {
            $actualErrorMesage = "this is a long error message"
            $expectedText = "long error"
            $result = Get-DoMessagesMatch $actualErrorMesage $expectedText
            $result | Should Be $True
        }
    }

    Describe 'PesterThrowFailureMessage' {
        $testScriptPath = Join-Path $TestDrive.FullName test.ps1

        It 'returns false if the actual message is not the same as the expected message' {
            $unexpectedErrorMessage = 'unexpected'
            $expectedErrorMessage = 'some expected message'
            Set-Content -Path $testScriptPath -Value "throw '$unexpectedErrorMessage'"

            PesterThrow { & $testScriptPath } $expectedErrorMessage > $null
            $result = PesterThrowFailureMessage $unexpectedErrorMessage $expectedErrorMessage
            $result | Should Match "^Expected: the expression to throw an exception with message {$expectedErrorMessage}, an exception was raised, message was {$unexpectedErrorMessage}`n    from $([RegEx]::Escape($testScriptPath)):\d+ char:\d+"
        }

        It 'returns true if the actual message is the same as the expected message' {
            PesterThrow { } > $null
            $result = PesterThrowFailureMessage 'error message'
            $result | Should Be 'Expected: the expression to throw an exception'
        }
    }

    Describe 'NotPesterThrowFailureMessage' {
        $testScriptPath = Join-Path $TestDrive.FullName test.ps1

        It 'returns false if the actual message is not the same as the expected message' {
            $unexpectedErrorMessage = 'unexpected'
            $expectedErrorMessage = 'some expected message'
            Set-Content -Path $testScriptPath -Value "throw '$unexpectedErrorMessage'"

            PesterThrow { & $testScriptPath } $expectedErrorMessage > $null
            $result = NotPesterThrowFailureMessage $unexpectedErrorMessage $expectedErrorMessage
            $result | Should Match "^Expected: the expression not to throw an exception with message {$expectedErrorMessage}, an exception was raised, message was {$unexpectedErrorMessage}`n    from $([RegEx]::Escape($testScriptPath)):\d+ char:\d+"
        }

        It 'returns true if the actual message is the same as the expected message' {
            Set-Content -Path $testScriptPath -Value "throw 'error message'"
            PesterThrow { & $testScriptPath } > $null
            $result = NotPesterThrowFailureMessage 'error message'
            $result | Should Match "^Expected: the expression not to throw an exception. Message was {error message}`n    from $([RegEx]::Escape($testScriptPath)):\d+ char:\d+"
        }
    }
}

# SIG # Begin signature block
# MIInRwYJKoZIhvcNAQcCoIInODCCJzQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAVnL9yiUPg5gD+
# cJ8osBcyjOhTH9lYQjbPD/Kg+XP2KKCCC7QwggXLMIIEs6ADAgECAhMzAAABQGf2
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
# GukwghrlAgEBMIGmMIGOMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMTgwNgYDVQQDEy9NaWNyb3NvZnQgV2luZG93cyBUaGlyZCBQYXJ0eSBDb21w
# b25lbnQgQ0EgMjAxMgITMwAAAUBn9phrMQi4cgAAAAABQDANBglghkgBZQMEAgEF
# AKCB+jAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAvBgkqhkiG9w0BCQQxIgQg
# yoSAr69yc1iNQ5X8gLiHcym+cUwtT5rnGqyO7W4A5F4wUAYKKwYBBAGCNwoDHDFC
# DEBFMzkyMUVFQTIyQ0U3MTlEQkE5ODRCQzFEOEM3QjMxNTczQjBBRUQ5NDkyQjI2
# OTBGMzgzMkI3QkY0Qzc0MzJGMFoGCisGAQQBgjcCAQwxTDBKoCSAIgBNAGkAYwBy
# AG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0cDovL3d3dy5taWNyb3Nv
# ZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggGAEw3EvaN2e1Y461IYGOL5
# hmvjI8rfQzG/PmTHDWzOKDo9JjdWLH1BjRWssUX16atQXwV/H5NifzVnmFq19gvf
# 5IzGIM+L3E/6VX6tofO4DbYToaSJxBkOj1g7DcneuvgX2iq6Rvq89R0rUzTNDz7B
# 4sCUOQEoEbCX6vHpfsI52d+Ffp6rbk5GwN9RNePKrj9voy6245l4pspJTMANbPTX
# cOlTgG4H10kT15v5n0QyRdhdykyPGa3ezaQ2FvEvwVPaBgUiY4m2VxiOMM/F4xDp
# khav3P8QxjBxllwH2h//U3U7bFFLN1fGvKMIcJVywFSW/Uc/LsjtrJ90JGy8g+Gt
# tfHwFhRlkj2lO/b1ANj4MZlMWO4jzrsz9fWPmlAYw5fuog6fVFWKRvJlVpl9Xqcw
# 2kNqth1zF8SD1KzN64AweDOpGK4iY2AMOUgWFkLE/cC8TL4UAA+Accs3jUpKAHsk
# F8bacGLJ3ZelOas8vIRRK6LUkuTOrxcZixYwCQCqg/VUoYIXljCCF5IGCisGAQQB
# gjcDAwExgheCMIIXfgYJKoZIhvcNAQcCoIIXbzCCF2sCAQMxDzANBglghkgBZQME
# AgEFADCCAVEGCyqGSIb3DQEJEAEEoIIBQASCATwwggE4AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIOlN4IbRLTWlSaaajl74MzAOQ8SoPBzh5Rz1MJOE
# MCO6AgZqqqeED4IYEjIwMjYxMDEwMDgzNjM0Ljk5WjAEgAIB9KCB0aSBzjCByzEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1Mg
# RVNOOkUwMDItMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFt
# cCBTZXJ2aWNloIIR7TCCByAwggUIoAMCAQICEzMAAAIpDtVkKrSX8hoAAQAAAikw
# DQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcN
# MjYwMjE5MTk0MDA3WhcNMjcwNTE3MTk0MDA3WjCByzELMAkGA1UEBhMCVVMxEzAR
# BgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1p
# Y3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2Eg
# T3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOkUwMDItMDVFMC1E
# OTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNlMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAniLRauM9aAmEplGZqWA7GyVhLvvt
# W23PzM+z2tyNGV+RDjfloqwdBb5xpchUVMpczuUyV2X1PEBTzlPeT9WNTmfCfqrg
# ORvgFkgTq/+PLHJdLPUQaaoEzKv5W8qgc+AjJr1UdkHrwIFaeGtYW5jpvRu2Fnsu
# vDeRea0g2FdMDJYOCMvGEbhYETdngaVV7fSLxWhZgZ0C2X6Ntimdy/D1hB1IV1OX
# SzkmaE36qkPwfnXluegAjJ5x4z8WbvrMx4WTC1KzFk4LPSewp/A7XpXCo/WjPtGa
# u7ZEgxwq8KOngkn8N3JZLV0Ua3ZrHHGpfEQg4jRRYGbMqcBdmhgBepIONfkJfrYV
# 6ZzjFB+JjwgCWVqdMw1qMLCv2KOYxy9aU/wIGy9xaAMuHG4TiOD29XkBRvo0+7JE
# thf2/mQAlANRA2fN9CvgbtMsPhaUhsvLaXdbM5N3FGIyKcyBuM96BTZokiTfGHTX
# eEh7BEeQ5LOW8Yim6b5n6zgN/Y02+xFtk0+8kloCSEn703s7i5kLE1UszbL2qVZR
# 4RNswag8ONPZ7zrYrQhW54YVzX2rc29vhn9rV9rOmAWtedQgv/Pnpib73oF21jbn
# c2LfHBUaJtD2fnyUYYQX3Uqgqq/EHjhifFWJZsRV6sdUnQ0pEwkoKbLJBqmcIf+r
# pgNYOC+83hgTZ4ECAwEAAaOCAUkwggFFMB0GA1UdDgQWBBQnTUWki/QFvEL2kNtV
# o0QFyjeDOzAfBgNVHSMEGDAWgBSfpxVdAF5iXYP05dJlpxtTNRnpcjBfBgNVHR8E
# WDBWMFSgUqBQhk5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9N
# aWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcmwwbAYIKwYB
# BQUHAQEEYDBeMFwGCCsGAQUFBzAChlBodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20v
# cGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEw
# KDEpLmNydDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMA4G
# A1UdDwEB/wQEAwIHgDANBgkqhkiG9w0BAQsFAAOCAgEAPcHO9pX/3Mw4adPU9zxg
# DDkIcZf8dOI6RO7d/RXqkEp9lKeg1c4YMJ8wqmNzSIS7VGlq3ezcb64WQ3GvieMc
# 760UDTx3kUKZyVXh7Mk7ud4EwZVAdU0SOjp2bfwFZkfaDCfzQTqgfnfkjm/D8es0
# YEcJOtrBZDpAeZYoPwzJ2BHkf2plvR3aPL13Cpmmvw20jgB0nX2RbfoqjGXzZZBD
# p+9f0QCkzb+EKav9hYXIzDJkpCIbIQXQVQdFY5pMBX4VVH+U07iyfbA0eBMgrzmS
# dweoOyMOlo0McnI8JH87FTE6X7rCeUsHThy/Mhj1mTnj48GvCEl1rOpIlSv+ktPy
# VW9S6cacmCkREI51P+TnnCrdjl5R3cBVma8AIvfET2WuhBMXG/yxi39dLTR47tXk
# 5aIWNI8zWUNAQ4ErjGYDFPvBBI7TEDCA55TxhFDjeyx1xx9Ci9BQNNTxFlWSq6/y
# 1Drrg0zRc8OeNxTzKeIJAiBZSnUbnIkdSFzpPl7Huq4/bSRWIFZ/uOAR6Ltl0HuU
# V99Hn9wEFmtJschg6icxrFd1+fmzUHjFfPIlrpST6ubIJxhvTvx9fxx+B7DvWShl
# /1qyaUJhbkK0zkePV473mgtMWhZhrDYPkYW7Q+ak5J/iEg78NCCfxP1VzXc/8loK
# Jeq+dO4U/LADLqZ4ZBdrsNQwggdxMIIFWaADAgECAhMzAAAAFcXna54Cm0mZAAAA
# AAAVMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0ZSBB
# dXRob3JpdHkgMjAxMDAeFw0yMTA5MzAxODIyMjVaFw0zMDA5MzAxODMyMjVaMHwx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1p
# Y3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMIICIjANBgkqhkiG9w0BAQEFAAOC
# Ag8AMIICCgKCAgEA5OGmTOe0ciELeaLL1yR5vQ7VgtP97pwHB9KpbE51yMo1V/YB
# f2xK4OK9uT4XYDP/XE/HZveVU3Fa4n5KWv64NmeFRiMMtY0Tz3cywBAY6GB9alKD
# RLemjkZrBxTzxXb1hlDcwUTIcVxRMTegCjhuje3XD9gmU3w5YQJ6xKr9cmmvHaus
# 9ja+NSZk2pg7uhp7M62AW36MEBydUv626GIl3GoPz130/o5Tz9bshVZN7928jaTj
# kY+yOSxRnOlwaQ3KNi1wjjHINSi947SHJMPgyY9+tVSP3PoFVZhtaDuaRr3tpK56
# KTesy+uDRedGbsoy1cCGMFxPLOJiss254o2I5JasAUq7vnGpF1tnYN74kpEeHT39
# IM9zfUGaRnXNxF803RKJ1v2lIH1+/NmeRd+2ci/bfV+AutuqfjbsNkz2K26oElHo
# vwUDo9Fzpk03dJQcNIIP8BDyt0cY7afomXw/TNuvXsLz1dhzPUNOwTM5TI4CvEJo
# LhDqhFFG4tG9ahhaYQFzymeiXtcodgLiMxhy16cg8ML6EgrXY28MyTZki1ugpoMh
# XV8wdJGUlNi5UPkLiWHzNgY1GIRH29wb0f2y1BzFa/ZcUlFdEtsluq9QBXpsxREd
# cu+N+VLEhReTwDwV2xo3xwgVGD94q0W29R6HXtqPnhZyacaue7e3PmriLq0CAwEA
# AaOCAd0wggHZMBIGCSsGAQQBgjcVAQQFAgMBAAEwIwYJKwYBBAGCNxUCBBYEFCqn
# Uv5kxJq+gpE8RjUpzxD/LwTuMB0GA1UdDgQWBBSfpxVdAF5iXYP05dJlpxtTNRnp
# cjBcBgNVHSAEVTBTMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNodHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0w
# EwYDVR0lBAwwCgYIKwYBBQUHAwgwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEw
# CwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAU1fZWy4/o
# olxiaNE9lJBb186aGMQwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDovL2NybC5taWNy
# b3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYt
# MjMuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5j
# cnQwDQYJKoZIhvcNAQELBQADggIBAJ1VffwqreEsH2cBMSRb4Z5yS/ypb+pcFLY+
# TkdkeLEGk5c9MTO1OdfCcTY/2mRsfNB1OW27DzHkwo/7bNGhlBgi7ulmZzpTTd2Y
# urYeeNg2LpypglYAA7AFvonoaeC6Ce5732pvvinLbtg/SHUB2RjebYIM9W0jVOR4
# U3UkV7ndn/OOPcbzaN9l9qRWqveVtihVJ9AkvUCgvxm2EhIRXT0n4ECWOKz3+SmJ
# w7wXsFSFQrP8DJ6LGYnn8AtqgcKBGUIZUnWKNsIdw2FzLixre24/LAl4FOmRsqlb
# 30mjdAy87JGA0j3mSj5mO0+7hvoyGtmW9I/2kQH2zsZ0/fZMcm8Qq3UwxTSwethQ
# /gpY3UA8x1RtnWN0SCyxTkctwRQEcb9k+SS+c23Kjgm9swFXSVRk2XPXfx5bRAGO
# WhmRaw2fpCjcZxkoJLo4S5pu+yFUa2pFEUep8beuyOiJXk+d0tBMdrVXVAmxaQFE
# fnyhYWxz/gq77EFmPWn9y8FBSX5+k77L+DvktxW/tM4+pTFRhLy/AsGConsXHRWJ
# jXD+57XQKBqJC4822rpM+Zv/Cuk0+CQ1ZyvgDbjmjJnW4SLq8CdCPSWU5nR0W2rR
# nj7tfqAxM328y+l7vzhwRNGQ8cirOoo6CGJ/2XBjU02N7oJtpQUQwXEGahC0HVUz
# WLOhcGbyoYIDUDCCAjgCAQEwgfmhgdGkgc4wgcsxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9w
# ZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjpFMDAyLTA1RTAtRDk0
# NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcG
# BSsOAwIaAxUAt7/YkjttsaG+2cTeXVwhKvvSL/+ggYMwgYCkfjB8MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQg
# VGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQsFAAIFAO50HVAwIhgPMjAy
# NjEwMTAwMjExMjhaGA8yMDI2MTAxMTAyMTEyOFowdzA9BgorBgEEAYRZCgQBMS8w
# LTAKAgUA7nQdUAIBADAKAgEAAgIjnAIB/zAHAgEAAgISgDAKAgUA7nVu0AIBADA2
# BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIBAAIDB6EgoQowCAIB
# AAIDAYagMA0GCSqGSIb3DQEBCwUAA4IBAQDR1BbuC2PuEhAx7A3+MK0HtRWCaxAe
# Jjv8Ox2XczRm8z5CD6wCzmLayOhOmvTVEAqmB+PLEzu5YWfZFyNDlxnUEISYfmll
# 18br/ymSWab3jmQL2NVlv0ztivZswzrbxhZCu1yi88RR6qpvH8rj1k89dGjQpf/K
# JqYc61OwkupMXlqdFIb2qPEcrGS7rjUQm0AN0stfhvv+ZnorOCvtf4gStzBaNeVQ
# vXiQGmTcnBYOUvO6UHBkJbz9/opaoaVyBwiFjAt0cxMlvzs3massdkrEBWbowOqM
# xpf8Qdo+HiQ1fW4pHgRxk6yjRZLjtOUjKICgd1wNcT6W4614Yz9+9Ps4MYIEDTCC
# BAkCAQEwgZMwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAO
# BgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEm
# MCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAIpDtVk
# KrSX8hoAAQAAAikwDQYJYIZIAWUDBAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsq
# hkiG9w0BCRABBDAvBgkqhkiG9w0BCQQxIgQgW17XVvoDk+ob0T1mGgJ4N2NzMsuB
# agBgJ4Dw2BLkgKIwgfoGCyqGSIb3DQEJEAIvMYHqMIHnMIHkMIG9BCC3yj3xIrbw
# /5UrxLpsaj5JHjhLYJJihRFTLnpfaDq6kjCBmDCBgKR+MHwxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFBDQSAyMDEwAhMzAAACKQ7VZCq0l/IaAAEAAAIpMCIEILAOwijtE8Ge
# 3/WdCefcysLi0/WbTsYhwzpVqEBiuGyZMA0GCSqGSIb3DQEBCwUABIICAEp8Q7Za
# bNq1bmWp3mGx13Vhj6Gfw7sXlbDEUNHQsdBONTSYi/Fh3zpW1W5P6ZacvdQCWDM3
# oLKQDcsHnQ4qo/4DIZY0MEEynjjJFud8Z9LZojwEA4jhiYRhqVlCN+KpuFqN8sbT
# D+HUMcLv9IBEM72vuetBLxgfRi4aG46Xau/K+Q4T+9Ro4zfruuYwbP5mczHmHqbn
# VD/tGsKmgSf1rAc9AkJy3Z/uhl5ETknwZFAeN2h2joSv57JBTfYc3oqII4o9++Sb
# hHvH+EzUFeYDh4ycEHTocJeLXZxDNvHIHvP2CSOmysZgvvo6n2FoUWruqmBn2QQL
# m4yk15x067Zz5XR+hQBrarHS/01WmQP79gnBAxiIKl77pbbkoDFUJDtfX2cGctl5
# srriI+XXZunEAKBJE2D7+75KQivvbgcjnuvx1p0jx29fibZm9S6PPZLyU3vtev5a
# iCGHITxUpI8qDtaWYBjQgzmLGF2cu0nrukH1J4V7RMCorum6p/nO4AFy9K0APp6e
# /VVkhExjvbQc24BIR3l4ucWlehX3YIKTkOktgOqcYqnCKJdVpg6yy/OmyYMc5del
# GWxKyxZOKtQpKlQOMrn+GFWThuK5f0KtWjevkCHLfQTLtk7SL6xjbl53xOqgQYmj
# mwcv0ZHgMVUlN02YtlD5iQIybom8kq5iOBY0
# SIG # End signature block
