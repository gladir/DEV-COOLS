; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/test_loops.c

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

; --- Fonction: test_while_simple ---
_CCF_test_while_simple:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,8
;   param n = [EBP+8]
;   local s = [EBP-4]
        MOV DWORD PTR [EBP-4],0
;   local i = [EBP-8]
        MOV DWORD PTR [EBP-8],1
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,1
        MOV DWORD PTR [EBP-8],EAX
_CCL_2:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+8]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JLE _CCL_4
        XOR EAX,EAX
        JMP _CCL_5
_CCL_4:
        MOV EAX,1
_CCL_5:
        TEST EAX,EAX
        JZ _CCL_3
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-8]
        INC EAX
        MOV DWORD PTR [EBP-8],EAX
        JMP _CCL_2
_CCL_3:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_1
_CCL_1:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_while_zero ---
_CCF_test_while_zero:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,8
;   local s = [EBP-4]
        MOV DWORD PTR [EBP-4],0
;   local i = [EBP-8]
        MOV DWORD PTR [EBP-8],0
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
_CCL_7:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,0
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _CCL_9
        XOR EAX,EAX
        JMP _CCL_10
_CCL_9:
        MOV EAX,1
_CCL_10:
        TEST EAX,EAX
        JZ _CCL_8
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-8]
        DEC EAX
        MOV DWORD PTR [EBP-8],EAX
        JMP _CCL_7
_CCL_8:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_6
_CCL_6:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_do_while ---
_CCF_test_do_while:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,8
;   param n = [EBP+8]
;   local s = [EBP-4]
        MOV DWORD PTR [EBP-4],0
;   local i = [EBP-8]
        MOV DWORD PTR [EBP-8],1
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,1
        MOV DWORD PTR [EBP-8],EAX
_CCL_12:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-8]
        INC EAX
        MOV DWORD PTR [EBP-8],EAX
_CCL_13:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+8]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JLE _CCL_15
        XOR EAX,EAX
        JMP _CCL_16
_CCL_15:
        MOV EAX,1
_CCL_16:
        TEST EAX,EAX
        JNZ _CCL_12
_CCL_14:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_11
_CCL_11:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_for_simple ---
_CCF_test_for_simple:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,8
;   param n = [EBP+8]
;   local s = [EBP-4]
        MOV DWORD PTR [EBP-4],0
;   local i = [EBP-8]
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,1
        MOV DWORD PTR [EBP-8],EAX
_CCL_18:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+8]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JLE _CCL_21
        XOR EAX,EAX
        JMP _CCL_22
_CCL_21:
        MOV EAX,1
_CCL_22:
        TEST EAX,EAX
        JZ _CCL_20
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
_CCL_19:
        MOV EAX,DWORD PTR [EBP-8]
        INC EAX
        MOV DWORD PTR [EBP-8],EAX
        JMP _CCL_18
_CCL_20:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_17
_CCL_17:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_for_decl ---
_CCF_test_for_decl:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,8
;   param n = [EBP+8]
;   local s = [EBP-4]
        MOV DWORD PTR [EBP-4],0
;   local i = [EBP-8]
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
_CCL_24:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+8]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_27
        XOR EAX,EAX
        JMP _CCL_28
_CCL_27:
        MOV EAX,1
_CCL_28:
        TEST EAX,EAX
        JZ _CCL_26
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
_CCL_25:
        MOV EAX,DWORD PTR [EBP-8]
        INC EAX
        MOV DWORD PTR [EBP-8],EAX
        JMP _CCL_24
_CCL_26:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_23
_CCL_23:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_for_compound_incr ---
_CCF_test_for_compound_incr:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,8
;   param n = [EBP+8]
;   local s = [EBP-4]
        MOV DWORD PTR [EBP-4],0
;   local i = [EBP-8]
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
_CCL_30:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+8]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_33
        XOR EAX,EAX
        JMP _CCL_34
_CCL_33:
        MOV EAX,1
_CCL_34:
        TEST EAX,EAX
        JZ _CCL_32
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
_CCL_31:
        MOV EAX,2
        MOV EBX,EAX
        MOV EAX,DWORD PTR [EBP-8]
        ADD EAX,EBX
        MOV DWORD PTR [EBP-8],EAX
        JMP _CCL_30
_CCL_32:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_29
_CCL_29:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_for_break ---
_CCF_test_for_break:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,8
;   param n = [EBP+8]
;   local s = [EBP-4]
        MOV DWORD PTR [EBP-4],0
;   local i = [EBP-8]
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
_CCL_36:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,100
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
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+8]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JGE _CCL_43
        XOR EAX,EAX
        JMP _CCL_44
_CCL_43:
        MOV EAX,1
_CCL_44:
        TEST EAX,EAX
        JZ _CCL_41
        JMP _CCL_38
_CCL_41:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
_CCL_37:
        MOV EAX,DWORD PTR [EBP-8]
        INC EAX
        MOV DWORD PTR [EBP-8],EAX
        JMP _CCL_36
_CCL_38:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_35
_CCL_35:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_while_break ---
_CCF_test_while_break:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,8
;   param n = [EBP+8]
;   local s = [EBP-4]
        MOV DWORD PTR [EBP-4],0
;   local i = [EBP-8]
        MOV DWORD PTR [EBP-8],0
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
_CCL_46:
        MOV EAX,1
        TEST EAX,EAX
        JZ _CCL_47
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+8]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JGE _CCL_50
        XOR EAX,EAX
        JMP _CCL_51
_CCL_50:
        MOV EAX,1
_CCL_51:
        TEST EAX,EAX
        JZ _CCL_48
        JMP _CCL_47
_CCL_48:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-8]
        INC EAX
        MOV DWORD PTR [EBP-8],EAX
        JMP _CCL_46
_CCL_47:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_45
_CCL_45:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_for_continue ---
_CCF_test_for_continue:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,8
;   param n = [EBP+8]
;   local s = [EBP-4]
        MOV DWORD PTR [EBP-4],0
;   local i = [EBP-8]
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
_CCL_53:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+8]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_56
        XOR EAX,EAX
        JMP _CCL_57
_CCL_56:
        MOV EAX,1
_CCL_57:
        TEST EAX,EAX
        JZ _CCL_55
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,3
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_60
        XOR EAX,EAX
        JMP _CCL_61
_CCL_60:
        MOV EAX,1
_CCL_61:
        TEST EAX,EAX
        JZ _CCL_58
        JMP _CCL_54
_CCL_58:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
_CCL_54:
        MOV EAX,DWORD PTR [EBP-8]
        INC EAX
        MOV DWORD PTR [EBP-8],EAX
        JMP _CCL_53
_CCL_55:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_52
_CCL_52:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_while_continue ---
_CCF_test_while_continue:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,8
;   local s = [EBP-4]
        MOV DWORD PTR [EBP-4],0
;   local i = [EBP-8]
        MOV DWORD PTR [EBP-8],0
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
_CCL_63:
        MOV EAX,DWORD PTR [EBP-8]
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
        JZ _CCL_64
        MOV EAX,DWORD PTR [EBP-8]
        INC EAX
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,5
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_69
        XOR EAX,EAX
        JMP _CCL_70
_CCL_69:
        MOV EAX,1
_CCL_70:
        TEST EAX,EAX
        JZ _CCL_67
        JMP _CCL_63
_CCL_67:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_63
_CCL_64:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_62
_CCL_62:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_nested_for ---
_CCF_test_nested_for:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,12
;   param n = [EBP+8]
;   local s = [EBP-4]
        MOV DWORD PTR [EBP-4],0
;   local i = [EBP-8]
;   local j = [EBP-12]
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
_CCL_72:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+8]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_75
        XOR EAX,EAX
        JMP _CCL_76
_CCL_75:
        MOV EAX,1
_CCL_76:
        TEST EAX,EAX
        JZ _CCL_74
        MOV EAX,0
        MOV DWORD PTR [EBP-12],EAX
_CCL_77:
        MOV EAX,DWORD PTR [EBP-12]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+8]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_80
        XOR EAX,EAX
        JMP _CCL_81
_CCL_80:
        MOV EAX,1
_CCL_81:
        TEST EAX,EAX
        JZ _CCL_79
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
_CCL_78:
        MOV EAX,DWORD PTR [EBP-12]
        INC EAX
        MOV DWORD PTR [EBP-12],EAX
        JMP _CCL_77
_CCL_79:
_CCL_73:
        MOV EAX,DWORD PTR [EBP-8]
        INC EAX
        MOV DWORD PTR [EBP-8],EAX
        JMP _CCL_72
_CCL_74:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_71
_CCL_71:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_nested_break ---
_CCF_test_nested_break:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,12
;   local s = [EBP-4]
        MOV DWORD PTR [EBP-4],0
;   local i = [EBP-8]
;   local j = [EBP-12]
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
_CCL_83:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,5
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_86
        XOR EAX,EAX
        JMP _CCL_87
_CCL_86:
        MOV EAX,1
_CCL_87:
        TEST EAX,EAX
        JZ _CCL_85
        MOV EAX,0
        MOV DWORD PTR [EBP-12],EAX
_CCL_88:
        MOV EAX,DWORD PTR [EBP-12]
        PUSH EAX
        MOV EAX,5
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_91
        XOR EAX,EAX
        JMP _CCL_92
_CCL_91:
        MOV EAX,1
_CCL_92:
        TEST EAX,EAX
        JZ _CCL_90
        MOV EAX,DWORD PTR [EBP-12]
        PUSH EAX
        MOV EAX,2
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_95
        XOR EAX,EAX
        JMP _CCL_96
_CCL_95:
        MOV EAX,1
_CCL_96:
        TEST EAX,EAX
        JZ _CCL_93
        JMP _CCL_90
_CCL_93:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
_CCL_89:
        MOV EAX,DWORD PTR [EBP-12]
        INC EAX
        MOV DWORD PTR [EBP-12],EAX
        JMP _CCL_88
_CCL_90:
_CCL_84:
        MOV EAX,DWORD PTR [EBP-8]
        INC EAX
        MOV DWORD PTR [EBP-8],EAX
        JMP _CCL_83
_CCL_85:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_82
_CCL_82:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_while_nested ---
_CCF_test_while_nested:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,8
;   local s = [EBP-4]
        MOV DWORD PTR [EBP-4],0
;   local i = [EBP-8]
        MOV DWORD PTR [EBP-8],0
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
_CCL_98:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,3
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_100
        XOR EAX,EAX
        JMP _CCL_101
_CCL_100:
        MOV EAX,1
_CCL_101:
        TEST EAX,EAX
        JZ _CCL_99
        MOV EAX,0
; WARNING: variable non trouvee pour stockage: j
_CCL_102:
; WARNING: variable non trouvee: j
        XOR EAX,EAX
        PUSH EAX
        MOV EAX,4
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_104
        XOR EAX,EAX
        JMP _CCL_105
_CCL_104:
        MOV EAX,1
_CCL_105:
        TEST EAX,EAX
        JZ _CCL_103
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
; WARNING: variable non trouvee: j
        XOR EAX,EAX
        INC EAX
; WARNING: variable non trouvee pour stockage: j
        JMP _CCL_102
_CCL_103:
        MOV EAX,DWORD PTR [EBP-8]
        INC EAX
        MOV DWORD PTR [EBP-8],EAX
        JMP _CCL_98
_CCL_99:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_97
_CCL_97:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_for_empty_init ---
_CCF_test_for_empty_init:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,8
;   local s = [EBP-4]
        MOV DWORD PTR [EBP-4],0
;   local i = [EBP-8]
        MOV DWORD PTR [EBP-8],0
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
_CCL_107:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,5
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_110
        XOR EAX,EAX
        JMP _CCL_111
_CCL_110:
        MOV EAX,1
_CCL_111:
        TEST EAX,EAX
        JZ _CCL_109
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
_CCL_108:
        MOV EAX,DWORD PTR [EBP-8]
        INC EAX
        MOV DWORD PTR [EBP-8],EAX
        JMP _CCL_107
_CCL_109:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_106
_CCL_106:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: main ---
_CCF_main:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   local r = [EBP-4]
        MOV EAX,5
        PUSH EAX
        CALL _CCF_test_while_simple
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        CALL _CCF_test_while_zero
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,5
        PUSH EAX
        CALL _CCF_test_do_while
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,5
        PUSH EAX
        CALL _CCF_test_for_simple
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,10
        PUSH EAX
        CALL _CCF_test_for_decl
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,10
        PUSH EAX
        CALL _CCF_test_for_compound_incr
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,5
        PUSH EAX
        CALL _CCF_test_for_break
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,5
        PUSH EAX
        CALL _CCF_test_while_break
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,10
        PUSH EAX
        CALL _CCF_test_for_continue
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        CALL _CCF_test_while_continue
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,3
        PUSH EAX
        CALL _CCF_test_nested_for
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        CALL _CCF_test_nested_break
        MOV DWORD PTR [EBP-4],EAX
        CALL _CCF_test_while_nested
        MOV DWORD PTR [EBP-4],EAX
        CALL _CCF_test_for_empty_init
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        JMP _CCL_112
_CCL_112:
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
