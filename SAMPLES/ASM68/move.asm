; move.asm - Tests des instructions de transfert de donnees
; Instructions : MOVE, MOVEA, MOVEQ, MOVEM, MOVEP, LEA, PEA,
;                EXG, SWAP, LINK, UNLK
; Valider avec : asm68 move.asm

    ORG       $1000

start:
    ; --- MOVE : transferts generaux ---
    MOVE.L    #$12345678, D0     ; Chargement immediat long
    MOVE.W    #$ABCD, D1         ; Chargement immediat mot
    MOVE.B    #$42, D2           ; Chargement immediat octet
    MOVE.L    D0, D3             ; Registre a registre
    MOVE.W    D1, D4             ; Registre a registre (mot)
    MOVE.B    D2, D5             ; Registre a registre (octet)

    ; --- MOVEA : transfert vers registre d'adresse ---
    MOVEA.L   #$00002000, A0     ; Charger adresse dans A0
    MOVEA.L   A0, A1             ; Copie registre adresse
    MOVEA.W   #$1000, A2         ; Mot signe-etendu a 32 bits

    ; --- MOVEQ : chargement rapide 8 bits ---
    MOVEQ     #0, D0             ; Mise a zero rapide
    MOVEQ     #-1, D1            ; D1 = $FFFFFFFF
    MOVEQ     #127, D2           ; Valeur max positive
    MOVEQ     #-128, D3          ; Valeur min negative

    ; --- MOVEM : sauvegarde/restauration de registres ---
    MOVEM.L   D0-D7/A0-A6, -(A7)  ; Sauvegarder tous les registres
    MOVEM.L   (A7)+, D0-D7/A0-A6  ; Restaurer tous les registres
    MOVEM.L   D0-D3/A0-A1, -(A7)  ; Sauvegarder selection
    MOVEM.L   (A7)+, D0-D3/A0-A1  ; Restaurer selection

    ; --- LEA : chargement d'adresse ---
    LEA       data1(PC), A0      ; Adresse relative PC
    LEA       $2000, A1          ; Adresse absolue

    ; --- PEA : empiler adresse ---
    PEA       data1(PC)          ; Empiler adresse relative PC
    ADDQ.L    #4, A7             ; Nettoyer la pile

    ; --- EXG : echange de registres ---
    EXG       D0, D1             ; Echanger deux registres donnees
    EXG       A0, A1             ; Echanger deux registres adresses
    EXG       D0, A0             ; Echanger donnee et adresse

    ; --- SWAP : echanger moities 16 bits ---
    MOVE.L    #$AABB0011, D0
    SWAP      D0                 ; D0 = $0011AABB

    ; --- LINK / UNLK : cadre de pile ---
    LINK      A6, #-8            ; Creer cadre avec 8 octets locaux
    UNLK      A6                 ; Detruire le cadre

    ; Terminer
    MOVE.B    #9, D0
    TRAP      #15

data1:
    DC.L      $DEADBEEF

    END       start
