; hello.asm - Test 1 : affichage d'un message sous DOS
; .MODEL SMALL / .DATA + .CODE / INT 21h / INT 20h
; Valider avec : MASM hello.asm ; TLINK hello.obj ; hello.exe

        .MODEL  SMALL
        .STACK  256

        .DATA
msg     DB      'Bonjour, MASM.PAS !', 0Dh, 0Ah, '$'

        .CODE
start:
        MOV     AX, @DATA
        MOV     DS, AX

        ; afficher la chaine (INT 21h, AH=09h)
        MOV     AH, 09h
        LEA     DX, msg
        INT     21h

        ; terminer le programme (INT 20h)
        INT     20h

        END     start
