; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/long_advanced_test.c

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

; --- Fonction: add_long ---
_CCF_add_long:
        PUSH EBP
        MOV EBP,ESP
;   param x = [EBP+8]
;   param y = [EBP+12]
        MOV EAX,DWORD PTR [EBP+8]
        JMP _CCL_1
_CCL_1:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: multiply_long ---
_CCF_multiply_long:
        PUSH EBP
        MOV EBP,ESP
;   param a = [EBP+8]
;   param b = [EBP+12]
        MOV EAX,DWORD PTR [EBP+8]
        JMP _CCL_2
_CCL_2:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: main ---
_CCF_main:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,12
;   local a = [EBP-4]
        MOV DWORD PTR [EBP-4],50000
;   local b = [EBP-8]
        MOV DWORD PTR [EBP-8],75000
;   local result = [EBP-12]
        MOV EAX,50000
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,75000
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        CALL _CCF_add_long
        ADD ESP,8
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        CALL _CCF_multiply_long
        ADD ESP,8
        MOV DWORD PTR [EBP-12],EAX
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
