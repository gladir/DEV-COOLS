; test_transfer.asm - Tests des instructions de transfert de donnees (TODO 11)
; Instructions : MOVE, MOVEA, MOVEQ, MOVEM, MOVEP, LEA, PEA,
;                EXG, SWAP, LINK, UNLK, MOVE SR/CCR
; Valider avec : asm68 test_transfer.asm -> 0 erreurs

    ORG       $1000

start:

    ; ================================================================
    ; MOVE : transferts generaux
    ; ================================================================
    ; Registre a registre
    MOVE.L    D0, D1
    MOVE.W    D2, D3
    MOVE.B    D4, D5
    ; Immediat vers registre
    MOVE.L    #$12345678, D0
    MOVE.W    #$ABCD, D1
    MOVE.B    #$42, D2
    ; Registre vers memoire (indirect)
    MOVE.L    D0, (A0)
    MOVE.W    D1, (A1)
    MOVE.B    D2, (A2)
    ; Memoire vers registre (indirect)
    MOVE.L    (A0), D3
    MOVE.W    (A1), D4
    MOVE.B    (A2), D5
    ; Post-increment et pre-decrement
    MOVE.L    (A0)+, D6
    MOVE.W    D7, -(A7)
    ; Deplacement
    MOVE.W    4(A0), D0
    MOVE.L    D1, -8(A2)
    ; Adresse absolue courte
    MOVE.W    $100, D0
    ; Adresse absolue longue
    MOVE.L    D0, $20000
    ; Immediat vers memoire
    MOVE.L    #$DEAD, (A0)
    MOVE.W    #0, 4(A1)

    ; ================================================================
    ; MOVEA : transfert vers registre d'adresse
    ; ================================================================
    MOVEA.L   #$00002000, A0
    MOVEA.L   A0, A1
    MOVEA.W   #$1000, A2
    MOVEA.L   D0, A3
    MOVEA.W   (A0), A4
    MOVEA.L   (A1)+, A5

    ; ================================================================
    ; MOVEQ : chargement rapide 8 bits
    ; ================================================================
    MOVEQ     #0, D0
    MOVEQ     #1, D1
    MOVEQ     #-1, D2
    MOVEQ     #127, D3
    MOVEQ     #-128, D4
    MOVEQ     #$42, D5
    MOVEQ     #$7F, D6
    MOVEQ     #-100, D7

    ; ================================================================
    ; MOVEM : sauvegarde/restauration de registres multiples
    ; ================================================================
    MOVEM.L   D0-D7/A0-A6, -(A7)
    MOVEM.L   (A7)+, D0-D7/A0-A6
    MOVEM.W   D0-D3/A0-A1, -(A7)
    MOVEM.W   (A7)+, D0-D3/A0-A1
    MOVEM.L   D0/D2/D4, -(A7)
    MOVEM.L   (A7)+, D0/D2/D4

    ; ================================================================
    ; MOVEP : transfert peripherique (octets alternes)
    ; ================================================================
    MOVEP.W   D0, 0(A0)
    MOVEP.L   D1, 4(A0)
    MOVEP.W   0(A0), D2
    MOVEP.L   4(A0), D3

    ; ================================================================
    ; LEA : charger adresse effective
    ; ================================================================
    LEA       buffer(PC), A0
    LEA       $2000, A1
    LEA       8(A2), A3
    LEA       (A4), A5

    ; ================================================================
    ; PEA : empiler adresse effective
    ; ================================================================
    PEA       buffer(PC)
    PEA       $3000
    PEA       (A0)
    PEA       4(A1)

    ; ================================================================
    ; EXG : echange de registres
    ; ================================================================
    EXG       D0, D1
    EXG       D2, D7
    EXG       A0, A1
    EXG       A3, A6
    EXG       D0, A0
    EXG       D5, A3

    ; ================================================================
    ; SWAP : echanger moities 16 bits
    ; ================================================================
    SWAP      D0
    SWAP      D7
    SWAP      D3

    ; ================================================================
    ; LINK / UNLK : cadre de pile
    ; ================================================================
    LINK      A6, #-8
    LINK      A5, #-256
    LINK      A6, #0
    UNLK      A6
    UNLK      A5

    ; ================================================================
    ; MOVE SR/CCR : formes speciales
    ; ================================================================
    MOVE.W    SR, D0
    MOVE.W    CCR, D0
    MOVE.W    D0, CCR
    MOVE.W    D0, SR
    MOVE.W    #$0700, SR

    ; Terminer
    RTS

buffer:
    DC.L      $DEADBEEF
    DC.L      $CAFEBABE

    END       start
