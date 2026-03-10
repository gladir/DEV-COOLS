; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/test_pointers.c

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

_CCV_g_val  DD 0
_CCV_g_ptr  DD 0

; --- Segment de code ---
.CODE

; --- Fonction: add_one ---
_CCF_add_one:
        PUSH EBP
        MOV EBP,ESP
;   param x = [EBP+8]
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        JMP _CCL_1
_CCL_1:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: double_val ---
_CCF_double_val:
        PUSH EBP
        MOV EBP,ESP
;   param x = [EBP+8]
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,2
        MOV EBX,EAX
        POP EAX
        IMUL EAX,EBX
        JMP _CCL_2
_CCL_2:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: main ---
_CCF_main:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,28
;   local a = [EBP-4]
        MOV DWORD PTR [EBP-4],42
;   local b = [EBP-8]
        MOV DWORD PTR [EBP-8],0
;   local p = [EBP-12]
;   local q = [EBP-16]
;   local pp = [EBP-20]
;   local vp = [EBP-24]
;   local fp = [EBP-28]
        MOV EAX,42
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
        LEA EAX,[EBP-4]
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-12]
        MOV EAX,DWORD PTR [EAX]
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,100
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-12]
        POP DWORD PTR [EAX]
        MOV EAX,0
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,55
        MOV DWORD PTR [_CCV_g_val],EAX
        MOV EAX,OFFSET _CCV_g_val
        MOV DWORD PTR [_CCV_g_ptr],EAX
        MOV EAX,DWORD PTR [_CCV_g_ptr]
        MOV EAX,DWORD PTR [EAX]
        MOV DWORD PTR [EBP-8],EAX
        LEA EAX,[EBP-4]
        MOV DWORD PTR [EBP-24],EAX
        LEA EAX,[EBP-12]
        MOV DWORD PTR [EBP-20],EAX
        MOV EAX,DWORD PTR [EBP-12]
        PUSH EAX
        LEA EAX,[EBP-4]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_6
        XOR EAX,EAX
        JMP _CCL_7
_CCL_6:
        MOV EAX,1
_CCL_7:
        TEST EAX,EAX
        JZ _CCL_4
        MOV EAX,1
        MOV DWORD PTR [EBP-8],EAX
_CCL_4:
        MOV EAX,DWORD PTR [EBP-16]
        PUSH EAX
        MOV EAX,0
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_10
        XOR EAX,EAX
        JMP _CCL_11
_CCL_10:
        MOV EAX,1
_CCL_11:
        TEST EAX,EAX
        JZ _CCL_8
        MOV EAX,2
        MOV DWORD PTR [EBP-8],EAX
_CCL_8:
        MOV EAX,DWORD PTR [EBP-12]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-16]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JNE _CCL_14
        XOR EAX,EAX
        JMP _CCL_15
_CCL_14:
        MOV EAX,1
_CCL_15:
        TEST EAX,EAX
        JZ _CCL_12
        MOV EAX,3
        MOV DWORD PTR [EBP-8],EAX
_CCL_12:
        LEA EAX,[EBP-4]
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-12]
        ADD EAX,4
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-12]
        SUB EAX,4
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-12]
        ADD EAX,4
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-12]
        SUB EAX,4
        MOV DWORD PTR [EBP-12],EAX
        LEA EAX,[EBP-4]
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,50
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-12]
        POP DWORD PTR [EAX]
        MOV EAX,10
        MOV EBX,EAX
        MOV EAX,DWORD PTR [EBP-12]
        PUSH EAX
        MOV EAX,DWORD PTR [EAX]
        ADD EAX,EBX
        POP ECX
        MOV DWORD PTR [ECX],EAX
        MOV EAX,OFFSET _CCF_add_one
        MOV DWORD PTR [EBP-28],EAX
        MOV EAX,10
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-28]
        CALL EAX
        ADD ESP,4
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,OFFSET _CCF_double_val
        MOV DWORD PTR [EBP-28],EAX
        MOV EAX,5
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-28]
        CALL EAX
        ADD ESP,4
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,0
        JMP _CCL_3
_CCL_3:
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
