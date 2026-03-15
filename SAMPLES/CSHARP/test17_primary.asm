; Genere par CSCW32 - Compilateur C# vers 80386 Win32
; Source : SAMPLES/CSHARP/test17_primary.cs

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


; --- method Square ---
_CSCF_SQUARE:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,DWORD PTR [EBP+8]
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
_CSCL_00000:
        MOV ESP,EBP
        POP EBP
        RET

; --- method GetValue ---
_CSCF_GETVALUE:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,42
_CSCL_00001:
        MOV ESP,EBP
        POP EBP
        RET

; --- method ShowInt ---
_CSCF_SHOWINT:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        CALL _CSCRT_PRINTLN
_CSCL_00002:
        MOV ESP,EBP
        POP EBP
        RET

; --- method TestLiterals ---
_CSCF_TESTLITERALS:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,10
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,255
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,OFFSET _CSCK_2
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,65
        MOV DWORD PTR [EBP-20],EAX
        MOV EAX,1
        MOV DWORD PTR [EBP-24],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-28],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-32],EAX
        MOV EAX,42
        NEG EAX
        MOV DWORD PTR [EBP-36],EAX
        MOV EAX,DWORD PTR [EBP-16]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        CALL _CSCRT_PRINTLN
_CSCL_00003:
        MOV ESP,EBP
        POP EBP
        RET

; --- method TestAccess ---
_CSCF_TESTACCESS:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,10
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,20
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,DWORD PTR [EBP-4]
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        CALL _CSCF_SQUARE
        MOV DWORD PTR [EBP-16],EAX
        CALL _CSCF_GETVALUE
        MOV DWORD PTR [EBP-20],EAX
        MOV EAX,OFFSET _CSCK_3
        PUSH EAX
        CALL _CSCRT_PRINT
        MOV EAX,DWORD PTR [EBP-12]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,DWORD PTR [EBP-4]
        MOV DWORD PTR [EBP-24],EAX
        MOV EAX,DWORD PTR [_CSCST_COUNTER]
        MOV DWORD PTR [EBP-28],EAX
_CSCL_00004:
        MOV ESP,EBP
        POP EBP
        RET

; --- method TestUnary ---
_CSCF_TESTUNARY:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,10
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
        INC DWORD PTR [EBP-4]
        MOV EAX,DWORD PTR [EBP-4]
        DEC DWORD PTR [EBP-4]
        MOV EAX,DWORD PTR [EBP-4]
        MOV EAX,DWORD PTR [EBP-4]
        INC DWORD PTR [EBP-4]
        MOV EAX,DWORD PTR [EBP-4]
        DEC DWORD PTR [EBP-4]
        MOV EAX,DWORD PTR [_CSCST_FLAG]
        TEST EAX,EAX
        SETZ AL
        MOVZX EAX,AL
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        CALL _CSCRT_PRINTLN
_CSCL_00005:
        MOV ESP,EBP
        POP EBP
        RET

; --- method Main ---
_CSCF_MAIN:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        CALL _CSCF_TESTLITERALS
        CALL _CSCF_TESTACCESS
        CALL _CSCF_TESTUNARY
        MOV EAX,OFFSET _CSCK_4
        PUSH EAX
        CALL _CSCRT_PRINTLN
_CSCL_00006:
        PUSH 0
        CALL _ExitProcess@4
        MOV ESP,EBP
        POP EBP
        RET
.DATA

; Constantes chaines
_CSCK_1 DB "test",0
_CSCK_2 DB "hello world",0
_CSCK_3 DB "result: ",0
_CSCK_4 DB "Primary expressions test OK",0

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


END _CSCF_MAIN
