<#
.SYNOPSIS
Unregisters a scheduled Chocolatey package task.

.DESCRIPTION 
Removes a Chocolatey scheduled task by package ID. Deletes the task from Windows Task Scheduler and removes it from the C:\ProgramData\AppPkgMgr\scheduled.json file.

.PARAMETER id
The package ID of the scheduled task to unregister.

.INPUTS
None

.OUTPUTS
None

.EXAMPLE
Unregister-ChocolateyTask -id 'vlc'

Unregisters the scheduled task for the VLC package.

.NOTES
None
#>
   

function Unregister-ChocolateyTask {
    param (
        [string]$id
    )

    # JSON file handling
    $path = 'C:\ProgramData\AppPkgMgr\scheduled.json'

    if (Test-Path -Path $path) {
        $scheduledTasks = Get-Content -Path $path | ConvertFrom-Json
        $taskToRemove = $scheduledTasks | Where-Object { $_.id -eq $id }

        if ($taskToRemove) {
            # Remove the Windows scheduled task
            Unregister-ScheduledTask -TaskName $taskToRemove.taskName -Confirm:$false

            # Remove the task from the JSON array
            $scheduledTasks = $scheduledTasks | Where-Object { $_.id -ne $id }

            if($scheduledTasks -ne "") {
                $scheduledTasks | ConvertTo-Json | Set-Content -Path $path
            } else {
                Remove-Item $path -force
            }

            Write-Host "Task for package '$id' removed successfully."
        } else {
            Write-Host "No task found for package '$id'."
        }
    } else {
        Write-Host "No scheduled tasks found."
    }
}
