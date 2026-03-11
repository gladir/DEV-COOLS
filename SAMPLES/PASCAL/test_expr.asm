; TPCW32 - Compilateur Turbo Pascal -> ASM 80386 Win32
; Genere automatiquement a partir de : SAMPLES/PASCAL/test_expr.pas

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
_TPK_1  DB 'Hello World',0
_TPK_2  DB 'A',0
_TPK_3  DB 'Test',0
_TPV_X  DD 0
_TPV_Y  DD 0
_TPV_Z  DD 0
_TPV_C  DB 0
_TPV_B  DB 0
_TPV_S  DB 256 DUP(0)

; --- Segment de code ---
.CODE


; --- Programme principal ---
_TPF_Main:
        PUSH EBP
        MOV EBP,ESP
; Obtenir STDOUT
        PUSH -11
        CALL GetStdHandle
        MOV [HSTDOUT],EAX
; Obtenir STDIN
        PUSH -10
        CALL GetStdHandle
        MOV [HSTDIN],EAX
; Obtenir le tas du processus
        CALL GetProcessHeap
        MOV [HHEAP],EAX
        MOV EAX,42
        MOV DWORD PTR [_TPV_X],EAX
        MOV EAX,0
        MOV DWORD PTR [_TPV_Y],EAX
        MOV EAX,1
        NEG EAX
        MOV DWORD PTR [_TPV_Z],EAX
        MOV EAX,100
        MOV DWORD PTR [_TPV_X],EAX
        MOV EAX,DWORD PTR [_TPV_X]
        MOV DWORD PTR [_TPV_Y],EAX
        MOV EAX,65
        AND EAX,0FFh
        MOV BYTE PTR [_TPV_C],AL
        MOV EAX,1
        MOV BYTE PTR [_TPV_B],AL
        XOR EAX,EAX
        MOV BYTE PTR [_TPV_B],AL
        LEA EAX,[_TPK_1]
        MOV DWORD PTR [_TPV_S],EAX
        MOV EAX,4
        MOV DWORD PTR [_TPV_X],EAX
        LEA EAX,[_TPK_2]
        AND EAX,0FFh
        MOV DWORD PTR [_TPV_X],EAX
        MOV EAX,66
        AND EAX,0FFh
        MOV BYTE PTR [_TPV_C],AL
        MOV EAX,5
        INC EAX
        MOV DWORD PTR [_TPV_X],EAX
        MOV EAX,10
        DEC EAX
        MOV DWORD PTR [_TPV_Y],EAX
        MOV EAX,7
        NEG EAX
        CDQ
        XOR EAX,EDX
        SUB EAX,EDX
        MOV DWORD PTR [_TPV_X],EAX
        MOV EAX,3
        IMUL EAX,EAX
        MOV DWORD PTR [_TPV_Y],EAX
        MOV EAX,5
        AND EAX,1
        MOV BYTE PTR [_TPV_B],AL
        MOV EAX,256
        AND EAX,0FFh
        MOV DWORD PTR [_TPV_X],EAX
        MOV EAX,256
        SHR EAX,8
        AND EAX,0FFh
        MOV DWORD PTR [_TPV_Y],EAX
        MOV EAX,10
        MOV DWORD PTR [_TPV_X],EAX
        MOV EAX,DWORD PTR [_TPV_X]
        INC EAX
        MOV DWORD PTR [_TPV_X],EAX
        MOV EAX,DWORD PTR [_TPV_X]
        DEC EAX
        MOV DWORD PTR [_TPV_X],EAX
        MOV EAX,5
        MOV ECX,EAX
        MOV EAX,DWORD PTR [_TPV_X]
        ADD EAX,ECX
        MOV DWORD PTR [_TPV_X],EAX
        MOV EAX,3
        MOV ECX,EAX
        MOV EAX,DWORD PTR [_TPV_X]
        SUB EAX,ECX
        MOV DWORD PTR [_TPV_X],EAX
        CALL _TPF_WRITELN
        MOV EAX,42
        PUSH EAX
        CALL _TPF_WRITE
        ADD ESP,4
        MOV EAX,DWORD PTR [_TPV_X]
        PUSH EAX
        CALL _TPF_WRITELN
        ADD ESP,4
        LEA EAX,[_TPK_3]
        PUSH EAX
        CALL _TPF_WRITE
        ADD ESP,4
_TPL_1:
        PUSH 0
        CALL ExitProcess
        MOV ESP,EBP
        POP EBP
        RET
END _TPF_Main
