; test_listing.asm - Test TODO 23 : Directives de listing et mise en page
; Valider avec : asm68 test_listing.asm -l test_listing.lst -s -w
;
; Cas testes :
; 1.  TTL "titre" : definir le titre du listing
; 2.  TITLE "titre" : alias de TTL
; 3.  SPC 3 : inserer 3 lignes blanches
; 4.  SPC : inserer 1 ligne blanche (defaut)
; 5.  PAGE : saut de page
; 6.  EJECT : alias de PAGE
; 7.  LIST : activer le listing
; 8.  NOLIST : desactiver le listing
; 9.  OPT L+ : activer listing via OPT
; 10. OPT L- : desactiver listing via OPT
; 11. FAIL "message" : erreur volontaire (commentee)
; 12. INFORM 0, "info" : message informatif
; 13. INFORM 1, "warn" : avertissement
; 14. Listing d'instructions avec adresses et octets
; 15. Table des symboles en fin de listing

    TTL       'Test TODO 23 - Listing et mise en page'

    ORG       $2000

; --- Cas 1 : titre du listing ---
    TITLE     'Cas 1-2 : titre change par TITLE'

; --- Cas 3 : SPC avec argument ---
    SPC       3

; --- Cas 4 : SPC sans argument ---
    SPC

; --- Cas 14 : instructions dans le listing ---
start:
    MOVEQ     #0, D0
    MOVEQ     #1, D1
    MOVEQ     #2, D2
    MOVE.L    #$12345678, D3
    MOVE.W    #$ABCD, D4

; --- Cas 5 : saut de page ---
    PAGE

; --- Cas 7-8 : LIST/NOLIST ---
    NOLIST
    MOVEQ     #10, D5        ; invisible dans le listing
    MOVEQ     #11, D6        ; invisible aussi
    LIST

; --- Cas 9-10 : OPT L-/L+ ---
    OPT       L-
    MOVEQ     #20, D7        ; invisible
    OPT       L+

; --- Cas 6 : EJECT ---
    EJECT

; --- Cas 12 : INFORM niveau 0 (info) ---
    INFORM    0, 'Ceci est un message informatif (niveau 0)'

; --- Cas 13 : INFORM niveau 1 (avertissement) ---
    INFORM    1, 'Ceci est un avertissement (niveau 1)'

; --- Cas 14 suite : instructions supplementaires ---
BUFFER_SIZE EQU  256
    MOVE.L    #BUFFER_SIZE, A0
    LEA       start(PC), A1
    NOP
    NOP
    NOP

; --- Cas 11 : FAIL (commente pour ne pas bloquer) ---
;    FAIL      'Arret volontaire de l assemblage'

; --- Terminer ---
    MOVE.B    #9, D0
    TRAP      #15

; --- Fin ---
    END       start
