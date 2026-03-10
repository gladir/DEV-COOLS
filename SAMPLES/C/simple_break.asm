; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/simple_break.c

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
        SUB ESP,4
;   local i = [EBP-4]
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
_CCL_2:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,5
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_4
        XOR EAX,EAX
        JMP _CCL_5
_CCL_4:
        MOV EAX,1
_CCL_5:
        TEST EAX,EAX
        JZ _CCL_3
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,3
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_8
        XOR EAX,EAX
        JMP _CCL_9
_CCL_8:
        MOV EAX,1
_CCL_9:
        TEST EAX,EAX
        JZ _CCL_6
        JMP _CCL_3
_CCL_6:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_2
_CCL_3:
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
