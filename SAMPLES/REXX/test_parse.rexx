/* test_parse.rexx - Test de l'instruction PARSE (TODO 16) */

/* PARSE VAR - decoupage par mots */
line = "hello world REXX"
parse var line w1 w2 w3
say w1
say w2
say w3

/* PARSE VAR - dernier mot prend le reste */
data = "one two three four five"
parse var data a b rest
say a
say b
say rest

/* PARSE VAR - avec delimiteur litteral */
csv = "apple,banana,cherry"
parse var csv f1 ',' f2 ',' f3
say f1
say f2
say f3

/* PARSE VAR - avec position absolue */
fixed = "ABCDEFGHIJ"
parse var fixed p1 4 p2 7 p3
say p1
say p2
say p3

/* PARSE VAR - avec point (throwaway) */
info = "skip1 keep1 skip2 keep2"
parse var info . w1 . w2
say w1
say w2

/* PARSE UPPER VAR - conversion majuscules */
mixed = "Hello World"
parse upper var mixed u1 u2
say u1
say u2

/* PARSE VERSION */
parse version ver
say ver

/* PARSE SOURCE */
parse source src
say src
