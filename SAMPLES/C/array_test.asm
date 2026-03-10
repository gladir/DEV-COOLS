; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/array_test.c

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

; --- Fonction: main ---
_CCF_main:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,24
;   local arr = [EBP-20]
;   local i = [EBP-24]
        LEA EAX,[EBP-20]
        PUSH EAX
        MOV EAX,0
        SHL EAX,2
        POP EBX
        ADD EAX,EBX
        MOV EAX,DWORD PTR [EAX]
        PUSH EAX
        MOV EAX,10
        ADD ESP,4
; ; affectation dans expression
        LEA EAX,[EBP-20]
        PUSH EAX
        MOV EAX,1
        SHL EAX,2
        POP EBX
        ADD EAX,EBX
        MOV EAX,DWORD PTR [EAX]
        PUSH EAX
        MOV EAX,20
        ADD ESP,4
; ; affectation dans expression
        LEA EAX,[EBP-20]
        PUSH EAX
        MOV EAX,2
        SHL EAX,2
        POP EBX
        ADD EAX,EBX
        MOV EAX,DWORD PTR [EAX]
        PUSH EAX
        MOV EAX,30
        ADD ESP,4
; ; affectation dans expression
        LEA EAX,[EBP-20]
        PUSH EAX
        MOV EAX,3
        SHL EAX,2
        POP EBX
        ADD EAX,EBX
        MOV EAX,DWORD PTR [EAX]
        PUSH EAX
        MOV EAX,40
        ADD ESP,4
; ; affectation dans expression
        LEA EAX,[EBP-20]
        PUSH EAX
        MOV EAX,4
        SHL EAX,2
        POP EBX
        ADD EAX,EBX
        MOV EAX,DWORD PTR [EAX]
        PUSH EAX
        MOV EAX,50
        ADD ESP,4
; ; affectation dans expression
        LEA EAX,[EBP-20]
        PUSH EAX
        MOV EAX,2
        SHL EAX,2
        POP EBX
        ADD EAX,EBX
        MOV EAX,DWORD PTR [EAX]
        MOV DWORD PTR [EBP-24],EAX
        MOV EAX,DWORD PTR [EBP-24]
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
