; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/test_goto.c

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

_CCK_1  DB 'test_simple_goto = %d',10,0
_CCK_2  DB 'test_goto_forward = %d',10,0
_CCK_3  DB 'test_goto_in_if = %d',10,0
_CCK_4  DB 'test_break_in_loop = %d',10,0
_CCK_5  DB 'test_continue_in_loop = %d',10,0
_CCK_6  DB 'test_return_expr = %d',10,0

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

; --- Fonction: test_simple_goto ---
_CCF_test_simple_goto:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   local x = [EBP-4]
        MOV DWORD PTR [EBP-4],1
        MOV EAX,1
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_USR_skip
        MOV EAX,99
        MOV DWORD PTR [EBP-4],EAX
_CCL_USR_skip:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_1
_CCL_1:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_goto_forward ---
_CCF_test_goto_forward:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   local r = [EBP-4]
        MOV DWORD PTR [EBP-4],0
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_USR_label2
_CCL_USR_label1:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_USR_label3
_CCL_USR_label2:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,10
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_USR_label1
_CCL_USR_label3:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_2
_CCL_2:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_goto_in_if ---
_CCF_test_goto_in_if:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   local v = [EBP-4]
        MOV DWORD PTR [EBP-4],5
        MOV EAX,5
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,3
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _CCL_6
        XOR EAX,EAX
        JMP _CCL_7
_CCL_6:
        MOV EAX,1
_CCL_7:
        TEST EAX,EAX
        JZ _CCL_4
        JMP _CCL_USR_done
_CCL_4:
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
_CCL_USR_done:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_3
_CCL_3:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_break_in_loop ---
_CCF_test_break_in_loop:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,8
;   local i = [EBP-4]
        MOV DWORD PTR [EBP-4],0
;   local s = [EBP-8]
        MOV DWORD PTR [EBP-8],0
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
_CCL_9:
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
        MOV EAX,5
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
        JMP _CCL_11
_CCL_14:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-4]
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-8],EAX
_CCL_10:
        MOV EAX,DWORD PTR [EBP-4]
        INC EAX
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_9
_CCL_11:
        MOV EAX,DWORD PTR [EBP-8]
        JMP _CCL_8
_CCL_8:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_continue_in_loop ---
_CCF_test_continue_in_loop:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,8
;   local i = [EBP-4]
        MOV DWORD PTR [EBP-4],0
;   local s = [EBP-8]
        MOV DWORD PTR [EBP-8],0
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
_CCL_19:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,5
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_22
        XOR EAX,EAX
        JMP _CCL_23
_CCL_22:
        MOV EAX,1
_CCL_23:
        TEST EAX,EAX
        JZ _CCL_21
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,2
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_26
        XOR EAX,EAX
        JMP _CCL_27
_CCL_26:
        MOV EAX,1
_CCL_27:
        TEST EAX,EAX
        JZ _CCL_24
        JMP _CCL_20
_CCL_24:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-4]
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-8],EAX
_CCL_20:
        MOV EAX,DWORD PTR [EBP-4]
        INC EAX
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_19
_CCL_21:
        MOV EAX,DWORD PTR [EBP-8]
        JMP _CCL_18
_CCL_18:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_return_void ---
_CCF_test_return_void:
        PUSH EBP
        MOV EBP,ESP
        XOR EAX,EAX
        JMP _CCL_28
_CCL_28:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_return_expr ---
_CCF_test_return_expr:
        PUSH EBP
        MOV EBP,ESP
        MOV EAX,42
        JMP _CCL_29
_CCL_29:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: main ---
_CCF_main:
        PUSH EBP
        MOV EBP,ESP
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_7
        CALL _CCRT_PRINTSTR
        CALL _CCF_test_simple_goto
        CALL _CCRT_PRINTINT
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_8
        CALL _CCRT_PRINTSTR
        CALL _CCF_test_goto_forward
        CALL _CCRT_PRINTINT
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_9
        CALL _CCRT_PRINTSTR
        CALL _CCF_test_goto_in_if
        CALL _CCRT_PRINTINT
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_10
        CALL _CCRT_PRINTSTR
        CALL _CCF_test_break_in_loop
        CALL _CCRT_PRINTINT
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_11
        CALL _CCRT_PRINTSTR
        CALL _CCF_test_continue_in_loop
        CALL _CCRT_PRINTINT
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
; printf (TODO 21)
        MOV ESI,OFFSET _CCK_12
        CALL _CCRT_PRINTSTR
        CALL _CCF_test_return_expr
        CALL _CCRT_PRINTINT
        CALL _CCRT_PRINTCRLF
        XOR EAX,EAX
        MOV EAX,0
        JMP _CCL_30
_CCL_30:
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

_CCK_7  DB 'test_simple_goto = ',0
_CCK_8  DB 'test_goto_forward = ',0
_CCK_9  DB 'test_goto_in_if = ',0
_CCK_10  DB 'test_break_in_loop = ',0
_CCK_11  DB 'test_continue_in_loop = ',0
_CCK_12  DB 'test_return_expr = ',0

.CODE

END _main
