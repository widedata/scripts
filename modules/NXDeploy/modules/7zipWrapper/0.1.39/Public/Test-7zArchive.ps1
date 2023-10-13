Function Test-7zArchive {
<#
    .SYNOPSIS
        Test files a 7-Zip archive.
    .DESCRIPTION
        Use this cmdlet to test 7-Zip archives for errors
    .EXAMPLE
        Test-7zArchive c:\temp\test.7z

        Test the archive "c:\temp\test.7z". Throw an error if any errors are found
    .NOTES
        This function has not been updated yet.
    .LINK
        https://documentation.help/7-Zip/list.htm
#>
    [CmdletBinding()]
    Param(
        # The name of the archive to test
        [Parameter(Mandatory=$true, Position=0)]
        [string]$ArchivePath,

        #If specified apply password to open archive
        [SecureString]
        $Password,

        # Additional switches
        [Parameter(Mandatory=$false, Position=1)]
        [String]$Switches = ""
    )

    [hashtable]$params = @{
        Operation = 'Test'
        ArchivePath = $ArchivePath
        Include = @()
        Exclude = @()
        Switches = $Switches
        CheckOK = $false
    }
    if ( $PSBoundParameters.ContainsKey('Password') ) { # Password parameter present
        $params.Add('Password',$Password)
    }

    $params.GetEnumerator() | ForEach-Object { Write-Debug -Message ('{0}: {1}' -f ($_.Key), ($_.Value) ) }

    [string[]]$result = Invoke-7zInterop @params

    # Check result
    if ($result.Contains("No files to process")) {
        Write-Verbose "Archive is empty"
        return $result
    }

    if ($result.Contains("cannot find archive")) {
        throw "Archive `"$Path`" not found"
    }

    if ($result.Contains("Everything is Ok")) {
        Write-Verbose "Archive is OK"
        return $result
    }

    # In all other cases, we have an error. Write out the results Verbose
    $result | Write-Verbose
    # ... and throw an error
    throw "Testing archive `"$ArchivePath`" failed: $result"
}
