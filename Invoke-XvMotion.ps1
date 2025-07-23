function Invoke-XvMotion {
    param (
        $CsvPath,
        $MaxSession=3,
        $WaitingTime=5,
        $TargetCluster,
        $TargetDatastore
    )

    $runningSessions = 0
    $taskName = 'ApplyStorageDrsRecommendation_Task'

    $CsvData = Import-Csv -Path $CsvPath -ErrorAction Stop

    if (!$CsvData) {
        throw 'Data provided is empty'
    }

    $destination_cluster = Get-Cluster -Name $TargetCluster
    $destination_vmhost = $destination_cluster | Get-VMHost | Sort-Object Name
    $hostCount = $destination_vmhost.Count
    $index = 0

    $CsvData | ForEach-Object {
        Write-Host "-------------------------------------------------------------------"
        Write-Host "Checking the running vMotion now .... Pls wait ..... "
        Write-Host "-------------------------------------------------------------------"

        do {

            $runningSessions = (Get-Task | Where-Object { $_.name -like $taskName -and $_.State -eq "Running" -and $_.ExtensionData.Info.Reason.Username -match 'ussorj07adm_vc' }).Count

            if ($runningSessions -ge $MaxSession) {
                Write-Host "The current running vMotion sessions is $($runningSessions). No new vMotion will be started now. Next check will be performed in $($WaitingTime) seconds"
                Start-Sleep -Seconds $waitingTime
            }
            else {
                Write-Host "The current running vMotion sessions is $($runningSessions), a new storage vMotion will be started soon"
                Start-Sleep -Seconds 3
            }
        } while ( $runningSessions -ge $MaxSession )

        $currentVMHost = $destination_vmhost[$index % $hostCount]

        Write-Host "-------------------------------------------------------------------"
        Write-Host "The cross cluster vMotion will start for below VM ... "
        Write-Host "$($_.vmname) --- > $($TargetCluster) / $($currentVMHost.Name) >>> $($TargetDatastore)"
        Get-VM $ _.vmname | Move-VM -Destination $currentVMHost -Datastore $TargetDatastore -VMotionPriority High -DiskStorageFormat Thick -RunAsync -Confirm:$false | Out-Null
        Write-Host "-------------------------------------------------------------------"

        $index++
        
    }
}
