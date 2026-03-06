; Genere par JS86 v1.0 - SAMPLES\JS\test12.js

        .MODEL SMALL
        .STACK 1024

_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME  CS:_TEXT, DS:_DATA, SS:STACK

; --- debut du code genere ---

        MOV   AX, 42
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_1:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_2
        INC    CX
        INC    DI
        JMP   _JSL_1
_JSL_2:
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
        LEA   AX, _JSK_3
        MOV   DI, AX
        XOR   CX, CX
_JSL_4:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_5
        INC    CX
        INC    DI
        JMP   _JSL_4
_JSL_5:
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
        MOV   AX, 10
        MOV   [_JSV_x], AX
        LEA   AX, _JSK_6
        MOV   [_JSV_s], AX
        MOV   AX, [_JSV_x]
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_7:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_8
        INC    CX
        INC    DI
        JMP   _JSL_7
_JSL_8:
        SUB   DI, CX
        MOV   DX, DI
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        LEA   DX, _JS_SPACE
        MOV   CX, 1
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        MOV   AX, [_JSV_s]
        MOV   DI, AX
        XOR   CX, CX
_JSL_9:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_10
        INC    CX
        INC    DI
        JMP   _JSL_9
_JSL_10:
        SUB   DI, CX
        MOV   DX, DI
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        LEA   DX, _JS_SPACE
        MOV   CX, 1
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        MOV   AX, 99
        CALL   _JSRT_NUMTOSTR
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
        MOV   AX, 5
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_13:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_14
        INC    CX
        INC    DI
        JMP   _JSL_13
_JSL_14:
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
        LEA   AX, _JSK_15
        MOV   DI, AX
        XOR   CX, CX
_JSL_16:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_17
        INC    CX
        INC    DI
        JMP   _JSL_16
_JSL_17:
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
        LEA   DI, _JS_WARNPFX
        XOR   CX, CX
_JSL_18:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_19
        INC    CX
        INC    DI
        JMP   _JSL_18
_JSL_19:
        SUB   DI, CX
        LEA   DX, _JS_WARNPFX
        MOV   BX, 2
        MOV   AH, 40h
        INT    21h
        LEA   AX, _JSK_20
        MOV   DI, AX
        XOR   CX, CX
_JSL_21:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_22
        INC    CX
        INC    DI
        JMP   _JSL_21
_JSL_22:
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
        LEA   AX, _JSK_23
        MOV   DI, AX
        XOR   CX, CX
_JSL_24:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_25
        INC    CX
        INC    DI
        JMP   _JSL_24
_JSL_25:
        SUB   DI, CX
        MOV   DX, DI
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
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
        LEA   AX, _JSK_29
        PUSH   AX
        XOR   AX, AX
        MOV   [_JSV_p], AX
        MOV   AX, 1
        MOV   [_JSV_b], AX
        MOV   AX, [_JSV_b]
        OR   AX, AX
        JNZ   _JSL_30
        LEA   DI, _JS_FALSE
        XOR   CX, CX
_JSL_32:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_33
        INC    CX
        INC    DI
        JMP   _JSL_32
_JSL_33:
        SUB   DI, CX
        LEA   DX, _JS_FALSE
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        JMP   _JSL_31
_JSL_30:
        LEA   DI, _JS_TRUE
        XOR   CX, CX
_JSL_34:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_35
        INC    CX
        INC    DI
        JMP   _JSL_34
_JSL_35:
        SUB   DI, CX
        LEA   DX, _JS_TRUE
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
_JSL_31:
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        MOV   AX, 0
        OR   AX, AX
        JNZ   _JSL_36
        LEA   DI, _JS_FALSE
        XOR   CX, CX
_JSL_38:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_39
        INC    CX
        INC    DI
        JMP   _JSL_38
_JSL_39:
        SUB   DI, CX
        LEA   DX, _JS_FALSE
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        JMP   _JSL_37
_JSL_36:
        LEA   DI, _JS_TRUE
        XOR   CX, CX
_JSL_40:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_41
        INC    CX
        INC    DI
        JMP   _JSL_40
_JSL_41:
        SUB   DI, CX
        LEA   DX, _JS_TRUE
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
_JSL_37:
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        XOR   AX, AX
        MOV   AX, 0
        LEA   DI, _JS_NULL
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
        LEA   DX, _JS_NULL
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        XOR   AX, AX
        MOV   AX, 0
        LEA   DI, _JS_UNDEF
        XOR   CX, CX
_JSL_44:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_45
        INC    CX
        INC    DI
        JMP   _JSL_44
_JSL_45:
        SUB   DI, CX
        LEA   DX, _JS_UNDEF
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        MOV   AX, 123
        MOV   [_JSV_n], AX
        MOV   AX, [_JSV_n]
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_46:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_47
        INC    CX
        INC    DI
        JMP   _JSL_46
_JSL_47:
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
        JZ   _JSL_48
        DEC   BX
        MOV   [SI], BX
        MOV   DI, BX
        SHL   DI, 1
        ADD   DI, 2
        ADD   DI, SI
        MOV   AX, [DI]
        RET
_JSL_48:
        XOR   AX, AX
        RET
_JSRT_ARRSHIFT:
        MOV   CX, [SI]
        OR   CX, CX
        JZ   _JSL_49
        MOV   AX, [SI+2]
        PUSH   AX
        DEC   CX
        MOV   [SI], CX
        LEA   DI, [SI+2]
        LEA   BX, [SI+4]
_JSL_50:
        OR   CX, CX
        JZ   _JSL_51
        MOV   AX, [BX]
        MOV   [DI], AX
        ADD   DI, 2
        ADD   BX, 2
        DEC   CX
        JMP   _JSL_50
_JSL_51:
        POP   AX
        RET
_JSL_49:
        XOR   AX, AX
        RET
_JSRT_ARRUNSHIFT:
        PUSH   AX
        MOV   CX, [SI]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        ADD   DI, 2
_JSL_52:
        OR   CX, CX
        JZ   _JSL_53
        MOV   AX, [DI-2]
        MOV   [DI], AX
        SUB   DI, 2
        DEC   CX
        JMP   _JSL_52
_JSL_53:
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
_JSL_54:
        OR   CX, CX
        JZ   _JSL_55
        CMP   [SI], BX
        JE   _JSL_56
        ADD   SI, 2
        INC   DX
        DEC   CX
        JMP   _JSL_54
_JSL_56:
        MOV   AX, DX
        RET
_JSL_55:
        MOV   AX, -1
        RET
_JSRT_ARRREV:
        MOV   CX, [SI]
        CMP   CX, 2
        JL   _JSL_57
        LEA   BX, [SI+2]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        SUB   DI, 2
_JSL_58:
        CMP   BX, DI
        JGE   _JSL_59
        MOV   AX, [BX]
        MOV   DX, [DI]
        MOV   [BX], DX
        MOV   [DI], AX
        ADD   BX, 2
        SUB   DI, 2
        JMP   _JSL_58
_JSL_59:
_JSL_57:
        MOV   AX, SI
        RET
_JSRT_ARRSORT:
        PUSH   SI
_JSL_60:
        XOR   DX, DX
        MOV   CX, [SI]
        DEC   CX
        CMP   CX, 0
        JLE   _JSL_63
        LEA   BX, [SI+2]
_JSL_61:
        MOV   AX, [BX]
        CMP   AX, [BX+2]
        JLE   _JSL_62
        MOV   DI, [BX+2]
        MOV   [BX], DI
        MOV   [BX+2], AX
        MOV   DX, 1
_JSL_62:
        ADD   BX, 2
        DEC   CX
        OR   CX, CX
        JNZ   _JSL_61
        OR   DX, DX
        JNZ   _JSL_60
_JSL_63:
        POP   AX
        RET

; --- runtime object routines (TODO 16) ---
_JSRT_STRCMP:
        PUSH   SI
        PUSH   DI
_JSL_64:
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_66
        OR   AL, AL
        JZ   _JSL_65
        INC   SI
        INC   DI
        JMP   _JSL_64
_JSL_65:
        XOR   AX, AX
        POP   DI
        POP   SI
        RET
_JSL_66:
        MOV   AX, 1
        POP   DI
        POP   SI
        RET
_JSRT_OBJGET:
        PUSH   CX
        PUSH   BX
        MOV   CX, [BX]
        ADD   BX, 2
_JSL_67:
        OR   CX, CX
        JZ   _JSL_69
        PUSH   CX
        PUSH   BX
        PUSH   DI
        MOV   SI, [BX]
        CALL   _JSRT_STRCMP
        POP   DI
        POP   BX
        POP   CX
        OR   AX, AX
        JZ   _JSL_68
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_67
_JSL_68:
        MOV   AX, [BX+2]
        POP   BX
        POP   CX
        RET
_JSL_69:
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
_JSL_70:
        OR   CX, CX
        JZ   _JSL_72
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
        JZ   _JSL_71
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_70
_JSL_71:
        MOV   [BX+2], DX
        MOV   AX, DX
        POP   BX
        POP   CX
        RET
_JSL_72:
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
_JSL_73:
        OR   CX, CX
        JZ   _JSL_74
        MOV   AX, [SI]
        MOV   [DI], AX
        ADD   SI, 4
        ADD   DI, 2
        DEC   CX
        JMP   _JSL_73
_JSL_74:
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
_JSL_75:
        OR   CX, CX
        JZ   _JSL_76
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
        JMP   _JSL_75
_JSL_76:
        POP   BX
        MOV   AX, BX
        POP   DI
        POP   CX
        RET

; --- runtime regexp routines (TODO 19) ---
_JSRT_REPARSE:
        PUSH   BX
        MOV   BX, DI
_JSL_77:
        MOV   AL, [BX]
        CMP   AL, 1
        JZ   _JSL_78
        OR   AL, AL
        JZ   _JSL_78
        INC   BX
        JMP   _JSL_77
_JSL_78:
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
        JZ   _JSL_81
_JSL_79:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_82
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   DX, CX
_JSL_80:
        OR   DX, DX
        JZ   _JSL_81B
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_82B
        INC   SI
        INC   DI
        DEC   DX
        JMP   _JSL_80
_JSL_81B:
        POP   CX
        POP   DI
        POP   SI
        JMP   _JSL_81
_JSL_82B:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_79
_JSL_81:
        MOV   AX, 1
        POP   DX
        POP   CX
        POP   BX
        POP   DI
        POP   SI
        RET
_JSL_82:
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
        JZ   _JSL_85
_JSL_83:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_86
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   DX, CX
_JSL_84:
        OR   DX, DX
        JZ   _JSL_85B
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_86B
        INC   SI
        INC   DI
        DEC   DX
        JMP   _JSL_84
_JSL_85B:
        POP   CX
        POP   DI
        POP   SI
        JMP   _JSL_85
_JSL_86B:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_83
_JSL_85:
        MOV   AX, SI
        SUB   AX, BX
        POP   DX
        POP   CX
        POP   BX
        POP   DI
        POP   SI
        RET
_JSL_86:
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
        JZ   _JSL_87
        MOV   AX, SI
        RET
_JSL_87:
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
_JSL_88:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_91
        OR   DX, DX
        JZ   _JSL_89C
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   CX, DX
_JSL_89:
        OR   CX, CX
        JZ   _JSL_90
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_89N
        INC   SI
        INC   DI
        DEC   CX
        JMP   _JSL_89
_JSL_89N:
        POP   CX
        POP   DI
        POP   SI
_JSL_89C:
        MOV   AL, [SI]
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_88
_JSL_90:
        POP   CX
        POP   DI
        POP   AX
        PUSH   SI
        MOV   SI, [SP+10]
_JSL_92:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_92D
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_92
_JSL_92D:
        POP   SI
_JSL_93:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_91
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_93
_JSL_91:
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
_JSL_94:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_95
        INC   AX
        INC   SI
        JMP   _JSL_94
_JSL_95:
        POP   SI
        RET
_JSRT_STRINDEXOF:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        MOV   BX, SI
_JSL_96:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_99
        PUSH   SI
        PUSH   DI
_JSL_97:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_98
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_97N
        INC   SI
        INC   DI
        JMP   _JSL_97
_JSL_98:
        POP   DI
        POP   AX
        SUB   AX, BX
        POP   DX
        POP   CX
        POP   BX
        RET
_JSL_97N:
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_96
_JSL_99:
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
_JSL_100:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_103
        PUSH   SI
        PUSH   DI
_JSL_101:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_102
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_101N
        INC   SI
        INC   DI
        JMP   _JSL_101
_JSL_102:
        POP   DI
        POP   AX
        SUB   AX, BX
        MOV   DX, AX
        ADD   AX, BX
        MOV   SI, AX
        INC   SI
        JMP   _JSL_100
_JSL_101N:
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_100
_JSL_103:
        MOV   AX, DX
        POP   DX
        POP   CX
        POP   BX
        RET
_JSRT_STRSTARTW:
_JSL_104:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_104Y
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_105
        INC   SI
        INC   DI
        JMP   _JSL_104
_JSL_104Y:
        MOV   AX, 1
        RET
_JSL_105:
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
        JA   _JSL_106
        SUB   BX, CX
        ADD   SI, BX
        POP   CX
        POP   BX
        JMP   _JSRT_STRSTARTW
_JSL_106:
        XOR   AX, AX
        POP   CX
        POP   BX
        RET
_JSRT_STRSLICE:
        PUSH   DI
        PUSH   DX
        LEA   DI, _JSRT_STRBUF
        MOV   DX, BX
_JSL_107:
        OR   DX, DX
        JZ   _JSL_108
        CMP   BYTE PTR [SI], 0
        JE   _JSL_109
        INC   SI
        DEC   DX
        JMP   _JSL_107
_JSL_108:
        CMP   BX, CX
        JGE   _JSL_109
        CMP   BYTE PTR [SI], 0
        JE   _JSL_109
        MOV   AL, [SI]
        MOV   [DI], AL
        INC   SI
        INC   DI
        INC   BX
        JMP   _JSL_108
_JSL_109:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DX
        POP   DI
        RET
_JSRT_STRTOUPPER:
        PUSH   DI
        LEA   DI, _JSRT_STRBUF
_JSL_110:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_111
        CMP   AL, 'a'
        JB   _JSL_110C
        CMP   AL, 'z'
        JA   _JSL_110C
        SUB   AL, 32
_JSL_110C:
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_110
_JSL_111:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DI
        RET
_JSRT_STRTOLOWER:
        PUSH   DI
        LEA   DI, _JSRT_STRBUF
_JSL_112:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_113
        CMP   AL, 'A'
        JB   _JSL_112C
        CMP   AL, 'Z'
        JA   _JSL_112C
        ADD   AL, 32
_JSL_112C:
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_112
_JSL_113:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DI
        RET
_JSRT_STRTRIM:
        PUSH   DI
        PUSH   BX
_JSL_114:
        MOV   AL, [SI]
        CMP   AL, 32
        JE   _JSL_114S
        CMP   AL, 9
        JE   _JSL_114S
        JMP   _JSL_115
_JSL_114S:
        INC   SI
        JMP   _JSL_114
_JSL_115:
        LEA   DI, _JSRT_STRBUF
        MOV   BX, DI
_JSL_117:
        MOV   AL, [SI]
        MOV   [DI], AL
        OR   AL, AL
        JZ   _JSL_116
        INC   SI
        INC   DI
        JMP   _JSL_117
_JSL_116:
_JSL_118:
        DEC   DI
        CMP   DI, BX
        JB   _JSL_118D
        CMP   BYTE PTR [DI], 32
        JE   _JSL_118
        CMP   BYTE PTR [DI], 9
        JE   _JSL_118
_JSL_118D:
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
_JSL_119:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_122
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   CX, DX
_JSL_120:
        OR   CX, CX
        JZ   _JSL_121
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_120N
        INC   SI
        INC   DI
        DEC   CX
        JMP   _JSL_120
_JSL_120N:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_119
_JSL_121:
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
        JMP   _JSL_119
_JSL_122:
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
_JSL_123:
        OR   CX, CX
        JZ   _JSL_125
        MOV   SI, DX
_JSL_124:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_124D
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_124
_JSL_124D:
        DEC   CX
        JMP   _JSL_123
_JSL_125:
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
        JAE   _JSL_128
        SUB   CX, DX
        LEA   BX, _JSRT_STRBUF
        PUSH   SI
        MOV   SI, DI
_JSL_126:
        OR   CX, CX
        JZ   _JSL_127
        MOV   AL, [SI]
        OR   AL, AL
        JNZ   _JSL_126C
        MOV   SI, DI
        MOV   AL, [SI]
_JSL_126C:
        MOV   [BX], AL
        INC   BX
        INC   SI
        DEC   CX
        JMP   _JSL_126
_JSL_127:
        POP   SI
_JSL_129:
        MOV   AL, [SI]
        MOV   [BX], AL
        OR   AL, AL
        JZ   _JSL_129D
        INC   SI
        INC   BX
        JMP   _JSL_129
_JSL_129D:
        LEA   AX, _JSRT_STRBUF
        POP   DX
        POP   BX
        RET
_JSL_128:
        LEA   BX, _JSRT_STRBUF
_JSL_130:
        MOV   AL, [SI]
        MOV   [BX], AL
        OR   AL, AL
        JZ   _JSL_130D
        INC   SI
        INC   BX
        JMP   _JSL_130
_JSL_130D:
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
_JSL_131:
        CMP   BYTE PTR [SI], 32
        JE   _JSL_131S
        JMP   _JSL_131E
_JSL_131S:
        INC   SI
        JMP   _JSL_131
_JSL_131E:
        CMP   BYTE PTR [SI], '-'
        JNE   _JSL_131P
        MOV   BX, 1
        INC   SI
        JMP   _JSL_132
_JSL_131P:
        CMP   BYTE PTR [SI], '+'
        JNE   _JSL_132
        INC   SI
_JSL_132:
        XOR   DX, DX
        MOV   DL, [SI]
        OR   DL, DL
        JZ   _JSL_133
        CMP   DL, '0'
        JB   _JSL_133
        CMP   DL, '9'
        JA   _JSL_132H
        SUB   DL, '0'
        JMP   _JSL_132M
_JSL_132H:
        CMP   DL, 'a'
        JB   _JSL_132U
        CMP   DL, 'f'
        JA   _JSL_133
        SUB   DL, 'a'
        ADD   DL, 10
        JMP   _JSL_132M
_JSL_132U:
        CMP   DL, 'A'
        JB   _JSL_133
        CMP   DL, 'F'
        JA   _JSL_133
        SUB   DL, 'A'
        ADD   DL, 10
_JSL_132M:
        CMP   DL, CL
        JAE   _JSL_133
        PUSH   DX
        PUSH   CX
        MUL    CX
        POP   CX
        POP   DX
        ADD   AX, DX
        INC   SI
        JMP   _JSL_132
_JSL_133:
        OR   BX, BX
        JZ   _JSL_133D
        NEG    AX
_JSL_133D:
        POP   DX
        POP   BX
        RET
_JSRT_ABS:
        OR   AX, AX
        JNS   _JSL_134
        NEG    AX
_JSL_134:
        RET
_JSRT_POW:
        PUSH   CX
        PUSH   DX
        MOV   CX, BX
        MOV   BX, AX
        MOV   AX, 1
_JSL_135:
        OR   CX, CX
        JZ   _JSL_136
        PUSH   DX
        MUL    BX
        POP   DX
        DEC   CX
        JMP   _JSL_135
_JSL_136:
        POP   DX
        POP   CX
        RET
_JSRT_SQRT:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        OR   AX, AX
        JZ   _JSL_138
        MOV   BX, AX
        SHR   AX, 1
        OR   AX, AX
        JZ   _JSL_138O
_JSL_137:
        MOV   CX, AX
        PUSH   BX
        XOR   DX, DX
        MOV   AX, BX
        DIV    CX
        POP   BX
        ADD   AX, CX
        SHR   AX, 1
        CMP   AX, CX
        JB   _JSL_137
        MOV   AX, CX
_JSL_138:
        POP   DX
        POP   CX
        POP   BX
        RET
_JSL_138O:
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
        JZ   _JSL_140
        JS   _JSL_139
        MOV   AX, 1
        JMP   _JSL_140
_JSL_139:
        MOV   AX, 0FFFFh
_JSL_140:
        RET
_JSRT_JSONSTR:
        PUSH   DI
        LEA   DI, _JSRT_JSONBUF
        CALL   _JSRT_NUMTOSTR
        LEA   AX, _JSRT_JSONBUF
        POP   DI
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
_JSK_3  DB  'hello world',0
_JSV_x  DW  0
_JSV_s  DW  0
_JSK_6  DB  'test',0
_JSK_15  DB  'erreur ici',0
_JSK_20  DB  'attention',0
_JSK_23  DB  'no newline',0
_JSK_26  DB  'alerte!',0
_JSV_p  DW  0
_JSK_29  DB  'question?',0
_JSV_b  DW  0
_JSV_n  DW  0
_DATA   ENDS

        END
