; test_macro.asm - Test de la gestion des macros MACRO/ENDM (TODO 22)
; Ce fichier teste les fonctionnalites avancees des macros :
;   1. Definition et expansion de macro simple
;   2. Macro avec parametres positionnels (\1, \2)
;   3. Macro avec parametres nommes (\param)
;   4. Etiquettes locales avec \@ (suffixe unique)
;   5. NARG : nombre d'arguments dans les expressions
;   6. MEXIT : sortie anticipee d'une expansion
;   7. Macros imbriquees (macro appelant une macro)
;   8. REPT/ENDR : repetition de bloc
;   9. Expansion avec limite de profondeur
;  10. Listing des macros expandees si -x active

    ORG   $1000

; --- 1. Macro simple sans parametres ---
CLRALL  MACRO
    CLR.L     D0
    CLR.L     D1
    ENDM

; --- 2. Macro avec parametres positionnels ---
LOAD2   MACRO
    MOVE.L    \1, D0
    MOVE.L    \2, D1
    ENDM

; --- 3. Macro avec parametres nommes ---
SETVAL  MACRO   dest, val
    MOVE.W    #\val, \dest
    ENDM

; --- 4. Macro avec etiquette locale \@ ---
WAIT    MACRO
    MOVE.W    \1, D7
.wt\@:
    SUBQ.W    #1, D7
    BNE       .wt\@
    ENDM

; --- 5. Macro utilisant NARG ---
PUSHN   MACRO
    DC.W      NARG
    ENDM

; --- 6. Macro avec MEXIT ---
CHKARG  MACRO
    MOVE.L    #0, D0
    MEXIT
    MOVE.L    #$FF, D0
    ENDM

; --- 7. Macros imbriquees : OUTER appelle INNER ---
INNER   MACRO
    ADDQ.L    #1, D2
    ENDM

OUTER   MACRO
    CLR.L     D2
    INNER
    INNER
    ENDM

; === Zone de code : expansions ===

START:
    ; 1. Macro simple
    CLRALL

    ; 2. Parametres positionnels
    LOAD2     #$1234, #$5678

    ; 3. Parametres nommes
    SETVAL    D3, $ABCD

    ; 4. Etiquettes locales (deux expansions = etiquettes differentes)
    WAIT      #10
    WAIT      #20

    ; 5. NARG
    PUSHN
    PUSHN     A,B,C

    ; 6. MEXIT (MOVE.L #$FF,D0 ne doit pas etre genere)
    CHKARG

    ; 7. Macros imbriquees
    OUTER

    ; 8. REPT/ENDR
    MOVEQ     #0, D5
    REPT      3
    ADDQ.L    #1, D5
    ENDR

    ; Terminer
    MOVE.B    #9, D0
    TRAP      #15

; --- Donnees ---
MSG:
    DC.B      'Macro OK', 0
    EVEN

    END       START
