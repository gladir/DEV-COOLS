; ========================================
; Genere par VAXPAS86 v1.0 (2026-03-07)
; Source : SAMPLES\VAXPASCAL\test_func.pas
; ========================================

.MODEL SMALL
.STACK 1024

; --- Segment de code ---
_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME CS:_TEXT, DS:_DATA

; --- Point d entree principal ---
_VXPF_MAIN:
        MOV   AX, _DATA
        MOV   DS, AX
        JMP   _VXPL_MAINBODY


; --- factorial ---
_VXPF_FACTORIAL   PROC NEAR
        PUSH   BP
        MOV   BP, SP
        SUB   SP, 2
        PUSH   SI
        PUSH   DI
        MOV   WORD PTR [BP-2], 0
; exception: sauvegarder handler parent
        PUSH   WORD PTR [_VXPRT_EXCHDL]
        PUSH   WORD PTR [_VXPRT_EXCSP]
        PUSH   WORD PTR [_VXPRT_EXCBP]
        MOV   WORD PTR [_VXPRT_EXCHDL], OFFSET _VXPL_2
        MOV   WORD PTR [_VXPRT_EXCSP], SP
        MOV   WORD PTR [_VXPRT_EXCBP], BP
; if
        MOV   AX, WORD PTR [BP+4]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        CMP   AX, BX
        MOV   AX, 0
        JG   _VXPL_4
        INC    AX
_VXPL_4:
        TEST   AX, AX
        JZ   _VXPL_5
; assign retval factorial
        MOV   AX, 1
        MOV   WORD PTR [BP-2], AX
        JMP   _VXPL_6
_VXPL_5:
; assign retval factorial
        MOV   AX, WORD PTR [BP+4]
        PUSH   AX
; call factorial
        MOV   AX, WORD PTR [BP+4]
        PUSH   AX
        MOV   AX, 1
        MOV   BX, AX
        POP   AX
        SUB   AX, BX
        PUSH   AX
        CALL   _VXPF_FACTORIAL
        MOV   BX, AX
        POP   AX
        IMUL   BX
        MOV   WORD PTR [BP-2], AX
_VXPL_6:
; exception: pas d erreur, restaurer handler parent
        POP   WORD PTR [_VXPRT_EXCBP]
        POP   WORD PTR [_VXPRT_EXCSP]
        POP   WORD PTR [_VXPRT_EXCHDL]
        JMP   _VXPL_3
_VXPL_2:
; exception handler
        POP   WORD PTR [_VXPRT_EXCBP]
        POP   WORD PTR [_VXPRT_EXCSP]
        POP   WORD PTR [_VXPRT_EXCHDL]
_VXPL_3:
_VXPL_1:
        MOV   AX, WORD PTR [BP-2]
        POP   DI
        POP   SI
        MOV   SP, BP
        POP   BP
        RET   2
_VXPF_FACTORIAL   ENDP


; --- max_of ---
_VXPF_MAX_OF   PROC NEAR
        PUSH   BP
        MOV   BP, SP
        SUB   SP, 2
        PUSH   SI
        PUSH   DI
        MOV   WORD PTR [BP-2], 0
; exception: sauvegarder handler parent
        PUSH   WORD PTR [_VXPRT_EXCHDL]
        PUSH   WORD PTR [_VXPRT_EXCSP]
        PUSH   WORD PTR [_VXPRT_EXCBP]
        MOV   WORD PTR [_VXPRT_EXCHDL], OFFSET _VXPL_8
        MOV   WORD PTR [_VXPRT_EXCSP], SP
        MOV   WORD PTR [_VXPRT_EXCBP], BP
; if
        MOV   AX, WORD PTR [BP+6]
        PUSH   AX
        MOV   AX, WORD PTR [BP+4]
        MOV   BX, AX
        P