; Genere par JS86 v1.0 - SAMPLES\JS\test20.js

        .MODEL SMALL
        .STACK 1024

_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME  CS:_TEXT, DS:_DATA, SS:STACK

; --- debut du code genere ---

        LEA   AX, _JSK_1
        MOV   [_JSV_s], AX
        MOV   AX, [_JSV_s]
        MOV   SI, AX
        CALL   _JSRT_STRLEN
        MOV   [_JSV_len], AX
        MOV   AX, [_JSV_len]
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
        MOV   AX, [_JSV_s]
        MOV   SI, AX
        PUSH   SI
        LEA   AX, _JSK_4
        MOV   DI, AX
        POP   SI
        CALL   _JSRT_STRINDEXOF
        MOV   [_JSV_idx], AX
        MOV   AX, [_JSV_idx]
        CALL   _JSRT_NUMTOSTR
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
        LEA   AX, _JSK_7
        MOV   [_JSV_s2], AX
        MOV   AX, [_JSV_s2]
        MOV   SI, AX
        PUSH   SI
        LEA   AX, _JSK_8
        MOV   DI, AX
        POP   SI
        CALL   _JSRT_STRLASTIDX
        MOV   [_JSV_li], AX
        MOV   AX, [_JSV_li]
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
        MOV   AX, [_JSV_s]
        MOV   SI, AX
        PUSH   SI
        LEA   AX, _JSK_11
        MOV   DI, AX
        POP   SI
        CALL   _JSRT_STRINDEXOF
        CMP   AX, 0FFFFh
        JE   _JSL_12
        MOV   AX, 1
        JMP   _JSL_13
_JSL_12:
        XOR   AX, AX
_JSL_13:
        MOV   [_JSV_inc], AX
        MOV   AX, [_JSV_inc]
        OR   AX, AX
        JNZ   _JSL_14
        LEA   DI, _JS_FALSE
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
        LEA   DX, _JS_FALSE
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        JMP   _JSL_15
_JSL_14:
        LEA   DI, _JS_TRUE
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
        LEA   DX, _JS_TRUE
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
_JSL_15:
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        MOV   AX, [_JSV_s]
        MOV   SI, AX
        PUSH   SI
        LEA   AX, _JSK_20
        MOV   DI, AX
        POP   SI
        CALL   _JSRT_STRSTARTW
        MOV   [_JSV_sw], AX
        MOV   AX, [_JSV_sw]
        OR   AX, AX
        JNZ   _JSL_21
        LEA   DI, _JS_FALSE
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
        LEA   DX, _JS_FALSE
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        JMP   _JSL_22
_JSL_21:
        LEA   DI, _JS_TRUE
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
        LEA   DX, _JS_TRUE
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
_JSL_22:
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        MOV   AX, [_JSV_s]
        MOV   SI, AX
        PUSH   SI
        LEA   AX, _JSK_27
        MOV   DI, AX
        POP   SI
        CALL   _JSRT_STRENDW
        MOV   [_JSV_ew], AX
        MOV   AX, [_JSV_ew]
        OR   AX, AX
        JNZ   _JSL_28
        LEA   DI, _JS_FALSE
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
        LEA   DX, _JS_FALSE
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        JMP   _JSL_29
_JSL_28:
        LEA   DI, _JS_TRUE
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
        LEA   DX, _JS_TRUE
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
_JSL_29:
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        MOV   AX, [_JSV_s]
        MOV   SI, AX
        PUSH   SI
        MOV   AX, 0
        MOV   CX, AX
        POP   SI
        CALL   _JSRT_STRCHAR
        MOV   [_JSV_ch], AX
        MOV   AX, [_JSV_ch]
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
        MOV   AX, [_JSV_s]
        MOV   SI, AX
        PUSH   SI
        MOV   AX, 0
        MOV   CX, AX
        POP   SI
        CALL   _JSRT_STRORD
        MOV   [_JSV_code], AX
        MOV   AX, [_JSV_code]
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
        MOV   AX, [_JSV_s]
        MOV   SI, AX
        CALL   _JSRT_STRTOUPPER
        MOV   [_JSV_up], AX
        MOV   AX, [_JSV_up]
        MOV   DI, AX
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
        CALL   _JSRT_STRTOLOWER
        MOV   [_JSV_lo], AX
        MOV   AX, [_JSV_lo]
        MOV   DI, AX
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
        MOV   DX, DI
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        LEA   AX, _JSK_42
        MOV   [_JSV_s3], AX
        MOV   AX, [_JSV_s3]
        MOV   SI, AX
        CALL   _JSRT_STRTRIM
        MOV   [_JSV_tr], AX
        MOV   AX, [_JSV_tr]
        MOV   DI, AX
        XOR   CX, CX
_JSL_43:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_44
        INC    CX
        INC    DI
        JMP   _JSL_43
_JSL_44:
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
        MOV   AX, 0
        MOV   BX, AX
        MOV   AX, 5
        MOV   CX, AX
        POP   SI
        CALL   _JSRT_STRSLICE
        MOV   [_JSV_sl], AX
        MOV   AX, [_JSV_sl]
        MOV   DI, AX
        XOR   CX, CX
_JSL_45:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_46
        INC    CX
        INC    DI
        JMP   _JSL_45
_JSL_46:
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
        MOV   AX, 6
        MOV   BX, AX
        MOV   AX, 11
        MOV   CX, AX
        POP   SI
        CALL   _JSRT_STRSLICE
        MOV   [_JSV_sub], AX
        MOV   AX, [_JSV_sub]
        MOV   DI, AX
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
        MOV   DX, DI
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        LEA   AX, _JSK_49
        MOV   SI, AX
        PUSH   SI
        MOV   AX, 3
        MOV   CX, AX
        POP   SI
        LEA   DI, _JSRT_STRBUF
        CALL   _JSRT_STRREPEAT
        MOV   [_JSV_rp], AX
        MOV   AX, [_JSV_rp]
        MOV   DI, AX
        XOR   CX, CX
_JSL_50:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_51
        INC    CX
        INC    DI
        JMP   _JSL_50
_JSL_51:
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
        LEA   AX, _JSK_52
        MOV   SI, AX
        PUSH   SI
        MOV   AX, 5
        MOV   CX, AX
        LEA   AX, _JSK_53
        MOV   DI, AX
        POP   SI
        CALL   _JSRT_STRPADS
        MOV   [_JSV_ps], AX
        MOV   AX, [_JSV_ps]
        MOV   DI, AX
        XOR   CX, CX
_JSL_54:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_55
        INC    CX
        INC    DI
        JMP   _JSL_54
_JSL_55:
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
        MOV   AX, 65
        CALL   _JSRT_CHR
        MOV   [_JSV_fc], AX
        MOV   AX, [_JSV_fc]
        MOV   DI, AX
        XOR   CX, CX
_JSL_56:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_57
        INC    CX
        INC    DI
        JMP   _JSL_56
_JSL_57:
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
        LEA   AX, _JSK_58
        MOV   SI, AX
        PUSH   SI
        LEA   AX, _JSK_59
        MOV   DI, AX
        POP   SI
        CALL   _JSRT_STRSPLIT
        MOV   [_JSV_parts], AX
        MOV   AX, [_JSV_parts]
        MOV   SI, AX
        MOV   AX, [SI]
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_60:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_61
        INC    CX
        INC    DI
        JMP   _JSL_60
_JSL_61:
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
        LEA   AX, _JSK_62
        MOV   SI, AX
        MOV   CX, 10
        CALL   _JSRT_STRTOINT
        MOV   [_JSV_n1], AX
        MOV   AX, [_JSV_n1]
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_63:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_64
        INC    CX
        INC    DI
        JMP   _JSL_63
_JSL_64:
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
        LEA   AX, _JSK_65
        MOV   SI, AX
        MOV   AX, 16
        MOV   CX, AX
        CALL   _JSRT_STRTOINT
        MOV   [_JSV_n2], AX
        MOV   AX, [_JSV_n2]
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_66:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_67
        INC    CX
        INC    DI
        JMP   _JSL_66
_JSL_67:
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
        LEA   AX, _JSK_68
        MOV   SI, AX
        CALL   _JSRT_STRTONUM
        MOV   [_JSV_n3], AX
        MOV   AX, [_JSV_n3]
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_69:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_70
        INC    CX
        INC    DI
        JMP   _JSL_69
_JSL_70:
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
        MOV   AX, 42
        XOR   AX, AX
        MOV   [_JSV_nan], AX
        MOV   AX, [_JSV_nan]
        OR   AX, AX
        JNZ   _JSL_71
        LEA   DI, _JS_FALSE
        XOR   CX, CX
_JSL_73:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_74
        INC    CX
        INC    DI
        JMP   _JSL_73
_JSL_74:
        SUB   DI, CX
        LEA   DX, _JS_FALSE
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        JMP   _JSL_72
_JSL_71:
        LEA   DI, _JS_TRUE
        XOR   CX, CX
_JSL_75:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_76
        INC    CX
        INC    DI
        JMP   _JSL_75
_JSL_76:
        SUB   DI, CX
        LEA   DX, _JS_TRUE
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
_JSL_72:
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        MOV   AX, 42
        MOV   AX, 1
        MOV   [_JSV_fin], AX
        MOV   AX, [_JSV_fin]
        OR   AX, AX
        JNZ   _JSL_77
        LEA   DI, _JS_FALSE
        XOR   CX, CX
_JSL_79:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_80
        INC    CX
        INC    DI
        JMP   _JSL_79
_JSL_80:
        SUB   DI, CX
        LEA   DX, _JS_FALSE
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        JMP   _JSL_78
_JSL_77:
        LEA   DI, _JS_TRUE
        XOR   CX, CX
_JSL_81:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_82
        INC    CX
        INC    DI
        JMP   _JSL_81
_JSL_82:
        SUB   DI, CX
        LEA   DX, _JS_TRUE
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
_JSL_78:
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        MOV   AX, 42
        MOV   AX, 1
        MOV   [_JSV_ni], AX
        MOV   AX, [_JSV_ni]
        OR   AX, AX
        JNZ   _JSL_83
        LEA   DI, _JS_FALSE
        XOR   CX, CX
_JSL_85:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_86
        INC    CX
        INC    DI
        JMP   _JSL_85
_JSL_86:
        SUB   DI, CX
        LEA   DX, _JS_FALSE
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        JMP   _JSL_84
_JSL_83:
        LEA   DI, _JS_TRUE
        XOR   CX, CX
_JSL_87:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_88
        INC    CX
        INC    DI
        JMP   _JSL_87
_JSL_88:
        SUB   DI, CX
        LEA   DX, _JS_TRUE
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
_JSL_84:
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        MOV   AX, -5
        CALL   _JSRT_ABS
        MOV   [_JSV_ab], AX
        MOV   AX, [_JSV_ab]
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_89:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_90
        INC    CX
        INC    DI
        JMP   _JSL_89
_JSL_90:
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
        MOV   AX, 3
        PUSH   AX
        MOV   AX, 7
        POP   BX
        CMP   BX, AX
        JLE   _JSL_91
        MOV   AX, BX
_JSL_91:
        MOV   [_JSV_mx], AX
        MOV   AX, [_JSV_mx]
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_92:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_93
        INC    CX
        INC    DI
        JMP   _JSL_92
_JSL_93:
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
        MOV   AX, 3
        PUSH   AX
        MOV   AX, 7
        POP   BX
        CMP   BX, AX
        JGE   _JSL_94
        MOV   AX, BX
_JSL_94:
        MOV   [_JSV_mn], AX
        MOV   AX, [_JSV_mn]
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_95:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_96
        INC    CX
        INC    DI
        JMP   _JSL_95
_JSL_96:
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
        MOV   AX, 2
        PUSH   AX
        MOV   AX, 10
        MOV   BX, AX
        POP   AX
        CALL   _JSRT_POW
        MOV   [_JSV_pw], AX
        MOV   AX, [_JSV_pw]
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_97:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_98
        INC    CX
        INC    DI
        JMP   _JSL_97
_JSL_98:
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
        MOV   AX, 144
        CALL   _JSRT_SQRT
        MOV   [_JSV_sq], AX
        MOV   AX, [_JSV_sq]
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_99:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_100
        INC    CX
        INC    DI
        JMP   _JSL_99
_JSL_100:
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
        MOV   AX, 42
        MOV   [_JSV_fl], AX
        MOV   AX, [_JSV_fl]
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_101:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_102
        INC    CX
        INC    DI
        JMP   _JSL_101
_JSL_102:
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
        MOV   AX, -10
        CALL   _JSRT_SIGN
        MOV   [_JSV_sg], AX
        MOV   AX, [_JSV_sg]
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_103:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_104
        INC    CX
        INC    DI
        JMP   _JSL_103
_JSL_104:
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
        MOV   AX, 3
        MOV   [_JSV_pi], AX
        MOV   AX, [_JSV_pi]
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_105:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_106
        INC    CX
        INC    DI
        JMP   _JSL_105
_JSL_106:
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
        CALL   _JSRT_RAND
        MOV   [_JSV_rnd], AX
        MOV   AX, 42
        CALL   _JSRT_JSONSTR
        MOV   [_JSV_js], AX
        MOV   AX, [_JSV_js]
        MOV   DI, AX
        XOR   CX, CX
_JSL_107:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_108
        INC    CX
        INC    DI
        JMP   _JSL_107
_JSL_108:
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
        XOR   AX, AX
        MOV   [_JSV_jp], AX
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
        JZ   _JSL_109
        DEC   BX
        MOV   [SI], BX
        MOV   DI, BX
        SHL   DI, 1
        ADD   DI, 2
        ADD   DI, SI
        MOV   AX, [DI]
        RET
_JSL_109:
        XOR   AX, AX
        RET
_JSRT_ARRSHIFT:
        MOV   CX, [SI]
        OR   CX, CX
        JZ   _JSL_110
        MOV   AX, [SI+2]
        PUSH   AX
        DEC   CX
        MOV   [SI], CX
        LEA   DI, [SI+2]
        LEA   BX, [SI+4]
_JSL_111:
        OR   CX, CX
        JZ   _JSL_112
        MOV   AX, [BX]
        MOV   [DI], AX
        ADD   DI, 2
        ADD   BX, 2
        DEC   CX
        JMP   _JSL_111
_JSL_112:
        POP   AX
        RET
_JSL_110:
        XOR   AX, AX
        RET
_JSRT_ARRUNSHIFT:
        PUSH   AX
        MOV   CX, [SI]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        ADD   DI, 2
_JSL_113:
        OR   CX, CX
        JZ   _JSL_114
        MOV   AX, [DI-2]
        MOV   [DI], AX
        SUB   DI, 2
        DEC   CX
        JMP   _JSL_113
_JSL_114:
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
_JSL_115:
        OR   CX, CX
        JZ   _JSL_116
        CMP   [SI], BX
        JE   _JSL_117
        ADD   SI, 2
        INC   DX
        DEC   CX
        JMP   _JSL_115
_JSL_117:
        MOV   AX, DX
        RET
_JSL_116:
        MOV   AX, -1
        RET
_JSRT_ARRREV:
        MOV   CX, [SI]
        CMP   CX, 2
        JL   _JSL_118
        LEA   BX, [SI+2]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        SUB   DI, 2
_JSL_119:
        CMP   BX, DI
        JGE   _JSL_120
        MOV   AX, [BX]
        MOV   DX, [DI]
        MOV   [BX], DX
        MOV   [DI], AX
        ADD   BX, 2
        SUB   DI, 2
        JMP   _JSL_119
_JSL_120:
_JSL_118:
        MOV   AX, SI
        RET
_JSRT_ARRSORT:
        PUSH   SI
_JSL_121:
        XOR   DX, DX
        MOV   CX, [SI]
        DEC   CX
        CMP   CX, 0
        JLE   _JSL_124
        LEA   BX, [SI+2]
_JSL_122:
        MOV   AX, [BX]
        CMP   AX, [BX+2]
        JLE   _JSL_123
        MOV   DI, [BX+2]
        MOV   [BX], DI
        MOV   [BX+2], AX
        MOV   DX, 1
_JSL_123:
        ADD   BX, 2
        DEC   CX
        OR   CX, CX
        JNZ   _JSL_122
        OR   DX, DX
        JNZ   _JSL_121
_JSL_124:
        POP   AX
        RET

; --- runtime object routines (TODO 16) ---
_JSRT_STRCMP:
        PUSH   SI
        PUSH   DI
_JSL_125:
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_127
        OR   AL, AL
        JZ   _JSL_126
        INC   SI
        INC   DI
        JMP   _JSL_125
_JSL_126:
        XOR   AX, AX
        POP   DI
        POP   SI
        RET
_JSL_127:
        MOV   AX, 1
        POP   DI
        POP   SI
        RET
_JSRT_OBJGET:
        PUSH   CX
        PUSH   BX
        MOV   CX, [BX]
        ADD   BX, 2
_JSL_128:
        OR   CX, CX
        JZ   _JSL_130
        PUSH   CX
        PUSH   BX
        PUSH   DI
        MOV   SI, [BX]
        CALL   _JSRT_STRCMP
        POP   DI
        POP   BX
        POP   CX
        OR   AX, AX
        JZ   _JSL_129
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_128
_JSL_129:
        MOV   AX, [BX+2]
        POP   BX
        POP   CX
        RET
_JSL_130:
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
_JSL_131:
        OR   CX, CX
        JZ   _JSL_133
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
        JZ   _JSL_132
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_131
_JSL_132:
        MOV   [BX+2], DX
        MOV   AX, DX
        POP   BX
        POP   CX
        RET
_JSL_133:
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
_JSL_134:
        OR   CX, CX
        JZ   _JSL_135
        MOV   AX, [SI]
        MOV   [DI], AX
        ADD   SI, 4
        ADD   DI, 2
        DEC   CX
        JMP   _JSL_134
_JSL_135:
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
_JSL_136:
        OR   CX, CX
        JZ   _JSL_137
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
        JMP   _JSL_136
_JSL_137:
        POP   BX
        MOV   AX, BX
        POP   DI
        POP   CX
        RET

; --- runtime regexp routines (TODO 19) ---
_JSRT_REPARSE:
        PUSH   BX
        MOV   BX, DI
_JSL_138:
        MOV   AL, [BX]
        CMP   AL, 1
        JZ   _JSL_139
        OR   AL, AL
        JZ   _JSL_139
        INC   BX
        JMP   _JSL_138
_JSL_139:
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
        JZ   _JSL_142
_JSL_140:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_143
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   DX, CX
_JSL_141:
        OR   DX, DX
        JZ   _JSL_142B
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_143B
        INC   SI
        INC   DI
        DEC   DX
        JMP   _JSL_141
_JSL_142B:
        POP   CX
        POP   DI
        POP   SI
        JMP   _JSL_142
_JSL_143B:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_140
_JSL_142:
        MOV   AX, 1
        POP   DX
        POP   CX
        POP   BX
        POP   DI
        POP   SI
        RET
_JSL_143:
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
        JZ   _JSL_146
_JSL_144:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_147
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   DX, CX
_JSL_145:
        OR   DX, DX
        JZ   _JSL_146B
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_147B
        INC   SI
        INC   DI
        DEC   DX
        JMP   _JSL_145
_JSL_146B:
        POP   CX
        POP   DI
        POP   SI
        JMP   _JSL_146
_JSL_147B:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_144
_JSL_146:
        MOV   AX, SI
        SUB   AX, BX
        POP   DX
        POP   CX
        POP   BX
        POP   DI
        POP   SI
        RET
_JSL_147:
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
        JZ   _JSL_148
        MOV   AX, SI
        RET
_JSL_148:
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
_JSL_149:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_152
        OR   DX, DX
        JZ   _JSL_150C
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   CX, DX
_JSL_150:
        OR   CX, CX
        JZ   _JSL_151
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_150N
        INC   SI
        INC   DI
        DEC   CX
        JMP   _JSL_150
_JSL_150N:
        POP   CX
        POP   DI
        POP   SI
_JSL_150C:
        MOV   AL, [SI]
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_149
_JSL_151:
        POP   CX
        POP   DI
        POP   AX
        PUSH   SI
        MOV   SI, [SP+10]
_JSL_153:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_153D
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_153
_JSL_153D:
        POP   SI
_JSL_154:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_152
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_154
_JSL_152:
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
_JSL_155:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_156
        INC   AX
        INC   SI
        JMP   _JSL_155
_JSL_156:
        POP   SI
        RET
_JSRT_STRINDEXOF:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        MOV   BX, SI
_JSL_157:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_160
        PUSH   SI
        PUSH   DI
_JSL_158:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_159
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_158N
        INC   SI
        INC   DI
        JMP   _JSL_158
_JSL_159:
        POP   DI
        POP   AX
        SUB   AX, BX
        POP   DX
        POP   CX
        POP   BX
        RET
_JSL_158N:
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_157
_JSL_160:
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
_JSL_161:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_164
        PUSH   SI
        PUSH   DI
_JSL_162:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_163
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_162N
        INC   SI
        INC   DI
        JMP   _JSL_162
_JSL_163:
        POP   DI
        POP   AX
        SUB   AX, BX
        MOV   DX, AX
        ADD   AX, BX
        MOV   SI, AX
        INC   SI
        JMP   _JSL_161
_JSL_162N:
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_161
_JSL_164:
        MOV   AX, DX
        POP   DX
        POP   CX
        POP   BX
        RET
_JSRT_STRSTARTW:
_JSL_165:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_165Y
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_166
        INC   SI
        INC   DI
        JMP   _JSL_165
_JSL_165Y:
        MOV   AX, 1
        RET
_JSL_166:
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
        JA   _JSL_167
        SUB   BX, CX
        ADD   SI, BX
        POP   CX
        POP   BX
        JMP   _JSRT_STRSTARTW
_JSL_167:
        XOR   AX, AX
        POP   CX
        POP   BX
        RET
_JSRT_STRSLICE:
        PUSH   DI
        PUSH   DX
        LEA   DI, _JSRT_STRBUF
        MOV   DX, BX
_JSL_168:
        OR   DX, DX
        JZ   _JSL_169
        CMP   BYTE PTR [SI], 0
        JE   _JSL_170
        INC   SI
        DEC   DX
        JMP   _JSL_168
_JSL_169:
        CMP   BX, CX
        JGE   _JSL_170
        CMP   BYTE PTR [SI], 0
        JE   _JSL_170
        MOV   AL, [SI]
        MOV   [DI], AL
        INC   SI
        INC   DI
        INC   BX
        JMP   _JSL_169
_JSL_170:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DX
        POP   DI
        RET
_JSRT_STRTOUPPER:
        PUSH   DI
        LEA   DI, _JSRT_STRBUF
_JSL_171:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_172
        CMP   AL, 'a'
        JB   _JSL_171C
        CMP   AL, 'z'
        JA   _JSL_171C
        SUB   AL, 32
_JSL_171C:
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_171
_JSL_172:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DI
        RET
_JSRT_STRTOLOWER:
        PUSH   DI
        LEA   DI, _JSRT_STRBUF
_JSL_173:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_174
        CMP   AL, 'A'
        JB   _JSL_173C
        CMP   AL, 'Z'
        JA   _JSL_173C
        ADD   AL, 32
_JSL_173C:
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_173
_JSL_174:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DI
        RET
_JSRT_STRTRIM:
        PUSH   DI
        PUSH   BX
_JSL_175:
        MOV   AL, [SI]
        CMP   AL, 32
        JE   _JSL_175S
        CMP   AL, 9
        JE   _JSL_175S
        JMP   _JSL_176
_JSL_175S:
        INC   SI
        JMP   _JSL_175
_JSL_176:
        LEA   DI, _JSRT_STRBUF
        MOV   BX, DI
_JSL_178:
        MOV   AL, [SI]
        MOV   [DI], AL
        OR   AL, AL
        JZ   _JSL_177
        INC   SI
        INC   DI
        JMP   _JSL_178
_JSL_177:
_JSL_179:
        DEC   DI
        CMP   DI, BX
        JB   _JSL_179D
        CMP   BYTE PTR [DI], 32
        JE   _JSL_179
        CMP   BYTE PTR [DI], 9
        JE   _JSL_179
_JSL_179D:
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
_JSL_180:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_183
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   CX, DX
_JSL_181:
        OR   CX, CX
        JZ   _JSL_182
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_181N
        INC   SI
        INC   DI
        DEC   CX
        JMP   _JSL_181
_JSL_181N:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_180
_JSL_182:
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
        JMP   _JSL_180
_JSL_183:
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
_JSL_184:
        OR   CX, CX
        JZ   _JSL_186
        MOV   SI, DX
_JSL_185:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_185D
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_185
_JSL_185D:
        DEC   CX
        JMP   _JSL_184
_JSL_186:
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
        JAE   _JSL_189
        SUB   CX, DX
        LEA   BX, _JSRT_STRBUF
        PUSH   SI
        MOV   SI, DI
_JSL_187:
        OR   CX, CX
        JZ   _JSL_188
        MOV   AL, [SI]
        OR   AL, AL
        JNZ   _JSL_187C
        MOV   SI, DI
        MOV   AL, [SI]
_JSL_187C:
        MOV   [BX], AL
        INC   BX
        INC   SI
        DEC   CX
        JMP   _JSL_187
_JSL_188:
        POP   SI
_JSL_190:
        MOV   AL, [SI]
        MOV   [BX], AL
        OR   AL, AL
        JZ   _JSL_190D
        INC   SI
        INC   BX
        JMP   _JSL_190
_JSL_190D:
        LEA   AX, _JSRT_STRBUF
        POP   DX
        POP   BX
        RET
_JSL_189:
        LEA   BX, _JSRT_STRBUF
_JSL_191:
        MOV   AL, [SI]
        MOV   [BX], AL
        OR   AL, AL
        JZ   _JSL_191D
        INC   SI
        INC   BX
        JMP   _JSL_191
_JSL_191D:
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
_JSL_192:
        CMP   BYTE PTR [SI], 32
        JE   _JSL_192S
        JMP   _JSL_192E
_JSL_192S:
        INC   SI
        JMP   _JSL_192
_JSL_192E:
        CMP   BYTE PTR [SI], '-'
        JNE   _JSL_192P
        MOV   BX, 1
        INC   SI
        JMP   _JSL_193
_JSL_192P:
        CMP   BYTE PTR [SI], '+'
        JNE   _JSL_193
        INC   SI
_JSL_193:
        XOR   DX, DX
        MOV   DL, [SI]
        OR   DL, DL
        JZ   _JSL_194
        CMP   DL, '0'
        JB   _JSL_194
        CMP   DL, '9'
        JA   _JSL_193H
        SUB   DL, '0'
        JMP   _JSL_193M
_JSL_193H:
        CMP   DL, 'a'
        JB   _JSL_193U
        CMP   DL, 'f'
        JA   _JSL_194
        SUB   DL, 'a'
        ADD   DL, 10
        JMP   _JSL_193M
_JSL_193U:
        CMP   DL, 'A'
        JB   _JSL_194
        CMP   DL, 'F'
        JA   _JSL_194
        SUB   DL, 'A'
        ADD   DL, 10
_JSL_193M:
        CMP   DL, CL
        JAE   _JSL_194
        PUSH   DX
        PUSH   CX
        MUL    CX
        POP   CX
        POP   DX
        ADD   AX, DX
        INC   SI
        JMP   _JSL_193
_JSL_194:
        OR   BX, BX
        JZ   _JSL_194D
        NEG    AX
_JSL_194D:
        POP   DX
        POP   BX
        RET
_JSRT_ABS:
        OR   AX, AX
        JNS   _JSL_195
        NEG    AX
_JSL_195:
        RET
_JSRT_POW:
        PUSH   CX
        PUSH   DX
        MOV   CX, BX
        MOV   BX, AX
        MOV   AX, 1
_JSL_196:
        OR   CX, CX
        JZ   _JSL_197
        PUSH   DX
        MUL    BX
        POP   DX
        DEC   CX
        JMP   _JSL_196
_JSL_197:
        POP   DX
        POP   CX
        RET
_JSRT_SQRT:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        OR   AX, AX
        JZ   _JSL_199
        MOV   BX, AX
        SHR   AX, 1
        OR   AX, AX
        JZ   _JSL_199O
_JSL_198:
        MOV   CX, AX
        PUSH   BX
        XOR   DX, DX
        MOV   AX, BX
        DIV    CX
        POP   BX
        ADD   AX, CX
        SHR   AX, 1
        CMP   AX, CX
        JB   _JSL_198
        MOV   AX, CX
_JSL_199:
        POP   DX
        POP   CX
        POP   BX
        RET
_JSL_199O:
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
        JZ   _JSL_201
        JS   _JSL_200
        MOV   AX, 1
        JMP   _JSL_201
_JSL_200:
        MOV   AX, 0FFFFh
_JSL_201:
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
_JSV_s  DW  0
_JSK_1  DB  'Hello World',0
_JSV_len  DW  0
_JSV_idx  DW  0
_JSK_4  DB  'World',0
_JSV_s2  DW  0
_JSK_7  DB  'abcabc',0
_JSV_li  DW  0
_JSK_8  DB  'abc',0
_JSV_inc  DW  0
_JSK_11  DB  'llo',0
_JSV_sw  DW  0
_JSK_20  DB  'Hel',0
_JSV_ew  DW  0
_JSK_27  DB  'rld',0
_JSV_ch  DW  0
_JSV_code  DW  0
_JSV_up  DW  0
_JSV_lo  DW  0
_JSV_s3  DW  0
_JSK_42  DB  '  hi  ',0
_JSV_tr  DW  0
_JSV_sl  DW  0
_JSV_sub  DW  0
_JSV_rp  DW  0
_JSK_49  DB  'ab',0
_JSV_ps  DW  0
_JSK_52  DB  '42',0
_JSK_53  DB  '0',0
_JSV_fc  DW  0
_JSV_parts  DW  0
_JSK_58  DB  'a,b,c',0
_JSK_59  DB  ',',0
_JSV_n1  DW  0
_JSK_62  DB  '42',0
_JSV_n2  DW  0
_JSK_65  DB  'FF',0
_JSV_n3  DW  0
_JSK_68  DB  '123',0
_JSV_nan  DW  0
_JSV_fin  DW  0
_JSV_ni  DW  0
_JSV_ab  DW  0
_JSV_mx  DW  0
_JSV_mn  DW  0
_JSV_pw  DW  0
_JSV_sq  DW  0
_JSV_fl  DW  0
_JSV_sg  DW  0
_JSV_pi  DW  0
_JSV_rnd  DW  0
_JSV_js  DW  0
_JSV_jp  DW  0
_DATA   ENDS

        END
