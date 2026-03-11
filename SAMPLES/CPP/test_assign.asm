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

        MOV AX,100
        MOV WORD PTR [BP-2],AX
        MOV AX,3
        MOV WORD PTR [BP-4],AX
        MOV AX,WORD PTR [BP-2]
        MOV WORD PTR [BP-6],AX
        MOV AX,10
        MOV BX,AX
        MOV AX,WORD PTR [BP-2]
        ADD AX,BX
        MOV WORD PTR [BP-2],AX
        MOV AX,1
        MOV BX,AX
        MOV AX,WORD PTR [BP-4]
        SUB AX,BX
        MOV WORD PTR [BP-4],AX
        MOV AX,2
        MOV BX,AX
        MOV AX,WORD PTR [BP-2]
        IMUL BX
        MOV WORD PTR [BP-2],AX
        MOV AX,2
        MOV BX,AX
        MOV AX,WORD PTR [BP-4]
        CMP BX,0
        JE _CC_L_1
        CWD
        IDIV BX
        JMP _CC_L_2
_CC_L_1:
        XOR AX,AX
_CC_L_2:
        MOV WORD PTR [BP-4],AX
        MOV AX,7
        MOV BX,AX
        MOV AX,WORD PTR [BP-6]
        CMP BX,0
        JE _CC_L_3
        CWD
        IDIV BX
        MOV AX,DX
        JMP _CC_L_4
_CC_L_3:
        XOR AX,AX
_CC_L_4:
        MOV WORD PTR [BP-6],AX
        MOV AX,WORD PTR [BP-2]
        PUSH   AX
        MOV AX,255
        MOV BX,AX
        POP    AX
        AND AX,BX
        MOV WORD PTR [BP-8],AX
        MOV AX,WORD PTR [BP-4]
        PUSH   AX
        MOV AX,16
        MOV BX,AX
        POP    AX
        OR AX,BX
        MOV WORD PTR [BP-10],AX
        MOV AX,WORD PTR [BP-6]
        PUSH   AX
        MOV AX,3
        MOV BX,AX
        POP    AX
        XOR AX,BX
        MOV WORD PTR [BP-12],AX
        MOV AX,2
        MOV BX,AX
        MOV AX,WORD PTR [BP-8]
        MOV CL,BL
        SAL AX,CL
        MOV WORD PTR [BP-8],AX
        MOV AX,1
        MOV BX,AX
        MOV AX,WORD PTR [BP-10]
        MOV CL,BL
        SAR AX,CL
        MOV WORD PTR [BP-10],AX
        MOV AX,WORD PTR [BP-2]
        PUSH   AX
        INC    AX
        MOV WORD PTR [BP-2],AX
        POP    AX
        MOV AX,WORD PTR [BP-4]
        PUSH   AX
        DEC    AX
        MOV WORD PTR [BP-4],AX
        POP    AX
        MOV AX,WORD PTR [BP-6]
        INC    AX
        MOV WORD PTR [BP-6],AX
        MOV AX,WORD PTR [BP-8]
        DEC    AX
        MOV WORD PTR [BP-8],AX
        MOV AX,1
        MOV WORD PTR [BP-14],AX
        MOV AX,2
        MOV WORD PTR [BP-16],AX
        MOV AX,3
        MOV WORD PTR [BP-18],AX

_TEXT   ENDS

_DATA   SEGMENT WORD PUBLIC 'DATA'
_CC_TRUE_S   DB  'true',0
_CC_FALSE_S  DB  'false',0
_CC_NULL_S   DB  '(null)',0
_CC_STRBUF   DB  256 DUP(0)
_CC_V_counter  DW  0
_CC_V_LIMIT  DW  255
_DATA   ENDS

END _main
