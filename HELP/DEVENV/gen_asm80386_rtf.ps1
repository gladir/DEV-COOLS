# Genere HELP\DEVENV\ASM80386.RTF a partir de DOC\ASM_80386.txt

$src = Get-Content (Join-Path $PSScriptRoot '..\..\DOC\ASM_80386.txt')
$N = $src.Count

function Esc([string]$s) {
  $s = $s -replace '\\','\\'
  $s = $s -replace '\{','\{'
  $s = $s -replace '\}','\}'
  return $s
}

$secKeys = @{
  1  = 'Assembleur 80386 introduction;Intel 80386;1985;CISC 32 bits;mode reel mode protege mode virtuel 8086;famille x86;486 Pentium;evolution 8086 80286;modele programmation;little endian'
  2  = 'Assembleur 80386 architecture registres;registres generaux EAX EBX ECX EDX;ESI EDI EBP ESP;CS DS ES FS GS SS;EIP;EFLAGS;registres controle CR0-CR4;registres debug DR0-DR7;registres test;registres systeme GDTR LDTR IDTR TR'
  3  = 'Assembleur 80386 modes adressage;immediat;registre;direct;indirect registre;base index deplacement;SIB scale index base;PC relatif;segment override;mode 16 32 bits'
  4  = 'Assembleur 80386 jeu instructions opcodes;MOV LEA XCHG PUSH POP;ADD SUB MUL IMUL DIV IDIV INC DEC NEG CMP;AND OR XOR NOT TEST;SHL SHR SAR ROL ROR RCL RCR SHLD SHRD;Jcc JMP CALL RET LOOP;BSF BSR BT BTS BTR BTC;MOVSX MOVZX;STOS LODS MOVS CMPS SCAS REP;CLI STI HLT NOP'
  5  = 'Assembleur 80386 codage instructions format binaire;prefixes opcode ModRM SIB displacement immediate;prefixes 66 67 F0 F2 F3 26 2E 36 3E 64 65;encodage 32 bits;extension REX'
  6  = 'Assembleur 80386 mode protege descripteurs;GDT LDT IDT;segment selector;descripteur segment code donnee systeme;privilege level CPL DPL RPL;TSS task state segment;call gate trap gate interrupt gate task gate'
  7  = 'Assembleur 80386 pagination memoire virtuelle;page directory page table;PDE PTE;CR3;TLB;page fault;4Ko pages;permissions read write user supervisor'
  8  = 'Assembleur 80386 interruptions exceptions;IDT;faults traps aborts;divide error;page fault;general protection fault;double fault;INT 0-FF;NMI;IRQ;interrupt vector'
  9  = 'Assembleur 80386 optimisation;pipeline;cache;pairing;alignement;LEA arithmetique;instructions specialisees'
  10 = 'Assembleur 80386 directives MASM TASM;ASM86.PAS MASM.PAS;DB DW DD DQ DF DT;DUP;SEGMENT ENDS;ASSUME;PROC ENDP;.MODEL;.386 .486;.CODE .DATA .STACK;EQU =;MACRO ENDM;ORG END'
  11 = 'Assembleur 80386 exemples;Hello World;factorielle;tri a bulles;multiplication 32 64 bits;copie bloc memoire;routine delai'
  12 = 'Assembleur 80386 conversion 8086;correspondance registres 16 32 bits;modes adressage;conversion instructions'
  13 = 'Assembleur 80386 conversion ARM;correspondance registres R0-R15;modes adressage;conversion instructions'
  14 = 'Assembleur 80386 conversion 68000;correspondance registres D0-D7 A0-A7;modes adressage;conversion instructions'
  15 = 'Assembleur 80386 conversion PowerPC;correspondance registres GPR0-GPR31;modes adressage;conversion instructions'
  16 = 'Assembleur 80386 conversion Z8000;correspondance registres;modes adressage;conversion instructions'
  17 = 'Assembleur 80386 conversion i860;correspondance registres;modes adressage;conversion instructions'
  18 = 'Assembleur 80386 conversion Itanium IA-64;correspondance registres;modes adressage;conversion instructions'
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
    $prev = 'IDH_ASM80386_{0:D2}' -f ($cur - 1)
    $parts += '{\uldb << Precedent}{\v ' + $prev + '}'
  }
  if ($cur -lt $total) {
    $nxt = 'IDH_ASM80386_{0:D2}' -f ($cur + 1)
    $parts += '{\uldb Suivant >>}{\v ' + $nxt + '}'
  }
  if ($cur -ne 1) {
    $parts += '{\uldb Table des matieres}{\v IDH_ASM80386_01}'
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
    $id = 'IDH_ASM80386_{0:D2}' -f $n
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
    $id = 'IDH_ASM80386_{0:D2}' -f $secNum
    [void]$sb.AppendLine('{\footnote # ' + $id + '}')
    [void]$sb.AppendLine('{\footnote ' + [char]36 + ' Assembleur 80386 - ' + (Esc $secTitle) + '}')
    $kw = $secKeys[$secNum]
    if (-not $kw) { $kw = 'Assembleur 80386' }
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

$outPath = Join-Path $PSScriptRoot 'ASM80386.RTF'
[System.IO.File]::WriteAllText($outPath, $sb.ToString(), [System.Text.Encoding]::ASCII)
Write-Host ("Genere: " + $outPath + " (" + (Get-Item $outPath).Length + " octets)")
