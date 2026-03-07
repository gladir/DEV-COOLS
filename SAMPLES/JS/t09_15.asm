; Genere par JS86 v1.0 - t09_15.js

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
   