PROCEDURE records
(* Types enregistrement, tableaux et ON...GOSUB *)
TYPE person=name:STRING[10]; age:INTEGER
DIM p:person
DIM team(3):person
DIM i,k:INTEGER
p.name="Bob"
p.age=42
team(2)=p
PRINT team(2).name;" a ";team(2).age;" ans"
k=2
ON k GOSUB 100,200
END
100 PRINT "sous-programme 100"
RETURN
200 PRINT "sous-programme 200"
RETURN
