*
* test_procs.prg - Test procedures et fonctions (TODO 17)
*

* --- Test 1 : FUNCTION simple avec RETURN ---
? "Test 1: FUNCTION simple"
LOCAL x
x := Dbl(5)
? x

* --- Test 2 : PROCEDURE simple ---
? "Test 2: PROCEDURE simple"
DO Hello

* --- Test 3 : FUNCTION avec LOCAL ---
? "Test 3: FUNCTION avec LOCAL"
? Add(3, 7)

* --- Test 4 : Appel direct de fonction ---
? "Test 4: Appel direct"
? Triple(4)

* --- Test 5 : FUNCTION recursive ---
? "Test 5: Factorielle"
? Facto(5)

* --- Test 6 : DO procname WITH args ---
? "Test 6: DO WITH"
DO ShowVal WITH 42

* --- Test 7 : PROCEDURE avec PARAMETERS ---
? "Test 7: PROCEDURE PARAMETERS"
DO Greet WITH 99

* --- Test 8 : RETURN sans expression dans FUNCTION retourne NIL ---
? "Test 8: Fin"

RETURN

* ---- Definitions des fonctions et procedures ----

FUNCTION Dbl(n)
RETURN n * 2

PROCEDURE Hello()
  ? "Hello World"
RETURN

FUNCTION Add(a, b)
  LOCAL result
  result := a + b
RETURN result

FUNCTION Triple(n)
RETURN n * 3

FUNCTION Facto(n)
  IF n <= 1
    RETURN 1
  ENDIF
RETURN n * Facto(n - 1)

PROCEDURE ShowVal(v)
  ? "Value:", v
RETURN

PROCEDURE Greet(x)
  PARAMETERS dummy
  ? "Greet:", x
RETURN
