; Genere par CSCW32 - Compilateur C# vers 80386 Win32
; Source : SAMPLES/CSHARP/test20_ifelse.cs

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
        MOV EAX,10
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,20
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        POP EBX
        CMP EBX,EAX
        SETL AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00001
        MOV EAX,1
        MOV DWORD PTR [EBP-12],EAX
_CSCL_00001:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        POP EBX
        CMP EBX,EAX
        SETG AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00003
        MOV EAX,2
        MOV DWORD PTR [EBP-12],EAX
        JMP _CSCL_00004
_CSCL_00003:
        MOV EAX,3
        MOV DWORD PTR [EBP-12],EAX
_CSCL_00004:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,10
        POP EBX
        CMP EBX,EAX
        SETE AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00005
        MOV EAX,4
        MOV DWORD PTR [EBP-12],EAX
_CSCL_00005:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,10
        POP EBX
        CMP EBX,EAX
        SETNE AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00007
        MOV EAX,5
        MOV DWORD PTR [EBP-12],EAX
        JMP _CSCL_00008
_CSCL_00007:
        MOV EAX,6
        MOV DWORD PTR [EBP-12],EAX
_CSCL_00008:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        POP EBX
        CMP EBX,EAX
        SETE AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00009
        MOV EAX,10
        MOV DWORD PTR [EBP-12],EAX
        JMP _CSCL_00010
_CSCL_00009:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,10
        POP EBX
        CMP EBX,EAX
        SETE AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00011
        MOV EAX,20
        MOV DWORD PTR [EBP-12],EAX
        JMP _CSCL_00012
_CSCL_00011:
        MOV EAX,30
        MOV DWORD PTR [EBP-12],EAX
_CSCL_00012:
_CSCL_00010:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,0
        POP EBX
        CMP EBX,EAX
        SETL AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00013
        MOV EAX,100
        MOV DWORD PTR [EBP-12],EAX
        JMP _CSCL_00014
_CSCL_00013:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,0
        POP EBX
        CMP EBX,EAX
        SETE AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00015
        MOV EAX,200
        MOV DWORD PTR [EBP-12],EAX
        JMP _CSCL_00016
_CSCL_00015:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,100
        POP EBX
        CMP EBX,EAX
        SETG AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00017
        MOV EAX,300
        MOV DWORD PTR [EBP-12],EAX
        JMP _CSCL_00018
_CSCL_00017:
        MOV EAX,400
        MOV DWORD PTR [EBP-12],EAX
_CSCL_00018:
_CSCL_00016:
_CSCL_00014:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,0
        POP EBX
        CMP EBX,EAX
        SETG AL
        MOVZX EAX,AL
        TEST EAX,EAX
        JZ _CSCL_00019
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,0
        POP EBX
        CMP EBX,EAX
        SETG AL
        MOVZX EAX,AL
        TEST EAX,EAX
        JZ _CSCL_00019
        MOV EAX,1
        JMP _CSCL_00020
_CSCL_00019:
        XOR EAX,EAX
_CSCL_00020:
        TEST EAX, EAX
        JZ _CSCL_00021
        MOV EAX,500
        MOV DWORD PTR [EBP-12],EAX
_CSCL_00021:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,0
        POP EBX
        CMP EBX,EAX
        SETE AL
        MOVZX EAX,AL
        TEST EAX,EAX
        JNZ _CSCL_00023
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,20
        POP EBX
        CMP EBX,EAX
        SETE AL
        MOVZX EAX,AL
        TEST EAX,EAX
        JNZ _CSCL_00023
        XOR EAX,EAX
        JMP _CSCL_00024
_CSCL_00023:
        MOV EAX,1
_CSCL_00024:
        TEST EAX, EAX
        JZ _CSCL_00025
        MOV EAX,600
        MOV DWORD PTR [EBP-12],EAX
_CSCL_00025:
        MOV DWORD PTR [EBP-16],0
        MOV EAX,1
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,DWORD PTR [EBP-16]
        TEST EAX,EAX
        SETZ AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00027
        MOV EAX,700
        MOV DWORD PTR [EBP-12],EAX
_CSCL_00027:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,0
        POP EBX
        CMP EBX,EAX
        SETG AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00029
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,0
        POP EBX
        CMP EBX,EAX
        SETG AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00031
        MOV EAX,800
        MOV DWORD PTR [EBP-12],EAX
_CSCL_00031:
_CSCL_00029:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,10
        POP EBX
        CMP EBX,EAX
        SETE AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00033
        MOV DWORD PTR [EBP-20],0
        MOV EAX,42
        MOV DWORD PTR [EBP-20],EAX
        MOV EAX,DWORD PTR [EBP-20]
        MOV DWORD PTR [EBP-12],EAX
_CSCL_00033:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        POP EBX
        CMP EBX,EAX
        SETL AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00035
        MOV EAX,OFFSET _CSCK_1
        PUSH EAX
        CALL _CSCRT_PRINTLN
        JMP _CSCL_00036
_CSCL_00035:
        MOV EAX,OFFSET _CSCK_2
        PUSH EAX
        CALL _CSCRT_PRINTLN
_CSCL_00036:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        POP EBX
        CMP EBX,EAX
        SETE AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00037
        MOV EAX,1000
        MOV DWORD PTR [EBP-12],EAX
        JMP _CSCL_00038
_CSCL_00037:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,10
        POP EBX
        CMP EBX,EAX
        SETE AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00039
        MOV EAX,2000
        MOV DWORD PTR [EBP-12],EAX
        JMP _CSCL_00040
_CSCL_00039:
        MOV EAX,3000
        MOV DWORD PTR [EBP-12],EAX
_CSCL_00040:
_CSCL_00038:
_CSCL_00000:
        PUSH 0
        CALL _ExitProcess@4
        MOV ESP,EBP
        POP EBP
        RET
.DATA

; Constantes chaines
_CSCK_1 DB "x < y",0
_CSCK_2 DB "x >= y",0

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
