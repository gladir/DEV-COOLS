; Genere par JS86 v1.0 - SAMPLES\JS\test16.js

        .MODEL SMALL
        .STACK 1024

_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME  CS:_TEXT, DS:_DATA, SS:STACK

; --- debut du code genere ---

        LEA   AX, _JSO_1
        MOV   [_JSV_obj], AX
        MOV   AX, [_JSV_obj]
        MOV   BX, AX
        LEA   DI, _JSK_4
        CALL   _JSRT_OBJGET
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
        MOV   AX, [_JSV_obj]
        MOV   BX, AX
        LEA   DI, _JSK_7
        CALL   _JSRT_OBJGET
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
        MOV   AX, [_JSV_obj]
        PUSH   AX
        MOV   AX, 42
        POP   BX
        LEA   DI, _JSK_10
        CALL   _JSRT_OBJSET
        MOV   AX, [_JSV_obj]
        MOV   BX, AX
        LEA   DI, _JSK_11
        CALL   _JSRT_OBJGET
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
        MOV   AX, [_JSV_obj]
        PUSH   AX
        MOV   AX, 99
        POP   BX
        LEA   DI, _JSK_14
        CALL   _JSRT_OBJSET
        MOV   AX, [_JSV_obj]
        MOV   BX, AX
        LEA   DI, _JSK_15
        CALL   _JSRT_OBJGET
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
        MOV   AX, 5
        MOV   [_JSV_a], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, 3
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [_JSO_18_V0], AX
        LEA   AX, _JSO_18
        MOV   [_JSV_b], AX
        MOV   AX, [_JSV_b]
        MOV   BX, AX
        LEA   DI, _JSK_20
        CALL   _JSRT_OBJGET
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
        MOV   AX, [_JSV_obj]
        MOV   BX, AX
        CALL   _JSRT_OBJKEYS
        MOV   [_JSV_keys], AX
        MOV   AX, [_JSV_keys]
        MOV   SI, AX
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
        LEA   AX, _JSO_25
        MOV   [_JSV_src], AX
        LEA   AX, _JSO_27
        MOV   [_JSV_dst], AX
        MOV   AX, [_JSV_dst]
        PUSH   AX
        MOV   AX, [_JSV_src]
        MOV   SI, AX
        POP   BX
        CALL   _JSRT_OBJASSIGN
        MOV   AX, [_JSV_dst]
        MOV   BX, AX
        LEA   DI, _JSK_30
        CALL   _JSRT_OBJGET
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
        LEA   AX, _JSO_33
        MOV   [_JSV_p], AX
        MOV   AX, [_JSV_p]
        MOV   BX, AX
        LEA   DI, _JSK_37
        CALL   _JSRT_OBJGET
        CALL   _JSRT_NUMTOSTR
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
        MOV   AX, [_JSV_p]
        MOV   BX, AX
        LEA   DI, _JSK_40
        CALL   _JSRT_OBJGET
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_41:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_42
        INC    CX
        INC    DI
        JMP   _JSL_41
_JSL_42:
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
        MOV   AX, [_JSV_p]
        MOV   BX, AX
        LEA   DI, _JSK_43
        CALL   _JSRT_OBJGET
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
_JSV_obj  DW  0
_JSK_2  DB  'x',0
_JSK_3  DB  'y',0
_JSO_1  DW  2   ; objet (2 props)
_JSO_1_K0  DW  OFFSET _JSK_2
_JSO_1_V0  DW  10
_JSO_1_K1  DW  OFFSET _JSK_3
_JSO_1_V1  DW  20
_JSO_1_K2  DW  0
_JSO_1_V2  DW  0
_JSO_1_K3  DW  0
_JSO_1_V3  DW  0
_JSO_1_K4  DW  0
_JSO_1_V4  DW  0
_JSO_1_K5  DW  0
_JSO_1_V5  DW  0
_JSK_4  DB  'x',0
_JSK_7  DB  'y',0
_JSK_10  DB  'x',0
_JSK_11  DB  'x',0
_JSK_14  DB  'z',0
_JSK_15  DB  'z',0
_JSV_a  DW  0
_JSV_b  DW  0
_JSK_19  DB  'val',0
_JSO_18  DW  1   ; objet (1 props)
_JSO_18_K0  DW  OFFSET _JSK_19
_JSO_18_V0  DW  0
_JSO_18_K1  DW  0
_JSO_18_V1  DW  0
_JSO_18_K2  DW  0
_JSO_18_V2  DW  0
_JSO_18_K3  DW  0
_JSO_18_V3  DW  0
_JSO_18_K4  DW  0
_JSO_18_V4  DW  0
_JSK_20  DB  'val',0
_JSV_keys  DW  0
_JSV_src  DW  0
_JSK_26  DB  'm',0
_JSO_25  DW  1   ; objet (1 props)
_JSO_25_K0  DW  OFFSET _JSK_26
_JSO_25_V0  DW  77
_JSO_25_K1  DW  0
_JSO_25_V1  DW  0
_JSO_25_K2  DW  0
_JSO_25_V2  DW  0
_JSO_25_K3  DW  0
_JSO_25_V3  DW  0
_JSO_25_K4  DW  0
_JSO_25_V4  DW  0
_JSV_dst  DW  0
_JSK_28  DB  'n',0
_JSK_29  DB  'm',0
_JSO_27  DW  2   ; objet (2 props)
_JSO_27_K0  DW  OFFSET _JSK_28
_JSO_27_V0  DW  88
_JSO_27_K1  DW  OFFSET _JSK_29
_JSO_27_V1  DW  0
_JSO_27_K2  DW  0
_JSO_27_V2  DW  0
_JSO_27_K3  DW  0
_JSO_27_V3  DW  0
_JSO_27_K4  DW  0
_JSO_27_V4  DW  0
_JSO_27_K5  DW  0
_JSO_27_V5  DW  0
_JSK_30  DB  'm',0
_JSV_p  DW  0
_JSK_34  DB  'a',0
_JSK_35  DB  'b',0
_JSK_36  DB  'c',0
_JSO_33  DW  3   ; objet (3 props)
_JSO_33_K0  DW  OFFSET _JSK_34
_JSO_33_V0  DW  1
_JSO_33_K1  DW  OFFSET _JSK_35
_JSO_33_V1  DW  2
_JSO_33_K2  DW  OFFSET _JSK_36
_JSO_33_V2  DW  3
_JSO_33_K3  DW  0
_JSO_33_V3  DW  0
_JSO_33_K4  DW  0
_JSO_33_V4  DW  0
_JSO_33_K5  DW  0
_JSO_33_V5  DW  0
_JSO_33_K6  DW  0
_JSO_33_V6  DW  0
_JSK_37  DB  'a',0
_JSK_40  DB  'b',0
_JSK_43  DB  'c',0
_DATA   ENDS

        END
