## The purpose of this script is to copy existing Chocolatey packages to a new directory and change the version number in the nuspec file to
## 0.0.0.0 so that way it can be packaged as a "dummy" package. This is useful for when you want to trigger an update notification for the package
## such that the user is able to install the latest version of the package at will.cd 

param(
    [Parameter(Mandatory=$true)]
    [string]$sourceDir,

    [Parameter(Mandatory=$true)]
    [string]$targetDir
)

# Copy contents of each subfolder in the source directory to the target directory
Get-ChildItem -Path $sourceDir -Directory | ForEach-Object {
    Copy-Item -Path "$($_.FullName)\*" -Destination "$targetDir\$($_.Name)" -Recurse -Force
}

# Change the version in nuspec file and delete the contents of each tools folder
Get-ChildItem -Path $targetDir -Directory | ForEach-Object {
    $nuspecFiles = Get-ChildItem -Path "$($_.FullName)" -Filter "*.nuspec" -Recurse
    
    $nuspecFiles | ForEach-Object {
        # Load the XML file
        $xml = [xml](Get-Content $_.FullName)

        # Change version number
        $xml.package.metadata.version = "0.0.0.0"

        # Save the XML file
        $xml.OuterXml | Set-Content $_.FullName
    }
    
    $toolsDir = Join-Path $_.FullName "tools"

    if(Test-Path -Path $toolsDir) {
        # Delete the contents of each tools folder
        Get-ChildItem -Path $toolsDir | Remove-Item -Recurse -Force
    }
}
