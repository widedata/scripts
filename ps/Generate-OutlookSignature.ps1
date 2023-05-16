<# 
.SYNOPSIS
    Generates signature for Microsoft Outlook with info from Active Directory 

.DESCRIPTION 
    This script generates HTM, TXT, and RTF files for Microsoft Outlook to use for signatures based on values pulled from Active Directory via LDAP. 

    You can set the "Signature Name" via a variable below along with defaults for: Company, Telephone, Fax, Web, and Email. As this pulls ALL LDAP
    properties you can use any of them in the following context by simply replacing "property" with the appropriate ldap property name:
    $($USER.property)

    The "templates" are included "inline" for the HTM, TXT, and RTF. You can use the variables $useName, $useEmail, $useTitle, $useCompany, 
    $usePhone, $useFax, and $useWeb to insert the desired values in the templates.

    Some additional aliases were created for hard to remember LDAP properties (i.e. 'l' means city). 
    
    Here is a list of the best values to use when creating the templates:
    $($USER.displayName)
    $($USER.firstName)
    $($USER.lastName)
    $($USER.email)
    $($USER.title)
    $($USER.department)
    $($USER.description)
    $($USER.officeName)
    $($USER.company)
    $($USER.mobile)
    $($USER.phone)
    $($USER.faxNumber)
    $($USER.ipPhone)
    $($USER.streetAddress)
    $($USER.city)
    $($USER.state)
    $($USER.country)
    $($USER.postalCode)

.COMPONENT 
    PowerShell 5.1+ Recommended, may run on lower versions but is untested.

.LINK 
    Function for cleaning up LDAP properties for easier variable reference gotten from https://petri.com/expanding-active-directory-searcher-powershell/.

.NOTES 
    Scripted by:
    Dailen Gunter @ WideData
    dgunter@widedata.com
    404-360-8211
    @dailen
#>

## You can set the name of the Signature referenced in the files and by Outlook
$SignatureName = "Company Signature"

## This option will overwrite any existing signature file
$OverwriteExisting = $true

## Default Company Info in case any are missing in AD
## Leave blank if you don't need it
$defaultCompanyName = "Your Company Name"
$defaultTelephone = "111-222-3333"
$defaultFax = "000-000-0000"
$defaultWeb = "https://www.yourdomain.com"
$defaultEmail = "info@yourdomain.com"

##################################################################
##################################################################

## This is Microsoft's default path and should never change 
## but it's included here just in case
$signaturePath = "$env:appdata\Microsoft\Signatures" # NO TRAILING SLASH

## Lets test if the signature exists but overwriting is disabled
if(-Not($OverwriteExisting)) {
    if(test-path "$signaturePath\$SignatureName.*") {
        ## Signature already present so stopping the script
        Exit 0
    }
}

## Function to improve AD/LDAP directory results handling
Function Convert-ADSearchResult 
{
    param
    (
        [Parameter(Mandatory,ValueFromPipeline)]
        [ValidateNotNullorEmpty()]
        [System.DirectoryServices.SearchResult]$SearchResult
    )

    Begin 
    {
        Write-Verbose "Starting $($MyInvocation.MyCommand)"
    }

    Process 
    {
        Write-Verbose "Processing result for $($searchResult.Path)"
        #create an ordered hashtable with property names alphabetized
        $props = $SearchResult.Properties.PropertyNames | Sort-Object
        $objHash = [ordered]@{}
        foreach ($p in $props) {
         $value =  $searchresult.Properties.item($p)
         if ($value.count -eq 1) {
            $value = $value[0]
         }
         $objHash.add($p,$value)
        }
    new-object psobject -property $objHash
    }

    End 
    {
        Write-Verbose "Ending $($MyInvocation.MyCommand)"
    }
}

## Here is where we actually pull the data from AD/LDAP
$LDAPSEARCH = New-Object System.DirectoryServices.DirectorySearcher
$LDAPSEARCH.Filter = "samAccountName=$env:UserName"
$USER = $LDAPSEARCH.FindOne() | Convert-ADSearchResult

## This will add some aliases to some more difficult to remember LDAP property names
## These silently continue in case the original value does not exist
$USER | add-member -passthru -membertype aliasproperty -name firstName -Value givenname -ErrorAction SilentlyContinue
$USER | add-member -passthru -membertype aliasproperty -name lastName -Value sn -ErrorAction SilentlyContinue
$USER | add-member -passthru -membertype aliasproperty -name email -Value mail -ErrorAction SilentlyContinue
$USER | add-member -passthru -membertype aliasproperty -name officeName -Value physicaldeliveryofficename -ErrorAction SilentlyContinue
$USER | add-member -passthru -membertype aliasproperty -name faxNumber -Value facsimiletelephonenumber -ErrorAction SilentlyContinue
$USER | add-member -passthru -MemberType AliasProperty -Name phone -Value telephonenumber -ErrorAction SilentlyContinue
$USER | add-member -passthru -membertype aliasproperty -name city -Value l -ErrorAction SilentlyContinue
$USER | add-member -passthru -membertype aliasproperty -name state -Value st -ErrorAction SilentlyContinue
$USER | add-member -passthru -membertype aliasproperty -name country -Value co -ErrorAction SilentlyContinue

## Lets set the display name variable or use the username if that's not available
if($USER.displayname) {
    $useName = $USER.displayname
} else {
    $useName = $USER.samaccountname
}

## Lets set the title variable or use the default value we set
if($USER.title) {
    $useTitle = $USER.title
} else {
    $useTitle = "."
}

## Lets set the email variable or use the default value we set
if($null -eq $USER.mail) {
    if($defaultEmail -ne "") {
        $useEmail = $defaultEmail
    }
} else {
    $useEmail = $USER.mail
}

## Lets set the company variable or use the default value we set
if($null -eq $USER.company) {
    if($defaultCompanyName -ne "") {
        $useCompany = $defaultCompanyName
    }
} else {
    $useCompany = $USER.company
}

## Lets set the phone variable or use the default value we set
if($null -eq $USER.telephonenumber) {
    if($defaultPhone -ne "") {
        $usePhone = $defaultPhone
    }
} else {
    $usePhone = $USER.telephonenumber
}

## Lets set the fax variable or use the default value we set
if($null -eq $USER.facsimiletelephonenumber) {
    if($defaultFax -ne "") {
        $useFax = $defaultFax
    }
} else {
    $useFax = $USER.facsimiletelephonenumber
}

## Lets set the web variable or use the default value we set
if($null -eq $USER.wwwhomepage) {
    if($defaultWeb -ne "") {
        $useWeb = $defaultFax
    }
} else {
    $useWeb = $USER.wwwhomepage
}

# Lets test signature folder path and/or create a folder
if (-Not(test-path $signaturePath)) {
    mkdir $signaturePath
} else {

}

##################################################################
##################################################################
## If editing this, just paste your content after the beginning @" 
## and before the final "@ (referred to as a Here-String in PS)

$htmlSignature = @"
<html> <head> <title> </title> </head> <body>
<p><span style="FONT-SIZE: 10pt; COLOR:#1F497D; FONT-FAMILY: Calibri">
$useName <br />
$useTitle<br />
$useCompany<br />
T:&nbsp;$usePhone &nbsp; F:&nbsp;$useFax<br />
E:&nbsp;<a href="mailto:$useEmail" style="FONT-SIZE: 10pt; COLOR:#1F497D; FONT-FAMILY: Calibri">$useEmail</a>
 &nbsp; <a href="$useWeb" style="FONT-SIZE: 10pt; COLOR:#1F497D; FONT-FAMILY: Calibri">$useWeb</a>
</p>
<span style="FONT-SIZE: 10pt; COLOR: Green; FONT-FAMILY: Calibri">
<span style="FONT-SIZE: 18pt; COLOR: Green; FONT-FAMILY: Webdings">P</span>
Please consider the environment - do you really need to print this email?<br />
</span></p>
</body> </html> 
"@


##################################################################
##################################################################

$textSignature = @"
$useName
$useTitle
$useCompany
T: $usePhone    F: $useFax
E: $useEmail
$useWeb

Please consider the environment - do you really need to print this email?
"@


##################################################################
##################################################################

$rtfSignature = @"
{\rtf1\ansi\ansicpg1252\deff0\deflang1033{\fonttbl{\f0\fswiss\fprq2\fcharset0 Calibri;}{\f1\froman\fprq2\fcharset2 Webdings;}}
{\colortbl;\red031\green073\blue125;\red0\green0\blue255;\red0\green128\blue0;}
{\*\generator Msftedit 5.41.15.1507;}\viewkind4\uc1\pard\sb100\sa100\cf1\lang2057\f0\fs20 $useName\line $useTitle\line $useCompany\line T: $usePhone   F: $useFax\line E: {\field{\*\fldinst{HYPERLINK "mailto:$useEmail"}}{\fldrslt{\ul $useEmail}}}\ulnone\f0\fs20    {\field{\*\fldinst{HYPERLINK "$useWeb"}}{\fldrslt{\ul $useWeb}}}\ulnone\f0\fs20\par
\cf3\f1\fs36 P\fs20  \f0 Please consider the environment - do you really need to print this email?\par
\pard\cf1\lang1033\par
}
"@


##################################################################
##################################################################
## Okay now we're ready to write our files. If overwrite is true
## then we'll overwrite using Force

if($OverwriteExisting) {
    set-content -Path "$signaturePath\$SignatureName.htm" -Value $htmlSignature -Force
    set-content -Path "$signaturePath\$SignatureName.txt" -Value $textSignature -Force
    set-content -Path "$signaturePath\$SignatureName.rtf" -Value $rtfSignature -Force
}
else 
{
    set-content -Path "$signaturePath\$SignatureName.htm" -Value $htmlSignature -ErrorAction SilentlyContinue
    set-content -Path "$signaturePath\$SignatureName.txt" -Value $textSignature -ErrorAction SilentlyContinue
    set-content -Path "$signaturePath\$SignatureName.rtf" -Value $rtfSignature -ErrorAction SilentlyContinue
}
