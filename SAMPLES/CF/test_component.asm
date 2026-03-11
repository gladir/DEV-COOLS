; CF86 v1.0 - 2026-03-06
; Compilateur ColdFusion -> assembleur 8086
; Source: SAMPLES/CF/test_component.cfm

.MODEL SMALL
.STACK 1024

_TEXT SEGMENT PUBLIC 'CODE'
        ASSUME CS:_TEXT, DS:_DATA, SS:NOTHING

; Point d'entree programme CF86
_CFF_Main:
        PUSH   BP
        MOV   BP, SP
        MOV   AX, _DATA
        MOV   DS, AX

; ==== <cfcomponent> ====
; ---- <cfproperty> ----
; ---- <cfproperty> ----
; ---- <cffunction> ----
        JMP   _CFL_2

; function crier returnType=string access=public
_CFF_crier:
        PUSH   BP
        MOV   BP, SP
        SUB   SP, 128
; ---- <cfreturn> ----
        MOV   AX, OFFSET _CFK_4
        JMP   _CFL_3
_CFL_3:
        MOV   SP, BP
        POP   BP
        RET

_CFL_2:
; ---- <cffunction> ----
        JMP   _CFL_5

; function description returnType=string access=public
_CFF_description:
        PUSH   BP
        MOV   BP, SP
        SUB   SP, 128
; ---- <cfreturn> ----
        MOV   AX, OFFSET _CFK_7
        JMP   _CFL_6
_CFL_6:
        MOV   SP, BP
        POP   BP
        RET

_CFL_5:
        JMP   _CFL_8

; getter: getnom()
_CFC_Animal_getnom:
        PUSH   BP
        MOV   BP, SP
        MOV   SI, [BP+4]
        MOV   DI, OFFSET _CFK_9
        CALL   _CFRT_STFIND
        MOV   SP, BP
        POP   BP
        RET

_CFL_8:
        JMP   _CFL_10

; setter: setnom(val)
_CFC_Animal_setnom:
        PUSH   BP
        MOV   BP, SP
        MOV   SI, [BP+6]
        MOV   DI, OFFSET _CFK_9
        MOV   AX, [BP+4]
        CALL   _CFRT_STINSERT
        MOV   SP, BP
        POP   BP
        RET

_CFL_10:
        JMP   _CFL_11

; getter: getpattes()
_CFC_Animal_getpattes:
        PUSH   BP
        MOV   BP, SP
        MOV   SI, [BP+4]
        MOV   DI, OFFSET _CFK_12
        CALL   _CFRT_STFIND
        MOV   SP, BP
        POP   BP
        RET

_CFL_11:
        JMP   _CFL_13

; setter: setpattes(val)
_CFC_Animal_setpattes:
        PUSH   BP
        MOV   BP, SP
        MOV   SI, [BP+6]
        MOV   DI, OFFSET _CFK_12
        MOV   AX, [BP+4]
        CALL   _CFRT_STINSERT
        MOV   SP, BP
        POP   BP
        RET

_CFL_13:
; ==== fin cfcomponent Animal ====
; ---- CFSET ----
; CreateObject()
        MOV   SI, OFFSET _CFL_14
        MOV   WORD PTR [SI], 0
        PUSH   SI
        MOV   DI, OFFSET _CFK_9
        XOR   AX, AX
        CALL   _CFRT_STINSERT
        POP   SI
        PUSH   SI
        MOV   DI, OFFSET _CFK_12
        XOR   AX, AX
        CALL   _CFRT_STINSERT
        POP   SI
        MOV   AX, SI
        MOV   [_CFV_chat], AX
; cfoutput: texte brut
        MOV   SI, OFFSET _CFK_15
        CALL   _CFRT_PRINT
; ==== <cfcomponent> ====
; heritage depuis Animal
; ---- <cfproperty> ----
; ---- <cffunction> ----
        JMP   _CFL_17

; function crier returnType=string access=public
_CFF_crier:
        PUSH   BP
        MOV   BP, SP
        SUB   SP, 128
; ---- <cfreturn> ----
        MOV   AX, OFFSET _CFK_19
        JMP   _CFL_18
_CFL_18:
        MOV   SP, BP
        POP   BP
        RET

_CFL_17:
        JMP   _CFL_20

; getter: getnom()
_CFC_Chien_getnom:
        PUSH   BP
        MOV   BP, SP
        MOV   SI, [BP+4]
        MOV   DI, OFFSET _CFK_9
        CALL   _CFRT_STFIND
        MOV   SP, BP
        POP   BP
        RET

_CFL_20:
        JMP   _CFL_21

; setter: setnom(val)
_CFC_Chien_setnom:
        PUSH   BP
        MOV   BP, SP
        MOV   SI, [BP+6]
        MOV   DI, OFFSET _CFK_9
        MOV   AX, [BP+4]
        CALL   _CFRT_STINSERT
        MOV   SP, BP
        POP   BP
        RET

_CFL_21:
        JMP   _CFL_22

; getter: getpattes()
_CFC_Chien_getpattes:
        PUSH   BP
        MOV   BP, SP
        MOV   SI, [BP+4]
        MOV   DI, OFFSET _CFK_12
        CALL   _CFRT_STFIND
        MOV   SP, BP
        POP   BP
        RET

_CFL_22:
        JMP   _CFL_23

; setter: setpattes(val)
_CFC_Chien_setpattes:
        PUSH   BP
        MOV   BP, SP
        MOV   SI, [BP+6]
        MOV   DI, OFFSET _CFK_12
        MOV   AX, [BP+4]
        CALL   _CFRT_STINSERT
        MOV   SP, BP
        POP   BP
        RET

_CFL_23:
        JMP   _CFL_24

; getter: getrace()
_CFC_Chien_getrace:
        PUSH   BP
        MOV   BP, SP
        MOV   SI, [BP+4]
        MOV   DI, OFFSET _CFK_25
        CALL   _CFRT_STFIND
        MOV   SP, BP
        POP   BP
        RET

_CFL_24:
        JMP   _CFL_26

; setter: setrace(val)
_CFC_Chien_setrace:
        PUSH   BP
        MOV   BP, SP
        MOV   SI, [BP+6]
        MOV   DI, OFFSET _CFK_25
        MOV   AX, [BP+4]
        CALL   _CFRT_STINSERT
        MOV   SP, BP
        POP   BP
        RET

_CFL_26:
; ==== fin cfcomponent Chien ====
; ---- CFSET ----
; new chien()
        MOV   SI, OFFSET _CFL_27
        MOV   WORD PTR [SI], 0
        PUSH   SI
        MOV   DI, OFFSET _CFK_9
        XOR   AX, AX
        CALL   _CFRT_STINSERT
        POP   SI
        PUSH   SI
        MOV   DI, OFFSET _CFK_12
        XOR   AX, AX
        CALL   _CFRT_STINSERT
        POP   SI
        PUSH   SI
        MOV   DI, OFFSET _CFK_25
        XOR   AX, AX
        CALL   _CFRT_STINSERT
        POP   SI
        MOV   AX, SI
        MOV   [_CFV_rex], AX
; cfoutput: texte brut
        MOV   SI, OFFSET _CFK_28
        CALL   _CFRT_PRINT
; ---- CFSET ----
; appel crier
        CALL   _CFF_crier
        MOV   [_CFV_son], AX
; cfoutput: texte brut
        MOV   SI, OFFSET _CFK_29
        CALL   _CFRT_PRINT
        MOV   AX, [_CFV_son]
; cfoutput: expr numerique
        CALL   _CFRT_PRINTNUM
; cfoutput: texte brut
        MOV   SI, OFFSET _CFK_30
        CALL   _CFRT_PRINT

; --- Fin du code ---
        MOV   SP, BP
        POP   BP
        MOV   AX, 4C00h
        INT   21h


; --- Runtime minimal CF86 ---

_CFRT_STRLEN:
        PUSH   SI
        XOR   CX, CX
_CFRT_STRLEN_L:
        LODSB
        OR   AL, AL
        JZ   _CFRT_STRLEN_E
        INC   CX
        JMP   _CFRT_STRLEN_L
_CFRT_STRLEN_E:
        POP   SI
        RET

_CFRT_PRINT:
        PUSH   AX
        PUSH   BX
        PUSH   CX
        PUSH   DX
        CALL   _CFRT_STRLEN
        MOV   DX, SI
        MOV   BX, 1
        MOV   AH, 40h
        INT   21h
        POP   DX
        POP   CX
        POP   BX
        POP   AX
        RET

_CFRT_PRINTLN:
        CALL   _CFRT_PRINT
        MOV   SI, OFFSET _CF_CRLF
        CALL   _CFRT_PRINT
        RET

_CFRT_NUMTOSTR:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        PUSH   DI
        MOV   DI, OFFSET _CF_NUMBUF
        ADD   DI, 11
        MOV   BYTE PTR [DI], 0
        DEC   DI
        MOV   CX, AX
        OR   AX, AX
        JNS   _CFRT_NTS_POS
        NEG   AX
_CFRT_NTS_POS:
        MOV   BX, 10
_CFRT_NTS_LP:
        XOR   DX, DX
        DIV   BX
        ADD   DL, '0'
        MOV   [DI], DL
        DEC   DI
        OR   AX, AX
        JNZ   _CFRT_NTS_LP
        OR   CX, CX
        JNS   _CFRT_NTS_DN
        MOV   BYTE PTR [DI], '-'
        DEC   DI
_CFRT_NTS_DN:
        INC   DI
        MOV   AX, DI
        POP   DI
        POP   DX
        POP   CX
        POP   BX
        RET

_CFRT_PRINTNUM:
        CALL   _CFRT_NUMTOSTR
        MOV   SI, AX
        CALL   _CFRT_PRINT
        RET

_CFRT_LEFT:
        PUSH   DI
        MOV   DI, OFFSET _CF_STRBUF
_CFRT_LEFT_LP:
        OR   CX, CX
        JZ   _CFRT_LEFT_DN
        LODSB
        OR   AL, AL
        JZ   _CFRT_LEFT_DN
        STOSB
        DEC   CX
        JMP   _CFRT_LEFT_LP
_CFRT_LEFT_DN:
        MOV   BYTE PTR [DI], 0
        MOV   AX, OFFSET _CF_STRBUF
        POP   DI
        RET

_CFRT_RIGHT:
        PUSH   DI
        PUSH   BX
        PUSH   CX
        PUSH   SI
        CALL   _CFRT_STRLEN
        POP   SI
        MOV   BX, CX
        POP   CX
        CMP   CX, BX
        JAE   _CFRT_RIGHT_ALL
        MOV   AX, BX
        SUB   AX, CX
        ADD   SI, AX
        JMP   _CFRT_RIGHT_CP
_CFRT_RIGHT_ALL:
        MOV   CX, BX
_CFRT_RIGHT_CP:
        MOV   DI, OFFSET _CF_STRBUF
_CFRT_RIGHT_LP:
        OR   CX, CX
        JZ   _CFRT_RIGHT_DN
        LODSB
        STOSB
        DEC   CX
        JMP   _CFRT_RIGHT_LP
_CFRT_RIGHT_DN:
        MOV   BYTE PTR [DI], 0
        MOV   AX, OFFSET _CF_STRBUF
        POP   BX
        POP   DI
        RET

_CFRT_MID:
        PUSH   DI
        DEC   BX
_CFRT_MID_SK:
        OR   BX, BX
        JZ   _CFRT_MID_CP
        CMP   BYTE PTR [SI], 0
        JE   _CFRT_MID_CP
        INC   SI
        DEC   BX
        JMP   _CFRT_MID_SK
_CFRT_MID_CP:
        MOV   DI, OFFSET _CF_STRBUF
_CFRT_MID_LP:
        OR   CX, CX
        JZ   _CFRT_MID_DN
        LODSB
        OR   AL, AL
        JZ   _CFRT_MID_DN
        STOSB
        DEC   CX
        JMP   _CFRT_MID_LP
_CFRT_MID_DN:
        MOV   BYTE PTR [DI], 0
        MOV   AX, OFFSET _CF_STRBUF
        POP   DI
        RET

_CFRT_TRIM:
        PUSH   DI
_CFRT_TRIM_LS:
        CMP   BYTE PTR [SI], 32
        JNE   _CFRT_TRIM_CP
        INC   SI
        JMP   _CFRT_TRIM_LS
_CFRT_TRIM_CP:
        MOV   DI, OFFSET _CF_STRBUF
_CFRT_TRIM_CL:
        LODSB
        STOSB
        OR   AL, AL
        JNZ   _CFRT_TRIM_CL
        DEC   DI
_CFRT_TRIM_RS:
        CMP   DI, OFFSET _CF_STRBUF
        JBE   _CFRT_TRIM_DN
        DEC   DI
        CMP   BYTE PTR [DI], 32
        JE   _CFRT_TRIM_RS
        INC   DI
_CFRT_TRIM_DN:
        MOV   BYTE PTR [DI], 0
        MOV   AX, OFFSET _CF_STRBUF
        POP   DI
        RET

_CFRT_LTRIM:
        PUSH   DI
_CFRT_LTR_LS:
        CMP   BYTE PTR [SI], 32
        JNE   _CFRT_LTR_CP
        INC   SI
        JMP   _CFRT_LTR_LS
_CFRT_LTR_CP:
        MOV   DI, OFFSET _CF_STRBUF
_CFRT_LTR_CL:
        LODSB
        STOSB
        OR   AL, AL
        JNZ   _CFRT_LTR_CL
        MOV   AX, OFFSET _CF_STRBUF
        POP   DI
        RET

_CFRT_RTRIM:
        PUSH   DI
        MOV   DI, OFFSET _CF_STRBUF
_CFRT_RTR_CL:
        LODSB
        STOSB
        OR   AL, AL
        JNZ   _CFRT_RTR_CL
        DEC   DI
_CFRT_RTR_RS:
        CMP   DI, OFFSET _CF_STRBUF
        JBE   _CFRT_RTR_DN
        DEC   DI
        CMP   BYTE PTR [DI], 32
        JE   _CFRT_RTR_RS
        INC   DI
_CFRT_RTR_DN:
        MOV   BYTE PTR [DI], 0
        MOV   AX, OFFSET _CF_STRBUF
        POP   DI
        RET

_CFRT_UCASE:
        PUSH   DI
        MOV   DI, OFFSET _CF_STRBUF
_CFRT_UC_LP:
        LODSB
        CMP   AL, 'a'
        JB   _CFRT_UC_ST
        CMP   AL, 'z'
        JA   _CFRT_UC_ST
        SUB   AL, 32
_CFRT_UC_ST:
        STOSB
        OR   AL, AL
        JNZ   _CFRT_UC_LP
        MOV   AX, OFFSET _CF_STRBUF
        POP   DI
        RET

_CFRT_LCASE:
        PUSH   DI
        MOV   DI, OFFSET _CF_STRBUF
_CFRT_LC_LP:
        LODSB
        CMP   AL, 'A'
        JB   _CFRT_LC_ST
        CMP   AL, 'Z'
        JA   _CFRT_LC_ST
        ADD   AL, 32
_CFRT_LC_ST:
        STOSB
        OR   AL, AL
        JNZ   _CFRT_LC_LP
        MOV   AX, OFFSET _CF_STRBUF
        POP   DI
        RET

_CFRT_FIND:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        XOR   BX, BX
_CFRT_FND_LP:
        CMP   BYTE PTR [SI], 0
        JE   _CFRT_FND_NF
        INC   BX
        PUSH   SI
        PUSH   DI
_CFRT_FND_CM:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _CFRT_FND_OK
        CMP   AL, [SI]
        JNE   _CFRT_FND_NX
        INC   SI
        INC   DI
        JMP   _CFRT_FND_CM
_CFRT_FND_NX:
        POP   DI
        POP   SI
        INC   SI
        JMP   _CFRT_FND_LP
_CFRT_FND_OK:
        POP   DI
        POP   SI
        MOV   AX, BX
        JMP   _CFRT_FND_RT
_CFRT_FND_NF:
        XOR   AX, AX
_CFRT_FND_RT:
        POP   DX
        POP   CX
        POP   BX
        RET

_CFRT_FINDNOCASE:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        XOR   BX, BX
_CFRT_FNC_LP:
        CMP   BYTE PTR [SI], 0
        JE   _CFRT_FNC_NF
        INC   BX
        PUSH   SI
        PUSH   DI
_CFRT_FNC_CM:
        MOV   AL, [DI]
        OR   AL, AL
        JZ   _CFRT_FNC_OK
        MOV   AH, [SI]
        CMP   AL, 'a'
        JB   _CFRT_FNC_U1
        CMP   AL, 'z'
        JA   _CFRT_FNC_U1
        SUB   AL, 32
_CFRT_FNC_U1:
        CMP   AH, 'a'
        JB   _CFRT_FNC_U2
        CMP   AH, 'z'
        JA   _CFRT_FNC_U2
        SUB   AH, 32
_CFRT_FNC_U2:
        CMP   AL, AH
        JNE   _CFRT_FNC_NX
        INC   SI
        INC   DI
        JMP   _CFRT_FNC_CM
_CFRT_FNC_NX:
        POP   DI
        POP   SI
        INC   SI
        JMP   _CFRT_FNC_LP
_CFRT_FNC_OK:
        POP   DI
        POP   SI
        MOV   AX, BX
        JMP   _CFRT_FNC_RT
_CFRT_FNC_NF:
        XOR   AX, AX
_CFRT_FNC_RT:
        POP   DX
        POP   CX
        POP   BX
        RET

_CFRT_REPLACE:
        PUSH   CX
        PUSH   DX
        PUSH   BP
        MOV   BP, OFFSET _CF_STRBUF
        PUSH   SI
        MOV   SI, DI
        CALL   _CFRT_STRLEN
        MOV   DX, CX
        POP   SI
_CFRT_RPL_LP:
        CMP   BYTE PTR [SI], 0
        JE   _CFRT_RPL_DN
        PUSH   SI
        PUSH   DI
        MOV   CX, DX
_CFRT_RPL_CM:
        OR   CX, CX
        JZ   _CFRT_RPL_FD
        MOV   AL, [SI]
        CMP   AL, [DI]
        JNE   _CFRT_RPL_NM
        INC   SI
        INC   DI
        DEC   CX
        JMP   _CFRT_RPL_CM
_CFRT_RPL_NM:
        POP   DI
        POP   SI
        LODSB
        MOV   CX, BP
        XCHG   DI, CX
        STOSB
        MOV   BP, DI
        XCHG   DI, CX
        JMP   _CFRT_RPL_LP
_CFRT_RPL_FD:
        POP   DI
        POP   SI
        ADD   SI, DX
        PUSH   SI
        MOV   SI, BX
        XCHG   DI, BP
_CFRT_RPL_RC:
        LODSB
        OR   AL, AL
        JZ   _CFRT_RPL_RD
        STOSB
        JMP   _CFRT_RPL_RC
_CFRT_RPL_RD:
        MOV   BP, DI
        POP   SI
        MOV   DI, OFFSET _CF_NULL_STR
        XOR   DX, DX
_CFRT_RPL_RS:
        LODSB
        XCHG   DI, BP
        STOSB
        MOV   BP, DI
        XCHG   DI, BP
        OR   AL, AL
        JNZ   _CFRT_RPL_RS
        JMP   _CFRT_RPL_RT
_CFRT_RPL_DN:
        XCHG   DI, BP
        MOV   BYTE PTR [DI], 0
_CFRT_RPL_RT:
        MOV   AX, OFFSET _CF_STRBUF
        POP   BP
        POP   DX
        POP   CX
        RET

_CFRT_STRTONUM:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        XOR   AX, AX
        XOR   CX, CX
        CMP   BYTE PTR [SI], '-'
        JNE   _CFRT_STN_LP
        MOV   CX, 1
        INC   SI
_CFRT_STN_LP:
        MOV   BL, [SI]
        XOR   BH, BH
        SUB   BL, '0'
        JB   _CFRT_STN_DN
        CMP   BL, 9
        JA   _CFRT_STN_DN
        PUSH   DX
        MOV   DX, 10
        MUL   DX
        POP   DX
        ADD   AX, BX
        INC   SI
        JMP   _CFRT_STN_LP
_CFRT_STN_DN:
        OR   CX, CX
        JZ   _CFRT_STN_RT
        NEG   AX
_CFRT_STN_RT:
        POP   DX
        POP   CX
        POP   BX
        RET

_CFRT_REPEAT:
        PUSH   DI
        PUSH   BX
        MOV   BX, SI
        MOV   DI, OFFSET _CF_STRBUF
_CFRT_RPT_OL:
        OR   CX, CX
        JZ   _CFRT_RPT_DN
        MOV   SI, BX
_CFRT_RPT_IL:
        LODSB
        OR   AL, AL
        JZ   _CFRT_RPT_NX
        STOSB
        JMP   _CFRT_RPT_IL
_CFRT_RPT_NX:
        DEC   CX
        JMP   _CFRT_RPT_OL
_CFRT_RPT_DN:
        MOV   BYTE PTR [DI], 0
        MOV   AX, OFFSET _CF_STRBUF
        POP   BX
        POP   DI
        RET

_CFRT_REVERSE:
        PUSH   DI
        PUSH   BX
        PUSH   CX
        CALL   _CFRT_STRLEN
        MOV   DI, OFFSET _CF_STRBUF
        ADD   SI, CX
        DEC   SI
_CFRT_REV_LP:
        OR   CX, CX
        JZ   _CFRT_REV_DN
        MOV   AL, [SI]
        STOSB
        DEC   SI
        DEC   CX
        JMP   _CFRT_REV_LP
_CFRT_REV_DN:
        MOV   BYTE PTR [DI], 0
        MOV   AX, OFFSET _CF_STRBUF
        POP   CX
        POP   BX
        POP   DI
        RET

_CFRT_LISTLEN:
        PUSH   BX
        XOR   AX, AX
        CMP   BYTE PTR [SI], 0
        JE   _CFRT_LLN_RT
        INC   AX
_CFRT_LLN_LP:
        MOV   BL, [SI]
        OR   BL, BL
        JZ   _CFRT_LLN_RT
        CMP   BL, ','
        JNE   _CFRT_LLN_NX
        INC   AX
_CFRT_LLN_NX:
        INC   SI
        JMP   _CFRT_LLN_LP
_CFRT_LLN_RT:
        POP   BX
        RET

_CFRT_LISTGETAT:
        PUSH   DI
        DEC   CX
_CFRT_LGA_SK:
        OR   CX, CX
        JZ   _CFRT_LGA_CP
        CMP   BYTE PTR [SI], 0
        JE   _CFRT_LGA_CP
        CMP   BYTE PTR [SI], ','
        JNE   _CFRT_LGA_NX
        DEC   CX
_CFRT_LGA_NX:
        INC   SI
        JMP   _CFRT_LGA_SK
_CFRT_LGA_CP:
        MOV   DI, OFFSET _CF_STRBUF2
_CFRT_LGA_CL:
        MOV   AL, [SI]
        OR   AL, AL
        JZ   _CFRT_LGA_DN
        CMP   AL, ','
        JE   _CFRT_LGA_DN
        STOSB
        INC   SI
        JMP   _CFRT_LGA_CL
_CFRT_LGA_DN:
        MOV   BYTE PTR [DI], 0
        MOV   AX, OFFSET _CF_STRBUF2
        POP   DI
        RET

_CFRT_LISTAPPEND:
        PUSH   BX
        MOV   BX, OFFSET _CF_STRBUF
_CFRT_LAP_CL:
        LODSB
        MOV   [BX], AL
        INC   BX
        OR   AL, AL
        JNZ   _CFRT_LAP_CL
        DEC   BX
        CMP   BX, OFFSET _CF_STRBUF
        JE   _CFRT_LAP_CV
        MOV   BYTE PTR [BX], ','
        INC   BX
_CFRT_LAP_CV:
        MOV   SI, DI
_CFRT_LAP_VL:
        LODSB
        MOV   [BX], AL
        INC   BX
        OR   AL, AL
        JNZ   _CFRT_LAP_VL
        MOV   AX, OFFSET _CF_STRBUF
        POP   BX
        RET

_CFRT_ABS:
        OR   AX, AX
        JNS   _CFRT_ABS_OK
        NEG   AX
_CFRT_ABS_OK:
        RET

_CFRT_MAX:
        CMP   AX, BX
        JGE   _CFRT_MAX_OK
        MOV   AX, BX
_CFRT_MAX_OK:
        RET

_CFRT_MIN:
        CMP   AX, BX
        JLE   _CFRT_MIN_OK
        MOV   AX, BX
_CFRT_MIN_OK:
        RET

_CFRT_SGN:
        OR   AX, AX
        JZ   _CFRT_SGN_Z
        JS   _CFRT_SGN_N
        MOV   AX, 1
        RET
_CFRT_SGN_N:
        MOV   AX, -1
        RET
_CFRT_SGN_Z:
        XOR   AX, AX
        RET

_CFRT_ISNUMERIC:
        PUSH   SI
_CFRT_ISNUM_SK:
        LODSB
        CMP   AL, 32
        JE   _CFRT_ISNUM_SK
        CMP   AL, '+'
        JE   _CFRT_ISNUM_DG
        CMP   AL, '-'
        JE   _CFRT_ISNUM_DG
        DEC   SI
_CFRT_ISNUM_DG:
        XOR   CX, CX
_CFRT_ISNUM_LP:
        LODSB
        OR   AL, AL
        JZ   _CFRT_ISNUM_OK
        CMP   AL, '0'
        JB   _CFRT_ISNUM_NO
        CMP   AL, '9'
        JA   _CFRT_ISNUM_NO
        INC   CX
        JMP   _CFRT_ISNUM_LP
_CFRT_ISNUM_OK:
        OR   CX, CX
        JZ   _CFRT_ISNUM_NO
        MOV   AX, 1
        POP   SI
        RET
_CFRT_ISNUM_NO:
        XOR   AX, AX
        POP   SI
        RET

_CFRT_ISBOOLEAN:
        OR   AX, AX
        JZ   _CFRT_ISBL_Y
        CMP   AX, 1
        JE   _CFRT_ISBL_Y
        XOR   AX, AX
        RET
_CFRT_ISBL_Y:
        MOV   AX, 1
        RET

_CFRT_ARRLEN:
        MOV   AX, [SI]
        RET

_CFRT_ARRAPPEND:
        PUSH   BX
        PUSH   CX
        MOV   CX, [SI]
        CMP   CX, 64
        JAE   _CFRT_ARAP_E
        INC   WORD PTR [SI]
        SHL   CX, 1
        ADD   CX, 2
        MOV   BX, SI
        ADD   BX, CX
        MOV   [BX], AX
_CFRT_ARAP_E:
        POP   CX
        POP   BX
        RET

_CFRT_ARRGET:
        PUSH   BX
        OR   CX, CX
        JZ   _CFRT_ARGT_0
        CMP   CX, [SI]
        JA   _CFRT_ARGT_0
        DEC   CX
        SHL   CX, 1
        ADD   CX, 2
        MOV   BX, SI
        ADD   BX, CX
        MOV   AX, [BX]
        POP   BX
        RET
_CFRT_ARGT_0:
        XOR   AX, AX
        POP   BX
        RET

_CFRT_ARRSET:
        PUSH   BX
        OR   CX, CX
        JZ   _CFRT_ARST_E
        CMP   CX, [SI]
        JA   _CFRT_ARST_E
        DEC   CX
        SHL   CX, 1
        ADD   CX, 2
        MOV   BX, SI
        ADD   BX, CX
        MOV   [BX], AX
_CFRT_ARST_E:
        POP   BX
        RET

_CFRT_ARRDEL:
        PUSH   BX
        PUSH   DX
        OR   CX, CX
        JZ   _CFRT_ARDL_E
        CMP   CX, [SI]
        JA   _CFRT_ARDL_E
        MOV   DX, [SI]
        DEC   CX
        SHL   CX, 1
        ADD   CX, 2
        MOV   BX, SI
        ADD   BX, CX
_CFRT_ARDL_LP:
        ADD   CX, 2
        SHR   CX, 1
        CMP   CX, DX
        JA   _CFRT_ARDL_DN
        SHL   CX, 1
        MOV   AX, [SI+CX]
        ADD   CX, 2
        MOV   [BX], AX
        ADD   BX, 2
        JMP   _CFRT_ARDL_LP
_CFRT_ARDL_DN:
        DEC   WORD PTR [SI]
_CFRT_ARDL_E:
        POP   DX
        POP   BX
        RET

_CFRT_ARRINS:
        PUSH   BX
        PUSH   DX
        MOV   DX, [SI]
        CMP   DX, 64
        JAE   _CFRT_ARIN_E
        OR   CX, CX
        JZ   _CFRT_ARIN_E
        PUSH   AX
        MOV   BX, DX
_CFRT_ARIN_LP:
        CMP   BX, CX
        JB   _CFRT_ARIN_DN
        PUSH   CX
        MOV   CX, BX
        DEC   CX
        SHL   CX, 1
        ADD   CX, 2
        MOV   AX, [SI+CX]
        ADD   CX, 2
        MOV   [SI+CX], AX
        POP   CX
        DEC   BX
        JMP   _CFRT_ARIN_LP
_CFRT_ARIN_DN:
        POP   AX
        DEC   CX
        SHL   CX, 1
        ADD   CX, 2
        MOV   [SI+CX], AX
        INC   WORD PTR [SI]
_CFRT_ARIN_E:
        POP   DX
        POP   BX
        RET

_CFRT_ARRCLEAR:
        MOV   WORD PTR [SI], 0
        RET

_CFRT_ARRTOLIST:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        PUSH   SI
        PUSH   DI
        MOV   CX, [SI]
        MOV   BX, OFFSET _CF_STRBUF
        ADD   SI, 2
        OR   CX, CX
        JZ   _CFRT_A2L_E
        XOR   DX, DX
_CFRT_A2L_LP:
        OR   DX, DX
        JZ   _CFRT_A2L_ND
        PUSH   SI
        PUSH   DI
        MOV   SI, [SP]
_CFRT_A2L_DL:
        LODSB
        OR   AL, AL
        JZ   _CFRT_A2L_DD
        MOV   [BX], AL
        INC   BX
        JMP   _CFRT_A2L_DL
_CFRT_A2L_DD:
        POP   DI
        POP   SI
_CFRT_A2L_ND:
        MOV   AX, [SI]
        ADD   SI, 2
        PUSH   CX
        PUSH   DX
        PUSH   SI
        PUSH   DI
        MOV   DI, BX
        OR   AX, AX
        JNS   _CFRT_A2L_PS
        MOV   BYTE PTR [DI], '-'
        INC   DI
        NEG   AX
_CFRT_A2L_PS:
        XOR   CX, CX
_CFRT_A2L_D1:
        XOR   DX, DX
        MOV   SI, 10
        DIV   SI
        ADD   DL, '0'
        PUSH   DX
        INC   CX
        OR   AX, AX
        JNZ   _CFRT_A2L_D1
_CFRT_A2L_D2:
        POP   AX
        MOV   [DI], AL
        INC   DI
        LOOP   _CFRT_A2L_D2
        MOV   BX, DI
        POP   DI
        POP   SI
        POP   DX
        POP   CX
        INC   DX
        DEC   CX
        JNZ   _CFRT_A2L_LP
_CFRT_A2L_E:
        MOV   BYTE PTR [BX], 0
        MOV   AX, OFFSET _CF_STRBUF
        POP   DI
        POP   SI
        POP   DX
        POP   CX
        POP   BX
        RET

_CFRT_STRCMP:
        PUSH   BX
        PUSH   SI
        PUSH   DI
_CFRT_SCMP_LP:
        MOV   AL, [SI]
        MOV   AH, [DI]
        CMP   AL, AH
        JNE   _CFRT_SCMP_NE
        OR   AL, AL
        JZ   _CFRT_SCMP_EQ
        INC   SI
        INC   DI
        JMP   _CFRT_SCMP_LP
_CFRT_SCMP_EQ:
        XOR   AX, AX
        JMP   _CFRT_SCMP_RT
_CFRT_SCMP_NE:
        XOR   AH, AH
        MOV   BL, [DI]
        XOR   BH, BH
        SUB   AX, BX
_CFRT_SCMP_RT:
        POP   DI
        POP   SI
        POP   BX
        RET

_CFRT_STINSERT:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        PUSH   SI
        PUSH   DI
        MOV   DX, AX
        MOV   CX, [SI]
        MOV   BX, SI
        ADD   BX, 2
_CFRT_STI_LP:
        OR   CX, CX
        JZ   _CFRT_STI_NEW
        PUSH   CX
        PUSH   BX
        PUSH   DI
        PUSH   SI
        MOV   SI, [BX]
        CALL   _CFRT_STRCMP
        POP   SI
        POP   DI
        POP   BX
        POP   CX
        OR   AX, AX
        JZ   _CFRT_STI_UPD
        ADD   BX, 4
        DEC   CX
        JMP   _CFRT_STI_LP
_CFRT_STI_UPD:
        MOV   [BX+2], DX
        JMP   _CFRT_STI_DN
_CFRT_STI_NEW:
        POP   DI
        POP   SI
        CMP   WORD PTR [SI], 32
        JAE   _CFRT_STI_FUL
        INC   WORD PTR [SI]
        MOV   [BX], DI
        MOV   [BX+2], DX
_CFRT_STI_FUL:
        POP   DX
        POP   CX
        POP   BX
        RET
_CFRT_STI_DN:
        POP   DI
        POP   SI
        POP   DX
        POP   CX
        POP   BX
        RET

_CFRT_STFIND:
        PUSH   BX
        PUSH   CX
        PUSH   SI
        PUSH   DI
        MOV   CX, [SI]
        MOV   BX, SI
        ADD   BX, 2
_CFRT_STF_LP:
        OR   CX, CX
        JZ   _CFRT_STF_NF
        PUSH   CX
        PUSH   BX
        PUSH   DI
        PUSH   SI
        MOV   SI, [BX]
        CALL   _CFRT_STRCMP
        POP   SI
        POP   DI
        POP   BX
        POP   CX
        OR   AX, AX
        JZ   _CFRT_STF_OK
        ADD   BX, 4
        DEC   CX
        JMP   _CFRT_STF_LP
_CFRT_STF_OK:
        MOV   AX, [BX+2]
        JMP   _CFRT_STF_RT
_CFRT_STF_NF:
        XOR   AX, AX
_CFRT_STF_RT:
        POP   DI
        POP   SI
        POP   CX
        POP   BX
        RET

_CFRT_STRUCTGET:
        JMP   _CFRT_STFIND

_CFRT_STKEYEX:
        PUSH   BX
        PUSH   CX
        PUSH   SI
        PUSH   DI
        MOV   CX, [SI]
        MOV   BX, SI
        ADD   BX, 2
_CFRT_SKE_LP:
        OR   CX, CX
        JZ   _CFRT_SKE_NF
        PUSH   CX
        PUSH   BX
        PUSH   DI
        PUSH   SI
        MOV   SI, [BX]
        CALL   _CFRT_STRCMP
        POP   SI
        POP   DI
        POP   BX
        POP   CX
        OR   AX, AX
        JZ   _CFRT_SKE_OK
        ADD   BX, 4
        DEC   CX
        JMP   _CFRT_SKE_LP
_CFRT_SKE_OK:
        MOV   AX, 1
        JMP   _CFRT_SKE_RT
_CFRT_SKE_NF:
        XOR   AX, AX
_CFRT_SKE_RT:
        POP   DI
        POP   SI
        POP   CX
        POP   BX
        RET

_CFRT_STDEL:
        PUSH   AX
        PUSH   BX
        PUSH   CX
        PUSH   DX
        PUSH   SI
        PUSH   DI
        MOV   CX, [SI]
        MOV   BX, SI
        ADD   BX, 2
        XOR   DX, DX
_CFRT_SDL_LP:
        OR   CX, CX
        JZ   _CFRT_SDL_DN
        PUSH   CX
        PUSH   BX
        PUSH   DI
        PUSH   SI
        MOV   SI, [BX]
        CALL   _CFRT_STRCMP
        POP   SI
        POP   DI
        POP   BX
        POP   CX
        OR   AX, AX
        JZ   _CFRT_SDL_FD
        ADD   BX, 4
        INC   DX
        DEC   CX
        JMP   _CFRT_SDL_LP
_CFRT_SDL_FD:
        DEC   CX
_CFRT_SDL_SH:
        OR   CX, CX
        JZ   _CFRT_SDL_SD
        MOV   AX, [BX+4]
        MOV   [BX], AX
        MOV   AX, [BX+6]
        MOV   [BX+2], AX
        ADD   BX, 4
        DEC   CX
        JMP   _CFRT_SDL_SH
_CFRT_SDL_SD:
        POP   DI
        POP   SI
        DEC   WORD PTR [SI]
        JMP   _CFRT_SDL_RT
_CFRT_SDL_DN:
        POP   DI
        POP   SI
_CFRT_SDL_RT:
        POP   DX
        POP   CX
        POP   BX
        POP   AX
        RET

_CFRT_STCOUNT:
        MOV   AX, [SI]
        RET

_CFRT_STKEYLIST:
        PUSH   BX
        PUSH   CX
        PUSH   DX
        PUSH   SI
        PUSH   DI
        MOV   CX, [SI]
        ADD   SI, 2
        MOV   DI, OFFSET _CF_STRBUF
        XOR   DX, DX
_CFRT_SKL_LP:
        OR   CX, CX
        JZ   _CFRT_SKL_DN
        OR   DX, DX
        JZ   _CFRT_SKL_NC
        MOV   BYTE PTR [DI], ','
        INC   DI
_CFRT_SKL_NC:
        MOV   DX, 1
        PUSH   SI
        MOV   SI, [SI]
_CFRT_SKL_CC:
        LODSB
        OR   AL, AL
        JZ   _CFRT_SKL_CD
        STOSB
        JMP   _CFRT_SKL_CC
_CFRT_SKL_CD:
        POP   SI
        ADD   SI, 4
        DEC   CX
        JMP   _CFRT_SKL_LP
_CFRT_SKL_DN:
        MOV   BYTE PTR [DI], 0
        MOV   AX, OFFSET _CF_STRBUF
        POP   DI
        POP   SI
        POP   DX
        POP   CX
        POP   BX
        RET

_CFRT_STCLEAR:
        MOV   WORD PTR [SI], 0
        RET

_CFRT_SCSTART:
        MOV   WORD PTR [_CF_SCPOS], 0
        MOV   DI, OFFSET _CF_SCBUF
        MOV   BYTE PTR [DI], 0
        RET

_CFRT_SCAPPEND:
        PUSH   SI
        MOV   DI, OFFSET _CF_SCBUF
        ADD   DI, [_CF_SCPOS]
_CFRT_SCA_LP:
        LODSB
        OR   AL, AL
        JZ   _CFRT_SCA_DN
        STOSB
        JMP   _CFRT_SCA_LP
_CFRT_SCA_DN:
        MOV   BYTE PTR [DI], 0
        SUB   DI, OFFSET _CF_SCBUF
        MOV   [_CF_SCPOS], DI
        POP   SI
        RET

_CFRT_SCAPPNUM:
        CALL   _CFRT_NUMTOSTR
        MOV   SI, AX
        CALL   _CFRT_SCAPPEND
        RET

_TEXT ENDS

_DATA SEGMENT PUBLIC 'DATA'

; Donnees statiques CF86

_CF_CRLF  DB  13,10,0
_CF_NULL_STR  DB  0
_CF_STRBUF  DB  256 DUP(0)
_CF_TXTBUF  DB  512 DUP(0)
_CF_NUMBUF  DB  12 DUP(0)
_CF_SWTMP  DW  0
_CF_LOOPLIM  DW  0
_CF_LOOPSTP  DW  0
_CF_STRBUF2  DB  256 DUP(0)
_CF_SCBUF  DB  512 DUP(0)
_CF_SCPOS  DW  0
_CFL_1  DB  130 DUP(0)
_CFK_4  DB  'Grr!',0
_CFK_7  DB  'Animal',0
_CFK_9  DB  'nom',0
_CFK_12  DB  'pattes',0
_CFL_14  DB  130 DUP(0)
_CFV_chat  DW  0
_CFK_15  DB  'Chat cree',0
_CFL_16  DB  130 DUP(0)
_CFK_19  DB  'Wouf!',0
_CFK_25  DB  'race',0
_CFL_27  DB  130 DUP(0)
_CFV_rex  DW  0
_CFK_28  DB  'Rex cree',0
_CFV_son  DW  0
_CFK_29  DB  'Son: ',0
_CFK_30  DB  'Test composant OK',0

_DATA ENDS

END _CFF_Main
