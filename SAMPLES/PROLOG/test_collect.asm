; Genere par PROLOG86 v1.0 - SAMPLES/PROLOG/test_collect.pl
; Date: 2026-03-06

        .MODEL SMALL
        .STACK 2048

_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME  CS:_TEXT, DS:_DATA, SS:STACK

; --- Point d entree ---
_PLP_Main:
        MOV   AX, _DATA
        MOV   DS, AX


; =======================================
;   Clauses compilees (TODO 10 + 11 + 12 + 13 + 14 + 15)
; =======================================

; --- Regle succeed/0 clause 0 (1 but(s), 0 var(s)) ---
_PLP_succeed_0_0:
        PUSH   BP
        MOV   BP, SP
; --- corps de la regle ---

; but 1/1: true/0
; true/0 inline - noop
        CLC
        MOV   SP, BP
        POP   BP
        RET

_PLP_succeed_0_0_F:
        STC
        MOV   SP, BP
        POP   BP
        RET

; --- Regle test_findall/0 clause 0 (4 but(s), 1 var(s)) ---
_PLP_test_findall_0_0:
        PUSH   BP
        MOV   BP, SP
; allocate 1 variable(s) locale(s)
        SUB   SP, 2
; init vars locales a REF libre
        MOV   AX, WORD PTR [_PL_HTOP]
        MOV   SI, AX
        SHL   SI, 1
        ADD   SI, OFFSET _PL_HEAP
        MOV   WORD PTR [SI], AX
        INC    WORD PTR [_PL_HTOP]
        MOV   WORD PTR [BP-2], AX
; --- corps de la regle ---

; but 1/4: findall/3
; findall/3 inline (TODO 20)
        CALL    _PLRT_COLLECT_RESET
        PUSH   WORD PTR [_PL_HTOP]
        PUSH   WORD PTR [_PL_TTOP]
        PUSH   WORD PTR [_PL_CPTOP]
        CALL   _PLP_succeed_0
        JC   _PL_L_1
        MOV   AX, 8200
; atom a
        CALL    _PLRT_COLLECT_PUSH
_PL_L_1:
        POP   WORD PTR [_PL_CPTOP]
        POP   WORD PTR [_PL_TTOP]
        POP   WORD PTR [_PL_HTOP]
        CALL    _PLRT_UNTRAIL
        CALL    _PLRT_MAKELIST
        MOV   BX, AX
        MOV   AX, WORD PTR [BP-2]
        CALL    _PLRT_BIND
; findall/3 done

; but 2/4: write/1
; write/1 inline
        MOV   AX, 8202
        CALL    _PLRT_WRITE_TERM
; write/1 done

; but 3/4: write/1
; write/1 inline
        MOV   AX, WORD PTR [BP-2]
        CALL    _PLRT_DEREF
        CALL    _PLRT_WRITE_TERM
; write/1 done

; but 4/4: nl/0
; nl/0 inline
        CALL    _PLRT_NL
        CLC
        MOV   SP, BP
        POP   BP
        RET

_PLP_test_findall_0_0_F:
        STC
        MOV   SP, BP
        POP   BP
        RET

; --- Regle test_findall_empty/0 clause 0 (4 but(s), 1 var(s)) ---
_PLP_test_findall_empty_0_0:
        PUSH   BP
        MOV   BP, SP
; allocate 1 variable(s) locale(s)
        SUB   SP, 2
; init vars locales a REF libre
        MOV   AX, WORD PTR [_PL_HTOP]
        MOV   SI, AX
        SHL   SI, 1
        ADD   SI, OFFSET _PL_HEAP
        MOV   WORD PTR [SI], AX
        INC    WORD PTR [_PL_HTOP]
        MOV   WORD PTR [BP-2], AX
; --- corps de la regle ---

; but 1/4: findall/3
; findall/3 inline (TODO 20)
        CALL    _PLRT_COLLECT_RESET
        PUSH   WORD PTR [_PL_HTOP]
        PUSH   WORD PTR [_PL_TTOP]
        PUSH   WORD PTR [_PL_CPTOP]
        CALL   _PLP_fail_0
        JC   _PL_L_2
        MOV   AX, 8200
; atom a
        CALL    _PLRT_COLLECT_PUSH
_PL_L_2:
        POP   WORD PTR [_PL_CPTOP]
        POP   WORD PTR [_PL_TTOP]
        POP   WORD PTR [_PL_HTOP]
        CALL    _PLRT_UNTRAIL
        CALL    _PLRT_MAKELIST
        MOV   BX, AX
        MOV   AX, WORD PTR [BP-2]
        CALL    _PLRT_BIND
; findall/3 done

; but 2/4: write/1
; write/1 inline
        MOV   AX, 8203
        CALL    _PLRT_WRITE_TERM
; write/1 done

; but 3/4: write/1
; write/1 inline
        MOV   AX, WORD PTR [BP-2]
        CALL    _PLRT_DEREF
        CALL    _PLRT_WRITE_TERM
; write/1 done

; but 4/4: nl/0
; nl/0 inline
        CALL    _PLRT_NL
        CLC
        MOV   SP, BP
        POP   BP
        RET

_PLP_test_findall_empty_0_0_F:
        STC
        MOV   SP, BP
        POP   BP
        RET

; --- Regle test_bagof/0 clause 0 (4 but(s), 1 var(s)) ---
_PLP_test_bagof_0_0:
        PUSH   BP
        MOV   BP, SP
; allocate 1 variable(s) locale(s)
        SUB   SP, 2
; init vars locales a REF libre
        MOV   AX, WORD PTR [_PL_HTOP]
        MOV   SI, AX
        SHL   SI, 1
        ADD   SI, OFFSET _PL_HEAP
        MOV   WORD PTR [SI], AX
        INC    WORD PTR [_PL_HTOP]
        MOV   WORD PTR [BP-2], AX
; --- corps de la regle ---

; but 1/4: bagof/3
; bagof/3 inline (TODO 20)
        CALL    _PLRT_COLLECT_RESET
        PUSH   WORD PTR [_PL_HTOP]
        PUSH   WORD PTR [_PL_TTOP]
        PUSH   WORD PTR [_PL_CPTOP]
        CALL   _PLP_succeed_0
        JC   _PL_L_3
        MOV   AX, 8200
; atom a
        CALL    _PLRT_COLLECT_PUSH
_PL_L_3:
        POP   WORD PTR [_PL_CPTOP]
        POP   WORD PTR [_PL_TTOP]
        POP   WORD PTR [_PL_HTOP]
        CALL    _PLRT_UNTRAIL
        CALL    _PLRT_MAKELIST
        CMP   AX, 8193
; compare with [] (nil)
        JE   _PLP_test_bagof_0_0_F
        MOV   BX, AX
        MOV   AX, WORD PTR [BP-2]
        CALL    _PLRT_BIND
; bagof/3 done

; but 2/4: write/1
; write/1 inline
        MOV   AX, 8204
        CALL    _PLRT_WRITE_TERM
; write/1 done

; but 3/4: write/1
; write/1 inline
        MOV   AX, WORD PTR [BP-2]
        CALL    _PLRT_DEREF
        CALL    _PLRT_WRITE_TERM
; write/1 done

; but 4/4: nl/0
; nl/0 inline
        CALL    _PLRT_NL
        CLC
        MOV   SP, BP
        POP   BP
        RET

_PLP_test_bagof_0_0_F:
        STC
        MOV   SP, BP
        POP   BP
        RET

; --- Regle test_setof/0 clause 0 (4 but(s), 1 var(s)) ---
_PLP_test_setof_0_0:
        PUSH   BP
        MOV   BP, SP
; allocate 1 variable(s) locale(s)
        SUB   SP, 2
; init vars locales a REF libre
        MOV   AX, WORD PTR [_PL_HTOP]
        MOV   SI, AX
        SHL   SI, 1
        ADD   SI, OFFSET _PL_HEAP
        MOV   WORD PTR [SI], AX
        INC    WORD PTR [_PL_HTOP]
        MOV   WORD PTR [BP-2], AX
; --- corps de la regle ---

; but 1/4: setof/3
; setof/3 inline (TODO 20)
        CALL    _PLRT_COLLECT_RESET
        PUSH   WORD PTR [_PL_HTOP]
        PUSH   WORD PTR [_PL_TTOP]
        PUSH   WORD PTR [_PL_CPTOP]
        CALL   _PLP_succeed_0
        JC   _PL_L_5
        MOV   AX, 8200
; atom a
        CALL    _PLRT_COLLECT_PUSH
_PL_L_5:
        POP   WORD PTR [_PL_CPTOP]
        POP   WORD PTR [_PL_TTOP]
        POP   WORD PTR [_PL_HTOP]
        CALL    _PLRT_UNTRAIL
        CALL    _PLRT_MAKELIST
        CMP   AX, 8193
; compare with [] (nil)
        JE   _PLP_test_setof_0_0_F
        CALL    _PLRT_SORT
        CALL    _PLRT_SETOF_DEDUP
        MOV   BX, AX
        MOV   AX, WORD PTR [BP-2]
        CALL    _PLRT_BIND
; setof/3 done

; but 2/4: write/1
; write/1 inline
        MOV   AX, 8205
        CALL    _PLRT_WRITE_TERM
; write/1 done

; but 3/4: write/1
; write/1 inline
        MOV   AX, WORD PTR [BP-2]
        CALL    _PLRT_DEREF
        CALL    _PLRT_WRITE_TERM
; write/1 done

; but 4/4: nl/0
; nl/0 inline
        CALL    _PLRT_NL
        CLC
        MOV   SP, BP
        POP   BP
        RET

_PLP_test_setof_0_0_F:
        STC
        MOV   SP, BP
        POP   BP
        RET

; =======================================
;   Points d entree des predicats
; =======================================

; === Predicat succeed/0 (1 clause(s)) ===

; === Predicat test_findall/0 (1 clause(s)) ===

; === Predicat test_findall_empty/0 (1 clause(s)) ===

; === Predicat test_bagof/0 (1 clause(s)) ===

; === Predicat test_setof/0 (1 clause(s)) ===

; --- Fin du code genere ---

        MOV   AX, 4C00h
        INT   21h


; =======================================
;   Routines de backtracking (TODO 12)
; =======================================

_PLRT_UNTRAIL:
        PUSH   SI
        PUSH   AX
_PLRT_UNTR_LP:
        MOV   AX, WORD PTR [_PL_TTOP]
        CMP   AX, CX
        JLE   _PLRT_UNTR_DONE
        DEC    AX
        MOV   WORD PTR [_PL_TTOP], AX
        MOV   SI, AX
        SHL    SI,1
        MOV   AX, WORD PTR [_PL_TRAIL + SI]
        MOV   SI, AX
        SHL    SI,1
        MOV   WORD PTR [_PL_HEAP + SI], AX
        JMP   _PLRT_UNTR_LP
_PLRT_UNTR_DONE:
        POP   AX
        POP   SI
        RET

_PLRT_TRY:
        PUSH   SI
        PUSH   AX
        MOV   SI, WORD PTR [_PL_CPTOP]
        SHL    SI,1
        MOV   AX, WORD PTR [_PL_CPTOP]
        MOV   WORD PTR [_PL_STACK + SI], AX
        ADD   SI, 2
        MOV   AX, WORD PTR [_PL_TTOP]
        MOV   WORD PTR [_PL_STACK + SI], AX
        ADD   SI, 2
        MOV   AX, WORD PTR [_PL_HTOP]
        MOV   WORD PTR [_PL_STACK + SI], AX
        ADD   SI, 2
        MOV   WORD PTR [_PL_STACK + SI], BX
        ADD   SI, 2
        SHR    SI,1
        MOV   WORD PTR [_PL_CPTOP], SI
        CLC
        POP   AX
        POP   SI
        RET

_PLRT_RETRY:
        PUSH   SI
        PUSH   AX
        PUSH   CX
        MOV   SI, WORD PTR [_PL_CPTOP]
        SUB   SI, 4
        SHL    SI,1
        MOV   CX, WORD PTR [_PL_STACK + SI + 2]
        CALL    _PLRT_UNTRAIL
        MOV   WORD PTR [_PL_TTOP], CX
        MOV   AX, WORD PTR [_PL_STACK + SI + 4]
        MOV   WORD PTR [_PL_HTOP], AX
        MOV   WORD PTR [_PL_STACK + SI + 6], BX
        CLC
        POP   CX
        POP   AX
        POP   SI
        RET

_PLRT_TRUST:
        PUSH   SI
        PUSH   AX
        PUSH   CX
        MOV   SI, WORD PTR [_PL_CPTOP]
        SUB   SI, 4
        SHL    SI,1
        MOV   CX, WORD PTR [_PL_STACK + SI + 2]
        CALL    _PLRT_UNTRAIL
        MOV   WORD PTR [_PL_TTOP], CX
        MOV   AX, WORD PTR [_PL_STACK + SI + 4]
        MOV   WORD PTR [_PL_HTOP], AX
        MOV   AX, WORD PTR [_PL_STACK + SI]
        MOV   WORD PTR [_PL_CPTOP], AX
        CLC
        POP   CX
        POP   AX
        POP   SI
        RET


; =======================================
;   Routines de liste (TODO 13)
; =======================================

_PLRT_PUTLIST:
        PUSH   SI
        MOV   SI, WORD PTR [_PL_HTOP]
        PUSH   SI
        SHL    SI,1
        ADD   SI, OFFSET _PL_HEAP
        MOV   WORD PTR [SI], AX
        MOV   WORD PTR [SI+2], BX
        POP   AX
        OR   AX, 32768
        ADD    WORD PTR [_PL_HTOP],2
        POP   SI
        RET

_PLRT_GETLIST:
        PUSH   SI
        PUSH   AX
        MOV   BX, AX
        AND   BX, 57344
        CMP   BX, 32768
        JNE   _PLRT_GETL_FAIL
        AND   AX, 8191
        MOV   SI, AX
        SHL    SI,1
        ADD   SI, OFFSET _PL_HEAP
        MOV   BX, WORD PTR [SI]
        MOV   CX, WORD PTR [SI+2]
        POP   AX
        POP   SI
        CLC
        RET
_PLRT_GETL_FAIL:
        POP   AX
        POP   SI
        STC
        RET

_PLRT_LENGTH:
        PUSH   SI
        PUSH   BX
        PUSH   CX
        XOR   CX, CX
_PLRT_LEN_LP:
        MOV   BX, AX
        AND   BX, 57344
        CMP   BX, 32768
        JNE   _PLRT_LEN_DONE
        AND   AX, 8191
        MOV   SI, AX
        SHL    SI,1
        ADD   SI, OFFSET _PL_HEAP
        MOV   AX, WORD PTR [SI+2]
        INC    CX
        JMP   _PLRT_LEN_LP
_PLRT_LEN_DONE:
        MOV   AX, CX
        AND   AX, 8191
        OR   AX, 16384
        POP   CX
        POP   BX
        POP   SI
        RET

_PLRT_MEMBER:
        PUSH   SI
        PUSH   DX
        MOV   DX, AX
_PLRT_MEM_LP:
        MOV   AX, BX
        AND   AX, 57344
        CMP   AX, 32768
        JNE   _PLRT_MEM_FAIL
        MOV   AX, BX
        AND   AX, 8191
        MOV   SI, AX
        SHL    SI,1
        ADD   SI, OFFSET _PL_HEAP
        CMP   DX, WORD PTR [SI]
        JE   _PLRT_MEM_OK
        MOV   BX, WORD PTR [SI+2]
        JMP   _PLRT_MEM_LP
_PLRT_MEM_OK:
        POP   DX
        POP   SI
        CLC
        RET
_PLRT_MEM_FAIL:
        POP   DX
        POP   SI
        STC
        RET

_PLRT_APPEND:
        PUSH   SI
        PUSH   DX
        PUSH   CX
        MOV   CX, AX
        AND   CX, 57344
        CMP   CX, 32768
        JNE   _PLRT_APP_L1EMPTY
        MOV   DX, AX
        AND   DX, 8191
        MOV   SI, DX
        SHL    SI,1
        ADD   SI, OFFSET _PL_HEAP
        PUSH   BX
        PUSH   WORD PTR [SI]
        MOV   AX, WORD PTR [SI+2]
        CALL    _PLRT_APPEND
        MOV   BX, AX
        POP   AX
        ADD   SP, 2
        CALL    _PLRT_PUTLIST
        POP   CX
        POP   DX
        POP   SI
        RET
_PLRT_APP_L1EMPTY:
        MOV   AX, BX
        POP   CX
        POP   DX
        POP   SI
        RET

_PLRT_NTH:
        PUSH   SI
        PUSH   CX
        MOV   CX, AX
_PLRT_NTH_LP:
        MOV   AX, BX
        AND   AX, 57344
        CMP   AX, 32768
        JNE   _PLRT_NTH_FAIL
        MOV   AX, BX
        AND   AX, 8191
        MOV   SI, AX
        SHL    SI,1
        ADD   SI, OFFSET _PL_HEAP
        CMP   CX, 0
        JE   _PLRT_NTH_FOUND
        DEC    CX
        MOV   BX, WORD PTR [SI+2]
        JMP   _PLRT_NTH_LP
_PLRT_NTH_FOUND:
        MOV   AX, WORD PTR [SI]
        POP   CX
        POP   SI
        CLC
        RET
_PLRT_NTH_FAIL:
        POP   CX
        POP   SI
        STC
        RET

_PLRT_LAST:
        PUSH   SI
        PUSH   BX
_PLRT_LAST_LP:
        MOV   BX, AX
        AND   BX, 57344
        CMP   BX, 32768
        JNE   _PLRT_LAST_FAIL
        AND   AX, 8191
        MOV   SI, AX
        SHL    SI,1
        ADD   SI, OFFSET _PL_HEAP
        MOV   BX, WORD PTR [SI+2]
        MOV   AX, BX
        AND   AX, 57344
        CMP   AX, 32768
        JNE   _PLRT_LAST_GOT
        MOV   AX, BX
        JMP   _PLRT_LAST_LP
_PLRT_LAST_GOT:
        MOV   AX, WORD PTR [SI]
        POP   BX
        POP   SI
        CLC
        RET
_PLRT_LAST_FAIL:
        POP   BX
        POP   SI
        STC
        RET


; =======================================
;   Routines arithmetiques (TODO 14)
; =======================================

_PLRT_DEREF_INT:
        PUSH   BX
        MOV   BX, AX
        AND   BX, 57344
        CMP   BX, 16384
        JNE   _PLRT_DI_FAIL
        AND   AX, 8191
        TEST   AX, 1000h
        JZ   _PLRT_DI_POS
        OR   AX, 0E000h
_PLRT_DI_POS:
        CLC
        POP   BX
        RET
_PLRT_DI_FAIL:
        STC
        POP   BX
        RET

_PLRT_MKINT:
        AND   AX, 8191
        OR   AX, 16384
        RET

_PLRT_ABS:
        TEST   AX, AX
        JNS   _PLRT_ABS_OK
        NEG    AX
_PLRT_ABS_OK:
        RET

_PLRT_SIGN:
        CMP   AX, 0
        JL   _PLRT_SIGN_N
        JG   _PLRT_SIGN_P
        MOV   AX, 0
        RET
_PLRT_SIGN_N:
        MOV   AX, -1
        RET
_PLRT_SIGN_P:
        MOV   AX, 1
        RET

_PLRT_MSB:
        PUSH   CX
        MOV   CX, 15
_PLRT_MSB_LP:
        TEST   AX, 8000h
        JNZ   _PLRT_MSB_FOUND
        SHL    AX,1
        DEC    CX
        JNS   _PLRT_MSB_LP
        MOV   AX, -1
        POP   CX
        RET
_PLRT_MSB_FOUND:
        MOV   AX, CX
        POP   CX
        RET


; ========================================
;  Runtime : Comparaison et tests (TODO 15)
; ========================================

; _PLRT_TAG_OF : AX=terme -> AX=tag (0..4)
_PLRT_TAG_OF:
        AND   AX, 57344
        MOV   CL, 13
        SHR   AX, CL
        RET

; _PLRT_STRUCT_EQ : AX=term1, BX=term2
; CF=0 si egaux structurellement, CF=1 sinon
_PLRT_STRUCT_EQ:
        PUSH   DX
        PUSH   SI
        PUSH   DI
        CALL    _PLRT_DEREF
        MOV   DX, AX
        MOV   AX, BX
        CALL    _PLRT_DEREF
        MOV   BX, AX
        MOV   AX, DX
        CMP   AX, BX
        JE   _PL_L_6
        MOV   DX, AX
        AND   DX, 57344
        MOV   SI, BX
        AND   SI, 57344
        CMP   DX, SI
        JNE   _PL_L_7
        CMP   DX, 32768
        JE   _PL_L_9
        CMP   DX, 24576
        JNE   _PL_L_7
; STR struct_eq: compare heap cells
        AND   AX, 8191
        AND   BX, 8191
        MOV   SI, AX
        SHL    SI,1
        ADD   SI, OFFSET _PL_HEAP
        MOV   DI, BX
        SHL    DI,1
        ADD   DI, OFFSET _PL_HEAP
        MOV   AX, WORD PTR [SI]
        CMP   AX, WORD PTR [DI]
        JNE   _PL_L_7
        MOV   AX, WORD PTR [SI+2]
        CMP   AX, WORD PTR [DI+2]
        JNE   _PL_L_7
        JMP   _PL_L_6
_PL_L_9:
; LIST struct_eq: compare head+tail
        AND   AX, 8191
        AND   BX, 8191
        MOV   SI, AX
        SHL    SI,1
        ADD   SI, OFFSET _PL_HEAP
        MOV   DI, BX
        SHL    DI,1
        ADD   DI, OFFSET _PL_HEAP
        PUSH   DI
        PUSH   SI
        MOV   AX, WORD PTR [SI]
        MOV   BX, WORD PTR [DI]
        CALL    _PLRT_STRUCT_EQ
        POP   SI
        POP   DI
        JC   _PL_L_7
        MOV   AX, WORD PTR [SI+2]
        MOV   BX, WORD PTR [DI+2]
        CALL    _PLRT_STRUCT_EQ
        JC   _PL_L_7
_PL_L_6:
        CLC
        JMP   _PL_L_8
_PL_L_7:
        STC
_PL_L_8:
        POP   DI
        POP   SI
        POP   DX
        RET

; _PLRT_COMPARE : AX=term1, BX=term2 -> flags
; Ordre: Var < Int < Atom < Str < List
_PLRT_COMPARE:
        PUSH   DX
        PUSH   SI
        PUSH   DI
        PUSH   CX
        CALL    _PLRT_DEREF
        MOV   DX, AX
        MOV   AX, BX
        CALL    _PLRT_DEREF
        MOV   BX, AX
        MOV   AX, DX
        MOV   SI, AX
        AND   SI, 57344
        MOV   CL, 13
        SHR   SI, CL
        MOV   DI, BX
        AND   DI, 57344
        SHR   DI, CL
        CMP   SI, 1
        JNE   _PL_L_11
        MOV   SI, 2
        JMP   _PL_L_12
_PL_L_11:
        CMP   SI, 2
        JNE   _PL_L_12
        MOV   SI, 1
_PL_L_12:
        CMP   DI, 1
        JNE   _PL_L_13
        MOV   DI, 2
        JMP   _PL_L_14
_PL_L_13:
        CMP   DI, 2
        JNE   _PL_L_14
        MOV   DI, 1
_PL_L_14:
        CMP   SI, DI
        JE   _PL_L_15
        JMP   _PL_L_16
_PL_L_15:
        MOV   SI, AX
        AND   SI, 8191
        MOV   DI, BX
        AND   DI, 8191
        CMP   SI, DI
_PL_L_16:
        POP   CX
        POP   DI
        POP   SI
        POP   DX
        RET

; _PLRT_COPY_TERM : AX=source -> AX=copie
_PLRT_COPY_TERM:
        PUSH   BX
        PUSH   DX
        PUSH   SI
        CALL    _PLRT_DEREF
        MOV   DX, AX
        AND   DX, 57344
        CMP   DX, 8192
        JE   _PL_L_17
        CMP   DX, 16384
        JE   _PL_L_17
        CMP   DX, 0
        JNE   _PL_L_19
        MOV   AX, WORD PTR [_PL_HTOP]
        MOV   SI, AX
        SHL   SI, 1
        ADD   SI, OFFSET _PL_HEAP
        MOV   WORD PTR [SI], AX
        INC    WORD PTR [_PL_HTOP]
        JMP   _PL_L_18
_PL_L_19:
        CMP   DX, 32768
        JNE   _PL_L_20
; copy LIST: copy head+tail
        AND   AX, 8191
        MOV   SI, AX
        SHL    SI,1
        ADD   SI, OFFSET _PL_HEAP
        PUSH   SI
        MOV   AX, WORD PTR [SI]
        CALL    _PLRT_COPY_TERM
        MOV   BX, AX
        POP   SI
        PUSH   BX
        PUSH   SI
        MOV   AX, WORD PTR [SI+2]
        CALL    _PLRT_COPY_TERM
        MOV   DX, AX
        POP   SI
        POP   BX
        MOV   AX, BX
        MOV   BX, DX
        CALL    _PLRT_PUTLIST
        JMP   _PL_L_18
_PL_L_20:
_PL_L_17:
_PL_L_18:
        POP   SI
        POP   DX
        POP   BX
        RET


; === TODO 16 : Control Runtime ===

_PLRT_NEGATION:
; negation by failure: try goal in AX
; save HTOP, TTOP, CPTOP
        PUSH   BP
        MOV   BP, SP
        PUSH   WORD PTR [_PL_HTOP]
        PUSH   WORD PTR [_PL_TTOP]
        PUSH   WORD PTR [_PL_CPTOP]
        CALL    AX
        JNC   _PLRT_NEG_FAIL
; goal failed -> negation succeeds
        POP   WORD PTR [_PL_CPTOP]
        POP   WORD PTR [_PL_TTOP]
        POP   WORD PTR [_PL_HTOP]
        MOV   SP, BP
        POP   BP
        CLC
        RET
_PLRT_NEG_FAIL:
; goal succeeded -> negation fails
        POP   WORD PTR [_PL_CPTOP]
        POP   WORD PTR [_PL_TTOP]
        POP   WORD PTR [_PL_HTOP]
        CALL    _PLRT_UNTRAIL
        MOV   SP, BP
        POP   BP
        STC
        RET


; =======================================
;   Routines I/O (TODO 17)
; =======================================

_PLRT_NUMTOSTR:
        PUSH   BX
        PUSH   SI
        PUSH   DI
        MOV   DI, OFFSET _PL_IOBUF
        ADD   DI, 127
        MOV   CX, 0
        MOV   BX, 10
        TEST   AX, AX
        JNS   _PLRT_N2S_POS
        PUSH   AX
        NEG    AX
        JMP   _PLRT_N2S_LOOP
_PLRT_N2S_POS:
        PUSH   AX
_PLRT_N2S_LOOP:
        XOR   DX, DX
        DIV   BX
        ADD   DL, '0'
        MOV   BYTE PTR [DI], DL
        DEC    DI
        INC    CX
        TEST   AX, AX
        JNZ   _PLRT_N2S_LOOP
        POP   AX
        TEST   AX, AX
        JNS   _PLRT_N2S_DONE
        MOV   BYTE PTR [DI], '-'
        DEC    DI
        INC    CX
_PLRT_N2S_DONE:
        INC    DI
        MOV   DX, DI
        POP   DI
        POP   SI
        POP   BX
        RET

_PLRT_WRITE_TERM:
        PUSH   AX
        PUSH   BX
        PUSH   CX
        PUSH   DX
        PUSH   SI
        PUSH   DI
        CALL    _PLRT_DEREF
        MOV   BX, AX
        AND   BX, 57344
        MOV   CL, 13
        SHR   BX, CL
        CMP   BX, 1
        JE   _PLRT_WT_ATOM
        CMP   BX, 2
        JE   _PLRT_WT_INT
        CMP   BX, 4
        JE   _PLRT_WT_LIST
        CMP   BX, 3
        JE   _PLRT_WT_STR
        JMP   _PLRT_WT_REF
_PLRT_WT_ATOM:
        AND   AX, 8191
        SHL   AX, 1
        MOV   SI, AX
        ADD   SI, OFFSET _PLA_TABLE
        MOV   SI, WORD PTR [SI]
        MOV   DI, SI
        MOV   CX, 0
_PLRT_WT_ALEN:
        CMP   BYTE PTR [DI], 0
        JE   _PLRT_WT_APRN
        INC    DI
        INC    CX
        JMP   _PLRT_WT_ALEN
_PLRT_WT_APRN:
        MOV   DX, SI
        MOV   BX, 1
        MOV   AH, 40h
        INT   21h
        JMP   _PLRT_WT_END
_PLRT_WT_INT:
        AND   AX, 8191
        TEST   AX, 1000h
        JZ   _PLRT_WT_IPOS
        OR   AX, 0E000h
_PLRT_WT_IPOS:
        CALL    _PLRT_NUMTOSTR
        MOV   BX, 1
        MOV   AH, 40h
        INT   21h
        JMP   _PLRT_WT_END
_PLRT_WT_LIST:
; print [ then elements
        MOV   DL, '['
        MOV   AH, 02h
        INT   21h
        MOV   AX, WORD PTR [SP+10]
        CALL    _PLRT_DEREF
        AND   AX, 8191
        SHL   AX, 1
        ADD   AX, OFFSET _PL_HEAP
        MOV   SI, AX
        MOV   AX, WORD PTR [SI]
        CALL    _PLRT_WRITE_TERM
        MOV   AX, WORD PTR [SI+2]
        CALL    _PLRT_DEREF
        MOV   BX, AX
        AND   BX, 57344
        CMP   BX, 8192
        JNE   _PLRT_WT_LTAIL
        MOV   BX, AX
        AND   BX, 8191
        CMP   BX, 0
        JE   _PLRT_WT_LEND
_PLRT_WT_LTAIL:
        MOV   DL, '|'
        MOV   AH, 02h
        INT   21h
        CALL    _PLRT_WRITE_TERM
_PLRT_WT_LEND:
        MOV   DL, ']'
        MOV   AH, 02h
        INT   21h
        JMP   _PLRT_WT_END
_PLRT_WT_STR:
; structure: print functor(args)
        AND   AX, 8191
        MOV   DL, '<'
        MOV   AH, 02h
        INT   21h
        MOV   DL, '>'
        MOV   AH, 02h
        INT   21h
        JMP   _PLRT_WT_END
_PLRT_WT_REF:
        MOV   DL, '_'
        MOV   AH, 02h
        INT   21h
        MOV   DL, 'G'
        MOV   AH, 02h
        INT   21h
        AND   AX, 8191
        CALL    _PLRT_NUMTOSTR
        MOV   BX, 1
        MOV   AH, 40h
        INT   21h
_PLRT_WT_END:
        POP   DI
        POP   SI
        POP   DX
        POP   CX
        POP   BX
        POP   AX
        RET

_PLRT_NL:
        MOV   DL, 13
        MOV   AH, 02h
        INT   21h
        MOV   DL, 10
        MOV   AH, 02h
        INT   21h
        RET

_PLRT_TAB:
        PUSH   CX
        MOV   CX, AX
        TEST   CX, CX
        JZ   _PLRT_TAB_END
_PLRT_TAB_LOOP:
        MOV   DL, 32
        MOV   AH, 02h
        INT   21h
        LOOP    _PLRT_TAB_LOOP
_PLRT_TAB_END:
        POP   CX
        RET

_PLRT_PUT_CHAR:
        MOV   DL, AL
        MOV   AH, 02h
        INT   21h
        RET

_PLRT_GET_CHAR:
        MOV   AH, 01h
        INT   21h
        XOR   AH, AH
        AND   AX, 8191
        OR   AX, 16384
        RET

_PLRT_CHAR_CODE:
        PUSH   BX
        MOV   BX, AX
        AND   BX, 57344
        CMP   BX, 8192
        JNE   _PLRT_CC_INT
        AND   AX, 8191
        SHL   AX, 1
        MOV   SI, AX
        ADD   SI, OFFSET _PLA_TABLE
        MOV   SI, WORD PTR [SI]
        XOR   AX, AX
        MOV   AL, BYTE PTR [SI]
        AND   AX, 8191
        OR   AX, 16384
        POP   BX
        RET
_PLRT_CC_INT:
        POP   BX
        RET

_PLRT_ATOM_LENGTH:
        PUSH   SI
        PUSH   DI
        AND   AX, 8191
        SHL   AX, 1
        MOV   SI, AX
        ADD   SI, OFFSET _PLA_TABLE
        MOV   SI, WORD PTR [SI]
        XOR   CX, CX
_PLRT_AL_LOOP:
        CMP   BYTE PTR [SI], 0
        JE   _PLRT_AL_DONE
        INC    SI
        INC    CX
        JMP   _PLRT_AL_LOOP
_PLRT_AL_DONE:
        MOV   AX, CX
        AND   AX, 8191
        OR   AX, 16384
        POP   DI
        POP   SI
        RET

_PLRT_ATOM_CONCAT:
        PUSH   SI
        PUSH   DI
        PUSH   CX
        PUSH   BX
        AND   AX, 8191
        SHL   AX, 1
        MOV   SI, AX
        ADD   SI, OFFSET _PLA_TABLE
        MOV   SI, WORD PTR [SI]
        MOV   DI, OFFSET _PL_IOBUF
_PLRT_AC_CP1:
        MOV   AL, BYTE PTR [SI]
        CMP   AL, 0
        JE   _PLRT_AC_CP2S
        MOV   BYTE PTR [DI], AL
        INC    SI
        INC    DI
        JMP   _PLRT_AC_CP1
_PLRT_AC_CP2S:
        POP   BX
        AND   BX, 8191
        SHL   BX, 1
        MOV   SI, BX
        ADD   SI, OFFSET _PLA_TABLE
        MOV   SI, WORD PTR [SI]
_PLRT_AC_CP2:
        MOV   AL, BYTE PTR [SI]
        MOV   BYTE PTR [DI], AL
        CMP   AL, 0
        JE   _PLRT_AC_DONE
        INC    SI
        INC    DI
        JMP   _PLRT_AC_CP2
_PLRT_AC_DONE:
        MOV   AX, DI
        SUB   AX, OFFSET _PL_IOBUF
        AND   AX, 8191
        OR   AX, 16384
        POP   CX
        POP   DI
        POP   SI
        RET

_PLRT_ATOM_CHARS:
        PUSH   BX
        PUSH   SI
        PUSH   DI
        PUSH   CX
        AND   AX, 8191
        SHL   AX, 1
        MOV   SI, AX
        ADD   SI, OFFSET _PLA_TABLE
        MOV   SI, WORD PTR [SI]
        MOV   DI, SI
        XOR   CX, CX
_PLRT_ACH_LEN:
        CMP   BYTE PTR [DI], 0
        JE   _PLRT_ACH_BUILD
        INC    DI
        INC    CX
        JMP   _PLRT_ACH_LEN
_PLRT_ACH_BUILD:
        MOV   AX, 8192
        TEST   CX, CX
        JZ   _PLRT_ACH_DONE
_PLRT_ACH_LOOP:
        DEC    DI
        XOR   BX, BX
        MOV   BL, BYTE PTR [DI]
        AND   BX, 8191
        OR   BX, 16384
        PUSH   AX
        MOV   AX, BX
        POP   BX
        CALL    _PLRT_PUTLIST
        LOOP    _PLRT_ACH_LOOP
_PLRT_ACH_DONE:
        POP   CX
        POP   DI
        POP   SI
        POP   BX
        RET

_PLRT_NUMBER_CHARS:
        PUSH   BX
        PUSH   SI
        PUSH   DI
        PUSH   CX
        AND   AX, 8191
        TEST   AX, 1000h
        JZ   _PLRT_NC_POS
        OR   AX, 0E000h
_PLRT_NC_POS:
        CALL    _PLRT_NUMTOSTR
        MOV   SI, DX
        ADD   SI, CX
        MOV   AX, 8192
        TEST   CX, CX
        JZ   _PLRT_NC_DONE
_PLRT_NC_LOOP:
        DEC    SI
        XOR   BX, BX
        MOV   BL, BYTE PTR [SI]
        AND   BX, 8191
        OR   BX, 16384
        PUSH   AX
        MOV   AX, BX
        POP   BX
        CALL    _PLRT_PUTLIST
        LOOP    _PLRT_NC_LOOP
_PLRT_NC_DONE:
        POP   CX
        POP   DI
        POP   SI
        POP   BX
        RET


; === TODO 18 : Runtime predicats predefinis ===

_PLRT_GROUND:
        PUSH    BX
        PUSH    CX
        CALL    _PLRT_DEREF
        MOV   BX, AX
        AND   BX, 57344
        CMP   BX, 0
        JE   _PLRT_GND_FAIL
        CMP   BX, 16384
        JE   _PLRT_GND_OK
        CMP   BX, 8192
        JE   _PLRT_GND_OK
        CMP   BX, 32768
        JNE   _PLRT_GND_OK
        PUSH    AX
        CALL    _PLRT_GETLIST
        MOV   AX, BX
        CALL    _PLRT_GROUND
        JC   _PLRT_GND_F2
        MOV   AX, CX
        CALL    _PLRT_GROUND
        JC   _PLRT_GND_F2
        POP     AX
        JMP   _PLRT_GND_OK
_PLRT_GND_F2:
        POP     AX
_PLRT_GND_FAIL:
        STC
        POP     CX
        POP     BX
        RET
_PLRT_GND_OK:
        CLC
        POP     CX
        POP     BX
        RET

_PLRT_UNIV:
        PUSH    CX
        CALL    _PLRT_DEREF
        MOV   BX, AX
        AND   BX, 57344
        CMP   BX, 32768
        JE   _PLRT_UNIV_L
; atom/int -> [X]
        MOV   BX, 8192
        CALL    _PLRT_PUTLIST
        MOV   BX, AX
        POP     CX
        RET
_PLRT_UNIV_L:
; list [H|T] -> [dot,H,T]
        PUSH    AX
        CALL    _PLRT_GETLIST
        PUSH    BX
        MOV   AX, CX
        MOV   BX, 8192
        CALL    _PLRT_PUTLIST
        POP     BX
        PUSH    AX
        MOV   AX, BX
        POP     BX
        CALL    _PLRT_PUTLIST
        MOV   BX, AX
        POP     AX
        MOV   AX, 8193
        CALL    _PLRT_PUTLIST
        MOV   BX, AX
        POP     CX
        RET

_PLRT_REVERSE:
        PUSH    BX
        PUSH    CX
        PUSH    DX
        MOV   DX, 8192
_PLRT_REVL:
        CALL    _PLRT_DEREF
        MOV   BX, AX
        AND   BX, 57344
        CMP   BX, 32768
        JNE   _PLRT_REVD
        CALL    _PLRT_GETLIST
        MOV   AX, BX
        MOV   BX, DX
        CALL    _PLRT_PUTLIST
        MOV   DX, AX
        MOV   AX, CX
        JMP   _PLRT_REVL
_PLRT_REVD:
        MOV   AX, DX
        POP     DX
        POP     CX
        POP     BX
        RET

_PLRT_MSORT:
        PUSH    BX
        PUSH    CX
        PUSH    DI
        MOV   DI, 8192
_PLRT_MSL:
        CALL    _PLRT_DEREF
        MOV   BX, AX
        AND   BX, 57344
        CMP   BX, 32768
        JNE   _PLRT_MSD
        CALL    _PLRT_GETLIST
        PUSH    CX
        MOV   AX, BX
        MOV   BX, DI
        CALL    _PLRT_MSORT_I
        MOV   DI, AX
        POP     AX
        JMP   _PLRT_MSL
_PLRT_MSD:
        MOV   AX, DI
        POP     DI
        POP     CX
        POP     BX
        RET

_PLRT_MSORT_I:
        PUSH    CX
        PUSH    DX
        MOV   CX, BX
        AND   CX, 57344
        CMP   CX, 32768
        JNE   _PLRT_MSI_H
        PUSH    AX
        PUSH    BX
        MOV   AX, BX
        CALL    _PLRT_GETLIST
        MOV   DX, CX
        POP     CX
        POP     AX
        PUSH    AX
        PUSH    BX
        CALL    _PLRT_COMPARE
        CMP   AX, 0
        POP     BX
        POP     AX
        JLE   _PLRT_MSI_H
        PUSH    BX
        MOV   BX, DX
        CALL    _PLRT_MSORT_I
        MOV   BX, AX
        POP     AX
        CALL    _PLRT_PUTLIST
        POP     DX
        POP     CX
        RET
_PLRT_MSI_H:
        CALL    _PLRT_PUTLIST
        POP     DX
        POP     CX
        RET

_PLRT_SORT:
        CALL    _PLRT_MSORT
; remove consecutive duplicates
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    DI
        MOV   DI, 8192
        MOV   DX, -1
_PLRT_SRT_L:
        CALL    _PLRT_DEREF
        MOV   BX, AX
        AND   BX, 57344
        CMP   BX, 32768
        JNE   _PLRT_SRT_E
        CALL    _PLRT_GETLIST
        CMP   BX, DX
        JE   _PLRT_SRT_SK
        MOV   DX, BX
        PUSH    CX
        MOV   AX, BX
        MOV   BX, DI
        CALL    _PLRT_PUTLIST
        MOV   DI, AX
        POP     AX
        JMP   _PLRT_SRT_L
_PLRT_SRT_SK:
        MOV   AX, CX
        JMP   _PLRT_SRT_L
_PLRT_SRT_E:
        MOV   AX, DI
        CALL    _PLRT_REVERSE
        POP     DI
        POP     DX
        POP     CX
        POP     BX
        RET

_PLRT_CALL:
; call/1: atom in AX -> lookup pred label and call
; simplified: we emit a stub that succeeds for known atoms
; Real call/1 would need indirect jump table
        PUSH    BX
        CALL    _PLRT_DEREF
        MOV   BX, AX
        AND   BX, 57344
; check if atom
        CMP   BX, 8192
        JNE   _PLRT_CALL_F
; extract atom index
        AND   AX, 8191
; lookup: check for true(0)/fail(1)
        CMP   AX, 0
        JE   _PLRT_CALL_F
; default: succeed
        CLC
        POP     BX
        RET
_PLRT_CALL_F:
        STC
        POP     BX
        RET

_PLRT_UNIFY_OC:
; simplified: delegates to standard unify
; a full occurs check would walk the term tree
        CALL    _PLRT_UNIFY
        RET

_PLRT_READ:
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    SI
; read chars into _PL_IOBUF until CR
        MOV   SI, OFFSET _PL_IOBUF
        XOR   CX, CX
_PLRT_RD_LP:
        MOV   AH, 01h
        INT   21h
        CMP   AL, 13
        JE   _PLRT_RD_DN
        CMP   AL, 10
        JE   _PLRT_RD_DN
        MOV     BYTE PTR [SI], AL
        INC     SI
        INC     CX
        CMP   CX, 126
        JB   _PLRT_RD_LP
_PLRT_RD_DN:
        MOV     BYTE PTR [SI], 0
; parse integer from _PL_IOBUF
        MOV   SI, OFFSET _PL_IOBUF
        XOR   AX, AX
        XOR   BX, BX
        XOR   DX, DX
; check negative
        CMP     BYTE PTR [SI], 45
        JNE   _PLRT_RD_POS
        MOV   DX, 1
        INC     SI
_PLRT_RD_POS:
        MOV     BL, BYTE PTR [SI]
        CMP   BL, 0
        JE   _PLRT_RD_FIN
        SUB   BL, 48
        CMP   BL, 9
        JA   _PLRT_RD_FIN
; AX = AX * 10 + BL
        PUSH    DX
        MOV   CX, 10
        MUL     CX
        POP     DX
        XOR   BH, BH
        ADD   AX, BX
        INC     SI
        JMP   _PLRT_RD_POS
_PLRT_RD_FIN:
        CMP   DX, 0
        JE   _PLRT_RD_TAG
        NEG     AX
_PLRT_RD_TAG:
; tag as INT
        AND   AX, 8191
        OR   AX, 16384
        POP     SI
        POP     DX
        POP     CX
        POP     BX
        RET

_PLRT_SUB_ATOM:
; sub_atom/5 stub - not fully implemented
        STC
        RET


; =======================================
;   Routines Dynamic DB (TODO 19)
; =======================================

_PLRT_ASSERTA:
        PUSH    BX
        PUSH    CX
        PUSH    SI
        PUSH    DI
        PUSH    AX
        MOV   CX, WORD PTR [_PL_DYNCOUNT]
        TEST   CX, CX
        JZ   _PLRT_ASSA_INS
        MOV   SI, CX
        DEC     SI
        SHL     SI,1
        ADD   SI, OFFSET _PL_DYNDB
        MOV   DI, SI
        ADD   DI, 2
        STD
        REP MOVSW
        CLD
_PLRT_ASSA_INS:
        POP     AX
        MOV   WORD PTR [_PL_DYNDB], AX
        INC     WORD PTR [_PL_DYNCOUNT]
        POP     DI
        POP     SI
        POP     CX
        POP     BX
        CLC
        RET

_PLRT_ASSERTZ:
        PUSH    SI
        MOV   SI, WORD PTR [_PL_DYNCOUNT]
        SHL     SI,1
        ADD   SI, OFFSET _PL_DYNDB
        MOV   WORD PTR [SI], AX
        INC     WORD PTR [_PL_DYNCOUNT]
        POP     SI
        CLC
        RET

_PLRT_RETRACT:
        PUSH    BX
        PUSH    CX
        PUSH    SI
        PUSH    DI
        MOV   BX, AX
        MOV   CX, WORD PTR [_PL_DYNCOUNT]
        TEST   CX, CX
        JZ   _PLRT_RET_FAIL
        MOV   SI, OFFSET _PL_DYNDB
_PLRT_RET_LOOP:
        CMP   WORD PTR [SI], BX
        JE   _PLRT_RET_FOUND
        ADD   SI, 2
        DEC     CX
        JNZ   _PLRT_RET_LOOP
_PLRT_RET_FAIL:
        POP     DI
        POP     SI
        POP     CX
        POP     BX
        STC
        RET
_PLRT_RET_FOUND:
        MOV   DI, SI
        ADD   SI, 2
        DEC     CX
        CLD
        REP MOVSW
        DEC     WORD PTR [_PL_DYNCOUNT]
        POP     DI
        POP     SI
        POP     CX
        POP     BX
        CLC
        RET

_PLRT_ABOLISH:
        PUSH    BX
        PUSH    CX
        PUSH    SI
        PUSH    DI
        MOV   BX, AX
        AND   BX, 8191
; extract atom index from predicate
        MOV   CX, WORD PTR [_PL_DYNCOUNT]
        TEST   CX, CX
        JZ   _PLRT_ABOL_DONE
        MOV   SI, OFFSET _PL_DYNDB
        MOV   DI, SI
        XOR   DX, DX
; DX = new count
_PLRT_ABOL_LOOP:
        MOV   AX, WORD PTR [SI]
        PUSH    AX
        AND   AX, 8191
        CMP   AX, BX
        POP     AX
        JE   _PLRT_ABOL_SKIP
        MOV   WORD PTR [DI], AX
        ADD   DI, 2
        INC     DX
_PLRT_ABOL_SKIP:
        ADD   SI, 2
        DEC     CX
        JNZ   _PLRT_ABOL_LOOP
        MOV   WORD PTR [_PL_DYNCOUNT], DX
_PLRT_ABOL_DONE:
        POP     DI
        POP     SI
        POP     CX
        POP     BX
        CLC
        RET


; =======================================
;   Routines Collection (TODO 20)
; =======================================

_PLRT_COLLECT_PUSH:
        PUSH    SI
        MOV   SI, WORD PTR [_PL_COLLCOUNT]
        SHL     SI,1
        ADD   SI, OFFSET _PL_COLLECT
        MOV   WORD PTR [SI], AX
        INC     WORD PTR [_PL_COLLCOUNT]
        POP     SI
        RET

_PLRT_COLLECT_RESET:
        MOV   WORD PTR [_PL_COLLCOUNT], 0
        RET

_PLRT_MAKELIST:
        PUSH    BX
        PUSH    CX
        PUSH    SI
        MOV   CX, WORD PTR [_PL_COLLCOUNT]
        TEST   CX, CX
        JZ   _PLRT_MKLS_EMPTY
        MOV   BX, 8193
; BX = [] (nil atom)
        MOV   SI, CX
        DEC     SI
        SHL     SI,1
        ADD   SI, OFFSET _PL_COLLECT
_PLRT_MKLS_LOOP:
        MOV   AX, WORD PTR [SI]
; AX = head, BX = tail
        CALL    _PLRT_PUTLIST
        MOV   BX, AX
; new tail = resulting list
        SUB   SI, 2
        DEC     CX
        JNZ   _PLRT_MKLS_LOOP
; AX = complete list
        JMP   _PLRT_MKLS_DONE
_PLRT_MKLS_EMPTY:
        MOV   AX, 8193
; AX = [] (empty list)
_PLRT_MKLS_DONE:
        POP     SI
        POP     CX
        POP     BX
        CLC
        RET

_PLRT_FINDALL:
        CALL    _PLRT_MAKELIST
        RET

_PLRT_SETOF_DEDUP:
        PUSH    BX
        PUSH    CX
        PUSH    SI
        PUSH    DI
        MOV   SI, AX
        MOV   BX, AX
        AND   BX, 57344
        CMP   BX, 32768
        JNE   _PLRT_DEDUP_DONE
; reset collect buffer for dedup
        CALL    _PLRT_COLLECT_RESET
_PLRT_DEDUP_WALK:
        MOV   AX, SI
        AND   AX, 8191
        SHL     AX,1
        ADD   AX, OFFSET _PL_HEAP
        MOV   DI, AX
; DI -> heap cell [head|tail]
        MOV   AX, WORD PTR [DI]
; AX = head of current cell
        MOV   CX, WORD PTR [_PL_COLLCOUNT]
        TEST   CX, CX
        JZ   _PLRT_DEDUP_ADD
        PUSH    SI
        MOV   SI, CX
        DEC     SI
        SHL     SI,1
        ADD   SI, OFFSET _PL_COLLECT
        CMP   AX, WORD PTR [SI]
        POP     SI
        JE   _PLRT_DEDUP_SKIP
_PLRT_DEDUP_ADD:
        CALL    _PLRT_COLLECT_PUSH
_PLRT_DEDUP_SKIP:
        MOV   SI, WORD PTR [DI+2]
; SI = tail
        MOV   BX, SI
        AND   BX, 57344
        CMP   BX, 32768
        JE   _PLRT_DEDUP_WALK
        CALL    _PLRT_MAKELIST
_PLRT_DEDUP_DONE:
        POP     DI
        POP     SI
        POP     CX
        POP     BX
        CLC
        RET


; =======================================
;   Routines Operateurs (TODO 21)
; =======================================

_PLRT_OP_REGISTER:
        PUSH    SI
        PUSH    DI
        AND   AX, 8191
        MOV   SI, WORD PTR [_PL_OPCOUNT]
        SHL     SI,1
        ADD   SI, OFFSET _PL_OPPREC
        MOV   WORD PTR [SI], AX
        INC     WORD PTR [_PL_OPCOUNT]
        POP     DI
        POP     SI
        CLC
        RET

_PLRT_OP_LOOKUP:
        PUSH    CX
        PUSH    SI
        MOV   CX, WORD PTR [_PL_OPCOUNT]
        TEST   CX, CX
        JZ   _PLRT_OPLK_FAIL
        MOV   SI, OFFSET _PL_OPPREC
_PLRT_OPLK_LOOP:
        CMP   AX, WORD PTR [SI]
        JE   _PLRT_OPLK_FOUND
        ADD   SI, 2
        DEC     CX
        JNZ   _PLRT_OPLK_LOOP
_PLRT_OPLK_FAIL:
        POP     SI
        POP     CX
        STC
        RET
_PLRT_OPLK_FOUND:
        MOV   AX, WORD PTR [SI]
        POP     SI
        POP     CX
        CLC
        RET

_TEXT   ENDS

_DATA   SEGMENT WORD PUBLIC 'DATA'

_PL_CRLF    DB  13,10,0

_PL_STRBUF  DB  256 DUP(0)

_PL_TRUE_S  DB  'true',0
_PL_FAIL_S  DB  'fail',0
_PL_CUT_S  DB  '!',0
_PL_NIL_S  DB  '[]',0
_PL_YES_S  DB  'yes',0
_PL_NO_S  DB  'no',0
_PLA_0  DB  '.',0
_PLA_1  DB  '[]',0
_PLA_2  DB  ',',0
_PLA_3  DB  ';',0
_PLA_4  DB  '->',0
_PLA_5  DB  'true',0
_PLA_6  DB  'fail',0
_PLA_7  DB  'false',0
; --- Table des atomes (8 entrees) ---
_PLA_TABLE  DW  _PLA_0, _PLA_1, _PLA_2, _PLA_3, _PLA_4, _PLA_5, _PLA_6, _PLA_7
_PLA_COUNT  DW  8
; --- Table des foncteurs (5 entrees) ---
_PLF_0  DW  0, 2   ; ./2
_PLF_1  DW  1, 0   ; []/0
_PLF_2  DW  2, 2   ; ,/2
_PLF_3  DW  3, 2   ; ;/2
_PLF_4  DW  4, 2   ; ->/2
_PLF_COUNT  DW  5

; --- Zones memoire WAM ---
_PL_HEAP    DW  2048 DUP(0)
_PL_HTOP    DW  0
_PL_STACK   DW  1024 DUP(0)
_PL_STOP    DW  0
_PL_TRAIL   DW  512 DUP(0)
_PL_TTOP    DW  0

; --- Backtracking (choice point stack) ---
_PL_CPTOP   DW  0
_PL_CUT_BARRIER DW  0

; --- I/O buffer (TODO 17) ---
_PL_IOBUF   DB  128 DUP(0)
_PL_IOBUFLEN DW  0

; --- Dynamic database (TODO 19) ---
_PL_DYNDB   DW  256 DUP(0)
_PL_DYNCOUNT DW  0

; --- Solution collection buffer (TODO 20) ---
_PL_COLLECT  DW  256 DUP(0)
_PL_COLLCOUNT DW  0

; --- Operator table (TODO 21) ---
_PL_OPCOUNT DW  0
_PL_OPPREC  DW  128 DUP(0)
_PL_OPTYPE  DB  512 DUP(0)
_PL_OPNAME  DB  4096 DUP(0)

; --- Directives (TODO 22) ---
_PL_MODNAME DB  64 DUP(0)
_PL_INITCNT DW  0

; --- Registres d arguments WAM ---
_PL_ARGS    DW  16 DUP(0)

_DATA   ENDS

        END    _PLP_Main
