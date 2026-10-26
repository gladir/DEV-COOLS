PROCEDURE fileio
(* Fichiers texte : CREATE, WRITE, OPEN, READ, EOF, DELETE *)
DIM path:BYTE
DIM s:STRING[40]
CREATE #path,"demo.txt":WRITE
PRINT #path,"premiere ligne"
PRINT #path,"seconde ligne"
CLOSE #path
OPEN #path,"demo.txt":READ
WHILE NOT(EOF(#path)) DO
INPUT #path,s
PRINT "[";s;"]"
ENDWHILE
CLOSE #path
DELETE "demo.txt"
