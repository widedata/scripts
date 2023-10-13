Function Expand-7zArchive {
<#
    .SYNOPSIS
        Extract files fom a 7-Zip archive
    .DESCRIPTION
        Use this cmdlet to extract files from an existing 7-Zip archive
        Extracts files from an archive to the current directory or to the output
        directory. The output directory can be specified by -o switch.
        This command copies all extracted files to one directory. If you want
        extracted files with full paths, you must use x command.  7-Zip will
        prompt the user before overwriting existing files unless the user
        specifies the -y switch. If the user gives a no answer, 7-Zip will
        prompt for the file to be extracted to a new filename. Then a no answer
        skips that file; or, yes prompts for new filename.

    .EXAMPLE
        Expand-7zArchive backups.7z

        extracts all files from archive backups.7z to the current folder
    .EXAMPLE
        Expand-7zArchive -Path archive.zip -Destination "c:\soft" -Include "*.cpp" -recurse

        extracts all *.cpp files from archive archive.zip to c:\soft folder.
    .NOTES
    This function has not been updated yet.

    .LINK
    https://documentation.help/7-Zip/extract1.htm
#>
    [CmdletBinding()]
    Param(
        # The path of the archive to expand
        [Parameter(Mandatory=$true, Position=0)]
        [string]$ArchivePath,

        # The path to extract files to
        [Parameter(Mandatory=$false, Position=1)]
        [string]$Destination = ".",

        # A list of file names or patterns to include
        [Parameter(Mandatory=$false, ValueFromPipeLine=$true, Position=2)]
        [string[]]$Include = @("*"),

        # A list of file names or patterns to exclude
        [Parameter(Mandatory=$false)]
        [string[]]$Exclude = @(),

        #If specified apply password to archive and decrypt contents
        [SecureString]
        $Password,

        # Apply include patterns recursively
        [switch]$Recurse,

        # Additional switches for 7zip
        [string]$Switches = "",

        # Force overwriting existing files
        [switch]$Force
    )

    Begin {
        $Switches = $Switches + (' "-o{0}"' -f $Destination)
        if ($Force) {
            $Switches = $Switches + " -aoa" # Overwrite ALL
        } else {
            $Switches = $Switches + " -aos" # SKIP extracting existing files
        }

        $filesToProcess = @()
    }
    Process {
        $filesToProcess += $Include
    }

    End {

        [hashtable]$params = @{
            Operation = 'Extract'
            ArchivePath = $ArchivePath
            Include = $Include
            Exclude = $Exclude
            Switches = $Switches
        }
        if ( $PSBoundParameters.ContainsKey('Password') ) { # Password parameter present
            $params.Add('Password',$Password)
        }
        if ( $PSBoundParameters.ContainsKey('Force') ) { # Force parameter present
            $params.Add('Force',$true)
        }
        if ( $PSBoundParameters.ContainsKey('Recurse') ) { # Recurse parameter present
            $params.Add('Recurse',$true)
        }
        $params.GetEnumerator() | ForEach-Object { Write-Debug -Message ('{0}: {1}' -f ($_.Key), ($_.Value) ) }

        [string[]]$result = Invoke-7zInterop @params

        $result | ForEach-Object {
            if ($_.StartsWith("Skipping    ")) {
                Write-Warning $_
            }
        }
    }
}
