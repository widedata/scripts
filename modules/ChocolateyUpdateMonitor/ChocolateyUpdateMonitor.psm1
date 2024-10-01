
<#
.SYNOPSIS
    Retrieves the configuration settings for the Chocolatey Update Monitor.

.DESCRIPTION
    The Get-ChocoMonitorConfig function reads the settings from a JSON file located in a specific path. If the settings file does not exist, it generates default settings and saves them to the file. It then returns these settings.

.EXAMPLE
    Get-ChocoMonitorConfig
    This example retrieves the Chocolatey Update Monitor settings.
#>

function Get-ChocoMonitorConfig {
    [CmdletBinding()]
    param()

    Write-Verbose "Loading Chocolatey Update Monitor settings"

    if (-NOT(Test-Path "$env:ProgramData\ChocoUpdateMonitor")) {
        Write-Verbose "No settings folder found. Generating default folder..."
		
		New-Item -Path "$env:ProgramData\ChocoUpdateMonitor" -Type Directory

    if (-NOT(Test-Path "$env:ProgramData\ChocoUpdateMonitor\settings.json")) {
        Write-Verbose "No settings file found. Generating default settings..."

        $defaultSettings = @{
            UseRocolatey           = Test-Path (Get-Command roco).Path
            AppIcon                = 'https://wdc.help/icons/Box.Packed.ico'
            ChocoSources           = @()
            AppTitle               = 'Chocolatey Update Monitor'
            UpdateCheckInterval    = "Daily"
            UpdateNotifyWebhookURL = ""
        }

        $chocoSources = choco source list -r |
            ConvertFrom-Csv -Header 'SourceName', 'SourceUrl', 'disabled', 'Username', 'Password', 'Priority', 'BypassProxy', 'SelfService', 'AdminOnly' -delimiter '|' |
            Where-Object disabled -ne $true | # Exclude disabled sources
            Select-Object @{Name='SourceName'; Expression={$_.SourceName}}, @{Name='SourceUrl'; Expression={$_.SourceUrl}}

        foreach ($source in $chocoSources) {
            $defaultSettings.ChocoSources += @{
                SourceName = $source.SourceName
                SourceUrl  = $source.SourceUrl
            }
        }

        $defaultSettings | ConvertTo-Json -Depth 4 | Set-Content "$env:ProgramData\ChocoUpdateMonitor\settings.json"
    }

    Write-Verbose "Reading settings from file..."
    $settings = Get-Content "$env:ProgramData\ChocoUpdateMonitor\settings.json" | ConvertFrom-Json

    return $settings
}

<#
.SYNOPSIS
    Retrieves the list of outdated Chocolatey packages.

.DESCRIPTION
    The Get-ChocolateyUpdate function checks for outdated packages using either Chocolatey or Rocolatey, depending on the configuration settings. It fetches updates from the sources specified in the settings and saves the list of outdated packages to a JSON file.

.EXAMPLE
    Get-ChocolateyUpdate
    This example retrieves the list of outdated Chocolatey packages and saves it to a JSON file.
#>

function Get-ChocolateyUpdate {
    [CmdletBinding()]
    param()

    $settings = Get-ChocoMonitorConfig
    $outdatedPackages = @()

    if ($settings.UseRocolatey) {
        Write-Verbose "Using Rocolatey"

        $allChocoSources = choco source list -r | ConvertFrom-Csv -Header 'SourceName', 'SourceUrl', 'disabled', 'Username', 'Password', 'Priority', 'BypassProxy', 'SelfService', 'AdminOnly' -delimiter '|'

        $sourceNamesToDisable = $allChocoSources.SourceName | Where-Object { $_ -notin $settings.ChocoSources.SourceName }

        foreach ($thisChocoSource in $allChocoSources) {
            try {
                $request = Invoke-WebRequest -Uri $thisChocoSource.SourceURL -TimeoutSec 5

                if ($request.StatusCode -ne 200) {
                    Write-Verbose "Skipping source $($thisChocoSource.SourceURL) as it's not online."
                    $sourceNamesToDisable += $thisChocoSource.SourceName
                }
            } catch {
                Write-Verbose "There was a problem connecting to $($thisChocoSource.SourceURL)."
            }


        }

        Write-Verbose "Temporarily disabling sources not specified in settings"
        $sourceNamesToDisable | ForEach-Object { choco source disable -n $_ }

        try {
            $outdatedPackages = roco outdated -r |
                ConvertFrom-Csv -Delimiter '|' -Header 'Name', 'CurrentVersion', 'AvailableVersion', 'Pinned'
        } catch {
            Write-Verbose "There was a problem running Rocolatey."
        }finally {
            Write-Verbose "Re-enabling temporarily disabled sources"
            $sourceNamesToDisable | ForEach-Object { choco source enable -n $_ }
        }
    }
    else {
        Write-Verbose "Using Chocolatey"

        foreach ($source in $settings.ChocoSources) {
            try {
                $request = Invoke-WebRequest -Uri $source.SourceURL -TimeoutSec 5

                if ($request.StatusCode -eq 200) {
                    Write-Verbose "Retrieving updates from $($source.SourceURL)..."
                    $outdatedPackage = choco outdated --source $source.SourceURL -r --ignore-unfound | ConvertFrom-Csv -Delimiter '|' -Header 'Name', 'CurrentVersion', 'AvailableVersion', 'Pinned'
                    $outdatedPackage | add-member -NotePropertyName Source -NotePropertyValue $source.SourceURL
                    $outdatedPackages += $outdatedPackage
                } else {
                    Write-Verbose "Skipping source $($source.SourceURL) as it's not online."
                }
            } catch {
                Write-Verbose "There was a problem connecting to $($source.SourceURL)."
            }
        }
    }

    Set-Content "$env:ProgramData\ChocoUpdateMonitor\updates.json" ($outdatedPackages | ConvertTo-Json -Depth 4)
}

<#
.SYNOPSIS
    Installs updates for outdated Chocolatey packages.

.DESCRIPTION
    The Install-ChocolateyUpdate function reads the list of outdated packages from a JSON file. It then iterates over each package and if the package is not pinned, it attempts to upgrade it using Chocolatey. If there are multiple updates for the same package, they are skipped to avoid version conflicts.

.EXAMPLE
    Install-ChocolateyUpdate
    This example installs updates for all outdated and unpinned Chocolatey packages listed in the JSON file.
#>

function Install-ChocolateyUpdate {
    [CmdletBinding(SupportsShouldProcess)]
    param ()

    $updatesFile = "$env:ProgramData\ChocoUpdateMonitor\updates.json"

    if (-NOT(Test-Path $updatesFile)) {
        Write-Verbose "No updates file found. Fetching the latest updates..."
        Get-ChocolateyUpdate
    }

    $updates = (Get-Content $updatesFile | ConvertFrom-Json)

    foreach ($update in $updates) {
        if ($update.Pinned -ne $true) {
            Write-Verbose "Installing update for $($update.Name)..."
            # Since Rocolatey does not support install or upgrade, we will always use Chocolatey for these operations.

            # If there are multiple updates for the same package, we need to skip all of them to avoid version conflicts.
            if(($updates | Where-Object { $_.Name -eq $update.Name }).Count -gt 1) {
                if($WhatIfPreference.IsPresent) {
                    Write-Output "WhatIf is enabled. Would have skipped $($update.Name) because there are multiple available source for this package."
                    continue
                } else {
                    Write-Warning "Package $($update.Name) is a duplicate. Skipping..."
                    continue
                }
            } else {
                if($WhatIfPreference.IsPresent) {
                    Write-Output "WhatIf is enabled. Running with -NOOP parameter."
                    choco upgrade $update.Name --source $update.Source -y --noop -r
                } else {
                    choco upgrade $update.Name --source $update.Source -y -r
                }
            }
        }
    }
}

<#
.SYNOPSIS
    Displays the list of outdated Chocolatey packages.

.DESCRIPTION
    The Show-ChocolateyUpdate function reads the list of outdated packages from a JSON file and displays each package. If there are multiple updates for the same package, a warning is displayed.

.EXAMPLE
    Show-ChocolateyUpdate
    This example displays the list of outdated Chocolatey packages listed in the JSON file.
#>

function Show-ChocolateyUpdate {
    [CmdletBinding()]
    param()

    $updatesFile = "$env:ProgramData\ChocoUpdateMonitor\updates.json"

    if (-NOT(Test-Path $updatesFile)) {
        Write-Verbose "No updates file found. Fetching the latest updates..."
        Get-ChocolateyUpdate
    }

    $updates = (Get-Content $updatesFile | ConvertFrom-Json)

    foreach ($update in $updates) {
        if (($updates | Where-Object { $_.Name -eq $update.Name }).Count -gt 1) {
            Write-Output $update
            Write-Warning "Package $($update.Name) has multiple available sources for update."
        } else {
            Write-Output $update
        }
    }
}

<#
.SYNOPSIS
    Registers a scheduled task to check for Chocolatey package updates.

.DESCRIPTION
    The Register-ChocoMonitorTask function creates a new scheduled task that runs the Get-ChocolateyUpdate function at a specified interval. The interval is determined by the UpdateCheckInterval setting, which can be "Daily", "Weekly", "AtLogOn", or "AtStartup".

.EXAMPLE
    Register-ChocoMonitorTask
    This example registers a scheduled task to check for Chocolatey package updates according to the interval specified in the settings.
#>

function Register-ChocoMonitorTask {
    [CmdletBinding(SupportsShouldProcess)]
    param ()

    $settings = Get-ChocoMonitorConfig
    $validTriggers = @("Daily", "Weekly", "AtLogOn", "AtStartup")
    $TaskName = 'ChocolateyUpdateMonitor'

    if ($settings.UpdateCheckInterval -notin $validTriggers) {
        Write-Error "Invalid UpdateCheckInterval setting. Must be one of: $validTriggers"
        return
    }

    $action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument '-NoProfile -WindowStyle Hidden -Command "& {Get-ChocolateyUpdate}"'
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount

    switch ($settings.UpdateCheckInterval) {
        "Daily" {
            $trigger = New-ScheduledTaskTrigger -Daily -At 10am
        }
        "Weekly" {
            $trigger = New-ScheduledTaskTrigger -Weekly -At 10am -DaysOfWeek Monday
        }
        "AtLogOn" {
            $trigger = New-ScheduledTaskTrigger -AtLogOn
        }
        "AtStartup" {
            $trigger = New-ScheduledTaskTrigger -AtStartup
        }
    }

    $taskSettings = New-ScheduledTaskSettingsSet -DontStopIfGoingOnBatteries -StartWhenAvailable -AllowStartIfOnBatteries

    if ($WhatIfPreference.IsPresent) {
        Write-Output "WhatIf is enabled. Would have created Chocolatey Update Monitor scheduled task"
        Install-Module ChocolateyUpdateMonitor -Scope AllUsers -WhatIf
        return
    } else {
        Write-Verbose "Creating Chocolatey Update Monitor scheduled task"
        Install-Module ChocolateyUpdateMonitor -Scope AllUsers
        Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $taskSettings
    }
}

<#
.SYNOPSIS
    Unregisters the scheduled task for checking Chocolatey package updates.

.DESCRIPTION
    The Unregister-ChocoMonitorTask function removes the scheduled task named "Chocolatey Update Monitor".

.EXAMPLE
    Unregister-ChocoMonitorTask
    This example removes the scheduled task for checking Chocolatey package updates.
#>

function Unregister-ChocoMonitorTask {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $TaskName = 'ChocolateyUpdateMonitor'

    try {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Verbose "Successfully removed the scheduled task: $TaskName"
    }
    catch {
        Write-Warning "Failed to remove the scheduled task: $TaskName"
        Write-Error $_
    }
}

<#
.SYNOPSIS
    Sets the configuration settings for the Chocolatey Update Monitor.

.DESCRIPTION
    The Set-ChocoMonitorConfig function updates the settings for the Chocolatey Update Monitor and writes them to a JSON file. The settings that can be updated include UseRocolatey, AppIcon, ChocoSources, AppTitle, UpdateNotifyWebhookURL, and UpdateCheckInterval. If the UpdateCheckInterval is changed, the scheduled task for checking updates is also updated.

.PARAMETER UseRocolatey
    Specifies whether to use Rocolatey. Should be a boolean value.

.PARAMETER AppIcon
    The URL of the application icon.

.PARAMETER ChocoSources
    The list of Chocolatey sources.

.PARAMETER AppTitle
    The title of the application.

.PARAMETER UpdateNotifyWebhookURL
    The URL of the webhook to notify about updates.

.PARAMETER UpdateCheckInterval
    The interval for checking updates. Can be "Daily", "Weekly", "AtLogOn", or "AtStartup".

.EXAMPLE
    Set-ChocoMonitorConfig -UseRocolatey $false -AppIcon "https://newicon.com/icon.png" -UpdateCheckInterval "Weekly"
    This example sets UseRocolatey to false, changes the AppIcon, and sets the UpdateCheckInterval to "Weekly".
#>

function Set-ChocoMonitorConfig {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$false)]
        [bool]$UseRocolatey,
        [Parameter(Mandatory=$false)]
        [string]$AppIcon,
        [Parameter(Mandatory=$false)]
        [psobject]$ChocoSources,
        [Parameter(Mandatory=$false)]
        [string]$AppTitle,
        [Parameter(Mandatory=$false)]
        [string]$UpdateNotifyWebhookURL,
        [Parameter(Mandatory=$false)]
        [string]$UpdateCheckInterval
    )

    $settingsFile = "$env:ProgramData\ChocoUpdateMonitor\settings.json"

    if (Test-Path $settingsFile) {
        $currentSettings = Get-Content $settingsFile | ConvertFrom-Json
    }
    else {
        $currentSettings = Get-ChocoMonitorConfig
    }

    if ($PSBoundParameters.ContainsKey('UseRocolatey')) {
        $currentSettings.UseRocolatey = $UseRocolatey
    }
    if ($PSBoundParameters.ContainsKey('AppIcon')) {
        $currentSettings.AppIcon = $AppIcon
    }
    if ($PSBoundParameters.ContainsKey('ChocoSources')) {
        $currentSettings.ChocoSources = $ChocoSources
    }
    if ($PSBoundParameters.ContainsKey('AppTitle')) {
        $currentSettings.AppTitle = $AppTitle
    }
    if ($PSBoundParameters.ContainsKey('UpdateNotifyWebhookURL')) {
        $currentSettings.UpdateNotifyWebhookURL = $UpdateNotifyWebhookURL
    }
    if ($PSBoundParameters.ContainsKey('UpdateCheckInterval')) {
        $currentSettings.UpdateCheckInterval = $UpdateCheckInterval
    }

    if ($WhatIfPreference.IsPresent) {
        Write-Output "WhatIf is enabled. Would have updated the settings file"
        return
    } else {
        $currentSettings | ConvertTo-Json | Set-Content $settingsFile
        Write-Verbose "Settings updated"
    }


    if ($UpdateCheckInterval -ne $currentSettings.UpdateCheckInterval) {
        if ($WhatIfPreference.IsPresent) {
            Write-Output "WhatIf is enabled. Would have updated the scheduled task"
            return
        } else {
            Write-Verbose "UpdateCheckInterval changed, updating the scheduled task..."
            Unregister-ChocoMonitorTask
            Register-ChocoMonitorTask
            }
        }
}


Export-ModuleMember -Function Get-ChocoMonitorConfig, Get-ChocolateyUpdate, Show-ChocolateyUpdate, Install-ChocolateyUpdate, Register-ChocoMonitorTask, Set-ChocoMonitorConfig, Unregister-ChocoMonitorTask
