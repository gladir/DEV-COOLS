; Test 04 - Sauts conditionnels et boucles
; Teste: JMP, JE, JNE, JG, JL, LOOP, CMP

.MODEL SMALL
.STACK 100h

.DATA
counter DW 0

.CODE
START:
    MOV AX, @DATA
    MOV DS, AX

    ; Saut inconditionnel
    JMP skip_this
    MOV AX, 999
skip_this:

    ; Boucle LOOP
    MOV CX, 10
loop_start:
    INC counter
    LOOP loop_start

    ; Comparaison avec sauts conditionnels
    MOV AX, 5
    CMP AX, 10
    JE equal_label
    JG greater_label
    JL less_label

less_label:
    MOV BX, 1
    JMP done_cmp

equal_label:
    MOV BX, 0
    JMP done_cmp

greater_label:
    MOV BX, 2

done_cmp:
    MOV AH, 4Ch
    INT 21h
END START
