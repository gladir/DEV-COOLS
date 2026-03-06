; Genere par JS86 v1.0 - SAMPLES\JS\test14.js

        .MODEL SMALL
        .STACK 1024

_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME  CS:_TEXT, DS:_DATA, SS:STACK

; --- debut du code genere ---

        MOV   AX, 0
        MOV   [_JSV_sum], AX
        MOV   AX, 1
        MOV   [_JSV_i], AX
_JSL_1:
        MOV   AX, [_JSV_i]
        PUSH   AX
        MOV   AX, 5
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JG   _JSL_3
        INC    AX
_JSL_3:
        OR   AX, AX
        JZ   _JSL_2
        MOV   AX, [_JSV_sum]
        PUSH   AX
        MOV   AX, [_JSV_i]
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [_JSV_sum], AX
        MOV   AX, [_JSV_i]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [_JSV_i], AX
        JMP   _JSL_1
_JSL_2:
        MOV   AX, [_JSV_sum]
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
        MOV   AX, 0
        MOV   [_JSV_s2], AX
        MOV   AX, 1
        MOV   [_JSV_j], AX
_JSL_6:
        MOV   AX, [_JSV_s2]
        PUSH   AX
        MOV   AX, [_JSV_j]
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [_JSV_s2], AX
        MOV   AX, [_JSV_j]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [_JSV_j], AX
_JSL_7:
        MOV   AX, [_JSV_j]
        PUSH   AX
        MOV   AX, 3
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JG   _JSL_9
        INC    AX
_JSL_9:
        OR   AX, AX
        JNZ   _JSL_6
_JSL_8:
        MOV   AX, [_JSV_s2]
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
        MOV   AX, 0
        MOV   [_JSV_s3], AX
        MOV   AX, 0
        MOV   [_JSV_k], AX
_JSL_12:
        MOV   AX, [_JSV_k]
        PUSH   AX
        MOV   AX, 5
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JGE   _JSL_15
        INC    AX
_JSL_15:
        OR   AX, AX
        JZ   _JSL_14
        JMP   _JSL_16
_JSL_13:
        MOV   AX, [_JSV_k]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [_JSV_k], AX
        JMP   _JSL_12
_JSL_16:
        MOV   AX, [_JSV_s3]
        PUSH   AX
        MOV   AX, [_JSV_k]
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [_JSV_s3], AX
        JMP   _JSL_13
_JSL_14:
        MOV   AX, [_JSV_s3]
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
        MOV   AX, 0
        MOV   [_JSV_s4], AX
        MOV   AX, 0
        MOV   [_JSV_m], AX
_JSL_19:
        MOV   AX, 1
        OR   AX, AX
        JZ   _JSL_20
        MOV   AX, [_JSV_m]
        PUSH   AX
        MOV   AX, 3
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JNE   _JSL_22
        INC    AX
_JSL_22:
        OR   AX, AX
        JZ   _JSL_23
        JMP   _JSL_20
_JSL_23:
_JSL_21:
        MOV   AX, [_JSV_s4]
        PUSH   AX
        MOV   AX, [_JSV_m]
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [_JSV_s4], AX
        MOV   AX, [_JSV_m]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [_JSV_m], AX
        JMP   _JSL_19
_JSL_20:
        MOV   AX, [_JSV_s4]
        CALL   _JSRT_NUMTOSTR
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
        LEA   DX, _JS_CRLF
        MOV   CX, 2
        MOV   BX, 1
        MOV   AH, 40h
        INT    21h
        MOV   AX, 0
        MOV   [_JSV_s5], AX
        MOV   AX, 0
        MOV   [_JSV_n], AX
_JSL_26:
        MOV   AX, [_JSV_n]
        PUSH   AX
        MOV   AX, 5
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JGE   _JSL_29
        INC    AX
_JSL_29:
        OR   AX, AX
        JZ   _JSL_28
        JMP   _JSL_30
_JSL_27:
        MOV   AX, [_JSV_n]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [_JSV_n], AX
        JMP   _JSL_26
_JSL_30:
        MOV   AX, [_JSV_n]
        PUSH   AX
        MOV   AX, 2
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JNE   _JSL_32
        INC    AX
_JSL_32:
        OR   AX, AX
        JZ   _JSL_33
        JMP   _JSL_27
_JSL_33:
_JSL_31:
        MOV   AX, [_JSV_s5]
        PUSH   AX
        MOV   AX, [_JSV_n]
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [_JSV_s5], AX
        JMP   _JSL_27
_JSL_28:
        MOV   AX, [_JSV_s5]
        CALL   _JSRT_NUMTOSTR
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
        JZ   _JSL_36
        DEC   BX
        MOV   [SI], BX
        MOV   DI, BX
        SHL   DI, 1
        ADD   DI, 2
        ADD   DI, SI
        MOV   AX, [DI]
        RET
_JSL_36:
        XOR   AX, AX
        RET
_JSRT_ARRSHIFT:
        MOV   CX, [SI]
        OR   CX, CX
        JZ   _JSL_37
        MOV   AX, [SI+2]
        PUSH   AX
        DEC   CX
        MOV   [SI], CX
        LEA   DI, [SI+2]
        LEA   BX, [SI+4]
_JSL_38:
        OR   CX, CX
        JZ   _JSL_39
        MOV   AX, [BX]
        MOV   [DI], AX
        ADD   DI, 2
        ADD   BX, 2
        DEC   CX
        JMP   _JSL_38
_JSL_39:
        POP   AX
        RET
_JSL_37:
        XOR   AX, AX
        RET
_JSRT_ARRUNSHIFT:
        PUSH   AX
        MOV   CX, [SI]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        ADD   DI, 2
_JSL_40:
        OR   CX, CX
        JZ   _JSL_41
        MOV   AX, [DI-2]
        MOV   [DI], AX
        SUB   DI, 2
        DEC   CX
        JMP   _JSL_40
_JSL_41:
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
_JSL_42:
        OR   CX, CX
        JZ   _JSL_43
        CMP   [SI], BX
        JE   _JSL_44
        ADD   SI, 2
        INC   DX
        DEC   CX
        JMP   _JSL_42
_JSL_44:
        MOV   AX, DX
        RET
_JSL_43:
        MOV   AX, -1
        RET
_JSRT_ARRREV:
        MOV   CX, [SI]
        CMP   CX, 2
        JL   _JSL_45
        LEA   BX, [SI+2]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        SUB   DI, 2
_JSL_46:
        CMP   BX, DI
        JGE   _JSL_47
        MOV   AX, [BX]
        MOV   DX, [DI]
        MOV   [BX], DX
        MOV   [DI], AX
        ADD   BX, 2
        SUB   DI, 2
        JMP   _JSL_46
_JSL_47:
_JSL_45:
        MOV   AX, SI
        RET
_JSRT_ARRSORT:
        PUSH   SI
_JSL_48:
        XOR   DX, DX
        MOV   CX, [SI]
        DEC   CX
        CMP   CX, 0
        JLE   _JSL_51
        LEA   BX, [SI+2]
_JSL_49:
        MOV   AX, [BX]
        CMP   AX, [BX+2]
        JLE   _JSL_50
        MOV   DI, [BX+2]
        MOV   [BX], DI
        MOV   [BX+2], AX
        MOV   DX, 1
_JSL_50:
        ADD   BX, 2
        DEC   CX
        OR   CX, CX
        JNZ   _JSL_49
        OR   DX, DX
        JNZ   _JSL_48
_JSL_51:
        POP   AX
        RET

; --- runtime object routines (TODO 16) ---
_JSRT_STRCMP:
        PUSH   SI
        PUSH   DI
_JSL_52:
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_54
        OR   AL, AL
        JZ   _JSL_53
        INC   SI
        INC   DI
        JMP   _JSL_52
_JSL_53:
        XOR   AX, AX
        POP   DI
        POP   SI
        RET
_JSL_54:
        MOV   AX, 1
        POP   DI
        POP   SI
        RET
_JSRT_OBJGET:
        PUSH   CX
        PUSH   BX
        MOV   CX, [BX]
        ADD   BX, 2
_JSL_55:
        OR   CX, CX
        JZ   _JSL_57
        PUSH   CX
        PUSH   BX
        PUSH   DI
        MOV   SI, [BX]
        CALL   _JSRT_STRCMP
        POP   DI
        POP   BX
        POP   CX
        OR   AX, AX
        JZ   _JSL_56
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_55
_JSL_56:
        MOV   AX, [BX+2]
        POP   BX
        POP   CX
        RET
_JSL_57:
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
_JSL_58:
        OR   CX, CX
        JZ   _JSL_60
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
        JZ   _JSL_59
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_58
_JSL_59:
        MOV   [BX+2], DX
        MOV   AX, DX
        POP   BX
        POP   CX
        RET
_JSL_60:
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
_JSL_61:
        OR   CX, CX
        JZ   _JSL_62
        MOV   AX, [SI]
        MOV   [DI], AX
        ADD   SI, 4
        ADD   DI, 2
        DEC   CX
        JMP   _JSL_61
_JSL_62:
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
_JSL_63:
        OR   CX, CX
        JZ   _JSL_64
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
        JMP   _JSL_63
_JSL_64:
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
_JSV_sum  DW  0
_JSV_i  DW  0
_JSV_s2  DW  0
_JSV_j  DW  0
_JSV_s3  DW  0
_JSV_k  DW  0
_JSV_s4  DW  0
_JSV_m  DW  0
_JSV_s5  DW  0
_JSV_n  DW  0
_DATA   ENDS

        END
