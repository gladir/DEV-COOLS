; TPCW32 - Compilateur Turbo Pascal -> ASM 80386 Win32
; Genere automatiquement a partir de : SAMPLES/PASCAL/TestForward.pas

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
_TPK_1  DB 'R',195,169,'sultat: ',0
_TPK_2  DB 'Test des d',195,169,'clarations FORWARD',0

; --- Segment de code ---
.CODE


; --- CALCULATEFIBONACCI ---
_TPF_CALCULATEFIBONACCI:
        PUSH EBP
        MOV EBP,ESP
        SUB ESP,4
        MOV DWORD PTR [EBP-4],0
        MOV EAX,DWORD PTR [EBP+8]
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        CALL _TPF_CALCULATEFIBONACCI
        ADD ESP,4
        MOV DWORD PTR [EBP-4],EAX
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        CALL _TPF_CALCULATEFIBONACCI
        ADD ESP,4
_TPL_1:
        MOV EAX,DWORD PTR [EBP-4]
        MOV ESP,EBP
        POP EBP
        RET

; --- DISPLAYRESULT ---
_TPF_DISPLAYRESULT:
        PUSH EBP
        MOV EBP,ESP
        LEA EAX,[_TPK_1]
        PUSH EAX
        CALL _TPF_WRITE
        ADD ESP,4
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        CALL _TPF_WRITELN
        ADD ESP,4
_TPL_2:
        MOV ESP,EBP
        POP EBP
        RET

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
        LEA EAX,[_TPK_2]
        PUSH EAX
        CALL _TPF_WRITELN
        ADD ESP,4
        MOV EAX,5
        PUSH EAX
        CALL _TPF_CALCULATEFIBONACCI
        ADD ESP,4
        PUSH EAX
        CALL _TPF_DISPLAYRESULT
        ADD ESP,4
_TPL_3:
        PUSH 0
        CALL ExitProcess
        MOV ESP,EBP
        POP EBP
        RET
END _TPF_Main
