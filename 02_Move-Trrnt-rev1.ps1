# Define source and destination directories
$SourceDirectory = "E:\000_Temp"
$videos = "E:\03_Videos\000_Temp"
$docs = "E:\01_Documents\000_Temp"
$pics = "E:\02_Images\000_Temp"
$audios = "E:\04_Audios\000_Temp"

# Ensure destination directories exist
$destinations = @($videos, $docs, $pics, $audios)
foreach ($dir in $destinations) {
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory
    }
}

# Define extension-to-destination mapping (keys in lowercase)
$extensionMap = @{
    ".mp4"  = $videos
    ".avi"  = $videos
    ".mkv"  = $videos
    ".pdf"  = $docs
    ".docx" = $docs
    ".txt"  = $docs
    ".jpg"  = $pics
    ".png"  = $pics
    ".gif"  = $pics
    ".mp3"  = $audios
    ".wav"  = $audios
    ".flac" = $audios
}

# Function to move folders with retry logic
function Move-FolderWithRetry {
    param (
        [string]$source,
        [string]$destination
    )
    $maxRetries = 5
    $retryDelay = 2 # seconds
    for ($i = 0; $i -lt $maxRetries; $i++) {
        try {
            Move-Item -Path $source -Destination $destination -Force -ErrorAction Stop
            Write-Host "Moved folder: $source to $destination"
            return
        } catch {
            Start-Sleep -Seconds $retryDelay
        }
    }
    Write-Host "Failed to move folder after $maxRetries attempts: $source to $destination"
}

# Set up FileSystemWatcher for directories
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $SourceDirectory
$watcher.NotifyFilter = [System.IO.NotifyFilters]::DirectoryName
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true

# Register event handler for folder creation
Register-ObjectEvent -InputObject $watcher -EventName Created -Action {
    $newFolderPath = $Event.SourceEventArgs.FullPath
    if (Test-Path $newFolderPath -PathType Container) {
        # Wait 10 seconds to allow files to be added
        Start-Sleep -Seconds 70
        # Get all files in the new folder
        $files = Get-ChildItem -Path $newFolderPath -File
        # Filter files with mapped extensions
        $mappedFiles = $files | Where-Object { $extensionMap.ContainsKey($_.Extension.ToLower()) }
        if ($mappedFiles) {
            # Group by lowercase extension
            $groups = $mappedFiles | Group-Object -Property { $_.Extension.ToLower() }
            # Find the group with the highest count
            $mostCommonGroup = $groups | Sort-Object -Property Count -Descending | Select-Object -First 1
            $extension = $mostCommonGroup.Name
            $destinationDir = $extensionMap[$extension]
            # Move the folder to the destination
            Move-FolderWithRetry -source $newFolderPath -destination $destinationDir
        } else {
            Write-Host "No files with mapped extensions found in $newFolderPath; folder not moved."
        }
    }
}

# Keep the script running
Write-Host "Folder watcher is running. Press Enter to exit."
Read-Host