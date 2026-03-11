; TPCW32 - Compilateur Turbo Pascal -> ASM 80386 Win32
; Genere automatiquement a partir de : SAMPLES/PASCAL/test_control.pas

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
_TPK_1  DB '=== Test structures de controle (TODO 13) ===',0
_TPK_2  DB 'IF simple: n > 5',0
_TPK_3  DB 'ERREUR: ne devrait pas afficher',0
_TPK_4  DB 'IF ELSE: n <= 20',0
_TPK_5  DB 'ERREUR',0
_TPK_6  DB 'IF ELSE IF: n <= 50',0
_TPK_7  DB 'IF BEGIN END: bloc 1',0
_TPK_8  DB 'IF BEGIN END: bloc 2',0
_TPK_9  DB 'WHILE: i=',0
_TPK_10  DB 'REPEAT: i=',0
_TPK_11  DB 'FOR: i=',0
_TPK_12  DB 'DOWNTO: i=',0
_TPK_13  DB 'CASE: un',0
_TPK_14  DB 'CASE: deux',0
_TPK_15  DB 'CASE: trois',0
_TPK_16  DB 'CASE: autre',0
_TPK_17  DB 'CASE BEGIN: premier',0
_TPK_18  DB 'CASE BEGIN: suite',0
_TPK_19  DB 'CASE: deuxieme',0
_TPK_20  DB 'IMBRIQUE: i=',0
_TPK_21  DB ' j=',0
_TPK_22  DB 'SOMME 1..10 = ',0
_TPK_23  DB '=== Fin des tests ===',0
_TPV_I  DD 0
_TPV_J  DD 0
_TPV_N  DD 0
_TPV_SOMME  DD 0

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
        MOV EAX,10
        MOV DWORD PTR [_TPV_N],EAX
; if
        MOV EAX,DWORD PTR [_TPV_N]
        PUSH EAX
        MOV EAX,5
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _TPL_2
        XOR EAX,EAX
        JMP _TPL_3
_TPL_2:
        MOV EAX,1
_TPL_3:
        TEST EAX,EAX
        JZ _TPL_4
; writeln
        LEA EAX,[_TPK_2]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
_TPL_4:
; if
        MOV EAX,DWORD PTR [_TPV_N]
        PUSH EAX
        MOV EAX,20
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _TPL_6
        XOR EAX,EAX
        JMP _TPL_7
_TPL_6:
        MOV EAX,1
_TPL_7:
        TEST EAX,EAX
        JZ _TPL_8
; writeln
        LEA EAX,[_TPK_3]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        JMP _TPL_9
_TPL_8:
; writeln
        LEA EAX,[_TPK_4]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
_TPL_9:
; if
        MOV EAX,DWORD PTR [_TPV_N]
        PUSH EAX
        MOV EAX,100
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _TPL_10
        XOR EAX,EAX
        JMP _TPL_11
_TPL_10:
        MOV EAX,1
_TPL_11:
        TEST EAX,EAX
        JZ _TPL_12
; writeln
        LEA EAX,[_TPK_5]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        JMP _TPL_13
_TPL_12:
; if
        MOV EAX,DWORD PTR [_TPV_N]
        PUSH EAX
        MOV EAX,50
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _TPL_14
        XOR EAX,EAX
        JMP _TPL_15
_TPL_14:
        MOV EAX,1
_TPL_15:
        TEST EAX,EAX
        JZ _TPL_16
; writeln
        LEA EAX,[_TPK_5]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        JMP _TPL_17
_TPL_16:
; writeln
        LEA EAX,[_TPK_6]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
_TPL_17:
_TPL_13:
; if
        MOV EAX,DWORD PTR [_TPV_N]
        PUSH EAX
        MOV EAX,5
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _TPL_18
        XOR EAX,EAX
        JMP _TPL_19
_TPL_18:
        MOV EAX,1
_TPL_19:
        TEST EAX,EAX
        JZ _TPL_20
; writeln
        LEA EAX,[_TPK_7]
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
_TPL_20:
        MOV EAX,1
        MOV DWORD PTR [_TPV_I],EAX
; while
_TPL_22:
        MOV EAX,DWORD PTR [_TPV_I]
        PUSH EAX
        MOV EAX,3
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JLE _TPL_24
        XOR EAX,EAX
        JMP _TPL_25
_TPL_24:
        MOV EAX,1
_TPL_25:
        TEST EAX,EAX
        JZ _TPL_23
; write
        LEA EAX,[_TPK_9]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
; writeln
        MOV EAX,DWORD PTR [_TPV_I]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        MOV EAX,DWORD PTR [_TPV_I]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [_TPV_I],EAX
        JMP _TPL_22
_TPL_23:
        MOV EAX,1
        MOV DWORD PTR [_TPV_I],EAX
; repeat
_TPL_26:
; write
        LEA EAX,[_TPK_10]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
; writeln
        MOV EAX,DWORD PTR [_TPV_I]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        MOV EAX,DWORD PTR [_TPV_I]
        PUSH EAX
        MOV EAX,1
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [_TPV_I],EAX
        MOV EAX,DWORD PTR [_TPV_I]
        PUSH EAX
        MOV EAX,3
        MOV EBX,EAX
        POP EAX
        CMP EAX,EBX
        JG _TPL_28
        XOR EAX,EAX
        JMP _TPL_29
_TPL_28:
        MOV EAX,1
_TPL_29:
        TEST EAX,EAX
        JZ _TPL_26
_TPL_27:
; for
        MOV EAX,1
        MOV DWORD PTR [_TPV_I],EAX
        MOV EAX,3
        MOV DWORD PTR [_TPL_30],EAX
_TPL_31:
        MOV EAX,DWORD PTR [_TPV_I]
        CMP EAX,DWORD PTR [_TPL_30]
        JG _TPL_32
; write
        LEA EAX,[_TPK_11]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
; writeln
        MOV EAX,DWORD PTR [_TPV_I]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
_TPL_33:
        MOV EAX,DWORD PTR [_TPV_I]
        INC EAX
        MOV DWORD PTR [_TPV_I],EAX
        JMP _TPL_31
_TPL_32:
; for
        MOV EAX,3
        MOV DWORD PTR [_TPV_I],EAX
        MOV EAX,1
        MOV DWORD PTR [_TPL_34],EAX
_TPL_35:
        MOV EAX,DWORD PTR [_TPV_I]
        CMP EAX,DWORD PTR [_TPL_34]
        JL _TPL_36
; write
        LEA EAX,[_TPK_12]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
; writeln
        MOV EAX,DWORD PTR [_TPV_I]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
_TPL_37:
        MOV EAX,DWORD PTR [_TPV_I]
        DEC EAX
        MOV DWORD PTR [_TPV_I],EAX
        JMP _TPL_35
_TPL_36:
        MOV EAX,2
        MOV DWORD PTR [_TPV_N],EAX
; case
        MOV EAX,DWORD PTR [_TPV_N]
        PUSH EAX
        MOV EAX,DWORD PTR [ESP]
        CMP EAX,1
        JE _TPL_40
        JMP _TPL_39
_TPL_40:
; writeln
        LEA EAX,[_TPK_13]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        JMP _TPL_38
_TPL_39:
        MOV EAX,DWORD PTR [ESP]
        CMP EAX,2
        JE _TPL_42
        JMP _TPL_41
_TPL_42:
; writeln
        LEA EAX,[_TPK_14]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        JMP _TPL_38
_TPL_41:
        MOV EAX,DWORD PTR [ESP]
        CMP EAX,3
        JE _TPL_44
        JMP _TPL_43
_TPL_44:
; writeln
        LEA EAX,[_TPK_15]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        JMP _TPL_38
_TPL_43:
; case default
; writeln
        LEA EAX,[_TPK_16]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
_TPL_38:
        POP EAX
        MOV EAX,1
        MOV DWORD PTR [_TPV_N],EAX
; case
        MOV EAX,DWORD PTR [_TPV_N]
        PUSH EAX
        MOV EAX,DWORD PTR [ESP]
        CMP EAX,1
        JE _TPL_47
        JMP _TPL_46
_TPL_47:
; writeln
        LEA EAX,[_TPK_17]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
; writeln
        LEA EAX,[_TPK_18]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        JMP _TPL_45
_TPL_46:
        MOV EAX,DWORD PTR [ESP]
        CMP EAX,2
        JE _TPL_49
        JMP _TPL_48
_TPL_49:
; writeln
        LEA EAX,[_TPK_19]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
        JMP _TPL_45
_TPL_48:
_TPL_45:
        POP EAX
; for
        MOV EAX,1
        MOV DWORD PTR [_TPV_I],EAX
        MOV EAX,2
        MOV DWORD PTR [_TPL_50],EAX
_TPL_51:
        MOV EAX,DWORD PTR [_TPV_I]
        CMP EAX,DWORD PTR [_TPL_50]
        JG _TPL_52
; for
        MOV EAX,1
        MOV DWORD PTR [_TPV_J],EAX
        MOV EAX,2
        MOV DWORD PTR [_TPL_54],EAX
_TPL_55:
        MOV EAX,DWORD PTR [_TPV_J]
        CMP EAX,DWORD PTR [_TPL_54]
        JG _TPL_56
; write
        LEA EAX,[_TPK_20]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
; write
        MOV EAX,DWORD PTR [_TPV_I]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
; write
        LEA EAX,[_TPK_21]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
; writeln
        MOV EAX,DWORD PTR [_TPV_J]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
_TPL_57:
        MOV EAX,DWORD PTR [_TPV_J]
        INC EAX
        MOV DWORD PTR [_TPV_J],EAX
        JMP _TPL_55
_TPL_56:
_TPL_53:
        MOV EAX,DWORD PTR [_TPV_I]
        INC EAX
        MOV DWORD PTR [_TPV_I],EAX
        JMP _TPL_51
_TPL_52:
        MOV EAX,0
        MOV DWORD PTR [_TPV_SOMME],EAX
; for
        MOV EAX,1
        MOV DWORD PTR [_TPV_I],EAX
        MOV EAX,10
        MOV DWORD PTR [_TPL_58],EAX
_TPL_59:
        MOV EAX,DWORD PTR [_TPV_I]
        CMP EAX,DWORD PTR [_TPL_58]
        JG _TPL_60
        MOV EAX,DWORD PTR [_TPV_SOMME]
        PUSH EAX
        MOV EAX,DWORD PTR [_TPV_I]
        MOV EBX,EAX
        POP EAX
        ADD EAX,EBX
        MOV DWORD PTR [_TPV_SOMME],EAX
_TPL_61:
        MOV EAX,DWORD PTR [_TPV_I]
        INC EAX
        MOV DWORD PTR [_TPV_I],EAX
        JMP _TPL_59
_TPL_60:
; write
        LEA EAX,[_TPK_22]
        MOV ESI,EAX
        CALL _TPRT_PRINTSTR
; writeln
        MOV EAX,DWORD PTR [_TPV_SOMME]
        CALL _TPRT_NUMTOSTR
        LEA ESI,[NUMBUF]
        CALL _TPRT_PRINTSTR
        LEA ESI,[CRLF]
        CALL _TPRT_PRINTSTR
; writeln
        LEA EAX,[_TPK_23]
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
