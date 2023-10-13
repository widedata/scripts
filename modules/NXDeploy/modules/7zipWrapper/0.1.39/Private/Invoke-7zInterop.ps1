function Invoke-7zInterop {
    [CmdletBinding()]
    #This (internal) function does the hard work: it calls 7-Zip with the appropriate arguments
    Param(
        # The operation to perform
        [Parameter(Mandatory)]
        [ValidateSet("New", "Add", "Update", "List", "Extract", "Test")]
        [string]$Operation,

        [ValidateSet('7z','zip','gzip','bzip2','tar','iso','udf')]
        [Alias("Type")]
        [string] $ArchiveType = '7z',

        # The path of the archive
        [Parameter(Mandatory)]
        [Alias("Path")]
        [string]$ArchivePath,

        # A list of file names or patterns to include
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Include,

        # A list of file names or patterns to exclude
        [Parameter(Mandatory=$false)]
        [AllowEmptyCollection()]
        [string[]]$Exclude,

        # Apply include patterns recursively
        [Parameter(Mandatory=$false)]
        [switch]$Recurse,

        # If given this will encrypt and secure the archive
        [Parameter(Mandatory=$false)]
        [SecureString]$Password,

        #during add operations Force overwrite of archive and start from empty file
        #during update operations overwrite individual files within archive
        [Parameter(Mandatory=$false)]
        [switch]$Force,

        # Additional switches for 7z
        [Parameter(Mandatory=$false)]
        [AllowEmptyString()]
        [string]$Switches,

        # Throw if the output does not contain "Everything is OK"
        [Parameter(Mandatory=$false)]
        [bool]$CheckOK = $true
    )

    $Arguments = [System.Collections.ArrayList]@()
    $fileMode = [System.Collections.ArrayList]@()

    switch ($Operation) {
        "New" { # New means the archive file will be recreated
            $verb = "Adding to new"
            $fileMode += "-mx9" # -mx9: Ultra compression
        }
        "Add" {
            $verb = "Adding to"
            $fileMode += "-mx9" # -mx9: Ultra compression
        }
        "Update" {
            $verb = "Updating"
            $fileMode += "-mx9" # -mx9: Ultra compression
        }
        "Extract" {
            $verb = "Extracting"
            if ( $PSBoundParameters.ContainsKey('Force') )  {
                $fileMode += "-aoa" #-aoa: Overwrite All existing files without prompt
            }
        }
        "List" {
            $verb = "Listing"
        }
        "Test" {
            $verb = "Testing"
        }
    }

    #Add the operation command to the switches
    $Arguments += $verb.Substring(0,1).ToLower()

    #Add the archive type to the switches
    $Arguments += '-t{0}' -f $ArchiveType

    #here is a quick fix for some the archive path that might be
    #double quoted too many times.  This might not be needed.
    $Arguments += ('"{0}"' -f $ArchivePath).Replace('""','"')

    # Set up switches to use.
    #These two switches are for unattended scenarios
    $Arguments += "-bd", "-y" # -bd: no percentage indicator; -y: Yes to all prompts


    Write-Debug -Message ('ParameterKey Recurse: {0}' -f $PSBoundParameters.ContainsKey('Recurse'))
    if ( $PSBoundParameters.ContainsKey('Recurse')  ) { $Arguments += "-r" } # -r: recurse parameter present

    Write-Debug -Message ('ParameterKey Password: {0}' -f $PSBoundParameters.ContainsKey('Password'))
    if ( $PSBoundParameters.ContainsKey('Password') ) { # -p: Password parameter present
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
        $pString = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        $Arguments += '"-p{0}"' -f $pString
        $pString = $null
        $fileMode += "-mhe" #Encrypt file headers in archive
    }

    #These are the file handler switches that manage what 7zip should do in
    #the event of filename conflicts. These switches need to go after the mode
    #and initial switches in the arguments array.
    #May need to research this switch for duplicate filenames in different folders
    #$fileMode += "-spf"  # -spf : Use fully qualified filenames
    $Arguments += $fileMode

    # Add excludes to the switches
    if ( $PSBoundParameters.ContainsKey('Exclude') -and $Exclude.Count -gt 0) { # Exclude file list parameter present
        $Arguments += $Exclude | ForEach-Object { '"-x!{0}"' -f $_ }
    }

    # Add includes to the switches
    $Arguments += $Include | ForEach-Object { '"-i!{0}"' -f $_ }

    #Add any explicitly passed parameters to the switches
    $Arguments += $Switches -split '\s+' | ForEach-Object { '{0}' -f $_ }

    #Spin up sub thread to run 7zip executable
    $pinfo = New-object System.Diagnostics.ProcessStartInfo
    $pinfo.CreateNoWindow = $true
    $pinfo.UseShellExecute = $false
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    $pinfo.FileName = $7zSettings.Path7zEXE
    $pinfo.Arguments = $Arguments
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $pinfo
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    Write-Debug -Message "============================================"
    Write-Debug -Message ('Standard Output: {0}' -f $stdout )
    Write-Debug -Message "============================================"
    Write-Debug -Message ('Error Output: {0}' -f $stderr )
    Write-Debug -Message "============================================"
    Write-Debug -Message ( "Exit Code: " + $process.ExitCode )
    Write-Debug -Message ( '7zip exe: {0}' -f ($7zSettings.Path7zEXE) )
    Write-Debug -Message 'Arguments: '
    $Arguments | ForEach-Object { Write-Debug -Message ('{0}' -f $_ )}
    Write-Debug -Message "============================================"

    # Check result
    if ($CheckOK) {
        $Err = "System ERROR: "
        $isBAD = ([string]$stdout).Contains($Err)
        $isOK  = ([string]$stdout).Contains("Everything is Ok")

        if (-not $isOK )  {
            [string]$errorMessage = '{0} archive failed.' -f $verb
            if ($isBAD) { $errorMessage = $stdout.Substring($stdout.IndexOf($Err) + 14 ) }

            Debug-ThrowException `
                -Message $errorMessage `
                -Verb $verb `
                -Path $ArchivePath `
                -Output ($stdout + "`r`n" + $stderr) `
                -LineNumber Get-CurrentLineNumber `
                -Filename Get-CurrentFileName `
                -Executable $7zSettings.Path7zEXE `
                -Exception ([System.InvalidOperationException]::new($errorMessage))

        }
    }

    # No error: return the 7-Zip output
    Write-Output $stdout
}
