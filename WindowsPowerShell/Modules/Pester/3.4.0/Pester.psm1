# Pester
# Version: $version$
# Changeset: $sha$

if ($PSVersionTable.PSVersion.Major -ge 3)
{
    $script:IgnoreErrorPreference = 'Ignore'
    $outNullModule = 'Microsoft.PowerShell.Core'
}
else
{
    $script:IgnoreErrorPreference = 'SilentlyContinue'
    $outNullModule = 'Microsoft.PowerShell.Utility'
}

# Tried using $ExecutionState.InvokeCommand.GetCmdlet() here, but it does not trigger module auto-loading the way
# Get-Command does.  Since this is at import time, before any mocks have been defined, that's probably acceptable.
# If someone monkeys with Get-Command before they import Pester, they may break something.

$script:SafeCommands = @{
    'Add-Member'          = Get-Command -Name Add-Member          -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Add-Type'            = Get-Command -Name Add-Type            -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Compare-Object'      = Get-Command -Name Compare-Object      -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Export-ModuleMember' = Get-Command -Name Export-ModuleMember -Module Microsoft.PowerShell.Core       -CommandType Cmdlet -ErrorAction Stop
    'ForEach-Object'      = Get-Command -Name ForEach-Object      -Module Microsoft.PowerShell.Core       -CommandType Cmdlet -ErrorAction Stop
    'Format-Table'        = Get-Command -Name Format-Table        -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Get-ChildItem'       = Get-Command -Name Get-ChildItem       -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Get-Command'         = Get-Command -Name Get-Command         -Module Microsoft.PowerShell.Core       -CommandType Cmdlet -ErrorAction Stop
    'Get-Content'         = Get-Command -Name Get-Content         -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Get-Date'            = Get-Command -Name Get-Date            -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Get-Item'            = Get-Command -Name Get-Item            -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Get-Location'        = Get-Command -Name Get-Location        -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Get-Member'          = Get-Command -Name Get-Member          -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Get-Module'          = Get-Command -Name Get-Module          -Module Microsoft.PowerShell.Core       -CommandType Cmdlet -ErrorAction Stop
    'Get-PSDrive'         = Get-Command -Name Get-PSDrive         -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Get-Variable'        = Get-Command -Name Get-Variable        -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Group-Object'        = Get-Command -Name Group-Object        -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Join-Path'           = Get-Command -Name Join-Path           -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Measure-Object'      = Get-Command -Name Measure-Object      -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'New-Item'            = Get-Command -Name New-Item            -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'New-Module'          = Get-Command -Name New-Module          -Module Microsoft.PowerShell.Core       -CommandType Cmdlet -ErrorAction Stop
    'New-Object'          = Get-Command -Name New-Object          -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'New-PSDrive'         = Get-Command -Name New-PSDrive         -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'New-Variable'        = Get-Command -Name New-Variable        -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Out-Null'            = Get-Command -Name Out-Null            -Module $outNullModule                  -CommandType Cmdlet -ErrorAction Stop
    'Out-String'          = Get-Command -Name Out-String          -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Pop-Location'        = Get-Command -Name Pop-Location        -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Push-Location'       = Get-Command -Name Push-Location       -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Remove-Item'         = Get-Command -Name Remove-Item         -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Remove-PSBreakpoint' = Get-Command -Name Remove-PSBreakpoint -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Remove-PSDrive'      = Get-Command -Name Remove-PSDrive      -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Remove-Variable'     = Get-Command -Name Remove-Variable     -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Resolve-Path'        = Get-Command -Name Resolve-Path        -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Select-Object'       = Get-Command -Name Select-Object       -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Set-Content'         = Get-Command -Name Set-Content         -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Set-PSBreakpoint'    = Get-Command -Name Set-PSBreakpoint    -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Set-StrictMode'      = Get-Command -Name Set-StrictMode      -Module Microsoft.PowerShell.Core       -CommandType Cmdlet -ErrorAction Stop
    'Set-Variable'        = Get-Command -Name Set-Variable        -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Sort-Object'         = Get-Command -Name Sort-Object         -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Split-Path'          = Get-Command -Name Split-Path          -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Start-Sleep'         = Get-Command -Name Start-Sleep         -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Test-Path'           = Get-Command -Name Test-Path           -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop
    'Where-Object'        = Get-Command -Name Where-Object        -Module Microsoft.PowerShell.Core       -CommandType Cmdlet -ErrorAction Stop
    'Write-Error'         = Get-Command -Name Write-Error         -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Write-Progress'      = Get-Command -Name Write-Progress      -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Write-Verbose'       = Get-Command -Name Write-Verbose       -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
    'Write-Warning'       = Get-Command -Name Write-Warning       -Module Microsoft.PowerShell.Utility    -CommandType Cmdlet -ErrorAction Stop
}

 
# Not all platforms have Get-WmiObject (Nano) 
# Get-CimInstance is prefered, but we can use Get-WmiObject if it exists 
# Moreover, it shouldn't really be fatal if neither of those cmdlets 
# exist
if ( Get-Command -ea SilentlyContinue Get-CimInstance ) 
{ 
    $script:SafeCommands['Get-CimInstance'] = Get-Command -Name Get-CimInstance -Module CimCmdlets -CommandType Cmdlet -ErrorAction Stop 
} 
elseif ( Get-command -ea SilentlyContinue Get-WmiObject ) 
{ 
    $script:SafeCommands['Get-WmiObject']   = Get-Command -Name Get-WmiObject   -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Stop 
} 
else 
{ 
    Write-Warning "OS Information retrieval is not possible, reports will contain only partial system data" 
} 


# little sanity check to make sure we don't blow up a system with a typo up there
# (not that I've EVER done that by, for example, mapping New-Item to Remove-Item...)

foreach ($keyValuePair in $script:SafeCommands.GetEnumerator())
{
    if ($keyValuePair.Key -ne $keyValuePair.Value.Name)
    {
        throw "SafeCommands entry for $($keyValuePair.Key) does not hold a reference to the proper command."
    }
}

$moduleRoot = & $script:SafeCommands['Split-Path'] -Path $MyInvocation.MyCommand.Path

"$moduleRoot\Functions\*.ps1", "$moduleRoot\Functions\Assertions\*.ps1" |
& $script:SafeCommands['Resolve-Path'] |
& $script:SafeCommands['Where-Object'] { -not ($_.ProviderPath.ToLower().Contains(".tests.")) } |
& $script:SafeCommands['ForEach-Object'] { . $_.ProviderPath }

function Invoke-Pester {
<#
.SYNOPSIS
Invokes Pester to run all tests (files containing *.Tests.ps1) recursively under the Path

.DESCRIPTION
Upon calling Invoke-Pester, all files that have a name containing
"*.Tests.ps1" will have the tests defined in their Describe blocks
executed. Invoke-Pester begins at the location of Path and
runs recursively through each sub directory looking for
"*.Tests.ps1" files containing tests. If a TestName is provided,
Invoke-Pester will only run tests that have a describe block with a
matching name. By default, Invoke-Pester will end the test run with a
simple report of the number of tests passed and failed output to the
console. One may want pester to "fail a build" in the event that any
tests fail. To accomodate this, Invoke-Pester will return an exit
code equal to the number of failed tests if the EnableExit switch is
set. Invoke-Pester will also write a NUnit style log of test results
if the OutputXml parameter is provided. In these cases, Invoke-Pester
will write the result log to the path provided in the OutputXml
parameter.

Optionally, Pester can generate a report of how much code is covered
by the tests, and information about any commands which were not
executed.

.PARAMETER Script
This parameter indicates which test scripts should be run.
This parameter may be passed simple strings (wildcards are allowed), or hashtables containing Path, Arguments and Parameters keys.
If hashtables are used, the Parameters key must refer to a hashtable, and the Arguments key must refer to an array; these will be splatted to the test script(s) indicated in the Path key.

Note:  If the path contains any wildcards, or if it refers to a directory, then Pester will search for and execute all test scripts named *.Tests.ps1 in the target path; the search is recursive.  If the path contains no wildcards and refers to a file, Pester will just try to execute that file regardless of its name.

Aliased to 'Path' and 'relative_path' for backwards compatibility.

.PARAMETER TestName
Informs Invoke-Pester to only run Describe blocks that match this name.

.PARAMETER EnableExit
Will cause Invoke-Pester to exit with a exit code equal to the number of failed tests once all tests have been run. Use this to "fail" a build when any tests fail.

.PARAMETER OutputXml
The path where Invoke-Pester will save a NUnit formatted test results log file. If this path is not provided, no log will be generated.

.PARAMETER Tag
Informs Invoke-Pester to only run Describe blocks tagged with the tags specified. Aliased 'Tags' for backwards compatibility.

.PARAMETER ExcludeTag
Informs Invoke-Pester to not run blocks tagged with the tags specified.

.PARAMETER PassThru
Returns a Pester result object containing the information about the whole test run, and each test.

.PARAMETER CodeCoverage
Instructs Pester to generate a code coverage report in addition to running tests.  You may pass either hashtables or strings to this parameter.
If strings are used, they must be paths (wildcards allowed) to source files, and all commands in the files are analyzed for code coverage.
By passing hashtables instead, you can limit the analysis to specific lines or functions within a file.
Hashtables must contain a Path key (which can be abbreviated to just "P"), and may contain Function (or "F"), StartLine (or "S"), and EndLine ("E") keys to narrow down the commands to be analyzed.
If Function is specified, StartLine and EndLine are ignored.
If only StartLine is defined, the entire script file starting with StartLine is analyzed.
If only EndLine is present, all lines in the script file up to and including EndLine are analyzed.
Both Function and Path (as well as simple strings passed instead of hashtables) may contain wildcards.

.PARAMETER Strict
Makes Pending and Skipped tests to Failed tests. Useful for continuous integration where you need to make sure all tests passed.

.PARAMETER Quiet
Disables the output Pester writes to screen. No other output is generated unless you specify PassThru, or one of the Output parameters.

.PARAMETER PesterOption
Sets advanced options for the test execution. Enter a PesterOption object, such as one that you create by using the New-PesterOption cmdlet, or a hash table in which the keys are option names and the values are option values.
For more information on the options available, see the help for New-PesterOption.

.Example
Invoke-Pester

This will find all *.Tests.ps1 files and run their tests. No exit code will be returned and no log file will be saved.

.Example
Invoke-Pester -Script ./tests/Utils*

This will run all tests in files under ./Tests that begin with Utils and alsocontains .Tests.

.Example
Invoke-Pester -Script @{ Path = './tests/Utils*'; Parameters = @{ NamedParameter = 'Passed By Name' }; Arguments = @('Passed by position') }

Executes the same tests as in Example 1, but will run them with the equivalent of the following command line:  & $testScriptPath -NamedParameter 'Passed By Name' 'Passed by position'

.Example
Invoke-Pester -TestName "Add Numbers"

This will only run the Describe block named "Add Numbers"

.Example
Invoke-Pester -EnableExit -OutputXml "./artifacts/TestResults.xml"

This runs all tests from the current directory downwards and writes the results according to the NUnit schema to artifacts/TestResults.xml just below the current directory. The test run will return an exit code equal to the number of test failures.

.Example
Invoke-Pester -EnableExit -OutputFile "./artifacts/TestResults.xml" -OutputFormat NUnitxml

This runs all tests from the current directory downwards and writes the results to an output file and NUnitxml output format

.EXAMPLE
Invoke-Pester -CodeCoverage 'ScriptUnderTest.ps1'

Runs all *.Tests.ps1 scripts in the current directory, and generates a coverage report for all commands in the "ScriptUnderTest.ps1" file.

.EXAMPLE
Invoke-Pester -CodeCoverage @{ Path = 'ScriptUnderTest.ps1'; Function = 'FunctionUnderTest' }

Runs all *.Tests.ps1 scripts in the current directory, and generates a coverage report for all commands in the "FunctionUnderTest" function in the "ScriptUnderTest.ps1" file.

.EXAMPLE
Invoke-Pester -CodeCoverage @{ Path = 'ScriptUnderTest.ps1'; StartLine = 10; EndLine = 20 }

Runs all *.Tests.ps1 scripts in the current directory, and generates a coverage report for all commands on lines 10 through 20 in the "ScriptUnderTest.ps1" file.

.LINK
Describe
about_pester
New-PesterOption

#>
    [CmdletBinding(DefaultParameterSetName = 'LegacyOutputXml')]
    param(
        [Parameter(Position=0,Mandatory=0)]
        [Alias('Path', 'relative_path')]
        [object[]]$Script = '.',

        [Parameter(Position=1,Mandatory=0)]
        [Alias("Name")]
        [string[]]$TestName,

        [Parameter(Position=2,Mandatory=0)]
        [switch]$EnableExit,

        [Parameter(Position=3,Mandatory=0, ParameterSetName = 'LegacyOutputXml')]
        [string]$OutputXml,

        [Parameter(Position=4,Mandatory=0)]
        [Alias('Tags')]
        [string[]]$Tag,

        [string[]]$ExcludeTag,

        [switch]$PassThru,

        [object[]] $CodeCoverage = @(),

        [Switch]$Strict,

        [Parameter(Mandatory = $true, ParameterSetName = 'NewOutputSet')]
        [string] $OutputFile,

        [Parameter(Mandatory = $true, ParameterSetName = 'NewOutputSet')]
        [ValidateSet('LegacyNUnitXml', 'NUnitXml')]
        [string] $OutputFormat,

        [Switch]$Quiet,

        [object]$PesterOption
    )

    if ($PSBoundParameters.ContainsKey('OutputXml'))
    {
        & $script:SafeCommands['Write-Warning'] 'The -OutputXml parameter has been deprecated; please use the new -OutputFile and -OutputFormat parameters instead.  To get the same type of export that the -OutputXml parameter currently provides, use an -OutputFormat of "LegacyNUnitXml".'

        & $script:SafeCommands['Start-Sleep'] -Seconds 2

        $OutputFile = $OutputXml
        $OutputFormat = 'LegacyNUnitXml'
    }

    $script:mockTable = @{}

    $pester = New-PesterState -TestNameFilter $TestName -TagFilter ($Tag -split "\s") -ExcludeTagFilter ($ExcludeTag -split "\s") -SessionState $PSCmdlet.SessionState -Strict:$Strict -Quiet:$Quiet -PesterOption $PesterOption
    Enter-CoverageAnalysis -CodeCoverage $CodeCoverage -PesterState $pester

    Write-Screen "`r`n`r`n`r`n`r`n"

    $invokeTestScript = {
        param (
            [Parameter(Position = 0)]
            [string] $Path,

            [object[]] $Arguments = @(),
            [System.Collections.IDictionary] $Parameters = @{}
        )

        & $Path @Parameters @Arguments
    }

    Set-ScriptBlockScope -ScriptBlock $invokeTestScript -SessionState $PSCmdlet.SessionState

    $testScripts = @(ResolveTestScripts $Script)

    foreach ($testScript in $testScripts)
    {
        try
        {
            do
            {
                & $invokeTestScript -Path $testScript.Path -Arguments $testScript.Arguments -Parameters $testScript.Parameters
            } until ($true)
        }
        catch
        {
            $firstStackTraceLine = $_.ScriptStackTrace -split '\r?\n' | & $script:SafeCommands['Select-Object'] -First 1
            $pester.AddTestResult("Error occurred in test script '$($testScript.Path)'", "Failed", $null, $_.Exception.Message, $firstStackTraceLine, $null, $null, $_)

            # This is a hack to ensure that XML output is valid for now.  The test-suite names come from the Describe attribute of the TestResult
            # objects, and a blank name is invalid NUnit XML.  This will go away when we promote test scripts to have their own test-suite nodes,
            # planned for v4.0
            $pester.TestResult[-1].Describe = "Error in $($testScript.Path)"

            $pester.TestResult[-1] | Write-PesterResult
        }
    }

    $pester | Write-PesterReport
    $coverageReport = Get-CoverageReport -PesterState $pester
    Show-CoverageReport -CoverageReport $coverageReport
    Exit-CoverageAnalysis -PesterState $pester

    if(& $script:SafeCommands['Get-Variable'] -Name OutputFile -ValueOnly -ErrorAction $script:IgnoreErrorPreference) {
        Export-PesterResults -PesterState $pester -Path $OutputFile -Format $OutputFormat
    }

    if ($PassThru) {
        #remove all runtime properties like current* and Scope
        $properties = @(
            "TagFilter","ExcludeTagFilter","TestNameFilter","TotalCount","PassedCount","FailedCount","SkippedCount","PendingCount","Time","TestResult"

            if ($CodeCoverage)
            {
                @{ Name = 'CodeCoverage'; Expression = { $coverageReport } }
            }
        )

        $pester | & $script:SafeCommands['Select-Object'] -Property $properties
    }

    if ($EnableExit) { Exit-WithCode -FailedCount $pester.FailedCount }
}

function New-PesterOption
{
<#
.SYNOPSIS
   Creates an object that contains advanced options for Invoke-Pester
.PARAMETER IncludeVSCodeMarker
   When this switch is set, an extra line of output will be written to the console for test failures, making it easier
   for VSCode's parser to provide highlighting / tooltips on the line where the error occurred.
.INPUTS
   None
   You cannot pipe input to this command.
.OUTPUTS
   System.Management.Automation.PSObject
.LINK
   Invoke-Pester
#>

    [CmdletBinding()]
    param (
        [switch] $IncludeVSCodeMarker
    )

    return & $script:SafeCommands['New-Object'] psobject -Property @{
        IncludeVSCodeMarker = [bool]$IncludeVSCodeMarker
    }
}

function ResolveTestScripts
{
    param ([object[]] $Path)

    $resolvedScriptInfo = @(
        foreach ($object in $Path)
        {
            if ($object -is [System.Collections.IDictionary])
            {
                $unresolvedPath = Get-DictionaryValueFromFirstKeyFound -Dictionary $object -Key 'Path', 'p'
                $arguments      = @(Get-DictionaryValueFromFirstKeyFound -Dictionary $object -Key 'Arguments', 'args', 'a')
                $parameters     = Get-DictionaryValueFromFirstKeyFound -Dictionary $object -Key 'Parameters', 'params'

                if ($unresolvedPath -isnot [string] -or $unresolvedPath -notmatch '\S')
                {
                    throw 'When passing hashtables to the -Path parameter, the Path key is mandatory, and must contain a single string.'
                }

                if ($null -ne $parameters -and $parameters -isnot [System.Collections.IDictionary])
                {
                    throw 'When passing hashtables to the -Path parameter, the Parameters key (if present) must be assigned an IDictionary object.'
                }
            }
            else
            {
                $unresolvedPath = [string] $object
                $arguments      = @()
                $parameters     = @{}
            }

            if ($unresolvedPath -notmatch '[\*\?\[\]]' -and
                (& $script:SafeCommands['Test-Path'] -LiteralPath $unresolvedPath -PathType Leaf) -and
                (& $script:SafeCommands['Get-Item'] -LiteralPath $unresolvedPath) -is [System.IO.FileInfo])
            {
                $extension = [System.IO.Path]::GetExtension($unresolvedPath)
                if ($extension -ne '.ps1')
                {
                    & $script:SafeCommands['Write-Error'] "Script path '$unresolvedPath' is not a ps1 file."
                }
                else
                {
                    & $script:SafeCommands['New-Object'] psobject -Property @{
                        Path       = $unresolvedPath
                        Arguments  = $arguments
                        Parameters = $parameters
                    }
                }
            }
            else
            {
                # World's longest pipeline?

                & $script:SafeCommands['Resolve-Path'] -Path $unresolvedPath |
                & $script:SafeCommands['Where-Object'] { $_.Provider.Name -eq 'FileSystem' } |
                & $script:SafeCommands['Select-Object'] -ExpandProperty ProviderPath |
                & $script:SafeCommands['Get-ChildItem'] -Include *.Tests.ps1 -Recurse |
                & $script:SafeCommands['Where-Object'] { -not $_.PSIsContainer } |
                & $script:SafeCommands['Select-Object'] -ExpandProperty FullName -Unique |
                & $script:SafeCommands['ForEach-Object'] {
                    & $script:SafeCommands['New-Object'] psobject -Property @{
                        Path       = $_
                        Arguments  = $arguments
                        Parameters = $parameters
                    }
                }
            }
        }
    )

    # Here, we have the option of trying to weed out duplicate file paths that also contain identical
    # Parameters / Arguments.  However, we already make sure that each object in $Path didn't produce
    # any duplicate file paths, and if the caller happens to pass in a set of parameters that produce
    # dupes, maybe that's not our problem.  For now, just return what we found.

    $resolvedScriptInfo
}

function Get-DictionaryValueFromFirstKeyFound
{
    param ([System.Collections.IDictionary] $Dictionary, [object[]] $Key)

    foreach ($keyToTry in $Key)
    {
        if ($Dictionary.Contains($keyToTry)) { return $Dictionary[$keyToTry] }
    }
}

function Set-ScriptBlockScope
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory = $true, ParameterSetName = 'FromSessionState')]
        [System.Management.Automation.SessionState]
        $SessionState,

        [Parameter(Mandatory = $true, ParameterSetName = 'FromSessionStateInternal')]
        $SessionStateInternal
    )

    $flags = [System.Reflection.BindingFlags]'Instance,NonPublic'

    if ($PSCmdlet.ParameterSetName -eq 'FromSessionState')
    {
        $SessionStateInternal = $SessionState.GetType().GetProperty('Internal', $flags).GetValue($SessionState, $null)
    }

    [scriptblock].GetProperty('SessionStateInternal', $flags).SetValue($ScriptBlock, $SessionStateInternal, $null)
}

function Get-ScriptBlockScope
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock
    )

    $flags = [System.Reflection.BindingFlags]'Instance,NonPublic'
    [scriptblock].GetProperty('SessionStateInternal', $flags).GetValue($ScriptBlock, $null)
}

function SafeGetCommand
{
    <#
        .SYNOPSIS
        This command is used by Pester's Mocking framework.  You do not need to call it directly.
    #>

    return $script:SafeCommands['Get-Command']
}

$snippetsDirectoryPath = "$PSScriptRoot\Snippets"
if ((& $script:SafeCommands['Test-Path'] -Path Variable:\psise) -and
    ($null -ne $psISE) -and
    ($PSVersionTable.PSVersion.Major -ge 3) -and
    (& $script:SafeCommands['Test-Path'] $snippetsDirectoryPath))
{
    Import-IseSnippet -Path $snippetsDirectoryPath
}

& $script:SafeCommands['Export-ModuleMember'] Describe, Context, It, In, Mock, Assert-VerifiableMocks, Assert-MockCalled, Set-TestInconclusive
& $script:SafeCommands['Export-ModuleMember'] New-Fixture, Get-TestDriveItem, Should, Invoke-Pester, Setup, InModuleScope, Invoke-Mock
& $script:SafeCommands['Export-ModuleMember'] BeforeEach, AfterEach, BeforeAll, AfterAll
& $script:SafeCommands['Export-ModuleMember'] Get-MockDynamicParameters, Set-DynamicParameterVariables
& $script:SafeCommands['Export-ModuleMember'] SafeGetCommand, New-PesterOption

# SIG # Begin signature block
# MIInVwYJKoZIhvcNAQcCoIInSDCCJ0QCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAa1zF00SgCc6Hf
# nndjPuCIoihFDJJWHbmJ8PgIyYhOKqCCC8MwggXaMIIEwqADAgECAhMzAAABP8rF
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
# BgkqhkiG9w0BCQQxIgQgt5Yg6AkohrHBTzz9oUDIXfbyDRSAV28/S8NzmfKEs4sw
# UAYKKwYBBAGCNwoDHDFCDEAwOTRDRkY4QTY3OUJCOThBREJDNkNEN0IzRUQzOUU0
# OTQ5QUMyRjVDRDlCNkNGOUYyMDM0MzQxQ0RGQzk3MzIwMFoGCisGAQQBgjcCAQwx
# TDBKoCSAIgBNAGkAYwByAG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggGA
# TKUCzw0lkmXdYTCRNLj+g0Tj6SWmoD6VHSkQ2+LDJ5sEdkaiCmdsU7S2tXGgV/Zf
# ZRTjlFUc0W5GUcjipoU2S0d25wLjBvVh8jf4CaOcUuQjfz2+Cze/9yrDLd4ziMLE
# X500//ry7z7HuD/sU2BQ+5aQrVaswBRVDOQnypAQBtj4CGUbdfQ4miYJ6ywRq4ih
# +L+cUILAuvXH+p1hXU25H8zPZQYPiLbIEbvERSgVKWsBzIlD4haZNhKS02Fym11O
# 8gccTfCE8XdW6achlVWe4iDwF2dNN7n/rYRfz40wrnlQkmo8f8JkunTr44UOwPSN
# MliQDlqpuutOBdbr4EuI6lIms78xbuDVBsfI6JdOWrg6KZ1s7EzMAGE9c9vzUHri
# QyGQjiLWBLb59dqMBXxWadF8nkV8rQViBChro7n8y+GbEMTLUAVO8nx8KC1FZpnC
# cLVre16wHEFa2wIenPrQCj+7dETbGGQibZjq9xGemd8l5Izfjcbov6US9+KoApi4
# oYIXlzCCF5MGCisGAQQBgjcDAwExgheDMIIXfwYJKoZIhvcNAQcCoIIXcDCCF2wC
# AQMxDzANBglghkgBZQMEAgEFADCCAVIGCyqGSIb3DQEJEAEEoIIBQQSCAT0wggE5
# AgEBBgorBgEEAYRZCgMBMDEwDQYJYIZIAWUDBAIBBQAEILdb38iTcP2P19PTfj/N
# uzSbPQ5vTSh4nAKkTehasAQiAgZqqYGPCvgYEzIwMjYxMDEwMDgzNjM0LjE4Nlow
# BIACAfSggdGkgc4wgcsxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNV
# BAsTHm5TaGllbGQgVFNTIEVTTjpBMDAwLTA1RTAtRDk0NzElMCMGA1UEAxMcTWlj
# cm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaCCEe0wggcgMIIFCKADAgECAhMzAAAC
# K7sAUP9NO5qhAAEAAAIrMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFBDQSAyMDEwMB4XDTI2MDIxOTE5NDAxMVoXDTI3MDUxNzE5NDAxMVowgcsx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1p
# Y3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNT
# IEVTTjpBMDAwLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3Rh
# bXAgU2VydmljZTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAJfeaLo4
# PezJSpCbhCqCSso9tywr9DHd9hy0vz5UzW45jduiiLkbHBq5OBB/okUchNOjFLuC
# OoqUrw4UvMvpROXSPEQrm3oO45yAld2+62KahOU5LQLeTIhNcEBeiP+CnqFFH3Pp
# ZGKnUq2SKVvd0lcKNCpP0/YK66Ov5XPyv5n6MOXT2OL+Jz/gbfiveZXCOz/8afH0
# +7fVXytcWJw2IDPGm5trClt3ymp/OVZPa+cbeQX2XoyJERu8ndcctTAdCyHS39Ot
# IXH+z/IKqklZgnqgKUbvS2+wUfRpE/zAHhw/8IVrYgu+TbqLc5wkGX6moqMdNIHL
# 2a/BM8QOWfNyjQ23xHqlI9NdmAGyxweGgp8LRZCY7NjaR5dsCZFNxkzJfPm/8Alu
# agjTLTsFrO+3k2Rd10b1MStBbC2wXIgqsSUOBZ8d4KhO7XC7ZyIPd0rvbPdxraDO
# gQPFPaP0FchQpqJPNN1A9GwAxo7d1TTNobAwyXC1InIOHXhgSBmhS7m9Lwy6Ayp2
# s2OmHIvrnIqGOkBZuFiQgc7/S5mO73m0/zNk2pchGHi119Yck8BOf2v5zGTK6HbH
# RUt1/HWWYr1fc2MfQ22ACzkkH/A6WTK653GYVN9ZXJGsvfuKyk5nxo8AWC/JHpw1
# OQamQWjfklGNyI2ZmJTipP1S3L5XmC50WTWPAgMBAAGjggFJMIIBRTAdBgNVHQ4E
# FgQUPhaO5BNQlu1t3eOa9mS7QVnZ5TYwHwYDVR0jBBgwFoAUn6cVXQBeYl2D9OXS
# ZacbUzUZ6XIwXwYDVR0fBFgwVjBUoFKgUIZOaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIw
# MTAoMSkuY3JsMGwGCCsGAQUFBwEBBGAwXjBcBggrBgEFBQcwAoZQaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBUaW1lLVN0
# YW1wJTIwUENBJTIwMjAxMCgxKS5jcnQwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8E
# DDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcNAQELBQADggIB
# AM78IqxyIQzySvV+ofhOV9ProQ2hOPFfDzXSnISrQ92uAvB+BPfH7WDPsJAe1R16
# +oxDmofIMuGbqlP3XUJiQY37qD4xTt8xhOvp3dLGJ4nAEihaR9HiDtKK0bMwpTjr
# koRh6N912hSCi8L/FxGloAs7mnf8DbjwHKEmIy20FA0O2xP8doIXBEUJRFvL9/xz
# WSTLwXzGQJcXP78y1nl3WVYWPA4jaB5kdar1eKEM6B57mdLaSijlXqfxcbbbRRN6
# 9V/6mCakgfvVcoNUhhMYZkmzrI+V8nZperDUwTg1HqiQ2xjc/UzfUfoMxhF8kY0E
# 16nn3mRcaHdjMDdwKLKD6OYnnyH99O+OeAim5QV84OkOMXHSJzVigsA3GEIXdGFL
# 2pgzsrjQ0SEqyFi5oCQgbZcEpiKDev/T9vSyO+MHCznkBiicybcDypxf/qT1V9zS
# a/122ice5YZ8DZv6oTaqkKeHMZt0MeruI5JkTDTWc26kAx/VzjWT0ihNDbPeLDrD
# hlmgs7KDhMoxunWSulPi2uKn/LfQK/mSHKoIM2ppdCkGQ5g43wuC2hDdqZU5fuLH
# mN2ufH+9TFNRKKBe+tZ0vtSTySmZLTO2jZOjLtpPmgHMJO9+P2In8E38TW+EUGSE
# kK9ns9W+wxKdNOaTHYVqXaVWTO24Ajjh8P+7Isl1oxBLMIIHcTCCBVmgAwIBAgIT
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
# U046QTAwMC0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFNlcnZpY2WiIwoBATAHBgUrDgMCGgMVAAmsP3TKQemj/QAZvuWbC+wK2pE5oIGD
# MIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQG
# A1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwDQYJKoZIhvcNAQEL
# BQACBQDudEiyMCIYDzIwMjYxMDEwMDUxNjM0WhgPMjAyNjEwMTEwNTE2MzRaMHcw
# PQYKKwYBBAGEWQoEATEvMC0wCgIFAO50SLICAQAwCgIBAAICCrUCAf8wBwIBAAIC
# EvswCgIFAO51mjICAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAK
# MAgCAQACAwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0BAQsFAAOCAQEAKNvTr29Q
# VH/G/PeOmooUHJm8NSRAbha6xjzvAy0ktYNtipuK6FGFmBXBq5P01/ahMIrSaGXK
# p0bvTTgpvo3Nfs6nsjP25W6fOmb+QQ3fMpfavq5ORn2WIoTa4f2zszKoeGHtu8YJ
# H9fCBQQZu84mR0orzxWkg7zMn+mbm9JjDSU9Vrt3o+KigbCGkhmMveekJx6Hf2O8
# eoSRpzwllJQLiefFaflbTyawFPrgs6L8AGW/T5/OjJ/u2HmCvhF1Ff/e9vu6fZwA
# 8YYUvrk3Nuj7ZVyY+83XMvL9c1mf9wUo2DhJqUrkaHejJM+xH8pscAnGi6Yi5qCm
# Pur6tuaWICVOLjGCBA0wggQJAgEBMIGTMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBD
# QSAyMDEwAhMzAAACK7sAUP9NO5qhAAEAAAIrMA0GCWCGSAFlAwQCAQUAoIIBSjAa
# BgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIEINd9djFX
# ZJWJo+S7job6csw/X0KaFfmTDbGMzTh6ojAxMIH6BgsqhkiG9w0BCRACLzGB6jCB
# 5zCB5DCBvQQgcg4j9D+QV+1gD4zY5j7UHHdqMEPr9YMC09Pa8WS/blIwgZgwgYCk
# fjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAiu7AFD/TTuaoQAB
# AAACKzAiBCDyPW30hQqBVxhqsIPYsjbxcxC+Pxp+3UGgQa79W4CG8DANBgkqhkiG
# 9w0BAQsFAASCAgAi71sQEsCLRFwVs/hn3JawrABWFN/E4p4STZTBqUoH3z/EfuIJ
# H9PAotFhrTPAT+FMlQPtymXiYOpcJjJykHI1ZKH73hzKRd366aOia2tdu2Yi8PBL
# ZvpslSflEHPsxc1szDSYY9b4Fa37rQ/VHDMYQQXKOei+WN46Hk6sPNGe83kYtlMV
# X3vsRXiISUca0FLBGB/ibgpo15il7nkEVNUoJxwvOmA/KUCdJpLcfzmpoT0PVhft
# iolipd5Iju2db4OMdXE4hx+EOmHyr106BPrgkaNSpxjlDJ5X0XqLIFScw93oFjja
# gATKzEflNB5u8SE7GkEImmV0kyHwo9EdyrWa3/k8K2gpvxff+BPSkpMy9v6p8mi2
# WNmcd90JOT2IDExK74rrf+RbJe2ppwDY7CxBhm1ll1WqRj0NnT5+avszpAPq1epV
# EWrti9cxVQlUHn67LB7kXZWz8GtgsjXfGNEb+I00cV+s31iT73r1BgMxGcxt5mHR
# lmxAh7tul1yJLKvMfArcMsuEsVUlwwFee9FweK/2v4zJKmf+iRn5x1MtkSu1axG/
# aFI8BuveXPVvvARwzok/cMWOsmqGJJ6mVdKdkaLiufGDKFetUJsQshv4NhIf8qCE
# 2hqHnia+qlGdjkjvlcUuMXDm2qqxIs2tuqU2quCLKHEpwDXttRo5vf4HQA==
# SIG # End signature block
