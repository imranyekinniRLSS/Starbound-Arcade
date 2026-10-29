function Invoke-PesterInJob ($ScriptBlock, [switch] $GenerateNUnitReport)
{
    $PesterPath = Get-Module Pester | Select-Object -First 1 -ExpandProperty Path

    $job = Start-Job {
        param ($PesterPath, $TestDrive, $ScriptBlock, $GenerateNUnitReport)
        Import-Module $PesterPath -Force | Out-Null
        $ScriptBlock | Set-Content $TestDrive\Temp.Tests.ps1 | Out-Null

        $params = @{
            PassThru = $true
            Path = $TestDrive
        }

        if ($GenerateNUnitReport)
        {
            $params['OutputFile'] = "$TestDrive\Temp.Tests.xml"
            $params['OutputFormat'] = 'NUnitXml'
        }

        Invoke-Pester @params

    } -ArgumentList  $PesterPath, $TestDrive, $ScriptBlock, $GenerateNUnitReport
    $job | Wait-Job | Out-Null

    #not using Recieve-Job to ignore any output to Host
    #TODO: how should this handle errors?
    #$job.Error | foreach { throw $_.Exception  }
    $job.Output
    $job.ChildJobs| foreach {
        $childJob = $_
        #$childJob.Error | foreach { throw $_.Exception }
        $childJob.Output
    }
    $job | Remove-Job
}

Describe "Tests running in clean runspace" {
    It "It - Skip and Pending tests" {
        #tests to be run in different runspace using different Pester instance
        $TestSuite = {
            Describe 'It - Skip and Pending tests' {

                It "Skip without ScriptBlock" -skip
                It "Skip with empty ScriptBlock" -skip {}
                It "Skip with not empty ScriptBlock" -Skip {"something"}

                It "Implicit pending" {}
                It "Pending without ScriptBlock" -Pending
                It "Pending with empty ScriptBlock" -Pending {}
                It "Pending with not empty ScriptBlock" -Pending {"something"}
            }
        }

        $result = Invoke-PesterInJob -ScriptBlock $TestSuite
        $result.SkippedCount | Should Be 3
        $result.PendingCount | Should Be 4
        $result.TotalCount | Should Be 7
    }

    It "It - It without ScriptBlock fails" {
        #tests to be run in different runspace using different Pester instance
        $TestSuite = {
            Describe 'It without ScriptBlock fails' {
               It "Fails whole describe"
               It "is not run" { "but it would pass if it was run" }

            }
        }

        $result = Invoke-PesterInJob -ScriptBlock $TestSuite
        $result.PassedCount | Should Be 0
        $result.FailedCount | Should Be 1

        $result.TotalCount | Should Be 1
    }

    It "Invoke-Pester - PassThru output" {
        #tests to be run in different runspace using different Pester instance
        $TestSuite = {
            Describe 'PassThru output' {
               it "Passes" { "pass" }
               it "fails" { throw }
               it "Skipped" -Skip {}
               it "Pending" -Pending {}
            }
        }

        $result = Invoke-PesterInJob -ScriptBlock $TestSuite
        $result.PassedCount | Should Be 1
        $result.FailedCount | Should Be 1
        $result.SkippedCount | Should Be 1
        $result.PendingCount | Should Be 1

        $result.TotalCount | Should Be 4
    }

    It 'Produces valid NUnit output when syntax errors occur in test scripts' {
        $invalidScript = '
            Describe "Something" {
                It "Works" {
                    $true | Should Be $true
                }
            # Deliberately missing closing brace to trigger syntax error
        '

        $result = Invoke-PesterInJob -ScriptBlock $invalidScript -GenerateNUnitReport

        $result.FailedCount | Should Be 1
        $result.TotalCount | Should Be 1
        'TestDrive:\Temp.Tests.xml' | Should Exist

        $xml = [xml](Get-Content TestDrive:\Temp.Tests.xml)

        $xml.'test-results'.'test-suite'.results.'test-suite'.name | Should Not BeNullOrEmpty
    }
}

Describe 'Guarantee It fail on setup or teardown fail (running in clean runspace)' {
    #these tests are kinda tricky. We need to ensure few things:
    #1) failing BeforeEach will fail the test. This is easy, just put the BeforeEach in the same try catch as the invocation
    #   of It code.
    #2) failing AfterEach will fail the test. To do that we might put the AfterEach to the same try as the It code, BUT we also
    #   want to guarantee that the AfterEach will run even if the test in It will fail. For this reason the AfterEach must be triggered in
    #   a finally block. And there we are not protected by the catch clause. So we need another try in the the finally to catch teardown block
    #   error. If we fail to do that the state won't be correctly cleaned up and we can get strange errors like: "You are still in It block", when
    #   running next test. For the same reason I am putting the "ensure all tests run" tests here. otherwise you get false positives because you cannot determine
    #   if the suite failed because of the whole suite failed or just a single test failed.

    It 'It fails if BeforeEach fails' {
        $testSuite = {
            Describe 'Guarantee It fail on setup or teardown fail' {
                BeforeEach {
                    throw [System.InvalidOperationException] 'test exception'
                }

                It 'It fails if BeforeEach fails' {
                    $true
                }
            }
        }

        $result = Invoke-PesterInJob -ScriptBlock $testSuite

        $result.FailedCount | Should Be 1
        $result.TestResult[0].FailureMessage | Should Be "test exception"
    }

    It 'It fails if AfterEach fails' {
        $testSuite = {
            Describe 'Guarantee It fail on setup or teardown fail' {
                It 'It fails if AfterEach fails' {
                    $true
                }

                 AfterEach {
                    throw [System.InvalidOperationException] 'test exception'
                }
            }

            Describe 'Make sure all the tests in the suite run' {
                #when the previous test fails in after each and
                It 'It is pending' -Pending {}
            }
        }

        $result = Invoke-PesterInJob -ScriptBlock $testSuite

        if ($result.PendingCount -ne 1)
        {
            throw "The test suite in separate runspace did not run to completion, it was likely terminated by an uncaught exception thrown in AfterEach."
        }

        $result.FailedCount | Should Be 1
        $result.TestResult[0].FailureMessage | Should Be "test exception"
    }
}

# SIG # Begin signature block
# MIInVwYJKoZIhvcNAQcCoIInSDCCJ0QCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDMXLR+Va7Sa4M8
# P5trYXi9LZnt+EF1eUV4EH3pEK60iqCCC8MwggXaMIIEwqADAgECAhMzAAABP8rF
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
# 8f7BcdpMoEFagt3xHzGCGuowghrmAgEBMIGmMIGOMQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMTgwNgYDVQQDEy9NaWNyb3NvZnQgV2luZG93cyBU
# aGlyZCBQYXJ0eSBDb21wb25lbnQgQ0EgMjAxMgITMwAAAT/KxSgZC4k1WAAAAAAB
# PzANBglghkgBZQMEAgEFAKCB+jAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAv
# BgkqhkiG9w0BCQQxIgQg8lI1aVvrGg9VlCVa7YFdaJoLCGcQzFAi7Ma44/Sqsy8w
# UAYKKwYBBAGCNwoDHDFCDEA4RTdGNTc0MUE0MjZGNkNBRjYwOTk0NTU0QURCRUI2
# QzRENTMxMUI2NEVEOEU3RUEwMDc1MkMwMUZDMTczOEIzMFoGCisGAQQBgjcCAQwx
# TDBKoCSAIgBNAGkAYwByAG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggGA
# JlSFg4kk+KQbkx6gF/dtYjlwducm9xiezKC0zdJ1KGUd8Klmqag11oTYJo6Z9HK2
# saZyfrL7gLJMCDu77lPjfoK9r6J+XE28qoEpYmN/OPdMLH0UpZxfeuGrTNXnYnuW
# WVeo+s8KxXcnFW1eg+rdJJkznDLJVyVMHRT+h3dnYZ9Pqol0oQL5rxMvFlkSgw0z
# 1Y0nYZ93KV/a0DXikcNUdQ/VILZNfyLsvFbwLB+b7jfHqDDdGa7WrZ+YW529w97p
# 4/PGGFwbdVwlwglH14KopS9MszLJ+QxwEruyn7MqV/ywkOWalHp0WHMRXP0g/fzc
# BLMK63Ckr+kkxEqD3NSYJAmRehs5JdKdZbA2ZOfqhKnMDYl4jjMrNNmcGoh+EBwy
# GYgqVl+HjJ2rWSlWNwJXgYYlxNc5Mcxg+w6mNR0eOzfC/E6dN9dnZezHpcYDXHnF
# GpmjkJ0k71LpFqJztDxDyNFmm/cDdkRX4IoAQY+mIhZym6+mkNdYRIuVN//vX0Bk
# oYIXlzCCF5MGCisGAQQBgjcDAwExgheDMIIXfwYJKoZIhvcNAQcCoIIXcDCCF2wC
# AQMxDzANBglghkgBZQMEAgEFADCCAVIGCyqGSIb3DQEJEAEEoIIBQQSCAT0wggE5
# AgEBBgorBgEEAYRZCgMBMDEwDQYJYIZIAWUDBAIBBQAEIKnMAtu5/6SeUv49Ej2X
# VTu6IFC96S7OOq7Q1/SIxcxyAgZqqowkcRIYEzIwMjYxMDEwMDgzNjM2LjExOVow
# BIACAfSggdGkgc4wgcsxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNV
# BAsTHm5TaGllbGQgVFNTIEVTTjpGMDAyLTA1RTAtRDk0NzElMCMGA1UEAxMcTWlj
# cm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaCCEe0wggcgMIIFCKADAgECAhMzAAAC
# ICTh5uAXubSOAAEAAAIgMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFBDQSAyMDEwMB4XDTI2MDIxOTE5Mzk1MloXDTI3MDUxNzE5Mzk1Mlowgcsx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1p
# Y3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNT
# IEVTTjpGMDAyLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3Rh
# bXAgU2VydmljZTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBANFhjvKv
# uKNboJHXvy4q94gy5+61Y6JzGAnAo5x7/YY5Bx66zplZ9fXiLeM2Dck4/swYkyQ4
# C5zBYHCIDxRGn5liQaOlWhWQZmxXbtaOovCl/YDCoGwn9POrATskUVrG6nct3GPw
# aN0nKYMVGt1U3+lgegEWuMPUiQgO7xvUJafy2CiaIpFJj5JO8mr32ZWR2mEwEhQY
# 56BCfLypF3bhUwTTGLw6iaSz1mr0SMN4ocam8BtdQRDqbdxE6gQ+FMT+aLB5Af1O
# om3cg6yo+/cvy6uiMHvjtcELbLQIMgeUotwuXdkbwPslcqdZMV6feaww8mly+tDf
# NQFUmsf+YjdHEeYKH2mkM/S4bX48nCTof/H6x+gb2FbrjGheSnHoMR81k19xd0pt
# cXbxcRd0s2fOjdIs1XKZ5AmE2o5IqGdTzhCcqauMSTnjUmK6uUMKQJY72VQFQxv3
# HSfJ9dRs1E9UuA/49MxF1c6jAl1gLMJB83ZmovSzhgjbwXUNufsGDDYTg/UT26ey
# 8zMke3OFLZOHdOkJ8Fs4ZqUiUX3H8Mln+yyb/LLNP1i0gV6qZ83EE9MTdo66HofG
# ZMgLN9gABO9Y2EFujX1DCyM94D0m+GpMsLYpQ2CteugbLh4NmjSfuMViNmRSKHVP
# L7wTqoS9XY1rpnmBTIPlr60cYOarr0KZSId/AgMBAAGjggFJMIIBRTAdBgNVHQ4E
# FgQU28ic4IiHEYDyZjuXWDTtQe/I2DMwHwYDVR0jBBgwFoAUn6cVXQBeYl2D9OXS
# ZacbUzUZ6XIwXwYDVR0fBFgwVjBUoFKgUIZOaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIw
# MTAoMSkuY3JsMGwGCCsGAQUFBwEBBGAwXjBcBggrBgEFBQcwAoZQaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBUaW1lLVN0
# YW1wJTIwUENBJTIwMjAxMCgxKS5jcnQwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8E
# DDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcNAQELBQADggIB
# AK0oYG2jUFK+bhYUj4nQ1LJWFTUscvsXd9uNnZ3sXkqf8UJMFlenOsNWXrcUtE1w
# gWmcnLj+eWDjevtPmwk92jgyzwANIdAQmcdK7fH1SmMLNEQE+L36ceG8OBHH/VaY
# EPqBBRkks6Fw3ZPFbgonKGKcy2IEW2Q1Fna+ZnUwB01dObl3QvCTfDOP79/tUIJN
# YJclKio1rdVT/qwAIcj3sS9ufODxt3eHGt/PoJwJW5/vt6C9EeKe2Em7BJF48/tp
# WZx69vWdZQgAgJ0F5sdA6vM0h5YEhDC9wVpLdIVz7j2uqvBA4wUNHgVgHNLtvRB4
# FXEW4svaJW7goAcw1SEstIPiIosMUE1M61PNOWEa8yAbvsDVyN5CsMwdrqhF4wN5
# QOodSvG/yDshF0iH6HSAMuTM3TEi7OWLQG/sm3JsYltXonFoMXgLNIIgxGkrn2cj
# qIqjguCdtAFklbv7pqRiwob+lc+V/E2/YiekPXS1IKQK/D2SvpbX41E34S5lzNGA
# DBaVwr1clne67+/+jEe07v+SZUiznUX2pXpjZA1d3q1Tjpg+sr3ybZAPKz6W8s2K
# YrR7XFntnUZrAqiEoa+UsAtYOVlCqAd8nfUIHQuUgMjuIvJhOl3aLIqOqyRtCLIy
# 0gIf5GYf+gKDsk4rRkDdcgxtr1pJaAEXdBnqkbcQZ5CqMIIHcTCCBVmgAwIBAgIT
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
# je6CbaUFEMFxBmoQtB1VM1izoXBm8qGCA1AwggI4AgEBMIH5oYHRpIHOMIHLMQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNy
# b3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBF
# U046RjAwMi0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFNlcnZpY2WiIwoBATAHBgUrDgMCGgMVAJMYD2+mwnqCWoIuYjSuCAbHhgQSoIGD
# MIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQG
# A1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwDQYJKoZIhvcNAQEL
# BQACBQDudAHcMCIYDzIwMjYxMDEwMDAxNDIwWhgPMjAyNjEwMTEwMDE0MjBaMHcw
# PQYKKwYBBAGEWQoEATEvMC0wCgIFAO50AdwCAQAwCgIBAAICRBsCAf8wBwIBAAIC
# EjIwCgIFAO51U1wCAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAK
# MAgCAQACAwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0BAQsFAAOCAQEAjzqn0rP+
# sb9MDkVDbd15860X+BlmDSaMsOXX/P/xqX3Oi7f9q97+WpB017cU3siAo7Om7FkF
# IltzM/UViZvRUFBuTX9PD5iN3P2cNMpUyIYwxMe9TUXLBrb7LJq6D5W18cOhoGPQ
# LAL7C/+wLckQ2OjAyo3s8QQ+O0e3UzHlG5X4lksVmkDVZfFSmMXMfnCumZhPdiS9
# v7rFJBK6c/DxDhisy/1OMEUVUikYiUq41VmpouMBO3pnlrtRwqWY4YfDGxdoNMLU
# c8hDSOCTqPi+WIqCmNkVS7g92DX+miznrTYL9luXoN41mp3g39hcVO3zrqugd5HM
# RYBoClJq8AnXGjGCBA0wggQJAgEBMIGTMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBD
# QSAyMDEwAhMzAAACICTh5uAXubSOAAEAAAIgMA0GCWCGSAFlAwQCAQUAoIIBSjAa
# BgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIEICSarSwA
# QsV5hCkWH6wMBcj7wwL3Ud33xDtOtuxNBSUMMIH6BgsqhkiG9w0BCRACLzGB6jCB
# 5zCB5DCBvQQg43u/I6U8DVWqUSnRAhUaU13xLlhYGcqP3su5NYdI7a8wgZgwgYCk
# fjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAiAk4ebgF7m0jgAB
# AAACIDAiBCDFaggr3y5eV1q6PWASXsImGiSSMTkTC4mb4pQc3Bd9CzANBgkqhkiG
# 9w0BAQsFAASCAgCFQU0P45WmSYQ2HIMro6vGygKt2XBs1fF29AxV+c1qkdkp5BQ0
# 4+Sk394RlXK3nnsRJGg4JVXrW4xS+rO+gRhzMyYT/19lbHXC5Xl7Zf/KRdfFDUds
# 0pbHX8Q3ZvrZzyZ1/qrE9wdnOZUmia6C1GM+jY+ARmxbuHSwLLlSX+O2hEn6zxdf
# DSzLB1ZolRgYMWw/b5Lhq4NEV17RGhV6/W8IUzzeX2ty2OikDwZ1Vft3n10KGPw/
# TsUaf0JAcfB8PzX534hwE81xi1WEFNbvxfs7VG9KRLt1rBQnRJNF8wCnfcMwUYI5
# G5VlxXPpdKQ1ufPzgOk8OEnki/8eAEIPByZF8jXOZdoAczy0kVe8W7wW+5Q6N46i
# lVQv/RuerfDOUrdv/lzmHpiotHJNAy639adwl4rSWpVMLpRfQIUBktsdCYhf1l+V
# v6Az+3kCsvYFFgNpL7LsTC25By6pXbRRHJzizto0j4fctvom9p21sWrk2nMgIFO/
# DR0HtIdrnTeJ9FC2gg9AaD+7nRL1DjAg7xJI5GthNJDY3jVnxZoEGMbBxnVKRanC
# m+Xt2yo7f4DNvTrZuxcoUrWRzjfftez+IpcB9yyd9VpFjMcKzbdBXwIyYxmhxGiI
# WjC3+rGoHb92rVpbh5Wl5asCZ4bM6B+piOcWibOx3TDzkZdzv7TWwH+tdQ==
# SIG # End signature block
