; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/ternary_operator_test.c

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

_CCK_1  DB 'max(10, 5) = %d (devrait ',195,170,'tre 10)',10,0
_CCK_2  DB 'condition fausse: %d (devrait ',195,170,'tre 5)',10,0
_CCK_3  DB '1 ? 100 : 200 = %d (devrait ',195,170,'tre 100)',10,0
_CCK_4  DB '0 ? 100 : 200 = %d (devrait ',195,170,'tre 200)',10,0
_CCK_5  DB '(8 > 5) ? (3 + 2) : (3 - 2) = %d (devrait ',195,170,'tre 5)',10,0
_CCK_6  DB '(8 < 5) ? (3 + 2) : (3 - 2) = %d (devrait ',195,170,'tre 1)',10,0
_CCK_7  DB 'Ternaire imbriqu',195,169,': %d (devrait ',195,170,'tre 2)',10,0
_CCK_8  DB '0 ? 42 : 99 = %d (devrait ',195,170,'tre 99)',10,0
_CCK_9  DB '1 ? 42 : 99 = %d (devrait ',195,170,'tre 42)',10,0
_CCK_10  DB '!7 ? 0 : 7 = %d (devrait ',195,170,'tre 7)',10,0

; --- Segment de code ---
.CODE

; --- Fonction: main ---
_CCF_main:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,16
;   local a = [EBP-4]
;   local b = [EBP-8]
;   local c = [EBP-12]
;   local result = [EBP-16]
        MOV EAX,10
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,5
        MOV DWORD PTR [EBP-8],EAX
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
        MOV EAX,DWORD PTR [EBP-16]
        PUSH EAX
        MOV EAX,OFFSET _CCK_1
        PUSH EAX
        CALL _printf
        ADD ESP,8
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_6
        XOR EAX,EAX
        JMP _CCL_7
_CCL_6:
        MOV EAX,1
_CCL_7:
        TEST EAX,EAX
        JZ _CCL_8
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_9
_CCL_8:
        MOV EAX,DWORD PTR [EBP-8]
_CCL_9:
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,DWORD PTR [EBP-16]
        PUSH EAX
        MOV EAX,OFFSET _CCK_2
        PUSH EAX
        CALL _printf
        ADD ESP,8
        MOV EAX,1
        TEST EAX,EAX
        JZ _CCL_10
        MOV EAX,100
        JMP _CCL_11
_CCL_10:
        MOV EAX,200
_CCL_11:
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,DWORD PTR [EBP-16]
        PUSH EAX
        MOV EAX,OFFSET _CCK_3
        PUSH EAX
        CALL _printf
        ADD ESP,8
        MOV EAX,0
        TEST EAX,EAX
        JZ _CCL_12
        MOV EAX,100
        JMP _CCL_13
_CCL_12:
        MOV EAX,200
_CCL_13:
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,DWORD PTR [EBP-16]
        PUSH EAX
        MOV EAX,OFFSET _CCK_4
        PUSH EAX
        CALL _printf
        ADD ESP,8
        MOV EAX,8
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,3
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,2
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,5
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
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-12]
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        JMP _CCL_17
_CCL_16:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-12]
        MOV EBX,EAX
        POP EAX
        SUB EAX,EBX
_CCL_17:
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,DWORD PTR [EBP-16]
        PUSH EAX
        MOV EAX,OFFSET _CCK_5
        PUSH EAX
        CALL _printf
        ADD ESP,8
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,5
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _CCL_18
        XOR EAX,EAX
        JMP _CCL_19
_CCL_18:
        MOV EAX,1
_CCL_19:
        TEST EAX,EAX
        JZ _CCL_20
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-12]
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        JMP _CCL_21
_CCL_20:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-12]
        MOV EBX,EAX
        POP EAX
        SUB EAX,EBX
_CCL_21:
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,DWORD PTR [EBP-16]
        PUSH EAX
        MOV EAX,OFFSET _CCK_6
        PUSH EAX
        CALL _printf
        ADD ESP,8
        MOV EAX,15
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,20
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _CCL_22
        XOR EAX,EAX
        JMP _CCL_23
_CCL_22:
        MOV EAX,1
_CCL_23:
        TEST EAX,EAX
        JZ _CCL_24
        MOV EAX,1
        JMP _CCL_25
_CCL_24:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,10
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _CCL_26
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
        MOV EAX,DWORD PTR [EBP-16]
        PUSH EAX
        MOV EAX,OFFSET _CCK_7
        PUSH EAX
        CALL _printf
        ADD ESP,8
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,42
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,99
        MOV DWORD PTR [EBP-12],EAX
        MOV EAX,DWORD PTR [EBP-4]
        TEST EAX,EAX
        JZ _CCL_30
        MOV EAX,DWORD PTR [EBP-8]
        JMP _CCL_31
_CCL_30:
        MOV EAX,DWORD PTR [EBP-12]
_CCL_31:
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,DWORD PTR [EBP-16]
        PUSH EAX
        MOV EAX,OFFSET _CCK_8
        PUSH EAX
        CALL _printf
        ADD ESP,8
        MOV EAX,1
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        TEST EAX,EAX
        JZ _CCL_32
        MOV EAX,DWORD PTR [EBP-8]
        JMP _CCL_33
_CCL_32:
        MOV EAX,DWORD PTR [EBP-12]
_CCL_33:
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,DWORD PTR [EBP-16]
        PUSH EAX
        MOV EAX,OFFSET _CCK_9
        PUSH EAX
        CALL _printf
        ADD ESP,8
        MOV EAX,7
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP-4]
        TEST EAX,EAX
        SETZ AL
        MOVZX EAX,AL
        TEST EAX,EAX
        JZ _CCL_34
        MOV EAX,0
        JMP _CCL_35
_CCL_34:
        MOV EAX,DWORD PTR [EBP-4]
_CCL_35:
        MOV DWORD PTR [EBP-16],EAX
        MOV EAX,DWORD PTR [EBP-16]
        PUSH EAX
        MOV EAX,OFFSET _CCK_10
        PUSH EAX
        CALL _printf
        ADD ESP,8
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
