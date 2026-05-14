# Genere HELP\DEVENV\C.RTF a partir de DOC\C_SPEC_LANG.txt
# Format des sections : "N. TITRE" (non indente) encadre par deux lignes "=====".

$src = Get-Content (Join-Path $PSScriptRoot '..\..\DOC\C_SPEC_LANG.txt')
$N = $src.Count

function Esc([string]$s) {
  $s = $s -replace '\\','\\'
  $s = $s -replace '\{','\{'
  $s = $s -replace '\}','\}'
  return $s
}

$secKeys = @{
  1  = 'C presentation;ANSI;C89;C90;K&R;langage C'
  2  = 'C structure programme;main;unite de traduction;translation unit'
  3  = 'C structure lexicale;identificateurs;mots reserves;litteraux;commentaires'
  4  = 'C types donnees;char;int;short;long;float;double;void;qualificateurs;const;volatile'
  5  = 'C declarations variables;auto;static;extern;register'
  6  = 'C operateurs;expressions;arithmetique;relationnel;logique;bit a bit;precedence;sizeof'
  7  = 'C structures controle;if;else;switch;while;do;for;break;continue;goto;return'
  8  = 'C fonctions;prototype;parametres;varargs;recursivite'
  9  = 'C tableaux;array;dimensions;initialisation'
  10 = 'C pointeurs;NULL;arithmetique pointeurs;malloc;free;reference'
  11 = 'C structures;union;enum;enumeration;typedef;champs de bits'
  12 = 'C preprocesseur;define;include;ifdef;macros;__FILE__;__LINE__'
  13 = 'C chaines;string;strlen;strcpy;strcmp;strcat;memcpy'
  14 = 'C entrees sorties;printf;scanf;fopen;fclose;fgetc;fputc;FILE'
  15 = 'C bibliotheque standard;ANSI;stdio.h;stdlib.h;string.h;math.h'
  16 = 'C allocation dynamique;malloc;calloc;realloc;free;memoire'
  17 = 'C portee;duree de vie;liaison;linkage;static;extern'
  18 = 'C entrees sorties POSIX;open;close;read;write;lseek;fd'
  19 = 'C assertions;errno;exit;abort;atexit;EXIT_SUCCESS;EXIT_FAILURE'
  20 = 'C evolutions;C99;C11;C17;C23;standard'
  21 = 'C compilation;lien;cpp;cc;as;ld;objet;executable'
  22 = 'C compilateurs projet;C.PAS;CC8086.PAS;CC09.PAS;CC6502.PAS;CCW32.PAS;CCJASMIN.PAS'
  23 = 'C exemple complet;Fibonacci;programme exemple'
  24 = 'C tableau fonctions;liste fonctions standard;en-tetes'
  25 = 'C definitions fonctions;documentation fonctions;reference fonctions'
  26 = 'C references;bibliographie;K&R;Kernighan;Ritchie;ISO 9899'
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
    $prev = 'IDH_C_{0:D2}' -f ($cur - 1)
    $parts += '{\uldb << Precedent}{\v ' + $prev + '}'
  }
  if ($cur -lt $total) {
    $nxt = 'IDH_C_{0:D2}' -f ($cur + 1)
    $parts += '{\uldb Suivant >>}{\v ' + $nxt + '}'
  }
  if ($cur -ne 1) {
    $parts += '{\uldb Table des matieres}{\v IDH_C_01}'
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
    $id = 'IDH_C_{0:D2}' -f $n
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
    $id = 'IDH_C_{0:D2}' -f $secNum
    [void]$sb.AppendLine('{\footnote # ' + $id + '}')
    [void]$sb.AppendLine('{\footnote ' + [char]36 + ' C - ' + (Esc $secTitle) + '}')
    $kw = $secKeys[$secNum]
    if (-not $kw) { $kw = 'C' }
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

$outPath = Join-Path $PSScriptRoot 'C.RTF'
[System.IO.File]::WriteAllText($outPath, $sb.ToString(), [System.Text.Encoding]::ASCII)
Write-Host ("Genere: " + $outPath + " (" + (Get-Item $outPath).Length + " octets)")
