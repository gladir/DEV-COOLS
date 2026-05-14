# Genere HELP\DEVENV\PSP.RTF a partir de DOC\PSP_SPEC_LANG.txt

$src = Get-Content (Join-Path $PSScriptRoot '..\..\DOC\PSP_SPEC_LANG.txt')
$N = $src.Count

function Esc([string]$s) {
  $s = $s -replace '\\','\\'
  $s = $s -replace '\{','\{'
  $s = $s -replace '\}','\}'
  return $s
}

$secKeys = @{
  1  = 'PSP introduction;Pascal Server Pages;DEV-COOLS;PSP86.PAS;PSPCW32.PAS;ASP 3.0;CGI;.psp'
  2  = 'PSP philosophie;ASP 3.0;Active Server Pages;VBScript JScript;Pascal Server Pages;modele execution;CGI DOS;IIS Apache'
  3  = 'PSP structure fichier;HTML statique;blocs code;program;uses;ordre source'
  4  = 'PSP balises;<% %>;<%= %>;<%@ %>;<%-- --%>;include serveur;#include file virtual'
  5  = 'PSP directives page;@Language PascalScript;@CodePage;@LCID;@EnableSessionState'
  6  = 'PSP lexique;identificateurs;mots-cles Pascal;commentaires { } (* *);litteraux #10 #13 $1A %1010;True False nil'
  7  = 'PSP types donnees;Integer Word Byte Char Boolean String Real Pointer Text;array record enumeration set sous-intervalle pointeur typee'
  8  = 'PSP declarations const var type;sections multiples;constantes typees;Turbo Pascal mode'
  9  = 'PSP operateurs;arithmetiques + - * / div mod;relationnels = <> < <= > >= in;logiques and or xor not shl shr;concatenation +'
  10 = 'PSP controle flux;affectation :=;if then else;case;for to downto;while;repeat until;with;break continue exit'
  11 = 'PSP procedures fonctions;procedure;function Result;parametres valeur var;variables locales;Exit;forward'
  12 = 'PSP tableaux records;array of;bornes;multidimensionnels;record;Length Low High SizeOf'
  13 = 'PSP enumerations ensembles;type enum;Ord;set of;in;operations ensemblistes'
  14 = 'PSP chaines;String;Length Copy Pos Concat Chr Ord UpCase IntToStr StrToInt Trim'
  15 = 'PSP bibliotheque standard;Write WriteLn Read ReadLn;Abs Sqr Inc Dec Odd Pred Succ Random;Format Str Val'
  16 = 'PSP sortie HTML;Write WriteLn;Content-Type;flux HTTP;balises mixtes'
  17 = 'PSP COM OLE;CreateObject;Object;IDispatch;Scripting.FileSystemObject;PSPCW32 Win32;late-binding'
  18 = 'PSP directives compilation;$DEFINE $UNDEF;$IFDEF $IFNDEF $ELSE $ENDIF;$H $I $R'
  19 = 'PSP inclusions;$I fichier.inc;#include file virtual;MAX_INCLUDE profondeur;recursion detectee'
  20 = 'PSP erreurs;diagnostics ligne colonne;syntaxe semantique;limites MAX_SYM;division zero;indice borne $R'
  21 = 'PSP86 PSPCW32 compilateurs;cible 8086 MASM SMALL;Win32 natif;prefixes _PSP_ _PSPF_ _PSPK_ _PSPRT_ _PSPL_ _PSPA_ _PSPR_ _PSPE_ _PSPK_HTML_ _PSPX_;MAX_SYM 2048'
  22 = 'PSP deploiement;DOS CGI;Win32 IIS Apache;ASM86 LINK;cycle compilation iteratif'
  23 = 'PSP exemples;Hello World;compteur;tableau somme;procedures fonctions;COM CreateObject;directives conditionnelles'
  24 = 'PSP vs ASP 3.0;Pascal vs VBScript JScript;AOT vs interprete;Response.Write;objets intrinseques Request Response Server Session Application'
  25 = 'PSP vs Pascal standard;blocs <% %> portee globale;HTML emis automatiquement;<%= raccourci;limitations Real;Object COM only'
  26 = 'PSP ressources projet;PSP86.PAS;PSPCW32.PAS;ASC2PSP.PAS;BIN2PSP.PAS;SAMPLES PSP;hello test_arith test_array test_case test_com test_func test_loop test_record test_string'
  27 = 'PSP bibliographie;ASP 3.0 Microsoft;Mitchell;Homer;Pascal Wirth Jensen;Turbo Pascal 7;Free Pascal;RFC 3875 CGI'
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
    $prev = 'IDH_PSP_{0:D2}' -f ($cur - 1)
    $parts += '{\uldb << Precedent}{\v ' + $prev + '}'
  }
  if ($cur -lt $total) {
    $nxt = 'IDH_PSP_{0:D2}' -f ($cur + 1)
    $parts += '{\uldb Suivant >>}{\v ' + $nxt + '}'
  }
  if ($cur -ne 1) {
    $parts += '{\uldb Table des matieres}{\v IDH_PSP_01}'
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
    $id = 'IDH_PSP_{0:D2}' -f $n
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
    $id = 'IDH_PSP_{0:D2}' -f $secNum
    [void]$sb.AppendLine('{\footnote # ' + $id + '}')
    [void]$sb.AppendLine('{\footnote ' + [char]36 + ' PSP - ' + (Esc $secTitle) + '}')
    $kw = $secKeys[$secNum]
    if (-not $kw) { $kw = 'PSP' }
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

$outPath = Join-Path $PSScriptRoot 'PSP.RTF'
[System.IO.File]::WriteAllText($outPath, $sb.ToString(), [System.Text.Encoding]::ASCII)
Write-Host ("Genere: " + $outPath + " (" + (Get-Item $outPath).Length + " octets)")
