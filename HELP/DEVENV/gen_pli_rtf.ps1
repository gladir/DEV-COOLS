# Genere HELP\DEVENV\PLI.RTF a partir de DOC\PLI_SPEC_LANG.txt

$src = Get-Content (Join-Path $PSScriptRoot '..\..\DOC\PLI_SPEC_LANG.txt')
$N = $src.Count

function Esc([string]$s) {
  $s = $s -replace '\\','\\'
  $s = $s -replace '\{','\{'
  $s = $s -replace '\}','\}'
  return $s
}

$secKeys = @{
  1  = 'PL/I introduction;PL/1;IBM 1964;NPL;System/360;ANSI X3.53;PL/M;DR PL/I-86;Enterprise PL/I'
  2  = 'PL/I philosophie;universalite;defauts intelligents;lisibilite;modularite;extensibilite;conversions implicites;ON-units'
  3  = 'PL/I structure programme;PROCEDURE OPTIONS(MAIN);BEGIN END;blocs imbriques;portee lexicale;commentaires;etiquettes labels'
  4  = 'PL/I lexique;identificateurs;mots-cles non reserves;constantes numeriques;constantes binaires B;chaines apostrophes;chaines bits'
  5  = 'PL/I types donnees;FIXED BINARY;FIXED DECIMAL;FLOAT BINARY;FLOAT DECIMAL;CHARACTER VARYING;BIT;PICTURE;POINTER OFFSET;LABEL;ENTRY'
  6  = 'PL/I DECLARE DCL;attributs;declarations factorisees;niveaux 1 2 3;INITIAL;LIKE;ALIGNED'
  7  = 'PL/I classes stockage;AUTOMATIC;STATIC;EXTERNAL;BASED;CONTROLLED;ALLOCATE FREE;pile heap'
  8  = 'PL/I operateurs;arithmetiques;puissance **;comparaison =;^= != ~=;logiques & | ^;concatenation ||;precedence;conversions implicites'
  9  = 'PL/I controle flux;affectation multiple;IF THEN ELSE;DO TO BY WHILE UNTIL FOREVER;LEAVE ITERATE;SELECT WHEN OTHERWISE;GOTO;CALL RETURN'
  10 = 'PL/I procedures fonctions;PROCEDURE RETURNS;passage parametres reference valeur;RECURSIVE;OPTIONS MAIN REENTRANT BYVALUE LINKAGE'
  11 = 'PL/I entrees sorties;PUT GET LIST EDIT DATA;format A F E B P X SKIP PAGE COL;FILE INPUT OUTPUT;STREAM RECORD;OPEN CLOSE READ WRITE'
  12 = 'PL/I pointeurs structures;POINTER NULL;ADDR;BASED;ALLOCATE SET;structures auto-referentielles;liste chainee'
  13 = 'PL/I tableaux;dimensions;indices;sections de tableaux;expressions tableau;matrice;tableaux structures'
  14 = 'PL/I exceptions;ON-units;OVERFLOW UNDERFLOW ZERODIVIDE SIZE STRINGSIZE SUBSCRIPTRANGE CONVERSION ENDFILE ERROR FINISH;SIGNAL;REVERT'
  15 = 'PL/I preprocesseur;%INCLUDE;%DECLARE;%IF %THEN %ELSE;%DO;%PROCEDURE;macros'
  16 = 'PLI86.PAS;compilateur PL/I 8086;sortie MASM TASM;projet DEV-COOLS;modeles memoire SMALL COMPACT;pipeline assemblage liens'
  17 = 'PL/I exemples;Hello World;factorielle recursive;tri a bulles;lecture fichier;liste chainee'
  18 = 'PL/I differences;PL/I vs C;PL/I vs COBOL;PL/I vs Fortran;comparaison langages'
  19 = 'PL/I ressources projet;PLI86.PAS;ASM86.PAS;MASM.PAS;LINK.PAS;LIB.PAS;DISEXE.PAS;DEBUG.PAS'
  20 = 'PL/I bibliographie;ANSI X3.53;ISO 6160;ISO 6522;Pollack Sterling;Hughes;Sturm;IBM Enterprise PL/I;Iron Spring PL/I;Kednos PL/I'
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
    $prev = 'IDH_PLI_{0:D2}' -f ($cur - 1)
    $parts += '{\uldb << Precedent}{\v ' + $prev + '}'
  }
  if ($cur -lt $total) {
    $nxt = 'IDH_PLI_{0:D2}' -f ($cur + 1)
    $parts += '{\uldb Suivant >>}{\v ' + $nxt + '}'
  }
  if ($cur -ne 1) {
    $parts += '{\uldb Table des matieres}{\v IDH_PLI_01}'
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
    $id = 'IDH_PLI_{0:D2}' -f $n
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
    $id = 'IDH_PLI_{0:D2}' -f $secNum
    [void]$sb.AppendLine('{\footnote # ' + $id + '}')
    [void]$sb.AppendLine('{\footnote ' + [char]36 + ' PL/I - ' + (Esc $secTitle) + '}')
    $kw = $secKeys[$secNum]
    if (-not $kw) { $kw = 'PL/I' }
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

$outPath = Join-Path $PSScriptRoot 'PLI.RTF'
[System.IO.File]::WriteAllText($outPath, $sb.ToString(), [System.Text.Encoding]::ASCII)
Write-Host ("Genere: " + $outPath + " (" + (Get-Item $outPath).Length + " octets)")
