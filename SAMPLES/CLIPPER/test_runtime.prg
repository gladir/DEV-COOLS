* test_runtime.prg - Test du runtime minimal (TODO 24)

* Test des fonctions deja existantes via le runtime consolide
LOCAL nVal, cStr, nRes

* Test expression basique
nVal := 42
? "nVal =", nVal

* Test concatenation de chaines
cStr := "Hello"
? "String:", cStr

* Test operations arithmetiques
nRes := nVal + 8
? "42 + 8 =", nRes

nRes := nVal * 2
? "42 * 2 =", nRes

* Test ABS (builtin)
nVal := -15
nRes := ABS(nVal)
? "ABS(-15) =", nRes

* Test MAX et MIN
nRes := MAX(10, 25)
? "MAX(10,25) =", nRes

nRes := MIN(10, 25)
? "MIN(10,25) =", nRes

* Test STR et VAL (conversion)
cStr := STR(123)
? "STR(123) =", cStr

nRes := VAL("456")
? "VAL(456) =", nRes

* Test SQRT
nRes := SQRT(100)
? "SQRT(100) =", nRes

* Test LEN
nRes := LEN("Hello")
? "LEN(Hello) =", nRes

* Test UPPER et LOWER
cStr := UPPER("hello")
? "UPPER(hello) =", cStr

cStr := LOWER("HELLO")
? "LOWER(HELLO) =", cStr

* Test SUBSTR
cStr := SUBSTR("Hello World", 1, 5)
? "SUBSTR(Hello World,1,5) =", cStr

* Test EMPTY
? "EMPTY(0) =", EMPTY(0)

* Test systeme
? "MAXROW() =", MAXROW()
? "MAXCOL() =", MAXCOL()

? "Runtime minimal OK"
