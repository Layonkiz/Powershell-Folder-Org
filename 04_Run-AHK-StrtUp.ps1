# Task details
$taskName = "Run PowerShell Profile at Startup"
$taskAction = New-ScheduledTaskAction `
    -Execute 'pwsh.exe' `
    -Argument "-NoProfile -WindowStyle Hidden -Command `". `'$PROFILE`'`""

$taskTrigger = New-ScheduledTaskTrigger -AtLogOn
$taskPrincipal = New-ScheduledTaskPrincipal -RunLevel Highest -UserId "$env:USERDOMAIN\$env:USERNAME"

# Register the task
Register-ScheduledTask `
    -TaskName $taskName `
    -Action $taskAction `
    -Trigger $taskTrigger `
    -Principal $taskPrincipal `
    -Force