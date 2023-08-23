function Update-ChocolateyTaskStatus {
    param (
        [string]$taskName
    )

    # JSON file handling
    $path = 'C:\ProgramData\AppPkgMgr\scheduled.json'
    
    if (Test-Path -Path $path) {
        $scheduledTasks = Get-Content -Path $path | ConvertFrom-Json

        if ($taskName) {
            # Update the specific task by taskName
            $task = Get-ScheduledTaskInfo -TaskName $taskName
            $result = $task.LastTaskResult
            ($scheduledTasks | Where-Object { $_.taskName -eq $taskName }).taskStatus = $result
        }
        else {
            # Update tasks where taskDateTime has passed and taskStatus is "Scheduled"
            foreach ($taskItem in $scheduledTasks | Where-Object { $_.taskDateTime -lt (Get-Date -Format 'o') -and $_.taskStatus -eq 'Scheduled' }) {
                $task = Get-ScheduledTaskInfo -TaskName $taskItem.taskName
                $result = $task.LastTaskResult
                $taskItem.taskStatus = $result
            }
        }

        $scheduledTasks | ConvertTo-Json | Set-Content -Path $path
        Write-Host "Task status updated successfully."
    }
    else {
        Write-Host "No scheduled tasks found."
    }
}
