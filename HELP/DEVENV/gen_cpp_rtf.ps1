# Genere HELP\DEVENV\CPP.RTF a partir de DOC\CPP_SPEC_LANG.txt
# Format des sections : "N. TITRE" (non indente) encadre par deux lignes "=====".

$src = Get-Content (Join-Path $PSScriptRoot '..\..\DOC\CPP_SPEC_LANG.txt')
$N = $src.Count

function Esc([string]$s) {
  $s = $s -replace '\\','\\'
  $s = $s -replace '\{','\{'
  $s = $s -replace '\}','\}'
  return $s
}

$secKeys = @{
  1  = 'C++ presentation;Stroustrup;Bell Labs;ISO 14882;C++98;C++03;C++11;C++14;C++17;C++20;C++23'
  2  = 'C++ structure programme;main;translation unit;namespace;include'
  3  = 'C++ structure lexicale;identificateurs;mots reserves;litteraux;commentaires;digraphes;nullptr;true;false'
  4  = 'C++ types donnees;bool;char;wchar_t;short;int;long;long long;float;double;void;enum;enum class;typedef;using;const;volatile;mutable;constexpr'
  5  = 'C++ declarations variables;auto;register;static;extern;thread_local;initialisation uniforme'
  6  = 'C++ operateurs;arithmetique;relationnel;logique;bit a bit;new;delete;sizeof;typeid;static_cast;dynamic_cast;const_cast;reinterpret_cast;surcharge'
  7  = 'C++ structures controle;if;else;switch;case;while;do;for;range-for;break;continue;return;goto;try;catch;throw'
  8  = 'C++ fonctions;parametres;reference;valeur;defaut;surcharge;inline;membre;lambda;constexpr'
  9  = 'C++ tableaux;array;vector;multidimensionnel;std::array;std::vector'
  10 = 'C++ pointeurs;references;rvalue reference;unique_ptr;shared_ptr;weak_ptr;new;delete;placement new'
  11 = 'C++ classes;objets;struct;class;public;private;protected;constructeur;destructeur;RAII;this;static;mutable'
  12 = 'C++ heritage;virtual;override;final;polymorphisme;abstract;virtual destructor;heritage multiple;heritage virtuel'
  13 = 'C++ surcharge operateurs;operator+;operator=;operator++;operator<<;friend;foncteur'
  14 = 'C++ templates;genericite;template typename;classe template;fonction template;specialisation;variadique'
  15 = 'C++ namespaces;namespace;using;alias;std;anonyme'
  16 = 'C++ exceptions;try;catch;throw;noexcept;std::exception;hierarchie'
  17 = 'C++ STL;bibliotheque standard;vector;list;map;set;deque;string;algorithm;iterator;foncteur;flux;iostream'
  18 = 'C++ preprocesseur;include;define;ifdef;pragma;__cplusplus;__FILE__;__LINE__'
  19 = 'C++ paradigmes;procedural;oriente objet;generique;fonctionnel;meta-programmation'
  20 = 'C++ evolutions;C++98;C++03;C++11;C++14;C++17;C++20;C++23;auto;lambda;concepts;modules;coroutines'
  21 = 'C++ compilation;edition liens;name mangling;extern C;phases traduction'
  22 = 'C++ compilateurs projet;CPP86.PAS'
  23 = 'C++ exemples;Hello World;Fibonacci;classe Point;template Pile;polymorphisme'
  24 = 'C++ references;bibliographie;Stroustrup;Meyers;Vandevoorde;isocpp;cppreference'
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
    $prev = 'IDH_CPP_{0:D2}' -f ($cur - 1)
    $parts += '{\uldb << Precedent}{\v ' + $prev + '}'
  }
  if ($cur -lt $total) {
    $nxt = 'IDH_CPP_{0:D2}' -f ($cur + 1)
    $parts += '{\uldb Suivant >>}{\v ' + $nxt + '}'
  }
  if ($cur -ne 1) {
    $parts += '{\uldb Table des matieres}{\v IDH_CPP_01}'
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
    $id = 'IDH_CPP_{0:D2}' -f $n
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
    $id = 'IDH_CPP_{0:D2}' -f $secNum
    [void]$sb.AppendLine('{\footnote # ' + $id + '}')
    [void]$sb.AppendLine('{\footnote ' + [char]36 + ' C++ - ' + (Esc $secTitle) + '}')
    $kw = $secKeys[$secNum]
    if (-not $kw) { $kw = 'C++' }
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

$outPath = Join-Path $PSScriptRoot 'CPP.RTF'
[System.IO.File]::WriteAllText($outPath, $sb.ToString(), [System.Text.Encoding]::ASCII)
Write-Host ("Genere: " + $outPath + " (" + (Get-Item $outPath).Length + " octets)")
