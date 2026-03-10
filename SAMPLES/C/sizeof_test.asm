; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/sizeof_test.c

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

_CCK_1  DB 'sizeof(int) = %d',10,0
_CCK_2  DB 'sizeof(char) = %d',10,0
_CCK_3  DB 'sizeof(int*) = %d',10,0
_CCK_4  DB 'sizeof(a) = %d',10,0
_CCK_5  DB 'sizeof(c) = %d',10,0
_CCK_6  DB 'sizeof(arr) = %d',10,0
_CCK_7  DB 'sizeof(ptr) = %d',10,0
_CCK_8  DB 'sizeof(a + c) = %d',10,0
_CCK_9  DB 'sizeof(*ptr) = %d',10,0

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

; === Fin Runtime I/O ===

; --- Fonction: main ---
_CCF_main:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,56
;   local a = [EBP-4]
;   local c = [EBP-8]
;   local arr = [EBP-48]
;   local ptr = [EBP-52]
;   local result = [EBP-56]
        MOV EAX,4
        MOV DWORD PTR [EBP-56],EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_10
        CALL _CCRT_PRINTSTR
        MOV EAX,DWORD PTR [EBP-56]
        CALL _CCRT_PRINTINT
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
        MOV EAX,1
        MOV DWORD PTR [EBP-56],EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_11
        CALL _CCRT_PRINTSTR
        MOV EAX,DWORD PTR [EBP-56]
        CALL _CCRT_PRINTINT
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
        MOV EAX,4
        MOV DWORD PTR [EBP-56],EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_12
        CALL _CCRT_PRINTSTR
        MOV EAX,DWORD PTR [EBP-56]
        CALL _CCRT_PRINTINT
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
        MOV EAX,DWORD PTR [EBP-4]
        MOV EAX,4
        MOV DWORD PTR [EBP-56],EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_13
        CALL _CCRT_PRINTSTR
        MOV EAX,DWORD PTR [EBP-56]
        CALL _CCRT_PRINTINT
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EAX,4
        MOV DWORD PTR [EBP-56],EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_14
        CALL _CCRT_PRINTSTR
        MOV EAX,DWORD PTR [EBP-56]
        CALL _CCRT_PRINTINT
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
        LEA EAX,[EBP-48]
        MOV EAX,4
        MOV DWORD PTR [EBP-56],EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_15
        CALL _CCRT_PRINTSTR
        MOV EAX,DWORD PTR [EBP-56]
        CALL _CCRT_PRINTINT
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
        MOV EAX,DWORD PTR [EBP-52]
        MOV EAX,4
        MOV DWORD PTR [EBP-56],EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_16
        CALL _CCRT_PRINTSTR
        MOV EAX,DWORD PTR [EBP-56]
        CALL _CCRT_PRINTINT
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV EAX,4
        MOV DWORD PTR [EBP-56],EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_17
        CALL _CCRT_PRINTSTR
        MOV EAX,DWORD PTR [EBP-56]
        CALL _CCRT_PRINTINT
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
        MOV EAX,DWORD PTR [EBP-52]
        MOV EAX,DWORD PTR [EAX]
        MOV EAX,4
        MOV DWORD PTR [EBP-56],EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_18
        CALL _CCRT_PRINTSTR
        MOV EAX,DWORD PTR [EBP-56]
        CALL _CCRT_PRINTINT
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
        MOV EAX,0
        JMP _CCL_1
_CCL_1:
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

_CCK_10  DB 'sizeof(int) = ',0
_CCK_11  DB 'sizeof(char) = ',0
_CCK_12  DB 'sizeof(int*) = ',0
_CCK_13  DB 'sizeof(a) = ',0
_CCK_14  DB 'sizeof(c) = ',0
_CCK_15  DB 'sizeof(arr) = ',0
_CCK_16  DB 'sizeof(ptr) = ',0
_CCK_17  DB 'sizeof(a + c) = ',0
_CCK_18  DB 'sizeof(*ptr) = ',0

.CODE

END _main
