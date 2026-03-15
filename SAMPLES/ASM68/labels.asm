; labels.asm - Tests des etiquettes globales et locales
; Valider avec : asm68 labels.asm

    ORG       $1000

; --- Etiquettes globales ---
start:
    BSR       routine1
    BSR       routine2
    BRA       fin

; --- Routine 1 avec etiquettes locales ---
routine1:
    MOVEQ     #5, D0
.loop:
    SUBQ.L    #1, D0
    BNE       .loop              ; Etiquette locale a routine1
    RTS

; --- Routine 2 avec etiquettes locales (meme nom que routine1) ---
routine2:
    MOVEQ     #3, D1
.loop:
    SUBQ.L    #1, D1
    BNE       .loop              ; Etiquette locale a routine2
    RTS

; --- Etiquettes avec EQU ---
MAX_COUNT   EQU   100
BUFFER_SIZE EQU   256
STATUS_OK   EQU   0
STATUS_ERR  EQU   -1

; --- Utilisation des constantes ---
fin:
    MOVE.L    #MAX_COUNT, D0
    MOVE.L    #BUFFER_SIZE, D1
    MOVE.L    #STATUS_OK, D2

    ; Terminer
    MOVE.B    #9, D0
    TRAP      #15

    END       start
