# Genere HELP\DEVENV\PASCAL.RTF a partir de DOC\PASCAL_SPEC_LANG.txt
# Format des sections : "N. TITRE" (non indente) encadre par deux lignes "=====".

$src = Get-Content (Join-Path $PSScriptRoot '..\..\DOC\PASCAL_SPEC_LANG.txt')
$N = $src.Count

function Esc([string]$s) {
  $s = $s -replace '\\','\\'
  $s = $s -replace '\{','\{'
  $s = $s -replace '\}','\}'
  return $s
}

$secKeys = @{
  1  = 'Pascal presentation;Wirth;ETH;Turbo Pascal;Delphi;Free Pascal;FPC'
  2  = 'Pascal structure programme;program;begin;end;uses'
  3  = 'Pascal structure lexicale;identificateurs;mots reserves;litteraux;commentaires;directives'
  4  = 'Pascal types donnees;Integer;Byte;Word;Char;Boolean;Real;String;set;array;record;pointer;enumeration'
  5  = 'Pascal declarations variables;var;const;constantes typees'
  6  = 'Pascal operateurs;arithmetique;relationnel;logique;ensemble;chaine;div;mod;shl;shr;precedence'
  7  = 'Pascal structures controle;if;then;else;case;while;repeat;until;for;break;continue;exit;halt;goto'
  8  = 'Pascal procedures;fonctions;parametres;var;const;out;overload;forward;recursivite'
  9  = 'Pascal tableaux;array;statiques;dynamiques;SetLength;open array'
  10 = 'Pascal records;enregistrements;with;variant;packed'
  11 = 'Pascal ensembles;set;set of;union;intersection;in'
  12 = 'Pascal chaines;string;ShortString;AnsiString;Length;Copy;Pos;Delete;Insert'
  13 = 'Pascal fichiers;file of;Text;BlockRead;Assign;Reset;Rewrite;Read;Write;Eof'
  14 = 'Pascal unites;unit;interface;implementation;initialization;finalization;uses'
  15 = 'Pascal pointeurs;allocation dynamique;New;Dispose;GetMem;FreeMem;nil;reference'
  16 = 'Pascal objets;object;virtual;constructor;destructor;heritage;Turbo Pascal'
  17 = 'Pascal classes;class;TObject;private;protected;public;published;property;Delphi;FPC'
  18 = 'Pascal exceptions;try;except;finally;raise;Exception;EConvertError'
  19 = 'Pascal generiques;generics;TListe;specialize;Delphi;FPC'
  20 = 'Pascal directives compilation;MODE;IFDEF;DEFINE;UNDEF;I+;R+;H+;Q+'
  21 = 'Pascal bibliotheque standard;System;Crt;Dos;SysUtils;Math;Strings'
  22 = 'Pascal compilateurs projet;PASCAL.PAS;PASC86.PAS;PASCW32.PAS;TPCW32.PAS'
  23 = 'Pascal exemple complet;Fibonacci;programme exemple'
  24 = 'Pascal references;bibliographie;Wirth;Jensen;ISO 7185;Turbo Pascal Reference;Cantu'
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
    $prev = 'IDH_PASCAL_{0:D2}' -f ($cur - 1)
    $parts += '{\uldb << Precedent}{\v ' + $prev + '}'
  }
  if ($cur -lt $total) {
    $nxt = 'IDH_PASCAL_{0:D2}' -f ($cur + 1)
    $parts += '{\uldb Suivant >>}{\v ' + $nxt + '}'
  }
  if ($cur -ne 1) {
    $parts += '{\uldb Table des matieres}{\v IDH_PASCAL_01}'
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
    $id = 'IDH_PASCAL_{0:D2}' -f $n
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
    $id = 'IDH_PASCAL_{0:D2}' -f $secNum
    [void]$sb.AppendLine('{\footnote # ' + $id + '}')
    [void]$sb.AppendLine('{\footnote ' + [char]36 + ' Pascal - ' + (Esc $secTitle) + '}')
    $kw = $secKeys[$secNum]
    if (-not $kw) { $kw = 'Pascal' }
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

$outPath = Join-Path $PSScriptRoot 'PASCAL.RTF'
[System.IO.File]::WriteAllText($outPath, $sb.ToString(), [System.Text.Encoding]::ASCII)
Write-Host ("Genere: " + $outPath + " (" + (Get-Item $outPath).Length + " octets)")
