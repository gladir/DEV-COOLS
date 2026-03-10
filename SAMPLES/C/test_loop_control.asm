; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/test_loop_control.c

.386
.MODEL FLAT, STDCALL

; --- Imports Win32 (kernel32.dll) ---
EXTRN _ExitProcess@4:NEAR
EXTRN _GetStdHandle@4:NEAR
EXTRN _WriteFile@20:NEAR
EXTRN _ReadFile@20:NEAR
EXTRN _GetProcessHeap@0:NEAR
EXTRN _HeapAlloc@12:NEAR
EXTRN _HeapFree@12:NEAR

; --- Segment de donnees ---
.DATA

HSTDOUT  DD 0
HSTDIN   DD 0
HHEAP    DD 0
NUMBUF   DB 16 DUP(0)
INBUF    DB 256 DUP(0)
BYTESWR  DD 0
BYTESRD  DD 0
CRLF     DB 13,10,0


; --- Segment de code ---
.CODE

; --- Fonction: main ---
_CCF_main:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,8
;   local i = [EBP-4]
;   local j = [EBP-8]
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
_CCL_2:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,10
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_4
        XOR EAX,EAX
        JMP _CCL_5
_CCL_4:
        MOV EAX,1
_CCL_5:
        TEST EAX,EAX
        JZ _CCL_3
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,5
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_8
        XOR EAX,EAX
        JMP _CCL_9
_CCL_8:
        MOV EAX,1
_CCL_9:
        TEST EAX,EAX
        JZ _CCL_6
        JMP _CCL_3
_CCL_6:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_2
_CCL_3:
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
_CCL_10:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,10
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_12
        XOR EAX,EAX
        JMP _CCL_13
_CCL_12:
        MOV EAX,1
_CCL_13:
        TEST EAX,EAX
        JZ _CCL_11
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,3
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_16
        XOR EAX,EAX
        JMP _CCL_17
_CCL_16:
        MOV EAX,1
_CCL_17:
        TEST EAX,EAX
        JZ _CCL_14
        JMP _CCL_10
_CCL_14:
        JMP _CCL_10
_CCL_11:
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
_CCL_18:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,10
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_21
        XOR EAX,EAX
        JMP _CCL_22
_CCL_21:
        MOV EAX,1
_CCL_22:
        TEST EAX,EAX
        JZ _CCL_20
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,7
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_25
        XOR EAX,EAX
        JMP _CCL_26
_CCL_25:
        MOV EAX,1
_CCL_26:
        TEST EAX,EAX
        JZ _CCL_23
        JMP _CCL_20
_CCL_23:
_CCL_19:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_18
_CCL_20:
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
_CCL_27:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,10
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_30
        XOR EAX,EAX
        JMP _CCL_31
_CCL_30:
        MOV EAX,1
_CCL_31:
        TEST EAX,EAX
        JZ _CCL_29
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,4
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_34
        XOR EAX,EAX
        JMP _CCL_35
_CCL_34:
        MOV EAX,1
_CCL_35:
        TEST EAX,EAX
        JZ _CCL_32
        JMP _CCL_28
_CCL_32:
_CCL_28:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_27
_CCL_29:
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
_CCL_36:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,3
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_39
        XOR EAX,EAX
        JMP _CCL_40
_CCL_39:
        MOV EAX,1
_CCL_40:
        TEST EAX,EAX
        JZ _CCL_38
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
_CCL_41:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,3
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_44
        XOR EAX,EAX
        JMP _CCL_45
_CCL_44:
        MOV EAX,1
_CCL_45:
        TEST EAX,EAX
        JZ _CCL_43
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_48
        XOR EAX,EAX
        JMP _CCL_49
_CCL_48:
        MOV EAX,1
_CCL_49:
        TEST EAX,EAX
        JZ _CCL_46
        JMP _CCL_42
_CCL_46:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_52
        XOR EAX,EAX
        JMP _CCL_53
_CCL_52:
        MOV EAX,1
_CCL_53:
        TEST EAX,EAX
        JZ _CCL_54
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,2
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_56
        XOR EAX,EAX
        JMP _CCL_57
_CCL_56:
        MOV EAX,1
_CCL_57:
        TEST EAX,EAX
        JZ _CCL_54
        MOV EAX,1
        JMP _CCL_55
_CCL_54:
        XOR EAX,EAX
_CCL_55:
        TEST EAX,EAX
        JZ _CCL_50
        JMP _CCL_43
_CCL_50:
_CCL_42:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-8],EAX
        JMP _CCL_41
_CCL_43:
_CCL_37:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_36
_CCL_38:
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
_CCL_58:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,3
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_63
        XOR EAX,EAX
        JMP _CCL_64
_CCL_63:
        MOV EAX,1
_CCL_64:
        TEST EAX,EAX
        JZ _CCL_61
        JMP _CCL_60
_CCL_61:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
_CCL_59:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,10
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_65
        XOR EAX,EAX
        JMP _CCL_66
_CCL_65:
        MOV EAX,1
_CCL_66:
        TEST EAX,EAX
        JNZ _CCL_58
_CCL_60:
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
_CCL_67:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,2
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_72
        XOR EAX,EAX
        JMP _CCL_73
_CCL_72:
        MOV EAX,1
_CCL_73:
        TEST EAX,EAX
        JZ _CCL_70
        JMP _CCL_68
_CCL_70:
_CCL_68:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,5
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_74
        XOR EAX,EAX
        JMP _CCL_75
_CCL_74:
        MOV EAX,1
_CCL_75:
        TEST EAX,EAX
        JNZ _CCL_67
_CCL_69:
        MOV EAX,0
        JMP _CCL_1
_CCL_1:
        MOV ESP,EBP
        POP EBP
        RET

; --- Point d'entree Win32 ---
_main:
        PUSH -11
        CALL _GetStdHandle@4
        MOV DWORD PTR [HSTDOUT],EAX
        PUSH -10
        CALL _GetStdHandle@4
        MOV DWORD PTR [HSTDIN],EAX
        CALL _GetProcessHeap@0
        MOV DWORD PTR [HHEAP],EAX
        CALL _CCF_main
        PUSH 0
        CALL _ExitProcess@4

END _main
