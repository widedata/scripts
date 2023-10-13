function Update-7zArchive() {
    <#
        .SYNOPSIS
            Update files in a 7-Zip archive
        .DESCRIPTION
            Use this cmdlet to update files to an existing 7-Zip archive. If the archive does not
            exist, it is created. Update-7zArchive will update older files in the archive and add
            files that are new to the archive.  This does not replace unchanged files within the
            archive, instead those files are skipped. This is for speed improvements.
        .EXAMPLE
            Update-7zArchive existing-archive *.txt

            Updates an existing 7-zip-archive named 'existing-archive.7z' with all files found
            having a .txt extension in the current directory that are newer than the files in the
            archive and all files that are not currently in the archive.
        .EXAMPLE
            Update-7zArchive existing-archive *.txt -ArchiveType zip

            Updates an existing zip-archive named 'existing-archive.zip' with all files found
            having a .txt extension in the current directory that are newer than the files in the
            archive and all files that are not currently in the archive.
        .EXAMPLE
            Update-7zArchive existing-archive *.jpg,*.gif,*.png,*.bmp -Recurse -Exclude tmp/

            Updates an existing 7-zip-archive named 'existing-archive.7z' with all files found
            having a jpg, gif, png or bmp extension in the current directory and all sub
            directories that are newer than the files in the archive and all files that are not
            currently in the archive.

            All files in the folder tmp are excluded, i.e. not included in the archive.
        .NOTES
        The current version of 7-Zip cannot change an archive which was created with the solid
        option switched on. To update a .7z archive you must create and update that archive
        only in non-solid mode (-ms=off switch).
        .LINK
        https://documentation.help/7-Zip/update.htm
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Low')]
    Param(
        # The path of the archive to update
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

        # The type of archive to update
        [ValidateSet('7z','zip','gzip','bzip2','tar','iso','udf')]
        [string]
        $ArchiveType = '7z',

        #If specified apply password to open and update this archive
        [SecureString]
        $Password,

        # Additional switches for 7zip (Feature intended for advanced usage)
        [string]$Switches,

        # Apply include patterns recursively
        [switch]$Recurse,

        [switch]
        $Force

    )

    if ($PSCmdlet.ShouldProcess("Update Archive")) {

        [hashtable]$params = @{
            Operation = 'Update'
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
}
