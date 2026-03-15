; Genere par CSCW32 - Compilateur C# vers 80386 Win32
; Source : SAMPLES/CSHARP/test21_loops.cs

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
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,1
        MOV DWORD PTR [EBP-4],EAX
_CSCL_00001:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,10
        POP EBX
        CMP EBX,EAX
        SETLE AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00002
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-4]
        POP EBX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,DWORD PTR [EBP-4]
        INC DWORD PTR [EBP-4]
        JMP _CSCL_00001
_CSCL_00002:
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
_CSCL_00003:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,5
        POP EBX
        CMP EBX,EAX
        SETL AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00004
        MOV EAX,DWORD PTR [EBP-4]
        INC DWORD PTR [EBP-4]
        JMP _CSCL_00003
_CSCL_00004:
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,100
        MOV DWORD PTR [EBP-12],EAX
_CSCL_00005:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,10
        POP EBX
        CMP EBX,EAX
        SETL AL
        MOVZX EAX,AL
        TEST EAX,EAX
        JZ _CSCL_00007
        MOV EAX,DWORD PTR [EBP-12]
        PUSH EAX
        MOV EAX,0
        POP EBX
        CMP EBX,EAX
        SETG AL
        MOVZX EAX,AL
        TEST EAX,EAX
        JZ _CSCL_00007
        MOV EAX,1
        JMP _CSCL_00008
_CSCL_00007:
        XOR EAX,EAX
_CSCL_00008:
        TEST EAX, EAX
        JZ _CSCL_00006
        MOV EAX,DWORD PTR [EBP-4]
        INC DWORD PTR [EBP-4]
        MOV EAX,DWORD PTR [EBP-12]
        PUSH EAX
        MOV EAX,10
        POP EBX
        SUB EBX,EAX
        MOV EAX,EBX
        MOV DWORD PTR [EBP-12],EAX
        JMP _CSCL_00005
_CSCL_00006:
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
_CSCL_00009:
        MOV EAX,DWORD PTR [EBP-4]
        INC DWORD PTR [EBP-4]
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,5
        POP EBX
        CMP EBX,EAX
        SETL AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JNZ _CSCL_00009
_CSCL_00010:
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
_CSCL_00011:
        MOV EAX,DWORD PTR [EBP-4]
        INC DWORD PTR [EBP-4]
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,3
        POP EBX
        CMP EBX,EAX
        SETL AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JNZ _CSCL_00011
_CSCL_00012:
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-20],EAX
_CSCL_00013:
        MOV EAX,DWORD PTR [EBP-20]
        PUSH EAX
        MOV EAX,10
        POP EBX
        CMP EBX,EAX
        SETL AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00016
        JMP _CSCL_00015
_CSCL_00014:
        MOV EAX,DWORD PTR [EBP-20]
        INC DWORD PTR [EBP-20]
        JMP _CSCL_00013
_CSCL_00015:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-20]
        POP EBX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-8],EAX
        JMP _CSCL_00014
_CSCL_00016:
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,1
        MOV DWORD PTR [EBP-24],EAX
_CSCL_00017:
        MOV EAX,DWORD PTR [EBP-24]
        PUSH EAX
        MOV EAX,5
        POP EBX
        CMP EBX,EAX
        SETLE AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00020
        JMP _CSCL_00019
_CSCL_00018:
        MOV EAX,DWORD PTR [EBP-24]
        INC DWORD PTR [EBP-24]
        JMP _CSCL_00017
_CSCL_00019:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-24]
        POP EBX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-8],EAX
        JMP _CSCL_00018
_CSCL_00020:
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
_CSCL_00021:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,10
        POP EBX
        CMP EBX,EAX
        SETL AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00024
        JMP _CSCL_00023
_CSCL_00022:
        MOV EAX,DWORD PTR [EBP-4]
        INC DWORD PTR [EBP-4]
        JMP _CSCL_00021
_CSCL_00023:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-4]
        POP EBX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-8],EAX
        JMP _CSCL_00022
_CSCL_00024:
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-28],EAX
_CSCL_00025:
        MOV EAX,DWORD PTR [EBP-28]
        PUSH EAX
        MOV EAX,3
        POP EBX
        CMP EBX,EAX
        SETL AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00028
        JMP _CSCL_00027
_CSCL_00026:
        MOV EAX,DWORD PTR [EBP-28]
        INC DWORD PTR [EBP-28]
        JMP _CSCL_00025
_CSCL_00027:
        MOV EAX,0
        MOV DWORD PTR [EBP-32],EAX
_CSCL_00029:
        MOV EAX,DWORD PTR [EBP-32]
        PUSH EAX
        MOV EAX,3
        POP EBX
        CMP EBX,EAX
        SETL AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00032
        JMP _CSCL_00031
_CSCL_00030:
        MOV EAX,DWORD PTR [EBP-32]
        INC DWORD PTR [EBP-32]
        JMP _CSCL_00029
_CSCL_00031:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,1
        POP EBX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-8],EAX
        JMP _CSCL_00030
_CSCL_00032:
        JMP _CSCL_00026
_CSCL_00028:
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
_CSCL_00033:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,100
        POP EBX
        CMP EBX,EAX
        SETL AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00034
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,10
        POP EBX
        CMP EBX,EAX
        SETE AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00035
        JMP _CSCL_00034
_CSCL_00035:
        MOV EAX,DWORD PTR [EBP-4]
        INC DWORD PTR [EBP-4]
        JMP _CSCL_00033
_CSCL_00034:
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
_CSCL_00037:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,100
        POP EBX
        CMP EBX,EAX
        SETL AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00040
        JMP _CSCL_00039
_CSCL_00038:
        MOV EAX,DWORD PTR [EBP-4]
        INC DWORD PTR [EBP-4]
        JMP _CSCL_00037
_CSCL_00039:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,5
        POP EBX
        CMP EBX,EAX
        SETGE AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00041
        JMP _CSCL_00040
_CSCL_00041:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-4]
        POP EBX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-8],EAX
        JMP _CSCL_00038
_CSCL_00040:
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
_CSCL_00043:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,10
        POP EBX
        CMP EBX,EAX
        SETL AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00044
        MOV EAX,DWORD PTR [EBP-4]
        INC DWORD PTR [EBP-4]
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,5
        POP EBX
        CMP EBX,EAX
        SETE AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00045
        JMP _CSCL_00043
_CSCL_00045:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-4]
        POP EBX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-8],EAX
        JMP _CSCL_00043
_CSCL_00044:
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
_CSCL_00047:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,10
        POP EBX
        CMP EBX,EAX
        SETL AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00050
        JMP _CSCL_00049
_CSCL_00048:
        MOV EAX,DWORD PTR [EBP-4]
        INC DWORD PTR [EBP-4]
        JMP _CSCL_00047
_CSCL_00049:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,3
        POP EBX
        CMP EBX,EAX
        SETE AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00051
        JMP _CSCL_00048
_CSCL_00051:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-4]
        POP EBX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-8],EAX
        JMP _CSCL_00048
_CSCL_00050:
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
_CSCL_00053:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,3
        POP EBX
        CMP EBX,EAX
        SETL AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00056
        JMP _CSCL_00055
_CSCL_00054:
        MOV EAX,DWORD PTR [EBP-4]
        INC DWORD PTR [EBP-4]
        JMP _CSCL_00053
_CSCL_00055:
        MOV EAX,0
        MOV DWORD PTR [EBP-16],EAX
_CSCL_00057:
        MOV EAX,DWORD PTR [EBP-16]
        PUSH EAX
        MOV EAX,2
        POP EBX
        CMP EBX,EAX
        SETL AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00058
        MOV EAX,DWORD PTR [EBP-16]
        INC DWORD PTR [EBP-16]
        JMP _CSCL_00057
_CSCL_00058:
        JMP _CSCL_00054
_CSCL_00056:
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
_CSCL_00059:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,5
        POP EBX
        CMP EBX,EAX
        SETE AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00061
        JMP _CSCL_00060
_CSCL_00061:
        MOV EAX,DWORD PTR [EBP-4]
        INC DWORD PTR [EBP-4]
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,100
        POP EBX
        CMP EBX,EAX
        SETL AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JNZ _CSCL_00059
_CSCL_00060:
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
