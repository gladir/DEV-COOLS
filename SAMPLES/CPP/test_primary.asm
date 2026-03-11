; Genere par CPP86 v1.0
; Compilateur C++ -> ASM 8086 (MASM .MODEL SMALL)

.MODEL SMALL
.STACK 1024

; Declaration anticipee du segment de donnees
_DATA   SEGMENT WORD PUBLIC 'DATA'
_DATA   ENDS

; Segment de code
_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME CS:_TEXT, DS:_DATA, SS:STACK

        MOV AX,42
        MOV WORD PTR [BP-2],AX
        MOV AX,2
        MOV WORD PTR [BP-4],AX
        MOV AX,1
        MOV WORD PTR [BP-6],AX
        MOV AX,4
        MOV WORD PTR [BP-8],AX
        MOV AX,2
        MOV WORD PTR [BP-10],AX
        MOV AX,2
        MOV WORD PTR [BP-12],AX
        MOV AX,2
        CALL _CC_RT_NEW
        MOV WORD PTR [BP-14],AX
        MOV AX,WORD PTR [BP-14]
        CALL _CC_RT_DELETE
        MOV AX,10
        PUSH   DX
        MOV DX,2
        IMUL   DX
        POP    DX
        CALL _CC_RT_NEW
        MOV WORD PTR [BP-16],AX
        MOV AX,WORD PTR [BP-16]
        CALL _CC_RT_DELETE
        MOV AX,100
        MOV WORD PTR [BP-18],AX
        LEA AX,[BP-18]
        MOV WORD PTR [BP-20],AX
        MOV AX,WORD PTR [BP-20]
        MOV BX,AX
        MOV AX,[BX]
        MOV WORD PTR [BP-22],AX
        MOV AX,5
        MOV WORD PTR [BP-24],AX
        MOV AX,WORD PTR [BP-24]
        PUSH   AX
        INC    AX
        MOV WORD PTR [BP-24],AX
        POP    AX
        MOV AX,WORD PTR [BP-24]
        INC    AX
        MOV WORD PTR [BP-24],AX
        MOV AX,WORD PTR [BP-24]
        PUSH   AX
        DEC    AX
        MOV WORD PTR [BP-24],AX
        POP    AX
        MOV AX,WORD PTR [BP-24]
        DEC    AX
        MOV WORD PTR [BP-24],AX
        MOV AX,3
        MOV WORD PTR [BP-26],AX
        MOV AX,7
        MOV WORD PTR [BP-28],AX
        MOV AX,WORD PTR [BP-2]
        PUSH   AX
        MOV AX,WORD PTR [BP-4]
        MOV BX,AX
        POP    AX
        ADD AX,BX
        PUSH   AX
        MOV AX,2
        MOV BX,AX
        POP    AX
        IMUL BX
        MOV WORD PTR [BP-30],AX

; === Runtime library ===

_CC_RT_NEW:
        PUSH   BX
        PUSH   CX
        MOV    CX,AX
        ADD    CX,15
        SHR    CX,1
        SHR    CX,1
        SHR    CX,1
        SHR    CX,1
        INC    CX
        MOV    BX,CX
        MOV    AH,48h
        INT    21h
        JNC    _CC_RT_NEW_OK
        XOR    AX,AX
_CC_RT_NEW_OK:
        POP    CX
        POP    BX
        RET

_CC_RT_DELETE:
        PUSH   ES
        MOV    ES,AX
        MOV    AH,49h
        INT    21h
        POP    ES
        RET


_TEXT   ENDS

_DATA   SEGMENT WORD PUBLIC 'DATA'
_CC_TRUE_S   DB  'true',0
_CC_FALSE_S  DB  'false',0
_CC_NULL_S   DB  '(null)',0
_CC_STRBUF   DB  256 DUP(0)
_CC_V_result  DW  0
_CC_V_g_val  DW  99
_DATA   ENDS

END _main
