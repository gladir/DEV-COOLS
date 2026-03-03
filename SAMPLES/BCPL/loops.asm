; ------------------------------------------------------------
;  Fichier genere par BCPL86 v1.0
;  Date   : 2026-03-03
;  Source : SAMPLES\BCPL\loops.b
;  Section: SAMPLES\BCPL\loops
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
;  ====== RUNTIME BCPL (BRT) - BCPL86 TODO 20 ====== 

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
;  _BRT_WRITEF : formateur stub - imprime le format brut en TODO 19
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

_BP_SAMPLES_BCPL_loops_PRINTLINE:
        PUSH  BP
        MOV  BP, SP
        PUSH  SI
        PUSH  DI
        PUSH  BX

        LEA  AX, [_BK_1]
        MOV  SI, AX
        CALL  _BRT_WRITES
_BP_PRINTLINE_RET:

        POP  BX
        POP  DI
        POP  SI
        MOV  SP, BP
        POP  BP
        RET

;  END PRINTLINE

_BP_SAMPLES_BCPL_loops_START:
        PUSH  BP
        MOV  BP, SP
        PUSH  SI
        PUSH  DI
        PUSH  BX

        MOV  AX, 0
        MOV  [BP-2], AX
        MOV  AX, 0
        MOV  [BP-4], AX
        CALL  _BP_SAMPLES_BCPL_loops_PRINTLINE
        LEA  AX, [_BK_2]
        MOV  SI, AX
        CALL  _BRT_WRITES
        MOV  AX, 1
        MOV  [BP-2], AX
        MOV  AX, 10
        MOV  SI, AX
_BL_1:
        MOV  AX, [BP-2]
        CMP  AX, SI
        JG  _BL_2
        MOV  AX, [BP-2]
        CALL  _BRT_WRITEN
        MOV  AX, 32
        PUSH  AX
        PUSH  DX
        MOV  DL, AL
        MOV  AH, 2
        INT  21h
        POP  DX
        POP  AX
        MOV  AX, [BP-2]
        INC  AX
        MOV  [BP-2], AX
        JMP  _BL_1
_BL_2:
        CALL  _BRT_NEWLINE
        CALL  _BP_SAMPLES_BCPL_loops_PRINTLINE
        LEA  AX, [_BK_3]
        MOV  SI, AX
        CALL  _BRT_WRITES
        MOV  AX, 10
        MOV  [BP-2], AX
        MOV  AX, 1
        MOV  SI, AX
_BL_3:
        MOV  AX, [BP-2]
        CMP  AX, SI
        JL  _BL_4
        MOV  AX, [BP-2]
        CALL  _BRT_WRITEN
        MOV  AX, 32
        PUSH  AX
        PUSH  DX
        MOV  DL, AL
        MOV  AH, 2
        INT  21h
        POP  DX
        POP  AX
        MOV  AX, [BP-2]
        DEC  AX
        MOV  [BP-2], AX
        JMP  _BL_3
_BL_4:
        CALL  _BRT_NEWLINE
        CALL  _BP_SAMPLES_BCPL_loops_PRINTLINE
        LEA  AX, [_BK_4]
        MOV  SI, AX
        CALL  _BRT_WRITES
        MOV  AX, 0
        MOV  [BP-4], AX
        MOV  AX, 1
        MOV  [BP-2], AX
        MOV  AX, 100
        MOV  SI, AX
_BL_5:
        MOV  AX, [BP-2]
        CMP  AX, SI
        JG  _BL_6
        MOV  AX, [BP-4]
        PUSH AX
        MOV  AX, [BP-2]
        MOV  CX, AX
        POP  AX
        ADD  AX, CX
        MOV  [BP-4], AX
        MOV  AX, [BP-2]
        INC  AX
        MOV  [BP-2], AX
        JMP  _BL_5
_BL_6:
        LEA  AX, [_BK_5]
        MOV  SI, AX
        CALL  _BRT_WRITES
        MOV  AX, [BP-4]
        CALL  _BRT_WRITEN
        CALL  _BRT_NEWLINE
        CALL  _BP_SAMPLES_BCPL_loops_PRINTLINE
        LEA  AX, [_BK_6]
        MOV  SI, AX
        CALL  _BRT_WRITES
        MOV  AX, 1
        MOV  [BP-2], AX
_BL_7:
        MOV  AX, [BP-2]
        PUSH AX
        MOV  AX, 1024
        MOV  CX, AX
        POP  AX
        CMP  AX, CX
        JLE  _BL_9
        MOV  AX, 0
        JMP  _BL_10
_BL_9:
        MOV  AX, 0FFFFh
_BL_10:
        CMP  AX, 0
        JE  _BL_8
        MOV  AX, [BP-2]
        CALL  _BRT_WRITEN
        MOV  AX, 32
        PUSH  AX
        PUSH  DX
        MOV  DL, AL
        MOV  AH, 2
        INT  21h
        POP  DX
        POP  AX
        MOV  AX, [BP-2]
        PUSH AX
        MOV  AX, 2
        MOV  CX, AX
        POP  AX
        IMUL CX
        MOV  [BP-2], AX
        JMP  _BL_7
_BL_8:
        CALL  _BRT_NEWLINE
        CALL  _BP_SAMPLES_BCPL_loops_PRINTLINE
        LEA  AX, [_BK_7]
        MOV  SI, AX
        CALL  _BRT_WRITES
        MOV  AX, 0
        MOV  [BP-2], AX
_BL_11:
        MOV  AX, [BP-2]
        PUSH AX
        MOV  AX, 10
        MOV  CX, AX
        POP  AX
        CMP  AX, CX
        JE  _BL_13
        MOV  AX, 0
        JMP  _BL_14
_BL_13:
        MOV  AX, 0FFFFh
_BL_14:
        CMP  AX, 0
        JNE  _BL_12
        MOV  AX, [BP-2]
        CALL  _BRT_WRITEN
        MOV  AX, 32
        PUSH  AX
        PUSH  DX
        MOV  DL, AL
        MOV  AH, 2
        INT  21h
        POP  DX
        POP  AX
        MOV  AX, [BP-2]
        PUSH AX
        MOV  AX, 1
        MOV  CX, AX
        POP  AX
        ADD  AX, CX
        MOV  [BP-2], AX
        JMP  _BL_11
_BL_12:
        CALL  _BRT_NEWLINE
        CALL  _BP_SAMPLES_BCPL_loops_PRINTLINE
        LEA  AX, [_BK_8]
        MOV  SI, AX
        CALL  _BRT_WRITES
        MOV  AX, 1
        MOV  [BP-2], AX
_BL_15:
        MOV  AX, [BP-2]
        CALL  _BRT_WRITEN
        LEA  AX, [_BK_9]
        MOV  SI, AX
        CALL  _BRT_WRITES
        MOV  AX, [BP-2]
        PUSH AX
        MOV  AX, 7
        MOV  CX, AX
        POP  AX
        IMUL CX
        CALL  _BRT_WRITEN
        CALL  _BRT_NEWLINE
        MOV  AX, [BP-2]
        PUSH AX
        MOV  AX, 1
        MOV  CX, AX
        POP  AX
        ADD  AX, CX
        MOV  [BP-2], AX
        MOV  AX, [BP-2]
        PUSH AX
        MOV  AX, 5
        MOV  CX, AX
        POP  AX
        CMP  AX, CX
        JLE  _BL_17
        MOV  AX, 0
        JMP  _BL_18
_BL_17:
        MOV  AX, 0FFFFh
_BL_18:
        CMP  AX, 0
        JNE  _BL_15
_BL_16:
        CALL  _BP_SAMPLES_BCPL_loops_PRINTLINE
        LEA  AX, [_BK_10]
        MOV  SI, AX
        CALL  _BRT_WRITES
        MOV  AX, 1
        MOV  [BP-2], AX
        MOV  AX, 100
        MOV  SI, AX
_BL_19:
        MOV  AX, [BP-2]
        CMP  AX, SI
        JG  _BL_20
        MOV  AX, [BP-2]
        PUSH AX
        MOV  AX, 5
        MOV  CX, AX
        POP  AX
        CMP  AX, CX
        JG  _BL_23
        MOV  AX, 0
        JMP  _BL_24
_BL_23:
        MOV  AX, 0FFFFh
_BL_24:
        CMP  AX, 0
        JE  _BL_21
        JMP  _BL_20
        JMP  _BL_22
_BL_21:
_BL_22:
        MOV  AX, [BP-2]
        CALL  _BRT_WRITEN
        MOV  AX, 32
        PUSH  AX
        PUSH  DX
        MOV  DL, AL
        MOV  AH, 2
        INT  21h
        POP  DX
        POP  AX
        MOV  AX, [BP-2]
        INC  AX
        MOV  [BP-2], AX
        JMP  _BL_19
_BL_20:
        CALL  _BRT_NEWLINE
        CALL  _BP_SAMPLES_BCPL_loops_PRINTLINE
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


;  ----- Chaines litterales differees (TODO 25) -----
_DATA           SEGMENT WORD PUBLIC 'DATA'

_BK_1                   DB      31, '------------------------------', 10d
_BK_2                   DB      16, 'FOR i = 1 TO 10', 10d
_BK_3                   DB      22, 'FOR i = 10 TO 1 BY -1', 10d
_BK_4                   DB      22, 'Somme 1..100 avec FOR', 10d
_BK_5                   DB      22, '  1 + 2 + ... + 100 = '
_BK_6                   DB      27, 'Puissances de 2 avec WHILE', 10d
_BK_7                   DB      23, 'Compte 0..9 avec UNTIL', 10d
_BK_8                   DB      21, 'Tableau  avec REPEAT', 10d
_BK_9                   DB      6, '  7 = '
_BK_10                  DB      21, 'FOR avec BREAK a i=5', 10d
_BK_11                  DB      17, 'Fin des boucles.', 10d

_DATA           ENDS

                END     START
