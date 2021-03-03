param(
[Parameter(Mandatory=$true,Position=1)]
[string]$fontFolder
)
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
Add-Type -AssemblyName PresentationCore

$hashFontFileTypes = @{}
$hashFontFileTypes.Add(".fon", "")
$hashFontFileTypes.Add(".fnt", "")
$hashFontFileTypes.Add(".ttf", " (TrueType)")
$hashFontFileTypes.Add(".ttc", " (TrueType)")
$hashFontFileTypes.Add(".otf", " (OpenType)")

foreach ($font in (Get-ChildItem "$fontFolder"))
{
    if(-Not(test-path -Path "C:\Windows\Fonts\$($font.Name)")) 
    {

        $fontName = (New-Object -TypeName Windows.Media.GlyphTypeface -ArgumentList $font.FullName).Win32FamilyNames.Values
	    $fontExt = $font.Extension
        $regKeyName = $fontName -join " "
        $regKeyValue = $font.Name

        Copy-Item $($font.FullName) "C:\Windows\Fonts" -Force 

        if (-not($hashFontFileTypes.ContainsKey($fontExt))) 
    	{
	    	Write-Host "File Extension Unsupported"
	    	$retVal = 0
    	}

        if ($retVal -eq 0)
    	{
            Write-Host "Font $($font.FullName) installation failed." -ForegroundColor Red
            Write-Host ""
            1
        }
        else
        {
            New-ItemProperty -Path $regPath -Name "$($fontName)$($hashFontFileTypes.$fontExt)" -Value $regKeyValue -Force -ErrorAction 'silentlycontinue'
            Write-Host "Font $($font.FullName) $($hashFontFileTypes.$fontExt) installed successfully." -ForegroundColor Green
        }
    }
}
