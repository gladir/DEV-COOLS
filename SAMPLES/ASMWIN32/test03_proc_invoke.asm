; test03_proc_invoke.asm - Test 3 : PROC/ENDP haut niveau + INVOKE
; Parametres nommes (arg1:DWORD, arg2:DWORD), variable LOCAL, USES.

.386
.MODEL FLAT
EXTERN ExitProcess:PROC

.CODE

; Max(a,b) : retourne le plus grand des deux arguments dans EAX
; NOTE : pas de RET explicite avant ENDP - avec un PROC haut niveau,
; ENDP genere lui-meme l epilogue complet (restauration USES, ESP/EBP,
; RET n correct pour STDCALL) ; un RET ecrit a la main court-circuiterait
; cet epilogue et desequilibrerait la pile (vrai aussi avec un ML.EXE reel).
Max PROC USES EBX a:DWORD, b:DWORD
        LOCAL tmp:DWORD
        MOV EBX, a
        MOV tmp, EBX
        MOV EAX, b
        CMP EAX, tmp
        JLE useA
        JMP done
useA:
        MOV EAX, tmp
done:
Max ENDP

; Sum3(a,b,c) : additionne trois entiers
Sum3 PROC a:DWORD, b:DWORD, c:DWORD
        MOV EAX, a
        ADD EAX, b
        ADD EAX, c
Sum3 ENDP

start:
        INVOKE Max, 10, 42          ; EAX = 42
        INVOKE Sum3, 1, 2, 3        ; EAX = 6
        ; code de sortie = Sum3(1,2,3) = 6
        INVOKE ExitProcess, EAX

END start
