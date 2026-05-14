# Genere HELP\DEVENV\ALGOL68.RTF a partir de DOC\ALGOL68_SPEC_LANG.txt
# Format des sections : "N. TITRE" (non indente) encadre par deux lignes "=====".

$src = Get-Content (Join-Path $PSScriptRoot '..\..\DOC\ALGOL68_SPEC_LANG.txt')
$N = $src.Count

function Esc([string]$s) {
  $s = $s -replace '\\','\\'
  $s = $s -replace '\{','\{'
  $s = $s -replace '\}','\}'
  return $s
}

$secKeys = @{
  1  = 'Algol 68 structure programme;begin;end;source;IFIP'
  2  = 'Algol 68 commentaires;pragmats;co;comment;pr'
  3  = 'Algol 68 lexical;identificateurs;litteraux;casse'
  4  = 'Algol 68 denotations;litteraux;int;real;bool;string;format'
  5  = 'Algol 68 modes;types;INT;REAL;BOOL;CHAR;STRING;VOID'
  6  = 'Algol 68 systeme modes;coercitions;deproceduring;dereferencing;widening'
  7  = 'Algol 68 operateurs;priorites;monadiques;dyadiques'
  8  = 'Algol 68 declarations identite;variable;LOC;HEAP'
  9  = 'Algol 68 expressions;formules;unitaires'
  10 = 'Algol 68 clauses fermees;serie;BEGIN;END'
  11 = 'Algol 68 conditionnelles;IF;CASE;THEN;ELSE;FI;ESAC'
  12 = 'Algol 68 boucles;FOR;FROM;TO;BY;WHILE;DO;OD'
  13 = 'Algol 68 structures;STRUCT;champs'
  14 = 'Algol 68 references;affectations;REF;pointeurs'
  15 = 'Algol 68 tableaux;ROW;tranches;indexation;bornes'
  16 = 'Algol 68 procedures;PROC;parametres;retour'
  17 = 'Algol 68 operateurs definis;OP;PRIO;surcharge'
  18 = 'Algol 68 unions;UNION;CASE conformite'
  19 = 'Algol 68 collaterales;paralleles;PAR'
  20 = 'Algol 68 transput;entrees;sorties;read;print;put;get'
  21 = 'Algol 68 symboles;portee;scope;identification'
  22 = 'Algol 68 runtime;minimal;bibliotheque'
  23 = 'Algol 68 mots reserves;bold words;keywords'
  24 = 'Algol 68 grammaire BNF;syntaxe;Van Wijngaarden'
}

# Pre-pass : collecte les titres
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
    $prev = 'IDH_ALGOL68_{0:D2}' -f ($cur - 1)
    $parts += '{\uldb << Precedent}{\v ' + $prev + '}'
  }
  if ($cur -lt $total) {
    $nxt = 'IDH_ALGOL68_{0:D2}' -f ($cur + 1)
    $parts += '{\uldb Suivant >>}{\v ' + $nxt + '}'
  }
  if ($cur -ne 1) {
    $parts += '{\uldb Table des matieres}{\v IDH_ALGOL68_01}'
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
    $id = 'IDH_ALGOL68_{0:D2}' -f $n
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

  # Detection en-tete : "===" sur ligne i, "N. TITRE" sur i+1, "===" sur i+2.
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
    $id = 'IDH_ALGOL68_{0:D2}' -f $secNum
    [void]$sb.AppendLine('{\footnote # ' + $id + '}')
    [void]$sb.AppendLine('{\footnote ' + [char]36 + ' Algol 68 - ' + (Esc $secTitle) + '}')
    $kw = $secKeys[$secNum]
    if (-not $kw) { $kw = 'Algol 68' }
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

  # Sous-titre "N.M Titre" suivi de "-----"
  if ($i+1 -lt $N -and $src[$i+1] -match '^\s*-{3,}\s*$' -and
      $line -match '^\s*(\d+\.\d+)\s+(.+?)\s*$') {
    [void]$sb.AppendLine('\par')
    [void]$sb.AppendLine('\b ' + (Esc $line.Trim()) + ' \b0\par')
    [void]$sb.AppendLine('\par')
    $i += 2
    while ($i -lt $N -and $src[$i].Trim() -eq '') { $i++ }
    continue
  }

  # Lignes de soulignement seules
  if ($line -match '^\s*-{3,}\s*$' -or $line -match '^\s*={3,}\s*$') {
    $i++; continue
  }

  # Ligne vide
  if ($line.Trim() -eq '') {
    [void]$sb.AppendLine('\par')
    $i++; continue
  }

  # Ligne indentee : Courier
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

$outPath = Join-Path $PSScriptRoot 'ALGOL68.RTF'
[System.IO.File]::WriteAllText($outPath, $sb.ToString(), [System.Text.Encoding]::ASCII)
Write-Host ("Genere: " + $outPath + " (" + (Get-Item $outPath).Length + " octets)")
