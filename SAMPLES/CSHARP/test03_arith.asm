; Genere par CSCW32 - Compilateur C# vers 80386 Win32
; Source : SAMPLES/CSHARP/test03_arith.cs

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
        MOV DWORD PTR [EBP-4],0
        MOV DWORD PTR [EBP-8],0
        MOV DWORD PTR [EBP-12],0
        MOV EAX,20
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,6
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        POP EBX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-12]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        POP EBX
        SUB EBX,EAX
        MOV EAX,EBX
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-12]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        POP EBX
        IMUL EAX,EBX
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-12]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        POP EBX
        MOV ECX,EAX
        MOV EAX,EBX
        CDQ
        IDIV ECX
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-12]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        POP EBX
        MOV ECX,EAX
        MOV EAX,EBX
        CDQ
        IDIV ECX
        MOV EAX,EDX
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-12]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,4
        MOV EBX,EAX
        MOV EAX,DWORD PTR [EBP-4]
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,2
        MOV EBX,EAX
        MOV EAX,DWORD PTR [EBP-4]
        SUB EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,3
        MOV EBX,EAX
        MOV EAX,DWORD PTR [EBP-4]
        IMUL EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,2
        MOV ECX,EAX
        MOV EAX,DWORD PTR [EBP-4]
        CDQ
        IDIV ECX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,DWORD PTR [EBP-4]
        INC DWORD PTR [EBP-4]
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,DWORD PTR [EBP-8]
        DEC DWORD PTR [EBP-8]
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        CALL _CSCRT_PRINTLN
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
