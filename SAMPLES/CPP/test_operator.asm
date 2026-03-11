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


; Methode : Vector2D::Vector2D
_CC_C_Vector2D_CTOR:
        PUSH BP
        MOV BP,SP
; Initialiser les champs de l'objet a 0
        MOV DI,WORD PTR [BP+4]
        MOV CX,0
        XOR AX,AX
        REP    STOSW
        MOV BX,WORD PTR [BP+4]
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV AX,0
        MOV BX,WORD PTR [_CC_RT_ATMP]
        MOV WORD PTR [BX],AX
        MOV BX,WORD PTR [BP+4]
        ADD BX,2
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV AX,0
        MOV BX,WORD PTR [_CC_RT_ATMP]
        MOV WORD PTR [BX],AX
_CC_L_1:
        MOV SP,BP
        POP BP
        RET


; Methode : Vector2D::operator+
_CC_C_Vector2D_OP_PLUS:
        PUSH BP
        MOV BP,SP
        MOV BX,WORD PTR [BP+4]
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV AX,WORD PTR [BP+6]
        PUSH   AX
        MOV BX,AX
        POP    AX
        ADD AX,BX
        MOV BX,WORD PTR [BP+4]
        ADD BX,2
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        PUSH   AX
        MOV BX,AX
        POP    AX
        ADD AX,BX
        MOV AX,WORD PTR [BP+6]
        PUSH   AX
        MOV BX,AX
        POP    AX
        ADD AX,BX
        JMP _CC_L_2
_CC_L_2:
        MOV SP,BP
        POP BP
        RET


; Methode : Vector2D::operator-
_CC_C_Vector2D_OP_MINUS:
        PUSH BP
        MOV BP,SP
        MOV BX,WORD PTR [BP+4]
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV AX,WORD PTR [BP+6]
        PUSH   AX
        MOV BX,AX
        POP    AX
        SUB AX,BX
        MOV BX,WORD PTR [BP+4]
        ADD BX,2
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        PUSH   AX
        MOV BX,AX
        POP    AX
        ADD AX,BX
        MOV AX,WORD PTR [BP+6]
        PUSH   AX
        MOV BX,AX
        POP    AX
        SUB AX,BX
        JMP _CC_L_3
_CC_L_3:
        MOV SP,BP
        POP BP
        RET


; Methode : Vector2D::operator==
_CC_C_Vector2D_OP_EQ:
        PUSH BP
        MOV BP,SP
; if
        MOV BX,WORD PTR [BP+4]
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV AX,WORD PTR [BP+6]
        PUSH   AX
        MOV BX,AX
        POP    AX
        CMP AX,BX
        JE _CC_L_5
        XOR AX,AX
        JMP _CC_L_6
_CC_L_5:
        MOV AX,1
_CC_L_6:
        TEST AX,AX
        JZ _CC_L_7
; if
        MOV BX,WORD PTR [BP+4]
        ADD BX,2
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV AX,WORD PTR [BP+6]
        PUSH   AX
        MOV BX,AX
        POP    AX
        CMP AX,BX
        JE _CC_L_9
        XOR AX,AX
        JMP _CC_L_10
_CC_L_9:
        MOV AX,1
_CC_L_10:
        TEST AX,AX
        JZ _CC_L_11
        MOV AX,1
        JMP _CC_L_4
_CC_L_11:
_CC_L_7:
        MOV AX,0
        JMP _CC_L_4
_CC_L_4:
        MOV SP,BP
        POP BP
        RET


; Methode : Vector2D::operator!=
_CC_C_Vector2D_OP_NEQ:
        PUSH BP
        MOV BP,SP
; if
        MOV BX,WORD PTR [BP+4]
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV AX,WORD PTR [BP+6]
        PUSH   AX
        MOV BX,AX
        POP    AX
        CMP AX,BX
        JNE _CC_L_14
        XOR AX,AX
        JMP _CC_L_15
_CC_L_14:
        MOV AX,1
_CC_L_15:
        TEST AX,AX
        JZ _CC_L_16
        MOV AX,1
        JMP _CC_L_13
_CC_L_16:
; if
        MOV BX,WORD PTR [BP+4]
        ADD BX,2
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV AX,WORD PTR [BP+6]
        PUSH   AX
        MOV BX,AX
        POP    AX
        CMP AX,BX
        JNE _CC_L_18
        XOR AX,AX
        JMP _CC_L_19
_CC_L_18:
        MOV AX,1
_CC_L_19:
        TEST AX,AX
        JZ _CC_L_20
        MOV AX,1
        JMP _CC_L_13
_CC_L_20:
        MOV AX,0
        JMP _CC_L_13
_CC_L_13:
        MOV SP,BP
        POP BP
        RET


; Methode : Counter::Counter
_CC_C_Counter_CTOR:
        PUSH BP
        MOV BP,SP
; Initialiser les champs de l'objet a 0
        MOV DI,WORD PTR [BP+4]
        MOV CX,0
        XOR AX,AX
        REP    STOSW
        MOV BX,WORD PTR [BP+4]
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV AX,0
        MOV BX,WORD PTR [_CC_RT_ATMP]
        MOV WORD PTR [BX],AX
_CC_L_22:
        MOV SP,BP
        POP BP
        RET


; Methode : Counter::operator+
_CC_C_Counter_OP_PLUS:
        PUSH BP
        MOV BP,SP
        MOV BX,WORD PTR [BP+4]
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        PUSH   AX
        MOV AX,WORD PTR [BP+6]
        MOV BX,AX
        POP    AX
        ADD AX,BX
        JMP _CC_L_23
_CC_L_23:
        MOV SP,BP
        POP BP
        RET


; Methode : Counter::operator*
_CC_C_Counter_OP_MUL:
        PUSH BP
        MOV BP,SP
        MOV BX,WORD PTR [BP+4]
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        PUSH   AX
        MOV AX,WORD PTR [BP+6]
        MOV BX,AX
        POP    AX
        IMUL BX
        JMP _CC_L_24
_CC_L_24:
        MOV SP,BP
        POP BP
        RET


; Fonction : main
PUBLIC _main
_main:
        PUSH BP
        MOV BP,SP
; Appel constructeur Vector2D
        LEA AX,[BP-4]
        PUSH AX
        CALL _CC_C_Vector2D_CTOR
        ADD SP,2
        LEA BX,[BP-4]
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV AX,3
        MOV BX,WORD PTR [_CC_RT_ATMP]
        MOV WORD PTR [BX],AX
        LEA BX,[BP-4]
        ADD BX,2
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV AX,4
        MOV BX,WORD PTR [_CC_RT_ATMP]
        MOV WORD PTR [BX],AX
; Appel constructeur Vector2D
        LEA AX,[BP-8]
        PUSH AX
        CALL _CC_C_Vector2D_CTOR
        ADD SP,2
        LEA BX,[BP-8]
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV AX,1
        MOV BX,WORD PTR [_CC_RT_ATMP]
        MOV WORD PTR [BX],AX
        LEA BX,[BP-8]
        ADD BX,2
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV AX,2
        MOV BX,WORD PTR [_CC_RT_ATMP]
        MOV WORD PTR [BX],AX
; cout/cerr << ...
; operator+ surcharge
        MOV AX,WORD PTR [BP-8]
        PUSH AX
        LEA AX,[BP-4]
        PUSH AX
        CALL _CC_C_Vector2D_OP_PLUS
        ADD SP,4
        MOV BX,1
        CALL _CC_RT_WRITENUM
        MOV BX,1
        CALL _CC_RT_WRITECRLF
; cout/cerr << ...
; operator- surcharge
        MOV AX,WORD PTR [BP-8]
        PUSH AX
        LEA AX,[BP-4]
        PUSH AX
        CALL _CC_C_Vector2D_OP_MINUS
        ADD SP,4
        MOV BX,1
        CALL _CC_RT_WRITENUM
        MOV BX,1
        CALL _CC_RT_WRITECRLF
; Appel constructeur Vector2D
        LEA AX,[BP-12]
        PUSH AX
        CALL _CC_C_Vector2D_CTOR
        ADD SP,2
        LEA BX,[BP-12]
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV AX,3
        MOV BX,WORD PTR [_CC_RT_ATMP]
        MOV WORD PTR [BX],AX
        LEA BX,[BP-12]
        ADD BX,2
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV AX,4
        MOV BX,WORD PTR [_CC_RT_ATMP]
        MOV WORD PTR [BX],AX
; operator== surcharge
        MOV AX,WORD PTR [BP-12]
        PUSH AX
        LEA AX,[BP-4]
        PUSH AX
        CALL _CC_C_Vector2D_OP_EQ
        ADD SP,4
        MOV WORD PTR [BP-14],AX
; cout/cerr << ...
        MOV AX,WORD PTR [BP-14]
        MOV BX,1
        CALL _CC_RT_WRITENUM
        MOV BX,1
        CALL _CC_RT_WRITECRLF
; operator!= surcharge
        MOV AX,WORD PTR [BP-8]
        PUSH AX
        LEA AX,[BP-4]
        PUSH AX
        CALL _CC_C_Vector2D_OP_NEQ
        ADD SP,4
        MOV WORD PTR [BP-16],AX
; cout/cerr << ...
        MOV AX,WORD PTR [BP-16]
        MOV BX,1
        CALL _CC_RT_WRITENUM
        MOV BX,1
        CALL _CC_RT_WRITECRLF
; Appel constructeur Counter
        LEA AX,[BP-18]
        PUSH AX
        CALL _CC_C_Counter_CTOR
        ADD SP,2
        LEA BX,[BP-18]
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV AX,10
        MOV BX,WORD PTR [_CC_RT_ATMP]
        MOV WORD PTR [BX],AX
; cout/cerr << ...
; operator+ surcharge
        MOV AX,5
        PUSH AX
        LEA AX,[BP-18]
        PUSH AX
        CALL _CC_C_Counter_OP_PLUS
        ADD SP,4
        MOV BX,1
        CALL _CC_RT_WRITENUM
        MOV BX,1
        CALL _CC_RT_WRITECRLF
; cout/cerr << ...
; operator* surcharge
        MOV AX,3
        PUSH AX
        LEA AX,[BP-18]
        PUSH AX
        CALL _CC_C_Counter_OP_MUL
        ADD SP,4
        MOV BX,1
        CALL _CC_RT_WRITENUM
        MOV BX,1
        CALL _CC_RT_WRITECRLF
        MOV AX,0
        JMP _CC_L_25
_CC_L_25:
        MOV SP,BP
        POP BP
        RET


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
_CC_RT_ATMP     DW  0
_DATA   ENDS

END _main
