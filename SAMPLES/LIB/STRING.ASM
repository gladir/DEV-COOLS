; STRING.ASM - Module de fonctions de chaines
; Exemple pour tester la commande LIB

.MODEL SMALL
.CODE

; Fonction STRLEN - Calcule la longueur d'une chaine
; Entree: DS:SI = pointeur vers la chaine (terminee par 0)
; Sortie: CX = longueur
PUBLIC STRLEN
STRLEN PROC
    PUSH SI
    XOR CX, CX
STRLEN_LOOP:
    LODSB
    OR AL, AL
    JZ STRLEN_END
    INC CX
    JMP STRLEN_LOOP
STRLEN_END:
    POP SI
    RET
STRLEN ENDP

; Fonction STRCPY - Copie une chaine
; Entree: DS:SI = source, ES:DI = destination
PUBLIC STRCPY
STRCPY PROC
STRCPY_LOOP:
    LODSB
    STOSB
    OR AL, AL
    JNZ STRCPY_LOOP
    RET
STRCPY ENDP

END
