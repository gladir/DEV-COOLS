; Genere par JS86 v1.0 - SAMPLES\JS\test12.js

        .MODEL SMALL
        .STACK 1024

_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME  CS:_TEXT, DS:_DATA, SS:STACK

; --- debut du code genere ---

        MOV   AX, 42
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_1:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_2
        INC    CX
        INC    DI
        JMP   _JSL_1
_JSL_2:
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
        LEA   AX, _JSK_3
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
        MOV   AX, 10
        MOV   [_JSV_x], AX
        LEA   AX, _JSK_6
        MOV   [_JSV_s], AX
        MOV   AX, [_JSV_x]
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
        LEA   DX, _JS_SPACE
        MOV   CX, 1
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        MOV   AX, [_JSV_s]
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
        LEA   DX, _JS_SPACE
        MOV   CX, 1
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        MOV   AX, 99
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
        MOV   AX, 5
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
        LEA   AX, _JSK_15
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
        MOV   BX, 2
        MOV   AH, 40h
        INT    21h
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 2
        MOV   AH, 40h
        INT    21h
        LEA   DI, _JS_WARNPFX
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
        LEA   DX, _JS_WARNPFX
        MOV   BX, 2
        MOV   AH, 40h
        INT    21h
        LEA   AX, _JSK_20
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
        MOV   BX, 2
        MOV   AH, 40h
        INT    21h
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 2
        MOV   AH, 40h
        INT    21h
        LEA   AX, _JSK_23
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
        LEA   AX, _JSK_26
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
        PUSH   AX
        XOR   AX, AX
        MOV   [_JSV_p], AX
        MOV   AX, 1
        MOV   [_JSV_b], AX
        MOV   AX, [_JSV_b]
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
        MOV   AX, 0
        OR   AX, AX
        JNZ   _JSL_36
        LEA   DI, _JS_FALSE
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
        LEA   DX, _JS_FALSE
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        JMP   _JSL_37
_JSL_36:
        LEA   DI, _JS_TRUE
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
        LEA   DX, _JS_TRUE
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
_JSL_37:
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        XOR   AX, AX
        MOV   AX, 0
        LEA   DI, _JS_NULL
        XOR   CX, CX
_JSL_42:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_43
        INC    CX
        INC    DI
        JMP   _JSL_42
_JSL_43:
        SUB   DI, CX
        LEA   DX, _JS_NULL
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        XOR   AX, AX
        MOV   AX, 0
        LEA   DI, _JS_UNDEF
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
        LEA   DX, _JS_UNDEF
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        MOV   AX, 123
        MOV   [_JSV_n], AX
        MOV   AX, [_JSV_n]
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_46:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_47
        INC    CX
        INC    DI
        JMP   _JSL_46
_JSL_47:
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
        JZ   _JSL_48
        DEC   BX
        MOV   [SI], BX
        MOV   DI, BX
        SHL   DI, 1
        ADD   DI, 2
        ADD   DI, SI
        MOV   AX, [DI]
        RET
_JSL_48:
        XOR   AX, AX
        RET
_JSRT_ARRSHIFT:
        MOV   CX, [SI]
        OR   CX, CX
        JZ   _JSL_49
        MOV   AX, [SI+2]
        PUSH   AX
        DEC   CX
        MOV   [SI], CX
        LEA   DI, [SI+2]
        LEA   BX, [SI+4]
_JSL_50:
        OR   CX, CX
        JZ   _JSL_51
        MOV   AX, [BX]
        MOV   [DI], AX
        ADD   DI, 2
        ADD   BX, 2
        DEC   CX
        JMP   _JSL_50
_JSL_51:
        POP   AX
        RET
_JSL_49:
        XOR   AX, AX
        RET
_JSRT_ARRUNSHIFT:
        PUSH   AX
        MOV   CX, [SI]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        ADD   DI, 2
_JSL_52:
        OR   CX, CX
        JZ   _JSL_53
        MOV   AX, [DI-2]
        MOV   [DI], AX
        SUB   DI, 2
        DEC   CX
        JMP   _JSL_52
_JSL_53:
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
_JSL_54:
        OR   CX, CX
        JZ   _JSL_55
        CMP   [SI], BX
        JE   _JSL_56
        ADD   SI, 2
        INC   DX
        DEC   CX
        JMP   _JSL_54
_JSL_56:
        MOV   AX, DX
        RET
_JSL_55:
        MOV   AX, -1
        RET
_JSRT_ARRREV:
        MOV   CX, [SI]
        CMP   CX, 2
        JL   _JSL_57
        LEA   BX, [SI+2]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        SUB   DI, 2
_JSL_58:
        CMP   BX, DI
        JGE   _JSL_59
        MOV   AX, [BX]
        MOV   DX, [DI]
        MOV   [BX], DX
        MOV   [DI], AX
        ADD   BX, 2
        SUB   DI, 2
        JMP   _JSL_58
_JSL_59:
_JSL_57:
        MOV   AX, SI
        RET
_JSRT_ARRSORT:
        PUSH   SI
_JSL_60:
        XOR   DX, DX
        MOV   CX, [SI]
        DEC   CX
        CMP   CX, 0
        JLE   _JSL_63
        LEA   BX, [SI+2]
_JSL_61:
        MOV   AX, [BX]
        CMP   AX, [BX+2]
        JLE   _JSL_62
        MOV   DI, [BX+2]
        MOV   [BX], DI
        MOV   [BX+2], AX
        MOV   DX, 1
_JSL_62:
        ADD   BX, 2
        DEC   CX
        OR   CX, CX
        JNZ   _JSL_61
        OR   DX, DX
        JNZ   _JSL_60
_JSL_63:
        POP   AX
        RET

; --- runtime object routines (TODO 16) ---
_JSRT_STRCMP:
        PUSH   SI
        PUSH   DI
_JSL_64:
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_66
        OR   AL, AL
        JZ   _JSL_65
        INC   SI
        INC   DI
        JMP   _JSL_64
_JSL_65:
        XOR   AX, AX
        POP   DI
        POP   SI
        RET
_JSL_66:
        MOV   AX, 1
        POP   DI
        POP   SI
        RET
_JSRT_OBJGET:
        PUSH   CX
        PUSH   BX
        MOV   CX, [BX]
        ADD   BX, 2
_JSL_67:
        OR   CX, CX
        JZ   _JSL_69
        PUSH   CX
        PUSH   BX
        PUSH   DI
        MOV   SI, [BX]
        CALL   _JSRT_STRCMP
        POP   DI
        POP   BX
        POP   CX
        OR   AX, AX
        JZ   _JSL_68
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_67
_JSL_68:
        MOV   AX, [BX+2]
        POP   BX
        POP   CX
        RET
_JSL_69:
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
_JSL_70:
        OR   CX, CX
        JZ   _JSL_72
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
        JZ   _JSL_71
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_70
_JSL_71:
        MOV   [BX+2], DX
        MOV   AX, DX
        POP   BX
        POP   CX
        RET
_JSL_72:
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
_JSL_73:
        OR   CX, CX
        JZ   _JSL_74
        MOV   AX, [SI]
        MOV   [DI], AX
        ADD   SI, 4
        ADD   DI, 2
        DEC   CX
        JMP   _JSL_73
_JSL_74:
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
_JSL_75:
        OR   CX, CX
        JZ   _JSL_76
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
        JMP   _JSL_75
_JSL_76:
        POP   BX
        MOV   AX, BX
        POP   DI
        POP   CX
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
_JSK_3  DB  'hello world',0
_JSV_x  DW  0
_JSV_s  DW  0
_JSK_6  DB  'test',0
_JSK_15  DB  'erreur ici',0
_JSK_20  DB  'attention',0
_JSK_23  DB  'no newline',0
_JSK_26  DB  'alerte!',0
_JSV_p  DW  0
_JSK_29  DB  'question?',0
_JSV_b  DW  0
_JSV_n  DW  0
_DATA   ENDS

        END
