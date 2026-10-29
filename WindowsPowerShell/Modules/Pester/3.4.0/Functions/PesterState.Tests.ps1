Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "New-PesterState" {
        Context "TestNameFilter parameter is set" {
            $p = new-pesterstate -TestNameFilter "filter"

            it "sets the TestNameFilter property" {
                $p.TestNameFilter | should be "filter"
            }

        }
        Context "TagFilter parameter is set" {
            $p = new-pesterstate -TagFilter "tag","tag2"

            it "sets the TestNameFilter property" {
                $p.TagFilter | should be ("tag","tag2")
            }
        }

        Context "ExcludeTagFilter parameter is set" {
            $p = new-pesterstate -ExcludeTagFilter "tag3", "tag"

            it "sets the ExcludeTagFilter property" {
                $p.ExcludeTagFilter | should be ("tag3", "tag")
            }
        }

        Context "TagFilter and ExcludeTagFilter parameter are set" {
            $p = new-pesterstate -TagFilter "tag","tag2" -ExcludeTagFilter "tag3"

            it "sets the TestNameFilter property" {
                $p.TagFilter | should be ("tag","tag2")
            }

            it "sets the ExcludeTagFilter property" {
                $p.ExcludeTagFilter | should be ("tag3")
            }
        }
        Context "TestNameFilter and TagFilter parameter is set" {
            $p = new-pesterstate -TagFilter "tag","tag2" -testnamefilter "filter"

            it "sets the TestNameFilter property" {
                $p.TagFilter | should be ("tag","tag2")
            }

            it "sets the TestNameFilter property" {
                $p.TagFilter | should be ("tag","tag2")
            }

        }
    }

    Describe "Pester state object" {
        $p = New-PesterState

        Context "entering describe" {
            It "enters describe" {
                $p.EnterDescribe("describe")
                $p.CurrentDescribe | should be "Describe"
            }
            It "can enter describe only once" {
                { $p.EnterDescribe("describe") } | Should Throw
            }

            It "Reports scope correctly" {
                $p.Scope | should be "describe"
            }
        }
        Context "leaving describe" {
            It "leaves describe" {
                $p.LeaveDescribe()
                $p.CurrentDescribe | should benullOrEmpty
            }
            It "Reports scope correctly" {
                $p.Scope | should benullOrEmpty
            }
        }

        context "Entering It from Describe" {
            $p.EnterDescribe('Describe')

            It "Enters It successfully" {
                { $p.EnterTest("It") } | Should Not Throw
            }

            It "Reports scope correctly" {
                $p.Scope | Should Be 'It'
            }

            It "Cannot enter It after already entered" {
                { $p.EnterTest("It") } | Should Throw
            }

            It "Cannot enter Context from inside It" {
                { $p.EnterContext("Context") } | Should Throw
            }
        }

        context "Leaving It from Describe" {
            It "Leaves It to Describe" {
                { $p.LeaveTest() } | Should Not Throw
            }

            It "Reports scope correctly" {
                $p.Scope | Should Be 'Describe'
            }

            $p.LeaveDescribe()
        }

        Context "entering Context" {
            it "Cannot enter Context before Describe" {
                { $p.EnterContext("context") } | should throw
            }

            it "enters context from describe" {
                $p.EnterDescribe("Describe")
                $p.EnterContext("Context")
                $p.CurrentContext | should be "Context"
            }
            It "can enter context only once" {
                { $p.EnterContext("Context") } | Should Throw
            }

            It "Reports scope correctly" {
                $p.Scope | should be "Context"
            }
        }

        Context "leaving context" {
            it "cannot leave describe before leaving context" {
                { $p.LeaveDescribe() } | should throw
            }
            it "leaves context" {
                $p.LeaveContext()
                $p.CurrentContext | should BeNullOrEmpty
            }
            It "Returns from context to describe" {
                $p.Scope | should be "Describe"
            }

            $p.LeaveDescribe()
        }

        context "Entering It from Context" {
            $p.EnterDescribe('Describe')
            $p.EnterContext('Context')

            It "Enters It successfully" {
                { $p.EnterTest("It") } | Should Not Throw
            }

            It "Reports scope correctly" {
                $p.Scope | Should Be 'It'
            }

            It "Cannot enter It after already entered" {
                { $p.EnterTest("It") } | Should Throw
            }
        }

        context "Leaving It from Context" {
            It "Leaves It to Context" {
                { $p.LeaveTest() } | Should Not Throw
            }

            It "Reports scope correctly" {
                $p.Scope | Should Be 'Context'
            }

            $p.LeaveContext()
            $p.LeaveDescribe()
        }

        context "adding test result" {
            $p.EnterDescribe('Describe')

            it "adds passed test" {
                $p.AddTestResult("result","Passed", 100)
                $result = $p.TestResult[-1]
                $result.Name | should be "result"
                $result.passed | should be $true
                $result.Result | Should be "Passed"
                $result.time.ticks | should be 100
            }
            it "adds failed test" {
                try { throw 'message' } catch { $e = $_ }
                $p.AddTestResult("result","Failed", 100, "fail", "stack","suite name",@{param='eters'},$e)
                $result = $p.TestResult[-1]
                $result.Name | should be "result"
                $result.passed | should be $false
                $result.Result | Should be "Failed"
                $result.time.ticks | should be 100
                $result.FailureMessage | should be "fail"
                $result.StackTrace | should be "stack"
                $result.ParameterizedSuiteName | should be "suite name"
                $result.Parameters['param'] | should be 'eters'
                $result.ErrorRecord.Exception.Message | should be 'message'
            }

            it "adds skipped test" {
                $p.AddTestResult("result","Skipped", 100)
                $result = $p.TestResult[-1]
                $result.Name | should be "result"
                $result.passed | should be $true
                $result.Result | Should be "Skipped"
                $result.time.ticks | should be 100
            }

            it "adds Pending test" {
                $p.AddTestResult("result","Pending", 100)
                $result = $p.TestResult[-1]
                $result.Name | should be "result"
                $result.passed | should be $true
                $result.Result | Should be "Pending"
                $result.time.ticks | should be 100
            }

            it "can add test result before entering describe" {
                if ($p.CurrentContext) { $p.LeaveContext()}
                if ($p.CurrentDescribe) { $p.LeaveDescribe() }
                { $p.addTestResult(1,"Passed",1) } | should not throw
            }

            $p.LeaveContext()
            $p.LeaveDescribe()

        }

        Context "Path and TestNameFilter parameter is set" {
            $strict = New-PesterState -Strict

            It "Keeps Passed state" {
                $strict.AddTestResult("test","Passed")
                $result = $strict.TestResult[-1]

                $result.passed | should be $true
                $result.Result | Should be "Passed"
            }

            It "Keeps Failed state" {
                $strict.AddTestResult("test","Failed")
                $result = $strict.TestResult[-1]

                $result.passed | should be $false
                $result.Result | Should be "Failed"
            }

            It "Changes Pending state to Failed" {
                $strict.AddTestResult("test","Pending")
                $result = $strict.TestResult[-1]

                $result.passed | should be $false
                $result.Result | Should be "Failed"
            }

            It "Changes Skipped state to Failed" {
                $strict.AddTestResult("test","Skipped")
                $result = $strict.TestResult[-1]

                $result.passed | should be $false
                $result.Result | Should be "Failed"
            }
        }
    }
    Describe ConvertTo-FailureLines {
        $testPath = Join-Path $TestDrive test.ps1
        $escapedTestPath = [regex]::Escape($testPath)
        It 'produces correct message lines.' {
            try { throw 'message' } catch { $e = $_ }

            $r = $e | ConvertTo-FailureLines

            $r.Message[0] | Should be 'RuntimeException: message'
            $r.Message.Count | Should be 1
        }
        It 'failed should produces correct message lines.' {
            try { 'One' | Should be 'Two' } catch { $e = $_ }
            $r = $e | ConvertTo-FailureLines

            $r.Message[0] | Should be 'String lengths are both 3. Strings differ at index 0.'
            $r.Message[1] | Should be 'Expected: {Two}'
            $r.Message[2] | Should be 'But was:  {One}'
            $r.Message[3] | Should be '-----------^'
            $r.Message[4] | Should match "'One' | Should be 'Two'"
            $r.Message.Count | Should be 5
        }
        Context 'should fails in file' {
            Set-Content -Path $testPath -Value @'
                $script:IgnoreErrorPreference = 'SilentlyContinue'
                'One' | Should be 'Two'
'@

            try { & $testPath } catch { $e = $_ }
            $r = $e | ConvertTo-FailureLines

            It 'produces correct message lines.' {


                $r.Message[0] | Should be 'String lengths are both 3. Strings differ at index 0.'
                $r.Message[1] | Should be 'Expected: {Two}'
                $r.Message[2] | Should be 'But was:  {One}'
                $r.Message[3] | Should be '-----------^'
                $r.Message[4] | Should be "2:                 'One' | Should be 'Two'"                $r.Message.Count | Should be 5
            }
            if ( $e | Get-Member -Name ScriptStackTrace )
            {
                It 'produces correct trace lines.' {
                    $r.Trace[0] | Should be "at <ScriptBlock>, $testPath`: line 2"
                    $r.Trace[1] -match 'at <ScriptBlock>, .*\\Functions\\PesterState.Tests.ps1: line [0-9]*$' |
                        Should be $true
                    $r.Trace.Count | Should be 2
                }
            }
            else
            {
                It 'produces correct trace lines.' {
                    $r.Trace[0] | Should be "at line: 2 in $testPath"
                    $r.Trace.Count | Should be 1
                }
            }
        }
        Context 'exception thrown in nested functions in file' {
            Set-Content -Path $testPath -Value @'
                function f1 {
                    throw 'f1 message'
                }
                function f2 {
                    f1
                }
                f2
'@

            try { & $testPath } catch { $e = $_ }

            $r = $e | ConvertTo-FailureLines

            It 'produces correct message lines.' {
                $r.Message[0] | Should be 'RuntimeException: f1 message'
            }
            if ( $e | Get-Member -Name ScriptStackTrace )
            {
                It 'produces correct trace lines.' {
                    $r.Trace[0] | Should be "at f1, $testPath`: line 2"
                    $r.Trace[1] | Should be "at f2, $testPath`: line 5"
                    $r.Trace[2] | Should be "at <ScriptBlock>, $testPath`: line 7"
                    $r.Trace[3] -match 'at <ScriptBlock>, .*\\Functions\\PesterState.Tests.ps1: line [0-9]*$' |
                        Should be $true
                    $r.Trace.Count | Should be 4
                }
            }
            else
            {
                It 'produces correct trace lines.' {
                    $r.Trace[0] | Should be "at line: 2 in $testPath"
                    $r.Trace.Count | Should be 1
                }
            }
        }
        Context 'nested exceptions thrown in file' {
            Set-Content -Path $testPath -Value @'
                try
                {
                    throw New-Object System.ArgumentException(
                        'inner message',
                        'param_name'
                    )
                }
                catch
                {
                    throw New-Object System.FormatException(
                        'outer message',
                        $_.Exception
                    )
                }
'@

            try { & $testPath } catch { $e = $_ }

            $r = $e | ConvertTo-FailureLines

            It 'produces correct message lines.' {
                $r.Message[0] | Should be 'ArgumentException: inner message'
                $r.Message[1] | Should be 'Parameter name: param_name'
                $r.Message[2] | Should be 'FormatException: outer message'
            }
            if ( $e | Get-Member -Name ScriptStackTrace )
            {
                It 'produces correct trace line.' {
                    $r.Trace[0] | Should be "at <ScriptBlock>, $testPath`: line 10"
                    $r.Trace[1] -match 'at <ScriptBlock>, .*\\Functions\\PesterState.Tests.ps1: line [0-9]*$'
                    $r.Trace.Count | Should be 2
                }
            }
            else
            {
                It 'produces correct trace line.' {
                    $r.Trace[0] | Should be "at line: 10 in $testPath"
                    $r.Trace.Count | Should be 1
                }
            }
        }
    }
}

# SIG # Begin signature block
# MIInSAYJKoZIhvcNAQcCoIInOTCCJzUCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCzVis637nmKLfu
# tBlmMuPbVllEbkewuwHWaKM6oNYSS6CCC7QwggXLMIIEs6ADAgECAhMzAAABQGf2
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
# GuowghrmAgEBMIGmMIGOMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMTgwNgYDVQQDEy9NaWNyb3NvZnQgV2luZG93cyBUaGlyZCBQYXJ0eSBDb21w
# b25lbnQgQ0EgMjAxMgITMwAAAUBn9phrMQi4cgAAAAABQDANBglghkgBZQMEAgEF
# AKCB+jAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAvBgkqhkiG9w0BCQQxIgQg
# InRqHKo44foeQeopz1shBwFDUlKjffYxokul9o552kIwUAYKKwYBBAGCNwoDHDFC
# DEA5MUMzOEYzQjRCNUIyNDM1RDE5RjY0RUY3MjhDN0IwNUYzRjBFMzA4RTBERUE3
# ODY4MDI4NDgzODQ3OUNENEM0MFoGCisGAQQBgjcCAQwxTDBKoCSAIgBNAGkAYwBy
# AG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0cDovL3d3dy5taWNyb3Nv
# ZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggGAhQ0RHHjwlzZJqZRcR4V5
# KS5+Y+nhK9tpzr8A8UxNsZOeTQeIiwFNIJMrXTlNJ9wtkM4W5K0tM2FwUQh6Kvc+
# 3g0aTOYo5smFXqO1o4H15O3YC2IgwlyBnUd3tToe3/cm8z4cqr15K5uPgaRUfFgk
# FppUiBUH543XAooa1MtwJ9NzZXobYkK4/LqgutUY+//Uc9gpYEqGDOWM2qQV3v/6
# RtfO/SNl96jifeOOb7ATw2rh0+V10Grc+3yjZ2FR+LdsyKKBfiMsaXTa3d77fiRa
# 1P4DhNdPCqVC013Zd8pfSg7R0J5SACgEmdbh6qvZWUKD0fqSOaq5+WSnKFsfqDgM
# whHQG9pGhq65C9IEqbXFYtrfr4jW7EDL/WrhnZD5TxPsAJI7k67F/ZLjMaqFFqRM
# 4b3EjCz80xcmKdsL0Okf0TaI9qhMAUvRQU8TzkiltIbMk2qhIbiBTDC+JQqZEeuE
# NMELbc36nG6sRn8oFbM5SXNHiBsTUmhkUVN3L3LkQrM9oYIXlzCCF5MGCisGAQQB
# gjcDAwExgheDMIIXfwYJKoZIhvcNAQcCoIIXcDCCF2wCAQMxDzANBglghkgBZQME
# AgEFADCCAVIGCyqGSIb3DQEJEAEEoIIBQQSCAT0wggE5AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIMCTbI4L3O65TtLT09XbE6cpSd+3eI0hZz/BRpfb
# ez+xAgZqqqeED1AYEzIwMjYxMDEwMDgzNjMzLjQzM1owBIACAfSggdGkgc4wgcsx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1p
# Y3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNT
# IEVTTjpFMDAyLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3Rh
# bXAgU2VydmljZaCCEe0wggcgMIIFCKADAgECAhMzAAACKQ7VZCq0l/IaAAEAAAIp
# MA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4X
# DTI2MDIxOTE5NDAwN1oXDTI3MDUxNzE5NDAwN1owgcsxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNh
# IE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjpFMDAyLTA1RTAt
# RDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCCAiIw
# DQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAJ4i0WrjPWgJhKZRmalgOxslYS77
# 7Vttz8zPs9rcjRlfkQ435aKsHQW+caXIVFTKXM7lMldl9TxAU85T3k/VjU5nwn6q
# 4Dkb4BZIE6v/jyxyXSz1EGmqBMyr+VvKoHPgIya9VHZB68CBWnhrWFuY6b0bthZ7
# Lrw3kXmtINhXTAyWDgjLxhG4WBE3Z4GlVe30i8VoWYGdAtl+jbYpncvw9YQdSFdT
# l0s5JmhN+qpD8H515bnoAIyeceM/Fm76zMeFkwtSsxZOCz0nsKfwO16VwqP1oz7R
# mru2RIMcKvCjp4JJ/DdyWS1dFGt2axxxqXxEIOI0UWBmzKnAXZoYAXqSDjX5CX62
# Femc4xQfiY8IAllanTMNajCwr9ijmMcvWlP8CBsvcWgDLhxuE4jg9vV5AUb6NPuy
# RLYX9v5kAJQDUQNnzfQr4G7TLD4WlIbLy2l3WzOTdxRiMinMgbjPegU2aJIk3xh0
# 13hIewRHkOSzlvGIpum+Z+s4Df2NNvsRbZNPvJJaAkhJ+9N7O4uZCxNVLM2y9qlW
# UeETbMGoPDjT2e862K0IVueGFc19q3Nvb4Z/a1fazpgFrXnUIL/z56Ym+96BdtY2
# 53Ni3xwVGibQ9n58lGGEF91KoKqvxB44YnxViWbEVerHVJ0NKRMJKCmyyQapnCH/
# q6YDWDgvvN4YE2eBAgMBAAGjggFJMIIBRTAdBgNVHQ4EFgQUJ01FpIv0BbxC9pDb
# VaNEBco3gzswHwYDVR0jBBgwFoAUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXwYDVR0f
# BFgwVjBUoFKgUIZOaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwv
# TWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3JsMGwGCCsG
# AQUFBwEBBGAwXjBcBggrBgEFBQcwAoZQaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAx
# MCgxKS5jcnQwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcNAQELBQADggIBAD3BzvaV/9zMOGnT1Pc8
# YAw5CHGX/HTiOkTu3f0V6pBKfZSnoNXOGDCfMKpjc0iEu1Rpat3s3G+uFkNxr4nj
# HO+tFA08d5FCmclV4ezJO7neBMGVQHVNEjo6dm38BWZH2gwn80E6oH535I5vw/Hr
# NGBHCTrawWQ6QHmWKD8MydgR5H9qZb0d2jy9dwqZpr8NtI4AdJ19kW36Koxl82WQ
# Q6fvX9EApM2/hCmr/YWFyMwyZKQiGyEF0FUHRWOaTAV+FVR/lNO4sn2wNHgTIK85
# kncHqDsjDpaNDHJyPCR/OxUxOl+6wnlLB04cvzIY9Zk54+PBrwhJdazqSJUr/pLT
# 8lVvUunGnJgpERCOdT/k55wq3Y5eUd3AVZmvACL3xE9lroQTFxv8sYt/XS00eO7V
# 5OWiFjSPM1lDQEOBK4xmAxT7wQSO0xAwgOeU8YRQ43ssdccfQovQUDTU8RZVkquv
# 8tQ664NM0XPDnjcU8yniCQIgWUp1G5yJHUhc6T5ex7quP20kViBWf7jgEei7ZdB7
# lFffR5/cBBZrSbHIYOonMaxXdfn5s1B4xXzyJa6Uk+rmyCcYb078fX8cfgew71ko
# Zf9asmlCYW5CtM5Hj1eO95oLTFoWYaw2D5GFu0PmpOSf4hIO/DQgn8T9Vc13P/Ja
# CiXqvnTuFPywAy6meGQXa7DUMIIHcTCCBVmgAwIBAgITMwAAABXF52ueAptJmQAA
# AAAAFTANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldh
# c2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUg
# QXV0aG9yaXR5IDIwMTAwHhcNMjEwOTMwMTgyMjI1WhcNMzAwOTMwMTgzMjI1WjB8
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1N
# aWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDCCAiIwDQYJKoZIhvcNAQEBBQAD
# ggIPADCCAgoCggIBAOThpkzntHIhC3miy9ckeb0O1YLT/e6cBwfSqWxOdcjKNVf2
# AX9sSuDivbk+F2Az/1xPx2b3lVNxWuJ+Slr+uDZnhUYjDLWNE893MsAQGOhgfWpS
# g0S3po5GawcU88V29YZQ3MFEyHFcUTE3oAo4bo3t1w/YJlN8OWECesSq/XJprx2r
# rPY2vjUmZNqYO7oaezOtgFt+jBAcnVL+tuhiJdxqD89d9P6OU8/W7IVWTe/dvI2k
# 45GPsjksUZzpcGkNyjYtcI4xyDUoveO0hyTD4MmPfrVUj9z6BVWYbWg7mka97aSu
# eik3rMvrg0XnRm7KMtXAhjBcTyziYrLNueKNiOSWrAFKu75xqRdbZ2De+JKRHh09
# /SDPc31BmkZ1zcRfNN0Sidb9pSB9fvzZnkXftnIv231fgLrbqn427DZM9ituqBJR
# 6L8FA6PRc6ZNN3SUHDSCD/AQ8rdHGO2n6Jl8P0zbr17C89XYcz1DTsEzOUyOArxC
# aC4Q6oRRRuLRvWoYWmEBc8pnol7XKHYC4jMYctenIPDC+hIK12NvDMk2ZItboKaD
# IV1fMHSRlJTYuVD5C4lh8zYGNRiER9vcG9H9stQcxWv2XFJRXRLbJbqvUAV6bMUR
# HXLvjflSxIUXk8A8FdsaN8cIFRg/eKtFtvUeh17aj54WcmnGrnu3tz5q4i6tAgMB
# AAGjggHdMIIB2TASBgkrBgEEAYI3FQEEBQIDAQABMCMGCSsGAQQBgjcVAgQWBBQq
# p1L+ZMSavoKRPEY1Kc8Q/y8E7jAdBgNVHQ4EFgQUn6cVXQBeYl2D9OXSZacbUzUZ
# 6XIwXAYDVR0gBFUwUzBRBgwrBgEEAYI3TIN9AQEwQTA/BggrBgEFBQcCARYzaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRt
# MBMGA1UdJQQMMAoGCCsGAQUFBwMIMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBB
# MAsGA1UdDwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFNX2VsuP
# 6KJcYmjRPZSQW9fOmhjEMFYGA1UdHwRPME0wS6BJoEeGRWh0dHA6Ly9jcmwubWlj
# cm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dF8yMDEwLTA2
# LTIzLmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYBBQUHMAKGPmh0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMu
# Y3J0MA0GCSqGSIb3DQEBCwUAA4ICAQCdVX38Kq3hLB9nATEkW+Geckv8qW/qXBS2
# Pk5HZHixBpOXPTEztTnXwnE2P9pkbHzQdTltuw8x5MKP+2zRoZQYIu7pZmc6U03d
# mLq2HnjYNi6cqYJWAAOwBb6J6Gngugnue99qb74py27YP0h1AdkY3m2CDPVtI1Tk
# eFN1JFe53Z/zjj3G82jfZfakVqr3lbYoVSfQJL1AoL8ZthISEV09J+BAljis9/kp
# icO8F7BUhUKz/AyeixmJ5/ALaoHCgRlCGVJ1ijbCHcNhcy4sa3tuPywJeBTpkbKp
# W99Jo3QMvOyRgNI95ko+ZjtPu4b6MhrZlvSP9pEB9s7GdP32THJvEKt1MMU0sHrY
# UP4KWN1APMdUbZ1jdEgssU5HLcEUBHG/ZPkkvnNtyo4JvbMBV0lUZNlz138eW0QB
# jloZkWsNn6Qo3GcZKCS6OEuabvshVGtqRRFHqfG3rsjoiV5PndLQTHa1V1QJsWkB
# RH58oWFsc/4Ku+xBZj1p/cvBQUl+fpO+y/g75LcVv7TOPqUxUYS8vwLBgqJ7Fx0V
# iY1w/ue10CgaiQuPNtq6TPmb/wrpNPgkNWcr4A245oyZ1uEi6vAnQj0llOZ0dFtq
# 0Z4+7X6gMTN9vMvpe784cETRkPHIqzqKOghif9lwY1NNje6CbaUFEMFxBmoQtB1V
# M1izoXBm8qGCA1AwggI4AgEBMIH5oYHRpIHOMIHLMQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBP
# cGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046RTAwMi0wNUUwLUQ5
# NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WiIwoBATAH
# BgUrDgMCGgMVALe/2JI7bbGhvtnE3l1cISr70i//oIGDMIGApH4wfDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgUENBIDIwMTAwDQYJKoZIhvcNAQELBQACBQDudB1QMCIYDzIw
# MjYxMDEwMDIxMTI4WhgPMjAyNjEwMTEwMjExMjhaMHcwPQYKKwYBBAGEWQoEATEv
# MC0wCgIFAO50HVACAQAwCgIBAAICI5wCAf8wBwIBAAICEoAwCgIFAO51btACAQAw
# NgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAKMAgCAQACAwehIKEKMAgC
# AQACAwGGoDANBgkqhkiG9w0BAQsFAAOCAQEA0dQW7gtj7hIQMewN/jCtB7UVgmsQ
# HiY7/Dsdl3M0ZvM+Qg+sAs5i2sjoTpr01RAKpgfjyxM7uWFn2RcjQ5cZ1BCEmH5p
# ZdfG6/8pklmm945kC9jVZb9M7Yr2bMM628YWQrtcovPEUeqqbx/K49ZPPXRo0KX/
# yiamHOtTsJLqTF5anRSG9qjxHKxku641EJtADdLLX4b7/mZ6Kzgr7X+IErcwWjXl
# UL14kBpk3JwWDlLzulBwZCW8/f6KWqGlcgcIhYwLdHMTJb87N5mrLHZKxAVm6MDq
# jMaX/EHaPh4kNX1uKR4EcZOso0WS47TlIyiAoHdcDXE+luOteGM/fvT7ODGCBA0w
# ggQJAgEBMIGTMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# JjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAACKQ7V
# ZCq0l/IaAAEAAAIpMA0GCWCGSAFlAwQCAQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYL
# KoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIEIEfxLnwxEkLrGepLlzMvyizwF+Xu
# Su1/2Avj0f5U13bqMIH6BgsqhkiG9w0BCRACLzGB6jCB5zCB5DCBvQQgt8o98SK2
# 8P+VK8S6bGo+SR44S2CSYoURUy56X2g6upIwgZgwgYCkfjB8MQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBQQ0EgMjAxMAITMwAAAikO1WQqtJfyGgABAAACKTAiBCCwDsIo7RPB
# nt/1nQnn3MrC4tP1m07GIcM6VahAYrhsmTANBgkqhkiG9w0BAQsFAASCAgB5i+xR
# WJo+DOwuA1hU3kDtu+NdJQdBjwMpbTPwup+MXNm5w/uF3b6TYbNXxfvkMRjOU7im
# 7FA08cikVNuY6IkF0jDSszg3XeXI1i3zfQqgT5CUXGTTnOSYnibNWY4KYMSAqNTu
# uxeDER3hUwSrIR1tIMhOtatEmyxgDVlczigGt9UxLVFkODyHaCE1mWDtvyytVh9k
# Pci6Avx0UEsmasek6RgLWfV80GgJRh+/g8/jFHYxPJnOi6d1wDOzz8NvfQwyYStE
# J2+/kd3o/3Dae7DBXxR58Eg5MSkcYCH8FZhY3ByQJ6jPFjWMlnyGDdcHG//yFqNE
# AnhN3L0AfLGINnXfz+PnrAZqcxvntDRlxRqhcz+Jx0GM+8YQYEYlmMS56NoT2Q4i
# Ovi3NYw0W18xXmDGTlJmjDWJfD6m9S00ietk+Sv30AgKihhXPYM/PZnTEvU5S3Pd
# ygfNqhaifQFkWcurWw4+AyQhp/xdROYoh0d1S8PnbtcUfx3xZBMGYcLxTYWUqfef
# q5zu+m05K2m2EUf5rvyEZA3ZSSh33xNhJ1uBETW+JVCt2Qi0EAd+ZSr96NAejZRM
# vnG8XMiACyOf+CZKnyNn/iPF3RZ5ttKgyT072AZer0HDuuP4fZAYkQ74Tn4uzqmH
# mJMzcuWVYOlxdDY99ygrxIxay884hdMgC3cDQA==
# SIG # End signature block
