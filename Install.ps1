. "$PSScriptRoot\Common.ps1"
Assert-Admin
if (-not [Environment]::Is64BitProcess) { throw 'Utilisez Windows PowerShell 64 bits.' }
$target = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) 'TempsEnfants'
$taskName = 'TempsEnfants-Agent'
Write-Host "Installation / reparation dans $target"
if (Test-Path -LiteralPath $target) {
    $existing = Get-Item -LiteralPath $target -Force
    if (-not $existing.PSIsContainer -or ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Le dossier cible est un lien ou un fichier. Installation interrompue.' }
    foreach ($item in @(Get-ChildItem -LiteralPath $target -Force)) {
        if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Contenu inattendu dans le dossier cible : $($item.Name). Installation interrompue." }
    }
} else { New-Item -ItemType Directory -Path $target | Out-Null }
$previousTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($previousTask) {
    Disable-ScheduledTask -TaskName $taskName | Out-Null
    Stop-ScheduledTask -TaskName $taskName
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        if ((Get-ScheduledTask -TaskName $taskName).State -ne 'Running') { break }
        Start-Sleep -Milliseconds 250
    }
    if ((Get-ScheduledTask -TaskName $taskName).State -eq 'Running') { throw 'Impossible d arreter l ancien agent. Redemarrez puis relancez Installer.cmd.' }
}
# Protect before copying executable code or settings. SID-based rules work in any Windows language.
$acl = New-Object Security.AccessControl.DirectorySecurity
$acl.SetAccessRuleProtection($true, $false)
foreach ($sid in @('S-1-5-18', 'S-1-5-32-544')) {
    $rule = New-Object Security.AccessControl.FileSystemAccessRule([Security.Principal.SecurityIdentifier]::new($sid), 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
    $acl.AddAccessRule($rule)
}
$acl.SetOwner([Security.Principal.SecurityIdentifier]::new('S-1-5-32-544'))
Set-Acl -LiteralPath $target -AclObject $acl
$fileAcl = New-Object Security.AccessControl.FileSecurity
$fileAcl.SetAccessRuleProtection($true, $false)
foreach ($sid in @('S-1-5-18','S-1-5-32-544')) {
    $fileAcl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new($sid), 'FullControl', 'Allow'))
}
$fileAcl.SetOwner([Security.Principal.SecurityIdentifier]::new('S-1-5-32-544'))
foreach ($item in @(Get-ChildItem -LiteralPath $target -Force -File)) { Set-Acl -LiteralPath $item.FullName -AclObject $fileAcl }
foreach ($file in @('Common.ps1','Native.cs','Agent.ps1','Panel.ps1','Uninstall.ps1','Launch.ps1')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $target -Force
}
if (-not (Test-Path -LiteralPath "$target\config.json")) {
    Save-Json "$target\config.json" ([ordered]@{ Enabled = $false; Minutes = @(0,60,120,60,60,180,180) })
} else { $null = Read-Config "$target\config.json" }
Repair-Usage "$target\usage.json"
$powershell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$action = New-ScheduledTaskAction -Execute $powershell -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$target\Agent.ps1`"" -WorkingDirectory $target
$startup = New-ScheduledTaskTrigger -AtStartup
$watchdog = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit ([timespan]::Zero) -MultipleInstances IgnoreNew -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
$principal = New-ScheduledTaskPrincipal -UserId 'S-1-5-18' -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger @($startup,$watchdog) -Settings $settings -Principal $principal -Description 'Quotas locaux par jour pour les utilisateurs non administrateurs.' -Force | Out-Null
# Explicitly restrict task administration and execution to SYSTEM and Administrators.
$scheduler = New-Object -ComObject 'Schedule.Service'
$scheduler.Connect()
$scheduler.GetFolder('\').GetTask($taskName).SetSecurityDescriptor('D:P(A;;GA;;;SY)(A;;GA;;;BA)', 0)
$shell = New-Object -ComObject WScript.Shell
$linkPath = Join-Path ([Environment]::GetFolderPath('CommonDesktopDirectory')) 'Temps enfants.lnk'
$link = $shell.CreateShortcut($linkPath)
$link.TargetPath = $powershell
$link.Arguments = "-NoProfile -ExecutionPolicy Bypass -STA -File `"$target\Launch.ps1`" -Mode Panneau"
$link.WorkingDirectory = $target
$link.Description = 'Reglages et consommation - administrateur requis'
$link.Save()
$bytes = [IO.File]::ReadAllBytes($linkPath)
$bytes[21] = $bytes[21] -bor 0x20 # Shell link RunAsUser / elevation flag.
[IO.File]::WriteAllBytes($linkPath, $bytes)
Start-ScheduledTask -TaskName $taskName
Write-Host 'Installation terminee. Ouvrez Temps enfants sur le Bureau, puis activez et enregistrez vos limites.'
# This is the interactive settings window requested by the installing parent.
& "$target\Panel.ps1"
