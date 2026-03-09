; ========================================
; Genere par VAXPAS86 v1.0 (2026-03-07)
; Source : SAMPLES\VAXPASCAL\test_ifcase.pas
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
; assign X
        MOV   AX, 10
        MOV   WORD PTR [_VXP_X], AX
; if
        MOV   AX, WORD PTR [_VXP_X]
        PUSH   AX
        MOV   AX, 10
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JNE   _VXPL_1
        INC    AX
_VXPL_1:
        TEST   AX, AX
        JZ   _VXPL_2
; writeln
        LEA   AX, _VXPK_4
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
_VXPL_2:
; assign Y
        MOV   AX, 5
        MOV   WORD PTR [_VXP_Y], AX
; if
        MOV   AX, WORD PTR [_VXP_Y]
        PUSH   AX
        MOV   AX, 10
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JLE   _VXPL_5
        INC    AX
_VXPL_5:
        TEST   AX, AX
        JZ   _VXPL_6
; writeln
        LEA   AX, _VXPK_8
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
        JMP   _VXPL_7
_VXPL_6:
; writeln
        LEA   AX, _VXPK_9
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
_VXPL_7:
; if
        MOV   AX, WORD PTR [_VXP_X]
        PUSH   AX
        MOV   AX, 10
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JNE   _VXPL_10
        INC    AX
_VXPL_10:
        TEST   AX, AX
        JZ   _VXPL_11
; writeln
        LEA   AX, _VXPK_13
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
; assign Y
        MOV   AX, 20
        MOV   WORD PTR [_VXP_Y], AX
        JMP   _VXPL_12
_VXPL_11:
; writeln
        LEA   AX, _VXPK_14
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
; assign Y
        XOR   AX, AX
        MOV   WORD PTR [_VXP_Y], AX
_VXPL_12:
; if
        MOV   AX, WORD PTR [_VXP_X]
        PUSH   AX
        XOR   AX, AX
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JLE   _VXPL_15
        INC    AX
_VXPL_15:
        TEST   AX, AX
        JZ   _VXPL_16
; if
        MOV   AX, WORD PTR [_VXP_Y]
        PUSH   AX
        MOV   AX, 20
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JNE   _VXPL_18
        INC    AX
_VXPL_18:
        TEST   AX, AX
        JZ   _VXPL_19
; writeln
        LEA   AX, _VXPK_21
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
        JMP   _VXPL_20
_VXPL_19:
; writeln
        LEA   AX, _VXPK_22
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
_VXPL_20:
_VXPL_16:
; assign X
        MOV   AX, 2
        MOV   WORD PTR [_VXP_X], AX
; case
        MOV   AX, WORD PTR [_VXP_X]
        PUSH   AX
        MOV   AX, WORD PTR [SP]
        CMP   AX, 1
        JE   _VXPL_25
        JMP   _VXPL_24
_VXPL_25:
; writeln
        LEA   AX, _VXPK_26
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
        JMP   _VXPL_23
_VXPL_24:
        MOV   AX, WORD PTR [SP]
        CMP   AX, 2
        JE   _VXPL_28
        JMP   _VXPL_27
_VXPL_28:
; writeln
        LEA   AX, _VXPK_29
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
        JMP   _VXPL_23
_VXPL_27:
        MOV   AX, WORD PTR [SP]
        CMP   AX, 3
        JE   _VXPL_31
        JMP   _VXPL_30
_VXPL_31:
; writeln
        LEA   AX, _VXPK_32
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
        JMP   _VXPL_23
_VXPL_30:
_VXPL_23:
        POP   AX
; assign X
        MOV   AX, 99
        MOV   WORD PTR [_VXP_X], AX
; case
        MOV   AX, WORD PTR [_VXP_X]
        PUSH   AX
        MOV   AX, WORD PTR [SP]
        CMP   AX, 1
        JE   _VXPL_35
        JMP   _VXPL_34
_VXPL_35:
; writeln
        LEA   AX, _VXPK_36
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
        JMP   _VXPL_33
_VXPL_34:
        MOV   AX, WORD PTR [SP]
        CMP   AX, 2
        JE   _VXPL_38
        JMP   _VXPL_37
_VXPL_38:
; writeln
        LEA   AX, _VXPK_39
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
        JMP   _VXPL_33
_VXPL_37:
; case default
; writeln
        LEA   AX, _VXPK_40
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
_VXPL_33:
        POP   AX
; case
        MOV   AX, WORD PTR [_VXP_X]
        PUSH   AX
        MOV   AX, WORD PTR [SP]
        CMP   AX, 1
        JE   _VXPL_43
        JMP   _VXPL_42
_VXPL_43:
; writeln
        LEA   AX, _VXPK_44
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
        JMP   _VXPL_41
_VXPL_42:
; case default
; writeln
        LEA   AX, _VXPK_45
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
_VXPL_41:
        POP   AX
; assign X
        MOV   AX, 5
        MOV   WORD PTR [_VXP_X], AX
; case
        MOV   AX, WORD PTR [_VXP_X]
        PUSH   AX
        MOV   AX, WORD PTR [SP]
        CMP   AX, 1
        JB   _VXPL_47
        CMP   AX, 3
        JBE   _VXPL_48
        JMP   _VXPL_47
        JMP   _VXPL_47
_VXPL_48:
; writeln
        LEA   AX, _VXPK_49
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
        JMP   _VXPL_46
_VXPL_47:
        MOV   AX, WORD PTR [SP]
        CMP   AX, 4
        JB   _VXPL_50
        CMP   AX, 6
        JBE   _VXPL_51
        JMP   _VXPL_50
        JMP   _VXPL_50
_VXPL_51:
; writeln
        LEA   AX, _VXPK_52
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
        JMP   _VXPL_46
_VXPL_50:
        MOV   AX, WORD PTR [SP]
        CMP   AX, 7
        JB   _VXPL_53
        CMP   AX, 10
        JBE   _VXPL_54
        JMP   _VXPL_53
        JMP   _VXPL_53
_VXPL_54:
; writeln
        LEA   AX, _VXPK_55
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
        JMP   _VXPL_46
_VXPL_53:
_VXPL_46:
        POP   AX
; goto
        JMP   _VXPL_USR_100
; writeln
        LEA   AX, _VXPK_56
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
_VXPL_USR_100:
; writeln
        LEA   AX, _VXPK_57
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
; goto
        JMP   _VXPL_SORTIE
_VXPL_USR_200:
; writeln
        LEA   AX, _VXPK_58
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
_VXPL_SORTIE:
; writeln
        LEA   AX, _VXPK_59
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
; writeln
        LEA   AX, _VXPK_60
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
_VXP_X  DW  0
_VXP_Y  DW  0
_VXP_C  DB  0
_VXPK_4  DB  'IF simple: OK',0
_VXPK_8  DB  'IF/ELSE: FAIL',0
_VXPK_9  DB  'IF/ELSE: OK',0
_VXPK_13  DB  'IF block: OK',0
_VXPK_14  DB  'IF block: FAIL',0
_VXPK_21  DB  'Nested IF: OK',0
_VXPK_22  DB  'Nested IF: FAIL',0
_VXPK_26  DB  'CASE val: FAIL',0
_VXPK_29  DB  'CASE val: OK',0
_VXPK_32  DB  'CASE val: FAIL',0
_VXPK_36  DB  'CASE others: FAIL',0
_VXPK_39  DB  'CASE others: FAIL',0
_VXPK_40  DB  'CASE others: OK',0
_VXPK_44  DB  'CASE otherwise: FAIL',0
_VXPK_45  DB  'CASE otherwise: OK',0
_VXPK_49  DB  'CASE range: FAIL',0
_VXPK_52  DB  'CASE range: OK',0
_VXPK_55  DB  'CASE range: FAIL',0
_VXPK_56  DB  'GOTO: FAIL',0
_VXPK_57  DB  'GOTO numeric: OK',0
_VXPK_58  DB  'GOTO: FAIL',0
_VXPK_59  DB  'GOTO ident: OK',0
_VXPK_60  DB  'Tous les tests TODO 12 OK',0
_DATA   ENDS

        END     _VXPF_MAIN
