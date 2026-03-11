; TPCW32 - Compilateur Turbo Pascal -> ASM 80386 Win32
; Genere automatiquement a partir de : SAMPLES/PASCAL/test_strings.pas

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
STRBUF1   DB 256 DUP(0)
STRBUF2   DB 256 DUP(0)
TRUE_STR  DB 'TRUE',0
FALSE_STR DB 'FALSE',0

; --- Constantes et donnees utilisateur ---
_TPK_1  DB 'Hello',0
_TPK_2  DB 'Length test:',0
_TPK_3  DB 'Concat test:',0
_TPK_4  DB ' ',0
_TPK_5  DB 'World',0
_TPK_6  DB 'Copy test:',0
_TPK_7  DB 'ABCDEF',0
_TPK_8  DB 'Pos test:',0
_TPK_9  DB 'Hello World',0
_TPK_10  DB 'Upcase test:',0
_TPK_11  DB 'a',0
_TPK_12  DB 'Concat func:',0
_TPK_13  DB 'AB',0
_TPK_14  DB 'CD',0
_TPK_15  DB 'EF',0
_TPK_16  DB 'Compare test:',0
_TPK_17  DB 'ABC',0
_TPK_18  DB 'Equal',0
_TPK_19  DB 'Not equal',0
_TPK_20  DB 'DEF',0
_TPK_21  DB 'Less',0
_TPK_22  DB 'Not less',0
_TPK_23  DB 'Str/Val test:',0
_TPK_24  DB 'Done',0
_TPV_S1  DB 256 DUP(0)
_TPV_S2  DB 256 DUP(0)
_TPV_S3  DB 256 DUP(0)
_TPV_N  DD 0
_TPV_C  DB 0

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
        LEA EAX,[_TPK_1]
        MOV ESI,EAX
        LEA EDI,[_TPV_S1]
        CALL _TPRT_STRCPY
; writeln
        LEA EAX,[_TPK_2]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        LEA EAX,[_TPV_S1]
        MOV ESI,EAX
        CALL _TPRT_STRLEN
        MOV DWORD PTR [_TPV_N],EAX
; writeln
        MOV EAX,DWORD PTR [_TPV_N]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
; writeln
        LEA EAX,[_TPK_3]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        LEA EAX,[_TPK_1]
        MOV ESI,EAX
        LEA EDI,[STRBUF1]
        CALL _TPRT_STRCPY
        LEA EAX,[_TPK_4]
        MOV EDI,EAX
        LEA ESI,[STRBUF1]
        CALL _TPRT_CONCAT
        LEA EAX,[STRBUF1]
        MOV ESI,EAX
        LEA EDI,[STRBUF1]
        CALL _TPRT_STRCPY
        LEA EAX,[_TPK_5]
        MOV EDI,EAX
        LEA ESI,[STRBUF1]
        CALL _TPRT_CONCAT
        LEA EAX,[STRBUF1]
        MOV ESI,EAX
        LEA EDI,[_TPV_S2]
        CALL _TPRT_STRCPY
; writeln
        LEA EAX,[_TPV_S2]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
; writeln
        LEA EAX,[_TPK_6]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        LEA EAX,[_TPK_7]
        MOV ESI,EAX
        LEA EDI,[_TPV_S1]
        CALL _TPRT_STRCPY
        LEA EAX,[_TPV_S1]
        PUSH EAX
        MOV EAX,2
        PUSH EAX
        MOV EAX,3
        MOV ECX,EAX
        POP EBX
        POP ESI
        CALL _TPRT_COPY
        MOV ESI,EAX
        LEA EDI,[_TPV_S3]
        CALL _TPRT_STRCPY
; writeln
        LEA EAX,[_TPV_S3]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
; writeln
        LEA EAX,[_TPK_8]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        LEA EAX,[_TPK_9]
        MOV ESI,EAX
        LEA EDI,[_TPV_S1]
        CALL _TPRT_STRCPY
        LEA EAX,[_TPK_5]
        PUSH EAX
        LEA EAX,[_TPV_S1]
        MOV ESI,EAX
        POP EDI
        CALL _TPRT_POS
        MOV DWORD PTR [_TPV_N],EAX
; writeln
        MOV EAX,DWORD PTR [_TPV_N]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
; writeln
        LEA EAX,[_TPK_10]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        LEA EAX,[_TPK_11]
        CMP AL,97
        JB _TPL_2
        CMP AL,122
        JA _TPL_2
        SUB AL,32
_TPL_2:
        MOV BYTE PTR [_TPV_C],AL
; write
        MOVZX EAX,BYTE PTR [_TPV_C]
        MOV BYTE PTR [STRTMP],AL
        MOV BYTE PTR [STRTMP+1],0
        LEA ESI,[STRTMP]
        CALL _TPRT_PRINTSTR
; writeln
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
; writeln
        LEA EAX,[_TPK_12]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        LEA EAX,[_TPK_13]
        MOV ESI,EAX
        LEA EDI,[STRBUF1]
        CALL _TPRT_STRCPY
        LEA EAX,[_TPK_14]
        MOV EDI,EAX
        LEA ESI,[STRBUF1]
        CALL _TPRT_CONCAT
        LEA EAX,[_TPK_15]
        MOV EDI,EAX
        LEA ESI,[STRBUF1]
        CALL _TPRT_CONCAT
        LEA EAX,[STRBUF1]
        MOV ESI,EAX
        LEA EDI,[_TPV_S1]
        CALL _TPRT_STRCPY
; writeln
        LEA EAX,[_TPV_S1]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
; writeln
        LEA EAX,[_TPK_16]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        LEA EAX,[_TPK_17]
        MOV ESI,EAX
        LEA EDI,[_TPV_S1]
        CALL _TPRT_STRCPY
        LEA EAX,[_TPK_17]
        MOV ESI,EAX
        LEA EDI,[_TPV_S2]
        CALL _TPRT_STRCPY
; if
        LEA EAX,[_TPV_S1]
        PUSH EAX
        LEA EAX,[_TPV_S2]
        MOV EDI,EAX
        POP ESI
        CALL _TPRT_STRCMP
        TEST EAX,EAX
        JZ _TPL_3
        XOR EAX,EAX
        JMP _TPL_4
_TPL_3:
        MOV EAX,1
_TPL_4:
        TEST EAX,EAX
        JZ _TPL_5
; writeln
        LEA EAX,[_TPK_18]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        JMP _TPL_6
_TPL_5:
; writeln
        LEA EAX,[_TPK_19]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
_TPL_6:
        LEA EAX,[_TPK_20]
        MOV ESI,EAX
        LEA EDI,[_TPV_S2]
        CALL _TPRT_STRCPY
; if
        LEA EAX,[_TPV_S1]
        PUSH EAX
        LEA EAX,[_TPV_S2]
        MOV EDI,EAX
        POP ESI
        CALL _TPRT_STRCMP
        TEST EAX,EAX
        JS _TPL_7
        XOR EAX,EAX
        JMP _TPL_8
_TPL_7:
        MOV EAX,1
_TPL_8:
        TEST EAX,EAX
        JZ _TPL_9
; writeln
        LEA EAX,[_TPK_21]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        JMP _TPL_10
_TPL_9:
; writeln
        LEA EAX,[_TPK_22]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
_TPL_10:
; writeln
        LEA EAX,[_TPK_23]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
; str
        MOV EAX,42
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        LEA EAX,[_TPV_S1]
        MOV EDI,EAX
        CALL _TPRT_STRCPY
; writeln
        LEA EAX,[_TPV_S1]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
; val
        LEA EAX,[_TPV_S1]
        MOV ESI,EAX
        CALL _TPRT_STRTONUM
        MOV DWORD PTR [_TPV_N],EAX
        XOR EAX,EAX
        MOV DWORD PTR [_TPV_N],EAX
; writeln
        MOV EAX,DWORD PTR [_TPV_N]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
; writeln
        LEA EAX,[_TPK_24]
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
END _TPF_Main
