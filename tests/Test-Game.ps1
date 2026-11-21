<#
.SYNOPSIS
    Автотесты «Этерия: Осколок Луны».

.DESCRIPTION
    1. Статические проверки BAT-файла: кодировка, окончания строк,
       существование всех меток goto/call, синтаксис PowerShell-блока.
    2. Сценарии: игра запускается с ETHERIA_TEST=1 и заранее записанным
       вводом, тест проверяет, какой исход получился.

    Запуск:  powershell -ExecutionPolicy Bypass -File tests\Test-Game.ps1
#>
[CmdletBinding()]
param(
    [string]$Game
)

if (-not $Game) {
    $here = Split-Path -Parent $MyInvocation.MyCommand.Path
    $Game = Join-Path $here '..\etheria-moonshard.bat'
}

$ErrorActionPreference = 'Stop'
$Game = (Resolve-Path $Game).Path
$failed = 0
$passed = 0

function Pass($name) { $script:passed++; Write-Host "  [PASS] $name" -ForegroundColor Green }
function Fail($name, $why) { $script:failed++; Write-Host "  [FAIL] $name - $why" -ForegroundColor Red }

# ------------------------------------------------------------------
Write-Host "`nСтатические проверки" -ForegroundColor Cyan
# ------------------------------------------------------------------
$bytes = [IO.File]::ReadAllBytes($Game)
$text = [Text.Encoding]::UTF8.GetString($bytes)

if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB) {
    Fail 'UTF-8 без BOM' 'BOM ломает первую строку @echo off'
} else { Pass 'UTF-8 без BOM' }

$lfOnly = ([regex]::Matches($text, "(?<!`r)`n")).Count
if ($lfOnly -gt 0) { Fail 'CRLF' "строк с LF без CR: $lfOnly" } else { Pass 'Окончания строк CRLF' }

# Файл в самом git тоже должен быть с CRLF: «Download raw» на GitHub отдаёт его как есть,
# и с LF игра закрывается сразу после запуска.
$git = Get-Command git -ErrorAction SilentlyContinue
if ($git) {
    Push-Location (Split-Path $Game)
    $eol = (& git ls-files --eol -- (Split-Path $Game -Leaf) 2>$null) -join ''
    Pop-Location
    if (-not $eol) { Write-Host '  [SKIP] CRLF в git: файл не под контролем git' -ForegroundColor DarkGray }
    elseif ($eol -match '^i/crlf') { Pass 'В git файл хранится с CRLF' }
    else { Fail 'CRLF в git' "индекс: $eol" }
}
$psStart = $text.LastIndexOf('#PSBEGIN')
$batch = $text.Substring(0, $psStart)
$labels = [regex]::Matches($batch, '(?m)^:([A-Za-z_][A-Za-z0-9_]*)') | ForEach-Object { $_.Groups[1].Value.ToUpper() }
$labelSet = [Collections.Generic.HashSet[string]]::new([string[]]$labels)
$targets = [regex]::Matches($batch, '(?i)\b(?:goto|call)\s+:?([A-Za-z_][A-Za-z0-9_]*)') |
    ForEach-Object { $_.Groups[1].Value.ToUpper() } |
    Where-Object { $_ -ne 'EOF' } | Sort-Object -Unique
$missing = $targets | Where-Object { -not $labelSet.Contains($_) }
if ($missing) { Fail 'Метки goto/call' ("нет меток: " + ($missing -join ', ')) }
else { Pass "Все $($targets.Count) меток goto/call существуют" }

$dups = $labels | Group-Object | Where-Object Count -gt 1
if ($dups) { Fail 'Уникальность меток' (($dups.Name) -join ', ') } else { Pass 'Метки уникальны' }

$tokens = $null; $errors = $null
[void][Management.Automation.Language.Parser]::ParseInput($text.Substring($psStart), [ref]$tokens, [ref]$errors)
if ($errors.Count) { Fail 'PowerShell-блок' $errors[0].Message } else { Pass 'PowerShell-блок без синтаксических ошибок' }

# ------------------------------------------------------------------
Write-Host "`nСценарии прохождения" -ForegroundColor Cyan
# ------------------------------------------------------------------
# Ввод: каждая цифра - нажатие в меню, 'x' - любая клавиша на паузе,
# строка с переводом - имя героя.
$NL = "`r`n"
$scenarios = @(
    @{ Name = 'Рассвет дорогой ценой: ключ, алтарь без амулета'; Expect = @(3)
       Input = "x1Hero$NL" + '1x' + '11x' + '41' + 'x1' + '26' }
    @{ Name = 'Рассвет Этерии: ключ и Амулет Света'; Expect = @(1)
       Input = "x1Hero$NL" + '1x' + '11x' + '23x' + '41' + 'x1' + '26' }
    @{ Name = 'Король Теней: отдать осколок'; Expect = @(5)
       Input = "x1Hero$NL" + '2x' + '11x' + '41' + 'x2' + '26' }
    @{ Name = 'Пепел и свобода: разбить осколок'; Expect = @(4)
       Input = "x1Hero$NL" + '3x' + '11x' + '41' + 'x3' + '26' }
    @{ Name = 'Сожжённый светом: маг ранен паролями'; Expect = @(6)
       Input = "x1Hero$NL" + '2x' + '1' + '2333' + '1x' + '41' + 'x1' + '26' }
    @{ Name = 'Слишком поздно: время кончилось'; Expect = @(8)
       Input = "x1Hero$NL" + '1x' + '124x' + '22x' + '5x' + '3111x' + '4' }
    @{ Name = 'Сохранение и продолжение: ключ переживает перезагрузку'; Expect = @(3)
       Input = "x1Hero$NL" + '1x' + '11x' + '623' + '2' + '41' + 'x1' }
    @{ Name = 'Бой с Тенью: только защита'; Expect = @(7)
       Input = "x1Hero$NL" + '2x' + '11x' + '41' + 'x4' + ('2x' * 80) + '26' }
    @{ Name = 'Бой с Тенью: атака (победа или смерть)'; Expect = @(2, 7)
       Input = "x1Hero$NL" + '3x' + '11x' + '23x' + '31' + '1' + '1x' + '41' + 'x4' + ('3x1x1x' * 20) + '26' }
)

$work = Join-Path ([IO.Path]::GetTempPath()) ("etheria-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
try {
    foreach ($s in $scenarios) {
        $dir = Join-Path $work ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $dir | Out-Null
        Copy-Item $Game (Join-Path $dir 'game.bat')
        $in = Join-Path $dir 'input.txt'
        $out = Join-Path $dir 'output.txt'
        [IO.File]::WriteAllText($in, $s.Input)

        $env:ETHERIA_TEST = '1'
        $p = Start-Process cmd.exe -ArgumentList "/c `"`".\game.bat`" < input.txt > output.txt 2>&1`"" `
            -WorkingDirectory $dir -NoNewWindow -PassThru
        if (-not $p.WaitForExit(60000)) { $p.Kill(); Fail $s.Name 'тайм-аут'; continue }
        Remove-Item Env:ETHERIA_TEST

        $log = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($out))
        $m = [regex]::Match($log, '(?:Исход|РСЃС…РѕРґ)\s+(\d)')
        if (-not $m.Success) {
            $tail = ($log -split "`n" | Select-Object -Last 5) -join ' | '
            Fail $s.Name "концовка не достигнута: $tail"
            continue
        }
        $got = [int]$m.Groups[1].Value
        if ($s.Expect -contains $got) { Pass "$($s.Name) -> исход $got" }
        else { Fail $s.Name "ожидался исход $($s.Expect -join '/'), получен $got" }

        $prog = Join-Path $dir 'etheria-progress.cfg'
        if (-not (Test-Path $prog) -or -not (Select-String -Path $prog -Pattern "^e${got}:1" -Quiet)) {
            Fail "$($s.Name): Летопись" 'концовка не записана в etheria-progress.cfg'
        }
    }
}
finally {
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ("`nИтого: {0} пройдено, {1} провалено`n" -f $passed, $failed) -ForegroundColor $(if ($failed) { 'Red' } else { 'Green' })
exit $failed
