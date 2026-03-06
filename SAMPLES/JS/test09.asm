; Genere par JS86 v1.0 - SAMPLES/JS/test09.js

        .MODEL SMALL
        .STACK 1024

_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME  CS:_TEXT, DS:_DATA, SS:STACK

; --- debut du code genere ---

        MOV   AX, 42
        MOV   [_JSV_x], AX
        MOV   AX, 10
        MOV   [_JSV_y], AX
        MOV   [_JSV_z], 0
        MOV   AX, [_JSV_x]
        MOV   [_JSV_z], AX
        MOV   AX, [_JSV_y]
        MOV   [_JSV_z], AX
        MOV   AX, 5
        MOV   BX, AX
        MOV   AX, [_JSV_x]
        ADD   AX, BX
        MOV   [_JSV_x], AX
        MOV   AX, 3
        MOV   BX, AX
        MOV   AX, [_JSV_y]
        SUB   AX, BX
        MOV   [_JSV_y], AX
        MOV   AX, 3
        MOV   [_JSV_PI], AX
        MOV   AX, 0
        MOV   [_JSV_count], AX
        MOV   AX, [_JSV_count]
        MOV   [_JSV_count], AX

; --- fin du code genere ---

_TEXT   ENDS

_DATA   SEGMENT WORD PUBLIC 'DATA'
_JS_UNDEF   DB  'undefined',0
_JS_NULL    DB  'null',0
_JS_TRUE    DB  'true',0
_JS_FALSE   DB  'false',0
_JSRT_STRBUF DB 512 DUP(0)
_JSV_x  DW  0
_JSV_y  DW  0
_JSV_z  DW  0
_JSV_PI  DW  0
_JSV_count  DW  0
_DATA   ENDS

        END
