; test06_strings.asm - Test 6 : instructions chaine (STOSB/MOVSB) et REP
; Remplit un buffer de 20 'A', puis le copie dans un second buffer,
; et affiche le resultat.

.386
.MODEL FLAT
EXTERN GetStdHandle:PROC
EXTERN WriteFile:PROC
EXTERN ExitProcess:PROC

.DATA?
buf1    DB 21 DUP(?)
buf2    DB 21 DUP(?)

.DATA
written DD 0

.CODE
start:
        ; buf1 <- 20 fois 'A' + terminateur nul (via EDI/STOSB)
        MOV EDI, OFFSET buf1
        MOV AL, 'A'
        MOV ECX, 20
        REP STOSB
        MOV BYTE PTR [EDI], 0

        ; buf2 <- copie de buf1 (via ESI/EDI/MOVSB)
        MOV ESI, OFFSET buf1
        MOV EDI, OFFSET buf2
        MOV ECX, 21
        REP MOVSB

        ; afficher buf2
        PUSH -11
        CALL GetStdHandle
        MOV EBX, EAX
        PUSH 0
        PUSH OFFSET written
        PUSH 20
        PUSH OFFSET buf2
        PUSH EBX
        CALL WriteFile

        PUSH 0
        CALL ExitProcess

END start
