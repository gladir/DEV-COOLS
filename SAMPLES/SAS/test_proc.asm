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


; ========= PROC PRINT =========
; PROC option DATA=TEST1
; PROC PRINT : execution
; PROC PRINT : affichage tabulaire (stub TODO 18)
;   DATA=TEST1
; ========= FIN PROC PRINT =========


; ========= PROC PRINT =========
; PROC option DATA=TEST1
; VAR
; PROC PRINT : execution
; PROC PRINT : affichage tabulaire (stub TODO 18)
;   DATA=TEST1
;   VAR : 3 variable(s)
; ========= FIN PROC PRINT =========


; ========= PROC MEANS =========
; PROC option DATA=TEST1
; VAR
; PROC MEANS : execution
; PROC MEANS : statistiques descriptives (stub TODO 18)
;   DATA=TEST1
;   VAR : 2 variable(s)
; ========= FIN PROC MEANS =========


; ========= PROC SORT =========
; PROC option DATA=TEST1
; PROC option OUT=TEST1_SORTED
; BY
; PROC SORT : execution
; PROC SORT : tri (stub TODO 19)
;   DATA=TEST1
;   OUT=TEST1_SORTED
;   BY : 2 variable(s)
; ========= FIN PROC SORT =========


; ========= PROC FREQ =========
; PROC option DATA=TEST1
; TABLES (stub TODO 19)
; PROC FREQ : execution
; PROC FREQ : frequences (stub TODO 19)
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
; PROC PRINT : affichage tabulaire (stub TODO 18)
;   DATA=TEST1
;   VAR : 1 variable(s)
; ========= FIN PROC PRINT =========


; ========= PROC MEANS =========
; PROC option DATA=TEST1
; CLASS
; VAR
; TITLE: Statistiques par genre
; FOOTNOTE: Source: test_proc.sas
; PROC MEANS : execution
; PROC MEANS : statistiques descriptives (stub TODO 18)
;   DATA=TEST1
;   VAR : 1 variable(s)
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
; PROC PRINT : affichage tabulaire (stub TODO 18)
;   DATA=TEST1
;   VAR : 1 variable(s)
; ========= FIN PROC PRINT =========


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

_DATA ENDS

END _SASP_Main
