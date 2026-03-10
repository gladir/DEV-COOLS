; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/test_arrays.c

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

_CCV_g_arr  DB 20 DUP(0)

; --- Segment de code ---
.CODE

; --- Fonction: sum_array ---
_CCF_sum_array:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,8
;   param arr = [EBP+8]
;   param n = [EBP+12]
;   local total = [EBP-4]
        MOV DWORD PTR [EBP-4],0
;   local i = [EBP-8]
        MOV DWORD PTR [EBP-8],0
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
_CCL_2:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+12]
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
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        SHL EAX,2
        POP EBX
        ADD EAX,EBX
        MOV EAX,DWORD PTR [EAX]
        MOV EBX,EAX
        MOV EAX,DWORD PTR [EBP-4]
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-8]
        INC EAX
        MOV DWORD PTR [EBP-8],EAX
        JMP _CCL_2
_CCL_3:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_1
_CCL_1:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: main ---
_CCF_main:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,28
;   local arr = [EBP-20]
;   local i = [EBP-24]
;   local result = [EBP-28]
        MOV EAX,0
        SHL EAX,2
        PUSH EAX
        LEA EAX,[EBP-20]
        POP EBX
        ADD EAX,EBX
        PUSH EAX
        MOV EAX,10
        POP ECX
        MOV DWORD PTR [ECX],EAX
        MOV EAX,1
        SHL EAX,2
        PUSH EAX
        LEA EAX,[EBP-20]
        POP EBX
        ADD EAX,EBX
        PUSH EAX
        MOV EAX,20
        POP ECX
        MOV DWORD PTR [ECX],EAX
        MOV EAX,2
        SHL EAX,2
        PUSH EAX
        LEA EAX,[EBP-20]
        POP EBX
        ADD EAX,EBX
        PUSH EAX
        MOV EAX,30
        POP ECX
        MOV DWORD PTR [ECX],EAX
        MOV EAX,3
        SHL EAX,2
        PUSH EAX
        LEA EAX,[EBP-20]
        POP EBX
        ADD EAX,EBX
        PUSH EAX
        MOV EAX,40
        POP ECX
        MOV DWORD PTR [ECX],EAX
        MOV EAX,4
        SHL EAX,2
        PUSH EAX
        LEA EAX,[EBP-20]
        POP EBX
        ADD EAX,EBX
        PUSH EAX
        MOV EAX,50
        POP ECX
        MOV DWORD PTR [ECX],EAX
        LEA EAX,[EBP-20]
        PUSH EAX
        MOV EAX,2
        SHL EAX,2
        POP EBX
        ADD EAX,EBX
        MOV EAX,DWORD PTR [EAX]
        MOV DWORD PTR [EBP-28],EAX
        MOV EAX,3
        MOV DWORD PTR [EBP-24],EAX
        LEA EAX,[EBP-20]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-24]
        SHL EAX,2
        POP EBX
        ADD EAX,EBX
        MOV EAX,DWORD PTR [EAX]
        MOV DWORD PTR [EBP-28],EAX
        MOV EAX,0
        SHL EAX,2
        PUSH EAX
        LEA EAX,[EBP-20]
        POP EBX
        ADD EAX,EBX
        PUSH EAX
        POP ECX
        PUSH ECX
        MOV EAX,DWORD PTR [ECX]
        PUSH EAX
        MOV EAX,5
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        POP ECX
        MOV DWORD PTR [ECX],EAX
        MOV EAX,1
        SHL EAX,2
        PUSH EAX
        LEA EAX,[EBP-20]
        POP EBX
        ADD EAX,EBX
        PUSH EAX
        POP ECX
        PUSH ECX
        MOV EAX,DWORD PTR [ECX]
        PUSH EAX
        MOV EAX,10
        MOV EBX,EAX
        POP EAX
        SUB EAX,EBX
        POP ECX
        MOV DWORD PTR [ECX],EAX
        MOV EAX,0
        SHL EAX,2
        PUSH EAX
        MOV EAX,DWORD PTR [_CCV_g_arr]
        POP EBX
        ADD EAX,EBX
        PUSH EAX
        MOV EAX,100
        POP ECX
        MOV DWORD PTR [ECX],EAX
        MOV EAX,1
        SHL EAX,2
        PUSH EAX
        MOV EAX,DWORD PTR [_CCV_g_arr]
        POP EBX
        ADD EAX,EBX
        PUSH EAX
        MOV EAX,200
        POP ECX
        MOV DWORD PTR [ECX],EAX
        MOV EAX,DWORD PTR [_CCV_g_arr]
        PUSH EAX
        MOV EAX,0
        SHL EAX,2
        POP EBX
        ADD EAX,EBX
        MOV EAX,DWORD PTR [EAX]
        MOV DWORD PTR [EBP-28],EAX
        MOV EAX,5
        PUSH EAX
        LEA EAX,[EBP-20]
        PUSH EAX
        CALL _CCF_sum_array
        ADD ESP,8
        MOV DWORD PTR [EBP-28],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-24],EAX
_CCL_7:
        MOV EAX,DWORD PTR [EBP-24]
        PUSH EAX
        MOV EAX,5
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_9
        XOR EAX,EAX
        JMP _CCL_10
_CCL_9:
        MOV EAX,1
_CCL_10:
        TEST EAX,EAX
        JZ _CCL_8
        MOV EAX,DWORD PTR [EBP-24]
        SHL EAX,2
        PUSH EAX
        LEA EAX,[EBP-20]
        POP EBX
        ADD EAX,EBX
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-24]
        PUSH EAX
        MOV EAX,10
        MOV EBX,EAX
        POP EAX
        IMUL EAX,EBX
        POP ECX
        MOV DWORD PTR [ECX],EAX
        MOV EAX,DWORD PTR [EBP-24]
        INC EAX
        MOV DWORD PTR [EBP-24],EAX
        JMP _CCL_7
_CCL_8:
        MOV EAX,0
        MOV DWORD PTR [EBP-24],EAX
_CCL_11:
        MOV EAX,DWORD PTR [EBP-24]
        PUSH EAX
        MOV EAX,5
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_14
        XOR EAX,EAX
        JMP _CCL_15
_CCL_14:
        MOV EAX,1
_CCL_15:
        TEST EAX,EAX
        JZ _CCL_13
        MOV EAX,DWORD PTR [EBP-24]
        SHL EAX,2
        PUSH EAX
        LEA EAX,[EBP-20]
        POP EBX
        ADD EAX,EBX
        PUSH EAX
        POP ECX
        PUSH ECX
        MOV EAX,DWORD PTR [ECX]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        POP ECX
        MOV DWORD PTR [ECX],EAX
_CCL_12:
        MOV EAX,DWORD PTR [EBP-24]
        INC EAX
        MOV DWORD PTR [EBP-24],EAX
        JMP _CCL_11
_CCL_13:
        LEA EAX,[EBP-20]
        PUSH EAX
        MOV EAX,0
        SHL EAX,2
        POP EBX
        ADD EAX,EBX
        MOV EAX,DWORD PTR [EAX]
        PUSH EAX
        LEA EAX,[EBP-20]
        PUSH EAX
        MOV EAX,1
        SHL EAX,2
        POP EBX
        ADD EAX,EBX
        MOV EAX,DWORD PTR [EAX]
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        PUSH EAX
        LEA EAX,[EBP-20]
        PUSH EAX
        MOV EAX,2
        SHL EAX,2
        POP EBX
        ADD EAX,EBX
        MOV EAX,DWORD PTR [EAX]
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-28],EAX
        MOV EAX,0
        JMP _CCL_6
_CCL_6:
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
