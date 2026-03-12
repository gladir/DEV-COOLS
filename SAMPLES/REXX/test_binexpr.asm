; REXX86 v1.0 - SAMPLES/REXX/test_binexpr.rexx
.MODEL SMALL
.STACK 1024

_TEXT SEGMENT PUBLIC 'CODE'
        ASSUME CS:_TEXT, DS:_DATA, SS:NOTHING

; --- Point d'entree (main) ---
_RXP_Main:
        MOV   AX, _DATA
        MOV   DS, AX

; SAY
        MOV     AX, 5
        CALL   _RXRT_NUMTOSTR
        CALL   _RXRT_PRINTLN
; SAY
        MOV     AX, 6
        CALL   _RXRT_NUMTOSTR
        CALL   _RXRT_PRINTLN
; SAY
        MOV     AX, 15
        CALL   _RXRT_NUMTOSTR
        CALL   _RXRT_PRINTLN
; SAY
        MOV     AX, 5
        CALL   _RXRT_NUMTOSTR
        CALL   _RXRT_PRINTLN
; SAY
        MOV     AX, 2
        CALL   _RXRT_NUMTOSTR
        CALL   _RXRT_PRINTLN
; SAY
        MOV     AX, 1
        CALL   _RXRT_NUMTOSTR
        CALL   _RXRT_PRINTLN
; SAY
        MOV     AX, 32
        CALL   _RXRT_NUMTOSTR
        CALL   _RXRT_PRINTLN
; SAY
        LEA     AX, _RXK_1
        PUSH     AX
        LEA     AX, _RXK_2
        MOV     BX, AX
        POP     AX
        MOV     SI, AX
        MOV     DI, BX
        CALL    _RXRT_CONCAT
        MOV   SI, AX
        CALL   _RXRT_PRINTLN
; SAY
        LEA     AX, _RXK_3
        PUSH     AX
        LEA     AX, _RXK_4
        MOV     BX, AX
        POP     AX
        MOV     SI, AX
        MOV     DI, BX
        CALL    _RXRT_CONCAT
        MOV   SI, AX
        CALL   _RXRT_PRINTLN
; SAY
        LEA     AX, _RXK_4
        PUSH     AX
        LEA     AX, _RXK_4
        MOV     BX, AX
        POP     AX
        PUSH     BX
        MOV     SI, AX
        MOV     DI, OFFSET _RX_SPC_S
        CALL    _RXRT_CONCAT
        MOV     SI, AX
        POP     DI
        PUSH     DI
        MOV     DI, OFFSET _RX_TMPBUF
        CALL    _RXRT_STRCPY
        MOV     SI, OFFSET _RX_TMPBUF
        POP     DI
        CALL    _RXRT_CONCAT
        MOV   SI, AX
        CALL   _RXRT_PRINTLN
; SAY
        LEA     AX, _RXK_4
        PUSH     AX
        LEA     AX, _RXK_4
        MOV     BX, AX
        POP     AX
        MOV     SI, AX
        MOV     DI, BX
        CALL    _RXRT_STRCMP
        OR     AX, AX
        MOV     AX, 0
        JNE     _RXL_1
        INC     AX
_RXL_1:
        CALL   _RXRT_NUMTOSTR
        CALL   _RXRT_PRINTLN
; SAY
        LEA     AX, _RXK_4
        PUSH     AX
        LEA     AX, _RXK_4
        MOV     BX, AX
        POP     AX
        MOV     SI, AX
        MOV     DI, BX
        CALL    _RXRT_STRCMP
        OR     AX, AX
        MOV     AX, 0
        JE      _RXL_2
        INC     AX
_RXL_2:
        CALL   _RXRT_NUMTOSTR
        CALL   _RXRT_PRINTLN
; SAY
        LEA     AX, _RXK_5
        PUSH     AX
        LEA     AX, _RXK_6
        MOV     BX, AX
        POP     AX
        MOV     SI, AX
        MOV     DI, BX
        CALL    _RXRT_STRCMP
        CMP     AX, 1
        MOV     AX, 0
        JNE     _RXL_3
        INC     AX
_RXL_3:
        CALL   _RXRT_NUMTOSTR
        CALL   _RXRT_PRINTLN
; SAY
        LEA     AX, _RXK_6
        PUSH     AX
        LEA     AX, _RXK_6
        MOV     BX, AX
        POP     AX
        MOV     SI, AX
        MOV     DI, BX
        CALL    _RXRT_STRCMP
        CMP     AX, 0FFFFh
        MOV     AX, 0
        JNE     _RXL_4
        INC     AX
_RXL_4:
        CALL   _RXRT_NUMTOSTR
        CALL   _RXRT_PRINTLN
; SAY
        LEA     AX, _RXK_6
        PUSH     AX
        LEA     AX, _RXK_6
        MOV     BX, AX
        POP     AX
        MOV     SI, AX
        MOV     DI, BX
        CALL    _RXRT_STRCMPS
        OR     AX, AX
        MOV     AX, 0
        JNE     _RXL_5
        INC     AX
_RXL_5:
        CALL   _RXRT_NUMTOSTR
        CALL   _RXRT_PRINTLN
; SAY
        LEA     AX, _RXK_6
        PUSH     AX
        LEA     AX, _RXK_6
        MOV     BX, AX
        POP     AX
        MOV     SI, AX
        MOV     DI, BX
        CALL    _RXRT_STRCMPS
        OR     AX, AX
        MOV     AX, 0
        JE      _RXL_6
        INC     AX
_RXL_6:
        CALL   _RXRT_NUMTOSTR
        CALL   _RXRT_PRINTLN
; SAY
        MOV     AX, 1
        OR     AX, AX
        JZ      _RXL_7
        MOV     AX, 1
        OR     AX, AX
        JZ      _RXL_7
        MOV     AX, 1
        JMP     _RXL_8
_RXL_7:
        XOR     AX, AX
_RXL_8:
        CALL   _RXRT_NUMTOSTR
        CALL   _RXRT_PRINTLN
; SAY
        MOV     AX, 1
        OR     AX, AX
        JZ      _RXL_9
        MOV     AX, 0
        OR     AX, AX
        JZ      _RXL_9
        MOV     AX, 1
        JMP     _RXL_10
_RXL_9:
        XOR     AX, AX
_RXL_10:
        CALL   _RXRT_NUMTOSTR
        CALL   _RXRT_PRINTLN
; SAY
        MOV     AX, 0
        OR     AX, AX
        JNZ     _RXL_11
        MOV     AX, 1
        OR     AX, AX
        JNZ     _RXL_11
        XOR     AX, AX
        JMP     _RXL_12
_RXL_11:
        MOV     AX, 1
_RXL_12:
        CALL   _RXRT_NUMTOSTR
        CALL   _RXRT_PRINTLN
; SAY
        MOV     AX, 0
        OR     AX, AX
        JNZ     _RXL_13
        MOV     AX, 0
        OR     AX, AX
        JNZ     _RXL_13
        XOR     AX, AX
        JMP     _RXL_14
_RXL_13:
        MOV     AX, 1
_RXL_14:
        CALL   _RXRT_NUMTOSTR
        CALL   _RXRT_PRINTLN
; SAY
        MOV     AX, 1
        CALL   _RXRT_NUMTOSTR
        CALL   _RXRT_PRINTLN
; SAY
        MOV     AX, 0
        CALL   _RXRT_NUMTOSTR
        CALL   _RXRT_PRINTLN
; SAY
        MOV     AX, 1
        CALL   _RXRT_NUMTOSTR
        CALL   _RXRT_PRINTLN
; SAY
        MOV     AX, 0
        CALL   _RXRT_NUMTOSTR
        CALL   _RXRT_PRINTLN
        JMP     _RXP_Exit


; --- Runtime minimal REXX ---

_RXRT_PRINT:
        PUSH   AX
        PUSH   BX
        PUSH   CX
        PUSH   DX
        MOV   DI, SI
        XOR   CX, CX
_RXRT_PRINT_L:
        CMP   BYTE PTR [DI], 0
        JE   _RXRT_PRINT_W
        INC   DI
        INC   CX
        JMP   _RXRT_PRINT_L
_RXRT_PRINT_W:
        MOV   AH, 40h
        MOV   BX, 1
        MOV   DX, SI
        INT     21h
        POP   DX
        POP   CX
        POP   BX
        POP   AX
        RET

_RXRT_PRINTLN:
        CALL   _RXRT_PRINT
        MOV   SI, OFFSET _RX_CRLF
        CALL   _RXRT_PRINT
        RET

_RXRT_PANIC:
        CALL   _RXRT_PRINTLN
        MOV   AX, 4C01h
        INT     21h

_RXP_Exit:
        MOV   AX, 4C00h
        INT     21h

_RXRT_STRCPY:
        PUSH   AX
_RXRT_STRCPY_L:
        MOV   AL, BYTE PTR [SI]
        MOV   BYTE PTR [DI], AL
        INC   SI
        INC   DI
        OR   AL, AL
        JNZ   _RXRT_STRCPY_L
        POP   AX
        RET

_RXRT_UPPER:
        PUSH   AX
        PUSH   SI
_RXRT_UPPER_L:
        MOV   AL, BYTE PTR [SI]
        OR   AL, AL
        JZ   _RXRT_UPPER_D
        CMP   AL, 'a'
        JB   _RXRT_UPPER_N
        CMP   AL, 'z'
        JA   _RXRT_UPPER_N
        SUB   AL, 20h
        MOV   BYTE PTR [SI], AL
_RXRT_UPPER_N:
        INC   SI
        JMP   _RXRT_UPPER_L
_RXRT_UPPER_D:
        POP   SI
        POP   AX
        RET

_RXRT_STRLEN:
        PUSH   SI
        XOR   CX, CX
_RXRT_STRLEN_L:
        CMP   BYTE PTR [SI], 0
        JE   _RXRT_STRLEN_D
        INC   SI
        INC   CX
        JMP   _RXRT_STRLEN_L
_RXRT_STRLEN_D:
        POP   SI
        RET

_RXRT_NUMTOSTR:
        PUSH   AX
        PUSH   BX
        PUSH   CX
        PUSH   DX
        PUSH   DI
        MOV   DI, OFFSET _RX_NUMBUF
        ADD   DI, 11
        MOV   BYTE PTR [DI], 0
        DEC   DI
        MOV   BX, 10
        XOR   CX, CX
        OR   AX, AX
        JNS   _RXRT_N2S_P
        NEG   AX
        MOV   CX, 1
_RXRT_N2S_P:
        OR   AX, AX
        JNZ   _RXRT_N2S_L
        MOV   BYTE PTR [DI], '0'
        DEC   DI
        JMP   _RXRT_N2S_S
_RXRT_N2S_L:
        XOR   DX, DX
        DIV   BX
        ADD   DL, '0'
        MOV   BYTE PTR [DI], DL
        DEC   DI
        OR   AX, AX
        JNZ   _RXRT_N2S_L
_RXRT_N2S_S:
        OR   CX, CX
        JZ   _RXRT_N2S_D
        MOV   BYTE PTR [DI], '-'
        DEC   DI
_RXRT_N2S_D:
        INC   DI
        MOV   SI, DI
        POP   DI
        POP   DX
        POP   CX
        POP   BX
        POP   AX
        RET

_RXRT_STRTONUM:
        PUSH   BX
        PUSH   CX
        PUSH   SI
        XOR   AX, AX
        XOR   CX, CX
_RXRT_S2N_SP:
        CMP   BYTE PTR [SI], ' '
        JNE   _RXRT_S2N_SG
        INC   SI
        JMP   _RXRT_S2N_SP
_RXRT_S2N_SG:
        CMP   BYTE PTR [SI], '-'
        JNE   _RXRT_S2N_PL
        MOV   CX, 1
        INC   SI
        JMP   _RXRT_S2N_LP
_RXRT_S2N_PL:
        CMP   BYTE PTR [SI], '+'
        JNE   _RXRT_S2N_LP
        INC   SI
_RXRT_S2N_LP:
        MOV   BL, BYTE PTR [SI]
        CMP   BL, '0'
        JB   _RXRT_S2N_DN
        CMP   BL, '9'
        JA   _RXRT_S2N_DN
        SUB   BL, '0'
        XOR   BH, BH
        MOV   DX, AX
        SHL   AX, 1
        SHL   AX, 1
        ADD   AX, DX
        SHL   AX, 1
        ADD   AX, BX
        INC   SI
        JMP   _RXRT_S2N_LP
_RXRT_S2N_DN:
        OR   CX, CX
        JZ   _RXRT_S2N_R
        NEG   AX
_RXRT_S2N_R:
        POP   SI
        POP   CX
        POP   BX
        RET

_RXRT_CONCAT:
        PUSH   BX
        PUSH   CX
        PUSH   SI
        PUSH   DI
        MOV   BX, OFFSET _RX_CATBUF
_RXRT_CAT_L1:
        MOV   AL, BYTE PTR [SI]
        OR   AL, AL
        JZ   _RXRT_CAT_L2
        MOV   BYTE PTR [BX], AL
        INC   SI
        INC   BX
        JMP   _RXRT_CAT_L1
_RXRT_CAT_L2:
        MOV   SI, DI
_RXRT_CAT_L3:
        MOV   AL, BYTE PTR [SI]
        MOV   BYTE PTR [BX], AL
        OR   AL, AL
        JZ   _RXRT_CAT_DN
        INC   SI
        INC   BX
        JMP   _RXRT_CAT_L3
_RXRT_CAT_DN:
        MOV   AX, OFFSET _RX_CATBUF
        POP   DI
        POP   SI
        POP   CX
        POP   BX
        RET

_RXRT_STRCMP:
        PUSH   SI
        PUSH   DI
_RXRT_CMP_SL:
        CMP   BYTE PTR [SI], ' '
        JNE   _RXRT_CMP_SR
        INC   SI
        JMP   _RXRT_CMP_SL
_RXRT_CMP_SR:
        CMP   BYTE PTR [DI], ' '
        JNE   _RXRT_CMP_LP
        INC   DI
        JMP   _RXRT_CMP_SR
_RXRT_CMP_LP:
        MOV   AL, BYTE PTR [SI]
        MOV   AH, BYTE PTR [DI]
        OR   AL, AL
        JNZ   _RXRT_CMP_NZ
        OR   AH, AH
        JNZ   _RXRT_CMP_RS
        XOR   AX, AX
        JMP   _RXRT_CMP_DN
_RXRT_CMP_NZ:
        CMP   AL, ' '
        JNE   _RXRT_CMP_C1
        OR   AH, AH
        JNZ   _RXRT_CMP_C1
        INC   SI
        JMP   _RXRT_CMP_LP
_RXRT_CMP_C1:
        CMP   AH, ' '
        JNE   _RXRT_CMP_C2
        OR   AL, AL
        JNZ   _RXRT_CMP_C2
        INC   DI
        JMP   _RXRT_CMP_LP
_RXRT_CMP_C2:
        CMP   AL, AH
        JB   _RXRT_CMP_LT
        JA   _RXRT_CMP_GT
        INC   SI
        INC   DI
        JMP   _RXRT_CMP_LP
_RXRT_CMP_RS:
        CMP   AH, ' '
        JNE   _RXRT_CMP_LT
        INC   DI
        JMP   _RXRT_CMP_LP
_RXRT_CMP_LT:
        MOV   AX, 0FFFFh
        JMP   _RXRT_CMP_DN
_RXRT_CMP_GT:
        MOV   AX, 1
_RXRT_CMP_DN:
        POP   DI
        POP   SI
        RET

_RXRT_STRCMPS:
        PUSH   SI
        PUSH   DI
_RXRT_SCMP_LP:
        MOV   AL, BYTE PTR [SI]
        MOV   AH, BYTE PTR [DI]
        CMP   AL, AH
        JB   _RXRT_SCMP_LT
        JA   _RXRT_SCMP_GT
        OR   AL, AL
        JZ   _RXRT_SCMP_EQ
        INC   SI
        INC   DI
        JMP   _RXRT_SCMP_LP
_RXRT_SCMP_EQ:
        XOR   AX, AX
        JMP   _RXRT_SCMP_DN
_RXRT_SCMP_LT:
        MOV   AX, 0FFFFh
        JMP   _RXRT_SCMP_DN
_RXRT_SCMP_GT:
        MOV   AX, 1
_RXRT_SCMP_DN:
        POP   DI
        POP   SI
        RET

; --- Runtime E/S REXX (TODO 12) ---

_RXRT_INPUT:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        PUSH   SI
        MOV   BYTE PTR [_RX_INPUTBF], 253
        MOV   BYTE PTR [_RX_INPUTBF+1], 0
        MOV   AH, 0Ah
        LEA   DX, _RX_INPUTBF
        INT     21h
        XOR   BH, BH
        MOV   BL, BYTE PTR [_RX_INPUTBF+1]
        MOV   BYTE PTR [_RX_INPUTBF+BX+2], 0
        LEA   SI, _RX_INPUTBF
        ADD   SI, 2
        LEA   DI, _RX_STRBUF
        CALL   _RXRT_STRCPY
        MOV   SI, OFFSET _RX_CRLF
        CALL   _RXRT_PRINT
        LEA   AX, _RX_STRBUF
        POP   SI
        POP   DX
        POP   CX
        POP   BX
        RET

_RXRT_PRINTINT:
        CALL   _RXRT_NUMTOSTR
        CALL   _RXRT_PRINT
        RET

; --- Runtime BIF chaines (TODO 15) ---

_RXB_LENGTH:
        PUSH   BP
        MOV   BP, SP
        MOV   SI, [BP+4]
        CALL   _RXRT_STRLEN
        MOV   AX, CX
        POP   BP
        RET

_RXB_SUBSTR:
        PUSH   BP
        MOV   BP, SP
        PUSH   DI
        PUSH   SI
        MOV   SI, [BP+8]
        CALL   _RXRT_STRLEN
        MOV   DX, [BP+6]
        MOV   BX, [BP+4]
        LEA   DI, _RX_BIFBUF
        CMP   DX, 1
        JGE   _RXB_SUBS_POK
        MOV   DX, 1
_RXB_SUBS_POK:
        CMP   DX, CX
        JBE   _RXB_SUBS_PIR
        MOV   BYTE PTR [DI], 0
        JMP   _RXB_SUBS_DN
_RXB_SUBS_PIR:
        CMP   BX, 0
        JG   _RXB_SUBS_HL
        MOV   BX, CX
        SUB   BX, DX
        INC   BX
_RXB_SUBS_HL:
        PUSH   AX
        MOV   AX, DX
        ADD   AX, BX
        DEC   AX
        CMP   AX, CX
        POP   AX
        JBE   _RXB_SUBS_CP
        MOV   BX, CX
        SUB   BX, DX
        INC   BX
_RXB_SUBS_CP:
        ADD   SI, DX
        DEC   SI
        MOV   CX, BX
_RXB_SUBS_CL:
        CMP   CX, 0
        JE   _RXB_SUBS_NL
        MOV   AL, [SI]
        CMP   AL, 0
        JE   _RXB_SUBS_NL
        MOV   [DI], AL
        INC   SI
        INC   DI
        DEC   CX
        JMP   _RXB_SUBS_CL
_RXB_SUBS_NL:
        MOV   BYTE PTR [DI], 0
_RXB_SUBS_DN:
        MOV   AX, OFFSET _RX_BIFBUF
        POP   SI
        POP   DI
        POP   BP
        RET

_RXB_LEFT:
        PUSH   BP
        MOV   BP, SP
        PUSH   DI
        PUSH   SI
        MOV   SI, [BP+8]
        MOV   CX, [BP+6]
        MOV   DX, [BP+4]
        LEA   DI, _RX_BIFBUF
_RXB_LEFT_CP:
        CMP   CX, 0
        JE   _RXB_LEFT_DN
        MOV   AL, [SI]
        CMP   AL, 0
        JE   _RXB_LEFT_PD
        MOV   [DI], AL
        INC   SI
        INC   DI
        DEC   CX
        JMP   _RXB_LEFT_CP
_RXB_LEFT_PD:
        CMP   CX, 0
        JE   _RXB_LEFT_DN
        MOV   [DI], DL
        INC   DI
        DEC   CX
        JMP   _RXB_LEFT_PD
_RXB_LEFT_DN:
        MOV   BYTE PTR [DI], 0
        MOV   AX, OFFSET _RX_BIFBUF
        POP   SI
        POP   DI
        POP   BP
        RET

_RXB_RIGHT:
        PUSH   BP
        MOV   BP, SP
        PUSH   DI
        PUSH   SI
        MOV   SI, [BP+8]
        CALL   _RXRT_STRLEN
        MOV   BX, [BP+6]
        MOV   DX, [BP+4]
        LEA   DI, _RX_BIFBUF
        CMP   CX, BX
        JAE   _RXB_RIGHT_NP
        PUSH   CX
        MOV   AX, BX
        SUB   AX, CX
        MOV   CX, AX
_RXB_RIGHT_PL:
        CMP   CX, 0
        JE   _RXB_RIGHT_CC
        MOV   BYTE PTR [DI], DL
        INC   DI
        DEC   CX
        JMP   _RXB_RIGHT_PL
_RXB_RIGHT_CC:
        POP   CX
_RXB_RIGHT_CL:
        CMP   CX, 0
        JE   _RXB_RIGHT_DN
        MOV   AL, [SI]
        MOV   [DI], AL
        INC   SI
        INC   DI
        DEC   CX
        JMP   _RXB_RIGHT_CL
_RXB_RIGHT_NP:
        MOV   AX, CX
        SUB   AX, BX
        ADD   SI, AX
        MOV   CX, BX
_RXB_RIGHT_CF:
        CMP   CX, 0
        JE   _RXB_RIGHT_DN
        MOV   AL, [SI]
        MOV   [DI], AL
        INC   SI
        INC   DI
        DEC   CX
        JMP   _RXB_RIGHT_CF
_RXB_RIGHT_DN:
        MOV   BYTE PTR [DI], 0
        MOV   AX, OFFSET _RX_BIFBUF
        POP   SI
        POP   DI
        POP   BP
        RET

_RXB_CENTER:
        PUSH   BP
        MOV   BP, SP
        PUSH   DI
        PUSH   SI
        MOV   SI, [BP+8]
        CALL   _RXRT_STRLEN
        MOV   BX, [BP+6]
        MOV   DX, [BP+4]
        LEA   DI, _RX_BIFBUF
        CMP   CX, BX
        JAE   _RXB_CTR_TR
        PUSH   CX
        PUSH   DX
        MOV   AX, BX
        SUB   AX, CX
        SHR   AX, 1
        PUSH   AX
        MOV   CX, AX
        POP   AX
        PUSH   AX
        MOV   CX, AX
_RXB_CTR_LP:
        CMP   CX, 0
        JE   _RXB_CTR_CS
        MOV   BYTE PTR [DI], DL
        INC   DI
        DEC   CX
        JMP   _RXB_CTR_LP
_RXB_CTR_CS:
        POP   AX
        POP   DX
        POP   CX
        PUSH   AX
        PUSH   CX
_RXB_CTR_CC:
        CMP   CX, 0
        JE   _RXB_CTR_RP
        MOV   AL, [SI]
        CMP   AL, 0
        JE   _RXB_CTR_RP
        MOV   [DI], AL
        INC   SI
        INC   DI
        DEC   CX
        JMP   _RXB_CTR_CC
_RXB_CTR_RP:
        POP   CX
        POP   AX
        MOV   DX, [BP+4]
        MOV   BX, [BP+6]
        SUB   BX, AX
        SUB   BX, CX
        MOV   CX, BX
_RXB_CTR_RL:
        CMP   CX, 0
        JLE   _RXB_CTR_DN
        MOV   BYTE PTR [DI], DL
        INC   DI
        DEC   CX
        JMP   _RXB_CTR_RL
        JMP   _RXB_CTR_DN
_RXB_CTR_TR:
        MOV   CX, BX
_RXB_CTR_TL:
        CMP   CX, 0
        JE   _RXB_CTR_DN
        MOV   AL, [SI]
        MOV   [DI], AL
        INC   SI
        INC   DI
        DEC   CX
        JMP   _RXB_CTR_TL
_RXB_CTR_DN:
        MOV   BYTE PTR [DI], 0
        MOV   AX, OFFSET _RX_BIFBUF
        POP   SI
        POP   DI
        POP   BP
        RET

_RXB_COPIES:
        PUSH   BP
        MOV   BP, SP
        PUSH   DI
        PUSH   SI
        LEA   DI, _RX_BIFBUF
        MOV   BX, [BP+4]
_RXB_COP_OL:
        CMP   BX, 0
        JLE   _RXB_COP_DN
        MOV   SI, [BP+6]
_RXB_COP_IL:
        MOV   AL, [SI]
        CMP   AL, 0
        JE   _RXB_COP_NX
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _RXB_COP_IL
_RXB_COP_NX:
        DEC   BX
        JMP   _RXB_COP_OL
_RXB_COP_DN:
        MOV   BYTE PTR [DI], 0
        MOV   AX, OFFSET _RX_BIFBUF
        POP   SI
        POP   DI
        POP   BP
        RET

_RXB_REVERSE:
        PUSH   BP
        MOV   BP, SP
        PUSH   DI
        PUSH   SI
        MOV   SI, [BP+4]
        CALL   _RXRT_STRLEN
        LEA   DI, _RX_BIFBUF
        MOV   BYTE PTR [DI+CX], 0
        ADD   SI, CX
        DEC   SI
_RXB_REV_LP:
        CMP   CX, 0
        JE   _RXB_REV_DN
        MOV   AL, [SI]
        MOV   [DI], AL
        DEC   SI
        INC   DI
        DEC   CX
        JMP   _RXB_REV_LP
_RXB_REV_DN:
        MOV   AX, OFFSET _RX_BIFBUF
        POP   SI
        POP   DI
        POP   BP
        RET

_RXB_STRIP:
        PUSH   BP
        MOV   BP, SP
        PUSH   DI
        PUSH   SI
        MOV   SI, [BP+8]
        CALL   _RXRT_STRLEN
        MOV   BX, [BP+6]
        MOV   DX, [BP+4]
        CMP   BL, 84
        JE   _RXB_STR_NL
_RXB_STR_LL:
        CMP   CX, 0
        JE   _RXB_STR_NL
        CMP   BYTE PTR [SI], DL
        JNE   _RXB_STR_NL
        INC   SI
        DEC   CX
        JMP   _RXB_STR_LL
_RXB_STR_NL:
        LEA   DI, _RX_BIFBUF
        PUSH   CX
        PUSH   SI
_RXB_STR_CY:
        CMP   CX, 0
        JE   _RXB_STR_CD
        MOV   AL, [SI]
        MOV   [DI], AL
        INC   SI
        INC   DI
        DEC   CX
        JMP   _RXB_STR_CY
_RXB_STR_CD:
        MOV   BYTE PTR [DI], 0
        POP   SI
        POP   CX
        CMP   BL, 76
        JE   _RXB_STR_DN
        LEA   DI, _RX_BIFBUF
        ADD   DI, CX
        DEC   DI
_RXB_STR_TL:
        CMP   CX, 0
        JE   _RXB_STR_TD
        CMP   BYTE PTR [DI], DL
        JNE   _RXB_STR_TD
        MOV   BYTE PTR [DI], 0
        DEC   DI
        DEC   CX
        JMP   _RXB_STR_TL
_RXB_STR_TD:
_RXB_STR_DN:
        MOV   AX, OFFSET _RX_BIFBUF
        POP   SI
        POP   DI
        POP   BP
        RET

_RXB_SPACE:
        PUSH   BP
        MOV   BP, SP
        PUSH   DI
        PUSH   SI
        MOV   SI, [BP+8]
        MOV   BX, [BP+6]
        MOV   DX, [BP+4]
        LEA   DI, _RX_BIFBUF
_RXB_SPC_SK:
        CMP   BYTE PTR [SI], 32
        JNE   _RXB_SPC_WD
        INC   SI
        JMP   _RXB_SPC_SK
_RXB_SPC_WD:
        CMP   BYTE PTR [SI], 0
        JE   _RXB_SPC_DN
        CMP   BYTE PTR [SI], 32
        JE   _RXB_SPC_SP
        MOV   AL, [SI]
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _RXB_SPC_WD
_RXB_SPC_SP:
_RXB_SPC_S2:
        CMP   BYTE PTR [SI], 32
        JNE   _RXB_SPC_IP
        INC   SI
        JMP   _RXB_SPC_S2
_RXB_SPC_IP:
        CMP   BYTE PTR [SI], 0
        JE   _RXB_SPC_DN
        PUSH   CX
        MOV   CX, BX
_RXB_SPC_PL:
        CMP   CX, 0
        JE   _RXB_SPC_PD
        MOV   BYTE PTR [DI], DL
        INC   DI
        DEC   CX
        JMP   _RXB_SPC_PL
_RXB_SPC_PD:
        POP   CX
        JMP   _RXB_SPC_WD
_RXB_SPC_DN:
        MOV   BYTE PTR [DI], 0
        MOV   AX, OFFSET _RX_BIFBUF
        POP   SI
        POP   DI
        POP   BP
        RET

_RXB_OVERLAY:
        PUSH   BP
        MOV   BP, SP
        PUSH   DI
        PUSH   SI
        MOV   SI, [BP+6]
        LEA   DI, _RX_BIFBUF
        CALL   _RXRT_STRCPY
        LEA   DI, _RX_BIFBUF
        MOV   AX, [BP+4]
        DEC   AX
        ADD   DI, AX
        MOV   SI, [BP+8]
_RXB_OVL_LP:
        MOV   AL, [SI]
        CMP   AL, 0
        JE   _RXB_OVL_DN
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _RXB_OVL_LP
_RXB_OVL_DN:
        CMP   BYTE PTR [DI], 0
        JNE   _RXB_OVL_OK
        MOV   BYTE PTR [DI], 0
_RXB_OVL_OK:
        MOV   AX, OFFSET _RX_BIFBUF
        POP   SI
        POP   DI
        POP   BP
        RET

_RXB_INSERT:
        PUSH   BP
        MOV   BP, SP
        PUSH   DI
        PUSH   SI
        LEA   DI, _RX_BIFBUF
        MOV   BX, [BP+4]
        MOV   SI, [BP+6]
        MOV   CX, BX
_RXB_INS_P1:
        CMP   CX, 0
        JE   _RXB_INS_NW
        MOV   AL, [SI]
        CMP   AL, 0
        JE   _RXB_INS_NW
        MOV   [DI], AL
        INC   SI
        INC   DI
        DEC   CX
        JMP   _RXB_INS_P1
_RXB_INS_NW:
        PUSH   SI
        MOV   SI, [BP+8]
_RXB_INS_NL:
        MOV   AL, [SI]
        CMP   AL, 0
        JE   _RXB_INS_ND
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _RXB_INS_NL
_RXB_INS_ND:
        POP   SI
_RXB_INS_RL:
        MOV   AL, [SI]
        MOV   [DI], AL
        CMP   AL, 0
        JE   _RXB_INS_DN
        INC   SI
        INC   DI
        JMP   _RXB_INS_RL
_RXB_INS_DN:
        MOV   AX, OFFSET _RX_BIFBUF
        POP   SI
        POP   DI
        POP   BP
        RET

_RXB_DELSTR:
        PUSH   BP
        MOV   BP, SP
        PUSH   DI
        PUSH   SI
        MOV   SI, [BP+8]
        LEA   DI, _RX_BIFBUF
        MOV   BX, [BP+6]
        DEC   BX
        MOV   CX, BX
_RXB_DEL_P1:
        CMP   CX, 0
        JE   _RXB_DEL_SK
        MOV   AL, [SI]
        CMP   AL, 0
        JE   _RXB_DEL_DN
        MOV   [DI], AL
        INC   SI
        INC   DI
        DEC   CX
        JMP   _RXB_DEL_P1
_RXB_DEL_SK:
        MOV   CX, [BP+4]
        CMP   CX, 0
        JE   _RXB_DEL_DN
_RXB_DEL_SL:
        CMP   CX, 0
        JE   _RXB_DEL_RS
        CMP   BYTE PTR [SI], 0
        JE   _RXB_DEL_DN
        INC   SI
        DEC   CX
        JMP   _RXB_DEL_SL
_RXB_DEL_RS:
_RXB_DEL_RL:
        MOV   AL, [SI]
        MOV   [DI], AL
        CMP   AL, 0
        JE   _RXB_DEL_DN
        INC   SI
        INC   DI
        JMP   _RXB_DEL_RL
_RXB_DEL_DN:
        MOV   BYTE PTR [DI], 0
        MOV   AX, OFFSET _RX_BIFBUF
        POP   SI
        POP   DI
        POP   BP
        RET

_RXB_POS:
        PUSH   BP
        MOV   BP, SP
        PUSH   DI
        PUSH   SI
        MOV   SI, [BP+8]
        CALL   _RXRT_STRLEN
        MOV   BX, CX
        CMP   BX, 0
        JE   _RXB_POS_NF
        MOV   SI, [BP+6]
        CALL   _RXRT_STRLEN
        MOV   DX, [BP+4]
        DEC   DX
        MOV   SI, [BP+6]
        ADD   SI, DX
        SUB   CX, DX
        INC   DX
_RXB_POS_LP:
        CMP   CX, BX
        JB   _RXB_POS_NF
        PUSH   SI
        PUSH   CX
        MOV   DI, [BP+8]
        MOV   CX, BX
_RXB_POS_CM:
        CMP   CX, 0
        JE   _RXB_POS_FD
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _RXB_POS_NM
        INC   SI
        INC   DI
        DEC   CX
        JMP   _RXB_POS_CM
_RXB_POS_FD:
        POP   CX
        POP   SI
        MOV   AX, DX
        JMP   _RXB_POS_DN
_RXB_POS_NM:
        POP   CX
        POP   SI
        INC   SI
        INC   DX
        DEC   CX
        JMP   _RXB_POS_LP
_RXB_POS_NF:
        XOR   AX, AX
_RXB_POS_DN:
        POP   SI
        POP   DI
        POP   BP
        RET

_RXB_LASTPOS:
        PUSH   BP
        MOV   BP, SP
        PUSH   DI
        PUSH   SI
        MOV   SI, [BP+8]
        CALL   _RXRT_STRLEN
        MOV   BX, CX
        CMP   BX, 0
        JE   _RXB_LPO_NF
        MOV   SI, [BP+6]
        CALL   _RXRT_STRLEN
        XOR   AX, AX
        MOV   DX, 1
        MOV   SI, [BP+6]
_RXB_LPO_LP:
        CMP   CX, BX
        JB   _RXB_LPO_DN
        PUSH   SI
        PUSH   CX
        MOV   DI, [BP+8]
        MOV   CX, BX
_RXB_LPO_CM:
        CMP   CX, 0
        JE   _RXB_LPO_FD
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _RXB_LPO_NM
        INC   SI
        INC   DI
        DEC   CX
        JMP   _RXB_LPO_CM
_RXB_LPO_FD:
        POP   CX
        POP   SI
        MOV   AX, DX
        INC   SI
        INC   DX
        DEC   CX
        JMP   _RXB_LPO_LP
_RXB_LPO_NM:
        POP   CX
        POP   SI
        INC   SI
        INC   DX
        DEC   CX
        JMP   _RXB_LPO_LP
_RXB_LPO_NF:
        XOR   AX, AX
_RXB_LPO_DN:
        POP   SI
        POP   DI
        POP   BP
        RET


; --- sortie DOS ---
        MOV   AX, 4C00h
        INT     21h

_TEXT ENDS


_DATA SEGMENT PUBLIC 'DATA'
        ASSUME DS:_DATA

; Donnees REXX (predefinies + utilisateur)
_RX_RC DW 0
_RX_RESULT DB 'RESULT',0
_RX_SIGL DW 0
_RX_CRLF DB 13,10,0
_RX_NULL_STR DB 0
_RX_TRUE_S DB '1',0
_RX_FALSE_S DB '0',0
_RX_SPC_S DB ' ',0
_RX_STRBUF DB 256 DUP(0)
_RX_TMPBUF DB 256 DUP(0)
_RX_NUMBUF DB 12 DUP(0)
_RX_CATBUF DB 256 DUP(0)
_RX_INPUTBF DB 256 DUP(0)
_RX_BIFBUF DB 256 DUP(0)
_RXK_1 DB 'Hello',0
_RXK_2 DB 'World',0
_RXK_3 DB 'abc',0
_RXK_4 DB 'def',0
_RXK_5 DB 'b',0
_RXK_6 DB 'a',0
_DATA ENDS

END _RXP_Main
