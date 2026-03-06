; Genere par JS86 v1.0 - SAMPLES\JS\test10.js

        .MODEL SMALL
        .STACK 1024

_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME  CS:_TEXT, DS:_DATA, SS:STACK

; --- debut du code genere ---

        MOV   AX, 42
        MOV   [_JSV_a], AX
        LEA   AX, _JSK_1
        MOV   [_JSV_b], AX
        MOV   AX, 1
        MOV   [_JSV_c], AX
        MOV   AX, 0
        MOV   [_JSV_d], AX
        XOR   AX, AX
        MOV   AX, 0
        MOV   [_JSV_e], AX
        XOR   AX, AX
        MOV   AX, 0
        MOV   [_JSV_f], AX
        MOV   AX, -5
        MOV   [_JSV_g], AX
        MOV   AX, 1
        MOV   [_JSV_h], AX
        MOV   AX, -1
        MOV   [_JSV_i], AX
        XOR   AX, AX
        MOV   [_JSV_j], AX
        MOV   AX, [_JSV_a]
        CALL   _JSRT_TYPEOF
        MOV   [_JSV_k], AX
        MOV   AX, 0
        XOR   AX, AX
        MOV   [_JSV_l], AX
        MOV   AX, [_JSV_a]
        MOV   AX, 1
        MOV   [_JSV_m], AX
        LEA   AX, _JSA_2
        MOV   [_JSV_arr], AX
        LEA   AX, _JSA_3
        MOV   [_JSV_empty], AX
        LEA   AX, _JSO_4
        MOV   [_JSV_obj], AX
        MOV   AX, 10
        MOV   [_JSV_n], AX
        MOV   AX, [_JSV_n]
        INC    AX
        MOV   [_JSV_n], AX
        MOV   AX, [_JSV_n]
        DEC    AX
        MOV   [_JSV_n], AX
        MOV   AX, [_JSV_n]
        PUSH   AX
        INC    AX
        MOV   [_JSV_n], AX
        POP   AX
        MOV   [_JSV_o], AX
        MOV   AX, [_JSV_n]
        PUSH   AX
        DEC    AX
        MOV   [_JSV_n], AX
        POP   AX
        MOV   [_JSV_p], AX
        MOV   AX, 9
        MOV   [_JSV_q], AX

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
        JZ   _JSL_7
        DEC   BX
        MOV   [SI], BX
        MOV   DI, BX
        SHL   DI, 1
        ADD   DI, 2
        ADD   DI, SI
        MOV   AX, [DI]
        RET
_JSL_7:
        XOR   AX, AX
        RET
_JSRT_ARRSHIFT:
        MOV   CX, [SI]
        OR   CX, CX
        JZ   _JSL_8
        MOV   AX, [SI+2]
        PUSH   AX
        DEC   CX
        MOV   [SI], CX
        LEA   DI, [SI+2]
        LEA   BX, [SI+4]
_JSL_9:
        OR   CX, CX
        JZ   _JSL_10
        MOV   AX, [BX]
        MOV   [DI], AX
        ADD   DI, 2
        ADD   BX, 2
        DEC   CX
        JMP   _JSL_9
_JSL_10:
        POP   AX
        RET
_JSL_8:
        XOR   AX, AX
        RET
_JSRT_ARRUNSHIFT:
        PUSH   AX
        MOV   CX, [SI]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        ADD   DI, 2
_JSL_11:
        OR   CX, CX
        JZ   _JSL_12
        MOV   AX, [DI-2]
        MOV   [DI], AX
        SUB   DI, 2
        DEC   CX
        JMP   _JSL_11
_JSL_12:
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
_JSL_13:
        OR   CX, CX
        JZ   _JSL_14
        CMP   [SI], BX
        JE   _JSL_15
        ADD   SI, 2
        INC   DX
        DEC   CX
        JMP   _JSL_13
_JSL_15:
        MOV   AX, DX
        RET
_JSL_14:
        MOV   AX, -1
        RET
_JSRT_ARRREV:
        MOV   CX, [SI]
        CMP   CX, 2
        JL   _JSL_16
        LEA   BX, [SI+2]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        SUB   DI, 2
_JSL_17:
        CMP   BX, DI
        JGE   _JSL_18
        MOV   AX, [BX]
        MOV   DX, [DI]
        MOV   [BX], DX
        MOV   [DI], AX
        ADD   BX, 2
        SUB   DI, 2
        JMP   _JSL_17
_JSL_18:
_JSL_16:
        MOV   AX, SI
        RET
_JSRT_ARRSORT:
        PUSH   SI
_JSL_19:
        XOR   DX, DX
        MOV   CX, [SI]
        DEC   CX
        CMP   CX, 0
        JLE   _JSL_22
        LEA   BX, [SI+2]
_JSL_20:
        MOV   AX, [BX]
        CMP   AX, [BX+2]
        JLE   _JSL_21
        MOV   DI, [BX+2]
        MOV   [BX], DI
        MOV   [BX+2], AX
        MOV   DX, 1
_JSL_21:
        ADD   BX, 2
        DEC   CX
        OR   CX, CX
        JNZ   _JSL_20
        OR   DX, DX
        JNZ   _JSL_19
_JSL_22:
        POP   AX
        RET

; --- runtime object routines (TODO 16) ---
_JSRT_STRCMP:
        PUSH   SI
        PUSH   DI
_JSL_23:
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_25
        OR   AL, AL
        JZ   _JSL_24
        INC   SI
        INC   DI
        JMP   _JSL_23
_JSL_24:
        XOR   AX, AX
        POP   DI
        POP   SI
        RET
_JSL_25:
        MOV   AX, 1
        POP   DI
        POP   SI
        RET
_JSRT_OBJGET:
        PUSH   CX
        PUSH   BX
        MOV   CX, [BX]
        ADD   BX, 2
_JSL_26:
        OR   CX, CX
        JZ   _JSL_28
        PUSH   CX
        PUSH   BX
        PUSH   DI
        MOV   SI, [BX]
        CALL   _JSRT_STRCMP
        POP   DI
        POP   BX
        POP   CX
        OR   AX, AX
        JZ   _JSL_27
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_26
_JSL_27:
        MOV   AX, [BX+2]
        POP   BX
        POP   CX
        RET
_JSL_28:
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
_JSL_29:
        OR   CX, CX
        JZ   _JSL_31
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
        JZ   _JSL_30
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_29
_JSL_30:
        MOV   [BX+2], DX
        MOV   AX, DX
        POP   BX
        POP   CX
        RET
_JSL_31:
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
_JSL_32:
        OR   CX, CX
        JZ   _JSL_33
        MOV   AX, [SI]
        MOV   [DI], AX
        ADD   SI, 4
        ADD   DI, 2
        DEC   CX
        JMP   _JSL_32
_JSL_33:
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
_JSL_34:
        OR   CX, CX
        JZ   _JSL_35
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
        JMP   _JSL_34
_JSL_35:
        POP   BX
        MOV   AX, BX
        POP   DI
        POP   CX
        RET

; --- runtime regexp routines (TODO 19) ---
_JSRT_REPARSE:
        PUSH   BX
        MOV   BX, DI
_JSL_36:
        MOV   AL, [BX]
        CMP   AL, 1
        JZ   _JSL_37
        OR   AL, AL
        JZ   _JSL_37
        INC   BX
        JMP   _JSL_36
_JSL_37:
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
        JZ   _JSL_40
_JSL_38:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_41
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   DX, CX
_JSL_39:
        OR   DX, DX
        JZ   _JSL_40B
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_41B
        INC   SI
        INC   DI
        DEC   DX
        JMP   _JSL_39
_JSL_40B:
        POP   CX
        POP   DI
        POP   SI
        JMP   _JSL_40
_JSL_41B:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_38
_JSL_40:
        MOV   AX, 1
        POP   DX
        POP   CX
        POP   BX
        POP   DI
        POP   SI
        RET
_JSL_41:
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
        JZ   _JSL_44
_JSL_42:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_45
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   DX, CX
_JSL_43:
        OR   DX, DX
        JZ   _JSL_44B
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_45B
        INC   SI
        INC   DI
        DEC   DX
        JMP   _JSL_43
_JSL_44B:
        POP   CX
        POP   DI
        POP   SI
        JMP   _JSL_44
_JSL_45B:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_42
_JSL_44:
        MOV   AX, SI
        SUB   AX, BX
        POP   DX
        POP   CX
        POP   BX
        POP   DI
        POP   SI
        RET
_JSL_45:
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
        JZ   _JSL_46
        MOV   AX, SI
        RET
_JSL_46:
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
_JSL_47:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_50
        OR   DX, DX
        JZ   _JSL_48C
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   CX, DX
_JSL_48:
        OR   CX, CX
        JZ   _JSL_49
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_48N
        INC   SI
        INC   DI
        DEC   CX
        JMP   _JSL_48
_JSL_48N:
        POP   CX
        POP   DI
        POP   SI
_JSL_48C:
        MOV   AL, [SI]
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_47
_JSL_49:
        POP   CX
        POP   DI
        POP   AX
        PUSH   SI
        MOV   SI, [SP+10]
_JSL_51:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_51D
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_51
_JSL_51D:
        POP   SI
_JSL_52:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_50
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_52
_JSL_50:
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
_JSL_53:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_54
        INC   AX
        INC   SI
        JMP   _JSL_53
_JSL_54:
        POP   SI
        RET
_JSRT_STRINDEXOF:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        MOV   BX, SI
_JSL_55:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_58
        PUSH   SI
        PUSH   DI
_JSL_56:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_57
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_56N
        INC   SI
        INC   DI
        JMP   _JSL_56
_JSL_57:
        POP   DI
        POP   AX
        SUB   AX, BX
        POP   DX
        POP   CX
        POP   BX
        RET
_JSL_56N:
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_55
_JSL_58:
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
_JSL_59:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_62
        PUSH   SI
        PUSH   DI
_JSL_60:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_61
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_60N
        INC   SI
        INC   DI
        JMP   _JSL_60
_JSL_61:
        POP   DI
        POP   AX
        SUB   AX, BX
        MOV   DX, AX
        ADD   AX, BX
        MOV   SI, AX
        INC   SI
        JMP   _JSL_59
_JSL_60N:
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_59
_JSL_62:
        MOV   AX, DX
        POP   DX
        POP   CX
        POP   BX
        RET
_JSRT_STRSTARTW:
_JSL_63:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_63Y
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_64
        INC   SI
        INC   DI
        JMP   _JSL_63
_JSL_63Y:
        MOV   AX, 1
        RET
_JSL_64:
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
        JA   _JSL_65
        SUB   BX, CX
        ADD   SI, BX
        POP   CX
        POP   BX
        JMP   _JSRT_STRSTARTW
_JSL_65:
        XOR   AX, AX
        POP   CX
        POP   BX
        RET
_JSRT_STRSLICE:
        PUSH   DI
        PUSH   DX
        LEA   DI, _JSRT_STRBUF
        MOV   DX, BX
_JSL_66:
        OR   DX, DX
        JZ   _JSL_67
        CMP   BYTE PTR [SI], 0
        JE   _JSL_68
        INC   SI
        DEC   DX
        JMP   _JSL_66
_JSL_67:
        CMP   BX, CX
        JGE   _JSL_68
        CMP   BYTE PTR [SI], 0
        JE   _JSL_68
        MOV   AL, [SI]
        MOV   [DI], AL
        INC   SI
        INC   DI
        INC   BX
        JMP   _JSL_67
_JSL_68:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DX
        POP   DI
        RET
_JSRT_STRTOUPPER:
        PUSH   DI
        LEA   DI, _JSRT_STRBUF
_JSL_69:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_70
        CMP   AL, 'a'
        JB   _JSL_69C
        CMP   AL, 'z'
        JA   _JSL_69C
        SUB   AL, 32
_JSL_69C:
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_69
_JSL_70:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DI
        RET
_JSRT_STRTOLOWER:
        PUSH   DI
        LEA   DI, _JSRT_STRBUF
_JSL_71:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_72
        CMP   AL, 'A'
        JB   _JSL_71C
        CMP   AL, 'Z'
        JA   _JSL_71C
        ADD   AL, 32
_JSL_71C:
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_71
_JSL_72:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DI
        RET
_JSRT_STRTRIM:
        PUSH   DI
        PUSH   BX
_JSL_73:
        MOV   AL, [SI]
        CMP   AL, 32
        JE   _JSL_73S
        CMP   AL, 9
        JE   _JSL_73S
        JMP   _JSL_74
_JSL_73S:
        INC   SI
        JMP   _JSL_73
_JSL_74:
        LEA   DI, _JSRT_STRBUF
        MOV   BX, DI
_JSL_76:
        MOV   AL, [SI]
        MOV   [DI], AL
        OR   AL, AL
        JZ   _JSL_75
        INC   SI
        INC   DI
        JMP   _JSL_76
_JSL_75:
_JSL_77:
        DEC   DI
        CMP   DI, BX
        JB   _JSL_77D
        CMP   BYTE PTR [DI], 32
        JE   _JSL_77
        CMP   BYTE PTR [DI], 9
        JE   _JSL_77
_JSL_77D:
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
_JSL_78:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_81
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   CX, DX
_JSL_79:
        OR   CX, CX
        JZ   _JSL_80
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_79N
        INC   SI
        INC   DI
        DEC   CX
        JMP   _JSL_79
_JSL_79N:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_78
_JSL_80:
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
        JMP   _JSL_78
_JSL_81:
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
_JSL_82:
        OR   CX, CX
        JZ   _JSL_84
        MOV   SI, DX
_JSL_83:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_83D
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_83
_JSL_83D:
        DEC   CX
        JMP   _JSL_82
_JSL_84:
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
        JAE   _JSL_87
        SUB   CX, DX
        LEA   BX, _JSRT_STRBUF
        PUSH   SI
        MOV   SI, DI
_JSL_85:
        OR   CX, CX
        JZ   _JSL_86
        MOV   AL, [SI]
        OR   AL, AL
        JNZ   _JSL_85C
        MOV   SI, DI
        MOV   AL, [SI]
_JSL_85C:
        MOV   [BX], AL
        INC   BX
        INC   SI
        DEC   CX
        JMP   _JSL_85
_JSL_86:
        POP   SI
_JSL_88:
        MOV   AL, [SI]
        MOV   [BX], AL
        OR   AL, AL
        JZ   _JSL_88D
        INC   SI
        INC   BX
        JMP   _JSL_88
_JSL_88D:
        LEA   AX, _JSRT_STRBUF
        POP   DX
        POP   BX
        RET
_JSL_87:
        LEA   BX, _JSRT_STRBUF
_JSL_89:
        MOV   AL, [SI]
        MOV   [BX], AL
        OR   AL, AL
        JZ   _JSL_89D
        INC   SI
        INC   BX
        JMP   _JSL_89
_JSL_89D:
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
_JSL_90:
        CMP   BYTE PTR [SI], 32
        JE   _JSL_90S
        JMP   _JSL_90E
_JSL_90S:
        INC   SI
        JMP   _JSL_90
_JSL_90E:
        CMP   BYTE PTR [SI], '-'
        JNE   _JSL_90P
        MOV   BX, 1
        INC   SI
        JMP   _JSL_91
_JSL_90P:
        CMP   BYTE PTR [SI], '+'
        JNE   _JSL_91
        INC   SI
_JSL_91:
        XOR   DX, DX
        MOV   DL, [SI]
        OR   DL, DL
        JZ   _JSL_92
        CMP   DL, '0'
        JB   _JSL_92
        CMP   DL, '9'
        JA   _JSL_91H
        SUB   DL, '0'
        JMP   _JSL_91M
_JSL_91H:
        CMP   DL, 'a'
        JB   _JSL_91U
        CMP   DL, 'f'
        JA   _JSL_92
        SUB   DL, 'a'
        ADD   DL, 10
        JMP   _JSL_91M
_JSL_91U:
        CMP   DL, 'A'
        JB   _JSL_92
        CMP   DL, 'F'
        JA   _JSL_92
        SUB   DL, 'A'
        ADD   DL, 10
_JSL_91M:
        CMP   DL, CL
        JAE   _JSL_92
        PUSH   DX
        PUSH   CX
        MUL    CX
        POP   CX
        POP   DX
        ADD   AX, DX
        INC   SI
        JMP   _JSL_91
_JSL_92:
        OR   BX, BX
        JZ   _JSL_92D
        NEG    AX
_JSL_92D:
        POP   DX
        POP   BX
        RET
_JSRT_ABS:
        OR   AX, AX
        JNS   _JSL_93
        NEG    AX
_JSL_93:
        RET
_JSRT_POW:
        PUSH   CX
        PUSH   DX
        MOV   CX, BX
        MOV   BX, AX
        MOV   AX, 1
_JSL_94:
        OR   CX, CX
        JZ   _JSL_95
        PUSH   DX
        MUL    BX
        POP   DX
        DEC   CX
        JMP   _JSL_94
_JSL_95:
        POP   DX
        POP   CX
        RET
_JSRT_SQRT:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        OR   AX, AX
        JZ   _JSL_97
        MOV   BX, AX
        SHR   AX, 1
        OR   AX, AX
        JZ   _JSL_97O
_JSL_96:
        MOV   CX, AX
        PUSH   BX
        XOR   DX, DX
        MOV   AX, BX
        DIV    CX
        POP   BX
        ADD   AX, CX
        SHR   AX, 1
        CMP   AX, CX
        JB   _JSL_96
        MOV   AX, CX
_JSL_97:
        POP   DX
        POP   CX
        POP   BX
        RET
_JSL_97O:
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
        JZ   _JSL_99
        JS   _JSL_98
        MOV   AX, 1
        JMP   _JSL_99
_JSL_98:
        MOV   AX, 0FFFFh
_JSL_99:
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
_JSV_a  DW  0
_JSV_b  DW  0
_JSK_1  DB  'hello',0
_JSV_c  DW  0
_JSV_d  DW  0
_JSV_e  DW  0
_JSV_f  DW  0
_JSV_g  DW  0
_JSV_h  DW  0
_JSV_i  DW  0
_JSV_j  DW  0
_JSV_k  DW  0
_JSV_l  DW  0
_JSV_m  DW  0
_JSV_arr  DW  0
_JSA_2  DW  5   ; tableau (5 elem)
_JSA_2_E0  DW  1
_JSA_2_E1  DW  2
_JSA_2_E2  DW  3
_JSA_2_E3  DW  4
_JSA_2_E4  DW  5
_JSV_empty  DW  0
_JSA_3  DW  0   ; tableau (0 elem)
_JSV_obj  DW  0
_JSK_5  DB  'x',0
_JSK_6  DB  'y',0
_JSO_4  DW  2   ; objet (2 props)
_JSO_4_K0  DW  OFFSET _JSK_5
_JSO_4_V0  DW  10
_JSO_4_K1  DW  OFFSET _JSK_6
_JSO_4_V1  DW  20
_JSO_4_K2  DW  0
_JSO_4_V2  DW  0
_JSO_4_K3  DW  0
_JSO_4_V3  DW  0
_JSO_4_K4  DW  0
_JSO_4_V4  DW  0
_JSO_4_K5  DW  0
_JSO_4_V5  DW  0
_JSV_n  DW  0
_JSV_o  DW  0
_JSV_p  DW  0
_JSV_q  DW  0
_DATA   ENDS

        END
