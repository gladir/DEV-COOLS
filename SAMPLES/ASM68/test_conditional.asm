; test_conditional.asm - Test de l'assemblage conditionnel (TODO 10)
; Directives : IFEQ/IFNE/IFGT/IFGE/IFLT/IFLE, IFDEF/IFNDEF,
;              IFC/IFNC, IF, ELSE, ENDC/ENDIF, imbrication
; Valider avec : asm68 test_conditional.asm
; Valider avec : asm68 test_conditional.asm -d FEATURE

    ORG       $2000

; --- Constantes de test ---
VALZERO   EQU   0
VALPOS    EQU   5
VALNEG    EQU   -3
VALTWO    EQU   2

; ============================
; Test 1 : IFEQ (expr == 0)
; ============================
    IFEQ      VALZERO
    DC.W      $1111           ; Assemble : VALZERO == 0
    ENDC

    IFEQ      VALPOS
    DC.W      $DEAD           ; N'assemble PAS : VALPOS != 0
    ENDC

; ============================
; Test 2 : IFNE (expr != 0)
; ============================
    IFNE      VALPOS
    DC.W      $2222           ; Assemble : VALPOS != 0
    ENDC

    IFNE      VALZERO
    DC.W      $DEAD           ; N'assemble PAS : VALZERO == 0
    ENDC

; ============================
; Test 3 : IFGT (expr > 0)
; ============================
    IFGT      VALPOS
    DC.W      $3333           ; Assemble : VALPOS > 0
    ENDC

    IFGT      VALNEG
    DC.W      $DEAD           ; N'assemble PAS : VALNEG < 0
    ENDC

    IFGT      VALZERO
    DC.W      $DEAD           ; N'assemble PAS : VALZERO == 0
    ENDC

; ============================
; Test 4 : IFGE (expr >= 0)
; ============================
    IFGE      VALZERO
    DC.W      $4444           ; Assemble : VALZERO >= 0
    ENDC

    IFGE      VALNEG
    DC.W      $DEAD           ; N'assemble PAS : VALNEG < 0
    ENDC

; ============================
; Test 5 : IFLT (expr < 0)
; ============================
    IFLT      VALNEG
    DC.W      $5555           ; Assemble : VALNEG < 0
    ENDC

    IFLT      VALPOS
    DC.W      $DEAD           ; N'assemble PAS : VALPOS > 0
    ENDC

; ============================
; Test 6 : IFLE (expr <= 0)
; ============================
    IFLE      VALZERO
    DC.W      $6666           ; Assemble : VALZERO <= 0
    ENDC

    IFLE      VALPOS
    DC.W      $DEAD           ; N'assemble PAS : VALPOS > 0
    ENDC

; ============================
; Test 7 : IFDEF / IFNDEF
; ============================
    IFDEF     VALZERO
    DC.W      $7777           ; Assemble : VALZERO est defini
    ENDC

    IFDEF     NOTDEFINED
    DC.W      $DEAD           ; N'assemble PAS : NOTDEFINED non defini
    ENDC

    IFNDEF    NOTDEFINED
    DC.W      $8888           ; Assemble : NOTDEFINED non defini
    ENDC

    IFNDEF    VALZERO
    DC.W      $DEAD           ; N'assemble PAS : VALZERO est defini
    ENDC

; ============================
; Test 8 : IFC / IFNC
; ============================
    IFC       'ABC','ABC'
    DC.W      $9999           ; Assemble : chaines egales
    ENDC

    IFC       'ABC','DEF'
    DC.W      $DEAD           ; N'assemble PAS : chaines differentes
    ENDC

    IFNC      'ABC','DEF'
    DC.W      $AAAA           ; Assemble : chaines differentes
    ENDC

    IFNC      'XYZ','XYZ'
    DC.W      $DEAD           ; N'assemble PAS : chaines egales
    ENDC

; ============================
; Test 9 : ELSE
; ============================
    IFEQ      VALPOS
    DC.W      $DEAD           ; N'assemble PAS : VALPOS != 0
    ELSE
    DC.W      $BBBB           ; Assemble : branche ELSE
    ENDC

    IFEQ      VALZERO
    DC.W      $CCCC           ; Assemble : VALZERO == 0
    ELSE
    DC.W      $DEAD           ; N'assemble PAS
    ENDC

; ============================
; Test 10 : ENDIF (alias ENDC)
; ============================
    IFNE      VALPOS
    DC.W      $DDDD           ; Assemble
    ENDIF

; ============================
; Test 11 : IF (alias IFNE)
; ============================
    IF        VALPOS
    DC.W      $EEEE           ; Assemble : VALPOS != 0
    ENDC

    IF        VALZERO
    DC.W      $DEAD           ; N'assemble PAS : VALZERO == 0
    ENDC

; ============================
; Test 12 : Imbrication
; ============================
    IFNE      VALPOS
    DC.W      $F001           ; Assemble : niveau 1 vrai
    IFEQ      VALZERO
    DC.W      $F002           ; Assemble : niveau 2 vrai
    ENDC
    IFNE      VALZERO
    DC.W      $DEAD           ; N'assemble PAS : niveau 2 faux
    ENDC
    ENDC

    IFEQ      VALPOS
    DC.W      $DEAD           ; N'assemble PAS : niveau 1 faux
    IFEQ      VALZERO
    DC.W      $DEAD           ; N'assemble PAS : parent faux
    ENDC
    ENDC

; ============================
; Test 13 : IFDEF avec -d FEATURE
; ============================
    IFDEF     FEATURE
    DC.W      $FF00           ; Assemble seulement avec -d FEATURE
    ENDC

    END
