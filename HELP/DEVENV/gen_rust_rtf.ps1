# Genere HELP\DEVENV\RUST.RTF a partir de DOC\RUST_SPEC_LANG.txt

$src = Get-Content (Join-Path $PSScriptRoot '..\..\DOC\RUST_SPEC_LANG.txt')
$N = $src.Count

function Esc([string]$s) {
  $s = $s -replace '\\','\\'
  $s = $s -replace '\{','\{'
  $s = $s -replace '\}','\}'
  return $s
}

$secKeys = @{
  1  = 'Rust presentation;Graydon Hoare;Mozilla;Rust Foundation;historique versions;edition 2015 2018 2021 2024;rustc;LLVM;ownership;borrow checker;zero-cost abstractions'
  2  = 'Rust structure programme;Hello World;main fn;rustc;Cargo;Cargo.toml;crate;binaire bibliotheque'
  3  = 'Rust lexical;Unicode UTF-8;identificateurs;snake_case;PascalCase;mots reserves;litteraux;raw string;byte string;C string;commentaires;rustdoc'
  4  = 'Rust types donnees;i8 i16 i32 i64 i128;u8 u16 u32 u64 u128;f32 f64;bool char;tuple;tableau;slice;str String;struct enum;Option Result;references;Box Rc Arc RefCell Cell;let mut const static;shadowing'
  5  = 'Rust ownership emprunts lifetimes;move;clone;Copy;borrow checker;&T &mut T;lifetime;static;lifetime elision'
  6  = 'Rust operateurs;arithmetiques;comparaison;logiques;bit-a-bit;references;plage ..  ..=;as cast;question mark;precedence;std::ops'
  7  = 'Rust instructions expressions;if let;while let;loop;for;match;if let-else;break continue label;return;expression bloc;question mark'
  8  = 'Rust fonctions fermetures;fn;parametres;generics where;closures;Fn FnMut FnOnce;move;impl Trait'
  9  = 'Rust traits generics;trait impl;derive Debug Clone PartialEq Eq Hash Default Copy;Display From Into AsRef;Iterator IntoIterator;Send Sync;dyn Trait;object safety;GAT;Generic Associated Types'
  10 = 'Rust macros;macro_rules!;println! print! format! eprintln!;vec!;assert! assert_eq!;panic! todo! unimplemented!;dbg!;include_str!;cfg! env!;procedurales;derive;attribute macros'
  11 = 'Rust gestion erreurs;Result Ok Err;Option Some None;? operator try;panic!;unwrap expect;unwrap_or;map and_then;ok_or;anyhow thiserror'
  12 = 'Rust modules paquets;mod;use;pub pub(crate) pub(super);crate;Cargo;workspace;cargo build run test fmt clippy doc publish add install;crates.io'
  13 = 'Rust concurrence asynchrone;thread spawn;Arc Mutex;Send Sync;mpsc channel;async await;Future;tokio async-std smol embassy;join select'
  14 = 'Rust unsafe FFI;bloc unsafe;pointeur brut;extern C;no_mangle;static mut;union;trait unsafe;bindings'
  15 = 'Rust bibliotheque standard;std primitive;Option Result;Vec String;HashMap HashSet BTreeMap BTreeSet VecDeque BinaryHeap;Iterator;fmt Display Debug;io fs;path Path PathBuf;thread sync;process env;time Duration Instant;core alloc no_std'
  16 = 'Rust tests documentation;cfg test;#[test] should_panic;cargo test;integration tests;doctests;rustdoc;criterion benchmark'
  17 = 'Rust outils projet DEV-COOLS;RUST86.PAS compilateur 8086;ADA2RUST.PAS;RUST2ADA.PAS;PAS2RUST.PAS;RUST2PAS.PAS;VB2RUST.PAS;convertisseurs'
  18 = 'Rust exemples;Hello;factorielle;lecture fichier;iterators collect;pattern matching;HashMap;threads channels;tokio async await'
  19 = 'Rust bonnes pratiques;API Guidelines;cargo fmt;cargo clippy;must_use;Result ?;eviter unsafe;iterators;edition 2024;deny warnings'
  20 = 'Rust ecosysteme influence;serde tokio reqwest hyper axum actix-web rocket;diesel sqlx sea-orm;clap regex rayon crossbeam;anyhow thiserror;log tracing;wasm-bindgen;rustup rustc cargo rustfmt clippy rustdoc miri bindgen;Linux kernel;Windows kernel;Firefox Servo;Discord Dropbox AWS Cloudflare'
  21 = 'Rust references;Rust Reference;Rust Programming Language livre;Rust by Example;Rustonomicon;Async Book;crates.io;API Guidelines;RFC;Klabnik Nichols;Blandy Orendorff;McNamara'
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
    $prev = 'IDH_RUST_{0:D2}' -f ($cur - 1)
    $parts += '{\uldb << Precedent}{\v ' + $prev + '}'
  }
  if ($cur -lt $total) {
    $nxt = 'IDH_RUST_{0:D2}' -f ($cur + 1)
    $parts += '{\uldb Suivant >>}{\v ' + $nxt + '}'
  }
  if ($cur -ne 1) {
    $parts += '{\uldb Table des matieres}{\v IDH_RUST_01}'
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
    $id = 'IDH_RUST_{0:D2}' -f $n
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
    $id = 'IDH_RUST_{0:D2}' -f $secNum
    [void]$sb.AppendLine('{\footnote # ' + $id + '}')
    [void]$sb.AppendLine('{\footnote ' + [char]36 + ' Rust - ' + (Esc $secTitle) + '}')
    $kw = $secKeys[$secNum]
    if (-not $kw) { $kw = 'Rust' }
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

$outPath = Join-Path $PSScriptRoot 'RUST.RTF'
[System.IO.File]::WriteAllText($outPath, $sb.ToString(), [System.Text.Encoding]::ASCII)
Write-Host ("Genere: " + $outPath + " (" + (Get-Item $outPath).Length + " octets)")
