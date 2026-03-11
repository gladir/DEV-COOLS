; TPCW32 - Compilateur Turbo Pascal -> ASM 80386 Win32
; Genere automatiquement a partir de : SAMPLES/PASCAL/testrepeat.pas

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
TRUE_STR  DB 'TRUE',0
FALSE_STR DB 'FALSE',0

; --- Constantes et donnees utilisateur ---
_TPK_1  DB '=== Test des boucles REPEAT UNTIL ===',0
_TPK_2  DB 'Comptage de 1 ',195,160,' 5:',0
_TPK_3  DB 'Compteur: ',0
_TPK_4  DB 'Fin du comptage',0
_TPK_5  DB 'D',195,169,'compte de 10 ',195,160,' 0:',0
_TPK_6  DB 'Valeur: ',0
_TPK_7  DB 'Tous les tests termin',195,169,'s !',0
_TPV_COMPTEUR  DD 0
_TPV_NOMBRE  DD 0

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
        MOV EAX,1
        MOV DWORD PTR [_TPV_COMPTEUR],EAX
        MOV EAX,5
        MOV DWORD PTR [_TPV_NOMBRE],EAX
; writeln
        LEA EAX,[_TPK_1]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
; writeln
        LEA EAX,[_TPK_2]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
; repeat
_TPL_2:
; write
        LEA EAX,[_TPK_3]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
; writeln
        MOV EAX,DWORD PTR [_TPV_COMPTEUR]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        MOV EAX,DWORD PTR [_TPV_COMPTEUR]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [_TPV_COMPTEUR],EAX
        MOV EAX,DWORD PTR [_TPV_COMPTEUR]
        PUSH EAX
        MOV EAX,DWORD PTR [_TPV_NOMBRE]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _TPL_4
        XOR EAX,EAX
        JMP _TPL_5
_TPL_4:
        MOV EAX,1
_TPL_5:
        TEST EAX,EAX
        JZ _TPL_2
_TPL_3:
; writeln
        LEA EAX,[_TPK_4]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        MOV EAX,10
        MOV DWORD PTR [_TPV_COMPTEUR],EAX
; writeln
        LEA EAX,[_TPK_5]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
; repeat
_TPL_6:
; write
        LEA EAX,[_TPK_6]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
; writeln
        MOV EAX,DWORD PTR [_TPV_COMPTEUR]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        MOV EAX,DWORD PTR [_TPV_COMPTEUR]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        SUB EAX,EBX
        MOV DWORD PTR [_TPV_COMPTEUR],EAX
        MOV EAX,DWORD PTR [_TPV_COMPTEUR]
        PUSH EAX
        MOV EAX,0
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JLE _TPL_8
        XOR EAX,EAX
        JMP _TPL_9
_TPL_8:
        MOV EAX,1
_TPL_9:
        TEST EAX,EAX
        JZ _TPL_6
_TPL_7:
; writeln
        LEA EAX,[_TPK_7]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
_TPL_1:
        PUSH 0
        CALL ExitProcess
        MOV ESP,EBP
        POP EBP
        RET

; === Routines runtime TPCW32 ===

_TPRT_PRINTSTR:
        PUSHAD
        XOR ECX,ECX
_TPRT_PSTR_L:
        CMP BYTE PTR [ESI+ECX],0
        JE _TPRT_PSTR_G
        INC ECX
        JMP _TPRT_PSTR_L
_TPRT_PSTR_G:
        TEST ECX,ECX
        JZ _TPRT_PSTR_D
        PUSH 0
        PUSH OFFSET BYTESWR
        PUSH ECX
        PUSH ESI
        PUSH DWORD PTR [HSTDOUT]
        CALL WriteFile
_TPRT_PSTR_D:
        POPAD
        RET

_TPRT_NUMTOSTR:
        PUSHAD
        LEA EDI,[NUMBUF]
        XOR ECX,ECX
        TEST EAX,EAX
        JGE _TPRT_NTS_POS
        MOV BYTE PTR [EDI],45
        INC EDI
        NEG EAX
_TPRT_NTS_POS:
        MOV EBX,10
_TPRT_NTS_DIV:
        XOR EDX,EDX
        DIV EBX
        ADD DL,48
        PUSH EDX
        INC ECX
        TEST EAX,EAX
        JNZ _TPRT_NTS_DIV
_TPRT_NTS_POP:
        POP EAX
        MOV [EDI],AL
        INC EDI
        DEC ECX
        JNZ _TPRT_NTS_POP
        MOV BYTE PTR [EDI],0
        POPAD
        RET

_TPRT_STRTONUM:
        PUSH EBX
        PUSH ECX
        PUSH EDX
        XOR EAX,EAX
        XOR ECX,ECX
        CMP BYTE PTR [ESI],45
        JNE _TPRT_STN_LP
        INC ESI
        INC ECX
_TPRT_STN_LP:
        MOVZX EDX,BYTE PTR [ESI]
        TEST DL,DL
        JZ _TPRT_STN_DN
        CMP DL,48
        JB _TPRT_STN_DN
        CMP DL,57
        JA _TPRT_STN_DN
        SUB DL,48
        IMUL EAX,EAX,10
        ADD EAX,EDX
        INC ESI
        JMP _TPRT_STN_LP
_TPRT_STN_DN:
        TEST ECX,ECX
        JZ _TPRT_STN_RT
        NEG EAX
_TPRT_STN_RT:
        POP EDX
        POP ECX
        POP EBX
        RET

_TPRT_READLN:
        PUSHAD
        PUSH 0
        PUSH OFFSET BYTESRD
        PUSH 255
        PUSH OFFSET INBUF
        PUSH DWORD PTR [HSTDIN]
        CALL ReadFile
        MOV ECX,DWORD PTR [BYTESRD]
_TPRT_RL_TR:
        TEST ECX,ECX
        JZ _TPRT_RL_DN
        DEC ECX
        CMP BYTE PTR [INBUF+ECX],13
        JE _TPRT_RL_TR
        CMP BYTE PTR [INBUF+ECX],10
        JE _TPRT_RL_TR
        INC ECX
_TPRT_RL_DN:
        MOV BYTE PTR [INBUF+ECX],0
        POPAD
        RET

_TPRT_STRCPY:
        PUSH ESI
        PUSH EDI
_TPRT_SCPY_L:
        LODSB
        STOSB
        TEST AL,AL
        JNZ _TPRT_SCPY_L
        POP EDI
        POP ESI
        RET
END _TPF_Main
