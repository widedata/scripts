param
(
    [Parameter(ValueFromPipeline)]
    $User,

    [Parameter()]
    $FolderPath,

    [Parameter()]
    [switch]$GridView
)

function Get-UserFolderAccess
{
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline)]
        $User,

        [Parameter()]
        $FolderPath,

        [Parameter()]
        [switch]$GridView
    )

    Process
    {
        $NTDomain = (gwmi Win32_NTDomain).DomainName
        $memberships = Get-ADPrincipalGroupMembership $user
        $memberships += Get-ADUser $user
        $RootFolder = Get-ChildItem -Directory -Path $FolderPath -Recurse -Force
        $Output = @()
        ForEach ($Folder in $RootFolder) {
            $Acl = Get-Acl -Path $Folder.FullName
            ForEach ($Access in $Acl.Access) {
        $Properties = [ordered]@{'Name'=$Folder.FullName;'IDRef'=$Access.IdentityReference.ToString().Replace("$NTDomain\","");'Permissions'=$Access.FileSystemRights;'Inherited'=$Access.IsInherited}
        $Output += New-Object -TypeName PSObject -Property $Properties            
        }
        }

        $render = $output | where-object { $_.IDRef -in $memberships.SamAccountName } | select-object Name,IDRef,Permissions,Inherited

        If ($GridView) {
            $render | Out-GridView
        } else {
            $render | format-table -autosize
        }

    }
}

If ($GridView) {
    Get-UserFolderAccess $User $FolderPath -GridView
} else {
    Get-UserFolderAccess $User $FolderPath
}
