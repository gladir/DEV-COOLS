; SAS86 v1.0 - SAMPLES/SAS/test_infile.sas
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
; dataset: RESULT
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
; INFILE
; INFILE 'donnees.dat'
        MOV AH, 3Dh
        MOV AL, 00h
        LEA DX, _SASK_4
        INT 21h
        MOV [_SAS_INHDL], AX
;   DLM=','
;   FIRSTOBS=2
; INPUT
; lire une ligne dans _SAS_INBUF
        MOV AH, 3Fh
        MOV BX, [_SAS_INHDL]
        MOV CX, 255
        LEA DX, _SAS_INBUF
        INT 21h
        CMP AX, 0
        JE _SASL_5
        MOV [_SAS_INLEN], AX
        MOV WORD PTR [_SAS_INPOS], 0
; INPUT NOM (liste)
        LEA SI, _SAS_INBUF
        ADD SI, [_SAS_INPOS]
        MOV CX, 8
        LEA DI, _SAS_PDV + 0
        CALL _SASRT_GETFLD
        MOV [_SAS_INPOS], SI
; INPUT AGE (liste)
        LEA SI, _SAS_INBUF
        ADD SI, [_SAS_INPOS]
        CALL _SASRT_GETNUM
        MOV [_SAS_PDV + 8], AX
        MOV [_SAS_INPOS], SI
; INPUT SALAIRE (liste)
        LEA SI, _SAS_INBUF
        ADD SI, [_SAS_INPOS]
        CALL _SASRT_GETNUM
        MOV [_SAS_PDV + 10], AX
        MOV [_SAS_INPOS], SI
_SASL_5:
; FILE
; FILE 'sortie.dat'
        MOV AH, 3Ch
        MOV CX, 0
        LEA DX, _SASK_6
        INT 21h
        MOV [_SAS_OUTHDL], AX
; PUT
; PUT NOM
        LEA DX, _SAS_PDV + 0
        MOV CX, 8
        CALL _SASRT_PUTSTR
; PUT AGE
; charger AGE
        MOV AX, [_SAS_PDV + 8]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; PUT SALAIRE
; charger SALAIRE
        MOV AX, [_SAS_PDV + 10]
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
; OUTPUT : copier PDV -> dataset RESULT
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_2:
; ========= FIN DATA STEP RESULT =========


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
_SASK_4  DB  'donnees.dat',0
_SASK_6  DB  'sortie.dat',0

_DATA ENDS

END _SASP_Main
