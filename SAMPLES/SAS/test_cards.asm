; SAS86 v1.0 - SAMPLES/SAS/test_cards.sas
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
; dataset: CARTES
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
; FILE
; FILE PRINT (STDOUT)
        MOV WORD PTR [_SAS_OUTHDL], 1
; INFILE
; INFILE CARDS
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
; INPUT X (liste)
        LEA SI, _SAS_INBUF
        ADD SI, [_SAS_INPOS]
        CALL _SASRT_GETNUM
        MOV [_SAS_PDV], AX
        MOV [_SAS_INPOS], SI
; INPUT Y (liste)
        LEA SI, _SAS_INBUF
        ADD SI, [_SAS_INPOS]
        CALL _SASRT_GETNUM
        MOV [_SAS_PDV + 2], AX
        MOV [_SAS_INPOS], SI
_SASL_4:
; charger X
        MOV AX, [_SAS_PDV]
        PUSH AX
; charger Y
        MOV AX, [_SAS_PDV + 2]
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_5
        CMP BX, 8000h
        JE _SASL_5
        ADD AX, BX
        JMP _SASL_6
_SASL_5:
        MOV AX, 8000h
_SASL_6:
; stocker TOTAL
        MOV [_SAS_PDV + 4], AX
; PUT
; PUT literal: 'Total :'
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 7
        LEA DX, _SASK_7
        INT 21h
; PUT TOTAL
; charger TOTAL
        MOV AX, [_SAS_PDV + 4]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_3:
; OUTPUT : copier PDV -> dataset CARTES
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_2:
; ========= FIN DATA STEP CARTES =========


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
_SASK_7  DB  'Total :',0

_DATA ENDS

END _SASP_Main
