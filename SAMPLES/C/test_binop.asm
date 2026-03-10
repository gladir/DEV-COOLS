; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/test_binop.c

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

; --- Fonction: test_arith ---
_CCF_test_arith:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,12
;   local a = [EBP-4]
        MOV DWORD PTR [EBP-4],10
;   local b = [EBP-8]
        MOV DWORD PTR [EBP-8],3
;   local c = [EBP-12]
        MOV EAX,10
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,3
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        SUB EAX,EBX
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        IMUL EAX,EBX
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        CDQ
        IDIV EBX
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        CDQ
        IDIV EBX
        MOV EAX,EDX
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-12]
        JMP _CCL_1
_CCL_1:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_compare ---
_CCF_test_compare:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,12
;   local a = [EBP-4]
        MOV DWORD PTR [EBP-4],5
;   local b = [EBP-8]
        MOV DWORD PTR [EBP-8],10
;   local r = [EBP-12]
        MOV EAX,5
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,10
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_3
        XOR EAX,EAX
        JMP _CCL_4
_CCL_3:
        MOV EAX,1
_CCL_4:
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JNE _CCL_5
        XOR EAX,EAX
        JMP _CCL_6
_CCL_5:
        MOV EAX,1
_CCL_6:
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_7
        XOR EAX,EAX
        JMP _CCL_8
_CCL_7:
        MOV EAX,1
_CCL_8:
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JLE _CCL_9
        XOR EAX,EAX
        JMP _CCL_10
_CCL_9:
        MOV EAX,1
_CCL_10:
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _CCL_11
        XOR EAX,EAX
        JMP _CCL_12
_CCL_11:
        MOV EAX,1
_CCL_12:
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JGE _CCL_13
        XOR EAX,EAX
        JMP _CCL_14
_CCL_13:
        MOV EAX,1
_CCL_14:
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-12]
        JMP _CCL_2
_CCL_2:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_bitwise ---
_CCF_test_bitwise:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,12
;   local a = [EBP-4]
        MOV DWORD PTR [EBP-4],255
;   local b = [EBP-8]
        MOV DWORD PTR [EBP-8],15
;   local c = [EBP-12]
        MOV EAX,255
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,15
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        AND EAX,EBX
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        OR EAX,EBX
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        XOR EAX,EBX
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,4
        MOV EBX,EAX
        POP EAX
        MOV ECX,EBX
        SHL EAX,CL
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,4
        MOV EBX,EAX
        POP EAX
        MOV ECX,EBX
        SAR EAX,CL
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-12]
        JMP _CCL_15
_CCL_15:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_logic ---
_CCF_test_logic:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,12
;   local a = [EBP-4]
        MOV DWORD PTR [EBP-4],1
;   local b = [EBP-8]
        MOV DWORD PTR [EBP-8],0
;   local r = [EBP-12]
        MOV EAX,1
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,DWORD PTR [EBP-4]
        TEST EAX,EAX
        JZ _CCL_17
        MOV EAX,DWORD PTR [EBP-8]
        TEST EAX,EAX
        JZ _CCL_17
        MOV EAX,1
        JMP _CCL_18
_CCL_17:
        XOR EAX,EAX
_CCL_18:
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        TEST EAX,EAX
        JNZ _CCL_19
        MOV EAX,DWORD PTR [EBP-8]
        TEST EAX,EAX
        JNZ _CCL_19
        XOR EAX,EAX
        JMP _CCL_20
_CCL_19:
        MOV EAX,1
_CCL_20:
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        TEST EAX,EAX
        SETZ AL
        MOVZX EAX,AL
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-12]
        JMP _CCL_16
_CCL_16:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_ternary ---
_CCF_test_ternary:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,8
;   local a = [EBP-4]
        MOV DWORD PTR [EBP-4],5
;   local r = [EBP-8]
        MOV EAX,5
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,0
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
        MOV EAX,0
_CCL_25:
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,DWORD PTR [EBP-8]
        JMP _CCL_21
_CCL_21:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_precedence ---
_CCF_test_precedence:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   local r = [EBP-4]
        MOV EAX,2
        PUSH EAX
        MOV EAX,3
        PUSH EAX
        MOV EAX,4
        MOV EBX,EAX
        POP EAX
        IMUL EAX,EBX
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,10
        PUSH EAX
        MOV EAX,2
        PUSH EAX
        MOV EAX,3
        MOV EBX,EAX
        POP EAX
        IMUL EAX,EBX
        MOV EBX,EAX
        POP EAX
        SUB EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,1
        PUSH EAX
        MOV EAX,2
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        PUSH EAX
        MOV EAX,3
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        SUB EAX,EBX
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _CCL_27
        XOR EAX,EAX
        JMP _CCL_28
_CCL_27:
        MOV EAX,1
_CCL_28:
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_26
_CCL_26:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: main ---
_CCF_main:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   local r = [EBP-4]
        CALL _CCF_test_arith
        MOV DWORD PTR [EBP-4],EAX
        CALL _CCF_test_compare
        MOV DWORD PTR [EBP-4],EAX
        CALL _CCF_test_bitwise
        MOV DWORD PTR [EBP-4],EAX
        CALL _CCF_test_logic
        MOV DWORD PTR [EBP-4],EAX
        CALL _CCF_test_ternary
        MOV DWORD PTR [EBP-4],EAX
        CALL _CCF_test_precedence
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        JMP _CCL_29
_CCL_29:
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
