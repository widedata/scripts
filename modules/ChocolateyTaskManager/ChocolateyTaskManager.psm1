# ChocolateyTask.psm1

# Dot-source the individual function files
. "$PSScriptRoot\public\Register-ChocolateyTask.ps1"
. "$PSScriptRoot\public\Unregister-ChocolateyTask.ps1"
. "$PSScriptRoot\public\Get-ChocolateyTask.ps1"
. "$PSScriptRoot\public\Update-ChocolateyTaskStatus.ps1"

# Export the functions to make them available to users of the module
Export-ModuleMember -Function Register-ChocolateyTask, Unregister-ChocolateyTask, Get-ChocolateyTask, Update-ChocolateyTaskStatus
