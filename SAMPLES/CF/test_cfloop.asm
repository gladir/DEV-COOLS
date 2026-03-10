; CF86 v1.0 - 2026-03-06
; Compilateur ColdFusion -> assembleur 8086
; Source: SAMPLES/CF/test_cfloop.cfm

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

; ---- CFSET ----
        MOV   AX, 0
        MOV   [_CFV_total], AX
; cfloop: FOR i = 1 TO 5 STEP 1
        MOV   AX, 1
        MOV   [_CFV_i], AX
        MOV   AX, 5
        MOV   [_CF_LOOPLIM], AX
        MOV   AX, 1
        MOV   [_CF_LOOPSTP], AX
_CFL_FTEST_1:
        MOV   AX, [_CFV_i]
        CMP   AX, [_CF_LOOPLIM]
        JG   _CFL_FEND_3
; ---- CFSET ----
        MOV   AX, [_CFV_total]
        MOV   AX, [_CFV_i]
        PUSH   AX
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [_CFV_total], AX
_CFL_FINCR_2:
        MOV   AX, [_CFV_i]
        ADD   AX, [_CF_LOOPSTP]
        MOV   [_CFV_i], AX
        JMP   _CFL_FTEST_1
_CFL_FEND_3:
        MOV   AX, [_CFV_total]
; cfoutput: expr numerique
        CALL   _CFRT_PRINTNUM
; ---- CFSET ----
        MOV   AX, 0
        MOV   [_CFV_countdown], AX
; cfloop: FOR j = 10 TO 1 STEP -1
        MOV   AX, 10
        MOV   [_CFV_j], AX
        MOV   AX, 1
        MOV   [_CF_LOOPLIM], AX
        MOV   AX, -1
        MOV   [_CF_LOOPSTP], AX
_CFL_FTEST_4:
        MOV   AX, [_CFV_j]
        CMP   AX, [_CF_LOOPLIM]
        JL   _CFL_FEND_6
; ---- CFSET ----
        MOV   AX, [_CFV_countdown]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [_CFV_countdown], AX
_CFL_FINCR_5:
        MOV   AX, [_CFV_j]
        ADD   AX, [_CF_LOOPSTP]
        MOV   [_CFV_j], AX
        JMP   _CFL_FTEST_4
_CFL_FEND_6:
; ---- CFSET ----
        MOV   AX, 0
        MOV   [_CFV_sum], AX
; cfloop: FOR k = 1 TO 10 STEP 2
        MOV   AX, 1
        MOV   [_CFV_k], AX
        MOV   AX, 10
        MOV   [_CF_LOOPLIM], AX
        MOV   AX, 2
        MOV   [_CF_LOOPSTP], AX
_CFL_FTEST_7:
        MOV   AX, [_CFV_k]
        CMP   AX, [_CF_LOOPLIM]
        JG   _CFL_FEND_9
; ---- CFSET ----
        MOV   AX, [_CFV_sum]
        MOV   AX, [_CFV_k]
        PUSH   AX
        MOV   BX, AX
        POP   AX
        ADD   AX, BX
        MOV   [_CFV_sum], AX
_CFL_FINCR_8:
        MOV   AX, [_CFV_k]
        ADD   AX, [_CF_LOOPSTP]
        MOV   [_CFV_k], AX
        JMP   _CFL_FTEST_7
_CFL_FEND_9:
        MOV   AX, [_CFV_sum]
; cfoutput: expr numerique
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
_CFV_total  DW  0
_CFV_i  DW  0
_CFV_countdown  DW  0
_CFV_j  DW  0
_CFV_sum  DW  0
_CFV_k  DW  0

_DATA ENDS

END _CFF_Main
