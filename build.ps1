[cmdletbinding()]
param(
    [string[]]$Task = 'default'
)

if (!(Get-Module -Name PSScriptAnalyzer -ListAvailable)) { Install-Module -Name PSScriptAnalyzer }
if (!(Get-Module -Name Pester -ListAvailable)) { Install-Module -Name Pester }
if (!(Get-Module -Name psake -ListAvailable)) { Install-Module -Name psake }
if (!(Get-Module -Name PSDeploy -ListAvailable)) { Install-Module -Name PSDeploy }

Invoke-psake -buildFile "$PSScriptRoot\psakeBuild.ps1" -taskList $Task -Verbose:$VerbosePreference
