<#
.SYNOPSIS
Script to check the SSL configuration of URLs contained in a file, using the www.ssllabs.com API

.DESCRIPTION
Script will take a text file containing a list of URLs, and submit them to the 
"Qualys SSL Labs Server Test" to perform a deep analysis of the configuration of SSL on the host.
Hostname and grade saved to CSV, json data for hostname scan saved also.

.PARAMETER InputFile 
A text file containing one URL per line.

.PARAMETER Cache
Use a cached scan if available.

.PARAMETER Publish
Publish scan results to www.ssllabs.com

.PARAMETER MaxAge
Maximum age of a scan in hours, if pulling from cache.  Default is 168 (1 week).  Only used if
Cache is specified.

.PARAMETER Log
Enable Logging.

.EXAMPLE
Check-SSLConfig.ps1 -InputFile domains.txt

This will submit all the URLs in domains.txt to the SSL Labs Server Test, using default settings 
[Cache: False, Publish: False, MaxAge: N/A]

.EXAMPLE 
Check-SSLConfig.ps1 -InputFile domains.txt -Publish True

This will submit all the URLs in domains.txt to the SSL Labs Server Test, output results to CSV, 
Publish results on www.ssllabs.com, and use default settings [Cache: False, MaxAge: 0]

.EXAMPLE
Check-SSLConfig.ps1 -InputFile domains.txt -Cache $True -MaxAge 24

This will retrieve the report from cache, assuming a report exists with a age less than 24 hours.

.LINK 
https://github.com/damosan
#>
param(
    [Parameter(Mandatory = $true, Position = 1)][string]$InputFile,
    [boolean]$Cache = $false,
    [boolean]$Publish = $false,
    [int]$MaxAge = 168,
    [boolean]$Log = $True
)

#
# Define Variables
#
Set-variable -Name DATE_STRING -Value (get-date -Format "yyyy-MM-dd").ToString()
Set-Variable -Name AllResults -Value @() 
Set-Variable -Name Finished -Value $false
Set-Variable -Name HostList -Value $null
Set-Variable -Name BaseURL -Value "https://api.ssllabs.com/api/v2/analyze?host="
Set-Variable -Name GetBaseURL -Value "https://api.ssllabs.com/api/v2/getEndpointData?host="
Set-Variable -Name Interval -Value 60
Set-Variable -Name ResultsFile -Value "$PSScriptRoot\$DATE_STRING SSL Scan Results.csv"

#
# Functions
#
Function LogData {
    Param(
        [String]$LogMessage
    )
    Add-Content -Path $LogFile -Value ((get-date -Format "dd-MM-yyyy hh:mm:ss ") + " $LogMessage")	
}

Function Start-WebRequest {
    Param(
        [string]$URL,
        [string]$HostName,
        [string]$Operation
    )

    if ($Log) {LogData "Trying Invoke-WebRequest..." }
    try {
        $ScanData = Invoke-WebRequest $URL
        $ScanData = ConvertFrom-Json -inputobject $ScanData
        if ($Operation -eq "GET") { $HostData | ConvertTo-Json -depth 100 | Out-File "$ReportsFolder\$HostName.json" }
    }
    catch {
        $ErrorMessage = $_.Exception
        $ErrorMessage
        if ($Log) {
            LogData "Error performing operation: $Operation"
            LogData "Web request error: $URL"
            LogData "Web request error: $ErrorMessage" 
        }
        Write-Host "`nError poerforming operation: $Operation`n" -ForegroundColor Red
        Write-Host "`nWeb request error: $URL`n" -ForegroundColor Red
        Write-Host "`nWeb request error: $ErrorMessage`n" -ForegroundColor Red
        return = $False
    } 
    if ($Log) { LogData "...Successfully started web request"}
    return $ScanData
}

function Set-URL {
    Param (
        [Parameter(Mandatory = $true)][string][string]$Operation,
        [Parameter(Mandatory = $true)][string]$HostName,
        [Parameter(Mandatory = $false)][string]$HostIP,
        [Parameter(Mandatory = $false)][boolean]$Publish,
        [Parameter(Mandatory = $false)][boolean]$Cache,
        [Parameter(Mandatory = $false)][int]$MaxAge
    )

    if ($Log) { LogData "Hostname: $HostName"}

    # Build the URL for the API Call
    switch ($Operation) {
        "START" {
            $URL = $BaseURL + $HostName
            if ($Publish) { $URL += "&publish=on" } else { $URL += "&publish=off" }
            If ($Cache) { $URL += "&fromCache=on&maxAge=$MaxAge" } else { $URL += "&startNew=on"}
            if ($Log) {LogData "Scan URL: $URL"}
        }

        "CHECK" {
            $URL = $BaseURL + $HostName + "&publish=off"
            if ($Log) {LogData "Check URL: $URL"}
        }

        "GET" {
            $URL = $GetBaseURL + $HostName + "&s=$HostIP"
            if ($Log) {LogData "Get URL: $URL"}
        }
    }
    return $URL
}

#
# Check Args
#
If ($Log) {
    $LogFile = "$PSScriptRoot\$DATE_STRING SSL Check.log"
}

if (!(Test-Path $InputFile)) {
    Write-Host "`nCannot find input file: $InputFile.`n" -ForegroundColor Red
    if ($Log) {LogData "Cannot find input file: $InputFile."}
    exit
}
else {
    $HostList = Get-Content $InputFile
    if ([string]::IsNullOrEmpty($HostList)) {
        Write-Host "`nInput file is empty: $InputFile.`n" -ForegroundColor Red
        if ($Log) {LogData "Input file is empty: $InputFile."}
        exit
    }
}

#
# Create reports folder
#
$Global:ReportsFolder = "$PSScriptRoot\$DATE_STRING Raw Data"
if (!(Test-Path $ReportsFolder)) {
    New-Item -ItemType directory -Path $PSScriptRoot -Name "$DATE_STRING Raw Data"
}

# 
# Main Code
#
foreach ($HostName in $HostList) {
    $finished = $false

    # Build URL
    $StartURL = Set-URL "START" $HostName $HostIP $Publish $Cache $MaxAge

    # Start the SSL Test
    $StartResult = Start-WebRequest $StartURL $Hostname "START"
    
    if ($StartResult -ne $false) {
        do {
            $CheckURL = Set-URL "CHECK" $HostName 
            $CheckResult = Start-WebRequest $CheckURL $HostName "CHECK"
            $HostIP = $CheckResult.endpoints.ipaddress
            switch ($CheckResult.Status) { 
                "READY" {
                    if ($Log) { LogData $CheckResult }
                    $GetURL = Set-URL "GET" $HostName $HostIP
                    $FinalResult = Start-WebRequest $GetURL $HostName $HostIP "GET"
                    if ($FinalResult -ne $False) {
                        if ($Log) { LogData "Adding results to all results object."}
                        $HostResult = New-Object System.Object
                        $HostResult | Add-Member -type NoteProperty -name Domain -value $HostName
                        $HostResult | Add-Member -type NoteProperty -name Grade -value ($FinalResult.grade)
                        $AllResults += $HostResult
                    }
                    else {
                        if ($Log) { LogData "FinalResult equaled false."}
                    }
                    $finished = $true
                } 
                "ERROR" {
                    if ($Log) { LogData "Error reported by SSL Labs API: " + $FinalResult.statusMessage}
                    $HostResult = New-Object System.Object
                    $HostResult | Add-Member -type NoteProperty -name Domain -value $HostName
                    $HostResult | Add-Member -type NoteProperty -name Grade -value ("ERROR : " + $FinalResult.statusMessage)
                    $AllResults += $HostResult	
                    $finished = $true
                } 
                default {
                    if ($Log) { LogData "Sleeping for $Interval seconds..." }
                    if ($log) { LogData ($CheckResult.Status)}
                    start-sleep -Seconds $Interval
                }
            }  
        } while (!($finished))	
    }
}


"Compiling results into CSV..."
$AllResults

$AllResults | Select-Object Domain, Grade | export-csv $ResultsFile -NoTypeInformation

exit
