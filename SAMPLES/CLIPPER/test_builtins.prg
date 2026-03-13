* test_builtins.prg - Test des fonctions integrees (TODO 23)

* Fonctions numeriques
LOCAL nVal, nMax, nMin, nMod, nAbs, nSqrt

nVal := -42
nAbs := ABS(nVal)
? "ABS(-42) =", nAbs

nMax := MAX(10, 25)
? "MAX(10,25) =", nMax

nMin := MIN(10, 25)
? "MIN(10,25) =", nMin

nMod := MOD(17, 5)
? "MOD(17,5) =", nMod

nSqrt := SQRT(144)
? "SQRT(144) =", nSqrt

nVal := INT(42)
? "INT(42) =", nVal

nVal := ROUND(42, 0)
? "ROUND(42,0) =", nVal

* Fonctions systeme
? "MAXROW() =", MAXROW()
? "MAXCOL() =", MAXCOL()
? "OS() =", OS()
? "SECONDS() =", SECONDS()
? "TIME() =", TIME()

* Fonctions de type
? "EMPTY(0) =", EMPTY(0)
? "EMPTY(1) =", EMPTY(1)

* Fonctions de date
LOCAL dToday
dToday := DATE()
? "DATE() =", dToday
? "DAY(date) =", DAY(dToday)
? "MONTH(date) =", MONTH(dToday)
? "YEAR(date) =", YEAR(dToday)
? "DTOC(date) =", DTOC(dToday)
? "DTOS(date) =", DTOS(dToday)
? "CDOW(date) =", CDOW(dToday)
? "CMONTH(date) =", CMONTH(dToday)

RETURN
