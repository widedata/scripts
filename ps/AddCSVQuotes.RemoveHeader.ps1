[CmdletBinding()]
param (
    [Parameter(ValueFromRemainingArguments=$true)]
    $Path
)

If((Get-ChildItem $Path).Extension -eq ".csv")
{  
    Import-CSV $Path | Export-CSV "$Path.new" -NoTypeInformation -Force
	Remove-Item "$Path"
	(Get-Content "$Path.new" | Select-Object -Skip 1) | Set-Content $Path
    Remove-Item "$Path.new"
} else {
    Write-Error "Incorrect file extension. Only CSV Supported"
    Timeout /T 30
}
