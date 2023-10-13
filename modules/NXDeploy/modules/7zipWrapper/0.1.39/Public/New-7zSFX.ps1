Function New-7zSfx {
<#
    .SYNOPSIS
        Create a new 7-Zip self extracting archive
    .DESCRIPTION
        Create self-extracting archives using 7-Zip
    .EXAMPLE
        New-7zsfx app-sfx app.exe,app.exe.config app.exe

        Simply create a self-extracting exe from an executable file app.exe
        with its configuration file app.exe.config:
    .NOTES
        This might be omitted in later revisions as this sets off my
        sense of DSC flow and its old in its concept.  Since WinRM and
        DSC self expanding objects are a non starter.  I have included
        this for now but im reviewing security articles to determine
        use in different environments.

    .LINK
        https://documentation.help/7-Zip/sfx.htm
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Low')]
    Param(
        # The name of the exe-file to produce, without extension
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Path,

        # The files to include in the archive
        [Parameter(Mandatory=$true, Position=1)]
        [string[]]$Include,

        # The command to run when the sfx archive is started
        [Parameter(Mandatory=$true, Position=2)]
        [string]$CommandToRun,

        # Title for messages
        [Parameter(Mandatory=$false)]
        [string]$Title,

        # Begin Prompt message
        [Parameter(Mandatory=$false)]
        [string]$BeginPrompt,

        # Title of extraction dialog
        [Parameter(Mandatory=$false)]
        [string]$ExtractTitle,

        # Text in dialog
        [Parameter(Mandatory=$false)]
        [string]$ExtractDialogText,

        # Button text of cancel button
        [Parameter(Mandatory=$false)]
        [string]$ExtractCancelText,

        # A list of additional options, of the form "key=value"
        [Parameter(Mandatory=$false)]
        [string[]]$ConfigOptions,

        # Include subdirectories
        [switch]$Recurse,

        # Additional switches to pass to 7za when creating the archive
        [string]$Switches = ''
    )

    Begin {

        # Escape a variable for the config file
        Function Esc([string]$t) {
            # Prefix \ and " with \, replace CRLF with \n and TAB with \t
            Return $t.Replace('\', '\\').Replace('"', '\"').Replace("`r`n", '\n').Replace("`t", '\t')
        }

        # Get the base name of the specified path in Name
        if (-not [IO.Path]::IsPathRooted($Path)) {
            $Path = Join-Path "." $Path
        }
        # Then join the directory name with the file name exluding the extension
        [string]$Name = Join-Path ([IO.Path]::GetDirectoryName($Path)) ([IO.Path]::GetFileNameWithoutExtension($Path))

        [string]$tmpfile = "$Name.sfx.tmp"
        [Collections.ArrayList]$cfg = @()

        [string]$exefile = "$Name.exe"
        if (Test-Path -PathType Leaf "$exefile") { Remove-Item "$exefile" -Force }

    }

    Process {
        if ($PSCmdlet.ShouldProcess('Create Executable Archive')) {

            $null = New-7zArchive -ArchivePath $tmpfile -FilesToInclude $Include -FilesToExclude @() -ArchiveType 7z -Recurse:$Recurse -Switches $Switches

            # Copy sfx + archive + config to exe via bytestream

            #SFX Configuration File Header
            [void]$cfg.Add(";!@Install@!UTF-8!")
            #Title - title for messages
            [void]$cfg.Add('Title="{0}"' -f $Title)
            #RunProgram - Command for executing. Default value is "setup.exe". Substring %%T will be replaced with path to temporary folder, where files were extracted
            [void]$cfg.Add('RunProgram="{0}"' -f $(Esc($CommandToRun)))
            #BeginPrompt - Begin Prompt message
            if ($BeginPrompt -ne "")       { [void]$cfg.Add('BeginPrompt="{0}"' -f $(Esc($BeginPrompt))) }
            #ExtractTitle - title of extraction dialog
            if ($ExtractTitle -ne "")      { [void]$cfg.Add('ExtractTitle="{0}"' -f $(Esc($ExtractTitle))) }
            #ExtractDialogText - text in dialog
            if ($ExtractDialogText -ne "") { [void]$cfg.Add('ExtractDialogText="{0}"' -f $(Esc($ExtractDialogText))) }
            #ExtractCancelText - button text of cancel button
            if ($ExtractCancelText -ne "") { [void]$cfg.Add('ExtractCancelText="{0}"' -f $(Esc($ExtractCancelText))) }
            [void]$cfg.Add('GUIMode="1"')
            [void]$cfg.Add('MiscFlags="4"')
            #Progress - Value can be "yes" or "no". Default value is "yes".
            #Directory - Directory prefix for "RunProgram". Default value is ".\\"
            #ExecuteFile - Name of file for executing
            #ExecuteParameters - Parameters for "ExecuteFile"
            if ($null -ne $ConfigOptions) {
                $ConfigOptions | ForEach-Object {
                    [string[]]$parts = $_.Split('=')
                    if ($parts.Count -lt 2) {
                        throw "Invalid configuration option '$($_)': missing '='"
                    } else {
                        [void]$cfg.Add('{0}="{1}"' -f $($parts[0]), $(Esc($parts[1])))
                    }
                }
            }

            #SFX Configuration File Ending Suffix
            [void]$cfg.Add(';!@InstallEnd@!')


            Write-Verbose ('Creating sfx "{0}"...' -f $exefile)
            Write-Debug ($cfg | Join-String -Separator '`r`n')

            [string]$cfgfile = ( '{0}.sfx.config' -f $Name)

            Set-Content "$cfgfile" -Value $cfg
            $null = Update-7zArchive -ArchivePath "$tmpfile" -FilesToInclude "$cfgfile"
            Get-Content "$($7zSettings.Path7zSfx)","$cfgfile","$tmpfile" -AsByteStream -Raw | Set-Content "$exefile" -AsByteStream

            
        }
    }

    End {

        Remove-Item "$tmpfile"
        Remove-Item "$cfgfile"
    }
}

