# This script will force the usage of Modern Auth by Windows (not just Office)
# TODO: Autodetect version(s) of Outlook and run for one/all

if((Test-Path -LiteralPath "HKCU:\Software\Microsoft\Office\16.0\Common\Identity") -ne $true) {  New-Item "HKCU:\Software\Microsoft\Office\16.0\Common\Identity" -force -ea SilentlyContinue };
if((Test-Path -LiteralPath "HKCU:\Software\Microsoft\Exchange") -ne $true) {  New-Item "HKCU:\Software\Microsoft\Exchange" -force -ea SilentlyContinue };
New-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Office\16.0\Common\Identity' -Name 'Version' -Value 1 -PropertyType DWord -Force -ea SilentlyContinue;
New-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Office\16.0\Common\Identity' -Name 'EnableADAL' -Value 1 -PropertyType DWord -Force -ea SilentlyContinue;
New-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Exchange' -Name 'AlwaysUseMSOAuthForAutoDiscover' -Value 1 -PropertyType DWord -Force -ea SilentlyContinue;
