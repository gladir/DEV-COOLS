; test_logic.asm - Tests complets des instructions logiques et manipulation de bits
; Instructions : AND, ANDI, OR, ORI, EOR, EORI, NOT, BTST, BSET, BCLR, BCHG
; TODO 13 - Validation exhaustive

    ORG       $1000

start:

; =====================================================================
; AND - ET logique (deux formes)
; =====================================================================

    ; AND.B ea, Dn
    AND.B     D0, D1
    AND.B     (A0), D2
    AND.B     (A1)+, D3
    AND.B     -(A2), D4

    ; AND.W ea, Dn
    AND.W     D5, D6
    AND.W     (A3), D7
    AND.W     $1234, D0

    ; AND.L ea, Dn
    AND.L     D1, D2
    AND.L     (A0), D3
    AND.L     #$FF00FF00, D4

    ; AND.B Dn, ea (destination memoire)
    AND.B     D0, (A0)
    AND.B     D1, (A1)+
    AND.B     D2, -(A2)

    ; AND.W Dn, ea
    AND.W     D3, (A3)
    AND.W     D4, $2000

    ; AND.L Dn, ea
    AND.L     D5, (A4)
    AND.L     D6, (A5)+

; =====================================================================
; ANDI - ET immediat
; =====================================================================

    ; ANDI.B #imm, ea
    ANDI.B    #$0F, D0
    ANDI.B    #$FF, (A0)

    ; ANDI.W #imm, ea
    ANDI.W    #$00FF, D1
    ANDI.W    #$FF00, (A1)

    ; ANDI.L #imm, ea
    ANDI.L    #$000000FF, D2
    ANDI.L    #$FFFF0000, (A2)

    ; ANDI #imm, CCR
    ANDI      #$00, CCR
    ANDI      #$1F, CCR

    ; ANDI #imm, SR
    ANDI      #$F8FF, SR

; =====================================================================
; OR - OU logique (deux formes)
; =====================================================================

    ; OR.B ea, Dn
    OR.B      D0, D1
    OR.B      (A0), D2
    OR.B      (A1)+, D3

    ; OR.W ea, Dn
    OR.W      D4, D5
    OR.W      (A2), D6
    OR.W      #$8000, D7

    ; OR.L ea, Dn
    OR.L      D0, D1
    OR.L      (A3), D2
    OR.L      $3000, D3

    ; OR.B Dn, ea (destination memoire)
    OR.B      D0, (A0)
    OR.B      D1, (A1)+

    ; OR.W Dn, ea
    OR.W      D2, (A2)
    OR.W      D3, -(A3)

    ; OR.L Dn, ea
    OR.L      D4, (A4)
    OR.L      D5, $4000

; =====================================================================
; ORI - OU immediat
; =====================================================================

    ; ORI.B #imm, ea
    ORI.B     #$80, D0
    ORI.B     #$01, (A0)

    ; ORI.W #imm, ea
    ORI.W     #$8000, D1
    ORI.W     #$0001, (A1)

    ; ORI.L #imm, ea
    ORI.L     #$80000001, D2
    ORI.L     #$FF000000, (A2)

    ; ORI #imm, CCR
    ORI       #$01, CCR
    ORI       #$10, CCR

    ; ORI #imm, SR
    ORI       #$2000, SR

; =====================================================================
; EOR - OU exclusif (uniquement Dn, ea)
; =====================================================================

    ; EOR.B Dn, ea
    EOR.B     D0, D1
    EOR.B     D2, (A0)
    EOR.B     D3, (A1)+

    ; EOR.W Dn, ea
    EOR.W     D4, D5
    EOR.W     D6, (A2)
    EOR.W     D7, -(A3)

    ; EOR.L Dn, ea
    EOR.L     D0, D1
    EOR.L     D2, (A4)
    EOR.L     D3, $5000

; =====================================================================
; EORI - XOR immediat
; =====================================================================

    ; EORI.B #imm, ea
    EORI.B    #$FF, D0
    EORI.B    #$AA, (A0)

    ; EORI.W #imm, ea
    EORI.W    #$FFFF, D1
    EORI.W    #$5555, (A1)

    ; EORI.L #imm, ea
    EORI.L    #$FFFFFFFF, D2
    EORI.L    #$AA55AA55, (A2)

    ; EORI #imm, CCR
    EORI      #$1F, CCR

    ; EORI #imm, SR
    EORI      #$2000, SR

; =====================================================================
; NOT - complement a un (inversion de tous les bits)
; =====================================================================

    ; NOT.B ea
    NOT.B     D0
    NOT.B     (A0)
    NOT.B     (A1)+

    ; NOT.W ea
    NOT.W     D1
    NOT.W     (A2)
    NOT.W     -(A3)

    ; NOT.L ea
    NOT.L     D2
    NOT.L     (A4)
    NOT.L     $6000

; =====================================================================
; BTST - tester un bit (resultat dans Z)
; =====================================================================

    ; BTST #imm, ea (forme statique)
    BTST      #7, D0
    BTST      #0, D1
    BTST      #31, D2
    BTST      #3, (A0)
    BTST      #7, (A1)+

    ; BTST Dn, ea (forme dynamique)
    BTST      D0, D1
    BTST      D2, (A0)
    BTST      D3, (A1)+
    BTST      D4, -(A2)
    BTST      D5, $7000

; =====================================================================
; BSET - tester et positionner un bit
; =====================================================================

    ; BSET #imm, ea (forme statique)
    BSET      #0, D0
    BSET      #7, (A0)
    BSET      #15, D1

    ; BSET Dn, ea (forme dynamique)
    BSET      D0, D1
    BSET      D2, (A0)
    BSET      D3, (A1)+

; =====================================================================
; BCLR - tester et effacer un bit
; =====================================================================

    ; BCLR #imm, ea (forme statique)
    BCLR      #0, D0
    BCLR      #7, (A0)
    BCLR      #31, D1

    ; BCLR Dn, ea (forme dynamique)
    BCLR      D0, D1
    BCLR      D2, (A0)
    BCLR      D3, -(A2)

; =====================================================================
; BCHG - tester et inverser un bit
; =====================================================================

    ; BCHG #imm, ea (forme statique)
    BCHG      #0, D0
    BCHG      #7, (A0)
    BCHG      #15, D1

    ; BCHG Dn, ea (forme dynamique)
    BCHG      D0, D1
    BCHG      D2, (A0)
    BCHG      D3, (A1)+

; =====================================================================
; Fin du programme
; =====================================================================

    MOVE.B    #9, D0
    TRAP      #15

    END       start
