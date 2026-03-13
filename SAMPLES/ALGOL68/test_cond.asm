; Genere par AL68C86 v1.0 - SAMPLES/ALGOL68/test_cond.a68

        .MODEL SMALL
        .STACK 1024

_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME  CS:_TEXT, DS:_DATA, SS:NOTHING

; --- point d'entree ---
_A68P_main:
        MOV   AX, _DATA
        MOV   DS, AX

; decl a : mode=0
        MOV    AX, 1
        TEST   AX, AX
        JZ     _A68L_ELSE_1
        MOV    AX, 42
        JMP    _A68L_FI_1
_A68L_ELSE_1:
        MOV    AX, 0
_A68L_FI_1:
        SUB    SP, 2
        MOV    [BP-2], AX
; decl b : mode=0
        MOV    AX, 0
        TEST   AX, AX
        JZ     _A68L_ELSE_2
        MOV    AX, 1
        JMP    _A68L_FI_2
_A68L_ELSE_2:
        MOV    AX, 99
_A68L_FI_2:
        SUB    SP, 2
        MOV    [BP-4], AX
; decl c : mode=0
        MOV    AX, 2
        SUB    SP, 2
        MOV    [BP-6], AX
; decl d : mode=0
        MOV    AX, [BP-6]
        PUSH   AX
        MOV    AX, 1
        MOV    BX, AX
        POP    AX
        CMP    AX, BX
        JE     _A68L_1
        XOR    AX, AX
        JMP    _A68L_2
_A68L_1:
        MOV    AX, 1
_A68L_2:
        TEST   AX, AX
        JZ     _A68L_ELSE_3
        MOV    AX, 10
        JMP    _A68L_FI_3
_A68L_ELSE_3:
        MOV    AX, [BP-6]
        PUSH   AX
        MOV    AX, 2
        MOV    BX, AX
        POP    AX
        CMP    AX, BX
        JE     _A68L_3
        XOR    AX, AX
        JMP    _A68L_4
_A68L_3:
        MOV    AX, 1
_A68L_4:
        TEST   AX, AX
        JZ     _A68L_ELSE_4
        MOV    AX, 20
        JMP    _A68L_FI_4
_A68L_ELSE_4:
        MOV    AX, [BP-6]
        PUSH   AX
        MOV    AX, 3
        MOV    BX, AX
        POP    AX
        CMP    AX, BX
        JE     _A68L_5
        XOR    AX, AX
        JMP    _A68L_6
_A68L_5:
        MOV    AX, 1
_A68L_6:
        TEST   AX, AX
        JZ     _A68L_ELSE_5
        MOV    AX, 30
        JMP    _A68L_FI_5
_A68L_ELSE_5:
        MOV    AX, 0
_A68L_FI_5:
_A68L_FI_4:
_A68L_FI_3:
        SUB    SP, 2
        MOV    [BP-8], AX
        MOV    AX, 1
        TEST   AX, AX
        JZ     _A68L_ELSE_6
        XOR    AX, AX
        JMP    _A68L_FI_6
_A68L_ELSE_6:
_A68L_FI_6:
; decl e : mode=0
        MOV    AX, 2
        SUB    SP, 2
        MOV    [BP-10], AX
; decl f : mode=0
        MOV    AX, [BP-10]
        MOV    BX, AX
        CMP    BX, 1
        JNE    _A68L_CASE_1_1
        MOV    AX, 10
        JMP    _A68L_CESAC_1
_A68L_CASE_1_1:
        CMP    BX, 2
        JNE    _A68L_CASE_1_2
        MOV    AX, 20
        JMP    _A68L_CESAC_1
_A68L_CASE_1_2:
        CMP    BX, 3
        JNE    _A68L_CASE_1_3
        MOV    AX, 30
        JMP    _A68L_CESAC_1
_A68L_CASE_1_3:
_A68L_CESAC_1:
        SUB    SP, 2
        MOV    [BP-12], AX
; decl g : mode=0
        MOV    AX, 9
        SUB    SP, 2
        MOV    [BP-14], AX
; decl h : mode=0
        MOV    AX, [BP-14]
        MOV    BX, AX
        CMP    BX, 1
        JNE    _A68L_CASE_2_1
        MOV    AX, 10
        JMP    _A68L_CESAC_2
_A68L_CASE_2_1:
        CMP    BX, 2
        JNE    _A68L_CASE_2_2
        MOV    AX, 20
        JMP    _A68L_CESAC_2
_A68L_CASE_2_2:
        CMP    BX, 3
        JNE    _A68L_CASE_2_3
        MOV    AX, 30
        JMP    _A68L_CESAC_2
_A68L_CASE_2_3:
        MOV    AX, 99
_A68L_CESAC_2:
        SUB    SP, 2
        MOV    [BP-16], AX
; decl p : mode=2
        MOV    AX, 1
        SUB    SP, 1
        MOV    BYTE PTR [BP-18], AL
; decl i : mode=0
        MOV    AX, [BP-18]
        TEST   AX, AX
        JZ     _A68L_ELSE_7
        MOV    AX, 42
        JMP    _A68L_FI_7
_A68L_ELSE_7:
        MOV    AX, 0
_A68L_FI_7:
        SUB    SP, 2
        MOV    [BP-20], AX
; decl q : mode=2
        MOV    AX, 0
        SUB    SP, 1
        MOV    BYTE PTR [BP-22], AL
; decl j : mode=0
        MOV    AX, [BP-22]
        TEST   AX, AX
        JZ     _A68L_ELSE_8
        MOV    AX, 1
        JMP    _A68L_FI_8
_A68L_ELSE_8:
        MOV    AX, 99
_A68L_FI_8:
        SUB    SP, 2
        MOV    [BP-24], AX
; decl k : mode=0
        MOV    AX, 2
        SUB    SP, 2
        MOV    [BP-26], AX
; decl l : mode=0
        MOV    AX, [BP-26]
        MOV    BX, AX
        CMP    BX, 1
        JNE    _A68L_CASE_3_1
        MOV    AX, 10
        JMP    _A68L_CESAC_3
_A68L_CASE_3_1:
        CMP    BX, 2
        JNE    _A68L_CASE_3_2
        MOV    AX, 20
        JMP    _A68L_CESAC_3
_A68L_CASE_3_2:
        CMP    BX, 3
        JNE    _A68L_CASE_3_3
        MOV    AX, 30
        JMP    _A68L_CESAC_3
_A68L_CASE_3_3:
        MOV    AX, 0
_A68L_CESAC_3:
        SUB    SP, 2
        MOV    [BP-28], AX
; decl m : mode=0
        MOV    AX, 5
        SUB    SP, 2
        MOV    [BP-30], AX
; decl n : mode=0
        MOV    AX, [BP-30]
        MOV    BX, AX
        CMP    BX, 1
        JNE    _A68L_CASE_4_1
        MOV    AX, 10
        JMP    _A68L_CESAC_4
_A68L_CASE_4_1:
        CMP    BX, 2
        JNE    _A68L_CASE_4_2
        MOV    AX, 20
        JMP    _A68L_CESAC_4
_A68L_CASE_4_2:
        MOV    AX, 99
_A68L_CESAC_4:
        SUB    SP, 2
        MOV    [BP-32], AX
; decl o : mode=0
        MOV    AX, 3
        SUB    SP, 2
        MOV    [BP-34], AX
; decl r : mode=0
        MOV    AX, [BP-34]
        PUSH   AX
        MOV    AX, 2
        MOV    BX, AX
        POP    AX
        CMP    AX, BX
        JG     _A68L_7
        XOR    AX, AX
        JMP    _A68L_8
_A68L_7:
        MOV    AX, 1
_A68L_8:
        TEST   AX, AX
        JZ     _A68L_ELSE_9
        MOV    AX, [BP-34]
        PUSH   AX
        MOV    AX, 10
        MOV    BX, AX
        POP    AX
        IMUL   BX
        JMP    _A68L_FI_9
_A68L_ELSE_9:
        MOV    AX, [BP-34]
_A68L_FI_9:
        SUB    SP, 2
        MOV    [BP-36], AX
; decl s : mode=0
        MOV    AX, 1
        SUB    SP, 2
        MOV    [BP-38], AX
; decl t : mode=0
        MOV    AX, 2
        SUB    SP, 2
        MOV    [BP-40], AX
        MOV    AX, [BP-38]
        MOV    BX, AX
        CMP    BX, 1
        JNE    _A68L_CASE_5_1
        XOR    AX, AX
        JMP    _A68L_CESAC_5
_A68L_CASE_5_1:
        MOV    AX, [BP-40]
        MOV    BX, AX
        CMP    BX, 1
        JNE    _A68L_CASE_6_1
        XOR    AX, AX
        JMP    _A68L_CESAC_5
_A68L_CASE_6_1:
        CMP    BX, 2
        JNE    _A68L_CASE_6_2
        XOR    AX, AX
        JMP    _A68L_CESAC_5
_A68L_CASE_6_2:
_A68L_CESAC_5:

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
_DATA   ENDS

        END _A68P_main
