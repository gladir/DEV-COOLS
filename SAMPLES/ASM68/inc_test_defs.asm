; inc_test_defs.asm - Fichier inclus par test_include.asm (TODO 21)
; Contient des definitions de constantes et etiquettes reutilisables

; --- Constantes ---
MAGIC_NUM   EQU   $DEAD
VERSION     EQU   $0100
BUF_SIZE    EQU   256

; --- Sous-routine incluse ---
inc_routine:
    MOVE.W  #MAGIC_NUM,D0
    RTS
