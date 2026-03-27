; Test 12 - Write/WriteLn console avec INT 21h/AH=09
; Teste: LEA DX, msg + INT 21h (AH=09) -> Write('...')
; Le transpileur doit generer Write('...') avec le contenu
; de la chaine DB associee au lieu d'un WriteLn generique.

.MODEL SMALL
.STACK 100h

.DATA
hello DB 'Hello, World!$'
bye   DB 'Goodbye!$'
num   DB 'Test 123$'

.CODE
START:
    MOV AX, @DATA
    MOV DS, AX

    ; Afficher "Hello, World!" avec LEA DX
    MOV AH, 09h
    LEA DX, hello
    INT 21h

    ; Afficher "Goodbye!" avec LEA DX
    MOV AH, 09h
    LEA DX, bye
    INT 21h

    ; Afficher "Test 123"
    MOV AH, 09h
    LEA DX, num
    INT 21h

    ; Afficher un caractere 'A' via AH=02
    MOV AH, 02h
    MOV DL, 41h
    INT 21h

    MOV AH, 4Ch
    INT 21h
END START
