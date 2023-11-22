
# Classes
class NsgAuditInfo {
    [string]$Name
    [string]$ResourceID
    [string[]]$AssociatedSubnets
    [string[]]$AssociatedVMs
    [string[]]$AssociatedNICs
    [PSCustomObject[]]$Rules

    NsgAuditInfo([string]$Name, [string]$ResourceID) {
        $this.Name = $Name
        $this.ResourceID = $ResourceID
        $this.AssociatedSubnets = @()
        $this.AssociatedVMs = @()
        $this.AssociatedNICs = @()
        $this.Rules = @()
    }
}

function Export-NsgAuditInfoToHTML {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [NsgAuditInfo[]]$AuditInfoArray
    )

    begin {
        $htmlOutput = @"
<!DOCTYPE html>
<html>
<head>
    <style>
        table {
            border-collapse: collapse;
        }
        th, td {
            border: 1px solid black;
            padding: 8px;
        }
    </style>
</head>
<body>
<h2>Network Security Group Audit Report</h2>
"@
    }

    process {
        foreach ($auditInfo in $AuditInfoArray) {
            $htmlOutput += @"
<h3>Network Security Group: $($auditInfo.Name)</h3>
<p>Resource ID: $($auditInfo.ResourceID)</p>
<p>Associated Subnets:</p>
<ul>
"@
            foreach ($subnet in $auditInfo.AssociatedSubnets) {
                $htmlOutput += @"
    <li>$subnet</li>
"@
            }
            $htmlOutput += @"
</ul>

<p>Associated VMs:</p>
<ul>
"@
            foreach ($vm in $auditInfo.AssociatedVMs) {
                $htmlOutput += @"
    <li>$vm</li>
"@
            }
            $htmlOutput += @"
</ul>

<p>Associated NICs:</p>
<ul>
"@
            foreach ($nic in $auditInfo.AssociatedNICs) {
                $htmlOutput += @"
    <li>$nic</li>
"@
            }
            $htmlOutput += @"
</ul>
<p>Rules:</p>

<table>
    <tr>
        <th>Rule Name</th>
        <th>Priority</th>
        <th>Source IP/CIDR</th>
        <th>Source Port Range</th>
        <th>Destination IP/CIDR</th>
        <th>Destination Port Range</th>
        <th>Protocol</th>
        <th>Action</th>
        <th>Direction</th>
        <th>Description</th>
    </tr>
"@
            foreach ($rule in $auditInfo.Rules) {
                $htmlOutput += @"
    <tr>
        <td>$($rule.RuleName)</td>
        <td>$($rule.Priority)</td>
        <td>$($rule.SourceIP)</td>
        <td>$($rule.SourcePortRange)</td>
        <td>$($rule.DestinationIP)</td>
        <td>$($rule.DestinationPortRange)</td>
        <td>$($rule.Protocol)</td>
        <td>$($rule.Action)</td>
        <td>$($rule.Direction)</td>
        <td>$($rule.Description)</td>
    </tr>
"@
            }

            $htmlOutput += @"
</table>
<hr>
"@
        }
    }

    end {
        $htmlOutput += @"
</body>
</html>
"@

        $htmlOutput
    }
}

# Dont forget Connect-AzAccount using whatever auth mechanism you require.  Highly recommended not hard coding username & password! :)
Connect-AzAccount 

# May need to use Set-AzContext here if more than one subscription.


# Get the NSG associated with the public IP (if any)
$all_nsgs = Get-AzNetworkSecurityGroup 
$all_nics = Get-AzNetworkInterface 
$all_vms = Get-AzVM

$output = @()
foreach ($nsg in $all_nsgs) {
    $Name = $nsg.Name
    $nsgID = $nsg.Id
    $auditInfo = [NsgAuditInfo]::new($Name, $nsgID)

    # Check for Subnets asscassociated with NSG
    foreach ($subnet in $nsg.Subnets) {
        $subnet_config = Get-AzVirtualNetworkSubnetConfig -ResourceId $subnet.Id
        $auditInfo.AssociatedSubnets += $subnet_config.Name

        # Check each NIC configuration to see if it contains an Ip configuation with the current subnet
        foreach ($nic in $all_nics) { 
            if ($nic.ipconfigurations[0].subnet.id -eq $subnet_config.Id ) { 

                # Found a matching Subnet, check if there is a VM configured on NIC
                if ($null -ne $nic.VirtualMachine.ID) {
                    $vm = $all_vms | Where-Object { $_.Id -eq $nic.VirtualMachine.ID }
                    if ($vm) { 
                        $auditInfo.AssociatedVMs += $vm.Name 
                    }
                }
            }
        }
    }

    # Check for VMs using nics associated with the NSG
    $matchingNics = $all_nics | Where-Object { $_.Id -in $nsg.NetworkInterfaces.Id }
    foreach ($nic in $matchingNics) { 
        $vm = $all_vms | Where-Object { $_.Id -eq $nic.VirtualMachine.ID }
        if ($vm) { 
            $auditInfo.AssociatedVMs += $vm.Name 
        }
        $auditInfo.AssociatedNICs += $nic.Name
    }
    
    # Get the inbound security rules for the NSG
    $Rules = Get-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg

    if ($Rules) {
        foreach ($nsg_rule in $Rules) {
            # Add an example NSG rule to the object
            $rule = [PSCustomObject]@{
                RuleName             = $nsg_rule.Name
                Priority             = $nsg_rule.Priority
                SourceIP             = $nsg_rule.SourceAddressPrefix
                SourcePortRange      = $nsg_rule.SourcePortRange
                DestinationIP        = $nsg_rule.DestinationAddressPrefix
                DestinationPortRange = $nsg_rule.DestinationPortRange
                Protocol             = $nsg_rule.Protocol
                Action               = $nsg_rule.Access
                Direction            = $nsg_rule.Direction
                Description          = $nsg_rule.Description
            }
            $auditInfo.Rules += $rule
        }
    }
    $output += $auditInfo
}
$output | Select-Object Name, AssociatedSubnets, AssociatedVMs, AssociatedNICs, Rules | Format-Table -AutoSize
Out-File -FilePath ".\NsgAudit.html" -InputObject (Export-NsgAuditInfoToHTML $output)
