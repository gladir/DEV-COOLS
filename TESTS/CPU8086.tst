[Sanity-MOV-immediat]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 34h 12h BBh 78h 56h
BreakPoint: 1000:0106
Result:
AX=1234h
BX=5678h

[STOSW-INC-INC-LOOP-seg-reinit]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh C0h BFh 00h 02h B9h 04h 00h B8h AAh 55h ABh 47h 47h E2h FBh
BreakPoint: 1000:0113
Result:
AX=55AAh
CX=0000h
DI=0210h
ES=1000h

[CMP-regreg-JE-hang-repro]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 05h 00h BBh 05h 00h 39h D8h 74h 03h BBh 99h 99h B9h 01h 00h
BreakPoint: 1000:0110
Result:
AX=0005h
BX=0005h
CX=0001h

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

[ES-segment-override-MOV]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 20h 8Eh C0h BFh 00h 04h B0h 42h 26h 88h 05h BBh 00h 00h 8Ah 1Dh B9h 00h 00h 26h 8Ah 0Dh
BreakPoint: 1000:0118
Result:
BX=00F6h
CX=0042h
ES=2000h
IP=0118h

[REP-MOVSW-relocation-sysinit1]
Data in 1000:0300:
DB 11h 22h 33h 44h 55h 66h 77h 88h
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h 8Eh C0h BEh 00h 03h BFh 00h 05h B9h 04h 00h F3h A5h A1h 00h 05h
BreakPoint: 1000:0115
Result:
AX=2211h
SI=0308h
DI=0508h
CX=0000h
DS=1000h
ES=1000h

[PUSH-fabricated-far-ptr-RETF]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 50h B8h 00h 02h 50h CBh
Data in 1000:0200:
DB B9h 34h 12h
BreakPoint: 1000:0203
Result:
CX=1234h
CS=1000h
IP=0203h

[MOV-direct-disp16-modRM00rm110]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 34h 12h 89h 06h 70h 01h B8h 00h 00h A1h 70h 01h
BreakPoint: 1000:010D
Result:
AX=1234h

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

[Offset-wraparound-FFFF-STOSW-spills-to-next-segment]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh C0h BFh FFh FFh B8h CDh ABh ABh B8h 00h 20h 8Eh C0h B8h 00h 00h 26h A1h 00h 00h
BreakPoint: 1000:0118
Result:
DI=0001h
AX=F6ABh
ES=2000h

[SegOverride-leak-across-indirect-JMP-regression]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 20h 8Eh D0h BDh 50h 00h 2Eh FFh 26h 30h 01h
Data in 1000:0130:
DB 40h 01h
Data in 1000:0050:
DB CDh AAh
Data in 2000:0050:
DB 34h 12h
Data in 1000:0140:
DB 8Bh 76h 00h
BreakPoint: 1000:0143
Result:
SI=1234h
SS=2000h
BP=0050h

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

[TEST-reg-mem-flags]
Data in 1000:0400:
DB 80h 00h
Data in 1000:0402:
DB 00h 80h
Data in 1000:0404:
DB 00h FFh
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h B8h FFh 00h 85h 06h 00h 04h 9Ch 5Bh 81h E3h C1h 08h 89h C6h B8h 00h 80h 85h 06h 02h 04h 9Ch 59h 81h E1h C1h 08h B8h FFh 00h 85h 06h 04h 04h 9Ch 5Ah 81h E2h C1h 08h
BreakPoint: 1000:012E
Result:
SI=00FFh
BX=0000h
CX=0080h
DX=0040h

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

[REP-CMPSB-stops-early-on-mismatch]
Data in 1000:0300:
DB 11h 22h 99h 44h
Data in 1000:0400:
DB 11h 22h 33h 44h
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h 8Eh C0h BEh 00h 03h BFh 00h 04h B9h 04h 00h F3h A6h 9Ch 58h 25h 40h 00h 89h C3h
BreakPoint: 1000:0119
Result:
CX=0001h
SI=0303h
DI=0403h
BX=0000h

[REP-CMPSW-stops-early-on-mismatch]
Data in 1000:0500:
DB 11h 11h 22h 22h 99h 99h 44h 44h
Data in 1000:0600:
DB 11h 11h 22h 22h 33h 33h 44h 44h
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh D8h 8Eh C0h BEh 00h 05h BFh 00h 06h B9h 04h 00h F3h A7h 9Ch 58h 25h 40h 00h 89h C3h
BreakPoint: 1000:0119
Result:
CX=0001h
SI=0506h
DI=0606h
BX=0000h

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

[SUB-reg-reg-flags-full]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 05h 00h BBh 03h 00h 29h D8h 89h C7h 9Ch 58h 25h D1h 08h 89h C5h B8h 03h 00h BBh 05h 00h 29h D8h 89h C6h 9Ch 58h 25h D1h 08h 89h C2h B8h 00h 80h BBh 01h 00h 29h D8h 89h C1h 9Ch 58h 25h D1h 08h 89h C3h
BreakPoint: 1000:0133
Result:
DI=0002h
BP=0000h
SI=FFFEh
DX=0091h
CX=7FFFh
BX=0810h

[LAHF-loads-flags-into-AH]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 05h 00h 3Dh 05h 00h B0h 00h 9Fh 89h C3h B8h 03h 00h 3Dh 05h 00h B0h 00h 9Fh 89h C1h
BreakPoint: 1000:0116
Result:
BX=4400h
CX=9100h

[SAHF-loads-AH-into-flags-affects-JZ]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B4h 44h 9Eh B9h 00h 00h 74h 03h B9h 99h 99h BAh 11h 11h B4h 00h 9Eh BBh 00h 00h 74h 03h BBh 99h 99h BEh 22h 22h
BreakPoint: 1000:011C
Result:
CX=0000h
DX=1111h
BX=9999h
SI=2222h
