<#
.SYNOPSIS
    Генерирует SVG-скриншоты для README из настоящего вывода игры.

.DESCRIPTION
    Скрипт запускает etheria-moonshard.bat в режиме ETHERIA_TEST=1 с заранее
    записанным вводом, разбирает ANSI-вывод небольшим эмулятором терминала
    и сохраняет экраны как SVG. ASCII-сцены боя берутся из PowerShell-движка
    самой игры (блок #PSBEGIN), поэтому картинки совпадают с тем,
    что видит игрок.

    Запуск:  powershell -ExecutionPolicy Bypass -File tools\Render-Media.ps1
#>
[CmdletBinding()]
param([string]$OutDir)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Game = Join-Path $root 'etheria-moonshard.bat'
if (-not $OutDir) { $OutDir = Join-Path $root 'docs\media' }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding $false
$ESCc = [char]27

# ---------------------------------------------------------------
# Палитра терминала
# ---------------------------------------------------------------
$Palette = @{
    '0' = '#cdd6f4'; '90' = '#7f849c'; '91' = '#f38ba8'; '92' = '#a6e3a1'; '93' = '#f9e2af'
    '94' = '#89b4fa'; '95' = '#cba6f7'; '96' = '#89dceb'; '97' = '#ffffff'
}

# ---------------------------------------------------------------
# Мини-эмулятор терминала: \r, \n, ESC[nA, SGR-цвета
# ---------------------------------------------------------------
function ConvertFrom-Ansi([string]$text) {
    $rows = New-Object System.Collections.ArrayList
    [void]$rows.Add((New-Object System.Collections.ArrayList))
    $r = 0; $c = 0; $color = '0'
    $i = 0
    while ($i -lt $text.Length) {
        $ch = $text[$i]
        if ($ch -eq $ESCc -and ($i + 1) -lt $text.Length -and $text[$i + 1] -eq '[') {
            $m = [regex]::Match($text.Substring($i), '^\x1b\[([0-9;?]*)([A-Za-z])')
            if ($m.Success) {
                $arg = $m.Groups[1].Value; $cmd = $m.Groups[2].Value
                if ($cmd -eq 'm') { $color = if ($arg -eq '' -or $arg -eq '0') { '0' } else { ($arg -split ';')[-1] } }
                elseif ($cmd -eq 'A') { $n = if ($arg) { [int]$arg } else { 1 }; $r = [Math]::Max(0, $r - $n) }
                $i += $m.Length; continue
            }
        }
        if ($ch -eq "`r") { $c = 0 }
        elseif ($ch -eq "`n") {
            $r++; $c = 0
            while ($rows.Count -le $r) { [void]$rows.Add((New-Object System.Collections.ArrayList)) }
        }
        elseif ([int]$ch -ge 32) {
            $line = $rows[$r]
            while ($line.Count -lt $c) { [void]$line.Add(@(' ', '0')) }
            if ($line.Count -eq $c) { [void]$line.Add(@([string]$ch, $color)) } else { $line[$c] = @([string]$ch, $color) }
            $c++
        }
        $i++
    }
    # переносим длинные строки так же, как печатающая машинка игры (ширина 74)
    $out = New-Object System.Collections.ArrayList
    foreach ($line in $rows) {
        $cells = @($line)
        while ($cells.Count -gt 76) {
            $cut = 74
            while ($cut -gt 10 -and $cells[$cut][0] -ne ' ') { $cut-- }
            [void]$out.Add(@($cells[0..($cut - 1)]))
            $rest = @($cells[($cut + 1)..($cells.Count - 1)])
            $cells = @(@(' ', '0'), @(' ', '0')) + $rest
        }
        [void]$out.Add($cells)
    }
    while ($out.Count -gt 0 -and (($out[$out.Count - 1] | ForEach-Object { $_[0] }) -join '').Trim() -eq '') { $out.RemoveAt($out.Count - 1) }
    while ($out.Count -gt 0 -and (($out[0] | ForEach-Object { $_[0] }) -join '').Trim() -eq '') { $out.RemoveAt(0) }
    return , $out
}

function New-PlainRows([string[]]$lines, [string]$color = '0') {
    $rows = New-Object System.Collections.ArrayList
    foreach ($l in $lines) { [void]$rows.Add(@($l.ToCharArray() | ForEach-Object { , @([string]$_, $color) })) }
    return , $rows
}

function Esc-Xml([string]$s) { $s.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;') }

$CW = 8.4; $LH = 19; $PADX = 22; $TOP = 46

function Get-RowsSvg($rows, [double]$y0) {
    $sb = New-Object System.Text.StringBuilder
    $y = $y0
    foreach ($row in $rows) {
        [void]$sb.Append("<text x=`"$PADX`" y=`"$y`">")
        $cur = $null; $buf = ''
        foreach ($cell in $row) {
            if ($cell[1] -ne $cur) {
                if ($buf) { [void]$sb.Append("<tspan fill=`"$($Palette[$cur])`">$(Esc-Xml $buf)</tspan>") }
                $cur = $cell[1]; $buf = ''
            }
            $buf += $cell[0]
        }
        if ($buf) { [void]$sb.Append("<tspan fill=`"$($Palette[$cur])`">$(Esc-Xml $buf)</tspan>") }
        [void]$sb.Append("</text>`n")
        $y += $LH
    }
    return $sb.ToString()
}

function Get-WindowSvg([int]$cols, [int]$nrows, [string]$title, [string]$body, [string]$extraCss = '') {
    $w = [int]($cols * $CW + 2 * $PADX)
    $h = [int]($TOP + $nrows * $LH + 18)
    $t = Esc-Xml $title
    return @"
<svg xmlns="http://www.w3.org/2000/svg" width="$w" height="$h" viewBox="0 0 $w $h" role="img" aria-label="$t">
<style>
text{font-family:'Cascadia Mono','Cascadia Code',Consolas,'DejaVu Sans Mono',Menlo,monospace;font-size:14px;white-space:pre}
$extraCss
</style>
<defs><linearGradient id="bg" x2="0" y2="1"><stop stop-color="#1e1e2e"/><stop offset="1" stop-color="#151522"/></linearGradient></defs>
<rect width="$w" height="$h" rx="12" fill="url(#bg)"/>
<rect x=".5" y=".5" width="$($w-1)" height="$($h-1)" rx="12" fill="none" stroke="#313244"/>
<path d="M12 .5h$($w-24)a11.5 11.5 0 0 1 11.5 11.5v18H.5V12A11.5 11.5 0 0 1 12 .5z" fill="#181825"/>
<circle cx="22" cy="15.5" r="5.5" fill="#f38ba8"/><circle cx="40" cy="15.5" r="5.5" fill="#f9e2af"/><circle cx="58" cy="15.5" r="5.5" fill="#a6e3a1"/>
<text x="$([int]($w/2))" y="20" text-anchor="middle" style="font-size:12px" fill="#7f849c">$t</text>
<g xml:space="preserve">
$body</g>
</svg>
"@
}

function Save-Screen($rows, [string]$file, [string]$title) {
    $cols = 40
    foreach ($r in $rows) { if ($r.Count -gt $cols) { $cols = $r.Count } }
    $svg = Get-WindowSvg $cols $rows.Count $title (Get-RowsSvg $rows $TOP)
    [IO.File]::WriteAllText((Join-Path $OutDir $file), $svg, $utf8)
    Write-Host "  $file" -ForegroundColor Green
}

# ---------------------------------------------------------------
# Запуск игры с записанным вводом
# ---------------------------------------------------------------
function Invoke-Game([string]$inputKeys, [hashtable]$files = @{}) {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('etheria-media-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir | Out-Null
    try {
        Copy-Item $Game (Join-Path $dir 'game.bat')
        foreach ($k in $files.Keys) { [IO.File]::WriteAllText((Join-Path $dir $k), $files[$k], $utf8) }
        [IO.File]::WriteAllText((Join-Path $dir 'input.txt'), $inputKeys)
        $env:ETHERIA_TEST = '1'
        $p = Start-Process cmd.exe -ArgumentList '/c ".\game.bat" < input.txt > output.txt 2>&1' -WorkingDirectory $dir -NoNewWindow -PassThru
        [void]$p.WaitForExit(60000)
        Remove-Item Env:ETHERIA_TEST
        $log = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes((Join-Path $dir 'output.txt')))
        return , ($log -split "`f")
    } finally { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }
}

function Find-Screen($screens, [string]$marker, [int]$nth = 0) {
    $hits = @($screens | Where-Object { $_.Contains($marker) })
    if ($hits.Count -le $nth) { throw "Экран с маркером '$marker' не найден" }
    return $hits[$nth]
}

$NL = "`r`n"
$progress = "speed:0${NL}e1:1${NL}e2:0${NL}e3:1${NL}e4:1${NL}e5:1${NL}e6:0${NL}e7:1${NL}e8:0${NL}"
$save = "player_name:Арина${NL}player_class:Маг${NL}hp:13${NL}hours:4${NL}q_tavern:1${NL}q_east:0${NL}q_lib:1${NL}has_key:1${NL}has_amulet:0${NL}knows_weak:1${NL}"

Write-Host "`nЭкраны игры" -ForegroundColor Cyan

# 1. Главное меню, Как играть и Летопись
$s = Invoke-Game 'x4x3x6' @{ 'etheria-progress.cfg' = $progress; 'savegame.cfg' = $save }
Save-Screen (ConvertFrom-Ansi (Find-Screen $s '[6]')) 'screen-menu.svg' 'Этерия: Осколок Луны — главное меню'
Save-Screen (ConvertFrom-Ansi (Find-Screen $s 'КАК ИГРАТЬ')) 'screen-help.svg' 'Как играть'
Save-Screen (ConvertFrom-Ansi (Find-Screen $s 'ЛЕТОПИСЬ')) 'screen-chronicle.svg' 'Летопись концовок'

# 2. Площадь после загрузки сохранения и экран статуса
$s = Invoke-Game 'x261x4636' @{ 'etheria-progress.cfg' = $progress; 'savegame.cfg' = $save }
Save-Screen (ConvertFrom-Ansi (Find-Screen $s '[5]' 1)) 'screen-hub.svg' 'Площадь Этерии'
Save-Screen (ConvertFrom-Ansi (Find-Screen $s 'СТАТУС И ЗАМЕТКИ')) 'screen-status.svg' 'Статус и заметки'

# 3. Таверна: диалог с паролем
$s = Invoke-Game "x1Кира${NL}3x11x636" @{ 'etheria-progress.cfg' = $progress }
$tav = Find-Screen $s 'Незнакомец поднимает'
$tav = $tav.Substring(0, $tav.LastIndexOf('[4]')) + ($tav.Substring($tav.LastIndexOf('[4]')) -replace '(?s)(\[4\][^\n]*\n).*', '$1')
Save-Screen (ConvertFrom-Ansi $tav) 'screen-tavern.svg' 'Таверна «Ржавый якорь»'

# 4. Лучшая концовка
$s = Invoke-Game "x1Кира${NL}3x11x23x41x1" @{ 'etheria-progress.cfg' = $progress.Replace('e1:1', 'e1:0') }
Save-Screen (ConvertFrom-Ansi (Find-Screen $s 'Исход')) 'screen-ending.svg' 'Концовка: Рассвет Этерии'

# ---------------------------------------------------------------
# Движок сцен игры (блок #PSBEGIN)
# ---------------------------------------------------------------
$src = [IO.File]::ReadAllText($Game, $utf8)
$env:ps_mode = 'none'
$psBlock = $src.Substring($src.LastIndexOf('#PSBEGIN'))
. ([ScriptBlock]::Create($psBlock))
Remove-Item Env:ps_mode
[Console]::OutputEncoding = $utf8

function Get-FrameLines($f, $en) {
    $buf = New-Object 'object[]' $H
    for ($r = 0; $r -lt $H; $r++) { $buf[$r] = (' ' * $W).ToCharArray() }
    Stamp $buf ($H - 1) 0 ('_' * $W)
    $bottom = $H - 2
    PutSprite $buf $P[$f.pp] ($PBASE + $f.pdx) $bottom
    PutSprite $buf $E[$en][$f.ep] ($EBASE + $f.edx) $bottom
    if ($f.fx) { Stamp $buf $f.fxr $f.fxc $f.fx }
    $lines = @(); for ($r = 0; $r -lt $H; $r++) { $lines += (-join $buf[$r]) }
    return $lines
}

# 5. Статичный кадр боя со Стражем Тени: реальный раунд + кадр удара из движка
Write-Host "`nБой" -ForegroundColor Cyan
$s = Invoke-Game "x1Кира${NL}1x211x" @{ 'etheria-progress.cfg' = $progress }
$round = Find-Screen $s 'Раунд 1'
$dm = [regex]::Match($round, '(\d+) урона')
$pd = if ($dm.Success) { [int]$dm.Groups[1].Value } else { 4 }
$crit = $round.Contains('Критический')
$frames = New-Object System.Collections.ArrayList
Seq-Attack $pd $crit
$hit = Get-FrameLines $frames[3] 'guard'
$idle = Get-FrameLines (Fr 'stand' 0 'stand' 0 '' 0 0) 'guard'
$rows = ConvertFrom-Ansi $round
$scene = New-PlainRows $idle '97'
$hitRows = New-PlainRows $hit '97'
$out = New-Object System.Collections.ArrayList
$placedIdle = $false; $placedHit = $false
foreach ($r in $rows) {
    $line = ($r | ForEach-Object { $_[0] }) -join ''
    [void]$out.Add($r)
    if (-not $placedIdle -and $line -match 'HP: \[' -and $line -match '/14') { foreach ($x in $scene) { [void]$out.Add($x) }; $placedIdle = $true }
    if (-not $placedHit -and $line -match ':\s*1\s*$' -and $placedIdle) { foreach ($x in $hitRows) { [void]$out.Add($x) }; $placedHit = $true }
}
Save-Screen $out 'screen-battle.svg' 'Восточный квартал — бой со Стражем Тени'

# 6. Анимированный бой с Тенью
$frames = New-Object System.Collections.ArrayList
$timeline = New-Object System.Collections.ArrayList   # @(frameIndexStart, bossHp, heroHp, log, logColor)
function Mark($bhp, $hhp, $log, $col) { [void]$timeline.Add(@($frames.Count, $bhp, $hhp, $log, $col)) }

Mark 30 14 'Раунд 1. Ваш ход: [1] Атака' '0'
[void]$frames.Add((Fr 'stand' 0 'stand' 0 '' 0 0)); [void]$frames.Add((Fr 'stand' 0 'stand' 0 '' 0 0))
Seq-Attack 8 $true
Mark 22 14 'Критический удар. Вы наносите 8 урона.' '93'
Seq-EnemyAttack 3 $false
Mark 22 11 'Тень бьёт вас на 3 урона.' '91'
[void]$frames.Add((Fr 'stand' 0 'stand' 0 '' 0 0)); [void]$frames.Add((Fr 'stand' 0 'stand' 0 '' 0 0))
Mark 22 11 'Раунд 2. Ваш ход: [3] Удар в спину' '0'
Seq-Special 'thief' 8
Mark 14 11 'Удар в спину. Вы наносите 8 урона.' '95'
Seq-EnemyStun
Mark 14 11 'Тень оглушена и пропускает ход.' '96'
[void]$frames.Add((Fr 'stand' 0 'stand' 0 '' 0 0)); [void]$frames.Add((Fr 'stand' 0 'stand' 0 '' 0 0))
Mark 14 11 'Раунд 3. Ваш ход: [2] Защита' '0'
Seq-Block
Seq-EnemyAttack 2 $true
Mark 14 9 'Блок смягчает удар: Тень наносит 2 урона.' '96'
[void]$frames.Add((Fr 'stand' 0 'stand' 0 '' 0 0)); [void]$frames.Add((Fr 'stand' 0 'stand' 0 '' 0 0))
Mark 14 9 'Раунд 4. Ваш ход: [1] Атака' '0'
Seq-Attack 14 $true
Mark 0 9 'Критический удар. Вы наносите 14 урона.' '93'
Seq-Win
Mark 0 9 'Тень повержена.' '92'
for ($k = 0; $k -lt 6; $k++) { [void]$frames.Add($frames[$frames.Count - 1]) }

function Get-Bar([int]$v, [int]$max) {
    $n = [Math]::Ceiling($v * 20 / $max); return ('#' * $n) + ('-' * (20 - $n))
}

$N = $frames.Count
$d = 0.11
$T = [Math]::Round($N * $d, 2)
$pct = [Math]::Round(100 / $N, 4)
$body = New-Object System.Text.StringBuilder
$cols = 72
for ($i = 0; $i -lt $N; $i++) {
    $info = $timeline[0]
    foreach ($tl in $timeline) { if ($tl[0] -le $i) { $info = $tl } }
    $hcol = if ($info[2] -le 6) { '91' } elseif ($info[2] -le 12) { '93' } else { '92' }
    $rows = New-Object System.Collections.ArrayList
    $hud = @(
        @('============================================================', '94'),
        @(' ', '0', 'Кира', '93', ' / ', '0', 'Вор', '95', '   HP: ', '0', "[$(Get-Bar $info[2] 20)] $($info[2])/20", $hcol, '   До рассвета: ', '0', '2 ч.', '96'),
        @(' Локация: ', '0', 'Вершина Шпиля', '96'),
        @('============================================================', '94'),
        @(''),
        @('  ', '0', 'Тень', '91', '  HP: ', '0', "[$(Get-Bar $info[1] 30)]", '91', " $($info[1])/30", '0')
    )
    foreach ($seg in $hud) {
        $cells = @()
        for ($k = 0; $k + 1 -lt $seg.Count; $k += 2) { foreach ($ch in $seg[$k].ToCharArray()) { $cells += , @([string]$ch, $seg[$k + 1]) } }
        [void]$rows.Add($cells)
    }
    foreach ($x in (New-PlainRows (Get-FrameLines $frames[$i] 'boss') '97')) { [void]$rows.Add($x) }
    [void]$rows.Add(@())
    foreach ($x in (New-PlainRows @('  ' + $info[3]) $info[4])) { [void]$rows.Add($x) }
    $delay = [Math]::Round($i * $d, 2)
    [void]$body.Append("<g class=`"f`" style=`"animation-delay:${delay}s`">`n")
    [void]$body.Append((Get-RowsSvg $rows $TOP))
    [void]$body.Append("</g>`n")
    $nrows = $rows.Count
}
$css = ".f{opacity:0;animation:show ${T}s step-end infinite}@keyframes show{0%{opacity:1}$pct%{opacity:0}100%{opacity:0}}"
$svg = Get-WindowSvg $cols $nrows 'Вершина Шпиля — бой с Тенью' $body.ToString() $css
[IO.File]::WriteAllText((Join-Path $OutDir 'battle.svg'), $svg, $utf8)
Write-Host "  battle.svg ($N кадров, $T с)" -ForegroundColor Green
Write-Host ''
