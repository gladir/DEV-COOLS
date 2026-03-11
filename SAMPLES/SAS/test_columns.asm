; SAS86 v1.0 - SAMPLES/SAS/test_columns.sas
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
; dataset: COLUMNS
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
; INPUT
; lire une ligne dans _SAS_INBUF
        MOV AH, 3Fh
        MOV BX, [_SAS_INHDL]
        MOV CX, 255
        LEA DX, _SAS_INBUF
        INT 21h
        CMP AX, 0
        JE _SASL_4
        MOV [_SAS_INLEN], AX
        MOV WORD PTR [_SAS_INPOS], 0
; INPUT NOM 1-10
        LEA SI, _SAS_INBUF + 0
        MOV CX, 10
        LEA DI, _SAS_PDV + 0
        CALL _SASRT_CPYFLD
; INPUT AGE 11-13
        LEA SI, _SAS_INBUF + 10
        MOV CX, 3
        CALL _SASRT_ATOI
        MOV [_SAS_PDV + 10], AX
_SASL_4:
; PUT
; PUT NOM 1-10
        LEA DX, _SAS_PDV + 0
        MOV CX, 10
        CALL _SASRT_PUTSTR
; PUT AGE 11-13
; charger AGE
        MOV AX, [_SAS_PDV + 10]
        CALL _SASRT_PUTNUM
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
; PUT
; PUT literal: 'Fin du test colonnes'
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 20
        LEA DX, _SASK_5
        INT 21h
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_3:
; OUTPUT : copier PDV -> dataset COLUMNS
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_2:
; ========= FIN DATA STEP COLUMNS =========


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
_SASK_5  DB  'Fin du test colonnes',0

_DATA ENDS

END _SASP_Main
