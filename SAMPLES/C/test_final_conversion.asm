; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/test_final_conversion.c

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

; --- Fonction: test_function ---
_CCF_test_function:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,8
;   local x = [EBP-4]
        MOV DWORD PTR [EBP-4],42
;   local y = [EBP-8]
        MOV DWORD PTR [EBP-8],0
        MOV EAX,42
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,0
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
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,2
        MOV EBX,EAX
        POP EAX
        IMUL EAX,EBX
        MOV DWORD PTR [EBP-8],EAX
_CCL_2:
        MOV EAX,0
; WARNING: variable non trouvee pour stockage: i
_CCL_6:
; WARNING: variable non trouvee: i
        XOR EAX,EAX
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
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
; WARNING: variable non trouvee: i
        XOR EAX,EAX
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-8],EAX
_CCL_7:
; WARNING: variable non trouvee: i
        XOR EAX,EAX
        INC EAX
; WARNING: variable non trouvee pour stockage: i
        JMP _CCL_6
_CCL_8:
_CCL_11:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,0
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _CCL_13
        XOR EAX,EAX
        JMP _CCL_14
_CCL_13:
        MOV EAX,1
_CCL_14:
        TEST EAX,EAX
        JZ _CCL_12
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        SUB EAX,EBX
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,25
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_17
        XOR EAX,EAX
        JMP _CCL_18
_CCL_17:
        MOV EAX,1
_CCL_18:
        TEST EAX,EAX
        JZ _CCL_15
        JMP _CCL_12
_CCL_15:
        JMP _CCL_11
_CCL_12:
        MOV EAX,DWORD PTR [EBP-8]
        JMP _CCL_1
_CCL_1:
        MOV ESP,EBP
        POP EBP
        RET

END
