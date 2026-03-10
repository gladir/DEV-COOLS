; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/static_test.c

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

_CCV_global_counter  DD 0
_CCV_normal_var  DD 42
_CCST_1  DD 0
_CCST_2  DD 10
_CCST_3  DD 100

; --- Segment de code ---
.CODE

; --- Fonction: internal_function ---
_CCF_internal_function:
        PUSH EBP
        MOV EBP,ESP
;   static call_count = [_CCST_1]
        MOV EAX,0
        MOV DWORD PTR [_CCST_1],EAX
        MOV EAX,DWORD PTR [_CCST_1]
        INC EAX
        MOV DWORD PTR [_CCST_1],EAX
_CCL_1:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: public_function ---
_CCF_public_function:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   static local_static = [_CCST_2]
;   local local_auto = [EBP-4]
        MOV DWORD PTR [EBP-4],20
        MOV EAX,10
        MOV DWORD PTR [_CCST_2],EAX
        MOV EAX,20
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [_CCST_2]
        INC EAX
        MOV DWORD PTR [_CCST_2],EAX
_CCL_2:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: main ---
_CCF_main:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   static main_static = [_CCST_3]
;   local main_auto = [EBP-4]
        MOV DWORD PTR [EBP-4],200
        MOV EAX,100
        MOV DWORD PTR [_CCST_3],EAX
        MOV EAX,200
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,5
        MOV DWORD PTR [_CCV_global_counter],EAX
        MOV EAX,150
        MOV DWORD PTR [_CCST_3],EAX
        CALL _CCF_public_function
        CALL _CCF_internal_function
        MOV EAX,0
        JMP _CCL_3
_CCL_3:
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
