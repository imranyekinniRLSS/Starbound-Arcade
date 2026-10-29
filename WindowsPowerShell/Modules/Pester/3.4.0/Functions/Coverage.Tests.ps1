if ($PSVersionTable.PSVersion.Major -le 2) { return }

InModuleScope Pester {
    Describe 'Code Coverage Analysis' {
        $root = (Get-PSDrive TestDrive).Root

        $null = New-Item -Path $root\TestScript.ps1 -ItemType File -ErrorAction SilentlyContinue

        Set-Content -Path $root\TestScript.ps1 -Value @'
            function FunctionOne
            {
                function NestedFunction
                {
                    'I am the nested function.'
                    'I get fully executed.'
                }

                if ($true)
                {
                    'I am functionOne'
                    NestedFunction
                }
            }

            function FunctionTwo
            {
                'I am function two.  I never get called.'
            }

            FunctionOne

'@

        Context 'Entire file' {
            $testState = New-PesterState -Path $root

            # Path deliberately duplicated to make sure the code doesn't produce multiple breakpoints for the same commands
            Enter-CoverageAnalysis -CodeCoverage "$root\TestScript.ps1", "$root\TestScript.ps1" -PesterState $testState

            It 'Has the proper number of breakpoints defined' {
                $testState.CommandCoverage.Count | Should Be 7
            }

            $null = & "$root\TestScript.ps1"
            $coverageReport = Get-CoverageReport -PesterState $testState

            It 'Reports the proper number of executed commands' {
                $coverageReport.NumberOfCommandsExecuted | Should Be 6
            }

            It 'Reports the proper number of analyzed commands' {
                $coverageReport.NumberOfCommandsAnalyzed | Should Be 7
            }

            It 'Reports the proper number of analyzed files' {
                $coverageReport.NumberOfFilesAnalyzed | Should Be 1
            }

            It 'Reports the proper number of missed commands' {
                $coverageReport.MissedCommands.Count | Should Be 1
            }

            It 'Reports the correct missed command' {
                $coverageReport.MissedCommands[0].Command | Should Be "'I am function two.  I never get called.'"
            }

            It 'Reports the proper number of hit commands' {
                $coverageReport.HitCommands.Count | Should Be 6
            }

            It 'Reports the correct hit command' {
                $coverageReport.HitCommands[0].Command | Should Be "'I am the nested function.'"
            }

            Exit-CoverageAnalysis -PesterState $testState
        }

        Context 'Single function with missed commands' {
            $testState = New-PesterState -Path $root

            Enter-CoverageAnalysis -CodeCoverage @{Path = "$root\TestScript.ps1"; Function = 'FunctionTwo'} -PesterState $testState

            It 'Has the proper number of breakpoints defined' {
                $testState.CommandCoverage.Count | Should Be 1
            }

            $null = & "$root\TestScript.ps1"
            $coverageReport = Get-CoverageReport -PesterState $testState

            It 'Reports the proper number of executed commands' {
                $coverageReport.NumberOfCommandsExecuted | Should Be 0
            }

            It 'Reports the proper number of analyzed commands' {
                $coverageReport.NumberOfCommandsAnalyzed | Should Be 1
            }

            It 'Reports the proper number of missed commands' {
                $coverageReport.MissedCommands.Count | Should Be 1
            }

            It 'Reports the correct missed command' {
                $coverageReport.MissedCommands[0].Command | Should Be "'I am function two.  I never get called.'"
            }

            It 'Reports the proper number of hit commands' {
                $coverageReport.HitCommands.Count | Should Be 0
            }

            Exit-CoverageAnalysis -PesterState $testState
        }

        Context 'Single function with no missed commands' {
            $testState = New-PesterState -Path $root

            Enter-CoverageAnalysis -CodeCoverage @{Path = "$root\TestScript.ps1"; Function = 'FunctionOne'} -PesterState $testState

            It 'Has the proper number of breakpoints defined' {
                $testState.CommandCoverage.Count | Should Be 5
            }

            $null = & "$root\TestScript.ps1"
            $coverageReport = Get-CoverageReport -PesterState $testState

            It 'Reports the proper number of executed commands' {
                $coverageReport.NumberOfCommandsExecuted | Should Be 5
            }

            It 'Reports the proper number of analyzed commands' {
                $coverageReport.NumberOfCommandsAnalyzed | Should Be 5
            }

            It 'Reports the proper number of missed commands' {
                $coverageReport.MissedCommands.Count | Should Be 0
            }

            It 'Reports the proper number of hit commands' {
                $coverageReport.HitCommands.Count | Should Be 5
            }

            It 'Reports the correct hit command' {
                $coverageReport.HitCommands[0].Command | Should Be "'I am the nested function.'"
            }

            Exit-CoverageAnalysis -PesterState $testState
        }

        Context 'Range of lines' {
            $testState = New-PesterState -Path $root

            Enter-CoverageAnalysis -CodeCoverage @{Path = "$root\TestScript.ps1"; StartLine = 11; EndLine = 12 } -PesterState $testState

            It 'Has the proper number of breakpoints defined' {
                $testState.CommandCoverage.Count | Should Be 2
            }

            $null = & "$root\TestScript.ps1"
            $coverageReport = Get-CoverageReport -PesterState $testState

            It 'Reports the proper number of executed commands' {
                $coverageReport.NumberOfCommandsExecuted | Should Be 2
            }

            It 'Reports the proper number of analyzed commands' {
                $coverageReport.NumberOfCommandsAnalyzed | Should Be 2
            }

            It 'Reports the proper number of missed commands' {
                $coverageReport.MissedCommands.Count | Should Be 0
            }

            It 'Reports the proper number of hit commands' {
                $coverageReport.HitCommands.Count | Should Be 2
            }

            It 'Reports the correct hit command' {
                $coverageReport.HitCommands[0].Command | Should Be "'I am functionOne'"
            }

            Exit-CoverageAnalysis -PesterState $testState
        }

        Context 'Wildcard resolution' {
            $testState = New-PesterState -Path $root

            Enter-CoverageAnalysis -CodeCoverage @{Path = "$root\*.ps1"; Function = '*' } -PesterState $testState

            It 'Has the proper number of breakpoints defined' {
                $testState.CommandCoverage.Count | Should Be 6
            }

            $null = & "$root\TestScript.ps1"
            $coverageReport = Get-CoverageReport -PesterState $testState

            It 'Reports the proper number of executed commands' {
                $coverageReport.NumberOfCommandsExecuted | Should Be 5
            }

            It 'Reports the proper number of analyzed commands' {
                $coverageReport.NumberOfCommandsAnalyzed | Should Be 6
            }

            It 'Reports the proper number of analyzed files' {
                $coverageReport.NumberOfFilesAnalyzed | Should Be 1
            }

            It 'Reports the proper number of missed commands' {
                $coverageReport.MissedCommands.Count | Should Be 1
            }

            It 'Reports the correct missed command' {
                $coverageReport.MissedCommands[0].Command | Should Be "'I am function two.  I never get called.'"
            }

            It 'Reports the proper number of hit commands' {
                $coverageReport.HitCommands.Count | Should Be 5
            }

            It 'Reports the correct hit command' {
                $coverageReport.HitCommands[0].Command | Should Be "'I am the nested function.'"
            }

            Exit-CoverageAnalysis -PesterState $testState
        }
    }

    Describe 'Stripping common parent paths' {
        $paths = @(
            'C:\Common\Folder\UniqueSubfolder1\File.ps1'
            'C:\Common\Folder\UniqueSubfolder2\File2.ps1'
            'C:\Common\Folder\UniqueSubfolder3\File3.ps1'
        )

        $commonPath = Get-CommonParentPath -Path $paths

        It 'Identifies the correct parent path' {
            $commonPath | Should Be 'C:\Common\Folder'
        }

        It 'Strips the common path correctly' {
            Get-RelativePath -Path $paths[0] -RelativeTo $commonPath |
            Should Be 'UniqueSubfolder1\File.ps1'
        }
    }

    if ((Get-Module -ListAvailable PSDesiredStateConfiguration) -and $PSVersionTable.PSVersion.Major -ge 4)
    {
        Describe 'Analyzing coverage of a DSC configuration' {
            $root = (Get-PSDrive TestDrive).Root

            $null = New-Item -Path $root\TestScriptWithConfiguration.ps1 -ItemType File -ErrorAction SilentlyContinue

            Set-Content -Path $root\TestScriptWithConfiguration.ps1 -Value @'
                $line1 = $true   # Triggers breakpoint
                $line2 = $true   # Triggers breakpoint

                configuration MyTestConfig   # does NOT trigger breakpoint
                {
                    Node localhost    # Triggers breakpoint
                    {
                        WindowsFeature XPSViewer   # Triggers breakpoint
                        {
                            Name = 'XPS-Viewer'  # does NOT trigger breakpoint
                            Ensure = 'Present'   # does NOT trigger breakpoint
                        }
                    }

                    return # does NOT trigger breakpoint

                    $doesNotExecute = $true   # Triggers breakpoint
                }

                $line3 = $true   # Triggers breakpoint

                return   # does NOT trigger breakpoint

                $doesnotexecute = $true   # Triggers breakpoint
'@

            $testState = New-PesterState -Path $root

            Enter-CoverageAnalysis -CodeCoverage "$root\TestScriptWithConfiguration.ps1" -PesterState $testState

            It 'Has the proper number of breakpoints defined' {
                $testState.CommandCoverage.Count | Should Be 7
            }

            $null = . "$root\TestScriptWithConfiguration.ps1"

            $coverageReport = Get-CoverageReport -PesterState $testState
            It 'Reports the proper number of missed commands before running the configuration' {
                $coverageReport.MissedCommands.Count | Should Be 4
            }

            MyTestConfig -OutputPath $root

            $coverageReport = Get-CoverageReport -PesterState $testState
            It 'Reports the proper number of missed commands after running the configuration' {
                $coverageReport.MissedCommands.Count | Should Be 2
            }

            Exit-CoverageAnalysis -PesterState $testState
        }
    }
}

# SIG # Begin signature block
# MIInYQYJKoZIhvcNAQcCoIInUjCCJ04CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA+NSWJ517aiUrV
# KJxHqsXAXCXEXlAqDflUM+iV0N1usqCCC7QwggXLMIIEs6ADAgECAhMzAAABQGf2
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
# xmqCniEWEwVxlO00QxphZuEdjaOVInvr4ykiT0r/JaIwUAYKKwYBBAGCNwoDHDFC
# DEBEMEY0QzNEMEQxN0I0OUIxQkQ2NDAzQ0U0MzAxQzgyMTkwRjFGMDQ0MkU1NDY1
# MDM0RDZCRjU3MEFCQzdDN0E2MFoGCisGAQQBgjcCAQwxTDBKoCSAIgBNAGkAYwBy
# AG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0cDovL3d3dy5taWNyb3Nv
# ZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggGAKu5ETEcsjwjj1m3FIqDq
# FYUpZoyvFtOeHt3ZxSjw+scJR2MUP1NG2oHaKoMobDmgxFNOVcJk8SbXLk3SfLmL
# sz7dovmSF+7GnoGjlBXtAYSZ0ZljbBy3tvu86KcyY+hZeQ0MaPOmEPJP3g6rLHiY
# Twdwxs66rn3TUwo0MnxMRjf/a7GKORSCWE04tUa+tTzdvJkG0IE13f80EKdeNqTI
# c4/9ZmGdI8Zem89DUzAttNXZ0iIqVHCp9zSpxefE/+CuUcQcKLZPRYi7SbeKxJo9
# Op67mtd34kfkD9GNR1kmUR8PyU7ZqJbrcQuxXFUheYR+kSWyNOBVTiuPhwHIlQXJ
# u+aLYtzYXpBm86o/WuNNXdnC8p7YZrUAa7Sa9ZVm6I4LvCRvoMDE8VgnFwsnhRwe
# Y0IVk4W/wl7j/kXGA1J8ydcLybLp0hIK44drAkRFMbEsxDQ8Mbl519QC/6lBKTny
# cwat9vC76nc78hoBZjJTy2O/InGy5rkHplMpxbNMsbocoYIXsDCCF6wGCisGAQQB
# gjcDAwExghecMIIXmAYJKoZIhvcNAQcCoIIXiTCCF4UCAQMxDzANBglghkgBZQME
# AgEFADCCAVoGCyqGSIb3DQEJEAEEoIIBSQSCAUUwggFBAgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIL283NPruXyZmfPTUZQfiqamBv7b9t3CAoRs2J/o
# XxeuAgZqr3DBTA4YEzIwMjYxMDEwMDgzNjM0Ljg0M1owBIACAfSggdmkgdYwgdMx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1p
# Y3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEnMCUGA1UECxMeblNo
# aWVsZCBUU1MgRVNOOjZGMUEtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQg
# VGltZS1TdGFtcCBTZXJ2aWNloIIR/jCCBygwggUQoAMCAQICEzMAAAIcCVUV18NZ
# B9EAAQAAAhwwDQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENB
# IDIwMTAwHhcNMjUwODE0MTg0ODMxWhcNMjYxMTEzMTg0ODMxWjCB0zELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWljcm9zb2Z0
# IElyZWxhbmQgT3BlcmF0aW9ucyBMaW1pdGVkMScwJQYDVQQLEx5uU2hpZWxkIFRT
# UyBFU046NkYxQS0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCjDTEQ
# BRoUjLIshd4XN4jwgrIE43a7QOvTYhITmn0bkJRd+cW7ZLQTWBYIy8NamilfqVHG
# OaCepovcG2daUFVOjzFQ1Fm7beJ7hgEwAkHtS3qaeqcdXC8MnEY7hMPdKesJ37KD
# fkH1AV6Orejj44HK9ePKdrKlnK6RxBouwpC+jETwSUcfvNw5cQlaZTeudfNpb9Lh
# Ifc4+GhRtNNzLqdSArHmlFaJDbhQQ8tjNzEYmOqOTP4aIJYY8UcMx1bzqVpa+YKy
# Wi5A+w3Z4GTx3ElwRmZbiXqnhO2Ghdx97EQD1h1hozPXRoyFk2l2w1oO0NBQwMQL
# eTUPUzLr0xdI+VSYP3EXIOWReJVrsEISnddxW2pODMcbCvbwkPqgTvMQ9h65k6K4
# IFdNlKj/CTe1sOWwRJsg9XqKdiqvPGIxiqXF8J3MLcKKaH381P8uT39pT4jLJz1v
# c5pPR1nzCAtpUMIYQtEyurIiZ0Ue/Qy51y3Nb+Q+xXclr25+kpa6MSI3cJb/9fyE
# Vr2PkiY15DNwyK3cyhJqgbCduJklfUjKJsimGWpxxcWTihNNI5AGwBTDxTSDA6cz
# lQkPyYFQF3rk2no0GTHZy+IngjfgbJcUJbLLkW3VCwFjJV8Abco6EJ88dB/yVDMm
# 8uvnthbRsP/FWzgCDiBNLopk3IUR9f2MV1GWvQIDAQABo4IBSTCCAUUwHQYDVR0O
# BBYEFFreY4LMHy7vOm8OHwwYpVgsKTtkMB8GA1UdIwQYMBaAFJ+nFV0AXmJdg/Tl
# 0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly93d3cubWljcm9zb2Z0
# LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAy
# MDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYIKwYBBQUHMAKGUGh0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwVGltZS1T
# dGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/
# BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUAA4IC
# AQCSVvrD915qJ3cG6NAK1YUF7Sf2mTJHL7LJYSDvSIPCgnm7R7Q77gZ6s3N1lvXN
# M+wcnwQYzKjUrvK0vbX6mZ0UxOXX08Lw4nljan5cpRDLZ0P6GCBEyYmANCyBs4LE
# dh476ODi36+DrXBSui/PMuQffPQ8lde+g24GP0t1r0KI0x3rTjnUq5t730CtJ/pk
# yPe3SnisVuBJrMOz7xMn7woDkZVpiM8eP2uUy4jdaOiERz1qmdDqEyMxyTeOUdkj
# CW5Vh5RATSqOYCl8y1MATNsxR1jywtO6cvUaRsNJ4qf07uWUEac23IzW4z0x2/VX
# JaHTP8iuJAoiOe2qobKgXQe8Mc4VkLJQME8t+XKK7tjXND+w+i6exv3poF9B2reH
# cs6fq36b0Sc3P8bozPNa+kmTpiBMdMip5A38X9emI+9t96Teer89hsvdq76QF9FQ
# eIIVdK+3qWivQcLrbq9SbP1k087HARYu5xyibGzLcnBYfv2+wz/sBGqgbmHp3o1q
# F9o65E/hcj3G10fc9r80IvJCPEpfIvHPBDON12RfYSlMmeXKm6E+YR15rn1TPYTf
# TcvHJdKcoG8awCfJZgB+d6OvdgCIv1is3aXZ2fX3xGkDgMKb1C1liLALSrZ+5S+6
# Lfg988hRkHJ/vAe65a7nSFj1YvHWQ4wjzHKjsAjpNo2ucjCCB3EwggVZoAMCAQIC
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
# aWVsZCBUU1MgRVNOOjZGMUEtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQg
# VGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQBaZOIDTW7mbGr+dXGJ
# Eksw6yRUZ6CBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0G
# CSqGSIb3DQEBCwUAAgUA7nRK5zAiGA8yMDI2MTAxMDA1MjU1OVoYDzIwMjYxMDEx
# MDUyNTU5WjB3MD0GCisGAQQBhFkKBAExLzAtMAoCBQDudErnAgEAMAoCAQACAgxJ
# AgH/MAcCAQACAhLKMAoCBQDudZxnAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisG
# AQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQAD
# ggEBAFWFnF9+DmT5qKzsmhpCm5xu6QdoS0WMtl1kDRPn0lVYj4Pvq8/AK7Gsf6Y9
# /pNVlJTNMceUTYdvQUmvda5eI5TwWeZvV7QpRK73pYgvzSQddNTYa7Y2sZe/859S
# /HDu/Gq1QAkLa4AxHz8QINaxipOh19gIE5fqKYacY6ORk+Zzp7EreEcOw4dZgzFN
# jBBmKd0OVrmL7Vk8l1w7N09NIH7mFXOaqHmN6cWbReyo9rM+aUKW0EPp6G4amFe2
# x2xeI2w5qF+F0uRWgnphPIUpWerRKSxWxoOVA/u6IACCsV//w/N9YN6Ugp4ExcjD
# 0MjuCP58df7d1VUTszgjaDtSTnYxggQNMIIECQIBATCBkzB8MQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBQQ0EgMjAxMAITMwAAAhwJVRXXw1kH0QABAAACHDANBglghkgBZQME
# AgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJ
# BDEiBCCOH9w1y8HiwhgvT3Bofity/835R3dF37lFKFNuwejB9jCB+gYLKoZIhvcN
# AQkQAi8xgeowgecwgeQwgb0EIKAgaSY2F2jv4oTt1aEj4TYK3HZEtahi+8mh0Ihy
# IcdoMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAIc
# CVUV18NZB9EAAQAAAhwwIgQgzlEHXxPdnKKtU6lQIJZYivKqi8sOr+n/iCUJ8Ybg
# llIwDQYJKoZIhvcNAQELBQAEggIATCj0VeJPFf+tMrCYS34bJAma9FhCrYbCUU8d
# ti3lo98LBpXtcf4erOZhGP+rUoFfmsGt+29fCt/zfiinkMSe0LH9DFG2aaqS7K5n
# SEXgwI4zpIjL50T0iHca2sldXQMdGMYTrCSmkAsJkWYupFT317gMqpheZCRP5htF
# 2aYv3PRWGg4UPF6x9O46HSNqO93bg4P2U1dEbEriaVyxnC7ctBEk7JZFKcf4ljgF
# lsqI3oj2nQrUSAyV0oTI4d2zAGmuAISkPcqaENwSOF0utESl2vwlE4zVSf+4TPMq
# XTahdKlPjSasvlYi1VEX2iqACQS0uCdQ122YxP3/xvAK4/cB5tKgMZ4VGjHv0Tc0
# L72dpR/WKG7A3+9ZCrmHlo+/j5C63NV/0SFVq/TCgZJU+c7080zqh3sc8NcfrB2I
# E0ZpjKUdiyVs9IvPdMsPA8sQezqmFlU91/DfSgcWPEa0QGyS3GxYziWpx7Vyi7Ky
# iru8YXHklvFdLcMez8hyTXPBJdxOl5gw26thhcDsiI+fee19piOtdDYDySXZSZTX
# d7EsnWeBxa88tLeS9NX8fzBBAWtDJJFQL3u6ePKe3vRDIV8cn+wqZrQyQefGBmVr
# CLTq5KLSqgT3++UYdKprIj8UIulJDJ0QqOIwybkwGw1DzAZ52+DMs4SqMkQUJ6D3
# zXsK0T4=
# SIG # End signature block
