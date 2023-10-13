function Add-7zArchive() {
    <#
    .SYNOPSIS
        Create a new 7-Zip archive
    .DESCRIPTION
        Use this cmdlet to create 7-Zip archives. Possible types are 7z (default) as well as
        zip, gzip, bzip2, tar, iso, udf archive formats.  This needs testing...made usable
        The archive file is overwritten if it exists and the -force parameter is used
    .EXAMPLE
        New-7zArchive new-archive *.txt

        Creates a new 7-zip-archive named 'new-archive.7z' containing all files with a .txt extension
        in the current directory
    .EXAMPLE
        New-7zArchive new-archive *.txt -ArchiveType zip

        Creates a new zip-archive named 'new-archive.zip' containing all files with a .txt extension
        in the current directory
    .EXAMPLE
        New-7zArchive new-archive *.jpg,*.gif,*.png,*.bmp -Recurse -Exclude tmp/

        Creates a new 7-zip archive named 'new-archive.7z' containing all files with an extension
        of jpg, gif, png or bmp in the current directory and all directories below it

        All files in the folder tmp are excluded, i.e. not included in the archive.
    #>
    [CmdletBinding()]
    Param(
        # The path of the archive to create
        [Parameter(Mandatory, Position=0)]
        [string]
        $ArchivePath,

        # A list of file names or patterns to include
        [Parameter(Mandatory=$true, Position=1)]
        [string[]]
        $FilesToInclude,

        # A list of file names or patterns to exclude
        [Parameter(Mandatory=$false)]
        [AllowEmptyCollection()]
        [string[]]
        $FilesToExclude,

        # The type of archive to create
        [ValidateSet('7z','zip','gzip','bzip2','tar','iso','udf')]
        [string]
        $ArchiveType = '7z',

        #If specified apply password to archive and encrypt headers
        [SecureString]
        $Password,

        # Additional switches for 7zip (Feature intended for advanced usage)
        [string]$Switches,

        # Apply include patterns recursively
        [switch]$Recurse,

        [switch]
        $Force

    )

    [hashtable]$params = @{
        Operation = 'New'
        ArchiveType = $ArchiveType
        ArchivePath = $ArchivePath
        Include = $FilesToInclude
        Exclude = $FilesToExclude
        Switches = $Switches
        Recurse = $false
    }
    if ( $PSBoundParameters.ContainsKey('Password') ) { # Password parameter present
        $params['Password'] = $Password
    }
    if ( $PSBoundParameters.ContainsKey('Force') ) { # Force parameter present
        $params['Force'] = $true
    }
    if ( $PSBoundParameters.ContainsKey('Recurse') ) { # Recurse parameter present
        $params['Recurse'] = $true
    }
    $params.GetEnumerator() | ForEach-Object { write-debug -Message ('{0}: {1}' -f ($_.Key), ($_.Value) ) }


    [string[]]$result = Invoke-7zInterop @params

    return $result

}
