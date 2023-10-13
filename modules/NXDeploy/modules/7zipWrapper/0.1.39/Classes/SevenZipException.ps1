class SevenZipException : Exception {
    <#
        .SYNOPSIS
        Constructs a new exception with the specified detail message and additionaldata.

        .DESCRIPTION
        This is the base exception of this module.  The sub classes are to develop
        finer detailed exceptions to more accurately describe the errors thrown

        .PARAMETER Message
        The detail message of this exception.  This is provided by the calling code.

        .PARAMETER AdditionalData
        the details attached to this exception. A null value is permitted, and
        indicates that the error was basic and the details are unknown.

        .EXAMPLE
        throw [SevenZipException]::new("Unable to find archive", 'C:\test\archive.zip')

        This will produce the error message: Unable to find archive

        .EXAMPLE
        try {
            throw [SevenZipException]::new('Unable to find archive', 'C:\test\archive.zip')
        } catch [SevenZipException] {
            $AdditionalData = @{
                $Filename = $_.Exception.additionalData
            }
            throw [SevenZipException]::new($('Archive file unavailable: {0}' -f $AdditionalData.Filename, 'FileNotFoundException')
        }

        To access additionaldata in the SevenZipException use the $_.Exception variable
        This example will catch the first error in the catch block where error handling
        can be applied and if unresolved will then rethrow this error and produce the
        error message: Didn't catch it the second time

        .NOTES
        the detail message associated with additionaldata is not automatically
        incorporated in this exception's detail message.

        Exit Codes from 7-Zip
        7-Zip returns the following exit codes:

        Code    Meaning
        0    No error
        1    Warning (Non fatal error(s)). For example, one or more files were locked by some other application, so they were not compressed.
        2    Fatal error
        7    Command line error
        8    Not enough memory for operation
        255    User stopped the process

        .LINK
        Official 7Zip Exit Codes: https://documentation.help/7-Zip/exit_codes.htm

    #>
        #Class Properties
        [string]$Verb
        [string]$Path
        [string]$Output
        [string]$ScriptFilePath
        [string]$ScriptLineNumber
        [string]$ScriptFilename
        [string]$SevenZipExecutable
        [Exception]$Exception

        SevenZipException($Message) : base($Message) {

        }

        SevenZipException($Message, $Exception) : base($Message, $Exception.InnerException) {

        }

        SevenZipException() {
        }
}

