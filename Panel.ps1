. "$PSScriptRoot\Common.ps1"
Assert-Admin
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$configPath = "$PSScriptRoot\config.json"
$c = Read-Config $configPath
$form = New-Object Windows.Forms.Form
$form.Text = 'Temps enfants - Controle parental local'
$form.Size = New-Object Drawing.Size(790, 735)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object Drawing.Font('Segoe UI', 10)
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
function Label($Text, $X, $Y, $W, $H) {
    $l = New-Object Windows.Forms.Label
    $l.Text = $Text; $l.SetBounds($X, $Y, $W, $H)
    $form.Controls.Add($l)
    return $l
}
$null = Label 'Un planning commun, un compteur par enfant' 22 18 720 28
$null = Label 'Tous les comptes non administrateurs. Limites quotidiennes en heures et minutes.' 22 50 720 28
$enabled = New-Object Windows.Forms.CheckBox
$enabled.Text = 'Activer le controle parental'; $enabled.Checked = $c.Enabled
$enabled.SetBounds(22, 84, 400, 30); $form.Controls.Add($enabled)
$days = @('Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche')
$hours = @(); $minutes = @()
for ($i=0; $i -lt 7; $i++) {
    $y = 125 + $i * 33
    $null = Label $days[$i] 22 $y 105 28
    $h = New-Object Windows.Forms.NumericUpDown
    $h.SetBounds(135, $y, 65, 28); $h.Maximum = 24; $h.Value = [math]::Floor($c.Minutes[$i] / 60)
    $form.Controls.Add($h); $hours += $h
    $null = Label 'h' 207 $y 22 28
    $m = New-Object Windows.Forms.NumericUpDown
    $m.SetBounds(236, $y, 65, 28); $m.Maximum = 59; $m.Value = $c.Minutes[$i] % 60
    $form.Controls.Add($m); $minutes += $m
    $null = Label 'min' 309 $y 40 28
}
$null = Label "0 h = aucune utilisation autorisee.`r`n`r`nLe temps est cumule sur la journee, meme apres redemarrage.`r`n`r`nEcran verrouille : le temps compte.`r`nVeille ou session deconnectee : pause.`r`n`r`nA l'echeance, les applications sont fermees. Le travail non enregistre peut etre perdu." 385 125 360 224
$save = New-Object Windows.Forms.Button
$save.Text = 'Enregistrer les reglages'; $save.SetBounds(22, 365, 240, 36)
$form.Controls.Add($save)
$save.Add_Click({
    try {
        $values = @()
        for ($j=0; $j -lt 7; $j++) {
            $v = [int]$hours[$j].Value * 60 + [int]$minutes[$j].Value
            if ($v -gt 1440) { throw 'Le maximum est 24 h 00 par jour.' }
            $values += $v
        }
        Save-Json $configPath ([ordered]@{ Enabled = [bool]$enabled.Checked; Minutes = $values })
        [Windows.Forms.MessageBox]::Show('Reglages enregistres. Application sous quelques secondes.', 'Temps enfants')
    } catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Erreur') }
})
$status = Label '' 22 415 725 48
$null = Label "Consommation du jour (actualisation automatique)" 22 467 720 28
$grid = New-Object Windows.Forms.DataGridView
$grid.SetBounds(22, 500, 725, 145)
$grid.ReadOnly = $true; $grid.AllowUserToAddRows = $false; $grid.AllowUserToDeleteRows = $false
$grid.RowHeadersVisible = $false; $grid.AutoSizeColumnsMode = 'Fill'
foreach ($column in @('Compte', 'Consomme', 'Limite', 'Restant')) { $null = $grid.Columns.Add($column, $column) }
$form.Controls.Add($grid)
$null = Label 'Les comptes apparaissent apres leur premiere connexion. Fermer ce panneau laisse le controle actif.' 22 655 725 35
function Refresh-Usage {
    try {
        $current = Read-Config $configPath
        $health = Read-Json "$PSScriptRoot\health.json"
        $age = ([datetime]::UtcNow - [datetime]::Parse($health.Updated).ToUniversalTime()).TotalSeconds
        if ($age -gt 30 -or $health.Message -ne 'OK') {
            $status.Text = "ATTENTION : controle inactif ou en erreur. $($health.Message)"
            $status.ForeColor = [Drawing.Color]::Firebrick
        } else {
            $status.Text = if ($current.Enabled) { 'Controle actif - agent en fonctionnement.' } else { 'Controle desactive - activez puis enregistrez pour commencer.' }
            $status.ForeColor = [Drawing.Color]::DarkGreen
            if ($health.Warning) {
                $status.Text = 'Controle en cours, mais sauvegarde des compteurs en erreur. Verifiez health.json.'
                $status.ForeColor = [Drawing.Color]::Firebrick
            }
        }
        $state = Read-Usage "$PSScriptRoot\usage.json"
        $today = (Get-Date).ToString('yyyy-MM-dd')
        $grid.Rows.Clear()
        foreach ($account in @($state.Records | Group-Object Sid)) {
            $r = $account.Group | Where-Object Date -eq $today | Select-Object -First 1
            if ($null -eq $r) { $r = [pscustomobject]@{ Name = $account.Group[-1].Name; Seconds = 0 } }
            $limit = [double]$current.Minutes[(Get-DayIndex (Get-Date))] * 60
            $null = $grid.Rows.Add($r.Name, (Format-Time $r.Seconds), (Format-Time $limit), (Format-Time (Get-Remaining $current $r (Get-Date))))
        }
    } catch { $status.Text = "Agent indisponible : $($_.Exception.Message)"; $status.ForeColor = [Drawing.Color]::Firebrick }
}
$timer = New-Object Windows.Forms.Timer
$timer.Interval = 5000; $timer.Add_Tick({ Refresh-Usage })
$form.Add_Shown({ Refresh-Usage; $timer.Start() })
$form.Add_FormClosed({ $timer.Stop(); $timer.Dispose() })
$null = $form.ShowDialog()
$form.Dispose()
