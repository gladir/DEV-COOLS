; Test 06 - Declarations de donnees variees
; Teste: DB, DW, DD, DUP, chaines

.MODEL SMALL
.STACK 100h

.DATA
byteVal DB 42
wordVal DW 1000
dwordVal DD 100000
message DB 'Bonjour$'
buffer DB 256 DUP(0)
table DW 1, 2, 3, 4, 5
flag DB 1
count DW 0
maxVal DW 65535

.CODE
START:
    MOV AX, @DATA
    MOV DS, AX

    ; Lire des donnees
    MOV AL, byteVal
    MOV BX, wordVal
    MOV CX, count
    MOV DX, maxVal

    ; Ecrire des donnees
    MOV byteVal, 0
    MOV wordVal, 500
    MOV flag, 0

    MOV AH, 4Ch
    INT 21h
END START
