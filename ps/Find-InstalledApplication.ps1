<#
.SYNOPSIS
    Searches for installed applications in both system-wide and user-specific registry keys, covering both 32-bit and 64-bit uninstall locations.

.DESCRIPTION
    The Find-InstalledApplication function searches for installed applications in the Windows Registry.
    It checks the following registry hives:
      - HKLM (Hive Key Local Machine) for system-wide installations,
      - HKU (HKEY_USERS) for user-specific installations.
    This search covers both 32-bit and 64-bit uninstall locations in the registry.
    For each found application, it adds a property 'Scope' to indicate whether the installation is 'Machine' wide or specific to a 'domain\username'.
    The function supports both partial and exact match searches for application names.

.PARAMETER AppName
    The name of the application to search for. This parameter accepts partial or complete application names.

.PARAMETER Exact
    Indicates that the function should perform an exact match search for the application name. 
    When this switch is used, only applications with names exactly matching the specified AppName will be returned.
    Without this switch, the function performs a partial match search.

.EXAMPLE
    Find-InstalledApplication -AppName "Chrome"
    This command searches for installations that include 'Chrome' in the name and returns details of the installations found, along with the scope of each installation (either 'Machine' or 'user domain\username').

.EXAMPLE
    Find-InstalledApplication -AppName "Google Chrome" -Exact
    This command performs an exact match search for 'Google Chrome' and returns details of the installations found, along with the scope of each installation (either 'Machine' or 'user domain\username').

.NOTES
    This function requires appropriate permissions to access and modify registry settings.
    It is recommended to run PowerShell with administrative privileges for accurate search results.

#>

function Find-InstalledApplication {
  [CmdletBinding()]
    param (
        [string]$AppName,
        [switch]$Exact
    )

    # Define registry paths for uninstall information
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    # Initialize an empty array to hold results
    $results = @()

    # Mount HKU as a PSDrive if not already mounted
    if (-not (Get-PSDrive -Name HKU)) {
        New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS | Out-Null
    }

    # Function to get username from SID
    function Get-UsernameFromSID {
        param (
            [string]$SID
        )
        try {
            $objUser = New-Object System.Security.Principal.SecurityIdentifier($SID)
            $objUser.Translate([System.Security.Principal.NTAccount]).Value
        }
        catch {
            return "Unknown"
        }
    }

    # Search in HKLM
    foreach ($path in $regPaths) {
        if($Exact) {
                Get-ItemProperty -Path $path -ErrorAction Continue | 
                Where-Object { $_.DisplayName -eq "$AppName" } | 
                ForEach-Object {
                    $_ | Add-Member -MemberType NoteProperty -Name "Scope" -Value "Machine" -PassThru
                } | ForEach-Object { $results += $_ }
        } else {
                Get-ItemProperty -Path $path -ErrorAction Continue | 
                Where-Object { $_.DisplayName -like "*$AppName*" } | 
                ForEach-Object {
                    $_ | Add-Member -MemberType NoteProperty -Name "Scope" -Value "Machine" -PassThru
                } | ForEach-Object { $results += $_ }
        }
    }

    # Search in HKU
    Get-ChildItem 'HKU:\' -ErrorAction SilentlyContinue | ForEach-Object {
        $userRegPath = $_.Name
        $username = Get-UsernameFromSID -SID $_.PSChildName
        foreach ($path in $regPaths) {
            # Correct the finalPath construction
            $finalPath = "HKU:\" + $_.PSChildName + "\Software\" + ($path -replace "HKLM:\\SOFTWARE\\", "")
            if($Exact) {
                Get-ItemProperty -Path $finalPath -ErrorAction SilentlyContinue | 
                Where-Object { $_.DisplayName -eq "$AppName" } | 
                ForEach-Object {
                    $_ | Add-Member -MemberType NoteProperty -Name "Scope" -Value $username -PassThru
                } | ForEach-Object { $results += $_ }
                } else {
                Get-ItemProperty -Path $finalPath -ErrorAction SilentlyContinue | 
                Where-Object { $_.DisplayName -like "*$AppName*" } | 
                ForEach-Object {
                    $_ | Add-Member -MemberType NoteProperty -Name "Scope" -Value $username -PassThru
                } | ForEach-Object { $results += $_ }
            }
        }
    }

    $results = $results | Select DisplayName, DisplayVersion, Scope

    # Return the combined results
    return $results
}
