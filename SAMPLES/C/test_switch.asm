; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/test_switch.c

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

; --- Fonction: test_switch_basic ---
_CCF_test_switch_basic:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   param x = [EBP+8]
;   local r = [EBP-4]
        MOV DWORD PTR [EBP-4],0
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP+8]
        MOV ECX,EAX
; switch (valeur dans ECX)
        CMP ECX,1
        JE _CCL_3
        CMP ECX,2
        JE _CCL_4
        CMP ECX,3
        JE _CCL_5
        JMP _CCL_6
_CCL_3:
        MOV EAX,10
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_2
_CCL_4:
        MOV EAX,20
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_2
_CCL_5:
        MOV EAX,30
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_2
_CCL_6:
        MOV EAX,99
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_2
_CCL_2:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_1
_CCL_1:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_switch_default ---
_CCF_test_switch_default:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   param x = [EBP+8]
;   local r = [EBP-4]
        MOV DWORD PTR [EBP-4],0
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP+8]
        MOV ECX,EAX
; switch (valeur dans ECX)
        CMP ECX,10
        JE _CCL_9
        JMP _CCL_10
_CCL_9:
        MOV EAX,1
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_8
_CCL_10:
        MOV EAX,42
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_8
_CCL_8:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_7
_CCL_7:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_switch_fallthrough ---
_CCF_test_switch_fallthrough:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   param x = [EBP+8]
;   local r = [EBP-4]
        MOV DWORD PTR [EBP-4],0
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP+8]
        MOV ECX,EAX
; switch (valeur dans ECX)
        CMP ECX,1
        JE _CCL_13
        CMP ECX,2
        JE _CCL_14
        CMP ECX,3
        JE _CCL_15
        JMP _CCL_16
_CCL_13:
_CCL_14:
_CCL_15:
        MOV EAX,100
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_12
_CCL_16:
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_12
_CCL_12:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_11
_CCL_11:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_switch_no_default ---
_CCF_test_switch_no_default:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   param x = [EBP+8]
;   local r = [EBP-4]
        MOV DWORD PTR [EBP-4],5
        MOV EAX,5
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP+8]
        MOV ECX,EAX
; switch (valeur dans ECX)
        CMP ECX,1
        JE _CCL_19
        CMP ECX,2
        JE _CCL_20
        JMP _CCL_18
_CCL_19:
        MOV EAX,11
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_18
_CCL_20:
        MOV EAX,22
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_18
_CCL_18:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_17
_CCL_17:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_switch_negative ---
_CCF_test_switch_negative:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   param x = [EBP+8]
;   local r = [EBP-4]
        MOV DWORD PTR [EBP-4],0
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP+8]
        MOV ECX,EAX
; switch (valeur dans ECX)
        CMP ECX,-1
        JE _CCL_23
        CMP ECX,0
        JE _CCL_24
        CMP ECX,1
        JE _CCL_25
        JMP _CCL_22
_CCL_23:
        MOV EAX,1
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_22
_CCL_24:
        MOV EAX,2
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_22
_CCL_25:
        MOV EAX,3
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_22
_CCL_22:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_21
_CCL_21:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_switch_in_loop ---
_CCF_test_switch_in_loop:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,8
;   param n = [EBP+8]
;   local s = [EBP-4]
        MOV DWORD PTR [EBP-4],0
;   local i = [EBP-8]
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        MOV DWORD PTR [EBP-8],EAX
_CCL_27:
        MOV EAX,DWORD PTR [EBP-8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+8]
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
        MOV EAX,DWORD PTR [EBP-8]
        MOV ECX,EAX
; switch (valeur dans ECX)
        CMP ECX,0
        JE _CCL_33
        CMP ECX,1
        JE _CCL_34
        CMP ECX,2
        JE _CCL_35
        JMP _CCL_36
_CCL_33:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_32
_CCL_34:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,10
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_32
_CCL_35:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,100
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_32
_CCL_36:
        MOV EAX,DWORD PTR [EBP-4]
        PUSH EAX
        MOV EAX,1000
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_32
_CCL_32:
_CCL_28:
        MOV EAX,DWORD PTR [EBP-8]
        INC EAX
        MOV DWORD PTR [EBP-8],EAX
        JMP _CCL_27
_CCL_29:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_26
_CCL_26:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: test_switch_char ---
_CCF_test_switch_char:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
;   param c = [EBP+8]
;   local r = [EBP-4]
        MOV DWORD PTR [EBP-4],0
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP+8]
        MOV ECX,EAX
; switch (valeur dans ECX)
        CMP ECX,65
        JE _CCL_39
        CMP ECX,66
        JE _CCL_40
        JMP _CCL_41
_CCL_39:
        MOV EAX,1
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_38
_CCL_40:
        MOV EAX,2
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_38
_CCL_41:
        MOV EAX,0
        MOV DWORD PTR [EBP-4],EAX
        JMP _CCL_38
_CCL_38:
        MOV EAX,DWORD PTR [EBP-4]
        JMP _CCL_37
_CCL_37:
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
        CALL _CCF_test_switch_basic
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,2
        PUSH EAX
        CALL _CCF_test_switch_basic
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,3
        PUSH EAX
        CALL _CCF_test_switch_basic
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,99
        PUSH EAX
        CALL _CCF_test_switch_basic
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,10
        PUSH EAX
        CALL _CCF_test_switch_default
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        PUSH EAX
        CALL _CCF_test_switch_default
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,1
        PUSH EAX
        CALL _CCF_test_switch_fallthrough
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,2
        PUSH EAX
        CALL _CCF_test_switch_fallthrough
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,3
        PUSH EAX
        CALL _CCF_test_switch_fallthrough
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,99
        PUSH EAX
        CALL _CCF_test_switch_fallthrough
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,1
        PUSH EAX
        CALL _CCF_test_switch_no_default
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,2
        PUSH EAX
        CALL _CCF_test_switch_no_default
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,99
        PUSH EAX
        CALL _CCF_test_switch_no_default
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,1
        NEG EAX
        PUSH EAX
        CALL _CCF_test_switch_negative
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        PUSH EAX
        CALL _CCF_test_switch_negative
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,1
        PUSH EAX
        CALL _CCF_test_switch_negative
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,5
        PUSH EAX
        CALL _CCF_test_switch_in_loop
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,65
        PUSH EAX
        CALL _CCF_test_switch_char
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,66
        PUSH EAX
        CALL _CCF_test_switch_char
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,67
        PUSH EAX
        CALL _CCF_test_switch_char
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,0
        JMP _CCL_42
_CCL_42:
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
