* hello.prg - Exemple Clipper : sorties, variables, constantes, types
* Compilation : CLIPPER86 hello.prg

* --- Affichage simple avec ? ---
? "Hello, World!"
?

* --- Affichage avec ?? (sans saut de ligne) ---
?? "Bonjour "
?? "depuis Clipper86"
?

* --- Variables locales et types ---
LOCAL cNom, nAge, lActif, dDate

cNom   := "Jean Dupont"
nAge   := 35
lActif := .T.
dDate  := DATE()

? "Nom   :", cNom
? "Age   :", nAge
? "Actif :", lActif
? "Date  :", dDate

* --- Constantes numeriques ---
LOCAL nPi, nMax
nPi  := 314
nMax := 32767

? "Pi (x100) :", nPi
? "Max int   :", nMax

* --- Variables STATIC et PUBLIC ---
STATIC sCompteur := 0
PUBLIC gVersion  := 1

sCompteur := sCompteur + 1
? "Compteur statique :", sCompteur
? "Version globale   :", gVersion

* --- STORE multi-variable ---
LOCAL a, b, c
STORE 42 TO a, b, c
? "a =", a
? "b =", b
? "c =", c

* --- Affectations composees ---
a += 10
b -= 5
c *= 2
? "a += 10 :", a
? "b -= 5  :", b
? "c *= 2  :", c

* --- Types de valeurs ---
? "Type de cNom  :", TYPE("cNom")
? "Type de nAge  :", TYPE("nAge")
? "Type de lActif:", TYPE("lActif")

? "Fin de hello.prg"
