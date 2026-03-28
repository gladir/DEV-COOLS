; Test 17 - Pattern If...Then Goto vers If...Then Begin...End
; Ce test utilise RET pour generer Exit;

.MODEL SMALL
.STACK 100h

.DATA
value1 DW 100
value2 DW $D7B3
result DW 0

.CODE
START:
    MOV AX, @DATA
    MOV DS, AX

    MOV AX, value1
    CMP AX, value2
    JNE loc_1C0A

    MOV result, 1
    ADD result, 10
    MOV BX, result
    RET

loc_1C0A:
    MOV AH, 4Ch
    INT 21h
END START
