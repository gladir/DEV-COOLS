; Genere par JS86 v1.0 - SAMPLES\JS\test11.js

        .MODEL SMALL
        .STACK 1024

_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME  CS:_TEXT, DS:_DATA, SS:STACK

; --- debut du code genere ---

        MOV   AX, 10
        MOV   [_JSV_a], AX
        MOV   AX, 3
        MOV   [_JSV_b], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, [_JSV_b]
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [_JSV_sum], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, [_JSV_b]
        MOV   BX, AX
        POP   AX
        SUB   AX, BX
        MOV   [_JSV_diff], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, [_JSV_b]
        MOV   BX, AX
        POP   AX
        IMUL   BX
        MOV   [_JSV_prod], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, [_JSV_b]
        MOV   BX, AX
        POP   AX
        CMP   BX, 0
        JE   _JSL_1
        CWD
        IDIV   BX
        JMP   _JSL_2
_JSL_1:
        XOR   AX, AX
_JSL_2:
        MOV   [_JSV_quot], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, [_JSV_b]
        MOV   BX, AX
        POP   AX
        CMP   BX, 0
        JE   _JSL_3
        CWD
        IDIV   BX
        MOV   AX, DX
        JMP   _JSL_4
_JSL_3:
        XOR   AX, AX
_JSL_4:
        MOV   [_JSV_rem], AX
        MOV   AX, 5
        MOV   [_JSV_c1], AX
        MOV   AX, 6
        MOV   [_JSV_c2], AX
        MOV   AX, 21
        MOV   [_JSV_c3], AX
        MOV   AX, 4
        MOV   [_JSV_c4], AX
        MOV   AX, 2
        MOV   [_JSV_c5], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, [_JSV_b]
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JNE   _JSL_5
        INC    AX
_JSL_5:
        MOV   [_JSV_eq], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, [_JSV_b]
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JE   _JSL_6
        INC    AX
_JSL_6:
        MOV   [_JSV_ne], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, [_JSV_b]
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JGE   _JSL_7
        INC    AX
_JSL_7:
        MOV   [_JSV_lt], AX
        MOV   AX, [_JSV_b]
        PUSH   AX
        MOV   AX, [_JSV_b]
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JG   _JSL_8
        INC    AX
_JSL_8:
        MOV   [_JSV_le], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, [_JSV_b]
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JLE   _JSL_9
        INC    AX
_JSL_9:
        MOV   [_JSV_gt], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, [_JSV_a]
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JL   _JSL_10
        INC    AX
_JSL_10:
        MOV   [_JSV_ge], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, 10
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JNE   _JSL_11
        INC    AX
_JSL_11:
        MOV   [_JSV_seq], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, 5
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JE   _JSL_12
        INC    AX
_JSL_12:
        MOV   [_JSV_sne], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, [_JSV_b]
        MOV   BX, AX
        POP   AX
        AND   AX, BX
        MOV   [_JSV_band], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, [_JSV_b]
        MOV   BX, AX
        POP   AX
        OR   AX, BX
        MOV   [_JSV_bor], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, [_JSV_b]
        MOV   BX, AX
        POP   AX
        XOR   AX, BX
        MOV   [_JSV_bxor], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        MOV   CL, BL
        SAL   AX, CL
        MOV   [_JSV_shl], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        MOV   CL, BL
        SAR   AX, CL
        MOV   [_JSV_shr], AX
        MOV   AX, 5
        MOV   [_JSV_x], AX
        MOV   AX, 0
        MOV   [_JSV_y], AX
        MOV   AX, [_JSV_x]
        OR   AX, AX
        JZ   _JSL_13
        MOV   AX, 42
_JSL_13:
        MOV   [_JSV_and1], AX
        MOV   AX, [_JSV_y]
        OR   AX, AX
        JNZ   _JSL_14
        MOV   AX, 99
_JSL_14:
        MOV   [_JSV_or1], AX
        MOV   AX, [_JSV_y]
        OR   AX, AX
        JZ   _JSL_15
        MOV   AX, 42
_JSL_15:
        MOV   [_JSV_and2], AX
        MOV   AX, [_JSV_x]
        OR   AX, AX
        JNZ   _JSL_16
        MOV   AX, 99
_JSL_16:
        MOV   [_JSV_or2], AX
        MOV   AX, 0
        MOV   [_JSV_n], AX
        MOV   AX, [_JSV_n]
        CMP   AX, 0
        JNE   _JSL_17
        MOV   AX, 7
_JSL_17:
        MOV   [_JSV_nul], AX
        MOV   AX, [_JSV_x]
        OR   AX, AX
        JZ   _JSL_18
        MOV   AX, 100
        JMP   _JSL_19
_JSL_18:
        MOV   AX, 200
_JSL_19:
        MOV   [_JSV_t1], AX
        MOV   AX, [_JSV_y]
        OR   AX, AX
        JZ   _JSL_20
        MOV   AX, 100
        JMP   _JSL_21
_JSL_20:
        MOV   AX, 200
_JSL_21:
        MOV   [_JSV_t2], AX
        MOV   AX, 11
        MOV   [_JSV_t3], AX
        MOV   AX, 22
        MOV   [_JSV_t4], AX
        MOV   AX, 3
        MOV   [_JSV_v], AX
        MOV   AX, [_JSV_a]
        MOV   BX, AX
        MOV   AX, 5
        ADD   AX, BX
        MOV   [_JSV_m1], AX
        MOV   AX, [_JSV_a]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        SUB   AX, BX
        MOV   [_JSV_m2], AX
        MOV   AX, [_JSV_b]
        MOV   BX, AX
        MOV   AX, 2
        IMUL   BX
        MOV   [_JSV_m3], AX
        LEA   AX, _JSK_22
        MOV   [_JSV_s1], AX
        LEA   AX, _JSK_23
        MOV   [_JSV_s2], AX
        MOV   AX, [_JSV_s1]
        PUSH   AX
        MOV   AX, [_JSV_s2]
        MOV   BX, AX
        POP   AX
        CALL   _JSRT_CONCAT
        MOV   [_JSV_s3], AX

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
        JZ   _JSL_24
        DEC   BX
        MOV   [SI], BX
        MOV   DI, BX
        SHL   DI, 1
        ADD   DI, 2
        ADD   DI, SI
        MOV   AX, [DI]
        RET
_JSL_24:
        XOR   AX, AX
        RET
_JSRT_ARRSHIFT:
        MOV   CX, [SI]
        OR   CX, CX
        JZ   _JSL_25
        MOV   AX, [SI+2]
        PUSH   AX
        DEC   CX
        MOV   [SI], CX
        LEA   DI, [SI+2]
        LEA   BX, [SI+4]
_JSL_26:
        OR   CX, CX
        JZ   _JSL_27
        MOV   AX, [BX]
        MOV   [DI], AX
        ADD   DI, 2
        ADD   BX, 2
        DEC   CX
        JMP   _JSL_26
_JSL_27:
        POP   AX
        RET
_JSL_25:
        XOR   AX, AX
        RET
_JSRT_ARRUNSHIFT:
        PUSH   AX
        MOV   CX, [SI]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        ADD   DI, 2
_JSL_28:
        OR   CX, CX
        JZ   _JSL_29
        MOV   AX, [DI-2]
        MOV   [DI], AX
        SUB   DI, 2
        DEC   CX
        JMP   _JSL_28
_JSL_29:
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
_JSL_30:
        OR   CX, CX
        JZ   _JSL_31
        CMP   [SI], BX
        JE   _JSL_32
        ADD   SI, 2
        INC   DX
        DEC   CX
        JMP   _JSL_30
_JSL_32:
        MOV   AX, DX
        RET
_JSL_31:
        MOV   AX, -1
        RET
_JSRT_ARRREV:
        MOV   CX, [SI]
        CMP   CX, 2
        JL   _JSL_33
        LEA   BX, [SI+2]
        MOV   DI, CX
        SHL   DI, 1
        ADD   DI, SI
        SUB   DI, 2
_JSL_34:
        CMP   BX, DI
        JGE   _JSL_35
        MOV   AX, [BX]
        MOV   DX, [DI]
        MOV   [BX], DX
        MOV   [DI], AX
        ADD   BX, 2
        SUB   DI, 2
        JMP   _JSL_34
_JSL_35:
_JSL_33:
        MOV   AX, SI
        RET
_JSRT_ARRSORT:
        PUSH   SI
_JSL_36:
        XOR   DX, DX
        MOV   CX, [SI]
        DEC   CX
        CMP   CX, 0
        JLE   _JSL_39
        LEA   BX, [SI+2]
_JSL_37:
        MOV   AX, [BX]
        CMP   AX, [BX+2]
        JLE   _JSL_38
        MOV   DI, [BX+2]
        MOV   [BX], DI
        MOV   [BX+2], AX
        MOV   DX, 1
_JSL_38:
        ADD   BX, 2
        DEC   CX
        OR   CX, CX
        JNZ   _JSL_37
        OR   DX, DX
        JNZ   _JSL_36
_JSL_39:
        POP   AX
        RET

; --- runtime object routines (TODO 16) ---
_JSRT_STRCMP:
        PUSH   SI
        PUSH   DI
_JSL_40:
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _JSL_42
        OR   AL, AL
        JZ   _JSL_41
        INC   SI
        INC   DI
        JMP   _JSL_40
_JSL_41:
        XOR   AX, AX
        POP   DI
        POP   SI
        RET
_JSL_42:
        MOV   AX, 1
        POP   DI
        POP   SI
        RET
_JSRT_OBJGET:
        PUSH   CX
        PUSH   BX
        MOV   CX, [BX]
        ADD   BX, 2
_JSL_43:
        OR   CX, CX
        JZ   _JSL_45
        PUSH   CX
        PUSH   BX
        PUSH   DI
        MOV   SI, [BX]
        CALL   _JSRT_STRCMP
        POP   DI
        POP   BX
        POP   CX
        OR   AX, AX
        JZ   _JSL_44
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_43
_JSL_44:
        MOV   AX, [BX+2]
        POP   BX
        POP   CX
        RET
_JSL_45:
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
_JSL_46:
        OR   CX, CX
        JZ   _JSL_48
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
        JZ   _JSL_47
        ADD   BX, 4
        DEC   CX
        JMP   _JSL_46
_JSL_47:
        MOV   [BX+2], DX
        MOV   AX, DX
        POP   BX
        POP   CX
        RET
_JSL_48:
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
_JSL_49:
        OR   CX, CX
        JZ   _JSL_50
        MOV   AX, [SI]
        MOV   [DI], AX
        ADD   SI, 4
        ADD   DI, 2
        DEC   CX
        JMP   _JSL_49
_JSL_50:
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
_JSL_51:
        OR   CX, CX
        JZ   _JSL_52
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
        JMP   _JSL_51
_JSL_52:
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
_JSV_sum  DW  0
_JSV_diff  DW  0
_JSV_prod  DW  0
_JSV_quot  DW  0
_JSV_rem  DW  0
_JSV_c1  DW  0
_JSV_c2  DW  0
_JSV_c3  DW  0
_JSV_c4  DW  0
_JSV_c5  DW  0
_JSV_eq  DW  0
_JSV_ne  DW  0
_JSV_lt  DW  0
_JSV_le  DW  0
_JSV_gt  DW  0
_JSV_ge  DW  0
_JSV_seq  DW  0
_JSV_sne  DW  0
_JSV_band  DW  0
_JSV_bor  DW  0
_JSV_bxor  DW  0
_JSV_shl  DW  0
_JSV_shr  DW  0
_JSV_x  DW  0
_JSV_y  DW  0
_JSV_and1  DW  0
_JSV_or1  DW  0
_JSV_and2  DW  0
_JSV_or2  DW  0
_JSV_n  DW  0
_JSV_nul  DW  0
_JSV_t1  DW  0
_JSV_t2  DW  0
_JSV_t3  DW  0
_JSV_t4  DW  0
_JSV_v  DW  0
_JSV_m1  DW  0
_JSV_m2  DW  0
_JSV_m3  DW  0
_JSV_s1  DW  0
_JSK_22  DB  'hello',0
_JSV_s2  DW  0
_JSK_23  DB  'world',0
_JSV_s3  DW  0
_DATA   ENDS

        END
