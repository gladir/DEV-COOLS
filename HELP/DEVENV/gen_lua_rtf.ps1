# Genere HELP\DEVENV\LUA.RTF a partir de DOC\LUA_SPEC_LANG.txt
# Format des sections : "N. TITRE" suivi de "======" sur la ligne suivante.

$src = Get-Content (Join-Path $PSScriptRoot '..\..\DOC\LUA_SPEC_LANG.txt')
$N = $src.Count

function Esc([string]$s) {
  $s = $s -replace '\\','\\'
  $s = $s -replace '\{','\{'
  $s = $s -replace '\}','\}'
  return $s
}

$secKeys = @{
  1  = 'Lua introduction;histoire;Ierusalimschy;5.3'
  2  = 'Lua lexical;commentaires;identificateurs;litteraux;chaines'
  3  = 'Lua types;valeurs;nil;boolean;number;string;table;function'
  4  = 'Lua variables;portee;local;global;scope'
  5  = 'Lua operateurs;arithmetiques;comparaison;logiques;concatenation'
  6  = 'Lua instructions;if;while;for;repeat;goto;break;return'
  7  = 'Lua fonctions;function;closure;varargs;multiple return'
  8  = 'Lua tables;array;dictionary;constructor'
  9  = 'Lua metatables;__index;__newindex;__add;metamethods'
  10 = 'Lua bibliotheques standard;math;string;table;io;os'
  11 = 'Lua erreurs;pcall;error;xpcall;assert'
  12 = 'Lua limites;implementation;LUA86;sous-ensemble'
  13 = 'Lua cible compilation;8086;DOS;assembleur;backend'
}

# Pre-pass : collecte les titres de toutes les sections (pour la TOC)
# Format LUA : "N. TITRE" seul sur une ligne (PAS de ligne "====" en dessous).
$titles = @{}
for ($k = 0; $k -lt $N; $k++) {
  if ($src[$k] -match '^(\d+)\.\s+([A-Z].*?)\s*$') {
    $tNum = [int]$Matches[1]; $tTit = $Matches[2].Trim()
    $titles[$tNum] = $tTit
  }
}
$totalSecs = ($titles.Keys | Measure-Object -Maximum).Maximum

function EmitNav($sb, [int]$cur, [int]$total) {
  [void]$sb.AppendLine('\par')
  $parts = @()
  if ($cur -gt 1) {
    $prev = 'IDH_LUA_{0:D2}' -f ($cur - 1)
    $parts += '{\uldb << Precedent}{\v ' + $prev + '}'
  }
  if ($cur -lt $total) {
    $nxt = 'IDH_LUA_{0:D2}' -f ($cur + 1)
    $parts += '{\uldb Suivant >>}{\v ' + $nxt + '}'
  }
  if ($cur -ne 1) {
    $parts += '{\uldb Table des matieres}{\v IDH_LUA_01}'
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
    $id = 'IDH_LUA_{0:D2}' -f $n
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

  # En-tete LUA : "N. TITRE" seul (pas de separateur ====)
  if ($line -match '^(\d+)\.\s+([A-Z].*?)\s*$') {
    $secNum = [int]$Matches[1]
    $secTitle = $Matches[2].Trim()
    if ($true) {
    if ($inTopic) {
      if ($curSec -eq 1) { EmitTOC $sb $titles $totalSecs }
      EmitNav $sb $curSec $totalSecs
      [void]$sb.AppendLine('\page')
      [void]$sb.AppendLine('')
    }
    $id = 'IDH_LUA_{0:D2}' -f $secNum
    [void]$sb.AppendLine('{\footnote # ' + $id + '}')
    [void]$sb.AppendLine('{\footnote ' + [char]36 + ' Lua - ' + (Esc $secTitle) + '}')
    $kw = $secKeys[$secNum]
    if (-not $kw) { $kw = 'Lua' }
    [void]$sb.AppendLine('{\footnote K ' + $kw + '}')
    [void]$sb.AppendLine('\b\fs24 ' + (Esc $secTitle) + ' \b0\fs20\par')
    [void]$sb.AppendLine('\par')
    $i++
    while ($i -lt $N -and $src[$i].Trim() -eq '') { $i++ }
    $inTopic = $true
    $curSec = $secNum
    continue
    }
  }

  if (-not $inTopic) { $i++; continue }

  # Sous-titre "N.M Titre" suivi de "------"
  if ($line -match '^(\d+\.\d+)\s+(.+?)\s*$' -and $i+1 -lt $N -and $src[$i+1] -match '^-{3,}\s*$') {
    [void]$sb.AppendLine('\par')
    [void]$sb.AppendLine('\b ' + (Esc $line.Trim()) + ' \b0\par')
    [void]$sb.AppendLine('\par')
    $i += 2
    while ($i -lt $N -and $src[$i].Trim() -eq '') { $i++ }
    continue
  }

  # Lignes de soulignement seules
  if ($line -match '^-{3,}\s*$' -or $line -match '^={3,}\s*$') {
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

$outPath = Join-Path $PSScriptRoot 'LUA.RTF'
[System.IO.File]::WriteAllText($outPath, $sb.ToString(), [System.Text.Encoding]::ASCII)
Write-Host ("Genere: " + $outPath + " (" + (Get-Item $outPath).Length + " octets)")


