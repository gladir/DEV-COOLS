# Genere HELP\DEVENV\MODULA2.RTF a partir de DOC\MODULA2_SPEC_LANG.txt

$src = Get-Content (Join-Path $PSScriptRoot '..\..\DOC\MODULA2_SPEC_LANG.txt')
$N = $src.Count

function Esc([string]$s) {
  $s = $s -replace '\\','\\'
  $s = $s -replace '\{','\{'
  $s = $s -replace '\}','\}'
  return $s
}

$secKeys = @{
  1  = 'Modula-2 presentation;Niklaus Wirth;ETH Zurich;Lilith;Medos-2;PIM-4;ISO 10514;Modula-2 R10'
  2  = 'Modula-2 structure programme;MODULE;DEFINITION MODULE;IMPLEMENTATION MODULE;BEGIN;END'
  3  = 'Modula-2 structure lexicale;identificateurs;mots reserves;litteraux;commentaires imbricables;sensible casse'
  4  = 'Modula-2 types donnees;BOOLEAN;CHAR;INTEGER;CARDINAL;LONGINT;LONGREAL;BITSET;ARRAY;RECORD;variantes;POINTER;SET;types procedure;tableaux ouverts'
  5  = 'Modula-2 declarations;CONST;TYPE;VAR;ordre declarations'
  6  = 'Modula-2 operateurs;arithmetique;DIV;MOD;relationnel;different #;logique;ensemble;IN;precedence'
  7  = 'Modula-2 structures controle;IF;ELSIF;CASE;WHILE;REPEAT;FOR;BY;LOOP;EXIT;WITH;RETURN'
  8  = 'Modula-2 procedures;parametres;VAR;tableau ouvert;HIGH;recursivite;types procedure;FORWARD'
  9  = 'Modula-2 modules;DEFINITION MODULE;IMPLEMENTATION MODULE;EXPORT QUALIFIED;FROM IMPORT;IMPORT;modules locaux'
  10 = 'Modula-2 pointeurs;POINTER TO;NEW;DISPOSE;ALLOCATE;DEALLOCATE;Storage;NIL;dereferencement'
  11 = 'Modula-2 coroutines;PROCESS;NEWPROCESS;TRANSFER;IOTRANSFER;SYSTEM;concurrence cooperative'
  12 = 'Modula-2 procedures standard;ABS;CAP;CHR;ORD;ODD;INC;DEC;INCL;EXCL;HIGH;SIZE;NEW;DISPOSE;FLOAT;TRUNC;ROUND;HALT;ADR;TSIZE'
  13 = 'Modula-2 bibliotheques;InOut;MathLib0;Strings;Storage;SYSTEM;WriteString;WriteCard;WriteInt;ReadString'
  14 = 'Modula-2 evolutions;Modula-2 original 1979;Modula-2 revise 1984;PIM-4 1988;ISO 10514 1996;Modula-2 R10 2010'
  15 = 'Modula-2 compilateur projet;MODII86.PAS;MS-DOS;assembleur 8086;MASM;modele SMALL'
  16 = 'Modula-2 convertisseurs;ADA2MOD2.PAS;PAS2MOD2.PAS;Ada vers Modula-2;Pascal vers Modula-2'
  17 = 'Modula-2 exemples;Hello World;Factorielle;liste chainee;module pile;DEFINITION;IMPLEMENTATION'
  18 = 'Modula-2 influence;Oberon;Modula-3;Ada;Component Pascal;comparaison Pascal'
  19 = 'Modula-2 references;bibliographie;Wirth PIM-4;ISO 10514-1;King;Modula-2 R10'
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
    $prev = 'IDH_MODULA2_{0:D2}' -f ($cur - 1)
    $parts += '{\uldb << Precedent}{\v ' + $prev + '}'
  }
  if ($cur -lt $total) {
    $nxt = 'IDH_MODULA2_{0:D2}' -f ($cur + 1)
    $parts += '{\uldb Suivant >>}{\v ' + $nxt + '}'
  }
  if ($cur -ne 1) {
    $parts += '{\uldb Table des matieres}{\v IDH_MODULA2_01}'
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
    $id = 'IDH_MODULA2_{0:D2}' -f $n
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
    $id = 'IDH_MODULA2_{0:D2}' -f $secNum
    [void]$sb.AppendLine('{\footnote # ' + $id + '}')
    [void]$sb.AppendLine('{\footnote ' + [char]36 + ' Modula-2 - ' + (Esc $secTitle) + '}')
    $kw = $secKeys[$secNum]
    if (-not $kw) { $kw = 'Modula-2' }
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

$outPath = Join-Path $PSScriptRoot 'MODULA2.RTF'
[System.IO.File]::WriteAllText($outPath, $sb.ToString(), [System.Text.Encoding]::ASCII)
Write-Host ("Genere: " + $outPath + " (" + (Get-Item $outPath).Length + " octets)")
