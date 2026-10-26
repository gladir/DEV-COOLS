PROCEDURE primes
(* Procedure avec parametre : basic09 primes.bas -r "primes(50)" *)
PARAM n:INTEGER
DIM i,j:INTEGER
DIM isp:BOOLEAN
FOR i=2 TO n
isp=TRUE
j=2
WHILE j*j<=i AND isp DO
IF MOD(i,j)=0 THEN
isp=FALSE
ENDIF
j=j+1
ENDWHILE
IF isp THEN
PRINT i;" ";
ENDIF
NEXT i
PRINT
