; Genere par CSCW32 - Compilateur C# vers 80386 Win32
; Source : SAMPLES/CSHARP/test11_literals.cs

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
        MOV EAX,100
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,50
        NEG EAX
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,255
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,1
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,65
        MOV DWORD PTR [EBP-20],EAX
        MOV EAX,OFFSET _CSCK_1
        MOV DWORD PTR [EBP-24],EAX
        MOV DWORD PTR [EBP-28],0
        MOV DWORD PTR [EBP-32],0
        MOV DWORD PTR [EBP-36],0
        MOV DWORD PTR [EBP-40],0
        MOV DWORD PTR [EBP-44],0
        MOV EAX,42
        MOV DWORD PTR [EBP-28],EAX
        MOV EAX,171
        MOV DWORD PTR [EBP-32],EAX
        MOV EAX,1
        MOV DWORD PTR [EBP-36],EAX
        MOV EAX,10
        MOV DWORD PTR [EBP-40],EAX
        MOV EAX,OFFSET _CSCK_2
        MOV DWORD PTR [EBP-44],EAX
        MOV EAX,DWORD PTR [EBP-28]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,DWORD PTR [EBP-32]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,DWORD PTR [EBP-36]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,DWORD PTR [EBP-40]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,DWORD PTR [EBP-44]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,OFFSET _CSCK_3
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,OFFSET _CSCK_4
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,3
        MOV DWORD PTR [EBP-28],EAX
        MOV EAX,DWORD PTR [EBP-28]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-4]
        POP EBX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-32],EAX
        MOV EAX,DWORD PTR [EBP-32]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,0
        MOV DWORD PTR [EBP-36],EAX
        MOV EAX,DWORD PTR [EBP-36]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,OFFSET _CSCK_5
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,0
        MOV DWORD PTR [EBP-44],EAX
        MOV EAX,OFFSET _CSCK_6
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,OFFSET _CSCK_7
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
_CSCK_1 DB "Hello",0
_CSCK_2 DB "Bonjour le monde",0
_CSCK_3 DB "Constante MAX_VAL :",0
_CSCK_4 DB "Constante MIN_VAL :",0
_CSCK_5 DB "null test",0
_CSCK_6 DB "Escaped: 	 tab 
 newline \ backslash",0
_CSCK_7 DB "Verbatim: c:\path\to\file",0

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
