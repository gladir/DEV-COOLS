; test_srecord.asm - Test de la generation de fichier objet S-Record (TODO 20)
; Ce fichier teste la generation de S-Records pour differents cas :
;   - Section CODE avec instructions
;   - Section DATA avec donnees initialisees
;   - Section BSS (pas de S-Record attendu pour BSS)
;   - Adresse de demarrage via END
;   - Donnees depassant MAX_SREC_DATA (32 octets) pour tester le decoupage

    ORG   $1000

; --- Section CODE : instructions basiques ---
START:
    MOVE.L  #$12345678,D0   ; 6 octets
    MOVE.W  #$ABCD,D1       ; 4 octets
    ADD.L   D0,D1           ; 2 octets
    SUB.W   #$0010,D2       ; 4 octets
    CLR.L   D3              ; 2 octets
    NOP                     ; 2 octets
    NOP                     ; 2 octets

; --- Quelques branchements ---
LOOP:
    DBF     D7,LOOP         ; 4 octets
    BRA.W   DONE            ; 4 octets

; --- Donnees en section CODE (via DC) ---
MSG:
    DC.B    'S-Record Test',0  ; 14 octets
    EVEN                       ; alignement

DONE:
    MOVE.B  #9,D0            ; Terminer
    TRAP    #15              ; Fin

    END     START
