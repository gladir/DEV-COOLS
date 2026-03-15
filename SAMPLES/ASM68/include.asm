; include.asm - Tests de la directive INCLUDE
; Valider avec : asm68 include.asm -i .

    ORG       $1000

; Inclure le fichier de sous-routines
    INCLUDE   "inc_sub.asm"

start:
    ; Appeler la sous-routine definie dans inc_sub.asm
    LEA       hello_msg(PC), A1
    BSR       print_string       ; Defini dans inc_sub.asm

    ; Terminer
    MOVE.B    #9, D0
    TRAP      #15

hello_msg:
    DC.B      'Test INCLUDE OK', $0D, $0A, 0

    END       start
