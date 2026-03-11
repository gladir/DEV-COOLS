; Genere par JS86 v1.0 - SAMPLES\JS\test17.js

        .MODEL SMALL
        .STACK 1024

_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME  CS:_TEXT, DS:_DATA, SS:STACK

; --- debut du code genere ---

        JMP   _JSL_2
_JSF_add:
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        PUSH   DI
        INC   WORD PTR [_JS_CALLDEPTH]
        MOV   AX, [BP+6]
        PUSH   AX
        MOV   AX, [BP+4]
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        JMP   _JSL_1
        XOR   AX, AX
_JSL_1:
        DEC   WORD PTR [_JS_CALLDEPTH]
        MOV   SI, [BP-2]
        MOV   DI, [BP-4]
        MOV   SP, BP
        POP   BP
        RET
_JSL_2:
        MOV   AX, 3
        PUSH   AX
        MOV   AX, 4
        PUSH   AX
        CALL   _JSF_add
        ADD   SP, 4
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
        JMP   _JSL_6
_JSF_nothing:
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        PUSH   DI
        INC   WORD PTR [_JS_CALLDEPTH]
        XOR   AX, AX
        JMP   _JSL_5
        XOR   AX, AX
_JSL_5:
        DEC   WORD PTR [_JS_CALLDEPTH]
        MOV   SI, [BP-2]
        MOV   DI, [BP-4]
        MOV   SP, BP
        POP   BP
        RET
_JSL_6:
        CALL   _JSF_nothing
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
        JMP   _JSL_10
_JSF_empty:
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        PUSH   DI
        INC   WORD PTR [_JS_CALLDEPTH]
        XOR   AX, AX
_JSL_9:
        DEC   WORD PTR [_JS_CALLDEPTH]
        MOV   SI, [BP-2]
        MOV   DI, [BP-4]
        MOV   SP, BP
        POP   BP
        RET
_JSL_10:
        CALL   _JSF_empty
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
        JMP   _JSL_14
_JSF_square:
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        PUSH   DI
        INC   WORD PTR [_JS_CALLDEPTH]
        SUB   SP, 2
        MOV   AX, [BP+4]
        PUSH   AX
        MOV   AX, [BP+4]
        MOV   BX, AX
        POP   AX
        IMUL   BX
        MOV   [BP-6], AX
        MOV   AX, [BP-6]
        JMP   _JSL_13
        XOR   AX, AX
_JSL_13:
        DEC   WORD PTR [_JS_CALLDEPTH]
        MOV   SI, [BP-2]
        MOV   DI, [BP-4]
        MOV   SP, BP
        POP   BP
        RET
_JSL_14:
        MOV   AX, 5
        PUSH   AX
        CALL   _JSF_square
        ADD   SP, 2
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
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
        MOV   DX, DI
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        JMP   _JSL_18
_JSF_ANON_17:
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        PUSH   DI
        INC   WORD PTR [_JS_CALLDEPTH]
        MOV   AX, [BP+4]
        PUSH   AX
        MOV   AX, 2
        MOV   BX, AX
        POP   AX
        IMUL   BX
        JMP   _JSL_19
        XOR   AX, AX
_JSL_19:
        DEC   WORD PTR [_JS_CALLDEPTH]
        MOV   SI, [BP-2]
        MOV   DI, [BP-4]
        MOV   SP, BP
        POP   BP
        RET
_JSL_18:
        LEA   AX, _JSF_ANON_17
        MOV   [_JSV_double], AX
        MOV   AX, 6
        PUSH   AX
        MOV   AX, [_JSV_double]
        CALL   AX
        ADD   SP, 2
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
        JMP   _JSL_23
_JSF_ANON_22:
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        PUSH   DI
        INC   WORD PTR [_JS_CALLDEPTH]
        MOV   AX, [BP+4]
        PUSH   AX
        MOV   AX, 3
        MOV   BX, AX
        POP   AX
        IMUL   BX
_JSL_24:
        DEC   WORD PTR [_JS_CALLDEPTH]
        MOV   SI, [BP-2]
        MOV   DI, [BP-4]
        MOV   SP, BP
        POP   BP
        RET
_JSL_23:
        LEA   AX, _JSF_ANON_22
        MOV   [_JSV_triple], AX
        MOV   AX, 4
        PUSH   AX
        MOV   AX, [_JSV_triple]
        CALL   AX
        ADD   SP, 2
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
        JMP   _JSL_28
_JSF_ANON_27:
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        PUSH   DI
        INC   WORD PTR [_JS_CALLDEPTH]
        MOV   AX, [BP+6]
        PUSH   AX
        MOV   AX, [BP+4]
        MOV   BX, AX
        POP   AX
        IMUL   BX
_JSL_29:
        DEC   WORD PTR [_JS_CALLDEPTH]
        MOV   SI, [BP-2]
        MOV   DI, [BP-4]
        MOV   SP, BP
        POP   BP
        RET
_JSL_28:
        LEA   AX, _JSF_ANON_27
        MOV   [_JSV_mul], AX
        MOV   AX, 3
        PUSH   AX
        MOV   AX, 5
        PUSH   AX
        MOV   AX, [_JSV_mul]
        CALL   AX
        ADD   SP, 4
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
        JMP   _JSL_33
_JSF_ANON_32:
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        PUSH   DI
        INC   WORD PTR [_JS_CALLDEPTH]
        SUB   SP, 2
        MOV   AX, [BP+4]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [BP-6], AX
        MOV   AX, [BP-6]
        JMP   _JSL_34
        XOR   AX, AX
_JSL_34:
        DEC   WORD PTR [_JS_CALLDEPTH]
        MOV   SI, [BP-2]
        MOV   DI, [BP-4]
        MOV   SP, BP
        POP   BP
        RET
_JSL_33:
        LEA   AX, _JSF_ANON_32
        MOV   [_JSV_inc], AX
        MOV   AX, 9
        PUSH   AX
        MOV   AX, [_JSV_inc]
        CALL   AX
        ADD   SP, 2
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
        JMP   _JSL_38
_JSF_apply:
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        PUSH   DI
        INC   WORD PTR [_JS_CALLDEPTH]
        MOV   AX, [BP+4]
        PUSH   AX
        MOV   AX, [BP+6]
        CALL   AX
        ADD   SP, 2
        JMP   _JSL_37
        XOR   AX, AX
_JSL_37:
        DEC   WORD PTR [_JS_CALLDEPTH]
        MOV   SI, [BP-2]
        MOV   DI, [BP-4]
        MOV   SP, BP
        POP   BP
        RET
_JSL_38:
        MOV   AX, [_JSV_double]
        PUSH   AX
        MOV   AX, 7
        PUSH   AX
        CALL   _JSF_apply
        ADD   SP, 4
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
        JMP   _JSL_42
_JSF_ANON_41:
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        PUSH   DI
        INC   WORD PTR [_JS_CALLDEPTH]
        MOV   AX, 42
_JSL_43:
        DEC   WORD PTR [_JS_CALLDEPTH]
        MOV   SI, [BP-2]
        MOV   DI, [BP-4]
        MOV   SP, BP
        POP   BP
        RET
_JSL_42:
        LEA   AX, _JSF_ANON_41
        MOV   [_JSV_getVal], AX
        MOV   AX, [_JSV_getVal]
        CALL   AX
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
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
        JZ   _JSL_46
        DEC   BX
        MOV   [SI], BX
        MOV   DI, BX
        SHL   DI, 1
        ADD   DI, 2
        ADD   DI, SI
        MOV   AX, [DI]
        RET
_JSL_46:
        XOR   AX, AX
        RET
_JSRT_ARRSHIFT:
        MOV   CX, [SI]
        OR   CX, CX
        JZ   _JSL_47
        MOV   AX, [SI+2]
        PUSH   AX
        DEC   CX
        MOV   [SI], CX
        LEA   DI, [SI+2]
        LEA   BX, [SI+4]
_JSL_48:
        OR   CX, CX
        JZ   _JSL_49
        MOV   AX, [BX]
        MOV   [DI], AX
        ADD   DI, 2
        ADD   BX, 2
        DEC   CX
        JMP   _JSL_48
_JSL_49:
        POP   AX
        RET
_JSL_47:
        XOR   AX, AX
        RET
_JSRT_ARRUNSHIFT:
        PUSH   AX
        MOV   CX, [SI]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        ADD   DI, 2
_JSL_50:
        OR   CX, CX
        JZ   _JSL_51
        MOV   AX, [DI-2]
        MOV   [DI], AX
        SUB   DI, 2
        DEC   CX
        JMP   _JSL_50
_JSL_51:
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
_JSL_52:
        OR   CX, CX
        JZ   _JSL_53
        CMP   [SI], BX
        JE   _JSL_54
        ADD   SI, 2
        INC   DX
        DEC   CX
        JMP   _JSL_52
_JSL_54:
        MOV   AX, DX
        RET
_JSL_53:
        MOV   AX, -1
        RET
_JSRT_ARRREV:
        MOV   CX, [SI]
        CMP   CX, 2
        JL   _JSL_55
        LEA   BX, [SI+2]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        SUB   DI, 2
_JSL_56:
        CMP   BX, DI
        JGE   _JSL_57
        MOV   AX, [BX]
        MOV   DX, [DI]
        MOV   [BX], DX
        MOV   [DI], AX
        ADD   BX, 2
        SUB   DI, 2
        JMP   _JSL_56
_JSL_57:
_JSL_55:
        MOV   AX, SI
        RET
_JSRT_ARRSORT:
        PUSH   SI
_JSL_58:
        XOR   DX, DX
        MOV   CX, [SI]
        DEC   CX
        CMP   CX, 0
        JLE   _JSL_61
        LEA   BX, [SI+2]
_JSL_59:
        MOV   AX, [BX]
        CMP   AX, [BX+2]
        JLE   _JSL_60
        MOV   DI, [BX+2]
        MOV   [BX], DI
        MOV   [BX+2], AX
        MOV   DX, 1
_JSL_60:
        ADD   BX, 2
        DEC   CX
        OR   CX, CX
        JNZ   _JSL_59
        OR   DX, DX
        JNZ   _JSL_58
_JSL_61:
        POP   AX
        RET

; --- runtime object routines (TODO 16) ---
_JSRT_STRCMP:
        PUSH   SI
        PUSH   DI
_JSL_62:
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_64
        OR   AL, AL
        JZ   _JSL_63
        INC   SI
        INC   DI
        JMP   _JSL_62
_JSL_63:
        XOR   AX, AX
        POP   DI
        POP   SI
        RET
_JSL_64:
        MOV   AX, 1
        POP   DI
        POP   SI
        RET
_JSRT_OBJGET:
        PUSH   CX
        PUSH   BX
        MOV   CX, [BX]
        ADD   BX, 2
_JSL_65:
        OR   CX, CX
        JZ   _JSL_67
        PUSH   CX
        PUSH   BX
        PUSH   DI
        MOV   SI, [BX]
        CALL   _JSRT_STRCMP
        POP   DI
        POP   BX
        POP   CX
        OR   AX, AX
        JZ   _JSL_66
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_65
_JSL_66:
        MOV   AX, [BX+2]
        POP   BX
        POP   CX
        RET
_JSL_67:
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
_JSL_68:
        OR   CX, CX
        JZ   _JSL_70
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
        JZ   _JSL_69
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_68
_JSL_69:
        MOV   [BX+2], DX
        MOV   AX, DX
        POP   BX
        POP   CX
        RET
_JSL_70:
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
_JSL_71:
        OR   CX, CX
        JZ   _JSL_72
        MOV   AX, [SI]
        MOV   [DI], AX
        ADD   SI, 4
        ADD   DI, 2
        DEC   CX
        JMP   _JSL_71
_JSL_72:
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
_JSL_73:
        OR   CX, CX
        JZ   _JSL_74
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
        JMP   _JSL_73
_JSL_74:
        POP   BX
        MOV   AX, BX
        POP   DI
        POP   CX
        RET

; --- runtime regexp routines (TODO 19) ---
_JSRT_REPARSE:
        PUSH   BX
        MOV   BX, DI
_JSL_75:
        MOV   AL, [BX]
        CMP   AL, 1
        JZ   _JSL_76
        OR   AL, AL
        JZ   _JSL_76
        INC   BX
        JMP   _JSL_75
_JSL_76:
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
        JZ   _JSL_79
_JSL_77:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_80
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   DX, CX
_JSL_78:
        OR   DX, DX
        JZ   _JSL_79B
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_80B
        INC   SI
        INC   DI
        DEC   DX
        JMP   _JSL_78
_JSL_79B:
        POP   CX
        POP   DI
        POP   SI
        JMP   _JSL_79
_JSL_80B:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_77
_JSL_79:
        MOV   AX, 1
        POP   DX
        POP   CX
        POP   BX
        POP   DI
        POP   SI
        RET
_JSL_80:
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
        JZ   _JSL_83
_JSL_81:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_84
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   DX, CX
_JSL_82:
        OR   DX, DX
        JZ   _JSL_83B
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_84B
        INC   SI
        INC   DI
        DEC   DX
        JMP   _JSL_82
_JSL_83B:
        POP   CX
        POP   DI
        POP   SI
        JMP   _JSL_83
_JSL_84B:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_81
_JSL_83:
        MOV   AX, SI
        SUB   AX, BX
        POP   DX
        POP   CX
        POP   BX
        POP   DI
        POP   SI
        RET
_JSL_84:
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
        JZ   _JSL_85
        MOV   AX, SI
        RET
_JSL_85:
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
_JSL_86:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_89
        OR   DX, DX
        JZ   _JSL_87C
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   CX, DX
_JSL_87:
        OR   CX, CX
        JZ   _JSL_88
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_87N
        INC   SI
        INC   DI
        DEC   CX
        JMP   _JSL_87
_JSL_87N:
        POP   CX
        POP   DI
        POP   SI
_JSL_87C:
        MOV   AL, [SI]
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_86
_JSL_88:
        POP   CX
        POP   DI
        POP   AX
        PUSH   SI
        MOV   SI, [SP+10]
_JSL_90:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_90D
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_90
_JSL_90D:
        POP   SI
_JSL_91:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_89
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_91
_JSL_89:
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
_JSL_92:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_93
        INC   AX
        INC   SI
        JMP   _JSL_92
_JSL_93:
        POP   SI
        RET
_JSRT_STRINDEXOF:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        MOV   BX, SI
_JSL_94:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_97
        PUSH   SI
        PUSH   DI
_JSL_95:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_96
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_95N
        INC   SI
        INC   DI
        JMP   _JSL_95
_JSL_96:
        POP   DI
        POP   AX
        SUB   AX, BX
        POP   DX
        POP   CX
        POP   BX
        RET
_JSL_95N:
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_94
_JSL_97:
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
_JSL_98:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_101
        PUSH   SI
        PUSH   DI
_JSL_99:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_100
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_99N
        INC   SI
        INC   DI
        JMP   _JSL_99
_JSL_100:
        POP   DI
        POP   AX
        SUB   AX, BX
        MOV   DX, AX
        ADD   AX, BX
        MOV   SI, AX
        INC   SI
        JMP   _JSL_98
_JSL_99N:
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_98
_JSL_101:
        MOV   AX, DX
        POP   DX
        POP   CX
        POP   BX
        RET
_JSRT_STRSTARTW:
_JSL_102:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_102Y
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_103
        INC   SI
        INC   DI
        JMP   _JSL_102
_JSL_102Y:
        MOV   AX, 1
        RET
_JSL_103:
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
        JA   _JSL_104
        SUB   BX, CX
        ADD   SI, BX
        POP   CX
        POP   BX
        JMP   _JSRT_STRSTARTW
_JSL_104:
        XOR   AX, AX
        POP   CX
        POP   BX
        RET
_JSRT_STRSLICE:
        PUSH   DI
        PUSH   DX
        LEA   DI, _JSRT_STRBUF
        MOV   DX, BX
_JSL_105:
        OR   DX, DX
        JZ   _JSL_106
        CMP   BYTE PTR [SI], 0
        JE   _JSL_107
        INC   SI
        DEC   DX
        JMP   _JSL_105
_JSL_106:
        CMP   BX, CX
        JGE   _JSL_107
        CMP   BYTE PTR [SI], 0
        JE   _JSL_107
        MOV   AL, [SI]
        MOV   [DI], AL
        INC   SI
        INC   DI
        INC   BX
        JMP   _JSL_106
_JSL_107:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DX
        POP   DI
        RET
_JSRT_STRTOUPPER:
        PUSH   DI
        LEA   DI, _JSRT_STRBUF
_JSL_108:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_109
        CMP   AL, 'a'
        JB   _JSL_108C
        CMP   AL, 'z'
        JA   _JSL_108C
        SUB   AL, 32
_JSL_108C:
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_108
_JSL_109:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DI
        RET
_JSRT_STRTOLOWER:
        PUSH   DI
        LEA   DI, _JSRT_STRBUF
_JSL_110:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_111
        CMP   AL, 'A'
        JB   _JSL_110C
        CMP   AL, 'Z'
        JA   _JSL_110C
        ADD   AL, 32
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
_JSRT_STRTRIM:
        PUSH   DI
        PUSH   BX
_JSL_112:
        MOV   AL, [SI]
        CMP   AL, 32
        JE   _JSL_112S
        CMP   AL, 9
        JE   _JSL_112S
        JMP   _JSL_113
_JSL_112S:
        INC   SI
        JMP   _JSL_112
_JSL_113:
        LEA   DI, _JSRT_STRBUF
        MOV   BX, DI
_JSL_115:
        MOV   AL, [SI]
        MOV   [DI], AL
        OR   AL, AL
        JZ   _JSL_114
        INC   SI
        INC   DI
        JMP   _JSL_115
_JSL_114:
_JSL_116:
        DEC   DI
        CMP   DI, BX
        JB   _JSL_116D
        CMP   BYTE PTR [DI], 32
        JE   _JSL_116
        CMP   BYTE PTR [DI], 9
        JE   _JSL_116
_JSL_116D:
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
_JSL_117:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_120
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   CX, DX
_JSL_118:
        OR   CX, CX
        JZ   _JSL_119
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_118N
        INC   SI
        INC   DI
        DEC   CX
        JMP   _JSL_118
_JSL_118N:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_117
_JSL_119:
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
        JMP   _JSL_117
_JSL_120:
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
_JSL_121:
        OR   CX, CX
        JZ   _JSL_123
        MOV   SI, DX
_JSL_122:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_122D
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_122
_JSL_122D:
        DEC   CX
        JMP   _JSL_121
_JSL_123:
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
        JAE   _JSL_126
        SUB   CX, DX
        LEA   BX, _JSRT_STRBUF
        PUSH   SI
        MOV   SI, DI
_JSL_124:
        OR   CX, CX
        JZ   _JSL_125
        MOV   AL, [SI]
        OR   AL, AL
        JNZ   _JSL_124C
        MOV   SI, DI
        MOV   AL, [SI]
_JSL_124C:
        MOV   [BX], AL
        INC   BX
        INC   SI
        DEC   CX
        JMP   _JSL_124
_JSL_125:
        POP   SI
_JSL_127:
        MOV   AL, [SI]
        MOV   [BX], AL
        OR   AL, AL
        JZ   _JSL_127D
        INC   SI
        INC   BX
        JMP   _JSL_127
_JSL_127D:
        LEA   AX, _JSRT_STRBUF
        POP   DX
        POP   BX
        RET
_JSL_126:
        LEA   BX, _JSRT_STRBUF
_JSL_128:
        MOV   AL, [SI]
        MOV   [BX], AL
        OR   AL, AL
        JZ   _JSL_128D
        INC   SI
        INC   BX
        JMP   _JSL_128
_JSL_128D:
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
_JSL_129:
        CMP   BYTE PTR [SI], 32
        JE   _JSL_129S
        JMP   _JSL_129E
_JSL_129S:
        INC   SI
        JMP   _JSL_129
_JSL_129E:
        CMP   BYTE PTR [SI], '-'
        JNE   _JSL_129P
        MOV   BX, 1
        INC   SI
        JMP   _JSL_130
_JSL_129P:
        CMP   BYTE PTR [SI], '+'
        JNE   _JSL_130
        INC   SI
_JSL_130:
        XOR   DX, DX
        MOV   DL, [SI]
        OR   DL, DL
        JZ   _JSL_131
        CMP   DL, '0'
        JB   _JSL_131
        CMP   DL, '9'
        JA   _JSL_130H
        SUB   DL, '0'
        JMP   _JSL_130M
_JSL_130H:
        CMP   DL, 'a'
        JB   _JSL_130U
        CMP   DL, 'f'
        JA   _JSL_131
        SUB   DL, 'a'
        ADD   DL, 10
        JMP   _JSL_130M
_JSL_130U:
        CMP   DL, 'A'
        JB   _JSL_131
        CMP   DL, 'F'
        JA   _JSL_131
        SUB   DL, 'A'
        ADD   DL, 10
_JSL_130M:
        CMP   DL, CL
        JAE   _JSL_131
        PUSH   DX
        PUSH   CX
        MUL    CX
        POP   CX
        POP   DX
        ADD   AX, DX
        INC   SI
        JMP   _JSL_130
_JSL_131:
        OR   BX, BX
        JZ   _JSL_131D
        NEG    AX
_JSL_131D:
        POP   DX
        POP   BX
        RET
_JSRT_ABS:
        OR   AX, AX
        JNS   _JSL_132
        NEG    AX
_JSL_132:
        RET
_JSRT_POW:
        PUSH   CX
        PUSH   DX
        MOV   CX, BX
        MOV   BX, AX
        MOV   AX, 1
_JSL_133:
        OR   CX, CX
        JZ   _JSL_134
        PUSH   DX
        MUL    BX
        POP   DX
        DEC   CX
        JMP   _JSL_133
_JSL_134:
        POP   DX
        POP   CX
        RET
_JSRT_SQRT:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        OR   AX, AX
        JZ   _JSL_136
        MOV   BX, AX
        SHR   AX, 1
        OR   AX, AX
        JZ   _JSL_136O
_JSL_135:
        MOV   CX, AX
        PUSH   BX
        XOR   DX, DX
        MOV   AX, BX
        DIV    CX
        POP   BX
        ADD   AX, CX
        SHR   AX, 1
        CMP   AX, CX
        JB   _JSL_135
        MOV   AX, CX
_JSL_136:
        POP   DX
        POP   CX
        POP   BX
        RET
_JSL_136O:
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
        JZ   _JSL_138
        JS   _JSL_137
        MOV   AX, 1
        JMP   _JSL_138
_JSL_137:
        MOV   AX, 0FFFFh
_JSL_138:
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
_JSV_double  DW  0
_JSV_triple  DW  0
_JSV_mul  DW  0
_JSV_inc  DW  0
_JSV_getVal  DW  0
_DATA   ENDS

        END
