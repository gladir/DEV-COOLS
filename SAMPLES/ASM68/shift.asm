; shift.asm - Tests des instructions de decalage et rotation
; Instructions : ASL, ASR, LSL, LSR, ROL, ROR, ROXL, ROXR
; Valider avec : asm68 shift.asm

    ORG       $1000

start:
    ; --- ASL : decalage arithmetique gauche ---
    MOVE.L    #1, D0
    ASL.L     #4, D0             ; D0 = 16 ($10)
    MOVE.W    #$0001, D1
    ASL.W     #8, D1             ; D1.W = $0100

    ; --- ASR : decalage arithmetique droite ---
    MOVE.L    #$80000000, D0     ; Nombre negatif
    ASR.L     #4, D0             ; D0 = $F8000000 (signe preserve)
    MOVE.L    #256, D1
    ASR.L     #2, D1             ; D1 = 64

    ; --- LSL : decalage logique gauche ---
    MOVE.L    #$00000001, D0
    LSL.L     #1, D0             ; D0 = $00000002
    LSL.L     #7, D0             ; D0 = $00000100

    ; --- LSR : decalage logique droite ---
    MOVE.L    #$80000000, D0
    LSR.L     #4, D0             ; D0 = $08000000 (zero insere)
    MOVE.L    #$FF, D1
    LSR.L     #4, D1             ; D1 = $0F

    ; --- ROL : rotation gauche ---
    MOVE.L    #$80000001, D0
    ROL.L     #1, D0             ; D0 = $00000003 (bit 31 -> bit 0)

    ; --- ROR : rotation droite ---
    MOVE.L    #$00000001, D0
    ROR.L     #1, D0             ; D0 = $80000000 (bit 0 -> bit 31)

    ; --- ROXL : rotation gauche avec X ---
    MOVEQ     #0, D0
    ORI       #$10, CCR          ; Positionner X
    ROXL.L    #1, D0             ; D0 = 1 (X entre par la droite)

    ; --- ROXR : rotation droite avec X ---
    MOVEQ     #0, D0
    ORI       #$10, CCR          ; Positionner X
    ROXR.L    #1, D0             ; D0 = $80000000 (X entre par la gauche)

    ; --- Decalage par registre ---
    MOVE.L    #1, D0
    MOVE.L    #5, D1
    LSL.L     D1, D0             ; D0 = 32 (decalage de D1 positions)

    ; Terminer
    MOVE.B    #9, D0
    TRAP      #15

    END       start
