param([ValidateSet('Installer','Panneau','Desinstaller')][string]$Mode = 'Panneau')
$ErrorActionPreference = 'Stop'
$logPath = $null
$transcribing = $false
try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $isAdmin = ([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        $arguments = '-NoProfile -ExecutionPolicy Bypass -STA -File "{0}" -Mode {1}' -f $PSCommandPath, $Mode
        $child = Start-Process -FilePath "$PSHOME\powershell.exe" -Verb RunAs -ArgumentList $arguments -Wait -PassThru
        exit $child.ExitCode
    }
    if (-not [Environment]::Is64BitProcess) { throw 'Lancez le fichier .cmd fourni : Windows PowerShell 64 bits est necessaire.' }
    $logPath = Join-Path ([IO.Path]::GetTempPath()) ('TempsEnfants-' + [guid]::NewGuid().ToString('N') + '.log')
    try { Start-Transcript -LiteralPath $logPath -ErrorAction Stop | Out-Null; $transcribing = $true } catch { $logPath = $null }
    Write-Host "Temps enfants - $Mode"
    Write-Host "Windows PowerShell $($PSVersionTable.PSVersion) / 64 bits"
    if ($Mode -eq 'Installer') {
        & (Join-Path $PSScriptRoot 'Install.ps1')
    } else {
        $installed = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) 'TempsEnfants'
        $file = if ($Mode -eq 'Panneau') { 'Panel.ps1' } else { 'Uninstall.ps1' }
        $entry = Join-Path $installed $file
        if (-not (Test-Path -LiteralPath $entry -PathType Leaf)) {
            throw "Installation absente ou incomplete. Decompressez tout le nouveau ZIP, puis lancez Installer.cmd. Fichier manquant : $entry"
        }
        & $entry
    }
} catch {
    Write-Host ''
    Write-Host 'ECHEC - Temps enfants' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.InvocationInfo.PositionMessage
    Write-Host $_.ScriptStackTrace
    if ($logPath) { Write-Host "Journal a transmettre : $logPath" -ForegroundColor Yellow }
    if ($transcribing) { Stop-Transcript | Out-Null; $transcribing = $false }
    $null = Read-Host 'Appuyez sur Entree pour fermer cette fenetre'
    exit 1
} finally {
    if ($transcribing) { Stop-Transcript | Out-Null }
}
