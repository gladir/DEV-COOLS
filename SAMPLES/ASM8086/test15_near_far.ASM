; Test 15 - Near et Far procedures
; Teste: Directives Near et Far dans les declarations Pascal generees

.MODEL SMALL
.STACK 100h

.DATA
result DW 0

.CODE

; Procedure NEAR explicite sans parametres
MyNearProc PROC NEAR
    MOV AX, 42
    RET
MyNearProc ENDP

; Procedure FAR explicite sans parametres  
MyFarProc PROC FAR
    MOV AX, 100
    RETF
MyFarProc ENDP

START:
    MOV AX, @DATA
    MOV DS, AX
    
    ; Appeler MyNearProc
    CALL MyNearProc
    MOV result, AX
    
    ; Appeler MyFarProc
    CALL FAR PTR MyFarProc
    MOV result, AX
    
    MOV AH, 4Ch
    INT 21h
END START
