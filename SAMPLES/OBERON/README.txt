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

pour les 20 exemples (arith, builtins, calendar, case, collatz,
digits, factorial, fib, gcd, halt, hello, keywords, loopexit,
loops, mersenne, power, primes, primes200, pythagore, sqrt).
Tous produisent les resultats attendus sans erreur.

Procedures built-in
-------------------

Pleinement supportees (voir SAMPLES/OBERON/builtins.obn et halt.obn) :

  ABS(x)      Valeur absolue d'une expression entiere.
  ODD(x)      Retourne 1 si x est impair, 0 sinon.
  CHR(n)      Retourne le caractere de code n (identite 32 bits).
  ORD(c)      Retourne le code entier de c (identite 32 bits).
  CAP(c)      Convertit 'a'..'z' en 'A'..'Z', sinon inchange.
  ASH(x, n)   Decalage binaire arithmetique (n constante litterale).
              n > 0 : decalage vers la gauche ; n < 0 : vers la droite.
  MAX(T)      Plus grande valeur du type T (INTEGER/CHAR/BOOLEAN).
  MIN(T)      Plus petite valeur du type T.
  SIZE(T)     Taille en octets du type T (INTEGER=4, CHAR=1, BOOLEAN=1).
  INC(v)      Incremente v de 1.
  INC(v, n)   Incremente v de n (n constante entiere).
  DEC(v)      Decremente v de 1.
  DEC(v, n)   Decremente v de n (n constante entiere).
  HALT(n)     Termine le programme avec le code de sortie n.

Non supportees par ce compilateur minimal (requierent des types
que le compilateur ne gere pas encore) :

  COPY        Copie d'une chaine dans un tableau (requiert ARRAY).
  ENTIER      Partie entiere d'un reel (requiert REAL).
  EXCL(s, x)  Retire x de l'ensemble s (requiert SET).
  INCL(s, x)  Ajoute x a l'ensemble s (requiert SET).
  LEN(a)      Longueur d'un tableau ou d'une chaine (requiert ARRAY).
  MOVE        Copie memoire (non implemente).
  NEW(p)      Allocation dynamique (requiert POINTER).

