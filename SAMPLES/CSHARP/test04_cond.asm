; Genere par CSCW32 - Compilateur C# vers 80386 Win32
; Source : SAMPLES/CSHARP/test04_cond.cs

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
        MOV EAX,OFFSET _CSCK_1
        PUSH EAX
        CALL _CSCRT_PRINTLN
        JMP _CSCL_00002
_CSCL_00001:
        MOV EAX,OFFSET _CSCK_2
        PUSH EAX
        CALL _CSCRT_PRINTLN
_CSCL_00002:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,10
        POP EBX
        CMP EBX,EAX
        SETE AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00003
        MOV EAX,OFFSET _CSCK_3
        PUSH EAX
        CALL _CSCRT_PRINTLN
_CSCL_00003:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,0
        POP EBX
        CMP EBX,EAX
        SETG AL
        MOVZX EAX,AL
        TEST EAX,EAX
        JZ _CSCL_00005
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,0
        POP EBX
        CMP EBX,EAX
        SETG AL
        MOVZX EAX,AL
        TEST EAX,EAX
        JZ _CSCL_00005
        MOV EAX,1
        JMP _CSCL_00006
_CSCL_00005:
        XOR EAX,EAX
_CSCL_00006:
        TEST EAX, EAX
        JZ _CSCL_00007
        MOV EAX,OFFSET _CSCK_4
        PUSH EAX
        CALL _CSCRT_PRINTLN
_CSCL_00007:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        POP EBX
        CMP EBX,EAX
        SETNE AL
        MOVZX EAX,AL
        TEST EAX,EAX
        JNZ _CSCL_00009
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,0
        POP EBX
        CMP EBX,EAX
        SETE AL
        MOVZX EAX,AL
        TEST EAX,EAX
        JNZ _CSCL_00009
        XOR EAX,EAX
        JMP _CSCL_00010
_CSCL_00009:
        MOV EAX,1
_CSCL_00010:
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-12]
        PUSH EAX
        CALL _CSCRT_PRINTLN
        MOV EAX,DWORD PTR [EBP-12]
        TEST EAX,EAX
        SETZ AL
        MOVZX EAX,AL
        TEST EAX, EAX
        JZ _CSCL_00011
        MOV EAX,OFFSET _CSCK_5
        PUSH EAX
        CALL _CSCRT_PRINTLN
        JMP _CSCL_00012
_CSCL_00011:
        MOV EAX,OFFSET _CSCK_6
        PUSH EAX
        CALL _CSCRT_PRINTLN
_CSCL_00012:
_CSCL_00000:
        PUSH 0
        CALL _ExitProcess@4
        MOV ESP,EBP
        POP EBP
        RET
.DATA

; Constantes chaines
_CSCK_1 DB "a < b",0
_CSCK_2 DB "a >= b",0
_CSCK_3 DB "a est 10",0
_CSCK_4 DB "tous positifs",0
_CSCK_5 DB "negatif",0
_CSCK_6 DB "positif",0

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
