. "$PSScriptRoot\Common.ps1"
Assert-Admin
Add-Type -AssemblyName System.Windows.Forms
$answer = [Windows.Forms.MessageBox]::Show('Arreter et desinstaller le controle parental ? Les compteurs et fichiers seront conserves.', 'Temps enfants', 'YesNo', 'Question')
if ($answer -ne 'Yes') { exit }
$task = Get-ScheduledTask -TaskName 'TempsEnfants-Agent' -ErrorAction SilentlyContinue
if ($task) {
    Disable-ScheduledTask -TaskName 'TempsEnfants-Agent' | Out-Null
    Stop-ScheduledTask -TaskName 'TempsEnfants-Agent'
    Unregister-ScheduledTask -TaskName 'TempsEnfants-Agent' -Confirm:$false
}
$link = Join-Path ([Environment]::GetFolderPath('CommonDesktopDirectory')) 'Temps enfants.lnk'
if (Test-Path -LiteralPath $link) { Remove-Item -LiteralPath $link }
[Windows.Forms.MessageBox]::Show('Controle arrete et tache supprimee. Les fichiers et compteurs sont conserves dans Program Files\TempsEnfants. Vous pouvez supprimer ce dossier manuellement.', 'Temps enfants') | Out-Null
