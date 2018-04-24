# PowerShell
A collection of PowerShell scripts and tidbits


## Check-SSLConfig.ps1

#### Inputs

|Parameter|Mandatory|Options|Default|Description|
|---|---|---|---|---|
|InputFile|Yes|[Path][Filename]|N/A|A test file containing one URL per line|
|Cache|No|$True/$False|$False|Use a cached scan if available|
|Public|No|$True/$False|$False|Publish scan results to www.ssllabs.com.|
|MaxAge|No|Integer|168|Maximum age of a scan in hours, if pulling from cache. The default is 168 (1 week). Only used if Cache is specified|


#### Outputs

**Log File:** Log file is saved in the same folder as the script. Filename "yyyy-MM-dd SSL Check.log"  
**Report:** Report file is CSV, saved in the same folder as the script. Filename "yyyy-MM-dd SSL Scan Results.csv"  
**Raw Data:** Raw data in JSON format is saved for each host in a folder located in the same location as the script. Folder name "yyyy-MM-dd Raw Data"

#### Example Usage

Submit all the URLs in hosts.txt to the SSL Labs Server Test, using default settings  
`Check-SSLConfig.ps1 -InputFile domains.txt`

Submit all the URLs in hosts.txt to the SSL Labs Server Test, publish results on www.ssllabs.com, and use default settings [Cache: False, MaxAge: 0]  
`Check-SSLConfig.ps1 -InputFile domains.txt -Publish True`

Retrieve the report from the cache, assuming a report exists with an age less than 24 hours.  
`Check-SSLConfig.ps1 -InputFile domains.txt -Cache $True -MaxAge 24`

#### Futures

In its current form, the script meets my needs, however items I'd like to expand are:

- Function to Email report
- Enhanced report with format options: CSV, HTML, XML
- Additional data in the report such as Test Time.
- Make Raw Data dump optional, and/or dependant on the specified rating.
----

## IIS-Binding.ps1

#### Inputs

**-FileName:** CSV file to save export data to, or CSV file containing previous export data to import.
**-Import:** Set to import
**-Export:** Set to export

#### Example Usage

IIS-Binding.ps1 -FileName C:\Data\IIS-Bindings.csv -Export
IIS-Binding.ps1 -FileName C:\Data\IIS-Bindings.csv -Import

----
