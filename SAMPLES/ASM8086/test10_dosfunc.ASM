; Test 10 - Fonctions DOS de l'unite Dos
; Teste: INT 21h AX=3300h (GetCBreak), AX=3301h (SetCBreak)
;        INT 21h AH=54h (GetVerify), AH=2Eh (SetVerify)
;        INT 21h AH=36h (DiskFree/DiskSize)
; Verifie que ASM2PAS utilise les fonctions Dos au lieu de Intr()

.MODEL SMALL
.STACK 100h

.DATA

.CODE
START:
    MOV AX, @DATA
    MOV DS, AX

    ; GetCBreak (INT 21h / AX=3300h)
    MOV AX, 3300h
    INT 21h

    ; SetCBreak (INT 21h / AX=3301h)
    MOV DL, 1
    MOV AX, 3301h
    INT 21h

    ; GetVerify (INT 21h / AH=54h)
    MOV AH, 54h
    INT 21h

    ; SetVerify (INT 21h / AH=2Eh)
    MOV AL, 0
    MOV AH, 2Eh
    INT 21h

    ; DiskFree (INT 21h / AH=36h)
    MOV DL, 0
    MOV AH, 36h
    INT 21h

    ; Terminer
    MOV AH, 4Ch
    MOV AL, 0
    INT 21h
END START
