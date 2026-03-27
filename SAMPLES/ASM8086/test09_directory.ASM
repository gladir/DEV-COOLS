; Test 09 - Operations sur les repertoires (WinDOS)
; Teste: INT 21h AH=39h (CreateDir), AH=3Ah (RemoveDir), AH=3Bh (SetCurDir)
; Verifie que ASM2PAS utilise WinDOS au lieu de code assembleur long

.MODEL SMALL
.STACK 100h

.DATA
dirname DB 'TESTDIR', 0

.CODE
START:
    MOV AX, @DATA
    MOV DS, AX

    ; Creer un repertoire (INT 21h / AH=39h)
    LEA DX, dirname
    MOV AH, 39h
    INT 21h

    ; Changer vers ce repertoire (INT 21h / AH=3Bh)
    LEA DX, dirname
    MOV AH, 3Bh
    INT 21h

    ; Revenir au repertoire parent
    ; Supprimer le repertoire (INT 21h / AH=3Ah)
    LEA DX, dirname
    MOV AH, 3Ah
    INT 21h

    ; Terminer
    MOV AH, 4Ch
    MOV AL, 0
    INT 21h
END START
