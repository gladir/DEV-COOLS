; CF86 v1.0 - 2026-03-06
; Compilateur ColdFusion -> assembleur 8086
; Source: SAMPLES/CF/test_writeoutput.cfm

.MODEL SMALL
.STACK 1024

_TEXT SEGMENT PUBLIC 'CODE'
        ASSUME CS:_TEXT, DS:_DATA, SS:NOTHING

; Point d'entree programme CF86
_CFF_Main:
        PUSH   BP
        MOV   BP, SP
        MOV   AX, _DATA
        MOV   DS, AX

; ---- VAR (local) ----
        MOV   AX, OFFSET _CFK_1
        MOV   [_CFV_greeting], AX
        MOV   AX, OFFSET _CFV_greeting
; WriteOutput: chaine
        MOV   SI, AX
        CALL   _CFRT_PRINT
        MOV   AX, 123
; WriteOutput: numerique
        CALL   _CFRT_PRINTNUM

; --- Fin du code ---
        MOV   SP, BP
        POP   BP
        MOV   AX, 4C00h
        INT   21h


; --- Runtime minimal CF86 ---

_CFRT_STRLEN:
        PUSH   SI
        XOR   CX, CX
_CFRT_STRLEN_L:
        LODSB
        OR   AL, AL
        JZ   _CFRT_STRLEN_E
        INC   CX
        JMP   _CFRT_STRLEN_L
_CFRT_STRLEN_E:
        POP   SI
        RET

_CFRT_PRINT:
        PUSH   AX
        PUSH   BX
        PUSH   CX
        PUSH   DX
        CALL   _CFRT_STRLEN
        MOV   DX, SI
        MOV   BX, 1
        MOV   AH, 40h
        INT   21h
        POP   DX
        POP   CX
        POP   BX
        POP   AX
        RET

_CFRT_PRINTLN:
        CALL   _CFRT_PRINT
        MOV   SI, OFFSET _CF_CRLF
        CALL   _CFRT_PRINT
        RET

_CFRT_NUMTOSTR:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        PUSH   DI
        MOV   DI, OFFSET _CF_NUMBUF
        ADD   DI, 11
        MOV   BYTE PTR [DI], 0
        DEC   DI
        MOV   CX, AX
        OR   AX, AX
        JNS   _CFRT_NTS_POS
        NEG   AX
_CFRT_NTS_POS:
        MOV   BX, 10
_CFRT_NTS_LP:
        XOR   DX, DX
        DIV   BX
        ADD   DL, '0'
        MOV   [DI], DL
        DEC   DI
        OR   AX, AX
        JNZ   _CFRT_NTS_LP
        OR   CX, CX
        JNS   _CFRT_NTS_DN
        MOV   BYTE PTR [DI], '-'
        DEC   DI
_CFRT_NTS_DN:
        INC   DI
        MOV   AX, DI
        POP   DI
        POP   DX
        POP   CX
        POP   BX
        RET

_CFRT_PRINTNUM:
        CALL   _CFRT_NUMTOSTR
        MOV   SI, AX
        CALL   _CFRT_PRINT
        RET

_TEXT ENDS

_DATA SEGMENT PUBLIC 'DATA'

; Donnees statiques CF86

_CF_CRLF  DB  13,10,0
_CF_NULL_STR  DB  0
_CF_STRBUF  DB  256 DUP(0)
_CF_TXTBUF  DB  512 DUP(0)
_CF_NUMBUF  DB  12 DUP(0)
_CF_SWTMP  DW  0
_CF_LOOPLIM  DW  0
_CF_LOOPSTP  DW  0
_CFK_1  DB  'Bonjour',0
_CFV_greeting  DW  0

_DATA ENDS

END _CFF_Main
