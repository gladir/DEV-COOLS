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
