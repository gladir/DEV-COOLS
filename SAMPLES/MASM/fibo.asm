; fibo.asm - Test 6 : boucle LOOP
; Calcule les 10 premiers nombres de Fibonacci dans un tableau
; Utilise SI/DI comme indices, boucle LOOP

        .MODEL  SMALL
        .STACK  256

        .DATA
fib0    DW      0
fib1    DW      1
fib2    DW      0
fib3    DW      0
fib4    DW      0
fib5    DW      0
fib6    DW      0
fib7    DW      0
fib8    DW      0
fib9    DW      0

        .CODE
main    PROC
        MOV     AX, @DATA
        MOV     DS, AX

        ; fib[n] = fib[n-1] + fib[n-2]
        ; calculer fib2..fib9 en utilisant les valeurs precedentes
        MOV     AX, fib1
        ADD     AX, fib0
        MOV     fib2, AX   ; 0+1=1

        MOV     AX, fib2
        ADD     AX, fib1
        MOV     fib3, AX   ; 1+1=2

        MOV     AX, fib3
        ADD     AX, fib2
        MOV     fib4, AX   ; 2+1=3

        MOV     AX, fib4
        ADD     AX, fib3
        MOV     fib5, AX   ; 3+2=5

        ; boucle LOOP pour fib6..fib9
        MOV     SI, OFFSET fib4   ; fib[n-2]
        MOV     DI, OFFSET fib5   ; fib[n-1]
        MOV     CX, 4             ; 4 iterations : fib6, fib7, fib8, fib9
fib_loop:
        MOV     AX, [SI]
        MOV     BX, [DI]
        ADD     AX, BX
        MOV     [DI+2], AX        ; fib[n] = fib[n-1] + fib[n-2]
        ADD     SI, 2
        ADD     DI, 2
        LOOP    fib_loop

        INT     20h
main    ENDP

        END     main
