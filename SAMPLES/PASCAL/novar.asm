; Programme: NOVAR
; Compilé par PC8086 - Compilateur Pascal vers 8086
; Date: 2026-02-28 16:12:52

.MODEL SMALL
.STACK 100h

.DATA

; Procédures d'aide pour l'affichage
PRINT_NUM PROC
; Affiche le nombre dans AX
    ; Implémentation simplifiée pour afficher un nombre
    ; (code complet requis pour conversion décimale)
    mov dx, ax
    add dl, 48  ; Convertir en ASCII (pour chiffres 0-9 seulement)
    mov ah, 02h
    int 21h
    ret
PRINT_NUM ENDP
