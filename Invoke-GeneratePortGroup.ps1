function Invoke-GeneratePortGroup {
    param (
        $vSSName = 'vSwitch_temp',
        $Mtu = 9000,
        $PortGroups
    )

    if (!$PortGroups) {
        Write-Error "No port groups provided. Please provide a list of port groups to create."
        exit 1
    }
    
    if (-not (Get-VirtualSwitch -Name $vssName -ErrorAction SilentlyContinue)) {
        Write-Output "Creating Virtual Switch: $vSSName with MTU $Mtu"
        New-VirtualSwitch -Name $vssName -Mtu $Mtu -Confirm:$false | Out-Null
    }

    $vss = Get-VirtualSwitch -Name $vssName

    Write-Output "Creating Port Groups on Virtual Switch: $vssName"
    foreach ($pg in $PortGroups) {
        $pgName = $pg.Name
        $vlanId = $pg.VlanConfiguration

        # Check if port group already exists
        if (-not (Get-VirtualPortGroup -Name $pgName -VirtualSwitch $vssName -ErrorAction SilentlyContinue)) {
            Write-Output "Creating Port Group: $pgName with VLAN $vlanId on $vssName"
            New-VirtualPortGroup -Name $pgName -VirtualSwitch $vss -VLanId $vlanId -Confirm:$false | Out-Null
        }
        else {
            Write-Output "Port Group $pgName already exists on $vssName, skipping..."
        }
    }
}




$VIServer = ''
Connect-VIServer $VIServer -Credential (Get-Credential)
Disconnect-VIServer $VIServer -Confirm:$false -Force