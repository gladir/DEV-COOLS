; Genere par JS86 v1.0 - SAMPLES\JS\test13.js

        .MODEL SMALL
        .STACK 1024

_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME  CS:_TEXT, DS:_DATA, SS:STACK

; --- debut du code genere ---

        MOV   AX, 10
        MOV   [_JSV_x], AX
        MOV   AX, [_JSV_x]
        OR   AX, AX
        JZ   _JSL_2
        MOV   AX, 1
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_3:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_4
        INC    CX
        INC    DI
        JMP   _JSL_3
_JSL_4:
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
_JSL_2:
_JSL_1:
        JMP   _JSL_6
        MOV   AX, 99
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
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        JMP   _JSL_5
_JSL_6:
        MOV   AX, 2
        CALL   _JSRT_NUMTOSTR
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
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
_JSL_5:
        MOV   AX, 5
        MOV   [_JSV_y], AX
        MOV   AX, [_JSV_y]
        PUSH   AX
        MOV   AX, 10
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JNE   _JSL_12
        INC    AX
_JSL_12:
        OR   AX, AX
        JZ   _JSL_13
        MOV   AX, 99
        CALL   _JSRT_NUMTOSTR
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
        JMP   _JSL_11
_JSL_13:
        MOV   AX, [_JSV_y]
        PUSH   AX
        MOV   AX, 5
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JNE   _JSL_17
        INC    AX
_JSL_17:
        OR   AX, AX
        JZ   _JSL_18
        MOV   AX, 3
        CALL   _JSRT_NUMTOSTR
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
_JSL_18:
        MOV   AX, 99
        CALL   _JSRT_NUMTOSTR
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
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
_JSL_16:
_JSL_11:
        MOV   AX, 2
        MOV   [_JSV_z], AX
        MOV   AX, [_JSV_z]
        PUSH   AX
        POP   BX
        PUSH   BX
        MOV   AX, 1
        CMP   BX, AX
        JNE   _JSL_24
        MOV   AX, 99
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
        JMP   _JSL_23
_JSL_24:
        POP   BX
        PUSH   BX
        MOV   AX, 2
        CMP   BX, AX
        JNE   _JSL_27
        MOV   AX, 4
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_28:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_29
        INC    CX
        INC    DI
        JMP   _JSL_28
_JSL_29:
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
        JMP   _JSL_23
_JSL_27:
        POP   BX
        PUSH   BX
        MOV   AX, 3
        CMP   BX, AX
        JNE   _JSL_30
        MOV   AX, 99
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_31:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_32
        INC    CX
        INC    DI
        JMP   _JSL_31
_JSL_32:
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
        JMP   _JSL_23
_JSL_30:
        MOV   AX, 99
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_33:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_34
        INC    CX
        INC    DI
        JMP   _JSL_33
_JSL_34:
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
        JMP   _JSL_23
_JSL_23:
        ADD   SP, 2
        MOV   AX, 99
        MOV   [_JSV_w], AX
        MOV   AX, [_JSV_w]
        PUSH   AX
        POP   BX
        PUSH   BX
        MOV   AX, 1
        CMP   BX, AX
        JNE   _JSL_36
        MOV   AX, 99
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_37:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_38
        INC    CX
        INC    DI
        JMP   _JSL_37
_JSL_38:
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
        JMP   _JSL_35
_JSL_36:
        MOV   AX, 5
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_39:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_40
        INC    CX
        INC    DI
        JMP   _JSL_39
_JSL_40:
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
        JMP   _JSL_35
_JSL_35:
        ADD   SP, 2
        MOV   AX, 0
        MOV   AH, 4Ch
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
        JZ   _JSL_41
        DEC   BX
        MOV   [SI], BX
        MOV   DI, BX
        SHL   DI, 1
        ADD   DI, 2
        ADD   DI, SI
        MOV   AX, [DI]
        RET
_JSL_41:
        XOR   AX, AX
        RET
_JSRT_ARRSHIFT:
        MOV   CX, [SI]
        OR   CX, CX
        JZ   _JSL_42
        MOV   AX, [SI+2]
        PUSH   AX
        DEC   CX
        MOV   [SI], CX
        LEA   DI, [SI+2]
        LEA   BX, [SI+4]
_JSL_43:
        OR   CX, CX
        JZ   _JSL_44
        MOV   AX, [BX]
        MOV   [DI], AX
        ADD   DI, 2
        ADD   BX, 2
        DEC   CX
        JMP   _JSL_43
_JSL_44:
        POP   AX
        RET
_JSL_42:
        XOR   AX, AX
        RET
_JSRT_ARRUNSHIFT:
        PUSH   AX
        MOV   CX, [SI]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        ADD   DI, 2
_JSL_45:
        OR   CX, CX
        JZ   _JSL_46
        MOV   AX, [DI-2]
        MOV   [DI], AX
        SUB   DI, 2
        DEC   CX
        JMP   _JSL_45
_JSL_46:
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
_JSL_47:
        OR   CX, CX
        JZ   _JSL_48
        CMP   [SI], BX
        JE   _JSL_49
        ADD   SI, 2
        INC   DX
        DEC   CX
        JMP   _JSL_47
_JSL_49:
        MOV   AX, DX
        RET
_JSL_48:
        MOV   AX, -1
        RET
_JSRT_ARRREV:
        MOV   CX, [SI]
        CMP   CX, 2
        JL   _JSL_50
        LEA   BX, [SI+2]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        SUB   DI, 2
_JSL_51:
        CMP   BX, DI
        JGE   _JSL_52
        MOV   AX, [BX]
        MOV   DX, [DI]
        MOV   [BX], DX
        MOV   [DI], AX
        ADD   BX, 2
        SUB   DI, 2
        JMP   _JSL_51
_JSL_52:
_JSL_50:
        MOV   AX, SI
        RET
_JSRT_ARRSORT:
        PUSH   SI
_JSL_53:
        XOR   DX, DX
        MOV   CX, [SI]
        DEC   CX
        CMP   CX, 0
        JLE   _JSL_56
        LEA   BX, [SI+2]
_JSL_54:
        MOV   AX, [BX]
        CMP   AX, [BX+2]
        JLE   _JSL_55
        MOV   DI, [BX+2]
        MOV   [BX], DI
        MOV   [BX+2], AX
        MOV   DX, 1
_JSL_55:
        ADD   BX, 2
        DEC   CX
        OR   CX, CX
        JNZ   _JSL_54
        OR   DX, DX
        JNZ   _JSL_53
_JSL_56:
        POP   AX
        RET

; --- runtime object routines (TODO 16) ---
_JSRT_STRCMP:
        PUSH   SI
        PUSH   DI
_JSL_57:
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_59
        OR   AL, AL
        JZ   _JSL_58
        INC   SI
        INC   DI
        JMP   _JSL_57
_JSL_58:
        XOR   AX, AX
        POP   DI
        POP   SI
        RET
_JSL_59:
        MOV   AX, 1
        POP   DI
        POP   SI
        RET
_JSRT_OBJGET:
        PUSH   CX
        PUSH   BX
        MOV   CX, [BX]
        ADD   BX, 2
_JSL_60:
        OR   CX, CX
        JZ   _JSL_62
        PUSH   CX
        PUSH   BX
        PUSH   DI
        MOV   SI, [BX]
        CALL   _JSRT_STRCMP
        POP   DI
        POP   BX
        POP   CX
        OR   AX, AX
        JZ   _JSL_61
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_60
_JSL_61:
        MOV   AX, [BX+2]
        POP   BX
        POP   CX
        RET
_JSL_62:
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
_JSL_63:
        OR   CX, CX
        JZ   _JSL_65
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
        JZ   _JSL_64
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_63
_JSL_64:
        MOV   [BX+2], DX
        MOV   AX, DX
        POP   BX
        POP   CX
        RET
_JSL_65:
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
_JSL_66:
        OR   CX, CX
        JZ   _JSL_67
        MOV   AX, [SI]
        MOV   [DI], AX
        ADD   SI, 4
        ADD   DI, 2
        DEC   CX
        JMP   _JSL_66
_JSL_67:
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
_JSL_68:
        OR   CX, CX
        JZ   _JSL_69
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
        JMP   _JSL_68
_JSL_69:
        POP   BX
        MOV   AX, BX
        POP   DI
        POP   CX
        RET

; --- runtime regexp routines (TODO 19) ---
_JSRT_REPARSE:
        PUSH   BX
        MOV   BX, DI
_JSL_70:
        MOV   AL, [BX]
        CMP   AL, 1
        JZ   _JSL_71
        OR   AL, AL
        JZ   _JSL_71
        INC   BX
        JMP   _JSL_70
_JSL_71:
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
        JZ   _JSL_74
_JSL_72:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_75
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   DX, CX
_JSL_73:
        OR   DX, DX
        JZ   _JSL_74B
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_75B
        INC   SI
        INC   DI
        DEC   DX
        JMP   _JSL_73
_JSL_74B:
        POP   CX
        POP   DI
        POP   SI
        JMP   _JSL_74
_JSL_75B:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_72
_JSL_74:
        MOV   AX, 1
        POP   DX
        POP   CX
        POP   BX
        POP   DI
        POP   SI
        RET
_JSL_75:
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
        JZ   _JSL_78
_JSL_76:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_79
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   DX, CX
_JSL_77:
        OR   DX, DX
        JZ   _JSL_78B
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_79B
        INC   SI
        INC   DI
        DEC   DX
        JMP   _JSL_77
_JSL_78B:
        POP   CX
        POP   DI
        POP   SI
        JMP   _JSL_78
_JSL_79B:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_76
_JSL_78:
        MOV   AX, SI
        SUB   AX, BX
        POP   DX
        POP   CX
        POP   BX
        POP   DI
        POP   SI
        RET
_JSL_79:
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
        JZ   _JSL_80
        MOV   AX, SI
        RET
_JSL_80:
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
_JSL_81:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_84
        OR   DX, DX
        JZ   _JSL_82C
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   CX, DX
_JSL_82:
        OR   CX, CX
        JZ   _JSL_83
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_82N
        INC   SI
        INC   DI
        DEC   CX
        JMP   _JSL_82
_JSL_82N:
        POP   CX
        POP   DI
        POP   SI
_JSL_82C:
        MOV   AL, [SI]
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_81
_JSL_83:
        POP   CX
        POP   DI
        POP   AX
        PUSH   SI
        MOV   SI, [SP+10]
_JSL_85:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_85D
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_85
_JSL_85D:
        POP   SI
_JSL_86:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_84
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_86
_JSL_84:
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
_JSL_87:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_88
        INC   AX
        INC   SI
        JMP   _JSL_87
_JSL_88:
        POP   SI
        RET
_JSRT_STRINDEXOF:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        MOV   BX, SI
_JSL_89:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_92
        PUSH   SI
        PUSH   DI
_JSL_90:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_91
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_90N
        INC   SI
        INC   DI
        JMP   _JSL_90
_JSL_91:
        POP   DI
        POP   AX
        SUB   AX, BX
        POP   DX
        POP   CX
        POP   BX
        RET
_JSL_90N:
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_89
_JSL_92:
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
_JSL_93:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_96
        PUSH   SI
        PUSH   DI
_JSL_94:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_95
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_94N
        INC   SI
        INC   DI
        JMP   _JSL_94
_JSL_95:
        POP   DI
        POP   AX
        SUB   AX, BX
        MOV   DX, AX
        ADD   AX, BX
        MOV   SI, AX
        INC   SI
        JMP   _JSL_93
_JSL_94N:
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_93
_JSL_96:
        MOV   AX, DX
        POP   DX
        POP   CX
        POP   BX
        RET
_JSRT_STRSTARTW:
_JSL_97:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_97Y
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_98
        INC   SI
        INC   DI
        JMP   _JSL_97
_JSL_97Y:
        MOV   AX, 1
        RET
_JSL_98:
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
        JA   _JSL_99
        SUB   BX, CX
        ADD   SI, BX
        POP   CX
        POP   BX
        JMP   _JSRT_STRSTARTW
_JSL_99:
        XOR   AX, AX
        POP   CX
        POP   BX
        RET
_JSRT_STRSLICE:
        PUSH   DI
        PUSH   DX
        LEA   DI, _JSRT_STRBUF
        MOV   DX, BX
_JSL_100:
        OR   DX, DX
        JZ   _JSL_101
        CMP   BYTE PTR [SI], 0
        JE   _JSL_102
        INC   SI
        DEC   DX
        JMP   _JSL_100
_JSL_101:
        CMP   BX, CX
        JGE   _JSL_102
        CMP   BYTE PTR [SI], 0
        JE   _JSL_102
        MOV   AL, [SI]
        MOV   [DI], AL
        INC   SI
        INC   DI
        INC   BX
        JMP   _JSL_101
_JSL_102:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DX
        POP   DI
        RET
_JSRT_STRTOUPPER:
        PUSH   DI
        LEA   DI, _JSRT_STRBUF
_JSL_103:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_104
        CMP   AL, 'a'
        JB   _JSL_103C
        CMP   AL, 'z'
        JA   _JSL_103C
        SUB   AL, 32
_JSL_103C:
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_103
_JSL_104:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DI
        RET
_JSRT_STRTOLOWER:
        PUSH   DI
        LEA   DI, _JSRT_STRBUF
_JSL_105:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_106
        CMP   AL, 'A'
        JB   _JSL_105C
        CMP   AL, 'Z'
        JA   _JSL_105C
        ADD   AL, 32
_JSL_105C:
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_105
_JSL_106:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DI
        RET
_JSRT_STRTRIM:
        PUSH   DI
        PUSH   BX
_JSL_107:
        MOV   AL, [SI]
        CMP   AL, 32
        JE   _JSL_107S
        CMP   AL, 9
        JE   _JSL_107S
        JMP   _JSL_108
_JSL_107S:
        INC   SI
        JMP   _JSL_107
_JSL_108:
        LEA   DI, _JSRT_STRBUF
        MOV   BX, DI
_JSL_110:
        MOV   AL, [SI]
        MOV   [DI], AL
        OR   AL, AL
        JZ   _JSL_109
        INC   SI
        INC   DI
        JMP   _JSL_110
_JSL_109:
_JSL_111:
        DEC   DI
        CMP   DI, BX
        JB   _JSL_111D
        CMP   BYTE PTR [DI], 32
        JE   _JSL_111
        CMP   BYTE PTR [DI], 9
        JE   _JSL_111
_JSL_111D:
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
_JSL_112:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_115
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   CX, DX
_JSL_113:
        OR   CX, CX
        JZ   _JSL_114
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_113N
        INC   SI
        INC   DI
        DEC   CX
        JMP   _JSL_113
_JSL_113N:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_112
_JSL_114:
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
        JMP   _JSL_112
_JSL_115:
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
_JSL_116:
        OR   CX, CX
        JZ   _JSL_118
        MOV   SI, DX
_JSL_117:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_117D
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_117
_JSL_117D:
        DEC   CX
        JMP   _JSL_116
_JSL_118:
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
        JAE   _JSL_121
        SUB   CX, DX
        LEA   BX, _JSRT_STRBUF
        PUSH   SI
        MOV   SI, DI
_JSL_119:
        OR   CX, CX
        JZ   _JSL_120
        MOV   AL, [SI]
        OR   AL, AL
        JNZ   _JSL_119C
        MOV   SI, DI
        MOV   AL, [SI]
_JSL_119C:
        MOV   [BX], AL
        INC   BX
        INC   SI
        DEC   CX
        JMP   _JSL_119
_JSL_120:
        POP   SI
_JSL_122:
        MOV   AL, [SI]
        MOV   [BX], AL
        OR   AL, AL
        JZ   _JSL_122D
        INC   SI
        INC   BX
        JMP   _JSL_122
_JSL_122D:
        LEA   AX, _JSRT_STRBUF
        POP   DX
        POP   BX
        RET
_JSL_121:
        LEA   BX, _JSRT_STRBUF
_JSL_123:
        MOV   AL, [SI]
        MOV   [BX], AL
        OR   AL, AL
        JZ   _JSL_123D
        INC   SI
        INC   BX
        JMP   _JSL_123
_JSL_123D:
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
_JSL_124:
        CMP   BYTE PTR [SI], 32
        JE   _JSL_124S
        JMP   _JSL_124E
_JSL_124S:
        INC   SI
        JMP   _JSL_124
_JSL_124E:
        CMP   BYTE PTR [SI], '-'
        JNE   _JSL_124P
        MOV   BX, 1
        INC   SI
        JMP   _JSL_125
_JSL_124P:
        CMP   BYTE PTR [SI], '+'
        JNE   _JSL_125
        INC   SI
_JSL_125:
        XOR   DX, DX
        MOV   DL, [SI]
        OR   DL, DL
        JZ   _JSL_126
        CMP   DL, '0'
        JB   _JSL_126
        CMP   DL, '9'
        JA   _JSL_125H
        SUB   DL, '0'
        JMP   _JSL_125M
_JSL_125H:
        CMP   DL, 'a'
        JB   _JSL_125U
        CMP   DL, 'f'
        JA   _JSL_126
        SUB   DL, 'a'
        ADD   DL, 10
        JMP   _JSL_125M
_JSL_125U:
        CMP   DL, 'A'
        JB   _JSL_126
        CMP   DL, 'F'
        JA   _JSL_126
        SUB   DL, 'A'
        ADD   DL, 10
_JSL_125M:
        CMP   DL, CL
        JAE   _JSL_126
        PUSH   DX
        PUSH   CX
        MUL    CX
        POP   CX
        POP   DX
        ADD   AX, DX
        INC   SI
        JMP   _JSL_125
_JSL_126:
        OR   BX, BX
        JZ   _JSL_126D
        NEG    AX
_JSL_126D:
        POP   DX
        POP   BX
        RET
_JSRT_ABS:
        OR   AX, AX
        JNS   _JSL_127
        NEG    AX
_JSL_127:
        RET
_JSRT_POW:
        PUSH   CX
        PUSH   DX
        MOV   CX, BX
        MOV   BX, AX
        MOV   AX, 1
_JSL_128:
        OR   CX, CX
        JZ   _JSL_129
        PUSH   DX
        MUL    BX
        POP   DX
        DEC   CX
        JMP   _JSL_128
_JSL_129:
        POP   DX
        POP   CX
        RET
_JSRT_SQRT:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        OR   AX, AX
        JZ   _JSL_131
        MOV   BX, AX
        SHR   AX, 1
        OR   AX, AX
        JZ   _JSL_131O
_JSL_130:
        MOV   CX, AX
        PUSH   BX
        XOR   DX, DX
        MOV   AX, BX
        DIV    CX
        POP   BX
        ADD   AX, CX
        SHR   AX, 1
        CMP   AX, CX
        JB   _JSL_130
        MOV   AX, CX
_JSL_131:
        POP   DX
        POP   CX
        POP   BX
        RET
_JSL_131O:
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
        JZ   _JSL_133
        JS   _JSL_132
        MOV   AX, 1
        JMP   _JSL_133
_JSL_132:
        MOV   AX, 0FFFFh
_JSL_133:
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
_JSV_x  DW  0
_JSV_y  DW  0
_JSV_z  DW  0
_JSV_w  DW  0
_DATA   ENDS

        END
