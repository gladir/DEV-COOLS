; =========================================================
; Genere par KOTLIN86 v1.0 (2026-03-07)
; Source  : SAMPLES/KOTLIN/test_expr.kt
; Cible   : MASM 8086, modele SMALL
; =========================================================

        .8086
        DOSSEG
        .MODEL SMALL
        .STACK 1024

_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME CS:_TEXT, DS:_DATA, SS:NOTHING

; -- Point d'entree : fun main() --
_KTF_main:
        PUSH BP
        MOV BP, SP
        PUSH SI
        PUSH DI
; -- Initialiser DS sur le segment de donnees --
        MOV AX, _DATA
        MOV DS, AX

        MOV AX, 42
        MOV [_KTV_x], AX
        MOV AX, [_KTV_x]
        PUSH AX
        MOV AX, 10
        MOV BX, AX
        POP AX
        ADD AX, BX
        MOV [_KTV_y], AX
        LEA AX, _KTK_16
        MOV [_KTV_name], AX
        MOV AX, 1
        MOV [_KTV_flag], AX
        MOV AX, 0
        MOV [_KTV_nothing], AX
        MOV AX, 65
        MOV [_KTV_c], AX
        MOV AX, [_KTV_x]
        PUSH AX
        MOV AX, [_KTV_y]
        MOV BX, AX
        POP AX
        ADD AX, BX
        PUSH AX
        MOV AX, 2
        MOV BX, AX
        POP AX
        IMUL BX
        MOV [_KTV_sum], AX

; -- Fin de programme : DOS exit --
        MOV AX, 4C00h
        INT 21h

        POP DI
        POP SI
        MOV SP, BP
        POP BP
        RET


; =========================================================
; RUNTIME MINIMAL KOTLIN86
; =========================================================

; --- _KTRT_CONCAT : concatenation de chaines ---
; SI = str1 (ASCIIZ), DI = str2 (ASCIIZ) -> AX = ptr buf
_KTRT_CONCAT:
        PUSH SI
        PUSH DI
        PUSH CX
        MOV BX, DI
        MOV DI, OFFSET _KT_STRBUF
; Copier str1 dans le buffer
_KTRT_CC1:
        LODSB
        TEST AL, AL
        JZ _KTRT_CC2
        STOSB
        JMP _KTRT_CC1
_KTRT_CC2:
; Copier str2 dans le buffer
        MOV SI, BX
_KTRT_CC3:
        LODSB
        STOSB
        TEST AL, AL
        JNZ _KTRT_CC3
        MOV AX, OFFSET _KT_STRBUF
        POP CX
        POP DI
        POP SI
        RET

; --- _KTRT_STRCMP : comparaison de chaines ---
; SI = str1, DI = str2 -> AX = -1/0/+1
_KTRT_STRCMP:
        PUSH SI
        PUSH DI
_KTRT_SC1:
        LODSB
        MOV AH, [DI]
        INC DI
        CMP AL, AH
        JNE _KTRT_SC2
        TEST AL, AL
        JNZ _KTRT_SC1
; Les chaines sont egales
        XOR AX, AX
        POP DI
        POP SI
        RET
_KTRT_SC2:
        JA _KTRT_SC3
; str1 < str2
        MOV AX, -1
        POP DI
        POP SI
        RET
_KTRT_SC3:
; str1 > str2
        MOV AX, 1
        POP DI
        POP SI
        RET

; =========================================================
; TODO 12 - RUNTIME E/S KOTLIN86
; =========================================================

; --- _KTRT_STRLEN : SI = str ASCIIZ -> CX = longueur ---
_KTRT_STRLEN:
        PUSH SI
        XOR CX, CX
_KTRT_SL1:
        LODSB
        TEST AL, AL
        JZ _KTRT_SL2
        INC CX
        JMP _KTRT_SL1
_KTRT_SL2:
        POP SI
        RET

; --- _KTRT_NUMTOSTR : AX = entier signe -> SI = ptr, CX = len ---
_KTRT_NUMTOSTR:
        PUSH DI
        PUSH BX
        PUSH DX
; Ecrire les chiffres depuis la fin du buffer
        MOV DI, OFFSET _KT_NUMBUF
        ADD DI, 11
        MOV BYTE PTR [DI], 0
        DEC DI
        MOV BX, 10
        XOR CX, CX
; Sauver le signe
        MOV SI, AX
        TEST AX, AX
        JNS _KTRT_NS0
        NEG AX
_KTRT_NS0:
; Boucle extraction chiffres (AX = valeur positive)
_KTRT_NS1:
        XOR DX, DX
        DIV BX
        ADD DL, '0'
        MOV [DI], DL
        DEC DI
        INC CX
        TEST AX, AX
        JNZ _KTRT_NS1
; Ajouter le signe - si necessaire
        TEST SI, SI
        JNS _KTRT_NS2
        MOV BYTE PTR [DI], 45
        DEC DI
        INC CX
_KTRT_NS2:
; SI = debut de la chaine (DI+1)
        INC DI
        MOV SI, DI
        POP DX
        POP BX
        POP DI
        RET

; --- _KTRT_STRTONUM : SI = str ASCIIZ -> AX = entier ---
_KTRT_STRTONUM:
        PUSH BX
        PUSH CX
        PUSH DX
        XOR AX, AX
        XOR CX, CX
        MOV BX, 10
; Verifier signe negatif
        CMP BYTE PTR [SI], 45
        JNE _KTRT_SN1
        INC SI
        INC CL
_KTRT_SN1:
        MOV DL, [SI]
        INC SI
        TEST DL, DL
        JZ _KTRT_SN2
        SUB DL, '0'
        CMP DL, 9
        JA _KTRT_SN2
        MUL BX
        XOR DH, DH
        ADD AX, DX
        JMP _KTRT_SN1
_KTRT_SN2:
; Appliquer le signe si negatif
        TEST CL, CL
        JZ _KTRT_SN3
        NEG AX
_KTRT_SN3:
        POP DX
        POP CX
        POP BX
        RET

; --- _KTRT_PRINTSTR : SI = str ASCIIZ -> STDOUT ---
_KTRT_PRINTSTR:
        PUSH AX
        PUSH BX
        PUSH CX
        PUSH DX
        CALL _KTRT_STRLEN
        MOV DX, SI
        MOV AH, 40h
        MOV BX, 1
        INT 21h
        POP DX
        POP CX
        POP BX
        POP AX
        RET

; --- _KTRT_PRINT : AX = entier -> STDOUT ---
_KTRT_PRINT:
        CALL _KTRT_NUMTOSTR
        CALL _KTRT_PRINTSTR
        RET

; --- _KTRT_NEWLINE : CR+LF sur STDOUT ---
_KTRT_NEWLINE:
        PUSH SI
        MOV SI, OFFSET _KT_CRLF
        CALL _KTRT_PRINTSTR
        POP SI
        RET

; --- _KTRT_READLINE : lire ligne STDIN -> AX = ptr ---
_KTRT_READLINE:
        PUSH DX
        PUSH BX
        MOV AH, 0Ah
        MOV DX, OFFSET _KT_INPUTMX
        INT 21h
; Convertir le buffer DOS en ASCIIZ
        XOR BX, BX
        MOV BL, [_KT_INPUTLN]
        MOV BYTE PTR [_KT_INPUTBF+BX], 0
        MOV AX, OFFSET _KT_INPUTBF
; Afficher un retour a la ligne apres la saisie
        CALL _KTRT_NEWLINE
        POP BX
        POP DX
        RET

; =========================================================
; TODO 15 - RUNTIME TABLEAUX KOTLIN86
; =========================================================

; --- _KTRT_ARRIDXOF : BX=arr, AX=val -> AX=index/-1 ---
_KTRT_ARRIDXOF:
        PUSH BX
        PUSH CX
        PUSH SI
        MOV CX, [BX]
        ADD BX, 2
        XOR SI, SI
_KTRT_AIF1:
        TEST CX, CX
        JZ _KTRT_AIF2
        CMP AX, [BX]
        JE _KTRT_AIF3
        ADD BX, 2
        INC SI
        DEC CX
        JMP _KTRT_AIF1
_KTRT_AIF2:
; non trouve
        MOV AX, -1
        POP SI
        POP CX
        POP BX
        RET
_KTRT_AIF3:
; trouve a index SI
        MOV AX, SI
        POP SI
        POP CX
        POP BX
        RET

; --- _KTRT_ARRSUM : BX=arr -> AX=somme ---
_KTRT_ARRSUM:
        PUSH BX
        PUSH CX
        MOV CX, [BX]
        ADD BX, 2
        XOR AX, AX
_KTRT_ASM1:
        TEST CX, CX
        JZ _KTRT_ASM2
        ADD AX, [BX]
        ADD BX, 2
        DEC CX
        JMP _KTRT_ASM1
_KTRT_ASM2:
        POP CX
        POP BX
        RET

; --- _KTRT_ARRSORT : BX=arr -> AX=BX (trie) ---
_KTRT_ARRSORT:
        PUSH BX
        PUSH CX
        PUSH DX
        PUSH SI
        PUSH DI
        MOV CX, [BX]
        CMP CX, 2
        JB _KTRT_ASR4
        DEC CX
_KTRT_ASR1:
        PUSH CX
        MOV SI, BX
        ADD SI, 2
        MOV DI, CX
_KTRT_ASR2:
        MOV AX, [SI]
        MOV DX, [SI+2]
        CMP AX, DX
        JLE _KTRT_ASR3
        MOV [SI], DX
        MOV [SI+2], AX
_KTRT_ASR3:
        ADD SI, 2
        DEC DI
        JNZ _KTRT_ASR2
        POP CX
        LOOP _KTRT_ASR1
_KTRT_ASR4:
        MOV AX, BX
        POP DI
        POP SI
        POP DX
        POP CX
        POP BX
        RET

; ---------------------------------------------------------
; Runtime : classes et objets
; ---------------------------------------------------------

_KTRT_OBJNEW:
        PUSH DI
        PUSH AX
        MOV DI, BX
        XOR AX, AX
        REP STOSB
        POP AX
        POP DI
        RET

; ; --- scope runtime (TODO 18) ---

; =========================================================
; TODO 19 - RUNTIME CHAINES ET METHODES STRING
; =========================================================

; --- _KTRT_STRLENAX : AX = ptr str -> AX = longueur ---
_KTRT_STRLENAX:
        PUSH SI
        PUSH CX
        MOV SI, AX
        XOR CX, CX
_KTRT_SLA1:
        LODSB
        TEST AL, AL
        JZ _KTRT_SLA2
        INC CX
        JMP _KTRT_SLA1
_KTRT_SLA2:
        MOV AX, CX
        POP CX
        POP SI
        RET

; --- _KTRT_STRCHAR : SI=str, CX=idx -> AX=ptr _KT_CHRBUF ---
_KTRT_STRCHAR:
        PUSH BX
        MOV BX, SI
        ADD BX, CX
        MOV AL, [BX]
        MOV BYTE PTR [_KT_CHRBUF], AL
        MOV BYTE PTR [_KT_CHRBUF+1], 0
        MOV AX, OFFSET _KT_CHRBUF
        POP BX
        RET

; --- _KTRT_STRSUB : SI=str, BX=start, CX=end -> AX=buf ---
_KTRT_STRSUB:
        PUSH DI
        PUSH SI
        ADD SI, BX
        SUB CX, BX
        MOV DI, OFFSET _KT_STRBUF2
_KTRT_SSB1:
        TEST CX, CX
        JZ _KTRT_SSB2
        LODSB
        STOSB
        DEC CX
        JMP _KTRT_SSB1
_KTRT_SSB2:
        MOV BYTE PTR [DI], 0
        MOV AX, OFFSET _KT_STRBUF2
        POP SI
        POP DI
        RET

; --- _KTRT_STRINDEXOF : SI=str, DI=sub -> AX=idx/-1 ---
_KTRT_STRINDEXOF:
        PUSH BX
        PUSH CX
        PUSH DX
        XOR BX, BX
_KTRT_SIO1:
        MOV AL, [SI+BX]
        TEST AL, AL
        JZ _KTRT_SIO4
; Comparer sub a partir de SI+BX
        XOR CX, CX
_KTRT_SIO2:
        MOV DL, [DI+CX]
        TEST DL, DL
        JZ _KTRT_SIO3
        MOV DH, BX
        ADD DH, CL
        PUSH BX
        XOR BH, BH
        MOV BL, DH
        MOV AL, [SI+BX]
        POP BX
        CMP AL, DL
        JNE _KTRT_SIO5
        INC CX
        JMP _KTRT_SIO2
_KTRT_SIO5:
        INC BX
        JMP _KTRT_SIO1
_KTRT_SIO3:
; Trouve a position BX
        MOV AX, BX
        POP DX
        POP CX
        POP BX
        RET
_KTRT_SIO4:
; Pas trouve
        MOV AX, -1
        POP DX
        POP CX
        POP BX
        RET

; --- _KTRT_STRSTARTW : SI=str, DI=prefix -> AX=0/1 ---
_KTRT_STRSTARTW:
        PUSH BX
        XOR BX, BX
_KTRT_SSW1:
        MOV AL, [DI+BX]
        TEST AL, AL
        JZ _KTRT_SSW2
        CMP AL, [SI+BX]
        JNE _KTRT_SSW3
        INC BX
        JMP _KTRT_SSW1
_KTRT_SSW2:
        MOV AX, 1
        POP BX
        RET
_KTRT_SSW3:
        XOR AX, AX
        POP BX
        RET

; --- _KTRT_STRENDW : SI=str, DI=suffix -> AX=0/1 ---
_KTRT_STRENDW:
        PUSH BX
        PUSH CX
        PUSH DX
; Longueur de str
        PUSH SI
        CALL _KTRT_STRLEN
        MOV DX, CX
        POP SI
; Longueur de suffix
        PUSH SI
        MOV SI, DI
        CALL _KTRT_STRLEN
        MOV BX, CX
        POP SI
; Verifier que str >= suffix
        CMP DX, BX
        JB _KTRT_SEW3
; Comparer depuis la fin
        SUB DX, BX
        XOR CX, CX
_KTRT_SEW1:
        CMP CX, BX
        JE _KTRT_SEW2
        PUSH BX
        MOV BX, DX
        ADD BX, CX
        MOV AL, [SI+BX]
        POP BX
        CMP AL, [DI+CX]
        JNE _KTRT_SEW3
        INC CX
        JMP _KTRT_SEW1
_KTRT_SEW2:
        MOV AX, 1
        POP DX
        POP CX
        POP BX
        RET
_KTRT_SEW3:
        XOR AX, AX
        POP DX
        POP CX
        POP BX
        RET

; --- _KTRT_STRTOUPPER : SI=str -> AX=ptr _KT_STRBUF2 ---
_KTRT_STRTOUPPER:
        PUSH SI
        PUSH DI
        MOV DI, OFFSET _KT_STRBUF2
_KTRT_STU1:
        LODSB
        CMP AL, 'a'
        JB _KTRT_STU2
        CMP AL, 'z'
        JA _KTRT_STU2
        SUB AL, 32
_KTRT_STU2:
        STOSB
        TEST AL, AL
        JNZ _KTRT_STU1
        MOV AX, OFFSET _KT_STRBUF2
        POP DI
        POP SI
        RET

; --- _KTRT_STRTOLOWER : SI=str -> AX=ptr _KT_STRBUF2 ---
_KTRT_STRTOLOWER:
        PUSH SI
        PUSH DI
        MOV DI, OFFSET _KT_STRBUF2
_KTRT_STL1:
        LODSB
        CMP AL, 'A'
        JB _KTRT_STL2
        CMP AL, 'Z'
        JA _KTRT_STL2
        ADD AL, 32
_KTRT_STL2:
        STOSB
        TEST AL, AL
        JNZ _KTRT_STL1
        MOV AX, OFFSET _KT_STRBUF2
        POP DI
        POP SI
        RET

; --- _KTRT_STRTRIM : SI=str -> AX=ptr _KT_STRBUF2 ---
_KTRT_STRTRIM:
        PUSH SI
        PUSH DI
        PUSH CX
; Sauter les espaces au debut
_KTRT_STM1:
        MOV AL, [SI]
        CMP AL, ' '
        JE _KTRT_STM1A
        CMP AL, 9
        JE _KTRT_STM1A
        JMP _KTRT_STM2
_KTRT_STM1A:
        INC SI
        JMP _KTRT_STM1
_KTRT_STM2:
; Copier dans buf
        MOV DI, OFFSET _KT_STRBUF2
        XOR CX, CX
_KTRT_STM3:
        LODSB
        STOSB
        INC CX
        TEST AL, AL
        JNZ _KTRT_STM3
; Supprimer espaces a la fin
        MOV DI, OFFSET _KT_STRBUF2
        ADD DI, CX
        SUB DI, 2
_KTRT_STM4:
        CMP DI, OFFSET _KT_STRBUF2
        JB _KTRT_STM5
        MOV AL, [DI]
        CMP AL, ' '
        JE _KTRT_STM4A
        CMP AL, 9
        JE _KTRT_STM4A
        JMP _KTRT_STM5
_KTRT_STM4A:
        DEC DI
        JMP _KTRT_STM4
_KTRT_STM5:
        INC DI
        MOV BYTE PTR [DI], 0
        MOV AX, OFFSET _KT_STRBUF2
        POP CX
        POP DI
        POP SI
        RET

; --- _KTRT_STRREV : SI=str -> AX=ptr _KT_STRBUF2 ---
_KTRT_STRREV:
        PUSH SI
        PUSH DI
        PUSH CX
; Calculer longueur
        CALL _KTRT_STRLEN
; Pointer DI vers la fin du buf, copier a l envers
        MOV DI, OFFSET _KT_STRBUF2
        ADD DI, CX
        MOV BYTE PTR [DI], 0
        DEC DI
_KTRT_SRV1:
        TEST CX, CX
        JZ _KTRT_SRV2
        LODSB
        MOV [DI], AL
        DEC DI
        DEC CX
        JMP _KTRT_SRV1
_KTRT_SRV2:
        MOV AX, OFFSET _KT_STRBUF2
        POP CX
        POP DI
        POP SI
        RET

; --- _KTRT_STRREPEAT : SI=str, CX=count -> AX=buf ---
_KTRT_STRREPEAT:
        PUSH SI
        PUSH DI
        PUSH CX
        PUSH BX
        MOV BX, SI
        MOV DI, OFFSET _KT_STRBUF2
_KTRT_SRP1:
        TEST CX, CX
        JZ _KTRT_SRP3
        MOV SI, BX
_KTRT_SRP2:
        LODSB
        TEST AL, AL
        JZ _KTRT_SRP2A
        STOSB
        JMP _KTRT_SRP2
_KTRT_SRP2A:
        DEC CX
        JMP _KTRT_SRP1
_KTRT_SRP3:
        MOV BYTE PTR [DI], 0
        MOV AX, OFFSET _KT_STRBUF2
        POP BX
        POP CX
        POP DI
        POP SI
        RET

; --- _KTRT_STRRPLS : SI=str, DI=old, BX=new -> AX=buf ---
_KTRT_STRRPLS:
        PUSH SI
        PUSH DI
        PUSH CX
        PUSH DX
; Simple impl : copier str a _KT_STRBUF2 (stub)
        PUSH DI
        MOV DI, OFFSET _KT_STRBUF2
_KTRT_SRP_C1:
        LODSB
        STOSB
        TEST AL, AL
        JNZ _KTRT_SRP_C1
        POP DI
        MOV AX, OFFSET _KT_STRBUF2
        POP DX
        POP CX
        POP DI
        POP SI
        RET

; --- _KTRT_CHKCHAR : AX=char, BX=mode -> AX=0/1 ---
_KTRT_CHKCHAR:
        CMP BX, 0
        JE _KTRT_CHK_LET
        CMP BX, 1
        JE _KTRT_CHK_DIG
; isWhitespace
        CMP AL, ' '
        JE _KTRT_CHK_Y
        CMP AL, 9
        JE _KTRT_CHK_Y
        CMP AL, 10
        JE _KTRT_CHK_Y
        CMP AL, 13
        JE _KTRT_CHK_Y
        JMP _KTRT_CHK_N
_KTRT_CHK_LET:
        CMP AL, 'A'
        JB _KTRT_CHK_LET2
        CMP AL, 'Z'
        JBE _KTRT_CHK_Y
_KTRT_CHK_LET2:
        CMP AL, 'a'
        JB _KTRT_CHK_N
        CMP AL, 'z'
        JBE _KTRT_CHK_Y
        JMP _KTRT_CHK_N
_KTRT_CHK_DIG:
        CMP AL, '0'
        JB _KTRT_CHK_N
        CMP AL, '9'
        JBE _KTRT_CHK_Y
        JMP _KTRT_CHK_N
_KTRT_CHK_Y:
        MOV AX, 1
        RET
_KTRT_CHK_N:
        XOR AX, AX
        RET

; =========================================================
; TODO 20 - NULL SAFETY RUNTIME
; =========================================================

; --- _KTRT_PANIC : affiche NPE et quitte (exit code 1) ---
_KTRT_PANIC:
        PUSH SI
        MOV SI, OFFSET _KT_NPE_MSG
        CALL _KTRT_PRINTSTR
        CALL _KTRT_NEWLINE
        POP SI
        MOV AX, 4C01h
        INT 21h
        RET

; --- _KTRT_CHKNIL : AX=ptr, panic si null ---
_KTRT_CHKNIL:
        TEST AX, AX
        JNZ _KTRT_CHKNIL_OK
        JMP _KTRT_PANIC
_KTRT_CHKNIL_OK:
        RET

_TEXT   ENDS


_DATA   SEGMENT WORD PUBLIC 'DATA'

_KT_CRLF  DB 13, 10, 0
_KT_NULL_STR  DB 0
_KT_TRUE_S  DB 'true', 0
_KT_FALSE_S  DB 'false', 0
_KT_STRBUF  DB 256 DUP(0)
_KT_STRBUF2  DB 256 DUP(0)
_KT_CHRBUF  DB 4 DUP(0)
_KT_NUMBUF  DB 12 DUP(0)
_KT_SPACE  DB ' ', 0
_KT_INPUTMX  DB 126
_KT_INPUTLN  DB 0
_KT_INPUTBF  DB 128 DUP(0)
_KT_NPE_MSG  DB 'NullPointerException', 0
_KTV_x  DW 0
_KTV_y  DW 0
_KTV_name  DW 0
_KTK_16  DB 'Hello', 0
_KTV_flag  DW 0
_KTV_nothing  DW 0
_KTV_c  DW 0
_KTV_sum  DW 0

_DATA   ENDS

        END _KTF_main
