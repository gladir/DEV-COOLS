; ========================================
; Genere par VAXPAS86 v1.0 (2026-03-07)
; Source : SAMPLES\VAXPASCAL\test_funcproc.pas
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


; --- SayHello ---
_VXPF_SAYHELLO   PROC NEAR
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        PUSH   DI
; writeln
        LEA   AX, _VXPK_2
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
_VXPL_1:
        POP   DI
        POP   SI
        MOV   SP, BP
        POP   BP
        RET
_VXPF_SAYHELLO   ENDP


; --- PrintVal ---
_VXPF_PRINTVAL   PROC NEAR
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        PUSH   DI
; writeln
        MOV   AX, WORD PTR [BP+4]
        CALL   _VXPRT_NUMTOSTR
        MOV   SI, OFFSET _VXPRT_NUMBUF
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
_VXPL_3:
        POP   DI
        POP   SI
        MOV   SP, BP
        POP   BP
        RET   2
_VXPF_PRINTVAL   ENDP

_VXPL_MAINBODY:
_VXPL_N:

; --- Triple ---
_VXPF_TRIPLE   PROC NEAR
        PUSH   BP
        MOV   BP, SP
        SUB   SP, 2
        PUSH   SI
        PUSH   DI
        MOV   WORD PTR [BP-2], 0
; assign retval result
        MOV   AX, WORD PTR [BP+4]
        PUSH   AX
        MOV   AX, WORD PTR [BP+4]
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        PUSH   AX
        MOV   AX, WORD PTR [BP+4]
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   WORD PTR [BP-2], AX
_VXPL_4:
        MOV   AX, WORD PTR [BP-2]
        POP   DI
        POP   SI
        MOV   SP, BP
        POP   BP
        RET   2
_VXPF_TRIPLE   ENDP


; --- AddPrint ---
_VXPF_ADDPRINT   PROC NEAR
        PUSH   BP
        MOV   BP, SP
        SUB   SP, 2
        PUSH   SI
        PUSH   DI
; assign S
        MOV   AX, WORD PTR [BP+6]
        PUSH   AX
        MOV   AX, WORD PTR [BP+4]
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   WORD PTR [BP-2], AX
; writeln
        MOV   AX, WORD PTR [BP-2]
        CALL   _VXPRT_NUMTOSTR
        MOV   SI, OFFSET _VXPRT_NUMBUF
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
_VXPL_5:
        POP   DI
        POP   SI
        MOV   SP, BP
        POP   BP
        RET   4
_VXPF_ADDPRINT   ENDP


; --- Square ---
_VXPF_SQUARE   PROC NEAR
        PUSH   BP
        MOV   BP, SP
        SUB   SP, 2
        PUSH   SI
        PUSH   DI
        MOV   WORD PTR [BP-2], 0
; assign retval Square
        MOV   AX, WORD PTR [BP+4]
        PUSH   AX
        MOV   AX, WORD PTR [BP+4]
        MOV   BX, AX
        POP   AX
        IMUL   BX
        MOV   WORD PTR [BP-2], AX
_VXPL_6:
        MOV   AX, WORD PTR [BP-2]
        POP   DI
        POP   SI
        MOV   SP, BP
        POP   BP
        RET   2
_VXPF_SQUARE   ENDP


; --- SumOfSquares ---
_VXPF_SUMOFSQUARES   PROC NEAR
        PUSH   BP
        MOV   BP, SP
        SUB   SP, 2
        PUSH   SI
        PUSH   DI
        MOV   WORD PTR [BP-2], 0
; assign retval SumOfSquares
; call square
        MOV   AX, WORD PTR [BP+6]
        PUSH   AX
        CALL   _VXPF_SQUARE
        PUSH   AX
; call square
        MOV   AX, WORD PTR [BP+4]
        PUSH   AX
        CALL   _VXPF_SQUARE
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   WORD PTR [BP-2], AX
_VXPL_7:
        MOV   AX, WORD PTR [BP-2]
        POP   DI
        POP   SI
        MOV   SP, BP
        POP   BP
        RET   4
_VXPF_SUMOFSQUARES   ENDP


; --- TestExit ---
_VXPF_TESTEXIT   PROC NEAR
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        PUSH   DI
; if
        MOV   AX, WORD PTR [BP+4]
        PUSH   AX
        XOR   AX, AX
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JNE   _VXPL_9
        INC    AX
_VXPL_9:
        TEST   AX, AX
        JZ   _VXPL_10
; writeln
        LEA   AX, _VXPK_12
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
        JMP   _VXPL_8
_VXPL_10:
; writeln
        LEA   AX, _VXPK_13
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
_VXPL_8:
        POP   DI
        POP   SI
        MOV   SP, BP
        POP   BP
        RET   2
_VXPF_TESTEXIT   ENDP


; --- Fwd ---
_VXPF_FWD   PROC NEAR
        PUSH   BP
        MOV   BP, SP
        SUB   SP, 2
        PUSH   SI
        PUSH   DI
        MOV   WORD PTR [BP-2], 0
; assign retval Fwd
        MOV   AX, WORD PTR [BP+4]
        PUSH   AX
        MOV   AX, 100
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   WORD PTR [BP-2], AX
_VXPL_14:
        MOV   AX, WORD PTR [BP-2]
        POP   DI
        POP   SI
        MOV   SP, BP
        POP   BP
        RET   2
_VXPF_FWD   ENDP

; call SayHello
        CALL   _VXPF_SAYHELLO
; write
        LEA   AX, _VXPK_15
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
; call PrintVal
        CALL   _VXPF_PRINTVAL
; assign R
        XOR   AX, AX
        MOV   WORD PTR [_VXP_R], AX
; write
        LEA   AX, _VXPK_16
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
; writeln
        MOV   AX, WORD PTR [_VXP_R]
        CALL   _VXPRT_NUMTOSTR
        MOV   SI, OFFSET _VXPRT_NUMBUF
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
; assign R
; call triple
        MOV   AX, 5
        PUSH   AX
        CALL   _VXPF_TRIPLE
        MOV   WORD PTR [_VXP_R], AX
; write
        LEA   AX, _VXPK_17
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
; writeln
        MOV   AX, WORD PTR [_VXP_R]
        CALL   _VXPRT_NUMTOSTR
        MOV   SI, OFFSET _VXPRT_NUMBUF
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
; write
        LEA   AX, _VXPK_18
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
; call AddPrint
        CALL   _VXPF_ADDPRINT
; assign R
; call sumofsquares
        MOV   AX, 3
        PUSH   AX
        MOV   AX, 4
        PUSH   AX
        CALL   _VXPF_SUMOFSQUARES
        MOV   WORD PTR [_VXP_R], AX
; write
        LEA   AX, _VXPK_19
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
; writeln
        MOV   AX, WORD PTR [_VXP_R]
        CALL   _VXPRT_NUMTOSTR
        MOV   SI, OFFSET _VXPRT_NUMBUF
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
; call TestExit
        CALL   _VXPF_TESTEXIT
; assign R
; call fwd
        MOV   AX, 5
        PUSH   AX
        CALL   _VXPF_FWD
        MOV   WORD PTR [_VXP_R], AX
; write
        LEA   AX, _VXPK_20
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
; writeln
        MOV   AX, WORD PTR [_VXP_R]
        CALL   _VXPRT_NUMTOSTR
        MOV   SI, OFFSET _VXPRT_NUMBUF
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
; writeln
        LEA   AX, _VXPK_21
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
_VXP_R  DW  0
_VXPK_2  DB  'Hello from proc',0
_VXPK_12  DB  'exit early',0
_VXPK_13  DB  'not reached if 0',0
_VXPK_15  DB  'PrintVal: ',0
_VXPK_16  DB  'Double 7 = ',0
_VXPK_17  DB  'Triple 5 = ',0
_VXPK_18  DB  '3+4 = ',0
_VXPK_19  DB  '3^2+4^2 = ',0
_VXPK_20  DB  'Fwd 5 = ',0
_VXPK_21  DB  'Tous les tests TODO 14 OK',0
_DATA   ENDS

        END     _VXPF_MAIN
