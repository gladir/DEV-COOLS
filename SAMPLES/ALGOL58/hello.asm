; =========================================================
; Genere par AL58C86 v1.0
; Source : SAMPLES/ALGOL58/hello.a58
; =========================================================

        .8086
        .MODEL SMALL
        .STACK 1024

_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME CS:_TEXT, DS:_DATA, SS:STACK

_A58P_Main PROC
        MOV     AX, _DATA
        MOV     DS, AX
        PUSH    BP
        MOV     BP, SP

        MOV    AX, 42
        MOV    [_A58V_x], AX
        MOV    AX, [_A58V_x]
        PUSH    AX
        POP    AX
        ADD    AX, 10
        MOV    [_A58V_y], AX
        MOV    AX, 3
        MOV    [_A58V_z], AX
        MOV    AX, 1
        MOV    [_A58V_b], AX
        MOV    AX, [_A58V_x]
        PUSH    AX
        POP    AX
        CMP    AX, 0
        MOV    AX, 0
        SETG    AL
        TEST    AX, AX
        JZ    _A58L_1
; --- writeln ---
        MOV    SI, OFFSET _A58K_1
        CALL    _A58RT_STRLEN
        MOV    AH, 40h
        MOV    BX, 1
        MOV    DX, SI
        INT    21h
        MOV    SI, OFFSET _A58_CRLF
        MOV    CX, 2
        MOV    AH, 40h
        MOV    BX, 1
        MOV    DX, SI
        INT    21h
        JMP    _A58L_2
_A58L_1:
; --- writeln ---
        MOV    SI, OFFSET _A58K_2
        CALL    _A58RT_STRLEN
        MOV    AH, 40h
        MOV    BX, 1
        MOV    DX, SI
        INT    21h
        MOV    SI, OFFSET _A58_CRLF
        MOV    CX, 2
        MOV    AH, 40h
        MOV    BX, 1
        MOV    DX, SI
        INT    21h
_A58L_2:
        MOV    AX, 1
        MOV    [_A58V_x], AX
        MOV    AX, 1
        MOV    [_A58L_3], AX
        MOV    AX, 10
        MOV    [_A58L_4], AX
        JMP    _A58L_5
_A58L_6:
        MOV    AX, [_A58V_x]
        ADD    AX, [_A58L_3]
        MOV    [_A58V_x], AX
_A58L_5:
        MOV    AX, [_A58V_x]
        CMP    AX, [_A58L_4]
        JG    _A58L_7
        MOV    AX, [_A58V_y]
        PUSH    AX
        MOV    AX, [_A58V_x]
        MOV    BX, AX
        POP    AX
        ADD    AX, BX
        MOV    [_A58V_y], AX
        JMP    _A58L_6
_A58L_7:
        MOV    AX, 0
        MOV    [_A58V_b], AX
        MOV    AX, 1
        MOV    [_A58V_b], AX
        MOV    AX, [_A58V_b]
        TEST    AX, AX
        MOV    AX, 0
        SETE    AL
        MOV    [_A58V_b], AX
        MOV    AX, 0
        MOV    [_A58V_b], AX
        MOV    AX, 0
        MOV    [_A58V_b], AX
        MOV    AX, 32
        MOV    [_A58V_x], AX
        MOV    AX, 5
        MOV    [_A58V_y], AX
        MOV    AX, 2
        MOV    [_A58V_y], AX
; label 1
_A58L_1:
        MOV    AX, [_A58V_a]
        PUSH    AX
        MOV    AX, [_A58V_b]
        MOV    BX, AX
        POP    AX
        CMP    AX, BX
        MOV    AX, 0
        SETG    AL
        TEST    AX, AX
        JZ    _A58L_8
        JMP    _A58L_9
_A58L_8:
_A58L_9:
        MOV    AX, [_A58V_x]
        PUSH    AX
        MOV    AX, 42
        MOV    BX, AX
        POP    AX
; max(a,b)
        CALL    _A58RT_MAX
        MOV    [_A58V_y], AX
; goto fin
        JMP    _A58L_fin
        MOV    AX, 999
        MOV    [_A58V_x], AX
; label fin
_A58L_fin:
; --- writeln ---
        MOV    SI, OFFSET _A58K_3
        CALL    _A58RT_STRLEN
        MOV    AH, 40h
        MOV    BX, 1
        MOV    DX, SI
        INT    21h
        MOV    SI, OFFSET _A58_CRLF
        MOV    CX, 2
        MOV    AH, 40h
        MOV    BX, 1
        MOV    DX, SI
        INT    21h

; =========================================================
;  RUNTIME LIBRARY (TODO 24)
; =========================================================
        JMP    _A58RT_SKIP

; --- _A58RT_STRLEN ---
_A58RT_STRLEN PROC NEAR
        PUSH    SI
        XOR    CX, CX
_A58RI_SL1:
        CMP    BYTE PTR [SI], 0
        JE    _A58RI_SL2
        INC    SI
        INC    CX
        JMP    _A58RI_SL1
_A58RI_SL2:
        POP    SI
        MOV    AX, CX
        RET
_A58RT_STRLEN ENDP

; --- _A58RT_NUMTOSTR ---
_A58RT_NUMTOSTR PROC NEAR
        PUSH    BX
        PUSH    DX
        PUSH    DI
        MOV    DI, OFFSET _A58_STRBUF
        MOV    SI, DI
        TEST    AX, AX
        JGE    _A58RI_NP
        NEG    AX
        MOV    BYTE PTR [DI], 45
        INC    DI
_A58RI_NP:
        XOR    CX, CX
        MOV    BX, 10
_A58RI_ND:
        XOR    DX, DX
        DIV    BX
        ADD    DL, 48
        PUSH    DX
        INC    CX
        TEST    AX, AX
        JNZ    _A58RI_ND
        MOV    BX, CX
_A58RI_NW:
        POP    DX
        MOV    [DI], DL
        INC    DI
        DEC    BX
        JNZ    _A58RI_NW
        MOV    BYTE PTR [DI], 0
        MOV    CX, DI
        SUB    CX, SI
        MOV    SI, OFFSET _A58_STRBUF
        POP    DI
        POP    DX
        POP    BX
        RET
_A58RT_NUMTOSTR ENDP

; --- _A58RT_STRTONUM ---
_A58RT_STRTONUM PROC NEAR
        PUSH    BX
        PUSH    CX
        PUSH    DX
        XOR    AX, AX
        XOR    CX, CX
_A58RI_AW:
        CMP    BYTE PTR [SI], 32
        JNE    _A58RI_AC
        INC    SI
        JMP    _A58RI_AW
_A58RI_AC:
        CMP    BYTE PTR [SI], 45
        JNE    _A58RI_AP
        MOV    CX, 1
        INC    SI
        JMP    _A58RI_AD
_A58RI_AP:
        CMP    BYTE PTR [SI], 43
        JNE    _A58RI_AD
        INC    SI
_A58RI_AD:
        CMP    BYTE PTR [SI], 48
        JB    _A58RI_AF
        CMP    BYTE PTR [SI], 57
        JA    _A58RI_AF
        MOV    BX, 10
        MUL    BX
        XOR    BX, BX
        MOV    BL, [SI]
        SUB    BL, 48
        ADD    AX, BX
        INC    SI
        JMP    _A58RI_AD
_A58RI_AF:
        TEST    CX, CX
        JZ    _A58RI_AR
        NEG    AX
_A58RI_AR:
        POP    DX
        POP    CX
        POP    BX
        RET
_A58RT_STRTONUM ENDP

; --- _A58RT_PRINT ---
_A58RT_PRINT PROC NEAR
        MOV    AH, 40h
        MOV    DX, SI
        INT    21h
        RET
_A58RT_PRINT ENDP

; --- _A58RT_PRINTLN ---
_A58RT_PRINTLN PROC NEAR
        CALL    _A58RT_PRINT
        PUSH    BX
        MOV    SI, OFFSET _A58_CRLF
        MOV    CX, 2
        MOV    AH, 40h
        MOV    DX, SI
        INT    21h
        POP    BX
        RET
_A58RT_PRINTLN ENDP

; --- _A58RT_ABS ---
_A58RT_ABS PROC NEAR
        TEST    AX, AX
        JGE    _A58RI_AB1
        NEG    AX
_A58RI_AB1:
        RET
_A58RT_ABS ENDP

; --- _A58RT_SIGN ---
_A58RT_SIGN PROC NEAR
        TEST    AX, AX
        JZ    _A58RI_SG2
        JG    _A58RI_SG1
        MOV    AX, 0FFFFh
        RET
_A58RI_SG1:
        MOV    AX, 1
_A58RI_SG2:
        RET
_A58RT_SIGN ENDP

; --- _A58RT_POW ---
_A58RT_POW PROC NEAR
        PUSH    CX
        PUSH    DX
        MOV    CX, BX
        MOV    BX, AX
        MOV    AX, 1
        TEST    CX, CX
        JZ    _A58RI_PW2
_A58RI_PW1:
        IMUL    BX
        DEC    CX
        JNZ    _A58RI_PW1
_A58RI_PW2:
        POP    DX
        POP    CX
        RET
_A58RT_POW ENDP

; --- _A58RT_SQRT ---
_A58RT_SQRT PROC NEAR
        PUSH    BX
        PUSH    CX
        PUSH    DX
        TEST    AX, AX
        JLE    _A58RI_SQ3
        CMP    AX, 1
        JE    _A58RI_SQ4
        MOV    BX, AX
        SHR    AX, 1
_A58RI_SQ1:
        MOV    CX, AX
        MOV    AX, BX
        XOR    DX, DX
        DIV    CX
        ADD    AX, CX
        SHR    AX, 1
        CMP    AX, CX
        JB    _A58RI_SQ1
        MOV    AX, CX
        JMP    _A58RI_SQ4
_A58RI_SQ3:
        XOR    AX, AX
_A58RI_SQ4:
        POP    DX
        POP    CX
        POP    BX
        RET
_A58RT_SQRT ENDP

; --- _A58RT_MAX ---
_A58RT_MAX PROC NEAR
        CMP    AX, BX
        JGE    _A58RI_MX1
        MOV    AX, BX
_A58RI_MX1:
        RET
_A58RT_MAX ENDP

; --- _A58RT_MIN ---
_A58RT_MIN PROC NEAR
        CMP    AX, BX
        JLE    _A58RI_MN1
        MOV    AX, BX
_A58RI_MN1:
        RET
_A58RT_MIN ENDP

; --- _A58RT_PANIC ---
_A58RT_PANIC PROC NEAR
        PUSH    SI
        MOV    SI, OFFSET _A58K_PANIC_PFX
        CALL    _A58RT_STRLEN
        MOV    AH, 40h
        MOV    BX, 2
        MOV    DX, SI
        INT    21h
        POP    SI
        CALL    _A58RT_STRLEN
        MOV    AH, 40h
        MOV    BX, 2
        MOV    DX, SI
        INT    21h
        MOV    SI, OFFSET _A58_CRLF
        MOV    CX, 2
        MOV    AH, 40h
        MOV    BX, 2
        MOV    DX, SI
        INT    21h
        MOV    AX, 4C01h
        INT    21h
_A58RT_PANIC ENDP

; --- _A58RT_CHKIDX ---
_A58RT_CHKIDX PROC NEAR
        CMP    AX, BX
        JL    _A58RI_CK1
        CMP    AX, CX
        JG    _A58RI_CK1
        RET
_A58RI_CK1:
        MOV    SI, OFFSET _A58K_PANIC_IDX
        CALL    _A58RT_PANIC
        RET
_A58RT_CHKIDX ENDP

; --- Stubs transcendantaux ---
_A58RT_SIN PROC NEAR
        XOR    AX, AX
        RET
_A58RT_SIN ENDP

_A58RT_COS PROC NEAR
        MOV    AX, 1
        RET
_A58RT_COS ENDP

_A58RT_ARCTAN PROC NEAR
        XOR    AX, AX
        RET
_A58RT_ARCTAN ENDP

_A58RT_LN PROC NEAR
        XOR    AX, AX
        RET
_A58RT_LN ENDP

_A58RT_EXP PROC NEAR
        MOV    AX, 1
        RET
_A58RT_EXP ENDP

_A58RT_SKIP:

_DATA   SEGMENT WORD PUBLIC 'DATA'
_A58_STRBUF        DW      128 DUP(0)
_A58_HEAP        DW      1024 DUP(0)
_A58_HEAPTOP        DW      0
_A58_CRLF        DB      13,10,0
_A58K_TRUE        DB      116,114,117,101,0
_A58K_FALSE        DB      102,97,108,115,101,0
_A58_RDBUF        DW      66 DUP(0)
_A58_CALLER_BP        DW      0
_A58K_PANIC_PFX        DB      82,117,110,116,105,109,101,32,101,114,114,111,114,58,32,0
_A58K_PANIC_IDX        DB      105,110,100,101,120,32,111,117,116,32,111,102,32,98,111,117,110,100,115,0
_A58V_x        DW      0
_A58V_y        DW      0
_A58V_z        DW      0
_A58V_b        DW      0
_A58K_1        DB      72,101,108,108,111,44,32,65,108,103,111,108,32,53,56,33,0
_A58K_2        DB      78,101,103,97,116,105,118,101,0
_A58L_3        DW      0
_A58L_4        DW      0
_A58V_a        DW      0
_A58V_b        DW      0
_A58K_3        DB      70,105,110,32,100,117,32,112,114,111,103,114,97,109,109,101,0
_DATA   ENDS

; --- sortie DOS ---
        MOV    SP, BP
        POP    BP
        MOV    AX, 4C00h
        INT    21h
_A58P_Main ENDP

_TEXT   ENDS

        END     _A58P_Main
