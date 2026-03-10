; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/extern_complete_test.c

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

_CCV_internal_var  DD 10
_CCV_temporary_var  DD 0

; --- Segment de code ---
.CODE

; --- Fonction: test_function ---
_CCF_test_function:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,12
;   local local_extern_var = [EBP-4]
;   local local_extern_char = [EBP-8]
;   local local_extern_ptr = [EBP-12]
        MOV EAX,42
        MOV DWORD PTR [_global_counter],EAX
        MOV EAX,65
        MOV DWORD PTR [_status_flag],EAX
        MOV EAX,DWORD PTR [_global_counter]
        PUSH EAX
        MOV EAX,DWORD PTR [_data_buffer]
        POP DWORD PTR [EAX]
_CCL_1:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: main ---
_CCF_main:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   local main_extern_var = [EBP-4]
        MOV EAX,0
        JMP _CCL_2
_CCL_2:
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
