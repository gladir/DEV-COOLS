; TPCW32 - Compilateur Turbo Pascal -> ASM 80386 Win32
; Genere automatiquement a partir de : SAMPLES/PASCAL/testwrite.pas

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
_TPK_1  DB 'A',0
_TPK_2  DB 'Test du compilateur PC8086',0
_TPK_3  DB 'Nombre: ',0
_TPK_4  DB 'Lettre: ',0
_TPK_5  DB 'Bool',195,169,'en: ',0
_TPK_6  DB 'Fin du test',0
_TPV_NOMBRE  DD 0
_TPV_LETTRE  DB 0
_TPV_FLAG  DB 0
_TPV_NOM  DB 256 DUP(0)

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
        MOV DWORD PTR [_TPV_NOMBRE],EAX
        LEA EAX,[_TPK_1]
        MOV BYTE PTR [_TPV_LETTRE],AL
        MOV EAX,1
        MOV BYTE PTR [_TPV_FLAG],AL
        LEA EAX,[_TPK_2]
        PUSH EAX
        CALL _TPF_WRITELN
        ADD ESP,4
        LEA EAX,[_TPK_3]
        PUSH EAX
        CALL _TPF_WRITE
        ADD ESP,4
        MOV EAX,DWORD PTR [_TPV_NOMBRE]
        PUSH EAX
        CALL _TPF_WRITELN
        ADD ESP,4
        LEA EAX,[_TPK_4]
        PUSH EAX
        CALL _TPF_WRITE
        ADD ESP,4
        MOVZX EAX,BYTE PTR [_TPV_LETTRE]
        PUSH EAX
        CALL _TPF_WRITELN
        ADD ESP,4
        LEA EAX,[_TPK_5]
        PUSH EAX
        CALL _TPF_WRITE
        ADD ESP,4
        MOVZX EAX,BYTE PTR [_TPV_FLAG]
        PUSH EAX
        CALL _TPF_WRITELN
        ADD ESP,4
        LEA EAX,[_TPK_6]
        PUSH EAX
        CALL _TPF_WRITELN
        ADD ESP,4
_TPL_1:
        PUSH 0
        CALL ExitProcess
        MOV ESP,EBP
        POP EBP
        RET
END _TPF_Main
