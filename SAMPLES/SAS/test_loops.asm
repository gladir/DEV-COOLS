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

; DATA
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
        JE _SASL_1
        CMP BX, 8000h
        JE _SASL_1
        ADD AX, BX
        JMP _SASL_2
_SASL_1:
        MOV AX, 8000h
_SASL_2:
; stocker X
        MOV [_SAS_PDV], AX
; PUT
; PUT literal: 'bloc simple : x='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 16
        LEA DX, _SASK_3
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
_SASL_4:
; charger I
        MOV AX, [_SAS_PDV + 2]
        PUSH AX
        MOV AX, 5
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_6
        CMP BX, 8000h
        JE _SASL_6
        CMP AX, BX
        JLE _SASL_8
        XOR AX, AX
        JMP _SASL_9
_SASL_8:
        MOV AX, 1
_SASL_9:
        JMP _SASL_7
_SASL_6:
        MOV AX, 8000h
_SASL_7:
        TEST AX, AX
        JZ _SASL_5
; PUT
; PUT literal: 'while : i='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 10
        LEA DX, _SASK_10
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
        JE _SASL_11
        CMP BX, 8000h
        JE _SASL_11
        ADD AX, BX
        JMP _SASL_12
_SASL_11:
        MOV AX, 8000h
_SASL_12:
; stocker I
        MOV [_SAS_PDV + 2], AX
        JMP _SASL_4
_SASL_5:
        MOV AX, 1
; stocker J
        MOV [_SAS_PDV + 4], AX
; DO UNTIL
        JMP _SASL_14
_SASL_13:
; charger J
        MOV AX, [_SAS_PDV + 4]
        PUSH AX
        MOV AX, 5
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_16
        CMP BX, 8000h
        JE _SASL_16
        CMP AX, BX
        JG _SASL_18
        XOR AX, AX
        JMP _SASL_19
_SASL_18:
        MOV AX, 1
_SASL_19:
        JMP _SASL_17
_SASL_16:
        MOV AX, 8000h
_SASL_17:
        TEST AX, AX
        JNZ _SASL_15
_SASL_14:
; PUT
; PUT literal: 'until : j='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 10
        LEA DX, _SASK_20
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
        JE _SASL_21
        CMP BX, 8000h
        JE _SASL_21
        ADD AX, BX
        JMP _SASL_22
_SASL_21:
        MOV AX, 8000h
_SASL_22:
; stocker J
        MOV [_SAS_PDV + 4], AX
        JMP _SASL_13
_SASL_15:
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
_SASL_23:
        MOV AX, [_SAS_PDV + 6]
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
; PUT
; PUT literal: 'iter : k='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 9
        LEA DX, _SASK_26
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
_SASL_24:
        MOV AX, [_SAS_PDV + 6]
        ADD AX, [_SAS_DOSTEP]
        MOV [_SAS_PDV + 6], AX
        JMP _SASL_23
_SASL_25:
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
_SASL_27:
        MOV AX, [_SAS_PDV + 8]
        MOV DX, [_SAS_DOEND]
        MOV BX, [_SAS_DOSTEP]
        OR BX, BX
        JS _SASL_27N
        CMP AX, DX
        JG _SASL_29
        JMP _SASL_27OK
_SASL_27N:
        CMP AX, DX
        JL _SASL_29
_SASL_27OK:
; PUT
; PUT literal: 'by2 : m='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 8
        LEA DX, _SASK_30
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
_SASL_28:
        MOV AX, [_SAS_PDV + 8]
        ADD AX, [_SAS_DOSTEP]
        MOV [_SAS_PDV + 8], AX
        JMP _SASL_27
_SASL_29:
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
_SASL_31:
        MOV AX, [_SAS_PDV + 10]
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
; PUT
; PUT literal: 'rev : n='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 8
        LEA DX, _SASK_34
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
_SASL_32:
        MOV AX, [_SAS_PDV + 10]
        ADD AX, [_SAS_DOSTEP]
        MOV [_SAS_PDV + 10], AX
        JMP _SASL_31
_SASL_33:
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
_SASL_35:
        MOV AX, [_SAS_PDV + 12]
        MOV DX, [_SAS_DOEND]
        MOV BX, [_SAS_DOSTEP]
        OR BX, BX
        JS _SASL_35N
        CMP AX, DX
        JG _SASL_37
        JMP _SASL_35OK
_SASL_35N:
        CMP AX, DX
        JL _SASL_37
_SASL_35OK:
; IF
; charger P
        MOV AX, [_SAS_PDV + 12]
        PUSH AX
        MOV AX, 3
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_38
        CMP BX, 8000h
        JE _SASL_38
        CMP AX, BX
        JG _SASL_40
        XOR AX, AX
        JMP _SASL_41
_SASL_40:
        MOV AX, 1
_SASL_41:
        JMP _SASL_39
_SASL_38:
        MOV AX, 8000h
_SASL_39:
        TEST AX, AX
        JZ _SASL_42
; LEAVE
        JMP _SASL_37
_SASL_42:
; PUT
; PUT literal: 'leave : p='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 10
        LEA DX, _SASK_44
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
_SASL_36:
        MOV AX, [_SAS_PDV + 12]
        ADD AX, [_SAS_DOSTEP]
        MOV [_SAS_PDV + 12], AX
        JMP _SASL_35
_SASL_37:
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
_SASL_45:
        MOV AX, [_SAS_PDV + 14]
        MOV DX, [_SAS_DOEND]
        MOV BX, [_SAS_DOSTEP]
        OR BX, BX
        JS _SASL_45N
        CMP AX, DX
        JG _SASL_47
        JMP _SASL_45OK
_SASL_45N:
        CMP AX, DX
        JL _SASL_47
_SASL_45OK:
; IF
; charger Q
        MOV AX, [_SAS_PDV + 14]
        PUSH AX
        MOV AX, 3
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_48
        CMP BX, 8000h
        JE _SASL_48
        CMP AX, BX
        JE _SASL_50
        XOR AX, AX
        JMP _SASL_51
_SASL_50:
        MOV AX, 1
_SASL_51:
        JMP _SASL_49
_SASL_48:
        MOV AX, 8000h
_SASL_49:
        TEST AX, AX
        JZ _SASL_52
; CONTINUE
        JMP _SASL_46
_SASL_52:
; PUT
; PUT literal: 'cont : q='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 9
        LEA DX, _SASK_54
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
_SASL_46:
        MOV AX, [_SAS_PDV + 14]
        ADD AX, [_SAS_DOSTEP]
        MOV [_SAS_PDV + 14], AX
        JMP _SASL_45
_SASL_47:
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
        LEA DX, _SASK_55
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
_SASL_56:
        MOV AX, [_SAS_PDV + 20]
        MOV DX, [_SAS_DOEND]
        MOV BX, [_SAS_DOSTEP]
        OR BX, BX
        JS _SASL_56N
        CMP AX, DX
        JG _SASL_58
        JMP _SASL_56OK
_SASL_56N:
        CMP AX, DX
        JL _SASL_58
_SASL_56OK:
; charger S
        MOV AX, [_SAS_PDV + 18]
        PUSH AX
        MOV AX, 15
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_59
        CMP BX, 8000h
        JE _SASL_59
        CMP AX, BX
        JL _SASL_61
        XOR AX, AX
        JMP _SASL_62
_SASL_61:
        MOV AX, 1
_SASL_62:
        JMP _SASL_60
_SASL_59:
        MOV AX, 8000h
_SASL_60:
        TEST AX, AX
        JZ _SASL_58
; charger S
        MOV AX, [_SAS_PDV + 18]
        PUSH AX
; charger T
        MOV AX, [_SAS_PDV + 20]
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_63
        CMP BX, 8000h
        JE _SASL_63
        ADD AX, BX
        JMP _SASL_64
_SASL_63:
        MOV AX, 8000h
_SASL_64:
; stocker S
        MOV [_SAS_PDV + 18], AX
; PUT
; PUT literal: 'itwhile : t='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 12
        LEA DX, _SASK_65
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
        LEA DX, _SASK_66
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
_SASL_57:
        MOV AX, [_SAS_PDV + 20]
        ADD AX, [_SAS_DOSTEP]
        MOV [_SAS_PDV + 20], AX
        JMP _SASL_56
_SASL_58:
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
_SASL_67:
        MOV AX, [_SAS_PDV + 22]
        MOV DX, [_SAS_DOEND]
        MOV BX, [_SAS_DOSTEP]
        OR BX, BX
        JS _SASL_67N
        CMP AX, DX
        JG _SASL_69
        JMP _SASL_67OK
_SASL_67N:
        CMP AX, DX
        JL _SASL_69
_SASL_67OK:
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
_SASL_70:
        MOV AX, [_SAS_PDV + 24]
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
; PUT
; PUT literal: 'imbr : a='
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 9
        LEA DX, _SASK_73
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
        LEA DX, _SASK_74
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
_SASL_71:
        MOV AX, [_SAS_PDV + 24]
        ADD AX, [_SAS_DOSTEP]
        MOV [_SAS_PDV + 24], AX
        JMP _SASL_70
_SASL_72:
        POP WORD PTR [_SAS_DOSTEP]
        POP WORD PTR [_SAS_DOEND]
_SASL_68:
        MOV AX, [_SAS_PDV + 22]
        ADD AX, [_SAS_DOSTEP]
        MOV [_SAS_PDV + 22], AX
        JMP _SASL_67
_SASL_69:
        POP WORD PTR [_SAS_DOSTEP]
        POP WORD PTR [_SAS_DOEND]
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
_SASK_3  DB  'bloc simple : x=',0
_SASK_10  DB  'while : i=',0
_SASK_20  DB  'until : j=',0
_SASK_26  DB  'iter : k=',0
_SASK_30  DB  'by2 : m=',0
_SASK_34  DB  'rev : n=',0
_SASK_44  DB  'leave : p=',0
_SASK_54  DB  'cont : q=',0
_SASK_55  DB  'goto : r=',0
_SASK_65  DB  'itwhile : t=',0
_SASK_66  DB  ' s=',0
_SASK_73  DB  'imbr : a=',0
_SASK_74  DB  ' b=',0

_DATA ENDS

END _SASP_Main
