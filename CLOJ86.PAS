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
Procedure LitEval(Const T : TToken; Var Res : TExprVal); Forward;
(* TODO 05 *)
Function  SymMangle(Const Name : TString; Kind : TSymKind) : TString; Forward;
Function  SymFind(Const Name : TString) : Integer; Forward;
Function  SymAdd(Const Name : TString; Kind : TSymKind;
                 TypeIdx, Offset : Integer) : Integer; Forward;
Procedure SymEnterScope; Forward;
Procedure SymLeaveScope; Forward;
(* TODO 06 *)
Procedure TypeInit;      Forward;
Function  TypeSizeof(TypeIdx : Integer) : Integer; Forward;
(* TODO 07 *)
Function  LabelGen : TString; Forward;
Procedure EmitRaw(Const S : TString); Forward;
Procedure EmitBlankLine; Forward;
Procedure EmitComment(Const S : TString); Forward;
Procedure EmitLabel(Const Lbl : TString); Forward;
Procedure EmitInstr(Const Mnem, Ops : TString); Forward;
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
(* TODO 10 *)
Procedure ExprFlushToAX(Const E : TExprVal); Forward;
Procedure ParseForm(Var Res : TExprVal); Forward;
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
      Scanning := True;
      (* On jette le token lu et on en lit un autre.
         Si c etait un LPAREN/LBRACKET/LBRACE il faudrait
         sauter toute la forme imbriquee. Pour l instant on
         saute un seul token. Le skip recursif sera dans TODO 04. *)
    End;
  End;

  If Opts.DebugMode Then
    PrintToken(CurToken);
End;

(* ============================================================
   STUBS POUR TODOs 03-25  (a implementer)
   ============================================================ *)

Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := AVal;
  Res.TypeIdx := ATypeIdx;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

Procedure ExprMakeNone(Var Res : TExprVal);
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_IDX_NIL;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

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

Procedure LitEval(Const T : TToken; Var Res : TExprVal);
Begin
  (* TODO 03 - stub *)
  ExprMakeNone(Res);
End;

Function SymMangle(Const Name : TString; Kind : TSymKind) : TString;
Begin
  Case Kind Of
    SK_VAR   : SymMangle := CL_VAR_PFX + Name;
    SK_FN    : SymMangle := CL_FN_PFX + Name;
    SK_LOCAL : SymMangle := CL_VAR_PFX + Name;
  Else
    SymMangle := CL_VAR_PFX + Name;
  End;
End;

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

Function SymAdd(Const Name : TString; Kind : TSymKind;
                TypeIdx, Offset : Integer) : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    FatalError('table des symboles pleine');
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
  SymAdd := SymCount;
  Inc(SymCount);
  Inc(TotalSyms);
End;

Procedure SymEnterScope;
Begin
  If ScopeTop >= MAX_SCOPE Then
    FatalError('profondeur de portee maximale atteinte');
  ScopeStack[ScopeTop] := SymCount;
  Inc(ScopeTop);
  Inc(CurScope);
End;

Procedure SymLeaveScope;
Begin
  If ScopeTop > 0 Then
  Begin
    Dec(ScopeTop);
    SymCount := ScopeStack[ScopeTop];
    Dec(CurScope);
  End;
End;

Procedure TypeInit;
Begin
  (* TODO 06 - stub : initialiser les types primitifs *)
  TypeCount := 0;
End;

Function TypeSizeof(TypeIdx : Integer) : Integer;
Begin
  (* TODO 06 - stub *)
  TypeSizeof := 2;
End;

Function LabelGen : TString;
Var S : TString;
Begin
  Inc(LabelGenSeq);
  Str(LabelGenSeq, S);
  LabelGen := CL_LBL_PFX + S;
End;

Procedure EmitRaw(Const S : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, S);
End;

Procedure EmitBlankLine;
Begin
  If OutFOpen Then
    WriteLn(OutF);
End;

Procedure EmitComment(Const S : TString);
Begin
  EmitRaw('; ' + S);
End;

Procedure EmitLabel(Const Lbl : TString);
Begin
  EmitRaw(Lbl + ':');
End;

Procedure EmitInstr(Const Mnem, Ops : TString);
Begin
  If Ops = '' Then
    EmitRaw('        ' + Mnem)
  Else
    EmitRaw('        ' + Mnem + ' ' + Ops);
End;

Procedure EmitProlog;
Begin
  EmitInstr('PUSH', 'BP');
  EmitInstr('MOV', 'BP,SP');
End;

Procedure EmitEpilog;
Begin
  EmitInstr('MOV', 'SP,BP');
  EmitInstr('POP', 'BP');
  EmitInstr('RET', '');
End;

Procedure EmitOpen;
Begin
  Assign(OutF, Opts.OutFile);
  Rewrite(OutF);
  If IOResult <> 0 Then
    FatalError('impossible de creer ' + Opts.OutFile);
  OutFOpen := True;
End;

Procedure EmitHeader;
Begin
  EmitComment('=========================================================');
  EmitComment('Genere par CLOJ86 v' + CLOJ86_VERSION + ' (' + CLOJ86_DATE + ')');
  EmitComment('Source  : ' + Opts.SrcFile);
  EmitComment('Cible   : MASM 8086, modele SMALL');
  EmitComment('=========================================================');
  EmitBlankLine;
  EmitRaw('        .8086');
  EmitRaw('        DOSSEG');
  EmitRaw('        .MODEL  SMALL');
  EmitBlankLine;
  EmitRaw('        .STACK  ' + IntToStr(STACK_SIZE));
  EmitBlankLine;
  EmitRaw('_TEXT   SEGMENT PUBLIC ''CODE''');
  EmitRaw('        ASSUME  CS:_TEXT, DS:_DATA, SS:STACK');
  EmitBlankLine;
End;

Procedure EmitDataSeg;
Var I : Integer;
Begin
  EmitBlankLine;
  EmitRaw('_DATA   SEGMENT PUBLIC ''DATA''');
  EmitBlankLine;
  For I := 0 To DataCount - 1 Do
  Begin
    Case DataTab[I].Kind Of
      DK_WORD :
        EmitRaw(DataTab[I].LblName + '        DW ' + DataTab[I].StrVal);
      DK_BYTE :
        EmitRaw(DataTab[I].LblName + '        DB ' + DataTab[I].StrVal);
      DK_STR :
        EmitRaw(DataTab[I].LblName + '        DB ''' + DataTab[I].StrVal + ''',0');
    Else
      EmitRaw(DataTab[I].LblName + '        DW 0');
    End;
  End;
  EmitBlankLine;
  EmitRaw('_DATA   ENDS');
End;

Procedure EmitClose;
Begin
  EmitBlankLine;
  EmitRaw('_TEXT   ENDS');
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

Procedure ExprFlushToAX(Const E : TExprVal);
Var S : TString;
Begin
  Case E.Kind Of
    EK_IMM :
    Begin
      Str(E.ImmVal, S);
      EmitInstr('MOV', 'AX,' + S);
    End;
    EK_MEM :
    Begin
      Str(E.Offset, S);
      EmitInstr('MOV', 'AX,[BP-' + S + ']');
    End;
    EK_AX  : ;  (* deja dans AX *)
    EK_NONE : EmitInstr('XOR', 'AX,AX');  (* nil = 0 *)
  End;
End;

Procedure ParseForm(Var Res : TExprVal);
Begin
  (* TODO 10 - stub *)
  ExprMakeNone(Res);
End;

Procedure EmitRuntime;
Begin
  (* TODO 24 - stub *)
  If RuntimeEmitted Then Exit;
  RuntimeEmitted := True;
End;

Procedure SymInit;
Begin
  (* TODO 05 - stub : enregistrer les formes speciales *)
  SymCount := 0;
End;

Procedure ParseProgram;
Begin
  (* TODO 25 - stub : lire le premier token et boucler *)
  LexNextToken;
  While CurToken.Kind <> TK_EOF Do
  Begin
    ParseForm(GExprDummy);
    LexNextToken;
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
