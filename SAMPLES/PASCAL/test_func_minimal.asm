; TPCW32 - Compilateur Turbo Pascal -> ASM 80386 Win32
; Genere automatiquement a partir de : SAMPLES/PASCAL/test_func_minimal.pas

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
; --- Imports Win32 pour unite DOS (TODO 19) ---
EXTRN _GetLocalTime@4:NEAR
EXTRN _SetLocalTime@4:NEAR
EXTRN _GetFileAttributesA@4:NEAR
EXTRN _SetFileAttributesA@8:NEAR
EXTRN _FindFirstFileA@8:NEAR
EXTRN _FindNextFileA@8:NEAR
EXTRN _FindClose@4:NEAR
EXTRN _GetDiskFreeSpaceA@20:NEAR
EXTRN _GetEnvironmentVariableA@12:NEAR
EXTRN _CreateProcessA@40:NEAR
EXTRN _WaitForSingleObject@8:NEAR
EXTRN _GetExitCodeProcess@8:NEAR
EXTRN _GetFullPathNameA@16:NEAR
; --- Imports Win32 pour unite Graph (TODO 20) ---
; --- user32.dll ---
EXTRN _RegisterClassA@4:NEAR
EXTRN _CreateWindowExA@48:NEAR
EXTRN _DestroyWindow@4:NEAR
EXTRN _ShowWindow@8:NEAR
EXTRN _UpdateWindow@4:NEAR
EXTRN _GetDC@4:NEAR
EXTRN _ReleaseDC@8:NEAR
EXTRN _DefWindowProcA@16:NEAR
EXTRN _GetClientRect@8:NEAR
EXTRN _InvalidateRect@12:NEAR
EXTRN _PeekMessageA@20:NEAR
EXTRN _DispatchMessageA@4:NEAR
EXTRN _TranslateMessage@4:NEAR
EXTRN _PostQuitMessage@4:NEAR
EXTRN _LoadCursorA@8:NEAR
EXTRN _GetModuleHandleA@4:NEAR
EXTRN _FillRect@12:NEAR
; --- gdi32.dll ---
EXTRN _SetPixel@16:NEAR
EXTRN _GetPixel@12:NEAR
EXTRN _MoveToEx@16:NEAR
EXTRN _LineTo@12:NEAR
EXTRN _Rectangle@20:NEAR
EXTRN _Ellipse@20:NEAR
EXTRN _Arc@36:NEAR
EXTRN _Pie@36:NEAR
EXTRN _CreatePen@12:NEAR
EXTRN _CreateSolidBrush@4:NEAR
EXTRN _SelectObject@8:NEAR
EXTRN _DeleteObject@4:NEAR
EXTRN _TextOutA@20:NEAR
EXTRN _CreateFontA@56:NEAR
EXTRN _SetBkMode@8:NEAR
EXTRN _SetTextColor@8:NEAR
EXTRN _SetBkColor@8:NEAR
EXTRN _GetTextExtentPoint32A@16:NEAR
EXTRN _CreateCompatibleDC@4:NEAR
EXTRN _CreateCompatibleBitmap@12:NEAR
EXTRN _BitBlt@36:NEAR
EXTRN _DeleteDC@4:NEAR
EXTRN _FloodFill@16:NEAR
EXTRN _GetStockObject@4:NEAR
; --- Imports Win32 pour unite Strings (TODO 21) ---
; --- kernel32.dll ---
EXTRN _lstrlenA@4:NEAR
EXTRN _lstrcpyA@8:NEAR
EXTRN _lstrcatA@8:NEAR
EXTRN _lstrcmpA@8:NEAR
EXTRN _lstrcmpiA@8:NEAR

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

; --- Variables DOS (emulation unite DOS) ---
DOSERROR  DD 0
DOSEXITCODE DD 0
DOS_SYSTIME DB 16 DUP(0)
DOS_FATTR DD 0
DOS_ENVBUF DB 256 DUP(0)
DOS_PATHBUF DB 260 DUP(0)
DOS_DKFREE DD 4 DUP(0)
DOS_FINDDATA DB 320 DUP(0)
DOS_FINDHDL DD -1
DOS_PROCINFO DB 16 DUP(0)
DOS_STARTINFO DB 68 DUP(0)
DOS_EXITVAL DD 0

; --- Variables Graph (emulation graphique Windows) ---
GR_RESULT   DD 0
GR_DRIVER   DD 0
GR_MODE     DD 0
GR_HWND     DD 0
GR_HDC      DD 0
GR_HPEN     DD 0
GR_HBRUSH   DD 0
GR_HFONT    DD 0
GR_HINST    DD 0
GR_MAXX     DD 639
GR_MAXY     DD 479
GR_COLOR    DD 15
GR_BKCOLOR  DD 0
GR_FILLCOLOR DD 0
GR_FILLSTYLE DD 1
GR_LINESTYLE DD 0
GR_LINEWIDTH DD 1
GR_WRITEMODE DD 0
GR_CPX      DD 0
GR_CPY      DD 0
GR_VPXL     DD 0
GR_VPYT     DD 0
GR_VPXR     DD 639
GR_VPYB     DD 479
GR_VPCLIP   DD 1
GR_TXFONT   DD 0
GR_TXDIR    DD 0
GR_TXSIZE   DD 1
GR_ACTIVE   DD 0
GR_MAXCOLOR DD 15
GR_WNDCLASS DB 'TPGraphWnd',0
GR_WNDTITLE DB 'Turbo Pascal Graphics',0
GR_CLSREC   DB 40 DUP(0)
GR_RECT     DD 4 DUP(0)
GR_MSG      DB 28 DUP(0)
GR_TXBUF    DB 256 DUP(0)
GR_TXSIZE2  DD 2 DUP(0)
GR_PALETTE  DD 000000h
            DD 0AA0000h
            DD 000AA00h
            DD 0AAAA00h
            DD 00000AAh
            DD 0AA00AAh
            DD 00055AAh
            DD 0AAAAAAh
            DD 0555555h
            DD 0FF5555h
            DD 055FF55h
            DD 0FFFF55h
            DD 05555FFh
            DD 0FF55FFh
            DD 055FFFFh
            DD 0FFFFFFh
GR_ERRMSG0  DB 'No error',0
GR_ERRMSG1  DB '(BGI) graphics not installed',0
GR_ERRMSG2  DB 'Graphics hardware not detected',0
GR_DRVNAME  DB 'EGAVGA',0
GR_MODNAME  DB '640x480x16',0

; --- Variables Strings (unite Strings emulation) ---
STR_TMPBUF  DB 256 DUP(0)
STR_PASBUF  DB 256 DUP(0)
; --- Variables Printer (unite Printer emulation) ---
PRN_HANDLE  DD -1
PRN_FNAME   DB 'NUL',0
; --- Variables Overlay (stubs) ---
OVR_RESULT  DD 0
OVR_BUFSIZE DD 0

; --- Constantes et donnees utilisateur ---
_TPK_1  DB 'x = ',0
_TPV_X  DD 0

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
        MOV EAX,10
        MOV DWORD PTR [_TPV_X],EAX
; writeln
        LEA EAX,[_TPK_1]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        MOV EAX,DWORD PTR [_TPV_X]
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

_TPRT_DOSVERSION:
        MOV EAX,7
        RET

_TPRT_DISKFREE:
        PUSH EBP
        MOV EBP,ESP
        PUSHAD
        MOV EAX,DWORD PTR [EBP+8]
        TEST EAX,EAX
        JZ _TPRT_DF_CUR
        ADD AL,64
        MOV BYTE PTR [DOS_PATHBUF],AL
        MOV BYTE PTR [DOS_PATHBUF+1],':'
        MOV BYTE PTR [DOS_PATHBUF+2],'\'
        MOV BYTE PTR [DOS_PATHBUF+3],0
        PUSH OFFSET DOS_PATHBUF
        JMP _TPRT_DF_GO
_TPRT_DF_CUR:
        PUSH 0
_TPRT_DF_GO:
        PUSH OFFSET DOS_DKFREE+12
        PUSH OFFSET DOS_DKFREE+8
        PUSH OFFSET DOS_DKFREE+4
        PUSH OFFSET DOS_DKFREE+0
        CALL GetDiskFreeSpaceA
        MOV EAX,DWORD PTR [DOS_DKFREE+8]
        IMUL EAX,DWORD PTR [DOS_DKFREE+0]
        IMUL EAX,DWORD PTR [DOS_DKFREE+4]
        MOV DWORD PTR [EBP-4],EAX
        POPAD
        MOV EAX,DWORD PTR [EBP-4]
        POP EBP
        RET

_TPRT_DISKSIZE:
        PUSH EBP
        MOV EBP,ESP
        PUSHAD
        MOV EAX,DWORD PTR [EBP+8]
        TEST EAX,EAX
        JZ _TPRT_DS_CUR
        ADD AL,64
        MOV BYTE PTR [DOS_PATHBUF],AL
        MOV BYTE PTR [DOS_PATHBUF+1],':'
        MOV BYTE PTR [DOS_PATHBUF+2],'\'
        MOV BYTE PTR [DOS_PATHBUF+3],0
        PUSH OFFSET DOS_PATHBUF
        JMP _TPRT_DS_GO
_TPRT_DS_CUR:
        PUSH 0
_TPRT_DS_GO:
        PUSH OFFSET DOS_DKFREE+12
        PUSH OFFSET DOS_DKFREE+8
        PUSH OFFSET DOS_DKFREE+4
        PUSH OFFSET DOS_DKFREE+0
        CALL GetDiskFreeSpaceA
        MOV EAX,DWORD PTR [DOS_DKFREE+12]
        IMUL EAX,DWORD PTR [DOS_DKFREE+0]
        IMUL EAX,DWORD PTR [DOS_DKFREE+4]
        MOV DWORD PTR [EBP-4],EAX
        POPAD
        MOV EAX,DWORD PTR [EBP-4]
        POP EBP
        RET

_TPRT_GETENV:
        PUSH EBP
        MOV EBP,ESP
        PUSH ECX
        PUSH EDX
        MOV EAX,DWORD PTR [EBP+8]
        INC EAX
        PUSH 255
        PUSH OFFSET DOS_ENVBUF
        PUSH EAX
        CALL GetEnvironmentVariableA
        MOV BYTE PTR [STRBUF],AL
        TEST EAX,EAX
        JZ _TPRT_GE_DN
        MOV ECX,EAX
        PUSH ESI
        PUSH EDI
        LEA ESI,[DOS_ENVBUF]
        LEA EDI,[STRBUF+1]
        REP MOVSB
        POP EDI
        POP ESI
_TPRT_GE_DN:
        LEA EAX,[STRBUF]
        POP EDX
        POP ECX
        POP EBP
        RET

_TPRT_FEXPAND:
        PUSH EBP
        MOV EBP,ESP
        PUSH ECX
        PUSH EDX
        MOV EAX,DWORD PTR [EBP+8]
        INC EAX
        PUSH 0
        PUSH OFFSET DOS_PATHBUF
        PUSH 259
        PUSH EAX
        CALL GetFullPathNameA
        MOV BYTE PTR [STRBUF2],AL
        TEST EAX,EAX
        JZ _TPRT_FE_DN
        MOV ECX,EAX
        PUSH ESI
        PUSH EDI
        LEA ESI,[DOS_PATHBUF]
        LEA EDI,[STRBUF2+1]
        REP MOVSB
        POP EDI
        POP ESI
_TPRT_FE_DN:
        LEA EAX,[STRBUF2]
        POP EDX
        POP ECX
        POP EBP
        RET

_TPRT_FSEARCH:
        PUSH EBP
        MOV EBP,ESP
        PUSH ECX
        MOV EAX,DWORD PTR [EBP+8]
        INC EAX
        PUSH EAX
        CALL GetFileAttributesA
        CMP EAX,-1
        JE _TPRT_FS_NF
        MOV EAX,DWORD PTR [EBP+8]
        JMP _TPRT_FS_DN
_TPRT_FS_NF:
        MOV BYTE PTR [STRBUF],0
        LEA EAX,[STRBUF]
_TPRT_FS_DN:
        POP ECX
        POP EBP
        RET

_TPRT_FSPLIT:
        PUSH EBP
        MOV EBP,ESP
        PUSHAD
        MOV ESI,DWORD PTR [EBP+8]
        MOV EDI,DWORD PTR [EBP+12]
        MOVZX ECX,BYTE PTR [ESI]
        MOV BYTE PTR [EDI],CL
        INC ESI
        INC EDI
        REP MOVSB
        MOV EDI,DWORD PTR [EBP+16]
        MOV BYTE PTR [EDI],0
        MOV EDI,DWORD PTR [EBP+20]
        MOV BYTE PTR [EDI],0
        POPAD
        POP EBP
        RET

_TPRT_FINDFIRST:
        PUSH EBP
        MOV EBP,ESP
        PUSHAD
        MOV EAX,DWORD PTR [EBP+8]
        INC EAX
        PUSH OFFSET DOS_FINDDATA
        PUSH EAX
        CALL FindFirstFileA
        MOV DWORD PTR [DOS_FINDHDL],EAX
        CMP EAX,-1
        JE _TPRT_FF_NF
        MOV EDI,DWORD PTR [EBP+16]
        MOV EAX,DWORD PTR [DOS_FINDDATA]
        MOV WORD PTR [EDI],AX
        MOV DWORD PTR [EDI+4],0
        MOV EAX,DWORD PTR [DOS_FINDDATA+32]
        MOV DWORD PTR [EDI+8],EAX
        LEA ESI,[DOS_FINDDATA+44]
        LEA EDI,[EDI+12]
        PUSH EDI
        INC EDI
        XOR ECX,ECX
_TPRT_FF_CP:
        LODSB
        TEST AL,AL
        JZ _TPRT_FF_CE
        STOSB
        INC ECX
        CMP ECX,79
        JB _TPRT_FF_CP
_TPRT_FF_CE:
        POP EDI
        MOV BYTE PTR [EDI],CL
        MOV DWORD PTR [DOSERROR],0
        JMP _TPRT_FF_DN
_TPRT_FF_NF:
        MOV DWORD PTR [DOSERROR],18
_TPRT_FF_DN:
        POPAD
        POP EBP
        RET

_TPRT_FINDNEXT:
        PUSH EBP
        MOV EBP,ESP
        PUSHAD
        PUSH OFFSET DOS_FINDDATA
        PUSH DWORD PTR [DOS_FINDHDL]
        CALL FindNextFileA
        TEST EAX,EAX
        JZ _TPRT_FN_NF
        MOV EDI,DWORD PTR [EBP+8]
        MOV EAX,DWORD PTR [DOS_FINDDATA]
        MOV WORD PTR [EDI],AX
        MOV DWORD PTR [EDI+4],0
        MOV EAX,DWORD PTR [DOS_FINDDATA+32]
        MOV DWORD PTR [EDI+8],EAX
        LEA ESI,[DOS_FINDDATA+44]
        LEA EDI,[EDI+12]
        PUSH EDI
        INC EDI
        XOR ECX,ECX
_TPRT_FN_CP:
        LODSB
        TEST AL,AL
        JZ _TPRT_FN_CE
        STOSB
        INC ECX
        CMP ECX,79
        JB _TPRT_FN_CP
_TPRT_FN_CE:
        POP EDI
        MOV BYTE PTR [EDI],CL
        MOV DWORD PTR [DOSERROR],0
        JMP _TPRT_FN_DN
_TPRT_FN_NF:
        MOV DWORD PTR [DOSERROR],18
        PUSH DWORD PTR [DOS_FINDHDL]
        CALL FindClose
        MOV DWORD PTR [DOS_FINDHDL],-1
_TPRT_FN_DN:
        POPAD
        POP EBP
        RET

_TPRT_EXEC:
        PUSH EBP
        MOV EBP,ESP
        PUSHAD
        LEA EDI,[DOS_STARTINFO]
        MOV ECX,68
        XOR AL,AL
        REP STOSB
        MOV DWORD PTR [DOS_STARTINFO],68
        PUSH OFFSET DOS_PROCINFO
        PUSH OFFSET DOS_STARTINFO
        PUSH 0
        PUSH 0
        PUSH 0
        PUSH 0
        PUSH 0
        PUSH 0
        MOV EAX,DWORD PTR [EBP+12]
        INC EAX
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+8]
        INC EAX
        PUSH EAX
        CALL CreateProcessA
        TEST EAX,EAX
        JZ _TPRT_EX_ER
        PUSH -1
        PUSH DWORD PTR [DOS_PROCINFO]
        CALL WaitForSingleObject
        PUSH OFFSET DOS_EXITVAL
        PUSH DWORD PTR [DOS_PROCINFO]
        CALL GetExitCodeProcess
        MOV EAX,DWORD PTR [DOS_EXITVAL]
        MOV DWORD PTR [DOSEXITCODE],EAX
        PUSH DWORD PTR [DOS_PROCINFO+4]
        CALL CloseHandle
        PUSH DWORD PTR [DOS_PROCINFO]
        CALL CloseHandle
        MOV DWORD PTR [DOSERROR],0
        JMP _TPRT_EX_DN
_TPRT_EX_ER:
        MOV DWORD PTR [DOSERROR],2
_TPRT_EX_DN:
        POPAD
        POP EBP
        RET

_TPRT_MSDOS:
        PUSH EBP
        MOV EBP,ESP
        PUSH EBX
        MOV EBX,DWORD PTR [EBP+8]
        MOVZX EAX,BYTE PTR [EBX+1]
        CMP AL,4Ch
        JNE _TPRT_MS_N4C
        MOVZX EAX,BYTE PTR [EBX]
        PUSH EAX
        CALL ExitProcess
_TPRT_MS_N4C:
        CMP AL,30h
        JNE _TPRT_MS_N30
        MOV BYTE PTR [EBX],7
        MOV BYTE PTR [EBX+1],0
        JMP _TPRT_MS_DN
_TPRT_MS_N30:
        CMP AL,2Ah
        JNE _TPRT_MS_N2A
        PUSH OFFSET DOS_SYSTIME
        CALL GetLocalTime
        MOVZX EAX,WORD PTR [DOS_SYSTIME+0]
        MOV WORD PTR [EBX+4],AX
        MOV AL,BYTE PTR [DOS_SYSTIME+2]
        MOV BYTE PTR [EBX+7],AL
        MOV AL,BYTE PTR [DOS_SYSTIME+6]
        MOV BYTE PTR [EBX+6],AL
        MOV AL,BYTE PTR [DOS_SYSTIME+4]
        MOV BYTE PTR [EBX],AL
        JMP _TPRT_MS_DN
_TPRT_MS_N2A:
        CMP AL,2Ch
        JNE _TPRT_MS_N2C
        PUSH OFFSET DOS_SYSTIME
        CALL GetLocalTime
        MOV AL,BYTE PTR [DOS_SYSTIME+8]
        MOV BYTE PTR [EBX+5],AL
        MOV AL,BYTE PTR [DOS_SYSTIME+10]
        MOV BYTE PTR [EBX+4],AL
        MOV AL,BYTE PTR [DOS_SYSTIME+12]
        MOV BYTE PTR [EBX+7],AL
        MOV AL,BYTE PTR [DOS_SYSTIME+14]
        XOR AH,AH
        MOV CL,10
        DIV CL
        MOV BYTE PTR [EBX+6],AL
        JMP _TPRT_MS_DN
_TPRT_MS_N2C:
        CMP AL,02h
        JNE _TPRT_MS_N02
        MOV AL,BYTE PTR [EBX+6]
        MOV BYTE PTR [NUMBUF],AL
        PUSH OFFSET BYTESWR
        PUSH 0
        PUSH 1
        PUSH OFFSET NUMBUF
        PUSH DWORD PTR [HSTDOUT]
        CALL WriteFile
        JMP _TPRT_MS_DN
_TPRT_MS_N02:
_TPRT_MS_DN:
        POP EBX
        POP EBP
        RET

; ============================================================
;  RUNTIME GRAPH : routines d emulation graphique Windows     
; ============================================================

_TPRT_INITGRAPH:
        PUSH EBP
        MOV EBP,ESP
        PUSHAD
        PUSH 0
        CALL GetModuleHandleA
        MOV DWORD PTR [GR_HINST],EAX
        PUSH 32512
        PUSH 0
        CALL LoadCursorA
        MOV ECX,EAX
        LEA EDI,[GR_CLSREC]
        XOR EAX,EAX
        MOV ECX,10
        REP STOSD
        MOV DWORD PTR [GR_CLSREC+0],3
        MOV DWORD PTR [GR_CLSREC+4],OFFSET DefWindowProcA
        MOV EAX,DWORD PTR [GR_HINST]
        MOV DWORD PTR [GR_CLSREC+20],EAX
        MOV DWORD PTR [GR_CLSREC+32],6
        MOV DWORD PTR [GR_CLSREC+36],OFFSET GR_WNDCLASS
        PUSH OFFSET GR_CLSREC
        CALL RegisterClassA
        PUSH 0
        PUSH DWORD PTR [GR_HINST]
        PUSH 0
        PUSH 0
        PUSH 520
        PUSH 660
        PUSH 100
        PUSH 100
        PUSH 00CF0000h
        PUSH OFFSET GR_WNDTITLE
        PUSH OFFSET GR_WNDCLASS
        PUSH 0
        CALL CreateWindowExA
        MOV DWORD PTR [GR_HWND],EAX
        PUSH 5
        PUSH EAX
        CALL ShowWindow
        PUSH DWORD PTR [GR_HWND]
        CALL UpdateWindow
        PUSH DWORD PTR [GR_HWND]
        CALL GetDC
        MOV DWORD PTR [GR_HDC],EAX
        MOV DWORD PTR [GR_ACTIVE],1
        PUSH DWORD PTR [GR_PALETTE+60]
        PUSH 1
        PUSH 0
        CALL CreatePen
        MOV DWORD PTR [GR_HPEN],EAX
        PUSH EAX
        PUSH DWORD PTR [GR_HDC]
        CALL SelectObject
        PUSH 0
        CALL CreateSolidBrush
        MOV DWORD PTR [GR_HBRUSH],EAX
        PUSH 1
        PUSH DWORD PTR [GR_HDC]
        CALL SetBkMode
        MOV EDX,DWORD PTR [EBP+8]
        MOV DWORD PTR [EDX],9
        MOV EDX,DWORD PTR [EBP+12]
        MOV DWORD PTR [EDX],2
        MOV DWORD PTR [GR_RESULT],0
        MOV DWORD PTR [GR_DRIVER],9
        MOV DWORD PTR [GR_MODE],2
        POPAD
        POP EBP
        RET

_TPRT_CLOSEGRAPH:
        PUSH EBP
        MOV EBP,ESP
        CMP DWORD PTR [GR_HPEN],0
        JZ _TPRT_CG_NP
        PUSH DWORD PTR [GR_HPEN]
        CALL DeleteObject
_TPRT_CG_NP:
        CMP DWORD PTR [GR_HBRUSH],0
        JZ _TPRT_CG_NB
        PUSH DWORD PTR [GR_HBRUSH]
        CALL DeleteObject
_TPRT_CG_NB:
        CMP DWORD PTR [GR_HFONT],0
        JZ _TPRT_CG_NF
        PUSH DWORD PTR [GR_HFONT]
        CALL DeleteObject
_TPRT_CG_NF:
        PUSH DWORD PTR [GR_HDC]
        PUSH DWORD PTR [GR_HWND]
        CALL ReleaseDC
        PUSH DWORD PTR [GR_HWND]
        CALL DestroyWindow
        MOV DWORD PTR [GR_ACTIVE],0
        MOV DWORD PTR [GR_HWND],0
        MOV DWORD PTR [GR_HDC],0
        POP EBP
        RET

_TPRT_PUTPIXEL:
        PUSH EBP
        MOV EBP,ESP
        MOV EAX,DWORD PTR [EBP+16]
        AND EAX,0Fh
        MOV EAX,DWORD PTR [GR_PALETTE+EAX*4]
        PUSH EAX
        PUSH DWORD PTR [EBP+12]
        PUSH DWORD PTR [EBP+8]
        PUSH DWORD PTR [GR_HDC]
        CALL SetPixel
        POP EBP
        RET

_TPRT_GETPIXEL:
        PUSH EBP
        MOV EBP,ESP
        PUSH DWORD PTR [EBP+16]
        PUSH DWORD PTR [EBP+12]
        PUSH DWORD PTR [GR_HDC]
        CALL GetPixel
        POP EBP
        RET

_TPRT_LINE:
        PUSH EBP
        MOV EBP,ESP
        PUSH 0
        PUSH DWORD PTR [EBP+12]
        PUSH DWORD PTR [EBP+8]
        PUSH DWORD PTR [GR_HDC]
        CALL MoveToEx
        PUSH DWORD PTR [EBP+20]
        PUSH DWORD PTR [EBP+16]
        PUSH DWORD PTR [GR_HDC]
        CALL LineTo
        MOV EAX,DWORD PTR [EBP+16]
        MOV DWORD PTR [GR_CPX],EAX
        MOV EAX,DWORD PTR [EBP+20]
        MOV DWORD PTR [GR_CPY],EAX
        POP EBP
        RET

_TPRT_LINETO:
        PUSH EBP
        MOV EBP,ESP
        PUSH 0
        PUSH DWORD PTR [GR_CPY]
        PUSH DWORD PTR [GR_CPX]
        PUSH DWORD PTR [GR_HDC]
        CALL MoveToEx
        PUSH DWORD PTR [EBP+12]
        PUSH DWORD PTR [EBP+8]
        PUSH DWORD PTR [GR_HDC]
        CALL LineTo
        MOV EAX,DWORD PTR [EBP+8]
        MOV DWORD PTR [GR_CPX],EAX
        MOV EAX,DWORD PTR [EBP+12]
        MOV DWORD PTR [GR_CPY],EAX
        POP EBP
        RET

_TPRT_LINEREL:
        PUSH EBP
        MOV EBP,ESP
        PUSH 0
        PUSH DWORD PTR [GR_CPY]
        PUSH DWORD PTR [GR_CPX]
        PUSH DWORD PTR [GR_HDC]
        CALL MoveToEx
        MOV EAX,DWORD PTR [GR_CPX]
        ADD EAX,DWORD PTR [EBP+8]
        MOV DWORD PTR [GR_CPX],EAX
        PUSH EAX
        MOV EAX,DWORD PTR [GR_CPY]
        ADD EAX,DWORD PTR [EBP+12]
        MOV DWORD PTR [GR_CPY],EAX
        PUSH EAX
        POP EDX
        POP ECX
        PUSH EDX
        PUSH ECX
        PUSH DWORD PTR [GR_HDC]
        CALL LineTo
        POP EBP
        RET

_TPRT_RECTANGLE:
        PUSH EBP
        MOV EBP,ESP
        PUSH 5
        CALL GetStockObject
        PUSH EAX
        PUSH DWORD PTR [GR_HDC]
        CALL SelectObject
        PUSH EAX
        PUSH DWORD PTR [EBP+20]
        PUSH DWORD PTR [EBP+16]
        PUSH DWORD PTR [EBP+12]
        PUSH DWORD PTR [EBP+8]
        PUSH DWORD PTR [GR_HDC]
        CALL Rectangle
        POP EAX
        PUSH EAX
        PUSH DWORD PTR [GR_HDC]
        CALL SelectObject
        POP EBP
        RET

_TPRT_BAR:
        PUSH EBP
        MOV EBP,ESP
        MOV EAX,DWORD PTR [GR_FILLCOLOR]
        AND EAX,0Fh
        MOV EAX,DWORD PTR [GR_PALETTE+EAX*4]
        PUSH EAX
        CALL CreateSolidBrush
        PUSH EAX
        PUSH EAX
        PUSH DWORD PTR [GR_HDC]
        CALL SelectObject
        PUSH EAX
        PUSH DWORD PTR [EBP+20]
        PUSH DWORD PTR [EBP+16]
        PUSH DWORD PTR [EBP+12]
        PUSH DWORD PTR [EBP+8]
        PUSH DWORD PTR [GR_HDC]
        CALL Rectangle
        POP EAX
        PUSH EAX
        PUSH DWORD PTR [GR_HDC]
        CALL SelectObject
        POP EAX
        PUSH EAX
        CALL DeleteObject
        POP EBP
        RET

_TPRT_BAR3D:
        PUSH EBP
        MOV EBP,ESP
        PUSHAD
        PUSH DWORD PTR [EBP+20]
        PUSH DWORD PTR [EBP+16]
        PUSH DWORD PTR [EBP+12]
        PUSH DWORD PTR [EBP+8]
        CALL _TPRT_BAR
        ADD ESP,16
        PUSH DWORD PTR [EBP+20]
        PUSH DWORD PTR [EBP+16]
        PUSH DWORD PTR [EBP+12]
        PUSH DWORD PTR [EBP+8]
        CALL _TPRT_RECTANGLE
        ADD ESP,16
; Bar3D top and side simplified (depth lines)
        POPAD
        POP EBP
        RET

_TPRT_CIRCLE:
        PUSH EBP
        MOV EBP,ESP
        PUSH 5
        CALL GetStockObject
        PUSH EAX
        PUSH DWORD PTR [GR_HDC]
        CALL SelectObject
        PUSH EAX
        MOV ECX,DWORD PTR [EBP+8]
        MOV EDX,DWORD PTR [EBP+12]
        MOV EBX,DWORD PTR [EBP+16]
        MOV EAX,EDX
        ADD EAX,EBX
        PUSH EAX
        MOV EAX,ECX
        ADD EAX,EBX
        PUSH EAX
        MOV EAX,EDX
        SUB EAX,EBX
        PUSH EAX
        MOV EAX,ECX
        SUB EAX,EBX
        PUSH EAX
        PUSH DWORD PTR [GR_HDC]
        CALL Ellipse
        POP EAX
        PUSH EAX
        PUSH DWORD PTR [GR_HDC]
        CALL SelectObject
        POP EBP
        RET

_TPRT_ARC:
        PUSH EBP
        MOV EBP,ESP
; Arc simplifie -> cercle (stub angles)
        PUSH DWORD PTR [EBP+24]
        PUSH DWORD PTR [EBP+12]
        PUSH DWORD PTR [EBP+8]
        CALL _TPRT_CIRCLE
        ADD ESP,12
        POP EBP
        RET

_TPRT_ELLIPSE:
        PUSH EBP
        MOV EBP,ESP
        PUSH 5
        CALL GetStockObject
        PUSH EAX
        PUSH DWORD PTR [GR_HDC]
        CALL SelectObject
        PUSH EAX
        MOV ECX,DWORD PTR [EBP+8]
        MOV EDX,DWORD PTR [EBP+12]
        MOV EBX,DWORD PTR [EBP+24]
        MOV ESI,DWORD PTR [EBP+28]
        MOV EAX,EDX
        ADD EAX,ESI
        PUSH EAX
        MOV EAX,ECX
        ADD EAX,EBX
        PUSH EAX
        MOV EAX,EDX
        SUB EAX,ESI
        PUSH EAX
        MOV EAX,ECX
        SUB EAX,EBX
        PUSH EAX
        PUSH DWORD PTR [GR_HDC]
        CALL Ellipse
        POP EAX
        PUSH EAX
        PUSH DWORD PTR [GR_HDC]
        CALL SelectObject
        POP EBP
        RET

_TPRT_FILLELLIPSE:
        PUSH EBP
        MOV EBP,ESP
        MOV EAX,DWORD PTR [GR_FILLCOLOR]
        AND EAX,0Fh
        MOV EAX,DWORD PTR [GR_PALETTE+EAX*4]
        PUSH EAX
        CALL CreateSolidBrush
        PUSH EAX
        PUSH EAX
        PUSH DWORD PTR [GR_HDC]
        CALL SelectObject
        PUSH EAX
        MOV ECX,DWORD PTR [EBP+8]
        MOV EDX,DWORD PTR [EBP+12]
        MOV EBX,DWORD PTR [EBP+16]
        MOV ESI,DWORD PTR [EBP+20]
        MOV EAX,EDX
        ADD EAX,ESI
        PUSH EAX
        MOV EAX,ECX
        ADD EAX,EBX
        PUSH EAX
        MOV EAX,EDX
        SUB EAX,ESI
        PUSH EAX
        MOV EAX,ECX
        SUB EAX,EBX
        PUSH EAX
        PUSH DWORD PTR [GR_HDC]
        CALL Ellipse
        POP EAX
        PUSH EAX
        PUSH DWORD PTR [GR_HDC]
        CALL SelectObject
        POP EAX
        PUSH EAX
        CALL DeleteObject
        POP EBP
        RET

_TPRT_PIESLICE:
        PUSH EBP
        MOV EBP,ESP
; PieSlice simplifie -> cercle rempli (stub)
        PUSH DWORD PTR [EBP+24]
        PUSH DWORD PTR [EBP+12]
        PUSH DWORD PTR [EBP+8]
        CALL _TPRT_CIRCLE
        ADD ESP,12
        POP EBP
        RET

_TPRT_SECTOR:
        PUSH EBP
        MOV EBP,ESP
; Sector simplifie -> ellipse remplie (stub)
        PUSH DWORD PTR [EBP+28]
        PUSH DWORD PTR [EBP+24]
        PUSH DWORD PTR [EBP+12]
        PUSH DWORD PTR [EBP+8]
        CALL _TPRT_FILLELLIPSE
        ADD ESP,16
        POP EBP
        RET

_TPRT_FLOODFILL:
        PUSH EBP
        MOV EBP,ESP
        MOV EAX,DWORD PTR [EBP+16]
        AND EAX,0Fh
        MOV EAX,DWORD PTR [GR_PALETTE+EAX*4]
        PUSH EAX
        PUSH DWORD PTR [EBP+12]
        PUSH DWORD PTR [EBP+8]
        PUSH DWORD PTR [GR_HDC]
        CALL FloodFill
        POP EBP
        RET

_TPRT_SETCOLOR:
        PUSH EBP
        MOV EBP,ESP
        MOV EAX,DWORD PTR [EBP+8]
        MOV DWORD PTR [GR_COLOR],EAX
        CALL _TPRT_UPDATEPEN
        POP EBP
        RET

_TPRT_UPDATEPEN:
        PUSHAD
        CMP DWORD PTR [GR_HPEN],0
        JZ _TPRT_UP_SK
        PUSH DWORD PTR [GR_HPEN]
        CALL DeleteObject
_TPRT_UP_SK:
        MOV EAX,DWORD PTR [GR_COLOR]
        AND EAX,0Fh
        MOV EAX,DWORD PTR [GR_PALETTE+EAX*4]
        PUSH EAX
        PUSH DWORD PTR [GR_LINEWIDTH]
        PUSH DWORD PTR [GR_LINESTYLE]
        CALL CreatePen
        MOV DWORD PTR [GR_HPEN],EAX
        PUSH EAX
        PUSH DWORD PTR [GR_HDC]
        CALL SelectObject
        MOV EAX,DWORD PTR [GR_COLOR]
        AND EAX,0Fh
        MOV EAX,DWORD PTR [GR_PALETTE+EAX*4]
        PUSH EAX
        PUSH DWORD PTR [GR_HDC]
        CALL SetTextColor
        POPAD
        RET

_TPRT_UPDATEFONT:
        PUSHAD
        CMP DWORD PTR [GR_HFONT],0
        JZ _TPRT_UF_SK
        PUSH DWORD PTR [GR_HFONT]
        CALL DeleteObject
_TPRT_UF_SK:
        MOV EAX,DWORD PTR [GR_TXSIZE]
        SHL EAX,3
        TEST EAX,EAX
        JNZ _TPRT_UF_NZ
        MOV EAX,8
_TPRT_UF_NZ:
; CreateFontA - stub simplifie
        MOV DWORD PTR [GR_HFONT],0
        POPAD
        RET

_TPRT_OUTTEXTXY:
        PUSH EBP
        MOV EBP,ESP
        PUSHAD
        MOV ESI,DWORD PTR [EBP+16]
        XOR ECX,ECX
        MOV CL,BYTE PTR [ESI]
        INC ESI
        PUSH ECX
        PUSH ESI
        PUSH DWORD PTR [EBP+12]
        PUSH DWORD PTR [EBP+8]
        PUSH DWORD PTR [GR_HDC]
        CALL TextOutA
        POPAD
        POP EBP
        RET

_TPRT_CLEARDEVICE:
        PUSHAD
        MOV EAX,DWORD PTR [GR_BKCOLOR]
        AND EAX,0Fh
        MOV EAX,DWORD PTR [GR_PALETTE+EAX*4]
        PUSH EAX
        CALL CreateSolidBrush
        MOV EBX,EAX
        MOV DWORD PTR [GR_RECT+0],0
        MOV DWORD PTR [GR_RECT+4],0
        MOV EAX,DWORD PTR [GR_MAXX]
        INC EAX
        MOV DWORD PTR [GR_RECT+8],EAX
        MOV EAX,DWORD PTR [GR_MAXY]
        INC EAX
        MOV DWORD PTR [GR_RECT+12],EAX
        PUSH EBX
        PUSH OFFSET GR_RECT
        PUSH DWORD PTR [GR_HDC]
        CALL FillRect
        PUSH EBX
        CALL DeleteObject
        MOV DWORD PTR [GR_CPX],0
        MOV DWORD PTR [GR_CPY],0
        POPAD
        RET

_TPRT_GRAPHERRORMSG:
        PUSH EBP
        MOV EBP,ESP
        MOV EAX,DWORD PTR [EBP+8]
        TEST EAX,EAX
        JNZ _TPRT_GE_E1
        MOV EAX,OFFSET GR_ERRMSG0
        JMP _TPRT_GE_DN
_TPRT_GE_E1:
        CMP EAX,-2
        JNE _TPRT_GE_E2
        MOV EAX,OFFSET GR_ERRMSG2
        JMP _TPRT_GE_DN
_TPRT_GE_E2:
        MOV EAX,OFFSET GR_ERRMSG1
_TPRT_GE_DN:
        POP EBP
        RET

_TPRT_IMAGESIZE:
        PUSH EBP
        MOV EBP,ESP
        MOV EAX,DWORD PTR [EBP+16]
        SUB EAX,DWORD PTR [EBP+8]
        INC EAX
        MOV ECX,DWORD PTR [EBP+20]
        SUB ECX,DWORD PTR [EBP+12]
        INC ECX
        IMUL EAX,ECX
        SHL EAX,2
        ADD EAX,4
        POP EBP
        RET

_TPRT_TEXTHEIGHT:
        PUSH EBP
        MOV EBP,ESP
        PUSHAD
        MOV ESI,DWORD PTR [EBP+8]
        XOR ECX,ECX
        MOV CL,BYTE PTR [ESI]
        INC ESI
        PUSH OFFSET GR_TXSIZE2
        PUSH ECX
        PUSH ESI
        PUSH DWORD PTR [GR_HDC]
        CALL GetTextExtentPoint32A
        POPAD
        MOV EAX,DWORD PTR [GR_TXSIZE2+4]
        POP EBP
        RET

_TPRT_TEXTWIDTH:
        PUSH EBP
        MOV EBP,ESP
        PUSHAD
        MOV ESI,DWORD PTR [EBP+8]
        XOR ECX,ECX
        MOV CL,BYTE PTR [ESI]
        INC ESI
        PUSH OFFSET GR_TXSIZE2
        PUSH ECX
        PUSH ESI
        PUSH DWORD PTR [GR_HDC]
        CALL GetTextExtentPoint32A
        POPAD
        MOV EAX,DWORD PTR [GR_TXSIZE2]
        POP EBP
        RET

; ============================================================
;  RUNTIME STRINGS : routines unite Strings (PChar / ASCIIZ)  
; ============================================================

_TPRT_STRCOPY:
        PUSH EBP
        MOV EBP,ESP
        MOV EAX,DWORD PTR [EBP+12]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        CALL lstrcpyA
        MOV EAX,DWORD PTR [EBP+8]
        POP EBP
        RET

_TPRT_STRCAT:
        PUSH EBP
        MOV EBP,ESP
        MOV EAX,DWORD PTR [EBP+12]
        PUSH EAX
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        CALL lstrcatA
        MOV EAX,DWORD PTR [EBP+8]
        POP EBP
        RET

_TPRT_STRPOS:
        PUSH EBP
        MOV EBP,ESP
        PUSH EBX
        PUSH ESI
        PUSH EDI
        MOV ESI,DWORD PTR [EBP+8]
        MOV EDI,DWORD PTR [EBP+12]
        PUSH EDI
        CALL lstrlenA
        MOV ECX,EAX
        TEST ECX,ECX
        JZ _TPRT_SP_NUL
        PUSH ESI
        CALL lstrlenA
        MOV EBX,EAX
        SUB EBX,ECX
        JS _TPRT_SP_NF
        INC EBX
_TPRT_SP_LP:
        PUSH ECX
        PUSH ESI
        PUSH EDI
        REPE CMPSB
        POP EDI
        POP ESI
        POP ECX
        JE _TPRT_SP_FD
        INC ESI
        DEC EBX
        JNZ _TPRT_SP_LP
_TPRT_SP_NF:
        XOR EAX,EAX
        JMP _TPRT_SP_DN
_TPRT_SP_NUL:
        MOV EAX,ESI
        JMP _TPRT_SP_DN
_TPRT_SP_FD:
        MOV EAX,ESI
_TPRT_SP_DN:
        POP EDI
        POP ESI
        POP EBX
        POP EBP
        RET

_TPRT_STRSCAN:
        PUSH EBP
        MOV EBP,ESP
        MOV EDX,DWORD PTR [EBP+8]
        MOV CL,BYTE PTR [EBP+12]
_TPRT_SC_LP:
        MOV AL,BYTE PTR [EDX]
        CMP AL,CL
        JE _TPRT_SC_FD
        TEST AL,AL
        JZ _TPRT_SC_NF
        INC EDX
        JMP _TPRT_SC_LP
_TPRT_SC_NF:
        XOR EAX,EAX
        POP EBP
        RET
_TPRT_SC_FD:
        MOV EAX,EDX
        POP EBP
        RET

_TPRT_STRRSCAN:
        PUSH EBP
        MOV EBP,ESP
        PUSH EBX
        MOV EDX,DWORD PTR [EBP+8]
        MOV CL,BYTE PTR [EBP+12]
        XOR EBX,EBX
_TPRT_RS_LP:
        MOV AL,BYTE PTR [EDX]
        TEST AL,AL
        JZ _TPRT_RS_DN
        CMP AL,CL
        JNE _TPRT_RS_NX
        MOV EBX,EDX
_TPRT_RS_NX:
        INC EDX
        JMP _TPRT_RS_LP
_TPRT_RS_DN:
        MOV EAX,EBX
        POP EBX
        POP EBP
        RET

_TPRT_STREND:
        MOV EAX,DWORD PTR [ESP+4]
_TPRT_SE_LP:
        CMP BYTE PTR [EAX],0
        JE _TPRT_SE_DN
        INC EAX
        JMP _TPRT_SE_LP
_TPRT_SE_DN:
        RET

_TPRT_STRMOVE:
        PUSH EBP
        MOV EBP,ESP
        PUSH ESI
        PUSH EDI
        PUSH ECX
        MOV EDI,DWORD PTR [EBP+8]
        MOV ESI,DWORD PTR [EBP+12]
        MOV ECX,DWORD PTR [EBP+16]
        REP MOVSB
        POP ECX
        POP EDI
        POP ESI
        MOV EAX,DWORD PTR [EBP+8]
        POP EBP
        RET

_TPRT_STRNEW:
        PUSH EBP
        MOV EBP,ESP
        PUSH EBX
        MOV EAX,DWORD PTR [EBP+8]
        PUSH EAX
        CALL lstrlenA
        INC EAX
        MOV EBX,EAX
        PUSH EBX
        PUSH 0
        PUSH DWORD PTR [HHEAP]
        CALL HeapAlloc
        TEST EAX,EAX
        JZ _TPRT_SN_DN
        PUSH DWORD PTR [EBP+8]
        PUSH EAX
        MOV EBX,EAX
        CALL lstrcpyA
        MOV EAX,EBX
_TPRT_SN_DN:
        POP EBX
        POP EBP
        RET

_TPRT_STRDISPOSE:
        PUSH EBP
        MOV EBP,ESP
        MOV EAX,DWORD PTR [EBP+8]
        TEST EAX,EAX
        JZ _TPRT_SD_DN
        PUSH EAX
        PUSH 0
        PUSH DWORD PTR [HHEAP]
        CALL HeapFree
_TPRT_SD_DN:
        POP EBP
        RET

_TPRT_STRPAS:
        PUSH EBP
        MOV EBP,ESP
        PUSH ESI
        PUSH EDI
        MOV ESI,DWORD PTR [EBP+8]
        PUSH ESI
        CALL lstrlenA
        CMP EAX,255
        JBE _TPRT_PA_OK
        MOV EAX,255
_TPRT_PA_OK:
        LEA EDI,[STR_PASBUF]
        MOV BYTE PTR [EDI],AL
        MOV ECX,EAX
        INC EDI
        REP MOVSB
        MOV EAX,OFFSET STR_PASBUF
        POP EDI
        POP ESI
        POP EBP
        RET

_TPRT_STRPCOPY:
        PUSH EBP
        MOV EBP,ESP
        PUSH ESI
        PUSH EDI
        MOV EDI,DWORD PTR [EBP+8]
        MOV ESI,DWORD PTR [EBP+12]
        XOR ECX,ECX
        MOV CL,BYTE PTR [ESI]
        INC ESI
        REP MOVSB
        MOV BYTE PTR [EDI],0
        MOV EAX,DWORD PTR [EBP+8]
        POP EDI
        POP ESI
        POP EBP
        RET

_TPRT_STRUPPER:
        PUSH EBP
        MOV EBP,ESP
        MOV EDX,DWORD PTR [EBP+8]
        MOV EAX,EDX
_TPRT_SU_LP:
        MOV CL,BYTE PTR [EDX]
        TEST CL,CL
        JZ _TPRT_SU_DN
        CMP CL,'a'
        JB _TPRT_SU_NX
        CMP CL,'z'
        JA _TPRT_SU_NX
        SUB CL,32
        MOV BYTE PTR [EDX],CL
_TPRT_SU_NX:
        INC EDX
        JMP _TPRT_SU_LP
_TPRT_SU_DN:
        POP EBP
        RET

_TPRT_STRLOWER:
        PUSH EBP
        MOV EBP,ESP
        MOV EDX,DWORD PTR [EBP+8]
        MOV EAX,EDX
_TPRT_SL_LP:
        MOV CL,BYTE PTR [EDX]
        TEST CL,CL
        JZ _TPRT_SL_DN
        CMP CL,'A'
        JB _TPRT_SL_NX
        CMP CL,'Z'
        JA _TPRT_SL_NX
        ADD CL,32
        MOV BYTE PTR [EDX],CL
_TPRT_SL_NX:
        INC EDX
        JMP _TPRT_SL_LP
_TPRT_SL_DN:
        POP EBP
        RET

_TPRT_STRLCOPY:
        PUSH EBP
        MOV EBP,ESP
        PUSH ESI
        PUSH EDI
        MOV EDI,DWORD PTR [EBP+8]
        MOV ESI,DWORD PTR [EBP+12]
        MOV ECX,DWORD PTR [EBP+16]
_TPRT_LC_LP:
        TEST ECX,ECX
        JZ _TPRT_LC_DN
        MOV AL,BYTE PTR [ESI]
        MOV BYTE PTR [EDI],AL
        TEST AL,AL
        JZ _TPRT_LC_DN
        INC ESI
        INC EDI
        DEC ECX
        JMP _TPRT_LC_LP
_TPRT_LC_DN:
        MOV BYTE PTR [EDI],0
        MOV EAX,DWORD PTR [EBP+8]
        POP EDI
        POP ESI
        POP EBP
        RET

_TPRT_STRLCAT:
        PUSH EBP
        MOV EBP,ESP
        PUSH EBX
        PUSH ESI
        PUSH EDI
        MOV EDI,DWORD PTR [EBP+8]
_TPRT_LA_FE:
        CMP BYTE PTR [EDI],0
        JE _TPRT_LA_CP
        INC EDI
        JMP _TPRT_LA_FE
_TPRT_LA_CP:
        MOV EBX,EDI
        SUB EBX,DWORD PTR [EBP+8]
        MOV ECX,DWORD PTR [EBP+16]
        SUB ECX,EBX
        JLE _TPRT_LA_DN
        MOV ESI,DWORD PTR [EBP+12]
_TPRT_LA_LP:
        TEST ECX,ECX
        JZ _TPRT_LA_DN
        MOV AL,BYTE PTR [ESI]
        MOV BYTE PTR [EDI],AL
        TEST AL,AL
        JZ _TPRT_LA_DN
        INC ESI
        INC EDI
        DEC ECX
        JMP _TPRT_LA_LP
_TPRT_LA_DN:
        MOV BYTE PTR [EDI],0
        MOV EAX,DWORD PTR [EBP+8]
        POP EDI
        POP ESI
        POP EBX
        POP EBP
        RET

_TPRT_STRECOPY:
        PUSH EBP
        MOV EBP,ESP
        PUSH ESI
        PUSH EDI
        MOV EDI,DWORD PTR [EBP+8]
        MOV ESI,DWORD PTR [EBP+12]
_TPRT_EC_LP:
        MOV AL,BYTE PTR [ESI]
        MOV BYTE PTR [EDI],AL
        TEST AL,AL
        JZ _TPRT_EC_DN
        INC ESI
        INC EDI
        JMP _TPRT_EC_LP
_TPRT_EC_DN:
        MOV EAX,EDI
        POP EDI
        POP ESI
        POP EBP
        RET

_TPRT_STRLICOMP:
        PUSH EBP
        MOV EBP,ESP
        PUSH ESI
        PUSH EDI
        MOV ESI,DWORD PTR [EBP+8]
        MOV EDI,DWORD PTR [EBP+12]
        MOV ECX,DWORD PTR [EBP+16]
_TPRT_LI_LP:
        TEST ECX,ECX
        JZ _TPRT_LI_EQ
        MOV AL,BYTE PTR [ESI]
        MOV AH,BYTE PTR [EDI]
        CMP AL,'a'
        JB _TPRT_LI_N1
        CMP AL,'z'
        JA _TPRT_LI_N1
        SUB AL,32
_TPRT_LI_N1:
        CMP AH,'a'
        JB _TPRT_LI_N2
        CMP AH,'z'
        JA _TPRT_LI_N2
        SUB AH,32
_TPRT_LI_N2:
        CMP AL,AH
        JNE _TPRT_LI_NE
        TEST AL,AL
        JZ _TPRT_LI_EQ
        INC ESI
        INC EDI
        DEC ECX
        JMP _TPRT_LI_LP
_TPRT_LI_EQ:
        XOR EAX,EAX
        JMP _TPRT_LI_DN
_TPRT_LI_NE:
        MOVZX EAX,AL
        MOVZX EDX,AH
        SUB EAX,EDX
_TPRT_LI_DN:
        POP EDI
        POP ESI
        POP EBP
        RET
END _TPF_Main
