# Connect to vCenter
$VIServer = "vcenterurl"

Connect-VIServer -Server $VIServer -Credential $cred

Get-Datastore -Name "PSTORE-NFS-CONTENTLIBRARY" | Get-VM | Get-CDDrive | Set-CDDrive -NoMedia -Confirm:$false

Disconnect-VIServer $VIServer -Confirm:$false -Force