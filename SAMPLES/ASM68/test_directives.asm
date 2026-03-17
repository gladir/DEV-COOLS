; test_directives.asm - Tests des directives de base (TODO 08)
; Directives : ORG, DC, DCB, DS, EQU, SET, EVEN, CNOP, END
; Valider avec : asm68 test_directives.asm

    ORG       $2000

; --- EQU : constantes d'assemblage ---
MAGIC       EQU   $DEAD
VERSION     EQU   1
BUFSIZE     EQU   256

; --- SET : variables d'assemblage (redefinissables) ---
COUNTER     SET   0
COUNTER     SET   1
COUNTER     SET   2

; --- DC.B : octets et chaines ---
data_bytes:
    DC.B      $00, $FF, $55, $AA
    DC.B      'Hello', 0
    DC.B      'A', $20, 'B'

; --- DC.W : mots (16 bits) ---
data_words:
    DC.W      $1234, $5678, $9ABC
    DC.W      MAGIC
    DC.W      0

; --- DC.L : long mots (32 bits) ---
data_longs:
    DC.L      $12345678
    DC.L      $DEADBEEF, $CAFEBABE
    DC.L      0

; --- EVEN : alignement sur adresse paire ---
    DC.B      $FF              ; force adresse impaire
    EVEN                       ; realigne sur mot

; --- DS.B : reserver des octets ---
buffer:
    DS.B      10               ; 10 octets a zero

; --- DS.W : reserver des mots ---
    DS.W      5                ; 5 mots = 10 octets

; --- DS.L : reserver des long mots ---
    DS.L      2                ; 2 long mots = 8 octets

; --- DS.W 0 : alignement sur mot ---
    DC.B      $FF
    DS.W      0                ; alignement sur mot

; --- DCB.B : bloc d'octets repetes ---
fill_bytes:
    DCB.B     8, $FF           ; 8 octets valant $FF

; --- DCB.W : bloc de mots repetes ---
fill_words:
    DCB.W     4, $ABCD         ; 4 mots valant $ABCD

; --- DCB.L : bloc de long mots repetes ---
fill_longs:
    DCB.L     2, $12345678     ; 2 long mots

; --- CNOP : alignement avec offset ---
    CNOP      0, 4             ; aligner sur long mot

; --- Etiquette de fin ---
end_mark:
    DC.L      $FFFFFFFF

    END       data_bytes
