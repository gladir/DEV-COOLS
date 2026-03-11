; SAS86 v1.0 - SAMPLES/SAS/test_datastep.sas
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
; PUT
; PUT literal: 'total='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 6
        LEA DX, _SASK_6
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
; OUTPUT : copier PDV -> dataset TEST1
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_2:
; ========= FIN DATA STEP TEST1 =========


; ========= DATA STEP =========
; dataset: TEST2
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_7:
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
; stocker A
        MOV [_SAS_PDV + 6], AX
; OUTPUT explicite
; OUTPUT : copier PDV -> dataset TEST2
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        MOV AX, 2
; stocker A
        MOV [_SAS_PDV + 6], AX
; OUTPUT explicite
; OUTPUT : copier PDV -> dataset TEST2
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
; PUT
; PUT literal: 'a='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SASK_10
        INT 21h
; PUT A
; charger A
        MOV AX, [_SAS_PDV + 6]
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
        INC WORD PTR [_SAS_N]
_SASL_8:
; ========= FIN DATA STEP TEST2 =========


; ========= DATA STEP =========
; dataset: TEST3
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_11:
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
        MOV AX, 55
; stocker SCORE
        MOV [_SAS_PDV + 8], AX
; IF
; charger SCORE
        MOV AX, [_SAS_PDV + 8]
        PUSH AX
        MOV AX, 60
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_14
        CMP BX, 8000h
        JE _SASL_14
        CMP AX, BX
        JL _SASL_16
        XOR AX, AX
        JMP _SASL_17
_SASL_16:
        MOV AX, 1
_SASL_17:
        JMP _SASL_15
_SASL_14:
        MOV AX, 8000h
_SASL_15:
        TEST AX, AX
        JZ _SASL_18
; DELETE : ne pas ecrire cette observation
        JMP _SASL_11
_SASL_18:
; PUT
; PUT literal: 'score='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 6
        LEA DX, _SASK_20
        INT 21h
; PUT SCORE
; charger SCORE
        MOV AX, [_SAS_PDV + 8]
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
_SASL_13:
; OUTPUT : copier PDV -> dataset TEST3
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_12:
; ========= FIN DATA STEP TEST3 =========


; ========= DATA STEP =========
; dataset: TEST4
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_21:
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
        XOR AX, AX
; stocker I
        MOV [_SAS_PDV + 10], AX
; DO WHILE
_SASL_24:
; charger I
        MOV AX, [_SAS_PDV + 10]
        PUSH AX
        MOV AX, 100
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_26
        CMP BX, 8000h
        JE _SASL_26
        CMP AX, BX
        JL _SASL_28
        XOR AX, AX
        JMP _SASL_29
_SASL_28:
        MOV AX, 1
_SASL_29:
        JMP _SASL_27
_SASL_26:
        MOV AX, 8000h
_SASL_27:
        TEST AX, AX
        JZ _SASL_25
; charger I
        MOV AX, [_SAS_PDV + 10]
        PUSH AX
        MOV AX, 1
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_30
        CMP BX, 8000h
        JE _SASL_30
        ADD AX, BX
        JMP _SASL_31
_SASL_30:
        MOV AX, 8000h
_SASL_31:
; stocker I
        MOV [_SAS_PDV + 10], AX
; IF
; charger I
        MOV AX, [_SAS_PDV + 10]
        PUSH AX
        MOV AX, 5
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_32
        CMP BX, 8000h
        JE _SASL_32
        CMP AX, BX
        JG _SASL_34
        XOR AX, AX
        JMP _SASL_35
_SASL_34:
        MOV AX, 1
_SASL_35:
        JMP _SASL_33
_SASL_32:
        MOV AX, 8000h
_SASL_33:
        TEST AX, AX
        JZ _SASL_36
; STOP : arreter le DATA step
        JMP _SASL_22
_SASL_36:
; PUT
; PUT literal: 'i='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SASK_38
        INT 21h
; PUT I
; charger I
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
        JMP _SASL_24
_SASL_25:
_SASL_23:
; OUTPUT : copier PDV -> dataset TEST4
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_22:
; ========= FIN DATA STEP TEST4 =========


; ========= DATA STEP =========
; dataset: _NULL_
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_39:
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
        MOV AX, 42
; stocker MSG
        MOV [_SAS_PDV + 12], AX
; PUT
; PUT literal: 'Message:'
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 8
        LEA DX, _SASK_42
        INT 21h
; PUT MSG
; charger MSG
        MOV AX, [_SAS_PDV + 12]
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
_SASL_41:
; OUTPUT : copier PDV -> dataset _NULL_
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_40:
; ========= FIN DATA STEP _NULL_ =========


; ========= DATA STEP =========
; dataset: COPIE
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_43:
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
; SET
; SET source=TEST1
; PUT
; PUT literal: 'copie: x='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 9
        LEA DX, _SASK_46
        INT 21h
; PUT X
; charger X
        MOV AX, [_SAS_PDV]
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
_SASL_45:
; OUTPUT : copier PDV -> dataset COPIE
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
; Boucle implicite : iteration suivante
        JMP _SASL_43
_SASL_44:
; ========= FIN DATA STEP COPIE =========


; ========= DATA STEP =========
; dataset: CUMUL
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_47:
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
; RETAIN
        MOV AX, 10
; stocker VAL
        MOV [_SAS_PDV + 16], AX
; charger SOMME
        MOV AX, [_SAS_PDV + 14]
        PUSH AX
; charger VAL
        MOV AX, [_SAS_PDV + 16]
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_50
        CMP BX, 8000h
        JE _SASL_50
        ADD AX, BX
        JMP _SASL_51
_SASL_50:
        MOV AX, 8000h
_SASL_51:
; stocker SOMME
        MOV [_SAS_PDV + 14], AX
; PUT
; PUT literal: 'somme='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 6
        LEA DX, _SASK_52
        INT 21h
; PUT SOMME
; charger SOMME
        MOV AX, [_SAS_PDV + 14]
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
_SASL_49:
; OUTPUT : copier PDV -> dataset CUMUL
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_48:
; ========= FIN DATA STEP CUMUL =========


; ========= DATA STEP =========
; dataset: AUTO
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_53:
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
        MOV WORD PTR [_SAS_PDV + 16], -32768
        MOV AX, 99
; stocker X
        MOV [_SAS_PDV], AX
; PUT
; PUT literal: '_N_= observation numero'
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 23
        LEA DX, _SASK_56
        INT 21h
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
; PUT
; PUT literal: 'x='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SASK_57
        INT 21h
; PUT X
; charger X
        MOV AX, [_SAS_PDV]
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
_SASL_55:
; OUTPUT : copier PDV -> dataset AUTO
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_54:
; ========= FIN DATA STEP AUTO =========


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
_SASK_6  DB  'total=',0
_SASK_10  DB  'a=',0
_SASK_20  DB  'score=',0
_SASK_38  DB  'i=',0
_SASK_42  DB  'Message:',0
_SASK_46  DB  'copie: x=',0
_SASK_52  DB  'somme=',0
_SASK_56  DB  '_N_= observation numero',0
_SASK_57  DB  'x=',0

_DATA ENDS

END _SASP_Main
