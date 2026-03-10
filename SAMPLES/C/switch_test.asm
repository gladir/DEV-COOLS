; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/switch_test.c

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

; --- Fonction: test_switch ---
_CCF_test_switch:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   param x = [EBP+8]
;   local result = [EBP-4]
        MOV DWORD PTR [EBP-4],0
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP+8]
        MOV ECX,EAX
; switch (valeur dans ECX)
        CMP ECX,1
        JE _CCL_3
        CMP ECX,2
        JE _CCL_4
        CMP ECX,3
        JE _CCL_5
        CMP ECX,4
        JE _CCL_6
        JMP _CCL_7
_CCL_3:
        MOV EAX,10
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_2
_CCL_4:
        MOV EAX,20
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_2
_CCL_5:
_CCL_6:
        MOV EAX,30
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_2
_CCL_7:
        MOV EAX,99
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_2
_CCL_2:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_1
_CCL_1:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: nested_switch ---
_CCF_nested_switch:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   param a = [EBP+8]
;   param b = [EBP+12]
;   local result = [EBP-4]
        MOV DWORD PTR [EBP-4],0
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP+8]
        MOV ECX,EAX
; switch (valeur dans ECX)
        CMP ECX,1
        JE _CCL_10
        CMP ECX,2
        JE _CCL_11
        JMP _CCL_12
_CCL_10:
        MOV EAX,DWORD PTR [EBP+12]
        MOV ECX,EAX
; switch (valeur dans ECX)
        CMP ECX,10
        JE _CCL_14
        CMP ECX,20
        JE _CCL_15
        JMP _CCL_16
_CCL_14:
        MOV EAX,100
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_13
_CCL_15:
        MOV EAX,200
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_13
_CCL_16:
        MOV EAX,999
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_13
_CCL_13:
        JMP _CCL_9
_CCL_11:
        MOV EAX,2000
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_9
_CCL_12:
        MOV EAX,9999
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_9
_CCL_9:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_8
_CCL_8:
        MOV ESP,EBP
        POP EBP
        RET

END
