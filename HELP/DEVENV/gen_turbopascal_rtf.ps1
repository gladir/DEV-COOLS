# Genere les RTF de la section Turbo Pascal et toutes ses unites
# a partir des fichiers DOC\TURBOPASCAL_*.txt
#
# 14 fichiers produits :
#   TURBOPASCAL.RTF   (depuis TURBOPASCAL_SPEC_LANG.txt) - vue d ensemble
#   TPSYSTEM.RTF      (unite System)
#   TPCRT.RTF         (unite Crt)
#   TPDOS.RTF         (unite Dos)
#   TPGRAPH.RTF       (unite Graph)
#   TPGRAPH3.RTF      (unite Graph3)
#   TPOVERLAY.RTF     (unite Overlay)
#   TPOBJECTS.RTF     (programmation objet)
#   TPPRINTER.RTF     (unite Printer)
#   TPSTRING.RTF      (type String)
#   TPSTRINGS.RTF     (unite Strings PChar)
#   TPMEMORY.RTF      (gestion memoire)
#   TPWINDOS.RTF      (unite WinDos)
#   TPTURBO3.RTF      (compatibilite TP3)

$ErrorActionPreference = 'Stop'

# Configuration : nom doc, prefixe ID, fichier RTF, titre, plage MAP
$units = @(
  @{Doc='TURBOPASCAL_SPEC_LANG'; Pfx='TP';       Rtf='TURBOPASCAL.RTF'; Title='Turbo Pascal';        Base=5400; Label='vue d ensemble'},
  @{Doc='TURBOPASCAL_SYSTEM';    Pfx='TPSYS';    Rtf='TPSYSTEM.RTF';   Title='Unite System';         Base=5500; Label='unite System'},
  @{Doc='TURBOPASCAL_CRT';       Pfx='TPCRT';    Rtf='TPCRT.RTF';      Title='Unite Crt';            Base=5600; Label='unite Crt'},
  @{Doc='TURBOPASCAL_DOS';       Pfx='TPDOS';    Rtf='TPDOS.RTF';      Title='Unite Dos';            Base=5700; Label='unite Dos'},
  @{Doc='TURBOPASCAL_GRAPH';     Pfx='TPGRAPH';  Rtf='TPGRAPH.RTF';    Title='Unite Graph (BGI)';    Base=5800; Label='unite Graph (BGI)'},
  @{Doc='TURBOPASCAL_GRAPH3';    Pfx='TPGR3';    Rtf='TPGRAPH3.RTF';   Title='Unite Graph3 (TP 3)';  Base=5900; Label='unite Graph3'},
  @{Doc='TURBOPASCAL_OVERLAY';   Pfx='TPOVL';    Rtf='TPOVERLAY.RTF';  Title='Unite Overlay';        Base=6000; Label='unite Overlay'},
  @{Doc='TURBOPASCAL_OBJECTS';   Pfx='TPOBJ';    Rtf='TPOBJECTS.RTF';  Title='Programmation Objet';  Base=6100; Label='programmation objet'},
  @{Doc='TURBOPASCAL_PRINTER';   Pfx='TPPRT';    Rtf='TPPRINTER.RTF';  Title='Unite Printer';        Base=6200; Label='unite Printer'},
  @{Doc='TURBOPASCAL_STRING';    Pfx='TPSTR';    Rtf='TPSTRING.RTF';   Title='Type String';          Base=6300; Label='type String'},
  @{Doc='TURBOPASCAL_STRINGS';   Pfx='TPSTRS';   Rtf='TPSTRINGS.RTF';  Title='Unite Strings (PChar)';Base=6400; Label='unite Strings'},
  @{Doc='TURBOPASCAL_MEMORY';    Pfx='TPMEM';    Rtf='TPMEMORY.RTF';   Title='Gestion Memoire';      Base=6500; Label='gestion memoire'},
  @{Doc='TURBOPASCAL_WINDOS';    Pfx='TPWIN';    Rtf='TPWINDOS.RTF';   Title='Unite WinDos';         Base=6600; Label='unite WinDos'},
  @{Doc='TURBOPASCAL_TURBO3';    Pfx='TPT3';     Rtf='TPTURBO3.RTF';   Title='Compatibilite TP3';    Base=6700; Label='unite Turbo3'}
)

# Patrons de liens croises : regex -> ID cible
# Les patrons sont appliques aux lignes de prose (pas aux blocs code indentes)
$crossLinks = @(
  @{Pat='TURBOPASCAL_SPEC_LANG\.txt'; Id='IDH_TP_01';      Lbl='Turbo Pascal'},
  @{Pat='TURBOPASCAL_SYSTEM\.txt';    Id='IDH_TPSYS_01';   Lbl='unite System'},
  @{Pat='TURBOPASCAL_CRT\.txt';       Id='IDH_TPCRT_01';   Lbl='unite Crt'},
  @{Pat='TURBOPASCAL_DOS\.txt';       Id='IDH_TPDOS_01';   Lbl='unite Dos'},
  @{Pat='TURBOPASCAL_GRAPH\.txt';     Id='IDH_TPGRAPH_01'; Lbl='unite Graph'},
  @{Pat='TURBOPASCAL_GRAPH3\.txt';    Id='IDH_TPGR3_01';   Lbl='unite Graph3'},
  @{Pat='TURBOPASCAL_OVERLAY\.txt';   Id='IDH_TPOVL_01';   Lbl='unite Overlay'},
  @{Pat='TURBOPASCAL_OBJECTS\.txt';   Id='IDH_TPOBJ_01';   Lbl='programmation objet'},
  @{Pat='TURBOPASCAL_PRINTER\.txt';   Id='IDH_TPPRT_01';   Lbl='unite Printer'},
  @{Pat='TURBOPASCAL_STRINGS\.txt';   Id='IDH_TPSTRS_01';  Lbl='unite Strings'},
  @{Pat='TURBOPASCAL_STRING\.txt';    Id='IDH_TPSTR_01';   Lbl='type String'},
  @{Pat='TURBOPASCAL_MEMORY\.txt';    Id='IDH_TPMEM_01';   Lbl='gestion memoire'},
  @{Pat='TURBOPASCAL_WINDOS\.txt';    Id='IDH_TPWIN_01';   Lbl='unite WinDos'},
  @{Pat='TURBOPASCAL_TURBO3\.txt';    Id='IDH_TPT3_01';    Lbl='compatibilite TP3'}
)

function Esc([string]$s) {
  $s = $s -replace '\\','\\'
  $s = $s -replace '\{','\{'
  $s = $s -replace '\}','\}'
  return $s
}

# Emet une ligne de prose avec substitution de liens croises
# Renvoie le RTF (sans \par final)
function ProcessProseLine([string]$line, [string]$selfPfx) {
  # Trouver toutes les occurrences (pat, start, length, id, lbl)
  $hits = @()
  foreach ($cl in $crossLinks) {
    if ($cl.Id -like "IDH_${selfPfx}_*") { continue }  # pas d auto-lien
    foreach ($m in [regex]::Matches($line, $cl.Pat)) {
      $hits += @{Start=$m.Index; Len=$m.Length; Id=$cl.Id; Text=$m.Value}
    }
  }
  if ($hits.Count -eq 0) { return (Esc $line) }
  # Trier par Start
  $hits = $hits | Sort-Object Start
  # Eliminer chevauchements (garde le premier)
  $filtered = @()
  $lastEnd = -1
  foreach ($h in $hits) {
    if ($h.Start -ge $lastEnd) {
      $filtered += $h
      $lastEnd = $h.Start + $h.Len
    }
  }
  # Construire le RTF
  $sb = New-Object System.Text.StringBuilder
  $cur = 0
  foreach ($h in $filtered) {
    if ($h.Start -gt $cur) {
      [void]$sb.Append((Esc $line.Substring($cur, $h.Start - $cur)))
    }
    [void]$sb.Append('{\uldb ')
    [void]$sb.Append((Esc $h.Text))
    [void]$sb.Append('}{\v ')
    [void]$sb.Append($h.Id)
    [void]$sb.Append('}')
    $cur = $h.Start + $h.Len
  }
  if ($cur -lt $line.Length) {
    [void]$sb.Append((Esc $line.Substring($cur)))
  }
  return $sb.ToString()
}

function EmitNav($sb, $pfx, [int]$cur, [int]$total, [bool]$isMain) {
  [void]$sb.AppendLine('\par')
  $parts = @()
  if ($cur -gt 1) {
    $prev = ('IDH_{0}_{1:D2}' -f $pfx, ($cur - 1))
    $parts += '{\uldb << Precedent}{\v ' + $prev + '}'
  }
  if ($cur -lt $total) {
    $nxt = ('IDH_{0}_{1:D2}' -f $pfx, ($cur + 1))
    $parts += '{\uldb Suivant >>}{\v ' + $nxt + '}'
  }
  if ($cur -ne 1) {
    $parts += '{\uldb Sommaire}{\v ' + ('IDH_{0}_01' -f $pfx) + '}'
  }
  if (-not $isMain) {
    $parts += '{\uldb Turbo Pascal}{\v IDH_TP_01}'
  }
  $parts += '{\uldb Retour aux langages}{\v IDH_LANGAGES}'
  [void]$sb.AppendLine(($parts -join '     ') + '\par')
}

function EmitTOC($sb, $titles, [int]$total, $pfx, [bool]$isMain) {
  [void]$sb.AppendLine('\par')
  [void]$sb.AppendLine('\b Sections suivantes : \b0\par')
  [void]$sb.AppendLine('\par')
  for ($n = 2; $n -le $total; $n++) {
    if (-not $titles.ContainsKey($n)) { continue }
    $id = 'IDH_{0}_{1:D2}' -f $pfx, $n
    $lbl = ('{0,2}. {1}' -f $n, $titles[$n])
    [void]$sb.AppendLine('{\f1 ' + (Esc $lbl) + '}     {\uldb [Aller]}{\v ' + $id + '}\par')
  }
  if ($isMain) {
    # Sur la page sommaire principale, ajouter les liens vers les unites
    [void]$sb.AppendLine('\par')
    [void]$sb.AppendLine('\b Unites et sujets connexes : \b0\par')
    [void]$sb.AppendLine('\par')
    foreach ($u in $units) {
      if ($u.Pfx -eq 'TP') { continue }
      $uid = 'IDH_{0}_01' -f $u.Pfx
      $lbl = '   {0,-28} ({1})' -f $u.Title, $u.Doc
      [void]$sb.AppendLine('{\f1 ' + (Esc $lbl) + '}     {\uldb [Aller]}{\v ' + $uid + '}\par')
    }
  }
}

function GenerateRtfForUnit($unit) {
  $docPath = Join-Path $PSScriptRoot ('..\..\DOC\' + $unit.Doc + '.txt')
  $src = Get-Content $docPath
  $N = $src.Count
  $pfx = $unit.Pfx
  $isMain = ($pfx -eq 'TP')

  # Pre-scan : titres des sections
  $titles = @{}
  for ($k = 1; $k -lt $N - 1; $k++) {
    if ($src[$k-1] -match '^={3,}\s*$' -and
        $src[$k+1] -match '^={3,}\s*$' -and
        $src[$k]   -match '^\s*(\d+)\.\s+(.+?)\s*$') {
      $titles[[int]$Matches[1]] = $Matches[2].Trim()
    }
  }
  $totalSecs = ($titles.Keys | Measure-Object -Maximum).Maximum

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
        if ($curSec -eq 1) { EmitTOC $sb $titles $totalSecs $pfx $isMain }
        EmitNav $sb $pfx $curSec $totalSecs $isMain
        [void]$sb.AppendLine('\page')
        [void]$sb.AppendLine('')
      }
      $id = 'IDH_{0}_{1:D2}' -f $pfx, $secNum
      [void]$sb.AppendLine('{\footnote # ' + $id + '}')
      [void]$sb.AppendLine('{\footnote ' + [char]36 + ' ' + (Esc $unit.Title) + ' - ' + (Esc $secTitle) + '}')
      $kw = ('Turbo Pascal;{0};{1}' -f $unit.Title, $secTitle)
      [void]$sb.AppendLine('{\footnote K ' + (Esc $kw) + '}')
      [void]$sb.AppendLine('\b\fs24 ' + (Esc $secTitle) + ' \b0\fs20\par')
      [void]$sb.AppendLine('\par')
      $i += 3
      while ($i -lt $N -and $src[$i].Trim() -eq '') { $i++ }
      $inTopic = $true
      $curSec = $secNum
      continue
    }

    if (-not $inTopic) { $i++; continue }

    # Sous-section "N.N Titre" suivie d une ligne de tirets
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
      # Bloc code/indente : Courier, sans substitution de liens
      $txt = $line -replace "`t", '    '
      [void]$sb.AppendLine('{\f1 ' + (Esc $txt) + '}\par')
    } else {
      # Prose : avec substitution de liens
      [void]$sb.AppendLine((ProcessProseLine $line $pfx) + '\par')
    }
    $i++
  }

  [void]$sb.AppendLine('')
  if ($inTopic) { EmitNav $sb $pfx $curSec $totalSecs $isMain }
  [void]$sb.AppendLine('}')

  $outPath = Join-Path $PSScriptRoot $unit.Rtf
  [System.IO.File]::WriteAllText($outPath, $sb.ToString(), [System.Text.Encoding]::ASCII)
  $sz = (Get-Item $outPath).Length
  Write-Host ("  {0,-18} -> {1,3} sections, {2} octets" -f $unit.Rtf, $totalSecs, $sz)
  return @{Pfx=$pfx; Total=$totalSecs; Base=$unit.Base}
}

# Boucle de generation
Write-Host "Generation RTF Turbo Pascal :"
$results = @()
foreach ($u in $units) {
  $results += (GenerateRtfForUnit $u)
}

# Generation d un snippet MAP a inserer dans DEVENV.HPJ
$mapPath = Join-Path $PSScriptRoot 'turbopascal_map.inc'
$ms = New-Object System.Text.StringBuilder
[void]$ms.AppendLine('; --- Turbo Pascal et unites (genere automatiquement) ---')
foreach ($r in $results) {
  for ($n = 1; $n -le $r.Total; $n++) {
    $idName = 'IDH_{0}_{1:D2}' -f $r.Pfx, $n
    $val = $r.Base + $n
    [void]$ms.AppendLine(('{0,-20}= {1}' -f $idName, $val))
  }
}
[System.IO.File]::WriteAllText($mapPath, $ms.ToString(), [System.Text.Encoding]::ASCII)
Write-Host ("Snippet MAP : " + $mapPath)
