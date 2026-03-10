; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/test_if_else.c

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

; --- Fonction: test_simple_if ---
_CCF_test_simple_if:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   param x = [EBP+8]
;   local r = [EBP-4]
        MOV DWORD PTR [EBP-4],0
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,0
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _CCL_4
        XOR EAX,EAX
        JMP _CCL_5
_CCL_4:
        MOV EAX,1
_CCL_5:
        TEST EAX,EAX
        JZ _CCL_2
        MOV EAX,1
        MOV DWORD PTR [EBP-4],EAX
_CCL_2:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_1
_CCL_1:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_if_else ---
_CCF_test_if_else:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   param x = [EBP+8]
;   local r = [EBP-4]
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,0
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _CCL_9
        XOR EAX,EAX
        JMP _CCL_10
_CCL_9:
        MOV EAX,1
_CCL_10:
        TEST EAX,EAX
        JZ _CCL_7
        MOV EAX,1
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_8
_CCL_7:
        MOV EAX,1
        NEG EAX
        MOV DWORD PTR [EBP-4],EAX
_CCL_8:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_6
_CCL_6:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_if_else_block ---
_CCF_test_if_else_block:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   param x = [EBP+8]
;   local r = [EBP-4]
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,10
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
        JZ _CCL_12
        MOV EAX,2
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_13
_CCL_12:
        MOV EAX,2
        NEG EAX
        MOV DWORD PTR [EBP-4],EAX
_CCL_13:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_11
_CCL_11:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_else_if ---
_CCF_test_else_if:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   param x = [EBP+8]
;   local r = [EBP-4]
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,100
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _CCL_19
        XOR EAX,EAX
        JMP _CCL_20
_CCL_19:
        MOV EAX,1
_CCL_20:
        TEST EAX,EAX
        JZ _CCL_17
        MOV EAX,3
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_18
_CCL_17:
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,10
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _CCL_23
        XOR EAX,EAX
        JMP _CCL_24
_CCL_23:
        MOV EAX,1
_CCL_24:
        TEST EAX,EAX
        JZ _CCL_21
        MOV EAX,2
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_22
_CCL_21:
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,0
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _CCL_27
        XOR EAX,EAX
        JMP _CCL_28
_CCL_27:
        MOV EAX,1
_CCL_28:
        TEST EAX,EAX
        JZ _CCL_25
        MOV EAX,1
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_26
_CCL_25:
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
_CCL_26:
_CCL_22:
_CCL_18:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_16
_CCL_16:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_nested_if ---
_CCF_test_nested_if:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   param a = [EBP+8]
;   param b = [EBP+12]
;   local r = [EBP-4]
        MOV DWORD PTR [EBP-4],0
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,0
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _CCL_32
        XOR EAX,EAX
        JMP _CCL_33
_CCL_32:
        MOV EAX,1
_CCL_33:
        TEST EAX,EAX
        JZ _CCL_30
        MOV EAX,DWORD PTR [EBP+12]
        PUSH EAX
        MOV EAX,0
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _CCL_36
        XOR EAX,EAX
        JMP _CCL_37
_CCL_36:
        MOV EAX,1
_CCL_37:
        TEST EAX,EAX
        JZ _CCL_34
        MOV EAX,1
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_35
_CCL_34:
        MOV EAX,2
        MOV DWORD PTR [EBP-4],EAX
_CCL_35:
        JMP _CCL_31
_CCL_30:
        MOV EAX,DWORD PTR [EBP+12]
        PUSH EAX
        MOV EAX,0
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _CCL_40
        XOR EAX,EAX
        JMP _CCL_41
_CCL_40:
        MOV EAX,1
_CCL_41:
        TEST EAX,EAX
        JZ _CCL_38
        MOV EAX,3
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_39
_CCL_38:
        MOV EAX,4
        MOV DWORD PTR [EBP-4],EAX
_CCL_39:
_CCL_31:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_29
_CCL_29:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_if_with_expr ---
_CCF_test_if_with_expr:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   param x = [EBP+8]
;   local r = [EBP-4]
        MOV DWORD PTR [EBP-4],0
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,42
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _CCL_45
        XOR EAX,EAX
        JMP _CCL_46
_CCL_45:
        MOV EAX,1
_CCL_46:
        TEST EAX,EAX
        JZ _CCL_43
        MOV EAX,100
        MOV DWORD PTR [EBP-4],EAX
_CCL_43:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_42
_CCL_42:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_compound_in_if ---
_CCF_test_compound_in_if:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,8
;   param x = [EBP+8]
;   local a = [EBP-4]
        MOV DWORD PTR [EBP-4],0
;   local b = [EBP-8]
        MOV DWORD PTR [EBP-8],0
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,0
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _CCL_50
        XOR EAX,EAX
        JMP _CCL_51
_CCL_50:
        MOV EAX,1
_CCL_51:
        TEST EAX,EAX
        JZ _CCL_48
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,2
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-8],EAX
        JMP _CCL_49
_CCL_48:
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
_CCL_49:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP-8]
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        JMP _CCL_47
_CCL_47:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_empty_then ---
_CCF_test_empty_then:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   param x = [EBP+8]
;   local r = [EBP-4]
        MOV DWORD PTR [EBP-4],5
        MOV EAX,5
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,0
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _CCL_55
        XOR EAX,EAX
        JMP _CCL_56
_CCL_55:
        MOV EAX,1
_CCL_56:
        TEST EAX,EAX
        JZ _CCL_53
        JMP _CCL_54
_CCL_53:
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
_CCL_54:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_52
_CCL_52:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: main ---
_CCF_main:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   local r = [EBP-4]
        MOV EAX,1
        PUSH EAX
        CALL _CCF_test_simple_if
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        PUSH EAX
        CALL _CCF_test_simple_if
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,5
        PUSH EAX
        CALL _CCF_test_if_else
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,3
        NEG EAX
        PUSH EAX
        CALL _CCF_test_if_else
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,20
        PUSH EAX
        CALL _CCF_test_if_else_block
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,5
        PUSH EAX
        CALL _CCF_test_if_else_block
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,200
        PUSH EAX
        CALL _CCF_test_else_if
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,50
        PUSH EAX
        CALL _CCF_test_else_if
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,5
        PUSH EAX
        CALL _CCF_test_else_if
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,1
        NEG EAX
        PUSH EAX
        CALL _CCF_test_else_if
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,1
        PUSH EAX
        MOV EAX,1
        PUSH EAX
        CALL _CCF_test_nested_if
        ADD ESP,8
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,1
        NEG EAX
        PUSH EAX
        MOV EAX,1
        PUSH EAX
        CALL _CCF_test_nested_if
        ADD ESP,8
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,1
        PUSH EAX
        MOV EAX,1
        NEG EAX
        PUSH EAX
        CALL _CCF_test_nested_if
        ADD ESP,8
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,1
        NEG EAX
        PUSH EAX
        MOV EAX,1
        NEG EAX
        PUSH EAX
        CALL _CCF_test_nested_if
        ADD ESP,8
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,42
        PUSH EAX
        CALL _CCF_test_if_with_expr
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        PUSH EAX
        CALL _CCF_test_if_with_expr
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,10
        PUSH EAX
        CALL _CCF_test_compound_in_if
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,5
        NEG EAX
        PUSH EAX
        CALL _CCF_test_compound_in_if
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,1
        PUSH EAX
        CALL _CCF_test_empty_then
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,1
        NEG EAX
        PUSH EAX
        CALL _CCF_test_empty_then
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        JMP _CCL_57
_CCL_57:
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
