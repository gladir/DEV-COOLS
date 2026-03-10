; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/ternary_operator_test.c

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

_CCK_1  DB 'max(10, 5) = %d (devrait ',195,170,'tre 10)',10,0
_CCK_2  DB 'condition fausse: %d (devrait ',195,170,'tre 5)',10,0
_CCK_3  DB '1 ? 100 : 200 = %d (devrait ',195,170,'tre 100)',10,0
_CCK_4  DB '0 ? 100 : 200 = %d (devrait ',195,170,'tre 200)',10,0
_CCK_5  DB '(8 > 5) ? (3 + 2) : (3 - 2) = %d (devrait ',195,170,'tre 5)',10,0
_CCK_6  DB '(8 < 5) ? (3 + 2) : (3 - 2) = %d (devrait ',195,170,'tre 1)',10,0
_CCK_7  DB 'Ternaire imbriqu',195,169,': %d (devrait ',195,170,'tre 2)',10,0
_CCK_8  DB '0 ? 42 : 99 = %d (devrait ',195,170,'tre 99)',10,0
_CCK_9  DB '1 ? 42 : 99 = %d (devrait ',195,170,'tre 42)',10,0
_CCK_10  DB '!7 ? 0 : 7 = %d (devrait ',195,170,'tre 7)',10,0

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
        SUB ESP,16
;   local a = [EBP-4]
;   local b = [EBP-8]
;   local c = [EBP-12]
;   local result = [EBP-16]
        MOV EAX,10
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,5
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _CCL_2
        XOR EAX,EAX
        JMP _CCL_3
_CCL_2:
        MOV EAX,1
_CCL_3:
        TEST EAX,EAX
        JZ _CCL_4
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_5
_CCL_4:
        MOV EAX,DWORD PTR [EBP-8]
_CCL_5:
        MOV DWORD PTR [EBP-16],EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_11
        CALL _CCRT_PRINTSTR
        MOV EAX,DWORD PTR [EBP-16]
        CALL _CCRT_PRINTINT
        MOV ESI,OFFSET _CCK_12
        CALL _CCRT_PRINTSTR
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_6
        XOR EAX,EAX
        JMP _CCL_7
_CCL_6:
        MOV EAX,1
_CCL_7:
        TEST EAX,EAX
        JZ _CCL_8
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_9
_CCL_8:
        MOV EAX,DWORD PTR [EBP-8]
_CCL_9:
        MOV DWORD PTR [EBP-16],EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_13
        CALL _CCRT_PRINTSTR
        MOV EAX,DWORD PTR [EBP-16]
        CALL _CCRT_PRINTINT
        MOV ESI,OFFSET _CCK_14
        CALL _CCRT_PRINTSTR
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
        MOV EAX,1
        TEST EAX,EAX
        JZ _CCL_10
        MOV EAX,100
        JMP _CCL_11
_CCL_10:
        MOV EAX,200
_CCL_11:
        MOV DWORD PTR [EBP-16],EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_15
        CALL _CCRT_PRINTSTR
        MOV EAX,DWORD PTR [EBP-16]
        CALL _CCRT_PRINTINT
        MOV ESI,OFFSET _CCK_16
        CALL _CCRT_PRINTSTR
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
        MOV EAX,0
        TEST EAX,EAX
        JZ _CCL_12
        MOV EAX,100
        JMP _CCL_13
_CCL_12:
        MOV EAX,200
_CCL_13:
        MOV DWORD PTR [EBP-16],EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_17
        CALL _CCRT_PRINTSTR
        MOV EAX,DWORD PTR [EBP-16]
        CALL _CCRT_PRINTINT
        MOV ESI,OFFSET _CCK_18
        CALL _CCRT_PRINTSTR
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
        MOV EAX,8
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,3
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,2
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,5
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _CCL_14
        XOR EAX,EAX
        JMP _CCL_15
_CCL_14:
        MOV EAX,1
_CCL_15:
        TEST EAX,EAX
        JZ _CCL_16
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-12]
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        JMP _CCL_17
_CCL_16:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-12]
        MOV EBX,EAX
        POP EAX
        SUB EAX,EBX
_CCL_17:
        MOV DWORD PTR [EBP-16],EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_19
        CALL _CCRT_PRINTSTR
        MOV EAX,DWORD PTR [EBP-16]
        CALL _CCRT_PRINTINT
        MOV ESI,OFFSET _CCK_14
        CALL _CCRT_PRINTSTR
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,5
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_18
        XOR EAX,EAX
        JMP _CCL_19
_CCL_18:
        MOV EAX,1
_CCL_19:
        TEST EAX,EAX
        JZ _CCL_20
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-12]
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        JMP _CCL_21
_CCL_20:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-12]
        MOV EBX,EAX
        POP EAX
        SUB EAX,EBX
_CCL_21:
        MOV DWORD PTR [EBP-16],EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_20
        CALL _CCRT_PRINTSTR
        MOV EAX,DWORD PTR [EBP-16]
        CALL _CCRT_PRINTINT
        MOV ESI,OFFSET _CCK_21
        CALL _CCRT_PRINTSTR
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
        MOV EAX,15
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,20
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _CCL_22
        XOR EAX,EAX
        JMP _CCL_23
_CCL_22:
        MOV EAX,1
_CCL_23:
        TEST EAX,EAX
        JZ _CCL_24
        MOV EAX,1
        JMP _CCL_25
_CCL_24:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,10
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _CCL_26
        XOR EAX,EAX
        JMP _CCL_27
_CCL_26:
        MOV EAX,1
_CCL_27:
        TEST EAX,EAX
        JZ _CCL_28
        MOV EAX,2
        JMP _CCL_29
_CCL_28:
        MOV EAX,3
_CCL_29:
_CCL_25:
        MOV DWORD PTR [EBP-16],EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_22
        CALL _CCRT_PRINTSTR
        MOV EAX,DWORD PTR [EBP-16]
        CALL _CCRT_PRINTINT
        MOV ESI,OFFSET _CCK_23
        CALL _CCRT_PRINTSTR
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,42
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,99
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        TEST EAX,EAX
        JZ _CCL_30
        MOV EAX,DWORD PTR [EBP-8]
        JMP _CCL_31
_CCL_30:
        MOV EAX,DWORD PTR [EBP-12]
_CCL_31:
        MOV DWORD PTR [EBP-16],EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_24
        CALL _CCRT_PRINTSTR
        MOV EAX,DWORD PTR [EBP-16]
        CALL _CCRT_PRINTINT
        MOV ESI,OFFSET _CCK_25
        CALL _CCRT_PRINTSTR
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
        MOV EAX,1
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        TEST EAX,EAX
        JZ _CCL_32
        MOV EAX,DWORD PTR [EBP-8]
        JMP _CCL_33
_CCL_32:
        MOV EAX,DWORD PTR [EBP-12]
_CCL_33:
        MOV DWORD PTR [EBP-16],EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_26
        CALL _CCRT_PRINTSTR
        MOV EAX,DWORD PTR [EBP-16]
        CALL _CCRT_PRINTINT
        MOV ESI,OFFSET _CCK_27
        CALL _CCRT_PRINTSTR
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
        MOV EAX,7
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        TEST EAX,EAX
        SETZ AL
        MOVZX EAX,AL
        TEST EAX,EAX
        JZ _CCL_34
        MOV EAX,0
        JMP _CCL_35
_CCL_34:
        MOV EAX,DWORD PTR [EBP-4]
_CCL_35:
        MOV DWORD PTR [EBP-16],EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_28
        CALL _CCRT_PRINTSTR
        MOV EAX,DWORD PTR [EBP-16]
        CALL _CCRT_PRINTINT
        MOV ESI,OFFSET _CCK_29
        CALL _CCRT_PRINTSTR
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

_CCK_11  DB 'max(10, 5) = ',0
_CCK_12  DB ' (devrait ',195,170,'tre 10)',0
_CCK_13  DB 'condition fausse: ',0
_CCK_14  DB ' (devrait ',195,170,'tre 5)',0
_CCK_15  DB '1 ? 100 : 200 = ',0
_CCK_16  DB ' (devrait ',195,170,'tre 100)',0
_CCK_17  DB '0 ? 100 : 200 = ',0
_CCK_18  DB ' (devrait ',195,170,'tre 200)',0
_CCK_19  DB '(8 > 5) ? (3 + 2) : (3 - 2) = ',0
_CCK_20  DB '(8 < 5) ? (3 + 2) : (3 - 2) = ',0
_CCK_21  DB ' (devrait ',195,170,'tre 1)',0
_CCK_22  DB 'Ternaire imbriqu',195,169,': ',0
_CCK_23  DB ' (devrait ',195,170,'tre 2)',0
_CCK_24  DB '0 ? 42 : 99 = ',0
_CCK_25  DB ' (devrait ',195,170,'tre 99)',0
_CCK_26  DB '1 ? 42 : 99 = ',0
_CCK_27  DB ' (devrait ',195,170,'tre 42)',0
_CCK_28  DB '!7 ? 0 : 7 = ',0
_CCK_29  DB ' (devrait ',195,170,'tre 7)',0

.CODE

END _main
