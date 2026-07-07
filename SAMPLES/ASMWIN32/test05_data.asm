; test05_data.asm - Test 5 : declarations de donnees DB/DW/DD/DQ et DUP
; Affiche la somme des elements d'un tableau DD rempli par DUP.

.386
.MODEL FLAT
EXTERN GetStdHandle:PROC
EXTERN WriteFile:PROC
EXTERN ExitProcess:PROC

.DATA
byteval  DB 42
wordval  DW 1000
dwordval DD 100000
qwordval DQ 0
array10  DD 10 DUP(5)          ; 10 entiers valant 5 -> somme attendue 50
msgbuf   DB 'Somme du tableau calculee.', 13, 10, 0
msglen   DD 28
written  DD 0

.DATA?
scratch  DD ?

.CODE
start:
        ; sommer les 10 entiers de array10
        MOV ECX, 10
        MOV ESI, 0              ; index
        MOV EAX, 0              ; accumulateur
sumloop:
        MOV EBX, [array10 + ESI*4]
        ADD EAX, EBX
        INC ESI
        LOOP sumloop
        MOV scratch, EAX

        ; afficher un message de confirmation
        PUSH -11
        CALL GetStdHandle
        MOV EBX, EAX
        PUSH 0
        PUSH OFFSET written
        PUSH msglen
        PUSH OFFSET msgbuf
        PUSH EBX
        CALL WriteFile

        ; code de sortie = somme (attendu 50)
        PUSH scratch
        CALL ExitProcess

END start
