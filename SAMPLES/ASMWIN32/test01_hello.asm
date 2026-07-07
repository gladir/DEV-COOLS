; test01_hello.asm - Test 1 : afficher une chaine sur la console
; Style bas niveau (sans INVOKE) : GetStdHandle, WriteFile, ExitProcess.
; Assembler : ML test01_hello.asm  (produit test01_hello.exe)

.386
.MODEL FLAT

EXTERN GetStdHandle:PROC
EXTERN WriteFile:PROC
EXTERN ExitProcess:PROC

.DATA
msg     DB 'Bonjour depuis ML.PAS !', 13, 10, 0
msglen  DD 25
written DD 0

.CODE
start:
        PUSH -11                ; STD_OUTPUT_HANDLE
        CALL GetStdHandle
        MOV EBX, EAX            ; EBX = handle console

        PUSH 0
        PUSH OFFSET written
        PUSH msglen
        PUSH OFFSET msg
        PUSH EBX
        CALL WriteFile

        PUSH 0
        CALL ExitProcess

END start
