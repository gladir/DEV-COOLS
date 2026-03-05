; arith.asm - Test 2 : operations arithmetiques ADD SUB MUL DIV
; resultats stockes en memoire, verifiables avec debugger

        .MODEL  SMALL
        .STACK  256

        .DATA
val_a   DW      1234
val_b   DW      56
res_add DW      0       ; attendu : 1290
res_sub DW      0       ; attendu : 1178
res_mul DW      0       ; attendu : bas 16 bits de 1234*56 = 69104
res_div DW      0       ; attendu : 1234 / 56 = 22 (quotient)
res_mod DW      0       ; attendu : 1234 mod 56 = 2 (reste)

        .CODE
main    PROC
        MOV     AX, @DATA
        MOV     DS, AX

        ; ADD
        MOV     AX, val_a
        ADD     AX, val_b
        MOV     res_add, AX

        ; SUB
        MOV     AX, val_a
        SUB     AX, val_b
        MOV     res_sub, AX

        ; MUL (unsigned : DX:AX = AX * src)
        MOV     AX, val_a
        MUL     val_b
        MOV     res_mul, AX   ; partie basse

        ; DIV (unsigned : AX = DX:AX / src, DX = reste)
        MOV     AX, val_a
        XOR     DX, DX
        DIV     val_b
        MOV     res_div, AX
        MOV     res_mod, DX

        INT     20h
main    ENDP

        END     main
