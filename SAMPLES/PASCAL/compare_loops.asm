; Programme: COMPARAISONWHILEREPEAT
; Compilé par PC8086 - Compilateur Pascal vers 8086
; Date: 2026-02-28

.MODEL SMALL
.STACK 100h

.DATA
TRUE_STR  DB 'TRUE$'
FALSE_STR DB 'FALSE$'

I DW ?

.CODE
MAIN PROC
    mov ax, @data
    mov ds, ax

; Affichage chaîne: === Test WHILE ===
.DATA
STR0 DB '=== Test WHILE ===$'
    mov dx, OFFSET STR0
    mov ah, 09h
    int 21h
    mov dl, 13
    mov ah, 02h
    int 21h
    mov dl, 10
    mov ah, 02h
    int 21h
    mov ax, 10
    mov I, ax
L2:
    mov al, 73
    cmp al, 10
    mov ax, 1
    jl COMP_TRUE_3
    mov ax, 0
COMP_TRUE_3:
    cmp ax, 0
    je L3
; Affichage chaîne: Ceci ne devrait pas s afficher
STR4 DB 'Ceci ne devrait pas s afficher$'
    mov dx, OFFSET STR4
    mov ah, 09h
    int 21h
    mov dl, 13
    mov ah, 02h
    int 21h
    mov dl, 10
    mov ah, 02h
    int 21h
    mov al, 73
    add al, 1
    mov I, ax
    jmp L2
L3:
; Affichage chaîne: WHILE termine, i = 10
STR5 DB 'WHILE termine, i = 10$'
    mov dx, OFFSET STR5
    mov ah, 09h
    int 21h
    mov dl, 13
    mov ah, 02h
    int 21h
    mov dl, 10
    mov ah, 02h
    int 21h
; Affichage chaîne: === Test REPEAT ===
STR6 DB '=== Test REPEAT ===$'
    mov dx, OFFSET STR6
    mov ah, 09h
    int 21h
    mov dl, 13
    mov ah, 02h
    int 21h
    mov dl, 10
    mov ah, 02h
    int 21h
    mov ax, 10
    mov I, ax
L8:
; Affichage chaîne: Ceci s affiche au moins une fois
STR8 DB 'Ceci s affiche au moins une fois$'
    mov dx, OFFSET STR8
    mov ah, 09h
    int 21h
    mov dl, 13
    mov ah, 02h
    int 21h
    mov dl, 10
    mov ah, 02h
    int 21h
    mov al, 73
    add al, 1
    mov I, ax
    mov al, 73
    cmp al, 11
    mov ax, 1
    jge COMP_TRUE_9
    mov ax, 0
COMP_TRUE_9:
    cmp ax, 0
    je L8
; Affichage chaîne: REPEAT termine
STR10 DB 'REPEAT termine$'
    mov dx, OFFSET STR10
    mov ah, 09h
    int 21h
    mov dl, 13
    mov ah, 02h
    int 21h
    mov dl, 10
    mov ah, 02h
    int 21h

    mov ax, 4C00h
    int 21h
MAIN ENDP
END MAIN

; Procédures d'aide pour l'affichage
PRINT_NUM PROC
; Affiche le nombre dans AX en décimal
    push ax
    push bx
    push cx
    push dx

; Traiter le signe négatif
    cmp ax, 0
    jge PRINT_POSITIVE
    mov dl, '-'
    mov ah, 02h
    int 21h
    neg ax

PRINT_POSITIVE:
; Conversion en décimal et affichage
    mov cx, 0    ; Compteur de chiffres
    mov bx, 10   ; Diviseur

PUSH_DIGITS:
    mov dx, 0
    div bx       ; AX = AX / 10, DX = reste
    add dl, 48   ; Convertir en ASCII
    push dx      ; Empiler le chiffre
    inc cx       ; Incrémenter compteur
    cmp ax, 0
    jne PUSH_DIGITS

POP_DIGITS:
    pop dx       ; Dépiler et afficher
    mov ah, 02h
    int 21h
    loop POP_DIGITS

    pop dx
    pop cx
    pop bx
    pop ax
    ret
PRINT_NUM ENDP
