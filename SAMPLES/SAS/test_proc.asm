; SAS86 v1.0 - SAMPLES/SAS/test_proc.sas
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
; dataset: TEST1
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
        MOV AX, 10
; stocker X
        MOV [_SAS_PDV], AX
        MOV AX, 20
; stocker Y
        MOV [_SAS_PDV + 2], AX
; charger X
        MOV AX, [_SAS_PDV]
        PUSH AX
; charger Y
        MOV AX, [_SAS_PDV + 2]
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_4
        CMP BX, 8000h
        JE _SASL_4
        ADD AX, BX
        JMP _SASL_5
_SASL_4:
        MOV AX, 8000h
_SASL_5:
; stocker TOTAL
        MOV [_SAS_PDV + 4], AX
_SASL_3:
; OUTPUT : copier PDV -> dataset TEST1
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_2:
; ========= FIN DATA STEP TEST1 =========


; ========= PROC PRINT =========
; PROC option DATA=TEST1
; PROC PRINT : execution
; PROC PRINT : affichage tabulaire
; PRINT toutes les variables du PDV
; PRINT X (num)
        MOV AX, WORD PTR [_SAS_PDV + 0]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; PRINT Y (num)
        MOV AX, WORD PTR [_SAS_PDV + 2]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; PRINT TOTAL (num)
        MOV AX, WORD PTR [_SAS_PDV + 4]
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
; PROC option DATA=TEST1
; VAR
; PROC PRINT : execution
; PROC PRINT : affichage tabulaire
; En-tete : X Y TOTAL
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 9
        LEA DX, _SASK_6
        INT 21h
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
; PRINT X (num)
        MOV AX, WORD PTR [_SAS_PDV + 0]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; PRINT Y (num)
        MOV AX, WORD PTR [_SAS_PDV + 2]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; PRINT TOTAL (num)
        MOV AX, WORD PTR [_SAS_PDV + 4]
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


; ========= PROC MEANS =========
; PROC option DATA=TEST1
; VAR
; PROC MEANS : execution
; PROC MEANS : statistiques descriptives
; En-tete stats: Variable N Mean Std Min Max
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 27
        LEA DX, _SASK_7
        INT 21h
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
; MEANS: X
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 1
        LEA DX, _SASK_8
        INT 21h
        MOV AX, WORD PTR [_SAS_PDV + 0]
        CMP AX, -32768
        JE _SASL_9
        PUSH AX
; N = 1
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
        MOV AX, 1
        CALL _SASRT_PUTNUM
        POP AX
        PUSH AX
; Mean = valeur
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
        CALL _SASRT_PUTNUM
        POP AX
        PUSH AX
; Std = 0 (1 observation)
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
        MOV AX, 0
        CALL _SASRT_PUTNUM
        POP AX
        PUSH AX
; Min = valeur
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
        CALL _SASRT_PUTNUM
        POP AX
        PUSH AX
; Max = valeur
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
        CALL _SASRT_PUTNUM
        POP AX
_SASL_9:
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
; MEANS: Y
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 1
        LEA DX, _SASK_10
        INT 21h
        MOV AX, WORD PTR [_SAS_PDV + 2]
        CMP AX, -32768
        JE _SASL_11
        PUSH AX
; N = 1
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
        MOV AX, 1
        CALL _SASRT_PUTNUM
        POP AX
        PUSH AX
; Mean = valeur
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
        CALL _SASRT_PUTNUM
        POP AX
        PUSH AX
; Std = 0 (1 observation)
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
        MOV AX, 0
        CALL _SASRT_PUTNUM
        POP AX
        PUSH AX
; Min = valeur
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
        CALL _SASRT_PUTNUM
        POP AX
        PUSH AX
; Max = valeur
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
        CALL _SASRT_PUTNUM
        POP AX
_SASL_11:
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
; ========= FIN PROC MEANS =========


; ========= PROC SORT =========
; PROC option DATA=TEST1
; PROC option OUT=TEST1_SORTED
; BY
; PROC SORT : execution
; PROC SORT : tri du dataset
; DATA=TEST1
; OUT=TEST1_SORTED
; BY X (ASCENDING)
; Tri a bulles (squelette multi-observations)
        MOV CX, WORD PTR [_SAS_N]
        CMP CX, 2
        JL _SASL_15
        DEC CX
_SASL_12:
        PUSH CX
        XOR SI, SI
_SASL_13:
; Comparer X
        MOV AX, WORD PTR [_SAS_PDV + 0]
        MOV BX, WORD PTR [_SAS_PDV + 0]
        CMP AX, BX
        JLE _SASL_14
; Echange observations (REP MOVSW)
        MOV CX, 256
        NOP
_SASL_14:
        LOOP _SASL_13
        POP CX
        LOOP _SASL_12
_SASL_15:
; PROC SORT : fin du tri
; ========= FIN PROC SORT =========


; ========= PROC FREQ =========
; PROC option DATA=TEST1
; TABLES
; PROC FREQ : execution
; PROC FREQ : tableaux de frequences
; FREQ table: X
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 19
        LEA DX, _SASK_16
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


; ========= PROC FORMAT =========
; PROC FORMAT : execution
; PROC FORMAT : formats utilisateur (stub TODO 20)
; ========= FIN PROC FORMAT =========


; ========= PROC PRINT =========
; PROC option DATA=TEST1
; PROC option NOPRINT
; VAR
; PROC PRINT : execution
; PROC PRINT : NOPRINT -> pas d affichage
; ========= FIN PROC PRINT =========


; ========= PROC MEANS =========
; PROC option DATA=TEST1
; VAR
; TITLE: Statistiques par genre
; FOOTNOTE: Source: test_proc.sas
; PROC MEANS : execution
; PROC MEANS : statistiques descriptives
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 22
        LEA DX, _SASK_17
        INT 21h
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
; En-tete stats: Variable N Mean Std Min Max
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 27
        LEA DX, _SASK_18
        INT 21h
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
; MEANS: X
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 1
        LEA DX, _SASK_19
        INT 21h
        MOV AX, WORD PTR [_SAS_PDV + 0]
        CMP AX, -32768
        JE _SASL_20
        PUSH AX
; N = 1
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
        MOV AX, 1
        CALL _SASRT_PUTNUM
        POP AX
        PUSH AX
; Mean = valeur
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
        CALL _SASRT_PUTNUM
        POP AX
        PUSH AX
; Std = 0 (1 observation)
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
        MOV AX, 0
        CALL _SASRT_PUTNUM
        POP AX
        PUSH AX
; Min = valeur
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
        CALL _SASRT_PUTNUM
        POP AX
        PUSH AX
; Max = valeur
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
        CALL _SASRT_PUTNUM
        POP AX
_SASL_20:
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 21
        LEA DX, _SASK_21
        INT 21h
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
; ========= FIN PROC MEANS =========


; ========= PROC BIZARRE =========
; PROC option DATA=TEST1
; PROC BIZARRE : non reconnu, ignore
; VAR
; ========= FIN PROC BIZARRE =========


; ========= PROC PRINT =========
; PROC option DATA=TEST1
; VAR
; PROC PRINT : execution
; PROC PRINT : affichage tabulaire
; En-tete : X
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 1
        LEA DX, _SASK_22
        INT 21h
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
; PRINT X (num)
        MOV AX, WORD PTR [_SAS_PDV + 0]
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


; ========= PROC MEANS =========
; PROC option DATA=TEST1
; VAR
; PROC MEANS : execution
; PROC MEANS : statistiques descriptives
; En-tete stats: Variable N Min Max Sum
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 22
        LEA DX, _SASK_23
        INT 21h
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
; MEANS: X
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 1
        LEA DX, _SASK_24
        INT 21h
        MOV AX, WORD PTR [_SAS_PDV + 0]
        CMP AX, -32768
        JE _SASL_25
        PUSH AX
; N = 1
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
        MOV AX, 1
        CALL _SASRT_PUTNUM
        POP AX
        PUSH AX
; Min = valeur
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
        CALL _SASRT_PUTNUM
        POP AX
        PUSH AX
; Max = valeur
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
        CALL _SASRT_PUTNUM
        POP AX
; Sum = valeur
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
        CALL _SASRT_PUTNUM
_SASL_25:
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
; MEANS: Y
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 1
        LEA DX, _SASK_26
        INT 21h
        MOV AX, WORD PTR [_SAS_PDV + 2]
        CMP AX, -32768
        JE _SASL_27
        PUSH AX
; N = 1
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
        MOV AX, 1
        CALL _SASRT_PUTNUM
        POP AX
        PUSH AX
; Min = valeur
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
        CALL _SASRT_PUTNUM
        POP AX
        PUSH AX
; Max = valeur
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
        CALL _SASRT_PUTNUM
        POP AX
; Sum = valeur
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
        CALL _SASRT_PUTNUM
_SASL_27:
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
; ========= FIN PROC MEANS =========


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
_SASK_6  DB  'X Y TOTAL',0
_SASK_7  DB  'Variable N Mean Std Min Max',0
_SASK_8  DB  'X',0
_SASK_10  DB  'Y',0
_SASK_16  DB  'X Frequency Percent',0
_SASK_17  DB  'Statistiques par genre',0
_SASK_18  DB  'Variable N Mean Std Min Max',0
_SASK_19  DB  'X',0
_SASK_21  DB  'Source: test_proc.sas',0
_SASK_22  DB  'X',0
_SASK_23  DB  'Variable N Min Max Sum',0
_SASK_24  DB  'X',0
_SASK_26  DB  'Y',0

_DATA ENDS

END _SASP_Main
