; test_parser.asm - Test du parseur de ligne assembleur (TODO 19)
; Teste : etiquettes, opcodes avec suffixes, operandes, commentaires,
;         listes de registres (MOVEM), modes d'adressage speciaux.

        ORG     $1000

; --- 1. Etiquettes simples ---
start:
        NOP                     ; instruction sans operande

; --- 2. Etiquette avec instruction sur la meme ligne ---
loop:   MOVE.L  D0,D1           ; transfert registre a registre

; --- 3. Suffixes de taille ---
        MOVE.B  #$FF,D0         ; .B = octet
        MOVE.W  #$1234,D1       ; .W = mot
        MOVE.L  #$12345678,D2   ; .L = long mot
        ADD.B   D0,D1           ; add byte
        ADD.W   D0,D1           ; add word
        ADD.L   D0,D1           ; add long

; --- 4. Modes d'adressage ---
        MOVE.L  D3,D4           ; registre donnees
        MOVE.L  A0,A1           ; registre adresse
        MOVE.L  #100,D0         ; immediat
        MOVE.L  (A0),D0         ; indirect registre
        MOVE.L  (A0)+,D0        ; post-increment
        MOVE.L  -(A0),D0        ; pre-decrement
        MOVE.W  4(A0),D0        ; indirect avec deplacement
        LEA     table(PC),A0    ; relatif PC

; --- 5. Listes de registres (MOVEM) ---
        MOVEM.L D0-D3/A0-A2,-(A7)  ; sauvegarde registres
        MOVEM.L (A7)+,D0-D3/A0-A2  ; restauration registres
        MOVEM.W D0/D2/D4,-(A7)     ; registres individuels
        MOVEM.W (A7)+,D0/D2/D4     ; restauration individuelle

; --- 6. Instructions sans operandes ---
        NOP
        RTS
        RTE
        RTR
        TRAPV
        RESET

; --- 7. Instructions avec un seul operande ---
        CLR.L   D0
        NEG.W   D1
        NOT.B   D2
        TST.L   D3
        JMP     start
        JSR     subrtn
        PEA     (A0)
        SWAP    D5

; --- 8. Instructions de branchement ---
        BRA.S   skip1
        BEQ.W   skip1
skip1:  BNE     skip2
skip2:  BSR     subrtn
        DBRA    D0,loop

; --- 9. Instructions avec taille par defaut ---
        CMP     D0,D1           ; taille par defaut (mot)
        ADD     D0,D1

; --- 10. Instructions BCD ---
        ABCD    D0,D1
        SBCD    D2,D3
        NBCD    D4

; --- 11. Directives ---
table:  DC.W    $1234,$5678,$9ABC
        DC.B    'Hello',0
        DS.W    10
        EVEN

; --- 12. Labels et EQU ---
BUFSIZE EQU     256
MAXVAL  EQU     $FF

; --- 13. Instruction speciales ---
        TRAP    #0
        STOP    #$2700
        CHK     D0,D1
        LINK    A6,#-64
        UNLK    A6
        EXG     D0,D1

subrtn: MOVE.L  D0,D0           ; sous-routine stub
        RTS

        END     start
