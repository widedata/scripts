[CmdletBinding()]
param (
    [Parameter(ValueFromRemainingArguments=$true)]
    $Path
)

If((Get-ChildItem $Path).Extension -eq ".csv")
{  
    Import-CSV $Path | Export-CSV "$Path.new" -NoTypeInformation -Force
    Remove-Item "$Path"
    Rename-Item "$Path.new" "$Path"
} else {
    Write-Error "Incorrect file extension. Only CSV Supported"
    Timeout /T 30
}