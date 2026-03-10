; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/test_loop_control.c

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

; === Fin Runtime I/O ===

; --- Fonction: main ---
_CCF_main:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,8
;   local i = [EBP-4]
;   local j = [EBP-8]
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
_CCL_2:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,10
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_4
        XOR EAX,EAX
        JMP _CCL_5
_CCL_4:
        MOV EAX,1
_CCL_5:
        TEST EAX,EAX
        JZ _CCL_3
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,5
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_8
        XOR EAX,EAX
        JMP _CCL_9
_CCL_8:
        MOV EAX,1
_CCL_9:
        TEST EAX,EAX
        JZ _CCL_6
        JMP _CCL_3
_CCL_6:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_2
_CCL_3:
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
_CCL_10:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,10
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_12
        XOR EAX,EAX
        JMP _CCL_13
_CCL_12:
        MOV EAX,1
_CCL_13:
        TEST EAX,EAX
        JZ _CCL_11
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,3
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_16
        XOR EAX,EAX
        JMP _CCL_17
_CCL_16:
        MOV EAX,1
_CCL_17:
        TEST EAX,EAX
        JZ _CCL_14
        JMP _CCL_10
_CCL_14:
        JMP _CCL_10
_CCL_11:
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
_CCL_18:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,10
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_21
        XOR EAX,EAX
        JMP _CCL_22
_CCL_21:
        MOV EAX,1
_CCL_22:
        TEST EAX,EAX
        JZ _CCL_20
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,7
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_25
        XOR EAX,EAX
        JMP _CCL_26
_CCL_25:
        MOV EAX,1
_CCL_26:
        TEST EAX,EAX
        JZ _CCL_23
        JMP _CCL_20
_CCL_23:
_CCL_19:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_18
_CCL_20:
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
_CCL_27:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,10
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_30
        XOR EAX,EAX
        JMP _CCL_31
_CCL_30:
        MOV EAX,1
_CCL_31:
        TEST EAX,EAX
        JZ _CCL_29
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,4
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_34
        XOR EAX,EAX
        JMP _CCL_35
_CCL_34:
        MOV EAX,1
_CCL_35:
        TEST EAX,EAX
        JZ _CCL_32
        JMP _CCL_28
_CCL_32:
_CCL_28:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_27
_CCL_29:
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
_CCL_36:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,3
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_39
        XOR EAX,EAX
        JMP _CCL_40
_CCL_39:
        MOV EAX,1
_CCL_40:
        TEST EAX,EAX
        JZ _CCL_38
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
_CCL_41:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,3
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_44
        XOR EAX,EAX
        JMP _CCL_45
_CCL_44:
        MOV EAX,1
_CCL_45:
        TEST EAX,EAX
        JZ _CCL_43
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_48
        XOR EAX,EAX
        JMP _CCL_49
_CCL_48:
        MOV EAX,1
_CCL_49:
        TEST EAX,EAX
        JZ _CCL_46
        JMP _CCL_42
_CCL_46:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_52
        XOR EAX,EAX
        JMP _CCL_53
_CCL_52:
        MOV EAX,1
_CCL_53:
        TEST EAX,EAX
        JZ _CCL_54
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,2
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_56
        XOR EAX,EAX
        JMP _CCL_57
_CCL_56:
        MOV EAX,1
_CCL_57:
        TEST EAX,EAX
        JZ _CCL_54
        MOV EAX,1
        JMP _CCL_55
_CCL_54:
        XOR EAX,EAX
_CCL_55:
        TEST EAX,EAX
        JZ _CCL_50
        JMP _CCL_43
_CCL_50:
_CCL_42:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-8],EAX
        JMP _CCL_41
_CCL_43:
_CCL_37:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_36
_CCL_38:
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
_CCL_58:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,3
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_63
        XOR EAX,EAX
        JMP _CCL_64
_CCL_63:
        MOV EAX,1
_CCL_64:
        TEST EAX,EAX
        JZ _CCL_61
        JMP _CCL_60
_CCL_61:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
_CCL_59:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,10
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_65
        XOR EAX,EAX
        JMP _CCL_66
_CCL_65:
        MOV EAX,1
_CCL_66:
        TEST EAX,EAX
        JNZ _CCL_58
_CCL_60:
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
_CCL_67:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,2
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_72
        XOR EAX,EAX
        JMP _CCL_73
_CCL_72:
        MOV EAX,1
_CCL_73:
        TEST EAX,EAX
        JZ _CCL_70
        JMP _CCL_68
_CCL_70:
_CCL_68:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,5
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_74
        XOR EAX,EAX
        JMP _CCL_75
_CCL_74:
        MOV EAX,1
_CCL_75:
        TEST EAX,EAX
        JNZ _CCL_67
_CCL_69:
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

END _main
