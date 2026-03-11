; Programme: SIMPLE_FOR
; Compilé par PC8086 - Compilateur Pascal vers 8086
; Date: 2026-02-28 20:26:04

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

    mov ax, 1
    mov [I], ax
    mov ax, 3
    mov bx, ax
L1:
    mov ax, [I]
    cmp ax, bx
    jg L3
; Affichage variable: I
    mov ax, I
    call PRINT_NUM
    mov dl, 13
    mov ah, 02h
    int 21h
    mov dl, 10
    mov ah, 02h
    int 21h
L2:
    mov ax, [I]
    inc ax
    mov [I], ax
    jmp L1
L3:

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
