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

        MOV AX,10
        MOV WORD PTR [BP-2],AX
        MOV AX,20
        MOV WORD PTR [BP-4],AX
        MOV AX,WORD PTR [BP-2]
        PUSH   AX
        MOV AX,WORD PTR [BP-4]
        MOV BX,AX
        POP    AX
        ADD AX,BX
        MOV WORD PTR [BP-6],AX
        MOV AX,WORD PTR [BP-2]
        PUSH   AX
        MOV AX,1
        MOV BX,AX
        POP    AX
        ADD AX,BX
        MOV WORD PTR [BP-2],AX
        MOV AX,WORD PTR [BP-4]
        PUSH   AX
        MOV AX,1
        MOV BX,AX
        POP    AX
        SUB AX,BX
        MOV WORD PTR [BP-4],AX
        MOV AX,5
        MOV WORD PTR [BP-8],AX
        MOV AX,6
        MOV WORD PTR [BP-10],AX
        MOV AX,7
        MOV WORD PTR [BP-12],AX
        MOV AX,WORD PTR [BP-10]
        MOV BX,AX
        MOV AX,WORD PTR [BP-8]
        ADD AX,BX
        MOV WORD PTR [BP-8],AX
        MOV AX,2
        MOV BX,AX
        MOV AX,WORD PTR [BP-12]
        SUB AX,BX
        MOV WORD PTR [BP-12],AX
        MOV AX,WORD PTR [BP-2]
        PUSH   AX
        INC    AX
        MOV WORD PTR [BP-2],AX
        POP    AX
        MOV AX,WORD PTR [BP-4]
        DEC    AX
        MOV WORD PTR [BP-4],AX

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
_CC_V_g  DW  42
_CC_V_h  DW  0
_CC_V_MAX  DW  100
_DATA   ENDS

END _main
