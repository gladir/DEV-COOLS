; ========================================
; Genere par VAXPAS86 v1.0 (2026-03-07)
; Source : SAMPLES\VAXPASCAL\test_loops.pas
; ========================================

.MODEL SMALL
.STACK 1024

; --- Segment de code ---
_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME CS:_TEXT, DS:_DATA

; --- Point d entree principal ---
_VXPF_MAIN:
        MOV   AX, _DATA
        MOV   DS, AX
        JMP   _VXPL_MAINBODY

_VXPL_MAINBODY:
; assign S
        XOR   AX, AX
        MOV   WORD PTR [_VXP_S], AX
; for
        MOV   AX, 1
        MOV   WORD PTR [_VXP_I], AX
        MOV   AX, 5
        MOV   WORD PTR [_VXPL_1], AX
_VXPL_2:
        MOV   AX, WORD PTR [_VXP_I]
        CMP   AX, WORD PTR [_VXPL_1]
        JG   _VXPL_3
; assign S
        MOV   AX, WORD PTR [_VXP_S]
        PUSH   AX
        MOV   AX, WORD PTR [_VXP_I]
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   WORD PTR [_VXP_S], AX
_VXPL_4:
        INC   WORD PTR [_VXP_I]
        JMP   _VXPL_2
_VXPL_3:
; writeln
        LEA   AX, _VXPK_5
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
; writeln
        MOV   AX, WORD PTR [_VXP_S]
        CALL   _VXPRT_NUMTOSTR
        MOV   SI, OFFSET _VXPRT_NUMBUF
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
; assign S
        XOR   AX, AX
        MOV   WORD PTR [_VXP_S], AX
; for
        MOV   AX, 5
        MOV   WORD PTR [_VXP_I], AX
        MOV   AX, 1
        MOV   WORD PTR [_VXPL_6], AX
_VXPL_7:
        MOV   AX, WORD PTR [_VXP_I]
        CMP   AX, WORD PTR [_VXPL_6]
        JL   _VXPL_8
; assign S
        MOV   AX, WORD PTR [_VXP_S]
        PUSH   AX
        MOV   AX, WORD PTR [_VXP_I]
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   WORD PTR [_VXP_S], AX
_VXPL_9:
        DEC   WORD PTR [_VXP_I]
        JMP   _VXPL_7
_VXPL_8:
; writeln
        LEA   AX, _VXPK_10
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
; writeln
        MOV   AX, WORD PTR [_VXP_S]
        CALL   _VXPRT_NUMTOSTR
        MOV   SI, OFFSET _VXPRT_NUMBUF
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
; assign S
        XOR   AX, AX
        MOV   WORD PTR [_VXP_S], AX
; for
        MOV   AX, 1
        MOV   WORD PTR [_VXP_I], AX
        MOV   AX, 3
        MOV   WORD PTR [_VXPL_11], AX
_VXPL_12:
        MOV   AX, WORD PTR [_VXP_I]
        CMP   AX, WORD PTR [_VXPL_11]
        JG   _VXPL_13
; assign S
        MOV   AX, WORD PTR [_VXP_S]
        PUSH   AX
        MOV   AX, WORD PTR [_VXP_I]
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   WORD PTR [_VXP_S], AX
; assign S
        MOV   AX, WORD PTR [_VXP_S]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   WORD PTR [_VXP_S], AX
_VXPL_14:
        INC   WORD PTR [_VXP_I]
        JMP   _VXPL_12
_VXPL_13:
; writeln
        LEA   AX, _VXPK_15
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
; writeln
        MOV   AX, WORD PTR [_VXP_S]
        CALL   _VXPRT_NUMTOSTR
        MOV   SI, OFFSET _VXPRT_NUMBUF
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
; assign S
        XOR   AX, AX
        MOV   WORD PTR [_VXP_S], AX
; for
        XOR   AX, AX
        MOV   WORD PTR [_VXP_I], AX
        MOV   AX, 10
        MOV   WORD PTR [_VXPL_16], AX
        MOV   AX, 2
        MOV   WORD PTR [_VXPL_17], AX
_VXPL_18:
        MOV   AX, WORD PTR [_VXP_I]
        CMP   AX, WORD PTR [_VXPL_16]
        JG   _VXPL_19
; assign S
        MOV   AX, WORD PTR [_VXP_S]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   WORD PTR [_VXP_S], AX
_VXPL_20:
        MOV   AX, WORD PTR [_VXP_I]
        ADD   AX, WORD PTR [_VXPL_17]
        MOV   WORD PTR [_VXP_I], AX
        JMP   _VXPL_18
_VXPL_19:
; writeln
        LEA   AX, _VXPK_21
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
; writeln
        MOV   AX, WORD PTR [_VXP_S]
        CALL   _VXPRT_NUMTOSTR
        MOV   SI, OFFSET _VXPRT_NUMBUF
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
; assign I
        XOR   AX, AX
        MOV   WORD PTR [_VXP_I], AX
; assign S
        XOR   AX, AX
        MOV   WORD PTR [_VXP_S], AX
; while
_VXPL_22:
        MOV   AX, WORD PTR [_VXP_I]
        PUSH   AX
        MOV   AX, 5
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JGE   _VXPL_24
        INC    AX
_VXPL_24:
        TEST   AX, AX
        JZ   _VXPL_23
; assign I
        MOV   AX, WORD PTR [_VXP_I]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   WORD PTR [_VXP_I], AX
; assign S
        MOV   AX, WORD PTR [_VXP_S]
        PUSH   AX
        MOV   AX, WORD PTR [_VXP_I]
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   WORD PTR [_VXP_S], AX
        JMP   _VXPL_22
_VXPL_23:
; writeln
        LEA   AX, _VXPK_25
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
; writeln
        MOV   AX, WORD PTR [_VXP_S]
        CALL   _VXPRT_NUMTOSTR
        MOV   SI, OFFSET _VXPRT_NUMBUF
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
; assign I
        XOR   AX, AX
        MOV   WORD PTR [_VXP_I], AX
; assign S
        XOR   AX, AX
        MOV   WORD PTR [_VXP_S], AX
; repeat
_VXPL_26:
; assign I
        MOV   AX, WORD PTR [_VXP_I]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   WORD PTR [_VXP_I], AX
; assign S
        MOV   AX, WORD PTR [_VXP_S]
        PUSH   AX
        MOV   AX, WORD PTR [_VXP_I]
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   WORD PTR [_VXP_S], AX
        MOV   AX, WORD PTR [_VXP_I]
        PUSH   AX
        MOV   AX, 5
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JL   _VXPL_28
        INC    AX
_VXPL_28:
        TEST   AX, AX
        JZ   _VXPL_26
_VXPL_27:
; writeln
        LEA   AX, _VXPK_29
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
; writeln
        MOV   AX, WORD PTR [_VXP_S]
        CALL   _VXPRT_NUMTOSTR
        MOV   SI, OFFSET _VXPRT_NUMBUF
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
; assign I
        XOR   AX, AX
        MOV   WORD PTR [_VXP_I], AX
; assign S
        XOR   AX, AX
        MOV   WORD PTR [_VXP_S], AX
; loop
_VXPL_30:
; assign I
        MOV   AX, WORD PTR [_VXP_I]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   WORD PTR [_VXP_I], AX
; assign S
        MOV   AX, WORD PTR [_VXP_S]
        PUSH   AX
        MOV   AX, WORD PTR [_VXP_I]
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   WORD PTR [_VXP_S], AX
; exit if
        MOV   AX, WORD PTR [_VXP_I]
        PUSH   AX
        MOV   AX, 5
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JL   _VXPL_32
        INC    AX
_VXPL_32:
        TEST   AX, AX
        JNZ   _VXPL_31
        JMP   _VXPL_30
_VXPL_31:
; writeln
        LEA   AX, _VXPK_33
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
; writeln
        MOV   AX, WORD PTR [_VXP_S]
        CALL   _VXPRT_NUMTOSTR
        MOV   SI, OFFSET _VXPRT_NUMBUF
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
; assign S
        XOR   AX, AX
        MOV   WORD PTR [_VXP_S], AX
; for
        MOV   AX, 1
        MOV   WORD PTR [_VXP_I], AX
        MOV   AX, 100
        MOV   WORD PTR [_VXPL_34], AX
_VXPL_35:
        MOV   AX, WORD PTR [_VXP_I]
        CMP   AX, WORD PTR [_VXPL_34]
        JG   _VXPL_36
; if
        MOV   AX, WORD PTR [_VXP_I]
        PUSH   AX
        MOV   AX, 3
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JLE   _VXPL_38
        INC    AX
_VXPL_38:
        TEST   AX, AX
        JZ   _VXPL_39
        JMP   _VXPL_36
_VXPL_39:
; assign S
        MOV   AX, WORD PTR [_VXP_S]
        PUSH   AX
        MOV   AX, WORD PTR [_VXP_I]
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   WORD PTR [_VXP_S], AX
_VXPL_37:
        INC   WORD PTR [_VXP_I]
        JMP   _VXPL_35
_VXPL_36:
; writeln
        LEA   AX, _VXPK_41
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
; writeln
        MOV   AX, WORD PTR [_VXP_S]
        CALL   _VXPRT_NUMTOSTR
        MOV   SI, OFFSET _VXPRT_NUMBUF
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
; assign S
        XOR   AX, AX
        MOV   WORD PTR [_VXP_S], AX
; for
        MOV   AX, 1
        MOV   WORD PTR [_VXP_I], AX
        MOV   AX, 5
        MOV   WORD PTR [_VXPL_42], AX
_VXPL_43:
        MOV   AX, WORD PTR [_VXP_I]
        CMP   AX, WORD PTR [_VXPL_42]
        JG   _VXPL_44
; if
        MOV   AX, WORD PTR [_VXP_I]
        PUSH   AX
        MOV   AX, 3
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JNE   _VXPL_46
        INC    AX
_VXPL_46:
        TEST   AX, AX
        JZ   _VXPL_47
        JMP   _VXPL_45
_VXPL_47:
; assign S
        MOV   AX, WORD PTR [_VXP_S]
        PUSH   AX
        MOV   AX, WORD PTR [_VXP_I]
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   WORD PTR [_VXP_S], AX
_VXPL_45:
        INC   WORD PTR [_VXP_I]
        JMP   _VXPL_43
_VXPL_44:
; writeln
        LEA   AX, _VXPK_49
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
; writeln
        MOV   AX, WORD PTR [_VXP_S]
        CALL   _VXPRT_NUMTOSTR
        MOV   SI, OFFSET _VXPRT_NUMBUF
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
; writeln
        LEA   AX, _VXPK_50
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR

; --- Sortie programme (DOS INT 21h) ---
        MOV   AH, 4Ch
        MOV   AL, 0
        INT    21h

; === Routines runtime ===

; PRINTSTR : affiche chaine ASCIIZ (SI -> chaine)
_VXPRT_PRINTSTR:
_VXPRT_PRINTSTR_LP:
        LODSB
        CMP   AL, 0
        JE   _VXPRT_PRINTSTR_DONE
        MOV   DL, AL
        MOV   AH, 02h
        INT    21h
        JMP   _VXPRT_PRINTSTR_LP
_VXPRT_PRINTSTR_DONE:
        RET

; NUMTOSTR : convertit AX (signe) -> NUMBUF (ASCIIZ)
_VXPRT_NUMTOSTR:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        PUSH   DI
        MOV   DI, OFFSET _VXPRT_NUMBUF
        MOV   CX, 0
        CMP   AX, 0
        JGE   _VXPRT_NTS_POS
        MOV   BYTE PTR [DI], '-'
        INC    DI
        NEG    AX
_VXPRT_NTS_POS:
        MOV   BX, 10
_VXPRT_NTS_DIV:
        XOR   DX, DX
        DIV   BX
        ADD   DL, '0'
        PUSH   DX
        INC    CX
        CMP   AX, 0
        JNE   _VXPRT_NTS_DIV
_VXPRT_NTS_POP:
        POP   AX
        MOV   [DI], AL
        INC    DI
        LOOP   _VXPRT_NTS_POP
        MOV   BYTE PTR [DI], 0
        POP   DI
        POP   DX
        POP   CX
        POP   BX
        RET

; STRLEN : longueur chaine ASCIIZ (SI -> AX)
_VXPRT_STRLEN:
        PUSH   SI
        XOR   AX, AX
_VXPRT_STRLEN_LP:
        CMP   BYTE PTR [SI], 0
        JE   _VXPRT_STRLEN_DONE
        INC    AX
        INC    SI
        JMP   _VXPRT_STRLEN_LP
_VXPRT_STRLEN_DONE:
        POP   SI
        RET

; CONCAT : SI + DI -> AX = ptr STRBUF
_VXPRT_CONCAT:
        PUSH   BX
        PUSH   CX
        MOV   BX, OFFSET _VXPRT_STRBUF
_VXPRT_CONCAT_S1:
        MOV   AL, [SI]
        CMP   AL, 0
        JE   _VXPRT_CONCAT_S2
        MOV   [BX], AL
        INC    SI
        INC    BX
        JMP   _VXPRT_CONCAT_S1
_VXPRT_CONCAT_S2:
        MOV   AL, [DI]
        CMP   AL, 0
        JE   _VXPRT_CONCAT_END
        MOV   [BX], AL
        INC    DI
        INC    BX
        JMP   _VXPRT_CONCAT_S2
_VXPRT_CONCAT_END:
        MOV   BYTE PTR [BX], 0
        LEA   AX, _VXPRT_STRBUF
        POP   CX
        POP   BX
        RET

; STRCMP : SI vs DI -> AX (signe)
_VXPRT_STRCMP:
_VXPRT_STRCMP_LP:
        MOV   AL, [SI]
        MOV   AH, [DI]
        CMP   AL, AH
        JNE   _VXPRT_STRCMP_DIFF
        CMP   AL, 0
        JE   _VXPRT_STRCMP_EQ
        INC    SI
        INC    DI
        JMP   _VXPRT_STRCMP_LP
_VXPRT_STRCMP_EQ:
        XOR   AX, AX
        RET
_VXPRT_STRCMP_DIFF:
        XOR   AH, AH
        MOV   BL, [DI]
        XOR   BH, BH
        SUB   AX, BX
        RET

; CHR : AL -> AX = ptr chaine 1 car
_VXPRT_CHR:
        MOV   BYTE PTR [_VXPRT_CHRBUF], AL
        MOV   BYTE PTR [_VXPRT_CHRBUF+1], 0
        LEA   AX, _VXPRT_CHRBUF
        RET

; READCHAR : lire un caractere -> AL
_VXPRT_READCHAR:
        MOV   AH, 01h
        INT    21h
        RET

; READNUM : lire entier decimal -> AX
_VXPRT_READNUM:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        XOR   BX, BX
        XOR   CX, CX
_VXPRT_RN_LP:
        MOV   AH, 01h
        INT    21h
        CMP   AL, 13
        JE   _VXPRT_RN_DONE
        CMP   AL, '-'
        JNE   _VXPRT_RN_DIG
        MOV   CX, 1
        JMP   _VXPRT_RN_LP
_VXPRT_RN_DIG:
        CMP   AL, '0'
        JB   _VXPRT_RN_DONE
        CMP   AL, '9'
        JA   _VXPRT_RN_DONE
        SUB   AL, '0'
        XOR   AH, AH
        PUSH   AX
        MOV   AX, BX
        MOV   DX, 10
        MUL   DX
        MOV   BX, AX
        POP   AX
        ADD   BX, AX
        JMP   _VXPRT_RN_LP
_VXPRT_RN_DONE:
        MOV   AX, BX
        CMP   CX, 0
        JE   _VXPRT_RN_END
        NEG    AX
_VXPRT_RN_END:
        POP   DX
        POP   CX
        POP   BX
        RET

_TEXT   ENDS
_DATA   SEGMENT WORD PUBLIC 'DATA'
; --- Buffers internes ---
_VXPRT_CRLF    DB  13,10,0
_VXPRT_STRBUF  DB  512 DUP(0)
_VXPRT_CHRBUF  DB  2 DUP(0)
_VXPRT_NUMBUF  DB  12 DUP(0)
_VXPRT_TRUE_S  DB  'TRUE',0
_VXPRT_FALSE_S DB  'FALSE',0
_VXPRT_HEAP    DB  4096 DUP(0)
_VXPRT_HEAPTOP DW  OFFSET _VXPRT_HEAP
_VXPRT_SEED    DW  1

; --- Donnees du programme ---
_VXP_I  DW  0
_VXP_S  DW  0
_VXPL_1  DW  0
_VXPK_5  DB  'FOR TO sum 1..5 = ',0
_VXPL_6  DW  0
_VXPK_10  DB  'FOR DOWNTO sum 5..1 = ',0
_VXPL_11  DW  0
_VXPK_15  DB  'FOR block sum = ',0
_VXPL_16  DW  0
_VXPL_17  DW  0
_VXPK_21  DB  'FOR BY 2 count = ',0
_VXPK_25  DB  'WHILE sum = ',0
_VXPK_29  DB  'REPEAT sum = ',0
_VXPK_33  DB  'LOOP sum = ',0
_VXPL_34  DW  0
_VXPK_41  DB  'FOR+BREAK sum 1..3 = ',0
_VXPL_42  DW  0
_VXPK_49  DB  'FOR+CONTINUE skip 3 = ',0
_VXPK_50  DB  'Tous les tests TODO 13 OK',0
_DATA   ENDS

        END     _VXPF_MAIN
