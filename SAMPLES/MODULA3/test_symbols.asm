; =========================================================
; Genere par MODIII86 v1.0 (2026-03-11)
; Source  : SAMPLES/MODULA3/test_symbols.m3
; Cible   : MASM 8086, modele SMALL
; =========================================================

        .MODEL SMALL
        .STACK 1024

; --- Segment de code ---
_TEXT   SEGMENT WORD PUBLIC 'CODE'
        ASSUME  CS:_TEXT, DS:_DATA

; --- Point d'entree principal ---
_M3P_Main:
        MOV   AX, _DATA
        MOV   DS, AX


; --- Sortie programme (DOS INT 21h) ---
        MOV   AH, 4Ch
        MOV   AL, 0
        INT    21h

_TEXT   ENDS

_DATA   SEGMENT WORD PUBLIC 'DATA'

; --- Buffers internes Modula-3 ---
_M3RT_CRLF    DB  13,10,0
_M3RT_STRBUF  DB  512 DUP(0)
_M3RT_NUMBUF  DB  12 DUP(0)
_M3RT_TRUE_S  DB  'TRUE',0
_M3RT_FALSE_S DB  'FALSE',0
_M3RT_HEAP    DB  4096 DUP(0)
_M3RT_HEAPTOP DW  OFFSET _M3RT_HEAP

; --- Donnees du programme ---
_M3K_1  DB  'Hello',0
_M3K_2  DB  'Hello, ',0

_DATA   ENDS

        END _M3P_Main
