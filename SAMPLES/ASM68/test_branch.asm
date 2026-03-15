; test_branch.asm - Tests complets des instructions de branchement et controle
; Instructions : BRA, BSR, Bcc, DBcc, Scc, JMP, JSR, RTS, RTE, RTR, NOP
; TODO 15 - Validation exhaustive

    ORG       $1000

start:

; =====================================================================
; NOP - Pas d'operation ($4E71)
; =====================================================================

    NOP                          ; $4E71

; =====================================================================
; RTS, RTE, RTR - Retours
; =====================================================================

    RTS                          ; $4E75
    RTE                          ; $4E73
    RTR                          ; $4E77

; =====================================================================
; BRA - Branchement inconditionnel
; =====================================================================

    ; BRA.W label (deplacement 16 bits)
    BRA       bra_target         ; $6000 + disp16
bra_target:
    NOP

    ; BRA.S label (deplacement 8 bits)
    BRA.S     bra_short          ; $60xx (8 bits)
bra_short:
    NOP

; =====================================================================
; BSR - Branchement vers sous-routine
; =====================================================================

    ; BSR.W label
    BSR       sub1               ; $6100 + disp16
    NOP

    ; BSR.S label (cible proche pour deplacement 8 bits)
    BSR.S     bsr_short_target   ; $61xx (8 bits)
    NOP
bsr_short_target:
    NOP

; =====================================================================
; Bcc - Branchements conditionnels (16 conditions)
; =====================================================================

    ; BEQ (cc=7)
    BEQ       cc_target          ; $6700 + disp16
    ; BNE (cc=6)
    BNE       cc_target          ; $6600 + disp16
    ; BCC / BHS (cc=4)
    BCC       cc_target          ; $6400 + disp16
    BHS       cc_target          ; $6400 + disp16 (alias BCC)
    ; BCS / BLO (cc=5)
    BCS       cc_target          ; $6500 + disp16
    BLO       cc_target          ; $6500 + disp16 (alias BCS)
    ; BMI (cc=11)
    BMI       cc_target          ; $6B00 + disp16
    ; BPL (cc=10)
    BPL       cc_target          ; $6A00 + disp16
    ; BVS (cc=9)
    BVS       cc_target          ; $6900 + disp16
    ; BVC (cc=8)
    BVC       cc_target          ; $6800 + disp16
    ; BHI (cc=2)
    BHI       cc_target          ; $6200 + disp16
    ; BLS (cc=3)
    BLS       cc_target          ; $6300 + disp16
    ; BGE (cc=12)
    BGE       cc_target          ; $6C00 + disp16
    ; BLT (cc=13)
    BLT       cc_target          ; $6D00 + disp16
    ; BGT (cc=14)
    BGT       cc_target          ; $6E00 + disp16
    ; BLE (cc=15)
    BLE       cc_target          ; $6F00 + disp16
cc_target:
    NOP

; =====================================================================
; Bcc.S - Branchements conditionnels courts (8 bits)
; =====================================================================

    BEQ.S     short_target       ; $67xx
    BNE.S     short_target       ; $66xx
    BCC.S     short_target       ; $64xx
    BCS.S     short_target       ; $65xx
    BMI.S     short_target       ; $6Bxx
    BPL.S     short_target       ; $6Axx
    BGE.S     short_target       ; $6Cxx
    BLT.S     short_target       ; $6Dxx
    BGT.S     short_target       ; $6Exx
    BLE.S     short_target       ; $6Fxx
short_target:
    NOP

; =====================================================================
; DBcc - Decrementer et brancher
; =====================================================================

    ; DBRA/DBF (cc=1) - boucle inconditionnelle
    DBRA      D0, db_loop_top    ; $51C8 | reg + disp16
db_loop_top:
    DBF       D1, db_loop_top    ; $51C9 | reg + disp16

    ; DBT (cc=0) - jamais boucler
    DBT       D2, db_loop_top    ; $50CA | reg + disp16

    ; DBEQ (cc=7)
    DBEQ      D3, db_loop_top    ; $57CB + disp16

    ; DBNE (cc=6)
    DBNE      D4, db_loop_top    ; $56CC + disp16

    ; DBCC (cc=4)
    DBCC      D5, db_loop_top    ; $54CD + disp16

    ; DBCS (cc=5)
    DBCS      D6, db_loop_top    ; $55CE + disp16

    ; DBMI (cc=11)
    DBMI      D7, db_loop_top    ; $5BCF + disp16

    ; DBPL (cc=10)
    DBPL      D0, db_loop_top    ; $5AC8 + disp16

    ; DBVS (cc=9)
    DBVS      D1, db_loop_top    ; $59C9 + disp16

    ; DBVC (cc=8)
    DBVC      D2, db_loop_top    ; $58CA + disp16

    ; DBHI (cc=2)
    DBHI      D3, db_loop_top    ; $52CB + disp16

    ; DBLS (cc=3)
    DBLS      D4, db_loop_top    ; $53CC + disp16

    ; DBGE (cc=12)
    DBGE      D5, db_loop_top    ; $5CCD + disp16

    ; DBLT (cc=13)
    DBLT      D6, db_loop_top    ; $5DCE + disp16

    ; DBGT (cc=14)
    DBGT      D7, db_loop_top    ; $5ECF + disp16

    ; DBLE (cc=15)
    DBLE      D0, db_loop_top    ; $5FC8 + disp16

; =====================================================================
; Scc - Positionner octet selon condition
; =====================================================================

    ; ST (cc=0) / SF (cc=1)
    ST        D0                 ; $50C0
    SF        D1                 ; $51C1

    ; SEQ (cc=7) / SNE (cc=6)
    SEQ       D2                 ; $57C2
    SNE       D3                 ; $56C3

    ; SCC (cc=4) / SCS (cc=5)
    SCC       D4                 ; $54C4
    SCS       D5                 ; $55C5

    ; SHI (cc=2) / SLS (cc=3)
    SHI       D6                 ; $52C6
    SLS       D7                 ; $53C7

    ; SMI (cc=11) / SPL (cc=10)
    SMI       D0                 ; $5BC0
    SPL       D1                 ; $5AC1

    ; SVS (cc=9) / SVC (cc=8)
    SVS       D2                 ; $59C2
    SVC       D3                 ; $58C3

    ; SGE (cc=12) / SLT (cc=13)
    SGE       D4                 ; $5CC4
    SLT       D5                 ; $5DC5

    ; SGT (cc=14) / SLE (cc=15)
    SGT       D6                 ; $5EC6
    SLE       D7                 ; $5FC7

    ; Scc avec adressage memoire
    SEQ       (A0)               ; $57D0
    SNE       (A1)+              ; $56D9
    SCC       -(A2)              ; $54E2
    SCS       4(A3)              ; $55EB + $0004

; =====================================================================
; JMP - Saut inconditionnel
; =====================================================================

    ; JMP (An)
    JMP       (A0)               ; $4ED0
    ; JMP d(An)
    JMP       8(A1)              ; $4EE9 + $0008
    ; JMP xxx.W
    JMP       $2000              ; $4EF8 + $2000
    ; JMP xxx.L
    JMP       $12345678          ; $4EF9 + $1234 + $5678

; =====================================================================
; JSR - Appel sous-routine
; =====================================================================

    ; JSR (An)
    JSR       (A0)               ; $4E90
    ; JSR d(An)
    JSR       8(A1)              ; $4EA9 + $0008
    ; JSR xxx.W
    JSR       $2000              ; $4EB8 + $2000
    ; JSR xxx.L
    JSR       $12345678          ; $4EB9 + $1234 + $5678

; =====================================================================
; Sous-routines de test
; =====================================================================

sub1:
    MOVEQ     #1, D0
    RTS

    END       start
