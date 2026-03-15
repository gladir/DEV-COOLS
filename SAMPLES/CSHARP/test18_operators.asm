; Genere par CSCW32 - Compilateur C# vers 80386 Win32
; Source : SAMPLES/CSHARP/test18_operators.cs

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


; --- method TestArith ---
_CSCF_TESTARITH:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,10
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
        SUB EBX,EAX
        MOV EAX,EBX
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        POP EBX
        IMUL EAX,EBX
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        POP EBX
        MOV ECX,EAX
        MOV EAX,EBX
        CDQ
        IDIV ECX
        MOV DWORD PTR [EBP-12],EAX
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
        MOV EAX,2
        PUSH EAX
        MOV EAX,3
        PUSH EAX
        MOV EAX,4
        POP EBX
        IMUL EAX,EBX
        POP EBX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,2
        PUSH EAX
        MOV EAX,3
        POP EBX
        ADD EAX,EBX
        PUSH EAX
        MOV EAX,4
        POP EBX
        IMUL EAX,EBX
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,100
        PUSH EAX
        MOV EAX,10
        POP EBX
        MOV ECX,EAX
        MOV EAX,EBX
        CDQ
        IDIV ECX
        PUSH EAX
        MOV EAX,2
        POP EBX
        MOV ECX,EAX
        MOV EAX,EBX
        CDQ
        IDIV ECX
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,10
        PUSH EAX
        MOV EAX,3
        POP EBX
        SUB EBX,EAX
        MOV EAX,EBX
        PUSH EAX
        MOV EAX,2
        POP EBX
        SUB EBX,EAX
        MOV EAX,EBX
        MOV DWORD PTR [EBP-12],EAX
_CSCL_00000:
        MOV ESP,EBP
        POP EBP
        RET

; --- method TestCompare ---
_CSCF_TESTCOMPARE:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,5
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,10
        MOV DWORD PTR [EBP-8],EAX
        MOV DWORD PTR [EBP-12],0
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,5
        POP EBX
        CMP EBX,EAX
        SETE AL
        MOVZX EAX,AL
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        POP EBX
        CMP EBX,EAX
        SETNE AL
        MOVZX EAX,AL
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        POP EBX
        CMP EBX,EAX
        SETL AL
        MOVZX EAX,AL
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,5
        POP EBX
        CMP EBX,EAX
        SETLE AL
        MOVZX EAX,AL
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-4]
        POP EBX
        CMP EBX,EAX
        SETG AL
        MOVZX EAX,AL
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,10
        POP EBX
        CMP EBX,EAX
        SETGE AL
        MOVZX EAX,AL
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        POP EBX
        CMP EBX,EAX
        SETE AL
        MOVZX EAX,AL
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        POP EBX
        CMP EBX,EAX
        SETG AL
        MOVZX EAX,AL
        MOV DWORD PTR [EBP-12],EAX
_CSCL_00001:
        MOV ESP,EBP
        POP EBP
        RET

; --- method TestLogic ---
_CSCF_TESTLOGIC:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,1
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
        MOV DWORD PTR [EBP-12],0
        MOV EAX,DWORD PTR [EBP-4]
        TEST EAX,EAX
        JZ _CSCL_00003
        MOV EAX,DWORD PTR [EBP-4]
        TEST EAX,EAX
        JZ _CSCL_00003
        MOV EAX,1
        JMP _CSCL_00004
_CSCL_00003:
        XOR EAX,EAX
_CSCL_00004:
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        TEST EAX,EAX
        JZ _CSCL_00005
        MOV EAX,DWORD PTR [EBP-8]
        TEST EAX,EAX
        JZ _CSCL_00005
        MOV EAX,1
        JMP _CSCL_00006
_CSCL_00005:
        XOR EAX,EAX
_CSCL_00006:
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-8]
        TEST EAX,EAX
        JZ _CSCL_00007
        MOV EAX,DWORD PTR [EBP-4]
        TEST EAX,EAX
        JZ _CSCL_00007
        MOV EAX,1
        JMP _CSCL_00008
_CSCL_00007:
        XOR EAX,EAX
_CSCL_00008:
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        TEST EAX,EAX
        JNZ _CSCL_00009
        MOV EAX,DWORD PTR [EBP-8]
        TEST EAX,EAX
        JNZ _CSCL_00009
        XOR EAX,EAX
        JMP _CSCL_00010
_CSCL_00009:
        MOV EAX,1
_CSCL_00010:
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-8]
        TEST EAX,EAX
        JNZ _CSCL_00011
        MOV EAX,DWORD PTR [EBP-4]
        TEST EAX,EAX
        JNZ _CSCL_00011
        XOR EAX,EAX
        JMP _CSCL_00012
_CSCL_00011:
        MOV EAX,1
_CSCL_00012:
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-8]
        TEST EAX,EAX
        JNZ _CSCL_00013
        MOV EAX,DWORD PTR [EBP-8]
        TEST EAX,EAX
        JNZ _CSCL_00013
        XOR EAX,EAX
        JMP _CSCL_00014
_CSCL_00013:
        MOV EAX,1
_CSCL_00014:
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        TEST EAX,EAX
        SETZ AL
        MOVZX EAX,AL
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-8]
        TEST EAX,EAX
        SETZ AL
        MOVZX EAX,AL
        MOV DWORD PTR [EBP-12],EAX
_CSCL_00002:
        MOV ESP,EBP
        POP EBP
        RET

; --- method TestBitwise ---
_CSCF_TESTBITWISE:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,255
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,15
        MOV DWORD PTR [EBP-8],EAX
        MOV DWORD PTR [EBP-12],0
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        POP EBX
        AND EAX,EBX
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        POP EBX
        OR EAX,EBX
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        POP EBX
        XOR EAX,EBX
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,0
        NOT EAX
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,1
        PUSH EAX
        MOV EAX,4
        POP EBX
        MOV ECX,EAX
        MOV EAX,EBX
        SHL EAX,CL
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,256
        PUSH EAX
        MOV EAX,4
        POP EBX
        MOV ECX,EAX
        MOV EAX,EBX
        SHR EAX,CL
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,255
        PUSH EAX
        MOV EAX,15
        POP EBX
        AND EAX,EBX
        PUSH EAX
        MOV EAX,240
        POP EBX
        OR EAX,EBX
        MOV DWORD PTR [EBP-12],EAX
_CSCL_00015:
        MOV ESP,EBP
        POP EBP
        RET

; --- method TestComplex ---
_CSCF_TESTCOMPLEX:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,2
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,3
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,4
        MOV DWORD PTR [EBP-12],EAX
        MOV DWORD PTR [EBP-16],0
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-12]
        POP EBX
        IMUL EAX,EBX
        POP EBX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        POP EBX
        IMUL EAX,EBX
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-12]
        POP EBX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        POP EBX
        ADD EAX,EBX
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-12]
        PUSH EAX
        MOV EAX,1
        POP EBX
        SUB EBX,EAX
        MOV EAX,EBX
        POP EBX
        IMUL EAX,EBX
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        POP EBX
        IMUL EAX,EBX
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-12]
        POP EBX
        IMUL EAX,EBX
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        POP EBX
        ADD EAX,EBX
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-12]
        POP EBX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,1
        PUSH EAX
        MOV EAX,2
        POP EBX
        ADD EAX,EBX
        PUSH EAX
        MOV EAX,3
        POP EBX
        ADD EAX,EBX
        PUSH EAX
        MOV EAX,4
        POP EBX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,10
        PUSH EAX
        MOV EAX,3
        POP EBX
        MOV ECX,EAX
        MOV EAX,EBX
        CDQ
        IDIV ECX
        MOV EAX,EDX
        PUSH EAX
        MOV EAX,1
        POP EBX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-16],EAX
_CSCL_00016:
        MOV ESP,EBP
        POP EBP
        RET

; --- method TestCombined ---
_CSCF_TESTCOMBINED:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,5
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,10
        MOV DWORD PTR [EBP-8],EAX
        MOV DWORD PTR [EBP-12],0
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,0
        POP EBX
        CMP EBX,EAX
        SETG AL
        MOVZX EAX,AL
        TEST EAX,EAX
        JZ _CSCL_00018
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,10
        POP EBX
        CMP EBX,EAX
        SETL AL
        MOVZX EAX,AL
        TEST EAX,EAX
        JZ _CSCL_00018
        MOV EAX,1
        JMP _CSCL_00019
_CSCL_00018:
        XOR EAX,EAX
_CSCL_00019:
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,10
        POP EBX
        CMP EBX,EAX
        SETG AL
        MOVZX EAX,AL
        TEST EAX,EAX
        JNZ _CSCL_00020
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,5
        POP EBX
        CMP EBX,EAX
        SETG AL
        MOVZX EAX,AL
        TEST EAX,EAX
        JNZ _CSCL_00020
        XOR EAX,EAX
        JMP _CSCL_00021
_CSCL_00020:
        MOV EAX,1
_CSCL_00021:
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,5
        POP EBX
        CMP EBX,EAX
        SETE AL
        MOVZX EAX,AL
        TEST EAX,EAX
        JZ _CSCL_00022
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,10
        POP EBX
        CMP EBX,EAX
        SETE AL
        MOVZX EAX,AL
        TEST EAX,EAX
        JZ _CSCL_00022
        MOV EAX,1
        JMP _CSCL_00023
_CSCL_00022:
        XOR EAX,EAX
_CSCL_00023:
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,5
        POP EBX
        CMP EBX,EAX
        SETNE AL
        MOVZX EAX,AL
        TEST EAX,EAX
        JNZ _CSCL_00024
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,10
        POP EBX
        CMP EBX,EAX
        SETNE AL
        MOVZX EAX,AL
        TEST EAX,EAX
        JNZ _CSCL_00024
        XOR EAX,EAX
        JMP _CSCL_00025
_CSCL_00024:
        MOV EAX,1
_CSCL_00025:
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        POP EBX
        CMP EBX,EAX
        SETG AL
        MOVZX EAX,AL
        TEST EAX,EAX
        SETZ AL
        MOVZX EAX,AL
        MOV DWORD PTR [EBP-12],EAX
_CSCL_00017:
        MOV ESP,EBP
        POP EBP
        RET

; --- method TestNullCoalesce ---
_CSCF_TESTNULLCOALESCE:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,42
        MOV DWORD PTR [EBP-8],EAX
        MOV DWORD PTR [EBP-12],0
        MOV EAX,DWORD PTR [EBP-4]
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV DWORD PTR [EBP-12],EAX
_CSCL_00026:
        MOV ESP,EBP
        POP EBP
        RET

; --- method TestShiftMask ---
_CSCF_TESTSHIFTMASK:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,1
        PUSH EAX
        MOV EAX,3
        POP EBX
        MOV ECX,EAX
        MOV EAX,EBX
        SHL EAX,CL
        MOV DWORD PTR [EBP-8],EAX
        MOV DWORD PTR [EBP-12],0
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        POP EBX
        OR EAX,EBX
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-12]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        NOT EAX
        POP EBX
        AND EAX,EBX
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,2
        POP EBX
        MOV ECX,EAX
        MOV EAX,EBX
        SHR EAX,CL
        PUSH EAX
        MOV EAX,1
        POP EBX
        AND EAX,EBX
        MOV DWORD PTR [EBP-12],EAX
_CSCL_00027:
        MOV ESP,EBP
        POP EBP
        RET

; --- method Main ---
_CSCF_MAIN:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,1024
        CALL _CSCF_TESTARITH
        CALL _CSCF_TESTCOMPARE
        CALL _CSCF_TESTLOGIC
        CALL _CSCF_TESTBITWISE
        CALL _CSCF_TESTCOMPLEX
        CALL _CSCF_TESTCOMBINED
        CALL _CSCF_TESTNULLCOALESCE
        CALL _CSCF_TESTSHIFTMASK
_CSCL_00028:
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
