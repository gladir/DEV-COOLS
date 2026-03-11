; SAS86 v1.0 - SAMPLES/SAS/test_functions.sas
.MODEL SMALL
.STACK 1024

_TEXT SEGMENT PUBLIC 'CODE'
        ASSUME CS:_TEXT, DS:_DATA, SS:STACK

_SASP_Main:
        PUSH BP
        MOV BP, SP
        MOV AX, _DATA
        MOV DS, AX


; ========= DATA STEP =========
; dataset: TEST1
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_1:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV AX, -42
; stocker X
        MOV [_SAS_PDV], AX
; ABS()
; charger X
        MOV AX, [_SAS_PDV]
        TEST AX, AX
        JNS _SASL_4
        NEG AX
_SASL_4:
; stocker Y
        MOV [_SAS_PDV + 2], AX
; PUT
; PUT Y
; charger Y
        MOV AX, [_SAS_PDV + 2]
        CALL _SASRT_PUTNUM
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_3:
; OUTPUT : copier PDV -> dataset TEST1
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_2:
; ========= FIN DATA STEP TEST1 =========


; ========= DATA STEP =========
; dataset: TEST2
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_5:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV AX, 123
; stocker X
        MOV [_SAS_PDV], AX
; INT()
; charger X
        MOV AX, [_SAS_PDV]
; stocker Y
        MOV [_SAS_PDV + 2], AX
; PUT
; PUT Y
; charger Y
        MOV AX, [_SAS_PDV + 2]
        CALL _SASRT_PUTNUM
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_7:
; OUTPUT : copier PDV -> dataset TEST2
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_6:
; ========= FIN DATA STEP TEST2 =========


; ========= DATA STEP =========
; dataset: TEST3
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_8:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
; SIGN()
        MOV AX, -10
        CMP AX, 0
        JG _SASL_11
        JGE _SASL_12
        MOV AX, -1
        JMP _SASL_12
_SASL_11:
        MOV AX, 1
_SASL_12:
; stocker A
        MOV [_SAS_PDV + 4], AX
; SIGN()
        XOR AX, AX
        CMP AX, 0
        JG _SASL_13
        JGE _SASL_14
        MOV AX, -1
        JMP _SASL_14
_SASL_13:
        MOV AX, 1
_SASL_14:
; stocker B
        MOV [_SAS_PDV + 6], AX
; SIGN()
        MOV AX, 5
        CMP AX, 0
        JG _SASL_15
        JGE _SASL_16
        MOV AX, -1
        JMP _SASL_16
_SASL_15:
        MOV AX, 1
_SASL_16:
; stocker C
        MOV [_SAS_PDV + 8], AX
; PUT
; PUT A
; charger A
        MOV AX, [_SAS_PDV + 4]
        CALL _SASRT_PUTNUM
; PUT B
; charger B
        MOV AX, [_SAS_PDV + 6]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; PUT C
; charger C
        MOV AX, [_SAS_PDV + 8]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_10:
; OUTPUT : copier PDV -> dataset TEST3
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_9:
; ========= FIN DATA STEP TEST3 =========


; ========= DATA STEP =========
; dataset: TEST4
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_17:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
        MOV WORD PTR [_SAS_PDV + 6], -32768
        MOV WORD PTR [_SAS_PDV + 8], -32768
; MOD()
        MOV AX, 17
        PUSH AX
        MOV AX, 5
        MOV BX, AX
        POP AX
        CWD
        IDIV BX
        MOV AX, DX
; stocker X
        MOV [_SAS_PDV], AX
; PUT
; PUT X
; charger X
        MOV AX, [_SAS_PDV]
        CALL _SASRT_PUTNUM
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_19:
; OUTPUT : copier PDV -> dataset TEST4
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_18:
; ========= FIN DATA STEP TEST4 =========


; ========= DATA STEP =========
; dataset: TEST5
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_20:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
        MOV WORD PTR [_SAS_PDV + 6], -32768
        MOV WORD PTR [_SAS_PDV + 8], -32768
; MIN()
        MOV AX, 10
        PUSH AX
        MOV AX, 20
        MOV BX, AX
        POP AX
        CALL _SASRT_MIN
; stocker A
        MOV [_SAS_PDV + 4], AX
; MAX()
        MOV AX, 10
        PUSH AX
        MOV AX, 20
        MOV BX, AX
        POP AX
        CALL _SASRT_MAX
; stocker B
        MOV [_SAS_PDV + 6], AX
; PUT
; PUT A
; charger A
        MOV AX, [_SAS_PDV + 4]
        CALL _SASRT_PUTNUM
; PUT B
; charger B
        MOV AX, [_SAS_PDV + 6]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_22:
; OUTPUT : copier PDV -> dataset TEST5
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_21:
; ========= FIN DATA STEP TEST5 =========


; ========= DATA STEP =========
; dataset: TEST6
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_23:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
        MOV WORD PTR [_SAS_PDV + 6], -32768
        MOV WORD PTR [_SAS_PDV + 8], -32768
; SUM()
        MOV AX, 1
        PUSH AX
        MOV AX, 2
        MOV BX, AX
        POP AX
        ADD AX, BX
        PUSH AX
        MOV AX, 3
        MOV BX, AX
        POP AX
        ADD AX, BX
        PUSH AX
        MOV AX, 4
        MOV BX, AX
        POP AX
        ADD AX, BX
        PUSH AX
        MOV AX, 5
        MOV BX, AX
        POP AX
        ADD AX, BX
; stocker TOTAL
        MOV [_SAS_PDV + 10], AX
; PUT
; PUT TOTAL
; charger TOTAL
        MOV AX, [_SAS_PDV + 10]
        CALL _SASRT_PUTNUM
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_25:
; OUTPUT : copier PDV -> dataset TEST6
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_24:
; ========= FIN DATA STEP TEST6 =========


; ========= DATA STEP =========
; dataset: TEST7
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_26:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
        MOV WORD PTR [_SAS_PDV + 6], -32768
        MOV WORD PTR [_SAS_PDV + 8], -32768
        MOV WORD PTR [_SAS_PDV + 10], -32768
; ROUND()
        MOV AX, 27
; stocker X
        MOV [_SAS_PDV], AX
; CEIL()
        MOV AX, 15
; stocker Y
        MOV [_SAS_PDV + 2], AX
; FLOOR()
        MOV AX, 15
; stocker Z
        MOV [_SAS_PDV + 12], AX
; PUT
; PUT X
; charger X
        MOV AX, [_SAS_PDV]
        CALL _SASRT_PUTNUM
; PUT Y
; charger Y
        MOV AX, [_SAS_PDV + 2]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; PUT Z
; charger Z
        MOV AX, [_SAS_PDV + 12]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_28:
; OUTPUT : copier PDV -> dataset TEST7
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_27:
; ========= FIN DATA STEP TEST7 =========


; ========= DATA STEP =========
; dataset: TEST8
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_29:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
        MOV WORD PTR [_SAS_PDV + 6], -32768
        MOV WORD PTR [_SAS_PDV + 8], -32768
        MOV WORD PTR [_SAS_PDV + 10], -32768
        MOV WORD PTR [_SAS_PDV + 12], -32768
        MOV AX, OFFSET _SASK_32
; stocker X
        MOV [_SAS_PDV], AX
; LENGTH()
; charger X
        MOV AX, [_SAS_PDV]
        CALL _SASRT_STRLEN
; stocker N
        MOV [_SAS_PDV + 14], AX
; PUT
; PUT N
; charger N
        MOV AX, [_SAS_PDV + 14]
        CALL _SASRT_PUTNUM
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_31:
; OUTPUT : copier PDV -> dataset TEST8
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_30:
; ========= FIN DATA STEP TEST8 =========


; ========= DATA STEP =========
; dataset: TEST9
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_33:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
        MOV WORD PTR [_SAS_PDV + 6], -32768
        MOV WORD PTR [_SAS_PDV + 8], -32768
        MOV WORD PTR [_SAS_PDV + 10], -32768
        MOV WORD PTR [_SAS_PDV + 12], -32768
        MOV WORD PTR [_SAS_PDV + 14], -32768
        MOV AX, OFFSET _SASK_36
; stocker X
        MOV [_SAS_PDV], AX
; UPCASE()
; charger X
        MOV AX, [_SAS_PDV]
        CALL _SASRT_UPCASE
; stocker U
        MOV [_SAS_PDV + 16], AX
; LOWCASE()
; charger X
        MOV AX, [_SAS_PDV]
        CALL _SASRT_LOWCASE
; stocker L
        MOV [_SAS_PDV + 18], AX
; PUT
; PUT U
; charger U
        MOV AX, [_SAS_PDV + 16]
        CALL _SASRT_PUTNUM
; PUT L
; charger L
        MOV AX, [_SAS_PDV + 18]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_35:
; OUTPUT : copier PDV -> dataset TEST9
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_34:
; ========= FIN DATA STEP TEST9 =========


; ========= DATA STEP =========
; dataset: TEST10
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_37:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
        MOV WORD PTR [_SAS_PDV + 6], -32768
        MOV WORD PTR [_SAS_PDV + 8], -32768
        MOV WORD PTR [_SAS_PDV + 10], -32768
        MOV WORD PTR [_SAS_PDV + 12], -32768
        MOV WORD PTR [_SAS_PDV + 14], -32768
        MOV WORD PTR [_SAS_PDV + 16], -32768
        MOV WORD PTR [_SAS_PDV + 18], -32768
        MOV AX, OFFSET _SASK_40
; stocker X
        MOV [_SAS_PDV], AX
; TRIM()
; charger X
        MOV AX, [_SAS_PDV]
        CALL _SASRT_TRIM
; stocker Y
        MOV [_SAS_PDV + 2], AX
; PUT
; PUT Y
; charger Y
        MOV AX, [_SAS_PDV + 2]
        CALL _SASRT_PUTNUM
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_39:
; OUTPUT : copier PDV -> dataset TEST10
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_38:
; ========= FIN DATA STEP TEST10 =========


; ========= DATA STEP =========
; dataset: TEST11
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_41:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
        MOV WORD PTR [_SAS_PDV + 6], -32768
        MOV WORD PTR [_SAS_PDV + 8], -32768
        MOV WORD PTR [_SAS_PDV + 10], -32768
        MOV WORD PTR [_SAS_PDV + 12], -32768
        MOV WORD PTR [_SAS_PDV + 14], -32768
        MOV WORD PTR [_SAS_PDV + 16], -32768
        MOV WORD PTR [_SAS_PDV + 18], -32768
        MOV AX, OFFSET _SASK_44
; stocker X
        MOV [_SAS_PDV], AX
; LEFT()
; charger X
        MOV AX, [_SAS_PDV]
        CALL _SASRT_LEFT
; stocker Y
        MOV [_SAS_PDV + 2], AX
; PUT
; PUT Y
; charger Y
        MOV AX, [_SAS_PDV + 2]
        CALL _SASRT_PUTNUM
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_43:
; OUTPUT : copier PDV -> dataset TEST11
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_42:
; ========= FIN DATA STEP TEST11 =========


; ========= DATA STEP =========
; dataset: TEST12
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_45:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
        MOV WORD PTR [_SAS_PDV + 6], -32768
        MOV WORD PTR [_SAS_PDV + 8], -32768
        MOV WORD PTR [_SAS_PDV + 10], -32768
        MOV WORD PTR [_SAS_PDV + 12], -32768
        MOV WORD PTR [_SAS_PDV + 14], -32768
        MOV WORD PTR [_SAS_PDV + 16], -32768
        MOV WORD PTR [_SAS_PDV + 18], -32768
        MOV AX, OFFSET _SASK_48
; stocker X
        MOV [_SAS_PDV], AX
; SUBSTR()
; charger X
        MOV AX, [_SAS_PDV]
        PUSH AX
        MOV AX, 1
        PUSH AX
        MOV AX, 7
        MOV CX, AX
        POP BX
        POP SI
        CALL _SASRT_SUBSTR
; stocker Y
        MOV [_SAS_PDV + 2], AX
; PUT
; PUT Y
; charger Y
        MOV AX, [_SAS_PDV + 2]
        CALL _SASRT_PUTNUM
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_47:
; OUTPUT : copier PDV -> dataset TEST12
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_46:
; ========= FIN DATA STEP TEST12 =========


; ========= DATA STEP =========
; dataset: TEST13
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_49:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
        MOV WORD PTR [_SAS_PDV + 6], -32768
        MOV WORD PTR [_SAS_PDV + 8], -32768
        MOV WORD PTR [_SAS_PDV + 10], -32768
        MOV WORD PTR [_SAS_PDV + 12], -32768
        MOV WORD PTR [_SAS_PDV + 14], -32768
        MOV WORD PTR [_SAS_PDV + 16], -32768
        MOV WORD PTR [_SAS_PDV + 18], -32768
        MOV AX, OFFSET _SASK_52
; stocker X
        MOV [_SAS_PDV], AX
; SUBSTR()
; charger X
        MOV AX, [_SAS_PDV]
        PUSH AX
        MOV AX, 7
        PUSH AX
        MOV AX, -1
        MOV CX, AX
        POP BX
        POP SI
        CALL _SASRT_SUBSTR
; stocker Y
        MOV [_SAS_PDV + 2], AX
; PUT
; PUT Y
; charger Y
        MOV AX, [_SAS_PDV + 2]
        CALL _SASRT_PUTNUM
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_51:
; OUTPUT : copier PDV -> dataset TEST13
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_50:
; ========= FIN DATA STEP TEST13 =========


; ========= DATA STEP =========
; dataset: TEST14
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_53:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
        MOV WORD PTR [_SAS_PDV + 6], -32768
        MOV WORD PTR [_SAS_PDV + 8], -32768
        MOV WORD PTR [_SAS_PDV + 10], -32768
        MOV WORD PTR [_SAS_PDV + 12], -32768
        MOV WORD PTR [_SAS_PDV + 14], -32768
        MOV WORD PTR [_SAS_PDV + 16], -32768
        MOV WORD PTR [_SAS_PDV + 18], -32768
        MOV AX, OFFSET _SASK_56
; stocker X
        MOV [_SAS_PDV], AX
; INDEX()
; charger X
        MOV AX, [_SAS_PDV]
        PUSH AX
        MOV AX, OFFSET _SASK_57
        MOV DI, AX
        POP SI
        CALL _SASRT_INDEX
; stocker POS
        MOV [_SAS_PDV + 20], AX
; PUT
; PUT POS
; charger POS
        MOV AX, [_SAS_PDV + 20]
        CALL _SASRT_PUTNUM
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_55:
; OUTPUT : copier PDV -> dataset TEST14
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_54:
; ========= FIN DATA STEP TEST14 =========


; ========= DATA STEP =========
; dataset: TEST15
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_58:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
        MOV WORD PTR [_SAS_PDV + 6], -32768
        MOV WORD PTR [_SAS_PDV + 8], -32768
        MOV WORD PTR [_SAS_PDV + 10], -32768
        MOV WORD PTR [_SAS_PDV + 12], -32768
        MOV WORD PTR [_SAS_PDV + 14], -32768
        MOV WORD PTR [_SAS_PDV + 16], -32768
        MOV WORD PTR [_SAS_PDV + 18], -32768
        MOV WORD PTR [_SAS_PDV + 20], -32768
        MOV AX, OFFSET _SASK_61
; stocker X
        MOV [_SAS_PDV], AX
; COMPRESS()
; charger X
        MOV AX, [_SAS_PDV]
        PUSH AX
        XOR DI, DI
        POP AX
        CALL _SASRT_COMPRESS
; stocker Y
        MOV [_SAS_PDV + 2], AX
; PUT
; PUT Y
; charger Y
        MOV AX, [_SAS_PDV + 2]
        CALL _SASRT_PUTNUM
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_60:
; OUTPUT : copier PDV -> dataset TEST15
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_59:
; ========= FIN DATA STEP TEST15 =========


; ========= DATA STEP =========
; dataset: TEST16
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_62:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
        MOV WORD PTR [_SAS_PDV + 6], -32768
        MOV WORD PTR [_SAS_PDV + 8], -32768
        MOV WORD PTR [_SAS_PDV + 10], -32768
        MOV WORD PTR [_SAS_PDV + 12], -32768
        MOV WORD PTR [_SAS_PDV + 14], -32768
        MOV WORD PTR [_SAS_PDV + 16], -32768
        MOV WORD PTR [_SAS_PDV + 18], -32768
        MOV WORD PTR [_SAS_PDV + 20], -32768
        MOV AX, OFFSET _SASK_65
; stocker X
        MOV [_SAS_PDV], AX
; COMPRESS()
; charger X
        MOV AX, [_SAS_PDV]
        PUSH AX
        MOV AX, OFFSET _SASK_66
        MOV DI, AX
        POP AX
        CALL _SASRT_COMPRESS
; stocker Y
        MOV [_SAS_PDV + 2], AX
; PUT
; PUT Y
; charger Y
        MOV AX, [_SAS_PDV + 2]
        CALL _SASRT_PUTNUM
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_64:
; OUTPUT : copier PDV -> dataset TEST16
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_63:
; ========= FIN DATA STEP TEST16 =========


; ========= DATA STEP =========
; dataset: TEST17
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_67:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
        MOV WORD PTR [_SAS_PDV + 6], -32768
        MOV WORD PTR [_SAS_PDV + 8], -32768
        MOV WORD PTR [_SAS_PDV + 10], -32768
        MOV WORD PTR [_SAS_PDV + 12], -32768
        MOV WORD PTR [_SAS_PDV + 14], -32768
        MOV WORD PTR [_SAS_PDV + 16], -32768
        MOV WORD PTR [_SAS_PDV + 18], -32768
        MOV WORD PTR [_SAS_PDV + 20], -32768
        MOV AX, OFFSET _SASK_70
; stocker A
        MOV [_SAS_PDV + 4], AX
        MOV AX, OFFSET _SASK_71
; stocker B
        MOV [_SAS_PDV + 6], AX
; CAT()
; charger A
        MOV AX, [_SAS_PDV + 4]
        PUSH AX
; charger B
        MOV AX, [_SAS_PDV + 6]
        MOV DI, AX
        POP SI
        CALL _SASRT_STRCAT
; stocker C
        MOV [_SAS_PDV + 8], AX
; PUT
; PUT C
; charger C
        MOV AX, [_SAS_PDV + 8]
        CALL _SASRT_PUTNUM
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_69:
; OUTPUT : copier PDV -> dataset TEST17
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_68:
; ========= FIN DATA STEP TEST17 =========


; ========= DATA STEP =========
; dataset: TEST18
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_72:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
        MOV WORD PTR [_SAS_PDV + 6], -32768
        MOV WORD PTR [_SAS_PDV + 8], -32768
        MOV WORD PTR [_SAS_PDV + 10], -32768
        MOV WORD PTR [_SAS_PDV + 12], -32768
        MOV WORD PTR [_SAS_PDV + 14], -32768
        MOV WORD PTR [_SAS_PDV + 16], -32768
        MOV WORD PTR [_SAS_PDV + 18], -32768
        MOV WORD PTR [_SAS_PDV + 20], -32768
        MOV AX, 42
; stocker N
        MOV [_SAS_PDV + 14], AX
; PUT()
; charger N
        MOV AX, [_SAS_PDV + 14]
        CALL _SASRT_NUM2STR
; stocker S
        MOV [_SAS_PDV + 22], AX
; PUT
; PUT S
; charger S
        MOV AX, [_SAS_PDV + 22]
        CALL _SASRT_PUTNUM
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_74:
; OUTPUT : copier PDV -> dataset TEST18
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_73:
; ========= FIN DATA STEP TEST18 =========


; ========= DATA STEP =========
; dataset: TEST19
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_75:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
        MOV WORD PTR [_SAS_PDV + 6], -32768
        MOV WORD PTR [_SAS_PDV + 8], -32768
        MOV WORD PTR [_SAS_PDV + 10], -32768
        MOV WORD PTR [_SAS_PDV + 12], -32768
        MOV WORD PTR [_SAS_PDV + 14], -32768
        MOV WORD PTR [_SAS_PDV + 16], -32768
        MOV WORD PTR [_SAS_PDV + 18], -32768
        MOV WORD PTR [_SAS_PDV + 20], -32768
        MOV WORD PTR [_SAS_PDV + 22], -32768
; TODAY()
        MOV AX, 24176
; stocker D
        MOV [_SAS_PDV + 24], AX
; PUT
; PUT D
; charger D
        MOV AX, [_SAS_PDV + 24]
        CALL _SASRT_PUTNUM
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_77:
; OUTPUT : copier PDV -> dataset TEST19
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_76:
; ========= FIN DATA STEP TEST19 =========


; ========= DATA STEP =========
; dataset: TEST20
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_78:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
        MOV WORD PTR [_SAS_PDV + 6], -32768
        MOV WORD PTR [_SAS_PDV + 8], -32768
        MOV WORD PTR [_SAS_PDV + 10], -32768
        MOV WORD PTR [_SAS_PDV + 12], -32768
        MOV WORD PTR [_SAS_PDV + 14], -32768
        MOV WORD PTR [_SAS_PDV + 16], -32768
        MOV WORD PTR [_SAS_PDV + 18], -32768
        MOV WORD PTR [_SAS_PDV + 20], -32768
        MOV WORD PTR [_SAS_PDV + 22], -32768
        MOV WORD PTR [_SAS_PDV + 24], -32768
; MDY()
        MOV AX, 3
        PUSH AX
        MOV AX, 11
        PUSH AX
        MOV AX, 2026
        MOV CX, AX
        POP BX
        POP AX
        CALL _SASRT_MDY
; stocker D
        MOV [_SAS_PDV + 24], AX
; PUT
; PUT D
; charger D
        MOV AX, [_SAS_PDV + 24]
        CALL _SASRT_PUTNUM
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_80:
; OUTPUT : copier PDV -> dataset TEST20
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_79:
; ========= FIN DATA STEP TEST20 =========


; ========= DATA STEP =========
; dataset: TEST21
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_81:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
        MOV WORD PTR [_SAS_PDV + 6], -32768
        MOV WORD PTR [_SAS_PDV + 8], -32768
        MOV WORD PTR [_SAS_PDV + 10], -32768
        MOV WORD PTR [_SAS_PDV + 12], -32768
        MOV WORD PTR [_SAS_PDV + 14], -32768
        MOV WORD PTR [_SAS_PDV + 16], -32768
        MOV WORD PTR [_SAS_PDV + 18], -32768
        MOV WORD PTR [_SAS_PDV + 20], -32768
        MOV WORD PTR [_SAS_PDV + 22], -32768
        MOV WORD PTR [_SAS_PDV + 24], -32768
; MDY()
        MOV AX, 7
        PUSH AX
        MOV AX, 4
        PUSH AX
        MOV AX, 1976
        MOV CX, AX
        POP BX
        POP AX
        CALL _SASRT_MDY
; stocker D
        MOV [_SAS_PDV + 24], AX
; YEAR()
; charger D
        MOV AX, [_SAS_PDV + 24]
        CALL _SASRT_YEAR
; stocker Y
        MOV [_SAS_PDV + 2], AX
; MONTH()
; charger D
        MOV AX, [_SAS_PDV + 24]
        CALL _SASRT_MONTH
; stocker M
        MOV [_SAS_PDV + 26], AX
; DAY()
; charger D
        MOV AX, [_SAS_PDV + 24]
        CALL _SASRT_DAY
; stocker J
        MOV [_SAS_PDV + 28], AX
; PUT
; PUT Y
; charger Y
        MOV AX, [_SAS_PDV + 2]
        CALL _SASRT_PUTNUM
; PUT M
; charger M
        MOV AX, [_SAS_PDV + 26]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; PUT J
; charger J
        MOV AX, [_SAS_PDV + 28]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_83:
; OUTPUT : copier PDV -> dataset TEST21
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_82:
; ========= FIN DATA STEP TEST21 =========


; ========= DATA STEP =========
; dataset: TEST22
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_84:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
        MOV WORD PTR [_SAS_PDV + 6], -32768
        MOV WORD PTR [_SAS_PDV + 8], -32768
        MOV WORD PTR [_SAS_PDV + 10], -32768
        MOV WORD PTR [_SAS_PDV + 12], -32768
        MOV WORD PTR [_SAS_PDV + 14], -32768
        MOV WORD PTR [_SAS_PDV + 16], -32768
        MOV WORD PTR [_SAS_PDV + 18], -32768
        MOV WORD PTR [_SAS_PDV + 20], -32768
        MOV WORD PTR [_SAS_PDV + 22], -32768
        MOV WORD PTR [_SAS_PDV + 24], -32768
        MOV WORD PTR [_SAS_PDV + 26], -32768
        MOV WORD PTR [_SAS_PDV + 28], -32768
        MOV AX, OFFSET _SASK_87
; stocker NOM
        MOV [_SAS_PDV + 30], AX
; UPCASE()
; TRIM()
; LEFT()
; charger NOM
        MOV AX, [_SAS_PDV + 30]
        CALL _SASRT_LEFT
        CALL _SASRT_TRIM
        CALL _SASRT_UPCASE
; stocker NOM_CLEAN
        MOV [_SAS_PDV + 32], AX
; PUT
; PUT NOM_CLEAN
; charger NOM_CLEAN
        MOV AX, [_SAS_PDV + 32]
        CALL _SASRT_PUTNUM
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_86:
; OUTPUT : copier PDV -> dataset TEST22
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_85:
; ========= FIN DATA STEP TEST22 =========


; ========= DATA STEP =========
; dataset: TEST23
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_88:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
        MOV WORD PTR [_SAS_PDV + 6], -32768
        MOV WORD PTR [_SAS_PDV + 8], -32768
        MOV WORD PTR [_SAS_PDV + 10], -32768
        MOV WORD PTR [_SAS_PDV + 12], -32768
        MOV WORD PTR [_SAS_PDV + 14], -32768
        MOV WORD PTR [_SAS_PDV + 16], -32768
        MOV WORD PTR [_SAS_PDV + 18], -32768
        MOV WORD PTR [_SAS_PDV + 20], -32768
        MOV WORD PTR [_SAS_PDV + 22], -32768
        MOV WORD PTR [_SAS_PDV + 24], -32768
        MOV WORD PTR [_SAS_PDV + 26], -32768
        MOV WORD PTR [_SAS_PDV + 28], -32768
        MOV WORD PTR [_SAS_PDV + 30], -32768
        MOV WORD PTR [_SAS_PDV + 32], -32768
; SQRT()
        MOV AX, 16
        CALL _SASRT_SQRT
; stocker A
        MOV [_SAS_PDV + 4], AX
; LOG()
        MOV AX, 256
        CALL _SASRT_LOG
; stocker B
        MOV [_SAS_PDV + 6], AX
; EXP()
        XOR AX, AX
        CALL _SASRT_EXP
; stocker C
        MOV [_SAS_PDV + 8], AX
; PUT
; PUT A
; charger A
        MOV AX, [_SAS_PDV + 4]
        CALL _SASRT_PUTNUM
; PUT B
; charger B
        MOV AX, [_SAS_PDV + 6]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; PUT C
; charger C
        MOV AX, [_SAS_PDV + 8]
        CALL _SASRT_PUTNUM
        MOV AH, 02h
        MOV DL, 20h
        INT 21h
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_90:
; OUTPUT : copier PDV -> dataset TEST23
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_89:
; ========= FIN DATA STEP TEST23 =========


; ========= DATA STEP =========
; dataset: TEST24
        MOV WORD PTR [_SAS_N], 1
        MOV WORD PTR [_SAS_ERROR], 0

_SASL_91:
; --- iteration DATA step ---
; Reinitialiser PDV (variables non-RETAIN -> manquant)
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        LEA DI, _SAS_PDV + 0
        MOV AL, 20h
        MOV CX, 0
        REP STOSB
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 0], -32768
        MOV WORD PTR [_SAS_PDV + 2], -32768
        MOV WORD PTR [_SAS_PDV + 4], -32768
        MOV WORD PTR [_SAS_PDV + 6], -32768
        MOV WORD PTR [_SAS_PDV + 8], -32768
        MOV WORD PTR [_SAS_PDV + 10], -32768
        MOV WORD PTR [_SAS_PDV + 12], -32768
        MOV WORD PTR [_SAS_PDV + 14], -32768
        MOV WORD PTR [_SAS_PDV + 16], -32768
        MOV WORD PTR [_SAS_PDV + 18], -32768
        MOV WORD PTR [_SAS_PDV + 20], -32768
        MOV WORD PTR [_SAS_PDV + 22], -32768
        MOV WORD PTR [_SAS_PDV + 24], -32768
        MOV WORD PTR [_SAS_PDV + 26], -32768
        MOV WORD PTR [_SAS_PDV + 28], -32768
        MOV WORD PTR [_SAS_PDV + 30], -32768
        MOV WORD PTR [_SAS_PDV + 32], -32768
        MOV AX, OFFSET _SASK_94
; stocker X
        MOV [_SAS_PDV], AX
; RIGHT()
; charger X
        MOV AX, [_SAS_PDV]
        CALL _SASRT_RIGHT
; stocker Y
        MOV [_SAS_PDV + 2], AX
; PUT
; PUT Y
; charger Y
        MOV AX, [_SAS_PDV + 2]
        CALL _SASRT_PUTNUM
; PUT newline
        MOV AH, 40h
        MOV BX, [_SAS_OUTHDL]
        MOV CX, 2
        LEA DX, _SAS_CRLF
        INT 21h
_SASL_93:
; OUTPUT : copier PDV -> dataset TEST24
        INC WORD PTR [_SAS_N]
        MOV WORD PTR [_SAS_ERROR], 0
        INC WORD PTR [_SAS_N]
_SASL_92:
; ========= FIN DATA STEP TEST24 =========


; --- Fin du code ---
        MOV SP, BP
        POP BP
        MOV AX, 4C00h
        INT 21h


; --- Runtime minimal SAS86 ---

; === Runtime fonctions integrees SAS86 (TODO 22) ===

_SASRT_MIN:
        CMP AX, BX
        JLE _SASRT_MIN_D
        MOV AX, BX
_SASRT_MIN_D:
        RET

_SASRT_MAX:
        CMP AX, BX
        JGE _SASRT_MAX_D
        MOV AX, BX
_SASRT_MAX_D:
        RET

_SASRT_ROUND:
        TEST BX, BX
        JZ _SASRT_ROUND_D
        CWD
        IDIV BX
        IMUL BX
_SASRT_ROUND_D:
        RET

_SASRT_SQRT:
        CMP AX, 1
        JLE _SASRT_SQRT_D
        PUSH SI
        MOV SI, AX
        SHR AX, 1
_SASRT_SQRT_L:
        MOV CX, AX
        PUSH AX
        MOV AX, SI
        XOR DX, DX
        DIV CX
        POP BX
        ADD AX, BX
        SHR AX, 1
        CMP AX, CX
        JB _SASRT_SQRT_L
        MOV AX, CX
        POP SI
_SASRT_SQRT_D:
        RET

_SASRT_LOG:
        CMP AX, 1
        JLE _SASRT_LOG_Z
        PUSH CX
        XOR CX, CX
_SASRT_LOG_L:
        SHR AX, 1
        JZ _SASRT_LOG_E
        INC CX
        JMP _SASRT_LOG_L
_SASRT_LOG_E:
        MOV AX, CX
        POP CX
        RET
_SASRT_LOG_Z:
        XOR AX, AX
        RET

_SASRT_EXP:
        RET

_SASRT_STRLEN:
        MOV SI, AX
        XOR CX, CX
_SASRT_SL_LP:
        LODSB
        TEST AL, AL
        JZ _SASRT_SL_DN
        INC CX
        JMP _SASRT_SL_LP
_SASRT_SL_DN:
        MOV AX, CX
        RET

_SASRT_INDEX:
        PUSH SI
        PUSH DI
        XOR BX, BX
_SASRT_IX_NX:
        MOV AL, [SI]
        TEST AL, AL
        JZ _SASRT_IX_NF
        INC BX
        PUSH SI
        PUSH DI
_SASRT_IX_CM:
        MOV AL, [DI]
        TEST AL, AL
        JZ _SASRT_IX_FD
        CMP AL, [SI]
        JNE _SASRT_IX_NM
        INC SI
        INC DI
        JMP _SASRT_IX_CM
_SASRT_IX_NM:
        POP DI
        POP SI
        INC SI
        JMP _SASRT_IX_NX
_SASRT_IX_FD:
        POP DI
        POP SI
        MOV AX, BX
        POP DI
        POP SI
        RET
_SASRT_IX_NF:
        XOR AX, AX
        POP DI
        POP SI
        RET

_SASRT_SUBSTR:
        PUSH DI
        LEA DI, _SAS_STRBUF
        DEC BX
        ADD SI, BX
_SASRT_SS_LP:
        CMP CX, 0
        JE _SASRT_SS_DN
        LODSB
        TEST AL, AL
        JZ _SASRT_SS_DN
        STOSB
        CMP CX, -1
        JE _SASRT_SS_LP
        DEC CX
        JMP _SASRT_SS_LP
_SASRT_SS_DN:
        MOV BYTE PTR [DI], 0
        LEA AX, _SAS_STRBUF
        POP DI
        RET

_SASRT_TRIM:
        PUSH SI
        PUSH DI
        MOV SI, AX
        LEA DI, _SAS_STRBUF
        XOR CX, CX
_SASRT_TR_CP:
        LODSB
        STOSB
        TEST AL, AL
        JZ _SASRT_TR_TM
        INC CX
        JMP _SASRT_TR_CP
_SASRT_TR_TM:
        LEA DI, _SAS_STRBUF
        ADD DI, CX
        DEC DI
_SASRT_TR_BK:
        LEA AX, _SAS_STRBUF
        CMP DI, AX
        JB _SASRT_TR_DN
        CMP BYTE PTR [DI], 20h
        JNE _SASRT_TR_DN
        MOV BYTE PTR [DI], 0
        DEC DI
        JMP _SASRT_TR_BK
_SASRT_TR_DN:
        LEA AX, _SAS_STRBUF
        POP DI
        POP SI
        RET

_SASRT_LEFT:
        MOV SI, AX
_SASRT_LF_SK:
        CMP BYTE PTR [SI], 20h
        JNE _SASRT_LF_CP
        INC SI
        JMP _SASRT_LF_SK
_SASRT_LF_CP:
        PUSH DI
        LEA DI, _SAS_STRBUF
_SASRT_LF_LP:
        LODSB
        STOSB
        TEST AL, AL
        JNZ _SASRT_LF_LP
        LEA AX, _SAS_STRBUF
        POP DI
        RET

_SASRT_RIGHT:
        PUSH SI
        PUSH DI
        MOV SI, AX
        LEA DI, _SAS_STRBUF
_SASRT_RI_LP:
        LODSB
        STOSB
        TEST AL, AL
        JNZ _SASRT_RI_LP
        LEA AX, _SAS_STRBUF
        POP DI
        POP SI
        RET

_SASRT_UPCASE:
        PUSH SI
        PUSH DI
        MOV SI, AX
        LEA DI, _SAS_STRBUF
_SASRT_UC_LP:
        LODSB
        CMP AL, 61h
        JB _SASRT_UC_OK
        CMP AL, 7Ah
        JA _SASRT_UC_OK
        SUB AL, 20h
_SASRT_UC_OK:
        STOSB
        TEST AL, AL
        JNZ _SASRT_UC_LP
        LEA AX, _SAS_STRBUF
        POP DI
        POP SI
        RET

_SASRT_LOWCASE:
        PUSH SI
        PUSH DI
        MOV SI, AX
        LEA DI, _SAS_STRBUF
_SASRT_LC_LP:
        LODSB
        CMP AL, 41h
        JB _SASRT_LC_OK
        CMP AL, 5Ah
        JA _SASRT_LC_OK
        ADD AL, 20h
_SASRT_LC_OK:
        STOSB
        TEST AL, AL
        JNZ _SASRT_LC_LP
        LEA AX, _SAS_STRBUF
        POP DI
        POP SI
        RET

_SASRT_COMPRESS:
        PUSH SI
        PUSH DI
        MOV SI, AX
        PUSH DI
        LEA DI, _SAS_STRBUF
_SASRT_CO_LP:
        LODSB
        TEST AL, AL
        JZ _SASRT_CO_DN
        MOV BX, [SP]
        TEST BX, BX
        JNZ _SASRT_CO_CK
        CMP AL, 20h
        JE _SASRT_CO_LP
        JMP _SASRT_CO_ST
_SASRT_CO_CK:
        PUSH SI
        MOV SI, BX
_SASRT_CO_SC:
        MOV AH, [SI]
        TEST AH, AH
        JZ _SASRT_CO_KP
        CMP AL, AH
        JE _SASRT_CO_RM
        INC SI
        JMP _SASRT_CO_SC
_SASRT_CO_KP:
        POP SI
_SASRT_CO_ST:
        STOSB
        JMP _SASRT_CO_LP
_SASRT_CO_RM:
        POP SI
        JMP _SASRT_CO_LP
_SASRT_CO_DN:
        STOSB
        POP BX
        LEA AX, _SAS_STRBUF
        POP DI
        POP SI
        RET

_SASRT_STRCAT:
        PUSH SI
        PUSH DI
        PUSH DI
        LEA DI, _SAS_STRBUF2
_SASRT_SC_C1:
        LODSB
        TEST AL, AL
        JZ _SASRT_SC_S2
        STOSB
        JMP _SASRT_SC_C1
_SASRT_SC_S2:
        POP SI
_SASRT_SC_C2:
        LODSB
        STOSB
        TEST AL, AL
        JNZ _SASRT_SC_C2
        LEA AX, _SAS_STRBUF2
        POP DI
        POP SI
        RET

_SASRT_NUM2STR:
        PUSH SI
        PUSH DI
        PUSH BX
        LEA DI, _SAS_NUMBUF
        TEST AX, AX
        JNS _SASRT_N2_POS
        MOV BYTE PTR [DI], 2Dh
        INC DI
        NEG AX
_SASRT_N2_POS:
        XOR CX, CX
        MOV BX, 10
_SASRT_N2_DIV:
        XOR DX, DX
        DIV BX
        ADD DL, 30h
        PUSH DX
        INC CX
        TEST AX, AX
        JNZ _SASRT_N2_DIV
_SASRT_N2_POP:
        POP AX
        STOSB
        LOOP _SASRT_N2_POP
        MOV BYTE PTR [DI], 0
        LEA AX, _SAS_NUMBUF
        POP BX
        POP DI
        POP SI
        RET

_SASRT_STR2NUM:
        MOV SI, AX
        XOR AX, AX
        XOR CX, CX
        CMP BYTE PTR [SI], 2Dh
        JNE _SASRT_A2_LP
        INC CX
        INC SI
_SASRT_A2_LP:
        MOV BL, [SI]
        SUB BL, 30h
        JB _SASRT_A2_DN
        CMP BL, 9
        JA _SASRT_A2_DN
        MOV DX, 10
        IMUL DX
        XOR BH, BH
        ADD AX, BX
        INC SI
        JMP _SASRT_A2_LP
_SASRT_A2_DN:
        TEST CX, CX
        JZ _SASRT_A2_RT
        NEG AX
_SASRT_A2_RT:
        RET

_SASRT_MDY:
        PUSH SI
        PUSH DI
        PUSH BX
        PUSH AX
        MOV AX, CX
        SUB AX, 1960
        MOV BX, 365
        IMUL BX
        MOV DI, AX
        MOV AX, CX
        SUB AX, 1960
        MOV BX, 4
        CWD
        IDIV BX
        ADD DI, AX
        POP AX
        DEC AX
        MOV BX, AX
        SHL BX, 1
        ADD BX, OFFSET _SASRT_MDAYS
        MOV AX, [BX]
        ADD DI, AX
        POP AX
        DEC AX
        ADD AX, DI
        POP DI
        POP SI
        RET

_SASRT_MDAYS:
        DW  0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334

_SASRT_YEAR:
        PUSH BX
        MOV BX, 365
        CWD
        IDIV BX
        ADD AX, 1960
        POP BX
        RET

_SASRT_MONTH:
        PUSH BX
        PUSH SI
        MOV BX, 365
        CWD
        IDIV BX
        MOV AX, DX
        LEA SI, _SASRT_MDAYS
        MOV CX, 12
        XOR BX, BX
_SASRT_MO_LP:
        MOV DX, [SI+BX]
        CMP AX, DX
        JL _SASRT_MO_FD
        ADD BX, 2
        LOOP _SASRT_MO_LP
_SASRT_MO_FD:
        SHR BX, 1
        MOV AX, BX
        POP SI
        POP BX
        RET

_SASRT_DAY:
        PUSH BX
        PUSH SI
        MOV BX, 365
        CWD
        IDIV BX
        MOV AX, DX
        LEA SI, _SASRT_MDAYS
        XOR BX, BX
        MOV CX, 11
_SASRT_DY_LP:
        MOV DX, [SI+BX+2]
        CMP AX, DX
        JL _SASRT_DY_FD
        ADD BX, 2
        LOOP _SASRT_DY_LP
_SASRT_DY_FD:
        SUB AX, [SI+BX]
        INC AX
        POP SI
        POP BX
        RET


_TEXT ENDS

_DATA SEGMENT PUBLIC 'DATA'

; --- Donnees predefinies SAS86 ---
_SAS_MISSING  DW  -32768
_SAS_N  DW  0
_SAS_ERROR  DW  0
_SAS_PDV  DB  512 DUP(0)
_SAS_CRLF  DB  13,10,0
_SAS_INBUF  DB  256 DUP(0)
_SAS_INLEN  DW  0
_SAS_INPOS  DW  0
_SAS_NUMBUF  DB  12 DUP(0)
_SAS_INHDL  DW  0
_SAS_OUTHDL  DW  1
_SAS_DOEND  DW  0
_SAS_DOSTEP  DW  1
_SAS_STRBUF  DB  256 DUP(0)
_SAS_STRBUF2  DB  256 DUP(0)
_SASK_32  DB  'Hello World',0
_SASK_36  DB  'Hello',0
_SASK_40  DB  'Hello   ',0
_SASK_44  DB  '   World',0
_SASK_48  DB  'Bonjour le monde',0
_SASK_52  DB  'Hello World',0
_SASK_56  DB  'Hello World',0
_SASK_57  DB  'World',0
_SASK_61  DB  'A B C D',0
_SASK_65  DB  'Hello123World',0
_SASK_66  DB  '0123456789',0
_SASK_70  DB  'Bon',0
_SASK_71  DB  'jour',0
_SASK_87  DB  '  Alice  ',0
_SASK_94  DB  'Hello',0

_DATA ENDS

END _SASP_Main
