; ========================================
; Genere par PSPCW32 v1.0 (2026-03-07)
; Source : SAMPLES/PSP/test_string.psp
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

.STACK 4096

; --- Segment de code ---
_TEXT   SEGMENT DWORD PUBLIC 'CODE'
        ASSUME CS:_TEXT

; --- Point d entree principal ---
_PSPF_main:
; Obtenir le handle stdout
        PUSH   -11
        CALL   _GetStdHandle@4
        MOV   DWORD PTR [_PSPRT_HSTDOUT], EAX

        JMP   _PSPL_MAINBODY

; html fragment
        MOV   ESI, OFFSET _PSPK_HTML_1
        CALL   _PSPRT_PRINTSTR
_PSPL_MAINBODY:
; assign msg1
        LEA   EAX, _PSPK_2
        MOV   DWORD PTR [_PSP_MSG1], EAX
; assign msg2
        LEA   EAX, _PSPK_3
        MOV   DWORD PTR [_PSP_MSG2], EAX
; writeln
        LEA   EAX, _PSPK_4
        MOV   ESI, EAX
        CALL   _PSPRT_PRINTSTR
        LEA   EAX, _PSPK_5
        MOV   ESI, EAX
        CALL   _PSPRT_PRINTSTR
        MOV   ESI, OFFSET _PSPRT_CRLF
        CALL   _PSPRT_PRINTSTR
; writeln
        LEA   EAX, _PSPK_6
        MOV   ESI, EAX
        CALL   _PSPRT_PRINTSTR
        MOV   EAX, DWORD PTR [_PSP_MSG1]
        MOV   ESI, EAX
        CALL   _PSPRT_PRINTSTR
        LEA   EAX, _PSPK_7
        MOV   ESI, EAX
        CALL   _PSPRT_PRINTSTR
        MOV   ESI, OFFSET _PSPRT_CRLF
        CALL   _PSPRT_PRINTSTR
; writeln
        LEA   EAX, _PSPK_8
        MOV   ESI, EAX
        CALL   _PSPRT_PRINTSTR
        MOV   EAX, DWORD PTR [_PSP_MSG2]
        MOV   ESI, EAX
        CALL   _PSPRT_PRINTSTR
        LEA   EAX, _PSPK_9
        MOV   ESI, EAX
        CALL   _PSPRT_PRINTSTR
        MOV   ESI, OFFSET _PSPRT_CRLF
        CALL   _PSPRT_PRINTSTR
; writeln
        LEA   EAX, _PSPK_10
        MOV   ESI, EAX
        CALL   _PSPRT_PRINTSTR
        XOR   EAX, EAX
        CALL   _PSPRT_NUMTOSTR
        MOV   ESI, OFFSET _PSPRT_NUMBUF
        CALL   _PSPRT_PRINTSTR
        LEA   EAX, _PSPK_11
        MOV   ESI, EAX
        CALL   _PSPRT_PRINTSTR
        MOV   ESI, OFFSET _PSPRT_CRLF
        CALL   _PSPRT_PRINTSTR
; writeln
        LEA   EAX, _PSPK_12
        MOV   ESI, EAX
        CALL   _PSPRT_PRINTSTR
        MOV   ESI, OFFSET _PSPRT_CRLF
        CALL   _PSPRT_PRINTSTR
; html fragment
        MOV   ESI, OFFSET _PSPK_HTML_13
        CALL   _PSPRT_PRINTSTR


; --- Sortie programme ---
        PUSH   0
        CALL   _ExitProcess@4

; ========================================
;   ROUTINES RUNTIME 32 BITS
; ========================================

_PSPRT_PRINTSTR:
        PUSH   ESI
        MOV   EDI, ESI
; calculer la longueur
        XOR   ECX, ECX
_PSPRT_PRINTSTR_L:
        CMP   BYTE PTR [EDI], 0
        JE   _PSPRT_PRINTSTR_W
        INC   EDI
        INC   ECX
        JMP   _PSPRT_PRINTSTR_L
_PSPRT_PRINTSTR_W:
; WriteFile(hStdout, pStr, len, pWritten, 0)
        PUSH   0
        PUSH   OFFSET _PSPRT_WRITTEN
        PUSH   ECX
        PUSH   ESI
        PUSH   DWORD PTR [_PSPRT_HSTDOUT]
        CALL   _WriteFile@20
        POP   ESI
        RET

_PSPRT_NUMTOSTR:
        PUSH   EBX
        PUSH   ECX
        PUSH   EDX
        PUSH   EDI
        LEA   EDI, _PSPRT_NUMBUF + 15
        MOV   BYTE PTR [EDI], 0
        MOV   ECX, 0
        MOV   EBX, 10
        CMP   EAX, 0
        JGE   _PSPRT_NTS_POS
        NEG   EAX
        MOV   ECX, 1
_PSPRT_NTS_POS:
        CMP   EAX, 0
        JNE   _PSPRT_NTS_LOOP
        DEC   EDI
        MOV   BYTE PTR [EDI], '0'
        JMP   _PSPRT_NTS_SIGN
_PSPRT_NTS_LOOP:
        CMP   EAX, 0
        JE   _PSPRT_NTS_SIGN
        XOR   EDX, EDX
        DIV   EBX
        ADD   DL, '0'
        DEC   EDI
        MOV   BYTE PTR [EDI], DL
        JMP   _PSPRT_NTS_LOOP
_PSPRT_NTS_SIGN:
        CMP   ECX, 1
        JNE   _PSPRT_NTS_DONE
        DEC   EDI
        MOV   BYTE PTR [EDI], '-'
_PSPRT_NTS_DONE:
        MOV   EAX, EDI
        POP   EDI
        POP   EDX
        POP   ECX
        POP   EBX
        RET

_PSPRT_STRLEN:
        PUSH   EDI
        MOV   EDI, ESI
        XOR   EAX, EAX
_PSPRT_STRLEN_L:
        CMP   BYTE PTR [EDI], 0
        JE   _PSPRT_STRLEN_D
        INC   EDI
        INC   EAX
        JMP   _PSPRT_STRLEN_L
_PSPRT_STRLEN_D:
        POP   EDI
        RET

_PSPRT_CONCAT:
        PUSH   EBX
        LEA   EBX, _PSPRT_STRBUF
_PSPRT_CONC_L1:
        MOV   AL, BYTE PTR [ESI]
        MOV   BYTE PTR [EBX], AL
        CMP   AL, 0
        JE   _PSPRT_CONC_L2
        INC   ESI
        INC   EBX
        JMP   _PSPRT_CONC_L1
_PSPRT_CONC_L2:
        MOV   AL, BYTE PTR [EDI]
        MOV   BYTE PTR [EBX], AL
        CMP   AL, 0
        JE   _PSPRT_CONC_DN
        INC   EDI
        INC   EBX
        JMP   _PSPRT_CONC_L2
_PSPRT_CONC_DN:
        LEA   EAX, _PSPRT_STRBUF
        POP   EBX
        RET

_PSPRT_STRCMP:
        PUSH   EBX
_PSPRT_SCMP_L:
        MOV   AL, BYTE PTR [ESI]
        MOV   BL, BYTE PTR [EDI]
        CMP   AL, BL
        JB   _PSPRT_SCMP_LT
        JA   _PSPRT_SCMP_GT
        CMP   AL, 0
        JE   _PSPRT_SCMP_EQ
        INC   ESI
        INC   EDI
        JMP   _PSPRT_SCMP_L
_PSPRT_SCMP_EQ:
        XOR   EAX, EAX
        JMP   _PSPRT_SCMP_DN
_PSPRT_SCMP_LT:
        MOV   EAX, -1
        JMP   _PSPRT_SCMP_DN
_PSPRT_SCMP_GT:
        MOV   EAX, 1
_PSPRT_SCMP_DN:
        POP   EBX
        RET

_PSPRT_WRITECRLF:
        LEA   ESI, _PSPRT_CRLF
        CALL   _PSPRT_PRINTSTR
        RET

_PSPRT_CHR:
        MOV   BYTE PTR [_PSPRT_CHRBUF], AL
        MOV   BYTE PTR [_PSPRT_CHRBUF + 1], 0
        LEA   EAX, _PSPRT_CHRBUF
        RET

_PSPRT_STRTONUM:
        PUSH   EBX
        PUSH   ECX
        XOR   EAX, EAX
        XOR   ECX, ECX
        CMP   BYTE PTR [ESI], '-'
        JNE   _PSPRT_STN_LP
        MOV   ECX, 1
        INC   ESI
_PSPRT_STN_LP:
        MOVZX   EBX, BYTE PTR [ESI]
        CMP   EBX, '0'
        JB   _PSPRT_STN_DN
        CMP   EBX, '9'
        JA   _PSPRT_STN_DN
        SUB   EBX, '0'
        IMUL   EAX, 10
        ADD   EAX, EBX
        INC   ESI
        JMP   _PSPRT_STN_LP
_PSPRT_STN_DN:
        CMP   ECX, 1
        JNE   _PSPRT_STN_OK
        NEG   EAX
_PSPRT_STN_OK:
        POP   ECX
        POP   EBX
        RET

_PSPRT_COPY:
        PUSH   EBX
        DEC   ECX
        ADD   ESI, ECX
        LEA   EBX, _PSPRT_STRBUF
_PSPRT_COPY_L:
        CMP   EDX, 0
        JLE   _PSPRT_COPY_DN
        MOV   AL, BYTE PTR [ESI]
        CMP   AL, 0
        JE   _PSPRT_COPY_DN
        MOV   BYTE PTR [EBX], AL
        INC   ESI
        INC   EBX
        DEC   EDX
        JMP   _PSPRT_COPY_L
_PSPRT_COPY_DN:
        MOV   BYTE PTR [EBX], 0
        LEA   EAX, _PSPRT_STRBUF
        POP   EBX
        RET

_PSPRT_POS:
        PUSH   EBX
        PUSH   ECX
        MOV   EBX, EDI
        XOR   ECX, ECX
_PSPRT_POS_NX:
        CMP   BYTE PTR [EBX], 0
        JE   _PSPRT_POS_NF
        INC   ECX
        PUSH   ESI
        PUSH   EBX
_PSPRT_POS_CM:
        MOV   AL, BYTE PTR [ESI]
        CMP   AL, 0
        JE   _PSPRT_POS_FD
        CMP   AL, BYTE PTR [EBX]
        JNE   _PSPRT_POS_NM
        INC   ESI
        INC   EBX
        JMP   _PSPRT_POS_CM
_PSPRT_POS_FD:
        POP   EBX
        POP   ESI
        MOV   EAX, ECX
        JMP   _PSPRT_POS_DN
_PSPRT_POS_NM:
        POP   EBX
        POP   ESI
        INC   EBX
        JMP   _PSPRT_POS_NX
_PSPRT_POS_NF:
        XOR   EAX, EAX
_PSPRT_POS_DN:
        POP   ECX
        POP   EBX
        RET

_PSPRT_UPCASE:
        CMP   AL, 'a'
        JB   _PSPRT_UPC_DN
        CMP   AL, 'z'
        JA   _PSPRT_UPC_DN
        SUB   AL, 32
_PSPRT_UPC_DN:
        RET

_PSPRT_LOWERCASE:
        PUSH   EDI
        LEA   EDI, _PSPRT_STRBUF
        PUSH   EDI
_PSPRT_LC_LP:
        MOV   AL, BYTE PTR [ESI]
        CMP   AL, 0
        JE   _PSPRT_LC_DN
        CMP   AL, 'A'
        JB   _PSPRT_LC_SK
        CMP   AL, 'Z'
        JA   _PSPRT_LC_SK
        ADD   AL, 32
_PSPRT_LC_SK:
        MOV   BYTE PTR [EDI], AL
        INC   ESI
        INC   EDI
        JMP   _PSPRT_LC_LP
_PSPRT_LC_DN:
        MOV   BYTE PTR [EDI], 0
        POP   EAX
        POP   EDI
        RET

_PSPRT_TRIM:
        PUSH   EDI
_PSPRT_TR_LS:
        MOV   AL, BYTE PTR [ESI]
        CMP   AL, 32
        JE   _PSPRT_TR_LN
        CMP   AL, 9
        JNE   _PSPRT_TR_CP
_PSPRT_TR_LN:
        INC   ESI
        JMP   _PSPRT_TR_LS
_PSPRT_TR_CP:
        LEA   EDI, _PSPRT_STRBUF
        PUSH   EDI
_PSPRT_TR_C2:
        MOV   AL, BYTE PTR [ESI]
        MOV   BYTE PTR [EDI], AL
        CMP   AL, 0
        JE   _PSPRT_TR_TS
        INC   ESI
        INC   EDI
        JMP   _PSPRT_TR_C2
_PSPRT_TR_TS:
        DEC   EDI
        POP   EAX
        PUSH   EAX
        CMP   EDI, EAX
        JB   _PSPRT_TR_DN
        CMP   BYTE PTR [EDI], 32
        JE   _PSPRT_TR_T2
        CMP   BYTE PTR [EDI], 9
        JNE   _PSPRT_TR_DN
_PSPRT_TR_T2:
        MOV   BYTE PTR [EDI], 0
        DEC   EDI
        POP   EAX
        PUSH   EAX
        CMP   EDI, EAX
        JAE   _PSPRT_TR_TS
_PSPRT_TR_DN:
        POP   EAX
        POP   EDI
        RET

_PSPRT_DELETE:
        CMP   EBX, 0
        JE   _PSPRT_DEL_DN
        CMP   ECX, 0
        JE   _PSPRT_DEL_DN
        PUSH   EDI
        DEC   EBX
        LEA   EDI, [ESI+EBX]
        LEA   ESI, [EDI+ECX]
_PSPRT_DEL_LP:
        MOV   AL, BYTE PTR [ESI]
        MOV   BYTE PTR [EDI], AL
        CMP   AL, 0
        JE   _PSPRT_DEL_D2
        INC   ESI
        INC   EDI
        JMP   _PSPRT_DEL_LP
_PSPRT_DEL_D2:
        POP   EDI
_PSPRT_DEL_DN:
        RET

_PSPRT_INSERT:
        PUSH   EBP
        MOV   EBP, ESP
        PUSH   ESI
        PUSH   EDI
        XOR   ECX, ECX
_PSPRT_INS_SL:
        CMP   BYTE PTR [ESI+ECX], 0
        JE   _PSPRT_INS_S2
        INC   ECX
        JMP   _PSPRT_INS_SL
_PSPRT_INS_S2:
        XOR   EDX, EDX
_PSPRT_INS_DL:
        CMP   BYTE PTR [EDI+EDX], 0
        JE   _PSPRT_INS_D2
        INC   EDX
        JMP   _PSPRT_INS_DL
_PSPRT_INS_D2:
        DEC   EBX
        LEA   ESI, [EDI+EDX]
        LEA   EDI, [ESI+ECX]
        MOV   EAX, EDX
        SUB   EAX, EBX
        INC   EAX
_PSPRT_INS_MV:
        CMP   EAX, 0
        JLE   _PSPRT_INS_CP
        MOV   CL, BYTE PTR [ESI]
        MOV   BYTE PTR [EDI], CL
        DEC   ESI
        DEC   EDI
        DEC   EAX
        JMP   _PSPRT_INS_MV
_PSPRT_INS_CP:
        POP   EDI
        POP   ESI
        ADD   EDI, EBX
_PSPRT_INS_C2:
        MOV   AL, BYTE PTR [ESI]
        CMP   AL, 0
        JE   _PSPRT_INS_DN
        MOV   BYTE PTR [EDI], AL
        INC   ESI
        INC   EDI
        JMP   _PSPRT_INS_C2
_PSPRT_INS_DN:
        MOV   ESP, EBP
        POP   EBP
        RET

_PSPRT_SQRT:
        CMP   EAX, 1
        JBE   _PSPRT_SQ_DN
        PUSH   EBX
        PUSH   ECX
        PUSH   EDX
        MOV   ECX, EAX
        MOV   EBX, EAX
_PSPRT_SQ_LP:
        MOV   EAX, ECX
        XOR   EDX, EDX
        DIV   EBX
        ADD   EAX, EBX
        SHR   EAX, 1
        CMP   EAX, EBX
        JAE   _PSPRT_SQ_OK
        MOV   EBX, EAX
        JMP   _PSPRT_SQ_LP
_PSPRT_SQ_OK:
        MOV   EAX, EBX
        POP   EDX
        POP   ECX
        POP   EBX
_PSPRT_SQ_DN:
        RET

_PSPRT_RANDOM:
        MOV   EAX, DWORD PTR [_PSPRT_SEED]
        IMUL   EAX, 1103515245
        ADD   EAX, 12345
        MOV   DWORD PTR [_PSPRT_SEED], EAX
        AND   EAX, 7FFFFFFFh
        RET

_PSPRT_RANDOMIZE:
        CALL   _GetTickCount@0
        MOV   DWORD PTR [_PSPRT_SEED], EAX
        RET

_PSPRT_PANIC:
        CALL   _PSPRT_PRINTSTR
        LEA   ESI, _PSPRT_CRLF
        CALL   _PSPRT_PRINTSTR
        PUSH   1
        CALL   _ExitProcess@4

_PSPRT_PANIC_DIV0:
        LEA   ESI, _PSPRT_DIV0MSG
        CMP   DWORD PTR [_PSPX_HANDLER], 0
        JE   _PSPRT_PANIC_DIV0_FATAL
        MOV   ESP, DWORD PTR [_PSPX_SAVESP]
        MOV   EBP, DWORD PTR [_PSPX_SAVEBP]
        JMP   DWORD PTR [_PSPX_HANDLER]
_PSPRT_PANIC_DIV0_FATAL:
        CALL   _PSPRT_PANIC

; --- Fin du segment de code ---
_TEXT   ENDS

_DATA   SEGMENT DWORD PUBLIC 'DATA'
; --- Buffers internes ---
_PSPRT_CRLF    DB  13,10,0
_PSPRT_STRBUF  DB  512 DUP(0)
_PSPRT_CHRBUF  DB  2 DUP(0)
_PSPRT_NUMBUF  DB  12 DUP(0)
_PSPRT_TRUE_S  DB  'TRUE',0
_PSPRT_FALSE_S DB  'FALSE',0
_PSPRT_HEAP    DB  4096 DUP(0)
_PSPRT_HEAPTOP DD  OFFSET _PSPRT_HEAP
_PSPRT_SEED    DD  1
_PSPX_HANDLER DD  0
_PSPX_SAVESP  DD  0
_PSPX_SAVEBP  DD  0
_PSPRT_DIV0MSG DB  'Runtime error: Division by zero',0
_PSPRT_PANICMSG DB 0
_PSPRT_HSTDOUT DD  0
_PSPRT_WRITTEN DD  0

; --- Donnees du programme ---
_PSPK_HTML_1  DB  '<html>
  <head>
    <title>Pascal Server Pages - test_case</title>
  </head>
  <body>
',0
_PSP_MSG1  DD  0
_PSP_MSG2  DD  0
_PSPK_2  DB  'Hello',0
_PSPK_3  DB  'World',0
_PSPK_4  DB  'Test des chaînes de caractères:',0
_PSPK_5  DB  '<br />',0
_PSPK_6  DB  'msg1 = ',0
_PSPK_7  DB  '<br />',0
_PSPK_8  DB  'msg2 = ',0
_PSPK_9  DB  '<br />',0
_PSPK_10  DB  'Concaténation: ',0
_PSPK_11  DB  '<br />',0
_PSPK_12  DB  'Chaîne littérale: ''Bonjour Pascal!''',0
_PSPK_HTML_13  DB  '
  </body>
</html>
',0
_DATA   ENDS
        END     _PSPF_main
