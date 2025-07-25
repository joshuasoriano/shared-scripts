function Show-Progress {
    while ((Get-Job -State "Running").Count -gt 0) {
        $completedJobs = @(Get-Job -State "Completed")
        $completedCount = $completedJobs.Count
        $totalCount = (Get-Job).Count
        $percentComplete = $completedCount / $totalCount * 100
        Write-Progress -Activity "Processing" -Status "Completed $completedCount of $totalCount" -PercentComplete $percentComplete
        Start-Sleep -Seconds 1
    }
    
}

###########################################################################################################################################

$ScriptBlock = {
    param(
        $VIServer,
        [pscredential]$Credential
    )

    $result = @()

    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -DisplayDeprecationWarnings:$false -ParticipateInCeip:$false -Confirm:$false -Scope Session | Out-Null
    
    try {
        Connect-VIServer -Server $VIServer -Credential $Credential -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Error "$($VIServer) - $($_.Exception.Message)"
        exit 1
    }

    ###########################################################

    ###########################################################


    Disconnect-VIServer $VIServer -Force -Confirm:$false

    $result
}

###########################################################################################################################################

Get-Job | Remove-Job -Force

foreach ($VIServer in $VIServers) {
    Start-Job -ScriptBlock $ScriptBlock -Name $VIServer -ArgumentList $VIServer, $cred
}

Show-Progress
@(Get-Job | Receive-Job)