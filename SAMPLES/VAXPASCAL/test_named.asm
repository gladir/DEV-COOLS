; ========================================
; Genere par VAXPAS86 v1.0 (2026-03-07)
; Source : SAMPLES\VAXPASCAL\test_named.pas
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


; --- display ---
_VXPF_DISPLAY   PROC NEAR
        PUSH   BP
        MOV   BP, SP
        PUSH   SI
        PUSH   DI
; exception: sauvegarder handler parent
        PUSH   WORD PTR [_VXPRT_EXCHDL]
        PUSH   WORD PTR [_VXPRT_EXCSP]
        PUSH   WORD PTR [_VXPRT_EXCBP]
        MOV   WORD PTR [_VXPRT_EXCHDL], OFFSET _VXPL_2
        MOV   WORD PTR [_VXPRT_EXCSP], SP
        MOV   WORD PTR [_VXPRT_EXCBP], BP
; writeln
        LEA   AX, _VXPK_4
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   AX, WORD PTR [BP+8]
        CALL   _VXPRT_NUMTOSTR
        MOV   SI, OFFSET _VXPRT_NUMBUF
        CALL   _VXPRT_PRINTSTR
        LEA   AX, _VXPK_5
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   AX, WORD PTR [BP+6]
        CALL   _VXPRT_NUMTOSTR
        MOV   SI, OFFSET _VXPRT_NUMBUF
        CALL   _VXPRT_PRINTSTR
        LEA   AX, _VXPK_6
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   AX, WORD PTR [BP+4]
        CALL   _VXPRT_NUMTOSTR
        MOV   SI, OFFSET _VXPRT_NUMBUF
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
; exception: pas d erreur, restaurer handler parent
        POP   WORD PTR [_VXPRT_EXCBP]
        POP   WORD PTR [_VXPRT_EXCSP]
        POP   WORD PTR [_VXPRT_EXCHDL]
        JMP   _VXPL_3
_VXPL_2:
; exception handler
        POP   WORD PTR [_VXPRT_EXCBP]
        POP   WORD PTR [_VXPRT_EXCSP]
        POP   WORD PTR [_VXPRT_EXCHDL]
_VXPL_3:
_VXPL_1:
        POP   DI
        POP   SI
        MOV   SP, BP
        POP   BP
        RET   6
_VXPF_DISPLAY   ENDP

_VXPL_MAINBODY:
; exception: sauvegarder handler parent
        PUSH   WORD PTR [_VXPRT_EXCHDL]
        PUSH   WORD PTR [_VXPRT_EXCSP]
        PUSH   WORD PTR [_VXPRT_EXCBP]
        MOV   WORD PTR [_VXPRT_EXCHDL], OFFSET _VXPL_7
        MOV   WORD PTR [_VXPRT_EXCSP], SP
        MOV   WORD PTR [_VXPRT_EXCBP], BP
; call display
        XOR   AX, AX
        PUSH   AX
        XOR   AX, AX
        PUSH   AX
        MOV   AX, 10
        PUSH   AX
        XOR   AX, AX
        PUSH   AX
        XOR   AX, AX
        PUSH   AX
        MOV   AX, 20
        PUSH   AX
        XOR   AX, AX
        PUSH   AX
        XOR   AX, AX
        PUSH   AX
        MOV   AX, 1
        PUSH   AX
        CALL   _VXPF_DISPLAY
; call display
        XOR   AX, AX
        PUSH   AX
        XOR   AX, AX
        PUSH   AX
        MOV   AX, 50
        PUSH   AX
        XOR   AX, AX
        PUSH   AX
        XOR   AX, AX
        PUSH   AX
        MOV   AX, 30
        PUSH   AX
        XOR   AX, AX
        PUSH   AX
        XOR   AX, AX
        PUSH   AX
        MOV   AX, 2
        PUSH   AX
        CALL   _VXPF_DISPLAY
; writeln
        LEA   AX, _VXPK_9
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        MOV   SI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
; exception: pas d erreur, restaurer handler parent
        POP   WORD PTR [_VXPRT_EXCBP]
        POP   WORD PTR [_VXPRT_EXCSP]
        POP   WORD PTR [_VXPRT_EXCHDL]
        JMP   _VXPL_8
_VXPL_7:
; exception handler
        POP   WORD PTR [_VXPRT_EXCBP]
        POP   WORD PTR [_VXPRT_EXCSP]
        POP   WORD PTR [_VXPRT_EXCHDL]
_VXPL_8:

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

; SUBSTR : SI=str, BX=pos(1-base), CX=len -> AX=ptr STRBUF
_VXPRT_SUBSTR:
        PUSH   BX
        PUSH   CX
        PUSH   DI
        PUSH   SI
        CMP   BX, 1
        JGE   _VXPRT_SUBSTR_POSOK
        MOV   BX, 1
_VXPRT_SUBSTR_POSOK:
        DEC    BX
        ADD   SI, BX
        LEA   DI, _VXPRT_STRBUF
_VXPRT_SUBSTR_LP:
        CMP   CX, 0
        JE   _VXPRT_SUBSTR_DONE
        MOV   AL, [SI]
        CMP   AL, 0
        JE   _VXPRT_SUBSTR_DONE
        MOV   [DI], AL
        INC    SI
        INC    DI
        DEC    CX
        JMP   _VXPRT_SUBSTR_LP
_VXPRT_SUBSTR_DONE:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _VXPRT_STRBUF
        POP   SI
        POP   DI
        POP   CX
        POP   BX
        RET

; SSLICE : DI=target str, SI=source str, BX=pos(1-base), CX=len
_VXPRT_SSLICE:
        PUSH   BX
        PUSH   CX
        PUSH   DI
        PUSH   SI
        CMP   BX, 1
        JGE   _VXPRT_SSLICE_POSOK
        MOV   BX, 1
_VXPRT_SSLICE_POSOK:
        DEC    BX
        ADD   DI, BX
_VXPRT_SSLICE_LP:
        CMP   CX, 0
        JE   _VXPRT_SSLICE_DONE
        MOV   AL, [SI]
        CMP   AL, 0
        JE   _VXPRT_SSLICE_DONE
        MOV   [DI], AL
        INC    SI
        INC    DI
        DEC    CX
        JMP   _VXPRT_SSLICE_LP
_VXPRT_SSLICE_DONE:
        POP   SI
        POP   DI
        POP   CX
        POP   BX
        RET

; INDEX : SI=str, DI=sub -> AX=position (1-based, 0=absent)
_VXPRT_INDEX:
        PUSH   BX
        PUSH   CX
        CMP   BYTE PTR [DI], 0
        JNE   _VXPRT_INDEX_INIT
        MOV   AX, 1
        POP   CX
        POP   BX
        RET
_VXPRT_INDEX_INIT:
        MOV   BX, SI
        MOV   CX, 1
_VXPRT_INDEX_LP:
        CMP   BYTE PTR [BX], 0
        JE   _VXPRT_INDEX_NF
        PUSH   BX
        PUSH   DI
_VXPRT_INDEX_CM:
        MOV   AL, [DI]
        CMP   AL, 0
        JE   _VXPRT_INDEX_FD
        CMP   AL, [BX]
        JNE   _VXPRT_INDEX_NX
        INC    BX
        INC    DI
        JMP   _VXPRT_INDEX_CM
_VXPRT_INDEX_FD:
        POP   DI
        POP   BX
        MOV   AX, CX
        POP   CX
        POP   BX
        RET
_VXPRT_INDEX_NX:
        POP   DI
        POP   BX
        INC    BX
        INC    CX
        JMP   _VXPRT_INDEX_LP
_VXPRT_INDEX_NF:
        XOR   AX, AX
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

        POP   DX
        POP   CX
        POP   BX
        RET

; SET_CLR : SI=set ptr -> clear 32 bytes
_VXPRT_SET_CLR:
        PUSH   CX
        PUSH   DI
        MOV   DI, SI
        XOR   AX, AX
        MOV   CX, 16
        REP    STOSW
        POP   DI
        POP   CX
        RET

; SET_ADD : SI=set ptr, BX=element -> set bit
_VXPRT_SET_ADD:
        PUSH   BX
        PUSH   CX
        PUSH   SI
        MOV   CX, BX
        SHR   BX, 1
        SHR   BX, 1
        SHR   BX, 1
        ADD   SI, BX
        AND   CL, 7
        MOV   AL, 1
        SHL   AL, CL
        OR   BYTE PTR [SI], AL
        POP   SI
        POP   CX
        POP   BX
        RET

; SET_ADDRANGE : SI=set, BX=lo, CX=hi -> set bits
_VXPRT_SET_ADDRANGE:
        PUSH   BX
        PUSH   CX
_VXPRT_SET_AR_LP:
        CMP   BX, CX
        JG   _VXPRT_SET_AR_DONE
        CALL   _VXPRT_SET_ADD
        INC    BX
        JMP   _VXPRT_SET_AR_LP
_VXPRT_SET_AR_DONE:
        POP   CX
        POP   BX
        RET

; SET_UNION : SI=left, DI=right -> AX=OFFSET SETBUF
_VXPRT_SET_UNION:
        PUSH   BX
        PUSH   CX
        PUSH   SI
        PUSH   DI
        LEA   BX, _VXPRT_SETBUF
        MOV   CX, 32
_VXPRT_SET_UNI_LP:
        MOV   AL, [SI]
        OR   AL, [DI]
        MOV   [BX], AL
        INC    SI
        INC    DI
        INC    BX
        DEC    CX
        JNZ   _VXPRT_SET_UNI_LP
        LEA   AX, _VXPRT_SETBUF
        POP   DI
        POP   SI
        POP   CX
        POP   BX
        RET

; SET_INTER : SI=left, DI=right -> AX=OFFSET SETBUF
_VXPRT_SET_INTER:
        PUSH   BX
        PUSH   CX
        PUSH   SI
        PUSH   DI
        LEA   BX, _VXPRT_SETBUF
        MOV   CX, 32
_VXPRT_SET_INT_LP:
        MOV   AL, [SI]
        AND   AL, [DI]
        MOV   [BX], AL
        INC    SI
        INC    DI
        INC    BX
        DEC    CX
        JNZ   _VXPRT_SET_INT_LP
        LEA   AX, _VXPRT_SETBUF
        POP   DI
        POP   SI
        POP   CX
        POP   BX
        RET

; SET_DIFF : SI=left, DI=right -> AX=OFFSET SETBUF
_VXPRT_SET_DIFF:
        PUSH   BX
        PUSH   CX
        PUSH   SI
        PUSH   DI
        LEA   BX, _VXPRT_SETBUF
        MOV   CX, 32
_VXPRT_SET_DIF_LP:
        MOV   AL, [DI]
        NOT    AL
        AND   AL, [SI]
        MOV   [BX], AL
        INC    SI
        INC    DI
        INC    BX
        DEC    CX
        JNZ   _VXPRT_SET_DIF_LP
        LEA   AX, _VXPRT_SETBUF
        POP   DI
        POP   SI
        POP   CX
        POP   BX
        RET

; SET_IN : SI=set, BX=element -> AX=0/1
_VXPRT_SET_IN:
        PUSH   BX
        PUSH   CX
        PUSH   SI
        MOV   CX, BX
        SHR   BX, 1
        SHR   BX, 1
        SHR   BX, 1
        ADD   SI, BX
        AND   CL, 7
        MOV   AL, [SI]
        SHR   AL, CL
        AND   AL, 1
        XOR   AH, AH
        POP   SI
        POP   CX
        POP   BX
        RET

; SET_EQ : SI=set1, DI=set2 -> AX=1/0
_VXPRT_SET_EQ:
        PUSH   CX
        PUSH   SI
        PUSH   DI
        MOV   CX, 32
_VXPRT_SET_EQ_LP:
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _VXPRT_SET_EQ_NE
        INC    SI
        INC    DI
        DEC    CX
        JNZ   _VXPRT_SET_EQ_LP
        MOV   AX, 1
        JMP   _VXPRT_SET_EQ_DN
_VXPRT_SET_EQ_NE:
        XOR   AX, AX
_VXPRT_SET_EQ_DN:
        POP   DI
        POP   SI
        POP   CX
        RET

; SET_SUB : SI=set1, DI=set2 -> AX=1 if set1 <= set2
_VXPRT_SET_SUB:
        PUSH   CX
        PUSH   SI
        PUSH   DI
        MOV   CX, 32
_VXPRT_SET_SB_LP:
        MOV   AL, [DI]
        NOT    AL
        AND   AL, [SI]
        JNZ   _VXPRT_SET_SB_NO
        INC    SI
        INC    DI
        DEC    CX
        JNZ   _VXPRT_SET_SB_LP
        MOV   AX, 1
        JMP   _VXPRT_SET_SB_DN
_VXPRT_SET_SB_NO:
        XOR   AX, AX
_VXPRT_SET_SB_DN:
        POP   DI
        POP   SI
        POP   CX
        RET

; SET_CARD : SI=set -> AX=card
_VXPRT_SET_CARD:
        PUSH   BX
        PUSH   CX
        PUSH   SI
        XOR   BX, BX
        MOV   CX, 32
_VXPRT_SET_CD_LP:
        MOV   AL, [SI]
        PUSH   CX
        MOV   CX, 8
_VXPRT_SET_CD_BIT:
        SHR   AL, 1
        ADC   BX, 0
        DEC    CX
        JNZ   _VXPRT_SET_CD_BIT
        POP   CX
        INC    SI
        DEC    CX
        JNZ   _VXPRT_SET_CD_LP
        MOV   AX, BX
        POP   SI
        POP   CX
        POP   BX
        RET

; SET_COPY : SI=src, DI=dst -> copy 32 bytes
_VXPRT_SET_COPY:
        PUSH   CX
        PUSH   SI
        PUSH   DI
        MOV   CX, 16
        REP    MOVSW
        POP   DI
        POP   SI
        POP   CX
        RET

; NEW : AX=taille -> AX=pointeur alloue
_VXPRT_NEW:
        PUSH   BX
        MOV   BX, WORD PTR [_VXPRT_HEAPTOP]
        PUSH   BX
        ADD   BX, AX
        INC    BX
        AND   BX, 0FFFEh
        MOV   WORD PTR [_VXPRT_HEAPTOP], BX
        POP   AX
        POP   BX
        RET

; DISPOSE : AX=pointeur (no-op heap lineaire)
_VXPRT_DISPOSE:
        RET

; SQRT : racine carree entiere AX -> AX
_VXPRT_SQRT:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        CMP   AX, 0
        JLE   _VXPRT_SQRT_ZERO
        MOV   BX, AX
        MOV   AX, 1
_VXPRT_SQRT_LP:
        MOV   CX, AX
        MOV   AX, BX
        XOR   DX, DX
        DIV   CX
        ADD   AX, CX
        SHR   AX, 1
        CMP   AX, CX
        JB   _VXPRT_SQRT_LP
        MOV   AX, CX
        JMP   _VXPRT_SQRT_DONE
_VXPRT_SQRT_ZERO:
        XOR   AX, AX
_VXPRT_SQRT_DONE:
        POP   DX
        POP   CX
        POP   BX
        RET

; RANDOM : LFSR 16-bit -> AX (0..32767)
_VXPRT_RANDOM:
        PUSH   BX
        MOV   AX, [_VXPRT_SEED]
        MOV   BX, 25173
        MUL   BX
        ADD   AX, 13849
        MOV   [_VXPRT_SEED], AX
        AND   AX, 7FFFh
        POP   BX
        RET

; STRCPY : copier ASCIIZ SI -> DI
_VXPRT_STRCPY:
        PUSH   SI
        PUSH   DI
_VXPRT_STRCPY_LP:
        LODSB
        STOSB
        CMP   AL, 0
        JNE   _VXPRT_STRCPY_LP
        POP   DI
        POP   SI
        RET

; STRCMPI : compare ASCIIZ SI vs DI case-insensitive -> AX
_VXPRT_STRCMPI:
        PUSH   SI
        PUSH   DI
        PUSH   BX
_VXPRT_SCMPI_LP:
        MOV   AL, [SI]
        MOV   BL, [DI]
        CMP   AL, 'a'
        JB   _VXPRT_SCMPI_A
        CMP   AL, 'z'
        JA   _VXPRT_SCMPI_A
        SUB   AL, 32
_VXPRT_SCMPI_A:
        CMP   BL, 'a'
        JB   _VXPRT_SCMPI_B
        CMP   BL, 'z'
        JA   _VXPRT_SCMPI_B
        SUB   BL, 32
_VXPRT_SCMPI_B:
        CMP   AL, BL
        JNE   _VXPRT_SCMPI_NE
        CMP   AL, 0
        JE   _VXPRT_SCMPI_EQ
        INC    SI
        INC    DI
        JMP   _VXPRT_SCMPI_LP
_VXPRT_SCMPI_EQ:
        XOR   AX, AX
        JMP   _VXPRT_SCMPI_DONE
_VXPRT_SCMPI_NE:
        XOR   AH, AH
        SUB   AL, BL
        CBW
_VXPRT_SCMPI_DONE:
        POP   BX
        POP   DI
        POP   SI
        RET

; UPPERCASE : SI=chaine ASCIIZ -> convertit en majuscules, AX=SI
_VXPRT_UPPERCASE:
        PUSH   SI
        PUSH   DI
        LEA   DI, _VXPRT_STRBUF
        MOV   AX, DI
        PUSH   AX
_VXPRT_UC_LP:
        MOV   AL, [SI]
        CMP   AL, 0
        JE   _VXPRT_UC_DONE
        CMP   AL, 'a'
        JB   _VXPRT_UC_STORE
        CMP   AL, 'z'
        JA   _VXPRT_UC_STORE
        AND   AL, 0DFh
_VXPRT_UC_STORE:
        MOV   [DI], AL
        INC    SI
        INC    DI
        JMP   _VXPRT_UC_LP
_VXPRT_UC_DONE:
        MOV   BYTE PTR [DI], 0
        POP   AX
        POP   DI
        POP   SI
        RET

; LOWERCASE : SI=chaine ASCIIZ -> convertit en minuscules, AX=STRBUF
_VXPRT_LOWERCASE:
        PUSH   SI
        PUSH   DI
        LEA   DI, _VXPRT_STRBUF
        MOV   AX, DI
        PUSH   AX
_VXPRT_LC_LP:
        MOV   AL, [SI]
        CMP   AL, 0
        JE   _VXPRT_LC_DONE
        CMP   AL, 'A'
        JB   _VXPRT_LC_STORE
        CMP   AL, 'Z'
        JA   _VXPRT_LC_STORE
        OR   AL, 20h
_VXPRT_LC_STORE:
        MOV   [DI], AL
        INC    SI
        INC    DI
        JMP   _VXPRT_LC_LP
_VXPRT_LC_DONE:
        MOV   BYTE PTR [DI], 0
        POP   AX
        POP   DI
        POP   SI
        RET

; VERIFY : SI=str, DI=charset -> AX=pos (1-base) ou 0
_VXPRT_VERIFY:
        PUSH   BX
        PUSH   CX
        PUSH   SI
        XOR   CX, CX
_VXPRT_VER_LP:
        INC    CX
        MOV   AL, [SI]
        CMP   AL, 0
        JE   _VXPRT_VER_OK
        PUSH   DI
_VXPRT_VER_CHK:
        MOV   BL, [DI]
        CMP   BL, 0
        JE   _VXPRT_VER_FOUND
        CMP   AL, BL
        JE   _VXPRT_VER_MATCH
        INC    DI
        JMP   _VXPRT_VER_CHK
_VXPRT_VER_MATCH:
        POP   DI
        INC    SI
        JMP   _VXPRT_VER_LP
_VXPRT_VER_FOUND:
        POP   DI
        MOV   AX, CX
        JMP   _VXPRT_VER_DONE
_VXPRT_VER_OK:
        XOR   AX, AX
_VXPRT_VER_DONE:
        POP   SI
        POP   CX
        POP   BX
        RET

; TRIM : SI=chaine -> AX=STRBUF (espaces de fin supprimes)
_VXPRT_TRIM:
        PUSH   SI
        PUSH   DI
        PUSH   BX
        LEA   DI, _VXPRT_STRBUF
        MOV   BX, DI
_VXPRT_TRIM_CP:
        LODSB
        STOSB
        CMP   AL, 0
        JNE   _VXPRT_TRIM_CP
        DEC    DI
_VXPRT_TRIM_LP:
        CMP   DI, BX
        JBE   _VXPRT_TRIM_DONE
        DEC    DI
        CMP   BYTE PTR [DI], ' '
        JE   _VXPRT_TRIM_LP
        INC    DI
_VXPRT_TRIM_DONE:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _VXPRT_STRBUF
        POP   BX
        POP   DI
        POP   SI
        RET

; PAD : SI=str, BX=char, CX=len -> AX=STRBUF
_VXPRT_PAD:
        PUSH   SI
        PUSH   DI
        PUSH   CX
        LEA   DI, _VXPRT_STRBUF
_VXPRT_PAD_CP:
        MOV   AL, [SI]
        CMP   AL, 0
        JE   _VXPRT_PAD_FILL
        MOV   [DI], AL
        INC    SI
        INC    DI
        DEC    CX
        CMP   CX, 0
        JLE   _VXPRT_PAD_END
        JMP   _VXPRT_PAD_CP
_VXPRT_PAD_FILL:
        CMP   CX, 0
        JLE   _VXPRT_PAD_END
        MOV   AL, BL
_VXPRT_PAD_FLP:
        MOV   [DI], AL
        INC    DI
        DEC    CX
        JNZ   _VXPRT_PAD_FLP
_VXPRT_PAD_END:
        MOV   BYTE PTR [DI], 0
        POP   CX
        POP   DI
        POP   SI
        LEA   AX, _VXPRT_STRBUF
        RET

; DELETE : SI=str, BX=pos, CX=len - supprime in-place
_VXPRT_DELETE:
        PUSH   SI
        PUSH   DI
        PUSH   BX
        PUSH   CX
        DEC    BX
        MOV   DI, SI
        ADD   DI, BX
        MOV   SI, DI
        ADD   SI, CX
_VXPRT_DEL_LP:
        LODSB
        STOSB
        CMP   AL, 0
        JNE   _VXPRT_DEL_LP
        POP   CX
        POP   BX
        POP   DI
        POP   SI
        RET

; INSERT : SI=sub, DI=target, BX=pos - insere dans target
_VXPRT_INSERT:
        PUSH   AX
        PUSH   BX
        PUSH   CX
        PUSH   SI
        PUSH   DI
        PUSH   SI
        XOR   CX, CX
_VXPRT_INS_SLEN:
        CMP   BYTE PTR [SI], 0
        JE   _VXPRT_INS_SLEN_D
        INC    CX
        INC    SI
        JMP   _VXPRT_INS_SLEN
_VXPRT_INS_SLEN_D:
        POP   SI
        PUSH   DI
        XOR   AX, AX
_VXPRT_INS_TLEN:
        CMP   BYTE PTR [DI], 0
        JE   _VXPRT_INS_TLEN_D
        INC    AX
        INC    DI
        JMP   _VXPRT_INS_TLEN
_VXPRT_INS_TLEN_D:
        POP   DI
        PUSH   CX
        PUSH   SI
        MOV   SI, DI
        ADD   SI, AX
        PUSH   DI
        MOV   DI, SI
        ADD   DI, CX
        MOV   CX, AX
        DEC    BX
        SUB   CX, BX
        INC    CX
        STD
        REP    MOVSB
        CLD
        POP   DI
        POP   SI
        POP   CX
        ADD   DI, BX
_VXPRT_INS_CPY:
        CMP   CX, 0
        JE   _VXPRT_INS_DONE
        MOV   AL, [SI]
        MOV   [DI], AL
        INC    SI
        INC    DI
        DEC    CX
        JMP   _VXPRT_INS_CPY
_VXPRT_INS_DONE:
        POP   DI
        POP   SI
        POP   CX
        POP   BX
        POP   AX
        RET

; MESSAGE : SI=chaine -> ecriture sur stderr
_VXPRT_MESSAGE:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        PUSH   SI
        MOV   DX, SI
        XOR   CX, CX
_VXPRT_MSG_LEN:
        CMP   BYTE PTR [SI], 0
        JE   _VXPRT_MSG_WR
        INC    CX
        INC    SI
        JMP   _VXPRT_MSG_LEN
_VXPRT_MSG_WR:
        MOV   BX, 2
        MOV   AH, 40h
        INT    21h
        POP   SI
        POP   DX
        POP   CX
        POP   BX
        RET

; VAL : SI=chaine -> AX=nombre, BX=err (0 si ok)
_VXPRT_VAL:
        PUSH   CX
        PUSH   DX
        XOR   AX, AX
        XOR   BX, BX
        XOR   CX, CX
        CMP   BYTE PTR [SI], '-'
        JNE   _VXPRT_VAL_PLUS
        MOV   CX, 1
        INC    SI
_VXPRT_VAL_PLUS:
        CMP   BYTE PTR [SI], '+'
        JNE   _VXPRT_VAL_LP
        INC    SI
_VXPRT_VAL_LP:
        MOV   DL, [SI]
        CMP   DL, 0
        JE   _VXPRT_VAL_DONE
        CMP   DL, '0'
        JB   _VXPRT_VAL_ERR
        CMP   DL, '9'
        JA   _VXPRT_VAL_ERR
        SUB   DL, '0'
        PUSH   DX
        MOV   DX, 10
        MUL   DX
        POP   DX
        XOR   DH, DH
        ADD   AX, DX
        INC    SI
        JMP   _VXPRT_VAL_LP
_VXPRT_VAL_ERR:
        MOV   BX, 1
_VXPRT_VAL_DONE:
        CMP   CX, 0
        JE   _VXPRT_VAL_RET
        NEG    AX
_VXPRT_VAL_RET:
        POP   DX
        POP   CX
        RET

; DATE : INT 21h/2Ah -> DATEBUF ASCIIZ
_VXPRT_DATE:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        PUSH   DI
        MOV   AH, 2Ah
        INT    21h
        LEA   DI, _VXPRT_DATEBUF
        XOR   AH, AH
        MOV   AL, DL
        PUSH   DX
        PUSH   CX
        MOV   BL, 10
        XOR   AH, AH
        DIV   BL
        ADD   AL, '0'
        ADD   AH, '0'
        MOV   [DI], AL
        MOV   [DI+1], AH
        MOV   BYTE PTR [DI+2], '-'
        ADD   DI, 3
        POP   CX
        POP   DX
        MOV   AL, DH
        XOR   AH, AH
        PUSH   CX
        MOV   BL, 10
        DIV   BL
        ADD   AL, '0'
        ADD   AH, '0'
        MOV   [DI], AL
        MOV   [DI+1], AH
        MOV   BYTE PTR [DI+2], '-'
        ADD   DI, 3
        POP   AX
        CALL   _VXPRT_NUMTOSTR
        PUSH   SI
        LEA   SI, _VXPRT_NUMBUF
_VXPRT_DATE_YR:
        LODSB
        CMP   AL, 0
        JE   _VXPRT_DATE_END
        STOSB
        JMP   _VXPRT_DATE_YR
_VXPRT_DATE_END:
        MOV   BYTE PTR [DI], 0
        POP   SI
        POP   DI
        POP   DX
        POP   CX
        POP   BX
        RET

; TIME : INT 21h/2Ch -> TIMEBUF ASCIIZ
_VXPRT_TIME:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        PUSH   DI
        MOV   AH, 2Ch
        INT    21h
        LEA   DI, _VXPRT_TIMEBUF
        MOV   AL, CH
        XOR   AH, AH
        PUSH   CX
        PUSH   DX
        MOV   BL, 10
        DIV   BL
        ADD   AL, '0'
        ADD   AH, '0'
        MOV   [DI], AL
        MOV   [DI+1], AH
        MOV   BYTE PTR [DI+2], ':'
        ADD   DI, 3
        POP   DX
        POP   CX
        MOV   AL, CL
        XOR   AH, AH
        PUSH   DX
        MOV   BL, 10
        DIV   BL
        ADD   AL, '0'
        ADD   AH, '0'
        MOV   [DI], AL
        MOV   [DI+1], AH
        MOV   BYTE PTR [DI+2], ':'
        ADD   DI, 3
        POP   DX
        MOV   AL, DH
        XOR   AH, AH
        MOV   BL, 10
        DIV   BL
        ADD   AL, '0'
        ADD   AH, '0'
        MOV   [DI], AL
        MOV   [DI+1], AH
        MOV   BYTE PTR [DI+2], 0
        POP   DI
        POP   DX
        POP   CX
        POP   BX
        RET

; CLOCK : INT 21h/2Ch -> AX = centisecondes depuis minuit
_VXPRT_CLOCK:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        MOV   AH, 2Ch
        INT    21h
        XOR   AX, AX
        MOV   AL, CH
        MOV   BX, 3600
        MUL   BX
        PUSH   AX
        XOR   AX, AX
        MOV   AL, CL
        MOV   BX, 60
        MUL   BX
        POP   BX
        ADD   AX, BX
        XOR   BX, BX
        MOV   BL, DH
        ADD   AX, BX
        MOV   BX, 100
        MUL   BX
        XOR   BX, BX
        MOV   BL, DL
        ADD   AX, BX
        POP   DX
        POP   CX
        POP   BX
        RET

; WALLCLOCK : INT 21h/2Ch -> AX = secondes depuis minuit
_VXPRT_WALLCLOCK:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        MOV   AH, 2Ch
        INT    21h
        XOR   AX, AX
        MOV   AL, CH
        MOV   BX, 3600
        MUL   BX
        PUSH   AX
        XOR   AX, AX
        MOV   AL, CL
        MOV   BX, 60
        MUL   BX
        POP   BX
        ADD   AX, BX
        XOR   BX, BX
        MOV   BL, DH
        ADD   AX, BX
        POP   DX
        POP   CX
        POP   BX
        RET

; FWRSTR : ecrire ASCIIZ [SI] vers fichier CURHDL
_VXPRT_FWRSTR:
        PUSH   AX
        PUSH   BX
        PUSH   CX
        PUSH   DX
        PUSH   DI
        MOV   DI, SI
        XOR   CX, CX
_VXPRT_FWRL:
        CMP   BYTE PTR [DI], 0
        JE   _VXPRT_FWRD
        INC   DI
        INC   CX
        JMP   _VXPRT_FWRL
_VXPRT_FWRD:
        MOV   DX, SI
        MOV   BX, WORD PTR [_VXPRT_CURHDL]
        MOV   AH, 40h
        INT    21h
        POP   DI
        POP   DX
        POP   CX
        POP   BX
        POP   AX
        RET

; FRDCHAR : lire 1 char depuis fichier CURHDL -> AL
_VXPRT_FRDCHAR:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        MOV   BX, WORD PTR [_VXPRT_CURHDL]
        LEA   DX, _VXPRT_FRDCBUF
        MOV   CX, 1
        MOV   AH, 3Fh
        INT    21h
        MOV   AL, BYTE PTR [_VXPRT_FRDCBUF]
        POP   DX
        POP   CX
        POP   BX
        RET

; FRDNUM : lire entier depuis fichier CURHDL -> AX
_VXPRT_FRDNUM:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        PUSH   SI
        XOR   SI, SI
        XOR   CX, CX
_VXPRT_FRNL:
        MOV   BX, WORD PTR [_VXPRT_CURHDL]
        LEA   DX, _VXPRT_FRDCBUF
        PUSH   CX
        MOV   CX, 1
        MOV   AH, 3Fh
        INT    21h
        POP   CX
        CMP   AX, 0
        JE   _VXPRT_FRND
        MOV   AL, BYTE PTR [_VXPRT_FRDCBUF]
        CMP   AL, ' '
        JE   _VXPRT_FRNL
        CMP   AL, 13
        JE   _VXPRT_FRNL
        CMP   AL, 10
        JE   _VXPRT_FRNL
        CMP   AL, 9
        JE   _VXPRT_FRNL
        CMP   AL, '-'
        JNE   _VXPRT_FRNA
        MOV   CX, 1
        JMP   _VXPRT_FRNL
_VXPRT_FRNA:
        CMP   AL, '0'
        JB   _VXPRT_FRND
        CMP   AL, '9'
        JA   _VXPRT_FRND
        SUB   AL, '0'
        XOR   AH, AH
        XCHG   AX, SI
        MOV   BX, 10
        MUL   BX
        ADD   AX, SI
        MOV   SI, AX
        JMP   _VXPRT_FRNL
_VXPRT_FRND:
        MOV   AX, SI
        CMP   CX, 0
        JE   _VXPRT_FRNP
        NEG   AX
_VXPRT_FRNP:
        POP   SI
        POP   DX
        POP   CX
        POP   BX
        RET

; FEOF : tester EOF sur handle BX -> AX
_VXPRT_FEOF:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        LEA   DX, _VXPRT_FRDCBUF
        MOV   CX, 1
        MOV   AH, 3Fh
        INT    21h
        CMP   AX, 0
        JE   _VXPRT_FEYE
        POP   DX
        POP   CX
        POP   BX
        PUSH   BX
        PUSH   CX
        PUSH   DX
        MOV   AX, 4201h
        MOV   CX, 0FFFFh
        MOV   DX, 0FFFFh
        INT    21h
        XOR   AX, AX
        JMP   _VXPRT_FEDN
_VXPRT_FEYE:
        MOV   AX, 1
_VXPRT_FEDN:
        POP   DX
        POP   CX
        POP   BX
        RET

; FEOLN : tester EOLN sur handle BX -> AX
_VXPRT_FEOLN:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        LEA   DX, _VXPRT_FRDCBUF
        MOV   CX, 1
        MOV   AH, 3Fh
        INT    21h
        CMP   AX, 0
        JE   _VXPRT_FELY
        MOV   AL, BYTE PTR [_VXPRT_FRDCBUF]
        CMP   AL, 10
        JE   _VXPRT_FELY
        CMP   AL, 13
        JE   _VXPRT_FELY
        POP   DX
        POP   CX
        POP   BX
        PUSH   BX
        PUSH   CX
        PUSH   DX
        MOV   AX, 4201h
        MOV   CX, 0FFFFh
        MOV   DX, 0FFFFh
        INT    21h
        XOR   AX, AX
        JMP   _VXPRT_FELDN
_VXPRT_FELY:
        MOV   AX, 1
_VXPRT_FELDN:
        POP   DX
        POP   CX
        POP   BX
        RET

; PANIC : affiche msg [SI] et termine (INT 21h/4Ch)
_VXPRT_PANIC:
        MOV   AH, 40h
        MOV   BX, 2
        PUSH   SI
        MOV   DI, SI
        XOR   CX, CX
_VXPRT_PNKL:
        CMP   BYTE PTR [DI], 0
        JE   _VXPRT_PNKD
        INC   DI
        INC   CX
        JMP   _VXPRT_PNKL
_VXPRT_PNKD:
        POP   DX
        MOV   AH, 40h
        MOV   BX, 2
        INT    21h
        MOV   DX, OFFSET _VXPRT_CRLF
        MOV   CX, 2
        MOV   AH, 40h
        MOV   BX, 2
        INT    21h
        MOV   AX, 4C01h
        INT    21h

; PANIC_DIV0 : division par zero
_VXPRT_PANIC_DIV0:
        MOV   SI, OFFSET _VXPRT_DIV0MSG
        CMP   WORD PTR [_VXPRT_EXCHDL], 0
        JE   _VXPRT_PD0F
        MOV   WORD PTR [_VXPRT_EXCCODE], 3
        MOV   SP, WORD PTR [_VXPRT_EXCSP]
        MOV   BP, WORD PTR [_VXPRT_EXCBP]
        JMP   WORD PTR [_VXPRT_EXCHDL]
_VXPRT_PD0F:
        CALL   _VXPRT_PANIC

; PANIC_OVF : integer overflow
_VXPRT_PANIC_OVF:
        MOV   SI, OFFSET _VXPRT_OVFMSG
        CMP   WORD PTR [_VXPRT_EXCHDL], 0
        JE   _VXPRT_POVF
        MOV   WORD PTR [_VXPRT_EXCCODE], 2
        MOV   SP, WORD PTR [_VXPRT_EXCSP]
        MOV   BP, WORD PTR [_VXPRT_EXCBP]
        JMP   WORD PTR [_VXPRT_EXCHDL]
_VXPRT_POVF:
        CALL   _VXPRT_PANIC

; PANIC_RNG : range check error
_VXPRT_PANIC_RNG:
        MOV   SI, OFFSET _VXPRT_RNGMSG
        CMP   WORD PTR [_VXPRT_EXCHDL], 0
        JE   _VXPRT_PRNG
        MOV   WORD PTR [_VXPRT_EXCCODE], 6
        MOV   SP, WORD PTR [_VXPRT_EXCSP]
        MOV   BP, WORD PTR [_VXPRT_EXCBP]
        JMP   WORD PTR [_VXPRT_EXCHDL]
_VXPRT_PRNG:
        CALL   _VXPRT_PANIC

; PANIC_NIL : nil pointer dereference
_VXPRT_PANIC_NIL:
        MOV   SI, OFFSET _VXPRT_NILMSG
        CMP   WORD PTR [_VXPRT_EXCHDL], 0
        JE   _VXPRT_PNIL
        MOV   WORD PTR [_VXPRT_EXCCODE], 1
        MOV   SP, WORD PTR [_VXPRT_EXCSP]
        MOV   BP, WORD PTR [_VXPRT_EXCBP]
        JMP   WORD PTR [_VXPRT_EXCHDL]
_VXPRT_PNIL:
        CALL   _VXPRT_PANIC

; SIGNAL : lever condition, code dans AX
_VXPRT_SIGNAL:
        MOV   WORD PTR [_VXPRT_EXCCODE], AX
        CMP   WORD PTR [_VXPRT_EXCHDL], 0
        JE   _VXPRT_SIGF
        MOV   SP, WORD PTR [_VXPRT_EXCSP]
        MOV   BP, WORD PTR [_VXPRT_EXCBP]
        JMP   WORD PTR [_VXPRT_EXCHDL]
_VXPRT_SIGF:
        MOV   SI, OFFSET _VXPRT_SIGMSG
        CALL   _VXPRT_PANIC

; EXCMSG : retourne msg exception dans SI
_VXPRT_EXCMSG:
        MOV   AX, WORD PTR [_VXPRT_EXCCODE]
        CMP   AX, 1
        JE   _VXPRT_EM01
        CMP   AX, 2
        JE   _VXPRT_EM02
        CMP   AX, 3
        JE   _VXPRT_EM03
        CMP   AX, 6
        JE   _VXPRT_EM06
        MOV   SI, OFFSET _VXPRT_SIGMSG
        RET
_VXPRT_EM01:
        MOV   SI, OFFSET _VXPRT_NILMSG
        RET
_VXPRT_EM02:
        MOV   SI, OFFSET _VXPRT_OVFMSG
        RET
_VXPRT_EM03:
        MOV   SI, OFFSET _VXPRT_DIV0MSG
        RET
_VXPRT_EM06:
        MOV   SI, OFFSET _VXPRT_RNGMSG
        RET

; PRINTINT : affiche entier signe AX
_VXPRT_PRINTINT:
        CALL   _VXPRT_NUMTOSTR
        LEA   SI, _VXPRT_NUMBUF
        CALL   _VXPRT_PRINTSTR
        RET

; PRINTUINT : affiche entier non signe AX
_VXPRT_PRINTUINT:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        PUSH   DI
        MOV   DI, OFFSET _VXPRT_NUMBUF
        ADD   DI, 10
        MOV   BYTE PTR [DI], 0
        DEC    DI
        MOV   BX, 10
_VXPRT_PU_LP:
        XOR   DX, DX
        DIV   BX
        ADD   DL, '0'
        MOV   [DI], DL
        DEC    DI
        CMP   AX, 0
        JNE   _VXPRT_PU_LP
        INC    DI
        MOV   SI, DI
        CALL   _VXPRT_PRINTSTR
        POP   DI
        POP   DX
        POP   CX
        POP   BX
        RET

; PRINTLN : affiche retour a la ligne CRLF
_VXPRT_PRINTLN:
        MOV   DL, 13
        MOV   AH, 02h
        INT    21h
        MOV   DL, 10
        MOV   AH, 02h
        INT    21h
        RET

; PRINTCHAR : affiche caractere AL
_VXPRT_PRINTCHAR:
        MOV   DL, AL
        MOV   AH, 02h
        INT    21h
        RET

; PRINTBOOL : affiche True si AX<>0, sinon False
_VXPRT_PRINTBOOL:
        CMP   AX, 0
        JE   _VXPRT_PB_F
        LEA   SI, _VXPRT_TRUE_S
        JMP   _VXPRT_PB_P
_VXPRT_PB_F:
        LEA   SI, _VXPRT_FALSE_S
_VXPRT_PB_P:
        CALL   _VXPRT_PRINTSTR
        RET

; PRINTREAL : stub - affiche AX comme entier
_VXPRT_PRINTREAL:
        CALL   _VXPRT_PRINTINT
        RET

; READINT : lire entier signe -> AX (alias READNUM)
_VXPRT_READINT:
        JMP   _VXPRT_READNUM

; READLINE : lire ligne -> STRBUF, AX = pointeur
_VXPRT_READLINE:
        PUSH   BX
        MOV   BX, OFFSET _VXPRT_STRBUF
_VXPRT_RL_LP:
        MOV   AH, 01h
        INT    21h
        CMP   AL, 13
        JE   _VXPRT_RL_DN
        CMP   AL, 10
        JE   _VXPRT_RL_DN
        MOV   [BX], AL
        INC    BX
        JMP   _VXPRT_RL_LP
_VXPRT_RL_DN:
        MOV   BYTE PTR [BX], 0
        LEA   AX, _VXPRT_STRBUF
        POP   BX
        RET

; READSTR : alias READLINE
_VXPRT_READSTR:
        JMP   _VXPRT_READLINE

; SEARCH : alias INDEX
_VXPRT_SEARCH:
        JMP   _VXPRT_INDEX

; VARY_ASSIGN : copie ASCIIZ SI -> VARYING [DI]
_VXPRT_VARY_ASSIGN:
        PUSH   BX
        PUSH   CX
        XOR   CX, CX
        LEA   BX, [DI+2]
_VXPRT_VA_LP:
        MOV   AL, [SI]
        CMP   AL, 0
        JE   _VXPRT_VA_DN
        MOV   [BX], AL
        INC    SI
        INC    BX
        INC    CX
        JMP   _VXPRT_VA_LP
_VXPRT_VA_DN:
        MOV   BYTE PTR [BX], 0
        MOV   WORD PTR [DI], CX
        POP   CX
        POP   BX
        RET

; VARY_CONCAT : VARYING SI + VARYING DI -> STRBUF
_VXPRT_VARY_CONCAT:
        PUSH   BX
        PUSH   CX
        MOV   BX, OFFSET _VXPRT_STRBUF
        MOV   CX, WORD PTR [SI]
        ADD   SI, 2
_VXPRT_VC1:
        CMP   CX, 0
        JE   _VXPRT_VC2S
        MOV   AL, [SI]
        MOV   [BX], AL
        INC    SI
        INC    BX
        DEC    CX
        JMP   _VXPRT_VC1
_VXPRT_VC2S:
        MOV   CX, WORD PTR [DI]
        ADD   DI, 2
_VXPRT_VC2:
        CMP   CX, 0
        JE   _VXPRT_VCDN
        MOV   AL, [DI]
        MOV   [BX], AL
        INC    DI
        INC    BX
        DEC    CX
        JMP   _VXPRT_VC2
_VXPRT_VCDN:
        MOV   BYTE PTR [BX], 0
        LEA   AX, _VXPRT_STRBUF
        POP   CX
        POP   BX
        RET

; VARY_LENGTH : VARYING [SI] -> AX = longueur
_VXPRT_VARY_LENGTH:
        MOV   AX, WORD PTR [SI]
        RET

; VARY_BODY : VARYING [SI] -> AX = pointeur body
_VXPRT_VARY_BODY:
        LEA   AX, [SI+2]
        RET

; VARY_SUBSTR : VARYING[SI], start BX, len CX -> STRBUF
_VXPRT_VARY_SUBSTR:
        PUSH   DI
        ADD   SI, 2
        DEC    BX
        ADD   SI, BX
        MOV   DI, OFFSET _VXPRT_STRBUF
_VXPRT_VSB_LP:
        CMP   CX, 0
        JE   _VXPRT_VSB_DN
        MOV   AL, [SI]
        MOV   [DI], AL
        INC    SI
        INC    DI
        DEC    CX
        JMP   _VXPRT_VSB_LP
_VXPRT_VSB_DN:
        MOV   BYTE PTR [DI], 0
        LEA   AX, _VXPRT_STRBUF
        POP   DI
        RET

; VARY_CMP : compare VARYING [SI] vs [DI] -> AX
_VXPRT_VARY_CMP:
        PUSH   BX
        PUSH   CX
        MOV   CX, WORD PTR [SI]
        MOV   BX, WORD PTR [DI]
        ADD   SI, 2
        ADD   DI, 2
        CMP   CX, BX
        JLE   _VXPRT_VCMP_MN
        MOV   CX, BX
_VXPRT_VCMP_MN:
_VXPRT_VCMP_LP:
        CMP   CX, 0
        JE   _VXPRT_VCMP_LN
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _VXPRT_VCMP_NE
        INC    SI
        INC    DI
        DEC    CX
        JMP   _VXPRT_VCMP_LP
_VXPRT_VCMP_NE:
        XOR   AH, AH
        SUB   AL, [DI]
        CBW
        JMP   _VXPRT_VCMP_RT
_VXPRT_VCMP_LN:
        MOV   AX, WORD PTR [SI-2]
        SUB   SI, 2
        SUB   DI, 2
        MOV   AX, WORD PTR [SI]
        SUB   AX, WORD PTR [DI]
_VXPRT_VCMP_RT:
        POP   CX
        POP   BX
        RET

; POWI : AX ^ BX -> AX
_VXPRT_POWI:
        PUSH   CX
        PUSH   DX
        MOV   CX, BX
        MOV   DX, AX
        MOV   AX, 1
        CMP   CX, 0
        JE   _VXPRT_PWI_DN
_VXPRT_PWI_LP:
        MUL   DX
        DEC    CX
        JNZ   _VXPRT_PWI_LP
_VXPRT_PWI_DN:
        POP   DX
        POP   CX
        RET

; SETSEED : AX -> graine RANDOM
_VXPRT_SETSEED:
        MOV   WORD PTR [_VXPRT_SEED], AX
        RET

; ABS : |AX| -> AX
_VXPRT_ABS:
        CMP   AX, 0
        JGE   _VXPRT_ABS_DN
        NEG    AX
_VXPRT_ABS_DN:
        RET

; SQR : AX*AX -> AX
_VXPRT_SQR:
        IMUL   AX
        RET

; MAX : max(AX, BX) -> AX
_VXPRT_MAX:
        CMP   AX, BX
        JGE   _VXPRT_MAX_DN
        MOV   AX, BX
_VXPRT_MAX_DN:
        RET

; MIN : min(AX, BX) -> AX
_VXPRT_MIN:
        CMP   AX, BX
        JLE   _VXPRT_MIN_DN
        MOV   AX, BX
_VXPRT_MIN_DN:
        RET

; ZERO : zero CX octets a [DI]
_VXPRT_ZERO:
        XOR   AL, AL
        REP    STOSB
        RET

; FILL : remplir CX octets a [DI] avec AL
_VXPRT_FILL:
        REP    STOSB
        RET

; FOPEN : DX = nom, AL = mode (0=lect,1=ecr,2=rw) -> AX handle
_VXPRT_FOPEN:
        MOV   AH, 3Dh
        INT    21h
        JNC   _VXPRT_FO_OK
        MOV   AX, 0FFFFh
_VXPRT_FO_OK:
        RET

; FCREATE : DX = nom -> AX handle
_VXPRT_FCREATE:
        MOV   AH, 3Ch
        XOR   CX, CX
        INT    21h
        JNC   _VXPRT_FC_OK
        MOV   AX, 0FFFFh
_VXPRT_FC_OK:
        RET

; FCLOSE : BX = handle
_VXPRT_FCLOSE:
        MOV   AH, 3Eh
        INT    21h
        RET

; FREAD : BX=handle, CX=taille, DX=buffer -> AX=lus
_VXPRT_FREAD:
        MOV   AH, 3Fh
        INT    21h
        JNC   _VXPRT_FR_OK
        XOR   AX, AX
_VXPRT_FR_OK:
        RET

; FWRITE : BX=handle, CX=taille, DX=buffer -> AX=ecrits
_VXPRT_FWRITE:
        MOV   AH, 40h
        INT    21h
        JNC   _VXPRT_FW_OK
        XOR   AX, AX
_VXPRT_FW_OK:
        RET

; FDELETE : DX = nom fichier ASCIIZ
_VXPRT_FDELETE:
        MOV   AH, 41h
        INT    21h
        RET

; ASSERT : AX<>0 ou panic avec message SI
_VXPRT_ASSERT:
        CMP   AX, 0
        JNE   _VXPRT_ASS_OK
        LEA   SI, _VXPRT_ASSERTMSG
        CALL   _VXPRT_PRINTSTR
        CALL   _VXPRT_PRINTLN
        MOV   AH, 4Ch
        MOV   AL, 1
        INT    21h
_VXPRT_ASS_OK:
        RET

; RESIGNAL : propager condition au handler parent
_VXPRT_RESIGNAL:
        CMP   WORD PTR [_VXPRT_EXCHDL], 0
        JE   _VXPRT_RSG_PK
        MOV   SP, WORD PTR [_VXPRT_EXCSP]
        MOV   BP, WORD PTR [_VXPRT_EXCBP]
        JMP   WORD PTR [_VXPRT_EXCHDL]
_VXPRT_RSG_PK:
        LEA   SI, _VXPRT_SIGMSG
        JMP   _VXPRT_PANIC

; VMS_STUB : stub generique VMS (AX = nom)
_VXPRT_VMS_STUB:
        MOV   SI, AX
        CALL   _VXPRT_PRINTSTR
        CALL   _VXPRT_PRINTLN
        MOV   AX, 1
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
_VXPRT_SETBUF  DB  32 DUP(0)
_VXPRT_DATEBUF DB  16 DUP(0)
_VXPRT_TIMEBUF DB  12 DUP(0)
_VXPRT_ASSERTMSG DB 'Assertion failed',0

; --- File Descriptor Blocks predefinis ---
_VXP_INPUT   DW  0
        DW  1
        DB  'CON',0
        DB  124 DUP(0)
_VXP_OUTPUT  DW  1
        DW  2
        DB  'CON',0
        DB  124 DUP(0)
_VXP_TTY     DW  0
        DW  1
        DB  'CON',0
        DB  124 DUP(0)
_VXP_TTYOUTPUT DW  1
        DW  2
        DB  'CON',0
        DB  124 DUP(0)
_VXP_ERROR   DW  2
        DW  2
        DB  'CON',0
        DB  124 DUP(0)
_VXPRT_CURHDL  DW  1
_VXPRT_IOSTATUS DW  0
_VXPRT_FNAMEBUF DB  128 DUP(0)
_VXPRT_FRDCBUF DB  2 DUP(0)

; --- Exception handler frame ---
_VXPRT_EXCHDL  DW  0
_VXPRT_EXCSP   DW  0
_VXPRT_EXCBP   DW  0
_VXPRT_EXCCODE DW  0
_VXPRT_EXCVAL  DW  0
_VXPRT_EXCPHDL DW  0
_VXPRT_EXCPSP  DW  0
_VXPRT_EXCPBP  DW  0
; --- Messages d erreur runtime ---
_VXPRT_DIV0MSG DB  'Runtime error: Division by zero',0
_VXPRT_OVFMSG  DB  'Runtime error: Integer overflow',0
_VXPRT_RNGMSG  DB  'Runtime error: Range check error',0
_VXPRT_NILMSG  DB  'Runtime error: Nil pointer dereference',0
_VXPRT_SIGMSG  DB  'Runtime error: Unhandled condition',0

; --- Donnees du programme ---
_VXPK_4  DB  'Point : (',0
_VXPK_5  DB  ', ',0
_VXPK_6  DB  ') id=',0
_VXPK_9  DB  'Test parametres nommes termine.',0
_DATA   ENDS

        END     _VXPF_MAIN
