* math.prg - Exemple Clipper : fonctions, procedures, recursion, RETURN
* Compilation : CLIPPER86 math.prg

* --- Appels de fonctions simples ---
? "Double de 7 :", Dbl(7)
? "Triple de 4 :", Triple(4)
? "Somme 3+5   :", Add(3, 5)

* --- Fonctions mathematiques integrees ---
? "ABS(-42)    :", ABS(-42)
? "MAX(10, 20) :", MAX(10, 20)
? "MIN(10, 20) :", MIN(10, 20)
? "MOD(17, 5)  :", MOD(17, 5)
? "SQRT(144)   :", SQRT(144)
? "INT(7)      :", INT(7)
? "ROUND(7, 0) :", ROUND(7, 0)

* --- Recursion : factorielle ---
? "Facto(1)  :", Facto(1)
? "Facto(5)  :", Facto(5)
? "Facto(7)  :", Facto(7)

* --- Recursion : Fibonacci ---
? "Fib(1)  :", Fib(1)
? "Fib(5)  :", Fib(5)
? "Fib(10) :", Fib(10)

* --- Procedure sans valeur de retour ---
DO ShowLine WITH 40

* --- Procedure avec calcul ---
LOCAL nResult
nResult := Power(2, 10)
? "2^10 =", nResult

? "Fin de math.prg"
RETURN

* ---- Definitions ----

FUNCTION Dbl(n)
RETURN n * 2

FUNCTION Triple(n)
RETURN n * 3

FUNCTION Add(a, b)
  LOCAL result
  result := a + b
RETURN result

FUNCTION Facto(n)
  IF n <= 1
    RETURN 1
  ENDIF
RETURN n * Facto(n - 1)

FUNCTION Fib(n)
  IF n <= 1
    RETURN n
  ENDIF
RETURN Fib(n - 1) + Fib(n - 2)

FUNCTION Power(base, expo)
  LOCAL result, i
  result := 1
  FOR i := 1 TO expo
    result := result * base
  NEXT
RETURN result

PROCEDURE ShowLine(nLen)
  LOCAL i
  FOR i := 1 TO nLen
    ?? "-"
  NEXT
  ?
RETURN
