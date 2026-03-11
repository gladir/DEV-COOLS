; SAS86 v1.0 - SAMPLES/SAS/test_procfreqsort.sas
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
; dataset: SCORES
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
        MOV AX, 42
; stocker X
        MOV [_SAS_PDV], AX
        MOV AX, 10
; stocker Y
        MOV [_SAS_PDV + 2], AX
_SASL_3:
; OUTPUT : copier PDV -> dataset SCORES
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_2:
; ========= FIN DATA STEP SCORES =========


; ========= PROC FREQ =========
; PROC option DATA=SCORES
; TABLES
; PROC FREQ : execution
; PROC FREQ : tableaux de frequences
; FREQ table: X
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 19
        LEA DX, _SASK_4
        INT 21h
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
; FREQ X (num)
        MOV AX, WORD PTR [_SAS_PDV + 0]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; Frequency = 1
        MOV AX, 1
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; Percent = 100
        MOV AX, 100
        CALL _SASRT_PUTNUM
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
; ========= FIN PROC FREQ =========


; ========= PROC FREQ =========
; PROC option DATA=SCORES
; TABLES
; PROC FREQ : execution
; PROC FREQ : tableaux de frequences
; FREQ table: X
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 19
        LEA DX, _SASK_5
        INT 21h
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
; FREQ X (num)
        MOV AX, WORD PTR [_SAS_PDV + 0]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; Frequency = 1
        MOV AX, 1
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; Percent = 100
        MOV AX, 100
        CALL _SASRT_PUTNUM
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
; FREQ table: Y
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 19
        LEA DX, _SASK_6
        INT 21h
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
; FREQ Y (num)
        MOV AX, WORD PTR [_SAS_PDV + 2]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; Frequency = 1
        MOV AX, 1
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; Percent = 100
        MOV AX, 100
        CALL _SASRT_PUTNUM
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
; ========= FIN PROC FREQ =========


; ========= PROC SORT =========
; PROC option DATA=SCORES
; PROC option OUT=SCORES_SORTED
; BY
; PROC SORT : execution
; PROC SORT : tri du dataset
; DATA=SCORES
; OUT=SCORES_SORTED
; BY X (ASCENDING)
; Tri a bulles (squelette multi-observations)
        MOV CX, WORD PTR [_SAS_N]
        CMP CX, 2
        JL _SASL_10
        DEC CX
_SASL_7:
        PUSH CX
        XOR SI, SI
_SASL_8:
; Comparer X
        MOV AX, WORD PTR [_SAS_PDV + 0]
        MOV BX, WORD PTR [_SAS_PDV + 0]
        CMP AX, BX
        JLE _SASL_9
; Echange observations (REP MOVSW)
        MOV CX, 256
        NOP
_SASL_9:
        LOOP _SASL_8
        POP CX
        LOOP _SASL_7
_SASL_10:
; PROC SORT : fin du tri
; ========= FIN PROC SORT =========


; ========= PROC SORT =========
; PROC option DATA=SCORES
; BY
; PROC SORT : execution
; PROC SORT : tri du dataset
; DATA=SCORES
; BY Y (DESCENDING)
; Tri a bulles (squelette multi-observations)
        MOV CX, WORD PTR [_SAS_N]
        CMP CX, 2
        JL _SASL_14
        DEC CX
_SASL_11:
        PUSH CX
        XOR SI, SI
_SASL_12:
; Comparer Y
        MOV AX, WORD PTR [_SAS_PDV + 2]
        MOV BX, WORD PTR [_SAS_PDV + 2]
        CMP AX, BX
        JGE _SASL_13
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


; ========= PROC SORT =========
; PROC option DATA=SCORES
; PROC option OUT=RESULTAT
; BY
; PROC SORT : execution
; PROC SORT : tri du dataset
; DATA=SCORES
; OUT=RESULTAT
; BY X (ASCENDING)
; BY Y (DESCENDING)
; Tri a bulles (squelette multi-observations)
        MOV CX, WORD PTR [_SAS_N]
        CMP CX, 2
        JL _SASL_18
        DEC CX
_SASL_15:
        PUSH CX
        XOR SI, SI
_SASL_16:
; Comparer X
        MOV AX, WORD PTR [_SAS_PDV + 0]
        MOV BX, WORD PTR [_SAS_PDV + 0]
        CMP AX, BX
        JLE _SASL_17
; Echange observations (REP MOVSW)
        MOV CX, 256
        NOP
_SASL_17:
        LOOP _SASL_16
        POP CX
        LOOP _SASL_15
_SASL_18:
; PROC SORT : fin du tri
; ========= FIN PROC SORT =========


; ========= PROC FREQ =========
; PROC option DATA=SCORES
; PROC option NOPRINT
; TABLES
; PROC FREQ : execution
; PROC FREQ : NOPRINT -> pas d affichage
; ========= FIN PROC FREQ =========


; ========= PROC FREQ =========
; PROC option DATA=SCORES
; PROC FREQ : execution
; PROC FREQ : tableaux de frequences
; PROC FREQ : aucune variable TABLES specifiee
; ========= FIN PROC FREQ =========


; ========= PROC SORT =========
; PROC option DATA=SCORES
; PROC SORT : execution
; PROC SORT : tri du dataset
; DATA=SCORES
; PROC SORT : aucune variable BY specifiee
; ========= FIN PROC SORT =========


; --- Fin du code ---
        MOV SP, BP
        POP BP
        MOV AX, 4C00h
        INT 21h


; --- Runtime minimal SAS86 ---

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
_SASK_4  DB  'X Frequency Percent',0
_SASK_5  DB  'X Frequency Percent',0
_SASK_6  DB  'Y Frequency Percent',0

_DATA ENDS

END _SASP_Main
