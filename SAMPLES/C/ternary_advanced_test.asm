; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/ternary_advanced_test.c

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
        SUB ESP,16
;   local x = [EBP-4]
;   local y = [EBP-8]
;   local z = [EBP-12]
;   local result = [EBP-16]
        MOV EAX,10
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,20
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,30
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _CCL_2
        XOR EAX,EAX
        JMP _CCL_3
_CCL_2:
        MOV EAX,1
_CCL_3:
        TEST EAX,EAX
        JZ _CCL_4
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_5
_CCL_4:
        MOV EAX,DWORD PTR [EBP-8]
_CCL_5:
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-12]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _CCL_6
        XOR EAX,EAX
        JMP _CCL_7
_CCL_6:
        MOV EAX,1
_CCL_7:
        TEST EAX,EAX
        JZ _CCL_8
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        JMP _CCL_9
_CCL_8:
        MOV EAX,DWORD PTR [EBP-12]
_CCL_9:
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _CCL_10
        XOR EAX,EAX
        JMP _CCL_11
_CCL_10:
        MOV EAX,1
_CCL_11:
        TEST EAX,EAX
        JZ _CCL_12
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-12]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _CCL_14
        XOR EAX,EAX
        JMP _CCL_15
_CCL_14:
        MOV EAX,1
_CCL_15:
        TEST EAX,EAX
        JZ _CCL_16
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_17
_CCL_16:
        MOV EAX,DWORD PTR [EBP-12]
_CCL_17:
        JMP _CCL_13
_CCL_12:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-12]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _CCL_18
        XOR EAX,EAX
        JMP _CCL_19
_CCL_18:
        MOV EAX,1
_CCL_19:
        TEST EAX,EAX
        JZ _CCL_20
        MOV EAX,DWORD PTR [EBP-8]
        JMP _CCL_21
_CCL_20:
        MOV EAX,DWORD PTR [EBP-12]
_CCL_21:
_CCL_13:
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,5
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,DWORD PTR [EBP-4]
        TEST EAX,EAX
        JZ _CCL_22
        MOV EAX,DWORD PTR [EBP-8]
        TEST EAX,EAX
        JZ _CCL_22
        MOV EAX,1
        JMP _CCL_23
_CCL_22:
        XOR EAX,EAX
_CCL_23:
        TEST EAX,EAX
        JZ _CCL_24
        MOV EAX,1
        JMP _CCL_25
_CCL_24:
        MOV EAX,DWORD PTR [EBP-4]
        TEST EAX,EAX
        JNZ _CCL_26
        MOV EAX,DWORD PTR [EBP-8]
        TEST EAX,EAX
        JNZ _CCL_26
        XOR EAX,EAX
        JMP _CCL_27
_CCL_26:
        MOV EAX,1
_CCL_27:
        TEST EAX,EAX
        JZ _CCL_28
        MOV EAX,2
        JMP _CCL_29
_CCL_28:
        MOV EAX,3
_CCL_29:
_CCL_25:
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,15
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,15
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_30
        XOR EAX,EAX
        JMP _CCL_31
_CCL_30:
        MOV EAX,1
_CCL_31:
        TEST EAX,EAX
        JZ _CCL_32
        MOV EAX,100
        JMP _CCL_33
_CCL_32:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JNE _CCL_34
        XOR EAX,EAX
        JMP _CCL_35
_CCL_34:
        MOV EAX,1
_CCL_35:
        TEST EAX,EAX
        JZ _CCL_36
        MOV EAX,200
        JMP _CCL_37
_CCL_36:
        MOV EAX,300
_CCL_37:
_CCL_33:
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        TEST EAX,EAX
        SETZ AL
        MOVZX EAX,AL
        TEST EAX,EAX
        JZ _CCL_38
        MOV EAX,42
        JMP _CCL_39
_CCL_38:
        MOV EAX,0
_CCL_39:
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,3
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_40
        XOR EAX,EAX
        JMP _CCL_41
_CCL_40:
        MOV EAX,1
_CCL_41:
        TEST EAX,EAX
        JZ _CCL_42
        MOV EAX,10
        JMP _CCL_43
_CCL_42:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,2
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_44
        XOR EAX,EAX
        JMP _CCL_45
_CCL_44:
        MOV EAX,1
_CCL_45:
        TEST EAX,EAX
        JZ _CCL_46
        MOV EAX,20
        JMP _CCL_47
_CCL_46:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,3
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
        JZ _CCL_50
        MOV EAX,30
        JMP _CCL_51
_CCL_50:
        MOV EAX,40
_CCL_51:
_CCL_47:
_CCL_43:
        MOV DWORD PTR [EBP-16],EAX
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
