<#
.SYNOPSIS
Registers a scheduled Chocolatey package task in Windows Task Scheduler.

.DESCRIPTION
Creates a scheduled task to run a Chocolatey command at a specified date/time. Task details are saved to C:\ProgramData\AppPkgMgr\scheduled.json.

.PARAMETER id
The ID of the Chocolatey package to schedule.

.PARAMETER version
The specific version of the package to install/upgrade to.

.PARAMETER action 
The Chocolatey command to run (install, upgrade, uninstall, etc).

.PARAMETER actionParameters
Additional parameters to pass to the Chocolatey command.

.PARAMETER source
The source repository to retrieve the package from.

.PARAMETER taskDateTime
The date/time to run the scheduled task.

.PARAMETER RunAsJob
If specified, runs the task as a PowerShell job under the SYSTEM account.

.INPUTS
None

.OUTPUTS
None

.EXAMPLE
Register-ChocolateyTask -id 'vlc' -version '3.0.8' -action 'install' -taskDateTime '3/1/2023 9:00'

.NOTES
None
#>


function Register-ChocolateyTask {
    param (
        [string]$id,
        [string]$version,
        [string]$action,
        [string[]]$actionParameters,
        [string]$source,
        [datetime]$taskDateTime,
        [switch]$RunAsJob
    )
    
    # Initialize $scheduledTasks as an empty array
    $scheduledTasks = @()

    # JSON file path
    $path = 'C:\ProgramData\AppPkgMgr\scheduled.json'

    # Check if the file exists
    if (Test-Path -Path $path) {
        # Load existing scheduled tasks from the JSON file
        $scheduledTasks += (Get-Content -Path $path | ConvertFrom-Json)
    } else {
        # Create an empty JSON file if it does not exist
        @() | ConvertTo-Json | Set-Content -Path $path
    }

    # Determine task name and make sure it's unique
    $taskName = "Choco-$id"
    $counter = 1
    while ($scheduledTasks.taskName -contains $taskName) {
        $taskName = "Choco-$id-$counter"
        $counter++
    }

    $scheduledTask = @{
        id               = $id
        version          = $version
        action           = $action
        actionParameters = $actionParameters
        source           = $source
        taskDateTime     = $taskDateTime.ToString('o')
        taskStatus       = "Scheduled"
        taskName         = $taskName
        RunAsJob         = $RunAsJob.IsPresent
    }
    
    $scheduledTasks += $scheduledTask
    $scheduledTasks | ConvertTo-Json | Set-Content -Path $path

    # Windows scheduled task creation
    $chocoAction = "choco $action $id --version $version --source $source $($actionParameters -join ' ')"
    $taskAction = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument $chocoAction
    $taskTrigger = New-ScheduledTaskTrigger -Once -At $taskDateTime

    if ($RunAsJob) {
        $taskPrincipal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
        $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopOnIdleEnd -DontStopIfGoingOnBatteries -RunOnlyIfNetworkAvailable # -ExecutionTimeLimit ([TimeSpan]::FromHours(4)) -DeleteExpiredTaskAfter ([TimeSpan]::FromDays(30)) -AsJob
    }
    else {
        $taskPrincipal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
        $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopOnIdleEnd -DontStopIfGoingOnBatteries -RunOnlyIfNetworkAvailable # -ExecutionTimeLimit ([TimeSpan]::FromHours(4)) -DeleteExpiredTaskAfter ([TimeSpan]::FromDays(30))
    }

    Register-ScheduledTask -Action $taskAction -Trigger $taskTrigger -Principal $taskPrincipal -TaskName $taskName -Settings $taskSettings -Description "Chocolatey task for $id"

    Write-Host "Task for package '$id' scheduled successfully with task name '$taskName'."
}
