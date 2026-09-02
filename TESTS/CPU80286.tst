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

[CWD-sign-extends-AX-into-DX-both-directions]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h FFh 7Fh 99h 89h D3h B8h 00h 80h 99h
BreakPoint: 1000:010A
Result:
DX=FFFFh
BX=0000h
AX=8000h

[DAA-adjusts-upper-nibble-only-without-AF]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 50h 00h 04h 50h 27h 89h C3h 9Ch 58h 25h 01h 00h 89h C1h
BreakPoint: 1000:010F
Result:
BX=0000h
CX=0001h

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

[DAS-adjusts-upper-nibble-only-without-AF]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h A5h 00h 2Ch 05h 2Fh 89h C3h 9Ch 58h 25h 01h 00h 89h C1h
BreakPoint: 1000:010F
Result:
BX=0040h
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

[ES-segment-override-MOV]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 20h 8Eh C0h BFh 00h 04h B0h 42h 26h 88h 05h BBh 00h 00h 8Ah 1Dh B9h 00h 00h 26h 8Ah 0Dh
BreakPoint: 1000:0118
Result:
BX=00F6h
CX=0042h
ES=2000h

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

[JAE-taken-when-equal-unsigned]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 05h 00h BBh 05h 00h 39h D8h 73h 05h B9h 00h 00h EBh 03h B9h 01h 00h
BreakPoint: 1000:0112
Result:
AX=0005h
BX=0005h
CX=0001h

[JA-taken-when-above-unsigned]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 05h 00h BBh 03h 00h 39h D8h 77h 05h B9h 00h 00h EBh 03h B9h 01h 00h
BreakPoint: 1000:0112
Result:
AX=0005h
BX=0003h
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

[JB-taken-when-below-unsigned]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 03h 00h BBh 05h 00h 39h D8h 72h 05h B9h 00h 00h EBh 03h B9h 01h 00h
BreakPoint: 1000:0112
Result:
AX=0003h
BX=0005h
CX=0001h

[JC-taken-when-carry-is-set]
EntryPoint: 1000:0100
Data in 1000:0100:
DB F9h 72h 05h BBh 00h 00h EBh 03h BBh 01h 00h
BreakPoint: 1000:010B
Result:
BX=0001h

[JCXZ-taken-when-CX-is-zero]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B9h 00h 00h E3h 05h B8h 00h 00h EBh 03h B8h 01h 00h
BreakPoint: 1000:010D
Result:
AX=0001h
CX=0000h

[JE-taken-when-comparison-is-equal]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 05h 00h BBh 05h 00h 39h D8h 74h 05h B9h 00h 00h EBh 03h B9h 01h 00h
BreakPoint: 1000:0112
Result:
AX=0005h
BX=0005h
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

[JG-taken-when-signed-value-is-greater]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 05h 00h BBh 03h 00h 39h D8h 7Fh 05h B9h 00h 00h EBh 03h B9h 01h 00h
BreakPoint: 1000:0112
Result:
AX=0005h
BX=0003h
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

[JL-taken-when-signed-value-is-less]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 03h 00h BBh 05h 00h 39h D8h 7Ch 05h B9h 00h 00h EBh 03h B9h 01h 00h
BreakPoint: 1000:0112
Result:
AX=0003h
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

[JNGE-taken-when-signed-value-is-less]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 03h 00h BBh 05h 00h 39h D8h 7Ch 05h B9h 00h 00h EBh 03h B9h 01h 00h
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

[JNLE-taken-when-signed-value-is-greater]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 05h 00h BBh 03h 00h 39h D8h 7Fh 05h B9h 00h 00h EBh 03h B9h 01h 00h
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

[JP-taken-when-parity-is-set]
EntryPoint: 1000:0100
Data in 1000:0100:
DB 31h C0h 7Ah 05h B9h 00h 00h EBh 03h B9h 01h 00h
BreakPoint: 1000:010C
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

[LOOPE-repeats-while-CX-nonzero-and-ZF-set]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B9h 03h 00h 31h C0h E1h FCh B8h 78h 56h
BreakPoint: 1000:010A
Result:
AX=5678h
CX=0000h

[LOOPNE-stops-when-zero-flag-becomes-set]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B9h 02h 00h B8h 01h 00h 3Dh 00h 00h E0h FEh B8h 34h 12h
BreakPoint: 1000:010E
Result:
AX=1234h
CX=0000h

[LSL-resolves-real-GDT-limit-with-granularity-and-fails-on-invalid-selector]
EntryPoint: 1000:0100
Data in 1000:0300:
DB 17h 00h 00h 00h 05h 00h
Data in 5000:0000:
DB 00h 00h 00h 00h 00h 00h 00h 00h 00h 01h 00h 00h 00h 9Ah 00h 00h 00h 00h 00h 00h 00h 9Ah 80h 00h
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h 0Fh 01h 16h 00h 03h BBh 34h 12h B9h 08h 00h 0Fh 03h D9h 9Ch 5Eh 81h E6h 40h 00h 89h DAh BBh 34h 12h B9h 10h 00h 0Fh 03h D9h 9Ch 5Fh 81h E7h 40h 00h 89h DDh BBh 34h 12h B9h 18h 00h 0Fh 03h D9h 9Ch 58h 25h 40h 00h
BreakPoint: 1000:013A
Result:
BX=1234h
CX=0018h
DX=0100h
SI=0040h
BP=0FFFh
DI=0040h
AX=0000h

[LTR-validates-selector-against-GDT-and-marks-descriptor-busy]
EntryPoint: 1000:0100
Data in 1000:0300:
DB 0Fh 00h 00h 00h 06h 00h
Data in 6000:0000:
DB 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 00h 89h 00h 00h
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h 0Fh 01h 16h 00h 03h B9h 08h 00h 0Fh 00h D9h 0Fh 00h C8h 89h C2h B8h 00h 60h 8Eh D8h 8Ah 1Eh 0Dh 00h B9h 18h 00h 0Fh 00h D9h 0Fh 00h C8h
BreakPoint: 1000:0127
Result:
DX=0008h
BX=008Bh
AX=0008h
CX=0018h

[MOV-direct-disp16-modRM00rm110]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 34h 12h 89h 06h 70h 01h B8h 00h 00h A1h 70h 01h
BreakPoint: 1000:010D
Result:
AX=1234h

[MOV-moffs8-AL-and-moffs16-AX-write-directions]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h B0h 42h A2h 00h 04h B8h 34h 12h A3h 02h 04h 8Ah 1Eh 00h 04h B7h 00h 8Bh 0Eh 02h 04h
BreakPoint: 1000:011A
Result:
BX=0042h
CX=1234h

[MOV-AL-moffs8-and-AX-moffs16-load-directions]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h A0h 00h 03h B4h 00h A1h 02h 03h
Data in 1000:0300:
DB A5h 00h 34h 12h
BreakPoint: 1000:010D
Result:
AX=1234h
DS=1000h

[MOV-r-m16-imm16-writes-memory-word]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h C7h 06h 00h 03h 34h 12h 8Bh 1Eh 00h 03h
BreakPoint: 1000:010F
Result:
BX=1234h

[MOV-r-m8-imm8-writes-memory-byte]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h C6h 06h 00h 03h 42h B5h 00h 8Ah 0Eh 00h 03h
BreakPoint: 1000:0110
Result:
CX=0042h

[MOV-r16-from-memory-via-general-ModRM]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h 8Bh 1Eh 00h 03h
Data in 1000:0300:
DB 34h 12h
BreakPoint: 1000:0109
Result:
BX=1234h

[MOV-r8-imm8-loads-all-eight-byte-registers]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B0h 11h B4h 22h B1h 33h B5h 44h B2h 55h B6h 66h B3h 77h B7h 88h
BreakPoint: 1000:0110
Result:
AX=2211h
CX=4433h
DX=6655h
BX=8877h

[MOV-register-to-register-preserves-value]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 34h 12h BBh 78h 56h 89h D8h
BreakPoint: 1000:0108
Result:
AX=5678h
BX=5678h

[MOV-segment-register-from-memory-operand]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h 8Eh 16h 00h 03h
Data in 1000:0300:
DB 00h 20h
BreakPoint: 1000:0109
Result:
SS=2000h

[MOVmemCS-reload-CMP-JE-hang-repro]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B9h 00h 00h BFh 00h 03h 8Ch 0Dh 8Bh 1Dh 8Ch C8h 39h D8h 74h 03h B9h 99h 99h BAh 11h 11h
BreakPoint: 1000:0116
Result:
AX=1000h
BX=1000h
CX=0000h
DX=1111h

[MOVmemCS-then-INT-dispatch]
Data in 0000:03C4:
DB 00h 03h 00h 10h
Data in 1000:0100:
DB BFh 00h 05h 8Ch 0Dh CDh F1h
Data in 1000:0300:
DB B8h 78h 56h CFh
EntryPoint: 1000:0100
BreakPoint: 1000:0107
Result:
AX=5678h
CS=1000h
IP=0107h

[OUTSB-and-OUTSW-write-port-from-DS-SI-leave-memory-untouched]
Data in 1000:0300:
DB AAh
Data in 1000:0500:
DB BBh BBh
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h BEh 00h 03h BAh FFh 00h 6Eh A0h 00h 03h B4h 00h 89h C1h 89h F7h FDh BEh 00h 05h BAh FEh 00h 6Fh A1h 00h 05h
BreakPoint: 1000:0120
Result:
CX=00AAh
DI=0301h
AX=BBBBh
SI=04FEh

[Sanity-MOV-immediat]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 34h 12h BBh 78h 56h
BreakPoint: 1000:0106
Result:
AX=1234h
BX=5678h
