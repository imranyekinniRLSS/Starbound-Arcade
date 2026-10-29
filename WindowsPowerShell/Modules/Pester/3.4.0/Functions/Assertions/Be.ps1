#Be
function PesterBe($value, $expected) {
    return ($expected -eq $value)
}

function PesterBeFailureMessage($value, $expected) {
    if (-not (($expected -is [string]) -and ($value -is [string])))
    {
        return "Expected: {$expected}`nBut was:  {$value}"
    }
    <#joining the output strings to a single string here, otherwise I get
       Cannot find an overload for "Exception" and the argument count: "4".
       at line: 63 in C:\Users\nohwnd\github\pester\Functions\Assertions\Should.ps1

    This is a quickwin solution, doing the join in the Should directly might be better
    way of doing this. But I don't want to mix two problems.
    #>
    ( Get-CompareStringMessage -Expected $expected -Actual $value ) -join "`n"
}

function NotPesterBeFailureMessage($value, $expected) {
    return "Expected: value was {$value}, but should not have been the same"
}

#BeExactly
function PesterBeExactly($value, $expected) {
    return ($expected -ceq $value)
}

function PesterBeExactlyFailureMessage($value, $expected) {
    if (-not (($expected -is [string]) -and ($value -is [string])))
    {
        return "Expected exactly: {$expected}`nBut was: {$value}"
    }
    <#joining the output strings to a single string here, otherwise I get
       Cannot find an overload for "Exception" and the argument count: "4".
       at line: 63 in C:\Users\nohwnd\github\pester\Functions\Assertions\Should.ps1

    This is a quickwin solution, doing the join in the Should directly might be better
    way of doing this. But I don't want to mix two problems.
    #>
    ( Get-CompareStringMessage -Expected $expected -Actual $value -CaseSensitive ) -join "`n"
}

function NotPesterBeExactlyFailureMessage($value, $expected) {
    return "Expected: value was {$value}, but should not have been exactly the same"
}

#common functions
function Get-CompareStringMessage {
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [String]$Expected,
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [String]$Actual,
        [switch]$CaseSensitive
    )

    $expectedLength = $expected.Length
    $actualLength = $actual.Length
    $maxLength = $expectedLength,$actualLength | & $SafeCommands['Sort-Object'] -Descending | & $SafeCommands['Select-Object'] -First 1

    $differenceIndex = $null
    for ($i = 0; $i -lt $maxLength -and ($null -eq $differenceIndex); ++$i){
        $differenceIndex = if ($CaseSensitive -and ($expected[$i] -cne $actual[$i]))
        {
            $i
        }
        elseif ($expected[$i] -ne $actual[$i])
        {
            $i
        }
    }

    [string]$output = $null
    if ($null -ne $differenceIndex)
    {
        if ($expected.Length -ne $actual.Length) {
           "Expected string length $expectedLength but was $actualLength. Strings differ at index $differenceIndex."
        }
        else
        {
           "String lengths are both $expectedLength. Strings differ at index $differenceIndex."
        }


        "Expected: {{{0}}}" -f ( $expected | Expand-SpecialCharacters )
        "But was:  {{{0}}}" -f ( $actual | Expand-SpecialCharacters )

        $specialCharacterOffset = $null
        if ($differenceIndex -ne 0)
        {
            #count all the special characters before the difference
            $specialCharacterOffset = ($actual[0..($differenceIndex-1)] |
                & $SafeCommands['Where-Object'] {"`n","`r","`t","`b","`0" -contains $_} |
                & $SafeCommands['Measure-Object'] |
                & $SafeCommands['Select-Object'] -ExpandProperty Count)
        }

        '-'*($differenceIndex+$specialCharacterOffset+11)+'^'
    }
}

function Expand-SpecialCharacters {
    param (
    [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
    [AllowEmptyString()]
    [string[]]$InputObject)
    process {
        $InputObject -replace "`n","\n" -replace "`r","\r" -replace "`t","\t" -replace "`0", "\0" -replace "`b","\b"
    }
}


# SIG # Begin signature block
# MIInSAYJKoZIhvcNAQcCoIInOTCCJzUCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDGTPpFnM9UACmG
# LTABB5DPnkbYtfFj5/7m5G0ol4ZteqCCC7QwggXLMIIEs6ADAgECAhMzAAABQGf2
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
# 2m1YMu/+w5kekSqlLEIzNzeQ1yYPnZKjJR8ecrVQJVkwUAYKKwYBBAGCNwoDHDFC
# DEA1Mzg0RjA5NzM2N0RGRTY0NEIyQjlENEM1MUJGNEMzQjY1RTg0NzQyOTdBM0U5
# QzgyRDlGM0IyNkY3RjdDNkM2MFoGCisGAQQBgjcCAQwxTDBKoCSAIgBNAGkAYwBy
# AG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0cDovL3d3dy5taWNyb3Nv
# ZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggGAmzKbsf59UDfIL2lStrD0
# URcSWgMn4Nm+jlXC8wy0I1DJsEPiss/6LE8tauU7AjgkpLHF8dmMFMtTBup7Tx0N
# PMCnGRyNZNprpzwcBL6xH2GRN0ifIXqU4PTyubiZnN2HRN6988gZDyqrRYsyxiq3
# p3dsTJHP0eny38YDb2Bar8KJLNKOGpPetBQrf9fAirAg1HUUILxQpxfi1jfnPJND
# I8nV2LxlZIttgdIt499Qaa5CMFD9oX2DG91T/Z1RXmPg6YY7PhBdN1V4t/dkCU3O
# SChzC0KgCrr+9S6wVcjTn6zxLi5PeliheLTPVkkMqXj3A2K/a6wpqH8X+5NNISmw
# gH6IOJX9JKsMarjveBQiggbsVYWJjsUmp8m/vuGd6w6+4LnoSWBpRV+no5+xILJc
# LTF/H9dJsVjGkoQQlFDRU2v36uu3E3biiALKJ0r18Kwbi8ykkzB8fNQzGsB0mx1O
# YYleRmspUgLMouU4RVptTIFscf4ev69QNrHGZ14SFjhBoYIXlzCCF5MGCisGAQQB
# gjcDAwExgheDMIIXfwYJKoZIhvcNAQcCoIIXcDCCF2wCAQMxDzANBglghkgBZQME
# AgEFADCCAVIGCyqGSIb3DQEJEAEEoIIBQQSCAT0wggE5AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIEn/bWGwChDhiCNYvsolY0s+3twKF4SGL9bn7i7O
# 2F5XAgZqqWrJ96wYEzIwMjYwOTE4MDQwMDE4Ljk4NFowBIACAfSggdGkgc4wgcsx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1p
# Y3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNT
# IEVTTjo5MjAwLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3Rh
# bXAgU2VydmljZaCCEe0wggcgMIIFCKADAgECAhMzAAACI0/ZYCRTz/4rAAEAAAIj
# MA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4X
# DTI2MDIxOTE5Mzk1N1oXDTI3MDUxNzE5Mzk1N1owgcsxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNh
# IE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo5MjAwLTA1RTAt
# RDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCCAiIw
# DQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAIrpDaeTlZR0rNIJJp+n5SNQBGxb
# EcpLresmEUL/NJpsW6ZMG5onRA2uap6+5vkNvt9KPmq3DAqeMg73b4dcXrvX3Z+6
# MvsMWi3lYSP8C0Rn9evMUeKYqU3WHqARDA/kjrvCLNo9blnNIE2losGDmge8BI85
# m3B01Shn4NAoXeEmXUpm6giVUr6qLtwuOBqTqzmg5lxEIysqe4LdqhVrrBENti8p
# S6PuuQXH0o7Q+wcn+T4udkyCBGF6HgBV1rDKH6g7Mo+OVAZQ19J5ZSDKbZT0Itry
# 23SZBfgPEPPr6tqbnSCPWgB/JDpNDuv3o8AMU4oGBpTv5ykedpkbz11N6BDrJ0FE
# YjJw7DV1FfZ4oNFHPOIrdyfRZoib/s54azJAqMjMRC5RMO/QmP/3NDu2u4s46kkP
# 3wElU4ruN7zhLPaFvce9RJPuPWPY3yl4PqiWSkUdH/VnwnPgX6aStQXsyY8CKtgd
# HO6dsiDcesMw3AVg3vIGQMDj9Uyj0JjTL2gZSirbKNsLBOJvP1ViX3ecHdBCJMJP
# 2dbcz5M5YH48ytmkTGrUFIeYo/Mip6EqqtQOgzfc8r50QrClgsRPq5erge5BExdZ
# P/+w+5tSdABppQx9CEBlLLbce3HC03d4r35PjAJq/bBAW3nt5Q7BRbn8MLMwX225
# rkd7WE2+BwBdqIbXAgMBAAGjggFJMIIBRTAdBgNVHQ4EFgQU1sCHz2/b2c9j1vBB
# vVBgLPFWB5cwHwYDVR0jBBgwFoAUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXwYDVR0f
# BFgwVjBUoFKgUIZOaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwv
# TWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3JsMGwGCCsG
# AQUFBwEBBGAwXjBcBggrBgEFBQcwAoZQaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAx
# MCgxKS5jcnQwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcNAQELBQADggIBAIdDB7vPm2ng1nAB/VwH
# 7hz0niy/Dc/paoYEzG2rOdLoN3NTNK1ccJo9mEzjWDWIoc2eZycuPAu6M4Ro2OFK
# dQOIBmpCNbllqk4HGBzsSCCGH2T6vvypYB7esnhCiEFuFIZ1m0qK9NFp5GqaeHLz
# 5OGsqHMJ4TBpqtcmKZnBKl1BBQNuF5Yd7IDEBKq6W13ko7Sb9QW87Te196moZcDi
# 0KD9YYQLAqo6MnOlEB88gHrLUfJWuT6+YvmukRtPDAs61ftbEUYbz5xguT0eNoOT
# GtoD8diUpBHHWx3Nr7D+C6UvCA6cHJEkoXauvwzsU0iXCiLrLAWlo1zwDsd7BoaO
# DD+19wTbrQjVd6QaW4A0j0ec405haUjsEoFBtYTa16jq+xDVWDwHytNlJ49V2Zcv
# U8+qqzcpV0UozmRihw8IMz7pUvfYhX3qwRJ/ZPsOPFqekKDYPZRiPhnWLtzLxTUs
# sMaDnkpazhp/ZFEGMfYy6UeACZbmhsrGJkINCNFqugnZcSVdSGKAT0HO+EIVtP8c
# Nja+lWmXkedKlwJLGYvmLmUhP/FsBAwjsu6Hvleub4iyV8VY4Y4YyUKn7bioQkSC
# VcQ/vHCyiU10E2d1eKGHIh59UaUjUNHvEYQuImuTyJ9VZij1cRsRe/+Vu+noXZHZ
# SyfB5ZyS+rTLUdacscOofp0+MIIHcTCCBVmgAwIBAgITMwAAABXF52ueAptJmQAA
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
# cGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046OTIwMC0wNUUwLUQ5
# NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WiIwoBATAH
# BgUrDgMCGgMVADhFYWz6ROJmehmICPUG1iPzMI1qoIGDMIGApH4wfDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgUENBIDIwMTAwDQYJKoZIhvcNAQELBQACBQDuVzScMCIYDzIw
# MjYwOTE4MDM1NTA4WhgPMjAyNjA5MTkwMzU1MDhaMHcwPQYKKwYBBAGEWQoEATEv
# MC0wCgIFAO5XNJwCAQAwCgIBAAICBSECAf8wBwIBAAICEmAwCgIFAO5YhhwCAQAw
# NgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAKMAgCAQACAwehIKEKMAgC
# AQACAwGGoDANBgkqhkiG9w0BAQsFAAOCAQEAb4K1ExFMnFLR7HlgWBrQwmLKdu+n
# +FyiwrF6Wa1Ftrziy6usshOHDNTuiCGijrFUTgWErP2HD/zcvQb+LF0REXA3mzQU
# 1ko8Uo54V/rPqHbKc5ig2CFnpDBze19LXsPnxfALA7op08Qx41Sl67lo2IAg9j7y
# taJO6QH/7mRuosuGXNmGSrlaAn6XscfKyYjdIdbyGBSmmMTwZN8haIjQUDIz4jSF
# 9mnXPGN4BaC0R43gKduo6zKDZFeMnpV/1FjwRgGSl8FRdddyEG45W/egwMXbdH++
# v9GmAuK1C20K8AwNhn4a5RuHT6PvFk0xaTqrEl8AI1G5VALxk6lMQxuwSzGCBA0w
# ggQJAgEBMIGTMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# JjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAACI0/Z
# YCRTz/4rAAEAAAIjMA0GCWCGSAFlAwQCAQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYL
# KoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIEIM13P9NWI0KSIDEtavO13cbFxsho
# P8Ediu6KOli6y7n1MIH6BgsqhkiG9w0BCRACLzGB6jCB5zCB5DCBvQQglvAzLBFu
# 9waLKeOfCMCpxoPjvJi95splEC+0QBHm7rMwgZgwgYCkfjB8MQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBQQ0EgMjAxMAITMwAAAiNP2WAkU8/+KwABAAACIzAiBCBPHFlnCt0s
# zFDBI8oNZe9uhB+PV+RFt7iz3Y+c1zR19jANBgkqhkiG9w0BAQsFAASCAgATNHmz
# WrpsTAqaBK3gHG6EqbyPgIe/fgaoZ0MGJl0fVOw4FLg73QDgj17v5oTP3MQ7tF0m
# KlORTfRzhUa1Vu53X8EHNhmQ7Cvavz/cR0Yw4SCwoXYLK2NvIg5imgda0V0D3SeX
# Hqn7kchNLHD2hrRHcI1S2nmeTjKWMsXrfSGFpsw3nzi681cPlndPF5bQY61c5CKS
# cINpbl4RSlc0aWNkEqcacrBkgGNH6G8EWUtlekRc/mV67e4wrqvFQ97Aqr6LOe/F
# qgnun/0/WVWSO44GHV2ZzluB01ATByM0Rin44HLdWQqYyAgwcdaPrUvMqFlwi7II
# 47PetBwcVcYmsmJneoSBAUYMnB8qff8/0jNSn2xfWMFh9KjHhN4hIjwadVjidW5G
# +M7JAB8Z6ngyTfENdW5iTqlpR4W+1xyo1cCXFRKX3Md9Ff6UvP+nzS3tT6j1IdU6
# LLdfcQ+kuMUk+tSBXmEZXC4Ir4nB59hnJVpmiPhTej2yA8EFpWI2zckz9uPO+5LZ
# NDY9ecA2HXlYyT3cU+B5iL0GkFwfRfjl30+u4/6aKcxOORH1LBuiScP1LH42rUFi
# ne7UsJf5kDLZoIlddON5LJOgQ/tCE6fy3v0c8DEW5+UJ64+tQCHk24N2ZyyRPJs3
# eSupGxWkjP1npnggcBqgTavf39ciwTF8rhjPSQ==
# SIG # End signature block
