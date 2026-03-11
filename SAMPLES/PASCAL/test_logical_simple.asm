; TPCW32 - Compilateur Turbo Pascal -> ASM 80386 Win32
; Genere automatiquement a partir de : SAMPLES/PASCAL/test_logical_simple.pas

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
_TPK_1  DB 'AND result: ',0
_TPK_2  DB 'OR result: ',0
_TPK_3  DB 'XOR result: ',0
_TPV_VAL1  DD 0
_TPV_VAL2  DD 0
_TPV_RES  DD 0

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
        MOV EAX,15
        MOV DWORD PTR [_TPV_VAL1],EAX
        MOV EAX,7
        MOV DWORD PTR [_TPV_VAL2],EAX
        MOV EAX,DWORD PTR [_TPV_VAL1]
        TEST EAX,EAX
        JZ _TPL_2
        MOV EAX,DWORD PTR [_TPV_VAL2]
        TEST EAX,EAX
        JZ _TPL_2
        MOV EAX,1
        JMP _TPL_3
_TPL_2:
        XOR EAX,EAX
_TPL_3:
        MOV DWORD PTR [_TPV_RES],EAX
        LEA EAX,[_TPK_1]
        PUSH EAX
        MOV EAX,DWORD PTR [_TPV_RES]
        PUSH EAX
        CALL _TPF_WRITELN
        ADD ESP,8
        MOV EAX,DWORD PTR [_TPV_VAL1]
        TEST EAX,EAX
        JNZ _TPL_4
        MOV EAX,DWORD PTR [_TPV_VAL2]
        TEST EAX,EAX
        JNZ _TPL_4
        XOR EAX,EAX
        JMP _TPL_5
_TPL_4:
        MOV EAX,1
_TPL_5:
        MOV DWORD PTR [_TPV_RES],EAX
        LEA EAX,[_TPK_2]
        PUSH EAX
        MOV EAX,DWORD PTR [_TPV_RES]
        PUSH EAX
        CALL _TPF_WRITELN
        ADD ESP,8
        MOV EAX,DWORD PTR [_TPV_VAL1]
        PUSH EAX
        MOV EAX,DWORD PTR [_TPV_VAL2]
        MOV EBX,EAX
        POP EAX
        XOR EAX,EBX
        MOV DWORD PTR [_TPV_RES],EAX
        LEA EAX,[_TPK_3]
        PUSH EAX
        MOV EAX,DWORD PTR [_TPV_RES]
        PUSH EAX
        CALL _TPF_WRITELN
        ADD ESP,8
_TPL_1:
        PUSH 0
        CALL ExitProcess
        MOV ESP,EBP
        POP EBP
        RET
END _TPF_Main
