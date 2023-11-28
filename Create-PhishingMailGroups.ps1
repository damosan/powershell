<#
.SYNOPSIS
Create CSV files for importing into GoPhish.  

.DESCRIPTION
GoPhish is a nifty free tool for SME & Not-for-Profit internal phishing simulations.  I like to split the
user base across a number of groups and trickle emails to those users, to try and avoid alerting many 
people at once.

This script creates CSV files for importing users into GoPhish.  Script randomly allocates AD user accounts 
to groups based on the number of groups or required group size.

Requried CSV format for GoPhish

First Name,Last Name,Email,Position
Example,User,foobar@example.com,Systems Administrator

https://docs.getgophish.com/user-guide/building-your-first-campaign/importing-groups

.PARAMETER GroupBy
How to group users.  

    - GroupNumber : Users evenly distrubuted across number of groups specificed in GroupNumber parameter.
    - GroupSize : Users distributed into groups of size specified.  Depending on total number of user accounts, 
                  the last group could contain as little as 1 user account.

.PARAMETER GroupNumber
The number of groups required.  Ignored if GroupSize selected as above.

The number of members of each group is calculated by using [math]::ceiling to round up. If the number of groups is close to
the number of users, rounding up may result in lower group numbers than expected.  Ignoring this as for my purposes the user
count is in the hundreds and only 4-5 grops required.

.PARAMETER GroupSize
The size of each group.  Ignored if GroupNumber selected as above.

.EXAMPLE 
Get all users from AD and randomly seperate them into 4 groups.

    Create-PhishingMailGroups.ps1 -GroupBy GroupNumber -GroupNumber 4
#>
param(
    [Parameter(Mandatory = $true)]
    [string]    
    [ValidateSet("GroupNumber", "GroupSize")]
    $GroupBy,

    [int]
    $GroupNumber,

    [int]
    $GroupSize
)

# Validate Params
if ($GroupBy -eq "GroupNumber") {
    if (!($GroupNumber)) {
        Write-Host "GroupNumber required.  Please specifiy the required number of groups using -GroupNumber" -ForegroundColor Yellow
        exit
    }    
} elseif ($GroupBy -eq "GroupSize") {
    if (!($GroupSize)) {
        Write-Host "GroupSize required.  Please specifiy the required number of groups using -GroupSize" -ForegroundColor Yellow
        exit
    }   
} else {
    Write-Host "This can't be happening" -ForegroundColor Red
    exit
}


# Specify the distinguished name of the target OU(s)
$account_OUs = (
    "OU=Users,DC=company,DC=local", 
    "OU=More Users,DC=company,DC=local"
)

# Accounts to exclude by sAMAccountNAme, i.e. test and service accounts.
# Of course ideally these are in a different OU, but sometimes we inherit less than ideal systems. ¯\_(ツ)_/¯
# i.e.
$exceptions = (
    "testuser01",
    "testuser02",
    "testuser03",
    "serviceaccount01",
    "serviceaccount02",
    "serviceaccount03"
)

$user_properties = @(
    "GivenName",           
    "Surname",           
    "EmailAddress",
    "Title",
    "sAMAccountName"
)

function Remove-SelectedUsers {
    Param (
        [Parameter(Mandatory = $true)][array]$AllUsers,
        [Parameter(Mandatory = $true)][array]$CurrentGroup
    )

    $return_result = @()
    foreach ($user in $AllUsers) {
        # Only return users not in the current group.
        if (!($CurrentGroup.sAMAccountName).Contains($user.sAMAccountName)) {
            $return_result += $user
        }
    }
    return $return_result
}


function Get-AllAdUsers {
    param (
        [Parameter(Mandatory = $true)][array]$OUs
    )

    $return_result = @()
    foreach ($ou in $ous) {
        # Retrieve users from the specified OU, enabled accounts onlys
        $users = Get-ADUser -Filter 'enabled -eq $true' -SearchBase $ou -Properties $user_properties
    
        foreach ($user in $users) {
            # Check for exceptions
            if (!($exceptions -contains ($user.sAMAccountName))) {
                # Get attributes for each user, name according to GoPhish requirements.
                $user_attributes = [ORDERED]@{
                    "First Name"     = $user.GivenName
                    "Last Name"      = $user.Surname
                    "Email"          = $user.EmailAddress
                    "Position"       = $user.Title
                    "sAMAccountName" = $user.sAMAccountName
                }
    
                # Assign attributes to Output object
                $new_user = New-Object psobject -Property $user_attributes
                $return_result += $new_user
            }
        }
    }

    # Output all users to CSV
    $return_result |  Select-Object "First Name", "Last Name", Email, Position, sAMAccountName | 
        Sort-Object "First Name" |
        Export-Csv "all_users.csv" -NoTypeInformation
            
    return $return_result
}

#
# Main Code
# 

# Get All Users
$all_users = Get-AllAdUsers $account_OUs 

# Use a subset for testing to avoid querying AD constantly
#$all_users = Import-Csv ".\all_users_subset.csv"

# Get total number of users
$count = ($all_users).Count

# Set initial group number
$current_group_number = 1

if ($GroupBy -eq "GroupNumber") {
    if ($GroupNumber -gt $count) {
        Write-Host "More groups ($GroupNumber) requested than users ($count) found.  Try again with less groups." -ForegroundColor Yellow
        exit
    } else {
        # Get-Random requires count (group size), define by dividing user count by groups required, rounding up.
        $GroupSize = [math]::ceiling($count / $GroupNumber)
    }
} elseif ($GroupBy -eq "GroupSize") {
    if ($GroupSize -gt $count) {
        Write-Host "Larger size ($GroupSize) requested than users ($count) found.  Creating one group." -ForegroundColor Green
    } 
} else {
    Write-Host "This can't be happening again!" -ForegroundColor Red
    exit
}

# If count is greater than zero, there are still users to assign
while ($count -gt 0) {
    $current_group = @()
    
    $group_name = "group_$current_group_number.csv"
    $current_group = $all_users | Get-Random -Count $GroupSize |  Select-Object "First Name", "Last Name", Email, Position, sAMAccountName
    $current_group | Select-Object "First Name", "Last Name", Email, Position | 
        Sort-Object "First Name" | 
        Export-Csv $group_name -NoTypeInformation

    $all_users = Remove-SelectedUsers $all_users $current_group

    $count = $count - $GroupSize
    $current_group_number = $current_group_number + 1
}  

