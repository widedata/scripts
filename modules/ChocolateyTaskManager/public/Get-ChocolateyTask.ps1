<#
.SYNOPSIS
Gets scheduled Chocolatey package tasks.

.DESCRIPTION
Retrieves scheduled Chocolatey package tasks from the JSON file at C:\ProgramData\AppPkgMgr\scheduled.json.

.PARAMETER Identity
The name or ID of a specific scheduled task to return. If not specified, all scheduled tasks are returned.

.INPUTS
None

.OUTPUTS
[PSCustomObject] or [Array] of scheduled task objects.

.EXAMPLE
Get-ChocolateyTask
Returns all scheduled Chocolatey tasks.

.EXAMPLE 
Get-ChocolateyTask -Identity 'Choco-vlc-1'
Returns the scheduled task with name 'Choco-vlc-1'.

.NOTES
None
#>


function Get-ChocolateyTask {
    param (
        [string]$Identity
    )

    # JSON file handling
    $path = 'C:\ProgramData\AppPkgMgr\scheduled.json'

    if (Test-Path -Path $path) {
        $scheduledTasks = Get-Content -Path $path | ConvertFrom-Json
        
        if ($Identity) {
            $filteredTasks = $scheduledTasks | Where-Object { $_.taskName -eq $Identity -or $_.id -eq $Identity }
            return $filteredTasks
        }
        else {
            return $scheduledTasks
        }
    }
    else {
        Write-Host "No scheduled tasks found."
    }
}
