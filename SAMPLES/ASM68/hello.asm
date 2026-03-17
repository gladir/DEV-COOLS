; hello.asm - Hello World en assembleur 68000
; Affiche "Hello, World!" puis termine le programme.
; Convention : TRAP #15, D0=14 pour afficher chaine (A1=adresse)
;              TRAP #15, D0=9 pour terminer
; Valider avec : asm68 hello.asm

    ORG       $1000

start:
    LEA       message(PC), A1    ; Adresse du message dans A1
    MOVE.B    #14, D0            ; Fonction : afficher chaine (A1)
    TRAP      #15                ; Appel systeme
    MOVE.B    #9, D0             ; Fonction : terminer le programme
    TRAP      #15                ; Fin

message:
    DC.B      'Hello, World!', $0D, $0A, 0

    END       start
