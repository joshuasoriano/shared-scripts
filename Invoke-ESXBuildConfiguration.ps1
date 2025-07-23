function Invoke-ESXBuildConfiguration {
    param (
        $ESXiHostname = '',
        $ESXiUserdesc = 'GIO IaaS - Administrator Account',
        $ESXiPermission = 'Admin',
        $ESXiNewUser = '',
        $ESXiUserPass = '',
        $domain = '',
        $dnsAddresses = @("", "")
        [string[]]$Configuration = @("All")
    )

    # Target ESXi host
    $vmhost = Get-VMHost
    $view_vmhost = Get-View -ViewType HostSystem
    $esxcli = Get-EsxCli -VMHost $vmhost -V2


    #Prechecks
    ###############################################################################################
    $vmhost_authentication = $vmhost | Get-VMHostAuthentication
    ###############################################################################################


    #New Local User
    ###############################################################################################
    if ("All" -in $Configuration -or "LocalUser" -in $Configuration) {
        Write-Host "Creating local account"
        # Check for existing account
        $UserCheck = Get-VMHostAccount -User $ESXiNewUser -ErrorAction SilentlyContinue

        if ($null -eq $UserCheck) {
            ## Ceate new account
            New-VMHostAccount -Id $ESXiNewUser -Password $ESXiUserPass -Description $ESXiUserdesc | Out-Null

            ## Set Permission for new account
            New-VIPermission -Entity (Get-Folder root) -Principal $ESXiNewUser -Role $ESXiPermission | Out-Null

            Write-Host "Local Account Created"
        }

        if ($UserCheck) {
            Write-Host "Local Account Already Exist"
            try {
                ## Update Password
                $UserCheck | Set-VMHostAccount -Password $ESXiUserPass -Description $ESXiUserdesc -ErrorAction Stop | Out-Null
            }
            catch {
                Write-Host $_.Exception.Message
            }

            ## Check existing permission
            $CheckPermission = Get-VIPermission -Principal $ESXiNewUser

            if ($CheckPermission.Role -notlike $ESXiPermission) {
                try {
                    New-VIPermission -Entity (Get-Folder root) -Principal $ESXiNewUser -Role $ESXiPermission -ErrorAction Stop | Out-Null
                }
                catch {
                    Write-Host $_.Exception.Message
                }
            }

    
            Write-Host "Local Account Password has been reset using the provided"
        }
    }
    ###############################################################################################

    #Configure TCP/IP Stack
    ###############################################################################################
    if ("All" -in $Configuration -or "TCPIP" -in $Configuration) {
        Write-Host "Configuring TCP/IP Stack"
        $networkStack = Get-VMHostNetworkStack $vmhost -Name 'defaultTcpipStack'
        if ($networkStack.DnsDomainName -ne $domain) {
            Write-Host 'Configuring TCP/IP Stack'
            if ($vmhost_authentication -eq 'ok') {
                Write-Host 'Leaving Domain'
                Get-VMHostAuthentication | Set-VMHostAuthentication -LeaveDomain -Force -Confirm:$false | Out-Null
            }
        }
        $networkStack | Set-VMHostNetworkStack -HostName $ESXiHostname -DomainName $domain -SearchDomain $domain -DnsAddress $dnsAddresses -Confirm:$false | Out-Null
        Write-Host 'TCP/IP Stack configuration complete'
    }
    ###############################################################################################

    #Configure NTP Service
    ###############################################################################################
    if ("All" -in $Configuration -or "NTP" -in $Configuration) {
        Write-Host "Configuring NTP Service"
        if (($vmHost | Get-VMHostNtpServer).Length -eq 0) {

            Write-Host "Starting ntpd service"
            $vmHost | Get-VMHostService | Where-Object { $ _. key -eq "ntpd" } | Start-VMHostService | Out-Null

            Write-Host "Configuring ntpd service policy"
            $vmHost | Get-VMHostService | Where-Object { $ _. key -eq "ntpd" } | Set-VMHostService -Policy On | Out-Null

            Write-Host 'Adding NTP Servers'
            $vmHost | Add-VMHostNtpServer -NtpServer $dnsAddresses | Out-Null
            Write-Host 'NTP Configuration Complete'
        }
    }
    ###############################################################################################

    #Configure Domain Authentication
    ###############################################################################################
    if ("All" -in $Configuration -or "DomainAuth" -in $Configuration) {
        if ($domainAuth -ne 'Ok') {
            Write-Host "Configuring authentication to domain: $($domain)"
            #Get-VMHostAuthentication -VMHost $vmHost | Set-VMHostAuthentication -JoinDomain -Domain $Domain -Credential $cred -Confirm:$False | Out-Null
            Write-Host "Host has been joined to $($domain)"
        }
    }
    ###############################################################################################

    #Set Power Policy to High Performance
    ###############################################################################################
    if ("All" -in $Configuration -or "PowerPolicy" -in $Configuration) {
        if ($view_vmhost.Hardware.CpuPowerManagementInfo.CurrentPolicy -ne 'High Performance') {
            Write-Host "Configuring Power Policy to High Performance"
            (Get-View ($vmHost | Get-View).ConfigManager.PowerSystem).ConfigurePowerPolicy(1)
            Write-Host "Power Policy set to High Performance"
        }
    }
    ###############################################################################################

    #Services Policy
    ###############################################################################################
    if ("All" -in $Configuration -or "ServicePolicy" -in $Configuration) {
        # Get the services
        $services = Get-VMHostService -VMHost $vmhost

        # Define the services to manage
        $targetServices = @("TSM", "TSM-SSH")

        foreach ($svcName in $targetServices) {
            $service = $services | Where-Object { $_.Key -eq $svcName }

            if ($service) {
                # Stop the service if it's running
                if ($service.Running) {
                    Write-Host "Stopping $svcName..."
                    Stop-VMHostService -HostService $service -Confirm:$false | Out-Null
                }

                # Set startup policy to manual
                Write-Host "Setting $svcName startup policy to Manual..."
                Set-VMHostService -HostService $service -Policy Off  | Out-Null
            }
            else {
                Write-Host "$svcName service not found on $vmhost"
            }
        }
    }
    ###############################################################################################

    #Advanced Settings
    ###############################################################################################
    if ("All" -in $Configuration -or "AdvancedSettings" -in $Configuration) {
        $motdMessage = "WARNING: This system is for __ authorized personnel only, unauthorized access or use may lead to disciplinary action and/or legal penalties, and all activities are recorded and monitored; your use implies consent to monitoring, by the __ Security Team."
 
        # Define the settings to configure
        $AdvSettingProperties = @{
            'Mem.ShareForceSalting'                                  = 2
            'VMFS3.UseATSForHBOnVMFS5'                               = 1
            'Security.PasswordQualityControl'                        = 'retry=3 min=disabled,disabled,disabled,disabled,15'
            'Security.PasswordHistory'                               = 5
            'Security.AccountLockFailures'                           = 5
            'Security.AccountUnlockTime'                             = 900
            'Config.HostAgent.plugins.solo.enableMob'                = 'False'
            'Config.HostAgent.plugins.hostsvc.esxAdminsGroup'        = 'ESX Admins'
            'Config.HostAgent.plugins.hostsvc.esxAdminsGroupAutoAdd' = 'True'
            'VMkernel.Boot.execInstalledOnly'                        = 'True'
            'UserVars.SuppressHyperthreadWarning'                    = 0
            'UserVars.HostClientCEIPOptIn'                           = 2
            'UserVars.SuppressShellWarning'                          = 0
            'UserVars.DcuiTimeOut'                                   = 600
            'UserVars.ESXiShellTimeOut'                              = 900
            'UserVars.ESXiShellInteractiveTimeOut'                   = 900
            'UserVars.ESXiVPsDisabledProtocols'                      = 'sslv3,tlsv1,tlsv1.1'
            'Config.Etc.motd'                                        = $motdMessage
            'Annotations.WelcomeMessage'                             = $motdMessage
            'UserVars.HostClientWelcomeMessage'                      = $motdMessage
        }

        Write-Host "Applying advanced settings values"
        foreach ($key in $AdvSettingProperties.Keys) {
            $value = $AdvSettingProperties[$key]
            Get-AdvancedSetting -Entity $vmHost -Name $key | Set-AdvancedSetting -Value $value -Confirm:$false | Out-Null
        }

        Write-Host "Advanced settings has been configured"
    }
    ###############################################################################################

    #HPP
    ###############################################################################################
    if ("All" -in $Configuration -or "HPP" -in $Configuration) {
        # Define rules to add
        $rules = @(
            @{ Rule = 914; NvmeModel = "IBM     2145" },
            @{ Rule = 915; NvmeModel = "dellemc-powerstore" }
        )

        # Common parameters
        $plugin = "HPP"
        $configString = "pss=LB-Latency,latency-eval-time=60000"

        foreach ($rule in $rules) {
            $ruleId = $rule.Rule
            $model = $rule.NvmeModel

            # Check if rule ID already exists
            $existing = $esxcli.storage.core.claimrule.list.Invoke() | Where-Object {
                $_.Rule -eq $ruleId
            }

            # Remove existing rule if found
            if ($existing) {
                Write-Host "Removing existing rule ID $ruleId"

                $esxcli.storage.core.claimrule.remove.Invoke(@{
                        rule = $ruleId
                    }) | Out-Null
            }

            # Add new rule
            Write-Host "Adding rule ID $ruleId for model '$model'"
            try {
                $esxcli.storage.core.claimrule.add.Invoke(@{
                        rule                = $ruleId
                        type                = "vendor"
                        plugin              = $plugin
                        nvmecontrollermodel = $model
                        configstring        = $configString
                        force               = $true
                    })
            }
            catch {
                Write-Host "Unable to create rule $($ruleId) for $($model)"
            }

            # Set latency threshold
            Write-Host "Setting IO threshold for model '$model' NVMe LUN"
            try {
                $esxcli.storage.core.device.latencythreshold.set.Invoke(@{
                        vendor                    = "NVMe"
                        model                     = $model
                        latencysensitivethreshold = 10
                    }) | Out-Null
            }
            catch {
                Write-Host "Unable to apply latency threshold to : $($model)"
            }
        }

        # Optionally load and apply rules
        $esxcli.storage.core.claimrule.load.Invoke() | Out-Null
        $esxcli.storage.core.claimrule.run.Invoke() | Out-Null
    }
    ###############################################################################################

    #Set NVME NQN
    ###############################################################################################
    if ("All" -in $Configuration -or "NVMeNQN" -in $Configuration) {
        $esxcli.nvme.info.set.Invoke(@{hostnqn = "default" })
    }
    ###############################################################################################
    
}

