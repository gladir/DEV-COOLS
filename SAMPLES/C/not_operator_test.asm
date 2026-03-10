; CCW32 - Compilateur C vers ASM 80386 pour Windows 32 bits
; Genere automatiquement a partir de : SAMPLES/C/not_operator_test.c

.386
.MODEL FLAT, STDCALL

; --- Imports Win32 (kernel32.dll) ---
EXTRN _ExitProcess@4:NEAR
EXTRN _GetStdHandle@4:NEAR
EXTRN _WriteFile@20:NEAR
EXTRN _ReadFile@20:NEAR
EXTRN _GetProcessHeap@0:NEAR
EXTRN _HeapAlloc@12:NEAR
EXTRN _HeapFree@12:NEAR

; --- Segment de donnees ---
.DATA

HSTDOUT  DD 0
HSTDIN   DD 0
HHEAP    DD 0
NUMBUF   DB 16 DUP(0)
INBUF    DB 256 DUP(0)
BYTESWR  DD 0
BYTESRD  DD 0
CRLF     DB 13,10,0

_CCK_1  DB '!0 = %d (devrait ',195,170,'tre 1)',10,0
_CCK_2  DB '!1 = %d (devrait ',195,170,'tre 0)',10,0
_CCK_3  DB '!5 = %d (devrait ',195,170,'tre 0)',10,0
_CCK_4  DB '!(-3) = %d (devrait ',195,170,'tre 0)',10,0
_CCK_5  DB '!(10 > 5) = %d (devrait ',195,170,'tre 0)',10,0
_CCK_6  DB '!(10 < 5) = %d (devrait ',195,170,'tre 1)',10,0
_CCK_7  DB '!!0 = %d (devrait ',195,170,'tre 0)',10,0
_CCK_8  DB '!!7 = %d (devrait ',195,170,'tre 1)',10,0

; --- Segment de code ---
.CODE

END
