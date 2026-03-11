; TPCW32 - Compilateur Turbo Pascal -> ASM 80386 Win32
; Genere automatiquement a partir de : SAMPLES/PASCAL/test_debug.pas

.386
.MODEL FLAT, STDCALL

; --- Imports Win32 (kernel32.dll) ---
EXTRN _ExitProcess@4:NEAR
EXTRN _GetStdHandle@4:NEAR
EXTRN _WriteFile@20:NEAR
EXTRN _ReadFile@20:NEAR
EXTRN _WriteConsoleA@20:NEAR
EXTRN _ReadConsoleA@20:NEAR
EXTRN _SetConsoleCursorPosition@8:NEAR
EXTRN _GetConsoleScreenBufferInfo@8:NEAR
EXTRN _SetConsoleTextAttribute@8:NEAR
EXTRN _FillConsoleOutputCharacterA@20:NEAR
EXTRN _FillConsoleOutputAttribute@20:NEAR
EXTRN _GetConsoleMode@8:NEAR
EXTRN _SetConsoleMode@8:NEAR
EXTRN _GetProcessHeap@0:NEAR
EXTRN _HeapAlloc@12:NEAR
EXTRN _HeapFree@12:NEAR
EXTRN _CreateFileA@28:NEAR
EXTRN _CloseHandle@4:NEAR
EXTRN _SetFilePointer@16:NEAR
EXTRN _GetFileSize@8:NEAR
EXTRN _DeleteFileA@4:NEAR
EXTRN _CreateDirectoryA@8:NEAR
EXTRN _RemoveDirectoryA@4:NEAR
EXTRN _SetCurrentDirectoryA@4:NEAR
EXTRN _GetCurrentDirectoryA@8:NEAR
EXTRN _GetTickCount@0:NEAR
EXTRN _Sleep@4:NEAR
EXTRN _GetCommandLineA@0:NEAR

; --- Segment de donnees ---
.DATA

; --- Variables runtime TPCW32 ---
HSTDOUT   DD 0
HSTDIN    DD 0
HHEAP     DD 0
NUMBUF    DB 32 DUP(0)
INBUF     DB 256 DUP(0)
BYTESWR   DD 0
BYTESRD   DD 0
CRLF      DB 13,10,0
STRTMP    DB 256 DUP(0)

; --- Constantes et donnees utilisateur ---
_TPK_1  DB 'DEBUG: Testing string: "',0
_TPK_2  DB '" (length=',0
_TPK_3  DB ')',0
_TPK_4  DB 'DEBUG: Pos("ldd   ", s) = ',0
_TPK_5  DB 'ldd   ',0
_TPK_6  DB 'DEBUG: Pos("std   ", s) = ',0
_TPK_7  DB 'std   ',0
_TPK_8  DB 'iload ',0
_TPK_9  DB 'DEBUG: Converted to: "',0
_TPK_10  DB '"',0
_TPK_11  DB 'istore ',0
_TPK_12  DB 'DEBUG: No pattern matched',0
_TPK_13  DB 'Test 1:',0
_TPK_14  DB 'ldd   x',0
_TPK_15  DB 'Test 2:',0
_TPK_16  DB 'std   x',0
_TPV_RESULT  DB 256 DUP(0)

; --- Segment de code ---
.CODE

END
