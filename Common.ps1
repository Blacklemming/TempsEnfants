$ErrorActionPreference = 'Stop'
function Assert-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not ([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Ouvrez ce programme avec les droits administrateur.'
    }
}
function Save-Json($Path, $Value) {
    $temp = $Path + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    try {
        $json = $Value | ConvertTo-Json -Depth 12
        $null = $json | ConvertFrom-Json -ErrorAction Stop
        $encoding = [Text.UTF8Encoding]::new($true)
        $bytes = $encoding.GetPreamble() + $encoding.GetBytes($json)
        # Flush data to the device before publishing the replacement file.
        $stream = [IO.FileStream]::new($temp, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None, 4096, [IO.FileOptions]::WriteThrough)
        try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true) }
        finally { $stream.Dispose() }
        if ([IO.File]::Exists($Path)) { [IO.File]::Replace($temp, $Path, ($Path + '.bak')) }
        else { [IO.File]::Move($temp, $Path) }
    } finally { if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) } }
}
function Read-Json($Path) {
    try {
        $json = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($json)) { throw 'Fichier vide.' }
        $value = $json | ConvertFrom-Json -ErrorAction Stop
        if ($null -eq $value) { throw 'Valeur JSON vide.' }
        return $value
    } catch { throw "Lecture impossible de $Path : $($_.Exception.Message)" }
}
function Test-Usage($State) {
    if ($State.Version -ne 1 -or $State.Records -isnot [array]) { throw 'Structure des compteurs invalide.' }
    if ($null -ne $State.Revision -and ($State.Revision -isnot [ValueType] -or $State.Revision -is [bool] -or $State.Revision -lt 0 -or [double]$State.Revision -ne [math]::Floor([double]$State.Revision))) { throw 'Revision invalide.' }
    $seen = @{}
    foreach ($r in $State.Records) {
        if (-not $r.Sid -or -not $r.Name -or $r.Date -notmatch '^\d{4}-\d{2}-\d{2}$' -or $r.Seconds -isnot [ValueType] -or $r.Seconds -is [bool] -or [double]::IsNaN([double]$r.Seconds) -or [double]::IsInfinity([double]$r.Seconds) -or $r.Seconds -lt 0 -or $r.Seconds -gt 86400) { throw 'Enregistrement de consommation invalide.' }
        $key = "$($r.Sid)/$($r.Date)"
        if ($seen.ContainsKey($key)) { throw 'Compteurs en double.' }
        $seen[$key] = $true
    }
}
function Read-Usage($Path) {
    $valid = @()
    foreach ($candidate in @($Path, ($Path + '.recovery'), ($Path + '.bak'), ($Path + '.recovery.bak'))) {
        try {
            $state = Read-Json $candidate
            Test-Usage $state
            if ($null -eq $state.Revision) { $state | Add-Member -NotePropertyName Revision -NotePropertyValue 0 }
            $valid += [pscustomobject]@{ State = $state; Revision = [long]$state.Revision; Priority = $valid.Count }
        } catch { }
    }
    if ($valid.Count -eq 0) { throw "Aucun compteur valide dans $Path ou ses sauvegardes. Relancez Installer.cmd pour reparer." }
    return ($valid | Sort-Object @{Expression='Revision';Descending=$true},Priority | Select-Object -First 1).State
}
function Save-Usage($Path, $State) {
    Test-Usage $State
    if ($null -eq $State.Revision) { $State | Add-Member -NotePropertyName Revision -NotePropertyValue 0 }
    $State.Revision = [long]$State.Revision + 1
    $failures = @()
    # Each copy is written independently. The older .bak copies are retained too.
    foreach ($destination in @(($Path + '.recovery'), $Path)) {
        try { Save-Json $destination $State }
        catch { $failures += $_.Exception.Message }
    }
    return ($failures -join ' | ')
}
function Repair-Usage($Path) {
    try { $state = Read-Usage $Path }
    catch {
        # Only the administrator-run installer may reset an unrecoverable history.
        $tag = [guid]::NewGuid().ToString('N')
        foreach ($candidate in @($Path, ($Path + '.recovery'), ($Path + '.bak'), ($Path + '.recovery.bak'))) {
            if (Test-Path -LiteralPath $candidate) { Copy-Item -LiteralPath $candidate -Destination ($candidate + '.damaged-' + $tag) }
        }
        Write-Host 'Compteurs absents ou irrecuperables : creation de compteurs neufs. Reglages conserves.'
        $state = [pscustomobject]@{ Version = 1; Revision = 0; Records = @() }
    }
    $problem = Save-Usage $Path $state
    if ($problem) { throw "Impossible de securiser les compteurs : $problem" }
}
function Read-Config($Path) {
    $c = Read-Json $Path
    if ($c.Enabled -isnot [bool] -or @($c.Minutes).Count -ne 7) { throw 'Configuration invalide.' }
    foreach ($n in $c.Minutes) {
        if ($n -isnot [ValueType] -or $n -lt 0 -or $n -gt 1440 -or [double]$n -ne [math]::Floor([double]$n)) { throw 'Quota invalide.' }
    }
    return $c
}
function Get-DayIndex([datetime]$Date) { (([int]$Date.DayOfWeek + 6) % 7) }
function Get-Remaining($Config, $Record, [datetime]$Date) {
    [math]::Max(0, ([double]$Config.Minutes[(Get-DayIndex $Date)] * 60) - [double]$Record.Seconds)
}
function Format-Time([double]$Seconds) {
    $m = [math]::Floor($Seconds / 60)
    '{0} h {1:00} min' -f [math]::Floor($m / 60), ($m % 60)
}
