; Genere par PYTHON86 v1.0 - SAMPLES/PYTHON/test_dicts.py
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

; assign: a = expr
; dict literal
        MOV    DI, [_PY_HEAPTOP]
        ADD    DI, OFFSET _PY_HEAP
        MOV    WORD PTR [DI], 0
        ADD    WORD PTR [_PY_HEAPTOP], 2
        MOV    AX, DI
        MOV    [_PYV_a], AX
; assign: b = expr
; dict literal
        MOV    DI, [_PY_HEAPTOP]
        ADD    DI, OFFSET _PY_HEAP
        MOV    AX, 1
        MOV    [DI+2], AX
        MOV    AX, 10
        MOV    [DI+4], AX
        MOV    AX, 2
        MOV    [DI+6], AX
        MOV    AX, 20
        MOV    [DI+8], AX
        MOV    AX, 3
        MOV    [DI+10], AX
        MOV    AX, 30
        MOV    [DI+12], AX
        MOV    WORD PTR [DI], 3
        MOV    AX, 14
        ADD    [_PY_HEAPTOP], AX
        MOV    AX, DI
        MOV    [_PYV_b], AX
; assign: n = expr
; ident: len [_PYRT_len]
; ident: b [_PYV_b]
        MOV    AX, [_PYV_b]
        PUSH   AX
        POP    AX
; builtin call: len
        MOV    SI, AX
        MOV    AX, [SI]
        MOV    [_PYV_n], AX
; print(...)
; ident: n [_PYV_n]
        MOV    AX, [_PYV_n]
        CALL   _PYRT_PRINT
        CALL   _PYRT_NEWLINE
; assign: x = expr
; ident: b [_PYV_b]
        MOV    AX, [_PYV_b]
        MOV    SI, AX
; dict access [key]
        MOV    AX, 1
        CALL   _PYRT_DICTGET
        MOV    [_PYV_x], AX
; print(...)
; ident: x [_PYV_x]
        MOV    AX, [_PYV_x]
        CALL   _PYRT_PRINT
        CALL   _PYRT_NEWLINE
; assign: y = expr
; ident: b [_PYV_b]
        MOV    AX, [_PYV_b]
        MOV    SI, AX
; dict access [key]
        MOV    AX, 3
        CALL   _PYRT_DICTGET
        MOV    [_PYV_y], AX
; print(...)
; ident: y [_PYV_y]
        MOV    AX, [_PYV_y]
        CALL   _PYRT_PRINT
        CALL   _PYRT_NEWLINE
        MOV    AX, [_PYV_b]
        PUSH   AX
        MOV    AX, 2
        PUSH   AX
        MOV    AX, 99
; dict assign: b[key] = val
        MOV    BX, AX
        POP    AX
        POP    SI
        CALL   _PYRT_DICTSET
; print(...)
; ident: b [_PYV_b]
        MOV    AX, [_PYV_b]
        MOV    SI, AX
; dict access [key]
        MOV    AX, 2
        CALL   _PYRT_DICTGET
        CALL   _PYRT_PRINT
        CALL   _PYRT_NEWLINE
        MOV    AX, [_PYV_b]
        PUSH   AX
        MOV    AX, 4
        PUSH   AX
        MOV    AX, 40
; dict assign: b[key] = val
        MOV    BX, AX
        POP    AX
        POP    SI
        CALL   _PYRT_DICTSET
; print(...)
; ident: len [_PYRT_len]
; ident: b [_PYV_b]
        MOV    AX, [_PYV_b]
        PUSH   AX
        POP    AX
; builtin call: len
        MOV    SI, AX
        MOV    AX, [SI]
        CALL   _PYRT_PRINT
        CALL   _PYRT_NEWLINE
; assign: v = expr
; ident: b [_PYV_b]
        MOV    AX, [_PYV_b]
        MOV    SI, AX
; attr: .get
        PUSH   SI
        MOV    AX, 1
        PUSH   AX
        XOR    AX, AX
        MOV    BX, AX
        POP    AX
        POP    SI
        CALL   _PYRT_DICTGETDEF
        MOV    [_PYV_v], AX
; print(...)
; ident: v [_PYV_v]
        MOV    AX, [_PYV_v]
        CALL   _PYRT_PRINT
        CALL   _PYRT_NEWLINE
; assign: w = expr
; ident: b [_PYV_b]
        MOV    AX, [_PYV_b]
        MOV    SI, AX
; attr: .get
        PUSH   SI
        MOV    AX, 999
        PUSH   AX
        MOV    AX, -1
        MOV    BX, AX
        POP    AX
        POP    SI
        CALL   _PYRT_DICTGETDEF
        MOV    [_PYV_w], AX
; print(...)
; ident: w [_PYV_w]
        MOV    AX, [_PYV_w]
        CALL   _PYRT_PRINT
        CALL   _PYRT_NEWLINE
; -- if --
; ident: b [_PYV_b]
        MOV    AX, 1
        PUSH   AX
        MOV    AX, [_PYV_b]
        MOV    SI, AX
        POP    AX
        CALL   _PYRT_DICTCONTAINS
        TEST   AX, AX
        JZ     _PYL_2
; print(...)
        MOV    AX, 1
        CALL   _PYRT_PRINT
        CALL   _PYRT_NEWLINE
        JMP    _PYL_1
_PYL_2:
_PYL_1:
; -- if --
; ident: b [_PYV_b]
        MOV    AX, 999
        PUSH   AX
        MOV    AX, [_PYV_b]
        MOV    SI, AX
        POP    AX
        CALL   _PYRT_DICTCONTAINS
        TEST   AX, AX
        JZ     _PYL_4
; print(...)
        XOR    AX, AX
        CALL   _PYRT_PRINT
        CALL   _PYRT_NEWLINE
        JMP    _PYL_3
_PYL_4:
_PYL_3:
; assign: k = expr
; ident: b [_PYV_b]
        MOV    AX, [_PYV_b]
        MOV    SI, AX
; attr: .keys
        CALL   _PYRT_DICTKEYS
        MOV    [_PYV_k], AX
; print(...)
; ident: len [_PYRT_len]
; ident: k [_PYV_k]
        MOV    AX, [_PYV_k]
        PUSH   AX
        POP    AX
; builtin call: len
        MOV    SI, AX
        CALL   _PYRT_LEN
        CALL   _PYRT_PRINT
        CALL   _PYRT_NEWLINE
; assign: vals = expr
; ident: b [_PYV_b]
        MOV    AX, [_PYV_b]
        MOV    SI, AX
; attr: .values
        CALL   _PYRT_DICTVALS
        MOV    [_PYV_vals], AX
; print(...)
; ident: len [_PYRT_len]
; ident: vals [_PYV_vals]
        MOV    AX, [_PYV_vals]
        PUSH   AX
        POP    AX
; builtin call: len
        MOV    SI, AX
        CALL   _PYRT_LEN
        CALL   _PYRT_PRINT
        CALL   _PYRT_NEWLINE
; del
        MOV    AX, [_PYV_b]
        MOV    SI, AX
        MOV    AX, 4
        CALL   _PYRT_DICTDEL
; print(...)
; ident: len [_PYRT_len]
; ident: b [_PYV_b]
        MOV    AX, [_PYV_b]
        PUSH   AX
        POP    AX
; builtin call: len
        MOV    SI, AX
        MOV    AX, [SI]
        CALL   _PYRT_PRINT
        CALL   _PYRT_NEWLINE

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

_PYV_a  DW  0
_PYV_b  DW  0
_PYV_n  DW  0
_PYV_x  DW  0
_PYV_y  DW  0
_PYV_v  DW  0
_PYV_w  DW  0
_PYV_k  DW  0
_PYV_vals  DW  0

_DATA   ENDS

        END _PYF_Main
