; SAS86 v1.0 - SAMPLES/SAS/test_if_select.sas
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
        MOV AX, 42
; stocker X
        MOV [_SAS_PDV], AX
        MOV AX, 10
; stocker Y
        MOV [_SAS_PDV + 2], AX
; IF
; charger X
        MOV AX, [_SAS_PDV]
        PUSH AX
        XOR AX, AX
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_4
        CMP BX, 8000h
        JE _SASL_4
        CMP AX, BX
        JG _SASL_6
        XOR AX, AX
        JMP _SASL_7
_SASL_6:
        MOV AX, 1
_SASL_7:
        JMP _SASL_5
_SASL_4:
        MOV AX, 8000h
_SASL_5:
        TEST AX, AX
        JZ _SASL_8
; PUT
; PUT literal: 'x est positif'
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 13
        LEA DX, _SASK_10
        INT 21h
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_8:
; IF
; charger Y
        MOV AX, [_SAS_PDV + 2]
        PUSH AX
        MOV AX, 20
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_11
        CMP BX, 8000h
        JE _SASL_11
        CMP AX, BX
        JG _SASL_13
        XOR AX, AX
        JMP _SASL_14
_SASL_13:
        MOV AX, 1
_SASL_14:
        JMP _SASL_12
_SASL_11:
        MOV AX, 8000h
_SASL_12:
        TEST AX, AX
        JZ _SASL_15
; PUT
; PUT literal: 'y grand'
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 7
        LEA DX, _SASK_17
        INT 21h
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
        JMP _SASL_16
_SASL_15:
; PUT
; PUT literal: 'y petit'
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 7
        LEA DX, _SASK_18
        INT 21h
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_16:
; IF
; charger X
        MOV AX, [_SAS_PDV]
        PUSH AX
        MOV AX, 42
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_19
        CMP BX, 8000h
        JE _SASL_19
        CMP AX, BX
        JE _SASL_21
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
        JZ _SASL_23
; PUT
; PUT literal: 'x vaut 42'
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 9
        LEA DX, _SASK_25
        INT 21h
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
; PUT
; PUT literal: 'reponse!'
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 8
        LEA DX, _SASK_26
        INT 21h
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_23:
; IF
; charger X
        MOV AX, [_SAS_PDV]
        PUSH AX
        XOR AX, AX
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_27
        CMP BX, 8000h
        JE _SASL_27
        CMP AX, BX
        JL _SASL_29
        XOR AX, AX
        JMP _SASL_30
_SASL_29:
        MOV AX, 1
_SASL_30:
        JMP _SASL_28
_SASL_27:
        MOV AX, 8000h
_SASL_28:
        TEST AX, AX
        JZ _SASL_31
; PUT
; PUT literal: 'negatif'
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 7
        LEA DX, _SASK_33
        INT 21h
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
        JMP _SASL_32
_SASL_31:
; IF
; charger X
        MOV AX, [_SAS_PDV]
        PUSH AX
        XOR AX, AX
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_34
        CMP BX, 8000h
        JE _SASL_34
        CMP AX, BX
        JE _SASL_36
        XOR AX, AX
        JMP _SASL_37
_SASL_36:
        MOV AX, 1
_SASL_37:
        JMP _SASL_35
_SASL_34:
        MOV AX, 8000h
_SASL_35:
        TEST AX, AX
        JZ _SASL_38
; PUT
; PUT literal: 'zero'
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 4
        LEA DX, _SASK_40
        INT 21h
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
        JMP _SASL_39
_SASL_38:
; PUT
; PUT literal: 'positif'
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 7
        LEA DX, _SASK_41
        INT 21h
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_39:
_SASL_32:
; IF
; charger Y
        MOV AX, [_SAS_PDV + 2]
        PUSH AX
        MOV AX, 100
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_42
        CMP BX, 8000h
        JE _SASL_42
        CMP AX, BX
        JG _SASL_44
        XOR AX, AX
        JMP _SASL_45
_SASL_44:
        MOV AX, 1
_SASL_45:
        JMP _SASL_43
_SASL_42:
        MOV AX, 8000h
_SASL_43:
        TEST AX, AX
        JZ _SASL_46
; PUT
; PUT literal: 'y tres grand'
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 12
        LEA DX, _SASK_48
        INT 21h
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
        JMP _SASL_47
_SASL_46:
; PUT
; PUT literal: 'y raisonnable'
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 13
        LEA DX, _SASK_49
        INT 21h
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_47:
        MOV AX, 2
; stocker Z
        MOV [_SAS_PDV + 4], AX
; SELECT
; charger Z
        MOV AX, [_SAS_PDV + 4]
        MOV DX, AX
; WHEN
        MOV AX, 1
        CMP DX, AX
        JE _SASL_52
        JMP _SASL_51
_SASL_52:
; PUT
; PUT literal: 'un'
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SASK_53
        INT 21h
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
        JMP _SASL_50
_SASL_51:
; WHEN
        MOV AX, 2
        CMP DX, AX
        JE _SASL_55
        JMP _SASL_54
_SASL_55:
; PUT
; PUT literal: 'deux'
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 4
        LEA DX, _SASK_56
        INT 21h
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
        JMP _SASL_50
_SASL_54:
; WHEN
        MOV AX, 3
        CMP DX, AX
        JE _SASL_58
        JMP _SASL_57
_SASL_58:
; PUT
; PUT literal: 'trois'
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 5
        LEA DX, _SASK_59
        INT 21h
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
        JMP _SASL_50
_SASL_57:
; OTHERWISE
; PUT
; PUT literal: 'autre'
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 5
        LEA DX, _SASK_60
        INT 21h
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_50:
; SELECT
; WHEN
; charger X
        MOV AX, [_SAS_PDV]
        PUSH AX
        MOV AX, 100
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_63
        CMP BX, 8000h
        JE _SASL_63
        CMP AX, BX
        JG _SASL_65
        XOR AX, AX
        JMP _SASL_66
_SASL_65:
        MOV AX, 1
_SASL_66:
        JMP _SASL_64
_SASL_63:
        MOV AX, 8000h
_SASL_64:
        TEST AX, AX
        JZ _SASL_62
; PUT
; PUT literal: 'x > 100'
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 7
        LEA DX, _SASK_67
        INT 21h
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
        JMP _SASL_61
_SASL_62:
; WHEN
; charger X
        MOV AX, [_SAS_PDV]
        PUSH AX
        MOV AX, 50
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_69
        CMP BX, 8000h
        JE _SASL_69
        CMP AX, BX
        JG _SASL_71
        XOR AX, AX
        JMP _SASL_72
_SASL_71:
        MOV AX, 1
_SASL_72:
        JMP _SASL_70
_SASL_69:
        MOV AX, 8000h
_SASL_70:
        TEST AX, AX
        JZ _SASL_68
; PUT
; PUT literal: 'x > 50'
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 6
        LEA DX, _SASK_73
        INT 21h
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
        JMP _SASL_61
_SASL_68:
; WHEN
; charger X
        MOV AX, [_SAS_PDV]
        PUSH AX
        XOR AX, AX
        MOV BX, AX
        POP AX
        CMP AX, 8000h
        JE _SASL_75
        CMP BX, 8000h
        JE _SASL_75
        CMP AX, BX
        JG _SASL_77
        XOR AX, AX
        JMP _SASL_78
_SASL_77:
        MOV AX, 1
_SASL_78:
        JMP _SASL_76
_SASL_75:
        MOV AX, 8000h
_SASL_76:
        TEST AX, AX
        JZ _SASL_74
; PUT
; PUT literal: 'x > 0'
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 5
        LEA DX, _SASK_79
        INT 21h
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
        JMP _SASL_61
_SASL_74:
; OTHERWISE
; PUT
; PUT literal: 'x <= 0'
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 6
        LEA DX, _SASK_80
        INT 21h
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_61:
        MOV AX, 5
; stocker W
        MOV [_SAS_PDV + 6], AX
; SELECT
; charger W
        MOV AX, [_SAS_PDV + 6]
        MOV DX, AX
; WHEN
        MOV AX, 1
        CMP DX, AX
        JE _SASL_83
        MOV AX, 2
        CMP DX, AX
        JE _SASL_83
        MOV AX, 3
        CMP DX, AX
        JE _SASL_83
        JMP _SASL_82
_SASL_83:
; PUT
; PUT literal: 'petit'
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 5
        LEA DX, _SASK_84
        INT 21h
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
        JMP _SASL_81
_SASL_82:
; WHEN
        MOV AX, 4
        CMP DX, AX
        JE _SASL_86
        MOV AX, 5
        CMP DX, AX
        JE _SASL_86
        MOV AX, 6
        CMP DX, AX
        JE _SASL_86
        JMP _SASL_85
_SASL_86:
; PUT
; PUT literal: 'moyen'
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 5
        LEA DX, _SASK_87
        INT 21h
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
        JMP _SASL_81
_SASL_85:
; OTHERWISE
; PUT
; PUT literal: 'grand'
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 5
        LEA DX, _SASK_88
        INT 21h
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_81:
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
_SASK_10  DB  'x est positif',0
_SASK_17  DB  'y grand',0
_SASK_18  DB  'y petit',0
_SASK_25  DB  'x vaut 42',0
_SASK_26  DB  'reponse!',0
_SASK_33  DB  'negatif',0
_SASK_40  DB  'zero',0
_SASK_41  DB  'positif',0
_SASK_48  DB  'y tres grand',0
_SASK_49  DB  'y raisonnable',0
_SASK_53  DB  'un',0
_SASK_56  DB  'deux',0
_SASK_59  DB  'trois',0
_SASK_60  DB  'autre',0
_SASK_67  DB  'x > 100',0
_SASK_73  DB  'x > 50',0
_SASK_79  DB  'x > 0',0
_SASK_80  DB  'x <= 0',0
_SASK_84  DB  'petit',0
_SASK_87  DB  'moyen',0
_SASK_88  DB  'grand',0

_DATA ENDS

END _SASP_Main
