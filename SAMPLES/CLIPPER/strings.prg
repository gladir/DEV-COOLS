* strings.prg - Exemple Clipper : manipulation de chaines
* Compilation : CLIPPER86 strings.prg

LOCAL cTexte, cMot

* --- Longueur ---
cTexte := "Bonjour le monde"
? "Texte  :", cTexte
? "LEN    :", LEN(cTexte)

* --- Casse ---
? "UPPER  :", UPPER(cTexte)
? "LOWER  :", LOWER(cTexte)

* --- Extraction ---
? "LEFT(8)   :", LEFT(cTexte, 8)
? "RIGHT(5)  :", RIGHT(cTexte, 5)
? "SUBSTR(9) :", SUBSTR(cTexte, 9, 2)

* --- Recherche ---
cMot := "le"
? "AT('le')  :", AT(cMot, cTexte)
? "RAT('o')  :", RAT("o", cTexte)

* --- Espaces ---
LOCAL cPad
cPad := "  Hello  "
? "TRIM      :", TRIM(cPad)
? "LTRIM     :", LTRIM(cPad)
? "ALLTRIM   :", ALLTRIM(cPad)

* --- Remplissage ---
? "PADR(AB,8):", PADR("AB", 8)
?? "."
? "PADL(AB,8):", PADL("AB", 8)
?? "."
? "PADC(AB,8):", PADC("AB", 8)
?? "."
? "SPACE(5)  :", SPACE(5)
?? "."

* --- Repetition ---
? "REPLICATE :", REPLICATE("*-", 5)

* --- Caracteres ---
? "CHR(65)   :", CHR(65)
? "ASC('A')  :", ASC("A")

* --- Conversion ---
? "STR(1234) :", STR(1234)
? "VAL('567'):", VAL("567")

* --- Remplacement ---
? "STRTRAN   :", STRTRAN("Hello World", "World", "Clipper")
? "STUFF     :", STUFF("abcdef", 3, 2, "XY")

* --- TRANSFORM ---
? "TRANSFORM :", TRANSFORM("test", "@!")

* --- Concatenation ---
LOCAL cPrenom, cNom, cComplet
cPrenom := "Jean"
cNom    := "Dupont"
cComplet := cPrenom + " " + cNom
? "Concat    :", cComplet

* --- EMPTY ---
? "EMPTY('') :", EMPTY("")
? "EMPTY('A'):", EMPTY("A")

? "Fin de strings.prg"
