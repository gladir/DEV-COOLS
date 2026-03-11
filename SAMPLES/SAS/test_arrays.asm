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

; DATA
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
_SASL_1:
        MOV AX, [_SAS_PDV + 10]
        MOV DX, [_SAS_DOEND]
        MOV BX, [_SAS_DOSTEP]
        OR BX, BX
        JS _SASL_1N
        CMP AX, DX
        JG _SASL_3
        JMP _SASL_1OK
_SASL_1N:
        CMP AX, DX
        JL _SASL_3
_SASL_1OK:
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
_SASL_2:
        MOV AX, [_SAS_PDV + 10]
        ADD AX, [_SAS_DOSTEP]
        MOV [_SAS_PDV + 10], AX
        JMP _SASL_1
_SASL_3:
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
; PUT
; PUT literal: 'scores{'
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 7
        LEA DX, _SASK_7
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
        LEA DX, _SASK_8
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
_SASL_5:
        MOV AX, [_SAS_PDV + 10]
        ADD AX, [_SAS_DOSTEP]
        MOV [_SAS_PDV + 10], AX
        JMP _SASL_4
_SASL_6:
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
_SASL_9:
        MOV AX, [_SAS_PDV + 10]
        MOV DX, [_SAS_DOEND]
        MOV BX, [_SAS_DOSTEP]
        OR BX, BX
        JS _SASL_9N
        CMP AX, DX
        JG _SASL_11
        JMP _SASL_9OK
_SASL_9N:
        CMP AX, DX
        JL _SASL_11
_SASL_9OK:
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
        JE _SASL_12
        CMP BX, 8000h
        JE _SASL_12
        ADD AX, BX
        JMP _SASL_13
_SASL_12:
        MOV AX, 8000h
_SASL_13:
; stocker TOTAL
        MOV [_SAS_PDV + 12], AX
_SASL_10:
        MOV AX, [_SAS_PDV + 10]
        ADD AX, [_SAS_DOSTEP]
        MOV [_SAS_PDV + 10], AX
        JMP _SASL_9
_SASL_11:
        POP WORD PTR [_SAS_DOSTEP]
        POP WORD PTR [_SAS_DOEND]
; PUT
; PUT literal: 'total='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 6
        LEA DX, _SASK_14
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
_SASL_15:
        MOV AX, [_SAS_PDV + 20]
        MOV DX, [_SAS_DOEND]
        MOV BX, [_SAS_DOSTEP]
        OR BX, BX
        JS _SASL_15N
        CMP AX, DX
        JG _SASL_17
        JMP _SASL_15OK
_SASL_15N:
        CMP AX, DX
        JL _SASL_17
_SASL_15OK:
; PUT
; PUT literal: 'notes{'
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 6
        LEA DX, _SASK_18
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
        LEA DX, _SASK_19
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
_SASL_16:
        MOV AX, [_SAS_PDV + 20]
        ADD AX, [_SAS_DOSTEP]
        MOV [_SAS_PDV + 20], AX
        JMP _SASL_15
_SASL_17:
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
_SASL_20:
        MOV AX, [_SAS_PDV + 32]
        MOV DX, [_SAS_DOEND]
        MOV BX, [_SAS_DOSTEP]
        OR BX, BX
        JS _SASL_20N
        CMP AX, DX
        JG _SASL_22
        JMP _SASL_20OK
_SASL_20N:
        CMP AX, DX
        JL _SASL_22
_SASL_20OK:
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
        JE _SASL_23
        CMP BX, 8000h
        JE _SASL_23
        IMUL BX
        JMP _SASL_24
_SASL_23:
        MOV AX, 8000h
_SASL_24:
        POP BX
        MOV WORD PTR [_SAS_PDV + BX], AX
_SASL_21:
        MOV AX, [_SAS_PDV + 32]
        ADD AX, [_SAS_DOSTEP]
        MOV [_SAS_PDV + 32], AX
        JMP _SASL_20
_SASL_22:
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
_SASL_25:
        MOV AX, [_SAS_PDV + 32]
        MOV DX, [_SAS_DOEND]
        MOV BX, [_SAS_DOSTEP]
        OR BX, BX
        JS _SASL_25N
        CMP AX, DX
        JG _SASL_27
        JMP _SASL_25OK
_SASL_25N:
        CMP AX, DX
        JL _SASL_27
_SASL_25OK:
; PUT
; PUT literal: 'vals{'
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 5
        LEA DX, _SASK_28
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
        LEA DX, _SASK_29
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
_SASL_26:
        MOV AX, [_SAS_PDV + 32]
        ADD AX, [_SAS_DOSTEP]
        MOV [_SAS_PDV + 32], AX
        JMP _SASL_25
_SASL_27:
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
        LEA DX, _SASK_30
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
_SASL_31:
        MOV AX, [_SAS_PDV + 52]
        MOV DX, [_SAS_DOEND]
        MOV BX, [_SAS_DOSTEP]
        OR BX, BX
        JS _SASL_31N
        CMP AX, DX
        JG _SASL_33
        JMP _SASL_31OK
_SASL_31N:
        CMP AX, DX
        JL _SASL_33
_SASL_31OK:
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
_SASL_34:
        MOV AX, [_SAS_PDV + 54]
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
; charger C
        MOV AX, [_SAS_PDV + 54]
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
        JE _SASL_37
        CMP BX, 8000h
        JE _SASL_37
        IMUL BX
        JMP _SASL_38
_SASL_37:
        MOV AX, 8000h
_SASL_38:
        PUSH AX
; charger C
        MOV AX, [_SAS_PDV + 54]
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_39
        CMP BX, 8000h
        JE _SASL_39
        ADD AX, BX
        JMP _SASL_40
_SASL_39:
        MOV AX, 8000h
_SASL_40:
        POP BX
        MOV WORD PTR [_SAS_PDV + BX], AX
_SASL_35:
        MOV AX, [_SAS_PDV + 54]
        ADD AX, [_SAS_DOSTEP]
        MOV [_SAS_PDV + 54], AX
        JMP _SASL_34
_SASL_36:
        POP WORD PTR [_SAS_DOSTEP]
        POP WORD PTR [_SAS_DOEND]
_SASL_32:
        MOV AX, [_SAS_PDV + 52]
        ADD AX, [_SAS_DOSTEP]
        MOV [_SAS_PDV + 52], AX
        JMP _SASL_31
_SASL_33:
        POP WORD PTR [_SAS_DOSTEP]
        POP WORD PTR [_SAS_DOEND]
; PUT
; PUT literal: 'mat{1}='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 7
        LEA DX, _SASK_41
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
        LEA DX, _SASK_42
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
; RUN

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
_SASK_7  DB  'scores{',0
_SASK_8  DB  '}=',0
_SASK_14  DB  'total=',0
_SASK_18  DB  'notes{',0
_SASK_19  DB  '}=',0
_SASK_28  DB  'vals{',0
_SASK_29  DB  '}=',0
_SASK_30  DB  'tmp{2}=',0
_SASK_41  DB  'mat{1}=',0
_SASK_42  DB  ' mat{6}=',0

_DATA ENDS

END _SASP_Main
