<#
.SYNOPSIS
Script to get TLS certificate details from a host

.DESCRIPTION
Script will take a text file containing a list of hosts, or a single hostname.  Queries the host
and returns the following certificate information:

    CN                      
    Issuer                  
    Expiration              
    CertificateIsValid      
    SubjectAlternativeNames 

.PARAMETER InputFile 
A text file containing one hostname per line.  Include :PortNumber for services not on 443

.PARAMETER HostName
A single hostname to scan.

.EXAMPLE
Get-Certificate.ps1 -InputFile hostnames.txt

This will return certificate details for all hostname contained in hostnames.ps1

.EXAMPLE
Get-Certificate.ps1 -HostName example.com

This will return certificate details for the supplied hostname.

.NOTES
The specifics of pulling the certificate details came from a combination of web searches and trial and error.
Thanks to all for sharing your code and helping the community.

#>
param(
    [Parameter(Mandatory = $false)][string]$InputFile,
    [Parameter(Mandatory = $false)][string]$HostName
)

function Get-WebsiteCertificate {
    [CmdletBinding()]
    param(
        [string]$url
    )

    $url = "https://$url"
    $request = [Net.WebRequest]::Create($url)
    $request.AllowAutoRedirect = $true
    [Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    # Seems to throw an error even when it works, so catch the "error" in the subsequent if statement.
    try { $Response = $request.GetResponse() } catch {}

    # If this is null, throw the error.
    if ($null -ne $request.ServicePoint.Certificate) {
        $Cert = [Security.Cryptography.X509Certificates.X509Certificate2]$request.ServicePoint.Certificate.Handle
        # Get SubjectAlternateNames if any exist
        try { 
            $SAN = ($Cert.Extensions | Where-Object { $_.Oid.Value -eq "2.5.29.17" }).Format(0) -split ", " 
        } catch { 
            $SAN = $null 
        }
        # Get the expiration date of the certificate
        [datetime]$expiration = [System.DateTime]::Parse($request.ServicePoint.Certificate.GetExpirationDateString())
        # Build the results
        $return_result = New-Object psobject -Property @{
            URL                     = $url;
            CN                      = $request.ServicePoint.Certificate.Subject;
            Issuer                  = $request.ServicePoint.Certificate.Issuer;
            Expiration              = $expiration
            SubjectAlternativeNames = $SAN;
        }
    } else {
        Write-Host -ForegroundColor Red "Error retrieving $url"
        Write-Host -ForegroundColor Red $error[0].Exception.Message
        $return_result = New-Object psobject -Property @{
            URL                     = $url;
            CN                      = ""
            Issuer                  = ""
            Expiration              = ""
            SubjectAlternativeNames = ""
        }
    }

    return $return_result
}


#
# Check Args
#
if ($InputFile) {
    if (!(Test-Path $InputFile)) {
        Write-Host "`nCannot find input file: $InputFile.`n" -ForegroundColor Red
        exit
    } else {
        $HostList = Get-Content $InputFile
        if ([string]::IsNullOrEmpty($HostList)) {
            Write-Host "`nInput file is empty: $InputFile.`n" -ForegroundColor Red
            exit
        }
    } 
} elseif ($HostName) {
    $HostList = $HostName
} else {
    Write-Host "Input required"
}

$results = @()
foreach ($url in $HostList) {
    $current_host = $null
    $current_host = Get-WebsiteCertificate -URL $url
    $results += $current_host
}

$results | Select-Object URL, CN, Expiration, Issuer, SubjectAlternativeNames 

exit 


















