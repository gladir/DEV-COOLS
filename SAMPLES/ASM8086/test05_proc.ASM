; Test 05 - Procedures et appels
; Teste: PROC, ENDP, CALL, RET, PUSH, POP

.MODEL SMALL
.STACK 100h

.DATA
value DW 0

.CODE

; Procedure simple
AddValues PROC NEAR
    PUSH BP
    MOV BP, SP
    MOV AX, BX
    ADD AX, CX
    POP BP
    RET
AddValues ENDP

; Procedure avec retour dans AX
Square PROC NEAR
    PUSH BP
    MOV BP, SP
    MUL AX
    POP BP
    RET
Square ENDP

START:
    MOV AX, @DATA
    MOV DS, AX

    ; Appeler AddValues
    MOV BX, 3
    MOV CX, 4
    CALL AddValues
    MOV value, AX

    ; Appeler Square
    MOV AX, 5
    CALL Square
    MOV value, AX

    MOV AH, 4Ch
    INT 21h
END START
