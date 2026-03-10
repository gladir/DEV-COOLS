; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/test_complet.c

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

_CCV_global_var  DD 42

; --- Segment de code ---
.CODE

; --- Fonction: simple_function ---
_CCF_simple_function:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   param param = [EBP+8]
;   local local_var = [EBP-4]
        MOV DWORD PTR [EBP-4],10
        MOV EAX,10
        MOV DWORD PTR [EBP-4],EAX
        XOR EAX,EAX
        JMP _CCL_1
_CCL_1:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: main ---
_CCF_main:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,16
;   local x = [EBP-4]
        MOV DWORD PTR [EBP-4],5
;   local c = [EBP-8]
        MOV DWORD PTR [EBP-8],65
;   local ptr = [EBP-12]
        MOV DWORD PTR [EBP-12],0
;   local result = [EBP-16]
        MOV DWORD PTR [EBP-16],0
        MOV EAX,5
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,65
        MOV DWORD PTR [EBP-8],EAX
        LEA EAX,[EBP-4]
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [_CCV_global_var]
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,DWORD PTR [EBP-16]
        PUSH EAX
        CALL _CCF_simple_function
        ADD ESP,4
_CCL_2:
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
