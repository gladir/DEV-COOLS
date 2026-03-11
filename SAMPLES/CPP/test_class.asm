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
_CC_L_1:
        MOV SP,BP
        POP BP
        RET


; Methode : Counter::increment
_CC_C_Counter_increment:
        PUSH BP
        MOV BP,SP
        MOV BX,WORD PTR [BP+4]
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV BX,WORD PTR [BP+4]
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        PUSH   AX
        MOV AX,1
        MOV BX,AX
        POP    AX
        ADD AX,BX
        MOV BX,WORD PTR [_CC_RT_ATMP]
        MOV WORD PTR [BX],AX
_CC_L_2:
        MOV SP,BP
        POP BP
        RET


; Methode : Counter::get
_CC_C_Counter_get:
        PUSH BP
        MOV BP,SP
        MOV BX,WORD PTR [BP+4]
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        JMP _CC_L_3
_CC_L_3:
        MOV SP,BP
        POP BP
        RET


; Methode : Point::Point
_CC_C_Point_CTOR:
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
_CC_L_4:
        MOV SP,BP
        POP BP
        RET


; Methode : Point::set
_CC_C_Point_set:
        PUSH BP
        MOV BP,SP
        MOV BX,WORD PTR [BP+4]
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV AX,WORD PTR [BP+6]
        MOV BX,WORD PTR [_CC_RT_ATMP]
        MOV WORD PTR [BX],AX
        MOV BX,WORD PTR [BP+4]
        ADD BX,2
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV AX,WORD PTR [BP+8]
        MOV BX,WORD PTR [_CC_RT_ATMP]
        MOV WORD PTR [BX],AX
_CC_L_5:
        MOV SP,BP
        POP BP
        RET


; Methode : Point::getX
_CC_C_Point_getX:
        PUSH BP
        MOV BP,SP
        MOV BX,WORD PTR [BP+4]
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        JMP _CC_L_6
_CC_L_6:
        MOV SP,BP
        POP BP
        RET


; Methode : Point::getY
_CC_C_Point_getY:
        PUSH BP
        MOV BP,SP
        MOV BX,WORD PTR [BP+4]
        ADD BX,2
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        JMP _CC_L_7
_CC_L_7:
        MOV SP,BP
        POP BP
        RET


; Methode : Box::Box
_CC_C_Box_CTOR:
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
        MOV AX,10
        MOV BX,WORD PTR [_CC_RT_ATMP]
        MOV WORD PTR [BX],AX
        MOV BX,WORD PTR [BP+4]
        ADD BX,2
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV AX,20
        MOV BX,WORD PTR [_CC_RT_ATMP]
        MOV WORD PTR [BX],AX
_CC_L_8:
        MOV SP,BP
        POP BP
        RET


; Methode : Box::area
_CC_C_Box_area:
        PUSH BP
        MOV BP,SP
        MOV BX,WORD PTR [BP+4]
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV BX,WORD PTR [BP+4]
        ADD BX,2
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        PUSH   AX
        MOV BX,AX
        POP    AX
        IMUL BX
        JMP _CC_L_9
_CC_L_9:
        MOV SP,BP
        POP BP
        RET


; Fonction : main
PUBLIC _main
_main:
        PUSH BP
        MOV BP,SP
; Appel constructeur Counter
        LEA AX,[BP-2]
        PUSH AX
        CALL _CC_C_Counter_CTOR
        ADD SP,2
        LEA AX,[BP-2]
        PUSH AX
        CALL _CC_C_Counter_increment
        ADD SP,2
        LEA AX,[BP-2]
        PUSH AX
        CALL _CC_C_Counter_increment
        ADD SP,2
        LEA AX,[BP-2]
        PUSH AX
        CALL _CC_C_Counter_increment
        ADD SP,2
; cout/cerr << ...
        LEA AX,[BP-2]
        PUSH AX
        CALL _CC_C_Counter_get
        ADD SP,2
        MOV BX,1
        CALL _CC_RT_WRITENUM
        MOV BX,1
        CALL _CC_RT_WRITECRLF
; Appel constructeur Point
        LEA AX,[BP-6]
        PUSH AX
        CALL _CC_C_Point_CTOR
        ADD SP,2
        LEA AX,[BP-6]
        PUSH AX
        MOV AX,5
        PUSH AX
        MOV AX,10
        PUSH AX
        CALL _CC_C_Point_set
        ADD SP,2
; cout/cerr << ...
        LEA AX,[BP-6]
        PUSH AX
        CALL _CC_C_Point_getX
        ADD SP,2
        MOV BX,1
        CALL _CC_RT_WRITENUM
        MOV BX,1
        CALL _CC_RT_WRITECRLF
; cout/cerr << ...
        LEA AX,[BP-6]
        PUSH AX
        CALL _CC_C_Point_getY
        ADD SP,2
        MOV BX,1
        CALL _CC_RT_WRITENUM
        MOV BX,1
        CALL _CC_RT_WRITECRLF
; Appel constructeur Box
        LEA AX,[BP-10]
        PUSH AX
        CALL _CC_C_Box_CTOR
        ADD SP,2
; cout/cerr << ...
        LEA BX,[BP-10]
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV BX,1
        CALL _CC_RT_WRITENUM
        MOV BX,1
        CALL _CC_RT_WRITECRLF
; cout/cerr << ...
        LEA BX,[BP-10]
        ADD BX,2
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV BX,1
        CALL _CC_RT_WRITENUM
        MOV BX,1
        CALL _CC_RT_WRITECRLF
        MOV AX,4
        CALL _CC_RT_NEW
; Appel constructeur apres new
        PUSH AX
        PUSH AX
        CALL _CC_C_Box_CTOR
        ADD SP,2
        POP AX
        MOV WORD PTR [BP-12],AX
; cout/cerr << ...
        MOV AX,WORD PTR [BP-12]
        MOV BX,AX
        MOV AX,[BX]
        MOV BX,1
        CALL _CC_RT_WRITENUM
        MOV BX,1
        CALL _CC_RT_WRITECRLF
        MOV AX,WORD PTR [BP-12]
        CALL _CC_RT_DELETE
        MOV AX,0
        JMP _CC_L_10
_CC_L_10:
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


; === Exception Runtime (TODO 23) ===

_CC_RT_PANIC_EXC:
        MOV    DX,OFFSET _CC_EXCMSG
        MOV    AH,09h
        INT    21h
        MOV    AX,4C01h
        INT    21h


_TEXT   ENDS

_DATA   SEGMENT WORD PUBLIC 'DATA'
_CC_TRUE_S   DB  'true',0
_CC_FALSE_S  DB  'false',0
_CC_NULL_S   DB  '(null)',0
_CC_STRBUF   DB  256 DUP(0)
_CC_RT_CRLF     DB  13,10
_CC_RT_NUMBUF   DB  8 DUP(0)
_CC_RT_INBUF    DB  80,0,80 DUP(0)
_CC_HANDLER  DW  0
_CC_EXCCODE  DW  0
_CC_EXCMSG   DB  'Unhandled exception',13,10,'$'
_CC_RT_ATMP     DW  0
_DATA   ENDS

END _main
