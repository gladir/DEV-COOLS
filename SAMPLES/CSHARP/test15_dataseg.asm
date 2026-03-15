; Genere par CSCW32 - Compilateur C# vers 80386 Win32
; Source : SAMPLES/CSHARP/test15_dataseg.cs

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
        MOV EAX,OFFSET _CSCK_1
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,OFFSET _CSCK_2
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,OFFSET _CSCK_3
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,OFFSET _CSCK_4
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,OFFSET _CSCK_5
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,OFFSET _CSCK_6
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,10
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,20
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,1
        MOV DWORD PTR [EBP-12],EAX
_CSCL_00000:
        PUSH 0
        CALL _ExitProcess@4
        MOV ESP,EBP
        POP EBP
        RET
.DATA

; Constantes chaines
_CSCK_1 DB "Data segment test",0
_CSCK_2 DB "Hello World",0
_CSCK_3 DB "Testing static vars",0
_CSCK_4 DB "Counter value",0
_CSCK_5 DB "Flag status",0
_CSCK_6 DB "Done",0

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
_CSCST_2 DB 0
_CSCST_3 DD 0
_CSCST_4 DD 0
_CSCST_5 DB 0


END _CSCF_MAIN
