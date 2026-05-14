# Genere HELP\DEVENV\OBERON.RTF a partir de DOC\OBERON_SPEC_LANG.txt

$src = Get-Content (Join-Path $PSScriptRoot '..\..\DOC\OBERON_SPEC_LANG.txt')
$N = $src.Count

function Esc([string]$s) {
  $s = $s -replace '\\','\\'
  $s = $s -replace '\{','\{'
  $s = $s -replace '\}','\}'
  return $s
}

$secKeys = @{
  1  = 'Oberon presentation;Niklaus Wirth;ETH Zurich;Modula-2;Oberon-2;Oberon-07;Active Oberon'
  2  = 'Oberon structure programme;MODULE;IMPORT;BEGIN;END'
  3  = 'Oberon structure lexicale;identificateurs;mots reserves;litteraux;commentaires;export asterisque'
  4  = 'Oberon types donnees;BOOLEAN;CHAR;SHORTINT;INTEGER;LONGINT;REAL;LONGREAL;SET;BYTE;ARRAY;RECORD;POINTER'
  5  = 'Oberon declarations;CONST;TYPE;VAR;export'
  6  = 'Oberon operateurs;arithmetique;DIV;MOD;relationnel;logique;ensemble;IN;IS;precedence'
  7  = 'Oberon structures controle;IF;ELSIF;CASE;WHILE;REPEAT;FOR;LOOP;EXIT;WITH;RETURN'
  8  = 'Oberon procedures;parametres;VAR;tableau ouvert;recursivite;procedure liee type;methode;receveur'
  9  = 'Oberon tableaux;ARRAY;LEN;tableau ouvert;tableau dynamique;NEW;POINTER TO ARRAY'
  10 = 'Oberon enregistrements;RECORD;extension type;heritage;IS;type guard'
  11 = 'Oberon pointeurs;POINTER TO;NEW;NIL;garbage collector;ramasse-miettes'
  12 = 'Oberon modules;MODULE;IMPORT;export;asterisque;visibilite lecture seule;initialisation'
  13 = 'Oberon procedures standard;INC;DEC;ABS;ODD;LEN;ORD;CHR;NEW;HALT;INCL;EXCL;Out;In'
  14 = 'Oberon exceptions;erreurs execution;HALT;verification bornes'
  15 = 'Oberon SYSTEM;bas niveau;GET;PUT;MOVE;ADR;VAL;SIZE'
  16 = 'Oberon evolutions;Oberon 1988;Oberon-2 1991;Oberon-07;Active Oberon;Component Pascal'
  17 = 'Oberon compilateurs projet;OBERON86.PAS;OBERCW32.PAS'
  18 = 'Oberon convertisseurs;C2OBERON.PAS;ADA2OBER.PAS;PAS2OBER.PAS;OBER2PAS.PAS;OBER2CS.PAS;OBER2ADA.PAS;OBERON2C.PAS'
  19 = 'Oberon exemples;Hello World;Factorielle;liste chainee;extension type;polymorphisme;tri insertion'
  20 = 'Oberon Systeme;Oberon System;ETH;Native Oberon;Bluebottle;A2;Project Oberon'
  21 = 'Oberon influence;Component Pascal;Zonnon;Go;Modula-2 difference'
  22 = 'Oberon references;bibliographie;Wirth;Reiser;Mossenbock;Project Oberon;Oberon Microsystems'
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
    $prev = 'IDH_OBERON_{0:D2}' -f ($cur - 1)
    $parts += '{\uldb << Precedent}{\v ' + $prev + '}'
  }
  if ($cur -lt $total) {
    $nxt = 'IDH_OBERON_{0:D2}' -f ($cur + 1)
    $parts += '{\uldb Suivant >>}{\v ' + $nxt + '}'
  }
  if ($cur -ne 1) {
    $parts += '{\uldb Table des matieres}{\v IDH_OBERON_01}'
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
    $id = 'IDH_OBERON_{0:D2}' -f $n
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
    $id = 'IDH_OBERON_{0:D2}' -f $secNum
    [void]$sb.AppendLine('{\footnote # ' + $id + '}')
    [void]$sb.AppendLine('{\footnote ' + [char]36 + ' Oberon - ' + (Esc $secTitle) + '}')
    $kw = $secKeys[$secNum]
    if (-not $kw) { $kw = 'Oberon' }
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

$outPath = Join-Path $PSScriptRoot 'OBERON.RTF'
[System.IO.File]::WriteAllText($outPath, $sb.ToString(), [System.Text.Encoding]::ASCII)
Write-Host ("Genere: " + $outPath + " (" + (Get-Item $outPath).Length + " octets)")
