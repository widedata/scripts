param(
[Parameter(Mandatory=$true,Position=1)]
[string]$fontFolder
)
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
Add-Type -AssemblyName PresentationCore

foreach ($font in (Get-ChildItem "$fontFolder"))
{
        $fontName = (New-Object -TypeName Windows.Media.GlyphTypeface -ArgumentList $font.VersionInfo.FileName).Win32FamilyNames.Values
        $regKeyName = $fontName -join " "
        $regKeyValue = $font.Name

        Copy-Item $font "C:\Windows\Fonts" -Force -ErrorAction 'silentlycontinue'
	
        New-ItemProperty -Path $regPath -Name $regKeyName -Value $regKeyValue -Force -ErrorAction 'silentlycontinue'

}
