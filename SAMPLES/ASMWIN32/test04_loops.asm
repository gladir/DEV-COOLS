; test04_loops.asm - Test 4 : boucles et sauts conditionnels
; Calcule la somme 1+2+...+10 avec une boucle LOOP, puis avec JMP/CMP.

.386
.MODEL FLAT
EXTERN ExitProcess:PROC

.DATA
sum1    DD 0    ; attendu : 55 (boucle LOOP)
sum2    DD 0    ; attendu : 55 (boucle JMP/CMP)

.CODE
start:
        ; --- boucle avec LOOP (ECX = compteur) ---
        MOV ECX, 10
        MOV EAX, 0
        MOV EBX, 1
loop1:
        ADD EAX, EBX
        INC EBX
        LOOP loop1
        MOV sum1, EAX

        ; --- boucle equivalente avec CMP/JLE ---
        MOV EAX, 0
        MOV EBX, 1
loop2:
        CMP EBX, 10
        JG  loop2_done
        ADD EAX, EBX
        INC EBX
        JMP loop2
loop2_done:
        MOV sum2, EAX

        ; code de sortie = 0 si sum1 == sum2 == 55, sinon 1
        MOV EAX, sum1
        CMP EAX, sum2
        JNE fail
        CMP EAX, 55
        JNE fail
        PUSH 0
        CALL ExitProcess
fail:
        PUSH 1
        CALL ExitProcess

END start
