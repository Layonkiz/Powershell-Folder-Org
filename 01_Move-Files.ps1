$SourceDirectory = Read-Host "Please enter the source directory path"
$DestinationDirectory = Read-Host "Please enter the destination directory path"

# First, try to find .mkv files
$movies = Get-ChildItem -Path $SourceDirectory -Recurse -Filter *.mkv

if ($movies.Count -eq 0) {
    # If no .mkv files, look for .mp4 files
    $movies = Get-ChildItem -Path $SourceDirectory -Recurse -Filter *.mp4
    if ($movies.Count -eq 0) {
        Write-Host "No .mkv or .mp4 files found in the source directory."
        exit
    }
}

# Loop through each file found (whether .mkv or .mp4)
ForEach ($movie in $movies)
{
    # Copy each file to the destination directory
    Copy-Item -Path $movie.FullName -Destination $DestinationDirectory
}

Write-Host "File copying completed."