; logic.asm - Tests des instructions logiques et de manipulation de bits
; Instructions : AND, ANDI, OR, ORI, EOR, EORI, NOT,
;                BTST, BSET, BCLR, BCHG
; Valider avec : asm68 logic.asm

    ORG       $1000

start:
    ; --- AND : ET logique ---
    MOVE.L    #$FF00FF00, D0
    MOVE.L    #$0F0F0F0F, D1
    AND.L     D0, D1             ; D1 = $0F000F00

    ; --- ANDI : ET immediat ---
    MOVE.L    #$FFFFFFFF, D0
    ANDI.L    #$000000FF, D0     ; D0 = $000000FF

    ; --- ANDI CCR : masquer drapeaux ---
    ANDI      #$00, CCR          ; Effacer tous les drapeaux

    ; --- OR : OU logique ---
    MOVE.L    #$FF000000, D0
    MOVE.L    #$00FF0000, D1
    OR.L      D0, D1             ; D1 = $FFFF0000

    ; --- ORI : OU immediat ---
    MOVE.L    #$00000000, D0
    ORI.L     #$80000001, D0     ; D0 = $80000001

    ; --- ORI CCR : positionner drapeaux ---
    ORI       #$01, CCR          ; Positionner le drapeau C

    ; --- EOR : OU exclusif ---
    MOVE.L    #$AAAAAAAA, D0
    MOVE.L    #$55555555, D1
    EOR.L     D0, D1             ; D1 = $FFFFFFFF

    ; --- EORI : XOR immediat ---
    MOVE.L    #$FF00FF00, D0
    EORI.L    #$FFFFFFFF, D0     ; D0 = $00FF00FF (complement)

    ; --- NOT : complement a un ---
    MOVE.L    #$00000000, D0
    NOT.L     D0                 ; D0 = $FFFFFFFF
    NOT.L     D0                 ; D0 = $00000000

    ; --- BTST : tester un bit ---
    MOVE.L    #$80, D0
    BTST      #7, D0             ; Z=0 (bit 7 est 1)
    BTST      #0, D0             ; Z=1 (bit 0 est 0)

    ; --- BSET : tester et positionner un bit ---
    MOVEQ     #0, D0
    BSET      #0, D0             ; D0 = 1, Z etait 1

    ; --- BCLR : tester et effacer un bit ---
    MOVE.L    #$FF, D0
    BCLR      #0, D0             ; D0 = $FE, Z etait 0

    ; --- BCHG : tester et inverser un bit ---
    MOVE.L    #$AA, D0
    BCHG      #0, D0             ; D0 = $AB (bit 0 inverse)
    BCHG      #0, D0             ; D0 = $AA (bit 0 re-inverse)

    ; Terminer
    MOVE.B    #9, D0
    TRAP      #15

    END       start
