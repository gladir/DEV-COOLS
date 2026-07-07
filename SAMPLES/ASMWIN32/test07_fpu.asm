; test07_fpu.asm - Test 7 : arithmetique flottante x87 (FLD/FADD/FMUL/FISTP)
; Calcule (3.5 + 1.5) * 2.0 = 10.0, convertit en entier, l'utilise
; comme code de sortie pour verification rapide.

.386
.MODEL FLAT
EXTERN ExitProcess:PROC

.DATA
a       DQ 3.5
b       DQ 1.5
c       DQ 2.0
result  DD 0

.CODE
start:
        ; NOTE : ML.PAS ne suit pas le type declare d'un symbole (DQ vs DD)
        ; pour deviner automatiquement la taille d'un operande memoire sans
        ; PTR explicite - toujours preciser QWORD PTR pour un double x87
        ; (sinon FLD/FADD/FMUL liraient a tort 4 octets = simple precision).
        FLD QWORD PTR a           ; ST(0) = 3.5
        FADD QWORD PTR b         ; ST(0) = 3.5 + 1.5 = 5.0
        FMUL QWORD PTR c         ; ST(0) = 5.0 * 2.0 = 10.0
        FISTP result             ; result (DD) = 10, depile ST(0)

        PUSH result
        CALL ExitProcess

END start
