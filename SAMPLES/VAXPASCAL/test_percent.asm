; ========================================
; Genere par VAXPAS86 v1.0 (2026-03-07)
; Source : SAMPLES\VAXPASCAL\test_percent.pas
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
; assign Stat
        MOV   WORD PTR [_VXP_STAT], AX
; writeln
        LEA   AX, _VXPK_1
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   AX, WORD PTR [_VXP_STAT]
        CALL   _VXPRT_NUMTOSTR
        MOV   SI, OFFSET _VXPRT_NUMBUF
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
; writeln
        XOR   AX, AX
        CALL   _VXPRT_NUMTOSTR
        MOV   SI, OFFSET _VXPRT_NUMBUF
        CALL   _VXPRT_PRINTSTR
        LEA   AX, _VXPK_2
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
_VXP_CHAN  DW  0
_VXP_STAT  DW  0
_VXPK_1  DB  'Status=',0
_VXPK_2  DB  'Hello',0
_DATA   ENDS

        END     _VXPF_MAIN
