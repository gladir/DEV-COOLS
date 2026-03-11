; TPCW32 - Compilateur Turbo Pascal -> ASM 8086 DOS
; Mode DOS 16 bits - genere a partir de : SAMPLES/PASCAL/test_pe.pas

.8086
.MODEL SMALL
.STACK 1024

; --- Segment de donnees DOS 16 bits ---
.DATA

NUMBUF   DB 16 DUP(0)
INBUF    DB 128 DUP(0)
CRLF     DB 13,10,'$'
STRTMP   DB 128 DUP(0)
TRUE_STR DB 'TRUE','$'
FALSE_STR DB 'FALSE','$'

_TPK_1 DB 'TestPE',0
_TPK_2 DB 'Hello PE',0
_TPK_3 DB ' ',0
_TPV_X DW 0
_TPV_S DB 256 DUP(0)

; --- Segment de code DOS 16 bits ---
.CODE

_TPF_Main:
        MOV AX,@DATA
        MOV DS,AX

; Corps du programme (TODO 25)
        MOV AX,4C00h
        INT 21h

END _TPF_Main
