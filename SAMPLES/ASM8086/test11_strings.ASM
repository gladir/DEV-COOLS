; Test 11 - Fonctions de chaines C -> unite Strings
; Teste: CALL _strcmp, CALL _strcpy, CALL _strcat, CALL _strlen
; Le transpileur doit generer Uses Strings et appeler
; StrComp, StrCopy, StrCat, StrLen de l'unite Strings.

.MODEL SMALL
.STACK 100h

.DATA
src DB 'Hello', 0
dst DB 20 DUP(0)
buf DB 'World', 0

.CODE
START:
    MOV AX, @DATA
    MOV DS, AX

    ; Copier src -> dst  (strcpy)
    LEA AX, src
    PUSH AX
    LEA AX, dst
    PUSH AX
    CALL _strcpy
    ADD SP, 4

    ; Longueur de dst (strlen)
    LEA AX, dst
    PUSH AX
    CALL _strlen
    ADD SP, 2

    ; Concatener buf a dst (strcat)
    LEA AX, buf
    PUSH AX
    LEA AX, dst
    PUSH AX
    CALL _strcat
    ADD SP, 4

    ; Comparer src et dst (strcmp)
    LEA AX, dst
    PUSH AX
    LEA AX, src
    PUSH AX
    CALL _strcmp
    ADD SP, 4

    MOV AH, 4Ch
    INT 21h
END START
