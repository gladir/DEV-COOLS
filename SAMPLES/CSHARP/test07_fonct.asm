; Genere par CSCW32 - Compilateur C# vers 80386 Win32
; Source : SAMPLES/CSHARP/test07_fonct.cs

.386
.MODEL FLAT, STDCALL

; Imports Win32 API (kernel32.dll)
EXTRN _ExitProcess@4:NEAR
EXTRN _GetStdHandle@4:NEAR
EXTRN _WriteFile@20:NEAR
EXTRN _ReadFile@20:NEAR
EXTRN _GetProcessHeap@0:NEAR
EXTRN _HeapAlloc@12:NEAR
EXTRN _HeapFree@12:NEAR

.CODE


; --- method Add ---
_CSCF_ADD:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+12]
        POP EBX
        ADD EAX,EBX
_CSCL_00000:
        MOV ESP,EBP
        POP EBP
        RET

; --- method Max ---
_CSCF_MAX:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+12]
        POP EBX
        CMP EBX,EAX
        SETG AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00002
        MOV EAX,DWORD PTR [EBP+8]
_CSCL_00002:
        MOV EAX,DWORD PTR [EBP+12]
_CSCL_00001:
        MOV ESP,EBP
        POP EBP
        RET

; --- method PrintLine ---
_CSCF_PRINTLINE:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        CALL _CSCRT_PRINTLN
_CSCL_00004:
        MOV ESP,EBP
        POP EBP
        RET

; --- method Main ---
_CSCF_MAIN:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV DWORD PTR [EBP-4],0
        MOV EAX,3
        PUSH EAX
        MOV EAX,7
        PUSH EAX
        CALL _CSCF_ADD
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,12
        PUSH EAX
        MOV EAX,5
        PUSH EAX
        CALL _CSCF_MAX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,2
        PUSH EAX
        MOV EAX,3
        PUSH EAX
        CALL _CSCF_ADD
        PUSH EAX
        MOV EAX,4
        PUSH EAX
        MOV EAX,6
        PUSH EAX
        CALL _CSCF_MAX
        PUSH EAX
        CALL _CSCF_MAX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,42
        PUSH EAX
        CALL _CSCF_PRINTLINE
_CSCL_00005:
        PUSH 0
        CALL _ExitProcess@4
        MOV ESP,EBP
        POP EBP
        RET
.DATA

; Constantes chaines

; Donnees statiques (DataTab)
_CSC_CRLF DB 13,10,0
_CSC_EMPTY DB 0
_CSC_INBUF DB 256 DUP(0)
_CSC_NUMBUF DB 16 DUP(0)
_CSC_HSTDOUT DD 0
_CSC_HSTDIN DD 0
_CSC_HHEAP DD 0
_CSC_WRITTEN DD 0
_CSC_READCNT DD 0


END _CSCF_MAIN
