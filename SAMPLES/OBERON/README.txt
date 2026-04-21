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


Modules Oberon "built-in"
=========================

Palier 1 (implementes) : les modules qui ne requierent ni type
composite (ARRAY, RECORD, POINTER) ni arithmetique flottante ; voir
les exemples mod_*.obn livres dans ce repertoire.

  Out        (mod_out.obn)
    String(s)     deja supporte : ecrit une chaine sur stdout
    Int(n, w)     deja supporte : ecrit n en decimal (w ignore)
    Ln            deja supporte : ecrit CR+LF
    Char(n)       NOUVEAU : ecrit un caractere (code ASCII) sur stdout
    Hex(n)        NOUVEAU : ecrit n en hexa 8 chiffres majuscules

  Bit        (mod_bit.obn)
    And(a,b)      a AND b bit-a-bit
    Or(a,b)       a OR b bit-a-bit
    Xor(a,b)      a XOR b bit-a-bit
    Not(a)        complement binaire (NOT a)
    Shl(a,n)      decalage logique vers la gauche de n bits
    Shr(a,n)      decalage logique vers la droite de n bits
    Test(a,bit)   1 si le bit numero "bit" de a est a 1, sinon 0
    Set(a,bit)    retourne a OR (1 SHL bit)
    Clear(a,bit)  retourne a AND NOT (1 SHL bit)

  Timer      (mod_timer.obn)
    Time()        ms ecoules depuis le demarrage (Win32 GetTickCount)
    Sleep(ms)     pause bloquante en millisecondes (Win32 Sleep)

  Err        (mod_err.obn)
    String(s)     ecrit une chaine sur stderr
    Int(n)        ecrit n en decimal sur stderr
    Ln            ecrit CR+LF sur stderr

  Args       (mod_args.obn)
    Count()       nombre d'arguments de la ligne de commande
                  (simple comptage de mots separes par des blancs,
                  sans gestion des guillemets).
                  Get(i, s) non supporte : requiert ARRAY OF CHAR.

  Random     (mod_random.obn)
    Init(seed)    fixe la graine (seed = INTEGER)
    Int(bound)    prochaine valeur entiere >= 0 et < bound
                  (generateur LCG "Numerical Recipes" 32 bits).
                  Real() non supporte : requiert REAL.

  SYSTEM     (mod_system.obn)
    VAL(T, x)     conversion de representation, identite en 32 bits
    ADR(v)        adresse memoire de la variable v
    GET(addr, v)  lit mem[addr] dans v (instruction) ou expression
    PUT(addr, x)  ecrit x a l'adresse addr (instruction)
                  Autres procedures SYSTEM.* hors perimetre.


Modules Oberon "built-in" - hors perimetre de l'iteration courante
===================================================================

Les modules suivants sont mentionnes par les librairies Oberon de
reference (Oakwood, ETH) mais ne sont pas implementes ici ; chacun
requiert une evolution majeure du compilateur.

  Strings, Conv   (Palier 2) requierent ARRAY OF CHAR + parametres VAR
                  + les built-ins COPY / LEN.
  Math, MathL     (Palier 3) requierent le type REAL (32 bits) ou
                  LONGREAL (64 bits) et un generateur x87 FPU.
                  Random.Real depend aussi du Palier 3.
  Files, GC,      (Palier 4) requierent POINTER, NEW, ainsi qu'un
  DynLink         runtime minimal (tas HeapAlloc/VirtualAlloc, tables
                  de chargement dynamique LoadLibraryA/GetProcAddress).
  Coroutines      (Palier 5) requierent un mecanisme de changement de
                  contexte (CreateFiber/SwitchToFiber ou switcher maison)
                  et une allocation de piles dediees.
  In              Les formes VAR (In.Int(VAR n)) dependent des parametres
                  VAR et donc du Palier 2 (voir Strings). Une future
                  implementation lira stdin via ReadFile.

Ces modules sont documentes ici afin que leur absence soit claire
pour l'utilisateur et que l'ordre des paliers soit trace.
