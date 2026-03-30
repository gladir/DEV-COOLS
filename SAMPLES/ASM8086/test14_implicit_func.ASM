; Test 14 - Fonctions implicites (sans PROC/ENDP)
; Teste: Detection automatique des fonctions avec PUSH BP/MOV BP,SP/POP BP/RET
; et appels avec parametres via PUSH/CALL

.MODEL SMALL
.STACK 100h

.DATA
result DW 0
sum DW 0

.CODE

; Fonction implicite d'addition avec 2 parametres
; my_add(a, b) -> AX = a + b
my_add:
    PUSH     BP
    MOV      BP, SP
    MOV      AX, [BP+4]    ; param1 (a)
    ADD      AX, [BP+6]    ; param2 (b)
    POP      BP
    RET      0004h

; Fonction implicite de multiplication avec 2 parametres
; my_mult(a, b) -> AX = a * b (partie basse)
my_mult:
    PUSH     BP
    MOV      BP, SP
    MOV      AX, [BP+4]    ; param1 (a)
    MOV      BX, [BP+6]    ; param2 (b)
    MUL      BX            ; AX = AX * BX
    POP      BP
    RET      0004h

; Fonction implicite sans parametres
; get_value() -> AX = 42
get_value:
    PUSH     BP
    MOV      BP, SP
    MOV      AX, 42
    POP      BP
    RET

START:
    MOV AX, @DATA
    MOV DS, AX
    
    ; Appeler my_add(5, 3) -> devrait retourner 8
    PUSH     3
    PUSH     5
    CALL     my_add
    MOV      sum, AX
    
    ; Appeler my_mult(4, 7) -> devrait retourner 28
    PUSH     7
    PUSH     4
    CALL     my_mult
    MOV      result, AX
    
    ; Appeler get_value() -> devrait retourner 42
    CALL     get_value
    
    MOV AH, 4Ch
    INT 21h
END START
