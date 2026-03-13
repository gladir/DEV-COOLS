; Genere par AL68C86 v1.0 - SAMPLES/ALGOL68/test_struct.a68

        .MODEL SMALL
        .STACK 1024

_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME  CS:_TEXT, DS:_DATA, SS:NOTHING

; --- point d'entree ---
_A68P_main:
        MOV   AX, _DATA
        MOV   DS, AX

; MODE POINT = STRUCT, size=4, fields=2
; decl p : mode=10
; struct constructor POINT
        SUB    SP, 4
        MOV    BX, SP
        MOV    AX, 3
        MOV    [BX], AX
        MOV    AX, 7
        MOV    [BX+2], AX
        MOV    AX, BX
; global struct p init, size=4
        MOV    SI, AX
        MOV    DI, OFFSET _A68V_p
        MOV    CX, 2
        CLD
        REP MOVSW
; decl px : mode=0
; field x OF POINT, offset=0
        MOV    BX, OFFSET _A68V_p
        MOV    AX, [BX]
        MOV    [_A68V_px], AX
; decl py : mode=0
; field y OF POINT, offset=2
        MOV    BX, OFFSET _A68V_p
        ADD    BX, 2
        MOV    AX, [BX]
        MOV    [_A68V_py], AX
; MODE VEC3 = STRUCT, size=6, fields=3
; decl v : mode=11
; struct constructor VEC3
        SUB    SP, 6
        MOV    BX, SP
        MOV    AX, 10
        MOV    [BX], AX
        MOV    AX, 20
        MOV    [BX+2], AX
        MOV    AX, 30
        MOV    [BX+4], AX
        MOV    AX, BX
; global struct v init, size=6
        MOV    SI, AX
        MOV    DI, OFFSET _A68V_v
        MOV    CX, 3
        CLD
        REP MOVSW
; decl va : mode=0
; field a OF VEC3, offset=0
        MOV    BX, OFFSET _A68V_v
        MOV    AX, [BX]
        MOV    [_A68V_va], AX
; decl vb : mode=0
; field b OF VEC3, offset=2
        MOV    BX, OFFSET _A68V_v
        ADD    BX, 2
        MOV    AX, [BX]
        MOV    [_A68V_vb], AX
; decl vc : mode=0
; field c OF VEC3, offset=4
        MOV    BX, OFFSET _A68V_v
        ADD    BX, 4
        MOV    AX, [BX]
        MOV    [_A68V_vc], AX
; MODE myint = alias for INT
; decl z : mode=12
        MOV    AX, 99
        MOV    [_A68V_z], AX

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
_A68V_p:
        DW      2  ; struct/union block
        DW      1 DUP(0)
_A68V_px:
        DW      0
_A68V_py:
        DW      0
_A68V_v:
        DW      3  ; struct/union block
        DW      2 DUP(0)
_A68V_va:
        DW      0
_A68V_vb:
        DW      0
_A68V_vc:
        DW      0
_A68V_z:
        DW      0
_DATA   ENDS

        END _A68P_main
