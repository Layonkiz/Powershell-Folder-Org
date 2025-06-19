<#
.SYNOPSIS
Automatically categorizes and moves newly created folders based on file extensions.

.DESCRIPTION
Monitors a source directory for new folders. When a folder is created:
1. Waits 70 seconds for files to be added
2. Analyzes file extensions in the folder
3. Moves the folder to the appropriate category directory based on the most common mapped file extension

.NOTES
- Ensures destination directories exist before moving
- Includes retry logic for file lock contention
- Handles temporary system files (thumbs.db, desktop.ini)
- Processes only top-level directories in source folder
#>

# Configuration
$SourceDirectory = "E:\000_Temp"
$videos = "E:\03_Videos\000_Temp"
$docs = "E:\01_Documents\000_Temp"
$pics = "E:\02_Images\000_Temp"
$audios = "E:\04_Audios\000_Temp"

# Create destination directories if missing
$destinations = @($videos, $docs, $pics, $audios)
foreach ($dir in $destinations) {
    if (-not (Test-Path -Path $dir -PathType Container)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
}

# Extension to category mapping (case-insensitive)
$extensionMap = @{
    ".mp4"  = $videos
    ".avi"  = $videos
    ".mkv"  = $videos
    ".mov"  = $videos
    ".pdf"  = $docs
    ".docx" = $docs
    ".doc"  = $docs
    ".xlsx" = $docs
    ".pptx" = $docs
    ".txt"  = $docs
    ".jpg"  = $pics
    ".jpeg" = $pics
    ".png"  = $pics
    ".gif"  = $pics
    ".bmp"  = $pics
    ".mp3"  = $audios
    ".wav"  = $audios
    ".flac" = $audios
    ".m4a"  = $audios
}

# System files to ignore
$ignoreFiles = @("thumbs.db", "desktop.ini")

function Move-FolderWithRetry {
    param (
        [string]$Source,
        [string]$Destination
    )
    
    $maxRetries = 5
    $retryDelay = 5  # seconds
    $attempt = 1

    while ($attempt -le $maxRetries) {
        try {
            Move-Item -Path $Source -Destination $Destination -Force -ErrorAction Stop
            Write-Host "[SUCCESS] Moved folder: $(Split-Path $Source -Leaf) to $Destination"
            return
        }
        catch {
            Write-Warning "[ATTEMPT $attempt/$maxRetries] Failed to move folder: $($_.Exception.Message)"
            Start-Sleep -Seconds $retryDelay
            $attempt++
        }
    }
    
    Write-Error "[FATAL] Failed to move folder after $maxRetries attempts: $Source"
}

# Create filesystem watcher
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $SourceDirectory
$watcher.NotifyFilter = [System.IO.NotifyFilters]::DirectoryName
$watcher.IncludeSubdirectories = $false  # Monitor only top-level
$watcher.EnableRaisingEvents = $true

# Register folder created event
$action = {
    $folderPath = $Event.SourceEventArgs.FullPath
    $folderName = Split-Path $folderPath -Leaf

    try {
        # Verify folder still exists
        if (-not (Test-Path -Path $folderPath -PathType Container)) {
            Write-Host "[INFO] Folder no longer exists: $folderName"
            return
        }

        # Wait for file operations to complete
        Write-Host "[PROCESSING] Analyzing folder: $folderName (waiting 70 seconds)"
        Start-Sleep -Seconds 864000

        # Re-verify existence after delay
        if (-not (Test-Path -Path $folderPath -PathType Container)) {
            Write-Host "[INFO] Folder disappeared during processing: $folderName"
            return
        }

        # Get valid files (ignore system files)
        $files = Get-ChildItem -Path $folderPath -File | 
                 Where-Object { $_.Name -notin $ignoreFiles }

        if (-not $files) {
            Write-Host "[INFO] No valid files found in folder: $folderName"
            return
        }

        # Analyze file extensions
        $extensionGroups = $files | 
            Group-Object { $_.Extension.ToLower() } |
            Where-Object { $extensionMap.ContainsKey($_.Name) }

        if (-not $extensionGroups) {
            Write-Host "[INFO] No mapped extensions found in: $folderName"
            return
        }

        # Determine category by most common extension
        $targetCategory = $extensionGroups | 
            Sort-Object Count -Descending | 
            Select-Object -First 1 | 
            ForEach-Object { $extensionMap[$_.Name] }

        # Move folder to category directory
        Move-FolderWithRetry -Source $folderPath -Destination $targetCategory
    }
    catch {
        Write-Error "[ERROR] Processing folder $folderName : $($_.Exception.Message)"
    }
}

Register-ObjectEvent -InputObject $watcher -EventName Created -Action $action > $null

Write-Host "`nFolder Organizer is running..."
Write-Host "Source: $SourceDirectory"
Write-Host "Categories:`n- Videos: $videos`n- Documents: $docs`n- Images: $pics`n- Audio: $audios"
Write-Host "`nPress CTRL+C to exit..."

try {
    # Keep console open
    while ($true) { Start-Sleep -Seconds 60 }
}
finally {
    # Cleanup on exit
    Get-EventSubscriber | Unregister-Event
    $watcher.Dispose()
    Write-Host "`nWatcher stopped. Resources cleaned up."
}