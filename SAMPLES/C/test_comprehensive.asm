; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/test_comprehensive.c

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
        SUB ESP,16
;   local a = [EBP-4]
        MOV DWORD PTR [EBP-4],10
;   local b = [EBP-8]
        MOV DWORD PTR [EBP-8],20
;   local c = [EBP-12]
        MOV DWORD PTR [EBP-12],0
;   local i = [EBP-16]
        MOV DWORD PTR [EBP-16],0
        MOV EAX,10
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,20
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        SUB EAX,EBX
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        IMUL EAX,EBX
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        CDQ
        IDIV EBX
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        CDQ
        IDIV EBX
        MOV EAX,EDX
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,2
        MOV EBX,EAX
        POP EAX
        IMUL EAX,EBX
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        PUSH EAX
        MOV EAX,3
        MOV EBX,EAX
        POP EAX
        SUB EAX,EBX
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _CCL_4
        XOR EAX,EAX
        JMP _CCL_5
_CCL_4:
        MOV EAX,1
_CCL_5:
        TEST EAX,EAX
        JZ _CCL_2
        MOV EAX,1
        MOV DWORD PTR [EBP-12],EAX
_CCL_2:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
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
        MOV EAX,2
        MOV DWORD PTR [EBP-12],EAX
_CCL_6:
        MOV EAX,0
        MOV DWORD PTR [EBP-16],EAX
_CCL_10:
        MOV EAX,DWORD PTR [EBP-16]
        PUSH EAX
        MOV EAX,5
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_12
        XOR EAX,EAX
        JMP _CCL_13
_CCL_12:
        MOV EAX,1
_CCL_13:
        TEST EAX,EAX
        JZ _CCL_11
        MOV EAX,DWORD PTR [EBP-16]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-16],EAX
        JMP _CCL_10
_CCL_11:
        MOV EAX,0
        MOV DWORD PTR [EBP-16],EAX
_CCL_14:
        MOV EAX,DWORD PTR [EBP-16]
        PUSH EAX
        MOV EAX,3
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_17
        XOR EAX,EAX
        JMP _CCL_18
_CCL_17:
        MOV EAX,1
_CCL_18:
        TEST EAX,EAX
        JZ _CCL_16
        MOV EAX,DWORD PTR [EBP-12]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-16]
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-12],EAX
_CCL_15:
        MOV EAX,DWORD PTR [EBP-16]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-16],EAX
        JMP _CCL_14
_CCL_16:
        MOV EAX,DWORD PTR [EBP-12]
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
