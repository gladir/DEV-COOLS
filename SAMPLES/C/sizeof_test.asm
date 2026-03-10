; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/sizeof_test.c

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

_CCK_1  DB 'sizeof(int) = %d',10,0
_CCK_2  DB 'sizeof(char) = %d',10,0
_CCK_3  DB 'sizeof(int*) = %d',10,0
_CCK_4  DB 'sizeof(a) = %d',10,0
_CCK_5  DB 'sizeof(c) = %d',10,0
_CCK_6  DB 'sizeof(arr) = %d',10,0
_CCK_7  DB 'sizeof(ptr) = %d',10,0
_CCK_8  DB 'sizeof(a + c) = %d',10,0
_CCK_9  DB 'sizeof(*ptr) = %d',10,0

; --- Segment de code ---
.CODE

; --- Fonction: main ---
_CCF_main:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,56
;   local a = [EBP-4]
;   local c = [EBP-8]
;   local arr = [EBP-48]
;   local ptr = [EBP-52]
;   local result = [EBP-56]
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
