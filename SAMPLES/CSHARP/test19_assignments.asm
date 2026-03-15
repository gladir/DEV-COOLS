; Genere par CSCW32 - Compilateur C# vers 80386 Win32
; Source : SAMPLES/CSHARP/test19_assignments.cs

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


; --- method TestSimple ---
_CSCF_TESTSIMPLE:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV DWORD PTR [EBP-4],0
        MOV DWORD PTR [EBP-8],0
        MOV DWORD PTR [EBP-12],0
        MOV EAX,10
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,20
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,DWORD PTR [EBP-4]
        MOV DWORD PTR [EBP-12],EAX
_CSCL_00000:
        MOV ESP,EBP
        POP EBP
        RET

; --- method TestExpr ---
_CSCF_TESTEXPR:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,5
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,3
        MOV DWORD PTR [EBP-8],EAX
        MOV DWORD PTR [EBP-12],0
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        POP EBX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        POP EBX
        IMUL EAX,EBX
        PUSH EAX
        MOV EAX,1
        POP EBX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        POP EBX
        ADD EAX,EBX
        PUSH EAX
        MOV EAX,2
        POP EBX
        IMUL EAX,EBX
        MOV DWORD PTR [EBP-12],EAX
_CSCL_00001:
        MOV ESP,EBP
        POP EBP
        RET

; --- method TestCompound ---
_CSCF_TESTCOMPOUND:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,10
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,5
        MOV EBX,EAX
        MOV EAX,DWORD PTR [EBP-4]
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,3
        MOV EBX,EAX
        MOV EAX,DWORD PTR [EBP-4]
        SUB EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,2
        MOV EBX,EAX
        MOV EAX,DWORD PTR [EBP-4]
        IMUL EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,4
        MOV ECX,EAX
        MOV EAX,DWORD PTR [EBP-4]
        CDQ
        IDIV ECX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,5
        MOV ECX,EAX
        MOV EAX,DWORD PTR [EBP-4]
        CDQ
        IDIV ECX
        MOV DWORD PTR [EBP-4],EDX
        MOV EAX,EDX
_CSCL_00002:
        MOV ESP,EBP
        POP EBP
        RET

; --- method TestBitCompound ---
_CSCF_TESTBITCOMPOUND:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,1
        OR DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        MOV EAX,4
        OR DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        MOV EAX,5
        AND DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        MOV EAX,1
        XOR DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
_CSCL_00003:
        MOV ESP,EBP
        POP EBP
        RET

; --- method TestShiftCompound ---
_CSCF_TESTSHIFTCOMPOUND:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,1
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,4
        MOV ECX,EAX
        SHL DWORD PTR [EBP-4],CL
        MOV EAX,DWORD PTR [EBP-4]
        MOV EAX,2
        MOV ECX,EAX
        SHR DWORD PTR [EBP-4],CL
        MOV EAX,DWORD PTR [EBP-4]
_CSCL_00004:
        MOV ESP,EBP
        POP EBP
        RET

; --- method TestPostIncDec ---
_CSCF_TESTPOSTINCDEC:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        INC DWORD PTR [EBP-4]
        MOV EAX,DWORD PTR [EBP-4]
        INC DWORD PTR [EBP-4]
        MOV EAX,DWORD PTR [EBP-4]
        DEC DWORD PTR [EBP-4]
_CSCL_00005:
        MOV ESP,EBP
        POP EBP
        RET

; --- method TestPreIncDec ---
_CSCF_TESTPREINCDEC:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,10
        MOV DWORD PTR [EBP-4],EAX
        INC DWORD PTR [EBP-4]
        MOV EAX,DWORD PTR [EBP-4]
        DEC DWORD PTR [EBP-4]
        MOV EAX,DWORD PTR [EBP-4]
_CSCL_00006:
        MOV ESP,EBP
        POP EBP
        RET

; --- method TestMethodCall ---
_CSCF_TESTMETHODCALL:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,42
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        CALL _CSCRT_PRINTLN
_CSCL_00007:
        MOV ESP,EBP
        POP EBP
        RET

; --- method TestString ---
_CSCF_TESTSTRING:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV DWORD PTR [EBP-4],0
        MOV EAX,OFFSET _CSCK_1
        MOV DWORD PTR [EBP-4],EAX
_CSCL_00008:
        MOV ESP,EBP
        POP EBP
        RET

; --- method TestMultiple ---
_CSCF_TESTMULTIPLE:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,1
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,2
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,3
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-12]
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,DWORD PTR [EBP-4]
        MOV DWORD PTR [EBP-12],EAX
_CSCL_00009:
        MOV ESP,EBP
        POP EBP
        RET

; --- method TestExprStmt ---
_CSCF_TESTEXPRSTMT:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,5
        MOV DWORD PTR [EBP-4],EAX
_CSCL_00010:
        MOV ESP,EBP
        POP EBP
        RET

; --- method GetValue ---
_CSCF_GETVALUE:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,42
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
_CSCL_00011:
        MOV ESP,EBP
        POP EBP
        RET

; --- method TestBlock ---
_CSCF_TESTBLOCK:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,1
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,2
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV DWORD PTR [EBP-4],EAX
_CSCL_00012:
        MOV ESP,EBP
        POP EBP
        RET

; --- method Main ---
_CSCF_MAIN:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        CALL _CSCF_TESTSIMPLE
        CALL _CSCF_TESTEXPR
        CALL _CSCF_TESTCOMPOUND
        CALL _CSCF_TESTBITCOMPOUND
        CALL _CSCF_TESTSHIFTCOMPOUND
        CALL _CSCF_TESTPOSTINCDEC
        CALL _CSCF_TESTPREINCDEC
        CALL _CSCF_TESTMETHODCALL
        CALL _CSCF_TESTSTRING
        CALL _CSCF_TESTMULTIPLE
        CALL _CSCF_TESTBLOCK
_CSCL_00013:
        PUSH 0
        CALL _ExitProcess@4
        MOV ESP,EBP
        POP EBP
        RET
.DATA

; Constantes chaines
_CSCK_1 DB "hello",0

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
