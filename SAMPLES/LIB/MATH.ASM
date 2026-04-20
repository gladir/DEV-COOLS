; MATH.ASM - Module de fonctions mathematiques simples
; Exemple pour tester la commande LIB

.MODEL SMALL
.CODE

; Fonction ADD16 - Addition de deux valeurs 16 bits
; Entree: AX = valeur 1, BX = valeur 2
; Sortie: AX = resultat
PUBLIC ADD16
ADD16 PROC
    ADD AX, BX
    RET
ADD16 ENDP

; Fonction SUB16 - Soustraction de deux valeurs 16 bits
; Entree: AX = valeur 1, BX = valeur 2
; Sortie: AX = resultat
PUBLIC SUB16
SUB16 PROC
    SUB AX, BX
    RET
SUB16 ENDP

; Fonction MUL16 - Multiplication de deux valeurs 16 bits
; Entree: AX = valeur 1, BX = valeur 2
; Sortie: DX:AX = resultat
PUBLIC MUL16
MUL16 PROC
    MUL BX
    RET
MUL16 ENDP

END
