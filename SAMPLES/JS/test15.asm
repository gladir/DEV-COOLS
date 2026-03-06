; Genere par JS86 v1.0 - SAMPLES\JS\test15.js

        .MODEL SMALL
        .STACK 1024

_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME  CS:_TEXT, DS:_DATA, SS:STACK

; --- debut du code genere ---

        LEA   AX, _JSA_1
        MOV   [_JSV_arr], AX
        MOV   AX, [_JSV_arr]
        PUSH   AX
        MOV   AX, 0
        SHL   AX, 1
        ADD   AX, 2
        MOV   SI, AX
        POP   BX
        ADD   SI, BX
        MOV   AX, [SI]
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
        MOV   AX, [_JSV_arr]
        PUSH   AX
        MOV   AX, 1
        SHL   AX, 1
        ADD   AX, 2
        MOV   SI, AX
        POP   BX
        ADD   SI, BX
        MOV   AX, [SI]
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
        MOV   AX, [_JSV_arr]
        PUSH   AX
        MOV   AX, 2
        SHL   AX, 1
        ADD   AX, 2
        MOV   SI, AX
        POP   BX
        ADD   SI, BX
        MOV   AX, [SI]
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_6:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_7
        INC    CX
        INC    DI
        JMP   _JSL_6
_JSL_7:
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
        MOV   AX, [_JSV_arr]
        MOV   SI, AX
        MOV   AX, [SI]
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
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
        MOV   DX, DI
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        MOV   AX, [_JSV_arr]
        PUSH   AX
        MOV   AX, 1
        SHL   AX, 1
        ADD   AX, 2
        MOV   SI, AX
        POP   BX
        ADD   SI, BX
        PUSH   SI
        MOV   AX, 99
        POP   SI
        MOV   [SI], AX
        MOV   AX, [_JSV_arr]
        PUSH   AX
        MOV   AX, 1
        SHL   AX, 1
        ADD   AX, 2
        MOV   SI, AX
        POP   BX
        ADD   SI, BX
        MOV   AX, [SI]
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
        MOV   AX, [_JSV_arr]
        MOV   SI, AX
        PUSH   SI
        MOV   AX, 40
        POP   SI
        CALL   _JSRT_ARRPUSH
        MOV   AX, [_JSV_arr]
        MOV   SI, AX
        MOV   AX, [SI]
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_12:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_13
        INC    CX
        INC    DI
        JMP   _JSL_12
_JSL_13:
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
        MOV   AX, [_JSV_arr]
        PUSH   AX
        MOV   AX, 3
        SHL   AX, 1
        ADD   AX, 2
        MOV   SI, AX
        POP   BX
        ADD   SI, BX
        MOV   AX, [SI]
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
        MOV   AX, [_JSV_arr]
        MOV   SI, AX
        CALL   _JSRT_ARRPOP
        MOV   [_JSV_v], AX
        MOV   AX, [_JSV_v]
        CALL   _JSRT_NUMTOSTR
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
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        MOV   AX, [_JSV_arr]
        MOV   SI, AX
        MOV   AX, [SI]
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
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
        MOV   DX, DI
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        MOV   AX, [_JSV_arr]
        MOV   SI, AX
        PUSH   SI
        MOV   AX, 99
        MOV   BX, AX
        POP   SI
        CALL   _JSRT_ARRIDXOF
        MOV   [_JSV_idx], AX
        MOV   AX, [_JSV_idx]
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_20:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_21
        INC    CX
        INC    DI
        JMP   _JSL_20
_JSL_21:
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
        LEA   AX, _JSA_22
        MOV   [_JSV_r], AX
        MOV   AX, [_JSV_r]
        MOV   SI, AX
        CALL   _JSRT_ARRREV
        MOV   AX, [_JSV_r]
        PUSH   AX
        MOV   AX, 0
        SHL   AX, 1
        ADD   AX, 2
        MOV   SI, AX
        POP   BX
        ADD   SI, BX
        MOV   AX, [SI]
        CALL   _JSRT_NUMTOSTR
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
        MOV   AX, [_JSV_r]
        PUSH   AX
        MOV   AX, 2
        SHL   AX, 1
        ADD   AX, 2
        MOV   SI, AX
        POP   BX
        ADD   SI, BX
        MOV   AX, [SI]
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
        LEA   AX, _JSA_27
        MOV   [_JSV_s], AX
        MOV   AX, [_JSV_s]
        MOV   SI, AX
        CALL   _JSRT_ARRSORT
        MOV   AX, [_JSV_s]
        PUSH   AX
        MOV   AX, 0
        SHL   AX, 1
        ADD   AX, 2
        MOV   SI, AX
        POP   BX
        ADD   SI, BX
        MOV   AX, [SI]
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
        MOV   AX, [_JSV_s]
        PUSH   AX
        MOV   AX, 1
        SHL   AX, 1
        ADD   AX, 2
        MOV   SI, AX
        POP   BX
        ADD   SI, BX
        MOV   AX, [SI]
        CALL   _JSRT_NUMTOSTR
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
        MOV   AX, [_JSV_s]
        PUSH   AX
        MOV   AX, 2
        SHL   AX, 1
        ADD   AX, 2
        MOV   SI, AX
        POP   BX
        ADD   SI, BX
        MOV   AX, [SI]
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
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
        MOV   DX, DI
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        LEA   AX, _JSA_34
        MOV   [_JSV_a2], AX
        MOV   AX, [_JSV_a2]
        MOV   SI, AX
        MOV   AX, [SI]
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
        JZ   _JSL_37
        DEC   BX
        MOV   [SI], BX
        MOV   DI, BX
        SHL   DI, 1
        ADD   DI, 2
        ADD   DI, SI
        MOV   AX, [DI]
        RET
_JSL_37:
        XOR   AX, AX
        RET
_JSRT_ARRSHIFT:
        MOV   CX, [SI]
        OR   CX, CX
        JZ   _JSL_38
        MOV   AX, [SI+2]
        PUSH   AX
        DEC   CX
        MOV   [SI], CX
        LEA   DI, [SI+2]
        LEA   BX, [SI+4]
_JSL_39:
        OR   CX, CX
        JZ   _JSL_40
        MOV   AX, [BX]
        MOV   [DI], AX
        ADD   DI, 2
        ADD   BX, 2
        DEC   CX
        JMP   _JSL_39
_JSL_40:
        POP   AX
        RET
_JSL_38:
        XOR   AX, AX
        RET
_JSRT_ARRUNSHIFT:
        PUSH   AX
        MOV   CX, [SI]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        ADD   DI, 2
_JSL_41:
        OR   CX, CX
        JZ   _JSL_42
        MOV   AX, [DI-2]
        MOV   [DI], AX
        SUB   DI, 2
        DEC   CX
        JMP   _JSL_41
_JSL_42:
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
_JSL_43:
        OR   CX, CX
        JZ   _JSL_44
        CMP   [SI], BX
        JE   _JSL_45
        ADD   SI, 2
        INC   DX
        DEC   CX
        JMP   _JSL_43
_JSL_45:
        MOV   AX, DX
        RET
_JSL_44:
        MOV   AX, -1
        RET
_JSRT_ARRREV:
        MOV   CX, [SI]
        CMP   CX, 2
        JL   _JSL_46
        LEA   BX, [SI+2]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        SUB   DI, 2
_JSL_47:
        CMP   BX, DI
        JGE   _JSL_48
        MOV   AX, [BX]
        MOV   DX, [DI]
        MOV   [BX], DX
        MOV   [DI], AX
        ADD   BX, 2
        SUB   DI, 2
        JMP   _JSL_47
_JSL_48:
_JSL_46:
        MOV   AX, SI
        RET
_JSRT_ARRSORT:
        PUSH   SI
_JSL_49:
        XOR   DX, DX
        MOV   CX, [SI]
        DEC   CX
        CMP   CX, 0
        JLE   _JSL_52
        LEA   BX, [SI+2]
_JSL_50:
        MOV   AX, [BX]
        CMP   AX, [BX+2]
        JLE   _JSL_51
        MOV   DI, [BX+2]
        MOV   [BX], DI
        MOV   [BX+2], AX
        MOV   DX, 1
_JSL_51:
        ADD   BX, 2
        DEC   CX
        OR   CX, CX
        JNZ   _JSL_50
        OR   DX, DX
        JNZ   _JSL_49
_JSL_52:
        POP   AX
        RET

; --- runtime object routines (TODO 16) ---
_JSRT_STRCMP:
        PUSH   SI
        PUSH   DI
_JSL_53:
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_55
        OR   AL, AL
        JZ   _JSL_54
        INC   SI
        INC   DI
        JMP   _JSL_53
_JSL_54:
        XOR   AX, AX
        POP   DI
        POP   SI
        RET
_JSL_55:
        MOV   AX, 1
        POP   DI
        POP   SI
        RET
_JSRT_OBJGET:
        PUSH   CX
        PUSH   BX
        MOV   CX, [BX]
        ADD   BX, 2
_JSL_56:
        OR   CX, CX
        JZ   _JSL_58
        PUSH   CX
        PUSH   BX
        PUSH   DI
        MOV   SI, [BX]
        CALL   _JSRT_STRCMP
        POP   DI
        POP   BX
        POP   CX
        OR   AX, AX
        JZ   _JSL_57
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_56
_JSL_57:
        MOV   AX, [BX+2]
        POP   BX
        POP   CX
        RET
_JSL_58:
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
_JSL_59:
        OR   CX, CX
        JZ   _JSL_61
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
        JZ   _JSL_60
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_59
_JSL_60:
        MOV   [BX+2], DX
        MOV   AX, DX
        POP   BX
        POP   CX
        RET
_JSL_61:
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
_JSL_62:
        OR   CX, CX
        JZ   _JSL_63
        MOV   AX, [SI]
        MOV   [DI], AX
        ADD   SI, 4
        ADD   DI, 2
        DEC   CX
        JMP   _JSL_62
_JSL_63:
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
_JSL_64:
        OR   CX, CX
        JZ   _JSL_65
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
        JMP   _JSL_64
_JSL_65:
        POP   BX
        MOV   AX, BX
        POP   DI
        POP   CX
        RET

; --- runtime regexp routines (TODO 19) ---
_JSRT_REPARSE:
        PUSH   BX
        MOV   BX, DI
_JSL_66:
        MOV   AL, [BX]
        CMP   AL, 1
        JZ   _JSL_67
        OR   AL, AL
        JZ   _JSL_67
        INC   BX
        JMP   _JSL_66
_JSL_67:
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
        JZ   _JSL_70
_JSL_68:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_71
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   DX, CX
_JSL_69:
        OR   DX, DX
        JZ   _JSL_70B
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_71B
        INC   SI
        INC   DI
        DEC   DX
        JMP   _JSL_69
_JSL_70B:
        POP   CX
        POP   DI
        POP   SI
        JMP   _JSL_70
_JSL_71B:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_68
_JSL_70:
        MOV   AX, 1
        POP   DX
        POP   CX
        POP   BX
        POP   DI
        POP   SI
        RET
_JSL_71:
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
        MOV   AX, SI
        SUB   AX, BX
        POP   DX
        POP   CX
        POP   BX
        POP   DI
        POP   SI
        RET
_JSL_75:
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
        JZ   _JSL_76
        MOV   AX, SI
        RET
_JSL_76:
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
_JSL_77:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_80
        OR   DX, DX
        JZ   _JSL_78C
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   CX, DX
_JSL_78:
        OR   CX, CX
        JZ   _JSL_79
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_78N
        INC   SI
        INC   DI
        DEC   CX
        JMP   _JSL_78
_JSL_78N:
        POP   CX
        POP   DI
        POP   SI
_JSL_78C:
        MOV   AL, [SI]
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_77
_JSL_79:
        POP   CX
        POP   DI
        POP   AX
        PUSH   SI
        MOV   SI, [SP+10]
_JSL_81:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_81D
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_81
_JSL_81D:
        POP   SI
_JSL_82:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_80
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_82
_JSL_80:
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
_JSL_83:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_84
        INC   AX
        INC   SI
        JMP   _JSL_83
_JSL_84:
        POP   SI
        RET
_JSRT_STRINDEXOF:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        MOV   BX, SI
_JSL_85:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_88
        PUSH   SI
        PUSH   DI
_JSL_86:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_87
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_86N
        INC   SI
        INC   DI
        JMP   _JSL_86
_JSL_87:
        POP   DI
        POP   AX
        SUB   AX, BX
        POP   DX
        POP   CX
        POP   BX
        RET
_JSL_86N:
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_85
_JSL_88:
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
        MOV   DX, AX
        ADD   AX, BX
        MOV   SI, AX
        INC   SI
        JMP   _JSL_89
_JSL_90N:
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_89
_JSL_92:
        MOV   AX, DX
        POP   DX
        POP   CX
        POP   BX
        RET
_JSRT_STRSTARTW:
_JSL_93:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_93Y
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_94
        INC   SI
        INC   DI
        JMP   _JSL_93
_JSL_93Y:
        MOV   AX, 1
        RET
_JSL_94:
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
        JA   _JSL_95
        SUB   BX, CX
        ADD   SI, BX
        POP   CX
        POP   BX
        JMP   _JSRT_STRSTARTW
_JSL_95:
        XOR   AX, AX
        POP   CX
        POP   BX
        RET
_JSRT_STRSLICE:
        PUSH   DI
        PUSH   DX
        LEA   DI, _JSRT_STRBUF
        MOV   DX, BX
_JSL_96:
        OR   DX, DX
        JZ   _JSL_97
        CMP   BYTE PTR [SI], 0
        JE   _JSL_98
        INC   SI
        DEC   DX
        JMP   _JSL_96
_JSL_97:
        CMP   BX, CX
        JGE   _JSL_98
        CMP   BYTE PTR [SI], 0
        JE   _JSL_98
        MOV   AL, [SI]
        MOV   [DI], AL
        INC   SI
        INC   DI
        INC   BX
        JMP   _JSL_97
_JSL_98:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DX
        POP   DI
        RET
_JSRT_STRTOUPPER:
        PUSH   DI
        LEA   DI, _JSRT_STRBUF
_JSL_99:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_100
        CMP   AL, 'a'
        JB   _JSL_99C
        CMP   AL, 'z'
        JA   _JSL_99C
        SUB   AL, 32
_JSL_99C:
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_99
_JSL_100:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DI
        RET
_JSRT_STRTOLOWER:
        PUSH   DI
        LEA   DI, _JSRT_STRBUF
_JSL_101:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_102
        CMP   AL, 'A'
        JB   _JSL_101C
        CMP   AL, 'Z'
        JA   _JSL_101C
        ADD   AL, 32
_JSL_101C:
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_101
_JSL_102:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DI
        RET
_JSRT_STRTRIM:
        PUSH   DI
        PUSH   BX
_JSL_103:
        MOV   AL, [SI]
        CMP   AL, 32
        JE   _JSL_103S
        CMP   AL, 9
        JE   _JSL_103S
        JMP   _JSL_104
_JSL_103S:
        INC   SI
        JMP   _JSL_103
_JSL_104:
        LEA   DI, _JSRT_STRBUF
        MOV   BX, DI
_JSL_106:
        MOV   AL, [SI]
        MOV   [DI], AL
        OR   AL, AL
        JZ   _JSL_105
        INC   SI
        INC   DI
        JMP   _JSL_106
_JSL_105:
_JSL_107:
        DEC   DI
        CMP   DI, BX
        JB   _JSL_107D
        CMP   BYTE PTR [DI], 32
        JE   _JSL_107
        CMP   BYTE PTR [DI], 9
        JE   _JSL_107
_JSL_107D:
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
_JSL_108:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_111
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   CX, DX
_JSL_109:
        OR   CX, CX
        JZ   _JSL_110
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_109N
        INC   SI
        INC   DI
        DEC   CX
        JMP   _JSL_109
_JSL_109N:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_108
_JSL_110:
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
        JMP   _JSL_108
_JSL_111:
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
_JSL_112:
        OR   CX, CX
        JZ   _JSL_114
        MOV   SI, DX
_JSL_113:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_113D
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_113
_JSL_113D:
        DEC   CX
        JMP   _JSL_112
_JSL_114:
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
        JAE   _JSL_117
        SUB   CX, DX
        LEA   BX, _JSRT_STRBUF
        PUSH   SI
        MOV   SI, DI
_JSL_115:
        OR   CX, CX
        JZ   _JSL_116
        MOV   AL, [SI]
        OR   AL, AL
        JNZ   _JSL_115C
        MOV   SI, DI
        MOV   AL, [SI]
_JSL_115C:
        MOV   [BX], AL
        INC   BX
        INC   SI
        DEC   CX
        JMP   _JSL_115
_JSL_116:
        POP   SI
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
_JSL_117:
        LEA   BX, _JSRT_STRBUF
_JSL_119:
        MOV   AL, [SI]
        MOV   [BX], AL
        OR   AL, AL
        JZ   _JSL_119D
        INC   SI
        INC   BX
        JMP   _JSL_119
_JSL_119D:
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
_JSL_120:
        CMP   BYTE PTR [SI], 32
        JE   _JSL_120S
        JMP   _JSL_120E
_JSL_120S:
        INC   SI
        JMP   _JSL_120
_JSL_120E:
        CMP   BYTE PTR [SI], '-'
        JNE   _JSL_120P
        MOV   BX, 1
        INC   SI
        JMP   _JSL_121
_JSL_120P:
        CMP   BYTE PTR [SI], '+'
        JNE   _JSL_121
        INC   SI
_JSL_121:
        XOR   DX, DX
        MOV   DL, [SI]
        OR   DL, DL
        JZ   _JSL_122
        CMP   DL, '0'
        JB   _JSL_122
        CMP   DL, '9'
        JA   _JSL_121H
        SUB   DL, '0'
        JMP   _JSL_121M
_JSL_121H:
        CMP   DL, 'a'
        JB   _JSL_121U
        CMP   DL, 'f'
        JA   _JSL_122
        SUB   DL, 'a'
        ADD   DL, 10
        JMP   _JSL_121M
_JSL_121U:
        CMP   DL, 'A'
        JB   _JSL_122
        CMP   DL, 'F'
        JA   _JSL_122
        SUB   DL, 'A'
        ADD   DL, 10
_JSL_121M:
        CMP   DL, CL
        JAE   _JSL_122
        PUSH   DX
        PUSH   CX
        MUL    CX
        POP   CX
        POP   DX
        ADD   AX, DX
        INC   SI
        JMP   _JSL_121
_JSL_122:
        OR   BX, BX
        JZ   _JSL_122D
        NEG    AX
_JSL_122D:
        POP   DX
        POP   BX
        RET
_JSRT_ABS:
        OR   AX, AX
        JNS   _JSL_123
        NEG    AX
_JSL_123:
        RET
_JSRT_POW:
        PUSH   CX
        PUSH   DX
        MOV   CX, BX
        MOV   BX, AX
        MOV   AX, 1
_JSL_124:
        OR   CX, CX
        JZ   _JSL_125
        PUSH   DX
        MUL    BX
        POP   DX
        DEC   CX
        JMP   _JSL_124
_JSL_125:
        POP   DX
        POP   CX
        RET
_JSRT_SQRT:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        OR   AX, AX
        JZ   _JSL_127
        MOV   BX, AX
        SHR   AX, 1
        OR   AX, AX
        JZ   _JSL_127O
_JSL_126:
        MOV   CX, AX
        PUSH   BX
        XOR   DX, DX
        MOV   AX, BX
        DIV    CX
        POP   BX
        ADD   AX, CX
        SHR   AX, 1
        CMP   AX, CX
        JB   _JSL_126
        MOV   AX, CX
_JSL_127:
        POP   DX
        POP   CX
        POP   BX
        RET
_JSL_127O:
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
        JZ   _JSL_129
        JS   _JSL_128
        MOV   AX, 1
        JMP   _JSL_129
_JSL_128:
        MOV   AX, 0FFFFh
_JSL_129:
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
_JSV_arr  DW  0
_JSA_1  DW  3   ; tableau (3 elem)
_JSA_1_E0  DW  10
_JSA_1_E1  DW  20
_JSA_1_E2  DW  30
_JSV_v  DW  0
_JSV_idx  DW  0
_JSV_r  DW  0
_JSA_22  DW  3   ; tableau (3 elem)
_JSA_22_E0  DW  1
_JSA_22_E1  DW  2
_JSA_22_E2  DW  3
_JSV_s  DW  0
_JSA_27  DW  3   ; tableau (3 elem)
_JSA_27_E0  DW  30
_JSA_27_E1  DW  10
_JSA_27_E2  DW  20
_JSV_a2  DW  0
_JSA_34  DW  3   ; tableau (3 elem)
_JSA_34_E0  DW  0
_JSA_34_E1  DW  0
_JSA_34_E2  DW  0
_DATA   ENDS

        END
