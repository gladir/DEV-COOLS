; test_arith.asm - Tests complets des instructions arithmetiques entieres
; TODO 12 : ADD, ADDA, ADDQ, ADDI, ADDX, SUB, SUBA, SUBQ, SUBI, SUBX,
;           MULS, MULU, DIVS, DIVU, NEG, NEGX, CLR, EXT,
;           CMP, CMPA, CMPI, CMPM, TST, TAS
; Valider avec : asm68 test_arith.asm (0 erreurs, 0 avertissements)

    ORG       $1000

start:
    ; --- ADD : addition ea,Dn et Dn,ea ---
    ADD.B     D0, D1            ; Dn,Dn (byte)
    ADD.W     D2, D3            ; Dn,Dn (word)
    ADD.L     D4, D5            ; Dn,Dn (long)
    ADD.W     (A0), D0          ; (An),Dn
    ADD.L     (A1)+, D1         ; (An)+,Dn
    ADD.W     -(A2), D2         ; -(An),Dn
    ADD.L     8(A3), D3         ; d16(An),Dn
    ADD.W     #$1234, D4        ; #imm,Dn
    ADD.L     D0, (A0)          ; Dn,(An)  - memoire alterable
    ADD.W     D1, (A1)+         ; Dn,(An)+
    ADD.B     D2, -(A2)         ; Dn,-(An)

    ; --- ADDA : addition sur registre d'adresse ---
    ADDA.W    D0, A0            ; Dn,An (word)
    ADDA.L    D1, A1            ; Dn,An (long)
    ADDA.L    #$100, A2         ; #imm,An
    ADDA.W    (A0), A3          ; (An),An

    ; --- ADDQ : addition rapide 1-8 ---
    ADDQ.B    #1, D0            ; min value
    ADDQ.W    #4, D1            ; mid value
    ADDQ.L    #8, D2            ; max value (encoded as 0)
    ADDQ.W    #1, (A0)          ; memoire
    ADDQ.L    #2, A0            ; registre d'adresse

    ; --- ADDI : addition immediate ---
    ADDI.B    #$FF, D0          ; byte
    ADDI.W    #$1234, D1        ; word
    ADDI.L    #$12345678, D2    ; long
    ADDI.W    #100, (A0)        ; memoire

    ; --- ADDX : addition avec extension ---
    ADDX.B    D0, D1            ; Dn,Dn byte
    ADDX.W    D2, D3            ; Dn,Dn word
    ADDX.L    D4, D5            ; Dn,Dn long
    ADDX.W    -(A0), -(A1)     ; -(An),-(An)

    ; --- SUB : soustraction ea,Dn et Dn,ea ---
    SUB.B     D0, D1            ; Dn,Dn byte
    SUB.W     D2, D3            ; Dn,Dn word
    SUB.L     D4, D5            ; Dn,Dn long
    SUB.W     (A0), D0          ; (An),Dn
    SUB.L     #$1000, D1        ; #imm,Dn
    SUB.L     D0, (A0)          ; Dn,(An)

    ; --- SUBA : soustraction sur registre d'adresse ---
    SUBA.W    D0, A0            ; Dn,An word
    SUBA.L    D1, A1            ; Dn,An long
    SUBA.L    #$100, A2         ; #imm,An

    ; --- SUBQ : soustraction rapide 1-8 ---
    SUBQ.B    #1, D0
    SUBQ.W    #4, D1
    SUBQ.L    #8, D2
    SUBQ.W    #3, (A0)

    ; --- SUBI : soustraction immediate ---
    SUBI.B    #$10, D0
    SUBI.W    #$1000, D1
    SUBI.L    #$10000, D2

    ; --- SUBX : soustraction avec extension ---
    SUBX.B    D0, D1
    SUBX.W    D2, D3
    SUBX.L    D4, D5
    SUBX.W    -(A0), -(A1)

    ; --- MULS : multiplication signee ---
    MULS.W    D0, D1
    MULS.W    (A0), D2
    MULS.W    #10, D3

    ; --- MULU : multiplication non signee ---
    MULU.W    D0, D1
    MULU.W    (A0), D2
    MULU.W    #100, D3

    ; --- DIVS : division signee ---
    DIVS.W    D0, D1
    DIVS.W    (A0), D2
    DIVS.W    #7, D3

    ; --- DIVU : division non signee ---
    DIVU.W    D0, D1
    DIVU.W    (A0), D2
    DIVU.W    #3, D3

    ; --- NEG : negation ---
    NEG.B     D0
    NEG.W     D1
    NEG.L     D2
    NEG.W     (A0)

    ; --- NEGX : negation avec extension ---
    NEGX.B    D0
    NEGX.W    D1
    NEGX.L    D2

    ; --- CLR : mise a zero ---
    CLR.B     D0
    CLR.W     D1
    CLR.L     D2
    CLR.L     (A0)

    ; --- EXT : extension de signe ---
    EXT.W     D0               ; byte -> word
    EXT.L     D0               ; word -> long
    EXT.W     D7
    EXT.L     D7

    ; --- CMP : comparaison ---
    CMP.B     D0, D1
    CMP.W     D2, D3
    CMP.L     D4, D5
    CMP.W     (A0), D0
    CMP.L     #$1000, D1

    ; --- CMPA : comparaison avec registre d'adresse ---
    CMPA.W    D0, A0
    CMPA.L    D1, A1
    CMPA.L    #$2000, A2

    ; --- CMPI : comparaison immediate ---
    CMPI.B    #0, D0
    CMPI.W    #$100, D1
    CMPI.L    #$10000, D2

    ; --- CMPM : comparaison memoire a memoire ---
    CMPM.B    (A0)+, (A1)+
    CMPM.W    (A2)+, (A3)+
    CMPM.L    (A4)+, (A5)+

    ; --- TST : tester (comparer a zero) ---
    TST.B     D0
    TST.W     D1
    TST.L     D2
    TST.W     (A0)

    ; --- TAS : tester et positionner bit 7 ---
    TAS       D0
    TAS       (A0)

    END       start
