function Get-FAPortStatus {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $VMHost,
        [Parameter(Mandatory)]
        [pscredential]$SSHCredential
    )

    process {
        $commandQuery = "./opt/PowerPathsrestdesx8live/bin/powermt display ports;./opt/PowerPathsrestdesx8/bin/powermt display ports"
    
        $sshService = $VMHost | Get-VMHostService | Where-Object { $_.Key -eq "TSM-SSH" }
    
        if ($sshService.Running -ne "True") {
            Start-VMHostService -HostService $sshService -Confirm:$false | Out-Null
        }

        $sshSession = New-SSHSession -ComputerName $VMhost.Name -Credential $SSHCredential -AcceptKey
        try {
            $sshCommand = Invoke-SSHCommand -Command "$($commandQuery)" -SSHSession $sshSession -ErrorAction Stop
        }
        catch {
            throw "$($VMHost.Name) - Unable to establish SSH Session"
        }

        # Split text into lines
        $pattern = "(\d+)\s+(FN\s+\w+:\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)"
        $dataLines = $sshCommand.Output -split "`n" | Select-String -Pattern $pattern
        # Define an array to store custom output
        $output = @()

        # Loop through each line and create custom output
        foreach ($line in $dataLines) {
            if ($line -match $pattern) {
                $object = [PSCustomObject]@{
                    Hostname   = $VMHost.Name
                    Location   = $VMHost | Get-Datacenter
                    Cluster    = $VMHost.Parent
                    vCenter    = $VMHost.Uid.Substring($VMHost.Uid.IndexOf('@') + 1).Split(":")[0]
                    Model      = $VMHost.Model
                    ServiceTag = $VMHost.ExtensionData.Hardware.SystemInfo.SerialNumber
                    StorageID  = $matches[1]
                    Interface  = $matches[2]
                    Wt_Q       = $matches[3]
                    Total      = $matches[4]
                    Dead       = $matches[5]
                    Q_IOs      = $matches[6]
                    Errors     = $matches[7]
                }
                $output += $object
            }
        }

        # Output the custom output
        $output

        Remove-SSHSession -SSHSession $sshSession | Out-Null

        Stop-VMHostService -HostService $sshService -Confirm:$false | Out-Null
    } 
}
