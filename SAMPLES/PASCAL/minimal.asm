; Programme: MINIMAL
; Compilé par PC8086 - Compilateur Pascal vers 8086
; Date: 2026-02-28 20:19:14

.MODEL SMALL
.STACK 100h

.DATA
TRUE_STR  DB 'TRUE$'
FALSE_STR DB 'FALSE$'


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
