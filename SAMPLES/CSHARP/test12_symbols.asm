; Genere par CSCW32 - Compilateur C# vers 80386 Win32
; Source : SAMPLES/CSHARP/test12_symbols.cs

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
        MOV DWORD PTR [EBP-4],0
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+12]
        POP EBX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
_CSCL_00000:
        MOV ESP,EBP
        POP EBP
        RET

; --- method Subtract ---
_CSCF_SUBTRACT:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+12]
        POP EBX
        SUB EBX,EAX
        MOV EAX,EBX
_CSCL_00001:
        MOV ESP,EBP
        POP EBP
        RET

; --- method IsPositive ---
_CSCF_ISPOSITIVE:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,0
        POP EBX
        CMP EBX,EAX
        SETG AL
        MOVZX EAX,AL
_CSCL_00002:
        MOV ESP,EBP
        POP EBP
        RET

; --- method PrintResult ---
_CSCF_PRINTRESULT:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        CALL _CSCRT_PRINT
        MOV EAX,OFFSET _CSCK_1
        PUSH EAX
        CALL _CSCRT_PRINT
        MOV EAX,DWORD PTR [EBP+12]
        PUSH EAX
        CALL _CSCRT_PRINTLN
_CSCL_00003:
        MOV ESP,EBP
        POP EBP
        RET

; --- method Main ---
_CSCF_MAIN:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,100
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,OFFSET _CSCK_2
        MOV DWORD PTR [EBP-8],EAX
        MOV DWORD PTR [EBP-12],0
        MOV DWORD PTR [EBP-16],0
        MOV DWORD PTR [EBP-20],0
        MOV DWORD PTR [EBP-24],0
        MOV DWORD PTR [EBP-28],0
        MOV EAX,42
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,58
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,DWORD PTR [EBP-12]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-16]
        PUSH EAX
        CALL _CSCF_ADD
        MOV DWORD PTR [EBP-20],EAX
        MOV EAX,DWORD PTR [EBP-20]
        PUSH EAX
        CALL _CSCF_ISPOSITIVE
        MOV DWORD PTR [EBP-24],EAX
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,OFFSET _CSCK_3
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-20]
        PUSH EAX
        CALL _CSCF_PRINTRESULT
        MOV EAX,OFFSET _CSCK_4
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-12]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-16]
        PUSH EAX
        CALL _CSCF_SUBTRACT
        PUSH EAX
        CALL _CSCF_PRINTRESULT
        MOV EAX,DWORD PTR [EBP-24]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,OFFSET _CSCK_5
        MOV DWORD PTR [EBP-28],EAX
        MOV EAX,DWORD PTR [EBP-28]
        PUSH EAX
        CALL _CSCRT_PRINTLN
_CSCL_00004:
        PUSH 0
        CALL _ExitProcess@4
        MOV ESP,EBP
        POP EBP
        RET
.DATA

; Constantes chaines
_CSCK_1 DB ": ",0
_CSCK_2 DB "Calculator Test",0
_CSCK_3 DB "Sum",0
_CSCK_4 DB "Diff",0
_CSCK_5 DB "Done",0

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
