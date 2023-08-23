Add-Type -AssemblyName System.Windows.Forms
. (Join-Path $PSScriptRoot 'show-chocolateyupdate.designer.ps1')
$Form1.ShowDialog()