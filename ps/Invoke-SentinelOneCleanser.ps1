## Download SentinelCleaner_22_1GA_64.exe
try {
    invoke-webrequest "https://wdc.help/tools/s1/SentinelCleaner_22_1GA_64.exe" -outfile "$env:TEMP\SentinelCleaner_22_1GA_64.exe"   
} catch {
   Write-Information "Failed to download SentinelCleaner_22_1GA_64.exe"
}

## Install SentinelCleaner_22_1GA_64.exe
try {
    Start-Process "$env:TEMP\SentinelCleaner_22_1GA_64.exe" -Wait
} catch {
   Write-Information "SentinelCleaner_22_1GA_64.exe execution failed or reported errors"
} finally {
    Remove-Item "$env:TEMP\SentinelCleaner_22_1GA_64.exe"
}

## Download SentinelCleaner_x64.exe
try {
    Invoke-WebRequest "https://wdc.help/tools/s1/SentinelCleaner_x64.exe" -outfile "$env:TEMP\SentinelCleaner_x64.exe"
} catch {
   Write-Information "Failed to download SentinelCleaner_x64.exe"
}

## Install SentinelCleaner_x64.exe
try {
    
    Start-Process "$env:TEMP\SentinelCleaner_x64.exe" -Wait
} catch {
   Write-Information "SentinelCleaner_x64.exe execution failed or reported errors"
} finally {
    Remove-Item "$env:TEMP\SentinelCleaner_x64.exe"
}

try {
    Start-Process "C:\Program Files (x86)\SolarWinds MSP\Ecosystem Agent\unins000.exe" -ArgumentList "/silent" -Wait
} catch {
    Write-Information "Failed to uninstall Ecosystem Agent"
}

try {
    Remove-Item "C:\program files (x86)\N-Able Technologies\Windows Agent\Config\ExecutionerConfig.xml" -Force
} catch {
   Write-Information "Failed to remove ExecutionerConfig.xml"
}

try {
    Remove-Item "C:\program files (x86)\N-Able Technologies\Windows Agent\Config\ExecutionerConfig.xml.backup" -Force
} catch {
   Write-Information "Failed to remove ExecutionerConfig.xml.backup"
}

try {
    sc delete EcosystemAgent
} catch {
   Write-Information "Failed to remove EcosystemAgent service"
}

try {
    sc delete EcosystemAgentMaintenance
} catch {
   Write-Information "Failed to remove EcosystemAgentMaintenance service"
}

try {
    get-service -Name "Windows Agent" | Restart-Service
} catch {
   Write-Information "Failed to restart Windows Agent service"
}

try {
    get-service -Name "Windows Agent Maintenance" | Restart-Service
} catch {
   Write-Information "Failed to restart Windows Agent Maintenance service"
}