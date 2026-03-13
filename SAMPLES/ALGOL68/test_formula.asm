; Genere par AL68C86 v1.0 - SAMPLES/ALGOL68/test_formula.a68

        .MODEL SMALL
        .STACK 1024

_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME  CS:_TEXT, DS:_DATA, SS:NOTHING

; --- point d'entree ---
_A68P_main:
        MOV   AX, _DATA
        MOV   DS, AX

; decl a : mode=0
        MOV    AX, 10
        SUB    SP, 2
        MOV    [BP-2], AX
; decl b : mode=0
        MOV    AX, 3
        SUB    SP, 2
        MOV    [BP-4], AX
; decl c : mode=0
        MOV    AX, [BP-2]
        PUSH   AX
        MOV    AX, [BP-4]
        MOV    BX, AX
        POP    AX
        ADD    AX, BX
        SUB    SP, 2
        MOV    [BP-6], AX
; decl d : mode=0
        MOV    AX, [BP-2]
        PUSH   AX
        MOV    AX, [BP-4]
        MOV    BX, AX
        POP    AX
        SUB    AX, BX
        SUB    SP, 2
        MOV    [BP-8], AX
; decl e : mode=0
        MOV    AX, [BP-2]
        PUSH   AX
        MOV    AX, [BP-4]
        MOV    BX, AX
        POP    AX
        IMUL   BX
        SUB    SP, 2
        MOV    [BP-10], AX
; decl f : mode=0
        MOV    AX, [BP-2]
        PUSH   AX
        MOV    AX, [BP-4]
        MOV    BX, AX
        POP    AX
        CWD
        IDIV   BX
        SUB    SP, 2
        MOV    [BP-12], AX
; decl g : mode=0
        MOV    AX, [BP-2]
        PUSH   AX
        MOV    AX, [BP-4]
        MOV    BX, AX
        POP    AX
        CWD
        IDIV   BX
        MOV    AX, DX
        SUB    SP, 2
        MOV    [BP-14], AX
; decl h : mode=0
        MOV    AX, 256
        SUB    SP, 2
        MOV    [BP-16], AX
; decl p : mode=2
        MOV    AX, [BP-2]
        PUSH   AX
        MOV    AX, 10
        MOV    BX, AX
        POP    AX
        CMP    AX, BX
        JE     _A68L_1
        XOR    AX, AX
        JMP    _A68L_2
_A68L_1:
        MOV    AX, 1
_A68L_2:
        SUB    SP, 1
        MOV    BYTE PTR [BP-18], AL
; decl q : mode=2
        MOV    AX, [BP-2]
        PUSH   AX
        MOV    AX, [BP-4]
        MOV    BX, AX
        POP    AX
        CMP    AX, BX
        JNE    _A68L_3
        XOR    AX, AX
        JMP    _A68L_4
_A68L_3:
        MOV    AX, 1
_A68L_4:
        SUB    SP, 1
        MOV    BYTE PTR [BP-20], AL
; decl r : mode=2
        MOV    AX, [BP-2]
        PUSH   AX
        MOV    AX, 20
        MOV    BX, AX
        POP    AX
        CMP    AX, BX
        JL     _A68L_5
        XOR    AX, AX
        JMP    _A68L_6
_A68L_5:
        MOV    AX, 1
_A68L_6:
        SUB    SP, 1
        MOV    BYTE PTR [BP-22], AL
; decl s : mode=2
        MOV    AX, [BP-2]
        PUSH   AX
        MOV    AX, 10
        MOV    BX, AX
        POP    AX
        CMP    AX, BX
        JLE    _A68L_7
        XOR    AX, AX
        JMP    _A68L_8
_A68L_7:
        MOV    AX, 1
_A68L_8:
        SUB    SP, 1
        MOV    BYTE PTR [BP-24], AL
; decl t : mode=2
        MOV    AX, [BP-4]
        PUSH   AX
        MOV    AX, 1
        MOV    BX, AX
        POP    AX
        CMP    AX, BX
        JG     _A68L_9
        XOR    AX, AX
        JMP    _A68L_10
_A68L_9:
        MOV    AX, 1
_A68L_10:
        SUB    SP, 1
        MOV    BYTE PTR [BP-26], AL
; decl u : mode=2
        MOV    AX, [BP-4]
        PUSH   AX
        MOV    AX, 3
        MOV    BX, AX
        POP    AX
        CMP    AX, BX
        JGE    _A68L_11
        XOR    AX, AX
        JMP    _A68L_12
_A68L_11:
        MOV    AX, 1
_A68L_12:
        SUB    SP, 1
        MOV    BYTE PTR [BP-28], AL
; decl v : mode=2
        MOV    AX, 0
        SUB    SP, 1
        MOV    BYTE PTR [BP-30], AL
; decl w : mode=2
        MOV    AX, 1
        SUB    SP, 1
        MOV    BYTE PTR [BP-32], AL
; decl x : mode=2
        MOV    AX, 0
        SUB    SP, 1
        MOV    BYTE PTR [BP-34], AL
; decl bv : mode=4
        MOV    AX, 255
        SUB    SP, 2
        MOV    [BP-36], AX
; decl shifted : mode=0
        MOV    AX, [BP-2]
        PUSH   AX
        MOV    AX, 2
        MOV    BX, AX
        POP    AX
        MOV    CL, BL
        SAL    AX, CL
        SUB    SP, 2
        MOV    [BP-38], AX
; decl rshift : mode=0
        MOV    AX, [BP-2]
        PUSH   AX
        MOV    AX, 1
        MOV    BX, AX
        POP    AX
        MOV    CL, BL
        SAR    AX, CL
        SUB    SP, 2
        MOV    [BP-40], AX
        MOV    AX, [BP-2]
        PUSH   AX
        MOV    AX, 5
        MOV    BX, AX
        POP    AX
        ADD    AX, BX
        MOV    [BP-2], AX
        MOV    AX, [BP-4]
        PUSH   AX
        MOV    AX, 1
        MOV    BX, AX
        POP    AX
        SUB    AX, BX
        MOV    [BP-4], AX
        MOV    AX, [BP-6]
        PUSH   AX
        MOV    AX, 2
        MOV    BX, AX
        POP    AX
        IMUL   BX
        MOV    [BP-6], AX
        MOV    AX, [BP-8]
        PUSH   AX
        MOV    AX, 2
        MOV    BX, AX
        POP    AX
        CWD
        IDIV   BX
        MOV    [BP-8], AX
; decl s1 : mode=5
        LEA    AX, _A68K_13
        SUB    SP, 2
        MOV    [BP-42], AX
; decl s2 : mode=5
        LEA    AX, _A68K_14
        SUB    SP, 2
        MOV    [BP-44], AX

; --- sortie DOS ---
        MOV    AX, 4C00h
        INT    21h


_TEXT   ENDS


_DATA   SEGMENT WORD PUBLIC 'DATA'
        ASSUME  DS:_DATA
_A68_TRUE_S:
        DB      'TRUE',0
_A68_FALSE_S:
        DB      'FALSE',0
_A68_NIL_S:
        DB      'NIL',0
_A68_CRLF:
        DB      13,10,0
_A68_STRBUF:
        DB      256 DUP(0)
_A68_STRPOOL:
        DB      1024 DUP(0)
_A68_STRPOOL_TOP:
        DW      0
_A68K_13:
        DB      'hello',0
_A68K_14:
        DB      'world',0
_DATA   ENDS

        END _A68P_main
