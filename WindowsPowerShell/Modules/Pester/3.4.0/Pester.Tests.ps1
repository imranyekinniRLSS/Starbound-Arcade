$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$manifestPath   = "$here\Pester.psd1"
$changeLogPath = "$here\CHANGELOG.md"

# DO NOT CHANGE THIS TAG NAME; IT AFFECTS THE CI BUILD.

Describe -Tags 'VersionChecks' "Pester manifest and changelog" {
    $script:manifest = $null
    It "has a valid manifest" {
        {
            $script:manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop -WarningAction SilentlyContinue
        } | Should Not Throw
    }

    It "has a valid name in the manifest" {
        $script:manifest.Name | Should Be Pester
    }

    It "has a valid guid in the manifest" {
        $script:manifest.Guid | Should Be 'a699dea5-2c73-4616-a270-1f7abb777e71'
    }

    It "has a valid version in the manifest" {
        $script:manifest.Version -as [Version] | Should Not BeNullOrEmpty
    }

    $script:changelogVersion = $null
    It "has a valid version in the changelog" {

        foreach ($line in (Get-Content $changeLogPath))
        {
            if ($line -match "^\D*(?<Version>(\d+\.){1,3}\d+)")
            {
                $script:changelogVersion = $matches.Version
                break
            }
        }
        $script:changelogVersion                | Should Not BeNullOrEmpty
        $script:changelogVersion -as [Version]  | Should Not BeNullOrEmpty
    }

    It "changelog and manifest versions are the same" {
        $script:changelogVersion -as [Version] | Should be ( $script:manifest.Version -as [Version] )
    }

    if (Get-Command git.exe -ErrorAction SilentlyContinue) {
        $script:tagVersion = $null
        It "is tagged with a valid version" {
            $thisCommit = git.exe log --decorate --oneline HEAD~1..HEAD

            if ($thisCommit -match 'tag:\s*(\d+(?:\.\d+)*)')
            {
                $script:tagVersion = $matches[1]
            }

            $script:tagVersion                  | Should Not BeNullOrEmpty
            $script:tagVersion -as [Version]    | Should Not BeNullOrEmpty
        }

        It "all versions are the same" {
            $script:changelogVersion -as [Version] | Should be ( $script:manifest.Version -as [Version] )
            $script:manifest.Version -as [Version] | Should be ( $script:tagVersion -as [Version] )
        }

    }
}

if ($PSVersionTable.PSVersion.Major -ge 3)
{
    $error.Clear()
    Describe 'Clean treatment of the $error variable' {
        Context 'A Context' {
            It 'Performs a successful test' {
                $true | Should Be $true
            }
        }

        It 'Did not add anything to the $error variable' {
            $error.Count | Should Be 0
        }
    }

    InModuleScope Pester {
        Describe 'SafeCommands table' {
            $path = $ExecutionContext.SessionState.Module.ModuleBase
            $filesToCheck = Get-ChildItem -Path $path -Recurse -Include *.ps1,*.psm1 -Exclude *.Tests.ps1
            $callsToSafeCommands = @(
                foreach ($file in $files)
                {
                    $tokens = $parseErrors = $null
                    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref] $tokens, [ref] $parseErrors)
                    $filter = {
                        $args[0] -is [System.Management.Automation.Language.CommandAst] -and
                        $args[0].InvocationOperator -eq [System.Management.Automation.Language.TokenKind]::Ampersand -and
                        $args[0].CommandElements[0] -is [System.Management.Automation.Language.IndexExpressionAst] -and
                        $args[0].CommandElements[0].Target -is [System.Management.Automation.Language.VariableExpressionAst] -and
                        $args[0].CommandElements[0].Target.VariablePath.UserPath -match '^(?:script:)?SafeCommands$'
                    }

                    $ast.FindAll($filter, $true)
                }
            )

            $uniqueSafeCommands = $callsToSafeCommands | ForEach-Object { $_.CommandElements[0].Index.Value } | Select-Object -Unique

            $missingSafeCommands = $uniqueSafeCommands | Where-Object { -not $script:SafeCommands.ContainsKey($_) }

            It 'The SafeCommands table contains all commands that are called from the module' {
                $missingSafeCommands | Should Be $null
            }
        }
    }
}

Describe 'Style rules' {
    $pesterRoot = (Get-Module Pester).ModuleBase

    $files = @(
        Get-ChildItem $pesterRoot -Include *.ps1,*.psm1
        Get-ChildItem $pesterRoot\Functions -Include *.ps1,*.psm1 -Recurse
    )

    It 'Pester source files contain no trailing whitespace' {
        $badLines = @(
            foreach ($file in $files)
            {
                $lines = [System.IO.File]::ReadAllLines($file.FullName)
                $lineCount = $lines.Count

                for ($i = 0; $i -lt $lineCount; $i++)
                {
                    if ($lines[$i] -match '\s+$')
                    {
                        'File: {0}, Line: {1}' -f $file.FullName, ($i + 1)
                    }
                }
            }
        )

        if ($badLines.Count -gt 0)
        {
            throw "The following $($badLines.Count) lines contain trailing whitespace: `r`n`r`n$($badLines -join "`r`n")"
        }
    }

    It 'Pester Source Files all end with a newline' {
        $badFiles = @(
            foreach ($file in $files)
            {
                $string = [System.IO.File]::ReadAllText($file.FullName)
                if ($string.Length -gt 0 -and $string[-1] -ne "`n")
                {
                    $file.FullName
                }
            }
        )

        if ($badFiles.Count -gt 0)
        {
            throw "The following files do not end with a newline: `r`n`r`n$($badFiles -join "`r`n")"
        }
    }
}

InModuleScope Pester {
    Describe 'ResolveTestScripts' {
        Setup -File SomeFile.ps1
        Setup -File SomeFile.Tests.ps1
        Setup -File SomeOtherFile.ps1
        Setup -File SomeOtherFile.Tests.ps1

        It 'Resolves non-wildcarded file paths regardless of whether the file ends with Tests.ps1' {
            $result = @(ResolveTestScripts $TestDrive\SomeOtherFile.ps1)
            $result.Count | Should Be 1
            $result[0].Path | Should Be "$TestDrive\SomeOtherFile.ps1"
        }

        It 'Finds only *.Tests.ps1 files when the path contains wildcards' {
            $result = @(ResolveTestScripts $TestDrive\*.ps1)
            $result.Count | Should Be 2

            $paths = $result | Select-Object -ExpandProperty Path

            ($paths -contains "$TestDrive\SomeFile.Tests.ps1") | Should Be $true
            ($paths -contains "$TestDrive\SomeOtherFile.Tests.ps1") | Should Be $true
        }

        It 'Finds only *.Tests.ps1 files when the path refers to a directory and does not contain wildcards' {
            $result = @(ResolveTestScripts $TestDrive)

            $result.Count | Should Be 2

            $paths = $result | Select-Object -ExpandProperty Path

            ($paths -contains "$TestDrive\SomeFile.Tests.ps1") | Should Be $true
            ($paths -contains "$TestDrive\SomeOtherFile.Tests.ps1") | Should Be $true
        }

        It 'Assigns empty array and hashtable to the Arguments and Parameters properties when none are specified by the caller' {
            $result = @(ResolveTestScripts "$TestDrive\SomeFile.ps1")

            $result.Count | Should Be 1
            $result[0].Path | Should Be "$TestDrive\SomeFile.ps1"

            ,$result[0].Arguments | Should Not Be $null
            ,$result[0].Parameters | Should Not Be $null

            $result[0].Arguments.GetType() | Should Be ([object[]])
            $result[0].Arguments.Count | Should Be 0

            $result[0].Parameters.GetType() | Should Be ([hashtable])
            $result[0].Parameters.PSBase.Count | Should Be 0
        }

        Context 'Passing in Dictionaries instead of Strings' {
            It 'Allows the use of a "P" key instead of "Path"' {
                $result = @(ResolveTestScripts @{ P = "$TestDrive\SomeFile.ps1" })

                $result.Count | Should Be 1
                $result[0].Path | Should Be "$TestDrive\SomeFile.ps1"
            }

            $testArgs = @('I am a string')
            It 'Allows the use of an "Arguments" key in the dictionary' {
                $result = @(ResolveTestScripts @{ Path = "$TestDrive\SomeFile.ps1"; Arguments = $testArgs })

                $result.Count | Should Be 1
                $result[0].Path | Should Be "$TestDrive\SomeFile.ps1"

                $result[0].Arguments.Count | Should Be 1
                $result[0].Arguments[0] | Should Be 'I am a string'
            }

            It 'Allows the use of an "Args" key in the dictionary' {
                $result = @(ResolveTestScripts @{ Path = "$TestDrive\SomeFile.ps1"; Args = $testArgs })

                $result.Count | Should Be 1
                $result[0].Path | Should Be "$TestDrive\SomeFile.ps1"

                $result[0].Arguments.Count | Should Be 1
                $result[0].Arguments[0] | Should Be 'I am a string'
            }

            It 'Allows the use of an "A" key in the dictionary' {
                $result = @(ResolveTestScripts @{ Path = "$TestDrive\SomeFile.ps1"; A = $testArgs })

                $result.Count | Should Be 1
                $result[0].Path | Should Be "$TestDrive\SomeFile.ps1"

                $result[0].Arguments.Count | Should Be 1
                $result[0].Arguments[0] | Should Be 'I am a string'
            }

            $testParams = @{ MyKey = 'MyValue' }
            It 'Allows the use of a "Parameters" key in the dictionary' {
                $result = @(ResolveTestScripts @{ Path = "$TestDrive\SomeFile.ps1"; Parameters = $testParams })

                $result.Count | Should Be 1
                $result[0].Path | Should Be "$TestDrive\SomeFile.ps1"

                $result[0].Parameters.PSBase.Count | Should Be 1
                $result[0].Parameters['MyKey'] | Should Be 'MyValue'
            }

            It 'Allows the use of a "Params" key in the dictionary' {
                $result = @(ResolveTestScripts @{ Path = "$TestDrive\SomeFile.ps1"; Params = $testParams })

                $result.Count | Should Be 1
                $result[0].Path | Should Be "$TestDrive\SomeFile.ps1"

                $result[0].Parameters.PSBase.Count | Should Be 1
                $result[0].Parameters['MyKey'] | Should Be 'MyValue'
            }

            It 'Throws an error if no Path is specified' {
                { ResolveTestScripts @{} } | Should Throw
            }

            It 'Throws an error if a Parameters key is used, but does not contain an IDictionary object' {
                { ResolveTestScripts @{ P='P'; Params = 'A string' } } | Should Throw
            }
        }
    }
}

# SIG # Begin signature block
# MIInYQYJKoZIhvcNAQcCoIInUjCCJ04CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBfE/e7u3jI6yz7
# QBumibsiH2jWUPju+4aTP+s3pHx6C6CCC7QwggXLMIIEs6ADAgECAhMzAAABQGf2
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
# 94xukSE+y4BA4FzFksXXaGjRyjPUpkDE4RMJYruwNLIwUAYKKwYBBAGCNwoDHDFC
# DEA1REYzOEJFQ0NENkYzMjk3NTlCQTEwNDMwNzc2RTQ1NUJCQzczRTJCNTQ5MDYy
# MzY1RTBERDIyMkVDQzFGQzEyMFoGCisGAQQBgjcCAQwxTDBKoCSAIgBNAGkAYwBy
# AG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0cDovL3d3dy5taWNyb3Nv
# ZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggGAR3PGSl9Eb0IOd2fM/+yT
# u4mJD7GgOxESlMbOc8BowawC+UioX2QdV1egyrvn1lBRj5rEB8PvDeGARPAJwOCf
# XmJI/Zc3rZXoda2KIse1VrBuD/sHeufla8IjoaYai3fiLvI8VTsdOSb6Z86E3ofi
# WvAdZO2QGupirBuJYECyH10b4ZEnbKHzkEzgvIwTvMJAApEfXSYthAftofmjZJQt
# w9zK6vccieJiUoiND0rylBy4sUvGQjHXXY8tI/GAVbnm5HAw6VmBQ7N+dVUM0O+A
# HBjH5ZYGA00dpsjPotO+tI3P1vgJKVZ40GnzWIPNkh8wG3p0ulz6X29Ig6i38kc2
# UPYT0B/+5HbV83BmASNa11GiZj3Z8kMhf3Rpgc8PyG+d7tvfjDKM/Uo1pINBXnDN
# 4BRWd8cikM/bNNLCq9PtMRm77n5rs8N1FqDz/XroECbIhI4NdCY/CMsXAWyx7W6N
# hm3Z4z7apRUN16xgg9UmNezUB5NIb8V6hDAogVg6rZmLoYIXsDCCF6wGCisGAQQB
# gjcDAwExghecMIIXmAYJKoZIhvcNAQcCoIIXiTCCF4UCAQMxDzANBglghkgBZQME
# AgEFADCCAVoGCyqGSIb3DQEJEAEEoIIBSQSCAUUwggFBAgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIAS1ES7LujgLc0K16zeyWJqqAn07PTe+kwF09iql
# hKJHAgZqrW52WLwYEzIwMjYxMDEwMDgzNjM0LjYzNlowBIACAfSggdmkgdYwgdMx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1p
# Y3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEnMCUGA1UECxMeblNo
# aWVsZCBUU1MgRVNOOjM2MDUtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQg
# VGltZS1TdGFtcCBTZXJ2aWNloIIR/jCCBygwggUQoAMCAQICEzMAAAITsEM1Zs+v
# legAAQAAAhMwDQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENB
# IDIwMTAwHhcNMjUwODE0MTg0ODE3WhcNMjYxMTEzMTg0ODE3WjCB0zELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWljcm9zb2Z0
# IElyZWxhbmQgT3BlcmF0aW9ucyBMaW1pdGVkMScwJQYDVQQLEx5uU2hpZWxkIFRT
# UyBFU046MzYwNS0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQD0mXrg
# uhnEMg1IWDP70pLk7O/mbnjx49XNz1FdZ7hPj8ymV+Brh6rXZEZ2nlxW+eN17m/F
# +rZrH+Oe7u9Rbitk3iY5Sbm+H6RxixCVhDncXCAgHecSNxAeiasbeZl7+jOMVICv
# oluCUq0h4DJI/MBwXPIB6vmUs1QcES9AwzwE6MzJqkK+HTGyDjEoVxUQlAsoR8IY
# F98xkj9qa60cVvcJRNntpWkbYocQVQ2VnW/Awq/FdM9EOdvA8bPLKoknOd+ws0dD
# i9e3a21LU94KgYjSE3U96rzIawhcz2ihzALToMY1Iz/gsDHa4q/CZSfo3AtzT62a
# +fLrDbytkt6OyRF+dVah8S/WZZjSMdScevBIYFLyBU/2BwGzo/mDQ6kk8x/F1SQd
# dGRww89bSEg/w1tbxblK6nwe7CdIpuOnICUYFR0z9XmtlvSxmaSfvXivpQsYr5ws
# sA3pHcWFfo3SePrgXbstMrYFtLSkllpeOjR4M3PVBzF4gUtSAX5EGwtgOfwTxwKR
# 7Erw2W3caL3Ml/nnDpR9Nn6TBMzEyoXGHv5N/Hv5oE5tn6fH3rUC2KoDLvNVXr2j
# 8tZF0o9l29mf0RLIZtOc9+OQERG/bamtKUROVHDM/puYRU4pYtZXDG7CHttRZS5R
# vVyP3fO+21BgZBq3kT0Assk2aW8soKyQHutouwIDAQABo4IBSTCCAUUwHQYDVR0O
# BBYEFBOeEErH4WvKmFBYxGKkfj2wwUA6MB8GA1UdIwQYMBaAFJ+nFV0AXmJdg/Tl
# 0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly93d3cubWljcm9zb2Z0
# LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAy
# MDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYIKwYBBQUHMAKGUGh0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwVGltZS1T
# dGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/
# BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUAA4IC
# AQCCbFomsapDYPpQmFnpCXZJkU5o24ZtbcvMH4RL6XYEHUwm0FFIV2L+FVjfc2nG
# wlCFDlMtWnQNdg6Qig9BzXusf4hWF6Y7yMK35TojVMjDpxHtz60Sj8mOnoSoRTVz
# j+atoyOAeFD6toL85QCb3wDWvhsg8e2wGYtE4aZ4TlcsgVoEhlYe+HYI5chMo5td
# V3nAa0nV1ll3BocAJcXnTqO1r66hR3LMB642VM8tOtnyfKHEbCT1WHp6INDsJAxZ
# JJrwMlL09ReN6iL29N1Ltkxeq762/pDPfG2gEXn5gUri4T6aIaz3QXGbRUraVauY
# WGORGXnPKgc53Abuyk1iQOiYI81Yi51RCZBgqm38eyyl9xv7GmdYgNB0zOATymPW
# +nAuBYScfsu1Ph1kJ6gOj08rjRHEEPyQonvr2eCQTB/AIPYRf8xCTv14i86GmcfX
# Ya5UHK9opmTldm+q08403Cvyr+oDfzvsi5bBaCdp5f6munDR1n9Au1sYZWuA/5NF
# CO37Z1xkDk/dfgvAA2GI+zLQ6XhcJ2Ps7EEsW87OwI8M9pWeSn518MUb404GKvtq
# pMnrzrbanKaDVX7qBz/VG/EL/CC9jIbTfd5wmq/Q6fRlE1iv6L86TCADcc/VosPR
# oesSnDqW3TbreJGQK+tx1w5bzDeMLxMm5oZbILZL2MSPODCCB3EwggVZoAMCAQIC
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
# aWVsZCBUU1MgRVNOOjM2MDUtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQg
# VGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQCYETxIKPGCNpybLz9U
# R2Ts3GlHpqCBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0G
# CSqGSIb3DQEBCwUAAgUA7nRC2DAiGA8yMDI2MTAxMDA0NTEzNloYDzIwMjYxMDEx
# MDQ1MTM2WjB3MD0GCisGAQQBhFkKBAExLzAtMAoCBQDudELYAgEAMAoCAQACAh17
# AgH/MAcCAQACAhJRMAoCBQDudZRYAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisG
# AQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQAD
# ggEBAAk6Bjt5gzErhJRfq7c4Ud/scwiiIq0YWvZqmm9DC8tOqYJ+n9PxQtKk/st3
# D/OzOK7TbI7yYDQKRjX/NoFM5apt61a8uPuRNC0I5bczc1m6kV45ZyMbBsunN1Ue
# VSx7oet4IvfOQT2rEjciTkdPug/mMzYiV2rk7XE0wT6gr293qetHbGHddM5stEJn
# uxVVBElCVDpj4x8srgzq461o0/1lXYNoShdJ8aFmbQlpFdYo+QNmkkWv5g4WI0Yh
# L4GvDnz2vo8bG6NSC+Sts4+ASOmbqJ7wZtG4tOWbzeFFQiFWO8LnVFg4hEtVGi3v
# obiKhsxWZSJ5+0aasNqDIQma4YUxggQNMIIECQIBATCBkzB8MQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBQQ0EgMjAxMAITMwAAAhOwQzVmz6+V6AABAAACEzANBglghkgBZQME
# AgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJ
# BDEiBCB10/sljGhCdRcrxgRmfWhsz0Dim+Gm8X3tWFTM5G4unTCB+gYLKoZIhvcN
# AQkQAi8xgeowgecwgeQwgb0EIMzhCW0UhTPwngOMDM/idWh1m9DFgaV5Qh+nzo5r
# nFhoMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAIT
# sEM1Zs+vlegAAQAAAhMwIgQg6pWICIISnAsOeXzJVxfs8IqfscYXqPNNcybNi2G3
# 6xIwDQYJKoZIhvcNAQELBQAEggIAN/DYwRFVBmz0NSnV3RbTnFmfF0yx1pizCCDV
# AYBxAeCiAKm9XavNxiiycOC7jF4OJZT3BkDBALwJSEmRYFNHCp3oGvtVrifFg3pP
# KD4xVZq/78voCwYxQjVpizUqUsQON+hP9DvBUEWcwCI36EvVIlscSqF4RMus+Yrg
# ml745hi/asPRdEl6Gbg2u3NVMXqjDhzh/dVz64AFcD78m1EG+i4wEKFEApePX5op
# lLH+Gr0tH60R4Jc2iku4gq11BkvHswek0X8mmkVVAK0SmBYl9oyiTVshnaxSQJAb
# ig/vgDA7KN32aOLkKosi7sN9VqCBvgHSErMEIiguqdUFvGLaKIYiwr/+zYAkY7sg
# Wm0myXcvv9xnqts4Dp2/W/Tbkce/YvF66d7xA8DkoSacPzc0TrgJixuUr4EqFByf
# RMtu4Y6a2IF850sQof1+rvzek13Z0xFRQpbPJM2HRDNXJTLXrJqRFYYR2tpzKK8Y
# 1PaZKBR7AcGdOa0LxLuObMBZShtUOk14pvT4xOcDXWIj1hgbNNaXTlE31nRARwxx
# EKF5QaMUPf+yDWJ7j67VxeVSJDZK7Z7RIEBkWLeKd3dVAE0PobMhlR0iV9UE8S2i
# uMwM0ZgJCL4TmjHMP1srlaXu5gNWiK6Jjyp4repzo3jID7tE/d20mAwg+XsmTWLF
# YE7pvEU=
# SIG # End signature block
