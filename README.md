# PowerShell
A collection of PowerShell scripts and tidbits

## Check-SSLConfig.ps1
Script to automate SSL-Labs tests on external website

## IIS-Binding.ps1

#### Inputs

**-FileName:** CSV file to save export data to, or CSV file containing previous export data to import.
**-Import:** Set to import
**-Export:** Set to export

#### Example Usage

IIS-Binding.ps1 -FileName C:\Data\IIS-Bindings.csv -Export
IIS-Binding.ps1 -FileName C:\Data\IIS-Bindings.csv -Import

----

