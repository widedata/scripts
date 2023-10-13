# Copyright WebMD Health Services
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License

#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

# Functions should use $moduleRoot as the relative root from which to find
# things. A published module has its function appended to this file, while a 
# module in development has its functions in the Functions directory.
$moduleRoot = $PSScriptRoot

# Store each of your module's functions in its own file in the Functions 
# directory. On the build server, your module's functions will be appended to 
# this file, so only dot-source files that exist on the file system. This allows
# developers to work on a module without having to build it first. Grab all the
# functions that are in their own files.
$functionsPath = Join-Path -Path $moduleRoot -ChildPath 'Functions\*.ps1'
if( (Test-Path -Path $functionsPath) )
{
    foreach( $functionPath in (Get-Item $functionsPath) )
    {
        . $functionPath.FullName
    }
}



function Get-CInstalledProgram
{
    <#
    .SYNOPSIS
    Gets information about the programs installed on the computer.

    .DESCRIPTION
    The `Get-CInstalledProgram` function is the PowerShell equivalent of the Programs and Features/Apps and Features
    settings UI. It inspects the registry to determine what programs are installed. When running as an administrator, it
    returns programs installed for *all* users, not just the current user.

    The function looks in the following registry keys for install information:

    * HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall
    * HKEY_LOCAL_MACHINE\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall
    * HKEY_USERS\*\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'

    A key is skipped if:

    * it doesn't have a `DisplayName` value.
    * it has a `ParentKeyName` value.
    * it has a `SystemComponent` value and its value is `1`.

    `Get-CInstalledProgram` tries its best to get accurate data. The following properties either aren't stored
    consistently, is in strange formats, can't be parsed, etc.

    * The `ProductCode` property is set to `[Guid]::Empty` if the software doesn't have a product code.
    * The `User` property will only be set for software installed for specific users. For global software, the `User`
      property will be `[String]::Empty`.
    * The `InstallDate` property is set to `[DateTime]::MinValue` if the install date can't be determined.
    * The `Version` property is `$null` if the version can't be parsed.

    .EXAMPLE
    Get-CInstalledProgram | Sort-Object 'DisplayName'

    Demonstrates how to get a list of all the installed programs, similar to what the Programs and Features settings UI
    shows. The returned objects are not sorted, so you'll usually want to pipe the output to `Sort-Object`.

    .EXAMPLE
    Get-CInstalledProgram -Name 'Google Chrome'

    Demonstrates how to get a specific program. If the specific program isn't found, `$null` is returned.

    .EXAMPLE
    Get-CInstalledProgram -Name 'Microsoft*'

    Demonstrates that you can use wildcards to search for programs.
    #>
    [CmdletBinding()]
    param(
        # The name of a specific program to get. Wildcards supported.
        [String] $Name
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -Session $ExecutionContext.SessionState

    function Get-KeyStringValue
    {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [Microsoft.Win32.RegistryKey] $Key,

            [Parameter(Mandatory)]
            [String] $ValueName
        )

        $value = $Key.GetValue($ValueName)
        if( $null -eq $value )
        {
            return ''
        }
        return $value.ToString()
    }

    function Get-KeyIntValue
    {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [Microsoft.Win32.RegistryKey] $Key,

            [Parameter(Mandatory)]
            [String] $ValueName
        )

        [int] $value = 0
        $rawValue = $Key.GetValue($ValueName)
        if( [int]::TryParse([Convert]::ToString($rawValue), [ref]$value) )
        {
            return $value
        }

        return 0
    }

    if( -not (Test-Path -Path 'hku:\') )
    {
        $null = New-PSDrive -Name 'HKU' -PSProvider Registry -Root 'HKEY_USERS' -WhatIf:$false
    }

    $keys = & {
        Get-ChildItem -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
        Get-ChildItem -Path 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
        Get-ChildItem -Path 'hku:\*\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction Ignore
    }

    $programs = $null
    & {
        foreach( $key in $keys )
        {
            $valueNames = [Collections.Generic.Hashset[String]]::New($key.GetValueNames())

            if( -not $valueNames.Contains('DisplayName') )
            {
                continue
            }

            $displayName = $key.GetValue('DisplayName')
            if( $Name -and $displayName -notlike $Name )
            {
                continue
            }

            if( $valueNames.Contains('ParentKeyName') )
            {
                continue
            }

            if( $valueNames.Contains('SystemComponent') )
            {
                continue
            }

            $systemComponent = $key.GetValue('SystemComponent')
            if( $systemComponent -eq 1 )
            {
                continue
            }

            $info = [pscustomobject]@{
                Comments = Get-KeyStringValue -Key $key -ValueName 'Comments';
                Contact = Get-KeyStringValue -Key $key -ValueName 'Contact';
                DisplayName = $displayName;
                DisplayVersion = Get-KeyStringValue -Key $key -ValueName 'DisplayVersion';
                EstimatedSize = Get-KeyIntValue -Key $key -ValueName 'EstimatedSize';
                HelpLink = Get-KeyStringValue -Key $key -ValueName 'HelpLink';
                HelpTelephone = Get-KeyStringValue -Key $key -ValueName 'HelpTelephone';
                InstallDate = $null;
                InstallLocation = Get-KeyStringValue -Key $key -ValueName 'InstallLocation';
                InstallSource = Get-KeyStringValue -Key $key -ValueName 'InstallSource';
                Key = $key;
                Language = Get-KeyIntValue -Key $key -ValueName 'Language';
                ModifyPath = Get-KeyStringValue -Key $key -ValueName 'ModifyPath';
                Path = Get-KeyStringValue -Key $key -ValueName 'Path';
                ProductCode = $null;
                Publisher = Get-KeyStringValue -Key $key -ValueName 'Publisher';
                Readme = Get-KeyStringValue -Key $key -ValueName 'Readme';
                Size = Get-KeyStringValue -Key $key -ValueName 'Size';
                UninstallString = Get-KeyStringValue -Key $key -ValueName 'UninstallString';
                UrlInfoAbout = Get-KeyStringValue -Key $key -ValueName 'URLInfoAbout';
                UrlUpdateInfo = Get-KeyStringValue -Key $key -ValueName 'URLUpdateInfo';
                User = $null;
                Version = $null;
                VersionMajor = Get-KeyIntValue -Key $key -ValueName 'VersionMajor';
                VersionMinor = Get-KeyIntValue -Key $key -ValueName 'VersionMinor';
                WindowsInstaller = $false;
            }
            $info | Add-Member -Name 'Name' -MemberType AliasProperty -Value 'DisplayName'

            $installDateValue = Get-KeyStringValue -Key $key -ValueName 'InstallDate'
            [DateTime] $installDate = [DateTime]::MinValue
            if( [DateTime]::TryParse($installDateValue, [ref]$installDate) -or
                [DateTime]::TryParseExact($installDateValue, 'yyyyMMdd', [cultureinfo]::CurrentCulture,
                                            [Globalization.DateTimeStyles]::None, [ref]$installDate)
            )
            {
                $info.InstallDate = $installDate
            }

            [Guid]$productCode = [Guid]::Empty
            $keyName = [IO.Path]::GetFileName($key.Name)
            if( [Guid]::TryParse($keyName, [ref]$productCode) )
            {
                $info.ProductCode = $productCode
            }

            if( $key.Name -match '^HKEY_USERS\\([^\\]+)\\')
            {
                $info.User = $Matches[1]
                $numErrors = $Global:Error.Count
                try
                {
                    $sid = [Security.Principal.SecurityIdentifier]::New($user)
                    if( $sid.IsValidTargetType([Security.Principal.NTAccount]))
                    {
                        $ntAccount = $sid.Translate([Security.Principal.NTAccount])
                        if( $ntAccount )
                        {
                            $info.User = $ntAccount.Value
                        }
                    }
                }
                catch
                {
                    for( $idx = $numErrors; $idx -lt $Global:Error.Count; ++$idx )
                    {
                        $Global:Error.RemoveAt(0)
                    }
                }
            }

            $intVersion = Get-KeyIntValue -Key $key -ValueName 'Version'
            if( $intVersion )
            {
                $major = $intVersion -shr 24 # first 8 bits are major version number
                $minor = ($intVersion -band 0x00ff0000) -shr 16 # bits 9 - 16 are the minor version number
                $build = $intVersion -band 0x0000ffff # last 16 bits are the build number
                $rawVersion = "$($major).$($minor).$($build)"
            }
            else
            {
                $rawVersion = Get-KeyStringValue -Key $key -ValueName 'Version'
            }

            [Version]$version = $null
            if( [Version]::TryParse($rawVersion, [ref]$version) )
            {
                $info.Version = $version
            }

            $windowsInstallerValue = Get-KeyIntValue -Key $key -ValueName 'WindowsInstaller'
            $info.WindowsInstaller = ($windowsInstallerValue -gt 0)

            $info.pstypenames.Insert(0, 'Carbon.Windows.Installer.ProgramInfo')
            $info | Write-Output
        }
    } |
    Tee-Object -Variable 'programs' |
    Sort-Object -Property 'DisplayName'

    if( $Name -and -not [wildcardpattern]::ContainsWildcardCharacters($Name) -and -not $programs )
    {
        $msg = "Program ""$($Name)"" is not installed."
        Write-Error -Message $msg -ErrorAction $ErrorActionPreference
    }
}



function Get-CMsi
{
    <#
    .SYNOPSIS
    Gets information from an MSI.

    .DESCRIPTION
    The `Get-CMsi` function uses the `WindowsInstaller.Installer` COM API to read properties from an MSI file. Pass the
    path to the MSI file or files to the `Path`, or pipe file objects to `Get-CMsi`. An object is returned that exposes
    the internal metadata of the MSI file:

    * `ProductName`, the value of the MSI's `ProductName` property.
    * `ProductCode`, the value of the MSI's `ProductCode` property as a `Guid`.
    * `ProductLanguage`, the value of the MSI's `ProduceLanguage` property, as an integer.
    * `Manufacturer`, the value of the MSI's `Manufacturer` property.
    * `ProductVersion`, the value of the MSI's `ProductVersion` property, as a `Version`
    * `Path`, the path of the MSI file.
    * `TableNames`: the names of all the tables in the MSI's internal database
    * `Tables`: records from tables in the MSI's internal database

    The function can also return the records from the MSI's internal database tables. Tables included are returned as
    properties on the return object's `Tables` property. It is expensive to read all the records in all the database
    tables, so by default, `Get-CMsi` only returns the records from the `Property` and `Feature` tables. The `Property`
    table contains program metadata like product name, product code, etc. The `Feature` table contains the feature names
    of any optional features you might want to install. When installing, these feature names would get passed to the
    `msiexec` install command as a comma-separated list as the `ADDLOCAL` property, e.g. ADDLOCAL="Feature1,Feature2".

    To return the records from additional tables, pass the table name or names to the `IncludeTable` parameter.
    Wildcards supported. Records from the `Property` and `Feature` tables are *always* returned. The `TableNames`
    property on returned objects is the list of all tables in the MSI's database.

    Because this function uses the Windows Installer COM API, it requires Windows PowerShell 5.1 or PowerShell 7.1+ on
    Windows.

    .LINK
    https://msdn.microsoft.com/en-us/library/aa370905.aspx

    .EXAMPLE
    Get-CMsi -Path MyCool.msi

    Demonstrates how to get information from an MSI file.

    .EXAMPLE
    Get-ChildItem *.msi -Recurse | Get-CMsi

    Demonstrates that you can pipe file info objects into `Get-CMsi`.

    .EXAMPLE
    Get-CMsi -Path example.msi -IncludeTable 'Component'

    Demonstrates how to return records from one of an MSI's internal database tables by passing the table name to the
    `IncludeTable` parameter. Wildcards supported.

    .EXAMPLE
    Get-CMsi -Url 'https://example.com/example.msi'

    Demonstrates how to download an MSI file to read its metadata. The file is saved to the current user's temp
    directory with the same name as the file name in the URL. The return object will have the path to the MSI file.

    .EXAMPLE
    Get-CMsi -Url 'https://example.com/example.msi' -OutputPath '~\Downloads'

    Demonstrates how to download an MSI file and save it to a directory using the name of the file from the download
    URL as the filename. In this case, the file will be saved to `~\Downloads\example.msi`. The return object's `Path`
    property will contain the full path to the downloaded MSI file.

    .EXAMPLE
    Get-CMsi -Url 'https://example.com/example.msi' -OutputPath '~\Downloads\new_example.msi'

    Demonstrates how to use a custom file name for the downloaded file by making `OutputPath` be a path to an item that
    doesn't exist or the path to an existing file.
    #>
    [CmdletBinding(DefaultParameterSetName='ByPath')]
    param(
        # Path to the MSI file whose information to retrieve. Wildcards supported.
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName='ByPath',
                   Position=0)]
        [Alias('FullName')]
        [String[]] $Path,

        # The URL to the MSI file to get. The file will be downloaded to the current user's temp directory. Use the
        # `OutputPath` parameter to save it somewhere else or use the `Path` property on the returned object to copy the
        # downloaded file somewhere else.
        [Parameter(Mandatory, ParameterSetName='ByUrl')]
        [Uri] $Url,

        # The path where the downloaded MSI file should be saved. By default, the file is downloaded to the current
        # user's temp directory. If `OutputPath` is a directory, the file will be saved to that directory with the
        # same name as file's name in the `Url`. Otherwise, `OutputPath` is considered to be the path to the file where
        # the downloaded MSI should be saved. Any existing file will be overwritten.
        [Parameter(ParameterSetName='ByUrl')]
        [String] $OutputPath,

        # Extra tables to read from the MSI and return. By default, only the installer's Property and Feature tables
        # are returned. Wildcards supported. See https://docs.microsoft.com/en-us/windows/win32/msi/database-tables for
        # the list of all MSI database tables.
        [String[]] $IncludeTable
    )

    begin
    {
        Set-StrictMode -Version 'Latest'
        Use-CallerPreference -Cmdlet $PSCmdlet -Session $ExecutionContext.SessionState

        $timer = [Diagnostics.Stopwatch]::StartNew()
        $lastWrite = [Diagnostics.Stopwatch]::New()
        function Debug
        {
            param(
                [String] $Message
            )

            $msg = "[$([Math]::Round($timer.Elapsed.TotalMinutes))m $($timer.Elapsed.Seconds.toString('00'))s " +
                   "$($timer.Elapsed.Milliseconds.ToString('000'))ms]  " +
                   "[$([Math]::Round($lastWrite.Elapsed.TotalSeconds).ToString('00'))s " +
                   "$($lastWrite.Elapsed.Milliseconds.ToString('000'))ms]  $($Message)"
            Microsoft.PowerShell.Utility\Write-Debug -Message $msg
            $lastWrite.Restart()
        }

        if( $PSCmdlet.ParameterSetName -eq 'ByUrl' )
        {
            $msiFileName = $Url.Segments[-1]
            if( $OutputPath )
            {
                if( (Test-Path -Path $OutputPath -PathType Container) )
                {
                    $OutputPath = Join-Path -Path $OutputPath -ChildPath $msiFileName
                }
            }
            else
            {
                $OutputPath = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath $msiFileName
            }
            $ProgressPreference = [Management.Automation.ActionPreference]::SilentlyContinue
            Invoke-WebRequest -Uri $Url -OutFile $OutputPath | Out-Null
            Get-Item -LiteralPath $OutputPath | Get-CMsi -IncludeTable $IncludeTable
            return
        }

        $IncludeTable = & {
            'Feature'
            'Property'
            $IncludeTable | Write-Output
        } | Select-Object -Unique
    }

    process
    {
        if( $PSCmdlet.ParameterSetName -eq 'ByUrl' )
        {
            return
        }

        $Path = Resolve-Path -Path $Path | Select-Object -ExpandProperty 'ProviderPath'
        if( -not $Path )
        {
            return
        }

        foreach( $msiPath in $Path )
        {
            $info = [pscustomobject]@{
                Manufacturer = $null;
                Path = $null;
                ProductCode = $null;
                ProductLanguage = $null;
                ProductName = $null;
                ProductVersion = $null;
                TableNames = @();
                Tables = [pscustomobject]@{};
            }
            $info |
                Add-Member -Name 'Name' -MemberType AliasProperty -Value 'ProductName' -PassThru |
                Add-Member -Name 'Property' -MemberType 'ScriptProperty' -Value { $this.Tables.Property } -PassThru |
                Add-Member -Name 'GetPropertyValue' -MemberType 'ScriptMethod' -Value {
                    param(
                        [Parameter(Mandatory)]
                        [String] $Name
                    )

                    if( -not $this.Property )
                    {
                        return
                    }

                    $this.Property | Where-Object 'Property' -eq $Name | Select-Object -ExpandProperty 'Value'
                }

            $installer = New-Object -ComObject 'WindowsInstaller.Installer'

            $database = $null
            Debug "[$($PSCmdlet.MyInvocation.MyCommand.Name)]  Opening ""$($msiPath)""."
            try
            {
                $database = $installer.OpenDatabase($msiPath, 0)
                if( -not $database )
                {
                    $msg = "$($msiPath): failed to open database."
                    Write-Error -Message $msg -ErrorAction $ErrorActionPreference
                    continue
                }
            }
            catch
            {
                $msg = "Exception opening MSI database in file ""$($msiPath)"": $($_)"
                Write-Error -Message $msg -ErrorAction $ErrorActionPreference
                continue
            }

            try
            {
                Debug '    _Tables'
                $tables = Read-CMsiTable -Database $database -Name '_Tables' -MsiPath $msiPath
                $info.TableNames = $tables | Select-Object -ExpandProperty 'Name'

                foreach( $tableName in $info.TableNames )
                {
                    $info.Tables | Add-Member -Name $tableName -MemberType NoteProperty -Value @()
                    if( $IncludeTable -and -not ($IncludeTable | Where-Object { $tableName -like $_ }) )
                    {
                        Debug "  ! $($tableName)"
                        continue
                    }

                    Debug "    $($tableName)"
                    $info.Tables.$tableName = Read-CMsiTable -Database $database -Name $tableName -MsiPath $msiPath
                }

                [Guid] $productCode = [Guid]::Empty
                [String] $rawProductCode = $info.GetPropertyValue('ProductCode')
                if( [Guid]::TryParse($rawProductCode, [ref]$productCode) )
                {
                    $info.ProductCode = $productCode
                }

                [int] $langID = 0
                [String] $rawLangID = $info.GetPropertyValue('ProductLanguage')
                if( [int]::TryParse($rawLangID, [ref]$langID) )
                {
                    $info.ProductLanguage = $langID
                }

                $info.Path = $msiPath;
                $info.Manufacturer = $info.GetPropertyValue('Manufacturer')
                $info.ProductName = $info.GetPropertyValue('ProductName')
                $info.ProductVersion = $info.GetPropertyValue('ProductVersion')

                [void]$info.pstypenames.Insert(0, 'Carbon.Windows.Installer.MsiInfo')
            }
            finally
            {
                $collect = $false
                if( $database )
                {
                    [void][Runtime.InteropServices.Marshal]::ReleaseCOMObject($database)
                    $collect = $true
                }

                if( $installer )
                {
                    [void][Runtime.InteropServices.Marshal]::ReleaseCOMObject($installer)
                    $collect = $true
                }

                if( $collect )
                {
                    # ReleaseCOMObject still leaves the MSI file open. The only way to close the file handle is to run
                    # garbage collection, and even then it takes a few seconds. :(
                    Debug "[GC]::Collect()  START"
                    [GC]::Collect()
                    Debug "[GC]::Collect()  END"
                }
            }

            # It can take some milliseconds for the COM file handles to get closed. In my testing, about 10 to 30
            # milliseconds. I give it 100ms just to be safe. But don't keep trying because something else might
            # legitimately have the file open. 100ms is the longest something can take without a human wondering what's
            # taking so long.
            $timer = [Diagnostics.Stopwatch]::StartNew()
            $numAttempts = 1
            $maxTime = [TimeSpan]::New(0, 0, 0, 0, 100)
            while( $timer.Elapsed -lt $maxTime )
            {
                $numErrors = $Global:Error.Count
                try
                {
                    # Wait until the file handle held by the WindowsInstaller COM objects is closed.
                    [IO.File]::Open($msiPath, 'Open', 'Read', 'None').Close()
                    break
                }
                catch
                {
                    ++$numAttempts
                    for( $numErrors; $numErrors -lt $Global:Error.Count; ++$numErrors )
                    {
                        $Global:Error.RemoveAt(0)
                    }
                    Start-Sleep -Milliseconds 1
                }
            }
            $timer.Stop()
            $msg = "Took $($numAttempts) attempt(s) in " +
                   "$($timer.Elapsed.TotalSeconds.ToString('0.000'))s for handle to ""$($msiPath)"" to close."
            Debug $msg
            $info | Write-Output
        }
    }
}



function Install-CMsi
{
    <#
    .SYNOPSIS
    Installs an MSI.

    .DESCRIPTION
    `Install-CMsi` installs software from an MSI file, without displaying any user interface. Pass the path to the MSI
    to install to the `Path` property. The `Install-CMsi` function reads the product name code from the MSI file, and
    does nothing if a program with that product code is already installed. Otherwise, the function runs the installer in
    quiet mode (i.e. no UI is visible) with `msiexec`. All the program's features will be installed with their default
    values. You can control the installer's display mode with the `DisplayMode` parameter: set it to `Passive` to show a
    UI with just a progress bar, or `Full` to show the UI as-if the user double-clicked the MSI file.

    `Install-CMsi` can also download an MSI and install it. Pass the URL to the MSI file to the `Url` parameter. Pass
    the MSI file's SHA256 checksum to the `Checksum` parameter. (Use PowerShell's `Get-FileHash` cmdlet to get the
    checksum.) In order avoid downloading an MSI that is already installed, you must also pass the MSI's product name to
    the `ProductName` parameter and its product code to the `ProductCode` parameter. Use this module's `Get-CMsi`
    function to get an MSI file's product metadata.

     If the install fails, the function writes an error and leaves a debug-level log file in the current user's temp
     directory. The log file name begins with the name of the MSI file name, then has a `.`, then a random file name
     (e.g. `xxxxxxxx.xxx`), then ends with a `.log` extension. You can customize the location of the log file with the
     `LogPath` parameter. You can customize logging options with the `LogOption` parameter. Default log options are
    `!*vx` (log all messages, all verbose message, all debug messages, and flush each line to the log file as it is
    written).

    If you want to install the MSI even if it is already installed, use the `-Force` switch. For downloaded MSI files,
    this will cause the file to be downloaded every time `Install-CMsi` is run.

    You can pass additional arguments to `msiexec.exe` when installing the MSI file with the `ArgumentList` parameter.

    Requires Windows PowerShell 5.1 or PowerShell 7.1+ on Windows.

    .EXAMPLE
    Install-CMsi -Path '.\Path\to\installer.msi'

    Demonstrates how to install a program with its MSI.

    .EXAMPLE
    Get-ChildItem *.msi | Install-CMsi

    Demonstrates that you can pipe file objects to `Install-CMsi`.

    .EXAMPLE
    Install-CMsi -Path 'installer.msi' -Force

    Demonstrates how to re-install an MSI file even if it's already installed.

    .EXAMPLE
    Install-CMsi -Url 'https://example.com/installer.msi' -Checksum '63c34def9153659a825757ec475a629dff5be93d0f019f1385d07a22a1df7cde' -ProductName 'Carbon Test Installer' -ProductCode 'e1724abc-a8d6-4d88-bbed-2e077c9ae6d2'

    Demonstrates that `Install-CMsi` can download and install MSI files.
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName='ByPath')]
    param(
        # The path to the installer to run. Wildcards supported.
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName='ByPath')]
        [Alias('FullName')]
        [string[]] $Path,

        # The URL to an installer to download and install. Requires the `Checksum` parameter to ensure the correct file
        # was downloaded.
        [Parameter(Mandatory, ParameterSetName='ByUrl')]
        [Uri] $Url,

        # Used with the `Url` parameter. The SHA256 hash the downloaded installer should have. Case-insensitive.
        [Parameter(Mandatory, ParameterSetName='ByUrl')]
        [String] $Checksum,

        # The product name of the downloaded MSI. Used to determine if the program is installed or not. Used with the
        # `Url` parameter. The installer is only downloaded if the product is not installed or the `-Force` switch is
        # used. Use the `Get-CMsi` function to get the product code of an MSI.
        [Parameter(Mandatory, ParameterSetName='ByUrl')]
        [String] $ProductName,

        # The product code of the downloaded MSI. Used to determine if the program is installed or not. Used with the
        # `Url` parameter. The installer is only downloaded if the product is not installed or the `-Force` switch is
        # used. Use the `Get-CMsi` function to get the product code from an MSI.
        [Parameter(Mandatory, ParameterSetName='ByUrl')]
        [Guid] $ProductCode,

        # Install the MSI even if it has already been installed. Will cause a repair/reinstall to run.
        [Switch] $Force,

        # Controls how the MSI UI is displayed to the user. The default is `Quiet`, meaning no UI is shown. Valid values
        # are `Passive`, a UI showing a progress bar is shown, or `Full`, the UI is displayed to the user as if they
        # double-clicked the MSI file.
        [ValidateSet('Quiet', 'Passive', 'Full')]
        [String] $DisplayMode = 'Quiet',

        # The logging options to use. The default is to log all information (`*`), log verbose output (`v`), log extra
        # debugging information (`x`), and to flush each line to the log (`!`).
        [String] $LogOption = '!*vx',

        # The path to the log file. The default is to log to a file in the temporary directory and delete the log file
        # unless the installation fails. The default log file name begins with the name of the MSI file name, then
        # has a `.`, then a random file name (e.g. `xxxxxxxx.xxx`), then ends with a `.log` extension.
        [String] $LogPath,

        # Extra arguments to pass to the installer. These are passed directly after the install option and path to the
        # MSI file. Do not pass any install option, display option, or logging option in this parameter. Instead, use
        # the `DisplayMode` parameter to control display options, the `LogOption` parameter to control logging options,
        # and the `LogPath` parameter to control where the installation log file is saved.
        [String[]] $ArgumentList
    )

    process
    {
        Set-StrictMode -Version 'Latest'
        Use-CallerPreference -Cmdlet $PSCmdlet -Session $ExecutionContext.SessionState

        function Test-ProgramInstalled
        {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory)]
                [String] $Name,

                [Guid] $Code
            )

            $DebugPreference = 'SilentlyContinue'
            $installInfo = Get-CInstalledProgram -Name $Name -ErrorAction Ignore
            if( -not $installInfo )
            {
                return $false
            }

            $installed = $installInfo.ProductCode -eq $Code
            if( $installed )
            {
                $msg = "$($msgPrefix)[$($installInfo.DisplayName)]  Installed $($installInfo.InstallDate)."
                Write-Verbose -Message $msg
                return $true
            }

            return $false
        }

        function Invoke-Msiexec
        {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory, ValueFromPipeline)]
                [Object] $Msi,

                [String] $From
            )

            process
            {
                $target = $Msi.ProductName
                if( $Msi.Manufacturer )
                {
                    $target = "$($Msi.Manufacturer)'s ""$($target)"""
                }

                if( $Msi.ProductVersion )
                {
                    $target = "$($target) $($Msi.ProductVersion)"
                }

                $deleteLog = $false
                if( -not $LogPath )
                {
                    $LogPath = "$($Msi.Path | Split-Path -Leaf).$([IO.Path]::GetRandomFileName()).log"
                    $LogPath = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath $LogPath
                    $deleteLog = $true
                }
                $logParentDir = $LogPath | Split-Path -Parent
                if( $logParentDir -and -not (Test-Path -Path $logParentDir) )
                {
                    New-Item -Path $logParentDir -Force -ItemType 'Directory' | Out-Null
                }
                if( -not (Test-Path -Path $LogPath) )
                {
                    New-Item -Path $LogPath -ItemType 'File' | Out-Null
                }

                if( -not $From )
                {
                    $From = $Msi.Path
                }

                $displayOptions = @{
                    'Quiet' = '/quiet';
                    'Passive' = '/passive';
                    'Full' = '';
                }

                $ArgumentList = & {
                    '/i'
                    # Must surround with double quotes. Single quotes are interpreted as part of the path.
                    """$($msi.Path)"""
                    $displayOptions[$DisplayMode]
                    $ArgumentList | Write-Output
                    "/l$($LogOption)",
                    # Must surround with double quotes. Single quotes are interpreted as part of the path.
                    """$($LogPath)"""
                } | Where-Object { $_ }

                $action = 'Install'
                $verb = 'Installing'
                if( $Force )
                {
                    $action = 'Repair'
                    $verb = 'Repairing'
                }

                if( $PSCmdlet.ShouldProcess( $From, $action ) )
                {
                    Write-Information -Message "$($msgPrefix)$($verb) $($target) from ""$($From)"""
                    Write-Verbose -Message "msiexec.exe $($ArgumentList -join ' ')"
                    $timer = [Diagnostics.Stopwatch]::StartNew()
                    $msiProcess = Start-Process -FilePath 'msiexec.exe' `
                                                -ArgumentList $ArgumentList `
                                                -NoNewWindow `
                                                -PassThru `
                                                -Wait

                    $timer.Stop()
                    $msg =
                        "            exit($($msiProcess.ExitCode)) in $($timer.Elapsed.TotalSeconds.ToString('0.000'))s"
                    Write-Verbose $msg

                    if( $null -ne $msiProcess.ExitCode -and $msiProcess.ExitCode -ne 0 )
                    {
                        $msg = "$($target) $($action.ToLowerInvariant()) failed. Installer ""$($msi.Path)"" returned " +
                               "exit code $($msiProcess.ExitCode). See the installation log file ""$($LogPath)"" for " +
                               'more information and https://docs.microsoft.com/en-us/windows/win32/msi/error-codes ' +
                               'for a description of the exit code.'
                        Write-Error $msg -ErrorAction $ErrorActionPreference
                        return
                    }
                }

                if( $deleteLog -and (Test-Path -Path $LogPath) )
                {
                    Remove-Item -Path $LogPath -ErrorAction Ignore
                }
            }
        }

        $msgPrefix = "[$($MyInvocation.MyCommand.Name)]  "
        Write-Debug "$($msgPrefix)+"

        if( $Path )
        {
            Get-CMsi -Path $Path |
                Where-Object {
                    $msiInfo = $_

                    $installed = Test-ProgramInstalled -Name $msiInfo.ProductName -Code $msiInfo.ProductCode
                    if( $installed )
                    {
                        return $Force.IsPresent
                    }

                    # Not installed so $Force has no meaning. $Force also controls whether the action is "Install" or
                    # "Repair". We're always installing if not installed so set $Force to $false.
                    $Force = $false
                    return $true
                } |
                Invoke-Msiexec
            return
        }

        # If the program we are going to download is already installed, don't re-download it.
        $installed = Test-ProgramInstalled -Name $ProductName -Code $ProductCode
        if( $installed -and -not $Force )
        {
            return
        }
        # Make sure action is properly reported as Install or Repair.
        if( -not $installed )
        {
            $Force = $false
        }

        $msi = Get-CMsi -Url $Url
        if( -not $msi )
        {
            return
        }

        $actualChecksum = Get-FileHash -LiteralPath $msi.Path
        if( $actualChecksum.Hash -ne $Checksum )
        {
            $msg = "Install failed: checksum ""$($actualChecksum.Hash.ToLowerInvariant())"" for installer " +
                   "downloaded from ""$($Url)"" does not match expected checksum ""$($Checksum.ToLowerInvariant())""."
            Write-Error -Message $msg -ErrorAction $ErrorActionPreference
            return
        }

        $msi | Invoke-Msiexec -From $Url

        Write-Debug "$($msgPrefix)-"
    }
}



function Read-CMsiTable
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Object] $Database,

        [Parameter(Mandatory)]
        [String] $Name,

        [Parameter(Mandatory)]
        [String] $MsiPath
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -Session $ExecutionContext.SessionState

    $numErrors = $Global:Error.Count
    $view = $null

    try
    {
        $view = $Database.OpenView("select * from ``$($Name)``")
        if( -not $view )
        {
            $msg = "$($msiPath): failed to query $($Name) table."
            Write-Error -Message $msg -ErrorAction $ErrorActionPreference
            return
        }
    }
    catch
    {
        for( $idx = $numErrors; $idx -lt $Global:Error.Count; ++$idx )
        {
            $Global:Error.RemoveAt(0)
        }
        $msg = "Exception opening table ""$($Name)"" from MSI ""$($MsiPath)"": $($_)"
        Write-Debug -Message $msg
        return
    }

    $numErrors = $Global:Error.Count
    try
    {
        [void]$view.Execute()

        $colIdxToName = [Collections.ArrayList]::New()

        for( $idx = 0; $idx -le $view.ColumnInfo(0).FieldCount(); ++$idx )
        {
            $numErrors = $Global:Error.Count
            $columnName = $view.ColumnInfo(0).StringData($idx)
            Write-Debug "    [$($idx)] $columnName"
            [void]$colIdxToName.Add($columnName)
        }

        $msiRecord = $view.Fetch()
        while( $msiRecord )
        {
            $record = [pscustomobject]@{};
            Write-Debug '    +-----+'
            for( $idx = 0; $idx -lt $colIdxToName.Count; ++$idx )
            {
                $fieldName = $colIdxToName[$idx]
                if( -not $fieldName )
                {
                    continue
                }

                $fieldValue = $msiRecord.StringData($idx)
                Write-Debug "    [$($idx)][$($fieldName)]  $($fieldValue)"
                $record | Add-Member -Name $fieldName -MemberType NoteProperty -Value $fieldValue
            }
            $record.pstypenames.Insert(0, "Carbon.Windows.Installer.Records.$($Name)")
            $record | Write-Output
            $msiRecord = $view.Fetch()
        }
    }
    catch
    {
        $msg = "Exception reading ""$($Name)"" table record data from MSI ""$($MsiPath)"": " +
                "$($_)"
        Write-Debug -Message $msg
    }
    finally
    {
        if( $view )
        {
            [void]$view.Close()
        }
    }
}



function Use-CallerPreference
{
    <#
    .SYNOPSIS
    Sets the PowerShell preference variables in a module's function based on the callers preferences.

    .DESCRIPTION
    Script module functions do not automatically inherit their caller's variables, including preferences set by common
    parameters. This means if you call a script with switches like `-Verbose` or `-WhatIf`, those that parameter don't
    get passed into any function that belongs to a module. 

    When used in a module function, `Use-CallerPreference` will grab the value of these common parameters used by the
    function's caller:

     * ErrorAction
     * Debug
     * Confirm
     * InformationAction
     * Verbose
     * WarningAction
     * WhatIf
    
    This function should be used in a module's function to grab the caller's preference variables so the caller doesn't
    have to explicitly pass common parameters to the module function.

    This function is adapted from the [`Get-CallerPreference` function written by David Wyatt](https://gallery.technet.microsoft.com/scriptcenter/Inherit-Preference-82343b9d).

    There is currently a [bug in PowerShell](https://connect.microsoft.com/PowerShell/Feedback/Details/763621) that
    causes an error when `ErrorAction` is implicitly set to `Ignore`. If you use this function, you'll need to add
    explicit `-ErrorAction $ErrorActionPreference` to every `Write-Error` call. Please vote up this issue so it can get
    fixed.

    .LINK
    about_Preference_Variables

    .LINK
    about_CommonParameters

    .LINK
    https://gallery.technet.microsoft.com/scriptcenter/Inherit-Preference-82343b9d

    .LINK
    http://powershell.org/wp/2014/01/13/getting-your-script-module-functions-to-inherit-preference-variables-from-the-caller/

    .EXAMPLE
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    Demonstrates how to set the caller's common parameter preference variables in a module function.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        #[Management.Automation.PSScriptCmdlet]
        # The module function's `$PSCmdlet` object. Requires the function be decorated with the `[CmdletBinding()]`
        # attribute.
        $Cmdlet,

        [Parameter(Mandatory)]
        # The module function's `$ExecutionContext.SessionState` object.  Requires the function be decorated with the
        # `[CmdletBinding()]` attribute. 
        #
        # Used to set variables in its callers' scope, even if that caller is in a different script module.
        [Management.Automation.SessionState]$SessionState
    )

    Set-StrictMode -Version 'Latest'

    # List of preference variables taken from the about_Preference_Variables and their common parameter name (taken
    # from about_CommonParameters).
    $commonPreferences = @{
                              'ErrorActionPreference' = 'ErrorAction';
                              'DebugPreference' = 'Debug';
                              'ConfirmPreference' = 'Confirm';
                              'InformationPreference' = 'InformationAction';
                              'VerbosePreference' = 'Verbose';
                              'WarningPreference' = 'WarningAction';
                              'WhatIfPreference' = 'WhatIf';
                          }

    foreach( $prefName in $commonPreferences.Keys )
    {
        $parameterName = $commonPreferences[$prefName]

        # Don't do anything if the parameter was passed in.
        if( $Cmdlet.MyInvocation.BoundParameters.ContainsKey($parameterName) )
        {
            continue
        }

        $variable = $Cmdlet.SessionState.PSVariable.Get($prefName)
        # Don't do anything if caller didn't use a common parameter.
        if( -not $variable )
        {
            continue
        }

        if( $SessionState -eq $ExecutionContext.SessionState )
        {
            Set-Variable -Scope 1 -Name $variable.Name -Value $variable.Value -Force -Confirm:$false -WhatIf:$false
        }
        else
        {
            $SessionState.PSVariable.Set($variable.Name, $variable.Value)
        }
    }
}