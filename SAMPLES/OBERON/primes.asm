; ------------------------------------------------------------
;  Fichier genere par OBERON86 v1.0
;  Date   : 2026-03-03
;  Source : C:\SOURCE\GITHUB\DEV-COOLS\primes.obn
;  Module : Primes
;  Cible  : MASM 8086, modele SMALL, near cdecl
; ------------------------------------------------------------

        .MODEL  SMALL
        .8086

;  ----- Segment STACK -----
_STACK          SEGMENT PARA STACK 'STACK'
                DB      512 DUP (?)
_STACK          ENDS

;  ----- Segment DATA -----
_DATA           SEGMENT WORD PUBLIC 'DATA'

;  ----- Variables systeme OBERON86 -----
_OV_OUTBUF              DB      256 DUP(0)
_OV_INBUF               DB      128 DUP(0)
_OV_INTBUF              DB      12 DUP(0)
_OV_CRLF                DB      0Dh, 0Ah, '$'
_OV_NULLSTR             DB      0
_OV_TRUE                DB      'TRUE', 0
_OV_FALSE               DB      'FALSE', 0
_OV_IN_DONE             DW      1
_OV_HEAP_PTR            DW      0
_OV_HEAP_BUF            DB      4096 DUP(0)

_OV_i                   DW      0
_OV_j                   DW      0
_OV_prime               DW      0
_OV_count               DW      0

_DATA           ENDS

;  ----- Segment CODE -----
_CODE           SEGMENT WORD PUBLIC 'CODE'

                ASSUME CS:_CODE, DS:_DATA, SS:_STACK

START:
        MOV  AX, _DATA
        MOV  DS, AX
        MOV  AX, OFFSET _OV_HEAP_BUF
        MOV  [_OV_HEAP_PTR], AX

        MOV  AX, 0
        MOV  [_OV_count], AX
        LEA  AX, [_OK_1]
        MOV  SI, AX
        CALL  _ORT_WRITESTR
        CALL  _ORT_WRITELN
        LEA  AX, [_OK_2]
        MOV  SI, AX
        CALL  _ORT_WRITESTR
        MOV  AX, 2
        MOV  [_OV_i], AX
        MOV  AX, 49
        MOV  SI, AX
_OL_1:
        MOV  AX, [_OV_i]
        CMP  AX, SI
        JG  _OL_2
        MOV  AX, 1
        MOV  [_OV_prime], AX
        MOV  AX, 2
        MOV  [_OV_j], AX
_OL_3:
        MOV  AX, [_OV_j]
        PUSH AX
        MOV  AX, [_OV_j]
        MOV  CX, AX
        POP  AX
        IMUL CX
        PUSH AX
        MOV  AX, [_OV_i]
        MOV  CX, AX
        POP  AX
        CMP  AX, CX
        MOV  AX, 0
        JG  _OL_5
        MOV  AX, 1
_OL_5:
        CMP  AX, 0
        JE  _OL_4
        MOV  AX, [_OV_i]
        PUSH AX
        MOV  AX, [_OV_j]
        MOV  CX, AX
        POP  AX
        CWD
        IDIV CX
        MOV  AX, DX
        PUSH AX
        MOV  AX, 0
        MOV  CX, AX
        POP  AX
        CMP  AX, CX
        MOV  AX, 0
        JNE  _OL_8
        MOV  AX, 1
_OL_8:
        CMP  AX, 0
        JE  _OL_7
        MOV  AX, 0
        MOV  [_OV_prime], AX
        JMP  _OL_6
_OL_7:
_OL_6:
        LEA  BX, [_OV_j]
        INC  Word Ptr [BX]
        JMP  _OL_3
_OL_4:
        MOV  AX, [_OV_prime]
        PUSH AX
        MOV  AX, 1
        MOV  CX, AX
        POP  AX
        CMP  AX, CX
        MOV  AX, 0
        JNE  _OL_11
        MOV  AX, 1
_OL_11:
        CMP  AX, 0
        JE  _OL_10
        MOV  AX, [_OV_i]
        PUSH AX
        MOV  AX, 0
        POP  AX
        CALL  _ORT_WRITEINT
        LEA  AX, [_OK_3]
        MOV  SI, AX
        CALL  _ORT_WRITESTR
        LEA  BX, [_OV_count]
        INC  Word Ptr [BX]
        JMP  _OL_9
_OL_10:
_OL_9:
        MOV  AX, [_OV_i]
        INC  AX
        MOV  [_OV_i], AX
        JMP  _OL_1
_OL_2:
        CALL  _ORT_WRITELN
        LEA  AX, [_OK_4]
        MOV  SI, AX
        CALL  _ORT_WRITESTR
        MOV  AX, [_OV_count]
        PUSH AX
        MOV  AX, 0
        POP  AX
        CALL  _ORT_WRITEINT
        CALL  _ORT_WRITELN

;  Fin normale du programme
        MOV  AX, 4C00h
        INT  21h

; ------------------------------------------------------------
;  ====== RUNTIME Out / In - OBERON86 TODO 20 ====== 

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


_CODE           ENDS


;  ----- Chaines litterales differees (TODO 25) -----
_DATA           SEGMENT WORD PUBLIC 'DATA'

_OK_1                   DB      'Nombres premiers < 50 :', 0
_OK_2                   DB      '  ', 0
_OK_3                   DB      ' ', 0
_OK_4                   DB      'Total : ', 0

_DATA           ENDS

                END     START
