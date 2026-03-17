; macro.asm - Tests des macros et directives MACRO/ENDM, REPT/ENDR
; Valider avec : asm68 macro.asm -x

    ORG       $1000

; --- Definition de macros ---

; Macro pour afficher un message (TRAP #15 convention simulateur)
PRINT   MACRO
    LEA       \1(PC), A1         ; Adresse du message
    MOVE.B    #14, D0            ; Fonction affichage
    TRAP      #15                ; Appel systeme
    ENDM

; Macro pour terminer le programme
EXIT    MACRO
    MOVE.B    #9, D0             ; Fonction terminer
    TRAP      #15                ; Fin
    ENDM

; Macro avec plusieurs parametres
LOADREG MACRO
    MOVE.L    \1, \2             ; Charger valeur dans registre
    ENDM

; Macro pour sauvegarder/restaurer les registres
PUSHALL MACRO
    MOVEM.L   D0-D7/A0-A6, -(A7)
    ENDM

POPALL  MACRO
    MOVEM.L   (A7)+, D0-D7/A0-A6
    ENDM

; Macro avec etiquette locale (\@)
DELAY   MACRO
    MOVE.L    \1, D0
.loop\@:
    SUBQ.L    #1, D0
    BNE       .loop\@
    ENDM

start:
    ; --- Utilisation des macros ---
    PRINT     msg1               ; Expansion de la macro PRINT
    LOADREG   #$12345678, D0     ; Expansion avec 2 arguments
    LOADREG   #$AABBCCDD, D1     ; Autre expansion

    ; --- REPT : repetition de bloc ---
    MOVEQ     #0, D0
    REPT      4
    ADDQ.L    #1, D0             ; Execute 4 fois -> D0 = 4
    ENDR

    ; --- Macros de sauvegarde/restauration ---
    PUSHALL                      ; Sauvegarder tous les registres
    MOVEQ     #0, D0             ; Modifier D0
    POPALL                       ; Restaurer tous les registres

    ; --- Macro avec etiquette locale ---
    DELAY     #100               ; Boucle de delai
    DELAY     #50                ; Autre delai (etiquette differente)

    ; --- Affichage final ---
    PRINT     msg2
    EXIT

; --- Donnees ---
msg1:
    DC.B      'Test macros debut', $0D, $0A, 0
msg2:
    DC.B      'Test macros OK', $0D, $0A, 0

    END       start
