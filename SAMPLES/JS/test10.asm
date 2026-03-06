; Genere par JS86 v1.0 - SAMPLES\JS\test10.js

        .MODEL SMALL
        .STACK 1024

_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME  CS:_TEXT, DS:_DATA, SS:STACK

; --- debut du code genere ---

        MOV   AX, 42
        MOV   [_JSV_a], AX
        LEA   AX, _JSK_1
        MOV   [_JSV_b], AX
        MOV   AX, 1
        MOV   [_JSV_c], AX
        MOV   AX, 0
        MOV   [_JSV_d], AX
        XOR   AX, AX
        MOV   AX, 0
        MOV   [_JSV_e], AX
        XOR   AX, AX
        MOV   AX, 0
        MOV   [_JSV_f], AX
        MOV   AX, -5
        MOV   [_JSV_g], AX
        MOV   AX, 1
        MOV   [_JSV_h], AX
        MOV   AX, -1
        MOV   [_JSV_i], AX
        XOR   AX, AX
        MOV   [_JSV_j], AX
        MOV   AX, [_JSV_a]
        CALL   _JSRT_TYPEOF
        MOV   [_JSV_k], AX
        MOV   AX, 0
        XOR   AX, AX
        MOV   [_JSV_l], AX
        MOV   AX, [_JSV_a]
        MOV   AX, 1
        MOV   [_JSV_m], AX
        LEA   AX, _JSA_2
        MOV   [_JSV_arr], AX
        LEA   AX, _JSA_3
        MOV   [_JSV_empty], AX
        LEA   AX, _JSO_4
        MOV   [_JSV_obj], AX
        MOV   AX, 10
        MOV   [_JSV_n], AX
        MOV   AX, [_JSV_n]
        INC    AX
        MOV   [_JSV_n], AX
        MOV   AX, [_JSV_n]
        DEC    AX
        MOV   [_JSV_n], AX
        MOV   AX, [_JSV_n]
        PUSH   AX
        INC    AX
        MOV   [_JSV_n], AX
        POP   AX
        MOV   [_JSV_o], AX
        MOV   AX, [_JSV_n]
        PUSH   AX
        DEC    AX
        MOV   [_JSV_n], AX
        POP   AX
        MOV   [_JSV_p], AX
        MOV   AX, 9
        MOV   [_JSV_q], AX

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
        JZ   _JSL_7
        DEC   BX
        MOV   [SI], BX
        MOV   DI, BX
        SHL   DI, 1
        ADD   DI, 2
        ADD   DI, SI
        MOV   AX, [DI]
        RET
_JSL_7:
        XOR   AX, AX
        RET
_JSRT_ARRSHIFT:
        MOV   CX, [SI]
        OR   CX, CX
        JZ   _JSL_8
        MOV   AX, [SI+2]
        PUSH   AX
        DEC   CX
        MOV   [SI], CX
        LEA   DI, [SI+2]
        LEA   BX, [SI+4]
_JSL_9:
        OR   CX, CX
        JZ   _JSL_10
        MOV   AX, [BX]
        MOV   [DI], AX
        ADD   DI, 2
        ADD   BX, 2
        DEC   CX
        JMP   _JSL_9
_JSL_10:
        POP   AX
        RET
_JSL_8:
        XOR   AX, AX
        RET
_JSRT_ARRUNSHIFT:
        PUSH   AX
        MOV   CX, [SI]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        ADD   DI, 2
_JSL_11:
        OR   CX, CX
        JZ   _JSL_12
        MOV   AX, [DI-2]
        MOV   [DI], AX
        SUB   DI, 2
        DEC   CX
        JMP   _JSL_11
_JSL_12:
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
_JSL_13:
        OR   CX, CX
        JZ   _JSL_14
        CMP   [SI], BX
        JE   _JSL_15
        ADD   SI, 2
        INC   DX
        DEC   CX
        JMP   _JSL_13
_JSL_15:
        MOV   AX, DX
        RET
_JSL_14:
        MOV   AX, -1
        RET
_JSRT_ARRREV:
        MOV   CX, [SI]
        CMP   CX, 2
        JL   _JSL_16
        LEA   BX, [SI+2]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        SUB   DI, 2
_JSL_17:
        CMP   BX, DI
        JGE   _JSL_18
        MOV   AX, [BX]
        MOV   DX, [DI]
        MOV   [BX], DX
        MOV   [DI], AX
        ADD   BX, 2
        SUB   DI, 2
        JMP   _JSL_17
_JSL_18:
_JSL_16:
        MOV   AX, SI
        RET
_JSRT_ARRSORT:
        PUSH   SI
_JSL_19:
        XOR   DX, DX
        MOV   CX, [SI]
        DEC   CX
        CMP   CX, 0
        JLE   _JSL_22
        LEA   BX, [SI+2]
_JSL_20:
        MOV   AX, [BX]
        CMP   AX, [BX+2]
        JLE   _JSL_21
        MOV   DI, [BX+2]
        MOV   [BX], DI
        MOV   [BX+2], AX
        MOV   DX, 1
_JSL_21:
        ADD   BX, 2
        DEC   CX
        OR   CX, CX
        JNZ   _JSL_20
        OR   DX, DX
        JNZ   _JSL_19
_JSL_22:
        POP   AX
        RET

; --- runtime object routines (TODO 16) ---
_JSRT_STRCMP:
        PUSH   SI
        PUSH   DI
_JSL_23:
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_25
        OR   AL, AL
        JZ   _JSL_24
        INC   SI
        INC   DI
        JMP   _JSL_23
_JSL_24:
        XOR   AX, AX
        POP   DI
        POP   SI
        RET
_JSL_25:
        MOV   AX, 1
        POP   DI
        POP   SI
        RET
_JSRT_OBJGET:
        PUSH   CX
        PUSH   BX
        MOV   CX, [BX]
        ADD   BX, 2
_JSL_26:
        OR   CX, CX
        JZ   _JSL_28
        PUSH   CX
        PUSH   BX
        PUSH   DI
        MOV   SI, [BX]
        CALL   _JSRT_STRCMP
        POP   DI
        POP   BX
        POP   CX
        OR   AX, AX
        JZ   _JSL_27
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_26
_JSL_27:
        MOV   AX, [BX+2]
        POP   BX
        POP   CX
        RET
_JSL_28:
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
_JSL_29:
        OR   CX, CX
        JZ   _JSL_31
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
        JZ   _JSL_30
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_29
_JSL_30:
        MOV   [BX+2], DX
        MOV   AX, DX
        POP   BX
        POP   CX
        RET
_JSL_31:
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
_JSL_32:
        OR   CX, CX
        JZ   _JSL_33
        MOV   AX, [SI]
        MOV   [DI], AX
        ADD   SI, 4
        ADD   DI, 2
        DEC   CX
        JMP   _JSL_32
_JSL_33:
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
_JSL_34:
        OR   CX, CX
        JZ   _JSL_35
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
        JMP   _JSL_34
_JSL_35:
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
_JSV_a  DW  0
_JSV_b  DW  0
_JSK_1  DB  'hello',0
_JSV_c  DW  0
_JSV_d  DW  0
_JSV_e  DW  0
_JSV_f  DW  0
_JSV_g  DW  0
_JSV_h  DW  0
_JSV_i  DW  0
_JSV_j  DW  0
_JSV_k  DW  0
_JSV_l  DW  0
_JSV_m  DW  0
_JSV_arr  DW  0
_JSA_2  DW  5   ; tableau (5 elem)
_JSA_2_E0  DW  1
_JSA_2_E1  DW  2
_JSA_2_E2  DW  3
_JSA_2_E3  DW  4
_JSA_2_E4  DW  5
_JSV_empty  DW  0
_JSA_3  DW  0   ; tableau (0 elem)
_JSV_obj  DW  0
_JSK_5  DB  'x',0
_JSK_6  DB  'y',0
_JSO_4  DW  2   ; objet (2 props)
_JSO_4_K0  DW  OFFSET _JSK_5
_JSO_4_V0  DW  10
_JSO_4_K1  DW  OFFSET _JSK_6
_JSO_4_V1  DW  20
_JSO_4_K2  DW  0
_JSO_4_V2  DW  0
_JSO_4_K3  DW  0
_JSO_4_V3  DW  0
_JSO_4_K4  DW  0
_JSO_4_V4  DW  0
_JSO_4_K5  DW  0
_JSO_4_V5  DW  0
_JSV_n  DW  0
_JSV_o  DW  0
_JSV_p  DW  0
_JSV_q  DW  0
_DATA   ENDS

        END
