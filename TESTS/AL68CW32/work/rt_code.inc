rt_put:
        TEST    ECX, ECX
        JLE     rt_putx
        PUSH    ESI
        PUSH    ECX
        PUSH    -11
        CALL    GetStdHandle
        POP     ECX
        POP     ESI
        PUSH    0
        PUSH    OFFSET rtwr
        PUSH    ECX
        PUSH    ESI
        PUSH    EAX
        CALL    WriteFile
rt_putx:
        RET
_A68RT_NEWLINE:
        MOV     ESI, OFFSET rtcr
        MOV     ECX, 2
        JMP     rt_put
_A68RT_SPACE:
        MOV     ESI, OFFSET rtsp
        MOV     ECX, 1
        JMP     rt_put
_A68RT_WRITECHAR:
        MOV     BYTE PTR [rtbuf], AL
        MOV     ESI, OFFSET rtbuf
        MOV     ECX, 1
        JMP     rt_put
_A68RT_WRITESTR:
        MOV     ECX, DWORD PTR [EAX+8]
        SUB     ECX, DWORD PTR [EAX+4]
        INC     ECX
        MOV     ESI, DWORD PTR [EAX]
        JMP     rt_put
_A68RT_WRITEBOOL:
        TEST    EAX, EAX
        JE      wb_f
        MOV     ESI, OFFSET rttrue
        MOV     ECX, 4
        JMP     rt_put
wb_f:
        MOV     ESI, OFFSET rtfalse
        MOV     ECX, 5
        JMP     rt_put
rt_digits:
        MOV     EDI, OFFSET rtbuf+60
        MOV     ESI, EDI
        MOV     ECX, EAX
        TEST    EAX, EAX
        JNS     rd_loop
        NEG     EAX
rd_loop:
        XOR     EDX, EDX
        DIV     DWORD PTR [rtten]
        PUSH    EAX
        MOV     EAX, EDX
        ADD     EAX, 48
        DEC     EDI
        MOV     BYTE PTR [EDI], AL
        POP     EAX
        TEST    EAX, EAX
        JNE     rd_loop
        TEST    ECX, ECX
        JNS     rd_end
        DEC     EDI
        MOV     BYTE PTR [EDI], 45
rd_end:
        RET
_A68RT_WRITEINT:
        CALL    rt_digits
        MOV     ECX, ESI
        SUB     ECX, EDI
        MOV     ESI, EDI
        JMP     rt_put
_A68RT_WRITEREAL:
        FSTP    QWORD PTR [rtq]
        MOV     EAX, DWORD PTR [rtq+4]
        MOV     DWORD PTR [rtsg], EAX
        AND     EAX, 2147483647
        MOV     DWORD PTR [rtq+4], EAX
        FLD     QWORD PTR [rtq]
        FMUL    QWORD PTR [rtmilr]
        FISTP   QWORD PTR [rtq]
        MOV     EAX, DWORD PTR [rtq]
        MOV     EDX, DWORD PTR [rtq+4]
        DIV     DWORD PTR [rtmil]
        MOV     EDI, OFFSET rtbuf+60
        MOV     ESI, EDI
        PUSH    EAX
        MOV     EAX, EDX
        MOV     ECX, 6
wr_f:
        XOR     EDX, EDX
        DIV     DWORD PTR [rtten]
        PUSH    EAX
        MOV     EAX, EDX
        ADD     EAX, 48
        DEC     EDI
        MOV     BYTE PTR [EDI], AL
        POP     EAX
        DEC     ECX
        JNE     wr_f
wr_t:
        MOV     EAX, ESI
        DEC     EAX
        CMP     EAX, EDI
        JLE     wr_te
        MOVZX   EDX, BYTE PTR [EAX]
        CMP     EDX, 48
        JNE     wr_te
        MOV     ESI, EAX
        JMP     wr_t
wr_te:
        DEC     EDI
        MOV     BYTE PTR [EDI], 46
        POP     EAX
wr_i:
        XOR     EDX, EDX
        DIV     DWORD PTR [rtten]
        PUSH    EAX
        MOV     EAX, EDX
        ADD     EAX, 48
        DEC     EDI
        MOV     BYTE PTR [EDI], AL
        POP     EAX
        TEST    EAX, EAX
        JNE     wr_i
        MOV     EAX, DWORD PTR [rtsg]
        TEST    EAX, EAX
        JNS     wr_ns
        DEC     EDI
        MOV     BYTE PTR [EDI], 45
wr_ns:
        MOV     ECX, ESI
        SUB     ECX, EDI
        MOV     ESI, EDI
        JMP     rt_put
_A68RT_WHOLE:
        PUSH    ECX
        CALL    rt_digits
        POP     EDX
        MOV     ECX, ESI
        SUB     ECX, EDI
        CMP     EDX, ECX
        JGE     wh_w
        MOV     EDX, ECX
wh_w:
        PUSH    EDI
        PUSH    ECX
        PUSH    EDX
        MOV     EAX, EDX
        ADD     EAX, 16
        CALL    _A68RT_ALLOC
        POP     EDX
        POP     ECX
        POP     ESI
        MOV     DWORD PTR [EAX+4], 1
        MOV     DWORD PTR [EAX+8], EDX
        MOV     DWORD PTR [EAX+12], 1
        MOV     EDI, EAX
        ADD     EDI, 16
        MOV     DWORD PTR [EAX], EDI
        PUSH    EAX
        MOV     EAX, EDX
        SUB     EAX, ECX
wh_p:
        TEST    EAX, EAX
        JLE     wh_pe
        MOV     BYTE PTR [EDI], 32
        INC     EDI
        DEC     EAX
        JMP     wh_p
wh_pe:
        REP MOVSB
        POP     EAX
        RET
rt_getc:
        MOV     EAX, DWORD PTR [rtpeek]
        CMP     EAX, -2
        JE      gc_read
        MOV     DWORD PTR [rtpeek], -2
        RET
gc_read:
        PUSH    -10
        CALL    GetStdHandle
        PUSH    0
        PUSH    OFFSET rtwr
        PUSH    1
        PUSH    OFFSET rtin
        PUSH    EAX
        CALL    ReadFile
        MOV     EAX, DWORD PTR [rtwr]
        TEST    EAX, EAX
        JE      gc_eof
        MOVZX   EAX, BYTE PTR [rtin]
        RET
gc_eof:
        MOV     EAX, -1
        RET
rt_skipws:
        CALL    rt_getc
        CMP     EAX, 32
        JE      rt_skipws
        CMP     EAX, 9
        JE      rt_skipws
        CMP     EAX, 10
        JE      rt_skipws
        CMP     EAX, 13
        JE      rt_skipws
        RET
_A68RT_READCHAR:
        CALL    rt_getc
        CMP     EAX, -1
        JNE     rc_x
        XOR     EAX, EAX
rc_x:
        RET
_A68RT_READINT:
        CALL    rt_skipws
        MOV     DWORD PTR [rtsg], 0
        MOV     DWORD PTR [rtacc], 0
        CMP     EAX, 45
        JNE     ri_l
        MOV     DWORD PTR [rtsg], 1
        CALL    rt_getc
ri_l:
        SUB     EAX, 48
        CMP     EAX, 9
        JA      ri_e
        PUSH    EAX
        MOV     EAX, DWORD PTR [rtacc]
        IMUL    EAX, DWORD PTR [rtten]
        POP     ECX
        ADD     EAX, ECX
        MOV     DWORD PTR [rtacc], EAX
        CALL    rt_getc
        JMP     ri_l
ri_e:
        ADD     EAX, 48
        MOV     DWORD PTR [rtpeek], EAX
        MOV     EAX, DWORD PTR [rtacc]
        MOV     ECX, DWORD PTR [rtsg]
        TEST    ECX, ECX
        JE      ri_x
        NEG     EAX
ri_x:
        RET
_A68RT_READREAL:
        CALL    rt_skipws
        MOV     DWORD PTR [rtsg], 0
        MOV     DWORD PTR [rtcnt], 0
        MOV     DWORD PTR [rtdot], 0
        CMP     EAX, 45
        JNE     rr_d
        MOV     DWORD PTR [rtsg], 1
        CALL    rt_getc
rr_d:
        FLDZ
rr_l:
        CMP     EAX, 46
        JNE     rr_nd
        MOV     ECX, DWORD PTR [rtdot]
        TEST    ECX, ECX
        JNE     rr_e
        MOV     DWORD PTR [rtdot], 1
        CALL    rt_getc
        JMP     rr_l
rr_nd:
        SUB     EAX, 48
        CMP     EAX, 9
        JA      rr_e2
        PUSH    EAX
        FMUL    QWORD PTR [rtten8]
        FILD    DWORD PTR [ESP]
        FADDP   ST(1), ST(0)
        POP     EAX
        MOV     ECX, DWORD PTR [rtdot]
        ADD     DWORD PTR [rtcnt], ECX
        CALL    rt_getc
        JMP     rr_l
rr_e2:
        ADD     EAX, 48
rr_e:
        MOV     DWORD PTR [rtpeek], EAX
rr_f:
        MOV     ECX, DWORD PTR [rtcnt]
        TEST    ECX, ECX
        JE      rr_s
        FDIV    QWORD PTR [rtten8]
        DEC     ECX
        MOV     DWORD PTR [rtcnt], ECX
        JMP     rr_f
rr_s:
        MOV     EAX, DWORD PTR [rtsg]
        TEST    EAX, EAX
        JE      rr_x
        FCHS
rr_x:
        RET
_A68RT_READSTR:
        MOV     EAX, 272
        CALL    _A68RT_ALLOC
        MOV     DWORD PTR [rtblk], EAX
        MOV     EDX, EAX
        ADD     EAX, 16
        MOV     DWORD PTR [EDX], EAX
        MOV     DWORD PTR [EDX+4], 1
        MOV     DWORD PTR [EDX+12], 1
        MOV     DWORD PTR [rtacc], 0
rs_l:
        CALL    rt_getc
        CMP     EAX, 10
        JE      rs_e
        CMP     EAX, -1
        JE      rs_e
        CMP     EAX, 13
        JE      rs_l
        MOV     ECX, DWORD PTR [rtacc]
        CMP     ECX, 256
        JGE     rs_l
        MOV     EDX, DWORD PTR [rtblk]
        MOV     EDX, DWORD PTR [EDX]
        ADD     EDX, ECX
        MOV     BYTE PTR [EDX], AL
        INC     ECX
        MOV     DWORD PTR [rtacc], ECX
        JMP     rs_l
rs_e:
        MOV     EDX, DWORD PTR [rtblk]
        MOV     EAX, DWORD PTR [rtacc]
        MOV     DWORD PTR [EDX+8], EAX
        MOV     EAX, EDX
        RET
_A68RT_STRCAT:
        PUSH    ESI
        PUSH    EDI
        MOV     EAX, DWORD PTR [ESI+8]
        SUB     EAX, DWORD PTR [ESI+4]
        INC     EAX
        TEST    EAX, EAX
        JGE     sc_1
        XOR     EAX, EAX
sc_1:
        MOV     DWORD PTR [rtacc], EAX
        MOV     EAX, DWORD PTR [EDI+8]
        SUB     EAX, DWORD PTR [EDI+4]
        INC     EAX
        TEST    EAX, EAX
        JGE     sc_2
        XOR     EAX, EAX
sc_2:
        MOV     DWORD PTR [rtcnt], EAX
        ADD     EAX, DWORD PTR [rtacc]
        ADD     EAX, 16
        CALL    _A68RT_ALLOC
        POP     EDI
        POP     ESI
        MOV     EDX, EAX
        MOV     DWORD PTR [EDX+4], 1
        MOV     ECX, DWORD PTR [rtacc]
        ADD     ECX, DWORD PTR [rtcnt]
        MOV     DWORD PTR [EDX+8], ECX
        MOV     DWORD PTR [EDX+12], 1
        MOV     EAX, EDX
        ADD     EAX, 16
        MOV     DWORD PTR [EDX], EAX
        PUSH    EDI
        MOV     EDI, EAX
        MOV     ECX, DWORD PTR [rtacc]
        MOV     ESI, DWORD PTR [ESI]
        REP MOVSB
        POP     ESI
        MOV     ECX, DWORD PTR [rtcnt]
        MOV     ESI, DWORD PTR [ESI]
        REP MOVSB
        MOV     EAX, EDX
        RET
