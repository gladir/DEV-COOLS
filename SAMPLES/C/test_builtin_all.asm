; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/test_builtin_all.c

.386
.MODEL FLAT, STDCALL

; --- Imports Win32 (kernel32.dll) ---
EXTRN _ExitProcess@4:NEAR
EXTRN _GetStdHandle@4:NEAR
EXTRN _WriteFile@20:NEAR
EXTRN _ReadFile@20:NEAR
EXTRN _GetProcessHeap@0:NEAR
EXTRN _HeapAlloc@12:NEAR
EXTRN _HeapFree@12:NEAR

; --- Segment de donnees ---
.DATA

HSTDOUT  DD 0
HSTDIN   DD 0
HHEAP    DD 0
NUMBUF   DB 16 DUP(0)
INBUF    DB 256 DUP(0)
BYTESWR  DD 0
BYTESRD  DD 0
CRLF     DB 13,10,0

_CCK_1  DB '=== Test 136 fonctions C standard built-in ===',10,0
_CCK_2  DB 'Toutes les fonctions sont acceptees par le compilateur.',10,0
_CCK_3  DB 'builtin_all: OK',10,0

; --- Segment de code ---
.CODE


; === Runtime I/O (TODO 21) ===

; --- _CCRT_PRINTSTR : afficher chaine ASCIIZ (ESI) ---
_CCRT_PRINTSTR:
        PUSHAD
        MOV EDI,ESI
        XOR ECX,ECX
_CCRT_PS_LEN:
        CMP BYTE PTR [EDI],0
        JE _CCRT_PS_GO
        INC EDI
        INC ECX
        JMP _CCRT_PS_LEN
_CCRT_PS_GO:
        CMP ECX,0
        JE _CCRT_PS_END
        PUSH 0
        PUSH OFFSET BYTESWR
        PUSH ECX
        PUSH ESI
        PUSH [HSTDOUT]
        CALL _WriteFile@20
_CCRT_PS_END:
        POPAD
        RET

; --- _CCRT_PRINTINT : afficher entier signe (EAX) ---
_CCRT_PRINTINT:
        PUSHAD
        MOV ESI,EAX
        LEA EDI,[NUMBUF+15]
        MOV BYTE PTR [EDI],0
        XOR ECX,ECX
        MOV EBX,10
        TEST ESI,ESI
        JNS _CCRT_PI_POS
        NEG ESI
_CCRT_PI_POS:
        MOV EAX,ESI
_CCRT_PI_LOOP:
        XOR EDX,EDX
        DIV EBX
        ADD DL,48
        DEC EDI
        MOV [EDI],DL
        INC ECX
        TEST EAX,EAX
        JNZ _CCRT_PI_LOOP
        MOV EAX,[ESP+28]
        TEST EAX,EAX
        JNS _CCRT_PI_PRINT
        DEC EDI
        MOV BYTE PTR [EDI],45
        INC ECX
_CCRT_PI_PRINT:
        PUSH 0
        PUSH OFFSET BYTESWR
        PUSH ECX
        PUSH EDI
        PUSH [HSTDOUT]
        CALL _WriteFile@20
        POPAD
        RET

; --- _CCRT_PRINTUINT : afficher entier non signe (EAX) ---
_CCRT_PRINTUINT:
        PUSHAD
        LEA EDI,[NUMBUF+15]
        MOV BYTE PTR [EDI],0
        XOR ECX,ECX
        MOV EBX,10
_CCRT_PU_LOOP:
        XOR EDX,EDX
        DIV EBX
        ADD DL,48
        DEC EDI
        MOV [EDI],DL
        INC ECX
        TEST EAX,EAX
        JNZ _CCRT_PU_LOOP
        PUSH 0
        PUSH OFFSET BYTESWR
        PUSH ECX
        PUSH EDI
        PUSH [HSTDOUT]
        CALL _WriteFile@20
        POPAD
        RET

; --- _CCRT_PRINTHEX : afficher entier en hexa (EAX) ---
_CCRT_PRINTHEX:
        PUSHAD
        LEA EDI,[NUMBUF+15]
        MOV BYTE PTR [EDI],0
        XOR ECX,ECX
        MOV EBX,16
_CCRT_PH_LOOP:
        XOR EDX,EDX
        DIV EBX
        CMP DL,10
        JB _CCRT_PH_DIG
        ADD DL,87
        JMP _CCRT_PH_STORE
_CCRT_PH_DIG:
        ADD DL,48
_CCRT_PH_STORE:
        DEC EDI
        MOV [EDI],DL
        INC ECX
        TEST EAX,EAX
        JNZ _CCRT_PH_LOOP
        PUSH 0
        PUSH OFFSET BYTESWR
        PUSH ECX
        PUSH EDI
        PUSH [HSTDOUT]
        CALL _WriteFile@20
        POPAD
        RET

; --- _CCRT_PRINTCHAR : afficher un caractere (AL) ---
_CCRT_PRINTCHAR:
        PUSHAD
        MOV [NUMBUF],AL
        PUSH 0
        PUSH OFFSET BYTESWR
        PUSH 1
        PUSH OFFSET NUMBUF
        PUSH [HSTDOUT]
        CALL _WriteFile@20
        POPAD
        RET

; --- _CCRT_PRINTCRLF : afficher retour a la ligne ---
_CCRT_PRINTCRLF:
        PUSHAD
        PUSH 0
        PUSH OFFSET BYTESWR
        PUSH 2
        PUSH OFFSET CRLF
        PUSH [HSTDOUT]
        CALL _WriteFile@20
        POPAD
        RET

; --- _CCRT_READINT : lire entier depuis stdin -> EAX ---
_CCRT_READINT:
        PUSH EBX
        PUSH ECX
        PUSH EDX
        PUSH ESI
        PUSH EDI
        PUSH 0
        PUSH OFFSET BYTESRD
        PUSH 255
        PUSH OFFSET INBUF
        PUSH [HSTDIN]
        CALL _ReadFile@20
        LEA ESI,[INBUF]
        XOR EAX,EAX
        XOR ECX,ECX
        XOR EDX,EDX
_CCRT_RI_SKIP:
        MOV CL,[ESI]
        CMP CL,32
        JE _CCRT_RI_SKIPN
        CMP CL,9
        JNE _CCRT_RI_SIGN
_CCRT_RI_SKIPN:
        INC ESI
        JMP _CCRT_RI_SKIP
_CCRT_RI_SIGN:
        CMP CL,45
        JNE _CCRT_RI_PLUS
        MOV EDX,1
        INC ESI
        JMP _CCRT_RI_DLOOP
_CCRT_RI_PLUS:
        CMP CL,43
        JNE _CCRT_RI_DLOOP
        INC ESI
_CCRT_RI_DLOOP:
        MOVZX ECX,BYTE PTR [ESI]
        CMP ECX,48
        JB _CCRT_RI_DONE
        CMP ECX,57
        JA _CCRT_RI_DONE
        SUB ECX,48
        IMUL EAX,10
        ADD EAX,ECX
        INC ESI
        JMP _CCRT_RI_DLOOP
_CCRT_RI_DONE:
        TEST EDX,EDX
        JZ _CCRT_RI_RET
        NEG EAX
_CCRT_RI_RET:
        POP EDI
        POP ESI
        POP EDX
        POP ECX
        POP EBX
        RET

; --- _CCRT_READSTR : lire chaine depuis stdin (EDI=buf) ---
_CCRT_READSTR:
        PUSHAD
        PUSH 0
        PUSH OFFSET BYTESRD
        PUSH 255
        PUSH OFFSET INBUF
        PUSH [HSTDIN]
        CALL _ReadFile@20
        LEA ESI,[INBUF]
        MOV EDI,[ESP+4]
_CCRT_RS_COPY:
        LODSB
        CMP AL,13
        JE _CCRT_RS_END
        CMP AL,10
        JE _CCRT_RS_END
        CMP AL,0
        JE _CCRT_RS_END
        STOSB
        JMP _CCRT_RS_COPY
_CCRT_RS_END:
        MOV BYTE PTR [EDI],0
        POPAD
        RET

; --- _CCRT_READCHAR : lire un caractere -> EAX ---
_CCRT_READCHAR:
        PUSH EBX
        PUSH ECX
        PUSH EDX
        MOV BYTE PTR [NUMBUF],0
        PUSH 0
        PUSH OFFSET BYTESRD
        PUSH 1
        PUSH OFFSET NUMBUF
        PUSH [HSTDIN]
        CALL _ReadFile@20
        MOVZX EAX,BYTE PTR [NUMBUF]
        POP EDX
        POP ECX
        POP EBX
        RET

; === Runtime supplementaire (TODO 24) ===

; --- _CCRT_NUMTOSTR : entier (EAX) -> ASCII (EDI=buf) ---
_CCRT_NUMTOSTR:
        PUSH EBX
        PUSH ECX
        PUSH EDX
        PUSH ESI
        PUSH EDI
        MOV ESI,EDI
        MOV ECX,EAX
        TEST EAX,EAX
        JNS _CCRT_NT_POS
        MOV BYTE PTR [EDI],45
        INC EDI
        NEG EAX
_CCRT_NT_POS:
        XOR ECX,ECX
        MOV EBX,10
_CCRT_NT_PUSH:
        XOR EDX,EDX
        DIV EBX
        ADD DL,48
        PUSH EDX
        INC ECX
        TEST EAX,EAX
        JNZ _CCRT_NT_PUSH
_CCRT_NT_POP:
        POP EAX
        MOV [EDI],AL
        INC EDI
        DEC ECX
        JNZ _CCRT_NT_POP
        MOV BYTE PTR [EDI],0
        POP EDI
        POP ESI
        POP EDX
        POP ECX
        POP EBX
        RET

; --- _CCRT_STRTONUM : ASCII (ESI) -> entier (EAX) ---
_CCRT_STRTONUM:
        PUSH EBX
        PUSH ECX
        PUSH EDX
        PUSH ESI
        XOR EAX,EAX
        XOR EDX,EDX
_CCRT_SN_SKIP:
        MOV CL,[ESI]
        CMP CL,32
        JE _CCRT_SN_SKIPN
        CMP CL,9
        JNE _CCRT_SN_SIGN
_CCRT_SN_SKIPN:
        INC ESI
        JMP _CCRT_SN_SKIP
_CCRT_SN_SIGN:
        CMP CL,45
        JNE _CCRT_SN_PLUS
        MOV EDX,1
        INC ESI
        JMP _CCRT_SN_LOOP
_CCRT_SN_PLUS:
        CMP CL,43
        JNE _CCRT_SN_LOOP
        INC ESI
_CCRT_SN_LOOP:
        MOVZX ECX,BYTE PTR [ESI]
        CMP ECX,48
        JB _CCRT_SN_DONE
        CMP ECX,57
        JA _CCRT_SN_DONE
        SUB ECX,48
        IMUL EAX,10
        ADD EAX,ECX
        INC ESI
        JMP _CCRT_SN_LOOP
_CCRT_SN_DONE:
        TEST EDX,EDX
        JZ _CCRT_SN_RET
        NEG EAX
_CCRT_SN_RET:
        POP ESI
        POP EDX
        POP ECX
        POP EBX
        RET

; --- _CCRT_STRLEN : longueur ASCIIZ (ESI) -> EAX ---
_CCRT_STRLEN:
        PUSH EDI
        MOV EDI,ESI
        XOR EAX,EAX
_CCRT_SL_LOOP:
        CMP BYTE PTR [EDI],0
        JE _CCRT_SL_DONE
        INC EDI
        INC EAX
        JMP _CCRT_SL_LOOP
_CCRT_SL_DONE:
        POP EDI
        RET

; --- _CCRT_STRCMP : comparer (ESI) et (EDI) -> drapeaux ---
_CCRT_STRCMP:
        PUSH ESI
        PUSH EDI
_CCRT_SC_LOOP:
        MOV AL,[ESI]
        MOV AH,[EDI]
        CMP AL,AH
        JNE _CCRT_SC_DONE
        TEST AL,AL
        JZ _CCRT_SC_DONE
        INC ESI
        INC EDI
        JMP _CCRT_SC_LOOP
_CCRT_SC_DONE:
        POP EDI
        POP ESI
        RET

; --- _CCRT_STRCPY : copier (ESI) -> (EDI) ---
_CCRT_STRCPY:
        PUSH ESI
        PUSH EDI
_CCRT_SCP_LOOP:
        LODSB
        STOSB
        TEST AL,AL
        JNZ _CCRT_SCP_LOOP
        POP EDI
        POP ESI
        RET

; --- _CCRT_STRCAT : concatener (ESI)+(EDI) -> EAX=INBUF ---
_CCRT_STRCAT:
        PUSHAD
        LEA EDI,[INBUF]
        MOV EBX,[ESP+4]
_CCRT_CAT_CP1:
        LODSB
        TEST AL,AL
        JZ _CCRT_CAT_S2
        STOSB
        JMP _CCRT_CAT_CP1
_CCRT_CAT_S2:
        MOV ESI,EBX
_CCRT_CAT_CP2:
        LODSB
        STOSB
        TEST AL,AL
        JNZ _CCRT_CAT_CP2
        POPAD
        LEA EAX,[INBUF]
        RET

; --- _CCRT_READLN : consommer jusqu a CR+LF ---
_CCRT_READLN:
        PUSHAD
_CCRT_RL_LOOP:
        PUSH 0
        PUSH OFFSET BYTESRD
        PUSH 1
        PUSH OFFSET NUMBUF
        PUSH [HSTDIN]
        CALL _ReadFile@20
        CMP DWORD PTR [BYTESRD],0
        JE _CCRT_RL_END
        CMP BYTE PTR [NUMBUF],10
        JE _CCRT_RL_END
        JMP _CCRT_RL_LOOP
_CCRT_RL_END:
        POPAD
        RET

; --- _CCRT_MALLOC : allouer EAX octets -> EAX=ptr ---
_CCRT_MALLOC:
        PUSH EAX
        PUSH 8
        PUSH [HHEAP]
        CALL _HeapAlloc@12
        RET

; --- _CCRT_FREE : liberer (EAX) ---
_CCRT_FREE:
        PUSH EAX
        PUSH 0
        PUSH [HHEAP]
        CALL _HeapFree@12
        RET

; --- _CCRT_MEMCPY : copier ECX octets (ESI)->(EDI) ---
_CCRT_MEMCPY:
        PUSH ESI
        PUSH EDI
        PUSH ECX
        REP MOVSB
        POP ECX
        POP EDI
        POP ESI
        RET

; --- _CCRT_MEMSET : remplir ECX octets (EDI) avec AL ---
_CCRT_MEMSET:
        PUSH EDI
        PUSH ECX
        REP STOSB
        POP ECX
        POP EDI
        RET

; --- _CCRT_PANIC : afficher ESI + ExitProcess(1) ---
_CCRT_PANIC:
        CALL _CCRT_PRINTSTR
        CALL _CCRT_PRINTCRLF
        PUSH 1
        CALL _ExitProcess@4

; === Fin Runtime (TODO 24) ===

; --- Fonction: test_stdio_decl ---
_CCF_test_stdio_decl:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   local fp = [EBP-4]
        MOV EAX,DWORD PTR [_clearerr]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_fclose]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_feof]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_ferror]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_fflush]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_fgetc]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_fgetpos]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_fgets]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_fopen]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_fprintf]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_fputc]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_fputs]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_fread]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_freopen]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_fscanf]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_fseek]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_fsetpos]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_ftell]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_fwrite]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_getc]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_getchar]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_gets]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_perror]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_printf]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_putc]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_putchar]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_puts]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_remove]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_rename]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_rewind]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_scanf]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_setbuf]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_setvbuf]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_sprintf]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_sscanf]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_tmpfile]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_tmpnam]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_ungetc]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_vfprintf]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_vprintf]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_vsprintf]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
_CCL_1:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_stdlib_decl ---
_CCF_test_stdlib_decl:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   local fp = [EBP-4]
        MOV EAX,DWORD PTR [_abort]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_abs]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_atexit]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_atof]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_atoi]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_atol]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_bsearch]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_calloc]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_div]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_exit]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_free]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_getenv]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_labs]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_ldiv]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_malloc]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_qsort]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_rand]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_realloc]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_srand]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_strtod]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_strtol]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_strtoul]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_system]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
_CCL_2:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_string_decl ---
_CCF_test_string_decl:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   local fp = [EBP-4]
        MOV EAX,DWORD PTR [_memchr]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_memcmp]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_memcpy]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_memmove]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_memset]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_strcat]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_strchr]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_strcmp]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_strcpy]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_strcspn]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_strerror]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_strlen]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_strncat]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_strncmp]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_strncpy]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_strpbrk]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_strrchr]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_strspn]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_strstr]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_strtok]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
_CCL_3:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_math_decl ---
_CCF_test_math_decl:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   local fp = [EBP-4]
        MOV EAX,DWORD PTR [_acos]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_asin]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_atan]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_atan2]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_ceil]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_cos]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_cosh]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_exp]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_fabs]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_floor]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_fmod]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_frexp]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_ldexp]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_log]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_log10]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_modf]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_pow]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_sin]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_sinh]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_sqrt]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_tan]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_tanh]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
_CCL_4:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_time_decl ---
_CCF_test_time_decl:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   local fp = [EBP-4]
        MOV EAX,DWORD PTR [_asctime]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_clock]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_ctime]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_difftime]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_gmtime]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_localtime]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_mktime]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_strftime]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_time]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
_CCL_5:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_ctype_decl ---
_CCF_test_ctype_decl:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   local fp = [EBP-4]
        MOV EAX,DWORD PTR [_isalnum]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_isalpha]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_iscntrl]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_isdigit]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_isgraph]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_islower]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_isprint]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_ispunct]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_isspace]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_isupper]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_isxdigit]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_tolower]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_toupper]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
_CCL_6:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_signal_decl ---
_CCF_test_signal_decl:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   local fp = [EBP-4]
        MOV EAX,DWORD PTR [_raise]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_signal]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
_CCL_7:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_setjmp_decl ---
_CCF_test_setjmp_decl:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   local fp = [EBP-4]
        MOV EAX,DWORD PTR [_longjmp]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_setjmp]
; cast vers pointeur (no-op)
        MOV DWORD PTR [EBP-4],EAX
_CCL_8:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: main ---
_CCF_main:
        PUSH EBP
        MOV EBP,ESP
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_4
        CALL _CCRT_PRINTSTR
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_5
        CALL _CCRT_PRINTSTR
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_6
        CALL _CCRT_PRINTSTR
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
        MOV EAX,0
        JMP _CCL_9
_CCL_9:
        MOV ESP,EBP
        POP EBP
        RET

; --- Point d'entree Win32 ---
_main:
        PUSH -11
        CALL _GetStdHandle@4
        MOV DWORD PTR [HSTDOUT],EAX
        PUSH -10
        CALL _GetStdHandle@4
        MOV DWORD PTR [HSTDIN],EAX
        CALL _GetProcessHeap@0
        MOV DWORD PTR [HHEAP],EAX
        CALL _CCF_main
        PUSH 0
        CALL _ExitProcess@4


; --- Donnees supplementaires (TODO 21) ---
.DATA

_CCK_4  DB '=== Test 136 fonctions C standard built-in ===',0
_CCK_5  DB 'Toutes les fonctions sont acceptees par le compilateur.',0
_CCK_6  DB 'builtin_all: OK',0

.CODE

END _main
