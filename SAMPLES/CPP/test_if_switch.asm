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

        MOV AX,5
        MOV WORD PTR [BP-2],AX
; if
        MOV AX,WORD PTR [BP-2]
        PUSH   AX
        MOV AX,3
        MOV BX,AX
        POP    AX
        CMP AX,BX
        JG _CC_L_1
        XOR AX,AX
        JMP _CC_L_2
_CC_L_1:
        MOV AX,1
_CC_L_2:
        TEST AX,AX
        JZ _CC_L_3
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_5
        MOV BX,1
        CALL _CC_RT_WRITESTR
        MOV BX,1
        CALL _CC_RT_WRITECRLF
_CC_L_3:
        MOV AX,2
        MOV WORD PTR [BP-4],AX
; if
        MOV AX,WORD PTR [BP-4]
        PUSH   AX
        MOV AX,10
        MOV BX,AX
        POP    AX
        CMP AX,BX
        JG _CC_L_6
        XOR AX,AX
        JMP _CC_L_7
_CC_L_6:
        MOV AX,1
_CC_L_7:
        TEST AX,AX
        JZ _CC_L_8
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_10
        MOV BX,1
        CALL _CC_RT_WRITESTR
        MOV BX,1
        CALL _CC_RT_WRITECRLF
        JMP _CC_L_9
_CC_L_8:
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_11
        MOV BX,1
        CALL _CC_RT_WRITESTR
        MOV BX,1
        CALL _CC_RT_WRITECRLF
_CC_L_9:
        MOV AX,42
        MOV WORD PTR [BP-6],AX
; if
        MOV AX,WORD PTR [BP-6]
        PUSH   AX
        MOV AX,100
        MOV BX,AX
        POP    AX
        CMP AX,BX
        JG _CC_L_12
        XOR AX,AX
        JMP _CC_L_13
_CC_L_12:
        MOV AX,1
_CC_L_13:
        TEST AX,AX
        JZ _CC_L_14
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_16
        MOV BX,1
        CALL _CC_RT_WRITESTR
        MOV BX,1
        CALL _CC_RT_WRITECRLF
        JMP _CC_L_15
_CC_L_14:
; if
        MOV AX,WORD PTR [BP-6]
        PUSH   AX
        MOV AX,50
        MOV BX,AX
        POP    AX
        CMP AX,BX
        JG _CC_L_17
        XOR AX,AX
        JMP _CC_L_18
_CC_L_17:
        MOV AX,1
_CC_L_18:
        TEST AX,AX
        JZ _CC_L_19
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_10
        MOV BX,1
        CALL _CC_RT_WRITESTR
        MOV BX,1
        CALL _CC_RT_WRITECRLF
        JMP _CC_L_20
_CC_L_19:
; if
        MOV AX,WORD PTR [BP-6]
        PUSH   AX
        MOV AX,10
        MOV BX,AX
        POP    AX
        CMP AX,BX
        JG _CC_L_21
        XOR AX,AX
        JMP _CC_L_22
_CC_L_21:
        MOV AX,1
_CC_L_22:
        TEST AX,AX
        JZ _CC_L_23
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_25
        MOV BX,1
        CALL _CC_RT_WRITESTR
        MOV BX,1
        CALL _CC_RT_WRITECRLF
        JMP _CC_L_24
_CC_L_23:
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_11
        MOV BX,1
        CALL _CC_RT_WRITESTR
        MOV BX,1
        CALL _CC_RT_WRITECRLF
_CC_L_24:
_CC_L_20:
_CC_L_15:
        MOV AX,3
        MOV WORD PTR [BP-8],AX
        MOV AX,3
        MOV WORD PTR [BP-10],AX
; if
        MOV AX,WORD PTR [BP-8]
        PUSH   AX
        MOV AX,WORD PTR [BP-10]
        MOV BX,AX
        POP    AX
        CMP AX,BX
        JE _CC_L_26
        XOR AX,AX
        JMP _CC_L_27
_CC_L_26:
        MOV AX,1
_CC_L_27:
        TEST AX,AX
        JZ _CC_L_28
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_30
        MOV BX,1
        CALL _CC_RT_WRITESTR
        MOV BX,1
        CALL _CC_RT_WRITECRLF
_CC_L_28:
        MOV AX,3
        MOV WORD PTR [BP-12],AX
; switch
        MOV AX,WORD PTR [BP-12]
        PUSH AX
        MOV AX,WORD PTR [SP]
        CMP AX,1
        JNE _CC_L_32
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_33
        MOV BX,1
        CALL _CC_RT_WRITESTR
        MOV BX,1
        CALL _CC_RT_WRITECRLF
; break
        JMP _CC_L_31
_CC_L_32:
        MOV AX,WORD PTR [SP]
        CMP AX,2
        JNE _CC_L_34
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_35
        MOV BX,1
        CALL _CC_RT_WRITESTR
        MOV BX,1
        CALL _CC_RT_WRITECRLF
; break
        JMP _CC_L_31
_CC_L_34:
        MOV AX,WORD PTR [SP]
        CMP AX,3
        JNE _CC_L_36
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_37
        MOV BX,1
        CALL _CC_RT_WRITESTR
        MOV BX,1
        CALL _CC_RT_WRITECRLF
; break
        JMP _CC_L_31
_CC_L_36:
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_38
        MOV BX,1
        CALL _CC_RT_WRITESTR
        MOV BX,1
        CALL _CC_RT_WRITECRLF
; break
        JMP _CC_L_31
_CC_L_31:
        ADD SP,2

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
_CC_K_5  DB  'x > 3',0
_CC_K_10  DB  'grand',0
_CC_K_11  DB  'petit',0
_CC_K_16  DB  'tres grand',0
_CC_K_25  DB  'moyen',0
_CC_K_30  DB  'egal',0
_CC_K_33  DB  'lundi',0
_CC_K_35  DB  'mardi',0
_CC_K_37  DB  'mercredi',0
_CC_K_38  DB  'autre',0
_DATA   ENDS

END _main
