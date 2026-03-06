; Genere par JS86 v1.0 - SAMPLES\JS\test11.js

        .MODEL SMALL
        .STACK 1024

_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME  CS:_TEXT, DS:_DATA, SS:STACK

; --- debut du code genere ---

        MOV   AX, 10
        MOV   [_JSV_a], AX
        MOV   AX, 3
        MOV   [_JSV_b], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, [_JSV_b]
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [_JSV_sum], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, [_JSV_b]
        MOV   BX, AX
        POP   AX
        SUB   AX, BX
        MOV   [_JSV_diff], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, [_JSV_b]
        MOV   BX, AX
        POP   AX
        IMUL   BX
        MOV   [_JSV_prod], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, [_JSV_b]
        MOV   BX, AX
        POP   AX
        CMP   BX, 0
        JE   _JSL_1
        CWD
        IDIV   BX
        JMP   _JSL_2
_JSL_1:
        XOR   AX, AX
_JSL_2:
        MOV   [_JSV_quot], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, [_JSV_b]
        MOV   BX, AX
        POP   AX
        CMP   BX, 0
        JE   _JSL_3
        CWD
        IDIV   BX
        MOV   AX, DX
        JMP   _JSL_4
_JSL_3:
        XOR   AX, AX
_JSL_4:
        MOV   [_JSV_rem], AX
        MOV   AX, 5
        MOV   [_JSV_c1], AX
        MOV   AX, 6
        MOV   [_JSV_c2], AX
        MOV   AX, 21
        MOV   [_JSV_c3], AX
        MOV   AX, 4
        MOV   [_JSV_c4], AX
        MOV   AX, 2
        MOV   [_JSV_c5], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, [_JSV_b]
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JNE   _JSL_5
        INC    AX
_JSL_5:
        MOV   [_JSV_eq], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, [_JSV_b]
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JE   _JSL_6
        INC    AX
_JSL_6:
        MOV   [_JSV_ne], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, [_JSV_b]
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JGE   _JSL_7
        INC    AX
_JSL_7:
        MOV   [_JSV_lt], AX
        MOV   AX, [_JSV_b]
        PUSH   AX
        MOV   AX, [_JSV_b]
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JG   _JSL_8
        INC    AX
_JSL_8:
        MOV   [_JSV_le], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, [_JSV_b]
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JLE   _JSL_9
        INC    AX
_JSL_9:
        MOV   [_JSV_gt], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, [_JSV_a]
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JL   _JSL_10
        INC    AX
_JSL_10:
        MOV   [_JSV_ge], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, 10
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JNE   _JSL_11
        INC    AX
_JSL_11:
        MOV   [_JSV_seq], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, 5
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JE   _JSL_12
        INC    AX
_JSL_12:
        MOV   [_JSV_sne], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, [_JSV_b]
        MOV   BX, AX
        POP   AX
        AND   AX, BX
        MOV   [_JSV_band], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, [_JSV_b]
        MOV   BX, AX
        POP   AX
        OR   AX, BX
        MOV   [_JSV_bor], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, [_JSV_b]
        MOV   BX, AX
        POP   AX
        XOR   AX, BX
        MOV   [_JSV_bxor], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        MOV   CL, BL
        SAL   AX, CL
        MOV   [_JSV_shl], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        MOV   CL, BL
        SAR   AX, CL
        MOV   [_JSV_shr], AX
        MOV   AX, 5
        MOV   [_JSV_x], AX
        MOV   AX, 0
        MOV   [_JSV_y], AX
        MOV   AX, [_JSV_x]
        OR   AX, AX
        JZ   _JSL_13
        MOV   AX, 42
_JSL_13:
        MOV   [_JSV_and1], AX
        MOV   AX, [_JSV_y]
        OR   AX, AX
        JNZ   _JSL_14
        MOV   AX, 99
_JSL_14:
        MOV   [_JSV_or1], AX
        MOV   AX, [_JSV_y]
        OR   AX, AX
        JZ   _JSL_15
        MOV   AX, 42
_JSL_15:
        MOV   [_JSV_and2], AX
        MOV   AX, [_JSV_x]
        OR   AX, AX
        JNZ   _JSL_16
        MOV   AX, 99
_JSL_16:
        MOV   [_JSV_or2], AX
        MOV   AX, 0
        MOV   [_JSV_n], AX
        MOV   AX, [_JSV_n]
        CMP   AX, 0
        JNE   _JSL_17
        MOV   AX, 7
_JSL_17:
        MOV   [_JSV_nul], AX
        MOV   AX, [_JSV_x]
        OR   AX, AX
        JZ   _JSL_18
        MOV   AX, 100
        JMP   _JSL_19
_JSL_18:
        MOV   AX, 200
_JSL_19:
        MOV   [_JSV_t1], AX
        MOV   AX, [_JSV_y]
        OR   AX, AX
        JZ   _JSL_20
        MOV   AX, 100
        JMP   _JSL_21
_JSL_20:
        MOV   AX, 200
_JSL_21:
        MOV   [_JSV_t2], AX
        MOV   AX, 11
        MOV   [_JSV_t3], AX
        MOV   AX, 22
        MOV   [_JSV_t4], AX
        MOV   AX, 3
        MOV   [_JSV_v], AX
        MOV   AX, [_JSV_a]
        MOV   BX, AX
        MOV   AX, 5
        ADD   AX, BX
        MOV   [_JSV_m1], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        SUB   AX, BX
        MOV   [_JSV_m2], AX
        MOV   AX, [_JSV_b]
        MOV   BX, AX
        MOV   AX, 2
        IMUL   BX
        MOV   [_JSV_m3], AX
        LEA   AX, _JSK_22
        MOV   [_JSV_s1], AX
        LEA   AX, _JSK_23
        MOV   [_JSV_s2], AX
        MOV   AX, [_JSV_s1]
        PUSH   AX
        MOV   AX, [_JSV_s2]
        MOV   BX, AX
        POP   AX
        CALL   _JSRT_CONCAT
        MOV   [_JSV_s3], AX

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
        JZ   _JSL_24
        DEC   BX
        MOV   [SI], BX
        MOV   DI, BX
        SHL   DI, 1
        ADD   DI, 2
        ADD   DI, SI
        MOV   AX, [DI]
        RET
_JSL_24:
        XOR   AX, AX
        RET
_JSRT_ARRSHIFT:
        MOV   CX, [SI]
        OR   CX, CX
        JZ   _JSL_25
        MOV   AX, [SI+2]
        PUSH   AX
        DEC   CX
        MOV   [SI], CX
        LEA   DI, [SI+2]
        LEA   BX, [SI+4]
_JSL_26:
        OR   CX, CX
        JZ   _JSL_27
        MOV   AX, [BX]
        MOV   [DI], AX
        ADD   DI, 2
        ADD   BX, 2
        DEC   CX
        JMP   _JSL_26
_JSL_27:
        POP   AX
        RET
_JSL_25:
        XOR   AX, AX
        RET
_JSRT_ARRUNSHIFT:
        PUSH   AX
        MOV   CX, [SI]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        ADD   DI, 2
_JSL_28:
        OR   CX, CX
        JZ   _JSL_29
        MOV   AX, [DI-2]
        MOV   [DI], AX
        SUB   DI, 2
        DEC   CX
        JMP   _JSL_28
_JSL_29:
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
_JSL_30:
        OR   CX, CX
        JZ   _JSL_31
        CMP   [SI], BX
        JE   _JSL_32
        ADD   SI, 2
        INC   DX
        DEC   CX
        JMP   _JSL_30
_JSL_32:
        MOV   AX, DX
        RET
_JSL_31:
        MOV   AX, -1
        RET
_JSRT_ARRREV:
        MOV   CX, [SI]
        CMP   CX, 2
        JL   _JSL_33
        LEA   BX, [SI+2]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        SUB   DI, 2
_JSL_34:
        CMP   BX, DI
        JGE   _JSL_35
        MOV   AX, [BX]
        MOV   DX, [DI]
        MOV   [BX], DX
        MOV   [DI], AX
        ADD   BX, 2
        SUB   DI, 2
        JMP   _JSL_34
_JSL_35:
_JSL_33:
        MOV   AX, SI
        RET
_JSRT_ARRSORT:
        PUSH   SI
_JSL_36:
        XOR   DX, DX
        MOV   CX, [SI]
        DEC   CX
        CMP   CX, 0
        JLE   _JSL_39
        LEA   BX, [SI+2]
_JSL_37:
        MOV   AX, [BX]
        CMP   AX, [BX+2]
        JLE   _JSL_38
        MOV   DI, [BX+2]
        MOV   [BX], DI
        MOV   [BX+2], AX
        MOV   DX, 1
_JSL_38:
        ADD   BX, 2
        DEC   CX
        OR   CX, CX
        JNZ   _JSL_37
        OR   DX, DX
        JNZ   _JSL_36
_JSL_39:
        POP   AX
        RET

; --- runtime object routines (TODO 16) ---
_JSRT_STRCMP:
        PUSH   SI
        PUSH   DI
_JSL_40:
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_42
        OR   AL, AL
        JZ   _JSL_41
        INC   SI
        INC   DI
        JMP   _JSL_40
_JSL_41:
        XOR   AX, AX
        POP   DI
        POP   SI
        RET
_JSL_42:
        MOV   AX, 1
        POP   DI
        POP   SI
        RET
_JSRT_OBJGET:
        PUSH   CX
        PUSH   BX
        MOV   CX, [BX]
        ADD   BX, 2
_JSL_43:
        OR   CX, CX
        JZ   _JSL_45
        PUSH   CX
        PUSH   BX
        PUSH   DI
        MOV   SI, [BX]
        CALL   _JSRT_STRCMP
        POP   DI
        POP   BX
        POP   CX
        OR   AX, AX
        JZ   _JSL_44
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_43
_JSL_44:
        MOV   AX, [BX+2]
        POP   BX
        POP   CX
        RET
_JSL_45:
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
_JSL_46:
        OR   CX, CX
        JZ   _JSL_48
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
        JZ   _JSL_47
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_46
_JSL_47:
        MOV   [BX+2], DX
        MOV   AX, DX
        POP   BX
        POP   CX
        RET
_JSL_48:
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
_JSL_49:
        OR   CX, CX
        JZ   _JSL_50
        MOV   AX, [SI]
        MOV   [DI], AX
        ADD   SI, 4
        ADD   DI, 2
        DEC   CX
        JMP   _JSL_49
_JSL_50:
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
_JSL_51:
        OR   CX, CX
        JZ   _JSL_52
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
        JMP   _JSL_51
_JSL_52:
        POP   BX
        MOV   AX, BX
        POP   DI
        POP   CX
        RET

; --- runtime regexp routines (TODO 19) ---
_JSRT_REPARSE:
        PUSH   BX
        MOV   BX, DI
_JSL_53:
        MOV   AL, [BX]
        CMP   AL, 1
        JZ   _JSL_54
        OR   AL, AL
        JZ   _JSL_54
        INC   BX
        JMP   _JSL_53
_JSL_54:
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
        JZ   _JSL_57
_JSL_55:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_58
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   DX, CX
_JSL_56:
        OR   DX, DX
        JZ   _JSL_57B
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_58B
        INC   SI
        INC   DI
        DEC   DX
        JMP   _JSL_56
_JSL_57B:
        POP   CX
        POP   DI
        POP   SI
        JMP   _JSL_57
_JSL_58B:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_55
_JSL_57:
        MOV   AX, 1
        POP   DX
        POP   CX
        POP   BX
        POP   DI
        POP   SI
        RET
_JSL_58:
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
        JZ   _JSL_61
_JSL_59:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_62
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   DX, CX
_JSL_60:
        OR   DX, DX
        JZ   _JSL_61B
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_62B
        INC   SI
        INC   DI
        DEC   DX
        JMP   _JSL_60
_JSL_61B:
        POP   CX
        POP   DI
        POP   SI
        JMP   _JSL_61
_JSL_62B:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_59
_JSL_61:
        MOV   AX, SI
        SUB   AX, BX
        POP   DX
        POP   CX
        POP   BX
        POP   DI
        POP   SI
        RET
_JSL_62:
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
        JZ   _JSL_63
        MOV   AX, SI
        RET
_JSL_63:
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
_JSL_64:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_67
        OR   DX, DX
        JZ   _JSL_65C
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   CX, DX
_JSL_65:
        OR   CX, CX
        JZ   _JSL_66
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_65N
        INC   SI
        INC   DI
        DEC   CX
        JMP   _JSL_65
_JSL_65N:
        POP   CX
        POP   DI
        POP   SI
_JSL_65C:
        MOV   AL, [SI]
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_64
_JSL_66:
        POP   CX
        POP   DI
        POP   AX
        PUSH   SI
        MOV   SI, [SP+10]
_JSL_68:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_68D
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_68
_JSL_68D:
        POP   SI
_JSL_69:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_67
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_69
_JSL_67:
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
_JSL_70:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_71
        INC   AX
        INC   SI
        JMP   _JSL_70
_JSL_71:
        POP   SI
        RET
_JSRT_STRINDEXOF:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        MOV   BX, SI
_JSL_72:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_75
        PUSH   SI
        PUSH   DI
_JSL_73:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_74
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_73N
        INC   SI
        INC   DI
        JMP   _JSL_73
_JSL_74:
        POP   DI
        POP   AX
        SUB   AX, BX
        POP   DX
        POP   CX
        POP   BX
        RET
_JSL_73N:
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_72
_JSL_75:
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
_JSL_76:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_79
        PUSH   SI
        PUSH   DI
_JSL_77:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_78
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_77N
        INC   SI
        INC   DI
        JMP   _JSL_77
_JSL_78:
        POP   DI
        POP   AX
        SUB   AX, BX
        MOV   DX, AX
        ADD   AX, BX
        MOV   SI, AX
        INC   SI
        JMP   _JSL_76
_JSL_77N:
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_76
_JSL_79:
        MOV   AX, DX
        POP   DX
        POP   CX
        POP   BX
        RET
_JSRT_STRSTARTW:
_JSL_80:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_80Y
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_81
        INC   SI
        INC   DI
        JMP   _JSL_80
_JSL_80Y:
        MOV   AX, 1
        RET
_JSL_81:
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
        JA   _JSL_82
        SUB   BX, CX
        ADD   SI, BX
        POP   CX
        POP   BX
        JMP   _JSRT_STRSTARTW
_JSL_82:
        XOR   AX, AX
        POP   CX
        POP   BX
        RET
_JSRT_STRSLICE:
        PUSH   DI
        PUSH   DX
        LEA   DI, _JSRT_STRBUF
        MOV   DX, BX
_JSL_83:
        OR   DX, DX
        JZ   _JSL_84
        CMP   BYTE PTR [SI], 0
        JE   _JSL_85
        INC   SI
        DEC   DX
        JMP   _JSL_83
_JSL_84:
        CMP   BX, CX
        JGE   _JSL_85
        CMP   BYTE PTR [SI], 0
        JE   _JSL_85
        MOV   AL, [SI]
        MOV   [DI], AL
        INC   SI
        INC   DI
        INC   BX
        JMP   _JSL_84
_JSL_85:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DX
        POP   DI
        RET
_JSRT_STRTOUPPER:
        PUSH   DI
        LEA   DI, _JSRT_STRBUF
_JSL_86:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_87
        CMP   AL, 'a'
        JB   _JSL_86C
        CMP   AL, 'z'
        JA   _JSL_86C
        SUB   AL, 32
_JSL_86C:
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_86
_JSL_87:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DI
        RET
_JSRT_STRTOLOWER:
        PUSH   DI
        LEA   DI, _JSRT_STRBUF
_JSL_88:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_89
        CMP   AL, 'A'
        JB   _JSL_88C
        CMP   AL, 'Z'
        JA   _JSL_88C
        ADD   AL, 32
_JSL_88C:
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_88
_JSL_89:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DI
        RET
_JSRT_STRTRIM:
        PUSH   DI
        PUSH   BX
_JSL_90:
        MOV   AL, [SI]
        CMP   AL, 32
        JE   _JSL_90S
        CMP   AL, 9
        JE   _JSL_90S
        JMP   _JSL_91
_JSL_90S:
        INC   SI
        JMP   _JSL_90
_JSL_91:
        LEA   DI, _JSRT_STRBUF
        MOV   BX, DI
_JSL_93:
        MOV   AL, [SI]
        MOV   [DI], AL
        OR   AL, AL
        JZ   _JSL_92
        INC   SI
        INC   DI
        JMP   _JSL_93
_JSL_92:
_JSL_94:
        DEC   DI
        CMP   DI, BX
        JB   _JSL_94D
        CMP   BYTE PTR [DI], 32
        JE   _JSL_94
        CMP   BYTE PTR [DI], 9
        JE   _JSL_94
_JSL_94D:
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
_JSL_95:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_98
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   CX, DX
_JSL_96:
        OR   CX, CX
        JZ   _JSL_97
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_96N
        INC   SI
        INC   DI
        DEC   CX
        JMP   _JSL_96
_JSL_96N:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_95
_JSL_97:
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
        JMP   _JSL_95
_JSL_98:
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
_JSL_99:
        OR   CX, CX
        JZ   _JSL_101
        MOV   SI, DX
_JSL_100:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_100D
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_100
_JSL_100D:
        DEC   CX
        JMP   _JSL_99
_JSL_101:
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
        JAE   _JSL_104
        SUB   CX, DX
        LEA   BX, _JSRT_STRBUF
        PUSH   SI
        MOV   SI, DI
_JSL_102:
        OR   CX, CX
        JZ   _JSL_103
        MOV   AL, [SI]
        OR   AL, AL
        JNZ   _JSL_102C
        MOV   SI, DI
        MOV   AL, [SI]
_JSL_102C:
        MOV   [BX], AL
        INC   BX
        INC   SI
        DEC   CX
        JMP   _JSL_102
_JSL_103:
        POP   SI
_JSL_105:
        MOV   AL, [SI]
        MOV   [BX], AL
        OR   AL, AL
        JZ   _JSL_105D
        INC   SI
        INC   BX
        JMP   _JSL_105
_JSL_105D:
        LEA   AX, _JSRT_STRBUF
        POP   DX
        POP   BX
        RET
_JSL_104:
        LEA   BX, _JSRT_STRBUF
_JSL_106:
        MOV   AL, [SI]
        MOV   [BX], AL
        OR   AL, AL
        JZ   _JSL_106D
        INC   SI
        INC   BX
        JMP   _JSL_106
_JSL_106D:
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
_JSL_107:
        CMP   BYTE PTR [SI], 32
        JE   _JSL_107S
        JMP   _JSL_107E
_JSL_107S:
        INC   SI
        JMP   _JSL_107
_JSL_107E:
        CMP   BYTE PTR [SI], '-'
        JNE   _JSL_107P
        MOV   BX, 1
        INC   SI
        JMP   _JSL_108
_JSL_107P:
        CMP   BYTE PTR [SI], '+'
        JNE   _JSL_108
        INC   SI
_JSL_108:
        XOR   DX, DX
        MOV   DL, [SI]
        OR   DL, DL
        JZ   _JSL_109
        CMP   DL, '0'
        JB   _JSL_109
        CMP   DL, '9'
        JA   _JSL_108H
        SUB   DL, '0'
        JMP   _JSL_108M
_JSL_108H:
        CMP   DL, 'a'
        JB   _JSL_108U
        CMP   DL, 'f'
        JA   _JSL_109
        SUB   DL, 'a'
        ADD   DL, 10
        JMP   _JSL_108M
_JSL_108U:
        CMP   DL, 'A'
        JB   _JSL_109
        CMP   DL, 'F'
        JA   _JSL_109
        SUB   DL, 'A'
        ADD   DL, 10
_JSL_108M:
        CMP   DL, CL
        JAE   _JSL_109
        PUSH   DX
        PUSH   CX
        MUL    CX
        POP   CX
        POP   DX
        ADD   AX, DX
        INC   SI
        JMP   _JSL_108
_JSL_109:
        OR   BX, BX
        JZ   _JSL_109D
        NEG    AX
_JSL_109D:
        POP   DX
        POP   BX
        RET
_JSRT_ABS:
        OR   AX, AX
        JNS   _JSL_110
        NEG    AX
_JSL_110:
        RET
_JSRT_POW:
        PUSH   CX
        PUSH   DX
        MOV   CX, BX
        MOV   BX, AX
        MOV   AX, 1
_JSL_111:
        OR   CX, CX
        JZ   _JSL_112
        PUSH   DX
        MUL    BX
        POP   DX
        DEC   CX
        JMP   _JSL_111
_JSL_112:
        POP   DX
        POP   CX
        RET
_JSRT_SQRT:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        OR   AX, AX
        JZ   _JSL_114
        MOV   BX, AX
        SHR   AX, 1
        OR   AX, AX
        JZ   _JSL_114O
_JSL_113:
        MOV   CX, AX
        PUSH   BX
        XOR   DX, DX
        MOV   AX, BX
        DIV    CX
        POP   BX
        ADD   AX, CX
        SHR   AX, 1
        CMP   AX, CX
        JB   _JSL_113
        MOV   AX, CX
_JSL_114:
        POP   DX
        POP   CX
        POP   BX
        RET
_JSL_114O:
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
        JZ   _JSL_116
        JS   _JSL_115
        MOV   AX, 1
        JMP   _JSL_116
_JSL_115:
        MOV   AX, 0FFFFh
_JSL_116:
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
_JSV_sum  DW  0
_JSV_diff  DW  0
_JSV_prod  DW  0
_JSV_quot  DW  0
_JSV_rem  DW  0
_JSV_c1  DW  0
_JSV_c2  DW  0
_JSV_c3  DW  0
_JSV_c4  DW  0
_JSV_c5  DW  0
_JSV_eq  DW  0
_JSV_ne  DW  0
_JSV_lt  DW  0
_JSV_le  DW  0
_JSV_gt  DW  0
_JSV_ge  DW  0
_JSV_seq  DW  0
_JSV_sne  DW  0
_JSV_band  DW  0
_JSV_bor  DW  0
_JSV_bxor  DW  0
_JSV_shl  DW  0
_JSV_shr  DW  0
_JSV_x  DW  0
_JSV_y  DW  0
_JSV_and1  DW  0
_JSV_or1  DW  0
_JSV_and2  DW  0
_JSV_or2  DW  0
_JSV_n  DW  0
_JSV_nul  DW  0
_JSV_t1  DW  0
_JSV_t2  DW  0
_JSV_t3  DW  0
_JSV_t4  DW  0
_JSV_v  DW  0
_JSV_m1  DW  0
_JSV_m2  DW  0
_JSV_m3  DW  0
_JSV_s1  DW  0
_JSK_22  DB  'hello',0
_JSV_s2  DW  0
_JSK_23  DB  'world',0
_JSV_s3  DW  0
_DATA   ENDS

        END
