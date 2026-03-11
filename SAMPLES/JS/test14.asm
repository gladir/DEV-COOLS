; Genere par JS86 v1.0 - SAMPLES\JS\test14.js

        .MODEL SMALL
        .STACK 1024

_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME  CS:_TEXT, DS:_DATA, SS:STACK

; --- debut du code genere ---

        MOV   AX, 0
        MOV   [_JSV_sum], AX
        MOV   AX, 1
        MOV   [_JSV_i], AX
_JSL_1:
        MOV   AX, [_JSV_i]
        PUSH   AX
        MOV   AX, 5
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JG   _JSL_3
        INC    AX
_JSL_3:
        OR   AX, AX
        JZ   _JSL_2
        MOV   AX, [_JSV_sum]
        PUSH   AX
        MOV   AX, [_JSV_i]
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [_JSV_sum], AX
        MOV   AX, [_JSV_i]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [_JSV_i], AX
        JMP   _JSL_1
_JSL_2:
        MOV   AX, [_JSV_sum]
        CALL   _JSRT_NUMTOSTR
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
        MOV   AX, 0
        MOV   [_JSV_s2], AX
        MOV   AX, 1
        MOV   [_JSV_j], AX
_JSL_6:
        MOV   AX, [_JSV_s2]
        PUSH   AX
        MOV   AX, [_JSV_j]
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [_JSV_s2], AX
        MOV   AX, [_JSV_j]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [_JSV_j], AX
_JSL_7:
        MOV   AX, [_JSV_j]
        PUSH   AX
        MOV   AX, 3
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JG   _JSL_9
        INC    AX
_JSL_9:
        OR   AX, AX
        JNZ   _JSL_6
_JSL_8:
        MOV   AX, [_JSV_s2]
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
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
        MOV   [_JSV_s3], AX
        MOV   AX, 0
        MOV   [_JSV_k], AX
_JSL_12:
        MOV   AX, [_JSV_k]
        PUSH   AX
        MOV   AX, 5
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JGE   _JSL_15
        INC    AX
_JSL_15:
        OR   AX, AX
        JZ   _JSL_14
        JMP   _JSL_16
_JSL_13:
        MOV   AX, [_JSV_k]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [_JSV_k], AX
        JMP   _JSL_12
_JSL_16:
        MOV   AX, [_JSV_s3]
        PUSH   AX
        MOV   AX, [_JSV_k]
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [_JSV_s3], AX
        JMP   _JSL_13
_JSL_14:
        MOV   AX, [_JSV_s3]
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
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
        MOV   [_JSV_s4], AX
        MOV   AX, 0
        MOV   [_JSV_m], AX
_JSL_19:
        MOV   AX, 1
        OR   AX, AX
        JZ   _JSL_20
        MOV   AX, [_JSV_m]
        PUSH   AX
        MOV   AX, 3
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JNE   _JSL_22
        INC    AX
_JSL_22:
        OR   AX, AX
        JZ   _JSL_23
        JMP   _JSL_20
_JSL_23:
_JSL_21:
        MOV   AX, [_JSV_s4]
        PUSH   AX
        MOV   AX, [_JSV_m]
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [_JSV_s4], AX
        MOV   AX, [_JSV_m]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [_JSV_m], AX
        JMP   _JSL_19
_JSL_20:
        MOV   AX, [_JSV_s4]
        CALL   _JSRT_NUMTOSTR
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
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        MOV   AX, 0
        MOV   [_JSV_s5], AX
        MOV   AX, 0
        MOV   [_JSV_n], AX
_JSL_26:
        MOV   AX, [_JSV_n]
        PUSH   AX
        MOV   AX, 5
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JGE   _JSL_29
        INC    AX
_JSL_29:
        OR   AX, AX
        JZ   _JSL_28
        JMP   _JSL_30
_JSL_27:
        MOV   AX, [_JSV_n]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [_JSV_n], AX
        JMP   _JSL_26
_JSL_30:
        MOV   AX, [_JSV_n]
        PUSH   AX
        MOV   AX, 2
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JNE   _JSL_32
        INC    AX
_JSL_32:
        OR   AX, AX
        JZ   _JSL_33
        JMP   _JSL_27
_JSL_33:
_JSL_31:
        MOV   AX, [_JSV_s5]
        PUSH   AX
        MOV   AX, [_JSV_n]
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [_JSV_s5], AX
        JMP   _JSL_27
_JSL_28:
        MOV   AX, [_JSV_s5]
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
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
        JZ   _JSL_36
        DEC   BX
        MOV   [SI], BX
        MOV   DI, BX
        SHL   DI, 1
        ADD   DI, 2
        ADD   DI, SI
        MOV   AX, [DI]
        RET
_JSL_36:
        XOR   AX, AX
        RET
_JSRT_ARRSHIFT:
        MOV   CX, [SI]
        OR   CX, CX
        JZ   _JSL_37
        MOV   AX, [SI+2]
        PUSH   AX
        DEC   CX
        MOV   [SI], CX
        LEA   DI, [SI+2]
        LEA   BX, [SI+4]
_JSL_38:
        OR   CX, CX
        JZ   _JSL_39
        MOV   AX, [BX]
        MOV   [DI], AX
        ADD   DI, 2
        ADD   BX, 2
        DEC   CX
        JMP   _JSL_38
_JSL_39:
        POP   AX
        RET
_JSL_37:
        XOR   AX, AX
        RET
_JSRT_ARRUNSHIFT:
        PUSH   AX
        MOV   CX, [SI]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        ADD   DI, 2
_JSL_40:
        OR   CX, CX
        JZ   _JSL_41
        MOV   AX, [DI-2]
        MOV   [DI], AX
        SUB   DI, 2
        DEC   CX
        JMP   _JSL_40
_JSL_41:
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
_JSL_42:
        OR   CX, CX
        JZ   _JSL_43
        CMP   [SI], BX
        JE   _JSL_44
        ADD   SI, 2
        INC   DX
        DEC   CX
        JMP   _JSL_42
_JSL_44:
        MOV   AX, DX
        RET
_JSL_43:
        MOV   AX, -1
        RET
_JSRT_ARRREV:
        MOV   CX, [SI]
        CMP   CX, 2
        JL   _JSL_45
        LEA   BX, [SI+2]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        SUB   DI, 2
_JSL_46:
        CMP   BX, DI
        JGE   _JSL_47
        MOV   AX, [BX]
        MOV   DX, [DI]
        MOV   [BX], DX
        MOV   [DI], AX
        ADD   BX, 2
        SUB   DI, 2
        JMP   _JSL_46
_JSL_47:
_JSL_45:
        MOV   AX, SI
        RET
_JSRT_ARRSORT:
        PUSH   SI
_JSL_48:
        XOR   DX, DX
        MOV   CX, [SI]
        DEC   CX
        CMP   CX, 0
        JLE   _JSL_51
        LEA   BX, [SI+2]
_JSL_49:
        MOV   AX, [BX]
        CMP   AX, [BX+2]
        JLE   _JSL_50
        MOV   DI, [BX+2]
        MOV   [BX], DI
        MOV   [BX+2], AX
        MOV   DX, 1
_JSL_50:
        ADD   BX, 2
        DEC   CX
        OR   CX, CX
        JNZ   _JSL_49
        OR   DX, DX
        JNZ   _JSL_48
_JSL_51:
        POP   AX
        RET

; --- runtime object routines (TODO 16) ---
_JSRT_STRCMP:
        PUSH   SI
        PUSH   DI
_JSL_52:
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_54
        OR   AL, AL
        JZ   _JSL_53
        INC   SI
        INC   DI
        JMP   _JSL_52
_JSL_53:
        XOR   AX, AX
        POP   DI
        POP   SI
        RET
_JSL_54:
        MOV   AX, 1
        POP   DI
        POP   SI
        RET
_JSRT_OBJGET:
        PUSH   CX
        PUSH   BX
        MOV   CX, [BX]
        ADD   BX, 2
_JSL_55:
        OR   CX, CX
        JZ   _JSL_57
        PUSH   CX
        PUSH   BX
        PUSH   DI
        MOV   SI, [BX]
        CALL   _JSRT_STRCMP
        POP   DI
        POP   BX
        POP   CX
        OR   AX, AX
        JZ   _JSL_56
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_55
_JSL_56:
        MOV   AX, [BX+2]
        POP   BX
        POP   CX
        RET
_JSL_57:
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
_JSL_58:
        OR   CX, CX
        JZ   _JSL_60
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
        JZ   _JSL_59
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_58
_JSL_59:
        MOV   [BX+2], DX
        MOV   AX, DX
        POP   BX
        POP   CX
        RET
_JSL_60:
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
_JSL_61:
        OR   CX, CX
        JZ   _JSL_62
        MOV   AX, [SI]
        MOV   [DI], AX
        ADD   SI, 4
        ADD   DI, 2
        DEC   CX
        JMP   _JSL_61
_JSL_62:
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
_JSL_63:
        OR   CX, CX
        JZ   _JSL_64
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
        JMP   _JSL_63
_JSL_64:
        POP   BX
        MOV   AX, BX
        POP   DI
        POP   CX
        RET

; --- runtime regexp routines (TODO 19) ---
_JSRT_REPARSE:
        PUSH   BX
        MOV   BX, DI
_JSL_65:
        MOV   AL, [BX]
        CMP   AL, 1
        JZ   _JSL_66
        OR   AL, AL
        JZ   _JSL_66
        INC   BX
        JMP   _JSL_65
_JSL_66:
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
        JZ   _JSL_69
_JSL_67:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_70
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   DX, CX
_JSL_68:
        OR   DX, DX
        JZ   _JSL_69B
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_70B
        INC   SI
        INC   DI
        DEC   DX
        JMP   _JSL_68
_JSL_69B:
        POP   CX
        POP   DI
        POP   SI
        JMP   _JSL_69
_JSL_70B:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_67
_JSL_69:
        MOV   AX, 1
        POP   DX
        POP   CX
        POP   BX
        POP   DI
        POP   SI
        RET
_JSL_70:
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
        JZ   _JSL_73
_JSL_71:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_74
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   DX, CX
_JSL_72:
        OR   DX, DX
        JZ   _JSL_73B
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_74B
        INC   SI
        INC   DI
        DEC   DX
        JMP   _JSL_72
_JSL_73B:
        POP   CX
        POP   DI
        POP   SI
        JMP   _JSL_73
_JSL_74B:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_71
_JSL_73:
        MOV   AX, SI
        SUB   AX, BX
        POP   DX
        POP   CX
        POP   BX
        POP   DI
        POP   SI
        RET
_JSL_74:
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
        JZ   _JSL_75
        MOV   AX, SI
        RET
_JSL_75:
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
_JSL_76:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_79
        OR   DX, DX
        JZ   _JSL_77C
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   CX, DX
_JSL_77:
        OR   CX, CX
        JZ   _JSL_78
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_77N
        INC   SI
        INC   DI
        DEC   CX
        JMP   _JSL_77
_JSL_77N:
        POP   CX
        POP   DI
        POP   SI
_JSL_77C:
        MOV   AL, [SI]
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_76
_JSL_78:
        POP   CX
        POP   DI
        POP   AX
        PUSH   SI
        MOV   SI, [SP+10]
_JSL_80:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_80D
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_80
_JSL_80D:
        POP   SI
_JSL_81:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_79
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_81
_JSL_79:
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
_JSL_82:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_83
        INC   AX
        INC   SI
        JMP   _JSL_82
_JSL_83:
        POP   SI
        RET
_JSRT_STRINDEXOF:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        MOV   BX, SI
_JSL_84:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_87
        PUSH   SI
        PUSH   DI
_JSL_85:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_86
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_85N
        INC   SI
        INC   DI
        JMP   _JSL_85
_JSL_86:
        POP   DI
        POP   AX
        SUB   AX, BX
        POP   DX
        POP   CX
        POP   BX
        RET
_JSL_85N:
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_84
_JSL_87:
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
_JSL_88:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_91
        PUSH   SI
        PUSH   DI
_JSL_89:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_90
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_89N
        INC   SI
        INC   DI
        JMP   _JSL_89
_JSL_90:
        POP   DI
        POP   AX
        SUB   AX, BX
        MOV   DX, AX
        ADD   AX, BX
        MOV   SI, AX
        INC   SI
        JMP   _JSL_88
_JSL_89N:
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_88
_JSL_91:
        MOV   AX, DX
        POP   DX
        POP   CX
        POP   BX
        RET
_JSRT_STRSTARTW:
_JSL_92:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_92Y
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_93
        INC   SI
        INC   DI
        JMP   _JSL_92
_JSL_92Y:
        MOV   AX, 1
        RET
_JSL_93:
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
        JA   _JSL_94
        SUB   BX, CX
        ADD   SI, BX
        POP   CX
        POP   BX
        JMP   _JSRT_STRSTARTW
_JSL_94:
        XOR   AX, AX
        POP   CX
        POP   BX
        RET
_JSRT_STRSLICE:
        PUSH   DI
        PUSH   DX
        LEA   DI, _JSRT_STRBUF
        MOV   DX, BX
_JSL_95:
        OR   DX, DX
        JZ   _JSL_96
        CMP   BYTE PTR [SI], 0
        JE   _JSL_97
        INC   SI
        DEC   DX
        JMP   _JSL_95
_JSL_96:
        CMP   BX, CX
        JGE   _JSL_97
        CMP   BYTE PTR [SI], 0
        JE   _JSL_97
        MOV   AL, [SI]
        MOV   [DI], AL
        INC   SI
        INC   DI
        INC   BX
        JMP   _JSL_96
_JSL_97:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DX
        POP   DI
        RET
_JSRT_STRTOUPPER:
        PUSH   DI
        LEA   DI, _JSRT_STRBUF
_JSL_98:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_99
        CMP   AL, 'a'
        JB   _JSL_98C
        CMP   AL, 'z'
        JA   _JSL_98C
        SUB   AL, 32
_JSL_98C:
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_98
_JSL_99:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DI
        RET
_JSRT_STRTOLOWER:
        PUSH   DI
        LEA   DI, _JSRT_STRBUF
_JSL_100:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_101
        CMP   AL, 'A'
        JB   _JSL_100C
        CMP   AL, 'Z'
        JA   _JSL_100C
        ADD   AL, 32
_JSL_100C:
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_100
_JSL_101:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DI
        RET
_JSRT_STRTRIM:
        PUSH   DI
        PUSH   BX
_JSL_102:
        MOV   AL, [SI]
        CMP   AL, 32
        JE   _JSL_102S
        CMP   AL, 9
        JE   _JSL_102S
        JMP   _JSL_103
_JSL_102S:
        INC   SI
        JMP   _JSL_102
_JSL_103:
        LEA   DI, _JSRT_STRBUF
        MOV   BX, DI
_JSL_105:
        MOV   AL, [SI]
        MOV   [DI], AL
        OR   AL, AL
        JZ   _JSL_104
        INC   SI
        INC   DI
        JMP   _JSL_105
_JSL_104:
_JSL_106:
        DEC   DI
        CMP   DI, BX
        JB   _JSL_106D
        CMP   BYTE PTR [DI], 32
        JE   _JSL_106
        CMP   BYTE PTR [DI], 9
        JE   _JSL_106
_JSL_106D:
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
_JSL_107:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_110
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   CX, DX
_JSL_108:
        OR   CX, CX
        JZ   _JSL_109
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_108N
        INC   SI
        INC   DI
        DEC   CX
        JMP   _JSL_108
_JSL_108N:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_107
_JSL_109:
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
        JMP   _JSL_107
_JSL_110:
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
_JSL_111:
        OR   CX, CX
        JZ   _JSL_113
        MOV   SI, DX
_JSL_112:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_112D
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_112
_JSL_112D:
        DEC   CX
        JMP   _JSL_111
_JSL_113:
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
        JAE   _JSL_116
        SUB   CX, DX
        LEA   BX, _JSRT_STRBUF
        PUSH   SI
        MOV   SI, DI
_JSL_114:
        OR   CX, CX
        JZ   _JSL_115
        MOV   AL, [SI]
        OR   AL, AL
        JNZ   _JSL_114C
        MOV   SI, DI
        MOV   AL, [SI]
_JSL_114C:
        MOV   [BX], AL
        INC   BX
        INC   SI
        DEC   CX
        JMP   _JSL_114
_JSL_115:
        POP   SI
_JSL_117:
        MOV   AL, [SI]
        MOV   [BX], AL
        OR   AL, AL
        JZ   _JSL_117D
        INC   SI
        INC   BX
        JMP   _JSL_117
_JSL_117D:
        LEA   AX, _JSRT_STRBUF
        POP   DX
        POP   BX
        RET
_JSL_116:
        LEA   BX, _JSRT_STRBUF
_JSL_118:
        MOV   AL, [SI]
        MOV   [BX], AL
        OR   AL, AL
        JZ   _JSL_118D
        INC   SI
        INC   BX
        JMP   _JSL_118
_JSL_118D:
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
_JSL_119:
        CMP   BYTE PTR [SI], 32
        JE   _JSL_119S
        JMP   _JSL_119E
_JSL_119S:
        INC   SI
        JMP   _JSL_119
_JSL_119E:
        CMP   BYTE PTR [SI], '-'
        JNE   _JSL_119P
        MOV   BX, 1
        INC   SI
        JMP   _JSL_120
_JSL_119P:
        CMP   BYTE PTR [SI], '+'
        JNE   _JSL_120
        INC   SI
_JSL_120:
        XOR   DX, DX
        MOV   DL, [SI]
        OR   DL, DL
        JZ   _JSL_121
        CMP   DL, '0'
        JB   _JSL_121
        CMP   DL, '9'
        JA   _JSL_120H
        SUB   DL, '0'
        JMP   _JSL_120M
_JSL_120H:
        CMP   DL, 'a'
        JB   _JSL_120U
        CMP   DL, 'f'
        JA   _JSL_121
        SUB   DL, 'a'
        ADD   DL, 10
        JMP   _JSL_120M
_JSL_120U:
        CMP   DL, 'A'
        JB   _JSL_121
        CMP   DL, 'F'
        JA   _JSL_121
        SUB   DL, 'A'
        ADD   DL, 10
_JSL_120M:
        CMP   DL, CL
        JAE   _JSL_121
        PUSH   DX
        PUSH   CX
        MUL    CX
        POP   CX
        POP   DX
        ADD   AX, DX
        INC   SI
        JMP   _JSL_120
_JSL_121:
        OR   BX, BX
        JZ   _JSL_121D
        NEG    AX
_JSL_121D:
        POP   DX
        POP   BX
        RET
_JSRT_ABS:
        OR   AX, AX
        JNS   _JSL_122
        NEG    AX
_JSL_122:
        RET
_JSRT_POW:
        PUSH   CX
        PUSH   DX
        MOV   CX, BX
        MOV   BX, AX
        MOV   AX, 1
_JSL_123:
        OR   CX, CX
        JZ   _JSL_124
        PUSH   DX
        MUL    BX
        POP   DX
        DEC   CX
        JMP   _JSL_123
_JSL_124:
        POP   DX
        POP   CX
        RET
_JSRT_SQRT:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        OR   AX, AX
        JZ   _JSL_126
        MOV   BX, AX
        SHR   AX, 1
        OR   AX, AX
        JZ   _JSL_126O
_JSL_125:
        MOV   CX, AX
        PUSH   BX
        XOR   DX, DX
        MOV   AX, BX
        DIV    CX
        POP   BX
        ADD   AX, CX
        SHR   AX, 1
        CMP   AX, CX
        JB   _JSL_125
        MOV   AX, CX
_JSL_126:
        POP   DX
        POP   CX
        POP   BX
        RET
_JSL_126O:
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
        JZ   _JSL_128
        JS   _JSL_127
        MOV   AX, 1
        JMP   _JSL_128
_JSL_127:
        MOV   AX, 0FFFFh
_JSL_128:
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
_JSV_sum  DW  0
_JSV_i  DW  0
_JSV_s2  DW  0
_JSV_j  DW  0
_JSV_s3  DW  0
_JSV_k  DW  0
_JSV_s4  DW  0
_JSV_m  DW  0
_JSV_s5  DW  0
_JSV_n  DW  0
_DATA   ENDS

        END
