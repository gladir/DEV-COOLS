; Genere par PYTHON86 v1.0 - SAMPLES/PYTHON/test_if.py
; Cible : MASM .MODEL SMALL, DOS 16 bits

.MODEL SMALL
.STACK 1024

_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME CS:_TEXT, DS:_DATA, SS:STACK

; -- Point d entree principal --
_PYF_Main:
        MOV AX,_DATA
        MOV DS,AX
        PUSH BP
        MOV BP,SP

; assign: x = expr
        MOV    AX, 10
        MOV    [_PYV_x], AX
; -- if --
; ident: x [_PYV_x]
        MOV    AX, [_PYV_x]
        CMP    AX, 5
        MOV    AX, 0
        JLE    $+4
        INC    AX
        TEST   AX, AX
        JZ     _PYL_2
; print(...)
        MOV    AX, OFFSET _PYK_3
        MOV    SI, AX
        CALL   _PYRT_PRINTSTR
        CALL   _PYRT_NEWLINE
        JMP    _PYL_1
_PYL_2:
_PYL_1:
; assign: y = expr
        MOV    AX, 3
        MOV    [_PYV_y], AX
; -- if --
; ident: y [_PYV_y]
        MOV    AX, [_PYV_y]
        CMP    AX, 5
        MOV    AX, 0
        JLE    $+4
        INC    AX
        TEST   AX, AX
        JZ     _PYL_5
; print(...)
        MOV    AX, OFFSET _PYK_6
        MOV    SI, AX
        CALL   _PYRT_PRINTSTR
        CALL   _PYRT_NEWLINE
        JMP    _PYL_4
_PYL_5:
; -- else --
; print(...)
        MOV    AX, OFFSET _PYK_7
        MOV    SI, AX
        CALL   _PYRT_PRINTSTR
        CALL   _PYRT_NEWLINE
_PYL_4:
; assign: z = expr
        MOV    AX, 5
        MOV    [_PYV_z], AX
; -- if --
; ident: z [_PYV_z]
        MOV    AX, [_PYV_z]
        CMP    AX, 5
        MOV    AX, 0
        JGE    $+4
        INC    AX
        TEST   AX, AX
        JZ     _PYL_9
; print(...)
        MOV    AX, OFFSET _PYK_10
        MOV    SI, AX
        CALL   _PYRT_PRINTSTR
        CALL   _PYRT_NEWLINE
        JMP    _PYL_8
_PYL_9:
; -- elif --
; ident: z [_PYV_z]
        MOV    AX, [_PYV_z]
        CMP    AX, 5
        MOV    AX, 0
        JNE    $+4
        INC    AX
        TEST   AX, AX
        JZ     _PYL_11
; print(...)
        MOV    AX, OFFSET _PYK_12
        MOV    SI, AX
        CALL   _PYRT_PRINTSTR
        CALL   _PYRT_NEWLINE
        JMP    _PYL_8
_PYL_11:
; -- else --
; print(...)
        MOV    AX, OFFSET _PYK_13
        MOV    SI, AX
        CALL   _PYRT_PRINTSTR
        CALL   _PYRT_NEWLINE
_PYL_8:
; assign: a = expr
        MOV    AX, 10
        MOV    [_PYV_a], AX
; assign: b = expr
        MOV    AX, 20
        MOV    [_PYV_b], AX
; -- if --
; ident: a [_PYV_a]
        MOV    AX, [_PYV_a]
        CMP    AX, 5
        MOV    AX, 0
        JLE    $+4
        INC    AX
        TEST   AX, AX
        JZ     _PYL_15
; -- if --
; ident: b [_PYV_b]
        MOV    AX, [_PYV_b]
        CMP    AX, 15
        MOV    AX, 0
        JLE    $+4
        INC    AX
        TEST   AX, AX
        JZ     _PYL_17
; print(...)
        MOV    AX, OFFSET _PYK_18
        MOV    SI, AX
        CALL   _PYRT_PRINTSTR
        CALL   _PYRT_NEWLINE
        JMP    _PYL_16
_PYL_17:
_PYL_16:
        JMP    _PYL_14
_PYL_15:
_PYL_14:
; -- if --
; ident: x [_PYV_x]
; ident: y [_PYV_y]
        MOV    AX, [_PYV_x]
        PUSH   AX
        MOV    AX, [_PYV_y]
        MOV    BX, AX
        POP    AX
        ADD    AX, BX
        CMP    AX, 10
        MOV    AX, 0
        JLE    $+4
        INC    AX
        TEST   AX, AX
        JZ     _PYL_20
; print(...)
        MOV    AX, OFFSET _PYK_21
        MOV    SI, AX
        CALL   _PYRT_PRINTSTR
        CALL   _PYRT_NEWLINE
        JMP    _PYL_19
_PYL_20:
_PYL_19:
; assign: val = expr
        MOV    AX, 1
        PUSH   AX
; ident: x [_PYV_x]
        MOV    AX, [_PYV_x]
        CMP    AX, 5
        MOV    AX, 0
        JLE    $+4
        INC    AX
        TEST   AX, AX
        JZ     _PYL_22
        POP    AX
        JMP    _PYL_23
_PYL_22:
        ADD    SP, 2
        XOR    AX, AX
_PYL_23:
        MOV    [_PYV_val], AX
; print(...)
; ident: val [_PYV_val]
        MOV    AX, [_PYV_val]
        CALL   _PYRT_PRINT
        CALL   _PYRT_NEWLINE
; assign: msg = expr
        MOV    AX, OFFSET _PYK_24
        PUSH   AX
; ident: x [_PYV_x]
        MOV    AX, [_PYV_x]
        CMP    AX, 5
        MOV    AX, 0
        JLE    $+4
        INC    AX
        TEST   AX, AX
        JZ     _PYL_25
        POP    AX
        JMP    _PYL_26
_PYL_25:
        ADD    SP, 2
        MOV    AX, OFFSET _PYK_27
_PYL_26:
        MOV    [_PYV_msg], AX
; -- if --
; ident: x [_PYV_x]
        MOV    AX, [_PYV_x]
        CMP    AX, 0
        MOV    AX, 0
        JGE    $+4
        INC    AX
        TEST   AX, AX
        JZ     _PYL_29
; pass
        JMP    _PYL_28
_PYL_29:
; -- else --
; print(...)
        MOV    AX, OFFSET _PYK_30
        MOV    SI, AX
        CALL   _PYRT_PRINTSTR
        CALL   _PYRT_NEWLINE
_PYL_28:
; assign: n = expr
        MOV    AX, 2
        MOV    [_PYV_n], AX
; -- if --
; ident: n [_PYV_n]
        MOV    AX, [_PYV_n]
        CMP    AX, 1
        MOV    AX, 0
        JNE    $+4
        INC    AX
        TEST   AX, AX
        JZ     _PYL_32
; print(...)
        MOV    AX, OFFSET _PYK_33
        MOV    SI, AX
        CALL   _PYRT_PRINTSTR
        CALL   _PYRT_NEWLINE
        JMP    _PYL_31
_PYL_32:
; -- elif --
; ident: n [_PYV_n]
        MOV    AX, [_PYV_n]
        CMP    AX, 2
        MOV    AX, 0
        JNE    $+4
        INC    AX
        TEST   AX, AX
        JZ     _PYL_34
; print(...)
        MOV    AX, OFFSET _PYK_35
        MOV    SI, AX
        CALL   _PYRT_PRINTSTR
        CALL   _PYRT_NEWLINE
        JMP    _PYL_31
_PYL_34:
; -- elif --
; ident: n [_PYV_n]
        MOV    AX, [_PYV_n]
        CMP    AX, 3
        MOV    AX, 0
        JNE    $+4
        INC    AX
        TEST   AX, AX
        JZ     _PYL_36
; print(...)
        MOV    AX, OFFSET _PYK_37
        MOV    SI, AX
        CALL   _PYRT_PRINTSTR
        CALL   _PYRT_NEWLINE
        JMP    _PYL_31
_PYL_36:
; -- else --
; print(...)
        MOV    AX, OFFSET _PYK_38
        MOV    SI, AX
        CALL   _PYRT_PRINTSTR
        CALL   _PYRT_NEWLINE
_PYL_31:

; -- Fin du programme --
        MOV SP,BP
        POP BP
        RET
        MOV AX,4C00h
        INT 21h

; -- Runtime : expressions binaires (TODO 11) --
_PYRT_CONCAT:
        PUSH   DI
        MOV    DI, OFFSET _PY_STRBUF
_PYRT_CC1:
        LODSB
        TEST   AL, AL
        JZ     _PYRT_CC2
        STOSB
        JMP    _PYRT_CC1
_PYRT_CC2:
        POP    SI
_PYRT_CC3:
        LODSB
        TEST   AL, AL
        JZ     _PYRT_CC4
        STOSB
        JMP    _PYRT_CC3
_PYRT_CC4:
        MOV    BYTE PTR [DI], 0
        MOV    AX, OFFSET _PY_STRBUF
        RET
_PYRT_STRCMP:
_PYRT_SC1:
        MOV    AL, [SI]
        MOV    AH, [DI]
        CMP    AL, AH
        JB     _PYRT_SCLT
        JA     _PYRT_SCGT
        TEST   AL, AL
        JZ     _PYRT_SCEQ
        INC    SI
        INC    DI
        JMP    _PYRT_SC1
_PYRT_SCEQ:
        XOR    AX, AX
        RET
_PYRT_SCLT:
        MOV    AX, -1
        RET
_PYRT_SCGT:
        MOV    AX, 1
        RET
_PYRT_STRMUL:
        MOV    DI, OFFSET _PY_STRBUF
        TEST   CX, CX
        JLE    _PYRT_SM_END
_PYRT_SM_LP:
        PUSH   CX
        PUSH   SI
_PYRT_SM_C:
        LODSB
        TEST   AL, AL
        JZ     _PYRT_SM_NX
        STOSB
        JMP    _PYRT_SM_C
_PYRT_SM_NX:
        POP    SI
        POP    CX
        LOOP   _PYRT_SM_LP
_PYRT_SM_END:
        MOV    BYTE PTR [DI], 0
        MOV    AX, OFFSET _PY_STRBUF
        RET
_PYRT_CONTAINS:
        MOV    BX, AX
        MOV    CX, [SI]
        ADD    SI, 2
        TEST   CX, CX
        JZ     _PYRT_CN_NO
_PYRT_CN_LP:
        LODSW
        CMP    AX, BX
        JE     _PYRT_CN_YES
        LOOP   _PYRT_CN_LP
_PYRT_CN_NO:
        XOR    AX, AX
        RET
_PYRT_CN_YES:
        MOV    AX, 1
        RET
_PYRT_NOT:
        TEST   AX, AX
        MOV    AX, 0
        JNZ    $+4
        INC    AX
        RET
_PYRT_POWER:
        PUSH   BX
        PUSH   DX
        MOV    BX, AX
        MOV    AX, 1
        TEST   CX, CX
        JLE    _PYRT_PW_END
_PYRT_PW_LP:
        IMUL   BX
        LOOP   _PYRT_PW_LP
_PYRT_PW_END:
        POP    DX
        POP    BX
        RET

; -- Runtime : entrees/sorties (TODO 12) --
_PYRT_STRLEN:
        PUSH   SI
        XOR    CX, CX
_PYRT_SL1:
        LODSB
        TEST   AL, AL
        JZ     _PYRT_SL2
        INC    CX
        JMP    _PYRT_SL1
_PYRT_SL2:
        POP    SI
        RET
_PYRT_LEN:
        PUSH   SI
        XOR    AX, AX
_PYRT_LN1:
        CMP    BYTE PTR [SI], 0
        JE     _PYRT_LN2
        INC    AX
        INC    SI
        JMP    _PYRT_LN1
_PYRT_LN2:
        POP    SI
        RET
_PYRT_NUMTOSTR:
        PUSH   BX
        PUSH   DX
        PUSH   DI
        MOV    DI, OFFSET _PY_NUMBUF
        ADD    DI, 11
        MOV    BYTE PTR [DI], 0
        DEC    DI
        MOV    BX, 10
        XOR    CX, CX
        TEST   AX, AX
        JNS    _PYRT_NT_POS
        NEG    AX
        PUSH   AX
        MOV    AX, 1
        PUSH   AX
        POP    AX
        POP    AX
        JMP    _PYRT_NT_POS
_PYRT_NT_NEG:
        NEG    AX
_PYRT_NT_POS:
_PYRT_NT_LP:
        XOR    DX, DX
        DIV    BX
        ADD    DL, 48
        MOV    [DI], DL
        DEC    DI
        INC    CX
        TEST   AX, AX
        JNZ    _PYRT_NT_LP
        INC    DI
        MOV    SI, DI
        POP    DI
        POP    DX
        POP    BX
        RET
_PYRT_INTTOSTR:
        CALL   _PYRT_NUMTOSTR
        MOV    AX, SI
        RET
_PYRT_PRINTSTR:
        PUSH   AX
        PUSH   BX
        PUSH   CX
        PUSH   DX
        CALL   _PYRT_STRLEN
        MOV    DX, SI
        MOV    BX, 1
        MOV    AH, 40h
        INT    21h
        POP    DX
        POP    CX
        POP    BX
        POP    AX
        RET
_PYRT_PRINT:
        PUSH   SI
        PUSH   CX
        PUSH   DX
        PUSH   BX
        TEST   AX, AX
        JNS    _PYRT_PR_POS
        PUSH   AX
        MOV    DL, 45
        MOV    AH, 02h
        INT    21h
        POP    AX
        NEG    AX
_PYRT_PR_POS:
        CALL   _PYRT_NUMTOSTR
        MOV    DX, SI
        MOV    BX, 1
        MOV    AH, 40h
        INT    21h
        POP    BX
        POP    DX
        POP    CX
        POP    SI
        RET
_PYRT_NEWLINE:
        PUSH   AX
        PUSH   BX
        PUSH   CX
        PUSH   DX
        MOV    DX, OFFSET _PY_CRLF
        MOV    CX, 2
        MOV    BX, 1
        MOV    AH, 40h
        INT    21h
        POP    DX
        POP    CX
        POP    BX
        POP    AX
        RET
_PYRT_PRINTSPC:
        PUSH   AX
        PUSH   DX
        MOV    DL, 32
        MOV    AH, 02h
        INT    21h
        POP    DX
        POP    AX
        RET
_PYRT_INPUT:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        PUSH   SI
        MOV    DX, OFFSET _PY_INPUTMX
        MOV    AH, 0Ah
        INT    21h
        XOR    BH, BH
        MOV    BL, [_PY_INPUTLN]
        MOV    BYTE PTR [_PY_INPUTBF + BX], 0
        CALL   _PYRT_NEWLINE
        MOV    AX, OFFSET _PY_INPUTBF
        POP    SI
        POP    DX
        POP    CX
        POP    BX
        RET
_PYRT_STRTONUM:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        XOR    AX, AX
        XOR    CX, CX
        CMP    BYTE PTR [SI], 45
        JNE    _PYRT_SN_LP
        INC    CX
        INC    SI
_PYRT_SN_LP:
        MOV    BL, [SI]
        TEST   BL, BL
        JZ     _PYRT_SN_DN
        CMP    BL, 48
        JB     _PYRT_SN_DN
        CMP    BL, 57
        JA     _PYRT_SN_DN
        SUB    BL, 48
        XOR    BH, BH
        PUSH   BX
        MOV    BX, 10
        MUL    BX
        POP    BX
        ADD    AX, BX
        INC    SI
        JMP    _PYRT_SN_LP
_PYRT_SN_DN:
        TEST   CX, CX
        JZ     _PYRT_SN_OK
        NEG    AX
_PYRT_SN_OK:
        POP    DX
        POP    CX
        POP    BX
        RET
_PYRT_TOHEX:
        PUSH   BX
        PUSH   CX
        PUSH   DI
        MOV    DI, OFFSET _PY_NUMBUF
        MOV    BYTE PTR [DI], 48
        MOV    BYTE PTR [DI+1], 120
        ADD    DI, 6
        MOV    BYTE PTR [DI], 0
        DEC    DI
        MOV    CX, 4
_PYRT_HX_LP:
        MOV    BX, AX
        AND    BX, 0Fh
        CMP    BL, 10
        JB     _PYRT_HX_D
        ADD    BL, 87
        JMP    _PYRT_HX_S
_PYRT_HX_D:
        ADD    BL, 48
_PYRT_HX_S:
        MOV    [DI], BL
        DEC    DI
        SHR    AX, 1
        SHR    AX, 1
        SHR    AX, 1
        SHR    AX, 1
        LOOP   _PYRT_HX_LP
        MOV    AX, OFFSET _PY_NUMBUF
        POP    DI
        POP    CX
        POP    BX
        RET
_PYRT_TOOCT:
        PUSH   BX
        PUSH   CX
        PUSH   DI
        MOV    DI, OFFSET _PY_NUMBUF
        MOV    BYTE PTR [DI], 48
        MOV    BYTE PTR [DI+1], 111
        ADD    DI, 8
        MOV    BYTE PTR [DI], 0
        DEC    DI
        MOV    CX, 6
_PYRT_OC_LP:
        MOV    BX, AX
        AND    BX, 07h
        ADD    BL, 48
        MOV    [DI], BL
        DEC    DI
        SHR    AX, 1
        SHR    AX, 1
        SHR    AX, 1
        LOOP   _PYRT_OC_LP
        MOV    AX, OFFSET _PY_NUMBUF
        POP    DI
        POP    CX
        POP    BX
        RET
_PYRT_TOBIN:
        PUSH   BX
        PUSH   CX
        PUSH   DI
        MOV    DI, OFFSET _PY_STRBUF
        MOV    BYTE PTR [DI], 48
        MOV    BYTE PTR [DI+1], 98
        ADD    DI, 18
        MOV    BYTE PTR [DI], 0
        DEC    DI
        MOV    CX, 16
_PYRT_BN_LP:
        MOV    BX, AX
        AND    BX, 01h
        ADD    BL, 48
        MOV    [DI], BL
        DEC    DI
        SHR    AX, 1
        LOOP   _PYRT_BN_LP
        MOV    AX, OFFSET _PY_STRBUF
        POP    DI
        POP    CX
        POP    BX
        RET

; -- Runtime : listes (TODO 15) --
_PYRT_SLICE:
        PUSH   DX
        CMP    BX, 0FFFFh
        JNE    _PYRT_SL_OK
        MOV    BX, [SI]
_PYRT_SL_OK:
        MOV    CX, BX
        SUB    CX, AX
        PUSH   CX
        PUSH   SI
        PUSH   AX
        MOV    DI, [_PY_HEAPTOP]
        ADD    DI, OFFSET _PY_HEAP
        MOV    [DI], CX
        POP    AX
        SHL    AX, 1
        POP    SI
        ADD    SI, AX
        ADD    SI, 2
        POP    CX
        PUSH   DI
        PUSH   CX
        ADD    DI, 2
        TEST   CX, CX
        JLE    _PYRT_SL_DN
_PYRT_SL_CP:
        MOVSW
        LOOP   _PYRT_SL_CP
_PYRT_SL_DN:
        POP    CX
        INC    CX
        SHL    CX, 1
        ADD    [_PY_HEAPTOP], CX
        POP    AX
        POP    DX
        RET
_PYRT_LISTAPPEND:
        MOV    CX, [SI]
        MOV    BX, CX
        SHL    BX, 1
        ADD    BX, 2
        MOV    [SI+BX], AX
        INC    WORD PTR [SI]
        ADD    WORD PTR [_PY_HEAPTOP], 2
        RET
_PYRT_LISTPOP:
        MOV    CX, [SI]
        DEC    WORD PTR [SI]
        SHL    CX, 1
        MOV    AX, [SI+CX]
        RET
_PYRT_LISTINSERT:
        PUSH   DX
        MOV    DX, BX
        MOV    CX, [SI]
        MOV    BX, CX
_PYRT_LI_SH:
        CMP    BX, AX
        JLE    _PYRT_LI_IN
        PUSH   AX
        MOV    AX, BX
        SHL    AX, 1
        ADD    AX, 2
        PUSH   SI
        ADD    SI, AX
        MOV    AX, [SI-2]
        MOV    [SI], AX
        POP    SI
        POP    AX
        DEC    BX
        JMP    _PYRT_LI_SH
_PYRT_LI_IN:
        SHL    AX, 1
        ADD    AX, 2
        ADD    SI, AX
        MOV    [SI], DX
        SUB    SI, AX
        INC    WORD PTR [SI]
        ADD    WORD PTR [_PY_HEAPTOP], 2
        POP    DX
        RET
_PYRT_LISTCONCAT:
        PUSH   BX
        PUSH   DX
        MOV    AX, [SI]
        MOV    BX, [DI]
        MOV    CX, AX
        ADD    CX, BX
        PUSH   CX
        PUSH   SI
        PUSH   DI
        PUSH   AX
        PUSH   BX
        MOV    DI, [_PY_HEAPTOP]
        ADD    DI, OFFSET _PY_HEAP
        MOV    [DI], CX
        PUSH   DI
        ADD    DI, 2
        POP    BX
        PUSH   BX
        MOV    CX, [SP+8]
        POP    DI
        POP    CX
        POP    AX
        POP    BX
        POP    SI
        POP    DX
        MOV    [DI], DX
        PUSH   DI
        PUSH   BX
        PUSH   CX
        ADD    DI, 2
        ADD    SI, 2
        MOV    CX, AX
        TEST   CX, CX
        JLE    _PYRT_LC_P2
_PYRT_LC_L1:
        MOVSW
        LOOP   _PYRT_LC_L1
_PYRT_LC_P2:
        POP    CX
        POP    SI
        ADD    SI, 2
        TEST   CX, CX
        JLE    _PYRT_LC_DN
_PYRT_LC_L2:
        MOVSW
        LOOP   _PYRT_LC_L2
_PYRT_LC_DN:
        POP    AX
        MOV    CX, [AX]
        INC    CX
        SHL    CX, 1
        ADD    [_PY_HEAPTOP], CX
        POP    DX
        POP    BX
        RET
_PYRT_LISTMUL:
        PUSH   BX
        PUSH   DX
        MOV    AX, [SI]
        MOV    BX, AX
        IMUL   CX
        MOV    DX, AX
        MOV    DI, [_PY_HEAPTOP]
        ADD    DI, OFFSET _PY_HEAP
        MOV    [DI], DX
        PUSH   DI
        ADD    DI, 2
        TEST   CX, CX
        JLE    _PYRT_LM_DN
_PYRT_LM_LP:
        PUSH   CX
        PUSH   SI
        ADD    SI, 2
        MOV    CX, BX
        TEST   CX, CX
        JLE    _PYRT_LM_NX
_PYRT_LM_CP:
        MOVSW
        LOOP   _PYRT_LM_CP
_PYRT_LM_NX:
        POP    SI
        POP    CX
        LOOP   _PYRT_LM_LP
_PYRT_LM_DN:
        POP    AX
        MOV    CX, [AX]
        INC    CX
        SHL    CX, 1
        ADD    [_PY_HEAPTOP], CX
        POP    DX
        POP    BX
        RET

; -- Runtime : dicts (TODO 16) --
_PYRT_DICTGET:
        PUSH   BX
        MOV    BX, AX
        MOV    CX, [SI]
        ADD    SI, 2
        TEST   CX, CX
        JZ     _PYRT_DG_NF
_PYRT_DG_LP:
        CMP    [SI], BX
        JE     _PYRT_DG_FD
        ADD    SI, 4
        LOOP   _PYRT_DG_LP
_PYRT_DG_NF:
        XOR    AX, AX
        POP    BX
        RET
_PYRT_DG_FD:
        MOV    AX, [SI+2]
        POP    BX
        RET
_PYRT_DICTSET:
        PUSH   DX
        MOV    DX, AX
        MOV    CX, [SI]
        PUSH   SI
        ADD    SI, 2
        TEST   CX, CX
        JZ     _PYRT_DS_ADD
_PYRT_DS_LP:
        CMP    [SI], DX
        JE     _PYRT_DS_UPD
        ADD    SI, 4
        LOOP   _PYRT_DS_LP
_PYRT_DS_ADD:
        MOV    [SI], DX
        MOV    [SI+2], BX
        POP    SI
        INC    WORD PTR [SI]
        ADD    WORD PTR [_PY_HEAPTOP], 4
        POP    DX
        RET
_PYRT_DS_UPD:
        MOV    [SI+2], BX
        POP    SI
        POP    DX
        RET
_PYRT_DICTGETDEF:
        PUSH   DX
        MOV    DX, AX
        MOV    CX, [SI]
        ADD    SI, 2
        TEST   CX, CX
        JZ     _PYRT_DD_DEF
_PYRT_DD_LP:
        CMP    [SI], DX
        JE     _PYRT_DD_FD
        ADD    SI, 4
        LOOP   _PYRT_DD_LP
_PYRT_DD_DEF:
        MOV    AX, BX
        POP    DX
        RET
_PYRT_DD_FD:
        MOV    AX, [SI+2]
        POP    DX
        RET
_PYRT_DICTCONTAINS:
        MOV    BX, AX
        MOV    CX, [SI]
        ADD    SI, 2
        TEST   CX, CX
        JZ     _PYRT_DC_NO
_PYRT_DC_LP:
        CMP    [SI], BX
        JE     _PYRT_DC_YES
        ADD    SI, 4
        LOOP   _PYRT_DC_LP
_PYRT_DC_NO:
        XOR    AX, AX
        RET
_PYRT_DC_YES:
        MOV    AX, 1
        RET
_PYRT_DICTDEL:
        PUSH   BX
        PUSH   DX
        MOV    BX, AX
        MOV    CX, [SI]
        PUSH   SI
        ADD    SI, 2
        TEST   CX, CX
        JZ     _PYRT_DL_DN
_PYRT_DL_LP:
        CMP    [SI], BX
        JE     _PYRT_DL_FD
        ADD    SI, 4
        LOOP   _PYRT_DL_LP
        JMP    _PYRT_DL_DN
_PYRT_DL_FD:
        DEC    CX
        TEST   CX, CX
        JZ     _PYRT_DL_DC
_PYRT_DL_SH:
        MOV    AX, [SI+4]
        MOV    [SI], AX
        MOV    AX, [SI+6]
        MOV    [SI+2], AX
        ADD    SI, 4
        LOOP   _PYRT_DL_SH
_PYRT_DL_DC:
        POP    SI
        DEC    WORD PTR [SI]
        POP    DX
        POP    BX
        RET
_PYRT_DL_DN:
        POP    SI
        POP    DX
        POP    BX
        RET
_PYRT_DICTKEYS:
        PUSH   BX
        MOV    CX, [SI]
        ADD    SI, 2
        MOV    DI, [_PY_HEAPTOP]
        ADD    DI, OFFSET _PY_HEAP
        MOV    [DI], CX
        PUSH   DI
        ADD    DI, 2
        TEST   CX, CX
        JLE    _PYRT_DK_DN
_PYRT_DK_LP:
        MOV    AX, [SI]
        STOSW
        ADD    SI, 4
        LOOP   _PYRT_DK_LP
_PYRT_DK_DN:
        POP    AX
        MOV    CX, [AX]
        INC    CX
        SHL    CX, 1
        ADD    [_PY_HEAPTOP], CX
        POP    BX
        RET
_PYRT_DICTVALS:
        PUSH   BX
        MOV    CX, [SI]
        ADD    SI, 2
        MOV    DI, [_PY_HEAPTOP]
        ADD    DI, OFFSET _PY_HEAP
        MOV    [DI], CX
        PUSH   DI
        ADD    DI, 2
        TEST   CX, CX
        JLE    _PYRT_DV_DN
_PYRT_DV_LP:
        MOV    AX, [SI+2]
        STOSW
        ADD    SI, 4
        LOOP   _PYRT_DV_LP
_PYRT_DV_DN:
        POP    AX
        MOV    CX, [AX]
        INC    CX
        SHL    CX, 1
        ADD    [_PY_HEAPTOP], CX
        POP    BX
        RET

_TEXT   ENDS


_DATA   SEGMENT WORD PUBLIC 'DATA'

_PY_STRBUF  DB  256 DUP(0)

_PY_NUMBUF  DB  12 DUP(0)

_PY_CRLF    DB  13, 10
_PY_SPACE   DB  32, 0

_PY_INPUTMX DB  126
_PY_INPUTLN DB  0
_PY_INPUTBF DB  128 DUP(0)

_PY_FOREND   DW 0
_PY_FORSTEP  DW 0
_PY_FORITER  DW 0

_PY_HEAP    DB  4096 DUP(0)
_PY_HEAPTOP DW  0

_PYV_x  DW  0
_PYK_3  DB  120,32,101,115,116,32,103,114,97,110,100,0
_PYV_y  DW  0
_PYK_6  DB  121,32,101,115,116,32,103,114,97,110,100,0
_PYK_7  DB  121,32,101,115,116,32,112,101,116,105,116,0
_PYV_z  DW  0
_PYK_10  DB  122,32,101,115,116,32,112,101,116,105,116,0
_PYK_12  DB  122,32,118,97,117,116,32,99,105,110,113,0
_PYK_13  DB  122,32,101,115,116,32,103,114,97,110,100,0
_PYV_a  DW  0
_PYV_b  DW  0
_PYK_18  DB  108,101,115,32,100,101,117,120,32,103,114,97,110,100,115,0
_PYK_21  DB  115,111,109,109,101,32,103,114,97,110,100,101,0
_PYV_val  DW  0
_PYK_24  DB  103,114,97,110,100,0
_PYK_27  DB  112,101,116,105,116,0
_PYV_msg  DW  0
_PYK_30  DB  120,32,112,111,115,105,116,105,102,0
_PYV_n  DW  0
_PYK_33  DB  117,110,0
_PYK_35  DB  100,101,117,120,0
_PYK_37  DB  116,114,111,105,115,0
_PYK_38  DB  97,117,116,114,101,0

_DATA   ENDS

        END _PYF_Main
