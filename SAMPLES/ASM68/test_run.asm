; test_run.asm - Test de l'orchestration complete (TODO 24)
; Verifie le programme principal : deux passes, symboles predefinis,
; generation de code, listing, et code de retour.

; ---- Test 1 : Reference en avant (passe 1 -> passe 2) ----
       ORG     $1000
START:
       MOVE.L  #FWD_VAL,D0      ; reference en avant vers EQU
       LEA     BUFFER,A0        ; reference en avant vers BSS

; ---- Test 2 : Symboles predefinis et EQU/SET ----
MAGIC  EQU     $DEAD
COUNT  SET     10
       MOVE.W  #MAGIC,D1
       MOVEQ   #COUNT,D2

; ---- Test 3 : Section DATA ----
       SECTION DATA
MSG:   DC.B    'Run OK',0
       EVEN

; ---- Test 4 : Section BSS ----
       SECTION BSS
BUFFER: DS.B   64

; ---- Test 5 : Retour section CODE ----
       SECTION CODE
       MOVE.L  #MSG,A1          ; reference croisee vers DATA
       MOVE.W  #7,D3            ; longueur
       JSR     START            ; reference arriere

; ---- Test 6 : EQU avec expression ----
FWD_VAL EQU    MAGIC+1          ; $DEAF

; ---- Test 7 : Etiquettes locales ----
LOOP:
       SUBQ.W  #1,D2
       BNE     LOOP
.done:
       NOP

; ---- Test 8 : Macro simple ----
CLRREG MACRO
       CLR.L   \1
       ENDM

       CLRREG  D0
       CLRREG  D1

; ---- Test 9 : Assemblage conditionnel ----
       IFEQ    0
       MOVE.L  #1,D5            ; cette ligne est assemblee (0=0 vrai)
       ENDC

       IFNE    0
       MOVE.L  #$BAD,D6         ; cette ligne n'est PAS assemblee
       ENDC

; ---- Test 10 : Alignement et directives ----
       EVEN
       CNOP    0,4

; ---- Test 11 : Donnees DC ----
       DC.W    $1234,$5678
       DC.L    START

; ---- Test 12 : Instructions variees ----
       ADD.L   D0,D1
       SUB.W   D2,D3
       AND.L   #$FF,D0
       OR.W    #$8000,D1
       LSL.W   #2,D4
       ROR.B   #1,D5

; ---- Test 13 : Branchements ----
       BRA.S   SKIP
       NOP
SKIP:  NOP

; ---- Test 14 : Instructions speciales ----
       SWAP    D0
       EXT.W   D1
       EXT.L   D1

; ---- Test 15 : Fin du programme ----
       RTS

       END     START
