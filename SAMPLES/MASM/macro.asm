; macro.asm - Test 4 : MACRO, LOCAL, expansion multiple
; Macros sans parametres pour test de base

        .MODEL  SMALL
        .STACK  256

; -- Macro : ABS_AX - valeur absolue de AX dans AX
ABS_AX  MACRO
        LOCAL   skipneg
        OR      AX, AX
        JNS     skipneg
        NEG     AX
skipneg:
        ENDM

; -- Macro : ZERO_AX - met AX a zero
ZERO_AX MACRO
        XOR     AX, AX
        ENDM

; -- Macro : SWAP_AX_BX - echanger AX et BX
SWAP_AX_BX MACRO
        XCHG    AX, BX
        ENDM

        .DATA
result1 DW      0   ; resultat ABS(-5) -> 5
result2 DW      0   ; resultat ZERO_AX -> 0
result3 DW      0   ; resultat SWAP    -> 200

        .CODE
main    PROC
        MOV     AX, @DATA
        MOV     DS, AX

        ; tester ABS_AX
        MOV     AX, 0FFFBh
        ABS_AX
        MOV     result1, AX   ; doit etre 5

        ; tester ZERO_AX (expansion multiple)
        MOV     AX, 1234h
        ZERO_AX
        MOV     result2, AX   ; doit etre 0

        ; tester SWAP_AX_BX
        MOV     AX, 100
        MOV     BX, 200
        SWAP_AX_BX
        MOV     result3, AX   ; doit etre 200

        INT     20h
main    ENDP

        END     main
