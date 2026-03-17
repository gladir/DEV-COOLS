; expr.asm - Tests des expressions arithmetiques
; Bases numeriques, operateurs, expressions complexes
; Valider avec : asm68 expr.asm

    ORG       $1000

; --- Constantes en differentes bases ---
DEC_VAL     EQU   255            ; Decimal
HEX_VAL     EQU   $FF            ; Hexadecimal
OCT_VAL     EQU   @377           ; Octal
BIN_VAL     EQU   %11111111      ; Binaire

; --- Expressions arithmetiques ---
SUM_VAL     EQU   100+200        ; Addition
DIFF_VAL    EQU   500-123        ; Soustraction
PROD_VAL    EQU   12*10          ; Multiplication
QUOT_VAL    EQU   100/4          ; Division
MOD_VAL     EQU   100%7          ; Modulo

; --- Expressions avec operateurs bit a bit ---
AND_VAL     EQU   $FF00&$0F0F   ; ET -> $0F00
OR_VAL      EQU   $FF00|$00FF   ; OU -> $FFFF
XOR_VAL     EQU   $FF00^$0FF0   ; XOR -> $F0F0
SHL_VAL     EQU   1<<8           ; Decalage gauche -> 256
SHR_VAL     EQU   $100>>4        ; Decalage droite -> 16

; --- Expressions avec parentheses ---
COMPLEX1    EQU   (10+20)*3      ; 90
COMPLEX2    EQU   100-(50/2)     ; 75
COMPLEX3    EQU   (1<<4)|(1<<2)  ; $14

start:
    ; --- Chargement des constantes ---
    MOVE.L    #DEC_VAL, D0       ; 255
    MOVE.L    #HEX_VAL, D1       ; 255
    MOVE.L    #BIN_VAL, D2       ; 255
    MOVE.L    #SUM_VAL, D3       ; 300
    MOVE.L    #PROD_VAL, D4      ; 120
    MOVE.L    #AND_VAL, D5       ; $0F00
    MOVE.L    #COMPLEX1, D6      ; 90
    MOVE.L    #COMPLEX3, D7      ; $14

    ; --- Expression inline ---
    MOVE.L    #100+200+300, D0   ; 600
    MOVE.L    #$FF&$0F, D1       ; $0F
    MOVE.L    #1<<16, D2         ; $10000

    ; --- Adresse courante (*) ---
    LEA       *(PC), A0          ; A0 = adresse courante

    ; Terminer
    MOVE.B    #9, D0
    TRAP      #15

    END       start
