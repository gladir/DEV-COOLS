; IO.ASM - Module de fonctions d'entree/sortie
; Exemple pour tester la commande LIB

.MODEL SMALL
.CODE

; Fonction PUTCHAR - Affiche un caractere
; Entree: AL = caractere a afficher
PUBLIC PUTCHAR
PUTCHAR PROC
    PUSH BX
    MOV AH, 0Eh
    MOV BH, 0
    INT 10h
    POP BX
    RET
PUTCHAR ENDP

; Fonction GETCHAR - Lit un caractere
; Sortie: AL = caractere lu
PUBLIC GETCHAR
GETCHAR PROC
    MOV AH, 00h
    INT 16h
    RET
GETCHAR ENDP

; Fonction NEWLINE - Affiche un retour a la ligne
PUBLIC NEWLINE
NEWLINE PROC
    PUSH AX
    MOV AL, 0Dh
    CALL PUTCHAR
    MOV AL, 0Ah
    CALL PUTCHAR
    POP AX
    RET
NEWLINE ENDP

END
