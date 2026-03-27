; Test 07 - Operations de pile
; Teste: PUSH, POP, PUSHF, POPF

.MODEL SMALL
.STACK 100h

.DATA

.CODE
START:
    MOV AX, @DATA
    MOV DS, AX

    ; Sauvegarder et restaurer des registres
    MOV AX, 1234h
    MOV BX, 5678h
    PUSH AX
    PUSH BX
    MOV AX, 0
    MOV BX, 0
    POP BX
    POP AX

    ; Sauvegarder les flags
    PUSHF
    CLC
    POPF

    MOV AH, 4Ch
    INT 21h
END START
