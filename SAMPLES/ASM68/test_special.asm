; test_special.asm - Tests des instructions BCD et operations speciales (TODO 16)
; Instructions : ABCD, SBCD, NBCD, CHK, TRAP, TRAPV,
;                MOVE USP, STOP, RESET, ILLEGAL, NOP
; Valider avec : asm68 test_special.asm (0 erreurs, 0 avertissements)

    ORG       $1000

start:
    ; === ABCD : addition BCD registre a registre ===
    ABCD      D0, D1             ; D0 + D1 -> D1 (BCD)
    ABCD      D3, D7             ; D3 + D7 -> D7 (BCD)
    ABCD      D7, D0             ; D7 + D0 -> D0 (BCD)

    ; === ABCD : addition BCD memoire pre-decrement ===
    ABCD      -(A0), -(A1)       ; BCD add via memoire
    ABCD      -(A2), -(A3)       ; BCD add via memoire
    ABCD      -(A7), -(A6)       ; BCD add via memoire

    ; === SBCD : soustraction BCD registre a registre ===
    SBCD      D0, D1             ; D1 - D0 -> D1 (BCD)
    SBCD      D5, D2             ; D2 - D5 -> D2 (BCD)
    SBCD      D7, D7             ; D7 - D7 -> D7 (BCD)

    ; === SBCD : soustraction BCD memoire pre-decrement ===
    SBCD      -(A0), -(A1)       ; BCD sub via memoire
    SBCD      -(A4), -(A5)       ; BCD sub via memoire

    ; === NBCD : negation BCD ===
    NBCD      D0                 ; complement BCD de D0
    NBCD      D7                 ; complement BCD de D7
    NBCD      (A0)               ; complement BCD en memoire
    NBCD      (A3)+              ; complement BCD avec post-increment
    NBCD      -(A2)              ; complement BCD avec pre-decrement

    ; === CHK : verification de bornes ===
    CHK.W     D0, D1             ; verifier D1 dans [0..D0]
    CHK.W     D7, D0             ; verifier D0 dans [0..D7]
    CHK.W     (A0), D3           ; verifier D3 dans [0..(A0)]
    CHK.W     4(A1), D2          ; verifier D2 dans [0..d(A1)]
    CHK.W     #100, D0           ; verifier D0 dans [0..100]

    ; === TRAP : exception logicielle ===
    TRAP      #0                 ; vecteur 0
    TRAP      #1                 ; vecteur 1
    TRAP      #7                 ; vecteur 7
    TRAP      #14                ; vecteur 14
    TRAP      #15                ; vecteur 15

    ; === TRAPV : exception si overflow ===
    TRAPV                        ; piege si V=1

    ; === MOVE USP : pile utilisateur ===
    MOVE.L    USP, A0            ; lire USP dans A0
    MOVE.L    USP, A3            ; lire USP dans A3
    MOVE.L    USP, A7            ; lire USP dans A7
    MOVE.L    A0, USP            ; ecrire A0 dans USP
    MOVE.L    A5, USP            ; ecrire A5 dans USP
    MOVE.L    A7, USP            ; ecrire A7 dans USP

    ; === MOVE SR/CCR (deja impl. TODO 11, verif. non-regression) ===
    MOVE.W    SR, D0             ; lire SR
    MOVE.W    CCR, D1            ; lire CCR (68010+)
    MOVE.W    D0, SR             ; ecrire SR
    MOVE.W    D1, CCR            ; ecrire CCR

    ; === Terminer ===
    MOVE.B    #9, D0
    TRAP      #15

    ; === STOP : arreter le processeur ===
    STOP      #$2700             ; STOP avec SR=$2700

    ; === RESET : reinitialiser peripheriques ===
    RESET                        ; signal RESET

    ; === ILLEGAL : instruction illegale ===
    ILLEGAL                      ; declencher exception

    ; === NOP : (verification non-regression TODO 15) ===
    NOP
    NOP

    END       start
