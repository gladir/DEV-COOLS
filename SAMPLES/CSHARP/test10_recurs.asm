; Genere par CSCW32 - Compilateur C# vers 80386 Win32
; Source : SAMPLES/CSHARP/test10_recurs.cs

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


; --- method Fact ---
_CSCF_FACT:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,1
        POP EBX
        CMP EBX,EAX
        SETLE AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00001
        MOV EAX,1
_CSCL_00001:
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,1
        POP EBX
        SUB EBX,EAX
        MOV EAX,EBX
        PUSH EAX
        CALL _CSCF_FACT
        POP EBX
        IMUL EAX,EBX
_CSCL_00000:
        MOV ESP,EBP
        POP EBP
        RET

; --- method Main ---
_CSCF_MAIN:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV DWORD PTR [EBP-4],0
        MOV DWORD PTR [EBP-8],0
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
_CSCL_00004:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,7
        POP EBX
        CMP EBX,EAX
        SETLE AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00007
        JMP _CSCL_00006
_CSCL_00005:
        MOV EAX,DWORD PTR [EBP-4]
        INC DWORD PTR [EBP-4]
        JMP _CSCL_00004
_CSCL_00006:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        CALL _CSCF_FACT
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        JMP _CSCL_00005
_CSCL_00007:
_CSCL_00003:
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
