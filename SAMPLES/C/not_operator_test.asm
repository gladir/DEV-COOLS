; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/not_operator_test.c

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

_CCK_1  DB '!0 = %d (devrait ',195,170,'tre 1)',10,0
_CCK_2  DB '!1 = %d (devrait ',195,170,'tre 0)',10,0
_CCK_3  DB '!5 = %d (devrait ',195,170,'tre 0)',10,0
_CCK_4  DB '!(-3) = %d (devrait ',195,170,'tre 0)',10,0
_CCK_5  DB '!(10 > 5) = %d (devrait ',195,170,'tre 0)',10,0
_CCK_6  DB '!(10 < 5) = %d (devrait ',195,170,'tre 1)',10,0
_CCK_7  DB '!!0 = %d (devrait ',195,170,'tre 0)',10,0
_CCK_8  DB '!!7 = %d (devrait ',195,170,'tre 1)',10,0

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
