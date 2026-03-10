; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/for_test.c

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

; --- Fonction: test_for_basic ---
_CCF_test_for_basic:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,8
;   local i = [EBP-4]
;   local sum = [EBP-8]
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,10
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JLE _CCL_2
        XOR EAX,EAX
        JMP _CCL_3
_CCL_2:
        MOV EAX,1
_CCL_3:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
; WARNING: ponctuation inattendue: }
        XOR EAX,EAX
_CCL_1:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_for_complex ---
_CCF_test_for_complex:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,12
;   local i = [EBP-4]
;   local j = [EBP-8]
;   local result = [EBP-12]
        MOV EAX,0
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,5
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_5
        XOR EAX,EAX
        JMP _CCL_6
_CCL_5:
        MOV EAX,1
_CCL_6:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,3
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_7
        XOR EAX,EAX
        JMP _CCL_8
_CCL_7:
        MOV EAX,1
_CCL_8:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-8],EAX
; WARNING: ponctuation inattendue: }
        XOR EAX,EAX
_CCL_4:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: main ---
_CCF_main:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,8
;   local a = [EBP-4]
;   local b = [EBP-8]
        CALL _CCF_test_for_basic
        MOV DWORD PTR [EBP-4],EAX
        CALL _CCF_test_for_complex
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        JMP _CCL_9
_CCL_9:
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
