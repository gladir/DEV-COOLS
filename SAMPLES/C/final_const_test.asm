; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/final_const_test.c

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

; --- Fonction: test ---
_CCF_test:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   local x = [EBP-4]
        MOV DWORD PTR [EBP-4],5
        MOV EAX,5
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,10
        MOV DWORD PTR [EBP-4],EAX
_CCL_1:
        MOV ESP,EBP
        POP EBP
        RET

END
