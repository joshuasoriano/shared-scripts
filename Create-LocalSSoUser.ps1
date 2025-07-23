$viServer = 'uschvcenter4003.corporate.ingrammicro.com'

$firstName = ''
$lastName = ''
$userName = ''
$emailAddress = ''


Connect-SsoAdminServer -Server $viServer -Credential $cred -SkipCertificateCheck

$fullName = "$($firstName) $($lastName)"

$UserCheck = Get-SsoPersonUser -Name $fullName

if (!$UserCheck) {
    $newUser = New-SsoPersonUser -UserName '' -Password '' -EmailAddress '' -Description 'Local user' -FirstName '' -LastName ''
}

Get-VcenterServerGlobalPermissions -Server (Connect-VIServer -Server $viServer -Credential $cred) -TargetUser $UserCheck

<#
if ($newUser) {
    Add-UserToSsoGroup -User $newUser -TargetGroup 'Administrator'
}
#>

Disconnect-SsoAdminServer -Server $viServer