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

[JECXZ-tests-zero-extended-CX-condition]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B9h 00h 00h E3h 05h B8h 00h 00h EBh 03h B8h 01h 00h
BreakPoint: 1000:010D
Result:
AX=0001h
CX=0000h

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
