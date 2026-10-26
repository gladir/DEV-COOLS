PROCEDURE sieve
(* Crible d'Eratosthene *)
DIM i,j,n,count:INTEGER
DIM flags(2000):BOOLEAN
n=2000
FOR i=1 TO n
flags(i)=TRUE
NEXT i
FOR i=2 TO n
IF flags(i) THEN
count=count+1
FOR j=i+i TO n STEP i
flags(j)=FALSE
NEXT j
ENDIF
NEXT i
PRINT "Nombres premiers jusqu'a ";n;" : ";count
