; SAS86 v1.0 - SAMPLES/SAS/test_arrays.sas
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
; dataset: TEST
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
; ARRAY declaration
; ARRAY SCORES dim=5 elemsize=2
; DO I = ... TO ...
        MOV AX, 1
        MOV [_SAS_PDV + 10], AX
; DIM()
        MOV AX, 5
        PUSH AX
        MOV AX, 1
        PUSH AX
        PUSH WORD PTR [_SAS_DOEND]
        PUSH WORD PTR [_SAS_DOSTEP]
        POP BX
        MOV [_SAS_DOSTEP], BX
        POP DX
        MOV [_SAS_DOEND], DX
_SASL_4:
        MOV AX, [_SAS_PDV + 10]
        MOV DX, [_SAS_DOEND]
        MOV BX, [_SAS_DOSTEP]
        OR BX, BX
        JS _SASL_4N
        CMP AX, DX
        JG _SASL_6
        JMP _SASL_4OK
_SASL_4N:
        CMP AX, DX
        JL _SASL_6
_SASL_4OK:
; charger I
        MOV AX, [_SAS_PDV + 10]
; affectation SCORES{i} = ...
        DEC AX
        SHL AX, 1
        ADD AX, 0
        PUSH AX
        XOR AX, AX
        POP BX
        MOV WORD PTR [_SAS_PDV + BX], AX
_SASL_5:
        MOV AX, [_SAS_PDV + 10]
        ADD AX, [_SAS_DOSTEP]
        MOV [_SAS_PDV + 10], AX
        JMP _SASL_4
_SASL_6:
        POP WORD PTR [_SAS_DOSTEP]
        POP WORD PTR [_SAS_DOEND]
        MOV AX, 1
; affectation SCORES{i} = ...
        DEC AX
        SHL AX, 1
        ADD AX, 0
        PUSH AX
        MOV AX, 10
        POP BX
        MOV WORD PTR [_SAS_PDV + BX], AX
        MOV AX, 2
; affectation SCORES{i} = ...
        DEC AX
        SHL AX, 1
        ADD AX, 0
        PUSH AX
        MOV AX, 20
        POP BX
        MOV WORD PTR [_SAS_PDV + BX], AX
        MOV AX, 3
; affectation SCORES{i} = ...
        DEC AX
        SHL AX, 1
        ADD AX, 0
        PUSH AX
        MOV AX, 30
        POP BX
        MOV WORD PTR [_SAS_PDV + BX], AX
        MOV AX, 4
; affectation SCORES{i} = ...
        DEC AX
        SHL AX, 1
        ADD AX, 0
        PUSH AX
        MOV AX, 40
        POP BX
        MOV WORD PTR [_SAS_PDV + BX], AX
        MOV AX, 5
; affectation SCORES{i} = ...
        DEC AX
        SHL AX, 1
        ADD AX, 0
        PUSH AX
        MOV AX, 50
        POP BX
        MOV WORD PTR [_SAS_PDV + BX], AX
; DO I = ... TO ...
        MOV AX, 1
        MOV [_SAS_PDV + 10], AX
        MOV AX, 5
        PUSH AX
        MOV AX, 1
        PUSH AX
        PUSH WORD PTR [_SAS_DOEND]
        PUSH WORD PTR [_SAS_DOSTEP]
        POP BX
        MOV [_SAS_DOSTEP], BX
        POP DX
        MOV [_SAS_DOEND], DX
_SASL_7:
        MOV AX, [_SAS_PDV + 10]
        MOV DX, [_SAS_DOEND]
        MOV BX, [_SAS_DOSTEP]
        OR BX, BX
        JS _SASL_7N
        CMP AX, DX
        JG _SASL_9
        JMP _SASL_7OK
_SASL_7N:
        CMP AX, DX
        JL _SASL_9
_SASL_7OK:
; PUT
; PUT literal: 'scores{'
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 7
        LEA DX, _SASK_10
        INT 21h
; PUT I
; charger I
        MOV AX, [_SAS_PDV + 10]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; PUT literal: '}='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SASK_11
        INT 21h
; PUT SCORES
; charger SCORES
        MOV AX, [_SAS_PDV]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
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
_SASL_8:
        MOV AX, [_SAS_PDV + 10]
        ADD AX, [_SAS_DOSTEP]
        MOV [_SAS_PDV + 10], AX
        JMP _SASL_7
_SASL_9:
        POP WORD PTR [_SAS_DOSTEP]
        POP WORD PTR [_SAS_DOEND]
        XOR AX, AX
; stocker TOTAL
        MOV [_SAS_PDV + 12], AX
; DO I = ... TO ...
        MOV AX, 1
        MOV [_SAS_PDV + 10], AX
; DIM()
        MOV AX, 5
        PUSH AX
        MOV AX, 1
        PUSH AX
        PUSH WORD PTR [_SAS_DOEND]
        PUSH WORD PTR [_SAS_DOSTEP]
        POP BX
        MOV [_SAS_DOSTEP], BX
        POP DX
        MOV [_SAS_DOEND], DX
_SASL_12:
        MOV AX, [_SAS_PDV + 10]
        MOV DX, [_SAS_DOEND]
        MOV BX, [_SAS_DOSTEP]
        OR BX, BX
        JS _SASL_12N
        CMP AX, DX
        JG _SASL_14
        JMP _SASL_12OK
_SASL_12N:
        CMP AX, DX
        JL _SASL_14
_SASL_12OK:
; charger TOTAL
        MOV AX, [_SAS_PDV + 12]
        PUSH AX
; charger I
        MOV AX, [_SAS_PDV + 10]
; acces tableau SCORES{i}
        DEC AX
        SHL AX, 1
        ADD AX, 0
        MOV BX, AX
        MOV AX, WORD PTR [_SAS_PDV + BX]
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_15
        CMP BX, 8000h
        JE _SASL_15
        ADD AX, BX
        JMP _SASL_16
_SASL_15:
        MOV AX, 8000h
_SASL_16:
; stocker TOTAL
        MOV [_SAS_PDV + 12], AX
_SASL_13:
        MOV AX, [_SAS_PDV + 10]
        ADD AX, [_SAS_DOSTEP]
        MOV [_SAS_PDV + 10], AX
        JMP _SASL_12
_SASL_14:
        POP WORD PTR [_SAS_DOSTEP]
        POP WORD PTR [_SAS_DOEND]
; PUT
; PUT literal: 'total='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 6
        LEA DX, _SASK_17
        INT 21h
; PUT TOTAL
; charger TOTAL
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
; ARRAY declaration
; ARRAY NOTES dim=3 elemsize=2
        MOV AX, 15
; stocker MATH
        MOV [_SAS_PDV + 14], AX
        MOV AX, 12
; stocker FRANCAIS
        MOV [_SAS_PDV + 16], AX
        MOV AX, 18
; stocker ANGLAIS
        MOV [_SAS_PDV + 18], AX
; DO J = ... TO ...
        MOV AX, 1
        MOV [_SAS_PDV + 20], AX
; DIM()
        MOV AX, 3
        PUSH AX
        MOV AX, 1
        PUSH AX
        PUSH WORD PTR [_SAS_DOEND]
        PUSH WORD PTR [_SAS_DOSTEP]
        POP BX
        MOV [_SAS_DOSTEP], BX
        POP DX
        MOV [_SAS_DOEND], DX
_SASL_18:
        MOV AX, [_SAS_PDV + 20]
        MOV DX, [_SAS_DOEND]
        MOV BX, [_SAS_DOSTEP]
        OR BX, BX
        JS _SASL_18N
        CMP AX, DX
        JG _SASL_20
        JMP _SASL_18OK
_SASL_18N:
        CMP AX, DX
        JL _SASL_20
_SASL_18OK:
; PUT
; PUT literal: 'notes{'
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 6
        LEA DX, _SASK_21
        INT 21h
; PUT J
; charger J
        MOV AX, [_SAS_PDV + 20]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; PUT literal: '}='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SASK_22
        INT 21h
; PUT NOTES
; charger NOTES
        MOV AX, [_SAS_PDV + 14]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; PUT J
; charger J
        MOV AX, [_SAS_PDV + 20]
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
_SASL_19:
        MOV AX, [_SAS_PDV + 20]
        ADD AX, [_SAS_DOSTEP]
        MOV [_SAS_PDV + 20], AX
        JMP _SASL_18
_SASL_20:
        POP WORD PTR [_SAS_DOSTEP]
        POP WORD PTR [_SAS_DOEND]
; ARRAY declaration
; ARRAY VALS dim=5 elemsize=2
; DO K = ... TO ...
        MOV AX, 1
        MOV [_SAS_PDV + 32], AX
        MOV AX, 5
        PUSH AX
        MOV AX, 1
        PUSH AX
        PUSH WORD PTR [_SAS_DOEND]
        PUSH WORD PTR [_SAS_DOSTEP]
        POP BX
        MOV [_SAS_DOSTEP], BX
        POP DX
        MOV [_SAS_DOEND], DX
_SASL_23:
        MOV AX, [_SAS_PDV + 32]
        MOV DX, [_SAS_DOEND]
        MOV BX, [_SAS_DOSTEP]
        OR BX, BX
        JS _SASL_23N
        CMP AX, DX
        JG _SASL_25
        JMP _SASL_23OK
_SASL_23N:
        CMP AX, DX
        JL _SASL_25
_SASL_23OK:
; charger K
        MOV AX, [_SAS_PDV + 32]
; affectation VALS{i} = ...
        DEC AX
        SHL AX, 1
        ADD AX, 22
        PUSH AX
; charger K
        MOV AX, [_SAS_PDV + 32]
        PUSH AX
        MOV AX, 10
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_26
        CMP BX, 8000h
        JE _SASL_26
        IMUL BX
        JMP _SASL_27
_SASL_26:
        MOV AX, 8000h
_SASL_27:
        POP BX
        MOV WORD PTR [_SAS_PDV + BX], AX
_SASL_24:
        MOV AX, [_SAS_PDV + 32]
        ADD AX, [_SAS_DOSTEP]
        MOV [_SAS_PDV + 32], AX
        JMP _SASL_23
_SASL_25:
        POP WORD PTR [_SAS_DOSTEP]
        POP WORD PTR [_SAS_DOEND]
; DO K = ... TO ...
        MOV AX, 1
        MOV [_SAS_PDV + 32], AX
; DIM()
        MOV AX, 5
        PUSH AX
        MOV AX, 1
        PUSH AX
        PUSH WORD PTR [_SAS_DOEND]
        PUSH WORD PTR [_SAS_DOSTEP]
        POP BX
        MOV [_SAS_DOSTEP], BX
        POP DX
        MOV [_SAS_DOEND], DX
_SASL_28:
        MOV AX, [_SAS_PDV + 32]
        MOV DX, [_SAS_DOEND]
        MOV BX, [_SAS_DOSTEP]
        OR BX, BX
        JS _SASL_28N
        CMP AX, DX
        JG _SASL_30
        JMP _SASL_28OK
_SASL_28N:
        CMP AX, DX
        JL _SASL_30
_SASL_28OK:
; PUT
; PUT literal: 'vals{'
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 5
        LEA DX, _SASK_31
        INT 21h
; PUT K
; charger K
        MOV AX, [_SAS_PDV + 32]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; PUT literal: '}='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SASK_32
        INT 21h
; PUT VALS
; charger VALS
        MOV AX, [_SAS_PDV + 22]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; PUT K
; charger K
        MOV AX, [_SAS_PDV + 32]
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
_SASL_29:
        MOV AX, [_SAS_PDV + 32]
        ADD AX, [_SAS_DOSTEP]
        MOV [_SAS_PDV + 32], AX
        JMP _SASL_28
_SASL_30:
        POP WORD PTR [_SAS_DOSTEP]
        POP WORD PTR [_SAS_DOEND]
; ARRAY declaration
; ARRAY TMP dim=3 elemsize=2
        MOV AX, 1
; affectation TMP{i} = ...
        DEC AX
        SHL AX, 1
        ADD AX, 34
        PUSH AX
        MOV AX, 100
        POP BX
        MOV WORD PTR [_SAS_PDV + BX], AX
        MOV AX, 2
; affectation TMP{i} = ...
        DEC AX
        SHL AX, 1
        ADD AX, 34
        PUSH AX
        MOV AX, 200
        POP BX
        MOV WORD PTR [_SAS_PDV + BX], AX
        MOV AX, 3
; affectation TMP{i} = ...
        DEC AX
        SHL AX, 1
        ADD AX, 34
        PUSH AX
        MOV AX, 300
        POP BX
        MOV WORD PTR [_SAS_PDV + BX], AX
; PUT
; PUT literal: 'tmp{2}='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 7
        LEA DX, _SASK_33
        INT 21h
; PUT TMP
; charger TMP
        MOV AX, [_SAS_PDV + 34]
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
; ARRAY declaration
; ARRAY MAT dim=6 elemsize=2
; DO R = ... TO ...
        MOV AX, 1
        MOV [_SAS_PDV + 52], AX
        MOV AX, 2
        PUSH AX
        MOV AX, 1
        PUSH AX
        PUSH WORD PTR [_SAS_DOEND]
        PUSH WORD PTR [_SAS_DOSTEP]
        POP BX
        MOV [_SAS_DOSTEP], BX
        POP DX
        MOV [_SAS_DOEND], DX
_SASL_34:
        MOV AX, [_SAS_PDV + 52]
        MOV DX, [_SAS_DOEND]
        MOV BX, [_SAS_DOSTEP]
        OR BX, BX
        JS _SASL_34N
        CMP AX, DX
        JG _SASL_36
        JMP _SASL_34OK
_SASL_34N:
        CMP AX, DX
        JL _SASL_36
_SASL_34OK:
; DO C = ... TO ...
        MOV AX, 1
        MOV [_SAS_PDV + 54], AX
        MOV AX, 3
        PUSH AX
        MOV AX, 1
        PUSH AX
        PUSH WORD PTR [_SAS_DOEND]
        PUSH WORD PTR [_SAS_DOSTEP]
        POP BX
        MOV [_SAS_DOSTEP], BX
        POP DX
        MOV [_SAS_DOEND], DX
_SASL_37:
        MOV AX, [_SAS_PDV + 54]
        MOV DX, [_SAS_DOEND]
        MOV BX, [_SAS_DOSTEP]
        OR BX, BX
        JS _SASL_37N
        CMP AX, DX
        JG _SASL_39
        JMP _SASL_37OK
_SASL_37N:
        CMP AX, DX
        JL _SASL_39
_SASL_37OK:
; charger R
        MOV AX, [_SAS_PDV + 52]
        PUSH AX
        MOV AX, 1
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_40
        CMP BX, 8000h
        JE _SASL_40
        SUB AX, BX
        JMP _SASL_41
_SASL_40:
        MOV AX, 8000h
_SASL_41:
        PUSH AX
        MOV AX, 3
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_42
        CMP BX, 8000h
        JE _SASL_42
        IMUL BX
        JMP _SASL_43
_SASL_42:
        MOV AX, 8000h
_SASL_43:
        PUSH AX
; charger C
        MOV AX, [_SAS_PDV + 54]
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_44
        CMP BX, 8000h
        JE _SASL_44
        ADD AX, BX
        JMP _SASL_45
_SASL_44:
        MOV AX, 8000h
_SASL_45:
; stocker IDX
        MOV [_SAS_PDV + 56], AX
; charger IDX
        MOV AX, [_SAS_PDV + 56]
; affectation MAT{i} = ...
        DEC AX
        SHL AX, 1
        ADD AX, 40
        PUSH AX
; charger R
        MOV AX, [_SAS_PDV + 52]
        PUSH AX
        MOV AX, 10
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_46
        CMP BX, 8000h
        JE _SASL_46
        IMUL BX
        JMP _SASL_47
_SASL_46:
        MOV AX, 8000h
_SASL_47:
        PUSH AX
; charger C
        MOV AX, [_SAS_PDV + 54]
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_48
        CMP BX, 8000h
        JE _SASL_48
        ADD AX, BX
        JMP _SASL_49
_SASL_48:
        MOV AX, 8000h
_SASL_49:
        POP BX
        MOV WORD PTR [_SAS_PDV + BX], AX
_SASL_38:
        MOV AX, [_SAS_PDV + 54]
        ADD AX, [_SAS_DOSTEP]
        MOV [_SAS_PDV + 54], AX
        JMP _SASL_37
_SASL_39:
        POP WORD PTR [_SAS_DOSTEP]
        POP WORD PTR [_SAS_DOEND]
_SASL_35:
        MOV AX, [_SAS_PDV + 52]
        ADD AX, [_SAS_DOSTEP]
        MOV [_SAS_PDV + 52], AX
        JMP _SASL_34
_SASL_36:
        POP WORD PTR [_SAS_DOSTEP]
        POP WORD PTR [_SAS_DOEND]
; PUT
; PUT literal: 'mat{1}='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 7
        LEA DX, _SASK_50
        INT 21h
; PUT MAT
; charger MAT
        MOV AX, [_SAS_PDV + 40]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; PUT literal: ' mat{6}='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 8
        LEA DX, _SASK_51
        INT 21h
; PUT MAT
; charger MAT
        MOV AX, [_SAS_PDV + 40]
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
; OUTPUT : copier PDV -> dataset TEST
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_2:
; ========= FIN DATA STEP TEST =========


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
_SASK_10  DB  'scores{',0
_SASK_11  DB  '}=',0
_SASK_17  DB  'total=',0
_SASK_21  DB  'notes{',0
_SASK_22  DB  '}=',0
_SASK_31  DB  'vals{',0
_SASK_32  DB  '}=',0
_SASK_33  DB  'tmp{2}=',0
_SASK_50  DB  'mat{1}=',0
_SASK_51  DB  ' mat{6}=',0

_DATA ENDS

END _SASP_Main
