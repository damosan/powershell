<#
.SYNOPSIS
Script to check the website security configuration using the Mozilla Observatory API

.DESCRIPTION
Script will take a text file containing a list of URLs, and submit them to the
"Mozilla Observatory" to perform an analysis of the configuration of the host.

.PARAMETER InputFile
A text file containing one URL per line.

.PARAMETER Rescan
Forces a rescan of the site.

.PARAMETER Hidden
Hide scan results in Mozilla Observatory

.PARAMETER Log
Enable Logging.

.EXAMPLE
Get-Observatory.ps1 -InputFile domains.txt

This will submit all the URLs in domains.txt to Mozilla Observatory, using default settings
[Rescan: True, Hidden: True]

.EXAMPLE
Get-Observatory.ps1 -InputFile domains.txt -Publish True

This will submit all the URLs in domains.txt to the Mozilla Observatory, output results to CSV,
Publish results on Mozilla Observatory, and use default settings [Cache: False]

.NOTES
With the exception of the Grade, results are taken from the "Pass" field, thus a result of True is a pass, False is a fail.
This can be seen in the raw data file.

Further info on the scoring methodology:
https://github.com/mozilla/http-observatory/blob/master/httpobs/docs/scoring.md


#>
param(
    [Parameter(Mandatory = $true, Position = 1)][string]$InputFile,
    [boolean]$Rescan = $true,
    [boolean]$Hidden = $true,
    [boolean]$Log = $True
)

#
# Define Variables
#
Set-variable -Name DATE_STRING -Value (get-date -Format "yyyy-MM-dd").ToString()
Set-Variable -Name all_results -Value @()
Set-Variable -Name Finished -Value $false
Set-Variable -Name host_list -Value $null
Set-Variable -Name base_url -Value "https://http-observatory.security.mozilla.org/api/v1/analyze?host="
Set-Variable -Name get_base_url -Value "https://http-observatory.security.mozilla.org/api/v1/getScanResults?scan="
Set-Variable -Name Interval -Value 60
Set-Variable -Name ResultsFile -Value "$PSScriptRoot\$DATE_STRING Observatory.csv"


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
        [Parameter(Mandatory = $true)][string]$URL,
        [Parameter(Mandatory = $true)][string]$method,
        [Parameter(Mandatory = $true)][string]$host_name,
        [Parameter(Mandatory = $false)][string]$scan_id
    )

    if ($Log) {LogData "Trying Invoke-WebRequest..." }
    try {
        $scan_data = Invoke-RestMethod -Method $method -Uri $URL
        if ($method -eq "GET") { $scan_data | ConvertTo-Json -depth 100 | Out-File "$ReportsFolder\$host_name.json" }
    }
    catch {
        $ErrorMessage = $_.Exception
        $ErrorMessage
        if ($Log) {
            LogData "Error performing operation: $method"
            LogData "Web request error: $URL"
            LogData "Web request error: $ErrorMessage"
        }
        Write-Host "`nError performing operation: $method`n" -ForegroundColor Red
        Write-Host "`nWeb request error: $URL`n" -ForegroundColor Red
        Write-Host "`nWeb request error: $ErrorMessage`n" -ForegroundColor Red
        return $False
    }
    if ($Log) { LogData "...Successfully started web request"}
    return $scan_data
}


function Set-URL {
    Param (
        [Parameter(Mandatory = $true)][string]$operation,
        [Parameter(Mandatory = $true)][string]$host_name,
        [Parameter(Mandatory = $false)][boolean]$hidden,
        [Parameter(Mandatory = $false)][boolean]$rescan,
        [Parameter(Mandatory = $false)][string]$scan_id

    )

    if ($Log) { LogData "Hostname: $host_name"}

    # Build the URL for the API Call
    switch ($operation) {
        "START" {
            $URL = $base_url + $host_name
            if ($hidden) { $URL += "&hidden=true" } else { $URL += "&hidden=false" }
            If ($rescan) { $URL += "&rescan=true" } else { $URL += "&rescan=false"}
            if ($Log) {LogData "Scan URL: $URL"}
        }

        "CHECK" {
            $URL = $base_url + $host_name
            if ($Log) {LogData "Check URL: $URL"}
        }

        "GET" {
            $URL = $get_base_url + $scan_id
            if ($Log) {LogData "GET URL: $URL"}
        }
    }
    return $URL
}

#
# Check Args
#
If ($Log) {
    $LogFile = "$PSScriptRoot\$DATE_STRING Observatory.log"
}

if (!(Test-Path $InputFile)) {
    Write-Host "`nCannot find input file: $InputFile.`n" -ForegroundColor Red
    if ($Log) {LogData "Cannot find input file: $InputFile."}
    exit
}
else {
    $host_list = Get-Content $InputFile
    if ([string]::IsNullOrEmpty($host_list)) {
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
foreach ($host_name in $host_list) {
    $finished = $false

    # Build URL
    $start_url = Set-URL "START" $host_name $hidden $rescan

    # Start the test
    $start_result = Start-WebRequest $start_url "POST" $host_name

    if ($start_result -ne $false) {
        do {
            $check_url = Set-URL "CHECK" $host_name
            $check_result = Start-WebRequest $check_url "GET" $host_name
            $scan_id = $check_result.scan_id
            switch ($check_result.State) {
                "FINISHED" {
                    if ($Log) { LogData $check_result }
                    $get_url = Set-URL "GET" $host_name $hidden $rescan $scan_id
                    $host_result = Start-WebRequest $get_url "GET" $host_name $scan_id
                    if ($host_result -ne $False) {
                        if ($Log) { LogData "Adding results to all results object."}
                        $build_result = New-Object System.Object
                        $build_result | Add-Member -type NoteProperty -name Domain -value $host_name
                        $build_result | Add-Member -type NoteProperty -name Grade -value ($check_result.grade)
                        $build_result | Add-Member -type NoteProperty -name "CSP" -value ($host_result.'content-security-policy'.pass)
                        $build_result | Add-Member -type NoteProperty -name "Cookies" -value ($host_result.'cookies'.pass)
                        $build_result | Add-Member -type NoteProperty -name "CORS" -value ($host_result.'cross-origin-resource-sharing'.pass)
                        $build_result | Add-Member -type NoteProperty -name "PKP" -value ($host_result.'public-key-pinning'.pass)
                        $build_result | Add-Member -type NoteProperty -name "Redirection" -value ($host_result.'redirection'.pass)
                        $build_result | Add-Member -type NoteProperty -name "Referrer" -value ($host_result.'referrer-policy'.pass)
                        $build_result | Add-Member -type NoteProperty -name "HSTS" -value ($host_result.'strict-transport-security'.pass)
                        $build_result | Add-Member -type NoteProperty -name "SRI" -value ($host_result.'subresource-integrity'.pass)
                        $build_result | Add-Member -type NoteProperty -name "X-Content-Type" -value ($host_result.'x-content-type-options'.pass)
                        $build_result | Add-Member -type NoteProperty -name "X-Frame" -value ($host_result.'x-frame-options'.pass)
                        $build_result | Add-Member -type NoteProperty -name "X-XSS" -value ($host_result.'x-xss-protection'.pass)


                        $all_results += $build_result
                    }
                    else {
                        if ($Log) { LogData "host_result equaled false."}
                    }
                    $finished = $true
                }
                ("FAILED", "ABORTED") {
                    if ($Log) { LogData "Error reported by Mozilla Observatory API: " + $check_result.State}
                    $build_result = New-Object System.Object
                    $build_result | Add-Member -type NoteProperty -name Domain -value $host_name
                    $build_result | Add-Member -type NoteProperty -name Grade -value ("ERROR : " + $check_result.State)
                    $all_results += $build_result
                    $finished = $true
                }
                default {
                    if ($Log) { LogData "Sleeping for $Interval seconds..." }
                    if ($log) { LogData ($check_result.Status)}
                    start-sleep -Seconds $Interval
                }
            }
        } while (!($finished))
    }
}


"Compiling results into CSV..."
$all_results | Format-Table -AutoSize

$all_results | Select-Object Domain, Grade, CSP, Cookies, CORS, PKP, Redirection, Referrer, HSTS, SRI, X-Content-Type, X-Frame, X-XSS  | export-csv $ResultsFile -NoTypeInformation
