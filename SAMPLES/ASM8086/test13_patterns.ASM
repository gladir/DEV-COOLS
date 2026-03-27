; Test 13 - Detection de patterns assembleur -> unite Strings
; Teste: procedures qui implementent strcpy/strlen/strlower via
;   REPNE SCASB + REP MOVSB (strcpy)
;   REPNE SCASB + NEG CX (strlen variante NOT CX + DEC CX)
;   REPNE SCASB + NEG AX (strlen variante MOV AX,CX + INC + INC + NEG AX)
;   boucle char par char, compare 41h-5Ah, ADD 20h (strlower)
; Le transpileur doit reconnaitre ces patterns et generer des
; appels a StrCopy/StrLen/StrLower de l'unite Strings au lieu de
; traduire chaque instruction individuellement.

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

; --- Pattern strlen : REPNE SCASB + NOT CX + DEC CX ---
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

; --- Pattern strlen variante : REPNE SCASB + NEG AX ---
; Meme calcul de longueur mais avec MOV AX,CX + INC + INC + NEG AX.
my_strlen2 PROC NEAR
    PUSH BP
    MOV BP, SP
    PUSH DI
    PUSH DS
    POP ES
    MOV DI, [BP+04h]
    XOR AX, AX
    MOV CX, FFFFh
    REPNE SCASB
    MOV AX, CX
    INC AX
    INC AX
    NEG AX
    POP DI
    MOV SP, BP
    POP BP
    RET
my_strlen2 ENDP

; --- Pattern strlower : boucle char par char, compare 41h-5Ah, ADD 20h ---
; Convertit une chaine en minuscules, retourne pointeur original.
my_strlower PROC NEAR
    PUSH BP
    MOV BP, SP
    PUSH SI
    MOV SI, [BP+04h]
    MOV DX, SI
    MOV BH, 41h
    MOV BL, 5Ah
    MOV AL, 20h
    XOR CX, CX
loc_sl_loop:
    MOV CL, [SI]
    JCXZ loc_sl_done
    CMP CL, BH
    JB loc_sl_next
    CMP CL, BL
    JNBE loc_sl_next
    ADD CL, AL
    MOV [SI], CL
loc_sl_next:
    INC SI
    JMP loc_sl_loop
loc_sl_done:
    MOV AX, DX
    POP SI
    MOV SP, BP
    POP BP
    RET
my_strlower ENDP

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

    ; Calculer la longueur via my_strlen2 (variante NEG AX)
    LEA AX, dst
    PUSH AX
    CALL my_strlen2
    ADD SP, 2

    ; Convertir dst en minuscules via my_strlower
    LEA AX, dst
    PUSH AX
    CALL my_strlower
    ADD SP, 2

    MOV AH, 4Ch
    INT 21h
END START
