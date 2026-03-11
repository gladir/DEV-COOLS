; Genere par JS86 v1.0 - SAMPLES\JS\test19.js

        .MODEL SMALL
        .STACK 1024

_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME  CS:_TEXT, DS:_DATA, SS:STACK

; --- debut du code genere ---

        LEA   AX, _JSK_1
        MOV   [_JSV_re], AX
        MOV   AX, [_JSV_re]
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_2:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_3
        INC    CX
        INC    DI
        JMP   _JSL_2
_JSL_3:
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
        LEA   AX, _JSK_4
        MOV   [_JSV_re2], AX
        LEA   AX, _JSK_5
        MOV   [_JSV_s], AX
        MOV   AX, [_JSV_re2]
        MOV   DI, AX
        PUSH   DI
        MOV   AX, [_JSV_s]
        MOV   SI, AX
        POP   DI
        CALL   _JSRT_REMATCH
        MOV   [_JSV_found], AX
        MOV   AX, [_JSV_found]
        OR   AX, AX
        JNZ   _JSL_6
        LEA   DI, _JS_FALSE
        XOR   CX, CX
_JSL_8:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_9
        INC    CX
        INC    DI
        JMP   _JSL_8
_JSL_9:
        SUB   DI, CX
        LEA   DX, _JS_FALSE
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        JMP   _JSL_7
_JSL_6:
        LEA   DI, _JS_TRUE
        XOR   CX, CX
_JSL_10:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_11
        INC    CX
        INC    DI
        JMP   _JSL_10
_JSL_11:
        SUB   DI, CX
        LEA   DX, _JS_TRUE
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
_JSL_7:
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        LEA   AX, _JSK_12
        MOV   [_JSV_re3], AX
        MOV   AX, [_JSV_re3]
        MOV   DI, AX
        PUSH   DI
        MOV   AX, [_JSV_s]
        MOV   SI, AX
        POP   DI
        CALL   _JSRT_REMATCH
        MOV   [_JSV_notfound], AX
        MOV   AX, [_JSV_notfound]
        OR   AX, AX
        JNZ   _JSL_13
        LEA   DI, _JS_FALSE
        XOR   CX, CX
_JSL_15:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_16
        INC    CX
        INC    DI
        JMP   _JSL_15
_JSL_16:
        SUB   DI, CX
        LEA   DX, _JS_FALSE
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        JMP   _JSL_14
_JSL_13:
        LEA   DI, _JS_TRUE
        XOR   CX, CX
_JSL_17:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_18
        INC    CX
        INC    DI
        JMP   _JSL_17
_JSL_18:
        SUB   DI, CX
        LEA   DX, _JS_TRUE
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
_JSL_14:
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        MOV   AX, [_JSV_s]
        MOV   SI, AX
        PUSH   SI
        MOV   AX, [_JSV_re]
        MOV   DI, AX
        POP   SI
        CALL   _JSRT_REMATCH
        MOV   [_JSV_m], AX
        MOV   AX, [_JSV_m]
        OR   AX, AX
        JNZ   _JSL_19
        LEA   DI, _JS_FALSE
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
        LEA   DX, _JS_FALSE
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        JMP   _JSL_20
_JSL_19:
        LEA   DI, _JS_TRUE
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
        LEA   DX, _JS_TRUE
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
_JSL_20:
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        MOV   AX, [_JSV_s]
        MOV   SI, AX
        PUSH   SI
        MOV   AX, [_JSV_re2]
        MOV   DI, AX
        POP   SI
        CALL   _JSRT_REINDEX
        MOV   [_JSV_idx], AX
        MOV   AX, [_JSV_idx]
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_25:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_26
        INC    CX
        INC    DI
        JMP   _JSL_25
_JSL_26:
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
        MOV   AX, [_JSV_s]
        MOV   SI, AX
        PUSH   SI
        MOV   AX, [_JSV_re3]
        MOV   DI, AX
        POP   SI
        CALL   _JSRT_REINDEX
        MOV   [_JSV_idx2], AX
        MOV   AX, [_JSV_idx2]
        CALL   _JSRT_NUMTOSTR
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
        MOV   [_JSV_re4], AX
        MOV   AX, [_JSV_re4]
        MOV   DI, AX
        PUSH   DI
        MOV   AX, [_JSV_s]
        MOV   SI, AX
        POP   DI
        CALL   _JSRT_REMATCH
        MOV   [_JSV_t], AX
        MOV   AX, [_JSV_t]
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
        MOV   AX, [_JSV_re2]
        MOV   DI, AX
        PUSH   DI
        MOV   AX, [_JSV_s]
        MOV   SI, AX
        POP   DI
        CALL   _JSRT_REEXEC
        MOV   [_JSV_ex], AX
        MOV   AX, [_JSV_ex]
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_36:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_37
        INC    CX
        INC    DI
        JMP   _JSL_36
_JSL_37:
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
        LEA   AX, _JSK_38
        MOV   [_JSV_orig], AX
        MOV   AX, [_JSV_orig]
        MOV   SI, AX
        PUSH   SI
        LEA   AX, _JSK_39
        PUSH   AX
        LEA   AX, _JSK_40
        MOV   BX, AX
        POP   DI
        POP   SI
        CALL   _JSRT_RESUB
        MOV   [_JSV_rep], AX
        MOV   AX, [_JSV_rep]
        MOV   DI, AX
        XOR   CX, CX
_JSL_41:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_42
        INC    CX
        INC    DI
        JMP   _JSL_41
_JSL_42:
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
        LEA   AX, _JSK_43
        MOV   [_JSV_re5], AX
        MOV   AX, [_JSV_re5]
        MOV   DI, AX
        PUSH   DI
        LEA   AX, _JSK_44
        MOV   SI, AX
        POP   DI
        CALL   _JSRT_REMATCH
        MOV   [_JSV_r], AX
        MOV   AX, [_JSV_r]
        OR   AX, AX
        JNZ   _JSL_45
        LEA   DI, _JS_FALSE
        XOR   CX, CX
_JSL_47:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_48
        INC    CX
        INC    DI
        JMP   _JSL_47
_JSL_48:
        SUB   DI, CX
        LEA   DX, _JS_FALSE
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        JMP   _JSL_46
_JSL_45:
        LEA   DI, _JS_TRUE
        XOR   CX, CX
_JSL_49:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_50
        INC    CX
        INC    DI
        JMP   _JSL_49
_JSL_50:
        SUB   DI, CX
        LEA   DX, _JS_TRUE
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
_JSL_46:
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
        JZ   _JSL_51
        DEC   BX
        MOV   [SI], BX
        MOV   DI, BX
        SHL   DI, 1
        ADD   DI, 2
        ADD   DI, SI
        MOV   AX, [DI]
        RET
_JSL_51:
        XOR   AX, AX
        RET
_JSRT_ARRSHIFT:
        MOV   CX, [SI]
        OR   CX, CX
        JZ   _JSL_52
        MOV   AX, [SI+2]
        PUSH   AX
        DEC   CX
        MOV   [SI], CX
        LEA   DI, [SI+2]
        LEA   BX, [SI+4]
_JSL_53:
        OR   CX, CX
        JZ   _JSL_54
        MOV   AX, [BX]
        MOV   [DI], AX
        ADD   DI, 2
        ADD   BX, 2
        DEC   CX
        JMP   _JSL_53
_JSL_54:
        POP   AX
        RET
_JSL_52:
        XOR   AX, AX
        RET
_JSRT_ARRUNSHIFT:
        PUSH   AX
        MOV   CX, [SI]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        ADD   DI, 2
_JSL_55:
        OR   CX, CX
        JZ   _JSL_56
        MOV   AX, [DI-2]
        MOV   [DI], AX
        SUB   DI, 2
        DEC   CX
        JMP   _JSL_55
_JSL_56:
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
_JSL_57:
        OR   CX, CX
        JZ   _JSL_58
        CMP   [SI], BX
        JE   _JSL_59
        ADD   SI, 2
        INC   DX
        DEC   CX
        JMP   _JSL_57
_JSL_59:
        MOV   AX, DX
        RET
_JSL_58:
        MOV   AX, -1
        RET
_JSRT_ARRREV:
        MOV   CX, [SI]
        CMP   CX, 2
        JL   _JSL_60
        LEA   BX, [SI+2]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        SUB   DI, 2
_JSL_61:
        CMP   BX, DI
        JGE   _JSL_62
        MOV   AX, [BX]
        MOV   DX, [DI]
        MOV   [BX], DX
        MOV   [DI], AX
        ADD   BX, 2
        SUB   DI, 2
        JMP   _JSL_61
_JSL_62:
_JSL_60:
        MOV   AX, SI
        RET
_JSRT_ARRSORT:
        PUSH   SI
_JSL_63:
        XOR   DX, DX
        MOV   CX, [SI]
        DEC   CX
        CMP   CX, 0
        JLE   _JSL_66
        LEA   BX, [SI+2]
_JSL_64:
        MOV   AX, [BX]
        CMP   AX, [BX+2]
        JLE   _JSL_65
        MOV   DI, [BX+2]
        MOV   [BX], DI
        MOV   [BX+2], AX
        MOV   DX, 1
_JSL_65:
        ADD   BX, 2
        DEC   CX
        OR   CX, CX
        JNZ   _JSL_64
        OR   DX, DX
        JNZ   _JSL_63
_JSL_66:
        POP   AX
        RET

; --- runtime object routines (TODO 16) ---
_JSRT_STRCMP:
        PUSH   SI
        PUSH   DI
_JSL_67:
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_69
        OR   AL, AL
        JZ   _JSL_68
        INC   SI
        INC   DI
        JMP   _JSL_67
_JSL_68:
        XOR   AX, AX
        POP   DI
        POP   SI
        RET
_JSL_69:
        MOV   AX, 1
        POP   DI
        POP   SI
        RET
_JSRT_OBJGET:
        PUSH   CX
        PUSH   BX
        MOV   CX, [BX]
        ADD   BX, 2
_JSL_70:
        OR   CX, CX
        JZ   _JSL_72
        PUSH   CX
        PUSH   BX
        PUSH   DI
        MOV   SI, [BX]
        CALL   _JSRT_STRCMP
        POP   DI
        POP   BX
        POP   CX
        OR   AX, AX
        JZ   _JSL_71
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_70
_JSL_71:
        MOV   AX, [BX+2]
        POP   BX
        POP   CX
        RET
_JSL_72:
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
_JSL_73:
        OR   CX, CX
        JZ   _JSL_75
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
        JZ   _JSL_74
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_73
_JSL_74:
        MOV   [BX+2], DX
        MOV   AX, DX
        POP   BX
        POP   CX
        RET
_JSL_75:
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
_JSL_76:
        OR   CX, CX
        JZ   _JSL_77
        MOV   AX, [SI]
        MOV   [DI], AX
        ADD   SI, 4
        ADD   DI, 2
        DEC   CX
        JMP   _JSL_76
_JSL_77:
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
_JSL_78:
        OR   CX, CX
        JZ   _JSL_79
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
        JMP   _JSL_78
_JSL_79:
        POP   BX
        MOV   AX, BX
        POP   DI
        POP   CX
        RET

; --- runtime regexp routines (TODO 19) ---
_JSRT_REPARSE:
        PUSH   BX
        MOV   BX, DI
_JSL_80:
        MOV   AL, [BX]
        CMP   AL, 1
        JZ   _JSL_81
        OR   AL, AL
        JZ   _JSL_81
        INC   BX
        JMP   _JSL_80
_JSL_81:
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
        JZ   _JSL_84
_JSL_82:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_85
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   DX, CX
_JSL_83:
        OR   DX, DX
        JZ   _JSL_84B
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_85B
        INC   SI
        INC   DI
        DEC   DX
        JMP   _JSL_83
_JSL_84B:
        POP   CX
        POP   DI
        POP   SI
        JMP   _JSL_84
_JSL_85B:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_82
_JSL_84:
        MOV   AX, 1
        POP   DX
        POP   CX
        POP   BX
        POP   DI
        POP   SI
        RET
_JSL_85:
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
        JZ   _JSL_88
_JSL_86:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_89
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   DX, CX
_JSL_87:
        OR   DX, DX
        JZ   _JSL_88B
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_89B
        INC   SI
        INC   DI
        DEC   DX
        JMP   _JSL_87
_JSL_88B:
        POP   CX
        POP   DI
        POP   SI
        JMP   _JSL_88
_JSL_89B:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_86
_JSL_88:
        MOV   AX, SI
        SUB   AX, BX
        POP   DX
        POP   CX
        POP   BX
        POP   DI
        POP   SI
        RET
_JSL_89:
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
        JZ   _JSL_90
        MOV   AX, SI
        RET
_JSL_90:
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
_JSL_91:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_94
        OR   DX, DX
        JZ   _JSL_92C
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   CX, DX
_JSL_92:
        OR   CX, CX
        JZ   _JSL_93
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_92N
        INC   SI
        INC   DI
        DEC   CX
        JMP   _JSL_92
_JSL_92N:
        POP   CX
        POP   DI
        POP   SI
_JSL_92C:
        MOV   AL, [SI]
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_91
_JSL_93:
        POP   CX
        POP   DI
        POP   AX
        PUSH   SI
        MOV   SI, [SP+10]
_JSL_95:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_95D
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_95
_JSL_95D:
        POP   SI
_JSL_96:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_94
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_96
_JSL_94:
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
_JSL_97:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_98
        INC   AX
        INC   SI
        JMP   _JSL_97
_JSL_98:
        POP   SI
        RET
_JSRT_STRINDEXOF:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        MOV   BX, SI
_JSL_99:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_102
        PUSH   SI
        PUSH   DI
_JSL_100:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_101
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_100N
        INC   SI
        INC   DI
        JMP   _JSL_100
_JSL_101:
        POP   DI
        POP   AX
        SUB   AX, BX
        POP   DX
        POP   CX
        POP   BX
        RET
_JSL_100N:
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_99
_JSL_102:
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
_JSL_103:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_106
        PUSH   SI
        PUSH   DI
_JSL_104:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_105
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_104N
        INC   SI
        INC   DI
        JMP   _JSL_104
_JSL_105:
        POP   DI
        POP   AX
        SUB   AX, BX
        MOV   DX, AX
        ADD   AX, BX
        MOV   SI, AX
        INC   SI
        JMP   _JSL_103
_JSL_104N:
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_103
_JSL_106:
        MOV   AX, DX
        POP   DX
        POP   CX
        POP   BX
        RET
_JSRT_STRSTARTW:
_JSL_107:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_107Y
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_108
        INC   SI
        INC   DI
        JMP   _JSL_107
_JSL_107Y:
        MOV   AX, 1
        RET
_JSL_108:
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
        JA   _JSL_109
        SUB   BX, CX
        ADD   SI, BX
        POP   CX
        POP   BX
        JMP   _JSRT_STRSTARTW
_JSL_109:
        XOR   AX, AX
        POP   CX
        POP   BX
        RET
_JSRT_STRSLICE:
        PUSH   DI
        PUSH   DX
        LEA   DI, _JSRT_STRBUF
        MOV   DX, BX
_JSL_110:
        OR   DX, DX
        JZ   _JSL_111
        CMP   BYTE PTR [SI], 0
        JE   _JSL_112
        INC   SI
        DEC   DX
        JMP   _JSL_110
_JSL_111:
        CMP   BX, CX
        JGE   _JSL_112
        CMP   BYTE PTR [SI], 0
        JE   _JSL_112
        MOV   AL, [SI]
        MOV   [DI], AL
        INC   SI
        INC   DI
        INC   BX
        JMP   _JSL_111
_JSL_112:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DX
        POP   DI
        RET
_JSRT_STRTOUPPER:
        PUSH   DI
        LEA   DI, _JSRT_STRBUF
_JSL_113:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_114
        CMP   AL, 'a'
        JB   _JSL_113C
        CMP   AL, 'z'
        JA   _JSL_113C
        SUB   AL, 32
_JSL_113C:
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_113
_JSL_114:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DI
        RET
_JSRT_STRTOLOWER:
        PUSH   DI
        LEA   DI, _JSRT_STRBUF
_JSL_115:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_116
        CMP   AL, 'A'
        JB   _JSL_115C
        CMP   AL, 'Z'
        JA   _JSL_115C
        ADD   AL, 32
_JSL_115C:
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_115
_JSL_116:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DI
        RET
_JSRT_STRTRIM:
        PUSH   DI
        PUSH   BX
_JSL_117:
        MOV   AL, [SI]
        CMP   AL, 32
        JE   _JSL_117S
        CMP   AL, 9
        JE   _JSL_117S
        JMP   _JSL_118
_JSL_117S:
        INC   SI
        JMP   _JSL_117
_JSL_118:
        LEA   DI, _JSRT_STRBUF
        MOV   BX, DI
_JSL_120:
        MOV   AL, [SI]
        MOV   [DI], AL
        OR   AL, AL
        JZ   _JSL_119
        INC   SI
        INC   DI
        JMP   _JSL_120
_JSL_119:
_JSL_121:
        DEC   DI
        CMP   DI, BX
        JB   _JSL_121D
        CMP   BYTE PTR [DI], 32
        JE   _JSL_121
        CMP   BYTE PTR [DI], 9
        JE   _JSL_121
_JSL_121D:
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
_JSL_122:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_125
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   CX, DX
_JSL_123:
        OR   CX, CX
        JZ   _JSL_124
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_123N
        INC   SI
        INC   DI
        DEC   CX
        JMP   _JSL_123
_JSL_123N:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_122
_JSL_124:
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
        JMP   _JSL_122
_JSL_125:
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
_JSL_126:
        OR   CX, CX
        JZ   _JSL_128
        MOV   SI, DX
_JSL_127:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_127D
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_127
_JSL_127D:
        DEC   CX
        JMP   _JSL_126
_JSL_128:
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
        JAE   _JSL_131
        SUB   CX, DX
        LEA   BX, _JSRT_STRBUF
        PUSH   SI
        MOV   SI, DI
_JSL_129:
        OR   CX, CX
        JZ   _JSL_130
        MOV   AL, [SI]
        OR   AL, AL
        JNZ   _JSL_129C
        MOV   SI, DI
        MOV   AL, [SI]
_JSL_129C:
        MOV   [BX], AL
        INC   BX
        INC   SI
        DEC   CX
        JMP   _JSL_129
_JSL_130:
        POP   SI
_JSL_132:
        MOV   AL, [SI]
        MOV   [BX], AL
        OR   AL, AL
        JZ   _JSL_132D
        INC   SI
        INC   BX
        JMP   _JSL_132
_JSL_132D:
        LEA   AX, _JSRT_STRBUF
        POP   DX
        POP   BX
        RET
_JSL_131:
        LEA   BX, _JSRT_STRBUF
_JSL_133:
        MOV   AL, [SI]
        MOV   [BX], AL
        OR   AL, AL
        JZ   _JSL_133D
        INC   SI
        INC   BX
        JMP   _JSL_133
_JSL_133D:
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
_JSL_134:
        CMP   BYTE PTR [SI], 32
        JE   _JSL_134S
        JMP   _JSL_134E
_JSL_134S:
        INC   SI
        JMP   _JSL_134
_JSL_134E:
        CMP   BYTE PTR [SI], '-'
        JNE   _JSL_134P
        MOV   BX, 1
        INC   SI
        JMP   _JSL_135
_JSL_134P:
        CMP   BYTE PTR [SI], '+'
        JNE   _JSL_135
        INC   SI
_JSL_135:
        XOR   DX, DX
        MOV   DL, [SI]
        OR   DL, DL
        JZ   _JSL_136
        CMP   DL, '0'
        JB   _JSL_136
        CMP   DL, '9'
        JA   _JSL_135H
        SUB   DL, '0'
        JMP   _JSL_135M
_JSL_135H:
        CMP   DL, 'a'
        JB   _JSL_135U
        CMP   DL, 'f'
        JA   _JSL_136
        SUB   DL, 'a'
        ADD   DL, 10
        JMP   _JSL_135M
_JSL_135U:
        CMP   DL, 'A'
        JB   _JSL_136
        CMP   DL, 'F'
        JA   _JSL_136
        SUB   DL, 'A'
        ADD   DL, 10
_JSL_135M:
        CMP   DL, CL
        JAE   _JSL_136
        PUSH   DX
        PUSH   CX
        MUL    CX
        POP   CX
        POP   DX
        ADD   AX, DX
        INC   SI
        JMP   _JSL_135
_JSL_136:
        OR   BX, BX
        JZ   _JSL_136D
        NEG    AX
_JSL_136D:
        POP   DX
        POP   BX
        RET
_JSRT_ABS:
        OR   AX, AX
        JNS   _JSL_137
        NEG    AX
_JSL_137:
        RET
_JSRT_POW:
        PUSH   CX
        PUSH   DX
        MOV   CX, BX
        MOV   BX, AX
        MOV   AX, 1
_JSL_138:
        OR   CX, CX
        JZ   _JSL_139
        PUSH   DX
        MUL    BX
        POP   DX
        DEC   CX
        JMP   _JSL_138
_JSL_139:
        POP   DX
        POP   CX
        RET
_JSRT_SQRT:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        OR   AX, AX
        JZ   _JSL_141
        MOV   BX, AX
        SHR   AX, 1
        OR   AX, AX
        JZ   _JSL_141O
_JSL_140:
        MOV   CX, AX
        PUSH   BX
        XOR   DX, DX
        MOV   AX, BX
        DIV    CX
        POP   BX
        ADD   AX, CX
        SHR   AX, 1
        CMP   AX, CX
        JB   _JSL_140
        MOV   AX, CX
_JSL_141:
        POP   DX
        POP   CX
        POP   BX
        RET
_JSL_141O:
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
        JZ   _JSL_143
        JS   _JSL_142
        MOV   AX, 1
        JMP   _JSL_143
_JSL_142:
        MOV   AX, 0FFFFh
_JSL_143:
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
_JSV_re  DW  0
_JSK_1  DB  'hello',0
_JSV_re2  DW  0
_JSK_4  DB  'world',0
_JSV_s  DW  0
_JSK_5  DB  'hello world',0
_JSV_found  DW  0
_JSV_re3  DW  0
_JSK_12  DB  'xyz',0
_JSV_notfound  DW  0
_JSV_m  DW  0
_JSV_idx  DW  0
_JSV_idx2  DW  0
_JSV_re4  DW  0
_JSK_29  DB  'llog',0
_JSV_t  DW  0
_JSV_ex  DW  0
_JSV_orig  DW  0
_JSK_38  DB  'foo bar foo',0
_JSV_rep  DW  0
_JSK_39  DB  'foo',0
_JSK_40  DB  'baz',0
_JSV_re5  DW  0
_JSK_43  DB  'test',0
_JSV_r  DW  0
_JSK_44  DB  'this is a test',0
_DATA   ENDS

        END
