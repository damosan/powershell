#     _        _   _             ____  _               _                   
#    / \   ___| |_(_)_   _____  |  _ \(_)_ __ ___  ___| |_ ___  _ __ _   _ 
#   / _ \ / __| __| \ \ / / _ \ | | | | | '__/ _ \/ __| __/ _ \| '__| | | |
#  / ___ \ (__| |_| |\ V /  __/ | |_| | | | |  __/ (__| || (_) | |  | |_| |
# /_/   \_\___|\__|_| \_/ \___| |____/|_|_|  \___|\___|\__\___/|_|   \__, |
#                                                                   |___/ 


# Get the group members from GroupOne, and if they exist in GroupTwo, remove them.  Useful for group migrations.  Whatif for safety during testing :)
(Get-ADGroupMember GROUP_ONE).SamAccountName | %{Remove-ADGroupMember -Identity GROUP_TWO -Members $_ -Confirm:$false -WhatIf}

# Get the last logon time stamp from a list of user accounts in a specified OU
Get-ADUser -SearchBase "OU=SOME OU,DC=LOCAL,DC=DOMAIN" -Filter * -Properties * | Select-Object Name, description, @{Name="LastLogonTimeStamp";Expression={([datetime]::FromFileTime($_.LastLogonTimeStamp))}} | Export-Csv -NoTypeInformation ".\SOME_PATH\Accounts.csv"

#  Get the group members, pipe to Get-ADUser, select mail property.
Get-ADGroupMember SOME_GROUP | Get-ADUser -Properties mail | Select-Object mail

# Import CSV, if no mobile, export name and email
Import-Csv .\ldapusers.csv |  %{if ($_.Mobile -like ""){ Get-ADUser $_.dn -Properties displayName, mail | Select-Object displayName, samAccountName, mail | Export-Csv -NoTypeInformation -Append unregistered.csv}}

# Get AD users with no password required (That's BAD) 
Get-ADUser -Filter {PasswordNotRequired -eq $true} | Select-Object samAccountName, Name, Enabled | Export-Csv -NoTypeInformation E:\Scripts\nopasswordrequired.csv

# Get members of AD group
Get-ADGroupMember "GROUP_NAME"

# Get members of AD group, pipe to Get-ADUser to get account details
Get-ADGroupMember "GROUP_NAME" | Get-ADUser

# Get Members, Properties and Methods of the first group member
(Get-ADGroupMember "GROUP_NAME")[0] | Get-Member

# Export group members to a CSV
Get-ADGroupMember "GROUP_NAME" | Get-ADUser -Properties DisplayName, Title | Select-Object DislayName, Title | Export-Csv "GROUP_MEMBERS.csv" -NoTypeInformation

# Get nested group members
Get-ADGroupMember "GROUP_NAME" -Recursive | Get-ADUser -Properties DisplayName, Title | Select-Object DisplayName, Title 

# Convert AD time to readable time
[DateTime]::FromFileTime($AD_OBJECT.LastLogonTimeStamp)


# ______ _ _           
# |  ____(_) |          
# | |__   _| | ___  ___ 
# |  __| | | |/ _ \/ __|
# | |    | | |  __/\__ \
# |_|    |_|_|\___||___/               
#                      

# Roll log files
Get-ChildItem -Path ".\SOME_PATH\LogFiles" | 
   where-object {$_.LastWriteTime -lt (get-date).AddDays(-31)} | 
   Remove-item

# Loads the logins file into memory via get-content, then parses SOME_LOG_FILE... and running a grep on each of the logins contained in the logins file.  (No dount can be done multiple different ways in pure bash or pwsh, this was an expirment in combining the two.)
Get-Content ./logins.txt | %{cat ./SOME_LOG_FILE.log | grep $_  -C 1 }

# Export to CSV
Get-ChildItem | Export-Csv "Listing.csv"

# Remove type information from top of CSV file (PowerShell 5.1)
Get-ChildItem | Export-Csv "Listing.csv" -NoTypeInformation

# Select specific attributes to export to CSV
Get-ChildItem | Select-Object Name,FullName,CreationTime,LastAccessTime | Export-Csv "Listing.csv" -NoTypeInformation

# Import XML File
[xml]$k = Get-Content -Path .\MyXMLFile.xml

# . Source External scripts, relative path to script location.
. "$PSScriptRoot\EXTERNAL_FILE.ps1"


#  __  __ _          
# |  \/  (_)___  ___ 
# | |\/| | / __|/ __|
# | |  | | \__ \ (__ 
# |_|  |_|_|___/\___|
#                   

# Get PowerShell Version
(get-host).version

# Get Uptime PowerShell 5.1
(get-date) – (gcim Win32_OperatingSystem).LastBootUpTime

# Create DateTime strings for file names
((get-date -Format "dd-MM-yyyy") + "-SOME_FILE.txt")
((get-date -Format "yyyMMdd-HHmm") + "-SOME_FILE.txt")

# Get Uptime PowerShell Core (6+)
Get-Uptime

# Get Local Group Members
Get-LocalGroupMember -Group Administrators

# Get Remote Group Members
Invoke-Command -ComputerName "SERVER01" -ScriptBlock {Get-LocalGroupMember -Name 'Administrators'}

# VSCode Examples (https://code.visualstudio.com/docs/languages/powershell)
code (Get-ChildItem $Home\.vscode\extensions\ms-vscode.PowerShell-*\examples)[-1]

# Get temperate from Dell Server.  Worked circa 2010
do {Clear-Host; get-content .\SERVERS.txt | 
      %{gwmi -namespace root\cimv2\dell -class CIM_NumericSensor -ComputerName $_ -filter "SensorType = '2'"| 
         ft __SERVER, Name, @{n="CurrentReading";e={ ($_.CurrentReading) / 10 }}, @{n="Warning";e= {($_.UpperThresholdNonCritical) / 10}}, @{n="Critical";e={($_.UpperThresholdCritical) / 10} } -AutoSize };Write-Host "`n`nPress CTRL-C to Exit.";Start-Sleep -Seconds 15 } until ( $x -eq 0 )


#   _   _      _                      _    _             
#  | \ | | ___| |___      _____  _ __| | _(_)_ __   __ _ 
#  |  \| |/ _ \ __\ \ /\ / / _ \| '__| |/ / | '_ \ / _` |
#  | |\  |  __/ |_ \ V  V / (_) | |  |   <| | | | | (_| |
#  |_| \_|\___|\__| \_/\_/ \___/|_|  |_|\_\_|_| |_|\__, |
#                                                  |___/ 

# Test for open ports
Test-NetConnection -ComputerName SERVER01 -port 80        

# Ping
Test-Connetion -ComputerName DESKTOP666

# Ping multiple servers with incrementing name
$arr = 1..10
foreach ($a in $arr) {Test-Connection "SERVER$A" -Count 1 | Select-Object Destination, Address }

# Quiet ping returns true or false, useful for conditional statements
Test-Connetion -ComputerName DESKTOP666 -Quiet

# Get external IP Address
Invoke-RestMethod ifconfig.co/json

# Web request using local proxy
Invoke-WebRequest https://secure.eicar.org/eicar.com -OutFile eicar.com -Proxy "http://webproxy.some.local.domain:8080"

# TLS Version for web requests
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# HTTP Listener
$httpListener = New-Object System.Net.HttpListener
$httpListener.Prefixes.Add('http://192.168.0.1:80/')
$httpListener.Start()



# ASCII Headers
# http://patorjk.com/software/taag/#p=display&f=Big&t=Files



