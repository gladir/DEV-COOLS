; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/test_compound_assign.c

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

; --- Fonction: test_compound_arith ---
_CCF_test_compound_arith:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   local x = [EBP-4]
        MOV DWORD PTR [EBP-4],10
        MOV EAX,10
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,5
        MOV EBX,EAX
        MOV EAX,DWORD PTR [EBP-4]
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,3
        MOV EBX,EAX
        MOV EAX,DWORD PTR [EBP-4]
        SUB EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,2
        MOV EBX,EAX
        MOV EAX,DWORD PTR [EBP-4]
        IMUL EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,4
        MOV EBX,EAX
        MOV EAX,DWORD PTR [EBP-4]
        CDQ
        IDIV EBX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,3
        MOV EBX,EAX
        MOV EAX,DWORD PTR [EBP-4]
        CDQ
        IDIV EBX
        MOV EAX,EDX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_1
_CCL_1:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_compound_bitwise ---
_CCF_test_compound_bitwise:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   local a = [EBP-4]
        MOV DWORD PTR [EBP-4],255
        MOV EAX,255
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,15
        MOV EBX,EAX
        MOV EAX,DWORD PTR [EBP-4]
        AND EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,48
        MOV EBX,EAX
        MOV EAX,DWORD PTR [EBP-4]
        OR EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,5
        MOV EBX,EAX
        MOV EAX,DWORD PTR [EBP-4]
        XOR EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,2
        MOV EBX,EAX
        MOV EAX,DWORD PTR [EBP-4]
        MOV ECX,EBX
        SHL EAX,CL
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,1
        MOV EBX,EAX
        MOV EAX,DWORD PTR [EBP-4]
        MOV ECX,EBX
        SAR EAX,CL
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_2
_CCL_2:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_post_increment ---
_CCF_test_post_increment:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   local i = [EBP-4]
        MOV DWORD PTR [EBP-4],0
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        INC EAX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        INC EAX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        INC EAX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_3
_CCL_3:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_post_decrement ---
_CCF_test_post_decrement:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   local j = [EBP-4]
        MOV DWORD PTR [EBP-4],10
        MOV EAX,10
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        DEC EAX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        DEC EAX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        DEC EAX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_4
_CCL_4:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_pre_increment ---
_CCF_test_pre_increment:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   local k = [EBP-4]
        MOV DWORD PTR [EBP-4],0
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        INC EAX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        INC EAX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_5
_CCL_5:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_pre_decrement ---
_CCF_test_pre_decrement:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   local m = [EBP-4]
        MOV DWORD PTR [EBP-4],5
        MOV EAX,5
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        DEC EAX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        DEC EAX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_6
_CCL_6:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_deref_assign ---
_CCF_test_deref_assign:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,8
;   local val = [EBP-4]
        MOV DWORD PTR [EBP-4],42
;   local p = [EBP-8]
        MOV EAX,42
        MOV DWORD PTR [EBP-4],EAX
        LEA EAX,[EBP-4]
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,100
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        POP DWORD PTR [EAX]
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_7
_CCL_7:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_deref_compound ---
_CCF_test_deref_compound:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,8
;   local val = [EBP-4]
        MOV DWORD PTR [EBP-4],10
;   local p = [EBP-8]
        MOV EAX,10
        MOV DWORD PTR [EBP-4],EAX
        LEA EAX,[EBP-4]
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,5
        MOV EBX,EAX
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EAX]
        ADD EAX,EBX
        POP ECX
        MOV DWORD PTR [ECX],EAX
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_8
_CCL_8:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_mixed ---
_CCF_test_mixed:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,8
;   local a = [EBP-4]
        MOV DWORD PTR [EBP-4],1
;   local b = [EBP-8]
        MOV DWORD PTR [EBP-8],2
        MOV EAX,1
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,2
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        MOV EAX,DWORD PTR [EBP-4]
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        MOV EBX,EAX
        MOV EAX,DWORD PTR [EBP-8]
        IMUL EAX,EBX
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,1
        MOV EBX,EAX
        MOV EAX,DWORD PTR [EBP-4]
        SUB EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,2
        MOV EBX,EAX
        MOV EAX,DWORD PTR [EBP-8]
        CDQ
        IDIV EBX
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        JMP _CCL_9
_CCL_9:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: main ---
_CCF_main:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   local r = [EBP-4]
        CALL _CCF_test_compound_arith
        MOV DWORD PTR [EBP-4],EAX
        CALL _CCF_test_compound_bitwise
        MOV DWORD PTR [EBP-4],EAX
        CALL _CCF_test_post_increment
        MOV DWORD PTR [EBP-4],EAX
        CALL _CCF_test_post_decrement
        MOV DWORD PTR [EBP-4],EAX
        CALL _CCF_test_pre_increment
        MOV DWORD PTR [EBP-4],EAX
        CALL _CCF_test_pre_decrement
        MOV DWORD PTR [EBP-4],EAX
        CALL _CCF_test_deref_assign
        MOV DWORD PTR [EBP-4],EAX
        CALL _CCF_test_deref_compound
        MOV DWORD PTR [EBP-4],EAX
        CALL _CCF_test_mixed
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        JMP _CCL_10
_CCL_10:
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
