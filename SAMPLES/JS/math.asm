; Genere par JS86 v1.0 - SAMPLES\JS\math.js

        .MODEL SMALL
        .STACK 1024

_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME  CS:_TEXT, DS:_DATA, SS:STACK

_JSF_main:
; --- initialisation segment de donnees ---
        MOV   AX, _DATA
        MOV   DS, AX

; --- debut du code genere ---

        JMP   _JSL_2
_JSF_factorial:
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        PUSH   DI
        INC   WORD PTR [_JS_CALLDEPTH]
        MOV   AX, [BP+4]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JG   _JSL_4
        INC    AX
_JSL_4:
        OR   AX, AX
        JZ   _JSL_5
        MOV   AX, 1
        JMP   _JSL_1
_JSL_5:
_JSL_3:
        MOV   AX, [BP+4]
        PUSH   AX
        MOV   AX, [BP+4]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        SUB   AX, BX
        PUSH   AX
        CALL   _JSF_factorial
        ADD   SP, 2
        MOV   BX, AX
        POP   AX
        IMUL   BX
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
        MOV   AX, 5
        PUSH   AX
        CALL   _JSF_factorial
        ADD   SP, 2
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
        JMP   _JSL_9
_JSF_fib:
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        PUSH   DI
        INC   WORD PTR [_JS_CALLDEPTH]
        MOV   AX, [BP+4]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JG   _JSL_11
        INC    AX
_JSL_11:
        OR   AX, AX
        JZ   _JSL_12
        MOV   AX, [BP+4]
        JMP   _JSL_8
_JSL_12:
_JSL_10:
        MOV   AX, [BP+4]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        SUB   AX, BX
        PUSH   AX
        CALL   _JSF_fib
        ADD   SP, 2
        PUSH   AX
        MOV   AX, [BP+4]
        PUSH   AX
        MOV   AX, 2
        MOV   BX, AX
        POP   AX
        SUB   AX, BX
        PUSH   AX
        CALL   _JSF_fib
        ADD   SP, 2
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        JMP   _JSL_8
        XOR   AX, AX
_JSL_8:
        DEC   WORD PTR [_JS_CALLDEPTH]
        MOV   SI, [BP-2]
        MOV   DI, [BP-4]
        MOV   SP, BP
        POP   BP
        RET
_JSL_9:
        MOV   AX, 10
        PUSH   AX
        CALL   _JSF_fib
        ADD   SP, 2
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
        MOV   AX, -42
        CALL   _JSRT_ABS
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
        MOV   AX, 2
        PUSH   AX
        MOV   AX, 8
        MOV   BX, AX
        POP   AX
        CALL   _JSRT_POW
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
        MOV   AX, 144
        CALL   _JSRT_SQRT
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
        MOV   AX, 10
        PUSH   AX
        MOV   AX, 20
        POP   BX
        CMP   BX, AX
        JLE   _JSL_21
        MOV   AX, BX
_JSL_21:
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_22:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_23
        INC    CX
        INC    DI
        JMP   _JSL_22
_JSL_23:
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
        PUSH   AX
        MOV   AX, 20
        POP   BX
        CMP   BX, AX
        JGE   _JSL_24
        MOV   AX, BX
_JSL_24:
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
        MOV   AX, -99
        CALL   _JSRT_SIGN
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
        JMP   _JSL_30
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
        JMP   _JSL_29
        XOR   AX, AX
_JSL_29:
        DEC   WORD PTR [_JS_CALLDEPTH]
        MOV   SI, [BP-2]
        MOV   DI, [BP-4]
        MOV   SP, BP
        POP   BP
        RET
_JSL_30:
        MOV   AX, 100
        PUSH   AX
        MOV   AX, 200
        PUSH   AX
        CALL   _JSF_add
        ADD   SP, 4
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

; --- sortie programme ---
        MOV   AX, 4C00h
        INT    21h

; --- runtime core routines (TODO 24) ---
_JSRT_NUMTOSTR:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        PUSH   DI
        PUSH   SI
        LEA   DI, _JSRT_NUMBUF
        ADD   DI, 11
        MOV   BYTE PTR [DI], 0
        DEC   DI
        XOR   CX, CX
        MOV   BX, AX
        OR   AX, AX
        JNS   _JSL_33
        NEG    AX
_JSL_33:
        MOV   SI, 10
_JSL_34:
        XOR   DX, DX
        DIV    SI
        ADD   DL, '0'
        MOV   [DI], DL
        DEC   DI
        INC   CX
        OR   AX, AX
        JNZ   _JSL_34
        OR   BX, BX
        JNS   _JSL_35
        MOV   BYTE PTR [DI], '-'
        DEC   DI
_JSL_35:
        INC   DI
        MOV   AX, DI
        POP   SI
        POP   DI
        POP   DX
        POP   CX
        POP   BX
        RET
_JSRT_CONCAT:
        PUSH   SI
        PUSH   DI
        PUSH   CX
        LEA   DI, _JSRT_STRBUF
        MOV   SI, AX
_JSL_36:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_37
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_36
_JSL_37:
        MOV   SI, BX
_JSL_39:
        MOV   AL, [SI]
        MOV   [DI], AL
        OR   AL, AL
        JZ   _JSL_38
        INC   SI
        INC   DI
        JMP   _JSL_39
_JSL_38:
        LEA   AX, _JSRT_STRBUF
        POP   CX
        POP   DI
        POP   SI
        RET
_JSRT_PRINT:
        MOV   AH, 40h
        INT    21h
        RET
_JSRT_PRINTLN:
        MOV   AH, 40h
        INT    21h
        PUSH   CX
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   AH, 40h
        INT    21h
        POP   CX
        RET
_JSRT_TYPEOF:
        CMP   BX, 1
        JE   _JSL_40
        CMP   BX, 2
        JE   _JSL_41
        CMP   BX, 3
        JE   _JSL_42
        CMP   BX, 7
        JE   _JSL_43
        LEA   AX, _JS_TYP_NUMBER
        RET
_JSL_40:
        LEA   AX, _JS_TYP_STRING
        RET
_JSL_41:
        LEA   AX, _JS_TYP_BOOLEAN
        RET
_JSL_42:
        LEA   AX, _JS_TYP_OBJECT
        RET
_JSL_43:
        LEA   AX, _JS_UNDEF
        RET
_JSRT_TRUTHY:
        CMP   BX, 7
        JE   _JSL_46
        CMP   BX, 6
        JE   _JSL_46
        CMP   BX, 1
        JE   _JSL_44
        OR   AX, AX
        JZ   _JSL_46
        JMP   _JSL_45
_JSL_44:
        MOV   SI, AX
        CMP   BYTE PTR [SI], 0
        JE   _JSL_46
_JSL_45:
        MOV   AX, 1
        RET
_JSL_46:
        XOR   AX, AX
        RET
_JSRT_STRTRUTHY:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_48
        CMP   BYTE PTR [SI], '0'
        JNE   _JSL_47
        CMP   BYTE PTR [SI+1], 0
        JE   _JSL_48
_JSL_47:
        MOV   AX, 1
        RET
_JSL_48:
        XOR   AX, AX
        RET
_JSRT_ALLOC:
        PUSH   BX
        MOV   BX, [_JS_HEAPTOP]
        LEA   AX, _JS_HEAP
        ADD   AX, BX
        ADD   BX, CX
        MOV   [_JS_HEAPTOP], BX
        POP   BX
        RET

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
        JZ   _JSL_49
        DEC   BX
        MOV   [SI], BX
        MOV   DI, BX
        SHL   DI, 1
        ADD   DI, 2
        ADD   DI, SI
        MOV   AX, [DI]
        RET
_JSL_49:
        XOR   AX, AX
        RET
_JSRT_ARRSHIFT:
        MOV   CX, [SI]
        OR   CX, CX
        JZ   _JSL_50
        MOV   AX, [SI+2]
        PUSH   AX
        DEC   CX
        MOV   [SI], CX
        LEA   DI, [SI+2]
        LEA   BX, [SI+4]
_JSL_51:
        OR   CX, CX
        JZ   _JSL_52
        MOV   AX, [BX]
        MOV   [DI], AX
        ADD   DI, 2
        ADD   BX, 2
        DEC   CX
        JMP   _JSL_51
_JSL_52:
        POP   AX
        RET
_JSL_50:
        XOR   AX, AX
        RET
_JSRT_ARRUNSHIFT:
        PUSH   AX
        MOV   CX, [SI]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        ADD   DI, 2
_JSL_53:
        OR   CX, CX
        JZ   _JSL_54
        MOV   AX, [DI-2]
        MOV   [DI], AX
        SUB   DI, 2
        DEC   CX
        JMP   _JSL_53
_JSL_54:
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
_JSL_55:
        OR   CX, CX
        JZ   _JSL_56
        CMP   [SI], BX
        JE   _JSL_57
        ADD   SI, 2
        INC   DX
        DEC   CX
        JMP   _JSL_55
_JSL_57:
        MOV   AX, DX
        RET
_JSL_56:
        MOV   AX, -1
        RET
_JSRT_ARRREV:
        MOV   CX, [SI]
        CMP   CX, 2
        JL   _JSL_58
        LEA   BX, [SI+2]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        SUB   DI, 2
_JSL_59:
        CMP   BX, DI
        JGE   _JSL_60
        MOV   AX, [BX]
        MOV   DX, [DI]
        MOV   [BX], DX
        MOV   [DI], AX
        ADD   BX, 2
        SUB   DI, 2
        JMP   _JSL_59
_JSL_60:
_JSL_58:
        MOV   AX, SI
        RET
_JSRT_ARRSORT:
        PUSH   SI
_JSL_61:
        XOR   DX, DX
        MOV   CX, [SI]
        DEC   CX
        CMP   CX, 0
        JLE   _JSL_64
        LEA   BX, [SI+2]
_JSL_62:
        MOV   AX, [BX]
        CMP   AX, [BX+2]
        JLE   _JSL_63
        MOV   DI, [BX+2]
        MOV   [BX], DI
        MOV   [BX+2], AX
        MOV   DX, 1
_JSL_63:
        ADD   BX, 2
        DEC   CX
        OR   CX, CX
        JNZ   _JSL_62
        OR   DX, DX
        JNZ   _JSL_61
_JSL_64:
        POP   AX
        RET

; --- runtime object routines (TODO 16) ---
_JSRT_STRCMP:
        PUSH   SI
        PUSH   DI
_JSL_65:
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_67
        OR   AL, AL
        JZ   _JSL_66
        INC   SI
        INC   DI
        JMP   _JSL_65
_JSL_66:
        XOR   AX, AX
        POP   DI
        POP   SI
        RET
_JSL_67:
        MOV   AX, 1
        POP   DI
        POP   SI
        RET
_JSRT_OBJGET:
        PUSH   CX
        PUSH   BX
        MOV   CX, [BX]
        ADD   BX, 2
_JSL_68:
        OR   CX, CX
        JZ   _JSL_70
        PUSH   CX
        PUSH   BX
        PUSH   DI
        MOV   SI, [BX]
        CALL   _JSRT_STRCMP
        POP   DI
        POP   BX
        POP   CX
        OR   AX, AX
        JZ   _JSL_69
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_68
_JSL_69:
        MOV   AX, [BX+2]
        POP   BX
        POP   CX
        RET
_JSL_70:
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
_JSL_71:
        OR   CX, CX
        JZ   _JSL_73
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
        JZ   _JSL_72
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_71
_JSL_72:
        MOV   [BX+2], DX
        MOV   AX, DX
        POP   BX
        POP   CX
        RET
_JSL_73:
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
_JSL_74:
        OR   CX, CX
        JZ   _JSL_75
        MOV   AX, [SI]
        MOV   [DI], AX
        ADD   SI, 4
        ADD   DI, 2
        DEC   CX
        JMP   _JSL_74
_JSL_75:
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
_JSL_76:
        OR   CX, CX
        JZ   _JSL_77
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
        JMP   _JSL_76
_JSL_77:
        POP   BX
        MOV   AX, BX
        POP   DI
        POP   CX
        RET

; --- runtime regexp routines (TODO 19) ---
_JSRT_REPARSE:
        PUSH   BX
        MOV   BX, DI
_JSL_78:
        MOV   AL, [BX]
        CMP   AL, 1
        JZ   _JSL_79
        OR   AL, AL
        JZ   _JSL_79
        INC   BX
        JMP   _JSL_78
_JSL_79:
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
        JZ   _JSL_82
_JSL_80:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_83
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   DX, CX
_JSL_81:
        OR   DX, DX
        JZ   _JSL_82B
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_83B
        INC   SI
        INC   DI
        DEC   DX
        JMP   _JSL_81
_JSL_82B:
        POP   CX
        POP   DI
        POP   SI
        JMP   _JSL_82
_JSL_83B:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_80
_JSL_82:
        MOV   AX, 1
        POP   DX
        POP   CX
        POP   BX
        POP   DI
        POP   SI
        RET
_JSL_83:
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
        JZ   _JSL_86
_JSL_84:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_87
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   DX, CX
_JSL_85:
        OR   DX, DX
        JZ   _JSL_86B
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_87B
        INC   SI
        INC   DI
        DEC   DX
        JMP   _JSL_85
_JSL_86B:
        POP   CX
        POP   DI
        POP   SI
        JMP   _JSL_86
_JSL_87B:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_84
_JSL_86:
        MOV   AX, SI
        SUB   AX, BX
        POP   DX
        POP   CX
        POP   BX
        POP   DI
        POP   SI
        RET
_JSL_87:
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
        JZ   _JSL_88
        MOV   AX, SI
        RET
_JSL_88:
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
_JSL_89:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_92
        OR   DX, DX
        JZ   _JSL_90C
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   CX, DX
_JSL_90:
        OR   CX, CX
        JZ   _JSL_91
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_90N
        INC   SI
        INC   DI
        DEC   CX
        JMP   _JSL_90
_JSL_90N:
        POP   CX
        POP   DI
        POP   SI
_JSL_90C:
        MOV   AL, [SI]
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_89
_JSL_91:
        POP   CX
        POP   DI
        POP   AX
        PUSH   SI
        MOV   SI, [SP+10]
_JSL_93:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_93D
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_93
_JSL_93D:
        POP   SI
_JSL_94:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_92
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_94
_JSL_92:
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
_JSL_95:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_96
        INC   AX
        INC   SI
        JMP   _JSL_95
_JSL_96:
        POP   SI
        RET
_JSRT_STRINDEXOF:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        MOV   BX, SI
_JSL_97:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_100
        PUSH   SI
        PUSH   DI
_JSL_98:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_99
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_98N
        INC   SI
        INC   DI
        JMP   _JSL_98
_JSL_99:
        POP   DI
        POP   AX
        SUB   AX, BX
        POP   DX
        POP   CX
        POP   BX
        RET
_JSL_98N:
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_97
_JSL_100:
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
_JSL_101:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_104
        PUSH   SI
        PUSH   DI
_JSL_102:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_103
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_102N
        INC   SI
        INC   DI
        JMP   _JSL_102
_JSL_103:
        POP   DI
        POP   AX
        SUB   AX, BX
        MOV   DX, AX
        ADD   AX, BX
        MOV   SI, AX
        INC   SI
        JMP   _JSL_101
_JSL_102N:
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_101
_JSL_104:
        MOV   AX, DX
        POP   DX
        POP   CX
        POP   BX
        RET
_JSRT_STRSTARTW:
_JSL_105:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_105Y
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_106
        INC   SI
        INC   DI
        JMP   _JSL_105
_JSL_105Y:
        MOV   AX, 1
        RET
_JSL_106:
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
        JA   _JSL_107
        SUB   BX, CX
        ADD   SI, BX
        POP   CX
        POP   BX
        JMP   _JSRT_STRSTARTW
_JSL_107:
        XOR   AX, AX
        POP   CX
        POP   BX
        RET
_JSRT_STRSLICE:
        PUSH   DI
        PUSH   DX
        LEA   DI, _JSRT_STRBUF
        MOV   DX, BX
_JSL_108:
        OR   DX, DX
        JZ   _JSL_109
        CMP   BYTE PTR [SI], 0
        JE   _JSL_110
        INC   SI
        DEC   DX
        JMP   _JSL_108
_JSL_109:
        CMP   BX, CX
        JGE   _JSL_110
        CMP   BYTE PTR [SI], 0
        JE   _JSL_110
        MOV   AL, [SI]
        MOV   [DI], AL
        INC   SI
        INC   DI
        INC   BX
        JMP   _JSL_109
_JSL_110:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DX
        POP   DI
        RET
_JSRT_STRTOUPPER:
        PUSH   DI
        LEA   DI, _JSRT_STRBUF
_JSL_111:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_112
        CMP   AL, 'a'
        JB   _JSL_111C
        CMP   AL, 'z'
        JA   _JSL_111C
        SUB   AL, 32
_JSL_111C:
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_111
_JSL_112:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DI
        RET
_JSRT_STRTOLOWER:
        PUSH   DI
        LEA   DI, _JSRT_STRBUF
_JSL_113:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_114
        CMP   AL, 'A'
        JB   _JSL_113C
        CMP   AL, 'Z'
        JA   _JSL_113C
        ADD   AL, 32
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
_JSRT_STRTRIM:
        PUSH   DI
        PUSH   BX
_JSL_115:
        MOV   AL, [SI]
        CMP   AL, 32
        JE   _JSL_115S
        CMP   AL, 9
        JE   _JSL_115S
        JMP   _JSL_116
_JSL_115S:
        INC   SI
        JMP   _JSL_115
_JSL_116:
        LEA   DI, _JSRT_STRBUF
        MOV   BX, DI
_JSL_118:
        MOV   AL, [SI]
        MOV   [DI], AL
        OR   AL, AL
        JZ   _JSL_117
        INC   SI
        INC   DI
        JMP   _JSL_118
_JSL_117:
_JSL_119:
        DEC   DI
        CMP   DI, BX
        JB   _JSL_119D
        CMP   BYTE PTR [DI], 32
        JE   _JSL_119
        CMP   BYTE PTR [DI], 9
        JE   _JSL_119
_JSL_119D:
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
_JSL_120:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_123
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   CX, DX
_JSL_121:
        OR   CX, CX
        JZ   _JSL_122
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_121N
        INC   SI
        INC   DI
        DEC   CX
        JMP   _JSL_121
_JSL_121N:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_120
_JSL_122:
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
        JMP   _JSL_120
_JSL_123:
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
_JSL_124:
        OR   CX, CX
        JZ   _JSL_126
        MOV   SI, DX
_JSL_125:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_125D
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_125
_JSL_125D:
        DEC   CX
        JMP   _JSL_124
_JSL_126:
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
        JAE   _JSL_129
        SUB   CX, DX
        LEA   BX, _JSRT_STRBUF
        PUSH   SI
        MOV   SI, DI
_JSL_127:
        OR   CX, CX
        JZ   _JSL_128
        MOV   AL, [SI]
        OR   AL, AL
        JNZ   _JSL_127C
        MOV   SI, DI
        MOV   AL, [SI]
_JSL_127C:
        MOV   [BX], AL
        INC   BX
        INC   SI
        DEC   CX
        JMP   _JSL_127
_JSL_128:
        POP   SI
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
_JSL_129:
        LEA   BX, _JSRT_STRBUF
_JSL_131:
        MOV   AL, [SI]
        MOV   [BX], AL
        OR   AL, AL
        JZ   _JSL_131D
        INC   SI
        INC   BX
        JMP   _JSL_131
_JSL_131D:
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
_JSL_132:
        CMP   BYTE PTR [SI], 32
        JE   _JSL_132S
        JMP   _JSL_132E
_JSL_132S:
        INC   SI
        JMP   _JSL_132
_JSL_132E:
        CMP   BYTE PTR [SI], '-'
        JNE   _JSL_132P
        MOV   BX, 1
        INC   SI
        JMP   _JSL_133
_JSL_132P:
        CMP   BYTE PTR [SI], '+'
        JNE   _JSL_133
        INC   SI
_JSL_133:
        XOR   DX, DX
        MOV   DL, [SI]
        OR   DL, DL
        JZ   _JSL_134
        CMP   DL, '0'
        JB   _JSL_134
        CMP   DL, '9'
        JA   _JSL_133H
        SUB   DL, '0'
        JMP   _JSL_133M
_JSL_133H:
        CMP   DL, 'a'
        JB   _JSL_133U
        CMP   DL, 'f'
        JA   _JSL_134
        SUB   DL, 'a'
        ADD   DL, 10
        JMP   _JSL_133M
_JSL_133U:
        CMP   DL, 'A'
        JB   _JSL_134
        CMP   DL, 'F'
        JA   _JSL_134
        SUB   DL, 'A'
        ADD   DL, 10
_JSL_133M:
        CMP   DL, CL
        JAE   _JSL_134
        PUSH   DX
        PUSH   CX
        MUL    CX
        POP   CX
        POP   DX
        ADD   AX, DX
        INC   SI
        JMP   _JSL_133
_JSL_134:
        OR   BX, BX
        JZ   _JSL_134D
        NEG    AX
_JSL_134D:
        POP   DX
        POP   BX
        RET
_JSRT_ABS:
        OR   AX, AX
        JNS   _JSL_135
        NEG    AX
_JSL_135:
        RET
_JSRT_POW:
        PUSH   CX
        PUSH   DX
        MOV   CX, BX
        MOV   BX, AX
        MOV   AX, 1
_JSL_136:
        OR   CX, CX
        JZ   _JSL_137
        PUSH   DX
        MUL    BX
        POP   DX
        DEC   CX
        JMP   _JSL_136
_JSL_137:
        POP   DX
        POP   CX
        RET
_JSRT_SQRT:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        OR   AX, AX
        JZ   _JSL_139
        MOV   BX, AX
        SHR   AX, 1
        OR   AX, AX
        JZ   _JSL_139O
_JSL_138:
        MOV   CX, AX
        PUSH   BX
        XOR   DX, DX
        MOV   AX, BX
        DIV    CX
        POP   BX
        ADD   AX, CX
        SHR   AX, 1
        CMP   AX, CX
        JB   _JSL_138
        MOV   AX, CX
_JSL_139:
        POP   DX
        POP   CX
        POP   BX
        RET
_JSL_139O:
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
        JZ   _JSL_141
        JS   _JSL_140
        MOV   AX, 1
        JMP   _JSL_141
_JSL_140:
        MOV   AX, 0FFFFh
_JSL_141:
        RET
_JSRT_JSONSTR:
        PUSH   DI
        LEA   DI, _JSRT_JSONBUF
        CALL   _JSRT_NUMTOSTR
        LEA   AX, _JSRT_JSONBUF
        POP   DI
        RET

; --- runtime class routines (TODO 21) ---
_JSRT_NEW:
        PUSH   BX
        MOV   BX, [_JSRT_HEAPTOP]
        LEA   AX, _JSRT_OBJHEAP
        ADD   AX, BX
        PUSH   AX
        MOV   WORD PTR [AX], 0
        MOV   WORD PTR [AX+2], 0
        ADD   BX, 68
        MOV   [_JSRT_HEAPTOP], BX
        POP   AX
        POP   BX
        RET
_JSRT_OBJCREATE:
        PUSH   DX
        MOV   DX, BX
        PUSH   BX
        MOV   BX, [_JSRT_HEAPTOP]
        LEA   AX, _JSRT_OBJHEAP
        ADD   AX, BX
        MOV   [AX], DX
        MOV   WORD PTR [AX+2], 0
        ADD   AX, 2
        PUSH   AX
        ADD   BX, 68
        MOV   [_JSRT_HEAPTOP], BX
        POP   AX
        POP   BX
        POP   DX
        RET

; --- runtime exception routines (TODO 23) ---
_JSRT_MKERROR:
        MOV   AX, SI
        RET
_JSRT_THROW:
        MOV   [_JSX_ERRPTR], AX
        CMP   WORD PTR [_JSX_HANDLER], 0
        JZ   _JSL_142
        MOV   SP, [_JSX_SAVESP]
        MOV   BP, [_JSX_SAVEBP]
        MOV   BX, [_JSX_HANDLER]
        JMP   BX
_JSL_142:
        PUSH   AX
        LEA   DX, _JS_ERR_UNCAUGHT
        MOV   DI, DX
        XOR   CX, CX
_JSL_143:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_144
        INC   CX
        INC   DI
        JMP   _JSL_143
_JSL_144:
        SUB   DI, CX
        MOV   DX, DI
        MOV   BX, 2
        MOV   AH, 40h
        INT    21h
        POP   AX
        MOV   DI, AX
        XOR   CX, CX
_JSL_145:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_146
        INC   CX
        INC   DI
        JMP   _JSL_145
_JSL_146:
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
        MOV   AX, 4C01h
        INT    21h
_JSRT_PANIC:
        MOV   AX, SI
        CALL   _JSRT_THROW
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
_JSRT_OBJHEAP DB 4096 DUP(0)
_JSRT_HEAPTOP DW 0
_JSRT_OBJTMP  DW 0
_JSX_HANDLER  DW  0
_JSX_SAVESP   DW  0
_JSX_SAVEBP   DW  0
_JSX_ERRPTR   DW  0
_JS_ERR_DIV0  DB  'Division by zero',0
_JS_ERR_UNCAUGHT DB 'Uncaught: ',0
_JSRT_ERRBUF  DB  64 DUP(0)
_JSRT_NUMBUF  DB  12 DUP(0)
_JS_TYP_NUMBER  DB 'number',0
_JS_TYP_STRING  DB 'string',0
_JS_TYP_BOOLEAN DB 'boolean',0
_JS_TYP_OBJECT  DB 'object',0
_JS_TYP_FUNCTION DB 'function',0
_JS_HEAP      DB 4096 DUP(0)
_JS_HEAPTOP   DW 0
_DATA   ENDS

        END   _JSF_main
