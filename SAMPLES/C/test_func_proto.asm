; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/test_func_proto.c

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

; --- Imports utilisateur (extern) ---
EXTRN _ext_func:NEAR

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

; --- Fonction: helper ---
_CCF_helper:
        PUSH EBP
        MOV EBP,ESP
;   param x = [EBP+8]
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,2
        MOV EBX,EAX
        POP EAX
        IMUL EAX,EBX
        JMP _CCL_1
_CCL_1:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: add ---
_CCF_add:
        PUSH EBP
        MOV EBP,ESP
;   param a = [EBP+8]
;   param b = [EBP+12]
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+12]
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        JMP _CCL_2
_CCL_2:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: sub ---
_CCF_sub:
        PUSH EBP
        MOV EBP,ESP
;   param a = [EBP+8]
;   param b = [EBP+12]
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+12]
        MOV EBX,EAX
        POP EAX
        SUB EAX,EBX
        JMP _CCL_3
_CCL_3:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: factorial ---
_CCF_factorial:
        PUSH EBP
        MOV EBP,ESP
;   param n = [EBP+8]
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JLE _CCL_7
        XOR EAX,EAX
        JMP _CCL_8
_CCL_7:
        MOV EAX,1
_CCL_8:
        TEST EAX,EAX
        JZ _CCL_5
        MOV EAX,1
        JMP _CCL_4
_CCL_5:
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        SUB EAX,EBX
        PUSH EAX
        CALL _CCF_factorial
        ADD ESP,4
        MOV EBX,EAX
        POP EAX
        IMUL EAX,EBX
        JMP _CCL_4
_CCL_4:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: do_nothing ---
_CCF_do_nothing:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   local x = [EBP-4]
        MOV DWORD PTR [EBP-4],0
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
_CCL_9:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: max_of ---
_CCF_max_of:
        PUSH EBP
        MOV EBP,ESP
;   param a = [EBP+8]
;   param b = [EBP+12]
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+12]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _CCL_13
        XOR EAX,EAX
        JMP _CCL_14
_CCL_13:
        MOV EAX,1
_CCL_14:
        TEST EAX,EAX
        JZ _CCL_11
        MOV EAX,DWORD PTR [EBP+8]
        JMP _CCL_10
_CCL_11:
        MOV EAX,DWORD PTR [EBP+12]
        JMP _CCL_10
_CCL_10:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: compute ---
_CCF_compute:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,8
;   param a = [EBP+8]
;   param b = [EBP+12]
;   param c = [EBP+16]
;   local sum = [EBP-4]
        MOV DWORD PTR [EBP-4],0
;   local avg = [EBP-8]
        MOV DWORD PTR [EBP-8],0
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+12]
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+16]
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,3
        MOV EBX,EAX
        POP EAX
        CDQ
        IDIV EBX
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,DWORD PTR [EBP-8]
        JMP _CCL_15
_CCL_15:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: chain_call ---
_CCF_chain_call:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,12
;   param x = [EBP+8]
;   local a = [EBP-4]
        MOV DWORD PTR [EBP-4],0
;   local b = [EBP-8]
        MOV DWORD PTR [EBP-8],0
;   local c = [EBP-12]
        MOV DWORD PTR [EBP-12],0
        MOV EAX,1
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        CALL _CCF_add
        ADD ESP,8
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,2
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        CALL _CCF_sub
        ADD ESP,8
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        CALL _CCF_helper
        ADD ESP,4
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-12]
        JMP _CCL_16
_CCL_16:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: sum5 ---
_CCF_sum5:
        PUSH EBP
        MOV EBP,ESP
;   param a = [EBP+8]
;   param b = [EBP+12]
;   param c = [EBP+16]
;   param d = [EBP+20]
;   param e = [EBP+24]
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+12]
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+16]
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+20]
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+24]
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        JMP _CCL_17
_CCL_17:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: main ---
_CCF_main:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   local r = [EBP-4]
        MOV EAX,4
        PUSH EAX
        MOV EAX,3
        PUSH EAX
        CALL _CCF_add
        ADD ESP,8
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,3
        PUSH EAX
        MOV EAX,10
        PUSH EAX
        CALL _CCF_sub
        ADD ESP,8
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,5
        PUSH EAX
        CALL _CCF_factorial
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        CALL _CCF_do_nothing
        MOV EAX,20
        PUSH EAX
        MOV EAX,10
        PUSH EAX
        CALL _CCF_max_of
        ADD ESP,8
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,15
        PUSH EAX
        MOV EAX,30
        PUSH EAX
        CALL _CCF_max_of
        ADD ESP,8
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,12
        PUSH EAX
        MOV EAX,9
        PUSH EAX
        MOV EAX,6
        PUSH EAX
        CALL _CCF_compute
        ADD ESP,12
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,5
        PUSH EAX
        CALL _CCF_chain_call
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,5
        PUSH EAX
        MOV EAX,4
        PUSH EAX
        MOV EAX,3
        PUSH EAX
        MOV EAX,2
        PUSH EAX
        MOV EAX,1
        PUSH EAX
        CALL _CCF_sum5
        ADD ESP,20
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,7
        PUSH EAX
        CALL _CCF_helper
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        JMP _CCL_18
_CCL_18:
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
