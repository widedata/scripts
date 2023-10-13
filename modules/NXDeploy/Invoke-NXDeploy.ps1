function Invoke-NXDeploy {
    param(
        [Parameter(Mandatory=$true)]
        [string]$msiPath,
        [string]$installIdentifier,
        [Parameter(Mandatory=$true)]
        [string]$vpnServer,
        [Parameter(Mandatory=$true)]
        [string]$vpnDomain,
        [string]$outputDir = "C:\temp"
    )

    # Import 7zipWrapper module
    Write-Output "Importing 7zipWrapper module"
    if(Get-module 7zipWrapper -ListAvailable) {
        Remove-Module 7zipWrapper
    }

    import-module "$PSScriptRoot\modules\7zipWrapper\0.1.39\7zipWrapper.psm1" -Scope Local


    If(-Not (Get-Module Carbon.Windows.Installer -ListAvailable)) {
        # Import Carbon.Windows.Installer module
        Write-Output "Importing Carbon.Windows.Installer module"
        import-module "$PSScriptRoot\modules\Carbon.Windows.Installer\2.0.0\Carbon.Windows.Installer.psm1" -Scope Local
    }


    # If the user did not enter an output directory use C:\temp and create if it's missing
    if ($outputDir -eq "") {
        Write-Output "No output directory specified, using default C:\temp"
        $outputDir = "C:\temp"
        if (!(Test-Path $outputDir -ErrorAction SilentlyContinue)) {
            Write-Output "Creating $outputDir"
            New-Item -ItemType Directory -Force -Path $outputDir
        }
    } else {
        Write-Output "Output directory specified, using $outputDir"
    }
    
    $msiName = (Get-Item $msiPath).Name

    # Get the msi version and create the output file name
    $msiVersion = (Get-CMsi $msiPath).ProductVersion
    Write-Output "MSI Version: $msiVersion"

    # Create the output file name
    if($installIdentifier) {
        $outputFile = "NetExtender-$installIdentifier-$msiVersion.exe"
    } else {
        $outputFile = "NetExtender-Custom-$msiVersion.exe"
    }

    # Create the output file path
    $outputFile = "NetExtender-$installIdentifier-$msiVersion.exe"
    $ExeDestination = "$outputDir\$outputFile"
    Write-Output "Output file will be: $ExeDestination"

    # Check if the output file already exists, if it does rename it with the MD5 hash    
    If(Test-Path "$outputDir\$outputFile" -ErrorAction SilentlyContinue) {
        Write-Output "File already exists, renaming with MD5 hash"
        $OldHash = (Get-FileHash -Path "$outputDir\$outputFile" -Algorithm MD5).Hash.ToString()
        Write-Output "Old MD5 Hash: $OldHash"
        $OldHashFile = $outputFile.Replace(".exe", "-$OldHash.exe")
        Rename-Item "$outputDir\$outputFile" "$outputDir\$OldHashFile"
        Write-Output "$outputDir\$outputFile-$OldHash"
    }

    # Create the 7zSFX parameters
    $7zSFXParams = @{
        Path = $ExeDestination
        Include = $msiPath
        ExtractTitle = "Please wait..."
        CommandToRun = "C:\Windows\System32\msiexec.exe /i %%T\$msiName /norestart /passive EDITABLE=FALSE SERVER=`"$VPNServer`" DOMAIN=$VPNDomain"
    }

    # Create the 7zSFX
    New-7zSFX @7zSFXParams

    # Check if the 7zSFX was created
    If(Test-Path $ExeDestination -ErrorAction SilentlyContinue) {
        Write-Output "Installer created successfully"

        if($oldHash) {
            # Compare the MD5 hash of the new file to the old file
            Write-Output "An existing file was found, comparing MD5 hashes"
            $NewHash = (Get-FileHash -Path $ExeDestination -Algorithm MD5).Hash.ToString()
            Write-Output "New MD5 Hash: $NewHash"
            if($NewHash -eq $OldHash) {
                Write-Output "MD5 Hashes match, deleting old file"
                Remove-Item "$outputDir\$outputFile-$OldHash"
            } else {
                Write-Output "MD5 Hashes do not match, retaining both copies"
            }
        }

    } else {
        Write-Output "Instsaller creation failed"
    }
}