; Genere par AL68C86 v1.0 - SAMPLES/ALGOL68/test_closed.a68

        .MODEL SMALL
        .STACK 1024

_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME  CS:_TEXT, DS:_DATA, SS:NOTHING

; --- point d'entree ---
_A68P_main:
        MOV   AX, _DATA
        MOV   DS, AX

; decl x : mode=0
        MOV    AX, 10
        SUB    SP, 2
        MOV    [BP-2], AX
; decl y : mode=0
        MOV    AX, 20
        SUB    SP, 2
        MOV    [BP-4], AX
; decl z : mode=0
        MOV    AX, [BP-2]
        PUSH   AX
        MOV    AX, [BP-4]
        MOV    BX, AX
        POP    AX
        ADD    AX, BX
        SUB    SP, 2
        MOV    [BP-6], AX
; decl a : mode=0
        MOV    AX, 7
        SUB    SP, 2
        MOV    [BP-4], AX
; decl b : mode=0
; decl tmp : mode=0
        MOV    AX, 5
        SUB    SP, 2
        MOV    [BP-6], AX
        MOV    AX, [BP-6]
        PUSH   AX
        MOV    AX, 2
        MOV    BX, AX
        POP    AX
        IMUL   BX
        SUB    SP, 2
        MOV    [BP-6], AX
_A68L_loop:
; decl c : mode=0
        MOV    AX, 1
        SUB    SP, 2
        MOV    [BP-8], AX
_A68L_done:
        JMP    _A68L_done

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
