; Test 02 - Operations arithmetiques
; Teste: ADD, SUB, MUL, DIV, INC, DEC, NEG

.MODEL SMALL
.STACK 100h

.DATA
val1 DW 10
val2 DW 20
result DW 0

.CODE
START:
    MOV AX, @DATA
    MOV DS, AX

    ; Addition
    MOV AX, val1
    ADD AX, val2
    MOV result, AX

    ; Soustraction
    MOV AX, val2
    SUB AX, val1
    MOV result, AX

    ; Increment / Decrement
    MOV CX, 5
    INC CX
    DEC CX

    ; Negation
    MOV AX, 42
    NEG AX

    ; Multiplication
    MOV AX, 6
    MOV BX, 7
    MUL BX

    ; Division
    MOV AX, 100
    MOV BL, 10
    DIV BL

    MOV AH, 4Ch
    INT 21h
END START
