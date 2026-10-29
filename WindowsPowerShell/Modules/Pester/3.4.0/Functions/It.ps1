function It {
<#
.SYNOPSIS
Validates the results of a test inside of a Describe block.

.DESCRIPTION
The It command is intended to be used inside of a Describe or Context Block.
If you are familiar with the AAA pattern (Arrange-Act-Assert), the body of
the It block is the appropriate location for an assert. The convention is to
assert a single expectation for each It block. The code inside of the It block
should throw a terminating error if the expectation of the test is not met and
thus cause the test to fail. The name of the It block should expressively state
the expectation of the test.

In addition to using your own logic to test expectations and throw exceptions,
you may also use Pester's Should command to perform assertions in plain language.

.PARAMETER Name
An expressive phsae describing the expected test outcome.

.PARAMETER Test
The script block that should throw an exception if the
expectation of the test is not met.If you are following the
AAA pattern (Arrange-Act-Assert), this typically holds the
Assert.

.PARAMETER Pending
Use this parameter to explicitly mark the test as work-in-progress/not implemented/pending when you
need to distinguish a test that fails because it is not finished yet from a tests
that fail as a result of changes being made in the code base. An empty test, that is a
test that contains nothing except whitespace or comments is marked as Pending by default.

.PARAMETER Skip
Use this parameter to explicitly mark the test to be skipped. This is preferable to temporarily
commenting out a test, because the test remains listed in the output. Use the Strict parameter
of Invoke-Pester to force all skipped tests to fail.

.PARAMETER TestCases
Optional array of hashtable (or any IDictionary) objects.  If this parameter is used,
Pester will call the test script block once for each table in the TestCases array,
splatting the dictionary to the test script block as input.  If you want the name of
the test to appear differently for each test case, you can embed tokens into the Name
parameter with the syntax 'Adds numbers <A> and <B>' (assuming you have keys named A and B
in your TestCases hashtables.)

.EXAMPLE
function Add-Numbers($a, $b) {
    return $a + $b
}

Describe "Add-Numbers" {
    It "adds positive numbers" {
        $sum = Add-Numbers 2 3
        $sum | Should Be 5
    }

    It "adds negative numbers" {
        $sum = Add-Numbers (-2) (-2)
        $sum | Should Be (-4)
    }

    It "adds one negative number to positive number" {
        $sum = Add-Numbers (-2) 2
        $sum | Should Be 0
    }

    It "concatenates strings if given strings" {
        $sum = Add-Numbers two three
        $sum | Should Be "twothree"
    }
}

.EXAMPLE
function Add-Numbers($a, $b) {
    return $a + $b
}

Describe "Add-Numbers" {
    $testCases = @(
        @{ a = 2;     b = 3;       expectedResult = 5 }
        @{ a = -2;    b = -2;      expectedResult = -4 }
        @{ a = -2;    b = 2;       expectedResult = 0 }
        @{ a = 'two'; b = 'three'; expectedResult = 'twothree' }
    )

    It 'Correctly adds <a> and <b> to get <expectedResult>' -TestCases $testCases {
        param ($a, $b, $expectedResult)

        $sum = Add-Numbers $a $b
        $sum | Should Be $expectedResult
    }
}

.LINK
Describe
Context
about_should
#>
    [CmdletBinding(DefaultParameterSetName = 'Normal')]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$name,

        [Parameter(Position = 1)]
        [ScriptBlock] $test = {},

        [System.Collections.IDictionary[]] $TestCases,

        [Parameter(ParameterSetName = 'Pending')]
        [Switch] $Pending,

        [Parameter(ParameterSetName = 'Skip')]
        [Alias('Ignore')]
        [Switch] $Skip
    )

    ItImpl -Pester $pester -OutputScriptBlock ${function:Write-PesterResult} @PSBoundParameters
}

function ItImpl
{
    [CmdletBinding(DefaultParameterSetName = 'Normal')]
    param(
        [Parameter(Mandatory = $true, Position=0)]
        [string]$name,
        [Parameter(Position = 1)]
        [ScriptBlock] $test,
        [System.Collections.IDictionary[]] $TestCases,
        [Parameter(ParameterSetName = 'Pending')]
        [Switch] $Pending,

        [Parameter(ParameterSetName = 'Skip')]
        [Alias('Ignore')]
        [Switch] $Skip,

        $Pester,
        [scriptblock] $OutputScriptBlock
    )

    Assert-DescribeInProgress -CommandName It

    # Jumping through hoops to make strict mode happy.
    if ($PSCmdlet.ParameterSetName -ne 'Skip') { $Skip = $false }
    if ($PSCmdlet.ParameterSetName -ne 'Pending') { $Pending = $false }

    #unless Skip or Pending is specified you must specify a ScriptBlock to the Test parameter
    if (-not ($PSBoundParameters.ContainsKey('test') -or $Skip -or $Pending))
    {
        throw 'No test script block is provided. (Have you put the open curly brace on the next line?)'
    }

    #the function is called with Pending or Skipped set the script block if needed
    if ($null -eq $test) { $test = {} }

    #mark empty Its as Pending
    #[String]::IsNullOrWhitespace is not available in .NET version used with PowerShell 2
    if ($PSCmdlet.ParameterSetName -eq 'Normal' -and
       [String]::IsNullOrEmpty((Remove-Comments $test.ToString()) -replace "\s"))
    {
        $Pending = $true
    }

    $pendingSkip = @{}

    if ($PSCmdlet.ParameterSetName -eq 'Skip')
    {
        $pendingSkip['Skip'] = $Skip
    }
    else
    {
        $pendingSkip['Pending'] = $Pending
    }

    if ($null -ne $TestCases -and $TestCases.Count -gt 0)
    {
        foreach ($testCase in $TestCases)
        {
            $expandedName = [regex]::Replace($name, '<([^>]+)>', {
                $capture = $args[0].Groups[1].Value
                if ($testCase.Contains($capture))
                {
                    $testCase[$capture]
                }
                else
                {
                    "<$capture>"
                }
            })

            $splat = @{
                Name = $expandedName
                Scriptblock = $test
                Parameters = $testCase
                ParameterizedSuiteName = $name
                OutputScriptBlock = $OutputScriptBlock
            }

            Invoke-Test @splat @pendingSkip
        }
    }
    else
    {
        Invoke-Test -Name $name -ScriptBlock $test @pendingSkip -OutputScriptBlock $OutputScriptBlock
    }
}

function Invoke-Test
{
    [CmdletBinding(DefaultParameterSetName = 'Normal')]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock,

        [scriptblock] $OutputScriptBlock,

        [System.Collections.IDictionary] $Parameters,
        [string] $ParameterizedSuiteName,

        [Parameter(ParameterSetName = 'Pending')]
        [Switch] $Pending,

        [Parameter(ParameterSetName = 'Skip')]
        [Alias('Ignore')]
        [Switch] $Skip
    )

    if ($null -eq $Parameters) { $Parameters = @{} }

    $Pester.EnterTest($Name)

    if ($Skip)
    {
        $Pester.AddTestResult($Name, "Skipped", $null)
    }
    elseif ($Pending)
    {
        $Pester.AddTestResult($Name, "Pending", $null)
    }
    else
    {
        & $SafeCommands['Write-Progress'] -Activity "Running test '$Name'" -Status Processing

        $errorRecord = $null
        try
        {
            Invoke-TestCaseSetupBlocks

            do
            {
                $null = & $ScriptBlock @Parameters
            } until ($true)
        }
        catch
        {
            $errorRecord = $_
        }
        finally
        {
            #guarantee that the teardown action will run and prevent it from failing the whole suite
            try
            {
                if (-not ($Skip -or $Pending))
                {
                    Invoke-TestCaseTeardownBlocks
                }
            }
            catch
            {
                $errorRecord = $_
            }
        }


        $result = Get-PesterResult -ErrorRecord $errorRecord
        $orderedParameters = Get-OrderedParameterDictionary -ScriptBlock $ScriptBlock -Dictionary $Parameters
        $Pester.AddTestResult( $result.name, $result.Result, $null, $result.FailureMessage, $result.StackTrace, $ParameterizedSuiteName, $orderedParameters, $result.ErrorRecord )
        & $SafeCommands['Write-Progress'] -Activity "Running test '$Name'" -Completed -Status Processing
    }

    if ($null -ne $OutputScriptBlock)
    {
        $Pester.testresult[-1] | & $OutputScriptBlock
    }

    Exit-MockScope
    $Pester.LeaveTest()
}

function Get-PesterResult {
    param(
        [Nullable[TimeSpan]] $Time,
        [System.Management.Automation.ErrorRecord] $ErrorRecord
    )

    $testResult = @{
        name = $name
        time = $time
        failureMessage = ""
        stackTrace = ""
        ErrorRecord = $null
        success = $false
        result = "Failed"
    };

    if(-not $ErrorRecord)
    {
        $testResult.Result = "Passed"
        $testResult.success = $true
        return $testResult
    }

    if ($ErrorRecord.FullyQualifiedErrorID -eq 'PesterAssertionFailed')
    {
        # we use TargetObject to pass structured information about the error.
        $details = $ErrorRecord.TargetObject

        $failureMessage = $details.Message
        $file = $details.File
        $line = $details.Line
        $lineText = "`n$line`: $($details.LineText)"
    }
    elseif ($ErrorRecord.FullyQualifiedErrorId -eq 'PesterTestInconclusive')
    {
        # we use TargetObject to pass structured information about the error.
        $details = $ErrorRecord.TargetObject

        $failureMessage = $details.Message
        $file = $details.File
        $line = $details.Line
        $lineText = "`n$line`: $($details.LineText)"

        $testResult.Result = 'Inconclusive'
    }
    else
    {
        $failureMessage = $ErrorRecord.ToString()
        $file = $ErrorRecord.InvocationInfo.ScriptName
        $line = $ErrorRecord.InvocationInfo.ScriptLineNumber
        $lineText = ''
    }

    $testResult.failureMessage = $failureMessage
    $testResult.stackTrace = "at line: $line in ${file}${lineText}"
    $testResult.ErrorRecord = $ErrorRecord

    return $testResult
}

function Remove-Comments ($Text)
{
    $text -replace "(?s)(<#.*#>)" -replace "\#.*"
}

function Get-OrderedParameterDictionary
{
    [OutputType([System.Collections.IDictionary])]
    param (
        [scriptblock] $ScriptBlock,
        [System.Collections.IDictionary] $Dictionary
    )

    $parameters = Get-ParameterDictionary -ScriptBlock $ScriptBlock

    $orderedDictionary = & $SafeCommands['New-Object'] System.Collections.Specialized.OrderedDictionary

    foreach ($parameterName in $parameters.Keys)
    {
        $value = $null
        if ($Dictionary.ContainsKey($parameterName))
        {
            $value = $Dictionary[$parameterName]
        }

        $orderedDictionary[$parameterName] = $value
    }

    return $orderedDictionary
}

function Get-ParameterDictionary
{
    param (
        [scriptblock] $ScriptBlock
    )

    $guid = [guid]::NewGuid().Guid

    try
    {
        & $SafeCommands['Set-Content'] function:\$guid $ScriptBlock
        $metadata = [System.Management.Automation.CommandMetadata](& $SafeCommands['Get-Command'] -Name $guid -CommandType Function)

        return $metadata.Parameters
    }
    finally
    {
        if (& $SafeCommands['Test-Path'] function:\$guid) { & $SafeCommands['Remove-Item'] function:\$guid }
    }
}

# SIG # Begin signature block
# MIInXgYJKoZIhvcNAQcCoIInTzCCJ0sCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAJRIPwOjAQ/ONG
# FAFN0nZ5tXeJNCsoEPb8IZ5X8QGPUqCCC7QwggXLMIIEs6ADAgECAhMzAAABQGf2
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
# e09D2ORRncTx8u6seYptx6dKt2lLeuGAA8Gjb/jVOL4wUAYKKwYBBAGCNwoDHDFC
# DEAyMkM5NUNDMEY1RjdDMDA0MUU4ODhFRTIyMzY5NTQ5ODJBQjgwMTJDMThFQzg5
# OTRBMkJEMENFMTBDNUNFRjlFMFoGCisGAQQBgjcCAQwxTDBKoCSAIgBNAGkAYwBy
# AG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0cDovL3d3dy5taWNyb3Nv
# ZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggGAT74b5FcosT7xB3hegPFG
# RHDSNgKt0e/fs1Mk5rcOh7d+psegjLBYmk1IkzS1LQCBtOUR+5eXaNeiI45JyrCz
# w71vUlssVhREUPgvHU4OcHHF5woioybk9+KYM46+fGEE7DFvqun2Jpf1Vf9/fJMu
# mTnoNgOUUxbQTBHanRscYpEah44bpZ50rR+tLSC7lSU/NaxzZbX+GL9DM3tD2145
# +WxUGD2ueIyH/d5MW28iYeaKtMWdRdqOU9mW0To9uZvtpLIJ/0yF3Vt3sHoWxz77
# izDLfVjL/Ims8jAoTj628D0HxydY0qdPYNOdHhsTek5sLf4CsvJGYb6RDC5yIU8X
# 7CZzUE/WBlt6S4xF+x2vB1yDzsc2tNzbdBi3ZKCTtCwg+7jtpNC/xilP3d7YdROG
# ILKWztY/Yh3GMKxDAUnW8STu9EK9shMX1hv2PLVbXOqgCkSS7+Iy3MSF7avfxuJg
# CYARYXvjuF0FoI+w2xwfVfupmdtFNM0QvTdcZLsaqr1SoYIXrTCCF6kGCisGAQQB
# gjcDAwExgheZMIIXlQYJKoZIhvcNAQcCoIIXhjCCF4ICAQMxDzANBglghkgBZQME
# AgEFADCCAVoGCyqGSIb3DQEJEAEEoIIBSQSCAUUwggFBAgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIIJEAa09oBqENW4l8y5cW3WOMjRMpjU3nbe+doqa
# wpc9AgZqif9a4xEYEzIwMjYwOTEyMTM1MzE4Ljc0NFowBIACAfSggdmkgdYwgdMx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1p
# Y3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEnMCUGA1UECxMeblNo
# aWVsZCBUU1MgRVNOOjZGMUEtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQg
# VGltZS1TdGFtcCBTZXJ2aWNloIIR+zCCBygwggUQoAMCAQICEzMAAAIcCVUV18NZ
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
# TY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggNWMIICPgIBATCCAQGhgdmkgdYwgdMx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1p
# Y3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEnMCUGA1UECxMeblNo
# aWVsZCBUU1MgRVNOOjZGMUEtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQg
# VGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQBaZOIDTW7mbGr+dXGJ
# Eksw6yRUZ6CBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0G
# CSqGSIb3DQEBCwUAAgUA7k+CTzAiGA8yMDI2MDkxMjA3NDgzMVoYDzIwMjYwOTEz
# MDc0ODMxWjB0MDoGCisGAQQBhFkKBAExLDAqMAoCBQDuT4JPAgEAMAcCAQACAgIX
# MAcCAQACAhI2MAoCBQDuUNPPAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQB
# hFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEB
# AGKWt4nUpehxRc3KJGrhxpGC+nQ/2/RCmSCyQ/CgEIuYDRevhLmOZlgs8mlJeZJX
# IidxI+2voRpSdDnBSIHG4+Ii3ITMYGVEh9fBD0ola5B2aEeCLWLNR0FYONYy2el7
# axa2IBnzJzXJZjlcOy1ZuS8SITdDy6nGLVdEE/7y1KmIAL1E5/BdS5The3SwGMRq
# PVAk4wdYRqUEvK0opjz2LmSiLTQceKWcM/18KraYjSZ4s2zpZc0DK6f/HdzdV56z
# RVd2TL4JPTC8iza68XubyD+PAfU5GVKd+rWbhqYWz4YvXQUgC2EqAYRccXbD39P/
# 3gGDxNmI4GuD45cUv1CmJ/oxggQNMIIECQIBATCBkzB8MQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1T
# dGFtcCBQQ0EgMjAxMAITMwAAAhwJVRXXw1kH0QABAAACHDANBglghkgBZQMEAgEF
# AKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJBDEi
# BCD/AngVLNPyWRVYbgYxF+LlAEeB3rE2zYO8/fvCjME1YTCB+gYLKoZIhvcNAQkQ
# Ai8xgeowgecwgeQwgb0EIKAgaSY2F2jv4oTt1aEj4TYK3HZEtahi+8mh0IhyIcdo
# MIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAO
# BgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEm
# MCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAIcCVUV
# 18NZB9EAAQAAAhwwIgQg/gYM4LXEMnG03u+IcuwoYPlSMj05pKepaCNNgnVpFDow
# DQYJKoZIhvcNAQELBQAEggIAb5GCEFzdyzxY8k1Zfk3m9HDRHrt1NtwVqI7vRuTE
# duRH+N1Rw99B3woZAVzM/dSNn05iFIFu9KuGJaalIA+qKpb7vqc8B8lEVhhPbpJ5
# d7kh2SNX3aabCLNnvKc5p7pAiOAbUcvoQ17K1wZT5v14sET5FH/k87BXNWjVw1cT
# npfo2vnXFS5Oa+AjzfsZzZtsr9ktLoW+X7grVcWsKQRI/fxNnjw8C3MngCHSsUo7
# 4eG6PuMfm92cvzcp7ldUFPZw65kNf0JL1qbp3XDWe18NTVKEPVVZynqzi5OMMzjo
# TBfVKYv74fYdDgRZxMlQKQC6NFwoS22JRRanjXU4KDXAKseaf0Cn+Y3CHZNiYFyq
# P10iTOf3Sa9mJZOehY/XJeQjkZrHWoxOR2qnRkfMgF9hzvkZfDlfmyN++UwFFLC3
# mSuv8phMFaxJeE9iQk2Vwwo5qIQ26iITlo0ysCCLlOm9EeTOevjGMN2QXqrQ1vCb
# oXJ0K/WUtGsldVD6zqcLrNokaJu2zgqqkSGfRjgFYWlF/yJHUMO5w96/0LqB+032
# o8j/Zbl7hrWY+WggFq9G7CyHEwmjYo4iDFYKlT0AdD5nWTkqPnn3ND9+gvaInQHm
# pFAMVxNKJX737ODBJA7eb52Ep3NI7hpBtLZZdA4tT/JqfpvUlg4d63ZYsR9Zce28
# hPE=
# SIG # End signature block
