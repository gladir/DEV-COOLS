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
        MOV   AX, [BP+6]
        PUSH   AX
        MOV   AX, [BP+4]
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        JMP   _JSL_1
        XOR   AX, AX
_JSL_1:
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
        XOR   AX, AX
        JMP   _JSL_5
        XOR   AX, AX
_JSL_5:
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
        XOR   AX, AX
_JSL_9:
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
        SUB   SP, 2
        MOV   AX, [BP+4]
        PUSH   AX
        MOV   AX, [BP+4]
        MOV   BX, AX
        POP   AX
        IMUL   BX
        MOV   [BP-2], AX
        MOV   AX, [BP-2]
        JMP   _JSL_13
        XOR   AX, AX
_JSL_13:
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
        MOV   AX, [BP+4]
        PUSH   AX
        MOV   AX, 2
        MOV   BX, AX
        POP   AX
        IMUL   BX
        JMP   _JSL_19
        XOR   AX, AX
_JSL_19:
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
        MOV   AX, [BP+4]
        PUSH   AX
        MOV   AX, 3
        MOV   BX, AX
        POP   AX
        IMUL   BX
_JSL_24:
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
        MOV   AX, [BP+6]
        PUSH   AX
        MOV   AX, [BP+4]
        MOV   BX, AX
        POP   AX
        IMUL   BX
_JSL_29:
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
        SUB   SP, 2
        MOV   AX, [BP+4]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [BP-2], AX
        MOV   AX, [BP-2]
        JMP   _JSL_34
        XOR   AX, AX
_JSL_34:
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
        MOV   AX, [BP+4]
        PUSH   AX
        MOV   AX, [BP+6]
        CALL   AX
        ADD   SP, 2
        JMP   _JSL_37
        XOR   AX, AX
_JSL_37:
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
        MOV   AX, 42
_JSL_43:
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
_JSV_double  DW  0
_JSV_triple  DW  0
_JSV_mul  DW  0
_JSV_inc  DW  0
_JSV_getVal  DW  0
_DATA   ENDS

        END
