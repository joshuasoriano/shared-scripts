############################# User-defined variables. ##########################################################
$Credential = Get-Credential

$vCenters = 'vcenter1.com', 'vcenter2.com'
$RVToolsExeFolder = "C:\Program Files (x86)\Robware\RVTools"
$ExportDirectory = "C:\export"
$ExportConsolidatedFilename = "C:\RVTools_Consolidated.xlsx"
################################################################################################################

function Export-ConsolidatedRVTools {    
    param (
        [Parameter(Mandatory)]
        [string] $ExportDirectory,
        [Parameter(Mandatory)]
        [string] $OutFilename
    )
    
    process {
        [string[]] $items = (Get-ChildItem $ExportDirectory -Recurse).FullName
    
        if ($items.Count -eq 0) {
            throw "No files found in $ExportDirectory"
        }
    
        [string] $inputFilenames = $items -join ";"

        # Merge xlsx files
        $arguments = "-input $($inputFilenames) -output $($OutFilename) -overwrite -verbose"
        Start-Process -FilePath "$($RVToolsExeFolder)\RVToolsMergeExcelFiles.exe" -ArgumentList $arguments -Wait -NoNewWindow
   
        Remove-Item "$($ExportDirectory)\*"

        Get-ChildItem $OutFilename
    }
}

function Wait-Progress {
    while ((Get-Job -State "Running").Count -gt 0) {
        $completedJobs = @(Get-Job -State "Completed")
        $completedCount = $completedJobs.Count
        $totalCount = (Get-Job).Count
        $percentComplete = $completedCount / $totalCount * 100
        Write-Progress -Activity "Processing" -Status "Completed $completedCount of $totalCount" -PercentComplete $percentComplete
        Start-Sleep -Seconds 1
    }
}

$ScriptBlock = {
    param(
        [string]$VIServer,
        [PSCustomObject]$Credential,
        [string]$RVToolsExeFolder,
        [string]$ExportDirectory
    )

    begin {
        Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -DisplayDeprecationWarnings: $false -ParticipateInCeip: $false -Confirm: $false -Scope Session | Out-Null
    }

    process {
        $exportFilename = "$($VIServer).xlsx"
        $start_time = Get-Date
        $max_wait_time = 60

        while ($true) {
            $Arguments = "-s $($VIServer) -u $($Credential.Username) -p $(($Credential.Password | ConvertFrom-SecureString -AsPlainText)) -c ExportAll2xlsx -d $($ExportDirectory) -f $($exportFilename) -DBColumnNames -GetFriendlyNames"

            Start-Process -FilePath "$($RVToolsExeFolder)\RVTools.exe" -ArgumentList $Arguments -Wait

            $file = Get-ChildItem $ExportDirectory -Filter $exportFilename -Recurse | Select-Object -First 1
        
            if ($file) {
                break
            }

            $elapsed_time = New-TimeSpan -Start $start_time -End (Get-Date)
        
            if ($elapsed_time.TotalSeconds -ge $max_wait_time) {
                break
            }

            Start-Sleep -Seconds 3
        }

        return $file
    }
}

Get-Job | Remove-Job -Force

foreach ($VIServer in $vCenters) {
    Start-Job -ScriptBlock $ScriptBlock -Name $VIServer -ArgumentList $VIServer, $Credential, $RVToolsExeFolder, $ExportDirectory
}
 
Wait-Progress

@(Get-Job | Receive-Job)

#Output the consolidated excel file
Export-ConsolidatedRVTools $ExportDirectory $ExportConsolidatedFilename

Get-Job | Remove-Job -Force
########################################################################################################################
