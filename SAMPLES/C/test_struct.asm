; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/test_struct.c

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

_CCV_g_pt  DB 8 DUP(0)

; --- Segment de code ---
.CODE

; --- Fonction: main ---
_CCF_main:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,24
;   local p = [EBP-8]
;   local q = [EBP-16]
;   local u = [EBP-20]
;   local r = [EBP-24]
        MOV EAX,10
        PUSH EAX
        LEA EAX,[EBP-8]
        POP DWORD PTR [EAX]
        MOV EAX,20
        PUSH EAX
        LEA EAX,[EBP-8]
        ADD EAX,4
        POP DWORD PTR [EAX]
        LEA EAX,[EBP-8]
        MOV EAX,DWORD PTR [EAX]
        MOV DWORD PTR [EBP-24],EAX
        LEA EAX,[EBP-8]
        ADD EAX,4
        MOV EAX,DWORD PTR [EAX]
        MOV DWORD PTR [EBP-24],EAX
        LEA EAX,[EBP-8]
        MOV EAX,DWORD PTR [EAX]
        PUSH EAX
        LEA EAX,[EBP-16]
        POP DWORD PTR [EAX]
        MOV EAX,42
        PUSH EAX
        LEA EAX,[EBP-16]
        ADD EAX,4
        POP DWORD PTR [EAX]
        MOV EAX,100
        PUSH EAX
        LEA EAX,[EBP-20]
        POP DWORD PTR [EAX]
        LEA EAX,[EBP-20]
        MOV EAX,DWORD PTR [EAX]
        MOV DWORD PTR [EBP-24],EAX
        MOV EAX,7
        PUSH EAX
        MOV EAX,OFFSET _CCV_g_pt
        POP DWORD PTR [EAX]
        MOV EAX,8
        PUSH EAX
        MOV EAX,OFFSET _CCV_g_pt
        ADD EAX,4
        POP DWORD PTR [EAX]
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
