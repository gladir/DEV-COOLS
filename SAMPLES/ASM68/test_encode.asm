; test_encode.asm - Test TODO 17 : encodage binaire des instructions
; Verifie que les fonctions d'encodage generent le code correct
; pour chaque groupe d'instructions du 68000

        SECTION CODE

start:
        ; --- MOVE : 00ss_ddd_mmm_MMM_rrr ---
        MOVE.B  D0,D1           ; byte Dn->Dn
        MOVE.W  D2,D3           ; word Dn->Dn
        MOVE.L  D4,D5           ; long Dn->Dn
        MOVE.W  A0,D0           ; An->Dn
        MOVE.L  #$1234,D0       ; imm->Dn
        MOVE.W  (A0),D1         ; (An)->Dn
        MOVE.W  (A0)+,D2        ; (An)+->Dn
        MOVE.W  -(A1),D3        ; -(An)->Dn
        MOVE.W  4(A2),D4        ; d(An)->Dn
        MOVE.L  D0,(A0)         ; Dn->(An)
        MOVE.W  D1,$1000        ; Dn->abs.W (via abs short if small)

        ; --- Arithmetique : ADD/SUB/CMP ---
        ADD.B   D0,D1           ; Dn+Dn
        ADD.W   #10,D2          ; imm+Dn (ADDI)
        ADDQ.W  #3,D0           ; quick add
        SUB.L   D1,D2           ; Dn-Dn
        CMP.W   D3,D4           ; compare
        NEG.W   D0              ; negate
        CLR.L   D1              ; clear
        MULS    D0,D1           ; signed multiply
        DIVU    D2,D3           ; unsigned divide

        ; --- Logique : AND/OR/EOR ---
        AND.W   D0,D1
        OR.L    D2,D3
        EOR.W   D4,D5
        NOT.W   D0

        ; --- Decalage/Rotation : shift/rotate ---
        ASL.W   #1,D0           ; shift left 1
        ASR.B   #2,D1           ; shift right 2
        LSL.L   D0,D1           ; logical shift by register
        ROR.W   #4,D2           ; rotate right 4
        ROL.B   #1,D3           ; rotate left 1

        ; --- Branchement : Bcc ---
        BRA.S   next1           ; branch always short
next1:  BEQ.S   next2           ; branch equal short
next2:  BNE.W   next3           ; branch not equal word
next3:  BSR.W   subr            ; branch to subroutine

        ; --- Manipulation de bits : BTST/BSET/BCLR/BCHG ---
        BTST    D0,D1           ; test bit dynamic
        BSET    #7,D2           ; set bit static
        BCLR    D3,D4           ; clear bit dynamic
        BCHG    #0,D5           ; change bit static

        ; --- Scc/DBcc ---
        SEQ     D0              ; set if equal
        SNE     D1              ; set if not equal
        DBRA    D0,start        ; decrement and branch

        ; --- Instructions BCD ---
        ABCD    D0,D1
        SBCD    D2,D3
        NBCD    D4

        ; --- Controle ---
        NOP

        ; Terminer
        MOVE.B  #9, D0
        TRAP    #15

subr:
        MOVE.L  D0,D1
        RTS

        END     start
