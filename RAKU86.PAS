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

  TODO 07 - EMETTEUR DE CODE ASM [IMPLEMENTE]
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

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES [IMPLEMENTE]
            TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR/
              DK_ARRAY_BLK/DK_HASH_BLK), IntVal, StrVal, ElemCount
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr, DataAddArray, DataAddHash
            DataInit : pre-peupler le segment DATA avec les
              constantes internes (CRLF, NL, SPACE, True/False,
              Nil, buffers STRBUF/TMPBUF)
            Variables our (package) : entrees DW dans DATA
            Constantes : entrees DW ou DB (immuables)
            Chaines litterales : DB 'abc',0 dans DATA avec label _RKK_N
            Tables de methodes virtuelles pour les classes
            Tables de dispatch pour les multi subs

  TODO 09 - VARIABLES ET AFFECTATIONS [IMPLEMENTE]
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

  TODO 10 - EXPRESSIONS PRIMAIRES [IMPLEMENTE]
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

  TODO 11 - EXPRESSIONS BINAIRES [IMPLEMENTE]
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

  TODO 12 - ENTREES/SORTIES (say, print, put, get, prompt) [IMPLEMENTE]
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

  TODO 13 - CONDITIONNELLES (if/elsif/else, unless, given/when) [IMPLEMENTE]
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

  TODO 14 - BOUCLES (loop, while, until, repeat, for) [IMPLEMENTE]
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

  TODO 15 - TABLEAUX ET LISTES (Array, List) [IMPLEMENTE]
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

  TODO 16 - TABLES DE HACHAGE (Hash)                   [IMPLEMENTE]
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

  TODO 17 - SOUS-ROUTINES ET FONCTIONS (sub, return) [IMPLEMENTE]
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

  TODO 18 - MULTI DISPATCH (multi sub, proto) [IMPLEMENTE]
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

  TODO 19 - CLASSES ET OBJETS (class, has, method, new) [IMPLEMENTE]
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
  MAX_MULTI_VAR   = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_MULTI_GROUP = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_CLASS       = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_CLASS_ATTR  = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_CLASS_METH  = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
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
    ClassIdx    : Integer;   { index ClassTab, -1 si non-objet }
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
  TDataKind = (DK_WORD, DK_BYTE, DK_STR, DK_ARRAY_BLK, DK_HASH_BLK);

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

  { ---- Multi dispatch (TODO 18) -------------------------- }
  TMultiVarRec = Record
    LblName    : TString;   { label ASM du candidat (_RKS_f_M1) }
    ParamCount : Integer;   { nombre de parametres              }
    TypeIdx0   : Integer;   { type du 1er param (TY_UNKNOWN=any)}
  End;

  TMultiGroup = Record
    Name     : TString;     { nom de base (ex: 'f')            }
    VarCount : Integer;     { nombre de candidats multi         }
    Vars     : Array[0..MAX_MULTI_VAR - 1] Of TMultiVarRec;
    DefIdx   : Integer;     { indice du candidat par defaut (-1)}
    HasProto : Boolean;     { proto sub declare ?               }
  End;

  { ---- Classes et objets (TODO 19) ------------------------ }
  TClassAttrRec = Record
    Name     : TString;   { nom de l attribut sans sigil      }
    IsPublic : Boolean;    { $.x = True, $!x = False           }
    IsRW     : Boolean;    { has $.x is rw                     }
    Offset   : Integer;    { offset dans l instance (2, 4, ..) }
    TypeIdx  : Integer;    { type de la valeur (maj a .new)    }
  End;

  TClassMethodRec = Record
    Name    : TString;     { nom de la methode                 }
    LblName : TString;     { label ASM (_RKS_Cls_meth)         }
    VtIdx   : Integer;     { indice dans la vtable (0, 1, ...) }
  End;

  TClassRec = Record
    Name      : TString;
    ParentIdx : Integer;
    AttrCount : Integer;
    Attrs     : Array[0..MAX_CLASS_ATTR - 1] Of TClassAttrRec;
    MethCount : Integer;
    Meths     : Array[0..MAX_CLASS_METH - 1] Of TClassMethodRec;
    InstSize  : Integer;
    VtLbl     : TString;
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

  { Compteurs conditionnelles (TODO 13) }
  IfCount    : Integer;
  GivenCount : Integer;

  { Compteurs boucles (TODO 14) }
  WhileCount  : Integer;
  UntilCount  : Integer;
  LoopCount   : Integer;
  RepeatCount : Integer;
  ForCount    : Integer;

  { Compteurs tableaux (TODO 15) }
  ArrayTempCount : Integer;

  { Compteurs hash (TODO 16) }
  HashTempCount  : Integer;

  { Compteurs sous-routines (TODO 17) }
  SubCount : Integer;

  { Multi dispatch (TODO 18) }
  MultiGroupTab   : Array[0..MAX_MULTI_GROUP - 1] Of TMultiGroup;
  MultiGroupCount : Integer;
  MultiCount      : Integer;

  { Classes et objets (TODO 19) }
  ClassTab    : Array[0..MAX_CLASS - 1] Of TClassRec;
  ClassCount  : Integer;
  CurClassIdx : Integer;

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

{ Forward declarations TODO 07 - Emetteur de code ASM }
Procedure EmitInstrA(Const Mnem, A1 : TString);                   Forward;
Procedure EmitInstrAB(Const Mnem, A1, A2 : TString);              Forward;
Procedure EmitPush(Const Reg : TString);                          Forward;
Procedure EmitPop(Const Reg : TString);                           Forward;
Procedure EmitMov(Const Dst, Src : TString);                      Forward;
Procedure EmitProlog;                                             Forward;
Procedure EmitEpilog;                                             Forward;

{ Forward declarations TODO 08 - Segment de donnees et statiques }
Function  DataAddArray(Const Lbl : TString;
                       AElemCount : Integer) : Integer;           Forward;
Function  DataAddHash(Const Lbl : TString;
                      APairCount : Integer) : Integer;            Forward;
Procedure DataInit;                                               Forward;

{ Forward declarations TODO 09 - Variables et affectations }
Function  ExprAddrOf(SIdx : Integer) : TString;                    Forward;
Procedure ExprStore(SIdx : Integer);                               Forward;
Procedure ExprLoad(SIdx : Integer; Var Res : TExprVal);            Forward;
Function  DeclAllocSym(Const AName : TString;
                       Const ASigil : TString;
                       ACat : TSymCat;
                       ATypeIdx : Integer) : Integer;              Forward;
Procedure ParseDeclStmt(Const Kw : TString);                       Forward;
Procedure ParseExprStmt;                                           Forward;

{ Forward declarations TODO 10 - Expressions primaires }
Procedure ParseSubCall(Const SubName : TString;
                       Var Res : TExprVal);                        Forward;
Procedure ParseMethodCall(Const MethName : TString;
                          Var Res : TExprVal);                     Forward;
Procedure ParseArrayIndex(SIdx : Integer;
                          Var Res : TExprVal);                     Forward;
Procedure ParseHashAccess(SIdx : Integer;
                          Var Res : TExprVal);                     Forward;
Procedure ParsePostfix(Var Res : TExprVal);                        Forward;
Procedure ParsePairExpr(Const Key : TString;
                        Var Res : TExprVal);                       Forward;

{ Forward declarations TODO 11 - Expressions binaires }
Procedure EmitBinExprRuntime;                                     Forward;

{ Forward declarations TODO 12 - Entrees/sorties }
Procedure EmitPrintVal(ATypeIdx : Integer);                       Forward;
Procedure ParseSayExpr(Var Res : TExprVal);                       Forward;
Procedure ParsePrintExpr(Var Res : TExprVal);                     Forward;
Procedure ParseNoteExpr(Var Res : TExprVal);                      Forward;
Procedure ParseGetExpr(Var Res : TExprVal);                       Forward;
Procedure ParsePromptExpr(Var Res : TExprVal);                    Forward;
Procedure EmitIORuntime;                                          Forward;

{ Forward declarations TODO 13 - Conditionnelles }
Procedure ParseIfStmt;                                            Forward;
Procedure ParseUnlessStmt;                                        Forward;
Procedure ParseGivenWhenStmt;                                     Forward;

{ Forward declarations TODO 14 - Boucles }
Procedure LoopPush(Const BrkLbl, ContLbl, RedoLbl : TString);    Forward;
Procedure LoopPop;                                                Forward;
Procedure ParseWhileStmt;                                         Forward;
Procedure ParseUntilStmt;                                         Forward;
Procedure ParseLoopStmt;                                          Forward;
Procedure ParseRepeatStmt;                                        Forward;
Procedure ParseForStmt;                                           Forward;

{ Forward declarations TODO 15 - Tableaux et listes }
Procedure ParseArrayLiteral(Var Res : TExprVal);                  Forward;
Procedure ParseArrayMethodCall(SIdx : Integer;
                               Const MethName : TString;
                               Var Res : TExprVal);               Forward;
Procedure EmitArrayRuntime;                                       Forward;

{ Forward declarations TODO 16 - Tables de hachage }
Procedure ParseHashLiteral(Var Res : TExprVal);                    Forward;
Procedure ParseHashMethodCall(SIdx : Integer;
                              Const MethName : TString;
                              Var Res : TExprVal);                 Forward;
Procedure ParseHashStore(SIdx : Integer);                          Forward;
Procedure EmitHashRuntime;                                         Forward;

{ Forward declarations TODO 17 - Sous-routines et fonctions }
Procedure ParseSubDecl;                                            Forward;
Procedure ParseReturnStmt;                                         Forward;

{ Forward declarations TODO 18 - Multi dispatch }
Function  MultiGroupFind(Const Name : TString) : Integer;         Forward;
Function  MultiGroupAdd(Const Name : TString) : Integer;          Forward;
Procedure ParseMultiDecl;                                          Forward;
Procedure ParseProtoDecl;                                          Forward;
Procedure EmitMultiDispatchers;                                    Forward;

{ Forward declarations TODO 19 - Classes et objets }
Function  ClassFind(Const AName : TString) : Integer;              Forward;
Function  ClassAdd(Const AName : TString;
                   ParIdx : Integer) : Integer;                    Forward;
Procedure ParseClassDecl;                                          Forward;
Procedure EmitClassVtables;                                        Forward;
Procedure EmitClassRuntime;                                        Forward;

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
  IfCount      := 0;
  GivenCount   := 0;
  WhileCount   := 0;
  UntilCount   := 0;
  LoopCount    := 0;
  RepeatCount  := 0;
  ForCount     := 0;
  ArrayTempCount := 0;
  HashTempCount  := 0;
  SubCount       := 0;
  MultiGroupCount := 0;
  MultiCount      := 0;
  ClassCount      := 0;
  CurClassIdx     := -1;
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
    SymTab[I].ClassIdx    := -1;
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
  EmitComment('Init heap pointer');
  EmitInstr('MOV', 'WORD PTR [_RK_HEAPTOP], OFFSET _RK_HEAP');
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
  EmitComment('=== Runtime RAKU86 ===');
  EmitBlankLine;
  EmitBinExprRuntime;
  EmitIORuntime;
  EmitArrayRuntime;
  EmitHashRuntime;
  EmitClassRuntime;
End;

Procedure EmitDataSeg;
Var
  I   : Integer;
  J   : Integer;
  Tmp : TString;
  S   : TString;
Begin
  EmitRaw('_DATA   SEGMENT WORD PUBLIC ''DATA''');
  If DataCount = 0 Then
    EmitRaw('; (aucune donnee utilisateur)')
  Else
    For I := 0 To DataCount - 1 Do
    Begin
      Case DataTab[I].Kind Of
        DK_WORD :
          EmitRaw(DataTab[I].LblName + '  DW  ' +
                  IntToStr(DataTab[I].IntVal));
        DK_BYTE :
        Begin
          { Si StrVal non vide, utiliser la spec brute (ex: '256 DUP(0)') }
          If DataTab[I].StrVal <> '' Then
            EmitRaw(DataTab[I].LblName + '  DB  ' + DataTab[I].StrVal)
          Else
            EmitRaw(DataTab[I].LblName + '  DB  ' +
                    IntToStr(DataTab[I].IntVal));
        End;
        DK_STR :
        Begin
          S := DataTab[I].StrVal;
          If Length(S) = 0 Then
            EmitRaw(DataTab[I].LblName + '  DB  0')
          Else
          Begin
            { Emettre comme octets pour gerer les caracteres de controle }
            Tmp := DataTab[I].LblName + '  DB  ';
            For J := 1 To Length(S) Do
            Begin
              If J > 1 Then
                Tmp := Tmp + ',';
              Tmp := Tmp + IntToStr(Ord(S[J]));
            End;
            Tmp := Tmp + ',0';
            EmitRaw(Tmp);
          End;
        End;
        DK_ARRAY_BLK :
          EmitRaw(DataTab[I].LblName + '  DW  ' +
                  IntToStr(DataTab[I].ElemCount) + ' DUP(0)');
        DK_HASH_BLK :
        Begin
          { Hash = nombre de paires (DW) + ElemCount paires cle/valeur    }
          { Chaque paire = 2 words : pointeur cle ASCIIZ + valeur = 4 oct}
          EmitRaw(DataTab[I].LblName + '  DW  0');
          EmitRaw(DataTab[I].LblName + '_D  DW  ' +
                  IntToStr(DataTab[I].ElemCount * 2) + ' DUP(0)');
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
  EmitMultiDispatchers;
  EmitClassVtables;
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
  TODO 07 - EMETTEUR DE CODE ASM [IMPLEMENTE]
  ============================================================ }

{ ---- EmitInstrA : instruction a 1 operande ------------------- }
{ Formate : 8 espaces + mnemonique + espace + operande           }
Procedure EmitInstrA(Const Mnem, A1 : TString);
Begin
  EmitRaw('        ' + Mnem + '  ' + A1);
End;

{ ---- EmitInstrAB : instruction a 2 operandes ----------------- }
{ Formate : 8 espaces + mnemonique + espace + A1 + ', ' + A2    }
Procedure EmitInstrAB(Const Mnem, A1, A2 : TString);
Begin
  EmitRaw('        ' + Mnem + '  ' + A1 + ', ' + A2);
End;

{ ---- EmitPush : PUSH registre -------------------------------- }
Procedure EmitPush(Const Reg : TString);
Begin
  EmitInstrA('PUSH', Reg);
End;

{ ---- EmitPop : POP registre ---------------------------------- }
Procedure EmitPop(Const Reg : TString);
Begin
  EmitInstrA('POP', Reg);
End;

{ ---- EmitMov : MOV dst, src ---------------------------------- }
Procedure EmitMov(Const Dst, Src : TString);
Begin
  EmitInstrAB('MOV', Dst, Src);
End;

{ ---- EmitProlog : prologue de sous-routine ------------------- }
{ PUSH BP / MOV BP,SP                                            }
{ Etablit le cadre de pile standard 8086 pour sous-routines      }
{ Raku (sub, method, block).                                     }
Procedure EmitProlog;
Begin
  EmitPush('BP');
  EmitMov('BP', 'SP');
End;

{ ---- EmitEpilog : epilogue de sous-routine ------------------- }
{ MOV SP,BP / POP BP / RET                                       }
{ Restaure le cadre de pile et retourne a l appelant.            }
Procedure EmitEpilog;
Begin
  EmitMov('SP', 'BP');
  EmitPop('BP');
  EmitRaw('        RET');
End;

{ ============================================================
  TODO 08 - SEGMENT DE DONNEES ET STATIQUES [IMPLEMENTE]
  ============================================================ }

{ ---- DataAddArray : ajouter un bloc tableau dans DataTab ----- }
{ Cree une entree DK_ARRAY_BLK de AElemCount mots (DW).         }
{ Retourne l index dans DataTab ou -1 si plein.                 }
Function DataAddArray(Const Lbl : TString;
                      AElemCount : Integer) : Integer;
Var
  Idx : Integer;
Begin
  If DataCount >= MAX_DATA Then
  Begin
    CompileError('segment DATA plein (max=' + IntToStr(MAX_DATA) + ')');
    DataAddArray := -1;
    Exit;
  End;
  Idx := DataAdd(Lbl, DK_ARRAY_BLK, 0, '');
  If Idx >= 0 Then
    DataTab[Idx].ElemCount := AElemCount;
  DataAddArray := Idx;
End;

{ ---- DataAddHash : ajouter un bloc hash dans DataTab --------- }
{ Cree une entree DK_HASH_BLK de APairCount paires cle/valeur.  }
{ En memoire : 1 DW compteur + APairCount * 2 DW (cle+val).     }
{ Retourne l index dans DataTab ou -1 si plein.                 }
Function DataAddHash(Const Lbl : TString;
                     APairCount : Integer) : Integer;
Var
  Idx : Integer;
Begin
  If DataCount >= MAX_DATA Then
  Begin
    CompileError('segment DATA plein (max=' + IntToStr(MAX_DATA) + ')');
    DataAddHash := -1;
    Exit;
  End;
  Idx := DataAdd(Lbl, DK_HASH_BLK, 0, '');
  If Idx >= 0 Then
    DataTab[Idx].ElemCount := APairCount;
  DataAddHash := Idx;
End;

{ ---- DataInit : pre-peupler le segment DATA ------------------- }
{ Enregistre les constantes internes utilisees par le runtime     }
{ Raku86 avant que la compilation ne commence :                   }
{   _RK_CRLF      : retour chariot (13,10,0)                     }
{   _RK_NL        : saut de ligne (10,0)                         }
{   _RK_SPACE     : espace (32,0)                                }
{   _RK_EMPTY     : chaine vide (0)                              }
{   _RK_TRUE_S    : chaine 'True'                                }
{   _RK_FALSE_S   : chaine 'False'                               }
{   _RK_NIL_S     : chaine 'Nil'                                 }
{   _RK_STRBUF    : buffer de concatenation (256 octets)         }
{   _RK_TMPBUF    : buffer temporaire (256 octets)               }
{   _RK_NUMBUF    : buffer conversion entier (12 octets)         }
Procedure DataInit;
Begin
  DataAdd('_RK_CRLF',    DK_STR, 0, #13#10);
  DataAdd('_RK_NL',      DK_STR, 0, #10);
  DataAdd('_RK_SPACE',   DK_STR, 0, ' ');
  DataAdd('_RK_EMPTY',   DK_STR, 0, '');
  DataAdd('_RK_TRUE_S',  DK_STR, 0, 'True');
  DataAdd('_RK_FALSE_S', DK_STR, 0, 'False');
  DataAdd('_RK_NIL_S',   DK_STR, 0, 'Nil');
  DataAdd('_RK_STRBUF',  DK_BYTE, 0, '256 DUP(0)');
  DataAdd('_RK_TMPBUF',  DK_BYTE, 0, '256 DUP(0)');
  DataAdd('_RK_NUMBUF',  DK_BYTE, 0, '12 DUP(0)');
  DataAdd('_RK_IOBUF',   DK_BYTE, 0, '130 DUP(0)');
  DataAdd('_RK_HEAP',    DK_BYTE, 0, '4096 DUP(0)');
  DataAdd('_RK_HEAPTOP', DK_WORD, 0, '');
  { Multi dispatch (TODO 18) }
  DataAdd('_RK_MULTISIG',  DK_WORD, 0, '');
  DataAdd('_RKK_NOMDISP',  DK_STR, 0,
          'No matching multi candidate');
  { Classes et objets (TODO 19) }
  DataAdd('_RK_INSTPTR',   DK_WORD, 0, '');
  DataAdd('_RKK_NOMETHOD', DK_STR, 0, 'Method not found');
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
      Res.Kind    := EK_MEM;
      Res.ImmVal  := 0;     { 0 = reference DATA (pas locale) }
      Res.TypeIdx := TY_IDX_STR;
      Res.Offset  := DataCount - 1;  { index dans DataTab }
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
    Affectation simple '=' et ':=' : traitement via ParseExprStmt
    ============================================================== }
  If (Op = '=') Or (Op = ':=') Then
  Begin
    EmitComment(Op + ' : affectation via ExprEmitBinOp');
    { AX contient la valeur droite. Left.EK_MEM contient la dest. }
    If (Left.Kind = EK_MEM) And (Left.ImmVal = 1) Then
    Begin
      { Variable locale [BP-n] }
      EmitInstr('MOV', '[BP-' + IntToStr(Left.Offset) + '], AX');
    End
    Else If (Left.Kind = EK_MEM) And (Left.Offset >= 0) And
            (Left.Offset < DataCount) Then
    Begin
      { Variable DATA }
      EmitInstr('MOV', '[' + DataTab[Left.Offset].LblName + '], AX');
    End
    Else
      EmitComment(Op + ' : cible non resolue');
    Res.Kind := EK_AX;
    Exit;
  End;
  { ==============================================================
    Affectations composees : stub (gestion directe dans ParseExprStmt)
    ============================================================== }
  If (Op = '+=') Or (Op = '-=') Or (Op = '*=') Or (Op = '/=') Or
     (Op = '~=') Or (Op = 'x=') Then
  Begin
    EmitComment(Op + ' : affectation composee (gere par ParseExprStmt)');
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
    { Puissance : BX=base, AX=exposant -> AX=result }
    EmitInstr('PUSH', 'AX');
    EmitInstr('MOV', 'AX, BX');
    EmitPop('CX');
    EmitInstr('CALL', '_RKRT_POWER');
    Exit;
  End;
  { ==============================================================
    Concatenation ~ et repetition x
    ============================================================== }
  If Op = '~' Then
  Begin
    { Concatenation : BX=gauche ptr, AX=droite ptr -> AX=STRBUF }
    EmitInstr('PUSH', 'AX');
    EmitInstr('MOV', 'BYTE PTR [_RK_STRBUF], 0');
    EmitInstr('MOV', 'DI, OFFSET _RK_STRBUF');
    EmitInstr('MOV', 'SI, BX');
    EmitInstr('CALL', '_RKRT_CONCAT');
    EmitPop('SI');
    EmitInstr('CALL', '_RKRT_CONCAT');
    EmitInstr('MOV', 'AX, OFFSET _RK_STRBUF');
    Res.TypeIdx := TY_IDX_STR;
    Exit;
  End;
  If Op = 'x' Then
  Begin
    { Repetition : BX=chaine ptr, AX=count -> AX=TMPBUF }
    EmitInstr('MOV', 'CX, AX');
    EmitInstr('MOV', 'SI, BX');
    EmitInstr('CALL', '_RKRT_STRREPEAT');
    Res.TypeIdx := TY_IDX_STR;
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
    { Comparaisons de chaines : BX=gauche ptr, AX=droite ptr }
    EmitInstr('MOV', 'SI, BX');
    EmitInstr('MOV', 'DI, AX');
    EmitInstr('CALL', '_RKRT_STRCMP');
    { AX = -1 (lt), 0 (eq), +1 (gt) apres _RKRT_STRCMP }
    If Op = 'eq' Then
    Begin
      EmitInstr('TEST', 'AX, AX');
      EmitInstr('SETE', 'AL');
      EmitInstr('MOVZX', 'AX, AL');
    End
    Else If Op = 'ne' Then
    Begin
      EmitInstr('TEST', 'AX, AX');
      EmitInstr('SETNE', 'AL');
      EmitInstr('MOVZX', 'AX, AL');
    End
    Else If Op = 'lt' Then
    Begin
      EmitInstr('CMP', 'AX, 0');
      EmitInstr('SETL', 'AL');
      EmitInstr('MOVZX', 'AX, AL');
    End
    Else If Op = 'le' Then
    Begin
      EmitInstr('CMP', 'AX, 0');
      EmitInstr('SETLE', 'AL');
      EmitInstr('MOVZX', 'AX, AL');
    End
    Else If Op = 'gt' Then
    Begin
      EmitInstr('CMP', 'AX, 0');
      EmitInstr('SETG', 'AL');
      EmitInstr('MOVZX', 'AX, AL');
    End
    Else If Op = 'ge' Then
    Begin
      EmitInstr('CMP', 'AX, 0');
      EmitInstr('SETGE', 'AL');
      EmitInstr('MOVZX', 'AX, AL');
    End
    Else If Op = 'leg' Then
    Begin
      { leg = <=> pour chaines : retourne -1/0/+1 }
      { AX a deja -1/0/+1 }
    End
    Else If Op = 'cmp' Then
    Begin
      { cmp = alias pour leg }
      { AX a deja -1/0/+1 }
    End;
    If (Op <> 'leg') And (Op <> 'cmp') Then
      Res.TypeIdx := TY_IDX_BOOL
    Else
      Res.TypeIdx := TY_IDX_INT;
    Exit;
  End;
  { ==============================================================
    Smart match ~~
    ============================================================== }
  If Op = '~~' Then
  Begin
    { Smart match : BX=left, AX=right -> comparaison par defaut }
    EmitInstr('CMP', 'BX, AX');
    EmitInstr('SETE', 'AL');
    EmitInstr('MOVZX', 'AX, AL');
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
{ Gere : litteraux, variables $/@/pct/&, parens, not/so/True/  }
{        appels de sub name(args), paires key => val, self,     }
{        acces tableau @arr[idx], acces hash pct-h(key),        }
{        postfixes .method(args) et .attribut                    }
Procedure ParsePrimary(Var Res : TExprVal);
Var
  Sub  : TExprVal;
  SIdx : Integer;
  Name : TString;
  CIdx : Integer;
Begin
  ExprMakeNone(Res);
  { --- Litteraux entiers --- }
  If CurToken.Kind = TK_INTEGER Then
  Begin
    LitEval(CurToken, Res);
    ParserAdvance;
    ParsePostfix(Res);
    Exit;
  End;
  { --- Litteraux rationnels --- }
  If CurToken.Kind = TK_RATIONAL Then
  Begin
    LitEval(CurToken, Res);
    ParserAdvance;
    ParsePostfix(Res);
    Exit;
  End;
  { --- Litteraux chaines --- }
  If CurToken.Kind = TK_STRING Then
  Begin
    LitEval(CurToken, Res);
    ParserAdvance;
    ParsePostfix(Res);
    Exit;
  End;
  { --- Variables scalaires $nom --- }
  If CurToken.Kind = TK_SCALAR Then
  Begin
    SIdx := SymFind('$' + CurToken.Val);
    If SIdx >= 0 Then
    Begin
      ExprLoad(SIdx, Res);
      { Propager le type classe si applicable }
      If (SymTab[SIdx].TypeIdx = TY_IDX_CLASS) And
         (SymTab[SIdx].ClassIdx >= 0) Then
      Begin
        Res.TypeIdx := TY_IDX_CLASS;
        Res.Offset  := SymTab[SIdx].ClassIdx;
      End;
    End
    Else
    Begin
      EmitComment('$' + CurToken.Val + ' (non declare)');
      ExprMakeImm(0, TY_IDX_INT, Res);
    End;
    ParserAdvance;
    { --- Postfix : $obj.method(args), $obj.attr --- }
    ParsePostfix(Res);
    Exit;
  End;
  { --- Variables tableau @nom --- }
  If CurToken.Kind = TK_ARRAY_SIG Then
  Begin
    Name := CurToken.Val;
    SIdx := SymFind('@' + Name);
    If SIdx < 0 Then
    Begin
      EmitComment('@' + Name + ' (non declare)');
      ExprMakeImm(0, TY_IDX_ARRAY, Res);
      ParserAdvance;
      ParsePostfix(Res);
      Exit;
    End;
    ParserAdvance;
    { --- Acces element tableau : @arr[$i] --- }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[') Then
    Begin
      ParseArrayIndex(SIdx, Res);
    End
    Else
    Begin
      ExprLoad(SIdx, Res);
    End;
    ParsePostfix(Res);
    Exit;
  End;
  { --- Variables hash %nom --- }
  If CurToken.Kind = TK_HASH_SIG Then
  Begin
    Name := CurToken.Val;
    SIdx := SymFind('%' + Name);
    If SIdx < 0 Then
    Begin
      EmitComment('%' + Name + ' (non declare)');
      ExprMakeImm(0, TY_IDX_HASH, Res);
      ParserAdvance;
      ParsePostfix(Res);
      Exit;
    End;
    ParserAdvance;
    { --- Acces element hash : pct-h(key) ou pct-h<key> --- }
    If ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{')) Or
       ((CurToken.Kind = TK_OP) And (CurToken.Val = '<')) Then
    Begin
      ParseHashAccess(SIdx, Res);
    End
    Else
    Begin
      ExprLoad(SIdx, Res);
    End;
    ParsePostfix(Res);
    Exit;
  End;
  { --- Variables code &nom --- }
  If CurToken.Kind = TK_CODE_SIG Then
  Begin
    SIdx := SymFind('&' + CurToken.Val);
    If SIdx >= 0 Then
    Begin
      ExprLoad(SIdx, Res);
    End
    Else
    Begin
      EmitComment('&' + CurToken.Val + ' (non declare)');
      ExprMakeImm(0, TY_IDX_CODE, Res);
    End;
    ParserAdvance;
    ParsePostfix(Res);
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
      ParsePostfix(Res);
      Exit;
    End;
    { --- self : reference a l objet courant --- }
    If CurToken.Val = 'self' Then
    Begin
      ParserAdvance;
      EmitComment('self : reference objet courant');
      EmitInstr('MOV', 'AX, [BP+4]');
      Res.Kind    := EK_AX;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_INT;
      Res.Offset  := 0;
      ParsePostfix(Res);
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
  { --- Identificateur libre : sub call, Classe.new, pair key => val --- }
  If CurToken.Kind = TK_IDENT Then
  Begin
    Name := CurToken.Val;
    { --- Builtins E/S (TODO 12) : say, put, print, note, get, prompt --- }
    If (Name = 'say') Or (Name = 'put') Then
    Begin
      ParserAdvance;
      ParseSayExpr(Res);
      Exit;
    End;
    If Name = 'print' Then
    Begin
      ParserAdvance;
      ParsePrintExpr(Res);
      Exit;
    End;
    If Name = 'note' Then
    Begin
      ParserAdvance;
      ParseNoteExpr(Res);
      Exit;
    End;
    If Name = 'get' Then
    Begin
      ParserAdvance;
      ParseGetExpr(Res);
      Exit;
    End;
    If Name = 'prompt' Then
    Begin
      ParserAdvance;
      ParsePromptExpr(Res);
      Exit;
    End;
    ParserAdvance;
    { --- Paire : ident => valeur --- }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '=>') Then
    Begin
      ParsePairExpr(Name, Res);
      ParsePostfix(Res);
      Exit;
    End;
    { --- Appel de sous-routine : name(args) --- }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      ParseSubCall(Name, Res);
      ParsePostfix(Res);
      Exit;
    End;
    { --- Instanciation : Classe.new(args) --- }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '.') Then
    Begin
      { Chercher la classe }
      CIdx := ClassFind(Name);
      If CIdx >= 0 Then
      Begin
        EmitComment('classe ' + Name);
        EmitInstr('XOR', 'AX, AX');
        Res.Kind    := EK_AX;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_CLASS;
        Res.Offset  := CIdx;
      End
      Else
      Begin
        EmitComment('type/classe ' + Name);
        EmitInstr('XOR', 'AX, AX');
        Res.Kind    := EK_AX;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_INT;
        Res.Offset  := 0;
      End;
      ParsePostfix(Res);
      Exit;
    End;
    { Identifiant simple (peut etre un nom de type ou bareword) }
    EmitComment('ident ' + Name);
    ExprMakeImm(0, TY_IDX_INT, Res);
    ParsePostfix(Res);
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
    ParsePostfix(Res);
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

{ ============================================================
  TODO 09 - VARIABLES ET AFFECTATIONS [IMPLEMENTE]
  ExprAddrOf     : adresse MASM (WORD PTR [...]) pour un symbole
  ExprStore      : stocker AX dans la variable SymTab[SIdx]
  ExprLoad       : charger une variable dans AX + remplir TExprVal
  DeclAllocSym   : allouer une variable my (locale) ou our (DATA)
  ParseDeclStmt  : my $x; my Int $x = 42; our $x; constant $c = 7;
  ParseExprStmt  : expression-instruction ($x = expr; etc.)
  ============================================================ }

{ ---- ExprAddrOf : adresse MASM d un symbole SymTab[SIdx] ---- }
{ Variables locales  (SC_MY/SC_PARAM) : WORD PTR [BP-N]         }
{ Variables globales (SC_OUR/SC_CONST) : WORD PTR [_RKV_nom]    }
{ Retourne '' si SIdx invalide.                                  }
Function ExprAddrOf(SIdx : Integer) : TString;
Var
  S : TString;
Begin
  If (SIdx < 0) Or (SIdx >= SymCount) Then
  Begin
    ExprAddrOf := '';
    Exit;
  End;
  If (SymTab[SIdx].Cat = SC_MY) Or (SymTab[SIdx].Cat = SC_HAS) Then
  Begin
    Str(SymTab[SIdx].Offset, S);
    ExprAddrOf := 'WORD PTR [BP-' + S + ']';
  End
  Else If SymTab[SIdx].Cat = SC_PARAM Then
  Begin
    Str(SymTab[SIdx].Offset, S);
    ExprAddrOf := 'WORD PTR [BP+' + S + ']';
  End
  Else If (SymTab[SIdx].Cat = SC_OUR) Or (SymTab[SIdx].Cat = SC_CONST) Then
    ExprAddrOf := 'WORD PTR [' + SymTab[SIdx].MangledName + ']'
  Else
    ExprAddrOf := '';
End;

{ ---- ExprStore : stocker AX dans la variable SymTab[SIdx] ---- }
Procedure ExprStore(SIdx : Integer);
Var
  S : TString;
Begin
  If (SIdx < 0) Or (SIdx >= SymCount) Then Exit;
  If (SymTab[SIdx].Cat = SC_MY) Or (SymTab[SIdx].Cat = SC_HAS) Then
  Begin
    Str(SymTab[SIdx].Offset, S);
    EmitInstr('MOV', '[BP-' + S + '], AX');
  End
  Else If SymTab[SIdx].Cat = SC_PARAM Then
  Begin
    Str(SymTab[SIdx].Offset, S);
    EmitInstr('MOV', '[BP+' + S + '], AX');
  End
  Else If (SymTab[SIdx].Cat = SC_OUR) Or (SymTab[SIdx].Cat = SC_CONST) Then
    EmitInstr('MOV', '[' + SymTab[SIdx].MangledName + '], AX')
  Else
  Begin
    CompileError('ExprStore: categorie non supportee pour ' +
                 SymTab[SIdx].SigilName);
  End;
End;

{ ---- ExprLoad : charger une variable dans AX et TExprVal ----- }
Procedure ExprLoad(SIdx : Integer; Var Res : TExprVal);
Var
  S : TString;
Begin
  Res.Kind    := EK_AX;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  If (SIdx < 0) Or (SIdx >= SymCount) Then
  Begin
    Res.TypeIdx := TY_IDX_INT;
    EmitInstr('XOR', 'AX, AX');
    Exit;
  End;
  Res.TypeIdx := SymTab[SIdx].TypeIdx;
  If (SymTab[SIdx].Cat = SC_MY) Or (SymTab[SIdx].Cat = SC_HAS) Then
  Begin
    Str(SymTab[SIdx].Offset, S);
    EmitInstr('MOV', 'AX, [BP-' + S + ']');
  End
  Else If SymTab[SIdx].Cat = SC_PARAM Then
  Begin
    Str(SymTab[SIdx].Offset, S);
    EmitInstr('MOV', 'AX, [BP+' + S + ']');
  End
  Else If (SymTab[SIdx].Cat = SC_OUR) Or (SymTab[SIdx].Cat = SC_CONST) Then
  Begin
    If SymTab[SIdx].TypeIdx = TY_IDX_STR Then
      EmitInstr('MOV', 'AX, [' + SymTab[SIdx].MangledName + ']')
    Else
      EmitInstr('MOV', 'AX, [' + SymTab[SIdx].MangledName + ']');
  End
  Else
    EmitInstr('XOR', 'AX, AX');
End;

{ ---- DeclAllocSym : allouer une variable ---------------------- }
{ my    -> locale [BP-n], SUB SP,2                                }
{ our   -> globale DATA, DataAddWord                              }
{ constant -> globale DATA, DataAddWord                           }
{ Retourne l'index dans SymTab.                                   }
Function DeclAllocSym(Const AName : TString;
                      Const ASigil : TString;
                      ACat : TSymCat;
                      ATypeIdx : Integer) : Integer;
Var
  Ofs : Integer;
  Idx : Integer;
  Lbl : TString;
Begin
  If ACat = SC_MY Then
  Begin
    { Variable locale sur la pile }
    Ofs := SymNextOffset;
    EmitInstr('SUB', 'SP, 2');
    EmitInstr('MOV', 'WORD PTR [BP-' + IntToStr(Ofs) + '], 0');
    Idx := SymAdd(AName, ASigil, SC_MY, ATypeIdx, Ofs);
    EmitComment('my ' + ASigil + AName + ' [BP-' + IntToStr(Ofs) + ']');
    DeclAllocSym := Idx;
  End
  Else If ACat = SC_OUR Then
  Begin
    { Variable globale dans DATA }
    Lbl := SymMangle(AName, SC_OUR);
    DataAddWord(Lbl, 0);
    Idx := SymAdd(AName, ASigil, SC_OUR, ATypeIdx, 0);
    EmitComment('our ' + ASigil + AName + ' -> ' + Lbl);
    DeclAllocSym := Idx;
  End
  Else If ACat = SC_CONST Then
  Begin
    { Constante dans DATA }
    Lbl := SymMangle(AName, SC_CONST);
    DataAddWord(Lbl, 0);
    Idx := SymAdd(AName, ASigil, SC_CONST, ATypeIdx, 0);
    EmitComment('constant ' + ASigil + AName + ' -> ' + Lbl);
    DeclAllocSym := Idx;
  End
  Else
  Begin
    { Fallback : traiter comme my }
    Ofs := SymNextOffset;
    EmitInstr('SUB', 'SP, 2');
    EmitInstr('MOV', 'WORD PTR [BP-' + IntToStr(Ofs) + '], 0');
    Idx := SymAdd(AName, ASigil, ACat, ATypeIdx, Ofs);
    DeclAllocSym := Idx;
  End;
End;

{ ---- ParseDeclStmt : declaration de variable ------------------- }
{ Syntaxe : my [$type] $var [= expr] ;                            }
{           our [$type] $var [= expr] ;                           }
{           constant $var = expr ;                                 }
{           has $.attr ;                                           }
Procedure ParseDeclStmt(Const Kw : TString);
Var
  Cat     : TSymCat;
  VarName : TString;
  Sigil   : TString;
  TyIdx   : Integer;
  SIdx    : Integer;
  E       : TExprVal;
  TyName  : TString;
Begin
  { Determiner la categorie }
  If Kw = 'our' Then Cat := SC_OUR
  Else If Kw = 'has' Then Cat := SC_HAS
  Else If Kw = 'constant' Then Cat := SC_CONST
  Else Cat := SC_MY;   { my par defaut }

  TyIdx := TY_IDX_INT;   { type par defaut : Int }

  { Verifier s il y a un type optionnel avant le sigil }
  If CurToken.Kind = TK_IDENT Then
  Begin
    TyName := CurToken.Val;
    If TypeLookupName(TyName) <> TY_UNKNOWN Then
    Begin
      TyIdx := TypeLookupName(TyName);
      ParserAdvance;   { consommer le nom de type }
    End;
  End;

  { Attendre un token sigil : $x, @x, %x, &x }
  If (CurToken.Kind = TK_SCALAR) Or (CurToken.Kind = TK_ARRAY_SIG) Or
     (CurToken.Kind = TK_HASH_SIG) Or (CurToken.Kind = TK_CODE_SIG) Then
  Begin
    VarName := CurToken.Val;
    If CurToken.Kind = TK_SCALAR Then
      Sigil := '$'
    Else If CurToken.Kind = TK_ARRAY_SIG Then
    Begin
      Sigil := '@';
      TyIdx := TY_IDX_ARRAY;
    End
    Else If CurToken.Kind = TK_HASH_SIG Then
    Begin
      Sigil := '%';
      TyIdx := TY_IDX_HASH;
    End
    Else
      Sigil := '&';
    ParserAdvance;   { consommer la variable }
  End
  Else
  Begin
    CompileError('identifiant attendu apres ' + Kw);
    Exit;
  End;

  { Verifier doublon dans la portee courante }
  If SymFindInScope(Sigil + VarName, CurScope) >= 0 Then
  Begin
    WarnMsg('redeclaration de ' + Sigil + VarName + ' dans la meme portee');
  End;

  { Allouer le symbole }
  SIdx := DeclAllocSym(VarName, Sigil, Cat, TyIdx);

  { Initialisation optionnelle : = expr ou := expr (binding) }
  If (CurToken.Kind = TK_OP) And
     ((CurToken.Val = '=') Or (CurToken.Val = ':=')) Then
  Begin
    ParserAdvance;   { consommer = ou := }
    { Pour les tableaux, detecter le litteral (e1, e2, ...) }
    If (Sigil = '@') And (CurToken.Kind = TK_PUNCT) And
       (CurToken.Val = '(') Then
    Begin
      ParserAdvance;   { consommer '(' }
      ParseArrayLiteral(E);
    End
    { Pour les hash, detecter le litteral (k1 => v1, k2 => v2, ...) }
    Else If (Sigil = '%') And (CurToken.Kind = TK_PUNCT) And
            (CurToken.Val = '(') Then
    Begin
      ParserAdvance;   { consommer '(' }
      ParseHashLiteral(E);
    End
    Else
    Begin
      ParseExpr(E);
    End;
    ExprFlushToAX(E);
    If SIdx >= 0 Then
    Begin
      { Propager le type si scalaire sans annotation de type explicite }
      If (Sigil = '$') And (TyIdx = TY_IDX_INT) And
         (E.TypeIdx <> TY_UNKNOWN) And (E.TypeIdx <> TY_IDX_INT) Then
        SymTab[SIdx].TypeIdx := E.TypeIdx;
      { Propager l index de classe pour les objets (TODO 19) }
      If E.TypeIdx = TY_IDX_CLASS Then
        SymTab[SIdx].ClassIdx := E.Offset;
      ExprStore(SIdx);
    End;
  End;

  { Consommer le ; optionnel }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance;
End;

{ ---- ParseExprStmt : expression-instruction ------------------- }
{ Gere : $var = expr; $var op= expr; expr;                       }
Procedure ParseExprStmt;
Var
  E      : TExprVal;
  VarNm  : TString;
  Sigil  : TString;
  SIdx   : Integer;
  Op     : TString;
Begin
  { Si c est un scalaire/tableau/hash suivi d un operateur d affectation }
  If (CurToken.Kind = TK_SCALAR) Or (CurToken.Kind = TK_ARRAY_SIG) Or
     (CurToken.Kind = TK_HASH_SIG) Then
  Begin
    VarNm := CurToken.Val;
    If CurToken.Kind = TK_SCALAR Then Sigil := '$'
    Else If CurToken.Kind = TK_ARRAY_SIG Then Sigil := '@'
    Else Sigil := '%';

    SIdx := SymFind(Sigil + VarNm);

    { Creer automatiquement si inconnu (mode implicite) }
    If SIdx < 0 Then
      SIdx := DeclAllocSym(VarNm, Sigil, SC_MY, TY_IDX_INT);

    ParserAdvance;   { consommer la variable }

    { Detection d affectation d element hash : pct-h(key) = val }
    If (Sigil = '%') And
       (((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{')) Or
        ((CurToken.Kind = TK_OP) And (CurToken.Val = '<'))) Then
    Begin
      ParseHashStore(SIdx);
    End
    Else If (CurToken.Kind = TK_OP) And (IsAssignOp(CurToken.Val)) Then
    Begin
      Op := CurToken.Val;
      ParserAdvance;   { consommer l operateur }
      { Pour les tableaux, detecter le litteral (e1, e2, ...) }
      If (Sigil = '@') And (Op = '=') And
         (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        ParserAdvance;   { consommer '(' }
        ParseArrayLiteral(E);
      End
      { Pour les hash, detecter le litteral (k1 => v1, ...) }
      Else If (Sigil = '%') And (Op = '=') And
              (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        ParserAdvance;   { consommer '(' }
        ParseHashLiteral(E);
      End
      Else
        ParseExpr(E);
      ExprFlushToAX(E);

      If Op = '=' Then
      Begin
        EmitComment(Sigil + VarNm + ' = ...');
        ExprStore(SIdx);
      End
      Else If Op = ':=' Then
      Begin
        EmitComment(Sigil + VarNm + ' := ...');
        ExprStore(SIdx);
      End
      Else
      Begin
        { Affectation composee : charger la valeur courante dans BX }
        EmitPush('AX');
        ExprLoad(SIdx, E);
        EmitInstr('MOV', 'BX, AX');
        EmitPop('AX');
        If      Op = '+='  Then EmitInstr('ADD', 'BX, AX')
        Else If Op = '-='  Then EmitInstr('SUB', 'BX, AX')
        Else If Op = '*='  Then
        Begin
          EmitInstr('XCHG', 'AX, BX');
          EmitInstr('IMUL', 'BX');
        End
        Else If Op = '/='  Then
        Begin
          EmitInstr('XCHG', 'AX, BX');
          EmitInstr('CWD', '');
          EmitInstr('IDIV', 'BX');
          EmitInstr('MOV', 'BX, AX');
        End
        Else If Op = '~='  Then
          EmitComment('~= : concat stub')
        Else If Op = 'x='  Then
          EmitComment('x= : repeat stub')
        Else
          EmitComment(Op + ' : compound assign stub');
        EmitInstr('MOV', 'AX, BX');
        ExprStore(SIdx);
      End;
    End
    Else
    Begin
      { Pas d affectation : charger la variable + postfixes }
      ExprLoad(SIdx, E);
      ParsePostfix(E);
    End;
  End
  Else
  Begin
    { Expression generale (appel de sub, etc.) }
    ParseExpr(E);
    ExprFlushToAX(E);
  End;

  { Consommer le ; optionnel }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance;
End;

{ ============================================================
  TODO 10 - EXPRESSIONS PRIMAIRES [IMPLEMENTE]
  ParseSubCall    : appel de sub name(args) -> PUSH args/CALL/ADD SP
  ParseMethodCall : appel de methode .method(args) -> CALL
  ParseArrayIndex : acces @arr[$i] -> offset dans ARRAY
  ParseHashAccess : acces pct-h(key) ou pct-h<key> -> CALL lookup
  ParsePostfix    : chaine de postfixes .method/[idx]/(key)
  ParsePairExpr   : construction de paire key => value
  ============================================================ }

{ ---- ParseSubCall : appel de sous-routine name(args) ---------- }
{ Pousse les arguments de droite a gauche, puis CALL _RKS_name,   }
{ ADD SP, N*2 pour nettoyer la pile.                              }
{ Si la sub est multi, emet MOV [_RK_MULTISIG], type du 1er arg  }
{ avant le CALL pour permettre le dispatch.                       }
Procedure ParseSubCall(Const SubName : TString;
                       Var Res : TExprVal);
Var
  ArgCount  : Integer;
  E         : TExprVal;
  Lbl       : TString;
  GIdx      : Integer;
  FirstType : Integer;
  TS        : TString;
Begin
  Lbl := '_RKS_' + SymNameClean(SubName);
  ArgCount  := 0;
  FirstType := TY_UNKNOWN;
  { Consommer '(' }
  ParserAdvance;
  { Parser les arguments separes par ',' }
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
  Begin
    Repeat
      ParseExpr(E);
      ExprFlushToAX(E);
      { Memoriser le type du premier argument pour multi dispatch }
      If ArgCount = 0 Then
        FirstType := E.TypeIdx;
      EmitPush('AX');
      Inc(ArgCount);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance
      Else
        Break;
    Until CurToken.Kind = TK_EOF;
  End;
  { Consommer ')' }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance
  Else
    CompileError(''')'' attendue apres les arguments de ' + SubName);
  { Multi dispatch : stocker le type du 1er arg dans _RK_MULTISIG }
  GIdx := MultiGroupFind(SubName);
  If GIdx >= 0 Then
  Begin
    If FirstType < 0 Then
      EmitInstr('MOV', 'WORD PTR [_RK_MULTISIG], 0FFFFh')
    Else
    Begin
      Str(FirstType, TS);
      EmitInstr('MOV', 'WORD PTR [_RK_MULTISIG], ' + TS);
    End;
  End;
  { Emettre CALL }
  EmitInstr('CALL', Lbl);
  { Nettoyer la pile }
  If ArgCount > 0 Then
    EmitInstr('ADD', 'SP, ' + IntToStr(ArgCount * 2));
  EmitComment('appel ' + SubName + '(' + IntToStr(ArgCount) + ' args)');
  Res.Kind    := EK_AX;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_IDX_INT;
  Res.Offset  := 0;
End;

{ ---- ParseMethodCall : appel .methode(args) ------------------- }
{ L objet est deja dans AX. Pousse self + args, CALL label.       }
Procedure ParseMethodCall(Const MethName : TString;
                          Var Res : TExprVal);
Var
  ArgCount : Integer;
  E        : TExprVal;
  Lbl      : TString;
Begin
  Lbl := '_RKS_' + SymNameClean(MethName);
  ArgCount := 0;
  { Pousser self (AX = objet courant) }
  EmitPush('AX');
  Inc(ArgCount);
  { Consommer '(' si present }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
  Begin
    ParserAdvance;
    If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
    Begin
      Repeat
        ParseExpr(E);
        ExprFlushToAX(E);
        EmitPush('AX');
        Inc(ArgCount);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          ParserAdvance
        Else
          Break;
      Until CurToken.Kind = TK_EOF;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance
    Else
      CompileError(''')'' attendue apres les arguments de .' + MethName);
  End;
  { Emettre CALL }
  EmitInstr('CALL', Lbl);
  If ArgCount > 0 Then
    EmitInstr('ADD', 'SP, ' + IntToStr(ArgCount * 2));
  EmitComment('methode .' + MethName + '(' + IntToStr(ArgCount - 1) + ' args)');
  Res.Kind    := EK_AX;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_IDX_INT;
  Res.Offset  := 0;
End;

{ ---- ParseArrayIndex : acces @arr[$i] -> element -------------- }
{ SIdx = index du symbole @arr dans SymTab.                       }
{ Le variable contient un pointeur vers le bloc heap :            }
{   [count:DW] [e0:DW] [e1:DW] ...                               }
{ Charge le pointeur, evalue l index, calcule offset = 2+idx*2.  }
Procedure ParseArrayIndex(SIdx : Integer;
                          Var Res : TExprVal);
Var
  E : TExprVal;
  S : TString;
Begin
  { Consommer '[' }
  ParserAdvance;
  { Evaluer l expression d index }
  ParseExpr(E);
  ExprFlushToAX(E);
  { Consommer ']' }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
    ParserAdvance
  Else
    CompileError(''']'' attendue apres l''index du tableau');
  { AX = index. Calculer offset = index * 2 + 2                }
  { +2 pour sauter le mot compteur DW en tete du bloc tableau  }
  EmitInstr('SHL', 'AX, 1');
  EmitInstr('ADD', 'AX, 2');
  { Charger le pointeur tableau dans BX }
  If (SIdx >= 0) And (SIdx < SymCount) Then
  Begin
    If (SymTab[SIdx].Cat = SC_MY) Or (SymTab[SIdx].Cat = SC_PARAM) Or
       (SymTab[SIdx].Cat = SC_HAS) Then
    Begin
      Str(SymTab[SIdx].Offset, S);
      EmitInstr('MOV', 'BX, [BP-' + S + ']');
    End
    Else If (SymTab[SIdx].Cat = SC_OUR) Or (SymTab[SIdx].Cat = SC_CONST) Then
      EmitInstr('MOV', 'BX, [' + SymTab[SIdx].MangledName + ']')
    Else
      EmitInstr('XOR', 'BX, BX');
  End
  Else
    EmitInstr('XOR', 'BX, BX');
  { BX = heap ptr, AX = offset. Charger l element }
  EmitInstr('ADD', 'BX, AX');
  EmitInstr('MOV', 'AX, [BX]');
  EmitComment('@' + SymTab[SIdx].Name + '[$idx] -> element');
  Res.Kind    := EK_AX;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_IDX_INT;
  Res.Offset  := 0;
End;

(* ---- ParseHashAccess : acces %h{$key} ou %h<key> ------------- *)
(* SIdx = index du symbole %h dans SymTab.                         *)
(* Appelle _RKRT_HLOOKUP avec AX=hash ptr, BX=key ptr.            *)
Procedure ParseHashAccess(SIdx : Integer;
                          Var Res : TExprVal);
Var
  E    : TExprVal;
  Lbl  : TString;
  S    : TString;
Begin
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
  Begin
    (* %h{$key} : acces avec expression *)
    ParserAdvance;
    ParseExpr(E);
    ExprFlushToAX(E);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
      ParserAdvance
    Else
      CompileError('''}'' attendue apres la clef du hash');
    { AX = clef. Pousser clef, charger hash ptr }
    EmitPush('AX');
    If (SIdx >= 0) And (SIdx < SymCount) Then
    Begin
      If (SymTab[SIdx].Cat = SC_MY) Or (SymTab[SIdx].Cat = SC_PARAM) Then
      Begin
        Str(SymTab[SIdx].Offset, S);
        EmitInstr('MOV', 'AX, [BP-' + S + ']');
      End
      Else
        EmitInstr('MOV', 'AX, [' + SymTab[SIdx].MangledName + ']');
    End
    Else
      EmitInstr('XOR', 'AX, AX');
    EmitPush('AX');
    EmitInstr('CALL', '_RKRT_HLOOKUP');
    EmitInstr('ADD', 'SP, 4');
    EmitComment('%' + SymTab[SIdx].Name + '{key} -> lookup');
  End
  Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '<') Then
  Begin
    { %h<literal_key> : acces avec clef litterale }
    ParserAdvance;
    If CurToken.Kind = TK_IDENT Then
    Begin
      Lbl := DataAddStr(CurToken.Val);
      ParserAdvance;
    End
    Else
    Begin
      CompileError('clef attendue apres ''<''');
      Lbl := DataAddStr('');
    End;
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '>') Then
      ParserAdvance
    Else
      CompileError('''>'' attendue apres la clef du hash');
    { Charger la clef litterale }
    EmitInstr('MOV', 'AX, OFFSET ' + Lbl);
    EmitPush('AX');
    If (SIdx >= 0) And (SIdx < SymCount) Then
    Begin
      If (SymTab[SIdx].Cat = SC_MY) Or (SymTab[SIdx].Cat = SC_PARAM) Then
      Begin
        Str(SymTab[SIdx].Offset, S);
        EmitInstr('MOV', 'AX, [BP-' + S + ']');
      End
      Else
        EmitInstr('MOV', 'AX, [' + SymTab[SIdx].MangledName + ']');
    End
    Else
      EmitInstr('XOR', 'AX, AX');
    EmitPush('AX');
    EmitInstr('CALL', '_RKRT_HLOOKUP');
    EmitInstr('ADD', 'SP, 4');
    EmitComment('%' + SymTab[SIdx].Name + '<key> -> lookup');
  End
  Else
  Begin
    EmitComment('% acces sans {} ni <> (stub)');
  End;
  Res.Kind    := EK_AX;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_IDX_INT;
  Res.Offset  := 0;
End;

(* ---- ParsePostfix : chaine de postfixes .method / [idx] / (key) - *)
(* Apres le parsage d une expression primaire, traite les postfixes  *)
(* enchaines : $obj.method(args), $obj.attr, @arr[$i], %h{$k}.      *)
Procedure ParsePostfix(Var Res : TExprVal);
Var
  MethName  : TString;
  CIdx      : Integer;
  MIdx      : Integer;
  AIdx      : Integer;
  MI        : Integer;
  ArgCount  : Integer;
  E         : TExprVal;
  OfsStr    : TString;
  PName     : TString;
  Lbl       : TString;
  TS        : TString;
  SaveCIdx  : Integer;
Begin
  { Boucle pour supporter les chaines : $obj.meth1.meth2 }
  While True Do
  Begin
    { --- .ident : acces attribut ou appel methode --- }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '.') Then
    Begin
      ExprFlushToAX(Res);
      ParserAdvance;   { consommer '.' }
      If CurToken.Kind = TK_IDENT Then
      Begin
        MethName := CurToken.Val;
        ParserAdvance;   { consommer le nom }
        { Dispatch vers ParseArrayMethodCall si type tableau }
        If Res.TypeIdx = TY_IDX_ARRAY Then
        Begin
          ParseArrayMethodCall(-1, MethName, Res);
        End
        { Dispatch vers ParseHashMethodCall si type hash }
        Else If Res.TypeIdx = TY_IDX_HASH Then
        Begin
          ParseHashMethodCall(-1, MethName, Res);
        End
        { Dispatch vers methode/attribut de classe (TODO 19) }
        Else If Res.TypeIdx = TY_IDX_CLASS Then
        Begin
          CIdx := Res.Offset;
          SaveCIdx := CIdx;
          If (CIdx >= 0) And (CIdx < ClassCount) Then
          Begin
            { Chercher une methode }
            MIdx := -1;
            For MI := 0 To ClassTab[CIdx].MethCount - 1 Do
              If ClassTab[CIdx].Meths[MI].Name = MethName Then
              Begin MIdx := MI; Break; End;
            { Chercher un attribut }
            AIdx := -1;
            For MI := 0 To ClassTab[CIdx].AttrCount - 1 Do
              If ClassTab[CIdx].Attrs[MI].Name = MethName Then
              Begin AIdx := MI; Break; End;
            If (MIdx >= 0) And (CurToken.Kind = TK_PUNCT) And
               (CurToken.Val = '(') Then
            Begin
              { Appel de methode de classe }
              Lbl := ClassTab[CIdx].Meths[MIdx].LblName;
              ArgCount := 0;
              EmitPush('AX');   { push self }
              Inc(ArgCount);
              ParserAdvance;   { consommer '(' }
              If Not ((CurToken.Kind = TK_PUNCT) And
                      (CurToken.Val = ')')) Then
              Begin
                Repeat
                  ParseExpr(E);
                  ExprFlushToAX(E);
                  EmitPush('AX');
                  Inc(ArgCount);
                  If (CurToken.Kind = TK_PUNCT) And
                     (CurToken.Val = ',') Then
                    ParserAdvance
                  Else
                    Break;
                Until CurToken.Kind = TK_EOF;
              End;
              If (CurToken.Kind = TK_PUNCT) And
                 (CurToken.Val = ')') Then
                ParserAdvance;
              EmitInstr('CALL', Lbl);
              If ArgCount > 0 Then
                EmitInstr('ADD', 'SP, ' + IntToStr(ArgCount * 2));
              Res.Kind    := EK_AX;
              Res.ImmVal  := 0;
              Res.TypeIdx := TY_IDX_CLASS;
              Res.Offset  := SaveCIdx;
            End
            Else If AIdx >= 0 Then
            Begin
              { Acces attribut de classe via accesseur }
              Lbl := '_RKS_' + SymNameClean(ClassTab[CIdx].Name) +
                     '_' + SymNameClean(MethName);
              EmitPush('AX');
              EmitInstr('CALL', Lbl);
              EmitInstr('ADD', 'SP, 2');
              EmitComment('.attr ' + MethName);
              Res.Kind    := EK_AX;
              Res.ImmVal  := 0;
              Res.TypeIdx := ClassTab[CIdx].Attrs[AIdx].TypeIdx;
              Res.Offset  := 0;
            End
            Else
            Begin
              { Methode inconnue -> essai generique }
              If (CurToken.Kind = TK_PUNCT) And
                 (CurToken.Val = '(') Then
                ParseMethodCall(MethName, Res)
              Else
              Begin
                EmitPush('AX');
                EmitInstr('CALL', '_RKS_' + SymNameClean(MethName));
                EmitInstr('ADD', 'SP, 2');
                Res.Kind    := EK_AX;
                Res.ImmVal  := 0;
                Res.TypeIdx := TY_IDX_INT;
                Res.Offset  := 0;
              End;
            End;
          End
          Else
          Begin
            If (CurToken.Kind = TK_PUNCT) And
               (CurToken.Val = '(') Then
              ParseMethodCall(MethName, Res)
            Else
            Begin
              EmitPush('AX');
              EmitInstr('CALL', '_RKS_' + SymNameClean(MethName));
              EmitInstr('ADD', 'SP, 2');
              Res.Kind    := EK_AX;
              Res.ImmVal  := 0;
              Res.TypeIdx := TY_IDX_INT;
              Res.Offset  := 0;
            End;
          End;
        End
        Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          { Appel de methode .method(args) }
          ParseMethodCall(MethName, Res);
        End
        Else
        Begin
          { Acces attribut .attr : stub (CALL accessor) }
          EmitPush('AX');
          EmitInstr('CALL', '_RKS_' + SymNameClean(MethName));
          EmitInstr('ADD', 'SP, 2');
          EmitComment('.attr ' + MethName);
          Res.Kind    := EK_AX;
          Res.ImmVal  := 0;
          Res.TypeIdx := TY_IDX_INT;
          Res.Offset  := 0;
        End;
      End
      Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'new') Then
      Begin
        { Instanciation : Classe.new(args) }
        ParserAdvance;   { consommer new }
        If Res.TypeIdx = TY_IDX_CLASS Then
        Begin
          { Instanciation d une classe connue (TODO 19) }
          CIdx := Res.Offset;
          Str(ClassTab[CIdx].InstSize, TS);
          EmitComment('new ' + ClassTab[CIdx].Name);
          EmitInstr('MOV', 'CX, ' + TS);
          EmitInstr('CALL', '_RKRT_NEW');
          EmitInstr('MOV', 'BX, AX');
          EmitInstr('MOV', 'WORD PTR [BX], OFFSET ' +
                    ClassTab[CIdx].VtLbl);
          EmitInstr('MOV', 'WORD PTR [_RK_INSTPTR], AX');
          { Parametres nommes : (attr => val, ...) }
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          Begin
            ParserAdvance;   { consommer '(' }
            While Not ((CurToken.Kind = TK_PUNCT) And
                       (CurToken.Val = ')')) And
                  (CurToken.Kind <> TK_EOF) Do
            Begin
              If CurToken.Kind = TK_IDENT Then
              Begin
                PName := CurToken.Val;
                ParserAdvance;
                If (CurToken.Kind = TK_OP) And
                   (CurToken.Val = '=>') Then
                Begin
                  ParserAdvance;   { consommer '=>' }
                  ParseExpr(E);
                  ExprFlushToAX(E);
                  { Trouver l offset de l attribut }
                  AIdx := -1;
                  For MI := 0 To ClassTab[CIdx].AttrCount - 1 Do
                    If ClassTab[CIdx].Attrs[MI].Name = PName Then
                    Begin AIdx := MI; Break; End;
                  If AIdx >= 0 Then
                  Begin
                    Str(ClassTab[CIdx].Attrs[AIdx].Offset, OfsStr);
                    EmitInstr('MOV',
                      'BX, WORD PTR [_RK_INSTPTR]');
                    EmitInstr('MOV',
                      'WORD PTR [BX+' + OfsStr + '], AX');
                    { Mettre a jour le type de l attribut }
                    If E.TypeIdx <> TY_UNKNOWN Then
                      ClassTab[CIdx].Attrs[AIdx].TypeIdx :=
                        E.TypeIdx;
                  End
                  Else
                    WarnMsg('attribut inconnu : ' + PName);
                End
                Else
                Begin
                  ParseExpr(E);
                  ExprFlushToAX(E);
                End;
              End
              Else
              Begin
                ParseExpr(E);
                ExprFlushToAX(E);
              End;
              If (CurToken.Kind = TK_PUNCT) And
                 (CurToken.Val = ',') Then
                ParserAdvance
              Else
                Break;
            End;
            If (CurToken.Kind = TK_PUNCT) And
               (CurToken.Val = ')') Then
              ParserAdvance;
          End;
          EmitInstr('MOV', 'AX, WORD PTR [_RK_INSTPTR]');
          Res.Kind    := EK_AX;
          Res.ImmVal  := 0;
          Res.TypeIdx := TY_IDX_CLASS;
          Res.Offset  := CIdx;
        End
        Else If (CurToken.Kind = TK_PUNCT) And
                (CurToken.Val = '(') Then
        Begin
          ParseMethodCall('new', Res);
        End
        Else
        Begin
          EmitComment('.new sans arguments');
          EmitPush('AX');
          EmitInstr('CALL', '_RKS_new');
          EmitInstr('ADD', 'SP, 2');
          Res.Kind    := EK_AX;
          Res.ImmVal  := 0;
          Res.TypeIdx := TY_IDX_INT;
          Res.Offset  := 0;
        End;
      End
      Else
      Begin
        CompileError('identifiant attendu apres ''.''');
        Break;
      End;
    End
    Else
      Break;
  End;
End;

{ ---- ParsePairExpr : construction de paire clef => valeur ------ }
{ Detecte par ParsePrimary quand un TK_IDENT est suivi de '=>'.    }
{ Resultat : AX = pointeur vers Pair (stub : DW key, DW val).     }
Procedure ParsePairExpr(Const Key : TString;
                        Var Res : TExprVal);
Var
  E    : TExprVal;
  KLbl : TString;
Begin
  { Consommer '=>' }
  ParserAdvance;
  { La clef est un litteral chaine }
  KLbl := DataAddStr(Key);
  { Evaluer la valeur }
  ParseExpr(E);
  ExprFlushToAX(E);
  { Pousser valeur puis clef, creer Pair }
  EmitPush('AX');
  EmitInstr('MOV', 'AX, OFFSET ' + KLbl);
  EmitPush('AX');
  EmitComment('Pair : ' + Key + ' => value (stub)');
  { Stub : laisser AX = pointeur Pair (on recupere simplement la valeur) }
  EmitPop('AX');      { AX = ptr clef (stub) }
  EmitPop('AX');      { AX = valeur }
  Res.Kind    := EK_AX;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_IDX_PAIR;
  Res.Offset  := 0;
End;

{ ============================================================
  TODO 15 - TABLEAUX ET LISTES [IMPLEMENTE]
  ParseArrayLiteral, ParseArrayMethodCall, EmitArrayRuntime
  ============================================================ }

{ ---- ParseArrayLiteral : parser (e1, e2, ...) -> heap array --- }
{ Alloue un bloc sur le heap _RK_HEAP avec layout :               }
{   [count:DW] [elem0:DW] [elem1:DW] ... [elemN:DW]              }
{ Retourne le pointeur vers le bloc dans AX.                      }
Procedure ParseArrayLiteral(Var Res : TExprVal);
Var
  Elems : Array[0..63] Of LongInt;
  ECount : Integer;
  I      : Integer;
  E      : TExprVal;
  AllImm : Boolean;
  Lbl    : TString;
Begin
  ECount := 0;
  AllImm := True;
  { '(' deja consomme par l appelant }
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
  Begin
    Repeat
      ParseExpr(E);
      If (E.Kind = EK_IMM) And AllImm And (ECount < 64) Then
        Elems[ECount] := E.ImmVal
      Else
      Begin
        { Si on avait des immediats avant, les flusher sur la pile }
        If AllImm And (ECount > 0) Then
        Begin
          For I := 0 To ECount - 1 Do
          Begin
            EmitInstr('MOV', 'AX, ' + IntToStr(Elems[I]));
            EmitPush('AX');
          End;
        End;
        AllImm := False;
        ExprFlushToAX(E);
        EmitPush('AX');
      End;
      Inc(ECount);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance
      Else
        Break;
    Until CurToken.Kind = TK_EOF;
  End;
  { Consommer ')' }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance
  Else
    CompileError(''')'' attendue apres liste tableau');
  { Allouer le bloc sur le heap }
  Inc(ArrayTempCount);
  Lbl := '_RKL_AT' + IntToStr(ArrayTempCount);
  EmitComment('array literal (' + IntToStr(ECount) + ' elems)');
  { BX = _RK_HEAPTOP (pointeur courant du heap) }
  EmitInstr('MOV', 'BX, [_RK_HEAPTOP]');
  { Stocker le nombre d elements comme premier mot }
  EmitInstr('MOV', 'WORD PTR [BX], ' + IntToStr(ECount));
  If AllImm Then
  Begin
    { Tous les elements sont des immediats : ecrire directement }
    For I := 0 To ECount - 1 Do
      EmitInstr('MOV', 'WORD PTR [BX+' + IntToStr((I + 1) * 2) + '], ' +
                IntToStr(Elems[I]));
  End
  Else
  Begin
    { Les elements sont sur la pile (dans l ordre inverse) }
    { Depiler dans l ordre inverse pour remplir le tableau }
    For I := ECount - 1 DownTo 0 Do
    Begin
      EmitPop('AX');
      EmitInstr('MOV', 'WORD PTR [BX+' + IntToStr((I + 1) * 2) + '], AX');
    End;
  End;
  { Avancer le heap pointer }
  EmitInstr('ADD', 'WORD PTR [_RK_HEAPTOP], ' +
            IntToStr((ECount + 1) * 2));
  { AX = pointeur vers le debut du bloc (count) }
  EmitInstr('MOV', 'AX, BX');
  Res.Kind    := EK_AX;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_IDX_ARRAY;
  Res.Offset  := 0;
End;

{ ---- ParseArrayMethodCall : .method() sur un tableau ----------- }
{ SIdx = index du symbole @arr, MethName = nom de la methode.      }
{ AX contient deja le pointeur vers le bloc tableau.               }
Procedure ParseArrayMethodCall(SIdx : Integer;
                               Const MethName : TString;
                               Var Res : TExprVal);
Var
  E   : TExprVal;
Begin
  Res.Kind    := EK_AX;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_IDX_INT;
  Res.Offset  := 0;
  { --- .elems : nombre d elements --- }
  If MethName = 'elems' Then
  Begin
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        ParserAdvance;
    End;
    EmitInstr('MOV', 'BX, AX');
    EmitInstr('MOV', 'AX, [BX]');
    EmitComment('.elems -> count');
    Exit;
  End;
  { --- .end : dernier indice (count - 1) --- }
  If MethName = 'end' Then
  Begin
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        ParserAdvance;
    End;
    EmitInstr('MOV', 'BX, AX');
    EmitInstr('MOV', 'AX, [BX]');
    EmitInstr('DEC', 'AX');
    EmitComment('.end -> count-1');
    Exit;
  End;
  { --- .push($x) : ajout en fin --- }
  If MethName = 'push' Then
  Begin
    EmitPush('AX');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      ParserAdvance;
      ParseExpr(E);
      ExprFlushToAX(E);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        ParserAdvance;
    End;
    { AX = valeur, pile = arr ptr }
    EmitInstr('MOV', 'CX, AX');
    EmitPop('BX');
    EmitInstr('CALL', '_RKRT_ARRPUSH');
    EmitComment('.push(val)');
    Exit;
  End;
  { --- .pop : retrait en fin --- }
  If MethName = 'pop' Then
  Begin
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        ParserAdvance;
    End;
    EmitInstr('MOV', 'BX, AX');
    EmitInstr('CALL', '_RKRT_ARRPOP');
    EmitComment('.pop -> AX');
    Exit;
  End;
  { --- .shift : retrait en debut --- }
  If MethName = 'shift' Then
  Begin
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        ParserAdvance;
    End;
    EmitInstr('MOV', 'BX, AX');
    EmitInstr('CALL', '_RKRT_ARRSHIFT');
    EmitComment('.shift -> AX');
    Exit;
  End;
  { --- .unshift($x) : ajout en debut --- }
  If MethName = 'unshift' Then
  Begin
    EmitPush('AX');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      ParserAdvance;
      ParseExpr(E);
      ExprFlushToAX(E);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        ParserAdvance;
    End;
    EmitInstr('MOV', 'CX, AX');
    EmitPop('BX');
    EmitInstr('CALL', '_RKRT_ARRUNSHIFT');
    EmitComment('.unshift(val)');
    Exit;
  End;
  { --- .reverse : inverser le tableau --- }
  If MethName = 'reverse' Then
  Begin
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        ParserAdvance;
    End;
    EmitInstr('MOV', 'BX, AX');
    EmitInstr('CALL', '_RKRT_ARRREVERSE');
    EmitComment('.reverse');
    Exit;
  End;
  { --- .sort : trier le tableau (insertion sort) --- }
  If MethName = 'sort' Then
  Begin
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        ParserAdvance;
    End;
    EmitInstr('MOV', 'BX, AX');
    EmitInstr('CALL', '_RKRT_ARRSORT');
    EmitComment('.sort');
    Exit;
  End;
  { --- .join(sep) : joindre en chaine --- }
  If MethName = 'join' Then
  Begin
    EmitPush('AX');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      ParserAdvance;
      ParseExpr(E);
      ExprFlushToAX(E);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        ParserAdvance;
    End;
    { AX = sep ptr, pile = arr ptr }
    EmitInstr('MOV', 'SI, AX');
    EmitPop('BX');
    EmitInstr('CALL', '_RKRT_ARRJOIN');
    EmitComment('.join(sep) -> AX=str');
    Res.TypeIdx := TY_IDX_STR;
    Exit;
  End;
  { --- .grep / .map : stubs --- }
  If (MethName = 'grep') Or (MethName = 'map') Then
  Begin
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      ParserAdvance;
      { Consommer les arguments sans les traiter }
      If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
      Begin
        ParseExpr(E);
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        ParserAdvance;
    End;
    EmitComment('.' + MethName + ' (stub)');
    Res.TypeIdx := TY_IDX_ARRAY;
    Exit;
  End;
  { Methode inconnue : delegation a ParseMethodCall generique }
  EmitPush('AX');
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    ParseMethodCall(MethName, Res)
  Else
  Begin
    EmitComment('.attr ' + MethName + ' (array stub)');
  End;
End;

{ ---- EmitArrayRuntime : routines runtime pour les tableaux ----- }
{ _RKRT_ARRPUSH  : BX=arr, CX=val -> ajouter en fin               }
{ _RKRT_ARRPOP   : BX=arr -> AX=dernier element (retrait)         }
{ _RKRT_ARRSHIFT : BX=arr -> AX=premier element (retrait)         }
{ _RKRT_ARRUNSHIFT: BX=arr, CX=val -> inserer en debut            }
{ _RKRT_ARRREVERSE: BX=arr -> inverser en place                   }
{ _RKRT_ARRSORT  : BX=arr -> tri insertion en place                }
{ _RKRT_ARRJOIN  : BX=arr, SI=sep -> AX=STRBUF ptr                }
Procedure EmitArrayRuntime;
Begin
  EmitBlankLine;
  EmitComment('=== Runtime TABLEAUX (TODO 15) ===');
  EmitBlankLine;

  { _RKRT_ARRPUSH : BX=arr ptr, CX=value -> append }
  EmitComment('--- _RKRT_ARRPUSH : BX=arr, CX=val -> push ---');
  EmitRaw('_RKRT_ARRPUSH PROC NEAR');
  EmitRaw('        PUSH  SI');
  EmitRaw('        MOV   SI, [BX]');         { SI = count }
  EmitRaw('        INC   WORD PTR [BX]');    { count++ }
  EmitRaw('        SHL   SI, 1');            { SI = count*2 }
  EmitRaw('        ADD   SI, 2');            { skip count word }
  EmitRaw('        ADD   SI, BX');           { SI = addr of new slot }
  EmitRaw('        MOV   [SI], CX');         { store value }
  EmitRaw('        POP   SI');
  EmitRaw('        RET');
  EmitRaw('_RKRT_ARRPUSH ENDP');
  EmitBlankLine;

  { _RKRT_ARRPOP : BX=arr ptr -> AX=last element }
  EmitComment('--- _RKRT_ARRPOP : BX=arr -> AX=last ---');
  EmitRaw('_RKRT_ARRPOP PROC NEAR');
  EmitRaw('        PUSH  SI');
  EmitRaw('        MOV   SI, [BX]');         { SI = count }
  EmitRaw('        TEST  SI, SI');
  EmitRaw('        JZ    _RKRT_AP_Z');
  EmitRaw('        DEC   WORD PTR [BX]');    { count-- }
  EmitRaw('        SHL   SI, 1');            { SI = count*2 }
  EmitRaw('        MOV   AX, [BX+SI]');      { AX = last elem }
  EmitRaw('        POP   SI');
  EmitRaw('        RET');
  EmitRaw('_RKRT_AP_Z:');
  EmitRaw('        XOR   AX, AX');
  EmitRaw('        POP   SI');
  EmitRaw('        RET');
  EmitRaw('_RKRT_ARRPOP ENDP');
  EmitBlankLine;

  { _RKRT_ARRSHIFT : BX=arr ptr -> AX=first element (remove) }
  EmitComment('--- _RKRT_ARRSHIFT : BX=arr -> AX=first ---');
  EmitRaw('_RKRT_ARRSHIFT PROC NEAR');
  EmitRaw('        PUSH  SI');
  EmitRaw('        PUSH  DI');
  EmitRaw('        PUSH  CX');
  EmitRaw('        MOV   CX, [BX]');         { CX = count }
  EmitRaw('        TEST  CX, CX');
  EmitRaw('        JZ    _RKRT_AS_Z');
  EmitRaw('        MOV   AX, [BX+2]');       { AX = first elem }
  EmitRaw('        DEC   WORD PTR [BX]');    { count-- }
  EmitRaw('        DEC   CX');
  EmitRaw('        LEA   DI, [BX+2]');       { DI = slot 0 }
  EmitRaw('        LEA   SI, [BX+4]');       { SI = slot 1 }
  EmitRaw('        REP   MOVSW');            { shift left }
  EmitRaw('        POP   CX');
  EmitRaw('        POP   DI');
  EmitRaw('        POP   SI');
  EmitRaw('        RET');
  EmitRaw('_RKRT_AS_Z:');
  EmitRaw('        XOR   AX, AX');
  EmitRaw('        POP   CX');
  EmitRaw('        POP   DI');
  EmitRaw('        POP   SI');
  EmitRaw('        RET');
  EmitRaw('_RKRT_ARRSHIFT ENDP');
  EmitBlankLine;

  { _RKRT_ARRUNSHIFT : BX=arr ptr, CX=value -> insert at front }
  EmitComment('--- _RKRT_ARRUNSHIFT : BX=arr, CX=val -> unshift ---');
  EmitRaw('_RKRT_ARRUNSHIFT PROC NEAR');
  EmitRaw('        PUSH  SI');
  EmitRaw('        PUSH  DI');
  EmitRaw('        PUSH  CX');
  EmitRaw('        MOV   AX, [BX]');         { AX = count }
  EmitRaw('        INC   WORD PTR [BX]');    { count++ }
  { Shift elements right: from end to start }
  EmitRaw('        TEST  AX, AX');
  EmitRaw('        JZ    _RKRT_AU_INS');
  EmitRaw('        MOV   CX, AX');           { CX = old count }
  EmitRaw('        MOV   SI, AX');
  EmitRaw('        SHL   SI, 1');            { SI = count*2 }
  EmitRaw('        LEA   SI, [BX+SI]');      { SI = ptr to last elem }
  EmitRaw('        LEA   DI, [SI+2]');       { DI = ptr to new slot }
  EmitRaw('        STD');
  EmitRaw('        REP   MOVSW');
  EmitRaw('        CLD');
  EmitRaw('_RKRT_AU_INS:');
  EmitRaw('        POP   CX');
  EmitRaw('        MOV   [BX+2], CX');       { store new first elem }
  EmitRaw('        POP   DI');
  EmitRaw('        POP   SI');
  EmitRaw('        RET');
  EmitRaw('_RKRT_ARRUNSHIFT ENDP');
  EmitBlankLine;

  { _RKRT_ARRREVERSE : BX=arr ptr -> reverse in place }
  EmitComment('--- _RKRT_ARRREVERSE : BX=arr -> reverse ---');
  EmitRaw('_RKRT_ARRREVERSE PROC NEAR');
  EmitRaw('        PUSH  SI');
  EmitRaw('        PUSH  DI');
  EmitRaw('        MOV   CX, [BX]');         { CX = count }
  EmitRaw('        CMP   CX, 2');
  EmitRaw('        JB    _RKRT_ARV_DN');
  EmitRaw('        LEA   SI, [BX+2]');       { SI = first elem }
  EmitRaw('        MOV   DI, CX');
  EmitRaw('        SHL   DI, 1');
  EmitRaw('        LEA   DI, [BX+DI]');      { DI = past-last }
  EmitRaw('        SUB   DI, 2');            { DI = last elem }
  EmitRaw('_RKRT_ARV_LP:');
  EmitRaw('        CMP   SI, DI');
  EmitRaw('        JAE   _RKRT_ARV_DN');
  EmitRaw('        MOV   AX, [SI]');
  EmitRaw('        MOV   CX, [DI]');
  EmitRaw('        MOV   [SI], CX');
  EmitRaw('        MOV   [DI], AX');
  EmitRaw('        ADD   SI, 2');
  EmitRaw('        SUB   DI, 2');
  EmitRaw('        JMP   _RKRT_ARV_LP');
  EmitRaw('_RKRT_ARV_DN:');
  EmitRaw('        POP   DI');
  EmitRaw('        POP   SI');
  EmitRaw('        RET');
  EmitRaw('_RKRT_ARRREVERSE ENDP');
  EmitBlankLine;

  { _RKRT_ARRSORT : BX=arr ptr -> insertion sort in place }
  EmitComment('--- _RKRT_ARRSORT : BX=arr -> insertion sort ---');
  EmitRaw('_RKRT_ARRSORT PROC NEAR');
  EmitRaw('        PUSH  SI');
  EmitRaw('        PUSH  DI');
  EmitRaw('        PUSH  CX');
  EmitRaw('        PUSH  DX');
  EmitRaw('        MOV   CX, [BX]');         { CX = count }
  EmitRaw('        CMP   CX, 2');
  EmitRaw('        JB    _RKRT_AST_DN');
  EmitRaw('        MOV   SI, 1');            { SI = i = 1 }
  EmitRaw('_RKRT_AST_OT:');
  EmitRaw('        CMP   SI, CX');
  EmitRaw('        JAE   _RKRT_AST_DN');
  { DX = arr[i] (key) }
  EmitRaw('        MOV   DI, SI');
  EmitRaw('        SHL   DI, 1');
  EmitRaw('        MOV   DX, [BX+DI+2]');   { DX = key }
  { j = i }
  EmitRaw('        MOV   DI, SI');
  EmitRaw('_RKRT_AST_IN:');
  EmitRaw('        TEST  DI, DI');
  EmitRaw('        JZ    _RKRT_AST_PL');
  { compare arr[j-1] with key }
  EmitRaw('        MOV   AX, DI');
  EmitRaw('        DEC   AX');
  EmitRaw('        SHL   AX, 1');
  EmitRaw('        ADD   AX, 2');
  EmitRaw('        PUSH  BX');
  EmitRaw('        ADD   BX, AX');
  EmitRaw('        MOV   AX, [BX]');         { AX = arr[j-1] }
  EmitRaw('        POP   BX');
  EmitRaw('        CMP   AX, DX');
  EmitRaw('        JLE   _RKRT_AST_PL');
  { arr[j] = arr[j-1] }
  EmitRaw('        PUSH  DI');
  EmitRaw('        SHL   DI, 1');
  EmitRaw('        MOV   [BX+DI+2], AX');
  EmitRaw('        POP   DI');
  EmitRaw('        DEC   DI');
  EmitRaw('        JMP   _RKRT_AST_IN');
  EmitRaw('_RKRT_AST_PL:');
  { arr[j] = key }
  EmitRaw('        PUSH  DI');
  EmitRaw('        SHL   DI, 1');
  EmitRaw('        MOV   [BX+DI+2], DX');
  EmitRaw('        POP   DI');
  EmitRaw('        INC   SI');
  EmitRaw('        JMP   _RKRT_AST_OT');
  EmitRaw('_RKRT_AST_DN:');
  EmitRaw('        POP   DX');
  EmitRaw('        POP   CX');
  EmitRaw('        POP   DI');
  EmitRaw('        POP   SI');
  EmitRaw('        RET');
  EmitRaw('_RKRT_ARRSORT ENDP');
  EmitBlankLine;

  { _RKRT_ARRJOIN : BX=arr ptr, SI=sep ASCIIZ -> AX=STRBUF ptr }
  EmitComment('--- _RKRT_ARRJOIN : BX=arr, SI=sep -> AX=str ---');
  EmitRaw('_RKRT_ARRJOIN PROC NEAR');
  EmitRaw('        PUSH  DI');
  EmitRaw('        PUSH  CX');
  EmitRaw('        PUSH  DX');
  EmitRaw('        PUSH  BX');
  EmitRaw('        MOV   DI, OFFSET _RK_STRBUF');
  EmitRaw('        MOV   BYTE PTR [DI], 0');
  EmitRaw('        MOV   CX, [BX]');         { CX = count }
  EmitRaw('        TEST  CX, CX');
  EmitRaw('        JZ    _RKRT_AJ_DN');
  EmitRaw('        ADD   BX, 2');            { BX = first elem }
  EmitRaw('        XOR   DX, DX');           { DX = index }
  EmitRaw('_RKRT_AJ_LP:');
  { Ajouter le separateur si pas le premier }
  EmitRaw('        TEST  DX, DX');
  EmitRaw('        JZ    _RKRT_AJ_NOS');
  EmitRaw('        PUSH  SI');
  EmitRaw('        PUSH  CX');
  EmitRaw('        PUSH  BX');
  EmitRaw('        CALL  _RKRT_CONCAT');
  EmitRaw('        POP   BX');
  EmitRaw('        POP   CX');
  EmitRaw('        POP   SI');
  EmitRaw('_RKRT_AJ_NOS:');
  { Convertir l entier en chaine et concatener }
  EmitRaw('        PUSH  SI');
  EmitRaw('        PUSH  CX');
  EmitRaw('        PUSH  BX');
  EmitRaw('        PUSH  DX');
  EmitRaw('        MOV   AX, [BX]');         { AX = elem value }
  EmitRaw('        CALL  _RKRT_ITOA');
  { SI = _RK_NUMBUF (resultat de ITOA) }
  EmitRaw('        MOV   SI, AX');
  EmitRaw('        CALL  _RKRT_CONCAT');
  EmitRaw('        POP   DX');
  EmitRaw('        POP   BX');
  EmitRaw('        POP   CX');
  EmitRaw('        POP   SI');
  EmitRaw('        ADD   BX, 2');
  EmitRaw('        INC   DX');
  EmitRaw('        CMP   DX, CX');
  EmitRaw('        JB    _RKRT_AJ_LP');
  EmitRaw('_RKRT_AJ_DN:');
  EmitRaw('        MOV   AX, OFFSET _RK_STRBUF');
  EmitRaw('        POP   BX');
  EmitRaw('        POP   DX');
  EmitRaw('        POP   CX');
  EmitRaw('        POP   DI');
  EmitRaw('        RET');
  EmitRaw('_RKRT_ARRJOIN ENDP');
  EmitBlankLine;

  { _RKRT_ITOA : AX=entier -> AX=ptr NUMBUF (ASCIIZ) }
  EmitComment('--- _RKRT_ITOA : AX=int16 -> AX=NUMBUF ---');
  EmitRaw('_RKRT_ITOA PROC NEAR');
  EmitRaw('        PUSH  BX');
  EmitRaw('        PUSH  CX');
  EmitRaw('        PUSH  DX');
  EmitRaw('        PUSH  DI');
  EmitRaw('        LEA   DI, _RK_NUMBUF');
  EmitRaw('        MOV   BX, AX');
  EmitRaw('        TEST  AX, AX');
  EmitRaw('        JNS   _RKRT_IA_POS');
  EmitRaw('        MOV   BYTE PTR [DI], 2Dh');
  EmitRaw('        INC   DI');
  EmitRaw('        NEG   BX');
  EmitRaw('_RKRT_IA_POS:');
  EmitRaw('        MOV   AX, BX');
  EmitRaw('        XOR   CX, CX');
  EmitRaw('        MOV   BX, 10');
  EmitRaw('_RKRT_IA_DV:');
  EmitRaw('        XOR   DX, DX');
  EmitRaw('        DIV   BX');
  EmitRaw('        ADD   DL, 30h');
  EmitRaw('        PUSH  DX');
  EmitRaw('        INC   CX');
  EmitRaw('        TEST  AX, AX');
  EmitRaw('        JNZ   _RKRT_IA_DV');
  EmitRaw('_RKRT_IA_PP:');
  EmitRaw('        POP   DX');
  EmitRaw('        MOV   [DI], DL');
  EmitRaw('        INC   DI');
  EmitRaw('        DEC   CX');
  EmitRaw('        JNZ   _RKRT_IA_PP');
  EmitRaw('        MOV   BYTE PTR [DI], 0');
  EmitRaw('        MOV   AX, OFFSET _RK_NUMBUF');
  EmitRaw('        POP   DI');
  EmitRaw('        POP   DX');
  EmitRaw('        POP   CX');
  EmitRaw('        POP   BX');
  EmitRaw('        RET');
  EmitRaw('_RKRT_ITOA ENDP');
  EmitBlankLine;
End;

{ ============================================================
  TODO 16 - TABLES DE HACHAGE (Hash) - Implementation
  ============================================================ }

{ ---- ParseHashLiteral : parser (k1 => v1, k2 => v2, ...) ------- }
{ Alloue un bloc sur le heap _RK_HEAP avec layout :                 }
{   [paircount:DW] [key0ptr:DW][val0:DW] [key1ptr:DW][val1:DW] ... }
{ Retourne le pointeur vers le bloc dans AX.                        }
Procedure ParseHashLiteral(Var Res : TExprVal);
Var
  Keys  : Array[0..15] Of TString;
  Vals  : Array[0..15] Of LongInt;
  VIsImm: Array[0..15] Of Boolean;
  PCount: Integer;
  I     : Integer;
  E     : TExprVal;
  KName : TString;
  KLbl  : TString;
  AllImm: Boolean;
Begin
  PCount := 0;
  AllImm := True;
  { '(' deja consomme par l appelant }
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
  Begin
    Repeat
      { Clef : identifiant ou chaine }
      If CurToken.Kind = TK_IDENT Then
      Begin
        KName := CurToken.Val;
        ParserAdvance;
      End
      Else If CurToken.Kind = TK_STRING Then
      Begin
        KName := CurToken.Val;
        ParserAdvance;
      End
      Else
      Begin
        CompileError('clef attendue dans le litteral hash');
        KName := '';
        ParserAdvance;
      End;
      { Consommer => }
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '=>') Then
        ParserAdvance
      Else
        CompileError('''=> '' attendu apres la clef du hash');
      { Valeur }
      ParseExpr(E);
      If PCount < 16 Then
      Begin
        Keys[PCount] := KName;
        If (E.Kind = EK_IMM) And AllImm Then
        Begin
          Vals[PCount] := E.ImmVal;
          VIsImm[PCount] := True;
        End
        Else
        Begin
          If AllImm And (PCount > 0) Then
          Begin
            { Flusher les valeurs immediates precedentes sur la pile }
            For I := 0 To PCount - 1 Do
            Begin
              KLbl := DataAddStr(Keys[I]);
              EmitInstr('MOV', 'AX, OFFSET ' + KLbl);
              EmitPush('AX');
              EmitInstr('MOV', 'AX, ' + IntToStr(Vals[I]));
              EmitPush('AX');
            End;
          End;
          AllImm := False;
          VIsImm[PCount] := False;
          { Emettre clef + valeur sur la pile }
          ExprFlushToAX(E);
          EmitPush('AX');   { valeur }
          KLbl := DataAddStr(KName);
          EmitInstr('MOV', 'AX, OFFSET ' + KLbl);
          EmitPush('AX');   { clef }
        End;
      End;
      Inc(PCount);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance
      Else
        Break;
    Until CurToken.Kind = TK_EOF;
  End;
  { Consommer ')' }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance
  Else
    CompileError(''')'' attendue apres litteral hash');
  { Allouer le bloc sur le heap }
  Inc(HashTempCount);
  EmitComment('hash literal (' + IntToStr(PCount) + ' paires)');
  { BX = _RK_HEAPTOP (pointeur courant du heap) }
  EmitInstr('MOV', 'BX, [_RK_HEAPTOP]');
  { Stocker le nombre de paires comme premier mot }
  EmitInstr('MOV', 'WORD PTR [BX], ' + IntToStr(PCount));
  If AllImm Then
  Begin
    { Toutes les paires sont statiques : ecrire directement }
    For I := 0 To PCount - 1 Do
    Begin
      KLbl := DataAddStr(Keys[I]);
      EmitInstr('MOV', 'WORD PTR [BX+' + IntToStr(I * 4 + 2) + '], OFFSET ' + KLbl);
      EmitInstr('MOV', 'WORD PTR [BX+' + IntToStr(I * 4 + 4) + '], ' +
                IntToStr(Vals[I]));
    End;
  End
  Else
  Begin
    { Les paires sont sur la pile (clef, val empilees par paire) }
    { Pile (du sommet) : keyN, valN, ... key0, val0 }
    For I := PCount - 1 DownTo 0 Do
    Begin
      EmitPop('AX');   { clef ptr }
      EmitInstr('MOV', 'WORD PTR [BX+' + IntToStr(I * 4 + 2) + '], AX');
      EmitPop('AX');   { valeur }
      EmitInstr('MOV', 'WORD PTR [BX+' + IntToStr(I * 4 + 4) + '], AX');
    End;
  End;
  { Avancer le heap pointer : count(2) + paires(PCount*4) }
  EmitInstr('ADD', 'WORD PTR [_RK_HEAPTOP], ' +
            IntToStr(PCount * 4 + 2));
  { AX = pointeur vers le debut du bloc }
  EmitInstr('MOV', 'AX, BX');
  Res.Kind    := EK_AX;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_IDX_HASH;
  Res.Offset  := 0;
End;

{ ---- ParseHashMethodCall : appel de methode sur un hash --------- }
{ AX contient deja le pointeur hash. MethName = nom de la methode.  }
Procedure ParseHashMethodCall(SIdx : Integer;
                              Const MethName : TString;
                              Var Res : TExprVal);
Begin
  Res.Kind    := EK_AX;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_IDX_INT;
  Res.Offset  := 0;
  { --- .elems : nombre de paires --- }
  If MethName = 'elems' Then
  Begin
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        ParserAdvance;
    End;
    EmitInstr('MOV', 'BX, AX');
    EmitInstr('MOV', 'AX, [BX]');
    EmitComment('.elems -> pair count');
    Exit;
  End;
  { --- .keys : tableau des clefs --- }
  If MethName = 'keys' Then
  Begin
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        ParserAdvance;
    End;
    EmitInstr('MOV', 'BX, AX');
    EmitInstr('CALL', '_RKRT_HKEYS');
    EmitComment('.keys -> AX=array');
    Res.TypeIdx := TY_IDX_ARRAY;
    Exit;
  End;
  { --- .values : tableau des valeurs --- }
  If MethName = 'values' Then
  Begin
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        ParserAdvance;
    End;
    EmitInstr('MOV', 'BX, AX');
    EmitInstr('CALL', '_RKRT_HVALUES');
    EmitComment('.values -> AX=array');
    Res.TypeIdx := TY_IDX_ARRAY;
    Exit;
  End;
  { --- .pairs : stub --- }
  If MethName = 'pairs' Then
  Begin
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        ParserAdvance;
    End;
    EmitComment('.pairs (stub)');
    Res.TypeIdx := TY_IDX_ARRAY;
    Exit;
  End;
  { --- .kv : stub --- }
  If MethName = 'kv' Then
  Begin
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        ParserAdvance;
    End;
    EmitComment('.kv (stub)');
    Res.TypeIdx := TY_IDX_ARRAY;
    Exit;
  End;
  { --- .exists(key) : test d existence --- }
  If MethName = 'exists' Then
  Begin
    EmitPush('AX');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      ParserAdvance;
      ParseExpr(Res);
      ExprFlushToAX(Res);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        ParserAdvance;
    End;
    EmitInstr('MOV', 'SI, AX');
    EmitPop('BX');
    EmitInstr('CALL', '_RKRT_HEXISTS');
    EmitComment('.exists(key) -> AX=0|1');
    Res.Kind    := EK_AX;
    Res.ImmVal  := 0;
    Res.TypeIdx := TY_IDX_BOOL;
    Res.Offset  := 0;
    Exit;
  End;
  { --- .delete(key) : suppression --- }
  If MethName = 'delete' Then
  Begin
    EmitPush('AX');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      ParserAdvance;
      ParseExpr(Res);
      ExprFlushToAX(Res);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        ParserAdvance;
    End;
    EmitInstr('MOV', 'SI, AX');
    EmitPop('BX');
    EmitInstr('CALL', '_RKRT_HDELETE');
    EmitComment('.delete(key)');
    Res.Kind    := EK_AX;
    Res.ImmVal  := 0;
    Res.TypeIdx := TY_IDX_INT;
    Res.Offset  := 0;
    Exit;
  End;
  { Methode inconnue : delegation a ParseMethodCall generique }
  EmitPush('AX');
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    ParseMethodCall(MethName, Res)
  Else
  Begin
    EmitComment('.attr ' + MethName + ' (hash stub)');
  End;
End;

{ ---- ParseHashStore : pct-h(key) = val ou pct-h<key> = val ------ }
{ SIdx = index du symbole pct-h. Le token courant est curly ou <.  }
Procedure ParseHashStore(SIdx : Integer);
Var
  E    : TExprVal;
  Lbl  : TString;
  S    : TString;
Begin
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
  Begin
    (* pct-h curly-expr = val *)
    ParserAdvance;   (* consommer curly-open *)
    ParseExpr(E);
    ExprFlushToAX(E);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
      ParserAdvance
    Else
      CompileError('''}'' attendue apres la clef');
    EmitPush('AX');   (* sauver clef *)
  End
  Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '<') Then
  Begin
    { %h<literal> = val }
    ParserAdvance;
    If CurToken.Kind = TK_IDENT Then
    Begin
      Lbl := DataAddStr(CurToken.Val);
      ParserAdvance;
    End
    Else
    Begin
      CompileError('clef attendue apres ''<''');
      Lbl := DataAddStr('');
    End;
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '>') Then
      ParserAdvance
    Else
      CompileError('''>'' attendue apres la clef');
    EmitInstr('MOV', 'AX, OFFSET ' + Lbl);
    EmitPush('AX');   (* sauver clef *)
  End
  Else
  Begin
    CompileError('acces hash attendu');
    Exit;
  End;
  (* Consommer = *)
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
    ParserAdvance
  Else
  Begin
    CompileError('''='' attendu apres l acces hash');
    EmitPop('AX');
    Exit;
  End;
  (* Parser la valeur *)
  ParseExpr(E);
  ExprFlushToAX(E);
  (* AX = valeur, pile = clef ptr *)
  (* Charger hash ptr dans BX *)
  EmitPush('AX');   (* sauver valeur *)
  If (SIdx >= 0) And (SIdx < SymCount) Then
  Begin
    If (SymTab[SIdx].Cat = SC_MY) Or (SymTab[SIdx].Cat = SC_PARAM) Then
    Begin
      Str(SymTab[SIdx].Offset, S);
      EmitInstr('MOV', 'BX, [BP-' + S + ']');
    End
    Else
      EmitInstr('MOV', 'BX, [' + SymTab[SIdx].MangledName + ']');
  End
  Else
    EmitInstr('XOR', 'BX, BX');
  EmitPop('AX');    (* valeur *)
  EmitPop('SI');    (* clef ptr *)
  EmitInstr('CALL', '_RKRT_HSTORE');
  EmitComment('% hash store');
End;

{ ---- EmitHashRuntime : routines runtime pour les hash ----------- }
{ _RKRT_HLOOKUP : pile=[hash_ptr][key_ptr] -> AX=valeur            }
{ _RKRT_HSTORE  : BX=hash, SI=key, AX=val -> stocke/ajoute         }
{ _RKRT_HEXISTS : BX=hash, SI=key -> AX=0|1                        }
{ _RKRT_HDELETE : BX=hash, SI=key -> supprime la paire             }
{ _RKRT_HKEYS   : BX=hash -> AX=new array of keys on heap          }
{ _RKRT_HVALUES : BX=hash -> AX=new array of values on heap        }
Procedure EmitHashRuntime;
Begin
  EmitBlankLine;
  EmitComment('=== Runtime HASH (TODO 16) ===');
  EmitBlankLine;

  { _RKRT_HLOOKUP : stack-based lookup }
  { [SP+2]=hash_ptr, [SP+4]=key_ptr -> AX=value }
  EmitComment('--- _RKRT_HLOOKUP : [SP+2]=hash, [SP+4]=key -> AX ---');
  EmitRaw('_RKRT_HLOOKUP PROC NEAR');
  EmitRaw('        PUSH  BP');
  EmitRaw('        MOV   BP, SP');
  EmitRaw('        PUSH  SI');
  EmitRaw('        PUSH  DI');
  EmitRaw('        PUSH  CX');
  EmitRaw('        MOV   BX, [BP+4]');       { BX = hash ptr }
  EmitRaw('        MOV   DI, [BP+6]');       { DI = key ptr }
  EmitRaw('        MOV   CX, [BX]');         { CX = pair count }
  EmitRaw('        ADD   BX, 2');            { skip count word }
  EmitRaw('        TEST  CX, CX');
  EmitRaw('        JZ    _RKRT_HL_NF');
  EmitRaw('_RKRT_HL_LOOP:');
  EmitRaw('        PUSH  CX');
  EmitRaw('        PUSH  BX');
  EmitRaw('        MOV   SI, [BX]');         { SI = stored key ptr }
  { compare SI vs DI byte by byte }
  EmitRaw('_RKRT_HL_CMP:');
  EmitRaw('        MOV   AL, [SI]');
  EmitRaw('        MOV   AH, [DI]');
  EmitRaw('        CMP   AL, AH');
  EmitRaw('        JNE   _RKRT_HL_NEXT');
  EmitRaw('        TEST  AL, AL');
  EmitRaw('        JZ    _RKRT_HL_FOUND');
  EmitRaw('        INC   SI');
  EmitRaw('        INC   DI');
  EmitRaw('        JMP   _RKRT_HL_CMP');
  EmitRaw('_RKRT_HL_NEXT:');
  { restore DI to original key ptr }
  EmitRaw('        MOV   DI, [BP+6]');
  EmitRaw('        POP   BX');
  EmitRaw('        POP   CX');
  EmitRaw('        ADD   BX, 4');            { next pair }
  EmitRaw('        DEC   CX');
  EmitRaw('        JNZ   _RKRT_HL_LOOP');
  EmitRaw('_RKRT_HL_NF:');
  EmitRaw('        XOR   AX, AX');           { not found -> 0 }
  EmitRaw('        JMP   _RKRT_HL_END');
  EmitRaw('_RKRT_HL_FOUND:');
  EmitRaw('        POP   BX');
  EmitRaw('        POP   CX');
  EmitRaw('        MOV   AX, [BX+2]');       { AX = value }
  EmitRaw('_RKRT_HL_END:');
  EmitRaw('        POP   CX');
  EmitRaw('        POP   DI');
  EmitRaw('        POP   SI');
  EmitRaw('        POP   BP');
  EmitRaw('        RET');
  EmitRaw('_RKRT_HLOOKUP ENDP');
  EmitBlankLine;

  { _RKRT_HSTORE : BX=hash, SI=key, AX=value -> store/append }
  EmitComment('--- _RKRT_HSTORE : BX=hash, SI=key, AX=val ---');
  EmitRaw('_RKRT_HSTORE PROC NEAR');
  EmitRaw('        PUSH  DI');
  EmitRaw('        PUSH  CX');
  EmitRaw('        PUSH  DX');
  EmitRaw('        MOV   DX, AX');           { DX = value }
  EmitRaw('        MOV   DI, BX');           { DI = hash base }
  EmitRaw('        MOV   CX, [BX]');         { CX = pair count }
  EmitRaw('        ADD   BX, 2');            { skip count }
  EmitRaw('        TEST  CX, CX');
  EmitRaw('        JZ    _RKRT_HS_ADD');
  EmitRaw('        PUSH  CX');
  EmitRaw('_RKRT_HS_LOOP:');
  EmitRaw('        PUSH  BX');
  EmitRaw('        PUSH  SI');
  EmitRaw('        PUSH  DI');
  EmitRaw('        MOV   DI, [BX]');         { DI = stored key }
  { compare SI vs DI }
  EmitRaw('_RKRT_HS_CMP:');
  EmitRaw('        MOV   AL, [SI]');
  EmitRaw('        MOV   AH, [DI]');
  EmitRaw('        CMP   AL, AH');
  EmitRaw('        JNE   _RKRT_HS_NXT');
  EmitRaw('        TEST  AL, AL');
  EmitRaw('        JZ    _RKRT_HS_UPD');
  EmitRaw('        INC   SI');
  EmitRaw('        INC   DI');
  EmitRaw('        JMP   _RKRT_HS_CMP');
  EmitRaw('_RKRT_HS_NXT:');
  EmitRaw('        POP   DI');
  EmitRaw('        POP   SI');
  EmitRaw('        POP   BX');
  EmitRaw('        ADD   BX, 4');
  EmitRaw('        DEC   CX');
  EmitRaw('        JNZ   _RKRT_HS_LOOP');
  EmitRaw('        POP   CX');              { restore original count }
  EmitRaw('        JMP   _RKRT_HS_ADD');
  EmitRaw('_RKRT_HS_UPD:');
  { Found : update value in place }
  EmitRaw('        POP   DI');
  EmitRaw('        POP   SI');
  EmitRaw('        POP   BX');
  EmitRaw('        MOV   [BX+2], DX');       { update value }
  EmitRaw('        POP   CX');              { discard saved count }
  EmitRaw('        JMP   _RKRT_HS_DONE');
  EmitRaw('_RKRT_HS_ADD:');
  { BX points past last pair. DI = hash base. }
  EmitRaw('        MOV   [BX], SI');         { store key ptr }
  EmitRaw('        MOV   [BX+2], DX');       { store value }
  EmitRaw('        INC   WORD PTR [DI]');    { paircount++ }
  EmitRaw('        ADD   WORD PTR [_RK_HEAPTOP], 4');
  EmitRaw('_RKRT_HS_DONE:');
  EmitRaw('        POP   DX');
  EmitRaw('        POP   CX');
  EmitRaw('        POP   DI');
  EmitRaw('        RET');
  EmitRaw('_RKRT_HSTORE ENDP');
  EmitBlankLine;

  { _RKRT_HEXISTS : BX=hash, SI=key -> AX=0|1 }
  EmitComment('--- _RKRT_HEXISTS : BX=hash, SI=key -> AX=0|1 ---');
  EmitRaw('_RKRT_HEXISTS PROC NEAR');
  EmitRaw('        PUSH  DI');
  EmitRaw('        PUSH  CX');
  EmitRaw('        MOV   CX, [BX]');
  EmitRaw('        ADD   BX, 2');
  EmitRaw('        TEST  CX, CX');
  EmitRaw('        JZ    _RKRT_HE_NF');
  EmitRaw('_RKRT_HE_LOOP:');
  EmitRaw('        PUSH  CX');
  EmitRaw('        PUSH  BX');
  EmitRaw('        PUSH  SI');
  EmitRaw('        MOV   DI, [BX]');
  EmitRaw('_RKRT_HE_CMP:');
  EmitRaw('        MOV   AL, [SI]');
  EmitRaw('        MOV   AH, [DI]');
  EmitRaw('        CMP   AL, AH');
  EmitRaw('        JNE   _RKRT_HE_NXT');
  EmitRaw('        TEST  AL, AL');
  EmitRaw('        JZ    _RKRT_HE_YES');
  EmitRaw('        INC   SI');
  EmitRaw('        INC   DI');
  EmitRaw('        JMP   _RKRT_HE_CMP');
  EmitRaw('_RKRT_HE_NXT:');
  EmitRaw('        POP   SI');
  EmitRaw('        POP   BX');
  EmitRaw('        POP   CX');
  EmitRaw('        ADD   BX, 4');
  EmitRaw('        DEC   CX');
  EmitRaw('        JNZ   _RKRT_HE_LOOP');
  EmitRaw('_RKRT_HE_NF:');
  EmitRaw('        XOR   AX, AX');
  EmitRaw('        JMP   _RKRT_HE_END');
  EmitRaw('_RKRT_HE_YES:');
  EmitRaw('        POP   SI');
  EmitRaw('        POP   BX');
  EmitRaw('        POP   CX');
  EmitRaw('        MOV   AX, 1');
  EmitRaw('_RKRT_HE_END:');
  EmitRaw('        POP   CX');
  EmitRaw('        POP   DI');
  EmitRaw('        RET');
  EmitRaw('_RKRT_HEXISTS ENDP');
  EmitBlankLine;

  { _RKRT_HDELETE : BX=hash, SI=key -> remove pair }
  EmitComment('--- _RKRT_HDELETE : BX=hash, SI=key ---');
  EmitRaw('_RKRT_HDELETE PROC NEAR');
  EmitRaw('        PUSH  DI');
  EmitRaw('        PUSH  CX');
  EmitRaw('        PUSH  DX');
  EmitRaw('        MOV   DX, BX');           { DX = hash base }
  EmitRaw('        MOV   CX, [BX]');
  EmitRaw('        ADD   BX, 2');
  EmitRaw('        TEST  CX, CX');
  EmitRaw('        JZ    _RKRT_HD_END');
  EmitRaw('_RKRT_HD_LOOP:');
  EmitRaw('        PUSH  CX');
  EmitRaw('        PUSH  BX');
  EmitRaw('        PUSH  SI');
  EmitRaw('        MOV   DI, [BX]');
  EmitRaw('_RKRT_HD_CMP:');
  EmitRaw('        MOV   AL, [SI]');
  EmitRaw('        MOV   AH, [DI]');
  EmitRaw('        CMP   AL, AH');
  EmitRaw('        JNE   _RKRT_HD_NXT');
  EmitRaw('        TEST  AL, AL');
  EmitRaw('        JZ    _RKRT_HD_FND');
  EmitRaw('        INC   SI');
  EmitRaw('        INC   DI');
  EmitRaw('        JMP   _RKRT_HD_CMP');
  EmitRaw('_RKRT_HD_NXT:');
  EmitRaw('        POP   SI');
  EmitRaw('        POP   BX');
  EmitRaw('        POP   CX');
  EmitRaw('        ADD   BX, 4');
  EmitRaw('        DEC   CX');
  EmitRaw('        JNZ   _RKRT_HD_LOOP');
  EmitRaw('        JMP   _RKRT_HD_END');
  EmitRaw('_RKRT_HD_FND:');
  EmitRaw('        POP   SI');
  EmitRaw('        POP   BX');
  EmitRaw('        POP   CX');
  { Shift remaining pairs left by 4 bytes }
  EmitRaw('        DEC   CX');
  EmitRaw('        TEST  CX, CX');
  EmitRaw('        JZ    _RKRT_HD_DEC');
  EmitRaw('        PUSH  SI');
  EmitRaw('        MOV   SI, BX');
  EmitRaw('        ADD   SI, 4');
  EmitRaw('_RKRT_HD_SH:');
  EmitRaw('        MOV   AX, [SI]');
  EmitRaw('        MOV   [BX], AX');
  EmitRaw('        MOV   AX, [SI+2]');
  EmitRaw('        MOV   [BX+2], AX');
  EmitRaw('        ADD   BX, 4');
  EmitRaw('        ADD   SI, 4');
  EmitRaw('        DEC   CX');
  EmitRaw('        JNZ   _RKRT_HD_SH');
  EmitRaw('        POP   SI');
  EmitRaw('_RKRT_HD_DEC:');
  EmitRaw('        MOV   BX, DX');           { BX = hash base }
  EmitRaw('        DEC   WORD PTR [BX]');    { paircount-- }
  EmitRaw('        SUB   WORD PTR [_RK_HEAPTOP], 4');
  EmitRaw('_RKRT_HD_END:');
  EmitRaw('        POP   DX');
  EmitRaw('        POP   CX');
  EmitRaw('        POP   DI');
  EmitRaw('        RET');
  EmitRaw('_RKRT_HDELETE ENDP');
  EmitBlankLine;

  { _RKRT_HKEYS : BX=hash -> AX=new array of keys on heap }
  EmitComment('--- _RKRT_HKEYS : BX=hash -> AX=array of keys ---');
  EmitRaw('_RKRT_HKEYS PROC NEAR');
  EmitRaw('        PUSH  SI');
  EmitRaw('        PUSH  CX');
  EmitRaw('        PUSH  DI');
  EmitRaw('        MOV   CX, [BX]');         { CX = pair count }
  EmitRaw('        MOV   DI, [_RK_HEAPTOP]');{ DI = new array base }
  EmitRaw('        MOV   [DI], CX');         { store count }
  EmitRaw('        ADD   BX, 2');            { skip hash count }
  EmitRaw('        MOV   SI, DI');
  EmitRaw('        ADD   SI, 2');            { SI = first elem slot }
  EmitRaw('        TEST  CX, CX');
  EmitRaw('        JZ    _RKRT_HK_DN');
  EmitRaw('_RKRT_HK_LP:');
  EmitRaw('        MOV   AX, [BX]');         { key ptr }
  EmitRaw('        MOV   [SI], AX');
  EmitRaw('        ADD   SI, 2');
  EmitRaw('        ADD   BX, 4');            { next pair }
  EmitRaw('        DEC   CX');
  EmitRaw('        JNZ   _RKRT_HK_LP');
  EmitRaw('_RKRT_HK_DN:');
  { Update heap top }
  EmitRaw('        MOV   [_RK_HEAPTOP], SI');
  EmitRaw('        MOV   AX, DI');           { AX = array ptr }
  EmitRaw('        POP   DI');
  EmitRaw('        POP   CX');
  EmitRaw('        POP   SI');
  EmitRaw('        RET');
  EmitRaw('_RKRT_HKEYS ENDP');
  EmitBlankLine;

  { _RKRT_HVALUES : BX=hash -> AX=new array of values on heap }
  EmitComment('--- _RKRT_HVALUES : BX=hash -> AX=array of values ---');
  EmitRaw('_RKRT_HVALUES PROC NEAR');
  EmitRaw('        PUSH  SI');
  EmitRaw('        PUSH  CX');
  EmitRaw('        PUSH  DI');
  EmitRaw('        MOV   CX, [BX]');
  EmitRaw('        MOV   DI, [_RK_HEAPTOP]');
  EmitRaw('        MOV   [DI], CX');
  EmitRaw('        ADD   BX, 2');
  EmitRaw('        MOV   SI, DI');
  EmitRaw('        ADD   SI, 2');
  EmitRaw('        TEST  CX, CX');
  EmitRaw('        JZ    _RKRT_HV_DN');
  EmitRaw('_RKRT_HV_LP:');
  EmitRaw('        MOV   AX, [BX+2]');       { value }
  EmitRaw('        MOV   [SI], AX');
  EmitRaw('        ADD   SI, 2');
  EmitRaw('        ADD   BX, 4');
  EmitRaw('        DEC   CX');
  EmitRaw('        JNZ   _RKRT_HV_LP');
  EmitRaw('_RKRT_HV_DN:');
  EmitRaw('        MOV   [_RK_HEAPTOP], SI');
  EmitRaw('        MOV   AX, DI');
  EmitRaw('        POP   DI');
  EmitRaw('        POP   CX');
  EmitRaw('        POP   SI');
  EmitRaw('        RET');
  EmitRaw('_RKRT_HVALUES ENDP');
  EmitBlankLine;
End;
{ _RKRT_CONCAT  : SI=src ASCIIZ, DI=dst -> appends src au dst     }
{                 (DI avance au null-terminator de dst d abord)     }
{ _RKRT_STRREPEAT : SI=src ASCIIZ, CX=count -> AX=OFFSET TMPBUF   }
{ _RKRT_STRCMP  : SI=str1, DI=str2 -> AX = -1/0/+1                }
{ _RKRT_POWER   : AX=base, CX=exposant -> AX=result               }
Procedure EmitBinExprRuntime;
Begin
  EmitComment('--- _RKRT_CONCAT : append ASCIIZ SI a DI ---');
  EmitRaw('_RKRT_CONCAT PROC NEAR');
  EmitRaw('        PUSH  SI');
  EmitRaw('        PUSH  BX');
  EmitRaw('        MOV   BX, DI');
  EmitRaw('_RKRT_CC_FEND:');
  EmitRaw('        CMP   BYTE PTR [DI], 0');
  EmitRaw('        JE    _RKRT_CC_CPY');
  EmitRaw('        INC   DI');
  EmitRaw('        JMP   _RKRT_CC_FEND');
  EmitRaw('_RKRT_CC_CPY:');
  EmitRaw('        MOV   AL, [SI]');
  EmitRaw('        MOV   [DI], AL');
  EmitRaw('        INC   DI');
  EmitRaw('        INC   SI');
  EmitRaw('        TEST  AL, AL');
  EmitRaw('        JNZ   _RKRT_CC_CPY');
  EmitRaw('        MOV   AX, BX');
  EmitRaw('        POP   BX');
  EmitRaw('        POP   SI');
  EmitRaw('        RET');
  EmitRaw('_RKRT_CONCAT ENDP');
  EmitBlankLine;

  EmitComment('--- _RKRT_STRREPEAT : SI=str, CX=count -> AX=TMPBUF ---');
  EmitRaw('_RKRT_STRREPEAT PROC NEAR');
  EmitRaw('        PUSH  BX');
  EmitRaw('        PUSH  DX');
  EmitRaw('        MOV   BX, SI');
  EmitRaw('        MOV   BYTE PTR [_RK_TMPBUF], 0');
  EmitRaw('        MOV   DI, OFFSET _RK_TMPBUF');
  EmitRaw('        TEST  CX, CX');
  EmitRaw('        JLE   _RKRT_SR_DONE');
  EmitRaw('_RKRT_SR_LOOP:');
  EmitRaw('        MOV   SI, BX');
  EmitRaw('        CALL  _RKRT_CONCAT');
  EmitRaw('        DEC   CX');
  EmitRaw('        JNZ   _RKRT_SR_LOOP');
  EmitRaw('_RKRT_SR_DONE:');
  EmitRaw('        MOV   AX, OFFSET _RK_TMPBUF');
  EmitRaw('        POP   DX');
  EmitRaw('        POP   BX');
  EmitRaw('        RET');
  EmitRaw('_RKRT_STRREPEAT ENDP');
  EmitBlankLine;

  EmitComment('--- _RKRT_STRCMP : SI=str1, DI=str2 -> AX=-1/0/+1 ---');
  EmitRaw('_RKRT_STRCMP PROC NEAR');
  EmitRaw('        PUSH  BX');
  EmitRaw('_RKRT_SC_LOOP:');
  EmitRaw('        MOV   AL, [SI]');
  EmitRaw('        MOV   BL, [DI]');
  EmitRaw('        CMP   AL, BL');
  EmitRaw('        JB    _RKRT_SC_LT');
  EmitRaw('        JA    _RKRT_SC_GT');
  EmitRaw('        TEST  AL, AL');
  EmitRaw('        JZ    _RKRT_SC_EQ');
  EmitRaw('        INC   SI');
  EmitRaw('        INC   DI');
  EmitRaw('        JMP   _RKRT_SC_LOOP');
  EmitRaw('_RKRT_SC_LT:');
  EmitRaw('        MOV   AX, 0FFFFh');
  EmitRaw('        JMP   _RKRT_SC_END');
  EmitRaw('_RKRT_SC_GT:');
  EmitRaw('        MOV   AX, 1');
  EmitRaw('        JMP   _RKRT_SC_END');
  EmitRaw('_RKRT_SC_EQ:');
  EmitRaw('        XOR   AX, AX');
  EmitRaw('_RKRT_SC_END:');
  EmitRaw('        POP   BX');
  EmitRaw('        RET');
  EmitRaw('_RKRT_STRCMP ENDP');
  EmitBlankLine;

  EmitComment('--- _RKRT_POWER : AX=base, CX=exp -> AX=result ---');
  EmitRaw('_RKRT_POWER PROC NEAR');
  EmitRaw('        PUSH  BX');
  EmitRaw('        PUSH  DX');
  EmitRaw('        MOV   BX, AX');
  EmitRaw('        MOV   AX, 1');
  EmitRaw('        TEST  CX, CX');
  EmitRaw('        JLE   _RKRT_PW_DONE');
  EmitRaw('_RKRT_PW_LOOP:');
  EmitRaw('        IMUL  BX');
  EmitRaw('        DEC   CX');
  EmitRaw('        JNZ   _RKRT_PW_LOOP');
  EmitRaw('_RKRT_PW_DONE:');
  EmitRaw('        POP   DX');
  EmitRaw('        POP   BX');
  EmitRaw('        RET');
  EmitRaw('_RKRT_POWER ENDP');
  EmitBlankLine;
End;

{ ============================================================
  TODO 12 - ENTREES/SORTIES [IMPLEMENTE]
  ParseSayExpr   : say expr -> CALL _RKRT_PRINTSTR/PRINTINT + NEWLINE
  ParsePrintExpr : print expr -> CALL _RKRT_PRINTSTR/PRINTINT
  ParseNoteExpr  : note expr -> ecrire sur STDOUT + NEWLINE (stub)
  ParseGetExpr   : get() -> lire une ligne STDIN, retourne Str
  ParsePromptExpr: prompt("msg") -> afficher msg + lire ligne
  EmitPrintVal   : helper - emet le code d impression selon le type
  EmitIORuntime  : runtime E/S (STRLEN, PRINTSTR, PRINTINT, NEWLINE,
                   GETLINE)
  ============================================================ }

{ ---- EmitPrintVal : emettre le code d impression selon TypeIdx -- }
{ AX contient la valeur a imprimer. Selon TypeIdx :                 }
{   TY_IDX_STR  -> MOV SI, AX / CALL _RKRT_PRINTSTR               }
{   TY_IDX_BOOL -> dispatch True/False via _RK_TRUE_S/_RK_FALSE_S  }
{   (default)   -> CALL _RKRT_PRINTINT                             }
Procedure EmitPrintVal(ATypeIdx : Integer);
Var
  LblF, LblE : TString;
Begin
  If ATypeIdx = TY_IDX_STR Then
  Begin
    EmitInstrAB('MOV', 'SI', 'AX');
    EmitInstrA('CALL', '_RKRT_PRINTSTR');
  End
  Else If ATypeIdx = TY_IDX_BOOL Then
  Begin
    LblF := LabelGen;
    LblE := LabelGen;
    EmitInstr('TEST', 'AX, AX');
    EmitInstrA('JZ', LblF);
    EmitInstrAB('LEA', 'SI', '_RK_TRUE_S');
    EmitInstrA('JMP', LblE);
    EmitLabel(LblF);
    EmitInstrAB('LEA', 'SI', '_RK_FALSE_S');
    EmitLabel(LblE);
    EmitInstrA('CALL', '_RKRT_PRINTSTR');
  End
  Else
  Begin
    EmitInstrA('CALL', '_RKRT_PRINTINT');
  End;
End;

{ ---- ParseSayExpr : say expr / say(expr) / put expr ------------- }
{ Affiche la valeur de l expression suivie d un saut de ligne.       }
{ Syntaxe acceptee : say expr;  say(expr);  put expr;               }
{ Retourne True (1) dans AX.                                        }
Procedure ParseSayExpr(Var Res : TExprVal);
Var
  E        : TExprVal;
  HasParen : Boolean;
Begin
  EmitComment('say ...');
  HasParen := False;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
  Begin
    HasParen := True;
    ParserAdvance;
  End;
  If Not ((CurToken.Kind = TK_PUNCT) And
    ((CurToken.Val = ';') Or (CurToken.Val = ')'))) And
     (CurToken.Kind <> TK_EOF) Then
  Begin
    ParseExpr(E);
    ExprFlushToAX(E);
    EmitPrintVal(E.TypeIdx);
  End;
  EmitInstrA('CALL', '_RKRT_NEWLINE');
  If HasParen Then
  Begin
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;
  End;
  ExprMakeImm(1, TY_IDX_BOOL, Res);
End;

{ ---- ParsePrintExpr : print expr / print(expr) ------------------- }
{ Affiche la valeur de l expression SANS saut de ligne.              }
{ Retourne True (1) dans AX.                                        }
Procedure ParsePrintExpr(Var Res : TExprVal);
Var
  E        : TExprVal;
  HasParen : Boolean;
Begin
  EmitComment('print ...');
  HasParen := False;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
  Begin
    HasParen := True;
    ParserAdvance;
  End;
  If Not ((CurToken.Kind = TK_PUNCT) And
    ((CurToken.Val = ';') Or (CurToken.Val = ')'))) And
     (CurToken.Kind <> TK_EOF) Then
  Begin
    ParseExpr(E);
    ExprFlushToAX(E);
    EmitPrintVal(E.TypeIdx);
  End;
  If HasParen Then
  Begin
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;
  End;
  ExprMakeImm(1, TY_IDX_BOOL, Res);
End;

{ ---- ParseNoteExpr : note expr / note(expr) ---------------------- }
{ Ecrit sur STDOUT suivi d un saut de ligne.                         }
{ (En Raku, note ecrit sur STDERR ; ici simplifie sur STDOUT.)       }
{ Retourne True (1) dans AX.                                        }
Procedure ParseNoteExpr(Var Res : TExprVal);
Var
  E        : TExprVal;
  HasParen : Boolean;
Begin
  EmitComment('note ...');
  HasParen := False;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
  Begin
    HasParen := True;
    ParserAdvance;
  End;
  If Not ((CurToken.Kind = TK_PUNCT) And
    ((CurToken.Val = ';') Or (CurToken.Val = ')'))) And
     (CurToken.Kind <> TK_EOF) Then
  Begin
    ParseExpr(E);
    ExprFlushToAX(E);
    EmitPrintVal(E.TypeIdx);
  End;
  EmitInstrA('CALL', '_RKRT_NEWLINE');
  If HasParen Then
  Begin
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;
  End;
  ExprMakeImm(1, TY_IDX_BOOL, Res);
End;

{ ---- ParseGetExpr : get / get() ---------------------------------- }
{ Lit une ligne depuis STDIN. Retourne un pointeur Str dans AX.      }
Procedure ParseGetExpr(Var Res : TExprVal);
Var
  HasParen : Boolean;
Begin
  EmitComment('get ...');
  HasParen := False;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
  Begin
    HasParen := True;
    ParserAdvance;
  End;
  If HasParen Then
  Begin
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;
  End;
  EmitInstrA('CALL', '_RKRT_GETLINE');
  Res.Kind    := EK_AX;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_IDX_STR;
  Res.Offset  := 0;
End;

{ ---- ParsePromptExpr : prompt("msg") / prompt "msg" -------------- }
{ Affiche le message, puis lit une ligne depuis STDIN.               }
{ Retourne un pointeur Str dans AX.                                  }
Procedure ParsePromptExpr(Var Res : TExprVal);
Var
  E        : TExprVal;
  HasParen : Boolean;
Begin
  EmitComment('prompt ...');
  HasParen := False;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
  Begin
    HasParen := True;
    ParserAdvance;
  End;
  If Not ((CurToken.Kind = TK_PUNCT) And
    ((CurToken.Val = ';') Or (CurToken.Val = ')'))) And
     (CurToken.Kind <> TK_EOF) Then
  Begin
    ParseExpr(E);
    ExprFlushToAX(E);
    EmitPrintVal(E.TypeIdx);
  End;
  If HasParen Then
  Begin
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;
  End;
  EmitInstrA('CALL', '_RKRT_GETLINE');
  Res.Kind    := EK_AX;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_IDX_STR;
  Res.Offset  := 0;
End;

{ ---- EmitIORuntime : routines runtime pour E/S ------------------- }
{ Emet les sous-programmes ASM 8086 pour les entrees/sorties :       }
{   _RKRT_STRLEN   : SI=chaine ASCIIZ -> CX=longueur                }
{   _RKRT_PRINTSTR : SI=chaine ASCIIZ -> ecriture STDOUT            }
{   _RKRT_PRINTINT : AX=entier signe  -> decimal sur STDOUT         }
{   _RKRT_NEWLINE  : ecrire CR+LF sur STDOUT                        }
{   _RKRT_GETLINE  : lire ligne STDIN -> AX=ptr chaine ASCIIZ       }
Procedure EmitIORuntime;
Begin
  EmitBlankLine;
  EmitComment('=== Runtime ENTREES/SORTIES (TODO 12) ===');
  EmitBlankLine;

  { _RKRT_STRLEN : SI=str ASCIIZ -> CX=longueur }
  EmitComment('--- _RKRT_STRLEN : SI=str ASCIIZ -> CX=longueur ---');
  EmitRaw('_RKRT_STRLEN PROC NEAR');
  EmitRaw('        PUSH  SI');
  EmitRaw('        XOR   CX, CX');
  EmitRaw('_RKRT_SL_LP:');
  EmitRaw('        CMP   BYTE PTR [SI], 0');
  EmitRaw('        JE    _RKRT_SL_DN');
  EmitRaw('        INC   SI');
  EmitRaw('        INC   CX');
  EmitRaw('        JMP   _RKRT_SL_LP');
  EmitRaw('_RKRT_SL_DN:');
  EmitRaw('        POP   SI');
  EmitRaw('        RET');
  EmitRaw('_RKRT_STRLEN ENDP');
  EmitBlankLine;

  { _RKRT_PRINTSTR : SI=str ASCIIZ -> ecrire sur STDOUT }
  EmitComment('--- _RKRT_PRINTSTR : SI=str ASCIIZ -> stdout ---');
  EmitRaw('_RKRT_PRINTSTR PROC NEAR');
  EmitRaw('        PUSH  AX');
  EmitRaw('        PUSH  BX');
  EmitRaw('        PUSH  CX');
  EmitRaw('        PUSH  DX');
  EmitRaw('        CALL  _RKRT_STRLEN');
  EmitRaw('        MOV   DX, SI');
  EmitRaw('        MOV   BX, 1');
  EmitRaw('        MOV   AH, 40h');
  EmitRaw('        INT   21h');
  EmitRaw('        POP   DX');
  EmitRaw('        POP   CX');
  EmitRaw('        POP   BX');
  EmitRaw('        POP   AX');
  EmitRaw('        RET');
  EmitRaw('_RKRT_PRINTSTR ENDP');
  EmitBlankLine;

  { _RKRT_PRINTINT : AX=entier signe -> afficher decimal sur STDOUT }
  EmitComment('--- _RKRT_PRINTINT : AX=int16 -> stdout decimal ---');
  EmitRaw('_RKRT_PRINTINT PROC NEAR');
  EmitRaw('        PUSH  AX');
  EmitRaw('        PUSH  BX');
  EmitRaw('        PUSH  CX');
  EmitRaw('        PUSH  DX');
  EmitRaw('        PUSH  SI');
  EmitRaw('        PUSH  DI');
  EmitRaw('        LEA   DI, _RK_NUMBUF');
  EmitRaw('        MOV   BX, AX');
  EmitRaw('        TEST  AX, AX');
  EmitRaw('        JNS   _RKRT_PI_POS');
  EmitRaw('        MOV   BYTE PTR [DI], 2Dh');
  EmitRaw('        INC   DI');
  EmitRaw('        NEG   BX');
  EmitRaw('_RKRT_PI_POS:');
  EmitRaw('        MOV   AX, BX');
  EmitRaw('        XOR   CX, CX');
  EmitRaw('        MOV   BX, 10');
  EmitRaw('_RKRT_PI_DLP:');
  EmitRaw('        XOR   DX, DX');
  EmitRaw('        DIV   BX');
  EmitRaw('        ADD   DL, 30h');
  EmitRaw('        PUSH  DX');
  EmitRaw('        INC   CX');
  EmitRaw('        TEST  AX, AX');
  EmitRaw('        JNZ   _RKRT_PI_DLP');
  EmitRaw('_RKRT_PI_SLP:');
  EmitRaw('        POP   AX');
  EmitRaw('        MOV   [DI], AL');
  EmitRaw('        INC   DI');
  EmitRaw('        DEC   CX');
  EmitRaw('        JNZ   _RKRT_PI_SLP');
  EmitRaw('        MOV   BYTE PTR [DI], 0');
  EmitRaw('        LEA   SI, _RK_NUMBUF');
  EmitRaw('        CALL  _RKRT_PRINTSTR');
  EmitRaw('        POP   DI');
  EmitRaw('        POP   SI');
  EmitRaw('        POP   DX');
  EmitRaw('        POP   CX');
  EmitRaw('        POP   BX');
  EmitRaw('        POP   AX');
  EmitRaw('        RET');
  EmitRaw('_RKRT_PRINTINT ENDP');
  EmitBlankLine;

  { _RKRT_NEWLINE : ecrire CR+LF sur STDOUT }
  EmitComment('--- _RKRT_NEWLINE : ecrire CR+LF sur stdout ---');
  EmitRaw('_RKRT_NEWLINE PROC NEAR');
  EmitRaw('        PUSH  SI');
  EmitRaw('        LEA   SI, _RK_CRLF');
  EmitRaw('        CALL  _RKRT_PRINTSTR');
  EmitRaw('        POP   SI');
  EmitRaw('        RET');
  EmitRaw('_RKRT_NEWLINE ENDP');
  EmitBlankLine;

  { _RKRT_GETLINE : lire une ligne STDIN -> AX=ptr ASCIIZ }
  EmitComment('--- _RKRT_GETLINE : lire ligne STDIN -> AX=ptr ---');
  EmitRaw('_RKRT_GETLINE PROC NEAR');
  EmitRaw('        PUSH  BX');
  EmitRaw('        PUSH  CX');
  EmitRaw('        PUSH  DX');
  EmitRaw('        MOV   BYTE PTR [_RK_IOBUF], 126');
  EmitRaw('        MOV   BYTE PTR [_RK_IOBUF+1], 0');
  EmitRaw('        LEA   DX, _RK_IOBUF');
  EmitRaw('        MOV   AH, 0Ah');
  EmitRaw('        INT   21h');
  EmitRaw('        LEA   BX, _RK_IOBUF');
  EmitRaw('        XOR   CH, CH');
  EmitRaw('        MOV   CL, [BX+1]');
  EmitRaw('        ADD   BX, 2');
  EmitRaw('        ADD   BX, CX');
  EmitRaw('        MOV   BYTE PTR [BX], 0');
  EmitRaw('        MOV   AX, OFFSET _RK_IOBUF');
  EmitRaw('        ADD   AX, 2');
  EmitRaw('        POP   DX');
  EmitRaw('        POP   CX');
  EmitRaw('        POP   BX');
  EmitRaw('        RET');
  EmitRaw('_RKRT_GETLINE ENDP');
  EmitBlankLine;
End;

{ ============================================================
  TODO 13 - CONDITIONNELLES (if/elsif/else, unless, given/when)
  ============================================================ }

{ ---- ParseBlock : parse accolades stmts accolades -------------- }
(* Consomme accolade ouvrante, execute les stmts, consomme fermante *)
Procedure ParseBlock;
Begin
  (* Consommer accolade ouvrante *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
    ParserAdvance
  Else
    CompileError('accolade ouvrante attendue');

  (* Parser les instructions du bloc *)
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) Do
    ParseStmt;

  (* Consommer accolade fermante *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
    ParserAdvance
  Else
    CompileError('accolade fermante attendue');
End;

(* ---- ParseIfStmt : if/elsif/else ----------------------------- *)
(* Syntaxe Raku :                                                   *)
(*   if cond LBRACE stmts RBRACE                                    *)
(*   if cond LBRACE stmts RBRACE else LBRACE stmts RBRACE           *)
(*   if cond LBRACE stmts RBRACE elsif cond LBRACE ... RBRACE       *)
Procedure ParseIfStmt;
Var
  Cond        : TExprVal;
  LblElsif    : TString;
  LblEnd      : TString;
  ElsifIdx    : Integer;
  NS          : TString;
Begin
  Inc(IfCount);
  Str(IfCount, NS);

  LblEnd := '_RKL_ENDIF_' + NS;
  ElsifIdx := 0;

  EmitComment('if (TODO 13)');

  { Evaluer la condition }
  ParseExpr(Cond);
  ExprFlushToAX(Cond);

  { Generer le label pour la branche fausse }
  Inc(ElsifIdx);
  Str(ElsifIdx, NS);
  Str(IfCount, LblElsif);
  LblElsif := '_RKL_ELSIF_' + LblElsif + '_' + NS;

  { TEST AX,AX / JZ -> branche fausse }
  EmitInstrAB('TEST', 'AX', 'AX');
  EmitInstrA('JZ', LblElsif);

  { Bloc THEN }
  ParseBlock;

  { Saut vers la fin }
  EmitInstrA('JMP', LblEnd);

  { Gerer les elsif / else }
  While (CurToken.Kind = TK_KEYWORD) And
        ((CurToken.Val = 'elsif') Or (CurToken.Val = 'else')) Do
  Begin
    If CurToken.Val = 'elsif' Then
    Begin
      EmitLabel(LblElsif);
      ParserAdvance;   { consommer 'elsif' }

      EmitComment('elsif');

      { Evaluer la condition elsif }
      ParseExpr(Cond);
      ExprFlushToAX(Cond);

      { Generer le prochain label fausse }
      Inc(ElsifIdx);
      Str(ElsifIdx, NS);
      Str(IfCount, LblElsif);
      LblElsif := '_RKL_ELSIF_' + LblElsif + '_' + NS;

      EmitInstrAB('TEST', 'AX', 'AX');
      EmitInstrA('JZ', LblElsif);

      { Bloc elsif }
      ParseBlock;

      { Saut vers la fin }
      EmitInstrA('JMP', LblEnd);
    End
    Else { else }
    Begin
      EmitLabel(LblElsif);
      ParserAdvance;   { consommer 'else' }

      EmitComment('else');

      { Bloc else }
      ParseBlock;

      { Marquer le label elsif courant comme consomme }
      LblElsif := '';
    End;
  End;

  { Si pas de else, on emet le label fausse restant }
  If LblElsif <> '' Then
    EmitLabel(LblElsif);

  { Label de fin }
  EmitLabel(LblEnd);
End;

(* ---- ParseUnlessStmt : unless cond LBRACE stmts RBRACE ------ *)
(* Equivalent a if !cond LBRACE stmts RBRACE                       *)
(* Supporte else, mais pas elsif                                    *)
Procedure ParseUnlessStmt;
Var
  Cond     : TExprVal;
  LblElse  : TString;
  LblEnd   : TString;
  NS       : TString;
Begin
  Inc(IfCount);
  Str(IfCount, NS);

  LblElse := '_RKL_UNLESS_ELSE_' + NS;
  LblEnd  := '_RKL_UNLESS_END_' + NS;

  EmitComment('unless (TODO 13)');

  { Evaluer la condition }
  ParseExpr(Cond);
  ExprFlushToAX(Cond);

  { unless = executer si faux : JNZ saute par-dessus le bloc }
  EmitInstrAB('TEST', 'AX', 'AX');
  EmitInstrA('JNZ', LblElse);

  { Bloc unless (execute si condition fausse) }
  ParseBlock;
  EmitInstrA('JMP', LblEnd);

  { Label else }
  EmitLabel(LblElse);

  { Gerer le else optionnel }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'else') Then
  Begin
    ParserAdvance;   { consommer 'else' }
    EmitComment('unless/else');
    ParseBlock;
  End;

  { Label de fin }
  EmitLabel(LblEnd);
End;

(* ---- ParseGivenWhenStmt : given/when/default ----------------- *)
(* Syntaxe Raku :                                                    *)
(*   given $x LBRACE                                                 *)
(*     when val1 LBRACE stmts RBRACE                                 *)
(*     when val2 LBRACE stmts RBRACE                                 *)
(*     default   LBRACE stmts RBRACE                                 *)
(*   RBRACE                                                          *)
Procedure ParseGivenWhenStmt;
Var
  GivenExpr   : TExprVal;
  WhenExpr    : TExprVal;
  LblNext     : TString;
  LblEnd      : TString;
  NS          : TString;
  WhenIdx     : Integer;
Begin
  Inc(GivenCount);
  Str(GivenCount, NS);
  LblEnd := '_RKL_ENDGIVEN_' + NS;
  WhenIdx := 0;

  EmitComment('given (TODO 13)');

  { Evaluer l expression given }
  ParseExpr(GivenExpr);
  ExprFlushToAX(GivenExpr);

  { Sauvegarder la valeur dans CX pour les comparaisons when }
  EmitInstrAB('MOV', 'CX', 'AX');

  (* Consommer accolade ouvrante *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
    ParserAdvance
  Else
    CompileError('accolade ouvrante attendue apres given');

  (* Parser les when/default *)
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) Do
  Begin
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'when') Then
    Begin
      ParserAdvance;   { consommer 'when' }
      Inc(WhenIdx);
      Str(WhenIdx, NS);
      Str(GivenCount, LblNext);
      LblNext := '_RKL_WHEN_' + LblNext + '_' + NS;

      EmitComment('when');

      { Evaluer la valeur when }
      ParseExpr(WhenExpr);
      ExprFlushToAX(WhenExpr);

      { Comparer : CX contient la valeur given }
      EmitInstrAB('CMP', 'CX', 'AX');
      EmitInstrA('JNE', LblNext);

      { Bloc when (match) }
      ParseBlock;

      { Sortir du given apres un match }
      EmitInstrA('JMP', LblEnd);

      { Label pour le prochain when }
      EmitLabel(LblNext);
    End
    Else If (CurToken.Kind = TK_KEYWORD) And
            (CurToken.Val = 'default') Then
    Begin
      ParserAdvance;   { consommer 'default' }
      EmitComment('default');

      { Bloc default (toujours execute si atteint) }
      ParseBlock;
    End
    Else
    Begin
      { Instruction hors when/default dans le given }
      ParseStmt;
    End;
  End;

  (* Consommer accolade fermante *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
    ParserAdvance
  Else
    CompileError('accolade fermante attendue apres given');

  { Label de fin }
  EmitLabel(LblEnd);
End;

{ ============================================================
  TODO 14 - BOUCLES (loop, while, until, repeat, for) [IMPLEMENTE]
  ============================================================ }

{ ---- LoopPush : empiler les labels de boucle ----------------- }
Procedure LoopPush(Const BrkLbl, ContLbl, RedoLbl : TString);
Begin
  If LoopTop >= MAX_LOOP_NEST Then
  Begin
    CompileError('Boucles trop imbriquees (max=' +
                 IntToStr(MAX_LOOP_NEST) + ')');
    Exit;
  End;
  LoopBreakLbl[LoopTop] := BrkLbl;
  LoopContLbl[LoopTop]  := ContLbl;
  LoopRedoLbl[LoopTop]  := RedoLbl;
  Inc(LoopTop);
End;

{ ---- LoopPop : depiler un niveau de boucle ------------------- }
Procedure LoopPop;
Begin
  If LoopTop > 0 Then Dec(LoopTop);
End;

(* ---- ParseWhileStmt : while cond BLOC ----------------------- *)
(* Syntaxe Raku :                                                  *)
(*   while cond { stmts }                                          *)
(* Emission :                                                      *)
(*   _RKL_WTEST_N:  [eval cond] TEST AX,AX / JZ _RKL_WEND_N      *)
(*                  [bloc]                                         *)
(*   _RKL_WCNT_N:   JMP _RKL_WTEST_N                              *)
(*   _RKL_WEND_N:                                                  *)
Procedure ParseWhileStmt;
Var
  Cond    : TExprVal;
  LblTest : TString;
  LblEnd  : TString;
  LblCont : TString;
  N       : TString;
Begin
  Inc(WhileCount);
  Str(WhileCount, N);
  LblTest := '_RKL_WTEST_' + N;
  LblEnd  := '_RKL_WEND_'  + N;
  LblCont := '_RKL_WCNT_'  + N;
  LoopPush(LblEnd, LblCont, LblTest);

  EmitLabel(LblTest);
  ParseExpr(Cond);
  ExprFlushToAX(Cond);
  EmitInstr('TEST', 'AX, AX');
  EmitInstr('JZ', LblEnd);

  ParseBlock;

  EmitLabel(LblCont);
  EmitInstr('JMP', LblTest);
  EmitLabel(LblEnd);
  LoopPop;
End;

(* ---- ParseUntilStmt : until cond BLOC ----------------------- *)
(* Comme while mais sort quand la condition est VRAIE              *)
(* Emission : TEST AX,AX / JNZ _RKL_UEND_N                       *)
Procedure ParseUntilStmt;
Var
  Cond    : TExprVal;
  LblTest : TString;
  LblEnd  : TString;
  LblCont : TString;
  N       : TString;
Begin
  Inc(UntilCount);
  Str(UntilCount, N);
  LblTest := '_RKL_UTEST_' + N;
  LblEnd  := '_RKL_UEND_'  + N;
  LblCont := '_RKL_UCNT_'  + N;
  LoopPush(LblEnd, LblCont, LblTest);

  EmitLabel(LblTest);
  ParseExpr(Cond);
  ExprFlushToAX(Cond);
  EmitInstr('TEST', 'AX, AX');
  EmitInstr('JNZ', LblEnd);

  ParseBlock;

  EmitLabel(LblCont);
  EmitInstr('JMP', LblTest);
  EmitLabel(LblEnd);
  LoopPop;
End;

(* ---- ParseLoopStmt : loop BLOC / loop (init;cond;incr) BLOC - *)
(* Forme 1 : loop { stmts }  -> boucle infinie                    *)
(*   _RKL_LBEG_N: [bloc] JMP _RKL_LBEG_N                          *)
(*   _RKL_LEND_N:                                                  *)
(* Forme 2 : loop (init; cond; incr) { stmts }                    *)
(*   [init]; _RKL_LTEST_N: [cond] JZ _RKL_LEND_N;                 *)
(*   JMP _RKL_LBOD_N; _RKL_LINCR_N: [incr] JMP _RKL_LTEST_N;     *)
(*   _RKL_LBOD_N: [bloc] JMP _RKL_LINCR_N; _RKL_LEND_N:           *)
Procedure ParseLoopStmt;
Var
  LblBeg  : TString;
  LblEnd  : TString;
  LblCont : TString;
  LblIncr : TString;
  LblBody : TString;
  N       : TString;
  Cond    : TExprVal;
  Dummy   : TExprVal;
Begin
  Inc(LoopCount);
  Str(LoopCount, N);
  LblBeg  := '_RKL_LBEG_'  + N;
  LblEnd  := '_RKL_LEND_'  + N;
  LblCont := '_RKL_LCNT_'  + N;

  (* Detecter la forme : loop (init; cond; incr) vs loop BLOC *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
  Begin
    (* Forme 2 : loop (init; cond; incr) BLOC *)
    LblIncr := '_RKL_LINCR_' + N;
    LblBody := '_RKL_LBOD_'  + N;
    ParserAdvance;   { consommer '(' }

    { Init }
    If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Then
    Begin
      If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'my') Then
      Begin
        ParserAdvance;
        ParseDeclStmt('my');
      End
      Else
        ParseExprStmt;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      ParserAdvance;

    LoopPush(LblEnd, LblIncr, LblBeg);

    { Test de condition }
    EmitLabel(LblBeg);
    If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Then
    Begin
      ParseExpr(Cond);
      ExprFlushToAX(Cond);
      EmitInstr('TEST', 'AX, AX');
      EmitInstr('JZ', LblEnd);
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      ParserAdvance;

    { Sauter au corps, placer l'increment entre }
    EmitInstr('JMP', LblBody);
    EmitLabel(LblIncr);
    If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
      ParseExpr(Dummy);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;
    EmitInstr('JMP', LblBeg);

    EmitLabel(LblBody);
    ParseBlock;
    EmitInstr('JMP', LblIncr);
    EmitLabel(LblEnd);
    LoopPop;
  End
  Else
  Begin
    (* Forme 1 : loop BLOC -> boucle infinie *)
    LoopPush(LblEnd, LblCont, LblBeg);
    EmitLabel(LblBeg);
    ParseBlock;
    EmitLabel(LblCont);
    EmitInstr('JMP', LblBeg);
    EmitLabel(LblEnd);
    LoopPop;
  End;
End;

(* ---- ParseRepeatStmt : repeat BLOC while/until cond --------- *)
(* Syntaxe Raku :                                                  *)
(*   repeat { stmts } while cond;                                  *)
(*   repeat { stmts } until cond;                                  *)
(* Emission :                                                      *)
(*   _RKL_RBEG_N: [bloc]                                          *)
(*   _RKL_RCNT_N: [cond] TEST AX,AX / JNZ ou JZ _RKL_RBEG_N      *)
(*   _RKL_REND_N:                                                  *)
Procedure ParseRepeatStmt;
Var
  Cond      : TExprVal;
  LblBeg    : TString;
  LblEnd    : TString;
  LblCont   : TString;
  N         : TString;
  IsUntil   : Boolean;
Begin
  Inc(RepeatCount);
  Str(RepeatCount, N);
  LblBeg  := '_RKL_RBEG_'  + N;
  LblEnd  := '_RKL_REND_'  + N;
  LblCont := '_RKL_RCNT_'  + N;
  LoopPush(LblEnd, LblCont, LblBeg);

  EmitLabel(LblBeg);
  ParseBlock;

  EmitLabel(LblCont);
  { Attendre while ou until }
  IsUntil := False;
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'while') Then
    ParserAdvance
  Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'until') Then
  Begin
    IsUntil := True;
    ParserAdvance;
  End
  Else
    CompileError('while ou until attendu apres repeat { ... }');

  ParseExpr(Cond);
  ExprFlushToAX(Cond);
  EmitInstr('TEST', 'AX, AX');
  If IsUntil Then
    EmitInstr('JZ', LblBeg)     { until : reboucler si FAUX }
  Else
    EmitInstr('JNZ', LblBeg);   { while : reboucler si VRAI }

  EmitLabel(LblEnd);
  LoopPop;

  { Consommer point-virgule optionnel }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance;
End;

(* ---- ParseForStmt : for RANGE -> $var BLOC ------------------- *)
(* Syntaxe Raku :                                                  *)
(*   for RANGE_EXPR -> $var { stmts }                              *)
(*   for RANGE_EXPR { stmts }  (utilise $_ implicite)             *)
(* Range simple : START..END  => boucle compteur                   *)
(* Emission (range) :                                              *)
(*   MOV [var], START                                              *)
(*   _RKL_FTEST_N: MOV AX,[var] / CMP AX, END / JG _RKL_FEND_N   *)
(*   [bloc]                                                        *)
(*   _RKL_FINCR_N: INC [var] / JMP _RKL_FTEST_N                   *)
(*   _RKL_FEND_N:                                                  *)
Procedure ParseForStmt;
Var
  LblTest  : TString;
  LblEnd   : TString;
  LblIncr  : TString;
  N        : TString;
  VarName  : TString;
  SymIdx   : Integer;
  StartE   : TExprVal;
  EndE     : TExprVal;
  OfsStr   : TString;
  HasVar   : Boolean;
Begin
  Inc(ForCount);
  Str(ForCount, N);
  LblTest := '_RKL_FTEST_' + N;
  LblEnd  := '_RKL_FEND_'  + N;
  LblIncr := '_RKL_FINCR_' + N;

  HasVar := False;
  SymIdx := -1;
  VarName := '$_';

  { Evaluer l'expression de range (start..end) }
  ParseExpr(StartE);
  ExprFlushToAX(StartE);
  EmitInstr('PUSH', 'AX');   { sauvegarder start sur la pile }

  { Detecter .. pour range }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '..') Then
  Begin
    ParserAdvance;   { consommer '..' }
    ParseExpr(EndE);
    ExprFlushToAX(EndE);
    EmitInstr('PUSH', 'AX');   { sauvegarder end sur la pile }
  End
  Else
  Begin
    { Pas de range : stub boucle unique }
    EmitInstr('PUSH', 'AX');   { end = start (1 iteration) }
  End;

  { Detecter -> $var pour la variable d'iteration }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '->') Then
  Begin
    ParserAdvance;   { consommer '->' }
    If CurToken.Kind = TK_SCALAR Then
    Begin
      VarName := CurToken.Val;
      ParserAdvance;
      HasVar := True;
    End
    Else
      CompileError('variable scalaire attendue apres ->');
  End;

  { Allouer la variable d'iteration locale }
  SymIdx := DeclAllocSym(VarName, '$', SC_MY, TY_IDX_INT);

  { Initialiser la variable avec la valeur de start }
  EmitInstr('POP', 'BX');    { BX = end }
  EmitInstr('POP', 'AX');    { AX = start }
  If SymIdx >= 0 Then
  Begin
    Str(SymTab[SymIdx].Offset, OfsStr);
    EmitInstr('MOV', 'WORD PTR [BP-' + OfsStr + '], AX');
  End;
  { Sauvegarder la borne fin dans CX (on la PUSH pour la retrouver) }
  EmitInstr('PUSH', 'BX');

  LoopPush(LblEnd, LblIncr, LblTest);

  { Test de boucle }
  EmitLabel(LblTest);
  If SymIdx >= 0 Then
  Begin
    Str(SymTab[SymIdx].Offset, OfsStr);
    EmitInstr('MOV', 'AX, WORD PTR [BP-' + OfsStr + ']');
  End;
  { Recuperer la borne fin depuis la pile (peek sans pop) }
  EmitInstr('MOV', 'BX, WORD PTR [SP]');
  EmitInstr('CMP', 'AX, BX');
  EmitInstr('JG', LblEnd);

  { Corps de boucle }
  ParseBlock;

  { Increment }
  EmitLabel(LblIncr);
  If SymIdx >= 0 Then
  Begin
    Str(SymTab[SymIdx].Offset, OfsStr);
    EmitInstr('INC', 'WORD PTR [BP-' + OfsStr + ']');
  End;
  EmitInstr('JMP', LblTest);

  EmitLabel(LblEnd);
  { Nettoyer la borne fin de la pile }
  EmitInstr('ADD', 'SP, 2');
  LoopPop;
End;

{ ============================================================
  TODO 17 - SOUS-ROUTINES ET FONCTIONS (sub, return) [IMPLEMENTE]
  ============================================================ }

{ ---- ParseSubDecl : declaration de sous-routine ---------------- }
(* Syntaxe : sub nom($a, $b, $c) { corps }                        *)
{ Convention d appel cdecl 16 bits :                               }
{   Arguments pousses de gauche a droite par l appelant            }
{   Prologue : PUSH BP / MOV BP,SP / [SUB SP, locals]             }
{   Epilogue : MOV SP,BP / POP BP / RET                           }
{   Valeur de retour dans AX                                      }
{ Parametres accessibles via [BP + offset positif] :               }
{   [BP]   = ancien BP                                             }
{   [BP+2] = adresse de retour                                    }
{   [BP+4] = dernier param (pousse en dernier)                    }
{   [BP+6] = avant-dernier param ...                               }
{   [BP+4+(ParamCount-1-i)*2] = param i (0-base)                  }
Procedure ParseSubDecl;
Var
  SubName     : TString;
  ParamNames  : Array[0..MAX_PARAM - 1] Of TString;
  ParamCount  : Integer;
  LblSkip     : TString;
  LblRet      : TString;
  LblProc     : TString;
  SaveFrame   : Integer;
  SaveFnDepth : Integer;
  SaveRetLbl  : TString;
  SaveFnName  : TString;
  I           : Integer;
  Ofs         : Integer;
  OfsStr      : TString;
Begin
  Inc(SubCount);
  { Attendre le nom de la sous-routine }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('nom de sous-routine attendu apres ''sub''');
    Exit;
  End;
  SubName := CurToken.Val;
  ParserAdvance;

  { Enregistrer le symbole sub dans la table }
  SymAdd(SubName, '&', SC_SUB, TY_IDX_CODE, 0);

  { Parser la liste de parametres : ($a, $b, $c) }
  ParamCount := 0;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
  Begin
    ParserAdvance;   { consommer '(' }
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) And
          (CurToken.Kind <> TK_EOF) Do
    Begin
      If CurToken.Kind = TK_SCALAR Then
      Begin
        If ParamCount < MAX_PARAM Then
        Begin
          ParamNames[ParamCount] := CurToken.Val;
          Inc(ParamCount);
        End
        Else
          CompileError('trop de parametres (max=' +
                       IntToStr(MAX_PARAM) + ')');
        ParserAdvance;
      End
      Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance   { consommer ',' }
      Else
      Begin
        CompileError('parametre $nom attendu dans la signature de sub ' +
                     SubName);
        ParserAdvance;
      End;
    End;
    { Consommer ')' }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance
    Else
      CompileError(''')'' attendue apres les parametres de sub ' + SubName);
  End;

  { Generer les labels }
  Str(SubCount, OfsStr);
  LblSkip := '_RKL_SSKIP_' + OfsStr;
  LblRet  := '_RKL_SRET_' + OfsStr;
  LblProc := '_RKS_' + SymNameClean(SubName);

  { Sauvegarder le contexte de la sous-routine courante }
  SaveFrame   := CurFrameSize;
  SaveFnDepth := CurFnDepth;
  SaveRetLbl  := CurFnRetLbl;
  SaveFnName  := CurFnName;

  CurFrameSize := 0;
  Inc(CurFnDepth);
  CurFnRetLbl  := LblRet;
  CurFnName    := SubName;

  { JMP par-dessus le corps de la sub }
  EmitInstr('JMP', LblSkip);
  EmitBlankLine;
  EmitComment('sub ' + SubName + '(' + IntToStr(ParamCount) + ' params)');
  EmitRaw(LblProc + ' PROC NEAR');

  { Prologue standard }
  EmitProlog;

  { Entrer dans une nouvelle portee }
  SymEnterScope;

  { Enregistrer les parametres dans la table des symboles }
  { Les params sont pousses de gauche a droite par l'appelant. }
  { Apres PUSH BP / MOV BP,SP :                                }
  {   param[i] est a [BP + 4 + (ParamCount - 1 - i) * 2]      }
  For I := 0 To ParamCount - 1 Do
  Begin
    Ofs := 4 + (ParamCount - 1 - I) * 2;
    SymAdd(ParamNames[I], '$', SC_PARAM, TY_IDX_INT, Ofs);
    Str(Ofs, OfsStr);
    EmitComment('param $' + ParamNames[I] + ' [BP+' + OfsStr + ']');
  End;

  (* Parser le corps : accolade ouvrante, stmts, accolade fermante *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
    ParserAdvance   (* consommer accolade ouvrante *)
  Else
    CompileError('''{'' attendue pour le corps de sub ' + SubName);

  While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) And
        (CurToken.Kind <> TK_EOF) Do
    ParseStmt;

  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
    ParserAdvance   (* consommer accolade fermante *)
  Else
    CompileError('''}'' attendue a la fin de sub ' + SubName);

  { Label de retour (cible de return) }
  EmitLabel(LblRet);

  { Epilogue standard }
  EmitEpilog;
  EmitRaw(LblProc + ' ENDP');
  EmitBlankLine;

  { Label de saut apres la sub }
  EmitLabel(LblSkip);

  { Quitter la portee }
  SymLeaveScope;

  { Restaurer le contexte }
  CurFrameSize := SaveFrame;
  CurFnDepth   := SaveFnDepth;
  CurFnRetLbl  := SaveRetLbl;
  CurFnName    := SaveFnName;
End;

{ ---- ParseReturnStmt : instruction return ---------------------- }
{ Syntaxe : return expr ;                                          }
{           return ;                                               }
{ Evalue l'expression, place le resultat dans AX, puis JMP vers   }
{ le label epilogue de la sous-routine courante (CurFnRetLbl).    }
Procedure ParseReturnStmt;
Var
  E : TExprVal;
Begin
  If CurFnDepth <= 0 Then
  Begin
    CompileError('return en dehors d''une sous-routine');
    Exit;
  End;
  { Si ';' immediat -> return void (AX=0) }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
  Begin
    EmitInstr('XOR', 'AX, AX');
    ParserAdvance;
  End
  Else
  Begin
    { Evaluer l'expression de retour }
    ParseExpr(E);
    ExprFlushToAX(E);
    { Consommer ';' si present }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      ParserAdvance;
  End;
  { Sauter vers l'epilogue }
  EmitInstr('JMP', CurFnRetLbl);
  EmitComment('return de sub ' + CurFnName);
End;

{ ============================================================
  TODO 18 - MULTI DISPATCH (multi sub, proto) [IMPLEMENTE]
  MultiGroupFind    : chercher un groupe multi par nom
  ParseMultiDecl    : multi sub name(Type $param, ...) corps
  ParseProtoDecl    : proto sub name
  EmitMultiDispatchers : generer les PROC dispatchers
  ============================================================ }

{ ---- MultiGroupFind : chercher un groupe multi par nom ------ }
{ Retourne l indice dans MultiGroupTab ou -1 si non trouve.     }
Function MultiGroupFind(Const Name : TString) : Integer;
Var
  I : Integer;
Begin
  For I := 0 To MultiGroupCount - 1 Do
    If MultiGroupTab[I].Name = Name Then
    Begin
      MultiGroupFind := I;
      Exit;
    End;
  MultiGroupFind := -1;
End;

{ ---- MultiGroupAdd : trouver ou creer un groupe multi ------- }
Function MultiGroupAdd(Const Name : TString) : Integer;
Var
  Idx : Integer;
Begin
  Idx := MultiGroupFind(Name);
  If Idx >= 0 Then
  Begin
    MultiGroupAdd := Idx;
    Exit;
  End;
  If MultiGroupCount >= MAX_MULTI_GROUP Then
  Begin
    CompileError('trop de groupes multi (max=' +
                 IntToStr(MAX_MULTI_GROUP) + ')');
    MultiGroupAdd := -1;
    Exit;
  End;
  Idx := MultiGroupCount;
  MultiGroupTab[Idx].Name     := Name;
  MultiGroupTab[Idx].VarCount := 0;
  MultiGroupTab[Idx].DefIdx   := -1;
  MultiGroupTab[Idx].HasProto := False;
  Inc(MultiGroupCount);
  MultiGroupAdd := Idx;
End;

{ ---- ParseMultiDecl : declaration multi sub ----------------- }
(* Syntaxe : multi sub nom(Type $a, Type $b) { corps }          *)
(*           multi sub nom($a) { corps }  (candidat par defaut) *)
{ La premiere declaration d un nom cree le symbole &nom.         }
{ Chaque candidat genere un PROC _RKS_nom_MN avec son corps.    }
{ Le dispatcher _RKS_nom est genere a la fin via                 }
{ EmitMultiDispatchers.                                          }
Procedure ParseMultiDecl;
Var
  SubName     : TString;
  ParamNames  : Array[0..MAX_PARAM - 1] Of TString;
  ParamTypes  : Array[0..MAX_PARAM - 1] Of Integer;
  ParamCount  : Integer;
  GIdx        : Integer;
  VIdx        : Integer;
  LblSkip     : TString;
  LblRet      : TString;
  LblProc     : TString;
  SaveFrame   : Integer;
  SaveFnDepth : Integer;
  SaveRetLbl  : TString;
  SaveFnName  : TString;
  I           : Integer;
  Ofs         : Integer;
  OfsStr      : TString;
  TyIdx       : Integer;
  CntStr      : TString;
  HasTyped    : Boolean;
Begin
  { Attendre 'sub' apres 'multi' }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'sub') Then
    ParserAdvance   { consommer 'sub' }
  Else
  Begin
    CompileError('''sub'' attendu apres ''multi''');
    Exit;
  End;

  { Nom de la sous-routine }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('nom de sous-routine attendu apres ''multi sub''');
    Exit;
  End;
  SubName := CurToken.Val;
  ParserAdvance;

  Inc(MultiCount);
  Inc(SubCount);

  { Trouver ou creer le groupe multi }
  GIdx := MultiGroupAdd(SubName);
  If GIdx < 0 Then Exit;

  { Enregistrer le symbole &nom si c est la premiere variante }
  If SymFind('&' + SubName) < 0 Then
    SymAdd(SubName, '&', SC_SUB, TY_IDX_CODE, 0);

  { Parser la liste de parametres avec contraintes de type }
  ParamCount := 0;
  HasTyped   := False;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
  Begin
    ParserAdvance;   { consommer '(' }
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) And
          (CurToken.Kind <> TK_EOF) Do
    Begin
      { Verifier si un nom de type precede le $param }
      TyIdx := TY_UNKNOWN;
      If CurToken.Kind = TK_IDENT Then
      Begin
        TyIdx := TypeLookupName(CurToken.Val);
        If TyIdx >= 0 Then
        Begin
          HasTyped := True;
          ParserAdvance;   { consommer le nom de type }
        End
        Else
          TyIdx := TY_UNKNOWN;
      End;
      If CurToken.Kind = TK_SCALAR Then
      Begin
        If ParamCount < MAX_PARAM Then
        Begin
          ParamNames[ParamCount] := CurToken.Val;
          ParamTypes[ParamCount] := TyIdx;
          Inc(ParamCount);
        End
        Else
          CompileError('trop de parametres (max=' +
                       IntToStr(MAX_PARAM) + ')');
        ParserAdvance;
      End
      Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance
      Else
      Begin
        CompileError('parametre $nom attendu dans multi sub ' + SubName);
        ParserAdvance;
      End;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance
    Else
      CompileError(''')'' attendue apres les parametres de multi sub ' +
                   SubName);
  End;

  { Ajouter le candidat au groupe }
  VIdx := MultiGroupTab[GIdx].VarCount;
  If VIdx >= MAX_MULTI_VAR Then
  Begin
    CompileError('trop de variantes multi pour ' + SubName +
                 ' (max=' + IntToStr(MAX_MULTI_VAR) + ')');
    Exit;
  End;

  Str(VIdx + 1, CntStr);
  LblProc := '_RKS_' + SymNameClean(SubName) + '_M' + CntStr;

  MultiGroupTab[GIdx].Vars[VIdx].LblName    := LblProc;
  MultiGroupTab[GIdx].Vars[VIdx].ParamCount := ParamCount;
  If (ParamCount > 0) And HasTyped Then
    MultiGroupTab[GIdx].Vars[VIdx].TypeIdx0 := ParamTypes[0]
  Else
    MultiGroupTab[GIdx].Vars[VIdx].TypeIdx0 := TY_UNKNOWN;
  Inc(MultiGroupTab[GIdx].VarCount);

  { Si pas de contrainte de type sur le 1er param -> candidat par defaut }
  If (Not HasTyped) Or
     ((ParamCount > 0) And (ParamTypes[0] = TY_UNKNOWN)) Then
    MultiGroupTab[GIdx].DefIdx := VIdx;

  { Generer les labels }
  Str(SubCount, OfsStr);
  LblSkip := '_RKL_SSKIP_' + OfsStr;
  LblRet  := '_RKL_SRET_' + OfsStr;

  { Sauvegarder le contexte }
  SaveFrame   := CurFrameSize;
  SaveFnDepth := CurFnDepth;
  SaveRetLbl  := CurFnRetLbl;
  SaveFnName  := CurFnName;

  CurFrameSize := 0;
  Inc(CurFnDepth);
  CurFnRetLbl  := LblRet;
  CurFnName    := SubName;

  { JMP par-dessus le corps du candidat }
  EmitInstr('JMP', LblSkip);
  EmitBlankLine;
  EmitComment('multi sub ' + SubName + ' candidat ' + CntStr +
              ' (' + IntToStr(ParamCount) + ' params)');
  EmitRaw(LblProc + ' PROC NEAR');

  { Prologue standard }
  EmitProlog;

  { Nouvelle portee }
  SymEnterScope;

  { Enregistrer les parametres }
  For I := 0 To ParamCount - 1 Do
  Begin
    Ofs := 4 + (ParamCount - 1 - I) * 2;
    SymAdd(ParamNames[I], '$', SC_PARAM, TY_IDX_INT, Ofs);
    Str(Ofs, OfsStr);
    EmitComment('param $' + ParamNames[I] + ' [BP+' + OfsStr + ']');
  End;

  { Parser le corps }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
    ParserAdvance
  Else
    CompileError('''{'' attendue pour le corps de multi sub ' + SubName);

  While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) And
        (CurToken.Kind <> TK_EOF) Do
    ParseStmt;

  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
    ParserAdvance
  Else
    CompileError('''}'' attendue a la fin de multi sub ' + SubName);

  { Label de retour }
  EmitLabel(LblRet);

  { Epilogue }
  EmitEpilog;
  EmitRaw(LblProc + ' ENDP');
  EmitBlankLine;

  { Label de saut apres le candidat }
  EmitLabel(LblSkip);

  { Quitter la portee }
  SymLeaveScope;

  { Restaurer le contexte }
  CurFrameSize := SaveFrame;
  CurFnDepth   := SaveFnDepth;
  CurFnRetLbl  := SaveRetLbl;
  CurFnName    := SaveFnName;
End;

{ ---- ParseProtoDecl : declaration proto sub ----------------- }
(* Syntaxe : proto sub nom(|) {*}                               *)
{ Declare le prototype d un groupe multi (optionnel).            }
Procedure ParseProtoDecl;
Var
  SubName : TString;
  GIdx    : Integer;
Begin
  { Attendre 'sub' apres 'proto' }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'sub') Then
    ParserAdvance
  Else
  Begin
    CompileError('''sub'' attendu apres ''proto''');
    Exit;
  End;

  { Nom de la sous-routine }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('nom de sous-routine attendu apres ''proto sub''');
    Exit;
  End;
  SubName := CurToken.Val;
  ParserAdvance;

  { Trouver ou creer le groupe multi }
  GIdx := MultiGroupAdd(SubName);
  If GIdx >= 0 Then
    MultiGroupTab[GIdx].HasProto := True;

  { Enregistrer le symbole &nom si pas deja fait }
  If SymFind('&' + SubName) < 0 Then
    SymAdd(SubName, '&', SC_SUB, TY_IDX_CODE, 0);

  { Consommer (|) ou (*) }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
  Begin
    ParserAdvance;
    { Consommer tout jusqu a ')' }
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) And
          (CurToken.Kind <> TK_EOF) Do
      ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;
  End;

  (* Consommer le corps du proto : {*} ou vide *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
  Begin
    ParserAdvance;
    (* Consommer tout jusqu a accolade fermante *)
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) And
          (CurToken.Kind <> TK_EOF) Do
      ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
      ParserAdvance;
  End;

  EmitComment('proto sub ' + SubName + ' (|) {*}');
End;

{ ---- EmitMultiDispatchers : generer les dispatchers ---------- }
{ Pour chaque groupe multi, genere un PROC _RKS_nom qui lit     }
{ _RK_MULTISIG (type du 1er argument) et JMP vers le candidat   }
{ correspondant. Le candidat par defaut (sans contrainte de      }
{ type) est utilise en dernier recours.                          }
Procedure EmitMultiDispatchers;
Var
  G       : Integer;
  V       : Integer;
  DispLbl : TString;
  S       : TString;
Begin
  If MultiGroupCount = 0 Then Exit;

  EmitBlankLine;
  EmitComment('=== Multi dispatchers (TODO 18) ===');

  For G := 0 To MultiGroupCount - 1 Do
  Begin
    DispLbl := '_RKS_' + SymNameClean(MultiGroupTab[G].Name);
    EmitBlankLine;
    EmitComment('dispatcher multi sub ' + MultiGroupTab[G].Name);
    EmitRaw(DispLbl + ' PROC NEAR');
    EmitInstr('MOV', 'AX, WORD PTR [_RK_MULTISIG]');

    { Emettre les CMP/JE pour chaque candidat type }
    For V := 0 To MultiGroupTab[G].VarCount - 1 Do
    Begin
      If MultiGroupTab[G].Vars[V].TypeIdx0 <> TY_UNKNOWN Then
      Begin
        Str(MultiGroupTab[G].Vars[V].TypeIdx0, S);
        EmitInstr('CMP', 'AX, ' + S);
        EmitInstr('JE', MultiGroupTab[G].Vars[V].LblName);
      End;
    End;

    { Candidat par defaut ou erreur }
    If MultiGroupTab[G].DefIdx >= 0 Then
      EmitInstr('JMP', MultiGroupTab[G].Vars[
                       MultiGroupTab[G].DefIdx].LblName)
    Else
    Begin
      { Pas de candidat par defaut -> erreur runtime }
      EmitInstr('MOV', 'AX, OFFSET _RKK_NOMDISP');
      EmitInstr('CALL', '_RKRT_OUTSTR');
      EmitInstr('CALL', '_RKRT_NEWLINE');
      EmitInstr('MOV', 'AX, 4C01h');
      EmitInstr('INT', '21h');
    End;

    EmitRaw(DispLbl + ' ENDP');
  End;
  EmitBlankLine;
End;

{ ============================================================
  TODO 19 - CLASSES ET OBJETS (class, has, method, new) [IMPLEMENTE]
  ============================================================ }

{ ---- ClassFind : chercher une classe par nom -------------------- }
Function ClassFind(Const AName : TString) : Integer;
Var
  I : Integer;
Begin
  ClassFind := -1;
  For I := 0 To ClassCount - 1 Do
    If ClassTab[I].Name = AName Then
    Begin
      ClassFind := I;
      Exit;
    End;
End;

{ ---- ClassAdd : ajouter une classe dans ClassTab ---------------- }
Function ClassAdd(Const AName : TString;
                  ParIdx : Integer) : Integer;
Var
  Idx : Integer;
Begin
  If ClassCount >= MAX_CLASS Then
  Begin
    CompileError('table des classes pleine (max=' +
                 IntToStr(MAX_CLASS) + ')');
    ClassAdd := -1;
    Exit;
  End;
  Idx := ClassCount;
  ClassTab[Idx].Name      := AName;
  ClassTab[Idx].ParentIdx := ParIdx;
  ClassTab[Idx].AttrCount := 0;
  ClassTab[Idx].MethCount := 0;
  ClassTab[Idx].InstSize  := 2;   { 2 octets pour pointeur vtable }
  ClassTab[Idx].VtLbl     := '_RKC_' + SymNameClean(AName) + '_VT';
  Inc(ClassCount);
  ClassAdd := Idx;
End;

{ ---- ParseClassDecl : declaration de classe --------------------- }
(* Syntaxe : class Nom [is Parent] { has ...; method ...; }        *)
Procedure ParseClassDecl;
Var
  ClassName    : TString;
  ParIdx       : Integer;
  CIdx         : Integer;
  AttrRaw      : TString;
  AttrName     : TString;
  IsPublic     : Boolean;
  IsRW         : Boolean;
  MethName     : TString;
  ParamNames   : Array[0..MAX_PARAM - 1] Of TString;
  ParamCount   : Integer;
  LblSkip      : TString;
  LblRet       : TString;
  LblProc      : TString;
  LblClsEnd    : TString;
  AccLbl       : TString;
  SaveFrame    : Integer;
  SaveFnDepth  : Integer;
  SaveRetLbl   : TString;
  SaveFnName   : TString;
  SaveClassIdx : Integer;
  I            : Integer;
  Ofs          : Integer;
  OfsStr       : TString;
  SelfOfs      : Integer;
  SelfOfsStr   : TString;
  AccOfs       : Integer;
  AccOfsStr    : TString;
Begin
  { Attendre le nom de la classe }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('nom de classe attendu apres ''class''');
    Exit;
  End;
  ClassName := CurToken.Val;
  ParserAdvance;

  { Heritage optionnel : is Parent }
  ParIdx := -1;
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'is') Then
  Begin
    ParserAdvance;   { consommer 'is' }
    If CurToken.Kind = TK_IDENT Then
    Begin
      ParIdx := ClassFind(CurToken.Val);
      If ParIdx < 0 Then
        WarnMsg('classe parente inconnue : ' + CurToken.Val);
      ParserAdvance;
    End;
  End;

  { Creer l entree classe }
  CIdx := ClassAdd(ClassName, ParIdx);
  If CIdx < 0 Then Exit;
  SaveClassIdx := CurClassIdx;
  CurClassIdx := CIdx;

  { Copier attributs et methodes du parent si heritage }
  If ParIdx >= 0 Then
  Begin
    For I := 0 To ClassTab[ParIdx].AttrCount - 1 Do
      If ClassTab[CIdx].AttrCount < MAX_CLASS_ATTR Then
      Begin
        ClassTab[CIdx].Attrs[ClassTab[CIdx].AttrCount] :=
          ClassTab[ParIdx].Attrs[I];
        Inc(ClassTab[CIdx].AttrCount);
      End;
    For I := 0 To ClassTab[ParIdx].MethCount - 1 Do
      If ClassTab[CIdx].MethCount < MAX_CLASS_METH Then
      Begin
        ClassTab[CIdx].Meths[ClassTab[CIdx].MethCount] :=
          ClassTab[ParIdx].Meths[I];
        Inc(ClassTab[CIdx].MethCount);
      End;
    ClassTab[CIdx].InstSize := ClassTab[ParIdx].InstSize;
  End;

  { Attendre '{' }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
    ParserAdvance
  Else
    CompileError('''{'' attendue pour le corps de class ' + ClassName);

  { JMP par-dessus tout le code genere pour la classe }
  LblClsEnd := LabelGen;
  EmitInstr('JMP', LblClsEnd);
  EmitBlankLine;
  EmitComment('class ' + ClassName);

  { Parser le corps de la classe }
  While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) And
        (CurToken.Kind <> TK_EOF) Do
  Begin
    { --- has $.attr [is rw]; --- }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'has') Then
    Begin
      ParserAdvance;   { consommer 'has' }
      IsPublic := True;
      IsRW     := False;
      AttrName := '';

      If CurToken.Kind = TK_SCALAR Then
      Begin
        AttrRaw := CurToken.Val;
        ParserAdvance;
        { Determiner public/prive et extraire le nom }
        If (Length(AttrRaw) > 0) And (AttrRaw[1] = '.') Then
        Begin
          IsPublic := True;
          AttrName := Copy(AttrRaw, 2, Length(AttrRaw) - 1);
        End
        Else If (Length(AttrRaw) > 0) And (AttrRaw[1] = '!') Then
        Begin
          IsPublic := False;
          AttrName := Copy(AttrRaw, 2, Length(AttrRaw) - 1);
        End
        Else
          AttrName := AttrRaw;
      End
      Else
      Begin
        CompileError('attribut $.nom ou $!nom attendu apres ''has''');
        ParserAdvance;
      End;

      { Verifier 'is rw' optionnel }
      If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'is') Then
      Begin
        ParserAdvance;   { consommer 'is' }
        If (CurToken.Kind = TK_IDENT) And (CurToken.Val = 'rw') Then
        Begin
          IsRW := True;
          ParserAdvance;   { consommer 'rw' }
        End;
      End;

      { Ajouter l attribut }
      If (AttrName <> '') And
         (ClassTab[CIdx].AttrCount < MAX_CLASS_ATTR) Then
      Begin
        AccOfs := ClassTab[CIdx].InstSize;
        ClassTab[CIdx].Attrs[ClassTab[CIdx].AttrCount].Name :=
          AttrName;
        ClassTab[CIdx].Attrs[ClassTab[CIdx].AttrCount].IsPublic :=
          IsPublic;
        ClassTab[CIdx].Attrs[ClassTab[CIdx].AttrCount].IsRW :=
          IsRW;
        ClassTab[CIdx].Attrs[ClassTab[CIdx].AttrCount].Offset :=
          AccOfs;
        ClassTab[CIdx].Attrs[ClassTab[CIdx].AttrCount].TypeIdx :=
          TY_IDX_INT;
        Inc(ClassTab[CIdx].AttrCount);
        ClassTab[CIdx].InstSize := ClassTab[CIdx].InstSize + 2;

        { Generer un accesseur pour les attributs publics }
        If IsPublic Then
        Begin
          AccLbl := '_RKS_' + SymNameClean(ClassName) + '_' +
                    SymNameClean(AttrName);
          Str(AccOfs, AccOfsStr);
          EmitBlankLine;
          EmitComment('accesseur ' + ClassName + '.' + AttrName);
          EmitRaw(AccLbl + ' PROC NEAR');
          EmitProlog;
          EmitInstr('MOV', 'BX, WORD PTR [BP+4]');
          EmitInstr('MOV', 'AX, WORD PTR [BX+' + AccOfsStr + ']');
          EmitEpilog;
          EmitRaw(AccLbl + ' ENDP');
        End;
      End;

      { Consommer ';' optionnel }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        ParserAdvance;
    End
    (* --- method nom(params) { corps } --- *)
    Else If (CurToken.Kind = TK_KEYWORD) And
            (CurToken.Val = 'method') Then
    Begin
      ParserAdvance;   { consommer 'method' }

      If CurToken.Kind <> TK_IDENT Then
      Begin
        CompileError('nom de methode attendu apres ''method''');
        ParserAdvance;
      End
      Else
      Begin
        MethName := CurToken.Val;
        ParserAdvance;

        { Parser la liste de parametres : (params) }
        ParamCount := 0;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;   { consommer '(' }
          While Not ((CurToken.Kind = TK_PUNCT) And
                     (CurToken.Val = ')')) And
                (CurToken.Kind <> TK_EOF) Do
          Begin
            If CurToken.Kind = TK_SCALAR Then
            Begin
              If ParamCount < MAX_PARAM Then
              Begin
                ParamNames[ParamCount] := CurToken.Val;
                Inc(ParamCount);
              End;
              ParserAdvance;
            End
            Else If (CurToken.Kind = TK_PUNCT) And
                    (CurToken.Val = ',') Then
              ParserAdvance
            Else
              ParserAdvance;
          End;
          If (CurToken.Kind = TK_PUNCT) And
             (CurToken.Val = ')') Then
            ParserAdvance;
        End;

        { Generer les labels }
        Inc(SubCount);
        LblProc := '_RKS_' + SymNameClean(ClassName) + '_' +
                    SymNameClean(MethName);
        Str(SubCount, OfsStr);
        LblRet  := '_RKL_SRET_' + OfsStr;

        { Enregistrer la methode dans ClassTab }
        If ClassTab[CIdx].MethCount < MAX_CLASS_METH Then
        Begin
          ClassTab[CIdx].Meths[ClassTab[CIdx].MethCount].Name :=
            MethName;
          ClassTab[CIdx].Meths[ClassTab[CIdx].MethCount].LblName :=
            LblProc;
          ClassTab[CIdx].Meths[ClassTab[CIdx].MethCount].VtIdx :=
            ClassTab[CIdx].MethCount;
          Inc(ClassTab[CIdx].MethCount);
        End;

        { Sauvegarder le contexte }
        SaveFrame   := CurFrameSize;
        SaveFnDepth := CurFnDepth;
        SaveRetLbl  := CurFnRetLbl;
        SaveFnName  := CurFnName;
        CurFrameSize := 0;
        Inc(CurFnDepth);
        CurFnRetLbl  := LblRet;
        CurFnName    := ClassName + '.' + MethName;

        { Emettre le prologue de la methode }
        EmitBlankLine;
        EmitComment('method ' + ClassName + '.' + MethName +
                    '(' + IntToStr(ParamCount) + ' params)');
        EmitRaw(LblProc + ' PROC NEAR');
        EmitProlog;

        { Entrer dans une nouvelle portee }
        SymEnterScope;

        { self est a [BP + 4 + ParamCount * 2] }
        SelfOfs := 4 + ParamCount * 2;
        Str(SelfOfs, SelfOfsStr);
        SymAdd('self', '$', SC_PARAM, TY_IDX_CLASS, SelfOfs);
        EmitComment('self [BP+' + SelfOfsStr + ']');

        { Enregistrer les parametres explicites }
        For I := 0 To ParamCount - 1 Do
        Begin
          Ofs := 4 + (ParamCount - 1 - I) * 2;
          SymAdd(ParamNames[I], '$', SC_PARAM, TY_IDX_INT, Ofs);
          Str(Ofs, OfsStr);
          EmitComment('param $' + ParamNames[I] +
                      ' [BP+' + OfsStr + ']');
        End;

        (* Parser le corps *)
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
          ParserAdvance
        Else
          CompileError('''{'' attendue pour le corps de method ' +
                       MethName);

        While Not ((CurToken.Kind = TK_PUNCT) And
                   (CurToken.Val = '}')) And
              (CurToken.Kind <> TK_EOF) Do
          ParseStmt;

        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
          ParserAdvance
        Else
          CompileError('''}'' attendue a la fin de method ' +
                       MethName);

        { Label de retour }
        EmitLabel(LblRet);
        EmitEpilog;
        EmitRaw(LblProc + ' ENDP');

        { Quitter la portee et restaurer le contexte }
        SymLeaveScope;
        CurFrameSize := SaveFrame;
        CurFnDepth   := SaveFnDepth;
        CurFnRetLbl  := SaveRetLbl;
        CurFnName    := SaveFnName;
      End;
    End
    Else
    Begin
      { Instruction inconnue dans le corps de la classe }
      ParserAdvance;
    End;
  End;

  (* Consommer accolade fermante *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
    ParserAdvance;

  { Label de fin de classe }
  EmitLabel(LblClsEnd);

  { Restaurer le contexte }
  CurClassIdx := SaveClassIdx;

  EmitComment('end class ' + ClassName);
End;

{ ---- EmitClassVtables : emettre les vtables dans le code -------- }
Procedure EmitClassVtables;
Var
  C, M : Integer;
  S    : TString;
Begin
  If ClassCount = 0 Then Exit;
  EmitBlankLine;
  EmitComment('=== Vtables des classes (TODO 19) ===');
  For C := 0 To ClassCount - 1 Do
  Begin
    EmitBlankLine;
    EmitComment('vtable ' + ClassTab[C].Name);
    EmitRaw(ClassTab[C].VtLbl + ':');
    For M := 0 To ClassTab[C].MethCount - 1 Do
    Begin
      S := '        DW      OFFSET ' +
           ClassTab[C].Meths[M].LblName;
      EmitRaw(S);
    End;
    If ClassTab[C].MethCount = 0 Then
      EmitRaw('        DW      0');
  End;
  EmitBlankLine;
End;

{ ---- EmitClassRuntime : runtime pour les objets ----------------- }
Procedure EmitClassRuntime;
Begin
  If ClassCount = 0 Then Exit;
  EmitBlankLine;
  EmitComment('=== Runtime classes (TODO 19) ===');
  EmitBlankLine;

  { _RKRT_NEW : allouer CX octets sur le tas, retour AX = ptr }
  EmitComment('_RKRT_NEW : CX=taille -> AX=ptr (zero-filled)');
  EmitRaw('_RKRT_NEW PROC NEAR');
  EmitInstr('MOV', 'BX, WORD PTR [_RK_HEAPTOP]');
  EmitInstr('MOV', 'AX, BX');
  EmitInstr('ADD', 'AX, OFFSET _RK_HEAP');
  EmitInstr('ADD', 'BX, CX');
  EmitInstr('MOV', 'WORD PTR [_RK_HEAPTOP], BX');
  EmitPush('AX');
  EmitPush('CX');
  EmitInstr('MOV', 'DI, AX');
  EmitInstr('XOR', 'AL, AL');
  EmitRaw('        REP STOSB');
  EmitPop('CX');
  EmitPop('AX');
  EmitRaw('        RET');
  EmitRaw('_RKRT_NEW ENDP');
  EmitBlankLine;
End;

Procedure ParseStmt;
Var
  Kw : TString;
Begin
  If CurToken.Kind = TK_EOF Then Exit;

  { Commentaire seul sur une ligne -> token suivant }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
  Begin
    ParserAdvance;
    Exit;
  End;

  { Declarateurs : my, our, has, constant }
  If CurToken.Kind = TK_KEYWORD Then
  Begin
    Kw := CurToken.Val;
    If (Kw = 'my') Or (Kw = 'our') Or (Kw = 'has') Or
       (Kw = 'constant') Then
    Begin
      ParserAdvance;   { consommer le mot-cle }
      ParseDeclStmt(Kw);
      Exit;
    End;

    { Conditionnelles (TODO 13) }
    If Kw = 'if' Then
    Begin
      ParserAdvance;   { consommer 'if' }
      ParseIfStmt;
      Exit;
    End;
    If Kw = 'unless' Then
    Begin
      ParserAdvance;   { consommer 'unless' }
      ParseUnlessStmt;
      Exit;
    End;
    If Kw = 'given' Then
    Begin
      ParserAdvance;   { consommer 'given' }
      ParseGivenWhenStmt;
      Exit;
    End;

    { Boucles (TODO 14) }
    If Kw = 'while' Then
    Begin
      ParserAdvance;   { consommer 'while' }
      ParseWhileStmt;
      Exit;
    End;
    If Kw = 'until' Then
    Begin
      ParserAdvance;   { consommer 'until' }
      ParseUntilStmt;
      Exit;
    End;
    If Kw = 'loop' Then
    Begin
      ParserAdvance;   { consommer 'loop' }
      ParseLoopStmt;
      Exit;
    End;
    If Kw = 'repeat' Then
    Begin
      ParserAdvance;   { consommer 'repeat' }
      ParseRepeatStmt;
      Exit;
    End;
    If Kw = 'for' Then
    Begin
      ParserAdvance;   { consommer 'for' }
      ParseForStmt;
      Exit;
    End;

    { Sous-routines (TODO 17) }
    If Kw = 'sub' Then
    Begin
      ParserAdvance;   { consommer 'sub' }
      ParseSubDecl;
      Exit;
    End;
    If Kw = 'return' Then
    Begin
      ParserAdvance;   { consommer 'return' }
      ParseReturnStmt;
      Exit;
    End;

    { Multi dispatch (TODO 18) }
    If Kw = 'multi' Then
    Begin
      ParserAdvance;   { consommer 'multi' }
      ParseMultiDecl;
      Exit;
    End;
    If Kw = 'proto' Then
    Begin
      ParserAdvance;   { consommer 'proto' }
      ParseProtoDecl;
      Exit;
    End;

    { Classes et objets (TODO 19) }
    If Kw = 'class' Then
    Begin
      ParserAdvance;   { consommer 'class' }
      ParseClassDecl;
      Exit;
    End;

    { Controle de boucle : last, next, redo }
    If Kw = 'last' Then
    Begin
      ParserAdvance;   { consommer 'last' }
      If LoopTop > 0 Then
        EmitInstr('JMP', LoopBreakLbl[LoopTop - 1])
      Else
        EmitComment('last: hors d''une boucle (ignore)');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        ParserAdvance;
      Exit;
    End;
    If Kw = 'next' Then
    Begin
      ParserAdvance;   { consommer 'next' }
      If LoopTop > 0 Then
        EmitInstr('JMP', LoopContLbl[LoopTop - 1])
      Else
        EmitComment('next: hors d''une boucle (ignore)');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        ParserAdvance;
      Exit;
    End;
    If Kw = 'redo' Then
    Begin
      ParserAdvance;   { consommer 'redo' }
      If LoopTop > 0 Then
        EmitInstr('JMP', LoopRedoLbl[LoopTop - 1])
      Else
        EmitComment('redo: hors d''une boucle (ignore)');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        ParserAdvance;
      Exit;
    End;
  End;

  { Expression-instruction (affectation, appel, etc.) }
  ParseExprStmt;
End;

{ ============================================================
  PROCEDURE Run
  ============================================================ }
Procedure Run;
Begin
  TypeInit;
  SymInit;
  DataInit;
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
  IfCount        := 0;
  GivenCount     := 0;
  WhileCount     := 0;
  UntilCount     := 0;
  LoopCount      := 0;
  RepeatCount    := 0;
  ForCount       := 0;
  ArrayTempCount := 0;
  HashTempCount  := 0;
  SubCount       := 0;
  MultiGroupCount := 0;
  MultiCount      := 0;
  ClassCount      := 0;
  CurClassIdx     := -1;
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
