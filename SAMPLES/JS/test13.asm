; Genere par JS86 v1.0 - SAMPLES\JS\test13.js

        .MODEL SMALL
        .STACK 1024

_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME  CS:_TEXT, DS:_DATA, SS:STACK

; --- debut du code genere ---

        MOV   AX, 10
        MOV   [_JSV_x], AX
        MOV   AX, [_JSV_x]
        OR   AX, AX
        JZ   _JSL_2
        MOV   AX, 1
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
_JSL_2:
_JSL_1:
        JMP   _JSL_6
        MOV   AX, 99
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
        JMP   _JSL_5
_JSL_6:
        MOV   AX, 2
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
_JSL_5:
        MOV   AX, 5
        MOV   [_JSV_y], AX
        MOV   AX, [_JSV_y]
        PUSH   AX
        MOV   AX, 10
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JNE   _JSL_12
        INC    AX
_JSL_12:
        OR   AX, AX
        JZ   _JSL_13
        MOV   AX, 99
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
        JMP   _JSL_11
_JSL_13:
        MOV   AX, [_JSV_y]
        PUSH   AX
        MOV   AX, 5
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JNE   _JSL_17
        INC    AX
_JSL_17:
        OR   AX, AX
        JZ   _JSL_18
        MOV   AX, 3
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
        JMP   _JSL_16
_JSL_18:
        MOV   AX, 99
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
_JSL_16:
_JSL_11:
        MOV   AX, 2
        MOV   [_JSV_z], AX
        MOV   AX, [_JSV_z]
        PUSH   AX
        POP   BX
        PUSH   BX
        MOV   AX, 1
        CMP   BX, AX
        JNE   _JSL_24
        MOV   AX, 99
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
        JMP   _JSL_23
_JSL_24:
        POP   BX
        PUSH   BX
        MOV   AX, 2
        CMP   BX, AX
        JNE   _JSL_27
        MOV   AX, 4
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
        JMP   _JSL_23
_JSL_27:
        POP   BX
        PUSH   BX
        MOV   AX, 3
        CMP   BX, AX
        JNE   _JSL_30
        MOV   AX, 99
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
        JMP   _JSL_23
_JSL_30:
        MOV   AX, 99
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_33:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_34
        INC    CX
        INC    DI
        JMP   _JSL_33
_JSL_34:
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
_JSL_23:
        ADD   SP, 2
        MOV   AX, 99
        MOV   [_JSV_w], AX
        MOV   AX, [_JSV_w]
        PUSH   AX
        POP   BX
        PUSH   BX
        MOV   AX, 1
        CMP   BX, AX
        JNE   _JSL_36
        MOV   AX, 99
        CALL   _JSRT_NUMTOSTR
        MOV   DI, AX
        XOR   CX, CX
_JSL_37:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_38
        INC    CX
        INC    DI
        JMP   _JSL_37
_JSL_38:
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
        JMP   _JSL_35
_JSL_36:
        MOV   AX, 5
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
        JMP   _JSL_35
_JSL_35:
        ADD   SP, 2
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
        JZ   _JSL_41
        DEC   BX
        MOV   [SI], BX
        MOV   DI, BX
        SHL   DI, 1
        ADD   DI, 2
        ADD   DI, SI
        MOV   AX, [DI]
        RET
_JSL_41:
        XOR   AX, AX
        RET
_JSRT_ARRSHIFT:
        MOV   CX, [SI]
        OR   CX, CX
        JZ   _JSL_42
        MOV   AX, [SI+2]
        PUSH   AX
        DEC   CX
        MOV   [SI], CX
        LEA   DI, [SI+2]
        LEA   BX, [SI+4]
_JSL_43:
        OR   CX, CX
        JZ   _JSL_44
        MOV   AX, [BX]
        MOV   [DI], AX
        ADD   DI, 2
        ADD   BX, 2
        DEC   CX
        JMP   _JSL_43
_JSL_44:
        POP   AX
        RET
_JSL_42:
        XOR   AX, AX
        RET
_JSRT_ARRUNSHIFT:
        PUSH   AX
        MOV   CX, [SI]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        ADD   DI, 2
_JSL_45:
        OR   CX, CX
        JZ   _JSL_46
        MOV   AX, [DI-2]
        MOV   [DI], AX
        SUB   DI, 2
        DEC   CX
        JMP   _JSL_45
_JSL_46:
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
_JSL_47:
        OR   CX, CX
        JZ   _JSL_48
        CMP   [SI], BX
        JE   _JSL_49
        ADD   SI, 2
        INC   DX
        DEC   CX
        JMP   _JSL_47
_JSL_49:
        MOV   AX, DX
        RET
_JSL_48:
        MOV   AX, -1
        RET
_JSRT_ARRREV:
        MOV   CX, [SI]
        CMP   CX, 2
        JL   _JSL_50
        LEA   BX, [SI+2]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        SUB   DI, 2
_JSL_51:
        CMP   BX, DI
        JGE   _JSL_52
        MOV   AX, [BX]
        MOV   DX, [DI]
        MOV   [BX], DX
        MOV   [DI], AX
        ADD   BX, 2
        SUB   DI, 2
        JMP   _JSL_51
_JSL_52:
_JSL_50:
        MOV   AX, SI
        RET
_JSRT_ARRSORT:
        PUSH   SI
_JSL_53:
        XOR   DX, DX
        MOV   CX, [SI]
        DEC   CX
        CMP   CX, 0
        JLE   _JSL_56
        LEA   BX, [SI+2]
_JSL_54:
        MOV   AX, [BX]
        CMP   AX, [BX+2]
        JLE   _JSL_55
        MOV   DI, [BX+2]
        MOV   [BX], DI
        MOV   [BX+2], AX
        MOV   DX, 1
_JSL_55:
        ADD   BX, 2
        DEC   CX
        OR   CX, CX
        JNZ   _JSL_54
        OR   DX, DX
        JNZ   _JSL_53
_JSL_56:
        POP   AX
        RET

; --- runtime object routines (TODO 16) ---
_JSRT_STRCMP:
        PUSH   SI
        PUSH   DI
_JSL_57:
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_59
        OR   AL, AL
        JZ   _JSL_58
        INC   SI
        INC   DI
        JMP   _JSL_57
_JSL_58:
        XOR   AX, AX
        POP   DI
        POP   SI
        RET
_JSL_59:
        MOV   AX, 1
        POP   DI
        POP   SI
        RET
_JSRT_OBJGET:
        PUSH   CX
        PUSH   BX
        MOV   CX, [BX]
        ADD   BX, 2
_JSL_60:
        OR   CX, CX
        JZ   _JSL_62
        PUSH   CX
        PUSH   BX
        PUSH   DI
        MOV   SI, [BX]
        CALL   _JSRT_STRCMP
        POP   DI
        POP   BX
        POP   CX
        OR   AX, AX
        JZ   _JSL_61
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_60
_JSL_61:
        MOV   AX, [BX+2]
        POP   BX
        POP   CX
        RET
_JSL_62:
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
_JSL_63:
        OR   CX, CX
        JZ   _JSL_65
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
        JZ   _JSL_64
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_63
_JSL_64:
        MOV   [BX+2], DX
        MOV   AX, DX
        POP   BX
        POP   CX
        RET
_JSL_65:
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
_JSL_66:
        OR   CX, CX
        JZ   _JSL_67
        MOV   AX, [SI]
        MOV   [DI], AX
        ADD   SI, 4
        ADD   DI, 2
        DEC   CX
        JMP   _JSL_66
_JSL_67:
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
_JSL_68:
        OR   CX, CX
        JZ   _JSL_69
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
        JMP   _JSL_68
_JSL_69:
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
_JSV_x  DW  0
_JSV_y  DW  0
_JSV_z  DW  0
_JSV_w  DW  0
_DATA   ENDS

        END
