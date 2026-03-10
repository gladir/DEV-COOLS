; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/if_final_test.c

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

_CCV_a  DD 0
_CCV_b  DD 0
_CCV_c  DD 0
_CCV_result  DD 0

; --- Segment de code ---
.CODE

; --- Fonction: main ---
_CCF_main:
        PUSH EBP
        MOV EBP,ESP
        MOV EAX,10
        MOV DWORD PTR [_CCV_a],EAX
        MOV EAX,5
        MOV DWORD PTR [_CCV_b],EAX
        MOV EAX,15
        MOV DWORD PTR [_CCV_c],EAX
        MOV EAX,DWORD PTR [_CCV_a]
        PUSH EAX
        MOV EAX,DWORD PTR [_CCV_b]
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
        MOV DWORD PTR [_CCV_result],EAX
_CCL_2:
        MOV EAX,DWORD PTR [_CCV_b]
        PUSH EAX
        MOV EAX,DWORD PTR [_CCV_c]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _CCL_8
        XOR EAX,EAX
        JMP _CCL_9
_CCL_8:
        MOV EAX,1
_CCL_9:
        TEST EAX,EAX
        JZ _CCL_6
        MOV EAX,2
        MOV DWORD PTR [_CCV_result],EAX
        JMP _CCL_7
_CCL_6:
        MOV EAX,3
        MOV DWORD PTR [_CCV_result],EAX
_CCL_7:
        MOV EAX,DWORD PTR [_CCV_a]
        PUSH EAX
        MOV EAX,DWORD PTR [_CCV_b]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _CCL_12
        XOR EAX,EAX
        JMP _CCL_13
_CCL_12:
        MOV EAX,1
_CCL_13:
        TEST EAX,EAX
        JZ _CCL_10
        MOV EAX,DWORD PTR [_CCV_c]
        PUSH EAX
        MOV EAX,DWORD PTR [_CCV_a]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _CCL_16
        XOR EAX,EAX
        JMP _CCL_17
_CCL_16:
        MOV EAX,1
_CCL_17:
        TEST EAX,EAX
        JZ _CCL_14
        MOV EAX,4
        MOV DWORD PTR [_CCV_result],EAX
        JMP _CCL_15
_CCL_14:
        MOV EAX,5
        MOV DWORD PTR [_CCV_result],EAX
_CCL_15:
_CCL_10:
        MOV EAX,DWORD PTR [_CCV_a]
        PUSH EAX
        MOV EAX,10
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_20
        XOR EAX,EAX
        JMP _CCL_21
_CCL_20:
        MOV EAX,1
_CCL_21:
        TEST EAX,EAX
        JZ _CCL_18
        MOV EAX,6
        MOV DWORD PTR [_CCV_result],EAX
_CCL_18:
        MOV EAX,DWORD PTR [_CCV_b]
        PUSH EAX
        MOV EAX,3
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JNE _CCL_24
        XOR EAX,EAX
        JMP _CCL_25
_CCL_24:
        MOV EAX,1
_CCL_25:
        TEST EAX,EAX
        JZ _CCL_22
        MOV EAX,7
        MOV DWORD PTR [_CCV_result],EAX
_CCL_22:
        MOV EAX,DWORD PTR [_CCV_c]
        PUSH EAX
        MOV EAX,15
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JGE _CCL_28
        XOR EAX,EAX
        JMP _CCL_29
_CCL_28:
        MOV EAX,1
_CCL_29:
        TEST EAX,EAX
        JZ _CCL_26
        MOV EAX,8
        MOV DWORD PTR [_CCV_result],EAX
_CCL_26:
        MOV EAX,DWORD PTR [_CCV_b]
        PUSH EAX
        MOV EAX,10
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JLE _CCL_32
        XOR EAX,EAX
        JMP _CCL_33
_CCL_32:
        MOV EAX,1
_CCL_33:
        TEST EAX,EAX
        JZ _CCL_30
        MOV EAX,9
        MOV DWORD PTR [_CCV_result],EAX
_CCL_30:
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
