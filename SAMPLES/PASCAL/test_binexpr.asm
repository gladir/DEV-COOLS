; TPCW32 - Compilateur Turbo Pascal -> ASM 80386 Win32
; Genere automatiquement a partir de : SAMPLES/PASCAL/test_binexpr.pas

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
_TPK_1  DB '10 + 3 = ',0
_TPK_2  DB '10 - 3 = ',0
_TPK_3  DB '10 * 3 = ',0
_TPK_4  DB '10 div 3 = ',0
_TPK_5  DB '10 mod 3 = ',0
_TPK_6  DB '12 and 10 = ',0
_TPK_7  DB '12 or 10 = ',0
_TPK_8  DB '12 xor 10 = ',0
_TPK_9  DB '1 shl 4 = ',0
_TPK_10  DB '32 shr 2 = ',0
_TPK_11  DB '5 = 10 -> ',0
_TPK_12  DB '5 = 5  -> ',0
_TPK_13  DB '5 <> 10 -> ',0
_TPK_14  DB '5 < 10 -> ',0
_TPK_15  DB '5 > 10 -> ',0
_TPK_16  DB '5 <= 10 -> ',0
_TPK_17  DB '5 >= 10 -> ',0
_TPK_18  DB '2 + 3 * 4 = ',0
_TPK_19  DB '(2 + 3) * 4 = ',0
_TPK_20  DB '10 - 2 * 3 + 1 = ',0
_TPK_21  DB 'Fin du test des expressions binaires',0
_TPV_A  DD 0
_TPV_B  DD 0
_TPV_C  DD 0
_TPV_R  DD 0
_TPV_OK  DB 0

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
        MOV DWORD PTR [_TPV_A],EAX
        MOV EAX,3
        MOV DWORD PTR [_TPV_B],EAX
        MOV EAX,DWORD PTR [_TPV_A]
        PUSH EAX
        MOV EAX,DWORD PTR [_TPV_B]
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [_TPV_R],EAX
; write
        LEA EAX,[_TPK_1]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
; writeln
        MOV EAX,DWORD PTR [_TPV_R]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        MOV EAX,DWORD PTR [_TPV_A]
        PUSH EAX
        MOV EAX,DWORD PTR [_TPV_B]
        MOV EBX,EAX
        POP EAX
        SUB EAX,EBX
        MOV DWORD PTR [_TPV_R],EAX
; write
        LEA EAX,[_TPK_2]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
; writeln
        MOV EAX,DWORD PTR [_TPV_R]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        MOV EAX,DWORD PTR [_TPV_A]
        PUSH EAX
        MOV EAX,DWORD PTR [_TPV_B]
        MOV EBX,EAX
        POP EAX
        IMUL EAX,EBX
        MOV DWORD PTR [_TPV_R],EAX
; write
        LEA EAX,[_TPK_3]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
; writeln
        MOV EAX,DWORD PTR [_TPV_R]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        MOV EAX,DWORD PTR [_TPV_A]
        PUSH EAX
        MOV EAX,DWORD PTR [_TPV_B]
        MOV EBX,EAX
        POP EAX
        CDQ
        IDIV EBX
        MOV DWORD PTR [_TPV_R],EAX
; write
        LEA EAX,[_TPK_4]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
; writeln
        MOV EAX,DWORD PTR [_TPV_R]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        MOV EAX,DWORD PTR [_TPV_A]
        PUSH EAX
        MOV EAX,DWORD PTR [_TPV_B]
        MOV EBX,EAX
        POP EAX
        CDQ
        IDIV EBX
        MOV EAX,EDX
        MOV DWORD PTR [_TPV_R],EAX
; write
        LEA EAX,[_TPK_5]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
; writeln
        MOV EAX,DWORD PTR [_TPV_R]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        MOV EAX,12
        MOV DWORD PTR [_TPV_A],EAX
        MOV EAX,10
        MOV DWORD PTR [_TPV_B],EAX
        MOV EAX,DWORD PTR [_TPV_A]
        TEST EAX,EAX
        JZ _TPL_2
        MOV EAX,DWORD PTR [_TPV_B]
        TEST EAX,EAX
        JZ _TPL_2
        MOV EAX,1
        JMP _TPL_3
_TPL_2:
        XOR EAX,EAX
_TPL_3:
        MOV DWORD PTR [_TPV_R],EAX
; write
        LEA EAX,[_TPK_6]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
; writeln
        MOV EAX,DWORD PTR [_TPV_R]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        MOV EAX,DWORD PTR [_TPV_A]
        TEST EAX,EAX
        JNZ _TPL_4
        MOV EAX,DWORD PTR [_TPV_B]
        TEST EAX,EAX
        JNZ _TPL_4
        XOR EAX,EAX
        JMP _TPL_5
_TPL_4:
        MOV EAX,1
_TPL_5:
        MOV DWORD PTR [_TPV_R],EAX
; write
        LEA EAX,[_TPK_7]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
; writeln
        MOV EAX,DWORD PTR [_TPV_R]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        MOV EAX,DWORD PTR [_TPV_A]
        PUSH EAX
        MOV EAX,DWORD PTR [_TPV_B]
        MOV EBX,EAX
        POP EAX
        XOR EAX,EBX
        MOV DWORD PTR [_TPV_R],EAX
; write
        LEA EAX,[_TPK_8]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
; writeln
        MOV EAX,DWORD PTR [_TPV_R]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        MOV EAX,1
        PUSH EAX
        MOV EAX,4
        MOV EBX,EAX
        POP EAX
        MOV ECX,EBX
        SHL EAX,CL
        MOV DWORD PTR [_TPV_R],EAX
; write
        LEA EAX,[_TPK_9]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
; writeln
        MOV EAX,DWORD PTR [_TPV_R]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        MOV EAX,32
        PUSH EAX
        MOV EAX,2
        MOV EBX,EAX
        POP EAX
        MOV ECX,EBX
        SHR EAX,CL
        MOV DWORD PTR [_TPV_R],EAX
; write
        LEA EAX,[_TPK_10]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
; writeln
        MOV EAX,DWORD PTR [_TPV_R]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        MOV EAX,5
        MOV DWORD PTR [_TPV_A],EAX
        MOV EAX,10
        MOV DWORD PTR [_TPV_B],EAX
        MOV EAX,DWORD PTR [_TPV_A]
        PUSH EAX
        MOV EAX,DWORD PTR [_TPV_B]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _TPL_6
        XOR EAX,EAX
        JMP _TPL_7
_TPL_6:
        MOV EAX,1
_TPL_7:
        AND EAX,0FFh
        MOV DWORD PTR [_TPV_R],EAX
; write
        LEA EAX,[_TPK_11]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
; writeln
        MOV EAX,DWORD PTR [_TPV_R]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        MOV EAX,DWORD PTR [_TPV_A]
        PUSH EAX
        MOV EAX,5
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JE _TPL_8
        XOR EAX,EAX
        JMP _TPL_9
_TPL_8:
        MOV EAX,1
_TPL_9:
        AND EAX,0FFh
        MOV DWORD PTR [_TPV_R],EAX
; write
        LEA EAX,[_TPK_12]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
; writeln
        MOV EAX,DWORD PTR [_TPV_R]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        MOV EAX,DWORD PTR [_TPV_A]
        PUSH EAX
        MOV EAX,DWORD PTR [_TPV_B]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JNE _TPL_10
        XOR EAX,EAX
        JMP _TPL_11
_TPL_10:
        MOV EAX,1
_TPL_11:
        AND EAX,0FFh
        MOV DWORD PTR [_TPV_R],EAX
; write
        LEA EAX,[_TPK_13]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
; writeln
        MOV EAX,DWORD PTR [_TPV_R]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        MOV EAX,DWORD PTR [_TPV_A]
        PUSH EAX
        MOV EAX,DWORD PTR [_TPV_B]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JL _TPL_12
        XOR EAX,EAX
        JMP _TPL_13
_TPL_12:
        MOV EAX,1
_TPL_13:
        AND EAX,0FFh
        MOV DWORD PTR [_TPV_R],EAX
; write
        LEA EAX,[_TPK_14]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
; writeln
        MOV EAX,DWORD PTR [_TPV_R]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        MOV EAX,DWORD PTR [_TPV_A]
        PUSH EAX
        MOV EAX,DWORD PTR [_TPV_B]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _TPL_14
        XOR EAX,EAX
        JMP _TPL_15
_TPL_14:
        MOV EAX,1
_TPL_15:
        AND EAX,0FFh
        MOV DWORD PTR [_TPV_R],EAX
; write
        LEA EAX,[_TPK_15]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
; writeln
        MOV EAX,DWORD PTR [_TPV_R]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        MOV EAX,DWORD PTR [_TPV_A]
        PUSH EAX
        MOV EAX,DWORD PTR [_TPV_B]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JLE _TPL_16
        XOR EAX,EAX
        JMP _TPL_17
_TPL_16:
        MOV EAX,1
_TPL_17:
        AND EAX,0FFh
        MOV DWORD PTR [_TPV_R],EAX
; write
        LEA EAX,[_TPK_16]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
; writeln
        MOV EAX,DWORD PTR [_TPV_R]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        MOV EAX,DWORD PTR [_TPV_A]
        PUSH EAX
        MOV EAX,DWORD PTR [_TPV_B]
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JGE _TPL_18
        XOR EAX,EAX
        JMP _TPL_19
_TPL_18:
        MOV EAX,1
_TPL_19:
        AND EAX,0FFh
        MOV DWORD PTR [_TPV_R],EAX
; write
        LEA EAX,[_TPK_17]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
; writeln
        MOV EAX,DWORD PTR [_TPV_R]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        MOV EAX,2
        PUSH EAX
        MOV EAX,3
        PUSH EAX
        MOV EAX,4
        MOV EBX,EAX
        POP EAX
        IMUL EAX,EBX
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [_TPV_R],EAX
; write
        LEA EAX,[_TPK_18]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
; writeln
        MOV EAX,DWORD PTR [_TPV_R]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        MOV EAX,2
        PUSH EAX
        MOV EAX,3
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        PUSH EAX
        MOV EAX,4
        MOV EBX,EAX
        POP EAX
        IMUL EAX,EBX
        MOV DWORD PTR [_TPV_R],EAX
; write
        LEA EAX,[_TPK_19]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
; writeln
        MOV EAX,DWORD PTR [_TPV_R]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        MOV EAX,10
        PUSH EAX
        MOV EAX,2
        PUSH EAX
        MOV EAX,3
        MOV EBX,EAX
        POP EAX
        IMUL EAX,EBX
        MOV EBX,EAX
        POP EAX
        SUB EAX,EBX
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [_TPV_R],EAX
; write
        LEA EAX,[_TPK_20]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
; writeln
        MOV EAX,DWORD PTR [_TPV_R]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
; writeln
        LEA EAX,[_TPK_21]
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
