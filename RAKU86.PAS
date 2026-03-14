{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Raku vers assembleur 8086
}

(* ============================================================
  RAKU86.PAS - Compilateur Raku vers assembleur 8086
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .MODEL SMALL, DOS 16 bits

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode)
            ParseArgs : analyser argv (source.raku [sortie.asm] [-v] [-d])
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter les extensions .raku, .rakumod, .rakutest, .p6, .pm6
            Programme principal : validation des arguments et appel Run
            Version, Date, aide en ligne (option -h)

  TODO 02 - LEXEUR (TOKENS RAKU) [IMPLEMENTE]
            TTokenKind : TK_EOF, TK_INTEGER, TK_RATIONAL, TK_STRING,
              TK_IDENT, TK_KEYWORD, TK_OP, TK_PUNCT, TK_REGEX,
              TK_SIGIL, TK_TWIGIL
            LexInit, LexClose, LexNextToken, LexScanIdent, LexScanNumber
            LexScanString : chaines entre guillemets doubles "abc"
              Interpolation de variables : "Hello $name"
              Chaines simples entre apostrophes 'abc' (pas d interpolation)
              Heredocs : q:to/END/; ... END
            Commentaires : # ligne, #`( ... ) bloc imbrique
            Sigils : $ (scalaire), @ (tableau), % (hash), & (code)
            Twigils : $. (attribut), $! (attribut prive), $* (global),
              $? (compile-time), $^ (placeholder)
            Mots-cles : my our has sub method class role module use need
              if elsif else unless given when default for loop while
              until repeat do gather take return last next redo
              multi proto only is does of returns where begin end
              try CATCH CONTROL die fail throw new self has
              True False Nil Mu Any
            Mode debug -d : affichage de chaque token avec PrintToken

  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
            Entiers decimaux : 0..65535 ou -32768..32767 (Int)
            Entiers autres bases : 0x1FF (hex), 0o77 (octal), 0b1010 (binaire)
            Separateurs : underscores dans les nombres 1_000_000
            Rationnels : reconnus par le lexeur, traites comme entiers (trunc)
              Rat : 3.14 -> arrondi entier (avertissement)
            Chaines entre guillemets doubles : "Hello $var" (interpolation)
            Chaines entre apostrophes : 'Hello' (pas d interpolation)
            Heredocs : q:to/END/; ... END
            True : constante booleenne -> AX=1
            False : constante booleenne -> AX=0
            Nil : constante indefinie -> AX=0
            Inf et NaN : non supportes sur 8086 (avertissement)
            Sequences d echappement : \n \t \r \\ \" \x[NN] \o[NN]

  TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
            Arithmetiques  : + - * / div mod %% (divisible)
            Chaines        : ~ (concatenation), x (repetition)
            Comparaison num: == != < <= > >= <=> (three-way)
            Comparaison str: eq ne lt le gt ge leg cmp
            Logiques       : && || ! // (defined-or)
              and or not (basse precedence)
            Affectation    : = := (bind)
            Affectation composee : += -= *= /= ~= x=
            Unaire         : + - ! ? ~ so not (prefixe)
            Increment/Decrement : ++ -- (prefixe et postfixe)
            Intervalles    : .. ..^ ^.. ^..^
            Jonctions      : | (any), & (all), ^ (one)
            Ternaire       : ?? !! (condition ?? vrai !! faux)
            Smart match    : ~~ (pattern matching)
            Precedence (du plus fort au plus faible) :
              1. postfixe : ++ -- appels de methodes .method
              2. prefixe : ! + - ~ ? so not
              3. * / div mod %%
              4. + - ~ (binaire)
              5. x (repetition)
              6. .. ..^ ^.. ^..^
              7. == != < <= > >= eq ne lt le gt ge
              8. && // ~~
              9. ||
             10. ?? !!
             11. = := += -= etc.
             12. and or not

  TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
            TSymKind : SK_MY, SK_OUR, SK_HAS, SK_PARAM, SK_SUB,
              SK_METHOD, SK_CLASS, SK_ROLE, SK_MODULE, SK_CONST
            TSymRec : Name, Sigil, Twigil, MangledName, Kind,
              TypeIdx, Offset, Scope, IsExported
            SymAdd, SymFind, SymFindInScope, SymMangle
            CurScope : compteur de portee imbriquee (max MAX_SCOPE)
            SymEnterScope / SymLeaveScope : gestion des portees
            Sigils dans la recherche : $x, @x, %x sont des symboles distincts
            Lexical scoping : my $x visible uniquement dans le bloc courant
            Package scoping : our $x visible dans le package

  TODO 06 - SYSTEME DE TYPES [IMPLEMENTE]
            TTypeKind : TYK_INT (Int, 16 bits), TYK_BOOL (Bool, 8 bits),
              TYK_STR (Str, ptr chaine), TYK_RAT (Rat, stub entier),
              TYK_ARRAY (Array), TYK_HASH (Hash),
              TYK_CODE (Code, ptr sub/block), TYK_CLASS (objet instance),
              TYK_ROLE (role compose), TYK_MU (Mu, type racine),
              TYK_ANY (Any, sous-type de Mu), TYK_JUNCTION (Junction),
              TYK_PAIR (Pair cle=>valeur), TYK_REGEX (Regex),
              TYK_MATCH (Match), TYK_NIL (type indefini)
            TypeTab, TypeInit : enregistrer les types primitifs
            TypeSizeof : Int=2, Bool=1, Str=2 (ptr), Array=2 (ptr)
            Contraintes de type : Int where * > 0 (simplifie)
            Coercion : +$x (numerique), ~$x (chaine), ?$x (booleen)

  TODO 07 - EMETTEUR DE CODE ASM
            TEmitter : OutF (Text), OutFOpen, EmitOpen, EmitClose
            EmitRaw, EmitLabel, EmitInstr (formatage 8 espaces)
            EmitComment, EmitBlankLine
            LabelGen global (compteur unique _RKL_NNNNN)
            Prefixes : _RKV_ (variable), _RKS_ (sub/method),
              _RKK_ (chaine const), _RKRT_ (runtime), _RKL_ (label),
              _RKC_ (classe), _RKR_ (role), _RKG_ (grammar)
            EmitHeader : .MODEL SMALL / .STACK 1024 / _TEXT SEGMENT
            EmitProlog / EmitEpilog : PUSH BP / MOV BP,SP et
              MOV SP,BP / POP BP / RET
            EmitDataSeg : ecrire _DATA SEGMENT ... _DATA ENDS

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES
            TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR/
              DK_ARRAY/DK_HASH), IntVal, StrVal, ElemCount
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr, DataAddArray, DataAddHash
            Variables our (package) : entrees DW dans DATA
            Constantes : entrees DW ou DB (immuables)
            Chaines litterales : DB 'abc',0 dans DATA avec label _RKK_N
            Tables de methodes virtuelles pour les classes
            Tables de dispatch pour les multi subs

  TODO 09 - VARIABLES ET AFFECTATIONS
            Variables my scalaires ($x) : pile BP, acces [BP-offset]
            Variables our scalaires ($x) : segment DATA, label _RKV_nom
            Tableaux my (@arr) : bloc contigu sur la pile
            Hashs my (%h) : structure de hachage simplifiee sur la pile
            Affectation = : ExprLoad + MOV destination, AX
            Binding := : aliasing (meme adresse memoire)
            Declarateurs : my, our, has, constant
            Typage optionnel : my Int $x = 42;
            Valeurs par defaut : my $x = 0; (initialisation)
            Affectation destructuree : my ($a, $b) = (1, 2)

  TODO 10 - EXPRESSIONS PRIMAIRES
            ParsePrimary : literal entier, literal chaine, ident,
              appel de sub, instanciation Classe.new
            Acces attribut : $obj.attribut -> appel accessor
            Acces methode : $obj.methode(args) -> CALL via vtable
            Acces element tableau : @arr[$i] -> offset dans ARRAY
            Acces element hash : %h{$key} -> CALL lookup
            Interpolation de chaine : "x = $x" -> concatenation
            Contexte numerique : +$x -> coercion vers Int
            Contexte chaine : ~$x -> coercion vers Str
            Contexte booleen : ?$x -> coercion vers Bool (so)
            self : reference a l objet courant dans une methode
            Construction de paire : clef => valeur -> Pair

  TODO 11 - EXPRESSIONS BINAIRES
            ParseExprPrec(MinPrec) : boucle de precedence (Pratt)
            Arithmetique entiere : ADD/SUB/IMUL/IDIV pour +, -, *, /
            div : division entiere (IDIV quotient dans AX)
            mod : reste de division entiere (IDIV reste dans DX)
            Concatenation ~ : CALL _RKRT_CONCAT(SI=gauche, DI=droite)
            Repetition x : CALL _RKRT_REPEAT(SI=chaine, CX=count)
            Comparaison == : CMP + JE/JNE -> AX=0|1
            Comparaison eq : CALL _RKRT_STRCMP -> AX=0|1
            Three-way <=> : CMP -> AX=-1|0|1 (Order::Less/Same/More)
            Logique && : court-circuit JZ vers false-branch
            Logique || : court-circuit JNZ vers true-branch
            Defined-or // : TEST AX,AX / JNZ (sauter si defini)
            Smart match ~~ : dispatch selon type droit
            Ternaire ?? !! : condition -> JZ vers branche fausse

  TODO 12 - ENTREES/SORTIES (say, print, put, get, prompt)
            say($x) : afficher $x + saut de ligne
              -> CALL _RKRT_PRINT + ecriture CR+LF
            print($x) : afficher $x sans saut de ligne
              -> CALL _RKRT_PRINT (INT 21h AH=40h BX=1)
            put($x) : identique a say (alias)
            $line = get() : lire une ligne depuis STDIN
              -> INT 21h AH=0Ah (lecture ligne avec tampon)
            prompt("message") : afficher message + lire ligne
              -> CALL _RKRT_PRINT + CALL _RKRT_GETLINE
            note("msg") : ecrire sur STDERR (handle 2)
              -> INT 21h AH=40h BX=2
            $*IN, $*OUT, $*ERR : handles standards (0, 1, 2)
            Formatage numerique : conversion Int -> Str pour affichage
              -> CALL _RKRT_NUMTOSTR(AX=n, DI=buf)
            Formatage chaine interpolee : concatener les segments

  TODO 13 - CONDITIONNELLES (if/elsif/else, unless, given/when)
            ParseIfStmt : if cond { stmts } elsif cond { stmts }
              else { stmts }
              Emission TEST AX,AX / JZ pour condition fausse
              Labels : _RKL_ELSIF_N, _RKL_ELSE_N, _RKL_ENDIF_N
            ParseUnlessStmt : unless cond { stmts }
              Negation : JNZ au lieu de JZ
            Postfixe : stmt if cond; stmt unless cond;
              Evaluer la condition d abord, puis le statement
            ParseGivenWhenStmt : given $x { when val { stmts }
              when val { stmts } default { stmts } }
              Emission : CMP + JE pour chaque when
              Smart matching implicite sur $_
              Labels : _RKL_WHEN_N, _RKL_DEFAULT_N, _RKL_ENDGIVEN_N
            With/Without : with $x { ... } without $x { ... }
              Test de definitude (defini vs Nil)

  TODO 14 - BOUCLES (loop, while, until, repeat, for)
            ParseLoopStmt : loop (init; cond; incr) { stmts }
              Equivalent du for C : init, test, corps, increment
              Labels : _RKL_LINIT_N, _RKL_LTEST_N, _RKL_LINCR_N,
                _RKL_LEND_N
            loop { stmts } : boucle infinie (sans condition)
            ParseWhileStmt : while cond { stmts }
              Labels : _RKL_WTEST_N, _RKL_WEND_N
            ParseUntilStmt : until cond { stmts }
              Negation : JNZ au lieu de JZ
            ParseRepeatStmt : repeat { stmts } while cond;
              Labels : _RKL_RBEG_N, _RKL_RTEST_N
            ParseForStmt : for @liste -> $elem { stmts }
              Iterateur pointeur : BX=ptr courant, CX=nb restant
              Variable $elem liee a l element courant (lecture seule)
              Labels : _RKL_FTEST_N, _RKL_FINCR_N, _RKL_FEND_N
            Postfixe : stmt for @list; stmt while cond;
            Controle de boucle : last (sortie), next (iteration suivante),
              redo (recommencer iteration courante)
            LoopPush / LoopPop : pile de labels pour last/next

  TODO 15 - TABLEAUX ET LISTES (Array, List)
            Declaration : my @arr = (1, 2, 3);
              Allocation sur pile ou DATA selon contexte
              Representation : bloc contigu de mots (DW) + compteur
            Acces indexe : @arr[$i] -> offset = $i * 2
              Verification de bornes optionnelle
            @arr.elems / @arr.end : nombre d elements / dernier indice
            @arr.push($x), @arr.pop : ajout/retrait en fin
              -> CALL _RKRT_PUSH / _RKRT_POP
            @arr.shift, @arr.unshift($x) : ajout/retrait en debut
            @arr.reverse : inverser le tableau
            @arr.sort : tri du tableau (appel runtime tri insertion)
            @arr.grep(cond) : filtrer les elements
            @arr.map(-> $x { expr }) : transformer les elements
            @arr.join(",") : joindre en chaine avec separateur
            Tranches : @arr[1..3] -> sous-tableau
            Aplatissement : |@arr (slip) dans une liste

  TODO 16 - TABLES DE HACHAGE (Hash)
            Declaration : my %h = (clef => "valeur", clef2 => 42);
              Structure de hachage simplifiee : tableau de paires
              cle (Str ptr) + valeur (Int ou Str ptr)
            Acces : %h{"clef"} ou %h<clef> -> CALL _RKRT_HLOOKUP
            Affectation : %h{"clef"} = valeur -> CALL _RKRT_HSTORE
            %h.keys : liste des clefs -> CALL _RKRT_HKEYS
            %h.values : liste des valeurs -> CALL _RKRT_HVALUES
            %h.pairs : liste des paires (Pair) -> CALL _RKRT_HPAIRS
            %h.elems : nombre de paires -> AX
            %h:exists{"clef"} : test d existence -> AX=0|1
            %h:delete{"clef"} : suppression d une entree
            Iteration : for %h.kv -> $k, $v { ... }
            Hash en segment DATA pour les variables our

  TODO 17 - SOUS-ROUTINES ET FONCTIONS (sub, return)
            ParseSubDecl : sub nom(params) [returns Type] { stmts }
            Parametres positionnels : sub f($a, $b) { ... }
              Empiles de droite a gauche, acces [BP+offset]
            Parametres optionnels : sub f($a, $b = 42) { ... }
              Valeur par defaut si argument absent
            Parametres nommes : sub f(:$clef) { ... }
              Passage par paire cle => valeur
            Parametres slurpy : sub f(*@rest) { ... }
              Collecte des arguments restants dans un tableau
            Convention d appel : cdecl 16 bits
            Prologue : PUSH BP / MOV BP,SP / SUB SP, locals_size
            Epilogue : MOV SP,BP / POP BP / RET
            return expr : MOV AX, valeur + JMP vers epilogue
            Blocs anonymes : -> $x { expr } (pointy block)
              Pointeur de code stocke comme valeur
            Appel indirect : $code.($args) -> CALL [ptr]
            Recursion : appel direct par nom

  TODO 18 - MULTI DISPATCH (multi sub, proto)
            Declaraton multi : multi sub f(Int $x) { ... }
              multi sub f(Str $x) { ... }
            proto sub f(|) {*} : prototype (optionnel)
            Table de dispatch : tableau de (signature, ptr_code)
              Stocke dans DATA avec label _RKS_nom_DISP
            Resolution a l appel : parcourir les candidats,
              verifier le type de chaque argument
              Appeler le premier candidat correspondant
            Candidat par defaut : multi sub f($x) { ... }
              (sans contrainte de type, utilise en dernier)
            Ambiguite : erreur si aucun candidat ne correspond
            multi method dans les classes : meme mecanisme
              avec self comme premier argument implicite
            Verification de type au runtime :
              Comparer TypeIdx de chaque argument avec la signature

  TODO 19 - CLASSES ET OBJETS (class, has, method, new)
            ParseClassDecl : class Nom [is Parent] [does Role] { ... }
            Attributs : has $.attr (public), has $!attr (prive)
              Stockes comme champs dans l instance (offsets fixes)
              Accesseurs automatiques pour $.attr (lecture seule)
              has $.attr is rw : accesseur lecture/ecriture
            method nom(params) { ... } : methode d instance
              self disponible comme premier parametre implicite
            Constructeur .new : allocation memoire + initialisation
              -> CALL _RKRT_NEW(CX=taille) -> AX=ptr objet
              Parametres nommes : Classe.new(attr => val)
            Heritage : class Enfant is Parent { ... }
              Copie des attributs du parent + ajouts
              Vtable : table de methodes virtuelles dans DATA
              Surcharge de methode : remplacer l entree dans vtable
            Appel de methode : $obj.methode(args)
              MOV BX,[AX] (ptr vtable) / CALL [BX+offset]
            Methodes speciales : BUILD, TWEAK (initialisation)
            .isa(Classe) : test d heritage -> AX=0|1

  TODO 20 - ROLES (role, does)
            ParseRoleDecl : role Nom { has ...; method ...; }
            Composition : class C does Role1 does Role2 { ... }
              Copier les attributs et methodes du role dans la classe
              au moment de la compilation (aplatissement)
            Methodes requises : method nom(...) { ... } dans le role
              La classe composante doit fournir l implementation
              si le role ne fournit qu un stub (method nom { ... })
            Resolution de conflits : si deux roles fournissent
              la meme methode, la classe doit la redefinir
            Verification a la compilation : erreur si un role
              exige une methode non fournie par la classe
            Methodes par defaut : le role peut fournir une implementation
              que la classe peut surcharger
            role avec parametres : role Nom[Type] { ... }
              (simplifie : un seul parametre de type)
            $obj.does(Role) : test si l objet compose le role -> AX=0|1

  TODO 21 - GRAMMAIRES ET REGEX (grammar, regex, token, rule)
            ParseGrammarDecl : grammar Nom { token ...; rule ...; }
            Regles token : token nom { pattern }
              Correspondance sans retour en arriere (backtrack)
            Regles rule : rule nom { pattern }
              Ignore les espaces (sigspace), sans retour en arriere
            Regles regex : regex nom { pattern }
              Avec retour en arriere (backtracking)
            Motifs de base :
              Litteraux : 'abc' (correspondance exacte)
              Classes de caracteres : <[a..z]> <[0..9]> <alpha> <digit>
              Quantificateurs : * (0+), + (1+), ? (0 ou 1)
              Alternation : | (ordonnee), || (premiere correspondance)
              Groupement : [ ... ] (non-capturant), ( ... ) (capturant)
              Ancres : ^ (debut), $ (fin)
            Appel de sous-regle : <nom_token> dans un pattern
            Objet Match ($/) : resultat de la correspondance
            Methode .parse($str) : lancer l analyse
              Emission : automate a etats (DFA simplifie) en ASM
              ou suite de CMP/JE/JNE pour les cas simples
            Actions : class Actions { method nom($/) { ... } }
              Appel automatique apres correspondance reussie

  TODO 22 - GESTION DES ERREURS (try, CATCH, die, fail)
            ParseTryCatchStmt : try { stmts CATCH { ... } }
              CATCH { when ExceptionType { stmts }
                      default { stmts } }
            die "message" : lever une exception fatale
              AX = code exception, BX = ptr message
            fail "message" : retourner une Failure (exception paresseuse)
              (simplifie : equivalent a die sur 8086)
            X::AdHoc : exception generique (message texte)
            Mecanisme sans support OS :
              _RK_HANDLER DW 0 dans DATA (ptr vers handler courant)
              try : sauvegarder ancien handler, installer nouveau
                MOV [_RK_HANDLER], OFFSET _RKL_CATCH_N
              CATCH : label _RKL_CATCH_N, dispatcher selon type exception
              Restauration : MOV [_RK_HANDLER], ancien_handler
            die sans handler : afficher 'Unhandled exception' + Halt
            warn "message" : avertissement sur STDERR, pas de levee
              -> CALL _RKRT_WARN (ecriture sur handle 2)

  TODO 23 - MODULES ET USE (module, use, need, is export)
            ParseModuleDecl : module Nom { ... }
              Declarations dans une portee nommee
            use NomModule : importer un module
              Charger les declarations exportees
            need NomModule : charger sans importer dans la portee
            is export : marquer un symbole comme exporte
              sub f() is export { ... } -> PUBLIC en ASM
            Importation selective : use Nom :only<sym1 sym2>
              (simplifie : tout ou rien)
            Modules integres (stubs) :
              use v6; (pragma de version, ignore)
              Modules standard non implementes : avertissement
            Resolution de noms qualifies : Module::Ident
            Tables d importation/exportation : EXTRN et PUBLIC en ASM
            Compilation separee (simplifiee) :
              Un seul fichier source a la fois, les modules importes
              sont declares comme externes

  TODO 24 - RUNTIME MINIMAL
            _RKRT_PRINT(BX=handle, SI=msg, CX=len) : INT 21h AH=40h
            _RKRT_PRINTLN : _RKRT_PRINT + CR+LF via _RK_CRLF DB 13,10,0
            _RKRT_STRLEN(SI=str) : compter octets jusqu a 0 -> AX
            _RKRT_NUMTOSTR(AX=n, DI=buf) : entier signe -> ASCII (itoa)
            _RKRT_STRTONUM(SI=str) : ASCII -> entier -> AX (atoi)
            _RKRT_CONCAT(SI=src1, DI=src2) : concatenation Str -> AX=ptr
            _RKRT_REPEAT(SI=str, CX=count) : repetition x -> AX=ptr
            _RKRT_STRCMP(SI=str1, DI=str2) : comparaison -> drapeaux ZF/CF
            _RKRT_GETLINE(DI=buf, CX=maxlen) : lire ligne STDIN -> AX=len
            _RKRT_NEW(CX=nb_octets) : allocation heap -> AX=ptr objet
            _RKRT_PUSH(BX=arr_ptr, AX=valeur) : empiler dans un tableau
            _RKRT_POP(BX=arr_ptr) : depiler d un tableau -> AX
            _RKRT_HLOOKUP(BX=hash_ptr, SI=clef) : chercher dans hash -> AX
            _RKRT_HSTORE(BX=hash_ptr, SI=clef, AX=valeur) : stocker dans hash
            _RKRT_HKEYS(BX=hash_ptr, DI=buf) : lister les clefs -> AX=count
            _RKRT_WARN(SI=msg) : ecriture sur STDERR (handle 2)
            _RKRT_PANIC(SI=msg) : affiche message + MOV AX,4C01h + INT 21h
            RuntimeEmitted : flag pour n emettre le runtime qu une seule fois
            Heap statique : _RK_HEAP DB 4096 DUP(0) + _RK_HEAPTOP DW 0

  TODO 25 - GENERATION FINALE ET FICHIERS EXEMPLES
            EmitClose : END _RKS_MAIN dans _TEXT ENDS / DATA ENDS
            Run : pipeline complet LexInit -> ParseCompUnit ->
              EmitRuntime -> _TEXT ENDS / EmitDataSeg / END _RKS_MAIN
            Fichiers SAMPLES\RAKU\ a creer :
              hello.raku    (say, print, variables scalaires, Str, Int)
              math.raku     (sub, return, recursion, operateurs)
              control.raku  (if/elsif, unless, given/when, ternaire)
              loops.raku    (for, while, until, loop, last/next/redo)
              arrays.raku   (Array, push, pop, map, grep, sort, join)
              hashes.raku   (Hash, acces, keys, values, exists, delete)
              classes.raku  (class, has, method, new, heritage, .isa)
              roles.raku    (role, does, composition, conflit)
              multi.raku    (multi sub, dispatch, proto)
              grammar.raku  (grammar, token, rule, parse, actions)
              errors.raku   (try, CATCH, die, fail, warn)
              modules.raku  (module, use, is export)
            Smoke tests : RAKU86.EXE -v SAMPLES\RAKU\*.raku

  ============================================================ *)

Program RAKU86;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES GLOBALES
  ============================================================ }
Const
  RAKU86_VERSION = '1.0';
  RAKU86_DATE    = '2026-03-06';

  { Limites des tableaux internes }
  MAX_SYM       = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_LABEL     = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_SCOPE     = {$IFDEF FPC}64{$ELSE}32{$ENDIF};
  MAX_DATA      = {$IFDEF FPC}512{$ELSE}100{$ENDIF};
  MAX_TYPE      = {$IFDEF FPC}32{$ELSE}16{$ENDIF};
  MAX_PARAM     = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_LOOP_NEST = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_ERRORS    = {$IFDEF FPC}30{$ELSE}3{$ENDIF};
  MAX_STR       = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  MAX_MODULE    = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_MULTI     = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_HASH_PAIRS  = 16;
  MAX_HASH_KEYS   = {$IFDEF FPC}512{$ELSE}100{$ENDIF};
  STACK_SIZE      = 1024;

  { Prefixes de nommage ASM }
  RK_VAR_PFX  = '_RKV_';    { variable scalaire/tableau/hash }
  RK_SUB_PFX  = '_RKS_';    { sous-routine sub / method      }
  RK_STR_PFX  = '_RKK_';    { constante chaine               }
  RK_RT_PFX   = '_RKRT_';   { routine runtime                }
  RK_LBL_PFX  = '_RKL_';    { label de saut interne          }
  RK_CLS_PFX  = '_RKC_';    { classe                         }
  RK_ROLE_PFX = '_RKR_';    { role                           }
  RK_GRM_PFX  = '_RKG_';    { grammar                        }

  { Codes de sortie }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Indices de types primitifs Raku }
  TY_IDX_INT     = 0;   { Int : entier signe 16 bits (2 octets)  }
  TY_IDX_BOOL    = 1;   { Bool : True/False (1 octet)            }
  TY_IDX_STR     = 2;   { Str : pointeur chaine (2 octets)       }
  TY_IDX_RAT     = 3;   { Rat : stub entier (2 octets)           }
  TY_IDX_ARRAY   = 4;   { Array : pointeur tableau (2 octets)    }
  TY_IDX_HASH    = 5;   { Hash : pointeur hash (2 octets)        }
  TY_IDX_CODE    = 6;   { Code : pointeur sub/block (2 octets)   }
  TY_IDX_CLASS   = 7;   { objet instance (pointeur 2 octets)     }
  TY_IDX_ROLE    = 8;   { role compose                           }
  TY_IDX_MU      = 9;   { Mu : type racine                       }
  TY_IDX_ANY     = 10;  { Any : sous-type de Mu                  }
  TY_IDX_JUNCTION= 11;  { Junction                               }
  TY_IDX_PAIR    = 12;  { Pair cle=>valeur (4 octets)            }
  TY_IDX_REGEX   = 13;  { Regex                                  }
  TY_IDX_MATCH   = 14;  { Match                                  }
  TY_IDX_NIL     = 15;  { Nil (type indefini)                    }
  TY_PRIM_COUNT  = 16;
  TY_UNKNOWN     = -1;

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String[MAX_STR];

  { ---- Tokens Raku ----------------------------------------- }
  TTokenKind = (
    TK_EOF,         { fin de fichier                       }
    TK_IDENT,       { identificateur                       }
    TK_KEYWORD,     { mot-cle Raku reconnu                 }
    TK_SCALAR,      { variable scalaire $nom               }
    TK_ARRAY_SIG,   { variable tableau @nom                }
    TK_HASH_SIG,    { variable hash %nom                   }
    TK_CODE_SIG,    { variable code &nom                   }
    TK_INTEGER,     { litteral entier                      }
    TK_RATIONAL,    { litteral rationnel / flottant         }
    TK_STRING,      { litteral chaine                      }
    TK_REGEX,       { expression reguliere /pat/           }
    TK_OP,          { operateur                            }
    TK_PUNCT        (* ponctuation () [] ; , -> =>          *)
  );

  TToken = Record
    Kind     : TTokenKind;
    Val      : TString;       { valeur textuelle brute             }
    IntVal   : LongInt;       { valeur entiere (TK_INTEGER)        }
    FloatVal : Real;          { valeur flottante (TK_RATIONAL)     }
    Line     : Integer;       { ligne source (1-base)              }
    Col      : Integer;       { colonne source (1-base)            }
  End;

  { ---- Options de compilation ----------------------------- }
  TOptions = Record
    SrcFile   : TString;   { script source (.raku/.p6)            }
    OutFile   : TString;   { fichier assembleur de sortie (.asm)  }
    Verbose   : Boolean;   { -v : banniere et statistiques        }
    DebugMode : Boolean;   { -d : affichage de chaque token       }
    Warnings  : Boolean;   { -w : activer les avertissements      }
  End;

  { ---- Categories de symboles ----------------------------- }
  TSymCat = (
    SC_MY,           { my $var / my @arr / my %h             }
    SC_OUR,          { our $var (portee package)              }
    SC_HAS,          { has $.attr / has $!attr (attribut)     }
    SC_PARAM,        { parametre de sous-routine              }
    SC_SUB,          { sous-routine (sub)                     }
    SC_METHOD,       { methode (method)                       }
    SC_CLASS,        { class                                  }
    SC_ROLE,         { role                                   }
    SC_MODULE,       { module / package                       }
    SC_CONST         { constant                               }
  );

  TSymRec = Record
    Name        : TString;   { nom sans sigil                  }
    SigilName   : TString;   { nom avec sigil ($x @x %x &x)   }
    MangledName : TString;   { _RKV_x / _RKS_x                }
    Cat         : TSymCat;
    TypeIdx     : Integer;   { indice dans TypeTab             }
    ScopeLevel  : Integer;
    Offset      : Integer;   { [BP-n] pour locaux, DATA sinon  }
    IsExported  : Boolean;   { marque is export                }
    DeclLine    : Integer;
  End;

  { ---- Types internes ------------------------------------- }
  TTypeKind = (
    TYK_INT,
    TYK_BOOL,
    TYK_STR,
    TYK_RAT,
    TYK_ARRAY,
    TYK_HASH,
    TYK_CODE,
    TYK_CLASS,
    TYK_ROLE,
    TYK_MU,
    TYK_ANY,
    TYK_JUNCTION,
    TYK_PAIR,
    TYK_REGEX,
    TYK_MATCH,
    TYK_NIL,
    TYK_UNKNOWN
  );

  TTypeRec = Record
    Name    : TString;
    Kind    : TTypeKind;
    Size    : Integer;   { taille en octets                   }
    ElemIdx : Integer;   { type des elements (TYK_ARRAY)      }
  End;

  { ---- Valeurs d'expression ------------------------------- }
  TExprKind = (
    EK_NONE,   { void / pas de valeur  }
    EK_IMM,    { immediat dans ImmVal  }
    EK_AX,     { valeur dans AX        }
    EK_DXAX,   { valeur longue DX:AX   }
    EK_MEM     { adresse [BP+Offset] ou [_RKV_x] }
  );

  TExprVal = Record
    Kind    : TExprKind;
    ImmVal  : LongInt;
    TypeIdx : Integer;
    Offset  : Integer;
  End;

  { ---- Segment de donnees --------------------------------- }
  TDataKind = (DK_WORD, DK_BYTE, DK_STR, DK_ARRAY_BLK);

  TDataRec = Record
    LblName   : TString;
    Kind      : TDataKind;
    IntVal    : LongInt;
    StrVal    : TString;
    ElemCount : Integer;
  End;

  { ---- Table de hachage (compile-time) ------------------- }
  THashKeyRec = Record
    HashSym : Integer;
    KeyStr  : TString;
    SlotIdx : Integer;
    KeyLbl  : TString;
  End;

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
Var
  { Options }
  Opts : TOptions;

  { Compteurs globaux }
  ErrorCount : Integer;
  WarnCount  : Integer;
  TotalLines : LongInt;
  TotalSyms  : Integer;

  { Valeur fictive pour ignorer un retour TExprVal }
  GExprDummy : TExprVal;

  { Lexeur }
  LexSrcF   : Text;
  LexLine   : String;
  LexLineNo : Integer;
  LexColNo  : Integer;
  LexEOF    : Boolean;
  LexOpened : Boolean;
  CurToken  : TToken;

  { Table des symboles }
  SymTab    : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount  : Integer;
  ScopeStack: Array[0..MAX_SCOPE - 1] Of Integer;
  ScopeTop  : Integer;
  CurScope  : Integer;
  LabelSeq  : Integer;

  { Table des types }
  TypeTab   : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount : Integer;

  { Emetteur ASM }
  OutF         : Text;
  OutFOpen     : Boolean;
  CurFrameSize : Integer;   { taille du cadre local courant        }
  CurFnDepth   : Integer;   { 0 = global, >0 = dans une sub       }
  CurFnRetLbl  : TString;   { label epilogue de la sub courante    }
  CurFnName    : TString;   { nom de la sub courante               }
  LoopTop      : Integer;
  LoopBreakLbl : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopContLbl  : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopRedoLbl  : Array[0..MAX_LOOP_NEST - 1] Of TString;

  { Segment de donnees statiques }
  DataTab   : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount : Integer;

  { Table de hachage compile-time }
  HashKeyTab   : Array[0..MAX_HASH_KEYS - 1] Of THashKeyRec;
  HashKeyCount : Integer;

  { Etat general }
  RuntimeEmitted : Boolean;

  { Modules importes }
  ModuleTab   : Array[0..MAX_MODULE - 1] Of TString;
  ModuleCount : Integer;

  { Drapeau : le mot-clef courant a deja ete consomme }
  GKwConsumed   : Boolean;
  GCallArgCount : Integer;

{ ============================================================
  FORWARD DECLARATIONS
  ============================================================ }
Procedure LexInit;       Forward;
Procedure LexClose;      Forward;
Procedure EmitOpen;      Forward;
Procedure EmitClose;     Forward;
Procedure EmitDataSeg;   Forward;
Procedure EmitRuntime;   Forward;
Procedure EmitHeader;    Forward;
Procedure ParserAdvance; Forward;
Procedure ParseStmt;     Forward;
Procedure TypeInit;      Forward;
Procedure SymInit;       Forward;
Procedure EmitRaw(Const S : TString);       Forward;
Procedure EmitBlankLine;                    Forward;
Procedure EmitComment(Const S : TString);   Forward;
Procedure EmitLabel(Const Name : TString);  Forward;
Procedure EmitInstr(Const Mnem, Ops : TString); Forward;

{ Forward declarations TODO 02 - Lexeur }
Function  IsAlpha(C : Char) : Boolean;                Forward;
Function  IsDigit(C : Char) : Boolean;                Forward;
Function  IsAlNum(C : Char) : Boolean;                Forward;
Function  IsHexDigit(C : Char) : Boolean;             Forward;
Function  HexVal(C : Char) : Integer;                 Forward;
Function  LexCurChar : Char;                          Forward;
Function  LexPeek : Char;                             Forward;
Function  LexPeek2 : Char;                            Forward;
Procedure LexAdvance;                                 Forward;
Procedure LexNextLine;                                Forward;
Procedure LexSkipWS;                                  Forward;
Function  IsRakuKeyword(Const S : TString) : Boolean; Forward;
Procedure PrintToken(Const T : TToken);               Forward;
Procedure LexScanIdent;                               Forward;
Procedure LexScanNumber;                              Forward;
Function  LexScanEscChar : Char;                      Forward;
Procedure LexScanStrSingle;                           Forward;
Procedure LexScanStrDouble;                           Forward;
Procedure LexScanOp;                                  Forward;
Procedure LexScanPunct;                               Forward;
Procedure LexNextToken;                               Forward;

{ Forward declarations TODO 03 - Litteraux et constantes }
Function  IntToStr(N : LongInt) : TString;                        Forward;
Function  LabelGen : TString;                                     Forward;
Function  DataAdd(Const Lbl : TString; Kind : TDataKind;
                  AIntVal : LongInt;
                  Const AStrVal : TString) : Integer;             Forward;
Function  DataAddStr(Const S : TString) : TString;                Forward;
Function  DataAddWord(Const Lbl : TString;
                      AIntVal : LongInt) : Integer;               Forward;
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal);                        Forward;
Procedure ExprMakeNone(Var Res : TExprVal);                       Forward;
Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal);       Forward;
Procedure LitEval(Const T : TToken; Var Res : TExprVal);          Forward;

{ Forward declarations TODO 04 - Operateurs et precedence }
Function  BinOpPrec(Const Op : TString) : Integer;                Forward;
Function  BinOpIsRight(Const Op : TString) : Boolean;             Forward;
Function  IsAssignOp(Const Op : TString) : Boolean;               Forward;
Procedure ExprFlushToAX(Var E : TExprVal);                        Forward;
Procedure ExprEmitBinOp(Const Op : TString;
            Var Left, Right, Res : TExprVal);                     Forward;
Procedure ParsePrimary(Var Res : TExprVal);                       Forward;
Procedure ParseUnary(Var Res : TExprVal);                         Forward;
Procedure ParseExprPrec(MinPrec : Integer;
            Var Res : TExprVal);                                  Forward;
Procedure ParseExpr(Var Res : TExprVal);                          Forward;

{ Forward declarations TODO 05 - Table des symboles }
Function  SymNameClean(Const Name : TString) : TString;           Forward;
Function  SymMangle(Const Name : TString;
                    Cat : TSymCat) : TString;                     Forward;
Function  SymFind(Const SgName : TString) : Integer;              Forward;
Function  SymFindInScope(Const SgName : TString;
                         Level : Integer) : Integer;              Forward;
Function  SymAdd(Const AName : TString;
                 Const ASigil : TString;
                 ACat : TSymCat;
                 ATypeIdx : Integer;
                 AOffset  : Integer) : Integer;                   Forward;
Procedure SymEnterScope;                                          Forward;
Procedure SymLeaveScope;                                          Forward;
Function  SymNextOffset : Integer;                                Forward;

{ Forward declarations TODO 06 - Systeme de types }
Function  TypeKindOf(TypeIdx : Integer) : TTypeKind;              Forward;
Function  TypeSizeof(TypeIdx : Integer) : Integer;                Forward;
Function  TypeMangle(TypeIdx : Integer) : TString;                Forward;
Function  TypeIsNumeric(TypeIdx : Integer) : Boolean;             Forward;
Function  TypeIsPtr(TypeIdx : Integer) : Boolean;                 Forward;
Function  TypeCanCoerce(SrcIdx, DstIdx : Integer) : Boolean;      Forward;
Function  TypeCoerceResult(LeftIdx, RightIdx : Integer;
                           Const Op : TString) : Integer;         Forward;
Function  TypeInfer(Const E : TExprVal) : Integer;                Forward;
Function  TypeLookupName(Const Name : TString) : Integer;         Forward;

{ ============================================================
  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
  ============================================================ }

{ ---- Erreur fatale ---------------------------------------- }
Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('RAKU86: ERREUR FATALE - ', Msg);
  Halt(EXIT_ERROR);
End;

{ ---- Erreur de compilation -------------------------------- }
Procedure CompileError(Const Msg : TString);
Begin
  Write('RAKU86:');
  If CurToken.Line > 0 Then
    Write(Opts.SrcFile, ':', CurToken.Line, ': ');
  WriteLn('error: ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('trop d''erreurs, compilation arretee');
End;

{ ---- Avertissement ---------------------------------------- }
Procedure WarnMsg(Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  Write('RAKU86:');
  If CurToken.Line > 0 Then
    Write(Opts.SrcFile, ':', CurToken.Line, ': ');
  WriteLn('warning: ', Msg);
  Inc(WarnCount);
End;

{ ---- Aide en ligne ---------------------------------------- }
Procedure ShowHelp;
Begin
  WriteLn('RAKU86 - Cette commande permet de lancer le compilateur Raku pour de l''assembleur du microprocesseur ',
          '8086 ou 8088.');
  WriteLn;
  WriteLn('Syntaxe : RAKU86 <source.raku> [sortie.asm] [-v] [-d] [-w]');
  WriteLn;
  WriteLn('  source.raku : fichier source Raku (.raku, .rakumod, .p6, .pm6)');
  WriteLn('  sortie.asm  : fichier assembleur de sortie (defaut: source.asm)');
  WriteLn('  -v          : mode verbeux (banniere + statistiques)');
  WriteLn('  -d          : debug tokens (affiche chaque token)');
  WriteLn('  -w          : activer les avertissements');
  WriteLn('  -h, --help  : cette aide');
  WriteLn;
  Halt(EXIT_OK);
End;

{ ---- Initialisation des options --------------------------- }
Procedure InitOptions;
Begin
  Opts.SrcFile   := '';
  Opts.OutFile   := '';
  Opts.Verbose   := False;
  Opts.DebugMode := False;
  Opts.Warnings  := False;
End;

{ ---- Construction du nom de sortie par defaut ------------- }
Procedure BuildOutName;
Var
  Base : TString;
  I    : Integer;
Begin
  Base := Opts.SrcFile;
  For I := Length(Base) DownTo 1 Do
  Begin
    If Base[I] = '.' Then
    Begin
      Base := Copy(Base, 1, I - 1);
      Break;
    End;
  End;
  Opts.OutFile := Base + '.asm';
End;

{ ---- Analyse des arguments de la ligne de commande -------- }
Procedure ParseArgs;
Var
  I   : Integer;
  Arg : TString;
Begin
  If ParamCount = 0 Then
    ShowHelp;
  I := 1;
  While I <= ParamCount Do
  Begin
    Arg := ParamStr(I);
    If (Arg = '-h') Or (Arg = '--help') Or (Arg = '/?') Then
      ShowHelp
    Else If (Arg = '-v') Or (Arg = '--verbose') Then
      Opts.Verbose := True
    Else If (Arg = '-d') Or (Arg = '--debug') Then
      Opts.DebugMode := True
    Else If (Arg = '-w') Or (Arg = '--warnings') Then
      Opts.Warnings := True
    Else If (Length(Arg) > 0) And (Arg[1] = '-') Then
    Begin
      WriteLn('RAKU86: option inconnue : ', Arg);
      Halt(EXIT_USAGE);
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else If Opts.OutFile = '' Then
      Opts.OutFile := Arg
    Else
    Begin
      WriteLn('RAKU86: argument inattendu : ', Arg);
      Halt(EXIT_USAGE);
    End;
    Inc(I);
  End;
  If Opts.SrcFile = '' Then
  Begin
    WriteLn('RAKU86: aucun fichier source specifie.');
    Halt(EXIT_USAGE);
  End;
  If Opts.OutFile = '' Then
    BuildOutName;
End;

{ ---- Banniere --------------------------------------------- }
Procedure ShowBanner;
Begin
  If Not Opts.Verbose Then Exit;
  WriteLn('================================================');
  WriteLn(' RAKU86 v', RAKU86_VERSION, ' (', RAKU86_DATE, ')');
  WriteLn(' Compilateur Raku -> assembleur 8086 / DOS');
  WriteLn('================================================');
  WriteLn(' Source  : ', Opts.SrcFile);
  WriteLn(' Sortie  : ', Opts.OutFile);
  If Opts.Warnings Then WriteLn(' Mode    : avertissements actifs');
  WriteLn('------------------------------------------------');
End;

{ ---- Statistiques finales --------------------------------- }
Procedure ShowStats;
Begin
  WriteLn('------------------------------------------------');
  WriteLn(' Lignes   : ', TotalLines);
  WriteLn(' Symboles : ', SymCount);
  WriteLn(' Erreurs  : ', ErrorCount);
  WriteLn(' Avert.   : ', WarnCount);
  If ErrorCount = 0 Then
    WriteLn(' Resultat : OK -> ', Opts.OutFile)
  Else
    WriteLn(' Resultat : ECHEC (', ErrorCount, ' erreur(s))');
  WriteLn('================================================');
End;

{ ---- Nettoyage des ressources ----------------------------- }
Procedure Cleanup;
Begin
  LexClose;
  EmitClose;
End;

{ ============================================================
  STUBS (a remplir par les TODOs suivants)
  ============================================================ }

{ ---- TypeInit : initialisation des types primitifs -------- }
Procedure TypeInit;
Var
  I : Integer;
Begin
  TypeCount := 0;
  For I := 0 To MAX_TYPE - 1 Do
  Begin
    TypeTab[I].Name    := '';
    TypeTab[I].Kind    := TYK_UNKNOWN;
    TypeTab[I].Size    := 0;
    TypeTab[I].ElemIdx := TY_UNKNOWN;
  End;
  TypeTab[TY_IDX_INT].Name     := 'Int';
  TypeTab[TY_IDX_INT].Kind     := TYK_INT;
  TypeTab[TY_IDX_INT].Size     := 2;
  TypeTab[TY_IDX_BOOL].Name    := 'Bool';
  TypeTab[TY_IDX_BOOL].Kind    := TYK_BOOL;
  TypeTab[TY_IDX_BOOL].Size    := 1;
  TypeTab[TY_IDX_STR].Name     := 'Str';
  TypeTab[TY_IDX_STR].Kind     := TYK_STR;
  TypeTab[TY_IDX_STR].Size     := 2;
  TypeTab[TY_IDX_RAT].Name     := 'Rat';
  TypeTab[TY_IDX_RAT].Kind     := TYK_RAT;
  TypeTab[TY_IDX_RAT].Size     := 2;
  TypeTab[TY_IDX_ARRAY].Name   := 'Array';
  TypeTab[TY_IDX_ARRAY].Kind   := TYK_ARRAY;
  TypeTab[TY_IDX_ARRAY].Size   := 2;
  TypeTab[TY_IDX_ARRAY].ElemIdx:= TY_IDX_INT;
  TypeTab[TY_IDX_HASH].Name    := 'Hash';
  TypeTab[TY_IDX_HASH].Kind    := TYK_HASH;
  TypeTab[TY_IDX_HASH].Size    := 2;
  TypeTab[TY_IDX_CODE].Name    := 'Code';
  TypeTab[TY_IDX_CODE].Kind    := TYK_CODE;
  TypeTab[TY_IDX_CODE].Size    := 2;
  TypeTab[TY_IDX_CLASS].Name   := 'Class';
  TypeTab[TY_IDX_CLASS].Kind   := TYK_CLASS;
  TypeTab[TY_IDX_CLASS].Size   := 2;
  TypeTab[TY_IDX_ROLE].Name    := 'Role';
  TypeTab[TY_IDX_ROLE].Kind    := TYK_ROLE;
  TypeTab[TY_IDX_ROLE].Size    := 2;
  TypeTab[TY_IDX_MU].Name      := 'Mu';
  TypeTab[TY_IDX_MU].Kind      := TYK_MU;
  TypeTab[TY_IDX_MU].Size      := 2;
  TypeTab[TY_IDX_ANY].Name     := 'Any';
  TypeTab[TY_IDX_ANY].Kind     := TYK_ANY;
  TypeTab[TY_IDX_ANY].Size     := 2;
  TypeTab[TY_IDX_JUNCTION].Name:= 'Junction';
  TypeTab[TY_IDX_JUNCTION].Kind:= TYK_JUNCTION;
  TypeTab[TY_IDX_JUNCTION].Size:= 2;
  TypeTab[TY_IDX_PAIR].Name    := 'Pair';
  TypeTab[TY_IDX_PAIR].Kind    := TYK_PAIR;
  TypeTab[TY_IDX_PAIR].Size    := 4;
  TypeTab[TY_IDX_REGEX].Name   := 'Regex';
  TypeTab[TY_IDX_REGEX].Kind   := TYK_REGEX;
  TypeTab[TY_IDX_REGEX].Size   := 2;
  TypeTab[TY_IDX_MATCH].Name   := 'Match';
  TypeTab[TY_IDX_MATCH].Kind   := TYK_MATCH;
  TypeTab[TY_IDX_MATCH].Size   := 2;
  TypeTab[TY_IDX_NIL].Name     := 'Nil';
  TypeTab[TY_IDX_NIL].Kind     := TYK_NIL;
  TypeTab[TY_IDX_NIL].Size     := 2;
  TypeCount := TY_PRIM_COUNT;
End;

{ ---- SymInit : initialisation de la table des symboles ---- }
Procedure SymInit;
Var
  I : Integer;
Begin
  SymCount     := 0;
  ScopeTop     := 0;
  CurScope     := 0;
  LabelSeq     := 0;
  CurFrameSize := 0;
  CurFnDepth   := 0;
  LoopTop      := 0;
  GKwConsumed  := False;
  CurFnRetLbl  := '';
  CurFnName    := '';
  For I := 0 To MAX_SYM - 1 Do
  Begin
    SymTab[I].Name        := '';
    SymTab[I].SigilName   := '';
    SymTab[I].MangledName := '';
    SymTab[I].Cat         := SC_MY;
    SymTab[I].TypeIdx     := TY_UNKNOWN;
    SymTab[I].ScopeLevel  := 0;
    SymTab[I].Offset      := 0;
    SymTab[I].IsExported  := False;
    SymTab[I].DeclLine    := 0;
  End;
End;

{ ---- Emetteur ASM : stubs de base ------------------------- }
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

Procedure EmitLabel(Const Name : TString);
Begin
  EmitRaw(Name + ':');
End;

Procedure EmitInstr(Const Mnem, Ops : TString);
Begin
  If Ops = '' Then
    EmitRaw('        ' + Mnem)
  Else
    EmitRaw('        ' + Mnem + '  ' + Ops);
End;

Procedure EmitHeader;
Begin
  EmitComment('Generated by RAKU86 v' + RAKU86_VERSION + ' - ' + RAKU86_DATE);
  EmitComment('Source : ' + Opts.SrcFile);
  EmitBlankLine;
  EmitRaw('        .MODEL  SMALL');
  EmitRaw('        .STACK  1024');
  EmitBlankLine;
  EmitRaw('_TEXT   SEGMENT WORD PUBLIC ''CODE''');
  EmitRaw('        ASSUME  CS:_TEXT, DS:_DATA');
  EmitBlankLine;
  EmitRaw('_RKS_MAIN PROC NEAR');
  EmitInstr('MOV', 'AX, @DATA');
  EmitInstr('MOV', 'DS, AX');
  EmitBlankLine;
End;

Procedure EmitOpen;
Begin
  Assign(OutF, Opts.OutFile);
  Rewrite(OutF);
  If IOResult <> 0 Then
    FatalError('Impossible d''ouvrir le fichier de sortie : ' + Opts.OutFile);
  OutFOpen := True;
  EmitHeader;
End;

Procedure EmitRuntime;
Begin
  If RuntimeEmitted Then Exit;
  RuntimeEmitted := True;
  EmitBlankLine;
  EmitComment('=== Runtime RAKU86 (stub) ===');
  EmitBlankLine;
End;

Procedure EmitDataSeg;
Var
  I   : Integer;
  Tmp : TString;
Begin
  EmitRaw('_DATA   SEGMENT WORD PUBLIC ''DATA''');
  { Buffer de travail pour concatenation de chaines }
  EmitRaw('_RK_STRBUF  DB  256 DUP(0)');
  If DataCount = 0 Then
    EmitRaw('; (aucune donnee utilisateur)')
  Else
    For I := 0 To DataCount - 1 Do
    Begin
      Case DataTab[I].Kind Of
        DK_WORD :
        Begin
          Str(DataTab[I].IntVal, Tmp);
          EmitRaw(DataTab[I].LblName + '  DW  ' + Tmp);
        End;
        DK_BYTE :
        Begin
          Str(DataTab[I].IntVal, Tmp);
          EmitRaw(DataTab[I].LblName + '  DB  ' + Tmp);
        End;
        DK_STR :
          EmitRaw(DataTab[I].LblName + '  DB  ''' +
                  DataTab[I].StrVal + ''', 0');
        DK_ARRAY_BLK :
        Begin
          Str(DataTab[I].ElemCount, Tmp);
          EmitRaw(DataTab[I].LblName + '  DW  ' + Tmp + ' DUP(0)');
        End;
      End;
    End;
  EmitRaw('_DATA   ENDS');
End;

Procedure EmitClose;
Begin
  If Not OutFOpen Then Exit;
  EmitBlankLine;
  EmitComment('Fin du script Raku - sortie implicite code 0');
  EmitInstr('MOV', 'AX, 4C00h');
  EmitInstr('INT', '21h');
  EmitRaw('_RKS_MAIN ENDP');
  EmitBlankLine;
  EmitRuntime;
  EmitRaw('_TEXT   ENDS');
  EmitBlankLine;
  EmitDataSeg;
  EmitBlankLine;
  EmitRaw('        END     _RKS_MAIN');
  Close(OutF);
  OutFOpen := False;
End;

{ ============================================================
  TODO 02 - LEXEUR (TOKENS RAKU) [IMPLEMENTE]
  ============================================================ }

{ ---- Fonctions auxiliaires de classification --------------- }
Function IsAlpha(C : Char) : Boolean;
Begin
  IsAlpha := ((C >= 'a') And (C <= 'z')) Or
             ((C >= 'A') And (C <= 'Z')) Or (C = '_') Or (C = '-');
End;

Function IsDigit(C : Char) : Boolean;
Begin
  IsDigit := (C >= '0') And (C <= '9');
End;

Function IsAlNum(C : Char) : Boolean;
Begin
  IsAlNum := ((C >= 'a') And (C <= 'z')) Or
             ((C >= 'A') And (C <= 'Z')) Or
             ((C >= '0') And (C <= '9')) Or (C = '_');
End;

Function IsHexDigit(C : Char) : Boolean;
Begin
  IsHexDigit := IsDigit(C) Or
                ((C >= 'a') And (C <= 'f')) Or
                ((C >= 'A') And (C <= 'F'));
End;

Function HexVal(C : Char) : Integer;
Begin
  If (C >= '0') And (C <= '9') Then
    HexVal := Ord(C) - Ord('0')
  Else If (C >= 'a') And (C <= 'f') Then
    HexVal := Ord(C) - Ord('a') + 10
  Else
    HexVal := Ord(C) - Ord('A') + 10;
End;

Function IsIdentStart(C : Char) : Boolean;
Begin
  IsIdentStart := ((C >= 'a') And (C <= 'z')) Or
                  ((C >= 'A') And (C <= 'Z')) Or (C = '_');
End;

Function IsIdentCont(C : Char) : Boolean;
Begin
  IsIdentCont := ((C >= 'a') And (C <= 'z')) Or
                 ((C >= 'A') And (C <= 'Z')) Or
                 ((C >= '0') And (C <= '9')) Or
                 (C = '_') Or (C = '-');
End;

{ ---- Position dans la ligne source ------------------------- }
Function LexCurChar : Char;
Begin
  If (LexEOF) Or (LexColNo > Length(LexLine)) Then
    LexCurChar := #0
  Else
    LexCurChar := LexLine[LexColNo];
End;

Function LexPeek : Char;
Begin
  If (LexEOF) Or (LexColNo + 1 > Length(LexLine)) Then
    LexPeek := #0
  Else
    LexPeek := LexLine[LexColNo + 1];
End;

Function LexPeek2 : Char;
Begin
  If (LexEOF) Or (LexColNo + 2 > Length(LexLine)) Then
    LexPeek2 := #0
  Else
    LexPeek2 := LexLine[LexColNo + 2];
End;

Procedure LexAdvance;
Begin
  Inc(LexColNo);
End;

{ ---- LexNextLine : lire la ligne suivante ------------------ }
Procedure LexNextLine;
Begin
  If EOF(LexSrcF) Then
  Begin
    LexEOF   := True;
    LexLine  := '';
    LexColNo := 1;
  End Else
  Begin
    ReadLn(LexSrcF, LexLine);
    Inc(LexLineNo);
    Inc(TotalLines);
    LexColNo := 1;
  End;
End;

{ ---- LexSkipWS : sauter blancs, tabs et commentaires ------- }
Procedure LexSkipWS;
Var
  C     : Char;
  Depth : Integer;
Begin
  Repeat
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
      LexNextLine;
    If LexEOF Then Exit;
    C := LexCurChar;
    If (C = ' ') Or (C = #9) Or (C = #13) Or (C = #10) Then
      LexAdvance
    Else If C = '#' Then
    Begin
      { Commentaire bloc : #`( ... ) avec imbrication }
      If (LexPeek = '`') And (LexPeek2 = '(') Then
      Begin
        LexAdvance; LexAdvance; LexAdvance; { sauter #`( }
        Depth := 1;
        While (Not LexEOF) And (Depth > 0) Do
        Begin
          If LexColNo > Length(LexLine) Then
            LexNextLine
          Else
          Begin
            C := LexCurChar;
            If C = '(' Then Inc(Depth)
            Else If C = ')' Then Dec(Depth);
            LexAdvance;
          End;
        End;
      End
      Else
      Begin
        { Commentaire ligne : # jusqu en fin de ligne }
        LexColNo := Length(LexLine) + 1;
        LexNextLine;
      End;
    End
    Else
      Exit;
  Until False;
End;

{ ---- Table des mots-cles Raku ----------------------------- }
Const
  RAKU_KW_COUNT = 60;
  RAKU_KW : Array[0..59] Of String[14] = (
    { Declarateurs }
    'my',       'our',       'has',       'constant',
    { Sous-routines et methodes }
    'sub',      'method',    'return',    'multi',
    'proto',    'only',
    { Classes, roles, modules }
    'class',    'role',      'module',    'grammar',
    'is',       'does',      'of',        'returns',
    'where',    'new',       'self',
    { Modules }
    'use',      'need',
    { Controle de flux }
    'if',       'elsif',     'else',      'unless',
    'given',    'when',      'default',   'with',
    'without',
    { Boucles }
    'for',      'loop',      'while',     'until',
    'repeat',   'do',        'gather',    'take',
    'last',     'next',      'redo',
    { Erreurs }
    'try',      'die',       'fail',      'warn',
    { Logique basse precedence }
    'not',      'and',       'or',
    { Comparaison chaine }
    'eq',       'ne',        'lt',        'le',
    'gt',       'ge',        'leg',       'cmp',
    { Operateur de contexte }
    'so',
    { Operateur de repetition }
    'x'
  );

Function IsRakuKeyword(Const S : TString) : Boolean;
Var
  I : Integer;
Begin
  IsRakuKeyword := False;
  For I := 0 To RAKU_KW_COUNT - 1 Do
    If S = RAKU_KW[I] Then
    Begin IsRakuKeyword := True; Exit; End;
End;

{ ---- PrintToken : affichage debug d un token --------------- }
Procedure PrintToken(Const T : TToken);
Var
  KS : String[12];
  NS : TString;
Begin
  Case T.Kind Of
    TK_IDENT      : KS := 'IDENT   ';
    TK_KEYWORD    : KS := 'KEYWORD ';
    TK_SCALAR     : KS := 'SCALAR$ ';
    TK_ARRAY_SIG  : KS := 'ARRAY@  ';
    TK_HASH_SIG   : KS := 'HASH%   ';
    TK_CODE_SIG   : KS := 'CODE&   ';
    TK_INTEGER    : KS := 'INTEGER ';
    TK_RATIONAL   : KS := 'RATIONAL';
    TK_STRING     : KS := 'STRING  ';
    TK_REGEX      : KS := 'REGEX   ';
    TK_OP         : KS := 'OP      ';
    TK_PUNCT      : KS := 'PUNCT   ';
    TK_EOF        : KS := 'EOF     ';
  End;
  Write('[', T.Line, ':', T.Col, '] ', KS, ' "', T.Val, '"');
  If T.Kind = TK_INTEGER Then
  Begin Str(T.IntVal, NS); Write(' =', NS); End
  Else If T.Kind = TK_RATIONAL Then
  Begin Str(T.FloatVal : 0 : 6, NS); Write(' =', NS); End;
  WriteLn;
End;

{ ---- LexScanIdent : identificateur ou mot-cle Raku --------- }
Procedure LexScanIdent;
Var
  S : TString;
Begin
  S := '';
  While (LexColNo <= Length(LexLine)) And IsIdentCont(LexLine[LexColNo]) Do
  Begin
    { Le tiret ne peut pas etre le dernier caractere d un ident }
    If (LexLine[LexColNo] = '-') Then
    Begin
      If (LexColNo + 1 <= Length(LexLine)) And
         IsIdentCont(LexLine[LexColNo + 1]) And
         (LexLine[LexColNo + 1] <> '-') Then
      Begin
        If Length(S) < MAX_STR Then S := S + LexLine[LexColNo];
        Inc(LexColNo);
      End
      Else
        Break;
    End
    Else
    Begin
      If Length(S) < MAX_STR Then S := S + LexLine[LexColNo];
      Inc(LexColNo);
    End;
  End;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
  { Constantes speciales }
  If (S = 'True') Or (S = 'False') Or (S = 'Nil') Or
     (S = 'Mu') Or (S = 'Any') Then
  Begin
    CurToken.Kind := TK_KEYWORD;
    If S = 'True'  Then CurToken.IntVal := 1
    Else                 CurToken.IntVal := 0;
  End
  Else If IsRakuKeyword(S) Then
    CurToken.Kind := TK_KEYWORD
  Else
    CurToken.Kind := TK_IDENT;
End;

{ ---- LexScanNumber : entier, hexadecimal, octal, binaire --- }
{ Raku : 0xFF hex, 0o77 octal, 0b1010 binaire, 1_000 seps     }
Procedure LexScanNumber;
Var
  S     : TString;
  Val   : LongInt;
  Base  : Integer;
  C     : Char;
  Fv    : Real;
  Div10 : Real;
Begin
  S    := '';
  Val  := 0;
  Base := 10;
  C    := LexCurChar;
  If (C = '0') And (LexPeek <> #0) Then
  Begin
    Case LexPeek Of
      'x','X': Begin S := '0x'; LexAdvance; LexAdvance; Base := 16; End;
      'o','O': Begin S := '0o'; LexAdvance; LexAdvance; Base := 8;  End;
      'b','B': Begin S := '0b'; LexAdvance; LexAdvance; Base := 2;  End;
    Else
      Val := 0;
      S   := '0';
      LexAdvance;
    End;
  End Else
  Begin
    Val := Ord(C) - Ord('0');
    S   := C;
    LexAdvance;
  End;
  While (Not LexEOF) And (LexColNo <= Length(LexLine)) Do
  Begin
    C := LexCurChar;
    If C = '_' Then Begin LexAdvance; Continue; End;
    Case Base Of
      2  : If (C = '0') Or (C = '1') Then
           Begin
             Val := Val * 2 + (Ord(C) - Ord('0'));
             If Length(S) < MAX_STR Then S := S + C;
             LexAdvance;
           End
           Else Break;
      8  : If (C >= '0') And (C <= '7') Then
           Begin
             Val := Val * 8 + (Ord(C) - Ord('0'));
             If Length(S) < MAX_STR Then S := S + C;
             LexAdvance;
           End
           Else Break;
      10 : If IsDigit(C) Then
           Begin
             Val := Val * 10 + (Ord(C) - Ord('0'));
             If Length(S) < MAX_STR Then S := S + C;
             LexAdvance;
           End
           Else Break;
      16 : If IsHexDigit(C) Then
           Begin
             Val := Val * 16 + HexVal(C);
             If Length(S) < MAX_STR Then S := S + C;
             LexAdvance;
           End
           Else Break;
    End;
  End;
  { Detection rationnel / flottant (base 10 uniquement) }
  If (Base = 10) And (Not LexEOF) And (LexColNo <= Length(LexLine)) And
     (LexCurChar = '.') And IsDigit(LexPeek) Then
  Begin
    Fv    := Val * 1.0;
    Div10 := 10.0;
    If Length(S) < MAX_STR Then S := S + '.';
    LexAdvance;
    While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
          (IsDigit(LexCurChar) Or (LexCurChar = '_')) Do
    Begin
      If LexCurChar <> '_' Then
      Begin
        Fv    := Fv + (Ord(LexCurChar) - Ord('0')) / Div10;
        Div10 := Div10 * 10.0;
        If Length(S) < MAX_STR Then S := S + LexCurChar;
      End;
      LexAdvance;
    End;
    CurToken.Kind     := TK_RATIONAL;
    CurToken.Val      := S;
    CurToken.IntVal   := Round(Fv);
    CurToken.FloatVal := Fv;
    Exit;
  End;
  CurToken.Kind   := TK_INTEGER;
  CurToken.Val    := S;
  CurToken.IntVal := Val;
End;

{ ---- LexScanEscChar : sequence d echappement --------------- }
{ Raku : \n \t \r \0 \\ \" \' \a \e \x[NN] \o[NN]            }
Function LexScanEscChar : Char;
Var
  C    : Char;
  Code : LongInt;
Begin
  Code := 0;
  If LexColNo > Length(LexLine) Then
  Begin
    LexScanEscChar := '?';
    Exit;
  End;
  C := LexCurChar;
  LexAdvance;
  Case C Of
    'n' : LexScanEscChar := #10;
    't' : LexScanEscChar := #9;
    'r' : LexScanEscChar := #13;
    'a' : LexScanEscChar := #7;
    'e' : LexScanEscChar := #27;
    '0' : LexScanEscChar := #0;
    '\' : LexScanEscChar := '\';
    '"' : LexScanEscChar := '"';
    '''': LexScanEscChar := '''';
    '$' : LexScanEscChar := '$';
    '@' : LexScanEscChar := '@';
    '%' : LexScanEscChar := '%';
    'x' : Begin
            { \x[NN] ou \xNN }
            Code := 0;
            If (LexColNo <= Length(LexLine)) And (LexCurChar = '[') Then
            Begin
              LexAdvance;
              While (LexColNo <= Length(LexLine)) And
                    (LexCurChar <> ']') And IsHexDigit(LexCurChar) Do
              Begin
                Code := Code * 16 + HexVal(LexCurChar);
                LexAdvance;
              End;
              If (LexColNo <= Length(LexLine)) And (LexCurChar = ']') Then
                LexAdvance;
            End Else
            Begin
              If (LexColNo <= Length(LexLine)) And IsHexDigit(LexCurChar) Then
              Begin
                Code := HexVal(LexCurChar); LexAdvance;
                If (LexColNo <= Length(LexLine)) And IsHexDigit(LexCurChar) Then
                Begin Code := Code * 16 + HexVal(LexCurChar); LexAdvance; End;
              End;
            End;
            LexScanEscChar := Chr(Code And $FF);
          End;
    'o' : Begin
            { \o[NN] }
            Code := 0;
            If (LexColNo <= Length(LexLine)) And (LexCurChar = '[') Then
            Begin
              LexAdvance;
              While (LexColNo <= Length(LexLine)) And
                    (LexCurChar <> ']') And
                    (LexCurChar >= '0') And (LexCurChar <= '7') Do
              Begin
                Code := Code * 8 + (Ord(LexCurChar) - Ord('0'));
                LexAdvance;
              End;
              If (LexColNo <= Length(LexLine)) And (LexCurChar = ']') Then
                LexAdvance;
            End;
            LexScanEscChar := Chr(Code And $FF);
          End;
  Else
    LexScanEscChar := C;
  End;
End;

{ ---- LexScanStrSingle : chaine entre apostrophes ----------- }
{ Raku : 'abc' - pas d interpolation, seuls \\ et \' echappes }
Procedure LexScanStrSingle;
Var
  S    : TString;
  C    : Char;
  Done : Boolean;
Begin
  LexAdvance; { consommer le guillemet-simple ouverture }
  S    := '';
  Done := False;
  Repeat
    If LexColNo > Length(LexLine) Then
    Begin
      If LexEOF Then
      Begin
        CompileError('Chaine simple-quote non fermee');
        Done := True;
      End Else
      Begin
        If Length(S) < MAX_STR Then S := S + #10;
        LexNextLine;
      End;
    End Else
    Begin
      C := LexCurChar;
      If C = '''' Then
      Begin
        LexAdvance; Done := True;
      End Else If C = '\' Then
      Begin
        LexAdvance;
        If (LexColNo <= Length(LexLine)) And
           ((LexCurChar = '''') Or (LexCurChar = '\')) Then
        Begin
          If Length(S) < MAX_STR Then S := S + LexCurChar;
          LexAdvance;
        End Else
          If Length(S) < MAX_STR Then S := S + '\';
      End Else
      Begin
        If Length(S) < MAX_STR Then S := S + C;
        LexAdvance;
      End;
    End;
  Until Done;
  CurToken.Kind   := TK_STRING;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
End;

{ ---- LexScanStrDouble : chaine entre guillemets doubles ---- }
{ Raku : "abc" - interpolation $var avec marqueurs #1 #2       }
Procedure LexScanStrDouble;
Var
  S    : TString;
  C    : Char;
  VN   : TString;
  Done : Boolean;
Begin
  LexAdvance; { consommer le guillemet-double ouverture }
  S    := '';
  Done := False;
  Repeat
    If LexColNo > Length(LexLine) Then
    Begin
      If LexEOF Then
      Begin
        CompileError('Chaine double-quote non fermee');
        Done := True;
      End Else
      Begin
        If Length(S) < MAX_STR Then S := S + #10;
        LexNextLine;
      End;
    End Else
    Begin
      C := LexCurChar;
      If C = '"' Then
      Begin
        LexAdvance; Done := True;
      End Else If C = '\' Then
      Begin
        LexAdvance;
        C := LexScanEscChar;
        If Length(S) < MAX_STR Then S := S + C;
      End Else If C = '$' Then
      Begin
        { Interpolation $var }
        LexAdvance;
        VN := '';
        While (LexColNo <= Length(LexLine)) And IsAlNum(LexCurChar) Do
        Begin
          If Length(VN) < 30 Then VN := VN + LexCurChar;
          LexAdvance;
        End;
        If VN <> '' Then
        Begin
          If Length(S) < MAX_STR Then S := S + #1;
          If Length(S) + Length(VN) <= MAX_STR Then S := S + VN;
          If Length(S) < MAX_STR Then S := S + #2;
        End Else
          If Length(S) < MAX_STR Then S := S + '$';
      End Else If C = '@' Then
      Begin
        { Interpolation @arr }
        LexAdvance;
        VN := '';
        While (LexColNo <= Length(LexLine)) And IsAlNum(LexCurChar) Do
        Begin
          If Length(VN) < 30 Then VN := VN + LexCurChar;
          LexAdvance;
        End;
        If VN <> '' Then
        Begin
          If Length(S) < MAX_STR Then S := S + #3;
          If Length(S) + Length(VN) <= MAX_STR Then S := S + VN;
          If Length(S) < MAX_STR Then S := S + #4;
        End Else
          If Length(S) < MAX_STR Then S := S + '@';
      End Else
      Begin
        If Length(S) < MAX_STR Then S := S + C;
        LexAdvance;
      End;
    End;
  Until Done;
  CurToken.Kind   := TK_STRING;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
End;

{ ---- LexScanOp : operateurs Raku (simples et composes) ----- }
Procedure LexScanOp;
Var
  S  : TString;
  C  : Char;
  P  : Char;
  P2 : Char;
Begin
  C  := LexCurChar;
  P  := LexPeek;
  P2 := LexPeek2;
  S  := C;
  LexAdvance;
  Case C Of
    '+': If P = '+' Then Begin S := '++'; LexAdvance; End
         Else If P = '=' Then Begin S := '+='; LexAdvance; End;
    '-': If P = '-' Then Begin S := '--'; LexAdvance; End
         Else If P = '>' Then Begin S := '->'; LexAdvance; End
         Else If P = '=' Then Begin S := '-='; LexAdvance; End;
    '*': If P = '*' Then
         Begin
           S := '**'; LexAdvance;
           If LexCurChar = '=' Then Begin S := '**='; LexAdvance; End;
         End
         Else If P = '=' Then Begin S := '*='; LexAdvance; End;
    '/': If P = '/' Then
         Begin
           S := '//'; LexAdvance;
           If LexCurChar = '=' Then Begin S := '//='; LexAdvance; End;
         End
         Else If P = '=' Then Begin S := '/='; LexAdvance; End;
    '~': If P = '~' Then Begin S := '~~'; LexAdvance; End
         Else If P = '=' Then Begin S := '~='; LexAdvance; End;
    '!': If P = '=' Then
         Begin
           S := '!='; LexAdvance;
           If LexCurChar = '=' Then Begin S := '!=='; LexAdvance; End;
         End
         Else If P = '~' Then Begin S := '!~'; LexAdvance; End
         Else If P = '!' Then Begin S := '!!'; LexAdvance; End;
    '=': If P = '=' Then
         Begin
           S := '=='; LexAdvance;
           If LexCurChar = '=' Then Begin S := '==='; LexAdvance; End;
         End
         Else If P = '>' Then Begin S := '=>'; LexAdvance; End;
    '<': If (P = '=') And (P2 = '>') Then
         Begin S := '<=>'; LexAdvance; LexAdvance; End
         Else If P = '=' Then Begin S := '<='; LexAdvance; End
         Else If P = '<' Then Begin S := '<<'; LexAdvance; End;
    '>': If P = '=' Then Begin S := '>='; LexAdvance; End
         Else If P = '>' Then Begin S := '>>'; LexAdvance; End;
    '&': If P = '&' Then Begin S := '&&'; LexAdvance; End;
    '|': If P = '|' Then Begin S := '||'; LexAdvance; End;
    '^': If P = '^' Then Begin S := '^^'; LexAdvance; End;
    '?': If P = '?' Then Begin S := '??'; LexAdvance; End;
    '%': If P = '%' Then Begin S := '%%'; LexAdvance; End
         Else If P = '=' Then Begin S := '%='; LexAdvance; End;
    ':': If P = '=' Then Begin S := ':='; LexAdvance; End;
    '.': If P = '.' Then
         Begin
           S := '..'; LexAdvance;
           If LexCurChar = '^' Then Begin S := '..^'; LexAdvance; End;
         End
         Else If P = '=' Then Begin S := '.='; LexAdvance; End;
  End;
  CurToken.Kind   := TK_OP;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
End;

{ ---- LexScanPunct : caractere de ponctuation --------------- }
Procedure LexScanPunct;
Begin
  CurToken.Kind   := TK_PUNCT;
  CurToken.Val    := LexCurChar;
  CurToken.IntVal := 0;
  LexAdvance;
End;

{ ---- LexNextToken : scanner principal ---------------------- }
Procedure LexNextToken;
Var
  C  : Char;
  S  : TString;
  SL : Integer;
  SC : Integer;
Begin
  CurToken.IntVal   := 0;
  CurToken.FloatVal := 0.0;

  LexSkipWS;

  If LexEOF Or (LexColNo > Length(LexLine)) Then
  Begin
    CurToken.Kind   := TK_EOF;
    CurToken.Val    := '';
    CurToken.Line   := LexLineNo;
    CurToken.Col    := LexColNo;
    Exit;
  End;

  SL := LexLineNo;
  SC := LexColNo;
  C  := LexCurChar;

  CurToken.Line := SL;
  CurToken.Col  := SC;

  { Sigil $ : variable scalaire ou variable speciale }
  If C = '$' Then
  Begin
    LexAdvance;
    S := '';
    { Twigils : $. $! $* $? $^ }
    If (LexColNo <= Length(LexLine)) And
       ((LexCurChar = '.') Or (LexCurChar = '!') Or
        (LexCurChar = '*') Or (LexCurChar = '?') Or
        (LexCurChar = '^')) Then
    Begin
      S := LexCurChar;
      LexAdvance;
      While (LexColNo <= Length(LexLine)) And IsAlNum(LexCurChar) Do
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
    End
    Else If (LexColNo <= Length(LexLine)) And IsIdentStart(LexCurChar) Then
    Begin
      While (LexColNo <= Length(LexLine)) And IsAlNum(LexCurChar) Do
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
    End
    Else If (LexColNo <= Length(LexLine)) And (LexCurChar = '/') Then
    Begin
      { $/ : Match variable }
      S := '/';
      LexAdvance;
    End;
    CurToken.Kind   := TK_SCALAR;
    CurToken.Val    := S;
    CurToken.IntVal := 0;
    Exit;
  End;

  { Sigil @ : variable tableau }
  If C = '@' Then
  Begin
    If IsIdentStart(LexPeek) Or (LexPeek = '*') Or (LexPeek = '!') Or
       (LexPeek = '.') Or (LexPeek = '?') Or (LexPeek = '^') Then
    Begin
      LexAdvance;
      S := '';
      If (LexColNo <= Length(LexLine)) And
         ((LexCurChar = '.') Or (LexCurChar = '!') Or
          (LexCurChar = '*') Or (LexCurChar = '?') Or
          (LexCurChar = '^')) Then
      Begin
        S := LexCurChar;
        LexAdvance;
      End;
      While (LexColNo <= Length(LexLine)) And IsAlNum(LexCurChar) Do
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
      CurToken.Kind   := TK_ARRAY_SIG;
      CurToken.Val    := S;
      CurToken.IntVal := 0;
      Exit;
    End;
  End;

  { Sigil % : variable hash }
  If C = '%' Then
  Begin
    If IsIdentStart(LexPeek) Or (LexPeek = '*') Or (LexPeek = '!') Or
       (LexPeek = '.') Or (LexPeek = '?') Or (LexPeek = '^') Then
    Begin
      LexAdvance;
      S := '';
      If (LexColNo <= Length(LexLine)) And
         ((LexCurChar = '.') Or (LexCurChar = '!') Or
          (LexCurChar = '*') Or (LexCurChar = '?') Or
          (LexCurChar = '^')) Then
      Begin
        S := LexCurChar;
        LexAdvance;
      End;
      While (LexColNo <= Length(LexLine)) And IsAlNum(LexCurChar) Do
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
      CurToken.Kind   := TK_HASH_SIG;
      CurToken.Val    := S;
      CurToken.IntVal := 0;
      Exit;
    End;
    { Sinon : operateur %% ou % }
    LexScanOp;
    Exit;
  End;

  { Sigil & : variable code }
  If C = '&' Then
  Begin
    If IsIdentStart(LexPeek) Then
    Begin
      LexAdvance;
      S := '';
      While (LexColNo <= Length(LexLine)) And IsAlNum(LexCurChar) Do
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
      CurToken.Kind   := TK_CODE_SIG;
      CurToken.Val    := S;
      CurToken.IntVal := 0;
      Exit;
    End;
    { Sinon : operateur && }
    LexScanOp;
    Exit;
  End;

  { Identificateur ou mot-cle }
  If IsIdentStart(C) Then
  Begin
    LexScanIdent;
    Exit;
  End;

  { Litteraux numeriques }
  If IsDigit(C) Then
  Begin
    LexScanNumber;
    Exit;
  End;

  { Chaine simple-quote }
  If C = '''' Then
  Begin
    LexScanStrSingle;
    Exit;
  End;

  { Chaine double-quote }
  If C = '"' Then
  Begin
    LexScanStrDouble;
    Exit;
  End;

  { Operateurs }
  Case C Of
    '+','-','*','/','~',
    '!','=','<','>','^','|','?',':','.':
    Begin
      LexScanOp;
      Exit;
    End;
  End;

  { Backslash : operateur unaire ou contexte }
  If C = '\' Then
  Begin
    LexScanOp;
    Exit;
  End;

  { Ponctuation }
  Case C Of
    ';',',','(',')','[',']','{','}':
    Begin
      LexScanPunct;
      Exit;
    End;
  End;

  { Caractere inconnu : consommer et emettre TK_PUNCT }
  CurToken.Kind   := TK_PUNCT;
  CurToken.Val    := C;
  CurToken.IntVal := 0;
  LexAdvance;
End;

{ ---- LexInit : ouvrir le fichier et initialiser le lexeur -- }
Procedure LexInit;
Begin
  LexOpened := False;
  Assign(LexSrcF, Opts.SrcFile);
  Reset(LexSrcF);
  If IOResult <> 0 Then
    FatalError('Impossible d''ouvrir: ' + Opts.SrcFile);
  LexOpened := True;
  LexEOF    := False;
  LexLineNo := 0;
  LexColNo  := 1;
  LexLine   := '';
  LexNextLine;
  { Shebang : ignorer la premiere ligne si #!/... }
  If (Length(LexLine) >= 2) And
     (LexLine[1] = '#') And (LexLine[2] = '!') Then
    LexNextLine;
End;

{ ---- LexClose : fermer le fichier source ------------------- }
Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
End;

{ ---- ParserAdvance : lire le prochain token --------------- }
Procedure ParserAdvance;
Begin
  LexNextToken;
End;

{ ============================================================
  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
  ============================================================ }

{ ---- IntToStr : conversion entier -> chaine ---------------- }
Function IntToStr(N : LongInt) : TString;
Var
  S : TString;
Begin
  Str(N, S);
  IntToStr := S;
End;

{ ---- LabelGen : generateur de labels uniques --------------- }
Function LabelGen : TString;
Begin
  Inc(LabelSeq);
  LabelGen := RK_LBL_PFX + IntToStr(LabelSeq);
End;

{ ---- DataAdd : ajouter une entree dans DataTab ------------- }
Function DataAdd(Const Lbl : TString; Kind : TDataKind;
                 AIntVal : LongInt;
                 Const AStrVal : TString) : Integer;
Begin
  If DataCount >= MAX_DATA Then
  Begin
    CompileError('segment DATA plein (max=' + IntToStr(MAX_DATA) + ')');
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

{ ---- DataAddStr : creer un label _RKK_N et stocker chaine -- }
{ Retourne le label genere.                                     }
Function DataAddStr(Const S : TString) : TString;
Var
  Lbl : TString;
Begin
  Inc(LabelSeq);
  Lbl := RK_STR_PFX + IntToStr(LabelSeq);
  DataAdd(Lbl, DK_STR, 0, S);
  DataAddStr := Lbl;
End;

{ ---- DataAddWord : ajouter un mot 16 bits dans DataTab ----- }
Function DataAddWord(Const Lbl : TString;
                     AIntVal : LongInt) : Integer;
Begin
  DataAddWord := DataAdd(Lbl, DK_WORD, AIntVal, '');
End;

{ ---- ExprMakeImm : construire une valeur immediate --------- }
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := AVal;
  Res.TypeIdx := ATypeIdx;
  Res.Offset  := 0;
End;

{ ---- ExprMakeNone : valeur invalide (void/erreur) ---------- }
Procedure ExprMakeNone(Var Res : TExprVal);
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_UNKNOWN;
  Res.Offset  := 0;
End;

{ ---- ExprMakeBool : valeur booleenne (True=1, False=0) ----- }
Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  If AVal <> 0 Then Res.ImmVal := 1
               Else Res.ImmVal := 0;
  Res.TypeIdx := TY_IDX_BOOL;
  Res.Offset  := 0;
End;

{ ---- LitEval : evaluer un token litteral en TExprVal ------- }
{ Gere : TK_INTEGER, TK_RATIONAL (tronque avec avertissement), }
{        TK_STRING (chaine -> DataAddStr), TK_KEYWORD           }
{        (True/False/Nil/Inf/NaN).                              }
Procedure LitEval(Const T : TToken; Var Res : TExprVal);
Var
  Lbl : TString;
Begin
  ExprMakeNone(Res);

  Case T.Kind Of
    { --- Entiers decimaux / hex / octal / binaire --- }
    TK_INTEGER :
    Begin
      Res.Kind    := EK_IMM;
      Res.ImmVal  := T.IntVal;
      Res.TypeIdx := TY_IDX_INT;
    End;

    { --- Rationnels (tronques a entier avec avertissement) --- }
    TK_RATIONAL :
    Begin
      WarnMsg('litteral rationnel tronque a entier (Rat -> Int)');
      Res.Kind    := EK_IMM;
      Res.ImmVal  := Trunc(T.FloatVal);
      Res.TypeIdx := TY_IDX_RAT;
    End;

    { --- Chaines (simple ou double quote) -> DATA segment --- }
    TK_STRING :
    Begin
      Lbl := DataAddStr(T.Val);
      Res.Kind    := EK_IMM;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_STR;
      { On stocke le label comme offset symbolique ; le code   }
      { generateur utilisera MOV AX, OFFSET <lbl> pour charger }
    End;

    { --- Mots-cles booleens et constantes speciales --- }
    TK_KEYWORD :
    Begin
      If T.Val = 'True' Then
        ExprMakeBool(1, Res)
      Else If T.Val = 'False' Then
        ExprMakeBool(0, Res)
      Else If T.Val = 'Nil' Then
        ExprMakeImm(0, TY_IDX_NIL, Res)
      Else If T.Val = 'Mu' Then
        ExprMakeImm(0, TY_IDX_MU, Res)
      Else If T.Val = 'Any' Then
        ExprMakeImm(0, TY_IDX_ANY, Res)
      Else If T.Val = 'Inf' Then
      Begin
        WarnMsg('Inf non supporte sur 8086, utilise 32767');
        ExprMakeImm(32767, TY_IDX_INT, Res);
      End
      Else If T.Val = 'NaN' Then
      Begin
        WarnMsg('NaN non supporte sur 8086, utilise 0');
        ExprMakeImm(0, TY_IDX_INT, Res);
      End
      Else
        ExprMakeNone(Res);
    End;
  Else
    ExprMakeNone(Res);
  End;
End;

{ ============================================================
  TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
  ============================================================ }

{ ---- BinOpPrec : precedence d'un operateur binaire Raku ---- }
{ Retourne 0 si ce n'est pas un operateur binaire infix.       }
{ Niveaux de precedence (plus le chiffre est eleve, plus       }
{ l'operateur est prioritaire) :                                }
{  1  and or not xor (basse precedence)                        }
{  2  = := += -= *= /= ~= x= (affectation)                    }
{  3  ?? !! (ternaire conditionnel)                             }
{  4  || // (or logique haute, defined-or)                      }
{  5  && (and logique haute)                                    }
{  6  ~~ (smart match)                                          }
{  7  == != < <= > >= <=> eq ne lt le gt ge leg cmp             }
{  8  .. ..^ ^.. ^..^ (intervalles)                             }
{  9  x (repetition chaine)                                     }
{ 10  + - ~ (addition, soustraction, concat binaire)            }
{ 11  * / div mod %% (multiplication, division)                 }
{ 12  ** (puissance, assoc droite)                              }
Function BinOpPrec(Const Op : TString) : Integer;
Begin
  { Prec 1 : and or not xor (basse precedence) }
  If (Op = 'and') Or (Op = 'or') Or (Op = 'xor') Then
  Begin BinOpPrec := 1; Exit; End;
  { Prec 2 : affectations }
  If (Op = '=')  Or (Op = ':=') Or
     (Op = '+=') Or (Op = '-=') Or (Op = '*=') Or (Op = '/=') Or
     (Op = '~=') Or (Op = 'x=') Then
  Begin BinOpPrec := 2; Exit; End;
  { Prec 3 : ternaire ?? !! traite directement dans ParseExprPrec }
  { Prec 4 : || // }
  If (Op = '||') Or (Op = '//') Then
  Begin BinOpPrec := 4; Exit; End;
  { Prec 5 : && }
  If Op = '&&' Then
  Begin BinOpPrec := 5; Exit; End;
  { Prec 6 : ~~ smart match }
  If Op = '~~' Then
  Begin BinOpPrec := 6; Exit; End;
  { Prec 7 : comparaisons numeriques et chaines }
  If (Op = '==')  Or (Op = '!=')  Or (Op = '<')  Or (Op = '<=') Or
     (Op = '>')   Or (Op = '>=')  Or (Op = '<=>') Or
     (Op = 'eq')  Or (Op = 'ne')  Or (Op = 'lt') Or (Op = 'le') Or
     (Op = 'gt')  Or (Op = 'ge')  Or (Op = 'leg') Or (Op = 'cmp') Then
  Begin BinOpPrec := 7; Exit; End;
  { Prec 8 : intervalles }
  If (Op = '..') Or (Op = '..^') Or (Op = '^..') Or (Op = '^..^') Then
  Begin BinOpPrec := 8; Exit; End;
  { Prec 9 : x (repetition) }
  If Op = 'x' Then
  Begin BinOpPrec := 9; Exit; End;
  { Prec 10 : + - ~ (binaire) }
  If (Op = '+') Or (Op = '-') Or (Op = '~') Then
  Begin BinOpPrec := 10; Exit; End;
  { Prec 11 : * / div mod %% }
  If (Op = '*') Or (Op = '/') Or (Op = 'div') Or (Op = 'mod') Or
     (Op = '%%') Then
  Begin BinOpPrec := 11; Exit; End;
  { Prec 12 : ** (puissance, assoc droite) }
  If Op = '**' Then
  Begin BinOpPrec := 12; Exit; End;
  BinOpPrec := 0;
End;

{ ---- BinOpIsRight : operateur associatif a droite ? --------- }
{ En Raku : = := += etc. et ** sont associatifs a droite        }
Function BinOpIsRight(Const Op : TString) : Boolean;
Begin
  BinOpIsRight :=
    (Op = '=')  Or (Op = ':=') Or
    (Op = '+=') Or (Op = '-=') Or (Op = '*=') Or (Op = '/=') Or
    (Op = '~=') Or (Op = 'x=') Or (Op = '**');
End;

{ ---- IsAssignOp : est-ce un operateur d'affectation ? ------- }
Function IsAssignOp(Const Op : TString) : Boolean;
Begin
  IsAssignOp :=
    (Op = '=')  Or (Op = ':=') Or
    (Op = '+=') Or (Op = '-=') Or (Op = '*=') Or (Op = '/=') Or
    (Op = '~=') Or (Op = 'x=');
End;

{ ---- ExprFlushToAX : charger une TExprVal dans AX ---------- }
{ Si deja EK_AX, ne rien faire. Si EK_IMM, emet MOV AX, val.  }
{ Si EK_MEM, charge selon le mode.                              }
Procedure ExprFlushToAX(Var E : TExprVal);
Var
  S : TString;
Begin
  Case E.Kind Of
    EK_IMM :
    Begin
      Str(E.ImmVal, S);
      EmitInstr('MOV', 'AX, ' + S);
    End;
    EK_MEM :
    Begin
      If E.ImmVal = 1 Then
      Begin
        Str(E.Offset, S);
        EmitInstr('MOV', 'AX, WORD PTR [BP-' + S + ']');
      End
      Else If (E.Offset >= 0) And (E.Offset < DataCount) Then
      Begin
        If DataTab[E.Offset].Kind = DK_STR Then
          EmitInstr('MOV', 'AX, OFFSET ' + DataTab[E.Offset].LblName)
        Else
          EmitInstr('MOV', 'AX, [' + DataTab[E.Offset].LblName + ']');
      End
      Else
        EmitInstr('MOV', 'AX, 0');
    End;
    EK_AX   : ;
    EK_DXAX : ;
    EK_NONE : ;
  End;
  E.Kind := EK_AX;
End;

{ ---- ExprEmitBinOp : code ASM pour un operateur binaire ---- }
{ Convention : BX=Left, AX=Right pour les ops non-affectation.  }
{   Affectations : Left=EK_MEM lvalue, AX=Right valeur          }
{   &&, ||, // : traites directement dans ParseExprPrec          }
Procedure ExprEmitBinOp(Const Op : TString;
                         Var Left, Right, Res : TExprVal);
Var
  LblA : TString;
  LblB : TString;
  LblC : TString;
Begin
  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_INT;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  { ==============================================================
    Affectation simple '=' et ':=' : stub (pas de table de symboles)
    ============================================================== }
  If (Op = '=') Or (Op = ':=') Then
  Begin
    EmitComment(Op + ' : affectation (stub)');
    Exit;
  End;
  { ==============================================================
    Affectations composees : stub
    ============================================================== }
  If (Op = '+=') Or (Op = '-=') Or (Op = '*=') Or (Op = '/=') Or
     (Op = '~=') Or (Op = 'x=') Then
  Begin
    EmitComment(Op + ' : affectation composee (stub)');
    Exit;
  End;
  { ==============================================================
    Operateurs arithmetiques : BX=Left, AX=Right
    ============================================================== }
  If Op = '+' Then
  Begin EmitInstr('ADD', 'AX, BX'); Exit; End;
  If Op = '-' Then
  Begin
    EmitInstr('XCHG', 'AX, BX');
    EmitInstr('SUB', 'AX, BX');
    Exit;
  End;
  If Op = '*' Then
  Begin EmitInstr('IMUL', 'BX'); Exit; End;
  If (Op = '/') Or (Op = 'div') Then
  Begin
    EmitInstr('XCHG', 'AX, BX');
    EmitInstr('CWD', '');
    EmitInstr('IDIV', 'BX');
    Exit;
  End;
  If (Op = 'mod') Or (Op = '%%') Then
  Begin
    EmitInstr('XCHG', 'AX, BX');
    EmitInstr('CWD', '');
    EmitInstr('IDIV', 'BX');
    If Op = '%%' Then
    Begin
      { %% : divisible -> DX=0 ? }
      EmitInstr('TEST', 'DX, DX');
      EmitInstr('SETE', 'AL');
      EmitInstr('MOVZX', 'AX, AL');
      Res.TypeIdx := TY_IDX_BOOL;
    End
    Else
      EmitInstr('MOV', 'AX, DX');
    Exit;
  End;
  If Op = '**' Then
  Begin
    EmitComment('** : puissance (stub)');
    EmitInstr('MOV', 'AX, 1');
    Exit;
  End;
  { ==============================================================
    Concatenation ~ et repetition x
    ============================================================== }
  If Op = '~' Then
  Begin
    EmitComment('~ : concatenation (stub CALL _RKRT_CONCAT)');
    Exit;
  End;
  If Op = 'x' Then
  Begin
    EmitComment('x : repetition (stub CALL _RKRT_STRREPEAT)');
    Exit;
  End;
  { ==============================================================
    Comparaisons numeriques : BX=Left, AX=Right
    ============================================================== }
  If Op = '==' Then
  Begin
    EmitInstr('CMP', 'BX, AX');
    EmitInstr('SETE', 'AL');
    EmitInstr('MOVZX', 'AX, AL');
    Res.TypeIdx := TY_IDX_BOOL;
    Exit;
  End;
  If Op = '!=' Then
  Begin
    EmitInstr('CMP', 'BX, AX');
    EmitInstr('SETNE', 'AL');
    EmitInstr('MOVZX', 'AX, AL');
    Res.TypeIdx := TY_IDX_BOOL;
    Exit;
  End;
  If Op = '<' Then
  Begin
    EmitInstr('CMP', 'BX, AX');
    EmitInstr('SETL', 'AL');
    EmitInstr('MOVZX', 'AX, AL');
    Res.TypeIdx := TY_IDX_BOOL;
    Exit;
  End;
  If Op = '<=' Then
  Begin
    EmitInstr('CMP', 'BX, AX');
    EmitInstr('SETLE', 'AL');
    EmitInstr('MOVZX', 'AX, AL');
    Res.TypeIdx := TY_IDX_BOOL;
    Exit;
  End;
  If Op = '>' Then
  Begin
    EmitInstr('CMP', 'BX, AX');
    EmitInstr('SETG', 'AL');
    EmitInstr('MOVZX', 'AX, AL');
    Res.TypeIdx := TY_IDX_BOOL;
    Exit;
  End;
  If Op = '>=' Then
  Begin
    EmitInstr('CMP', 'BX, AX');
    EmitInstr('SETGE', 'AL');
    EmitInstr('MOVZX', 'AX, AL');
    Res.TypeIdx := TY_IDX_BOOL;
    Exit;
  End;
  If Op = '<=>' Then
  Begin
    { Three-way : BX=Left, AX=Right -> AX = -1/0/+1 }
    LblA := LabelGen;
    LblB := LabelGen;
    LblC := LabelGen;
    EmitInstr('CMP', 'BX, AX');
    EmitInstr('JL', LblA);
    EmitInstr('JE', LblB);
    EmitInstr('MOV', 'AX, 1');
    EmitInstr('JMP', LblC);
    EmitLabel(LblA);
    EmitInstr('MOV', 'AX, 0FFFFh');
    EmitInstr('JMP', LblC);
    EmitLabel(LblB);
    EmitInstr('XOR', 'AX, AX');
    EmitLabel(LblC);
    Exit;
  End;
  { ==============================================================
    Comparaisons de chaines : eq ne lt le gt ge leg cmp
    ============================================================== }
  If (Op = 'eq') Or (Op = 'ne') Or (Op = 'lt') Or (Op = 'le') Or
     (Op = 'gt') Or (Op = 'ge') Or (Op = 'leg') Or (Op = 'cmp') Then
  Begin
    EmitComment(Op + ' : comparaison chaine (stub CALL _RKRT_STRCMP)');
    EmitInstr('XOR', 'AX, AX');
    Res.TypeIdx := TY_IDX_BOOL;
    Exit;
  End;
  { ==============================================================
    Smart match ~~
    ============================================================== }
  If Op = '~~' Then
  Begin
    EmitComment('~~ : smart match (stub)');
    EmitInstr('XOR', 'AX, AX');
    Res.TypeIdx := TY_IDX_BOOL;
    Exit;
  End;
  { ==============================================================
    Logiques basse precedence : and or xor
    ============================================================== }
  If Op = 'and' Then
  Begin
    EmitInstr('TEST', 'BX, BX');
    EmitInstr('SETNE', 'BL');
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('SETNE', 'AL');
    EmitInstr('AND', 'AL, BL');
    EmitInstr('MOVZX', 'AX, AL');
    Res.TypeIdx := TY_IDX_BOOL;
    Exit;
  End;
  If Op = 'or' Then
  Begin
    EmitInstr('TEST', 'BX, BX');
    EmitInstr('SETNE', 'BL');
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('SETNE', 'AL');
    EmitInstr('OR', 'AL, BL');
    EmitInstr('MOVZX', 'AX, AL');
    Res.TypeIdx := TY_IDX_BOOL;
    Exit;
  End;
  If Op = 'xor' Then
  Begin
    EmitInstr('TEST', 'BX, BX');
    EmitInstr('SETNE', 'BL');
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('SETNE', 'AL');
    EmitInstr('XOR', 'AL, BL');
    EmitInstr('MOVZX', 'AX, AL');
    Res.TypeIdx := TY_IDX_BOOL;
    Exit;
  End;
  { ==============================================================
    Intervalles .. ..^ ^.. ^..^ : stub
    ============================================================== }
  If (Op = '..') Or (Op = '..^') Or (Op = '^..') Or (Op = '^..^') Then
  Begin
    EmitComment(Op + ' : intervalle (stub)');
    Exit;
  End;
  { Operateur inconnu }
  EmitComment('ExprEmitBinOp : operateur non gere : ' + Op);
End;

{ ---- ParsePrimary : expression primaire (atome) ------------ }
{ Gere : litteraux, variables $/@/%/&, parens, not/so/True/etc }
Procedure ParsePrimary(Var Res : TExprVal);
Var
  Sub : TExprVal;
Begin
  ExprMakeNone(Res);
  { --- Litteraux entiers --- }
  If CurToken.Kind = TK_INTEGER Then
  Begin
    LitEval(CurToken, Res);
    ParserAdvance;
    Exit;
  End;
  { --- Litteraux rationnels --- }
  If CurToken.Kind = TK_RATIONAL Then
  Begin
    LitEval(CurToken, Res);
    ParserAdvance;
    Exit;
  End;
  { --- Litteraux chaines --- }
  If CurToken.Kind = TK_STRING Then
  Begin
    LitEval(CurToken, Res);
    ParserAdvance;
    Exit;
  End;
  { --- Variables scalaires $nom --- }
  If CurToken.Kind = TK_SCALAR Then
  Begin
    EmitComment('$' + CurToken.Val + ' (variable scalaire, stub)');
    ExprMakeImm(0, TY_IDX_INT, Res);
    ParserAdvance;
    Exit;
  End;
  { --- Variables tableau @nom --- }
  If CurToken.Kind = TK_ARRAY_SIG Then
  Begin
    EmitComment('@' + CurToken.Val + ' (variable tableau, stub)');
    ExprMakeImm(0, TY_IDX_ARRAY, Res);
    ParserAdvance;
    Exit;
  End;
  { --- Variables hash %nom --- }
  If CurToken.Kind = TK_HASH_SIG Then
  Begin
    EmitComment('%' + CurToken.Val + ' (variable hash, stub)');
    ExprMakeImm(0, TY_IDX_HASH, Res);
    ParserAdvance;
    Exit;
  End;
  { --- Variables code &nom --- }
  If CurToken.Kind = TK_CODE_SIG Then
  Begin
    EmitComment('&' + CurToken.Val + ' (variable code, stub)');
    ExprMakeImm(0, TY_IDX_CODE, Res);
    ParserAdvance;
    Exit;
  End;
  { --- Mots-cles : True, False, Nil, Mu, Any, Inf, NaN --- }
  If CurToken.Kind = TK_KEYWORD Then
  Begin
    If (CurToken.Val = 'True')  Or (CurToken.Val = 'False') Or
       (CurToken.Val = 'Nil')   Or (CurToken.Val = 'Mu')    Or
       (CurToken.Val = 'Any')   Or (CurToken.Val = 'Inf')   Or
       (CurToken.Val = 'NaN') Then
    Begin
      LitEval(CurToken, Res);
      ParserAdvance;
      Exit;
    End;
    { --- not (basse precedence, prefix) --- }
    If CurToken.Val = 'not' Then
    Begin
      ParserAdvance;
      ParseUnary(Sub);
      ExprFlushToAX(Sub);
      EmitInstr('TEST', 'AX, AX');
      EmitInstr('SETE', 'AL');
      EmitInstr('MOVZX', 'AX, AL');
      Res.Kind := EK_AX;
      Res.TypeIdx := TY_IDX_BOOL;
      Exit;
    End;
    { --- so (coercion booleenne) --- }
    If CurToken.Val = 'so' Then
    Begin
      ParserAdvance;
      ParseUnary(Sub);
      ExprFlushToAX(Sub);
      EmitInstr('TEST', 'AX, AX');
      EmitInstr('SETNE', 'AL');
      EmitInstr('MOVZX', 'AX, AL');
      Res.Kind := EK_AX;
      Res.TypeIdx := TY_IDX_BOOL;
      Exit;
    End;
    { Mot-cle non reconnu comme primaire : stub }
    EmitComment('keyword ' + CurToken.Val + ' (stub)');
    ExprMakeImm(0, TY_IDX_INT, Res);
    ParserAdvance;
    Exit;
  End;
  { --- Identificateur libre --- }
  If CurToken.Kind = TK_IDENT Then
  Begin
    EmitComment('ident ' + CurToken.Val + ' (stub)');
    ExprMakeImm(0, TY_IDX_INT, Res);
    ParserAdvance;
    Exit;
  End;
  { --- Parentheses --- }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
  Begin
    ParserAdvance;
    ParseExpr(Res);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance
    Else
      CompileError(''')'' attendue');
    Exit;
  End;
  { Token non reconnu comme expression primaire }
  If CurToken.Kind <> TK_EOF Then
  Begin
    CompileError('expression attendue, lu : ''' + CurToken.Val + '''');
    ParserAdvance;
  End;
End;

{ ---- ParseUnary : expression unaire prefixe/postfixe ------- }
{ Prefixes :  ! + - ~ ? (haute precedence)                     }
{             ++ -- (pre-increment/decrement)                   }
{ Postfixes : ++ -- (post-increment/decrement)                 }
Procedure ParseUnary(Var Res : TExprVal);
Var
  Op  : TString;
  Sub : TExprVal;
Begin
  ExprMakeNone(Res);
  { --- Operateurs unaires prefixes --- }
  If CurToken.Kind = TK_OP Then
  Begin
    Op := CurToken.Val;
    { Negation logique ! }
    If Op = '!' Then
    Begin
      ParserAdvance;
      ParseUnary(Sub);
      ExprFlushToAX(Sub);
      EmitInstr('TEST', 'AX, AX');
      EmitInstr('SETE', 'AL');
      EmitInstr('MOVZX', 'AX, AL');
      Res.Kind := EK_AX;
      Res.TypeIdx := TY_IDX_BOOL;
      Exit;
    End;
    { Plus unaire + (noop numerique) }
    If Op = '+' Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      Exit;
    End;
    { Moins unaire - (negation) }
    If Op = '-' Then
    Begin
      ParserAdvance;
      ParseUnary(Sub);
      ExprFlushToAX(Sub);
      EmitInstr('NEG', 'AX');
      Res.Kind := EK_AX;
      Res.TypeIdx := TY_IDX_INT;
      Exit;
    End;
    { Coercion chaine ~ }
    If Op = '~' Then
    Begin
      ParserAdvance;
      ParseUnary(Sub);
      ExprFlushToAX(Sub);
      EmitComment('~expr : coercion chaine (stub)');
      Res.Kind := EK_AX;
      Res.TypeIdx := TY_IDX_STR;
      Exit;
    End;
    { Coercion booleenne ? }
    If Op = '?' Then
    Begin
      ParserAdvance;
      ParseUnary(Sub);
      ExprFlushToAX(Sub);
      EmitInstr('TEST', 'AX, AX');
      EmitInstr('SETNE', 'AL');
      EmitInstr('MOVZX', 'AX, AL');
      Res.Kind := EK_AX;
      Res.TypeIdx := TY_IDX_BOOL;
      Exit;
    End;
    { Pre-increment ++ }
    If Op = '++' Then
    Begin
      ParserAdvance;
      ParsePrimary(Sub);
      ExprFlushToAX(Sub);
      EmitInstr('INC', 'AX');
      EmitComment('++expr : pre-increment (stub store)');
      Res.Kind := EK_AX;
      Res.TypeIdx := TY_IDX_INT;
      Exit;
    End;
    { Pre-decrement -- }
    If Op = '--' Then
    Begin
      ParserAdvance;
      ParsePrimary(Sub);
      ExprFlushToAX(Sub);
      EmitInstr('DEC', 'AX');
      EmitComment('--expr : pre-decrement (stub store)');
      Res.Kind := EK_AX;
      Res.TypeIdx := TY_IDX_INT;
      Exit;
    End;
  End;
  { --- Pas d'unaire prefixe : appeler ParsePrimary --- }
  ParsePrimary(Res);
  { --- Post-increment ++ --- }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '++') Then
  Begin
    ExprFlushToAX(Res);
    EmitComment('expr++ : post-increment (stub store)');
    EmitInstr('INC', 'AX');
    Res.Kind := EK_AX;
    Res.TypeIdx := TY_IDX_INT;
    ParserAdvance;
  End
  { --- Post-decrement -- --- }
  Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '--') Then
  Begin
    ExprFlushToAX(Res);
    EmitComment('expr-- : post-decrement (stub store)');
    EmitInstr('DEC', 'AX');
    Res.Kind := EK_AX;
    Res.TypeIdx := TY_IDX_INT;
    ParserAdvance;
  End;
End;

{ ---- CurTokIsInfixOp : le token courant est un op binaire ? - }
{ Detecte les operateurs et mots-cles infix de Raku.             }
Function CurTokIsInfixOp(Var Op : TString) : Boolean;
Begin
  CurTokIsInfixOp := False;
  Op := '';
  If CurToken.Kind = TK_OP Then
  Begin
    Op := CurToken.Val;
    If BinOpPrec(Op) > 0 Then
    Begin CurTokIsInfixOp := True; Exit; End;
    Op := '';
  End
  Else If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
  Begin
    If (CurToken.Val = 'and') Or (CurToken.Val = 'or') Or
       (CurToken.Val = 'xor') Or (CurToken.Val = 'x')  Or
       (CurToken.Val = 'div') Or (CurToken.Val = 'mod') Or
       (CurToken.Val = 'eq')  Or (CurToken.Val = 'ne')  Or
       (CurToken.Val = 'lt')  Or (CurToken.Val = 'le')  Or
       (CurToken.Val = 'gt')  Or (CurToken.Val = 'ge')  Or
       (CurToken.Val = 'leg') Or (CurToken.Val = 'cmp') Then
    Begin
      Op := CurToken.Val;
      CurTokIsInfixOp := True;
      Exit;
    End;
  End;
End;

{ ---- ParseExprPrec : coeur du parseur Pratt ---------------- }
{ Convention BX=Left, AX=Right pour les ops non-affectation.    }
{ Court-circuit inline pour && || //.                           }
{ Ternaire ?? !! avec labels _RKL_N.                            }
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal);
Var
  Op    : TString;
  Prec  : Integer;
  Right : TExprVal;
  Left  : TExprVal;
  CondT : TExprVal;
  LblA  : TString;
  LblB  : TString;
Begin
  ParseUnary(Left);
  Res := Left;
  Repeat
    { ---- Ternaire ?? !! : traitement special ---- }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '??') And
       (MinPrec <= 3) Then
    Begin
      ParserAdvance;
      ExprFlushToAX(Left);
      LblA := LabelGen;
      LblB := LabelGen;
      EmitInstr('TEST', 'AX, AX');
      EmitInstr('JZ', LblA);
      ParseExprPrec(1, CondT);
      ExprFlushToAX(CondT);
      EmitInstr('JMP', LblB);
      EmitLabel(LblA);
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '!!') Then
        ParserAdvance
      Else
        CompileError('''!!'' attendu apres ''??''');
      ParseExprPrec(3, Right);
      ExprFlushToAX(Right);
      EmitLabel(LblB);
      Res.Kind := EK_AX;
      Res.TypeIdx := TY_IDX_INT;
      Res.ImmVal := 0;
      Res.Offset := 0;
      Left := Res;
      Continue;
    End;
    { ---- Operateur binaire standard ---- }
    If Not CurTokIsInfixOp(Op) Then Break;
    Prec := BinOpPrec(Op);
    If Prec < MinPrec Then Break;
    ParserAdvance;
    { ---- Court-circuit && (and haute prec) ---- }
    If Op = '&&' Then
    Begin
      ExprFlushToAX(Left);
      LblA := LabelGen;
      LblB := LabelGen;
      EmitInstr('TEST', 'AX, AX');
      EmitInstr('JZ', LblA);
      ParseExprPrec(Prec + 1, Right);
      ExprFlushToAX(Right);
      EmitInstr('JMP', LblB);
      EmitLabel(LblA);
      EmitInstr('XOR', 'AX, AX');
      EmitLabel(LblB);
      Res.Kind := EK_AX;
      Res.TypeIdx := TY_IDX_BOOL;
      Res.ImmVal := 0;
      Res.Offset := 0;
      Left := Res;
      Continue;
    End;
    { ---- Court-circuit || ---- }
    If Op = '||' Then
    Begin
      ExprFlushToAX(Left);
      LblA := LabelGen;
      LblB := LabelGen;
      EmitInstr('TEST', 'AX, AX');
      EmitInstr('JNZ', LblA);
      ParseExprPrec(Prec + 1, Right);
      ExprFlushToAX(Right);
      EmitInstr('JMP', LblB);
      EmitLabel(LblA);
      EmitLabel(LblB);
      Res.Kind := EK_AX;
      Res.TypeIdx := TY_IDX_INT;
      Res.ImmVal := 0;
      Res.Offset := 0;
      Left := Res;
      Continue;
    End;
    { ---- Court-circuit // (defined-or) ---- }
    If Op = '//' Then
    Begin
      ExprFlushToAX(Left);
      LblA := LabelGen;
      EmitInstr('TEST', 'AX, AX');
      EmitInstr('JNZ', LblA);
      ParseExprPrec(Prec + 1, Right);
      ExprFlushToAX(Right);
      EmitLabel(LblA);
      Res.Kind := EK_AX;
      Res.TypeIdx := TY_IDX_INT;
      Res.ImmVal := 0;
      Res.Offset := 0;
      Left := Res;
      Continue;
    End;
    { ---- Affectations (prec=2) : garder Left en EK_MEM ---- }
    If Prec = 2 Then
    Begin
      ParseExprPrec(Prec, Right);
      ExprFlushToAX(Right);
      ExprEmitBinOp(Op, Left, Right, Res);
      Left := Res;
      Continue;
    End;
    { ---- Autres operateurs binaires : BX=Left, AX=Right ---- }
    If BinOpIsRight(Op) Then ParseExprPrec(Prec, Right)
    Else ParseExprPrec(Prec + 1, Right);
    ExprFlushToAX(Left);
    EmitInstr('PUSH', 'AX');
    ExprFlushToAX(Right);
    EmitInstr('POP', 'BX');
    ExprEmitBinOp(Op, Left, Right, Res);
    Left := Res;
  Until False;
  Res := Left;
End;

{ ---- ParseExpr : point d'entree principal des expressions --- }
Procedure ParseExpr(Var Res : TExprVal);
Begin
  ParseExprPrec(1, Res);
End;

{ ============================================================
  TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
  ============================================================ }

{ ---- SymNameClean : nettoyer un nom pour usage ASM ---------- }
{ Remplace les caracteres non-alphanumeriques par '_'.          }
{ Raku permet des noms avec tirets (kebab-case) et apostrophes. }
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
      R := R + C
    Else
      R := R + '_';
  End;
  SymNameClean := R;
End;

{ ---- SymMangle : generer un label ASM pour un symbole ------- }
{ Le prefixe depend de la categorie du symbole :                }
{   SC_MY / SC_OUR / SC_HAS / SC_PARAM / SC_CONST -> _RKV_     }
{   SC_SUB / SC_METHOD                             -> _RKS_     }
{   SC_CLASS                                       -> _RKC_     }
{   SC_ROLE                                        -> _RKR_     }
{   SC_MODULE                                      -> _RKV_     }
Function SymMangle(Const Name : TString;
                   Cat : TSymCat) : TString;
Var
  Pfx   : TString;
  Clean : TString;
Begin
  Clean := SymNameClean(Name);
  Case Cat Of
    SC_MY     : Pfx := RK_VAR_PFX;
    SC_OUR    : Pfx := RK_VAR_PFX;
    SC_HAS    : Pfx := RK_VAR_PFX;
    SC_PARAM  : Pfx := RK_VAR_PFX;
    SC_CONST  : Pfx := RK_VAR_PFX;
    SC_SUB    : Pfx := RK_SUB_PFX;
    SC_METHOD : Pfx := RK_SUB_PFX;
    SC_CLASS  : Pfx := RK_CLS_PFX;
    SC_ROLE   : Pfx := RK_ROLE_PFX;
    SC_MODULE : Pfx := RK_VAR_PFX;
  Else
    Pfx := RK_VAR_PFX;
  End;
  SymMangle := Pfx + Clean;
End;

{ ---- SymFind : chercher un symbole par nom avec sigil ------- }
{ En Raku, $x, @x, %x, &x sont des symboles distincts.         }
{ La recherche se fait sur SigilName (nom complet avec sigil).  }
{ Parcourt du plus recent au plus ancien pour le shadowing.     }
Function SymFind(Const SgName : TString) : Integer;
Var
  I : Integer;
Begin
  For I := SymCount - 1 DownTo 0 Do
    If SymTab[I].SigilName = SgName Then
    Begin
      SymFind := I;
      Exit;
    End;
  SymFind := -1;
End;

{ ---- SymFindInScope : recherche dans une portee specifique -- }
{ Cherche un symbole dans le scope donne uniquement.            }
Function SymFindInScope(Const SgName : TString;
                        Level : Integer) : Integer;
Var
  I : Integer;
Begin
  For I := SymCount - 1 DownTo 0 Do
    If (SymTab[I].SigilName = SgName) And
       (SymTab[I].ScopeLevel = Level) Then
    Begin
      SymFindInScope := I;
      Exit;
    End;
  SymFindInScope := -1;
End;

{ ---- SymAdd : ajouter un symbole dans la table -------------- }
{ AName    = nom sans sigil (ex: 'x')                           }
{ ASigil   = sigil ($, @, %, &, ou '' pour sub/class/etc.)      }
{ SigilName est construit : ASigil + AName                      }
{ Retourne l index du symbole (0-base) ou -1 si plein.          }
Function SymAdd(Const AName : TString;
                Const ASigil : TString;
                ACat : TSymCat;
                ATypeIdx : Integer;
                AOffset  : Integer) : Integer;
Var
  Idx  : Integer;
  SgNm : TString;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    CompileError('table des symboles pleine (max=' +
                 IntToStr(MAX_SYM) + ')');
    SymAdd := -1;
    Exit;
  End;
  Idx := SymCount;
  SgNm := ASigil + AName;
  SymTab[Idx].Name        := AName;
  SymTab[Idx].SigilName   := SgNm;
  SymTab[Idx].MangledName := SymMangle(AName, ACat);
  SymTab[Idx].Cat         := ACat;
  SymTab[Idx].TypeIdx     := ATypeIdx;
  SymTab[Idx].ScopeLevel  := CurScope;
  SymTab[Idx].Offset      := AOffset;
  SymTab[Idx].IsExported  := False;
  SymTab[Idx].DeclLine    := CurToken.Line;

  If Opts.DebugMode Then
    WriteLn('  SYM_ADD[', Idx, ']: ', SgNm,
            ' cat=', Ord(ACat),
            ' scope=', CurScope,
            ' offset=', AOffset,
            ' -> ', SymTab[Idx].MangledName);

  SymAdd := Idx;
  Inc(SymCount);
  Inc(TotalSyms);
End;

{ ---- SymEnterScope : entrer dans une nouvelle portee -------- }
{ Chaque bloc, sub, class, etc. cree une nouvelle portee.       }
{ Empile SymCount pour pouvoir retirer les symboles au retour.  }
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

{ ---- SymLeaveScope : quitter la portee courante ------------- }
{ Les symboles locaux de cette portee sont retires de la table. }
Procedure SymLeaveScope;
Begin
  If ScopeTop <= 0 Then
  Begin
    CompileError('SymLeaveScope : pas de scope a quitter');
    Exit;
  End;
  Dec(ScopeTop);
  SymCount := ScopeStack[ScopeTop];
  Dec(CurScope);
  If Opts.DebugMode Then
    WriteLn('  SCOPE_LEAVE: level=', CurScope);
End;

{ ---- SymNextOffset : prochain offset local [BP-n] ----------- }
{ Alloue 2 octets (mot 16 bits) sur le cadre de pile courant.  }
Function SymNextOffset : Integer;
Begin
  Inc(CurFrameSize, 2);
  SymNextOffset := CurFrameSize;
End;

{ ============================================================
  TODO 06 - SYSTEME DE TYPES [IMPLEMENTE]
  ============================================================ }

{ ---- TypeKindOf : retourner le TTypeKind d un index --------- }
{ Si l index est invalide, retourne TYK_UNKNOWN.                }
Function TypeKindOf(TypeIdx : Integer) : TTypeKind;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeKindOf := TypeTab[TypeIdx].Kind
  Else
    TypeKindOf := TYK_UNKNOWN;
End;

{ ---- TypeSizeof : taille en octets d un type par index ------ }
{ En architecture 16 bits, la plupart des valeurs sont dans     }
{ un mot (2 octets). Bool est 1 octet, Pair est 4 octets       }
{ (cle + valeur). Defaut = 2.                                   }
Function TypeSizeof(TypeIdx : Integer) : Integer;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeSizeof := TypeTab[TypeIdx].Size
  Else
    TypeSizeof := 2;
End;

{ ---- TypeMangle : prefixe ASM selon le type pour les labels - }
{ Permet de generer des noms de labels typees dans le code ASM. }
Function TypeMangle(TypeIdx : Integer) : TString;
Var
  K : TTypeKind;
Begin
  K := TypeKindOf(TypeIdx);
  Case K Of
    TYK_INT      : TypeMangle := '_RKT_Int';
    TYK_BOOL     : TypeMangle := '_RKT_Bool';
    TYK_STR      : TypeMangle := '_RKT_Str';
    TYK_RAT      : TypeMangle := '_RKT_Rat';
    TYK_ARRAY    : TypeMangle := '_RKT_Array';
    TYK_HASH     : TypeMangle := '_RKT_Hash';
    TYK_CODE     : TypeMangle := '_RKT_Code';
    TYK_CLASS    : TypeMangle := '_RKT_Class';
    TYK_ROLE     : TypeMangle := '_RKT_Role';
    TYK_MU       : TypeMangle := '_RKT_Mu';
    TYK_ANY      : TypeMangle := '_RKT_Any';
    TYK_JUNCTION : TypeMangle := '_RKT_Junct';
    TYK_PAIR     : TypeMangle := '_RKT_Pair';
    TYK_REGEX    : TypeMangle := '_RKT_Regex';
    TYK_MATCH    : TypeMangle := '_RKT_Match';
    TYK_NIL      : TypeMangle := '_RKT_Nil';
  Else
    TypeMangle := '_RKT_Unk';
  End;
End;

{ ---- TypeIsNumeric : vrai si le type est un numerique ------- }
{ En Raku, Int, Bool, Rat sont contextualisables en nombre.     }
{ Bool est True=1, False=0. Rat est traite comme entier (stub). }
Function TypeIsNumeric(TypeIdx : Integer) : Boolean;
Var
  K : TTypeKind;
Begin
  K := TypeKindOf(TypeIdx);
  TypeIsNumeric :=
    (K = TYK_INT) Or (K = TYK_BOOL) Or (K = TYK_RAT);
End;

{ ---- TypeIsPtr : vrai si le type est un pointeur ------------ }
{ Les types Str, Array, Hash, Code, Class, Role, Regex, Match  }
{ et Junction sont stockes comme pointeurs (2 octets near).     }
Function TypeIsPtr(TypeIdx : Integer) : Boolean;
Var
  K : TTypeKind;
Begin
  K := TypeKindOf(TypeIdx);
  TypeIsPtr :=
    (K = TYK_STR)   Or (K = TYK_ARRAY)  Or (K = TYK_HASH) Or
    (K = TYK_CODE)  Or (K = TYK_CLASS)   Or (K = TYK_ROLE) Or
    (K = TYK_REGEX) Or (K = TYK_MATCH)   Or
    (K = TYK_JUNCTION) Or (K = TYK_PAIR);
End;

{ ---- TypeCanCoerce : peut-on convertir SrcIdx vers DstIdx ? - }
{ Raku a un systeme de coercion tres souple :                   }
{   - Tout type -> Mu/Any (supertype)                           }
{   - Int <-> Bool (numerique <-> booleen)                      }
{   - Int <-> Str (coercion +$x / ~$x)                         }
{   - Bool -> Str / Int                                         }
{   - Nil -> tout type (valeur indefinie)                       }
{   - Meme type -> toujours OK                                  }
Function TypeCanCoerce(SrcIdx, DstIdx : Integer) : Boolean;
Var
  SK, DK : TTypeKind;
Begin
  { Meme type : toujours OK }
  If SrcIdx = DstIdx Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { Index invalide ou inconnu : permissif }
  If (SrcIdx < 0) Or (SrcIdx >= TypeCount) Or
     (DstIdx < 0) Or (DstIdx >= TypeCount) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  SK := TypeTab[SrcIdx].Kind;
  DK := TypeTab[DstIdx].Kind;
  { Nil -> tout type }
  If SK = TYK_NIL Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { Tout -> Mu / Any (supertypes Raku) }
  If (DK = TYK_MU) Or (DK = TYK_ANY) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { Int <-> Bool }
  If ((SK = TYK_INT) And (DK = TYK_BOOL)) Or
     ((SK = TYK_BOOL) And (DK = TYK_INT)) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { Int <-> Rat }
  If ((SK = TYK_INT) And (DK = TYK_RAT)) Or
     ((SK = TYK_RAT) And (DK = TYK_INT)) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { Int / Bool / Rat -> Str (coercion ~$x) }
  If (DK = TYK_STR) And
     ((SK = TYK_INT) Or (SK = TYK_BOOL) Or (SK = TYK_RAT)) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { Str -> Int / Bool / Rat (coercion +$x / ?$x) }
  If (SK = TYK_STR) And
     ((DK = TYK_INT) Or (DK = TYK_BOOL) Or (DK = TYK_RAT)) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { Sinon : pas de coercion automatique }
  TypeCanCoerce := False;
End;

{ ---- TypeCoerceResult : type resultat d un op binaire ------- }
{ Determine le type de retour en fonction des operandes et de   }
{ l operateur. Conventions Raku :                               }
{   - Arithmetique (+,-,*,/,div,mod,%%): Int (ou Rat)           }
{   - Comparaisons numeriques (==,!=,<,<=,>,>=,<=>): Bool       }
{   - Comparaisons de chaines (eq,ne,lt,le,gt,ge,leg): Bool     }
{   - Logiques (&&,||,//,and,or,not): type de l operande gauche }
{   - Concatenation (~): Str                                    }
{   - Repetition (x): Str                                       }
{   - Affectation (=,:=,+=,-= etc.): type de la destination     }
{   - Smart match (~~): Bool                                    }
Function TypeCoerceResult(LeftIdx, RightIdx : Integer;
                          Const Op : TString) : Integer;
Begin
  { Comparaisons numeriques -> Bool }
  If (Op = '==') Or (Op = '!=') Or (Op = '<') Or
     (Op = '<=') Or (Op = '>') Or (Op = '>=') Or
     (Op = '<=>') Then
  Begin
    TypeCoerceResult := TY_IDX_BOOL;
    Exit;
  End;
  { Comparaisons de chaines -> Bool }
  If (Op = 'eq') Or (Op = 'ne') Or (Op = 'lt') Or
     (Op = 'le') Or (Op = 'gt') Or (Op = 'ge') Or
     (Op = 'leg') Or (Op = 'cmp') Then
  Begin
    TypeCoerceResult := TY_IDX_BOOL;
    Exit;
  End;
  { Smart match -> Bool }
  If Op = '~~' Then
  Begin
    TypeCoerceResult := TY_IDX_BOOL;
    Exit;
  End;
  { Logiques : retournent le type de l operande gauche }
  If (Op = '&&') Or (Op = '||') Or (Op = '//') Or
     (Op = 'and') Or (Op = 'or') Or (Op = 'not') Then
  Begin
    TypeCoerceResult := LeftIdx;
    Exit;
  End;
  { Concatenation -> Str }
  If Op = '~' Then
  Begin
    TypeCoerceResult := TY_IDX_STR;
    Exit;
  End;
  { Repetition -> Str }
  If Op = 'x' Then
  Begin
    TypeCoerceResult := TY_IDX_STR;
    Exit;
  End;
  { Affectation : type de la destination (gauche) }
  If (Op = '=') Or (Op = ':=') Or
     (Op = '+=') Or (Op = '-=') Or (Op = '*=') Or
     (Op = '/=') Or (Op = '~=') Or (Op = 'x=') Then
  Begin
    TypeCoerceResult := LeftIdx;
    Exit;
  End;
  { Arithmetique : si les deux sont numeriques -> Int }
  If (Op = '+') Or (Op = '-') Or (Op = '*') Or
     (Op = '/') Or (Op = 'div') Or (Op = 'mod') Or
     (Op = '%%') Then
  Begin
    If TypeIsNumeric(LeftIdx) And TypeIsNumeric(RightIdx) Then
      TypeCoerceResult := TY_IDX_INT
    Else If LeftIdx <> TY_UNKNOWN Then
      TypeCoerceResult := LeftIdx
    Else
      TypeCoerceResult := TY_IDX_INT;
    Exit;
  End;
  { Intervalles -> Array }
  If (Op = '..') Or (Op = '..^') Or (Op = '^..') Or
     (Op = '^..^') Then
  Begin
    TypeCoerceResult := TY_IDX_ARRAY;
    Exit;
  End;
  { Par defaut : type de l operande gauche ou Int }
  If LeftIdx <> TY_UNKNOWN Then
    TypeCoerceResult := LeftIdx
  Else
    TypeCoerceResult := TY_IDX_INT;
End;

{ ---- TypeInfer : deduire le type d une expression ----------- }
{ Si le TypeIdx est deja connu, on le retourne directement.     }
{ Sinon, pour les immediats on suppose Int, pour le reste       }
{ on retourne TY_UNKNOWN.                                       }
Function TypeInfer(Const E : TExprVal) : Integer;
Begin
  If E.TypeIdx <> TY_UNKNOWN Then
    TypeInfer := E.TypeIdx
  Else If E.Kind = EK_IMM Then
    TypeInfer := TY_IDX_INT
  Else
    TypeInfer := TY_UNKNOWN;
End;

{ ---- TypeLookupName : chercher un type par nom -------------- }
{ Parcourt TypeTab pour trouver un type par son nom Raku.       }
{ La recherche est sensible a la casse (convention Raku).       }
{ Retourne l index (0-base) ou TY_UNKNOWN si non trouve.        }
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

{ ---- ParseStmt : stub ------------------------------------- }
Procedure ParseStmt;
Begin
  { Stub : avancer d'un token pour eviter boucle infinie }
  If CurToken.Kind <> TK_EOF Then
    ParserAdvance;
End;

{ ============================================================
  PROCEDURE Run
  ============================================================ }
Procedure Run;
Begin
  TypeInit;
  SymInit;
  EmitOpen;
  If ErrorCount > 0 Then Exit;
  LexInit;
  ParserAdvance;
  If Opts.DebugMode Then
  Begin
    While CurToken.Kind <> TK_EOF Do
    Begin
      PrintToken(CurToken);
      ParserAdvance;
    End;
  End
  Else
  Begin
    While CurToken.Kind <> TK_EOF Do
      ParseStmt;
  End;
  LexClose;
  EmitClose;
  If Opts.Verbose Then
    WriteLn('RAKU86: ', TotalLines, ' ligne(s) lues depuis ', Opts.SrcFile);
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
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
  OutFOpen       := False;
  LexOpened      := False;
  LexEOF         := False;
  CurFrameSize   := 0;
  CurFnDepth     := 0;
  LoopTop        := 0;
  GKwConsumed    := False;
  GCallArgCount  := 0;
  CurFnRetLbl    := '';
  CurFnName      := '';
  RuntimeEmitted := False;
  ModuleCount    := 0;
  HashKeyCount   := 0;
  GExprDummy.Kind    := EK_NONE;
  GExprDummy.ImmVal  := 0;
  GExprDummy.TypeIdx := TY_UNKNOWN;
  GExprDummy.Offset  := 0;
  InitOptions;
  ParseArgs;
  ShowBanner;
  Run;
  Cleanup;
  If Opts.Verbose Then ShowStats;
  If ErrorCount > 0 Then Halt(EXIT_ERROR)
                    Else Halt(EXIT_OK);
End.
