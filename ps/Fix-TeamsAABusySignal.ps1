# Description: When creating auto-attendant the connection between the Resource Account and Auto Attendant 
# seemed to be dysfunctional. It seemed that Azure tries to initialize the virtual service that for 
# handling the Auto Attendant but fails to be properly linked. This manually creates the link so Azure
# can initialize the virtual

# *NOTE: This needs to be run interactively as it will prompt for credentials

Install-Module AzureAD
Install-Module MicrosoftTeams

Connect-AzureAD
Connect-MicrosoftTeams

Write-Host "Please type the Auto-Attendant account email."
$ResourceEmail = Read-Host '(i.e. autoattendantresource@mydomain.com)'
Write-Host "Please type The Auto Attendant Name (not the resource name)."
$AttendantName = '(i.e. Main Auto Attendant)'
If((Get-CSAutoAttendant -NameFilter $AttendantName).ApplicationInstances -ne "") {
    Write-Host "Application Instance not initialized. Attempting to create application association."
    $Operator = (Get-CsOnlineApplicationInstance $ResourceEmail).ObjectId
    $Attendant = (Get-CSAutoAttendant -NameFilter $AttendantName).Identity
    try {
        Get-CsOnlineApplicationInstanceAssociation -Identities $Operator -ConfigurationId $Attendant -ConfigurationType AutoAttendant
    } catch {
        Write-Host "Unable to create application association."
        Write-Host $Error[0].Exception
    }
} else {
Write-Host "Application Instance has already been initialized. No action taken."
}
