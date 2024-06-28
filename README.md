Get-FAPortStatus.ps1

Required Module:
VMWare PowerCLI, POSH-SSH

Usage:
Connect-VIServer 'vcenter1.com' -Credential (Get-Credential)
Get-VMHost | Get-FAPortStatus -SSHCredential (Get-Credential)
Disconnect-VIServer * -Confirm:$false -Force

----------------------------------------------------------------------

Get-WebCertificateInfo.ps1

Usage:
"facebook.com", "google.com" | Get-WebCertificateInfo

----------------------------------------------------------------------
