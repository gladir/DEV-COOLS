; Test 01 - Programme Hello World simple (DOS)
; Teste: directives, donnees, INT 21h, MOV, Halt

.MODEL SMALL
.STACK 100h

.DATA
msg DB 'Hello, World!$'

.CODE
START:
    MOV AX, @DATA
    MOV DS, AX

    MOV AH, 09h
    LEA DX, msg
    INT 21h

    MOV AH, 4Ch
    MOV AL, 0
    INT 21h
END START
