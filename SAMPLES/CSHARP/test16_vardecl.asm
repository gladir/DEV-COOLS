; Genere par CSCW32 - Compilateur C# vers 80386 Win32
; Source : SAMPLES/CSHARP/test16_vardecl.cs

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
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP+8]
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
_CSCL_00000:
        MOV ESP,EBP
        POP EBP
        RET

; --- method Display ---
_CSCF_DISPLAY:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV DWORD PTR [EBP-4],0
        MOV DWORD PTR [EBP-8],0
        MOV DWORD PTR [EBP-12],0
        MOV EAX,1
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,65
        MOV DWORD PTR [EBP-20],EAX
        MOV EAX,OFFSET _CSCK_2
        MOV DWORD PTR [EBP-24],EAX
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        CALL _CSCRT_PRINTLN
_CSCL_00001:
        MOV ESP,EBP
        POP EBP
        RET

; --- method TypeTest ---
_CSCF_TYPETEST:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,10
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,20
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,30
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,40
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,50
        MOV DWORD PTR [EBP-20],EAX
        MOV EAX,1
        NEG EAX
        MOV DWORD PTR [EBP-24],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-28],EAX
        MOV EAX,88
        MOV DWORD PTR [EBP-32],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-40],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-44],EAX
        MOV EAX,OFFSET _CSCK_3
        MOV DWORD PTR [EBP-48],EAX
        MOV EAX,42
        NEG EAX
        MOV DWORD PTR [EBP-52],EAX
_CSCL_00002:
        MOV ESP,EBP
        POP EBP
        RET

; --- method Main ---
_CSCF_MAIN:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,10
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,20
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,1
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,65
        MOV DWORD PTR [EBP-20],EAX
        MOV EAX,OFFSET _CSCK_4
        MOV DWORD PTR [EBP-24],EAX
        MOV DWORD PTR [EBP-28],0
        MOV DWORD PTR [EBP-32],0
        MOV EAX,0
        MOV DWORD PTR [EBP-36],EAX
        MOV DWORD PTR [EBP-40],0
        MOV EAX,OFFSET _CSCK_5
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,DWORD PTR [EBP-24]
        PUSH EAX
        CALL _CSCRT_PRINTLN
_CSCL_00003:
        PUSH 0
        CALL _ExitProcess@4
        MOV ESP,EBP
        POP EBP
        RET
.DATA

; Constantes chaines
_CSCK_1 DB "hello",0
_CSCK_2 DB "value",0
_CSCK_3 DB "test",0
_CSCK_4 DB "world",0
_CSCK_5 DB "Variable declarations test",0

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
_CSCST_1 DD 0
_CSCST_2 DB 1
_CSCST_3 DD 0
_CSCST_4 DD 0
_CSCST_5 DB 59


END _CSCF_MAIN
