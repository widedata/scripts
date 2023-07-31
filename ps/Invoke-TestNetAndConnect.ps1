$networkConfig = @{
  fileStore = "\\fileserver1\shared\Programs"
  fileStoreArchive = "\\fileserver2\programs"
  fileUser = "domain\deploy"
  filePass = "d3pl0y4m3!"
}

Start-Transcript -Path "C:\temp\NetConnect_log.txt" -Append

If(Test-Path $networkConfig.fileStore -ErrorAction SilentlyContinue) {
  Write-Output "File store accessible. Continuing..."
} else {
  Write-Output "File store inaccessible..."

  try {
    Write-Output "Attempting to authenticate access to file store..."
    net use $($networkConfig.fileStore) /user:$($networkConfig.fileUser) $($networkConfig.filePass)
  } catch {
    Write-Output "Unable to authenticate file store. Proceeding without file store access."
  }
}

if($networkConfig.fileStoreArchive -ne "") {
  If(Test-Path $networkConfig.fileStoreArchive -ErrorAction SilentlyContinue) {
    Write-Output "File store archive accessible. Continuing..."
  } else {
    Write-Output "File store archive inaccessible..."
  
    try {
      Write-Output "Attempting to authenticate access to file store archive..."
      net use $($networkConfig.fileStoreArchive) /user:$($networkConfig.fileUser) $($networkConfig.filePass)
    } catch {
      Write-Output "Unable to authenticate file store archive. Proceeding without file store archive access."
    }
  }
}

Stop-Transcript