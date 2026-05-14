# Genere HELP\DEVENV\ASM6502.RTF a partir de DOC\ASM_6502.txt

$src = Get-Content (Join-Path $PSScriptRoot '..\..\DOC\ASM_6502.txt')
$N = $src.Count

function Esc([string]$s) {
  $s = $s -replace '\\','\\'
  $s = $s -replace '\{','\{'
  $s = $s -replace '\}','\}'
  return $s
}

$secKeys = @{
  1  = 'Assembleur 6502 introduction;MOS Technology;Chuck Peddle;1975;8 bits;variantes 6510 65C02 65816;Apple II;Commodore 64;Atari;NES;modele programmation;little endian'
  2  = 'Assembleur 6502 architecture registres;accumulateur A;registres X Y;pointeur pile SP;compteur programme PC;registre etat P;flags NV-BDIZC;page zero;stack'
  3  = 'Assembleur 6502 modes adressage;implied accumulator immediate;zero page;zero page X Y;absolute;absolute X Y;indirect;indexed indirect Ind X;indirect indexed Ind Y;relative'
  4  = 'Assembleur 6502 jeu instructions opcodes;LDA LDX LDY STA STX STY;TAX TAY TXA TYA TSX TXS;ADC SBC INC INX INY DEC DEX DEY;AND ORA EOR;ASL LSR ROL ROR;CMP CPX CPY BIT;BCC BCS BEQ BNE BMI BPL BVC BVS;JMP JSR RTS RTI BRK;PHA PLA PHP PLP;CLC SEC CLD SED CLI SEI CLV;NOP'
  5  = 'Assembleur 6502 codage instructions format binaire;opcode table;taille instruction;illegal opcodes;non documentes'
  6  = 'Assembleur 6502 interruptions;IRQ;NMI;BRK;vecteurs interruption FFFA FFFC FFFE;sequence traitement'
  7  = 'Assembleur 6502 techniques programmation;arithmetique 16 bits multi-precision;multiplication division logicielle;chaines caracteres;tables saut;code auto-modifiant;optimisations;sous-routines'
  8  = 'Assembleur 6502 directives;ASM6502.PAS;DB FCB BYTE;DW FDB WORD;DS RMB BLKB;FCC;ORG AORG RORG END EQU SET;LIST OPT;MACRO ENDM;etiquettes symboles;expressions;formats numeriques'
  9  = 'Assembleur 6502 exemples;Hello World;factorielle;tri a bulles;multiplication 16 bits;delai temporisation;copie bloc memoire'
  10 = 'Assembleur 6502 conversion 80386;DIS6502 ASM86;correspondance registres;modes adressage;conversion instructions'
  11 = 'Assembleur 6502 conversion 68000;correspondance registres D0-D7 A0-A7;modes adressage;conversion instructions'
  12 = 'Assembleur 6502 conversion Z80;correspondance registres;modes adressage;conversion instructions'
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
    $prev = 'IDH_ASM6502_{0:D2}' -f ($cur - 1)
    $parts += '{\uldb << Precedent}{\v ' + $prev + '}'
  }
  if ($cur -lt $total) {
    $nxt = 'IDH_ASM6502_{0:D2}' -f ($cur + 1)
    $parts += '{\uldb Suivant >>}{\v ' + $nxt + '}'
  }
  if ($cur -ne 1) {
    $parts += '{\uldb Table des matieres}{\v IDH_ASM6502_01}'
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
    $id = 'IDH_ASM6502_{0:D2}' -f $n
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
    $id = 'IDH_ASM6502_{0:D2}' -f $secNum
    [void]$sb.AppendLine('{\footnote # ' + $id + '}')
    [void]$sb.AppendLine('{\footnote ' + [char]36 + ' Assembleur 6502 - ' + (Esc $secTitle) + '}')
    $kw = $secKeys[$secNum]
    if (-not $kw) { $kw = 'Assembleur 6502' }
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

$outPath = Join-Path $PSScriptRoot 'ASM6502.RTF'
[System.IO.File]::WriteAllText($outPath, $sb.ToString(), [System.Text.Encoding]::ASCII)
Write-Host ("Genere: " + $outPath + " (" + (Get-Item $outPath).Length + " octets)")
