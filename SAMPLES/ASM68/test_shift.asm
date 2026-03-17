; test_shift.asm - Tests complets des instructions de decalage et rotation
; Instructions : ASL, ASR, LSL, LSR, ROL, ROR, ROXL, ROXR
; TODO 14 - Validation exhaustive

    ORG       $1000

start:

; =====================================================================
; ASL - Decalage arithmetique a gauche
; =====================================================================

    ; ASL.B #imm, Dn
    ASL.B     #1, D0
    ASL.B     #3, D1
    ASL.B     #8, D2

    ; ASL.W #imm, Dn
    ASL.W     #1, D3
    ASL.W     #4, D4
    ASL.W     #7, D5

    ; ASL.L #imm, Dn
    ASL.L     #1, D6
    ASL.L     #2, D7
    ASL.L     #5, D0

    ; ASL.B Dm, Dn
    ASL.B     D0, D1
    ASL.B     D2, D3

    ; ASL.W Dm, Dn
    ASL.W     D4, D5
    ASL.W     D6, D7

    ; ASL.L Dm, Dn
    ASL.L     D0, D1
    ASL.L     D2, D3

    ; ASL.W ea (memoire, 1 bit)
    ASL.W     (A0)
    ASL.W     (A1)+
    ASL.W     -(A2)
    ASL.W     $2000

; =====================================================================
; ASR - Decalage arithmetique a droite
; =====================================================================

    ; ASR.B #imm, Dn
    ASR.B     #1, D0
    ASR.B     #4, D1
    ASR.B     #8, D2

    ; ASR.W #imm, Dn
    ASR.W     #1, D3
    ASR.W     #6, D4

    ; ASR.L #imm, Dn
    ASR.L     #1, D5
    ASR.L     #3, D6

    ; ASR.B Dm, Dn
    ASR.B     D0, D1
    ASR.B     D3, D4

    ; ASR.W Dm, Dn
    ASR.W     D5, D6

    ; ASR.L Dm, Dn
    ASR.L     D7, D0

    ; ASR.W ea (memoire, 1 bit)
    ASR.W     (A0)
    ASR.W     (A3)+
    ASR.W     -(A4)

; =====================================================================
; LSL - Decalage logique a gauche
; =====================================================================

    ; LSL.B #imm, Dn
    LSL.B     #1, D0
    LSL.B     #5, D1

    ; LSL.W #imm, Dn
    LSL.W     #1, D2
    LSL.W     #8, D3

    ; LSL.L #imm, Dn
    LSL.L     #1, D4
    LSL.L     #4, D5

    ; LSL.W Dm, Dn
    LSL.W     D0, D1
    LSL.W     D6, D7

    ; LSL.L Dm, Dn
    LSL.L     D2, D3

    ; LSL.W ea (memoire)
    LSL.W     (A0)
    LSL.W     (A1)+
    LSL.W     -(A5)

; =====================================================================
; LSR - Decalage logique a droite
; =====================================================================

    ; LSR.B #imm, Dn
    LSR.B     #1, D0
    LSR.B     #7, D1

    ; LSR.W #imm, Dn
    LSR.W     #2, D2
    LSR.W     #6, D3

    ; LSR.L #imm, Dn
    LSR.L     #1, D4
    LSR.L     #3, D5

    ; LSR.B Dm, Dn
    LSR.B     D0, D1

    ; LSR.W Dm, Dn
    LSR.W     D2, D3

    ; LSR.L Dm, Dn
    LSR.L     D4, D5

    ; LSR.W ea (memoire)
    LSR.W     (A0)
    LSR.W     (A2)+

; =====================================================================
; ROL - Rotation a gauche
; =====================================================================

    ; ROL.B #imm, Dn
    ROL.B     #1, D0
    ROL.B     #3, D1

    ; ROL.W #imm, Dn
    ROL.W     #1, D2
    ROL.W     #5, D3

    ; ROL.L #imm, Dn
    ROL.L     #1, D4
    ROL.L     #8, D5

    ; ROL.W Dm, Dn
    ROL.W     D0, D1
    ROL.W     D6, D7

    ; ROL.L Dm, Dn
    ROL.L     D2, D3

    ; ROL.W ea (memoire)
    ROL.W     (A0)
    ROL.W     (A1)+

; =====================================================================
; ROR - Rotation a droite
; =====================================================================

    ; ROR.B #imm, Dn
    ROR.B     #1, D0
    ROR.B     #4, D1

    ; ROR.W #imm, Dn
    ROR.W     #2, D2
    ROR.W     #7, D3

    ; ROR.L #imm, Dn
    ROR.L     #1, D4
    ROR.L     #6, D5

    ; ROR.B Dm, Dn
    ROR.B     D0, D1

    ; ROR.W Dm, Dn
    ROR.W     D6, D7

    ; ROR.L Dm, Dn
    ROR.L     D2, D3

    ; ROR.W ea (memoire)
    ROR.W     (A0)
    ROR.W     -(A3)

; =====================================================================
; ROXL - Rotation a gauche avec X
; =====================================================================

    ; ROXL.B #imm, Dn
    ROXL.B    #1, D0
    ROXL.B    #3, D1

    ; ROXL.W #imm, Dn
    ROXL.W    #1, D2
    ROXL.W    #4, D3

    ; ROXL.L #imm, Dn
    ROXL.L    #1, D4
    ROXL.L    #2, D5

    ; ROXL.W Dm, Dn
    ROXL.W    D0, D1
    ROXL.W    D6, D7

    ; ROXL.L Dm, Dn
    ROXL.L    D2, D3

    ; ROXL.W ea (memoire)
    ROXL.W    (A0)
    ROXL.W    (A1)+

; =====================================================================
; ROXR - Rotation a droite avec X
; =====================================================================

    ; ROXR.B #imm, Dn
    ROXR.B    #1, D0
    ROXR.B    #5, D1

    ; ROXR.W #imm, Dn
    ROXR.W    #1, D2
    ROXR.W    #8, D3

    ; ROXR.L #imm, Dn
    ROXR.L    #1, D4
    ROXR.L    #3, D5

    ; ROXR.B Dm, Dn
    ROXR.B    D0, D1

    ; ROXR.W Dm, Dn
    ROXR.W    D6, D7

    ; ROXR.L Dm, Dn
    ROXR.L    D2, D3

    ; Terminer
    MOVE.B    #9, D0
    TRAP      #15

    ; ROXR.W ea (memoire)
    ROXR.W    (A0)
    ROXR.W    -(A4)

    END       start
