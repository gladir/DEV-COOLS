; Genere par JS86 v1.0 - t09full.js

        .MODEL SMALL
        .STACK 1024

_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME  CS:_TEXT, DS:_DATA, SS:STACK

; --- debut du code genere ---

        MOV   AX, 14
        MOV   [_JSV_a], AX
        MOV   AX, 20
        MOV   [_JSV_b], AX
        MOV   AX, 4
        MOV   [_JSV_c], AX
        MOV   AX, 1
        MOV   [_JSV_d], AX
        MOV   AX, 10
        MOV   [_JSV_e], AX
        MOV   AX, 1
        MOV   [_JSV_t], AX
        MOV   AX, 0
        MOV   [_JSV_f], AX
        MOV   AX, 1
        MOV   [_JSV_x], AX
        MOV   AX, -1
        MOV   [_JSV_y], AX
        MOV   AX, 1
        MOV   [_JSV_z], AX
        MOV   AX, 1
        MOV   [_JSV_w], AX
        MOV   AX, 1
        MOV   [_JSV_q], AX
        MOV   AX, 1
        MOV   [_JSV_r], AX
        MOV   AX, 1
        OR   AX, AX
        JZ   _JSL_1
        MOV   AX, 0
_JSL_1:
        MOV   [_JSV_s], AX
        MOV   AX, 0
        OR   AX, AX
        JNZ   _JSL_2
        MOV   AX, 1
_JSL_2:
        MOV   [_JSV_u], AX
        XOR   AX, AX
        MOV   AX, 0
        CMP   AX, 0
        JNE   _JSL_3
        MOV   AX, 42
_JSL_3:
        MOV   [_JSV_v], AX
        MOV   AX, 10
        MOV   [_JSV_k], AX
        MOV   [_JSV_m], AX

; --- fin du code genere ---

_TEXT   ENDS

_DATA   SEGMENT WORD PUBLIC 'DATA'
_JS_UNDEF   DB  'undefined',0
_JS_NULL    DB  'null',0
_JS_TRUE    DB  'true',0
_JS_FALSE   DB  'false',0
_JSRT_STRBUF DB 512 DUP(0)
_JS_CRLF    DB  13,10,0
_JS_SPACE   DB  ' ',0
_JS_WARNPFX DB  'Warning: ',0
_JSV_a  DW  0
_JSV_b  DW  0
_JSV_c  DW  0
_JSV_d  DW  0
_JSV_e  DW  0
_JSV_t  DW  0
_JSV_f  DW  0
_JSV_x  DW  0
_JSV_y  DW  0
_JSV_z  DW  0
_JSV_w  DW  0
_JSV_q  DW  0
_JSV_r  DW  0
_JSV_s  DW  0
_JSV_u  DW  0
_JSV_v  DW  0
_JSV_k  DW  0
_JSV_m  DW  0
_DATA   ENDS

        END
