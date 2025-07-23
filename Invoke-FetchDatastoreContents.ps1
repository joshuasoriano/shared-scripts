function Invoke-FetchDatastoreContents {

    $datastoreFiles = @()

    # Get all datastores
    $datastores = Get-Datastore | Where-Object { $_.Type -eq "VMFS" -or $_.Type -eq "NFS" -or $_.Type -eq "vSAN" }

    foreach ($ds in $datastores) {
        Write-Host "Processing datastore: $($ds.Name)"
    
        $dsBrowser = Get-View $ds.ExtensionData.Browser
        $searchSpec = New-Object VMware.Vim.HostDatastoreBrowserSearchSpec
        $searchSpec.MatchPattern = @("*")

        # Start at the root folder of the datastore
        $rootPath = "[" + $ds.Name + "]"

        # Search in the root folder
        $searchResult = $dsBrowser.SearchDatastoreSubFolders($rootPath, $searchSpec)

        foreach ($folder in $searchResult) {
            foreach ($file in $folder.File) {
                $datastoreFiles += [PSCustomObject]@{
                    Datastore  = $ds.Name
                    Folder     = $folder.FolderPath
                    FileName   = $file.Path
                    FileSizeMB = [math]::Round($file.FileSize / 1MB, 2)
                    FileType   = $file.GetType().Name
                }
            }
        }

    }

    return $datastoreFiles
}