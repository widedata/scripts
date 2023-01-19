function Get-UserFolderAccess
{
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline)]
        $user,

        [Parameter()]
        $FolderPath
    )

    Process
    {
        $NTDomain = (gwmi Win32_NTDomain).DomainName
        $groups = Get-ADPrincipalGroupMembership $user
        $RootFolder = Get-ChildItem -Directory -Path $FolderPath -Recurse -Force
        $Output = @()
        ForEach ($Folder in $RootFolder) {
            $Acl = Get-Acl -Path $Folder.FullName
            ForEach ($Access in $Acl.Access) {
        $Properties = [ordered]@{'Name'=$Folder.FullName;'IDRef'=$Access.IdentityReference.ToString().Replace("$NTDomain\","");'Permissions'=$Access.FileSystemRights;'Inherited'=$Access.IsInherited}
        $Output += New-Object -TypeName PSObject -Property $Properties            
        }
        }

        $output | where-object { $_.IDRef -in $groups.name } | select-object name,inherited | format-table -autosize
        
    }
}

Get-UserFolderAccess "wdcadmin" "C:\temp"
