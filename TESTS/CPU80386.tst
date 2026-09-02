[AAA-ASCII-Adjust-Addition]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 0Fh 00h 37h 89h C3h 9Ch 58h 25h 11h 00h 89h C1h B4h 10h 9Eh B8h 03h 02h 37h 89h C2h 9Ch 58h 25h 11h 00h 89h C6h B4h 00h 9Eh B8h 03h 02h 37h 89h C7h 9Ch 58h 25h 11h 00h 89h C5h
BreakPoint: 1000:012D
Result:
BX=0105h
CX=0011h
DX=0309h
SI=0011h
DI=0203h
BP=0000h

[AAD-ASCII-Adjust-before-Division]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 01h 03h D5h 0Ah 89h C3h 9Ch 58h 25h C4h 00h 89h C1h B8h 00h 00h D5h 0Ah 89h C2h 9Ch 58h 25h C4h 00h 89h C6h
BreakPoint: 1000:011C
Result:
BX=001Fh
CX=0000h
DX=0000h
SI=0044h

[AAM-ASCII-Adjust-Multiply]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B0h 1Fh D4h 0Ah 89h C3h 9Ch 58h 25h C4h 00h 89h C1h B0h 64h D4h 0Ah 89h C2h 9Ch 58h 25h C4h 00h 89h C6h
BreakPoint: 1000:011A
Result:
BX=0301h
CX=0000h
DX=0A00h
SI=0044h

[AAS-ASCII-Adjust-Subtraction]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 0Fh 00h 3Fh 89h C3h 9Ch 58h 25h 11h 00h 89h C1h B4h 10h 9Eh B8h 03h 02h 3Fh 89h C2h 9Ch 58h 25h 11h 00h 89h C6h B4h 00h 9Eh B8h 03h 02h 3Fh 89h C7h 9Ch 58h 25h 11h 00h 89h C5h
BreakPoint: 1000:012D
Result:
BX=FF09h
CX=0011h
DX=010Dh
SI=0011h
DI=0203h
BP=0000h

[ADC-propagates-carry-from-previous-ADD]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h FFh FFh BBh 01h 00h 01h D8h 11h D8h
BreakPoint: 1000:010A
Result:
AX=0002h
BX=0001h

[ADC-signed-overflow-with-carry-in-sets-OF]
EntryPoint: 1000:0100
Data in 1000:0100:
DB F9h B8h FFh 7Fh BBh 00h 00h 11h D8h 70h 05h BAh 00h 00h EBh 03h BAh 02h 00h
BreakPoint: 1000:0113
Result:
AX=8000h
DX=0002h

[ADD-reg-reg-flags-full]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 02h 00h BBh 03h 00h 01h D8h 89h C7h 9Ch 58h 25h D1h 08h 89h C5h B8h FFh FFh BBh 01h 00h 01h D8h 89h C6h 9Ch 58h 25h D1h 08h 89h C2h B8h FFh 7Fh BBh 01h 00h 01h D8h 89h C1h 9Ch 58h 25h D1h 08h 89h C3h
BreakPoint: 1000:0133
Result:
DI=0005h
BP=0000h
SI=0000h
DX=0051h
CX=8000h
BX=0890h

[ADD-signed-overflow-sets-OF-verified-via-branch]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h FFh 7Fh BBh 01h 00h 01h D8h 70h 05h B9h 00h 00h EBh 03h B9h 01h 00h
BreakPoint: 1000:0112
Result:
AX=8000h
CX=0001h

[AND-OR-XOR-mem-operand]
Data in 1000:0500:
DB F0h 00h
Data in 1000:0502:
DB 0Fh 00h
Data in 1000:0504:
DB F0h
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h BBh 0Fh 00h 21h 1Eh 00h 05h A1h 00h 05h 89h C6h B9h F0h 00h 0Bh 0Eh 02h 05h 89h CFh A1h 02h 05h 89h C5h B0h 0Fh 30h 06h 04h 05h B0h 00h A0h 04h 05h 89h C2h
BreakPoint: 1000:012C
Result:
SI=0000h
DI=00FFh
BP=000Fh
DX=00FFh

[AND-OR-XOR-reg-reg-flags]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h FFh 00h BBh 00h FFh 21h D8h 9Ch 5Eh 81h E6h C5h 08h B8h FFh FFh BBh 01h 80h 21h D8h 9Ch 5Fh 81h E7h C5h 08h B8h F0h 00h BBh 0Fh 00h 09h D8h 9Ch 5Dh 81h E5h C5h 08h B8h 34h 12h 31h C0h 9Ch 5Ah 81h E2h C5h 08h B8h FFh 00h BBh 0Fh 0Fh 31h D8h 9Ch 58h 25h C5h 08h
BreakPoint: 1000:0142
Result:
SI=0044h
DI=0080h
BP=0004h
DX=0044h
AX=0004h

[ARPL-adjusts-RPL-and-sets-ZF]
EntryPoint: 1000:0100
Data in 1000:0100:
DB BBh 08h 00h B9h 13h 00h 63h CBh 89h DFh 9Ch 5Eh 81h E6h 40h 00h BBh 0Bh 00h B9h 10h 00h 63h CBh 9Ch 58h 25h 40h 00h
BreakPoint: 1000:011D
Result:
DI=000Bh
SI=0040h
BX=000Bh
AX=0000h

[BOUND-checks-index-and-fires-INT5-on-overflow]
Data in 1000:0300:
DB 00h 00h 0Ah 00h
Data in 0000:0014:
DB 00h 02h 00h 10h
Data in 1000:0200:
DB BBh 78h 56h CFh
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h BAh 05h 00h 62h 16h 00h 03h B9h 34h 12h BAh 0Fh 00h 62h 16h 00h 03h BAh 99h 99h
BreakPoint: 1000:0119
Result:
CX=1234h
BX=5678h
DX=9999h

[BSF-and-BSR-scan-bits-in-memory-word-with-displacement]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h 0Fh BCh 1Eh 20h 03h 0Fh BDh 0Eh 30h 03h
Data in 1000:0320:
DB 20h 00h
Data in 1000:0330:
DB 28h 00h
BreakPoint: 1000:010F
Result:
BX=0005h
CX=0005h

[BT-memory-with-displacement-tests-bit-and-leaves-value-unchanged]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h B9h 03h 00h 0Fh A3h 0Eh 00h 02h 9Ch 58h 25h 01h 00h 8Bh 1Eh 00h 02h
Data in 1000:0200:
DB 08h 00h
BreakPoint: 1000:0116
Result:
AX=0001h
BX=0008h

[BT-r-m16-imm8-group8-tests-bit-in-memory-with-displacement]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h 0Fh BAh 26h 40h 02h 04h 9Ch 58h 25h 01h 00h
Data in 1000:0240:
DB 10h 00h
BreakPoint: 1000:0110
Result:
AX=0001h

[BTC-complements-bit-in-memory-with-displacement-and-reports-old-value-in-CF]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h B9h 03h 00h 0Fh BBh 0Eh 30h 02h 9Ch 58h 25h 01h 00h 8Bh 1Eh 30h 02h
Data in 1000:0230:
DB 08h 00h
BreakPoint: 1000:0116
Result:
AX=0001h
BX=0000h

[BTR-clears-bit-in-memory-with-displacement-and-reports-old-value-in-CF]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h B9h 03h 00h 0Fh B3h 0Eh 20h 02h 9Ch 58h 25h 01h 00h 8Bh 1Eh 20h 02h
Data in 1000:0220:
DB 08h 00h
BreakPoint: 1000:0116
Result:
AX=0001h
BX=0000h

[BTS-sets-bit-in-memory-with-displacement-and-reports-old-value-in-CF]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h B9h 03h 00h 0Fh ABh 0Eh 10h 02h 9Ch 58h 25h 01h 00h 8Bh 1Eh 10h 02h
Data in 1000:0210:
DB 00h 00h
BreakPoint: 1000:0116
Result:
AX=0000h
BX=0008h

[CALL-near-then-RET-resumes-correct-address]
EntryPoint: 1000:0100
Data in 1000:0100:
DB E8h 04h 00h B0h 34h EBh 03h B4h 12h C3h
BreakPoint: 1000:010A
Result:
AX=1234h
SP=0000h

[CBW-sign-extends-AL-into-AX-both-directions]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B0h 7Fh 98h 89h C3h B0h 80h 98h
BreakPoint: 1000:0108
Result:
AX=FF80h
BX=007Fh

[CDQ-sign-extends-EAX-into-EDX-both-directions]
EntryPoint: 1000:0100
Data in 1000:0100:
DB 66h B8h 00h 00h 00h 80h 66h 99h 66h 89h D1h 66h B8h FFh FFh FFh 7Fh 66h 99h
BreakPoint: 1000:0113
Result:
ECX=FFFFFFFFh
EDX=00000000h

[CLC-clears-carry-verified-via-JNC-branch]
EntryPoint: 1000:0100
Data in 1000:0100:
DB F9h F8h 73h 05h B8h ADh 0Bh EBh 03h B8h 34h 12h
BreakPoint: 1000:010C
Result:
AX=1234h

[CLD-clears-direction-verified-via-STOSB-increment]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh C0h BFh 10h 00h B0h AAh FDh AAh FCh AAh
BreakPoint: 1000:010E
Result:
DI=0010h
ES=1000h

[CLI-clears-and-STI-sets-interrupt-flag-snapshots]
EntryPoint: 1000:0100
Data in 1000:0100:
DB FBh 9Ch 58h 25h 00h 02h 89h C1h FAh 9Ch 58h 25h 00h 02h 89h C2h
BreakPoint: 1000:0110
Result:
CX=0200h
DX=0000h

[CLTS-clears-only-the-task-switched-bit-of-CR0]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 09h 00h 0Fh 22h 00h 0Fh 06h 0Fh 20h 00h
BreakPoint: 1000:010B
Result:
AX=0001h

[CMC-toggles-carry-both-directions-verified-via-branch]
EntryPoint: 1000:0100
Data in 1000:0100:
DB F8h F5h 72h 05h BBh 00h 00h EBh 03h BBh 01h 00h F5h 73h 05h B9h 00h 00h EBh 03h B9h 02h 00h
BreakPoint: 1000:0117
Result:
BX=0001h
CX=0002h

[CMP-mem-operand-flags-both-directions]
Data in 1000:0300:
DB 05h 00h
Data in 1000:0302:
DB 03h 00h
Data in 1000:0304:
DB 0Fh
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h BBh 03h 00h 39h 1Eh 00h 03h 9Ch 58h 25h D1h 08h 89h C6h A1h 00h 03h 89h C7h B9h 01h 00h 3Bh 0Eh 02h 03h 9Ch 58h 25h D1h 08h 89h C5h B0h 10h 38h 06h 04h 03h 9Ch 58h 25h D1h 08h 89h C2h
BreakPoint: 1000:0133
Result:
SI=0000h
DI=0005h
BP=0091h
DX=0081h

[CMP-reg-reg-flags-full]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 05h 00h BBh 05h 00h 39h D8h 9Ch 5Eh 81h E6h D1h 08h B8h 03h 00h BBh 05h 00h 39h D8h 9Ch 5Fh 81h E7h D1h 08h B8h 05h 00h BBh 03h 00h 39h D8h 9Ch 5Dh 81h E5h D1h 08h B8h 00h 80h BBh 01h 00h 39h D8h 9Ch 5Ah 81h E2h D1h 08h
BreakPoint: 1000:0138
Result:
SI=0040h
DI=0091h
BP=0000h
DX=0810h

[CMP-regreg-JE-hang-repro]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 05h 00h BBh 05h 00h 39h D8h 74h 03h BBh 99h 99h B9h 01h 00h
BreakPoint: 1000:0110
Result:
AX=0005h
BX=0005h
CX=0001h

[CMP-sets-branch-flags-without-modifying-operands]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 05h 00h BBh 05h 00h 39h D8h 74h 05h B9h 00h 00h EBh 03h B9h 01h 00h B8h 03h 00h BBh 05h 00h 39h D8h 75h 05h BAh 00h 00h EBh 03h BAh 02h 00h
BreakPoint: 1000:0124
Result:
CX=0001h
DX=0002h
AX=0003h
BX=0005h

[CMPS-byte-with-FS-segment-override-compares-FS-SI-against-ES-DI]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh C0h B8h 00h 20h 8Eh E0h BEh 00h 03h BFh 00h 04h 64h A6h 9Ch 58h 25h 40h 00h
Data in 2000:0300:
DB 05h
Data in 1000:0400:
DB 05h
BreakPoint: 1000:0117
Result:
AX=0040h
SI=0301h
DI=0401h

[CMPSB-single-both-directions]
Data in 1000:0300:
DB 05h 03h
Data in 1000:0400:
DB 05h 05h
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h 8Eh C0h BEh 00h 03h BFh 00h 04h A6h 9Ch 58h 25h D1h 08h 89h C3h 89h F1h 89h FAh A6h 9Ch 58h 25h D1h 08h 89h C5h
BreakPoint: 1000:0121
Result:
BX=0040h
CX=0301h
DX=0401h
BP=0091h
SI=0302h
DI=0402h

[CMPSD-dword-both-directions]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h 8Eh C0h BEh 00h 05h BFh 00h 06h 66h A7h 9Ch 58h 25h 40h 00h
Data in 1000:0500:
DB 05h 00h 00h 00h
Data in 1000:0600:
DB 05h 00h 00h 00h
BreakPoint: 1000:0114
Result:
AX=0040h
SI=0504h
DI=0604h

[CMPSW-single-both-directions]
Data in 1000:0500:
DB 05h 00h 03h 00h
Data in 1000:0600:
DB 05h 00h 05h 00h
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h 8Eh C0h BEh 00h 05h BFh 00h 06h A7h 9Ch 58h 25h D1h 08h 89h C3h 89h F1h 89h FAh A7h 9Ch 58h 25h D1h 08h 89h C5h
BreakPoint: 1000:0121
Result:
BX=0040h
CX=0502h
DX=0602h
BP=0091h
SI=0504h
DI=0604h

[CMPXCHG-r-m16-r16-compares-memory-with-displacement-and-exchanges-on-match]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h B8h 05h 00h BAh AAh 00h 0Fh B1h 16h 90h 02h 8Bh 1Eh 90h 02h 9Ch 59h 81h E1h 40h 00h
Data in 1000:0290:
DB 05h 00h
BreakPoint: 1000:011A
Result:
AX=0005h
BX=00AAh
CX=0040h

[CMPXCHG-r-m8-r8-compares-memory-with-displacement-and-loads-AL-on-mismatch]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h B0h 11h B4h 00h B1h 99h 0Fh B0h 0Eh A0h 02h 8Bh 1Eh A0h 02h 9Ch 59h 81h E1h 40h 00h
Data in 1000:02A0:
DB 77h 00h
BreakPoint: 1000:011A
Result:
AX=0077h
BX=0077h
CX=0000h

[CWD-sign-extends-AX-into-DX-both-directions]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h FFh 7Fh 99h 89h D3h B8h 00h 80h 99h
BreakPoint: 1000:010A
Result:
DX=FFFFh
BX=0000h
AX=8000h

[CWDE-sign-extends-AX-into-full-EAX-both-directions]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 80h 66h 98h 66h 89h C1h B8h FFh 7Fh 66h 98h
BreakPoint: 1000:010D
Result:
ECX=FFFF8000h
EAX=00007FFFh

[DAA-Decimal-Adjust-Addition]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 08h 00h 04h 08h 27h 89h C3h 9Ch 58h 25h D1h 08h 89h C1h B8h 90h 00h 04h 90h 27h 89h C2h 9Ch 58h 25h D1h 08h 89h C6h
BreakPoint: 1000:011E
Result:
BX=0016h
CX=0010h
DX=0080h
SI=0881h

[DAA-adjusts-upper-nibble-only-without-AF]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 50h 00h 04h 50h 27h 89h C3h 9Ch 58h 25h 01h 00h 89h C1h
BreakPoint: 1000:010F
Result:
BX=0000h
CX=0001h

[DAS-Decimal-Adjust-Subtraction]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 16h 00h 2Ch 08h 2Fh 89h C3h 9Ch 58h 25h D1h 08h 89h C1h B8h 20h 00h 2Ch 30h 2Fh 89h C2h 9Ch 58h 25h D1h 08h 89h C6h
BreakPoint: 1000:011E
Result:
BX=0008h
CX=0010h
DX=0090h
SI=0081h

[DAS-adjusts-upper-nibble-only-without-AF]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h A5h 00h 2Ch 05h 2Fh 89h C3h 9Ch 58h 25h 01h 00h 89h C1h
BreakPoint: 1000:010F
Result:
BX=0040h
CX=0001h

[DEC-does-not-affect-carry-flag]
EntryPoint: 1000:0100
Data in 1000:0100:
DB F9h B8h 01h 00h 48h 72h 05h BBh 00h 00h EBh 03h BBh 01h 00h 74h 05h B9h 00h 00h EBh 03h B9h 02h 00h
BreakPoint: 1000:0119
Result:
AX=0000h
BX=0001h
CX=0002h

[DIV-by-zero-triggers-fault]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 64h 00h B3h 00h F6h F3h
ExpectedFault: DIVISION0
Result:
AX=0064h
IP=0105h

[DIV-unsigned-byte-and-word]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 64h 00h B3h 0Ah F6h F3h 89h C3h BAh 00h 00h B8h E8h 03h B9h 07h 00h F7h F1h 89h D1h
BreakPoint: 1000:0116
Result:
BX=000Ah
CX=0006h
AX=008Eh

[DIV-word-with-nonzero-DX-dividend-high-part]
EntryPoint: 1000:0100
Data in 1000:0100:
DB BAh 01h 00h B8h A0h 86h B9h 03h 00h F7h F1h
BreakPoint: 1000:010B
Result:
AX=8235h
DX=0001h
CX=0003h

[ENTER-chains-frame-pointer-for-nonzero-nesting-level]
EntryPoint: 1000:0100
Data in 1000:0100:
DB BCh 00h 00h C8h 04h 00h 00h 89h EEh 89h E7h BCh 00h 00h BDh 00h 00h C8h 06h 00h 01h
BreakPoint: 1000:0115
Result:
SI=FFFEh
DI=FFFAh
BP=FFFEh
SP=FFF6h

[ESC-FPU-stub-strict-nop-memory-untouched]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 5Ah 5Ah A3h 00h 03h D9h 3Eh 00h 03h 8Bh 1Eh 00h 03h
BreakPoint: 1000:010E
Result:
AX=5A5Ah
BX=5A5Ah

[HLT-sets-fault-and-preserves-registers]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 34h 12h F4h
ExpectedFault: HLT
Result:
AX=1234h
IP=0104h

[IDIV-negative-divisor-sign-handling]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 64h 00h B3h F6h F6h FBh 89h C3h BAh 00h 00h B8h E8h 03h B9h F9h FFh F7h F9h 89h D1h
BreakPoint: 1000:0116
Result:
BX=00F6h
CX=0006h
AX=FF72h

[IDIV-signed-byte-and-word-negative]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 9Ch FFh B3h 0Ah F6h FBh 89h C3h BAh FFh FFh B8h 18h FCh B9h 07h 00h F7h F9h 89h D1h
BreakPoint: 1000:0116
Result:
BX=00F6h
CX=FFFAh
AX=FF72h

[IMUL-r16-r-m16-multiplies-memory-value-with-displacement]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h BBh 07h 00h 0Fh AFh 1Eh 70h 02h 9Ch 58h 25h 01h 00h
Data in 1000:0270:
DB 06h 00h
BreakPoint: 1000:0112
Result:
BX=002Ah
AX=0000h

[IMUL-single-operand-overflow-flags-both-cases]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h FBh FFh B9h 03h 00h F7h E9h 89h C6h 89h D7h 9Ch 5Bh 81h E3h 01h 08h B8h 00h 10h B9h 00h 10h F7h E9h 9Ch 5Dh 81h E5h 01h 08h
BreakPoint: 1000:0120
Result:
SI=FFF1h
DI=FFFFh
BX=0000h
AX=0000h
DX=0100h
BP=0801h

[IN-unhandled-port-only-changes-AX]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 34h 12h BBh 78h 56h B9h BCh 9Ah BAh 57h 13h BEh 68h 24h BFh 9Ah 36h BDh 78h 56h E4h FFh E5h FEh
BreakPoint: 1000:0119
Result:
AX=0000h
BX=5678h
CX=9ABCh
DX=1357h
SI=2468h
DI=369Ah
BP=5678h

[INC-DEC-AuxiliaryFlag-regression]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B0h 0Fh FEh C0h 9Fh 80h E4h 10h 89h C3h B0h 01h FEh C0h 9Fh 80h E4h 10h 89h C1h B0h 10h FEh C8h 9Fh 80h E4h 10h 89h C2h B0h 02h FEh C8h 9Fh 80h E4h 10h
BreakPoint: 1000:0126
Result:
BX=1010h
CX=0002h
DX=100Fh
AX=0001h

[INC-signed-overflow-preserves-carry]
EntryPoint: 1000:0100
Data in 1000:0100:
DB F9h B8h FFh 7Fh 40h 72h 05h BBh 00h 00h EBh 03h BBh 01h 00h
BreakPoint: 1000:010F
Result:
AX=8000h
BX=0001h

[INC-signed-overflow-sets-OF-preserves-CF]
EntryPoint: 1000:0100
Data in 1000:0100:
DB F9h B8h FFh 7Fh 40h 72h 05h BBh 00h 00h EBh 03h BBh 01h 00h 70h 05h B9h 00h 00h EBh 03h B9h 02h 00h
BreakPoint: 1000:0119
Result:
AX=8000h
BX=0001h
CX=0002h

[INS-reads-port-into-ES-DI-and-advances-by-direction]
Data in 1000:0300:
DB AAh
Data in 1000:0500:
DB AAh AAh
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh C0h BFh 00h 03h BAh FFh 00h 6Ch 8Eh D8h A0h 00h 03h B4h 00h 89h C1h 89h FEh FDh BFh 00h 05h BAh FEh 00h 6Dh A1h 00h 05h
BreakPoint: 1000:0122
Result:
SI=0301h
CX=0000h
DI=04FEh
AX=0000h

[INSB-reads-unhandled-port-into-ES-DI-and-advances-by-one]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh C0h BFh 00h 03h BAh FFh 00h 6Ch 26h 8Ah 1Eh 00h 03h
BreakPoint: 1000:0111
Result:
DI=0301h
BX=0000h

[INSD-reads-unhandled-port-into-ES-DI-and-advances-by-four]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh C0h BFh 00h 05h BAh FFh 00h 66h 6Dh 26h 66h 8Bh 1Eh 00h 05h
BreakPoint: 1000:0113
Result:
DI=0504h
EBX=00000000h

[INSW-reads-unhandled-port-into-ES-DI-and-advances-by-two]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh C0h BFh 00h 04h BAh FFh 00h 6Dh 26h 8Bh 1Eh 00h 04h
BreakPoint: 1000:0111
Result:
DI=0402h
BX=0000h

[INT-custom-vector-dispatch]
Data in 0000:03C0:
DB 00h 02h 00h 10h
Data in 1000:0100:
DB CDh F0h
Data in 1000:0200:
DB B8h 34h 12h CFh
EntryPoint: 1000:0100
BreakPoint: 1000:0102
Result:
AX=1234h
CS=1000h
IP=0102h

[INT-immediate-dispatches-handler-and-returns]
Data in 0000:0040:
DB 00h 03h 00h 10h
Data in 1000:0100:
DB CDh 10h BBh 34h 12h
Data in 1000:0300:
DB B8h 78h 56h CFh
EntryPoint: 1000:0100
BreakPoint: 1000:0105
Result:
AX=5678h
BX=1234h
CS=1000h
IP=0105h

[INTO-overflow-dispatches-vector-four-handler]
Data in 0000:0010:
DB 00h 03h 00h 10h
Data in 1000:0100:
DB B8h FFh 7Fh BBh 01h 00h 01h D8h CEh BAh 34h 12h
Data in 1000:0300:
DB B9h 78h 56h CFh
EntryPoint: 1000:0100
BreakPoint: 1000:010C
Result:
AX=8000h
BX=0001h
CX=5678h
DX=1234h
CS=1000h
IP=010Ch

[IRET-restores-IP-CS-and-flags-from-stack]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 02h 50h B8h 00h 10h 50h B8h 08h 03h 50h CFh
Data in 1000:0308:
DB B8h 34h 12h
BreakPoint: 1000:030B
Result:
AX=1234h
CS=1000h
IP=030Bh

[IRETD-pops-32-bit-EIP-CS-and-EFLAGS-from-stack]
EntryPoint: 1000:0100
Data in 1000:0100:
DB 66h 68h 41h 00h 00h 00h 66h 68h 00h 20h 00h 00h 66h 68h 34h 12h 00h 00h 66h CFh
BreakPoint: 2000:1234
Result:
Flags=0041h
CS=2000h
IP=1234h

[JA-taken-when-above-unsigned]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 05h 00h BBh 03h 00h 39h D8h 77h 05h B9h 00h 00h EBh 03h B9h 01h 00h
BreakPoint: 1000:0112
Result:
AX=0005h
BX=0003h
CX=0001h

[JAE-taken-when-equal-unsigned]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 05h 00h BBh 05h 00h 39h D8h 73h 05h B9h 00h 00h EBh 03h B9h 01h 00h
BreakPoint: 1000:0112
Result:
AX=0005h
BX=0005h
CX=0001h

[JB-taken-when-below-unsigned]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 03h 00h BBh 05h 00h 39h D8h 72h 05h B9h 00h 00h EBh 03h B9h 01h 00h
BreakPoint: 1000:0112
Result:
AX=0003h
BX=0005h
CX=0001h

[JBE-taken-when-equal-unsigned]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 05h 00h BBh 05h 00h 39h D8h 76h 05h B9h 00h 00h EBh 03h B9h 01h 00h
BreakPoint: 1000:0112
Result:
AX=0005h
BX=0005h
CX=0001h

[JC-taken-when-carry-is-set]
EntryPoint: 1000:0100
Data in 1000:0100:
DB F9h 72h 05h BBh 00h 00h EBh 03h BBh 01h 00h
BreakPoint: 1000:010B
Result:
BX=0001h

[JE-taken-when-comparison-is-equal]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 05h 00h BBh 05h 00h 39h D8h 74h 05h B9h 00h 00h EBh 03h B9h 01h 00h
BreakPoint: 1000:0112
Result:
AX=0005h
BX=0005h
CX=0001h

[JECXZ-tests-zero-extended-CX-condition]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B9h 00h 00h E3h 05h B8h 00h 00h EBh 03h B8h 01h 00h
BreakPoint: 1000:010D
Result:
AX=0001h
CX=0000h

[JG-taken-when-signed-value-is-greater]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 05h 00h BBh 03h 00h 39h D8h 7Fh 05h B9h 00h 00h EBh 03h B9h 01h 00h
BreakPoint: 1000:0112
Result:
AX=0005h
BX=0003h
CX=0001h

[JGE-taken-when-signed-values-are-equal]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 05h 00h BBh 05h 00h 39h D8h 7Dh 05h B9h 00h 00h EBh 03h B9h 01h 00h
BreakPoint: 1000:0112
Result:
AX=0005h
BX=0005h
CX=0001h

[JL-taken-when-signed-value-is-less]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 03h 00h BBh 05h 00h 39h D8h 7Ch 05h B9h 00h 00h EBh 03h B9h 01h 00h
BreakPoint: 1000:0112
Result:
AX=0003h
BX=0005h
CX=0001h

[JLE-taken-when-signed-values-are-equal]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 05h 00h BBh 05h 00h 39h D8h 7Eh 05h B9h 00h 00h EBh 03h B9h 01h 00h
BreakPoint: 1000:0112
Result:
AX=0005h
BX=0005h
CX=0001h

[JMP-indirect-word-ptr-BX]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h BBh 00h 02h FFh 27h
Data in 1000:0200:
DB 00h 03h
Data in 1000:0300:
DB B8h 34h 12h
BreakPoint: 1000:0303
Result:
AX=1234h
BX=0200h
DS=1000h
IP=0303h

[JMP-near-relative-skips-over-instruction]
EntryPoint: 1000:0100
Data in 1000:0100:
DB E9h 03h 00h B8h ADh 0Bh B8h 34h 12h
BreakPoint: 1000:0109
Result:
AX=1234h
IP=0109h

[JNA-alias-taken-when-values-are-equal]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 05h 00h BBh 05h 00h 39h D8h 76h 05h B9h 00h 00h EBh 03h B9h 01h 00h
BreakPoint: 1000:0112
Result:
AX=0005h
BX=0005h
CX=0001h

[JNAE-alias-taken-when-value-is-below]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 03h 00h BBh 05h 00h 39h D8h 72h 05h B9h 00h 00h EBh 03h B9h 01h 00h
BreakPoint: 1000:0112
Result:
AX=0003h
BX=0005h
CX=0001h

[JNB-taken-when-carry-is-clear]
EntryPoint: 1000:0100
Data in 1000:0100:
DB F8h 73h 05h B8h 00h 00h EBh 03h B8h 01h 00h
BreakPoint: 1000:010B
Result:
AX=0001h

[JNC-taken-when-carry-is-clear]
EntryPoint: 1000:0100
Data in 1000:0100:
DB F8h 73h 05h B8h 00h 00h EBh 03h B8h 01h 00h
BreakPoint: 1000:010B
Result:
AX=0001h

[JNE-taken-when-values-are-different]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 03h 00h BBh 05h 00h 39h D8h 75h 05h B9h 00h 00h EBh 03h B9h 01h 00h
BreakPoint: 1000:0112
Result:
CX=0001h

[JNG-taken-when-values-are-equal]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 05h 00h BBh 05h 00h 39h D8h 7Eh 05h B9h 00h 00h EBh 03h B9h 01h 00h
BreakPoint: 1000:0112
Result:
CX=0001h

[JNGE-taken-when-signed-value-is-less]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 03h 00h BBh 05h 00h 39h D8h 7Ch 05h B9h 00h 00h EBh 03h B9h 01h 00h
BreakPoint: 1000:0112
Result:
CX=0001h

[JNL-taken-when-signed-values-are-equal]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 05h 00h BBh 05h 00h 39h D8h 7Dh 05h B9h 00h 00h EBh 03h B9h 01h 00h
BreakPoint: 1000:0112
Result:
CX=0001h

[JNLE-taken-when-signed-value-is-greater]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 05h 00h BBh 03h 00h 39h D8h 7Fh 05h B9h 00h 00h EBh 03h B9h 01h 00h
BreakPoint: 1000:0112
Result:
CX=0001h

[JNO-taken-when-overflow-is-clear]
EntryPoint: 1000:0100
Data in 1000:0100:
DB 31h C0h 71h 05h B8h 00h 00h EBh 03h B8h 01h 00h
BreakPoint: 1000:010C
Result:
AX=0001h

[JNP-taken-when-parity-is-clear]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 00h 40h 7Bh 05h B9h 00h 00h EBh 03h B9h 01h 00h
BreakPoint: 1000:010E
Result:
CX=0001h

[JNS-taken-when-sign-is-clear]
EntryPoint: 1000:0100
Data in 1000:0100:
DB 31h C0h 79h 05h B8h 00h 00h EBh 03h B8h 01h 00h
BreakPoint: 1000:010C
Result:
AX=0001h

[JNZ-taken-when-zero-flag-is-clear]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 03h 00h BBh 05h 00h 39h D8h 75h 05h B9h 00h 00h EBh 03h B9h 01h 00h
BreakPoint: 1000:0112
Result:
CX=0001h

[JO-taken-when-signed-overflow-is-set]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h FFh 7Fh BBh 01h 00h 01h D8h 70h 05h B9h 00h 00h EBh 03h B9h 01h 00h
BreakPoint: 1000:0112
Result:
AX=8000h
CX=0001h

[JP-taken-when-parity-is-set]
EntryPoint: 1000:0100
Data in 1000:0100:
DB 31h C0h 7Ah 05h B9h 00h 00h EBh 03h B9h 01h 00h
BreakPoint: 1000:010C
Result:
CX=0001h

[JPE-alias-taken-when-parity-is-set]
EntryPoint: 1000:0100
Data in 1000:0100:
DB 31h C0h 7Ah 05h B9h 00h 00h EBh 03h B9h 01h 00h
BreakPoint: 1000:010C
Result:
CX=0001h

[JPO-taken-when-parity-is-clear]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 00h 40h 7Bh 05h B9h 00h 00h EBh 03h B9h 01h 00h
BreakPoint: 1000:010E
Result:
CX=0001h

[JS-taken-when-sign-is-set]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 00h BBh 01h 00h 29h D8h 78h 05h B9h 00h 00h EBh 03h B9h 01h 00h
BreakPoint: 1000:0112
Result:
AX=FFFFh
CX=0001h

[JZ-taken-when-zero-flag-is-set]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 05h 00h BBh 05h 00h 39h D8h 74h 05h B9h 00h 00h EBh 03h B9h 01h 00h
BreakPoint: 1000:0112
Result:
CX=0001h

[LAHF-captures-known-zero-comparison-flags]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 00h BBh 00h 00h 39h D8h 9Fh
BreakPoint: 1000:0109
Result:
AX=4400h

[LAHF-loads-flags-into-AH]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 05h 00h 3Dh 05h 00h B0h 00h 9Fh 89h C3h B8h 03h 00h 3Dh 05h 00h B0h 00h 9Fh 89h C1h
BreakPoint: 1000:0116
Result:
BX=4400h
CX=9100h

[LAR-resolves-real-GDT-descriptor-loaded-via-LGDT]
Data in 1000:0300:
DB FFh 00h 00h 00h 03h 00h
Data in 3000:0000:
DB 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 9Ah 00h 00h 00h 00h 00h 00h 00h 1Ah 00h 00h
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h 0Fh 01h 16h 00h 03h BBh 34h 12h B9h 08h 00h 0Fh 02h D9h 9Ch 5Eh 81h E6h 40h 00h 89h DFh BBh 34h 12h B9h 10h 00h 0Fh 02h D9h 9Ch 58h 25h 40h 00h 89h C1h BBh 34h 12h B9h 00h 00h 0Fh 02h D9h 9Ch 58h 25h 40h 00h
BreakPoint: 1000:0139
Result:
SI=0040h
DI=9A00h
BX=1234h
CX=0000h
AX=0000h

[LDS-loads-reg-and-DS-from-farptr]
EntryPoint: 1000:0100
Data in 1000:0100:
DB C5h 1Eh 00h 03h
Data in 0000:0300:
DB 78h 56h 34h 12h
BreakPoint: 1000:0104
Result:
BX=5678h
DS=1234h

[LDS-loads-SI-and-DS-from-farptr]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h C5h 36h 00h 03h
Data in 1000:0300:
DB 34h 12h 78h 56h
BreakPoint: 1000:0109
Result:
SI=1234h
DS=5678h

[LEA-computes-base-index-disp-without-memory-read]
EntryPoint: 1000:0100
Data in 1000:0100:
DB BEh 10h 00h BBh 20h 00h 8Dh 40h 05h
BreakPoint: 1000:0109
Result:
AX=0035h
BX=0020h
SI=0010h

[LEA-computes-BP-SI-displacement]
EntryPoint: 1000:0100
Data in 1000:0100:
DB BDh 10h 00h BEh 20h 00h 8Dh 42h 05h
BreakPoint: 1000:0109
Result:
AX=0035h
BP=0010h
SI=0020h

[LEAVE-restores-SP-from-BP-and-pops-saved-BP]
EntryPoint: 1000:0100
Data in 1000:0100:
DB BDh 00h 03h C9h
Data in 0000:0300:
DB CDh ABh
BreakPoint: 1000:0104
Result:
SP=0302h
BP=ABCDh

[LES-LDS-farptr-load-cdev-pattern]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h C4h 1Eh 00h 03h C5h 16h 08h 03h
Data in 1000:0300:
DB 78h 56h 34h 12h
Data in 1000:0308:
DB AAh 99h 78h 56h
BreakPoint: 1000:010D
Result:
BX=5678h
ES=1234h
DX=99AAh
DS=5678h

[LES-loads-DI-and-ES-from-farptr]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h C4h 3Eh 00h 03h
Data in 1000:0300:
DB 78h 56h 34h 12h
BreakPoint: 1000:0109
Result:
DI=5678h
ES=1234h

[LFS-and-LGS-load-registers-from-far-pointers-in-memory-with-displacement]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h 0Fh B4h 0Eh C0h 02h 0Fh B5h 16h D0h 02h
Data in 1000:02C0:
DB 78h 56h 00h 30h
Data in 1000:02D0:
DB BCh 9Ah 00h 40h
BreakPoint: 1000:010F
Result:
CX=5678h
DX=9ABCh

[LGDT-loads-GdtBase-and-GdtLimit-verified-via-LAR-boundary]
Data in 1000:0300:
DB 0Fh 00h 00h 00h 04h 00h
Data in 4000:0000:
DB 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 9Ah 00h 00h
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h 0Fh 01h 16h 00h 03h BBh 34h 12h B9h 08h 00h 0Fh 02h D9h 9Ch 5Eh 81h E6h 40h 00h B9h 10h 00h 0Fh 02h D9h 9Ch 5Fh 81h E7h 40h 00h
BreakPoint: 1000:0125
Result:
BX=9A00h
SI=0040h
DI=0000h

[LIDT-consumes-memory-operand-with-displacement-as-real-mode-no-op]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h BBh 34h 12h 0Fh 01h 1Eh 00h 04h B9h 56h 78h
Data in 1000:0400:
DB 00h 00h 00h 00h 00h 00h
BreakPoint: 1000:0110
Result:
BX=1234h
CX=7856h

[LLDT-consumes-memory-operand-with-displacement-as-real-mode-no-op]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h BBh 34h 12h 0Fh 00h 16h 00h 04h B9h 56h 78h
Data in 1000:0400:
DB 00h 00h
BreakPoint: 1000:0110
Result:
BX=1234h
CX=7856h

[LMSW-loads-CR0-PE-from-memory-SMSW-reads-it-back-via-displacement]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h 0Fh 01h 36h 00h 02h 0Fh 01h 26h 00h 04h 8Bh 1Eh 00h 04h
Data in 1000:0200:
DB 01h 00h
BreakPoint: 1000:0113
Result:
BX=0001h

[LOADALL-80286-loads-full-state-and-descriptor-cache-base-from-fixed-address]
EntryPoint: 1000:0100
Data in 1000:0100:
DB 0Fh 05h
Data in 0000:0800:
DB 00h 00h 01h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 01h 00h 50h 00h 00h 00h 28h 00h 30h 00h 00h 20h 38h 00h 11h 11h 22h 22h 33h 33h 44h 44h 55h 55h 66h 66h 77h 77h 88h 88h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 05h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h
Data in 0000:0050:
DB 8Bh 1Eh 10h 00h
Data in 5000:0010:
DB EFh BEh
BreakPoint: 2000:0054
Result:
AX=8888h
BX=BEEFh
CX=7777h
DX=6666h
SI=2222h
DI=1111h
BP=3333h
SP=4444h
CS=2000h
DS=0028h
SS=0030h
ES=0038h
IP=0054h
Flags=0001h

[LOADALL-80386-loads-full-state-and-descriptor-cache-base-from-ES-EDI]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh C0h 66h BFh 00h 04h 00h 00h 0Fh 07h
Data in 1000:0400:
DB 01h 00h 00h 00h 01h 00h 00h 00h 60h 00h 00h 00h 11h 11h 11h 11h 22h 22h 22h 22h 33h 33h 33h 33h 44h 44h 44h 44h 55h 55h 55h 55h 66h 66h 66h 66h 77h 77h 77h 77h 88h 88h 88h 88h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 48h 00h 00h 00h 50h 00h 00h 00h 58h 00h 00h 00h 60h 00h 00h 00h 00h 30h 00h 00h 68h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 06h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h
Data in 0000:0060:
DB 8Bh 1Eh 20h 00h
Data in 6000:0020:
DB FEh CAh
BreakPoint: 3000:0064
Result:
AX=8888h
BX=CAFEh
CX=7777h
DX=6666h
SI=2222h
DI=1111h
BP=3333h
SP=4444h
CS=3000h
DS=0058h
SS=0060h
ES=0068h
IP=0064h
Flags=0001h

[LOCK-prefix-preserves-following-instruction-semantics]
EntryPoint: 1000:0100
Data in 1000:0100:
DB F0h B8h 34h 12h BBh 78h 56h
BreakPoint: 1000:0107
Result:
AX=1234h
BX=5678h

[LODS-word-with-segment-override-reads-from-ES-not-DS]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh C0h BEh 00h 40h 26h ADh
Data in 1000:4000:
DB 78h 56h
BreakPoint: 1000:010A
Result:
AX=5678h
SI=4002h
ES=1000h
DS=0000h

[LODSB-loads-DS-SI-and-increments-SI]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h BEh 00h 30h ACh
Data in 1000:3000:
DB A5h
BreakPoint: 1000:0109
Result:
AX=10A5h
SI=3001h
DS=1000h

[LODSD-loads-full-dword-and-increments-SI-by-four]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h BEh 00h 30h 66h ADh
Data in 1000:3000:
DB 78h 56h 34h 12h
BreakPoint: 1000:010A
Result:
EAX=12345678h
SI=3004h
DS=1000h

[LODSW-loads-word-and-increments-SI-by-two]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h BEh 00h 30h ADh
Data in 1000:3000:
DB 34h 12h
BreakPoint: 1000:0109
Result:
AX=1234h
SI=3002h
DS=1000h

[LOOP-decrements-CX-until-zero]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B9h 03h 00h 90h E2h FDh B8h 34h 12h
BreakPoint: 1000:0109
Result:
AX=1234h
CX=0000h

[LOOPD-decrements-ECX-until-zero]
EntryPoint: 1000:0100
Data in 1000:0100:
DB 66h B9h 03h 00h 00h 00h 90h 67h E2h FCh B8h 34h 12h
BreakPoint: 1000:010D
Result:
AX=1234h
ECX=00000000h

[LOOPE-repeats-while-CX-nonzero-and-ZF-set]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B9h 03h 00h 31h C0h E1h FCh B8h 78h 56h
BreakPoint: 1000:010A
Result:
AX=5678h
CX=0000h

[LOOPED-and-LOOPZD-repeat-while-ECX-nonzero-and-ZF-set]
EntryPoint: 1000:0100
Data in 1000:0100:
DB 66h B9h 03h 00h 00h 00h 31h C0h 67h E1h FBh B8h 78h 56h
BreakPoint: 1000:010E
Result:
AX=5678h
ECX=00000000h

[LOOPNE-stops-when-zero-flag-becomes-set]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B9h 02h 00h B8h 01h 00h 3Dh 00h 00h E0h FEh B8h 34h 12h
BreakPoint: 1000:010E
Result:
AX=1234h
CX=0000h

[LOOPNED-and-LOOPNZD-stop-when-zero-flag-becomes-set]
EntryPoint: 1000:0100
Data in 1000:0100:
DB 66h B9h 02h 00h 00h 00h B8h 01h 00h 3Dh 00h 00h 67h E0h FEh B8h 34h 12h
BreakPoint: 1000:0112
Result:
AX=1234h
ECX=00000000h

[LSS-loads-register-and-SS-from-far-pointer-in-memory-with-displacement]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h 0Fh B2h 1Eh B0h 02h
Data in 1000:02B0:
DB 34h 12h 00h 20h
BreakPoint: 1000:010A
Result:
BX=1234h
SS=2000h

[MOV-32-bit-general-registers-round-trip]
EntryPoint: 1000:0100
Data in 1000:0100:
DB 66h B8h 78h 56h 34h 12h 66h BBh 00h 00h 00h 00h 66h 89h C3h
BreakPoint: 1000:010F
Result:
BX=5678h

[MOV-EAX-moffs32-loads-doubleword]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h 66h 67h A1h 00h 30h 00h 00h
Data in 1000:3000:
DB 78h 56h 34h 12h
BreakPoint: 1000:010C
Result:
AX=5678h

[MOV-AX-FS-and-FS-AX-round-trip]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 34h 12h 8Eh E0h B8h 00h 00h 8Ch E0h
BreakPoint: 1000:010A
Result:
AX=1234h

[MOV-BX-GS-and-GS-BX-round-trip]
EntryPoint: 1000:0100
Data in 1000:0100:
DB BBh 78h 56h 8Eh EBh BBh 00h 00h 8Ch EBh
BreakPoint: 1000:010A
Result:
BX=5678h

[MOV-EAX-CR0-and-CR0-EAX-round-trip]
EntryPoint: 1000:0100
Data in 1000:0100:
DB 66h B8h 34h 12h 00h 00h 0Fh 22h C0h 66h B8h 00h 00h 00h 00h 0Fh 20h C0h
BreakPoint: 1000:0112
Result:
AX=1234h

[MOV-EAX-CR2-and-CR2-EAX-round-trip]
EntryPoint: 1000:0100
Data in 1000:0100:
DB 66h B8h 78h 56h 34h 12h 0Fh 22h D0h 66h B8h 00h 00h 00h 00h 0Fh 20h D0h
BreakPoint: 1000:0112
Result:
AX=5678h

[MOV-EAX-CR3-and-CR3-EAX-round-trip]
EntryPoint: 1000:0100
Data in 1000:0100:
DB 66h B8h 78h 56h 34h 12h 0Fh 22h D8h 66h B8h 00h 00h 00h 00h 0Fh 20h D8h
BreakPoint: 1000:0112
Result:
AX=5678h

[MOV-EAX-CR4-and-CR4-EAX-round-trip]
EntryPoint: 1000:0100
Data in 1000:0100:
DB 66h B8h 78h 56h 34h 12h 0Fh 22h E0h 66h B8h 00h 00h 00h 00h 0Fh 20h E0h
BreakPoint: 1000:0112
Result:
EAX=12345678h

[MOV-EAX-DR0-and-DR0-EAX-round-trip]
EntryPoint: 1000:0100
Data in 1000:0100:
DB 66h B8h 11h 11h 11h 11h 0Fh 23h C0h 66h B8h 00h 00h 00h 00h 0Fh 21h C0h
BreakPoint: 1000:0112
Result:
AX=1111h

[MOV-EAX-DR7-and-DR7-EAX-round-trip]
EntryPoint: 1000:0100
Data in 1000:0100:
DB 66h B8h 77h 77h 77h 77h 0Fh 23h F8h 66h B8h 00h 00h 00h 00h 0Fh 21h F8h
BreakPoint: 1000:0112
Result:
AX=7777h

[MOV-EAX-TR6-and-TR6-EAX-round-trip]
EntryPoint: 1000:0100
Data in 1000:0100:
DB 66h B8h 66h 66h 66h 66h 0Fh 26h F0h 66h B8h 00h 00h 00h 00h 0Fh 24h F0h
BreakPoint: 1000:0112
Result:
AX=6666h

[MOV-EAX-from-FS-override-with-32-bit-EBX-addressing]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 20h 8Eh E0h 66h BBh 10h 00h 00h 00h 64h 66h 67h 8Bh 03h
Data in 2000:0010:
DB 78h 56h 34h 12h
BreakPoint: 1000:0110
Result:
AX=5678h

[MOV-EAX-through-EDI-32-bit-immediates-verify-full-registers]
EntryPoint: 1000:0100
Data in 1000:0100:
DB 66h B8h 11h 11h 11h 11h 66h B9h 22h 22h 22h 22h 66h BAh 33h 33h 33h 33h 66h BBh 44h 44h 44h 44h 66h BCh 55h 55h 55h 55h 66h BDh 66h 66h 66h 66h 66h BEh 77h 77h 77h 77h 66h BFh 78h 56h 34h 12h
BreakPoint: 1000:0130
Result:
EAX=11111111h
ECX=22222222h
EDX=33333333h
EBX=44444444h
ESP=55555555h
EBP=66666666h
ESI=77777777h
EDI=12345678h

[MOV-ECX-from-GS-override-with-32-bit-ESI-addressing]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 30h 8Eh E8h 66h BEh 20h 00h 00h 00h 65h 66h 67h 8Bh 0Eh
Data in 3000:0020:
DB EFh CDh ABh 89h
BreakPoint: 1000:0110
Result:
CX=CDEFh

[MOVSX-sign-extends-byte-and-word-from-memory-with-displacement]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h 0Fh BEh 1Eh 00h 03h 0Fh BFh 0Eh 10h 03h
Data in 1000:0300:
DB 80h
Data in 1000:0310:
DB 00h 80h
BreakPoint: 1000:010F
Result:
BX=FF80h
CX=8000h

[MOVZX-zero-extends-byte-and-word-from-memory-with-displacement]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h 0Fh B6h 1Eh E0h 02h 0Fh B7h 0Eh F0h 02h
Data in 1000:02E0:
DB FFh
Data in 1000:02F0:
DB 34h 12h
BreakPoint: 1000:010F
Result:
BX=00FFh
CX=1234h

[SGDT-and-SIDT-write-real-GDTR-IDTR-loaded-by-LGDT-LIDT]
EntryPoint: 1000:0100
Data in 1000:0300:
DB FFh 00h 34h 12h 05h 00h
Data in 1000:0306:
DB EEh 00h 78h 56h 06h 00h
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h 0Fh 01h 16h 00h 03h 0Fh 01h 1Eh 06h 03h 0Fh 01h 06h 0Ch 03h 0Fh 01h 0Eh 12h 03h 8Bh 1Eh 0Ch 03h 8Bh 16h 12h 03h 8Bh 36h 0Eh 03h 8Bh 3Eh 14h 03h
BreakPoint: 1000:0129
Result:
BX=00FFh
DX=00EEh
SI=1234h
DI=5678h

[SHLD-shifts-memory-word-with-displacement-using-immediate-count]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h BBh 00h 80h 0Fh A4h 1Eh 50h 02h 04h 8Bh 0Eh 50h 02h 9Ch 58h 25h 01h 00h
Data in 1000:0250:
DB 01h 00h
BreakPoint: 1000:0117
Result:
CX=0018h
AX=0000h

[SHRD-shifts-memory-word-with-displacement-using-CL-count]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h BBh 01h 00h B1h 04h 0Fh ADh 1Eh 60h 02h 8Bh 0Eh 60h 02h 9Ch 58h 25h 01h 00h
Data in 1000:0260:
DB 00h 80h
BreakPoint: 1000:0118
Result:
CX=1800h
AX=0000h

[SLDT-and-LLDT-validate-against-GDT-and-accept-null-selector]
EntryPoint: 1000:0100
Data in 1000:0300:
DB 0Fh 00h 00h 00h 07h 00h
Data in 7000:0000:
DB 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 82h 00h 00h
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h 0Fh 01h 16h 00h 03h B9h 08h 00h 0Fh 00h D1h 0Fh 00h C0h 89h C2h B9h 00h 00h 0Fh 00h D1h 0Fh 00h C0h
BreakPoint: 1000:011E
Result:
DX=0008h
AX=0000h

[XADD-exchanges-and-adds-byte-and-word-in-memory-with-displacement]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h B1h 03h BAh 20h 00h 0Fh C0h 0Eh 40h 03h 0Fh C1h 16h 50h 03h 8Bh 1Eh 40h 03h 8Bh 3Eh 50h 03h
Data in 1000:0340:
DB 05h 00h
Data in 1000:0350:
DB 00h 01h
BreakPoint: 1000:011C
Result:
CX=0005h
DX=0100h
BX=0008h
DI=0120h
