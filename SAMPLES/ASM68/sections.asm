; sections.asm - Tests des sections CODE, DATA, BSS et directives memoire
; Directives : SECTION, ORG, EVEN, CNOP, DC, DS, DCB, EQU
; Valider avec : asm68 sections.asm

; --- Section CODE ---
    SECTION   CODE

    ORG       $1000

start:
    ; Charger l'adresse des donnees
    LEA       message(PC), A1
    MOVE.B    #14, D0
    TRAP      #15

    ; Acceder au buffer BSS
    LEA       buffer, A0
    MOVE.B    #'A', (A0)         ; Premier octet du buffer

    ; Utiliser la table de donnees
    LEA       table, A1
    MOVE.W    (A1), D0           ; Premier element = 100
    MOVE.W    2(A1), D1          ; Deuxieme element = 200

    ; Terminer
    MOVE.B    #9, D0
    TRAP      #15

; --- Section DATA ---
    SECTION   DATA

message:
    DC.B      'Test sections OK', $0D, $0A, 0
    EVEN                         ; Aligner sur adresse paire

table:
    DC.W      100, 200, 300, 400, 500

; Bloc de constantes
zeros:
    DCB.B     16, 0              ; 16 octets a zero

pattern:
    DCB.W     8, $AAAA           ; 8 mots avec motif

; --- Section BSS (donnees non initialisees) ---
    SECTION   BSS

buffer:
    DS.B      256                ; Buffer de 256 octets

variables:
    DS.W      10                 ; 10 mots reserves

pointers:
    DS.L      4                  ; 4 long mots reserves

    END       start
