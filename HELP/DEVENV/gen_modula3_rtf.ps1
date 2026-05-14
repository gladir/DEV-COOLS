# Genere HELP\DEVENV\MODULA3.RTF a partir de DOC\MODULA3_SPEC_LANG.txt

$src = Get-Content (Join-Path $PSScriptRoot '..\..\DOC\MODULA3_SPEC_LANG.txt')
$N = $src.Count

function Esc([string]$s) {
  $s = $s -replace '\\','\\'
  $s = $s -replace '\{','\{'
  $s = $s -replace '\}','\}'
  return $s
}

$secKeys = @{
  1  = 'Modula-3 presentation;Cardelli;Nelson;DEC SRC;Olivetti;Modula-2+;Cedar;SRC Modula-3;CM3'
  2  = 'Modula-3 structure programme;MODULE;INTERFACE;EXPORTS Main;IMPORT;BEGIN;END'
  3  = 'Modula-3 structure lexicale;identificateurs;mots reserves;litteraux;commentaires imbricables;sensible casse'
  4  = 'Modula-3 types donnees;INTEGER;LONGINT;CARDINAL;BOOLEAN;CHAR;REAL;LONGREAL;EXTENDED;TEXT;ARRAY;RECORD;SET;REF;REFANY;OBJECT;BITS FOR'
  5  = 'Modula-3 declarations;CONST;TYPE;VAR;OPAQUE;REVEAL;ordre libre'
  6  = 'Modula-3 operateurs;arithmetique;DIV;MOD;relationnel;sous-type;logique court-circuit;ensemble;concatenation;precedence'
  7  = 'Modula-3 structures controle;IF;ELSIF;CASE;WHILE;REPEAT;FOR;BY;LOOP;EXIT;WITH;TYPECASE;RETURN'
  8  = 'Modula-3 procedures;parametres;VALUE;VAR;READONLY;valeurs defaut;parametres nommes;RAISES;premiere classe'
  9  = 'Modula-3 objets;OBJECT;METHODS;OVERRIDES;heritage;sous-typage;NEW;NARROW;ISTYPE;BRANDED;self'
  10 = 'Modula-3 exceptions;EXCEPTION;RAISE;TRY;EXCEPT;FINALLY;parametres exception'
  11 = 'Modula-3 concurrence;Thread;Fork;Join;Mutex;Condition;LOCK;Wait;Signal;Broadcast;Closure'
  12 = 'Modula-3 generiques;GENERIC INTERFACE;GENERIC MODULE;instanciation;parametre interface'
  13 = 'Modula-3 unsafe;UNSAFE;LOOPHOLE;UNTRACED REF;ADR;SUBARRAY;safe'
  14 = 'Modula-3 procedures standard;ABS;MAX;MIN;INC;DEC;ORD;VAL;FLOAT;TRUNC;ROUND;CEILING;FLOOR;NUMBER;FIRST;LAST;NEW;DISPOSE;ISTYPE;NARROW;TYPECODE;BITSIZE;BYTESIZE'
  15 = 'Modula-3 bibliotheques;IO;Text;Wr;Rd;Stdio;Thread;Fmt;Lex;Math;OS;Pickle;NetObj;Network Objects'
  16 = 'Modula-3 evolutions;Cedar;Modula-2+;SRC 1988;Modula-3 1989;SRC M3;CM3;PM3;EzM3;statut actuel'
  17 = 'Modula-3 compilateur projet;MODIII86.PAS;MS-DOS;assembleur 8086;MASM;modele LARGE'
  18 = 'Modula-3 convertisseurs;ADA2MOD3.PAS;PAS2MOD3.PAS;Ada vers Modula-3;Pascal vers Modula-3'
  19 = 'Modula-3 exemples;Hello World;Factorielle;heritage objets;exception finally;thread simple'
  20 = 'Modula-3 influence;Java;C#;Python;Go;comparaison Modula-2'
  21 = 'Modula-3 references;bibliographie;Cardelli;Nelson;Harbison;SRC Report 52;CM3'
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
    $prev = 'IDH_MODULA3_{0:D2}' -f ($cur - 1)
    $parts += '{\uldb << Precedent}{\v ' + $prev + '}'
  }
  if ($cur -lt $total) {
    $nxt = 'IDH_MODULA3_{0:D2}' -f ($cur + 1)
    $parts += '{\uldb Suivant >>}{\v ' + $nxt + '}'
  }
  if ($cur -ne 1) {
    $parts += '{\uldb Table des matieres}{\v IDH_MODULA3_01}'
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
    $id = 'IDH_MODULA3_{0:D2}' -f $n
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
    $id = 'IDH_MODULA3_{0:D2}' -f $secNum
    [void]$sb.AppendLine('{\footnote # ' + $id + '}')
    [void]$sb.AppendLine('{\footnote ' + [char]36 + ' Modula-3 - ' + (Esc $secTitle) + '}')
    $kw = $secKeys[$secNum]
    if (-not $kw) { $kw = 'Modula-3' }
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

$outPath = Join-Path $PSScriptRoot 'MODULA3.RTF'
[System.IO.File]::WriteAllText($outPath, $sb.ToString(), [System.Text.Encoding]::ASCII)
Write-Host ("Genere: " + $outPath + " (" + (Get-Item $outPath).Length + " octets)")
