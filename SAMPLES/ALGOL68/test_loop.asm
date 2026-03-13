; Genere par AL68C86 v1.0 - SAMPLES/ALGOL68/test_loop.a68

        .MODEL SMALL
        .STACK 1024

_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME  CS:_TEXT, DS:_DATA, SS:NOTHING

; --- point d'entree ---
_A68P_main:
        MOV   AX, _DATA
        MOV   DS, AX

; decl sum1 : mode=0
        MOV    AX, 0
        MOV    [_A68V_sum1], AX
        MOV    AX, 1
        SUB    SP, 2
        MOV    WORD PTR [BP-2], AX
        MOV    AX, 10
        SUB    SP, 2
        MOV    WORD PTR [BP-4], AX
_A68L_LTEST_1:
        MOV    AX, WORD PTR [BP-2]
        CMP    AX, WORD PTR [BP-4]
        JG     _A68L_LEND_1
        MOV    AX, [_A68V_sum1]
        PUSH   AX
        MOV    AX, [BP-2]
        MOV    BX, AX
        POP    AX
        ADD    AX, BX
        MOV    [_A68V_sum1], AX
_A68L_LINCR_1:
        MOV    AX, WORD PTR [BP-2]
        ADD    AX, 1
        MOV    WORD PTR [BP-2], AX
        JMP    _A68L_LTEST_1
_A68L_LEND_1:
        ADD    SP, 4
; decl sum2 : mode=0
        MOV    AX, 0
        MOV    [_A68V_sum2], AX
        MOV    AX, 1
        SUB    SP, 2
        MOV    WORD PTR [BP-2], AX
        MOV    AX, 5
        SUB    SP, 2
        MOV    WORD PTR [BP-4], AX
_A68L_LTEST_2:
        MOV    AX, WORD PTR [BP-2]
        CMP    AX, WORD PTR [BP-4]
        JG     _A68L_LEND_2
        MOV    AX, [_A68V_sum2]
        PUSH   AX
        MOV    AX, [BP-2]
        MOV    BX, AX
        POP    AX
        ADD    AX, BX
        MOV    [_A68V_sum2], AX
_A68L_LINCR_2:
        MOV    AX, WORD PTR [BP-2]
        ADD    AX, 1
        MOV    WORD PTR [BP-2], AX
        JMP    _A68L_LTEST_2
_A68L_LEND_2:
        ADD    SP, 4
; decl sum3 : mode=0
        MOV    AX, 0
        MOV    [_A68V_sum3], AX
        MOV    AX, 1
        SUB    SP, 2
        MOV    WORD PTR [BP-2], AX
        MOV    AX, 10
        SUB    SP, 2
        MOV    WORD PTR [BP-4], AX
_A68L_LTEST_3:
        MOV    AX, WORD PTR [BP-2]
        CMP    AX, WORD PTR [BP-4]
        JG     _A68L_LEND_3
        MOV    AX, [_A68V_sum3]
        PUSH   AX
        MOV    AX, [BP-2]
        MOV    BX, AX
        POP    AX
        ADD    AX, BX
        MOV    [_A68V_sum3], AX
_A68L_LINCR_3:
        MOV    AX, WORD PTR [BP-2]
        ADD    AX, 2
        MOV    WORD PTR [BP-2], AX
        JMP    _A68L_LTEST_3
_A68L_LEND_3:
        ADD    SP, 4
; decl sum4 : mode=0
        MOV    AX, 0
        MOV    [_A68V_sum4], AX
        MOV    AX, 10
        SUB    SP, 2
        MOV    WORD PTR [BP-2], AX
        MOV    AX, 1
        SUB    SP, 2
        MOV    WORD PTR [BP-4], AX
_A68L_LTEST_4:
        MOV    AX, WORD PTR [BP-2]
        CMP    AX, WORD PTR [BP-4]
        JL     _A68L_LEND_4
        MOV    AX, [_A68V_sum4]
        PUSH   AX
        MOV    AX, [BP-2]
        MOV    BX, AX
        POP    AX
        ADD    AX, BX
        MOV    [_A68V_sum4], AX
_A68L_LINCR_4:
        MOV    AX, WORD PTR [BP-2]
        ADD    AX, -1
        MOV    WORD PTR [BP-2], AX
        JMP    _A68L_LTEST_4
_A68L_LEND_4:
        ADD    SP, 4
; decl count : mode=0
        MOV    AX, 0
        MOV    [_A68V_count], AX
; decl limit : mode=0
        MOV    AX, 5
        MOV    [_A68V_limit], AX
_A68L_LTEST_5:
        MOV    AX, [_A68V_count]
        PUSH   AX
        MOV    AX, [_A68V_limit]
        MOV    BX, AX
        POP    AX
        CMP    AX, BX
        JL     _A68L_1
        XOR    AX, AX
        JMP    _A68L_2
_A68L_1:
        MOV    AX, 1
_A68L_2:
        TEST   AX, AX
        JZ     _A68L_LEND_5
        MOV    AX, [_A68V_count]
        PUSH   AX
        MOV    AX, 1
        MOV    BX, AX
        POP    AX
        ADD    AX, BX
        MOV    [_A68V_count], AX
_A68L_LINCR_5:
        JMP    _A68L_LTEST_5
_A68L_LEND_5:
; decl sum6 : mode=0
        MOV    AX, 0
        MOV    [_A68V_sum6], AX
        MOV    AX, 1
        SUB    SP, 2
        MOV    WORD PTR [BP-2], AX
        MOV    AX, 100
        SUB    SP, 2
        MOV    WORD PTR [BP-4], AX
_A68L_LTEST_6:
        MOV    AX, WORD PTR [BP-2]
        CMP    AX, WORD PTR [BP-4]
        JG     _A68L_LEND_6
        MOV    AX, [_A68V_sum6]
        PUSH   AX
        MOV    AX, 20
        MOV    BX, AX
        POP    AX
        CMP    AX, BX
        JL     _A68L_3
        XOR    AX, AX
        JMP    _A68L_4
_A68L_3:
        MOV    AX, 1
_A68L_4:
        TEST   AX, AX
        JZ     _A68L_LEND_6
        MOV    AX, [_A68V_sum6]
        PUSH   AX
        MOV    AX, [BP-2]
        MOV    BX, AX
        POP    AX
        ADD    AX, BX
        MOV    [_A68V_sum6], AX
_A68L_LINCR_6:
        MOV    AX, WORD PTR [BP-2]
        ADD    AX, 1
        MOV    WORD PTR [BP-2], AX
        JMP    _A68L_LTEST_6
_A68L_LEND_6:
        ADD    SP, 4
; decl total : mode=0
        MOV    AX, 0
        MOV    [_A68V_total], AX
        MOV    AX, 1
        SUB    SP, 2
        MOV    WORD PTR [BP-2], AX
        MOV    AX, 3
        SUB    SP, 2
        MOV    WORD PTR [BP-4], AX
_A68L_LTEST_7:
        MOV    AX, WORD PTR [BP-2]
        CMP    AX, WORD PTR [BP-4]
        JG     _A68L_LEND_7
        MOV    AX, 1
        SUB    SP, 2
        MOV    WORD PTR [BP-6], AX
        MOV    AX, 3
        SUB    SP, 2
        MOV    WORD PTR [BP-8], AX
_A68L_LTEST_8:
        MOV    AX, WORD PTR [BP-6]
        CMP    AX, WORD PTR [BP-8]
        JG     _A68L_LEND_8
        MOV    AX, [_A68V_total]
        PUSH   AX
        MOV    AX, 1
        MOV    BX, AX
        POP    AX
        ADD    AX, BX
        MOV    [_A68V_total], AX
_A68L_LINCR_8:
        MOV    AX, WORD PTR [BP-6]
        ADD    AX, 1
        MOV    WORD PTR [BP-6], AX
        JMP    _A68L_LTEST_8
_A68L_LEND_8:
        ADD    SP, 4
_A68L_LINCR_7:
        MOV    AX, WORD PTR [BP-2]
        ADD    AX, 1
        MOV    WORD PTR [BP-2], AX
        JMP    _A68L_LTEST_7
_A68L_LEND_7:
        ADD    SP, 4
; decl sum8 : mode=0
        MOV    AX, 0
        MOV    [_A68V_sum8], AX
        MOV    AX, 5
        SUB    SP, 2
        MOV    WORD PTR [BP-2], AX
        MOV    AX, 1
        SUB    SP, 2
        MOV    WORD PTR [BP-4], AX
_A68L_LTEST_9:
        MOV    AX, WORD PTR [BP-2]
        CMP    AX, WORD PTR [BP-4]
        JL     _A68L_LEND_9
        MOV    AX, [_A68V_sum8]
        PUSH   AX
        MOV    AX, [BP-2]
        MOV    BX, AX
        POP    AX
        ADD    AX, BX
        MOV    [_A68V_sum8], AX
_A68L_LINCR_9:
        MOV    AX, WORD PTR [BP-2]
        ADD    AX, -1
        MOV    WORD PTR [BP-2], AX
        JMP    _A68L_LTEST_9
_A68L_LEND_9:
        ADD    SP, 4

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
_A68V_sum1:
        DW      0
_A68V_sum2:
        DW      0
_A68V_sum3:
        DW      0
_A68V_sum4:
        DW      0
_A68V_count:
        DW      0
_A68V_limit:
        DW      0
_A68V_sum6:
        DW      0
_A68V_total:
        DW      0
_A68V_sum8:
        DW      0
_DATA   ENDS

        END _A68P_main
