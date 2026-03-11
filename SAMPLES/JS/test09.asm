; Genere par JS86 v1.0 - SAMPLES\JS\test09.js

        .MODEL SMALL
        .STACK 1024

_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME  CS:_TEXT, DS:_DATA, SS:STACK

; --- debut du code genere ---

        MOV   AX, 42
        MOV   [_JSV_x], AX
        MOV   AX, 10
        MOV   [_JSV_y], AX
        MOV   [_JSV_z], 0
        MOV   AX, [_JSV_x]
        MOV   [_JSV_z], AX
        MOV   AX, [_JSV_y]
        MOV   [_JSV_z], AX
        MOV   AX, 5
        MOV   BX, AX
        MOV   AX, [_JSV_x]
        ADD   AX, BX
        MOV   [_JSV_x], AX
        MOV   AX, 3
        MOV   BX, AX
        MOV   AX, [_JSV_y]
        SUB   AX, BX
        MOV   [_JSV_y], AX
        MOV   AX, 3
        MOV   [_JSV_PI], AX
        MOV   AX, 0
        MOV   [_JSV_count], AX
        MOV   AX, [_JSV_count]
        MOV   [_JSV_count], AX

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
        JZ   _JSL_1
        DEC   BX
        MOV   [SI], BX
        MOV   DI, BX
        SHL   DI, 1
        ADD   DI, 2
        ADD   DI, SI
        MOV   AX, [DI]
        RET
_JSL_1:
        XOR   AX, AX
        RET
_JSRT_ARRSHIFT:
        MOV   CX, [SI]
        OR   CX, CX
        JZ   _JSL_2
        MOV   AX, [SI+2]
        PUSH   AX
        DEC   CX
        MOV   [SI], CX
        LEA   DI, [SI+2]
        LEA   BX, [SI+4]
_JSL_3:
        OR   CX, CX
        JZ   _JSL_4
        MOV   AX, [BX]
        MOV   [DI], AX
        ADD   DI, 2
        ADD   BX, 2
        DEC   CX
        JMP   _JSL_3
_JSL_4:
        POP   AX
        RET
_JSL_2:
        XOR   AX, AX
        RET
_JSRT_ARRUNSHIFT:
        PUSH   AX
        MOV   CX, [SI]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        ADD   DI, 2
_JSL_5:
        OR   CX, CX
        JZ   _JSL_6
        MOV   AX, [DI-2]
        MOV   [DI], AX
        SUB   DI, 2
        DEC   CX
        JMP   _JSL_5
_JSL_6:
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
_JSL_7:
        OR   CX, CX
        JZ   _JSL_8
        CMP   [SI], BX
        JE   _JSL_9
        ADD   SI, 2
        INC   DX
        DEC   CX
        JMP   _JSL_7
_JSL_9:
        MOV   AX, DX
        RET
_JSL_8:
        MOV   AX, -1
        RET
_JSRT_ARRREV:
        MOV   CX, [SI]
        CMP   CX, 2
        JL   _JSL_10
        LEA   BX, [SI+2]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        SUB   DI, 2
_JSL_11:
        CMP   BX, DI
        JGE   _JSL_12
        MOV   AX, [BX]
        MOV   DX, [DI]
        MOV   [BX], DX
        MOV   [DI], AX
        ADD   BX, 2
        SUB   DI, 2
        JMP   _JSL_11
_JSL_12:
_JSL_10:
        MOV   AX, SI
        RET
_JSRT_ARRSORT:
        PUSH   SI
_JSL_13:
        XOR   DX, DX
        MOV   CX, [SI]
        DEC   CX
        CMP   CX, 0
        JLE   _JSL_16
        LEA   BX, [SI+2]
_JSL_14:
        MOV   AX, [BX]
        CMP   AX, [BX+2]
        JLE   _JSL_15
        MOV   DI, [BX+2]
        MOV   [BX], DI
        MOV   [BX+2], AX
        MOV   DX, 1
_JSL_15:
        ADD   BX, 2
        DEC   CX
        OR   CX, CX
        JNZ   _JSL_14
        OR   DX, DX
        JNZ   _JSL_13
_JSL_16:
        POP   AX
        RET

; --- runtime object routines (TODO 16) ---
_JSRT_STRCMP:
        PUSH   SI
        PUSH   DI
_JSL_17:
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_19
        OR   AL, AL
        JZ   _JSL_18
        INC   SI
        INC   DI
        JMP   _JSL_17
_JSL_18:
        XOR   AX, AX
        POP   DI
        POP   SI
        RET
_JSL_19:
        MOV   AX, 1
        POP   DI
        POP   SI
        RET
_JSRT_OBJGET:
        PUSH   CX
        PUSH   BX
        MOV   CX, [BX]
        ADD   BX, 2
_JSL_20:
        OR   CX, CX
        JZ   _JSL_22
        PUSH   CX
        PUSH   BX
        PUSH   DI
        MOV   SI, [BX]
        CALL   _JSRT_STRCMP
        POP   DI
        POP   BX
        POP   CX
        OR   AX, AX
        JZ   _JSL_21
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_20
_JSL_21:
        MOV   AX, [BX+2]
        POP   BX
        POP   CX
        RET
_JSL_22:
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
_JSL_23:
        OR   CX, CX
        JZ   _JSL_25
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
        JZ   _JSL_24
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_23
_JSL_24:
        MOV   [BX+2], DX
        MOV   AX, DX
        POP   BX
        POP   CX
        RET
_JSL_25:
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
_JSL_26:
        OR   CX, CX
        JZ   _JSL_27
        MOV   AX, [SI]
        MOV   [DI], AX
        ADD   SI, 4
        ADD   DI, 2
        DEC   CX
        JMP   _JSL_26
_JSL_27:
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
_JSL_28:
        OR   CX, CX
        JZ   _JSL_29
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
        JMP   _JSL_28
_JSL_29:
        POP   BX
        MOV   AX, BX
        POP   DI
        POP   CX
        RET

; --- runtime regexp routines (TODO 19) ---
_JSRT_REPARSE:
        PUSH   BX
        MOV   BX, DI
_JSL_30:
        MOV   AL, [BX]
        CMP   AL, 1
        JZ   _JSL_31
        OR   AL, AL
        JZ   _JSL_31
        INC   BX
        JMP   _JSL_30
_JSL_31:
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
        JZ   _JSL_34
_JSL_32:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_35
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   DX, CX
_JSL_33:
        OR   DX, DX
        JZ   _JSL_34B
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_35B
        INC   SI
        INC   DI
        DEC   DX
        JMP   _JSL_33
_JSL_34B:
        POP   CX
        POP   DI
        POP   SI
        JMP   _JSL_34
_JSL_35B:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_32
_JSL_34:
        MOV   AX, 1
        POP   DX
        POP   CX
        POP   BX
        POP   DI
        POP   SI
        RET
_JSL_35:
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
        JZ   _JSL_38
_JSL_36:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_39
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   DX, CX
_JSL_37:
        OR   DX, DX
        JZ   _JSL_38B
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_39B
        INC   SI
        INC   DI
        DEC   DX
        JMP   _JSL_37
_JSL_38B:
        POP   CX
        POP   DI
        POP   SI
        JMP   _JSL_38
_JSL_39B:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_36
_JSL_38:
        MOV   AX, SI
        SUB   AX, BX
        POP   DX
        POP   CX
        POP   BX
        POP   DI
        POP   SI
        RET
_JSL_39:
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
        JZ   _JSL_40
        MOV   AX, SI
        RET
_JSL_40:
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
_JSL_41:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_44
        OR   DX, DX
        JZ   _JSL_42C
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   CX, DX
_JSL_42:
        OR   CX, CX
        JZ   _JSL_43
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_42N
        INC   SI
        INC   DI
        DEC   CX
        JMP   _JSL_42
_JSL_42N:
        POP   CX
        POP   DI
        POP   SI
_JSL_42C:
        MOV   AL, [SI]
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_41
_JSL_43:
        POP   CX
        POP   DI
        POP   AX
        PUSH   SI
        MOV   SI, [SP+10]
_JSL_45:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_45D
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_45
_JSL_45D:
        POP   SI
_JSL_46:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_44
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_46
_JSL_44:
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
_JSL_47:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_48
        INC   AX
        INC   SI
        JMP   _JSL_47
_JSL_48:
        POP   SI
        RET
_JSRT_STRINDEXOF:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        MOV   BX, SI
_JSL_49:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_52
        PUSH   SI
        PUSH   DI
_JSL_50:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_51
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_50N
        INC   SI
        INC   DI
        JMP   _JSL_50
_JSL_51:
        POP   DI
        POP   AX
        SUB   AX, BX
        POP   DX
        POP   CX
        POP   BX
        RET
_JSL_50N:
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_49
_JSL_52:
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
_JSL_53:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_56
        PUSH   SI
        PUSH   DI
_JSL_54:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_55
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_54N
        INC   SI
        INC   DI
        JMP   _JSL_54
_JSL_55:
        POP   DI
        POP   AX
        SUB   AX, BX
        MOV   DX, AX
        ADD   AX, BX
        MOV   SI, AX
        INC   SI
        JMP   _JSL_53
_JSL_54N:
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_53
_JSL_56:
        MOV   AX, DX
        POP   DX
        POP   CX
        POP   BX
        RET
_JSRT_STRSTARTW:
_JSL_57:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_57Y
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_58
        INC   SI
        INC   DI
        JMP   _JSL_57
_JSL_57Y:
        MOV   AX, 1
        RET
_JSL_58:
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
        JA   _JSL_59
        SUB   BX, CX
        ADD   SI, BX
        POP   CX
        POP   BX
        JMP   _JSRT_STRSTARTW
_JSL_59:
        XOR   AX, AX
        POP   CX
        POP   BX
        RET
_JSRT_STRSLICE:
        PUSH   DI
        PUSH   DX
        LEA   DI, _JSRT_STRBUF
        MOV   DX, BX
_JSL_60:
        OR   DX, DX
        JZ   _JSL_61
        CMP   BYTE PTR [SI], 0
        JE   _JSL_62
        INC   SI
        DEC   DX
        JMP   _JSL_60
_JSL_61:
        CMP   BX, CX
        JGE   _JSL_62
        CMP   BYTE PTR [SI], 0
        JE   _JSL_62
        MOV   AL, [SI]
        MOV   [DI], AL
        INC   SI
        INC   DI
        INC   BX
        JMP   _JSL_61
_JSL_62:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DX
        POP   DI
        RET
_JSRT_STRTOUPPER:
        PUSH   DI
        LEA   DI, _JSRT_STRBUF
_JSL_63:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_64
        CMP   AL, 'a'
        JB   _JSL_63C
        CMP   AL, 'z'
        JA   _JSL_63C
        SUB   AL, 32
_JSL_63C:
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_63
_JSL_64:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DI
        RET
_JSRT_STRTOLOWER:
        PUSH   DI
        LEA   DI, _JSRT_STRBUF
_JSL_65:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_66
        CMP   AL, 'A'
        JB   _JSL_65C
        CMP   AL, 'Z'
        JA   _JSL_65C
        ADD   AL, 32
_JSL_65C:
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_65
_JSL_66:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DI
        RET
_JSRT_STRTRIM:
        PUSH   DI
        PUSH   BX
_JSL_67:
        MOV   AL, [SI]
        CMP   AL, 32
        JE   _JSL_67S
        CMP   AL, 9
        JE   _JSL_67S
        JMP   _JSL_68
_JSL_67S:
        INC   SI
        JMP   _JSL_67
_JSL_68:
        LEA   DI, _JSRT_STRBUF
        MOV   BX, DI
_JSL_70:
        MOV   AL, [SI]
        MOV   [DI], AL
        OR   AL, AL
        JZ   _JSL_69
        INC   SI
        INC   DI
        JMP   _JSL_70
_JSL_69:
_JSL_71:
        DEC   DI
        CMP   DI, BX
        JB   _JSL_71D
        CMP   BYTE PTR [DI], 32
        JE   _JSL_71
        CMP   BYTE PTR [DI], 9
        JE   _JSL_71
_JSL_71D:
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
_JSL_72:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_75
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   CX, DX
_JSL_73:
        OR   CX, CX
        JZ   _JSL_74
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_73N
        INC   SI
        INC   DI
        DEC   CX
        JMP   _JSL_73
_JSL_73N:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_72
_JSL_74:
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
        JMP   _JSL_72
_JSL_75:
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
_JSL_76:
        OR   CX, CX
        JZ   _JSL_78
        MOV   SI, DX
_JSL_77:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_77D
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_77
_JSL_77D:
        DEC   CX
        JMP   _JSL_76
_JSL_78:
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
        JAE   _JSL_81
        SUB   CX, DX
        LEA   BX, _JSRT_STRBUF
        PUSH   SI
        MOV   SI, DI
_JSL_79:
        OR   CX, CX
        JZ   _JSL_80
        MOV   AL, [SI]
        OR   AL, AL
        JNZ   _JSL_79C
        MOV   SI, DI
        MOV   AL, [SI]
_JSL_79C:
        MOV   [BX], AL
        INC   BX
        INC   SI
        DEC   CX
        JMP   _JSL_79
_JSL_80:
        POP   SI
_JSL_82:
        MOV   AL, [SI]
        MOV   [BX], AL
        OR   AL, AL
        JZ   _JSL_82D
        INC   SI
        INC   BX
        JMP   _JSL_82
_JSL_82D:
        LEA   AX, _JSRT_STRBUF
        POP   DX
        POP   BX
        RET
_JSL_81:
        LEA   BX, _JSRT_STRBUF
_JSL_83:
        MOV   AL, [SI]
        MOV   [BX], AL
        OR   AL, AL
        JZ   _JSL_83D
        INC   SI
        INC   BX
        JMP   _JSL_83
_JSL_83D:
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
_JSL_84:
        CMP   BYTE PTR [SI], 32
        JE   _JSL_84S
        JMP   _JSL_84E
_JSL_84S:
        INC   SI
        JMP   _JSL_84
_JSL_84E:
        CMP   BYTE PTR [SI], '-'
        JNE   _JSL_84P
        MOV   BX, 1
        INC   SI
        JMP   _JSL_85
_JSL_84P:
        CMP   BYTE PTR [SI], '+'
        JNE   _JSL_85
        INC   SI
_JSL_85:
        XOR   DX, DX
        MOV   DL, [SI]
        OR   DL, DL
        JZ   _JSL_86
        CMP   DL, '0'
        JB   _JSL_86
        CMP   DL, '9'
        JA   _JSL_85H
        SUB   DL, '0'
        JMP   _JSL_85M
_JSL_85H:
        CMP   DL, 'a'
        JB   _JSL_85U
        CMP   DL, 'f'
        JA   _JSL_86
        SUB   DL, 'a'
        ADD   DL, 10
        JMP   _JSL_85M
_JSL_85U:
        CMP   DL, 'A'
        JB   _JSL_86
        CMP   DL, 'F'
        JA   _JSL_86
        SUB   DL, 'A'
        ADD   DL, 10
_JSL_85M:
        CMP   DL, CL
        JAE   _JSL_86
        PUSH   DX
        PUSH   CX
        MUL    CX
        POP   CX
        POP   DX
        ADD   AX, DX
        INC   SI
        JMP   _JSL_85
_JSL_86:
        OR   BX, BX
        JZ   _JSL_86D
        NEG    AX
_JSL_86D:
        POP   DX
        POP   BX
        RET
_JSRT_ABS:
        OR   AX, AX
        JNS   _JSL_87
        NEG    AX
_JSL_87:
        RET
_JSRT_POW:
        PUSH   CX
        PUSH   DX
        MOV   CX, BX
        MOV   BX, AX
        MOV   AX, 1
_JSL_88:
        OR   CX, CX
        JZ   _JSL_89
        PUSH   DX
        MUL    BX
        POP   DX
        DEC   CX
        JMP   _JSL_88
_JSL_89:
        POP   DX
        POP   CX
        RET
_JSRT_SQRT:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        OR   AX, AX
        JZ   _JSL_91
        MOV   BX, AX
        SHR   AX, 1
        OR   AX, AX
        JZ   _JSL_91O
_JSL_90:
        MOV   CX, AX
        PUSH   BX
        XOR   DX, DX
        MOV   AX, BX
        DIV    CX
        POP   BX
        ADD   AX, CX
        SHR   AX, 1
        CMP   AX, CX
        JB   _JSL_90
        MOV   AX, CX
_JSL_91:
        POP   DX
        POP   CX
        POP   BX
        RET
_JSL_91O:
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
        JZ   _JSL_93
        JS   _JSL_92
        MOV   AX, 1
        JMP   _JSL_93
_JSL_92:
        MOV   AX, 0FFFFh
_JSL_93:
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
_JSV_PI  DW  0
_JSV_count  DW  0
_DATA   ENDS

        END
