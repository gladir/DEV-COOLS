; callsub.asm - Test 3 : PROC/ENDP, CALL/RET, convention C
; Sous-programme add_ab retourne AX = param1 + param2

        .MODEL  SMALL
        .STACK  256

        .DATA
result  DW      0   ; stockage du resultat

        .CODE

; add_ab NEAR : empile arg2 puis arg1, retourne AX = arg1+arg2
add_ab  PROC    NEAR
        PUSH    BP
        MOV     BP, SP
        MOV     AX, [BP+4]   ; arg1
        ADD     AX, [BP+6]   ; arg2
        POP     BP
        RET
add_ab  ENDP

main    PROC
        MOV     AX, @DATA
        MOV     DS, AX

        ; appel : add_ab(10, 20) -> attendu AX=30
        PUSH    20
        PUSH    10
        CALL    add_ab
        ADD     SP, 4
        MOV     result, AX

        INT     20h
main    ENDP

        END     main
