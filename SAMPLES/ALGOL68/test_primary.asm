; Genere par AL68C86 v1.0 - SAMPLES/ALGOL68/test_primary.a68

        .MODEL SMALL
        .STACK 1024

_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME  CS:_TEXT, DS:_DATA, SS:NOTHING

; --- point d'entree ---
_A68P_main:
        MOV   AX, _DATA
        MOV   DS, AX

; decl x : mode=0
        MOV    AX, 42
        SUB    SP, 2
        MOV    [BP-2], AX
; decl y : mode=0
        MOV    AX, [BP-2]
        SUB    SP, 2
        MOV    [BP-4], AX
; decl z : mode=0
        MOV    AX, 5
        SUB    SP, 2
        MOV    [BP-6], AX
; decl flag : mode=2
        MOV    AX, 1
        SUB    SP, 1
        MOV    BYTE PTR [BP-8], AL
        MOV    AX, [BP-8]
        TEST   AX, AX
        JZ     _A68L_ELSE_1
; decl a : mode=0
        MOV    AX, 1
        SUB    SP, 2
        MOV    [BP-10], AX
        XOR    AX, AX
        JMP    _A68L_FI_1
_A68L_ELSE_1:
; decl a : mode=0
        MOV    AX, 2
        SUB    SP, 2
        MOV    [BP-12], AX
        XOR    AX, AX
_A68L_FI_1:
        MOV    AX, 2
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
        MOV    AX, 0
_A68L_CESAC_1:

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
