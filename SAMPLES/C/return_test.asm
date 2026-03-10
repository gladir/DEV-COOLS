; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/return_test.c

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

; --- Fonction: test_return_value ---
_CCF_test_return_value:
        PUSH EBP
        MOV EBP,ESP
        MOV EAX,42
        JMP _CCL_1
_CCL_1:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_return_expr ---
_CCF_test_return_expr:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   local x = [EBP-4]
        MOV DWORD PTR [EBP-4],10
        MOV EAX,10
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_2
_CCL_2:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_return_void ---
_CCF_test_return_void:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   local y = [EBP-4]
        MOV DWORD PTR [EBP-4],20
        MOV EAX,20
        MOV DWORD PTR [EBP-4],EAX
        XOR EAX,EAX
        JMP _CCL_3
_CCL_3:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: main ---
_CCF_main:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,8
;   local result1 = [EBP-4]
        MOV DWORD PTR [EBP-4],0
;   local result2 = [EBP-8]
        MOV DWORD PTR [EBP-8],0
        CALL _CCF_test_return_value
        MOV DWORD PTR [EBP-4],EAX
        CALL _CCF_test_return_expr
        MOV DWORD PTR [EBP-8],EAX
        CALL _CCF_test_return_void
        MOV EAX,0
        JMP _CCL_4
_CCL_4:
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
