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
        MOV AX,5
        MOV WORD PTR [BP-2],AX
; if
        MOV AX,WORD PTR [BP-2]
        PUSH   AX
        MOV AX,3
        MOV BX,AX
        POP    AX
        CMP AX,BX
        JG _CC_L_2
        XOR AX,AX
        JMP _CC_L_3
_CC_L_2:
        MOV AX,1
_CC_L_3:
        TEST AX,AX
        JZ _CC_L_4
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_6
        MOV BX,1
        CALL _CC_RT_WRITESTR
        MOV BX,1
        CALL _CC_RT_WRITECRLF
_CC_L_4:
        MOV AX,2
        MOV WORD PTR [BP-4],AX
; if
        MOV AX,WORD PTR [BP-4]
        PUSH   AX
        MOV AX,10
        MOV BX,AX
        POP    AX
        CMP AX,BX
        JG _CC_L_7
        XOR AX,AX
        JMP _CC_L_8
_CC_L_7:
        MOV AX,1
_CC_L_8:
        TEST AX,AX
        JZ _CC_L_9
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_11
        MOV BX,1
        CALL _CC_RT_WRITESTR
        MOV BX,1
        CALL _CC_RT_WRITECRLF
        JMP _CC_L_10
_CC_L_9:
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_12
        MOV BX,1
        CALL _CC_RT_WRITESTR
        MOV BX,1
        CALL _CC_RT_WRITECRLF
_CC_L_10:
        MOV AX,42
        MOV WORD PTR [BP-6],AX
; if
        MOV AX,WORD PTR [BP-6]
        PUSH   AX
        MOV AX,100
        MOV BX,AX
        POP    AX
        CMP AX,BX
        JG _CC_L_13
        XOR AX,AX
        JMP _CC_L_14
_CC_L_13:
        MOV AX,1
_CC_L_14:
        TEST AX,AX
        JZ _CC_L_15
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_17
        MOV BX,1
        CALL _CC_RT_WRITESTR
        MOV BX,1
        CALL _CC_RT_WRITECRLF
        JMP _CC_L_16
_CC_L_15:
; if
        MOV AX,WORD PTR [BP-6]
        PUSH   AX
        MOV AX,50
        MOV BX,AX
        POP    AX
        CMP AX,BX
        JG _CC_L_18
        XOR AX,AX
        JMP _CC_L_19
_CC_L_18:
        MOV AX,1
_CC_L_19:
        TEST AX,AX
        JZ _CC_L_20
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_11
        MOV BX,1
        CALL _CC_RT_WRITESTR
        MOV BX,1
        CALL _CC_RT_WRITECRLF
        JMP _CC_L_21
_CC_L_20:
; if
        MOV AX,WORD PTR [BP-6]
        PUSH   AX
        MOV AX,10
        MOV BX,AX
        POP    AX
        CMP AX,BX
        JG _CC_L_22
        XOR AX,AX
        JMP _CC_L_23
_CC_L_22:
        MOV AX,1
_CC_L_23:
        TEST AX,AX
        JZ _CC_L_24
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_26
        MOV BX,1
        CALL _CC_RT_WRITESTR
        MOV BX,1
        CALL _CC_RT_WRITECRLF
        JMP _CC_L_25
_CC_L_24:
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_12
        MOV BX,1
        CALL _CC_RT_WRITESTR
        MOV BX,1
        CALL _CC_RT_WRITECRLF
_CC_L_25:
_CC_L_21:
_CC_L_16:
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
        JE _CC_L_27
        XOR AX,AX
        JMP _CC_L_28
_CC_L_27:
        MOV AX,1
_CC_L_28:
        TEST AX,AX
        JZ _CC_L_29
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_31
        MOV BX,1
        CALL _CC_RT_WRITESTR
        MOV BX,1
        CALL _CC_RT_WRITECRLF
_CC_L_29:
        MOV AX,3
        MOV WORD PTR [BP-12],AX
; switch
        MOV AX,WORD PTR [BP-12]
        PUSH AX
        MOV AX,WORD PTR [SP]
        CMP AX,1
        JNE _CC_L_33
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_34
        MOV BX,1
        CALL _CC_RT_WRITESTR
        MOV BX,1
        CALL _CC_RT_WRITECRLF
; break
        JMP _CC_L_32
_CC_L_33:
        MOV AX,WORD PTR [SP]
        CMP AX,2
        JNE _CC_L_35
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_36
        MOV BX,1
        CALL _CC_RT_WRITESTR
        MOV BX,1
        CALL _CC_RT_WRITECRLF
; break
        JMP _CC_L_32
_CC_L_35:
        MOV AX,WORD PTR [SP]
        CMP AX,3
        JNE _CC_L_37
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_38
        MOV BX,1
        CALL _CC_RT_WRITESTR
        MOV BX,1
        CALL _CC_RT_WRITECRLF
; break
        JMP _CC_L_32
_CC_L_37:
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_39
        MOV BX,1
        CALL _CC_RT_WRITESTR
        MOV BX,1
        CALL _CC_RT_WRITECRLF
; break
        JMP _CC_L_32
_CC_L_32:
        ADD SP,2
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
_CC_K_6  DB  'x > 3',0
_CC_K_11  DB  'grand',0
_CC_K_12  DB  'petit',0
_CC_K_17  DB  'tres grand',0
_CC_K_26  DB  'moyen',0
_CC_K_31  DB  'egal',0
_CC_K_34  DB  'lundi',0
_CC_K_36  DB  'mardi',0
_CC_K_38  DB  'mercredi',0
_CC_K_39  DB  'autre',0
_DATA   ENDS

END _main
