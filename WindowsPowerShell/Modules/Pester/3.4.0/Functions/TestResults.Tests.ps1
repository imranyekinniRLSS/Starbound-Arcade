Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "Write nunit test results (Legacy)" {
        Setup -Dir "Results"

        It "should write a successful test result" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')
            $TestResults.AddTestResult("Successful testcase","Passed",(New-TimeSpan -Seconds 1))

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile -LegacyFormat
            $xmlResult = [xml] (Get-Content $testFile)
            $xmlTestCase = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-case'
            $xmlTestCase.name     | Should Be "Successful testcase"
            $xmlTestCase.result   | Should Be "Success"
            $xmlTestCase.time     | Should Be "1"
        }

        It "should write a failed test result" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')
            $time = [TimeSpan]::FromSeconds(2.5)
            $TestResults.AddTestResult("Failed testcase","Failed",$time,'Assert failed: "Expected: Test. But was: Testing"','at line: 28 in  C:\Pester\Result.Tests.ps1')

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile -LegacyFormat
            $xmlResult = [xml] (Get-Content $testFile)
            $xmlTestCase = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-case'
            $xmlTestCase.name                   | Should Be "Failed testcase"
            $xmlTestCase.result                 | Should Be "Failure"
            $xmlTestCase.time                   | Should Be "2.5"
            $xmlTestCase.failure.message        | Should Be 'Assert failed: "Expected: Test. But was: Testing"'
            $xmlTestCase.failure.'stack-trace'  | Should Be 'at line: 28 in  C:\Pester\Result.Tests.ps1'
        }

         It "should write the test summary" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')
            $TestResults.AddTestResult("Testcase","Passed",(New-TimeSpan -Seconds 1))

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile -LegacyFormat
            $xmlResult = [xml] (Get-Content $testFile)
            $xmlTestResult = $xmlResult.'test-results'
            $xmlTestResult.total    | Should Be 1
            $xmlTestResult.failures | Should Be 0
            $xmlTestResult.date     | Should Be $true
            $xmlTestResult.time     | Should Be $true
        }

        it "should write the test-suite information" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')
            $TestResults.AddTestResult("Successful testcase","Passed",[timespan]10000000) #1.0 seconds
            $TestResults.AddTestResult("Successful testcase","Passed",[timespan]11000000) #1.1 seconds

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile -LegacyFormat
            $xmlResult = [xml] (Get-Content $testFile)

            $xmlTestResult = $xmlResult.'test-results'.'test-suite'.results.'test-suite'

            $description = $null
            if ($xmlTestResult.PSObject.Properties['description'])
            {
                $description = $xmlTestResult.description
            }

            $xmlTestResult.type    | Should Be "Powershell"
            $xmlTestResult.name    | Should Be "Mocked Describe"
            $description           | Should BeNullOrEmpty
            $xmlTestResult.result  | Should Be "Success"
            $xmlTestResult.success | Should Be "True"
            $xmlTestResult.time    | Should Be 2.1
        }

        it "should write two test-suite elements for two describes" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Describe #1')
            $TestResults.AddTestResult("Successful testcase","Passed",(New-TimeSpan -Seconds 1))
            $TestResults.LeaveDescribe()
            $testResults.EnterDescribe('Describe #2')
            $TestResults.AddTestResult("Failed testcase","Failed",(New-TimeSpan -Seconds 2))

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile -LegacyFormat
            $xmlResult = [xml] (Get-Content $testFile)

            $xmlTestSuite1 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[0]

            $description = $null
            if ($xmlTestSuite1.PSObject.Properties['description'])
            {
                $description = $xmlTestSuite1.description
            }

            $xmlTestSuite1.name    | Should Be "Describe #1"
            $description           | Should BeNullOrEmpty
            $xmlTestSuite1.result  | Should Be "Success"
            $xmlTestSuite1.success | Should Be "True"
            $xmlTestSuite1.time    | Should Be 1.0

            $xmlTestSuite2 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[1]
            $description = $null
            if ($xmlTestSuite2.PSObject.Properties['description'])
            {
                $description = $xmlTestSuite2.description
            }

            $xmlTestSuite2.name    | Should Be "Describe #2"
            $description           | Should BeNullOrEmpty
            $xmlTestSuite2.result  | Should Be "Failure"
            $xmlTestSuite2.success | Should Be "False"
            $xmlTestSuite2.time    | Should Be 2.0
        }

        it "should write parent results in tree correctly" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Failed')
            $TestResults.AddTestResult("Failed","Failed")
            $TestResults.AddTestResult("Skipped","Skipped")
            $TestResults.AddTestResult("Pending","Pending")
            $TestResults.AddTestResult("Passed","Passed")
            $TestResults.LeaveDescribe()

            $testResults.EnterDescribe('Skipped')
            $TestResults.AddTestResult("Skipped","Skipped")
            $TestResults.AddTestResult("Pending","Pending")
            $TestResults.AddTestResult("Passed","Passed")
            $TestResults.LeaveDescribe()

            $testResults.EnterDescribe('Pending')
            $TestResults.AddTestResult("Pending","Pending")
            $TestResults.AddTestResult("Passed","Passed")
            $TestResults.LeaveDescribe()

            $testResults.EnterDescribe('Passed')
            $TestResults.AddTestResult("Passed","Passed")
            $TestResults.LeaveDescribe()

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xmlResult = [xml] (Get-Content $testFile)

            $xmlTestSuite1 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[0]
            $xmlTestSuite1.name     | Should Be "Failed"
            $xmlTestSuite1.result   | Should Be "Failure"
            $xmlTestSuite1.success  | Should Be "False"

            $xmlTestSuite2 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[1]
            $xmlTestSuite2.name     | Should Be "Skipped"
            $xmlTestSuite2.result   | Should Be "Ignored"
            $xmlTestSuite2.success  | Should Be "True"

            $xmlTestSuite3 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[2]
            $xmlTestSuite3.name     | Should Be "Pending"
            $xmlTestSuite3.result   | Should Be "Inconclusive"
            $xmlTestSuite3.success  | Should Be "True"

            $xmlTestSuite4 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[3]
            $xmlTestSuite4.name     | Should Be "Passed"
            $xmlTestSuite4.result   | Should Be "Success"
            $xmlTestSuite4.success  | Should Be "True"

        }

        it "should write the environment information" {
            $state = New-PesterState "."
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $state $testFile -LegacyFormat
            $xmlResult = [xml] (Get-Content $testFile)

            $xmlEnvironment = $xmlResult.'test-results'.'environment'
            $xmlEnvironment.'os-Version'    | Should Be $true
            $xmlEnvironment.platform        | Should Be $true
            $xmlEnvironment.cwd             | Should Be (Get-Location).Path
            if ($env:Username) {
                $xmlEnvironment.user        | Should Be $env:Username
            }
            $xmlEnvironment.'machine-name'  | Should Be $env:ComputerName
        }

        it "Should validate test results against the nunit 2.5 schema" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Describe #1')
            $TestResults.AddTestResult("Successful testcase","Passed",(New-TimeSpan -Seconds 1))
            $TestResults.LeaveDescribe()
            $testResults.EnterDescribe('Describe #2')
            $TestResults.AddTestResult("Failed testcase","Failed",(New-TimeSpan -Seconds 2))

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile -LegacyFormat
            $xml = [xml] (Get-Content $testFile)

            $schemePath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"
            $xml.Schemas.Add($null,$schemePath) > $null
            { $xml.Validate({throw $args.Exception }) } | Should Not Throw
        }

        it "handles special characters in block descriptions well -!@#$%^&*()_+`1234567890[];'',./""- " {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Describe -!@#$%^&*()_+`1234567890[];'',./"- #1')
            $TestResults.AddTestResult("Successful testcase -!@#$%^&*()_+`1234567890[];'',./""-","Passed",(New-TimeSpan -Seconds 1))
            $TestResults.LeaveDescribe()

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile -LegacyFormat
            $xml = [xml] (Get-Content $testFile)

            $schemePath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"
            $xml.Schemas.Add($null,$schemePath) > $null
            { $xml.Validate({throw $args.Exception }) } | Should Not Throw
        }

        Context 'Exporting Parameterized Tests (New Legacy)' {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')

            $TestResults.AddTestResult(
                'Parameterized Testcase One',
                'Passed',
                (New-TimeSpan -Seconds 1),
                $null,
                $null,
                'Parameterized Testcase <A>',
                @{ Parameter = 'One' }
            )

            $TestResults.AddTestResult(
                'Parameterized Testcase <A>',
                'Failed',
                (New-TimeSpan -Seconds 1),
                'Assert failed: "Expected: Test. But was: Testing"',
                'at line: 28 in  C:\Pester\Result.Tests.ps1',
                'Parameterized Testcase <A>',
                @{ Parameter = 'Two' }

            )

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile -LegacyFormat
            $xmlResult    = [xml] (Get-Content $testFile)

            It 'should write parameterized test results correctly' {
                $xmlTestSuite = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-suite'

                $description = $null
                if ($xmlTestSuite.PSObject.Properties['description'])
                {
                    $description = $xmlTestSuite.description
                }

                $xmlTestSuite.name    | Should Be 'Parameterized Testcase <A>'
                $description          | Should BeNullOrEmpty
                $xmlTestSuite.type    | Should Be 'ParameterizedTest'
                $xmlTestSuite.result  | Should Be 'Failure'
                $xmlTestSuite.success | Should Be 'False'
                $xmlTestSuite.time    | Should Be '2'

                foreach ($testCase in $xmlTestSuite.results.'test-case')
                {
                    $testCase.Name | Should Match '^Parameterized Testcase (One|<A>)$'
                    $testCase.time | Should Be 1
                }
            }

            it 'Should validate test results against the nunit 2.5 schema' {
                $schemaPath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"
                $null = $xmlResult.Schemas.Add($null,$schemaPath)
                { $xmlResult.Validate({throw $args.Exception }) } | Should Not Throw
            }
        }
    }

    Describe "Write nunit test results (Newer format)" {
        Setup -Dir "Results"

        It "should write a successful test result" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')
            $TestResults.AddTestResult("Successful testcase",'Passed',(New-TimeSpan -Seconds 1))

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xmlResult = [xml] (Get-Content $testFile)
            $xmlTestCase = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-case'
            $xmlTestCase.name     | Should Be "Mocked Describe.Successful testcase"
            $xmlTestCase.result   | Should Be "Success"
            $xmlTestCase.time     | Should Be "1"
        }

        It "should write a failed test result" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')
            $time = [TimeSpan]25000000 #2.5 seconds
            $TestResults.AddTestResult("Failed testcase",'Failed',$time,'Assert failed: "Expected: Test. But was: Testing"','at line: 28 in  C:\Pester\Result.Tests.ps1')

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xmlResult = [xml] (Get-Content $testFile)
            $xmlTestCase = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-case'
            $xmlTestCase.name                   | Should Be "Mocked Describe.Failed testcase"
            $xmlTestCase.result                 | Should Be "Failure"
            $xmlTestCase.time                   | Should Be "2.5"
            $xmlTestCase.failure.message        | Should Be 'Assert failed: "Expected: Test. But was: Testing"'
            $xmlTestCase.failure.'stack-trace'  | Should Be 'at line: 28 in  C:\Pester\Result.Tests.ps1'
        }

         It "should write the test summary" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')
            $TestResults.AddTestResult("Testcase",'Passed',(New-TimeSpan -Seconds 1))

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xmlResult = [xml] (Get-Content $testFile)
            $xmlTestResult = $xmlResult.'test-results'
            $xmlTestResult.total    | Should Be 1
            $xmlTestResult.failures | Should Be 0
            $xmlTestResult.date     | Should Be $true
            $xmlTestResult.time     | Should Be $true
        }

        it "should write the test-suite information" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')
            $TestResults.AddTestResult("Successful testcase",'Passed',[timespan]10000000) #1.0 seconds
            $TestResults.AddTestResult("Successful testcase",'Passed',[timespan]11000000) #1.1 seconds

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xmlResult = [xml] (Get-Content $testFile)

            $xmlTestResult = $xmlResult.'test-results'.'test-suite'.results.'test-suite'
            $xmlTestResult.type            | Should Be "TestFixture"
            $xmlTestResult.name            | Should Be "Mocked Describe"
            $xmlTestResult.description     | Should Be "Mocked Describe"
            $xmlTestResult.result          | Should Be "Success"
            $xmlTestResult.success         | Should Be "True"
            $xmlTestResult.time            | Should Be 2.1
        }

        it "should write two test-suite elements for two describes" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Describe #1')
            $TestResults.AddTestResult("Successful testcase",'Passed',(New-TimeSpan -Seconds 1))
            $TestResults.LeaveDescribe()
            $testResults.EnterDescribe('Describe #2')
            $TestResults.AddTestResult("Failed testcase",'Failed',(New-TimeSpan -Seconds 2))

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xmlResult = [xml] (Get-Content $testFile)

            $xmlTestSuite1 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[0]
            $xmlTestSuite1.name        | Should Be "Describe #1"
            $xmlTestSuite1.description | Should Be "Describe #1"
            $xmlTestSuite1.result      | Should Be "Success"
            $xmlTestSuite1.success     | Should Be "True"
            $xmlTestSuite1.time        | Should Be 1.0

            $xmlTestSuite2 = $xmlResult.'test-results'.'test-suite'.results.'test-suite'[1]
            $xmlTestSuite2.name        | Should Be "Describe #2"
            $xmlTestSuite2.description | Should Be "Describe #2"
            $xmlTestSuite2.result      | Should Be "Failure"
            $xmlTestSuite2.success     | Should Be "False"
            $xmlTestSuite2.time        | Should Be 2.0
        }

        it "should write the environment information" {
            $state = New-PesterState "."
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $state $testFile
            $xmlResult = [xml] (Get-Content $testFile)

            $xmlEnvironment = $xmlResult.'test-results'.'environment'
            $xmlEnvironment.'os-Version'    | Should Be $true
            $xmlEnvironment.platform        | Should Be $true
            $xmlEnvironment.cwd             | Should Be (Get-Location).Path
            if ($env:Username) {
                $xmlEnvironment.user        | Should Be $env:Username
            }
            $xmlEnvironment.'machine-name'  | Should Be $env:ComputerName
        }

        it "Should validate test results against the nunit 2.5 schema" {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Describe #1')
            $TestResults.AddTestResult("Successful testcase",'Passed',(New-TimeSpan -Seconds 1))
            $TestResults.LeaveDescribe()
            $testResults.EnterDescribe('Describe #2')
            $TestResults.AddTestResult("Failed testcase",'Failed',(New-TimeSpan -Seconds 2))

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xml = [xml] (Get-Content $testFile)

            $schemePath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"
            $xml.Schemas.Add($null,$schemePath) > $null
            { $xml.Validate({throw $args.Exception }) } | Should Not Throw
        }

        it "handles special characters in block descriptions well -!@#$%^&*()_+`1234567890[];'',./""- " {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Describe -!@#$%^&*()_+`1234567890[];'',./"- #1')
            $TestResults.AddTestResult("Successful testcase -!@#$%^&*()_+`1234567890[];'',./""-",'Passed',(New-TimeSpan -Seconds 1))
            $TestResults.LeaveDescribe()

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xml = [xml] (Get-Content $testFile)

            $schemePath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"
            $xml.Schemas.Add($null,$schemePath) > $null
            { $xml.Validate({throw $args.Exception }) } | Should Not Throw
        }

        Context 'Exporting Parameterized Tests (Newer format)' {
            #create state
            $TestResults = New-PesterState -Path TestDrive:\
            $testResults.EnterDescribe('Mocked Describe')

            $TestResults.AddTestResult(
                'Parameterized Testcase One',
                'Passed',
                (New-TimeSpan -Seconds 1),
                $null,
                $null,
                'Parameterized Testcase <A>',
                @{Parameter = 'One'}
            )

            $parameters = New-Object System.Collections.Specialized.OrderedDictionary
            $parameters.Add('StringParameter', 'Two')
            $parameters.Add('NullParameter', $null)
            $parameters.Add('NumberParameter', -42.67)

            $TestResults.AddTestResult(
                'Parameterized Testcase <A>',
                'Failed',
                (New-TimeSpan -Seconds 1),
                'Assert failed: "Expected: Test. But was: Testing"',
                'at line: 28 in  C:\Pester\Result.Tests.ps1',
                'Parameterized Testcase <A>',
                $parameters
            )

            #export and validate the file
            $testFile = "$TestDrive\Results\Tests.xml"
            Export-NunitReport $testResults $testFile
            $xmlResult    = [xml] (Get-Content $testFile)

            It 'should write parameterized test results correctly' {
                $xmlTestSuite = $xmlResult.'test-results'.'test-suite'.'results'.'test-suite'.'results'.'test-suite'

                $xmlTestSuite.name        | Should Be 'Mocked Describe.Parameterized Testcase <A>'
                $xmlTestSuite.description | Should Be 'Parameterized Testcase <A>'
                $xmlTestSuite.type        | Should Be 'ParameterizedTest'
                $xmlTestSuite.result      | Should Be 'Failure'
                $xmlTestSuite.success     | Should Be 'False'
                $xmlTestSuite.time        | Should Be '2'

                $testCase1 = $xmlTestSuite.results.'test-case'[0]
                $testCase2 = $xmlTestSuite.results.'test-case'[1]

                $testCase1.Name | Should Be 'Mocked Describe.Parameterized Testcase One'
                $testCase1.Time | Should Be 1

                $testCase2.Name | Should Be 'Mocked Describe.Parameterized Testcase <A>("Two",null,-42.67)'
                $testCase2.Time | Should Be 1
            }

            it 'Should validate test results against the nunit 2.5 schema' {
                $schemaPath = (Get-Module -Name Pester).Path | Split-Path | Join-Path -ChildPath "nunit_schema_2.5.xsd"
                $null = $xmlResult.Schemas.Add($null,$schemaPath)
                { $xmlResult.Validate({throw $args.Exception }) } | Should Not Throw
            }
        }
    }

    Describe "Get-TestTime" {
        function Using-Culture {
            param (
                [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
                [ScriptBlock]$ScriptBlock,
                [System.Globalization.CultureInfo]$Culture='en-US'
            )

            $oldCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
            try
            {
                [System.Threading.Thread]::CurrentThread.CurrentCulture = $Culture
                $ExecutionContext.InvokeCommand.InvokeScript($ScriptBlock)
            }
            finally
            {
                [System.Threading.Thread]::CurrentThread.CurrentCulture = $oldCulture
            }
        }

        It "output is culture agnostic" {
            #on cs-CZ, de-DE and other systems where decimal separator is ",". value [double]3.5 is output as 3,5
            #this makes some of the tests fail, it could also leak to the nUnit report if the time was output

            $TestResult = New-Object -TypeName psObject -Property @{ Time = [timespan]35000000 } #3.5 seconds

            #using the string formatter here to know how the string will be output to screen
            $Result = { Get-TestTime -Tests $TestResult | Out-String -Stream } | Using-Culture -Culture de-DE
            $Result | Should Be "3.5"
        }
        It "Time is measured in seconds with 0,1 millisecond as lowest value" {
            $TestResult = New-Object -TypeName psObject -Property @{ Time = [timespan]1000 }
            Get-TestTime -Tests $TestResult | Should Be 0.0001
            $TestResult = New-Object -TypeName psObject -Property @{ Time = [timespan]100 }
            Get-TestTime -Tests $TestResult | Should Be 0
            $TestResult = New-Object -TypeName psObject -Property @{ Time = [timespan]1234567 }
            Get-TestTime -Tests $TestResult | Should Be 0.1235
        }
    }

    Describe "GetFullPath" {
        It "Resolves non existing path correctly" {
            pushd TestDrive:\
            $p = GetFullPath notexistingfile.txt
            popd
            $p | Should Be (Join-Path $TestDrive notexistingfile.txt)
        }

        It "Resolves existing path correctly" {
            pushd TestDrive:\
            New-Item -ItemType File -Name existingfile.txt
            $p = GetFullPath existingfile.txt
            popd
            $p | Should Be (Join-Path $TestDrive existingfile.txt)
        }

        It "Resolves full path correctly" {
            GetFullPath C:\Windows\System32\notepad.exe | Should Be C:\Windows\System32\notepad.exe
        }
    }
}

# SIG # Begin signature block
# MIInRAYJKoZIhvcNAQcCoIInNTCCJzECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBKD7WI8pBtccjL
# Ep1BJK+QbNkIDGYkDdkUBOY1i/oaFaCCC7QwggXLMIIEs6ADAgECAhMzAAABQGf2
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
# GuYwghriAgEBMIGmMIGOMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMTgwNgYDVQQDEy9NaWNyb3NvZnQgV2luZG93cyBUaGlyZCBQYXJ0eSBDb21w
# b25lbnQgQ0EgMjAxMgITMwAAAUBn9phrMQi4cgAAAAABQDANBglghkgBZQMEAgEF
# AKCB+jAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAvBgkqhkiG9w0BCQQxIgQg
# C0Ks46ZT58jpdBsRRqtdYH41Ska1tmmHIJ/c2UqMR8AwUAYKKwYBBAGCNwoDHDFC
# DEA4MDM4NjJEM0Y0NUYxRUQ0RDRDMTY1QkE2MDE3RTdEQkQwMEUxRkVDQTBFNTE1
# MkM5QTQ0RDk0RDY5RjU3RTNCMFoGCisGAQQBgjcCAQwxTDBKoCSAIgBNAGkAYwBy
# AG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0cDovL3d3dy5taWNyb3Nv
# ZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggGAgipGB/iSAN2lqCW7LVrr
# 9RvLJw3MQY3pGChoo3t5BNWxkljuSPaVV1Oq7/9y7uoMAdM7LSLPMr79hxMO8cZy
# xr3hnlhRYWQhyoC5kAATKuR38Z/Qr9MUQZKANDKmbY1Yiy5uOCsbrgpbomSTZGof
# re8DxGtr2ChzEUXsThB1ggOudrNHIFlcY5uRvwBeUNm+1ROuEcP5GQQma1ZwyUMT
# 9pqmiAjSy+ldk150GK34T8sqTYjyCisAuBx+CppXQdESygG0laEQe4nbicxWlq8A
# VTLtdUYged+ntMzW7LtLUCvhAuv8aQJYTwUaCisgv8y/fk3AM/T9F9XjyisxUWwl
# 7ID8wdcV6pCqaUOyuMYHAw/1OhWVJhM7t0h9jbi5Sd+hV0pzn2N7j8oYKfCdmEsa
# TxI6aI7lusBB+lmX+9b8c0YMt94PHq4FhfSSX8zpgwv2Pv8b/N30B/Tuw/x8Hd9y
# cuIthumjfroT9dFltJLF0UVj8XvcHoUsYxMA+LLqO2oooYIXkzCCF48GCisGAQQB
# gjcDAwExghd/MIIXewYJKoZIhvcNAQcCoIIXbDCCF2gCAQMxDzANBglghkgBZQME
# AgEFADCCAVEGCyqGSIb3DQEJEAEEoIIBQASCATwwggE4AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIEeFPR9i9K3RQjeLpRA1PLNfhuz+I/xjrZ5IhqQ9
# BVgyAgZqqk0EUxsYEjIwMjYxMDEwMDgzNjM2LjQ1WjAEgAIB9KCB0aSBzjCByzEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1Mg
# RVNOOjM3MDMtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFt
# cCBTZXJ2aWNloIIR6jCCByAwggUIoAMCAQICEzMAAAIfOnBp5KIwLpUAAQAAAh8w
# DQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcN
# MjYwMjE5MTkzOTUxWhcNMjcwNTE3MTkzOTUxWjCByzELMAkGA1UEBhMCVVMxEzAR
# BgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1p
# Y3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2Eg
# T3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjM3MDMtMDVFMC1E
# OTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNlMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAyzvFxTnHxqgKoIs9PgJkJhZd3WdG
# kxuFBSZKqjXTB8tvA2oXggbOjjbn7pMnuceNglpM4ESMvZBNlVsBJ7WfGZIMq8pA
# tGyKrCA+/uhcYLrHk139VcL5tQ/NdOFZnraASZSeLhm7siWVL1w8eeZ1YedMoC08
# 2duFpELJz6b0Wb9pD3N/X924S8h1bZx7Gv1v/Ola37XfgHxb3gPqjfxGPlxo+XPw
# zzFwmBAm9Gq2G/dnQyVrcM6cga6eIHx5YGNVBKXOJeABhC639ieMK8U801vkjPF4
# VdXTjj62Iw9PNCG2ai/AfiBdEQnZ9uvWF6xiukCB4qc5ymXAkvIzd9GAB50yVTeW
# c7Orf9mLKgRg6rrw2ne/d+BRU8M71HDt1aCMnfd11sLz/P0ghVSYdtVvKBkE6bRh
# 8pcvhZeIXp1TFWRdb+qLDrYq1/BhU4hIZ3/J0XToO8mWACdMcvQrQ3212k5/3H9y
# 6tzfxgmChYwvuZlAhPgCYZsTLjHb0lBpiogBXYjwI1E6rFlgQWSZtHgsIHhiRZpk
# APle//fASnBPoFC+zvXlkQ0MCngHL6Oq8Tb9mOIyqxwOmf8It2v3ylISwjWREvKh
# na6QwJu6ofuhY2McrQG5IijOrkzcv1Cz5cLZWGaACQw0D+3mAssMFWzU2x10QUkv
# jXHAtLEgeFu1Ou8CAwEAAaOCAUkwggFFMB0GA1UdDgQWBBTZO9rBg5R9K+Q8L3xk
# eV8CSPAe2zAfBgNVHSMEGDAWgBSfpxVdAF5iXYP05dJlpxtTNRnpcjBfBgNVHR8E
# WDBWMFSgUqBQhk5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9N
# aWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcmwwbAYIKwYB
# BQUHAQEEYDBeMFwGCCsGAQUFBzAChlBodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20v
# cGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEw
# KDEpLmNydDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMA4G
# A1UdDwEB/wQEAwIHgDANBgkqhkiG9w0BAQsFAAOCAgEAZW7tyKMp5z89CtYj23jZ
# 7Ho9m9eZebHZdhQBQQRk/ZUXXNoDVfCwCLrD2Bx4VL0Q3LMeJWzDYVSjxruEwy2q
# jbfwiPkhbRrqnUS6VT9VxPXAi8iqyj6XCRSQqj6Vfnn6ALWAZiFEHMccE+1iEO4G
# oPPq5Cr6zJAqEaiktJir/CdbCn4vOfhtroWf9UbXklXWGTmTo/km+MM6J0wk4+xL
# YDDfwV9+VuXU83e8CXRnqWJFYvO9XUqwtk69WRcwEe0uOHawlmaSeqYSWm1TTrDc
# RSSoEspLoDhls0N9fEa9zEz4NrNwZ7PqVD1YDIo3eG1Dh9gZRLCzDMDnKJU02aoN
# R2K3WNY8aVACPYqYwUESDS/zu9OWfv39i4zZiUKKAlSVV9uGnaWedfUrH2sxqKlx
# rfdW5qiqNHyNPSJeLFB4eIoeq6YkAwZci+75rwno8FcWHr2OKlcE2f6N4L5fkdJR
# cWEvX3iDODXhtPlrA2e4y3IuTBXrjcKLEGN89ul4NaI9FPbvp3Efbk1PsQZifAbZ
# QnYUNd0TTF+T/pK0WDwd1wqfSZul2jtffeat9gCGZtZswRiOsh5b4l2hAuU8xojt
# S17j7V2VNl/d6ECWzKHt7/PuQjyq0GpRlsmLodmt1dacG4/ltBRJhBT6bvEyPqmD
# tSCEFlEkbxY17YeTm9NoTDIwggdxMIIFWaADAgECAhMzAAAAFcXna54Cm0mZAAAA
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
# WLOhcGbyoYIDTTCCAjUCAQEwgfmhgdGkgc4wgcsxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9w
# ZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjozNzAzLTA1RTAtRDk0
# NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcG
# BSsOAwIaAxUASyDINT+7Dbgl6Zmx9iF09rV3hBCggYMwgYCkfjB8MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQg
# VGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQsFAAIFAO50a4UwIhgPMjAy
# NjEwMTAwNzQ1MDlaGA8yMDI2MTAxMTA3NDUwOVowdDA6BgorBgEEAYRZCgQBMSww
# KjAKAgUA7nRrhQIBADAHAgEAAgIuhDAHAgEAAgISHzAKAgUA7nW9BQIBADA2Bgor
# BgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIBAAIDB6EgoQowCAIBAAID
# AYagMA0GCSqGSIb3DQEBCwUAA4IBAQA8lCSJ+yfiK2+/Fb0qXfcuiDda479veWyT
# /x/MpWwGarqjvXevHdjvhVcTL3K9cOSyhc+NN6a5lgW66pFOKiNEjBfkXwU1NZnF
# WDfsI4Kjk5s20N5bXFNGrvad/pnoickWNwlq5R2Cq1R2fMXbn3yLfYaoVxP8P4bg
# rVg3wMSlzzT8E3uwzPzNVldt6TunmJbUQXbzvokKR+tGmY4BlDtY1DAj2Fon6e/M
# cy/tmmA0SQt6B81a4PPn23Qax+q1lQ37uFIbfgtKko891m4SDFwEjrHXOJaZc39v
# We40o3q2s1ri3RuEImkR5m8RjV7hcozURXlytPmc1aaS0wQ4D0XCMYIEDTCCBAkC
# AQEwgZMwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQG
# A1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAIfOnBp5KIw
# LpUAAQAAAh8wDQYJYIZIAWUDBAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG
# 9w0BCRABBDAvBgkqhkiG9w0BCQQxIgQg9Bgk1mYSFh4XHWuKU7GCsx63yOHpidDH
# W5E3K0lsjSEwgfoGCyqGSIb3DQEJEAIvMYHqMIHnMIHkMIG9BCCwJArfVpArDLVE
# ZBbuk2ND91F3UZwomLj2YXt8pC38FDCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFBDQSAyMDEwAhMzAAACHzpwaeSiMC6VAAEAAAIfMCIEIOhfMjnGE8s1rS0B
# eOsBGErywHcPIVMFTqDG+eMFRYBiMA0GCSqGSIb3DQEBCwUABIICAHzJJEpjQ3uE
# CHxzkM4kkZoLZNHbmE2oeOR8oQgzpvsvGWAueNQio28f8x0Mdyw68tXRqw+JkpF1
# cCgxQRsDAUDQTcMQt4X0xx7TkX4knc8W98At92E/DE/QWBFp4hIWGagnu5RihE5Z
# IeF8AZEv/JCIXpygyw/jzTvxeBdzHyUFpF5U4cPm7OZvEqC9rK3Ws/8QBPKjHZ/q
# oPfmXBd3lT5WZ9Q1+umnUbeoch0tCtshYRvBjdK/eFCEV+Dhuh3fqYq2uPVIbomb
# rJ05t6jBTXBZEbtNEKR9hPfK4XN90z9f4i+yo0YHMFzagUz9sMn6d+KqY8YAeZHq
# CNTAcrzcz7I39eILzCJhX0ncplQrBJck2PqEUC2AJNBK3i0Mq2sOmO9x0Lg7ro+c
# WgLNVvIZxnQptcY3Rk0Dl5Grd0O/4SDFjIxzfgp26Hs7DIdl3K07tDWOjPC1rdhw
# UhNR8AR4Xf7k3xelmUdEq2ll3+FmGd4HE/9ChnfKm8ZfQBw6Twap3gNxthlXUNm6
# MkTk9JulyHHVw47CQuVR4ECDudnCjdejcfSLVde0++HP6q6ICxRS4hGFu0Lt2yFn
# Ble1wRhBikC4ERqVUDfvjFUHa30wy9L9z7hqKN3g1J7pjCy74ve4AwRPmq570Sqf
# oA8JuSQOhwaFKOPaZQAKo73KD9QBxGlu
# SIG # End signature block
