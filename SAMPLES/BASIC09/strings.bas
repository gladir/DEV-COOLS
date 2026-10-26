PROCEDURE strings
(* Fonctions de chaines *)
DIM s,t:STRING[40]
s="Hello"
t=s+" World"
PRINT t
PRINT LEN(t),LEFT$(t,3),RIGHT$(t,3),MID$(t,2,3)
PRINT CHR$(65),ASC("a"),STR$(12.5),VAL("42")+1
PRINT SUBSTR("ll",t),SUBSTR("zz",t)
PRINT TRIM$("abc   ");"|"
