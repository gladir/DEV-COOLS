; test02_arith.asm - Test 2 : operations arithmetiques 32 bits
; ADD/SUB/IMUL/IDIV, resultats stockes en memoire (visibles au debogueur,
; ou par le code de sortie du processus pour une verification rapide).

.386
.MODEL FLAT
EXTERN ExitProcess:PROC

.DATA
val_a   DD 1234
val_b   DD 56
res_add DD 0    ; attendu : 1290
res_sub DD 0    ; attendu : 1178
res_mul DD 0    ; attendu : 69104
res_div DD 0    ; attendu : 22
res_mod DD 0    ; attendu : 2

.CODE
start:
        MOV EAX, val_a
        ADD EAX, val_b
        MOV res_add, EAX

        MOV EAX, val_a
        SUB EAX, val_b
        MOV res_sub, EAX

        MOV EAX, val_a
        IMUL EAX, val_b
        MOV res_mul, EAX

        MOV EAX, val_a
        CDQ                     ; etendre EAX en EDX:EAX (signe)
        IDIV val_b
        MOV res_div, EAX        ; quotient
        MOV res_mod, EDX        ; reste

        ; code de sortie = res_mod (attendu 2) pour verification rapide
        PUSH res_mod
        CALL ExitProcess

END start
