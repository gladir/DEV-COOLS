; extern.asm - Test 5 : PUBLIC/EXTRN, FIXUPP vers sous-programme externe
; Ce module utilise sub_add defini dans extern_sub.asm
; Compiler : MASM extern.asm + MASM extern_sub.asm
; Linker  : TLINK extern.obj extern_sub.obj

        .MODEL  SMALL
        .STACK  256

        EXTRN   sub_add : NEAR  ; defini dans extern_sub.asm

        .DATA
result  DW      0

        .CODE
main    PROC
        MOV     AX, @DATA
        MOV     DS, AX

        ; appel externe : sub_add(100, 23) -> attendu AX = 123
        PUSH    23
        PUSH    100
        CALL    sub_add
        ADD     SP, 4
        MOV     result, AX

        INT     20h
main    ENDP

        END     main
