# Genere HELP\DEVENV\JOVIAL.RTF a partir de DOC\JOVIAL_SPEC_LANG.txt

$src = Get-Content (Join-Path $PSScriptRoot '..\..\DOC\JOVIAL_SPEC_LANG.txt')
$N = $src.Count

function Esc([string]$s) {
  $s = $s -replace '\\','\\'
  $s = $s -replace '\{','\{'
  $s = $s -replace '\}','\}'
  return $s
}

$secKeys = @{
  1  = 'JOVIAL presentation;Jules Schwartz;SDC;System Development Corporation;SAGE;IAL;ALGOL 58;USAF;DoD;MIL-STD-1589;J3;J73'
  2  = 'JOVIAL structure programme;PROGRAM;PROC;START;TERM;BEGIN;END;COMPOOL;commentaires'
  3  = 'JOVIAL lexical;identificateurs;mots reserves;litteraux;hexadecimal;octal;binaire;FIXED;FLOATING'
  4  = 'JOVIAL types;ITEM;TABLE;OVERLAY;INTEGER;FLOATING;FIXED;BIT;CHAR;STATUS;POINTER;BOOLEAN;DENSE;MEDIUM;PARALLEL;SERIAL;DEFINE;CONSTANT'
  5  = 'JOVIAL operateurs;arithmetique;relationnel;EQ NQ LS LQ GR GQ;logique;AND OR NOT XOR;bit-a-bit;BAND BOR BXOR;SHL SHR;precedence'
  6  = 'JOVIAL controle;IF THEN ELSE;CASE;FOR STEP UNTIL;WHILE;GOTO;EXIT;STOP;RETURN'
  7  = 'JOVIAL procedures;PROC;RETURNS;parametres;IN OUT INOUT;appel'
  8  = 'JOVIAL COMPOOL;modules;declarations partagees;USES;compilation separee'
  9  = 'JOVIAL entrees sorties;INPUT;OUTPUT;registres memoire-mappes;LOC'
  10 = 'JOVIAL adressage;LOC;REF;pointeurs;@;dereferencement;bas niveau'
  11 = 'JOVIAL temps reel;INTERRUPT;INLINE assembleur;sections atomiques;embarque'
  12 = 'JOVIAL dialectes;J3;J3B Burroughs;J73 MIL-STD-1589;J73/I;evolution'
  13 = 'JOVIAL compilateurs projet;JOVIAL86.PAS;JOVCW32.PAS;DOS 8086;Win32 PE;MASM;FIXED point Q-format'
  14 = 'JOVIAL exemples;Hello;somme tableau;factorielle;registre materiel;machine etats;STATUS CASE'
  15 = 'JOVIAL influence;CMS-2;TACPOL;Ada;SPARK;F-16;B-1B;B-52;AWACS;DDC-I;SEA'
  16 = 'JOVIAL references;bibliographie;MIL-STD-1589C;Shaw;Schwartz;Sammet;HOLWG;AFSCM 300-9'
}

$titles = @{}
for ($k = 1; $k -lt $N - 1; $k++) {
  if ($src[$k-1] -match '^={3,}\s*$' -and
      $src[$k+1] -match '^={3,}\s*$' -and
      $src[$k]   -match '^\s*(\d+)\.\s+(.+?)\s*$') {
    $tNum = [int]$Matches[1]; $tTit = $Matches[2].Trim()
    $titles[$tNum] = $tTit
  }
}
$totalSecs = ($titles.Keys | Measure-Object -Maximum).Maximum

function EmitNav($sb, [int]$cur, [int]$total) {
  [void]$sb.AppendLine('\par')
  $parts = @()
  if ($cur -gt 1) {
    $prev = 'IDH_JOVIAL_{0:D2}' -f ($cur - 1)
    $parts += '{\uldb << Precedent}{\v ' + $prev + '}'
  }
  if ($cur -lt $total) {
    $nxt = 'IDH_JOVIAL_{0:D2}' -f ($cur + 1)
    $parts += '{\uldb Suivant >>}{\v ' + $nxt + '}'
  }
  if ($cur -ne 1) {
    $parts += '{\uldb Table des matieres}{\v IDH_JOVIAL_01}'
  }
  $parts += '{\uldb Retour aux langages}{\v IDH_LANGAGES}'
  [void]$sb.AppendLine(($parts -join '     ') + '\par')
}

function EmitTOC($sb, $titles, [int]$total) {
  [void]$sb.AppendLine('\par')
  [void]$sb.AppendLine('\b Sections suivantes : \b0\par')
  [void]$sb.AppendLine('\par')
  for ($n = 2; $n -le $total; $n++) {
    if (-not $titles.ContainsKey($n)) { continue }
    $id = 'IDH_JOVIAL_{0:D2}' -f $n
    $lbl = ('{0,2}. {1}' -f $n, $titles[$n])
    [void]$sb.AppendLine('{\f1 ' + (Esc $lbl) + '}     {\uldb [Aller]}{\v ' + $id + '}\par')
  }
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('{\rtf1\ansi\deff0')
[void]$sb.AppendLine('{\fonttbl{\f0\fswiss Helvetica;}{\f1\fmodern Courier New;}}')
[void]$sb.AppendLine('')

$i = 0
$inTopic = $false
$curSec = 0

while ($i -lt $N) {
  $line = $src[$i]

  if ($i+2 -lt $N -and
      $src[$i]   -match '^={3,}\s*$' -and
      $src[$i+2] -match '^={3,}\s*$' -and
      $src[$i+1] -match '^\s*(\d+)\.\s+(.+?)\s*$') {
    $secNum = [int]$Matches[1]
    $secTitle = $Matches[2].Trim()
    if ($inTopic) {
      if ($curSec -eq 1) { EmitTOC $sb $titles $totalSecs }
      EmitNav $sb $curSec $totalSecs
      [void]$sb.AppendLine('\page')
      [void]$sb.AppendLine('')
    }
    $id = 'IDH_JOVIAL_{0:D2}' -f $secNum
    [void]$sb.AppendLine('{\footnote # ' + $id + '}')
    [void]$sb.AppendLine('{\footnote ' + [char]36 + ' JOVIAL - ' + (Esc $secTitle) + '}')
    $kw = $secKeys[$secNum]
    if (-not $kw) { $kw = 'JOVIAL' }
    [void]$sb.AppendLine('{\footnote K ' + $kw + '}')
    [void]$sb.AppendLine('\b\fs24 ' + (Esc $secTitle) + ' \b0\fs20\par')
    [void]$sb.AppendLine('\par')
    $i += 3
    while ($i -lt $N -and $src[$i].Trim() -eq '') { $i++ }
    $inTopic = $true
    $curSec = $secNum
    continue
  }

  if (-not $inTopic) { $i++; continue }

  if ($i+1 -lt $N -and $src[$i+1] -match '^\s*-{3,}\s*$' -and
      $line -match '^\s*(\d+\.\d+)\s+(.+?)\s*$') {
    [void]$sb.AppendLine('\par')
    [void]$sb.AppendLine('\b ' + (Esc $line.Trim()) + ' \b0\par')
    [void]$sb.AppendLine('\par')
    $i += 2
    while ($i -lt $N -and $src[$i].Trim() -eq '') { $i++ }
    continue
  }

  if ($line -match '^\s*-{3,}\s*$' -or $line -match '^\s*={3,}\s*$') {
    $i++; continue
  }

  if ($line.Trim() -eq '') {
    [void]$sb.AppendLine('\par')
    $i++; continue
  }

  if ($line -match '^\s+\S') {
    $txt = $line -replace "`t", '    '
    $txt = Esc $txt
    [void]$sb.AppendLine('{\f1 ' + $txt + '}\par')
  } else {
    [void]$sb.AppendLine((Esc $line) + '\par')
  }
  $i++
}

[void]$sb.AppendLine('')
if ($inTopic) { EmitNav $sb $curSec $totalSecs }
[void]$sb.AppendLine('}')

$outPath = Join-Path $PSScriptRoot 'JOVIAL.RTF'
[System.IO.File]::WriteAllText($outPath, $sb.ToString(), [System.Text.Encoding]::ASCII)
Write-Host ("Genere: " + $outPath + " (" + (Get-Item $outPath).Length + " octets)")
