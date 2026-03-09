; ========================================
; Genere par VAXPCW32 v1.0 (2026-03-09)
; Source : SAMPLES/VAXPASCAL/test_coerce.pas
; Cible  : Win32 / 80386 / PE
; ========================================

.386
.MODEL FLAT, STDCALL
OPTION CASEMAP:NONE

; --- Declarations externes Win32 ---
EXTRN   _ExitProcess@4       : PROC
EXTRN   _GetStdHandle@4      : PROC
EXTRN   _WriteFile@20        : PROC
EXTRN   _ReadFile@20         : PROC
EXTRN   _GetProcessHeap@0    : PROC
EXTRN   _HeapAlloc@12        : PROC
EXTRN   _HeapFree@12         : PROC
EXTRN   _GetTickCount@0      : PROC
EXTRN   _GetLocalTime@4      : PROC
EXTRN   _CreateFileA@28      : PROC
EXTRN   _CloseHandle@4       : PROC
EXTRN   _DeleteFileA@4       : PROC

.STACK 4096

; --- Segment de code ---
_TEXT   SEGMENT DWORD PUBLIC 'CODE'
        ASSUME CS:_TEXT

; --- Point d entree principal ---
_VXPF_MAIN:
; Obtenir le handle stdout
        PUSH   -11
        CALL   _GetStdHandle@4
        MOV   DWORD PTR [_VXPRT_HSTDOUT], EAX
; Obtenir le handle stdin
        PUSH   -10
        CALL   _GetStdHandle@4
        MOV   DWORD PTR [_VXPRT_HSTDIN], EAX

_VXPL_MAINBODY:
; exception: sauvegarder handler parent
        PUSH   DWORD PTR [_VXPRT_EXCHDL]
        PUSH   DWORD PTR [_VXPRT_EXCSP]
        PUSH   DWORD PTR [_VXPRT_EXCBP]
        MOV   DWORD PTR [_VXPRT_EXCHDL], OFFSET _VXPL_1
        MOV   DWORD PTR [_VXPRT_EXCSP], ESP
        MOV   DWORD PTR [_VXPRT_EXCBP], EBP
; assign i
        MOV   EAX, -1
        MOV   DWORD PTR [_VXP_I], EAX
; assign u
        MOV   EAX, DWORD PTR [_VXP_I]
        MOV   DWORD PTR [_VXP_U], EAX
; writeln
        LEA   EAX, _VXPK_3
        MOV   ESI, EAX
        CALL   _VXPRT_PRINTSTR
        MOV   EAX, DWORD PTR [_VXP_U]
        CALL   _VXPRT_PRINTINT
        CALL   _VXPRT_NEWLINE
; assign i
        MOV   EAX, 65
        MOV   DWORD PTR [_VXP_I], EAX
; assign c
        MOV   EAX, DWORD PTR [_VXP_I]
        AND   EAX, 255
        MOV   BYTE PTR [_VXP_C], AL
; writeln
        LEA   EAX, _VXPK_4
        MOV   ESI, EAX
        CALL   _VXPRT_PRINTSTR
        MOVZX   EAX, BYTE PTR [_VXP_C]
        CALL   _VXPRT_PRINTCHAR
        CALL   _VXPRT_NEWLINE
; assign i
        LEA   EAX, _VXPK_5
        MOVZX   EAX, AL
        MOV   DWORD PTR [_VXP_I], EAX
; writeln
        LEA   EAX, _VXPK_6
        MOV   ESI, EAX
        CALL   _VXPRT_PRINTSTR
        MOV   EAX, DWORD PTR [_VXP_I]
        CALL   _VXPRT_PRINTINT
        CALL   _VXPRT_NEWLINE
; assign b
        MOV   EAX, 1
        MOV   BYTE PTR [_VXP_B], AL
; assign i
        MOVZX   EAX, BYTE PTR [_VXP_B]
        MOVZX   EAX, AL
        MOV   DWORD PTR [_VXP_I], EAX
; writeln
        LEA   EAX, _VXPK_7
        MOV   ESI, EAX
        CALL   _VXPRT_PRINTSTR
        MOV   EAX, DWORD PTR [_VXP_I]
        CALL   _VXPRT_PRINTINT
        CALL   _VXPRT_NEWLINE
; assign i
        MOV   EAX, 42
        MOV   DWORD PTR [_VXP_I], EAX
; assign p
        MOV   EAX, DWORD PTR [_VXP_I]
        LEA   EAX, [_VXP_I]
        MOV   DWORD PTR [_VXP_P], EAX
; writeln
        LEA   EAX, _VXPK_8
        MOV   ESI, EAX
        CALL   _VXPRT_PRINTSTR
; deref p^
        MOV   EBX, DWORD PTR [_VXP_P]
        MOV   EAX, DWORD PTR [EBX]
        CALL   _VXPRT_PRINTINT
        CALL   _VXPRT_NEWLINE
; writeln
        LEA   EAX, _VXPK_9
        MOV   ESI, EAX
        CALL   _VXPRT_PRINTSTR
        CALL   _VXPRT_NEWLINE
; exception: pas d erreur, restaurer handler parent
        POP   DWORD PTR [_VXPRT_EXCBP]
        POP   DWORD PTR [_VXPRT_EXCSP]
        POP   DWORD PTR [_VXPRT_EXCHDL]
        JMP   _VXPL_2
_VXPL_1:
; exception handler (propagate to parent)
        POP   DWORD PTR [_VXPRT_EXCBP]
        POP   DWORD PTR [_VXPRT_EXCSP]
        POP   DWORD PTR [_VXPRT_EXCHDL]
        MOV   ESP, DWORD PTR [_VXPRT_EXCSP]
        MOV   EBP, DWORD PTR [_VXPRT_EXCBP]
        JMP   DWORD PTR [_VXPRT_EXCHDL]
_VXPL_2:


; --- Sortie programme (Win32 ExitProcess) ---
        PUSH   0
        CALL   _ExitProcess@4

; ========================================
;   ROUTINES RUNTIME 32 BITS (Win32)
; ========================================

; PRINTSTR : affiche chaine ASCIIZ (ESI -> chaine)
_VXPRT_PRINTSTR:
        PUSH   ESI
        MOV   EDI, ESI
; calculer la longueur
        XOR   ECX, ECX
_VXPRT_PRINTSTR_L:
        CMP   BYTE PTR [EDI], 0
        JE   _VXPRT_PRINTSTR_W
        INC   EDI
        INC   ECX
        JMP   _VXPRT_PRINTSTR_L
_VXPRT_PRINTSTR_W:
; WriteFile(hStdout, pStr, len, pWritten, 0)
        PUSH   0
        PUSH   OFFSET _VXPRT_WRITTEN
        PUSH   ECX
        PUSH   ESI
        PUSH   DWORD PTR [_VXPRT_HSTDOUT]
        CALL   _WriteFile@20
        POP   ESI
        RET

; NUMTOSTR : convertit EAX (signe) -> NUMBUF (ASCIIZ)
_VXPRT_NUMTOSTR:
        PUSH   EBX
        PUSH   ECX
        PUSH   EDX
        PUSH   EDI
        PUSH   EAX
        LEA   EDI, _VXPRT_NUMBUF + 15
        MOV   BYTE PTR [EDI], 0
        MOV   ECX, 0
        MOV   EBX, 10
        CMP   EAX, 0
        JGE   _VXPRT_NTS_POS
        NEG    EAX
_VXPRT_NTS_POS:
_VXPRT_NTS_DIV:
        XOR   EDX, EDX
        DIV   EBX
        ADD    DL, '0'
        DEC    EDI
        MOV   [EDI], DL
        INC   ECX
        CMP   EAX, 0
        JNE   _VXPRT_NTS_DIV
; verifier le signe (valeur originale empilee)
        MOV   EAX, DWORD PTR [ESP]
        CMP   EAX, 0
        JGE   _VXPRT_NTS_DONE
        DEC    EDI
        MOV    BYTE PTR [EDI], '-'
_VXPRT_NTS_DONE:
        MOV   EAX, EDI
        ADD   ESP, 4
        POP   EDI
        POP   EDX
        POP   ECX
        POP   EBX
        RET

; STRLEN : longueur chaine ASCIIZ (ESI -> EAX)
_VXPRT_STRLEN:
        PUSH   ESI
        XOR   EAX, EAX
_VXPRT_STRLEN_LP:
        CMP   BYTE PTR [ESI], 0
        JE   _VXPRT_STRLEN_DONE
        INC    EAX
        INC    ESI
        JMP   _VXPRT_STRLEN_LP
_VXPRT_STRLEN_DONE:
        POP   ESI
        RET

; CONCAT : ESI + EDI -> EAX = ptr STRBUF
_VXPRT_CONCAT:
        PUSH   EBX
        LEA   EBX, _VXPRT_STRBUF
_VXPRT_CONCAT_S1:
        MOV   AL, [ESI]
        CMP   AL, 0
        JE   _VXPRT_CONCAT_S2
        MOV   [EBX], AL
        INC    ESI
        INC    EBX
        JMP   _VXPRT_CONCAT_S1
_VXPRT_CONCAT_S2:
        MOV   AL, [EDI]
        CMP   AL, 0
        JE   _VXPRT_CONCAT_END
        MOV   [EBX], AL
        INC    EDI
        INC    EBX
        JMP   _VXPRT_CONCAT_S2
_VXPRT_CONCAT_END:
        MOV   BYTE PTR [EBX], 0
        LEA   EAX, _VXPRT_STRBUF
        POP   EBX
        RET

; STRCMP : ESI vs EDI -> EAX (0=egal, <0 inf, >0 sup)
_VXPRT_STRCMP:
        PUSH   ESI
        PUSH   EDI
_VXPRT_STRCMP_LP:
        MOV   AL, [ESI]
        MOV   AH, [EDI]
        CMP   AL, AH
        JNE   _VXPRT_STRCMP_DIFF
        CMP   AL, 0
        JE   _VXPRT_STRCMP_EQ
        INC    ESI
        INC    EDI
        JMP   _VXPRT_STRCMP_LP
_VXPRT_STRCMP_EQ:
        XOR   EAX, EAX
        JMP   _VXPRT_STRCMP_RET
_VXPRT_STRCMP_DIFF:
        MOVZX   EAX, AL
        MOVZX   EDX, AH
        SUB   EAX, EDX
_VXPRT_STRCMP_RET:
        POP   EDI
        POP   ESI
        RET

; NEWLINE : ecrire CR+LF sur stdout
_VXPRT_NEWLINE:
        MOV   ESI, OFFSET _VXPRT_CRLF
        CALL   _VXPRT_PRINTSTR
        RET

; PRINTINT : affiche EAX en decimal signe
_VXPRT_PRINTINT:
        CALL   _VXPRT_NUMTOSTR
        MOV   ESI, EAX
        CALL   _VXPRT_PRINTSTR
        RET

; PRINTBOOL : affiche TRUE ou FALSE (EAX)
_VXPRT_PRINTBOOL:
        CMP   EAX, 0
        JE   _VXPRT_PB_FALSE
        MOV   ESI, OFFSET _VXPRT_TRUE_S
        JMP   _VXPRT_PB_PRINT
_VXPRT_PB_FALSE:
        MOV   ESI, OFFSET _VXPRT_FALSE_S
_VXPRT_PB_PRINT:
        CALL   _VXPRT_PRINTSTR
        RET

; READLN : lit une ligne stdin -> STRBUF (EAX=ptr)
_VXPRT_READLN:
        PUSH   EBX
        PUSH   ECX
; ReadFile(hStdin, STRBUF, 255, WRITTEN, 0)
        PUSH   0
        PUSH   OFFSET _VXPRT_WRITTEN
        PUSH   255
        PUSH   OFFSET _VXPRT_STRBUF
        PUSH   DWORD PTR [_VXPRT_HSTDIN]
        CALL   _ReadFile@20
; Supprimer CR/LF en fin de ligne
        MOV   ECX, DWORD PTR [_VXPRT_WRITTEN]
        LEA   EBX, _VXPRT_STRBUF
_VXPRT_RL_TRIM:
        CMP   ECX, 0
        JE   _VXPRT_RL_DONE
        DEC    ECX
        CMP   BYTE PTR [EBX+ECX], 10
        JE   _VXPRT_RL_ZERO
        CMP   BYTE PTR [EBX+ECX], 13
        JE   _VXPRT_RL_ZERO
        INC    ECX
        JMP   _VXPRT_RL_DONE
_VXPRT_RL_ZERO:
        MOV   BYTE PTR [EBX+ECX], 0
        JMP   _VXPRT_RL_TRIM
_VXPRT_RL_DONE:
        MOV   BYTE PTR [EBX+ECX], 0
        LEA   EAX, _VXPRT_STRBUF
        POP   ECX
        POP   EBX
        RET

; PRINTCHAR : affiche caractere dans AL
_VXPRT_PRINTCHAR:
        MOV   BYTE PTR [_VXPRT_CHRBUF], AL
        MOV   BYTE PTR [_VXPRT_CHRBUF + 1], 0
        MOV   ESI, OFFSET _VXPRT_CHRBUF
        CALL   _VXPRT_PRINTSTR
        RET

; PRINTINT_W : affiche EAX en decimal, largeur minimum ECX
_VXPRT_PRINTINT_W:
        PUSH   EBX
        PUSH   ECX
        CALL   _VXPRT_NUMTOSTR
        MOV   EDX, EAX
        MOV   ESI, EAX
        CALL   _VXPRT_STRLEN
        POP   ECX
        SUB   ECX, EAX
_VXPRT_PIW_PAD:
        CMP   ECX, 0
        JLE   _VXPRT_PIW_NUM
        PUSH   ECX
        PUSH   EDX
        MOV   BYTE PTR [_VXPRT_CHRBUF], 32
        MOV   BYTE PTR [_VXPRT_CHRBUF + 1], 0
        MOV   ESI, OFFSET _VXPRT_CHRBUF
        CALL   _VXPRT_PRINTSTR
        POP   EDX
        POP   ECX
        DEC    ECX
        JMP   _VXPRT_PIW_PAD
_VXPRT_PIW_NUM:
        MOV   ESI, EDX
        CALL   _VXPRT_PRINTSTR
        POP   EBX
        RET

; READINT : lit un entier depuis stdin -> EAX
_VXPRT_READINT:
        CALL   _VXPRT_READLN
        MOV   ESI, EAX
        CALL   _VXPRT_STRTONUM
        RET

; READSTR : lit une chaine depuis stdin -> EAX (ptr)
_VXPRT_READSTR:
        CALL   _VXPRT_READLN
        RET

; READCHAR : lit un caractere depuis stdin -> AL
_VXPRT_READCHAR:
        CALL   _VXPRT_READLN
        MOVZX   EAX, BYTE PTR [EAX]
        RET

; POWER : EAX ^ EBX -> EAX (entier)
_VXPRT_POWER:
        PUSH   ECX
        PUSH   EDX
        MOV   ECX, EBX
        MOV   EDX, EAX
        MOV   EAX, 1
        CMP   ECX, 0
        JLE   _VXPRT_POW_DONE
_VXPRT_POW_LP:
        IMUL   EDX
        DEC    ECX
        JNZ   _VXPRT_POW_LP
_VXPRT_POW_DONE:
        POP   EDX
        POP   ECX
        RET

; SET_IN : test EAX IN set[ESI] -> EAX (0 ou 1)
_VXPRT_SET_IN:
        PUSH   EBX
        PUSH   ECX
        MOV   ECX, EAX
        SHR   ECX, 3
        MOVZX   EBX, BYTE PTR [ESI+ECX]
        MOV   ECX, EAX
        AND   ECX, 7
        SHR   EBX, CL
        AND   EBX, 1
        MOV   EAX, EBX
        POP   ECX
        POP   EBX
        RET

; SET_COPY : copier ensemble ESI -> EDI (32 octets)
_VXPRT_SET_COPY:
        PUSH   ECX
        PUSH   ESI
        PUSH   EDI
        MOV   ECX, 8
        REP    MOVSD
        POP   EDI
        POP   ESI
        POP   ECX
        RET

; SET_UNION : ESI+EDI -> EAX=OFFSET STMP2
_VXPRT_SET_UNION:
        PUSH   ECX
        PUSH   EDX
        PUSH   EBX
        LEA   EBX, _VXPRT_STMP2
        MOV   ECX, 8
_VXPRT_SET_UN_LP:
        MOV   EDX, DWORD PTR [ESI]
        OR   EDX, DWORD PTR [EDI]
        MOV   DWORD PTR [EBX], EDX
        ADD   ESI, 4
        ADD   EDI, 4
        ADD   EBX, 4
        DEC    ECX
        JNZ   _VXPRT_SET_UN_LP
        LEA   EAX, _VXPRT_STMP2
        POP   EBX
        POP   EDX
        POP   ECX
        RET

; SET_INTER : ESI*EDI -> EAX=OFFSET STMP2
_VXPRT_SET_INTER:
        PUSH   ECX
        PUSH   EDX
        PUSH   EBX
        LEA   EBX, _VXPRT_STMP2
        MOV   ECX, 8
_VXPRT_SET_IN_LP:
        MOV   EDX, DWORD PTR [ESI]
        AND   EDX, DWORD PTR [EDI]
        MOV   DWORD PTR [EBX], EDX
        ADD   ESI, 4
        ADD   EDI, 4
        ADD   EBX, 4
        DEC    ECX
        JNZ   _VXPRT_SET_IN_LP
        LEA   EAX, _VXPRT_STMP2
        POP   EBX
        POP   EDX
        POP   ECX
        RET

; SET_DIFF : ESI-EDI -> EAX=OFFSET STMP2
_VXPRT_SET_DIFF:
        PUSH   ECX
        PUSH   EDX
        PUSH   EBX
        LEA   EBX, _VXPRT_STMP2
        MOV   ECX, 8
_VXPRT_SET_DF_LP:
        MOV   EDX, DWORD PTR [EDI]
        NOT    EDX
        AND   EDX, DWORD PTR [ESI]
        MOV   DWORD PTR [EBX], EDX
        ADD   ESI, 4
        ADD   EDI, 4
        ADD   EBX, 4
        DEC    ECX
        JNZ   _VXPRT_SET_DF_LP
        LEA   EAX, _VXPRT_STMP2
        POP   EBX
        POP   EDX
        POP   ECX
        RET

; SET_EQ : ESI=EDI -> EAX=1/0
_VXPRT_SET_EQ:
        PUSH   ECX
        PUSH   EDX
        MOV   ECX, 8
_VXPRT_SET_EQ_LP:
        MOV   EAX, DWORD PTR [ESI]
        CMP   EAX, DWORD PTR [EDI]
        JNE   _VXPRT_SET_EQ_NE
        ADD   ESI, 4
        ADD   EDI, 4
        DEC    ECX
        JNZ   _VXPRT_SET_EQ_LP
        MOV   EAX, 1
        JMP   _VXPRT_SET_EQ_DN
_VXPRT_SET_EQ_NE:
        XOR   EAX, EAX
_VXPRT_SET_EQ_DN:
        POP   EDX
        POP   ECX
        RET

; SET_SUBSET : A<=B -> EAX=1/0
_VXPRT_SET_SUBSET:
        PUSH   ECX
        PUSH   EDX
        MOV   ECX, 8
_VXPRT_SET_SB_LP:
        MOV   EAX, DWORD PTR [ESI]
        MOV   EDX, DWORD PTR [EDI]
        NOT    EDX
        AND   EAX, EDX
        JNZ   _VXPRT_SET_SB_NO
        ADD   ESI, 4
        ADD   EDI, 4
        DEC    ECX
        JNZ   _VXPRT_SET_SB_LP
        MOV   EAX, 1
        JMP   _VXPRT_SET_SB_DN
_VXPRT_SET_SB_NO:
        XOR   EAX, EAX
_VXPRT_SET_SB_DN:
        POP   EDX
        POP   ECX
        RET

; SET_CARD : ESI=set -> EAX=popcount
_VXPRT_SET_CARD:
        PUSH   ECX
        PUSH   EDX
        PUSH   ESI
        XOR   EAX, EAX
        MOV   ECX, 32
_VXPRT_SET_CD_LP:
        MOVZX   EDX, BYTE PTR [ESI]
_VXPRT_SET_CD_BT:
        TEST   EDX, EDX
        JZ   _VXPRT_SET_CD_NX
        TEST   EDX, 1
        JZ   _VXPRT_SET_CD_SH
        INC    EAX
_VXPRT_SET_CD_SH:
        SHR   EDX, 1
        JMP   _VXPRT_SET_CD_BT
_VXPRT_SET_CD_NX:
        INC    ESI
        DEC    ECX
        JNZ   _VXPRT_SET_CD_LP
        POP   ESI
        POP   EDX
        POP   ECX
        RET

; STRTONUM : convertit chaine ESI -> EAX (entier signe)
_VXPRT_STRTONUM:
        PUSH   EBX
        PUSH   ECX
        PUSH   EDX
        XOR   EAX, EAX
        XOR   ECX, ECX
        MOV   EBX, 10
        CMP    BYTE PTR [ESI], '-'
        JNE   _VXPRT_STN_LP
        INC    ESI
        MOV   ECX, 1
_VXPRT_STN_LP:
        MOVZX   EDX, BYTE PTR [ESI]
        CMP    EDX, '0'
        JB   _VXPRT_STN_END
        CMP    EDX, '9'
        JA   _VXPRT_STN_END
        SUB    EDX, '0'
        IMUL   EBX
        ADD   EAX, EDX
        INC    ESI
        JMP   _VXPRT_STN_LP
_VXPRT_STN_END:
        CMP   ECX, 1
        JNE   _VXPRT_STN_RET
        NEG    EAX
_VXPRT_STN_RET:
        POP   EDX
        POP   ECX
        POP   EBX
        RET

; SUBSTR : ESI=str, EBX=pos(1-base), ECX=len -> EAX=ptr STRBUF
_VXPRT_SUBSTR:
        PUSH   EBX
        PUSH   ECX
        PUSH   EDI
        PUSH   ESI
        CMP   EBX, 1
        JGE   _VXPRT_SUBSTR_POSOK
        MOV   EBX, 1
_VXPRT_SUBSTR_POSOK:
        DEC    EBX
        ADD   ESI, EBX
        LEA   EDI, _VXPRT_STRBUF
_VXPRT_SUBSTR_LP:
        CMP   ECX, 0
        JE   _VXPRT_SUBSTR_DONE
        MOV   AL, BYTE PTR [ESI]
        CMP   AL, 0
        JE   _VXPRT_SUBSTR_DONE
        MOV   BYTE PTR [EDI], AL
        INC    ESI
        INC    EDI
        DEC    ECX
        JMP   _VXPRT_SUBSTR_LP
_VXPRT_SUBSTR_DONE:
        MOV   BYTE PTR [EDI], 0
        LEA   EAX, _VXPRT_STRBUF
        POP   ESI
        POP   EDI
        POP   ECX
        POP   EBX
        RET

; SSLICE : EDI=target, ESI=source, EBX=pos(1-base), ECX=len
_VXPRT_SSLICE:
        PUSH   EBX
        PUSH   ECX
        PUSH   EDI
        PUSH   ESI
        CMP   EBX, 1
        JGE   _VXPRT_SSLICE_POSOK
        MOV   EBX, 1
_VXPRT_SSLICE_POSOK:
        DEC    EBX
        ADD   EDI, EBX
_VXPRT_SSLICE_LP:
        CMP   ECX, 0
        JE   _VXPRT_SSLICE_DONE
        MOV   AL, BYTE PTR [ESI]
        CMP   AL, 0
        JE   _VXPRT_SSLICE_DONE
        MOV   BYTE PTR [EDI], AL
        INC    ESI
        INC    EDI
        DEC    ECX
        JMP   _VXPRT_SSLICE_LP
_VXPRT_SSLICE_DONE:
        POP   ESI
        POP   EDI
        POP   ECX
        POP   EBX
        RET

; INDEX : ESI=str, EDI=sub -> EAX=position (1-based, 0=absent)
_VXPRT_INDEX:
        PUSH   EBX
        PUSH   ECX
        CMP   BYTE PTR [EDI], 0
        JNE   _VXPRT_INDEX_INIT
        MOV   EAX, 1
        POP   ECX
        POP   EBX
        RET
_VXPRT_INDEX_INIT:
        MOV   EBX, ESI
        MOV   ECX, 1
_VXPRT_INDEX_LP:
        CMP   BYTE PTR [EBX], 0
        JE   _VXPRT_INDEX_NF
        PUSH   EBX
        PUSH   EDI
_VXPRT_INDEX_CM:
        MOV   AL, BYTE PTR [EDI]
        CMP   AL, 0
        JE   _VXPRT_INDEX_FD
        CMP   AL, BYTE PTR [EBX]
        JNE   _VXPRT_INDEX_NX
        INC    EBX
        INC    EDI
        JMP   _VXPRT_INDEX_CM
_VXPRT_INDEX_FD:
        POP   EDI
        POP   EBX
        MOV   EAX, ECX
        POP   ECX
        POP   EBX
        RET
_VXPRT_INDEX_NX:
        POP   EDI
        POP   EBX
        INC    EBX
        INC    ECX
        JMP   _VXPRT_INDEX_LP
_VXPRT_INDEX_NF:
        XOR   EAX, EAX
        POP   ECX
        POP   EBX
        RET

; --- VARY_CMP : compare two VARYING strings ---
_VXPRT_VARY_CMP:
        PUSH   EBX
        PUSH   ECX
        PUSH   EDX
        MOVZX   ECX, WORD PTR [ESI]
        MOVZX   EDX, WORD PTR [EDI]
        ADD   ESI, 2
        ADD   EDI, 2
        MOV   EBX, ECX
        CMP   EBX, EDX
        JLE   _VXPRT_VCMP_ML
        MOV   EBX, EDX
_VXPRT_VCMP_ML:
        TEST   EBX, EBX
        JZ   _VXPRT_VCMP_LN
_VXPRT_VCMP_LP:
        MOV   AL, BYTE PTR [ESI]
        CMP   AL, BYTE PTR [EDI]
        JB   _VXPRT_VCMP_LT
        JA   _VXPRT_VCMP_GT
        INC    ESI
        INC    EDI
        DEC    EBX
        JNZ   _VXPRT_VCMP_LP
_VXPRT_VCMP_LN:
        MOV   EAX, ECX
        SUB   EAX, EDX
        JMP   _VXPRT_VCMP_DN
_VXPRT_VCMP_LT:
        MOV   EAX, -1
        JMP   _VXPRT_VCMP_DN
_VXPRT_VCMP_GT:
        MOV   EAX, 1
_VXPRT_VCMP_DN:
        POP   EDX
        POP   ECX
        POP   EBX
        RET

; --- VARY_FROM_STR : ASCIIZ -> VARYING ---
_VXPRT_VARY_FROM_STR:
        PUSH   EBX
        PUSH   ECX
        PUSH   EDI
        MOV   EBX, ESI
        XOR   ECX, ECX
_VXPRT_VFS_LP:
        CMP   BYTE PTR [EBX], 0
        JE   _VXPRT_VFS_DN
        INC    EBX
        INC    ECX
        JMP   _VXPRT_VFS_LP
_VXPRT_VFS_DN:
        MOV   WORD PTR [EDI], CX
        ADD   EDI, 2
        MOV   EBX, ECX
_VXPRT_VFS_CP:
        TEST   EBX, EBX
        JZ   _VXPRT_VFS_FN
        MOV   AL, BYTE PTR [ESI]
        MOV   BYTE PTR [EDI], AL
        INC    ESI
        INC    EDI
        DEC    EBX
        JMP   _VXPRT_VFS_CP
_VXPRT_VFS_FN:
        MOV   BYTE PTR [EDI], 0
        POP   EDI
        POP   ECX
        POP   EBX
        RET

; --- VARY_ASSIGN : VARYING body -> VARYING ---
_VXPRT_VARY_ASSIGN:
        CALL   _VXPRT_VARY_FROM_STR
        RET

; --- PANIC_DIV0 : division by zero ---
_VXPRT_PANIC_DIV0:
        CMP   DWORD PTR [_VXPRT_EXCHDL], 0
        JE   _VXPRT_PANIC_DIV0_X
        MOV   DWORD PTR [_VXPRT_EXCCODE], 3
        MOV   ESP, DWORD PTR [_VXPRT_EXCSP]
        MOV   EBP, DWORD PTR [_VXPRT_EXCBP]
        JMP   DWORD PTR [_VXPRT_EXCHDL]
_VXPRT_PANIC_DIV0_X:
        PUSH   OFFSET _VXPRT_DIV0MSG
        POP   ESI
        CALL   _VXPRT_PRINTSTR
        CALL   _VXPRT_NEWLINE
        PUSH   1
        CALL   _ExitProcess@4

; --- PANIC_NIL : nil pointer dereference ---
_VXPRT_PANIC_NIL:
        CMP   DWORD PTR [_VXPRT_EXCHDL], 0
        JE   _VXPRT_PANIC_NIL_X
        MOV   DWORD PTR [_VXPRT_EXCCODE], 1
        MOV   ESP, DWORD PTR [_VXPRT_EXCSP]
        MOV   EBP, DWORD PTR [_VXPRT_EXCBP]
        JMP   DWORD PTR [_VXPRT_EXCHDL]
_VXPRT_PANIC_NIL_X:
        PUSH   OFFSET _VXPRT_NILMSG
        POP   ESI
        CALL   _VXPRT_PRINTSTR
        CALL   _VXPRT_NEWLINE
        PUSH   1
        CALL   _ExitProcess@4

; --- PANIC_RANGE : array index out of bounds ---
_VXPRT_PANIC_RANGE:
        CMP   DWORD PTR [_VXPRT_EXCHDL], 0
        JE   _VXPRT_PANIC_RANGE_X
        MOV   DWORD PTR [_VXPRT_EXCCODE], 2
        MOV   ESP, DWORD PTR [_VXPRT_EXCSP]
        MOV   EBP, DWORD PTR [_VXPRT_EXCBP]
        JMP   DWORD PTR [_VXPRT_EXCHDL]
_VXPRT_PANIC_RANGE_X:
        PUSH   OFFSET _VXPRT_RNGMSG
        POP   ESI
        CALL   _VXPRT_PRINTSTR
        CALL   _VXPRT_NEWLINE
        PUSH   1
        CALL   _ExitProcess@4

; --- RSG_PK : unhandled signal (panic) ---
_VXPRT_RSG_PK:
        PUSH   OFFSET _VXPRT_SIGMSG
        POP   ESI
        CALL   _VXPRT_PRINTSTR
        CALL   _VXPRT_NEWLINE
        PUSH   1
        CALL   _ExitProcess@4

; --- NEW : HeapAlloc Win32 (EAX=size -> EAX=ptr) ---
_VXPRT_NEW:
        PUSH   EBX
        MOV   EBX, EAX
        CMP   DWORD PTR [_VXPRT_HHEAP], 0
        JNE   _VXPRT_NEW_OK
        CALL   _GetProcessHeap@0
        MOV   DWORD PTR [_VXPRT_HHEAP], EAX
_VXPRT_NEW_OK:
        PUSH   EBX
        PUSH   8
        PUSH   DWORD PTR [_VXPRT_HHEAP]
        CALL   _HeapAlloc@12
        POP   EBX
        RET

; --- DISPOSE : HeapFree Win32 (EAX=ptr) ---
_VXPRT_DISPOSE:
        PUSH   EBX
        MOV   EBX, EAX
        CMP   DWORD PTR [_VXPRT_HHEAP], 0
        JNE   _VXPRT_DISP_OK
        CALL   _GetProcessHeap@0
        MOV   DWORD PTR [_VXPRT_HHEAP], EAX
_VXPRT_DISP_OK:
        PUSH   EBX
        PUSH   0
        PUSH   DWORD PTR [_VXPRT_HHEAP]
        CALL   _HeapFree@12
        POP   EBX
        RET

; --- STRCOPY : copie chaine ASCIIZ (ESI->EDI) ---
_VXPRT_STRCOPY:
        PUSH   ESI
        PUSH   EDI
_VXPRT_STRCPY_LP:
        MOV   AL, BYTE PTR [ESI]
        MOV   BYTE PTR [EDI], AL
        CMP   AL, 0
        JE   _VXPRT_STRCPY_DN
        INC    ESI
        INC    EDI
        JMP   _VXPRT_STRCPY_LP
_VXPRT_STRCPY_DN:
        POP   EDI
        POP   ESI
        RET

; --- CHKIDX : verif bornes (EAX=idx, EBX=lo, ECX=hi) ---
_VXPRT_CHKIDX:
        CMP   EAX, EBX
        JL   _VXPRT_PANIC_RANGE
        CMP   EAX, ECX
        JG   _VXPRT_PANIC_RANGE
        RET

; --- VARY_CONCAT : VARYING || VARYING -> STRBUF ---
_VXPRT_VARY_CONCAT:
        PUSH   EBX
        PUSH   ECX
        PUSH   EDX
        MOVZX   ECX, WORD PTR [ESI]
        MOVZX   EDX, WORD PTR [EDI]
        ADD   ESI, 2
        ADD   EDI, 2
        LEA   EBX, _VXPRT_STRBUF
_VXPRT_VCAT_S1:
        TEST   ECX, ECX
        JZ   _VXPRT_VCAT_S2
        MOV   AL, BYTE PTR [ESI]
        MOV   BYTE PTR [EBX], AL
        INC    ESI
        INC    EBX
        DEC    ECX
        JMP   _VXPRT_VCAT_S1
_VXPRT_VCAT_S2:
        TEST   EDX, EDX
        JZ   _VXPRT_VCAT_DN
        MOV   AL, BYTE PTR [EDI]
        MOV   BYTE PTR [EBX], AL
        INC    EDI
        INC    EBX
        DEC    EDX
        JMP   _VXPRT_VCAT_S2
_VXPRT_VCAT_DN:
        MOV   BYTE PTR [EBX], 0
        LEA   EAX, _VXPRT_STRBUF
        POP   EDX
        POP   ECX
        POP   EBX
        RET

; --- VARY_LENGTH : VARYING -> longueur dans EAX ---
_VXPRT_VARY_LENGTH:
        MOVZX   EAX, WORD PTR [ESI]
        RET

; --- VARY_BODY : VARYING -> ptr body dans EAX ---
_VXPRT_VARY_BODY:
        LEA   EAX, [ESI+2]
        RET

; --- VARY_SUBSTR : VARYING sous-chaine -> STRBUF ---
_VXPRT_VARY_SUBSTR:
        PUSH   EBX
        PUSH   ECX
        PUSH   EDX
        PUSH   EDI
        MOVZX   EDX, WORD PTR [ESI]
        ADD   ESI, 2
        CMP   EBX, 1
        JGE   _VXPRT_VSUB_POK
        MOV   EBX, 1
_VXPRT_VSUB_POK:
        DEC    EBX
        CMP   EBX, EDX
        JGE   _VXPRT_VSUB_EMP
        ADD   ESI, EBX
        SUB   EDX, EBX
        CMP   ECX, EDX
        JLE   _VXPRT_VSUB_LOK
        MOV   ECX, EDX
_VXPRT_VSUB_LOK:
        LEA   EDI, _VXPRT_STRBUF
_VXPRT_VSUB_LP:
        TEST   ECX, ECX
        JZ   _VXPRT_VSUB_DN
        MOV   AL, BYTE PTR [ESI]
        MOV   BYTE PTR [EDI], AL
        INC    ESI
        INC    EDI
        DEC    ECX
        JMP   _VXPRT_VSUB_LP
_VXPRT_VSUB_EMP:
        LEA   EDI, _VXPRT_STRBUF
_VXPRT_VSUB_DN:
        MOV   BYTE PTR [EDI], 0
        LEA   EAX, _VXPRT_STRBUF
        POP   EDI
        POP   EDX
        POP   ECX
        POP   EBX
        RET

; --- RANDOM : LCG 32-bit -> EAX (0..2^31-1) ---
_VXPRT_RANDOM:
        PUSH   EDX
        MOV   EAX, DWORD PTR [_VXPRT_SEED]
        IMUL   EAX, 1103515245
        ADD   EAX, 12345
        MOV   DWORD PTR [_VXPRT_SEED], EAX
        AND   EAX, 7FFFFFFFh
        POP   EDX
        RET

; --- SETSEED : EAX=graine -> SEED ---
_VXPRT_SETSEED:
        MOV   DWORD PTR [_VXPRT_SEED], EAX
        RET

; --- ABS : EAX=val -> EAX=|val| ---
_VXPRT_ABS:
        TEST   EAX, EAX
        JNS   _VXPRT_ABS_OK
        NEG    EAX
_VXPRT_ABS_OK:
        RET

; --- SQR : EAX=val -> EAX=val*val ---
_VXPRT_SQR:
        IMUL   EAX, EAX
        RET

; --- MIN : EAX=a, EBX=b -> EAX=min(a,b) ---
_VXPRT_MIN:
        CMP   EAX, EBX
        JLE   _VXPRT_MIN_OK
        MOV   EAX, EBX
_VXPRT_MIN_OK:
        RET

; --- MAX : EAX=a, EBX=b -> EAX=max(a,b) ---
_VXPRT_MAX:
        CMP   EAX, EBX
        JGE   _VXPRT_MAX_OK
        MOV   EAX, EBX
_VXPRT_MAX_OK:
        RET

; --- ASSERT : EAX=cond, halt si 0 ---
_VXPRT_ASSERT:
        TEST   EAX, EAX
        JNZ   _VXPRT_ASSERT_OK
        PUSH   OFFSET _VXPRT_ASSERTMSG
        CALL   _VXPRT_PRINTSTR
        ADD   ESP, 4
        CALL   _VXPRT_NEWLINE
        PUSH   1
        CALL   ExitProcess
_VXPRT_ASSERT_OK:
        RET

; --- UPPERCASE : EAX=ptr ASCIIZ -> EAX=STRBUF en majuscules ---
_VXPRT_UPPERCASE:
        PUSH   ESI
        PUSH   EDI
        MOV   ESI, EAX
        LEA   EDI, _VXPRT_STRBUF
        PUSH   EDI
_VXPRT_UC_LP:
        MOV   AL, BYTE PTR [ESI]
        CMP   AL, 0
        JE   _VXPRT_UC_DONE
        CMP   AL, 'a'
        JB   _VXPRT_UC_STORE
        CMP   AL, 'z'
        JA   _VXPRT_UC_STORE
        AND   AL, 0DFh
_VXPRT_UC_STORE:
        MOV   BYTE PTR [EDI], AL
        INC    ESI
        INC    EDI
        JMP   _VXPRT_UC_LP
_VXPRT_UC_DONE:
        MOV   BYTE PTR [EDI], 0
        POP   EAX
        POP   EDI
        POP   ESI
        RET

; --- LOWERCASE : EAX=ptr ASCIIZ -> EAX=STRBUF en minuscules ---
_VXPRT_LOWERCASE:
        PUSH   ESI
        PUSH   EDI
        MOV   ESI, EAX
        LEA   EDI, _VXPRT_STRBUF
        PUSH   EDI
_VXPRT_LC_LP:
        MOV   AL, BYTE PTR [ESI]
        CMP   AL, 0
        JE   _VXPRT_LC_DONE
        CMP   AL, 'A'
        JB   _VXPRT_LC_STORE
        CMP   AL, 'Z'
        JA   _VXPRT_LC_STORE
        OR   AL, 20h
_VXPRT_LC_STORE:
        MOV   BYTE PTR [EDI], AL
        INC    ESI
        INC    EDI
        JMP   _VXPRT_LC_LP
_VXPRT_LC_DONE:
        MOV   BYTE PTR [EDI], 0
        POP   EAX
        POP   EDI
        POP   ESI
        RET

; --- TRIM : EAX=ptr ASCIIZ -> EAX=STRBUF trimmed ---
_VXPRT_TRIM:
        PUSH   ESI
        PUSH   EDI
        PUSH   ECX
        MOV   ESI, EAX
        LEA   EDI, _VXPRT_STRBUF
        PUSH   EDI
_VXPRT_TRIM_CP:
        MOV   AL, BYTE PTR [ESI]
        MOV   BYTE PTR [EDI], AL
        CMP   AL, 0
        JE   _VXPRT_TRIM_RL
        INC    ESI
        INC    EDI
        JMP   _VXPRT_TRIM_CP
_VXPRT_TRIM_RL:
        DEC    EDI
_VXPRT_TRIM_LP:
        LEA   ECX, _VXPRT_STRBUF
        CMP   EDI, ECX
        JB   _VXPRT_TRIM_DN
        CMP   BYTE PTR [EDI], 32
        JA   _VXPRT_TRIM_DN
        MOV   BYTE PTR [EDI], 0
        DEC    EDI
        JMP   _VXPRT_TRIM_LP
_VXPRT_TRIM_DN:
        POP   EAX
        POP   ECX
        POP   EDI
        POP   ESI
        RET

; --- PAD : EAX=ptr, EBX=char, ECX=taille -> EAX=STRBUF ---
_VXPRT_PAD:
        PUSH   ESI
        PUSH   EDI
        PUSH   ECX
        MOV   ESI, EAX
        LEA   EDI, _VXPRT_STRBUF
        PUSH   EDI
_VXPRT_PAD_CP:
        CMP   ECX, 0
        JLE   _VXPRT_PAD_DN
        MOV   AL, BYTE PTR [ESI]
        CMP   AL, 0
        JE   _VXPRT_PAD_FI
        MOV   BYTE PTR [EDI], AL
        INC    ESI
        INC    EDI
        DEC    ECX
        JMP   _VXPRT_PAD_CP
_VXPRT_PAD_FI:
        CMP   ECX, 0
        JLE   _VXPRT_PAD_DN
        MOV   BYTE PTR [EDI], BL
        INC    EDI
        DEC    ECX
        JMP   _VXPRT_PAD_FI
_VXPRT_PAD_DN:
        MOV   BYTE PTR [EDI], 0
        POP   EAX
        POP   ECX
        POP   EDI
        POP   ESI
        RET

; --- FILL : EAX=ptr, EBX=byte, ECX=count ---
_VXPRT_FILL:
        PUSH   EDI
        PUSH   ECX
        MOV   EDI, EAX
        MOV   AL, BL
        REP    STOSB
        POP   ECX
        POP   EDI
        RET

; --- ZERO : EAX=ptr, ECX=count ---
_VXPRT_ZERO:
        PUSH   EDI
        PUSH   ECX
        MOV   EDI, EAX
        XOR   AL, AL
        REP    STOSB
        POP   ECX
        POP   EDI
        RET

; --- STRCPY : EAX=src -> EAX=STRBUF (copie ASCIIZ) ---
_VXPRT_STRCPY:
        PUSH   ESI
        PUSH   EDI
        MOV   ESI, EAX
        LEA   EDI, _VXPRT_STRBUF
        PUSH   EDI
_VXPRT_SCPY_LP:
        MOV   AL, BYTE PTR [ESI]
        MOV   BYTE PTR [EDI], AL
        CMP   AL, 0
        JE   _VXPRT_SCPY_DN
        INC    ESI
        INC    EDI
        JMP   _VXPRT_SCPY_LP
_VXPRT_SCPY_DN:
        POP   EAX
        POP   EDI
        POP   ESI
        RET

; --- STRCMPI : EAX=s1, EBX=s2 -> EAX=diff (case-insensitive) ---
_VXPRT_STRCMPI:
        PUSH   ESI
        PUSH   EDI
        PUSH   EBX
        MOV   ESI, EAX
        MOV   EDI, EBX
_VXPRT_SCMPI_LP:
        MOVZX   EAX, BYTE PTR [ESI]
        MOVZX   EBX, BYTE PTR [EDI]
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
        TEST   AL, AL
        JZ   _VXPRT_SCMPI_EQ
        INC    ESI
        INC    EDI
        JMP   _VXPRT_SCMPI_LP
_VXPRT_SCMPI_EQ:
        XOR   EAX, EAX
        JMP   _VXPRT_SCMPI_DN
_VXPRT_SCMPI_NE:
        SUB   EAX, EBX
_VXPRT_SCMPI_DN:
        POP   EBX
        POP   EDI
        POP   ESI
        RET

; --- SEARCH : EAX=haystack, EBX=needle -> EAX=pos (1-based, 0=absent) ---
_VXPRT_SEARCH:
        PUSH   ESI
        PUSH   EDI
        PUSH   ECX
        PUSH   EDX
        MOV   ESI, EAX
        MOV   EDI, EBX
        XOR   ECX, ECX
_VXPRT_SRCH_LP:
        CMP   BYTE PTR [ESI], 0
        JE   _VXPRT_SRCH_NF
        INC    ECX
        PUSH   ESI
        PUSH   EDI
_VXPRT_SRCH_CMP:
        MOV   AL, BYTE PTR [EDI]
        CMP   AL, 0
        JE   _VXPRT_SRCH_FD
        CMP   AL, BYTE PTR [ESI]
        JNE   _VXPRT_SRCH_NX
        INC    ESI
        INC    EDI
        JMP   _VXPRT_SRCH_CMP
_VXPRT_SRCH_FD:
        POP   EDI
        POP   ESI
        MOV   EAX, ECX
        JMP   _VXPRT_SRCH_DN
_VXPRT_SRCH_NX:
        POP   EDI
        POP   ESI
        INC    ESI
        JMP   _VXPRT_SRCH_LP
_VXPRT_SRCH_NF:
        XOR   EAX, EAX
_VXPRT_SRCH_DN:
        POP   EDX
        POP   ECX
        POP   EDI
        POP   ESI
        RET

; --- VERIFY : EAX=str, EBX=charset -> EAX=pos (1-based, 0=all match) ---
_VXPRT_VERIFY:
        PUSH   ESI
        PUSH   EDI
        PUSH   ECX
        MOV   ESI, EAX
        XOR   ECX, ECX
_VXPRT_VRFY_LP:
        MOV   AL, BYTE PTR [ESI]
        CMP   AL, 0
        JE   _VXPRT_VRFY_OK
        INC    ECX
        MOV   EDI, EBX
_VXPRT_VRFY_CS:
        MOV   AH, BYTE PTR [EDI]
        CMP   AH, 0
        JE   _VXPRT_VRFY_NF
        CMP   AL, AH
        JE   _VXPRT_VRFY_NX
        INC    EDI
        JMP   _VXPRT_VRFY_CS
_VXPRT_VRFY_NF:
        MOV   EAX, ECX
        JMP   _VXPRT_VRFY_DN
_VXPRT_VRFY_NX:
        INC    ESI
        JMP   _VXPRT_VRFY_LP
_VXPRT_VRFY_OK:
        XOR   EAX, EAX
_VXPRT_VRFY_DN:
        POP   ECX
        POP   EDI
        POP   ESI
        RET

; --- MESSAGE : EAX=ptr ASCIIZ message ---
_VXPRT_MESSAGE:
        PUSH   EAX
        CALL   _VXPRT_PRINTSTR
        ADD   ESP, 4
        CALL   _VXPRT_NEWLINE
        RET

; --- DATE : -> EAX=ptr DATEBUF ---
_VXPRT_DATE:
        PUSH   ECX
        PUSH   EDX
        SUB   ESP, 16
        PUSH   ESP
        CALL   GetLocalTime
        MOVZX   EAX, WORD PTR [ESP+6]
        PUSH   EAX
        CALL   _VXPRT_NUMTOSTR
        ADD   ESP, 4
        PUSH   EAX
        LEA   EDI, _VXPRT_DATEBUF
        MOV   ESI, EAX
        CALL   _VXPRT_STRCOPY
        POP   EAX
        PUSH   EAX
        CALL   _VXPRT_STRLEN
        ADD   ESP, 4
        LEA   EDI, _VXPRT_DATEBUF
        ADD   EDI, EAX
        MOV   BYTE PTR [EDI], '-'
        INC    EDI
        MOVZX   EAX, WORD PTR [ESP+2]
        PUSH   EAX
        CALL   _VXPRT_NUMTOSTR
        ADD   ESP, 4
        MOV   ESI, EAX
        CALL   _VXPRT_STRCOPY
        LEA   EAX, _VXPRT_DATEBUF
        PUSH   EAX
        CALL   _VXPRT_STRLEN
        ADD   ESP, 4
        LEA   EDI, _VXPRT_DATEBUF
        ADD   EDI, EAX
        MOV   BYTE PTR [EDI], '-'
        INC    EDI
        MOVZX   EAX, WORD PTR [ESP]
        PUSH   EAX
        CALL   _VXPRT_NUMTOSTR
        ADD   ESP, 4
        MOV   ESI, EAX
        CALL   _VXPRT_STRCOPY
        ADD   ESP, 16
        LEA   EAX, _VXPRT_DATEBUF
        POP   EDX
        POP   ECX
        RET

; --- TIME : -> EAX=ptr TIMEBUF ---
_VXPRT_TIME:
        PUSH   ECX
        PUSH   EDX
        SUB   ESP, 16
        PUSH   ESP
        CALL   GetLocalTime
        MOVZX   EAX, WORD PTR [ESP+8]
        PUSH   EAX
        CALL   _VXPRT_NUMTOSTR
        ADD   ESP, 4
        LEA   EDI, _VXPRT_TIMEBUF
        MOV   ESI, EAX
        CALL   _VXPRT_STRCOPY
        LEA   EAX, _VXPRT_TIMEBUF
        PUSH   EAX
        CALL   _VXPRT_STRLEN
        ADD   ESP, 4
        LEA   EDI, _VXPRT_TIMEBUF
        ADD   EDI, EAX
        MOV   BYTE PTR [EDI], ':'
        INC    EDI
        MOVZX   EAX, WORD PTR [ESP+10]
        PUSH   EAX
        CALL   _VXPRT_NUMTOSTR
        ADD   ESP, 4
        MOV   ESI, EAX
        CALL   _VXPRT_STRCOPY
        LEA   EAX, _VXPRT_TIMEBUF
        PUSH   EAX
        CALL   _VXPRT_STRLEN
        ADD   ESP, 4
        LEA   EDI, _VXPRT_TIMEBUF
        ADD   EDI, EAX
        MOV   BYTE PTR [EDI], ':'
        INC    EDI
        MOVZX   EAX, WORD PTR [ESP+12]
        PUSH   EAX
        CALL   _VXPRT_NUMTOSTR
        ADD   ESP, 4
        MOV   ESI, EAX
        CALL   _VXPRT_STRCOPY
        ADD   ESP, 16
        LEA   EAX, _VXPRT_TIMEBUF
        POP   EDX
        POP   ECX
        RET

; --- CLOCK : -> EAX=GetTickCount ms ---
_VXPRT_CLOCK:
        CALL   GetTickCount
        RET

; --- POWI : EAX=base, EBX=exp -> EAX=base^exp ---
_VXPRT_POWI:
        PUSH   ECX
        PUSH   EDX
        MOV   ECX, EBX
        MOV   EDX, EAX
        MOV   EAX, 1
_VXPRT_POWI_LP:
        CMP   ECX, 0
        JLE   _VXPRT_POWI_DN
        IMUL   EAX, EDX
        DEC    ECX
        JMP   _VXPRT_POWI_LP
_VXPRT_POWI_DN:
        POP   EDX
        POP   ECX
        RET

; --- DELETE : EAX=str, EBX=pos(1-based), ECX=count -> EAX=STRBUF ---
_VXPRT_DELETE:
        PUSH   ESI
        PUSH   EDI
        PUSH   EDX
        MOV   ESI, EAX
        LEA   EDI, _VXPRT_STRBUF
        PUSH   EDI
        MOV   EDX, EBX
        DEC    EDX
_VXPRT_DEL_B:
        CMP   EDX, 0
        JLE   _VXPRT_DEL_SK
        MOV   AL, BYTE PTR [ESI]
        CMP   AL, 0
        JE   _VXPRT_DEL_DN
        MOV   BYTE PTR [EDI], AL
        INC    ESI
        INC    EDI
        DEC    EDX
        JMP   _VXPRT_DEL_B
_VXPRT_DEL_SK:
        MOV   EDX, ECX
_VXPRT_DEL_S:
        CMP   EDX, 0
        JLE   _VXPRT_DEL_CP
        CMP   BYTE PTR [ESI], 0
        JE   _VXPRT_DEL_DN
        INC    ESI
        DEC    EDX
        JMP   _VXPRT_DEL_S
_VXPRT_DEL_CP:
        MOV   AL, BYTE PTR [ESI]
        MOV   BYTE PTR [EDI], AL
        CMP   AL, 0
        JE   _VXPRT_DEL_DN
        INC    ESI
        INC    EDI
        JMP   _VXPRT_DEL_CP
_VXPRT_DEL_DN:
        MOV   BYTE PTR [EDI], 0
        POP   EAX
        POP   EDX
        POP   EDI
        POP   ESI
        RET

; --- INSERT : EAX=dst, EBX=ins, ECX=pos(1-based) -> EAX=STRBUF ---
_VXPRT_INSERT:
        PUSH   ESI
        PUSH   EDI
        PUSH   EDX
        MOV   ESI, EAX
        LEA   EDI, _VXPRT_STRBUF
        PUSH   EDI
        MOV   EDX, ECX
        DEC    EDX
_VXPRT_INS_B:
        CMP   EDX, 0
        JLE   _VXPRT_INS_I
        MOV   AL, BYTE PTR [ESI]
        CMP   AL, 0
        JE   _VXPRT_INS_I
        MOV   BYTE PTR [EDI], AL
        INC    ESI
        INC    EDI
        DEC    EDX
        JMP   _VXPRT_INS_B
_VXPRT_INS_I:
        PUSH   ESI
        MOV   ESI, EBX
_VXPRT_INS_IL:
        MOV   AL, BYTE PTR [ESI]
        CMP   AL, 0
        JE   _VXPRT_INS_ID
        MOV   BYTE PTR [EDI], AL
        INC    ESI
        INC    EDI
        JMP   _VXPRT_INS_IL
_VXPRT_INS_ID:
        POP   ESI
_VXPRT_INS_CP:
        MOV   AL, BYTE PTR [ESI]
        MOV   BYTE PTR [EDI], AL
        CMP   AL, 0
        JE   _VXPRT_INS_DN
        INC    ESI
        INC    EDI
        JMP   _VXPRT_INS_CP
_VXPRT_INS_DN:
        POP   EAX
        POP   EDX
        POP   EDI
        POP   ESI
        RET

; --- VAL : EAX=ptr ASCIIZ -> EAX=valeur entiere ---
_VXPRT_VAL:
        PUSH   EAX
        CALL   _VXPRT_STRTONUM
        ADD   ESP, 4
        RET

; --- FOPEN : EAX=filename ASCIIZ -> EAX=handle ---
_VXPRT_FOPEN:
        PUSH   0
        PUSH   128
        PUSH   3
        PUSH   0
        PUSH   1
        PUSH   80000000h
        PUSH   EAX
        CALL   CreateFileA
        RET

; --- FCREATE : EAX=filename -> EAX=handle ---
_VXPRT_FCREATE:
        PUSH   0
        PUSH   128
        PUSH   2
        PUSH   0
        PUSH   0
        PUSH   40000000h
        PUSH   EAX
        CALL   CreateFileA
        RET

; --- FCLOSE : EAX=handle ---
_VXPRT_FCLOSE:
        PUSH   EAX
        CALL   CloseHandle
        RET

; --- FREAD : EAX=handle, EBX=buf, ECX=count -> EAX=bytes_read ---
_VXPRT_FREAD:
        PUSH   0
        PUSH   OFFSET _VXPRT_WRITTEN
        PUSH   ECX
        PUSH   EBX
        PUSH   EAX
        CALL   ReadFile
        MOV   EAX, DWORD PTR [_VXPRT_WRITTEN]
        RET

; --- FWRITE : EAX=handle, EBX=buf, ECX=count -> EAX=bytes_written ---
_VXPRT_FWRITE:
        PUSH   0
        PUSH   OFFSET _VXPRT_WRITTEN
        PUSH   ECX
        PUSH   EBX
        PUSH   EAX
        CALL   WriteFile
        MOV   EAX, DWORD PTR [_VXPRT_WRITTEN]
        RET

; --- FDELETE : EAX=filename -> EAX=result ---
_VXPRT_FDELETE:
        PUSH   EAX
        CALL   DeleteFileA
        RET

; --- VMS_STUB : stub retourne 0 ---
_VXPRT_VMS_STUB:
        XOR   EAX, EAX
        RET

_TEXT   ENDS
_DATA   SEGMENT DWORD PUBLIC 'DATA'
; --- Buffers internes ---
_VXPRT_CRLF    DB  13,10,0
_VXPRT_STRBUF  DB  512 DUP(0)
_VXPRT_CHRBUF  DB  2 DUP(0)
_VXPRT_NUMBUF  DB  16 DUP(0)
_VXPRT_TRUE_S  DB  'TRUE',0
_VXPRT_FALSE_S DB  'FALSE',0
_VXPRT_HEAP    DB  4096 DUP(0)
_VXPRT_HEAPTOP DD  OFFSET _VXPRT_HEAP
_VXPRT_SEED    DD  1
_VXPRT_SETBUF  DB  32 DUP(0)
_VXPRT_STMP1   DB  32 DUP(0)
_VXPRT_STMP2   DB  32 DUP(0)
_VXPRT_DATEBUF DB  16 DUP(0)
_VXPRT_TIMEBUF DB  12 DUP(0)
_VXPRT_ASSERTMSG DB 'Assertion failed',0
_VXPRT_HSTDOUT DD  0
_VXPRT_HSTDIN  DD  0
_VXPRT_WRITTEN DD  0
_VXPRT_HHEAP   DD  0

; --- File Descriptor Blocks predefinis ---
_VXP_INPUT   DD  0
        DD  1
        DB  'CON',0
        DB  120 DUP(0)
_VXP_OUTPUT  DD  0
        DD  2
        DB  'CON',0
        DB  120 DUP(0)
_VXP_TTY     DD  0
        DD  1
        DB  'CON',0
        DB  120 DUP(0)
_VXP_TTYOUTPUT DD  0
        DD  2
        DB  'CON',0
        DB  120 DUP(0)
_VXP_ERROR   DD  0
        DD  2
        DB  'CON',0
        DB  120 DUP(0)
_VXPRT_CURHDL  DD  0
_VXPRT_IOSTATUS DD  0
_VXPRT_FNAMEBUF DB  128 DUP(0)
_VXPRT_FRDCBUF DB  2 DUP(0)

; --- Exception handler frame ---
_VXPRT_EXCHDL  DD  0
_VXPRT_EXCSP   DD  0
_VXPRT_EXCBP   DD  0
_VXPRT_EXCCODE DD  0
_VXPRT_EXCVAL  DD  0
_VXPRT_EXCPHDL DD  0
_VXPRT_EXCPSP  DD  0
_VXPRT_EXCPBP  DD  0
; --- Messages d erreur runtime ---
_VXPRT_DIV0MSG DB  'Runtime error: Division by zero',0
_VXPRT_OVFMSG  DB  'Runtime error: Integer overflow',0
_VXPRT_RNGMSG  DB  'Runtime error: Range check error',0
_VXPRT_NILMSG  DB  'Runtime error: Nil pointer dereference',0
_VXPRT_SIGMSG  DB  'Runtime error: Unhandled condition',0

; --- Donnees du programme ---
_VXP_I  DD  0
_VXP_U  DD  0
_VXP_C  DB  0
_VXP_B  DB  0
_VXP_P  DD  0
_VXPK_3  DB  'i::unsigned = ',0
_VXPK_4  DB  'chr(65) = ',0
_VXPK_5  DB  'Z',0
_VXPK_6  DB  'ord(Z) = ',0
_VXPK_7  DB  'ord(true) = ',0
_VXPK_8  DB  'address(i) -> p^ = ',0
_VXPK_9  DB  'Test coercitions termine.',0
_DATA   ENDS
        END     _VXPF_MAIN
