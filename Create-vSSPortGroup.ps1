$VIServer = 'vcenterurl'

$PortGroups = Import-Csv 'test.csv'

Connect-VIServer $VIServer -Credential $cred

if(!$PortGroups) {
    break
}

$vssName = 'vSwitch_temp'
Write-Host "Checking existence of $($vssName)"
if (-not (Get-VirtualSwitch -Name $vssName -ErrorAction SilentlyContinue)) {
    New-VirtualSwitch -Name $vssName -Mtu 9000 -Confirm:$false | Out-Null
}

$vss = Get-VirtualSwitch -Name $vssName

Write-Host "Loop through DVS Port Groups and recreate them on $($vssName)"
foreach ($pg in $PortGroups) {
    $pgName = $pg.Name
    $vlanId = $pg.VlanConfiguration

    # Check if port group already exists
    if (-not (Get-VirtualPortGroup -Name $pgName -VirtualSwitch $vssName -ErrorAction SilentlyContinue)) {
        Write-Host "Creating Port Group: $pgName with VLAN $vlanId on $vssName"
        New-VirtualPortGroup -Name $pgName -VirtualSwitch $vss -VLanId $vlanId -Confirm:$false | Out-Null
    }
    else {
        Write-Host "Port Group $pgName already exists on $vssName, skipping..."
    }
}


Disconnect-VIServer $VIServer -Confirm:$false -Force