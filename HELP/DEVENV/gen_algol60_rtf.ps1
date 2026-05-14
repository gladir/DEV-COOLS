# Genere HELP\DEVENV\ALGOL60.RTF a partir de DOC\ALGOL60_SPEC_LANG.txt
# Format des sections : "N. TITRE" suivi UNIQUEMENT d'une ligne "====" (souligne).

$src = Get-Content (Join-Path $PSScriptRoot '..\..\DOC\ALGOL60_SPEC_LANG.txt')
$N = $src.Count

function Esc([string]$s) {
  $s = $s -replace '\\','\\'
  $s = $s -replace '\{','\{'
  $s = $s -replace '\}','\}'
  return $s
}

$secKeys = @{
  1  = 'Algol 60 introduction;Naur;Revised Report'
  2  = 'Algol 60 lexical;identificateurs;litteraux;mots-cles'
  3  = 'Algol 60 types;integer;real;Boolean'
  4  = 'Algol 60 declarations;own;array;procedure;switch'
  5  = 'Algol 60 expressions;arithmetiques;booleennes;conditionnelles'
  6  = 'Algol 60 instructions;assignment;goto;if;for;while;step;until'
  7  = 'Algol 60 procedures;value;name;call by name;call by value;recursion'
  8  = 'Algol 60 tableaux;array;bornes;dimensions'
  9  = 'Algol 60 blocs;portee;scope;begin;end'
  10 = 'Algol 60 entrees sorties;read;write;input;output'
  11 = 'Algol 60 structure programme;main;source'
  12 = 'Algol 60 differences Algol 58;evolution'
  13 = 'Algol 60 limitations;compilateur'
  14 = 'Algol 60 references;bibliographie;BNF'
}

$LangId  = 'ALGOL60'
$LangTit = 'Algol 60'

# Pre-pass : collecte les titres
$titles = @{}
for ($k = 0; $k -lt $N - 1; $k++) {
  if ($src[$k+1] -match '^={3,}\s*$' -and
      ($k -eq 0 -or $src[$k-1] -notmatch '^={3,}\s*$') -and
      $src[$k]   -match '^\s*(\d+)\.\s+([A-Z].+?)\s*$') {
    $tNum = [int]$Matches[1]; $tTit = $Matches[2].Trim()
    $titles[$tNum] = $tTit
  }
}
$totalSecs = ($titles.Keys | Measure-Object -Maximum).Maximum

function EmitNav($sb, [int]$cur, [int]$total) {
  [void]$sb.AppendLine('\par')
  $parts = @()
  if ($cur -gt 1) {
    $prev = 'IDH_' + $LangId + '_{0:D2}' -f ($cur - 1)
    $parts += '{\uldb << Precedent}{\v ' + $prev + '}'
  }
  if ($cur -lt $total) {
    $nxt = 'IDH_' + $LangId + '_{0:D2}' -f ($cur + 1)
    $parts += '{\uldb Suivant >>}{\v ' + $nxt + '}'
  }
  if ($cur -ne 1) {
    $parts += '{\uldb Table des matieres}{\v IDH_' + $LangId + '_01}'
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
    $id = 'IDH_' + $LangId + '_{0:D2}' -f $n
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

  # Detection en-tete : "N. TITRE" sur i, "===" sur i+1, ligne i-1 non "===".
  if ($i+1 -lt $N -and
      $src[$i+1] -match '^={3,}\s*$' -and
      ($i -eq 0 -or $src[$i-1] -notmatch '^={3,}\s*$') -and
      $line -match '^\s*(\d+)\.\s+([A-Z].+?)\s*$') {
    $secNum = [int]$Matches[1]
    $secTitle = $Matches[2].Trim()
    if ($inTopic) {
      if ($curSec -eq 1) { EmitTOC $sb $titles $totalSecs }
      EmitNav $sb $curSec $totalSecs
      [void]$sb.AppendLine('\page')
      [void]$sb.AppendLine('')
    }
    $id = 'IDH_' + $LangId + '_{0:D2}' -f $secNum
    [void]$sb.AppendLine('{\footnote # ' + $id + '}')
    [void]$sb.AppendLine('{\footnote ' + [char]36 + ' ' + $LangTit + ' - ' + (Esc $secTitle) + '}')
    $kw = $secKeys[$secNum]
    if (-not $kw) { $kw = $LangTit }
    [void]$sb.AppendLine('{\footnote K ' + $kw + '}')
    [void]$sb.AppendLine('\b\fs24 ' + (Esc $secTitle) + ' \b0\fs20\par')
    [void]$sb.AppendLine('\par')
    $i += 2
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

$outPath = Join-Path $PSScriptRoot 'ALGOL60.RTF'
[System.IO.File]::WriteAllText($outPath, $sb.ToString(), [System.Text.Encoding]::ASCII)
Write-Host ("Genere: " + $outPath + " (" + (Get-Item $outPath).Length + " octets)")
