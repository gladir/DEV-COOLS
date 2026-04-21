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
  ENTIER      Partie entiere d'un reel : non encore implemente comme
              built-in, meme si le type REAL existe (Palier 3).  Le
              code genere pour fistp existe (voir Out.Real) mais la
              procedure n'est pas encore exposee au langage.
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
                  (respecte les guillemets "..").
    Get(i, s)     copie le i-eme argument (i>=0) dans s :
                  i = 0 donne le nom du programme.

  Random     (mod_random.obn, mod_random_real.obn)
    Init(seed)    fixe la graine (seed = INTEGER)
    Int(bound)    prochaine valeur entiere >= 0 et < bound
                  (generateur LCG "Numerical Recipes" 32 bits).
    Real()        Palier 3 : prochaine valeur REAL dans [0, 1)
                  derivee du meme LCG.

  SYSTEM     (mod_system.obn)
    VAL(T, x)     conversion de representation, identite en 32 bits
    ADR(v)        adresse memoire de la variable v
    GET(addr, v)  lit mem[addr] dans v (instruction) ou expression
    PUT(addr, x)  ecrit x a l'adresse addr (instruction)
                  Autres procedures SYSTEM.* hors perimetre.


Palier 2 (implementes) : les modules qui necessitent les parametres
VAR / ARRAY OF CHAR et les built-ins COPY / LEN ; voir les exemples
mod_strings.obn, mod_conv.obn et mod_in.obn.

  Strings    (mod_strings.obn)
    Length(s)               longueur (jusqu'au premier 0X).
    Cap(VAR s)              minuscules -> majuscules en place.
    Append(src, VAR dst)    concatene src a la fin de dst.
    Pos(pat, s, start)      position du motif >= start, -1 sinon.
    Delete(VAR s, pos, n)   supprime n caracteres a partir de pos.
    Insert(src, pos, VAR dst) insere src a la position pos.
    Replace(src, pos, VAR dst) remplace en place a partir de pos
                              sans changer la longueur.

  Conv       (mod_conv.obn)
    IntToString(n, VAR s)      n en decimal signe dans s.
    HexToString(n, VAR s)      n en hexa 8 chiffres majuscules.
    StringToInt(s, VAR n, VAR ok)  parse signe + chiffres ;
                                   ok = 1 si au moins un chiffre lu.

  In         (mod_in.obn)
    In.Done           variable booleenne : 1 si la derniere
                      operation a reussi, 0 sinon.
    Int(VAR n)        lit espaces, signe optionnel, chiffres
                      decimaux.
    Char(VAR c)       lit un caractere depuis stdin (code ASCII).
    Line(VAR s)       lit une ligne dans s (jusqu'au \n ou EOF).
    String(VAR s)     equivalent a Line ici.


Palier 3 (implementes) : type REAL (IEEE 754 simple precision, 32 bits)
et x87 FPU ; voir les exemples mod_math.obn, mod_out_real.obn et
mod_random_real.obn.

  Type REAL
    * Litteraux decimaux (3.14, 0.5, 1.5E-2) reconnus par le lexeur et
      stockes dans le pool de constantes REAL.
    * Declarations VAR r : REAL (LONGREAL est accepte comme alias
      simple precision dans cette iteration).
    * Expressions : +, -, *, /, negation unaire, parentheses.
      Les valeurs intermediaires circulent sur la pile x87 (st(0)).
    * Conversion implicite : un litteral ou une variable INTEGER dans
      un contexte REAL est automatiquement promu (fild).
    * Assignation r := expr emet fstp dword [r].

  Math       (mod_math.obn)
    Math.Pi                  constante pi (chargee par fldpi).
    Math.Sqrt(r)             racine carree (fsqrt).
    Math.Abs(r)              valeur absolue (fabs).
    Math.Sin(r)              sinus (fsin).
    Math.Cos(r)              cosinus (fcos).
    Math.Ln(r)               logarithme naturel (fldln2 + fyl2x).
    Math.Exp(r)              exponentielle (fldl2e + sequence
                             frndint/f2xm1/fscale).
    Math.ArcTan(r)           arc tangente (fld1 + fpatan).

  Out.Real   (mod_out_real.obn)
    Out.Real(r)             imprime r au format fixe :
                             signe optionnel + partie entiere + '.' +
                             6 chiffres apres la virgule.
    Out.Real(r, w)          le parametre de largeur w est accepte
                             mais ignore par ce format.

  Random.Real (mod_random_real.obn)
    Random.Real()           tire un REAL uniformement reparti dans
                            [0, 1) via le LCG existant
                            (Random.Init / Random.Int restent valides
                            pour semence et entiers).


Palier 4 (implementes) : E/S fichiers, tas et chargement dynamique via
les API Win32.  Les handles et adresses sont exposes comme INTEGER
(32 bits) ; le type POINTER et la primitive NEW restent hors perimetre
pour ce palier.  Voir les exemples mod_files.obn, mod_heap.obn et
mod_dynlink.obn.

  Files      (mod_files.obn)
    Files.Open(name, mode)  ouvre un fichier via CreateFileA.
                            name = litteral chaine OU ARRAY OF CHAR.
                            mode = litteral entier :
                                   0 = lecture seule (OPEN_EXISTING)
                                   1 = ecriture/creation (CREATE_ALWAYS)
                                   2 = ajout (OPEN_ALWAYS + seek en fin)
                            Retourne un handle INTEGER ou -1 en cas
                            d'echec (INVALID_HANDLE_VALUE).
    Files.Close(h)          ferme le handle (CloseHandle).
    Files.Read(h, buf, n)   lit jusqu'a n octets dans buf (ARRAY OF
                            CHAR).  Retourne le nombre d'octets lus,
                            0 en fin de fichier, -1 en cas d'erreur.
    Files.Write(h, buf, n)  ecrit n octets depuis buf.  Retourne le
                            nombre d'octets ecrits, -1 en cas d'erreur.
    Files.Seek(h, pos)      positionne le pointeur a pos octets depuis
                            le debut (SetFilePointer / FILE_BEGIN).
    Files.Size(h)           retourne la taille du fichier via
                            SetFilePointer(FILE_END) et restaure la
                            position courante.

  Heap       (mod_heap.obn)
    Heap.Alloc(n)           alloue n octets dans le tas du processus
                            avec HEAP_ZERO_MEMORY.  Retourne l'adresse
                            sous forme d'INTEGER (0 si echec).
    Heap.Free(addr)         libere le bloc (HeapFree).
    La manipulation des octets se fait via SYSTEM.GET / SYSTEM.PUT.
    Heap est le substitut minimal de GC/NEW tant que le type POINTER
    n'est pas implemente.

  DynLink    (mod_dynlink.obn)
    DynLink.Load(name)      LoadLibraryA.  Retourne un HMODULE INTEGER
                            (0 si echec).
    DynLink.GetProc(h, nm)  GetProcAddress.  Retourne l'adresse
                            (INTEGER) ou 0 si le nom n'est pas exporte.
    DynLink.Free(h)         FreeLibrary.
    Invoquer reellement l'adresse retournee par GetProc necessitera
    un type PROCEDURE variable (palier ulterieur).


Palier 5 (implementes) : coroutines via les fibers Win32 (voir
l'exemple mod_coroutines.obn).  Les handles sont exposes comme INTEGER.

  Coroutines (mod_coroutines.obn)
    Coroutines.Init()           convertit le thread courant en fiber
                                (ConvertThreadToFiber(NULL)) et
                                retourne le handle du fiber principal.
                                Doit etre appele une fois, avant toute
                                autre primitive.
    Coroutines.Body             renvoie l'adresse d'un helper interne
                                "_coro_body" : un point d'entree
                                generique qui, a chaque reprise,
                                re-yield en appelant SwitchToFiber sur
                                le parametre passe a CreateFiber.
                                Permet de construire des coroutines
                                sans avoir besoin de procedures Oberon
                                definies par l'utilisateur.
    Coroutines.New(entry, param) CreateFiber(64Ko, entry, param).
                                entry   : adresse d'entree (souvent
                                          Coroutines.Body).
                                param   : parametre passe a l'entree
                                          (par convention : handle du
                                          fiber principal a qui rendre
                                          la main).
                                Retourne 0 en cas d'echec.
    Coroutines.Switch(h)        instruction : SwitchToFiber(h).
    Coroutines.Delete(h)        instruction : DeleteFiber(h).

  Sous le capot, le compilateur emet un helper "_coro_body" dans la
  section .text (boucle push ebx ; call [SwitchToFiber] ; jmp loop)
  et un nouveau type de fixup FIX_CODE_ABS qui resout un label de
  code en une adresse absolue (necessaire pour CreateFiber, qui prend
  un pointeur de fonction, par opposition aux appels CALL PC-relatifs
  existants via FIX_CODE_REL).


Modules Oberon "built-in" - hors perimetre de l'iteration courante
===================================================================

Les modules suivants sont mentionnes par les librairies Oberon de
reference (Oakwood, ETH) mais ne sont pas implementes ici ; chacun
requiert une evolution majeure du compilateur.

  MathL           (Palier 3 etendu) requiert le type LONGREAL
                  reellement 64 bits (double precision) et l'emission
                  d'instructions x87 en precision double ; dans cette
                  iteration LONGREAL est un simple alias de REAL.
  GC, NEW,        (Palier 4 etendu) requierent le type POINTER et un
  POINTER         allocateur type-safe avec metadonnees.  Le module
                  Heap du Palier 4 fournit deja HeapAlloc/HeapFree
                  bruts, a utiliser avec SYSTEM.GET / SYSTEM.PUT.
  PROCEDURE       Les procedures Oberon definies par l'utilisateur
                  ne sont pas encore supportees.  Tant que ce n'est
                  pas le cas, les coroutines du Palier 5 doivent
                  utiliser Coroutines.Body ou une adresse externe
                  obtenue via DynLink.GetProc comme point d'entree.

Ces modules sont documentes ici afin que leur absence soit claire
pour l'utilisateur et que l'ordre des paliers soit trace.
