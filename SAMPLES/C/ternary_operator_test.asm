; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/ternary_operator_test.c

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

_CCK_1  DB 'max(10, 5) = %d (devrait ',195,170,'tre 10)',10,0
_CCK_2  DB 'condition fausse: %d (devrait ',195,170,'tre 5)',10,0
_CCK_3  DB '1 ? 100 : 200 = %d (devrait ',195,170,'tre 100)',10,0
_CCK_4  DB '0 ? 100 : 200 = %d (devrait ',195,170,'tre 200)',10,0
_CCK_5  DB '(8 > 5) ? (3 + 2) : (3 - 2) = %d (devrait ',195,170,'tre 5)',10,0
_CCK_6  DB '(8 < 5) ? (3 + 2) : (3 - 2) = %d (devrait ',195,170,'tre 1)',10,0
_CCK_7  DB 'Ternaire imbriqu',195,169,': %d (devrait ',195,170,'tre 2)',10,0
_CCK_8  DB '0 ? 42 : 99 = %d (devrait ',195,170,'tre 99)',10,0
_CCK_9  DB '1 ? 42 : 99 = %d (devrait ',195,170,'tre 42)',10,0
_CCK_10  DB '!7 ? 0 : 7 = %d (devrait ',195,170,'tre 7)',10,0

; --- Segment de code ---
.CODE

; --- Fonction: main ---
_CCF_main:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,16
;   local a = [EBP-4]
;   local b = [EBP-8]
;   local c = [EBP-12]
;   local result = [EBP-16]
        MOV EAX,10
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,5
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,DWORD PTR [EBP-4]
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,DWORD PTR [EBP-16]
        PUSH EAX
        MOV EAX,OFFSET _CCK_1
        PUSH EAX
        CALL _printf
        ADD ESP,8
        MOV EAX,DWORD PTR [EBP-4]
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,DWORD PTR [EBP-16]
        PUSH EAX
        MOV EAX,OFFSET _CCK_2
        PUSH EAX
        CALL _printf
        ADD ESP,8
        MOV EAX,1
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,DWORD PTR [EBP-16]
        PUSH EAX
        MOV EAX,OFFSET _CCK_3
        PUSH EAX
        CALL _printf
        ADD ESP,8
        MOV EAX,0
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,DWORD PTR [EBP-16]
        PUSH EAX
        MOV EAX,OFFSET _CCK_4
        PUSH EAX
        CALL _printf
        ADD ESP,8
        MOV EAX,8
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,3
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,2
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,DWORD PTR [EBP-16]
        PUSH EAX
        MOV EAX,OFFSET _CCK_5
        PUSH EAX
        CALL _printf
        ADD ESP,8
        MOV EAX,DWORD PTR [EBP-4]
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,DWORD PTR [EBP-16]
        PUSH EAX
        MOV EAX,OFFSET _CCK_6
        PUSH EAX
        CALL _printf
        ADD ESP,8
        MOV EAX,15
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,DWORD PTR [EBP-16]
        PUSH EAX
        MOV EAX,OFFSET _CCK_7
        PUSH EAX
        CALL _printf
        ADD ESP,8
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,42
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,99
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,DWORD PTR [EBP-16]
        PUSH EAX
        MOV EAX,OFFSET _CCK_8
        PUSH EAX
        CALL _printf
        ADD ESP,8
        MOV EAX,1
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,DWORD PTR [EBP-16]
        PUSH EAX
        MOV EAX,OFFSET _CCK_9
        PUSH EAX
        CALL _printf
        ADD ESP,8
        MOV EAX,7
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        TEST EAX,EAX
        SETZ AL
        MOVZX EAX,AL
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,DWORD PTR [EBP-16]
        PUSH EAX
        MOV EAX,OFFSET _CCK_10
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
