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

[Offset-wraparound-FFFF-STOSW-spills-to-next-segment]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 00h 10h 8Eh C0h BFh FFh FFh B8h CDh ABh ABh B8h 00h 20h 8Eh C0h B8h 00h 00h 26h A1h 00h 00h
BreakPoint: 1000:0118
Result:
DI=0001h
AX=F6ABh
ES=2000h
