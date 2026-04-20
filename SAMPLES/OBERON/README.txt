SAMPLES/OBERON - Couverture des mots reserves
==============================================

Ce document inventorie les mots reserves Oberon et leur etat de
prise en charge dans le compilateur minimal OBERCW32 (cible PE32
Windows, testee sous Wine).

Mots reserves - prise en charge complete
-----------------------------------------

Les mots suivants sont reconnus par le lexer et pleinement traites
par le generateur de code ; les exemples cites les exercent.

  BEGIN ...... demarrage du corps du MODULE ou d'un bloc imbrique
               (tous les exemples)
  CONST ...... section de constantes (keywords.obn)
  DIV ........ division entiere (arith.obn, gcd.obn, keywords.obn)
  ELSE ....... branche par defaut de IF / CASE
               (calendar.obn, case.obn, keywords.obn)
  END ........ fin de MODULE / IF / WHILE / FOR / CASE / LOOP
               (tous les exemples)
  IF ......... branchement conditionnel (calendar.obn, keywords.obn)
  IMPORT ..... importation de modules (tous les exemples)
  MODULE ..... en-tete du programme (tous les exemples)
  NIL ........ pointeur nul (reconnu ; usage limite)
  OR ......... accepte par le lexer (usage simple)
  RETURN ..... reconnu (procedures elles-memes sont encore ignorees)
  THEN ....... clause IF (keywords.obn, calendar.obn)
  TO ......... borne de FOR (keywords.obn, factorial.obn, primes.obn)
  UNTIL ...... clause de REPEAT (keywords.obn)
  VAR ........ declarations de variables (tous les exemples)
  WHILE ...... boucle tant-que (keywords.obn, digits.obn, sqrt.obn)
  FOR ........ boucle comptee
  REPEAT ..... boucle a post-condition (keywords.obn)

Mots reserves - ajoutes dans cette iteration
---------------------------------------------

  CASE ....... expression entiere + alternatives, separees par '|',
               avec ELSE optionnel.  Voir SAMPLES/OBERON/case.obn.
  LOOP ....... boucle infinie.  Voir SAMPLES/OBERON/loopexit.obn.
  EXIT ....... sortie du LOOP le plus interne.
               Voir SAMPLES/OBERON/loopexit.obn.

Mots reserves - reconnus syntaxiquement, semantique limitee
------------------------------------------------------------

Les sections TYPE et VAR acceptent ces mots dans les specifications
de types mais le compilateur minimal ne genere pas de code pour
l'indexation de tableaux, l'acces aux champs ni la dereference de
pointeurs.  Ces mots sont donc reconnus par le lexer et tolerer dans
les declarations, mais leur emploi au niveau des instructions n'est
pas encore supporte :

  ARRAY   POINTER   RECORD   WITH   IN   OF

Exemple d'emploi syntaxique accepte (sans effet runtime) :

  TYPE
    Vect  = ARRAY 10 OF INTEGER;
    Point = RECORD x, y : INTEGER END;
    PtrI  = POINTER TO INTEGER;

Verification
------------

La compilation a ete verifiee en executant sous Wine les binaires
PE32 produits par :

  ./BINLINUX/OBERCW32 SAMPLES/OBERON/<nom>.obn -o /tmp/<nom>.exe

pour les 18 exemples (arith, calendar, case, collatz, digits,
factorial, fib, gcd, hello, keywords, loopexit, loops, mersenne,
power, primes, primes200, pythagore, sqrt).  Tous produisent les
resultats attendus sans erreur.
