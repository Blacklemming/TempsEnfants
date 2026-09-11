. "$PSScriptRoot\Common.ps1"
if ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value -ne 'S-1-5-18') { throw 'Agent reserve au compte SYSTEM.' }
$statePath = "$PSScriptRoot\usage.json"
$warned = @{}
function Write-Health($Message, $Warning = '') {
    Save-Json "$PSScriptRoot\health.json" ([ordered]@{ Updated = [datetime]::UtcNow.ToString('o'); Message = $Message; Warning = $Warning })
}
try {
    Add-Type -Path "$PSScriptRoot\Native.cs"
    $state = Read-Usage $statePath
    while ($true) {
        $c = Read-Config "$PSScriptRoot\config.json"
        $now = Get-Date
        $day = $now.ToString('yyyy-MM-dd')
        $sessions = @([FamilyNative]::Sessions() | Where-Object { -not $_.Admin })
        if ($c.Enabled) {
            foreach ($group in @($sessions | Group-Object Sid)) {
                $r = $state.Records | Where-Object { $_.Sid -eq $group.Name -and $_.Date -eq $day } | Select-Object -First 1
                if ($null -eq $r) {
                    $r = [pscustomobject]@{ Sid = $group.Name; Name = $group.Group[0].Name; Date = $day; Seconds = 0 }
                    $state.Records = @($state.Records) + $r
                }
                $remaining = Get-Remaining $c $r $now
                if ($remaining -le 0) {
                    foreach ($s in $group.Group) {
                        # Recheck identity immediately before any destructive session action.
                        $check = [FamilyNative]::Sessions() | Where-Object { $_.Id -eq $s.Id -and $_.Sid -eq $s.Sid -and -not $_.Admin }
                        if ($check) { [FamilyNative]::Logoff($s.Id) }
                    }
                    continue
                }
                $active = @($group.Group | Where-Object State -eq 0)
                if ($active.Count -gt 0) {
                    foreach ($s in $active) {
                        $key = "$day/$($s.Sid)/$($s.Id)"
                        if ($remaining -le 300 -and -not $warned.ContainsKey($key)) {
                            try {
                                [FamilyNative]::Warn($s.Id, "Il reste environ $([math]::Ceiling($remaining / 60)) minute(s). Enregistre ton travail : ta session sera fermee automatiquement.")
                                $warned[$key] = $true
                            } catch { } # Warning failure must not disable enforcement.
                        }
                        if ($remaining -gt 300) { $warned.Remove($key) }
                    }
                    # Pre-charge one five-second slice, once per user (not per session).
                    # No wall-clock delta: sleep/offline time is never charged on resume.
                    $r.Seconds = [double]$r.Seconds + [math]::Min(5, $remaining)
                }
            }
        }
        # Keep enforcing with the in-memory state on transient disk failures.
        $warning = Save-Usage $statePath $state
        try { Write-Health 'OK' $warning } catch { }
        Start-Sleep -Seconds 5
    }
} catch {
    try { Write-Health $_.Exception.Message } catch { }
    exit 1
}
