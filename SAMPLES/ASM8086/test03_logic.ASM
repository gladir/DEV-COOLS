; Test 03 - Operations logiques et comparaisons
; Teste: AND, OR, XOR, NOT, CMP, TEST, SHL, SHR

.MODEL SMALL
.STACK 100h

.DATA
mask DW 0FFh

.CODE
START:
    MOV AX, @DATA
    MOV DS, AX

    ; Logique
    MOV AX, 0FFFFh
    AND AX, 00FFh
    OR AX, 0F00h
    XOR AX, AX
    NOT AX

    ; Decalages
    MOV AX, 1
    SHL AX, 1
    SHL AX, 1
    SHR AX, 1

    ; Comparaison et test
    MOV AX, 5
    CMP AX, 5
    TEST AX, 1

    MOV AH, 4Ch
    INT 21h
END START
