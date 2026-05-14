# Genere HELP\DEVENV\CSHARP.RTF a partir de DOC\CSHARP_SPEC_LANG.txt

$src = Get-Content (Join-Path $PSScriptRoot '..\..\DOC\CSHARP_SPEC_LANG.txt')
$N = $src.Count

function Esc([string]$s) {
  $s = $s -replace '\\','\\'
  $s = $s -replace '\{','\{'
  $s = $s -replace '\}','\}'
  return $s
}

$secKeys = @{
  1  = 'C# presentation;Anders Hejlsberg;Microsoft;ECMA-334;ISO 23270;CLR;.NET;Mono;C# 1.0;C# 12;C# 13;historique versions'
  2  = 'C# structure programme;namespace;Main;using;top-level statements;file-scoped namespace;global using'
  3  = 'C# lexical;Unicode;identificateurs;mots reserves;mots contextuels;litteraux;raw strings;commentaires XML doc'
  4  = 'C# types donnees;sbyte byte short ushort int uint long ulong;nint nuint;float double decimal Half;bool char enum struct;object string class interface delegate;nullable;var;const'
  5  = 'C# operateurs;arithmetiques;logiques;bit-a-bit;null-coalescing ??;range ..;pattern is as;lambda =>;precedence'
  6  = 'C# controle;if else;switch;switch expression;pattern matching;while do for foreach;break continue return goto;try catch finally;using;lock;checked unchecked;yield'
  7  = 'C# classes objets;heritage;polymorphisme;abstract virtual override sealed;proprietes;init-only;required;indexers;constructeurs primaires;interfaces;default interface methods;structs;readonly struct;record struct'
  8  = 'C# records;immuable;egalite valeur;with expression;record class;record struct'
  9  = 'C# generics;classe generique;contraintes where;methode generique;generic math INumber'
  10 = 'C# delegates evenements lambdas;delegate;Func Action Predicate;event;EventHandler;lambda expression'
  11 = 'C# LINQ;Language Integrated Query;Where Select OrderBy GroupBy Join;requete syntaxe methode;IEnumerable'
  12 = 'C# async await;Task ValueTask;asynchrone;async streams;IAsyncEnumerable;HttpClient'
  13 = 'C# namespaces;file-scoped namespace;using directive;using static;global using;alias'
  14 = 'C# memoire bas niveau;Garbage Collector;IDisposable;unsafe;pointeurs;stackalloc;Span Memory;ref in out'
  15 = 'C# attributs reflection;Obsolete;Serializable;AttributeUsage;typeof;GetType;reflection'
  16 = 'C# compilateurs projet;CSC86.PAS;CSCW32.PAS;DOS 8086;Win32 PE;MASM;DllImport'
  17 = 'C# exemples;Hello;factorielle;fichier;LINQ;async parallele;records pattern matching'
  18 = 'C# bonnes pratiques;nullable enable;var;PascalCase camelCase;XML doc;analyseurs Roslyn;EditorConfig'
  19 = 'C# ecosysteme;.NET Framework;.NET Core;.NET 8;Mono;Xamarin;.NET MAUI;Unity;Blazor;Roslyn;NuGet;TypeScript;Kotlin'
  20 = 'C# references;ECMA-334;ISO 23270;Microsoft Learn;Hejlsberg;Albahari;Skeet;Richter;Roslyn'
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
    $prev = 'IDH_CSHARP_{0:D2}' -f ($cur - 1)
    $parts += '{\uldb << Precedent}{\v ' + $prev + '}'
  }
  if ($cur -lt $total) {
    $nxt = 'IDH_CSHARP_{0:D2}' -f ($cur + 1)
    $parts += '{\uldb Suivant >>}{\v ' + $nxt + '}'
  }
  if ($cur -ne 1) {
    $parts += '{\uldb Table des matieres}{\v IDH_CSHARP_01}'
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
    $id = 'IDH_CSHARP_{0:D2}' -f $n
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
    $id = 'IDH_CSHARP_{0:D2}' -f $secNum
    [void]$sb.AppendLine('{\footnote # ' + $id + '}')
    [void]$sb.AppendLine('{\footnote ' + [char]36 + ' C# - ' + (Esc $secTitle) + '}')
    $kw = $secKeys[$secNum]
    if (-not $kw) { $kw = 'C#' }
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

$outPath = Join-Path $PSScriptRoot 'CSHARP.RTF'
[System.IO.File]::WriteAllText($outPath, $sb.ToString(), [System.Text.Encoding]::ASCII)
Write-Host ("Genere: " + $outPath + " (" + (Get-Item $outPath).Length + " octets)")
