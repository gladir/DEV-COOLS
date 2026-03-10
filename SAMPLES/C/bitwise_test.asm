; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/bitwise_test.c

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

_CCK_1  DB 'a & b = %d',10,0
_CCK_2  DB 'a | b = %d',10,0
_CCK_3  DB 'a ^ b = %d',10,0

; --- Segment de code ---
.CODE

; --- Fonction: main ---
_CCF_main:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,12
;   local a = [EBP-4]
;   local b = [EBP-8]
;   local result = [EBP-12]
        MOV EAX,5
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,3
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,DWORD PTR [EBP-4]
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-12]
        PUSH EAX
        MOV EAX,OFFSET _CCK_1
        PUSH EAX
        CALL _printf
        ADD ESP,8
        MOV EAX,DWORD PTR [EBP-4]
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-12]
        PUSH EAX
        MOV EAX,OFFSET _CCK_2
        PUSH EAX
        CALL _printf
        ADD ESP,8
        MOV EAX,DWORD PTR [EBP-4]
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-12]
        PUSH EAX
        MOV EAX,OFFSET _CCK_3
        PUSH EAX
        CALL _printf
        ADD ESP,8
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
