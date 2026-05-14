# Genere HELP\DEVENV\COBOL.RTF a partir de DOC\COBOL_SPEC_LANG.txt

$src = Get-Content (Join-Path $PSScriptRoot '..\..\DOC\COBOL_SPEC_LANG.txt')
$N = $src.Count

function Esc([string]$s) {
  $s = $s -replace '\\','\\'
  $s = $s -replace '\{','\{'
  $s = $s -replace '\}','\}'
  return $s
}

$secKeys = @{
  1  = 'COBOL presentation;CODASYL;Grace Hopper;FLOW-MATIC;DoD;ANSI;ISO 1989;COBOL-85;COBOL-2002;COBOL-2014;COBOL-2023'
  2  = 'COBOL structure programme;IDENTIFICATION DIVISION;ENVIRONMENT DIVISION;DATA DIVISION;PROCEDURE DIVISION;PROGRAM-ID;FILE-CONTROL;LINKAGE SECTION;WORKING-STORAGE'
  3  = 'COBOL structure lexicale;format colonnes;ANSI fixe;zone A;zone B;format libre;commentaires;insensible casse;mots reserves;figurative ZERO SPACE HIGH-VALUE'
  4  = 'COBOL types donnees;PICTURE;PIC;USAGE;DISPLAY;COMP;COMP-3;COMP-5;packed decimal;niveaux;01 88 77 66;OCCURS;REDEFINES;RENAMES;nom-condition'
  5  = 'COBOL instructions base;MOVE;DISPLAY;ACCEPT;COMPUTE;ADD;SUBTRACT;MULTIPLY;DIVIDE;STRING;UNSTRING;INSPECT;INITIALIZE'
  6  = 'COBOL structures controle;IF;ELSE;END-IF;EVALUATE;WHEN OTHER;PERFORM;TIMES;UNTIL;VARYING;inline;GO TO;CONTINUE;EXIT;STOP RUN'
  7  = 'COBOL fichiers;SEQUENTIAL;RELATIVE;INDEXED;LINE SEQUENTIAL;SELECT;ASSIGN;FD;OPEN;READ;WRITE;REWRITE;DELETE;START;FILE STATUS'
  8  = 'COBOL sous-programmes;CALL;USING;BY REFERENCE;BY CONTENT;BY VALUE;LINKAGE SECTION;EXIT PROGRAM;GOBACK;CANCEL'
  9  = 'COBOL COPY;COPY book;REPLACING;REPLACE;inclusion'
  10 = 'COBOL arithmetique decimale;precision exacte;COMP-3 packed;ROUNDED;ON SIZE ERROR;fonctions intrinseques;FUNCTION;SUM;MAX;SQRT;CURRENT-DATE;NUMVAL;UPPER-CASE;LENGTH'
  11 = 'COBOL tri fusion;SORT;MERGE;ASCENDING KEY;DESCENDING KEY;INPUT PROCEDURE;OUTPUT PROCEDURE'
  12 = 'COBOL Report Writer;REPORT SECTION;RD;INITIATE;GENERATE;TERMINATE'
  13 = 'COBOL-85 structuration;scope terminators;END-IF;END-PERFORM;END-EVALUATE;END-READ'
  14 = 'COBOL-2002 objets;CLASS-ID;METHOD-ID;FACTORY;OBJECT;format libre;NATIONAL;Unicode UTF-16;POINTER;ALLOCATE;FREE;exceptions'
  15 = 'COBOL compilateurs projet;COBOL86.PAS;COBOLW32.PAS;MS-DOS;Win32 PE;LARGE;MASM'
  16 = 'COBOL exemples;Hello World;boucle PERFORM VARYING;Factorielle;lecture fichier;sous-programme'
  17 = 'COBOL influence perennite;legacy;banque;assurance;mainframe;GnuCOBOL;Micro Focus;IBM Enterprise COBOL;modernisation'
  18 = 'COBOL references;bibliographie;ANSI X3.23;ISO 1989;Murach;Stern;Sammet;GnuCOBOL'
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
    $prev = 'IDH_COBOL_{0:D2}' -f ($cur - 1)
    $parts += '{\uldb << Precedent}{\v ' + $prev + '}'
  }
  if ($cur -lt $total) {
    $nxt = 'IDH_COBOL_{0:D2}' -f ($cur + 1)
    $parts += '{\uldb Suivant >>}{\v ' + $nxt + '}'
  }
  if ($cur -ne 1) {
    $parts += '{\uldb Table des matieres}{\v IDH_COBOL_01}'
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
    $id = 'IDH_COBOL_{0:D2}' -f $n
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
    $id = 'IDH_COBOL_{0:D2}' -f $secNum
    [void]$sb.AppendLine('{\footnote # ' + $id + '}')
    [void]$sb.AppendLine('{\footnote ' + [char]36 + ' COBOL - ' + (Esc $secTitle) + '}')
    $kw = $secKeys[$secNum]
    if (-not $kw) { $kw = 'COBOL' }
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

$outPath = Join-Path $PSScriptRoot 'COBOL.RTF'
[System.IO.File]::WriteAllText($outPath, $sb.ToString(), [System.Text.Encoding]::ASCII)
Write-Host ("Genere: " + $outPath + " (" + (Get-Item $outPath).Length + " octets)")
