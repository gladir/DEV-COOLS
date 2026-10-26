PROCEDURE usage
(* PRINT USING, DATA/READ et gestion d'erreur *)
DIM i:INTEGER
DIM x,r:REAL
DIM s:STRING[10]
DATA 10,"abc",2.5
READ i,s,x
PRINT USING "i6,s6,r8.2",i,s,x
ON ERROR GOTO 900
r=1/(i-10)
PRINT "inatteignable"
END
900 PRINT "erreur interceptee : ";ERR
