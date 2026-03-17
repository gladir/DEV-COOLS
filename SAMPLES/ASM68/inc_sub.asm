; inc_sub.asm - Fichier inclus par include.asm
; Contient des sous-routines reutilisables

; --- print_string ---
; Affiche la chaine pointee par A1 (terminee par zero)
; Entree : A1 = adresse de la chaine
; Utilise : D0
print_string:
    MOVE.B    #14, D0            ; Fonction affichage
    TRAP      #15                ; Appel systeme
    RTS
