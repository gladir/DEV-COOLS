; special.asm - Tests des instructions BCD et operations speciales
; Instructions : ABCD, SBCD, NBCD, CHK, TRAP, TRAPV,
;                MOVE SR/CCR/USP, STOP, RESET, ILLEGAL, NOP
; Valider avec : asm68 special.asm

    ORG       $1000

start:
    ; --- ABCD : addition BCD ---
    MOVE.B    #$25, D0           ; 25 en BCD
    MOVE.B    #$37, D1           ; 37 en BCD
    ABCD      D0, D1             ; D1 = $62 (25+37=62 en BCD)

    ; --- SBCD : soustraction BCD ---
    MOVE.B    #$50, D0           ; 50 en BCD
    MOVE.B    #$23, D1           ; 23 en BCD
    SBCD      D1, D0             ; D0 = $27 (50-23=27 en BCD)

    ; --- NBCD : negation BCD ---
    MOVE.B    #$25, D0
    NBCD      D0                 ; D0 = complement BCD de 25

    ; --- CHK : verification de bornes ---
    MOVE.W    #5, D0             ; Valeur a verifier
    MOVE.W    #10, D1            ; Borne superieure
    CHK.W     D1, D0             ; OK car 0 <= 5 <= 10

    ; --- TRAP : exception logicielle ---
    MOVE.B    #14, D0            ; Fonction affichage
    LEA       message(PC), A1    ; Adresse du message
    TRAP      #15                ; Appel simulateur

    ; --- NOP : pas d'operation ---
    NOP
    NOP
    NOP

    ; --- MOVE CCR : lire/ecrire condition codes ---
    MOVEQ     #0, D0
    TST.L     D0                 ; Positionner Z=1
    MOVE.W    CCR, D0            ; Lire les drapeaux dans D0

    ; --- ANDI/ORI avec CCR ---
    ORI       #$01, CCR          ; Positionner C
    ANDI      #$FE, CCR          ; Effacer C

    ; Terminer
    MOVE.B    #9, D0
    TRAP      #15

message:
    DC.B      'Test instructions speciales OK', $0D, $0A, 0

    END       start
