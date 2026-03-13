; REXX86 v1.0 - SAMPLES/REXX/test_loops.rexx
.MODEL SMALL
.STACK 1024

_TEXT SEGMENT PUBLIC 'CODE'
        ASSUME CS:_TEXT, DS:_DATA, SS:NOTHING

; --- Point d'entree (main) ---
_RXP_Main:
        MOV   AX, _DATA
        MOV   DS, AX

; assign: I = ...
        MOV     AX, 0
        MOV     SI, AX
        LEA     DI, _RXV_I
        CALL     _RXRT_STRCPY
; DO WHILE
_RXL_1:
        LEA     AX, _RXV_I
        PUSH     AX
        MOV     AX, 3
        MOV     BX, AX
        POP     AX
        MOV     SI, AX
        MOV     DI, BX
        CALL    _RXRT_STRCMP
        CMP     AX, 0FFFFh
        MOV     AX, 0
        JNE     _RXL_3
        INC     AX
_RXL_3:
        TEST   AX, AX
        JZ      _RXL_2
; SAY
        LEA     AX, _RXV_I
        MOV   SI, AX
        CALL   _RXRT_PRINTLN
; assign: I = ...
        LEA     AX, _RXV_I
        PUSH     AX
        MOV     AX, 1
        MOV     BX, AX
        POP     AX
        ADD     AX, BX
        MOV     SI, AX
        LEA     DI, _RXV_I
        CALL     _RXRT_STRCPY
        JMP     _RXL_1
_RXL_2:
; assign: J = ...
        MOV     AX, 10
        MOV     SI, AX
        LEA     DI, _RXV_J
        CALL     _RXRT_STRCPY
; DO FOREVER
_RXL_4:
; SAY
        LEA     AX, _RXV_J
        MOV   SI, AX
        CALL   _RXRT_PRINTLN
; assign: J = ...
        LEA     AX, _RXV_J
        PUSH     AX
        MOV     AX, 1
        MOV     BX, AX
        POP     AX
        SUB     AX, BX
        MOV     SI, AX
        LEA     DI, _RXV_J
        CALL     _RXRT_STRCPY
; IF
        LEA     AX, _RXV_J
        PUSH     AX
        MOV     AX, 8
        MOV     BX, AX
        POP     AX
        MOV     SI, AX
        MOV     DI, BX
        CALL    _RXRT_STRCMP
        CMP     AX, 0FFFFh
        MOV     AX, 0
        JNE     _RXL_6
        INC     AX
_RXL_6:
        TEST   AX, AX
        JZ      _RXL_7
; LEAVE
        JMP     _RXL_5
_RXL_7:
        JMP     _RXL_4
_RXL_5:
; DO K = ... TO ... [BY ...]
        MOV     AX, 1
        CALL     _RXRT_NUMTOSTR
        MOV     SI, AX
        LEA     DI, _RXV_K
        CALL     _RXRT_STRCPY
        MOV     AX, 5
        MOV     SI, AX
        LEA     DI, _RXL_9_FIN
        CALL     _RXRT_STRCPY
_RXL_10:
        LEA     AX, _RXV_K
        MOV     SI, AX
        CALL     _RXRT_STRTONUM
        PUSH     AX
        LEA     SI, _RXL_9_FIN
        CALL     _RXRT_STRTONUM
        MOV     BX, AX
        POP     AX
        CMP   AX, BX
        JG      _RXL_12
; SAY
        LEA     AX, _RXV_K
        MOV   SI, AX
        CALL   _RXRT_PRINTLN
_RXL_11:
        LEA     AX, _RXV_K
        MOV     SI, AX
        CALL     _RXRT_STRTONUM
        INC     AX
        CALL     _RXRT_NUMTOSTR
        MOV     SI, AX
        LEA     DI, _RXV_K
        CALL     _RXRT_STRCPY
        JMP     _RXL_10
_RXL_12:
; DO M = ... TO ... [BY ...]
        MOV     AX, 0
        CALL     _RXRT_NUMTOSTR
        MOV     SI, AX
        LEA     DI, _RXV_M
        CALL     _RXRT_STRCPY
        MOV     AX, 10
        MOV     SI, AX
        LEA     DI, _RXL_13_FIN
        CALL     _RXRT_STRCPY
        MOV     AX, 3
        MOV     SI, AX
        LEA     DI, _RXL_14_STEP
        CALL     _RXRT_STRCPY
_RXL_15:
        LEA     AX, _RXV_M
        MOV     SI, AX
        CALL     _RXRT_STRTONUM
        PUSH     AX
        LEA     SI, _RXL_13_FIN
        CALL     _RXRT_STRTONUM
        MOV     BX, AX
        POP     AX
        CMP   AX, BX
        JG      _RXL_17
; SAY
        LEA     AX, _RXV_M
        MOV   SI, AX
        CALL   _RXRT_PRINTLN
_RXL_16:
        LEA     AX, _RXV_M
        MOV     SI, AX
        CALL     _RXRT_STRTONUM
        PUSH     AX
        LEA     SI, _RXL_14_STEP
        CALL     _RXRT_STRTONUM
        MOV     BX, AX
        POP     AX
        ADD   AX, BX
        CALL     _RXRT_NUMTOSTR
        MOV     SI, AX
        LEA     DI, _RXV_M
        CALL     _RXRT_STRCPY
        JMP     _RXL_15
_RXL_17:
; DO expr (repeat N times)
        MOV     AX, 3
        MOV     SI, AX
        CALL     _RXRT_STRTONUM
        MOV     WORD PTR _RXL_18_CNT, AX
_RXL_19:
        MOV     AX, WORD PTR _RXL_18_CNT
        CMP   AX, 0
        JLE     _RXL_20
; SAY
        LEA     AX, _RXK_1
        MOV   SI, AX
        CALL   _RXRT_PRINTLN
        DEC     WORD PTR _RXL_18_CNT
        JMP     _RXL_19
_RXL_20:
; DO block
; SAY
        LEA     AX, _RXK_2
        MOV   SI, AX
        CALL   _RXRT_PRINTLN
; SAY
        LEA     AX, _RXK_3
        MOV   SI, AX
        CALL   _RXRT_PRINTLN
; assign: N = ...
        MOV     AX, 0
        MOV     SI, AX
        LEA     DI, _RXV_N
        CALL     _RXRT_STRCPY
; DO WHILE
_RXL_21:
        LEA     AX, _RXV_N
        PUSH     AX
        MOV     AX, 5
        MOV     BX, AX
        POP     AX
        MOV     SI, AX
        MOV     DI, BX
        CALL    _RXRT_STRCMP
        CMP     AX, 0FFFFh
        MOV     AX, 0
        JNE     _RXL_23
        INC     AX
_RXL_23:
        TEST   AX, AX
        JZ      _RXL_22
; assign: N = ...
        LEA     AX, _RXV_N
        PUSH     AX
        MOV     AX, 1
        MOV     BX, AX
        POP     AX
        ADD     AX, BX
        MOV     SI, AX
        LEA     DI, _RXV_N
        CALL     _RXRT_STRCPY
; IF
        LEA     AX, _RXV_N
        PUSH     AX
        MOV     AX, 3
        MOV     BX, AX
        POP     AX
        MOV     SI, AX
        MOV     DI, BX
        CALL    _RXRT_STRCMP
        OR     AX, AX
        MOV     AX, 0
        JNE     _RXL_24
        INC     AX
_RXL_24:
        TEST   AX, AX
        JZ      _RXL_25
; ITERATE
        JMP     _RXL_21
_RXL_25:
; SAY
        LEA     AX, _RXV_N
        MOV   SI, AX
        CALL   _RXRT_PRINTLN
        JMP     _RXL_21
_RXL_22:
; assign: P = ...
        MOV     AX, 1
        MOV     SI, AX
        LEA     DI, _RXV_P
        CALL     _RXRT_STRCPY
; DO UNTIL
        JMP     _RXL_28
_RXL_27:
        LEA     AX, _RXV_P
        PUSH     AX
        MOV     AX, 4
        MOV     BX, AX
        POP     AX
        MOV     SI, AX
        MOV     DI, BX
        CALL    _RXRT_STRCMP
        CMP     AX, 1
        MOV     AX, 0
        JNE     _RXL_30
        INC     AX
_RXL_30:
        TEST   AX, AX
        JNZ     _RXL_29
_RXL_28:
; SAY
        LEA     AX, _RXV_P
        MOV   SI, AX
        CALL   _RXRT_PRINTLN
; assign: P = ...
        LEA     AX, _RXV_P
        PUSH     AX
        MOV     AX, 1
        MOV     BX, AX
        POP     AX
        ADD     AX, BX
        MOV     SI, AX
        LEA     DI, _RXV_P
        CALL     _RXRT_STRCPY
        JMP     _RXL_27
_RXL_29:
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

; --- Runtime BIF partie 2 (TODO 18) ---

_RXB_WORDS:
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        MOV   SI, [BP+4]
        XOR   AX, AX
        XOR   DX, DX
_RXB2_WS_LP:
        MOV   BL, [SI]
        CMP   BL, 0
        JE   _RXB2_WS_DN
        CMP   BL, ' '
        JE   _RXB2_WS_SP
        CMP   DX, 0
        JNE   _RXB2_WS_NX
        INC   AX
        MOV   DX, 1
        JMP   _RXB2_WS_NX
_RXB2_WS_SP:
        XOR   DX, DX
_RXB2_WS_NX:
        INC   SI
        JMP   _RXB2_WS_LP
_RXB2_WS_DN:
        POP   SI
        POP   BP
        RET

_RXB_WORD:
        PUSH   BP
        MOV   BP, SP
        PUSH   DI
        PUSH   SI
        MOV   SI, [BP+6]
        MOV   CX, [BP+4]
        LEA   DI, _RX_BIF2BUF
        XOR   DX, DX
_RXB2_W_SKP:
        CMP   BYTE PTR [SI], 0
        JE   _RXB2_W_EMP
        CMP   BYTE PTR [SI], ' '
        JNE   _RXB2_W_FW
        INC   SI
        JMP   _RXB2_W_SKP
_RXB2_W_FW:
        INC   DX
        CMP   DX, CX
        JE   _RXB2_W_CPY
_RXB2_W_SRW:
        CMP   BYTE PTR [SI], 0
        JE   _RXB2_W_EMP
        CMP   BYTE PTR [SI], ' '
        JE   _RXB2_W_SKP
        INC   SI
        JMP   _RXB2_W_SRW
_RXB2_W_CPY:
        MOV   AL, [SI]
        CMP   AL, 0
        JE   _RXB2_W_END
        CMP   AL, ' '
        JE   _RXB2_W_END
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _RXB2_W_CPY
_RXB2_W_EMP:
_RXB2_W_END:
        MOV   BYTE PTR [DI], 0
        MOV   AX, OFFSET _RX_BIF2BUF
        POP   SI
        POP   DI
        POP   BP
        RET

_RXB_WORDINDEX:
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        MOV   SI, [BP+6]
        MOV   CX, [BP+4]
        XOR   DX, DX
        XOR   BX, BX
_RXB2_WI_LP:
        CMP   BYTE PTR [SI], 0
        JE   _RXB2_WI_NF
        INC   BX
        CMP   BYTE PTR [SI], ' '
        JNE   _RXB2_WI_FW
        INC   SI
        JMP   _RXB2_WI_LP
_RXB2_WI_FW:
        INC   DX
        CMP   DX, CX
        JE   _RXB2_WI_OK
_RXB2_WI_SK:
        CMP   BYTE PTR [SI], 0
        JE   _RXB2_WI_NF
        CMP   BYTE PTR [SI], ' '
        JE   _RXB2_WI_LP
        INC   SI
        INC   BX
        JMP   _RXB2_WI_SK
_RXB2_WI_OK:
        MOV   AX, BX
        JMP   _RXB2_WI_DN
_RXB2_WI_NF:
        XOR   AX, AX
_RXB2_WI_DN:
        POP   SI
        POP   BP
        RET

_RXB_WORDLENGTH:
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        MOV   SI, [BP+6]
        MOV   CX, [BP+4]
        XOR   DX, DX
_RXB2_WL_LP:
        CMP   BYTE PTR [SI], 0
        JE   _RXB2_WL_NF
        CMP   BYTE PTR [SI], ' '
        JNE   _RXB2_WL_FW
        INC   SI
        JMP   _RXB2_WL_LP
_RXB2_WL_FW:
        INC   DX
        CMP   DX, CX
        JE   _RXB2_WL_CT
_RXB2_WL_SK:
        CMP   BYTE PTR [SI], 0
        JE   _RXB2_WL_NF
        CMP   BYTE PTR [SI], ' '
        JE   _RXB2_WL_LP
        INC   SI
        JMP   _RXB2_WL_SK
_RXB2_WL_CT:
        XOR   AX, AX
_RXB2_WL_CL:
        CMP   BYTE PTR [SI], 0
        JE   _RXB2_WL_DN
        CMP   BYTE PTR [SI], ' '
        JE   _RXB2_WL_DN
        INC   AX
        INC   SI
        JMP   _RXB2_WL_CL
_RXB2_WL_NF:
        XOR   AX, AX
_RXB2_WL_DN:
        POP   SI
        POP   BP
        RET

_RXB_WORDPOS:
        PUSH   BP
        MOV   BP, SP
        PUSH   DI
        PUSH   SI
        MOV   SI, [BP+8]
_RXB2_WP_SS:
        CMP   BYTE PTR [SI], ' '
        JNE   _RXB2_WP_S1
        INC   SI
        JMP   _RXB2_WP_SS
_RXB2_WP_S1:
        LEA   DI, _RX_BIF2BUF
_RXB2_WP_CW:
        MOV   AL, [SI]
        CMP   AL, 0
        JE   _RXB2_WP_CE
        CMP   AL, ' '
        JE   _RXB2_WP_CE
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _RXB2_WP_CW
_RXB2_WP_CE:
        MOV   BYTE PTR [DI], 0
        MOV   SI, [BP+6]
        XOR   DX, DX
_RXB2_WP_NW:
        CMP   BYTE PTR [SI], 0
        JE   _RXB2_WP_NF
        CMP   BYTE PTR [SI], ' '
        JNE   _RXB2_WP_GW
        INC   SI
        JMP   _RXB2_WP_NW
_RXB2_WP_GW:
        INC   DX
        PUSH   SI
        LEA   DI, _RX_BIF2BUF
_RXB2_WP_CM:
        MOV   AL, [DI]
        CMP   AL, 0
        JNE   _RXB2_WP_C2
        CMP   BYTE PTR [SI], ' '
        JE   _RXB2_WP_FD
        CMP   BYTE PTR [SI], 0
        JE   _RXB2_WP_FD
        JMP   _RXB2_WP_NM
_RXB2_WP_C2:
        MOV   BL, [SI]
        CMP   AL, BL
        JNE   _RXB2_WP_NM
        INC   SI
        INC   DI
        JMP   _RXB2_WP_CM
_RXB2_WP_NM:
        POP   SI
_RXB2_WP_SR:
        CMP   BYTE PTR [SI], 0
        JE   _RXB2_WP_NF
        CMP   BYTE PTR [SI], ' '
        JE   _RXB2_WP_NW
        INC   SI
        JMP   _RXB2_WP_SR
_RXB2_WP_FD:
        POP   SI
        MOV   AX, DX
        JMP   _RXB2_WP_DN
_RXB2_WP_NF:
        XOR   AX, AX
_RXB2_WP_DN:
        POP   SI
        POP   DI
        POP   BP
        RET

_RXB_SUBWORD:
        PUSH   BP
        MOV   BP, SP
        PUSH   DI
        PUSH   SI
        MOV   SI, [BP+8]
        MOV   CX, [BP+6]
        MOV   BX, [BP+4]
        LEA   DI, _RX_BIF2BUF
        XOR   DX, DX
_RXB2_SW_SK:
        CMP   BYTE PTR [SI], 0
        JE   _RXB2_SW_ED
        CMP   BYTE PTR [SI], ' '
        JNE   _RXB2_SW_FW
        INC   SI
        JMP   _RXB2_SW_SK
_RXB2_SW_FW:
        INC   DX
        CMP   DX, CX
        JGE   _RXB2_SW_CP
_RXB2_SW_S2:
        CMP   BYTE PTR [SI], 0
        JE   _RXB2_SW_ED
        CMP   BYTE PTR [SI], ' '
        JE   _RXB2_SW_SK
        INC   SI
        JMP   _RXB2_SW_S2
_RXB2_SW_CP:
        CMP   BX, 0
        JE   _RXB2_SW_AL
        MOV   CX, BX
_RXB2_SW_CW:
        CMP   CX, 0
        JE   _RXB2_SW_ED
        CMP   BYTE PTR [SI], 0
        JE   _RXB2_SW_ED
        CMP   BYTE PTR [SI], ' '
        JNE   _RXB2_SW_CC
        MOV   BYTE PTR [DI], ' '
        INC   DI
        INC   SI
        JMP   _RXB2_SW_CW
_RXB2_SW_CC:
        MOV   AL, [SI]
        CMP   AL, 0
        JE   _RXB2_SW_D2
        CMP   AL, ' '
        JE   _RXB2_SW_D2
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _RXB2_SW_CC
_RXB2_SW_D2:
        DEC   CX
        JMP   _RXB2_SW_CW
_RXB2_SW_AL:
        MOV   AL, [SI]
        CMP   AL, 0
        JE   _RXB2_SW_ED
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _RXB2_SW_AL
_RXB2_SW_ED:
        MOV   BYTE PTR [DI], 0
        MOV   AX, OFFSET _RX_BIF2BUF
        POP   SI
        POP   DI
        POP   BP
        RET

_RXB_DELWORD:
        PUSH   BP
        MOV   BP, SP
        PUSH   DI
        PUSH   SI
        MOV   SI, [BP+8]
        MOV   CX, [BP+6]
        MOV   BX, [BP+4]
        LEA   DI, _RX_BIF2BUF
        XOR   DX, DX
_RXB2_DW_LP:
        CMP   BYTE PTR [SI], 0
        JE   _RXB2_DW_ED
        CMP   BYTE PTR [SI], ' '
        JNE   _RXB2_DW_FW
        MOV   AL, ' '
        MOV   [DI], AL
        INC   DI
        INC   SI
        JMP   _RXB2_DW_LP
_RXB2_DW_FW:
        INC   DX
        CMP   DX, CX
        JGE   _RXB2_DW_DL
_RXB2_DW_CW:
        MOV   AL, [SI]
        CMP   AL, 0
        JE   _RXB2_DW_ED
        CMP   AL, ' '
        JE   _RXB2_DW_LP
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _RXB2_DW_CW
_RXB2_DW_DL:
        CMP   BX, 0
        JE   _RXB2_DW_RA
        MOV   CX, BX
_RXB2_DW_DS:
        CMP   CX, 0
        JE   _RXB2_DW_CR
_RXB2_DW_D2:
        CMP   BYTE PTR [SI], 0
        JE   _RXB2_DW_ED
        CMP   BYTE PTR [SI], ' '
        JNE   _RXB2_DW_D3
        INC   SI
        JMP   _RXB2_DW_D2
_RXB2_DW_D3:
        CMP   BYTE PTR [SI], 0
        JE   _RXB2_DW_ED
        CMP   BYTE PTR [SI], ' '
        JE   _RXB2_DW_D4
        INC   SI
        JMP   _RXB2_DW_D3
_RXB2_DW_D4:
        DEC   CX
        JMP   _RXB2_DW_DS
_RXB2_DW_CR:
        MOV   AL, [SI]
        CMP   AL, 0
        JE   _RXB2_DW_ED
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _RXB2_DW_CR
_RXB2_DW_RA:
_RXB2_DW_ED:
        MOV   BYTE PTR [DI], 0
        MOV   AX, OFFSET _RX_BIF2BUF
        POP   SI
        POP   DI
        POP   BP
        RET

_RXB_C2D:
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        MOV   SI, [BP+4]
        XOR   AX, AX
        MOV   AL, [SI]
        POP   SI
        POP   BP
        RET

_RXB_C2X:
        PUSH   BP
        MOV   BP, SP
        PUSH   DI
        PUSH   SI
        MOV   SI, [BP+4]
        XOR   AX, AX
        MOV   AL, [SI]
        LEA   DI, _RX_BIF2BUF
        MOV   BL, AL
        SHR   BL, 1
        SHR   BL, 1
        SHR   BL, 1
        SHR   BL, 1
        AND   BL, 0Fh
        CMP   BL, 10
        JB   _RXB2_C2X_D1
        ADD   BL, 'A'
        SUB   BL, 10
        JMP   _RXB2_C2X_S1
_RXB2_C2X_D1:
        ADD   BL, '0'
_RXB2_C2X_S1:
        MOV   [DI], BL
        INC   DI
        MOV   BL, AL
        AND   BL, 0Fh
        CMP   BL, 10
        JB   _RXB2_C2X_D2
        ADD   BL, 'A'
        SUB   BL, 10
        JMP   _RXB2_C2X_S2
_RXB2_C2X_D2:
        ADD   BL, '0'
_RXB2_C2X_S2:
        MOV   [DI], BL
        INC   DI
        MOV   BYTE PTR [DI], 0
        MOV   AX, OFFSET _RX_BIF2BUF
        POP   SI
        POP   DI
        POP   BP
        RET

_RXB_D2C:
        PUSH   BP
        MOV   BP, SP
        PUSH   DI
        LEA   DI, _RX_BIF2BUF
        MOV   AX, [BP+4]
        MOV   [DI], AL
        MOV   BYTE PTR [DI+1], 0
        MOV   AX, OFFSET _RX_BIF2BUF
        POP   DI
        POP   BP
        RET

_RXB_D2X:
        PUSH   BP
        MOV   BP, SP
        PUSH   DI
        PUSH   SI
        MOV   AX, [BP+4]
        LEA   DI, _RX_BIF2BUF
        ADD   DI, 8
        MOV   BYTE PTR [DI], 0
        DEC   DI
        MOV   BX, 16
        OR   AX, AX
        JNZ   _RXB2_D2X_LP
        MOV   BYTE PTR [DI], '0'
        JMP   _RXB2_D2X_R
_RXB2_D2X_LP:
        XOR   DX, DX
        DIV   BX
        CMP   DL, 10
        JB   _RXB2_D2X_DG
        ADD   DL, 'A'
        SUB   DL, 10
        JMP   _RXB2_D2X_ST
_RXB2_D2X_DG:
        ADD   DL, '0'
_RXB2_D2X_ST:
        MOV   [DI], DL
        DEC   DI
        OR   AX, AX
        JNZ   _RXB2_D2X_LP
        INC   DI
_RXB2_D2X_R:
        MOV   SI, DI
        LEA   DI, _RX_BIF2BUF
        CMP   SI, DI
        JE   _RXB2_D2X_DN
        CALL   _RXRT_STRCPY
_RXB2_D2X_DN:
        MOV   AX, OFFSET _RX_BIF2BUF
        POP   SI
        POP   DI
        POP   BP
        RET

_RXB_X2C:
        PUSH   BP
        MOV   BP, SP
        PUSH   DI
        PUSH   SI
        MOV   SI, [BP+4]
        XOR   AX, AX
        MOV   BL, [SI]
        CMP   BL, 0
        JE   _RXB2_X2C_DN
        CMP   BL, 'a'
        JB   _RXB2_X2C_UA
        SUB   BL, 32
_RXB2_X2C_UA:
        CMP   BL, 'A'
        JB   _RXB2_X2C_D1
        SUB   BL, 'A'
        ADD   BL, 10
        JMP   _RXB2_X2C_H1
_RXB2_X2C_D1:
        SUB   BL, '0'
_RXB2_X2C_H1:
        SHL   BL, 1
        SHL   BL, 1
        SHL   BL, 1
        SHL   BL, 1
        MOV   AL, BL
        INC   SI
        MOV   BL, [SI]
        CMP   BL, 0
        JE   _RXB2_X2C_DN
        CMP   BL, 'a'
        JB   _RXB2_X2C_UB
        SUB   BL, 32
_RXB2_X2C_UB:
        CMP   BL, 'A'
        JB   _RXB2_X2C_D2
        SUB   BL, 'A'
        ADD   BL, 10
        JMP   _RXB2_X2C_H2
_RXB2_X2C_D2:
        SUB   BL, '0'
_RXB2_X2C_H2:
        OR   AL, BL
_RXB2_X2C_DN:
        LEA   DI, _RX_BIF2BUF
        MOV   [DI], AL
        MOV   BYTE PTR [DI+1], 0
        MOV   AX, OFFSET _RX_BIF2BUF
        POP   SI
        POP   DI
        POP   BP
        RET

_RXB_X2D:
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        MOV   SI, [BP+4]
        XOR   AX, AX
_RXB2_X2D_LP:
        MOV   BL, [SI]
        CMP   BL, 0
        JE   _RXB2_X2D_DN
        CMP   BL, 'a'
        JB   _RXB2_X2D_UA
        SUB   BL, 32
_RXB2_X2D_UA:
        SHL   AX, 1
        SHL   AX, 1
        SHL   AX, 1
        SHL   AX, 1
        CMP   BL, 'A'
        JB   _RXB2_X2D_DG
        SUB   BL, 'A'
        ADD   BL, 10
        JMP   _RXB2_X2D_AD
_RXB2_X2D_DG:
        SUB   BL, '0'
_RXB2_X2D_AD:
        XOR   BH, BH
        OR   AX, BX
        INC   SI
        JMP   _RXB2_X2D_LP
_RXB2_X2D_DN:
        POP   SI
        POP   BP
        RET

_RXB_B2X:
        PUSH   BP
        MOV   BP, SP
        PUSH   DI
        PUSH   SI
        MOV   SI, [BP+4]
        XOR   AX, AX
_RXB2_B2X_LP:
        MOV   BL, [SI]
        CMP   BL, 0
        JE   _RXB2_B2X_CV
        SHL   AX, 1
        CMP   BL, '1'
        JNE   _RXB2_B2X_NX
        INC   AX
_RXB2_B2X_NX:
        INC   SI
        JMP   _RXB2_B2X_LP
_RXB2_B2X_CV:
        LEA   DI, _RX_BIF2BUF
        ADD   DI, 8
        MOV   BYTE PTR [DI], 0
        DEC   DI
        MOV   BX, 16
        OR   AX, AX
        JNZ   _RXB2_B2X_DL
        MOV   BYTE PTR [DI], '0'
        JMP   _RXB2_B2X_R
_RXB2_B2X_DL:
        XOR   DX, DX
        DIV   BX
        CMP   DL, 10
        JB   _RXB2_B2X_D
        ADD   DL, 'A'
        SUB   DL, 10
        JMP   _RXB2_B2X_S
_RXB2_B2X_D:
        ADD   DL, '0'
_RXB2_B2X_S:
        MOV   [DI], DL
        DEC   DI
        OR   AX, AX
        JNZ   _RXB2_B2X_DL
        INC   DI
_RXB2_B2X_R:
        MOV   SI, DI
        LEA   DI, _RX_BIF2BUF
        CMP   SI, DI
        JE   _RXB2_B2X_DN
        CALL   _RXRT_STRCPY
_RXB2_B2X_DN:
        MOV   AX, OFFSET _RX_BIF2BUF
        POP   SI
        POP   DI
        POP   BP
        RET

_RXB_X2B:
        PUSH   BP
        MOV   BP, SP
        PUSH   DI
        PUSH   SI
        MOV   SI, [BP+4]
        LEA   DI, _RX_BIF2BUF
_RXB2_X2B_LP:
        MOV   BL, [SI]
        CMP   BL, 0
        JE   _RXB2_X2B_DN
        CMP   BL, 'a'
        JB   _RXB2_X2B_UA
        SUB   BL, 32
_RXB2_X2B_UA:
        CMP   BL, 'A'
        JB   _RXB2_X2B_DG
        SUB   BL, 'A'
        ADD   BL, 10
        JMP   _RXB2_X2B_CV
_RXB2_X2B_DG:
        SUB   BL, '0'
_RXB2_X2B_CV:
        MOV   CX, 4
_RXB2_X2B_BT:
        TEST   BL, 8
        JZ   _RXB2_X2B_B0
        MOV   BYTE PTR [DI], '1'
        JMP   _RXB2_X2B_BN
_RXB2_X2B_B0:
        MOV   BYTE PTR [DI], '0'
_RXB2_X2B_BN:
        INC   DI
        SHL   BL, 1
        DEC   CX
        JNZ   _RXB2_X2B_BT
        INC   SI
        JMP   _RXB2_X2B_LP
_RXB2_X2B_DN:
        MOV   BYTE PTR [DI], 0
        MOV   AX, OFFSET _RX_BIF2BUF
        POP   SI
        POP   DI
        POP   BP
        RET

_RXB_ABS:
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        MOV   SI, [BP+4]
        CALL   _RXRT_STRTONUM
        OR   AX, AX
        JNS   _RXB2_ABS_DN
        NEG   AX
_RXB2_ABS_DN:
        POP   SI
        POP   BP
        RET

_RXB_SIGN:
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        MOV   SI, [BP+4]
        CALL   _RXRT_STRTONUM
        CMP   AX, 0
        JE   _RXB2_SGN_DN
        JG   _RXB2_SGN_P
        MOV   AX, -1
        JMP   _RXB2_SGN_DN
_RXB2_SGN_P:
        MOV   AX, 1
_RXB2_SGN_DN:
        POP   SI
        POP   BP
        RET

_RXB_MAX:
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        MOV   SI, [BP+6]
        CALL   _RXRT_STRTONUM
        MOV   BX, AX
        MOV   SI, [BP+4]
        CALL   _RXRT_STRTONUM
        CMP   BX, AX
        JLE   _RXB2_MAX_DN
        MOV   AX, BX
_RXB2_MAX_DN:
        POP   SI
        POP   BP
        RET

_RXB_MIN:
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        MOV   SI, [BP+6]
        CALL   _RXRT_STRTONUM
        MOV   BX, AX
        MOV   SI, [BP+4]
        CALL   _RXRT_STRTONUM
        CMP   BX, AX
        JGE   _RXB2_MIN_DN
        MOV   AX, BX
_RXB2_MIN_DN:
        POP   SI
        POP   BP
        RET

_RXB_TRUNC:
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        MOV   SI, [BP+6]
        CALL   _RXRT_STRTONUM
        POP   SI
        POP   BP
        RET

_RXB_FORMAT:
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        MOV   SI, [BP+4]
        CALL   _RXRT_STRTONUM
        POP   SI
        POP   BP
        RET

_RXB_RANDOM:
        PUSH   BP
        MOV   BP, SP
        PUSH   DX
        MOV   AH, 0
        INT     1Ah
        MOV   AX, DX
        MOV   BX, [BP+6]
        SUB   BX, [BP+8]
        INC   BX
        XOR   DX, DX
        DIV   BX
        MOV   AX, DX
        ADD   AX, [BP+8]
        POP   DX
        POP   BP
        RET

_RXB_TIME:
        PUSH   BP
        MOV   BP, SP
        PUSH   DI
        LEA   DI, _RX_BIF2BUF
        MOV   AH, 2Ch
        INT     21h
        MOV   AL, CH
        XOR   AH, AH
        PUSH   CX
        PUSH   DX
        MOV   BL, 10
        XOR   AH, AH
        DIV   BL
        ADD   AL, '0'
        MOV   [DI], AL
        INC   DI
        ADD   AH, '0'
        MOV   [DI], AH
        INC   DI
        MOV   BYTE PTR [DI], ':'
        INC   DI
        POP   DX
        POP   CX
        MOV   AL, CL
        XOR   AH, AH
        PUSH   DX
        MOV   BL, 10
        DIV   BL
        ADD   AL, '0'
        MOV   [DI], AL
        INC   DI
        ADD   AH, '0'
        MOV   [DI], AH
        INC   DI
        MOV   BYTE PTR [DI], ':'
        INC   DI
        POP   DX
        MOV   AL, DH
        XOR   AH, AH
        MOV   BL, 10
        DIV   BL
        ADD   AL, '0'
        MOV   [DI], AL
        INC   DI
        ADD   AH, '0'
        MOV   [DI], AH
        INC   DI
        MOV   BYTE PTR [DI], 0
        MOV   AX, OFFSET _RX_BIF2BUF
        POP   DI
        POP   BP
        RET

_RXB_DATE:
        PUSH   BP
        MOV   BP, SP
        PUSH   DI
        LEA   DI, _RX_BIF2BUF
        MOV   AH, 2Ah
        INT     21h
        PUSH   CX
        MOV   AL, DL
        XOR   AH, AH
        MOV   BL, 10
        DIV   BL
        ADD   AL, '0'
        MOV   [DI], AL
        INC   DI
        ADD   AH, '0'
        MOV   [DI], AH
        INC   DI
        MOV   BYTE PTR [DI], '/'
        INC   DI
        MOV   AL, DH
        XOR   AH, AH
        MOV   BL, 10
        DIV   BL
        ADD   AL, '0'
        MOV   [DI], AL
        INC   DI
        ADD   AH, '0'
        MOV   [DI], AH
        INC   DI
        MOV   BYTE PTR [DI], '/'
        INC   DI
        POP   AX
        MOV   BX, 1000
        XOR   DX, DX
        DIV   BX
        ADD   AL, '0'
        MOV   [DI], AL
        INC   DI
        MOV   AX, DX
        XOR   DX, DX
        MOV   BX, 100
        DIV   BX
        ADD   AL, '0'
        MOV   [DI], AL
        INC   DI
        MOV   AX, DX
        XOR   DX, DX
        MOV   BX, 10
        DIV   BX
        ADD   AL, '0'
        MOV   [DI], AL
        INC   DI
        ADD   DL, '0'
        MOV   [DI], DL
        INC   DI
        MOV   BYTE PTR [DI], 0
        MOV   AX, OFFSET _RX_BIF2BUF
        POP   DI
        POP   BP
        RET

_RXB_DATATYPE:
        PUSH   BP
        MOV   BP, SP
        PUSH   DI
        PUSH   SI
        MOV   SI, [BP+6]
        LEA   DI, _RX_BIF2BUF
_RXB2_DT_LP:
        MOV   AL, [SI]
        CMP   AL, 0
        JE   _RXB2_DT_NUM
        CMP   AL, ' '
        JE   _RXB2_DT_NX
        CMP   AL, '+'
        JE   _RXB2_DT_NX
        CMP   AL, '-'
        JE   _RXB2_DT_NX
        CMP   AL, '.'
        JE   _RXB2_DT_NX
        CMP   AL, '0'
        JB   _RXB2_DT_CHR
        CMP   AL, '9'
        JA   _RXB2_DT_CHR
_RXB2_DT_NX:
        INC   SI
        JMP   _RXB2_DT_LP
_RXB2_DT_NUM:
        MOV   BYTE PTR [DI], 'N'
        MOV   BYTE PTR [DI+1], 'U'
        MOV   BYTE PTR [DI+2], 'M'
        MOV   BYTE PTR [DI+3], 0
        JMP   _RXB2_DT_DN
_RXB2_DT_CHR:
        MOV   BYTE PTR [DI], 'C'
        MOV   BYTE PTR [DI+1], 'H'
        MOV   BYTE PTR [DI+2], 'A'
        MOV   BYTE PTR [DI+3], 'R'
        MOV   BYTE PTR [DI+4], 0
_RXB2_DT_DN:
        MOV   AX, OFFSET _RX_BIF2BUF
        POP   SI
        POP   DI
        POP   BP
        RET

_RXB_SYMBOL:
        PUSH   BP
        MOV   BP, SP
        PUSH   DI
        LEA   DI, _RX_BIF2BUF
        MOV   BYTE PTR [DI], 'L'
        MOV   BYTE PTR [DI+1], 'I'
        MOV   BYTE PTR [DI+2], 'T'
        MOV   BYTE PTR [DI+3], 0
        MOV   AX, OFFSET _RX_BIF2BUF
        POP   DI
        POP   BP
        RET

_RXB_VALUE:
        PUSH   BP
        MOV   BP, SP
        MOV   AX, [BP+4]
        POP   BP
        RET

_RXB_ERRORTEXT:
        PUSH   BP
        MOV   BP, SP
        PUSH   DI
        LEA   DI, _RX_BIF2BUF
        MOV   BYTE PTR [DI], 0
        MOV   AX, OFFSET _RX_BIF2BUF
        POP   DI
        POP   BP
        RET

; --- Runtime PARSE (TODO 16) ---

_RXRT_PARSEINIT:
        PUSH   DI
        MOV   WORD PTR [_RX_PARSESRC], OFFSET _RX_TMPBUF
        MOV   WORD PTR [_RX_PARSEPOS], 0
        LEA   DI, _RX_TMPBUF
        CALL   _RXRT_STRCPY
        POP   DI
        RET

_RXRT_PARSEWORD:
        PUSH   SI
        PUSH   DI
        MOV   SI, WORD PTR [_RX_PARSESRC]
        ADD   SI, WORD PTR [_RX_PARSEPOS]
        LEA   DI, _RX_PARSEBUF
_RXRT_PW_SKIP:
        MOV   AL, BYTE PTR [SI]
        CMP   AL, 0
        JE   _RXRT_PW_END
        CMP   AL, ' '
        JNE   _RXRT_PW_COPY
        INC   SI
        JMP   _RXRT_PW_SKIP
_RXRT_PW_COPY:
        MOV   AL, BYTE PTR [SI]
        CMP   AL, 0
        JE   _RXRT_PW_END
        CMP   AL, ' '
        JE   _RXRT_PW_END
        MOV   BYTE PTR [DI], AL
        INC   SI
        INC   DI
        JMP   _RXRT_PW_COPY
_RXRT_PW_END:
        MOV   BYTE PTR [DI], 0
        MOV   AX, SI
        SUB   AX, WORD PTR [_RX_PARSESRC]
        MOV   WORD PTR [_RX_PARSEPOS], AX
        MOV   AX, OFFSET _RX_PARSEBUF
        POP   DI
        POP   SI
        RET

_RXRT_PARSEREST:
        PUSH   SI
        PUSH   DI
        MOV   SI, WORD PTR [_RX_PARSESRC]
        ADD   SI, WORD PTR [_RX_PARSEPOS]
        LEA   DI, _RX_PARSEBUF
_RXRT_PR_SKIP:
        MOV   AL, BYTE PTR [SI]
        CMP   AL, 0
        JE   _RXRT_PR_END
        CMP   AL, ' '
        JNE   _RXRT_PR_COPY
        INC   SI
        JMP   _RXRT_PR_SKIP
_RXRT_PR_COPY:
        MOV   AL, BYTE PTR [SI]
        CMP   AL, 0
        JE   _RXRT_PR_END
        MOV   BYTE PTR [DI], AL
        INC   SI
        INC   DI
        JMP   _RXRT_PR_COPY
_RXRT_PR_END:
        MOV   BYTE PTR [DI], 0
        MOV   AX, SI
        SUB   AX, WORD PTR [_RX_PARSESRC]
        MOV   WORD PTR [_RX_PARSEPOS], AX
        MOV   AX, OFFSET _RX_PARSEBUF
        POP   DI
        POP   SI
        RET

_RXRT_PARSEDELIM:
        PUSH   SI
        PUSH   BX
        PUSH   CX
        PUSH   DX
        MOV   SI, WORD PTR [_RX_PARSESRC]
        ADD   SI, WORD PTR [_RX_PARSEPOS]
        MOV   BX, SI
        PUSH   SI
        MOV   SI, DI
        CALL   _RXRT_STRLEN
        POP   SI
        MOV   DX, CX
_RXRT_PD_SCAN:
        MOV   AL, BYTE PTR [SI]
        CMP   AL, 0
        JE   _RXRT_PD_NFND
        PUSH   SI
        PUSH   DI
        MOV   CX, DX
_RXRT_PD_CMPL:
        CMP   CX, 0
        JE   _RXRT_PD_FOUN
        MOV   AL, BYTE PTR [SI]
        CMP   AL, BYTE PTR [DI]
        JNE   _RXRT_PD_NMAT
        INC   SI
        INC   DI
        DEC   CX
        JMP   _RXRT_PD_CMPL
_RXRT_PD_FOUN:
        POP   DI
        POP   SI
        PUSH   DI
        MOV   CX, SI
        SUB   CX, BX
        PUSH   SI
        MOV   SI, BX
        LEA   DI, _RX_PARSEBUF
_RXRT_PD_CPF:
        CMP   CX, 0
        JE   _RXRT_PD_CPD
        MOV   AL, BYTE PTR [SI]
        MOV   BYTE PTR [DI], AL
        INC   SI
        INC   DI
        DEC   CX
        JMP   _RXRT_PD_CPF
_RXRT_PD_CPD:
        MOV   BYTE PTR [DI], 0
        POP   SI
        POP   DI
        ADD   SI, DX
        MOV   AX, SI
        SUB   AX, WORD PTR [_RX_PARSESRC]
        MOV   WORD PTR [_RX_PARSEPOS], AX
        JMP   _RXRT_PD_DONE
_RXRT_PD_NMAT:
        POP   DI
        POP   SI
        INC   SI
        JMP   _RXRT_PD_SCAN
_RXRT_PD_NFND:
        PUSH   DI
        PUSH   SI
        MOV   SI, BX
        LEA   DI, _RX_PARSEBUF
        CALL   _RXRT_STRCPY
        POP   SI
        POP   DI
        MOV   AX, SI
        SUB   AX, WORD PTR [_RX_PARSESRC]
        MOV   WORD PTR [_RX_PARSEPOS], AX
_RXRT_PD_DONE:
        MOV   AX, OFFSET _RX_PARSEBUF
        POP   DX
        POP   CX
        POP   BX
        POP   SI
        RET

_RXRT_PARSEABS:
        PUSH   SI
        PUSH   DI
        PUSH   CX
        LEA   DI, _RX_PARSEBUF
        MOV   SI, WORD PTR [_RX_PARSESRC]
        ADD   SI, WORD PTR [_RX_PARSEPOS]
        DEC   BX
        MOV   CX, BX
        SUB   CX, WORD PTR [_RX_PARSEPOS]
        CMP   CX, 0
        JLE   _RXRT_PA_END
_RXRT_PA_COPY:
        MOV   AL, BYTE PTR [SI]
        CMP   AL, 0
        JE   _RXRT_PA_END
        MOV   BYTE PTR [DI], AL
        INC   SI
        INC   DI
        DEC   CX
        CMP   CX, 0
        JG   _RXRT_PA_COPY
        JMP   _RXRT_PA_END
_RXRT_PA_END:
        MOV   BYTE PTR [DI], 0
        MOV   WORD PTR [_RX_PARSEPOS], BX
        MOV   AX, OFFSET _RX_PARSEBUF
        POP   CX
        POP   DI
        POP   SI
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
_RX_PARSEBUF DB 256 DUP(0)
_RX_PARSEPOS DW 0
_RX_PARSESRC DW 0
_RX_RESBUF DB 256 DUP(0)
_RX_BIF2BUF DB 256 DUP(0)
_RXV_I DB 256 DUP(0)
_RXV_I_D DB 'I',0
_RXV_J DB 256 DUP(0)
_RXV_J_D DB 'J',0
_RXV_K DB 256 DUP(0)
_RXV_K_D DB 'K',0
_RXL_9_FIN DB 256 DUP(0)
_RXV_M DB 256 DUP(0)
_RXV_M_D DB 'M',0
_RXL_13_FIN DB 256 DUP(0)
_RXL_14_STEP DB 256 DUP(0)
_RXL_18_CNT DW 0
_RXK_1 DB 'boucle',0
_RXK_2 DB 'bloc',0
_RXK_3 DB 'simple',0
_RXV_N DB 256 DUP(0)
_RXV_N_D DB 'N',0
_RXV_P DB 256 DUP(0)
_RXV_P_D DB 'P',0
_DATA ENDS

END _RXP_Main
