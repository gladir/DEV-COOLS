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


; Fonction : test_basic
_CC_F_test_basic:
        PUSH BP
        MOV BP,SP
        MOV AX,0
        MOV WORD PTR [BP-2],AX
; try block (nest=1)
        PUSH   WORD PTR [_CC_HANDLER]
        CALL   _CC_L_CATCH_1_SETUP
        JMP    _CC_L_CATCH_1_DISPATCH
_CC_L_CATCH_1_SETUP:
        PUSH   BP
        MOV    WORD PTR [_CC_HANDLER],SP
        POP    BP
        RET
        MOV AX,10
        MOV WORD PTR [BP-2],AX
        MOV AX,42
; throw expr
        MOV    WORD PTR [_CC_EXCVAL],AX
        MOV    WORD PTR [_CC_EXCCODE],4
        CMP    WORD PTR [_CC_HANDLER],0
        JE     _CC_RT_PANIC_EXC
        MOV    SP,WORD PTR [_CC_HANDLER]
        POP    BP
        RET
        MOV AX,99
        MOV WORD PTR [BP-2],AX
; try - no exception, restore handler
        POP    WORD PTR [_CC_HANDLER]
        JMP    _CC_L_TRYEND_1
_CC_L_CATCH_1_DISPATCH:
; catch dispatch
        POP    WORD PTR [_CC_HANDLER]
; catch(int)
        MOV    AX,WORD PTR [_CC_EXCCODE]
        CMP    AX,4
        JNE    _CC_L_CNEXT_1_1
; catch var e = _CC_EXCVAL
        MOV    AX,WORD PTR [_CC_EXCVAL]
        PUSH   AX
        XOR AX,AX
        MOV WORD PTR [BP-2],AX
        ADD    SP,2
        JMP    _CC_L_TRYEND_1
_CC_L_CNEXT_1_1:
        JMP    _CC_RT_PANIC_EXC
_CC_L_TRYEND_1:
; end try/catch
        MOV AX,WORD PTR [BP-2]
        JMP _CC_L_1
_CC_L_1:
        MOV SP,BP
        POP BP
        RET


; Fonction : test_catch_all
_CC_F_test_catch_all:
        PUSH BP
        MOV BP,SP
        MOV AX,0
        MOV WORD PTR [BP-2],AX
; try block (nest=1)
        PUSH   WORD PTR [_CC_HANDLER]
        CALL   _CC_L_CATCH_2_SETUP
        JMP    _CC_L_CATCH_2_DISPATCH
_CC_L_CATCH_2_SETUP:
        PUSH   BP
        MOV    WORD PTR [_CC_HANDLER],SP
        POP    BP
        RET
        MOV AX,7
; throw expr
        MOV    WORD PTR [_CC_EXCVAL],AX
        MOV    WORD PTR [_CC_EXCCODE],4
        CMP    WORD PTR [_CC_HANDLER],0
        JE     _CC_RT_PANIC_EXC
        MOV    SP,WORD PTR [_CC_HANDLER]
        POP    BP
        RET
; try - no exception, restore handler
        POP    WORD PTR [_CC_HANDLER]
        JMP    _CC_L_TRYEND_2
_CC_L_CATCH_2_DISPATCH:
; catch dispatch
        POP    WORD PTR [_CC_HANDLER]
; catch(...)
        MOV AX,1
        MOV WORD PTR [BP-2],AX
        JMP    _CC_L_TRYEND_2
        JMP    _CC_RT_PANIC_EXC
_CC_L_TRYEND_2:
; end try/catch
        MOV AX,WORD PTR [BP-2]
        JMP _CC_L_2
_CC_L_2:
        MOV SP,BP
        POP BP
        RET


; Fonction : test_multi_catch
_CC_F_test_multi_catch:
        PUSH BP
        MOV BP,SP
        MOV AX,0
        MOV WORD PTR [BP-2],AX
; try block (nest=1)
        PUSH   WORD PTR [_CC_HANDLER]
        CALL   _CC_L_CATCH_3_SETUP
        JMP    _CC_L_CATCH_3_DISPATCH
_CC_L_CATCH_3_SETUP:
        PUSH   BP
        MOV    WORD PTR [_CC_HANDLER],SP
        POP    BP
        RET
        MOV AX,4
; throw expr
        MOV    WORD PTR [_CC_EXCVAL],AX
        MOV    WORD PTR [_CC_EXCCODE],4
        CMP    WORD PTR [_CC_HANDLER],0
        JE     _CC_RT_PANIC_EXC
        MOV    SP,WORD PTR [_CC_HANDLER]
        POP    BP
        RET
; try - no exception, restore handler
        POP    WORD PTR [_CC_HANDLER]
        JMP    _CC_L_TRYEND_3
_CC_L_CATCH_3_DISPATCH:
; catch dispatch
        POP    WORD PTR [_CC_HANDLER]
; catch(char)
        MOV    AX,WORD PTR [_CC_EXCCODE]
        CMP    AX,2
        JNE    _CC_L_CNEXT_3_1
; catch var c = _CC_EXCVAL
        MOV    AX,WORD PTR [_CC_EXCVAL]
        PUSH   AX
        MOV AX,1
        MOV WORD PTR [BP-2],AX
        ADD    SP,2
        JMP    _CC_L_TRYEND_3
_CC_L_CNEXT_3_1:
; catch(int)
        MOV    AX,WORD PTR [_CC_EXCCODE]
        CMP    AX,4
        JNE    _CC_L_CNEXT_3_2
; catch var e = _CC_EXCVAL
        MOV    AX,WORD PTR [_CC_EXCVAL]
        PUSH   AX
        MOV AX,2
        MOV WORD PTR [BP-2],AX
        ADD    SP,2
        JMP    _CC_L_TRYEND_3
_CC_L_CNEXT_3_2:
; catch(...)
        MOV AX,3
        MOV WORD PTR [BP-2],AX
        JMP    _CC_L_TRYEND_3
        JMP    _CC_RT_PANIC_EXC
_CC_L_TRYEND_3:
; end try/catch
        MOV AX,WORD PTR [BP-2]
        JMP _CC_L_3
_CC_L_3:
        MOV SP,BP
        POP BP
        RET


; Fonction : test_no_throw
_CC_F_test_no_throw:
        PUSH BP
        MOV BP,SP
        MOV AX,5
        MOV WORD PTR [BP-2],AX
; try block (nest=1)
        PUSH   WORD PTR [_CC_HANDLER]
        CALL   _CC_L_CATCH_4_SETUP
        JMP    _CC_L_CATCH_4_DISPATCH
_CC_L_CATCH_4_SETUP:
        PUSH   BP
        MOV    WORD PTR [_CC_HANDLER],SP
        POP    BP
        RET
        MOV AX,WORD PTR [BP-2]
        PUSH   AX
        MOV AX,10
        MOV BX,AX
        POP    AX
        ADD AX,BX
        MOV WORD PTR [BP-2],AX
; try - no exception, restore handler
        POP    WORD PTR [_CC_HANDLER]
        JMP    _CC_L_TRYEND_4
_CC_L_CATCH_4_DISPATCH:
; catch dispatch
        POP    WORD PTR [_CC_HANDLER]
; catch(int)
        MOV    AX,WORD PTR [_CC_EXCCODE]
        CMP    AX,4
        JNE    _CC_L_CNEXT_4_1
; catch var e = _CC_EXCVAL
        MOV    AX,WORD PTR [_CC_EXCVAL]
        PUSH   AX
        MOV AX,0
        MOV WORD PTR [BP-2],AX
        ADD    SP,2
        JMP    _CC_L_TRYEND_4
_CC_L_CNEXT_4_1:
        JMP    _CC_RT_PANIC_EXC
_CC_L_TRYEND_4:
; end try/catch
        MOV AX,WORD PTR [BP-2]
        JMP _CC_L_4
_CC_L_4:
        MOV SP,BP
        POP BP
        RET


; Fonction : do_throw
_CC_F_do_throw:
        PUSH BP
        MOV BP,SP
        MOV AX,99
; throw expr
        MOV    WORD PTR [_CC_EXCVAL],AX
        MOV    WORD PTR [_CC_EXCCODE],4
        CMP    WORD PTR [_CC_HANDLER],0
        JE     _CC_RT_PANIC_EXC
        MOV    SP,WORD PTR [_CC_HANDLER]
        POP    BP
        RET
_CC_L_5:
        MOV SP,BP
        POP BP
        RET


; Fonction : test_throw_in_func
_CC_F_test_throw_in_func:
        PUSH BP
        MOV BP,SP
        MOV AX,0
        MOV WORD PTR [BP-2],AX
; try block (nest=1)
        PUSH   WORD PTR [_CC_HANDLER]
        CALL   _CC_L_CATCH_5_SETUP
        JMP    _CC_L_CATCH_5_DISPATCH
_CC_L_CATCH_5_SETUP:
        PUSH   BP
        MOV    WORD PTR [_CC_HANDLER],SP
        POP    BP
        RET
        CALL _CC_F_do_throw
; try - no exception, restore handler
        POP    WORD PTR [_CC_HANDLER]
        JMP    _CC_L_TRYEND_5
_CC_L_CATCH_5_DISPATCH:
; catch dispatch
        POP    WORD PTR [_CC_HANDLER]
; catch(int)
        MOV    AX,WORD PTR [_CC_EXCCODE]
        CMP    AX,4
        JNE    _CC_L_CNEXT_5_1
; catch var e = _CC_EXCVAL
        MOV    AX,WORD PTR [_CC_EXCVAL]
        PUSH   AX
        XOR AX,AX
        MOV WORD PTR [BP-2],AX
        ADD    SP,2
        JMP    _CC_L_TRYEND_5
_CC_L_CNEXT_5_1:
        JMP    _CC_RT_PANIC_EXC
_CC_L_TRYEND_5:
; end try/catch
        MOV AX,WORD PTR [BP-2]
        JMP _CC_L_6
_CC_L_6:
        MOV SP,BP
        POP BP
        RET


; Fonction : main
PUBLIC _main
_main:
        PUSH BP
        MOV BP,SP
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_8
        MOV BX,1
        CALL _CC_RT_WRITESTR
; cout/cerr << ...
        CALL _CC_F_test_basic
        MOV BX,1
        CALL _CC_RT_WRITENUM
; cout/cerr << ...
        MOV BX,1
        CALL _CC_RT_WRITECRLF
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_9
        MOV BX,1
        CALL _CC_RT_WRITESTR
; cout/cerr << ...
        CALL _CC_F_test_catch_all
        MOV BX,1
        CALL _CC_RT_WRITENUM
; cout/cerr << ...
        MOV BX,1
        CALL _CC_RT_WRITECRLF
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_10
        MOV BX,1
        CALL _CC_RT_WRITESTR
; cout/cerr << ...
        CALL _CC_F_test_multi_catch
        MOV BX,1
        CALL _CC_RT_WRITENUM
; cout/cerr << ...
        MOV BX,1
        CALL _CC_RT_WRITECRLF
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_11
        MOV BX,1
        CALL _CC_RT_WRITESTR
; cout/cerr << ...
        CALL _CC_F_test_no_throw
        MOV BX,1
        CALL _CC_RT_WRITENUM
; cout/cerr << ...
        MOV BX,1
        CALL _CC_RT_WRITECRLF
; cout/cerr << ...
        MOV DX,OFFSET _CC_K_12
        MOV BX,1
        CALL _CC_RT_WRITESTR
; cout/cerr << ...
        CALL _CC_F_test_throw_in_func
        MOV BX,1
        CALL _CC_RT_WRITENUM
; cout/cerr << ...
        MOV BX,1
        CALL _CC_RT_WRITECRLF
        MOV AX,0
        JMP _CC_L_7
_CC_L_7:
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
_CC_K_8  DB  'test_basic: ',0
_CC_K_9  DB  'test_catch_all: ',0
_CC_K_10  DB  'test_multi_catch: ',0
_CC_K_11  DB  'test_no_throw: ',0
_CC_K_12  DB  'test_throw_in_func: ',0
_DATA   ENDS

END _main
