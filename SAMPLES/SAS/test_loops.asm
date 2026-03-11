; SAS86 v1.0 - SAMPLES/SAS/test_loops.sas
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
        MOV AX, 10
; stocker X
        MOV [_SAS_PDV], AX
; DO (bloc)
; charger X
        MOV AX, [_SAS_PDV]
        PUSH AX
        MOV AX, 1
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
; stocker X
        MOV [_SAS_PDV], AX
; PUT
; PUT literal: 'bloc simple : x='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 16
        LEA DX, _SASK_6
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
        MOV AX, 1
; stocker I
        MOV [_SAS_PDV + 2], AX
; DO WHILE
_SASL_7:
; charger I
        MOV AX, [_SAS_PDV + 2]
        PUSH AX
        MOV AX, 5
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_9
        CMP BX, 8000h
        JE _SASL_9
        CMP AX, BX
        JLE _SASL_11
        XOR AX, AX
        JMP _SASL_12
_SASL_11:
        MOV AX, 1
_SASL_12:
        JMP _SASL_10
_SASL_9:
        MOV AX, 8000h
_SASL_10:
        TEST AX, AX
        JZ _SASL_8
; PUT
; PUT literal: 'while : i='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 10
        LEA DX, _SASK_13
        INT 21h
; PUT I
; charger I
        MOV AX, [_SAS_PDV + 2]
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
; charger I
        MOV AX, [_SAS_PDV + 2]
        PUSH AX
        MOV AX, 1
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_14
        CMP BX, 8000h
        JE _SASL_14
        ADD AX, BX
        JMP _SASL_15
_SASL_14:
        MOV AX, 8000h
_SASL_15:
; stocker I
        MOV [_SAS_PDV + 2], AX
        JMP _SASL_7
_SASL_8:
        MOV AX, 1
; stocker J
        MOV [_SAS_PDV + 4], AX
; DO UNTIL
        JMP _SASL_17
_SASL_16:
; charger J
        MOV AX, [_SAS_PDV + 4]
        PUSH AX
        MOV AX, 5
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_19
        CMP BX, 8000h
        JE _SASL_19
        CMP AX, BX
        JG _SASL_21
        XOR AX, AX
        JMP _SASL_22
_SASL_21:
        MOV AX, 1
_SASL_22:
        JMP _SASL_20
_SASL_19:
        MOV AX, 8000h
_SASL_20:
        TEST AX, AX
        JNZ _SASL_18
_SASL_17:
; PUT
; PUT literal: 'until : j='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 10
        LEA DX, _SASK_23
        INT 21h
; PUT J
; charger J
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
; charger J
        MOV AX, [_SAS_PDV + 4]
        PUSH AX
        MOV AX, 1
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_24
        CMP BX, 8000h
        JE _SASL_24
        ADD AX, BX
        JMP _SASL_25
_SASL_24:
        MOV AX, 8000h
_SASL_25:
; stocker J
        MOV [_SAS_PDV + 4], AX
        JMP _SASL_16
_SASL_18:
; DO K = ... TO ...
        MOV AX, 1
        MOV [_SAS_PDV + 6], AX
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
_SASL_26:
        MOV AX, [_SAS_PDV + 6]
        MOV DX, [_SAS_DOEND]
        MOV BX, [_SAS_DOSTEP]
        OR BX, BX
        JS _SASL_26N
        CMP AX, DX
        JG _SASL_28
        JMP _SASL_26OK
_SASL_26N:
        CMP AX, DX
        JL _SASL_28
_SASL_26OK:
; PUT
; PUT literal: 'iter : k='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 9
        LEA DX, _SASK_29
        INT 21h
; PUT K
; charger K
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
_SASL_27:
        MOV AX, [_SAS_PDV + 6]
        ADD AX, [_SAS_DOSTEP]
        MOV [_SAS_PDV + 6], AX
        JMP _SASL_26
_SASL_28:
        POP WORD PTR [_SAS_DOSTEP]
        POP WORD PTR [_SAS_DOEND]
; DO M = ... TO ...
        XOR AX, AX
        MOV [_SAS_PDV + 8], AX
        MOV AX, 10
        PUSH AX
        MOV AX, 2
        PUSH AX
        PUSH WORD PTR [_SAS_DOEND]
        PUSH WORD PTR [_SAS_DOSTEP]
        POP BX
        MOV [_SAS_DOSTEP], BX
        POP DX
        MOV [_SAS_DOEND], DX
_SASL_30:
        MOV AX, [_SAS_PDV + 8]
        MOV DX, [_SAS_DOEND]
        MOV BX, [_SAS_DOSTEP]
        OR BX, BX
        JS _SASL_30N
        CMP AX, DX
        JG _SASL_32
        JMP _SASL_30OK
_SASL_30N:
        CMP AX, DX
        JL _SASL_32
_SASL_30OK:
; PUT
; PUT literal: 'by2 : m='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 8
        LEA DX, _SASK_33
        INT 21h
; PUT M
; charger M
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
_SASL_31:
        MOV AX, [_SAS_PDV + 8]
        ADD AX, [_SAS_DOSTEP]
        MOV [_SAS_PDV + 8], AX
        JMP _SASL_30
_SASL_32:
        POP WORD PTR [_SAS_DOSTEP]
        POP WORD PTR [_SAS_DOEND]
; DO N = ... TO ...
        MOV AX, 10
        MOV [_SAS_PDV + 10], AX
        MOV AX, 1
        PUSH AX
        MOV AX, -1
        PUSH AX
        PUSH WORD PTR [_SAS_DOEND]
        PUSH WORD PTR [_SAS_DOSTEP]
        POP BX
        MOV [_SAS_DOSTEP], BX
        POP DX
        MOV [_SAS_DOEND], DX
_SASL_34:
        MOV AX, [_SAS_PDV + 10]
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
; PUT
; PUT literal: 'rev : n='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 8
        LEA DX, _SASK_37
        INT 21h
; PUT N
; charger N
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
_SASL_35:
        MOV AX, [_SAS_PDV + 10]
        ADD AX, [_SAS_DOSTEP]
        MOV [_SAS_PDV + 10], AX
        JMP _SASL_34
_SASL_36:
        POP WORD PTR [_SAS_DOSTEP]
        POP WORD PTR [_SAS_DOEND]
; DO P = ... TO ...
        MOV AX, 1
        MOV [_SAS_PDV + 12], AX
        MOV AX, 100
        PUSH AX
        MOV AX, 1
        PUSH AX
        PUSH WORD PTR [_SAS_DOEND]
        PUSH WORD PTR [_SAS_DOSTEP]
        POP BX
        MOV [_SAS_DOSTEP], BX
        POP DX
        MOV [_SAS_DOEND], DX
_SASL_38:
        MOV AX, [_SAS_PDV + 12]
        MOV DX, [_SAS_DOEND]
        MOV BX, [_SAS_DOSTEP]
        OR BX, BX
        JS _SASL_38N
        CMP AX, DX
        JG _SASL_40
        JMP _SASL_38OK
_SASL_38N:
        CMP AX, DX
        JL _SASL_40
_SASL_38OK:
; IF
; charger P
        MOV AX, [_SAS_PDV + 12]
        PUSH AX
        MOV AX, 3
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_41
        CMP BX, 8000h
        JE _SASL_41
        CMP AX, BX
        JG _SASL_43
        XOR AX, AX
        JMP _SASL_44
_SASL_43:
        MOV AX, 1
_SASL_44:
        JMP _SASL_42
_SASL_41:
        MOV AX, 8000h
_SASL_42:
        TEST AX, AX
        JZ _SASL_45
; LEAVE
        JMP _SASL_40
_SASL_45:
; PUT
; PUT literal: 'leave : p='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 10
        LEA DX, _SASK_47
        INT 21h
; PUT P
; charger P
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
_SASL_39:
        MOV AX, [_SAS_PDV + 12]
        ADD AX, [_SAS_DOSTEP]
        MOV [_SAS_PDV + 12], AX
        JMP _SASL_38
_SASL_40:
        POP WORD PTR [_SAS_DOSTEP]
        POP WORD PTR [_SAS_DOEND]
; DO Q = ... TO ...
        MOV AX, 1
        MOV [_SAS_PDV + 14], AX
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
_SASL_48:
        MOV AX, [_SAS_PDV + 14]
        MOV DX, [_SAS_DOEND]
        MOV BX, [_SAS_DOSTEP]
        OR BX, BX
        JS _SASL_48N
        CMP AX, DX
        JG _SASL_50
        JMP _SASL_48OK
_SASL_48N:
        CMP AX, DX
        JL _SASL_50
_SASL_48OK:
; IF
; charger Q
        MOV AX, [_SAS_PDV + 14]
        PUSH AX
        MOV AX, 3
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_51
        CMP BX, 8000h
        JE _SASL_51
        CMP AX, BX
        JE _SASL_53
        XOR AX, AX
        JMP _SASL_54
_SASL_53:
        MOV AX, 1
_SASL_54:
        JMP _SASL_52
_SASL_51:
        MOV AX, 8000h
_SASL_52:
        TEST AX, AX
        JZ _SASL_55
; CONTINUE
        JMP _SASL_49
_SASL_55:
; PUT
; PUT literal: 'cont : q='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 9
        LEA DX, _SASK_57
        INT 21h
; PUT Q
; charger Q
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
        MOV AX, [_SAS_PDV + 14]
        ADD AX, [_SAS_DOSTEP]
        MOV [_SAS_PDV + 14], AX
        JMP _SASL_48
_SASL_50:
        POP WORD PTR [_SAS_DOSTEP]
        POP WORD PTR [_SAS_DOEND]
        XOR AX, AX
; stocker R
        MOV [_SAS_PDV + 16], AX
; GOTO
        JMP _SASL_SKIP
        MOV AX, 999
; stocker R
        MOV [_SAS_PDV + 16], AX
_SASL_SKIP:
; PUT
; PUT literal: 'goto : r='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 9
        LEA DX, _SASK_58
        INT 21h
; PUT R
; charger R
        MOV AX, [_SAS_PDV + 16]
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
        XOR AX, AX
; stocker S
        MOV [_SAS_PDV + 18], AX
; DO T = ... TO ...
        MOV AX, 1
        MOV [_SAS_PDV + 20], AX
        MOV AX, 10
        PUSH AX
        MOV AX, 1
        PUSH AX
        PUSH WORD PTR [_SAS_DOEND]
        PUSH WORD PTR [_SAS_DOSTEP]
        POP BX
        MOV [_SAS_DOSTEP], BX
        POP DX
        MOV [_SAS_DOEND], DX
_SASL_59:
        MOV AX, [_SAS_PDV + 20]
        MOV DX, [_SAS_DOEND]
        MOV BX, [_SAS_DOSTEP]
        OR BX, BX
        JS _SASL_59N
        CMP AX, DX
        JG _SASL_61
        JMP _SASL_59OK
_SASL_59N:
        CMP AX, DX
        JL _SASL_61
_SASL_59OK:
; charger S
        MOV AX, [_SAS_PDV + 18]
        PUSH AX
        MOV AX, 15
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_62
        CMP BX, 8000h
        JE _SASL_62
        CMP AX, BX
        JL _SASL_64
        XOR AX, AX
        JMP _SASL_65
_SASL_64:
        MOV AX, 1
_SASL_65:
        JMP _SASL_63
_SASL_62:
        MOV AX, 8000h
_SASL_63:
        TEST AX, AX
        JZ _SASL_61
; charger S
        MOV AX, [_SAS_PDV + 18]
        PUSH AX
; charger T
        MOV AX, [_SAS_PDV + 20]
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_66
        CMP BX, 8000h
        JE _SASL_66
        ADD AX, BX
        JMP _SASL_67
_SASL_66:
        MOV AX, 8000h
_SASL_67:
; stocker S
        MOV [_SAS_PDV + 18], AX
; PUT
; PUT literal: 'itwhile : t='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 12
        LEA DX, _SASK_68
        INT 21h
; PUT T
; charger T
        MOV AX, [_SAS_PDV + 20]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; PUT literal: ' s='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 3
        LEA DX, _SASK_69
        INT 21h
; PUT S
; charger S
        MOV AX, [_SAS_PDV + 18]
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
_SASL_60:
        MOV AX, [_SAS_PDV + 20]
        ADD AX, [_SAS_DOSTEP]
        MOV [_SAS_PDV + 20], AX
        JMP _SASL_59
_SASL_61:
        POP WORD PTR [_SAS_DOSTEP]
        POP WORD PTR [_SAS_DOEND]
; DO A = ... TO ...
        MOV AX, 1
        MOV [_SAS_PDV + 22], AX
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
_SASL_70:
        MOV AX, [_SAS_PDV + 22]
        MOV DX, [_SAS_DOEND]
        MOV BX, [_SAS_DOSTEP]
        OR BX, BX
        JS _SASL_70N
        CMP AX, DX
        JG _SASL_72
        JMP _SASL_70OK
_SASL_70N:
        CMP AX, DX
        JL _SASL_72
_SASL_70OK:
; DO B = ... TO ...
        MOV AX, 1
        MOV [_SAS_PDV + 24], AX
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
_SASL_73:
        MOV AX, [_SAS_PDV + 24]
        MOV DX, [_SAS_DOEND]
        MOV BX, [_SAS_DOSTEP]
        OR BX, BX
        JS _SASL_73N
        CMP AX, DX
        JG _SASL_75
        JMP _SASL_73OK
_SASL_73N:
        CMP AX, DX
        JL _SASL_75
_SASL_73OK:
; PUT
; PUT literal: 'imbr : a='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 9
        LEA DX, _SASK_76
        INT 21h
; PUT A
; charger A
        MOV AX, [_SAS_PDV + 22]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; PUT literal: ' b='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 3
        LEA DX, _SASK_77
        INT 21h
; PUT B
; charger B
        MOV AX, [_SAS_PDV + 24]
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
_SASL_74:
        MOV AX, [_SAS_PDV + 24]
        ADD AX, [_SAS_DOSTEP]
        MOV [_SAS_PDV + 24], AX
        JMP _SASL_73
_SASL_75:
        POP WORD PTR [_SAS_DOSTEP]
        POP WORD PTR [_SAS_DOEND]
_SASL_71:
        MOV AX, [_SAS_PDV + 22]
        ADD AX, [_SAS_DOSTEP]
        MOV [_SAS_PDV + 22], AX
        JMP _SASL_70
_SASL_72:
        POP WORD PTR [_SAS_DOSTEP]
        POP WORD PTR [_SAS_DOEND]
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
_SASK_6  DB  'bloc simple : x=',0
_SASK_13  DB  'while : i=',0
_SASK_23  DB  'until : j=',0
_SASK_29  DB  'iter : k=',0
_SASK_33  DB  'by2 : m=',0
_SASK_37  DB  'rev : n=',0
_SASK_47  DB  'leave : p=',0
_SASK_57  DB  'cont : q=',0
_SASK_58  DB  'goto : r=',0
_SASK_68  DB  'itwhile : t=',0
_SASK_69  DB  ' s=',0
_SASK_76  DB  'imbr : a=',0
_SASK_77  DB  ' b=',0

_DATA ENDS

END _SASP_Main
