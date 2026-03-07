; Programme: DEBUGLABEL
; Compilé par PC8086 - Compilateur Pascal vers 8086
; Date: 2026-02-28 22:56:37

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

; Procédures d'aide pour les chaînes
COPY_STR PROC
; Copie une chaîne de SI vers DI (format Pascal: longueur + caractères)
    push ax
    push cx
    push si
    push di

; Lire la longueur
    lodsb            ; Charger longueur depuis [SI]
    stosb            ; Stocker longueur vers [DI]
    mov cl, al       ; Nombre de caractères à copier
    mov ch, 0

; Copier les caractères
    rep movsb        ; Copier CX caractères

    pop di
    pop si
    pop cx
    pop ax
    ret
COPY_STR ENDP

CONCAT_STR PROC
; Concatène deux chaînes: SI (source1) + DI (source2) -> SI (résultat)
    push ax
    push bx
    push cx
    push dx
    push di

; Calculer la longueur totale
    mov al, [si]     ; Longueur chaîne 1
    mov bl, [di]     ; Longueur chaîne 2
    add al, bl       ; Longueur totale
    cmp al, 255      ; Vérifier dépassement
    jbe CONCAT_OK
    mov al, 255      ; Limiter à 255

CONCAT_OK:
; Stocker nouvelle longueur
    mov [si], al

; Positionner pour copie de la deuxième chaîne
    mov cl, [si]     ; Longueur chaîne 1 originale
    mov ch, 0
    mov dx, si
    inc dx           ; Pointer après longueur
    add dx, cx       ; Pointer après chaîne 1

; Copier la deuxième chaîne
    mov cl, [di]     ; Longueur chaîne 2
    inc di           ; Pointer après longueur
    mov si, di       ; Source = chaîne 2
    mov di, dx       ; Destination = fin de chaîne 1
    rep movsb        ; Copier

    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
CONCAT_STR ENDP

COMPARE_STR PROC
; Compare deux chaînes SI et DI, résultat dans AX (0=égal, 1=différent)
    push bx
    push cx
    push dx
    push si
    push di

; Lire la longueur
    lodsb            ; Charger longueur depuis [SI]
    mov cl, al
    mov ch, 0
    jcxz COMP_STR_END

COMP_STR_LOOP:
    lodsb            ; Charger caractère
    mov dl, al       ; Caractère à comparer
    cmp dl, [di]
    jne COMP_DIFF
    loop COMP_STR_LOOP

COMP_DIFF:
    mov ax, 1        ; Différent
    jmp COMP_END

COMP_EQUAL:
    mov ax, 0        ; Égal

COMP_END:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret
COMPARE_STR ENDP

PRINT_STR PROC
; Affiche une chaîne Pascal pointée par SI
    push ax
    push cx
    push dx
    push si

; Lire la longueur
    lodsb            ; AL = longueur
    mov cl, al
    mov ch, 0
    jcxz PRINT_STR_END

PRINT_CHAR_LOOP:
    lodsb            ; Charger caractère
    mov dl, al       ; Caractère à afficher
    mov ah, 02h      ; Fonction DOS affichage caractère
    int 21h
    loop PRINT_CHAR_LOOP

PRINT_STR_END:
    pop si
    pop dx
    pop cx
    pop ax
    ret
PRINT_STR ENDP
