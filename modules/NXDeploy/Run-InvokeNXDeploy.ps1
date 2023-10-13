# Prompt user for msi path
$msiPath = Read-Host "Enter the path to the msi file"

# Prompt user for Client abbreviation
$installIdentifier = Read-Host "Enter optional install identifier"

# Prompt user for VPN Server
$vpnServer = Read-Host "Enter the VPN Server"

# Prompt user for VPN Domain
$vpnDomain = Read-Host "Enter the VPN Domain"

# Prompt user for output directory or press enter for default
$outputDir = Read-Host "Enter the output directory or press enter for default"

Invoke-NXDeploy -msiPath $msiPath -installIdentifier $installIdentifier -vpnServer $vpnServer -vpnDomain $vpnDomain -outputDir $outputDir