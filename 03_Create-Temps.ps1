$fold =  "E:\"
$directories = Get-ChildItem -Path $fold -Directory
foreach ($directory in $directories) {
    $tempfolder = $directory.FullName + "\000_Temp"
        if (-not (Test-Path -Path $tempfolder)) {
            New-Item -Path $directory -ItemType Directory -Name "000_Temp" -Force    
}
}
