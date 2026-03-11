; SAS86 v1.0 - SAMPLES/SAS/procprint.sas
.MODEL SMALL
.STACK 1024

_TEXT SEGMENT PUBLIC 'CODE'
        ASSUME CS:_TEXT, DS:_DATA, SS:STACK

_SASP_Main:
        PUSH BP
        MOV BP, SP
        MOV AX, _DATA
        MOV DS, AX


; ========= DATA STEP =========
; dataset: VENTES
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_1:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV AX, OFFSET _SASK_4
; stocker PRODUIT
        MOV [_SAS_PDV], AX
        MOV AX, 25
; stocker PRIX
        MOV [_SAS_PDV + 2], AX
        MOV AX, 10
; stocker QUANTITE
        MOV [_SAS_PDV + 4], AX
; charger PRIX
        MOV AX, [_SAS_PDV + 2]
        PUSH AX
; charger QUANTITE
        MOV AX, [_SAS_PDV + 4]
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_5
        CMP BX, 8000h
        JE _SASL_5
        IMUL BX
        JMP _SASL_6
_SASL_5:
        MOV AX, 8000h
_SASL_6:
; stocker TOTAL
        MOV [_SAS_PDV + 6], AX
_SASL_3:
; OUTPUT : copier PDV -> dataset VENTES
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_2:
; ========= FIN DATA STEP VENTES =========


; ========= PROC PRINT =========
; PROC option DATA=VENTES
; PROC PRINT : execution
; PROC PRINT : affichage tabulaire
; PRINT toutes les variables du PDV
; PRINT PRODUIT (num)
        MOV AX, WORD PTR [_SAS_PDV + 0]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; PRINT PRIX (num)
        MOV AX, WORD PTR [_SAS_PDV + 2]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; PRINT QUANTITE (num)
        MOV AX, WORD PTR [_SAS_PDV + 4]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; PRINT TOTAL (num)
        MOV AX, WORD PTR [_SAS_PDV + 6]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
; ========= FIN PROC PRINT =========


; ========= PROC PRINT =========
; PROC option DATA=VENTES
; VAR
; PROC PRINT : execution
; PROC PRINT : affichage tabulaire
; En-tete : PRODUIT TOTAL
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 13
        LEA DX, _SASK_7
        INT 21h
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
; PRINT PRODUIT (num)
        MOV AX, WORD PTR [_SAS_PDV + 0]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; PRINT TOTAL (num)
        MOV AX, WORD PTR [_SAS_PDV + 6]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
; ========= FIN PROC PRINT =========


; ========= PROC PRINT =========
; PROC option DATA=VENTES
; VAR
; TITLE: Rapport de ventes
; FOOTNOTE: Source: procprint.sas
; PROC PRINT : execution
; PROC PRINT : affichage tabulaire
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 17
        LEA DX, _SASK_8
        INT 21h
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
; En-tete : PRODUIT PRIX QUANTITE TOTAL
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 27
        LEA DX, _SASK_9
        INT 21h
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
; PRINT PRODUIT (num)
        MOV AX, WORD PTR [_SAS_PDV + 0]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; PRINT PRIX (num)
        MOV AX, WORD PTR [_SAS_PDV + 2]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; PRINT QUANTITE (num)
        MOV AX, WORD PTR [_SAS_PDV + 4]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; PRINT TOTAL (num)
        MOV AX, WORD PTR [_SAS_PDV + 6]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 21
        LEA DX, _SASK_10
        INT 21h
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
; ========= FIN PROC PRINT =========


; ========= PROC PRINT =========
; PROC option DATA=VENTES
; PROC option NOPRINT
; VAR
; PROC PRINT : execution
; PROC PRINT : NOPRINT -> pas d affichage
; ========= FIN PROC PRINT =========


; ========= PROC SORT =========
; PROC option DATA=VENTES
; PROC option OUT=VENTES_TRI
; BY
; PROC SORT : execution
; PROC SORT : tri du dataset
; DATA=VENTES
; OUT=VENTES_TRI
; BY PRIX (ASCENDING)
; Tri a bulles (squelette multi-observations)
        MOV CX, WORD PTR [_SAS_N]
        CMP CX, 2
        JL _SASL_14
        DEC CX
_SASL_11:
        PUSH CX
        XOR SI, SI
_SASL_12:
; Comparer PRIX
        MOV AX, WORD PTR [_SAS_PDV + 2]
        MOV BX, WORD PTR [_SAS_PDV + 2]
        CMP AX, BX
        JLE _SASL_13
; Echange observations (REP MOVSW)
        MOV CX, 256
        NOP
_SASL_13:
        LOOP _SASL_12
        POP CX
        LOOP _SASL_11
_SASL_14:
; PROC SORT : fin du tri
; ========= FIN PROC SORT =========


; --- Fin du code ---
        MOV SP, BP
        POP BP
        MOV AX, 4C00h
        INT 21h


; --- Runtime minimal SAS86 ---

; === Runtime fonctions integrees SAS86 (TODO 22) ===

_SASRT_MIN:
        CMP AX, BX
        JLE _SASRT_MIN_D
        MOV AX, BX
_SASRT_MIN_D:
        RET

_SASRT_MAX:
        CMP AX, BX
        JGE _SASRT_MAX_D
        MOV AX, BX
_SASRT_MAX_D:
        RET

_SASRT_ROUND:
        TEST BX, BX
        JZ _SASRT_ROUND_D
        CWD
        IDIV BX
        IMUL BX
_SASRT_ROUND_D:
        RET

_SASRT_SQRT:
        CMP AX, 1
        JLE _SASRT_SQRT_D
        PUSH SI
        MOV SI, AX
        SHR AX, 1
_SASRT_SQRT_L:
        MOV CX, AX
        PUSH AX
        MOV AX, SI
        XOR DX, DX
        DIV CX
        POP BX
        ADD AX, BX
        SHR AX, 1
        CMP AX, CX
        JB _SASRT_SQRT_L
        MOV AX, CX
        POP SI
_SASRT_SQRT_D:
        RET

_SASRT_LOG:
        CMP AX, 1
        JLE _SASRT_LOG_Z
        PUSH CX
        XOR CX, CX
_SASRT_LOG_L:
        SHR AX, 1
        JZ _SASRT_LOG_E
        INC CX
        JMP _SASRT_LOG_L
_SASRT_LOG_E:
        MOV AX, CX
        POP CX
        RET
_SASRT_LOG_Z:
        XOR AX, AX
        RET

_SASRT_EXP:
        RET

_SASRT_STRLEN:
        MOV SI, AX
        XOR CX, CX
_SASRT_SL_LP:
        LODSB
        TEST AL, AL
        JZ _SASRT_SL_DN
        INC CX
        JMP _SASRT_SL_LP
_SASRT_SL_DN:
        MOV AX, CX
        RET

_SASRT_INDEX:
        PUSH SI
        PUSH DI
        XOR BX, BX
_SASRT_IX_NX:
        MOV AL, [SI]
        TEST AL, AL
        JZ _SASRT_IX_NF
        INC BX
        PUSH SI
        PUSH DI
_SASRT_IX_CM:
        MOV AL, [DI]
        TEST AL, AL
        JZ _SASRT_IX_FD
        CMP AL, [SI]
        JNE _SASRT_IX_NM
        INC SI
        INC DI
        JMP _SASRT_IX_CM
_SASRT_IX_NM:
        POP DI
        POP SI
        INC SI
        JMP _SASRT_IX_NX
_SASRT_IX_FD:
        POP DI
        POP SI
        MOV AX, BX
        POP DI
        POP SI
        RET
_SASRT_IX_NF:
        XOR AX, AX
        POP DI
        POP SI
        RET

_SASRT_SUBSTR:
        PUSH DI
        LEA DI, _SAS_STRBUF
        DEC BX
        ADD SI, BX
_SASRT_SS_LP:
        CMP CX, 0
        JE _SASRT_SS_DN
        LODSB
        TEST AL, AL
        JZ _SASRT_SS_DN
        STOSB
        CMP CX, -1
        JE _SASRT_SS_LP
        DEC CX
        JMP _SASRT_SS_LP
_SASRT_SS_DN:
        MOV BYTE PTR [DI], 0
        LEA AX, _SAS_STRBUF
        POP DI
        RET

_SASRT_TRIM:
        PUSH SI
        PUSH DI
        MOV SI, AX
        LEA DI, _SAS_STRBUF
        XOR CX, CX
_SASRT_TR_CP:
        LODSB
        STOSB
        TEST AL, AL
        JZ _SASRT_TR_TM
        INC CX
        JMP _SASRT_TR_CP
_SASRT_TR_TM:
        LEA DI, _SAS_STRBUF
        ADD DI, CX
        DEC DI
_SASRT_TR_BK:
        LEA AX, _SAS_STRBUF
        CMP DI, AX
        JB _SASRT_TR_DN
        CMP BYTE PTR [DI], 20h
        JNE _SASRT_TR_DN
        MOV BYTE PTR [DI], 0
        DEC DI
        JMP _SASRT_TR_BK
_SASRT_TR_DN:
        LEA AX, _SAS_STRBUF
        POP DI
        POP SI
        RET

_SASRT_LEFT:
        MOV SI, AX
_SASRT_LF_SK:
        CMP BYTE PTR [SI], 20h
        JNE _SASRT_LF_CP
        INC SI
        JMP _SASRT_LF_SK
_SASRT_LF_CP:
        PUSH DI
        LEA DI, _SAS_STRBUF
_SASRT_LF_LP:
        LODSB
        STOSB
        TEST AL, AL
        JNZ _SASRT_LF_LP
        LEA AX, _SAS_STRBUF
        POP DI
        RET

_SASRT_RIGHT:
        PUSH SI
        PUSH DI
        MOV SI, AX
        LEA DI, _SAS_STRBUF
_SASRT_RI_LP:
        LODSB
        STOSB
        TEST AL, AL
        JNZ _SASRT_RI_LP
        LEA AX, _SAS_STRBUF
        POP DI
        POP SI
        RET

_SASRT_UPCASE:
        PUSH SI
        PUSH DI
        MOV SI, AX
        LEA DI, _SAS_STRBUF
_SASRT_UC_LP:
        LODSB
        CMP AL, 61h
        JB _SASRT_UC_OK
        CMP AL, 7Ah
        JA _SASRT_UC_OK
        SUB AL, 20h
_SASRT_UC_OK:
        STOSB
        TEST AL, AL
        JNZ _SASRT_UC_LP
        LEA AX, _SAS_STRBUF
        POP DI
        POP SI
        RET

_SASRT_LOWCASE:
        PUSH SI
        PUSH DI
        MOV SI, AX
        LEA DI, _SAS_STRBUF
_SASRT_LC_LP:
        LODSB
        CMP AL, 41h
        JB _SASRT_LC_OK
        CMP AL, 5Ah
        JA _SASRT_LC_OK
        ADD AL, 20h
_SASRT_LC_OK:
        STOSB
        TEST AL, AL
        JNZ _SASRT_LC_LP
        LEA AX, _SAS_STRBUF
        POP DI
        POP SI
        RET

_SASRT_COMPRESS:
        PUSH SI
        PUSH DI
        MOV SI, AX
        PUSH DI
        LEA DI, _SAS_STRBUF
_SASRT_CO_LP:
        LODSB
        TEST AL, AL
        JZ _SASRT_CO_DN
        MOV BX, [SP]
        TEST BX, BX
        JNZ _SASRT_CO_CK
        CMP AL, 20h
        JE _SASRT_CO_LP
        JMP _SASRT_CO_ST
_SASRT_CO_CK:
        PUSH SI
        MOV SI, BX
_SASRT_CO_SC:
        MOV AH, [SI]
        TEST AH, AH
        JZ _SASRT_CO_KP
        CMP AL, AH
        JE _SASRT_CO_RM
        INC SI
        JMP _SASRT_CO_SC
_SASRT_CO_KP:
        POP SI
_SASRT_CO_ST:
        STOSB
        JMP _SASRT_CO_LP
_SASRT_CO_RM:
        POP SI
        JMP _SASRT_CO_LP
_SASRT_CO_DN:
        STOSB
        POP BX
        LEA AX, _SAS_STRBUF
        POP DI
        POP SI
        RET

_SASRT_STRCAT:
        PUSH SI
        PUSH DI
        PUSH DI
        LEA DI, _SAS_STRBUF2
_SASRT_SC_C1:
        LODSB
        TEST AL, AL
        JZ _SASRT_SC_S2
        STOSB
        JMP _SASRT_SC_C1
_SASRT_SC_S2:
        POP SI
_SASRT_SC_C2:
        LODSB
        STOSB
        TEST AL, AL
        JNZ _SASRT_SC_C2
        LEA AX, _SAS_STRBUF2
        POP DI
        POP SI
        RET

_SASRT_NUM2STR:
        PUSH SI
        PUSH DI
        PUSH BX
        LEA DI, _SAS_NUMBUF
        TEST AX, AX
        JNS _SASRT_N2_POS
        MOV BYTE PTR [DI], 2Dh
        INC DI
        NEG AX
_SASRT_N2_POS:
        XOR CX, CX
        MOV BX, 10
_SASRT_N2_DIV:
        XOR DX, DX
        DIV BX
        ADD DL, 30h
        PUSH DX
        INC CX
        TEST AX, AX
        JNZ _SASRT_N2_DIV
_SASRT_N2_POP:
        POP AX
        STOSB
        LOOP _SASRT_N2_POP
        MOV BYTE PTR [DI], 0
        LEA AX, _SAS_NUMBUF
        POP BX
        POP DI
        POP SI
        RET

_SASRT_STR2NUM:
        MOV SI, AX
        XOR AX, AX
        XOR CX, CX
        CMP BYTE PTR [SI], 2Dh
        JNE _SASRT_A2_LP
        INC CX
        INC SI
_SASRT_A2_LP:
        MOV BL, [SI]
        SUB BL, 30h
        JB _SASRT_A2_DN
        CMP BL, 9
        JA _SASRT_A2_DN
        MOV DX, 10
        IMUL DX
        XOR BH, BH
        ADD AX, BX
        INC SI
        JMP _SASRT_A2_LP
_SASRT_A2_DN:
        TEST CX, CX
        JZ _SASRT_A2_RT
        NEG AX
_SASRT_A2_RT:
        RET

_SASRT_MDY:
        PUSH SI
        PUSH DI
        PUSH BX
        PUSH AX
        MOV AX, CX
        SUB AX, 1960
        MOV BX, 365
        IMUL BX
        MOV DI, AX
        MOV AX, CX
        SUB AX, 1960
        MOV BX, 4
        CWD
        IDIV BX
        ADD DI, AX
        POP AX
        DEC AX
        MOV BX, AX
        SHL BX, 1
        ADD BX, OFFSET _SASRT_MDAYS
        MOV AX, [BX]
        ADD DI, AX
        POP AX
        DEC AX
        ADD AX, DI
        POP DI
        POP SI
        RET

_SASRT_MDAYS:
        DW  0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334

_SASRT_YEAR:
        PUSH BX
        MOV BX, 365
        CWD
        IDIV BX
        ADD AX, 1960
        POP BX
        RET

_SASRT_MONTH:
        PUSH BX
        PUSH SI
        MOV BX, 365
        CWD
        IDIV BX
        MOV AX, DX
        LEA SI, _SASRT_MDAYS
        MOV CX, 12
        XOR BX, BX
_SASRT_MO_LP:
        MOV DX, [SI+BX]
        CMP AX, DX
        JL _SASRT_MO_FD
        ADD BX, 2
        LOOP _SASRT_MO_LP
_SASRT_MO_FD:
        SHR BX, 1
        MOV AX, BX
        POP SI
        POP BX
        RET

_SASRT_DAY:
        PUSH BX
        PUSH SI
        MOV BX, 365
        CWD
        IDIV BX
        MOV AX, DX
        LEA SI, _SASRT_MDAYS
        XOR BX, BX
        MOV CX, 11
_SASRT_DY_LP:
        MOV DX, [SI+BX+2]
        CMP AX, DX
        JL _SASRT_DY_FD
        ADD BX, 2
        LOOP _SASRT_DY_LP
_SASRT_DY_FD:
        SUB AX, [SI+BX]
        INC AX
        POP SI
        POP BX
        RET


; === Runtime minimal SAS86 (TODO 24) ===

_SASRT_PRINT:
        MOV AH, 40h
        INT 21h
        RET

_SASRT_PRINTLN:
        MOV BX, [_SAS_OUTHDL]
        MOV AH, 40h
        INT 21h
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
        RET

_SASRT_PUTSTR:
        MOV BX, [_SAS_OUTHDL]
        MOV AH, 40h
        INT 21h
        RET

_SASRT_PUTNUM:
        PUSH SI
        PUSH DI
        CALL _SASRT_NUM2STR
        MOV SI, AX
        XOR CX, CX
_SASRT_PN_L:
        CMP BYTE PTR [SI], 0
        JE _SASRT_PN_D
        INC CX
        INC SI
        JMP _SASRT_PN_L
_SASRT_PN_D:
        MOV DX, AX
        MOV BX, [_SAS_OUTHDL]
        MOV AH, 40h
        INT 21h
        POP DI
        POP SI
        RET

_SASRT_STRCMP:
        PUSH SI
        PUSH DI
_SASRT_SC_LP:
        MOV AL, [SI]
        MOV AH, [DI]
        CMP AL, AH
        JNE _SASRT_SC_NE
        TEST AL, AL
        JZ _SASRT_SC_EQ
        INC SI
        INC DI
        JMP _SASRT_SC_LP
_SASRT_SC_EQ:
        CMP AL, AL
        POP DI
        POP SI
        RET
_SASRT_SC_NE:
        POP DI
        POP SI
        RET

_SASRT_CONCAT:
        PUSH SI
        PUSH DI
        PUSH DI
        LEA DI, _SAS_STRBUF2
_SASRT_CT_C1:
        LODSB
        TEST AL, AL
        JZ _SASRT_CT_S2
        STOSB
        JMP _SASRT_CT_C1
_SASRT_CT_S2:
        POP SI
_SASRT_CT_C2:
        LODSB
        STOSB
        TEST AL, AL
        JNZ _SASRT_CT_C2
        LEA AX, _SAS_STRBUF2
        POP DI
        POP SI
        RET

_SASRT_STRCPY:
        PUSH SI
        PUSH DI
        PUSH CX
        MOV SI, AX
_SASRT_SY_LP:
        TEST CX, CX
        JZ _SASRT_SY_DN
        MOV AL, [SI]
        TEST AL, AL
        JZ _SASRT_SY_PD
        STOSB
        INC SI
        DEC CX
        JMP _SASRT_SY_LP
_SASRT_SY_PD:
        MOV AL, 20h
        REP STOSB
_SASRT_SY_DN:
        POP CX
        POP DI
        POP SI
        RET

_SASRT_POW:
        TEST BX, BX
        JNZ _SASRT_PW_NZ
        MOV AX, 1
        RET
_SASRT_PW_NZ:
        PUSH CX
        MOV CX, BX
        MOV BX, AX
_SASRT_PW_LP:
        CMP CX, 1
        JLE _SASRT_PW_DN
        IMUL BX
        DEC CX
        JMP _SASRT_PW_LP
_SASRT_PW_DN:
        POP CX
        RET

_SASRT_ABS:
        TEST AX, AX
        JNS _SASRT_AB_DN
        NEG AX
_SASRT_AB_DN:
        RET

_SASRT_MISSING:
        CMP AX, 8000h
        RET

_SASRT_PANIC:
        MOV DX, SI
        XOR CX, CX
_SASRT_PK_L:
        CMP BYTE PTR [SI], 0
        JE _SASRT_PK_P
        INC CX
        INC SI
        JMP _SASRT_PK_L
_SASRT_PK_P:
        MOV BX, 2
        MOV AH, 40h
        INT 21h
        MOV AH, 40h
        MOV BX, 2
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
        MOV AX, 4C01h
        INT 21h

_SASRT_READLINE:
        PUSH SI
        PUSH DI
        PUSH BX
        MOV SI, DI
        XOR DX, DX
_SASRT_RL_LP:
        TEST CX, CX
        JZ _SASRT_RL_DN
        PUSH CX
        PUSH DX
        MOV AH, 3Fh
        MOV BX, [_SAS_INHDL]
        MOV CX, 1
        MOV DX, DI
        INT 21h
        POP DX
        POP CX
        TEST AX, AX
        JZ _SASRT_RL_DN
        CMP BYTE PTR [DI], 0Ah
        JE _SASRT_RL_NL
        CMP BYTE PTR [DI], 0Dh
        JE _SASRT_RL_LP
        INC DI
        INC DX
        DEC CX
        JMP _SASRT_RL_LP
_SASRT_RL_NL:
_SASRT_RL_DN:
        MOV BYTE PTR [DI], 0
        MOV AX, DX
        POP BX
        POP DI
        POP SI
        RET

_SASRT_CPYFLD:
        PUSH SI
        PUSH DI
        PUSH CX
_SASRT_CF_LP:
        TEST CX, CX
        JZ _SASRT_CF_DN
        MOV AL, [SI]
        TEST AL, AL
        JZ _SASRT_CF_PD
        STOSB
        INC SI
        DEC CX
        JMP _SASRT_CF_LP
_SASRT_CF_PD:
        MOV AL, 20h
        REP STOSB
_SASRT_CF_DN:
        POP CX
        POP DI
        POP SI
        RET

_SASRT_GETFLD:
        PUSH BX
        XOR BX, BX
_SASRT_GF_SK:
        CMP BYTE PTR [SI], 20h
        JNE _SASRT_GF_CP
        CMP BYTE PTR [SI], 0
        JE _SASRT_GF_PD
        INC SI
        JMP _SASRT_GF_SK
_SASRT_GF_CP:
        CMP BX, CX
        JGE _SASRT_GF_PD
        MOV AL, [SI]
        TEST AL, AL
        JZ _SASRT_GF_PD
        CMP AL, 20h
        JE _SASRT_GF_PD
        CMP AL, 09h
        JE _SASRT_GF_PD
        STOSB
        INC SI
        INC BX
        JMP _SASRT_GF_CP
_SASRT_GF_PD:
        MOV AX, CX
        SUB AX, BX
        MOV CX, AX
        MOV AL, 20h
        REP STOSB
        POP BX
        RET

_SASRT_GETNUM:
        PUSH BX
_SASRT_GN_SK:
        CMP BYTE PTR [SI], 20h
        JNE _SASRT_GN_RD
        INC SI
        JMP _SASRT_GN_SK
_SASRT_GN_RD:
        XOR AX, AX
        XOR CX, CX
        CMP BYTE PTR [SI], 2Dh
        JNE _SASRT_GN_DG
        INC CX
        INC SI
_SASRT_GN_DG:
        MOV BL, [SI]
        SUB BL, 30h
        JB _SASRT_GN_DN
        CMP BL, 9
        JA _SASRT_GN_DN
        MOV DX, 10
        IMUL DX
        XOR BH, BH
        ADD AX, BX
        INC SI
        JMP _SASRT_GN_DG
_SASRT_GN_DN:
        TEST CX, CX
        JZ _SASRT_GN_RT
        NEG AX
_SASRT_GN_RT:
        POP BX
        RET

_SASRT_ATOI:
        PUSH BX
        PUSH DX
        XOR AX, AX
        XOR DX, DX
_SASRT_AT_SK:
        TEST CX, CX
        JZ _SASRT_AT_DN
        CMP BYTE PTR [SI], 20h
        JNE _SASRT_AT_SN
        INC SI
        DEC CX
        JMP _SASRT_AT_SK
_SASRT_AT_SN:
        CMP BYTE PTR [SI], 2Dh
        JNE _SASRT_AT_DG
        INC DX
        INC SI
        DEC CX
_SASRT_AT_DG:
        TEST CX, CX
        JZ _SASRT_AT_ND
        MOV BL, [SI]
        SUB BL, 30h
        JB _SASRT_AT_ND
        CMP BL, 9
        JA _SASRT_AT_ND
        PUSH DX
        MOV DX, 10
        IMUL DX
        POP DX
        XOR BH, BH
        ADD AX, BX
        INC SI
        DEC CX
        JMP _SASRT_AT_DG
_SASRT_AT_ND:
        TEST DX, DX
        JZ _SASRT_AT_DN
        NEG AX
_SASRT_AT_DN:
        POP DX
        POP BX
        RET

_SASRT_INLIST:
        XOR AX, AX
        RET


_TEXT ENDS

_DATA SEGMENT PUBLIC 'DATA'

; --- Donnees predefinies SAS86 ---
_SAS_MISSING  DW  -32768
_SAS_N  DW  0
_SAS_ERROR  DW  0
_SAS_PDV  DB  512 DUP(0)
_SAS_CRLF  DB  13,10,0
_SAS_INBUF  DB  256 DUP(0)
_SAS_INLEN  DW  0
_SAS_INPOS  DW  0
_SAS_NUMBUF  DB  12 DUP(0)
_SAS_INHDL  DW  0
_SAS_OUTHDL  DW  1
_SAS_DOEND  DW  0
_SAS_DOSTEP  DW  1
_SAS_STRBUF  DB  256 DUP(0)
_SAS_STRBUF2  DB  256 DUP(0)
_SAS_HEAP  DB  4096 DUP(0)
_SAS_HEAPTOP  DW  0
_SAS_FIRST  DW  0
_SAS_LAST  DW  0
_SAS_BYKEY  DW  0
_SAS_BYKEY_PREV  DW  0
_SAS_MRGIDX  DW  0
_SAS_SETIDX  DW  0
_SAS_SETEND  DW  0
_SAS_SETNOBS  DW  0
_SAS_SETPT  DW  0
_SASK_4  DB  'Widget',0
_SASK_7  DB  'PRODUIT TOTAL',0
_SASK_8  DB  'Rapport de ventes',0
_SASK_9  DB  'PRODUIT PRIX QUANTITE TOTAL',0
_SASK_10  DB  'Source: procprint.sas',0

_DATA ENDS

END _SASP_Main
