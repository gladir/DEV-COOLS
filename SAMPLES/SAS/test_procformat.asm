; SAS86 v1.0 - SAMPLES/SAS/test_procformat.sas
.MODEL SMALL
.STACK 1024

_TEXT SEGMENT PUBLIC 'CODE'
        ASSUME CS:_TEXT, DS:_DATA, SS:STACK

_SASP_Main:
        PUSH BP
        MOV BP, SP
        MOV AX, _DATA
        MOV DS, AX


; ========= PROC FORMAT =========
; PROC FORMAT : VALUE AGEFMT
; PROC FORMAT : execution
; PROC FORMAT : emission des tables de formats
; Format AGEFMT : 4 plages
;   plage 0 -> Enfant (_SASK_1)
;   plage 1 -> Adolescent (_SASK_2)
;   plage 2 -> Adulte (_SASK_3)
;   plage 3 -> Senior (_SASK_4)
; ========= FIN PROC FORMAT =========


; ========= PROC FORMAT =========
; PROC FORMAT : VALUE SCOREFMT
; PROC FORMAT : execution
; PROC FORMAT : emission des tables de formats
; Format AGEFMT : 4 plages
;   plage 0 -> Enfant (_SASK_5)
;   plage 1 -> Adolescent (_SASK_6)
;   plage 2 -> Adulte (_SASK_7)
;   plage 3 -> Senior (_SASK_8)
; Format SCOREFMT : 4 plages
;   plage 0 -> Faible (_SASK_9)
;   plage 1 -> Moyen (_SASK_10)
;   plage 2 -> Bon (_SASK_11)
;   plage 3 -> Inconnu (_SASK_12)
; ========= FIN PROC FORMAT =========


; ========= PROC FORMAT =========
; PROC FORMAT : VALUE TEMPFMT
; PROC FORMAT : execution
; PROC FORMAT : emission des tables de formats
; Format AGEFMT : 4 plages
;   plage 0 -> Enfant (_SASK_13)
;   plage 1 -> Adolescent (_SASK_14)
;   plage 2 -> Adulte (_SASK_15)
;   plage 3 -> Senior (_SASK_16)
; Format SCOREFMT : 4 plages
;   plage 0 -> Faible (_SASK_17)
;   plage 1 -> Moyen (_SASK_18)
;   plage 2 -> Bon (_SASK_19)
;   plage 3 -> Inconnu (_SASK_20)
; Format TEMPFMT : 4 plages
;   plage 0 -> Gel (_SASK_21)
;   plage 1 -> Froid (_SASK_22)
;   plage 2 -> Tempere (_SASK_23)
;   plage 3 -> Chaud (_SASK_24)
; ========= FIN PROC FORMAT =========


; ========= DATA STEP =========
; dataset: TEST1
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_25:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV AX, 3
; stocker AGE
        MOV [_SAS_PDV], AX
        MOV AX, 85
; stocker SCORE
        MOV [_SAS_PDV + 2], AX
; FORMAT
; FORMAT AGE = AGEFMT
; FORMAT SCORE = SCOREFMT
_SASL_27:
; OUTPUT : copier PDV -> dataset TEST1
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_26:
; ========= FIN DATA STEP TEST1 =========


; ========= PROC PRINT =========
; PROC option DATA=TEST1
; VAR
; FORMAT
; FORMAT AGE = AGEFMT
; PROC PRINT : execution
; PROC PRINT : affichage tabulaire
; En-tete : AGE SCORE
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 9
        LEA DX, _SASK_28
        INT 21h
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
; PRINT AGE (num)
        MOV AX, WORD PTR [_SAS_PDV + 0]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; PRINT SCORE (num)
        MOV AX, WORD PTR [_SAS_PDV + 2]
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


; ========= PROC FORMAT =========
; PROC FORMAT : execution
; PROC FORMAT : emission des tables de formats
; Format AGEFMT : 4 plages
;   plage 0 -> Enfant (_SASK_29)
;   plage 1 -> Adolescent (_SASK_30)
;   plage 2 -> Adulte (_SASK_31)
;   plage 3 -> Senior (_SASK_32)
; Format SCOREFMT : 4 plages
;   plage 0 -> Faible (_SASK_33)
;   plage 1 -> Moyen (_SASK_34)
;   plage 2 -> Bon (_SASK_35)
;   plage 3 -> Inconnu (_SASK_36)
; Format TEMPFMT : 4 plages
;   plage 0 -> Gel (_SASK_37)
;   plage 1 -> Froid (_SASK_38)
;   plage 2 -> Tempere (_SASK_39)
;   plage 3 -> Chaud (_SASK_40)
; ========= FIN PROC FORMAT =========


; ========= DATA STEP =========
; dataset: TEST2
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_41:
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
        MOV AX, 42
; stocker X
        MOV [_SAS_PDV + 4], AX
; FORMAT
; FORMAT X = BEST
_SASL_43:
; OUTPUT : copier PDV -> dataset TEST2
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_42:
; ========= FIN DATA STEP TEST2 =========


; ========= PROC FORMAT =========
; PROC FORMAT : VALUE YESNO
; PROC FORMAT : execution
; PROC FORMAT : emission des tables de formats
; Format AGEFMT : 4 plages
;   plage 0 -> Enfant (_SASK_44)
;   plage 1 -> Adolescent (_SASK_45)
;   plage 2 -> Adulte (_SASK_46)
;   plage 3 -> Senior (_SASK_47)
; Format SCOREFMT : 4 plages
;   plage 0 -> Faible (_SASK_48)
;   plage 1 -> Moyen (_SASK_49)
;   plage 2 -> Bon (_SASK_50)
;   plage 3 -> Inconnu (_SASK_51)
; Format TEMPFMT : 4 plages
;   plage 0 -> Gel (_SASK_52)
;   plage 1 -> Froid (_SASK_53)
;   plage 2 -> Tempere (_SASK_54)
;   plage 3 -> Chaud (_SASK_55)
; Format YESNO : 3 plages
;   plage 0 -> Non (_SASK_56)
;   plage 1 -> Oui (_SASK_57)
;   plage 2 -> NA (_SASK_58)
; ========= FIN PROC FORMAT =========


; ========= DATA STEP =========
; dataset: TEST3
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_59:
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
        MOV AX, 1
; stocker REPONSE
        MOV [_SAS_PDV + 6], AX
; FORMAT
; FORMAT REPONSE = YESNO
_SASL_61:
; OUTPUT : copier PDV -> dataset TEST3
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_60:
; ========= FIN DATA STEP TEST3 =========


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
_SASK_1  DB  'Enfant',0
_SASK_2  DB  'Adolescent',0
_SASK_3  DB  'Adulte',0
_SASK_4  DB  'Senior',0
_SASK_5  DB  'Enfant',0
_SASK_6  DB  'Adolescent',0
_SASK_7  DB  'Adulte',0
_SASK_8  DB  'Senior',0
_SASK_9  DB  'Faible',0
_SASK_10  DB  'Moyen',0
_SASK_11  DB  'Bon',0
_SASK_12  DB  'Inconnu',0
_SASK_13  DB  'Enfant',0
_SASK_14  DB  'Adolescent',0
_SASK_15  DB  'Adulte',0
_SASK_16  DB  'Senior',0
_SASK_17  DB  'Faible',0
_SASK_18  DB  'Moyen',0
_SASK_19  DB  'Bon',0
_SASK_20  DB  'Inconnu',0
_SASK_21  DB  'Gel',0
_SASK_22  DB  'Froid',0
_SASK_23  DB  'Tempere',0
_SASK_24  DB  'Chaud',0
_SASK_28  DB  'AGE SCORE',0
_SASK_29  DB  'Enfant',0
_SASK_30  DB  'Adolescent',0
_SASK_31  DB  'Adulte',0
_SASK_32  DB  'Senior',0
_SASK_33  DB  'Faible',0
_SASK_34  DB  'Moyen',0
_SASK_35  DB  'Bon',0
_SASK_36  DB  'Inconnu',0
_SASK_37  DB  'Gel',0
_SASK_38  DB  'Froid',0
_SASK_39  DB  'Tempere',0
_SASK_40  DB  'Chaud',0
_SASK_44  DB  'Enfant',0
_SASK_45  DB  'Adolescent',0
_SASK_46  DB  'Adulte',0
_SASK_47  DB  'Senior',0
_SASK_48  DB  'Faible',0
_SASK_49  DB  'Moyen',0
_SASK_50  DB  'Bon',0
_SASK_51  DB  'Inconnu',0
_SASK_52  DB  'Gel',0
_SASK_53  DB  'Froid',0
_SASK_54  DB  'Tempere',0
_SASK_55  DB  'Chaud',0
_SASK_56  DB  'Non',0
_SASK_57  DB  'Oui',0
_SASK_58  DB  'NA',0

_DATA ENDS

END _SASP_Main
