; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/main.c

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
;   local result = [EBP-4]
;   local y = [EBP-8]
; WARNING: variable non trouvee: Point
        XOR EAX,EAX
; WARNING: mot-cle inattendu dans expression: typedef
        XOR EAX,EAX
; WARNING: ponctuation inattendue: }
        XOR EAX,EAX
; WARNING: variable non trouvee: p
        XOR EAX,EAX
; WARNING: variable non trouvee: p
        XOR EAX,EAX
; WARNING: variable non trouvee: p
        XOR EAX,EAX
        PUSH EAX
; WARNING: variable non trouvee: p
        XOR EAX,EAX
        PUSH EAX
        CALL _CCF_multiply
        ADD ESP,8
        MOV DWORD PTR [EBP-4],EAX
_CCL_1:
        MOV ESP,EBP
        POP EBP
        RET

; --- Fonction: multiply ---
_CCF_multiply:
        PUSH EBP
        MOV EBP,ESP
;   param a = [EBP+8]
;   param b = [EBP+12]
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+12]
        MOV EBX,EAX
        POP EAX
        IMUL EAX,EBX
        JMP _CCL_2
_CCL_2:
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
