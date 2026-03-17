; listing.asm - Tests des directives de listing
; Directives : TTL, SPC, PAGE, LIST, NOLIST, OPT
; Valider avec : asm68 listing.asm -l listing.lst -s

    TTL       'Test des directives de listing ASM68'

    ORG       $1000

; --- Code visible dans le listing ---
    LIST                         ; Activer le listing
start:
    MOVEQ     #0, D0
    MOVEQ     #0, D1

    SPC       2                  ; 2 lignes blanches dans le listing

    ; --- Section non listee ---
    NOLIST                       ; Desactiver le listing
    MOVEQ     #1, D2             ; Cette ligne n'apparait pas
    MOVEQ     #2, D3             ; Cette ligne non plus
    LIST                         ; Reactiver le listing

    ; --- Continuation du listing ---
    MOVE.L    #$DEADBEEF, D4
    MOVE.L    #$CAFEBABE, D5

    PAGE                         ; Saut de page dans le listing

    ; --- Utilisation de constantes ---
MAX_ITER    EQU   10
    MOVE.L    #MAX_ITER, D6

    ; Terminer
    MOVE.B    #9, D0
    TRAP      #15

    END       start
