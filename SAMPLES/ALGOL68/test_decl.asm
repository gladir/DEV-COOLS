; Genere par AL68C86 v1.0 - SAMPLES/ALGOL68/test_decl.a68

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
        MOV    AX, 10
        SUB    SP, 2
        MOV    [BP-4], AX
; decl flag : mode=2
        MOV    AX, 1
        SUB    SP, 1
        MOV    BYTE PTR [BP-6], AL
; decl c : mode=3
        MOV    AX, 65
        SUB    SP, 1
        MOV    BYTE PTR [BP-8], AL
; decl msg : mode=5
        LEA    AX, _A68K_1
        SUB    SP, 2
        MOV    [BP-10], AX
; decl a : mode=0
        MOV    AX, 1
        SUB    SP, 2
        MOV    [BP-12], AX
; decl b : mode=0
        MOV    AX, 2
        SUB    SP, 2
        MOV    [BP-14], AX
; decl c2 : mode=0
        MOV    AX, 3
        SUB    SP, 2
        MOV    [BP-16], AX

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
_A68K_1:
        DB      'Hello',0
_DATA   ENDS

        END _A68P_main
