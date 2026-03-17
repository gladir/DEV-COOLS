; test_advanced.asm - Tests des directives avancees (TODO 09)
; SECTION, INCLUDE, XDEF/XREF, MACRO/ENDM, REPT/ENDR, MEXIT
; Valider avec : asm68 test_advanced.asm -i SAMPLES/ASM68

    ORG       $1000

; --- Test SECTION ---
    SECTION   CODE
start:
    NOP

    SECTION   DATA
mydata:
    DC.B      'Hello', 0
    EVEN

    SECTION   BSS
mybuf:
    DS.B      64

    SECTION   CODE

; --- Test XDEF / XREF ---
    XDEF      start
    XDEF      mydata,mybuf
    XREF      ext_func

; --- Test MACRO simple ---
ADDCONST MACRO
    MOVE.L    \1, D0
    ENDM

; --- Test MACRO avec parametres nommes ---
LOADPAIR MACRO src,dst
    MOVE.L    \src, \dst
    ENDM

; --- Test MACRO avec etiquette locale ---
WAITLOOP MACRO
    MOVE.L    \1, D7
.lp\@:
    SUBQ.L    #1, D7
    BNE       .lp\@
    ENDM

; --- Test MACRO avec MEXIT ---
EARLYEXIT MACRO
    MOVE.L    #1, D0
    MEXIT
    MOVE.L    #2, D0
    ENDM

; --- Invocations de macros ---
    ADDCONST  #$FF
    LOADPAIR  #$1234,D1
    WAITLOOP  #100
    WAITLOOP  #50
    EARLYEXIT

; --- Test REPT ---
counter EQU 3
    REPT      counter
    ADDQ.L    #1, D0
    ENDR

; --- Retour en section DATA pour plus de donnees ---
    SECTION   DATA
msg2:
    DC.B      'Done', 0

    SECTION   CODE
    END       start
