; Test 13 - Detection de patterns assembleur -> unite Strings
; Teste: procedures qui implementent strcpy/strlen via
;   REPNE SCASB + REP MOVSB (strcpy)
;   REPNE SCASB + NEG CX (strlen)
; Le transpileur doit reconnaitre ces patterns et generer des
; appels a StrCopy/StrLen de l'unite Strings au lieu de traduire
; chaque instruction individuellement.

.MODEL SMALL
.STACK 100h

.DATA
src DB 'Hello World', 0
dst DB 32 DUP(0)

.CODE

; --- Pattern strcpy : REPNE SCASB + REP MOVSB ---
; Copie la chaine source vers destination, retourne pointeur dest.
my_strcpy PROC NEAR
    PUSH BP
    MOV BP, SP
    PUSH DI
    PUSH SI
    PUSH DS
    POP ES
    MOV DI, [BP+06h]
    MOV SI, DI
    XOR AX, AX
    MOV CX, 0FFFFh
    REPNE SCASB
    INC CX
    NEG CX
    MOV DI, [BP+04h]
    MOV DX, DI
    REP MOVSB
    MOV AX, DX
    POP SI
    POP DI
    MOV SP, BP
    POP BP
    RET
my_strcpy ENDP

; --- Pattern strlen : REPNE SCASB + NEG CX ---
; Calcule la longueur d'une chaine ASCIIZ, retourne dans AX.
my_strlen PROC NEAR
    PUSH BP
    MOV BP, SP
    PUSH DI
    PUSH DS
    POP ES
    MOV DI, [BP+04h]
    XOR AX, AX
    MOV CX, 0FFFFh
    REPNE SCASB
    NOT CX
    DEC CX
    MOV AX, CX
    POP DI
    MOV SP, BP
    POP BP
    RET
my_strlen ENDP

START:
    MOV AX, @DATA
    MOV DS, AX

    ; Copier src -> dst via my_strcpy
    LEA AX, src
    PUSH AX
    LEA AX, dst
    PUSH AX
    CALL my_strcpy
    ADD SP, 4

    ; Calculer la longueur de dst via my_strlen
    LEA AX, dst
    PUSH AX
    CALL my_strlen
    ADD SP, 2

    MOV AH, 4Ch
    INT 21h
END START
