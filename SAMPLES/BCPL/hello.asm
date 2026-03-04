; ------------------------------------------------------------
;  Fichier genere par BCPL86 v1.0
;  Date   : 2026-03-03
;  Source : SAMPLES\BCPL\hello.b
;  Section: SAMPLES\BCPL\hello
;  Cible  : MASM 8086, modele SMALL, convention BCPL
; ------------------------------------------------------------

        .MODEL  SMALL
        .8086

;  ----- Segment STACK -----
_STACK          SEGMENT PARA STACK 'STACK'
                DB      512 DUP (?)
_STACK          ENDS

;  ----- Segment DATA -----
_DATA           SEGMENT WORD PUBLIC 'DATA'

;  ----- Variables systeme BCPL86 -----
_BV_OUTBUF              DB      256 DUP(0)
_BV_INBUF               DB      128 DUP(0)
_BV_INTBUF              DB      12 DUP(0)
_BV_CRLF                DB      0Dh, 0Ah, '$'
_BV_TMPCH               DB      0, 0


_DATA           ENDS

;  ----- Segment CODE -----
_CODE           SEGMENT WORD PUBLIC 'CODE'

                ASSUME CS:_CODE, DS:_DATA, SS:_STACK

;  Point d'entree BCPL : init DS, vecteur global, appel G!1 (main)
START:
        MOV  AX, _DATA
        MOV  DS, AX
        LEA  BX, [_BG_]


;  Fin normale du programme
        MOV  AX, 4C00h
        INT  21h

; ------------------------------------------------------------
;  ====== RUNTIME BCPL (BRT) - BCPL86 ====== 

_BRT_WRITES:
        PUSH  AX
        PUSH  BX
        PUSH  CX
        PUSH  DX
        XOR  AH, AH
        MOV  AL, [SI]
        MOV  CX, AX
        INC  SI
_BRT_WS_LOOP:
        OR  CX, CX
        JZ  _BRT_WS_END
        MOV  DL, [SI]
        MOV  AH, 2
        INT  21h
        INC  SI
        DEC  CX
        JMP  _BRT_WS_LOOP
_BRT_WS_END:
        POP  DX
        POP  CX
        POP  BX
        POP  AX
        RET

_BRT_NEWLINE:
        PUSH  AX
        PUSH  DX
        MOV  DL, 0Dh
        MOV  AH, 2
        INT  21h
        MOV  DL, 0Ah
        MOV  AH, 2
        INT  21h
        POP  DX
        POP  AX
        RET

_BRT_WRITEN:
        PUSH  BX
        PUSH  CX
        PUSH  DX
        PUSH  SI
        XOR  SI, SI
        OR  AX, AX
        JNS  _BRT_WN_POS
        NEG  AX
        PUSH  AX
        MOV  DL, 2Dh
        MOV  AH, 2
        INT  21h
        POP  AX
_BRT_WN_POS:
        MOV  BX, 10
_BRT_WN_LOOP:
        XOR  DX, DX
        DIV  BX
        PUSH DX
        INC  SI
        OR  AX, AX
        JNZ  _BRT_WN_LOOP
_BRT_WN_PRINT:
        POP  DX
        ADD  DL, 30h
        MOV  AH, 2
        INT  21h
        DEC  SI
        JNZ  _BRT_WN_PRINT
        POP  SI
        POP  DX
        POP  CX
        POP  BX
        RET

_BRT_READCH:
        MOV  AH, 1
        INT  21h
        XOR  AH, AH
        RET

_BRT_READN:
        PUSH  BX
        PUSH  CX
        PUSH  DX
        PUSH  SI
        MOV  Byte Ptr [_BV_INBUF], 126
        LEA  DX, [_BV_INBUF]
        MOV  AH, 0Ah
        INT  21h
        MOV  DL, 0Dh
        MOV  AH, 2
        INT  21h
        MOV  DL, 0Ah
        MOV  AH, 2
        INT  21h
        LEA  SI, [_BV_INBUF+2]
        XOR  BX, BX
        XOR  DX, DX
        CMP  Byte Ptr [SI], 2Dh
        JNE  _BRT_RN_LOOP
        MOV  DX, 1
        INC  SI
_BRT_RN_LOOP:
        MOV  AL, [SI]
        CMP  AL, 30h
        JB  _BRT_RN_DONE
        CMP  AL, 39h
        JA  _BRT_RN_DONE
        SUB  AL, 30h
        XOR  AH, AH
        PUSH AX
        MOV  AX, BX
        MOV  CX, 10
        MUL  CX
        POP  CX
        ADD  AX, CX
        MOV  BX, AX
        INC  SI
        JMP  _BRT_RN_LOOP
_BRT_RN_DONE:
        MOV  AX, BX
        OR  DX, DX
        JZ  _BRT_RN_OK
        NEG  AX
_BRT_RN_OK:
        POP  SI
        POP  DX
        POP  CX
        POP  BX
        RET

_BRT_READS:
        PUSH  AX
        PUSH  CX
        PUSH  DX
        PUSH  SI
        PUSH  DI
        MOV  DI, BX
        MOV  Byte Ptr [_BV_INBUF], 126
        LEA  DX, [_BV_INBUF]
        MOV  AH, 0Ah
        INT  21h
        MOV  DL, 0Dh
        MOV  AH, 2
        INT  21h
        MOV  DL, 0Ah
        MOV  AH, 2
        INT  21h
        LEA  SI, [_BV_INBUF+2]
        XOR  AH, AH
        MOV  AL, [_BV_INBUF+1]
        MOV  CX, AX
        MOV  [DI], AL
        INC  DI
_BRT_RS_COPY:
        OR  CX, CX
        JZ  _BRT_RS_DONE
        MOV  AL, [SI]
        MOV  [DI], AL
        INC  SI
        INC  DI
        DEC  CX
        JMP  _BRT_RS_COPY
_BRT_RS_DONE:
        POP  DI
        POP  SI
        POP  DX
        POP  CX
        POP  AX
        RET

_BRT_WRITEF:
;  _BRT_WRITEF : formateur stub - imprime le format brut
        PUSH  BX
        MOV  AX, SI
        MOV  SI, AX
        CALL  _BRT_WRITES
        POP  BX
        RET

_BRT_STOP:
        MOV  AH, 4Ch
        INT  21h

_ORT_WRITESTR:
        PUSH  AX
        PUSH  DX
_ORT_WS_LOOP:
        MOV  DL, [SI]
        CMP  DL, 0
        JE  _ORT_WS_END
        MOV  AH, 2
        INT  21h
        INC  SI
        JMP  _ORT_WS_LOOP
_ORT_WS_END:
        POP  DX
        POP  AX
        RET

_ORT_WRITELN:
        PUSH  AX
        PUSH  DX
        MOV  DL, 0Dh
        MOV  AH, 2
        INT  21h
        MOV  DL, 0Ah
        MOV  AH, 2
        INT  21h
        POP  DX
        POP  AX
        RET

_ORT_WRITEINT:
        PUSH  BX
        PUSH  CX
        PUSH  DX
        PUSH  SI
        XOR  SI, SI
        OR  AX, AX
        JNS  _ORT_WI_POS
        NEG  AX
        PUSH  AX
        MOV  DL, 2Dh
        MOV  AH, 2
        INT  21h
        POP  AX
_ORT_WI_POS:
        MOV  BX, 10
_ORT_WI_LOOP:
        XOR  DX, DX
        DIV  BX
        PUSH DX
        INC  SI
        OR  AX, AX
        JNZ  _ORT_WI_LOOP
_ORT_WI_PRINT:
        POP  DX
        ADD  DL, 30h
        MOV  AH, 2
        INT  21h
        DEC  SI
        JNZ  _ORT_WI_PRINT
        POP  SI
        POP  DX
        POP  CX
        POP  BX
        RET

_ORT_READCHAR:
        MOV  AH, 1
        INT  21h
        XOR  AH, AH
        RET

_ORT_READINT:
        PUSH  BX
        PUSH  CX
        PUSH  DX
        PUSH  SI
        MOV  Byte Ptr [_OV_INBUF], 126
        LEA  DX, [_OV_INBUF]
        MOV  AH, 0Ah
        INT  21h
        MOV  DL, 0Dh
        MOV  AH, 2
        INT  21h
        MOV  DL, 0Ah
        MOV  AH, 2
        INT  21h
        LEA  SI, [_OV_INBUF+2]
        XOR  BX, BX
        XOR  DX, DX
        CMP  Byte Ptr [SI], 2Dh
        JNE  _ORT_RI_LOOP
        MOV  DX, 1
        INC  SI
_ORT_RI_LOOP:
        MOV  AL, [SI]
        CMP  AL, 30h
        JB  _ORT_RI_DONE
        CMP  AL, 39h
        JA  _ORT_RI_DONE
        SUB  AL, 30h
        XOR  AH, AH
        PUSH AX
        MOV  AX, BX
        MOV  CX, 10
        MUL  CX
        POP  CX
        ADD  AX, CX
        MOV  BX, AX
        INC  SI
        JMP  _ORT_RI_LOOP
_ORT_RI_DONE:
        MOV  AX, BX
        OR  DX, DX
        JZ  _ORT_RI_OK
        NEG  AX
_ORT_RI_OK:
        POP  SI
        POP  DX
        POP  CX
        POP  BX
        RET

_ORT_READSTR:
        PUSH  AX
        PUSH  CX
        PUSH  DX
        PUSH  SI
        PUSH  DI
        MOV  DI, BX
        MOV  Byte Ptr [_OV_INBUF], 126
        LEA  DX, [_OV_INBUF]
        MOV  AH, 0Ah
        INT  21h
        MOV  DL, 0Dh
        MOV  AH, 2
        INT  21h
        MOV  DL, 0Ah
        MOV  AH, 2
        INT  21h
        LEA  SI, [_OV_INBUF+2]
        XOR  AH, AH
        MOV  AL, [_OV_INBUF+1]
        MOV  CX, AX
_ORT_RS_COPY:
        OR  CX, CX
        JZ  _ORT_RS_DONE
        MOV  AL, [SI]
        MOV  [DI], AL
        INC  SI
        INC  DI
        DEC  CX
        JMP  _ORT_RS_COPY
_ORT_RS_DONE:
        MOV  Byte Ptr [DI], 0
        POP  DI
        POP  SI
        POP  DX
        POP  CX
        POP  AX
        RET

_ORT_BOUNDS_ERR:
        MOV  AX, 4C02h
        INT  21h

_ORT_NIL_ERR:
        MOV  AX, 4C03h
        INT  21h

_ORT_HEAP_ALLOC:
        PUSH  BX
        PUSH  DX
        ADD  BX, 1
        AND  BX, 0FFFEh
        MOV  AX, [_OV_HEAP_PTR]
        MOV  DX, AX
        ADD  DX, BX
        CMP  DX, OFFSET _OV_HEAP_BUF + 4096
        JA  _ORT_HA_OOM
        MOV  [_OV_HEAP_PTR], DX
        JMP  _ORT_HA_OK
_ORT_HA_OOM:
        XOR  AX, AX
_ORT_HA_OK:
        POP  DX
        POP  BX
        RET

_ORT_HEAP_FREE:
        RET

_BP_SAMPLES_BCPL_hello_START:
        PUSH  BP
        MOV  BP, SP
        PUSH  SI
        PUSH  DI
        PUSH  BX

        LEA  AX, [_BK_1]
        MOV  SI, AX
        CALL  _BRT_WRITES
        LEA  AX, [_BK_2]
        MOV  SI, AX
        CALL  _BRT_WRITES
        LEA  AX, [_BK_3]
        MOV  SI, AX
        CALL  _BRT_WRITES
        LEA  AX, [_BK_4]
        MOV  SI, AX
        CALL  _BRT_WRITES
        LEA  AX, [_BK_5]
        MOV  SI, AX
        CALL  _BRT_WRITES
        CALL  _BRT_NEWLINE
        LEA  AX, [_BK_6]
        MOV  SI, AX
        CALL  _BRT_WRITES
        LEA  AX, [_BK_7]
        MOV  SI, AX
        CALL  _BRT_WRITES
        CALL  _BRT_NEWLINE
        LEA  AX, [_BK_8]
        MOV  SI, AX
        CALL  _BRT_WRITES
        LEA  AX, [_BK_9]
        MOV  SI, AX
        CALL  _BRT_WRITES
        LEA  AX, [_BK_10]
        MOV  SI, AX
        CALL  _BRT_WRITES
        LEA  AX, [_BK_11]
        MOV  SI, AX
        CALL  _BRT_WRITES
_BP_START_RET:

        POP  BX
        POP  DI
        POP  SI
        MOV  SP, BP
        POP  BP
        RET

;  END START


_CODE           ENDS


;  ----- Chaines litterales differees -----
_DATA           SEGMENT WORD PUBLIC 'DATA'

_BK_1                   DB      31, '==============================', 10d
_BK_2                   DB      19, '  Bonjour, Monde !', 10d
_BK_3                   DB      16, '  Hello, World!', 10d
_BK_4                   DB      15, '  Hola, Mundo!', 10d
_BK_5                   DB      31, '==============================', 10d
_BK_6                   DB      35, 'Programme compile avec BCPL86 v1.0', 10d
_BK_7                   DB      29, 'Systeme  : 8086 / DOS (MASM)', 10d
_BK_8                   DB      27, 'Caracteres speciaux BCPL :', 10d
_BK_9                   DB      23, '  Tabulation -> ici', 9d, 'la', 10d
_BK_10                  DB      29, '  Quotes     -> "guillemets"', 10d
_BK_11                  DB      25, '  Asterisque -> *etoile*', 10d

_DATA           ENDS

                END     START
