function Debug-ThrowException {
    [CmdletBinding()]
    param (
        [string]$Message,
        [string]$Verb,
        [string]$Path,
        [string]$Output,
        [string]$LineNumber,
        [string]$Filename,
        [string]$Executable,
        [Exception]$Exception
    )

    begin {
        # if ($Exception) {
        #     $7zException =  [SevenZipException]::new($Message, $Exception)
        # } else {

        # }
        $7zException =  [SevenZipException]::new($Message)
        $7zException.Verb               = $Verb
        $7zException.Path               = $Path
        $7zException.Output             = $Output
        $7zException.ScriptFilePath     = $7zSettings.ScriptFilePath
        $7zException.ScriptLineNumber   = $LineNumber
        $7zException.ScriptFilename     = $Filename
        $7zException.SevenZipExecutable = $Executable
        $7zException.Exception          = $Exception

    }

    process {
        throw $7zException
    }

    end {

    }
}
