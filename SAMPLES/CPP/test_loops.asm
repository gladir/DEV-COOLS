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

        MOV AX,0
        MOV WORD PTR [BP-2],AX
        MOV AX,1
        MOV WORD PTR [BP-4],AX
; while
_CC_L_1:
        MOV AX,WORD PTR [BP-4]
        PUSH   AX
        MOV AX,5
        MOV BX,AX
        POP    AX
        CMP AX,BX
        JLE _CC_L_3
        XOR AX,AX
        JMP _CC_L_4
_CC_L_3:
        MOV AX,1
_CC_L_4:
        TEST AX,AX
        JZ _CC_L_2
        MOV AX,WORD PTR [BP-2]
        PUSH   AX
        MOV AX,WORD PTR [BP-4]
        MOV BX,AX
        POP    AX
        ADD AX,BX
        MOV WORD PTR [BP-2],AX
        MOV AX,WORD PTR [BP-4]
        PUSH   AX
        MOV AX,1
        MOV BX,AX
        POP    AX
        ADD AX,BX
        MOV WORD PTR [BP-4],AX
        JMP _CC_L_1
_CC_L_2:
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_5
        MOV BX,1
        CALL _CC_RT_WRITESTR
        MOV AX,WORD PTR [BP-2]
        MOV BX,1
        CALL _CC_RT_WRITENUM
        MOV BX,1
        CALL _CC_RT_WRITECRLF
        MOV AX,0
        MOV WORD PTR [BP-6],AX
        MOV AX,1
        MOV WORD PTR [BP-8],AX
; do-while
_CC_L_6:
        MOV AX,WORD PTR [BP-6]
        PUSH   AX
        MOV AX,WORD PTR [BP-8]
        MOV BX,AX
        POP    AX
        ADD AX,BX
        MOV WORD PTR [BP-6],AX
        MOV AX,WORD PTR [BP-8]
        PUSH   AX
        MOV AX,1
        MOV BX,AX
        POP    AX
        ADD AX,BX
        MOV WORD PTR [BP-8],AX
_CC_L_7:
        MOV AX,WORD PTR [BP-8]
        PUSH   AX
        MOV AX,3
        MOV BX,AX
        POP    AX
        CMP AX,BX
        JLE _CC_L_9
        XOR AX,AX
        JMP _CC_L_10
_CC_L_9:
        MOV AX,1
_CC_L_10:
        TEST AX,AX
        JNZ _CC_L_6
_CC_L_8:
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_11
        MOV BX,1
        CALL _CC_RT_WRITESTR
        MOV AX,WORD PTR [BP-6]
        MOV BX,1
        CALL _CC_RT_WRITENUM
        MOV BX,1
        CALL _CC_RT_WRITECRLF
        MOV AX,0
        MOV WORD PTR [BP-10],AX
; for
        MOV AX,0
        MOV WORD PTR [BP-12],AX
_CC_L_12:
        MOV AX,WORD PTR [BP-12]
        PUSH   AX
        MOV AX,5
        MOV BX,AX
        POP    AX
        CMP AX,BX
        JL _CC_L_16
        XOR AX,AX
        JMP _CC_L_17
_CC_L_16:
        MOV AX,1
_CC_L_17:
        TEST AX,AX
        JZ _CC_L_14
        JMP _CC_L_15
_CC_L_13:
        MOV AX,WORD PTR [BP-12]
        PUSH   AX
        MOV AX,1
        MOV BX,AX
        POP    AX
        ADD AX,BX
        MOV WORD PTR [BP-12],AX
        JMP _CC_L_12
_CC_L_15:
        MOV AX,WORD PTR [BP-10]
        PUSH   AX
        MOV AX,WORD PTR [BP-12]
        MOV BX,AX
        POP    AX
        ADD AX,BX
        MOV WORD PTR [BP-10],AX
        JMP _CC_L_13
_CC_L_14:
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_18
        MOV BX,1
        CALL _CC_RT_WRITESTR
        MOV AX,WORD PTR [BP-10]
        MOV BX,1
        CALL _CC_RT_WRITENUM
        MOV BX,1
        CALL _CC_RT_WRITECRLF
        MOV AX,0
        MOV WORD PTR [BP-14],AX
        MOV AX,0
        MOV WORD PTR [BP-16],AX
; while
_CC_L_19:
        MOV AX,WORD PTR [BP-16]
        PUSH   AX
        MOV AX,100
        MOV BX,AX
        POP    AX
        CMP AX,BX
        JL _CC_L_21
        XOR AX,AX
        JMP _CC_L_22
_CC_L_21:
        MOV AX,1
_CC_L_22:
        TEST AX,AX
        JZ _CC_L_20
; if
        MOV AX,WORD PTR [BP-16]
        PUSH   AX
        MOV AX,3
        MOV BX,AX
        POP    AX
        CMP AX,BX
        JGE _CC_L_23
        XOR AX,AX
        JMP _CC_L_24
_CC_L_23:
        MOV AX,1
_CC_L_24:
        TEST AX,AX
        JZ _CC_L_25
; break
        JMP _CC_L_20
_CC_L_25:
        MOV AX,WORD PTR [BP-14]
        PUSH   AX
        MOV AX,WORD PTR [BP-16]
        MOV BX,AX
        POP    AX
        ADD AX,BX
        MOV WORD PTR [BP-14],AX
        MOV AX,WORD PTR [BP-16]
        PUSH   AX
        MOV AX,1
        MOV BX,AX
        POP    AX
        ADD AX,BX
        MOV WORD PTR [BP-16],AX
        JMP _CC_L_19
_CC_L_20:
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_27
        MOV BX,1
        CALL _CC_RT_WRITESTR
        MOV AX,WORD PTR [BP-14]
        MOV BX,1
        CALL _CC_RT_WRITENUM
        MOV BX,1
        CALL _CC_RT_WRITECRLF
        MOV AX,0
        MOV WORD PTR [BP-18],AX
; for
        MOV AX,0
        MOV WORD PTR [BP-20],AX
_CC_L_28:
        MOV AX,WORD PTR [BP-20]
        PUSH   AX
        MOV AX,5
        MOV BX,AX
        POP    AX
        CMP AX,BX
        JL _CC_L_32
        XOR AX,AX
        JMP _CC_L_33
_CC_L_32:
        MOV AX,1
_CC_L_33:
        TEST AX,AX
        JZ _CC_L_30
        JMP _CC_L_31
_CC_L_29:
        MOV AX,WORD PTR [BP-20]
        PUSH   AX
        MOV AX,1
        MOV BX,AX
        POP    AX
        ADD AX,BX
        MOV WORD PTR [BP-20],AX
        JMP _CC_L_28
_CC_L_31:
; if
        MOV AX,WORD PTR [BP-20]
        PUSH   AX
        MOV AX,2
        MOV BX,AX
        POP    AX
        CMP AX,BX
        JE _CC_L_34
        XOR AX,AX
        JMP _CC_L_35
_CC_L_34:
        MOV AX,1
_CC_L_35:
        TEST AX,AX
        JZ _CC_L_36
; continue
        JMP _CC_L_29
_CC_L_36:
        MOV AX,WORD PTR [BP-18]
        PUSH   AX
        MOV AX,WORD PTR [BP-20]
        MOV BX,AX
        POP    AX
        ADD AX,BX
        MOV WORD PTR [BP-18],AX
        JMP _CC_L_29
_CC_L_30:
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_38
        MOV BX,1
        CALL _CC_RT_WRITESTR
        MOV AX,WORD PTR [BP-18]
        MOV BX,1
        CALL _CC_RT_WRITENUM
        MOV BX,1
        CALL _CC_RT_WRITECRLF

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

_CC_RT_WRITESTR:
        PUSH   AX
        PUSH   CX
        PUSH   SI
        MOV    SI,DX
        XOR    CX,CX
_CC_RT_WSTRL:
        CMP    BYTE PTR [SI],0
        JE     _CC_RT_WSTRD
        INC    SI
        INC    CX
        JMP    _CC_RT_WSTRL
_CC_RT_WSTRD:
        MOV    AH,40h
        INT    21h
        POP    SI
        POP    CX
        POP    AX
        RET

_CC_RT_WRITECRLF:
        PUSH   AX
        PUSH   CX
        PUSH   DX
        MOV    DX,OFFSET _CC_RT_CRLF
        MOV    CX,2
        MOV    AH,40h
        INT    21h
        POP    DX
        POP    CX
        POP    AX
        RET

_CC_RT_NUMTOSTR:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        PUSH   DI
        MOV    DI,OFFSET _CC_RT_NUMBUF
        XOR    CX,CX
        OR     AX,AX
        JNS    _CC_RT_NTPOS
        MOV    BYTE PTR [DI],45
        INC    DI
        NEG    AX
_CC_RT_NTPOS:
        MOV    BX,10
_CC_RT_NTLP:
        XOR    DX,DX
        DIV    BX
        PUSH   DX
        INC    CX
        OR     AX,AX
        JNZ    _CC_RT_NTLP
_CC_RT_NTPOP:
        POP    DX
        ADD    DL,30h
        MOV    [DI],DL
        INC    DI
        DEC    CX
        JNZ    _CC_RT_NTPOP
        MOV    BYTE PTR [DI],0
        POP    DI
        POP    DX
        POP    CX
        POP    BX
        RET

_CC_RT_WRITENUM:
        PUSH   BX
        CALL   _CC_RT_NUMTOSTR
        POP    BX
        MOV    DX,OFFSET _CC_RT_NUMBUF
        CALL   _CC_RT_WRITESTR
        RET

_CC_RT_STRTONUM:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        XOR    AX,AX
        XOR    CX,CX
_CC_RT_SNSKP:
        CMP    BYTE PTR [SI],32
        JNE    _CC_RT_SNSGN
        INC    SI
        JMP    _CC_RT_SNSKP
_CC_RT_SNSGN:
        CMP    BYTE PTR [SI],45
        JNE    _CC_RT_SNCHK
        MOV    CX,1
        INC    SI
        JMP    _CC_RT_SNLP
_CC_RT_SNCHK:
        CMP    BYTE PTR [SI],43
        JNE    _CC_RT_SNLP
        INC    SI
_CC_RT_SNLP:
        MOV    BL,[SI]
        CMP    BL,48
        JB     _CC_RT_SNDN
        CMP    BL,57
        JA     _CC_RT_SNDN
        SUB    BL,48
        XOR    BH,BH
        PUSH   BX
        MOV    BX,10
        MUL    BX
        POP    BX
        ADD    AX,BX
        INC    SI
        JMP    _CC_RT_SNLP
_CC_RT_SNDN:
        OR     CX,CX
        JZ     _CC_RT_SNEX
        NEG    AX
_CC_RT_SNEX:
        POP    DX
        POP    CX
        POP    BX
        RET

_CC_RT_READLINE:
        PUSH   AX
        PUSH   BX
        PUSH   DX
        PUSH   SI
        MOV    DX,OFFSET _CC_RT_INBUF
        MOV    AH,0Ah
        INT    21h
        MOV    SI,OFFSET _CC_RT_INBUF
        XOR    BX,BX
        MOV    BL,[SI+1]
        MOV    BYTE PTR [SI+BX+2],0
        MOV    DL,13
        MOV    AH,02h
        INT    21h
        MOV    DL,10
        MOV    AH,02h
        INT    21h
        POP    SI
        POP    DX
        POP    BX
        POP    AX
        RET


_TEXT   ENDS

_DATA   SEGMENT WORD PUBLIC 'DATA'
_CC_TRUE_S   DB  'true',0
_CC_FALSE_S  DB  'false',0
_CC_NULL_S   DB  '(null)',0
_CC_STRBUF   DB  256 DUP(0)
_CC_RT_CRLF     DB  13,10
_CC_RT_NUMBUF   DB  8 DUP(0)
_CC_RT_INBUF    DB  80,0,80 DUP(0)
_CC_K_5  DB  'while sum = ',0
_CC_K_11  DB  'do-while sum = ',0
_CC_K_18  DB  'for sum = ',0
_CC_K_27  DB  'break sum = ',0
_CC_K_38  DB  'continue sum = ',0
_DATA   ENDS

END _main
