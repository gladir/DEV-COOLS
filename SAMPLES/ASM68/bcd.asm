; bcd.asm - Tests des operations BCD (Binary Coded Decimal)
; Instructions : ABCD, SBCD, NBCD
; Valider avec : asm68 bcd.asm

    ORG       $1000

start:
    ; --- ABCD : addition BCD avec registres ---
    ; 25 + 37 = 62 en BCD
    ANDI      #$EF, CCR          ; Effacer X (pas de retenue)
    MOVE.B    #$25, D0           ; 25 en BCD
    MOVE.B    #$37, D1           ; 37 en BCD
    ABCD      D0, D1             ; D1.B = $62

    ; --- ABCD : addition BCD avec retenue ---
    ; 99 + 01 = 00 avec retenue (X=1)
    ANDI      #$EF, CCR          ; Effacer X
    MOVE.B    #$99, D0           ; 99 en BCD
    MOVE.B    #$01, D1           ; 01 en BCD
    ABCD      D0, D1             ; D1.B = $00, X=1 (retenue)

    ; --- SBCD : soustraction BCD avec registres ---
    ; 50 - 23 = 27 en BCD
    ANDI      #$EF, CCR          ; Effacer X
    MOVE.B    #$23, D0           ; 23 en BCD
    MOVE.B    #$50, D1           ; 50 en BCD
    SBCD      D0, D1             ; D1.B = $27

    ; --- SBCD : soustraction BCD avec emprunt ---
    ; 10 - 25 = 85 avec emprunt (X=1)
    ANDI      #$EF, CCR          ; Effacer X
    MOVE.B    #$25, D0           ; 25 en BCD
    MOVE.B    #$10, D1           ; 10 en BCD
    SBCD      D0, D1             ; D1.B = $85, X=1 (emprunt)

    ; --- NBCD : negation BCD ---
    ANDI      #$EF, CCR          ; Effacer X
    MOVE.B    #$25, D0           ; 25 en BCD
    NBCD      D0                 ; D0 = complement 10 de 25 = 75

    ; --- ABCD avec memoire (pre-decrement) ---
    LEA       bcd_a+2, A0        ; Fin du nombre BCD A
    LEA       bcd_b+2, A1        ; Fin du nombre BCD B
    ANDI      #$EF, CCR          ; Effacer X
    ABCD      -(A0), -(A1)       ; Addition BCD octet par octet
    ABCD      -(A0), -(A1)       ; Deuxieme octet

    ; Terminer
    MOVE.B    #9, D0
    TRAP      #15

; --- Donnees BCD ---
bcd_a:
    DC.B      $12, $34           ; Nombre BCD 1234
bcd_b:
    DC.B      $56, $78           ; Nombre BCD 5678

    END       start
