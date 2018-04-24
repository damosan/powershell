<#
.SYNOPSIS
Script to export/import website bindings from IIS.

.DESCRIPTION
Script will create a CSV file with all of the IIS 7.5 websites and associated bindings.
Script must be run on the IIS server, do to lack of -ComputerName option in IIS CMDLets. 
That said it would be easy enough to modify to run in a remote session if required.

.PARAMETER FileName
Input / Output data file.

.PARAMETER Import
Import bindings from filename specified.  New-WebBinding command commented out for safety while testing.

.PARAMETER Export
Export bindings to filename specified.
Note:  Default Website does not work correctly, however as we don't use Default, this suits
our needs.

.LINK 
https://github.com/damosan
#>

param(
    [Parameter(Mandatory = $true )][string]$FileName,
    [Parameter(Mandatory = $false)] [switch]$Import = $false,
    [Parameter(Mandatory = $false)] [switch]$Export = $false
)

function Import-Bindings {
    param(
        $FileName
    )

    $inputFile = Import-Csv $filename 
    foreach ($site in $inputFile) {
        $command = 'New-WebBinding -Name "' + $Site.Name + '" -IPAddress "' + $site.IP + '" -Port ' + $site.Port + ' -HostHeader "' + $Site.Host + '"'
        $command
        #New-WebBinding -Name $Site.Name -IPAddress $site.IP -Port $site.Port -HostHeader $Site.Host
        
    }
    
}

function Export-Bindings {
    param(
        $FileName
    )

    $websites = Get-Website
    $output = @()

    foreach ($site in $websites) {
        $name = $site.Name
        $bindingInfo = $site.Bindings.Collection.bindingInformation
        foreach ($bind in $bindingInfo) {
            $bind = $bind.Split(":")
            $myObject = New-Object PSObject
            $myobject | Add-Member -Type NoteProperty -Name "Name" -Value $Name
            $myobject | Add-Member -Type NoteProperty -Name "IP" -Value $bind[0]
            $myobject | Add-Member -Type NoteProperty -Name "Port" -Value $bind[1]
            $myobject | Add-Member -Type NoteProperty -Name "Host" -Value $bind[2]
            $output += $myObject
        }
    }
    $output | Export-Csv $FileName -NoTypeInformation
}

#
# Main Code
#

# Check for Import or Export
If (($Import -eq $false) -and ($Export -eq $false)) {
    Write-Host "ERROR: Select -Import or -Export" -ForegroundColor Red
    Exit 
} elseif (($Import -eq $true) -and ($Export -eq $true)) {
    Write-Host "ERROR: -Import and -Export cannot both be true" -ForegroundColor Red
    Exit 
} elseif ($import -eq $true) {
    if (!(Test-Path $FileName)) {
        Write-Host "ERROR: $filename does not exist" -ForegroundColor Red
        Exit 
    } 
    Import-Bindings $FileName   
    Exit
} elseif ($Export -eq $true) {
    Export-Bindings $FileName
    exit 
}
