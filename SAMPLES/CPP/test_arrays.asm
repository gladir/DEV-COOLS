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


; Fonction : main
PUBLIC _main
_main:
        PUSH BP
        MOV BP,SP
        LEA AX,[BP-10]
        PUSH   AX
        MOV AX,0
        SHL    AX,1
        POP    BX
        ADD BX,AX
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV AX,10
        MOV BX,WORD PTR [_CC_RT_ATMP]
        MOV WORD PTR [BX],AX
        LEA AX,[BP-10]
        PUSH   AX
        MOV AX,1
        SHL    AX,1
        POP    BX
        ADD BX,AX
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV AX,20
        MOV BX,WORD PTR [_CC_RT_ATMP]
        MOV WORD PTR [BX],AX
        LEA AX,[BP-10]
        PUSH   AX
        MOV AX,2
        SHL    AX,1
        POP    BX
        ADD BX,AX
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV AX,30
        MOV BX,WORD PTR [_CC_RT_ATMP]
        MOV WORD PTR [BX],AX
        LEA AX,[BP-10]
        PUSH   AX
        MOV AX,3
        SHL    AX,1
        POP    BX
        ADD BX,AX
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV AX,40
        MOV BX,WORD PTR [_CC_RT_ATMP]
        MOV WORD PTR [BX],AX
        LEA AX,[BP-10]
        PUSH   AX
        MOV AX,4
        SHL    AX,1
        POP    BX
        ADD BX,AX
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV AX,50
        MOV BX,WORD PTR [_CC_RT_ATMP]
        MOV WORD PTR [BX],AX
        LEA AX,[BP-10]
        PUSH   AX
        MOV AX,2
        SHL    AX,1
        POP    BX
        ADD BX,AX
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV WORD PTR [BP-12],AX
; cout/cerr << ...
        MOV AX,WORD PTR [BP-12]
        MOV BX,1
        CALL _CC_RT_WRITENUM
        MOV BX,1
        CALL _CC_RT_WRITECRLF
        MOV WORD PTR [BP-18],100
        MOV WORD PTR [BP-16],200
        MOV WORD PTR [BP-14],300
; cout/cerr << ...
        LEA AX,[BP-18]
        PUSH   AX
        MOV AX,0
        SHL    AX,1
        POP    BX
        ADD BX,AX
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV BX,1
        CALL _CC_RT_WRITENUM
        MOV BX,1
        CALL _CC_RT_WRITECRLF
; cout/cerr << ...
        LEA AX,[BP-18]
        PUSH   AX
        MOV AX,1
        SHL    AX,1
        POP    BX
        ADD BX,AX
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV BX,1
        CALL _CC_RT_WRITENUM
        MOV BX,1
        CALL _CC_RT_WRITECRLF
; cout/cerr << ...
        LEA AX,[BP-18]
        PUSH   AX
        MOV AX,2
        SHL    AX,1
        POP    BX
        ADD BX,AX
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV BX,1
        CALL _CC_RT_WRITENUM
        MOV BX,1
        CALL _CC_RT_WRITECRLF
        MOV WORD PTR [BP-24],7
        MOV WORD PTR [BP-22],8
        MOV WORD PTR [BP-20],9
; cout/cerr << ...
        LEA AX,[BP-24]
        PUSH   AX
        MOV AX,0
        SHL    AX,1
        POP    BX
        ADD BX,AX
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV BX,1
        CALL _CC_RT_WRITENUM
        MOV BX,1
        CALL _CC_RT_WRITECRLF
        MOV AX,0
        MOV WORD PTR [BP-26],AX
        MOV AX,0
        MOV WORD PTR [BP-28],AX
; while
_CC_L_2:
        MOV AX,WORD PTR [BP-28]
        PUSH   AX
        MOV AX,5
        MOV BX,AX
        POP    AX
        CMP AX,BX
        JL _CC_L_4
        XOR AX,AX
        JMP _CC_L_5
_CC_L_4:
        MOV AX,1
_CC_L_5:
        TEST AX,AX
        JZ _CC_L_3
        LEA AX,[BP-10]
        PUSH   AX
        MOV AX,WORD PTR [BP-28]
        SHL    AX,1
        POP    BX
        ADD BX,AX
        MOV WORD PTR [_CC_RT_ATMP],BX
        MOV AX,WORD PTR [BX]
        MOV AX,WORD PTR [BP-26]
        PUSH   AX
        MOV BX,AX
        POP    AX
        ADD AX,BX
        MOV BX,WORD PTR [_CC_RT_ATMP]
        MOV WORD PTR [BX],AX
        MOV AX,WORD PTR [BP-28]
        PUSH   AX
        INC    AX
        MOV WORD PTR [BP-28],AX
        POP    AX
        JMP _CC_L_2
_CC_L_3:
; cout/cerr << ...
        MOV AX,WORD PTR [BP-26]
        MOV BX,1
        CALL _CC_RT_WRITENUM
        MOV BX,1
        CALL _CC_RT_WRITECRLF
        LEA AX,[BP-10]
        MOV WORD PTR [BP-30],AX
; cout/cerr << ...
        MOV AX,WORD PTR [BP-30]
        MOV BX,AX
        MOV AX,[BX]
        MOV BX,1
        CALL _CC_RT_WRITENUM
        MOV BX,1
        CALL _CC_RT_WRITECRLF
        MOV AX,0
        JMP _CC_L_1
_CC_L_1:
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
_CC_EXCVAL   DW  0
_CC_EXCMSG   DB  'Unhandled exception',13,10,'$'
_CC_RT_ATMP     DW  0
_DATA   ENDS

END _main
