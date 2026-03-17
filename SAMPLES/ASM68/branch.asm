; branch.asm - Tests des instructions de branchement et controle de flux
; Instructions : BRA, BSR, Bcc, DBcc, Scc, JMP, JSR, RTS, NOP
; Valider avec : asm68 branch.asm

    ORG       $1000

start:
    ; --- BRA : branchement inconditionnel ---
    BRA       test_bsr
    NOP                          ; Ne sera jamais execute

    ; --- BSR : branchement vers sous-routine ---
test_bsr:
    BSR       subroutine1        ; Appel de sous-routine
    NOP                          ; Continue ici apres RTS

    ; --- BEQ/BNE : branchement si egal/pas egal ---
    MOVEQ     #0, D0
    TST.L     D0
    BEQ       is_zero            ; Branche car D0 = 0
    BRA       test_bcc           ; Ne devrait pas arriver
is_zero:
    NOP

    ; --- BCC/BCS : branchement si carry clear/set ---
test_bcc:
    MOVE.L    #$FFFFFFFF, D0
    ADD.L     #1, D0             ; Overflow -> C=1
    BCS       carry_set          ; Branche car C=1
    BRA       test_bmi
carry_set:
    NOP

    ; --- BMI/BPL : branchement si negatif/positif ---
test_bmi:
    MOVE.L    #-1, D0
    TST.L     D0
    BMI       is_negative        ; Branche car D0 < 0
    BRA       test_bgt
is_negative:
    NOP

    ; --- BGT/BLE : branchement si plus grand/inferieur ou egal ---
test_bgt:
    MOVE.L    #10, D0
    CMP.L     #5, D0
    BGT       is_greater         ; Branche car 10 > 5
    BRA       test_dbcc
is_greater:
    NOP

    ; --- DBcc : decrementer et brancher ---
test_dbcc:
    MOVEQ     #4, D0             ; Compteur = 4
dbloop:
    NOP                          ; Corps de la boucle
    DBRA      D0, dbloop         ; D0--, boucle si D0 >= 0
                                 ; Execute 5 fois (4,3,2,1,0)

    ; --- Scc : positionner octet selon condition ---
    MOVEQ     #0, D0
    TST.L     D0
    SEQ       D1                 ; D1 = $FF car Z=1
    SNE       D2                 ; D2 = $00 car Z=1

    ; --- JMP : saut inconditionnel ---
    JMP       test_jsr           ; Saut absolu

    ; --- JSR/RTS : appel et retour sous-routine ---
test_jsr:
    JSR       subroutine2        ; Appel sous-routine
    NOP                          ; Continue apres retour

    ; --- Branchement court (.S) ---
    BRA.S     fin                ; Deplacement 8 bits

    ; --- Sous-routines ---
subroutine1:
    MOVEQ     #1, D7             ; Faire quelque chose
    RTS                          ; Retour

subroutine2:
    MOVEQ     #2, D7             ; Faire autre chose
    RTS                          ; Retour

fin:
    ; Terminer
    MOVE.B    #9, D0
    TRAP      #15

    END       start
