; Genere par CSCW32 - Compilateur C# vers 80386 Win32
; Source : SAMPLES/CSHARP/test13_types.cs

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
        MOV DWORD PTR [EBP-16],0
        MOV DWORD PTR [EBP-20],0
        MOV DWORD PTR [EBP-24],0
        MOV DWORD PTR [EBP-28],0
        MOV DWORD PTR [EBP-32],0
        MOV DWORD PTR [EBP-40],0
        MOV DWORD PTR [EBP-48],0
        MOV DWORD PTR [EBP-52],0
        MOV DWORD PTR [EBP-56],0
        MOV DWORD PTR [EBP-60],0
        MOV DWORD PTR [EBP-64],0
        MOV EAX,42
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,100
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,1000
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,10
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,20
        MOV DWORD PTR [EBP-20],EAX
        MOV EAX,255
        MOV DWORD PTR [EBP-24],EAX
        MOV EAX,1
        NEG EAX
        MOV DWORD PTR [EBP-28],EAX
        MOV EAX,3
        MOV DWORD PTR [EBP-32],EAX
        MOV EAX,6
        MOV DWORD PTR [EBP-40],EAX
        MOV EAX,9
        MOV DWORD PTR [EBP-48],EAX
        MOV EAX,1
        MOV DWORD PTR [EBP-52],EAX
        MOV EAX,65
        MOV DWORD PTR [EBP-56],EAX
        MOV EAX,OFFSET _CSCK_1
        MOV DWORD PTR [EBP-60],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-64],EAX
        MOV EAX,DWORD PTR [EBP-24]
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-28]
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-16]
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-20]
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,DWORD PTR [EBP-52]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,DWORD PTR [EBP-56]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,DWORD PTR [EBP-60]
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
_CSCK_1 DB "Hello Types",0

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
