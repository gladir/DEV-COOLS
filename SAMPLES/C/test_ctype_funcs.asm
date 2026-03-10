; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/test_ctype_funcs.c

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

_CCK_1  DB '=== Test ctype.h ===',10,0
_CCK_2  DB 'isdigit(5)=%d',10,0
_CCK_3  DB 'isdigit(a)=%d',10,0
_CCK_4  DB 'isalpha(A)=%d',10,0
_CCK_5  DB 'isalpha(3)=%d',10,0
_CCK_6  DB 'isupper(A)=%d',10,0
_CCK_7  DB 'islower(a)=%d',10,0
_CCK_8  DB 'tolower(A)=%d',10,0
_CCK_9  DB 'toupper(a)=%d',10,0
_CCK_10  DB 'isspace( )=%d',10,0
_CCK_11  DB 'ctype.h: OK',10,0

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

; --- Fonction: my_isdigit ---
_CCF_my_isdigit:
        PUSH EBP
        MOV EBP,ESP
;   param c = [EBP+8]
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,48
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JGE _CCL_4
        XOR EAX,EAX
        JMP _CCL_5
_CCL_4:
        MOV EAX,1
_CCL_5:
        TEST EAX,EAX
        JZ _CCL_2
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,57
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JLE _CCL_8
        XOR EAX,EAX
        JMP _CCL_9
_CCL_8:
        MOV EAX,1
_CCL_9:
        TEST EAX,EAX
        JZ _CCL_6
        MOV EAX,1
        JMP _CCL_1
_CCL_6:
_CCL_2:
        MOV EAX,0
        JMP _CCL_1
_CCL_1:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: my_isalpha ---
_CCF_my_isalpha:
        PUSH EBP
        MOV EBP,ESP
;   param c = [EBP+8]
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,65
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JGE _CCL_13
        XOR EAX,EAX
        JMP _CCL_14
_CCL_13:
        MOV EAX,1
_CCL_14:
        TEST EAX,EAX
        JZ _CCL_11
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,90
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JLE _CCL_17
        XOR EAX,EAX
        JMP _CCL_18
_CCL_17:
        MOV EAX,1
_CCL_18:
        TEST EAX,EAX
        JZ _CCL_15
        MOV EAX,1
        JMP _CCL_10
_CCL_15:
_CCL_11:
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,97
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JGE _CCL_21
        XOR EAX,EAX
        JMP _CCL_22
_CCL_21:
        MOV EAX,1
_CCL_22:
        TEST EAX,EAX
        JZ _CCL_19
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,122
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JLE _CCL_25
        XOR EAX,EAX
        JMP _CCL_26
_CCL_25:
        MOV EAX,1
_CCL_26:
        TEST EAX,EAX
        JZ _CCL_23
        MOV EAX,1
        JMP _CCL_10
_CCL_23:
_CCL_19:
        MOV EAX,0
        JMP _CCL_10
_CCL_10:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: my_isupper ---
_CCF_my_isupper:
        PUSH EBP
        MOV EBP,ESP
;   param c = [EBP+8]
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,65
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JGE _CCL_30
        XOR EAX,EAX
        JMP _CCL_31
_CCL_30:
        MOV EAX,1
_CCL_31:
        TEST EAX,EAX
        JZ _CCL_28
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,90
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JLE _CCL_34
        XOR EAX,EAX
        JMP _CCL_35
_CCL_34:
        MOV EAX,1
_CCL_35:
        TEST EAX,EAX
        JZ _CCL_32
        MOV EAX,1
        JMP _CCL_27
_CCL_32:
_CCL_28:
        MOV EAX,0
        JMP _CCL_27
_CCL_27:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: my_islower ---
_CCF_my_islower:
        PUSH EBP
        MOV EBP,ESP
;   param c = [EBP+8]
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,97
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JGE _CCL_39
        XOR EAX,EAX
        JMP _CCL_40
_CCL_39:
        MOV EAX,1
_CCL_40:
        TEST EAX,EAX
        JZ _CCL_37
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,122
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JLE _CCL_43
        XOR EAX,EAX
        JMP _CCL_44
_CCL_43:
        MOV EAX,1
_CCL_44:
        TEST EAX,EAX
        JZ _CCL_41
        MOV EAX,1
        JMP _CCL_36
_CCL_41:
_CCL_37:
        MOV EAX,0
        JMP _CCL_36
_CCL_36:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: my_tolower ---
_CCF_my_tolower:
        PUSH EBP
        MOV EBP,ESP
;   param c = [EBP+8]
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,65
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JGE _CCL_48
        XOR EAX,EAX
        JMP _CCL_49
_CCL_48:
        MOV EAX,1
_CCL_49:
        TEST EAX,EAX
        JZ _CCL_46
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,90
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JLE _CCL_52
        XOR EAX,EAX
        JMP _CCL_53
_CCL_52:
        MOV EAX,1
_CCL_53:
        TEST EAX,EAX
        JZ _CCL_50
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,32
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        JMP _CCL_45
_CCL_50:
_CCL_46:
        MOV EAX,DWORD PTR [EBP+8]
        JMP _CCL_45
_CCL_45:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: my_toupper ---
_CCF_my_toupper:
        PUSH EBP
        MOV EBP,ESP
;   param c = [EBP+8]
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,97
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JGE _CCL_57
        XOR EAX,EAX
        JMP _CCL_58
_CCL_57:
        MOV EAX,1
_CCL_58:
        TEST EAX,EAX
        JZ _CCL_55
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,122
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JLE _CCL_61
        XOR EAX,EAX
        JMP _CCL_62
_CCL_61:
        MOV EAX,1
_CCL_62:
        TEST EAX,EAX
        JZ _CCL_59
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,32
        MOV EBX,EAX
        POP EAX
        SUB EAX,EBX
        JMP _CCL_54
_CCL_59:
_CCL_55:
        MOV EAX,DWORD PTR [EBP+8]
        JMP _CCL_54
_CCL_54:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: my_isspace ---
_CCF_my_isspace:
        PUSH EBP
        MOV EBP,ESP
;   param c = [EBP+8]
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,32
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_66
        XOR EAX,EAX
        JMP _CCL_67
_CCL_66:
        MOV EAX,1
_CCL_67:
        TEST EAX,EAX
        JZ _CCL_64
        MOV EAX,1
        JMP _CCL_63
_CCL_64:
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,9
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_70
        XOR EAX,EAX
        JMP _CCL_71
_CCL_70:
        MOV EAX,1
_CCL_71:
        TEST EAX,EAX
        JZ _CCL_68
        MOV EAX,1
        JMP _CCL_63
_CCL_68:
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,10
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_74
        XOR EAX,EAX
        JMP _CCL_75
_CCL_74:
        MOV EAX,1
_CCL_75:
        TEST EAX,EAX
        JZ _CCL_72
        MOV EAX,1
        JMP _CCL_63
_CCL_72:
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,13
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_78
        XOR EAX,EAX
        JMP _CCL_79
_CCL_78:
        MOV EAX,1
_CCL_79:
        TEST EAX,EAX
        JZ _CCL_76
        MOV EAX,1
        JMP _CCL_63
_CCL_76:
        MOV EAX,0
        JMP _CCL_63
_CCL_63:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: main ---
_CCF_main:
        PUSH EBP
        MOV EBP,ESP
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_12
        CALL _CCRT_PRINTSTR
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_13
        CALL _CCRT_PRINTSTR
        MOV EAX,53
        PUSH EAX
        CALL _CCF_my_isdigit
        ADD ESP,4
        CALL _CCRT_PRINTINT
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_14
        CALL _CCRT_PRINTSTR
        MOV EAX,97
        PUSH EAX
        CALL _CCF_my_isdigit
        ADD ESP,4
        CALL _CCRT_PRINTINT
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_15
        CALL _CCRT_PRINTSTR
        MOV EAX,65
        PUSH EAX
        CALL _CCF_my_isalpha
        ADD ESP,4
        CALL _CCRT_PRINTINT
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_16
        CALL _CCRT_PRINTSTR
        MOV EAX,51
        PUSH EAX
        CALL _CCF_my_isalpha
        ADD ESP,4
        CALL _CCRT_PRINTINT
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_17
        CALL _CCRT_PRINTSTR
        MOV EAX,65
        PUSH EAX
        CALL _CCF_my_isupper
        ADD ESP,4
        CALL _CCRT_PRINTINT
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_18
        CALL _CCRT_PRINTSTR
        MOV EAX,97
        PUSH EAX
        CALL _CCF_my_islower
        ADD ESP,4
        CALL _CCRT_PRINTINT
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_19
        CALL _CCRT_PRINTSTR
        MOV EAX,65
        PUSH EAX
        CALL _CCF_my_tolower
        ADD ESP,4
        CALL _CCRT_PRINTINT
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_20
        CALL _CCRT_PRINTSTR
        MOV EAX,97
        PUSH EAX
        CALL _CCF_my_toupper
        ADD ESP,4
        CALL _CCRT_PRINTINT
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_21
        CALL _CCRT_PRINTSTR
        MOV EAX,32
        PUSH EAX
        CALL _CCF_my_isspace
        ADD ESP,4
        CALL _CCRT_PRINTINT
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_22
        CALL _CCRT_PRINTSTR
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
        MOV EAX,0
        JMP _CCL_80
_CCL_80:
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

_CCK_12  DB '=== Test ctype.h ===',0
_CCK_13  DB 'isdigit(5)=',0
_CCK_14  DB 'isdigit(a)=',0
_CCK_15  DB 'isalpha(A)=',0
_CCK_16  DB 'isalpha(3)=',0
_CCK_17  DB 'isupper(A)=',0
_CCK_18  DB 'islower(a)=',0
_CCK_19  DB 'tolower(A)=',0
_CCK_20  DB 'toupper(a)=',0
_CCK_21  DB 'isspace( )=',0
_CCK_22  DB 'ctype.h: OK',0

.CODE

END _main
