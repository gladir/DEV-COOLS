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
