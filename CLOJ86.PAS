{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Clojure vers assembleur 8086
}

(* ============================================================
  CLOJ86.PAS - Compilateur Clojure vers assembleur 8086
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .MODEL SMALL, DOS 16 bits

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings)
            ParseArgs : analyser argv (source.clj [sortie.asm] [-v] [-d] [-w])
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .clj (source Clojure)
            Programme principal : validation des arguments et appel Run
            Version, Date, aide en ligne (option -h)

  TODO 02 - LECTEUR / TOKENISEUR (READER) [IMPLEMENTE]
            TTokenKind : TK_EOF, TK_INTEGER, TK_STRING, TK_SYMBOL,
              TK_KEYWORD, TK_LPAREN, TK_RPAREN, TK_LBRACKET, TK_RBRACKET,
              TK_LBRACE, TK_RBRACE, TK_QUOTE, TK_DEREF, TK_META,
              TK_SYNTAX_QUOTE, TK_UNQUOTE, TK_UNQUOTE_SPLICE,
              TK_DISPATCH, TK_TRUE, TK_FALSE, TK_NIL, TK_CHAR
            LexInit, LexClose, LexNextToken, LexScanSymbol, LexScanNumber
            LexScanString : chaine entre guillemets doubles "abc"
              Sequences d echappement : \n \t \r \\ \" \newline
            LexScanKeyword : :mot-cle ou ::mot-cle-qualifie
            Commentaires : ; jusqu a fin de ligne
              #_ ignore la forme suivante (comment macro)
              (comment ...) forme speciale ignoree
            Mode debug -d : affichage de chaque token avec PrintToken

  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
            Entiers decimaux : 0..65535 (positifs) ou -32768..32767 (signes)
            Entiers hexadecimaux : 0xFF -> reconnaissance et conversion
            Entiers octaux : 0377 -> reconnaissance et conversion
            Chaines : "abc" -> pointeur vers donnees DATA
              Concatenation via (str a b c) -> appel runtime
            nil : valeur nulle -> AX=0
            true : valeur booleenne vraie -> AX=1
            false : valeur booleenne fausse -> AX=0
            Caracteres : \a \b \newline \space \tab -> code ASCII
            Mots-cles (keywords) : :nom -> entier unique dans une table
            Ratios et BigDecimal : avertissement + troncature entiere

  TODO 04 - READER MACROS ET FORMES SPECIALES DE LECTURE [IMPLEMENTE]
            Quote : 'expr -> (quote expr)
            Syntax-quote : `expr -> (quasiquote expr)
            Unquote : ~expr -> (unquote expr)
            Unquote-splice : ~@expr -> (unquote-splice expr)
            Deref : @expr -> (deref expr)
            Metadata : ^{...} ou ^:tag -> annotation (ignoree a la compilation)
            Dispatch : #"regex" (avertissement, non supporte)
              #{} -> ensemble litteral (hash-set)
              #(...) -> fonction anonyme courte #(% %2 %&)
              #' -> var quote
            Lecture de listes : (a b c) -> liste chainee
            Lecture de vecteurs : [a b c] -> vecteur
            Lecture de maps : {:a 1 :b 2} -> table de hachage
            Lecture d ensembles : #{1 2 3} -> ensemble

  TODO 05 - TABLE DES SYMBOLES ET ENVIRONNEMENTS [IMPLEMENTE]
            TSymKind : SK_VAR, SK_FN, SK_MACRO, SK_SPECIAL, SK_LOCAL,
              SK_KEYWORD, SK_NS
            TSymRec : Name, MangledName, Kind, TypeTag, Offset,
              ScopeLevel, IsConst, Namespace
            SymNameClean : nettoyer les caracteres non-MASM (tirets etc.)
            SymMangle : prefixer selon Kind (SK_VAR->_CLV_, SK_FN->_CLF_,
              SK_MACRO->_CLV_, SK_LOCAL->_CLV_, SK_NS->_CLV_)
            SymFind : recherche MRU (du plus recent au plus ancien)
            SymFindInScope : recherche dans un niveau de portee specifique
            SymAdd : ajout (debug trace en -d, Namespace, DeclLine)
            CurScope : compteur de portee imbriquee (let, fn, loop)
            SymEnterScope / SymLeaveScope : gestion des portees imbriquees
            IsSpecialForm : detecte def/defn/defmacro/fn/let/if/do/
              when/cond/case/recur/loop/quote/var/try/catch/finally/
              throw/new/set!/monitor-enter/monitor-exit
            SymInit : enregistre les formes speciales + symboles predefinis
              def, defn, defmacro, fn, let, if, do, when, cond, case,
              recur, loop, quote, var, try, catch, finally, throw,
              new, set!, nil, true, false, not, and, or, println,
              print, pr, prn, str, +, -, mod, rem, inc, dec,
              =, <, >, <=, >=, ==, not=, cons, first, rest, list,
              vector, hash-map, hash-set, get, assoc, dissoc, conj,
              count, nth, seq, empty?, nil?, zero?, pos?, neg?,
              even?, odd?, apply, map, filter, reduce, atom, deref,
              reset!, swap!, compare-and-set!

  TODO 06 - SYSTEME DE TYPES INTERNES (TAGS) [IMPLEMENTE]
            Tags de valeurs Clojure (3 bits hauts d un Word) :
              TAG_NIL (0), TAG_TRUE (1), TAG_FALSE (2),
              TAG_INT (3), TAG_SYM (4), TAG_KW (5),
              TAG_CONS (6), TAG_VEC (7), TAG_MAP (8),
              TAG_SET (9), TAG_STR (10), TAG_FN (11), TAG_ATOM (12)
            Encodage compact : tag sur 4 bits + payload sur 12 bits
              ou tag dans un champ separe pour les objets heap
            TypeTab, TypeInit : enregistrer les 12 types primitifs
            TypeKindOf : retourner le TTypeKind d un indice de type
            TypeSizeof : taille en octets (2 en 16-bit pour tous)
            TypeMangle : prefixe ASM selon le tag (_CLI_/_CLS_/_CLB_ etc.)
            TypeIsNumeric : int et char sont numeriques
            TypeIsPtr : string/list/vector/map/set/function
            TypeIsTruthy : nil et false faux, tout le reste vrai
            TypeCanCoerce : coercitions dynamiques Clojure
            TypeCoerceResult : type resultat d une operation
            TypeInfer : deduction de type depuis TExprVal
            TypeLookupName : recherche par nom dans TypeTab

  TODO 07 - EMETTEUR DE CODE ASM [IMPLEMENTE]
            TEmitter : OutF (Text), OutFOpen, EmitOpen, EmitClose
            EmitRaw, EmitLabel, EmitInstr (formatage 8 espaces)
            EmitComment, EmitBlankLine
            LabelGen global (compteur unique _CL_NNNNN)
            Prefixes : _CLV_ (variable), _CLF_ (fonction), _CLK_ (chaine const),
              _CLRT_ (runtime), _CL_ (label), _CLKW_ (keyword),
              _CLVEC_ (vecteur data), _CLMAP_ (map data)
            EmitHeader : .MODEL SMALL / .STACK 1024 / _TEXT SEGMENT
            EmitProlog / EmitEpilog : PUSH BP / MOV BP,SP et MOV SP,BP / POP BP
            EmitDataSeg : ecrire _DATA SEGMENT ... _DATA ENDS

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES [IMPLEMENTE]
            TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR/DK_LIST/DK_VEC/DK_MAP),
              IntVal, StrVal, ElemCount
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr, DataAddList, DataAddVec : variantes d ajout
            Variables globales (def) : entrees DK_WORD dans DATA
            Chaines litterales : DB 'abc',0 dans DATA avec label _CLK_N
            Keywords : table globale des mots-cles, chaque :kw -> index unique
            Vecteurs litteraux : blocs contigus DW dans DATA
            Maps litterales : paires cle/valeur DW dans DATA

  TODO 09 - VARIABLES GLOBALES (def / defonce) [IMPLEMENTE]
            (def nom valeur) : declarer une variable globale
              Emission : calcul de valeur -> MOV [_CLV_nom], AX
            (def nom) : declaration sans valeur initiale -> nil
            (defonce nom valeur) : comme def mais n ecrase pas si deja defini
            Metadata sur les vars : ^:dynamic, ^:private (avertissements)
            (def ^:const nom valeur) : constante, inlining a la compilation
            Acces a une variable : MOV AX, [_CLV_nom]
            Pas de redefinition en mode strict (option -w avertissement)

  TODO 10 - EXPRESSIONS PRIMAIRES [IMPLEMENTE]
            ParseForm : dispatcher selon le type de token lu
            Litteraux : nombre, chaine, true, false, nil, keyword, caractere
            Symboles : resolution dans l environnement courant
            Appel de fonction : (f arg1 arg2 ...) -> evaluation args + CALL
            Formes speciales : if, do, let, fn, def, quote, recur, loop, etc.
            Acces a une variable locale : MOV AX, [BP-offset]
            Acces a une variable globale : MOV AX, [_CLV_nom]
            Forme quote : (quote x) -> retourne x sans evaluation
            Forme do : (do expr1 expr2 ... exprN) -> evalue tout, retourne exprN

  TODO 11 - EXPRESSIONS ARITHMETIQUES ET COMPARAISONS [IMPLEMENTE]
            Arithmetique : (+ a b ...) (- a b ...) (* a b ...) (/ a b ...)
              Variadic : (+ a b c) -> a+b puis +c via boucle ou depliage
              ADD/SUB/IMUL/IDIV pour les operations entieres
            (mod a b) -> IDIV, resultat dans DX (reste)
            (inc x) -> ADD AX,1 / (dec x) -> SUB AX,1
            Comparaisons : (= a b) (not= a b) (< a b) (<= a b) (> a b) (>= a b)
              CMP + Jcc pour chaque operateur
              Chaines : CALL _CLRT_STRCMP pour comparaison
            Logique : (and a b ...) -> court-circuit, retourne derniere valeur vraie
              (or a b ...) -> court-circuit, retourne premiere valeur vraie
              (not x) -> si nil ou false alors true, sinon false
            (min a b ...) (max a b ...) -> comparaison iteree

  TODO 12 - ENTREES/SORTIES (println / print / read-line) [IMPLEMENTE]
            (println expr ...) : afficher les arguments separes par espace + CR+LF
              Evaluation de chaque argument, conversion en chaine
              INT 21h AH=40h BX=1 (STDOUT) pour chaque partie
              _CLRT_PRVAL(AX=val) : afficher une valeur selon son tag
            (print expr ...) : comme println sans saut de ligne final
            (newline) : ecriture CR+LF seul
            (read-line) : INT 21h AH=0Ah lecture ligne -> AX=ptr chaine
            (pr-str expr) : convertir en chaine lisible -> AX=ptr
            (str expr ...) : concatener les representations en chaine
              -> CALL _CLRT_TOSTR pour chaque argument + _CLRT_CONCAT
            (flush) : stub (pas de buffering sur DOS)
            *out* / *err* : handles STDOUT (1) et STDERR (2)

  TODO 13 - FORMES SPECIALES : IF / DO / WHEN / COND / CASE [IMPLEMENTE]
            (if test then else?) : ParseIfForm
              Emission : evaluation test, TEST AX,AX / JZ label_else
              Labels : _CL_ELSE_N, _CL_ENDIF_N
              Truthiness : nil et false sont faux, tout le reste est vrai
            (do expr1 expr2 ... exprN) : evaluer sequentiellement
              Retourne la valeur de la derniere expression
            (when test expr ...) : sucre pour (if test (do expr ...) nil)
            (when-not test expr ...) : inverse de when
            (cond test1 expr1 test2 expr2 ... :else exprN) :
              Cascade de if/elsif, :else comme branche par defaut
              Labels : _CL_COND_N, _CL_CEND_N
            (case expr val1 result1 val2 result2 ... default) :
              CMP + JE pour chaque valeur, saut vers resultat
              Labels : _CL_CASE_N, _CL_CASEEND_N
            (if-let [x expr] then else?) : let + test en une forme
            (when-let [x expr] body ...) : let + when en une forme

  TODO 14 - LIAISONS LOCALES : LET [IMPLEMENTE]
            (let [x 1 y 2] body ...) : ParseLetForm
              Chaque liaison cree une variable locale sur la pile
              SUB SP,2 pour chaque liaison, acces [BP-offset]
              Les liaisons sont sequentielles (chaque nom voit les precedents)
              Retourne la valeur de la derniere expression du body
            Portee : les variables let ne sont visibles que dans le body
              SymEnterScope avant les liaisons, SymLeaveScope apres le body
            (let [x 1 y (+ x 1)] ...) : y peut utiliser x
            Nombre variable de liaisons : boucle sur les paires nom/valeur
            Verification : nombre pair d elements dans le vecteur de liaisons
            Shadowing : une liaison peut masquer une variable du scope parent

  TODO 15 - FONCTIONS (defn / fn / apply) [IMPLEMENTE]
            (defn nom [params] body ...) : ParseDefnForm
              Cree un label _CLF_nom, prologue PUSH BP / MOV BP,SP
              Parametres : [BP+4], [BP+6], ... (empiles droite a gauche)
              Corps : evaluer body, resultat dans AX
              Epilogue : MOV SP,BP / POP BP / RET
            (fn [params] body ...) : fonction anonyme (lambda)
              Label genere _CL_FN_N, meme convention d appel
            Appel de fonction : (f a1 a2 ...) ->
              Evaluer a1..aN, PUSH chaque argument, CALL _CLF_f, ADD SP,2*N
            (apply f args) : appel avec liste d arguments
              Depiler la liste args sur la pile, puis CALL
            Arite variable : (defn f [x & rest] ...) ->
              rest = pointeur vers liste des arguments restants
            Fonctions predefinies : +, -, *, /, =, <, >, str, println, etc.
            Closures : acces aux variables du scope parent via lien statique
              Pointeur vers BP du cadre englobant passe en parametre cache

  TODO 16 - BOUCLES : LOOP / RECUR / DOTIMES / DOSEQ [IMPLEMENTE]
            (loop [x init1 y init2] body ...) : ParseLoopForm
              Cree des liaisons locales comme let
              Label _CL_LOOP_N en debut du body
            (recur expr1 expr2 ...) : saut arriere vers loop
              Reevalue les expressions et met a jour les liaisons
              JMP _CL_LOOP_N (doit etre en position de queue)
              Verification : recur uniquement en tail position
            (dotimes [i n] body ...) : boucle de 0 a n-1
              Sucre pour (loop [i 0] (when (< i n) body (recur (inc i))))
              Labels : _CL_DTST_N, _CL_DTEND_N
            (doseq [x coll] body ...) : iteration sur une collection
              Sucre pour (loop [s (seq coll)] (when s body (recur (rest s))))
              Labels : _CL_DQST_N, _CL_DQEND_N
            (while test body ...) : boucle tant que test est vrai (macro)

  TODO 17 - LISTES (cons / first / rest / conj) [IMPLEMENTE]
            Cellule cons : paire (car . cdr) = 2 Words sur le heap
              _CL_HEAP DB 4096 DUP(0), _CL_HEAPTOP DW 0
            (cons x coll) -> CALL _CLRT_CONS(AX=x, BX=coll) -> AX=ptr
            (first lst) -> MOV BX,AX / MOV AX,[BX] (car)
            (rest lst) -> MOV BX,AX / MOV AX,[BX+2] (cdr)
            (list a b c ...) -> appels cons imbriques (cons a (cons b (cons c nil)))
            (conj lst x) -> (cons x lst) (ajout en tete pour les listes)
            (count lst) -> CALL _CLRT_LCOUNT parcours jusqu a nil -> AX
            (nth lst n) -> CALL _CLRT_LNTH parcours n fois rest -> AX
            (empty? coll) -> CMP AX,0 / JZ (test nil)
            (seq coll) -> retourne la collection comme sequence ou nil si vide

  TODO 18 - VECTEURS (vector / nth / assoc / conj) [IMPLEMENTE]
            Representation : bloc contigu en heap [count, e0, e1, ..., eN-1]
              count = nombre d elements (1 Word), chaque element = 1 Word
            (vector a b c) -> CALL _CLRT_VECNEW(CX=count) allouer + remplir
            [a b c] -> litteral vecteur, meme mecanisme
            (nth vec n) -> CALL _CLRT_VECNTH(BX=vec, CX=n) -> AX
              Verification de bornes : CMP n, [BX] / JAE erreur
            (count vec) -> MOV BX,AX / MOV AX,[BX] (premier Word = taille)
            (conj vec x) -> CALL _CLRT_VECCONJ allouer nouveau vecteur + copie + ajout
            (assoc vec n val) -> CALL _CLRT_VECASSOC copie avec remplacement index n
            (subvec vec start end) -> CALL _CLRT_SUBVEC sous-vecteur
            (get vec n) -> comme nth avec retour nil si hors bornes

  TODO 19 - TABLES DE HACHAGE (hash-map / get / assoc / dissoc) [IMPLEMENTE]
            Representation : liste de paires en heap [count, k0, v0, k1, v1, ...]
              count = nombre de paires, chaque paire = 2 Words (cle + valeur)
            (hash-map k1 v1 k2 v2 ...) -> CALL _CLRT_MAPNEW allouer + remplir
            {:k1 v1 :k2 v2} -> litteral map, meme mecanisme
            (get m key) -> CALL _CLRT_MAPGET(BX=map, CX=key) -> AX (nil si absent)
            (get m key default) -> comme get avec valeur par defaut
            (assoc m k v) -> CALL _CLRT_MAPASSOC copie avec ajout/remplacement
            (dissoc m k) -> CALL _CLRT_MAPDISSOC copie sans la cle k
            (contains? m key) -> CALL _CLRT_MAPHAS -> AX=true|false
            (keys m) -> CALL _CLRT_MAPKEYS -> AX=liste des cles
            (vals m) -> CALL _CLRT_MAPVALS -> AX=liste des valeurs
            (merge m1 m2) -> CALL _CLRT_MAPMERGE fusionner deux maps
            (count m) -> MOV BX,AX / MOV AX,[BX] (premier Word = nb paires)

  TODO 20 - ENSEMBLES (hash-set / contains? / conj / disj) [IMPLEMENTE]
            Representation : liste de valeurs en heap [count, e0, e1, ..., eN-1]
              count = nombre d elements (1 Word), chaque element = 1 Word
            (hash-set a b c) -> CALL _CLRT_SETNEW allouer + remplir (sans doublons)
            #{a b c} -> litteral ensemble, meme mecanisme
            (contains? s val) -> CALL _CLRT_SETHAS recherche lineaire -> AX=true|false
            (conj s val) -> CALL _CLRT_SETCONJ copie avec ajout si absent
            (disj s val) -> CALL _CLRT_SETDISJ copie sans l element val
            (count s) -> MOV BX,AX / MOV AX,[BX] (premier Word = taille)
            (union s1 s2) -> CALL _CLRT_SETUNION fusion sans doublons
            (intersection s1 s2) -> CALL _CLRT_SETINTER elements communs
            (difference s1 s2) -> CALL _CLRT_SETDIFF elements de s1 absents de s2

  TODO 21 - DESTRUCTURATION (DESTRUCTURING) [IMPLEMENTE]
            Destructuration sequentielle (vecteur) :
              (let [[a b c] vec] ...) -> nth 0, nth 1, nth 2
              (let [[a b & rest] vec] ...) -> a=nth 0, b=nth 1, rest=drop 2
              (let [[a _ c] vec] ...) -> _ ignore l element
            Destructuration associative (map) :
              (let [{:keys [a b]} m] ...) -> a=(get m :a), b=(get m :b)
              (let [{x :nom y :age} m] ...) -> x=(get m :nom), y=(get m :age)
              (let [{:keys [a] :or {a 0}} m] ...) -> valeur par defaut si absent
            Destructuration dans defn :
              (defn f [[a b] m] ...) -> destructuration des parametres
            Destructuration dans loop :
              (loop [[x & xs] coll] ...) -> liaison destructuree
            Imbrication : destructuration recursive sur structures imbriquees

  TODO 22 - FONCTIONS D ORDRE SUPERIEUR (map / filter / reduce) [IMPLEMENTE]
            (map f coll) -> CALL _CLRT_MAP appliquer f a chaque element
              Resultat : nouvelle liste (cons de chaque (f elem))
            (filter pred coll) -> CALL _CLRT_FILTER garder si (pred elem) vrai
              Resultat : nouvelle liste des elements satisfaisant pred
            (reduce f init coll) -> CALL _CLRT_REDUCE accumuler (f acc elem)
              Boucle : acc = (f acc (first s)), s = (rest s)
            (map f c1 c2) -> application avec deux collections en parallele
            (remove pred coll) -> comme filter avec predicat inverse
            (some pred coll) -> retourne premier (pred elem) vrai ou nil
            (every? pred coll) -> true si (pred elem) vrai pour tous
            (into to from) -> (reduce conj to from) verser from dans to
            (comp f g) -> composition de fonctions (fn [x] (f (g x)))
            (partial f args...) -> application partielle (fn [& more] (apply f args more))
            (constantly x) -> (fn [& _] x)
            (identity x) -> x

  TODO 23 - CHAINES DE CARACTERES (str / subs / count) [IMPLEMENTE]
            (str a b c ...) : concatenation en chaine de tous les arguments
              CALL _CLRT_TOSTR pour chaque argument + _CLRT_CONCAT
            (subs s start) / (subs s start end) : sous-chaine
              CALL _CLRT_SUBS(SI=str, BX=start, CX=end) -> AX=ptr
            (count s) : longueur de la chaine
              CALL _CLRT_STRLEN(SI=str) -> AX
            (get s n) : caractere a l index n -> code ASCII
            (clojure.string/upper-case s) -> CALL _CLRT_STRUPPER
            (clojure.string/lower-case s) -> CALL _CLRT_STRLOWER
            (clojure.string/trim s) -> CALL _CLRT_STRTRIM
            (clojure.string/includes? s sub) -> CALL _CLRT_STRFIND -> AX=true|false
            (clojure.string/replace s match replacement) -> CALL _CLRT_STRREPL
            (clojure.string/split s re) -> avertissement regex non supporte
              Variante simplifiee : split sur un caractere delimiteur
            (clojure.string/join sep coll) -> CALL _CLRT_STRJOIN

  TODO 24 - RUNTIME MINIMAL [IMPLEMENTE]
            _CLRT_PRINT(BX=handle, SI=msg, CX=len) : INT 21h AH=40h
            _CLRT_PRINTLN : _CLRT_PRINT + CR+LF via _CL_CRLF DB 13,10,0
            _CLRT_PRVAL(AX=val) : afficher une valeur selon son tag
            _CLRT_STRLEN(SI=str) : compte octets jusqu a 0 -> AX
            _CLRT_NUMTOSTR(AX=n, DI=buf) : entier signe -> ASCII (itoa)
            _CLRT_STRTONUM(SI=str) : ASCII -> entier -> AX (atoi)
            _CLRT_TOSTR(AX=val) : convertir valeur en chaine selon tag -> AX=ptr
            _CLRT_CONCAT(SI=str1, DI=str2) : concatenation -> AX=ptr buf
            _CLRT_STRCMP(SI=str1, DI=str2) : comparaison -> drapeaux ZF/CF
            _CLRT_CONS(AX=car, BX=cdr) : allouer cons cell -> AX=ptr
            _CLRT_VECNEW(CX=count) : allouer vecteur -> AX=ptr
            _CLRT_VECNTH(BX=vec, CX=idx) : acces element -> AX
            _CLRT_MAPNEW(CX=pairs) : allouer map -> AX=ptr
            _CLRT_MAPGET(BX=map, CX=key) : recherche cle -> AX (nil si absent)
            _CLRT_SETNEW(CX=count) : allouer ensemble -> AX=ptr
            _CLRT_ALLOC(CX=nb_octets) : allocation heap -> AX=ptr
              _CL_HEAP DB 4096 DUP(0) + _CL_HEAPTOP DW 0
            _CLRT_PANIC(SI=msg) : affiche message + MOV AX,4C01h + INT 21h
            _CLRT_EQUAL(AX=a, BX=b) : egalite structurelle -> AX=true|false
            RuntimeEmitted : flag pour n emettre le runtime qu une seule fois

  TODO 25 - GENERATION FINALE ET FICHIERS EXEMPLES
            EmitClose : END _CLF_main dans _TEXT ENDS / DATA ENDS
            Run : pipeline complet LexInit -> ParseProgram ->
              EmitRuntime -> _TEXT ENDS / EmitDataSeg / END _CLF_main
            Point d entree : la derniere expression de niveau superieur
              ou (defn -main [] ...) si presente -> _CLF_main
            Fichiers SAMPLES\CLOJURE\ a creer :
              hello.clj    (println, def, str, variables globales)
              math.clj     (defn, fn, +, -, *, /, mod, comparaisons)
              control.clj  (if, when, cond, case, do, let)
              loops.clj    (loop/recur, dotimes, doseq, while)
              lists.clj    (list, cons, first, rest, conj, nth)
              vectors.clj  (vector, nth, assoc, conj, subvec)
              maps.clj     (hash-map, get, assoc, dissoc, keys, vals)
              higher.clj   (map, filter, reduce, apply, comp, partial)
              strings.clj  (str, subs, upper-case, lower-case, trim)
              destruct.clj (destructuration sequentielle et associative)
            Smoke tests : CLOJ86.EXE -v SAMPLES\CLOJURE\*.clj

  ============================================================ *)

Program CLOJ86;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

(* ============================================================
   CONSTANTES GLOBALES
   ============================================================ *)
Const
  CLOJ86_VERSION = '1.0';
  CLOJ86_DATE    = '2026-03-07';

  (* Limites internes *)
  MAX_SYM       = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_SCOPE     = {$IFDEF FPC}64{$ELSE}32{$ENDIF};
  MAX_DATA      = {$IFDEF FPC}512{$ELSE}128{$ENDIF};
  MAX_TYPE      = {$IFDEF FPC}32{$ELSE}16{$ENDIF};
  MAX_PARAM     = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_LOOP_NEST = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_ERRORS    = {$IFDEF FPC}30{$ELSE}3{$ENDIF};
  MAX_STR       = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  MAX_KW        = {$IFDEF FPC}256{$ELSE}64{$ENDIF};
  STACK_SIZE    = 1024;
  MAX_DESTR     = {$IFDEF FPC}32{$ELSE}8{$ENDIF};

  (* Prefixes de nommage ASM *)
  CL_VAR_PFX  = '_CLV_';     (* variable globale (def)              *)
  CL_FN_PFX   = '_CLF_';     (* fonction (defn / fn)                *)
  CL_STR_PFX  = '_CLK_';     (* constante chaine litterale          *)
  CL_RT_PFX   = '_CLRT_';    (* routine runtime                     *)
  CL_LBL_PFX  = '_CL_';      (* label de saut interne               *)
  CL_KW_PFX   = '_CLKW_';    (* keyword (:nom)                      *)
  CL_VEC_PFX  = '_CLVEC_';   (* vecteur literal DATA                *)
  CL_MAP_PFX  = '_CLMAP_';   (* map literal DATA                    *)
  CL_SET_PFX  = '_CLSET_';   (* set literal DATA                    *)
  CL_LIST_PFX = '_CLLS_';    (* list literal DATA                   *)
  CL_NIL_LBL  = '_CL_NIL';   (* etiquette DATA chaine 'nil'         *)
  CL_TRUE_LBL = '_CL_TRUE';  (* etiquette DATA chaine 'true'        *)
  CL_FALSE_LBL= '_CL_FALSE'; (* etiquette DATA chaine 'false'       *)

  (* Codes de sortie *)
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  (* Indices de types primitifs Clojure *)
  TY_IDX_NIL     = 0;   (* nil                         *)
  TY_IDX_INT     = 1;   (* entier 16 bits signe        *)
  TY_IDX_STR     = 2;   (* pointeur chaine DATA        *)
  TY_IDX_BOOL    = 3;   (* 0 ou 1 dans AX              *)
  TY_IDX_KW      = 4;   (* keyword (:nom) -> index     *)
  TY_IDX_SYM     = 5;   (* symbole (nom) -> index      *)
  TY_IDX_LIST    = 6;   (* liste (cons cells)          *)
  TY_IDX_VEC     = 7;   (* vecteur (bloc contigu)      *)
  TY_IDX_MAP     = 8;   (* hash-map (paires cle/val)   *)
  TY_IDX_SET     = 9;   (* hash-set                    *)
  TY_IDX_FN      = 10;  (* fonction / closure           *)
  TY_IDX_CHAR    = 11;  (* caractere                    *)
  TY_PRIM_COUNT  = 12;
  TY_UNKNOWN     = -1;

(* ============================================================
   TYPES
   ============================================================ *)
Type
  TString = String[MAX_STR];

  (* ---- Options de compilation ----------------------------- *)
  TOptions = Record
    SrcFile   : TString;   (* fichier source (.clj)                *)
    OutFile   : TString;   (* fichier assembleur de sortie (.asm)  *)
    Verbose   : Boolean;   (* -v : banniere et statistiques        *)
    DebugMode : Boolean;   (* -d : affichage de chaque token       *)
    Warnings  : Boolean;   (* -w : activer les avertissements      *)
  End;

  (* ---- Tokens Clojure (TODO 02) -------------------------- *)
  TTokenKind = (
    TK_EOF,              (* fin de fichier                       *)
    TK_INTEGER,          (* literal entier 42 0xFF 0377          *)
    TK_STRING,           (* literal chaine "abc"                 *)
    TK_SYMBOL,           (* symbole : identifiant non mot-cle    *)
    TK_KEYWORD,          (* :mot-cle                             *)
    TK_LPAREN,           (* (                                    *)
    TK_RPAREN,           (* )                                    *)
    TK_LBRACKET,         (* [                                    *)
    TK_RBRACKET,         (* ]                                    *)
    TK_LBRACE,           (* accolade ouvrante                    *)
    TK_RBRACE,           (* accolade fermante                    *)
    TK_QUOTE,            (* '                                    *)
    TK_DEREF,            (* @                                    *)
    TK_META,             (* ^                                    *)
    TK_SYNTAX_QUOTE,     (* `                                    *)
    TK_UNQUOTE,          (* ~                                    *)
    TK_UNQUOTE_SPLICE,   (* ~@                                   *)
    TK_DISPATCH,         (* #                                    *)
    TK_TRUE,             (* true                                 *)
    TK_FALSE,            (* false                                *)
    TK_NIL,              (* nil                                  *)
    TK_CHAR              (* \a \newline \space \tab              *)
  );

  TToken = Record
    Kind   : TTokenKind;
    Val    : TString;      (* valeur textuelle brute              *)
    IntVal : LongInt;      (* valeur entiere (TK_INTEGER)         *)
    Line   : Integer;      (* ligne source (1-base)               *)
    Col    : Integer;      (* colonne source (1-base)             *)
  End;

  (* ---- Categories de symboles (TODO 05) ------------------- *)
  TSymKind = (
    SK_VAR,       (* variable globale (def)               *)
    SK_FN,        (* fonction (defn)                      *)
    SK_MACRO,     (* macro (defmacro) - stub              *)
    SK_SPECIAL,   (* forme speciale (if, do, let, ...)    *)
    SK_LOCAL,     (* variable locale (let, fn param)      *)
    SK_KEYWORD,   (* keyword (:nom)                       *)
    SK_NS         (* namespace                            *)
  );

  TSymRec = Record
    Name        : TString;   (* identifiant Clojure             *)
    MangledName : TString;   (* _CLV_nom / _CLF_nom             *)
    Kind        : TSymKind;
    TypeIdx     : Integer;   (* indice dans TypeTab             *)
    ScopeLevel  : Integer;
    Offset      : Integer;   (* [BP-n] pour locaux              *)
    IsConst     : Boolean;   (* ^:const -> erreur si reassigne  *)
    Namespace   : TString;   (* espace de noms (vide = courant) *)
    DeclLine    : Integer;
  End;

  (* ---- Types internes (TODO 06) --------------------------- *)
  TTypeKind = (
    TKC_NIL,
    TKC_INT,
    TKC_STRING,
    TKC_BOOLEAN,
    TKC_KEYWORD,
    TKC_SYMBOL,
    TKC_LIST,
    TKC_VECTOR,
    TKC_MAP,
    TKC_SET,
    TKC_FUNCTION,
    TKC_CHAR,
    TKC_UNKNOWN
  );

  TTypeRec = Record
    Name : TString;
    Kind : TTypeKind;
    Size : Integer;   (* octets : int=2, ptr=2             *)
  End;

  (* ---- Valeurs d expression (TODO 10) --------------------- *)
  TExprKind = (
    EK_NONE,   (* void / pas de valeur                      *)
    EK_IMM,    (* immediate dans ImmVal                     *)
    EK_AX,     (* valeur dans AX                            *)
    EK_MEM     (* adresse [BP+Offset] ou [_CLV_x]          *)
  );

  TExprVal = Record
    Kind    : TExprKind;
    ImmVal  : LongInt;
    TypeIdx : Integer;
    Offset  : Integer;
    SymIdx  : Integer;   (* indice dans SymTab (-1 = pas de lvalue) *)
  End;

  (* ---- Segment de donnees (TODO 08) ----------------------- *)
  TDataKind = (DK_WORD, DK_BYTE, DK_STR, DK_LIST, DK_VEC, DK_MAP);

  TDataRec = Record
    LblName   : TString;
    Kind      : TDataKind;
    IntVal    : LongInt;
    StrVal    : TString;
    ElemCount : Integer;
  End;

(* ============================================================
   VARIABLES GLOBALES
   ============================================================ *)
Var
  (* Options *)
  Opts : TOptions;

  (* Compteurs generaux *)
  ErrorCount : Integer;
  WarnCount  : Integer;
  TotalLines : LongInt;
  TotalSyms  : Integer;

  (* Valeur fictive pour ignorer un retour TExprVal *)
  GExprDummy : TExprVal;

  (* Lexeur (TODO 02) *)
  LexSrcF   : Text;
  LexLine   : String;
  LexLineNo : Integer;
  LexColNo  : Integer;
  LexEOF    : Boolean;
  LexOpened : Boolean;
  CurToken  : TToken;

  (* Table des symboles (TODO 05) *)
  SymTab     : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount   : Integer;
  ScopeStack : Array[0..MAX_SCOPE - 1] Of Integer;
  ScopeTop   : Integer;
  CurScope   : Integer;
  LabelSeq   : Integer;

  (* Table des types (TODO 06) *)
  TypeTab   : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount : Integer;

  (* Emetteur ASM (TODO 07) *)
  OutF         : Text;
  OutFOpen     : Boolean;
  CurFrameSize : Integer;    (* taille cadre local courant (words)  *)
  CurFnDepth   : Integer;    (* 0 = global, >0 = dans une defn/fn  *)
  CurFnRetLbl  : TString;    (* label epilogue de la fonction       *)
  CurFnName    : TString;    (* nom de la fonction courante         *)
  LoopTop      : Integer;
  LoopLbl      : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopBindCount: Array[0..MAX_LOOP_NEST - 1] Of Integer;
  LoopBindOfs  : Array[0..MAX_LOOP_NEST - 1, 0..MAX_PARAM - 1] Of Integer;
  LabelGenSeq  : Integer;    (* compteur unique pour LabelGen       *)

  (* Keywords (TODO 02/08) *)
  KwTab   : Array[0..MAX_KW - 1] Of TString;
  KwCount : Integer;

  (* Segment de donnees (TODO 08) *)
  DataTab   : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount : Integer;

  (* Etat general *)
  RuntimeEmitted : Boolean;

(* ============================================================
   FORWARD DECLARATIONS
   ============================================================ *)
Procedure LexInit;             Forward;
Procedure LexClose;            Forward;
Procedure LexNextLine;         Forward;
Function  IsSymStart(Ch : Char) : Boolean; Forward;
Function  IsSymCont(Ch : Char) : Boolean; Forward;
Function  IsHexDigit(Ch : Char) : Boolean; Forward;
Function  HexVal(Ch : Char) : Integer; Forward;
Procedure LexScanSymbol;       Forward;
Procedure LexScanNumber;       Forward;
Procedure LexScanString;       Forward;
Procedure LexScanKeyword;      Forward;
Procedure LexScanChar;         Forward;
Procedure LexNextToken;        Forward;
Procedure PrintToken(Const T : TToken); Forward;
(* TODO 03 *)
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal); Forward;
Procedure ExprMakeNone(Var Res : TExprVal); Forward;
Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal); Forward;
Function  DataAddWord(Const Lbl : TString;
                      AIntVal : LongInt) : Integer; Forward;
Function  KwFind(Const Name : TString) : Integer; Forward;
Function  KwAdd(Const Name : TString) : Integer; Forward;
Procedure LitEvalInt(Const T : TToken; Var Res : TExprVal); Forward;
Procedure LitEvalChar(Const T : TToken; Var Res : TExprVal); Forward;
Procedure LitEvalKW(Const T : TToken; Var Res : TExprVal); Forward;
Procedure LitEval(Const T : TToken; Var Res : TExprVal); Forward;
(* TODO 04 *)
Procedure SkipForm; Forward;
Procedure ReadList(Var ECount : Integer); Forward;
Procedure ReadVector(Var ECount : Integer); Forward;
Procedure ReadMap(Var ECount : Integer); Forward;
Procedure ReadSet(Var ECount : Integer); Forward;
Procedure ReadQuote; Forward;
Procedure ReadSyntaxQuote; Forward;
Procedure ReadUnquote; Forward;
Procedure ReadDeref; Forward;
Procedure ReadMeta; Forward;
Procedure ReadDispatch; Forward;
Procedure ReadForm(Var Res : TExprVal); Forward;
(* TODO 05 *)
Function  SymNameClean(Const Name : TString) : TString; Forward;
Function  SymMangle(Const Name : TString; Kind : TSymKind) : TString; Forward;
Function  SymFind(Const Name : TString) : Integer; Forward;
Function  SymFindInScope(Const Name : TString;
                 Level : Integer) : Integer; Forward;
Function  SymAdd(Const Name : TString; Kind : TSymKind;
                 TypeIdx, Offset : Integer) : Integer; Forward;
Procedure SymEnterScope; Forward;
Procedure SymLeaveScope; Forward;
Function  IsSpecialForm(Const Name : TString) : Boolean; Forward;
(* TODO 06 *)
Procedure TypeInit;      Forward;
Function  TypeSizeof(TypeIdx : Integer) : Integer; Forward;
Function  TypeKindOf(TypeIdx : Integer) : TTypeKind; Forward;
Function  TypeMangle(TypeIdx : Integer) : TString; Forward;
Function  TypeIsNumeric(TypeIdx : Integer) : Boolean; Forward;
Function  TypeIsPtr(TypeIdx : Integer) : Boolean; Forward;
Function  TypeIsTruthy(TypeIdx : Integer) : Boolean; Forward;
Function  TypeCanCoerce(SrcIdx, DstIdx : Integer) : Boolean; Forward;
Function  TypeCoerceResult(LeftIdx, RightIdx : Integer;
                           Const Op : TString) : Integer; Forward;
Function  TypeInfer(Const E : TExprVal) : Integer; Forward;
Function  TypeLookupName(Const Name : TString) : Integer; Forward;
(* TODO 07 *)
Function  LabelGen : TString; Forward;
Procedure EmitRaw(Const S : TString); Forward;
Procedure EmitBlankLine; Forward;
Procedure EmitComment(Const S : TString); Forward;
Procedure EmitLabel(Const Lbl : TString); Forward;
Procedure EmitInstr(Const Mnem, Ops : TString); Forward;
Procedure EmitInstrA(Const Mnem, A1 : TString); Forward;
Procedure EmitInstrAB(Const Mnem, A1, A2 : TString); Forward;
Procedure EmitProlog; Forward;
Procedure EmitEpilog; Forward;
Procedure EmitOpen;    Forward;
Procedure EmitClose;   Forward;
Procedure EmitHeader;  Forward;
Procedure EmitDataSeg; Forward;
(* TODO 08 *)
Function  DataAdd(Const Lbl : TString; Kind : TDataKind;
                  AIntVal : LongInt; Const AStrVal : TString) : Integer; Forward;
Function  DataAddStr(Const S : TString) : TString; Forward;
Function  DataAddList(AElemCount : Integer) : TString; Forward;
Function  DataAddVec(AElemCount : Integer) : TString; Forward;
Function  DataAddMap(APairCount : Integer) : TString; Forward;
Procedure DataInit; Forward;
(* TODO 09 *)
Function  ExprAddrOf(SIdx : Integer) : TString; Forward;
Procedure ExprStore(SIdx : Integer); Forward;
Procedure ExprLoad(SIdx : Integer; Var Res : TExprVal); Forward;
Function  DeclAllocGlobal(Const Name : TString) : Integer; Forward;
Procedure ParseDef(Var Res : TExprVal); Forward;
Procedure ParseDefonce(Var Res : TExprVal); Forward;
(* TODO 10 *)
Procedure ExprFlushToAX(Const E : TExprVal); Forward;
Procedure ParseQuote(Var Res : TExprVal); Forward;
Procedure ParseDo(Var Res : TExprVal); Forward;
Procedure ParseIf(Var Res : TExprVal); Forward;
Procedure ParseLet(Var Res : TExprVal); Forward;
Procedure ParseFnCall(Const FnName : TString; FnSIdx : Integer;
                      Var Res : TExprVal); Forward;
Procedure ParseForm(Var Res : TExprVal); Forward;
(* TODO 11 *)
Procedure ParseArith(Const Op : TString; Var Res : TExprVal); Forward;
Procedure ParseMod(Const Op : TString; Var Res : TExprVal); Forward;
Procedure ParseIncDec(Const Op : TString; Var Res : TExprVal); Forward;
Procedure ParseCompare(Const Op : TString; Var Res : TExprVal); Forward;
Procedure ParseAnd(Var Res : TExprVal); Forward;
Procedure ParseOr(Var Res : TExprVal); Forward;
Procedure ParseNot(Var Res : TExprVal); Forward;
Procedure ParseMinMax(Const Op : TString; Var Res : TExprVal); Forward;
(* TODO 12 *)
Procedure ParsePrintln(Var Res : TExprVal); Forward;
Procedure ParsePrint(Var Res : TExprVal); Forward;
Procedure ParseNewline(Var Res : TExprVal); Forward;
Procedure ParseReadLine(Var Res : TExprVal); Forward;
Procedure ParseStr(Var Res : TExprVal); Forward;
Procedure ParsePrStr(Var Res : TExprVal); Forward;
Procedure ParseFlush(Var Res : TExprVal); Forward;
(* TODO 13 *)
Procedure ParseWhenNot(Var Res : TExprVal); Forward;
Procedure ParseCond(Var Res : TExprVal); Forward;
Procedure ParseCase(Var Res : TExprVal); Forward;
Procedure ParseIfLet(Var Res : TExprVal); Forward;
Procedure ParseWhenLet(Var Res : TExprVal); Forward;
(* TODO 15 *)
Procedure ParseDefnForm(Var Res : TExprVal); Forward;
Procedure ParseFnForm(Var Res : TExprVal); Forward;
(* TODO 16 *)
Procedure ParseLoopForm(Var Res : TExprVal); Forward;
Procedure ParseRecurForm(Var Res : TExprVal); Forward;
Procedure ParseDotimesForm(Var Res : TExprVal); Forward;
Procedure ParseDoseqForm(Var Res : TExprVal); Forward;
Procedure ParseWhileForm(Var Res : TExprVal); Forward;
(* TODO 17 *)
Procedure ParseConsForm(Var Res : TExprVal); Forward;
Procedure ParseFirstForm(Var Res : TExprVal); Forward;
Procedure ParseRestForm(Var Res : TExprVal); Forward;
Procedure ParseListForm(Var Res : TExprVal); Forward;
Procedure ParseConjListForm(Var Res : TExprVal); Forward;
Procedure ParseCountForm(Var Res : TExprVal); Forward;
Procedure ParseNthForm(Var Res : TExprVal); Forward;
Procedure ParseEmptyForm(Var Res : TExprVal); Forward;
Procedure ParseSeqForm(Var Res : TExprVal); Forward;
(* TODO 18 *)
Procedure ParseVectorForm(Var Res : TExprVal); Forward;
Procedure ParseVecLiteral(Var Res : TExprVal); Forward;
Procedure ParseGetForm(Var Res : TExprVal); Forward;
Procedure ParseAssocForm(Var Res : TExprVal); Forward;
Procedure ParseSubvecForm(Var Res : TExprVal); Forward;
(* TODO 19 *)
Procedure ParseHashMapForm(Var Res : TExprVal); Forward;
Procedure ParseMapLiteral(Var Res : TExprVal); Forward;
Procedure ParseDissocForm(Var Res : TExprVal); Forward;
Procedure ParseContainsForm(Var Res : TExprVal); Forward;
Procedure ParseKeysForm(Var Res : TExprVal); Forward;
Procedure ParseValsForm(Var Res : TExprVal); Forward;
Procedure ParseMergeForm(Var Res : TExprVal); Forward;
(* TODO 20 *)
Procedure ParseHashSetForm(Var Res : TExprVal); Forward;
Procedure ParseSetLiteral(Var Res : TExprVal); Forward;
Procedure ParseDisjForm(Var Res : TExprVal); Forward;
Procedure ParseUnionForm(Var Res : TExprVal); Forward;
Procedure ParseInterForm(Var Res : TExprVal); Forward;
Procedure ParseDiffForm(Var Res : TExprVal); Forward;
(* TODO 21 *)
Procedure EmitDestrucVec(ValOfs : Integer); Forward;
Procedure EmitDestrucMap(ValOfs : Integer); Forward;
Procedure EmitDestrucBind(ValOfs : Integer); Forward;
(* TODO 22 *)
Procedure ParseMapHOFForm(Var Res : TExprVal); Forward;
Procedure ParseFilterForm(Var Res : TExprVal); Forward;
Procedure ParseReduceForm(Var Res : TExprVal); Forward;
Procedure ParseRemoveForm(Var Res : TExprVal); Forward;
Procedure ParseSomeForm(Var Res : TExprVal); Forward;
Procedure ParseEveryForm(Var Res : TExprVal); Forward;
Procedure ParseIntoForm(Var Res : TExprVal); Forward;
Procedure ParseCompForm(Var Res : TExprVal); Forward;
Procedure ParsePartialForm(Var Res : TExprVal); Forward;
Procedure ParseConstantlyForm(Var Res : TExprVal); Forward;
Procedure ParseIdentityForm(Var Res : TExprVal); Forward;
(* TODO 23 *)
Procedure ParseSubsForm(Var Res : TExprVal); Forward;
Procedure ParseUpperCaseForm(Var Res : TExprVal); Forward;
Procedure ParseLowerCaseForm(Var Res : TExprVal); Forward;
Procedure ParseTrimForm(Var Res : TExprVal); Forward;
Procedure ParseIncludesForm(Var Res : TExprVal); Forward;
Procedure ParseStrReplaceForm(Var Res : TExprVal); Forward;
Procedure ParseSplitForm(Var Res : TExprVal); Forward;
Procedure ParseJoinForm(Var Res : TExprVal); Forward;
(* TODO 24 *)
Procedure EmitRuntime;   Forward;
(* TODO 25 *)
Procedure SymInit;       Forward;
Procedure ParseProgram;  Forward;

(* ============================================================
   TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
   ============================================================ *)

(* ---- Messages d erreur et d avertissement ----------------- *)

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('CLOJ86: FATAL: ', Msg);
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
    Assign(OutF, Opts.OutFile);
    Erase(OutF);
  End;
  Halt(EXIT_ERROR);
End;

Procedure CompileError(Const Msg : TString);
Begin
  Write('CLOJ86:');
  If CurToken.Line > 0 Then
    Write(Opts.SrcFile, ':', CurToken.Line, ': ');
  WriteLn('error: ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('trop d''erreurs, compilation arretee');
End;

Procedure WarnMsg(Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  Write('CLOJ86:');
  If CurToken.Line > 0 Then
    Write(Opts.SrcFile, ':', CurToken.Line, ': ');
  WriteLn('warning: ', Msg);
  Inc(WarnCount);
End;

(* ---- Banniere et aide ------------------------------------- *)

Procedure ShowBanner;
Begin
  WriteLn('CLOJ86 v', CLOJ86_VERSION, ' (', CLOJ86_DATE, ')');
  WriteLn('Compilateur Clojure -> assembleur 8086 (MASM .MODEL SMALL)');
  WriteLn('Turbo Pascal / Free Pascal (-Mtp)');
  WriteLn;
End;

Procedure ShowUsage;
Begin
  WriteLn('Usage: CLOJ86 <source.clj> [sortie.asm] [-v] [-d] [-w]');
  WriteLn;
  WriteLn('  source.clj : fichier Clojure source');
  WriteLn('  sortie.asm : fichier assembleur de sortie (defaut: source.asm)');
  WriteLn('  -v         : mode verbeux (banniere + statistiques)');
  WriteLn('  -d         : debug tokens (affiche chaque token)');
  WriteLn('  -w         : activer les avertissements');
  WriteLn;
  Halt(EXIT_USAGE);
End;

(* ---- Fonctions utilitaires sur les chaines ----------------- *)

Function IntToStr(N : LongInt) : TString;
Var
  S : TString;
Begin
  Str(N, S);
  IntToStr := S;
End;

Function StrLowerCase(Const S : TString) : TString;
Var
  I : Integer;
  R : TString;
Begin
  R := S;
  For I := 1 To Length(R) Do
    If (R[I] >= 'A') And (R[I] <= 'Z') Then
      R[I] := Chr(Ord(R[I]) + 32);
  StrLowerCase := R;
End;

Function ExtractExt(Const Path : TString) : TString;
Var
  I, LastDot, LastSep : Integer;
Begin
  LastDot := 0;
  LastSep := 0;
  For I := 1 To Length(Path) Do
  Begin
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
    If Path[I] = '.' Then
      LastDot := I;
  End;
  If (LastDot > 0) And (LastDot > LastSep) Then
    ExtractExt := StrLowerCase(Copy(Path, LastDot, Length(Path) - LastDot + 1))
  Else
    ExtractExt := '';
End;

Function ReplaceExt(Const Path, NewExt : TString) : TString;
Var
  I, LastDot, LastSep : Integer;
Begin
  LastDot := 0;
  LastSep := 0;
  For I := 1 To Length(Path) Do
  Begin
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
    If Path[I] = '.' Then
      LastDot := I;
  End;
  If (LastDot > 0) And (LastDot > LastSep) Then
    ReplaceExt := Copy(Path, 1, LastDot - 1) + NewExt
  Else
    ReplaceExt := Path + NewExt;
End;

(* ---- Initialisation des options ----------------------------- *)

Procedure InitOptions;
Begin
  Opts.SrcFile   := '';
  Opts.OutFile   := '';
  Opts.Verbose   := False;
  Opts.DebugMode := False;
  Opts.Warnings  := False;
End;

(* ---- Analyse des arguments de la ligne de commande ---------- *)

Procedure ParseArgs;
Var
  I   : Integer;
  Arg : TString;
  Ext : TString;
Begin
  InitOptions;
  If ParamCount = 0 Then
    ShowUsage;

  For I := 1 To ParamCount Do
  Begin
    Arg := ParamStr(I);

    If (Arg = '-h') Or (Arg = '--help') Or (Arg = '/?') Then
      ShowUsage
    Else If (Arg = '-v') Or (Arg = '--verbose') Then
      Opts.Verbose := True
    Else If Arg = '-d' Then
      Opts.DebugMode := True
    Else If Arg = '-w' Then
      Opts.Warnings := True
    Else If Arg[1] = '-' Then
    Begin
      WriteLn('CLOJ86: option inconnue: ', Arg);
      ShowUsage;
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else If Opts.OutFile = '' Then
      Opts.OutFile := Arg
    Else
    Begin
      WriteLn('CLOJ86: argument inattendu: ', Arg);
      ShowUsage;
    End;
  End;

  If Opts.SrcFile = '' Then
  Begin
    WriteLn('CLOJ86: fichier source manquant');
    ShowUsage;
  End;

  (* Verifier l extension .clj *)
  Ext := ExtractExt(Opts.SrcFile);
  If Ext <> '.clj' Then
    WarnMsg('extension attendue .clj, trouvee: ' + Ext);

  (* Fichier de sortie par defaut : meme nom avec .asm *)
  If Opts.OutFile = '' Then
    Opts.OutFile := ReplaceExt(Opts.SrcFile, '.asm');
End;

(* ---- Nettoyage ---------------------------------------------- *)

Procedure Cleanup;
Begin
  If LexOpened Then
    LexClose;
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

(* ---- Initialisation generale des variables globales --------- *)

Procedure GlobalInit;
Begin
  ErrorCount     := 0;
  WarnCount      := 0;
  TotalLines     := 0;
  TotalSyms      := 0;
  SymCount       := 0;
  ScopeTop       := 0;
  CurScope       := 0;
  LabelSeq       := 0;
  TypeCount      := 0;
  DataCount      := 0;
  KwCount        := 0;
  OutFOpen       := False;
  LexOpened      := False;
  LexEOF         := False;
  CurFnDepth     := 0;
  CurFnRetLbl    := '';
  CurFnName      := '';
  LoopTop        := 0;
  RuntimeEmitted := False;
  CurFrameSize   := 0;
  LabelGenSeq    := 0;
  GExprDummy.Kind    := EK_NONE;
  GExprDummy.ImmVal  := 0;
  GExprDummy.TypeIdx := TY_UNKNOWN;
  GExprDummy.Offset  := 0;
  GExprDummy.SymIdx  := -1;
  CurToken.Kind    := TK_EOF;
  CurToken.Val     := '';
  CurToken.IntVal  := 0;
  CurToken.Line    := 0;
  CurToken.Col     := 0;
End;

(* ---- Statistiques ------------------------------------------ *)

Procedure ShowStats;
Begin
  WriteLn('Compilation terminee : ', Opts.SrcFile, ' -> ', Opts.OutFile);
  WriteLn('  Lignes         : ', TotalLines);
  WriteLn('  Symboles       : ', TotalSyms);
  WriteLn('  Erreurs        : ', ErrorCount);
  WriteLn('  Avertissements : ', WarnCount);
End;

(* ============================================================
   TODO 02 - LECTEUR / TOKENISEUR (READER) [IMPLEMENTE]
   ============================================================ *)

(* ---- LexNextLine : lire la prochaine ligne source ---------- *)
Procedure LexNextLine;
Begin
  If LexEOF Then Exit;
  If EOF(LexSrcF) Then
  Begin
    LexEOF   := True;
    LexLine  := '';
    LexColNo := 1;
  End
  Else
  Begin
    ReadLn(LexSrcF, LexLine);
    Inc(LexLineNo);
    Inc(TotalLines);
    LexColNo := 1;
  End;
End;

(* ---- LexInit : ouvrir le fichier source et initialiser ----- *)
Procedure LexInit;
Begin
  Assign(LexSrcF, Opts.SrcFile);
  Reset(LexSrcF);
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir ' + Opts.SrcFile);
  LexOpened := True;
  LexLineNo := 0;
  LexColNo  := 1;
  LexLine   := '';
  LexEOF    := False;
  LexNextLine;
End;

(* ---- LexClose : fermer le fichier source ------------------- *)
Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
End;

(* ---- Fonctions de test sur les caracteres ------------------- *)

Function IsHexDigit(Ch : Char) : Boolean;
Begin
  IsHexDigit := ((Ch >= '0') And (Ch <= '9')) Or
                ((Ch >= 'A') And (Ch <= 'F')) Or
                ((Ch >= 'a') And (Ch <= 'f'));
End;

Function HexVal(Ch : Char) : Integer;
Begin
  If (Ch >= '0') And (Ch <= '9') Then HexVal := Ord(Ch) - Ord('0')
  Else If (Ch >= 'A') And (Ch <= 'F') Then HexVal := Ord(Ch) - Ord('A') + 10
  Else HexVal := Ord(Ch) - Ord('a') + 10;
End;

(* IsSymStart : caracteres valides pour debut d un symbole Clojure
   Autorise lettres, _ + - * / = < > ! ? . & et bien d autres *)
Function IsSymStart(Ch : Char) : Boolean;
Begin
  IsSymStart := ((Ch >= 'A') And (Ch <= 'Z')) Or
                ((Ch >= 'a') And (Ch <= 'z')) Or
                (Ch = '_') Or (Ch = '+') Or (Ch = '-') Or
                (Ch = '*') Or (Ch = '/') Or (Ch = '=') Or
                (Ch = '<') Or (Ch = '>') Or (Ch = '!') Or
                (Ch = '?') Or (Ch = '&') Or (Ch = '%') Or
                (Ch = '.') Or (Ch = '$');
End;

(* IsSymCont : caracteres valides a l interieur d un symbole *)
Function IsSymCont(Ch : Char) : Boolean;
Begin
  IsSymCont := IsSymStart(Ch) Or
               ((Ch >= '0') And (Ch <= '9')) Or
               (Ch = '#') Or (Ch = ':') Or (Ch = '''');
End;

(* ---- LexScanSymbol : scanner un symbole ou mot-cle --------- *)
Procedure LexScanSymbol;
Var
  S : TString;
Begin
  S := '';
  While (LexColNo <= Length(LexLine)) And IsSymCont(LexLine[LexColNo]) Do
  Begin
    If Length(S) < MAX_STR Then
      S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
  (* Verifier les symboles speciaux *)
  If S = 'nil' Then
    CurToken.Kind := TK_NIL
  Else If S = 'true' Then
    CurToken.Kind := TK_TRUE
  Else If S = 'false' Then
    CurToken.Kind := TK_FALSE
  Else
    CurToken.Kind := TK_SYMBOL;
End;

(* ---- LexScanNumber : scanner un litteral numerique ---------- *)
Procedure LexScanNumber;
Var
  N    : LongInt;
  Base : Integer;
  Ch   : Char;
  Neg  : Boolean;
  S    : TString;
Begin
  N    := 0;
  Base := 10;
  Neg  := False;
  S    := '';
  Ch   := LexLine[LexColNo];

  (* Signe negatif : traite par le parser sauf si colle au chiffre *)
  (* Note : le signe - seul est un symbole, gere dans LexNextToken *)

  (* Prefixe 0x (hexa) ou 0 (octal) *)
  If (Ch = '0') And (LexColNo < Length(LexLine)) Then
  Begin
    Ch := LexLine[LexColNo + 1];
    If (Ch = 'x') Or (Ch = 'X') Then
    Begin
      Base := 16;
      S := '0x';
      Inc(LexColNo); Inc(LexColNo);
    End
    Else If (Ch >= '0') And (Ch <= '7') Then
    Begin
      Base := 8;
      S := '0';
      Inc(LexColNo);
    End;
  End;

  (* Scanner la partie entiere *)
  While LexColNo <= Length(LexLine) Do
  Begin
    Ch := LexLine[LexColNo];
    If (Base = 16) And IsHexDigit(Ch) Then
    Begin
      N := N * 16 + HexVal(Ch);
      If Length(S) < MAX_STR Then S := S + Ch;
      Inc(LexColNo);
    End
    Else If (Base = 8) And (Ch >= '0') And (Ch <= '7') Then
    Begin
      N := N * 8 + (Ord(Ch) - Ord('0'));
      If Length(S) < MAX_STR Then S := S + Ch;
      Inc(LexColNo);
    End
    Else If (Base = 10) And (Ch >= '0') And (Ch <= '9') Then
    Begin
      N := N * 10 + (Ord(Ch) - Ord('0'));
      If Length(S) < MAX_STR Then S := S + Ch;
      Inc(LexColNo);
    End
    Else
      Break;
  End;

  (* Clojure supporte les ratios N/M : avertissement, tronquer *)
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '/') And
     (LexColNo < Length(LexLine)) And
     (LexLine[LexColNo + 1] >= '0') And (LexLine[LexColNo + 1] <= '9') Then
  Begin
    WarnMsg('ratio non supporte, tronque a partie entiere');
    Inc(LexColNo); (* sauter / *)
    While (LexColNo <= Length(LexLine)) And
          (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
      Inc(LexColNo);
  End;

  (* Clojure supporte le suffixe N (BigInt) et M (BigDecimal) *)
  If (LexColNo <= Length(LexLine)) And
     ((LexLine[LexColNo] = 'N') Or (LexLine[LexColNo] = 'M')) Then
    Inc(LexColNo);

  If Neg Then N := -N;
  CurToken.Kind   := TK_INTEGER;
  CurToken.IntVal := N;
  Str(N, CurToken.Val);
End;

(* ---- LexScanString : chaine entre guillemets doubles -------- *)
Procedure LexScanString;
Var
  S  : TString;
  Ch : Char;
Begin
  S := '';
  Inc(LexColNo); (* sauter guillemet ouvrant *)
  While (Not LexEOF) Do
  Begin
    (* Fin de ligne dans la chaine -> chaine multi-ligne *)
    If LexColNo > Length(LexLine) Then
    Begin
      If Length(S) < MAX_STR Then
        S := S + #10;
      LexNextLine;
      If LexEOF Then
      Begin
        CompileError('chaine non terminee');
        Break;
      End;
    End
    Else
    Begin
      Ch := LexLine[LexColNo];
      If Ch = '"' Then
      Begin
        Inc(LexColNo);
        Break;
      End
      Else If Ch = '\' Then
      Begin
        Inc(LexColNo);
        If LexColNo > Length(LexLine) Then
        Begin
          If Length(S) < MAX_STR Then S := S + '\';
        End
        Else
        Begin
          Ch := LexLine[LexColNo];
          Inc(LexColNo);
          Case Ch Of
            'n' : If Length(S) < MAX_STR Then S := S + #10;
            't' : If Length(S) < MAX_STR Then S := S + #9;
            'r' : If Length(S) < MAX_STR Then S := S + #13;
            '\' : If Length(S) < MAX_STR Then S := S + '\';
            '"' : If Length(S) < MAX_STR Then S := S + '"';
            'b' : If Length(S) < MAX_STR Then S := S + #8;
            'f' : If Length(S) < MAX_STR Then S := S + #12;
          Else
            If Length(S) < MAX_STR Then S := S + Ch;
          End;
        End;
      End
      Else
      Begin
        If Length(S) < MAX_STR Then
          S := S + Ch;
        Inc(LexColNo);
      End;
    End;
  End;
  CurToken.Kind   := TK_STRING;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
End;

(* ---- LexScanKeyword : :mot-cle ou ::mot-cle-qualifie ------- *)
Procedure LexScanKeyword;
Var
  S : TString;
Begin
  S := '';
  Inc(LexColNo); (* sauter le premier : *)
  (* Double :: pour keyword qualifie *)
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = ':') Then
  Begin
    S := ':';
    Inc(LexColNo);
  End;
  (* Scanner le nom du keyword *)
  While (LexColNo <= Length(LexLine)) And IsSymCont(LexLine[LexColNo]) Do
  Begin
    If Length(S) < MAX_STR Then
      S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  CurToken.Kind   := TK_KEYWORD;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
End;

(* ---- LexScanChar : litteral caractere \a \newline etc ------- *)
Procedure LexScanChar;
Var
  S : TString;
Begin
  Inc(LexColNo); (* sauter le \ *)
  S := '';
  (* Scanner le nom du caractere *)
  While (LexColNo <= Length(LexLine)) And
        (((LexLine[LexColNo] >= 'a') And (LexLine[LexColNo] <= 'z')) Or
         ((LexLine[LexColNo] >= 'A') And (LexLine[LexColNo] <= 'Z'))) Do
  Begin
    If Length(S) < MAX_STR Then
      S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  CurToken.Kind := TK_CHAR;
  CurToken.Val  := S;
  (* Convertir les noms de caracteres connus en valeur entiere *)
  If Length(S) = 1 Then
    CurToken.IntVal := Ord(S[1])
  Else If S = 'newline' Then
    CurToken.IntVal := 10
  Else If S = 'space' Then
    CurToken.IntVal := 32
  Else If S = 'tab' Then
    CurToken.IntVal := 9
  Else If S = 'return' Then
    CurToken.IntVal := 13
  Else If S = 'backspace' Then
    CurToken.IntVal := 8
  Else If S = 'formfeed' Then
    CurToken.IntVal := 12
  Else
  Begin
    CompileError('caractere inconnu: \' + S);
    CurToken.IntVal := 0;
  End;
End;

(* ---- PrintToken : affichage debug d un token ---------------- *)
Procedure PrintToken(Const T : TToken);
Var NS : TString;
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', T.Line, ',', T.Col, '] ');
  Case T.Kind Of
    TK_EOF            : Write('EOF');
    TK_INTEGER        : Begin Str(T.IntVal, NS); Write('INT(', NS, ')'); End;
    TK_STRING         : Write('STR("', T.Val, '")');
    TK_SYMBOL         : Write('SYM(', T.Val, ')');
    TK_KEYWORD        : Write('KW(:', T.Val, ')');
    TK_LPAREN         : Write('LPAREN');
    TK_RPAREN         : Write('RPAREN');
    TK_LBRACKET       : Write('LBRACKET');
    TK_RBRACKET       : Write('RBRACKET');
    TK_LBRACE         : Write('LBRACE');
    TK_RBRACE         : Write('RBRACE');
    TK_QUOTE          : Write('QUOTE');
    TK_DEREF          : Write('DEREF');
    TK_META           : Write('META');
    TK_SYNTAX_QUOTE   : Write('SYNTAX_QUOTE');
    TK_UNQUOTE        : Write('UNQUOTE');
    TK_UNQUOTE_SPLICE : Write('UNQUOTE_SPLICE');
    TK_DISPATCH       : Write('DISPATCH(', T.Val, ')');
    TK_TRUE           : Write('TRUE');
    TK_FALSE          : Write('FALSE');
    TK_NIL            : Write('NIL');
    TK_CHAR           : Begin Str(T.IntVal, NS); Write('CHAR(\', T.Val, '=', NS, ')'); End;
  End;
  WriteLn;
End;

(* ---- LexNextToken : produire le prochain token -------------- *)
Procedure LexNextToken;
Var
  Ch      : Char;
  Scanning : Boolean;
  ShouldSkipForm : Boolean;
  SkipDepth : Integer;
  SaveDebug : Boolean;
Begin
  CurToken.IntVal := 0;
  Scanning := True;
  ShouldSkipForm := False;

  While Scanning Do
  Begin
    (* Avancer tant qu on est en fin de ligne *)
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
      LexNextLine;

    (* Fin de fichier *)
    If LexEOF Then
    Begin
      CurToken.Kind := TK_EOF;
      CurToken.Val  := '';
      CurToken.Line := LexLineNo;
      CurToken.Col  := LexColNo;
      Scanning := False;
      Break;
    End;

    CurToken.Line := LexLineNo;
    CurToken.Col  := LexColNo;
    Ch := LexLine[LexColNo];

    (* Espaces et virgules (la virgule est un whitespace en Clojure) *)
    If (Ch = ' ') Or (Ch = #9) Or (Ch = #13) Or (Ch = #12) Or (Ch = ',') Then
    Begin
      Inc(LexColNo);
    End

    (* Commentaire ; jusqu a fin de ligne *)
    Else If Ch = ';' Then
    Begin
      LexColNo := Length(LexLine) + 1;
    End

    (* Parenthese ouvrante ( *)
    Else If Ch = '(' Then
    Begin
      CurToken.Kind := TK_LPAREN;
      CurToken.Val  := '(';
      Inc(LexColNo);
      Scanning := False;
    End

    (* Parenthese fermante ) *)
    Else If Ch = ')' Then
    Begin
      CurToken.Kind := TK_RPAREN;
      CurToken.Val  := ')';
      Inc(LexColNo);
      Scanning := False;
    End

    (* Crochet ouvrant [ *)
    Else If Ch = '[' Then
    Begin
      CurToken.Kind := TK_LBRACKET;
      CurToken.Val  := '[';
      Inc(LexColNo);
      Scanning := False;
    End

    (* Crochet fermant ] *)
    Else If Ch = ']' Then
    Begin
      CurToken.Kind := TK_RBRACKET;
      CurToken.Val  := ']';
      Inc(LexColNo);
      Scanning := False;
    End

    (* Accolade ouvrante - utiliser le code ASCII pour eviter conflit Pascal *)
    Else If Ch = Chr(123) Then
    Begin
      CurToken.Kind := TK_LBRACE;
      CurToken.Val  := Chr(123);
      Inc(LexColNo);
      Scanning := False;
    End

    (* Accolade fermante *)
    Else If Ch = Chr(125) Then
    Begin
      CurToken.Kind := TK_RBRACE;
      CurToken.Val  := Chr(125);
      Inc(LexColNo);
      Scanning := False;
    End

    (* Quote ' *)
    Else If Ch = '''' Then
    Begin
      CurToken.Kind := TK_QUOTE;
      CurToken.Val  := '''';
      Inc(LexColNo);
      Scanning := False;
    End

    (* Deref @ *)
    Else If Ch = '@' Then
    Begin
      CurToken.Kind := TK_DEREF;
      CurToken.Val  := '@';
      Inc(LexColNo);
      Scanning := False;
    End

    (* Meta ^ *)
    Else If Ch = '^' Then
    Begin
      CurToken.Kind := TK_META;
      CurToken.Val  := '^';
      Inc(LexColNo);
      Scanning := False;
    End

    (* Syntax-quote ` *)
    Else If Ch = '`' Then
    Begin
      CurToken.Kind := TK_SYNTAX_QUOTE;
      CurToken.Val  := '`';
      Inc(LexColNo);
      Scanning := False;
    End

    (* Unquote ~ ou Unquote-splice ~@ *)
    Else If Ch = '~' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '@') Then
      Begin
        CurToken.Kind := TK_UNQUOTE_SPLICE;
        CurToken.Val  := '~@';
        Inc(LexColNo);
      End
      Else
      Begin
        CurToken.Kind := TK_UNQUOTE;
        CurToken.Val  := '~';
      End;
      Scanning := False;
    End

    (* Dispatch # : reader macros *)
    Else If Ch = '#' Then
    Begin
      Inc(LexColNo);
      If LexColNo > Length(LexLine) Then
      Begin
        CurToken.Kind := TK_DISPATCH;
        CurToken.Val  := '#';
        Scanning := False;
      End
      Else
      Begin
        Ch := LexLine[LexColNo];
        (* #_ : ignorer la forme suivante *)
        If Ch = '_' Then
        Begin
          Inc(LexColNo);
          ShouldSkipForm := True;
          (* On continue a scanner : le prochain vrai token sera lu,
             mais on va le jeter et en lire un autre *)
        End
        (* #' : var quote *)
        Else If Ch = '''' Then
        Begin
          CurToken.Kind := TK_DISPATCH;
          CurToken.Val  := '#''';
          Inc(LexColNo);
          Scanning := False;
        End
        (* #( : fonction anonyme *)
        Else If Ch = '(' Then
        Begin
          CurToken.Kind := TK_DISPATCH;
          CurToken.Val  := '#(';
          (* Ne pas avancer : le ( sera lu comme LPAREN au prochain appel *)
          Scanning := False;
        End
        (* #" : expression reguliere (avertissement) *)
        Else If Ch = '"' Then
        Begin
          WarnMsg('regex non supportee, traitee comme chaine');
          LexScanString;
          Scanning := False;
        End
        (* # suivi de accolade ouvrante : ensemble litteral *)
        Else If Ch = Chr(123) Then
        Begin
          CurToken.Kind := TK_DISPATCH;
          CurToken.Val  := '#' + Chr(123);
          (* Ne pas avancer : le accolade sera lu comme LBRACE *)
          Scanning := False;
        End
        (* Autre dispatch : traiter comme symbole dispatch generique *)
        Else
        Begin
          CurToken.Kind := TK_DISPATCH;
          CurToken.Val  := '#';
          Scanning := False;
        End;
      End;
    End

    (* Chaine double-quote *)
    Else If Ch = '"' Then
    Begin
      LexScanString;
      Scanning := False;
    End

    (* Keyword :mot-cle *)
    Else If Ch = ':' Then
    Begin
      LexScanKeyword;
      Scanning := False;
    End

    (* Caractere litteral \a \newline etc. *)
    Else If Ch = '\' Then
    Begin
      LexScanChar;
      Scanning := False;
    End

    (* Nombre : commence par un chiffre *)
    Else If (Ch >= '0') And (Ch <= '9') Then
    Begin
      LexScanNumber;
      Scanning := False;
    End

    (* Nombre negatif : - suivi d un chiffre sans espace *)
    Else If (Ch = '-') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] >= '0') And
            (LexLine[LexColNo + 1] <= '9') Then
    Begin
      Inc(LexColNo);
      LexScanNumber;
      CurToken.IntVal := -CurToken.IntVal;
      Str(CurToken.IntVal, CurToken.Val);
      Scanning := False;
    End

    (* Symbole : tout ce qui commence par un caractere de symbole *)
    Else If IsSymStart(Ch) Then
    Begin
      LexScanSymbol;
      Scanning := False;
    End

    (* Caractere inconnu : erreur et avancer *)
    Else
    Begin
      CompileError('caractere inattendu: ' + Ch);
      Inc(LexColNo);
    End;

    (* Si on a lu un token et qu on doit ignorer la forme (#_) *)
    If (Not Scanning) And ShouldSkipForm Then
    Begin
      ShouldSkipForm := False;
      SaveDebug := Opts.DebugMode;
      Opts.DebugMode := False;
      (* Skip recursif : sauter la forme complete (TODO 04) *)
      (* Pour les formes composees, compter la profondeur    *)
      If CurToken.Kind = TK_LPAREN Then
      Begin
        SkipDepth := 1;
        While (SkipDepth > 0) And (Not LexEOF) Do
        Begin
          LexNextToken;
          If CurToken.Kind = TK_LPAREN Then Inc(SkipDepth);
          If CurToken.Kind = TK_RPAREN Then Dec(SkipDepth);
        End;
      End
      Else If CurToken.Kind = TK_LBRACKET Then
      Begin
        SkipDepth := 1;
        While (SkipDepth > 0) And (Not LexEOF) Do
        Begin
          LexNextToken;
          If CurToken.Kind = TK_LBRACKET Then Inc(SkipDepth);
          If CurToken.Kind = TK_RBRACKET Then Dec(SkipDepth);
        End;
      End
      Else If CurToken.Kind = TK_LBRACE Then
      Begin
        SkipDepth := 1;
        While (SkipDepth > 0) And (Not LexEOF) Do
        Begin
          LexNextToken;
          If CurToken.Kind = TK_LBRACE Then Inc(SkipDepth);
          If CurToken.Kind = TK_RBRACE Then Dec(SkipDepth);
        End;
      End;
      (* Sinon c est un token atomique : deja lu et jete *)
      Opts.DebugMode := SaveDebug;
      Scanning := True;
    End;
  End;

  If Opts.DebugMode Then
    PrintToken(CurToken);
End;

(* ============================================================
   TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
   ============================================================ *)

(* ---- ExprMakeImm : valeur immediate constante ------------- *)
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := AVal;
  Res.TypeIdx := ATypeIdx;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ExprMakeNone : valeur invalide (void / nil) ---------- *)
Procedure ExprMakeNone(Var Res : TExprVal);
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_IDX_NIL;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ExprMakeBool : valeur booleenne (true=1, false=0) ---- *)
Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  If AVal <> 0 Then
    Res.ImmVal := 1
  Else
    Res.ImmVal := 0;
  Res.TypeIdx := TY_IDX_BOOL;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- DataAddWord : ajouter un mot DW au segment DATA ------ *)
Function DataAddWord(Const Lbl : TString;
                     AIntVal : LongInt) : Integer;
Begin
  DataAddWord := DataAdd(Lbl, DK_WORD, AIntVal, '');
End;

(* ---- KwFind : chercher un keyword dans KwTab --------------- *)
(* Retourne l indice (0-base) ou -1 si non trouve.             *)
Function KwFind(Const Name : TString) : Integer;
Var I : Integer;
Begin
  For I := 0 To KwCount - 1 Do
    If KwTab[I] = Name Then
    Begin
      KwFind := I;
      Exit;
    End;
  KwFind := -1;
End;

(* ---- KwAdd : ajouter un keyword dans KwTab ----------------- *)
(* Retourne l indice (reutilise un existant si deja present).   *)
Function KwAdd(Const Name : TString) : Integer;
Var Idx : Integer;
Begin
  Idx := KwFind(Name);
  If Idx >= 0 Then
  Begin
    KwAdd := Idx;
    Exit;
  End;
  If KwCount >= MAX_KW Then
  Begin
    CompileError('table des keywords pleine (max=' + IntToStr(MAX_KW) + ')');
    KwAdd := -1;
    Exit;
  End;
  KwTab[KwCount] := Name;
  KwAdd := KwCount;
  Inc(KwCount);
End;

(* ---- LitEvalInt : evaluer un token TK_INTEGER -------------- *)
(* IntVal est deja calcule par LexScanNumber (dec/hex/oct).     *)
Procedure LitEvalInt(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeImm(T.IntVal, TY_IDX_INT, Res);
End;

(* ---- LitEvalChar : evaluer un token TK_CHAR ---------------- *)
(* IntVal contient le code ASCII du caractere (\a \newline etc) *)
Procedure LitEvalChar(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeImm(T.IntVal, TY_IDX_CHAR, Res);
End;

(* ---- LitEvalKW : evaluer un token TK_KEYWORD --------------- *)
(* Enregistre le keyword dans KwTab et retourne son index.      *)
Procedure LitEvalKW(Const T : TToken; Var Res : TExprVal);
Var Idx : Integer;
Begin
  Idx := KwAdd(T.Val);
  ExprMakeImm(Idx, TY_IDX_KW, Res);
End;

(* ---- LitEval : dispatcher principal pour les litteraux ------ *)
(* Tokens acceptes : TK_INTEGER, TK_STRING, TK_TRUE, TK_FALSE, *)
(* TK_NIL, TK_CHAR, TK_KEYWORD.                                *)
Procedure LitEval(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeNone(Res);  (* valeur par defaut *)
  Case T.Kind Of
    TK_INTEGER :
      LitEvalInt(T, Res);

    TK_STRING :
    Begin
      DataAddStr(T.Val);
      Res.Kind    := EK_MEM;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_STR;
      Res.Offset  := DataCount - 1;
      Res.SymIdx  := -1;
    End;

    TK_TRUE :
      ExprMakeBool(1, Res);

    TK_FALSE :
      ExprMakeBool(0, Res);

    TK_NIL :
      ExprMakeImm(0, TY_IDX_NIL, Res);

    TK_CHAR :
      LitEvalChar(T, Res);

    TK_KEYWORD :
      LitEvalKW(T, Res);
  End;
End;

(* ============================================================
   TODO 04 - READER MACROS ET FORMES SPECIALES DE LECTURE [IMPLEMENTE]
   ============================================================
   Fonctions exposees :
     SkipForm        -- sauter recursivement une forme Clojure (pour #_)
     ReadList        -- lire (a b c) jusqu au ) -> compte les elements
     ReadVector      -- lire [a b c] jusqu au ] -> compte les elements
     ReadMap         -- lire {:a 1 :b 2} jusqu a l accolade fermante
     ReadSet         -- lire #{1 2 3} jusqu a l accolade fermante
     ReadQuote       -- 'expr  -> traiter comme (quote expr)
     ReadSyntaxQuote -- `expr  -> traiter comme (quasiquote expr)
     ReadUnquote     -- ~expr / ~@expr -> traiter comme unquote
     ReadDeref       -- @expr  -> traiter comme (deref expr)
     ReadMeta        -- ^{:k v} ou ^:tag -> lire et ignorer l annotation
     ReadDispatch    -- #"regex" #{} #() #' etc
     ReadForm        -- dispatcher principal : lit une forme selon le token
   ============================================================ *)

(* ---- SkipForm : sauter recursivement une forme Clojure ----- *)
(* Utilisee pour #_ (comment macro). Saute un token atomique    *)
(* ou une forme composee complete (liste, vecteur, map, set).   *)
Procedure SkipForm;
Var Depth : Integer;
Begin
  Case CurToken.Kind Of
    TK_LPAREN :
    Begin
      Depth := 1;
      While (Depth > 0) And (CurToken.Kind <> TK_EOF) Do
      Begin
        LexNextToken;
        If CurToken.Kind = TK_LPAREN Then Inc(Depth);
        If CurToken.Kind = TK_RPAREN Then Dec(Depth);
      End;
    End;
    TK_LBRACKET :
    Begin
      Depth := 1;
      While (Depth > 0) And (CurToken.Kind <> TK_EOF) Do
      Begin
        LexNextToken;
        If CurToken.Kind = TK_LBRACKET Then Inc(Depth);
        If CurToken.Kind = TK_RBRACKET Then Dec(Depth);
      End;
    End;
    TK_LBRACE :
    Begin
      Depth := 1;
      While (Depth > 0) And (CurToken.Kind <> TK_EOF) Do
      Begin
        LexNextToken;
        If CurToken.Kind = TK_LBRACE Then Inc(Depth);
        If CurToken.Kind = TK_RBRACE Then Dec(Depth);
      End;
    End;
  Else
    (* Token atomique : deja consomme, rien a faire *)
  End;
End;

(* ---- ReadList : lire une liste (e1 e2 ... eN) -------------- *)
(* CurToken doit etre TK_LPAREN a l entree.                    *)
(* Lit les sous-formes jusqu a TK_RPAREN.                       *)
(* ECount retourne le nombre d elements lus.                    *)
Procedure ReadList(Var ECount : Integer);
Var Sub : TExprVal;
Begin
  ECount := 0;
  LexNextToken;  (* consommer le ( *)
  While (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Do
  Begin
    ReadForm(Sub);
    Inc(ECount);
    LexNextToken;
  End;
  (* CurToken est ) ou EOF *)
  If CurToken.Kind <> TK_RPAREN Then
    CompileError(') attendue en fin de liste');
End;

(* ---- ReadVector : lire un vecteur [e1 e2 ... eN] ----------- *)
(* CurToken doit etre TK_LBRACKET a l entree.                  *)
Procedure ReadVector(Var ECount : Integer);
Var Sub : TExprVal;
Begin
  ECount := 0;
  LexNextToken;  (* consommer le [ *)
  While (CurToken.Kind <> TK_RBRACKET) And (CurToken.Kind <> TK_EOF) Do
  Begin
    ReadForm(Sub);
    Inc(ECount);
    LexNextToken;
  End;
  If CurToken.Kind <> TK_RBRACKET Then
    CompileError('] attendu en fin de vecteur');
End;

(* ---- ReadMap : lire une map accolade-ouvrante :a 1 :b 2 accolade-fermante *)
(* CurToken doit etre TK_LBRACE a l entree.                    *)
(* Lit des paires cle/valeur ; ECount = nombre de paires.       *)
Procedure ReadMap(Var ECount : Integer);
Var Sub : TExprVal;
    Cnt : Integer;
Begin
  ECount := 0;
  Cnt := 0;
  LexNextToken;  (* consommer l accolade ouvrante *)
  While (CurToken.Kind <> TK_RBRACE) And (CurToken.Kind <> TK_EOF) Do
  Begin
    ReadForm(Sub);
    Inc(Cnt);
    LexNextToken;
  End;
  If CurToken.Kind <> TK_RBRACE Then
    CompileError('accolade fermante attendue en fin de map');
  If (Cnt Mod 2) <> 0 Then
    CompileError('nombre impair d elements dans une map');
  ECount := Cnt Div 2;
End;

(* ---- ReadSet : lire un ensemble #accolade e1 e2 ... accolade-fermante *)
(* CurToken doit etre TK_LBRACE a l entree (le # a ete consomme). *)
Procedure ReadSet(Var ECount : Integer);
Var Sub : TExprVal;
Begin
  ECount := 0;
  LexNextToken;  (* consommer l accolade ouvrante *)
  While (CurToken.Kind <> TK_RBRACE) And (CurToken.Kind <> TK_EOF) Do
  Begin
    ReadForm(Sub);
    Inc(ECount);
    LexNextToken;
  End;
  If CurToken.Kind <> TK_RBRACE Then
    CompileError('accolade fermante attendue en fin d ensemble');
End;

(* ---- ReadQuote : 'expr -> traitement comme (quote expr) ----- *)
(* CurToken doit etre TK_QUOTE a l entree.                     *)
(* Lit la forme suivante et l evalue comme constante quotee.     *)
Procedure ReadQuote;
Var Sub : TExprVal;
Begin
  LexNextToken;  (* consommer le ' *)
  ReadForm(Sub);
  (* Pour l instant, quote retourne la valeur litterale          *)
  (* Le traitement complet (liste quotee etc.) sera dans TODO 10 *)
End;

(* ---- ReadSyntaxQuote : `expr -> (quasiquote expr) ----------- *)
(* Syntax-quote est utilise pour les macros. En l absence de     *)
(* macro-expansion reelle, on traite comme un quote simple.      *)
Procedure ReadSyntaxQuote;
Var Sub : TExprVal;
Begin
  LexNextToken;  (* consommer le ` *)
  ReadForm(Sub);
  If Opts.Warnings Then
    WarnMsg('syntax-quote non entierement supporte, traite comme quote');
End;

(* ---- ReadUnquote : ~expr ou ~@expr -> (unquote[-splice] expr) *)
Procedure ReadUnquote;
Var Sub : TExprVal;
Begin
  (* CurToken est TK_UNQUOTE ou TK_UNQUOTE_SPLICE *)
  LexNextToken;  (* consommer ~ ou ~@ *)
  ReadForm(Sub);
  If Opts.Warnings Then
    WarnMsg('unquote hors d un syntax-quote, ignore');
End;

(* ---- ReadDeref : @expr -> (deref expr) ---------------------- *)
(* Deref est utilise pour les atomes (atom). Pour l instant,     *)
(* on lit simplement la sous-forme.                              *)
Procedure ReadDeref;
Var Sub : TExprVal;
Begin
  LexNextToken;  (* consommer le @ *)
  ReadForm(Sub);
  (* Le code de deref sera genere dans TODO 10/17 *)
End;

(* ---- ReadMeta : ^annotation forme -> lire et ignorer le meta *)
(* ^:tag expr ou ^accolade-ouvrante :k v accolade-fermante expr *)
Procedure ReadMeta;
Var Sub   : TExprVal;
    ECnt  : Integer;
Begin
  LexNextToken;  (* consommer le ^ *)
  (* Lire l annotation *)
  If CurToken.Kind = TK_LBRACE Then
    ReadMap(ECnt)      (* ^accolade :k v accolade -> ignorer *)
  Else If CurToken.Kind = TK_KEYWORD Then
    (* ^:tag -> ignorer le keyword *)
  Else If CurToken.Kind = TK_SYMBOL Then
    (* ^Type -> ignorer le type hint *)
  Else
    CompileError('metadata attendue apres ^');
  (* Lire la forme annotee *)
  LexNextToken;
  ReadForm(Sub);
End;

(* ---- ReadDispatch : # suivi de divers caracteres ------------ *)
(* #"regex" -> avertissement                                     *)
(* #accolade -> ensemble litteral (hash-set)                     *)
(* #( -> fonction anonyme courte (avertissement)                 *)
(* #' -> var quote                                               *)
(* #_ -> skip form (deja gere dans le lexeur, securite ici)     *)
Procedure ReadDispatch;
Var Sub  : TExprVal;
    ECnt : Integer;
Begin
  LexNextToken;  (* consommer le # et lire le token suivant *)
  If CurToken.Kind = TK_LBRACE Then
  Begin
    (* #{...} -> hash-set *)
    ReadSet(ECnt);
    (* Le set sera construit dans DATA par TODO 20 *)
  End
  Else If CurToken.Kind = TK_LPAREN Then
  Begin
    (* #(...) -> fonction anonyme courte *)
    If Opts.Warnings Then
      WarnMsg('#() fonctions anonymes courtes non supportees, lu comme liste');
    ReadList(ECnt);
  End
  Else If CurToken.Kind = TK_STRING Then
  Begin
    (* #"regex" -> avertissement *)
    If Opts.Warnings Then
      WarnMsg('#"..." expressions regulieres non supportees');
  End
  Else If (CurToken.Kind = TK_QUOTE) Then
  Begin
    (* #'sym -> var quote *)
    LexNextToken;  (* consommer ' apres # *)
    ReadForm(Sub);
    (* Traitement var quote dans TODO 10 *)
  End
  Else
  Begin
    (* Dispatch inconnu : avertissement *)
    If Opts.Warnings Then
      WarnMsg('dispatch # non reconnu : ' + CurToken.Val);
  End;
End;

(* ---- ReadForm : dispatcher principal du reader Clojure ------ *)
(* Lit une forme Clojure complete a partir de CurToken.          *)
(* - Litteraux : entier, chaine, char, keyword, true/false/nil  *)
(* - Symboles : identifiants Clojure                             *)
(* - Listes : (...)                                              *)
(* - Vecteurs : [...]                                            *)
(* - Maps : accolade-ouvrante ... accolade-fermante              *)
(* - Reader macros : ' ` ~ ~@ @ ^ #                             *)
Procedure ReadForm(Var Res : TExprVal);
Var ECnt : Integer;
Begin
  ExprMakeNone(Res);
  Case CurToken.Kind Of
    (* Litteraux *)
    TK_INTEGER,
    TK_STRING,
    TK_TRUE,
    TK_FALSE,
    TK_NIL,
    TK_CHAR,
    TK_KEYWORD :
      LitEval(CurToken, Res);

    (* Symbole *)
    TK_SYMBOL :
    Begin
      (* Pour l instant on ne resout pas les symboles ; *)
      (* Le lookup et le codegen viendront dans TODO 10 *)
      Res.Kind    := EK_NONE;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_SYM;
      Res.Offset  := 0;
      Res.SymIdx  := -1;
    End;

    (* Collections *)
    TK_LPAREN   : ReadList(ECnt);
    TK_LBRACKET : ReadVector(ECnt);
    TK_LBRACE   : ReadMap(ECnt);

    (* Reader macros *)
    TK_QUOTE          : ReadQuote;
    TK_SYNTAX_QUOTE   : ReadSyntaxQuote;
    TK_UNQUOTE        : ReadUnquote;
    TK_UNQUOTE_SPLICE : ReadUnquote;
    TK_DEREF          : ReadDeref;
    TK_META           : ReadMeta;
    TK_DISPATCH       : ReadDispatch;

    TK_RPAREN :
      CompileError(') inattendue');
    TK_RBRACKET :
      CompileError('] inattendu');
    TK_RBRACE :
      CompileError('accolade fermante inattendue');

    TK_EOF : ;  (* fin de fichier *)
  End;
End;

(* ============================================================
   TODO 05 - TABLE DES SYMBOLES ET ENVIRONNEMENTS [IMPLEMENTE]
   ============================================================ *)

(* ---- SymNameClean : nettoyer les caracteres non valides en MASM --- *)
(* Les symboles Clojure peuvent contenir - ! ? * + / < > = etc.      *)
(* On remplace par _ pour obtenir un identifiant ASM valide.          *)
Function SymNameClean(Const Name : TString) : TString;
Var
  I : Integer;
  R : TString;
  C : Char;
Begin
  R := '';
  For I := 1 To Length(Name) Do
  Begin
    C := Name[I];
    If ((C >= 'A') And (C <= 'Z')) Or
       ((C >= 'a') And (C <= 'z')) Or
       ((C >= '0') And (C <= '9')) Or
       (C = '_') Then
    Begin
      If Length(R) < MAX_STR Then
        R := R + C;
    End
    Else
    Begin
      (* Remplacer les caracteres speciaux par _ *)
      If Length(R) < MAX_STR Then
        R := R + '_';
    End;
  End;
  If R = '' Then R := '_anon';
  SymNameClean := R;
End;

(* ---- SymMangle : calculer le nom ASM mangled selon le Kind ------- *)
(* SK_VAR   -> _CLV_ + nom nettoye (variable globale)                *)
(* SK_FN    -> _CLF_ + nom nettoye (fonction)                        *)
(* SK_MACRO -> _CLV_ + nom nettoye (macro traite comme var)          *)
(* SK_LOCAL -> _CLV_ + nom nettoye (locale via let/fn param)         *)
(* SK_NS    -> _CLV_ + nom nettoye (namespace)                       *)
(* SK_SPECIAL -> pas de label ASM (forme speciale interne)           *)
(* SK_KEYWORD -> _CLKW_ + nom nettoye                                *)
Function SymMangle(Const Name : TString; Kind : TSymKind) : TString;
Var
  Clean : TString;
Begin
  Clean := SymNameClean(Name);
  Case Kind Of
    SK_VAR     : SymMangle := CL_VAR_PFX + Clean;
    SK_FN      : SymMangle := CL_FN_PFX  + Clean;
    SK_LOCAL   : SymMangle := CL_VAR_PFX + Clean;
    SK_KEYWORD : SymMangle := CL_KW_PFX  + Clean;
    SK_NS      : SymMangle := CL_VAR_PFX + Clean;
    SK_MACRO   : SymMangle := CL_VAR_PFX + Clean;
    SK_SPECIAL : SymMangle := '';   (* formes speciales : pas de label *)
  Else
    SymMangle := CL_VAR_PFX + Clean;
  End;
End;

(* ---- SymFind : rechercher un symbole par nom (MRU first) --------- *)
(* Parcourt la table du plus recent au plus ancien pour respecter     *)
(* le shadowing des environnements lexicaux (let, fn).                *)
Function SymFind(Const Name : TString) : Integer;
Var I : Integer;
Begin
  For I := SymCount - 1 DownTo 0 Do
    If SymTab[I].Name = Name Then
    Begin
      SymFind := I;
      Exit;
    End;
  SymFind := -1;
End;

(* ---- SymFindInScope : rechercher un symbole dans un scope precis - *)
Function SymFindInScope(Const Name : TString;
                        Level : Integer) : Integer;
Var I : Integer;
Begin
  For I := SymCount - 1 DownTo 0 Do
    If (SymTab[I].Name = Name) And
       (SymTab[I].ScopeLevel = Level) Then
    Begin
      SymFindInScope := I;
      Exit;
    End;
  SymFindInScope := -1;
End;

(* ---- SymAdd : ajouter un symbole dans la table ------------------- *)
(* Retourne l indice du symbole (0-base) ou -1 en cas d erreur.      *)
Function SymAdd(Const Name : TString; Kind : TSymKind;
                TypeIdx, Offset : Integer) : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    CompileError('table des symboles pleine (max=' +
                 IntToStr(MAX_SYM) + ')');
    SymAdd := -1;
    Exit;
  End;
  SymTab[SymCount].Name        := Name;
  SymTab[SymCount].MangledName := SymMangle(Name, Kind);
  SymTab[SymCount].Kind        := Kind;
  SymTab[SymCount].TypeIdx     := TypeIdx;
  SymTab[SymCount].ScopeLevel  := CurScope;
  SymTab[SymCount].Offset      := Offset;
  SymTab[SymCount].IsConst     := False;
  SymTab[SymCount].Namespace   := '';
  SymTab[SymCount].DeclLine    := CurToken.Line;

  If Opts.DebugMode Then
    WriteLn('  SYM_ADD[', SymCount, ']: ', Name,
            ' kind=', Ord(Kind),
            ' scope=', CurScope,
            ' -> ', SymTab[SymCount].MangledName);

  SymAdd := SymCount;
  Inc(SymCount);
  Inc(TotalSyms);
End;

(* ---- SymEnterScope : entrer dans une nouvelle portee ------------- *)
(* Chaque let, fn, loop cree un nouvel environnement lexical.        *)
Procedure SymEnterScope;
Begin
  If ScopeTop >= MAX_SCOPE Then
  Begin
    CompileError('portees trop imbriquees (max=' +
                 IntToStr(MAX_SCOPE) + ')');
    Exit;
  End;
  ScopeStack[ScopeTop] := SymCount;
  Inc(ScopeTop);
  Inc(CurScope);
  If Opts.DebugMode Then
    WriteLn('  SCOPE_ENTER: level=', CurScope);
End;

(* ---- SymLeaveScope : quitter la portee courante ------------------ *)
(* Les symboles locaux de cette portee sont retires de la table.      *)
Procedure SymLeaveScope;
Begin
  If ScopeTop <= 0 Then Exit;
  Dec(ScopeTop);
  SymCount := ScopeStack[ScopeTop];
  Dec(CurScope);
  If Opts.DebugMode Then
    WriteLn('  SCOPE_LEAVE: level=', CurScope);
End;

(* ---- IsSpecialForm : est-ce une forme speciale Clojure ? ---------- *)
(* Les formes speciales sont traitees directement par le compilateur   *)
(* et ne peuvent pas etre redefinies par l utilisateur.                *)
Function IsSpecialForm(Const Name : TString) : Boolean;
Begin
  IsSpecialForm :=
    (Name = 'def') Or (Name = 'defn') Or (Name = 'defmacro') Or
    (Name = 'fn') Or (Name = 'fn*') Or
    (Name = 'let') Or (Name = 'let*') Or
    (Name = 'if') Or (Name = 'do') Or
    (Name = 'when') Or (Name = 'when-not') Or
    (Name = 'cond') Or (Name = 'case') Or
    (Name = 'if-let') Or (Name = 'when-let') Or
    (Name = 'recur') Or (Name = 'loop') Or
    (Name = 'dotimes') Or (Name = 'doseq') Or (Name = 'while') Or
    (Name = 'quote') Or (Name = 'var') Or
    (Name = 'try') Or (Name = 'catch') Or (Name = 'finally') Or
    (Name = 'throw') Or (Name = 'new') Or
    (Name = 'set!') Or
    (Name = 'monitor-enter') Or (Name = 'monitor-exit') Or
    (Name = '.') Or (Name = 'import');
End;

(* ============================================================
   TODO 06 - SYSTEME DE TYPES INTERNES (TAGS) [IMPLEMENTE]
   ============================================================ *)

(* TypeKindOf : retourner le TTypeKind associe a un indice de type *)
Function TypeKindOf(TypeIdx : Integer) : TTypeKind;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeKindOf := TypeTab[TypeIdx].Kind
  Else
    TypeKindOf := TKC_UNKNOWN;
End;

(* TypeSizeof : taille en octets d un type                        *)
(* En 16 bits, toutes les valeurs Clojure tiennent dans un word   *)
(* (AX = entier, pointeur near, ou tag+payload)                   *)
Function TypeSizeof(TypeIdx : Integer) : Integer;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeSizeof := TypeTab[TypeIdx].Size
  Else
    TypeSizeof := 2;
End;

(* TypeMangle : prefixe ASM selon le tag/type pour les labels data *)
(* Permet de differencier les blocs dans le segment DATA           *)
Function TypeMangle(TypeIdx : Integer) : TString;
Begin
  Case TypeKindOf(TypeIdx) Of
    TKC_NIL      : TypeMangle := '_CLN_';
    TKC_INT      : TypeMangle := '_CLI_';
    TKC_STRING   : TypeMangle := '_CLS_';
    TKC_BOOLEAN  : TypeMangle := '_CLB_';
    TKC_KEYWORD  : TypeMangle := '_CLKW_';
    TKC_SYMBOL   : TypeMangle := '_CLSY_';
    TKC_LIST     : TypeMangle := '_CLL_';
    TKC_VECTOR   : TypeMangle := '_CLVD_';
    TKC_MAP      : TypeMangle := '_CLMD_';
    TKC_SET      : TypeMangle := '_CLSD_';
    TKC_FUNCTION : TypeMangle := '_CLF_';
    TKC_CHAR     : TypeMangle := '_CLCH_';
  Else
    TypeMangle := '_CLX_';  (* inconnu *)
  End;
End;

(* TypeIsNumeric : vrai si le type est comparable a un nombre     *)
(* En Clojure, seuls int et char sont numeriques                   *)
(* (boolean n est PAS numerique, contrairement a d autres langages) *)
Function TypeIsNumeric(TypeIdx : Integer) : Boolean;
Var
  K : TTypeKind;
Begin
  K := TypeKindOf(TypeIdx);
  TypeIsNumeric := (K = TKC_INT) Or (K = TKC_CHAR);
End;

(* TypeIsPtr : vrai si le type est un pointeur near vers le heap  *)
(* string, list, vector, map, set, function sont des pointeurs    *)
Function TypeIsPtr(TypeIdx : Integer) : Boolean;
Var
  K : TTypeKind;
Begin
  K := TypeKindOf(TypeIdx);
  TypeIsPtr :=
    (K = TKC_STRING)   Or (K = TKC_LIST)     Or
    (K = TKC_VECTOR)   Or (K = TKC_MAP)      Or
    (K = TKC_SET)      Or (K = TKC_FUNCTION);
End;

(* TypeIsTruthy : le type est-il toujours truthy en Clojure ?       *)
(* nil : toujours falsy. boolean : depend de la valeur (false=0).  *)
(* Tout autre type est toujours truthy (int, string, list, etc.)   *)
(* Retourne True si le type est certainement truthy sans verifier  *)
(* la valeur. Pour TKC_NIL retourne False (toujours falsy).        *)
(* Pour TKC_BOOLEAN retourne False (faut verifier la valeur).      *)
Function TypeIsTruthy(TypeIdx : Integer) : Boolean;
Var
  K : TTypeKind;
Begin
  K := TypeKindOf(TypeIdx);
  If K = TKC_NIL Then
    TypeIsTruthy := False       (* nil est toujours falsy *)
  Else If K = TKC_BOOLEAN Then
    TypeIsTruthy := False       (* false est falsy, true est truthy -> runtime *)
  Else
    TypeIsTruthy := True;       (* tout le reste est toujours truthy *)
End;

(* TypeCanCoerce : peut-on convertir SrcIdx vers DstIdx ?          *)
(* Clojure est dynamiquement type -> la plupart des coercitions    *)
(* sont possibles a l execution via le runtime                     *)
Function TypeCanCoerce(SrcIdx, DstIdx : Integer) : Boolean;
Begin
  (* meme type -> toujours OK *)
  If SrcIdx = DstIdx Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  (* tout -> UNKNOWN est OK (perd l info de type) *)
  If DstIdx = TY_UNKNOWN Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  (* nil -> tout type : nil est une valeur valide partout *)
  If SrcIdx = TY_IDX_NIL Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  (* int <-> char : meme representation 16 bits *)
  If ((SrcIdx = TY_IDX_INT)  And (DstIdx = TY_IDX_CHAR)) Or
     ((SrcIdx = TY_IDX_CHAR) And (DstIdx = TY_IDX_INT)) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  (* int/char -> bool : toute valeur non nulle = true *)
  If (DstIdx = TY_IDX_BOOL) And TypeIsNumeric(SrcIdx) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  (* bool -> int : false=0, true=1 *)
  If (DstIdx = TY_IDX_INT) And (SrcIdx = TY_IDX_BOOL) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  (* int/char/bool/keyword -> string : via str runtime *)
  If (DstIdx = TY_IDX_STR) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  (* function -> int/char/bool : coercition invalide *)
  If (SrcIdx = TY_IDX_FN) And TypeIsNumeric(DstIdx) Then
  Begin
    TypeCanCoerce := False;
    Exit;
  End;
  (* Clojure est dynamiquement type : la plupart des autres      *)
  (* coercitions sont gerees a l execution par le runtime         *)
  TypeCanCoerce := False;
End;

(* TypeCoerceResult : deduire le type de resultat d une op binaire *)
(* basee sur les types des operandes et l operateur                *)
Function TypeCoerceResult(LeftIdx, RightIdx : Integer;
                          Const Op : TString) : Integer;
Var
  LK, RK : TTypeKind;
Begin
  LK := TypeKindOf(LeftIdx);
  RK := TypeKindOf(RightIdx);

  (* Operateurs de comparaison -> toujours booleen *)
  If (Op = '=')   Or (Op = 'not=') Or (Op = '==') Or
     (Op = '<')   Or (Op = '>')    Or
     (Op = '<=')  Or (Op = '>=')   Or
     (Op = 'identical?') Then
  Begin
    TypeCoerceResult := TY_IDX_BOOL;
    Exit;
  End;

  (* Operateurs logiques -> booleen *)
  If (Op = 'and') Or (Op = 'or') Or (Op = 'not') Then
  Begin
    (* en Clojure, and/or retournent la derniere valeur evaluee *)
    (* mais pour la verification de type, on simplifie en bool  *)
    TypeCoerceResult := TY_IDX_BOOL;
    Exit;
  End;

  (* Predicats -> booleen *)
  If (Op = 'nil?')  Or (Op = 'zero?') Or (Op = 'pos?')   Or
     (Op = 'neg?')  Or (Op = 'even?') Or (Op = 'odd?')   Or
     (Op = 'empty?') Or (Op = 'instance?') Then
  Begin
    TypeCoerceResult := TY_IDX_BOOL;
    Exit;
  End;

  (* Operateurs arithmetiques : si les deux sont numeriques -> int *)
  If (Op = '+') Or (Op = '-') Or (Op = '*') Or
     (Op = '/') Or (Op = 'mod') Or (Op = 'rem') Then
  Begin
    If TypeIsNumeric(LeftIdx) And TypeIsNumeric(RightIdx) Then
    Begin
      TypeCoerceResult := TY_IDX_INT;
      Exit;
    End;
    (* str : + avec une chaine -> concatenation en Clojure via (str ..) *)
    If (Op = '+') And ((LK = TKC_STRING) Or (RK = TKC_STRING)) Then
    Begin
      TypeCoerceResult := TY_IDX_STR;
      Exit;
    End;
    TypeCoerceResult := TY_UNKNOWN;
    Exit;
  End;

  (* inc/dec -> int *)
  If (Op = 'inc') Or (Op = 'dec') Then
  Begin
    TypeCoerceResult := TY_IDX_INT;
    Exit;
  End;

  (* Collections constructors *)
  If (Op = 'cons')  Or (Op = 'list') Or (Op = 'rest') Or
     (Op = 'seq')   Or (Op = 'map')  Or (Op = 'filter') Or
     (Op = 'reduce') Then
  Begin
    TypeCoerceResult := TY_IDX_LIST;
    Exit;
  End;

  If (Op = 'vector') Or (Op = 'conj') Then
  Begin
    TypeCoerceResult := TY_IDX_VEC;
    Exit;
  End;

  If (Op = 'hash-map') Or (Op = 'assoc') Or (Op = 'dissoc') Then
  Begin
    TypeCoerceResult := TY_IDX_MAP;
    Exit;
  End;

  If (Op = 'hash-set') Then
  Begin
    TypeCoerceResult := TY_IDX_SET;
    Exit;
  End;

  (* str -> string *)
  If Op = 'str' Then
  Begin
    TypeCoerceResult := TY_IDX_STR;
    Exit;
  End;

  (* first/nth/get -> type inconnu (depend du contenu) *)
  If (Op = 'first') Or (Op = 'nth') Or (Op = 'get') Then
  Begin
    TypeCoerceResult := TY_UNKNOWN;
    Exit;
  End;

  (* count -> int *)
  If Op = 'count' Then
  Begin
    TypeCoerceResult := TY_IDX_INT;
    Exit;
  End;

  (* Par defaut : type inconnu pour les operateurs non geres *)
  TypeCoerceResult := TY_UNKNOWN;
End;

(* TypeInfer : deduire le type d une expression a partir de TExprVal *)
Function TypeInfer(Const E : TExprVal) : Integer;
Begin
  If E.TypeIdx <> TY_UNKNOWN Then
    TypeInfer := E.TypeIdx
  Else If E.Kind = EK_IMM Then
    TypeInfer := TY_IDX_INT
  Else
    TypeInfer := TY_UNKNOWN;
End;

(* TypeLookupName : chercher un type par nom dans TypeTab           *)
Function TypeLookupName(Const Name : TString) : Integer;
Var
  I : Integer;
Begin
  For I := 0 To TypeCount - 1 Do
    If TypeTab[I].Name = Name Then
    Begin
      TypeLookupName := I;
      Exit;
    End;
  TypeLookupName := TY_UNKNOWN;
End;

(* TypeInit : enregistrer les 12 types primitifs Clojure           *)
(* Chaque type a un tag (0..11) correspondant a TY_IDX_*           *)
(* En 8086 16 bits, toutes les valeurs occupent 2 octets (Word)    *)
(* sauf nil (0) et bool (1 octet logique, stocke dans AX=2 octets) *)
Procedure TypeInit;
Var
  I : Integer;
Begin
  TypeCount := 0;
  For I := 0 To MAX_TYPE - 1 Do
  Begin
    TypeTab[I].Name := '';
    TypeTab[I].Kind := TKC_UNKNOWN;
    TypeTab[I].Size := 0;
  End;

  (* TY_IDX_NIL = 0 : nil *)
  TypeTab[TY_IDX_NIL].Name := 'nil';
  TypeTab[TY_IDX_NIL].Kind := TKC_NIL;
  TypeTab[TY_IDX_NIL].Size := 2;

  (* TY_IDX_INT = 1 : entier 16 bits signe *)
  TypeTab[TY_IDX_INT].Name := 'int';
  TypeTab[TY_IDX_INT].Kind := TKC_INT;
  TypeTab[TY_IDX_INT].Size := 2;

  (* TY_IDX_STR = 2 : pointeur chaine *)
  TypeTab[TY_IDX_STR].Name := 'string';
  TypeTab[TY_IDX_STR].Kind := TKC_STRING;
  TypeTab[TY_IDX_STR].Size := 2;

  (* TY_IDX_BOOL = 3 : booleen 0/1 *)
  TypeTab[TY_IDX_BOOL].Name := 'boolean';
  TypeTab[TY_IDX_BOOL].Kind := TKC_BOOLEAN;
  TypeTab[TY_IDX_BOOL].Size := 2;

  (* TY_IDX_KW = 4 : keyword *)
  TypeTab[TY_IDX_KW].Name := 'keyword';
  TypeTab[TY_IDX_KW].Kind := TKC_KEYWORD;
  TypeTab[TY_IDX_KW].Size := 2;

  (* TY_IDX_SYM = 5 : symbole *)
  TypeTab[TY_IDX_SYM].Name := 'symbol';
  TypeTab[TY_IDX_SYM].Kind := TKC_SYMBOL;
  TypeTab[TY_IDX_SYM].Size := 2;

  (* TY_IDX_LIST = 6 : liste (cons cells) *)
  TypeTab[TY_IDX_LIST].Name := 'list';
  TypeTab[TY_IDX_LIST].Kind := TKC_LIST;
  TypeTab[TY_IDX_LIST].Size := 2;

  (* TY_IDX_VEC = 7 : vecteur *)
  TypeTab[TY_IDX_VEC].Name := 'vector';
  TypeTab[TY_IDX_VEC].Kind := TKC_VECTOR;
  TypeTab[TY_IDX_VEC].Size := 2;

  (* TY_IDX_MAP = 8 : hash-map *)
  TypeTab[TY_IDX_MAP].Name := 'map';
  TypeTab[TY_IDX_MAP].Kind := TKC_MAP;
  TypeTab[TY_IDX_MAP].Size := 2;

  (* TY_IDX_SET = 9 : hash-set *)
  TypeTab[TY_IDX_SET].Name := 'set';
  TypeTab[TY_IDX_SET].Kind := TKC_SET;
  TypeTab[TY_IDX_SET].Size := 2;

  (* TY_IDX_FN = 10 : fonction / closure *)
  TypeTab[TY_IDX_FN].Name := 'function';
  TypeTab[TY_IDX_FN].Kind := TKC_FUNCTION;
  TypeTab[TY_IDX_FN].Size := 2;

  (* TY_IDX_CHAR = 11 : caractere *)
  TypeTab[TY_IDX_CHAR].Name := 'char';
  TypeTab[TY_IDX_CHAR].Kind := TKC_CHAR;
  TypeTab[TY_IDX_CHAR].Size := 2;

  TypeCount := TY_PRIM_COUNT;
End;

(* ============================================================
   TODO 07 - EMETTEUR DE CODE ASM [IMPLEMENTE]
   ============================================================ *)

(* LabelGen : generer un label unique _CL_NNNNN *)
Function LabelGen : TString;
Var S : TString;
Begin
  Inc(LabelGenSeq);
  Str(LabelGenSeq, S);
  LabelGen := CL_LBL_PFX + S;
End;

(* EmitRaw : ecrire une ligne brute dans le fichier de sortie *)
Procedure EmitRaw(Const S : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, S);
End;

(* EmitBlankLine : ligne vide *)
Procedure EmitBlankLine;
Begin
  If OutFOpen Then
    WriteLn(OutF);
End;

(* EmitComment : commentaire ASM '; texte' *)
Procedure EmitComment(Const S : TString);
Begin
  EmitRaw('; ' + S);
End;

(* EmitLabel : label ASM suivi de ':' en colonne 0 *)
Procedure EmitLabel(Const Lbl : TString);
Begin
  EmitRaw(Lbl + ':');
End;

(* EmitInstr : instruction avec mnemonique + operandes (8 espaces) *)
Procedure EmitInstr(Const Mnem, Ops : TString);
Begin
  If Ops = '' Then
    EmitRaw('        ' + Mnem)
  Else
    EmitRaw('        ' + Mnem + ' ' + Ops);
End;

(* EmitInstrA : instruction + un operande *)
Procedure EmitInstrA(Const Mnem, A1 : TString);
Begin
  EmitRaw('        ' + Mnem + ' ' + A1);
End;

(* EmitInstrAB : instruction + deux operandes separes par virgule *)
Procedure EmitInstrAB(Const Mnem, A1, A2 : TString);
Begin
  EmitRaw('        ' + Mnem + ' ' + A1 + ',' + A2);
End;

(* EmitProlog : preambule de fonction (BP frame) *)
Procedure EmitProlog;
Begin
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
End;

(* EmitEpilog : epilogue de fonction (restaurer SP/BP et retourner) *)
Procedure EmitEpilog;
Begin
  EmitInstrAB('MOV', 'SP', 'BP');
  EmitInstrA('POP', 'BP');
  EmitInstr('RET', '');
End;

(* EmitOpen : ouvrir le fichier de sortie ASM *)
Procedure EmitOpen;
Begin
  {$I-}
  Assign(OutF, Opts.OutFile);
  Rewrite(OutF);
  {$I+}
  If IOResult <> 0 Then
    FatalError('impossible de creer ' + Opts.OutFile);
  OutFOpen := True;
End;

(* EmitHeader : en-tete du fichier ASM (.MODEL SMALL, _TEXT SEGMENT, *)
(*   point d entree _CLF_main avec initialisation DS)                *)
Procedure EmitHeader;
Begin
  EmitComment('=========================================================');
  EmitComment('Genere par CLOJ86 v' + CLOJ86_VERSION + ' (' + CLOJ86_DATE + ')');
  EmitComment('Source  : ' + Opts.SrcFile);
  EmitComment('Cible   : MASM 8086, modele SMALL');
  EmitComment('=========================================================');
  EmitBlankLine;
  EmitRaw('        .MODEL SMALL');
  EmitRaw('        .STACK ' + IntToStr(STACK_SIZE));
  EmitBlankLine;
  EmitRaw('_TEXT   SEGMENT WORD PUBLIC ''CODE''');
  EmitRaw('        ASSUME  CS:_TEXT, DS:_DATA, SS:NOTHING');
  EmitBlankLine;
  (* Point d entree principal *)
  EmitLabel('_CLF_main');
  EmitComment('--- initialisation DS ---');
  EmitInstrAB('MOV', 'AX', '_DATA');
  EmitInstrAB('MOV', 'DS', 'AX');
  EmitBlankLine;
End;

(* EmitDataSeg : emettre le segment de donnees _DATA *)
(* Inclut les chaines predefinies Clojure et les donnees utilisateur *)
Procedure EmitDataSeg;
Var
  I, J  : Integer;
  S, Tmp: TString;
  Ch    : Char;
  InQ   : Boolean;
  Need  : Boolean;
Begin
  EmitBlankLine;
  EmitRaw('_DATA   SEGMENT PUBLIC ''DATA''');
  EmitBlankLine;
  (* Chaines predefinies Clojure *)
  EmitRaw(CL_NIL_LBL   + '  DB ''nil'',0');
  EmitRaw(CL_TRUE_LBL  + '  DB ''true'',0');
  EmitRaw(CL_FALSE_LBL + '  DB ''false'',0');
  EmitRaw('_CL_CRLF    DB 13,10,0');
  EmitRaw('_CL_STRBUF  DB 256 DUP(0)');
  (* Heap pour cellules cons (TODO 17) *)
  EmitRaw('_CL_HEAP    DB 4096 DUP(0)');
  EmitRaw('_CL_HEAPTOP DW 0');
  (* Variables temporaires pour operations vecteur (TODO 18) *)
  EmitRaw('_CL_VTMP1   DW 0');
  EmitRaw('_CL_VTMP2   DW 0');
  (* Variables temporaires pour operations map (TODO 19) *)
  EmitRaw('_CL_MTMP1   DW 0');
  EmitRaw('_CL_MTMP2   DW 0');
  (* Variables temporaires pour operations set (TODO 20) *)
  EmitRaw('_CL_STMP1   DW 0');
  EmitRaw('_CL_STMP2   DW 0');
  (* Variables temporaires pour fonctions d ordre superieur (TODO 22) *)
  EmitRaw('_CL_HFTMP1  DW 0');
  EmitRaw('_CL_HFTMP2  DW 0');
  EmitRaw('_CL_HFTMP3  DW 0');
  (* Variables temporaires pour operations sur chaines (TODO 23) *)
  EmitRaw('_CL_SCTMP1  DW 0');
  EmitRaw('_CL_SCTMP2  DW 0');
  EmitRaw('_CL_SCTMP3  DW 0');
  EmitRaw('_CL_STRBUF2 DB 256 DUP(0)');
  EmitBlankLine;
  (* Donnees utilisateur *)
  For I := 0 To DataCount - 1 Do
  Begin
    Case DataTab[I].Kind Of
      DK_WORD :
      Begin
        If DataTab[I].StrVal <> '' Then
          S := DataTab[I].StrVal
        Else
          Str(DataTab[I].IntVal, S);
        EmitRaw(DataTab[I].LblName + '  DW ' + S);
      End;
      DK_BYTE :
        EmitRaw(DataTab[I].LblName + '  DB ' + DataTab[I].StrVal);
      DK_STR :
      Begin
        (* Emettre la chaine avec gestion des caracteres de controle *)
        S := DataTab[I].LblName + '  DB ';
        InQ  := False;
        Need := False;
        For J := 1 To Length(DataTab[I].StrVal) Do
        Begin
          Ch := DataTab[I].StrVal[J];
          If (Ord(Ch) >= 32) And (Ord(Ch) <= 126) And (Ch <> '''') Then
          Begin
            (* Caractere imprimable normal *)
            If Not InQ Then
            Begin
              If Need Then S := S + ',';
              S   := S + '''';
              InQ := True;
              Need := False;
            End;
            S := S + Ch;
          End
          Else
          Begin
            (* Caractere non imprimable ou apostrophe -> valeur decimale *)
            If InQ Then
            Begin
              S := S + '''';
              InQ := False;
            End;
            If Need Then S := S + ',';
            Str(Ord(Ch), Tmp);
            S := S + Tmp;
            Need := True;
          End;
        End;
        If InQ Then S := S + '''';
        If Need Or InQ Then S := S + ',';
        S := S + '0';
        EmitRaw(S);
      End;
      DK_LIST, DK_VEC, DK_MAP :
      Begin
        (* Bloc contigu de mots : ElemCount x DW 0 *)
        Str(DataTab[I].ElemCount, Tmp);
        EmitRaw(DataTab[I].LblName + '  DW ' + Tmp + ' DUP(0)');
      End;
    Else
      EmitRaw(DataTab[I].LblName + '  DW 0');
    End;
  End;
  EmitBlankLine;
  EmitRaw('_DATA   ENDS');
End;

(* EmitClose : terminer le fichier ASM *)
(* Emettre la sortie DOS, le runtime, _TEXT ENDS, le segment DATA, END *)
Procedure EmitClose;
Begin
  EmitBlankLine;
  EmitComment('--- sortie DOS ---');
  EmitInstrAB('MOV', 'AX', '4C00h');
  EmitInstr('INT', '21h');
  EmitBlankLine;
  (* Routines runtime *)
  EmitRuntime;
  EmitBlankLine;
  EmitRaw('_TEXT   ENDS');
  (* Segment de donnees *)
  EmitDataSeg;
  EmitBlankLine;
  EmitRaw('        END _CLF_main');
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

Function DataAdd(Const Lbl : TString; Kind : TDataKind;
                 AIntVal : LongInt; Const AStrVal : TString) : Integer;
Begin
  If DataCount >= MAX_DATA Then
  Begin
    FatalError('segment de donnees plein');
    DataAdd := -1;
    Exit;
  End;
  DataTab[DataCount].LblName   := Lbl;
  DataTab[DataCount].Kind      := Kind;
  DataTab[DataCount].IntVal    := AIntVal;
  DataTab[DataCount].StrVal    := AStrVal;
  DataTab[DataCount].ElemCount := 0;
  DataAdd := DataCount;
  Inc(DataCount);
End;

Function DataAddStr(Const S : TString) : TString;
Var Lbl : TString;
    Seq : TString;
Begin
  Inc(LabelSeq);
  Str(LabelSeq, Seq);
  Lbl := CL_STR_PFX + Seq;
  DataAdd(Lbl, DK_STR, 0, S);
  DataAddStr := Lbl;
End;

(* ============================================================
   TODO 08 - SEGMENT DE DONNEES ET STATIQUES [IMPLEMENTE]
   ============================================================ *)

(* DataAddList : ajouter un bloc liste (ElemCount mots DW contigus) *)
Function DataAddList(AElemCount : Integer) : TString;
Var Lbl : TString;
    Seq : TString;
    Idx : Integer;
Begin
  Inc(LabelSeq);
  Str(LabelSeq, Seq);
  Lbl := CL_LIST_PFX + Seq;
  Idx := DataAdd(Lbl, DK_LIST, 0, '');
  If Idx >= 0 Then
    DataTab[Idx].ElemCount := AElemCount;
  DataAddList := Lbl;
End;

(* DataAddVec : ajouter un bloc vecteur (ElemCount mots DW contigus) *)
Function DataAddVec(AElemCount : Integer) : TString;
Var Lbl : TString;
    Seq : TString;
    Idx : Integer;
Begin
  Inc(LabelSeq);
  Str(LabelSeq, Seq);
  Lbl := CL_VEC_PFX + Seq;
  Idx := DataAdd(Lbl, DK_VEC, 0, '');
  If Idx >= 0 Then
    DataTab[Idx].ElemCount := AElemCount;
  DataAddVec := Lbl;
End;

(* DataAddMap : ajouter un bloc map (APairCount paires cle/valeur = 2*N DW) *)
Function DataAddMap(APairCount : Integer) : TString;
Var Lbl : TString;
    Seq : TString;
    Idx : Integer;
Begin
  Inc(LabelSeq);
  Str(LabelSeq, Seq);
  Lbl := CL_MAP_PFX + Seq;
  Idx := DataAdd(Lbl, DK_MAP, 0, '');
  If Idx >= 0 Then
    DataTab[Idx].ElemCount := APairCount * 2; (* paire = cle + val = 2 DW *)
  DataAddMap := Lbl;
End;

(* DataInit : pre-populer le segment de donnees avec les constantes *)
(* Clojure predefinies. Appele apres SymInit dans Run.              *)
Procedure DataInit;
Begin
  DataAdd('_CL_NIL_S',   DK_STR, 0, 'nil');
  DataAdd('_CL_TRUE_S',  DK_STR, 0, 'true');
  DataAdd('_CL_FALSE_S', DK_STR, 0, 'false');
  DataAdd('_CL_EMPTY_S', DK_STR, 0, '');
  DataAdd('_CL_SPACE_S', DK_STR, 0, ' ');
  DataAdd('_CL_NL_S',    DK_BYTE, 0, '13,10,0');
  DataAdd('_CL_TMPBUF',  DK_BYTE, 0, '256 DUP(0)');
  DataAdd('_CL_NUMBUF',  DK_BYTE, 0, '12 DUP(0)');
  DataAdd('_CL_INBUF',   DK_BYTE, 0, '130 DUP(0)');  (* 2 octets DOS + 128 donnees *)
  DataAdd('_CL_SPACE',   DK_STR, 0, ' ');
End;

(* ============================================================
   TODO 09 - VARIABLES GLOBALES (def / defonce) [IMPLEMENTE]
   ============================================================ *)

(* ExprAddrOf : retourne la chaine d adressage MASM d un symbole *)
Function ExprAddrOf(SIdx : Integer) : TString;
Var Ofs : Integer;
    S   : TString;
Begin
  Ofs := SymTab[SIdx].Offset;
  If Ofs < 0 Then
  Begin
    Str(-Ofs, S);
    ExprAddrOf := 'WORD PTR [BP-' + S + ']';
  End
  Else If Ofs > 0 Then
  Begin
    Str(Ofs, S);
    ExprAddrOf := 'WORD PTR [BP+' + S + ']';
  End
  Else
    ExprAddrOf := '[' + SymTab[SIdx].MangledName + ']';
End;

(* ExprStore : stocker AX dans le symbole SIdx *)
Procedure ExprStore(SIdx : Integer);
Var Addr : TString;
Begin
  If SIdx < 0 Then Exit;
  If SymTab[SIdx].IsConst Then
  Begin
    CompileError('impossible de reassigner la constante "' +
                 SymTab[SIdx].Name + '"');
    Exit;
  End;
  Addr := ExprAddrOf(SIdx);
  EmitInstrAB('MOV', Addr, 'AX');
End;

(* ExprLoad : charger le symbole SIdx dans AX et initialiser Res *)
Procedure ExprLoad(SIdx : Integer; Var Res : TExprVal);
Var Addr : TString;
Begin
  Res.Kind    := EK_AX;
  Res.TypeIdx := SymTab[SIdx].TypeIdx;
  Res.ImmVal  := 0;
  Res.Offset  := SymTab[SIdx].Offset;
  Res.SymIdx  := SIdx;
  Addr := ExprAddrOf(SIdx);
  EmitInstrAB('MOV', 'AX', Addr);
End;

(* DeclAllocGlobal : creer un symbole variable globale SK_VAR *)
(* et enregistrer une entree DK_WORD dans le segment de donnees *)
Function DeclAllocGlobal(Const Name : TString) : Integer;
Var SIdx : Integer;
Begin
  SIdx := SymFind(Name);
  If (SIdx >= 0) And (SymTab[SIdx].Kind = SK_VAR) Then
  Begin
    If Opts.Warnings Then
      WarnMsg('redefinition de "' + Name + '"');
    DeclAllocGlobal := SIdx;
    Exit;
  End;
  SIdx := SymAdd(Name, SK_VAR, TY_UNKNOWN, 0);
  If SIdx >= 0 Then
    DataAddWord(SymTab[SIdx].MangledName, 0);
  DeclAllocGlobal := SIdx;
End;

(* ParseDef : traiter (def nom [valeur]) *)
(* Syntaxe : (def nom)                   *)
(*           (def nom valeur)             *)
(*           (def ^:const nom valeur)     *)
(*           (def ^:dynamic nom valeur)   *)
(*           (def ^:private nom valeur)   *)
Procedure ParseDef(Var Res : TExprVal);
Var
  Name    : TString;
  SIdx    : Integer;
  ValRes  : TExprVal;
  HasMeta : Boolean;
  IsCon   : Boolean;
  IsDyn   : Boolean;
  IsPriv  : Boolean;
  MetaKW  : TString;
Begin
  HasMeta := False;
  IsCon   := False;
  IsDyn   := False;
  IsPriv  := False;
  (* Detecter les metadata ^:keyword *)
  While CurToken.Kind = TK_META Do
  Begin
    HasMeta := True;
    LexNextToken;  (* consomme ^ *)
    If CurToken.Kind = TK_KEYWORD Then
    Begin
      MetaKW := CurToken.Val;
      If MetaKW = 'const' Then
        IsCon := True
      Else If MetaKW = 'dynamic' Then
        IsDyn := True
      Else If MetaKW = 'private' Then
        IsPriv := True
      Else If Opts.Warnings Then
        WarnMsg('metadata "' + MetaKW + '" ignoree sur def');
      LexNextToken;
    End
    Else
    Begin
      CompileError('keyword attendu apres ^');
      ExprMakeNone(Res);
      Exit;
    End;
  End;
  (* Lire le nom du symbole *)
  If CurToken.Kind <> TK_SYMBOL Then
  Begin
    CompileError('symbole attendu apres def');
    ExprMakeNone(Res);
    Exit;
  End;
  Name := CurToken.Val;
  LexNextToken;
  (* Allouer la variable globale *)
  SIdx := DeclAllocGlobal(Name);
  If SIdx < 0 Then
  Begin
    ExprMakeNone(Res);
    Exit;
  End;
  (* Metadata dynamic/private : avertissements *)
  If IsDyn Then
  Begin
    If Opts.Warnings Then
      WarnMsg('"^:dynamic ' + Name + '" : dynamic vars non supportees');
  End;
  If IsPriv Then
  Begin
    If Opts.DebugMode Then
      WriteLn('  DEF ^:private ', Name);
  End;
  (* Emission du commentaire *)
  EmitComment('(def ' + Name + ')');
  (* Verifier si constante deja definie (redefinition interdite) *)
  If SymTab[SIdx].IsConst And (Not IsCon) Then
  Begin
    CompileError('impossible de reassigner la constante "' + Name + '"');
    (* Consommer la valeur si presente *)
    If CurToken.Kind <> TK_RPAREN Then
      ParseForm(ValRes);
    ExprMakeNone(Res);
    Exit;
  End;
  (* Verifier s il y a une valeur initiale *)
  If CurToken.Kind = TK_RPAREN Then
  Begin
    (* (def nom) -> initialiser a nil = 0 *)
    EmitInstrAB('XOR', 'AX', 'AX');
    EmitInstrAB('MOV', ExprAddrOf(SIdx), 'AX');
    SymTab[SIdx].TypeIdx := TY_IDX_NIL;
  End
  Else
  Begin
    (* (def nom valeur) -> evaluer la valeur *)
    ParseForm(ValRes);
    ExprFlushToAX(ValRes);
    EmitInstrAB('MOV', ExprAddrOf(SIdx), 'AX');
    SymTab[SIdx].TypeIdx := ValRes.TypeIdx;
  End;
  (* Appliquer ^:const APRES l affectation initiale *)
  If IsCon Then
    SymTab[SIdx].IsConst := True;
  ExprMakeNone(Res);
End;

(* ParseDefonce : traiter (defonce nom valeur) *)
(* Comme def mais ne reassigne pas si la var existe deja *)
Procedure ParseDefonce(Var Res : TExprVal);
Var
  Name    : TString;
  SIdx    : Integer;
  ValRes  : TExprVal;
  LblSkip : TString;
Begin
  If CurToken.Kind <> TK_SYMBOL Then
  Begin
    CompileError('symbole attendu apres defonce');
    ExprMakeNone(Res);
    Exit;
  End;
  Name := CurToken.Val;
  LexNextToken;
  EmitComment('(defonce ' + Name + ')');
  (* Verifier si deja defini *)
  SIdx := SymFind(Name);
  If (SIdx >= 0) And (SymTab[SIdx].Kind = SK_VAR) Then
  Begin
    (* Variable existe deja : sauter l initialisation *)
    LblSkip := LabelGen;
    EmitInstrAB('CMP', ExprAddrOf(SIdx), '0');
    EmitInstrA('JNE', LblSkip);
    (* Evaluer la valeur *)
    If CurToken.Kind <> TK_RPAREN Then
    Begin
      ParseForm(ValRes);
      ExprFlushToAX(ValRes);
      ExprStore(SIdx);
      SymTab[SIdx].TypeIdx := ValRes.TypeIdx;
    End;
    EmitLabel(LblSkip);
  End
  Else
  Begin
    (* Premiere definition *)
    SIdx := DeclAllocGlobal(Name);
    If SIdx < 0 Then
    Begin
      ExprMakeNone(Res);
      Exit;
    End;
    If CurToken.Kind = TK_RPAREN Then
    Begin
      EmitInstrAB('XOR', 'AX', 'AX');
      ExprStore(SIdx);
      SymTab[SIdx].TypeIdx := TY_IDX_NIL;
    End
    Else
    Begin
      ParseForm(ValRes);
      ExprFlushToAX(ValRes);
      ExprStore(SIdx);
      SymTab[SIdx].TypeIdx := ValRes.TypeIdx;
    End;
  End;
  ExprMakeNone(Res);
End;

Procedure ExprFlushToAX(Const E : TExprVal);
Var S    : TString;
    Addr : TString;
Begin
  Case E.Kind Of
    EK_IMM :
    Begin
      If E.ImmVal = 0 Then
        EmitInstrAB('XOR', 'AX', 'AX')
      Else
      Begin
        Str(E.ImmVal, S);
        EmitInstrAB('MOV', 'AX', S);
      End;
    End;
    EK_MEM :
    Begin
      If E.SymIdx >= 0 Then
      Begin
        Addr := ExprAddrOf(E.SymIdx);
        If TypeIsPtr(E.TypeIdx) Then
          EmitInstrAB('LEA', 'AX', Addr)
        Else
          EmitInstrAB('MOV', 'AX', Addr);
      End
      Else If E.Offset >= 0 Then
      Begin
        (* Donnee DATA : chaine, vecteur, etc. - adresse via OFFSET *)
        EmitInstrAB('MOV', 'AX', 'OFFSET ' + DataTab[E.Offset].LblName);
      End
      Else
      Begin
        Str(-E.Offset, S);
        EmitInstrAB('MOV', 'AX', 'WORD PTR [BP-' + S + ']');
      End;
    End;
    EK_AX  : ;  (* deja dans AX *)
    EK_NONE : EmitInstrAB('XOR', 'AX', 'AX');  (* nil = 0 *)
  End;
End;

(* ============================================================
   TODO 10 - EXPRESSIONS PRIMAIRES [IMPLEMENTE]
   ============================================================ *)

(* ---- ParseQuote : (quote x) -> retourne x sans evaluation --- *)
(* En Clojure, (quote x) retourne x tel quel.                   *)
(* Pour un entier/chaine/nil/bool, c est le litteral.            *)
(* Pour un symbole, on retourne l index du symbole comme valeur. *)
Procedure ParseQuote(Var Res : TExprVal);
Var StrLbl : TString;
Begin
  ExprMakeNone(Res);
  Case CurToken.Kind Of
    TK_INTEGER :
    Begin
      LitEvalInt(CurToken, Res);
      LexNextToken;
    End;
    TK_STRING :
    Begin
      LitEval(CurToken, Res);
      LexNextToken;
    End;
    TK_CHAR :
    Begin
      LitEvalChar(CurToken, Res);
      LexNextToken;
    End;
    TK_KEYWORD :
    Begin
      LitEvalKW(CurToken, Res);
      LexNextToken;
    End;
    TK_TRUE :
    Begin
      ExprMakeBool(1, Res);
      LexNextToken;
    End;
    TK_FALSE :
    Begin
      ExprMakeBool(0, Res);
      LexNextToken;
    End;
    TK_NIL :
    Begin
      ExprMakeNone(Res);
      LexNextToken;
    End;
    TK_SYMBOL :
    Begin
      (* Symbole quote : retourner comme chaine *)
      StrLbl := DataAddStr(CurToken.Val);
      Res.Kind    := EK_MEM;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_SYM;
      Res.Offset  := DataCount - 1;
      Res.SymIdx  := -1;
      LexNextToken;
    End;
  Else
    Begin
      (* Forme complexe quotee : skip et retourner nil *)
      If CurToken.Kind = TK_LPAREN Then
        SkipForm
      Else
        LexNextToken;
    End;
  End;
End;

(* ---- ParseDo : (do expr1 expr2 ... exprN) ------------------- *)
(* Evalue toutes les expressions en sequence.                    *)
(* Retourne la valeur de la derniere expression.                 *)
Procedure ParseDo(Var Res : TExprVal);
Var Sub : TExprVal;
Begin
  ExprMakeNone(Res);
  EmitComment('(do ...)');
  While (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Do
  Begin
    ParseForm(Sub);
    ExprFlushToAX(Sub);
    Res := Sub;
  End;
  (* La derniere valeur est dans AX *)
  If Res.Kind <> EK_NONE Then
  Begin
    Res.Kind := EK_AX;
  End;
End;

(* ---- ParseIf : (if test then else?) ------------------------- *)
(* Evalue test. Si vrai (non-nil, non-false), evalue then.       *)
(* Sinon, evalue else (ou retourne nil si absent).               *)
Procedure ParseIf(Var Res : TExprVal);
Var
  TestRes, ThenRes, ElseRes : TExprVal;
  LblElse, LblEnd : TString;
Begin
  ExprMakeNone(Res);
  EmitComment('(if ...)');
  LblElse := LabelGen;
  LblEnd  := LabelGen;

  (* Evaluer la condition *)
  ParseForm(TestRes);
  ExprFlushToAX(TestRes);

  (* Test de verite Clojure : nil(0) et false(0) sont faux *)
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JE', LblElse);

  (* Branche THEN *)
  ParseForm(ThenRes);
  ExprFlushToAX(ThenRes);
  EmitInstrA('JMP', LblEnd);

  (* Branche ELSE *)
  EmitLabel(LblElse);
  If (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Then
  Begin
    ParseForm(ElseRes);
    ExprFlushToAX(ElseRes);
  End
  Else
  Begin
    (* Pas de branche else : retourner nil *)
    EmitInstrAB('XOR', 'AX', 'AX');
  End;

  EmitLabel(LblEnd);
  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_UNKNOWN;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseLet : (let [x val y val2 ...] body ...) ----------- *)
(* Cree un nouvel environnement lexical avec les liaisons.       *)
(* Evalue le body dans ce contexte et retourne la derniere val.  *)
Procedure ParseLet(Var Res : TExprVal);
Var
  VarName   : TString;
  VarSIdx   : Integer;
  ValRes    : TExprVal;
  Sub       : TExprVal;
  SaveFrame : Integer;
  Ofs       : Integer;
  S         : TString;
  (* TODO 21 : destructuration *)
  DestrucNames    : Array[0..MAX_DESTR - 1] Of TString;
  DestrucKinds    : Array[0..MAX_DESTR - 1] Of Integer;
  DestrucKwIdx    : Array[0..MAX_DESTR - 1] Of Integer;
  DestrucDefaults : Array[0..MAX_DESTR - 1] Of LongInt;
  DestrucCount    : Integer;
  HasDestrucRest  : Boolean;
  HasDestrucOr    : Boolean;
  I, J            : Integer;
  DOfs            : Integer;
  LblDef, LblEnd  : TString;
Begin
  ExprMakeNone(Res);
  EmitComment('(let [...] ...)');

  (* On attend un vecteur de liaisons [ ... ] *)
  If CurToken.Kind <> TK_LBRACKET Then
  Begin
    CompileError('vecteur de liaisons attendu apres let');
    Exit;
  End;
  LexNextToken;  (* consomme '[' *)

  SymEnterScope;
  SaveFrame := CurFrameSize;

  (* Traiter les paires nom/valeur avec allocation individuelle  *)
  (* SUB SP,2 pour chaque liaison AVANT l evaluation de la valeur *)
  (* afin de proteger l espace contre les PUSH temporaires.       *)
  (* Les liaisons sont sequentielles : chaque nom voit les prec.  *)
  (* Le shadowing est supporte naturellement par SymAdd.          *)
  (* TODO 21 : support destructuration [vec] et {map} en plus de  *)
  (*           symboles simples.                                   *)
  While (CurToken.Kind <> TK_RBRACKET) And (CurToken.Kind <> TK_EOF) Do
  Begin
    (* TODO 21 : destructuration vecteur ou map *)
    If (CurToken.Kind = TK_LBRACKET) Or (CurToken.Kind = TK_LBRACE) Then
    Begin
      (* On doit d abord lire le pattern, puis la valeur *)
      (* Sauvegarder le type de pattern *)

      (* Verification : la valeur doit suivre *)
      (* Consommer le pattern complet, puis evaluer la valeur *)
      (* Strategie : stocker la valeur dans un local temporaire, *)
      (* puis appeler EmitDestrucBind avec ce local.             *)

      (* Allouer un local pour la valeur a destructurer *)
      Inc(CurFrameSize, 2);
      Ofs := CurFrameSize;
      EmitInstrAB('SUB', 'SP', '2');

      (* On doit d abord sauter le pattern pour lire la valeur *)
      (* Mais le lexeur est sequentiel. On va plutot lire le    *)
      (* pattern et la valeur ensemble.                          *)
      (* Approche : lire et stocker le pattern, evaluer la val   *)
      (* puis generer le code de destructuration.                *)
      (* Simplification : on lit le pattern token par token      *)
      (* grace a EmitDestrucBind qui consomme les tokens.        *)

      (* PROBLEME : En Clojure, (let [[a b] expr] ...) signifie *)
      (* que [a b] est le pattern et expr est la valeur.         *)
      (* Le pattern vient AVANT la valeur.                       *)
      (* Il faut donc : 1) sauter le pattern (compter brackets)  *)
      (*                2) evaluer la valeur                      *)
      (*                3) revenir au pattern pour destructurer   *)
      (* MAIS on n a pas de backtracking dans le lexeur.          *)
      (*                                                          *)
      (* Alternative : on lit le pattern, on memorise les noms,  *)
      (* PUIS on evalue la valeur, PUIS on bind les noms.        *)
      (*                                                          *)
      (* Approche retenue : On saute d abord le pattern en       *)
      (* comptant la profondeur, puis on evalue la valeur, puis  *)
      (* on rejouera le pattern. MAIS pas de replay possible.    *)
      (*                                                          *)
      (* Approche finale utilisee : lire d abord les noms du     *)
      (* pattern dans un tableau, evaluer la valeur, puis         *)
      (* generer les bindings.                                    *)
      (*                                                          *)
      (* MAIS pour rester simple et compatible avec le lexeur     *)
      (* sans backtracking, on change l'ordre:                    *)
      (* Le pattern et la valeur arrivent dans cet ordre:         *)
      (*   [a b c] expr                                           *)
      (* On NE peut PAS evaluer expr avant d'avoir lu [a b c].   *)
      (* Donc on lit d abord le pattern en memorisant les noms,   *)
      (* puis on evalue expr, puis on genere le code.             *)

      If CurToken.Kind = TK_LBRACKET Then
      Begin
        (* Destructuration sequentielle *)
        LexNextToken;  (* consomme '[' *)
        I := 0;
        HasDestrucRest := False;
        While (CurToken.Kind <> TK_RBRACKET) And
              (CurToken.Kind <> TK_EOF) Do
        Begin
          If (CurToken.Kind = TK_SYMBOL) And (CurToken.Val = '&') Then
          Begin
            LexNextToken; (* consomme '&' *)
            HasDestrucRest := True;
            If CurToken.Kind = TK_SYMBOL Then
            Begin
              If I < MAX_DESTR Then
              Begin
                DestrucNames[I] := CurToken.Val;
                DestrucKinds[I] := 2; (* rest *)
                Inc(I);
              End;
              LexNextToken;
            End;
            Continue;
          End;
          If CurToken.Kind = TK_SYMBOL Then
          Begin
            If I < MAX_DESTR Then
            Begin
              DestrucNames[I] := CurToken.Val;
              If CurToken.Val = '_' Then
                DestrucKinds[I] := 1 (* skip *)
              Else
                DestrucKinds[I] := 0; (* normal *)
            End;
            Inc(I);
            LexNextToken;
          End
          Else
          Begin
            (* Nested destructuring not supported in this path *)
            CompileError('symbole attendu dans destructuration let');
            LexNextToken;
          End;
        End;
        DestrucCount := I;
        If CurToken.Kind = TK_RBRACKET Then
          LexNextToken; (* consomme ']' *)

        (* Maintenant evaluer la valeur *)
        If (CurToken.Kind = TK_RBRACKET) Or (CurToken.Kind = TK_EOF) Then
        Begin
          WarnMsg('valeur manquante pour destructuration let');
          Break;
        End;
        ParseForm(ValRes);
        ExprFlushToAX(ValRes);
        Str(Ofs, S);
        EmitInstrAB('MOV', 'WORD PTR [BP-' + S + ']', 'AX');

        (* Generer le code de destructuration *)
        For J := 0 To DestrucCount - 1 Do
        Begin
          If DestrucKinds[J] = 1 Then
            Continue;  (* _ : skip *)
          Inc(CurFrameSize, 2);
          DOfs := CurFrameSize;
          EmitInstrAB('SUB', 'SP', '2');

          If DestrucKinds[J] = 2 Then
          Begin
            (* & rest : sous-vecteur a partir de l'index J *)
            Str(Ofs, S);
            EmitInstrAB('MOV', 'AX', 'WORD PTR [BP-' + S + ']');
            Str(J, S);
            EmitInstrAB('MOV', 'BX', S);
            EmitInstrA('CALL', CL_RT_PFX + 'VECDROP');
            Str(DOfs, S);
            EmitInstrAB('MOV', 'WORD PTR [BP-' + S + ']', 'AX');
            SymAdd(DestrucNames[J], SK_LOCAL, TY_IDX_VEC, -DOfs);
          End
          Else
          Begin
            (* Normal : nth *)
            Str(Ofs, S);
            EmitInstrAB('MOV', 'AX', 'WORD PTR [BP-' + S + ']');
            Str(J, S);
            EmitInstrAB('MOV', 'BX', S);
            EmitInstrA('CALL', CL_RT_PFX + 'VECNTH');
            Str(DOfs, S);
            EmitInstrAB('MOV', 'WORD PTR [BP-' + S + ']', 'AX');
            SymAdd(DestrucNames[J], SK_LOCAL, TY_UNKNOWN, -DOfs);
          End;
        End;
      End
      Else
      Begin
        (* Destructuration associative {map} *)
        LexNextToken;  (* consomme '{' *)
        I := 0;
        HasDestrucOr := False;
        While (CurToken.Kind <> TK_RBRACE) And
              (CurToken.Kind <> TK_EOF) Do
        Begin
          (* :keys [a b c] *)
          If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'keys') Then
          Begin
            LexNextToken;  (* consomme :keys *)
            If CurToken.Kind = TK_LBRACKET Then
            Begin
              LexNextToken;  (* consomme '[' *)
              While (CurToken.Kind <> TK_RBRACKET) And
                    (CurToken.Kind <> TK_EOF) Do
              Begin
                If (CurToken.Kind = TK_SYMBOL) And (I < MAX_DESTR) Then
                Begin
                  DestrucNames[I] := CurToken.Val;
                  DestrucKinds[I] := 0;  (* :keys mode *)
                  DestrucKwIdx[I] := KwAdd(CurToken.Val);
                  DestrucDefaults[I] := 0;
                  Inc(I);
                End;
                LexNextToken;
              End;
              If CurToken.Kind = TK_RBRACKET Then
                LexNextToken; (* consomme ']' *)
            End;
            Continue;
          End;
          (* :or {a 0 b 1} *)
          If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'or') Then
          Begin
            LexNextToken;  (* consomme :or *)
            HasDestrucOr := True;
            If CurToken.Kind = TK_LBRACE Then
            Begin
              LexNextToken;  (* consomme '{' *)
              While (CurToken.Kind <> TK_RBRACE) And
                    (CurToken.Kind <> TK_EOF) Do
              Begin
                If CurToken.Kind = TK_SYMBOL Then
                Begin
                  VarName := CurToken.Val;
                  LexNextToken;
                  If CurToken.Kind = TK_INTEGER Then
                  Begin
                    For J := 0 To I - 1 Do
                    Begin
                      If DestrucNames[J] = VarName Then
                        DestrucDefaults[J] := CurToken.IntVal;
                    End;
                    LexNextToken;
                  End;
                End
                Else
                  LexNextToken;
              End;
              If CurToken.Kind = TK_RBRACE Then
                LexNextToken; (* consomme '}' *)
            End;
            Continue;
          End;
          (* Forme explicite : {x :nom y :age} *)
          If CurToken.Kind = TK_SYMBOL Then
          Begin
            If I < MAX_DESTR Then
            Begin
              DestrucNames[I] := CurToken.Val;
              DestrucKinds[I] := 3; (* explicit key binding *)
            End;
            LexNextToken;
            If CurToken.Kind = TK_KEYWORD Then
            Begin
              If I < MAX_DESTR Then
                DestrucKwIdx[I] := KwAdd(CurToken.Val);
              LexNextToken;
              If I < MAX_DESTR Then
              Begin
                DestrucDefaults[I] := 0;
                Inc(I);
              End;
            End
            Else
            Begin
              CompileError('keyword attendu apres symbole dans {map}');
            End;
            Continue;
          End;
          LexNextToken;
        End;
        DestrucCount := I;
        If CurToken.Kind = TK_RBRACE Then
          LexNextToken; (* consomme '}' *)

        (* Evaluer la valeur *)
        If (CurToken.Kind = TK_RBRACKET) Or (CurToken.Kind = TK_EOF) Then
        Begin
          WarnMsg('valeur manquante pour destructuration let');
          Break;
        End;
        ParseForm(ValRes);
        ExprFlushToAX(ValRes);
        Str(Ofs, S);
        EmitInstrAB('MOV', 'WORD PTR [BP-' + S + ']', 'AX');

        (* Generer le code de destructuration map *)
        For J := 0 To DestrucCount - 1 Do
        Begin
          Inc(CurFrameSize, 2);
          DOfs := CurFrameSize;
          EmitInstrAB('SUB', 'SP', '2');

          Str(Ofs, S);
          EmitInstrAB('MOV', 'AX', 'WORD PTR [BP-' + S + ']');
          Str(DestrucKwIdx[J], S);
          EmitInstrAB('MOV', 'BX', S);
          EmitInstrA('CALL', CL_RT_PFX + 'MAPGET');

          (* Appliquer default si :or present et valeur = nil *)
          If HasDestrucOr And (DestrucDefaults[J] <> 0) Then
          Begin
            LblDef := LabelGen;
            LblEnd := LabelGen;
            EmitInstrAB('CMP', 'AX', '0');
            EmitInstrA('JNE', LblEnd);
            Str(DestrucDefaults[J], S);
            EmitInstrAB('MOV', 'AX', S);
            EmitLabel(LblEnd);
          End;

          Str(DOfs, S);
          EmitInstrAB('MOV', 'WORD PTR [BP-' + S + ']', 'AX');
          SymAdd(DestrucNames[J], SK_LOCAL, TY_UNKNOWN, -DOfs);
        End;
      End;

      Continue;
    End;

    If CurToken.Kind <> TK_SYMBOL Then
    Begin
      CompileError('symbole attendu dans les liaisons let');
      LexNextToken;
      Continue;
    End;
    VarName := CurToken.Val;
    LexNextToken;

    (* Verification : nombre pair d elements dans le vecteur *)
    If (CurToken.Kind = TK_RBRACKET) Or (CurToken.Kind = TK_EOF) Then
    Begin
      WarnMsg('nombre impair d''elements dans le vecteur de liaisons let');
      Break;
    End;

    (* Allouer l emplacement local sur la pile AVANT l evaluation *)
    Inc(CurFrameSize, 2);
    Ofs := CurFrameSize;
    EmitInstrAB('SUB', 'SP', '2');

    (* Evaluer la valeur de la liaison *)
    ParseForm(ValRes);
    ExprFlushToAX(ValRes);

    (* Enregistrer le symbole et stocker la valeur *)
    VarSIdx := SymAdd(VarName, SK_LOCAL, ValRes.TypeIdx, -Ofs);
    If VarSIdx >= 0 Then
    Begin
      (* Stocker AX dans [BP-Ofs] *)
      Str(Ofs, S);
      EmitInstrAB('MOV', 'WORD PTR [BP-' + S + ']', 'AX');
    End;
  End;

  If CurToken.Kind = TK_RBRACKET Then
    LexNextToken  (* consomme ']' *)
  Else
    CompileError('] attendu en fin de liaisons let');

  (* Evaluer le body *)
  While (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Do
  Begin
    ParseForm(Sub);
    ExprFlushToAX(Sub);
    Res := Sub;
  End;
  If Res.Kind <> EK_NONE Then
    Res.Kind := EK_AX;

  (* Liberer l espace pile *)
  If CurFrameSize > SaveFrame Then
  Begin
    Str(CurFrameSize - SaveFrame, S);
    EmitInstrAB('ADD', 'SP', S);
  End;

  CurFrameSize := SaveFrame;
  SymLeaveScope;
End;

(* ---- ParseFnCall : (f arg1 arg2 ...) -> CALL _CLF_f --------- *)
(* Evalue chaque argument, le pousse sur la pile, puis CALL.      *)
(* Resultat dans AX apres le retour.                              *)
Procedure ParseFnCall(Const FnName : TString; FnSIdx : Integer;
                      Var Res : TExprVal);
Var
  ArgCount : Integer;
  ArgRes   : TExprVal;
  S        : TString;
  Lbl      : TString;
Begin
  ExprMakeNone(Res);
  EmitComment('(' + FnName + ' ...)');
  ArgCount := 0;

  (* Evaluer et empiler les arguments *)
  While (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Do
  Begin
    ParseForm(ArgRes);
    ExprFlushToAX(ArgRes);
    EmitInstrA('PUSH', 'AX');
    Inc(ArgCount);
  End;

  (* Appel de la fonction *)
  If FnSIdx >= 0 Then
    Lbl := SymTab[FnSIdx].MangledName
  Else
    Lbl := CL_FN_PFX + SymNameClean(FnName);
  EmitInstrA('CALL', Lbl);

  (* Nettoyer la pile des arguments *)
  If ArgCount > 0 Then
  Begin
    Str(ArgCount * 2, S);
    EmitInstrAB('ADD', 'SP', S);
  End;

  (* Resultat dans AX *)
  Res.Kind    := EK_AX;
  If FnSIdx >= 0 Then
    Res.TypeIdx := SymTab[FnSIdx].TypeIdx
  Else
    Res.TypeIdx := TY_UNKNOWN;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseForm : dispatcher principal de compilation --------- *)
(* Lit une forme Clojure et genere le code ASM correspondant.     *)
(* C est le point d entree de toute evaluation d expression.      *)
Procedure ParseForm(Var Res : TExprVal);
Var HeadSym : TString;
    SIdx    : Integer;
    Depth   : Integer;
Begin
  ExprMakeNone(Res);
  Case CurToken.Kind Of
    (* --- Litteraux --- *)
    TK_INTEGER :
    Begin
      LitEvalInt(CurToken, Res);
      LexNextToken;
    End;
    TK_STRING :
    Begin
      LitEval(CurToken, Res);
      LexNextToken;
    End;
    TK_CHAR :
    Begin
      LitEvalChar(CurToken, Res);
      LexNextToken;
    End;
    TK_KEYWORD :
    Begin
      LitEvalKW(CurToken, Res);
      LexNextToken;
    End;
    TK_TRUE :
    Begin
      ExprMakeBool(1, Res);
      LexNextToken;
    End;
    TK_FALSE :
    Begin
      ExprMakeBool(0, Res);
      LexNextToken;
    End;
    TK_NIL :
    Begin
      ExprMakeNone(Res);
      LexNextToken;
    End;

    (* --- Acces a une variable (symbole) --- *)
    TK_SYMBOL :
    Begin
      HeadSym := CurToken.Val;
      SIdx := SymFind(HeadSym);
      If SIdx >= 0 Then
        ExprLoad(SIdx, Res)
      Else
      Begin
        WarnMsg('symbole non defini "' + HeadSym + '"');
        ExprMakeNone(Res);
      End;
      LexNextToken;
    End;

    (* --- Forme parenthesee (forme speciale ou appel de fn) --- *)
    TK_LPAREN :
    Begin
      LexNextToken;  (* consomme '(' *)
      If CurToken.Kind = TK_SYMBOL Then
      Begin
        HeadSym := CurToken.Val;

        (* -- def -- *)
        If HeadSym = 'def' Then
        Begin
          LexNextToken;
          ParseDef(Res);
          If CurToken.Kind = TK_RPAREN Then LexNextToken
          Else CompileError(') attendue apres def');
          Exit;
        End

        (* -- defonce -- *)
        Else If HeadSym = 'defonce' Then
        Begin
          LexNextToken;
          ParseDefonce(Res);
          If CurToken.Kind = TK_RPAREN Then LexNextToken
          Else CompileError(') attendue apres defonce');
          Exit;
        End

        (* -- quote -- *)
        Else If HeadSym = 'quote' Then
        Begin
          LexNextToken;
          ParseQuote(Res);
          If CurToken.Kind = TK_RPAREN Then LexNextToken
          Else CompileError(') attendue apres quote');
          Exit;
        End

        (* -- do -- *)
        Else If HeadSym = 'do' Then
        Begin
          LexNextToken;
          ParseDo(Res);
          If CurToken.Kind = TK_RPAREN Then LexNextToken
          Else CompileError(') attendue apres do');
          Exit;
        End

        (* -- if -- *)
        Else If HeadSym = 'if' Then
        Begin
          LexNextToken;
          ParseIf(Res);
          If CurToken.Kind = TK_RPAREN Then LexNextToken
          Else CompileError(') attendue apres if');
          Exit;
        End

        (* -- when : (when test body...) comme (if test (do body...)) -- *)
        Else If HeadSym = 'when' Then
        Begin
          LexNextToken;
          EmitComment('(when ...)');
          ParseIf(Res);  (* when = if sans else *)
          If CurToken.Kind = TK_RPAREN Then LexNextToken
          Else CompileError(') attendue apres when');
          Exit;
        End

        (* -- TODO 13 : when-not / cond / case / if-let / when-let -- *)
        Else If HeadSym = 'when-not' Then
        Begin
          LexNextToken;
          ParseWhenNot(Res);
          If CurToken.Kind = TK_RPAREN Then LexNextToken
          Else CompileError(') attendue apres when-not');
          Exit;
        End
        Else If HeadSym = 'cond' Then
        Begin
          LexNextToken;
          ParseCond(Res);
          If CurToken.Kind = TK_RPAREN Then LexNextToken
          Else CompileError(') attendue apres cond');
          Exit;
        End
        Else If HeadSym = 'case' Then
        Begin
          LexNextToken;
          ParseCase(Res);
          If CurToken.Kind = TK_RPAREN Then LexNextToken
          Else CompileError(') attendue apres case');
          Exit;
        End
        Else If HeadSym = 'if-let' Then
        Begin
          LexNextToken;
          ParseIfLet(Res);
          If CurToken.Kind = TK_RPAREN Then LexNextToken
          Else CompileError(') attendue apres if-let');
          Exit;
        End
        Else If HeadSym = 'when-let' Then
        Begin
          LexNextToken;
          ParseWhenLet(Res);
          If CurToken.Kind = TK_RPAREN Then LexNextToken
          Else CompileError(') attendue apres when-let');
          Exit;
        End

        (* -- let / let* -- *)
        Else If (HeadSym = 'let') Or (HeadSym = 'let*') Then
        Begin
          LexNextToken;
          ParseLet(Res);
          If CurToken.Kind = TK_RPAREN Then LexNextToken
          Else CompileError(') attendue apres let');
          Exit;
        End

        (* -- TODO 15 : defn / fn -- *)
        Else If HeadSym = 'defn' Then
        Begin
          LexNextToken;
          ParseDefnForm(Res);
          If CurToken.Kind = TK_RPAREN Then LexNextToken
          Else CompileError(') attendue apres defn');
          Exit;
        End
        Else If (HeadSym = 'fn') Or (HeadSym = 'fn*') Then
        Begin
          LexNextToken;
          ParseFnForm(Res);
          If CurToken.Kind = TK_RPAREN Then LexNextToken
          Else CompileError(') attendue apres fn');
          Exit;
        End

        (* -- TODO 16 : loop / recur / dotimes / doseq / while -- *)
        Else If HeadSym = 'loop' Then
        Begin
          LexNextToken;
          ParseLoopForm(Res);
          If CurToken.Kind = TK_RPAREN Then LexNextToken
          Else CompileError(') attendue apres loop');
          Exit;
        End
        Else If HeadSym = 'recur' Then
        Begin
          LexNextToken;
          ParseRecurForm(Res);
          If CurToken.Kind = TK_RPAREN Then LexNextToken
          Else CompileError(') attendue apres recur');
          Exit;
        End
        Else If HeadSym = 'dotimes' Then
        Begin
          LexNextToken;
          ParseDotimesForm(Res);
          If CurToken.Kind = TK_RPAREN Then LexNextToken
          Else CompileError(') attendue apres dotimes');
          Exit;
        End
        Else If HeadSym = 'doseq' Then
        Begin
          LexNextToken;
          ParseDoseqForm(Res);
          If CurToken.Kind = TK_RPAREN Then LexNextToken
          Else CompileError(') attendue apres doseq');
          Exit;
        End
        Else If HeadSym = 'while' Then
        Begin
          LexNextToken;
          ParseWhileForm(Res);
          If CurToken.Kind = TK_RPAREN Then LexNextToken
          Else CompileError(') attendue apres while');
          Exit;
        End

        (* -- Appel de fonction (symbole connu ou inconnu) -- *)
        Else
        Begin
          SIdx := SymFind(HeadSym);
          LexNextToken;  (* consomme le nom de la fonction *)

          (* TODO 11 : dispatcher les operateurs arithmetiques *)
          If (HeadSym = '+') Or (HeadSym = '-') Or
             (HeadSym = '*') Or (HeadSym = '/') Then
          Begin
            ParseArith(HeadSym, Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres ' + HeadSym);
            Exit;
          End
          Else If (HeadSym = 'mod') Or (HeadSym = 'rem') Then
          Begin
            ParseMod(HeadSym, Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres ' + HeadSym);
            Exit;
          End
          Else If (HeadSym = 'inc') Or (HeadSym = 'dec') Then
          Begin
            ParseIncDec(HeadSym, Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres ' + HeadSym);
            Exit;
          End
          Else If (HeadSym = '=') Or (HeadSym = 'not=') Or
                  (HeadSym = '<') Or (HeadSym = '<=') Or
                  (HeadSym = '>') Or (HeadSym = '>=') Or
                  (HeadSym = '==') Then
          Begin
            ParseCompare(HeadSym, Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres ' + HeadSym);
            Exit;
          End
          Else If HeadSym = 'and' Then
          Begin
            ParseAnd(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres and');
            Exit;
          End
          Else If HeadSym = 'or' Then
          Begin
            ParseOr(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres or');
            Exit;
          End
          Else If HeadSym = 'not' Then
          Begin
            ParseNot(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres not');
            Exit;
          End
          Else If (HeadSym = 'min') Or (HeadSym = 'max') Then
          Begin
            ParseMinMax(HeadSym, Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres ' + HeadSym);
            Exit;
          End

          (* TODO 12 : dispatcher les fonctions d E/S *)
          Else If (HeadSym = 'println') Or (HeadSym = 'prn') Then
          Begin
            ParsePrintln(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres println');
            Exit;
          End
          Else If (HeadSym = 'print') Or (HeadSym = 'pr') Then
          Begin
            ParsePrint(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres print');
            Exit;
          End
          Else If HeadSym = 'newline' Then
          Begin
            ParseNewline(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres newline');
            Exit;
          End
          Else If HeadSym = 'read-line' Then
          Begin
            ParseReadLine(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres read-line');
            Exit;
          End
          Else If HeadSym = 'str' Then
          Begin
            ParseStr(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres str');
            Exit;
          End
          Else If HeadSym = 'pr-str' Then
          Begin
            ParsePrStr(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres pr-str');
            Exit;
          End
          Else If HeadSym = 'flush' Then
          Begin
            ParseFlush(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres flush');
            Exit;
          End

          (* TODO 17 : operations sur les listes *)
          Else If HeadSym = 'cons' Then
          Begin
            ParseConsForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres cons');
            Exit;
          End
          Else If HeadSym = 'first' Then
          Begin
            ParseFirstForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres first');
            Exit;
          End
          Else If HeadSym = 'rest' Then
          Begin
            ParseRestForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres rest');
            Exit;
          End
          Else If HeadSym = 'list' Then
          Begin
            ParseListForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres list');
            Exit;
          End
          Else If HeadSym = 'conj' Then
          Begin
            ParseConjListForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres conj');
            Exit;
          End
          Else If HeadSym = 'count' Then
          Begin
            ParseCountForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres count');
            Exit;
          End
          Else If HeadSym = 'nth' Then
          Begin
            ParseNthForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres nth');
            Exit;
          End
          Else If (HeadSym = 'empty?') Then
          Begin
            ParseEmptyForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres empty?');
            Exit;
          End
          Else If HeadSym = 'seq' Then
          Begin
            ParseSeqForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres seq');
            Exit;
          End

          (* TODO 18 : operations sur les vecteurs *)
          Else If HeadSym = 'vector' Then
          Begin
            ParseVectorForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres vector');
            Exit;
          End
          Else If HeadSym = 'get' Then
          Begin
            ParseGetForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres get');
            Exit;
          End
          Else If HeadSym = 'assoc' Then
          Begin
            ParseAssocForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres assoc');
            Exit;
          End
          Else If HeadSym = 'subvec' Then
          Begin
            ParseSubvecForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres subvec');
            Exit;
          End

          (* TODO 19 : operations sur les tables de hachage *)
          Else If HeadSym = 'hash-map' Then
          Begin
            ParseHashMapForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres hash-map');
            Exit;
          End
          Else If HeadSym = 'dissoc' Then
          Begin
            ParseDissocForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres dissoc');
            Exit;
          End
          Else If HeadSym = 'contains?' Then
          Begin
            ParseContainsForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres contains?');
            Exit;
          End
          Else If HeadSym = 'keys' Then
          Begin
            ParseKeysForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres keys');
            Exit;
          End
          Else If HeadSym = 'vals' Then
          Begin
            ParseValsForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres vals');
            Exit;
          End
          Else If HeadSym = 'merge' Then
          Begin
            ParseMergeForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres merge');
            Exit;
          End

          (* TODO 20 : operations sur les ensembles *)
          Else If HeadSym = 'hash-set' Then
          Begin
            ParseHashSetForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres hash-set');
            Exit;
          End
          Else If HeadSym = 'disj' Then
          Begin
            ParseDisjForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres disj');
            Exit;
          End
          Else If HeadSym = 'union' Then
          Begin
            ParseUnionForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres union');
            Exit;
          End
          Else If HeadSym = 'intersection' Then
          Begin
            ParseInterForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres intersection');
            Exit;
          End
          Else If HeadSym = 'difference' Then
          Begin
            ParseDiffForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres difference');
            Exit;
          End

          (* TODO 22 : fonctions d ordre superieur *)
          Else If HeadSym = 'map' Then
          Begin
            ParseMapHOFForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres map');
            Exit;
          End
          Else If HeadSym = 'filter' Then
          Begin
            ParseFilterForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres filter');
            Exit;
          End
          Else If HeadSym = 'reduce' Then
          Begin
            ParseReduceForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres reduce');
            Exit;
          End
          Else If HeadSym = 'remove' Then
          Begin
            ParseRemoveForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres remove');
            Exit;
          End
          Else If HeadSym = 'some' Then
          Begin
            ParseSomeForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres some');
            Exit;
          End
          Else If HeadSym = 'every?' Then
          Begin
            ParseEveryForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres every?');
            Exit;
          End
          Else If HeadSym = 'into' Then
          Begin
            ParseIntoForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres into');
            Exit;
          End
          Else If HeadSym = 'comp' Then
          Begin
            ParseCompForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres comp');
            Exit;
          End
          Else If HeadSym = 'partial' Then
          Begin
            ParsePartialForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres partial');
            Exit;
          End
          Else If HeadSym = 'constantly' Then
          Begin
            ParseConstantlyForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres constantly');
            Exit;
          End
          Else If HeadSym = 'identity' Then
          Begin
            ParseIdentityForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres identity');
            Exit;
          End

          (* TODO 23 : operations sur les chaines *)
          Else If HeadSym = 'subs' Then
          Begin
            ParseSubsForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres subs');
            Exit;
          End
          Else If (HeadSym = 'clojure.string/upper-case') Or
                  (HeadSym = 'upper-case') Then
          Begin
            ParseUpperCaseForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres upper-case');
            Exit;
          End
          Else If (HeadSym = 'clojure.string/lower-case') Or
                  (HeadSym = 'lower-case') Then
          Begin
            ParseLowerCaseForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres lower-case');
            Exit;
          End
          Else If (HeadSym = 'clojure.string/trim') Or
                  (HeadSym = 'string/trim') Then
          Begin
            ParseTrimForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres trim');
            Exit;
          End
          Else If (HeadSym = 'clojure.string/includes?') Or
                  (HeadSym = 'string/includes?') Then
          Begin
            ParseIncludesForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres includes?');
            Exit;
          End
          Else If (HeadSym = 'clojure.string/replace') Or
                  (HeadSym = 'string/replace') Then
          Begin
            ParseStrReplaceForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres replace');
            Exit;
          End
          Else If (HeadSym = 'clojure.string/split') Or
                  (HeadSym = 'string/split') Then
          Begin
            ParseSplitForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres split');
            Exit;
          End
          Else If (HeadSym = 'clojure.string/join') Or
                  (HeadSym = 'string/join') Then
          Begin
            ParseJoinForm(Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres join');
            Exit;
          End

          (* Appel de fonction generique *)
          Else If (SIdx >= 0) And
             ((SymTab[SIdx].Kind = SK_FN) Or
              (SymTab[SIdx].Kind = SK_VAR)) Then
          Begin
            ParseFnCall(HeadSym, SIdx, Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres appel de fonction');
            Exit;
          End
          Else
          Begin
            (* Symbole non reconnu : tenter un appel quand meme *)
            ParseFnCall(HeadSym, SIdx, Res);
            If CurToken.Kind = TK_RPAREN Then LexNextToken
            Else CompileError(') attendue apres appel');
            Exit;
          End;
        End;
      End
      Else
      Begin
        (* Liste dont la tete n est pas un symbole : sauter *)
        Depth := 1;
        While (Depth > 0) And (CurToken.Kind <> TK_EOF) Do
        Begin
          If CurToken.Kind = TK_LPAREN Then Inc(Depth);
          If CurToken.Kind = TK_RPAREN Then Dec(Depth);
          If Depth > 0 Then LexNextToken;
        End;
        If CurToken.Kind = TK_RPAREN Then
          LexNextToken;
      End;
    End;

    (* --- Reader macro : quote --- *)
    TK_QUOTE :
    Begin
      LexNextToken;  (* consomme ' *)
      ParseQuote(Res);
    End;

    (* --- Vecteur litteral [a b c] --- *)
    TK_LBRACKET :
    Begin
      LexNextToken;  (* consomme '[' *)
      ParseVecLiteral(Res);
    End;

    (* --- Map litteral {:a 1 :b 2} --- *)
    TK_LBRACE :
    Begin
      LexNextToken;  (* consomme accolade ouvrante *)
      ParseMapLiteral(Res);
    End;

    (* --- Ensemble litteral #{a b c} --- *)
    TK_DISPATCH :
    Begin
      If (Length(CurToken.Val) >= 2) And (CurToken.Val[2] = Chr(123)) Then
      Begin
        LexNextToken;  (* consomme le TK_DISPATCH *)
        LexNextToken;  (* consomme l accolade ouvrante TK_LBRACE *)
        ParseSetLiteral(Res);
      End
      Else
        LexNextToken;  (* dispatch non gere *)
    End;

  Else
    (* Token non gere : avancer *)
    LexNextToken;
  End;
End;

(* ============================================================
   TODO 11 - EXPRESSIONS ARITHMETIQUES ET COMPARAISONS [IMPLEMENTE]
   ============================================================ *)

(* ---- ParseArith : (+ a b) (- a b) (mul a b) (/ a b) -------- *)
(* Operateurs arithmetiques variadiques Clojure.                  *)
(* Premiere forme evaluee dans AX, puis accumulation iterative.   *)
(* (+ a b c) = a+b puis +c                                       *)
(* Sans argument : (+) = 0, (mul) = 1                             *)
(* Un seul argument : (+ x) = x, (- x) = -x                      *)
Procedure ParseArith(Const Op : TString; Var Res : TExprVal);
Var
  ArgRes   : TExprVal;
  ArgCount : Integer;
Begin
  ExprMakeNone(Res);
  EmitComment('(' + Op + ' ...)');
  ArgCount := 0;

  (* Verifier s il y a des arguments *)
  If (CurToken.Kind = TK_RPAREN) Or (CurToken.Kind = TK_EOF) Then
  Begin
    (* Pas d argument : identite de l operateur *)
    If (Op = '+') Or (Op = '-') Then
      ExprMakeImm(0, TY_IDX_INT, Res)    { (+) = 0, (-) = 0 }
    Else
      ExprMakeImm(1, TY_IDX_INT, Res);   { mul = 1, (/) = 1 }
    Exit;
  End;

  (* Premier argument *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  Inc(ArgCount);

  (* Un seul argument avec - : negation *)
  If (ArgCount = 1) And (Op = '-') And
     ((CurToken.Kind = TK_RPAREN) Or (CurToken.Kind = TK_EOF)) Then
  Begin
    EmitInstrA('NEG', 'AX');
    Res.Kind    := EK_AX;
    Res.TypeIdx := TY_IDX_INT;
    Res.ImmVal  := 0;
    Res.Offset  := 0;
    Res.SymIdx  := -1;
    Exit;
  End;

  (* Arguments suivants : accumulation *)
  While (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Do
  Begin
    EmitInstrA('PUSH', 'AX');        (* sauvegarder l accumulateur *)
    ParseForm(ArgRes);
    ExprFlushToAX(ArgRes);
    EmitInstrAB('MOV', 'BX', 'AX'); (* BX = nouvel argument *)
    EmitInstrA('POP', 'AX');         (* AX = accumulateur *)

    If Op = '+' Then
      EmitInstrAB('ADD', 'AX', 'BX')
    Else If Op = '-' Then
      EmitInstrAB('SUB', 'AX', 'BX')
    Else If Op = '*' Then
    Begin
      EmitInstrA('IMUL', 'BX');      { DX:AX = AX x BX }
    End
    Else If Op = '/' Then
    Begin
      EmitInstr('CWD', '');          (* signe-etend AX dans DX:AX *)
      EmitInstrA('IDIV', 'BX');      (* AX = quotient, DX = reste *)
    End;
    Inc(ArgCount);
  End;

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_INT;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseMod : (mod a b) / (rem a b) ----------------------- *)
(* Reste de la division entiere.                                   *)
(* mod : reste avec signe du diviseur (semantique Clojure)         *)
(* rem : reste avec signe du dividende (semantique Java)           *)
Procedure ParseMod(Const Op : TString; Var Res : TExprVal);
Var
  ArgA, ArgB : TExprVal;
Begin
  ExprMakeNone(Res);
  EmitComment('(' + Op + ' a b)');

  (* Premier argument *)
  ParseForm(ArgA);
  ExprFlushToAX(ArgA);
  EmitInstrA('PUSH', 'AX');

  (* Second argument *)
  ParseForm(ArgB);
  ExprFlushToAX(ArgB);
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitInstrA('POP', 'AX');

  (* Division : AX = quotient, DX = reste *)
  EmitInstr('CWD', '');
  EmitInstrA('IDIV', 'BX');
  EmitInstrAB('MOV', 'AX', 'DX');   (* AX = reste *)

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_INT;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseIncDec : (inc x) / (dec x) ------------------------ *)
(* Incremente ou decremente la valeur de 1.                       *)
Procedure ParseIncDec(Const Op : TString; Var Res : TExprVal);
Var ArgRes : TExprVal;
Begin
  ExprMakeNone(Res);
  EmitComment('(' + Op + ' x)');

  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);

  If Op = 'inc' Then
    EmitInstrAB('ADD', 'AX', '1')
  Else
    EmitInstrAB('SUB', 'AX', '1');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_INT;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseCompare : (= a b) (< a b) (> a b) etc. ----------- *)
(* Compare deux valeurs. Pour les entiers : CMP + SETcc.          *)
(* Pour les chaines : CALL _CLRT_STRCMP puis CMP AX,0 + SETcc.   *)
(* Resultat : AX=1 (true) ou AX=0 (false)                        *)
Procedure ParseCompare(Const Op : TString; Var Res : TExprVal);
Var
  ArgA, ArgB : TExprVal;
  LblTrue, LblEnd : TString;
  Jcc : TString;
Begin
  ExprMakeNone(Res);
  EmitComment('(' + Op + ' a b)');

  (* Evaluer les deux arguments *)
  ParseForm(ArgA);
  ExprFlushToAX(ArgA);
  EmitInstrA('PUSH', 'AX');

  ParseForm(ArgB);
  ExprFlushToAX(ArgB);
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitInstrA('POP', 'AX');

  (* Comparaison de chaines si les deux sont des pointeurs string *)
  If (TypeIsPtr(ArgA.TypeIdx)) Or (TypeIsPtr(ArgB.TypeIdx)) Then
  Begin
    (* AX = gauche, BX = droite -> CALL _CLRT_STRCMP *)
    EmitInstrAB('MOV', 'SI', 'AX');
    EmitInstrAB('MOV', 'DI', 'BX');
    EmitInstrA('CALL', CL_RT_PFX + 'STRCMP');
    (* AX contient le resultat : <0, 0, >0 *)
    EmitInstrAB('CMP', 'AX', '0');
  End
  Else
  Begin
    (* Comparaison entiere *)
    EmitInstrAB('CMP', 'AX', 'BX');
  End;

  (* Determiner le saut conditionnel *)
  LblTrue := LabelGen;
  LblEnd  := LabelGen;

  If      Op = '='    Then Jcc := 'JE'
  Else If Op = 'not=' Then Jcc := 'JNE'
  Else If Op = '<'    Then Jcc := 'JL'
  Else If Op = '<='   Then Jcc := 'JLE'
  Else If Op = '>'    Then Jcc := 'JG'
  Else If Op = '>='   Then Jcc := 'JGE'
  Else If Op = '=='   Then Jcc := 'JE'
  Else                     Jcc := 'JE';

  EmitInstrA(Jcc, LblTrue);
  EmitInstrAB('XOR', 'AX', 'AX');   (* false = 0 *)
  EmitInstrA('JMP', LblEnd);
  EmitLabel(LblTrue);
  EmitInstrAB('MOV', 'AX', '1');    (* true = 1 *)
  EmitLabel(LblEnd);

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_BOOL;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseAnd : (and a b ...) ------------------------------- *)
(* Court-circuit : retourne la premiere valeur fausse (nil/false) *)
(* ou la derniere valeur vraie. En Clojure, (and) -> true.        *)
Procedure ParseAnd(Var Res : TExprVal);
Var
  ArgRes  : TExprVal;
  LblFail : TString;
  LblEnd  : TString;
Begin
  ExprMakeNone(Res);
  EmitComment('(and ...)');
  LblFail := LabelGen;
  LblEnd  := LabelGen;

  (* (and) sans arguments -> true *)
  If (CurToken.Kind = TK_RPAREN) Or (CurToken.Kind = TK_EOF) Then
  Begin
    ExprMakeBool(1, Res);
    Exit;
  End;

  (* Evaluer les arguments avec court-circuit *)
  While (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Do
  Begin
    ParseForm(ArgRes);
    ExprFlushToAX(ArgRes);

    (* Verifier si dernier argument *)
    If (CurToken.Kind = TK_RPAREN) Or (CurToken.Kind = TK_EOF) Then
    Begin
      (* Dernier argument : la valeur reste dans AX *)
    End
    Else
    Begin
      (* Pas le dernier : tester la verite *)
      EmitInstrAB('CMP', 'AX', '0');
      EmitInstrA('JE', LblFail);   (* nil/false -> court-circuit *)
    End;
  End;
  EmitInstrA('JMP', LblEnd);

  EmitLabel(LblFail);
  EmitInstrAB('XOR', 'AX', 'AX');  (* retourner nil/false = 0 *)
  EmitLabel(LblEnd);

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_UNKNOWN;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseOr : (or a b ...) --------------------------------- *)
(* Court-circuit : retourne la premiere valeur vraie              *)
(* ou la derniere valeur. En Clojure, (or) -> nil.                *)
Procedure ParseOr(Var Res : TExprVal);
Var
  ArgRes   : TExprVal;
  LblTrue  : TString;
  LblEnd   : TString;
Begin
  ExprMakeNone(Res);
  EmitComment('(or ...)');
  LblTrue := LabelGen;
  LblEnd  := LabelGen;

  (* (or) sans arguments -> nil *)
  If (CurToken.Kind = TK_RPAREN) Or (CurToken.Kind = TK_EOF) Then
  Begin
    ExprMakeNone(Res);
    Exit;
  End;

  (* Evaluer les arguments avec court-circuit *)
  While (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Do
  Begin
    ParseForm(ArgRes);
    ExprFlushToAX(ArgRes);

    (* Verifier si dernier argument *)
    If (CurToken.Kind = TK_RPAREN) Or (CurToken.Kind = TK_EOF) Then
    Begin
      (* Dernier argument : la valeur reste dans AX *)
    End
    Else
    Begin
      (* Pas le dernier : tester la verite *)
      EmitInstrAB('CMP', 'AX', '0');
      EmitInstrA('JNE', LblTrue);  (* vrai -> court-circuit *)
    End;
  End;
  EmitInstrA('JMP', LblEnd);

  EmitLabel(LblTrue);
  (* AX contient deja la valeur vraie *)
  EmitLabel(LblEnd);

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_UNKNOWN;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseNot : (not x) ------------------------------------- *)
(* Si x est nil ou false -> true (1), sinon -> false (0)          *)
Procedure ParseNot(Var Res : TExprVal);
Var
  ArgRes  : TExprVal;
  LblTrue, LblEnd : TString;
Begin
  ExprMakeNone(Res);
  EmitComment('(not x)');

  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);

  LblTrue := LabelGen;
  LblEnd  := LabelGen;

  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JE', LblTrue);        (* nil/false -> retourne true *)
  EmitInstrAB('XOR', 'AX', 'AX');   (* false = 0 *)
  EmitInstrA('JMP', LblEnd);
  EmitLabel(LblTrue);
  EmitInstrAB('MOV', 'AX', '1');    (* true = 1 *)
  EmitLabel(LblEnd);

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_BOOL;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseMinMax : (min a b ...) / (max a b ...) ------------ *)
(* Retourne le minimum ou maximum de N arguments.                 *)
(* Accumulation iterative : compare chaque argument avec AX.      *)
Procedure ParseMinMax(Const Op : TString; Var Res : TExprVal);
Var
  ArgRes   : TExprVal;
  LblSkip  : TString;
Begin
  ExprMakeNone(Res);
  EmitComment('(' + Op + ' ...)');

  (* Premier argument *)
  If (CurToken.Kind = TK_RPAREN) Or (CurToken.Kind = TK_EOF) Then
  Begin
    WarnMsg(Op + ' sans argument');
    ExprMakeNone(Res);
    Exit;
  End;

  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);

  (* Arguments suivants : comparaison iteree *)
  While (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Do
  Begin
    EmitInstrA('PUSH', 'AX');        (* sauvegarder le min/max courant *)
    ParseForm(ArgRes);
    ExprFlushToAX(ArgRes);
    EmitInstrAB('MOV', 'BX', 'AX'); (* BX = nouvel argument *)
    EmitInstrA('POP', 'AX');         (* AX = min/max courant *)

    LblSkip := LabelGen;
    EmitInstrAB('CMP', 'AX', 'BX');
    If Op = 'min' Then
      EmitInstrA('JLE', LblSkip)     (* AX <= BX : garder AX *)
    Else
      EmitInstrA('JGE', LblSkip);    (* AX >= BX : garder AX *)
    EmitInstrAB('MOV', 'AX', 'BX'); (* sinon prendre BX *)
    EmitLabel(LblSkip);
  End;

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_INT;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ============================================================
   TODO 12 - ENTREES/SORTIES (println / print / read-line) [IMPLEMENTE]
   ============================================================ *)

(* ---- EmitPrintVal : emettre le code pour afficher AX ---------- *)
(* AX contient la valeur a imprimer. TypeIdx indique le type.      *)
(* Pour un entier, on appelle _CLRT_NUMTOSTR puis _CLRT_PRINTSTR.  *)
(* Pour une chaine (pointeur), on appelle directement _CLRT_PRINTSTR. *)
(* Pour un booleen, on charge l adresse 'true' ou 'false'.         *)
Procedure EmitPrintVal(TIdx : Integer);
Begin
  If TypeIsPtr(TIdx) Then
  Begin
    (* AX = pointeur vers chaine null-terminee *)
    EmitInstrAB('MOV', 'SI', 'AX');
    EmitInstrA('CALL', CL_RT_PFX + 'PRINTSTR');
  End
  Else If TIdx = TY_IDX_BOOL Then
  Begin
    (* AX = 0 ou 1 -> afficher 'true' ou 'false' *)
    EmitInstrA('CALL', CL_RT_PFX + 'PRINTBOOL');
  End
  Else If TIdx = TY_IDX_NIL Then
  Begin
    (* Afficher 'nil' *)
    EmitInstrAB('MOV', 'SI', 'OFFSET ' + CL_NIL_LBL);
    EmitInstrA('CALL', CL_RT_PFX + 'PRINTSTR');
  End
  Else
  Begin
    (* AX = entier signe -> convertir en ASCII puis afficher *)
    EmitInstrAB('MOV', 'DI', 'OFFSET _CL_NUMBUF');
    EmitInstrA('CALL', CL_RT_PFX + 'NUMTOSTR');
    EmitInstrAB('MOV', 'SI', 'DI');
    EmitInstrA('CALL', CL_RT_PFX + 'PRINTSTR');
  End;
End;

(* ---- ParsePrintln : (println expr ...) ------------------------ *)
(* Affiche chaque argument separe par un espace, puis CR+LF.       *)
(* (println) sans argument -> saut de ligne seul.                   *)
(* Retourne nil (AX = 0).                                          *)
Procedure ParsePrintln(Var Res : TExprVal);
Var
  ArgRes   : TExprVal;
  ArgCount : Integer;
Begin
  ExprMakeNone(Res);
  EmitComment('(println ...)');
  ArgCount := 0;

  (* Evaluer et afficher chaque argument *)
  While (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Do
  Begin
    (* Espace separateur avant chaque argument sauf le premier *)
    If ArgCount > 0 Then
      EmitInstrA('CALL', CL_RT_PFX + 'PRINTSPACE');

    ParseForm(ArgRes);
    ExprFlushToAX(ArgRes);
    EmitPrintVal(ArgRes.TypeIdx);
    Inc(ArgCount);
  End;

  (* Saut de ligne final *)
  EmitInstrA('CALL', CL_RT_PFX + 'WRITECRLF');

  (* Retourne nil *)
  EmitInstrAB('XOR', 'AX', 'AX');
  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_NIL;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParsePrint : (print expr ...) ----------------------------- *)
(* Comme println mais sans saut de ligne final.                      *)
Procedure ParsePrint(Var Res : TExprVal);
Var
  ArgRes   : TExprVal;
  ArgCount : Integer;
Begin
  ExprMakeNone(Res);
  EmitComment('(print ...)');
  ArgCount := 0;

  While (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Do
  Begin
    If ArgCount > 0 Then
      EmitInstrA('CALL', CL_RT_PFX + 'PRINTSPACE');

    ParseForm(ArgRes);
    ExprFlushToAX(ArgRes);
    EmitPrintVal(ArgRes.TypeIdx);
    Inc(ArgCount);
  End;

  (* Retourne nil *)
  EmitInstrAB('XOR', 'AX', 'AX');
  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_NIL;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseNewline : (newline) ---------------------------------- *)
(* Ecrire CR+LF seul. Retourne nil.                                 *)
Procedure ParseNewline(Var Res : TExprVal);
Begin
  ExprMakeNone(Res);
  EmitComment('(newline)');
  EmitInstrA('CALL', CL_RT_PFX + 'WRITECRLF');

  EmitInstrAB('XOR', 'AX', 'AX');
  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_NIL;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseReadLine : (read-line) ------------------------------- *)
(* Lire une ligne de texte depuis STDIN.                            *)
(* Utilise INT 21h AH=0Ah (lecture ligne bufferisee).               *)
(* Retourne AX = pointeur vers la chaine lue (null-terminee).       *)
Procedure ParseReadLine(Var Res : TExprVal);
Begin
  ExprMakeNone(Res);
  EmitComment('(read-line)');
  EmitInstrA('CALL', CL_RT_PFX + 'READLINE');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_STR;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseStr : (str expr ...) --------------------------------- *)
(* Concatener les representations en chaine de tous les arguments.   *)
(* (str) -> ""                                                       *)
(* (str 42) -> "42"                                                  *)
(* (str "hello" " " "world") -> "hello world"                        *)
(* Utilise _CL_STRBUF comme buffer de concatenation.                 *)
Procedure ParseStr(Var Res : TExprVal);
Var
  ArgRes   : TExprVal;
  ArgCount : Integer;
Begin
  ExprMakeNone(Res);
  EmitComment('(str ...)');

  (* Initialiser le buffer de sortie a vide *)
  EmitInstrAB('MOV', 'DI', 'OFFSET _CL_STRBUF');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');

  ArgCount := 0;

  (* (str) sans argument -> chaine vide *)
  If (CurToken.Kind = TK_RPAREN) Or (CurToken.Kind = TK_EOF) Then
  Begin
    EmitInstrAB('MOV', 'AX', 'OFFSET _CL_STRBUF');
    Res.Kind    := EK_AX;
    Res.TypeIdx := TY_IDX_STR;
    Res.ImmVal  := 0;
    Res.Offset  := 0;
    Res.SymIdx  := -1;
    Exit;
  End;

  While (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Do
  Begin
    ParseForm(ArgRes);
    ExprFlushToAX(ArgRes);

    (* Convertir la valeur en chaine si necessaire *)
    If TypeIsPtr(ArgRes.TypeIdx) Then
    Begin
      (* AX = deja un pointeur string *)
      EmitInstrAB('MOV', 'SI', 'AX');
    End
    Else If ArgRes.TypeIdx = TY_IDX_BOOL Then
    Begin
      (* Convertir booleen en chaine 'true'/'false' *)
      EmitInstrA('CALL', CL_RT_PFX + 'BOOLTOSTR');
      EmitInstrAB('MOV', 'SI', 'AX');
    End
    Else If ArgRes.TypeIdx = TY_IDX_NIL Then
    Begin
      EmitInstrAB('MOV', 'SI', 'OFFSET _CL_EMPTY_S');
    End
    Else
    Begin
      (* Entier -> convertir en ASCII *)
      EmitInstrAB('MOV', 'DI', 'OFFSET _CL_TMPBUF');
      EmitInstrA('CALL', CL_RT_PFX + 'NUMTOSTR');
      EmitInstrAB('MOV', 'SI', 'DI');
    End;

    (* Concatener SI a la fin de _CL_STRBUF *)
    EmitInstrAB('MOV', 'DI', 'OFFSET _CL_STRBUF');
    EmitInstrA('CALL', CL_RT_PFX + 'CONCAT');

    Inc(ArgCount);
  End;

  (* Retourner pointeur vers _CL_STRBUF *)
  EmitInstrAB('MOV', 'AX', 'OFFSET _CL_STRBUF');
  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_STR;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParsePrStr : (pr-str expr) -------------------------------- *)
(* Convertir une expression en sa representation lisible (chaine).   *)
(* Les chaines sont entourees de guillemets, les autres sont         *)
(* converties normalement. Retourne AX=ptr chaine.                   *)
Procedure ParsePrStr(Var Res : TExprVal);
Var
  ArgRes : TExprVal;
Begin
  ExprMakeNone(Res);
  EmitComment('(pr-str ...)');

  If (CurToken.Kind = TK_RPAREN) Or (CurToken.Kind = TK_EOF) Then
  Begin
    (* (pr-str) sans argument -> "" *)
    EmitInstrAB('MOV', 'AX', 'OFFSET _CL_EMPTY_S');
    Res.Kind    := EK_AX;
    Res.TypeIdx := TY_IDX_STR;
    Res.ImmVal  := 0;
    Res.Offset  := 0;
    Res.SymIdx  := -1;
    Exit;
  End;

  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);

  (* Convertir la valeur en representation lisible *)
  If TypeIsPtr(ArgRes.TypeIdx) Then
    EmitInstrAB('MOV', 'SI', 'AX')
  Else If ArgRes.TypeIdx = TY_IDX_BOOL Then
  Begin
    EmitInstrA('CALL', CL_RT_PFX + 'BOOLTOSTR');
    EmitInstrAB('MOV', 'SI', 'AX');
  End
  Else If ArgRes.TypeIdx = TY_IDX_NIL Then
    EmitInstrAB('MOV', 'SI', 'OFFSET ' + CL_NIL_LBL)
  Else
  Begin
    EmitInstrAB('MOV', 'DI', 'OFFSET _CL_NUMBUF');
    EmitInstrA('CALL', CL_RT_PFX + 'NUMTOSTR');
    EmitInstrAB('MOV', 'SI', 'DI');
  End;

  EmitInstrAB('MOV', 'AX', 'SI');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_STR;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseFlush : (flush) -------------------------------------- *)
(* Stub : pas de buffering sur DOS. Retourne nil.                    *)
Procedure ParseFlush(Var Res : TExprVal);
Begin
  ExprMakeNone(Res);
  EmitComment('(flush) - stub, no buffering on DOS');

  EmitInstrAB('XOR', 'AX', 'AX');
  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_NIL;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ============================================================
   TODO 13 - FORMES SPECIALES : IF / DO / WHEN / COND / CASE [IMPLEMENTE]
   ============================================================ *)

(* ---- ParseWhenNot : (when-not test body...) -------------------- *)
(* Inverse de when : evalue body seulement si test est faux.         *)
(* Equivalent a : (if (not test) (do body...) nil)                   *)
Procedure ParseWhenNot(Var Res : TExprVal);
Var
  TestRes, Sub : TExprVal;
  LblEnd : TString;
Begin
  ExprMakeNone(Res);
  EmitComment('(when-not ...)');
  LblEnd := LabelGen;

  (* Evaluer la condition *)
  ParseForm(TestRes);
  ExprFlushToAX(TestRes);

  (* Si vrai (non-zero) -> sauter le body (when-not = body quand test faux) *)
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JNE', LblEnd);

  (* Evaluer le body (toutes les expressions) *)
  While (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Do
  Begin
    ParseForm(Sub);
    ExprFlushToAX(Sub);
    Res := Sub;
  End;
  If Res.Kind <> EK_NONE Then
    Res.Kind := EK_AX;

  EmitLabel(LblEnd);
  If Res.Kind = EK_NONE Then
  Begin
    EmitInstrAB('XOR', 'AX', 'AX');
    Res.Kind    := EK_AX;
    Res.TypeIdx := TY_IDX_NIL;
    Res.ImmVal  := 0;
    Res.Offset  := 0;
    Res.SymIdx  := -1;
  End;
End;

(* ---- ParseCond : (cond test1 expr1 test2 expr2 ... :else exprN) --- *)
(* Cascade de tests : evalue test1, si vrai retourne expr1, sinon      *)
(* evalue test2, si vrai retourne expr2, etc. :else est la branche     *)
(* par defaut. Retourne nil si aucune branche ne correspond.           *)
Procedure ParseCond(Var Res : TExprVal);
Var
  TestRes, ValRes : TExprVal;
  LblNext, LblEnd : TString;
  IsElse : Boolean;
Begin
  ExprMakeNone(Res);
  EmitComment('(cond ...)');
  LblEnd := LabelGen;

  While (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Do
  Begin
    (* Verifier si c est la clause :else *)
    IsElse := False;
    If CurToken.Kind = TK_KEYWORD Then
    Begin
      If CurToken.Val = ':else' Then
        IsElse := True;
    End;

    If IsElse Then
    Begin
      (* :else -> evaluer la derniere expression *)
      LexNextToken;  (* consomme :else *)
      ParseForm(ValRes);
      ExprFlushToAX(ValRes);
      Res := ValRes;
      Res.Kind := EK_AX;
      EmitInstrA('JMP', LblEnd);
      (* Consommer les expressions restantes au cas ou *)
      While (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Do
        LexNextToken;
    End
    Else
    Begin
      LblNext := LabelGen;
      (* Evaluer le test *)
      ParseForm(TestRes);
      ExprFlushToAX(TestRes);
      EmitInstrAB('CMP', 'AX', '0');
      EmitInstrA('JE', LblNext);

      (* Test vrai : evaluer l expression resultat *)
      ParseForm(ValRes);
      ExprFlushToAX(ValRes);
      Res := ValRes;
      Res.Kind := EK_AX;
      EmitInstrA('JMP', LblEnd);

      EmitLabel(LblNext);
    End;
  End;

  (* Si aucune branche ne correspond, retourner nil *)
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitLabel(LblEnd);
  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_UNKNOWN;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseCase : (case expr val1 result1 val2 result2 ... default) - *)
(* Evalue expr, puis compare avec chaque val. Si egal, evalue le        *)
(* resultat correspondant. Sinon, evalue le default (ou nil).            *)
(* Les valeurs de match sont des constantes compilees.                   *)
(* Un element seul en derniere position est le default.                  *)
Procedure ParseCase(Var Res : TExprVal);
Var
  ExprRes, MatchRes, ValRes : TExprVal;
  LblNext, LblEnd, LblMatch : TString;
  S : TString;
  MatchCount : Integer;
  HeadSym2 : TString;
  SIdx2    : Integer;
Begin
  ExprMakeNone(Res);
  EmitComment('(case ...)');
  LblEnd := LabelGen;

  (* Evaluer l expression a matcher *)
  ParseForm(ExprRes);
  ExprFlushToAX(ExprRes);
  EmitInstrA('PUSH', 'AX');  (* sauvegarder sur la pile *)

  MatchCount := 0;

  (* Parcourir les paires val/result et detecter le default *)
  While (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Do
  Begin
    (* Cas special : liste de valeurs (val1 val2 ...) result *)
    If CurToken.Kind = TK_LPAREN Then
    Begin
      (* Regarder si c est une liste de constantes ou une forme par defaut *)
      (* En Clojure case, (1 2 3) est une liste de match, (fn ..) est default *)
      (* Heuristique : si le premier element de la liste est un litteral,       *)
      (* c est une liste de match. Sinon, c est une expression par defaut.     *)

      (* Sauvegarder la position pour pouvoir traiter comme default *)
      LblNext  := LabelGen;
      LblMatch := LabelGen;
      LexNextToken;  (* consomme '(' *)

      (* Verifier si le premier token est un litteral de match *)
      If (CurToken.Kind = TK_INTEGER) Or (CurToken.Kind = TK_KEYWORD) Or
         (CurToken.Kind = TK_STRING) Or (CurToken.Kind = TK_NIL) Or
         (CurToken.Kind = TK_TRUE) Or (CurToken.Kind = TK_FALSE) Then
      Begin
        (* Liste de valeurs a matcher *)
        Str(MatchCount, S);
        EmitComment('case match list #' + S);
        EmitInstrAB('MOV', 'BX', 'WORD PTR [SP]');
        While (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Do
        Begin
          ParseForm(MatchRes);
          ExprFlushToAX(MatchRes);
          EmitInstrAB('CMP', 'BX', 'AX');
          EmitInstrA('JE', LblMatch);
        End;
        If CurToken.Kind = TK_RPAREN Then LexNextToken;
        EmitInstrA('JMP', LblNext);
        EmitLabel(LblMatch);

        (* Evaluer le resultat *)
        ParseForm(ValRes);
        ExprFlushToAX(ValRes);
        Res := ValRes;
        Res.Kind := EK_AX;
        EmitInstrA('JMP', LblEnd);

        EmitLabel(LblNext);
        Inc(MatchCount);
      End
      Else
      Begin
        (* C est une expression par defaut parenthesee (ex: (println "x")) *)
        (* On doit parser le contenu comme une forme                       *)
        (* Remonter : on a deja consomme '(', il faut parser la forme       *)
        (* Le premier token est un symbole -> c est un appel de fonction    *)
        EmitComment('case default');

        If CurToken.Kind = TK_SYMBOL Then
        Begin
          (* Reconstruire le contexte de ParseForm pour une expression *)
          (* On est deja a l interieur du '(' - deleguer a ParseForm  *)
          (* en repassant par le dispatcher de formes                  *)
          Res.Kind := EK_NONE;

          HeadSym2 := CurToken.Val;
          SIdx2 := SymFind(HeadSym2);
          LexNextToken;

          (* Appeler le dispatcher de formes pour le contenu *)
          (* Traiter comme un appel de fonction *)
          If (SIdx2 >= 0) And
             ((SymTab[SIdx2].Kind = SK_FN) Or
              (SymTab[SIdx2].Kind = SK_VAR)) Then
          Begin
            ParseFnCall(HeadSym2, SIdx2, ValRes);
          End
          Else
          Begin
            (* Fonction inconnue : avertir *)
            WarnMsg('case default: symbole inconnu "' + HeadSym2 + '"');
            ExprMakeNone(ValRes);
            While (CurToken.Kind <> TK_RPAREN) And
                  (CurToken.Kind <> TK_EOF) Do
              LexNextToken;
          End;
          If CurToken.Kind = TK_RPAREN Then LexNextToken;
          ExprFlushToAX(ValRes);
          Res := ValRes;
          Res.Kind := EK_AX;
          EmitInstrA('JMP', LblEnd);
        End
        Else
        Begin
          (* Autre cas : ignorer *)
          While (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Do
            LexNextToken;
          If CurToken.Kind = TK_RPAREN Then LexNextToken;
        End;
      End;
    End
    Else If (CurToken.Kind = TK_INTEGER) Or (CurToken.Kind = TK_KEYWORD) Or
            (CurToken.Kind = TK_STRING) Or (CurToken.Kind = TK_NIL) Or
            (CurToken.Kind = TK_TRUE) Or (CurToken.Kind = TK_FALSE) Or
            (CurToken.Kind = TK_SYMBOL) Then
    Begin
      (* Valeur simple de match ou expression par defaut *)
      LblNext := LabelGen;
      ParseForm(MatchRes);
      ExprFlushToAX(MatchRes);

      (* Verifier s il reste une expression apres (pas juste ')' ) *)
      If (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Then
      Begin
        (* C est une paire val/result *)
        EmitInstrAB('MOV', 'BX', 'AX');
        EmitInstrAB('MOV', 'AX', 'WORD PTR [SP]');
        EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrA('JNE', LblNext);

        (* Match ! Evaluer le resultat *)
        ParseForm(ValRes);
        ExprFlushToAX(ValRes);
        Res := ValRes;
        Res.Kind := EK_AX;
        EmitInstrA('JMP', LblEnd);

        EmitLabel(LblNext);
        Inc(MatchCount);
      End
      Else
      Begin
        (* C est l expression par defaut (dernier element seul) *)
        Res := MatchRes;
        Res.Kind := EK_AX;
        EmitInstrA('JMP', LblEnd);
      End;
    End
    Else
    Begin
      (* Ignorer les tokens inattendus *)
      LexNextToken;
    End;
  End;

  (* Default : nil si aucune correspondance *)
  EmitInstrAB('XOR', 'AX', 'AX');

  EmitLabel(LblEnd);
  EmitInstrAB('ADD', 'SP', '2');  (* nettoyer l expression sauvegardee *)

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_UNKNOWN;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseIfLet : (if-let [x expr] then else?) ------------------- *)
(* Evalue expr, lie x a la valeur, teste la verite de x.               *)
(* Si vrai, evalue then (x est visible). Sinon, evalue else (ou nil).  *)
Procedure ParseIfLet(Var Res : TExprVal);
Var
  VarName   : TString;
  VarSIdx   : Integer;
  ValRes    : TExprVal;
  ThenRes   : TExprVal;
  ElseRes   : TExprVal;
  SaveFrame : Integer;
  Ofs       : Integer;
  S         : TString;
  LblElse   : TString;
  LblEnd    : TString;
Begin
  ExprMakeNone(Res);
  EmitComment('(if-let [...] ...)');
  LblElse := LabelGen;
  LblEnd  := LabelGen;

  (* Attendre le vecteur de liaisons [ ... ] *)
  If CurToken.Kind <> TK_LBRACKET Then
  Begin
    CompileError('vecteur de liaison attendu apres if-let');
    Exit;
  End;
  LexNextToken;  (* consomme '[' *)

  SymEnterScope;
  SaveFrame := CurFrameSize;

  (* Lire le nom de variable *)
  If CurToken.Kind <> TK_SYMBOL Then
  Begin
    CompileError('symbole attendu dans la liaison if-let');
    SymLeaveScope;
    Exit;
  End;
  VarName := CurToken.Val;
  LexNextToken;

  (* Evaluer l expression de liaison *)
  ParseForm(ValRes);
  ExprFlushToAX(ValRes);

  (* Allouer un emplacement local sur la pile *)
  Inc(CurFrameSize, 2);
  Ofs := CurFrameSize;
  VarSIdx := SymAdd(VarName, SK_LOCAL, ValRes.TypeIdx, -Ofs);
  If VarSIdx >= 0 Then
  Begin
    Str(Ofs, S);
    EmitInstrAB('SUB', 'SP', '2');
    EmitInstrAB('MOV', 'WORD PTR [BP-' + S + ']', 'AX');
  End;

  If CurToken.Kind = TK_RBRACKET Then
    LexNextToken  (* consomme ']' *)
  Else
    CompileError('] attendu en fin de liaison if-let');

  (* Tester la verite de la valeur liee *)
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JE', LblElse);

  (* Branche THEN *)
  ParseForm(ThenRes);
  ExprFlushToAX(ThenRes);
  EmitInstrA('JMP', LblEnd);

  (* Branche ELSE *)
  EmitLabel(LblElse);
  If (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Then
  Begin
    ParseForm(ElseRes);
    ExprFlushToAX(ElseRes);
  End
  Else
  Begin
    EmitInstrAB('XOR', 'AX', 'AX');
  End;

  EmitLabel(LblEnd);

  (* Liberer l espace pile *)
  If CurFrameSize > SaveFrame Then
  Begin
    Str(CurFrameSize - SaveFrame, S);
    EmitInstrAB('ADD', 'SP', S);
  End;

  CurFrameSize := SaveFrame;
  SymLeaveScope;

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_UNKNOWN;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseWhenLet : (when-let [x expr] body...) ------------------- *)
(* Evalue expr, lie x a la valeur, teste la verite de x.                *)
(* Si vrai, evalue le body (x est visible). Sinon, retourne nil.        *)
Procedure ParseWhenLet(Var Res : TExprVal);
Var
  VarName   : TString;
  VarSIdx   : Integer;
  ValRes    : TExprVal;
  Sub       : TExprVal;
  SaveFrame : Integer;
  Ofs       : Integer;
  S         : TString;
  LblEnd    : TString;
Begin
  ExprMakeNone(Res);
  EmitComment('(when-let [...] ...)');
  LblEnd := LabelGen;

  (* Attendre le vecteur de liaisons [ ... ] *)
  If CurToken.Kind <> TK_LBRACKET Then
  Begin
    CompileError('vecteur de liaison attendu apres when-let');
    Exit;
  End;
  LexNextToken;  (* consomme '[' *)

  SymEnterScope;
  SaveFrame := CurFrameSize;

  (* Lire le nom de variable *)
  If CurToken.Kind <> TK_SYMBOL Then
  Begin
    CompileError('symbole attendu dans la liaison when-let');
    SymLeaveScope;
    Exit;
  End;
  VarName := CurToken.Val;
  LexNextToken;

  (* Evaluer l expression de liaison *)
  ParseForm(ValRes);
  ExprFlushToAX(ValRes);

  (* Allouer un emplacement local sur la pile *)
  Inc(CurFrameSize, 2);
  Ofs := CurFrameSize;
  VarSIdx := SymAdd(VarName, SK_LOCAL, ValRes.TypeIdx, -Ofs);
  If VarSIdx >= 0 Then
  Begin
    Str(Ofs, S);
    EmitInstrAB('SUB', 'SP', '2');
    EmitInstrAB('MOV', 'WORD PTR [BP-' + S + ']', 'AX');
  End;

  If CurToken.Kind = TK_RBRACKET Then
    LexNextToken  (* consomme ']' *)
  Else
    CompileError('] attendu en fin de liaison when-let');

  (* Tester la verite de la valeur liee *)
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JE', LblEnd);

  (* Evaluer le body (toutes les expressions) *)
  While (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Do
  Begin
    ParseForm(Sub);
    ExprFlushToAX(Sub);
    Res := Sub;
  End;
  If Res.Kind <> EK_NONE Then
    Res.Kind := EK_AX;

  EmitLabel(LblEnd);

  (* Liberer l espace pile *)
  If CurFrameSize > SaveFrame Then
  Begin
    Str(CurFrameSize - SaveFrame, S);
    EmitInstrAB('ADD', 'SP', S);
  End;

  CurFrameSize := SaveFrame;
  SymLeaveScope;

  If Res.Kind = EK_NONE Then
  Begin
    EmitInstrAB('XOR', 'AX', 'AX');
    Res.Kind    := EK_AX;
    Res.TypeIdx := TY_IDX_NIL;
    Res.ImmVal  := 0;
    Res.Offset  := 0;
    Res.SymIdx  := -1;
  End;
End;

(* ============================================================
   TODO 14 - LIAISONS LOCALES : LET [IMPLEMENTE]
   ============================================================ *)
(* ParseLet ameliore dans la section TODO 10 :                    *)
(*   - SUB SP,2 pour chaque liaison AVANT evaluation de la valeur *)
(*   - Verification du nombre pair d elements dans le vecteur     *)
(*   - Liaisons sequentielles (chaque nom voit les precedents)    *)
(*   - Shadowing supporte (une liaison masque le scope parent)    *)

(* ============================================================
   TODO 15 - FONCTIONS (defn / fn / apply) [IMPLEMENTE]
   ============================================================ *)

(* ---- ParseDefnForm : (defn nom [params] body ...) ------------ *)
(* Cree un label _CLF_nom, prologue PUSH BP / MOV BP,SP           *)
(* Parametres : [BP+4+2*(N-1-i)] pour le i-eme parametre          *)
(*   (les arguments sont empiles de gauche a droite par l appelant,*)
(*    donc le premier argument est le plus profond dans la pile)    *)
(* Corps : evaluer le body, resultat dans AX                       *)
(* Epilogue : MOV SP,BP / POP BP / RET                             *)
Procedure ParseDefnForm(Var Res : TExprVal);
Var
  FnName    : TString;
  FnLabel   : TString;
  SkipLbl   : TString;
  ParamCount: Integer;
  ParamNames: Array[0..MAX_PARAM - 1] Of TString;
  ParamDestr: Array[0..MAX_PARAM - 1] Of Integer;
    (* 0 = simple symbol, 1 = vec destr, 2 = map destr *)
  ParamDestrNames  : Array[0..MAX_PARAM - 1, 0..MAX_DESTR - 1] Of TString;
  ParamDestrKinds  : Array[0..MAX_PARAM - 1, 0..MAX_DESTR - 1] Of Integer;
  ParamDestrKwIdx  : Array[0..MAX_PARAM - 1, 0..MAX_DESTR - 1] Of Integer;
  ParamDestrDefaults: Array[0..MAX_PARAM - 1, 0..MAX_DESTR - 1] Of LongInt;
  ParamDestrCount  : Array[0..MAX_PARAM - 1] Of Integer;
  ParamDestrHasOr  : Array[0..MAX_PARAM - 1] Of Boolean;
  SaveFrame : Integer;
  SaveDepth : Integer;
  SaveRetLbl: TString;
  SaveFnName: TString;
  Sub       : TExprVal;
  I, J      : Integer;
  Ofs       : Integer;
  DOfs      : Integer;
  S, SV     : TString;
  TmpName   : TString;
  PIdx      : Integer;
  DC        : Integer;
  LblEnd    : TString;
Begin
  ExprMakeNone(Res);

  (* Lire le nom de la fonction *)
  If CurToken.Kind <> TK_SYMBOL Then
  Begin
    CompileError('nom de fonction attendu apres defn');
    Exit;
  End;
  FnName := CurToken.Val;
  FnLabel := CL_FN_PFX + SymNameClean(FnName);
  LexNextToken;

  EmitComment('(defn ' + FnName + ' ...)');

  (* Enregistrer la fonction dans la table des symboles *)
  SymAdd(FnName, SK_FN, TY_IDX_FN, 0);

  (* Optionnel : docstring (si chaine avant le vecteur) *)
  If CurToken.Kind = TK_STRING Then
    LexNextToken;  (* ignorer la docstring *)

  (* Lire le vecteur de parametres [p1 p2 ...] *)
  If CurToken.Kind <> TK_LBRACKET Then
  Begin
    CompileError('vecteur de parametres attendu dans defn');
    Exit;
  End;
  LexNextToken;  (* consomme '[' *)

  ParamCount := 0;
  While (CurToken.Kind <> TK_RBRACKET) And (CurToken.Kind <> TK_EOF) Do
  Begin
    (* TODO 21 : support destructuration dans les parametres *)
    If CurToken.Kind = TK_LBRACKET Then
    Begin
      (* Destructuration sequentielle : [a b c] *)
      LexNextToken;  (* consomme '[' *)
      If ParamCount < MAX_PARAM Then
      Begin
        Str(ParamCount, S);
        ParamNames[ParamCount] := '__dp' + S;
        ParamDestr[ParamCount] := 1;
        DC := 0;
        While (CurToken.Kind <> TK_RBRACKET) And (CurToken.Kind <> TK_EOF) Do
        Begin
          If (CurToken.Kind = TK_SYMBOL) And (CurToken.Val = '&') Then
          Begin
            LexNextToken;
            If (CurToken.Kind = TK_SYMBOL) And (DC < MAX_DESTR) Then
            Begin
              ParamDestrNames[ParamCount, DC] := CurToken.Val;
              ParamDestrKinds[ParamCount, DC] := 2; (* rest *)
              Inc(DC);
              LexNextToken;
            End;
            Continue;
          End;
          If (CurToken.Kind = TK_SYMBOL) And (DC < MAX_DESTR) Then
          Begin
            ParamDestrNames[ParamCount, DC] := CurToken.Val;
            If CurToken.Val = '_' Then
              ParamDestrKinds[ParamCount, DC] := 1
            Else
              ParamDestrKinds[ParamCount, DC] := 0;
            Inc(DC);
          End;
          LexNextToken;
        End;
        ParamDestrCount[ParamCount] := DC;
        ParamDestrHasOr[ParamCount] := False;
        If CurToken.Kind = TK_RBRACKET Then
          LexNextToken;
        Inc(ParamCount);
      End
      Else
      Begin
        (* Trop de parametres - sauter *)
        While (CurToken.Kind <> TK_RBRACKET) And (CurToken.Kind <> TK_EOF) Do
          LexNextToken;
        If CurToken.Kind = TK_RBRACKET Then LexNextToken;
      End;
      Continue;
    End;

    If CurToken.Kind = TK_LBRACE Then
    Begin
      (* Destructuration associative : {:keys [a b]} *)
      LexNextToken;  (* consomme '{' *)
      If ParamCount < MAX_PARAM Then
      Begin
        Str(ParamCount, S);
        ParamNames[ParamCount] := '__dp' + S;
        ParamDestr[ParamCount] := 2;
        DC := 0;
        ParamDestrHasOr[ParamCount] := False;
        While (CurToken.Kind <> TK_RBRACE) And (CurToken.Kind <> TK_EOF) Do
        Begin
          If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'keys') Then
          Begin
            LexNextToken;
            If CurToken.Kind = TK_LBRACKET Then
            Begin
              LexNextToken;
              While (CurToken.Kind <> TK_RBRACKET) And (CurToken.Kind <> TK_EOF) Do
              Begin
                If (CurToken.Kind = TK_SYMBOL) And (DC < MAX_DESTR) Then
                Begin
                  ParamDestrNames[ParamCount, DC] := CurToken.Val;
                  ParamDestrKinds[ParamCount, DC] := 0;
                  ParamDestrKwIdx[ParamCount, DC] := KwAdd(CurToken.Val);
                  ParamDestrDefaults[ParamCount, DC] := 0;
                  Inc(DC);
                End;
                LexNextToken;
              End;
              If CurToken.Kind = TK_RBRACKET Then LexNextToken;
            End;
            Continue;
          End;
          If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'or') Then
          Begin
            LexNextToken;
            ParamDestrHasOr[ParamCount] := True;
            If CurToken.Kind = TK_LBRACE Then
            Begin
              LexNextToken;
              While (CurToken.Kind <> TK_RBRACE) And (CurToken.Kind <> TK_EOF) Do
              Begin
                If CurToken.Kind = TK_SYMBOL Then
                Begin
                  TmpName := CurToken.Val;
                  LexNextToken;
                  If CurToken.Kind = TK_INTEGER Then
                  Begin
                    For J := 0 To DC - 1 Do
                      If ParamDestrNames[ParamCount, J] = TmpName Then
                        ParamDestrDefaults[ParamCount, J] := CurToken.IntVal;
                    LexNextToken;
                  End;
                End
                Else
                  LexNextToken;
              End;
              If CurToken.Kind = TK_RBRACE Then LexNextToken;
            End;
            Continue;
          End;
          (* Forme explicite {x :nom} *)
          If CurToken.Kind = TK_SYMBOL Then
          Begin
            If DC < MAX_DESTR Then
              ParamDestrNames[ParamCount, DC] := CurToken.Val;
            LexNextToken;
            If CurToken.Kind = TK_KEYWORD Then
            Begin
              If DC < MAX_DESTR Then
              Begin
                ParamDestrKinds[ParamCount, DC] := 3;
                ParamDestrKwIdx[ParamCount, DC] := KwAdd(CurToken.Val);
                ParamDestrDefaults[ParamCount, DC] := 0;
                Inc(DC);
              End;
              LexNextToken;
            End;
            Continue;
          End;
          LexNextToken;
        End;
        ParamDestrCount[ParamCount] := DC;
        If CurToken.Kind = TK_RBRACE Then LexNextToken;
        Inc(ParamCount);
      End
      Else
      Begin
        While (CurToken.Kind <> TK_RBRACE) And (CurToken.Kind <> TK_EOF) Do
          LexNextToken;
        If CurToken.Kind = TK_RBRACE Then LexNextToken;
      End;
      Continue;
    End;

    If CurToken.Kind <> TK_SYMBOL Then
    Begin
      CompileError('symbole attendu dans la liste des parametres');
      LexNextToken;
      Continue;
    End;
    If ParamCount < MAX_PARAM Then
    Begin
      ParamNames[ParamCount] := CurToken.Val;
      ParamDestr[ParamCount] := 0;
      Inc(ParamCount);
    End;
    LexNextToken;
  End;
  If CurToken.Kind = TK_RBRACKET Then
    LexNextToken  (* consomme ']' *)
  Else
    CompileError('] attendu en fin de parametres defn');

  (* Sauvegarder le contexte de la fonction englobante *)
  SaveFrame  := CurFrameSize;
  SaveDepth  := CurFnDepth;
  SaveRetLbl := CurFnRetLbl;
  SaveFnName := CurFnName;

  CurFrameSize := 0;
  Inc(CurFnDepth);
  CurFnName    := FnName;
  CurFnRetLbl  := '';  (* pas de label de retour anticipe pour defn *)

  (* JMP par-dessus le corps de la fonction pour eviter l execution *)
  SkipLbl := LabelGen;
  EmitInstrA('JMP', SkipLbl);

  (* Label de la fonction *)
  EmitLabel(FnLabel);
  EmitProlog;

  (* Entrer dans une nouvelle portee pour les parametres *)
  SymEnterScope;

  (* Enregistrer les parametres dans la table des symboles *)
  (* Les arguments sont empiles de gauche a droite par l appelant, *)
  (* donc le premier argument est a [BP+4+2*(N-1)].                *)
  For I := 0 To ParamCount - 1 Do
  Begin
    Ofs := 4 + 2 * (ParamCount - 1 - I);
    SymAdd(ParamNames[I], SK_LOCAL, TY_UNKNOWN, Ofs);
  End;

  (* TODO 21 : destructuration des parametres apres le prolog *)
  For PIdx := 0 To ParamCount - 1 Do
  Begin
    If ParamDestr[PIdx] = 0 Then
      Continue;  (* parametre simple, deja lie *)

    Ofs := 4 + 2 * (ParamCount - 1 - PIdx);

    If ParamDestr[PIdx] = 1 Then
    Begin
      (* Destructuration sequentielle *)
      EmitComment('destrVec param ' + ParamNames[PIdx]);
      For J := 0 To ParamDestrCount[PIdx] - 1 Do
      Begin
        If ParamDestrKinds[PIdx, J] = 1 Then
          Continue;  (* _ : skip *)
        Inc(CurFrameSize, 2);
        DOfs := CurFrameSize;
        EmitInstrAB('SUB', 'SP', '2');

        If ParamDestrKinds[PIdx, J] = 2 Then
        Begin
          Str(Ofs, S);
          EmitInstrAB('MOV', 'AX', 'WORD PTR [BP+' + S + ']');
          Str(J, S);
          EmitInstrAB('MOV', 'BX', S);
          EmitInstrA('CALL', CL_RT_PFX + 'VECDROP');
          Str(DOfs, S);
          EmitInstrAB('MOV', 'WORD PTR [BP-' + S + ']', 'AX');
          SymAdd(ParamDestrNames[PIdx, J], SK_LOCAL, TY_IDX_VEC, -DOfs);
        End
        Else
        Begin
          Str(Ofs, S);
          EmitInstrAB('MOV', 'AX', 'WORD PTR [BP+' + S + ']');
          Str(J, S);
          EmitInstrAB('MOV', 'BX', S);
          EmitInstrA('CALL', CL_RT_PFX + 'VECNTH');
          Str(DOfs, S);
          EmitInstrAB('MOV', 'WORD PTR [BP-' + S + ']', 'AX');
          SymAdd(ParamDestrNames[PIdx, J], SK_LOCAL, TY_UNKNOWN, -DOfs);
        End;
      End;
    End
    Else If ParamDestr[PIdx] = 2 Then
    Begin
      (* Destructuration associative *)
      EmitComment('destrMap param ' + ParamNames[PIdx]);
      For J := 0 To ParamDestrCount[PIdx] - 1 Do
      Begin
        Inc(CurFrameSize, 2);
        DOfs := CurFrameSize;
        EmitInstrAB('SUB', 'SP', '2');

        Str(Ofs, S);
        EmitInstrAB('MOV', 'AX', 'WORD PTR [BP+' + S + ']');
        Str(ParamDestrKwIdx[PIdx, J], S);
        EmitInstrAB('MOV', 'BX', S);
        EmitInstrA('CALL', CL_RT_PFX + 'MAPGET');

        If ParamDestrHasOr[PIdx] And (ParamDestrDefaults[PIdx, J] <> 0) Then
        Begin
          LblEnd := LabelGen;
          EmitInstrAB('CMP', 'AX', '0');
          EmitInstrA('JNE', LblEnd);
          Str(ParamDestrDefaults[PIdx, J], S);
          EmitInstrAB('MOV', 'AX', S);
          EmitLabel(LblEnd);
        End;

        Str(DOfs, S);
        EmitInstrAB('MOV', 'WORD PTR [BP-' + S + ']', 'AX');
        SymAdd(ParamDestrNames[PIdx, J], SK_LOCAL, TY_UNKNOWN, -DOfs);
      End;
    End;
  End;

  (* Evaluer le corps (body) *)
  (* En Clojure, la derniere expression du body est la valeur de retour *)
  While (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Do
  Begin
    ParseForm(Sub);
    ExprFlushToAX(Sub);
    Res := Sub;
  End;

  (* Epilogue de la fonction *)
  EmitEpilog;

  (* Quitter la portee des parametres *)
  SymLeaveScope;

  (* Label apres le corps de la fonction *)
  EmitLabel(SkipLbl);

  (* Restaurer le contexte de la fonction englobante *)
  CurFrameSize := SaveFrame;
  CurFnDepth   := SaveDepth;
  CurFnRetLbl  := SaveRetLbl;
  CurFnName    := SaveFnName;

  (* defn retourne nil *)
  ExprMakeNone(Res);
  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_NIL;
  EmitInstrAB('XOR', 'AX', 'AX');
End;

(* ---- ParseFnForm : (fn [params] body ...) -------------------- *)
(* Fonction anonyme (lambda). Meme convention d appel que defn.    *)
(* Retourne l adresse du label de la fonction dans AX.             *)
Procedure ParseFnForm(Var Res : TExprVal);
Var
  FnLabel   : TString;
  SkipLbl   : TString;
  ParamCount: Integer;
  ParamNames: Array[0..MAX_PARAM - 1] Of TString;
  SaveFrame : Integer;
  SaveDepth : Integer;
  SaveRetLbl: TString;
  SaveFnName: TString;
  Sub       : TExprVal;
  I         : Integer;
  Ofs       : Integer;
Begin
  ExprMakeNone(Res);

  (* Generer un label unique pour la lambda *)
  FnLabel := LabelGen;

  EmitComment('(fn [...] ...)');

  (* Optionnel : nom pour fn nomme (fn name [params] body) *)
  (* Si le token courant est un symbole, c est un nom optionnel *)
  (* car le vecteur de parametres sera TK_LBRACKET              *)
  If (CurToken.Kind = TK_SYMBOL) Then
    LexNextToken;  (* consomme le nom optionnel *)

  (* Lire le vecteur de parametres [p1 p2 ...] *)
  If CurToken.Kind <> TK_LBRACKET Then
  Begin
    CompileError('vecteur de parametres attendu dans fn');
    Exit;
  End;
  LexNextToken;  (* consomme '[' *)

  ParamCount := 0;
  While (CurToken.Kind <> TK_RBRACKET) And (CurToken.Kind <> TK_EOF) Do
  Begin
    If CurToken.Kind <> TK_SYMBOL Then
    Begin
      CompileError('symbole attendu dans la liste des parametres fn');
      LexNextToken;
      Continue;
    End;
    If ParamCount < MAX_PARAM Then
    Begin
      ParamNames[ParamCount] := CurToken.Val;
      Inc(ParamCount);
    End;
    LexNextToken;
  End;
  If CurToken.Kind = TK_RBRACKET Then
    LexNextToken  (* consomme ']' *)
  Else
    CompileError('] attendu en fin de parametres fn');

  (* Sauvegarder le contexte *)
  SaveFrame  := CurFrameSize;
  SaveDepth  := CurFnDepth;
  SaveRetLbl := CurFnRetLbl;
  SaveFnName := CurFnName;

  CurFrameSize := 0;
  Inc(CurFnDepth);
  CurFnName    := '(fn)';
  CurFnRetLbl  := '';  (* pas de label de retour anticipe pour fn *)

  (* JMP par-dessus le corps de la lambda *)
  SkipLbl := LabelGen;
  EmitInstrA('JMP', SkipLbl);

  (* Label de la lambda *)
  EmitLabel(FnLabel);
  EmitProlog;

  (* Entrer dans une nouvelle portee pour les parametres *)
  SymEnterScope;

  (* Enregistrer les parametres dans la table des symboles *)
  For I := 0 To ParamCount - 1 Do
  Begin
    Ofs := 4 + 2 * (ParamCount - 1 - I);
    SymAdd(ParamNames[I], SK_LOCAL, TY_UNKNOWN, Ofs);
  End;

  (* Evaluer le corps (body) *)
  (* En Clojure, la derniere expression du body est la valeur de retour *)
  While (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Do
  Begin
    ParseForm(Sub);
    ExprFlushToAX(Sub);
    Res := Sub;
  End;

  (* Epilogue de la lambda *)
  EmitEpilog;

  (* Quitter la portee des parametres *)
  SymLeaveScope;

  (* Label apres le corps de la lambda *)
  EmitLabel(SkipLbl);

  (* Restaurer le contexte *)
  CurFrameSize := SaveFrame;
  CurFnDepth   := SaveDepth;
  CurFnRetLbl  := SaveRetLbl;
  CurFnName    := SaveFnName;

  (* Retourner l adresse de la lambda dans AX *)
  EmitInstrAB('MOV', 'AX', 'OFFSET ' + FnLabel);
  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_FN;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ============================================================
   TODO 16 - BOUCLES : LOOP / RECUR / DOTIMES / DOSEQ [IMPLEMENTE]
   ============================================================ *)

(* ---- ParseLoopForm : (loop [x init1 y init2] body ...) -------- *)
(* Cree des liaisons locales comme let, avec un label de boucle    *)
(* en debut du body. (recur ...) saute vers ce label en mettant    *)
(* a jour les liaisons.                                             *)
Procedure ParseLoopForm(Var Res : TExprVal);
Var
  VarName   : TString;
  ValRes    : TExprVal;
  Sub       : TExprVal;
  SaveFrame : Integer;
  Ofs       : Integer;
  S         : TString;
  LoopLabel : TString;
  BC        : Integer;
  (* TODO 21 : destructuration dans loop *)
  IsDestruc        : Array[0..MAX_PARAM - 1] Of Integer; (* 0=simple,1=vec,2=map *)
  DestrucNames     : Array[0..MAX_PARAM - 1, 0..MAX_DESTR - 1] Of TString;
  DestrucKinds     : Array[0..MAX_PARAM - 1, 0..MAX_DESTR - 1] Of Integer;
  DestrucKwIdx     : Array[0..MAX_PARAM - 1, 0..MAX_DESTR - 1] Of Integer;
  DestrucDefaults  : Array[0..MAX_PARAM - 1, 0..MAX_DESTR - 1] Of LongInt;
  DestrucCounts    : Array[0..MAX_PARAM - 1] Of Integer;
  DestrucHasOr     : Array[0..MAX_PARAM - 1] Of Boolean;
  BindOfs          : Array[0..MAX_PARAM - 1] Of Integer;
  J, K             : Integer;
  DOfs             : Integer;
  DC               : Integer;
  LblEnd           : TString;
  TmpName          : TString;
Begin
  ExprMakeNone(Res);
  EmitComment('(loop [...] ...)');

  (* On attend un vecteur de liaisons [ ... ] *)
  If CurToken.Kind <> TK_LBRACKET Then
  Begin
    CompileError('vecteur de liaisons attendu apres loop');
    Exit;
  End;
  LexNextToken;  (* consomme '[' *)

  SymEnterScope;
  SaveFrame := CurFrameSize;
  BC := 0;  (* nombre de liaisons *)

  (* Traiter les paires nom/valeur, comme let *)
  While (CurToken.Kind <> TK_RBRACKET) And (CurToken.Kind <> TK_EOF) Do
  Begin
    (* TODO 21 : detecter destructuration *)
    If (CurToken.Kind = TK_LBRACKET) Or (CurToken.Kind = TK_LBRACE) Then
    Begin
      (* Lire le pattern de destructuration *)
      If BC < MAX_PARAM Then
      Begin
        DC := 0;
        DestrucHasOr[BC] := False;
        If CurToken.Kind = TK_LBRACKET Then
        Begin
          IsDestruc[BC] := 1;
          LexNextToken; (* consomme '[' *)
          While (CurToken.Kind <> TK_RBRACKET) And (CurToken.Kind <> TK_EOF) Do
          Begin
            If (CurToken.Kind = TK_SYMBOL) And (CurToken.Val = '&') Then
            Begin
              LexNextToken;
              If (CurToken.Kind = TK_SYMBOL) And (DC < MAX_DESTR) Then
              Begin
                DestrucNames[BC, DC] := CurToken.Val;
                DestrucKinds[BC, DC] := 2;
                Inc(DC);
                LexNextToken;
              End;
              Continue;
            End;
            If (CurToken.Kind = TK_SYMBOL) And (DC < MAX_DESTR) Then
            Begin
              DestrucNames[BC, DC] := CurToken.Val;
              If CurToken.Val = '_' Then
                DestrucKinds[BC, DC] := 1
              Else
                DestrucKinds[BC, DC] := 0;
              Inc(DC);
            End;
            LexNextToken;
          End;
          If CurToken.Kind = TK_RBRACKET Then LexNextToken;
        End
        Else
        Begin
          IsDestruc[BC] := 2;
          LexNextToken; (* consomme '{' *)
          While (CurToken.Kind <> TK_RBRACE) And (CurToken.Kind <> TK_EOF) Do
          Begin
            If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'keys') Then
            Begin
              LexNextToken;
              If CurToken.Kind = TK_LBRACKET Then
              Begin
                LexNextToken;
                While (CurToken.Kind <> TK_RBRACKET) And (CurToken.Kind <> TK_EOF) Do
                Begin
                  If (CurToken.Kind = TK_SYMBOL) And (DC < MAX_DESTR) Then
                  Begin
                    DestrucNames[BC, DC] := CurToken.Val;
                    DestrucKinds[BC, DC] := 0;
                    DestrucKwIdx[BC, DC] := KwAdd(CurToken.Val);
                    DestrucDefaults[BC, DC] := 0;
                    Inc(DC);
                  End;
                  LexNextToken;
                End;
                If CurToken.Kind = TK_RBRACKET Then LexNextToken;
              End;
              Continue;
            End;
            If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'or') Then
            Begin
              LexNextToken;
              DestrucHasOr[BC] := True;
              If CurToken.Kind = TK_LBRACE Then
              Begin
                LexNextToken;
                While (CurToken.Kind <> TK_RBRACE) And (CurToken.Kind <> TK_EOF) Do
                Begin
                  If CurToken.Kind = TK_SYMBOL Then
                  Begin
                    TmpName := CurToken.Val;
                    LexNextToken;
                    If CurToken.Kind = TK_INTEGER Then
                    Begin
                      For J := 0 To DC - 1 Do
                        If DestrucNames[BC, J] = TmpName Then
                          DestrucDefaults[BC, J] := CurToken.IntVal;
                      LexNextToken;
                    End;
                  End
                  Else
                    LexNextToken;
                End;
                If CurToken.Kind = TK_RBRACE Then LexNextToken;
              End;
              Continue;
            End;
            If CurToken.Kind = TK_SYMBOL Then
            Begin
              If DC < MAX_DESTR Then
                DestrucNames[BC, DC] := CurToken.Val;
              LexNextToken;
              If CurToken.Kind = TK_KEYWORD Then
              Begin
                If DC < MAX_DESTR Then
                Begin
                  DestrucKinds[BC, DC] := 3;
                  DestrucKwIdx[BC, DC] := KwAdd(CurToken.Val);
                  DestrucDefaults[BC, DC] := 0;
                  Inc(DC);
                End;
                LexNextToken;
              End;
              Continue;
            End;
            LexNextToken;
          End;
          If CurToken.Kind = TK_RBRACE Then LexNextToken;
        End;
        DestrucCounts[BC] := DC;
      End
      Else
      Begin
        (* Skip the pattern *)
        If CurToken.Kind = TK_LBRACKET Then
        Begin
          LexNextToken;
          While (CurToken.Kind <> TK_RBRACKET) And (CurToken.Kind <> TK_EOF) Do
            LexNextToken;
          If CurToken.Kind = TK_RBRACKET Then LexNextToken;
        End
        Else
        Begin
          LexNextToken;
          While (CurToken.Kind <> TK_RBRACE) And (CurToken.Kind <> TK_EOF) Do
            LexNextToken;
          If CurToken.Kind = TK_RBRACE Then LexNextToken;
        End;
      End;

      (* Verification : la valeur doit suivre *)
      If (CurToken.Kind = TK_RBRACKET) Or (CurToken.Kind = TK_EOF) Then
      Begin
        WarnMsg('valeur manquante pour destructuration loop');
        Break;
      End;

      (* Allouer un local pour la valeur brute *)
      Inc(CurFrameSize, 2);
      Ofs := CurFrameSize;
      EmitInstrAB('SUB', 'SP', '2');

      ParseForm(ValRes);
      ExprFlushToAX(ValRes);
      Str(Ofs, S);
      EmitInstrAB('MOV', 'WORD PTR [BP-' + S + ']', 'AX');

      If BC < MAX_PARAM Then
      Begin
        BindOfs[BC] := Ofs;
        If LoopTop < MAX_LOOP_NEST Then
          LoopBindOfs[LoopTop, BC] := Ofs;
        Inc(BC);
      End;

      Continue;
    End;

    If CurToken.Kind <> TK_SYMBOL Then
    Begin
      CompileError('symbole attendu dans les liaisons loop');
      LexNextToken;
      Continue;
    End;
    VarName := CurToken.Val;
    LexNextToken;

    (* Verification : nombre pair d elements dans le vecteur *)
    If (CurToken.Kind = TK_RBRACKET) Or (CurToken.Kind = TK_EOF) Then
    Begin
      WarnMsg('nombre impair d''elements dans le vecteur de liaisons loop');
      Break;
    End;

    (* Allouer l emplacement local sur la pile AVANT l evaluation *)
    Inc(CurFrameSize, 2);
    Ofs := CurFrameSize;
    EmitInstrAB('SUB', 'SP', '2');

    (* Evaluer la valeur de la liaison *)
    ParseForm(ValRes);
    ExprFlushToAX(ValRes);

    (* Enregistrer le symbole et stocker la valeur *)
    SymAdd(VarName, SK_LOCAL, ValRes.TypeIdx, -Ofs);
    Str(Ofs, S);
    EmitInstrAB('MOV', 'WORD PTR [BP-' + S + ']', 'AX');

    (* Memoriser l offset pour recur *)
    If BC < MAX_PARAM Then
    Begin
      IsDestruc[BC] := 0;
      BindOfs[BC] := Ofs;
      If LoopTop < MAX_LOOP_NEST Then
        LoopBindOfs[LoopTop, BC] := Ofs;
      Inc(BC);
    End;
  End;

  If CurToken.Kind = TK_RBRACKET Then
    LexNextToken  (* consomme ']' *)
  Else
    CompileError('] attendu en fin de liaisons loop');

  (* Generer le label de boucle *)
  LoopLabel := LabelGen;

  (* Empiler le contexte de boucle *)
  If LoopTop < MAX_LOOP_NEST Then
  Begin
    LoopLbl[LoopTop] := LoopLabel;
    LoopBindCount[LoopTop] := BC;
    Inc(LoopTop);
  End
  Else
    WarnMsg('boucles loop imbriquees trop profondes');

  EmitLabel(LoopLabel);

  (* TODO 21 : generer le code de destructuration apres le label *)
  (* pour que recur re-declenche la destructuration               *)
  For K := 0 To BC - 1 Do
  Begin
    If IsDestruc[K] = 1 Then
    Begin
      EmitComment('destrVec loop binding');
      For J := 0 To DestrucCounts[K] - 1 Do
      Begin
        If DestrucKinds[K, J] = 1 Then Continue;
        Inc(CurFrameSize, 2);
        DOfs := CurFrameSize;
        EmitInstrAB('SUB', 'SP', '2');
        If DestrucKinds[K, J] = 2 Then
        Begin
          Str(BindOfs[K], S);
          EmitInstrAB('MOV', 'AX', 'WORD PTR [BP-' + S + ']');
          Str(J, S);
          EmitInstrAB('MOV', 'BX', S);
          EmitInstrA('CALL', CL_RT_PFX + 'VECDROP');
          Str(DOfs, S);
          EmitInstrAB('MOV', 'WORD PTR [BP-' + S + ']', 'AX');
          SymAdd(DestrucNames[K, J], SK_LOCAL, TY_IDX_VEC, -DOfs);
        End
        Else
        Begin
          Str(BindOfs[K], S);
          EmitInstrAB('MOV', 'AX', 'WORD PTR [BP-' + S + ']');
          Str(J, S);
          EmitInstrAB('MOV', 'BX', S);
          EmitInstrA('CALL', CL_RT_PFX + 'VECNTH');
          Str(DOfs, S);
          EmitInstrAB('MOV', 'WORD PTR [BP-' + S + ']', 'AX');
          SymAdd(DestrucNames[K, J], SK_LOCAL, TY_UNKNOWN, -DOfs);
        End;
      End;
    End
    Else If IsDestruc[K] = 2 Then
    Begin
      EmitComment('destrMap loop binding');
      For J := 0 To DestrucCounts[K] - 1 Do
      Begin
        Inc(CurFrameSize, 2);
        DOfs := CurFrameSize;
        EmitInstrAB('SUB', 'SP', '2');
        Str(BindOfs[K], S);
        EmitInstrAB('MOV', 'AX', 'WORD PTR [BP-' + S + ']');
        Str(DestrucKwIdx[K, J], S);
        EmitInstrAB('MOV', 'BX', S);
        EmitInstrA('CALL', CL_RT_PFX + 'MAPGET');
        If DestrucHasOr[K] And (DestrucDefaults[K, J] <> 0) Then
        Begin
          LblEnd := LabelGen;
          EmitInstrAB('CMP', 'AX', '0');
          EmitInstrA('JNE', LblEnd);
          Str(DestrucDefaults[K, J], S);
          EmitInstrAB('MOV', 'AX', S);
          EmitLabel(LblEnd);
        End;
        Str(DOfs, S);
        EmitInstrAB('MOV', 'WORD PTR [BP-' + S + ']', 'AX');
        SymAdd(DestrucNames[K, J], SK_LOCAL, TY_UNKNOWN, -DOfs);
      End;
    End;
  End;

  (* Evaluer le body *)
  While (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Do
  Begin
    ParseForm(Sub);
    ExprFlushToAX(Sub);
    Res := Sub;
  End;
  If Res.Kind <> EK_NONE Then
    Res.Kind := EK_AX;

  (* Depiler le contexte de boucle *)
  If LoopTop > 0 Then
    Dec(LoopTop);

  (* Liberer l espace pile *)
  If CurFrameSize > SaveFrame Then
  Begin
    Str(CurFrameSize - SaveFrame, S);
    EmitInstrAB('ADD', 'SP', S);
  End;

  CurFrameSize := SaveFrame;
  SymLeaveScope;
End;

(* ---- ParseRecurForm : (recur expr1 expr2 ...) ----------------- *)
(* Reevalue les expressions et met a jour les liaisons du loop      *)
(* le plus interne, puis saute vers le label de boucle.             *)
(* Doit etre en position de queue (tail position).                  *)
Procedure ParseRecurForm(Var Res : TExprVal);
Var
  ArgCount : Integer;
  ArgRes   : TExprVal;
  S        : TString;
  I        : Integer;
  CurLoop  : Integer;
Begin
  ExprMakeNone(Res);
  EmitComment('(recur ...)');

  If LoopTop = 0 Then
  Begin
    CompileError('recur utilise en dehors d''un loop');
    While (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Do
      LexNextToken;
    Exit;
  End;

  CurLoop := LoopTop - 1;
  ArgCount := 0;

  (* Evaluer chaque argument et empiler le resultat *)
  While (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Do
  Begin
    ParseForm(ArgRes);
    ExprFlushToAX(ArgRes);
    EmitInstrA('PUSH', 'AX');
    Inc(ArgCount);
  End;

  If ArgCount <> LoopBindCount[CurLoop] Then
    WarnMsg('recur : nombre d''arguments different du nombre de liaisons loop');

  (* Depiler les valeurs en ordre inverse et mettre a jour les liaisons *)
  For I := ArgCount - 1 DownTo 0 Do
  Begin
    EmitInstrA('POP', 'AX');
    If I < LoopBindCount[CurLoop] Then
    Begin
      Str(LoopBindOfs[CurLoop, I], S);
      EmitInstrAB('MOV', 'WORD PTR [BP-' + S + ']', 'AX');
    End;
  End;

  (* Saut arriere vers le debut du loop *)
  EmitInstrA('JMP', LoopLbl[CurLoop]);
  Res.Kind := EK_NONE;
End;

(* ---- ParseDotimesForm : (dotimes [i n] body ...) -------------- *)
(* Boucle de i=0 a n-1. Sucre syntaxique equivalent a :            *)
(*   (loop [i 0] (when (< i n) body ... (recur (inc i))))          *)
Procedure ParseDotimesForm(Var Res : TExprVal);
Var
  VarName    : TString;
  LimitRes   : TExprVal;
  Sub        : TExprVal;
  SaveFrame  : Integer;
  LoopLabel  : TString;
  EndLabel   : TString;
  OfsVar     : Integer;
  OfsLimit   : Integer;
  S, S2      : TString;
Begin
  ExprMakeNone(Res);
  EmitComment('(dotimes [...] ...)');

  If CurToken.Kind <> TK_LBRACKET Then
  Begin
    CompileError('vecteur [i n] attendu apres dotimes');
    Exit;
  End;
  LexNextToken;  (* consomme '[' *)

  If CurToken.Kind <> TK_SYMBOL Then
  Begin
    CompileError('symbole attendu dans [i n] de dotimes');
    Exit;
  End;
  VarName := CurToken.Val;
  LexNextToken;

  SymEnterScope;
  SaveFrame := CurFrameSize;

  (* Allouer la variable d iteration, initialisee a 0 *)
  Inc(CurFrameSize, 2);
  OfsVar := CurFrameSize;
  EmitInstrAB('SUB', 'SP', '2');
  EmitInstrAB('MOV', 'AX', '0');
  Str(OfsVar, S);
  EmitInstrAB('MOV', 'WORD PTR [BP-' + S + ']', 'AX');
  SymAdd(VarName, SK_LOCAL, TY_IDX_INT, -OfsVar);

  (* Evaluer la limite *)
  ParseForm(LimitRes);
  ExprFlushToAX(LimitRes);

  (* Allouer le stockage de la limite *)
  Inc(CurFrameSize, 2);
  OfsLimit := CurFrameSize;
  EmitInstrAB('SUB', 'SP', '2');
  Str(OfsLimit, S2);
  EmitInstrAB('MOV', 'WORD PTR [BP-' + S2 + ']', 'AX');

  If CurToken.Kind = TK_RBRACKET Then
    LexNextToken  (* consomme ']' *)
  Else
    CompileError('] attendu en fin de [i n] de dotimes');

  LoopLabel := LabelGen;
  EndLabel  := LabelGen;

  EmitLabel(LoopLabel);

  (* Comparer i < n *)
  EmitInstrAB('MOV', 'AX', 'WORD PTR [BP-' + S + ']');
  EmitInstrAB('CMP', 'AX', 'WORD PTR [BP-' + S2 + ']');
  EmitInstrA('JGE', EndLabel);

  (* Evaluer le body *)
  While (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Do
  Begin
    ParseForm(Sub);
    ExprFlushToAX(Sub);
    Res := Sub;
  End;

  (* Incrementer i *)
  EmitInstrAB('MOV', 'AX', 'WORD PTR [BP-' + S + ']');
  EmitInstrA('INC', 'AX');
  EmitInstrAB('MOV', 'WORD PTR [BP-' + S + ']', 'AX');
  EmitInstrA('JMP', LoopLabel);

  EmitLabel(EndLabel);

  EmitInstrAB('MOV', 'AX', '0');
  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_NIL;

  If CurFrameSize > SaveFrame Then
  Begin
    Str(CurFrameSize - SaveFrame, S);
    EmitInstrAB('ADD', 'SP', S);
  End;

  CurFrameSize := SaveFrame;
  SymLeaveScope;
End;

(* ---- ParseDoseqForm : (doseq [x coll] body ...) -------------- *)
(* Iteration sur une collection (sequence).                         *)
(* Equivalent a : (loop [s (seq coll)]                              *)
(*                  (when s (let [x (first s)] body (recur (rest s)))))*)
(* Stub : emet un avertissement, compile le body une fois.          *)
Procedure ParseDoseqForm(Var Res : TExprVal);
Var Sub : TExprVal;
Begin
  ExprMakeNone(Res);
  WarnMsg('doseq non entierement supporte, traite comme stub');
  EmitComment('(doseq [...] ...) - stub');

  (* Sauter le vecteur de liaisons *)
  If CurToken.Kind = TK_LBRACKET Then
  Begin
    LexNextToken;
    While (CurToken.Kind <> TK_RBRACKET) And (CurToken.Kind <> TK_EOF) Do
      LexNextToken;
    If CurToken.Kind = TK_RBRACKET Then LexNextToken;
  End;

  (* Evaluer le body une fois (stub) *)
  While (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Do
  Begin
    ParseForm(Sub);
    Res := Sub;
  End;

  EmitInstrAB('MOV', 'AX', '0');
  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_NIL;
End;

(* ---- ParseWhileForm : (while test body ...) ------------------- *)
(* Boucle tant que test est vrai (non nil et non false).            *)
(* Le test est reevalue a chaque iteration.                         *)
Procedure ParseWhileForm(Var Res : TExprVal);
Var
  LoopLabel : TString;
  EndLabel  : TString;
  TestRes   : TExprVal;
  Sub       : TExprVal;
Begin
  ExprMakeNone(Res);
  EmitComment('(while ...)');

  LoopLabel := LabelGen;
  EndLabel  := LabelGen;

  EmitLabel(LoopLabel);

  (* Evaluer le test *)
  ParseForm(TestRes);
  ExprFlushToAX(TestRes);
  EmitInstrAB('TEST', 'AX', 'AX');
  EmitInstrA('JZ', EndLabel);

  (* Evaluer le body *)
  While (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Do
  Begin
    ParseForm(Sub);
    ExprFlushToAX(Sub);
    Res := Sub;
  End;

  EmitInstrA('JMP', LoopLabel);
  EmitLabel(EndLabel);

  EmitInstrAB('MOV', 'AX', '0');
  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_NIL;
End;

(* ============================================================
   TODO 17 - LISTES : CONS / FIRST / REST / CONJ [IMPLEMENTE]
   ============================================================ *)

(* ---- ParseConsForm : (cons x coll) ----------------------------- *)
(* Alloue une cellule cons sur le heap : [car=x, cdr=coll]          *)
(* AX = x (car), BX = coll (cdr) -> CALL _CLRT_CONS -> AX = ptr    *)
Procedure ParseConsForm(Var Res : TExprVal);
Var ArgRes : TExprVal;
Begin
  ExprMakeNone(Res);
  EmitComment('(cons x coll)');

  (* Evaluer le premier argument (x = car) *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrA('PUSH', 'AX');

  (* Evaluer le deuxieme argument (coll = cdr) *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'BX', 'AX');

  (* Recuperer car dans AX *)
  EmitInstrA('POP', 'AX');

  (* Appel runtime cons *)
  EmitInstrA('CALL', CL_RT_PFX + 'CONS');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_LIST;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseFirstForm : (first lst) ------------------------------ *)
(* Retourne le car de la cellule cons pointee par lst.               *)
(* Si lst = nil (0), retourne nil.                                   *)
Procedure ParseFirstForm(Var Res : TExprVal);
Var ArgRes : TExprVal;
    LblNil : TString;
    LblEnd : TString;
Begin
  ExprMakeNone(Res);
  EmitComment('(first lst)');
  LblNil := LabelGen;
  LblEnd := LabelGen;

  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);

  (* Si AX = 0 (nil), retourner nil *)
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JE', LblNil);

  (* AX = pointeur cons -> car = [AX] *)
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitInstrAB('MOV', 'AX', 'WORD PTR [BX]');
  EmitInstrA('JMP', LblEnd);

  EmitLabel(LblNil);
  EmitInstrAB('XOR', 'AX', 'AX');

  EmitLabel(LblEnd);
  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_UNKNOWN;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseRestForm : (rest lst) -------------------------------- *)
(* Retourne le cdr de la cellule cons pointee par lst.               *)
(* Si lst = nil, retourne nil.                                       *)
Procedure ParseRestForm(Var Res : TExprVal);
Var ArgRes : TExprVal;
    LblNil : TString;
    LblEnd : TString;
Begin
  ExprMakeNone(Res);
  EmitComment('(rest lst)');
  LblNil := LabelGen;
  LblEnd := LabelGen;

  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);

  (* Si AX = 0 (nil), retourner nil *)
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JE', LblNil);

  (* AX = pointeur cons -> cdr = [AX+2] *)
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitInstrAB('MOV', 'AX', 'WORD PTR [BX+2]');
  EmitInstrA('JMP', LblEnd);

  EmitLabel(LblNil);
  EmitInstrAB('XOR', 'AX', 'AX');

  EmitLabel(LblEnd);
  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_LIST;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseListForm : (list a b c ...) -------------------------- *)
(* Construit une liste par appels cons imbriques de droite a gauche. *)
(* (list a b c) = (cons a (cons b (cons c nil)))                     *)
(* On empile tous les arguments, puis on cons de droite a gauche.    *)
Procedure ParseListForm(Var Res : TExprVal);
Var ArgRes   : TExprVal;
    ArgCount : Integer;
    I        : Integer;
Begin
  ExprMakeNone(Res);
  EmitComment('(list ...)');
  ArgCount := 0;

  (* Empiler tous les arguments de gauche a droite *)
  While (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Do
  Begin
    ParseForm(ArgRes);
    ExprFlushToAX(ArgRes);
    EmitInstrA('PUSH', 'AX');
    Inc(ArgCount);
  End;

  (* Commencer avec nil (liste vide) *)
  EmitInstrAB('XOR', 'AX', 'AX');

  (* Depiler et cons de droite a gauche *)
  (* La pile contient [a, b, c] avec c au sommet *)
  (* On veut : (cons a (cons b (cons c nil))) *)
  (* Donc on depile c, cons c nil -> depile b, cons b result -> depile a, cons a result *)
  For I := 1 To ArgCount Do
  Begin
    EmitInstrAB('MOV', 'BX', 'AX');
    EmitInstrA('POP', 'AX');
    EmitInstrA('CALL', CL_RT_PFX + 'CONS');
  End;

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_LIST;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseConjListForm : (conj coll x) ------------------------- *)
(* Polymorphe : pour les listes, ajoute en tete (cons x lst).        *)
(* Pour les ensembles, ajoute si absent (SETCONJ).                   *)
Procedure ParseConjListForm(Var Res : TExprVal);
Var ArgRes : TExprVal;
    IsSet  : Boolean;
Begin
  ExprMakeNone(Res);
  EmitComment('(conj coll x)');

  (* Evaluer la collection (premier argument) *)
  ParseForm(ArgRes);
  IsSet := (ArgRes.TypeIdx = TY_IDX_SET);
  ExprFlushToAX(ArgRes);
  EmitInstrA('PUSH', 'AX');

  (* Evaluer l element a ajouter (deuxieme argument) *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);

  If IsSet Then
  Begin
    (* AX = val, POP -> set *)
    EmitInstrAB('MOV', 'BX', 'AX');
    EmitInstrA('POP', 'AX');
    EmitInstrA('CALL', CL_RT_PFX + 'SETCONJ');
    Res.Kind    := EK_AX;
    Res.TypeIdx := TY_IDX_SET;
    Res.ImmVal  := 0;
    Res.Offset  := 0;
    Res.SymIdx  := -1;
  End
  Else
  Begin
    (* AX = x (car), POP -> BX = coll (cdr) *)
    EmitInstrA('POP', 'BX');
    EmitInstrA('CALL', CL_RT_PFX + 'CONS');
    Res.Kind    := EK_AX;
    Res.TypeIdx := TY_IDX_LIST;
    Res.ImmVal  := 0;
    Res.Offset  := 0;
    Res.SymIdx  := -1;
  End;
End;

(* ---- ParseCountForm : (count coll) ----------------------------- *)
(* Polymorphe : chaines -> STRLEN, vecteurs -> [count],              *)
(* maps/sets -> [count], listes -> LCOUNT.                           *)
Procedure ParseCountForm(Var Res : TExprVal);
Var ArgRes : TExprVal;
Begin
  ExprMakeNone(Res);
  EmitComment('(count coll)');

  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);

  (* TODO 23 : dispatch polymorphe selon le type *)
  If ArgRes.TypeIdx = TY_IDX_STR Then
  Begin
    EmitInstrAB('MOV', 'SI', 'AX');
    EmitInstrA('CALL', CL_RT_PFX + 'STRLEN');
  End
  Else If (ArgRes.TypeIdx = TY_IDX_VEC) Or
          (ArgRes.TypeIdx = TY_IDX_MAP) Or
          (ArgRes.TypeIdx = TY_IDX_SET) Then
  Begin
    (* Layout : [count, ...] -> premier mot = nombre d elements *)
    EmitInstrAB('MOV', 'SI', 'AX');
    EmitInstrAB('MOV', 'AX', 'WORD PTR [SI]');
  End
  Else
    EmitInstrA('CALL', CL_RT_PFX + 'LCOUNT');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_INT;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseNthForm : (nth coll n) ------------------------------- *)
(* Parcourt la liste n fois (rest) puis retourne first.              *)
(* AX = liste, BX = index -> CALL _CLRT_LNTH -> AX = element        *)
Procedure ParseNthForm(Var Res : TExprVal);
Var ArgRes : TExprVal;
Begin
  ExprMakeNone(Res);
  EmitComment('(nth coll n)');

  (* Evaluer la collection *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrA('PUSH', 'AX');

  (* Evaluer l index *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'BX', 'AX');

  (* Recuperer la liste *)
  EmitInstrA('POP', 'AX');

  EmitInstrA('CALL', CL_RT_PFX + 'LNTH');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_UNKNOWN;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseEmptyForm : (empty? coll) ---------------------------- *)
(* Retourne true (1) si coll est nil, false (0) sinon.               *)
Procedure ParseEmptyForm(Var Res : TExprVal);
Var ArgRes : TExprVal;
    LblT   : TString;
    LblEnd : TString;
Begin
  ExprMakeNone(Res);
  EmitComment('(empty? coll)');
  LblT   := LabelGen;
  LblEnd := LabelGen;

  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);

  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JE', LblT);

  (* Non vide -> false *)
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstrA('JMP', LblEnd);

  (* Vide -> true *)
  EmitLabel(LblT);
  EmitInstrAB('MOV', 'AX', '1');

  EmitLabel(LblEnd);
  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_BOOL;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseSeqForm : (seq coll) --------------------------------- *)
(* Retourne la collection comme sequence, ou nil si vide.            *)
(* Pour une liste : retourne la liste elle-meme, ou nil si nil.      *)
Procedure ParseSeqForm(Var Res : TExprVal);
Var ArgRes : TExprVal;
Begin
  ExprMakeNone(Res);
  EmitComment('(seq coll)');

  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);

  (* AX contient deja le pointeur liste ou nil (0) *)
  (* seq retourne nil si la collection est vide, sinon la seq elle-meme *)
  (* Pour les listes, c est deja le cas : nil=0, non-nil=pointeur *)

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_LIST;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ============================================================
   TODO 18 - VECTEURS : VECTOR / GET / ASSOC / SUBVEC [IMPLEMENTE]
   ============================================================ *)

(* ---- ParseVectorForm : (vector a b c ...) ----------------------- *)
(* Cree un vecteur contigu sur le heap : [count, e0, e1, ..., eN-1]  *)
(* Chaque element = 1 Word, count = nombre d elements.               *)
Procedure ParseVectorForm(Var Res : TExprVal);
Var ArgRes   : TExprVal;
    ArgCount : Integer;
    I        : Integer;
Begin
  ExprMakeNone(Res);
  EmitComment('(vector ...)');
  ArgCount := 0;

  (* Empiler tous les arguments de gauche a droite *)
  While (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Do
  Begin
    ParseForm(ArgRes);
    ExprFlushToAX(ArgRes);
    EmitInstrA('PUSH', 'AX');
    Inc(ArgCount);
  End;

  (* Allouer le vecteur sur le heap *)
  EmitInstrAB('MOV', 'DI', 'WORD PTR [_CL_HEAPTOP]');
  EmitInstrAB('MOV', 'BX', 'OFFSET _CL_HEAP');
  EmitInstrAB('ADD', 'BX', 'DI');

  (* Stocker le nombre d elements *)
  EmitInstrAB('MOV', 'WORD PTR [BX]', IntToStr(ArgCount));

  (* Depiler les elements : la pile a [e_{n-1}, ..., e_0]        *)
  (* e_{n-1} est au sommet -> va a [BX + 2*n]                    *)
  (* e_0 est en bas        -> va a [BX + 2]                      *)
  For I := ArgCount DownTo 1 Do
  Begin
    EmitInstrA('POP', 'AX');
    EmitInstrAB('MOV', 'WORD PTR [BX+' + IntToStr(I * 2) + ']', 'AX');
  End;

  (* Resultat = pointeur vecteur *)
  EmitInstrAB('MOV', 'AX', 'BX');

  (* Mettre a jour heaptop *)
  EmitInstrAB('ADD', 'DI', IntToStr((ArgCount + 1) * 2));
  EmitInstrAB('MOV', 'WORD PTR [_CL_HEAPTOP]', 'DI');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_VEC;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseVecLiteral : [a b c ...] ------------------------------ *)
(* Litteral vecteur, meme mecanisme que (vector ...) mais ferme par ] *)
Procedure ParseVecLiteral(Var Res : TExprVal);
Var ArgRes   : TExprVal;
    ArgCount : Integer;
    I        : Integer;
Begin
  ExprMakeNone(Res);
  EmitComment('[...] litteral vecteur');
  ArgCount := 0;

  (* Empiler tous les elements *)
  While (CurToken.Kind <> TK_RBRACKET) And (CurToken.Kind <> TK_EOF) Do
  Begin
    ParseForm(ArgRes);
    ExprFlushToAX(ArgRes);
    EmitInstrA('PUSH', 'AX');
    Inc(ArgCount);
  End;

  If CurToken.Kind = TK_RBRACKET Then
    LexNextToken;

  (* Allouer le vecteur sur le heap *)
  EmitInstrAB('MOV', 'DI', 'WORD PTR [_CL_HEAPTOP]');
  EmitInstrAB('MOV', 'BX', 'OFFSET _CL_HEAP');
  EmitInstrAB('ADD', 'BX', 'DI');

  (* Stocker le nombre d elements *)
  EmitInstrAB('MOV', 'WORD PTR [BX]', IntToStr(ArgCount));

  (* Depiler les elements en ordre inverse *)
  For I := ArgCount DownTo 1 Do
  Begin
    EmitInstrA('POP', 'AX');
    EmitInstrAB('MOV', 'WORD PTR [BX+' + IntToStr(I * 2) + ']', 'AX');
  End;

  (* Resultat = pointeur vecteur *)
  EmitInstrAB('MOV', 'AX', 'BX');

  (* Mettre a jour heaptop *)
  EmitInstrAB('ADD', 'DI', IntToStr((ArgCount + 1) * 2));
  EmitInstrAB('MOV', 'WORD PTR [_CL_HEAPTOP]', 'DI');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_VEC;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseGetForm : (get coll key) ou (get coll key default) ---- *)
(* Polymorphe : TY_IDX_MAP -> MAPGET, TY_IDX_STR -> char a index,   *)
(* sinon VECNTH (acces indexe dans un vecteur).                      *)
(* AX = collection, BX = cle/index -> CALL runtime -> AX            *)
Procedure ParseGetForm(Var Res : TExprVal);
Var ArgRes  : TExprVal;
    HasDef  : Boolean;
    LblEnd  : TString;
    LblDef  : TString;
    IsMap   : Boolean;
    IsStr   : Boolean;
Begin
  ExprMakeNone(Res);
  EmitComment('(get coll key)');

  (* Evaluer la collection *)
  ParseForm(ArgRes);
  IsMap := (ArgRes.TypeIdx = TY_IDX_MAP);
  IsStr := (ArgRes.TypeIdx = TY_IDX_STR);
  ExprFlushToAX(ArgRes);
  EmitInstrA('PUSH', 'AX');

  (* Evaluer la cle/index *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'BX', 'AX');

  (* Verifier s il y a un argument par defaut *)
  HasDef := (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF);

  If HasDef Then
  Begin
    EmitInstrA('PUSH', 'BX');
    ParseForm(ArgRes);
    ExprFlushToAX(ArgRes);
    EmitInstrAB('MOV', 'CX', 'AX');  (* CX = default *)
    EmitInstrA('POP', 'BX');   (* BX = cle/index *)
  End;

  (* Recuperer la collection *)
  EmitInstrA('POP', 'AX');

  (* Appel runtime selon le type *)
  If IsMap Then
    EmitInstrA('CALL', CL_RT_PFX + 'MAPGET')
  Else If IsStr Then
  Begin
    (* TODO 23 : (get "abc" 1) -> code ASCII du caractere *)
    EmitInstrAB('MOV', 'SI', 'AX');
    EmitInstrAB('ADD', 'SI', 'BX');
    EmitInstrAB('XOR', 'AX', 'AX');
    EmitInstrAB('MOV', 'AL', 'BYTE PTR [SI]');
  End
  Else
    EmitInstrA('CALL', CL_RT_PFX + 'VECNTH');

  If HasDef Then
  Begin
    LblDef := LabelGen;
    LblEnd := LabelGen;
    (* Si resultat = 0 (nil), utiliser default *)
    EmitInstrAB('CMP', 'AX', '0');
    EmitInstrA('JE', LblDef);
    EmitInstrA('JMP', LblEnd);
    EmitLabel(LblDef);
    EmitInstrAB('MOV', 'AX', 'CX');
    EmitLabel(LblEnd);
  End;

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_UNKNOWN;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseAssocForm : (assoc coll key val) ---------------------- *)
(* Polymorphe : si la collection est TY_IDX_MAP, utilise MAPASSOC,   *)
(* sinon utilise VECASSOC.                                            *)
(* AX = coll, BX = cle/index, CX = nouvelle valeur                   *)
Procedure ParseAssocForm(Var Res : TExprVal);
Var ArgRes : TExprVal;
    IsMap  : Boolean;
Begin
  ExprMakeNone(Res);
  EmitComment('(assoc coll key val)');

  (* Evaluer la collection *)
  ParseForm(ArgRes);
  IsMap := (ArgRes.TypeIdx = TY_IDX_MAP);
  ExprFlushToAX(ArgRes);
  EmitInstrA('PUSH', 'AX');

  (* Evaluer la cle/index *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrA('PUSH', 'AX');

  (* Evaluer la nouvelle valeur *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'CX', 'AX');

  (* Recuperer cle et collection *)
  EmitInstrA('POP', 'BX');
  EmitInstrA('POP', 'AX');

  (* Appel runtime selon le type *)
  If IsMap Then
  Begin
    EmitInstrA('CALL', CL_RT_PFX + 'MAPASSOC');
    Res.TypeIdx := TY_IDX_MAP;
  End
  Else
  Begin
    EmitInstrA('CALL', CL_RT_PFX + 'VECASSOC');
    Res.TypeIdx := TY_IDX_VEC;
  End;

  Res.Kind    := EK_AX;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseSubvecForm : (subvec vec start end) ------------------- *)
(* Cree un sous-vecteur de start (inclus) a end (exclus).            *)
(* AX = vec, BX = start, CX = end                                    *)
Procedure ParseSubvecForm(Var Res : TExprVal);
Var ArgRes : TExprVal;
Begin
  ExprMakeNone(Res);
  EmitComment('(subvec vec start end)');

  (* Evaluer le vecteur *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrA('PUSH', 'AX');

  (* Evaluer start *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrA('PUSH', 'AX');

  (* Evaluer end *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'CX', 'AX');

  (* Recuperer start et vecteur *)
  EmitInstrA('POP', 'BX');
  EmitInstrA('POP', 'AX');

  (* Appel runtime subvec *)
  EmitInstrA('CALL', CL_RT_PFX + 'SUBVEC');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_VEC;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ============================================================
   TODO 19 - TABLES DE HACHAGE : HASH-MAP / DISSOC / CONTAINS?
             / KEYS / VALS / MERGE [IMPLEMENTE]
   ============================================================ *)

(* ---- ParseHashMapForm : (hash-map k1 v1 k2 v2 ...) ------------- *)
(* Cree une map sur le heap : [count_pairs, k0, v0, k1, v1, ...]    *)
(* count = nombre de paires, chaque paire = 2 Words.                 *)
Procedure ParseHashMapForm(Var Res : TExprVal);
Var ArgRes   : TExprVal;
    ArgCount : Integer;
    I        : Integer;
    NPairs   : Integer;
Begin
  ExprMakeNone(Res);
  EmitComment('(hash-map ...)');
  ArgCount := 0;

  (* Empiler tous les arguments : k1 v1 k2 v2 ... *)
  While (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Do
  Begin
    ParseForm(ArgRes);
    ExprFlushToAX(ArgRes);
    EmitInstrA('PUSH', 'AX');
    Inc(ArgCount);
  End;

  If (ArgCount Mod 2) <> 0 Then
    WarnMsg('hash-map : nombre impair d arguments');

  NPairs := ArgCount Div 2;

  (* Allouer la map sur le heap *)
  EmitInstrAB('MOV', 'DI', 'WORD PTR [_CL_HEAPTOP]');
  EmitInstrAB('MOV', 'BX', 'OFFSET _CL_HEAP');
  EmitInstrAB('ADD', 'BX', 'DI');

  (* Stocker le nombre de paires *)
  EmitInstrAB('MOV', 'WORD PTR [BX]', IntToStr(NPairs));

  (* Depiler : la pile a [vN, kN, ..., v1, k1] (inverse) *)
  (* Le dernier pousse (vN) est au sommet                  *)
  (* On veut : [BX+2]=k1, [BX+4]=v1, [BX+6]=k2, ...      *)
  (* Pile (sommet -> fond) : vN, kN, ..., v1, k1           *)
  (* => depiler en ordre inverse : [BX + ArgCount*2] .. [BX+2] *)
  For I := ArgCount DownTo 1 Do
  Begin
    EmitInstrA('POP', 'AX');
    EmitInstrAB('MOV', 'WORD PTR [BX+' + IntToStr(I * 2) + ']', 'AX');
  End;

  (* Resultat = pointeur map *)
  EmitInstrAB('MOV', 'AX', 'BX');

  (* Mettre a jour heaptop : 1 Word (count) + ArgCount Words *)
  EmitInstrAB('ADD', 'DI', IntToStr((ArgCount + 1) * 2));
  EmitInstrAB('MOV', 'WORD PTR [_CL_HEAPTOP]', 'DI');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_MAP;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseMapLiteral : {:k1 v1 :k2 v2 ...} -------------------- *)
(* Litteral map, meme mecanisme que (hash-map ...) ferme par }       *)
Procedure ParseMapLiteral(Var Res : TExprVal);
Var ArgRes   : TExprVal;
    ArgCount : Integer;
    I        : Integer;
    NPairs   : Integer;
Begin
  ExprMakeNone(Res);
  EmitComment('{...} litteral map');
  ArgCount := 0;

  (* Empiler tous les elements : k1 v1 k2 v2 ... *)
  While (CurToken.Kind <> TK_RBRACE) And (CurToken.Kind <> TK_EOF) Do
  Begin
    ParseForm(ArgRes);
    ExprFlushToAX(ArgRes);
    EmitInstrA('PUSH', 'AX');
    Inc(ArgCount);
  End;

  If CurToken.Kind = TK_RBRACE Then
    LexNextToken;

  If (ArgCount Mod 2) <> 0 Then
    WarnMsg('map literal : nombre impair d elements');

  NPairs := ArgCount Div 2;

  (* Allouer la map sur le heap *)
  EmitInstrAB('MOV', 'DI', 'WORD PTR [_CL_HEAPTOP]');
  EmitInstrAB('MOV', 'BX', 'OFFSET _CL_HEAP');
  EmitInstrAB('ADD', 'BX', 'DI');

  (* Stocker le nombre de paires *)
  EmitInstrAB('MOV', 'WORD PTR [BX]', IntToStr(NPairs));

  (* Depiler en ordre inverse *)
  For I := ArgCount DownTo 1 Do
  Begin
    EmitInstrA('POP', 'AX');
    EmitInstrAB('MOV', 'WORD PTR [BX+' + IntToStr(I * 2) + ']', 'AX');
  End;

  (* Resultat = pointeur map *)
  EmitInstrAB('MOV', 'AX', 'BX');

  (* Mettre a jour heaptop *)
  EmitInstrAB('ADD', 'DI', IntToStr((ArgCount + 1) * 2));
  EmitInstrAB('MOV', 'WORD PTR [_CL_HEAPTOP]', 'DI');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_MAP;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseDissocForm : (dissoc m key) --------------------------- *)
(* Cree une copie de la map sans la paire dont la cle est key.        *)
(* AX = map, BX = cle a supprimer -> CALL _CLRT_MAPDISSOC -> AX     *)
Procedure ParseDissocForm(Var Res : TExprVal);
Var ArgRes : TExprVal;
Begin
  ExprMakeNone(Res);
  EmitComment('(dissoc m key)');

  (* Evaluer la map *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrA('PUSH', 'AX');

  (* Evaluer la cle *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'BX', 'AX');

  (* Recuperer la map *)
  EmitInstrA('POP', 'AX');

  (* Appel runtime *)
  EmitInstrA('CALL', CL_RT_PFX + 'MAPDISSOC');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_MAP;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseContainsForm : (contains? coll key) ------------------- *)
(* Polymorphe : si la collection est TY_IDX_SET, utilise SETHAS,     *)
(* sinon utilise MAPHAS (recherche par cle dans une map).             *)
(* AX = coll, BX = cle/val -> CALL runtime -> AX = 1|0              *)
Procedure ParseContainsForm(Var Res : TExprVal);
Var ArgRes : TExprVal;
    IsSet  : Boolean;
Begin
  ExprMakeNone(Res);
  EmitComment('(contains? coll key)');

  (* Evaluer la collection *)
  ParseForm(ArgRes);
  IsSet := (ArgRes.TypeIdx = TY_IDX_SET);
  ExprFlushToAX(ArgRes);
  EmitInstrA('PUSH', 'AX');

  (* Evaluer la cle/valeur *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'BX', 'AX');

  (* Recuperer la collection *)
  EmitInstrA('POP', 'AX');

  (* Appel runtime selon le type *)
  If IsSet Then
    EmitInstrA('CALL', CL_RT_PFX + 'SETHAS')
  Else
    EmitInstrA('CALL', CL_RT_PFX + 'MAPHAS');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_BOOL;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseKeysForm : (keys m) ----------------------------------- *)
(* Retourne la liste des cles de la map.                              *)
(* AX = map -> CALL _CLRT_MAPKEYS -> AX = liste des cles            *)
Procedure ParseKeysForm(Var Res : TExprVal);
Var ArgRes : TExprVal;
Begin
  ExprMakeNone(Res);
  EmitComment('(keys m)');

  (* Evaluer la map *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);

  (* Appel runtime *)
  EmitInstrA('CALL', CL_RT_PFX + 'MAPKEYS');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_LIST;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseValsForm : (vals m) ----------------------------------- *)
(* Retourne la liste des valeurs de la map.                           *)
(* AX = map -> CALL _CLRT_MAPVALS -> AX = liste des valeurs         *)
Procedure ParseValsForm(Var Res : TExprVal);
Var ArgRes : TExprVal;
Begin
  ExprMakeNone(Res);
  EmitComment('(vals m)');

  (* Evaluer la map *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);

  (* Appel runtime *)
  EmitInstrA('CALL', CL_RT_PFX + 'MAPVALS');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_LIST;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseMergeForm : (merge m1 m2) ----------------------------- *)
(* Fusionne deux maps. Les cles de m2 ecrasent celles de m1.         *)
(* AX = m1, BX = m2 -> CALL _CLRT_MAPMERGE -> AX = nouvelle map     *)
Procedure ParseMergeForm(Var Res : TExprVal);
Var ArgRes : TExprVal;
Begin
  ExprMakeNone(Res);
  EmitComment('(merge m1 m2)');

  (* Evaluer m1 *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrA('PUSH', 'AX');

  (* Evaluer m2 *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'BX', 'AX');

  (* Recuperer m1 *)
  EmitInstrA('POP', 'AX');

  (* Appel runtime *)
  EmitInstrA('CALL', CL_RT_PFX + 'MAPMERGE');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_MAP;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ============================================================
   TODO 20 - ENSEMBLES : HASH-SET / CONTAINS? / CONJ / DISJ
             / UNION / INTERSECTION / DIFFERENCE [IMPLEMENTE]
   ============================================================ *)

(* ---- ParseHashSetForm : (hash-set a b c) ----------------------- *)
(* Cree un ensemble sur le heap : [count, e0, e1, ..., eN-1]        *)
(* Les doublons sont elimines a la compilation (comparaison naive).  *)
Procedure ParseHashSetForm(Var Res : TExprVal);
Var ArgRes   : TExprVal;
    ArgCount : Integer;
    I        : Integer;
Begin
  ExprMakeNone(Res);
  EmitComment('(hash-set ...)');
  ArgCount := 0;

  (* Empiler tous les arguments *)
  While (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Do
  Begin
    ParseForm(ArgRes);
    ExprFlushToAX(ArgRes);
    EmitInstrA('PUSH', 'AX');
    Inc(ArgCount);
  End;

  (* Allouer l ensemble sur le heap *)
  EmitInstrAB('MOV', 'DI', 'WORD PTR [_CL_HEAPTOP]');
  EmitInstrAB('MOV', 'BX', 'OFFSET _CL_HEAP');
  EmitInstrAB('ADD', 'BX', 'DI');

  (* Stocker le nombre d elements *)
  EmitInstrAB('MOV', 'WORD PTR [BX]', IntToStr(ArgCount));

  (* Depiler les elements en ordre inverse *)
  For I := ArgCount DownTo 1 Do
  Begin
    EmitInstrA('POP', 'AX');
    EmitInstrAB('MOV', 'WORD PTR [BX+' + IntToStr(I * 2) + ']', 'AX');
  End;

  (* Resultat = pointeur ensemble *)
  EmitInstrAB('MOV', 'AX', 'BX');

  (* Mettre a jour heaptop *)
  EmitInstrAB('ADD', 'DI', IntToStr((ArgCount + 1) * 2));
  EmitInstrAB('MOV', 'WORD PTR [_CL_HEAPTOP]', 'DI');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_SET;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseSetLiteral : #{a b c} -------------------------------- *)
(* Litteral ensemble, meme mecanisme que (hash-set ...) ferme par }  *)
Procedure ParseSetLiteral(Var Res : TExprVal);
Var ArgRes   : TExprVal;
    ArgCount : Integer;
    I        : Integer;
Begin
  ExprMakeNone(Res);
  EmitComment('#{...} litteral ensemble');
  ArgCount := 0;

  (* Empiler tous les elements *)
  While (CurToken.Kind <> TK_RBRACE) And (CurToken.Kind <> TK_EOF) Do
  Begin
    ParseForm(ArgRes);
    ExprFlushToAX(ArgRes);
    EmitInstrA('PUSH', 'AX');
    Inc(ArgCount);
  End;

  If CurToken.Kind = TK_RBRACE Then
    LexNextToken;

  (* Allouer l ensemble sur le heap *)
  EmitInstrAB('MOV', 'DI', 'WORD PTR [_CL_HEAPTOP]');
  EmitInstrAB('MOV', 'BX', 'OFFSET _CL_HEAP');
  EmitInstrAB('ADD', 'BX', 'DI');

  (* Stocker le nombre d elements *)
  EmitInstrAB('MOV', 'WORD PTR [BX]', IntToStr(ArgCount));

  (* Depiler les elements en ordre inverse *)
  For I := ArgCount DownTo 1 Do
  Begin
    EmitInstrA('POP', 'AX');
    EmitInstrAB('MOV', 'WORD PTR [BX+' + IntToStr(I * 2) + ']', 'AX');
  End;

  (* Resultat = pointeur ensemble *)
  EmitInstrAB('MOV', 'AX', 'BX');

  (* Mettre a jour heaptop *)
  EmitInstrAB('ADD', 'DI', IntToStr((ArgCount + 1) * 2));
  EmitInstrAB('MOV', 'WORD PTR [_CL_HEAPTOP]', 'DI');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_SET;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseDisjForm : (disj s val) ------------------------------ *)
(* Copie l ensemble sans l element val.                               *)
(* AX = set, BX = val -> CALL _CLRT_SETDISJ -> AX = nouveau set     *)
Procedure ParseDisjForm(Var Res : TExprVal);
Var ArgRes : TExprVal;
Begin
  ExprMakeNone(Res);
  EmitComment('(disj s val)');

  (* Evaluer l ensemble *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrA('PUSH', 'AX');

  (* Evaluer la valeur a retirer *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'BX', 'AX');

  (* Recuperer l ensemble *)
  EmitInstrA('POP', 'AX');

  (* Appel runtime *)
  EmitInstrA('CALL', CL_RT_PFX + 'SETDISJ');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_SET;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseUnionForm : (union s1 s2) ---------------------------- *)
(* Fusionne deux ensembles sans doublons.                             *)
(* AX = set1, BX = set2 -> CALL _CLRT_SETUNION -> AX = nouveau set  *)
Procedure ParseUnionForm(Var Res : TExprVal);
Var ArgRes : TExprVal;
Begin
  ExprMakeNone(Res);
  EmitComment('(union s1 s2)');

  (* Evaluer le premier ensemble *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrA('PUSH', 'AX');

  (* Evaluer le deuxieme ensemble *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'BX', 'AX');

  (* Recuperer le premier ensemble *)
  EmitInstrA('POP', 'AX');

  (* Appel runtime *)
  EmitInstrA('CALL', CL_RT_PFX + 'SETUNION');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_SET;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseInterForm : (intersection s1 s2) --------------------- *)
(* Retourne les elements communs aux deux ensembles.                  *)
(* AX = set1, BX = set2 -> CALL _CLRT_SETINTER -> AX = nouveau set  *)
Procedure ParseInterForm(Var Res : TExprVal);
Var ArgRes : TExprVal;
Begin
  ExprMakeNone(Res);
  EmitComment('(intersection s1 s2)');

  (* Evaluer le premier ensemble *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrA('PUSH', 'AX');

  (* Evaluer le deuxieme ensemble *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'BX', 'AX');

  (* Recuperer le premier ensemble *)
  EmitInstrA('POP', 'AX');

  (* Appel runtime *)
  EmitInstrA('CALL', CL_RT_PFX + 'SETINTER');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_SET;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseDiffForm : (difference s1 s2) ------------------------ *)
(* Retourne les elements de s1 absents de s2.                         *)
(* AX = set1, BX = set2 -> CALL _CLRT_SETDIFF -> AX = nouveau set   *)
Procedure ParseDiffForm(Var Res : TExprVal);
Var ArgRes : TExprVal;
Begin
  ExprMakeNone(Res);
  EmitComment('(difference s1 s2)');

  (* Evaluer le premier ensemble *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrA('PUSH', 'AX');

  (* Evaluer le deuxieme ensemble *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'BX', 'AX');

  (* Recuperer le premier ensemble *)
  EmitInstrA('POP', 'AX');

  (* Appel runtime *)
  EmitInstrA('CALL', CL_RT_PFX + 'SETDIFF');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_SET;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ============================================================
   TODO 21 - DESTRUCTURATION (DESTRUCTURING) [IMPLEMENTE]
   ============================================================ *)

(* ---- EmitDestrucVec : destructuration sequentielle (vecteur) --- *)
(* La valeur a destructurer est dans [BP-ValOfs].                    *)
(* Le token courant est juste apres le '[' consomme par l appelant.  *)
(* Pour chaque symbole, on genere :                                  *)
(*   AX = [BP-ValOfs]                                                *)
(*   BX = index                                                      *)
(*   CALL _CLRT_VECNTH                                               *)
(*   MOV [BP-Ofs], AX                                                *)
(* Le symbole _ est ignore (pas de liaison).                         *)
(* & rest : genere un appel _CLRT_VECDROP pour le reste du vecteur. *)
Procedure EmitDestrucVec(ValOfs : Integer);
Var
  Idx       : Integer;
  VarName   : TString;
  Ofs       : Integer;
  S         : TString;
  SV        : TString;
  HasRest   : Boolean;
  RestName  : TString;
  SubOfs    : Integer;
Begin
  EmitComment('destrVec [...]');
  Idx := 0;
  HasRest := False;
  RestName := '';

  While (CurToken.Kind <> TK_RBRACKET) And (CurToken.Kind <> TK_EOF) Do
  Begin
    (* Detecter & rest *)
    If (CurToken.Kind = TK_SYMBOL) And (CurToken.Val = '&') Then
    Begin
      LexNextToken;  (* consomme '&' *)
      HasRest := True;
      If CurToken.Kind = TK_SYMBOL Then
      Begin
        RestName := CurToken.Val;
        LexNextToken;  (* consomme le nom du rest *)
      End
      Else
        CompileError('symbole attendu apres & dans destructuration');
      Continue;
    End;

    (* Detecter destructuration imbriquee : [a [b c] d] *)
    If CurToken.Kind = TK_LBRACKET Then
    Begin
      (* Evaluer nth d abord, stocker dans un local temporaire *)
      Inc(CurFrameSize, 2);
      SubOfs := CurFrameSize;
      EmitInstrAB('SUB', 'SP', '2');

      Str(ValOfs, SV);
      EmitInstrAB('MOV', 'AX', 'WORD PTR [BP-' + SV + ']');
      Str(Idx, S);
      EmitInstrAB('MOV', 'BX', S);
      EmitInstrA('CALL', CL_RT_PFX + 'VECNTH');
      Str(SubOfs, S);
      EmitInstrAB('MOV', 'WORD PTR [BP-' + S + ']', 'AX');

      LexNextToken;  (* consomme '[' *)
      EmitDestrucVec(SubOfs);
      If CurToken.Kind = TK_RBRACKET Then
        LexNextToken  (* consomme ']' *)
      Else
        CompileError('] attendu en fin de destructuration imbriquee');
      Inc(Idx);
      Continue;
    End;

    (* Detecter destructuration imbriquee map : [a {b :x} d] *)
    If CurToken.Kind = TK_LBRACE Then
    Begin
      Inc(CurFrameSize, 2);
      SubOfs := CurFrameSize;
      EmitInstrAB('SUB', 'SP', '2');

      Str(ValOfs, SV);
      EmitInstrAB('MOV', 'AX', 'WORD PTR [BP-' + SV + ']');
      Str(Idx, S);
      EmitInstrAB('MOV', 'BX', S);
      EmitInstrA('CALL', CL_RT_PFX + 'VECNTH');
      Str(SubOfs, S);
      EmitInstrAB('MOV', 'WORD PTR [BP-' + S + ']', 'AX');

      LexNextToken;  (* consomme '{' *)
      EmitDestrucMap(SubOfs);
      If CurToken.Kind = TK_RBRACE Then
        LexNextToken  (* consomme '}' *)
      Else
        CompileError('} attendu en fin de destructuration imbriquee');
      Inc(Idx);
      Continue;
    End;

    If CurToken.Kind <> TK_SYMBOL Then
    Begin
      CompileError('symbole attendu dans destructuration vecteur');
      LexNextToken;
      Continue;
    End;
    VarName := CurToken.Val;
    LexNextToken;

    (* _ ignore l element *)
    If VarName = '_' Then
    Begin
      Inc(Idx);
      Continue;
    End;

    (* Allouer un local *)
    Inc(CurFrameSize, 2);
    Ofs := CurFrameSize;
    EmitInstrAB('SUB', 'SP', '2');

    (* AX = collection, BX = index, CALL VECNTH *)
    Str(ValOfs, SV);
    EmitInstrAB('MOV', 'AX', 'WORD PTR [BP-' + SV + ']');
    Str(Idx, S);
    EmitInstrAB('MOV', 'BX', S);
    EmitInstrA('CALL', CL_RT_PFX + 'VECNTH');

    (* Stocker *)
    Str(Ofs, S);
    EmitInstrAB('MOV', 'WORD PTR [BP-' + S + ']', 'AX');

    (* Enregistrer le symbole *)
    SymAdd(VarName, SK_LOCAL, TY_UNKNOWN, -Ofs);

    Inc(Idx);
  End;

  (* & rest : generer le sous-vecteur a partir de l index Idx *)
  If HasRest And (RestName <> '') Then
  Begin
    Inc(CurFrameSize, 2);
    Ofs := CurFrameSize;
    EmitInstrAB('SUB', 'SP', '2');

    Str(ValOfs, SV);
    EmitInstrAB('MOV', 'AX', 'WORD PTR [BP-' + SV + ']');
    Str(Idx, S);
    EmitInstrAB('MOV', 'BX', S);
    EmitInstrA('CALL', CL_RT_PFX + 'VECDROP');

    Str(Ofs, S);
    EmitInstrAB('MOV', 'WORD PTR [BP-' + S + ']', 'AX');
    SymAdd(RestName, SK_LOCAL, TY_IDX_VEC, -Ofs);
  End;
End;

(* ---- EmitDestrucMap : destructuration associative (map) --------- *)
(* La valeur a destructurer est dans [BP-ValOfs].                     *)
(* Le token courant est juste apres le '{' consomme par l appelant.   *)
(* Formes supportees :                                                *)
(*   {:keys [a b c]} -> a=(get m :a), b=(get m :b), c=(get m :c)     *)
(*   {x :nom y :age} -> x=(get m :nom), y=(get m :age)               *)
(*   {:keys [a] :or {a 0}} -> valeur par defaut si get retourne nil   *)
Procedure EmitDestrucMap(ValOfs : Integer);
Var
  VarName   : TString;
  Ofs       : Integer;
  S         : TString;
  SV        : TString;
  KIdx      : Integer;
  HasOr     : Boolean;
  OrNames   : Array[0..MAX_PARAM - 1] Of TString;
  OrVals    : Array[0..MAX_PARAM - 1] Of LongInt;
  OrCount   : Integer;
  OrOfs     : Array[0..MAX_PARAM - 1] Of Integer;
  I         : Integer;
  LblDef    : TString;
  LblEnd    : TString;
Begin
  EmitComment('destrMap {...}');
  HasOr   := False;
  OrCount := 0;

  While (CurToken.Kind <> TK_RBRACE) And (CurToken.Kind <> TK_EOF) Do
  Begin
    (* :keys [a b c] *)
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'keys') Then
    Begin
      LexNextToken;  (* consomme :keys *)

      If CurToken.Kind <> TK_LBRACKET Then
      Begin
        CompileError('[ attendu apres :keys');
        Continue;
      End;
      LexNextToken;  (* consomme '[' *)

      While (CurToken.Kind <> TK_RBRACKET) And (CurToken.Kind <> TK_EOF) Do
      Begin
        If CurToken.Kind <> TK_SYMBOL Then
        Begin
          CompileError('symbole attendu dans :keys');
          LexNextToken;
          Continue;
        End;
        VarName := CurToken.Val;
        LexNextToken;

        (* Allouer un local *)
        Inc(CurFrameSize, 2);
        Ofs := CurFrameSize;
        EmitInstrAB('SUB', 'SP', '2');

        (* AX = map, BX = keyword index pour :VarName *)
        KIdx := KwAdd(VarName);
        Str(ValOfs, SV);
        EmitInstrAB('MOV', 'AX', 'WORD PTR [BP-' + SV + ']');
        Str(KIdx, S);
        EmitInstrAB('MOV', 'BX', S);
        EmitInstrA('CALL', CL_RT_PFX + 'MAPGET');

        Str(Ofs, S);
        EmitInstrAB('MOV', 'WORD PTR [BP-' + S + ']', 'AX');
        SymAdd(VarName, SK_LOCAL, TY_UNKNOWN, -Ofs);

        (* Memoriser pour :or *)
        If OrCount < MAX_PARAM Then
        Begin
          OrNames[OrCount] := VarName;
          OrVals[OrCount]  := 0;
          OrOfs[OrCount]   := Ofs;
          Inc(OrCount);
        End;
      End;

      If CurToken.Kind = TK_RBRACKET Then
        LexNextToken  (* consomme ']' *)
      Else
        CompileError('] attendu apres :keys [...]');

      Continue;
    End;

    (* :or {a default-val b default-val} *)
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'or') Then
    Begin
      LexNextToken;  (* consomme :or *)
      HasOr := True;

      If CurToken.Kind <> TK_LBRACE Then
      Begin
        CompileError('{ attendu apres :or');
        Continue;
      End;
      LexNextToken;  (* consomme '{' *)

      While (CurToken.Kind <> TK_RBRACE) And (CurToken.Kind <> TK_EOF) Do
      Begin
        If CurToken.Kind <> TK_SYMBOL Then
        Begin
          LexNextToken;
          Continue;
        End;
        VarName := CurToken.Val;
        LexNextToken;

        (* Lire la valeur par defaut (entier attendu) *)
        If CurToken.Kind = TK_INTEGER Then
        Begin
          For I := 0 To OrCount - 1 Do
          Begin
            If OrNames[I] = VarName Then
              OrVals[I] := CurToken.IntVal;
          End;
          LexNextToken;
        End
        Else
        Begin
          (* Valeur par defaut non-entiere : ignorer *)
          LexNextToken;
        End;
      End;

      If CurToken.Kind = TK_RBRACE Then
        LexNextToken  (* consomme '}' *)
      Else
        CompileError('} attendu apres :or {...}');

      Continue;
    End;

    (* Forme explicite : {x :nom y :age} *)
    (* symbole suivi de keyword *)
    If CurToken.Kind = TK_SYMBOL Then
    Begin
      VarName := CurToken.Val;
      LexNextToken;

      If CurToken.Kind <> TK_KEYWORD Then
      Begin
        CompileError('keyword attendu apres symbole dans destructuration map');
        Continue;
      End;

      KIdx := KwAdd(CurToken.Val);
      LexNextToken;

      (* Allouer un local *)
      Inc(CurFrameSize, 2);
      Ofs := CurFrameSize;
      EmitInstrAB('SUB', 'SP', '2');

      Str(ValOfs, SV);
      EmitInstrAB('MOV', 'AX', 'WORD PTR [BP-' + SV + ']');
      Str(KIdx, S);
      EmitInstrAB('MOV', 'BX', S);
      EmitInstrA('CALL', CL_RT_PFX + 'MAPGET');

      Str(Ofs, S);
      EmitInstrAB('MOV', 'WORD PTR [BP-' + S + ']', 'AX');
      SymAdd(VarName, SK_LOCAL, TY_UNKNOWN, -Ofs);

      Continue;
    End;

    (* Token non reconnu dans destructuration map *)
    LexNextToken;
  End;

  (* Appliquer les valeurs par defaut :or si HasOr *)
  If HasOr Then
  Begin
    For I := 0 To OrCount - 1 Do
    Begin
      LblDef := LabelGen;
      LblEnd := LabelGen;
      Str(OrOfs[I], S);
      EmitInstrAB('CMP', 'WORD PTR [BP-' + S + ']', '0');
      EmitInstrA('JNE', LblEnd);
      EmitLabel(LblDef);
      Str(OrVals[I], SV);
      EmitInstrAB('MOV', 'WORD PTR [BP-' + S + ']', SV);
      EmitLabel(LblEnd);
    End;
  End;
End;

(* ---- EmitDestrucBind : dispatcher de destructuration ------------ *)
(* La valeur a destructurer est dans [BP-ValOfs].                     *)
(* Le token courant est '[' ou '{'.                                   *)
(* Detecte le type et appelle le bon helper.                          *)
Procedure EmitDestrucBind(ValOfs : Integer);
Begin
  If CurToken.Kind = TK_LBRACKET Then
  Begin
    LexNextToken;  (* consomme '[' *)
    EmitDestrucVec(ValOfs);
    If CurToken.Kind = TK_RBRACKET Then
      LexNextToken  (* consomme ']' *)
    Else
      CompileError('] attendu en fin de destructuration vecteur');
  End
  Else If CurToken.Kind = TK_LBRACE Then
  Begin
    LexNextToken;  (* consomme '{' *)
    EmitDestrucMap(ValOfs);
    If CurToken.Kind = TK_RBRACE Then
      LexNextToken  (* consomme '}' *)
    Else
      CompileError('} attendu en fin de destructuration map');
  End
  Else
    CompileError('[ ou { attendu pour destructuration');
End;

(* ============================================================
   TODO 22 - FONCTIONS D ORDRE SUPERIEUR (map / filter / reduce)
             [IMPLEMENTE]
   ============================================================ *)

(* ---- ParseMapHOFForm : (map f coll) ----------------------------- *)
(* Applique la fonction f a chaque element de coll (liste).           *)
(* Resultat : nouvelle liste des (f elem).                            *)
(* Strategie : parcourir la liste, appeler f via CALL indirect,       *)
(*   accumuler par cons en ordre inverse, puis renverser.             *)
Procedure ParseMapHOFForm(Var Res : TExprVal);
Var ArgRes  : TExprVal;
    LblLoop : TString;
    LblDone : TString;
Begin
  ExprMakeNone(Res);
  EmitComment('(map f coll)');

  (* Evaluer f -> adresse de fonction *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP1]', 'AX');

  (* Evaluer coll -> pointeur liste *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP2]', 'AX');

  (* Initialiser le resultat a nil *)
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP3]', '0');

  LblLoop := LabelGen;
  LblDone := LabelGen;

  EmitLabel(LblLoop);
  EmitInstrAB('MOV', 'SI', 'WORD PTR [_CL_HFTMP2]');
  EmitInstrAB('CMP', 'SI', '0');
  EmitInstrA('JE', LblDone);

  (* Appeler f(car(current)) *)
  EmitInstrAB('MOV', 'AX', 'WORD PTR [SI]');
  EmitInstrA('PUSH', 'AX');
  EmitRaw('        CALL    WORD PTR [_CL_HFTMP1]');
  EmitInstrAB('ADD', 'SP', '2');

  (* Cons resultat sur la liste accumulee *)
  EmitInstrAB('MOV', 'BX', 'WORD PTR [_CL_HFTMP3]');
  EmitInstrA('CALL', CL_RT_PFX + 'CONS');
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP3]', 'AX');

  (* Avancer au cdr *)
  EmitInstrAB('MOV', 'SI', 'WORD PTR [_CL_HFTMP2]');
  EmitInstrAB('MOV', 'SI', 'WORD PTR [SI+2]');
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP2]', 'SI');
  EmitInstrA('JMP', LblLoop);

  EmitLabel(LblDone);
  (* Renverser la liste accumulee *)
  EmitInstrAB('MOV', 'AX', 'WORD PTR [_CL_HFTMP3]');
  EmitInstrA('CALL', CL_RT_PFX + 'LREV');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_LIST;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseFilterForm : (filter pred coll) ----------------------- *)
(* Garde les elements pour lesquels (pred elem) est vrai (non nil).  *)
Procedure ParseFilterForm(Var Res : TExprVal);
Var ArgRes  : TExprVal;
    LblLoop : TString;
    LblDone : TString;
    LblSkip : TString;
Begin
  ExprMakeNone(Res);
  EmitComment('(filter pred coll)');

  (* Evaluer pred -> adresse de fonction *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP1]', 'AX');

  (* Evaluer coll -> pointeur liste *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP2]', 'AX');

  (* Initialiser le resultat a nil *)
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP3]', '0');

  LblLoop := LabelGen;
  LblDone := LabelGen;
  LblSkip := LabelGen;

  EmitLabel(LblLoop);
  EmitInstrAB('MOV', 'SI', 'WORD PTR [_CL_HFTMP2]');
  EmitInstrAB('CMP', 'SI', '0');
  EmitInstrA('JE', LblDone);

  (* Appeler pred(car(current)) *)
  EmitInstrAB('MOV', 'AX', 'WORD PTR [SI]');
  EmitInstrA('PUSH', 'AX');
  EmitRaw('        CALL    WORD PTR [_CL_HFTMP1]');
  EmitInstrAB('ADD', 'SP', '2');

  (* Si resultat = 0 (false/nil), sauter *)
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JE', LblSkip);

  (* Cons l element original sur la liste accumulee *)
  EmitInstrAB('MOV', 'SI', 'WORD PTR [_CL_HFTMP2]');
  EmitInstrAB('MOV', 'AX', 'WORD PTR [SI]');
  EmitInstrAB('MOV', 'BX', 'WORD PTR [_CL_HFTMP3]');
  EmitInstrA('CALL', CL_RT_PFX + 'CONS');
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP3]', 'AX');

  EmitLabel(LblSkip);
  (* Avancer au cdr *)
  EmitInstrAB('MOV', 'SI', 'WORD PTR [_CL_HFTMP2]');
  EmitInstrAB('MOV', 'SI', 'WORD PTR [SI+2]');
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP2]', 'SI');
  EmitInstrA('JMP', LblLoop);

  EmitLabel(LblDone);
  (* Renverser la liste accumulee *)
  EmitInstrAB('MOV', 'AX', 'WORD PTR [_CL_HFTMP3]');
  EmitInstrA('CALL', CL_RT_PFX + 'LREV');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_LIST;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseReduceForm : (reduce f init coll) ou (reduce f coll) -- *)
(* Forme 3 args : acc=init, boucle (f acc elem) sur coll.            *)
(* Forme 2 args : acc=first(coll), boucle sur rest(coll).            *)
Procedure ParseReduceForm(Var Res : TExprVal);
Var ArgRes  : TExprVal;
    LblLoop : TString;
    LblDone : TString;
    ArgCount: Integer;
Begin
  ExprMakeNone(Res);
  EmitComment('(reduce f ...)');

  (* Evaluer f -> adresse de fonction *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP1]', 'AX');

  (* Evaluer le deuxieme argument *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrA('PUSH', 'AX');

  (* Determiner si on a 2 ou 3 args *)
  ArgCount := 2;
  If (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF) Then
  Begin
    ArgCount := 3;
    (* 3 args : le 2eme est init, le 3eme est coll *)
    (* AX (empile) = init *)
    ParseForm(ArgRes);
    ExprFlushToAX(ArgRes);
    (* AX = coll *)
    EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP2]', 'AX');
    EmitInstrA('POP', 'AX');
    EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP3]', 'AX');
  End
  Else
  Begin
    (* 2 args : le 2eme est coll, init = first(coll), iterate rest *)
    EmitInstrA('POP', 'AX');
    EmitInstrAB('CMP', 'AX', '0');
    LblDone := LabelGen;
    EmitInstrA('JE', LblDone);
    EmitInstrAB('MOV', 'SI', 'AX');
    EmitInstrAB('MOV', 'BX', 'WORD PTR [SI]');
    EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP3]', 'BX');
    EmitInstrAB('MOV', 'SI', 'WORD PTR [SI+2]');
    EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP2]', 'SI');
  End;

  LblLoop := LabelGen;
  If ArgCount = 3 Then
    LblDone := LabelGen;

  EmitLabel(LblLoop);
  EmitInstrAB('MOV', 'SI', 'WORD PTR [_CL_HFTMP2]');
  EmitInstrAB('CMP', 'SI', '0');
  EmitInstrA('JE', LblDone);

  (* Appeler f(acc, car(current)) *)
  EmitInstrAB('MOV', 'AX', 'WORD PTR [_CL_HFTMP3]');
  EmitInstrA('PUSH', 'AX');
  EmitInstrAB('MOV', 'AX', 'WORD PTR [SI]');
  EmitInstrA('PUSH', 'AX');
  EmitRaw('        CALL    WORD PTR [_CL_HFTMP1]');
  EmitInstrAB('ADD', 'SP', '4');

  (* Mettre a jour l accumulateur *)
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP3]', 'AX');

  (* Avancer au cdr *)
  EmitInstrAB('MOV', 'SI', 'WORD PTR [_CL_HFTMP2]');
  EmitInstrAB('MOV', 'SI', 'WORD PTR [SI+2]');
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP2]', 'SI');
  EmitInstrA('JMP', LblLoop);

  EmitLabel(LblDone);
  EmitInstrAB('MOV', 'AX', 'WORD PTR [_CL_HFTMP3]');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_UNKNOWN;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseRemoveForm : (remove pred coll) ----------------------- *)
(* Comme filter mais garde les elements pour lesquels pred est faux. *)
Procedure ParseRemoveForm(Var Res : TExprVal);
Var ArgRes  : TExprVal;
    LblLoop : TString;
    LblDone : TString;
    LblSkip : TString;
Begin
  ExprMakeNone(Res);
  EmitComment('(remove pred coll)');

  (* Evaluer pred -> adresse de fonction *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP1]', 'AX');

  (* Evaluer coll -> pointeur liste *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP2]', 'AX');

  (* Initialiser le resultat a nil *)
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP3]', '0');

  LblLoop := LabelGen;
  LblDone := LabelGen;
  LblSkip := LabelGen;

  EmitLabel(LblLoop);
  EmitInstrAB('MOV', 'SI', 'WORD PTR [_CL_HFTMP2]');
  EmitInstrAB('CMP', 'SI', '0');
  EmitInstrA('JE', LblDone);

  (* Appeler pred(car(current)) *)
  EmitInstrAB('MOV', 'AX', 'WORD PTR [SI]');
  EmitInstrA('PUSH', 'AX');
  EmitRaw('        CALL    WORD PTR [_CL_HFTMP1]');
  EmitInstrAB('ADD', 'SP', '2');

  (* Si resultat != 0 (true), sauter (remove = inverse de filter) *)
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JNE', LblSkip);

  (* Cons l element original sur la liste accumulee *)
  EmitInstrAB('MOV', 'SI', 'WORD PTR [_CL_HFTMP2]');
  EmitInstrAB('MOV', 'AX', 'WORD PTR [SI]');
  EmitInstrAB('MOV', 'BX', 'WORD PTR [_CL_HFTMP3]');
  EmitInstrA('CALL', CL_RT_PFX + 'CONS');
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP3]', 'AX');

  EmitLabel(LblSkip);
  (* Avancer au cdr *)
  EmitInstrAB('MOV', 'SI', 'WORD PTR [_CL_HFTMP2]');
  EmitInstrAB('MOV', 'SI', 'WORD PTR [SI+2]');
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP2]', 'SI');
  EmitInstrA('JMP', LblLoop);

  EmitLabel(LblDone);
  (* Renverser la liste accumulee *)
  EmitInstrAB('MOV', 'AX', 'WORD PTR [_CL_HFTMP3]');
  EmitInstrA('CALL', CL_RT_PFX + 'LREV');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_LIST;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseSomeForm : (some pred coll) --------------------------- *)
(* Retourne la premiere valeur (pred elem) non nil/false, ou nil.    *)
Procedure ParseSomeForm(Var Res : TExprVal);
Var ArgRes  : TExprVal;
    LblLoop : TString;
    LblDone : TString;
    LblNil  : TString;
Begin
  ExprMakeNone(Res);
  EmitComment('(some pred coll)');

  (* Evaluer pred *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP1]', 'AX');

  (* Evaluer coll *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP2]', 'AX');

  LblLoop := LabelGen;
  LblDone := LabelGen;
  LblNil  := LabelGen;

  EmitLabel(LblLoop);
  EmitInstrAB('MOV', 'SI', 'WORD PTR [_CL_HFTMP2]');
  EmitInstrAB('CMP', 'SI', '0');
  EmitInstrA('JE', LblNil);

  (* Appeler pred(car(current)) *)
  EmitInstrAB('MOV', 'AX', 'WORD PTR [SI]');
  EmitInstrA('PUSH', 'AX');
  EmitRaw('        CALL    WORD PTR [_CL_HFTMP1]');
  EmitInstrAB('ADD', 'SP', '2');

  (* Si resultat != 0 -> retourner ce resultat *)
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JNE', LblDone);

  (* Avancer au cdr *)
  EmitInstrAB('MOV', 'SI', 'WORD PTR [_CL_HFTMP2]');
  EmitInstrAB('MOV', 'SI', 'WORD PTR [SI+2]');
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP2]', 'SI');
  EmitInstrA('JMP', LblLoop);

  EmitLabel(LblNil);
  EmitInstrAB('XOR', 'AX', 'AX');

  EmitLabel(LblDone);

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_UNKNOWN;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseEveryForm : (every? pred coll) ------------------------ *)
(* Retourne true si (pred elem) est vrai pour tous les elements,     *)
(* false des qu un element ne satisfait pas le predicat.              *)
Procedure ParseEveryForm(Var Res : TExprVal);
Var ArgRes   : TExprVal;
    LblLoop  : TString;
    LblTrue  : TString;
    LblFalse : TString;
    LblEnd   : TString;
Begin
  ExprMakeNone(Res);
  EmitComment('(every? pred coll)');

  (* Evaluer pred *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP1]', 'AX');

  (* Evaluer coll *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP2]', 'AX');

  LblLoop  := LabelGen;
  LblTrue  := LabelGen;
  LblFalse := LabelGen;
  LblEnd   := LabelGen;

  EmitLabel(LblLoop);
  EmitInstrAB('MOV', 'SI', 'WORD PTR [_CL_HFTMP2]');
  EmitInstrAB('CMP', 'SI', '0');
  EmitInstrA('JE', LblTrue);

  (* Appeler pred(car(current)) *)
  EmitInstrAB('MOV', 'AX', 'WORD PTR [SI]');
  EmitInstrA('PUSH', 'AX');
  EmitRaw('        CALL    WORD PTR [_CL_HFTMP1]');
  EmitInstrAB('ADD', 'SP', '2');

  (* Si resultat = 0 -> false *)
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JE', LblFalse);

  (* Avancer au cdr *)
  EmitInstrAB('MOV', 'SI', 'WORD PTR [_CL_HFTMP2]');
  EmitInstrAB('MOV', 'SI', 'WORD PTR [SI+2]');
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP2]', 'SI');
  EmitInstrA('JMP', LblLoop);

  EmitLabel(LblFalse);
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstrA('JMP', LblEnd);

  EmitLabel(LblTrue);
  EmitInstrAB('MOV', 'AX', '1');

  EmitLabel(LblEnd);

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_BOOL;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseIntoForm : (into to from) ----------------------------- *)
(* Equivalent a (reduce conj to from).                                *)
(* Pour les listes : cons chaque element de from sur to.              *)
Procedure ParseIntoForm(Var Res : TExprVal);
Var ArgRes  : TExprVal;
    LblLoop : TString;
    LblDone : TString;
Begin
  ExprMakeNone(Res);
  EmitComment('(into to from)');

  (* Evaluer to -> accumulateur *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP3]', 'AX');

  (* Evaluer from -> liste source *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP2]', 'AX');

  LblLoop := LabelGen;
  LblDone := LabelGen;

  EmitLabel(LblLoop);
  EmitInstrAB('MOV', 'SI', 'WORD PTR [_CL_HFTMP2]');
  EmitInstrAB('CMP', 'SI', '0');
  EmitInstrA('JE', LblDone);

  (* Conj car(current) sur l accumulateur *)
  EmitInstrAB('MOV', 'AX', 'WORD PTR [SI]');
  EmitInstrAB('MOV', 'BX', 'WORD PTR [_CL_HFTMP3]');
  EmitInstrA('CALL', CL_RT_PFX + 'CONS');
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP3]', 'AX');

  (* Avancer au cdr *)
  EmitInstrAB('MOV', 'SI', 'WORD PTR [_CL_HFTMP2]');
  EmitInstrAB('MOV', 'SI', 'WORD PTR [SI+2]');
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP2]', 'SI');
  EmitInstrA('JMP', LblLoop);

  EmitLabel(LblDone);
  EmitInstrAB('MOV', 'AX', 'WORD PTR [_CL_HFTMP3]');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_LIST;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseCompForm : (comp f g) --------------------------------- *)
(* Retourne une fonction qui applique g puis f.                       *)
(* Genere une lambda inline : (fn [x] (f (g x)))                     *)
(* Limitation : utilise des variables globales, un seul comp actif.   *)
Procedure ParseCompForm(Var Res : TExprVal);
Var ArgRes  : TExprVal;
    FnLabel : TString;
    SkipLbl : TString;
Begin
  ExprMakeNone(Res);
  EmitComment('(comp f g)');

  (* Evaluer f *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP1]', 'AX');

  (* Evaluer g *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP2]', 'AX');

  (* Generer la lambda inline *)
  FnLabel := LabelGen;
  SkipLbl := LabelGen;
  EmitInstrA('JMP', SkipLbl);

  EmitLabel(FnLabel);
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');

  (* Appeler g(x) : x = [BP+4] *)
  EmitInstrAB('MOV', 'AX', 'WORD PTR [BP+4]');
  EmitInstrA('PUSH', 'AX');
  EmitRaw('        CALL    WORD PTR [_CL_HFTMP2]');
  EmitInstrAB('ADD', 'SP', '2');

  (* Appeler f(g(x)) *)
  EmitInstrA('PUSH', 'AX');
  EmitRaw('        CALL    WORD PTR [_CL_HFTMP1]');
  EmitInstrAB('ADD', 'SP', '2');

  EmitInstrAB('MOV', 'SP', 'BP');
  EmitInstrA('POP', 'BP');
  EmitInstr('RET', '');

  EmitLabel(SkipLbl);
  EmitInstrAB('MOV', 'AX', 'OFFSET ' + FnLabel);

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_FN;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParsePartialForm : (partial f arg1 ...) -------------------- *)
(* Application partielle. Retourne une fonction qui appelle f         *)
(* avec les arguments stockes + un argument supplementaire.           *)
(* Supporte 1 ou 2 arguments partiels.                                *)
(* Limitation : utilise des variables globales, un seul partial actif. *)
Procedure ParsePartialForm(Var Res : TExprVal);
Var ArgRes   : TExprVal;
    FnLabel  : TString;
    SkipLbl  : TString;
    HasArg2  : Boolean;
Begin
  ExprMakeNone(Res);
  EmitComment('(partial f args...)');

  (* Evaluer f *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP1]', 'AX');

  (* Evaluer premier argument partiel *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP2]', 'AX');

  (* Verifier s il y a un deuxieme argument partiel *)
  HasArg2 := (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF);
  If HasArg2 Then
  Begin
    ParseForm(ArgRes);
    ExprFlushToAX(ArgRes);
    EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP3]', 'AX');
  End;

  (* Generer la lambda inline *)
  FnLabel := LabelGen;
  SkipLbl := LabelGen;
  EmitInstrA('JMP', SkipLbl);

  EmitLabel(FnLabel);
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');

  (* Appeler f(stored_args..., x) *)
  (* Empiler dans l ordre inverse : x d abord, puis arg2, puis arg1 *)
  EmitInstrAB('MOV', 'AX', 'WORD PTR [BP+4]');
  EmitInstrA('PUSH', 'AX');
  If HasArg2 Then
  Begin
    EmitInstrAB('MOV', 'AX', 'WORD PTR [_CL_HFTMP3]');
    EmitInstrA('PUSH', 'AX');
  End;
  EmitInstrAB('MOV', 'AX', 'WORD PTR [_CL_HFTMP2]');
  EmitInstrA('PUSH', 'AX');
  EmitRaw('        CALL    WORD PTR [_CL_HFTMP1]');
  If HasArg2 Then
    EmitInstrAB('ADD', 'SP', '6')
  Else
    EmitInstrAB('ADD', 'SP', '4');

  EmitInstrAB('MOV', 'SP', 'BP');
  EmitInstrA('POP', 'BP');
  EmitInstr('RET', '');

  EmitLabel(SkipLbl);
  EmitInstrAB('MOV', 'AX', 'OFFSET ' + FnLabel);

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_FN;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseConstantlyForm : (constantly x) ----------------------- *)
(* Retourne une fonction qui ignore ses arguments et retourne x.      *)
(* Limitation : utilise une variable globale, un seul constantly actif. *)
Procedure ParseConstantlyForm(Var Res : TExprVal);
Var ArgRes  : TExprVal;
    FnLabel : TString;
    SkipLbl : TString;
Begin
  ExprMakeNone(Res);
  EmitComment('(constantly x)');

  (* Evaluer x *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'WORD PTR [_CL_HFTMP1]', 'AX');

  (* Generer la lambda inline *)
  FnLabel := LabelGen;
  SkipLbl := LabelGen;
  EmitInstrA('JMP', SkipLbl);

  EmitLabel(FnLabel);
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');

  (* Retourner la valeur stockee *)
  EmitInstrAB('MOV', 'AX', 'WORD PTR [_CL_HFTMP1]');

  EmitInstrAB('MOV', 'SP', 'BP');
  EmitInstrA('POP', 'BP');
  EmitInstr('RET', '');

  EmitLabel(SkipLbl);
  EmitInstrAB('MOV', 'AX', 'OFFSET ' + FnLabel);

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_FN;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseIdentityForm : (identity x) --------------------------- *)
(* Retourne simplement x.                                             *)
Procedure ParseIdentityForm(Var Res : TExprVal);
Var ArgRes : TExprVal;
Begin
  ExprMakeNone(Res);
  EmitComment('(identity x)');

  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_UNKNOWN;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ============================================================
   TODO 23 - CHAINES DE CARACTERES (str / subs / count)
             [IMPLEMENTE]
   ============================================================ *)

(* ---- ParseSubsForm : (subs s start) / (subs s start end) ------- *)
(* Extrait une sous-chaine.                                          *)
(* (subs s start) : de start jusqu a la fin.                         *)
(* (subs s start end) : de start (inclus) a end (exclus).            *)
(* Resultat alloue dans _CL_STRBUF2, retourne AX=ptr.               *)
Procedure ParseSubsForm(Var Res : TExprVal);
Var ArgRes : TExprVal;
    HasEnd : Boolean;
Begin
  ExprMakeNone(Res);
  EmitComment('(subs s start [end])');

  (* Evaluer la chaine source *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrA('PUSH', 'AX');

  (* Evaluer start *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrA('PUSH', 'AX');

  (* Verifier s il y a un argument end *)
  HasEnd := (CurToken.Kind <> TK_RPAREN) And (CurToken.Kind <> TK_EOF);

  If HasEnd Then
  Begin
    ParseForm(ArgRes);
    ExprFlushToAX(ArgRes);
    EmitInstrAB('MOV', 'CX', 'AX');   (* CX = end *)
  End
  Else
    EmitInstrAB('MOV', 'CX', '0FFFFh');  (* sentinel : jusqu a la fin *)

  EmitInstrA('POP', 'BX');   (* BX = start *)
  EmitInstrA('POP', 'SI');   (* SI = source *)
  EmitInstrA('CALL', CL_RT_PFX + 'SUBS');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_STR;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseUpperCaseForm : (clojure.string/upper-case s) --------- *)
(* Convertit la chaine en majuscules. Resultat dans _CL_STRBUF2.     *)
Procedure ParseUpperCaseForm(Var Res : TExprVal);
Var ArgRes : TExprVal;
Begin
  ExprMakeNone(Res);
  EmitComment('(clojure.string/upper-case s)');

  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstrA('CALL', CL_RT_PFX + 'STRUPPER');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_STR;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseLowerCaseForm : (clojure.string/lower-case s) --------- *)
(* Convertit la chaine en minuscules. Resultat dans _CL_STRBUF2.     *)
Procedure ParseLowerCaseForm(Var Res : TExprVal);
Var ArgRes : TExprVal;
Begin
  ExprMakeNone(Res);
  EmitComment('(clojure.string/lower-case s)');

  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstrA('CALL', CL_RT_PFX + 'STRLOWER');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_STR;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseTrimForm : (clojure.string/trim s) -------------------- *)
(* Supprime les espaces en debut et fin de chaine.                    *)
Procedure ParseTrimForm(Var Res : TExprVal);
Var ArgRes : TExprVal;
Begin
  ExprMakeNone(Res);
  EmitComment('(clojure.string/trim s)');

  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstrA('CALL', CL_RT_PFX + 'STRTRIM');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_STR;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseIncludesForm : (clojure.string/includes? s sub) ------- *)
(* Retourne true si sub est trouvee dans s, false sinon.              *)
Procedure ParseIncludesForm(Var Res : TExprVal);
Var ArgRes : TExprVal;
Begin
  ExprMakeNone(Res);
  EmitComment('(clojure.string/includes? s sub)');

  (* Evaluer la chaine source *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrA('PUSH', 'AX');

  (* Evaluer la sous-chaine *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'DI', 'AX');

  EmitInstrA('POP', 'SI');   (* SI = chaine source *)
  EmitInstrA('CALL', CL_RT_PFX + 'STRFIND');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_BOOL;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseStrReplaceForm : (clojure.string/replace s match repl) *)
(* Remplace toutes les occurrences de match par repl dans s.         *)
Procedure ParseStrReplaceForm(Var Res : TExprVal);
Var ArgRes : TExprVal;
Begin
  ExprMakeNone(Res);
  EmitComment('(clojure.string/replace s match repl)');

  (* Evaluer la chaine source *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrA('PUSH', 'AX');

  (* Evaluer match *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrA('PUSH', 'AX');

  (* Evaluer repl *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'WORD PTR [_CL_SCTMP3]', 'AX');  (* repl *)

  EmitInstrA('POP', 'DI');   (* DI = match *)
  EmitInstrA('POP', 'SI');   (* SI = source *)
  EmitInstrA('CALL', CL_RT_PFX + 'STRREPL');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_STR;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseSplitForm : (clojure.string/split s delim) ------------ *)
(* Split simplifie : delimiteur est le premier caractere de la        *)
(* chaine delim. Retourne une liste de sous-chaines.                  *)
Procedure ParseSplitForm(Var Res : TExprVal);
Var ArgRes : TExprVal;
Begin
  ExprMakeNone(Res);
  EmitComment('(clojure.string/split s delim)');

  (* Evaluer la chaine source *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrA('PUSH', 'AX');

  (* Evaluer le delimiteur *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  (* Premier caractere du delimiteur ou caractere directement *)
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstrAB('XOR', 'BX', 'BX');
  EmitInstrAB('MOV', 'BL', 'BYTE PTR [SI]');

  EmitInstrA('POP', 'SI');   (* SI = source *)
  EmitInstrA('CALL', CL_RT_PFX + 'STRSPLIT');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_LIST;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ParseJoinForm : (clojure.string/join sep coll) ------------- *)
(* Concatene les elements de coll separes par sep.                    *)
Procedure ParseJoinForm(Var Res : TExprVal);
Var ArgRes : TExprVal;
Begin
  ExprMakeNone(Res);
  EmitComment('(clojure.string/join sep coll)');

  (* Evaluer le separateur *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrA('PUSH', 'AX');

  (* Evaluer la collection *)
  ParseForm(ArgRes);
  ExprFlushToAX(ArgRes);
  EmitInstrAB('MOV', 'BX', 'AX');  (* BX = liste *)

  EmitInstrA('POP', 'SI');   (* SI = separateur *)
  EmitInstrA('CALL', CL_RT_PFX + 'STRJOIN');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_STR;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

Procedure EmitRuntime;
Begin
  (* TODO 24 - runtime minimal pour E/S *)
  If RuntimeEmitted Then Exit;
  RuntimeEmitted := True;
  EmitBlankLine;
  EmitComment('=== RUNTIME CLOJURE ===');
  EmitBlankLine;

  (* --- _CLRT_PRINTSTR : afficher chaine ASCIIZ via STDOUT --- *)
  (* Entree : SI = pointeur chaine null-terminee                *)
  EmitRaw(CL_RT_PFX + 'PRINTSTR:');
  EmitRaw('        PUSH    AX');
  EmitRaw('        PUSH    BX');
  EmitRaw('        PUSH    CX');
  EmitRaw('        PUSH    DX');
  EmitRaw('        PUSH    SI');
  EmitRaw('        MOV     DX, SI');
  EmitRaw('        XOR     CX, CX');
  EmitRaw(CL_RT_PFX + 'PS_LN:');
  EmitRaw('        CMP     BYTE PTR [SI], 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'PS_DN');
  EmitRaw('        INC     SI');
  EmitRaw('        INC     CX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'PS_LN');
  EmitRaw(CL_RT_PFX + 'PS_DN:');
  EmitRaw('        TEST    CX, CX');
  EmitRaw('        JZ      ' + CL_RT_PFX + 'PS_EX');
  EmitRaw('        MOV     BX, 1');
  EmitRaw('        MOV     AH, 40h');
  EmitRaw('        INT     21h');
  EmitRaw(CL_RT_PFX + 'PS_EX:');
  EmitRaw('        POP     SI');
  EmitRaw('        POP     DX');
  EmitRaw('        POP     CX');
  EmitRaw('        POP     BX');
  EmitRaw('        POP     AX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- _CLRT_WRITECRLF : ecrire CR+LF via STDOUT --- *)
  EmitRaw(CL_RT_PFX + 'WRITECRLF:');
  EmitRaw('        PUSH    AX');
  EmitRaw('        PUSH    BX');
  EmitRaw('        PUSH    CX');
  EmitRaw('        PUSH    DX');
  EmitRaw('        MOV     DX, OFFSET _CL_CRLF');
  EmitRaw('        MOV     CX, 2');
  EmitRaw('        MOV     BX, 1');
  EmitRaw('        MOV     AH, 40h');
  EmitRaw('        INT     21h');
  EmitRaw('        POP     DX');
  EmitRaw('        POP     CX');
  EmitRaw('        POP     BX');
  EmitRaw('        POP     AX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- _CLRT_PRINTSPACE : ecrire un espace --- *)
  EmitRaw(CL_RT_PFX + 'PRINTSPACE:');
  EmitRaw('        PUSH    AX');
  EmitRaw('        PUSH    DX');
  EmitRaw('        MOV     DL, 32');
  EmitRaw('        MOV     AH, 02h');
  EmitRaw('        INT     21h');
  EmitRaw('        POP     DX');
  EmitRaw('        POP     AX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- _CLRT_NUMTOSTR : entier signe -> ASCII ASCIIZ --- *)
  (* Entree : AX = entier, DI = buffer destination          *)
  (* Sortie : buffer rempli, null-termine                   *)
  EmitRaw(CL_RT_PFX + 'NUMTOSTR:');
  EmitRaw('        PUSH    BX');
  EmitRaw('        PUSH    CX');
  EmitRaw('        PUSH    DX');
  EmitRaw('        PUSH    SI');
  EmitRaw('        PUSH    DI');
  EmitRaw('        TEST    AX, AX');
  EmitRaw('        JGE     ' + CL_RT_PFX + 'NT_POS');
  EmitRaw('        NEG     AX');
  EmitRaw('        MOV     BYTE PTR [DI], ''-''');
  EmitRaw('        INC     DI');
  EmitRaw(CL_RT_PFX + 'NT_POS:');
  EmitRaw('        MOV     SI, DI');
  EmitRaw('        MOV     BX, 10');
  EmitRaw('        XOR     CX, CX');
  EmitRaw(CL_RT_PFX + 'NT_DL:');
  EmitRaw('        XOR     DX, DX');
  EmitRaw('        DIV     BX');
  EmitRaw('        ADD     DL, 48');
  EmitRaw('        PUSH    DX');
  EmitRaw('        INC     CX');
  EmitRaw('        TEST    AX, AX');
  EmitRaw('        JNZ     ' + CL_RT_PFX + 'NT_DL');
  EmitRaw(CL_RT_PFX + 'NT_RL:');
  EmitRaw('        POP     DX');
  EmitRaw('        MOV     [SI], DL');
  EmitRaw('        INC     SI');
  EmitRaw('        LOOP    ' + CL_RT_PFX + 'NT_RL');
  EmitRaw('        MOV     BYTE PTR [SI], 0');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     SI');
  EmitRaw('        POP     DX');
  EmitRaw('        POP     CX');
  EmitRaw('        POP     BX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- _CLRT_PRINTBOOL : AX = 0|1 -> afficher 'false'|'true' --- *)
  EmitRaw(CL_RT_PFX + 'PRINTBOOL:');
  EmitRaw('        PUSH    SI');
  EmitRaw('        TEST    AX, AX');
  EmitRaw('        JZ      ' + CL_RT_PFX + 'PB_F');
  EmitRaw('        MOV     SI, OFFSET ' + CL_TRUE_LBL);
  EmitRaw('        JMP     ' + CL_RT_PFX + 'PB_P');
  EmitRaw(CL_RT_PFX + 'PB_F:');
  EmitRaw('        MOV     SI, OFFSET ' + CL_FALSE_LBL);
  EmitRaw(CL_RT_PFX + 'PB_P:');
  EmitRaw('        CALL    ' + CL_RT_PFX + 'PRINTSTR');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- _CLRT_BOOLTOSTR : AX=0|1 -> AX=ptr 'false'|'true' --- *)
  EmitRaw(CL_RT_PFX + 'BOOLTOSTR:');
  EmitRaw('        TEST    AX, AX');
  EmitRaw('        JZ      ' + CL_RT_PFX + 'BTS_F');
  EmitRaw('        MOV     AX, OFFSET ' + CL_TRUE_LBL);
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'BTS_F:');
  EmitRaw('        MOV     AX, OFFSET ' + CL_FALSE_LBL);
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- _CLRT_STRLEN : SI=chaine ASCIIZ -> AX=longueur --- *)
  EmitRaw(CL_RT_PFX + 'STRLEN:');
  EmitRaw('        PUSH    SI');
  EmitRaw('        XOR     AX, AX');
  EmitRaw(CL_RT_PFX + 'SL_LP:');
  EmitRaw('        CMP     BYTE PTR [SI], 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SL_DN');
  EmitRaw('        INC     SI');
  EmitRaw('        INC     AX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SL_LP');
  EmitRaw(CL_RT_PFX + 'SL_DN:');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- _CLRT_CONCAT : concatener SI apres DI (ASCIIZ) --- *)
  (* DI = destination (chaine ASCIIZ existante)              *)
  (* SI = source a ajouter (chaine ASCIIZ)                   *)
  EmitRaw(CL_RT_PFX + 'CONCAT:');
  EmitRaw('        PUSH    AX');
  EmitRaw('        PUSH    DI');
  EmitRaw('        PUSH    SI');
  (* Avancer DI jusqu a la fin de la chaine destination *)
  EmitRaw(CL_RT_PFX + 'CC_SK:');
  EmitRaw('        CMP     BYTE PTR [DI], 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'CC_CP');
  EmitRaw('        INC     DI');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'CC_SK');
  (* Copier SI dans DI *)
  EmitRaw(CL_RT_PFX + 'CC_CP:');
  EmitRaw('        MOV     AL, [SI]');
  EmitRaw('        MOV     [DI], AL');
  EmitRaw('        TEST    AL, AL');
  EmitRaw('        JZ      ' + CL_RT_PFX + 'CC_DN');
  EmitRaw('        INC     SI');
  EmitRaw('        INC     DI');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'CC_CP');
  EmitRaw(CL_RT_PFX + 'CC_DN:');
  EmitRaw('        POP     SI');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     AX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- _CLRT_STRCMP : comparer SI et DI (ASCIIZ) --- *)
  (* Resultat dans AX : <0, 0, >0                      *)
  EmitRaw(CL_RT_PFX + 'STRCMP:');
  EmitRaw('        PUSH    SI');
  EmitRaw('        PUSH    DI');
  EmitRaw(CL_RT_PFX + 'SC_LP:');
  EmitRaw('        MOV     AL, [SI]');
  EmitRaw('        MOV     AH, [DI]');
  EmitRaw('        CMP     AL, AH');
  EmitRaw('        JNE     ' + CL_RT_PFX + 'SC_NE');
  EmitRaw('        TEST    AL, AL');
  EmitRaw('        JZ      ' + CL_RT_PFX + 'SC_EQ');
  EmitRaw('        INC     SI');
  EmitRaw('        INC     DI');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SC_LP');
  EmitRaw(CL_RT_PFX + 'SC_EQ:');
  EmitRaw('        XOR     AX, AX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SC_DN');
  EmitRaw(CL_RT_PFX + 'SC_NE:');
  EmitRaw('        XOR     AH, AH');
  EmitRaw('        MOV     BL, [DI]');
  EmitRaw('        XOR     BH, BH');
  EmitRaw('        SUB     AX, BX');
  EmitRaw(CL_RT_PFX + 'SC_DN:');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- _CLRT_READLINE : lire une ligne depuis STDIN --- *)
  (* Utilise INT 21h AH=0Ah (lecture bufferisee)          *)
  (* Retourne AX = pointeur vers chaine null-terminee     *)
  EmitRaw(CL_RT_PFX + 'READLINE:');
  EmitRaw('        PUSH    BX');
  EmitRaw('        PUSH    CX');
  EmitRaw('        PUSH    DX');
  EmitRaw('        PUSH    SI');
  EmitRaw('        MOV     DX, OFFSET _CL_INBUF');
  EmitRaw('        MOV     SI, DX');
  EmitRaw('        MOV     BYTE PTR [SI], 126');
  EmitRaw('        MOV     AH, 0Ah');
  EmitRaw('        INT     21h');
  (* Longueur reelle en [SI+1], chaine commence a [SI+2] *)
  EmitRaw('        XOR     CH, CH');
  EmitRaw('        MOV     CL, [SI+1]');
  EmitRaw('        LEA     AX, [SI+2]');
  EmitRaw('        ADD     SI, 2');
  EmitRaw('        ADD     SI, CX');
  EmitRaw('        MOV     BYTE PTR [SI], 0');
  EmitRaw('        LEA     AX, [DX+2]');
  EmitRaw('        POP     SI');
  EmitRaw('        POP     DX');
  EmitRaw('        POP     CX');
  EmitRaw('        POP     BX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 17 : _CLRT_CONS : allouer cellule cons sur le heap --- *)
  (* Entree : AX = car (valeur), BX = cdr (liste/nil)               *)
  (* Sortie : AX = pointeur vers la nouvelle cellule cons            *)
  (* Cellule = 2 Words : [car, cdr] = 4 octets                      *)
  EmitRaw(CL_RT_PFX + 'CONS:');
  EmitRaw('        PUSH    CX');
  EmitRaw('        PUSH    DI');
  EmitRaw('        MOV     DI, WORD PTR [_CL_HEAPTOP]');
  EmitRaw('        MOV     CX, OFFSET _CL_HEAP');
  EmitRaw('        ADD     CX, DI');
  EmitRaw('        MOV     WORD PTR [CX], AX');
  EmitRaw('        MOV     WORD PTR [CX+2], BX');
  EmitRaw('        MOV     AX, CX');
  EmitRaw('        ADD     DI, 4');
  EmitRaw('        MOV     WORD PTR [_CL_HEAPTOP], DI');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     CX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 17 : _CLRT_LCOUNT : compter les elements d une liste --- *)
  (* Entree : AX = pointeur liste (ou 0 pour nil)                      *)
  (* Sortie : AX = nombre d elements                                    *)
  EmitRaw(CL_RT_PFX + 'LCOUNT:');
  EmitRaw('        PUSH    BX');
  EmitRaw('        XOR     BX, BX');
  EmitRaw(CL_RT_PFX + 'LC_LP:');
  EmitRaw('        CMP     AX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'LC_DN');
  EmitRaw('        INC     BX');
  EmitRaw('        PUSH    SI');
  EmitRaw('        MOV     SI, AX');
  EmitRaw('        MOV     AX, WORD PTR [SI+2]');
  EmitRaw('        POP     SI');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'LC_LP');
  EmitRaw(CL_RT_PFX + 'LC_DN:');
  EmitRaw('        MOV     AX, BX');
  EmitRaw('        POP     BX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 17 : _CLRT_LNTH : obtenir le N-ieme element --- *)
  (* Entree : AX = pointeur liste, BX = index (0-base)        *)
  (* Sortie : AX = element (car) ou 0 si hors bornes          *)
  EmitRaw(CL_RT_PFX + 'LNTH:');
  EmitRaw('        PUSH    CX');
  EmitRaw('        PUSH    SI');
  EmitRaw('        MOV     CX, BX');
  EmitRaw(CL_RT_PFX + 'LN_LP:');
  EmitRaw('        CMP     AX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'LN_NL');
  EmitRaw('        CMP     CX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'LN_OK');
  EmitRaw('        DEC     CX');
  EmitRaw('        MOV     SI, AX');
  EmitRaw('        MOV     AX, WORD PTR [SI+2]');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'LN_LP');
  EmitRaw(CL_RT_PFX + 'LN_OK:');
  EmitRaw('        MOV     SI, AX');
  EmitRaw('        MOV     AX, WORD PTR [SI]');
  EmitRaw('        POP     SI');
  EmitRaw('        POP     CX');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'LN_NL:');
  EmitRaw('        XOR     AX, AX');
  EmitRaw('        POP     SI');
  EmitRaw('        POP     CX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 18 : _CLRT_VECNTH : acces indexe dans un vecteur --- *)
  (* Entree : AX = pointeur vecteur, BX = index (0-base)           *)
  (* Sortie : AX = element ou 0 (nil) si hors bornes               *)
  (* Layout vecteur : [count, e0, e1, ..., e_{count-1}]            *)
  EmitRaw(CL_RT_PFX + 'VECNTH:');
  EmitRaw('        CMP     AX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'VN_NL');
  EmitRaw('        PUSH    SI');
  EmitRaw('        MOV     SI, AX');
  EmitRaw('        CMP     BX, WORD PTR [SI]');
  EmitRaw('        JAE     ' + CL_RT_PFX + 'VN_OB');
  EmitRaw('        SHL     BX, 1');
  EmitRaw('        ADD     BX, 2');
  EmitRaw('        ADD     SI, BX');
  EmitRaw('        MOV     AX, WORD PTR [SI]');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'VN_OB:');
  EmitRaw('        XOR     AX, AX');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'VN_NL:');
  EmitRaw('        XOR     AX, AX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 18 : _CLRT_VECCONJ : ajouter un element en fin --- *)
  (* Entree : AX = pointeur vecteur, BX = nouvel element          *)
  (* Sortie : AX = pointeur nouveau vecteur (copie + ajout)       *)
  EmitRaw(CL_RT_PFX + 'VECCONJ:');
  EmitRaw('        PUSH    CX');
  EmitRaw('        PUSH    SI');
  EmitRaw('        PUSH    DI');
  EmitRaw('        PUSH    BX');
  EmitRaw('        MOV     SI, AX');
  EmitRaw('        MOV     CX, WORD PTR [SI]');
  EmitRaw('        MOV     DI, WORD PTR [_CL_HEAPTOP]');
  EmitRaw('        MOV     BX, DI');
  EmitRaw('        ADD     BX, OFFSET _CL_HEAP');
  EmitRaw('        MOV     AX, CX');
  EmitRaw('        INC     AX');
  EmitRaw('        MOV     WORD PTR [BX], AX');
  EmitRaw('        INC     AX');
  EmitRaw('        SHL     AX, 1');
  EmitRaw('        ADD     DI, AX');
  EmitRaw('        MOV     WORD PTR [_CL_HEAPTOP], DI');
  EmitRaw('        ADD     SI, 2');
  EmitRaw('        MOV     DI, BX');
  EmitRaw('        ADD     DI, 2');
  EmitRaw(CL_RT_PFX + 'VC_LP:');
  EmitRaw('        CMP     CX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'VC_DN');
  EmitRaw('        MOV     AX, WORD PTR [SI]');
  EmitRaw('        MOV     WORD PTR [DI], AX');
  EmitRaw('        ADD     SI, 2');
  EmitRaw('        ADD     DI, 2');
  EmitRaw('        DEC     CX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'VC_LP');
  EmitRaw(CL_RT_PFX + 'VC_DN:');
  EmitRaw('        POP     AX');
  EmitRaw('        MOV     WORD PTR [DI], AX');
  EmitRaw('        MOV     AX, BX');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     SI');
  EmitRaw('        POP     CX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 18 : _CLRT_VECASSOC : copie avec remplacement --- *)
  (* Entree : AX = vecteur, BX = index, CX = nouvelle valeur    *)
  (* Sortie : AX = nouveau vecteur (copie avec element remplace) *)
  (* Utilise _CL_VTMP1 (index) et _CL_VTMP2 (valeur) comme tmp *)
  EmitRaw(CL_RT_PFX + 'VECASSOC:');
  EmitRaw('        PUSH    SI');
  EmitRaw('        PUSH    DI');
  EmitRaw('        PUSH    DX');
  EmitRaw('        MOV     WORD PTR [_CL_VTMP1], BX');
  EmitRaw('        MOV     WORD PTR [_CL_VTMP2], CX');
  EmitRaw('        MOV     SI, AX');
  EmitRaw('        MOV     CX, WORD PTR [SI]');
  EmitRaw('        MOV     DI, WORD PTR [_CL_HEAPTOP]');
  EmitRaw('        MOV     BX, DI');
  EmitRaw('        ADD     BX, OFFSET _CL_HEAP');
  EmitRaw('        MOV     WORD PTR [BX], CX');
  EmitRaw('        MOV     AX, CX');
  EmitRaw('        INC     AX');
  EmitRaw('        SHL     AX, 1');
  EmitRaw('        ADD     DI, AX');
  EmitRaw('        MOV     WORD PTR [_CL_HEAPTOP], DI');
  EmitRaw('        ADD     SI, 2');
  EmitRaw('        MOV     DI, BX');
  EmitRaw('        ADD     DI, 2');
  EmitRaw('        XOR     DX, DX');
  EmitRaw(CL_RT_PFX + 'VA_LP:');
  EmitRaw('        CMP     DX, CX');
  EmitRaw('        JAE     ' + CL_RT_PFX + 'VA_DN');
  EmitRaw('        CMP     DX, WORD PTR [_CL_VTMP1]');
  EmitRaw('        JE      ' + CL_RT_PFX + 'VA_RP');
  EmitRaw('        MOV     AX, WORD PTR [SI]');
  EmitRaw('        MOV     WORD PTR [DI], AX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'VA_NX');
  EmitRaw(CL_RT_PFX + 'VA_RP:');
  EmitRaw('        MOV     AX, WORD PTR [_CL_VTMP2]');
  EmitRaw('        MOV     WORD PTR [DI], AX');
  EmitRaw(CL_RT_PFX + 'VA_NX:');
  EmitRaw('        ADD     SI, 2');
  EmitRaw('        ADD     DI, 2');
  EmitRaw('        INC     DX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'VA_LP');
  EmitRaw(CL_RT_PFX + 'VA_DN:');
  EmitRaw('        MOV     AX, BX');
  EmitRaw('        POP     DX');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 18 : _CLRT_SUBVEC : sous-vecteur ------------------- *)
  (* Entree : AX = vecteur, BX = start (inclus), CX = end (exclus) *)
  (* Sortie : AX = nouveau sous-vecteur                             *)
  EmitRaw(CL_RT_PFX + 'SUBVEC:');
  EmitRaw('        PUSH    SI');
  EmitRaw('        PUSH    DI');
  EmitRaw('        PUSH    DX');
  EmitRaw('        MOV     SI, AX');
  EmitRaw('        MOV     DX, CX');
  EmitRaw('        SUB     DX, BX');
  EmitRaw('        MOV     DI, WORD PTR [_CL_HEAPTOP]');
  EmitRaw('        PUSH    BX');
  EmitRaw('        MOV     BX, DI');
  EmitRaw('        ADD     BX, OFFSET _CL_HEAP');
  EmitRaw('        MOV     WORD PTR [BX], DX');
  EmitRaw('        MOV     AX, DX');
  EmitRaw('        INC     AX');
  EmitRaw('        SHL     AX, 1');
  EmitRaw('        ADD     DI, AX');
  EmitRaw('        MOV     WORD PTR [_CL_HEAPTOP], DI');
  EmitRaw('        POP     AX');
  EmitRaw('        SHL     AX, 1');
  EmitRaw('        ADD     AX, 2');
  EmitRaw('        ADD     SI, AX');
  EmitRaw('        MOV     DI, BX');
  EmitRaw('        ADD     DI, 2');
  EmitRaw('        MOV     CX, DX');
  EmitRaw(CL_RT_PFX + 'SV_LP:');
  EmitRaw('        CMP     CX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SV_DN');
  EmitRaw('        MOV     AX, WORD PTR [SI]');
  EmitRaw('        MOV     WORD PTR [DI], AX');
  EmitRaw('        ADD     SI, 2');
  EmitRaw('        ADD     DI, 2');
  EmitRaw('        DEC     CX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SV_LP');
  EmitRaw(CL_RT_PFX + 'SV_DN:');
  EmitRaw('        MOV     AX, BX');
  EmitRaw('        POP     DX');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 19 : _CLRT_MAPGET : recherche de cle dans une map --- *)
  (* Entree : AX = pointeur map, BX = cle a chercher               *)
  (* Sortie : AX = valeur associee ou 0 (nil) si absente            *)
  (* Layout map : [count_pairs, k0, v0, k1, v1, ...]               *)
  EmitRaw(CL_RT_PFX + 'MAPGET:');
  EmitRaw('        CMP     AX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'MG_NL');
  EmitRaw('        PUSH    SI');
  EmitRaw('        PUSH    CX');
  EmitRaw('        MOV     SI, AX');
  EmitRaw('        MOV     CX, WORD PTR [SI]');
  EmitRaw('        ADD     SI, 2');
  EmitRaw(CL_RT_PFX + 'MG_LP:');
  EmitRaw('        CMP     CX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'MG_NF');
  EmitRaw('        CMP     WORD PTR [SI], BX');
  EmitRaw('        JE      ' + CL_RT_PFX + 'MG_FN');
  EmitRaw('        ADD     SI, 4');
  EmitRaw('        DEC     CX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'MG_LP');
  EmitRaw(CL_RT_PFX + 'MG_FN:');
  EmitRaw('        MOV     AX, WORD PTR [SI+2]');
  EmitRaw('        POP     CX');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'MG_NF:');
  EmitRaw('        XOR     AX, AX');
  EmitRaw('        POP     CX');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'MG_NL:');
  EmitRaw('        XOR     AX, AX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 19 : _CLRT_MAPASSOC : copie map + ajout/remplacement --- *)
  (* Entree : AX = map, BX = cle, CX = valeur                         *)
  (* Sortie : AX = nouvelle map                                        *)
  (* Si la cle existe, remplacer sa valeur. Sinon, ajouter la paire.   *)
  (* Utilise _CL_MTMP1 (cle) et _CL_MTMP2 (valeur) comme temporaires  *)
  EmitRaw(CL_RT_PFX + 'MAPASSOC:');
  EmitRaw('        MOV     WORD PTR [_CL_MTMP1], BX');
  EmitRaw('        MOV     WORD PTR [_CL_MTMP2], CX');
  EmitRaw('        PUSH    SI');
  EmitRaw('        PUSH    DI');
  EmitRaw('        PUSH    DX');
  EmitRaw('        CMP     AX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'MA_NW');
  EmitRaw('        MOV     SI, AX');
  EmitRaw('        MOV     CX, WORD PTR [SI]');
  (* Chercher si la cle existe *)
  EmitRaw('        PUSH    CX');
  EmitRaw('        PUSH    SI');
  EmitRaw('        ADD     SI, 2');
  EmitRaw('        MOV     BX, WORD PTR [_CL_MTMP1]');
  EmitRaw(CL_RT_PFX + 'MA_SK:');
  EmitRaw('        CMP     CX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'MA_AD');
  EmitRaw('        CMP     WORD PTR [SI], BX');
  EmitRaw('        JE      ' + CL_RT_PFX + 'MA_RP');
  EmitRaw('        ADD     SI, 4');
  EmitRaw('        DEC     CX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'MA_SK');
  (* Cle trouvee : copier avec remplacement, meme taille *)
  EmitRaw(CL_RT_PFX + 'MA_RP:');
  EmitRaw('        POP     SI');
  EmitRaw('        POP     CX');
  EmitRaw('        MOV     DI, WORD PTR [_CL_HEAPTOP]');
  EmitRaw('        MOV     BX, DI');
  EmitRaw('        ADD     BX, OFFSET _CL_HEAP');
  EmitRaw('        MOV     WORD PTR [BX], CX');
  EmitRaw('        MOV     AX, CX');
  EmitRaw('        SHL     AX, 1');
  EmitRaw('        SHL     AX, 1');
  EmitRaw('        ADD     AX, 2');
  EmitRaw('        ADD     DI, AX');
  EmitRaw('        MOV     WORD PTR [_CL_HEAPTOP], DI');
  EmitRaw('        ADD     SI, 2');
  EmitRaw('        MOV     DI, BX');
  EmitRaw('        ADD     DI, 2');
  EmitRaw('        MOV     DX, CX');
  EmitRaw(CL_RT_PFX + 'MA_CL:');
  EmitRaw('        CMP     DX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'MA_DN');
  EmitRaw('        MOV     AX, WORD PTR [SI]');
  EmitRaw('        MOV     WORD PTR [DI], AX');
  EmitRaw('        CMP     AX, WORD PTR [_CL_MTMP1]');
  EmitRaw('        JE      ' + CL_RT_PFX + 'MA_RV');
  EmitRaw('        MOV     AX, WORD PTR [SI+2]');
  EmitRaw('        MOV     WORD PTR [DI+2], AX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'MA_NX');
  EmitRaw(CL_RT_PFX + 'MA_RV:');
  EmitRaw('        MOV     AX, WORD PTR [_CL_MTMP2]');
  EmitRaw('        MOV     WORD PTR [DI+2], AX');
  EmitRaw(CL_RT_PFX + 'MA_NX:');
  EmitRaw('        ADD     SI, 4');
  EmitRaw('        ADD     DI, 4');
  EmitRaw('        DEC     DX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'MA_CL');
  EmitRaw(CL_RT_PFX + 'MA_DN:');
  EmitRaw('        MOV     AX, BX');
  EmitRaw('        POP     DX');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  (* Cle non trouvee : copier tout + ajouter nouvelle paire *)
  EmitRaw(CL_RT_PFX + 'MA_AD:');
  EmitRaw('        POP     SI');
  EmitRaw('        POP     CX');
  EmitRaw('        MOV     AX, CX');
  EmitRaw('        INC     AX');
  EmitRaw('        MOV     DI, WORD PTR [_CL_HEAPTOP]');
  EmitRaw('        MOV     BX, DI');
  EmitRaw('        ADD     BX, OFFSET _CL_HEAP');
  EmitRaw('        MOV     WORD PTR [BX], AX');
  EmitRaw('        SHL     AX, 1');
  EmitRaw('        SHL     AX, 1');
  EmitRaw('        ADD     AX, 2');
  EmitRaw('        ADD     DI, AX');
  EmitRaw('        MOV     WORD PTR [_CL_HEAPTOP], DI');
  EmitRaw('        ADD     SI, 2');
  EmitRaw('        MOV     DI, BX');
  EmitRaw('        ADD     DI, 2');
  EmitRaw('        MOV     DX, CX');
  EmitRaw(CL_RT_PFX + 'MA_C2:');
  EmitRaw('        CMP     DX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'MA_AP');
  EmitRaw('        MOV     AX, WORD PTR [SI]');
  EmitRaw('        MOV     WORD PTR [DI], AX');
  EmitRaw('        MOV     AX, WORD PTR [SI+2]');
  EmitRaw('        MOV     WORD PTR [DI+2], AX');
  EmitRaw('        ADD     SI, 4');
  EmitRaw('        ADD     DI, 4');
  EmitRaw('        DEC     DX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'MA_C2');
  EmitRaw(CL_RT_PFX + 'MA_AP:');
  EmitRaw('        MOV     AX, WORD PTR [_CL_MTMP1]');
  EmitRaw('        MOV     WORD PTR [DI], AX');
  EmitRaw('        MOV     AX, WORD PTR [_CL_MTMP2]');
  EmitRaw('        MOV     WORD PTR [DI+2], AX');
  EmitRaw('        MOV     AX, BX');
  EmitRaw('        POP     DX');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  (* Map nil : creer nouvelle map a 1 paire *)
  EmitRaw(CL_RT_PFX + 'MA_NW:');
  EmitRaw('        MOV     DI, WORD PTR [_CL_HEAPTOP]');
  EmitRaw('        MOV     BX, DI');
  EmitRaw('        ADD     BX, OFFSET _CL_HEAP');
  EmitRaw('        MOV     WORD PTR [BX], 1');
  EmitRaw('        MOV     AX, WORD PTR [_CL_MTMP1]');
  EmitRaw('        MOV     WORD PTR [BX+2], AX');
  EmitRaw('        MOV     AX, WORD PTR [_CL_MTMP2]');
  EmitRaw('        MOV     WORD PTR [BX+4], AX');
  EmitRaw('        ADD     DI, 6');
  EmitRaw('        MOV     WORD PTR [_CL_HEAPTOP], DI');
  EmitRaw('        MOV     AX, BX');
  EmitRaw('        POP     DX');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 19 : _CLRT_MAPDISSOC : copie map sans la cle donnee --- *)
  (* Entree : AX = map, BX = cle a supprimer                          *)
  (* Sortie : AX = nouvelle map (copie sans la paire correspondante)   *)
  EmitRaw(CL_RT_PFX + 'MAPDISSOC:');
  EmitRaw('        CMP     AX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'MD_NL');
  EmitRaw('        PUSH    SI');
  EmitRaw('        PUSH    DI');
  EmitRaw('        PUSH    DX');
  EmitRaw('        PUSH    CX');
  EmitRaw('        MOV     SI, AX');
  EmitRaw('        MOV     CX, WORD PTR [SI]');
  EmitRaw('        MOV     DI, WORD PTR [_CL_HEAPTOP]');
  EmitRaw('        PUSH    BX');
  EmitRaw('        MOV     BX, DI');
  EmitRaw('        ADD     BX, OFFSET _CL_HEAP');
  (* Compter les paires a copier (exclure la cle) *)
  EmitRaw('        MOV     DX, CX');
  EmitRaw('        DEC     DX');
  EmitRaw('        CMP     DX, 0');
  EmitRaw('        JL      ' + CL_RT_PFX + 'MD_E0');
  EmitRaw('        MOV     WORD PTR [BX], DX');
  (* Allouer : (new_count*2+1) words *)
  EmitRaw('        MOV     AX, DX');
  EmitRaw('        SHL     AX, 1');
  EmitRaw('        SHL     AX, 1');
  EmitRaw('        ADD     AX, 2');
  EmitRaw('        ADD     DI, AX');
  EmitRaw('        MOV     WORD PTR [_CL_HEAPTOP], DI');
  EmitRaw('        ADD     SI, 2');
  EmitRaw('        MOV     DI, BX');
  EmitRaw('        ADD     DI, 2');
  EmitRaw('        POP     AX');
  EmitRaw(CL_RT_PFX + 'MD_LP:');
  EmitRaw('        CMP     CX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'MD_DN');
  EmitRaw('        CMP     WORD PTR [SI], AX');
  EmitRaw('        JE      ' + CL_RT_PFX + 'MD_SP');
  EmitRaw('        PUSH    AX');
  EmitRaw('        MOV     AX, WORD PTR [SI]');
  EmitRaw('        MOV     WORD PTR [DI], AX');
  EmitRaw('        MOV     AX, WORD PTR [SI+2]');
  EmitRaw('        MOV     WORD PTR [DI+2], AX');
  EmitRaw('        POP     AX');
  EmitRaw('        ADD     DI, 4');
  EmitRaw(CL_RT_PFX + 'MD_SP:');
  EmitRaw('        ADD     SI, 4');
  EmitRaw('        DEC     CX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'MD_LP');
  EmitRaw(CL_RT_PFX + 'MD_DN:');
  EmitRaw('        MOV     AX, BX');
  EmitRaw('        POP     CX');
  EmitRaw('        POP     DX');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'MD_E0:');
  EmitRaw('        POP     BX');
  EmitRaw('        XOR     AX, AX');
  EmitRaw('        POP     CX');
  EmitRaw('        POP     DX');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'MD_NL:');
  EmitRaw('        XOR     AX, AX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 19 : _CLRT_MAPHAS : test de presence d une cle --- *)
  (* Entree : AX = map, BX = cle                                  *)
  (* Sortie : AX = 1 (true) si trouvee, 0 (false) sinon           *)
  EmitRaw(CL_RT_PFX + 'MAPHAS:');
  EmitRaw('        CMP     AX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'MH_NO');
  EmitRaw('        PUSH    SI');
  EmitRaw('        PUSH    CX');
  EmitRaw('        MOV     SI, AX');
  EmitRaw('        MOV     CX, WORD PTR [SI]');
  EmitRaw('        ADD     SI, 2');
  EmitRaw(CL_RT_PFX + 'MH_LP:');
  EmitRaw('        CMP     CX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'MH_NF');
  EmitRaw('        CMP     WORD PTR [SI], BX');
  EmitRaw('        JE      ' + CL_RT_PFX + 'MH_FN');
  EmitRaw('        ADD     SI, 4');
  EmitRaw('        DEC     CX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'MH_LP');
  EmitRaw(CL_RT_PFX + 'MH_FN:');
  EmitRaw('        MOV     AX, 1');
  EmitRaw('        POP     CX');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'MH_NF:');
  EmitRaw('        XOR     AX, AX');
  EmitRaw('        POP     CX');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'MH_NO:');
  EmitRaw('        XOR     AX, AX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 19 : _CLRT_MAPKEYS : liste des cles d une map --- *)
  (* Entree : AX = map                                            *)
  (* Sortie : AX = vecteur des cles [count, k0, k1, ...]         *)
  EmitRaw(CL_RT_PFX + 'MAPKEYS:');
  EmitRaw('        CMP     AX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'MK_NL');
  EmitRaw('        PUSH    SI');
  EmitRaw('        PUSH    DI');
  EmitRaw('        PUSH    CX');
  EmitRaw('        MOV     SI, AX');
  EmitRaw('        MOV     CX, WORD PTR [SI]');
  EmitRaw('        MOV     DI, WORD PTR [_CL_HEAPTOP]');
  EmitRaw('        MOV     BX, DI');
  EmitRaw('        ADD     BX, OFFSET _CL_HEAP');
  EmitRaw('        MOV     WORD PTR [BX], CX');
  EmitRaw('        MOV     AX, CX');
  EmitRaw('        INC     AX');
  EmitRaw('        SHL     AX, 1');
  EmitRaw('        ADD     DI, AX');
  EmitRaw('        MOV     WORD PTR [_CL_HEAPTOP], DI');
  EmitRaw('        ADD     SI, 2');
  EmitRaw('        MOV     DI, BX');
  EmitRaw('        ADD     DI, 2');
  EmitRaw(CL_RT_PFX + 'MK_LP:');
  EmitRaw('        CMP     CX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'MK_DN');
  EmitRaw('        MOV     AX, WORD PTR [SI]');
  EmitRaw('        MOV     WORD PTR [DI], AX');
  EmitRaw('        ADD     SI, 4');
  EmitRaw('        ADD     DI, 2');
  EmitRaw('        DEC     CX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'MK_LP');
  EmitRaw(CL_RT_PFX + 'MK_DN:');
  EmitRaw('        MOV     AX, BX');
  EmitRaw('        POP     CX');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'MK_NL:');
  EmitRaw('        XOR     AX, AX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 19 : _CLRT_MAPVALS : liste des valeurs d une map --- *)
  (* Entree : AX = map                                               *)
  (* Sortie : AX = vecteur des valeurs [count, v0, v1, ...]         *)
  EmitRaw(CL_RT_PFX + 'MAPVALS:');
  EmitRaw('        CMP     AX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'MV_NL');
  EmitRaw('        PUSH    SI');
  EmitRaw('        PUSH    DI');
  EmitRaw('        PUSH    CX');
  EmitRaw('        MOV     SI, AX');
  EmitRaw('        MOV     CX, WORD PTR [SI]');
  EmitRaw('        MOV     DI, WORD PTR [_CL_HEAPTOP]');
  EmitRaw('        MOV     BX, DI');
  EmitRaw('        ADD     BX, OFFSET _CL_HEAP');
  EmitRaw('        MOV     WORD PTR [BX], CX');
  EmitRaw('        MOV     AX, CX');
  EmitRaw('        INC     AX');
  EmitRaw('        SHL     AX, 1');
  EmitRaw('        ADD     DI, AX');
  EmitRaw('        MOV     WORD PTR [_CL_HEAPTOP], DI');
  EmitRaw('        ADD     SI, 2');
  EmitRaw('        MOV     DI, BX');
  EmitRaw('        ADD     DI, 2');
  EmitRaw(CL_RT_PFX + 'MV_LP:');
  EmitRaw('        CMP     CX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'MV_DN');
  EmitRaw('        MOV     AX, WORD PTR [SI+2]');
  EmitRaw('        MOV     WORD PTR [DI], AX');
  EmitRaw('        ADD     SI, 4');
  EmitRaw('        ADD     DI, 2');
  EmitRaw('        DEC     CX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'MV_LP');
  EmitRaw(CL_RT_PFX + 'MV_DN:');
  EmitRaw('        MOV     AX, BX');
  EmitRaw('        POP     CX');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'MV_NL:');
  EmitRaw('        XOR     AX, AX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 19 : _CLRT_MAPMERGE : fusionner deux maps ------------ *)
  (* Entree : AX = map1, BX = map2                                   *)
  (* Sortie : AX = nouvelle map contenant toutes les paires           *)
  (* Les cles de map2 ecrasent celles de map1.                        *)
  (* Strategie : copier map1, puis assoc chaque paire de map2.        *)
  EmitRaw(CL_RT_PFX + 'MAPMERGE:');
  EmitRaw('        CMP     AX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'MM_R2');
  EmitRaw('        CMP     BX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'MM_R1');
  EmitRaw('        PUSH    SI');
  EmitRaw('        PUSH    DI');
  EmitRaw('        PUSH    DX');
  EmitRaw('        PUSH    CX');
  (* Copier map1 entierement *)
  EmitRaw('        MOV     SI, AX');
  EmitRaw('        MOV     CX, WORD PTR [SI]');
  EmitRaw('        MOV     DI, WORD PTR [_CL_HEAPTOP]');
  EmitRaw('        MOV     AX, DI');
  EmitRaw('        ADD     AX, OFFSET _CL_HEAP');
  EmitRaw('        PUSH    AX');
  EmitRaw('        MOV     DX, CX');
  EmitRaw('        SHL     DX, 1');
  EmitRaw('        SHL     DX, 1');
  EmitRaw('        ADD     DX, 2');
  EmitRaw('        ADD     DI, DX');
  EmitRaw('        MOV     WORD PTR [_CL_HEAPTOP], DI');
  EmitRaw('        POP     DI');
  EmitRaw('        PUSH    DI');
  EmitRaw('        MOV     DX, CX');
  EmitRaw('        SHL     DX, 1');
  EmitRaw('        INC     DX');
  EmitRaw(CL_RT_PFX + 'MM_C1:');
  EmitRaw('        CMP     DX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'MM_P2');
  EmitRaw('        MOV     AX, WORD PTR [SI]');
  EmitRaw('        MOV     WORD PTR [DI], AX');
  EmitRaw('        ADD     SI, 2');
  EmitRaw('        ADD     DI, 2');
  EmitRaw('        DEC     DX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'MM_C1');
  (* Assoc chaque paire de map2 sur la copie *)
  EmitRaw(CL_RT_PFX + 'MM_P2:');
  EmitRaw('        MOV     SI, BX');
  EmitRaw('        MOV     CX, WORD PTR [SI]');
  EmitRaw('        ADD     SI, 2');
  EmitRaw(CL_RT_PFX + 'MM_LP:');
  EmitRaw('        CMP     CX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'MM_DN');
  EmitRaw('        MOV     BX, WORD PTR [SI]');
  EmitRaw('        MOV     DX, WORD PTR [SI+2]');
  EmitRaw('        POP     AX');
  EmitRaw('        PUSH    CX');
  EmitRaw('        PUSH    SI');
  EmitRaw('        MOV     CX, DX');
  EmitRaw('        CALL    ' + CL_RT_PFX + 'MAPASSOC');
  EmitRaw('        PUSH    AX');
  EmitRaw('        POP     AX');
  EmitRaw('        PUSH    AX');
  EmitRaw('        POP     SI');
  EmitRaw('        POP     CX');
  EmitRaw('        ADD     SI, 4');
  EmitRaw('        DEC     CX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'MM_LP');
  EmitRaw(CL_RT_PFX + 'MM_DN:');
  EmitRaw('        POP     AX');
  EmitRaw('        POP     CX');
  EmitRaw('        POP     DX');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'MM_R1:');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'MM_R2:');
  EmitRaw('        MOV     AX, BX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 20 : _CLRT_SETHAS : recherche lineaire dans un ensemble --- *)
  (* Entree : AX = set, BX = valeur a chercher                            *)
  (* Sortie : AX = 1 (true) si trouvee, 0 (false) sinon                   *)
  EmitRaw(CL_RT_PFX + 'SETHAS:');
  EmitRaw('        CMP     AX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SH_NO');
  EmitRaw('        PUSH    SI');
  EmitRaw('        PUSH    CX');
  EmitRaw('        MOV     SI, AX');
  EmitRaw('        MOV     CX, WORD PTR [SI]');
  EmitRaw('        ADD     SI, 2');
  EmitRaw(CL_RT_PFX + 'SH_LP:');
  EmitRaw('        CMP     CX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SH_NF');
  EmitRaw('        CMP     WORD PTR [SI], BX');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SH_FN');
  EmitRaw('        ADD     SI, 2');
  EmitRaw('        DEC     CX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SH_LP');
  EmitRaw(CL_RT_PFX + 'SH_FN:');
  EmitRaw('        MOV     AX, 1');
  EmitRaw('        POP     CX');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'SH_NF:');
  EmitRaw('        XOR     AX, AX');
  EmitRaw('        POP     CX');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'SH_NO:');
  EmitRaw('        XOR     AX, AX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 20 : _CLRT_SETCONJ : copie ensemble + ajout si absent --- *)
  (* Entree : AX = set, BX = valeur a ajouter                           *)
  (* Sortie : AX = nouveau set (copie avec element ajoute si absent)     *)
  EmitRaw(CL_RT_PFX + 'SETCONJ:');
  EmitRaw('        CMP     AX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SC_NL');
  EmitRaw('        PUSH    SI');
  EmitRaw('        PUSH    DI');
  EmitRaw('        PUSH    DX');
  EmitRaw('        PUSH    CX');
  EmitRaw('        MOV     WORD PTR [_CL_STMP1], BX');
  (* Verifier si l element existe deja *)
  EmitRaw('        MOV     SI, AX');
  EmitRaw('        MOV     CX, WORD PTR [SI]');
  EmitRaw('        PUSH    CX');
  EmitRaw('        PUSH    SI');
  EmitRaw('        ADD     SI, 2');
  EmitRaw(CL_RT_PFX + 'SC_CK:');
  EmitRaw('        CMP     CX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SC_NF');
  EmitRaw('        CMP     WORD PTR [SI], BX');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SC_EX');
  EmitRaw('        ADD     SI, 2');
  EmitRaw('        DEC     CX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SC_CK');
  (* Element existe deja : copie identique *)
  EmitRaw(CL_RT_PFX + 'SC_EX:');
  EmitRaw('        POP     SI');
  EmitRaw('        POP     CX');
  EmitRaw('        MOV     DI, WORD PTR [_CL_HEAPTOP]');
  EmitRaw('        MOV     BX, DI');
  EmitRaw('        ADD     BX, OFFSET _CL_HEAP');
  EmitRaw('        MOV     DX, CX');
  EmitRaw('        INC     DX');
  EmitRaw('        SHL     DX, 1');
  EmitRaw('        ADD     DI, DX');
  EmitRaw('        MOV     WORD PTR [_CL_HEAPTOP], DI');
  EmitRaw('        MOV     DI, BX');
  EmitRaw('        SHR     DX, 1');
  EmitRaw(CL_RT_PFX + 'SC_CP:');
  EmitRaw('        CMP     DX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SC_D2');
  EmitRaw('        MOV     AX, WORD PTR [SI]');
  EmitRaw('        MOV     WORD PTR [DI], AX');
  EmitRaw('        ADD     SI, 2');
  EmitRaw('        ADD     DI, 2');
  EmitRaw('        DEC     DX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SC_CP');
  EmitRaw(CL_RT_PFX + 'SC_D2:');
  EmitRaw('        MOV     AX, BX');
  EmitRaw('        POP     CX');
  EmitRaw('        POP     DX');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  (* Element absent : copie + ajout *)
  EmitRaw(CL_RT_PFX + 'SC_NF:');
  EmitRaw('        POP     SI');
  EmitRaw('        POP     CX');
  EmitRaw('        MOV     DI, WORD PTR [_CL_HEAPTOP]');
  EmitRaw('        MOV     BX, DI');
  EmitRaw('        ADD     BX, OFFSET _CL_HEAP');
  EmitRaw('        MOV     DX, CX');
  EmitRaw('        INC     DX');
  EmitRaw('        MOV     WORD PTR [BX], DX');
  (* Allouer (count+2) words *)
  EmitRaw('        MOV     AX, DX');
  EmitRaw('        INC     AX');
  EmitRaw('        SHL     AX, 1');
  EmitRaw('        ADD     DI, AX');
  EmitRaw('        MOV     WORD PTR [_CL_HEAPTOP], DI');
  (* Copier les anciens elements *)
  EmitRaw('        MOV     DI, BX');
  EmitRaw('        ADD     DI, 2');
  EmitRaw('        ADD     SI, 2');
  EmitRaw(CL_RT_PFX + 'SC_C2:');
  EmitRaw('        CMP     CX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SC_AD');
  EmitRaw('        MOV     AX, WORD PTR [SI]');
  EmitRaw('        MOV     WORD PTR [DI], AX');
  EmitRaw('        ADD     SI, 2');
  EmitRaw('        ADD     DI, 2');
  EmitRaw('        DEC     CX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SC_C2');
  (* Ajouter le nouvel element *)
  EmitRaw(CL_RT_PFX + 'SC_AD:');
  EmitRaw('        MOV     AX, WORD PTR [_CL_STMP1]');
  EmitRaw('        MOV     WORD PTR [DI], AX');
  EmitRaw('        MOV     AX, BX');
  EmitRaw('        POP     CX');
  EmitRaw('        POP     DX');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  (* Set nil : creer un singleton *)
  EmitRaw(CL_RT_PFX + 'SC_NL:');
  EmitRaw('        PUSH    DI');
  EmitRaw('        MOV     DI, WORD PTR [_CL_HEAPTOP]');
  EmitRaw('        MOV     AX, DI');
  EmitRaw('        ADD     AX, OFFSET _CL_HEAP');
  EmitRaw('        MOV     WORD PTR [AX], 1');
  EmitRaw('        MOV     WORD PTR [AX+2], BX');
  EmitRaw('        ADD     DI, 4');
  EmitRaw('        MOV     WORD PTR [_CL_HEAPTOP], DI');
  EmitRaw('        POP     DI');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 20 : _CLRT_SETDISJ : copie ensemble sans l element --- *)
  (* Entree : AX = set, BX = valeur a retirer                         *)
  (* Sortie : AX = nouveau set (copie sans l element)                  *)
  EmitRaw(CL_RT_PFX + 'SETDISJ:');
  EmitRaw('        CMP     AX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SD_NL');
  EmitRaw('        PUSH    SI');
  EmitRaw('        PUSH    DI');
  EmitRaw('        PUSH    DX');
  EmitRaw('        PUSH    CX');
  EmitRaw('        MOV     SI, AX');
  EmitRaw('        MOV     CX, WORD PTR [SI]');
  EmitRaw('        MOV     DI, WORD PTR [_CL_HEAPTOP]');
  EmitRaw('        PUSH    BX');
  EmitRaw('        MOV     BX, DI');
  EmitRaw('        ADD     BX, OFFSET _CL_HEAP');
  (* Compter : new_count = old_count - 1 (si element present) *)
  EmitRaw('        MOV     DX, CX');
  EmitRaw('        DEC     DX');
  EmitRaw('        CMP     DX, 0');
  EmitRaw('        JL      ' + CL_RT_PFX + 'SD_E0');
  EmitRaw('        MOV     WORD PTR [BX], DX');
  (* Allouer : (new_count+1) words *)
  EmitRaw('        MOV     AX, DX');
  EmitRaw('        INC     AX');
  EmitRaw('        SHL     AX, 1');
  EmitRaw('        ADD     DI, AX');
  EmitRaw('        MOV     WORD PTR [_CL_HEAPTOP], DI');
  EmitRaw('        ADD     SI, 2');
  EmitRaw('        MOV     DI, BX');
  EmitRaw('        ADD     DI, 2');
  EmitRaw('        POP     AX');
  EmitRaw(CL_RT_PFX + 'SD_LP:');
  EmitRaw('        CMP     CX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SD_DN');
  EmitRaw('        CMP     WORD PTR [SI], AX');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SD_SP');
  EmitRaw('        PUSH    AX');
  EmitRaw('        MOV     AX, WORD PTR [SI]');
  EmitRaw('        MOV     WORD PTR [DI], AX');
  EmitRaw('        POP     AX');
  EmitRaw('        ADD     DI, 2');
  EmitRaw(CL_RT_PFX + 'SD_SP:');
  EmitRaw('        ADD     SI, 2');
  EmitRaw('        DEC     CX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SD_LP');
  EmitRaw(CL_RT_PFX + 'SD_DN:');
  EmitRaw('        MOV     AX, BX');
  EmitRaw('        POP     CX');
  EmitRaw('        POP     DX');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'SD_E0:');
  EmitRaw('        POP     BX');
  EmitRaw('        XOR     AX, AX');
  EmitRaw('        POP     CX');
  EmitRaw('        POP     DX');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'SD_NL:');
  EmitRaw('        XOR     AX, AX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 20 : _CLRT_SETUNION : fusion de deux ensembles ---------- *)
  (* Entree : AX = set1, BX = set2                                       *)
  (* Sortie : AX = nouveau set (tous elements de s1 + ceux de s2 absents)*)
  EmitRaw(CL_RT_PFX + 'SETUNION:');
  EmitRaw('        CMP     AX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SU_R2');
  EmitRaw('        CMP     BX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SU_R1');
  EmitRaw('        PUSH    SI');
  EmitRaw('        PUSH    DI');
  EmitRaw('        PUSH    DX');
  EmitRaw('        PUSH    CX');
  EmitRaw('        MOV     WORD PTR [_CL_STMP1], AX');
  EmitRaw('        MOV     WORD PTR [_CL_STMP2], BX');
  (* Copier s1 entierement dans un nouveau set *)
  EmitRaw('        MOV     SI, AX');
  EmitRaw('        MOV     CX, WORD PTR [SI]');
  EmitRaw('        MOV     DI, WORD PTR [_CL_HEAPTOP]');
  EmitRaw('        MOV     BX, DI');
  EmitRaw('        ADD     BX, OFFSET _CL_HEAP');
  EmitRaw('        MOV     DX, CX');
  EmitRaw('        INC     DX');
  EmitRaw('        SHL     DX, 1');
  EmitRaw('        ADD     DI, DX');
  EmitRaw('        MOV     WORD PTR [_CL_HEAPTOP], DI');
  EmitRaw('        MOV     DI, BX');
  EmitRaw('        SHR     DX, 1');
  EmitRaw(CL_RT_PFX + 'SU_C1:');
  EmitRaw('        CMP     DX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SU_P2');
  EmitRaw('        MOV     AX, WORD PTR [SI]');
  EmitRaw('        MOV     WORD PTR [DI], AX');
  EmitRaw('        ADD     SI, 2');
  EmitRaw('        ADD     DI, 2');
  EmitRaw('        DEC     DX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SU_C1');
  (* Parcourir s2 et ajouter chaque element absent de la copie *)
  EmitRaw(CL_RT_PFX + 'SU_P2:');
  EmitRaw('        MOV     SI, WORD PTR [_CL_STMP2]');
  EmitRaw('        MOV     CX, WORD PTR [SI]');
  EmitRaw('        ADD     SI, 2');
  EmitRaw(CL_RT_PFX + 'SU_LP:');
  EmitRaw('        CMP     CX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SU_DN');
  EmitRaw('        MOV     DX, WORD PTR [SI]');
  (* Chercher DX dans la copie *)
  EmitRaw('        PUSH    CX');
  EmitRaw('        PUSH    SI');
  EmitRaw('        MOV     AX, BX');
  EmitRaw('        MOV     SI, BX');
  EmitRaw('        MOV     CX, WORD PTR [SI]');
  EmitRaw('        ADD     SI, 2');
  EmitRaw(CL_RT_PFX + 'SU_SR:');
  EmitRaw('        CMP     CX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SU_AB');
  EmitRaw('        CMP     WORD PTR [SI], DX');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SU_PR');
  EmitRaw('        ADD     SI, 2');
  EmitRaw('        DEC     CX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SU_SR');
  (* Element deja present : ne pas ajouter *)
  EmitRaw(CL_RT_PFX + 'SU_PR:');
  EmitRaw('        POP     SI');
  EmitRaw('        POP     CX');
  EmitRaw('        ADD     SI, 2');
  EmitRaw('        DEC     CX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SU_LP');
  (* Element absent : ajouter a la fin de la copie *)
  EmitRaw(CL_RT_PFX + 'SU_AB:');
  EmitRaw('        POP     SI');
  EmitRaw('        POP     CX');
  (* Ajouter DX en fin de set *)
  EmitRaw('        MOV     DI, WORD PTR [_CL_HEAPTOP]');
  EmitRaw('        PUSH    AX');
  EmitRaw('        MOV     AX, DI');
  EmitRaw('        ADD     AX, OFFSET _CL_HEAP');
  EmitRaw('        MOV     WORD PTR [AX], DX');
  EmitRaw('        ADD     DI, 2');
  EmitRaw('        MOV     WORD PTR [_CL_HEAPTOP], DI');
  EmitRaw('        POP     AX');
  (* Incrementer count dans la copie *)
  EmitRaw('        INC     WORD PTR [BX]');
  EmitRaw('        ADD     SI, 2');
  EmitRaw('        DEC     CX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SU_LP');
  EmitRaw(CL_RT_PFX + 'SU_DN:');
  EmitRaw('        MOV     AX, BX');
  EmitRaw('        POP     CX');
  EmitRaw('        POP     DX');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'SU_R1:');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'SU_R2:');
  EmitRaw('        MOV     AX, BX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 20 : _CLRT_SETINTER : intersection de deux ensembles --- *)
  (* Entree : AX = set1, BX = set2                                      *)
  (* Sortie : AX = nouveau set (elements communs)                        *)
  EmitRaw(CL_RT_PFX + 'SETINTER:');
  EmitRaw('        CMP     AX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SI_NL');
  EmitRaw('        CMP     BX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SI_NL');
  EmitRaw('        PUSH    SI');
  EmitRaw('        PUSH    DI');
  EmitRaw('        PUSH    DX');
  EmitRaw('        PUSH    CX');
  EmitRaw('        MOV     WORD PTR [_CL_STMP2], BX');
  (* Allouer un nouveau set vide *)
  EmitRaw('        MOV     DI, WORD PTR [_CL_HEAPTOP]');
  EmitRaw('        MOV     BX, DI');
  EmitRaw('        ADD     BX, OFFSET _CL_HEAP');
  EmitRaw('        MOV     WORD PTR [BX], 0');
  EmitRaw('        ADD     DI, 2');
  EmitRaw('        MOV     WORD PTR [_CL_HEAPTOP], DI');
  (* Parcourir s1 *)
  EmitRaw('        MOV     SI, AX');
  EmitRaw('        MOV     CX, WORD PTR [SI]');
  EmitRaw('        ADD     SI, 2');
  EmitRaw(CL_RT_PFX + 'SI_LP:');
  EmitRaw('        CMP     CX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SI_DN');
  EmitRaw('        MOV     DX, WORD PTR [SI]');
  (* Chercher DX dans s2 *)
  EmitRaw('        PUSH    CX');
  EmitRaw('        PUSH    SI');
  EmitRaw('        MOV     SI, WORD PTR [_CL_STMP2]');
  EmitRaw('        MOV     CX, WORD PTR [SI]');
  EmitRaw('        ADD     SI, 2');
  EmitRaw(CL_RT_PFX + 'SI_SR:');
  EmitRaw('        CMP     CX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SI_NP');
  EmitRaw('        CMP     WORD PTR [SI], DX');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SI_FD');
  EmitRaw('        ADD     SI, 2');
  EmitRaw('        DEC     CX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SI_SR');
  (* Element trouve dans s2 : ajouter au resultat *)
  EmitRaw(CL_RT_PFX + 'SI_FD:');
  EmitRaw('        POP     SI');
  EmitRaw('        POP     CX');
  EmitRaw('        MOV     DI, WORD PTR [_CL_HEAPTOP]');
  EmitRaw('        PUSH    AX');
  EmitRaw('        MOV     AX, DI');
  EmitRaw('        ADD     AX, OFFSET _CL_HEAP');
  EmitRaw('        MOV     WORD PTR [AX], DX');
  EmitRaw('        ADD     DI, 2');
  EmitRaw('        MOV     WORD PTR [_CL_HEAPTOP], DI');
  EmitRaw('        POP     AX');
  EmitRaw('        INC     WORD PTR [BX]');
  EmitRaw('        ADD     SI, 2');
  EmitRaw('        DEC     CX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SI_LP');
  (* Element absent de s2 : ignorer *)
  EmitRaw(CL_RT_PFX + 'SI_NP:');
  EmitRaw('        POP     SI');
  EmitRaw('        POP     CX');
  EmitRaw('        ADD     SI, 2');
  EmitRaw('        DEC     CX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SI_LP');
  EmitRaw(CL_RT_PFX + 'SI_DN:');
  EmitRaw('        MOV     AX, BX');
  EmitRaw('        POP     CX');
  EmitRaw('        POP     DX');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'SI_NL:');
  EmitRaw('        XOR     AX, AX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 20 : _CLRT_SETDIFF : difference de deux ensembles ------ *)
  (* Entree : AX = set1, BX = set2                                      *)
  (* Sortie : AX = nouveau set (elements de s1 absents de s2)           *)
  EmitRaw(CL_RT_PFX + 'SETDIFF:');
  EmitRaw('        CMP     AX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SF_NL');
  EmitRaw('        CMP     BX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SF_R1');
  EmitRaw('        PUSH    SI');
  EmitRaw('        PUSH    DI');
  EmitRaw('        PUSH    DX');
  EmitRaw('        PUSH    CX');
  EmitRaw('        MOV     WORD PTR [_CL_STMP2], BX');
  (* Allouer un nouveau set vide *)
  EmitRaw('        MOV     DI, WORD PTR [_CL_HEAPTOP]');
  EmitRaw('        MOV     BX, DI');
  EmitRaw('        ADD     BX, OFFSET _CL_HEAP');
  EmitRaw('        MOV     WORD PTR [BX], 0');
  EmitRaw('        ADD     DI, 2');
  EmitRaw('        MOV     WORD PTR [_CL_HEAPTOP], DI');
  (* Parcourir s1 *)
  EmitRaw('        MOV     SI, AX');
  EmitRaw('        MOV     CX, WORD PTR [SI]');
  EmitRaw('        ADD     SI, 2');
  EmitRaw(CL_RT_PFX + 'SF_LP:');
  EmitRaw('        CMP     CX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SF_DN');
  EmitRaw('        MOV     DX, WORD PTR [SI]');
  (* Chercher DX dans s2 *)
  EmitRaw('        PUSH    CX');
  EmitRaw('        PUSH    SI');
  EmitRaw('        MOV     SI, WORD PTR [_CL_STMP2]');
  EmitRaw('        MOV     CX, WORD PTR [SI]');
  EmitRaw('        ADD     SI, 2');
  EmitRaw(CL_RT_PFX + 'SF_SR:');
  EmitRaw('        CMP     CX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SF_AB');
  EmitRaw('        CMP     WORD PTR [SI], DX');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SF_PR');
  EmitRaw('        ADD     SI, 2');
  EmitRaw('        DEC     CX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SF_SR');
  (* Element present dans s2 : ignorer *)
  EmitRaw(CL_RT_PFX + 'SF_PR:');
  EmitRaw('        POP     SI');
  EmitRaw('        POP     CX');
  EmitRaw('        ADD     SI, 2');
  EmitRaw('        DEC     CX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SF_LP');
  (* Element absent de s2 : ajouter au resultat *)
  EmitRaw(CL_RT_PFX + 'SF_AB:');
  EmitRaw('        POP     SI');
  EmitRaw('        POP     CX');
  EmitRaw('        MOV     DI, WORD PTR [_CL_HEAPTOP]');
  EmitRaw('        PUSH    AX');
  EmitRaw('        MOV     AX, DI');
  EmitRaw('        ADD     AX, OFFSET _CL_HEAP');
  EmitRaw('        MOV     WORD PTR [AX], DX');
  EmitRaw('        ADD     DI, 2');
  EmitRaw('        MOV     WORD PTR [_CL_HEAPTOP], DI');
  EmitRaw('        POP     AX');
  EmitRaw('        INC     WORD PTR [BX]');
  EmitRaw('        ADD     SI, 2');
  EmitRaw('        DEC     CX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SF_LP');
  EmitRaw(CL_RT_PFX + 'SF_DN:');
  EmitRaw('        MOV     AX, BX');
  EmitRaw('        POP     CX');
  EmitRaw('        POP     DX');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'SF_NL:');
  EmitRaw('        XOR     AX, AX');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'SF_R1:');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 21 : _CLRT_VECDROP : sous-vecteur a partir de l index --- *)
  (* Entree : AX = pointeur vecteur, BX = start index (0-base)          *)
  (* Sortie : AX = nouveau vecteur contenant elements[BX..count-1]      *)
  (* Equivalent a (subvec vec start (count vec))                         *)
  (* Layout vecteur : [count, e0, e1, ..., e_{count-1}]                 *)
  EmitRaw(CL_RT_PFX + 'VECDROP:');
  EmitRaw('        CMP     AX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'VD_NL');
  EmitRaw('        PUSH    SI');
  EmitRaw('        PUSH    DI');
  EmitRaw('        PUSH    CX');
  EmitRaw('        PUSH    DX');
  EmitRaw('        MOV     SI, AX');
  EmitRaw('        MOV     CX, WORD PTR [SI]');
  (* CX = count total, BX = start *)
  EmitRaw('        CMP     BX, CX');
  EmitRaw('        JAE     ' + CL_RT_PFX + 'VD_EM');
  (* newcount = CX - BX *)
  EmitRaw('        SUB     CX, BX');
  (* Allouer le nouveau vecteur sur le heap *)
  EmitRaw('        MOV     DI, WORD PTR [_CL_HEAPTOP]');
  EmitRaw('        MOV     DX, DI');
  EmitRaw('        ADD     DX, OFFSET _CL_HEAP');
  EmitRaw('        MOV     WORD PTR [DX], CX');
  (* Avancer heaptop : (CX+1)*2 octets *)
  EmitRaw('        MOV     AX, CX');
  EmitRaw('        INC     AX');
  EmitRaw('        SHL     AX, 1');
  EmitRaw('        ADD     DI, AX');
  EmitRaw('        MOV     WORD PTR [_CL_HEAPTOP], DI');
  (* Copier les elements de SI+2+BX*2 vers DX+2 *)
  EmitRaw('        SHL     BX, 1');
  EmitRaw('        ADD     BX, 2');
  EmitRaw('        ADD     SI, BX');
  EmitRaw('        MOV     DI, DX');
  EmitRaw('        ADD     DI, 2');
  EmitRaw(CL_RT_PFX + 'VD_LP:');
  EmitRaw('        CMP     CX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'VD_DN');
  EmitRaw('        MOV     AX, WORD PTR [SI]');
  EmitRaw('        MOV     WORD PTR [DI], AX');
  EmitRaw('        ADD     SI, 2');
  EmitRaw('        ADD     DI, 2');
  EmitRaw('        DEC     CX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'VD_LP');
  EmitRaw(CL_RT_PFX + 'VD_DN:');
  EmitRaw('        MOV     AX, DX');
  EmitRaw('        POP     DX');
  EmitRaw('        POP     CX');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'VD_EM:');
  (* start >= count : retourner vecteur vide *)
  EmitRaw('        MOV     DI, WORD PTR [_CL_HEAPTOP]');
  EmitRaw('        MOV     DX, DI');
  EmitRaw('        ADD     DX, OFFSET _CL_HEAP');
  EmitRaw('        MOV     WORD PTR [DX], 0');
  EmitRaw('        ADD     DI, 2');
  EmitRaw('        MOV     WORD PTR [_CL_HEAPTOP], DI');
  EmitRaw('        MOV     AX, DX');
  EmitRaw('        POP     DX');
  EmitRaw('        POP     CX');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'VD_NL:');
  EmitRaw('        XOR     AX, AX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 22 : _CLRT_LREV : renverser une liste cons --- *)
  (* Entree : AX = pointeur liste (cons cells)               *)
  (* Sortie : AX = nouvelle liste renversee (cons cells)     *)
  (* Construit une nouvelle liste par cons successifs.        *)
  EmitRaw(CL_RT_PFX + 'LREV:');
  EmitRaw('        PUSH    SI');
  EmitRaw('        PUSH    BX');
  EmitRaw('        MOV     SI, AX');
  EmitRaw('        XOR     BX, BX');
  EmitRaw(CL_RT_PFX + 'LR_LP:');
  EmitRaw('        CMP     SI, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'LR_DN');
  EmitRaw('        MOV     AX, WORD PTR [SI]');
  EmitRaw('        CALL    ' + CL_RT_PFX + 'CONS');
  EmitRaw('        MOV     BX, AX');
  EmitRaw('        MOV     SI, WORD PTR [SI+2]');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'LR_LP');
  EmitRaw(CL_RT_PFX + 'LR_DN:');
  EmitRaw('        MOV     AX, BX');
  EmitRaw('        POP     BX');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 23 : _CLRT_SUBS : sous-chaine ----------------------- *)
  (* Entree : SI = source ASCIIZ, BX = start, CX = end (ou FFFFh)   *)
  (* Sortie : AX = pointeur vers _CL_STRBUF2 (sous-chaine)          *)
  EmitRaw(CL_RT_PFX + 'SUBS:');
  EmitRaw('        PUSH    DI');
  EmitRaw('        PUSH    DX');
  EmitRaw('        MOV     DI, OFFSET _CL_STRBUF2');
  EmitRaw('        ADD     SI, BX');
  EmitRaw('        XOR     DX, DX');
  EmitRaw('        ADD     DX, BX');
  EmitRaw(CL_RT_PFX + 'SB_LP:');
  EmitRaw('        CMP     BYTE PTR [SI], 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SB_DN');
  EmitRaw('        CMP     DX, CX');
  EmitRaw('        JAE     ' + CL_RT_PFX + 'SB_DN');
  EmitRaw('        MOV     AL, [SI]');
  EmitRaw('        MOV     [DI], AL');
  EmitRaw('        INC     SI');
  EmitRaw('        INC     DI');
  EmitRaw('        INC     DX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SB_LP');
  EmitRaw(CL_RT_PFX + 'SB_DN:');
  EmitRaw('        MOV     BYTE PTR [DI], 0');
  EmitRaw('        MOV     AX, OFFSET _CL_STRBUF2');
  EmitRaw('        POP     DX');
  EmitRaw('        POP     DI');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 23 : _CLRT_STRUPPER : majuscules --------------------- *)
  (* Entree : SI = source ASCIIZ                                     *)
  (* Sortie : AX = pointeur vers _CL_STRBUF2 (copie en majuscules)  *)
  EmitRaw(CL_RT_PFX + 'STRUPPER:');
  EmitRaw('        PUSH    SI');
  EmitRaw('        PUSH    DI');
  EmitRaw('        MOV     DI, OFFSET _CL_STRBUF2');
  EmitRaw(CL_RT_PFX + 'SU_LP:');
  EmitRaw('        MOV     AL, [SI]');
  EmitRaw('        TEST    AL, AL');
  EmitRaw('        JZ      ' + CL_RT_PFX + 'SU_DN');
  EmitRaw('        CMP     AL, 97');
  EmitRaw('        JB      ' + CL_RT_PFX + 'SU_SK');
  EmitRaw('        CMP     AL, 122');
  EmitRaw('        JA      ' + CL_RT_PFX + 'SU_SK');
  EmitRaw('        SUB     AL, 32');
  EmitRaw(CL_RT_PFX + 'SU_SK:');
  EmitRaw('        MOV     [DI], AL');
  EmitRaw('        INC     SI');
  EmitRaw('        INC     DI');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SU_LP');
  EmitRaw(CL_RT_PFX + 'SU_DN:');
  EmitRaw('        MOV     BYTE PTR [DI], 0');
  EmitRaw('        MOV     AX, OFFSET _CL_STRBUF2');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 23 : _CLRT_STRLOWER : minuscules --------------------- *)
  (* Entree : SI = source ASCIIZ                                     *)
  (* Sortie : AX = pointeur vers _CL_STRBUF2 (copie en minuscules)  *)
  EmitRaw(CL_RT_PFX + 'STRLOWER:');
  EmitRaw('        PUSH    SI');
  EmitRaw('        PUSH    DI');
  EmitRaw('        MOV     DI, OFFSET _CL_STRBUF2');
  EmitRaw(CL_RT_PFX + 'SL2_LP:');
  EmitRaw('        MOV     AL, [SI]');
  EmitRaw('        TEST    AL, AL');
  EmitRaw('        JZ      ' + CL_RT_PFX + 'SL2_DN');
  EmitRaw('        CMP     AL, 65');
  EmitRaw('        JB      ' + CL_RT_PFX + 'SL2_SK');
  EmitRaw('        CMP     AL, 90');
  EmitRaw('        JA      ' + CL_RT_PFX + 'SL2_SK');
  EmitRaw('        ADD     AL, 32');
  EmitRaw(CL_RT_PFX + 'SL2_SK:');
  EmitRaw('        MOV     [DI], AL');
  EmitRaw('        INC     SI');
  EmitRaw('        INC     DI');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SL2_LP');
  EmitRaw(CL_RT_PFX + 'SL2_DN:');
  EmitRaw('        MOV     BYTE PTR [DI], 0');
  EmitRaw('        MOV     AX, OFFSET _CL_STRBUF2');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 23 : _CLRT_STRTRIM : supprimer espaces debut/fin ---- *)
  (* Entree : SI = source ASCIIZ                                     *)
  (* Sortie : AX = pointeur vers _CL_STRBUF2 (copie trim)           *)
  EmitRaw(CL_RT_PFX + 'STRTRIM:');
  EmitRaw('        PUSH    SI');
  EmitRaw('        PUSH    DI');
  EmitRaw('        PUSH    CX');
  (* Avancer SI au-dela des espaces initiaux *)
  EmitRaw(CL_RT_PFX + 'ST_LS:');
  EmitRaw('        CMP     BYTE PTR [SI], 32');
  EmitRaw('        JE      ' + CL_RT_PFX + 'ST_LS2');
  EmitRaw('        CMP     BYTE PTR [SI], 9');
  EmitRaw('        JE      ' + CL_RT_PFX + 'ST_LS2');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'ST_CP');
  EmitRaw(CL_RT_PFX + 'ST_LS2:');
  EmitRaw('        INC     SI');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'ST_LS');
  (* Copier dans _CL_STRBUF2 *)
  EmitRaw(CL_RT_PFX + 'ST_CP:');
  EmitRaw('        MOV     DI, OFFSET _CL_STRBUF2');
  EmitRaw('        XOR     CX, CX');
  EmitRaw(CL_RT_PFX + 'ST_CL:');
  EmitRaw('        MOV     AL, [SI]');
  EmitRaw('        MOV     [DI], AL');
  EmitRaw('        TEST    AL, AL');
  EmitRaw('        JZ      ' + CL_RT_PFX + 'ST_TR');
  EmitRaw('        INC     SI');
  EmitRaw('        INC     DI');
  EmitRaw('        INC     CX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'ST_CL');
  (* Trim trailing: recul depuis la fin *)
  EmitRaw(CL_RT_PFX + 'ST_TR:');
  EmitRaw('        TEST    CX, CX');
  EmitRaw('        JZ      ' + CL_RT_PFX + 'ST_DN');
  EmitRaw('        DEC     DI');
  EmitRaw('        CMP     BYTE PTR [DI], 32');
  EmitRaw('        JE      ' + CL_RT_PFX + 'ST_T2');
  EmitRaw('        CMP     BYTE PTR [DI], 9');
  EmitRaw('        JE      ' + CL_RT_PFX + 'ST_T2');
  EmitRaw('        INC     DI');
  EmitRaw('        MOV     BYTE PTR [DI], 0');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'ST_DN');
  EmitRaw(CL_RT_PFX + 'ST_T2:');
  EmitRaw('        MOV     BYTE PTR [DI], 0');
  EmitRaw('        DEC     CX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'ST_TR');
  EmitRaw(CL_RT_PFX + 'ST_DN:');
  EmitRaw('        MOV     AX, OFFSET _CL_STRBUF2');
  EmitRaw('        POP     CX');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 23 : _CLRT_STRFIND : chercher sous-chaine ----------- *)
  (* Entree : SI = chaine source, DI = sous-chaine a chercher       *)
  (* Sortie : AX = 1 (true) si trouvee, 0 (false) sinon             *)
  EmitRaw(CL_RT_PFX + 'STRFIND:');
  EmitRaw('        PUSH    SI');
  EmitRaw('        PUSH    DI');
  EmitRaw('        PUSH    BX');
  EmitRaw('        PUSH    CX');
  EmitRaw('        MOV     BX, DI');
  EmitRaw(CL_RT_PFX + 'SF_OL:');
  EmitRaw('        CMP     BYTE PTR [SI], 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SF_NF');
  EmitRaw('        MOV     DI, BX');
  EmitRaw('        MOV     CX, SI');
  EmitRaw(CL_RT_PFX + 'SF_IL:');
  EmitRaw('        CMP     BYTE PTR [DI], 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SF_FD');
  EmitRaw('        CMP     BYTE PTR [CX], 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SF_NF');
  EmitRaw('        MOV     AL, [CX]');
  EmitRaw('        CMP     AL, [DI]');
  EmitRaw('        JNE     ' + CL_RT_PFX + 'SF_NX');
  EmitRaw('        INC     CX');
  EmitRaw('        INC     DI');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SF_IL');
  EmitRaw(CL_RT_PFX + 'SF_NX:');
  EmitRaw('        INC     SI');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SF_OL');
  EmitRaw(CL_RT_PFX + 'SF_FD:');
  EmitRaw('        MOV     AX, 1');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SF_EX');
  EmitRaw(CL_RT_PFX + 'SF_NF:');
  EmitRaw('        XOR     AX, AX');
  EmitRaw(CL_RT_PFX + 'SF_EX:');
  EmitRaw('        POP     CX');
  EmitRaw('        POP     BX');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 23 : _CLRT_STRREPL : remplacer occurrences ---------- *)
  (* Entree : SI = source, DI = match, _CL_SCTMP3 = replacement     *)
  (* Sortie : AX = pointeur vers _CL_STRBUF2 (resultat)             *)
  EmitRaw(CL_RT_PFX + 'STRREPL:');
  EmitRaw('        PUSH    BX');
  EmitRaw('        PUSH    CX');
  EmitRaw('        PUSH    DX');
  EmitRaw('        PUSH    SI');
  EmitRaw('        PUSH    DI');
  (* Calculer la longueur de match *)
  EmitRaw('        MOV     WORD PTR [_CL_SCTMP1], DI');
  EmitRaw('        XOR     CX, CX');
  EmitRaw(CL_RT_PFX + 'SR_ML:');
  EmitRaw('        CMP     BYTE PTR [DI], 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SR_MS');
  EmitRaw('        INC     DI');
  EmitRaw('        INC     CX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SR_ML');
  EmitRaw(CL_RT_PFX + 'SR_MS:');
  EmitRaw('        MOV     WORD PTR [_CL_SCTMP2], CX');
  EmitRaw('        MOV     BX, OFFSET _CL_STRBUF2');
  (* Boucle principale *)
  EmitRaw(CL_RT_PFX + 'SR_OL:');
  EmitRaw('        CMP     BYTE PTR [SI], 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SR_DN');
  (* Verifier si match commence ici *)
  EmitRaw('        MOV     DI, WORD PTR [_CL_SCTMP1]');
  EmitRaw('        MOV     DX, SI');
  EmitRaw(CL_RT_PFX + 'SR_CK:');
  EmitRaw('        CMP     BYTE PTR [DI], 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SR_MT');
  EmitRaw('        CMP     BYTE PTR [DX], 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SR_NM');
  EmitRaw('        MOV     AL, [DX]');
  EmitRaw('        CMP     AL, [DI]');
  EmitRaw('        JNE     ' + CL_RT_PFX + 'SR_NM');
  EmitRaw('        INC     DX');
  EmitRaw('        INC     DI');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SR_CK');
  (* Match trouve : copier replacement *)
  EmitRaw(CL_RT_PFX + 'SR_MT:');
  EmitRaw('        MOV     DI, WORD PTR [_CL_SCTMP3]');
  EmitRaw(CL_RT_PFX + 'SR_CR:');
  EmitRaw('        CMP     BYTE PTR [DI], 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SR_CA');
  EmitRaw('        MOV     AL, [DI]');
  EmitRaw('        MOV     [BX], AL');
  EmitRaw('        INC     BX');
  EmitRaw('        INC     DI');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SR_CR');
  EmitRaw(CL_RT_PFX + 'SR_CA:');
  EmitRaw('        ADD     SI, WORD PTR [_CL_SCTMP2]');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SR_OL');
  (* Pas de match : copier le caractere courant *)
  EmitRaw(CL_RT_PFX + 'SR_NM:');
  EmitRaw('        MOV     AL, [SI]');
  EmitRaw('        MOV     [BX], AL');
  EmitRaw('        INC     BX');
  EmitRaw('        INC     SI');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SR_OL');
  EmitRaw(CL_RT_PFX + 'SR_DN:');
  EmitRaw('        MOV     BYTE PTR [BX], 0');
  EmitRaw('        MOV     AX, OFFSET _CL_STRBUF2');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     SI');
  EmitRaw('        POP     DX');
  EmitRaw('        POP     CX');
  EmitRaw('        POP     BX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 23 : _CLRT_STRSPLIT : split sur un delimiteur -------- *)
  (* Entree : SI = source ASCIIZ, BL = caractere delimiteur          *)
  (* Sortie : AX = liste (cons cells) de pointeurs chaines heap      *)
  EmitRaw(CL_RT_PFX + 'STRSPLIT:');
  EmitRaw('        PUSH    CX');
  EmitRaw('        PUSH    DI');
  EmitRaw('        PUSH    DX');
  EmitRaw('        MOV     WORD PTR [_CL_SCTMP1], BX');
  EmitRaw('        XOR     DX, DX');
  (* DX = resultat liste (nil) *)
  (* Boucle externe : trouver le prochain token *)
  EmitRaw(CL_RT_PFX + 'SS_OL:');
  EmitRaw('        CMP     BYTE PTR [SI], 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SS_DN');
  (* Copier le segment dans le heap *)
  EmitRaw('        MOV     DI, WORD PTR [_CL_HEAPTOP]');
  EmitRaw('        MOV     CX, DI');
  EmitRaw('        ADD     CX, OFFSET _CL_HEAP');
  EmitRaw('        PUSH    CX');
  EmitRaw(CL_RT_PFX + 'SS_IL:');
  EmitRaw('        MOV     AL, [SI]');
  EmitRaw('        TEST    AL, AL');
  EmitRaw('        JZ      ' + CL_RT_PFX + 'SS_ES');
  EmitRaw('        CMP     AL, BYTE PTR [_CL_SCTMP1]');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SS_ES');
  EmitRaw('        MOV     BYTE PTR [CX], AL');
  EmitRaw('        INC     SI');
  EmitRaw('        INC     CX');
  EmitRaw('        INC     DI');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SS_IL');
  EmitRaw(CL_RT_PFX + 'SS_ES:');
  EmitRaw('        MOV     BYTE PTR [CX], 0');
  EmitRaw('        INC     DI');
  EmitRaw('        MOV     WORD PTR [_CL_HEAPTOP], DI');
  (* Sauter le delimiteur *)
  EmitRaw('        CMP     BYTE PTR [SI], 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SS_NC');
  EmitRaw('        INC     SI');
  EmitRaw(CL_RT_PFX + 'SS_NC:');
  (* Cons le segment sur la liste *)
  EmitRaw('        POP     AX');
  EmitRaw('        MOV     BX, DX');
  EmitRaw('        CALL    ' + CL_RT_PFX + 'CONS');
  EmitRaw('        MOV     DX, AX');
  EmitRaw('        MOV     BX, WORD PTR [_CL_SCTMP1]');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SS_OL');
  EmitRaw(CL_RT_PFX + 'SS_DN:');
  (* Renverser la liste pour l ordre correct *)
  EmitRaw('        MOV     AX, DX');
  EmitRaw('        CALL    ' + CL_RT_PFX + 'LREV');
  EmitRaw('        POP     DX');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     CX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 23 : _CLRT_STRJOIN : joindre avec separateur --------- *)
  (* Entree : SI = separateur ASCIIZ, BX = liste (cons cells)        *)
  (* Les elements de la liste sont des pointeurs chaines.             *)
  (* Sortie : AX = pointeur vers _CL_STRBUF2 (resultat)              *)
  EmitRaw(CL_RT_PFX + 'STRJOIN:');
  EmitRaw('        PUSH    CX');
  EmitRaw('        PUSH    DI');
  EmitRaw('        PUSH    DX');
  EmitRaw('        MOV     WORD PTR [_CL_SCTMP1], SI');
  EmitRaw('        MOV     DI, OFFSET _CL_STRBUF2');
  EmitRaw('        MOV     BYTE PTR [DI], 0');
  EmitRaw('        XOR     CX, CX');
  EmitRaw(CL_RT_PFX + 'SJ_LP:');
  EmitRaw('        CMP     BX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SJ_DN');
  (* Si ce n est pas le premier element, ajouter le sep *)
  EmitRaw('        TEST    CX, CX');
  EmitRaw('        JZ      ' + CL_RT_PFX + 'SJ_NS');
  EmitRaw('        MOV     SI, WORD PTR [_CL_SCTMP1]');
  EmitRaw(CL_RT_PFX + 'SJ_CS:');
  EmitRaw('        MOV     AL, [SI]');
  EmitRaw('        TEST    AL, AL');
  EmitRaw('        JZ      ' + CL_RT_PFX + 'SJ_NS');
  EmitRaw('        MOV     [DI], AL');
  EmitRaw('        INC     DI');
  EmitRaw('        INC     SI');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SJ_CS');
  (* Copier l element courant *)
  EmitRaw(CL_RT_PFX + 'SJ_NS:');
  EmitRaw('        PUSH    BX');
  EmitRaw('        MOV     SI, WORD PTR [BX]');
  EmitRaw(CL_RT_PFX + 'SJ_CE:');
  EmitRaw('        MOV     AL, [SI]');
  EmitRaw('        TEST    AL, AL');
  EmitRaw('        JZ      ' + CL_RT_PFX + 'SJ_NX');
  EmitRaw('        MOV     [DI], AL');
  EmitRaw('        INC     DI');
  EmitRaw('        INC     SI');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SJ_CE');
  EmitRaw(CL_RT_PFX + 'SJ_NX:');
  EmitRaw('        POP     BX');
  EmitRaw('        MOV     BX, WORD PTR [BX+2]');
  EmitRaw('        INC     CX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SJ_LP');
  EmitRaw(CL_RT_PFX + 'SJ_DN:');
  EmitRaw('        MOV     BYTE PTR [DI], 0');
  EmitRaw('        MOV     AX, OFFSET _CL_STRBUF2');
  EmitRaw('        POP     DX');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     CX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 24 : _CLRT_PRINT : ecriture brute sur handle ---------- *)
  (* Entree : BX = handle fichier, DX = adresse message, CX = longueur *)
  EmitRaw(CL_RT_PFX + 'PRINT:');
  EmitRaw('        PUSH    AX');
  EmitRaw('        MOV     AH, 40h');
  EmitRaw('        INT     21h');
  EmitRaw('        POP     AX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 24 : _CLRT_PRINTLN : afficher chaine + CR+LF ---------- *)
  (* Entree : SI = chaine ASCIIZ a afficher                           *)
  EmitRaw(CL_RT_PFX + 'PRINTLN:');
  EmitRaw('        CALL    ' + CL_RT_PFX + 'PRINTSTR');
  EmitRaw('        CALL    ' + CL_RT_PFX + 'WRITECRLF');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 24 : _CLRT_PRVAL : afficher valeur selon son tag ------ *)
  (* Entree : AX = valeur, BX = index de type (TY_IDX_xxx)            *)
  EmitRaw(CL_RT_PFX + 'PRVAL:');
  EmitRaw('        CMP     BX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'PV_NIL');
  EmitRaw('        CMP     BX, 1');
  EmitRaw('        JE      ' + CL_RT_PFX + 'PV_INT');
  EmitRaw('        CMP     BX, 2');
  EmitRaw('        JE      ' + CL_RT_PFX + 'PV_STR');
  EmitRaw('        CMP     BX, 3');
  EmitRaw('        JE      ' + CL_RT_PFX + 'PV_BOL');
  EmitRaw('        CMP     BX, 11');
  EmitRaw('        JE      ' + CL_RT_PFX + 'PV_CHR');
  (* types inconnus ou composites : afficher comme entier *)
  EmitRaw('        JMP     ' + CL_RT_PFX + 'PV_INT');
  EmitRaw(CL_RT_PFX + 'PV_NIL:');
  EmitRaw('        PUSH    SI');
  EmitRaw('        MOV     SI, OFFSET ' + CL_NIL_LBL);
  EmitRaw('        CALL    ' + CL_RT_PFX + 'PRINTSTR');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'PV_INT:');
  EmitRaw('        PUSH    DI');
  EmitRaw('        PUSH    SI');
  EmitRaw('        MOV     DI, OFFSET _CL_NUMBUF');
  EmitRaw('        CALL    ' + CL_RT_PFX + 'NUMTOSTR');
  EmitRaw('        MOV     SI, OFFSET _CL_NUMBUF');
  EmitRaw('        CALL    ' + CL_RT_PFX + 'PRINTSTR');
  EmitRaw('        POP     SI');
  EmitRaw('        POP     DI');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'PV_STR:');
  EmitRaw('        PUSH    SI');
  EmitRaw('        MOV     SI, AX');
  EmitRaw('        CALL    ' + CL_RT_PFX + 'PRINTSTR');
  EmitRaw('        POP     SI');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'PV_BOL:');
  EmitRaw('        CALL    ' + CL_RT_PFX + 'PRINTBOOL');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'PV_CHR:');
  EmitRaw('        PUSH    DX');
  EmitRaw('        MOV     DL, AL');
  EmitRaw('        MOV     AH, 02h');
  EmitRaw('        INT     21h');
  EmitRaw('        POP     DX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 24 : _CLRT_STRTONUM : ASCII -> entier (atoi) ---------- *)
  (* Entree : SI = chaine ASCIIZ                                       *)
  (* Sortie : AX = entier signe                                        *)
  EmitRaw(CL_RT_PFX + 'STRTONUM:');
  EmitRaw('        PUSH    BX');
  EmitRaw('        PUSH    CX');
  EmitRaw('        PUSH    DX');
  EmitRaw('        PUSH    SI');
  EmitRaw('        XOR     AX, AX');
  EmitRaw('        XOR     CX, CX');
  EmitRaw('        CMP     BYTE PTR [SI], ''-''');
  EmitRaw('        JNE     ' + CL_RT_PFX + 'SN_DG');
  EmitRaw('        INC     CX');
  EmitRaw('        INC     SI');
  EmitRaw(CL_RT_PFX + 'SN_DG:');
  EmitRaw('        MOV     BL, [SI]');
  EmitRaw('        CMP     BL, ''0''');
  EmitRaw('        JB      ' + CL_RT_PFX + 'SN_DN');
  EmitRaw('        CMP     BL, ''9''');
  EmitRaw('        JA      ' + CL_RT_PFX + 'SN_DN');
  EmitRaw('        SUB     BL, ''0''');
  EmitRaw('        XOR     BH, BH');
  EmitRaw('        PUSH    BX');
  EmitRaw('        MOV     BX, 10');
  EmitRaw('        XOR     DX, DX');
  EmitRaw('        MUL     BX');
  EmitRaw('        POP     BX');
  EmitRaw('        ADD     AX, BX');
  EmitRaw('        INC     SI');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SN_DG');
  EmitRaw(CL_RT_PFX + 'SN_DN:');
  EmitRaw('        TEST    CX, CX');
  EmitRaw('        JZ      ' + CL_RT_PFX + 'SN_OK');
  EmitRaw('        NEG     AX');
  EmitRaw(CL_RT_PFX + 'SN_OK:');
  EmitRaw('        POP     SI');
  EmitRaw('        POP     DX');
  EmitRaw('        POP     CX');
  EmitRaw('        POP     BX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 24 : _CLRT_TOSTR : valeur -> chaine selon tag --------- *)
  (* Entree : AX = valeur, BX = index de type                         *)
  (* Sortie : AX = pointeur chaine ASCIIZ                             *)
  EmitRaw(CL_RT_PFX + 'TOSTR:');
  EmitRaw('        CMP     BX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'TS_NIL');
  EmitRaw('        CMP     BX, 1');
  EmitRaw('        JE      ' + CL_RT_PFX + 'TS_INT');
  EmitRaw('        CMP     BX, 2');
  EmitRaw('        JE      ' + CL_RT_PFX + 'TS_STR');
  EmitRaw('        CMP     BX, 3');
  EmitRaw('        JE      ' + CL_RT_PFX + 'TS_BOL');
  EmitRaw('        CMP     BX, 11');
  EmitRaw('        JE      ' + CL_RT_PFX + 'TS_CHR');
  (* par defaut : convertir comme entier *)
  EmitRaw('        JMP     ' + CL_RT_PFX + 'TS_INT');
  EmitRaw(CL_RT_PFX + 'TS_NIL:');
  EmitRaw('        MOV     AX, OFFSET ' + CL_NIL_LBL);
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'TS_INT:');
  EmitRaw('        PUSH    DI');
  EmitRaw('        MOV     DI, OFFSET _CL_TMPBUF');
  EmitRaw('        CALL    ' + CL_RT_PFX + 'NUMTOSTR');
  EmitRaw('        MOV     AX, OFFSET _CL_TMPBUF');
  EmitRaw('        POP     DI');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'TS_STR:');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'TS_BOL:');
  EmitRaw('        CALL    ' + CL_RT_PFX + 'BOOLTOSTR');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'TS_CHR:');
  EmitRaw('        PUSH    DI');
  EmitRaw('        MOV     DI, OFFSET _CL_TMPBUF');
  EmitRaw('        MOV     BYTE PTR [DI], AL');
  EmitRaw('        MOV     BYTE PTR [DI+1], 0');
  EmitRaw('        MOV     AX, OFFSET _CL_TMPBUF');
  EmitRaw('        POP     DI');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 24 : _CLRT_VECNEW : allouer vecteur vide -------------- *)
  (* Entree : CX = nombre d elements (slots a 0)                      *)
  (* Sortie : AX = pointeur vers le nouveau vecteur [count,0,0,...]   *)
  EmitRaw(CL_RT_PFX + 'VECNEW:');
  EmitRaw('        PUSH    BX');
  EmitRaw('        PUSH    DI');
  EmitRaw('        PUSH    CX');
  EmitRaw('        MOV     DI, WORD PTR [_CL_HEAPTOP]');
  EmitRaw('        MOV     BX, DI');
  EmitRaw('        ADD     BX, OFFSET _CL_HEAP');
  EmitRaw('        MOV     WORD PTR [BX], CX');
  EmitRaw('        MOV     AX, CX');
  EmitRaw('        INC     AX');
  EmitRaw('        SHL     AX, 1');
  EmitRaw('        ADD     DI, AX');
  EmitRaw('        MOV     WORD PTR [_CL_HEAPTOP], DI');
  EmitRaw('        MOV     DI, BX');
  EmitRaw('        ADD     DI, 2');
  EmitRaw(CL_RT_PFX + 'VNW_Z:');
  EmitRaw('        CMP     CX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'VNW_D');
  EmitRaw('        MOV     WORD PTR [DI], 0');
  EmitRaw('        ADD     DI, 2');
  EmitRaw('        DEC     CX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'VNW_Z');
  EmitRaw(CL_RT_PFX + 'VNW_D:');
  EmitRaw('        MOV     AX, BX');
  EmitRaw('        POP     CX');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     BX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 24 : _CLRT_MAPNEW : allouer map vide ------------------- *)
  (* Entree : CX = nombre de paires (slots a 0)                        *)
  (* Sortie : AX = pointeur vers la map [count, k0,v0, k1,v1, ...]     *)
  EmitRaw(CL_RT_PFX + 'MAPNEW:');
  EmitRaw('        PUSH    BX');
  EmitRaw('        PUSH    DI');
  EmitRaw('        PUSH    DX');
  EmitRaw('        MOV     DI, WORD PTR [_CL_HEAPTOP]');
  EmitRaw('        MOV     BX, DI');
  EmitRaw('        ADD     BX, OFFSET _CL_HEAP');
  EmitRaw('        MOV     WORD PTR [BX], CX');
  EmitRaw('        MOV     AX, CX');
  EmitRaw('        SHL     AX, 2');
  EmitRaw('        ADD     AX, 2');
  EmitRaw('        ADD     DI, AX');
  EmitRaw('        MOV     WORD PTR [_CL_HEAPTOP], DI');
  EmitRaw('        MOV     DI, BX');
  EmitRaw('        ADD     DI, 2');
  EmitRaw('        MOV     DX, CX');
  EmitRaw('        SHL     DX, 1');
  EmitRaw(CL_RT_PFX + 'MNW_Z:');
  EmitRaw('        CMP     DX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'MNW_D');
  EmitRaw('        MOV     WORD PTR [DI], 0');
  EmitRaw('        ADD     DI, 2');
  EmitRaw('        DEC     DX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'MNW_Z');
  EmitRaw(CL_RT_PFX + 'MNW_D:');
  EmitRaw('        MOV     AX, BX');
  EmitRaw('        POP     DX');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     BX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 24 : _CLRT_SETNEW : allouer ensemble vide --------------- *)
  (* Entree : CX = nombre d elements (slots a 0)                        *)
  (* Sortie : AX = pointeur vers le set [count, e0, e1, ...]            *)
  (* Layout identique au vecteur                                         *)
  EmitRaw(CL_RT_PFX + 'SETNEW:');
  EmitRaw('        PUSH    BX');
  EmitRaw('        PUSH    DI');
  EmitRaw('        PUSH    CX');
  EmitRaw('        MOV     DI, WORD PTR [_CL_HEAPTOP]');
  EmitRaw('        MOV     BX, DI');
  EmitRaw('        ADD     BX, OFFSET _CL_HEAP');
  EmitRaw('        MOV     WORD PTR [BX], CX');
  EmitRaw('        MOV     AX, CX');
  EmitRaw('        INC     AX');
  EmitRaw('        SHL     AX, 1');
  EmitRaw('        ADD     DI, AX');
  EmitRaw('        MOV     WORD PTR [_CL_HEAPTOP], DI');
  EmitRaw('        MOV     DI, BX');
  EmitRaw('        ADD     DI, 2');
  EmitRaw(CL_RT_PFX + 'SNW_Z:');
  EmitRaw('        CMP     CX, 0');
  EmitRaw('        JE      ' + CL_RT_PFX + 'SNW_D');
  EmitRaw('        MOV     WORD PTR [DI], 0');
  EmitRaw('        ADD     DI, 2');
  EmitRaw('        DEC     CX');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'SNW_Z');
  EmitRaw(CL_RT_PFX + 'SNW_D:');
  EmitRaw('        MOV     AX, BX');
  EmitRaw('        POP     CX');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     BX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 24 : _CLRT_ALLOC : allocation generique sur le heap ---- *)
  (* Entree : CX = nombre d octets a allouer                           *)
  (* Sortie : AX = pointeur vers le bloc alloue                        *)
  EmitRaw(CL_RT_PFX + 'ALLOC:');
  EmitRaw('        PUSH    DI');
  EmitRaw('        MOV     DI, WORD PTR [_CL_HEAPTOP]');
  EmitRaw('        MOV     AX, DI');
  EmitRaw('        ADD     AX, OFFSET _CL_HEAP');
  EmitRaw('        ADD     DI, CX');
  EmitRaw('        MOV     WORD PTR [_CL_HEAPTOP], DI');
  EmitRaw('        POP     DI');
  EmitRaw('        RET');
  EmitBlankLine;

  (* --- TODO 24 : _CLRT_PANIC : erreur fatale + sortie DOS ---------- *)
  (* Entree : SI = message d erreur (ASCIIZ)                           *)
  EmitRaw(CL_RT_PFX + 'PANIC:');
  EmitRaw('        CALL    ' + CL_RT_PFX + 'PRINTSTR');
  EmitRaw('        CALL    ' + CL_RT_PFX + 'WRITECRLF');
  EmitRaw('        MOV     AX, 4C01h');
  EmitRaw('        INT     21h');
  EmitBlankLine;

  (* --- TODO 24 : _CLRT_EQUAL : egalite structurelle ----------------- *)
  (* Entree : AX = valeur a, BX = valeur b                              *)
  (* Sortie : AX = 1 (true) si egaux, 0 (false) sinon                   *)
  (* Comparaison simple (valeur directe). Pour les chaines,              *)
  (* les deux pointeurs sont compares (meme chaine DATA => egal).        *)
  (* Pour les listes/vecs, comparaison recursive non supportee ici.      *)
  EmitRaw(CL_RT_PFX + 'EQUAL:');
  EmitRaw('        CMP     AX, BX');
  EmitRaw('        JE      ' + CL_RT_PFX + 'EQ_T');
  (* Si les deux sont des chaines (non nul), comparer contenu *)
  EmitRaw('        TEST    AX, AX');
  EmitRaw('        JZ      ' + CL_RT_PFX + 'EQ_F');
  EmitRaw('        TEST    BX, BX');
  EmitRaw('        JZ      ' + CL_RT_PFX + 'EQ_F');
  EmitRaw('        PUSH    SI');
  EmitRaw('        PUSH    DI');
  EmitRaw('        MOV     SI, AX');
  EmitRaw('        MOV     DI, BX');
  EmitRaw(CL_RT_PFX + 'EQ_CL:');
  EmitRaw('        MOV     AL, [SI]');
  EmitRaw('        CMP     AL, [DI]');
  EmitRaw('        JNE     ' + CL_RT_PFX + 'EQ_NE');
  EmitRaw('        TEST    AL, AL');
  EmitRaw('        JZ      ' + CL_RT_PFX + 'EQ_YS');
  EmitRaw('        INC     SI');
  EmitRaw('        INC     DI');
  EmitRaw('        JMP     ' + CL_RT_PFX + 'EQ_CL');
  EmitRaw(CL_RT_PFX + 'EQ_YS:');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     SI');
  EmitRaw('        MOV     AX, 1');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'EQ_NE:');
  EmitRaw('        POP     DI');
  EmitRaw('        POP     SI');
  EmitRaw(CL_RT_PFX + 'EQ_F:');
  EmitRaw('        XOR     AX, AX');
  EmitRaw('        RET');
  EmitRaw(CL_RT_PFX + 'EQ_T:');
  EmitRaw('        MOV     AX, 1');
  EmitRaw('        RET');
  EmitBlankLine;

  EmitComment('=== FIN RUNTIME ===');
  EmitBlankLine;
End;

Procedure SymInit;
Begin
  (* TODO 05 - initialiser la table des symboles *)
  SymCount  := 0;
  ScopeTop  := 0;
  CurScope  := 0;
  LabelSeq  := 0;

  (* Formes speciales Clojure *)
  SymAdd('def',        SK_SPECIAL, TY_UNKNOWN, 0);
  SymAdd('defn',       SK_SPECIAL, TY_UNKNOWN, 0);
  SymAdd('defonce',    SK_SPECIAL, TY_UNKNOWN, 0);
  SymAdd('defmacro',   SK_SPECIAL, TY_UNKNOWN, 0);
  SymAdd('fn',         SK_SPECIAL, TY_IDX_FN,  0);
  SymAdd('fn*',        SK_SPECIAL, TY_IDX_FN,  0);
  SymAdd('let',        SK_SPECIAL, TY_UNKNOWN, 0);
  SymAdd('let*',       SK_SPECIAL, TY_UNKNOWN, 0);
  SymAdd('if',         SK_SPECIAL, TY_UNKNOWN, 0);
  SymAdd('do',         SK_SPECIAL, TY_UNKNOWN, 0);
  SymAdd('when',       SK_SPECIAL, TY_UNKNOWN, 0);
  SymAdd('cond',       SK_SPECIAL, TY_UNKNOWN, 0);
  SymAdd('case',       SK_SPECIAL, TY_UNKNOWN, 0);
  SymAdd('recur',      SK_SPECIAL, TY_UNKNOWN, 0);
  SymAdd('loop',       SK_SPECIAL, TY_UNKNOWN, 0);
  SymAdd('quote',      SK_SPECIAL, TY_UNKNOWN, 0);
  SymAdd('var',        SK_SPECIAL, TY_UNKNOWN, 0);
  SymAdd('try',        SK_SPECIAL, TY_UNKNOWN, 0);
  SymAdd('catch',      SK_SPECIAL, TY_UNKNOWN, 0);
  SymAdd('finally',    SK_SPECIAL, TY_UNKNOWN, 0);
  SymAdd('throw',      SK_SPECIAL, TY_UNKNOWN, 0);
  SymAdd('new',        SK_SPECIAL, TY_UNKNOWN, 0);
  SymAdd('set!',       SK_SPECIAL, TY_UNKNOWN, 0);
  SymAdd('monitor-enter', SK_SPECIAL, TY_UNKNOWN, 0);
  SymAdd('monitor-exit',  SK_SPECIAL, TY_UNKNOWN, 0);
  SymAdd('.',          SK_SPECIAL, TY_UNKNOWN, 0);
  SymAdd('import',     SK_SPECIAL, TY_UNKNOWN, 0);

  (* Fonctions predefinies - arithmetique *)
  SymAdd('+',          SK_FN, TY_IDX_INT, 0);
  SymAdd('-',          SK_FN, TY_IDX_INT, 0);
  SymAdd('*',          SK_FN, TY_IDX_INT, 0);
  SymAdd('/',          SK_FN, TY_IDX_INT, 0);
  SymAdd('mod',        SK_FN, TY_IDX_INT, 0);
  SymAdd('rem',        SK_FN, TY_IDX_INT, 0);
  SymAdd('inc',        SK_FN, TY_IDX_INT, 0);
  SymAdd('dec',        SK_FN, TY_IDX_INT, 0);

  (* Fonctions predefinies - comparaison *)
  SymAdd('=',          SK_FN, TY_IDX_BOOL, 0);
  SymAdd('<',          SK_FN, TY_IDX_BOOL, 0);
  SymAdd('>',          SK_FN, TY_IDX_BOOL, 0);
  SymAdd('<=',         SK_FN, TY_IDX_BOOL, 0);
  SymAdd('>=',         SK_FN, TY_IDX_BOOL, 0);
  SymAdd('==',         SK_FN, TY_IDX_BOOL, 0);
  SymAdd('not=',       SK_FN, TY_IDX_BOOL, 0);

  (* Fonctions predefinies - logique *)
  SymAdd('not',        SK_FN, TY_IDX_BOOL, 0);
  SymAdd('and',        SK_FN, TY_IDX_BOOL, 0);
  SymAdd('or',         SK_FN, TY_IDX_BOOL, 0);

  (* Fonctions predefinies - predicats *)
  SymAdd('nil?',       SK_FN, TY_IDX_BOOL, 0);
  SymAdd('zero?',      SK_FN, TY_IDX_BOOL, 0);
  SymAdd('pos?',       SK_FN, TY_IDX_BOOL, 0);
  SymAdd('neg?',       SK_FN, TY_IDX_BOOL, 0);
  SymAdd('even?',      SK_FN, TY_IDX_BOOL, 0);
  SymAdd('odd?',       SK_FN, TY_IDX_BOOL, 0);
  SymAdd('empty?',     SK_FN, TY_IDX_BOOL, 0);

  (* Fonctions predefinies - E/S *)
  SymAdd('println',    SK_FN, TY_IDX_NIL, 0);
  SymAdd('print',      SK_FN, TY_IDX_NIL, 0);
  SymAdd('pr',         SK_FN, TY_IDX_NIL, 0);
  SymAdd('prn',        SK_FN, TY_IDX_NIL, 0);

  (* Fonctions predefinies - chaines *)
  SymAdd('str',        SK_FN, TY_IDX_STR, 0);
  SymAdd('count',      SK_FN, TY_IDX_INT, 0);

  (* Fonctions predefinies - chaines (TODO 23) *)
  SymAdd('subs',       SK_FN, TY_IDX_STR, 0);
  SymAdd('clojure.string/upper-case', SK_FN, TY_IDX_STR, 0);
  SymAdd('clojure.string/lower-case', SK_FN, TY_IDX_STR, 0);
  SymAdd('clojure.string/trim',       SK_FN, TY_IDX_STR, 0);
  SymAdd('clojure.string/includes?',  SK_FN, TY_IDX_BOOL, 0);
  SymAdd('clojure.string/replace',    SK_FN, TY_IDX_STR, 0);
  SymAdd('clojure.string/split',      SK_FN, TY_IDX_LIST, 0);
  SymAdd('clojure.string/join',       SK_FN, TY_IDX_STR, 0);
  SymAdd('upper-case', SK_FN, TY_IDX_STR, 0);
  SymAdd('lower-case', SK_FN, TY_IDX_STR, 0);
  SymAdd('string/trim', SK_FN, TY_IDX_STR, 0);
  SymAdd('string/includes?', SK_FN, TY_IDX_BOOL, 0);
  SymAdd('string/replace', SK_FN, TY_IDX_STR, 0);
  SymAdd('string/split', SK_FN, TY_IDX_LIST, 0);
  SymAdd('string/join', SK_FN, TY_IDX_STR, 0);

  (* Fonctions predefinies - collections *)
  SymAdd('cons',       SK_FN, TY_IDX_LIST, 0);
  SymAdd('first',      SK_FN, TY_UNKNOWN,  0);
  SymAdd('rest',       SK_FN, TY_IDX_LIST, 0);
  SymAdd('list',       SK_FN, TY_IDX_LIST, 0);
  SymAdd('vector',     SK_FN, TY_IDX_VEC,  0);
  SymAdd('hash-map',   SK_FN, TY_IDX_MAP,  0);
  SymAdd('hash-set',   SK_FN, TY_IDX_SET,  0);
  SymAdd('get',        SK_FN, TY_UNKNOWN,  0);
  SymAdd('assoc',      SK_FN, TY_UNKNOWN,  0);
  SymAdd('dissoc',     SK_FN, TY_UNKNOWN,  0);
  SymAdd('conj',       SK_FN, TY_UNKNOWN,  0);
  SymAdd('nth',        SK_FN, TY_UNKNOWN,  0);
  SymAdd('subvec',     SK_FN, TY_IDX_VEC,  0);
  SymAdd('seq',        SK_FN, TY_IDX_LIST, 0);

  (* Fonctions predefinies - tables de hachage (TODO 19) *)
  SymAdd('contains?',  SK_FN, TY_IDX_BOOL, 0);
  SymAdd('keys',       SK_FN, TY_IDX_LIST, 0);
  SymAdd('vals',       SK_FN, TY_IDX_LIST, 0);
  SymAdd('merge',      SK_FN, TY_IDX_MAP,  0);

  (* Fonctions predefinies - ensembles (TODO 20) *)
  SymAdd('disj',         SK_FN, TY_IDX_SET,  0);
  SymAdd('union',        SK_FN, TY_IDX_SET,  0);
  SymAdd('intersection', SK_FN, TY_IDX_SET,  0);
  SymAdd('difference',   SK_FN, TY_IDX_SET,  0);

  (* Fonctions predefinies - fonctions d ordre superieur *)
  SymAdd('apply',      SK_FN, TY_UNKNOWN, 0);
  SymAdd('map',        SK_FN, TY_IDX_LIST, 0);
  SymAdd('filter',     SK_FN, TY_IDX_LIST, 0);
  SymAdd('reduce',     SK_FN, TY_UNKNOWN,  0);
  SymAdd('remove',     SK_FN, TY_IDX_LIST, 0);
  SymAdd('some',       SK_FN, TY_UNKNOWN,  0);
  SymAdd('every?',     SK_FN, TY_IDX_BOOL, 0);
  SymAdd('into',       SK_FN, TY_IDX_LIST, 0);
  SymAdd('comp',       SK_FN, TY_IDX_FN,   0);
  SymAdd('partial',    SK_FN, TY_IDX_FN,   0);
  SymAdd('constantly', SK_FN, TY_IDX_FN,   0);
  SymAdd('identity',   SK_FN, TY_UNKNOWN,  0);

  (* Fonctions predefinies - atomes *)
  SymAdd('atom',       SK_FN, TY_UNKNOWN, 0);
  SymAdd('deref',      SK_FN, TY_UNKNOWN, 0);
  SymAdd('reset!',     SK_FN, TY_UNKNOWN, 0);
  SymAdd('swap!',      SK_FN, TY_UNKNOWN, 0);
  SymAdd('compare-and-set!', SK_FN, TY_UNKNOWN, 0);
End;

Procedure ParseProgram;
Begin
  (* TODO 25 - stub : lire le premier token et boucler *)
  LexNextToken;
  While CurToken.Kind <> TK_EOF Do
  Begin
    ParseForm(GExprDummy);
  End;
End;

(* ============================================================
   PROCEDURE RUN - PIPELINE PRINCIPAL
   ============================================================ *)

Procedure Run;
Begin
  GlobalInit;
  If Opts.Verbose Then ShowBanner;

  TypeInit;
  SymInit;
  DataInit;
  EmitOpen;
  EmitHeader;
  LexInit;

  (* Boucle principale de compilation *)
  ParseProgram;

  LexClose;
  EmitRuntime;
  EmitClose;

  If Opts.Verbose Then ShowStats;

  If ErrorCount > 0 Then
    Halt(EXIT_ERROR)
  Else
    Halt(EXIT_OK);
End;

(* ============================================================
   PROGRAMME PRINCIPAL
   ============================================================ *)
Begin
  ParseArgs;
  Run;
End.
