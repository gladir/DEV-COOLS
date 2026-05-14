# Genere HELP\DEVENV\BCPL.RTF a partir de DOC\BCPL_SPEC_LANG.txt

$src = Get-Content (Join-Path $PSScriptRoot '..\..\DOC\BCPL_SPEC_LANG.txt')
$N = $src.Count

function Esc([string]$s) {
  $s = $s -replace '\\','\\'
  $s = $s -replace '\{','\{'
  $s = $s -replace '\}','\}'
  return $s
}

$secKeys = @{
  1  = 'BCPL presentation;Martin Richards;Cambridge;CPL;TRIPOS;Xerox Alto;langage B;Ken Thompson'
  2  = 'BCPL structure programme;START;LET;BE;GET;LIBHDR'
  3  = 'BCPL structure lexicale;identificateurs;mots reserves;litteraux;commentaires;echappement;asterisque'
  4  = 'BCPL types donnees;word;mot machine;typeless;vecteur;chaine;booleen;TRUE;FALSE'
  5  = 'BCPL declarations;MANIFEST;GLOBAL;STATIC;LET;EXTERNAL;TABLE;VEC'
  6  = 'BCPL operateurs;arithmetique;relationnel;logique;bit a bit;subscript;LV;adresse;conditionnel;affectation'
  7  = 'BCPL structures controle;IF;TEST;UNLESS;SWITCHON;CASE;WHILE;UNTIL;FOR;REPEAT;BREAK;LOOP;VALOF;RESULTIS;GOTO'
  8  = 'BCPL procedures;fonctions;LET;BE;VALOF;RESULTIS;AND;mutual recursion;parametres;reference'
  9  = 'BCPL vecteurs;tableaux;VEC;TABLE;subscript;GETVEC;FREEVEC;multidimensionnel'
  10 = 'BCPL chaines;caracteres;PACKSTRING;UNPACKSTRING;COMPSTRING;COPYSTRING;CONCAT;WRITES;WRITEF'
  11 = 'BCPL entrees sorties;WRITES;WRITEN;WRITEF;WRCH;RDCH;READN;FINDINPUT;FINDOUTPUT'
  12 = 'BCPL sections;compilation separee;GET;SECTION;EXTERNAL;GLOBAL'
  13 = 'BCPL OCODE;INTCODE;code intermediaire;machine virtuelle pile;portable'
  14 = 'BCPL exemples;Hello World;Factorielle;Fibonacci;tri insertion;recherche chaine'
  15 = 'BCPL compilateurs projet;BCPL86.PAS'
  16 = 'BCPL convertisseurs;ASC2BCPL.PAS;ADA2BCPL.PAS;PAS2BCPL.PAS;transpileur'
  17 = 'BCPL influence historique;langage B;langage C;Ken Thompson;Dennis Ritchie;Brian Kernighan;TRIPOS;Xerox Alto'
  18 = 'BCPL references;bibliographie;Martin Richards;Whitby-Strevens;BCPL Reference Manual;Cintsys'
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
    $prev = 'IDH_BCPL_{0:D2}' -f ($cur - 1)
    $parts += '{\uldb << Precedent}{\v ' + $prev + '}'
  }
  if ($cur -lt $total) {
    $nxt = 'IDH_BCPL_{0:D2}' -f ($cur + 1)
    $parts += '{\uldb Suivant >>}{\v ' + $nxt + '}'
  }
  if ($cur -ne 1) {
    $parts += '{\uldb Table des matieres}{\v IDH_BCPL_01}'
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
    $id = 'IDH_BCPL_{0:D2}' -f $n
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
    $id = 'IDH_BCPL_{0:D2}' -f $secNum
    [void]$sb.AppendLine('{\footnote # ' + $id + '}')
    [void]$sb.AppendLine('{\footnote ' + [char]36 + ' BCPL - ' + (Esc $secTitle) + '}')
    $kw = $secKeys[$secNum]
    if (-not $kw) { $kw = 'BCPL' }
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

$outPath = Join-Path $PSScriptRoot 'BCPL.RTF'
[System.IO.File]::WriteAllText($outPath, $sb.ToString(), [System.Text.Encoding]::ASCII)
Write-Host ("Genere: " + $outPath + " (" + (Get-Item $outPath).Length + " octets)")
