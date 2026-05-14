# Genere HELP\DEVENV\PYTHON.RTF a partir de DOC\PYTHON_SPEC_LANG.txt

$src = Get-Content (Join-Path $PSScriptRoot '..\..\DOC\PYTHON_SPEC_LANG.txt')
$N = $src.Count

function Esc([string]$s) {
  $s = $s -replace '\\','\\'
  $s = $s -replace '\{','\{'
  $s = $s -replace '\}','\}'
  return $s
}

$secKeys = @{
  1  = 'Python presentation;Guido van Rossum;CWI;Monty Python;PEP 20;Zen of Python;historique versions;Python 3.13;CPython;PyPy'
  2  = 'Python structure programme;module;__main__;indentation;PEP 8;shebang;main'
  3  = 'Python lexical;Unicode;identificateurs;snake_case;PascalCase;mots reserves;litteraux;f-strings;docstring;commentaires'
  4  = 'Python types donnees;int float complex bool;str bytes bytearray;list tuple range;dict set frozenset;None Ellipsis;type hints;PEP 484 526 585 695;variables;unpacking'
  5  = 'Python operateurs;arithmetiques;// ** @;comparaison is in;and or not;bit-a-bit;walrus :=;ternaire;precedence'
  6  = 'Python controle;if elif else;while else;for else;break continue pass;match case;PEP 634;try except finally;ExceptionGroup;with context manager;raise;return yield'
  7  = 'Python fonctions;def;parametres defaut;*args **kwargs;positional-only;keyword-only;lambda;decorateurs;map filter reduce'
  8  = 'Python classes objets;__init__;dunders;self;heritage;super;MRO;C3 linearization;property;dataclass;PEP 557;abc;abstractmethod'
  9  = 'Python modules packages;import;from import;__init__.py;namespace package;sys.path;pip;venv;poetry;uv'
  10 = 'Python collections;list tuple dict set;methodes;comprehensions;defaultdict Counter OrderedDict deque namedtuple ChainMap'
  11 = 'Python generateurs iterateurs async;yield;yield from;StopIteration;itertools;asyncio;async await;PEP 492;async for;async generators'
  12 = 'Python chaines;str methodes;split join replace;f-string formatage;str.format;encode decode;regex re;expressions regulieres'
  13 = 'Python entrees sorties fichiers;open;with;encoding utf-8;pathlib;Path;json csv pickle;tomllib;serialisation'
  14 = 'Python bibliotheque standard;sys os pathlib;argparse logging;datetime;math random;collections itertools functools;json csv sqlite3;urllib socket;threading multiprocessing asyncio;unittest pytest;typing dataclasses enum'
  15 = 'Python compilateurs projet;PYTHON86.PAS;PYTHCW32.PAS;DOS 8086;Win32 PE;MASM;sous-ensemble'
  16 = 'Python exemples;Hello;factorielle;Fibonacci;Counter;asyncio;dataclass;lru_cache;memoization'
  17 = 'Python bonnes pratiques;PEP 8;PEP 20;PEP 257;Zen;black;ruff;flake8 pylint;mypy pyright;pytest'
  18 = 'Python ecosysteme;NumPy Pandas SciPy;scikit-learn TensorFlow PyTorch JAX;Django Flask FastAPI;Tkinter PyQt;CPython PyPy Jython IronPython MicroPython GraalPy'
  19 = 'Python references;PEP Index;documentation officielle;PEP 8 20 484 492 526 557 585 634 695;Lutz;Beazley;Ramalho;van Rossum'
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
    $prev = 'IDH_PYTHON_{0:D2}' -f ($cur - 1)
    $parts += '{\uldb << Precedent}{\v ' + $prev + '}'
  }
  if ($cur -lt $total) {
    $nxt = 'IDH_PYTHON_{0:D2}' -f ($cur + 1)
    $parts += '{\uldb Suivant >>}{\v ' + $nxt + '}'
  }
  if ($cur -ne 1) {
    $parts += '{\uldb Table des matieres}{\v IDH_PYTHON_01}'
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
    $id = 'IDH_PYTHON_{0:D2}' -f $n
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
    $id = 'IDH_PYTHON_{0:D2}' -f $secNum
    [void]$sb.AppendLine('{\footnote # ' + $id + '}')
    [void]$sb.AppendLine('{\footnote ' + [char]36 + ' Python - ' + (Esc $secTitle) + '}')
    $kw = $secKeys[$secNum]
    if (-not $kw) { $kw = 'Python' }
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

$outPath = Join-Path $PSScriptRoot 'PYTHON.RTF'
[System.IO.File]::WriteAllText($outPath, $sb.ToString(), [System.Text.Encoding]::ASCII)
Write-Host ("Genere: " + $outPath + " (" + (Get-Item $outPath).Length + " octets)")
