; =========================================================
; Genere par CLOJ86 v1.0 (2026-03-07)
; Source  : SAMPLES/CLOJURE/test_destr.clj
; Cible   : MASM 8086, modele SMALL
; =========================================================

        .MODEL SMALL
        .STACK 1024

_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME  CS:_TEXT, DS:_DATA, SS:NOTHING

_CLF_main:
; --- initialisation DS ---
        MOV AX,_DATA
        MOV DS,AX

; (let [...] ...)
        SUB SP,2
; (vector ...)
        MOV AX,1
        PUSH AX
        MOV AX,2
        PUSH AX
        MOV AX,3
        PUSH AX
        MOV DI,WORD PTR [_CL_HEAPTOP]
        MOV BX,OFFSET _CL_HEAP
        ADD BX,DI
        MOV WORD PTR [BX],3
        POP AX
        MOV WORD PTR [BX+6],AX
        POP AX
        MOV WORD PTR [BX+4],AX
        POP AX
        MOV WORD PTR [BX+2],AX
        MOV AX,BX
        ADD DI,8
        MOV WORD PTR [_CL_HEAPTOP],DI
        MOV WORD PTR [BP-2],AX
        SUB SP,2
        MOV AX,WORD PTR [BP-2]
        MOV BX,0
        CALL _CLRT_VECNTH
        MOV WORD PTR [BP-4],AX
        SUB SP,2
        MOV AX,WORD PTR [BP-2]
        MOV BX,1
        CALL _CLRT_VECNTH
        MOV WORD PTR [BP-6],AX
        SUB SP,2
        MOV AX,WORD PTR [BP-2]
        MOV BX,2
        CALL _CLRT_VECNTH
        MOV WORD PTR [BP-8],AX
; (println ...)
        MOV AX,WORD PTR [BP-4]
        MOV DI,OFFSET _CL_NUMBUF
        CALL _CLRT_NUMTOSTR
        MOV SI,DI
        CALL _CLRT_PRINTSTR
        CALL _CLRT_WRITECRLF
        XOR AX,AX
; (println ...)
        MOV AX,WORD PTR [BP-6]
        MOV DI,OFFSET _CL_NUMBUF
        CALL _CLRT_NUMTOSTR
        MOV SI,DI
        CALL _CLRT_PRINTSTR
        CALL _CLRT_WRITECRLF
        XOR AX,AX
; (println ...)
        MOV AX,WORD PTR [BP-8]
        MOV DI,OFFSET _CL_NUMBUF
        CALL _CLRT_NUMTOSTR
        MOV SI,DI
        CALL _CLRT_PRINTSTR
        CALL _CLRT_WRITECRLF
        XOR AX,AX
        ADD SP,8
; (let [...] ...)
        SUB SP,2
; (vector ...)
        MOV AX,10
        PUSH AX
        MOV AX,20
        PUSH AX
        MOV AX,30
        PUSH AX
        MOV DI,WORD PTR [_CL_HEAPTOP]
        MOV BX,OFFSET _CL_HEAP
        ADD BX,DI
        MOV WORD PTR [BX],3
        POP AX
        MOV WORD PTR [BX+6],AX
        POP AX
        MOV WORD PTR [BX+4],AX
        POP AX
        MOV WORD PTR [BX+2],AX
        MOV AX,BX
        ADD DI,8
        MOV WORD PTR [_CL_HEAPTOP],DI
        MOV WORD PTR [BP-2],AX
        SUB SP,2
        MOV AX,WORD PTR [BP-2]
        MOV BX,0
        CALL _CLRT_VECNTH
        MOV WORD PTR [BP-4],AX
        SUB SP,2
        MOV AX,WORD PTR [BP-2]
        MOV BX,2
        CALL _CLRT_VECNTH
        MOV WORD PTR [BP-6],AX
; (println ...)
        MOV AX,WORD PTR [BP-4]
        MOV DI,OFFSET _CL_NUMBUF
        CALL _CLRT_NUMTOSTR
        MOV SI,DI
        CALL _CLRT_PRINTSTR
        CALL _CLRT_WRITECRLF
        XOR AX,AX
; (println ...)
        MOV AX,WORD PTR [BP-6]
        MOV DI,OFFSET _CL_NUMBUF
        CALL _CLRT_NUMTOSTR
        MOV SI,DI
        CALL _CLRT_PRINTSTR
        CALL _CLRT_WRITECRLF
        XOR AX,AX
        ADD SP,6
; (let [...] ...)
        SUB SP,2
; (hash-map ...)
        XOR AX,AX
        PUSH AX
        MOV AX,42
        PUSH AX
        MOV AX,1
        PUSH AX
        MOV AX,25
        PUSH AX
        MOV DI,WORD PTR [_CL_HEAPTOP]
        MOV BX,OFFSET _CL_HEAP
        ADD BX,DI
        MOV WORD PTR [BX],2
        POP AX
        MOV WORD PTR [BX+8],AX
        POP AX
        MOV WORD PTR [BX+6],AX
        POP AX
        MOV WORD PTR [BX+4],AX
        POP AX
        MOV WORD PTR [BX+2],AX
        MOV AX,BX
        ADD DI,10
        MOV WORD PTR [_CL_HEAPTOP],DI
        MOV WORD PTR [BP-2],AX
        SUB SP,2
        MOV AX,WORD PTR [BP-2]
        MOV BX,0
        CALL _CLRT_MAPGET
        MOV WORD PTR [BP-4],AX
        SUB SP,2
        MOV AX,WORD PTR [BP-2]
        MOV BX,1
        CALL _CLRT_MAPGET
        MOV WORD PTR [BP-6],AX
; (println ...)
        MOV AX,WORD PTR [BP-4]
        MOV DI,OFFSET _CL_NUMBUF
        CALL _CLRT_NUMTOSTR
        MOV SI,DI
        CALL _CLRT_PRINTSTR
        CALL _CLRT_WRITECRLF
        XOR AX,AX
; (println ...)
        MOV AX,WORD PTR [BP-6]
        MOV DI,OFFSET _CL_NUMBUF
        CALL _CLRT_NUMTOSTR
        MOV SI,DI
        CALL _CLRT_PRINTSTR
        CALL _CLRT_WRITECRLF
        XOR AX,AX
        ADD SP,6
; (let [...] ...)
        SUB SP,2
; (hash-map ...)
        XOR AX,AX
        PUSH AX
        MOV AX,42
        PUSH AX
        MOV AX,1
        PUSH AX
        MOV AX,25
        PUSH AX
        MOV DI,WORD PTR [_CL_HEAPTOP]
        MOV BX,OFFSET _CL_HEAP
        ADD BX,DI
        MOV WORD PTR [BX],2
        POP AX
        MOV WORD PTR [BX+8],AX
        POP AX
        MOV WORD PTR [BX+6],AX
        POP AX
        MOV WORD PTR [BX+4],AX
        POP AX
        MOV WORD PTR [BX+2],AX
        MOV AX,BX
        ADD DI,10
        MOV WORD PTR [_CL_HEAPTOP],DI
        MOV WORD PTR [BP-2],AX
        SUB SP,2
        MOV AX,WORD PTR [BP-2]
        MOV BX,0
        CALL _CLRT_MAPGET
        MOV WORD PTR [BP-4],AX
        SUB SP,2
        MOV AX,WORD PTR [BP-2]
        MOV BX,1
        CALL _CLRT_MAPGET
        MOV WORD PTR [BP-6],AX
; (println ...)
        MOV AX,WORD PTR [BP-4]
        MOV DI,OFFSET _CL_NUMBUF
        CALL _CLRT_NUMTOSTR
        MOV SI,DI
        CALL _CLRT_PRINTSTR
        CALL _CLRT_WRITECRLF
        XOR AX,AX
; (println ...)
        MOV AX,WORD PTR [BP-6]
        MOV DI,OFFSET _CL_NUMBUF
        CALL _CLRT_NUMTOSTR
        MOV SI,DI
        CALL _CLRT_PRINTSTR
        CALL _CLRT_WRITECRLF
        XOR AX,AX
        ADD SP,6
; (defn somme-vec ...)
        JMP _CL_1
_CLF_somme_vec:
        PUSH BP
        MOV BP,SP
; destrVec param __dp0
        SUB SP,2
        MOV AX,WORD PTR [BP+4]
        MOV BX,0
        CALL _CLRT_VECNTH
        MOV WORD PTR [BP-2],AX
        SUB SP,2
        MOV AX,WORD PTR [BP+4]
        MOV BX,1
        CALL _CLRT_VECNTH
        MOV WORD PTR [BP-4],AX
        SUB SP,2
        MOV AX,WORD PTR [BP+4]
        MOV BX,2
        CALL _CLRT_VECNTH
        MOV WORD PTR [BP-6],AX
; (+ ...)
        MOV AX,WORD PTR [BP-2]
        PUSH AX
; (+ ...)
        MOV AX,WORD PTR [BP-4]
        PUSH AX
        MOV AX,WORD PTR [BP-6]
        MOV BX,AX
        POP AX
        ADD AX,BX
        MOV BX,AX
        POP AX
        ADD AX,BX
        MOV SP,BP
        POP BP
        RET
_CL_1:
        XOR AX,AX
; (println ...)
; (somme-vec ...)
; (vector ...)
        MOV AX,1
        PUSH AX
        MOV AX,2
        PUSH AX
        MOV AX,3
        PUSH AX
        MOV DI,WORD PTR [_CL_HEAPTOP]
        MOV BX,OFFSET _CL_HEAP
        ADD BX,DI
        MOV WORD PTR [BX],3
        POP AX
        MOV WORD PTR [BX+6],AX
        POP AX
        MOV WORD PTR [BX+4],AX
        POP AX
        MOV WORD PTR [BX+2],AX
        MOV AX,BX
        ADD DI,8
        MOV WORD PTR [_CL_HEAPTOP],DI
        PUSH AX
        CALL _CLF_somme_vec
        ADD SP,2
        MOV SI,AX
        CALL _CLRT_PRINTSTR
        CALL _CLRT_WRITECRLF
        XOR AX,AX

; === RUNTIME CLOJURE ===

_CLRT_PRINTSTR:
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    SI
        MOV     DX, SI
        XOR     CX, CX
_CLRT_PS_LN:
        CMP     BYTE PTR [SI], 0
        JE      _CLRT_PS_DN
        INC     SI
        INC     CX
        JMP     _CLRT_PS_LN
_CLRT_PS_DN:
        TEST    CX, CX
        JZ      _CLRT_PS_EX
        MOV     BX, 1
        MOV     AH, 40h
        INT     21h
_CLRT_PS_EX:
        POP     SI
        POP     DX
        POP     CX
        POP     BX
        POP     AX
        RET

_CLRT_WRITECRLF:
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        MOV     DX, OFFSET _CL_CRLF
        MOV     CX, 2
        MOV     BX, 1
        MOV     AH, 40h
        INT     21h
        POP     DX
        POP     CX
        POP     BX
        POP     AX
        RET

_CLRT_PRINTSPACE:
        PUSH    AX
        PUSH    DX
        MOV     DL, 32
        MOV     AH, 02h
        INT     21h
        POP     DX
        POP     AX
        RET

_CLRT_NUMTOSTR:
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    SI
        PUSH    DI
        TEST    AX, AX
        JGE     _CLRT_NT_POS
        NEG     AX
        MOV     BYTE PTR [DI], '-'
        INC     DI
_CLRT_NT_POS:
        MOV     SI, DI
        MOV     BX, 10
        XOR     CX, CX
_CLRT_NT_DL:
        XOR     DX, DX
        DIV     BX
        ADD     DL, 48
        PUSH    DX
        INC     CX
        TEST    AX, AX
        JNZ     _CLRT_NT_DL
_CLRT_NT_RL:
        POP     DX
        MOV     [SI], DL
        INC     SI
        LOOP    _CLRT_NT_RL
        MOV     BYTE PTR [SI], 0
        POP     DI
        POP     SI
        POP     DX
        POP     CX
        POP     BX
        RET

_CLRT_PRINTBOOL:
        PUSH    SI
        TEST    AX, AX
        JZ      _CLRT_PB_F
        MOV     SI, OFFSET _CL_TRUE
        JMP     _CLRT_PB_P
_CLRT_PB_F:
        MOV     SI, OFFSET _CL_FALSE
_CLRT_PB_P:
        CALL    _CLRT_PRINTSTR
        POP     SI
        RET

_CLRT_BOOLTOSTR:
        TEST    AX, AX
        JZ      _CLRT_BTS_F
        MOV     AX, OFFSET _CL_TRUE
        RET
_CLRT_BTS_F:
        MOV     AX, OFFSET _CL_FALSE
        RET

_CLRT_STRLEN:
        PUSH    SI
        XOR     AX, AX
_CLRT_SL_LP:
        CMP     BYTE PTR [SI], 0
        JE      _CLRT_SL_DN
        INC     SI
        INC     AX
        JMP     _CLRT_SL_LP
_CLRT_SL_DN:
        POP     SI
        RET

_CLRT_CONCAT:
        PUSH    AX
        PUSH    DI
        PUSH    SI
_CLRT_CC_SK:
        CMP     BYTE PTR [DI], 0
        JE      _CLRT_CC_CP
        INC     DI
        JMP     _CLRT_CC_SK
_CLRT_CC_CP:
        MOV     AL, [SI]
        MOV     [DI], AL
        TEST    AL, AL
        JZ      _CLRT_CC_DN
        INC     SI
        INC     DI
        JMP     _CLRT_CC_CP
_CLRT_CC_DN:
        POP     SI
        POP     DI
        POP     AX
        RET

_CLRT_STRCMP:
        PUSH    SI
        PUSH    DI
_CLRT_SC_LP:
        MOV     AL, [SI]
        MOV     AH, [DI]
        CMP     AL, AH
        JNE     _CLRT_SC_NE
        TEST    AL, AL
        JZ      _CLRT_SC_EQ
        INC     SI
        INC     DI
        JMP     _CLRT_SC_LP
_CLRT_SC_EQ:
        XOR     AX, AX
        JMP     _CLRT_SC_DN
_CLRT_SC_NE:
        XOR     AH, AH
        MOV     BL, [DI]
        XOR     BH, BH
        SUB     AX, BX
_CLRT_SC_DN:
        POP     DI
        POP     SI
        RET

_CLRT_READLINE:
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    SI
        MOV     DX, OFFSET _CL_INBUF
        MOV     SI, DX
        MOV     BYTE PTR [SI], 126
        MOV     AH, 0Ah
        INT     21h
        XOR     CH, CH
        MOV     CL, [SI+1]
        LEA     AX, [SI+2]
        ADD     SI, 2
        ADD     SI, CX
        MOV     BYTE PTR [SI], 0
        LEA     AX, [DX+2]
        POP     SI
        POP     DX
        POP     CX
        POP     BX
        RET

_CLRT_CONS:
        PUSH    CX
        PUSH    DI
        MOV     DI, WORD PTR [_CL_HEAPTOP]
        MOV     CX, OFFSET _CL_HEAP
        ADD     CX, DI
        MOV     WORD PTR [CX], AX
        MOV     WORD PTR [CX+2], BX
        MOV     AX, CX
        ADD     DI, 4
        MOV     WORD PTR [_CL_HEAPTOP], DI
        POP     DI
        POP     CX
        RET

_CLRT_LCOUNT:
        PUSH    BX
        XOR     BX, BX
_CLRT_LC_LP:
        CMP     AX, 0
        JE      _CLRT_LC_DN
        INC     BX
        PUSH    SI
        MOV     SI, AX
        MOV     AX, WORD PTR [SI+2]
        POP     SI
        JMP     _CLRT_LC_LP
_CLRT_LC_DN:
        MOV     AX, BX
        POP     BX
        RET

_CLRT_LNTH:
        PUSH    CX
        PUSH    SI
        MOV     CX, BX
_CLRT_LN_LP:
        CMP     AX, 0
        JE      _CLRT_LN_NL
        CMP     CX, 0
        JE      _CLRT_LN_OK
        DEC     CX
        MOV     SI, AX
        MOV     AX, WORD PTR [SI+2]
        JMP     _CLRT_LN_LP
_CLRT_LN_OK:
        MOV     SI, AX
        MOV     AX, WORD PTR [SI]
        POP     SI
        POP     CX
        RET
_CLRT_LN_NL:
        XOR     AX, AX
        POP     SI
        POP     CX
        RET

_CLRT_VECNTH:
        CMP     AX, 0
        JE      _CLRT_VN_NL
        PUSH    SI
        MOV     SI, AX
        CMP     BX, WORD PTR [SI]
        JAE     _CLRT_VN_OB
        SHL     BX, 1
        ADD     BX, 2
        ADD     SI, BX
        MOV     AX, WORD PTR [SI]
        POP     SI
        RET
_CLRT_VN_OB:
        XOR     AX, AX
        POP     SI
        RET
_CLRT_VN_NL:
        XOR     AX, AX
        RET

_CLRT_VECCONJ:
        PUSH    CX
        PUSH    SI
        PUSH    DI
        PUSH    BX
        MOV     SI, AX
        MOV     CX, WORD PTR [SI]
        MOV     DI, WORD PTR [_CL_HEAPTOP]
        MOV     BX, DI
        ADD     BX, OFFSET _CL_HEAP
        MOV     AX, CX
        INC     AX
        MOV     WORD PTR [BX], AX
        INC     AX
        SHL     AX, 1
        ADD     DI, AX
        MOV     WORD PTR [_CL_HEAPTOP], DI
        ADD     SI, 2
        MOV     DI, BX
        ADD     DI, 2
_CLRT_VC_LP:
        CMP     CX, 0
        JE      _CLRT_VC_DN
        MOV     AX, WORD PTR [SI]
        MOV     WORD PTR [DI], AX
        ADD     SI, 2
        ADD     DI, 2
        DEC     CX
        JMP     _CLRT_VC_LP
_CLRT_VC_DN:
        POP     AX
        MOV     WORD PTR [DI], AX
        MOV     AX, BX
        POP     DI
        POP     SI
        POP     CX
        RET

_CLRT_VECASSOC:
        PUSH    SI
        PUSH    DI
        PUSH    DX
        MOV     WORD PTR [_CL_VTMP1], BX
        MOV     WORD PTR [_CL_VTMP2], CX
        MOV     SI, AX
        MOV     CX, WORD PTR [SI]
        MOV     DI, WORD PTR [_CL_HEAPTOP]
        MOV     BX, DI
        ADD     BX, OFFSET _CL_HEAP
        MOV     WORD PTR [BX], CX
        MOV     AX, CX
        INC     AX
        SHL     AX, 1
        ADD     DI, AX
        MOV     WORD PTR [_CL_HEAPTOP], DI
        ADD     SI, 2
        MOV     DI, BX
        ADD     DI, 2
        XOR     DX, DX
_CLRT_VA_LP:
        CMP     DX, CX
        JAE     _CLRT_VA_DN
        CMP     DX, WORD PTR [_CL_VTMP1]
        JE      _CLRT_VA_RP
        MOV     AX, WORD PTR [SI]
        MOV     WORD PTR [DI], AX
        JMP     _CLRT_VA_NX
_CLRT_VA_RP:
        MOV     AX, WORD PTR [_CL_VTMP2]
        MOV     WORD PTR [DI], AX
_CLRT_VA_NX:
        ADD     SI, 2
        ADD     DI, 2
        INC     DX
        JMP     _CLRT_VA_LP
_CLRT_VA_DN:
        MOV     AX, BX
        POP     DX
        POP     DI
        POP     SI
        RET

_CLRT_SUBVEC:
        PUSH    SI
        PUSH    DI
        PUSH    DX
        MOV     SI, AX
        MOV     DX, CX
        SUB     DX, BX
        MOV     DI, WORD PTR [_CL_HEAPTOP]
        PUSH    BX
        MOV     BX, DI
        ADD     BX, OFFSET _CL_HEAP
        MOV     WORD PTR [BX], DX
        MOV     AX, DX
        INC     AX
        SHL     AX, 1
        ADD     DI, AX
        MOV     WORD PTR [_CL_HEAPTOP], DI
        POP     AX
        SHL     AX, 1
        ADD     AX, 2
        ADD     SI, AX
        MOV     DI, BX
        ADD     DI, 2
        MOV     CX, DX
_CLRT_SV_LP:
        CMP     CX, 0
        JE      _CLRT_SV_DN
        MOV     AX, WORD PTR [SI]
        MOV     WORD PTR [DI], AX
        ADD     SI, 2
        ADD     DI, 2
        DEC     CX
        JMP     _CLRT_SV_LP
_CLRT_SV_DN:
        MOV     AX, BX
        POP     DX
        POP     DI
        POP     SI
        RET

_CLRT_MAPGET:
        CMP     AX, 0
        JE      _CLRT_MG_NL
        PUSH    SI
        PUSH    CX
        MOV     SI, AX
        MOV     CX, WORD PTR [SI]
        ADD     SI, 2
_CLRT_MG_LP:
        CMP     CX, 0
        JE      _CLRT_MG_NF
        CMP     WORD PTR [SI], BX
        JE      _CLRT_MG_FN
        ADD     SI, 4
        DEC     CX
        JMP     _CLRT_MG_LP
_CLRT_MG_FN:
        MOV     AX, WORD PTR [SI+2]
        POP     CX
        POP     SI
        RET
_CLRT_MG_NF:
        XOR     AX, AX
        POP     CX
        POP     SI
        RET
_CLRT_MG_NL:
        XOR     AX, AX
        RET

_CLRT_MAPASSOC:
        MOV     WORD PTR [_CL_MTMP1], BX
        MOV     WORD PTR [_CL_MTMP2], CX
        PUSH    SI
        PUSH    DI
        PUSH    DX
        CMP     AX, 0
        JE      _CLRT_MA_NW
        MOV     SI, AX
        MOV     CX, WORD PTR [SI]
        PUSH    CX
        PUSH    SI
        ADD     SI, 2
        MOV     BX, WORD PTR [_CL_MTMP1]
_CLRT_MA_SK:
        CMP     CX, 0
        JE      _CLRT_MA_AD
        CMP     WORD PTR [SI], BX
        JE      _CLRT_MA_RP
        ADD     SI, 4
        DEC     CX
        JMP     _CLRT_MA_SK
_CLRT_MA_RP:
        POP     SI
        POP     CX
        MOV     DI, WORD PTR [_CL_HEAPTOP]
        MOV     BX, DI
        ADD     BX, OFFSET _CL_HEAP
        MOV     WORD PTR [BX], CX
        MOV     AX, CX
        SHL     AX, 1
        SHL     AX, 1
        ADD     AX, 2
        ADD     DI, AX
        MOV     WORD PTR [_CL_HEAPTOP], DI
        ADD     SI, 2
        MOV     DI, BX
        ADD     DI, 2
        MOV     DX, CX
_CLRT_MA_CL:
        CMP     DX, 0
        JE      _CLRT_MA_DN
        MOV     AX, WORD PTR [SI]
        MOV     WORD PTR [DI], AX
        CMP     AX, WORD PTR [_CL_MTMP1]
        JE      _CLRT_MA_RV
        MOV     AX, WORD PTR [SI+2]
        MOV     WORD PTR [DI+2], AX
        JMP     _CLRT_MA_NX
_CLRT_MA_RV:
        MOV     AX, WORD PTR [_CL_MTMP2]
        MOV     WORD PTR [DI+2], AX
_CLRT_MA_NX:
        ADD     SI, 4
        ADD     DI, 4
        DEC     DX
        JMP     _CLRT_MA_CL
_CLRT_MA_DN:
        MOV     AX, BX
        POP     DX
        POP     DI
        POP     SI
        RET
_CLRT_MA_AD:
        POP     SI
        POP     CX
        MOV     AX, CX
        INC     AX
        MOV     DI, WORD PTR [_CL_HEAPTOP]
        MOV     BX, DI
        ADD     BX, OFFSET _CL_HEAP
        MOV     WORD PTR [BX], AX
        SHL     AX, 1
        SHL     AX, 1
        ADD     AX, 2
        ADD     DI, AX
        MOV     WORD PTR [_CL_HEAPTOP], DI
        ADD     SI, 2
        MOV     DI, BX
        ADD     DI, 2
        MOV     DX, CX
_CLRT_MA_C2:
        CMP     DX, 0
        JE      _CLRT_MA_AP
        MOV     AX, WORD PTR [SI]
        MOV     WORD PTR [DI], AX
        MOV     AX, WORD PTR [SI+2]
        MOV     WORD PTR [DI+2], AX
        ADD     SI, 4
        ADD     DI, 4
        DEC     DX
        JMP     _CLRT_MA_C2
_CLRT_MA_AP:
        MOV     AX, WORD PTR [_CL_MTMP1]
        MOV     WORD PTR [DI], AX
        MOV     AX, WORD PTR [_CL_MTMP2]
        MOV     WORD PTR [DI+2], AX
        MOV     AX, BX
        POP     DX
        POP     DI
        POP     SI
        RET
_CLRT_MA_NW:
        MOV     DI, WORD PTR [_CL_HEAPTOP]
        MOV     BX, DI
        ADD     BX, OFFSET _CL_HEAP
        MOV     WORD PTR [BX], 1
        MOV     AX, WORD PTR [_CL_MTMP1]
        MOV     WORD PTR [BX+2], AX
        MOV     AX, WORD PTR [_CL_MTMP2]
        MOV     WORD PTR [BX+4], AX
        ADD     DI, 6
        MOV     WORD PTR [_CL_HEAPTOP], DI
        MOV     AX, BX
        POP     DX
        POP     DI
        POP     SI
        RET

_CLRT_MAPDISSOC:
        CMP     AX, 0
        JE      _CLRT_MD_NL
        PUSH    SI
        PUSH    DI
        PUSH    DX
        PUSH    CX
        MOV     SI, AX
        MOV     CX, WORD PTR [SI]
        MOV     DI, WORD PTR [_CL_HEAPTOP]
        PUSH    BX
        MOV     BX, DI
        ADD     BX, OFFSET _CL_HEAP
        MOV     DX, CX
        DEC     DX
        CMP     DX, 0
        JL      _CLRT_MD_E0
        MOV     WORD PTR [BX], DX
        MOV     AX, DX
        SHL     AX, 1
        SHL     AX, 1
        ADD     AX, 2
        ADD     DI, AX
        MOV     WORD PTR [_CL_HEAPTOP], DI
        ADD     SI, 2
        MOV     DI, BX
        ADD     DI, 2
        POP     AX
_CLRT_MD_LP:
        CMP     CX, 0
        JE      _CLRT_MD_DN
        CMP     WORD PTR [SI], AX
        JE      _CLRT_MD_SP
        PUSH    AX
        MOV     AX, WORD PTR [SI]
        MOV     WORD PTR [DI], AX
        MOV     AX, WORD PTR [SI+2]
        MOV     WORD PTR [DI+2], AX
        POP     AX
        ADD     DI, 4
_CLRT_MD_SP:
        ADD     SI, 4
        DEC     CX
        JMP     _CLRT_MD_LP
_CLRT_MD_DN:
        MOV     AX, BX
        POP     CX
        POP     DX
        POP     DI
        POP     SI
        RET
_CLRT_MD_E0:
        POP     BX
        XOR     AX, AX
        POP     CX
        POP     DX
        POP     DI
        POP     SI
        RET
_CLRT_MD_NL:
        XOR     AX, AX
        RET

_CLRT_MAPHAS:
        CMP     AX, 0
        JE      _CLRT_MH_NO
        PUSH    SI
        PUSH    CX
        MOV     SI, AX
        MOV     CX, WORD PTR [SI]
        ADD     SI, 2
_CLRT_MH_LP:
        CMP     CX, 0
        JE      _CLRT_MH_NF
        CMP     WORD PTR [SI], BX
        JE      _CLRT_MH_FN
        ADD     SI, 4
        DEC     CX
        JMP     _CLRT_MH_LP
_CLRT_MH_FN:
        MOV     AX, 1
        POP     CX
        POP     SI
        RET
_CLRT_MH_NF:
        XOR     AX, AX
        POP     CX
        POP     SI
        RET
_CLRT_MH_NO:
        XOR     AX, AX
        RET

_CLRT_MAPKEYS:
        CMP     AX, 0
        JE      _CLRT_MK_NL
        PUSH    SI
        PUSH    DI
        PUSH    CX
        MOV     SI, AX
        MOV     CX, WORD PTR [SI]
        MOV     DI, WORD PTR [_CL_HEAPTOP]
        MOV     BX, DI
        ADD     BX, OFFSET _CL_HEAP
        MOV     WORD PTR [BX], CX
        MOV     AX, CX
        INC     AX
        SHL     AX, 1
        ADD     DI, AX
        MOV     WORD PTR [_CL_HEAPTOP], DI
        ADD     SI, 2
        MOV     DI, BX
        ADD     DI, 2
_CLRT_MK_LP:
        CMP     CX, 0
        JE      _CLRT_MK_DN
        MOV     AX, WORD PTR [SI]
        MOV     WORD PTR [DI], AX
        ADD     SI, 4
        ADD     DI, 2
        DEC     CX
        JMP     _CLRT_MK_LP
_CLRT_MK_DN:
        MOV     AX, BX
        POP     CX
        POP     DI
        POP     SI
        RET
_CLRT_MK_NL:
        XOR     AX, AX
        RET

_CLRT_MAPVALS:
        CMP     AX, 0
        JE      _CLRT_MV_NL
        PUSH    SI
        PUSH    DI
        PUSH    CX
        MOV     SI, AX
        MOV     CX, WORD PTR [SI]
        MOV     DI, WORD PTR [_CL_HEAPTOP]
        MOV     BX, DI
        ADD     BX, OFFSET _CL_HEAP
        MOV     WORD PTR [BX], CX
        MOV     AX, CX
        INC     AX
        SHL     AX, 1
        ADD     DI, AX
        MOV     WORD PTR [_CL_HEAPTOP], DI
        ADD     SI, 2
        MOV     DI, BX
        ADD     DI, 2
_CLRT_MV_LP:
        CMP     CX, 0
        JE      _CLRT_MV_DN
        MOV     AX, WORD PTR [SI+2]
        MOV     WORD PTR [DI], AX
        ADD     SI, 4
        ADD     DI, 2
        DEC     CX
        JMP     _CLRT_MV_LP
_CLRT_MV_DN:
        MOV     AX, BX
        POP     CX
        POP     DI
        POP     SI
        RET
_CLRT_MV_NL:
        XOR     AX, AX
        RET

_CLRT_MAPMERGE:
        CMP     AX, 0
        JE      _CLRT_MM_R2
        CMP     BX, 0
        JE      _CLRT_MM_R1
        PUSH    SI
        PUSH    DI
        PUSH    DX
        PUSH    CX
        MOV     SI, AX
        MOV     CX, WORD PTR [SI]
        MOV     DI, WORD PTR [_CL_HEAPTOP]
        MOV     AX, DI
        ADD     AX, OFFSET _CL_HEAP
        PUSH    AX
        MOV     DX, CX
        SHL     DX, 1
        SHL     DX, 1
        ADD     DX, 2
        ADD     DI, DX
        MOV     WORD PTR [_CL_HEAPTOP], DI
        POP     DI
        PUSH    DI
        MOV     DX, CX
        SHL     DX, 1
        INC     DX
_CLRT_MM_C1:
        CMP     DX, 0
        JE      _CLRT_MM_P2
        MOV     AX, WORD PTR [SI]
        MOV     WORD PTR [DI], AX
        ADD     SI, 2
        ADD     DI, 2
        DEC     DX
        JMP     _CLRT_MM_C1
_CLRT_MM_P2:
        MOV     SI, BX
        MOV     CX, WORD PTR [SI]
        ADD     SI, 2
_CLRT_MM_LP:
        CMP     CX, 0
        JE      _CLRT_MM_DN
        MOV     BX, WORD PTR [SI]
        MOV     DX, WORD PTR [SI+2]
        POP     AX
        PUSH    CX
        PUSH    SI
        MOV     CX, DX
        CALL    _CLRT_MAPASSOC
        PUSH    AX
        POP     AX
        PUSH    AX
        POP     SI
        POP     CX
        ADD     SI, 4
        DEC     CX
        JMP     _CLRT_MM_LP
_CLRT_MM_DN:
        POP     AX
        POP     CX
        POP     DX
        POP     DI
        POP     SI
        RET
_CLRT_MM_R1:
        RET
_CLRT_MM_R2:
        MOV     AX, BX
        RET

_CLRT_SETHAS:
        CMP     AX, 0
        JE      _CLRT_SH_NO
        PUSH    SI
        PUSH    CX
        MOV     SI, AX
        MOV     CX, WORD PTR [SI]
        ADD     SI, 2
_CLRT_SH_LP:
        CMP     CX, 0
        JE      _CLRT_SH_NF
        CMP     WORD PTR [SI], BX
        JE      _CLRT_SH_FN
        ADD     SI, 2
        DEC     CX
        JMP     _CLRT_SH_LP
_CLRT_SH_FN:
        MOV     AX, 1
        POP     CX
        POP     SI
        RET
_CLRT_SH_NF:
        XOR     AX, AX
        POP     CX
        POP     SI
        RET
_CLRT_SH_NO:
        XOR     AX, AX
        RET

_CLRT_SETCONJ:
        CMP     AX, 0
        JE      _CLRT_SC_NL
        PUSH    SI
        PUSH    DI
        PUSH    DX
        PUSH    CX
        MOV     WORD PTR [_CL_STMP1], BX
        MOV     SI, AX
        MOV     CX, WORD PTR [SI]
        PUSH    CX
        PUSH    SI
        ADD     SI, 2
_CLRT_SC_CK:
        CMP     CX, 0
        JE      _CLRT_SC_NF
        CMP     WORD PTR [SI], BX
        JE      _CLRT_SC_EX
        ADD     SI, 2
        DEC     CX
        JMP     _CLRT_SC_CK
_CLRT_SC_EX:
        POP     SI
        POP     CX
        MOV     DI, WORD PTR [_CL_HEAPTOP]
        MOV     BX, DI
        ADD     BX, OFFSET _CL_HEAP
        MOV     DX, CX
        INC     DX
        SHL     DX, 1
        ADD     DI, DX
        MOV     WORD PTR [_CL_HEAPTOP], DI
        MOV     DI, BX
        SHR     DX, 1
_CLRT_SC_CP:
        CMP     DX, 0
        JE      _CLRT_SC_D2
        MOV     AX, WORD PTR [SI]
        MOV     WORD PTR [DI], AX
        ADD     SI, 2
        ADD     DI, 2
        DEC     DX
        JMP     _CLRT_SC_CP
_CLRT_SC_D2:
        MOV     AX, BX
        POP     CX
        POP     DX
        POP     DI
        POP     SI
        RET
_CLRT_SC_NF:
        POP     SI
        POP     CX
        MOV     DI, WORD PTR [_CL_HEAPTOP]
        MOV     BX, DI
        ADD     BX, OFFSET _CL_HEAP
        MOV     DX, CX
        INC     DX
        MOV     WORD PTR [BX], DX
        MOV     AX, DX
        INC     AX
        SHL     AX, 1
        ADD     DI, AX
        MOV     WORD PTR [_CL_HEAPTOP], DI
        MOV     DI, BX
        ADD     DI, 2
        ADD     SI, 2
_CLRT_SC_C2:
        CMP     CX, 0
        JE      _CLRT_SC_AD
        MOV     AX, WORD PTR [SI]
        MOV     WORD PTR [DI], AX
        ADD     SI, 2
        ADD     DI, 2
        DEC     CX
        JMP     _CLRT_SC_C2
_CLRT_SC_AD:
        MOV     AX, WORD PTR [_CL_STMP1]
        MOV     WORD PTR [DI], AX
        MOV     AX, BX
        POP     CX
        POP     DX
        POP     DI
        POP     SI
        RET
_CLRT_SC_NL:
        PUSH    DI
        MOV     DI, WORD PTR [_CL_HEAPTOP]
        MOV     AX, DI
        ADD     AX, OFFSET _CL_HEAP
        MOV     WORD PTR [AX], 1
        MOV     WORD PTR [AX+2], BX
        ADD     DI, 4
        MOV     WORD PTR [_CL_HEAPTOP], DI
        POP     DI
        RET

_CLRT_SETDISJ:
        CMP     AX, 0
        JE      _CLRT_SD_NL
        PUSH    SI
        PUSH    DI
        PUSH    DX
        PUSH    CX
        MOV     SI, AX
        MOV     CX, WORD PTR [SI]
        MOV     DI, WORD PTR [_CL_HEAPTOP]
        PUSH    BX
        MOV     BX, DI
        ADD     BX, OFFSET _CL_HEAP
        MOV     DX, CX
        DEC     DX
        CMP     DX, 0
        JL      _CLRT_SD_E0
        MOV     WORD PTR [BX], DX
        MOV     AX, DX
        INC     AX
        SHL     AX, 1
        ADD     DI, AX
        MOV     WORD PTR [_CL_HEAPTOP], DI
        ADD     SI, 2
        MOV     DI, BX
        ADD     DI, 2
        POP     AX
_CLRT_SD_LP:
        CMP     CX, 0
        JE      _CLRT_SD_DN
        CMP     WORD PTR [SI], AX
        JE      _CLRT_SD_SP
        PUSH    AX
        MOV     AX, WORD PTR [SI]
        MOV     WORD PTR [DI], AX
        POP     AX
        ADD     DI, 2
_CLRT_SD_SP:
        ADD     SI, 2
        DEC     CX
        JMP     _CLRT_SD_LP
_CLRT_SD_DN:
        MOV     AX, BX
        POP     CX
        POP     DX
        POP     DI
        POP     SI
        RET
_CLRT_SD_E0:
        POP     BX
        XOR     AX, AX
        POP     CX
        POP     DX
        POP     DI
        POP     SI
        RET
_CLRT_SD_NL:
        XOR     AX, AX
        RET

_CLRT_SETUNION:
        CMP     AX, 0
        JE      _CLRT_SU_R2
        CMP     BX, 0
        JE      _CLRT_SU_R1
        PUSH    SI
        PUSH    DI
        PUSH    DX
        PUSH    CX
        MOV     WORD PTR [_CL_STMP1], AX
        MOV     WORD PTR [_CL_STMP2], BX
        MOV     SI, AX
        MOV     CX, WORD PTR [SI]
        MOV     DI, WORD PTR [_CL_HEAPTOP]
        MOV     BX, DI
        ADD     BX, OFFSET _CL_HEAP
        MOV     DX, CX
        INC     DX
        SHL     DX, 1
        ADD     DI, DX
        MOV     WORD PTR [_CL_HEAPTOP], DI
        MOV     DI, BX
        SHR     DX, 1
_CLRT_SU_C1:
        CMP     DX, 0
        JE      _CLRT_SU_P2
        MOV     AX, WORD PTR [SI]
        MOV     WORD PTR [DI], AX
        ADD     SI, 2
        ADD     DI, 2
        DEC     DX
        JMP     _CLRT_SU_C1
_CLRT_SU_P2:
        MOV     SI, WORD PTR [_CL_STMP2]
        MOV     CX, WORD PTR [SI]
        ADD     SI, 2
_CLRT_SU_LP:
        CMP     CX, 0
        JE      _CLRT_SU_DN
        MOV     DX, WORD PTR [SI]
        PUSH    CX
        PUSH    SI
        MOV     AX, BX
        MOV     SI, BX
        MOV     CX, WORD PTR [SI]
        ADD     SI, 2
_CLRT_SU_SR:
        CMP     CX, 0
        JE      _CLRT_SU_AB
        CMP     WORD PTR [SI], DX
        JE      _CLRT_SU_PR
        ADD     SI, 2
        DEC     CX
        JMP     _CLRT_SU_SR
_CLRT_SU_PR:
        POP     SI
        POP     CX
        ADD     SI, 2
        DEC     CX
        JMP     _CLRT_SU_LP
_CLRT_SU_AB:
        POP     SI
        POP     CX
        MOV     DI, WORD PTR [_CL_HEAPTOP]
        PUSH    AX
        MOV     AX, DI
        ADD     AX, OFFSET _CL_HEAP
        MOV     WORD PTR [AX], DX
        ADD     DI, 2
        MOV     WORD PTR [_CL_HEAPTOP], DI
        POP     AX
        INC     WORD PTR [BX]
        ADD     SI, 2
        DEC     CX
        JMP     _CLRT_SU_LP
_CLRT_SU_DN:
        MOV     AX, BX
        POP     CX
        POP     DX
        POP     DI
        POP     SI
        RET
_CLRT_SU_R1:
        RET
_CLRT_SU_R2:
        MOV     AX, BX
        RET

_CLRT_SETINTER:
        CMP     AX, 0
        JE      _CLRT_SI_NL
        CMP     BX, 0
        JE      _CLRT_SI_NL
        PUSH    SI
        PUSH    DI
        PUSH    DX
        PUSH    CX
        MOV     WORD PTR [_CL_STMP2], BX
        MOV     DI, WORD PTR [_CL_HEAPTOP]
        MOV     BX, DI
        ADD     BX, OFFSET _CL_HEAP
        MOV     WORD PTR [BX], 0
        ADD     DI, 2
        MOV     WORD PTR [_CL_HEAPTOP], DI
        MOV     SI, AX
        MOV     CX, WORD PTR [SI]
        ADD     SI, 2
_CLRT_SI_LP:
        CMP     CX, 0
        JE      _CLRT_SI_DN
        MOV     DX, WORD PTR [SI]
        PUSH    CX
        PUSH    SI
        MOV     SI, WORD PTR [_CL_STMP2]
        MOV     CX, WORD PTR [SI]
        ADD     SI, 2
_CLRT_SI_SR:
        CMP     CX, 0
        JE      _CLRT_SI_NP
        CMP     WORD PTR [SI], DX
        JE      _CLRT_SI_FD
        ADD     SI, 2
        DEC     CX
        JMP     _CLRT_SI_SR
_CLRT_SI_FD:
        POP     SI
        POP     CX
        MOV     DI, WORD PTR [_CL_HEAPTOP]
        PUSH    AX
        MOV     AX, DI
        ADD     AX, OFFSET _CL_HEAP
        MOV     WORD PTR [AX], DX
        ADD     DI, 2
        MOV     WORD PTR [_CL_HEAPTOP], DI
        POP     AX
        INC     WORD PTR [BX]
        ADD     SI, 2
        DEC     CX
        JMP     _CLRT_SI_LP
_CLRT_SI_NP:
        POP     SI
        POP     CX
        ADD     SI, 2
        DEC     CX
        JMP     _CLRT_SI_LP
_CLRT_SI_DN:
        MOV     AX, BX
        POP     CX
        POP     DX
        POP     DI
        POP     SI
        RET
_CLRT_SI_NL:
        XOR     AX, AX
        RET

_CLRT_SETDIFF:
        CMP     AX, 0
        JE      _CLRT_SF_NL
        CMP     BX, 0
        JE      _CLRT_SF_R1
        PUSH    SI
        PUSH    DI
        PUSH    DX
        PUSH    CX
        MOV     WORD PTR [_CL_STMP2], BX
        MOV     DI, WORD PTR [_CL_HEAPTOP]
        MOV     BX, DI
        ADD     BX, OFFSET _CL_HEAP
        MOV     WORD PTR [BX], 0
        ADD     DI, 2
        MOV     WORD PTR [_CL_HEAPTOP], DI
        MOV     SI, AX
        MOV     CX, WORD PTR [SI]
        ADD     SI, 2
_CLRT_SF_LP:
        CMP     CX, 0
        JE      _CLRT_SF_DN
        MOV     DX, WORD PTR [SI]
        PUSH    CX
        PUSH    SI
        MOV     SI, WORD PTR [_CL_STMP2]
        MOV     CX, WORD PTR [SI]
        ADD     SI, 2
_CLRT_SF_SR:
        CMP     CX, 0
        JE      _CLRT_SF_AB
        CMP     WORD PTR [SI], DX
        JE      _CLRT_SF_PR
        ADD     SI, 2
        DEC     CX
        JMP     _CLRT_SF_SR
_CLRT_SF_PR:
        POP     SI
        POP     CX
        ADD     SI, 2
        DEC     CX
        JMP     _CLRT_SF_LP
_CLRT_SF_AB:
        POP     SI
        POP     CX
        MOV     DI, WORD PTR [_CL_HEAPTOP]
        PUSH    AX
        MOV     AX, DI
        ADD     AX, OFFSET _CL_HEAP
        MOV     WORD PTR [AX], DX
        ADD     DI, 2
        MOV     WORD PTR [_CL_HEAPTOP], DI
        POP     AX
        INC     WORD PTR [BX]
        ADD     SI, 2
        DEC     CX
        JMP     _CLRT_SF_LP
_CLRT_SF_DN:
        MOV     AX, BX
        POP     CX
        POP     DX
        POP     DI
        POP     SI
        RET
_CLRT_SF_NL:
        XOR     AX, AX
        RET
_CLRT_SF_R1:
        RET

_CLRT_VECDROP:
        CMP     AX, 0
        JE      _CLRT_VD_NL
        PUSH    SI
        PUSH    DI
        PUSH    CX
        PUSH    DX
        MOV     SI, AX
        MOV     CX, WORD PTR [SI]
        CMP     BX, CX
        JAE     _CLRT_VD_EM
        SUB     CX, BX
        MOV     DI, WORD PTR [_CL_HEAPTOP]
        MOV     DX, DI
        ADD     DX, OFFSET _CL_HEAP
        MOV     WORD PTR [DX], CX
        MOV     AX, CX
        INC     AX
        SHL     AX, 1
        ADD     DI, AX
        MOV     WORD PTR [_CL_HEAPTOP], DI
        SHL     BX, 1
        ADD     BX, 2
        ADD     SI, BX
        MOV     DI, DX
        ADD     DI, 2
_CLRT_VD_LP:
        CMP     CX, 0
        JE      _CLRT_VD_DN
        MOV     AX, WORD PTR [SI]
        MOV     WORD PTR [DI], AX
        ADD     SI, 2
        ADD     DI, 2
        DEC     CX
        JMP     _CLRT_VD_LP
_CLRT_VD_DN:
        MOV     AX, DX
        POP     DX
        POP     CX
        POP     DI
        POP     SI
        RET
_CLRT_VD_EM:
        MOV     DI, WORD PTR [_CL_HEAPTOP]
        MOV     DX, DI
        ADD     DX, OFFSET _CL_HEAP
        MOV     WORD PTR [DX], 0
        ADD     DI, 2
        MOV     WORD PTR [_CL_HEAPTOP], DI
        MOV     AX, DX
        POP     DX
        POP     CX
        POP     DI
        POP     SI
        RET
_CLRT_VD_NL:
        XOR     AX, AX
        RET

_CLRT_LREV:
        PUSH    SI
        PUSH    BX
        MOV     SI, AX
        XOR     BX, BX
_CLRT_LR_LP:
        CMP     SI, 0
        JE      _CLRT_LR_DN
        MOV     AX, WORD PTR [SI]
        CALL    _CLRT_CONS
        MOV     BX, AX
        MOV     SI, WORD PTR [SI+2]
        JMP     _CLRT_LR_LP
_CLRT_LR_DN:
        MOV     AX, BX
        POP     BX
        POP     SI
        RET

_CLRT_SUBS:
        PUSH    DI
        PUSH    DX
        MOV     DI, OFFSET _CL_STRBUF2
        ADD     SI, BX
        XOR     DX, DX
        ADD     DX, BX
_CLRT_SB_LP:
        CMP     BYTE PTR [SI], 0
        JE      _CLRT_SB_DN
        CMP     DX, CX
        JAE     _CLRT_SB_DN
        MOV     AL, [SI]
        MOV     [DI], AL
        INC     SI
        INC     DI
        INC     DX
        JMP     _CLRT_SB_LP
_CLRT_SB_DN:
        MOV     BYTE PTR [DI], 0
        MOV     AX, OFFSET _CL_STRBUF2
        POP     DX
        POP     DI
        RET

_CLRT_STRUPPER:
        PUSH    SI
        PUSH    DI
        MOV     DI, OFFSET _CL_STRBUF2
_CLRT_SU_LP:
        MOV     AL, [SI]
        TEST    AL, AL
        JZ      _CLRT_SU_DN
        CMP     AL, 97
        JB      _CLRT_SU_SK
        CMP     AL, 122
        JA      _CLRT_SU_SK
        SUB     AL, 32
_CLRT_SU_SK:
        MOV     [DI], AL
        INC     SI
        INC     DI
        JMP     _CLRT_SU_LP
_CLRT_SU_DN:
        MOV     BYTE PTR [DI], 0
        MOV     AX, OFFSET _CL_STRBUF2
        POP     DI
        POP     SI
        RET

_CLRT_STRLOWER:
        PUSH    SI
        PUSH    DI
        MOV     DI, OFFSET _CL_STRBUF2
_CLRT_SL2_LP:
        MOV     AL, [SI]
        TEST    AL, AL
        JZ      _CLRT_SL2_DN
        CMP     AL, 65
        JB      _CLRT_SL2_SK
        CMP     AL, 90
        JA      _CLRT_SL2_SK
        ADD     AL, 32
_CLRT_SL2_SK:
        MOV     [DI], AL
        INC     SI
        INC     DI
        JMP     _CLRT_SL2_LP
_CLRT_SL2_DN:
        MOV     BYTE PTR [DI], 0
        MOV     AX, OFFSET _CL_STRBUF2
        POP     DI
        POP     SI
        RET

_CLRT_STRTRIM:
        PUSH    SI
        PUSH    DI
        PUSH    CX
_CLRT_ST_LS:
        CMP     BYTE PTR [SI], 32
        JE      _CLRT_ST_LS2
        CMP     BYTE PTR [SI], 9
        JE      _CLRT_ST_LS2
        JMP     _CLRT_ST_CP
_CLRT_ST_LS2:
        INC     SI
        JMP     _CLRT_ST_LS
_CLRT_ST_CP:
        MOV     DI, OFFSET _CL_STRBUF2
        XOR     CX, CX
_CLRT_ST_CL:
        MOV     AL, [SI]
        MOV     [DI], AL
        TEST    AL, AL
        JZ      _CLRT_ST_TR
        INC     SI
        INC     DI
        INC     CX
        JMP     _CLRT_ST_CL
_CLRT_ST_TR:
        TEST    CX, CX
        JZ      _CLRT_ST_DN
        DEC     DI
        CMP     BYTE PTR [DI], 32
        JE      _CLRT_ST_T2
        CMP     BYTE PTR [DI], 9
        JE      _CLRT_ST_T2
        INC     DI
        MOV     BYTE PTR [DI], 0
        JMP     _CLRT_ST_DN
_CLRT_ST_T2:
        MOV     BYTE PTR [DI], 0
        DEC     CX
        JMP     _CLRT_ST_TR
_CLRT_ST_DN:
        MOV     AX, OFFSET _CL_STRBUF2
        POP     CX
        POP     DI
        POP     SI
        RET

_CLRT_STRFIND:
        PUSH    SI
        PUSH    DI
        PUSH    BX
        PUSH    CX
        MOV     BX, DI
_CLRT_SF_OL:
        CMP     BYTE PTR [SI], 0
        JE      _CLRT_SF_NF
        MOV     DI, BX
        MOV     CX, SI
_CLRT_SF_IL:
        CMP     BYTE PTR [DI], 0
        JE      _CLRT_SF_FD
        CMP     BYTE PTR [CX], 0
        JE      _CLRT_SF_NF
        MOV     AL, [CX]
        CMP     AL, [DI]
        JNE     _CLRT_SF_NX
        INC     CX
        INC     DI
        JMP     _CLRT_SF_IL
_CLRT_SF_NX:
        INC     SI
        JMP     _CLRT_SF_OL
_CLRT_SF_FD:
        MOV     AX, 1
        JMP     _CLRT_SF_EX
_CLRT_SF_NF:
        XOR     AX, AX
_CLRT_SF_EX:
        POP     CX
        POP     BX
        POP     DI
        POP     SI
        RET

_CLRT_STRREPL:
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    SI
        PUSH    DI
        MOV     WORD PTR [_CL_SCTMP1], DI
        XOR     CX, CX
_CLRT_SR_ML:
        CMP     BYTE PTR [DI], 0
        JE      _CLRT_SR_MS
        INC     DI
        INC     CX
        JMP     _CLRT_SR_ML
_CLRT_SR_MS:
        MOV     WORD PTR [_CL_SCTMP2], CX
        MOV     BX, OFFSET _CL_STRBUF2
_CLRT_SR_OL:
        CMP     BYTE PTR [SI], 0
        JE      _CLRT_SR_DN
        MOV     DI, WORD PTR [_CL_SCTMP1]
        MOV     DX, SI
_CLRT_SR_CK:
        CMP     BYTE PTR [DI], 0
        JE      _CLRT_SR_MT
        CMP     BYTE PTR [DX], 0
        JE      _CLRT_SR_NM
        MOV     AL, [DX]
        CMP     AL, [DI]
        JNE     _CLRT_SR_NM
        INC     DX
        INC     DI
        JMP     _CLRT_SR_CK
_CLRT_SR_MT:
        MOV     DI, WORD PTR [_CL_SCTMP3]
_CLRT_SR_CR:
        CMP     BYTE PTR [DI], 0
        JE      _CLRT_SR_CA
        MOV     AL, [DI]
        MOV     [BX], AL
        INC     BX
        INC     DI
        JMP     _CLRT_SR_CR
_CLRT_SR_CA:
        ADD     SI, WORD PTR [_CL_SCTMP2]
        JMP     _CLRT_SR_OL
_CLRT_SR_NM:
        MOV     AL, [SI]
        MOV     [BX], AL
        INC     BX
        INC     SI
        JMP     _CLRT_SR_OL
_CLRT_SR_DN:
        MOV     BYTE PTR [BX], 0
        MOV     AX, OFFSET _CL_STRBUF2
        POP     DI
        POP     SI
        POP     DX
        POP     CX
        POP     BX
        RET

_CLRT_STRSPLIT:
        PUSH    CX
        PUSH    DI
        PUSH    DX
        MOV     WORD PTR [_CL_SCTMP1], BX
        XOR     DX, DX
_CLRT_SS_OL:
        CMP     BYTE PTR [SI], 0
        JE      _CLRT_SS_DN
        MOV     DI, WORD PTR [_CL_HEAPTOP]
        MOV     CX, DI
        ADD     CX, OFFSET _CL_HEAP
        PUSH    CX
_CLRT_SS_IL:
        MOV     AL, [SI]
        TEST    AL, AL
        JZ      _CLRT_SS_ES
        CMP     AL, BYTE PTR [_CL_SCTMP1]
        JE      _CLRT_SS_ES
        MOV     BYTE PTR [CX], AL
        INC     SI
        INC     CX
        INC     DI
        JMP     _CLRT_SS_IL
_CLRT_SS_ES:
        MOV     BYTE PTR [CX], 0
        INC     DI
        MOV     WORD PTR [_CL_HEAPTOP], DI
        CMP     BYTE PTR [SI], 0
        JE      _CLRT_SS_NC
        INC     SI
_CLRT_SS_NC:
        POP     AX
        MOV     BX, DX
        CALL    _CLRT_CONS
        MOV     DX, AX
        MOV     BX, WORD PTR [_CL_SCTMP1]
        JMP     _CLRT_SS_OL
_CLRT_SS_DN:
        MOV     AX, DX
        CALL    _CLRT_LREV
        POP     DX
        POP     DI
        POP     CX
        RET

_CLRT_STRJOIN:
        PUSH    CX
        PUSH    DI
        PUSH    DX
        MOV     WORD PTR [_CL_SCTMP1], SI
        MOV     DI, OFFSET _CL_STRBUF2
        MOV     BYTE PTR [DI], 0
        XOR     CX, CX
_CLRT_SJ_LP:
        CMP     BX, 0
        JE      _CLRT_SJ_DN
        TEST    CX, CX
        JZ      _CLRT_SJ_NS
        MOV     SI, WORD PTR [_CL_SCTMP1]
_CLRT_SJ_CS:
        MOV     AL, [SI]
        TEST    AL, AL
        JZ      _CLRT_SJ_NS
        MOV     [DI], AL
        INC     DI
        INC     SI
        JMP     _CLRT_SJ_CS
_CLRT_SJ_NS:
        PUSH    BX
        MOV     SI, WORD PTR [BX]
_CLRT_SJ_CE:
        MOV     AL, [SI]
        TEST    AL, AL
        JZ      _CLRT_SJ_NX
        MOV     [DI], AL
        INC     DI
        INC     SI
        JMP     _CLRT_SJ_CE
_CLRT_SJ_NX:
        POP     BX
        MOV     BX, WORD PTR [BX+2]
        INC     CX
        JMP     _CLRT_SJ_LP
_CLRT_SJ_DN:
        MOV     BYTE PTR [DI], 0
        MOV     AX, OFFSET _CL_STRBUF2
        POP     DX
        POP     DI
        POP     CX
        RET

; === FIN RUNTIME ===


; --- sortie DOS ---
        MOV AX,4C00h
        INT 21h


_TEXT   ENDS

_DATA   SEGMENT PUBLIC 'DATA'

_CL_NIL  DB 'nil',0
_CL_TRUE  DB 'true',0
_CL_FALSE  DB 'false',0
_CL_CRLF    DB 13,10,0
_CL_STRBUF  DB 256 DUP(0)
_CL_HEAP    DB 4096 DUP(0)
_CL_HEAPTOP DW 0
_CL_VTMP1   DW 0
_CL_VTMP2   DW 0
_CL_MTMP1   DW 0
_CL_MTMP2   DW 0
_CL_STMP1   DW 0
_CL_STMP2   DW 0
_CL_HFTMP1  DW 0
_CL_HFTMP2  DW 0
_CL_HFTMP3  DW 0
_CL_SCTMP1  DW 0
_CL_SCTMP2  DW 0
_CL_SCTMP3  DW 0
_CL_STRBUF2 DB 256 DUP(0)

_CL_NIL_S  DB 'nil',0
_CL_TRUE_S  DB 'true',0
_CL_FALSE_S  DB 'false',0
_CL_EMPTY_S  DB 0
_CL_SPACE_S  DB ' ',0
_CL_NL_S  DB 13,10,0
_CL_TMPBUF  DB 256 DUP(0)
_CL_NUMBUF  DB 12 DUP(0)
_CL_INBUF  DB 130 DUP(0)
_CL_SPACE  DB ' ',0

_DATA   ENDS

        END _CLF_main
