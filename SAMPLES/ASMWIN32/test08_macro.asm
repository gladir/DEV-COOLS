; test08_macro.asm - Test 8 : macros MACRO/ENDM avec parametres
; Une macro PrintMsg(handle, buffer, len) encapsule l'appel a WriteFile.

.386
.MODEL FLAT
EXTERN GetStdHandle:PROC
EXTERN WriteFile:PROC
EXTERN ExitProcess:PROC

PrintMsg MACRO hStdOut, buffer, len
        PUSH 0
        PUSH OFFSET written
        PUSH len
        PUSH OFFSET buffer
        PUSH hStdOut
        CALL WriteFile
ENDM

.DATA
msg1    DB 'Premiere ligne.', 13, 10, 0
msg1len DD 17
msg2    DB 'Deuxieme ligne.', 13, 10, 0
msg2len DD 17
written DD 0

.CODE
start:
        PUSH -11
        CALL GetStdHandle
        MOV EBX, EAX

        PrintMsg EBX, msg1, msg1len
        PrintMsg EBX, msg2, msg2len

        PUSH 0
        CALL ExitProcess

END start
