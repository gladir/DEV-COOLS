; SAS86 v1.0 - SAMPLES/SAS/test_merge.sas
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
; dataset: WORK1
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
; SET (enhanced TODO 23)
; SET source=SALES
; charger PRICE
        MOV AX, [_SAS_PDV + 2]
        PUSH AX
; charger QTY
        MOV AX, [_SAS_PDV + 4]
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_4
        CMP BX, 8000h
        JE _SASL_4
        IMUL BX
        JMP _SASL_5
_SASL_4:
        MOV AX, 8000h
_SASL_5:
; stocker TOTAL
        MOV [_SAS_PDV], AX
_SASL_3:
; OUTPUT : copier PDV -> dataset WORK1
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
; Boucle implicite : iteration suivante
        JMP _SASL_1
_SASL_2:
; ========= FIN DATA STEP WORK1 =========


; ========= DATA STEP =========
; dataset: COMBINED
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_6:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
; SET (enhanced TODO 23)
; SET source=DS_JAN
; SET source=DS_FEB
; SET concatenation: 2 datasets
        MOV WORD PTR [_SAS_SETIDX], 0
_SASL_8:
; OUTPUT : copier PDV -> dataset COMBINED
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
; Boucle implicite : iteration suivante
        JMP _SASL_6
_SASL_7:
; ========= FIN DATA STEP COMBINED =========


; ========= DATA STEP =========
; dataset: INFO
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_9:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
; SET (enhanced TODO 23)
; SET source=CUSTOMERS
; SET NOBS=TOTAL_OBS
        MOV AX, WORD PTR [_SAS_SETNOBS]
; stocker TOTAL_OBS
        MOV [_SAS_PDV + 6], AX
; IF
; charger _N_
        MOV AX, [_SAS_N]
        PUSH AX
        MOV AX, 1
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_12
        CMP BX, 8000h
        JE _SASL_12
        CMP AX, BX
        JE _SASL_14
        XOR AX, AX
        JMP _SASL_15
_SASL_14:
        MOV AX, 1
_SASL_15:
        JMP _SASL_13
_SASL_12:
        MOV AX, 8000h
_SASL_13:
        TEST AX, AX
        JZ _SASL_16
; PUT
; PUT TOTAL_OBS
; charger TOTAL_OBS
        MOV AX, [_SAS_PDV + 6]
        CALL _SASRT_PUTNUM
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_16:
_SASL_11:
; OUTPUT : copier PDV -> dataset INFO
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
; Boucle implicite : iteration suivante
        JMP _SASL_9
_SASL_10:
; ========= FIN DATA STEP INFO =========


; ========= DATA STEP =========
; dataset: LAST_CHECK
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_18:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
        MOV WORD PTR [_SAS_PDV + 6], -32768
; SET (enhanced TODO 23)
; SET source=ORDERS
; SET END=EOF
        MOV AX, WORD PTR [_SAS_SETEND]
; stocker EOF
        MOV [_SAS_PDV + 8], AX
; IF
; charger EOF
        MOV AX, [_SAS_PDV + 8]
        TEST AX, AX
        JZ _SASL_21
; PUT
; PUT literal: 'Fin du dataset'
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 14
        LEA DX, _SASK_23
        INT 21h
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_21:
_SASL_20:
; OUTPUT : copier PDV -> dataset LAST_CHECK
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
; Boucle implicite : iteration suivante
        JMP _SASL_18
_SASL_19:
; ========= FIN DATA STEP LAST_CHECK =========


; ========= DATA STEP =========
; dataset: DIRECT
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_24:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
        MOV WORD PTR [_SAS_PDV + 6], -32768
        MOV WORD PTR [_SAS_PDV + 8], -32768
        MOV AX, 5
; stocker N
        MOV [_SAS_PDV + 10], AX
; SET (enhanced TODO 23)
; SET source=RECORDS
; SET POINT=N
        MOV AX, WORD PTR [_SAS_SETPT]
; stocker N
        MOV [_SAS_PDV + 10], AX
_SASL_26:
; OUTPUT : copier PDV -> dataset DIRECT
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
; Boucle implicite : iteration suivante
        JMP _SASL_24
_SASL_25:
; ========= FIN DATA STEP DIRECT =========


; ========= DATA STEP =========
; dataset: MERGED
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_27:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
        MOV WORD PTR [_SAS_PDV + 6], -32768
        MOV WORD PTR [_SAS_PDV + 8], -32768
        MOV WORD PTR [_SAS_PDV + 10], -32768
; MERGE (TODO 23)
; MERGE source=CUSTOMERS
; MERGE source=ORDERS
        MOV WORD PTR [_SAS_MRGIDX], 0
; MERGE un-a-un (pas de BY) : correspondance par position
; BY (DATA step, TODO 23)
; BY var=CUST_ID
        MOV AX, 0
; stocker FIRST.CUST_ID
        MOV [_SAS_PDV + 12], AX
        MOV AX, 0
; stocker LAST.CUST_ID
        MOV [_SAS_PDV + 14], AX

; --- Gestion FIRST./LAST. pour BY ---
        MOV AX, WORD PTR [_SAS_BYKEY]
        MOV WORD PTR [_SAS_BYKEY_PREV], AX
        MOV BX, WORD PTR [_SAS_BYKEY_PREV]
        CMP AX, BX
        MOV AX, 0
        JE _SASL_30
        MOV AX, 1
_SASL_30:
; stocker FIRST.CUST_ID
        MOV [_SAS_PDV + 12], AX
; LAST.var positionne par look-ahead (stub commentaire)
        MOV AX, 1
; stocker LAST.CUST_ID
        MOV [_SAS_PDV + 14], AX
; LAST.CUST_ID = 1 (sera corrige en runtime)
_SASL_29:
; OUTPUT : copier PDV -> dataset MERGED
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_28:
; ========= FIN DATA STEP MERGED =========


; ========= DATA STEP =========
; dataset: MERGED_POS
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_31:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
        MOV WORD PTR [_SAS_PDV + 6], -32768
        MOV WORD PTR [_SAS_PDV + 8], -32768
        MOV WORD PTR [_SAS_PDV + 10], -32768
        MOV WORD PTR [_SAS_PDV + 12], -32768
        MOV WORD PTR [_SAS_PDV + 14], -32768
; MERGE (TODO 23)
; MERGE source=DS_A
; MERGE source=DS_B
        MOV WORD PTR [_SAS_MRGIDX], 0
; MERGE un-a-un (pas de BY) : correspondance par position
_SASL_33:
; OUTPUT : copier PDV -> dataset MERGED_POS
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_32:
; ========= FIN DATA STEP MERGED_POS =========


; ========= DATA STEP =========
; dataset: GROUPED
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_34:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
        MOV WORD PTR [_SAS_PDV + 6], -32768
        MOV WORD PTR [_SAS_PDV + 8], -32768
        MOV WORD PTR [_SAS_PDV + 10], -32768
        MOV WORD PTR [_SAS_PDV + 12], -32768
        MOV WORD PTR [_SAS_PDV + 14], -32768
; SET (enhanced TODO 23)
; SET source=SORTED_DATA
; BY (DATA step, TODO 23)
; BY var=REGION
        MOV AX, 0
; stocker FIRST.REGION
        MOV [_SAS_PDV + 16], AX
        MOV AX, 0
; stocker LAST.REGION
        MOV [_SAS_PDV + 18], AX

; --- Gestion FIRST./LAST. pour BY ---
        MOV AX, WORD PTR [_SAS_BYKEY]
        MOV WORD PTR [_SAS_BYKEY_PREV], AX
        MOV BX, WORD PTR [_SAS_BYKEY_PREV]
        CMP AX, BX
        MOV AX, 0
        JE _SASL_37
        MOV AX, 1
_SASL_37:
; stocker FIRST.REGION
        MOV [_SAS_PDV + 16], AX
; LAST.var positionne par look-ahead (stub commentaire)
        MOV AX, 1
; stocker LAST.REGION
        MOV [_SAS_PDV + 18], AX
; LAST.REGION = 1 (sera corrige en runtime)
; IF
; charger FIRST.REGION
        MOV AX, [_SAS_PDV + 16]
        TEST AX, AX
        JZ _SASL_38
        XOR AX, AX
; stocker TOTAL
        MOV [_SAS_PDV], AX
_SASL_38:
; IF
; charger LAST.REGION
        MOV AX, [_SAS_PDV + 18]
        TEST AX, AX
        JZ _SASL_40
; OUTPUT explicite
; OUTPUT : copier PDV -> dataset GROUPED
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
_SASL_40:
        INC WORD PTR [_SAS_N]
; Boucle implicite : iteration suivante
        JMP _SASL_34
_SASL_35:
; ========= FIN DATA STEP GROUPED =========


; ========= DATA STEP =========
; dataset: MULTI_BY
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_42:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
        MOV WORD PTR [_SAS_PDV + 6], -32768
        MOV WORD PTR [_SAS_PDV + 8], -32768
        MOV WORD PTR [_SAS_PDV + 10], -32768
        MOV WORD PTR [_SAS_PDV + 12], -32768
        MOV WORD PTR [_SAS_PDV + 14], -32768
        MOV WORD PTR [_SAS_PDV + 16], -32768
        MOV WORD PTR [_SAS_PDV + 18], -32768
; SET (enhanced TODO 23)
; SET source=SALES_DATA
; BY (DATA step, TODO 23)
; BY var=REGION
        MOV AX, 0
; stocker FIRST.REGION
        MOV [_SAS_PDV + 16], AX
        MOV AX, 0
; stocker LAST.REGION
        MOV [_SAS_PDV + 18], AX
; BY var=PRODUCT
        MOV AX, 0
; stocker FIRST.PRODUCT
        MOV [_SAS_PDV + 20], AX
        MOV AX, 0
; stocker LAST.PRODUCT
        MOV [_SAS_PDV + 22], AX

; --- Gestion FIRST./LAST. pour BY ---
        MOV AX, WORD PTR [_SAS_BYKEY]
        MOV WORD PTR [_SAS_BYKEY_PREV], AX
        MOV BX, WORD PTR [_SAS_BYKEY_PREV]
        CMP AX, BX
        MOV AX, 0
        JE _SASL_45
        MOV AX, 1
_SASL_45:
; stocker FIRST.REGION
        MOV [_SAS_PDV + 16], AX
; LAST.var positionne par look-ahead (stub commentaire)
        MOV AX, 1
; stocker LAST.REGION
        MOV [_SAS_PDV + 18], AX
; LAST.REGION = 1 (sera corrige en runtime)
; IF
; charger FIRST.PRODUCT
        MOV AX, [_SAS_PDV + 20]
        TEST AX, AX
        JZ _SASL_46
        XOR AX, AX
; stocker COUNT
        MOV [_SAS_PDV + 24], AX
_SASL_46:
_SASL_44:
; OUTPUT : copier PDV -> dataset MULTI_BY
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
; Boucle implicite : iteration suivante
        JMP _SASL_42
_SASL_43:
; ========= FIN DATA STEP MULTI_BY =========


; ========= DATA STEP =========
; dataset: UPDATED
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_48:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
        MOV WORD PTR [_SAS_PDV + 6], -32768
        MOV WORD PTR [_SAS_PDV + 8], -32768
        MOV WORD PTR [_SAS_PDV + 10], -32768
        MOV WORD PTR [_SAS_PDV + 12], -32768
        MOV WORD PTR [_SAS_PDV + 14], -32768
        MOV WORD PTR [_SAS_PDV + 16], -32768
        MOV WORD PTR [_SAS_PDV + 18], -32768
        MOV WORD PTR [_SAS_PDV + 20], -32768
        MOV WORD PTR [_SAS_PDV + 22], -32768
        MOV WORD PTR [_SAS_PDV + 24], -32768
; UPDATE (TODO 23)
; UPDATE master=MASTER
; UPDATE transaction=TRANS
; UPDATE : lire master MASTER puis appliquer TRANS
        MOV AX, -32768
; Si valeur transaction <> MISSING -> ecraser maitre
; BY (DATA step, TODO 23)
; BY var=ID
        MOV AX, 0
; stocker FIRST.ID
        MOV [_SAS_PDV + 26], AX
        MOV AX, 0
; stocker LAST.ID
        MOV [_SAS_PDV + 28], AX

; --- Gestion FIRST./LAST. pour BY ---
        MOV AX, WORD PTR [_SAS_BYKEY]
        MOV WORD PTR [_SAS_BYKEY_PREV], AX
        MOV BX, WORD PTR [_SAS_BYKEY_PREV]
        CMP AX, BX
        MOV AX, 0
        JE _SASL_51
        MOV AX, 1
_SASL_51:
; stocker FIRST.ID
        MOV [_SAS_PDV + 26], AX
; LAST.var positionne par look-ahead (stub commentaire)
        MOV AX, 1
; stocker LAST.ID
        MOV [_SAS_PDV + 28], AX
; LAST.ID = 1 (sera corrige en runtime)
_SASL_50:
; OUTPUT : copier PDV -> dataset UPDATED
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_49:
; ========= FIN DATA STEP UPDATED =========


; ========= DATA STEP =========
; dataset: INVENTORY
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_52:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
        MOV WORD PTR [_SAS_PDV + 6], -32768
        MOV WORD PTR [_SAS_PDV + 8], -32768
        MOV WORD PTR [_SAS_PDV + 10], -32768
        MOV WORD PTR [_SAS_PDV + 12], -32768
        MOV WORD PTR [_SAS_PDV + 14], -32768
        MOV WORD PTR [_SAS_PDV + 16], -32768
        MOV WORD PTR [_SAS_PDV + 18], -32768
        MOV WORD PTR [_SAS_PDV + 20], -32768
        MOV WORD PTR [_SAS_PDV + 22], -32768
        MOV WORD PTR [_SAS_PDV + 24], -32768
        MOV WORD PTR [_SAS_PDV + 26], -32768
        MOV WORD PTR [_SAS_PDV + 28], -32768
; MODIFY (TODO 23)
; MODIFY dataset=INVENTORY
; IF
; charger QTY
        MOV AX, [_SAS_PDV + 4]
        PUSH AX
        XOR AX, AX
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_55
        CMP BX, 8000h
        JE _SASL_55
        CMP AX, BX
        JE _SASL_57
        XOR AX, AX
        JMP _SASL_58
_SASL_57:
        MOV AX, 1
_SASL_58:
        JMP _SASL_56
_SASL_55:
        MOV AX, 8000h
_SASL_56:
        TEST AX, AX
        JZ _SASL_59
; DELETE : ne pas ecrire cette observation
        JMP _SASL_52
_SASL_59:
_SASL_54:
; OUTPUT : copier PDV -> dataset INVENTORY
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
; Boucle implicite : iteration suivante
        JMP _SASL_52
_SASL_53:
; ========= FIN DATA STEP INVENTORY =========


; ========= DATA STEP =========
; dataset: ALL_YEAR
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_61:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
        MOV WORD PTR [_SAS_PDV + 6], -32768
        MOV WORD PTR [_SAS_PDV + 8], -32768
        MOV WORD PTR [_SAS_PDV + 10], -32768
        MOV WORD PTR [_SAS_PDV + 12], -32768
        MOV WORD PTR [_SAS_PDV + 14], -32768
        MOV WORD PTR [_SAS_PDV + 16], -32768
        MOV WORD PTR [_SAS_PDV + 18], -32768
        MOV WORD PTR [_SAS_PDV + 20], -32768
        MOV WORD PTR [_SAS_PDV + 22], -32768
        MOV WORD PTR [_SAS_PDV + 24], -32768
        MOV WORD PTR [_SAS_PDV + 26], -32768
        MOV WORD PTR [_SAS_PDV + 28], -32768
; SET (enhanced TODO 23)
; SET source=Q1
; SET source=Q2
; SET source=Q3
; SET concatenation: 3 datasets
        MOV WORD PTR [_SAS_SETIDX], 0
_SASL_63:
; OUTPUT : copier PDV -> dataset ALL_YEAR
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
; Boucle implicite : iteration suivante
        JMP _SASL_61
_SASL_62:
; ========= FIN DATA STEP ALL_YEAR =========


; ========= DATA STEP =========
; dataset: FULL
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_64:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
        MOV WORD PTR [_SAS_PDV + 6], -32768
        MOV WORD PTR [_SAS_PDV + 8], -32768
        MOV WORD PTR [_SAS_PDV + 10], -32768
        MOV WORD PTR [_SAS_PDV + 12], -32768
        MOV WORD PTR [_SAS_PDV + 14], -32768
        MOV WORD PTR [_SAS_PDV + 16], -32768
        MOV WORD PTR [_SAS_PDV + 18], -32768
        MOV WORD PTR [_SAS_PDV + 20], -32768
        MOV WORD PTR [_SAS_PDV + 22], -32768
        MOV WORD PTR [_SAS_PDV + 24], -32768
        MOV WORD PTR [_SAS_PDV + 26], -32768
        MOV WORD PTR [_SAS_PDV + 28], -32768
; MERGE (TODO 23)
; MERGE source=EMP
; MERGE source=DEPT
; MERGE source=SAL
        MOV WORD PTR [_SAS_MRGIDX], 0
; MERGE un-a-un (pas de BY) : correspondance par position
; BY (DATA step, TODO 23)
; BY var=EMP_ID
        MOV AX, 0
; stocker FIRST.EMP_ID
        MOV [_SAS_PDV + 30], AX
        MOV AX, 0
; stocker LAST.EMP_ID
        MOV [_SAS_PDV + 32], AX

; --- Gestion FIRST./LAST. pour BY ---
        MOV AX, WORD PTR [_SAS_BYKEY]
        MOV WORD PTR [_SAS_BYKEY_PREV], AX
        MOV BX, WORD PTR [_SAS_BYKEY_PREV]
        CMP AX, BX
        MOV AX, 0
        JE _SASL_67
        MOV AX, 1
_SASL_67:
; stocker FIRST.EMP_ID
        MOV [_SAS_PDV + 30], AX
; LAST.var positionne par look-ahead (stub commentaire)
        MOV AX, 1
; stocker LAST.EMP_ID
        MOV [_SAS_PDV + 32], AX
; LAST.EMP_ID = 1 (sera corrige en runtime)
_SASL_66:
; OUTPUT : copier PDV -> dataset FULL
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_65:
; ========= FIN DATA STEP FULL =========


; ========= DATA STEP =========
; dataset: SORTED_DESC
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_68:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
        MOV WORD PTR [_SAS_PDV + 6], -32768
        MOV WORD PTR [_SAS_PDV + 8], -32768
        MOV WORD PTR [_SAS_PDV + 10], -32768
        MOV WORD PTR [_SAS_PDV + 12], -32768
        MOV WORD PTR [_SAS_PDV + 14], -32768
        MOV WORD PTR [_SAS_PDV + 16], -32768
        MOV WORD PTR [_SAS_PDV + 18], -32768
        MOV WORD PTR [_SAS_PDV + 20], -32768
        MOV WORD PTR [_SAS_PDV + 22], -32768
        MOV WORD PTR [_SAS_PDV + 24], -32768
        MOV WORD PTR [_SAS_PDV + 26], -32768
        MOV WORD PTR [_SAS_PDV + 28], -32768
        MOV WORD PTR [_SAS_PDV + 30], -32768
        MOV WORD PTR [_SAS_PDV + 32], -32768
; SET (enhanced TODO 23)
; SET source=MYDATA
; BY (DATA step, TODO 23)
; BY var=SCORE
        MOV AX, 0
; stocker FIRST.SCORE
        MOV [_SAS_PDV + 34], AX
        MOV AX, 0
; stocker LAST.SCORE
        MOV [_SAS_PDV + 36], AX

; --- Gestion FIRST./LAST. pour BY ---
        MOV AX, WORD PTR [_SAS_BYKEY]
        MOV WORD PTR [_SAS_BYKEY_PREV], AX
        MOV BX, WORD PTR [_SAS_BYKEY_PREV]
        CMP AX, BX
        MOV AX, 0
        JE _SASL_71
        MOV AX, 1
_SASL_71:
; stocker FIRST.SCORE
        MOV [_SAS_PDV + 34], AX
; LAST.var positionne par look-ahead (stub commentaire)
        MOV AX, 1
; stocker LAST.SCORE
        MOV [_SAS_PDV + 36], AX
; LAST.SCORE = 1 (sera corrige en runtime)
_SASL_70:
; OUTPUT : copier PDV -> dataset SORTED_DESC
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
; Boucle implicite : iteration suivante
        JMP _SASL_68
_SASL_69:
; ========= FIN DATA STEP SORTED_DESC =========


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
_SAS_FIRST  DW  0
_SAS_LAST  DW  0
_SAS_BYKEY  DW  0
_SAS_BYKEY_PREV  DW  0
_SAS_MRGIDX  DW  0
_SAS_SETIDX  DW  0
_SAS_SETEND  DW  0
_SAS_SETNOBS  DW  0
_SAS_SETPT  DW  0
_SASK_23  DB  'Fin du dataset',0

_DATA ENDS

END _SASP_Main
