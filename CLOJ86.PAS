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

  TODO 01 - INFRASTRUCTURE ET OPTIONS
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings)
            ParseArgs : analyser argv (source.clj [sortie.asm] [-v] [-d] [-w])
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .clj (source Clojure)
            Programme principal : validation des arguments et appel Run
            Version, Date, aide en ligne (option -h)

  TODO 02 - LECTEUR / TOKENISEUR (READER)
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

  TODO 03 - LITTERAUX ET CONSTANTES
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

  TODO 04 - READER MACROS ET FORMES SPECIALES DE LECTURE
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

  TODO 05 - TABLE DES SYMBOLES ET ENVIRONNEMENTS
            TSymKind : SK_VAR, SK_FN, SK_MACRO, SK_SPECIAL, SK_LOCAL,
              SK_KEYWORD, SK_NS
            TSymRec : Name, MangledName, Kind, TypeTag, Offset,
              ScopeLevel, IsConst, Namespace
            SymAdd, SymFind, SymFindInScope, SymMangle
            CurScope : compteur de portee imbriquee (let, fn, loop)
            SymEnterScope / SymLeaveScope : gestion des portees imbriquees
            Environnements lexicaux : chaque let/fn cree une portee
            Espaces de noms : prefixe ns/nom pour les symboles qualifies
            Symboles speciaux : def, defn, fn, let, if, do, recur, etc.

  TODO 06 - SYSTEME DE TYPES INTERNES (TAGS)
            Tags de valeurs Clojure (3 bits hauts d un Word) :
              TAG_NIL (0), TAG_TRUE (1), TAG_FALSE (2),
              TAG_INT (3), TAG_SYM (4), TAG_KW (5),
              TAG_CONS (6), TAG_VEC (7), TAG_MAP (8),
              TAG_SET (9), TAG_STR (10), TAG_FN (11), TAG_ATOM (12)
            Encodage compact : tag sur 4 bits + payload sur 12 bits
              ou tag dans un champ separe pour les objets heap
            TypeTab, TypeInit : enregistrer les types internes
            TypeCheck : verification dynamique de type a l execution
            type : forme retournant le tag d une valeur -> AX
            instance? : test de type -> AX=0|1
            Truthiness : nil et false sont faux, tout le reste est vrai

  TODO 07 - EMETTEUR DE CODE ASM
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

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES
            TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR/DK_LIST/DK_VEC/DK_MAP),
              IntVal, StrVal, ElemCount
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr, DataAddList, DataAddVec : variantes d ajout
            Variables globales (def) : entrees DK_WORD dans DATA
            Chaines litterales : DB 'abc',0 dans DATA avec label _CLK_N
            Keywords : table globale des mots-cles, chaque :kw -> index unique
            Vecteurs litteraux : blocs contigus DW dans DATA
            Maps litterales : paires cle/valeur DW dans DATA

  TODO 09 - VARIABLES GLOBALES (def / defonce)
            (def nom valeur) : declarer une variable globale
              Emission : calcul de valeur -> MOV [_CLV_nom], AX
            (def nom) : declaration sans valeur initiale -> nil
            (defonce nom valeur) : comme def mais n ecrase pas si deja defini
            Metadata sur les vars : ^:dynamic, ^:private (avertissements)
            (def ^:const nom valeur) : constante, inlining a la compilation
            Acces a une variable : MOV AX, [_CLV_nom]
            Pas de redefinition en mode strict (option -w avertissement)

  TODO 10 - EXPRESSIONS PRIMAIRES
            ParseForm : dispatcher selon le type de token lu
            Litteraux : nombre, chaine, true, false, nil, keyword, caractere
            Symboles : resolution dans l environnement courant
            Appel de fonction : (f arg1 arg2 ...) -> evaluation args + CALL
            Formes speciales : if, do, let, fn, def, quote, recur, loop, etc.
            Acces a une variable locale : MOV AX, [BP-offset]
            Acces a une variable globale : MOV AX, [_CLV_nom]
            Forme quote : (quote x) -> retourne x sans evaluation
            Forme do : (do expr1 expr2 ... exprN) -> evalue tout, retourne exprN

  TODO 11 - EXPRESSIONS ARITHMETIQUES ET COMPARAISONS
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

  TODO 12 - ENTREES/SORTIES (println / print / read-line)
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

  TODO 13 - FORMES SPECIALES : IF / DO / WHEN / COND / CASE
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

  TODO 14 - LIAISONS LOCALES : LET
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

  TODO 15 - FONCTIONS (defn / fn / apply)
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

  TODO 16 - BOUCLES : LOOP / RECUR / DOTIMES / DOSEQ
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

  TODO 17 - LISTES (cons / first / rest / conj)
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

  TODO 18 - VECTEURS (vector / nth / assoc / conj)
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

  TODO 19 - TABLES DE HACHAGE (hash-map / get / assoc / dissoc)
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

  TODO 20 - ENSEMBLES (hash-set / contains? / conj / disj)
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

  TODO 21 - DESTRUCTURATION (DESTRUCTURING)
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

  TODO 22 - FONCTIONS D ORDRE SUPERIEUR (map / filter / reduce)
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

  TODO 23 - CHAINES DE CARACTERES (str / subs / count)
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

  TODO 24 - RUNTIME MINIMAL
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

Begin
End.
