; TPCW32 - Compilateur Turbo Pascal -> ASM 80386 Win32
; Genere automatiquement a partir de : SAMPLES/PASCAL/SimpleLabelTest.pas

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
EXTRN _PeekConsoleInputA@16:NEAR
EXTRN _ReadConsoleInputA@16:NEAR
EXTRN _GetNumberOfConsoleInputEvents@8:NEAR
EXTRN _Beep@8:NEAR
EXTRN _ScrollConsoleScreenBufferA@20:NEAR
EXTRN _FlushConsoleInputBuffer@4:NEAR

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
STRBUF1   DB 256 DUP(0)
STRBUF2   DB 256 DUP(0)
TRUE_STR  DB 'TRUE',0
FALSE_STR DB 'FALSE',0

; --- Variables CRT (emulation console) ---
TEXTATTR  DD 7
WINDMIN   DD 0
WINDMAX   DD 184Fh
LASTMODE  DD 3
DIRECTVIDEO DD 1
CHECKBREAK  DD 1
CHECKEOF    DD 0
CHECKSNOW   DD 0
CRT_CSBI  DB 22 DUP(0)
CRT_INREC DB 20 DUP(0)
CRT_NEVT  DD 0
CRT_NWRT  DD 0

; --- Constantes et donnees utilisateur ---
_TPK_1  DB 'Before label',0
_TPK_2  DB 'At label',0
_TPK_3  DB 'After label',0

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
; writeln
        LEA EAX,[_TPK_1]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
_TPL_MYLABEL:
; writeln
        LEA EAX,[_TPK_2]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
; writeln
        LEA EAX,[_TPK_3]
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

_TPRT_STRLEN:
        PUSH ESI
        XOR EAX,EAX
_TPRT_SLN_L:
        CMP BYTE PTR [ESI],0
        JE _TPRT_SLN_D
        INC EAX
        INC ESI
        JMP _TPRT_SLN_L
_TPRT_SLN_D:
        POP ESI
        RET

_TPRT_CONCAT:
        PUSHAD
_TPRT_CAT_F:
        CMP BYTE PTR [ESI],0
        JE _TPRT_CAT_C
        INC ESI
        JMP _TPRT_CAT_F
_TPRT_CAT_C:
_TPRT_CAT_L:
        MOV AL,BYTE PTR [EDI]
        MOV BYTE PTR [ESI],AL
        TEST AL,AL
        JZ _TPRT_CAT_D
        INC ESI
        INC EDI
        JMP _TPRT_CAT_L
_TPRT_CAT_D:
        POPAD
        RET

_TPRT_STRCMP:
        PUSH ESI
        PUSH EDI
_TPRT_CMP_L:
        MOVZX EAX,BYTE PTR [ESI]
        MOVZX ECX,BYTE PTR [EDI]
        SUB EAX,ECX
        JNZ _TPRT_CMP_D
        TEST ECX,ECX
        JZ _TPRT_CMP_D
        INC ESI
        INC EDI
        JMP _TPRT_CMP_L
_TPRT_CMP_D:
        POP EDI
        POP ESI
        RET

_TPRT_COPY:
        PUSHAD
        LEA EDI,[STRBUF1]
        DEC EBX
        TEST EBX,EBX
        JLE _TPRT_CPY_C
_TPRT_CPY_S:
        CMP BYTE PTR [ESI],0
        JE _TPRT_CPY_E
        INC ESI
        DEC EBX
        JNZ _TPRT_CPY_S
_TPRT_CPY_C:
        TEST ECX,ECX
        JLE _TPRT_CPY_E
_TPRT_CPY_L:
        CMP BYTE PTR [ESI],0
        JE _TPRT_CPY_E
        MOVSB
        DEC ECX
        JNZ _TPRT_CPY_L
_TPRT_CPY_E:
        MOV BYTE PTR [EDI],0
        POPAD
        LEA EAX,[STRBUF1]
        RET

_TPRT_POS:
        PUSH EBX
        PUSH ECX
        PUSH EDX
        PUSH ESI
        PUSH EDI
        XOR EAX,EAX
        XOR EBX,EBX
_TPRT_POS_O:
        CMP BYTE PTR [ESI+EBX],0
        JE _TPRT_POS_N
        XOR ECX,ECX
_TPRT_POS_M:
        MOVZX EDX,BYTE PTR [EDI+ECX]
        TEST DL,DL
        JZ _TPRT_POS_F
        CMP DL,BYTE PTR [ESI+EBX+ECX]
        JNE _TPRT_POS_X
        INC ECX
        JMP _TPRT_POS_M
_TPRT_POS_F:
        LEA EAX,[EBX+1]
        JMP _TPRT_POS_D
_TPRT_POS_X:
        INC EBX
        JMP _TPRT_POS_O
_TPRT_POS_N:
        XOR EAX,EAX
_TPRT_POS_D:
        POP EDI
        POP ESI
        POP EDX
        POP ECX
        POP EBX
        RET

_TPRT_DELETE:
        PUSHAD
        DEC EBX
        MOV EDI,ESI
        ADD EDI,EBX
        ADD ESI,EBX
        ADD ESI,ECX
_TPRT_DEL_L:
        LODSB
        STOSB
        TEST AL,AL
        JNZ _TPRT_DEL_L
        POPAD
        RET

_TPRT_INSERT:
        PUSHAD
        DEC EBX
        PUSH ESI
        PUSH EDI
        MOV ESI,EDI
        LEA EDI,[STRBUF2]
        CALL _TPRT_STRCPY
        POP EDI
        POP ESI
        PUSH ESI
        PUSH EBX
        LEA ESI,[STRBUF2]
        MOV ECX,EBX
        TEST ECX,ECX
        JZ _TPRT_INS_P2
_TPRT_INS_P1:
        MOVSB
        DEC ECX
        JNZ _TPRT_INS_P1
_TPRT_INS_P2:
        POP EBX
        POP ESI
_TPRT_INS_S1:
        CMP BYTE PTR [ESI],0
        JE _TPRT_INS_S2
        MOVSB
        JMP _TPRT_INS_S1
_TPRT_INS_S2:
        LEA ESI,[STRBUF2]
        ADD ESI,EBX
_TPRT_INS_R1:
        LODSB
        STOSB
        TEST AL,AL
        JNZ _TPRT_INS_R1
        POPAD
        RET

_TPRT_CLRSCR:
        PUSHAD
        PUSH OFFSET CRT_CSBI
        PUSH DWORD PTR [HSTDOUT]
        CALL GetConsoleScreenBufferInfo
        MOVZX EAX,WORD PTR [CRT_CSBI+0]
        MOVZX ECX,WORD PTR [CRT_CSBI+2]
        IMUL EAX,ECX
        PUSH OFFSET CRT_NWRT
        PUSH 0
        PUSH EAX
        PUSH 32
        PUSH DWORD PTR [HSTDOUT]
        CALL FillConsoleOutputCharacterA
        MOVZX EAX,WORD PTR [CRT_CSBI+0]
        MOVZX ECX,WORD PTR [CRT_CSBI+2]
        IMUL EAX,ECX
        PUSH OFFSET CRT_NWRT
        PUSH 0
        PUSH EAX
        PUSH DWORD PTR [TEXTATTR]
        PUSH DWORD PTR [HSTDOUT]
        CALL FillConsoleOutputAttribute
        PUSH 0
        PUSH DWORD PTR [HSTDOUT]
        CALL SetConsoleCursorPosition
        POPAD
        RET

_TPRT_CLREOL:
        PUSHAD
        PUSH OFFSET CRT_CSBI
        PUSH DWORD PTR [HSTDOUT]
        CALL GetConsoleScreenBufferInfo
        MOVZX EAX,WORD PTR [CRT_CSBI+0]
        MOVZX ECX,WORD PTR [CRT_CSBI+4]
        SUB EAX,ECX
        MOVZX EDX,WORD PTR [CRT_CSBI+6]
        SHL EDX,16
        OR EDX,ECX
        PUSH OFFSET CRT_NWRT
        PUSH EDX
        PUSH EAX
        PUSH 32
        PUSH DWORD PTR [HSTDOUT]
        CALL FillConsoleOutputCharacterA
        POPAD
        RET

_TPRT_GOTOXY:
        PUSH EBP
        MOV EBP,ESP
        PUSH EAX
        PUSH EDX
        MOV EAX,DWORD PTR [EBP+8]
        DEC EAX
        AND EAX,0FFFFh
        MOV EDX,DWORD PTR [EBP+12]
        DEC EDX
        SHL EDX,16
        OR EAX,EDX
        PUSH EAX
        PUSH DWORD PTR [HSTDOUT]
        CALL SetConsoleCursorPosition
        POP EDX
        POP EAX
        POP EBP
        RET

_TPRT_WHEREX:
        PUSH ECX
        PUSH OFFSET CRT_CSBI
        PUSH DWORD PTR [HSTDOUT]
        CALL GetConsoleScreenBufferInfo
        MOVZX EAX,WORD PTR [CRT_CSBI+4]
        INC EAX
        POP ECX
        RET

_TPRT_WHEREY:
        PUSH ECX
        PUSH OFFSET CRT_CSBI
        PUSH DWORD PTR [HSTDOUT]
        CALL GetConsoleScreenBufferInfo
        MOVZX EAX,WORD PTR [CRT_CSBI+6]
        INC EAX
        POP ECX
        RET

_TPRT_TEXTCOLOR:
        PUSH EBP
        MOV EBP,ESP
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+8]
        AND EAX,0Fh
        MOV EDX,DWORD PTR [TEXTATTR]
        AND EDX,0F0h
        OR EAX,EDX
        MOV DWORD PTR [TEXTATTR],EAX
        PUSH EAX
        PUSH DWORD PTR [HSTDOUT]
        CALL SetConsoleTextAttribute
        POP EAX
        POP EBP
        RET

_TPRT_TEXTBG:
        PUSH EBP
        MOV EBP,ESP
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+8]
        AND EAX,07h
        SHL EAX,4
        MOV EDX,DWORD PTR [TEXTATTR]
        AND EDX,0Fh
        OR EAX,EDX
        MOV DWORD PTR [TEXTATTR],EAX
        PUSH EAX
        PUSH DWORD PTR [HSTDOUT]
        CALL SetConsoleTextAttribute
        POP EAX
        POP EBP
        RET

_TPRT_HIGHVIDEO:
        PUSH EAX
        MOV EAX,DWORD PTR [TEXTATTR]
        OR EAX,08h
        MOV DWORD PTR [TEXTATTR],EAX
        PUSH EAX
        PUSH DWORD PTR [HSTDOUT]
        CALL SetConsoleTextAttribute
        POP EAX
        RET

_TPRT_LOWVIDEO:
        PUSH EAX
        MOV EAX,DWORD PTR [TEXTATTR]
        AND EAX,0F7h
        MOV DWORD PTR [TEXTATTR],EAX
        PUSH EAX
        PUSH DWORD PTR [HSTDOUT]
        CALL SetConsoleTextAttribute
        POP EAX
        RET

_TPRT_NORMVIDEO:
        PUSH EAX
        MOV EAX,7
        MOV DWORD PTR [TEXTATTR],EAX
        PUSH EAX
        PUSH DWORD PTR [HSTDOUT]
        CALL SetConsoleTextAttribute
        POP EAX
        RET

_TPRT_WINDOW:
        PUSH EBP
        MOV EBP,ESP
        PUSH EAX
        PUSH EDX
        MOV EAX,DWORD PTR [EBP+12]
        DEC EAX
        SHL EAX,8
        MOV EDX,DWORD PTR [EBP+8]
        DEC EDX
        OR EAX,EDX
        MOV DWORD PTR [WINDMIN],EAX
        MOV EAX,DWORD PTR [EBP+20]
        DEC EAX
        SHL EAX,8
        MOV EDX,DWORD PTR [EBP+16]
        DEC EDX
        OR EAX,EDX
        MOV DWORD PTR [WINDMAX],EAX
        POP EDX
        POP EAX
        POP EBP
        RET

_TPRT_KEYPRESSED:
        PUSH ECX
        PUSH EDX
        PUSH OFFSET CRT_NEVT
        PUSH DWORD PTR [HSTDIN]
        CALL GetNumberOfConsoleInputEvents
        MOV EAX,DWORD PTR [CRT_NEVT]
        TEST EAX,EAX
        JZ _TPRT_KP_NO
        PUSH OFFSET CRT_NEVT
        PUSH 1
        PUSH OFFSET CRT_INREC
        PUSH DWORD PTR [HSTDIN]
        CALL PeekConsoleInputA
        MOVZX EAX,WORD PTR [CRT_INREC]
        CMP EAX,1
        JNE _TPRT_KP_FL
        MOV EAX,DWORD PTR [CRT_INREC+4]
        TEST EAX,EAX
        JZ _TPRT_KP_FL
        MOV EAX,1
        JMP _TPRT_KP_DN
_TPRT_KP_FL:
        PUSH OFFSET CRT_NEVT
        PUSH 1
        PUSH OFFSET CRT_INREC
        PUSH DWORD PTR [HSTDIN]
        CALL ReadConsoleInputA
_TPRT_KP_NO:
        XOR EAX,EAX
_TPRT_KP_DN:
        POP EDX
        POP ECX
        RET

_TPRT_READKEY:
        PUSH ECX
        PUSH EDX
_TPRT_RK_LP:
        PUSH OFFSET CRT_NEVT
        PUSH 1
        PUSH OFFSET CRT_INREC
        PUSH DWORD PTR [HSTDIN]
        CALL ReadConsoleInputA
        MOVZX EAX,WORD PTR [CRT_INREC]
        CMP EAX,1
        JNE _TPRT_RK_LP
        MOV EAX,DWORD PTR [CRT_INREC+4]
        TEST EAX,EAX
        JZ _TPRT_RK_LP
        MOVZX EAX,BYTE PTR [CRT_INREC+14]
        POP EDX
        POP ECX
        RET

_TPRT_SOUND:
        PUSH EBP
        MOV EBP,ESP
        PUSH 200
        PUSH DWORD PTR [EBP+8]
        CALL Beep
        POP EBP
        RET
END _TPF_Main
