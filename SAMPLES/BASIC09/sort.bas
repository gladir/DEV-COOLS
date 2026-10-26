PROCEDURE sort
(* Tri a bulles d'un tableau *)
DIM a(10):INTEGER
DIM i,j,t:INTEGER
FOR i=1 TO 10
a(i)=MOD(i*7,11)
NEXT i
FOR i=1 TO 9
FOR j=1 TO 10-i
IF a(j)>a(j+1) THEN
t=a(j)
a(j)=a(j+1)
a(j+1)=t
ENDIF
NEXT j
NEXT i
FOR i=1 TO 10
PRINT a(i);" ";
NEXT i
PRINT
