# Genere HELP\DEVENV\FORTRAN77.RTF a partir de DOC\FORTRAN77_SPEC_LANG.txt

$src = Get-Content (Join-Path $PSScriptRoot '..\..\DOC\FORTRAN77_SPEC_LANG.txt')
$N = $src.Count

function Esc([string]$s) {
  $s = $s -replace '\\','\\'
  $s = $s -replace '\{','\{'
  $s = $s -replace '\}','\}'
  return $s
}

$secKeys = @{
  1  = 'FORTRAN 77 presentation;John Backus;IBM 704;ANSI X3.9-1978;ISO 1539:1980;FORTRAN II;FORTRAN IV;FORTRAN 66;Fortran 90;calcul scientifique;LAPACK;BLAS'
  2  = 'FORTRAN 77 structure programme;PROGRAM;SUBROUTINE;FUNCTION;BLOCK DATA;IMPLICIT;ordre instructions;END'
  3  = 'FORTRAN 77 format colonne fixe;colonnes 1-5 1-6 7-72 73-80;label;continuation;commentaire C *;identificateurs;typage implicite;litteraux Hollerith'
  4  = 'FORTRAN 77 types donnees;INTEGER;REAL;DOUBLE PRECISION;COMPLEX;LOGICAL;CHARACTER;DIMENSION;column-major;PARAMETER;DATA;EQUIVALENCE'
  5  = 'FORTRAN 77 operateurs;arithmetique;**;.EQ. .NE. .LT. .LE. .GT. .GE.;.NOT. .AND. .OR. .EQV. .NEQV.;concatenation //;precedence;conversions implicites'
  6  = 'FORTRAN 77 controle;IF logique;IF arithmetique;IF THEN ELSE END IF;DO;CONTINUE;GOTO;GOTO calcule;STOP;END;PAUSE;RETURN'
  7  = 'FORTRAN 77 sous-programmes;SUBROUTINE;FUNCTION;CALL;passage par reference;statement function;EXTERNAL;INTRINSIC;SAVE'
  8  = 'FORTRAN 77 COMMON;blank common;named common;BLOCK DATA;partage variables;layout memoire'
  9  = 'FORTRAN 77 entrees sorties;WRITE;READ;FORMAT;list-directed;OPEN;CLOSE;ACCESS DIRECT;IOSTAT;REWIND;BACKSPACE;ENDFILE;INQUIRE'
  10 = 'FORTRAN 77 fonctions intrinseques;ABS;SQRT;EXP;LOG;SIN COS TAN;INT REAL DBLE CMPLX;MAX MIN MOD;LEN INDEX ICHAR CHAR;formes typees DABS DSQRT'
  11 = 'FORTRAN 77 CHARACTER;concatenation //;sous-chaine substring;comparaison lexicale LGE LGT LLE LLT'
  12 = 'FORTRAN 77 extensions;MIL-STD-1753;DO WHILE;END DO;IMPLICIT NONE;INTEGER*1 INTEGER*2 INTEGER*4;INCLUDE;NAMELIST;VAX;IBM'
  13 = 'FORTRAN 77 compilateur projet;F77C86.PAS;DOS 8086;MASM;COM EXE;IEEE 754'
  14 = 'FORTRAN 77 exemples;Hello;tableau;moyenne;factorielle;equation second degre;produit matriciel;lecture fichier'
  15 = 'FORTRAN 77 bonnes pratiques;IMPLICIT NONE;PARAMETER;indentation;IOSTAT;deprecies;GOTO;ASSIGN;PAUSE'
  16 = 'FORTRAN 77 influence;LAPACK;BLAS;NAG;IMSL;LINPACK;EISPACK;ARPACK;MINPACK;CERNLIB;ANSYS;NASTRAN;gfortran;Intel Fortran;LFortran'
  17 = 'FORTRAN 77 references;bibliographie;ANSI X3.9-1978;ISO 1539:1980;MIL-STD-1753;Metcalf Reid;Numerical Recipes;Backus'
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
    $prev = 'IDH_FORTRAN77_{0:D2}' -f ($cur - 1)
    $parts += '{\uldb << Precedent}{\v ' + $prev + '}'
  }
  if ($cur -lt $total) {
    $nxt = 'IDH_FORTRAN77_{0:D2}' -f ($cur + 1)
    $parts += '{\uldb Suivant >>}{\v ' + $nxt + '}'
  }
  if ($cur -ne 1) {
    $parts += '{\uldb Table des matieres}{\v IDH_FORTRAN77_01}'
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
    $id = 'IDH_FORTRAN77_{0:D2}' -f $n
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
    $id = 'IDH_FORTRAN77_{0:D2}' -f $secNum
    [void]$sb.AppendLine('{\footnote # ' + $id + '}')
    [void]$sb.AppendLine('{\footnote ' + [char]36 + ' FORTRAN 77 - ' + (Esc $secTitle) + '}')
    $kw = $secKeys[$secNum]
    if (-not $kw) { $kw = 'FORTRAN 77' }
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

$outPath = Join-Path $PSScriptRoot 'FORTRAN77.RTF'
[System.IO.File]::WriteAllText($outPath, $sb.ToString(), [System.Text.Encoding]::ASCII)
Write-Host ("Genere: " + $outPath + " (" + (Get-Item $outPath).Length + " octets)")
