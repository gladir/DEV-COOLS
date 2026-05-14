# Genere HELP\DEVENV\JAVA.RTF a partir de DOC\JAVA_SPEC_LANG.txt

$src = Get-Content (Join-Path $PSScriptRoot '..\..\DOC\JAVA_SPEC_LANG.txt')
$N = $src.Count

function Esc([string]$s) {
  $s = $s -replace '\\','\\'
  $s = $s -replace '\{','\{'
  $s = $s -replace '\}','\}'
  return $s
}

$secKeys = @{
  1  = 'Java presentation;James Gosling;Sun Microsystems;Oak;JVM;Write Once Run Anywhere;historique versions;Java 21 LTS;OpenJDK;HotSpot;GraalVM'
  2  = 'Java structure programme;Hello World;main;javac;java;single-source;unnamed classes;instance main'
  3  = 'Java lexical;Unicode;identificateurs;camelCase;PascalCase;mots reserves;var yield record sealed;litteraux;text blocks;commentaires;Javadoc'
  4  = 'Java types donnees;primitifs;boolean byte short char int long float double;wrappers;autoboxing;Object String;tableaux;records;var inference;final constantes'
  5  = 'Java operateurs;arithmetiques;affectation composee;comparaison instanceof;logiques;bit-a-bit;>>>;ternaire;cast;concatenation String;precedence'
  6  = 'Java controle;if else;switch instruction;switch expression;yield;pattern matching switch;while do-while;for;for-each;break continue label;try catch finally;multi-catch;try-with-resources;assert;throw'
  7  = 'Java classes objets;heritage;polymorphisme;abstract final static;interfaces;default methods;static methods;classes internes;anonymes;enum;records;sealed permits non-sealed;modificateurs acces'
  8  = 'Java generics;parametres type;methodes generiques;wildcards;extends super;type erasure;diamond operator;bounded type'
  9  = 'Java lambdas;programmation fonctionnelle;Function Predicate Consumer Supplier;BiFunction;UnaryOperator;references methode;effectively final;interfaces fonctionnelles;FunctionalInterface'
  10 = 'Java Stream API;filter map reduce collect;Collectors;parallelStream;mapToInt;flatMap;groupingBy partitioningBy;Optional;toList'
  11 = 'Java Collections Framework;List ArrayList LinkedList;Set HashSet TreeSet;Map HashMap TreeMap ConcurrentHashMap;Queue Deque;PriorityQueue ArrayDeque;collections immuables;List.of Set.of Map.of'
  12 = 'Java concurrence threads;Thread;synchronized volatile;Executor ExecutorService;Future CompletableFuture;atomic;ConcurrentHashMap;virtual threads;structured concurrency'
  13 = 'Java packages modules;package import;static import;JPMS Project Jigsaw;module-info;requires exports opens;uses provides;jlink jpackage jdeps'
  14 = 'Java bibliotheque standard;java.lang;java.util;java.io java.nio;java.net HttpClient;java.time;java.util.concurrent;java.sql JDBC;reflection;MethodHandles'
  15 = 'Java compilateurs projet;JAVAC86.PAS;JAVACW32.PAS;DOS 8086;Win32 PE;MASM;sous-ensemble Java 1.4 5 8'
  16 = 'Java exemples;Hello;factorielle;lecture fichier;Stream;HttpClient;record pattern matching;sealed'
  17 = 'Java bonnes pratiques;conventions Oracle;Optional;try-with-resources;raw types;composition;Override;Javadoc;SLF4J;JUnit;Maven Gradle'
  18 = 'Java ecosysteme;Java SE EE;Jakarta EE;Android;Spring Spring Boot;Hibernate JPA;Quarkus Micronaut;Apache Kafka Cassandra Hadoop Spark;IntelliJ Eclipse NetBeans;HotSpot OpenJ9 GraalVM Azul'
  19 = 'Java references;JLS Java Language Specification;JVMS;OpenJDK;JEP;Bloch Effective Java;Goetz Concurrency in Practice;Horstmann Core Java;tutoriels Oracle'
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
    $prev = 'IDH_JAVA_{0:D2}' -f ($cur - 1)
    $parts += '{\uldb << Precedent}{\v ' + $prev + '}'
  }
  if ($cur -lt $total) {
    $nxt = 'IDH_JAVA_{0:D2}' -f ($cur + 1)
    $parts += '{\uldb Suivant >>}{\v ' + $nxt + '}'
  }
  if ($cur -ne 1) {
    $parts += '{\uldb Table des matieres}{\v IDH_JAVA_01}'
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
    $id = 'IDH_JAVA_{0:D2}' -f $n
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
    $id = 'IDH_JAVA_{0:D2}' -f $secNum
    [void]$sb.AppendLine('{\footnote # ' + $id + '}')
    [void]$sb.AppendLine('{\footnote ' + [char]36 + ' Java - ' + (Esc $secTitle) + '}')
    $kw = $secKeys[$secNum]
    if (-not $kw) { $kw = 'Java' }
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

$outPath = Join-Path $PSScriptRoot 'JAVA.RTF'
[System.IO.File]::WriteAllText($outPath, $sb.ToString(), [System.Text.Encoding]::ASCII)
Write-Host ("Genere: " + $outPath + " (" + (Get-Item $outPath).Length + " octets)")
