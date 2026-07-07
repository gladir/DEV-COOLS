; test09_conditional.asm - Test 9 : assemblage conditionnel IFDEF/ELSE/ENDIF
; et constantes EQU. Le code de sortie depend de la constante choisie.

.386
.MODEL FLAT
EXTERN ExitProcess:PROC

DEBUG_MODE EQU 1
EXPECTED   EQU 111

.CODE
start:
IFDEF DEBUG_MODE
        MOV EAX, 100
ELSE
        MOV EAX, 200
ENDIF

IF EXPECTED EQ 111
        ADD EAX, 11    ; 100 + 11 = 111 (attendu, puisque DEBUG_MODE est definie)
ELSE
        ADD EAX, 99
ENDIF

        ; code de sortie attendu : 111
        PUSH EAX
        CALL ExitProcess

END start
