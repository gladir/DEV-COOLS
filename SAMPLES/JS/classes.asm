; Genere par JS86 v1.0 - SAMPLES\JS\classes.js

        .MODEL SMALL
        .STACK 1024

_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME  CS:_TEXT, DS:_DATA, SS:STACK

_JSF_main:
; --- initialisation segment de donnees ---
        MOV   AX, _DATA
        MOV   DS, AX

; --- debut du code genere ---

        JMP   _JSL_1
_JSF_Animal_ctor:
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        PUSH   DI
        INC   WORD PTR [_JS_CALLDEPTH]
        MOV   AX, [BP+4]
        PUSH   AX
        MOV   AX, [BP+8]
        POP   BX
        LEA   DI, _JSK_4
        CALL   _JSRT_OBJSET
        MOV   AX, [BP+4]
        PUSH   AX
        MOV   AX, [BP+6]
        POP   BX
        LEA   DI, _JSK_5
        CALL   _JSRT_OBJSET
        MOV   AX, [BP+4]
_JSL_2:
        DEC   WORD PTR [_JS_CALLDEPTH]
        MOV   SI, [BP-2]
        MOV   DI, [BP-4]
        MOV   SP, BP
        POP   BP
        RET
_JSF_Animal_speak:
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        PUSH   DI
        INC   WORD PTR [_JS_CALLDEPTH]
        MOV   AX, [BP+4]
        MOV   BX, AX
        LEA   DI, _JSK_8
        CALL   _JSRT_OBJGET
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
        XOR   AX, AX
_JSL_6:
        DEC   WORD PTR [_JS_CALLDEPTH]
        MOV   SI, [BP-2]
        MOV   DI, [BP-4]
        MOV   SP, BP
        POP   BP
        RET
_JSF_Animal__init:
        PUSH   BX
        LEA   DI, _JSK_11
        LEA   AX, _JSF_Animal_speak
        CALL   _JSRT_OBJSET
        POP   BX
        RET
_JSL_1:
        JMP   _JSL_12
_JSF_Dog_ctor:
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        PUSH   DI
        INC   WORD PTR [_JS_CALLDEPTH]
        MOV   AX, [BP+6]
        PUSH   AX
        LEA   AX, _JSK_15
        PUSH   AX
        MOV   AX, [BP+4]
        PUSH   AX
        CALL   _JSF_Animal_ctor
        ADD   SP, 6
        MOV   AX, [BP+4]
_JSL_13:
        DEC   WORD PTR [_JS_CALLDEPTH]
        MOV   SI, [BP-2]
        MOV   DI, [BP-4]
        MOV   SP, BP
        POP   BP
        RET
_JSF_Dog__init:
        PUSH   BX
        CALL   _JSF_Animal__init
        POP   BX
        RET
_JSL_12:
        JMP   _JSL_16
_JSF_Cat_ctor:
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        PUSH   DI
        INC   WORD PTR [_JS_CALLDEPTH]
        MOV   AX, [BP+6]
        PUSH   AX
        LEA   AX, _JSK_19
        PUSH   AX
        MOV   AX, [BP+4]
        PUSH   AX
        CALL   _JSF_Animal_ctor
        ADD   SP, 6
        MOV   AX, [BP+4]
_JSL_17:
        DEC   WORD PTR [_JS_CALLDEPTH]
        MOV   SI, [BP-2]
        MOV   DI, [BP-4]
        MOV   SP, BP
        POP   BP
        RET
_JSF_Cat__init:
        PUSH   BX
        CALL   _JSF_Animal__init
        POP   BX
        RET
_JSL_16:
        LEA   AX, _JSK_20
        PUSH   AX
        LEA   BX, _JSC_Dog
        CALL   _JSRT_OBJCREATE
        MOV   BX, AX
        CALL   _JSF_Dog__init
        MOV   AX, BX
        MOV   [_JSRT_OBJTMP], AX
        PUSH   AX
        CALL   _JSF_Dog_ctor
        ADD   SP, 4
        MOV   AX, [_JSRT_OBJTMP]
        MOV   [_JSV_dog], AX
        MOV   AX, [_JSV_dog]
        MOV   BX, AX
        LEA   DI, _JSK_21
        CALL   _JSRT_OBJGET
        MOV   [_JSRT_OBJTMP], BX
        PUSH   AX
        PUSH   WORD PTR [_JSRT_OBJTMP]
        MOV   AX, [SP+2]
        CALL   AX
        ADD   SP, 4
        LEA   AX, _JSK_22
        PUSH   AX
        LEA   BX, _JSC_Cat
        CALL   _JSRT_OBJCREATE
        MOV   BX, AX
        CALL   _JSF_Cat__init
        MOV   AX, BX
        MOV   [_JSRT_OBJTMP], AX
        PUSH   AX
        CALL   _JSF_Cat_ctor
        ADD   SP, 4
        MOV   AX, [_JSRT_OBJTMP]
        MOV   [_JSV_cat], AX
        MOV   AX, [_JSV_cat]
        MOV   BX, AX
        LEA   DI, _JSK_23
        CALL   _JSRT_OBJGET
        MOV   [_JSRT_OBJTMP], BX
        PUSH   AX
        PUSH   WORD PTR [_JSRT_OBJTMP]
        MOV   AX, [SP+2]
        CALL   AX
        ADD   SP, 4
        MOV   AX, [_JSV_dog]
        MOV   BX, AX
        LEA   DI, _JSK_24
        CALL   _JSRT_OBJGET
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
        MOV   AX, [_JSV_cat]
        MOV   BX, AX
        LEA   DI, _JSK_27
        CALL   _JSRT_OBJGET
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
        JMP   _JSL_30
_JSF_Counter_ctor:
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        PUSH   DI
        INC   WORD PTR [_JS_CALLDEPTH]
        MOV   AX, [BP+4]
        PUSH   AX
        MOV   AX, 0
        POP   BX
        LEA   DI, _JSK_33
        CALL   _JSRT_OBJSET
        MOV   AX, [BP+4]
_JSL_31:
        DEC   WORD PTR [_JS_CALLDEPTH]
        MOV   SI, [BP-2]
        MOV   DI, [BP-4]
        MOV   SP, BP
        POP   BP
        RET
_JSF_Counter_increment:
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        PUSH   DI
        INC   WORD PTR [_JS_CALLDEPTH]
        MOV   AX, [BP+4]
        PUSH   AX
        MOV   AX, [BP+4]
        MOV   BX, AX
        LEA   DI, _JSK_37
        CALL   _JSRT_OBJGET
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        POP   BX
        LEA   DI, _JSK_36
        CALL   _JSRT_OBJSET
        XOR   AX, AX
_JSL_34:
        DEC   WORD PTR [_JS_CALLDEPTH]
        MOV   SI, [BP-2]
        MOV   DI, [BP-4]
        MOV   SP, BP
        POP   BP
        RET
_JSF_Counter_getCount:
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        PUSH   DI
        INC   WORD PTR [_JS_CALLDEPTH]
        MOV   AX, [BP+4]
        MOV   BX, AX
        LEA   DI, _JSK_41
        CALL   _JSRT_OBJGET
        JMP   _JSL_39
        XOR   AX, AX
_JSL_39:
        DEC   WORD PTR [_JS_CALLDEPTH]
        MOV   SI, [BP-2]
        MOV   DI, [BP-4]
        MOV   SP, BP
        POP   BP
        RET
_JSF_Counter__init:
        PUSH   BX
        LEA   DI, _JSK_38
        LEA   AX, _JSF_Counter_increment
        CALL   _JSRT_OBJSET
        LEA   DI, _JSK_42
        LEA   AX, _JSF_Counter_getCount
        CALL   _JSRT_OBJSET
        POP   BX
        RET
_JSL_30:
        LEA   BX, _JSC_Counter
        CALL   _JSRT_OBJCREATE
        MOV   BX, AX
        CALL   _JSF_Counter__init
        MOV   AX, BX
        MOV   [_JSRT_OBJTMP], AX
        PUSH   AX
        CALL   _JSF_Counter_ctor
        ADD   SP, 2
        MOV   AX, [_JSRT_OBJTMP]
        MOV   [_JSV_c], AX
        MOV   AX, [_JSV_c]
        MOV   BX, AX
        LEA   DI, _JSK_43
        CALL   _JSRT_OBJGET
        MOV   [_JSRT_OBJTMP], BX
        PUSH   AX
        PUSH   WORD PTR [_JSRT_OBJTMP]
        MOV   AX, [SP+2]
        CALL   AX
        ADD   SP, 4
        MOV   AX, [_JSV_c]
        MOV   BX, AX
        LEA   DI, _JSK_44
        CALL   _JSRT_OBJGET
        MOV   [_JSRT_OBJTMP], BX
        PUSH   AX
        PUSH   WORD PTR [_JSRT_OBJTMP]
        MOV   AX, [SP+2]
        CALL   AX
        ADD   SP, 4
        MOV   AX, [_JSV_c]
        MOV   BX, AX
        LEA   DI, _JSK_45
        CALL   _JSRT_OBJGET
        MOV   [_JSRT_OBJTMP], BX
        PUSH   AX
        PUSH   WORD PTR [_JSRT_OBJTMP]
        MOV   AX, [SP+2]
        CALL   AX
        ADD   SP, 4
        MOV   AX, [_JSV_c]
        MOV   BX, AX
        LEA   DI, _JSK_46
        CALL   _JSRT_OBJGET
        MOV   [_JSRT_OBJTMP], BX
        PUSH   AX
        PUSH   WORD PTR [_JSRT_OBJTMP]
        MOV   AX, [SP+2]
        CALL   AX
        ADD   SP, 4
        CALL   _JSRT_NUMTOSTR
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
        JNS   _JSL_49
        NEG    AX
_JSL_49:
        MOV   SI, 10
_JSL_50:
        XOR   DX, DX
        DIV    SI
        ADD   DL, '0'
        MOV   [DI], DL
        DEC   DI
        INC   CX
        OR   AX, AX
        JNZ   _JSL_50
        OR   BX, BX
        JNS   _JSL_51
        MOV   BYTE PTR [DI], '-'
        DEC   DI
_JSL_51:
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
_JSL_52:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_53
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_52
_JSL_53:
        MOV   SI, BX
_JSL_55:
        MOV   AL, [SI]
        MOV   [DI], AL
        OR   AL, AL
        JZ   _JSL_54
        INC   SI
        INC   DI
        JMP   _JSL_55
_JSL_54:
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
        JE   _JSL_56
        CMP   BX, 2
        JE   _JSL_57
        CMP   BX, 3
        JE   _JSL_58
        CMP   BX, 7
        JE   _JSL_59
        LEA   AX, _JS_TYP_NUMBER
        RET
_JSL_56:
        LEA   AX, _JS_TYP_STRING
        RET
_JSL_57:
        LEA   AX, _JS_TYP_BOOLEAN
        RET
_JSL_58:
        LEA   AX, _JS_TYP_OBJECT
        RET
_JSL_59:
        LEA   AX, _JS_UNDEF
        RET
_JSRT_TRUTHY:
        CMP   BX, 7
        JE   _JSL_62
        CMP   BX, 6
        JE   _JSL_62
        CMP   BX, 1
        JE   _JSL_60
        OR   AX, AX
        JZ   _JSL_62
        JMP   _JSL_61
_JSL_60:
        MOV   SI, AX
        CMP   BYTE PTR [SI], 0
        JE   _JSL_62
_JSL_61:
        MOV   AX, 1
        RET
_JSL_62:
        XOR   AX, AX
        RET
_JSRT_STRTRUTHY:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_64
        CMP   BYTE PTR [SI], '0'
        JNE   _JSL_63
        CMP   BYTE PTR [SI+1], 0
        JE   _JSL_64
_JSL_63:
        MOV   AX, 1
        RET
_JSL_64:
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
        JZ   _JSL_65
        DEC   BX
        MOV   [SI], BX
        MOV   DI, BX
        SHL   DI, 1
        ADD   DI, 2
        ADD   DI, SI
        MOV   AX, [DI]
        RET
_JSL_65:
        XOR   AX, AX
        RET
_JSRT_ARRSHIFT:
        MOV   CX, [SI]
        OR   CX, CX
        JZ   _JSL_66
        MOV   AX, [SI+2]
        PUSH   AX
        DEC   CX
        MOV   [SI], CX
        LEA   DI, [SI+2]
        LEA   BX, [SI+4]
_JSL_67:
        OR   CX, CX
        JZ   _JSL_68
        MOV   AX, [BX]
        MOV   [DI], AX
        ADD   DI, 2
        ADD   BX, 2
        DEC   CX
        JMP   _JSL_67
_JSL_68:
        POP   AX
        RET
_JSL_66:
        XOR   AX, AX
        RET
_JSRT_ARRUNSHIFT:
        PUSH   AX
        MOV   CX, [SI]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        ADD   DI, 2
_JSL_69:
        OR   CX, CX
        JZ   _JSL_70
        MOV   AX, [DI-2]
        MOV   [DI], AX
        SUB   DI, 2
        DEC   CX
        JMP   _JSL_69
_JSL_70:
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
_JSL_71:
        OR   CX, CX
        JZ   _JSL_72
        CMP   [SI], BX
        JE   _JSL_73
        ADD   SI, 2
        INC   DX
        DEC   CX
        JMP   _JSL_71
_JSL_73:
        MOV   AX, DX
        RET
_JSL_72:
        MOV   AX, -1
        RET
_JSRT_ARRREV:
        MOV   CX, [SI]
        CMP   CX, 2
        JL   _JSL_74
        LEA   BX, [SI+2]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        SUB   DI, 2
_JSL_75:
        CMP   BX, DI
        JGE   _JSL_76
        MOV   AX, [BX]
        MOV   DX, [DI]
        MOV   [BX], DX
        MOV   [DI], AX
        ADD   BX, 2
        SUB   DI, 2
        JMP   _JSL_75
_JSL_76:
_JSL_74:
        MOV   AX, SI
        RET
_JSRT_ARRSORT:
        PUSH   SI
_JSL_77:
        XOR   DX, DX
        MOV   CX, [SI]
        DEC   CX
        CMP   CX, 0
        JLE   _JSL_80
        LEA   BX, [SI+2]
_JSL_78:
        MOV   AX, [BX]
        CMP   AX, [BX+2]
        JLE   _JSL_79
        MOV   DI, [BX+2]
        MOV   [BX], DI
        MOV   [BX+2], AX
        MOV   DX, 1
_JSL_79:
        ADD   BX, 2
        DEC   CX
        OR   CX, CX
        JNZ   _JSL_78
        OR   DX, DX
        JNZ   _JSL_77
_JSL_80:
        POP   AX
        RET

; --- runtime object routines (TODO 16) ---
_JSRT_STRCMP:
        PUSH   SI
        PUSH   DI
_JSL_81:
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_83
        OR   AL, AL
        JZ   _JSL_82
        INC   SI
        INC   DI
        JMP   _JSL_81
_JSL_82:
        XOR   AX, AX
        POP   DI
        POP   SI
        RET
_JSL_83:
        MOV   AX, 1
        POP   DI
        POP   SI
        RET
_JSRT_OBJGET:
        PUSH   CX
        PUSH   BX
        MOV   CX, [BX]
        ADD   BX, 2
_JSL_84:
        OR   CX, CX
        JZ   _JSL_86
        PUSH   CX
        PUSH   BX
        PUSH   DI
        MOV   SI, [BX]
        CALL   _JSRT_STRCMP
        POP   DI
        POP   BX
        POP   CX
        OR   AX, AX
        JZ   _JSL_85
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_84
_JSL_85:
        MOV   AX, [BX+2]
        POP   BX
        POP   CX
        RET
_JSL_86:
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
_JSL_87:
        OR   CX, CX
        JZ   _JSL_89
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
        JZ   _JSL_88
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_87
_JSL_88:
        MOV   [BX+2], DX
        MOV   AX, DX
        POP   BX
        POP   CX
        RET
_JSL_89:
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
_JSL_90:
        OR   CX, CX
        JZ   _JSL_91
        MOV   AX, [SI]
        MOV   [DI], AX
        ADD   SI, 4
        ADD   DI, 2
        DEC   CX
        JMP   _JSL_90
_JSL_91:
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
_JSL_92:
        OR   CX, CX
        JZ   _JSL_93
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
        JMP   _JSL_92
_JSL_93:
        POP   BX
        MOV   AX, BX
        POP   DI
        POP   CX
        RET

; --- runtime regexp routines (TODO 19) ---
_JSRT_REPARSE:
        PUSH   BX
        MOV   BX, DI
_JSL_94:
        MOV   AL, [BX]
        CMP   AL, 1
        JZ   _JSL_95
        OR   AL, AL
        JZ   _JSL_95
        INC   BX
        JMP   _JSL_94
_JSL_95:
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
        JZ   _JSL_98
_JSL_96:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_99
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   DX, CX
_JSL_97:
        OR   DX, DX
        JZ   _JSL_98B
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_99B
        INC   SI
        INC   DI
        DEC   DX
        JMP   _JSL_97
_JSL_98B:
        POP   CX
        POP   DI
        POP   SI
        JMP   _JSL_98
_JSL_99B:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_96
_JSL_98:
        MOV   AX, 1
        POP   DX
        POP   CX
        POP   BX
        POP   DI
        POP   SI
        RET
_JSL_99:
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
        JZ   _JSL_102
_JSL_100:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_103
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   DX, CX
_JSL_101:
        OR   DX, DX
        JZ   _JSL_102B
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_103B
        INC   SI
        INC   DI
        DEC   DX
        JMP   _JSL_101
_JSL_102B:
        POP   CX
        POP   DI
        POP   SI
        JMP   _JSL_102
_JSL_103B:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_100
_JSL_102:
        MOV   AX, SI
        SUB   AX, BX
        POP   DX
        POP   CX
        POP   BX
        POP   DI
        POP   SI
        RET
_JSL_103:
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
        JZ   _JSL_104
        MOV   AX, SI
        RET
_JSL_104:
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
_JSL_105:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_108
        OR   DX, DX
        JZ   _JSL_106C
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   CX, DX
_JSL_106:
        OR   CX, CX
        JZ   _JSL_107
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNZ   _JSL_106N
        INC   SI
        INC   DI
        DEC   CX
        JMP   _JSL_106
_JSL_106N:
        POP   CX
        POP   DI
        POP   SI
_JSL_106C:
        MOV   AL, [SI]
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_105
_JSL_107:
        POP   CX
        POP   DI
        POP   AX
        PUSH   SI
        MOV   SI, [SP+10]
_JSL_109:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_109D
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_109
_JSL_109D:
        POP   SI
_JSL_110:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_108
        MOV   [BX], AL
        INC   SI
        INC   BX
        JMP   _JSL_110
_JSL_108:
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
_JSL_111:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_112
        INC   AX
        INC   SI
        JMP   _JSL_111
_JSL_112:
        POP   SI
        RET
_JSRT_STRINDEXOF:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        MOV   BX, SI
_JSL_113:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_116
        PUSH   SI
        PUSH   DI
_JSL_114:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_115
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_114N
        INC   SI
        INC   DI
        JMP   _JSL_114
_JSL_115:
        POP   DI
        POP   AX
        SUB   AX, BX
        POP   DX
        POP   CX
        POP   BX
        RET
_JSL_114N:
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_113
_JSL_116:
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
_JSL_117:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_120
        PUSH   SI
        PUSH   DI
_JSL_118:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_119
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_118N
        INC   SI
        INC   DI
        JMP   _JSL_118
_JSL_119:
        POP   DI
        POP   AX
        SUB   AX, BX
        MOV   DX, AX
        ADD   AX, BX
        MOV   SI, AX
        INC   SI
        JMP   _JSL_117
_JSL_118N:
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_117
_JSL_120:
        MOV   AX, DX
        POP   DX
        POP   CX
        POP   BX
        RET
_JSRT_STRSTARTW:
_JSL_121:
        CMP   BYTE PTR [DI], 0
        JE   _JSL_121Y
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_122
        INC   SI
        INC   DI
        JMP   _JSL_121
_JSL_121Y:
        MOV   AX, 1
        RET
_JSL_122:
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
        JA   _JSL_123
        SUB   BX, CX
        ADD   SI, BX
        POP   CX
        POP   BX
        JMP   _JSRT_STRSTARTW
_JSL_123:
        XOR   AX, AX
        POP   CX
        POP   BX
        RET
_JSRT_STRSLICE:
        PUSH   DI
        PUSH   DX
        LEA   DI, _JSRT_STRBUF
        MOV   DX, BX
_JSL_124:
        OR   DX, DX
        JZ   _JSL_125
        CMP   BYTE PTR [SI], 0
        JE   _JSL_126
        INC   SI
        DEC   DX
        JMP   _JSL_124
_JSL_125:
        CMP   BX, CX
        JGE   _JSL_126
        CMP   BYTE PTR [SI], 0
        JE   _JSL_126
        MOV   AL, [SI]
        MOV   [DI], AL
        INC   SI
        INC   DI
        INC   BX
        JMP   _JSL_125
_JSL_126:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DX
        POP   DI
        RET
_JSRT_STRTOUPPER:
        PUSH   DI
        LEA   DI, _JSRT_STRBUF
_JSL_127:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_128
        CMP   AL, 'a'
        JB   _JSL_127C
        CMP   AL, 'z'
        JA   _JSL_127C
        SUB   AL, 32
_JSL_127C:
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_127
_JSL_128:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DI
        RET
_JSRT_STRTOLOWER:
        PUSH   DI
        LEA   DI, _JSRT_STRBUF
_JSL_129:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_130
        CMP   AL, 'A'
        JB   _JSL_129C
        CMP   AL, 'Z'
        JA   _JSL_129C
        ADD   AL, 32
_JSL_129C:
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_129
_JSL_130:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _JSRT_STRBUF
        POP   DI
        RET
_JSRT_STRTRIM:
        PUSH   DI
        PUSH   BX
_JSL_131:
        MOV   AL, [SI]
        CMP   AL, 32
        JE   _JSL_131S
        CMP   AL, 9
        JE   _JSL_131S
        JMP   _JSL_132
_JSL_131S:
        INC   SI
        JMP   _JSL_131
_JSL_132:
        LEA   DI, _JSRT_STRBUF
        MOV   BX, DI
_JSL_134:
        MOV   AL, [SI]
        MOV   [DI], AL
        OR   AL, AL
        JZ   _JSL_133
        INC   SI
        INC   DI
        JMP   _JSL_134
_JSL_133:
_JSL_135:
        DEC   DI
        CMP   DI, BX
        JB   _JSL_135D
        CMP   BYTE PTR [DI], 32
        JE   _JSL_135
        CMP   BYTE PTR [DI], 9
        JE   _JSL_135
_JSL_135D:
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
_JSL_136:
        CMP   BYTE PTR [SI], 0
        JE   _JSL_139
        PUSH   SI
        PUSH   DI
        PUSH   CX
        MOV   CX, DX
_JSL_137:
        OR   CX, CX
        JZ   _JSL_138
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_137N
        INC   SI
        INC   DI
        DEC   CX
        JMP   _JSL_137
_JSL_137N:
        POP   CX
        POP   DI
        POP   SI
        INC   SI
        JMP   _JSL_136
_JSL_138:
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
        JMP   _JSL_136
_JSL_139:
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
_JSL_140:
        OR   CX, CX
        JZ   _JSL_142
        MOV   SI, DX
_JSL_141:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _JSL_141D
        MOV   [DI], AL
        INC   SI
        INC   DI
        JMP   _JSL_141
_JSL_141D:
        DEC   CX
        JMP   _JSL_140
_JSL_142:
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
        JAE   _JSL_145
        SUB   CX, DX
        LEA   BX, _JSRT_STRBUF
        PUSH   SI
        MOV   SI, DI
_JSL_143:
        OR   CX, CX
        JZ   _JSL_144
        MOV   AL, [SI]
        OR   AL, AL
        JNZ   _JSL_143C
        MOV   SI, DI
        MOV   AL, [SI]
_JSL_143C:
        MOV   [BX], AL
        INC   BX
        INC   SI
        DEC   CX
        JMP   _JSL_143
_JSL_144:
        POP   SI
_JSL_146:
        MOV   AL, [SI]
        MOV   [BX], AL
        OR   AL, AL
        JZ   _JSL_146D
        INC   SI
        INC   BX
        JMP   _JSL_146
_JSL_146D:
        LEA   AX, _JSRT_STRBUF
        POP   DX
        POP   BX
        RET
_JSL_145:
        LEA   BX, _JSRT_STRBUF
_JSL_147:
        MOV   AL, [SI]
        MOV   [BX], AL
        OR   AL, AL
        JZ   _JSL_147D
        INC   SI
        INC   BX
        JMP   _JSL_147
_JSL_147D:
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
_JSL_148:
        CMP   BYTE PTR [SI], 32
        JE   _JSL_148S
        JMP   _JSL_148E
_JSL_148S:
        INC   SI
        JMP   _JSL_148
_JSL_148E:
        CMP   BYTE PTR [SI], '-'
        JNE   _JSL_148P
        MOV   BX, 1
        INC   SI
        JMP   _JSL_149
_JSL_148P:
        CMP   BYTE PTR [SI], '+'
        JNE   _JSL_149
        INC   SI
_JSL_149:
        XOR   DX, DX
        MOV   DL, [SI]
        OR   DL, DL
        JZ   _JSL_150
        CMP   DL, '0'
        JB   _JSL_150
        CMP   DL, '9'
        JA   _JSL_149H
        SUB   DL, '0'
        JMP   _JSL_149M
_JSL_149H:
        CMP   DL, 'a'
        JB   _JSL_149U
        CMP   DL, 'f'
        JA   _JSL_150
        SUB   DL, 'a'
        ADD   DL, 10
        JMP   _JSL_149M
_JSL_149U:
        CMP   DL, 'A'
        JB   _JSL_150
        CMP   DL, 'F'
        JA   _JSL_150
        SUB   DL, 'A'
        ADD   DL, 10
_JSL_149M:
        CMP   DL, CL
        JAE   _JSL_150
        PUSH   DX
        PUSH   CX
        MUL    CX
        POP   CX
        POP   DX
        ADD   AX, DX
        INC   SI
        JMP   _JSL_149
_JSL_150:
        OR   BX, BX
        JZ   _JSL_150D
        NEG    AX
_JSL_150D:
        POP   DX
        POP   BX
        RET
_JSRT_ABS:
        OR   AX, AX
        JNS   _JSL_151
        NEG    AX
_JSL_151:
        RET
_JSRT_POW:
        PUSH   CX
        PUSH   DX
        MOV   CX, BX
        MOV   BX, AX
        MOV   AX, 1
_JSL_152:
        OR   CX, CX
        JZ   _JSL_153
        PUSH   DX
        MUL    BX
        POP   DX
        DEC   CX
        JMP   _JSL_152
_JSL_153:
        POP   DX
        POP   CX
        RET
_JSRT_SQRT:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        OR   AX, AX
        JZ   _JSL_155
        MOV   BX, AX
        SHR   AX, 1
        OR   AX, AX
        JZ   _JSL_155O
_JSL_154:
        MOV   CX, AX
        PUSH   BX
        XOR   DX, DX
        MOV   AX, BX
        DIV    CX
        POP   BX
        ADD   AX, CX
        SHR   AX, 1
        CMP   AX, CX
        JB   _JSL_154
        MOV   AX, CX
_JSL_155:
        POP   DX
        POP   CX
        POP   BX
        RET
_JSL_155O:
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
        JZ   _JSL_157
        JS   _JSL_156
        MOV   AX, 1
        JMP   _JSL_157
_JSL_156:
        MOV   AX, 0FFFFh
_JSL_157:
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
        JZ   _JSL_158
        MOV   SP, [_JSX_SAVESP]
        MOV   BP, [_JSX_SAVEBP]
        MOV   BX, [_JSX_HANDLER]
        JMP   BX
_JSL_158:
        PUSH   AX
        LEA   DX, _JS_ERR_UNCAUGHT
        MOV   DI, DX
        XOR   CX, CX
_JSL_159:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_160
        INC   CX
        INC   DI
        JMP   _JSL_159
_JSL_160:
        SUB   DI, CX
        MOV   DX, DI
        MOV   BX, 2
        MOV   AH, 40h
        INT    21h
        POP   AX
        MOV   DI, AX
        XOR   CX, CX
_JSL_161:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _JSL_162
        INC   CX
        INC   DI
        JMP   _JSL_161
_JSL_162:
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
_JSC_Animal  DW  0
_JSK_4  DB  'name',0
_JSK_5  DB  'sound',0
_JSK_8  DB  'sound',0
_JSK_11  DB  'speak',0
_JSC_Dog  DW  OFFSET _JSC_Animal
_JSK_15  DB  'Woof',0
_JSC_Cat  DW  OFFSET _JSC_Animal
_JSK_19  DB  'Meow',0
_JSV_dog  DW  0
_JSK_20  DB  'Rex',0
_JSK_21  DB  'speak',0
_JSV_cat  DW  0
_JSK_22  DB  'Mimi',0
_JSK_23  DB  'speak',0
_JSK_24  DB  'name',0
_JSK_27  DB  'name',0
_JSC_Counter  DW  0
_JSK_33  DB  'count',0
_JSK_36  DB  'count',0
_JSK_37  DB  'count',0
_JSK_38  DB  'increment',0
_JSK_41  DB  'count',0
_JSK_42  DB  'getCount',0
_JSV_c  DW  0
_JSK_43  DB  'increment',0
_JSK_44  DB  'increment',0
_JSK_45  DB  'increment',0
_JSK_46  DB  'getCount',0
_DATA   ENDS

        END   _JSF_main
