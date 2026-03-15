; Genere par CSCW32 - Compilateur C# vers 80386 Win32
; Source : SAMPLES/CSHARP/test09_array.cs

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


; --- method Main ---
_CSCF_MAIN:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,5
        SHL EAX,2
        PUSH EAX
        PUSH 0
        CALL _GetProcessHeap@0
        PUSH EAX
        CALL _HeapAlloc@12
        MOV DWORD PTR [EBP-4],EAX
        MOV DWORD PTR [EBP-8],0
        MOV DWORD PTR [EBP-12],0
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,0
        SHL EAX,2
        POP EBX
        ADD EBX,EAX
        PUSH EAX
        PUSH EBX
        MOV EAX,10
        POP EBX
        MOV DWORD PTR [EBX],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        SHL EAX,2
        POP EBX
        ADD EBX,EAX
        PUSH EAX
        PUSH EBX
        MOV EAX,20
        POP EBX
        MOV DWORD PTR [EBX],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,2
        SHL EAX,2
        POP EBX
        ADD EBX,EAX
        PUSH EAX
        PUSH EBX
        MOV EAX,30
        POP EBX
        MOV DWORD PTR [EBX],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,3
        SHL EAX,2
        POP EBX
        ADD EBX,EAX
        PUSH EAX
        PUSH EBX
        MOV EAX,40
        POP EBX
        MOV DWORD PTR [EBX],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,4
        SHL EAX,2
        POP EBX
        ADD EBX,EAX
        PUSH EAX
        PUSH EBX
        MOV EAX,50
        POP EBX
        MOV DWORD PTR [EBX],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
_CSCL_00001:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,5
        POP EBX
        CMP EBX,EAX
        SETL AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00004
        JMP _CSCL_00003
_CSCL_00002:
        MOV EAX,DWORD PTR [EBP-8]
        INC DWORD PTR [EBP-8]
        JMP _CSCL_00001
_CSCL_00003:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        SHL EAX,2
        POP EBX
        ADD EAX,EBX
        MOV EAX,DWORD PTR [EAX]
        MOV EBX,EAX
        MOV EAX,DWORD PTR [EBP-12]
        ADD EAX,EBX
        MOV DWORD PTR [EBP-12],EAX
        JMP _CSCL_00002
_CSCL_00004:
        MOV EAX,DWORD PTR [EBP-12]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
_CSCL_00005:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,5
        POP EBX
        CMP EBX,EAX
        SETL AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00008
        JMP _CSCL_00007
_CSCL_00006:
        MOV EAX,DWORD PTR [EBP-8]
        INC DWORD PTR [EBP-8]
        JMP _CSCL_00005
_CSCL_00007:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        SHL EAX,2
        POP EBX
        ADD EAX,EBX
        MOV EAX,DWORD PTR [EAX]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        JMP _CSCL_00006
_CSCL_00008:
_CSCL_00000:
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
