; arith.asm - Tests des instructions arithmetiques entieres
; Instructions : ADD, ADDA, ADDQ, ADDI, ADDX, SUB, SUBA, SUBQ,
;                SUBI, SUBX, MULS, MULU, DIVS, DIVU, NEG, NEGX,
;                CLR, EXT, CMP, CMPA, CMPI, CMPM, TST, TAS
; Valider avec : asm68 arith.asm

    ORG       $1000

start:
    ; --- ADD : addition ---
    MOVE.L    #100, D0
    MOVE.L    #200, D1
    ADD.L     D0, D1             ; D1 = 300
    ADD.W     #$1000, D0         ; D0 = D0 + $1000

    ; --- ADDA : addition sur registre d'adresse ---
    MOVEA.L   #$2000, A0
    ADDA.L    #$100, A0          ; A0 = $2100

    ; --- ADDQ : addition rapide (1-8) ---
    MOVEQ     #0, D0
    ADDQ.L    #1, D0             ; D0 = 1
    ADDQ.W    #8, D0             ; D0 = 9

    ; --- ADDI : addition immediate ---
    ADDI.L    #$10000, D0        ; D0 = D0 + $10000

    ; --- SUB : soustraction ---
    MOVE.L    #500, D0
    MOVE.L    #200, D1
    SUB.L     D1, D0             ; D0 = 300

    ; --- SUBA : soustraction sur registre d'adresse ---
    MOVEA.L   #$3000, A0
    SUBA.L    #$100, A0          ; A0 = $2F00

    ; --- SUBQ : soustraction rapide (1-8) ---
    MOVE.L    #10, D0
    SUBQ.L    #3, D0             ; D0 = 7

    ; --- SUBI : soustraction immediate ---
    SUBI.L    #$1000, D0         ; D0 = D0 - $1000

    ; --- MULS : multiplication signee 16x16 -> 32 ---
    MOVE.W    #-10, D0
    MOVE.W    #20, D1
    MULS.W    D0, D1             ; D1 = -200

    ; --- MULU : multiplication non signee 16x16 -> 32 ---
    MOVE.W    #100, D0
    MOVE.W    #50, D1
    MULU.W    D0, D1             ; D1 = 5000

    ; --- DIVS : division signee 32/16 ---
    MOVE.L    #-1000, D0
    DIVS.W    #7, D0             ; D0.W = quotient, D0 haut = reste

    ; --- DIVU : division non signee 32/16 ---
    MOVE.L    #10000, D1
    DIVU.W    #3, D1             ; D1.W = 3333, reste dans bits hauts

    ; --- NEG : negation ---
    MOVE.L    #42, D0
    NEG.L     D0                 ; D0 = -42

    ; --- CLR : mise a zero ---
    CLR.L     D0                 ; D0 = 0
    CLR.W     D1                 ; D1.W = 0

    ; --- EXT : extension de signe ---
    MOVE.B    #$FF, D0           ; D0.B = -1
    EXT.W     D0                 ; D0.W = $FFFF (-1)
    EXT.L     D0                 ; D0.L = $FFFFFFFF (-1)

    ; --- CMP : comparaison ---
    MOVE.L    #100, D0
    MOVE.L    #100, D1
    CMP.L     D0, D1             ; Z=1 (egaux)

    ; --- CMPI : comparaison immediate ---
    CMPI.L    #100, D0           ; Z=1

    ; --- TST : tester (comparer a zero) ---
    MOVEQ     #0, D0
    TST.L     D0                 ; Z=1 (zero)

    ; Terminer
    MOVE.B    #9, D0
    TRAP      #15

    END       start
