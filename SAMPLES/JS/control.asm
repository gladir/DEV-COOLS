; Genere par JS86 v1.0 - SAMPLES\JS\control.js

        .MODEL SMALL
        .STACK 1024

_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME  CS:_TEXT, DS:_DATA, SS:STACK

_JSF_main:
; --- initialisation segment de donnees ---
        MOV   AX, _DATA
        MOV   DS, AX

; --- debut du code genere ---

        MOV   AX, 15
        MOV   [_JSV_x], AX
        MOV   AX, [_JSV_x]
        PUSH   AX
        MOV   AX, 20
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JLE   _JSL_2
        INC    AX
_JSL_2:
        OR   AX, AX
        JZ   _JSL_3
        LEA   AX, _JSK_4
        MOV   DI, AX
        XOR   CX, CX
_JSL_5:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_6
        INC    CX
        INC    DI
        JMP   _JSL_5
_JSL_6:
        SUB   DI, CX
        MOV   DX, DI
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        JMP   _JSL_1
_JSL_3:
        MOV   AX, [_JSV_x]
        PUSH   AX
        MOV   AX, 10
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JLE   _JSL_8
        INC    AX
_JSL_8:
        OR   AX, AX
        JZ   _JSL_9
        LEA   AX, _JSK_10
        MOV   DI, AX
        XOR   CX, CX
_JSL_11:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_12
        INC    CX
        INC    DI
        JMP   _JSL_11
_JSL_12:
        SUB   DI, CX
        MOV   DX, DI
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        JMP   _JSL_7
_JSL_9:
        LEA   AX, _JSK_13
        MOV   DI, AX
        XOR   CX, CX
_JSL_14:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_15
        INC    CX
        INC    DI
        JMP   _JSL_14
_JSL_15:
        SUB   DI, CX
        MOV   DX, DI
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
_JSL_7:
_JSL_1:
        MOV   AX, 3
        MOV   [_JSV_day], AX
        MOV   AX, [_JSV_day]
        PUSH   AX
        POP   BX
        PUSH   BX
        MOV   AX, 1
        CMP   BX, AX
        JNE   _JSL_17
        LEA   AX, _JSK_18
        MOV   DI, AX
        XOR   CX, CX
_JSL_19:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_20
        INC    CX
        INC    DI
        JMP   _JSL_19
_JSL_20:
        SUB   DI, CX
        MOV   DX, DI
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        JMP   _JSL_16
_JSL_17:
        POP   BX
        PUSH   BX
        MOV   AX, 2
        CMP   BX, AX
        JNE   _JSL_21
        LEA   AX, _JSK_22
        MOV   DI, AX
        XOR   CX, CX
_JSL_23:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_24
        INC    CX
        INC    DI
        JMP   _JSL_23
_JSL_24:
        SUB   DI, CX
        MOV   DX, DI
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        JMP   _JSL_16
_JSL_21:
        POP   BX
        PUSH   BX
        MOV   AX, 3
        CMP   BX, AX
        JNE   _JSL_25
        LEA   AX, _JSK_26
        MOV   DI, AX
        XOR   CX, CX
_JSL_27:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_28
        INC    CX
        INC    DI
        JMP   _JSL_27
_JSL_28:
        SUB   DI, CX
        MOV   DX, DI
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        JMP   _JSL_16
_JSL_25:
        LEA   AX, _JSK_29
        MOV   DI, AX
        XOR   CX, CX
_JSL_30:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_31
        INC    CX
        INC    DI
        JMP   _JSL_30
_JSL_31:
        SUB   DI, CX
        MOV   DX, DI
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        JMP   _JSL_16
_JSL_16:
        ADD   SP, 2
        MOV   AX, 0
        MOV   [_JSV_i], AX
        MOV   AX, 0
        MOV   [_JSV_total], AX
_JSL_32:
        MOV   AX, [_JSV_i]
        PUSH   AX
        MOV   AX, 5
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JGE   _JSL_34
        INC    AX
_JSL_34:
        OR   AX, AX
        JZ   _JSL_33
        MOV   AX, [_JSV_total]
        PUSH   AX
        MOV   AX, [_JSV_i]
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [_JSV_total], AX
        MOV   AX, [_JSV_i]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [_JSV_i], AX
        JMP   _JSL_32
_JSL_33:
        MOV   AX, [_JSV_total]
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_35:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_36
        INC    CX
        INC    DI
        JMP   _JSL_35
_JSL_36:
        SUB   DI, CX
        MOV   DX, DI
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        MOV   AX, 0
        MOV   [_JSV_sum], AX
        MOV   AX, 1
        MOV   [_JSV_j], AX
_JSL_37:
        MOV   AX, [_JSV_j]
        PUSH   AX
        MOV   AX, 10
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JG   _JSL_40
        INC    AX
_JSL_40:
        OR   AX, AX
        JZ   _JSL_39
        JMP   _JSL_41
_JSL_38:
        MOV   AX, [_JSV_j]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [_JSV_j], AX
        JMP   _JSL_37
_JSL_41:
        MOV   AX, [_JSV_sum]
        PUSH   AX
        MOV   AX, [_JSV_j]
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [_JSV_sum], AX
        JMP   _JSL_38
_JSL_39:
        MOV   AX, [_JSV_sum]
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_42:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_43
        INC    CX
        INC    DI
        JMP   _JSL_42
_JSL_43:
        SUB   DI, CX
        MOV   DX, DI
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        LEA   AX, _JSK_45
        MOV   [_JSA_44_E0], AX
        LEA   AX, _JSK_46
        MOV   [_JSA_44_E1], AX
        LEA   AX, _JSK_47
        MOV   [_JSA_44_E2], AX
        LEA   AX, _JSA_44
        MOV   [_JSV_fruits], AX
        MOV   AX, [_JSV_fruits]
        MOV   SI, AX
        MOV   AX, [SI]
        PUSH   AX
        PUSH   SI
        XOR   AX, AX
        MOV   [_JSV__foridx], AX
_JSL_48:
        POP   SI
        POP   CX
        PUSH   CX
        PUSH   SI
        MOV   AX, [_JSV__foridx]
        CMP   AX, CX
        JGE   _JSL_50
        SHL   AX, 1
        ADD   AX, 2
        ADD   SI, AX
        MOV   AX, [SI]
        MOV   [_JSV_f], AX
        MOV   AX, [_JSV_f]
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_51:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_52
        INC    CX
        INC    DI
        JMP   _JSL_51
_JSL_52:
        SUB   DI, CX
        MOV   DX, DI
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
_JSL_49:
        MOV   AX, [_JSV__foridx]
        INC   AX
        MOV   [_JSV__foridx], AX
        JMP   _JSL_48
_JSL_50:
        ADD   SP, 4
        MOV   AX, 1
        MOV   [_JSV_k], AX
        MOV   AX, 1
        MOV   [_JSV_product], AX
_JSL_53:
        MOV   AX, [_JSV_product]
        PUSH   AX
        MOV   AX, [_JSV_k]
        MOV   BX, AX
        POP   AX
        IMUL   BX
        MOV   [_JSV_product], AX
        MOV   AX, [_JSV_k]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [_JSV_k], AX
_JSL_54:
        MOV   AX, [_JSV_k]
        PUSH   AX
        MOV   AX, 5
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JG   _JSL_56
        INC    AX
_JSL_56:
        OR   AX, AX
        JNZ   _JSL_53
_JSL_55:
        MOV   AX, [_JSV_product]
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_57:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_58
        INC    CX
        INC    DI
        JMP   _JSL_57
_JSL_58:
        SUB   DI, CX
        MOV   DX, DI
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        MOV   AX, 18
        MOV   [_JSV_age], AX
        MOV   AX, [_JSV_age]
        PUSH   AX
        MOV   AX, 18
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JL   _JSL_59
        INC    AX
_JSL_59:
        OR   AX, AX
        JZ   _JSL_60
        LEA   AX, _JSK_62
        JMP   _JSL_61
_JSL_60:
        LEA   AX, _JSK_63
_JSL_61:
        MOV   [_JSV_status], AX
        MOV   AX, [_JSV_status]
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_64:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_65
        INC    CX
        INC    DI
        JMP   _JSL_64
_JSL_65:
        SUB   DI, CX
        MOV   DX, DI
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h

; --- sortie programme ---
        MOV   AX, 4C00h
        INT    21h

; --- runtime core routines (TODO 24) ---
_JSRT_NUMTOSTR:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        PUSH   DI
        PUSH   SI
        LEA   DI, _JSRT_NUMBUF
        ADD   DI, 11
        MOV   BYTE PTR [DI], 0
        DEC   DI
        XOR   CX, CX
        MOV   BX, AX
        OR   AX, AX
        JNS   _JSL_66
        NEG    AX
_JSL_66:
        MOV   SI, 10
_JSL_67:
        XOR   DX, DX
        DIV    SI
        ADD   DL, '0'
        MOV   [DI], DL
        DEC   DI
        INC   CX
        OR   AX, AX
        JNZ   _JSL_67
        OR   BX, BX
        JNS   _JSL_68
        MOV   BYTE PTR [DI], '-'
        DEC   DI
_JSL_68:
        INC   DI
        MOV   AX, DI
        POP   SI
        POP   DI
        POP   DX
        POP   CX
        POP   BX
        RET
_JSRT_CONCAT:
        PUSH   SI
        PUSH   DI
        PUSH   CX
        LEA   DI, _JSRT_STRBUF
        MOV   SI, AX
_JSL_69:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_70
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_69
_JSL_70:
        MOV   SI, BX
_JSL_72:
        MOV   AL, [SI]
        MOV   [DI], AL
        OR   AL, AL
        JZ   _JSL_71
        INC   SI
        INC   DI
        JMP   _JSL_72
_JSL_71:
        LEA   AX, _JSRT_STRBUF
        POP   CX
        POP   DI
        POP   SI
        RET
_JSRT_PRINT:
        MOV   AH, 40h
        INT    21h
        RET
_JSRT_PRINTLN:
        MOV   AH, 40h
        INT    21h
        PUSH   CX
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   AH, 40h
        INT    21h
        POP   CX
        RET
_JSRT_TYPEOF:
        CMP   BX, 1
        JE   _JSL_73
        CMP   BX, 2
        JE   _JSL_74
        CMP   BX, 3
        JE   _JSL_75
        CMP   BX, 7
        JE   _JSL_76
        LEA   AX, _JS_TYP_NUMBER
        RET
_JSL_73:
        LEA   AX, _JS_TYP_STRING
        RET
_JSL_74:
        LEA   AX, _JS_TYP_BOOLEAN
        RET
_JSL_75:
        LEA   AX, _JS_TYP_OBJECT
        RET
_JSL_76:
        LEA   AX, _JS_UNDEF
        RET
_JSRT_TRUTHY:
        CMP   BX, 7
        JE   _JSL_79
        CMP   BX, 6
        JE   _JSL_79
        CMP   BX, 1
        JE   _JSL_77
        OR   AX, AX
        JZ   _JSL_79
        JMP   _JSL_78
_JSL_77:
        MOV   SI, AX
        CMP   BYTE PTR [SI], 0
        JE   _JSL_79
_JSL_78:
        MOV   AX, 1
        RET
_JSL_79:
        XOR   AX, AX
        RET
_JSRT_STRTRUTHY:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_81
        CMP   BYTE PTR [SI], '0'
        JNE   _JSL_80
        CMP   BYTE PTR [SI+1], 0
        JE   _JSL_81
_JSL_80:
        MOV   AX, 1
        RET
_JSL_81:
        XOR   AX, AX
        RET
_JSRT_ALLOC:
        PUSH   BX
        MOV   BX, [_JS_HEAPTOP]
        LEA   AX, _JS_HEAP
        ADD   AX, BX
        ADD   BX, CX
        MOV   [_JS_HEAPTOP], BX
        POP   BX
        RET

; --- runtime array routines (TODO 15) ---
_JSRT_ARRPUSH:
        MOV   BX, [SI]
        MOV   DI, BX
        SHL   DI, 1
        ADD   DI, 2
        ADD   DI, SI
        MOV   [DI], AX
        INC   BX
        MOV   [SI], BX
        MOV   AX, BX
        RET
_JSRT_ARRPOP:
        MOV   BX, [SI]
        OR   BX, BX
        JZ   _JSL_82
        DEC   BX
        MOV   [SI], BX
        MOV   DI, BX
        SHL   DI, 1
        ADD   DI, 2
        ADD   DI, SI
        MOV   AX, [DI]
        RET
_JSL_82:
        XOR   AX, AX
        RET
_JSRT_ARRSHIFT:
        MOV   CX, [SI]
        OR   CX, CX
        JZ   _JSL_83
        MOV   AX, [SI+2]
        PUSH   AX
        DEC   CX
        MOV   [SI], CX
        LEA   DI, [SI+2]
        LEA   BX, [SI+4]
_JSL_84:
        OR   CX, CX
        JZ   _JSL_85
        MOV   AX, [BX]
        MOV   [DI], AX
        ADD   DI, 2
        ADD   BX, 2
        DEC   CX
        JMP   _JSL_84
_JSL_85:
        POP   AX
        RET
_JSL_83:
        XOR   AX, AX
        RET
_JSRT_ARRUNSHIFT:
        PUSH   AX
        MOV   CX, [SI]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        ADD   DI, 2
_JSL_86:
        OR   CX, CX
        JZ   _JSL_87
        MOV   AX, [DI-2]
        MOV   [DI], AX
        SUB   DI, 2
        DEC   CX
        JMP   _JSL_86
_JSL_87:
        POP   AX
        MOV   [SI+2], AX
        MOV   AX, [SI]
        INC   AX
        MOV   [SI], AX
        RET
_JSRT_ARRIDXOF:
        MOV   CX, [SI]
        ADD   SI, 2
        XOR   DX, DX
_JSL_88:
        OR   CX, CX
        JZ   _JSL_89
        CMP   [SI], BX
        JE   _JSL_90
        ADD   SI, 2
        INC   DX
        DEC   CX
        JMP   _JSL_88
_JSL_90:
        MOV   AX, DX
        RET
_JSL_89:
        MOV   AX, -1
        RET
_JSRT_ARRREV:
        MOV   CX, [SI]
        CMP   CX, 2
        JL   _JSL_91
        LEA   BX, [SI+2]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        SUB   DI, 2
_JSL_92:
        CMP   BX, DI
        JGE   _JSL_93
        MOV   AX, [BX]
        MOV   DX, [DI]
        MOV   [BX], DX
        MOV   [DI], AX
        ADD   BX, 2
        SUB   DI, 2
        JMP   _JSL_92
_JSL_93:
_JSL_91:
        MOV   AX, SI
        RET
_JSRT_ARRSORT:
        PUSH   SI
_JSL_94:
        XOR   DX, DX
        MOV   CX, [SI]
        DEC   CX
        CMP   CX, 0
        JLE   _JSL_97
        LEA   BX, [SI+2]
_JSL_95:
        MOV   AX, [BX]
        CMP   AX, [BX+2]
        JLE   _JSL_96
        MOV   DI, [BX+2]
        MOV   [BX], DI
        MOV   [BX+2], AX
        MOV   DX, 1
_JSL_96:
        ADD   BX, 2
        DEC   CX
        OR   CX, CX
        JNZ   _JSL_95
        OR   DX, DX
        JNZ   _JSL_94
_JSL_97:
        POP   AX
        RET

; --- runtime object routines (TODO 16) ---
_JSRT_STRCMP:
        PUSH   SI
        PUSH   DI
_JSL_98:
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_100
        OR   AL, AL
        JZ   _JSL_99
        INC   SI
        INC   DI
        JMP   _JSL_98
_JSL_99:
        XOR   AX, AX
        POP   DI
        POP   SI
        RET
_JSL_100:
        MOV   AX, 1
        POP   DI
        POP   SI
        RET
_JSRT_OBJGET:
        PUSH   CX
        PUSH   BX
        MOV   CX, [BX]
        ADD   BX, 2
_JSL_101:
        OR   CX, CX
        JZ   _JSL_103
        PUSH   CX
        PUSH   BX
        PUSH   DI
        MOV   SI, [BX]
        CALL   _JSRT_STRCMP
        POP   DI
        POP   BX
        POP   CX
        OR   AX, AX
        JZ   _JSL_102
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_101
_JSL_102:
        MOV   AX, [BX+2]
        POP   BX
        POP   CX
        RET
_JSL_103:
        XOR   AX, AX
        POP   BX
        POP   CX
        RET
_JSRT_OBJSET:
        MOV   DX, AX
        PUSH   CX
        MOV   CX, [BX]
        PUSH   BX
        ADD   BX, 2
_JSL_104:
        OR   CX, CX
        JZ   _JSL_106
        PUSH   CX
        PUSH   BX
        PUSH   DI
        PUSH   DX
        MOV   SI, [BX]
        CALL   _JSRT_STRCMP
        POP   DX
        POP   DI
        POP   BX
        POP   CX
        OR   AX, AX
        JZ   _JSL_105
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_104
_JSL_105:
        MOV   [BX+2], DX
        MOV   AX, DX
        POP   BX
        POP   CX
        RET
_JSL_106:
        MOV   [BX], DI
        MOV   [BX+2], DX
        POP   BX
        MOV   CX, [BX]
        INC   CX
        MOV   [BX], CX
        MOV   AX, DX
        POP   CX
        RET
_JSRT_OBJKEYS:
        PUSH   CX
        PUSH   SI
        PUSH   DI
        MOV   CX, [BX]
        LEA   SI, [BX+2]
        LEA   DI, _JSRT_OKBUF
        MOV   [DI], CX
        ADD   DI, 2
_JSL_107:
        OR   CX, CX
        JZ   _JSL_108
        MOV   AX, [SI]
        MOV   [DI], AX
        ADD   SI, 4
        ADD   DI, 2
        DEC   CX
        JMP   _JSL_107
_JSL_108:
        LEA   AX, _JSRT_OKBUF
        POP   DI
        POP   SI
        POP   CX
        RET
_JSRT_OBJASSIGN:
        PUSH   CX
        PUSH   DI
        PUSH   BX
        MOV   CX, [SI]
        ADD   SI, 2
_JSL_109:
        OR   CX, CX
        JZ   _JSL_110
        PUSH   CX
        PUSH   SI
        PUSH   BX
        MOV   DI, [SI]
        MOV   AX, [SI+2]
        CALL   _JSRT_OBJSET
        POP   BX
        POP   SI
        POP   CX
        ADD   SI, 4
        DEC   CX
        JMP   _JSL_109
_JSL_110:
        POP   BX
        MOV   AX, BX
        POP   DI
        POP   CX
        RET

; --- runtime regexp routines (TODO 19) ---
_JSRT_REPARSE:
        PUSH   BX
        MOV   BX, DI
_JSL_111:
        MOV   AL, [BX]
        CMP   AL, 1
        JZ   _JSL_112
        OR   AL, AL
        JZ   _JSL_112
        INC   BX
        JMP   _JSL_111
_JSL_112:
        MOV   CX, BX
        SUB   CX, DI
        POP   BX
        RET
_JSRT_REMATCH:
        PUSH   SI
        PUSH   DI
        PUSH   BX
        PUSH   CX
        PUSH   DX
        CALL   _JSRT_REPARSE
        OR   CX, CX
        JZ   _JSL_115
_JSL_113:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_116
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   DX, CX
_JSL_114:
        OR   DX, DX
        JZ   _JSL_115B
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_116B
        INC   SI
        INC   DI
        DEC   DX
        JMP   _JSL_114
_JSL_115B:
        POP   CX
        POP   DI
        POP   SI
        JMP   _JSL_115
_JSL_116B:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_113
_JSL_115:
        MOV   AX, 1
        POP   DX
        POP   CX
        POP   BX
        POP   DI
        POP   SI
        RET
_JSL_116:
        XOR   AX, AX
        POP   DX
        POP   CX
        POP   BX
        POP   DI
        POP   SI
        RET
_JSRT_REINDEX:
        PUSH   SI
        PUSH   DI
        PUSH   BX
        PUSH   CX
        PUSH   DX
        MOV   BX, SI
        CALL   _JSRT_REPARSE
        OR   CX, CX
        JZ   _JSL_119
_JSL_117:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_120
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   DX, CX
_JSL_118:
        OR   DX, DX
        JZ   _JSL_119B
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_120B
        INC   SI
        INC   DI
        DEC   DX
        JMP   _JSL_118
_JSL_119B:
        POP   CX
        POP   DI
        POP   SI
        JMP   _JSL_119
_JSL_120B:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_117
_JSL_119:
        MOV   AX, SI
        SUB   AX, BX
        POP   DX
        POP   CX
        POP   BX
        POP   DI
        POP   SI
        RET
_JSL_120:
        MOV   AX, -1
        POP   DX
        POP   CX
        POP   BX
        POP   DI
        POP   SI
        RET
_JSRT_REEXEC:
        PUSH   SI
        PUSH   DI
        CALL   _JSRT_REMATCH
        POP   DI
        POP   SI
        OR   AX, AX
        JZ   _JSL_121
        MOV   AX, SI
        RET
_JSL_121:
        XOR   AX, AX
        RET
_JSRT_RESUB:
        PUSH   BX
        PUSH   DI
        PUSH   SI
        PUSH   CX
        PUSH   DX
        CALL   _JSRT_REPARSE
        MOV   DX, CX
        LEA   BX, _JSRT_REBUF
_JSL_122:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_125
        OR   DX, DX
        JZ   _JSL_123C
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   CX, DX
_JSL_123:
        OR   CX, CX
        JZ   _JSL_124
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_123N
        INC   SI
        INC   DI
        DEC   CX
        JMP   _JSL_123
_JSL_123N:
        POP   CX
        POP   DI
        POP   SI
_JSL_123C:
        MOV   AL, [SI]
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_122
_JSL_124:
        POP   CX
        POP   DI
        POP   AX
        PUSH   SI
        MOV   SI, [SP+10]
_JSL_126:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_126D
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_126
_JSL_126D:
        POP   SI
_JSL_127:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_125
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_127
_JSL_125:
        MOV   BYTE PTR [BX], 0
        POP   DX
        POP   CX
        POP   SI
        POP   DI
        POP   BX
        LEA   AX, _JSRT_REBUF
        RET

; --- runtime string / math / number routines (TODO 20) ---
_JSRT_STRLEN:
        PUSH   SI
        XOR   AX, AX
_JSL_128:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_129
        INC   AX
        INC   SI
        JMP   _JSL_128
_JSL_129:
        POP   SI
        RET
_JSRT_STRINDEXOF:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        MOV   BX, SI
_JSL_130:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_133
        PUSH   SI
        PUSH   DI
_JSL_131:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_132
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_131N
        INC   SI
        INC   DI
        JMP   _JSL_131
_JSL_132:
        POP   DI
        POP   AX
        SUB   AX, BX
        POP   DX
        POP   CX
        POP   BX
        RET
_JSL_131N:
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_130
_JSL_133:
        MOV   AX, 0FFFFh
        POP   DX
        POP   CX
        POP   BX
        RET
_JSRT_STRLASTIDX:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        MOV   BX, SI
        MOV   DX, 0FFFFh
_JSL_134:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_137
        PUSH   SI
        PUSH   DI
_JSL_135:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_136
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_135N
        INC   SI
        INC   DI
        JMP   _JSL_135
_JSL_136:
        POP   DI
        POP   AX
        SUB   AX, BX
        MOV   DX, AX
        ADD   AX, BX
        MOV   SI, AX
        INC   SI
        JMP   _JSL_134
_JSL_135N:
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_134
_JSL_137:
        MOV   AX, DX
        POP   DX
        POP   CX
        POP   BX
        RET
_JSRT_STRSTARTW:
_JSL_138:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_138Y
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_139
        INC   SI
        INC   DI
        JMP   _JSL_138
_JSL_138Y:
        MOV   AX, 1
        RET
_JSL_139:
        XOR   AX, AX
        RET
_JSRT_STRENDW:
        PUSH   BX
        PUSH   CX
        PUSH   SI
        CALL   _JSRT_STRLEN
        MOV   BX, AX
        POP   SI
        PUSH   SI
        MOV   SI, DI
        CALL   _JSRT_STRLEN
        MOV   CX, AX
        POP   SI
        CMP   CX, BX
        JA   _JSL_140
        SUB   BX, CX
        ADD   SI, BX
        POP   CX
        POP   BX
        JMP   _JSRT_STRSTARTW
_JSL_140:
        XOR   AX, AX
        POP   CX
        POP   BX
        RET
_JSRT_STRSLICE:
        PUSH   DI
        PUSH   DX
        LEA   DI, _JSRT_STRBUF
        MOV   DX, BX
_JSL_141:
        OR   DX, DX
        JZ   _JSL_142
        CMP   BYTE PTR [SI], 0
        JE   _JSL_143
        INC   SI
        DEC   DX
        JMP   _JSL_141
_JSL_142:
        CMP   BX, CX
        JGE   _JSL_143
        CMP   BYTE PTR [SI], 0
        JE   _JSL_143
        MOV   AL, [SI]
        MOV   [DI], AL
        INC   SI
        INC   DI
        INC   BX
        JMP   _JSL_142
_JSL_143:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DX
        POP   DI
        RET
_JSRT_STRTOUPPER:
        PUSH   DI
        LEA   DI, _JSRT_STRBUF
_JSL_144:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_145
        CMP   AL, 'a'
        JB   _JSL_144C
        CMP   AL, 'z'
        JA   _JSL_144C
        SUB   AL, 32
_JSL_144C:
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_144
_JSL_145:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DI
        RET
_JSRT_STRTOLOWER:
        PUSH   DI
        LEA   DI, _JSRT_STRBUF
_JSL_146:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_147
        CMP   AL, 'A'
        JB   _JSL_146C
        CMP   AL, 'Z'
        JA   _JSL_146C
        ADD   AL, 32
_JSL_146C:
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_146
_JSL_147:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DI
        RET
_JSRT_STRTRIM:
        PUSH   DI
        PUSH   BX
_JSL_148:
        MOV   AL, [SI]
        CMP   AL, 32
        JE   _JSL_148S
        CMP   AL, 9
        JE   _JSL_148S
        JMP   _JSL_149
_JSL_148S:
        INC   SI
        JMP   _JSL_148
_JSL_149:
        LEA   DI, _JSRT_STRBUF
        MOV   BX, DI
_JSL_151:
        MOV   AL, [SI]
        MOV   [DI], AL
        OR   AL, AL
        JZ   _JSL_150
        INC   SI
        INC   DI
        JMP   _JSL_151
_JSL_150:
_JSL_152:
        DEC   DI
        CMP   DI, BX
        JB   _JSL_152D
        CMP   BYTE PTR [DI], 32
        JE   _JSL_152
        CMP   BYTE PTR [DI], 9
        JE   _JSL_152
_JSL_152D:
        INC   DI
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   BX
        POP   DI
        RET
_JSRT_STRSPLIT:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        LEA   BX, _JSRT_SPLITBUF
        MOV   WORD PTR [BX], 0
        ADD   BX, 2
        PUSH   SI
        MOV   SI, DI
        CALL   _JSRT_STRLEN
        MOV   DX, AX
        POP   SI
        MOV   [BX], SI
        ADD   BX, 2
        PUSH   AX
        LEA   AX, _JSRT_SPLITBUF
        MOV   CX, AX
        POP   AX
        PUSH   SI
        MOV   SI, CX
        MOV   AX, [SI]
        INC   AX
        MOV   [SI], AX
        POP   SI
_JSL_153:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_156
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   CX, DX
_JSL_154:
        OR   CX, CX
        JZ   _JSL_155
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_154N
        INC   SI
        INC   DI
        DEC   CX
        JMP   _JSL_154
_JSL_154N:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_153
_JSL_155:
        POP   CX
        POP   DI
        POP   AX
        MOV   [BX], SI
        ADD   BX, 2
        PUSH   SI
        MOV   SI, CX
        MOV   AX, [SI]
        INC   AX
        MOV   [SI], AX
        POP   SI
        JMP   _JSL_153
_JSL_156:
        LEA   AX, _JSRT_SPLITBUF
        POP   DX
        POP   CX
        POP   BX
        RET
_JSRT_STRCHAR:
        ADD   SI, CX
        MOV   AL, [SI]
        MOV   BYTE PTR [_JSRT_CHRBUF], AL
        MOV   BYTE PTR [_JSRT_CHRBUF+1], 0
        LEA   AX, _JSRT_CHRBUF
        RET
_JSRT_STRORD:
        ADD   SI, CX
        XOR   AX, AX
        MOV   AL, [SI]
        RET
_JSRT_STRREPEAT:
        PUSH   BX
        PUSH   DX
        MOV   BX, DI
        MOV   DX, SI
_JSL_157:
        OR   CX, CX
        JZ   _JSL_159
        MOV   SI, DX
_JSL_158:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_158D
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_158
_JSL_158D:
        DEC   CX
        JMP   _JSL_157
_JSL_159:
        MOV   BYTE PTR [DI], 0
        MOV   AX, BX
        POP   DX
        POP   BX
        RET
_JSRT_STRPADS:
        PUSH   BX
        PUSH   DX
        PUSH   CX
        PUSH   DI
        CALL   _JSRT_STRLEN
        MOV   DX, AX
        POP   DI
        POP   CX
        CMP   DX, CX
        JAE   _JSL_162
        SUB   CX, DX
        LEA   BX, _JSRT_STRBUF
        PUSH   SI
        MOV   SI, DI
_JSL_160:
        OR   CX, CX
        JZ   _JSL_161
        MOV   AL, [SI]
        OR   AL, AL
        JNZ   _JSL_160C
        MOV   SI, DI
        MOV   AL, [SI]
_JSL_160C:
        MOV   [BX], AL
        INC   BX
        INC   SI
        DEC   CX
        JMP   _JSL_160
_JSL_161:
        POP   SI
_JSL_163:
        MOV   AL, [SI]
        MOV   [BX], AL
        OR   AL, AL
        JZ   _JSL_163D
        INC   SI
        INC   BX
        JMP   _JSL_163
_JSL_163D:
        LEA   AX, _JSRT_STRBUF
        POP   DX
        POP   BX
        RET
_JSL_162:
        LEA   BX, _JSRT_STRBUF
_JSL_164:
        MOV   AL, [SI]
        MOV   [BX], AL
        OR   AL, AL
        JZ   _JSL_164D
        INC   SI
        INC   BX
        JMP   _JSL_164
_JSL_164D:
        LEA   AX, _JSRT_STRBUF
        POP   DX
        POP   BX
        RET
_JSRT_CHR:
        MOV   BYTE PTR [_JSRT_CHRBUF], AL
        MOV   BYTE PTR [_JSRT_CHRBUF+1], 0
        LEA   AX, _JSRT_CHRBUF
        RET
_JSRT_STRTONUM:
        MOV   CX, 10
        JMP   _JSRT_STRTOINT
_JSRT_STRTOINT:
        PUSH   BX
        PUSH   DX
        XOR   AX, AX
        XOR   BX, BX
_JSL_165:
        CMP   BYTE PTR [SI], 32
        JE   _JSL_165S
        JMP   _JSL_165E
_JSL_165S:
        INC   SI
        JMP   _JSL_165
_JSL_165E:
        CMP   BYTE PTR [SI], '-'
        JNE   _JSL_165P
        MOV   BX, 1
        INC   SI
        JMP   _JSL_166
_JSL_165P:
        CMP   BYTE PTR [SI], '+'
        JNE   _JSL_166
        INC   SI
_JSL_166:
        XOR   DX, DX
        MOV   DL, [SI]
        OR   DL, DL
        JZ   _JSL_167
        CMP   DL, '0'
        JB   _JSL_167
        CMP   DL, '9'
        JA   _JSL_166H
        SUB   DL, '0'
        JMP   _JSL_166M
_JSL_166H:
        CMP   DL, 'a'
        JB   _JSL_166U
        CMP   DL, 'f'
        JA   _JSL_167
        SUB   DL, 'a'
        ADD   DL, 10
        JMP   _JSL_166M
_JSL_166U:
        CMP   DL, 'A'
        JB   _JSL_167
        CMP   DL, 'F'
        JA   _JSL_167
        SUB   DL, 'A'
        ADD   DL, 10
_JSL_166M:
        CMP   DL, CL
        JAE   _JSL_167
        PUSH   DX
        PUSH   CX
        MUL    CX
        POP   CX
        POP   DX
        ADD   AX, DX
        INC   SI
        JMP   _JSL_166
_JSL_167:
        OR   BX, BX
        JZ   _JSL_167D
        NEG    AX
_JSL_167D:
        POP   DX
        POP   BX
        RET
_JSRT_ABS:
        OR   AX, AX
        JNS   _JSL_168
        NEG    AX
_JSL_168:
        RET
_JSRT_POW:
        PUSH   CX
        PUSH   DX
        MOV   CX, BX
        MOV   BX, AX
        MOV   AX, 1
_JSL_169:
        OR   CX, CX
        JZ   _JSL_170
        PUSH   DX
        MUL    BX
        POP   DX
        DEC   CX
        JMP   _JSL_169
_JSL_170:
        POP   DX
        POP   CX
        RET
_JSRT_SQRT:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        OR   AX, AX
        JZ   _JSL_172
        MOV   BX, AX
        SHR   AX, 1
        OR   AX, AX
        JZ   _JSL_172O
_JSL_171:
        MOV   CX, AX
        PUSH   BX
        XOR   DX, DX
        MOV   AX, BX
        DIV    CX
        POP   BX
        ADD   AX, CX
        SHR   AX, 1
        CMP   AX, CX
        JB   _JSL_171
        MOV   AX, CX
_JSL_172:
        POP   DX
        POP   CX
        POP   BX
        RET
_JSL_172O:
        MOV   AX, 1
        POP   DX
        POP   CX
        POP   BX
        RET
_JSRT_RAND:
        PUSH   DX
        MOV   AX, [_JS_RNDSEED]
        MOV   DX, 25173
        MUL    DX
        ADD   AX, 13849
        MOV   [_JS_RNDSEED], AX
        AND   AX, 7FFFh
        POP   DX
        RET
_JSRT_SIGN:
        OR   AX, AX
        JZ   _JSL_174
        JS   _JSL_173
        MOV   AX, 1
        JMP   _JSL_174
_JSL_173:
        MOV   AX, 0FFFFh
_JSL_174:
        RET
_JSRT_JSONSTR:
        PUSH   DI
        LEA   DI, _JSRT_JSONBUF
        CALL   _JSRT_NUMTOSTR
        LEA   AX, _JSRT_JSONBUF
        POP   DI
        RET

; --- runtime class routines (TODO 21) ---
_JSRT_NEW:
        PUSH   BX
        MOV   BX, [_JSRT_HEAPTOP]
        LEA   AX, _JSRT_OBJHEAP
        ADD   AX, BX
        PUSH   AX
        MOV   WORD PTR [AX], 0
        MOV   WORD PTR [AX+2], 0
        ADD   BX, 68
        MOV   [_JSRT_HEAPTOP], BX
        POP   AX
        POP   BX
        RET
_JSRT_OBJCREATE:
        PUSH   DX
        MOV   DX, BX
        PUSH   BX
        MOV   BX, [_JSRT_HEAPTOP]
        LEA   AX, _JSRT_OBJHEAP
        ADD   AX, BX
        MOV   [AX], DX
        MOV   WORD PTR [AX+2], 0
        ADD   AX, 2
        PUSH   AX
        ADD   BX, 68
        MOV   [_JSRT_HEAPTOP], BX
        POP   AX
        POP   BX
        POP   DX
        RET

; --- runtime exception routines (TODO 23) ---
_JSRT_MKERROR:
        MOV   AX, SI
        RET
_JSRT_THROW:
        MOV   [_JSX_ERRPTR], AX
        CMP   WORD PTR [_JSX_HANDLER], 0
        JZ   _JSL_175
        MOV   SP, [_JSX_SAVESP]
        MOV   BP, [_JSX_SAVEBP]
        MOV   BX, [_JSX_HANDLER]
        JMP   BX
_JSL_175:
        PUSH   AX
        LEA   DX, _JS_ERR_UNCAUGHT
        MOV   DI, DX
        XOR   CX, CX
_JSL_176:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_177
        INC   CX
        INC   DI
        JMP   _JSL_176
_JSL_177:
        SUB   DI, CX
        MOV   DX, DI
        MOV   BX, 2
        MOV   AH, 40h
        INT    21h
        POP   AX
        MOV   DI, AX
        XOR   CX, CX
_JSL_178:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_179
        INC   CX
        INC   DI
        JMP   _JSL_178
_JSL_179:
        SUB   DI, CX
        MOV   DX, DI
        MOV   BX, 2
        MOV   AH, 40h
        INT    21h
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 2
        MOV   AH, 40h
        INT    21h
        MOV   AX, 4C01h
        INT    21h
_JSRT_PANIC:
        MOV   AX, SI
        CALL   _JSRT_THROW
        RET

; --- fin du code genere ---

_TEXT   ENDS

_DATA   SEGMENT WORD PUBLIC 'DATA'
_JS_UNDEF   DB  'undefined',0
_JS_NULL    DB  'null',0
_JS_TRUE    DB  'true',0
_JS_FALSE   DB  'false',0
_JSRT_STRBUF DB 512 DUP(0)
_JS_CRLF    DB  13,10,0
_JS_SPACE   DB  ' ',0
_JS_WARNPFX DB  'Warning: ',0
_JSRT_OKBUF  DW  17 DUP(0)
_JS_CALLDEPTH  DW  0
_JSCAP_1  DW  0
_JSCAP_2  DW  0
_JSCAP_3  DW  0
_JSCAP_4  DW  0
_JSCAP_5  DW  0
_JSCAP_6  DW  0
_JSCAP_7  DW  0
_JSCAP_8  DW  0
_JSCAP_9  DW  0
_JSRT_REBUF  DB  256 DUP(0)
_JSRT_CHRBUF DB  2 DUP(0)
_JSRT_JSONBUF DB 256 DUP(0)
_JSRT_SPLITBUF DW 64 DUP(0)
_JS_RNDSEED  DW  12345
_JSRT_OBJHEAP DB 4096 DUP(0)
_JSRT_HEAPTOP DW 0
_JSRT_OBJTMP  DW 0
_JSX_HANDLER  DW  0
_JSX_SAVESP   DW  0
_JSX_SAVEBP   DW  0
_JSX_ERRPTR   DW  0
_JS_ERR_DIV0  DB  'Division by zero',0
_JS_ERR_UNCAUGHT DB 'Uncaught: ',0
_JSRT_ERRBUF  DB  64 DUP(0)
_JSRT_NUMBUF  DB  12 DUP(0)
_JS_TYP_NUMBER  DB 'number',0
_JS_TYP_STRING  DB 'string',0
_JS_TYP_BOOLEAN DB 'boolean',0
_JS_TYP_OBJECT  DB 'object',0
_JS_TYP_FUNCTION DB 'function',0
_JS_HEAP      DB 4096 DUP(0)
_JS_HEAPTOP   DW 0
_JSV_x  DW  0
_JSK_4  DB  'grand',0
_JSK_10  DB  'moyen',0
_JSK_13  DB  'petit',0
_JSV_day  DW  0
_JSK_18  DB  'lundi',0
_JSK_22  DB  'mardi',0
_JSK_26  DB  'mercredi',0
_JSK_29  DB  'autre',0
_JSV_i  DW  0
_JSV_total  DW  0
_JSV_sum  DW  0
_JSV_j  DW  0
_JSV_fruits  DW  0
_JSA_44  DW  0   ; tableau (0 elem)
_JSK_45  DB  'pomme',0
_JSA_44_E0  DW  0
_JSK_46  DB  'banane',0
_JSA_44_E1  DW  0
_JSK_47  DB  'cerise',0
_JSA_44_E2  DW  0
_JSV_f  DW  0
_JSV__foridx  DW  0
_JSV_k  DW  0
_JSV_product  DW  0
_JSV_age  DW  0
_JSV_status  DW  0
_JSK_62  DB  'majeur',0
_JSK_63  DB  'mineur',0
_DATA   ENDS

        END   _JSF_main
