.asnp Citrix.*

# Need to udpate so that script prompts user for server name and then when connecting
# to prompt for username and password

$deliveryController = server_name

#  Get list of all delivery groups (VDI Desktops and XenApp servers)
$deliveryGroups = Get-BrokerDesktopGroup -IsRemotePC $false -AdminAddress $deliveryController

# Get list of only application servers (XenApp servers)
$deliveryGroupsServersOnly = Get-BrokerDesktopGroup -IsRemotePC $false -AdminAddress $deliveryController -DeliveryType AppsOnly

# Array to store the Delivery Group name of application servers only (XenApp servers)
$appServerGroup = @()
foreach ($group in $deliveryGroupsServersOnly){
    $appServerGroup += $group.Name
}

# Initialize flags and variables
$promptUser = $true
$checkall = $false
$checkserversonly = $false
$provisionedSystems = @()

#  Continue prompting user for valid delivery group to check, all or just servers
while ($promptUser) {

    # List all the delivery group names
    $deliveryGroups | Format-Table Name

    # Prompt user for Delivery Group to check
    $deliveryGroupToCheck = Read-Host "`nEnter delivery group you want to check for Write Cache available or enter 'All' for all systems or 'Servers' for only App Servers: "

    # Check user's input
    foreach ($group in $deliveryGroups) {

        # if user input is valid, continue
        if (($group.Name -eq $deliveryGroupToCheck) -or ($deliveryGroupToCheck -eq "all") -or ($deliveryGroupToCheck -eq "servers")) {
            $promptUser = $false
        
            # set flag if user wants to check all systems
            if ($deliveryGroupToCheck -eq "all") {
                $checkall = $true
            }

            # set flag if user wants to check only servers
            if ($deliveryGrouptoCheck -eq "servers") {
                $checkserversonly = $true
            }
            break
        }
    }
    
    # user input was invalid
    if ($promptUser -eq $true) {
        "Delivery group does not exist.  Please try again.`n"
 
    }
}


"Querying all systems in Delivery group " + $deliveryGroupToCheck + ".  Note that only powered on machines will be checked. `n"

# Process which groups to check
if ($checkall -eq $true) {
    $provisionedSystems = Get-BrokerDesktop -AdminAddress $deliveryController -PowerState On
} elseif ($checkserversonly -eq $true) {
    foreach ($group in $appServerGroup) {
        $provisionedSystems += Get-BrokerDesktop -AdminAddress $deliveryController -PowerState On -DesktopGroupName $group
    }
} else {
    $provisionedSystems = Get-BrokerDesktop -AdminAddress $deliveryController -PowerState On -DesktopGroupName $deliveryGroupToCheck
}

# Get Write Cache Free space from delivery groups user selected
foreach ($server in $provisionedSystems) {

    Get-WmiObject -Class win32_volume -cn $server.HostedMachineName -ea SilentlyContinue -ErrorVariable errs |
              Select-Object @{LABEL='Computer';EXPRESSION={$server.HostedMachineName}},
                            driveletter,
                            label, 
                            @{LABEL='Free Space (GB)'; EXPRESSION={"{0:N2}" -f ($_.freespace/1GB)}}, 
                            @{LABEL='Recent user'; EXPRESSION={$server.LastConnectionUser}}|
              Where-Object {$_.driveletter -eq "D:"} |
              Format-Table
              
              
    if ($errs) {
        Write-Host "There was a problem accessing" $server.HostedMachineName ".  Error: " $errs "`n"
    }
}



