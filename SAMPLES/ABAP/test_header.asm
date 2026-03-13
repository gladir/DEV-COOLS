        ; ========================================
        ; Genere par ABAPCW32 V0.1
        ; Source : SAMPLES/ABAP/test_header.abap
        ; Cible  : Win32 / 80386 / PE
        ; ========================================

.386
.MODEL FLAT, STDCALL
OPTION CASEMAP:NONE

        ; --- Declarations externes Win32 (kernel32.dll) ---
EXTRN   _ExitProcess@4       : PROC
EXTRN   _GetStdHandle@4      : PROC
EXTRN   _WriteFile@20        : PROC
EXTRN   _ReadFile@20         : PROC
EXTRN   _GetProcessHeap@0    : PROC
EXTRN   _HeapAlloc@12        : PROC
EXTRN   _HeapFree@12         : PROC

.STACK 4096

        ; --- Segment de code ---
_TEXT   SEGMENT DWORD PUBLIC 'CODE'
        ASSUME CS:_TEXT

        ; COMPUTE
        MOV     EAX, DWORD PTR [_AB_LV_COUNT]
        PUSH    EAX
        MOV     EAX, 8
        MOV     EBX, EAX
        POP     EAX
        ADD     EAX, EBX
        ; COMPUTE: variable inconnue: LV_TOTAL
        ; WRITE
        LEA     EAX, [_ABK_1]
        CALL    _ABRT_PRINT
        MOV     EAX, DWORD PTR [_AB_LV_COUNT]
        CALL    _ABRT_PRINTINT
        ; WRITE
        CALL    _ABRT_CRLF
        ; WRITE
        CALL    _ABRT_CRLF

_TEXT   ENDS

        ; ========================================
        ; SEGMENT DE DONNEES (.DATA)
        ; ========================================

_DATA   SEGMENT DWORD PUBLIC 'DATA'
        ASSUME DS:_DATA

        ; --- Variables globales ---
_SY_SUBRC DD 0
_SY_TABIX DD 0
_SY_DBCNT DD 0
_SY_INDEX DD 0
_SY_LANGU DB 1 DUP(32), 0
_SY_MANDT DB 3 DUP(32), 0
_SY_DATUM DB 8 DUP(32), 0
_SY_UZEIT DB 6 DUP(32), 0
_SY_UNAME DB 12 DUP(32), 0
_AB_LV_COUNT DD 42
_AB_LV_NAME DB 1 DUP(32), 0


        ; --- Donnees tables internes (TODO 16) ---

        ; --- Tampons runtime ---
_ABRT_HSTDOUT    DD 0
_ABRT_HSTDIN     DD 0
_ABRT_WRITTEN    DD 0
_ABRT_NUMBUF     DB 12 DUP(0)
_ABRT_CRLF_DATA  DB 13, 10, 0
_ABRT_SPACE_DATA DB 32, 0
_ABRT_STRBUF     DB 512 DUP(0)
_ABRT_CATBUF     DB 512 DUP(0)
_ABRT_INPUTBUF   DB 256 DUP(0)

        ; --- Chaines litterales ---
_ABK_1 DB 'Compteur:',0

_DATA   ENDS

END _ABF_ZTEST_HEADER
