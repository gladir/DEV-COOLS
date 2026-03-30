; Test 08 - Operations sur chaines
; Teste: STOSB, LODSB, MOVSB, REP

.MODEL SMALL
.STACK 100h

.DATA
source DB 'Hello', 0
dest DB 6 DUP(0)
buffer DB 10 DUP(0)

.CODE
START:
    MOV AX, @DATA
    MOV DS, AX
    MOV ES, AX

    ; Remplir un buffer avec 0
    LEA DI, buffer
    MOV CX, 10
    MOV AL, 0
    REP STOSB

    ; Copier une chaine
    LEA SI, source
    LEA DI, dest
    MOV CX, 6
    REP MOVSB

    MOV AH, 4Ch
    INT 21h
END START
