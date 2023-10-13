<#
.SYNOPSIS
Powershell Module 7-Zip - 7-Zip commands for PowerShell
.DESCRIPTION
The functions in this module call 7za.exe, the standAlone version of 7-zip to
perform various tasks on 7-zip archives. Place anywhere, together with 7za.exe
and 7zsd.sfx. 7za.exe is required for all operations; 7zsd.sfx for creating
self extracting archives.
.PARAMETER NoSFX
The default behavior of this module is to use both 7za and 7zsfx tools
The option provided by this parameter is when leaner builds are needed
to ensure smaller footprints when the use-case requires it.
.EXAMPLE
import-module .\7-Zip.psm1 -ArgumentList $True
This will omit all 7zip SFX archive portions of this module
.NOTES
ModuleName    : 7-Zip
Created by    : David Tawater
Date Coded    : 2021-07-29
.LINK
Official 7Zip: http://www.7-zip.org
.LINK
https://documentation.help/7-Zip/start.htm
#>

#Grab the initialization script and then dot source first
$private = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Private/Initialize-Module.ps1') -ErrorAction Stop)
try {
    . $private.FullName
} catch {
    throw "Unable to dot source Initialization script [$($private.FullName)]"
}

# Dot source classes and public/private functions
$classes = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Classes/*.ps1') -Recurse -ErrorAction Stop)
$public  = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Public/*.ps1')  -Recurse -ErrorAction Stop)
#Grab everything but the initialization script as its already dot sourced
$private = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Private/*.ps1') -Exclude 'Private/Initialize-Module.ps1' -Recurse -ErrorAction Stop)
foreach ($import in @($classes + $private + $public)) {
    try {
        . $import.FullName
    } catch {
        throw "Unable to dot source [$($import.FullName)]"
    }
}

Export-ModuleMember -Function $public.Basename
