; Programme: TEST
; Compilé par PC8086 - Compilateur Pascal vers 8086
; Date: 2026-02-28

.MODEL SMALL
.STACK 100h

.DATA
X DW ?
Y DW ?
MESSAGE DB 256 DUP(?)

.CODE
MAIN PROC
    mov ax, @data
    mov ds, ax

; Affichage de: Programme de test
    mov dl, 80
    mov ah, 02h
    int 21h
    mov dl, 114
    mov ah, 02h
    int 21h
    mov dl, 111
    mov ah, 02h
    int 21h
    mov dl, 103
    mov ah, 02h
    int 21h
    mov dl, 114
    mov ah, 02h
    int 21h
    mov dl, 97
    mov ah, 02h
    int 21h
    mov dl, 109
    mov ah, 02h
    int 21h
    mov dl, 109
    mov ah, 02h
    int 21h
    mov dl, 101
    mov ah, 02h
    int 21h
    mov dl, 32
    mov ah, 02h
    int 21h
    mov dl, 100
    mov ah, 02h
    int 21h
    mov dl, 101
    mov ah, 02h
    int 21h
    mov dl, 32
    mov ah, 02h
    int 21h
    mov dl, 116
    mov ah, 02h
    int 21h
    mov dl, 101
    mov ah, 02h
    int 21h
    mov dl, 115
    mov ah, 02h
    int 21h
    mov dl, 116
    mov ah, 02h
    int 21h
    mov dl, 13
    mov ah, 02h
    int 21h
    mov dl, 10
    mov ah, 02h
    int 21h
; Affichage de: Fin du test
    mov dl, 70
    mov ah, 02h
    int 21h
    mov dl, 105
    mov ah, 02h
    int 21h
    mov dl, 110
    mov ah, 02h
    int 21h
    mov dl, 32
    mov ah, 02h
    int 21h
    mov dl, 100
    mov ah, 02h
    int 21h
    mov dl, 117
    mov ah, 02h
    int 21h
    mov dl, 32
    mov ah, 02h
    int 21h
    mov dl, 116
    mov ah, 02h
    int 21h
    mov dl, 101
    mov ah, 02h
    int 21h
    mov dl, 115
    mov ah, 02h
    int 21h
    mov dl, 116
    mov ah, 02h
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
; Affiche le nombre dans AX
    ; Implémentation simplifiée pour afficher un nombre
    ; (code complet requis pour conversion décimale)
    mov dx, ax
    add dl, 48  ; Convertir en ASCII (pour chiffres 0-9 seulement)
    mov ah, 02h
    int 21h
    ret
PRINT_NUM ENDP
