<#
.SYNOPSIS
Automatically categorizes and moves newly created folders and files based on file extensions.

.DESCRIPTION
Monitors a source directory for new items (both folders and files). For each item:
- Folders: Waits 70 seconds, analyzes contents, moves to category directory
- Files: Waits 10 seconds, moves directly to category directory

.NOTES
- Handles both folders and individual files
- Includes separate wait times for folders (70s) vs files (10s)
- Ensures destination directories exist
- Includes retry logic for file lock contention
- Handles temporary system files
- Processes only top-level items in source folder
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
$ignoreFiles = @("thumbs.db", "desktop.ini", "~*.*", "*.tmp")

function Move-ItemWithRetry {
    param (
        [string]$Source,
        [string]$Destination,
        [bool]$IsFile = $false
    )
    
    $maxRetries = 5
    $attempt = 1
    $itemName = Split-Path $Source -Leaf
    $itemType = if ($IsFile) { "file" } else { "folder" }

    while ($attempt -le $maxRetries) {
        try {
            # Verify item still exists
            if (-not (Test-Path -Path $Source)) {
                Write-Host "[INFO] $($itemType.ToUpper()) no longer exists: $itemName"
                return
            }

            # Create destination directory if moving a file
            if ($IsFile -and -not (Test-Path -Path $Destination -PathType Container)) {
                New-Item -Path $Destination -ItemType Directory -Force | Out-Null
            }

            Move-Item -Path $Source -Destination $Destination -Force -ErrorAction Stop
            
            Write-Host "[SUCCESS] Moved $itemType : $itemName to $Destination"
            return
        }
        catch {
            Write-Warning "[ATTEMPT $attempt/$maxRetries] Failed to move $itemType '$itemName': $($_.Exception.Message)"
            
            # Exponential backoff: 2, 4, 8, 16, 32 seconds
            $delaySeconds = [math]::Pow(2, $attempt)
            Start-Sleep -Seconds $delaySeconds
            
            $attempt++
        }
    }
    
    Write-Error "[FATAL] Failed to move $itemType after $maxRetries attempts: $itemName"
}

# Create filesystem watcher
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $SourceDirectory
$watcher.NotifyFilter = [System.IO.NotifyFilters]::FileName, [System.IO.NotifyFilters]::DirectoryName
$watcher.IncludeSubdirectories = $false  # Monitor only top-level
$watcher.EnableRaisingEvents = $true

# Register item created event
$action = {
    $itemPath = $Event.SourceEventArgs.FullPath
    $itemName = Split-Path $itemPath -Leaf

    try {
        # Allow time for file/folder creation to complete
        Start-Sleep -Seconds 2
        
        # Determine if item is file or folder
        $isFile = Test-Path -Path $itemPath -PathType Leaf
        $isFolder = Test-Path -Path $itemPath -PathType Container
        
        if (-not $isFile -and -not $isFolder) {
            Write-Host "[WARNING] Item no longer exists: $itemName"
            return
        }

        # Process FOLDERS
        if ($isFolder) {
            Write-Host "[PROCESSING] Analyzing folder: $itemName (waiting 70 seconds)"
            Start-Sleep -Seconds 70

            # Re-verify existence after delay
            if (-not (Test-Path -Path $itemPath -PathType Container)) {
                Write-Host "[INFO] Folder disappeared during processing: $itemName"
                return
            }

            # Get valid files (ignore system files)
            $files = Get-ChildItem -Path $itemPath -File | 
                     Where-Object { $_.Name -notin $ignoreFiles }

            if (-not $files) {
                Write-Host "[INFO] No valid files found in folder: $itemName"
                return
            }

            # Analyze file extensions
            $extensionGroups = $files | 
                Group-Object { $_.Extension.ToLower() } |
                Where-Object { $extensionMap.ContainsKey($_.Name) }

            if (-not $extensionGroups) {
                Write-Host "[INFO] No mapped extensions found in folder: $itemName"
                return
            }

            # Determine category by most common extension
            $targetCategory = $extensionGroups | 
                Sort-Object Count -Descending | 
                Select-Object -First 1 | 
                ForEach-Object { $extensionMap[$_.Name] }

            # Move folder to category directory
            Move-ItemWithRetry -Source $itemPath -Destination $targetCategory -IsFile $false
        }
        # Process FILES
        elseif ($isFile) {
            Write-Host "[PROCESSING] Found new file: $itemName (waiting 10 seconds)"
            Start-Sleep -Seconds 10

            # Re-verify existence after delay
            if (-not (Test-Path -Path $itemPath -PathType Leaf)) {
                Write-Host "[INFO] File disappeared during processing: $itemName"
                return
            }

            # Check if file should be ignored
            if ($itemName -in $ignoreFiles) {
                Write-Host "[INFO] Ignoring system file: $itemName"
                return
            }

            # Get file extension
            $ext = [System.IO.Path]::GetExtension($itemPath).ToLower()
            
            if (-not $ext) {
                Write-Host "[INFO] File has no extension: $itemName"
                return
            }

            # Find matching category
            if ($extensionMap.ContainsKey($ext)) {
                $targetCategory = $extensionMap[$ext]
                Move-ItemWithRetry -Source $itemPath -Destination $targetCategory -IsFile $true
            }
            else {
                Write-Host "[INFO] No mapped destination for $ext files: $itemName"
            }
        }
    }
    catch {
        Write-Error "[ERROR] Processing item $itemName : $($_.Exception.Message)"
    }
}

Register-ObjectEvent -InputObject $watcher -EventName Created -Action $action > $null

Write-Host "`nFile and Folder Organizer is running..."
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