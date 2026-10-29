Set-StrictMode -Version Latest

function FunctionUnderTest
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [string]
        $param1
    )

    return "I am a real world test"
}

function FunctionUnderTestWithoutParams([string]$param1) {
    return "I am a real world test with no params"
}

filter FilterUnderTest { $_ }

function CommonParamFunction (
    [string] ${Uncommon},
    [switch]
    ${Verbose},
    [switch]
    ${Debug},
    [System.Management.Automation.ActionPreference]
    ${ErrorAction},
    [System.Management.Automation.ActionPreference]
    ${WarningAction},
    [System.String]
    ${ErrorVariable},
    [System.String]
    ${WarningVariable},
    [System.String]
    ${OutVariable},
    [System.Int32]
    ${OutBuffer} ){
    return "Please strip me of my common parameters. They are far too common."
}

function PipelineInputFunction {
    param(
        [Parameter(ValueFromPipeline=$True)]
        [int]$PipeInt1,
        [Parameter(ValueFromPipeline=$True)]
        [int[]]$PipeInt2,
        [Parameter(ValueFromPipeline=$True)]
        [string]$PipeStr,
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [int]$PipeIntProp,
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [int[]]$PipeArrayProp,
        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [string]$PipeStringProp
    )
    begin{
        $p = 0
    }
    process {
        foreach($i in $input)
        {
            $p += 1
            write-output @{
                index=$p;
                val=$i;
                PipeInt1=$PipeInt1;
                PipeInt2=$PipeInt2;
                PipeStr=$PipeStr;
                PipeIntProp=$PipeIntProp;
                PipeArrayProp=$PipeArrayProp;
                PipeStringProp=$PipeStringProp;
            }
        }
    }
}

Describe "When calling Mock on existing function" {
    Mock FunctionUnderTest { return "I am the mock test that was passed $param1"}

    $result = FunctionUnderTest "boundArg"

    It "Should rename function under test" {
        $renamed = (Test-Path function:PesterIsMocking_FunctionUnderTest)
        $renamed | Should Be $true
    }

    It "Should Invoke the mocked script" {
        $result | Should Be "I am the mock test that was passed boundArg"
    }
}

Describe "When the caller mocks a command Pester uses internally" {
    Mock Write-Host { }

    Context "Context run when Write-Host is mocked" {
        It "does not make extra calls to the mocked command" {
            Write-Host 'Some String'
            Assert-MockCalled 'Write-Host' -Exactly 1
        }

        It "retains the correct mock count after the first test completes" {
            Assert-MockCalled 'Write-Host' -Exactly 1
        }
    }
}

Describe "When calling Mock on existing cmdlet" {
    Mock Get-Process {return "I am not Get-Process"}

    $result=Get-Process

    It "Should Invoke the mocked script" {
        $result | Should Be "I am not Get-Process"
    }

    It 'Should not resolve $args to the parent scope' {
        { $args = 'From', 'Parent', 'Scope'; Get-Process SomeName } | Should Not Throw
    }
}

Describe 'When calling Mock on an alias' {
    $originalPath = $env:path

    try
    {
        # Our TeamCity server has a dir.exe on the system path, and PowerShell v2 apparently finds that instead of the PowerShell alias first.
        # This annoying bit of code makes sure our test works as intended even when this is the case.

        $dirExe = Get-Command dir -CommandType Application -ErrorAction SilentlyContinue
        if ($null -ne $dirExe)
        {
            foreach ($app in $dirExe)
            {
                $parent = (Split-Path $app.Path -Parent).TrimEnd('\')
                $pattern = "^$([regex]::Escape($parent))\\?"

                $env:path = $env:path -split ';' -notmatch $pattern -join ';'
            }
        }

        Mock dir {return 'I am not dir'}

        $result = dir

        It 'Should Invoke the mocked script' {
            $result | Should Be 'I am not dir'
        }
    }
    finally
    {
        $env:path = $originalPath
    }
}

Describe 'When calling Mock on an alias that refers to a function Pester can''t see' {
    It 'Mocks the aliased command successfully' {
        # This function is defined in a non-global scope; code inside the Pester module can't see it directly.
        function orig {'orig'}
        New-Alias 'ali' orig

        ali | Should Be 'orig'

        { mock ali {'mck'} } | Should Not Throw

        ali | Should Be 'mck'
    }
}

Describe 'When calling Mock on a filter' {
    Mock FilterUnderTest {return 'I am not FilterUnderTest'}

    $result = 'Yes I am' | FilterUnderTest

    It 'Should Invoke the mocked script' {
        $result | Should Be 'I am not FilterUnderTest'
    }
}

Describe 'When calling Mock on an external script' {
    $ps1File = New-Item 'TestDrive:\tempExternalScript.ps1' -ItemType File -Force
    $ps1File | Set-Content -Value "'I am tempExternalScript.ps1'"

    Mock 'TestDrive:\tempExternalScript.ps1' {return 'I am not tempExternalScript.ps1'}

    <#
        # Invoking the script using its absolute path is not supported

        $result = TestDrive:\tempExternalScript.ps1
        It 'Should Invoke the absolute-path-qualified mocked script using just the script name' {
            $result | Should Be 'I am not tempExternalScript.ps1'
        }

        $result = & TestDrive:\tempExternalScript.ps1
        It 'Should Invoke the absolute-path-qualified mocked script using the command-invocation operator (&)' {
            $result | Should Be 'I am not tempExternalScript.ps1'
        }

        $result = . TestDrive:\tempExternalScript.ps1
        It 'Should Invoke the absolute-path-qualified mocked script using dot source notation' {
            $result | Should Be 'I am not tempExternalScript.ps1'
        }
    #>

    Push-Location TestDrive:\

    try
    {
        $result = tempExternalScript.ps1
        It 'Should Invoke the mocked script using just the script name' {
            $result | Should Be 'I am not tempExternalScript.ps1'
        }

        $result = & tempExternalScript.ps1
        It 'Should Invoke the mocked script using the command-invocation operator' {
            #the command invocation operator is (&). Moved this to comment because it breaks the contionuous builds.
            #there is issue for this on GH

            $result | Should Be 'I am not tempExternalScript.ps1'
        }

        $result = . tempExternalScript.ps1
        It 'Should Invoke the mocked script using dot source notation' {
            $result | Should Be 'I am not tempExternalScript.ps1'
        }

        <#
            # Invoking the script using only its relative path is not supported

            $result = .\tempExternalScript.ps1
            It 'Should Invoke the relative-path-qualified mocked script' {
                $result | Should Be 'I am not tempExternalScript.ps1'
            }
        #>

    }
    finally
    {
        Pop-Location
    }

    Remove-Item $ps1File -Force -ErrorAction SilentlyContinue
}

Describe 'When calling Mock on an application command' {
    Mock schtasks.exe {return 'I am not schtasks.exe'}

    $result = schtasks.exe

    It 'Should Invoke the mocked script' {
        $result | Should Be 'I am not schtasks.exe'
    }
}

Describe "When calling Mock in the Describe block" {
    Mock Out-File {return "I am not Out-File"}

    It "Should mock Out-File successfully" {
        $outfile = "test" | Out-File "TestDrive:\testfile.txt"
        $outfile | Should Be "I am not Out-File"
    }
}

Describe "When calling Mock on existing cmdlet to handle pipelined input" {
    Mock Get-ChildItem {
        if($_ -eq 'a'){
            return "AA"
        }
        if($_ -eq 'b'){
            return "BB"
        }
    }

    $result = ''
    "a", "b" | Get-ChildItem | % { $result += $_ }

    It "Should process the pipeline in the mocked script" {
        $result | Should Be "AABB"
    }
}

Describe "When calling Mock on existing cmdlet with Common params" {
    Mock CommonParamFunction

    $result=[string](Get-Content function:\CommonParamFunction)

    It "Should strip verbose" {
        $result.contains("`${Verbose}") | Should Be $false
    }
    It "Should strip Debug" {
        $result.contains("`${Debug}") | Should Be $false
    }
    It "Should strip ErrorAction" {
        $result.contains("`${ErrorAction}") | Should Be $false
    }
    It "Should strip WarningAction" {
        $result.contains("`${WarningAction}") | Should Be $false
    }
    It "Should strip ErrorVariable" {
        $result.contains("`${ErrorVariable}") | Should Be $false
    }
    It "Should strip WarningVariable" {
        $result.contains("`${WarningVariable}") | Should Be $false
    }
    It "Should strip OutVariable" {
        $result.contains("`${OutVariable}") | Should Be $false
    }
    It "Should strip OutBuffer" {
        $result.contains("`${OutBuffer}") | Should Be $false
    }
    It "Should not strip an Uncommon param" {
        $result.contains("`${Uncommon}") | Should Be $true
    }
}

Describe "When calling Mock on non-existing function" {
    try{
        Mock NotFunctionUnderTest {return}
    } Catch {
        $result=$_
    }

    It "Should throw correct error" {
        $result.Exception.Message | Should Be "Could not find command NotFunctionUnderTest"
    }
}

Describe 'When calling Mock, StrictMode is enabled, and variables are used in the ParameterFilter' {
    Set-StrictMode -Version Latest

    $result = $null
    $testValue = 'test'

    try
    {
        Mock FunctionUnderTest { 'I am the mock' } -ParameterFilter { $param1 -eq $testValue }
    }
    catch
    {
        $result = $_
    }

    It 'Does not throw an error when testing the parameter filter' {
        $result | Should Be $null
    }

    It 'Calls the mock properly' {
        FunctionUnderTest $testValue | Should Be 'I am the mock'
    }

    It 'Properly asserts the mock was called when there is a variable in the parameter filter' {
        Assert-MockCalled FunctionUnderTest -Exactly 1 -ParameterFilter { $param1 -eq $testValue }
    }
}

Describe "When calling Mock on existing function without matching bound params" {
    Mock FunctionUnderTest {return "fake results"} -parameterFilter {$param1 -eq "test"}

    $result=FunctionUnderTest "badTest"

    It "Should redirect to real function" {
        $result | Should Be "I am a real world test"
    }
}

Describe "When calling Mock on existing function with matching bound params" {
    Mock FunctionUnderTest {return "fake results"} -parameterFilter {$param1 -eq "badTest"}

    $result=FunctionUnderTest "badTest"

    It "Should return mocked result" {
        $result | Should Be "fake results"
    }
}

Describe "When calling Mock on existing function without matching unbound arguments" {
    Mock FunctionUnderTestWithoutParams {return "fake results"} -parameterFilter {$param1 -eq "test" -and $args[0] -eq 'notArg0'}

    $result=FunctionUnderTestWithoutParams -param1 "test" "arg0"

    It "Should redirect to real function" {
        $result | Should Be "I am a real world test with no params"
    }
}

Describe "When calling Mock on existing function with matching unbound arguments" {
    Mock FunctionUnderTestWithoutParams {return "fake results"} -parameterFilter {$param1 -eq "badTest" -and $args[0] -eq 'arg0'}

    $result=FunctionUnderTestWithoutParams "badTest" "arg0"

    It "Should return mocked result" {
        $result | Should Be "fake results"
    }
}

Describe 'When calling Mock on a function that has no parameters' {
    function Test-Function { }
    Mock Test-Function { return $args.Count }

    It 'Sends the $args variable properly with 2+ elements' {
        Test-Function 1 2 3 4 5 | Should Be 5
    }

    It 'Sends the $args variable properly with 1 element' {
        Test-Function 1 | Should Be 1
    }

    It 'Sends the $args variable properly with 0 elements' {
        Test-Function | Should Be 0
    }
}

Describe "When calling Mock on cmdlet Used by Mock" {
    Mock Set-Item {return "I am not Set-Item"}
    Mock Set-Item {return "I am not Set-Item"}

    $result = Set-Item "mypath" -value "value"

    It "Should Invoke the mocked script" {
        $result | Should Be "I am not Set-Item"
    }
}

Describe "When calling Mock on More than one command" {
    Mock Invoke-Command {return "I am not Invoke-Command"}
    Mock FunctionUnderTest {return "I am the mock test"}

    $result = Invoke-Command {return "yes I am"}
    $result2 = FunctionUnderTest

    It "Should Invoke the mocked script for the first Mock" {
        $result | Should Be "I am not Invoke-Command"
    }
    It "Should Invoke the mocked script for the second Mock" {
        $result2 | Should Be "I am the mock test"
    }
}

Describe 'When calling Mock on a module-internal function.' {
    New-Module -Name TestModule {
        function InternalFunction { 'I am the internal function' }
        function PublicFunction   { InternalFunction }
        function PublicFunctionThatCallsExternalCommand { Start-Sleep 0 }

        function FuncThatOverwritesExecutionContext {
            param ($ExecutionContext)

            InternalFunction
        }

        Export-ModuleMember -Function PublicFunction, PublicFunctionThatCallsExternalCommand, FuncThatOverwritesExecutionContext
    } | Import-Module -Force

    New-Module -Name TestModule2 {
        function InternalFunction { 'I am the second module internal function' }
        function InternalFunction2 { 'I am the second module, second function' }
        function PublicFunction   { InternalFunction }
        function PublicFunction2 { InternalFunction2 }

        function FuncThatOverwritesExecutionContext {
            param ($ExecutionContext)

            InternalFunction
        }

        function ScopeTest {
            return Get-CallerModuleName
        }

        function Get-CallerModuleName {
            [CmdletBinding()]
            param ( )

            return $PSCmdlet.SessionState.Module.Name
        }

        Export-ModuleMember -Function PublicFunction, PublicFunction2, FuncThatOverwritesExecutionContext, ScopeTest
    } | Import-Module -Force

    It 'Should fail to call the internal module function' {
        { TestModule\InternalFunction } | Should Throw
    }

    It 'Should call the actual internal module function from the public function' {
        TestModule\PublicFunction | Should Be 'I am the internal function'
    }

    Context 'Using Mock -ModuleName "ModuleName" "CommandName" syntax' {
        Mock -ModuleName TestModule InternalFunction { 'I am the mock test' }

        It 'Should call the mocked function' {
            TestModule\PublicFunction | Should Be 'I am the mock test'
        }

        Mock -ModuleName TestModule Start-Sleep { }

        It 'Should mock calls to external functions from inside the module' {
            PublicFunctionThatCallsExternalCommand

            Assert-MockCalled -ModuleName TestModule Start-Sleep -Exactly 1
        }

        Mock -ModuleName TestModule2 InternalFunction -ParameterFilter { $args[0] -eq 'Test' } {
            "I'm the mock who's been passed parameter Test"
        }

        It 'Should only call mocks within the same module' {
            TestModule2\PublicFunction | Should Be 'I am the second module internal function'
        }

        Mock -ModuleName TestModule2 InternalFunction2 {
            InternalFunction 'Test'
        }

        It 'Should call mocks from inside another mock' {
            TestModule2\PublicFunction2 | Should Be "I'm the mock who's been passed parameter Test"
        }

        It 'Should work even if the function is weird and steps on the automatic $ExecutionContext variable.' {
            TestModule2\FuncThatOverwritesExecutionContext | Should Be 'I am the second module internal function'
            TestModule\FuncThatOverwritesExecutionContext | Should Be 'I am the mock test'
        }

        Mock -ModuleName TestModule2 Get-CallerModuleName -ParameterFilter { $false }

        It 'Should call the original command from the proper scope if no parameter filters match' {
            TestModule2\ScopeTest | Should Be 'TestModule2'
        }

        Mock -ModuleName TestModule2 Get-Content { }

        It 'Does not trigger the mocked Get-Content from Pester internals' {
            Mock -ModuleName TestModule2 Get-CallerModuleName -ParameterFilter { $false }
            Assert-MockCalled -ModuleName TestModule2 Get-Content -Times 0 -Scope It
        }
    }

    AfterAll {
        Remove-Module TestModule -Force
        Remove-Module TestModule2 -Force
    }
}

Describe "When Applying multiple Mocks on a single command" {
    Mock FunctionUnderTest {return "I am the first mock test"} -parameterFilter {$param1 -eq "one"}
    Mock FunctionUnderTest {return "I am the Second mock test"} -parameterFilter {$param1 -eq "two"}

    $result = FunctionUnderTest "one"
    $result2= FunctionUnderTest "two"

    It "Should Invoke the mocked script for the first Mock" {
        $result | Should Be "I am the first mock test"
    }
    It "Should Invoke the mocked script for the second Mock" {
        $result2 | Should Be "I am the Second mock test"
    }
}

Describe "When Applying multiple Mocks with filters on a single command where both qualify" {
    Mock FunctionUnderTest {return "I am the first mock test"} -parameterFilter {$param1.Length -gt 0 }
    Mock FunctionUnderTest {return "I am the Second mock test"} -parameterFilter {$param1 -gt 1 }

    $result = FunctionUnderTest "one"

    It "The last Mock should win" {
        $result | Should Be "I am the Second mock test"
    }
}

Describe "When Applying multiple Mocks on a single command where one has no filter" {
    Mock FunctionUnderTest {return "I am the first mock test"} -parameterFilter {$param1 -eq "one"}
    Mock FunctionUnderTest {return "I am the paramless mock test"}
    Mock FunctionUnderTest {return "I am the Second mock test"} -parameterFilter {$param1 -eq "two"}

    $result = FunctionUnderTest "one"
    $result2= FunctionUnderTest "three"

    It "The parameterless mock is evaluated last" {
        $result | Should Be "I am the first mock test"
    }

    It "The parameterless mock will be applied if no other wins" {
        $result2 | Should Be "I am the paramless mock test"
    }
}

Describe "When Creating a Verifiable Mock that is not called" {
    Context "In the test script's scope" {
        Mock FunctionUnderTest {return "I am a verifiable test"} -Verifiable -parameterFilter {$param1 -eq "one"}
        FunctionUnderTest "three" | Out-Null

        try {
            Assert-VerifiableMocks
        } Catch {
            $result=$_
        }

        It "Should throw" {
            $result.Exception.Message | Should Be "`r`n Expected FunctionUnderTest to be called with `$param1 -eq `"one`""
        }
    }

    Context "In a module's scope" {
        New-Module -Name TestModule -ScriptBlock {
            function ModuleFunctionUnderTest { return 'I am the function under test in a module' }
        } | Import-Module -Force

        Mock -ModuleName TestModule ModuleFunctionUnderTest {return "I am a verifiable test"} -Verifiable -parameterFilter {$param1 -eq "one"}
        TestModule\ModuleFunctionUnderTest "three" | Out-Null

        try {
            Assert-VerifiableMocks
        } Catch {
            $result=$_
        }

        It "Should throw" {
            $result.Exception.Message | Should Be "`r`n Expected ModuleFunctionUnderTest in module TestModule to be called with `$param1 -eq `"one`""
        }

        AfterAll {
            Remove-Module TestModule -Force
        }
    }
}

Describe "When Creating a Verifiable Mock that is called" {
    Mock FunctionUnderTest -Verifiable -parameterFilter {$param1 -eq "one"}
    FunctionUnderTest "one"
    It "Assert-VerifiableMocks Should not throw" {
        { Assert-VerifiableMocks } | Should Not Throw
    }
}

Describe "When Calling Assert-MockCalled 0 without exactly" {
    Mock FunctionUnderTest {}
    FunctionUnderTest "one"

    try {
        Assert-MockCalled FunctionUnderTest 0
    } Catch {
        $result=$_
    }

    It "Should throw if mock was called" {
        $result.Exception.Message | Should Be "Expected FunctionUnderTest to be called 0 times exactly but was called 1 times"
    }

    It "Should not throw if mock was not called" {
        Assert-MockCalled FunctionUnderTest 0 { $param1 -eq "stupid" }
    }
}

Describe "When Calling Assert-MockCalled with exactly" {
    Mock FunctionUnderTest {}
    FunctionUnderTest "one"
    FunctionUnderTest "one"

    try {
        Assert-MockCalled FunctionUnderTest -exactly 3
    } Catch {
        $result=$_
    }

    It "Should throw if mock was not called the number of times specified" {
        $result.Exception.Message | Should Be "Expected FunctionUnderTest to be called 3 times exactly but was called 2 times"
    }

    It "Should not throw if mock was called the number of times specified" {
        Assert-MockCalled FunctionUnderTest -exactly 2 { $param1 -eq "one" }
    }
}

Describe "When Calling Assert-MockCalled without exactly" {
    Mock FunctionUnderTest {}
    FunctionUnderTest "one"
    FunctionUnderTest "one"
    FunctionUnderTest "two"

    It "Should throw if mock was not called atleast the number of times specified" {
        $scriptBlock = { Assert-MockCalled FunctionUnderTest 4 }
        $scriptBlock | Should Throw "Expected FunctionUnderTest to be called at least 4 times but was called 3 times"
    }

    It "Should not throw if mock was called at least the number of times specified" {
        Assert-MockCalled FunctionUnderTest
    }

    It "Should not throw if mock was called at exactly the number of times specified" {
        Assert-MockCalled FunctionUnderTest 2 { $param1 -eq "one" }
    }

    It "Should throw an error if any non-matching calls to the mock are made, and the -ExclusiveFilter parameter is used" {
        $scriptBlock = { Assert-MockCalled FunctionUnderTest -ExclusiveFilter { $param1 -eq 'one' } }
        $scriptBlock | Should Throw '1 non-matching calls were made'
    }
}

Describe "Using Pester Scopes (Describe,Context,It)" {
    Mock FunctionUnderTest {return "I am the first mock test"} -parameterFilter {$param1 -eq "one"}
    Mock FunctionUnderTest {return "I am the paramless mock test"}

    Context "When in the first context" {
        It "should mock Describe scoped paramles mock" {
            FunctionUnderTest | should be "I am the paramless mock test"
        }
        It "should mock Describe scoped single param mock" {
            FunctionUnderTest "one" | should be "I am the first mock test"
        }
    }

    Context "When in the second context" {
        It "should mock Describe scoped paramles mock again" {
            FunctionUnderTest | should be "I am the paramless mock test"
        }
        It "should mock Describe scoped single param mock again" {
            FunctionUnderTest "one" | should be "I am the first mock test"
        }
    }

    Context "When using mocks in both scopes" {
        Mock FunctionUnderTestWithoutParams {return "I am the other function"}

        It "should mock Describe scoped mock." {
            FunctionUnderTest | should be "I am the paramless mock test"
        }
        It "should mock Context scoped mock." {
            FunctionUnderTestWithoutParams | should be "I am the other function"
        }
    }

    Context "When context hides a describe mock" {
        Mock FunctionUnderTest {return "I am the context mock"}
        Mock FunctionUnderTest {return "I am the parameterized context mock"} -parameterFilter {$param1 -eq "one"}

        It "should use the context paramles mock" {
            FunctionUnderTest | should be "I am the context mock"
        }
        It "should use the context parameterized mock" {
            FunctionUnderTest "one" | should be "I am the parameterized context mock"
        }
    }

    Context "When context no longer hides a describe mock" {
        It "should use the describe mock" {
            FunctionUnderTest | should be "I am the paramless mock test"
        }

        It "should use the describe parameterized mock" {
            FunctionUnderTest "one" | should be "I am the first mock test"
        }
    }

    Context 'When someone calls Mock from inside an It block' {
        Mock FunctionUnderTest { return 'I am the context mock' }

        It 'Sets the mock' {
            Mock FunctionUnderTest { return 'I am the It mock' }
        }

        It 'Leaves the mock active in the parent scope' {
            FunctionUnderTest | Should Be 'I am the It mock'
        }
    }
}

Describe 'Testing mock history behavior from each scope' {
    function MockHistoryChecker { }
    Mock MockHistoryChecker { 'I am the describe mock.' }

    Context 'Without overriding the mock in lower scopes' {
        It "Reports that zero calls have been made to in the describe scope" {
            Assert-MockCalled MockHistoryChecker -Exactly 0 -Scope Describe
        }

        It 'Calls the describe mock' {
            MockHistoryChecker | Should Be 'I am the describe mock.'
        }

        It "Reports that zero calls have been made in an It block, after a context-scoped call" {
            Assert-MockCalled MockHistoryChecker -Exactly 0 -Scope It
        }

        It "Reports one Context-scoped call" {
            Assert-MockCalled MockHistoryChecker -Exactly 1
        }

        It "Reports one Describe-scoped call" {
            Assert-MockCalled MockHistoryChecker -Exactly 1 -Scope Describe
        }
    }

    Context 'After exiting the previous context' {
        It 'Reports zero context-scoped calls in the new context.' {
            Assert-MockCalled MockHistoryChecker -Exactly 0
        }

        It 'Reports one describe-scoped call from the previous context' {
            Assert-MockCalled MockHistoryChecker -Exactly 1 -Scope Describe
        }
    }

    Context 'While overriding mocks in lower scopes' {
        Mock MockHistoryChecker { 'I am the context mock.' }

        It 'Calls the context mock' {
            MockHistoryChecker | Should Be 'I am the context mock.'
        }

        It 'Reports one context-scoped call' {
            Assert-MockCalled MockHistoryChecker -Exactly 1
        }

        It 'Reports two describe-scoped calls, even when one is an override mock in a lower scope' {
            Assert-MockCalled MockHistoryChecker -Exactly 2 -Scope Describe
        }

        It 'Calls an It-scoped mock' {
            Mock MockHistoryChecker { 'I am the It mock.' }
            MockHistoryChecker | Should Be 'I am the It mock.'
        }

        It 'Reports 2 context-scoped calls' {
            Assert-MockCalled MockHistoryChecker -Exactly 2
        }

        It 'Reports 3 describe-scoped calls' {
            Assert-MockCalled MockHistoryChecker -Exactly 3 -Scope Describe
        }
    }

    It 'Reports 3 describe-scoped calls using the default scope in a Describe block' {
        Assert-MockCalled MockHistoryChecker -Exactly 3
    }
}

Describe "Using a single no param Describe" {
    Mock FunctionUnderTest {return "I am the describe mock test"}

    Context "With a context mocking the same function with no params"{
        Mock FunctionUnderTest {return "I am the context mock test"}
        It "Should use the context mock" {
            FunctionUnderTest | should be "I am the context mock test"
        }
    }
}

Describe 'Dot Source Test' {
    # This test is only meaningful if this test file is dot-sourced in the global scope.  If it's executed without
    # dot-sourcing or run by Invoke-Pester, there's no problem.

    function TestFunction { Test-Path -Path 'Test' }
    Mock Test-Path { }

    $null = TestFunction

    It "Calls the mock with parameter 'Test'" {
        Assert-MockCalled Test-Path -Exactly 1 -ParameterFilter { $Path -eq 'Test' }
    }

    It "Doesn't call the mock with any other parameters" {
        InModuleScope Pester {
            $global:calls = $mockTable['||Test-Path'].CallHistory
        }
        Assert-MockCalled Test-Path -Exactly 0 -ParameterFilter { $Path -ne 'Test' }
    }
}

Describe 'Mocking Cmdlets with dynamic parameters' {
    $mockWith = { if (-not $CodeSigningCert) { throw 'CodeSigningCert variable not found, or set to false!' } }
    Mock Get-ChildItem -MockWith $mockWith -ParameterFilter { [bool]$CodeSigningCert }

    It 'Allows calls to be made with dynamic parameters (including parameter filters)' {
        { Get-ChildItem -Path Cert:\ -CodeSigningCert } | Should Not Throw
        Assert-MockCalled Get-ChildItem
    }
}

Describe 'Mocking functions with dynamic parameters' {
    Context 'Dynamicparam block that uses the variables of static parameters in its logic' {
        # Get-Greeting sample function borrowed and modified from Bartek Bielawski's
        # blog at http://becomelotr.wordpress.com/2012/05/10/using-and-abusing-dynamic-parameters/

        function Get-Greeting {
            [CmdletBinding()]
            param (
                [string] $Name
            )

            DynamicParam {
                if ($Name -cmatch '\b[a-z]') {
                    $Attributes = New-Object Management.Automation.ParameterAttribute
                    $Attributes.ParameterSetName = "__AllParameterSets"
                    $Attributes.Mandatory = $false

                    $AttributeCollection = New-Object Collections.ObjectModel.Collection[Attribute]
                    $AttributeCollection.Add($Attributes)

                    $Dynamic = New-Object System.Management.Automation.RuntimeDefinedParameter('Capitalize', [switch], $AttributeCollection)

                    $ParamDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                    $ParamDictionary.Add("Capitalize", $Dynamic)
                    $ParamDictionary
                }
            }

            end
            {
                if($PSBoundParameters.Capitalize) {
                    $Name = [regex]::Replace(
                        $Name,
                        '\b\w',
                        { $args[0].Value.ToUpper() }
                    )
                }

                "Welcome $Name!"
            }
        }

        $mockWith = { if (-not $Capitalize) { throw 'Capitalize variable not found, or set to false!' } }
        Mock Get-Greeting -MockWith $mockWith -ParameterFilter { [bool]$Capitalize }

        It 'Allows calls to be made with dynamic parameters (including parameter filters)' {
            { Get-Greeting -Name lowercase -Capitalize } | Should Not Throw
            Assert-MockCalled Get-Greeting
        }

        $Capitalize = $false

        It 'Sets the dynamic parameter variable properly' {
            { Get-Greeting -Name lowercase -Capitalize } | Should Not Throw
            Assert-MockCalled Get-Greeting -Scope It
        }
    }

    Context 'When the mocked command is in a module' {
        New-Module -Name TestModule {
            function PublicFunction { Get-Greeting -Name lowercase -Capitalize }

            $script:DoDynamicParam = $true

            # Get-Greeting sample function borrowed and modified from Bartek Bielawski's
            # blog at http://becomelotr.wordpress.com/2012/05/10/using-and-abusing-dynamic-parameters/

            function script:Get-Greeting {
                [CmdletBinding()]
                param (
                    [string] $Name
                )

                DynamicParam {
                    # This check is here to make sure the mocked version can still work if the
                    # original function's dynamicparam block relied on script-scope variables.
                    if (-not $script:DoDynamicParam) { return }

                    if ($Name -cmatch '\b[a-z]') {
                        $Attributes = New-Object Management.Automation.ParameterAttribute
                        $Attributes.ParameterSetName = "__AllParameterSets"
                        $Attributes.Mandatory = $false

                        $AttributeCollection = New-Object Collections.ObjectModel.Collection[Attribute]
                        $AttributeCollection.Add($Attributes)

                        $Dynamic = New-Object System.Management.Automation.RuntimeDefinedParameter('Capitalize', [switch], $AttributeCollection)

                        $ParamDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                        $ParamDictionary.Add("Capitalize", $Dynamic)
                        $ParamDictionary
                    }
                }

                end
                {
                    if($PSBoundParameters.Capitalize) {
                        $Name = [regex]::Replace(
                            $Name,
                            '\b\w',
                            { $args[0].Value.ToUpper() }
                        )
                    }

                    "Welcome $Name!"
                }
            }
        } | Import-Module -Force

        $mockWith = { if (-not $Capitalize) { throw 'Capitalize variable not found, or set to false!' } }
        Mock Get-Greeting -MockWith $mockWith -ModuleName TestModule -ParameterFilter { [bool]$Capitalize }

        It 'Allows calls to be made with dynamic parameters (including parameter filters)' {
            { TestModule\PublicFunction } | Should Not Throw
            Assert-MockCalled Get-Greeting -ModuleName TestModule
        }

        AfterAll {
            Remove-Module TestModule -Force
        }
    }

    Context 'When the mocked command has mandatory parameters that are passed in via the pipeline' {
        # Get-Greeting sample function borrowed and modified from Bartek Bielawski's
        # blog at http://becomelotr.wordpress.com/2012/05/10/using-and-abusing-dynamic-parameters/

        function Get-Greeting2 {
            [CmdletBinding()]
            param (
                [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
                [string] $MandatoryParam,

                [string] $Name
            )

            DynamicParam {
                if ($Name -cmatch '\b[a-z]') {
                    $Attributes = New-Object Management.Automation.ParameterAttribute
                    $Attributes.ParameterSetName = "__AllParameterSets"
                    $Attributes.Mandatory = $false

                    $AttributeCollection = New-Object Collections.ObjectModel.Collection[Attribute]
                    $AttributeCollection.Add($Attributes)

                    $Dynamic = New-Object System.Management.Automation.RuntimeDefinedParameter('Capitalize', [switch], $AttributeCollection)

                    $ParamDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                    $ParamDictionary.Add("Capitalize", $Dynamic)
                    $ParamDictionary
                }
            }

            end
            {
                if($PSBoundParameters.Capitalize) {
                    $Name = [regex]::Replace(
                        $Name,
                        '\b\w',
                        { $args[0].Value.ToUpper() }
                    )
                }

                "Welcome $Name!"
            }
        }

        Mock Get-Greeting2 { 'Mocked' } -ParameterFilter { [bool]$Capitalize }
        $hash = @{ Result = $null }
        $scriptBlock = { $hash.Result = 'Mandatory' | Get-Greeting2 -Name test -Capitalize }

        It 'Should successfully call the mock and generate the dynamic parameters' {
            $scriptBlock | Should Not Throw
            $hash.Result | Should Be 'Mocked'
        }
    }

    Context 'When the mocked command has parameter sets that are ambiguous at the time the dynamic param block is executed' {
        # Get-Greeting sample function borrowed and modified from Bartek Bielawski's
        # blog at http://becomelotr.wordpress.com/2012/05/10/using-and-abusing-dynamic-parameters/

        function Get-Greeting3 {
            [CmdletBinding()]
            param (
                [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'One')]
                [string] $One,

                [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'Two')]
                [string] $Two,

                [string] $Name
            )

            DynamicParam {
                if ($Name -cmatch '\b[a-z]') {
                    $Attributes = New-Object Management.Automation.ParameterAttribute
                    $Attributes.ParameterSetName = "__AllParameterSets"
                    $Attributes.Mandatory = $false

                    $AttributeCollection = New-Object Collections.ObjectModel.Collection[Attribute]
                    $AttributeCollection.Add($Attributes)

                    $Dynamic = New-Object System.Management.Automation.RuntimeDefinedParameter('Capitalize', [switch], $AttributeCollection)

                    $ParamDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                    $ParamDictionary.Add("Capitalize", $Dynamic)
                    $ParamDictionary
                }
            }

            end
            {
                if($PSBoundParameters.Capitalize) {
                    $Name = [regex]::Replace(
                        $Name,
                        '\b\w',
                        { $args[0].Value.ToUpper() }
                    )
                }

                "Welcome $Name!"
            }
        }

        Mock Get-Greeting3 { 'Mocked' } -ParameterFilter { [bool]$Capitalize }
        $hash = @{ Result = $null }
        $scriptBlock = { $hash.Result = New-Object psobject -Property @{ One = 'One' } | Get-Greeting3 -Name test -Capitalize }

        It 'Should successfully call the mock and generate the dynamic parameters' {
            $scriptBlock | Should Not Throw
            $hash.Result | Should Be 'Mocked'
        }
    }

    Context 'When the mocked command''s dynamicparam block depends on the contents of $PSBoundParameters' {
        # Get-Greeting sample function borrowed and modified from Bartek Bielawski's
        # blog at http://becomelotr.wordpress.com/2012/05/10/using-and-abusing-dynamic-parameters/

        function Get-Greeting4 {
            [CmdletBinding()]
            param (
                [string] $Name
            )

            DynamicParam {
                if ($PSBoundParameters['Name'] -cmatch '\b[a-z]') {
                    $Attributes = New-Object Management.Automation.ParameterAttribute
                    $Attributes.ParameterSetName = "__AllParameterSets"
                    $Attributes.Mandatory = $false

                    $AttributeCollection = New-Object Collections.ObjectModel.Collection[Attribute]
                    $AttributeCollection.Add($Attributes)

                    $Dynamic = New-Object System.Management.Automation.RuntimeDefinedParameter('Capitalize', [switch], $AttributeCollection)

                    $ParamDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                    $ParamDictionary.Add("Capitalize", $Dynamic)
                    $ParamDictionary
                }
            }

            end
            {
                if($PSBoundParameters.Capitalize) {
                    $Name = [regex]::Replace(
                        $Name,
                        '\b\w',
                        { $args[0].Value.ToUpper() }
                    )
                }

                "Welcome $Name!"
            }
        }

        Mock Get-Greeting4 { 'Mocked' } -ParameterFilter { [bool]$Capitalize }
        $hash = @{ Result = $null }
        $scriptBlock = { $hash.Result = Get-Greeting4 -Name test -Capitalize }

        It 'Should successfully call the mock and generate the dynamic parameters' {
            $scriptBlock | Should Not Throw
            $hash.Result | Should Be 'Mocked'
        }
    }

    Context 'When the mocked command''s dynamicparam block depends on the contents of $PSCmdlet.ParameterSetName' {
        # Get-Greeting sample function borrowed and modified from Bartek Bielawski's
        # blog at http://becomelotr.wordpress.com/2012/05/10/using-and-abusing-dynamic-parameters/

        function Get-Greeting5 {
            [CmdletBinding(DefaultParameterSetName = 'One')]
            param (
                [string] $Name,

                [Parameter(ParameterSetName = 'Two')]
                [string] $Two
            )

            DynamicParam {
                if ($PSCmdlet.ParameterSetName -eq 'Two' -and $Name -cmatch '\b[a-z]') {
                    $Attributes = New-Object Management.Automation.ParameterAttribute
                    $Attributes.ParameterSetName = "__AllParameterSets"
                    $Attributes.Mandatory = $false

                    $AttributeCollection = New-Object Collections.ObjectModel.Collection[Attribute]
                    $AttributeCollection.Add($Attributes)

                    $Dynamic = New-Object System.Management.Automation.RuntimeDefinedParameter('Capitalize', [switch], $AttributeCollection)

                    $ParamDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                    $ParamDictionary.Add("Capitalize", $Dynamic)
                    $ParamDictionary
                }
            }

            end
            {
                if($PSBoundParameters.Capitalize) {
                    $Name = [regex]::Replace(
                        $Name,
                        '\b\w',
                        { $args[0].Value.ToUpper() }
                    )
                }

                "Welcome $Name!"
            }
        }

        Mock Get-Greeting5 { 'Mocked' } -ParameterFilter { [bool]$Capitalize }
        $hash = @{ Result = $null }
        $scriptBlock = { $hash.Result = Get-Greeting5 -Two 'Two' -Name test -Capitalize }

        It 'Should successfully call the mock and generate the dynamic parameters' {
            $scriptBlock | Should Not Throw
            $hash.Result | Should Be 'Mocked'
        }
    }
}

Describe 'Mocking Cmdlets with dynamic parameters in a module' {
    New-Module -Name TestModule {
        function PublicFunction   { Get-ChildItem -Path Cert:\ -CodeSigningCert }
    } | Import-Module -Force

    $mockWith = { if (-not $CodeSigningCert) { throw 'CodeSigningCert variable not found, or set to false!' } }
    Mock Get-ChildItem -MockWith $mockWith -ModuleName TestModule -ParameterFilter { [bool]$CodeSigningCert }

    It 'Allows calls to be made with dynamic parameters (including parameter filters)' {
        { TestModule\PublicFunction } | Should Not Throw
        Assert-MockCalled Get-ChildItem -ModuleName TestModule
    }

    AfterAll {
        Remove-Module TestModule -Force
    }
}

Describe 'DynamicParam blocks in other scopes' {
    New-Module -Name TestModule1 {
        $script:DoDynamicParam = $true

        function DynamicParamFunction {
            [CmdletBinding()]
            param ( )

            DynamicParam {
                if ($script:DoDynamicParam)
                {
                    Get-MockDynamicParameters -CmdletName Get-ChildItem -Parameters @{ Path = [string[]]'Cert:\' }
                }
            }

            end
            {
                'I am the original function'
            }
        }
    } | Import-Module -Force

    New-Module -Name TestModule2 {
        function CallingFunction
        {
            DynamicParamFunction -CodeSigningCert
        }

        function CallingFunction2 {
            [CmdletBinding()]
            param (
                [ValidateScript({ [bool](DynamicParamFunction -CodeSigningCert) })]
                [string]
                $Whatever
            )
        }
    } | Import-Module -Force

    Mock DynamicParamFunction { if ($CodeSigningCert) { 'I am the mocked function' } } -ModuleName TestModule2

    It 'Properly evaluates dynamic parameters when called from another scope' {
        CallingFunction | Should Be 'I am the mocked function'
    }

    It 'Properly evaluates dynamic parameters when called from another scope when the call is from a ValidateScript block' {
        CallingFunction2 -Whatever 'Whatever'
    }

    AfterAll {
        Remove-Module TestModule1 -Force
        Remove-Module TestModule2 -Force
    }
}

Describe 'Parameter Filters and Common Parameters' {
    function Test-Function { [CmdletBinding()] param ( ) }

    Mock Test-Function { } -ParameterFilter { $VerbosePreference -eq 'Continue' }

    It 'Applies common parameters correctly when testing the parameter filter' {
        { Test-Function -Verbose } | Should Not Throw
        Assert-MockCalled Test-Function
        Assert-MockCalled Test-Function -ParameterFilter { $VerbosePreference -eq 'Continue' }
    }
}

Describe "Mocking Get-ItemProperty" {
    Mock Get-ItemProperty { New-Object -typename psobject -property @{ Name = "fakeName" } }
    It "Does not fail with NotImplementedException" {
        Get-ItemProperty -Path "HKLM:\Software\Key\" -Name "Property" | Select -ExpandProperty Name | Should Be fakeName
    }
}

Describe 'When mocking a command with parameters that match internal variable names' {
    function Test-Function
    {
        [CmdletBinding()]
        param (
            [string] $ArgumentList,
            [int] $FunctionName,
            [double] $ModuleName
        )
    }

    Mock Test-Function { return 'Mocked!' }

    It 'Should execute the mocked command successfully' {
        { Test-Function } | Should Not Throw
        Test-Function | Should Be 'Mocked!'
    }
}

Describe 'Mocking commands with potentially ambigious parameter sets' {
    function SomeFunction
    {
        [CmdletBinding()]
        param
        (
            [parameter(ParameterSetName                = 'ps1',
                       ValueFromPipelineByPropertyName = $true)]
            [string]
            $p1,

            [parameter(ParameterSetName                = 'ps2',
                       ValueFromPipelineByPropertyName = $true)]
            [string]
            $p2
        )
        process
        {
            return $true
        }
    }

    Mock SomeFunction { }

    It 'Should call the function successfully, even with delayed parameter binding' {
        $object = New-Object psobject -Property @{ p1 = 'Whatever' }
        { $object | SomeFunction } | Should Not Throw
        Assert-MockCalled SomeFunction -ParameterFilter { $p1 -eq 'Whatever' }
    }
}

Describe 'When mocking a command that has an ArgumentList parameter with validation' {
    Mock Start-Process { return 'mocked' }

    It 'Calls the mock properly' {
        $hash = @{ Result = $null }
        $scriptBlock = { $hash.Result = Start-Process -FilePath cmd.exe -ArgumentList '/c dir c:\' }

        $scriptBlock | Should Not Throw
        $hash.Result | Should Be 'mocked'
    }
}

# These assertions won't actually "fail"; we had an infinite recursion bug in Get-DynamicParametersForCmdlet
# if the caller mocked New-Object.  It should be fixed by making that call to New-Object module-qualified,
# and this test will make sure it's working properly.  If this test fails, it'll take a really long time
# to execute, and then will throw a stack overflow error.

Describe 'Mocking New-Object' {
    It 'Works properly' {
        Mock New-Object

        $result = New-Object -TypeName Object
        $result | Should Be $null
        Assert-MockCalled New-Object
    }
}

Describe 'Mocking a function taking input from pipeline' {
    $psobj = New-Object -TypeName psobject -Property @{'PipeIntProp'='1';'PipeArrayProp'=1;'PipeStringProp'=1}
    $psArrayobj = New-Object -TypeName psobject -Property @{'PipeArrayProp'=@(1)}
    $noMockArrayResult = @(1,2) | PipelineInputFunction
    $noMockIntResult = 1 | PipelineInputFunction
    $noMockStringResult = '1' | PipelineInputFunction
    $noMockResultByProperty = $psobj | PipelineInputFunction -PipeStr 'val'
    $noMockArrayResultByProperty = $psArrayobj | PipelineInputFunction -PipeStr 'val'

    Mock PipelineInputFunction { write-output 'mocked' } -ParameterFilter { $PipeStr -eq 'blah' }

    context 'when calling original function with an array' {
        $result = @(1,2) | PipelineInputFunction
        it 'Returns actual implementation' {
            $result[0].keys | % {
                $result[0][$_] | Should Be $noMockArrayResult[0][$_]
                $result[1][$_] | Should Be $noMockArrayResult[1][$_]
            }
        }
    }

    context 'when calling original function with an int' {
        $result = 1 | PipelineInputFunction
        it 'Returns actual implementation' {
            $result.keys | % {
                $result[$_] | Should Be $noMockIntResult[$_]
            }
        }
    }

    context 'when calling original function with a string' {
        $result = '1' | PipelineInputFunction
        it 'Returns actual implementation' {
            $result.keys | % {
                $result[$_] | Should Be $noMockStringResult[$_]
            }
        }
    }

    context 'when calling original function and pipeline is bound by property name' {
        $result = $psobj | PipelineInputFunction -PipeStr 'val'
        it 'Returns actual implementation' {
            $result.keys | % {
                $result[$_] | Should Be $noMockResultByProperty[$_]
            }
        }
    }

    context 'when calling original function and forcing a parameter binding exception' {
        Mock PipelineInputFunction {
            if($MyInvocation.ExpectingInput) {
                throw New-Object -TypeName System.Management.Automation.ParameterBindingException
            }
            write-output $MyInvocation.ExpectingInput
        }
        $result = $psobj | PipelineInputFunction

        it 'falls back to no pipeline input' {
            $result | Should Be $false
        }
    }

    context 'when calling original function and pipeline is bound by property name with array values' {
        $result = $psArrayobj | PipelineInputFunction -PipeStr 'val'
        it 'Returns actual implementation' {
            $result.keys | % {
                $result[$_] | Should Be $noMockArrayResultByProperty[$_]
            }
        }
    }

    context 'when calling the mocked function' {
        $result = 'blah' | PipelineInputFunction
        it 'Returns mocked implementation' {
            $result | Should Be 'mocked'
        }
    }
}

Describe 'Mocking module-qualified calls' {
    It 'Mock alias should not exist before the mock is defined' {
        $alias = Get-Alias -Name 'Microsoft.PowerShell.Management\Get-Content' -ErrorAction SilentlyContinue
        $alias | Should Be $null
    }

    $mockFile = 'TestDrive:\TestFile'
    $mockResult = 'Mocked'

    Mock Get-Content { return $mockResult } -ParameterFilter { $Path -eq $mockFile }
    Setup -File TestFile -Content 'The actual file'

    It 'Creates the alias while the mock is in effect' {
        $alias = Get-Alias -Name 'Microsoft.PowerShell.Management\Get-Content' -ErrorAction SilentlyContinue
        $alias | Should Not Be $null
    }

    It 'Calls the mock properly even if the call is module-qualified' {
        $result = Microsoft.PowerShell.Management\Get-Content -Path $mockFile
        $result | Should Be $mockResult
    }
}

Describe 'After a mock goes out of scope' {
    It 'Removes the alias after the mock goes out of scope' {
        $alias = Get-Alias -Name 'Microsoft.PowerShell.Management\Get-Content' -ErrorAction SilentlyContinue
        $alias | Should Be $null
    }
}

Describe 'Assert-MockCalled with Aliases' {
    AfterEach {
        if (Test-Path alias:PesterTF) { Remove-Item Alias:PesterTF }
    }

    It 'Allows calls to Assert-MockCalled to use both aliases and the original command name' {
        function TestFunction { }
        Set-Alias -Name PesterTF -Value TestFunction
        Mock PesterTF
        $null = PesterTF

        { Assert-MockCalled PesterTF } | Should Not Throw
        { Assert-MockCalled TestFunction } | Should Not Throw
    }
}

Describe 'Mocking Get-Command' {
    # This was reported as a bug in 3.3.12; we were relying on Get-Command to safely invoke other commands.
    # Mocking Get-Command, though, would result in infinite recursion.

    It 'Does not break when Get-Command is mocked' {
        { Mock Get-Command } | Should Not Throw
    }
}

Describe 'Mocks with closures' {
    $closureVariable = 'from closure'
    $scriptBlock = { "Variable resolved $closureVariable" }
    $closure = $scriptBlock.GetNewClosure()
    $closureVariable = 'from script'

    function TestClosure([switch] $Closure) { 'Not mocked' }

    Mock TestClosure $closure -ParameterFilter { $Closure }
    Mock TestClosure $scriptBlock

    It 'Resolves variables in the closure rather than Pester''s current scope' {
        TestClosure | Should Be 'Variable resolved from script'
        TestClosure -Closure | Should Be 'Variable resolved from closure'
    }
}

Describe '$args handling' {

    function AdvancedFunction {
        [CmdletBinding()]
        param()
        'orig'
    }
    function SimpleFunction {
        . AdvancedFunction
    }
    function AdvancedFunctionWithArgs {
        [CmdletBinding()]
        param($Args)
        'orig'
    }
    Add-Type -TypeDefinition '
        using System.Management.Automation;
        [Cmdlet(VerbsLifecycle.Invoke, "CmdletWithArgs")]
        public class InvokeCmdletWithArgs : Cmdlet {
            public InvokeCmdletWithArgs() { }
            [Parameter]
            public object Args {
                set { }
            }
            protected override void EndProcessing() {
                WriteObject("orig");
            }
        }
    ' -PassThru | Select-Object -ExpandProperty Assembly | Import-Module

    Mock AdvancedFunction { 'mock' }
    Mock AdvancedFunctionWithArgs { 'mock' }
    Mock Invoke-CmdletWithArgs { 'mock' }

    It 'Advanced function mock should be callable with dot operator' {
        SimpleFunction garbage | Should Be mock
    }
    It 'Advanced function with Args parameter should be mockable' {
        AdvancedFunctionWithArgs -Args garbage | Should Be mock
    }
    It 'Cmdlet with Args parameter should be mockable' {
        Invoke-CmdletWithArgs -Args garbage | Should Be mock
    }

}

Describe 'Single quote in command/module name' {
    BeforeAll {
        $module = New-Module "Module '‘’‚‛" {
            Function NormalCommandName { 'orig' }
            New-Item "Function::Command '‘’‚‛" -Value { 'orig' }
        } | Import-Module -PassThru
    }

    AfterAll {
        if ($module) { Remove-Module $module; $module = $null }
    }

    It 'Command with single quote in module name should be mockable' {
        Mock NormalCommandName { 'mock' }
        NormalCommandName | Should Be mock
    }
    It 'Command with single quote in name should be mockable' {
        Mock "Command '‘’‚‛" { 'mock' }
        & "Command '‘’‚‛" | Should Be mock
    }

}

if ($global:PSVersionTable.PSVersion.Major -ge 3) {
    Describe 'Mocking cmdlet without positional parameters' {

        Add-Type -TypeDefinition '
            using System.Management.Automation;
            [Cmdlet(VerbsLifecycle.Invoke, "CmdletWithoutPositionalParameters")]
            public class InvokeCmdletWithoutPositionalParameters : Cmdlet {
                public InvokeCmdletWithoutPositionalParameters() { }
                [Parameter]
                public object Parameter {
                    set { }
                }
            }
            [Cmdlet(VerbsLifecycle.Invoke, "CmdletWithValueFromRemainingArguments")]
            public class InvokeCmdletWithValueFromRemainingArguments : Cmdlet {
                private string parameter;
                private string[] remainings;
                public InvokeCmdletWithValueFromRemainingArguments() { }
                [Parameter]
                public string Parameter {
                    set {
                        parameter=value;
                    }
                }
                [Parameter(ValueFromRemainingArguments=true)]
                public string[] Remainings {
                    set {
                        remainings=value;
                    }
                }
                protected override void EndProcessing() {
                    WriteObject(string.Concat(parameter, "; ", string.Join(", ", remainings)));
                }
            }
        ' -PassThru | Select-Object -First 1 -ExpandProperty Assembly | Import-Module

        It 'Original cmdlet does not have positional parameters' {
            { Invoke-CmdletWithoutPositionalParameters garbage } | Should Throw
        }
        Mock Invoke-CmdletWithoutPositionalParameters
        It 'Mock of cmdlet should not make parameters to be positional' {
            { Invoke-CmdletWithoutPositionalParameters garbage } | Should Throw
        }

        It 'Original cmdlet bind all to Remainings' {
            Invoke-CmdletWithValueFromRemainingArguments asd fgh jkl | Should Be '; asd, fgh, jkl'
        }
        Mock Invoke-CmdletWithValueFromRemainingArguments { -join ($Parameter, '; ', ($Remainings -join ', ')) }
        It 'Mock of cmdlet should bind all to Remainings' {
            Invoke-CmdletWithValueFromRemainingArguments asd fgh jkl | Should Be '; asd, fgh, jkl'
        }

    }
}

Describe 'Nested Mock calls' {
    $testDate = New-Object DateTime(2012,6,13)

    Mock Get-Date -ParameterFilter { $null -eq $Date } {
        Get-Date -Date $testDate -Format o
    }

    It 'Properly handles nested mocks' {
        $result = @(Get-Date)
        $result.Count | Should Be 1
        $result[0] | Should Be '2012-06-13T00:00:00.0000000'
    }
}

# SIG # Begin signature block
# MIIncAYJKoZIhvcNAQcCoIInYTCCJ10CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAkpc/exW5Mgzst
# vtrs/3BxZAzjbOAHK7Tw8WBQzKoGh6CCC8MwggXaMIIEwqADAgECAhMzAAABP8rF
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
# 8f7BcdpMoEFagt3xHzGCGwMwghr/AgEBMIGmMIGOMQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMTgwNgYDVQQDEy9NaWNyb3NvZnQgV2luZG93cyBU
# aGlyZCBQYXJ0eSBDb21wb25lbnQgQ0EgMjAxMgITMwAAAT/KxSgZC4k1WAAAAAAB
# PzANBglghkgBZQMEAgEFAKCB+jAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAv
# BgkqhkiG9w0BCQQxIgQgknjmSivrcMyLv8AWmBmpW480WR9T0ThSbYWP5nSGaKow
# UAYKKwYBBAGCNwoDHDFCDEA1MDZBRkE2NzQxM0I3RUE2MTI2NTQzM0JBNTEzNzBD
# RTkyRTM1QjIzRjVFQjdGOUE1RUVEQUJGODNBREJCQTQ1MFoGCisGAQQBgjcCAQwx
# TDBKoCSAIgBNAGkAYwByAG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggGA
# w1Bw56XFj6Vvx7VPRkZELxlwxZk9b+EuUN/hvpD48MFMRgOx0aNh5ZHBddXusgVp
# 1hk05B9JcbHqdIV0MaO92UzGEUM4tRfIHM94W8RRYYnFGXWBsJTJtA8jgSSaFX/b
# +Rajg9YSo3xObEBtAinzX2lioI+z8uz3tyiaobQR40GvufKITRI4EgKUKRqiXKmX
# oEUjXyLIu9RSF2dd6Gaf+wv324JJJgBK6FV81fmCQzA/OALr9hsCECNy8cpQkSdh
# FQzSjRSkyeM9WxddrPpvTy5v4MMLuUUKl8e9DVVVCnxAPcNARrjt2CnOL3VUo0+Q
# k0hQhuu2k1kISN8TqXPNOHxAObZ7TIQZw53vA7hJXHiKgV5J8xvEKK1bSgMP6Fid
# gXNR3sIGyCj4zK15h75IOhGUQI3YEGS5D00H/ZeQszLkPtfeHDEVusXv5cJG4H9y
# ZT2CNxBWjqQQUqyvPIP60d5IaqTWbn5oLLZ38Vt6d6SyGsYVOauDZ3EjOu4lqv47
# oYIXsDCCF6wGCisGAQQBgjcDAwExghecMIIXmAYJKoZIhvcNAQcCoIIXiTCCF4UC
# AQMxDzANBglghkgBZQMEAgEFADCCAVoGCyqGSIb3DQEJEAEEoIIBSQSCAUUwggFB
# AgEBBgorBgEEAYRZCgMBMDEwDQYJYIZIAWUDBAIBBQAEIFdXEAnHZ/Fqm28dHyDF
# g7njA02/HWmdgLOAhz3En01uAgZqrW52WMoYEzIwMjYxMDEwMDgzNjM1LjA5NFow
# BIACAfSggdmkgdYwgdMxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRl
# ZDEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjM2MDUtMDVFMC1EOTQ3MSUwIwYD
# VQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloIIR/jCCBygwggUQoAMC
# AQICEzMAAAITsEM1Zs+vlegAAQAAAhMwDQYJKoZIhvcNAQELBQAwfDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcNMjUwODE0MTg0ODE3WhcNMjYxMTEzMTg0
# ODE3WjCB0zELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEtMCsG
# A1UECxMkTWljcm9zb2Z0IElyZWxhbmQgT3BlcmF0aW9ucyBMaW1pdGVkMScwJQYD
# VQQLEx5uU2hpZWxkIFRTUyBFU046MzYwNS0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1p
# Y3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUAA4IC
# DwAwggIKAoICAQD0mXrguhnEMg1IWDP70pLk7O/mbnjx49XNz1FdZ7hPj8ymV+Br
# h6rXZEZ2nlxW+eN17m/F+rZrH+Oe7u9Rbitk3iY5Sbm+H6RxixCVhDncXCAgHecS
# NxAeiasbeZl7+jOMVICvoluCUq0h4DJI/MBwXPIB6vmUs1QcES9AwzwE6MzJqkK+
# HTGyDjEoVxUQlAsoR8IYF98xkj9qa60cVvcJRNntpWkbYocQVQ2VnW/Awq/FdM9E
# OdvA8bPLKoknOd+ws0dDi9e3a21LU94KgYjSE3U96rzIawhcz2ihzALToMY1Iz/g
# sDHa4q/CZSfo3AtzT62a+fLrDbytkt6OyRF+dVah8S/WZZjSMdScevBIYFLyBU/2
# BwGzo/mDQ6kk8x/F1SQddGRww89bSEg/w1tbxblK6nwe7CdIpuOnICUYFR0z9Xmt
# lvSxmaSfvXivpQsYr5wssA3pHcWFfo3SePrgXbstMrYFtLSkllpeOjR4M3PVBzF4
# gUtSAX5EGwtgOfwTxwKR7Erw2W3caL3Ml/nnDpR9Nn6TBMzEyoXGHv5N/Hv5oE5t
# n6fH3rUC2KoDLvNVXr2j8tZF0o9l29mf0RLIZtOc9+OQERG/bamtKUROVHDM/puY
# RU4pYtZXDG7CHttRZS5RvVyP3fO+21BgZBq3kT0Assk2aW8soKyQHutouwIDAQAB
# o4IBSTCCAUUwHQYDVR0OBBYEFBOeEErH4WvKmFBYxGKkfj2wwUA6MB8GA1UdIwQY
# MBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRpbWUt
# U3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYIKwYB
# BQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWlj
# cm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1UdEwEB
# /wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeAMA0G
# CSqGSIb3DQEBCwUAA4ICAQCCbFomsapDYPpQmFnpCXZJkU5o24ZtbcvMH4RL6XYE
# HUwm0FFIV2L+FVjfc2nGwlCFDlMtWnQNdg6Qig9BzXusf4hWF6Y7yMK35TojVMjD
# pxHtz60Sj8mOnoSoRTVzj+atoyOAeFD6toL85QCb3wDWvhsg8e2wGYtE4aZ4Tlcs
# gVoEhlYe+HYI5chMo5tdV3nAa0nV1ll3BocAJcXnTqO1r66hR3LMB642VM8tOtny
# fKHEbCT1WHp6INDsJAxZJJrwMlL09ReN6iL29N1Ltkxeq762/pDPfG2gEXn5gUri
# 4T6aIaz3QXGbRUraVauYWGORGXnPKgc53Abuyk1iQOiYI81Yi51RCZBgqm38eyyl
# 9xv7GmdYgNB0zOATymPW+nAuBYScfsu1Ph1kJ6gOj08rjRHEEPyQonvr2eCQTB/A
# IPYRf8xCTv14i86GmcfXYa5UHK9opmTldm+q08403Cvyr+oDfzvsi5bBaCdp5f6m
# unDR1n9Au1sYZWuA/5NFCO37Z1xkDk/dfgvAA2GI+zLQ6XhcJ2Ps7EEsW87OwI8M
# 9pWeSn518MUb404GKvtqpMnrzrbanKaDVX7qBz/VG/EL/CC9jIbTfd5wmq/Q6fRl
# E1iv6L86TCADcc/VosPRoesSnDqW3TbreJGQK+tx1w5bzDeMLxMm5oZbILZL2MSP
# ODCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZIhvcNAQEL
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
# 0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggNZMIICQQIB
# ATCCAQGhgdmkgdYwgdMxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRl
# ZDEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjM2MDUtMDVFMC1EOTQ3MSUwIwYD
# VQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoD
# FQCYETxIKPGCNpybLz9UR2Ts3GlHpqCBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA7nRC2DAiGA8yMDI2MTAxMDA0
# NTEzNloYDzIwMjYxMDExMDQ1MTM2WjB3MD0GCisGAQQBhFkKBAExLzAtMAoCBQDu
# dELYAgEAMAoCAQACAh17AgH/MAcCAQACAhJRMAoCBQDudZRYAgEAMDYGCisGAQQB
# hFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAw
# DQYJKoZIhvcNAQELBQADggEBAAk6Bjt5gzErhJRfq7c4Ud/scwiiIq0YWvZqmm9D
# C8tOqYJ+n9PxQtKk/st3D/OzOK7TbI7yYDQKRjX/NoFM5apt61a8uPuRNC0I5bcz
# c1m6kV45ZyMbBsunN1UeVSx7oet4IvfOQT2rEjciTkdPug/mMzYiV2rk7XE0wT6g
# r293qetHbGHddM5stEJnuxVVBElCVDpj4x8srgzq461o0/1lXYNoShdJ8aFmbQlp
# FdYo+QNmkkWv5g4WI0YhL4GvDnz2vo8bG6NSC+Sts4+ASOmbqJ7wZtG4tOWbzeFF
# QiFWO8LnVFg4hEtVGi3vobiKhsxWZSJ5+0aasNqDIQma4YUxggQNMIIECQIBATCB
# kzB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAhOwQzVmz6+V6AAB
# AAACEzANBglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJ
# EAEEMC8GCSqGSIb3DQEJBDEiBCChJ5LN77aj4F9y1JcxnMNihfEqAyO8N8XPHG5H
# KI+T/TCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIMzhCW0UhTPwngOMDM/i
# dWh1m9DFgaV5Qh+nzo5rnFhoMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAg
# UENBIDIwMTACEzMAAAITsEM1Zs+vlegAAQAAAhMwIgQg6pWICIISnAsOeXzJVxfs
# 8IqfscYXqPNNcybNi2G36xIwDQYJKoZIhvcNAQELBQAEggIAE4wYsHDb9qITQkNz
# VF3vh2k5zu/7D5NHp04gz7q+8WpczRgs59JjoSdokzR9WqY+EsvKVfHj6jRGSBHY
# wuFkIt5AZYAFgl9GNeswxuYDq5fqMeQ7ycZhL9tcKI7wCCInIGLJATQ5KyLb4zmG
# jV06H09QdAq7UZyI8pnUX0wSO/RVfd+SOH968SoLQ1JDRh8OP2en7rSHKvtaePzZ
# JGM6/KVz3srNeNtKzc3JAvRYyRHaARHAdY2/Rb/JdhNNDRpGZ2FQFWB8vDP1aYZw
# Yu5TPZ+oD2/eyb8lUFEmoGpK1vCpg6nnVwURM70VoIhDjBBAXeqBNuR3h70L45iq
# 5XewuYB4rzUG+7gC8OIu0vWFXnqUv5Jmopj5u45HFY9RCoeWIVf8/ixah2KOjGO2
# Iy8i8fnMwpFVZi5QUNA/RBusNw20ElLYvNpyMj0a0/lFYaBy0fJngoNJBhCqmI/h
# zqu8sjQALsSwTZGTQGDf4CQgF9WEaWLYjvkFwUSeVdhO//z892HuFMjJaXdN6Z0g
# N1TAydtTqEdwQu/YKJukIUmxCssWdxYAyxlenhJc0DJmVeGeJS9Mz6B708kUygaj
# gX6gcHuL0A1aGhw8ehmzb78A46tZwcvIBA28HFYnSsvqoEijRjKJt84RSd/bXDf/
# CRYxO/iSR4CBB5LoBZGd3oEkEUg=
# SIG # End signature block
