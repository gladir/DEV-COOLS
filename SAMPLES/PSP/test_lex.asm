; ========================================
; Genere par PSP86 v1.0 (2026-03-06)
; Source : samples\PSP\test_lex.psp
; ========================================

.MODEL SMALL
.STACK 1024

; --- Segment de code ---
_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME CS:_TEXT, DS:_DATA

; --- Point d entree principal ---
_PSPF_MAIN:
        MOV   AX, _DATA
        MOV   DS, AX
        JMP   _PSPL_MAINBODY

_PSPL_MAINBODY:
; assign i
        MOV   AX, 42
        MOV   WORD PTR [_PSP_I], AX
; assign x
        MOV   AX, 255
        MOV   WORD PTR [_PSP_X], AX
; assign s
        LEA   AX, _PSPK_1
        MOV   WORD PTR [_PSP_S], AX
; for
        MOV   AX, 1
        MOV   WORD PTR [_PSP_I], AX
        MOV   AX, 10
        MOV   WORD PTR [_PSPL_2], AX
_PSPL_3:
        MOV   AX, WORD PTR [_PSP_I]
        CMP   AX, WORD PTR [_PSPL_2]
        JG   _PSPL_4
; writeln
        MOV   AX, WORD PTR [_PSP_I]
        CALL   _PSPRT_NUMTOSTR
        MOV   SI, OFFSET _PSPRT_NUMBUF
        CALL   _PSPRT_PRINTSTR
        MOV   SI, OFFSET _PSPRT_CRLF
        CALL   _PSPRT_PRINTSTR
_PSPL_5:
        INC   WORD PTR [_PSP_I]
        JMP   _PSPL_3
_PSPL_4:
; if
        MOV   AX, WORD PTR [_PSP_I]
        PUSH   AX
        XOR   AX, AX
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JE   _PSPL_6
        INC    AX
_PSPL_6:
        TEST   AX, AX
        JZ   _PSPL_7
; write
        LEA   AX, _PSPK_9
        MOV   SI, AX
        CALL   _PSPRT_PRINTSTR
_PSPL_7:
; case
        MOV   AX, WORD PTR [_PSP_I]
        PUSH   AX
        MOV   AX, WORD PTR [SP]
        CMP   AX, 1
        JE   _PSPL_12
        JMP   _PSPL_11
_PSPL_12:
; writeln
        LEA   AX, _PSPK_13
        MOV   SI, AX
        CALL   _PSPRT_PRINTSTR
        MOV   SI, OFFSET _PSPRT_CRLF
        CALL   _PSPRT_PRINTSTR
        JMP   _PSPL_10
_PSPL_11:
        MOV   AX, WORD PTR [SP]
        CMP   AX, 2
        JE   _PSPL_15
        JMP   _PSPL_14
_PSPL_15:
; writeln
        LEA   AX, _PSPK_16
        MOV   SI, AX
        CALL   _PSPRT_PRINTSTR
        MOV   SI, OFFSET _PSPRT_CRLF
        CALL   _PSPRT_PRINTSTR
        JMP   _PSPL_10
_PSPL_14:
; case else
; writeln
        LEA   AX, _PSPK_17
        MOV   SI, AX
        CALL   _PSPRT_PRINTSTR
        MOV   SI, OFFSET _PSPRT_CRLF
        CALL   _PSPRT_PRINTSTR
_PSPL_10:
        POP   AX
; html fragment
        MOV   SI, OFFSET _PSPK_HTML_18
        CALL   _PSPRT_PRINTSTR

; --- Sortie programme (DOS INT 21h) ---
        MOV   AH, 4Ch
        MOV   AL, 0
        INT    21h

; === Routines runtime ===

; PRINTSTR : affiche chaine ASCIIZ (SI -> chaine)
_PSPRT_PRINTSTR:
_PSPRT_PRINTSTR_LP:
        LODSB
        CMP   AL, 0
        JE   _PSPRT_PRINTSTR_DONE
        MOV   DL, AL
        MOV   AH, 02h
        INT    21h
        JMP   _PSPRT_PRINTSTR_LP
_PSPRT_PRINTSTR_DONE:
        RET

; NUMTOSTR : convertit AX (signe) -> NUMBUF (ASCIIZ)
_PSPRT_NUMTOSTR:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        PUSH   DI
        MOV   DI, OFFSET _PSPRT_NUMBUF
        MOV   CX, 0
        CMP   AX, 0
        JGE   _PSPRT_NTS_POS
        MOV   BYTE PTR [DI], '-'
        INC    DI
        NEG    AX
_PSPRT_NTS_POS:
        MOV   BX, 10
_PSPRT_NTS_DIV:
        XOR   DX, DX
        DIV   BX
        ADD   DL, '0'
        PUSH   DX
        INC    CX
        CMP   AX, 0
        JNE   _PSPRT_NTS_DIV
_PSPRT_NTS_POP:
        POP   AX
        MOV   [DI], AL
        INC    DI
        LOOP   _PSPRT_NTS_POP
        MOV   BYTE PTR [DI], 0
        POP   DI
        POP   DX
        POP   CX
        POP   BX
        RET

; STRLEN : longueur chaine ASCIIZ (SI -> AX)
_PSPRT_STRLEN:
        PUSH   SI
        XOR   AX, AX
_PSPRT_STRLEN_LP:
        CMP   BYTE PTR [SI], 0
        JE   _PSPRT_STRLEN_DONE
        INC    AX
        INC    SI
        JMP   _PSPRT_STRLEN_LP
_PSPRT_STRLEN_DONE:
        POP   SI
        RET

; CONCAT : SI + DI -> AX = ptr STRBUF
_PSPRT_CONCAT:
        PUSH   BX
        PUSH   CX
        MOV   BX, OFFSET _PSPRT_STRBUF
_PSPRT_CONCAT_S1:
        MOV   AL, [SI]
        CMP   AL, 0
        JE   _PSPRT_CONCAT_S2
        MOV   [BX], AL
        INC    SI
        INC    BX
        JMP   _PSPRT_CONCAT_S1
_PSPRT_CONCAT_S2:
        MOV   AL, [DI]
        CMP   AL, 0
        JE   _PSPRT_CONCAT_END
        MOV   [BX], AL
        INC    DI
        INC    BX
        JMP   _PSPRT_CONCAT_S2
_PSPRT_CONCAT_END:
        MOV   BYTE PTR [BX], 0
        LEA   AX, _PSPRT_STRBUF
        POP   CX
        POP   BX
        RET

; STRCMP : SI vs DI -> AX (signe)
_PSPRT_STRCMP:
_PSPRT_STRCMP_LP:
        MOV   AL, [SI]
        MOV   AH, [DI]
        CMP   AL, AH
        JNE   _PSPRT_STRCMP_DIFF
        CMP   AL, 0
        JE   _PSPRT_STRCMP_EQ
        INC    SI
        INC    DI
        JMP   _PSPRT_STRCMP_LP
_PSPRT_STRCMP_EQ:
        XOR   AX, AX
        RET
_PSPRT_STRCMP_DIFF:
        XOR   AH, AH
        MOV   BL, [DI]
        XOR   BH, BH
        SUB   AX, BX
        RET

; CHR : AL -> AX = ptr chaine 1 car
_PSPRT_CHR:
        MOV   BYTE PTR [_PSPRT_CHRBUF], AL
        MOV   BYTE PTR [_PSPRT_CHRBUF+1], 0
        LEA   AX, _PSPRT_CHRBUF
        RET

; STRTONUM : SI -> AX (entier signe)
_PSPRT_STRTONUM:
        PUSH   BX
        PUSH   CX
        XOR   AX, AX
        XOR   CX, CX
        CMP   BYTE PTR [SI], '-'
        JNE   _PSPRT_STN_LP
        MOV   CX, 1
        INC    SI
_PSPRT_STN_LP:
        MOV   BL, [SI]
        CMP   BL, '0'
        JB   _PSPRT_STN_DONE
        CMP   BL, '9'
        JA   _PSPRT_STN_DONE
        SUB   BL, '0'
        XOR   BH, BH
        PUSH   BX
        MOV   BX, 10
        IMUL   BX
        POP   BX
        ADD   AX, BX
        INC    SI
        JMP   _PSPRT_STN_LP
_PSPRT_STN_DONE:
        CMP   CX, 0
        JE   _PSPRT_STN_RET
        NEG    AX
_PSPRT_STN_RET:
        POP   CX
        POP   BX
        RET

; COPY : SI,BX,CX -> AX = ptr STRBUF
_PSPRT_COPY:
        PUSH   DI
        MOV   DI, OFFSET _PSPRT_STRBUF
        DEC   BX
        ADD   SI, BX
_PSPRT_COPY_LP:
        CMP   CX, 0
        JE   _PSPRT_COPY_END
        MOV   AL, [SI]
        CMP   AL, 0
        JE   _PSPRT_COPY_END
        MOV   [DI], AL
        INC    SI
        INC    DI
        DEC    CX
        JMP   _PSPRT_COPY_LP
_PSPRT_COPY_END:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _PSPRT_STRBUF
        POP   DI
        RET

; POS : SI=sub, DI=str -> AX (1-base ou 0)
_PSPRT_POS:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        XOR   DX, DX
_PSPRT_POS_OUTER:
        CMP   BYTE PTR [DI], 0
        JE   _PSPRT_POS_NOTFOUND
        PUSH   SI
        PUSH   DI
        ADD   DI, DX
_PSPRT_POS_CMP:
        MOV   AL, [SI]
        CMP   AL, 0
        JE   _PSPRT_POS_FOUND
        CMP   AL, [DI]
        JNE   _PSPRT_POS_NEXT
        INC    SI
        INC    DI
        JMP   _PSPRT_POS_CMP
_PSPRT_POS_FOUND:
        POP   DI
        POP   SI
        MOV   AX, DX
        INC    AX
        JMP   _PSPRT_POS_RET
_PSPRT_POS_NEXT:
        POP   DI
        POP   SI
        INC    DX
        JMP   _PSPRT_POS_OUTER
_PSPRT_POS_NOTFOUND:
        XOR   AX, AX
_PSPRT_POS_RET:
        POP   DX
        POP   CX
        POP   BX
        RET

; FILLCHAR : DI=ptr, CX=n, AL=val -> REP STOSB
_PSPRT_FILLCHAR:
        REP    STOSB
        RET

; MOVE : SI=src, DI=dst, CX=n -> REP MOVSB
_PSPRT_MOVE:
        REP    MOVSB
        RET

; SQRT : AX=n -> AX=floor(sqrt(n))
_PSPRT_SQRT:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        CMP   AX, 0
        JLE   _PSPRT_SQRT_RET0
        MOV   BX, AX
        SHR   AX, 1
        CMP   AX, 0
        JE   _PSPRT_SQRT_ONE
_PSPRT_SQRT_LP:
        MOV   CX, AX
        MOV   AX, BX
        XOR   DX, DX
        DIV   CX
        ADD   AX, CX
        SHR   AX, 1
        CMP   AX, CX
        JB   _PSPRT_SQRT_LP
        MOV   AX, CX
        JMP   _PSPRT_SQRT_END
_PSPRT_SQRT_RET0:
        XOR   AX, AX
        JMP   _PSPRT_SQRT_END
_PSPRT_SQRT_ONE:
        MOV   AX, 1
_PSPRT_SQRT_END:
        POP   DX
        POP   CX
        POP   BX
        RET

; RANDOM : AX = pseudo-aleatoire 0..32767
_PSPRT_RANDOM:
        MOV   AX, WORD PTR [_PSPRT_SEED]
        MOV   CX, 25173
        MUL    CX
        ADD   AX, 13849
        MOV   WORD PTR [_PSPRT_SEED], AX
        AND   AX, 7FFFh
        RET

; RANDOMIZE : graine depuis horloge DOS
_PSPRT_RANDOMIZE:
        MOV   AH, 00h
        INT    1Ah
        MOV   WORD PTR [_PSPRT_SEED], DX
        RET

; ALLOC : CX=taille -> AX=ptr (bump alloc)
_PSPRT_ALLOC:
        MOV   AX, WORD PTR [_PSPRT_HEAPTOP]
        ADD   WORD PTR [_PSPRT_HEAPTOP], CX
        RET

; READCHAR : AL = caractere clavier (INT 21h/01h)
_PSPRT_READCHAR:
        MOV   AH, 01h
        INT    21h
        RET

; READNUM : AX = entier lu depuis clavier
_PSPRT_READNUM:
        PUSH   BX
        PUSH   CX
        PUSH   DI
        MOV   DI, OFFSET _PSPRT_NUMBUF
        XOR   CX, CX
_PSPRT_RN_LP:
        MOV   AH, 01h
        INT    21h
        CMP   AL, 13
        JE   _PSPRT_RN_DONE
        CMP   AL, 10
        JE   _PSPRT_RN_DONE
        MOV   [DI], AL
        INC    DI
        INC    CX
        CMP   CX, 10
        JB   _PSPRT_RN_LP
_PSPRT_RN_DONE:
        MOV   BYTE PTR [DI], 0
        MOV   SI, OFFSET _PSPRT_NUMBUF
        CALL   _PSPRT_STRTONUM
        POP   DI
        POP   CX
        POP   BX
        RET

; PRINT : BX=handle, DX=buf, CX=len -> INT 21h/40h
_PSPRT_PRINT:
        MOV   AH, 40h
        INT    21h
        RET

; PRINTLN : SI=chaine ASCIIZ -> affiche + CRLF
_PSPRT_PRINTLN:
        CALL   _PSPRT_PRINTSTR
        MOV   SI, OFFSET _PSPRT_CRLF
        CALL   _PSPRT_PRINTSTR
        RET

; DELETE : SI=str, BX=pos(1), CX=len -> modifie en place
_PSPRT_DELETE:
        PUSH   DI
        PUSH   SI
        DEC    BX
        MOV   DI, OFFSET _PSPRT_STRBUF
        PUSH   CX
        MOV   CX, BX
        CMP   CX, 0
        JE   _PSPRT_DEL_SKIP1
_PSPRT_DEL_CP1:
        MOV   AL, [SI]
        MOV   [DI], AL
        INC    SI
        INC    DI
        LOOP   _PSPRT_DEL_CP1
_PSPRT_DEL_SKIP1:
        POP   CX
_PSPRT_DEL_ADV:
        CMP   CX, 0
        JE   _PSPRT_DEL_TAIL
        CMP   BYTE PTR [SI], 0
        JE   _PSPRT_DEL_TAIL
        INC    SI
        DEC    CX
        JMP   _PSPRT_DEL_ADV
_PSPRT_DEL_TAIL:
        MOV   AL, [SI]
        MOV   [DI], AL
        CMP   AL, 0
        JE   _PSPRT_DEL_END
        INC    SI
        INC    DI
        JMP   _PSPRT_DEL_TAIL
_PSPRT_DEL_END:
        POP   DI
        MOV   SI, OFFSET _PSPRT_STRBUF
_PSPRT_DEL_BACK:
        MOV   AL, [SI]
        MOV   [DI], AL
        CMP   AL, 0
        JE   _PSPRT_DEL_RET
        INC    SI
        INC    DI
        JMP   _PSPRT_DEL_BACK
_PSPRT_DEL_RET:
        POP   DI
        RET

; INSERT : SI=sub, DI=str, BX=pos(1) -> modifie str
_PSPRT_INSERT:
        PUSH   DI
        PUSH   SI
        DEC    BX
        MOV   SI, DI
        MOV   DI, OFFSET _PSPRT_STRBUF
        MOV   CX, BX
        CMP   CX, 0
        JE   _PSPRT_INS_SUB
_PSPRT_INS_CP1:
        MOV   AL, [SI]
        CMP   AL, 0
        JE   _PSPRT_INS_SUB
        MOV   [DI], AL
        INC    SI
        INC    DI
        LOOP   _PSPRT_INS_CP1
_PSPRT_INS_SUB:
        POP   AX
        PUSH   SI
        MOV   SI, AX
_PSPRT_INS_CP2:
        MOV   AL, [SI]
        CMP   AL, 0
        JE   _PSPRT_INS_REST
        MOV   [DI], AL
        INC    SI
        INC    DI
        JMP   _PSPRT_INS_CP2
_PSPRT_INS_REST:
        POP   SI
_PSPRT_INS_CP3:
        MOV   AL, [SI]
        MOV   [DI], AL
        CMP   AL, 0
        JE   _PSPRT_INS_DONE
        INC    SI
        INC    DI
        JMP   _PSPRT_INS_CP3
_PSPRT_INS_DONE:
        POP   DI
        MOV   SI, OFFSET _PSPRT_STRBUF
_PSPRT_INS_BACK:
        MOV   AL, [SI]
        MOV   [DI], AL
        CMP   AL, 0
        JE   _PSPRT_INS_RET
        INC    SI
        INC    DI
        JMP   _PSPRT_INS_BACK
_PSPRT_INS_RET:
        RET

; LOWERCASE : SI=str -> AX=ptr STRBUF (minuscules)
_PSPRT_LOWERCASE:
        PUSH   DI
        MOV   DI, OFFSET _PSPRT_STRBUF
_PSPRT_LC_LP:
        MOV   AL, [SI]
        CMP   AL, 0
        JE   _PSPRT_LC_END
        CMP   AL, 'A'
        JB   _PSPRT_LC_STORE
        CMP   AL, 'Z'
        JA   _PSPRT_LC_STORE
        ADD   AL, 32
_PSPRT_LC_STORE:
        MOV   [DI], AL
        INC    SI
        INC    DI
        JMP   _PSPRT_LC_LP
_PSPRT_LC_END:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _PSPRT_STRBUF
        POP   DI
        RET

; TRIM : SI=str -> AX=ptr STRBUF (sans espaces)
_PSPRT_TRIM:
        PUSH   DI
_PSPRT_TRIM_L:
        CMP   BYTE PTR [SI], 32
        JNE   _PSPRT_TRIM_COPY
        INC    SI
        JMP   _PSPRT_TRIM_L
_PSPRT_TRIM_COPY:
        MOV   DI, OFFSET _PSPRT_STRBUF
_PSPRT_TRIM_CP:
        MOV   AL, [SI]
        MOV   [DI], AL
        CMP   AL, 0
        JE   _PSPRT_TRIM_R
        INC    SI
        INC    DI
        JMP   _PSPRT_TRIM_CP
_PSPRT_TRIM_R:
        DEC    DI
        CMP   DI, OFFSET _PSPRT_STRBUF
        JB   _PSPRT_TRIM_DONE
        CMP   BYTE PTR [DI], 32
        JNE   _PSPRT_TRIM_DONE
        MOV   BYTE PTR [DI], 0
        JMP   _PSPRT_TRIM_R
_PSPRT_TRIM_DONE:
        INC    DI
        MOV   BYTE PTR [DI], 0
        LEA   AX, _PSPRT_STRBUF
        POP   DI
        RET

; PANIC : SI=msg ASCIIZ -> affiche + halt(1)
_PSPRT_PANIC:
        CALL   _PSPRT_PRINTSTR
; CRLF apres message
        MOV   SI, OFFSET _PSPRT_CRLF
        CALL   _PSPRT_PRINTSTR
        MOV   AX, 4C01h
        INT    21h

; PANIC_DIV0 : Runtime error division by zero
_PSPRT_PANIC_DIV0:
        MOV   SI, OFFSET _PSPRT_DIV0MSG
        CMP   WORD PTR [_PSPX_HANDLER], 0
        JE   _PSPRT_PANIC_DIV0_FATAL
        MOV   SP, WORD PTR [_PSPX_SAVESP]
        MOV   BP, WORD PTR [_PSPX_SAVEBP]
        JMP   WORD PTR [_PSPX_HANDLER]
_PSPRT_PANIC_DIV0_FATAL:
        CALL   _PSPRT_PANIC

_TEXT   ENDS

_DATA   SEGMENT WORD PUBLIC 'DATA'
; --- Buffers internes ---
_PSPRT_CRLF    DB  13,10,0
_PSPRT_STRBUF  DB  512 DUP(0)
_PSPRT_CHRBUF  DB  2 DUP(0)
_PSPRT_NUMBUF  DB  12 DUP(0)
_PSPRT_TRUE_S  DB  'TRUE',0
_PSPRT_FALSE_S DB  'FALSE',0
_PSPRT_HEAP    DB  4096 DUP(0)
_PSPRT_HEAPTOP DW  OFFSET _PSPRT_HEAP
_PSPRT_SEED    DW  1
_PSPX_HANDLER DW  0
_PSPX_SAVESP  DW  0
_PSPX_SAVEBP  DW  0
_PSPRT_DIV0MSG DB  'Runtime error: Division by zero',0
_PSPRT_PANICMSG DB 0

; --- Donnees du programme ---
_PSP_I  DW  0
_PSP_S  DW  0
_PSP_X  DW  0
_PSPK_1  DB  'Hello World',0
_PSPL_2  DW  0
_PSPK_9  DB  'ok',0
_PSPK_13  DB  'Un',0
_PSPK_16  DB  'Deux',0
_PSPK_17  DB  'Autre',0
_PSPK_HTML_18  DB  '
',0
_DATA   ENDS
        END     _PSPF_main
