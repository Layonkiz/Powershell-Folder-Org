$SourceDirectory = "E:\000_Temp"
$videos = "E:\03_Videos\000_Temp"
$docs = "E:\01_Documents\000_Temp"
$pics = "E:\02_Images\000_Temp"
$audios = "E:\04_Audios\000_Temp"
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $SourceDirectory
$watcher.NotifyFilter = [System.IO.NotifyFilters]::DirectoryName
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true

    Register-ObjectEvent -InputObject $watcher -EventName Created -Action = {
        $NewFolder = $Event.SourceEventArgs.FullPath
        $changeType = $Event.SourceEventArgs.Changetype
        $parent = Split-Path $NewFolder -Parent
        Write-Host "New folder detected: $changeType - $NewFolder"
        if ($changeType -eq "Created" -and (Test-Path $NewFolder -PathType Container) -and $parent -eq $SourceDirectory) {
        Write-Host "Processing new folder: $NewFolder"
        # Ensure the destination directories exist
        if (-not (Test-Path -Path $videos)) {   
            New-Item -Path $videos -ItemType Directory -Force
        }   
        if (-not (Test-Path -Path $docs)) {   
            New-Item -Path $docs -ItemType Directory -Force
        }
        if (-not (Test-Path -Path $pics)) {   
            New-Item -Path $pics -ItemType Directory -Force
        }
        if (-not (Test-Path -Path $audios)) {   
            New-Item -Path $audios -ItemType Directory -Force
        }
        # Veryfy the file type contained into $NewFolder and move $NewFolder to the appropriate directory
        $files = Get-ChildItem -Path $NewFolder -recursive -File
        foreach ($file in $files) { 
            if ($file.Extension -eq ".mkv" -or $file.Extension -eq ".mp4") {
                Move-Item -Path $NewFolder -Destination $videos
            } elseif ($file.Extension -eq ".pdf" -or $file.Extension -eq ".docx") {
                Move-Item -Path $NewFolder -Destination $docs
            } elseif ($file.Extension -eq ".jpg" -or $file.Extension -eq ".png") {
                Move-Item -Path $NewFolder -Destination $pics
            } elseif ($file.Extension -eq ".mp3" -or $file.Extension -eq ".wav") {
                Move-Item -Path $NewFolder -Destination $audios
            } else {    
                Write-Host "File type not recognized: $($file.Name)"
            }   
        }
        Write-Host "Files moved successfully from $NewFolder"
    }
    }
$onCreated = Register-ObjectEvent -InputObject $watcher -EventName Created -Action $action  
Write-Host "Watching for new folders in $SourceDirectory..."
# Keep the script running to monitor for changes
while ($true) {
    Start-Sleep -Seconds 5
}   
# Unregister the event when done (optional, for cleanup)
# Unregister-Event -SourceIdentifier $onCreated.Name    
# $watcher.Dispose()  # Dispose of the watcher when no longer needed
# Write-Host "File watcher stopped."

      