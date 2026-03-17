; cond.asm - Tests de l'assemblage conditionnel
; Directives : IFEQ, IFNE, IFDEF, IFNDEF, IFC, IFNC, ELSE, ENDC
; Valider avec : asm68 cond.asm -d DEBUG

    ORG       $1000

; --- Definitions pour les tests ---
VERSION   EQU   2
ZERO      EQU   0
NONZERO   EQU   1

start:
    ; --- IFEQ : assembler si expression == 0 ---
    IFEQ      ZERO
    MOVEQ     #1, D0             ; Assemble car ZERO == 0
    ENDC

    ; --- IFNE : assembler si expression != 0 ---
    IFNE      NONZERO
    MOVEQ     #2, D1             ; Assemble car NONZERO != 0
    ENDC

    ; --- IFGT : assembler si expression > 0 ---
    IFGT      VERSION-1
    MOVEQ     #3, D2             ; Assemble car VERSION-1 = 1 > 0
    ENDC

    ; --- IFGE : assembler si expression >= 0 ---
    IFGE      VERSION
    MOVEQ     #4, D3             ; Assemble car VERSION = 2 >= 0
    ENDC

    ; --- IFLT : assembler si expression < 0 ---
    IFLT      VERSION
    MOVEQ     #99, D4            ; N'assemble PAS car VERSION = 2 >= 0
    ENDC

    ; --- IFDEF : assembler si symbole defini ---
    IFDEF     DEBUG
    LEA       dbg_msg(PC), A1    ; Assemble seulement si -d DEBUG
    MOVE.B    #14, D0
    TRAP      #15
    ENDC

    ; --- IFNDEF : assembler si symbole non defini ---
    IFNDEF    RELEASE
    MOVEQ     #5, D5             ; Assemble car RELEASE pas defini
    ENDC

    ; --- IFEQ avec ELSE ---
    IFEQ      VERSION-2
    MOVEQ     #10, D6            ; Assemble car VERSION-2 == 0
    ELSE
    MOVEQ     #20, D6            ; N'assemble PAS
    ENDC

    ; --- Imbrication de conditionnels ---
    IFDEF     DEBUG
    IFNE      VERSION
    MOVEQ     #30, D7            ; Assemble si DEBUG defini ET VERSION != 0
    ENDC
    ENDC

    ; Terminer
    MOVE.B    #9, D0
    TRAP      #15

dbg_msg:
    DC.B      '[DEBUG] Mode debogage actif', $0D, $0A, 0

    END       start
