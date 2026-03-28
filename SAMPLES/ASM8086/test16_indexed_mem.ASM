; =============================================================================
; Test 16 : Test des acces memoire indexes (BX+DI+offset, BX+SI+offset)
; Verifie que le transpileur ASM2PAS cree des variables locales au lieu de
; generer Mem[BX+DI+offset] pour une meilleure lisibilite du code.
; =============================================================================

.MODEL SMALL
.STACK 100h

.CODE
START:
    ; Initialiser registres de base et d'index
    MOV BX, 1000h
    MOV DI, 200h
    MOV SI, 100h
    
    ; Procedure qui utilise des acces memoire indexes
    CALL IndexedProc
    
    ; Terminer programme
    MOV AX, 4C00h
    INT 21h

; Procedure utilisant des acces memoire indexes avec plusieurs offsets
IndexedProc PROC NEAR
    PUSH BP
    MOV BP, SP
    PUSH AX
    PUSH BX
    PUSH DI
    
    ; Acces avec offset 2Ch - devrait creer Idx002Ch
    MOV AX, [BX+DI+2Ch]
    ADD AX, 1
    MOV [BX+DI+2Ch], AX
    
    ; Acces avec offset 44h - devrait creer Idx0044h
    MOV AX, [BX+DI+44h]
    SUB AX, 2
    MOV [BX+DI+44h], AX
    
    ; Acces avec offset 10h - devrait creer Idx0010h
    MOV AX, [BX+DI+10h]
    AND AX, 0FFh
    MOV [BX+DI+10h], AX
    
    ; Acces avec BX+SI+offset - devrait creer une autre variable
    MOV AX, [BX+SI+4Ch]
    OR AX, 0Fh
    MOV [BX+SI+4Ch], AX
    
    ; Acces avec offset 0 - devrait creer Idx0000h
    MOV AX, [BX+DI]
    XOR AX, AX
    MOV [BX+DI], AX
    
    POP DI
    POP BX
    POP AX
    POP BP
    RET
IndexedProc ENDP

END START
