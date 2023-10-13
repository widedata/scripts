# Function that imports a list of settings to use from a CSV to update installers en masse

function Invoke-MassNXUpdate {
    param(
        [Parameter(Mandatory=$true)]
        [string]$msiPath,
        [Parameter(Mandatory=$true)]
        [string]$listPath,
        [Parameter(Mandatory=$true)]
        [string]$savePath
    )

    . $PSScriptRoot\Invoke-NXDeploy.ps1

    $ClientList = get-content $listPath | ConvertFrom-CSV

    foreach ($client in $ClientList) {
        Invoke-NXDeploy -msiPath $msiPath -installIdentifier $client.ID -vpnServer $client.Server -vpnDomain $client.Domain -outputDir $savePath
    }

}