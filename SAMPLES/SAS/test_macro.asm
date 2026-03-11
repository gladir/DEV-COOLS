; SAS86 v1.0 - SAMPLES/SAS/test_macro.sas
.MODEL SMALL
.STACK 1024

_TEXT SEGMENT PUBLIC 'CODE'
        ASSUME CS:_TEXT, DS:_DATA, SS:STACK

_SASP_Main:
        PUSH BP
        MOV BP, SP
        MOV AX, _DATA
        MOV DS, AX

; %LET
; %LET NOM = ALICE
; %LET
; %LET AGE = 25
; %LET
; %LET VILLE = MONTREAL
; %PUT
; %PUT: NOM = ALICE
; NOTE: NOM = ALICE
; %PUT
; %PUT: AGE = 25
; NOTE: AGE = 25
; %PUT
; %PUT: VILLE = MONTREAL
; NOTE: VILLE = MONTREAL
; %PUT
; %PUT: DATE SYSTEME = 11MAR26
; NOTE: DATE SYSTEME = 11MAR26
; %PUT
; %PUT: HEURE SYSTEME = 12:00
; NOTE: HEURE SYSTEME = 12:00
; %PUT
; %PUT: VERSION SAS = 1.0
; NOTE: VERSION SAS = 1.0
; %LET
; %LET X = 10
; %LET
; %LET Y = 20
; %PUT
; %PUT: X = 10
; NOTE: X = 10
; %PUT
; %PUT: Y = 20
; NOTE: Y = 20
; %MACRO definition
; %MACRO SALUER definie (2 param)
; %SALUER expansion (2 args)
; %MACRO definition
; %MACRO HEADER definie (0 param)
; %HEADER expansion (0 args)
; %LET
; %LET SCORE = 85
; %IF
; %PUT
; %PUT: RESULTAT : REUSSI
; NOTE: RESULTAT : REUSSI
; %LET
; %LET NOTE = 45
; %IF
; %PUT
; %PUT: NOTE : ECHOUE
; NOTE: NOTE : ECHOUE
; %LET
; %LET COMPTEUR = 3
; %DO
; %PUT
; %PUT: BLOC DO EXECUTE
; NOTE: BLOC DO EXECUTE
; %END
; %GLOBAL
; %LET
; %LET G_VAR = GLOBAL_VAL
; %PUT
; %PUT: G_VAR = GLOBAL_VAL
; NOTE: G_VAR = GLOBAL_VAL
; %LET
; %LET MINUSC = BONJOUR
; %LET
; %LET MOT = HELLO
; %LET
; %LET DSNAME = TRAVAIL

; ========= DATA STEP =========
; dataset: WORK
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
; &&DSNAME (macro-variable en statement)
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
; PUT
; PUT TOTAL
; charger TOTAL
        MOV AX, [_SAS_PDV + 4]
        CALL _SASRT_PUTNUM
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_3:
; OUTPUT : copier PDV -> dataset WORK
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_2:
; ========= FIN DATA STEP WORK =========

; %LET
; %LET MODE = DEBUG
; %IF
; %PUT
; %PUT: MODE DEBUG ACTIVE
; NOTE: MODE DEBUG ACTIVE
; %PUT
; %PUT: TRACE ON
; NOTE: TRACE ON
; %PUT
; %PUT: = = = FIN DES TESTS MACRO = = =
; NOTE: = = = FIN DES TESTS MACRO = = =

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
