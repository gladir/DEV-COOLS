# Genere HELP\DEVENV\ASM68000.RTF a partir de DOC\ASM_68000.txt

$src = Get-Content (Join-Path $PSScriptRoot '..\..\DOC\ASM_68000.txt')
$N = $src.Count

function Esc([string]$s) {
  $s = $s -replace '\\','\\'
  $s = $s -replace '\{','\{'
  $s = $s -replace '\}','\}'
  return $s
}

$secKeys = @{
  1  = 'Assembleur 68000 introduction;Motorola;MC68000;1979;CISC 16/32 bits;Amiga;Atari ST;Macintosh;Sega Genesis;Neo Geo;famille 68k;68010 68020 68030 68040 68060;CPU32 ColdFire;modele programmation;big endian'
  2  = 'Assembleur 68000 architecture registres;registres donnees D0-D7;registres adresses A0-A7;USP SSP;PC;SR CCR;flags X N Z V C;modes superviseur utilisateur;organisation memoire'
  3  = 'Assembleur 68000 modes adressage;direct registre donnee adresse;indirect adresse;post-increment pre-decrement;deplacement;indexe;PC relatif;immediat;absolu court long'
  4  = 'Assembleur 68000 jeu instructions opcodes;MOVE MOVEA MOVEM MOVEP MOVEQ;ADD SUB MULU MULS DIVU DIVS;AND OR EOR NOT NEG;ASL ASR LSL LSR ROL ROR ROXL ROXR;CMP TST BTST BSET BCLR BCHG;Bcc BRA BSR JMP JSR RTS RTE;LINK UNLK;TRAP TRAPV CHK;NOP STOP RESET'
  5  = 'Assembleur 68000 codage instructions format binaire;encodage word 16 bits;effective address EA;extension words;taille operande B W L'
  6  = 'Assembleur 68000 exceptions interruptions;vecteur exception;groupe 0 1 2;reset bus error address error;privilege violation;TRAP TRAPV;CHK;interrupt levels 1-7;auto-vector;table vecteurs'
  7  = 'Assembleur 68000 coprocesseur flottant;MC68881 MC68882;FPU;registres FP0-FP7 FPCR FPSR FPIAR;FMOVE FADD FSUB FMUL FDIV;FSIN FCOS FSQRT FLOG;extended precision 80 bits'
  8  = 'Assembleur 68000 techniques programmation;arithmetique 32 64 bits;multiplication division logicielles;chaines caracteres;tables saut;optimisations;sous-routines conventions appel;stack frame LINK UNLK'
  9  = 'Assembleur 68000 directives;ASM68.PAS;DC.B DC.W DC.L;DS.B DS.W DS.L;DCB;ORG END EQU SET;OPT LIST;MACRO ENDM;etiquettes symboles;expressions;formats numeriques'
  10 = 'Assembleur 68000 exemples;Hello World;factorielle;tri a bulles;multiplication 32 bits;routine delai;copie bloc memoire'
  11 = 'Assembleur 68000 conversion 8086;correspondance registres;modes adressage;conversion instructions;DIS6502 DIS8086'
  12 = 'Assembleur 68000 conversion 80386;correspondance registres EAX-EDX;modes adressage;conversion instructions'
  13 = 'Assembleur 68000 conversion ARM;correspondance registres R0-R15;modes adressage;conversion instructions'
  14 = 'Assembleur 68000 conversion Z8000;correspondance registres;modes adressage;conversion instructions'
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
    $prev = 'IDH_ASM68000_{0:D2}' -f ($cur - 1)
    $parts += '{\uldb << Precedent}{\v ' + $prev + '}'
  }
  if ($cur -lt $total) {
    $nxt = 'IDH_ASM68000_{0:D2}' -f ($cur + 1)
    $parts += '{\uldb Suivant >>}{\v ' + $nxt + '}'
  }
  if ($cur -ne 1) {
    $parts += '{\uldb Table des matieres}{\v IDH_ASM68000_01}'
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
    $id = 'IDH_ASM68000_{0:D2}' -f $n
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
    $id = 'IDH_ASM68000_{0:D2}' -f $secNum
    [void]$sb.AppendLine('{\footnote # ' + $id + '}')
    [void]$sb.AppendLine('{\footnote ' + [char]36 + ' Assembleur 68000 - ' + (Esc $secTitle) + '}')
    $kw = $secKeys[$secNum]
    if (-not $kw) { $kw = 'Assembleur 68000' }
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

$outPath = Join-Path $PSScriptRoot 'ASM68000.RTF'
[System.IO.File]::WriteAllText($outPath, $sb.ToString(), [System.Text.Encoding]::ASCII)
Write-Host ("Genere: " + $outPath + " (" + (Get-Item $outPath).Length + " octets)")
