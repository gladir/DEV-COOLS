PROCEDURE fibonac
(* Appel de procedure avec parametres (passage par reference) *)
DIM n:INTEGER
DIM r:REAL
FOR n=1 TO 20 STEP 5
RUN fib(n,r)
PRINT "fib(";n;") = ";r
NEXT n

PROCEDURE fib
PARAM n:INTEGER
PARAM r:REAL
DIM a,b:REAL
IF n<2 THEN
r=n
ELSE
RUN fib(n-1,a)
RUN fib(n-2,b)
r=a+b
ENDIF
