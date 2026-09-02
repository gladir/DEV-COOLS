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

[CLTS-clears-only-the-task-switched-bit-of-CR0]
EntryPoint: 1000:0100
Data in 1000:0100:
DB B8h 09h 00h 0Fh 22h 00h 0Fh 06h 0Fh 20h 00h
BreakPoint: 1000:010B
Result:
AX=0001h

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
