# Genere HELP\DEVENV\JASMIN.RTF a partir de DOC\ASM_JASMIN.txt

$src = Get-Content (Join-Path $PSScriptRoot '..\..\DOC\ASM_JASMIN.txt')
$N = $src.Count

function Esc([string]$s) {
  $s = $s -replace '\\','\\'
  $s = $s -replace '\{','\{'
  $s = $s -replace '\}','\}'
  return $s
}

$secKeys = @{
  1  = 'Jasmin introduction;assembleur JVM;Jonathan Meyer;1996;bytecode Java;stack-based;CCJASMIN.PAS;JASMIN.PAS'
  2  = 'Jasmin JVM;machine virtuelle Java;pile operandes;variables locales;tas heap;method area;constant pool;types JVM byte short int long float double char boolean'
  3  = 'Jasmin structure fichier;.class;.super;.method;.end method;sections;fichier .j'
  4  = 'Jasmin directives;.class .super .implements;.field;.method .end method;.limit stack;.limit locals;.var;.line;.throws;.catch;.source'
  5  = 'Jasmin descripteurs types JVM;B C D F I J S Z V;L classname;tableau;signatures methodes'
  6  = 'Jasmin opcodes chargement stockage;iload aload fload dload lload;istore astore fstore dstore lstore;iconst bipush sipush ldc;iaload iastore;getstatic putstatic getfield putfield'
  7  = 'Jasmin opcodes arithmetiques logiques;iadd isub imul idiv irem ineg;ladd ladd fadd dadd;iand ior ixor;ishl ishr iushr;iinc'
  8  = 'Jasmin opcodes conversion types;i2l i2f i2d;l2i l2f l2d;f2i f2l f2d;d2i d2l d2f;i2b i2c i2s'
  9  = 'Jasmin opcodes controle flux;ifeq ifne iflt ifge ifgt ifle;if_icmpeq if_icmpne;if_acmpeq if_acmpnull;goto;tableswitch lookupswitch;ireturn areturn return'
  10 = 'Jasmin opcodes invocation methodes;invokevirtual;invokestatic;invokespecial;invokeinterface;invokedynamic;return'
  11 = 'Jasmin opcodes manipulation pile;dup dup2 dup_x1 dup_x2;pop pop2;swap;nop'
  12 = 'Jasmin opcodes creation objets tableaux;new;newarray anewarray multianewarray;arraylength;instanceof checkcast;monitorenter monitorexit;athrow'
  13 = 'Jasmin opcodes comparaison;lcmp fcmpl fcmpg dcmpl dcmpg;if_icmplt if_icmpgt;if_icmple if_icmpge'
  14 = 'Jasmin exemples complets;Hello World;factorielle;classe Java;methodes;constructeur'
  15 = 'Jasmin CCJASMIN.PAS;compilateur C vers Jasmin;projet DEV-COOLS;Free Pascal;Turbo Pascal'
  16 = 'Jasmin assemblage execution;.j en .class;commande jasmin;execution JVM;java MainClass'
  17 = 'Jasmin differences bytecode brut;syntaxe textuelle;labels symboliques;directives;encodage'
  18 = 'Jasmin ressources projet;CCJASMIN.PAS;JASMIN.PAS;CC8086.PAS;documentation'
  19 = 'Jasmin tableau complet instructions JVM;opcodes 00-FF;mnemoniques;reference complete'
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
    $prev = 'IDH_JASMIN_{0:D2}' -f ($cur - 1)
    $parts += '{\uldb << Precedent}{\v ' + $prev + '}'
  }
  if ($cur -lt $total) {
    $nxt = 'IDH_JASMIN_{0:D2}' -f ($cur + 1)
    $parts += '{\uldb Suivant >>}{\v ' + $nxt + '}'
  }
  if ($cur -ne 1) {
    $parts += '{\uldb Table des matieres}{\v IDH_JASMIN_01}'
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
    $id = 'IDH_JASMIN_{0:D2}' -f $n
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
    $id = 'IDH_JASMIN_{0:D2}' -f $secNum
    [void]$sb.AppendLine('{\footnote # ' + $id + '}')
    [void]$sb.AppendLine('{\footnote ' + [char]36 + ' Jasmin - ' + (Esc $secTitle) + '}')
    $kw = $secKeys[$secNum]
    if (-not $kw) { $kw = 'Jasmin' }
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

$outPath = Join-Path $PSScriptRoot 'JASMIN.RTF'
[System.IO.File]::WriteAllText($outPath, $sb.ToString(), [System.Text.Encoding]::ASCII)
Write-Host ("Genere: " + $outPath + " (" + (Get-Item $outPath).Length + " octets)")
