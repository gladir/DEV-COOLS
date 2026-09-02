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
