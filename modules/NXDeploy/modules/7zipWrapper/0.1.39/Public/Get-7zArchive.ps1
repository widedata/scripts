Function Get-7zArchive {
<#
    .SYNOPSIS
        List files fom a 7-Zip archive
    .DESCRIPTION
        Use this cmdlet to examine the contents of 7-Zip archives.
        Output is a list of PSCustomObjects with properties [string]Mode, [DateTime]DateTime, [int]Length, [int]Compressed and [string]Name
        options to add to this would be -slt to show technical info
    .EXAMPLE
        Get-7zArchive c:\temp\test.7z

        List the contents of the archive "c:\temp\test.7z"
    .NOTES
    This function has not been updated yet.
    .LINK
    https://documentation.help/7-Zip/list.htm
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    Param(
        # The name of the archive to list
        [Parameter(Mandatory=$true, Position=0)]
        [string]$ArchivePath,

        #If specified apply password to open archive
        [SecureString]
        $Password,

        # Additional switches
        [Parameter(Mandatory=$false)]
        [string]$Switches = ""
    )

    [hashtable]$params = @{
        Operation = 'List'
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

    [bool]$separatorFound = $false
    [int]$filecount = 0

    $result | ForEach-Object {
        if ($_.StartsWith("------------------- ----- ------------ ------------")) {
            if ($separatorFound) {
                # Second separator! We're done
                break
            }
            $separatorFound = -not $separatorFound
        } else {
            if ($separatorFound) {
                # 012345678901234567890123456789012345678901234567890123456789012345678901234567890
                # x-----------------x x---x x----------x x----------x  x--------------------
                # 2015-12-20 14:25:18 ....A        18144         2107  XMLClassGenerator.ini
                [string]$mode = $_.Substring(20, 5)
                [DateTime]$datetime = [DateTime]::ParseExact($_.Substring(0, 19), "yyyy'-'MM'-'dd HH':'mm':'ss", [CultureInfo]::InvariantCulture)
                [int]$length = [int]"0$($_.Substring(26, 12).Trim())"
                [int]$compressedlength = [int]"0$($_.Substring(39, 12).Trim())"
                [string]$name = $_.Substring(53).TrimEnd()

                # Write a PSCustomObject with properties to output
                Write-Output ([PSCustomObject] @{
                    Mode = $mode
                    DateTime = $datetime
                    Length = $length
                    Compressed = $compressedlength
                    Name = $name

                })
                $filecount++
            }
        }
    }
    Write-Debug ('filecount: {0}' -f $filecount)
}

