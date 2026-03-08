; ========================================
; Genere par PSPCW32 v1.0 (2026-03-07)
; Source : SAMPLES/PSP/test_directives.psp
; Cible  : Win32 / 80386 / PE
; ========================================

.386
.MODEL FLAT, STDCALL
OPTION CASEMAP:NONE

; --- Declarations externes Win32 ---
EXTRN   _ExitProcess@4       : PROC
EXTRN   _GetStdHandle@4      : PROC
EXTRN   _WriteFile@20        : PROC
EXTRN   _ReadFile@20         : PROC
EXTRN   _GetProcessHeap@0    : PROC
EXTRN   _HeapAlloc@12        : PROC
EXTRN   _HeapFree@12         : PROC
EXTRN   _GetTickCount@0      : PROC

.STACK 4096

; --- Segment de code ---
_TEXT   SEGMENT DWORD PUBLIC 'CODE'
        ASSUME CS:_TEXT

; --- Point d entree principal ---
_PSPF_main:
; Obtenir le handle stdout
        PUSH   -11
  