# Genere HELP\DEVENV\ABAP.RTF a partir de DOC\ABAP_SPEC_LANG.txt
# Chaque section "=== N. TITRE ===" devient un topic IDH_ABAP_NN

$src = Get-Content (Join-Path $PSScriptRoot '..\..\DOC\ABAP_SPEC_LANG.txt')
$N = $src.Count

function Esc([string]$s) {
  $s = $s -replace '\\','\\'
  $s = $s -replace '\{','\{'
  $s = $s -replace '\}','\}'
  return $s
}

$secKeys = @{
  1  = 'ABAP structure;REPORT;PROGRAM;INCLUDE'
  2  = 'ABAP commentaires'
  3  = 'ABAP types;DATA;TYPES;CHAR;INT;PACKED;STRING'
  4  = 'ABAP declarations;DATA;TYPES;CONSTANTS;FIELD-SYMBOLS'
  5  = 'ABAP operateurs'
  6  = 'ABAP expressions;affectations;COMPUTE;MOVE'
  7  = 'ABAP controle;IF;CASE;DO;WHILE;LOOP;EXIT;CONTINUE'
  8  = 'ABAP FORM;PERFORM;ENDFORM;sous-programmes'
  9  = 'ABAP FUNCTION;modules de fonction'
  10 = 'ABAP IO;WRITE;READ;OPEN DATASET'
  11 = 'ABAP chaines;CONCATENATE;SPLIT;SHIFT;REPLACE;STRLEN'
  12 = 'ABAP tables internes;APPEND;READ TABLE;LOOP AT'
  13 = 'ABAP base de donnees;SELECT;INSERT;UPDATE;DELETE;OpenSQL'
  14 = 'ABAP evenements;INITIALIZATION;START-OF-SELECTION'
  15 = 'ABAP ecran de selection;PARAMETERS;SELECT-OPTIONS'
  16 = 'ABAP exceptions;TRY;CATCH;RAISE'
  17 = 'ABAP variables systeme;sy-subrc;sy-datum;sy-uname'
  18 = 'ABAP fonctions integrees;STRLEN;ABS;ROUND;SUBSTRING'
  19 = 'ABAP mots-cles reserves'
  20 = 'ABAP grammaire BNF'
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('{\rtf1\ansi\deff0')
[void]$sb.AppendLine('{\fonttbl{\f0\fswiss Helvetica;}{\f1\fmodern Courier New;}}')
[void]$sb.AppendLine('')

$i = 0
$inTopic = $false
$pendingPar = $false   # evite \par redondants apres un titre

while ($i -lt $N) {
  $line = $src[$i]

  # Detection en-tete de section: "====" / "N. TITRE" / "===="
  if ($line -match '^={3,}\s*$' -and $i+2 -lt $N -and $src[$i+2] -match '^={3,}\s*$' -and $src[$i+1] -match '^(\d+)\.\s+(.+?)\s*$') {
    $secNum = [int]$Matches[1]
    $secTitle = $Matches[2].Trim()
    if ($inTopic) {
      [void]$sb.AppendLine('\page')
      [void]$sb.AppendLine('')
    }
    $id = 'IDH_ABAP_{0:D2}' -f $secNum
    [void]$sb.AppendLine('{\footnote # ' + $id + '}')
    [void]$sb.AppendLine('{\footnote ' + [char]36 + ' ABAP - ' + (Esc $secTitle) + '}')
    $kw = $secKeys[$secNum]
    if (-not $kw) { $kw = 'ABAP' }
    [void]$sb.AppendLine('{\footnote K ' + $kw + '}')
    [void]$sb.AppendLine('\b\fs24 ' + (Esc $secTitle) + ' \b0\fs20\par')
    [void]$sb.AppendLine('\par')
    $i += 3
    while ($i -lt $N -and $src[$i].Trim() -eq '') { $i++ }
    $inTopic = $true
    $pendingPar = $false
    continue
  }

  if (-not $inTopic) { $i++; continue }

  if ($line -match '^FIN DU DOCUMENT') { break }

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
    $i++
    continue
  }

  # Ligne vide
  if ($line.Trim() -eq '') {
    [void]$sb.AppendLine('\par')
    $i++
    continue
  }

  # Ligne indentee : Courier (preserve alignement)
  if ($line -match '^\s+\S') {
    # Convertir tabs en espaces et remplacer espaces consecutifs par \~ (non-breaking)
    $txt = $line -replace "`t", '    '
    $txt = Esc $txt
    [void]$sb.AppendLine('{\f1 ' + $txt + '}\par')
  } else {
    [void]$sb.AppendLine((Esc $line) + '\par')
  }
  $i++
}

[void]$sb.AppendLine('')
[void]$sb.AppendLine('}')

$outPath = Join-Path $PSScriptRoot 'ABAP.RTF'
[System.IO.File]::WriteAllText($outPath, $sb.ToString(), [System.Text.Encoding]::ASCII)
Write-Host ("Genere: " + $outPath + " (" + (Get-Item $outPath).Length + " octets)")
