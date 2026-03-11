; TPCW32 - Compilateur Turbo Pascal -> ASM 80386 Win32
; Genere automatiquement a partir de : SAMPLES/PASCAL/test_todo15.pas

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
_TPK_1  DB 'pt.X = ',0
_TPK_2  DB 'pt.Y = ',0
_TPK_3  DB 'arr[1] = ',0
_TPK_4  DB 'arr[3] = ',0
_TPK_5  DB 'arr[5] = ',0
_TPK_6  DB 'colors[2] = ',0
_TPK_7  DB 'b[0] = ',0
_TPK_8  DB 'arr[',0
_TPK_9  DB '] = ',0
_TPK_10  DB 'pt.X + 5 = ',0
_TPK_11  DB 'Ord(Green) = ',0
_TPV_PT  DB 8 DUP(0)
_TPV_ARR  DB 20 DUP(0)
_TPV_COLORS  DB 20 DUP(0)
_TPV_I  DD 0
_TPV_B  DB 10 DUP(0)

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
        LEA EAX,[_TPV_PT]
        PUSH EAX
        MOV EAX,10
        POP EBX
        MOV [EBX],EAX
        LEA EAX,[_TPV_PT]
        ADD EAX,4
        PUSH EAX
        MOV EAX,20
        POP EBX
        MOV [EBX],EAX
; writeln
        LEA EAX,[_TPK_1]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA EAX,[_TPV_PT]
        MOV EAX,[EAX]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
; writeln
        LEA EAX,[_TPK_2]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA EAX,[_TPV_PT]
        ADD EAX,4
        MOV EAX,[EAX]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        LEA EAX,[_TPV_ARR]
        PUSH EAX
        MOV EAX,1
        SUB EAX,1
        SHL EAX,2
        POP EBX
        ADD EBX,EAX
        PUSH EBX
        MOV EAX,100
        POP EBX
        MOV [EBX],EAX
        LEA EAX,[_TPV_ARR]
        PUSH EAX
        MOV EAX,2
        SUB EAX,1
        SHL EAX,2
        POP EBX
        ADD EBX,EAX
        PUSH EBX
        MOV EAX,200
        POP EBX
        MOV [EBX],EAX
        LEA EAX,[_TPV_ARR]
        PUSH EAX
        MOV EAX,3
        SUB EAX,1
        SHL EAX,2
        POP EBX
        ADD EBX,EAX
        PUSH EBX
        MOV EAX,300
        POP EBX
        MOV [EBX],EAX
        LEA EAX,[_TPV_ARR]
        PUSH EAX
        MOV EAX,4
        SUB EAX,1
        SHL EAX,2
        POP EBX
        ADD EBX,EAX
        PUSH EBX
        MOV EAX,400
        POP EBX
        MOV [EBX],EAX
        LEA EAX,[_TPV_ARR]
        PUSH EAX
        MOV EAX,5
        SUB EAX,1
        SHL EAX,2
        POP EBX
        ADD EBX,EAX
        PUSH EBX
        MOV EAX,500
        POP EBX
        MOV [EBX],EAX
; writeln
        LEA EAX,[_TPK_3]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA EAX,[_TPV_ARR]
        PUSH EAX
        MOV EAX,1
        SUB EAX,1
        SHL EAX,2
        POP EBX
        ADD EBX,EAX
        MOV EAX,[EBX]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
; writeln
        LEA EAX,[_TPK_4]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA EAX,[_TPV_ARR]
        PUSH EAX
        MOV EAX,3
        SUB EAX,1
        SHL EAX,2
        POP EBX
        ADD EBX,EAX
        MOV EAX,[EBX]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
; writeln
        LEA EAX,[_TPK_5]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA EAX,[_TPV_ARR]
        PUSH EAX
        MOV EAX,5
        SUB EAX,1
        SHL EAX,2
        POP EBX
        ADD EBX,EAX
        MOV EAX,[EBX]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        LEA EAX,[_TPV_COLORS]
        PUSH EAX
        MOV EAX,1
        SUB EAX,1
        SHL EAX,2
        POP EBX
        ADD EBX,EAX
        PUSH EBX
        MOV EAX,11
        POP EBX
        MOV [EBX],EAX
        LEA EAX,[_TPV_COLORS]
        PUSH EAX
        MOV EAX,2
        SUB EAX,1
        SHL EAX,2
        POP EBX
        ADD EBX,EAX
        PUSH EBX
        MOV EAX,22
        POP EBX
        MOV [EBX],EAX
        LEA EAX,[_TPV_COLORS]
        PUSH EAX
        MOV EAX,3
        SUB EAX,1
        SHL EAX,2
        POP EBX
        ADD EBX,EAX
        PUSH EBX
        MOV EAX,33
        POP EBX
        MOV [EBX],EAX
; writeln
        LEA EAX,[_TPK_6]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA EAX,[_TPV_COLORS]
        PUSH EAX
        MOV EAX,2
        SUB EAX,1
        SHL EAX,2
        POP EBX
        ADD EBX,EAX
        MOV EAX,[EBX]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        LEA EAX,[_TPV_B]
        PUSH EAX
        MOV EAX,0
        POP EBX
        ADD EBX,EAX
        PUSH EBX
        MOV EAX,65
        POP EBX
        MOV BYTE PTR [EBX],AL
        LEA EAX,[_TPV_B]
        PUSH EAX
        MOV EAX,1
        POP EBX
        ADD EBX,EAX
        PUSH EBX
        MOV EAX,66
        POP EBX
        MOV BYTE PTR [EBX],AL
; writeln
        LEA EAX,[_TPK_7]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA EAX,[_TPV_B]
        PUSH EAX
        MOV EAX,0
        POP EBX
        ADD EBX,EAX
        MOVZX EAX,BYTE PTR [EBX]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
; for
        MOV EAX,1
        MOV DWORD PTR [_TPV_I],EAX
        MOV EAX,5
        MOV DWORD PTR [_TPL_2],EAX
_TPL_3:
        MOV EAX,DWORD PTR [_TPV_I]
        CMP EAX,DWORD PTR [_TPL_2]
        JG _TPL_4
        LEA EAX,[_TPV_ARR]
        PUSH EAX
        MOV EAX,DWORD PTR [_TPV_I]
        SUB EAX,1
        SHL EAX,2
        POP EBX
        ADD EBX,EAX
        PUSH EBX
        MOV EAX,DWORD PTR [_TPV_I]
        PUSH EAX
        MOV EAX,10
        MOV EBX,EAX
        POP EAX
        IMUL EAX,EBX
        POP EBX
        MOV [EBX],EAX
_TPL_5:
        MOV EAX,DWORD PTR [_TPV_I]
        INC EAX
        MOV DWORD PTR [_TPV_I],EAX
        JMP _TPL_3
_TPL_4:
; for
        MOV EAX,1
        MOV DWORD PTR [_TPV_I],EAX
        MOV EAX,5
        MOV DWORD PTR [_TPL_6],EAX
_TPL_7:
        MOV EAX,DWORD PTR [_TPV_I]
        CMP EAX,DWORD PTR [_TPL_6]
        JG _TPL_8
; writeln
        LEA EAX,[_TPK_8]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        MOV EAX,DWORD PTR [_TPV_I]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA EAX,[_TPK_9]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA EAX,[_TPV_ARR]
        PUSH EAX
        MOV EAX,DWORD PTR [_TPV_I]
        SUB EAX,1
        SHL EAX,2
        POP EBX
        ADD EBX,EAX
        MOV EAX,[EBX]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
_TPL_9:
        MOV EAX,DWORD PTR [_TPV_I]
        INC EAX
        MOV DWORD PTR [_TPV_I],EAX
        JMP _TPL_7
_TPL_8:
        LEA EAX,[_TPV_PT]
        PUSH EAX
        LEA EAX,[_TPV_PT]
        MOV EAX,[EAX]
        PUSH EAX
        MOV EAX,5
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        POP EBX
        MOV [EBX],EAX
; writeln
        LEA EAX,[_TPK_10]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA EAX,[_TPV_PT]
        MOV EAX,[EAX]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        MOV EAX,1
        AND EAX,0FFh
        MOV DWORD PTR [_TPV_I],EAX
; writeln
        LEA EAX,[_TPK_11]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        MOV EAX,DWORD PTR [_TPV_I]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
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
