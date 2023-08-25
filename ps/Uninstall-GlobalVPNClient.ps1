    <#
    .SYNOPSIS
    Uninstalls the Global VPN Client application.

    .DESCRIPTION
    This script will search the uninstall registry keys for the Global VPN Client application.When found, it will execute the uninstall string to uninstall the application.

    It first stops any running processes that start with "SWGVC" to avoid issues uninstalling.

    It searches both 32-bit and 64-bit registry locations for the uninstall information.

    .EXAMPLE
    Uninstall-GlobalVPNClient

    Demonstrates how to find and execute the uninstall command for Global VPN Client.
    #>

function Uninstall-GlobalVPNClient {

    # Stop processes starting with "SWGVC"
    Get-Process | Where-Object { $_.ProcessName -like "SWGVC*" } | Stop-Process -Force

    # Path to the registry location for uninstall commands
    $registryPath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'

    # Loop through both 32-bit and 64-bit registry paths
    foreach ($path in $registryPath) {
        # Get all subkeys
        $keys = Get-ChildItem -LiteralPath $path

        # Loop through each subkey and check for the application name
        foreach ($key in $keys) {
            $keyName = $key.PSChildName

            try {
                $displayName = Get-ItemPropertyValue -Path "$path\$keyName" -Name 'DisplayName'
            } catch {
                $displayName = $null
            }

            if ($displayName -eq "Global VPN Client") {

                try {
                    $uninstallString = Get-ItemPropertyValue -Path "$path\$keyName" -Name 'UninstallString'
                } catch {
                    $uninstallString = $null
                }

                if ($uninstallString) {
                    Write-Host "Found uninstall command for Global VPN Client. Executing uninstallation..."
                    Start-Process cmd -ArgumentList "/c $uninstallString" -Wait
                    Write-Host "Uninstallation command executed."
                } else {
                    Write-Host "Uninstall command not found for Global VPN Client."
                }
                break
            }
        }
    }
}

Uninstall-GlobalVPNClient