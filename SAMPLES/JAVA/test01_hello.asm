; ----- Segment DATA -----
_DATA           SEGMENT WORD PUBLIC 'DATA'

; ----- Litteraux de chaines -----
_JS_1                   DB      'Hello, World!',0

; ----- Variables systeme JAVAC86 -----
_J_OUTBUF               DB      256 DUP(0)
_J_INBUF                DB      128 DUP(0)
_J_INTBUF               DB      12 DUP(0)
_J_CRLF                 DB      0Dh, 0Ah, '$'
_J_NULLSTR              DB      0


_DATA           ENDS

; ----- Segment CODE -----
_CODE           SEGMENT WORD PUBLIC 'CODE'

; --- Point d'entree programme ---
        ASSUME  CS:_CODE, DS:_DATA, SS:_STACK

START:
        MOV     AX, _DATA               ; initialiser DS
        MOV     DS, AX
        MOV     AX, _STACK              ; initialiser SS
        MOV     SS, AX
        MOV     SP, OFFSET _STACK + 512 ; sommet de pile
        CALL    _JF_test01_hello_main   ; appel methode main
        CALL    _JRT_EXIT0              ; fin normale

; =========================================================
; Fichier genere par JAVAC86 v1.0
; Date    : 2026-03-02
; Source  : SAMPLES\JAVA\test01_hello.java
; Classe  : 
; Cible   : MASM 8086, modele SMALL
; =========================================================

        .8086
        DOSSEG
        .MODEL  SMALL

; ----- Macros -----
EXIT_DOS        MACRO
                MOV     AH, 4Ch
                INT     21h
                ENDM

INIT_DS         MACRO
                MOV     AX, @DATA
                MOV     DS, AX
                ENDM

; ----- Segment STACK -----
_STACK          SEGMENT PARA STACK 'STACK'
                        DB      512 DUP(?)
_STACK          ENDS

; Classe : test01_hello

; -----------------------------------------------------------------------
; Methode : main
; -----------------------------------------------------------------------
_JF_test01_hello_main:
        INIT_DS
        PUSH BP
        MOV     BP, SP                  ; sauver frame pointer
        MOV     AX, OFFSET _JS_1
        MOV     DX, 13
        MOV     CX, DX                  ; len -> CX
        CALL    _JRT_WRITESTR
        CALL    _JRT_WRITECRLF
_JF_test01_hello_main_ret:
        MOV     SP, BP                  ; restaurer SP
        POP  BP
        RET

        EXIT_DOS

_CODE           ENDS

_DATA           SEGMENT WORD PUBLIC 'DATA'

; Constantes runtime (BOOL2STR, CHAR2STR, ERRBOUND)
_J_BOOL_F               DB      'false', 0
_J_BOOL_T               DB      'true',  0
_J_CHARBUF              DB      0
_J_OOBE                 DB      'ArrayIndexOutOfBounds', 0Dh, 0Ah, '$'

_DATA           ENDS

_CODE           SEGMENT WORD PUBLIC 'CODE'
        ASSUME  CS:_CODE, DS:_DATA, SS:_STACK

; -----------------------------------------------------------------------
; RUNTIME : ARITHMETIQUE
; -----------------------------------------------------------------------

_JRT_IMUL:
        IMUL BX
        RET

_JRT_IDIV:
        CWD
        IDIV    BX
        MOV     CX, DX
        RET

_JRT_IMOD:
        CWD
        IDIV    BX
        MOV     AX, DX
        RET

_JRT_INEG:
        NEG  AX
        RET

_JRT_ABS:
        TEST    AX, AX
        JGE     _JRT_ABS_R
        NEG  AX
_JRT_ABS_R:
        RET

; INT2STR : entier AX -> chaine ASCII  AX=ptr DX=len
_JRT_INT2STR:
        PUSH    SI
        PUSH    DI
        PUSH    BX
        PUSH    CX
        MOV     DI, OFFSET _J_INTBUF
        MOV     SI, DI
        TEST    AX, AX
        JGE     _JRT_I2S_POS
        NEG  AX
        MOV  BYTE PTR [SI], '-'
        INC  SI
_JRT_I2S_POS:
        MOV     BX, 10
        XOR  CX, CX
_JRT_I2S_LP:
        XOR  DX, DX
        DIV  BX
        PUSH    DX
        INC  CX
        TEST    AX, AX
        JNZ     _JRT_I2S_LP
_JRT_I2S_ST:
        POP     DX
        ADD  DL, '0'
        MOV     [SI], DL
        INC  SI
        LOOP    _JRT_I2S_ST
        MOV  BYTE PTR [SI], 0
        MOV     AX, DI
        MOV     DX, SI
        SUB     DX, DI
        POP     CX
        POP     BX
        POP     DI
        POP     SI
        RET

; STR2INT : AX=ptr DX=len -> AX (entier)
_JRT_STR2INT:
        PUSH    SI
        PUSH    BX
        PUSH    CX
        PUSH    DI
        MOV     SI, AX
        MOV     CX, DX
        XOR  BX, BX
        XOR  DI, DI
        TEST    CX, CX
        JZ      _JRT_S2I_DONE
        MOV     AL, [SI]
        CMP  AL, '-'
        JNE     _JRT_S2I_LP
        MOV     DI, 1
        INC  SI
        DEC  CX
        JZ      _JRT_S2I_DONE
_JRT_S2I_LP:
        MOV     AL, [SI]
        SUB  AL, '0'
        JB      _JRT_S2I_DONE
        CMP  AL, 9
        JA      _JRT_S2I_DONE
        CBW
        PUSH    AX
        MOV     AX, BX
        MOV     BX, 10
        MUL  BX
        POP     BX
        ADD     AX, BX
        MOV     BX, AX
        INC  SI
        LOOP    _JRT_S2I_LP
_JRT_S2I_DONE:
        MOV     AX, BX
        TEST    DI, DI
        JZ      _JRT_S2I_RET
        NEG  AX
_JRT_S2I_RET:
        POP     DI
        POP     CX
        POP     BX
        POP     SI
        RET

; BOOL2STR : AX=0/1 -> AX=ptr DX=len (false = 5, true = 4)
_JRT_BOOL2STR:
        TEST    AX, AX
        JNZ     _JRT_B2S_T
        MOV     AX, OFFSET _J_BOOL_F
        MOV     DX, 5
        RET
_JRT_B2S_T:
        MOV     AX, OFFSET _J_BOOL_T
        MOV     DX, 4
        RET

; CHAR2STR : AL (code char) -> AX=ptr DX=1
_JRT_CHAR2STR:
        MOV     [_J_CHARBUF], AL
        MOV     AX, OFFSET _J_CHARBUF
        MOV     DX, 1
        RET

; ERRBOUND : ArrayIndexOutOfBounds + INT 21h 4C01h
_JRT_ERRBOUND:
_JRT_BOUNDS_ERR:
        MOV     AH, 09h
        MOV     DX, OFFSET _J_OOBE
        INT  21h
        MOV     AX, 4C01h
        INT  21h

; -----------------------------------------------------------------------
; RUNTIME : ENTREES / SORTIES
; -----------------------------------------------------------------------

; WRITESTR : AX=ptr CX=len -> stdout (boucle INT 21h AH=02h)
_JRT_WRITESTR:
        PUSH    SI
        PUSH    CX
        MOV     SI, AX
        TEST    CX, CX
        JZ      _JRT_WS_DONE
_JRT_WS_LP:
        MOV     DL, [SI]
        MOV     AH, 02h
        INT  21h
        INC  SI
        LOOP    _JRT_WS_LP
_JRT_WS_DONE:
        POP     CX
        POP     SI
        RET

; WRITECRLF : afficher CR LF
_JRT_WRITECRLF:
        MOV     DL, 0Dh
        MOV     AH, 02h
        INT  21h
        MOV     DL, 0Ah
        MOV     AH, 02h
        INT  21h
        RET

; WRITECHR : AL (code char) -> stdout
_JRT_WRITECHR:
        MOV     DL, AL
        MOV     AH, 02h
        INT  21h
        RET

; WRITEINT : param [BP+2] (int) -> INT2STR + WRITESTR
_JRT_WRITEINT:
        PUSH BP
        MOV     BP, SP
        MOV     AX, [BP+4]
        CALL    _JRT_INT2STR
        MOV     CX, DX
        CALL    _JRT_WRITESTR
        POP  BP
        RET

; WRITEBOOL : param [BP+4] (bool) -> BOOL2STR + WRITESTR
_JRT_WRITEBOOL:
        PUSH BP
        MOV     BP, SP
        MOV     AX, [BP+4]
        CALL    _JRT_BOOL2STR
        MOV     CX, DX
        CALL    _JRT_WRITESTR
        POP  BP
        RET

; READLINE : stdin -> AX=ptr(_J_INBUF+2) DX=len
_JRT_READLINE:
        PUSH    BX
        MOV     BYTE PTR [_J_INBUF], 126
        MOV     BYTE PTR [_J_INBUF+1], 0
        MOV     AH, 0Ah
        MOV     DX, OFFSET _J_INBUF
        INT  21h
        CALL    _JRT_WRITECRLF
        XOR  BX, BX
        MOV     BL, [_J_INBUF+1]
        MOV     AX, OFFSET _J_INBUF + 2
        MOV     DX, BX
        POP     BX
        RET

; READINT : stdin -> AX (entier)
_JRT_READINT:
        CALL    _JRT_READLINE
        CALL    _JRT_STR2INT
        RET

; ERRMSG : AX=ptr (chaine $-terminee) -> affiche + Halt 1
_JRT_ERRMSG:
        MOV     DX, AX
        MOV     AH, 09h
        INT  21h
        MOV     AX, 4C01h
        INT  21h

; EXIT0 : MOV AX,4C00h / INT 21h
_JRT_EXIT0:
        MOV     AX, 4C00h
        INT  21h

; STRCAT : 4 mots sur pile -> _J_OUTBUF; AX=ptr DX=len
_JRT_STRCAT:
        PUSH BP
        MOV     BP, SP
        PUSH    SI
        PUSH    DI
        PUSH    BX
        MOV     DI, OFFSET _J_OUTBUF
        MOV     SI, [BP+8]
        MOV     CX, [BP+10]
        MOV     BX, CX
        TEST    CX, CX
        JZ      _JRT_SC_S2
_JRT_SC_L1:
        MOV     AL, [SI]
        MOV     [DI], AL
        INC  SI
        INC  DI
        LOOP    _JRT_SC_L1
_JRT_SC_S2:
        MOV     SI, [BP+4]
        MOV     CX, [BP+6]
        ADD     BX, CX
        TEST    CX, CX
        JZ      _JRT_SC_DONE
_JRT_SC_L2:
        MOV     AL, [SI]
        MOV     [DI], AL
        INC  SI
        INC  DI
        LOOP    _JRT_SC_L2
_JRT_SC_DONE:
        MOV  BYTE PTR [DI], 0
        MOV     AX, OFFSET _J_OUTBUF
        MOV     DX, BX
        POP     BX
        POP     DI
        POP     SI
        POP  BP
        RET

; STRCMP : 4 mots sur pile -> AX=0 egal, AX=-1 s1<s2, AX=1 s1>s2
_JRT_STRCMP:
        PUSH BP
        MOV     BP, SP
        PUSH    SI
        PUSH    DI
        PUSH    BX
        PUSH    CX
        MOV     SI, [BP+8]
        MOV     BX, [BP+10]
        MOV     DI, [BP+4]
        MOV     CX, [BP+6]
        CMP     CX, BX
        JBE     _JRT_SCMP_LP
        MOV     CX, BX
_JRT_SCMP_LP:
        TEST    CX, CX
        JZ      _JRT_SCMP_LEN
        MOV     AL, [SI]
        MOV     DL, [DI]
        INC  SI
        INC  DI
        DEC  CX
        CMP     AL, DL
        JB      _JRT_SCMP_LT
        JA      _JRT_SCMP_GT
        JMP     _JRT_SCMP_LP
_JRT_SCMP_LEN:
        MOV     AX, [BP+10]
        CMP     AX, [BP+6]
        JB      _JRT_SCMP_LT
        JA      _JRT_SCMP_GT
        XOR  AX, AX
        JMP     _JRT_SCMP_RET
_JRT_SCMP_LT:
        MOV     AX, 0FFFFh
        JMP     _JRT_SCMP_RET
_JRT_SCMP_GT:
        MOV     AX, 1
_JRT_SCMP_RET:
        POP     CX
        POP     BX
        POP     DI
        POP     SI
        POP  BP
        RET

; PRINTF : format AX=ptr CX=len -> WRITESTR (stub)
_JRT_PRINTF:
        CALL    _JRT_WRITESTR
        RET


_CODE           ENDS

        END     START
