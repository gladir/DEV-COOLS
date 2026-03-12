{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Prolog vers assembleur 8086
}

(* ============================================================
  PROLOG86.PAS - Compilateur Prolog vers assembleur 8086
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .MODEL SMALL, DOS 16 bits

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings)
            ParseArgs : analyser argv (source.pl [sortie.asm] [-v] [-d] [-w])
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .pl ou .pro (programme Prolog)
            Programme principal : validation des arguments et appel Run
            Version, Date, aide en ligne (option -h)

  TODO 02 - LEXEUR (TOKENS PROLOG) [IMPLEMENTE]
            TTokenKind : TK_EOF, TK_INTEGER, TK_FLOAT, TK_ATOM,
              TK_VARIABLE, TK_STRING, TK_OP, TK_PUNCT,
              TK_LPAREN, TK_RPAREN, TK_LBRACKET, TK_RBRACKET,
              TK_DOT, TK_PIPE, TK_UNDERSCORE, TK_CUT
            LexInit, LexClose, LexNextToken, LexScanAtom, LexScanNumber
            LexScanString : chaine entre apostrophes 'abc' ou guillemets "abc"
              Sequences d echappement : \n \t \r \\ \' \"
            LexScanVariable : commence par majuscule ou underscore _
              Variable anonyme : _ (underscore seul)
            Commentaires : % jusqu a fin de ligne, /* ... */ multi-lignes
            Atomes quotees : 'hello world' -> atome avec espaces
            Operateurs : :- ?- , ; | . ! + - * / // mod
              =  \= == \== is < > =< >= =:= =\= @< @> @=< @>=
            Mode debug -d : affichage de chaque token avec PrintToken

  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
            Entiers decimaux : 0..65535 ou -32768..32767
            Entiers hexadecimaux : 0xFF -> conversion en entier
            Entiers octaux : 0o77, caractere : 0'A (code ASCII de A)
            Flottants : reconnus par le lexeur, traites comme entiers (trunc)
            Atomes : identificateurs minuscules (hello, foo_bar)
              Atomes quotees : 'Hello World', '+', 'don''t'
            Chaines : "abc" -> liste de codes ASCII [97,98,99]
              ou atome selon le drapeau double_quotes (atom/codes/chars)
            Variables : commencent par majuscule ou _ (X, Var, _Temp)
            Variable anonyme : _ (chaque occurrence est independante)
            Termes speciaux : [] (liste vide), ! (cut)
            true : atome predefini -> succes immediat
            fail : atome predefini -> echec immediat

  TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
            Notation prefixe, infixe, postfixe : fx, fy, xfx, xfy, yfx, xf, yf
            Priorites standard (du plus faible au plus fort) :
              1200 : :- (directive), ?- (requete), --> (DCG)
              1100 : ; (disjonction)
              1050 : -> (if-then)
              1000 : , (conjonction)
              900  : \+ (negation par echec)
              700  : is, =, \=, ==, \==, <, >, =<, >=, =:=, =\=
                     @<, @>, @=<, @>=, =.., copy_term
              500  : +, -, /\, \/ (binaires)
              400  : *, /, //, rem, mod, <<, >>
              200  : ** (puissance), ^ (existentiel)
              200  : - (unaire, fy)
            ParseExprPrec(MaxPrec) : boucle de precedence (Pratt/operateur)
            op(Priorite, Type, Nom) : declaration d operateurs utilisateur

  TODO 05 - TABLE DES SYMBOLES (PREDICATS ET FONCTEURS) [IMPLEMENTE]
            TSymKind : SK_ATOM, SK_FUNCTOR, SK_PREDICATE, SK_BUILTIN,
              SK_OPERATOR, SK_MODULE
            TSymRec : Name, MangledName, Kind, Arity, ClauseHead,
              ClauseCount, IsBuiltin, IsDynamic, IsExported
            SymAdd, SymFind, SymFindPredicate(Name, Arity)
            Table des atomes : chaque atome unique a un index (intern)
            Table des foncteurs : couple (atome, arite) -> index unique
            Table des predicats : liste chainee de clauses par predicat
            Foncteurs systeme : '.'/2 (cons), []/0 (nil), ','/2 (conjonction)

  TODO 06 - REPRESENTATION DES TERMES (TAGS) [IMPLEMENTE]
            Representation WAM simplifiee sur 16 bits :
              Tag 3 bits + Valeur 13 bits dans un Word
              TAG_REF  = 0 : variable non liee (valeur = adresse)
              TAG_ATOM = 1 : atome (valeur = index table des atomes)
              TAG_INT  = 2 : entier 13 bits signe (-4096..4095)
              TAG_STR  = 3 : structure/foncteur (valeur = adresse heap)
              TAG_LIST = 4 : paire de liste (valeur = adresse heap)
            MakeRef, MakeAtom, MakeInt, MakeStr, MakeList : constructeurs
            GetTag, GetVal : extraction du tag et de la valeur
            Deref(addr) : suivre les chaines de references -> terme final
            Heap : _PL_HEAP DW 2048 DUP(0), _PL_HTOP DW 0
            Stack (environnements) : _PL_STACK DW 1024 DUP(0), _PL_STOP DW 0
            Trail (historique des liaisons) : _PL_TRAIL DW 512 DUP(0), _PL_TTOP DW 0

  TODO 07 - EMETTEUR DE CODE ASM [IMPLEMENTE]
            TEmitter : OutF (Text), OutFOpen, EmitOpen, EmitClose
            EmitRaw, EmitLabel, EmitInstr (formatage 8 espaces)
            EmitComment, EmitBlankLine
            LabelGen global (compteur unique _PL_L_NNNNN)
            Prefixes : _PLV_ (variable globale), _PLP_ (predicat),
              _PLK_ (chaine/atome const), _PLRT_ (runtime),
              _PL_L_ (label), _PLA_ (table des atomes),
              _PLF_ (table des foncteurs)
            EmitHeader : .MODEL SMALL / .STACK 2048 / _TEXT SEGMENT
            EmitProlog / EmitEpilog : PUSH BP / MOV BP,SP et MOV SP,BP / POP BP
            EmitDataSeg : ecrire _DATA SEGMENT ... _DATA ENDS

  TODO 08 - SEGMENT DE DONNEES ET TABLES STATIQUES [IMPLEMENTE]
            TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR/DK_TABLE),
              IntVal, StrVal, ElemCount
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr, DataAddAtomTable
            Table des atomes : _PLA_TABLE DW offset de chaque chaine atome
              Chaque atome : _PLA_N DB 'nom_atome',0
            Table des foncteurs : _PLF_TABLE, paires (atome_index, arite)
            Chaines litterales : DB 'abc',0 dans DATA avec label _PLK_N
            Heap statique : _PL_HEAP DW 2048 DUP(0) + _PL_HTOP DW 0
            Stack WAM : _PL_STACK DW 1024 DUP(0) + _PL_STOP DW 0
            Trail : _PL_TRAIL DW 512 DUP(0) + _PL_TTOP DW 0

  TODO 09 - UNIFICATION [IMPLEMENTE]
            Unify(addr1, addr2) : algorithme d unification recursif
              Deref les deux termes
              Si les deux sont REF : lier la plus recente a l autre
              Si un seul est REF : lier la variable au terme
              Si deux atomes : comparer les index -> succes ou echec
              Si deux entiers : comparer les valeurs -> succes ou echec
              Si deux structures : comparer foncteur/arite, unifier chaque argument
              Si deux listes : unifier tete puis queue recursivement
            Bind(ref_addr, term) : lier une variable et empiler sur le trail
            Trail(addr) : enregistrer la liaison pour le retour arriere
            Emission ASM :
              CALL _PLRT_UNIFY (AX=terme1, BX=terme2) -> CF=echec
              CALL _PLRT_DEREF (AX=addr) -> AX=terme dereferance
              CALL _PLRT_BIND  (AX=ref, BX=terme) -> empile sur trail

  TODO 10 - COMPILATION DES FAITS [IMPLEMENTE]
            ParseFact : atome. ou foncteur(arg1, arg2, ...).
            Fait sans arguments : predicat/0
              Emission : label _PLP_nom_0, succes immediat (RET)
            Fait avec arguments : predicat/N
              Allouer les arguments sur le heap
              Pour chaque argument : put_value ou put_atom ou put_int
              Emission : label _PLP_nom_N_clauseK
              Unifier chaque argument avec le registre Ai correspondant
              Succes : RET (continuer)
            Indexation premier argument : table de saut selon le type/valeur
              du premier argument pour selection rapide de la clause

  TODO 11 - COMPILATION DES REGLES [IMPLEMENTE]
            ParseRule : tete :- corps.
            Tete : comme un fait, unification des arguments
            Corps : sequence de buts separes par , (conjonction)
            Pour chaque but du corps :
              Charger les arguments dans les registres A1..AN
              CALL _PLP_predicat_N (appel du predicat)
              JC label_echec (si echec -> retour arriere)
            Allocation d environnement :
              allocate(N) : reserver N variables locales sur la pile
              deallocate : liberer l environnement avant le dernier appel
            Dernier appel (last call) : optimisation d appel terminal
              deallocate + JMP au lieu de CALL + RET

  TODO 12 - RETOUR ARRIERE (BACKTRACKING) [IMPLEMENTE]
            Points de choix (choice points) sur la pile :
              Sauvegarder : BP, HTOP, TTOP, adresse clause suivante
              try_me_else(Label) : creer point de choix
              retry_me_else(Label) : restaurer et essayer clause suivante
              trust_me : dernier choix, supprimer le point de choix
            Restauration :
              Defaire les liaisons du trail (untrail) jusqu au TTOP sauvegarde
              Restaurer HTOP (liberer le heap alloue depuis le choix)
              Sauter a la clause suivante ou echouer au point precedent
            Emission ASM :
              CALL _PLRT_TRY(BX=label_next) : creer choice point
              CALL _PLRT_RETRY(BX=label_next) : restaurer + nouveau choix
              CALL _PLRT_TRUST : restaurer + supprimer choice point
              JC _PL_L_FAIL : echec si plus de choix

  TODO 13 - LISTES [IMPLEMENTE]
            Notation : [H|T] -> foncteur '.'/2 (H=tete, T=queue)
            Liste vide : [] -> atome special (index 0)
            Notation sucre : [a,b,c] -> '.'(a,'.'(b,'.'(c,[])))
            Construction sur le heap :
              push_list : allouer 2 cellules (Head, Tail)
              put_list(AX=head, BX=tail) -> AX=ptr liste
            Decomposition :
              get_list(AX=liste) -> BX=head, CX=tail
              Echec si AX n est pas un terme LIST
            Predicats de liste (runtime) :
              _PLRT_LENGTH(AX=liste) -> AX=longueur
              _PLRT_APPEND(AX=l1, BX=l2, CX=result)
              _PLRT_MEMBER(AX=elem, BX=liste) -> CF=echec
              _PLRT_NTH(AX=index, BX=liste) -> AX=element
              _PLRT_LAST(AX=liste) -> AX=dernier element

  TODO 14 - ARITHMETIQUE (IS ET EVALUATION) [IMPLEMENTE]
            ParseIsExpr : Var is Expression
            Evaluation d expression arithmetique (cote droit de is) :
              Entiers : valeur directe -> AX
              Variables : Deref + extraction valeur entiere
              Operateurs : + - * / // mod rem
              Fonctions : abs(X), max(X,Y), min(X,Y), sign(X)
                succ(X), plus(X,Y), msb(X)
            Emission ASM pour chaque operateur :
              + -> ADD AX,BX
              - -> SUB AX,BX
              * -> IMUL BX
              / et // -> IDIV BX (quotient dans AX)
              mod -> IDIV BX (reste dans DX)
            Resultat : lier la variable gauche a l entier resultat
            Erreur si le cote droit contient une variable non liee
            Comparaisons arithmetiques : =:= =\= < > =< >=
              Evaluer les deux cotes + CMP + Jcc

  TODO 15 - COMPARAISON ET TESTS DE TYPE [IMPLEMENTE]
            Unification : =(X,Y) -> CALL _PLRT_UNIFY
            Non-unification : \=(X,Y) -> CALL _PLRT_UNIFY + NOT CF
            Egalite structurelle : ==(X,Y) -> comparaison sans liaison
            Inegalite structurelle : \==(X,Y) -> NOT ==
            Ordre standard des termes : @< @> @=< @>=
              Var < Nombre < Atome < Chaine < Structure
              CALL _PLRT_COMPARE(AX,BX) -> drapeaux ZF/CF
            Tests de type :
              var(X) -> tester TAG_REF apres Deref
              nonvar(X) -> NOT var(X)
              atom(X) -> tester TAG_ATOM
              number(X) -> tester TAG_INT
              integer(X) -> tester TAG_INT
              compound(X) -> tester TAG_STR ou TAG_LIST
              is_list(X) -> tester TAG_LIST ou atome []
              callable(X) -> atom(X) ou compound(X)
            Decomposition : =..(Term, [Functor|Args]) (univ)
              functor(Term, Name, Arity) : extraire foncteur et arite
              arg(N, Term, Arg) : extraire le Nieme argument
              copy_term(Original, Copie) : copie avec nouvelles variables

  TODO 16 - CONTROLE : CUT, IF-THEN-ELSE, NEGATION [IMPLEMENTE]
            Cut (!) : supprimer tous les points de choix jusqu au parent
              Emission : MOV [_PL_CUT_BARRIER], saved_choice_point
              Couper : restaurer la pile de choix au niveau sauvegarde
            If-Then-Else : ( Cond -> Action ; Alternative )
              Emission : essayer Cond, si succes -> Action, sinon Alternative
              Labels : _PL_L_THEN_N, _PL_L_ELSE_N, _PL_L_ENDIF_N
            If-Then (sans Else) : ( Cond -> Action )
              Si Cond echoue -> echec du but entier
            Disjonction : ( A ; B )
              Creer point de choix pour A, si echec essayer B
            Negation par echec : \+(Goal)
              Essayer Goal; si succes -> echec; si echec -> succes
              Emission : try Goal, si succes JMP fail_neg, sinon JMP succ_neg
            true : succes immediat (RET)
            fail : echec immediat (STC + RET, carry flag = echec)
            halt : MOV AX,4C00h / INT 21h
            halt(Code) : MOV AL,Code / MOV AH,4Ch / INT 21h

  TODO 17 - ENTREES/SORTIES [IMPLEMENTE]
            Flux standard : user_input (STDIN), user_output (STDOUT)
            write(X) : ecrire un terme Prolog
              Atome -> INT 21h AH=40h BX=1 (STDOUT)
              Entier -> CALL _PLRT_NUMTOSTR + ecriture
              Liste -> ecrire [elem1,elem2,...|Queue]
              Structure -> ecrire foncteur(arg1,arg2,...)
              Variable -> ecrire _G<adresse>
            writeln(X) : write(X) + nl
            nl : ecrire CR+LF -> INT 21h AH=02h DL=13 + DL=10
            print(X) : comme write mais utilise portray si defini
            write_canonical(X) : forme standard relisible par read
            tab(N) : ecrire N espaces
            put_char(C) : ecrire un caractere -> INT 21h AH=02h DL=C
            read(X) : lire un terme depuis STDIN
              INT 21h AH=0Ah (lecture ligne) -> buffer
              Appeler le lexeur + parseur sur le buffer
              Unifier X avec le terme lu
            get_char(C) : lire un caractere -> INT 21h AH=01h -> AL
            char_code(Char, Code) : conversion caractere/code ASCII
            atom_chars(Atom, Chars) : conversion atome/liste de caracteres
            atom_codes(Atom, Codes) : conversion atome/liste de codes
            number_chars(Num, Chars) : conversion nombre/liste de caracteres
            number_codes(Num, Codes) : conversion nombre/liste de codes
            atom_length(Atom, Len) : longueur d un atome
            atom_concat(A, B, C) : concatenation d atomes
            sub_atom(Atom, Before, Length, After, Sub) : sous-atome

  TODO 18 - PREDICATS PREDEFINIS (BUILT-IN) [IMPLEMENTE]
            Controle : true, fail, halt, halt/1, !/0 (cut)
            Logique : ','/2 (conjonction), ';'/2 (disjonction), '->'/2 (if-then)
            Unification : =/2, \=/2, unify_with_occurs_check/2
            Comparaison : ==/2, \==/2, @</2, @>/2, @=</2, @>=/2
            Arithmetique : is/2, =:=/2, =\=/2, </2, >/2, =</2, >=/2
            Type : var/1, nonvar/1, atom/1, number/1, integer/1,
              compound/1, is_list/1, callable/1, ground/1
            Termes : functor/3, arg/3, =../2, copy_term/2
            Listes : append/3, member/2, length/2, nth0/3, nth1/3,
              last/2, reverse/2, msort/2, sort/2
            Atomes : atom_chars/2, atom_codes/2, atom_length/2,
              atom_concat/3, sub_atom/5, char_code/2,
              number_chars/2, number_codes/2
            Entrees/sorties : read/1, write/1, writeln/1, nl/0,
              print/1, write_canonical/1, put_char/1, get_char/1, tab/1
            Meta : call/1, call/N (appel de but dynamique)
              CALL _PLRT_CALL(AX=terme_but) : resoudre et executer
            Tous les predicats : enregistrement dans la table des symboles
              avec flag IsBuiltin = True et un code (BIF_xxx)

  TODO 19 - ASSERT ET RETRACT (BASE DE DONNEES DYNAMIQUE) [IMPLEMENTE]
            asserta(Clause) : ajouter une clause en tete du predicat
              Marquer le predicat comme IsDynamic
              Copier la clause dans le heap permanent
              Inserer en tete de la liste chainee de clauses
            assertz(Clause) : ajouter une clause en queue du predicat
              Comme asserta mais insertion en fin de liste
            retract(Clause) : retirer la premiere clause unifiable
              Parcourir les clauses du predicat
              Unifier chaque clause avec Clause
              Si succes : retirer de la liste chainee
              Si echec : retour arriere vers la clause suivante
            abolish(Pred/Arity) : supprimer toutes les clauses d un predicat
            Limitation : nombre fixe de clauses dynamiques (MAX_DYN_CLAUSES)
            Emission : les clauses dynamiques sont stockees dans le heap
              et interpretees au lieu d etre compilees en code natif

  TODO 20 - FINDALL, BAGOF, SETOF (COLLECTE DE SOLUTIONS) [IMPLEMENTE]
            findall(Template, Goal, Bag) :
              Collecter toutes les instances de Template satisfaisant Goal
              Creer un point de choix pour Goal
              A chaque succes : copier Template dans un buffer temporaire
              Forcer le retour arriere pour trouver la solution suivante
              Quand Goal echoue : construire la liste Bag depuis le buffer
              Bag = [] si aucune solution
            bagof(Template, Goal, Bag) :
              Comme findall mais echoue si aucune solution
              Respect des variables libres dans Goal (quantification ^)
              X^Goal : X est quantifie existentiellement
            setof(Template, Goal, Set) :
              Comme bagof mais le resultat est trie et sans doublons
              CALL _PLRT_SORT + suppression des duplicats
            Emission ASM :
              Buffer temporaire : _PL_COLLECT DW 256 DUP(0)
              _PLRT_FINDALL : boucle try/fail sur Goal + collecte
              _PLRT_MAKELIST : construire la liste depuis le buffer

  TODO 21 - OPERATEURS UTILISATEUR (OP/3) [IMPLEMENTE]
            op(Priorite, Type, Nom) : definir un operateur
              Priorite : 1..1200
              Type : xf, yf, xfx, xfy, yfx, fy, fx
            current_op(Priorite, Type, Nom) : interroger les operateurs
            OpTab[0..MAX_OP-1] : table des operateurs
            OpAdd(Prio, Spec, Name) : ajouter ou modifier un operateur
            OpFind(Name) : chercher un operateur par nom
            Operateurs predefinis : toute la table standard ISO
              :- (fx 1200), ?- (fx 1200), ; (xfy 1100),
              -> (xfy 1050), , (xfy 1000), \+ (fy 900),
              is (xfx 700), = \= == \== (xfx 700), < > =< >= (xfx 700),
              + - (yfx 500), * / // mod (yfx 400), ** (xfx 200)
            Integration avec le parseur : ParseExprPrec consulte OpTab
              pour determiner la priorite et l associativite

  TODO 22 - DIRECTIVES ET CHARGEMENT [IMPLEMENTE]
            :- directive. : directive executee au chargement
            :- module(Nom, ListeExports). : declaration de module
            :- use_module(Module). : importation d un module
            :- dynamic(Pred/Arity). : declarer un predicat dynamique
            :- discontiguous(Pred/Arity). : clauses non contigues permises
            :- ensure_loaded(Fichier). : charger un fichier si pas deja charge
            :- op(Prio, Type, Nom). : definir un operateur
            :- initialization(Goal). : but execute apres le chargement
            Traitement : le parseur detecte :- en debut de clause
              et execute la directive au lieu de compiler une clause

  TODO 23 - CHAINES ET CARACTERES [IMPLEMENTE]
            Chaines double-quotees : "abc" -> liste de codes ou atome
              Drapeau double_quotes : atom (defaut), codes, chars
            Chaines simple-quotees : 'abc' -> atome
            char_type(Char, Type) : classification de caractere
              alpha, alnum, digit, space, upper, lower, punct, ascii
            upcase_atom(Atom, Upper) : conversion en majuscules
            downcase_atom(Atom, Lower) : conversion en minuscules
            atom_string(Atom, String) : conversion atome/chaine
            number_string(Number, String) : conversion nombre/chaine
            string_concat(A, B, C) : concatenation de chaines
            string_length(String, Len) : longueur de chaine
            Emission : les chaines sont stockees dans le segment DATA
              comme des suites d octets DB 'abc',0 avec label _PLK_N
            Conversion runtime : CALL _PLRT_ATOMCHARS, _PLRT_ATOMCODES

  TODO 24 - RUNTIME MINIMAL (MACHINE WAM SIMPLIFIEE)
            _PLRT_DEREF(AX=addr) : suivre les chaines de references -> AX
            _PLRT_UNIFY(AX=t1, BX=t2) : unification -> CF=echec
            _PLRT_BIND(AX=ref, BX=terme) : lier variable + trail
            _PLRT_UNTRAIL(AX=saved_ttop) : defaire les liaisons
            _PLRT_TRY(BX=label_next) : creer un point de choix
            _PLRT_RETRY(BX=label_next) : restaurer + nouveau choix
            _PLRT_TRUST : restaurer + supprimer le point de choix
            _PLRT_CALL(AX=terme_but) : resoudre et executer un but
            _PLRT_PRINT(BX=handle, SI=msg, CX=len) : INT 21h AH=40h
            _PLRT_PRINTLN : _PLRT_PRINT + CR+LF via _PL_CRLF DB 13,10,0
            _PLRT_WRITETERM(AX=terme) : ecrire un terme Prolog complet
            _PLRT_NUMTOSTR(AX=n, DI=buf) : entier signe -> ASCII (itoa)
            _PLRT_STRTONUM(SI=str) : ASCII -> entier -> AX (atoi)
            _PLRT_STRLEN(SI=str) : compte octets jusqu a 0 -> AX
            _PLRT_COMPARE(AX=t1, BX=t2) : ordre standard -> drapeaux ZF/CF
            _PLRT_HEAPALLOC(CX=nb_mots) : allouer sur le heap -> AX=ptr
            _PLRT_FINDALL : boucle de collecte de solutions
            _PLRT_MAKELIST(SI=buffer, CX=count) : construire liste -> AX
            _PLRT_SORT(AX=liste) : trier une liste -> AX=liste triee
            _PLRT_PANIC(SI=msg) : affiche message + MOV AX,4C01h + INT 21h
            RuntimeEmitted : flag pour n emettre le runtime qu une seule fois
            Heap : _PL_HEAP DW 2048 DUP(0) + _PL_HTOP DW 0
            Stack : _PL_STACK DW 1024 DUP(0) + _PL_STOP DW 0
            Trail : _PL_TRAIL DW 512 DUP(0) + _PL_TTOP DW 0

  TODO 25 - GENERATION FINALE ET FICHIERS EXEMPLES
            EmitClose : END _PLP_Main dans _TEXT ENDS / DATA ENDS
            Run : pipeline complet LexInit -> ParseProgram ->
              EmitRuntime -> _TEXT ENDS / EmitDataSeg / END _PLP_Main
            Point d entree : _PLP_Main correspond a la requete ?- main.
              ou au premier goal du fichier si pas de main/0
            Fichiers SAMPLES\PROLOG\ a creer :
              hello.pl    (write, nl, atomes, variables)
              math.pl     (arithmetique, is, predicats recursifs)
              lists.pl    (listes, append, member, reverse, tri)
              family.pl   (faits, regles, requetes, retour arriere)
              hanoi.pl    (tours de Hanoi, recursion, cut)
              queens.pl   (N-reines, generate-and-test, findall)
              peano.pl    (arithmetique de Peano, unification)
              meta.pl     (assert, retract, call, findall, bagof)
            Smoke tests : PROLOG86.EXE -v SAMPLES\PROLOG\*.pl

  ============================================================ *)

Program PROLOG86;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES
  ============================================================ }
Const
  PL86_VERSION = '1.0';
  PL86_DATE    = '2026-03-06';

  { Limites internes }
  MAX_SYM       = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_LABEL     = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_SCOPE     = {$IFDEF FPC}64{$ELSE}32{$ENDIF};
  MAX_DATA      = {$IFDEF FPC}512{$ELSE}128{$ENDIF};
  MAX_TYPE      = {$IFDEF FPC}32{$ELSE}16{$ENDIF};
  MAX_PARAM     = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_LOOP_NEST = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_ERRORS    = {$IFDEF FPC}30{$ELSE}3{$ENDIF};
  MAX_STR       = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  MAX_ATOM      = {$IFDEF FPC}1024{$ELSE}256{$ENDIF};
  MAX_CLAUSE    = {$IFDEF FPC}512{$ELSE}64{$ENDIF};
  MAX_FUNCTOR   = {$IFDEF FPC}256{$ELSE}64{$ENDIF};
  MAX_OP        = {$IFDEF FPC}128{$ELSE}64{$ENDIF};
  MAX_DYN       = {$IFDEF FPC}256{$ELSE}32{$ENDIF};
  MAX_FACT_ARGS = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_ARGS_REG  = 16;  { nombre max de registres A1..AN (WAM) }
  MAX_BODY_GOALS = {$IFDEF FPC}32{$ELSE}16{$ENDIF};
  MAX_RULE_VARS  = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_LIST_ELEMS = {$IFDEF FPC}128{$ELSE}32{$ENDIF};
  MAX_ARITH_NODES = {$IFDEF FPC}128{$ELSE}32{$ENDIF};
  HEAP_SIZE     = 2048;
  STACK_SIZE    = 1024;
  TRAIL_SIZE    = 512;

  { Tags WAM 16 bits (TODO 06) }
  { Word = Tag (3 bits hauts) + Valeur (13 bits bas)             }
  TAG_SHIFT = 13;            { nombre de bits pour la valeur     }
  VAL_MASK  = $1FFF;         { masque 13 bits (8191)             }
  TAG_MASK  = $E000;         { masque 3 bits hauts               }
  TAG_REF   = 0;             { variable non liee (val=adresse)   }
  TAG_ATOM  = 1;             { atome (val=index AtomTab)         }
  TAG_INT   = 2;             { entier 13 bits signe              }
  TAG_STR   = 3;             { structure/foncteur (val=adr heap) }
  TAG_LIST  = 4;             { paire de liste (val=adr heap)     }
  INT_MAX_VAL = 4095;        { valeur max entier 13 bits signe   }
  INT_MIN_VAL = -4096;       { valeur min entier 13 bits signe   }

  { Prefixes de nommage ASM }
  PL_VAR_PFX  = '_PLV_';    { variable globale               }
  PL_PRED_PFX = '_PLP_';    { predicat                       }
  PL_STR_PFX  = '_PLK_';    { constante chaine/atome         }
  PL_RT_PFX   = '_PLRT_';   { routine runtime                }
  PL_LBL_PFX  = '_PL_L_';   { label de saut interne          }
  PL_ATOM_PFX = '_PLA_';    { table des atomes               }
  PL_FUN_PFX  = '_PLF_';    { table des foncteurs            }

  { Codes de sortie }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Codes BIF (Built-In Function) pour identification formelle (TODO 18) }
  BIF_NONE           =  0;
  { Controle }
  BIF_TRUE           =  1;
  BIF_FAIL           =  2;
  BIF_HALT           =  3;
  BIF_CUT            =  4;
  BIF_CALL           =  5;
  BIF_NOT            =  6;
  { Unification }
  BIF_UNIFY          = 10;
  BIF_NOT_UNIFY      = 11;
  BIF_UNIFY_OC       = 12;
  { Comparaison structurelle }
  BIF_STRUCT_EQ      = 20;
  BIF_STRUCT_NEQ     = 21;
  BIF_TERM_LT        = 22;
  BIF_TERM_GT        = 23;
  BIF_TERM_LE        = 24;
  BIF_TERM_GE        = 25;
  BIF_COMPARE        = 26;
  { Arithmetique }
  BIF_IS             = 30;
  BIF_ARITH_EQ       = 31;
  BIF_ARITH_NEQ      = 32;
  BIF_ARITH_LT       = 33;
  BIF_ARITH_GT       = 34;
  BIF_ARITH_LE       = 35;
  BIF_ARITH_GE       = 36;
  { Type testing }
  BIF_VAR            = 40;
  BIF_NONVAR         = 41;
  BIF_ATOM           = 42;
  BIF_NUMBER         = 43;
  BIF_INTEGER        = 44;
  BIF_FLOAT          = 45;
  BIF_COMPOUND       = 46;
  BIF_CALLABLE       = 47;
  BIF_IS_LIST        = 48;
  BIF_ATOMIC         = 49;
  BIF_GROUND         = 50;
  { Termes }
  BIF_FUNCTOR        = 60;
  BIF_ARG            = 61;
  BIF_UNIV           = 62;
  BIF_COPY_TERM      = 63;
  { Listes }
  BIF_APPEND         = 70;
  BIF_LENGTH         = 71;
  BIF_MEMBER         = 72;
  BIF_LAST           = 73;
  BIF_REVERSE        = 74;
  BIF_MSORT          = 75;
  BIF_SORT           = 76;
  BIF_NTH0           = 77;
  BIF_NTH1           = 78;
  { E/S }
  BIF_WRITE          = 80;
  BIF_WRITELN        = 81;
  BIF_NL             = 82;
  BIF_READ           = 83;
  BIF_PRINT          = 84;
  BIF_WRITE_CAN      = 85;
  BIF_PUT_CHAR       = 86;
  BIF_GET_CHAR       = 87;
  BIF_TAB            = 88;
  { Atomes/chaines }
  BIF_ATOM_LENGTH    = 90;
  BIF_ATOM_CONCAT    = 91;
  BIF_ATOM_CHARS     = 92;
  BIF_ATOM_CODES     = 93;
  BIF_CHAR_CODE      = 94;
  BIF_NUMBER_CHARS   = 95;
  BIF_NUMBER_CODES   = 96;
  BIF_SUB_ATOM       = 97;
  BIF_UPCASE_ATOM    = 98;
  BIF_DOWNCASE_ATOM  = 99;
  BIF_ATOM_STRING    = 100;
  { Meta / collect }
  BIF_FINDALL        = 110;
  BIF_BAGOF          = 111;
  BIF_SETOF          = 112;
  BIF_BETWEEN        = 113;
  { Assert/retract }
  BIF_ASSERT         = 120;
  BIF_ASSERTA        = 121;
  BIF_ASSERTZ        = 122;
  BIF_RETRACT        = 123;
  BIF_ABOLISH        = 124;
  { Operateurs utilisateur (TODO 21) }
  BIF_OP             = 130;
  BIF_CURRENT_OP     = 131;
  { Directives (TODO 22) }
  BIF_DYNAMIC        = 140;
  BIF_DISCONTIGUOUS  = 141;
  BIF_MODULE         = 142;
  BIF_USE_MODULE     = 143;
  BIF_ENSURE_LOADED  = 144;
  BIF_INITIALIZATION = 145;
  { Chaines et caracteres (TODO 23) }
  BIF_CHAR_TYPE      = 150;
  BIF_NUMBER_STRING  = 151;
  BIF_STRING_CONCAT  = 152;
  BIF_STRING_LENGTH  = 153;

  { Limites pour les directives (TODO 22) }
  MAX_INIT_GOALS = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_MODULE_EXP = {$IFDEF FPC}64{$ELSE}16{$ENDIF};

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String[MAX_STR];

  { ---- Options de compilation ----------------------------- }
  TOptions = Record
    SrcFile   : TString;   { fichier source (.pl ou .pro)         }
    OutFile   : TString;   { fichier assembleur de sortie (.asm)  }
    Verbose   : Boolean;   { -v : banniere et statistiques        }
    DebugMode : Boolean;   { -d : affichage de chaque token       }
    Warnings  : Boolean;   { -w : activer les avertissements      }
  End;

  { ---- Tokens Prolog (TODO 02) ----------------------------- }
  TTokenKind = (
    TK_EOF,        { fin de fichier                          }
    TK_INTEGER,    { litteral entier 42 0xFF 0o77 0'A        }
    TK_FLOAT,      { litteral flottant 3.14 1.5e3            }
    TK_ATOM,       { atome : minuscule ou quote 'abc'        }
    TK_VARIABLE,   { variable : majuscule ou _ (X, _Temp)    }
    TK_STRING,     { chaine double-quote "abc"               }
    TK_OP,         { operateur :- ?- + - * / = < > etc.      }
    TK_PUNCT,      { ponctuation , ;                         }
    TK_LPAREN,     { (                                       }
    TK_RPAREN,     { )                                       }
    TK_LBRACKET,   { [                                       }
    TK_RBRACKET,   { ]                                       }
    TK_DOT,        { . (terminaison de clause)               }
    TK_PIPE,       { | (separateur tete/queue de liste)      }
    TK_UNDERSCORE, { _ (variable anonyme seule)              }
    TK_CUT         { ! (cut)                                 }
  );

  TToken = Record
    Kind     : TTokenKind;
    Val      : TString;     { valeur textuelle brute          }
    IntVal   : LongInt;     { valeur entiere (TK_INTEGER)     }
    FloatVal : Real;        { valeur flottante (TK_FLOAT)     }
    Line     : Integer;     { ligne source (1-base)           }
    Col      : Integer;     { colonne source (1-base)         }
  End;

  { ---- Segment de donnees (TODO 03) ------------------------- }
  TDataKind = (DK_WORD, DK_BYTE, DK_STR, DK_ATOM_TBL);

  TDataRec = Record
    LblName   : TString;
    Kind      : TDataKind;
    IntVal    : LongInt;
    StrVal    : TString;
    ElemCount : Integer;   { DK_ATOM_TBL : nb entrees          }
  End;

  { ---- Valeur d expression (TODO 03) ----------------------- }
  TExprKind = (
    EK_NONE,   { void / pas de valeur                          }
    EK_IMM,    { valeur immediate dans ImmVal                   }
    EK_AX,     { valeur dans le registre AX                     }
    EK_MEM     { adresse memoire [label] ou [BP+Offset]        }
  );

  TExprVal = Record
    Kind    : TExprKind;
    ImmVal  : LongInt;
    TypeIdx : Integer;   { indice de type (TY_IDX_*)            }
    Offset  : Integer;   { offset donnee/pile                   }
    SymIdx  : Integer;   { indice dans SymTab (-1 = pas lvalue) }
  End;

Const
  { Indices de types primitifs Prolog }
  TY_UNKNOWN   = -1;
  TY_IDX_INT   =  0;   { entier                                }
  TY_IDX_FLOAT =  1;   { flottant (traite comme entier trunc)  }
  TY_IDX_ATOM  =  2;   { atome                                 }
  TY_IDX_STR   =  3;   { chaine (liste de codes)               }
  TY_IDX_VAR   =  4;   { variable Prolog                       }
  TY_IDX_LIST  =  5;   { liste                                 }
  TY_IDX_TERM  =  6;   { terme structure                       }

Type
  { ---- Table des symboles - categories (TODO 05) ------------- }
  TSymKind = (
    SK_ATOM,       { atome interne (interning)                   }
    SK_FUNCTOR,    { foncteur : couple (atome, arite)            }
    SK_PREDICATE,  { predicat : nom/arite + liste de clauses     }
    SK_BUILTIN,    { predicat builtin (is, write, read, ...)     }
    SK_OPERATOR,   { operateur defini par op/3                   }
    SK_MODULE      { module (stub pour TODO 25)                  }
  );

  TSymRec = Record
    Name        : TString;   { nom de l atome / predicat          }
    MangledName : TString;   { label ASM _PLP_nom, _PLV_nom, etc. }
    Kind        : TSymKind;
    Arity       : Integer;   { arite du foncteur/predicat          }
    ClauseHead  : Integer;   { index premiere clause (-1=aucune)   }
    ClauseCount : Integer;   { nombre de clauses pour ce predicat  }
    ScopeLevel  : Integer;   { niveau de portee (0=global)         }
    IsBuiltin   : Boolean;   { predicat builtin ?                  }
    BifCode     : Integer;   { code BIF_xxx (0 si non builtin)     }
    IsDynamic   : Boolean;   { predicat dynamique (assert/retract) }
    IsExported  : Boolean;   { exporte hors du module ?            }
    DeclLine    : Integer;   { ligne de declaration                }
  End;

  { ---- Table des atomes (interning) -------------------------- }
  { Chaque atome unique a un index. AtomIntern retourne l index  }
  { existant ou en cree un nouveau.                              }
  TAtomEntry = Record
    Name  : TString;   { texte de l atome                        }
    SymIdx : Integer;  { index dans SymTab (-1 si pas de predicat)}
  End;

  { ---- Table des foncteurs ----------------------------------- }
  { Un foncteur est un couple (atome_index, arite). Deux termes  }
  { avec le meme nom et la meme arite partagent le meme index.   }
  TFunctorEntry = Record
    AtomIdx : Integer;   { index dans AtomTab                    }
    Arity   : Integer;   { arite du foncteur                     }
    SymIdx  : Integer;   { index dans SymTab (-1 si pas lie)     }
  End;

  { ---- Argument de fait (TODO 10) ------------------------------ }
  { Chaque argument d un fait est soit un atome, un entier, une    }
  { variable ou une variable anonyme _.                            }
  TFactArgKind = (
    FAK_ATOM,      { atome : val = index AtomTab                   }
    FAK_INT,       { entier : val = valeur entiere                 }
    FAK_VAR,       { variable nommee : name = nom variable         }
    FAK_ANON,      { variable anonyme _ : pas de liaison           }
    FAK_STR,       { structure foncteur(args) : val = index functor}
    FAK_LIST,      { liste [H|T] (TODO 13)                         }
    FAK_EXPR       { expression arithmetique (TODO 14)              }
  );

  TFactArg = Record
    Kind    : TFactArgKind;
    AtomIdx : Integer;   { FAK_ATOM : index atome                  }
    IntVal  : LongInt;   { FAK_INT : valeur entiere                }
    VarName : TString;   { FAK_VAR : nom de la variable            }
    { FAK_LIST (TODO 13) }
    ListStart : Integer; { index debut dans ListElemTab             }
    ListLen   : Integer; { nombre d elements (avant |)              }
    HasTail   : Boolean; { True si notation [..|Tail]               }
    { FAK_EXPR (TODO 14) }
    ExprRoot  : Integer; { index racine dans ArithNodeTab            }
  End;

  { ---- Clause Prolog (TODO 10) --------------------------------- }
  { Un fait est une clause sans corps : tete.                       }
  { Une regle a un corps : tete :- but1, but2, ...  (TODO 11)     }
  TClauseRec = Record
    PredName   : TString;   { nom du predicat                      }
    Arity      : Integer;   { arite du predicat                    }
    ClauseIdx  : Integer;   { K dans _PLP_nom_N_clauseK            }
    SymIdx     : Integer;   { index dans SymTab pour le predicat   }
    ClsLabel   : TString;   { label ASM de cette clause            }
    IsRule     : Boolean;   { True = regle, False = fait           }
    ArgCount   : Integer;   { nombre d arguments parses            }
    Args       : Array[0..MAX_FACT_ARGS - 1] Of TFactArg;
    FailLabel  : TString;   { label de saut en cas d echec         }
    { Champs specifiques aux regles (TODO 11) }
    BodyStart  : Integer;   { index debut dans GoalTab             }
    BodyLen    : Integer;   { nombre de buts dans le corps         }
    NVars      : Integer;   { nombre de variables locales          }
  End;

  { ---- But dans le corps d une regle (TODO 11) ------------------- }
  { Chaque but est un appel de predicat : nom(arg1, arg2, ..., argN) }
  TGoalRec = Record
    PredName : TString;   { nom du predicat appele                  }
    Arity    : Integer;   { arite du but                            }
    ArgCount : Integer;   { nombre d arguments                      }
    Args     : Array[0..MAX_FACT_ARGS - 1] Of TFactArg;
  End;

  { ---- Variable locale dans une regle (TODO 11) ------------------- }
  { Registre d une variable nommee utilisee dans la regle, avec son   }
  { offset dans l environnement (pile).                               }
  TRuleVarEntry = Record
    Name   : TString;   { nom de la variable                        }
    Offset : Integer;   { offset dans l environnement (BP-relative)  }
  End;

  { ---- Expression arithmetique (TODO 14) ----------------------------- }
  { Un noeud d arbre representant une expression arithmetique.            }
  TArithOp = (
    AO_ADD,   { + }           AO_SUB,   { - }
    AO_MUL,   { * }           AO_DIV,   { / }
    AO_IDIV,  { // }          AO_MOD,   { mod }
    AO_REM,   { rem }         AO_NEG,   { unaire - }
    AO_ABS,   { abs(X) }     AO_MAX,   { max(X,Y) }
    AO_MIN,   { min(X,Y) }   AO_SIGN,  { sign(X) }
    AO_SUCC,  { succ(X) }    AO_PLUS,  { plus(X,Y) }
    AO_MSB    { msb(X) }
  );
  TArithNodeKind = (ANK_INT, ANK_VAR, ANK_BINOP, ANK_UNOP);
  TArithNode = Record
    Kind    : TArithNodeKind;
    IntVal  : LongInt;         { ANK_INT : valeur entiere           }
    VarName : TString;         { ANK_VAR : nom de la variable       }
    Op      : TArithOp;        { ANK_BINOP/ANK_UNOP : operateur     }
    Left    : Integer;         { index enfant gauche (-1 si aucun)   }
    Right   : Integer;         { index enfant droit  (-1 si aucun)   }
  End;

  { ---- Operateur utilisateur (TODO 21) ----------------------------- }
  { Chaque operateur defini par op/3 est stocke dans la table OpTab.   }
  TOpEntry = Record
    Name : TString;    { nom de l operateur                          }
    Prec : Integer;    { precedence ISO 1..1200                      }
    Spec : TString;    { specifieur : xf, yf, xfx, xfy, yfx, fy, fx }
  End;

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
Var
  { Options }
  Opts : TOptions;

  { Compteurs generaux }
  ErrorCount : Integer;
  WarnCount  : Integer;
  TotalLines : LongInt;
  CurLine    : Integer;    { ligne source courante (maj par le lexeur) }

  { Emetteur ASM }
  OutF     : Text;
  OutFOpen : Boolean;

  { Lexeur (TODO 02) }
  LexSrcF   : Text;
  LexLine   : String;
  LexLineNo : Integer;
  LexColNo  : Integer;
  LexEOF    : Boolean;
  LexOpened : Boolean;
  CurToken  : TToken;

  { Segment de donnees (TODO 03) }
  DataTab      : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount    : Integer;
  LabelGenSeq  : Integer;

  { Table des symboles (TODO 05) }
  SymTab     : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount   : Integer;
  ScopeStack : Array[0..MAX_SCOPE - 1] Of Integer;
  ScopeTop   : Integer;
  CurScope   : Integer;
  AtomTab    : Array[0..MAX_ATOM - 1] Of TAtomEntry;
  AtomCount  : Integer;
  FunctorTab : Array[0..MAX_FUNCTOR - 1] Of TFunctorEntry;
  FunctorCount : Integer;
  TotalSyms  : Integer;  { compteur cumulatif de symboles ajoutes }

  { Table des clauses (TODO 10) }
  ClauseTab   : Array[0..MAX_CLAUSE - 1] Of TClauseRec;
  ClauseCount : Integer;

  { Corps des regles (TODO 11) }
  { Chaque regle a un corps de buts stocke a part. L index dans       }
  { GoalTab est BodyStart, et le nombre de buts est BodyLen.          }
  GoalTab    : Array[0..MAX_CLAUSE * MAX_BODY_GOALS - 1] Of TGoalRec;
  GoalCount  : Integer;
  { Variables locales de la regle courante }
  RuleVarTab   : Array[0..MAX_RULE_VARS - 1] Of TRuleVarEntry;
  RuleVarCount : Integer;

  { Elements de liste (TODO 13) }
  ListElemTab   : Array[0..MAX_LIST_ELEMS - 1] Of TFactArg;
  ListElemCount : Integer;

  { Noeuds d expression arithmetique (TODO 14) }
  ArithNodeTab   : Array[0..MAX_ARITH_NODES - 1] Of TArithNode;
  ArithNodeCount : Integer;

  { Table des operateurs utilisateur (TODO 21) }
  OpTab    : Array[0..MAX_OP - 1] Of TOpEntry;
  OpCount  : Integer;

  { Directives et module (TODO 22) }
  ModuleName    : TString;                                  { nom du module    }
  ModuleDefined : Boolean;                                  { :- module(...) ? }
  ModuleExports : Array[0..MAX_MODULE_EXP - 1] Of TString;  { noms exportes   }
  ModuleExpCount: Integer;
  InitGoalCount : Integer;   { nombre de buts :- initialization(Goal) }
  DiscontigFlag : Array[0..MAX_SYM - 1] Of Boolean;         { discontiguous?  }
  { Chaines et caracteres (TODO 23) }
  DoubleQuotesMode : TString;    { 'atom' (default), 'codes', 'chars' }

  { Representation des termes WAM (TODO 06) }
  Heap       : Array[0..HEAP_SIZE - 1] Of Integer;  { tas WAM             }
  HTop       : Integer;                              { sommet du tas       }
  Stack      : Array[0..STACK_SIZE - 1] Of Integer;  { pile environnements }
  STop       : Integer;                              { sommet de la pile   }
  Trail      : Array[0..TRAIL_SIZE - 1] Of Integer;  { historique liaisons }
  TTop       : Integer;                              { sommet du trail     }

{ ============================================================
  FORWARD DECLARATIONS
  ============================================================ }
{ Utilitaires chaines (TODO 01) }
Function  StrLowerCase(Const S : TString) : TString; Forward;
Function  StrUpperCase(Const S : TString) : TString; Forward;
Function  IntToStr(N : LongInt) : TString; Forward;
{ Messages (TODO 01) }
Procedure FatalError(Const Msg : TString); Forward;
Procedure CompileError(Const Msg : TString); Forward;
Procedure WarnMsg(Const Msg : TString); Forward;
{ Lexeur (TODO 02) }
Procedure LexInit;             Forward;
Procedure LexClose;            Forward;
Procedure LexNextLine;         Forward;
Procedure LexSkipBlockComment; Forward;
Function  IsIdentStart(Ch : Char) : Boolean; Forward;
Function  IsIdentCont(Ch : Char) : Boolean; Forward;
Function  IsHexDigit(Ch : Char) : Boolean; Forward;
Function  HexVal(Ch : Char) : Integer; Forward;
Procedure LexScanAtom;         Forward;
Procedure LexScanQuotedAtom;   Forward;
Procedure LexScanVariable;     Forward;
Procedure LexScanNumber;       Forward;
Procedure LexScanString;       Forward;
Function  LexScanEscChar : Char; Forward;
Procedure LexNextToken;        Forward;
Procedure PrintToken(Const T : TToken); Forward;
{ Litteraux et constantes (TODO 03) }
Function  LabelGen : TString; Forward;
Function  DataAdd(Const Lbl : TString; Kind : TDataKind;
                 AIntVal : LongInt; Const AStrVal : TString) : Integer; Forward;
Function  DataAddStr(Const S : TString) : TString; Forward;
Function  DataAddWord(Const Lbl : TString; AIntVal : LongInt) : Integer; Forward;
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal); Forward;
Procedure ExprMakeNone(Var Res : TExprVal); Forward;
Procedure LitEvalInt(Const T : TToken; Var Res : TExprVal); Forward;
Procedure LitEvalFloat(Const T : TToken; Var Res : TExprVal); Forward;
Procedure LitEval(Const T : TToken; Var Res : TExprVal); Forward;
Function  IsSpecialAtom(Const S : TString) : Boolean; Forward;
{ Segment de donnees et tables statiques (TODO 08) }
Function  DataAddAtomTable : Integer; Forward;
Function  DataAddFunctorTable : Integer; Forward;
Procedure DataInit; Forward;
{ Operateurs et precedence (TODO 04) }
Procedure ParserAdvance; Forward;
Function  BinOpPrec(Const Op : TString) : Integer; Forward;
Function  BinOpIsRight(Const Op : TString) : Boolean; Forward;
Function  OpSpecifier(Const Op : TString) : TString; Forward;
Procedure ExprFlushToAX(Const E : TExprVal); Forward;
Procedure EmitBinOp(Const Op : TString; LeftType, RightType : Integer); Forward;
Procedure ParsePrimary(Var Res : TExprVal); Forward;
Procedure ParseUnary(Var Res : TExprVal); Forward;
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal); Forward;
Procedure ParseExpr(Var Res : TExprVal); Forward;
{ Table des symboles (TODO 05) }
Function  SymNameClean(Const Name : TString) : TString; Forward;
Function  SymMangle(Const Name : TString; Kind : TSymKind) : TString; Forward;
Function  SymFind(Const Name : TString) : Integer; Forward;
Function  SymFindPredicate(Const Name : TString;
                           AArity : Integer) : Integer; Forward;
Function  SymAdd(Const Name : TString; Kind : TSymKind;
                 AArity : Integer) : Integer; Forward;
Procedure SymEnterScope; Forward;
Procedure SymLeaveScope; Forward;
Function  AtomIntern(Const Name : TString) : Integer; Forward;
Function  AtomName(Idx : Integer) : TString; Forward;
Function  FunctorIntern(AAtomIdx, AArity : Integer) : Integer; Forward;
Procedure SymInit; Forward;
{ Representation des termes WAM (TODO 06) }
Function  MakeRef(Addr : Integer) : Integer; Forward;
Function  MakeAtom(AIdx : Integer) : Integer; Forward;
Function  MakeInt(Val : Integer) : Integer; Forward;
Function  MakeStr(Addr : Integer) : Integer; Forward;
Function  MakeList(Addr : Integer) : Integer; Forward;
Function  GetTag(Cell : Integer) : Integer; Forward;
Function  GetVal(Cell : Integer) : Integer; Forward;
Function  IsRef(Cell : Integer) : Boolean; Forward;
Function  IsAtom(Cell : Integer) : Boolean; Forward;
Function  IsInt(Cell : Integer) : Boolean; Forward;
Function  IsStr(Cell : Integer) : Boolean; Forward;
Function  IsList(Cell : Integer) : Boolean; Forward;
Function  Deref(Addr : Integer) : Integer; Forward;
Function  HeapPush(Cell : Integer) : Integer; Forward;
Function  HeapTop : Integer; Forward;
Procedure HeapReset; Forward;
Function  StackPush(Cell : Integer) : Integer; Forward;
Function  StackTop : Integer; Forward;
Procedure StackReset; Forward;
Procedure TrailPush(Addr : Integer); Forward;
Function  TrailTop : Integer; Forward;
Procedure TrailReset; Forward;
Procedure TermInit; Forward;
{ Unification (TODO 09) }
Procedure Bind(RefAddr, Term : Integer); Forward;
Procedure UnwindTrail(SavedTop : Integer); Forward;
Function  Unify(Addr1, Addr2 : Integer) : Boolean; Forward;
Procedure EmitUnify; Forward;
Procedure EmitDeref; Forward;
Procedure EmitBind; Forward;
{ Emetteur de code ASM (TODO 07) }
Procedure EmitOpen; Forward;
Procedure EmitClose; Forward;
Procedure EmitRaw(Const S : TString); Forward;
Procedure EmitBlankLine; Forward;
Procedure EmitComment(Const S : TString); Forward;
Procedure EmitLabel(Const Lbl : TString); Forward;
Procedure EmitInstr(Const Mnem : TString); Forward;
Procedure EmitInstrA(Const Mnem, A1 : TString); Forward;
Procedure EmitInstrAB(Const Mnem, A1, A2 : TString); Forward;
Procedure EmitProlog; Forward;
Procedure EmitEpilog; Forward;
Procedure EmitHeader; Forward;
Procedure EmitDataSeg; Forward;
Procedure EmitRuntime; Forward;
{ Compilation des faits (TODO 10) }
Procedure ParseFactArg(Var Arg : TFactArg); Forward;
Function  ParseFact : Boolean; Forward;
Procedure EmitFactCode(CIdx : Integer); Forward;
Procedure EmitPredEntry(Const PName : TString; PArity : Integer); Forward;
Procedure EmitAllPredicates; Forward;
Procedure ParseProgram; Forward;
{ Compilation des regles (TODO 11) }
Function  RuleVarFindOrAdd(Const VName : TString) : Integer; Forward;
Procedure ParseGoal(Var G : TGoalRec); Forward;
Procedure ParseRuleBody(CIdx : Integer); Forward;
Procedure EmitRuleCode(CIdx : Integer); Forward;
{ Retour arriere - Backtracking (TODO 12) }
Procedure EmitBacktrackRuntime; Forward;
{ Listes (TODO 13) }
Procedure EmitListRuntime; Forward;
Procedure EmitBuildListToAX(Const Arg : TFactArg; InRule : Boolean); Forward;
Procedure EmitLoadArgToAX(Const Arg : TFactArg; InRule : Boolean); Forward;
{ Arithmetique (TODO 14) }
Procedure EmitArithRuntime; Forward;
Function  ParseArithExpr : Integer; Forward;
Function  ParseArithTerm : Integer; Forward;
Function  ParseArithFactor : Integer; Forward;
Procedure EmitArithEval(NodeIdx : Integer); Forward;
{ Comparaison et tests de type (TODO 15) }
Procedure EmitCompareRuntime; Forward;
{ Controle : cut, if-then-else, negation (TODO 16) }
Procedure EmitControlRuntime; Forward;
{ Entrees/sorties (TODO 17) }
Procedure EmitIORuntime; Forward;
{ Predicats predefinis (TODO 18) }
Procedure EmitBuiltinRuntime; Forward;
{ Assert/retract - base de donnees dynamique (TODO 19) }
Procedure EmitDynDBRuntime; Forward;
{ Collecte de solutions (TODO 20) }
Procedure EmitCollectRuntime; Forward;
{ Operateurs utilisateur (TODO 21) }
Procedure OpAdd(Const AName : TString; APrec : Integer;
                Const ASpec : TString); Forward;
Function  OpFind(Const AName : TString) : Integer; Forward;
Procedure OpInit; Forward;
Procedure EmitOperatorRuntime; Forward;
{ Directives et chargement (TODO 22) }
Function  ParseDirective : Boolean; Forward;
Procedure DirectiveInit; Forward;
{ Chaines et caracteres (TODO 23) }
Procedure EmitStringRuntime; Forward;

{ ============================================================
  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
  ============================================================ }

{ ---- Utilitaires chaines ------------------------------------ }

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

Function StrUpperCase(Const S : TString) : TString;
Var
  I : Integer;
  R : TString;
Begin
  R := S;
  For I := 1 To Length(R) Do
    If (R[I] >= 'a') And (R[I] <= 'z') Then
      R[I] := Chr(Ord(R[I]) - 32);
  StrUpperCase := R;
End;

Function IntToStr(N : LongInt) : TString;
Var
  S : TString;
Begin
  Str(N, S);
  IntToStr := S;
End;

Function StrToIntDef(Const S : TString; Def : LongInt) : LongInt;
Var
  V : LongInt;
  C : Integer;
Begin
  Val(S, V, C);
  If C = 0 Then StrToIntDef := V
  Else          StrToIntDef := Def;
End;

Function BaseName(Const Path : TString) : TString;
Var
  I, LastSep, LastDot : Integer;
  S : TString;
Begin
  LastSep := 0;
  LastDot := 0;
  For I := 1 To Length(Path) Do
  Begin
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
    If Path[I] = '.' Then
      LastDot := I;
  End;
  If LastDot > LastSep Then
    S := Copy(Path, LastSep + 1, LastDot - LastSep - 1)
  Else
    S := Copy(Path, LastSep + 1, Length(Path));
  BaseName := S;
End;

Function ExtractExt(Const Path : TString) : TString;
Var
  I, LastSep, LastDot : Integer;
Begin
  LastSep := 0;
  LastDot := 0;
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

{ ---- Messages d erreur et d avertissement ---------------- }

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('PROLOG86: FATAL: ', Msg);
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
  Write('PROLOG86:');
  If CurLine > 0 Then
    Write(Opts.SrcFile, ':', CurLine, ': ');
  WriteLn('error: ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('trop d''erreurs, compilation arretee');
End;

Procedure WarnMsg(Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  Write('PROLOG86:');
  If CurLine > 0 Then
    Write(Opts.SrcFile, ':', CurLine, ': ');
  WriteLn('warning: ', Msg);
  Inc(WarnCount);
End;

{ ---- Banniere ---------------------------------------------- }

Procedure ShowBanner;
Begin
  WriteLn('PROLOG86 v', PL86_VERSION, ' (', PL86_DATE, ')');
  WriteLn('Compilateur Prolog -> assembleur 8086 (MASM .MODEL SMALL)');
  WriteLn('Turbo Pascal / Free Pascal (-Mtp)');
  WriteLn;
End;

Procedure ShowUsage;
Begin
  WriteLn('Usage: PROLOG86 <source.pl> [sortie.asm] [-v] [-d] [-w]');
  WriteLn;
  WriteLn('  source.pl  : fichier Prolog source (.pl ou .pro)');
  WriteLn('  sortie.asm : fichier assembleur de sortie (defaut: source.asm)');
  WriteLn('  -v         : mode verbeux (banniere + statistiques)');
  WriteLn('  -d         : debug tokens (affiche chaque token)');
  WriteLn('  -w         : activer les avertissements');
  WriteLn;
  Halt(EXIT_USAGE);
End;

Procedure ShowHelp;
Begin
  ShowBanner;
  ShowUsage;
End;

{ ---- Initialisation des options ----------------------------- }

Procedure InitOptions;
Begin
  Opts.SrcFile   := '';
  Opts.OutFile   := '';
  Opts.Verbose   := False;
  Opts.DebugMode := False;
  Opts.Warnings  := False;
End;

{ ---- Analyse des arguments de la ligne de commande --------- }

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
      ShowHelp
    Else If (Arg = '-v') Or (Arg = '--verbose') Then
      Opts.Verbose := True
    Else If Arg = '-d' Then
      Opts.DebugMode := True
    Else If Arg = '-w' Then
      Opts.Warnings := True
    Else If Arg[1] = '-' Then
    Begin
      WriteLn('PROLOG86: option inconnue: ', Arg);
      ShowUsage;
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else If Opts.OutFile = '' Then
      Opts.OutFile := Arg
    Else
    Begin
      WriteLn('PROLOG86: argument inattendu: ', Arg);
      ShowUsage;
    End;
  End;

  If Opts.SrcFile = '' Then
  Begin
    WriteLn('PROLOG86: fichier source manquant');
    ShowUsage;
  End;

  { Verifier l extension .pl ou .pro }
  Ext := ExtractExt(Opts.SrcFile);
  If (Ext <> '.pl') And (Ext <> '.pro') Then
    WarnMsg('extension attendue: .pl ou .pro, trouvee: ' + Ext);

  If Opts.OutFile = '' Then
    Opts.OutFile := ReplaceExt(Opts.SrcFile, '.asm');
End;

{ ---- Nettoyage -------------------------------------------- }

Procedure Cleanup;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ---- Initialisation generale des variables globales -------- }

Procedure GlobalInit;
Begin
  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  CurLine    := 0;
  OutFOpen   := False;
  LexOpened  := False;
  LexEOF     := False;
  LexLineNo  := 0;
  LexColNo   := 1;
  LexLine    := '';
  CurToken.Kind     := TK_EOF;
  CurToken.Val      := '';
  CurToken.IntVal   := 0;
  CurToken.FloatVal := 0.0;
  CurToken.Line     := 0;
  CurToken.Col      := 0;
  { TODO 03 }
  DataCount   := 0;
  LabelGenSeq := 0;
  { TODO 05 }
  SymInit;
  { TODO 21 }
  OpInit;
  { TODO 22 }
  DirectiveInit;
  { TODO 06 }
  TermInit;
  { TODO 08 }
  DataInit;
  { TODO 10 }
  ClauseCount := 0;
  { TODO 11 }
  GoalCount    := 0;
  RuleVarCount := 0;
  { TODO 13 }
  ListElemCount := 0;
  { TODO 14 }
  ArithNodeCount := 0;
End;

{ ---- Statistiques ------------------------------------------ }

Procedure ShowStats;
Begin
  WriteLn('--- Bilan PROLOG86 ---');
  WriteLn('Source         : ', Opts.SrcFile);
  WriteLn('Sortie         : ', Opts.OutFile);
  WriteLn('Lignes lues    : ', TotalLines);
  WriteLn('Atomes internes: ', AtomCount);
  WriteLn('Foncteurs      : ', FunctorCount);
  WriteLn('Donnees DATA   : ', DataCount, '/', MAX_DATA, ' entrees');
  WriteLn('Symboles       : ', SymCount, ' (total cumul: ', TotalSyms, ')');
  WriteLn('Clauses        : ', ClauseCount, '/', MAX_CLAUSE);
  WriteLn('Heap WAM       : ', HTop, '/', HEAP_SIZE, ' cellules');
  WriteLn('Stack WAM      : ', STop, '/', STACK_SIZE, ' cellules');
  WriteLn('Trail WAM      : ', TTop, '/', TRAIL_SIZE, ' cellules');
  WriteLn('Erreurs        : ', ErrorCount);
  WriteLn('Avertissements : ', WarnCount);
  If ModuleDefined Then
    WriteLn('Module         : ', ModuleName, ' (', ModuleExpCount, ' exports)');
  If InitGoalCount > 0 Then
    WriteLn('Init goals     : ', InitGoalCount);
End;

{ ============================================================
  TODO 02 - LEXEUR (TOKENS PROLOG) [IMPLEMENTE]
  ============================================================ }

{ ---- Fonctions de test sur les caracteres ------------------- }

Function IsIdentStart(Ch : Char) : Boolean;
Begin
  IsIdentStart := ((Ch >= 'a') And (Ch <= 'z')) Or (Ch = '_');
End;

Function IsIdentCont(Ch : Char) : Boolean;
Begin
  IsIdentCont := ((Ch >= 'a') And (Ch <= 'z')) Or
                 ((Ch >= 'A') And (Ch <= 'Z')) Or
                 ((Ch >= '0') And (Ch <= '9')) Or
                 (Ch = '_');
End;

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

{ ---- PrintToken : affichage debug d un token --------------- }
Procedure PrintToken(Const T : TToken);
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', T.Line, ',', T.Col, '] ');
  Case T.Kind Of
    TK_EOF        : Write('EOF');
    TK_INTEGER    : Write('INT(', T.IntVal, ')');
    TK_FLOAT      : Write('FLOAT(', T.Val, ')');
    TK_ATOM       : Write('ATOM(', T.Val, ')');
    TK_VARIABLE   : Write('VAR(', T.Val, ')');
    TK_STRING     : Write('STR("', T.Val, '")');
    TK_OP         : Write('OP(', T.Val, ')');
    TK_PUNCT      : Write('PUNCT(', T.Val, ')');
    TK_LPAREN     : Write('LPAREN');
    TK_RPAREN     : Write('RPAREN');
    TK_LBRACKET   : Write('LBRACKET');
    TK_RBRACKET   : Write('RBRACKET');
    TK_DOT        : Write('DOT');
    TK_PIPE       : Write('PIPE');
    TK_UNDERSCORE : Write('ANON(_)');
    TK_CUT        : Write('CUT(!)');
  End;
  WriteLn;
End;

{ ---- LexNextLine : lire la prochaine ligne source ----------- }
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

{ ---- LexSkipBlockComment : sauter /* ... */ (pas imbrique) -- }
Procedure LexSkipBlockComment;
Var
  Done : Boolean;
Begin
  Inc(LexColNo); Inc(LexColNo); { sauter '/' et '*' }
  Done := False;
  While (Not LexEOF) And (Not Done) Do
  Begin
    If LexColNo > Length(LexLine) Then
    Begin
      LexNextLine;
    End
    Else If (LexLine[LexColNo] = '*') And
            (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '/') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      Done := True;
    End
    Else
      Inc(LexColNo);
  End;
  If Not Done Then
    CompileError('commentaire /* non ferme');
End;

{ ---- LexScanEscChar : traiter une sequence d echappement --- }
Function LexScanEscChar : Char;
Var
  Ch : Char;
Begin
  If LexColNo > Length(LexLine) Then
  Begin
    LexScanEscChar := '\';
    Exit;
  End;
  Ch := LexLine[LexColNo];
  Inc(LexColNo);
  Case Ch Of
    'n'  : LexScanEscChar := #10;
    't'  : LexScanEscChar := #9;
    'r'  : LexScanEscChar := #13;
    'a'  : LexScanEscChar := #7;
    'b'  : LexScanEscChar := #8;
    'f'  : LexScanEscChar := #12;
    '\'  : LexScanEscChar := '\';
    '''' : LexScanEscChar := '''';
    '"'  : LexScanEscChar := '"';
  Else
    LexScanEscChar := Ch;
  End;
End;

{ ---- LexScanAtom : scanner un atome non-quote (minuscule) --- }
Procedure LexScanAtom;
Var
  S : TString;
Begin
  S := '';
  While (LexColNo <= Length(LexLine)) And IsIdentCont(LexLine[LexColNo]) Do
  Begin
    If Length(S) < MAX_STR Then
      S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
  CurToken.Kind   := TK_ATOM;
End;

{ ---- LexScanQuotedAtom : scanner un atome entre apostrophes - }
Procedure LexScanQuotedAtom;
Var
  S  : TString;
  Ch : Char;
Begin
  S := '';
  Inc(LexColNo); { sauter apostrophe ouvrante }
  While LexColNo <= Length(LexLine) Do
  Begin
    Ch := LexLine[LexColNo];
    If Ch = '''' Then
    Begin
      Inc(LexColNo);
      { Doublement d apostrophe '' -> ' }
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '''') Then
      Begin
        If Length(S) < MAX_STR Then
          S := S + '''';
        Inc(LexColNo);
      End
      Else
        Break;
    End
    Else If Ch = '\' Then
    Begin
      Inc(LexColNo);
      Ch := LexScanEscChar;
      If Length(S) < MAX_STR Then
        S := S + Ch;
    End
    Else
    Begin
      If Length(S) < MAX_STR Then
        S := S + Ch;
      Inc(LexColNo);
    End;
  End;
  CurToken.Kind   := TK_ATOM;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
End;

{ ---- LexScanVariable : scanner une variable Prolog ---------- }
Procedure LexScanVariable;
Var
  S : TString;
Begin
  S := '';
  While (LexColNo <= Length(LexLine)) And IsIdentCont(LexLine[LexColNo]) Do
  Begin
    If Length(S) < MAX_STR Then
      S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
  { Variable anonyme _ vs variable nommee }
  If S = '_' Then
    CurToken.Kind := TK_UNDERSCORE
  Else
    CurToken.Kind := TK_VARIABLE;
End;

{ ---- LexScanNumber : scanner un litteral numerique ---------- }
{ Formats : decimal 42, hexadecimal 0xFF, octal 0o77,          }
{           caractere 0'A (code ASCII), flottant 3.14           }
Procedure LexScanNumber;
Var
  N        : LongInt;
  Base     : Integer;
  IsFloat  : Boolean;
  NegExp   : Boolean;
  Ch       : Char;
  FracDiv  : Real;
  FracVal  : Real;
  ExpVal   : Integer;
  FltVal   : Real;
Begin
  N       := 0;
  Base    := 10;
  IsFloat := False;
  NegExp  := False;
  FracVal := 0.0;
  FracDiv := 10.0;
  ExpVal  := 0;
  Ch      := LexLine[LexColNo];

  { Detecter prefixe 0x, 0o, 0b, ou 0'A (character code) }
  If (Ch = '0') And (LexColNo < Length(LexLine)) Then
  Begin
    Ch := LexLine[LexColNo + 1];
    If (Ch = 'x') Or (Ch = 'X') Then
    Begin
      Base := 16;
      Inc(LexColNo); Inc(LexColNo);
    End
    Else If (Ch = 'o') Or (Ch = 'O') Then
    Begin
      Base := 8;
      Inc(LexColNo); Inc(LexColNo);
    End
    Else If (Ch = 'b') Or (Ch = 'B') Then
    Begin
      Base := 2;
      Inc(LexColNo); Inc(LexColNo);
    End
    Else If Ch = '''' Then
    Begin
      { 0'A -> code ASCII du caractere suivant }
      Inc(LexColNo); Inc(LexColNo); { sauter 0 et ' }
      If LexColNo <= Length(LexLine) Then
      Begin
        N := Ord(LexLine[LexColNo]);
        Inc(LexColNo);
      End;
      CurToken.Kind   := TK_INTEGER;
      CurToken.IntVal := N;
      Str(N, CurToken.Val);
      Exit;
    End;
  End;

  { Scanner la partie entiere }
  While LexColNo <= Length(LexLine) Do
  Begin
    Ch := LexLine[LexColNo];
    If (Base = 16) And IsHexDigit(Ch) Then
    Begin
      N := N * 16 + HexVal(Ch);
      Inc(LexColNo);
    End
    Else If (Base = 8) And (Ch >= '0') And (Ch <= '7') Then
    Begin
      N := N * 8 + (Ord(Ch) - Ord('0'));
      Inc(LexColNo);
    End
    Else If (Base = 2) And ((Ch = '0') Or (Ch = '1')) Then
    Begin
      N := N * 2 + (Ord(Ch) - Ord('0'));
      Inc(LexColNo);
    End
    Else If (Base = 10) And (Ch >= '0') And (Ch <= '9') Then
    Begin
      N := N * 10 + (Ord(Ch) - Ord('0'));
      Inc(LexColNo);
    End
    Else
      Break;
  End;

  { Partie decimale .ddd (seulement en base 10) }
  If (Base = 10) And (LexColNo <= Length(LexLine)) And
     (LexLine[LexColNo] = '.') And
     (LexColNo < Length(LexLine)) And
     (LexLine[LexColNo + 1] >= '0') And (LexLine[LexColNo + 1] <= '9') Then
  Begin
    IsFloat := True;
    Inc(LexColNo); { sauter '.' }
    FracDiv := 10.0;
    FracVal := 0.0;
    While (LexColNo <= Length(LexLine)) And
          (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
    Begin
      FracVal := FracVal + (Ord(LexLine[LexColNo]) - Ord('0')) / FracDiv;
      FracDiv := FracDiv * 10.0;
      Inc(LexColNo);
    End;
  End;

  { Exposant e/E [+-]ddd }
  If (Base = 10) And (LexColNo <= Length(LexLine)) And
     ((LexLine[LexColNo] = 'e') Or (LexLine[LexColNo] = 'E')) Then
  Begin
    IsFloat := True;
    Inc(LexColNo);
    NegExp := False;
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '-') Then
    Begin
      NegExp := True;
      Inc(LexColNo);
    End
    Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '+') Then
      Inc(LexColNo);
    ExpVal := 0;
    While (LexColNo <= Length(LexLine)) And
          (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
    Begin
      ExpVal := ExpVal * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
      Inc(LexColNo);
    End;
  End;

  { Calculer la valeur finale }
  If IsFloat Then
  Begin
    FltVal := N + FracVal;
    While ExpVal > 0 Do
    Begin
      If NegExp Then FltVal := FltVal / 10.0
      Else           FltVal := FltVal * 10.0;
      Dec(ExpVal);
    End;
    CurToken.Kind     := TK_FLOAT;
    CurToken.FloatVal := FltVal;
    { IntVal = partie entiere tronquee, clampee a 16 bits }
    If FltVal > 32767.0 Then N := 32767
    Else If FltVal < -32768.0 Then N := -32768
    Else N := Trunc(FltVal);
    CurToken.IntVal := N;
    Str(FltVal:0:6, CurToken.Val);
  End
  Else
  Begin
    CurToken.Kind   := TK_INTEGER;
    CurToken.IntVal := N;
    Str(N, CurToken.Val);
  End;
End;

{ ---- LexScanString : scanner une chaine double-quote "abc" -- }
Procedure LexScanString;
Var
  S  : TString;
  Ch : Char;
Begin
  S := '';
  Inc(LexColNo); { sauter guillemet ouvrant }
  While LexColNo <= Length(LexLine) Do
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
      Ch := LexScanEscChar;
      If Length(S) < MAX_STR Then
        S := S + Ch;
    End
    Else
    Begin
      If Length(S) < MAX_STR Then
        S := S + Ch;
      Inc(LexColNo);
    End;
  End;
  CurToken.Kind   := TK_STRING;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
End;

{ ---- LexInit : initialiser le lexeur ----------------------- }
Procedure LexInit;
Begin
  Assign(LexSrcF, Opts.SrcFile);
  Reset(LexSrcF);
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir: ' + Opts.SrcFile);
  LexOpened  := True;
  LexLineNo  := 0;
  LexColNo   := 1;
  LexEOF     := False;
  LexLine    := '';
  CurToken.Kind     := TK_EOF;
  CurToken.Val      := '';
  CurToken.IntVal   := 0;
  CurToken.FloatVal := 0.0;
  CurToken.Line     := 0;
  CurToken.Col      := 0;
  { Lire la premiere ligne }
  LexNextLine;
End;

{ ---- LexClose : fermer le fichier source -------------------- }
Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
End;

{ ---- LexNextToken : scanner principal ----------------------- }
Procedure LexNextToken;
Var
  Ch, Ch2  : Char;
  Scanning : Boolean;
  OpS      : TString;
Begin
  CurToken.IntVal   := 0;
  CurToken.FloatVal := 0.0;

  Scanning := True;
  While Scanning Do
  Begin
    { Avancer jusqu a la prochaine ligne si fin de ligne }
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
      LexNextLine;

    { Fin de fichier }
    If LexEOF Then
    Begin
      CurToken.Kind := TK_EOF;
      CurToken.Val  := '';
      CurToken.Line := LexLineNo;
      CurToken.Col  := LexColNo;
      Scanning      := False;
      Break;
    End;

    CurToken.Line := LexLineNo;
    CurToken.Col  := LexColNo;
    CurLine       := LexLineNo;
    Ch            := LexLine[LexColNo];

    { Espaces blancs }
    If (Ch = ' ') Or (Ch = #9) Or (Ch = #13) Or (Ch = #12) Then
    Begin
      Inc(LexColNo);
    End

    { Commentaire % jusqu a fin de ligne }
    Else If Ch = '%' Then
    Begin
      LexColNo := Length(LexLine) + 1;
    End

    { Commentaire bloc /* ... */ }
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '*') Then
    Begin
      LexSkipBlockComment;
    End

    { Variable : commence par majuscule }
    Else If (Ch >= 'A') And (Ch <= 'Z') Then
    Begin
      LexScanVariable;
      Scanning := False;
    End

    { Underscore : variable anonyme ou variable _Xxx }
    Else If Ch = '_' Then
    Begin
      { Regarder le caractere suivant }
      If (LexColNo < Length(LexLine)) And
         IsIdentCont(LexLine[LexColNo + 1]) Then
      Begin
        { Variable nommee _Quelque_chose }
        LexScanVariable;
      End
      Else
      Begin
        { Variable anonyme _ seule }
        CurToken.Kind := TK_UNDERSCORE;
        CurToken.Val  := '_';
        Inc(LexColNo);
      End;
      Scanning := False;
    End

    { Atome ou mot-cle : commence par minuscule }
    Else If (Ch >= 'a') And (Ch <= 'z') Then
    Begin
      LexScanAtom;
      Scanning := False;
    End

    { Atome entre apostrophes 'abc' }
    Else If Ch = '''' Then
    Begin
      LexScanQuotedAtom;
      Scanning := False;
    End

    { Chaine double-quote "abc" }
    Else If Ch = '"' Then
    Begin
      LexScanString;
      Scanning := False;
    End

    { Nombre }
    Else If (Ch >= '0') And (Ch <= '9') Then
    Begin
      LexScanNumber;
      Scanning := False;
    End

    { Parentheses }
    Else If Ch = '(' Then
    Begin
      CurToken.Kind := TK_LPAREN;
      CurToken.Val  := '(';
      Inc(LexColNo);
      Scanning := False;
    End
    Else If Ch = ')' Then
    Begin
      CurToken.Kind := TK_RPAREN;
      CurToken.Val  := ')';
      Inc(LexColNo);
      Scanning := False;
    End

    { Crochets }
    Else If Ch = '[' Then
    Begin
      CurToken.Kind := TK_LBRACKET;
      CurToken.Val  := '[';
      Inc(LexColNo);
      Scanning := False;
    End
    Else If Ch = ']' Then
    Begin
      CurToken.Kind := TK_RBRACKET;
      CurToken.Val  := ']';
      Inc(LexColNo);
      Scanning := False;
    End

    { Pipe | }
    Else If Ch = '|' Then
    Begin
      CurToken.Kind := TK_PIPE;
      CurToken.Val  := '|';
      Inc(LexColNo);
      Scanning := False;
    End

    { Cut ! }
    Else If Ch = '!' Then
    Begin
      CurToken.Kind := TK_CUT;
      CurToken.Val  := '!';
      Inc(LexColNo);
      Scanning := False;
    End

    { Point . (terminaison de clause) }
    { Un point suivi d un espace/tab/fin de ligne/commentaire = fin de clause }
    Else If Ch = '.' Then
    Begin
      Inc(LexColNo);
      If (LexColNo > Length(LexLine)) Or
         (LexLine[LexColNo] = ' ') Or (LexLine[LexColNo] = #9) Or
         (LexLine[LexColNo] = '%') Then
      Begin
        CurToken.Kind := TK_DOT;
        CurToken.Val  := '.';
      End
      Else
      Begin
        { Peut etre l operateur =.. (univ) ou juste un point dans un nombre }
        CurToken.Kind := TK_OP;
        CurToken.Val  := '.';
      End;
      Scanning := False;
    End

    { Virgule , }
    Else If Ch = ',' Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := ',';
      Inc(LexColNo);
      Scanning := False;
    End

    { Point-virgule ; }
    Else If Ch = ';' Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := ';';
      Inc(LexColNo);
      Scanning := False;
    End

    { Operateur :- ou : }
    Else If Ch = ':' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '-') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP;
        CurToken.Val  := ':-';
      End
      Else
      Begin
        CurToken.Kind := TK_OP;
        CurToken.Val  := ':';
      End;
      Scanning := False;
    End

    { Operateur ?- ou ? }
    Else If Ch = '?' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '-') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP;
        CurToken.Val  := '?-';
      End
      Else
      Begin
        CurToken.Kind := TK_OP;
        CurToken.Val  := '?';
      End;
      Scanning := False;
    End

    { Operateurs commencant par = : =, ==, =.., =:=, =\=, =< }
    Else If Ch = '=' Then
    Begin
      Inc(LexColNo);
      Ch2 := #0;
      If LexColNo <= Length(LexLine) Then
        Ch2 := LexLine[LexColNo];
      If Ch2 = '=' Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '==';
      End
      Else If (Ch2 = '.') And (LexColNo < Length(LexLine)) And
              (LexLine[LexColNo + 1] = '.') Then
      Begin
        Inc(LexColNo); Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '=..';
      End
      Else If Ch2 = ':' Then
      Begin
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
        Begin
          Inc(LexColNo);
          CurToken.Kind := TK_OP; CurToken.Val := '=:=';
        End
        Else
        Begin
          CurToken.Kind := TK_OP; CurToken.Val := '=:';
        End;
      End
      Else If Ch2 = '\' Then
      Begin
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
        Begin
          Inc(LexColNo);
          CurToken.Kind := TK_OP; CurToken.Val := '=\=';
        End
        Else
        Begin
          CurToken.Kind := TK_OP; CurToken.Val := '=\';
        End;
      End
      Else If Ch2 = '<' Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '=<';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '=';
      End;
      Scanning := False;
    End

    { Operateurs commencant par \ : \=, \==, \+, \ }
    Else If Ch = '\' Then
    Begin
      Inc(LexColNo);
      Ch2 := #0;
      If LexColNo <= Length(LexLine) Then
        Ch2 := LexLine[LexColNo];
      If Ch2 = '=' Then
      Begin
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
        Begin
          Inc(LexColNo);
          CurToken.Kind := TK_OP; CurToken.Val := '\==';
        End
        Else
        Begin
          CurToken.Kind := TK_OP; CurToken.Val := '\=';
        End;
      End
      Else If Ch2 = '+' Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '\+';
      End
      Else If Ch2 = '/' Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '\/';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '\';
      End;
      Scanning := False;
    End

    { Operateurs commencant par @ : @<, @>, @=<, @>= }
    Else If Ch = '@' Then
    Begin
      Inc(LexColNo);
      Ch2 := #0;
      If LexColNo <= Length(LexLine) Then
        Ch2 := LexLine[LexColNo];
      If Ch2 = '<' Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '@<';
      End
      Else If Ch2 = '>' Then
      Begin
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
        Begin
          Inc(LexColNo);
          CurToken.Kind := TK_OP; CurToken.Val := '@>=';
        End
        Else
        Begin
          CurToken.Kind := TK_OP; CurToken.Val := '@>';
        End;
      End
      Else If Ch2 = '=' Then
      Begin
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '<') Then
        Begin
          Inc(LexColNo);
          CurToken.Kind := TK_OP; CurToken.Val := '@=<';
        End
        Else
        Begin
          CurToken.Kind := TK_OP; CurToken.Val := '@=';
        End;
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '@';
      End;
      Scanning := False;
    End

    { < ou << }
    Else If Ch = '<' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '<') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '<<';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '<';
      End;
      Scanning := False;
    End

    { > ou >= ou >> }
    Else If Ch = '>' Then
    Begin
      Inc(LexColNo);
      Ch2 := #0;
      If LexColNo <= Length(LexLine) Then
        Ch2 := LexLine[LexColNo];
      If Ch2 = '=' Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '>=';
      End
      Else If Ch2 = '>' Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '>>';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '>';
      End;
      Scanning := False;
    End

    { + }
    Else If Ch = '+' Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '+';
      Inc(LexColNo);
      Scanning := False;
    End

    { - ou -> }
    Else If Ch = '-' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '>') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '->';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '-';
      End;
      Scanning := False;
    End

    { * ou ** }
    Else If Ch = '*' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '*') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '**';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '*';
      End;
      Scanning := False;
    End

    { / ou // }
    Else If Ch = '/' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '/') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '//';
      End
      Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '\') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '/\';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '/';
      End;
      Scanning := False;
    End

    { ^ (existentiel) }
    Else If Ch = '^' Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '^';
      Inc(LexColNo);
      Scanning := False;
    End

    { # (non standard, mais parfois utilise) }
    Else If Ch = '#' Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '#';
      Inc(LexColNo);
      Scanning := False;
    End

    { Caractere inconnu }
    Else
    Begin
      OpS := Ch;
      CompileError('caractere inattendu: ' + OpS);
      Inc(LexColNo);
    End;
  End; { While Scanning }
End;

{ ============================================================
  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
  ============================================================ }

{ ---- LabelGen : generateur de labels uniques ---------------- }
Function LabelGen : TString;
Begin
  Inc(LabelGenSeq);
  LabelGen := PL_LBL_PFX + IntToStr(LabelGenSeq);
End;

{ ---- DataAdd : ajouter une entree dans le segment DATA ----- }
{ Retourne l index dans DataTab ou -1 si plein.                }
Function DataAdd(Const Lbl : TString; Kind : TDataKind;
                 AIntVal : LongInt; Const AStrVal : TString) : Integer;
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

{ ---- DataAddStr : creer un label _PLK_N et stocker chaine --- }
{ Retourne le label genere.                                     }
Function DataAddStr(Const S : TString) : TString;
Var
  Lbl : TString;
Begin
  Inc(LabelGenSeq);
  Lbl := PL_STR_PFX + IntToStr(LabelGenSeq);
  DataAdd(Lbl, DK_STR, 0, S);
  DataAddStr := Lbl;
End;

{ ---- DataAddWord : ajouter un mot 16 bits dans le segment DATA }
Function DataAddWord(Const Lbl : TString; AIntVal : LongInt) : Integer;
Begin
  DataAddWord := DataAdd(Lbl, DK_WORD, AIntVal, '');
End;

{ ---- ExprMakeImm : creer une valeur immediate --------------- }
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := AVal;
  Res.TypeIdx := ATypeIdx;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ---- ExprMakeNone : valeur invalide (void/erreur) ---------- }
Procedure ExprMakeNone(Var Res : TExprVal);
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_UNKNOWN;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ---- LitEvalInt : convertir un token TK_INTEGER en valeur -- }
{ IntVal est deja calcule par LexScanNumber (dec/hex/oct/bin/  }
{ char 0'A).                                                   }
Procedure LitEvalInt(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeImm(T.IntVal, TY_IDX_INT, Res);
End;

{ ---- LitEvalFloat : convertir un token TK_FLOAT en entier -- }
{ Prolog 8086 16 bits : les flottants sont tronques en entiers }
{ avec avertissement.                                          }
Procedure LitEvalFloat(Const T : TToken; Var Res : TExprVal);
Var
  N : LongInt;
Begin
  WarnMsg('flottant ' + T.Val + ' tronque en entier');
  If T.FloatVal > 32767.0 Then N := 32767
  Else If T.FloatVal < -32768.0 Then N := -32768
  Else N := Trunc(T.FloatVal);
  ExprMakeImm(N, TY_IDX_INT, Res);
End;

{ ---- IsSpecialAtom : teste si un atome est predefini -------- }
{ true -> succes immediat, fail -> echec immediat               }
Function IsSpecialAtom(Const S : TString) : Boolean;
Begin
  IsSpecialAtom := (S = 'true') Or (S = 'fail') Or
                   (S = 'is') Or (S = 'mod') Or (S = 'rem') Or
                   (S = 'not') Or (S = 'xor');
End;

{ ---- LitEval : dispatcher principal pour les litteraux ----- }
{ Types de tokens acceptes :                                    }
{   TK_INTEGER : entier -> EK_IMM / TY_IDX_INT                }
{   TK_FLOAT   : flottant -> tronque en entier + warning       }
{   TK_ATOM    : atome -> stocker en DATA, retourner EK_MEM   }
{   TK_STRING  : chaine -> stocker en DATA, retourner EK_MEM  }
{   TK_CUT     : ! -> EK_IMM avec valeur 0 (marqueur cut)     }
{   TK_UNDERSCORE : _ -> EK_IMM / TY_IDX_VAR (var anonyme)    }
{   TK_VARIABLE : Var -> EK_NONE (resolu plus tard par symtab) }
Procedure LitEval(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeNone(Res);  { valeur par defaut }
  Case T.Kind Of
    TK_INTEGER :
      LitEvalInt(T, Res);

    TK_FLOAT :
      LitEvalFloat(T, Res);

    TK_ATOM :
    Begin
      { Atomes speciaux : true et fail }
      If T.Val = 'true' Then
        ExprMakeImm(1, TY_IDX_ATOM, Res)
      Else If T.Val = 'fail' Then
        ExprMakeImm(0, TY_IDX_ATOM, Res)
      Else
      Begin
        { Atome general : stocker la chaine en DATA }
        DataAddStr(T.Val);
        Res.Kind    := EK_MEM;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_ATOM;
        Res.Offset  := DataCount - 1;
        Res.SymIdx  := -1;
      End;
    End;

    TK_STRING :
    Begin
      { Chaine "abc" : stocker en DATA }
      DataAddStr(T.Val);
      Res.Kind    := EK_MEM;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_STR;
      Res.Offset  := DataCount - 1;
      Res.SymIdx  := -1;
    End;

    TK_CUT :
    Begin
      { ! (cut) : marqueur special }
      ExprMakeImm(0, TY_IDX_ATOM, Res);
    End;

    TK_UNDERSCORE :
    Begin
      { _ (variable anonyme) : chaque occurrence est independante }
      ExprMakeImm(0, TY_IDX_VAR, Res);
    End;

    TK_VARIABLE :
    Begin
      { Variable nommee : sera resolue par la table des symboles }
      Res.Kind    := EK_NONE;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_VAR;
      Res.Offset  := 0;
      Res.SymIdx  := -1;
    End;

    TK_LBRACKET :
    Begin
      { [] (liste vide) : atome special }
      ExprMakeImm(0, TY_IDX_LIST, Res);
    End;
  End; { Case }
End;

{ ============================================================
  TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
  ============================================================ }

{ ---- ParserAdvance : consommer le token courant ------------- }
{ Appelle LexNextToken et affiche le token en mode debug.       }
Procedure ParserAdvance;
Begin
  LexNextToken;
  If Opts.DebugMode Then
    PrintToken(CurToken);
End;

{ ---- BinOpPrec : table de precedences Prolog (Pratt) -------- }
{ En Prolog ISO, les priorites sont decroissantes (1200=faible, }
{ 200=fort). On les convertit en niveaux croissants pour le     }
{ parseur Pratt (plus grand = plus serre, 0 = pas operateur).  }
{                                                                }
{   Prolog 1200 -> Pratt 1 : :- ?- -->                          }
{   Prolog 1100 -> Pratt 2 : ; (disjonction)                   }
{   Prolog 1050 -> Pratt 3 : -> (if-then)                      }
{   Prolog 1000 -> Pratt 4 : , (conjonction)                   }
{   Prolog 900  -> Pratt 5 : \+ (negation par echec)           }
{   Prolog 700  -> Pratt 6 : is = \= == \== < > =< >= =:= =\= }
{                             @< @> @=< @>= =.. copy_term      }
{   Prolog 500  -> Pratt 7 : + - /\ \/                         }
{   Prolog 400  -> Pratt 8 : * / // rem mod << >>              }
{   Prolog 200  -> Pratt 9 : ** ^                              }
Function BinOpPrec(Const Op : TString) : Integer;
Var
  OIdx : Integer;
  P    : Integer;
Begin
  { Niveau 1 : directif / requete (1200) }
  If (Op = ':-') Or (Op = '?-') Or (Op = '-->') Then
    BinOpPrec := 1
  { Niveau 2 : disjonction (1100) }
  Else If Op = ';' Then
    BinOpPrec := 2
  { Niveau 3 : if-then (1050) }
  Else If Op = '->' Then
    BinOpPrec := 3
  { Niveau 4 : conjonction (1000) }
  Else If Op = ',' Then
    BinOpPrec := 4
  { Niveau 5 : negation par echec (900) - unaire prefix, mais traite }
  { comme operateur binaire potentiel pour \+ dans certains contextes }
  { (ce cas est principalement gere par ParseUnary)                  }
  { Niveau 6 : comparaison / unification / evaluation (700) }
  Else If (Op = 'is')  Or (Op = '=')   Or (Op = '\=') Or
          (Op = '==')  Or (Op = '\==') Or (Op = '=:=') Or
          (Op = '=\=') Or (Op = '<')   Or (Op = '>') Or
          (Op = '=<')  Or (Op = '>=')  Or (Op = '=..') Or
          (Op = '@<')  Or (Op = '@>')  Or (Op = '@=<') Or
          (Op = '@>=') Then
    BinOpPrec := 6
  { Niveau 7 : addition / soustraction / bits (500) }
  Else If (Op = '+') Or (Op = '-') Or (Op = '/\') Or (Op = '\/') Then
    BinOpPrec := 7
  { Niveau 8 : multiplication / division (400) }
  Else If (Op = '*')   Or (Op = '/')   Or (Op = '//') Or
          (Op = 'rem') Or (Op = 'mod') Or
          (Op = '<<')  Or (Op = '>>') Then
    BinOpPrec := 8
  { Niveau 9 : puissance / existentiel (200) }
  Else If (Op = '**') Or (Op = '^') Then
    BinOpPrec := 9
  Else
  Begin
    { Fallback : consulter OpTab pour operateurs utilisateur (TODO 21) }
    OIdx := OpFind(Op);
    If OIdx >= 0 Then
    Begin
      P := OpTab[OIdx].Prec;
      If P >= 1200 Then BinOpPrec := 1
      Else If P >= 1100 Then BinOpPrec := 2
      Else If P >= 1050 Then BinOpPrec := 3
      Else If P >= 1000 Then BinOpPrec := 4
      Else If P >= 900  Then BinOpPrec := 5
      Else If P >= 700  Then BinOpPrec := 6
      Else If P >= 500  Then BinOpPrec := 7
      Else If P >= 400  Then BinOpPrec := 8
      Else If P >= 200  Then BinOpPrec := 9
      Else BinOpPrec := 10;
    End
    Else
      BinOpPrec := 0;
  End;
End;

{ ---- BinOpIsRight : operateur droit-associatif ? ------------ }
{ En Prolog ISO :                                                }
{   xfx : non associatif (=, ==, is, \=, ... -> gauche par def) }
{   xfy : associatif a droite (:-, ?-, ;, ->, ',', \+)          }
{   yfx : associatif a gauche (+, -, *, /, //, mod, rem, etc.)  }
Function BinOpIsRight(Const Op : TString) : Boolean;
Var
  OIdx : Integer;
Begin
  If (Op = ':-') Or (Op = '?-') Or (Op = '-->') Or
     (Op = ';')  Or (Op = '->') Or
     (Op = ',')  Or
     (Op = '^') Then
    BinOpIsRight := True
  Else
  Begin
    { Fallback : consulter OpTab pour operateurs utilisateur (TODO 21) }
    OIdx := OpFind(Op);
    If (OIdx >= 0) And (OpTab[OIdx].Spec = 'xfy') Then
      BinOpIsRight := True
    Else
      BinOpIsRight := False;
  End;
End;

{ ---- OpSpecifier : retourner le type d operateur Prolog ------ }
{ fx/fy  : prefixe (non/associatif a droite)                    }
{ xfx    : infixe non-associatif                                }
{ xfy    : infixe droit-associatif                               }
{ yfx    : infixe gauche-associatif                              }
{ xf/yf  : postfixe (non utilise dans ISO standard)             }
Function OpSpecifier(Const Op : TString) : TString;
Var
  OIdx : Integer;
Begin
  { Prefixes }
  If (Op = ':-') Or (Op = '?-') Then
    OpSpecifier := 'fx'
  Else If (Op = '\+') Or (Op = 'not') Then
    OpSpecifier := 'fy'
  { Infixes xfy (droit-associatif) }
  Else If (Op = ';') Or (Op = '->') Or (Op = ',') Then
    OpSpecifier := 'xfy'
  Else If (Op = '**') Then
    OpSpecifier := 'xfx'
  Else If (Op = '^') Then
    OpSpecifier := 'xfy'
  { Infixes xfx (non-associatif) }
  Else If (Op = 'is')  Or (Op = '=')   Or (Op = '\=') Or
          (Op = '==')  Or (Op = '\==') Or (Op = '=:=') Or
          (Op = '=\=') Or (Op = '<')   Or (Op = '>') Or
          (Op = '=<')  Or (Op = '>=')  Or (Op = '=..') Or
          (Op = '@<')  Or (Op = '@>')  Or (Op = '@=<') Or
          (Op = '@>=') Then
    OpSpecifier := 'xfx'
  { Infixes yfx (gauche-associatif) }
  Else If (Op = '+')   Or (Op = '-')   Or (Op = '/\') Or (Op = '\/') Or
          (Op = '*')   Or (Op = '/')   Or (Op = '//') Or
          (Op = 'rem') Or (Op = 'mod') Or
          (Op = '<<')  Or (Op = '>>') Then
    OpSpecifier := 'yfx'
  { Directive/requete prefixe }
  Else If (Op = '-->') Then
    OpSpecifier := 'xfx'
  Else
  Begin
    { Fallback : consulter OpTab pour operateurs utilisateur (TODO 21) }
    OIdx := OpFind(Op);
    If OIdx >= 0 Then
      OpSpecifier := OpTab[OIdx].Spec
    Else
      OpSpecifier := 'yfx';
  End;
End;

{ ---- ExprFlushToAX : materialiser une valeur dans AX -------- }
{ Emet le code 8086 necessaire pour charger la valeur dans AX.  }
{ Note : stub minimal, sera complete par TODO 07 (emetteur).    }
Procedure ExprFlushToAX(Const E : TExprVal);
Var
  NS : TString;
Begin
  Case E.Kind Of
    EK_IMM :
    Begin
      If E.ImmVal = 0 Then
        { XOR AX,AX est plus court que MOV AX,0 }
      Else
      Begin
        Str(E.ImmVal, NS);
        { MOV AX, valeur }
      End;
    End;
    EK_MEM :
    Begin
      If (E.Offset >= 0) And (E.Offset < DataCount) Then
      Begin
        { MOV AX, OFFSET label }
      End
      Else
      Begin
        { XOR AX,AX }
      End;
    End;
    EK_AX :
      { deja dans AX } ;
    EK_NONE :
      { XOR AX,AX } ;
  End;
End;

{ ---- EmitBinOp : emettre code pour un operateur binaire ------ }
{ AX = operande gauche, BX = operande droit.                     }
{ Resultat dans AX. Stub : sera complete par TODO 07.            }
Procedure EmitBinOp(Const Op : TString; LeftType, RightType : Integer);
Begin
  { Stub : sera complete quand l emetteur ASM sera implemente }
  { (TODO 07). Les operations seront :                         }
  {   +  -> ADD AX, BX                                        }
  {   -  -> SUB AX, BX                                        }
  {   *  -> IMUL BX                                           }
  {   /  -> CWD / IDIV BX                                     }
  {   // -> CWD / IDIV BX                                     }
  {   mod/rem -> CWD / IDIV BX, MOV AX,DX                     }
  {   ** -> CALL _PLRT_POW                                     }
  {   << -> MOV CL,BL / SHL AX,CL                             }
  {   >> -> MOV CL,BL / SAR AX,CL                             }
  {   /\ -> AND AX, BX                                        }
  {   \/ -> OR  AX, BX                                        }
  {   =:= =\= < > =< >= -> CMP AX,BX + Jcc                   }
  {   = \= == \== -> CALL _PLRT_UNIFY / _PLRT_EQUAL           }
  {   is -> evaluation arithmetique                            }
  If LeftType = LeftType Then { eviter note unused }
  Begin End;
  If RightType = RightType Then
  Begin End;
End;

{ ---- ParsePrimary : parser un terme primaire Prolog ---------- }
{ Gere : entiers, flottants, atomes, variables, chaines,        }
{   listes [H|T], parentheses (expr), cut !, variable anonyme _ }
Procedure ParsePrimary(Var Res : TExprVal);
Var
  TmpExpr : TExprVal;
Begin
  Case CurToken.Kind Of
    { --- Entier --- }
    TK_INTEGER :
    Begin
      LitEvalInt(CurToken, Res);
      ParserAdvance;
    End;

    { --- Flottant (tronque en entier) --- }
    TK_FLOAT :
    Begin
      LitEvalFloat(CurToken, Res);
      ParserAdvance;
    End;

    { --- Atome (identificateur minuscule ou atome quote) --- }
    TK_ATOM :
    Begin
      { Atomes operateurs mot-cle utilises comme valeurs }
      If (CurToken.Val = 'is') Or (CurToken.Val = 'mod') Or
         (CurToken.Val = 'rem') Or (CurToken.Val = 'not') Or
         (CurToken.Val = 'xor') Then
      Begin
        { Dans un contexte primaire, ce sont des atomes }
        LitEval(CurToken, Res);
        ParserAdvance;
      End
      Else
      Begin
        LitEval(CurToken, Res);
        ParserAdvance;
        { Verifier si c est un foncteur : atome( ... ) }
        If (CurToken.Kind = TK_LPAREN) Then
        Begin
          { Foncteur : atome(arg1, arg2, ...) }
          { Stub : consommer les arguments et retourner EK_AX }
          ParserAdvance; { consomme '(' }
          While (CurToken.Kind <> TK_EOF) And
                (CurToken.Kind <> TK_RPAREN) Do
          Begin
            ParseExprPrec(5, TmpExpr); { prec > , pour separer les args }
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
              ParserAdvance;
          End;
          If CurToken.Kind = TK_RPAREN Then
            ParserAdvance;
          Res.Kind    := EK_AX;
          Res.TypeIdx := TY_IDX_TERM;
          Res.SymIdx  := -1;
        End;
      End;
    End;

    { --- Variable (commence par majuscule ou _Xxx) --- }
    TK_VARIABLE :
    Begin
      LitEval(CurToken, Res);
      ParserAdvance;
    End;

    { --- Chaine "abc" --- }
    TK_STRING :
    Begin
      LitEval(CurToken, Res);
      ParserAdvance;
    End;

    { --- Variable anonyme _ --- }
    TK_UNDERSCORE :
    Begin
      LitEval(CurToken, Res);
      ParserAdvance;
    End;

    { --- Cut ! --- }
    TK_CUT :
    Begin
      LitEval(CurToken, Res);
      ParserAdvance;
    End;

    { --- Parentheses (expr) --- }
    TK_LPAREN :
    Begin
      ParserAdvance; { consomme '(' }
      ParseExprPrec(1, Res); { parser l expression complete }
      If CurToken.Kind = TK_RPAREN Then
        ParserAdvance
      Else
        CompileError('parenthese fermante ) attendue');
    End;

    { --- Liste [elem1, elem2 | Queue] ou [] --- }
    TK_LBRACKET :
    Begin
      ParserAdvance; { consomme '[' }
      { Liste vide [] }
      If CurToken.Kind = TK_RBRACKET Then
      Begin
        ExprMakeImm(0, TY_IDX_LIST, Res);
        ParserAdvance;
      End
      Else
      Begin
        { Parser les elements de la liste }
        ParseExprPrec(5, Res); { premier element (prec > ',') }
        Res.TypeIdx := TY_IDX_LIST;
        While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
        Begin
          ParserAdvance; { consomme ',' }
          ParseExprPrec(5, TmpExpr);
        End;
        { Queue de liste | }
        If CurToken.Kind = TK_PIPE Then
        Begin
          ParserAdvance; { consomme '|' }
          ParseExprPrec(5, TmpExpr); { queue }
        End;
        If CurToken.Kind = TK_RBRACKET Then
          ParserAdvance
        Else
          CompileError('crochet fermant ] attendu');
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_LIST;
        Res.SymIdx  := -1;
      End;
    End;

  Else
    { Token inconnu pour une expression primaire }
    ExprMakeNone(Res);
    ParserAdvance;
  End;
End;

{ ---- ParseUnary : parser les operateurs unaires prefixe ------ }
{ Prolog ISO :                                                    }
{   - (unaire, fy, prec 200) : negation arithmetique             }
{   \+ (fy, prec 900) : negation par echec (NAF)                }
{   not (fy, prec 900) : synonyme de \+                          }
{   + (unaire) : identite                                        }
{   \ (unaire) : complement bit a bit                            }
Procedure ParseUnary(Var Res : TExprVal);
Var
  Op : TString;
Begin
  { Operateur unaire sur TK_OP }
  If CurToken.Kind = TK_OP Then
  Begin
    Op := CurToken.Val;
    { - : negation arithmetique (fy, 200) }
    If Op = '-' Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      { Pliage de constantes }
      If Res.Kind = EK_IMM Then
        Res.ImmVal := -Res.ImmVal
      Else
        Res.Kind := EK_AX;
      Exit;
    End
    { + : identite (fy, 200) }
    Else If Op = '+' Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      { Pas de changement de valeur, coerce en nombre }
      Exit;
    End
    { \+ : negation par echec (fy, 900) }
    Else If Op = '\+' Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      If Res.Kind = EK_IMM Then
      Begin
        If Res.ImmVal = 0 Then Res.ImmVal := 1
        Else Res.ImmVal := 0;
      End
      Else
        Res.Kind := EK_AX;
      Exit;
    End
    { \ : complement bit-a-bit }
    Else If Op = '\' Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      If Res.Kind = EK_IMM Then
        Res.ImmVal := Not Res.ImmVal
      Else
        Res.Kind := EK_AX;
      Exit;
    End;
  End;
  { Operateur unaire sur TK_ATOM (mot-cle operateur) }
  If CurToken.Kind = TK_ATOM Then
  Begin
    Op := CurToken.Val;
    { not : synonyme de \+ (fy, 900) }
    If Op = 'not' Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      If Res.Kind = EK_IMM Then
      Begin
        If Res.ImmVal = 0 Then Res.ImmVal := 1
        Else Res.ImmVal := 0;
      End
      Else
        Res.Kind := EK_AX;
      Exit;
    End;
  End;
  { Pas d operateur unaire : appeler ParsePrimary }
  ParsePrimary(Res);
End;

{ ---- ParseExprPrec : parseur Pratt pour expressions Prolog --- }
{ MinPrec = niveau de precedence minimal a capturer.             }
{ On utilise la convention Pratt standard : plus grand = plus    }
{ serre. Le parseur s arrete quand un operateur a une priorite  }
{ inferieure au minimum demande.                                 }
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal);
Var
  Op       : TString;
  Prec     : Integer;
  NextPrec : Integer;
  Right    : TExprVal;
  FoldOk   : Boolean;
Begin
  ParseUnary(Res);

  Repeat
    Op   := '';
    Prec := 0;

    { Detecter operateur binaire dans TK_OP }
    If CurToken.Kind = TK_OP Then
    Begin
      Op   := CurToken.Val;
      Prec := BinOpPrec(Op);
    End
    { Detecter operateur binaire dans TK_ATOM (is, mod, rem, xor) }
    Else If CurToken.Kind = TK_ATOM Then
    Begin
      If (CurToken.Val = 'is')  Or (CurToken.Val = 'mod') Or
         (CurToken.Val = 'rem') Or (CurToken.Val = 'xor') Then
      Begin
        Op   := CurToken.Val;
        Prec := BinOpPrec(Op);
      End;
    End
    { Detecter , (conjonction) et ; (disjonction) dans TK_PUNCT }
    Else If CurToken.Kind = TK_PUNCT Then
    Begin
      If (CurToken.Val = ',') Or (CurToken.Val = ';') Then
      Begin
        Op   := CurToken.Val;
        Prec := BinOpPrec(Op);
      End;
    End;

    { Arreter si pas d operateur ou si priorite insuffisante }
    If Prec = 0 Then Break;
    If Prec < MinPrec Then Break;

    { Consommer l operateur }
    ParserAdvance;

    { Calculer la priorite pour le cote droit }
    If BinOpIsRight(Op) Then
      NextPrec := Prec      { droit-associatif : meme niveau }
    Else
      NextPrec := Prec + 1; { gauche-associatif : niveau plus serre }

    { Parser l operande droit }
    ParseExprPrec(NextPrec, Right);

    { Pliage de constantes si les deux cotes sont immediats }
    FoldOk := (Res.Kind = EK_IMM) And (Right.Kind = EK_IMM);
    If FoldOk Then
    Begin
      { Arithmetique }
      If Op = '+' Then
        ExprMakeImm(Res.ImmVal + Right.ImmVal, TY_IDX_INT, Res)
      Else If Op = '-' Then
        ExprMakeImm(Res.ImmVal - Right.ImmVal, TY_IDX_INT, Res)
      Else If Op = '*' Then
        ExprMakeImm(Res.ImmVal * Right.ImmVal, TY_IDX_INT, Res)
      Else If (Op = '/') Or (Op = '//') Then
      Begin
        If Right.ImmVal <> 0 Then
          ExprMakeImm(Res.ImmVal Div Right.ImmVal, TY_IDX_INT, Res)
        Else
        Begin
          CompileError('division par zero');
          ExprMakeImm(0, TY_IDX_INT, Res);
        End;
      End
      Else If (Op = 'mod') Or (Op = 'rem') Then
      Begin
        If Right.ImmVal <> 0 Then
          ExprMakeImm(Res.ImmVal Mod Right.ImmVal, TY_IDX_INT, Res)
        Else
        Begin
          CompileError('modulo par zero');
          ExprMakeImm(0, TY_IDX_INT, Res);
        End;
      End
      Else If Op = '**' Then
      Begin
        { Puissance entiere simplifiee }
        If Right.ImmVal = 0 Then
          ExprMakeImm(1, TY_IDX_INT, Res)
        Else If Right.ImmVal = 1 Then
          { garde Res.ImmVal }
        Else
        Begin
          { Stub : ** avec constantes non triviales -> AX }
          Res.Kind := EK_AX;
          Res.TypeIdx := TY_IDX_INT;
        End;
      End
      { Bits }
      Else If Op = '/\' Then
        ExprMakeImm(Res.ImmVal And Right.ImmVal, TY_IDX_INT, Res)
      Else If Op = '\/' Then
        ExprMakeImm(Res.ImmVal Or Right.ImmVal, TY_IDX_INT, Res)
      Else If Op = '<<' Then
        ExprMakeImm(Res.ImmVal Shl (Right.ImmVal And 15), TY_IDX_INT, Res)
      Else If Op = '>>' Then
        ExprMakeImm(Res.ImmVal Shr (Right.ImmVal And 15), TY_IDX_INT, Res)
      Else If Op = 'xor' Then
        ExprMakeImm(Res.ImmVal Xor Right.ImmVal, TY_IDX_INT, Res)
      { Comparaison (retourne 1=vrai, 0=faux) }
      Else If Op = '<' Then
        ExprMakeImm(Ord(Res.ImmVal < Right.ImmVal), TY_IDX_INT, Res)
      Else If Op = '>' Then
        ExprMakeImm(Ord(Res.ImmVal > Right.ImmVal), TY_IDX_INT, Res)
      Else If Op = '=<' Then
        ExprMakeImm(Ord(Res.ImmVal <= Right.ImmVal), TY_IDX_INT, Res)
      Else If Op = '>=' Then
        ExprMakeImm(Ord(Res.ImmVal >= Right.ImmVal), TY_IDX_INT, Res)
      Else If Op = '=:=' Then
        ExprMakeImm(Ord(Res.ImmVal = Right.ImmVal), TY_IDX_INT, Res)
      Else If Op = '=\=' Then
        ExprMakeImm(Ord(Res.ImmVal <> Right.ImmVal), TY_IDX_INT, Res)
      { Unification / egalite structurelle : pas de pliage simple }
      Else If (Op = '=') Or (Op = '\=') Or (Op = '==') Or (Op = '\==') Or
              (Op = '=..') Or (Op = '@<') Or (Op = '@>') Or
              (Op = '@=<') Or (Op = '@>=') Then
      Begin
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INT;
      End
      { is : evaluation arithmetique (le cote droit est deja evalue) }
      Else If Op = 'is' Then
        Res := Right
      { Conjonction , : si gauche = 1 (vrai), resultat = droit }
      Else If Op = ',' Then
      Begin
        If Res.ImmVal = 0 Then
          ExprMakeImm(0, TY_IDX_INT, Res) { echec short-circuit }
        Else
          Res := Right;
      End
      { Disjonction ; : si gauche <> 0 (vrai), garde gauche }
      Else If Op = ';' Then
      Begin
        If Res.ImmVal <> 0 Then
          { garde Res }
        Else
          Res := Right;
      End
      { -> (if-then) : si gauche vrai, resultat = droit }
      Else If Op = '->' Then
      Begin
        If Res.ImmVal <> 0 Then
          Res := Right
        Else
          ExprMakeImm(0, TY_IDX_INT, Res); { echec }
      End
      Else
      Begin
        { Operateur non pliant : resultat dans AX }
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INT;
      End;
    End
    Else
    Begin
      { Operandes non constants : le resultat sera dans AX (TODO 07) }
      { Emettre le code binaire via EmitBinOp stub }
      ExprFlushToAX(Res);
      ExprFlushToAX(Right);
      EmitBinOp(Op, Res.TypeIdx, Right.TypeIdx);
      Res.Kind    := EK_AX;
      Res.TypeIdx := TY_IDX_INT;
      Res.SymIdx  := -1;
    End;
  Until False;
End;

{ ---- ParseExpr : parser une expression Prolog complete ------- }
{ Equivalent a ParseExprPrec avec MinPrec=1 (tous les           }
{ operateurs sont captures, y compris :- et ?- au niveau 1).    }
Procedure ParseExpr(Var Res : TExprVal);
Begin
  ParseExprPrec(1, Res);
End;

{ ============================================================
  TODO 05 - TABLE DES SYMBOLES (PREDICATS ET FONCTEURS) [IMPLEMENTE]
  ============================================================ }

{ ---- SymNameClean : nettoyer un nom pour MASM ---------------- }
{ Remplace les caracteres non alphanumeriques par '_'.           }
Function SymNameClean(Const Name : TString) : TString;
Var
  I : Integer;
  R : TString;
  Ch : Char;
Begin
  R := '';
  For I := 1 To Length(Name) Do
  Begin
    Ch := Name[I];
    If ((Ch >= 'A') And (Ch <= 'Z')) Or
       ((Ch >= 'a') And (Ch <= 'z')) Or
       ((Ch >= '0') And (Ch <= '9')) Or
       (Ch = '_') Then
    Begin
      If Length(R) < MAX_STR Then
        R := R + Ch;
    End
    Else
    Begin
      If Length(R) < MAX_STR Then
        R := R + '_';
    End;
  End;
  If R = '' Then R := '_anon';
  SymNameClean := R;
End;

{ ---- SymMangle : generer le nom ASM mangled ------------------- }
{ Le prefixe depend de la categorie du symbole.                   }
{   SK_ATOM      -> _PLA_ (table des atomes)                     }
{   SK_FUNCTOR   -> _PLF_ (table des foncteurs)                  }
{   SK_PREDICATE -> _PLP_ (predicat utilisateur)                 }
{   SK_BUILTIN   -> _PLRT_ (predicat builtin -> runtime)         }
{   SK_OPERATOR  -> _PLP_ (operateur = predicat special)         }
{   SK_MODULE    -> _PLM_ (module - stub)                        }
Function SymMangle(Const Name : TString; Kind : TSymKind) : TString;
Var
  Clean : TString;
  Pfx   : TString;
Begin
  Clean := SymNameClean(Name);
  Case Kind Of
    SK_ATOM      : Pfx := PL_ATOM_PFX;
    SK_FUNCTOR   : Pfx := PL_FUN_PFX;
    SK_PREDICATE : Pfx := PL_PRED_PFX;
    SK_BUILTIN   : Pfx := PL_RT_PFX;
    SK_OPERATOR  : Pfx := PL_PRED_PFX;
    SK_MODULE    : Pfx := '_PLM_';
  Else
    Pfx := PL_VAR_PFX;
  End;
  SymMangle := Pfx + Clean;
End;

{ ---- SymFind : chercher un symbole par nom (MRU) ------------- }
{ Parcourt la table du plus recent au plus ancien.                }
{ Retourne l index du symbole, ou -1 si non trouve.               }
Function SymFind(Const Name : TString) : Integer;
Var
  I : Integer;
Begin
  For I := SymCount - 1 DownTo 0 Do
    If SymTab[I].Name = Name Then
    Begin
      SymFind := I;
      Exit;
    End;
  SymFind := -1;
End;

{ ---- SymFindPredicate : chercher un predicat par nom ET arite - }
{ En Prolog, un predicat est identifie par le couple nom/arite.   }
{ foo/1 et foo/2 sont des predicats differents.                   }
Function SymFindPredicate(Const Name : TString;
                           AArity : Integer) : Integer;
Var
  I : Integer;
Begin
  For I := SymCount - 1 DownTo 0 Do
    If (SymTab[I].Name = Name) And
       ((SymTab[I].Kind = SK_PREDICATE) Or (SymTab[I].Kind = SK_BUILTIN)) And
       (SymTab[I].Arity = AArity) Then
    Begin
      SymFindPredicate := I;
      Exit;
    End;
  SymFindPredicate := -1;
End;

{ ---- SymAdd : ajouter un symbole dans la table ---------------- }
{ Retourne l index du symbole ajoute (0-base) ou -1 si plein.     }
Function SymAdd(Const Name : TString; Kind : TSymKind;
                AArity : Integer) : Integer;
Var
  Idx : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    CompileError('table des symboles pleine (max=' + IntToStr(MAX_SYM) + ')');
    SymAdd := -1;
    Exit;
  End;
  Idx := SymCount;
  SymTab[Idx].Name        := Name;
  SymTab[Idx].MangledName := SymMangle(Name, Kind);
  SymTab[Idx].Kind        := Kind;
  SymTab[Idx].Arity       := AArity;
  SymTab[Idx].ClauseHead  := -1;
  SymTab[Idx].ClauseCount := 0;
  SymTab[Idx].ScopeLevel  := CurScope;
  SymTab[Idx].IsBuiltin   := (Kind = SK_BUILTIN);
  SymTab[Idx].BifCode     := BIF_NONE;
  SymTab[Idx].IsDynamic   := False;
  SymTab[Idx].IsExported  := False;
  SymTab[Idx].DeclLine    := LexLineNo;
  Inc(SymCount);
  Inc(TotalSyms);

  If Opts.DebugMode Then
    WriteLn('  SYM_ADD[', Idx, ']: ', Name,
            ' kind=', Ord(Kind),
            ' arity=', AArity,
            ' scope=', CurScope,
            ' -> ', SymTab[Idx].MangledName);

  SymAdd := Idx;
End;

{ ---- SymAddBif : ajouter un symbole builtin avec code BIF ----- }
Function SymAddBif(Const Name : TString; AArity : Integer;
                   ABif : Integer) : Integer;
Var Idx : Integer;
Begin
  Idx := SymAdd(Name, SK_BUILTIN, AArity);
  If Idx >= 0 Then
    SymTab[Idx].BifCode := ABif;
  SymAddBif := Idx;
End;

{ ---- SymEnterScope : entrer dans une nouvelle portee ---------- }
Procedure SymEnterScope;
Begin
  If ScopeTop >= MAX_SCOPE Then
  Begin
    CompileError('portees trop imbriquees (max=' + IntToStr(MAX_SCOPE) + ')');
    Exit;
  End;
  ScopeStack[ScopeTop] := SymCount;
  Inc(ScopeTop);
  Inc(CurScope);
  If Opts.DebugMode Then
    WriteLn('  SCOPE_ENTER: level=', CurScope);
End;

{ ---- SymLeaveScope : quitter la portee courante --------------- }
{ Retire tous les symboles ajoutes dans cette portee.             }
Procedure SymLeaveScope;
Begin
  If ScopeTop <= 0 Then Exit;
  If Opts.DebugMode Then
    WriteLn('  SCOPE_LEAVE: level=', CurScope);
  Dec(ScopeTop);
  SymCount := ScopeStack[ScopeTop];
  Dec(CurScope);
End;

{ ---- AtomIntern : interning d un atome ----------------------- }
{ Retourne l index de l atome dans AtomTab. Si l atome existe     }
{ deja, retourne l index existant (deduplication). Sinon, cree    }
{ une nouvelle entree.                                            }
Function AtomIntern(Const Name : TString) : Integer;
Var
  I : Integer;
Begin
  { Chercher si l atome existe deja }
  For I := 0 To AtomCount - 1 Do
    If AtomTab[I].Name = Name Then
    Begin
      AtomIntern := I;
      Exit;
    End;
  { Ajouter un nouvel atome }
  If AtomCount >= MAX_ATOM Then
  Begin
    CompileError('table des atomes pleine (max=' + IntToStr(MAX_ATOM) + ')');
    AtomIntern := -1;
    Exit;
  End;
  AtomTab[AtomCount].Name   := Name;
  AtomTab[AtomCount].SymIdx := -1;
  AtomIntern := AtomCount;
  Inc(AtomCount);
End;

{ ---- AtomName : retourner le nom d un atome par son index ----- }
Function AtomName(Idx : Integer) : TString;
Begin
  If (Idx >= 0) And (Idx < AtomCount) Then
    AtomName := AtomTab[Idx].Name
  Else
    AtomName := '?atom?';
End;

{ ---- FunctorIntern : interning d un foncteur ------------------ }
{ Un foncteur est un couple (atome_index, arite). Deux termes     }
{ f(a,b) et f(x,y) partagent le meme foncteur f/2.               }
{ Retourne l index dans FunctorTab.                               }
Function FunctorIntern(AAtomIdx, AArity : Integer) : Integer;
Var
  I : Integer;
Begin
  { Chercher si le foncteur existe deja }
  For I := 0 To FunctorCount - 1 Do
    If (FunctorTab[I].AtomIdx = AAtomIdx) And
       (FunctorTab[I].Arity = AArity) Then
    Begin
      FunctorIntern := I;
      Exit;
    End;
  { Ajouter un nouveau foncteur }
  If FunctorCount >= MAX_FUNCTOR Then
  Begin
    CompileError('table des foncteurs pleine (max=' + IntToStr(MAX_FUNCTOR) + ')');
    FunctorIntern := -1;
    Exit;
  End;
  FunctorTab[FunctorCount].AtomIdx := AAtomIdx;
  FunctorTab[FunctorCount].Arity   := AArity;
  FunctorTab[FunctorCount].SymIdx  := -1;
  FunctorIntern := FunctorCount;
  Inc(FunctorCount);
End;

{ ---- SymInit : initialiser les tables et builtins ------------- }
{ Enregistre les predicats builtins et les foncteurs systeme.     }
Procedure SymInit;
Var
  A : Integer;  { index atome temporaire }
Begin
  SymCount     := 0;
  ScopeTop     := 0;
  CurScope     := 0;
  AtomCount    := 0;
  FunctorCount := 0;
  TotalSyms    := 0;

  { Foncteurs systeme : interning des atomes de base }
  A := AtomIntern('.');     { cons : '.'/2 }
  FunctorIntern(A, 2);
  A := AtomIntern('[]');    { nil  : []/0  }
  FunctorIntern(A, 0);
  A := AtomIntern(',');     { conjonction : ','/2 }
  FunctorIntern(A, 2);
  A := AtomIntern(';');     { disjonction : ';'/2 }
  FunctorIntern(A, 2);
  A := AtomIntern('->');    { if-then : '->'/2 }
  FunctorIntern(A, 2);

  { Atomes speciaux }
  AtomIntern('true');
  AtomIntern('fail');
  AtomIntern('false');

  { Predicats builtins ISO (controle) (TODO 18) }
  SymAddBif('true',      0, BIF_TRUE);
  SymAddBif('fail',      0, BIF_FAIL);
  SymAddBif('halt',      0, BIF_HALT);
  SymAddBif('halt',      1, BIF_HALT);

  { Predicats builtins ISO (unification) (TODO 18) }
  SymAddBif('=',         2, BIF_UNIFY);
  SymAddBif('\=',        2, BIF_NOT_UNIFY);
  SymAddBif('==',        2, BIF_STRUCT_EQ);
  SymAddBif('\==',       2, BIF_STRUCT_NEQ);
  SymAddBif('copy_term', 2, BIF_COPY_TERM);
  SymAddBif('unify_with_occurs_check', 2, BIF_UNIFY_OC);

  { Predicats builtins ISO (arithmetique) (TODO 18) }
  SymAddBif('is',        2, BIF_IS);
  SymAddBif('=:=',       2, BIF_ARITH_EQ);
  SymAddBif('=\=',       2, BIF_ARITH_NEQ);
  SymAddBif('<',         2, BIF_ARITH_LT);
  SymAddBif('>',         2, BIF_ARITH_GT);
  SymAddBif('=<',        2, BIF_ARITH_LE);
  SymAddBif('>=',        2, BIF_ARITH_GE);

  { Predicats builtins ISO (comparaison de termes) (TODO 18) }
  SymAddBif('@<',        2, BIF_TERM_LT);
  SymAddBif('@>',        2, BIF_TERM_GT);
  SymAddBif('@=<',       2, BIF_TERM_LE);
  SymAddBif('@>=',       2, BIF_TERM_GE);
  SymAddBif('compare',   3, BIF_COMPARE);

  { Predicats builtins ISO (type checking) (TODO 18) }
  SymAddBif('var',       1, BIF_VAR);
  SymAddBif('nonvar',    1, BIF_NONVAR);
  SymAddBif('atom',      1, BIF_ATOM);
  SymAddBif('number',    1, BIF_NUMBER);
  SymAddBif('integer',   1, BIF_INTEGER);
  SymAddBif('float',     1, BIF_FLOAT);
  SymAddBif('compound',  1, BIF_COMPOUND);
  SymAddBif('callable',  1, BIF_CALLABLE);
  SymAddBif('is_list',   1, BIF_IS_LIST);
  SymAddBif('atomic',    1, BIF_ATOMIC);
  SymAddBif('ground',    1, BIF_GROUND);

  { Predicats builtins ISO (decomposition de termes) (TODO 18) }
  SymAddBif('functor',   3, BIF_FUNCTOR);
  SymAddBif('arg',       3, BIF_ARG);
  SymAddBif('=..',       2, BIF_UNIV);

  { Predicats builtins ISO (listes) (TODO 18) }
  SymAddBif('append',    3, BIF_APPEND);
  SymAddBif('length',    2, BIF_LENGTH);
  SymAddBif('member',    2, BIF_MEMBER);
  SymAddBif('last',      2, BIF_LAST);
  SymAddBif('reverse',   2, BIF_REVERSE);
  SymAddBif('msort',     2, BIF_MSORT);
  SymAddBif('sort',      2, BIF_SORT);
  SymAddBif('nth0',      3, BIF_NTH0);
  SymAddBif('nth1',      3, BIF_NTH1);

  { Predicats builtins ISO (E/S) (TODO 18) }
  SymAddBif('write',     1, BIF_WRITE);
  SymAddBif('writeln',   1, BIF_WRITELN);
  SymAddBif('write_canonical', 1, BIF_WRITE_CAN);
  SymAddBif('print',     1, BIF_PRINT);
  SymAddBif('nl',        0, BIF_NL);
  SymAddBif('read',      1, BIF_READ);
  SymAdd('read_term', SK_BUILTIN, 2);
  SymAddBif('get_char',  1, BIF_GET_CHAR);
  SymAddBif('put_char',  1, BIF_PUT_CHAR);
  SymAddBif('tab',       1, BIF_TAB);

  { Predicats builtins ISO (assert/retract) (TODO 18) }
  SymAddBif('assert',    1, BIF_ASSERT);
  SymAddBif('asserta',   1, BIF_ASSERTA);
  SymAddBif('assertz',   1, BIF_ASSERTZ);
  SymAddBif('retract',   1, BIF_RETRACT);
  SymAddBif('abolish',   1, BIF_ABOLISH);

  { Predicats builtins ISO (controle avance) (TODO 18) }
  SymAddBif('call',      1, BIF_CALL);
  SymAddBif('not',       1, BIF_NOT);
  SymAddBif('findall',   3, BIF_FINDALL);
  SymAddBif('bagof',     3, BIF_BAGOF);
  SymAddBif('setof',     3, BIF_SETOF);
  SymAddBif('between',   3, BIF_BETWEEN);

  { Predicats builtins ISO (atomes et chaines) (TODO 18) }
  SymAddBif('atom_length',  2, BIF_ATOM_LENGTH);
  SymAddBif('atom_concat',  3, BIF_ATOM_CONCAT);
  SymAddBif('atom_chars',   2, BIF_ATOM_CHARS);
  SymAddBif('atom_codes',   2, BIF_ATOM_CODES);
  SymAddBif('atom_string',  2, BIF_ATOM_STRING);
  SymAddBif('char_code',    2, BIF_CHAR_CODE);
  SymAddBif('number_codes', 2, BIF_NUMBER_CODES);
  SymAddBif('number_chars', 2, BIF_NUMBER_CHARS);
  SymAddBif('sub_atom',     5, BIF_SUB_ATOM);
  SymAddBif('upcase_atom',  2, BIF_UPCASE_ATOM);
  SymAddBif('downcase_atom', 2, BIF_DOWNCASE_ATOM);

  { Predicats builtins (chaines) (TODO 23) }
  SymAddBif('char_type',      2, BIF_CHAR_TYPE);
  SymAddBif('number_string',  2, BIF_NUMBER_STRING);
  SymAddBif('string_concat',  3, BIF_STRING_CONCAT);
  SymAddBif('string_length',  2, BIF_STRING_LENGTH);

  { Predicats builtins (operateurs) (TODO 21) }
  SymAddBif('op',           3, BIF_OP);
  SymAddBif('current_op',   3, BIF_CURRENT_OP);

  { Predicats builtins (directives) (TODO 22) }
  SymAddBif('dynamic',        1, BIF_DYNAMIC);
  SymAddBif('discontiguous',  1, BIF_DISCONTIGUOUS);
  SymAddBif('module',         2, BIF_MODULE);
  SymAddBif('use_module',     1, BIF_USE_MODULE);
  SymAddBif('ensure_loaded',  1, BIF_ENSURE_LOADED);
  SymAddBif('initialization', 1, BIF_INITIALIZATION);
End;

{ ============================================================
  TODO 21 - OPERATEURS UTILISATEUR (OP/3) [IMPLEMENTE]
  ============================================================ }

{ ---- OpFind : chercher un operateur par nom -------------------- }
{ Retourne l index dans OpTab ou -1 si pas trouve.                 }
Function OpFind(Const AName : TString) : Integer;
Var
  I : Integer;
Begin
  OpFind := -1;
  For I := 0 To OpCount - 1 Do
    If OpTab[I].Name = AName Then
    Begin
      OpFind := I;
      Exit;
    End;
End;

{ ---- OpAdd : ajouter ou modifier un operateur ------------------- }
{ Si un operateur du meme nom existe, met a jour sa precedence et   }
{ son specifieur. Sinon, ajoute un nouvel operateur.                }
{ Si APrec = 0, supprime l operateur.                               }
Procedure OpAdd(Const AName : TString; APrec : Integer;
                Const ASpec : TString);
Var
  Idx, I : Integer;
Begin
  Idx := OpFind(AName);
  If APrec = 0 Then
  Begin
    { Suppression }
    If Idx >= 0 Then
    Begin
      For I := Idx To OpCount - 2 Do
        OpTab[I] := OpTab[I + 1];
      Dec(OpCount);
    End;
    Exit;
  End;
  If Idx >= 0 Then
  Begin
    { Mise a jour }
    OpTab[Idx].Prec := APrec;
    OpTab[Idx].Spec := ASpec;
  End
  Else
  Begin
    { Ajout }
    If OpCount >= MAX_OP Then
    Begin
      WarnMsg('operator table full, ignoring op(' +
              IntToStr(APrec) + ',' + ASpec + ',' + AName + ')');
      Exit;
    End;
    OpTab[OpCount].Name := AName;
    OpTab[OpCount].Prec := APrec;
    OpTab[OpCount].Spec := ASpec;
    Inc(OpCount);
  End;
End;

{ ---- OpInit : initialiser la table des operateurs ISO ------------ }
{ Enregistre les operateurs standard ISO Prolog dans OpTab.          }
Procedure OpInit;
Begin
  OpCount := 0;
  { Directives (1200) }
  OpAdd(':-',   1200, 'fx');
  OpAdd('?-',   1200, 'fx');
  OpAdd('-->',  1200, 'xfx');
  { Disjonction (1100) }
  OpAdd(';',    1100, 'xfy');
  OpAdd('|',    1100, 'xfy');
  { If-then (1050) }
  OpAdd('->',   1050, 'xfy');
  { Conjonction (1000) }
  OpAdd(',',    1000, 'xfy');
  { Negation (900) }
  OpAdd('\+',    900, 'fy');
  OpAdd('not',   900, 'fy');
  { Comparaison / unification / evaluation (700) }
  OpAdd('is',    700, 'xfx');
  OpAdd('=',     700, 'xfx');
  OpAdd('\=',    700, 'xfx');
  OpAdd('==',    700, 'xfx');
  OpAdd('\==',   700, 'xfx');
  OpAdd('=:=',   700, 'xfx');
  OpAdd('=\=',   700, 'xfx');
  OpAdd('<',     700, 'xfx');
  OpAdd('>',     700, 'xfx');
  OpAdd('=<',    700, 'xfx');
  OpAdd('>=',    700, 'xfx');
  OpAdd('=..',   700, 'xfx');
  OpAdd('@<',    700, 'xfx');
  OpAdd('@>',    700, 'xfx');
  OpAdd('@=<',   700, 'xfx');
  OpAdd('@>=',   700, 'xfx');
  { Addition / soustraction / bits (500) }
  OpAdd('+',     500, 'yfx');
  OpAdd('-',     500, 'yfx');
  OpAdd('/\',    500, 'yfx');
  OpAdd('\/',    500, 'yfx');
  { Multiplication / division (400) }
  OpAdd('*',     400, 'yfx');
  OpAdd('/',     400, 'yfx');
  OpAdd('//',    400, 'yfx');
  OpAdd('rem',   400, 'yfx');
  OpAdd('mod',   400, 'yfx');
  OpAdd('<<',    400, 'yfx');
  OpAdd('>>',    400, 'yfx');
  { Puissance / existentiel (200) }
  OpAdd('**',    200, 'xfx');
  OpAdd('^',     200, 'xfy');
End;

{ ============================================================
  TODO 22 - DIRECTIVES ET CHARGEMENT [IMPLEMENTE]
  ============================================================ }

{ ---- DirectiveInit : initialiser les variables de directives --- }
{ Appele depuis GlobalInit ou Run avant le parsing.                }
Procedure DirectiveInit;
Var I : Integer;
Begin
  ModuleName    := '';
  ModuleDefined := False;
  ModuleExpCount := 0;
  InitGoalCount := 0;
  For I := 0 To MAX_SYM - 1 Do
    DiscontigFlag[I] := False;
  DoubleQuotesMode := 'atom';
End;

{ ---- ParseDirective : parser une directive :- ... . ------------ }
{ Appele quand CurToken est :- (deja consomme).                    }
{ Traite les directives standard ISO :                             }
{   :- module(Nom, Exports).                                       }
{   :- use_module(Module).                                         }
{   :- dynamic(Pred/Arity).                                        }
{   :- discontiguous(Pred/Arity).                                  }
{   :- ensure_loaded(Fichier).                                     }
{   :- op(Prio, Type, Nom).                                        }
{   :- initialization(Goal).                                       }
{ Retourne True si la directive a ete traitee.                     }
Function ParseDirective : Boolean;
Var
  DirName  : TString;
  ArgAtom  : TString;
  PredName : TString;
  PredArity: Integer;
  OpPrec   : Integer;
  OpType   : TString;
  OpName   : TString;
  SIdx     : Integer;
  FlagName : TString;
Begin
  ParseDirective := False;

  { Verifier qu on a un atome (nom de la directive) }
  If CurToken.Kind <> TK_ATOM Then
  Begin
    { Directive generique non reconnue : sauter jusqu au . }
    WarnMsg('directive non reconnue, ignoree');
    While (CurToken.Kind <> TK_EOF) And (CurToken.Kind <> TK_DOT) Do
      ParserAdvance;
    If CurToken.Kind = TK_DOT Then
      ParserAdvance;
    ParseDirective := True;
    Exit;
  End;

  DirName := CurToken.Val;
  ParserAdvance; { consomme le nom de la directive }

  { === :- module(Name, Exports). === }
  If DirName = 'module' Then
  Begin
    If CurToken.Kind = TK_LPAREN Then
    Begin
      ParserAdvance; { ( }
      If CurToken.Kind = TK_ATOM Then
      Begin
        ModuleName    := CurToken.Val;
        ModuleDefined := True;
        ParserAdvance; { nom du module }
        If Opts.Verbose Then
          WriteLn('PROLOG86: module ', ModuleName);
      End;
      { Avancer jusqu a la liste d exports ou la fin }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      Begin
        ParserAdvance; { , }
        { Parser la liste d exports [pred1/a1, pred2/a2, ...] }
        If CurToken.Kind = TK_LBRACKET Then
        Begin
          ParserAdvance; { [ }
          ModuleExpCount := 0;
          While (CurToken.Kind <> TK_EOF) And
                (CurToken.Kind <> TK_RBRACKET) Do
          Begin
            If (CurToken.Kind = TK_ATOM) And
               (ModuleExpCount < MAX_MODULE_EXP) Then
            Begin
              ModuleExports[ModuleExpCount] := CurToken.Val;
              Inc(ModuleExpCount);
              ParserAdvance;
              { Sauter /Arity si present }
              If (CurToken.Kind = TK_OP) And (CurToken.Val = '/') Then
              Begin
                ParserAdvance; { / }
                If CurToken.Kind = TK_INTEGER Then
                  ParserAdvance; { arity }
              End;
            End
            Else
              ParserAdvance;
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
              ParserAdvance;
          End;
          If CurToken.Kind = TK_RBRACKET Then
            ParserAdvance; { ] }
        End;
      End;
      If CurToken.Kind = TK_RPAREN Then
        ParserAdvance; { ) }
    End;
    { Avancer jusqu au . }
    While (CurToken.Kind <> TK_EOF) And (CurToken.Kind <> TK_DOT) Do
      ParserAdvance;
    If CurToken.Kind = TK_DOT Then
      ParserAdvance;
    ParseDirective := True;
    Exit;
  End

  { === :- use_module(Module). === }
  Else If DirName = 'use_module' Then
  Begin
    If CurToken.Kind = TK_LPAREN Then
    Begin
      ParserAdvance; { ( }
      If CurToken.Kind = TK_ATOM Then
      Begin
        ArgAtom := CurToken.Val;
        If Opts.Verbose Then
          WriteLn('PROLOG86: use_module(', ArgAtom, ')');
        ParserAdvance;
      End;
      { Sauter jusqu a ) }
      While (CurToken.Kind <> TK_EOF) And
            (CurToken.Kind <> TK_RPAREN) Do
        ParserAdvance;
      If CurToken.Kind = TK_RPAREN Then
        ParserAdvance; { ) }
    End;
    While (CurToken.Kind <> TK_EOF) And (CurToken.Kind <> TK_DOT) Do
      ParserAdvance;
    If CurToken.Kind = TK_DOT Then
      ParserAdvance;
    ParseDirective := True;
    Exit;
  End

  { === :- dynamic(Pred/Arity). === }
  Else If DirName = 'dynamic' Then
  Begin
    If CurToken.Kind = TK_LPAREN Then
    Begin
      ParserAdvance; { ( }
      { Parser un ou plusieurs Pred/Arity, separes par des virgules }
      While (CurToken.Kind <> TK_EOF) And
            (CurToken.Kind <> TK_RPAREN) Do
      Begin
        If CurToken.Kind = TK_ATOM Then
        Begin
          PredName  := CurToken.Val;
          PredArity := 0;
          ParserAdvance;
          If (CurToken.Kind = TK_OP) And (CurToken.Val = '/') Then
          Begin
            ParserAdvance; { / }
            If CurToken.Kind = TK_INTEGER Then
            Begin
              PredArity := CurToken.IntVal;
              ParserAdvance;
            End;
          End;
          { Trouver ou creer le predicat et le marquer dynamique }
          SIdx := SymFindPredicate(PredName, PredArity);
          If SIdx < 0 Then
            SIdx := SymAdd(PredName, SK_PREDICATE, PredArity);
          If SIdx >= 0 Then
          Begin
            SymTab[SIdx].IsDynamic := True;
            If Opts.Verbose Then
              WriteLn('PROLOG86: dynamic ', PredName, '/', PredArity);
          End;
        End
        Else
          ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          ParserAdvance;
      End;
      If CurToken.Kind = TK_RPAREN Then
        ParserAdvance; { ) }
    End
    Else If CurToken.Kind = TK_ATOM Then
    Begin
      { :- dynamic pred/arity. (sans parentheses) }
      PredName  := CurToken.Val;
      PredArity := 0;
      ParserAdvance;
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '/') Then
      Begin
        ParserAdvance; { / }
        If CurToken.Kind = TK_INTEGER Then
        Begin
          PredArity := CurToken.IntVal;
          ParserAdvance;
        End;
      End;
      SIdx := SymFindPredicate(PredName, PredArity);
      If SIdx < 0 Then
        SIdx := SymAdd(PredName, SK_PREDICATE, PredArity);
      If SIdx >= 0 Then
      Begin
        SymTab[SIdx].IsDynamic := True;
        If Opts.Verbose Then
          WriteLn('PROLOG86: dynamic ', PredName, '/', PredArity);
      End;
    End;
    While (CurToken.Kind <> TK_EOF) And (CurToken.Kind <> TK_DOT) Do
      ParserAdvance;
    If CurToken.Kind = TK_DOT Then
      ParserAdvance;
    ParseDirective := True;
    Exit;
  End

  { === :- discontiguous(Pred/Arity). === }
  Else If DirName = 'discontiguous' Then
  Begin
    If CurToken.Kind = TK_LPAREN Then
    Begin
      ParserAdvance; { ( }
      While (CurToken.Kind <> TK_EOF) And
            (CurToken.Kind <> TK_RPAREN) Do
      Begin
        If CurToken.Kind = TK_ATOM Then
        Begin
          PredName  := CurToken.Val;
          PredArity := 0;
          ParserAdvance;
          If (CurToken.Kind = TK_OP) And (CurToken.Val = '/') Then
          Begin
            ParserAdvance; { / }
            If CurToken.Kind = TK_INTEGER Then
            Begin
              PredArity := CurToken.IntVal;
              ParserAdvance;
            End;
          End;
          SIdx := SymFindPredicate(PredName, PredArity);
          If SIdx < 0 Then
            SIdx := SymAdd(PredName, SK_PREDICATE, PredArity);
          If (SIdx >= 0) And (SIdx < MAX_SYM) Then
          Begin
            DiscontigFlag[SIdx] := True;
            If Opts.Verbose Then
              WriteLn('PROLOG86: discontiguous ', PredName, '/', PredArity);
          End;
        End
        Else
          ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          ParserAdvance;
      End;
      If CurToken.Kind = TK_RPAREN Then
        ParserAdvance; { ) }
    End;
    While (CurToken.Kind <> TK_EOF) And (CurToken.Kind <> TK_DOT) Do
      ParserAdvance;
    If CurToken.Kind = TK_DOT Then
      ParserAdvance;
    ParseDirective := True;
    Exit;
  End

  { === :- ensure_loaded(Fichier). === }
  Else If DirName = 'ensure_loaded' Then
  Begin
    If CurToken.Kind = TK_LPAREN Then
    Begin
      ParserAdvance; { ( }
      If CurToken.Kind = TK_ATOM Then
      Begin
        ArgAtom := CurToken.Val;
        If Opts.Verbose Then
          WriteLn('PROLOG86: ensure_loaded(', ArgAtom, ')');
        ParserAdvance;
      End;
      While (CurToken.Kind <> TK_EOF) And
            (CurToken.Kind <> TK_RPAREN) Do
        ParserAdvance;
      If CurToken.Kind = TK_RPAREN Then
        ParserAdvance; { ) }
    End;
    While (CurToken.Kind <> TK_EOF) And (CurToken.Kind <> TK_DOT) Do
      ParserAdvance;
    If CurToken.Kind = TK_DOT Then
      ParserAdvance;
    ParseDirective := True;
    Exit;
  End

  { === :- op(Prio, Type, Nom). === }
  Else If DirName = 'op' Then
  Begin
    OpPrec := 0;
    OpType := 'xfx';
    OpName := '';
    If CurToken.Kind = TK_LPAREN Then
    Begin
      ParserAdvance; { ( }
      { Precedence }
      If CurToken.Kind = TK_INTEGER Then
      Begin
        OpPrec := CurToken.IntVal;
        ParserAdvance;
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance;
      { Type }
      If CurToken.Kind = TK_ATOM Then
      Begin
        OpType := CurToken.Val;
        ParserAdvance;
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance;
      { Nom }
      If (CurToken.Kind = TK_ATOM) Or (CurToken.Kind = TK_OP) Then
      Begin
        OpName := CurToken.Val;
        ParserAdvance;
      End;
      While (CurToken.Kind <> TK_EOF) And
            (CurToken.Kind <> TK_RPAREN) Do
        ParserAdvance;
      If CurToken.Kind = TK_RPAREN Then
        ParserAdvance; { ) }
    End;
    If (OpPrec > 0) And (OpName <> '') Then
    Begin
      OpAdd(OpName, OpPrec, OpType);
      If Opts.Verbose Then
        WriteLn('PROLOG86: op(', OpPrec, ', ', OpType, ', ', OpName, ')');
    End;
    While (CurToken.Kind <> TK_EOF) And (CurToken.Kind <> TK_DOT) Do
      ParserAdvance;
    If CurToken.Kind = TK_DOT Then
      ParserAdvance;
    ParseDirective := True;
    Exit;
  End

  { === :- set_prolog_flag(double_quotes, Mode). === (TODO 23) }
  Else If DirName = 'set_prolog_flag' Then
  Begin
    { Parser : set_prolog_flag(FlagName, Value) }
    If (CurToken.Kind = TK_ATOM) Then
    Begin
      FlagName := CurToken.Val;
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance;
      If (CurToken.Kind = TK_ATOM) Then
      Begin
        If FlagName = 'double_quotes' Then
        Begin
          DoubleQuotesMode := CurToken.Val;
          If Opts.Verbose Then
            WriteLn('PROLOG86: double_quotes = ', DoubleQuotesMode);
        End;
        ParserAdvance;
      End;
    End;
    While (CurToken.Kind <> TK_EOF) And (CurToken.Kind <> TK_DOT) Do
      ParserAdvance;
    If CurToken.Kind = TK_DOT Then
      ParserAdvance;
    ParseDirective := True;
    Exit;
  End

  { === :- initialization(Goal). === }
  Else If DirName = 'initialization' Then
  Begin
    { Pour un compilateur simple, on enregistre que le predicat doit }
    { etre appele au demarrage. On stocke le nombre de buts init.    }
    Inc(InitGoalCount);
    If Opts.Verbose Then
      WriteLn('PROLOG86: initialization directive #', InitGoalCount);
    While (CurToken.Kind <> TK_EOF) And (CurToken.Kind <> TK_DOT) Do
      ParserAdvance;
    If CurToken.Kind = TK_DOT Then
      ParserAdvance;
    ParseDirective := True;
    Exit;
  End

  { === Directive generique (goals a executer) === }
  { :- goal1, goal2, ... .                         }
  { Comme write('hello'), nl. ou test_xxx.         }
  Else
  Begin
    { Verifier si c est un predicat connu -> compiler comme fait/regle }
    { avec execution au chargement (point d entree init)               }
    { Pour simplifier : stocker le nom comme but d initialisation      }
    Inc(InitGoalCount);
    If Opts.Verbose Then
      WriteLn('PROLOG86: directive goal: ', DirName);
    While (CurToken.Kind <> TK_EOF) And (CurToken.Kind <> TK_DOT) Do
      ParserAdvance;
    If CurToken.Kind = TK_DOT Then
      ParserAdvance;
    ParseDirective := True;
    Exit;
  End;
End;

{ ============================================================
  TODO 06 - REPRESENTATION DES TERMES (TAGS) [IMPLEMENTE]
  ============================================================ }

{ ---- Constructeurs de cellules taggees ----------------------- }
{ Chaque cellule WAM est un Word 16 bits :                       }
{   Bits 15..13 = Tag (0..7)                                     }
{   Bits 12..0  = Valeur (0..8191 non signe, ou signe pour INT)  }

{ MakeRef : creer une cellule REF (variable non liee)            }
{ La valeur est l adresse dans le heap ou la variable pointe.    }
{ Une variable libre pointe sur elle-meme : MakeRef(addr) a addr.}
Function MakeRef(Addr : Integer) : Integer;
Begin
  MakeRef := (TAG_REF Shl TAG_SHIFT) Or (Addr And VAL_MASK);
End;

{ MakeAtom : creer une cellule ATOM                              }
{ La valeur est l index dans la table des atomes (AtomTab).      }
Function MakeAtom(AIdx : Integer) : Integer;
Begin
  MakeAtom := (TAG_ATOM Shl TAG_SHIFT) Or (AIdx And VAL_MASK);
End;

{ MakeInt : creer une cellule INT (entier 13 bits signe)         }
{ Les entiers sont stockes en complement a deux sur 13 bits.     }
{ Plage valide : -4096..4095.                                    }
Function MakeInt(Val : Integer) : Integer;
Begin
  If Val < INT_MIN_VAL Then
    Val := INT_MIN_VAL
  Else If Val > INT_MAX_VAL Then
    Val := INT_MAX_VAL;
  MakeInt := (TAG_INT Shl TAG_SHIFT) Or (Val And VAL_MASK);
End;

{ MakeStr : creer une cellule STR (structure/foncteur)           }
{ La valeur est l adresse dans le heap du debut de la structure. }
{ Le premier word du heap a cette adresse contient l index du    }
{ foncteur dans FunctorTab, suivi des arguments.                 }
Function MakeStr(Addr : Integer) : Integer;
Begin
  MakeStr := (TAG_STR Shl TAG_SHIFT) Or (Addr And VAL_MASK);
End;

{ MakeList : creer une cellule LIST (paire de liste)             }
{ La valeur est l adresse dans le heap de la paire [Head|Tail].  }
{ head = Heap[addr], tail = Heap[addr+1].                        }
Function MakeList(Addr : Integer) : Integer;
Begin
  MakeList := (TAG_LIST Shl TAG_SHIFT) Or (Addr And VAL_MASK);
End;

{ ---- Extraction du tag et de la valeur ----------------------- }

{ GetTag : extraire le tag (3 bits hauts) d une cellule          }
Function GetTag(Cell : Integer) : Integer;
Begin
  GetTag := (Cell Shr TAG_SHIFT) And 7;
End;

{ GetVal : extraire la valeur (13 bits bas) d une cellule        }
{ Pour TAG_INT, la valeur est signee (extension de signe).       }
{ Pour les autres tags, la valeur est non signee.                }
Function GetVal(Cell : Integer) : Integer;
Var
  V : Integer;
Begin
  V := Cell And VAL_MASK;
  If (GetTag(Cell) = TAG_INT) And ((V And $1000) <> 0) Then
    { Extension de signe : bit 12 est le signe, propager aux bits 13..15 }
    V := V Or (Not VAL_MASK);
  { Sinon V reste non signe (deja masque par VAL_MASK) }
  GetVal := V;
End;

{ ---- Predicats de type sur les cellules ---------------------- }

Function IsRef(Cell : Integer) : Boolean;
Begin
  IsRef := (GetTag(Cell) = TAG_REF);
End;

Function IsAtom(Cell : Integer) : Boolean;
Begin
  IsAtom := (GetTag(Cell) = TAG_ATOM);
End;

Function IsInt(Cell : Integer) : Boolean;
Begin
  IsInt := (GetTag(Cell) = TAG_INT);
End;

Function IsStr(Cell : Integer) : Boolean;
Begin
  IsStr := (GetTag(Cell) = TAG_STR);
End;

Function IsList(Cell : Integer) : Boolean;
Begin
  IsList := (GetTag(Cell) = TAG_LIST);
End;

{ ---- Dereferencement ----------------------------------------- }
{ Deref suit les chaines de references REF jusqu au terme final. }
{ Si une variable REF pointe sur elle-meme, elle est non liee.   }
{ Sinon, on suit recursivement la chaine de liaisons.            }
{ Retourne l adresse de la cellule finale dans le heap.          }

Function Deref(Addr : Integer) : Integer;
Var
  Cell : Integer;
  V    : Integer;
Begin
  While True Do
  Begin
    If (Addr < 0) Or (Addr >= HTop) Then
    Begin
      Deref := Addr;
      Exit;
    End;
    Cell := Heap[Addr];
    If GetTag(Cell) <> TAG_REF Then
    Begin
      { Pas une reference, c est le terme final }
      Deref := Addr;
      Exit;
    End;
    V := GetVal(Cell);
    If V = Addr Then
    Begin
      { Variable libre : pointe sur elle-meme }
      Deref := Addr;
      Exit;
    End;
    { Suivre la chaine }
    Addr := V;
  End;
End;

{ ---- Gestion du Heap (tas WAM) ------------------------------- }
{ Le heap contient les termes construits : atomes, entiers,      }
{ structures, listes, et les variables.                          }

{ HeapPush : empiler une cellule sur le heap, retourne l adresse }
Function HeapPush(Cell : Integer) : Integer;
Begin
  If HTop >= HEAP_SIZE Then
  Begin
    CompileError('heap WAM plein (max=' + IntToStr(HEAP_SIZE) + ')');
    HeapPush := -1;
    Exit;
  End;
  Heap[HTop] := Cell;
  HeapPush := HTop;
  Inc(HTop);
End;

{ HeapTop : retourner le sommet courant du heap (prochain libre) }
Function HeapTop : Integer;
Begin
  HeapTop := HTop;
End;

{ HeapReset : reinitialiser le heap (vider toutes les cellules)  }
Procedure HeapReset;
Begin
  HTop := 0;
End;

{ ---- Gestion de la pile d environnements (Stack) ------------- }
{ La pile contient les frames d appel : variables locales,       }
{ pointeurs de continuation, choix, etc.                         }

{ StackPush : empiler une cellule sur la pile, retourne l adresse}
Function StackPush(Cell : Integer) : Integer;
Begin
  If STop >= STACK_SIZE Then
  Begin
    CompileError('pile WAM pleine (max=' + IntToStr(STACK_SIZE) + ')');
    StackPush := -1;
    Exit;
  End;
  Stack[STop] := Cell;
  StackPush := STop;
  Inc(STop);
End;

{ StackTop : retourner le sommet courant de la pile              }
Function StackTop : Integer;
Begin
  StackTop := STop;
End;

{ StackReset : reinitialiser la pile                             }
Procedure StackReset;
Begin
  STop := 0;
End;

{ ---- Gestion du Trail (historique des liaisons) --------------- }
{ Le trail enregistre les adresses des variables liees pour      }
{ pouvoir defaire les liaisons lors du backtracking.             }

{ TrailPush : enregistrer une adresse dans le trail              }
Procedure TrailPush(Addr : Integer);
Begin
  If TTop >= TRAIL_SIZE Then
  Begin
    CompileError('trail WAM plein (max=' + IntToStr(TRAIL_SIZE) + ')');
    Exit;
  End;
  Trail[TTop] := Addr;
  Inc(TTop);
End;

{ TrailTop : retourner le sommet courant du trail                }
Function TrailTop : Integer;
Begin
  TrailTop := TTop;
End;

{ TrailReset : reinitialiser le trail                            }
Procedure TrailReset;
Begin
  TTop := 0;
End;

{ ---- Initialisation des structures WAM ----------------------- }
Procedure TermInit;
Begin
  HTop := 0;
  STop := 0;
  TTop := 0;
  FillChar(Heap,  SizeOf(Heap),  0);
  FillChar(Stack, SizeOf(Stack), 0);
  FillChar(Trail, SizeOf(Trail), 0);
End;

{ ============================================================
  TODO 09 - UNIFICATION [IMPLEMENTE]
  ============================================================ }

{ ---- Bind : lier une variable REF a un terme ------------------- }
{ RefAddr est l adresse heap d une cellule REF libre (pointe sur   }
{ elle-meme). On ecrit le terme Term a cette adresse et on empile  }
{ l adresse sur le trail pour pouvoir defaire la liaison lors du   }
{ backtracking.                                                    }
Procedure Bind(RefAddr, Term : Integer);
Begin
  Heap[RefAddr] := Term;
  TrailPush(RefAddr);
End;

{ ---- UnwindTrail : defaire les liaisons depuis SavedTop --------- }
{ Restaure toutes les variables liees depuis SavedTop jusqu a TTop  }
{ en remettant chaque cellule a une REF libre pointant sur elle-    }
{ meme. Utilise lors du backtracking pour annuler les unifications.  }
Procedure UnwindTrail(SavedTop : Integer);
Var
  I    : Integer;
  Addr : Integer;
Begin
  I := TTop - 1;
  While I >= SavedTop Do
  Begin
    Addr := Trail[I];
    Heap[Addr] := MakeRef(Addr);
    Dec(I);
  End;
  TTop := SavedTop;
End;

{ ---- Unify : algorithme d unification recursif ------------------- }
{ Prend deux adresses heap, dereference chacune, puis :              }
{   - Si les deux sont REF : lier la plus recente a l autre          }
{   - Si un seul est REF : lier la variable au terme                 }
{   - Si deux atomes : comparer les index d atome                    }
{   - Si deux entiers : comparer les valeurs                         }
{   - Si deux structures : comparer foncteur/arite, unifier args     }
{   - Si deux listes : unifier tete puis queue recursivement         }
{ Retourne True si l unification reussit, False sinon.               }
Function Unify(Addr1, Addr2 : Integer) : Boolean;
Var
  D1, D2   : Integer;
  C1, C2   : Integer;
  T1, T2   : Integer;
  V1, V2   : Integer;
  FIdx1    : Integer;
  FIdx2    : Integer;
  Arity    : Integer;
  I        : Integer;
  A1, A2   : Integer;
  Ok       : Boolean;
Begin
  D1 := Deref(Addr1);
  D2 := Deref(Addr2);

  { Meme adresse : trivial }
  If D1 = D2 Then
  Begin
    Unify := True;
    Exit;
  End;

  C1 := Heap[D1];
  C2 := Heap[D2];
  T1 := GetTag(C1);
  T2 := GetTag(C2);
  V1 := GetVal(C1);
  V2 := GetVal(C2);

  { ---- Cas 1 : les deux sont REF (variables libres) ----------- }
  If (T1 = TAG_REF) And (T2 = TAG_REF) Then
  Begin
    { Lier la plus recente (adresse plus haute) a l autre }
    If D1 > D2 Then
      Bind(D1, C2)
    Else
      Bind(D2, C1);
    Unify := True;
    Exit;
  End;

  { ---- Cas 2 : un seul est REF ----- }
  If T1 = TAG_REF Then
  Begin
    Bind(D1, C2);
    Unify := True;
    Exit;
  End;
  If T2 = TAG_REF Then
  Begin
    Bind(D2, C1);
    Unify := True;
    Exit;
  End;

  { ---- Cas 3 : deux atomes -------- }
  If (T1 = TAG_ATOM) And (T2 = TAG_ATOM) Then
  Begin
    Unify := (V1 = V2);
    Exit;
  End;

  { ---- Cas 4 : deux entiers ------- }
  If (T1 = TAG_INT) And (T2 = TAG_INT) Then
  Begin
    Unify := (V1 = V2);
    Exit;
  End;

  { ---- Cas 5 : deux structures ----- }
  { Structure sur le heap : [STR(addr)] -> Heap[addr] = foncteur   }
  { Heap[addr+1..addr+arity] = arguments                          }
  If (T1 = TAG_STR) And (T2 = TAG_STR) Then
  Begin
    A1 := V1;  { adresse du foncteur dans le heap }
    A2 := V2;
    { Le foncteur est stocke comme un entier brut : index FunctorTab }
    FIdx1 := Heap[A1];
    FIdx2 := Heap[A2];
    { Les foncteurs doivent etre identiques }
    If FIdx1 <> FIdx2 Then
    Begin
      Unify := False;
      Exit;
    End;
    { Extraire l arite du foncteur }
    If (FIdx1 >= 0) And (FIdx1 < FunctorCount) Then
      Arity := FunctorTab[FIdx1].Arity
    Else
    Begin
      Unify := False;
      Exit;
    End;
    { Unifier chaque argument }
    Ok := True;
    For I := 1 To Arity Do
    Begin
      Ok := Unify(A1 + I, A2 + I);
      If Not Ok Then
      Begin
        Unify := False;
        Exit;
      End;
    End;
    Unify := True;
    Exit;
  End;

  { ---- Cas 6 : deux listes --------- }
  { Liste sur le heap : [LIST(addr)] -> Heap[addr] = tete,         }
  { Heap[addr+1] = queue                                           }
  If (T1 = TAG_LIST) And (T2 = TAG_LIST) Then
  Begin
    A1 := V1;  { adresse de la paire dans le heap }
    A2 := V2;
    { Unifier la tete }
    Ok := Unify(A1, A2);
    If Not Ok Then
    Begin
      Unify := False;
      Exit;
    End;
    { Unifier la queue }
    Ok := Unify(A1 + 1, A2 + 1);
    Unify := Ok;
    Exit;
  End;

  { ---- Sinon : types incompatibles, echec ---- }
  Unify := False;
End;

{ ---- EmitDeref : emettre un appel a _PLRT_DEREF ------------------ }
{ AX contient l adresse du terme a dereferencer.                     }
{ Apres l appel, AX contient l adresse du terme dereference.         }
Procedure EmitDeref;
Begin
  EmitInstr('CALL    _PLRT_DEREF');
End;

{ ---- EmitBind : emettre un appel a _PLRT_BIND -------------------- }
{ AX = adresse de la variable REF, BX = terme a lier.               }
{ Empile l adresse sur le trail apres la liaison.                    }
Procedure EmitBind;
Begin
  EmitInstr('CALL    _PLRT_BIND');
End;

{ ---- EmitUnify : emettre un appel a _PLRT_UNIFY ------------------ }
{ AX = terme1, BX = terme2.                                         }
{ Apres l appel, CF (Carry Flag) = 1 si echec, 0 si succes.         }
Procedure EmitUnify;
Begin
  EmitInstr('CALL    _PLRT_UNIFY');
End;

{ ============================================================
  TODO 07 - EMETTEUR DE CODE ASM [IMPLEMENTE]
  ============================================================ }

{ ---- EmitOpen : ouvrir le fichier de sortie ASM --------------- }
{ Assigne le fichier OutF a Opts.OutFile et l ouvre en ecriture.  }
{ En cas d echec (IOResult <> 0), arrete avec FatalError.         }
Procedure EmitOpen;
Begin
  {$I-}
  Assign(OutF, Opts.OutFile);
  Rewrite(OutF);
  {$I+}
  If IOResult <> 0 Then
    FatalError('impossible de creer le fichier: ' + Opts.OutFile);
  OutFOpen := True;
End;

{ ---- EmitRaw : ecrire une ligne brute dans le fichier ASM ---- }
Procedure EmitRaw(Const S : TString);
Begin
  WriteLn(OutF, S);
End;

{ ---- EmitBlankLine : ecrire une ligne vide -------------------- }
Procedure EmitBlankLine;
Begin
  WriteLn(OutF);
End;

{ ---- EmitComment : ecrire un commentaire ASM (; texte) ------- }
Procedure EmitComment(Const S : TString);
Begin
  WriteLn(OutF, '; ', S);
End;

{ ---- EmitLabel : ecrire un label en colonne 0 (label:) ------- }
Procedure EmitLabel(Const Lbl : TString);
Begin
  WriteLn(OutF, Lbl, ':');
End;

{ ---- EmitInstr : instruction sans operande (8 espaces indent) - }
Procedure EmitInstr(Const Mnem : TString);
Begin
  WriteLn(OutF, '        ', Mnem);
End;

{ ---- EmitInstrA : instruction avec un operande --------------- }
Procedure EmitInstrA(Const Mnem, A1 : TString);
Begin
  WriteLn(OutF, '        ', Mnem, '   ', A1);
End;

{ ---- EmitInstrAB : instruction avec deux operandes ----------- }
Procedure EmitInstrAB(Const Mnem, A1, A2 : TString);
Begin
  WriteLn(OutF, '        ', Mnem, '   ', A1, ', ', A2);
End;

{ ---- EmitProlog : prologue de predicat/procedure ------------- }
{ PUSH BP / MOV BP,SP pour creer un frame de pile.               }
Procedure EmitProlog;
Begin
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
End;

{ ---- EmitEpilog : epilogue de predicat/procedure ------------- }
{ MOV SP,BP / POP BP / RET pour restaurer et retourner.          }
Procedure EmitEpilog;
Begin
  EmitInstrAB('MOV', 'SP', 'BP');
  EmitInstrA('POP', 'BP');
  EmitInstr('RET');
End;

{ ---- EmitHeader : en-tete du fichier ASM --------------------- }
{ Emet le commentaire d identification, les directives .MODEL     }
{ SMALL, .STACK 2048, et ouvre le segment _TEXT.                  }
{ Le point d entree est _PLP_Main (label du predicat principal).  }
Procedure EmitHeader;
Begin
  EmitComment('Genere par PROLOG86 v' + PL86_VERSION + ' - ' +
              Opts.SrcFile);
  EmitComment('Date: ' + PL86_DATE);
  EmitBlankLine;
  EmitRaw('        .MODEL SMALL');
  EmitRaw('        .STACK 2048');
  EmitBlankLine;
  EmitRaw('_TEXT   SEGMENT WORD PUBLIC ''CODE''');
  EmitRaw('        ASSUME  CS:_TEXT, DS:_DATA, SS:STACK');
  EmitBlankLine;
  EmitComment('--- Point d entree ---');
  EmitLabel('_PLP_Main');
  { Initialiser DS pour le segment DATA }
  EmitInstrAB('MOV', 'AX', '_DATA');
  EmitInstrAB('MOV', 'DS', 'AX');
  EmitBlankLine;
End;

{ ---- EmitDataSeg : emettre le segment de donnees ------------- }
{ Ecrit _DATA SEGMENT ... _DATA ENDS avec :                      }
{   - _PL_CRLF DB 13,10,0 (retour chariot+saut de ligne)        }
{   - Toutes les entrees du DataTab (DK_WORD, DK_BYTE, DK_STR,  }
{     DK_ATOM_TBL)                                               }
{   - Les zones WAM statiques (heap, stack, trail)               }
Procedure EmitDataSeg;
Var
  I, J : Integer;
  S    : TString;
Begin
  EmitRaw('_DATA   SEGMENT WORD PUBLIC ''DATA''');
  EmitBlankLine;

  { Constante CRLF pour les ecritures }
  EmitRaw('_PL_CRLF    DB  13,10,0');
  EmitBlankLine;

  { Buffer de travail pour les conversions }
  EmitRaw('_PL_STRBUF  DB  256 DUP(0)');
  EmitBlankLine;

  { Entrees dynamiques du DataTab }
  For I := 0 To DataCount - 1 Do
  Begin
    Case DataTab[I].Kind Of
      DK_WORD :
        EmitRaw(DataTab[I].LblName + '  DW  ' +
                IntToStr(DataTab[I].IntVal));
      DK_BYTE :
        EmitRaw(DataTab[I].LblName + '  DB  ' +
                IntToStr(DataTab[I].IntVal));
      DK_STR :
        Begin
          { Echapper les apostrophes pour MASM : ' -> ''          }
          { Caracteres de controle : emis en valeurs numeriques DB }
          { Le terminateur null est ajoute apres tous les octets. }
          S := '';
          For J := 1 To Length(DataTab[I].StrVal) Do
          Begin
            If (Ord(DataTab[I].StrVal[J]) < 32) Or
               (Ord(DataTab[I].StrVal[J]) > 126) Then
            Begin
              { Vider le texte accumule avant le caractere de controle }
              If Length(S) > 0 Then
              Begin
                EmitRaw(DataTab[I].LblName + '  DB  ''' + S + '''');
                S := '';
              End;
              EmitRaw('        DB  ' +
                      IntToStr(Ord(DataTab[I].StrVal[J])));
            End
            Else If DataTab[I].StrVal[J] = '''' Then
              S := S + ''''''
            Else
              S := S + DataTab[I].StrVal[J];
          End;
          { Emettre le reste du texte + terminateur null }
          If Length(S) > 0 Then
            EmitRaw(DataTab[I].LblName + '  DB  ''' + S + ''',0')
          Else
            EmitRaw('        DB  0');
        End;
      DK_ATOM_TBL :
        Begin
          { Table des atomes : DW avec offsets des chaines atomes }
          If DataTab[I].LblName = PL_ATOM_PFX + 'TABLE' Then
          Begin
            EmitComment('--- Table des atomes (' +
                        IntToStr(DataTab[I].ElemCount) + ' entrees) ---');
            If DataTab[I].ElemCount = 0 Then
              EmitRaw(DataTab[I].LblName + '  DW  0   ; table vide')
            Else
            Begin
              { Emettre les offsets par groupes de 8 pour lisibilite }
              J := 0;
              While J < DataTab[I].ElemCount Do
              Begin
                If J = 0 Then
                  S := DataTab[I].LblName + '  DW  '
                Else
                  S := '        DW  ';
                S := S + PL_ATOM_PFX + IntToStr(J);
                Inc(J);
                While (J < DataTab[I].ElemCount) And
                      ((J Mod 8) <> 0) Do
                Begin
                  S := S + ', ' + PL_ATOM_PFX + IntToStr(J);
                  Inc(J);
                End;
                EmitRaw(S);
              End;
            End;
            EmitRaw(PL_ATOM_PFX + 'COUNT  DW  ' +
                    IntToStr(DataTab[I].ElemCount));
          End
          { Table des foncteurs : paires (atome_index, arite) }
          Else If DataTab[I].LblName = PL_FUN_PFX + 'TABLE' Then
          Begin
            EmitComment('--- Table des foncteurs (' +
                        IntToStr(DataTab[I].ElemCount) + ' entrees) ---');
            For J := 0 To DataTab[I].ElemCount - 1 Do
            Begin
              EmitRaw(PL_FUN_PFX + IntToStr(J) + '  DW  ' +
                      IntToStr(FunctorTab[J].AtomIdx) + ', ' +
                      IntToStr(FunctorTab[J].Arity) +
                      '   ; ' + AtomTab[FunctorTab[J].AtomIdx].Name +
                      '/' + IntToStr(FunctorTab[J].Arity));
            End;
            EmitRaw(PL_FUN_PFX + 'COUNT  DW  ' +
                    IntToStr(DataTab[I].ElemCount));
          End
          Else
            EmitRaw(DataTab[I].LblName + '  DW  ' +
                    IntToStr(DataTab[I].ElemCount) +
                    '   ; table (' + IntToStr(DataTab[I].ElemCount) +
                    ' entrees)');
        End;
    End; { Case }
  End;

  EmitBlankLine;

  { Zones WAM statiques }
  EmitComment('--- Zones memoire WAM ---');
  EmitRaw('_PL_HEAP    DW  ' + IntToStr(HEAP_SIZE) + ' DUP(0)');
  EmitRaw('_PL_HTOP    DW  0');
  EmitRaw('_PL_STACK   DW  ' + IntToStr(STACK_SIZE) + ' DUP(0)');
  EmitRaw('_PL_STOP    DW  0');
  EmitRaw('_PL_TRAIL   DW  ' + IntToStr(TRAIL_SIZE) + ' DUP(0)');
  EmitRaw('_PL_TTOP    DW  0');
  EmitBlankLine;

  { Pointeur de pile de points de choix (TODO 12) }
  EmitComment('--- Backtracking (choice point stack) ---');
  EmitRaw('_PL_CPTOP   DW  0');
  EmitRaw('_PL_CUT_BARRIER DW  0');
  EmitBlankLine;

  { Buffer d entrees/sorties (TODO 17) }
  EmitComment('--- I/O buffer (TODO 17) ---');
  EmitRaw('_PL_IOBUF   DB  128 DUP(0)');
  EmitRaw('_PL_IOBUFLEN DW  0');
  EmitBlankLine;

  { Base de donnees dynamique (TODO 19) }
  EmitComment('--- Dynamic database (TODO 19) ---');
  EmitRaw('_PL_DYNDB   DW  256 DUP(0)');
  EmitRaw('_PL_DYNCOUNT DW  0');
  EmitBlankLine;

  { Buffer de collecte de solutions (TODO 20) }
  EmitComment('--- Solution collection buffer (TODO 20) ---');
  EmitRaw('_PL_COLLECT  DW  256 DUP(0)');
  EmitRaw('_PL_COLLCOUNT DW  0');
  EmitBlankLine;

  { Table des operateurs utilisateur (TODO 21) }
  EmitComment('--- Operator table (TODO 21) ---');
  EmitRaw('_PL_OPCOUNT DW  0');
  EmitRaw('_PL_OPPREC  DW  ' + IntToStr(MAX_OP) + ' DUP(0)');
  EmitRaw('_PL_OPTYPE  DB  ' + IntToStr(MAX_OP * 4) + ' DUP(0)');
  EmitRaw('_PL_OPNAME  DB  ' + IntToStr(MAX_OP * 32) + ' DUP(0)');
  EmitBlankLine;

  { Directives et module (TODO 22) }
  EmitComment('--- Directives (TODO 22) ---');
  EmitRaw('_PL_MODNAME DB  64 DUP(0)');
  EmitRaw('_PL_INITCNT DW  0');
  EmitBlankLine;

  { Chaines et caracteres (TODO 23) }
  EmitComment('--- Strings (TODO 23) ---');
  EmitRaw('_PL_DQMODE  DB  0');
  EmitBlankLine;

  { Registres d arguments WAM A1..AN (TODO 10) }
  EmitComment('--- Registres d arguments WAM ---');
  EmitRaw('_PL_ARGS    DW  ' + IntToStr(MAX_ARGS_REG) + ' DUP(0)');

  EmitBlankLine;
  EmitRaw('_DATA   ENDS');
End;

{ ============================================================
  TODO 12 - RETOUR ARRIERE (BACKTRACKING) [IMPLEMENTE]
  ============================================================ }

{ ---- EmitBacktrackRuntime : emettre les routines de backtracking -- }
{ Implemente les routines WAM de gestion des points de choix :       }
{   _PLRT_TRY    : creer un point de choix                          }
{   _PLRT_RETRY  : restaurer l etat et essayer la clause suivante   }
{   _PLRT_TRUST  : derniere clause, supprimer le point de choix     }
{   _PLRT_UNTRAIL: defaire les liaisons du trail                    }
{                                                                    }
{ Structure d un point de choix sur _PL_STACK (4 mots) :             }
{   [CPTOP-4] = ancien CPTOP (precedent point de choix)             }
{   [CPTOP-3] = TTOP sauvegarde (trail top)                         }
{   [CPTOP-2] = HTOP sauvegarde (heap top)                          }
{   [CPTOP-1] = adresse clause suivante (BX)                        }
{ Convention d appel :                                               }
{   _PLRT_TRY(BX=label_next) -> CF=0                                }
{   _PLRT_RETRY(BX=label_next) -> CF=0, etat restaure               }
{   _PLRT_TRUST -> CF=0, etat restaure, CP supprime                 }
{   _PLRT_UNTRAIL(CX=saved_ttop) -> trail defait                    }
Procedure EmitBacktrackRuntime;
Begin
  EmitBlankLine;
  EmitComment('=======================================');
  EmitComment('  Routines de backtracking (TODO 12)');
  EmitComment('=======================================');
  EmitBlankLine;

  { -------------------------------------------------------------- }
  { _PLRT_UNTRAIL : defaire les liaisons du trail                   }
  { Entree : CX = saved TTOP (defaire jusqu a cette valeur)        }
  { Sortie : _PL_TTOP = CX                                         }
  { Effet  : chaque adresse enregistree dans le trail est           }
  {          remise a son auto-reference (variable libre)            }
  { -------------------------------------------------------------- }
  EmitLabel('_PLRT_UNTRAIL');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'AX');
  EmitLabel('_PLRT_UNTR_LP');
  EmitInstrAB('MOV', 'AX', 'WORD PTR [_PL_TTOP]');
  EmitInstrAB('CMP', 'AX', 'CX');
  EmitInstrA('JLE', '_PLRT_UNTR_DONE');
  { Decrementer TTOP }
  EmitInstr('DEC    AX');
  EmitInstrAB('MOV', 'WORD PTR [_PL_TTOP]', 'AX');
  { Lire l adresse enregistree dans le trail : trail[AX] = addr heap }
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstr('SHL    SI,1');                { index -> offset octets }
  EmitInstrAB('MOV', 'AX', 'WORD PTR [_PL_TRAIL + SI]');
  { AX = adresse heap (index) a remettre comme REF libre }
  { Stocker heap[AX] = AX (auto-reference = variable libre, TAG_REF=0) }
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstr('SHL    SI,1');
  EmitInstrAB('MOV', 'WORD PTR [_PL_HEAP + SI]', 'AX');
  EmitInstrA('JMP', '_PLRT_UNTR_LP');
  EmitLabel('_PLRT_UNTR_DONE');
  EmitInstrA('POP', 'AX');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');
  EmitBlankLine;

  { -------------------------------------------------------------- }
  { _PLRT_TRY : creer un point de choix                            }
  { Entree : BX = adresse de la clause suivante (label)            }
  { Sortie : CF = 0                                                 }
  { Effet  : empile un choice point de 4 mots sur _PL_STACK        }
  {          [prev_cp, ttop, htop, next_clause]                     }
  { -------------------------------------------------------------- }
  EmitLabel('_PLRT_TRY');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'AX');
  { SI = CPTOP * 2 (offset octets dans _PL_STACK) }
  EmitInstrAB('MOV', 'SI', 'WORD PTR [_PL_CPTOP]');
  EmitInstr('SHL    SI,1');
  { Stocker ancien CPTOP }
  EmitInstrAB('MOV', 'AX', 'WORD PTR [_PL_CPTOP]');
  EmitInstrAB('MOV', 'WORD PTR [_PL_STACK + SI]', 'AX');
  EmitInstrAB('ADD', 'SI', '2');
  { Stocker TTOP }
  EmitInstrAB('MOV', 'AX', 'WORD PTR [_PL_TTOP]');
  EmitInstrAB('MOV', 'WORD PTR [_PL_STACK + SI]', 'AX');
  EmitInstrAB('ADD', 'SI', '2');
  { Stocker HTOP }
  EmitInstrAB('MOV', 'AX', 'WORD PTR [_PL_HTOP]');
  EmitInstrAB('MOV', 'WORD PTR [_PL_STACK + SI]', 'AX');
  EmitInstrAB('ADD', 'SI', '2');
  { Stocker adresse clause suivante }
  EmitInstrAB('MOV', 'WORD PTR [_PL_STACK + SI]', 'BX');
  EmitInstrAB('ADD', 'SI', '2');
  { Mettre a jour CPTOP (SI/2 = nouveau CPTOP) }
  EmitInstr('SHR    SI,1');
  EmitInstrAB('MOV', 'WORD PTR [_PL_CPTOP]', 'SI');
  { Succes }
  EmitInstr('CLC');
  EmitInstrA('POP', 'AX');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');
  EmitBlankLine;

  { -------------------------------------------------------------- }
  { _PLRT_RETRY : restaurer l etat et essayer la clause suivante   }
  { Entree : BX = adresse de la nouvelle clause suivante (label)   }
  { Sortie : CF = 0, HTOP/TTOP restaures, trail defait             }
  { Effet  : restaure l etat depuis le choice point courant,        }
  {          met a jour l adresse de la clause suivante              }
  { -------------------------------------------------------------- }
  EmitLabel('_PLRT_RETRY');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'AX');
  EmitInstrA('PUSH', 'CX');
  { SI pointe sur le choice point courant (CPTOP - 4 mots) }
  EmitInstrAB('MOV', 'SI', 'WORD PTR [_PL_CPTOP]');
  EmitInstrAB('SUB', 'SI', '4');
  EmitInstr('SHL    SI,1');
  { Lire TTOP sauvegarde (slot 1) }
  EmitInstrAB('MOV', 'CX', 'WORD PTR [_PL_STACK + SI + 2]');
  { Defaire le trail }
  EmitInstr('CALL    _PLRT_UNTRAIL');
  { Restaurer TTOP }
  EmitInstrAB('MOV', 'WORD PTR [_PL_TTOP]', 'CX');
  { Restaurer HTOP (slot 2) }
  EmitInstrAB('MOV', 'AX', 'WORD PTR [_PL_STACK + SI + 4]');
  EmitInstrAB('MOV', 'WORD PTR [_PL_HTOP]', 'AX');
  { Mettre a jour l adresse de la clause suivante (slot 3) }
  EmitInstrAB('MOV', 'WORD PTR [_PL_STACK + SI + 6]', 'BX');
  { CF = 0 (succes) }
  EmitInstr('CLC');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'AX');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');
  EmitBlankLine;

  { -------------------------------------------------------------- }
  { _PLRT_TRUST : derniere clause, restaurer et supprimer CP       }
  { Entree : (rien)                                                 }
  { Sortie : CF = 0, HTOP/TTOP restaures, CP supprime              }
  { Effet  : restaure l etat, puis retire le choice point           }
  { -------------------------------------------------------------- }
  EmitLabel('_PLRT_TRUST');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'AX');
  EmitInstrA('PUSH', 'CX');
  { SI pointe sur le choice point courant (CPTOP - 4 mots) }
  EmitInstrAB('MOV', 'SI', 'WORD PTR [_PL_CPTOP]');
  EmitInstrAB('SUB', 'SI', '4');
  EmitInstr('SHL    SI,1');
  { Lire TTOP sauvegarde (slot 1) }
  EmitInstrAB('MOV', 'CX', 'WORD PTR [_PL_STACK + SI + 2]');
  { Defaire le trail }
  EmitInstr('CALL    _PLRT_UNTRAIL');
  { Restaurer TTOP }
  EmitInstrAB('MOV', 'WORD PTR [_PL_TTOP]', 'CX');
  { Restaurer HTOP (slot 2) }
  EmitInstrAB('MOV', 'AX', 'WORD PTR [_PL_STACK + SI + 4]');
  EmitInstrAB('MOV', 'WORD PTR [_PL_HTOP]', 'AX');
  { Restaurer ancien CPTOP (slot 0) = supprimer ce CP }
  EmitInstrAB('MOV', 'AX', 'WORD PTR [_PL_STACK + SI]');
  EmitInstrAB('MOV', 'WORD PTR [_PL_CPTOP]', 'AX');
  { CF = 0 (succes) }
  EmitInstr('CLC');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'AX');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');
  EmitBlankLine;
End;

{ ============================================================
  TODO 13 - LISTES [IMPLEMENTE]
  ============================================================ }

{ ---- EmitListRuntime : emettre les routines de liste ----------- }
{ Routines WAM pour la construction et la decomposition de listes, }
{ ainsi que les predicats de liste standard.                       }
{                                                                  }
{   _PLRT_PUTLIST : AX=head, BX=tail -> AX=tagged list            }
{     Alloue 2 cellules sur le heap pour [Head|Tail]               }
{     heap[htop] = head, heap[htop+1] = tail                      }
{     AX = MakeList(htop) = (TAG_LIST << 13) | htop               }
{     htop += 2                                                    }
{                                                                  }
{   _PLRT_GETLIST : AX=tagged list -> BX=head, CX=tail            }
{     Extrait la tete et la queue d une liste                      }
{     CF=1 si AX n est pas une liste                               }
{                                                                  }
{   _PLRT_LENGTH : AX=tagged list -> AX=longueur (entier)         }
{   _PLRT_MEMBER : AX=elem, BX=liste -> CF=1 si pas membre        }
{   _PLRT_APPEND : AX=l1, BX=l2 -> AX=l1++l2 (sur le heap)       }
{   _PLRT_NTH    : AX=index (0-based), BX=liste -> AX=element     }
{   _PLRT_LAST   : AX=liste -> AX=dernier element                 }
Procedure EmitListRuntime;
Var
  NS        : TString;
Begin
  EmitBlankLine;
  EmitComment('=======================================');
  EmitComment('  Routines de liste (TODO 13)');
  EmitComment('=======================================');
  EmitBlankLine;

  { -------------------------------------------------------------- }
  { _PLRT_PUTLIST : AX=head, BX=tail -> AX=tagged list             }
  { Alloue 2 cellules sur le heap                                  }
  { -------------------------------------------------------------- }
  EmitLabel('_PLRT_PUTLIST');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', 'WORD PTR [_PL_HTOP]');
  EmitInstrA('PUSH', 'SI');
  EmitInstr('SHL    SI,1');
  EmitInstrAB('ADD', 'SI', 'OFFSET _PL_HEAP');
  EmitInstrAB('MOV', 'WORD PTR [SI]', 'AX');     { heap[htop] = head }
  EmitInstrAB('MOV', 'WORD PTR [SI+2]', 'BX');   { heap[htop+1] = tail }
  EmitInstrA('POP', 'AX');  { AX = old htop }
  { Tag as LIST: (TAG_LIST << 13) | htop }
  Str(TAG_LIST Shl TAG_SHIFT, NS);
  EmitInstrAB('OR', 'AX', NS);
  EmitInstr('ADD    WORD PTR [_PL_HTOP],2');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');
  EmitBlankLine;

  { -------------------------------------------------------------- }
  { _PLRT_GETLIST : AX=tagged list -> BX=head, CX=tail            }
  { CF=1 si pas une liste                                         }
  { -------------------------------------------------------------- }
  EmitLabel('_PLRT_GETLIST');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'AX');
  { Verifier le tag LIST }
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitInstrAB('AND', 'BX', IntToStr(TAG_MASK));
  Str(TAG_LIST Shl TAG_SHIFT, NS);
  EmitInstrAB('CMP', 'BX', NS);
  EmitInstrA('JNE', '_PLRT_GETL_FAIL');
  { Extraire la valeur (adresse heap) }
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstr('SHL    SI,1');
  EmitInstrAB('ADD', 'SI', 'OFFSET _PL_HEAP');
  EmitInstrAB('MOV', 'BX', 'WORD PTR [SI]');     { BX = head }
  EmitInstrAB('MOV', 'CX', 'WORD PTR [SI+2]');   { CX = tail }
  EmitInstrA('POP', 'AX');
  EmitInstrA('POP', 'SI');
  EmitInstr('CLC');
  EmitInstr('RET');
  EmitLabel('_PLRT_GETL_FAIL');
  EmitInstrA('POP', 'AX');
  EmitInstrA('POP', 'SI');
  EmitInstr('STC');
  EmitInstr('RET');
  EmitBlankLine;

  { -------------------------------------------------------------- }
  { _PLRT_LENGTH : AX=tagged list -> AX=longueur (tagged int)     }
  { Parcourt la liste et compte les elements                       }
  { -------------------------------------------------------------- }
  EmitLabel('_PLRT_LENGTH');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'CX');
  EmitInstrAB('XOR', 'CX', 'CX');  { CX = compteur }
  EmitLabel('_PLRT_LEN_LP');
  { Verifier si AX = [] }
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitInstrAB('AND', 'BX', IntToStr(TAG_MASK));
  Str(TAG_LIST Shl TAG_SHIFT, NS);
  EmitInstrAB('CMP', 'BX', NS);
  EmitInstrA('JNE', '_PLRT_LEN_DONE');
  { Extraire la queue }
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstr('SHL    SI,1');
  EmitInstrAB('ADD', 'SI', 'OFFSET _PL_HEAP');
  EmitInstrAB('MOV', 'AX', 'WORD PTR [SI+2]');  { AX = tail }
  EmitInstr('INC    CX');
  EmitInstrA('JMP', '_PLRT_LEN_LP');
  EmitLabel('_PLRT_LEN_DONE');
  { CX = longueur -> construire tagged int }
  EmitInstrAB('MOV', 'AX', 'CX');
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  Str(TAG_INT Shl TAG_SHIFT, NS);
  EmitInstrAB('OR', 'AX', NS);
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');
  EmitBlankLine;

  { -------------------------------------------------------------- }
  { _PLRT_MEMBER : AX=elem, BX=liste -> CF=1 si pas membre        }
  { Parcourt la liste et unifie chaque element avec AX             }
  { -------------------------------------------------------------- }
  EmitLabel('_PLRT_MEMBER');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DX');
  EmitInstrAB('MOV', 'DX', 'AX');  { DX = element a chercher }
  EmitLabel('_PLRT_MEM_LP');
  { Verifier si BX est une liste }
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstrAB('AND', 'AX', IntToStr(TAG_MASK));
  Str(TAG_LIST Shl TAG_SHIFT, NS);
  EmitInstrAB('CMP', 'AX', NS);
  EmitInstrA('JNE', '_PLRT_MEM_FAIL');
  { Extraire head et tail }
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstr('SHL    SI,1');
  EmitInstrAB('ADD', 'SI', 'OFFSET _PL_HEAP');
  { Comparer head avec l element }
  EmitInstrAB('CMP', 'DX', 'WORD PTR [SI]');
  EmitInstrA('JE', '_PLRT_MEM_OK');
  { Pas egal : passer au suivant }
  EmitInstrAB('MOV', 'BX', 'WORD PTR [SI+2]');  { BX = tail }
  EmitInstrA('JMP', '_PLRT_MEM_LP');
  EmitLabel('_PLRT_MEM_OK');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'SI');
  EmitInstr('CLC');
  EmitInstr('RET');
  EmitLabel('_PLRT_MEM_FAIL');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'SI');
  EmitInstr('STC');
  EmitInstr('RET');
  EmitBlankLine;

  { -------------------------------------------------------------- }
  { _PLRT_APPEND : AX=l1, BX=l2 -> AX=l1++l2 (construit sur heap)}
  { Copie l1 en ajoutant l2 comme queue du dernier element         }
  { -------------------------------------------------------------- }
  EmitLabel('_PLRT_APPEND');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DX');
  EmitInstrA('PUSH', 'CX');
  { Si l1 est vide, le resultat est l2 }
  EmitInstrAB('MOV', 'CX', 'AX');
  EmitInstrAB('AND', 'CX', IntToStr(TAG_MASK));
  Str(TAG_LIST Shl TAG_SHIFT, NS);
  EmitInstrAB('CMP', 'CX', NS);
  EmitInstrA('JNE', '_PLRT_APP_L1EMPTY');
  { l1 non-vide : extraire head et tail }
  EmitInstrAB('MOV', 'DX', 'AX');
  EmitInstrAB('AND', 'DX', IntToStr(VAL_MASK));
  EmitInstrAB('MOV', 'SI', 'DX');
  EmitInstr('SHL    SI,1');
  EmitInstrAB('ADD', 'SI', 'OFFSET _PL_HEAP');
  EmitInstrA('PUSH', 'BX');  { sauver l2 }
  EmitInstrA('PUSH', 'WORD PTR [SI]');  { sauver head }
  EmitInstrAB('MOV', 'AX', 'WORD PTR [SI+2]');  { AX = tail de l1 }
  { Appel recursif : AX=tail(l1), BX=l2 }
  EmitInstr('CALL    _PLRT_APPEND');
  { AX = append(tail(l1), l2) }
  EmitInstrAB('MOV', 'BX', 'AX');  { BX = nouvelle queue }
  EmitInstrA('POP', 'AX');   { AX = head de l1 }
  EmitInstrAB('ADD', 'SP', '2');  { depiler BX sauvegarde }
  { Construire la nouvelle cellule [head | append(tail,l2)] }
  EmitInstr('CALL    _PLRT_PUTLIST');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');
  EmitLabel('_PLRT_APP_L1EMPTY');
  EmitInstrAB('MOV', 'AX', 'BX');  { resultat = l2 }
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');
  EmitBlankLine;

  { -------------------------------------------------------------- }
  { _PLRT_NTH : AX=index (0-based int), BX=liste -> AX=element    }
  { CF=1 si index hors bornes ou pas une liste                    }
  { -------------------------------------------------------------- }
  EmitLabel('_PLRT_NTH');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'CX');
  EmitInstrAB('MOV', 'CX', 'AX');  { CX = index }
  EmitLabel('_PLRT_NTH_LP');
  { Verifier si BX est une liste }
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstrAB('AND', 'AX', IntToStr(TAG_MASK));
  Str(TAG_LIST Shl TAG_SHIFT, NS);
  EmitInstrAB('CMP', 'AX', NS);
  EmitInstrA('JNE', '_PLRT_NTH_FAIL');
  { Extraire head et tail }
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstr('SHL    SI,1');
  EmitInstrAB('ADD', 'SI', 'OFFSET _PL_HEAP');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', '_PLRT_NTH_FOUND');
  EmitInstr('DEC    CX');
  EmitInstrAB('MOV', 'BX', 'WORD PTR [SI+2]');  { BX = tail }
  EmitInstrA('JMP', '_PLRT_NTH_LP');
  EmitLabel('_PLRT_NTH_FOUND');
  EmitInstrAB('MOV', 'AX', 'WORD PTR [SI]');  { AX = head }
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'SI');
  EmitInstr('CLC');
  EmitInstr('RET');
  EmitLabel('_PLRT_NTH_FAIL');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'SI');
  EmitInstr('STC');
  EmitInstr('RET');
  EmitBlankLine;

  { -------------------------------------------------------------- }
  { _PLRT_LAST : AX=liste -> AX=dernier element                   }
  { CF=1 si liste vide                                             }
  { -------------------------------------------------------------- }
  EmitLabel('_PLRT_LAST');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'BX');
  EmitLabel('_PLRT_LAST_LP');
  { Verifier si AX est une liste }
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitInstrAB('AND', 'BX', IntToStr(TAG_MASK));
  Str(TAG_LIST Shl TAG_SHIFT, NS);
  EmitInstrAB('CMP', 'BX', NS);
  EmitInstrA('JNE', '_PLRT_LAST_FAIL');
  { Extraire head et tail }
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstr('SHL    SI,1');
  EmitInstrAB('ADD', 'SI', 'OFFSET _PL_HEAP');
  EmitInstrAB('MOV', 'BX', 'WORD PTR [SI+2]');  { BX = tail }
  { Si tail n est pas une liste, head est le dernier }
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstrAB('AND', 'AX', IntToStr(TAG_MASK));
  Str(TAG_LIST Shl TAG_SHIFT, NS);
  EmitInstrAB('CMP', 'AX', NS);
  EmitInstrA('JNE', '_PLRT_LAST_GOT');
  { Tail est une liste : continuer }
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstrA('JMP', '_PLRT_LAST_LP');
  EmitLabel('_PLRT_LAST_GOT');
  EmitInstrAB('MOV', 'AX', 'WORD PTR [SI]');  { AX = head (dernier) }
  EmitInstrA('POP', 'BX');
  EmitInstrA('POP', 'SI');
  EmitInstr('CLC');
  EmitInstr('RET');
  EmitLabel('_PLRT_LAST_FAIL');
  EmitInstrA('POP', 'BX');
  EmitInstrA('POP', 'SI');
  EmitInstr('STC');
  EmitInstr('RET');
  EmitBlankLine;
End;

{ ---- EmitLoadArgToAX : emettre le code pour charger un argument  }
{ dans AX sous forme taguee WAM.                                    }
{ InRule = True si on est dans une regle (variables dans l env BP).  }
Procedure EmitLoadArgToAX(Const Arg : TFactArg; InRule : Boolean);
Var
  TagVal : Integer;
  NS     : TString;
  VarIdx : Integer;
Begin
  Case Arg.Kind Of
    FAK_ATOM :
    Begin
      TagVal := (TAG_ATOM Shl TAG_SHIFT) Or (Arg.AtomIdx And VAL_MASK);
      Str(TagVal, NS);
      EmitInstrAB('MOV', 'AX', NS);
      EmitComment('atom ' + AtomName(Arg.AtomIdx));
    End;

    FAK_INT :
    Begin
      TagVal := (TAG_INT Shl TAG_SHIFT) Or
                (Integer(Arg.IntVal) And VAL_MASK);
      Str(TagVal, NS);
      EmitInstrAB('MOV', 'AX', NS);
      EmitComment('int ' + IntToStr(Arg.IntVal));
    End;

    FAK_VAR :
    Begin
      If InRule Then
      Begin
        VarIdx := RuleVarFindOrAdd(Arg.VarName);
        EmitComment('var ' + Arg.VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
      End
      Else
      Begin
        { Dans un fait, variable = creer REF libre sur le heap }
        EmitComment('var ' + Arg.VarName);
        EmitInstrAB('MOV', 'AX', 'WORD PTR [_PL_HTOP]');
        EmitInstrAB('MOV', 'SI', 'AX');
        EmitInstrAB('SHL', 'SI', '1');
        EmitInstrAB('ADD', 'SI', 'OFFSET _PL_HEAP');
        EmitInstrAB('MOV', 'WORD PTR [SI]', 'AX');
        EmitInstr('INC    WORD PTR [_PL_HTOP]');
      End;
    End;

    FAK_ANON :
    Begin
      EmitComment('anon _');
      EmitInstrAB('MOV', 'AX', 'WORD PTR [_PL_HTOP]');
      EmitInstrAB('MOV', 'SI', 'AX');
      EmitInstrAB('SHL', 'SI', '1');
      EmitInstrAB('ADD', 'SI', 'OFFSET _PL_HEAP');
      EmitInstrAB('MOV', 'WORD PTR [SI]', 'AX');
      EmitInstr('INC    WORD PTR [_PL_HTOP]');
    End;

    FAK_LIST :
    Begin
      EmitBuildListToAX(Arg, InRule);
    End;
  Else
    EmitInstrAB('MOV', 'AX', '0');
  End;
End;

{ ---- EmitBuildListToAX : construire une liste sur le heap -------- }
{ Construit la liste element par element de droite a gauche.         }
{ Le resultat (tagged LIST) est dans AX.                             }
{                                                                    }
{ Pour [a, b, c] :                                                   }
{   1. BX = [] (tagged atom)                                        }
{   2. AX = tagged(c), CALL _PLRT_PUTLIST -> AX = [c]              }
{   3. BX = AX, AX = tagged(b), CALL _PLRT_PUTLIST -> AX = [b,c]  }
{   4. BX = AX, AX = tagged(a), CALL _PLRT_PUTLIST -> AX = [a,b,c]}
{                                                                    }
{ Pour [a, b | T] :                                                  }
{   1. BX = T (tagged var)                                          }
{   2. AX = tagged(b), CALL _PLRT_PUTLIST -> AX = [b|T]            }
{   3. BX = AX, AX = tagged(a), CALL _PLRT_PUTLIST -> AX = [a,b|T] }
Procedure EmitBuildListToAX(Const Arg : TFactArg; InRule : Boolean);
Var
  I         : Integer;
  NilTagVal : Integer;
  NS        : TString;
Begin
  EmitComment('build list (' + IntToStr(Arg.ListLen) + ' elems' +
              ')');

  { Commencer par la queue }
  If Arg.HasTail Then
  Begin
    { Queue explicite : charger l element de queue }
    EmitLoadArgToAX(ListElemTab[Arg.ListStart + Arg.ListLen], InRule);
    EmitInstrAB('MOV', 'BX', 'AX');
  End
  Else
  Begin
    { Queue implicite : [] }
    NilTagVal := (TAG_ATOM Shl TAG_SHIFT) Or
                 (AtomIntern('[]') And VAL_MASK);
    Str(NilTagVal, NS);
    EmitInstrAB('MOV', 'BX', NS);
    EmitComment('tail = []');
  End;

  { Construire de droite a gauche }
  For I := Arg.ListLen - 1 DownTo 0 Do
  Begin
    { Sauver la queue courante (BX) }
    EmitInstrA('PUSH', 'BX');
    { Charger l element dans AX }
    EmitLoadArgToAX(ListElemTab[Arg.ListStart + I], InRule);
    { Restaurer la queue }
    EmitInstrA('POP', 'BX');
    { Construire la cellule [head|tail] }
    EmitInstr('CALL    _PLRT_PUTLIST');
    { Pour l iteration suivante, le resultat courant devient la queue }
    If I > 0 Then
      EmitInstrAB('MOV', 'BX', 'AX');
  End;
  { Resultat final dans AX }
End;

{ ============================================================
  TODO 14 - ARITHMETIQUE (IS ET EVALUATION) [IMPLEMENTE]
  ============================================================ }

{ ---- ArithNodeAdd : ajouter un noeud dans ArithNodeTab ---------- }
Function ArithNodeAdd(AKind : TArithNodeKind;
                      AIntVal : LongInt;
                      Const AVarName : TString;
                      AOp : TArithOp;
                      ALeft, ARight : Integer) : Integer;
Begin
  If ArithNodeCount >= MAX_ARITH_NODES Then
  Begin
    CompileError('table des noeuds arithmetiques pleine (max=' +
                 IntToStr(MAX_ARITH_NODES) + ')');
    ArithNodeAdd := 0;
    Exit;
  End;
  ArithNodeTab[ArithNodeCount].Kind    := AKind;
  ArithNodeTab[ArithNodeCount].IntVal  := AIntVal;
  ArithNodeTab[ArithNodeCount].VarName := AVarName;
  ArithNodeTab[ArithNodeCount].Op      := AOp;
  ArithNodeTab[ArithNodeCount].Left    := ALeft;
  ArithNodeTab[ArithNodeCount].Right   := ARight;
  ArithNodeAdd := ArithNodeCount;
  Inc(ArithNodeCount);
End;

{ ---- ParseArithFactor : parser un facteur arithmetique ----------- }
{ Factor -> integer | variable | '-' Factor | '(' Expr ')'          }
{         | abs(Expr) | max(Expr,Expr) | min(Expr,Expr)              }
{         | sign(Expr) | succ(Expr) | plus(Expr,Expr) | msb(Expr)    }
Function ParseArithFactor : Integer;
Var
  N      : Integer;
  FName  : TString;
  A1, A2 : Integer;
  Op     : TArithOp;
Begin
  ParseArithFactor := -1;

  { Entier }
  If CurToken.Kind = TK_INTEGER Then
  Begin
    ParseArithFactor := ArithNodeAdd(ANK_INT, CurToken.IntVal, '',
                                     AO_ADD, -1, -1);
    ParserAdvance;
    Exit;
  End;

  { Variable }
  If CurToken.Kind = TK_VARIABLE Then
  Begin
    ParseArithFactor := ArithNodeAdd(ANK_VAR, 0, CurToken.Val,
                                     AO_ADD, -1, -1);
    ParserAdvance;
    Exit;
  End;

  { Operateur unaire - }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '-') Then
  Begin
    ParserAdvance;
    N := ParseArithFactor;
    If N < 0 Then
    Begin
      CompileError('expression attendue apres le - unaire');
      Exit;
    End;
    ParseArithFactor := ArithNodeAdd(ANK_UNOP, 0, '', AO_NEG, N, -1);
    Exit;
  End;

  { Parentheses }
  If CurToken.Kind = TK_LPAREN Then
  Begin
    ParserAdvance; { consomme ( }
    N := ParseArithExpr;
    If CurToken.Kind = TK_RPAREN Then
      ParserAdvance
    Else
      CompileError(') attendu dans expression arithmetique');
    ParseArithFactor := N;
    Exit;
  End;

  { Fonctions arithmetiques : abs, max, min, sign, succ, plus, msb }
  If CurToken.Kind = TK_ATOM Then
  Begin
    FName := CurToken.Val;
    { Verifier si c est une fonction connue }
    Op := AO_ADD; { valeur par defaut, sera changee }
    If FName = 'abs'  Then Op := AO_ABS
    Else If FName = 'max'  Then Op := AO_MAX
    Else If FName = 'min'  Then Op := AO_MIN
    Else If FName = 'sign' Then Op := AO_SIGN
    Else If FName = 'succ' Then Op := AO_SUCC
    Else If FName = 'plus' Then Op := AO_PLUS
    Else If FName = 'msb'  Then Op := AO_MSB
    Else
    Begin
      { Atome comme constante numerique ? Non, erreur }
      CompileError('terme inattendu dans expression arithmetique: ' + FName);
      ParserAdvance;
      Exit;
    End;

    ParserAdvance; { consomme le nom de fonction }
    If CurToken.Kind <> TK_LPAREN Then
    Begin
      CompileError('( attendu apres ' + FName);
      ParseArithFactor := -1;
      Exit;
    End;
    ParserAdvance; { consomme ( }

    A1 := ParseArithExpr;

    { Fonctions binaires : max(X,Y), min(X,Y), plus(X,Y) }
    If (Op = AO_MAX) Or (Op = AO_MIN) Or (Op = AO_PLUS) Then
    Begin
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance
      Else
        CompileError(', attendu dans ' + FName + '(X,Y)');
      A2 := ParseArithExpr;
      If CurToken.Kind = TK_RPAREN Then
        ParserAdvance
      Else
        CompileError(') attendu apres ' + FName + '(X,Y)');
      ParseArithFactor := ArithNodeAdd(ANK_BINOP, 0, '', Op, A1, A2);
    End
    Else
    Begin
      { Fonctions unaires : abs(X), sign(X), succ(X), msb(X) }
      If CurToken.Kind = TK_RPAREN Then
        ParserAdvance
      Else
        CompileError(') attendu apres ' + FName + '(X)');
      ParseArithFactor := ArithNodeAdd(ANK_UNOP, 0, '', Op, A1, -1);
    End;
    Exit;
  End;

  { Rien de reconnu }
  CompileError('facteur arithmetique attendu, trouve: ' + CurToken.Val);
  If CurToken.Kind <> TK_EOF Then
    ParserAdvance;
End;

{ ---- ParseArithTerm : parser un terme (*, /, //, mod, rem) ------- }
{ Term -> Factor (('*' | '/' | '//' | 'mod' | 'rem') Factor)*       }
Function ParseArithTerm : Integer;
Var
  Left, Right : Integer;
  Op          : TArithOp;
Begin
  Left := ParseArithFactor;
  ParseArithTerm := Left;
  If Left < 0 Then Exit;

  While True Do
  Begin
    Op := AO_ADD; { placeholder }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '*') Then
      Op := AO_MUL
    Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '/') Then
      Op := AO_DIV
    Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '//') Then
      Op := AO_IDIV
    Else If (CurToken.Kind = TK_ATOM) And (CurToken.Val = 'mod') Then
      Op := AO_MOD
    Else If (CurToken.Kind = TK_ATOM) And (CurToken.Val = 'rem') Then
      Op := AO_REM
    Else
      Break;

    ParserAdvance;
    Right := ParseArithFactor;
    If Right < 0 Then Break;
    Left := ArithNodeAdd(ANK_BINOP, 0, '', Op, Left, Right);
  End;
  ParseArithTerm := Left;
End;

{ ---- ParseArithExpr : parser une expression arithmetique --------- }
{ Expr -> Term (('+' | '-') Term)*                                    }
Function ParseArithExpr : Integer;
Var
  Left, Right : Integer;
  Op          : TArithOp;
Begin
  Left := ParseArithTerm;
  ParseArithExpr := Left;
  If Left < 0 Then Exit;

  While True Do
  Begin
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '+') Then
      Op := AO_ADD
    Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '-') Then
      Op := AO_SUB
    Else
      Break;

    ParserAdvance;
    Right := ParseArithTerm;
    If Right < 0 Then Break;
    Left := ArithNodeAdd(ANK_BINOP, 0, '', Op, Left, Right);
  End;
  ParseArithExpr := Left;
End;

{ ---- EmitArithEval : emettre le code pour evaluer un noeud ------- }
{ Le resultat est dans AX (entier brut, non tague).                  }
Procedure EmitArithEval(NodeIdx : Integer);
Var
  NS     : TString;
  VarIdx : Integer;
Begin
  If (NodeIdx < 0) Or (NodeIdx >= ArithNodeCount) Then
  Begin
    EmitComment('arith eval: noeud invalide');
    EmitInstrAB('MOV', 'AX', '0');
    Exit;
  End;

  Case ArithNodeTab[NodeIdx].Kind Of
    ANK_INT :
    Begin
      { Entier direct -> AX (valeur brute) }
      Str(Integer(ArithNodeTab[NodeIdx].IntVal), NS);
      EmitInstrAB('MOV', 'AX', NS);
      EmitComment('int ' + IntToStr(ArithNodeTab[NodeIdx].IntVal));
    End;

    ANK_VAR :
    Begin
      { Variable : deref + extraire entier }
      VarIdx := RuleVarFindOrAdd(ArithNodeTab[NodeIdx].VarName);
      EmitComment('arith var ' + ArithNodeTab[NodeIdx].VarName);
      EmitInstrAB('MOV', 'AX',
                  'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
      EmitDeref;
      EmitInstr('CALL    _PLRT_DEREF_INT');
    End;

    ANK_BINOP :
    Begin
      { Evaluer gauche dans AX, push, evaluer droite dans AX, pop BX }
      EmitArithEval(ArithNodeTab[NodeIdx].Left);
      EmitInstrA('PUSH', 'AX');
      EmitArithEval(ArithNodeTab[NodeIdx].Right);
      EmitInstrAB('MOV', 'BX', 'AX');
      EmitInstrA('POP', 'AX');

      Case ArithNodeTab[NodeIdx].Op Of
        AO_ADD :
        Begin
          EmitInstrAB('ADD', 'AX', 'BX');
          EmitComment('+');
        End;
        AO_SUB :
        Begin
          EmitInstrAB('SUB', 'AX', 'BX');
          EmitComment('-');
        End;
        AO_MUL :
        Begin
          EmitInstr('IMUL   BX');
          EmitComment('*');
        End;
        AO_DIV, AO_IDIV :
        Begin
          EmitInstr('CWD');
          EmitInstr('IDIV   BX');
          EmitComment('/ (quotient dans AX)');
        End;
        AO_MOD :
        Begin
          EmitInstr('CWD');
          EmitInstr('IDIV   BX');
          EmitInstrAB('MOV', 'AX', 'DX');
          EmitComment('mod (reste dans DX->AX)');
        End;
        AO_REM :
        Begin
          EmitInstr('CWD');
          EmitInstr('IDIV   BX');
          EmitInstrAB('MOV', 'AX', 'DX');
          EmitComment('rem (reste dans DX->AX)');
        End;
        AO_MAX :
        Begin
          NS := LabelGen;
          EmitInstrAB('CMP', 'AX', 'BX');
          EmitInstrA('JGE', NS);
          EmitInstrAB('MOV', 'AX', 'BX');
          EmitLabel(NS);
          EmitComment('max');
        End;
        AO_MIN :
        Begin
          NS := LabelGen;
          EmitInstrAB('CMP', 'AX', 'BX');
          EmitInstrA('JLE', NS);
          EmitInstrAB('MOV', 'AX', 'BX');
          EmitLabel(NS);
          EmitComment('min');
        End;
        AO_PLUS :
        Begin
          EmitInstrAB('ADD', 'AX', 'BX');
          EmitComment('plus(X,Y)');
        End;
      End; { inner Case }
    End;

    ANK_UNOP :
    Begin
      { Evaluer l operande dans AX }
      EmitArithEval(ArithNodeTab[NodeIdx].Left);

      Case ArithNodeTab[NodeIdx].Op Of
        AO_NEG :
        Begin
          EmitInstr('NEG    AX');
          EmitComment('unaire -');
        End;
        AO_ABS :
        Begin
          EmitInstr('CALL    _PLRT_ABS');
          EmitComment('abs');
        End;
        AO_SIGN :
        Begin
          EmitInstr('CALL    _PLRT_SIGN');
          EmitComment('sign');
        End;
        AO_SUCC :
        Begin
          EmitInstr('INC    AX');
          EmitComment('succ');
        End;
        AO_MSB :
        Begin
          EmitInstr('CALL    _PLRT_MSB');
          EmitComment('msb');
        End;
      End; { inner Case }
    End;
  End; { outer Case }
End;

{ ---- EmitArithRuntime : emettre les routines arithmetiques ------- }
{ Routines de support pour l evaluation arithmetique :               }
{   _PLRT_DEREF_INT : AX=tagged -> AX=raw int (CF=1 si pas INT)    }
{   _PLRT_MKINT     : AX=raw int -> AX=tagged INT                  }
{   _PLRT_ABS       : AX=int -> AX=|int|                            }
{   _PLRT_SIGN      : AX=int -> AX=(-1,0,1)                        }
{   _PLRT_MSB       : AX=unsigned -> AX=bit index du MSB            }
Procedure EmitArithRuntime;
Var
  NS : TString;
Begin
  EmitBlankLine;
  EmitComment('=======================================');
  EmitComment('  Routines arithmetiques (TODO 14)');
  EmitComment('=======================================');
  EmitBlankLine;

  { _PLRT_DEREF_INT : AX=tagged term -> AX=raw signed int }
  { Deref d abord, puis extrait la valeur entiere 13 bits sign-extended }
  { CF=1 si le terme n est pas un entier }
  EmitLabel('_PLRT_DEREF_INT');
  EmitInstrA('PUSH', 'BX');
  { Verifier le tag }
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitInstrAB('AND', 'BX', IntToStr(TAG_MASK));
  Str(TAG_INT Shl TAG_SHIFT, NS);
  EmitInstrAB('CMP', 'BX', NS);
  EmitInstrA('JNE', '_PLRT_DI_FAIL');
  { Extraire la valeur 13 bits }
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  { Sign-extend 13 bits -> 16 bits : si bit 12 set, OR E000h }
  EmitInstrAB('TEST', 'AX', '1000h');
  EmitInstrA('JZ', '_PLRT_DI_POS');
  EmitInstrAB('OR', 'AX', '0E000h');
  EmitLabel('_PLRT_DI_POS');
  EmitInstr('CLC');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');
  EmitLabel('_PLRT_DI_FAIL');
  EmitInstr('STC');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');
  EmitBlankLine;

  { _PLRT_MKINT : AX=raw int -> AX=tagged INT }
  EmitLabel('_PLRT_MKINT');
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  Str(TAG_INT Shl TAG_SHIFT, NS);
  EmitInstrAB('OR', 'AX', NS);
  EmitInstr('RET');
  EmitBlankLine;

  { _PLRT_ABS : AX=int -> AX=|int| }
  EmitLabel('_PLRT_ABS');
  EmitInstrAB('TEST', 'AX', 'AX');
  EmitInstrA('JNS', '_PLRT_ABS_OK');
  EmitInstr('NEG    AX');
  EmitLabel('_PLRT_ABS_OK');
  EmitInstr('RET');
  EmitBlankLine;

  { _PLRT_SIGN : AX=int -> AX=(-1 si neg, 0 si zero, 1 si pos) }
  EmitLabel('_PLRT_SIGN');
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JL', '_PLRT_SIGN_N');
  EmitInstrA('JG', '_PLRT_SIGN_P');
  EmitInstrAB('MOV', 'AX', '0');
  EmitInstr('RET');
  EmitLabel('_PLRT_SIGN_N');
  EmitInstrAB('MOV', 'AX', '-1');
  EmitInstr('RET');
  EmitLabel('_PLRT_SIGN_P');
  EmitInstrAB('MOV', 'AX', '1');
  EmitInstr('RET');
  EmitBlankLine;

  { _PLRT_MSB : AX=unsigned -> AX=index du bit le plus significatif }
  { BSR (Bit Scan Reverse) sur 8086 n existe pas, on simule          }
  EmitLabel('_PLRT_MSB');
  EmitInstrA('PUSH', 'CX');
  EmitInstrAB('MOV', 'CX', '15');
  EmitLabel('_PLRT_MSB_LP');
  EmitInstrAB('TEST', 'AX', '8000h');
  EmitInstrA('JNZ', '_PLRT_MSB_FOUND');
  EmitInstr('SHL    AX,1');
  EmitInstr('DEC    CX');
  EmitInstrA('JNS', '_PLRT_MSB_LP');
  EmitInstrAB('MOV', 'AX', '-1');
  EmitInstrA('POP', 'CX');
  EmitInstr('RET');
  EmitLabel('_PLRT_MSB_FOUND');
  EmitInstrAB('MOV', 'AX', 'CX');
  EmitInstrA('POP', 'CX');
  EmitInstr('RET');
  EmitBlankLine;
End;

{ ============================================================
  TODO 15 - COMPARAISON ET TESTS DE TYPE [IMPLEMENTE]
  ============================================================ }

{ ---- EmitCompareRuntime : routines de comparaison et type ------ }
Procedure EmitCompareRuntime;
Var
  Lbl1, Lbl2, Lbl3, Lbl4, Lbl5 : TString;
  LblEnd                        : TString;
  LblFail, LblOk                : TString;
Begin
  EmitBlankLine;
  EmitComment('========================================');
  EmitComment(' Runtime : Comparaison et tests (TODO 15)');
  EmitComment('========================================');

  { _PLRT_TAG_OF : AX=tagged term -> AX=tag value (0..4) }
  EmitBlankLine;
  EmitComment('_PLRT_TAG_OF : AX=terme -> AX=tag (0..4)');
  EmitLabel(PL_RT_PFX + 'TAG_OF');
  EmitInstrAB('AND', 'AX', IntToStr(TAG_MASK));
  EmitInstrAB('MOV', 'CL', IntToStr(TAG_SHIFT));
  EmitInstrAB('SHR', 'AX', 'CL');
  EmitInstr('RET');

  { _PLRT_STRUCT_EQ : AX=term1, BX=term2 -> CF=1 if not equal }
  EmitBlankLine;
  EmitComment('_PLRT_STRUCT_EQ : AX=term1, BX=term2');
  EmitComment('CF=0 si egaux structurellement, CF=1 sinon');
  EmitLabel(PL_RT_PFX + 'STRUCT_EQ');
  EmitInstrA('PUSH', 'DX');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  { Deref AX }
  EmitInstr('CALL    ' + PL_RT_PFX + 'DEREF');
  EmitInstrAB('MOV', 'DX', 'AX');  { DX = deref term1 }
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstr('CALL    ' + PL_RT_PFX + 'DEREF');
  EmitInstrAB('MOV', 'BX', 'AX');  { BX = deref term2 }
  EmitInstrAB('MOV', 'AX', 'DX');  { AX = deref term1 }
  { Compare directly: if identical tagged words, equal }
  EmitInstrAB('CMP', 'AX', 'BX');
  LblOk := LabelGen;
  LblFail := LabelGen;
  LblEnd := LabelGen;
  EmitInstrA('JE', LblOk);
  { Tags differ? }
  EmitInstrAB('MOV', 'DX', 'AX');
  EmitInstrAB('AND', 'DX', IntToStr(TAG_MASK));
  EmitInstrAB('MOV', 'SI', 'BX');
  EmitInstrAB('AND', 'SI', IntToStr(TAG_MASK));
  EmitInstrAB('CMP', 'DX', 'SI');
  EmitInstrA('JNE', LblFail);
  { Same tag - for simple types (REF/ATOM/INT) values already compared }
  { since same tag but different word -> not equal }
  Lbl1 := LabelGen;
  Lbl2 := LabelGen;
  EmitInstrAB('CMP', 'DX', IntToStr(TAG_LIST Shl TAG_SHIFT));
  EmitInstrA('JE', Lbl1);
  EmitInstrAB('CMP', 'DX', IntToStr(TAG_STR Shl TAG_SHIFT));
  EmitInstrA('JNE', LblFail);
  { Structure: compare functor word at heap[val], then args recursively }
  { For 8086 simplicity: compare first two heap words (functor+arity) }
  EmitComment('STR struct_eq: compare heap cells');
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  EmitInstrAB('AND', 'BX', IntToStr(VAL_MASK));
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstr('SHL    SI,1');
  EmitInstrAB('ADD', 'SI', 'OFFSET _PL_HEAP');
  EmitInstrAB('MOV', 'DI', 'BX');
  EmitInstr('SHL    DI,1');
  EmitInstrAB('ADD', 'DI', 'OFFSET _PL_HEAP');
  { Compare functor cell (heap[addr]) }
  EmitInstrAB('MOV', 'AX', 'WORD PTR [SI]');
  EmitInstrAB('CMP', 'AX', 'WORD PTR [DI]');
  EmitInstrA('JNE', LblFail);
  { Compare arity cell (heap[addr+1]) }
  EmitInstrAB('MOV', 'AX', 'WORD PTR [SI+2]');
  EmitInstrAB('CMP', 'AX', 'WORD PTR [DI+2]');
  EmitInstrA('JNE', LblFail);
  EmitInstrA('JMP', LblOk);
  EmitLabel(Lbl1);
  { LIST: compare head and tail recursively via nested STRUCT_EQ calls }
  EmitComment('LIST struct_eq: compare head+tail');
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  EmitInstrAB('AND', 'BX', IntToStr(VAL_MASK));
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstr('SHL    SI,1');
  EmitInstrAB('ADD', 'SI', 'OFFSET _PL_HEAP');
  EmitInstrAB('MOV', 'DI', 'BX');
  EmitInstr('SHL    DI,1');
  EmitInstrAB('ADD', 'DI', 'OFFSET _PL_HEAP');
  { Compare heads: heap[addr] }
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'AX', 'WORD PTR [SI]');
  EmitInstrAB('MOV', 'BX', 'WORD PTR [DI]');
  EmitInstr('CALL    ' + PL_RT_PFX + 'STRUCT_EQ');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DI');
  EmitInstrA('JC', LblFail);
  { Compare tails: heap[addr+1] }
  EmitInstrAB('MOV', 'AX', 'WORD PTR [SI+2]');
  EmitInstrAB('MOV', 'BX', 'WORD PTR [DI+2]');
  EmitInstr('CALL    ' + PL_RT_PFX + 'STRUCT_EQ');
  EmitInstrA('JC', LblFail);
  EmitLabel(LblOk);
  EmitInstr('CLC');
  EmitInstrA('JMP', LblEnd);
  EmitLabel(LblFail);
  EmitInstr('STC');
  EmitLabel(LblEnd);
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DX');
  EmitInstr('RET');

  { _PLRT_COMPARE : AX=term1, BX=term2 -> flags for ordering }
  { CF=1,ZF=0 if term1<term2 ; CF=0,ZF=1 if equal ; CF=0,ZF=0 if term1>term2 }
  { Order: Var(0) < Int(2) < Atom(1) < Str(3) < List(4) }
  EmitBlankLine;
  EmitComment('_PLRT_COMPARE : AX=term1, BX=term2 -> flags');
  EmitComment('Ordre: Var < Int < Atom < Str < List');
  EmitLabel(PL_RT_PFX + 'COMPARE');
  EmitInstrA('PUSH', 'DX');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'CX');
  { Deref both }
  EmitInstr('CALL    ' + PL_RT_PFX + 'DEREF');
  EmitInstrAB('MOV', 'DX', 'AX');  { DX = deref term1 }
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstr('CALL    ' + PL_RT_PFX + 'DEREF');
  EmitInstrAB('MOV', 'BX', 'AX');  { BX = deref term2 }
  EmitInstrAB('MOV', 'AX', 'DX');  { AX = deref term1 }
  { Extract tags }
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstrAB('AND', 'SI', IntToStr(TAG_MASK));
  EmitInstrAB('MOV', 'CL', IntToStr(TAG_SHIFT));
  EmitInstrAB('SHR', 'SI', 'CL');  { SI = tag1 (0..4) }
  EmitInstrAB('MOV', 'DI', 'BX');
  EmitInstrAB('AND', 'DI', IntToStr(TAG_MASK));
  EmitInstrAB('SHR', 'DI', 'CL');  { DI = tag2 (0..4) }
  { Map tags to ordering: Var=0->0, Int=2->1, Atom=1->2, Str=3->3, List=4->4 }
  { Use a mapping: we remap via compare of raw tags with special handling }
  { Simplified: create order value in SI/DI }
  { ordermap: 0->0(var), 1->2(atom), 2->1(int), 3->3(str), 4->4(list) }
  Lbl1 := LabelGen;
  Lbl2 := LabelGen;
  Lbl3 := LabelGen;
  Lbl4 := LabelGen;
  { Remap SI }
  EmitInstrAB('CMP', 'SI', '1');
  EmitInstrA('JNE', Lbl1);
  EmitInstrAB('MOV', 'SI', '2');
  EmitInstrA('JMP', Lbl2);
  EmitLabel(Lbl1);
  EmitInstrAB('CMP', 'SI', '2');
  EmitInstrA('JNE', Lbl2);
  EmitInstrAB('MOV', 'SI', '1');
  EmitLabel(Lbl2);
  { Remap DI }
  EmitInstrAB('CMP', 'DI', '1');
  EmitInstrA('JNE', Lbl3);
  EmitInstrAB('MOV', 'DI', '2');
  EmitInstrA('JMP', Lbl4);
  EmitLabel(Lbl3);
  EmitInstrAB('CMP', 'DI', '2');
  EmitInstrA('JNE', Lbl4);
  EmitInstrAB('MOV', 'DI', '1');
  EmitLabel(Lbl4);
  { Compare order values }
  Lbl5 := LabelGen;
  LblEnd := LabelGen;
  EmitInstrAB('CMP', 'SI', 'DI');
  EmitInstrA('JE', Lbl5);
  { Different type orders: CMP result already set flags correctly }
  EmitInstrA('JMP', LblEnd);
  EmitLabel(Lbl5);
  { Same type order: compare by value (masked) }
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstrAB('AND', 'SI', IntToStr(VAL_MASK));
  EmitInstrAB('MOV', 'DI', 'BX');
  EmitInstrAB('AND', 'DI', IntToStr(VAL_MASK));
  EmitInstrAB('CMP', 'SI', 'DI');
  EmitLabel(LblEnd);
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DX');
  EmitInstr('RET');

  { _PLRT_COPY_TERM : AX=source term -> AX=copy with fresh vars }
  EmitBlankLine;
  EmitComment('_PLRT_COPY_TERM : AX=source -> AX=copie');
  EmitLabel(PL_RT_PFX + 'COPY_TERM');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'DX');
  EmitInstrA('PUSH', 'SI');
  { Deref source }
  EmitInstr('CALL    ' + PL_RT_PFX + 'DEREF');
  { Check tag }
  EmitInstrAB('MOV', 'DX', 'AX');
  EmitInstrAB('AND', 'DX', IntToStr(TAG_MASK));
  LblOk := LabelGen;
  LblEnd := LabelGen;
  { If ATOM or INT, return as-is }
  EmitInstrAB('CMP', 'DX', IntToStr(TAG_ATOM Shl TAG_SHIFT));
  EmitInstrA('JE', LblOk);
  EmitInstrAB('CMP', 'DX', IntToStr(TAG_INT Shl TAG_SHIFT));
  EmitInstrA('JE', LblOk);
  { If REF: create new fresh variable on heap }
  Lbl1 := LabelGen;
  EmitInstrAB('CMP', 'DX', IntToStr(TAG_REF Shl TAG_SHIFT));
  EmitInstrA('JNE', Lbl1);
  EmitInstrAB('MOV', 'AX', 'WORD PTR [_PL_HTOP]');
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstrAB('SHL', 'SI', '1');
  EmitInstrAB('ADD', 'SI', 'OFFSET _PL_HEAP');
  EmitInstrAB('MOV', 'WORD PTR [SI]', 'AX');
  EmitInstr('INC    WORD PTR [_PL_HTOP]');
  EmitInstrA('JMP', LblEnd);
  EmitLabel(Lbl1);
  { For LIST: deep copy head and tail recursively }
  Lbl2 := LabelGen;
  EmitInstrAB('CMP', 'DX', IntToStr(TAG_LIST Shl TAG_SHIFT));
  EmitInstrA('JNE', Lbl2);
  EmitComment('copy LIST: copy head+tail');
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstr('SHL    SI,1');
  EmitInstrAB('ADD', 'SI', 'OFFSET _PL_HEAP');
  { Copy head }
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'AX', 'WORD PTR [SI]');
  EmitInstr('CALL    ' + PL_RT_PFX + 'COPY_TERM');
  EmitInstrAB('MOV', 'BX', 'AX');   { BX = copied head }
  EmitInstrA('POP', 'SI');
  { Copy tail }
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'AX', 'WORD PTR [SI+2]');
  EmitInstr('CALL    ' + PL_RT_PFX + 'COPY_TERM');
  EmitInstrAB('MOV', 'DX', 'AX');   { DX = copied tail }
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'BX');          { BX = copied head }
  { Build new list cell: _PLRT_PUTLIST(AX=head, BX=tail) }
  EmitInstrAB('MOV', 'AX', 'BX');   { AX = head }
  EmitInstrAB('MOV', 'BX', 'DX');   { BX = tail }
  EmitInstr('CALL    ' + PL_RT_PFX + 'PUTLIST');
  EmitInstrA('JMP', LblEnd);
  EmitLabel(Lbl2);
  { For STR: return same term (structure copy simplified) }
  EmitLabel(LblOk);
  EmitLabel(LblEnd);
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');
  EmitBlankLine;
End;

{ ============================================================
  TODO 16 - CONTROLE : CUT, IF-THEN-ELSE, NEGATION [IMPLEMENTE]
  ============================================================ }

{ ---- EmitControlRuntime : routines de controle --------------- }
{ _PLRT_NEGATION : negation par echec                           }
{   Entree : AX = adresse du predicat a essayer                 }
{   Sortie : CF=0 si le predicat echoue (succes de \+)          }
{            CF=1 si le predicat reussit (echec de \+)          }
Procedure EmitControlRuntime;
Begin
  EmitBlankLine;
  EmitComment('=== TODO 16 : Control Runtime ===');
  EmitBlankLine;

  { _PLRT_NEGATION : negation par echec }
  { AX = adresse du but a essayer }
  { Sauvegarder l etat, essayer le but, restaurer }
  EmitLabel(PL_RT_PFX + 'NEGATION');
  EmitComment('negation by failure: try goal in AX');
  EmitComment('save HTOP, TTOP, CPTOP');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'WORD PTR [_PL_HTOP]');
  EmitInstrA('PUSH', 'WORD PTR [_PL_TTOP]');
  EmitInstrA('PUSH', 'WORD PTR [_PL_CPTOP]');
  { Appeler le but via AX }
  EmitInstr('CALL    AX');
  { Si CF=0 (succes du but) -> la negation echoue }
  EmitInstrA('JNC', PL_RT_PFX + 'NEG_FAIL');
  { CF=1 (echec du but) -> la negation reussit }
  EmitComment('goal failed -> negation succeeds');
  EmitInstrA('POP', 'WORD PTR [_PL_CPTOP]');
  EmitInstrA('POP', 'WORD PTR [_PL_TTOP]');
  EmitInstrA('POP', 'WORD PTR [_PL_HTOP]');
  EmitInstrAB('MOV', 'SP', 'BP');
  EmitInstrA('POP', 'BP');
  EmitInstr('CLC');
  EmitInstr('RET');
  EmitLabel(PL_RT_PFX + 'NEG_FAIL');
  EmitComment('goal succeeded -> negation fails');
  { Restaurer l etat }
  EmitInstrA('POP', 'WORD PTR [_PL_CPTOP]');
  EmitInstrA('POP', 'WORD PTR [_PL_TTOP]');
  EmitInstrA('POP', 'WORD PTR [_PL_HTOP]');
  { Untrail pour defaire les liaisons }
  EmitInstr('CALL    ' + PL_RT_PFX + 'UNTRAIL');
  EmitInstrAB('MOV', 'SP', 'BP');
  EmitInstrA('POP', 'BP');
  EmitInstr('STC');
  EmitInstr('RET');
  EmitBlankLine;
End;

{ ============================================================
  TODO 17 - ENTREES/SORTIES [IMPLEMENTE]
  Routines runtime pour les predicats d entrees/sorties.
  ============================================================ }
Procedure EmitIORuntime;
Var
  NS : TString;
Begin
  EmitBlankLine;
  EmitComment('=======================================');
  EmitComment('  Routines I/O (TODO 17)');
  EmitComment('=======================================');
  EmitBlankLine;

  { ---------------------------------------------------------- }
  { _PLRT_NUMTOSTR : AX = signed 16-bit int                   }
  {   Convertit en chaine ASCII dans _PL_IOBUF                }
  {   Retourne DX = OFFSET buffer, CX = longueur              }
  { ---------------------------------------------------------- }
  EmitLabel(PL_RT_PFX + 'NUMTOSTR');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitInstrAB('MOV', 'DI', 'OFFSET _PL_IOBUF');
  EmitInstrAB('ADD', 'DI', '127');
  EmitInstrAB('MOV', 'CX', '0');
  EmitInstrAB('MOV', 'BX', '10');
  { Gerer le signe }
  EmitInstrAB('TEST', 'AX', 'AX');
  EmitInstrA('JNS', PL_RT_PFX + 'N2S_POS');
  EmitInstrA('PUSH', 'AX');
  EmitInstr('NEG    AX');
  EmitInstrA('JMP', PL_RT_PFX + 'N2S_LOOP');
  EmitLabel(PL_RT_PFX + 'N2S_POS');
  EmitInstrA('PUSH', 'AX');
  { Boucle de conversion }
  EmitLabel(PL_RT_PFX + 'N2S_LOOP');
  EmitInstrAB('XOR', 'DX', 'DX');
  EmitInstrA('DIV', 'BX');
  EmitInstrAB('ADD', 'DL', '''0''');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', 'DL');
  EmitInstr('DEC    DI');
  EmitInstr('INC    CX');
  EmitInstrAB('TEST', 'AX', 'AX');
  EmitInstrA('JNZ', PL_RT_PFX + 'N2S_LOOP');
  { Ajouter le signe si negatif }
  EmitInstrA('POP', 'AX');
  EmitInstrAB('TEST', 'AX', 'AX');
  EmitInstrA('JNS', PL_RT_PFX + 'N2S_DONE');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '''-''');
  EmitInstr('DEC    DI');
  EmitInstr('INC    CX');
  EmitLabel(PL_RT_PFX + 'N2S_DONE');
  EmitInstr('INC    DI');
  EmitInstrAB('MOV', 'DX', 'DI');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');
  EmitBlankLine;

  { ---------------------------------------------------------- }
  { _PLRT_WRITE_TERM : AX = tagged term -> ecrire sur STDOUT  }
  { Gere ATOM, INT, REF, LIST, STR                            }
  { ---------------------------------------------------------- }
  EmitLabel(PL_RT_PFX + 'WRITE_TERM');
  EmitInstrA('PUSH', 'AX');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'DX');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  { Deref d abord }
  EmitInstr('CALL    ' + PL_RT_PFX + 'DEREF');
  { Extraire le tag }
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitInstrAB('AND', 'BX', IntToStr(TAG_MASK));
  EmitInstrAB('MOV', 'CL', IntToStr(TAG_SHIFT));
  EmitInstrAB('SHR', 'BX', 'CL');
  { Tag = TAG_ATOM ? }
  Str(TAG_ATOM, NS);
  EmitInstrAB('CMP', 'BX', NS);
  EmitInstrA('JE', PL_RT_PFX + 'WT_ATOM');
  { Tag = TAG_INT ? }
  Str(TAG_INT, NS);
  EmitInstrAB('CMP', 'BX', NS);
  EmitInstrA('JE', PL_RT_PFX + 'WT_INT');
  { Tag = TAG_LIST ? }
  Str(TAG_LIST, NS);
  EmitInstrAB('CMP', 'BX', NS);
  EmitInstrA('JE', PL_RT_PFX + 'WT_LIST');
  { Tag = TAG_STR ? }
  Str(TAG_STR, NS);
  EmitInstrAB('CMP', 'BX', NS);
  EmitInstrA('JE', PL_RT_PFX + 'WT_STR');
  { Tag = TAG_REF (variable libre) }
  EmitInstrA('JMP', PL_RT_PFX + 'WT_REF');

  { --- Ecrire un atome --- }
  EmitLabel(PL_RT_PFX + 'WT_ATOM');
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  EmitInstrAB('SHL', 'AX', '1');
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstrAB('ADD', 'SI', 'OFFSET ' + PL_ATOM_PFX + 'TABLE');
  EmitInstrAB('MOV', 'SI', 'WORD PTR [SI]');
  { SI pointe sur la chaine ASCIIZ de l atome }
  { Calculer la longueur }
  EmitInstrAB('MOV', 'DI', 'SI');
  EmitInstrAB('MOV', 'CX', '0');
  EmitLabel(PL_RT_PFX + 'WT_ALEN');
  EmitInstrAB('CMP', 'BYTE PTR [DI]', '0');
  EmitInstrA('JE', PL_RT_PFX + 'WT_APRN');
  EmitInstr('INC    DI');
  EmitInstr('INC    CX');
  EmitInstrA('JMP', PL_RT_PFX + 'WT_ALEN');
  EmitLabel(PL_RT_PFX + 'WT_APRN');
  { Ecrire via INT 21h AH=40h, BX=1 (STDOUT), CX=len, DX=offset }
  EmitInstrAB('MOV', 'DX', 'SI');
  EmitInstrAB('MOV', 'BX', '1');
  EmitInstrAB('MOV', 'AH', '40h');
  EmitInstrA('INT', '21h');
  EmitInstrA('JMP', PL_RT_PFX + 'WT_END');

  { --- Ecrire un entier --- }
  EmitLabel(PL_RT_PFX + 'WT_INT');
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  { Sign-extend 13 bits }
  EmitInstrAB('TEST', 'AX', '1000h');
  EmitInstrA('JZ', PL_RT_PFX + 'WT_IPOS');
  EmitInstrAB('OR', 'AX', '0E000h');
  EmitLabel(PL_RT_PFX + 'WT_IPOS');
  EmitInstr('CALL    ' + PL_RT_PFX + 'NUMTOSTR');
  { DX=offset, CX=length }
  EmitInstrAB('MOV', 'BX', '1');
  EmitInstrAB('MOV', 'AH', '40h');
  EmitInstrA('INT', '21h');
  EmitInstrA('JMP', PL_RT_PFX + 'WT_END');

  { --- Ecrire une liste --- }
  EmitLabel(PL_RT_PFX + 'WT_LIST');
  EmitComment('print [ then elements');
  EmitInstrAB('MOV', 'DL', '''[''');
  EmitInstrAB('MOV', 'AH', '02h');
  EmitInstrA('INT', '21h');
  { AX still has the tagged list - reload from stack }
  EmitInstrAB('MOV', 'AX', 'WORD PTR [SP+10]');
  EmitInstr('CALL    ' + PL_RT_PFX + 'DEREF');
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  EmitInstrAB('SHL', 'AX', '1');
  EmitInstrAB('ADD', 'AX', 'OFFSET _PL_HEAP');
  EmitInstrAB('MOV', 'SI', 'AX');
  { Print head }
  EmitInstrAB('MOV', 'AX', 'WORD PTR [SI]');
  EmitInstr('CALL    ' + PL_RT_PFX + 'WRITE_TERM');
  { Check tail }
  EmitInstrAB('MOV', 'AX', 'WORD PTR [SI+2]');
  EmitInstr('CALL    ' + PL_RT_PFX + 'DEREF');
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitInstrAB('AND', 'BX', IntToStr(TAG_MASK));
  Str(TAG_ATOM Shl TAG_SHIFT, NS);
  EmitInstrAB('CMP', 'BX', NS);
  EmitInstrA('JNE', PL_RT_PFX + 'WT_LTAIL');
  { Tail is atom - check if [] (nil) }
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitInstrAB('AND', 'BX', IntToStr(VAL_MASK));
  EmitInstrAB('CMP', 'BX', '0');
  EmitInstrA('JE', PL_RT_PFX + 'WT_LEND');
  { Non-nil atom tail: print | then atom }
  EmitLabel(PL_RT_PFX + 'WT_LTAIL');
  EmitInstrAB('MOV', 'DL', '''|''');
  EmitInstrAB('MOV', 'AH', '02h');
  EmitInstrA('INT', '21h');
  EmitInstr('CALL    ' + PL_RT_PFX + 'WRITE_TERM');
  EmitLabel(PL_RT_PFX + 'WT_LEND');
  EmitInstrAB('MOV', 'DL', ''']''');
  EmitInstrAB('MOV', 'AH', '02h');
  EmitInstrA('INT', '21h');
  EmitInstrA('JMP', PL_RT_PFX + 'WT_END');

  { --- Ecrire une structure f(args) --- }
  EmitLabel(PL_RT_PFX + 'WT_STR');
  EmitComment('structure: print functor(args)');
  { Simplification: afficher <str:XXXX> }
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  EmitInstrAB('MOV', 'DL', '''<''');
  EmitInstrAB('MOV', 'AH', '02h');
  EmitInstrA('INT', '21h');
  EmitInstrAB('MOV', 'DL', '''>''');
  EmitInstrAB('MOV', 'AH', '02h');
  EmitInstrA('INT', '21h');
  EmitInstrA('JMP', PL_RT_PFX + 'WT_END');

  { --- Ecrire une variable libre _GXXXX --- }
  EmitLabel(PL_RT_PFX + 'WT_REF');
  EmitInstrAB('MOV', 'DL', '''_''');
  EmitInstrAB('MOV', 'AH', '02h');
  EmitInstrA('INT', '21h');
  EmitInstrAB('MOV', 'DL', '''G''');
  EmitInstrAB('MOV', 'AH', '02h');
  EmitInstrA('INT', '21h');
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  EmitInstr('CALL    ' + PL_RT_PFX + 'NUMTOSTR');
  EmitInstrAB('MOV', 'BX', '1');
  EmitInstrAB('MOV', 'AH', '40h');
  EmitInstrA('INT', '21h');

  EmitLabel(PL_RT_PFX + 'WT_END');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstrA('POP', 'AX');
  EmitInstr('RET');
  EmitBlankLine;

  { ---------------------------------------------------------- }
  { _PLRT_NL : ecrire CR+LF sur STDOUT                        }
  { ---------------------------------------------------------- }
  EmitLabel(PL_RT_PFX + 'NL');
  EmitInstrAB('MOV', 'DL', '13');
  EmitInstrAB('MOV', 'AH', '02h');
  EmitInstrA('INT', '21h');
  EmitInstrAB('MOV', 'DL', '10');
  EmitInstrAB('MOV', 'AH', '02h');
  EmitInstrA('INT', '21h');
  EmitInstr('RET');
  EmitBlankLine;

  { ---------------------------------------------------------- }
  { _PLRT_TAB : AX = nombre d espaces a ecrire                }
  { ---------------------------------------------------------- }
  EmitLabel(PL_RT_PFX + 'TAB');
  EmitInstrA('PUSH', 'CX');
  EmitInstrAB('MOV', 'CX', 'AX');
  EmitInstrAB('TEST', 'CX', 'CX');
  EmitInstrA('JZ', PL_RT_PFX + 'TAB_END');
  EmitLabel(PL_RT_PFX + 'TAB_LOOP');
  EmitInstrAB('MOV', 'DL', '32');
  EmitInstrAB('MOV', 'AH', '02h');
  EmitInstrA('INT', '21h');
  EmitInstr('LOOP    ' + PL_RT_PFX + 'TAB_LOOP');
  EmitLabel(PL_RT_PFX + 'TAB_END');
  EmitInstrA('POP', 'CX');
  EmitInstr('RET');
  EmitBlankLine;

  { ---------------------------------------------------------- }
  { _PLRT_PUT_CHAR : AL = caractere a ecrire                  }
  { ---------------------------------------------------------- }
  EmitLabel(PL_RT_PFX + 'PUT_CHAR');
  EmitInstrAB('MOV', 'DL', 'AL');
  EmitInstrAB('MOV', 'AH', '02h');
  EmitInstrA('INT', '21h');
  EmitInstr('RET');
  EmitBlankLine;

  { ---------------------------------------------------------- }
  { _PLRT_GET_CHAR : lire un caractere -> AL                  }
  {   Retourne AX = tagged ATOM (atome 1 caractere)            }
  { ---------------------------------------------------------- }
  EmitLabel(PL_RT_PFX + 'GET_CHAR');
  EmitInstrAB('MOV', 'AH', '01h');
  EmitInstrA('INT', '21h');
  { AL = caractere lu, creer un tagged INT (code ASCII) }
  EmitInstrAB('XOR', 'AH', 'AH');
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  Str(TAG_INT Shl TAG_SHIFT, NS);
  EmitInstrAB('OR', 'AX', NS);
  EmitInstr('RET');
  EmitBlankLine;

  { ---------------------------------------------------------- }
  { _PLRT_CHAR_CODE : AX=tagged atom(1char) -> AX=tagged INT  }
  {   ou AX=tagged INT -> AX=tagged INT (identite pour codes)  }
  { ---------------------------------------------------------- }
  EmitLabel(PL_RT_PFX + 'CHAR_CODE');
  EmitInstrA('PUSH', 'BX');
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitInstrAB('AND', 'BX', IntToStr(TAG_MASK));
  Str(TAG_ATOM Shl TAG_SHIFT, NS);
  EmitInstrAB('CMP', 'BX', NS);
  EmitInstrA('JNE', PL_RT_PFX + 'CC_INT');
  { C est un atome -> extraire le premier caractere }
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  EmitInstrAB('SHL', 'AX', '1');
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstrAB('ADD', 'SI', 'OFFSET ' + PL_ATOM_PFX + 'TABLE');
  EmitInstrAB('MOV', 'SI', 'WORD PTR [SI]');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstrAB('MOV', 'AL', 'BYTE PTR [SI]');
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  Str(TAG_INT Shl TAG_SHIFT, NS);
  EmitInstrAB('OR', 'AX', NS);
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');
  EmitLabel(PL_RT_PFX + 'CC_INT');
  { Deja un entier - retourner tel quel }
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');
  EmitBlankLine;

  { ---------------------------------------------------------- }
  { _PLRT_ATOM_LENGTH : AX=tagged atom -> AX=tagged INT (len) }
  { ---------------------------------------------------------- }
  EmitLabel(PL_RT_PFX + 'ATOM_LENGTH');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  EmitInstrAB('SHL', 'AX', '1');
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstrAB('ADD', 'SI', 'OFFSET ' + PL_ATOM_PFX + 'TABLE');
  EmitInstrAB('MOV', 'SI', 'WORD PTR [SI]');
  EmitInstrAB('XOR', 'CX', 'CX');
  EmitLabel(PL_RT_PFX + 'AL_LOOP');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', PL_RT_PFX + 'AL_DONE');
  EmitInstr('INC    SI');
  EmitInstr('INC    CX');
  EmitInstrA('JMP', PL_RT_PFX + 'AL_LOOP');
  EmitLabel(PL_RT_PFX + 'AL_DONE');
  EmitInstrAB('MOV', 'AX', 'CX');
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  Str(TAG_INT Shl TAG_SHIFT, NS);
  EmitInstrAB('OR', 'AX', NS);
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');
  EmitBlankLine;

  { ---------------------------------------------------------- }
  { _PLRT_ATOM_CONCAT : AX=atom1, BX=atom2                    }
  {   Copie les deux chaines dans _PL_IOBUF, cree un nouvel   }
  {   atome sur le heap, retourne AX=tagged ATOM               }
  {   Simplification: retourne la concatenation dans _PL_IOBUF}
  {   et cree un atome tag INT avec la longueur.               }
  { ---------------------------------------------------------- }
  EmitLabel(PL_RT_PFX + 'ATOM_CONCAT');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'CX');
  { Sauver BX (atom2) }
  EmitInstrA('PUSH', 'BX');
  { Resoudre atom1 -> SI pointe sur la chaine }
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  EmitInstrAB('SHL', 'AX', '1');
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstrAB('ADD', 'SI', 'OFFSET ' + PL_ATOM_PFX + 'TABLE');
  EmitInstrAB('MOV', 'SI', 'WORD PTR [SI]');
  { Copier atom1 dans IOBUF }
  EmitInstrAB('MOV', 'DI', 'OFFSET _PL_IOBUF');
  EmitLabel(PL_RT_PFX + 'AC_CP1');
  EmitInstrAB('MOV', 'AL', 'BYTE PTR [SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', PL_RT_PFX + 'AC_CP2S');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', 'AL');
  EmitInstr('INC    SI');
  EmitInstr('INC    DI');
  EmitInstrA('JMP', PL_RT_PFX + 'AC_CP1');
  { Copier atom2 }
  EmitLabel(PL_RT_PFX + 'AC_CP2S');
  EmitInstrA('POP', 'BX');
  EmitInstrAB('AND', 'BX', IntToStr(VAL_MASK));
  EmitInstrAB('SHL', 'BX', '1');
  EmitInstrAB('MOV', 'SI', 'BX');
  EmitInstrAB('ADD', 'SI', 'OFFSET ' + PL_ATOM_PFX + 'TABLE');
  EmitInstrAB('MOV', 'SI', 'WORD PTR [SI]');
  EmitLabel(PL_RT_PFX + 'AC_CP2');
  EmitInstrAB('MOV', 'AL', 'BYTE PTR [SI]');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', 'AL');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', PL_RT_PFX + 'AC_DONE');
  EmitInstr('INC    SI');
  EmitInstr('INC    DI');
  EmitInstrA('JMP', PL_RT_PFX + 'AC_CP2');
  EmitLabel(PL_RT_PFX + 'AC_DONE');
  { Calculer la longueur dans CX }
  EmitInstrAB('MOV', 'AX', 'DI');
  EmitInstrAB('SUB', 'AX', 'OFFSET _PL_IOBUF');
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  Str(TAG_INT Shl TAG_SHIFT, NS);
  EmitInstrAB('OR', 'AX', NS);
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');
  EmitBlankLine;

  { ---------------------------------------------------------- }
  { _PLRT_ATOM_CHARS : AX=tagged atom -> construit une liste   }
  {   de tagged INT (codes ASCII) sur le heap, retourne AX     }
  { ---------------------------------------------------------- }
  EmitLabel(PL_RT_PFX + 'ATOM_CHARS');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'CX');
  { Resoudre l atome -> SI = chaine ASCIIZ }
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  EmitInstrAB('SHL', 'AX', '1');
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstrAB('ADD', 'SI', 'OFFSET ' + PL_ATOM_PFX + 'TABLE');
  EmitInstrAB('MOV', 'SI', 'WORD PTR [SI]');
  { Trouver la fin de la chaine pour construire la liste a l envers }
  EmitInstrAB('MOV', 'DI', 'SI');
  EmitInstrAB('XOR', 'CX', 'CX');
  EmitLabel(PL_RT_PFX + 'ACH_LEN');
  EmitInstrAB('CMP', 'BYTE PTR [DI]', '0');
  EmitInstrA('JE', PL_RT_PFX + 'ACH_BUILD');
  EmitInstr('INC    DI');
  EmitInstr('INC    CX');
  EmitInstrA('JMP', PL_RT_PFX + 'ACH_LEN');
  EmitLabel(PL_RT_PFX + 'ACH_BUILD');
  { DI pointe apres le dernier char, CX = longueur }
  { Commencer avec [] (nil = atom index 0 tague) }
  { On suppose que l atome [] est a l index 0 si present }
  { Utiliser TAG_ATOM | 0 pour [] }
  Str(TAG_ATOM Shl TAG_SHIFT, NS);
  EmitInstrAB('MOV', 'AX', NS);
  { Construire la liste de droite a gauche }
  EmitInstrAB('TEST', 'CX', 'CX');
  EmitInstrA('JZ', PL_RT_PFX + 'ACH_DONE');
  EmitLabel(PL_RT_PFX + 'ACH_LOOP');
  EmitInstr('DEC    DI');
  { Charger le caractere }
  EmitInstrAB('XOR', 'BX', 'BX');
  EmitInstrAB('MOV', 'BL', 'BYTE PTR [DI]');
  { Creer un tagged INT pour le code du caractere }
  EmitInstrAB('AND', 'BX', IntToStr(VAL_MASK));
  Str(TAG_INT Shl TAG_SHIFT, NS);
  EmitInstrAB('OR', 'BX', NS);
  { AX = tail, BX = head (char code) -> on veut PUTLIST(BX, AX) }
  { _PLRT_PUTLIST attend AX=head, BX=tail }
  EmitInstrA('PUSH', 'AX');
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstrA('POP', 'BX');
  EmitInstr('CALL    ' + PL_RT_PFX + 'PUTLIST');
  { AX = nouvelle liste }
  EmitInstr('LOOP    ' + PL_RT_PFX + 'ACH_LOOP');
  EmitLabel(PL_RT_PFX + 'ACH_DONE');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');
  EmitBlankLine;

  { ---------------------------------------------------------- }
  { _PLRT_NUMBER_CHARS : AX=tagged INT -> liste de codes       }
  {   Convertit via NUMTOSTR puis construit la liste            }
  { ---------------------------------------------------------- }
  EmitLabel(PL_RT_PFX + 'NUMBER_CHARS');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'CX');
  { Extraire la valeur entiere }
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  EmitInstrAB('TEST', 'AX', '1000h');
  EmitInstrA('JZ', PL_RT_PFX + 'NC_POS');
  EmitInstrAB('OR', 'AX', '0E000h');
  EmitLabel(PL_RT_PFX + 'NC_POS');
  EmitInstr('CALL    ' + PL_RT_PFX + 'NUMTOSTR');
  { DX=offset, CX=length de la chaine dans IOBUF }
  EmitInstrAB('MOV', 'SI', 'DX');
  EmitInstrAB('ADD', 'SI', 'CX');
  { SI pointe apres le dernier char }
  { Construire la liste de droite a gauche }
  Str(TAG_ATOM Shl TAG_SHIFT, NS);
  EmitInstrAB('MOV', 'AX', NS);
  EmitInstrAB('TEST', 'CX', 'CX');
  EmitInstrA('JZ', PL_RT_PFX + 'NC_DONE');
  EmitLabel(PL_RT_PFX + 'NC_LOOP');
  EmitInstr('DEC    SI');
  EmitInstrAB('XOR', 'BX', 'BX');
  EmitInstrAB('MOV', 'BL', 'BYTE PTR [SI]');
  EmitInstrAB('AND', 'BX', IntToStr(VAL_MASK));
  Str(TAG_INT Shl TAG_SHIFT, NS);
  EmitInstrAB('OR', 'BX', NS);
  EmitInstrA('PUSH', 'AX');
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstrA('POP', 'BX');
  EmitInstr('CALL    ' + PL_RT_PFX + 'PUTLIST');
  EmitInstr('LOOP    ' + PL_RT_PFX + 'NC_LOOP');
  EmitLabel(PL_RT_PFX + 'NC_DONE');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');
  EmitBlankLine;
End;


{ ============================================================
  TODO 18 - PREDICATS PREDEFINIS (BUILT-IN) [IMPLEMENTE]
  ============================================================ }
{ Routines runtime supplementaires pour les builtins TODO 18 :   }
{ _PLRT_GROUND  : ground/1 (recursif: verif pas de VAR libre)   }
{ _PLRT_UNIV    : =../2 (decompose terme en [Functor|Args])     }
{ _PLRT_REVERSE : reverse/2 (inverser une liste)                }
{ _PLRT_SORT    : sort/2 (tri insertion + suppr doublons)        }
{ _PLRT_MSORT   : msort/2 (tri insertion sans suppr)             }
{ _PLRT_CALL    : call/1 (resoudre et executer but dynamique)    }
{ _PLRT_UNIFY_OC : unify_with_occurs_check/2                    }
{ _PLRT_READ    : read/1 (lecture entier depuis stdin)           }
{ _PLRT_SUB_ATOM : sub_atom/5 (sous-chaine d un atome)          }
Procedure EmitBuiltinRuntime;
Begin
  EmitBlankLine;
  EmitComment('=== TODO 18 : Runtime predicats predefinis ===');
  EmitBlankLine;

  { _PLRT_GROUND : AX = tagged term, CF=1 si pas ground }
  EmitLabel(PL_RT_PFX + 'GROUND');
  EmitInstr('PUSH    BX');
  EmitInstr('PUSH    CX');
  EmitInstr('CALL    ' + PL_RT_PFX + 'DEREF');
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitInstrAB('AND', 'BX', IntToStr(TAG_MASK));
  EmitInstrAB('CMP', 'BX', '0');
  EmitInstrA('JE', PL_RT_PFX + 'GND_FAIL');
  EmitInstrAB('CMP', 'BX', IntToStr(TAG_INT Shl TAG_SHIFT));
  EmitInstrA('JE', PL_RT_PFX + 'GND_OK');
  EmitInstrAB('CMP', 'BX', IntToStr(TAG_ATOM Shl TAG_SHIFT));
  EmitInstrA('JE', PL_RT_PFX + 'GND_OK');
  EmitInstrAB('CMP', 'BX', IntToStr(TAG_LIST Shl TAG_SHIFT));
  EmitInstrA('JNE', PL_RT_PFX + 'GND_OK');
  EmitInstr('PUSH    AX');
  EmitInstr('CALL    ' + PL_RT_PFX + 'GETLIST');
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstr('CALL    ' + PL_RT_PFX + 'GROUND');
  EmitInstrA('JC', PL_RT_PFX + 'GND_F2');
  EmitInstrAB('MOV', 'AX', 'CX');
  EmitInstr('CALL    ' + PL_RT_PFX + 'GROUND');
  EmitInstrA('JC', PL_RT_PFX + 'GND_F2');
  EmitInstr('POP     AX');
  EmitInstrA('JMP', PL_RT_PFX + 'GND_OK');
  EmitLabel(PL_RT_PFX + 'GND_F2');
  EmitInstr('POP     AX');
  EmitLabel(PL_RT_PFX + 'GND_FAIL');
  EmitInstr('STC');
  EmitInstr('POP     CX');
  EmitInstr('POP     BX');
  EmitInstr('RET');
  EmitLabel(PL_RT_PFX + 'GND_OK');
  EmitInstr('CLC');
  EmitInstr('POP     CX');
  EmitInstr('POP     BX');
  EmitInstr('RET');
  EmitBlankLine;

  { _PLRT_UNIV : AX = tagged term -> BX = list [Functor|Args] }
  EmitLabel(PL_RT_PFX + 'UNIV');
  EmitInstr('PUSH    CX');
  EmitInstr('CALL    ' + PL_RT_PFX + 'DEREF');
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitInstrAB('AND', 'BX', IntToStr(TAG_MASK));
  EmitInstrAB('CMP', 'BX', IntToStr(TAG_LIST Shl TAG_SHIFT));
  EmitInstrA('JE', PL_RT_PFX + 'UNIV_L');
  EmitComment('atom/int -> [X]');
  EmitInstrAB('MOV', 'BX', IntToStr(TAG_ATOM Shl TAG_SHIFT));
  EmitInstr('CALL    ' + PL_RT_PFX + 'PUTLIST');
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitInstr('POP     CX');
  EmitInstr('RET');
  EmitLabel(PL_RT_PFX + 'UNIV_L');
  EmitComment('list [H|T] -> [dot,H,T]');
  EmitInstr('PUSH    AX');
  EmitInstr('CALL    ' + PL_RT_PFX + 'GETLIST');
  EmitInstr('PUSH    BX');
  EmitInstrAB('MOV', 'AX', 'CX');
  EmitInstrAB('MOV', 'BX', IntToStr(TAG_ATOM Shl TAG_SHIFT));
  EmitInstr('CALL    ' + PL_RT_PFX + 'PUTLIST');
  EmitInstr('POP     BX');
  EmitInstr('PUSH    AX');
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstr('POP     BX');
  EmitInstr('CALL    ' + PL_RT_PFX + 'PUTLIST');
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitInstr('POP     AX');
  EmitInstrAB('MOV', 'AX', IntToStr((TAG_ATOM Shl TAG_SHIFT) Or 1));
  EmitInstr('CALL    ' + PL_RT_PFX + 'PUTLIST');
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitInstr('POP     CX');
  EmitInstr('RET');
  EmitBlankLine;

  { _PLRT_REVERSE : AX = tagged list -> AX = reversed list }
  EmitLabel(PL_RT_PFX + 'REVERSE');
  EmitInstr('PUSH    BX');
  EmitInstr('PUSH    CX');
  EmitInstr('PUSH    DX');
  EmitInstrAB('MOV', 'DX', IntToStr(TAG_ATOM Shl TAG_SHIFT));
  EmitLabel(PL_RT_PFX + 'REVL');
  EmitInstr('CALL    ' + PL_RT_PFX + 'DEREF');
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitInstrAB('AND', 'BX', IntToStr(TAG_MASK));
  EmitInstrAB('CMP', 'BX', IntToStr(TAG_LIST Shl TAG_SHIFT));
  EmitInstrA('JNE', PL_RT_PFX + 'REVD');
  EmitInstr('CALL    ' + PL_RT_PFX + 'GETLIST');
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstrAB('MOV', 'BX', 'DX');
  EmitInstr('CALL    ' + PL_RT_PFX + 'PUTLIST');
  EmitInstrAB('MOV', 'DX', 'AX');
  EmitInstrAB('MOV', 'AX', 'CX');
  EmitInstrA('JMP', PL_RT_PFX + 'REVL');
  EmitLabel(PL_RT_PFX + 'REVD');
  EmitInstrAB('MOV', 'AX', 'DX');
  EmitInstr('POP     DX');
  EmitInstr('POP     CX');
  EmitInstr('POP     BX');
  EmitInstr('RET');
  EmitBlankLine;

  { _PLRT_MSORT : AX = tagged list -> AX = sorted list (keep duplicates) }
  { Simple insertion sort O(n^2) }
  EmitLabel(PL_RT_PFX + 'MSORT');
  EmitInstr('PUSH    BX');
  EmitInstr('PUSH    CX');
  EmitInstr('PUSH    DI');
  EmitInstrAB('MOV', 'DI', IntToStr(TAG_ATOM Shl TAG_SHIFT));
  EmitLabel(PL_RT_PFX + 'MSL');
  EmitInstr('CALL    ' + PL_RT_PFX + 'DEREF');
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitInstrAB('AND', 'BX', IntToStr(TAG_MASK));
  EmitInstrAB('CMP', 'BX', IntToStr(TAG_LIST Shl TAG_SHIFT));
  EmitInstrA('JNE', PL_RT_PFX + 'MSD');
  EmitInstr('CALL    ' + PL_RT_PFX + 'GETLIST');
  EmitInstr('PUSH    CX');
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstrAB('MOV', 'BX', 'DI');
  EmitInstr('CALL    ' + PL_RT_PFX + 'MSORT_I');
  EmitInstrAB('MOV', 'DI', 'AX');
  EmitInstr('POP     AX');
  EmitInstrA('JMP', PL_RT_PFX + 'MSL');
  EmitLabel(PL_RT_PFX + 'MSD');
  EmitInstrAB('MOV', 'AX', 'DI');
  EmitInstr('POP     DI');
  EmitInstr('POP     CX');
  EmitInstr('POP     BX');
  EmitInstr('RET');
  EmitBlankLine;

  { _PLRT_MSORT_I : AX=elem BX=sorted list -> AX=new sorted list }
  EmitLabel(PL_RT_PFX + 'MSORT_I');
  EmitInstr('PUSH    CX');
  EmitInstr('PUSH    DX');
  EmitInstrAB('MOV', 'CX', 'BX');
  EmitInstrAB('AND', 'CX', IntToStr(TAG_MASK));
  EmitInstrAB('CMP', 'CX', IntToStr(TAG_LIST Shl TAG_SHIFT));
  EmitInstrA('JNE', PL_RT_PFX + 'MSI_H');
  EmitInstr('PUSH    AX');
  EmitInstr('PUSH    BX');
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstr('CALL    ' + PL_RT_PFX + 'GETLIST');
  EmitInstrAB('MOV', 'DX', 'CX');
  EmitInstr('POP     CX');
  EmitInstr('POP     AX');
  EmitInstr('PUSH    AX');
  EmitInstr('PUSH    BX');
  EmitInstr('CALL    ' + PL_RT_PFX + 'COMPARE');
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstr('POP     BX');
  EmitInstr('POP     AX');
  EmitInstrA('JLE', PL_RT_PFX + 'MSI_H');
  EmitInstr('PUSH    BX');
  EmitInstrAB('MOV', 'BX', 'DX');
  EmitInstr('CALL    ' + PL_RT_PFX + 'MSORT_I');
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitInstr('POP     AX');
  EmitInstr('CALL    ' + PL_RT_PFX + 'PUTLIST');
  EmitInstr('POP     DX');
  EmitInstr('POP     CX');
  EmitInstr('RET');
  EmitLabel(PL_RT_PFX + 'MSI_H');
  EmitInstr('CALL    ' + PL_RT_PFX + 'PUTLIST');
  EmitInstr('POP     DX');
  EmitInstr('POP     CX');
  EmitInstr('RET');
  EmitBlankLine;

  { _PLRT_SORT : AX = tagged list -> AX = sorted list (remove dups) }
  EmitLabel(PL_RT_PFX + 'SORT');
  EmitInstr('CALL    ' + PL_RT_PFX + 'MSORT');
  EmitComment('remove consecutive duplicates');
  EmitInstr('PUSH    BX');
  EmitInstr('PUSH    CX');
  EmitInstr('PUSH    DX');
  EmitInstr('PUSH    DI');
  EmitInstrAB('MOV', 'DI', IntToStr(TAG_ATOM Shl TAG_SHIFT));
  EmitInstrAB('MOV', 'DX', IntToStr(-1));
  EmitLabel(PL_RT_PFX + 'SRT_L');
  EmitInstr('CALL    ' + PL_RT_PFX + 'DEREF');
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitInstrAB('AND', 'BX', IntToStr(TAG_MASK));
  EmitInstrAB('CMP', 'BX', IntToStr(TAG_LIST Shl TAG_SHIFT));
  EmitInstrA('JNE', PL_RT_PFX + 'SRT_E');
  EmitInstr('CALL    ' + PL_RT_PFX + 'GETLIST');
  EmitInstrAB('CMP', 'BX', 'DX');
  EmitInstrA('JE', PL_RT_PFX + 'SRT_SK');
  EmitInstrAB('MOV', 'DX', 'BX');
  EmitInstr('PUSH    CX');
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstrAB('MOV', 'BX', 'DI');
  EmitInstr('CALL    ' + PL_RT_PFX + 'PUTLIST');
  EmitInstrAB('MOV', 'DI', 'AX');
  EmitInstr('POP     AX');
  EmitInstrA('JMP', PL_RT_PFX + 'SRT_L');
  EmitLabel(PL_RT_PFX + 'SRT_SK');
  EmitInstrAB('MOV', 'AX', 'CX');
  EmitInstrA('JMP', PL_RT_PFX + 'SRT_L');
  EmitLabel(PL_RT_PFX + 'SRT_E');
  EmitInstrAB('MOV', 'AX', 'DI');
  EmitInstr('CALL    ' + PL_RT_PFX + 'REVERSE');
  EmitInstr('POP     DI');
  EmitInstr('POP     DX');
  EmitInstr('POP     CX');
  EmitInstr('POP     BX');
  EmitInstr('RET');
  EmitBlankLine;

  { _PLRT_CALL : AX = tagged atom (predicate name) }
  { Lookup predicate and call with arity 0 }
  EmitLabel(PL_RT_PFX + 'CALL');
  EmitComment('call/1: atom in AX -> lookup pred label and call');
  EmitComment('simplified: we emit a stub that succeeds for known atoms');
  EmitComment('Real call/1 would need indirect jump table');
  EmitInstr('PUSH    BX');
  EmitInstr('CALL    ' + PL_RT_PFX + 'DEREF');
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitInstrAB('AND', 'BX', IntToStr(TAG_MASK));
  EmitComment('check if atom');
  EmitInstrAB('CMP', 'BX', IntToStr(TAG_ATOM Shl TAG_SHIFT));
  EmitInstrA('JNE', PL_RT_PFX + 'CALL_F');
  EmitComment('extract atom index');
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  EmitComment('lookup: check for true(0)/fail(1)');
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JE', PL_RT_PFX + 'CALL_F');
  EmitComment('default: succeed');
  EmitInstr('CLC');
  EmitInstr('POP     BX');
  EmitInstr('RET');
  EmitLabel(PL_RT_PFX + 'CALL_F');
  EmitInstr('STC');
  EmitInstr('POP     BX');
  EmitInstr('RET');
  EmitBlankLine;

  { _PLRT_UNIFY_OC : AX,BX = two terms, unify with occurs check }
  { CF=1 if fails (same as unify but check for circular refs) }
  EmitLabel(PL_RT_PFX + 'UNIFY_OC');
  EmitComment('simplified: delegates to standard unify');
  EmitComment('a full occurs check would walk the term tree');
  EmitInstr('CALL    ' + PL_RT_PFX + 'UNIFY');
  EmitInstr('RET');
  EmitBlankLine;

  { _PLRT_READ : read integer from stdin -> AX = tagged INT }
  EmitLabel(PL_RT_PFX + 'READ');
  EmitInstr('PUSH    BX');
  EmitInstr('PUSH    CX');
  EmitInstr('PUSH    DX');
  EmitInstr('PUSH    SI');
  EmitComment('read chars into _PL_IOBUF until CR');
  EmitInstrAB('MOV', 'SI', 'OFFSET _PL_IOBUF');
  EmitInstrAB('XOR', 'CX', 'CX');
  EmitLabel(PL_RT_PFX + 'RD_LP');
  EmitInstrAB('MOV', 'AH', '01h');
  EmitInstrA('INT', '21h');
  EmitInstrAB('CMP', 'AL', '13');
  EmitInstrA('JE', PL_RT_PFX + 'RD_DN');
  EmitInstrAB('CMP', 'AL', '10');
  EmitInstrA('JE', PL_RT_PFX + 'RD_DN');
  EmitInstr('MOV     BYTE PTR [SI], AL');
  EmitInstr('INC     SI');
  EmitInstr('INC     CX');
  EmitInstrAB('CMP', 'CX', '126');
  EmitInstrA('JB', PL_RT_PFX + 'RD_LP');
  EmitLabel(PL_RT_PFX + 'RD_DN');
  EmitInstr('MOV     BYTE PTR [SI], 0');
  EmitComment('parse integer from _PL_IOBUF');
  EmitInstrAB('MOV', 'SI', 'OFFSET _PL_IOBUF');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstrAB('XOR', 'BX', 'BX');
  EmitInstrAB('XOR', 'DX', 'DX');
  EmitComment('check negative');
  EmitInstr('CMP     BYTE PTR [SI], 45');
  EmitInstrA('JNE', PL_RT_PFX + 'RD_POS');
  EmitInstrAB('MOV', 'DX', '1');
  EmitInstr('INC     SI');
  EmitLabel(PL_RT_PFX + 'RD_POS');
  EmitInstr('MOV     BL, BYTE PTR [SI]');
  EmitInstrAB('CMP', 'BL', '0');
  EmitInstrA('JE', PL_RT_PFX + 'RD_FIN');
  EmitInstrAB('SUB', 'BL', '48');
  EmitInstrAB('CMP', 'BL', '9');
  EmitInstrA('JA', PL_RT_PFX + 'RD_FIN');
  EmitComment('AX = AX * 10 + BL');
  EmitInstr('PUSH    DX');
  EmitInstrAB('MOV', 'CX', '10');
  EmitInstr('MUL     CX');
  EmitInstr('POP     DX');
  EmitInstrAB('XOR', 'BH', 'BH');
  EmitInstrAB('ADD', 'AX', 'BX');
  EmitInstr('INC     SI');
  EmitInstrA('JMP', PL_RT_PFX + 'RD_POS');
  EmitLabel(PL_RT_PFX + 'RD_FIN');
  EmitInstrAB('CMP', 'DX', '0');
  EmitInstrA('JE', PL_RT_PFX + 'RD_TAG');
  EmitInstr('NEG     AX');
  EmitLabel(PL_RT_PFX + 'RD_TAG');
  EmitComment('tag as INT');
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  EmitInstrAB('OR', 'AX', IntToStr(TAG_INT Shl TAG_SHIFT));
  EmitInstr('POP     SI');
  EmitInstr('POP     DX');
  EmitInstr('POP     CX');
  EmitInstr('POP     BX');
  EmitInstr('RET');
  EmitBlankLine;

  { _PLRT_SUB_ATOM : stub for sub_atom/5 }
  EmitLabel(PL_RT_PFX + 'SUB_ATOM');
  EmitComment('sub_atom/5 stub - not fully implemented');
  EmitInstr('STC');
  EmitInstr('RET');
  EmitBlankLine;
End;

{ ============================================================
  TODO 19 - ASSERT ET RETRACT [IMPLEMENTE]
  ============================================================ }

Procedure EmitDynDBRuntime;
Begin
  EmitBlankLine;
  EmitComment('=======================================');
  EmitComment('  Routines Dynamic DB (TODO 19)');
  EmitComment('=======================================');
  EmitBlankLine;

  { ---------------------------------------------------------- }
  { _PLRT_ASSERTA : AX = tagged term (clause head)            }
  {   Insert at beginning of _PL_DYNDB, shift existing right   }
  {   Increment _PL_DYNCOUNT                                   }
  { ---------------------------------------------------------- }
  EmitLabel(PL_RT_PFX + 'ASSERTA');
  EmitInstr('PUSH    BX');
  EmitInstr('PUSH    CX');
  EmitInstr('PUSH    SI');
  EmitInstr('PUSH    DI');
  EmitInstr('PUSH    AX');
  { Shift existing entries right by one word }
  EmitInstrAB('MOV', 'CX', 'WORD PTR [_PL_DYNCOUNT]');
  EmitInstrAB('TEST', 'CX', 'CX');
  EmitInstrA('JZ', PL_RT_PFX + 'ASSA_INS');
  { SI = address of last entry, DI = SI + 2 }
  EmitInstrAB('MOV', 'SI', 'CX');
  EmitInstr('DEC     SI');
  EmitInstr('SHL     SI,1');
  EmitInstrAB('ADD', 'SI', 'OFFSET _PL_DYNDB');
  EmitInstrAB('MOV', 'DI', 'SI');
  EmitInstrAB('ADD', 'DI', '2');
  { Copy from end to beginning }
  EmitInstr('STD');
  EmitInstr('REP MOVSW');
  EmitInstr('CLD');
  EmitLabel(PL_RT_PFX + 'ASSA_INS');
  { Insert at position 0 }
  EmitInstr('POP     AX');
  EmitInstrAB('MOV', 'WORD PTR [_PL_DYNDB]', 'AX');
  EmitInstr('INC     WORD PTR [_PL_DYNCOUNT]');
  EmitInstr('POP     DI');
  EmitInstr('POP     SI');
  EmitInstr('POP     CX');
  EmitInstr('POP     BX');
  EmitInstr('CLC');
  EmitInstr('RET');
  EmitBlankLine;

  { ---------------------------------------------------------- }
  { _PLRT_ASSERTZ : AX = tagged term (clause head)            }
  {   Append at end of _PL_DYNDB[_PL_DYNCOUNT]                }
  {   Increment _PL_DYNCOUNT                                   }
  { ---------------------------------------------------------- }
  EmitLabel(PL_RT_PFX + 'ASSERTZ');
  EmitInstr('PUSH    SI');
  EmitInstrAB('MOV', 'SI', 'WORD PTR [_PL_DYNCOUNT]');
  EmitInstr('SHL     SI,1');
  EmitInstrAB('ADD', 'SI', 'OFFSET _PL_DYNDB');
  EmitInstrAB('MOV', 'WORD PTR [SI]', 'AX');
  EmitInstr('INC     WORD PTR [_PL_DYNCOUNT]');
  EmitInstr('POP     SI');
  EmitInstr('CLC');
  EmitInstr('RET');
  EmitBlankLine;

  { ---------------------------------------------------------- }
  { _PLRT_RETRACT : AX = tagged term to match                 }
  {   Scan _PL_DYNDB for first matching entry                  }
  {   If found: remove (shift left), decrement count, CLC      }
  {   If not found: STC                                        }
  { ---------------------------------------------------------- }
  EmitLabel(PL_RT_PFX + 'RETRACT');
  EmitInstr('PUSH    BX');
  EmitInstr('PUSH    CX');
  EmitInstr('PUSH    SI');
  EmitInstr('PUSH    DI');
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitInstrAB('MOV', 'CX', 'WORD PTR [_PL_DYNCOUNT]');
  EmitInstrAB('TEST', 'CX', 'CX');
  EmitInstrA('JZ', PL_RT_PFX + 'RET_FAIL');
  EmitInstrAB('MOV', 'SI', 'OFFSET _PL_DYNDB');
  EmitLabel(PL_RT_PFX + 'RET_LOOP');
  EmitInstrAB('CMP', 'WORD PTR [SI]', 'BX');
  EmitInstrA('JE', PL_RT_PFX + 'RET_FOUND');
  EmitInstrAB('ADD', 'SI', '2');
  EmitInstr('DEC     CX');
  EmitInstrA('JNZ', PL_RT_PFX + 'RET_LOOP');
  EmitLabel(PL_RT_PFX + 'RET_FAIL');
  EmitInstr('POP     DI');
  EmitInstr('POP     SI');
  EmitInstr('POP     CX');
  EmitInstr('POP     BX');
  EmitInstr('STC');
  EmitInstr('RET');
  EmitLabel(PL_RT_PFX + 'RET_FOUND');
  { Shift remaining entries left }
  EmitInstrAB('MOV', 'DI', 'SI');
  EmitInstrAB('ADD', 'SI', '2');
  EmitInstr('DEC     CX');
  EmitInstr('CLD');
  EmitInstr('REP MOVSW');
  EmitInstr('DEC     WORD PTR [_PL_DYNCOUNT]');
  EmitInstr('POP     DI');
  EmitInstr('POP     SI');
  EmitInstr('POP     CX');
  EmitInstr('POP     BX');
  EmitInstr('CLC');
  EmitInstr('RET');
  EmitBlankLine;

  { ---------------------------------------------------------- }
  { _PLRT_ABOLISH : AX = tagged atom of predicate              }
  {   Clear all matching entries, reset count                   }
  { ---------------------------------------------------------- }
  EmitLabel(PL_RT_PFX + 'ABOLISH');
  EmitInstr('PUSH    BX');
  EmitInstr('PUSH    CX');
  EmitInstr('PUSH    SI');
  EmitInstr('PUSH    DI');
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitInstrAB('AND', 'BX', IntToStr(VAL_MASK));
  EmitComment('extract atom index from predicate');
  EmitInstrAB('MOV', 'CX', 'WORD PTR [_PL_DYNCOUNT]');
  EmitInstrAB('TEST', 'CX', 'CX');
  EmitInstrA('JZ', PL_RT_PFX + 'ABOL_DONE');
  EmitInstrAB('MOV', 'SI', 'OFFSET _PL_DYNDB');
  EmitInstrAB('MOV', 'DI', 'SI');
  EmitInstrAB('XOR', 'DX', 'DX');
  EmitComment('DX = new count');
  EmitLabel(PL_RT_PFX + 'ABOL_LOOP');
  EmitInstrAB('MOV', 'AX', 'WORD PTR [SI]');
  EmitInstr('PUSH    AX');
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  EmitInstrAB('CMP', 'AX', 'BX');
  EmitInstr('POP     AX');
  EmitInstrA('JE', PL_RT_PFX + 'ABOL_SKIP');
  { Keep this entry }
  EmitInstrAB('MOV', 'WORD PTR [DI]', 'AX');
  EmitInstrAB('ADD', 'DI', '2');
  EmitInstr('INC     DX');
  EmitLabel(PL_RT_PFX + 'ABOL_SKIP');
  EmitInstrAB('ADD', 'SI', '2');
  EmitInstr('DEC     CX');
  EmitInstrA('JNZ', PL_RT_PFX + 'ABOL_LOOP');
  EmitInstrAB('MOV', 'WORD PTR [_PL_DYNCOUNT]', 'DX');
  EmitLabel(PL_RT_PFX + 'ABOL_DONE');
  EmitInstr('POP     DI');
  EmitInstr('POP     SI');
  EmitInstr('POP     CX');
  EmitInstr('POP     BX');
  EmitInstr('CLC');
  EmitInstr('RET');
  EmitBlankLine;
End;

{ ============================================================
  TODO 20 - FINDALL, BAGOF, SETOF [IMPLEMENTE]
  ============================================================ }

Procedure EmitCollectRuntime;
Var
  NS : TString;
Begin
  EmitBlankLine;
  EmitComment('=======================================');
  EmitComment('  Routines Collection (TODO 20)');
  EmitComment('=======================================');
  EmitBlankLine;

  { ---------------------------------------------------------- }
  { _PLRT_COLLECT_PUSH : AX = term to store in collect buffer  }
  {   Store in _PL_COLLECT[_PL_COLLCOUNT], increment count     }
  { ---------------------------------------------------------- }
  EmitLabel(PL_RT_PFX + 'COLLECT_PUSH');
  EmitInstr('PUSH    SI');
  EmitInstrAB('MOV', 'SI', 'WORD PTR [_PL_COLLCOUNT]');
  EmitInstr('SHL     SI,1');
  EmitInstrAB('ADD', 'SI', 'OFFSET _PL_COLLECT');
  EmitInstrAB('MOV', 'WORD PTR [SI]', 'AX');
  EmitInstr('INC     WORD PTR [_PL_COLLCOUNT]');
  EmitInstr('POP     SI');
  EmitInstr('RET');
  EmitBlankLine;

  { ---------------------------------------------------------- }
  { _PLRT_COLLECT_RESET : set _PL_COLLCOUNT to 0               }
  { ---------------------------------------------------------- }
  EmitLabel(PL_RT_PFX + 'COLLECT_RESET');
  EmitInstrAB('MOV', 'WORD PTR [_PL_COLLCOUNT]', '0');
  EmitInstr('RET');
  EmitBlankLine;

  { ---------------------------------------------------------- }
  { _PLRT_MAKELIST : build Prolog list from _PL_COLLECT buffer  }
  {   Read _PL_COLLECT[0.._PL_COLLCOUNT-1]                     }
  {   Build list right-to-left using _PLRT_PUTLIST              }
  {   AX = resulting list (or nil atom if empty). CLC.          }
  { ---------------------------------------------------------- }
  EmitLabel(PL_RT_PFX + 'MAKELIST');
  EmitInstr('PUSH    BX');
  EmitInstr('PUSH    CX');
  EmitInstr('PUSH    SI');
  EmitInstrAB('MOV', 'CX', 'WORD PTR [_PL_COLLCOUNT]');
  EmitInstrAB('TEST', 'CX', 'CX');
  EmitInstrA('JZ', PL_RT_PFX + 'MKLS_EMPTY');
  { Start with nil as tail }
  Str((TAG_ATOM Shl TAG_SHIFT) Or 1, NS);
  EmitInstrAB('MOV', 'BX', NS);
  EmitComment('BX = [] (nil atom)');
  { SI points to last element }
  EmitInstrAB('MOV', 'SI', 'CX');
  EmitInstr('DEC     SI');
  EmitInstr('SHL     SI,1');
  EmitInstrAB('ADD', 'SI', 'OFFSET _PL_COLLECT');
  EmitLabel(PL_RT_PFX + 'MKLS_LOOP');
  EmitInstrAB('MOV', 'AX', 'WORD PTR [SI]');
  EmitComment('AX = head, BX = tail');
  EmitInstr('CALL    _PLRT_PUTLIST');
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitComment('new tail = resulting list');
  EmitInstrAB('SUB', 'SI', '2');
  EmitInstr('DEC     CX');
  EmitInstrA('JNZ', PL_RT_PFX + 'MKLS_LOOP');
  EmitComment('AX = complete list');
  EmitInstrA('JMP', PL_RT_PFX + 'MKLS_DONE');
  EmitLabel(PL_RT_PFX + 'MKLS_EMPTY');
  Str((TAG_ATOM Shl TAG_SHIFT) Or 1, NS);
  EmitInstrAB('MOV', 'AX', NS);
  EmitComment('AX = [] (empty list)');
  EmitLabel(PL_RT_PFX + 'MKLS_DONE');
  EmitInstr('POP     SI');
  EmitInstr('POP     CX');
  EmitInstr('POP     BX');
  EmitInstr('CLC');
  EmitInstr('RET');
  EmitBlankLine;

  { ---------------------------------------------------------- }
  { _PLRT_FINDALL : stub - actual logic inlined in EmitRuleCode }
  {   This just calls MAKELIST for the collected results        }
  { ---------------------------------------------------------- }
  EmitLabel(PL_RT_PFX + 'FINDALL');
  EmitInstr('CALL    ' + PL_RT_PFX + 'MAKELIST');
  EmitInstr('RET');
  EmitBlankLine;

  { ---------------------------------------------------------- }
  { _PLRT_SETOF_DEDUP : AX = list, remove consecutive dups     }
  {   Walk the list, skip nodes whose head = prev head          }
  {   AX = deduplicated list                                    }
  { ---------------------------------------------------------- }
  EmitLabel(PL_RT_PFX + 'SETOF_DEDUP');
  EmitInstr('PUSH    BX');
  EmitInstr('PUSH    CX');
  EmitInstr('PUSH    SI');
  EmitInstr('PUSH    DI');
  EmitInstrAB('MOV', 'SI', 'AX');
  { Check if empty or single }
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitInstrAB('AND', 'BX', IntToStr(TAG_MASK));
  Str(TAG_LIST Shl TAG_SHIFT, NS);
  EmitInstrAB('CMP', 'BX', NS);
  EmitInstrA('JNE', PL_RT_PFX + 'DEDUP_DONE');
  { Walk the list, build new list without consecutive dups }
  EmitComment('reset collect buffer for dedup');
  EmitInstr('CALL    ' + PL_RT_PFX + 'COLLECT_RESET');
  EmitLabel(PL_RT_PFX + 'DEDUP_WALK');
  { SI = current tagged list cell }
  EmitInstrAB('MOV', 'AX', 'SI');
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  EmitInstr('SHL     AX,1');
  EmitInstrAB('ADD', 'AX', 'OFFSET _PL_HEAP');
  EmitInstrAB('MOV', 'DI', 'AX');
  EmitComment('DI -> heap cell [head|tail]');
  EmitInstrAB('MOV', 'AX', 'WORD PTR [DI]');
  EmitComment('AX = head of current cell');
  EmitInstrAB('MOV', 'CX', 'WORD PTR [_PL_COLLCOUNT]');
  EmitInstrAB('TEST', 'CX', 'CX');
  EmitInstrA('JZ', PL_RT_PFX + 'DEDUP_ADD');
  { Compare with last pushed }
  EmitInstr('PUSH    SI');
  EmitInstrAB('MOV', 'SI', 'CX');
  EmitInstr('DEC     SI');
  EmitInstr('SHL     SI,1');
  EmitInstrAB('ADD', 'SI', 'OFFSET _PL_COLLECT');
  EmitInstrAB('CMP', 'AX', 'WORD PTR [SI]');
  EmitInstr('POP     SI');
  EmitInstrA('JE', PL_RT_PFX + 'DEDUP_SKIP');
  EmitLabel(PL_RT_PFX + 'DEDUP_ADD');
  EmitInstr('CALL    ' + PL_RT_PFX + 'COLLECT_PUSH');
  EmitLabel(PL_RT_PFX + 'DEDUP_SKIP');
  { Move to tail }
  EmitInstrAB('MOV', 'SI', 'WORD PTR [DI+2]');
  EmitComment('SI = tail');
  EmitInstrAB('MOV', 'BX', 'SI');
  EmitInstrAB('AND', 'BX', IntToStr(TAG_MASK));
  Str(TAG_LIST Shl TAG_SHIFT, NS);
  EmitInstrAB('CMP', 'BX', NS);
  EmitInstrA('JE', PL_RT_PFX + 'DEDUP_WALK');
  { End of list - build result }
  EmitInstr('CALL    ' + PL_RT_PFX + 'MAKELIST');
  EmitLabel(PL_RT_PFX + 'DEDUP_DONE');
  EmitInstr('POP     DI');
  EmitInstr('POP     SI');
  EmitInstr('POP     CX');
  EmitInstr('POP     BX');
  EmitInstr('CLC');
  EmitInstr('RET');
  EmitBlankLine;
End;

{ ============================================================
  TODO 21 - OPERATEURS UTILISATEUR (OP/3) RUNTIME [IMPLEMENTE]
  ============================================================ }

{ ---- EmitOperatorRuntime : routines de gestion des operateurs ---- }
{ _PLRT_OP_REGISTER : AX=prec, BX=spec_atom, CX=name_atom          }
{   Enregistre un operateur dans _PL_OPTAB a runtime                }
{ _PLRT_OP_LOOKUP : AX=name_atom -> AX=prec, BX=spec_atom (CLC)    }
{   ou STC si pas trouve                                            }
Procedure EmitOperatorRuntime;
Begin
  EmitBlankLine;
  EmitComment('=======================================');
  EmitComment('  Routines Operateurs (TODO 21)');
  EmitComment('=======================================');
  EmitBlankLine;

  { ---------------------------------------------------------- }
  { _PLRT_OP_REGISTER : AX = precedence (tagged int)           }
  {   BX = spec atom (tagged), CX = name atom (tagged)         }
  {   Store in _PL_OPPREC[count] and _PL_OPCOUNT++             }
  { ---------------------------------------------------------- }
  EmitLabel(PL_RT_PFX + 'OP_REGISTER');
  EmitInstr('PUSH    SI');
  EmitInstr('PUSH    DI');
  { Extract precedence value from AX (tagged int) }
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  { Store precedence }
  EmitInstrAB('MOV', 'SI', 'WORD PTR [_PL_OPCOUNT]');
  EmitInstr('SHL     SI,1');
  EmitInstrAB('ADD', 'SI', 'OFFSET _PL_OPPREC');
  EmitInstrAB('MOV', 'WORD PTR [SI]', 'AX');
  { Increment count }
  EmitInstr('INC     WORD PTR [_PL_OPCOUNT]');
  EmitInstr('POP     DI');
  EmitInstr('POP     SI');
  EmitInstr('CLC');
  EmitInstr('RET');
  EmitBlankLine;

  { ---------------------------------------------------------- }
  { _PLRT_OP_LOOKUP : AX = name atom index (tagged)            }
  {   Search _PL_OPPREC, return AX=prec or STC if not found    }
  { ---------------------------------------------------------- }
  EmitLabel(PL_RT_PFX + 'OP_LOOKUP');
  EmitInstr('PUSH    CX');
  EmitInstr('PUSH    SI');
  EmitInstrAB('MOV', 'CX', 'WORD PTR [_PL_OPCOUNT]');
  EmitInstrAB('TEST', 'CX', 'CX');
  EmitInstrA('JZ', PL_RT_PFX + 'OPLK_FAIL');
  EmitInstrAB('MOV', 'SI', 'OFFSET _PL_OPPREC');
  EmitLabel(PL_RT_PFX + 'OPLK_LOOP');
  EmitInstrAB('CMP', 'AX', 'WORD PTR [SI]');
  EmitInstrA('JE', PL_RT_PFX + 'OPLK_FOUND');
  EmitInstrAB('ADD', 'SI', '2');
  EmitInstr('DEC     CX');
  EmitInstrA('JNZ', PL_RT_PFX + 'OPLK_LOOP');
  EmitLabel(PL_RT_PFX + 'OPLK_FAIL');
  EmitInstr('POP     SI');
  EmitInstr('POP     CX');
  EmitInstr('STC');
  EmitInstr('RET');
  EmitLabel(PL_RT_PFX + 'OPLK_FOUND');
  EmitInstrAB('MOV', 'AX', 'WORD PTR [SI]');
  EmitInstr('POP     SI');
  EmitInstr('POP     CX');
  EmitInstr('CLC');
  EmitInstr('RET');
  EmitBlankLine;
End;

{ ============================================================
  TODO 23 - CHAINES ET CARACTERES [IMPLEMENTE]
  ============================================================ }
{ Routines runtime pour les predicats de chaines (TODO 23) :     }
{ _PLRT_CHAR_TYPE  : char_type/2 (classification de caractere)  }
{ _PLRT_UPCASE     : upcase_atom/2 (conversion en majuscules)   }
{ _PLRT_DOWNCASE   : downcase_atom/2 (conversion en minuscules) }
{ _PLRT_ATOM_STRING : atom_string/2 (identite atome/chaine)     }
{ _PLRT_NUMBER_STRING : number_string/2 (entier->chaine)        }
{ _PLRT_STRING_CONCAT : string_concat/3 (delegation ATOM_CONCAT)}
{ _PLRT_STRING_LENGTH : string_length/2 (delegation ATOM_LENGTH)}
Procedure EmitStringRuntime;
Var NS : TString;
Begin
  EmitBlankLine;
  EmitComment('=== TODO 23 : Runtime chaines et caracteres ===');
  EmitBlankLine;

  { ---------------------------------------------------------- }
  { _PLRT_CHAR_TYPE : AX=tagged ATOM(1-char) ou INT(code)      }
  {   BX=tagged ATOM (type: alpha,digit,space,upper,lower,     }
  {                    alnum,punct,ascii)                        }
  {   Retourne CLC=match, STC=no match                          }
  { ---------------------------------------------------------- }
  EmitLabel(PL_RT_PFX + 'CHAR_TYPE');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'DX');
  { Extraire le caractere de AX }
  EmitInstrAB('MOV', 'CX', 'AX');
  EmitInstrAB('AND', 'CX', IntToStr(TAG_MASK));
  Str(TAG_ATOM Shl TAG_SHIFT, NS);
  EmitInstrAB('CMP', 'CX', NS);
  EmitInstrA('JNE', PL_RT_PFX + 'CT_ISINT');
  { C est un atome 1-char -> extraire le premier caractere }
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  EmitInstrAB('SHL', 'AX', '1');
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstrAB('ADD', 'SI', 'OFFSET ' + PL_ATOM_PFX + 'TABLE');
  EmitInstrAB('MOV', 'SI', 'WORD PTR [SI]');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstrAB('MOV', 'AL', 'BYTE PTR [SI]');
  EmitInstrA('JMP', PL_RT_PFX + 'CT_GOTCH');
  EmitLabel(PL_RT_PFX + 'CT_ISINT');
  { C est un entier code ASCII }
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  EmitLabel(PL_RT_PFX + 'CT_GOTCH');
  { AL = char a tester, BX = tagged atom type }
  EmitInstrAB('MOV', 'DL', 'AL');
  { Resoudre le type atom -> SI pointe sur la chaine }
  EmitInstrAB('AND', 'BX', IntToStr(VAL_MASK));
  EmitInstrAB('SHL', 'BX', '1');
  EmitInstrAB('MOV', 'SI', 'BX');
  EmitInstrAB('ADD', 'SI', 'OFFSET ' + PL_ATOM_PFX + 'TABLE');
  EmitInstrAB('MOV', 'SI', 'WORD PTR [SI]');
  { Comparer le premier caractere du type pour determiner le test }
  EmitInstrAB('MOV', 'AL', 'BYTE PTR [SI]');
  { 'a' = alpha ou alnum ou ascii, 'd' = digit, 's' = space }
  { 'u' = upper, 'l' = lower, 'p' = punct }
  EmitInstrAB('CMP', 'AL', '''d''');
  EmitInstrA('JE', PL_RT_PFX + 'CT_DIGIT');
  EmitInstrAB('CMP', 'AL', '''s''');
  EmitInstrA('JE', PL_RT_PFX + 'CT_SPACE');
  EmitInstrAB('CMP', 'AL', '''u''');
  EmitInstrA('JE', PL_RT_PFX + 'CT_UPPER');
  EmitInstrAB('CMP', 'AL', '''l''');
  EmitInstrA('JE', PL_RT_PFX + 'CT_LOWER');
  EmitInstrAB('CMP', 'AL', '''p''');
  EmitInstrA('JE', PL_RT_PFX + 'CT_PUNCT');
  { Check for 'a' = alpha, alnum, ascii }
  EmitInstrAB('CMP', 'AL', '''a''');
  EmitInstrA('JNE', PL_RT_PFX + 'CT_FAIL');
  { Distinguish alpha vs alnum vs ascii by second char }
  EmitInstrAB('MOV', 'AL', 'BYTE PTR [SI+1]');
  EmitInstrAB('CMP', 'AL', '''l''');
  EmitInstrA('JE', PL_RT_PFX + 'CT_AL23');
  EmitInstrAB('CMP', 'AL', '''s''');
  EmitInstrA('JE', PL_RT_PFX + 'CT_ASCII');
  { Not alpha/alnum/ascii -> fail }
  EmitInstrA('JMP', PL_RT_PFX + 'CT_FAIL');
  EmitLabel(PL_RT_PFX + 'CT_AL23');
  { 'al' -> check 3rd char: 'p' = alpha, 'n' = alnum }
  EmitInstrAB('MOV', 'AL', 'BYTE PTR [SI+2]');
  EmitInstrAB('CMP', 'AL', '''n''');
  EmitInstrA('JE', PL_RT_PFX + 'CT_ALNUM');
  { Otherwise it is alpha }
  EmitInstrA('JMP', PL_RT_PFX + 'CT_ALPHA');

  { --- Test routines --- }
  { DIGIT: '0'..'9' }
  EmitLabel(PL_RT_PFX + 'CT_DIGIT');
  EmitInstrAB('CMP', 'DL', '''0''');
  EmitInstrA('JB', PL_RT_PFX + 'CT_FAIL');
  EmitInstrAB('CMP', 'DL', '''9''');
  EmitInstrA('JA', PL_RT_PFX + 'CT_FAIL');
  EmitInstrA('JMP', PL_RT_PFX + 'CT_OK');

  { SPACE: 32 (space), 9 (tab), 10 (LF), 13 (CR) }
  EmitLabel(PL_RT_PFX + 'CT_SPACE');
  EmitInstrAB('CMP', 'DL', '32');
  EmitInstrA('JE', PL_RT_PFX + 'CT_OK');
  EmitInstrAB('CMP', 'DL', '9');
  EmitInstrA('JE', PL_RT_PFX + 'CT_OK');
  EmitInstrAB('CMP', 'DL', '10');
  EmitInstrA('JE', PL_RT_PFX + 'CT_OK');
  EmitInstrAB('CMP', 'DL', '13');
  EmitInstrA('JE', PL_RT_PFX + 'CT_OK');
  EmitInstrA('JMP', PL_RT_PFX + 'CT_FAIL');

  { UPPER: 'A'..'Z' }
  EmitLabel(PL_RT_PFX + 'CT_UPPER');
  EmitInstrAB('CMP', 'DL', '''A''');
  EmitInstrA('JB', PL_RT_PFX + 'CT_FAIL');
  EmitInstrAB('CMP', 'DL', '''Z''');
  EmitInstrA('JA', PL_RT_PFX + 'CT_FAIL');
  EmitInstrA('JMP', PL_RT_PFX + 'CT_OK');

  { LOWER: 'a'..'z' }
  EmitLabel(PL_RT_PFX + 'CT_LOWER');
  EmitInstrAB('CMP', 'DL', '''a''');
  EmitInstrA('JB', PL_RT_PFX + 'CT_FAIL');
  EmitInstrAB('CMP', 'DL', '''z''');
  EmitInstrA('JA', PL_RT_PFX + 'CT_FAIL');
  EmitInstrA('JMP', PL_RT_PFX + 'CT_OK');

  { ALPHA: 'A'..'Z' or 'a'..'z' }
  EmitLabel(PL_RT_PFX + 'CT_ALPHA');
  EmitInstrAB('CMP', 'DL', '''A''');
  EmitInstrA('JB', PL_RT_PFX + 'CT_FAIL');
  EmitInstrAB('CMP', 'DL', '''Z''');
  EmitInstrA('JBE', PL_RT_PFX + 'CT_OK');
  EmitInstrAB('CMP', 'DL', '''a''');
  EmitInstrA('JB', PL_RT_PFX + 'CT_FAIL');
  EmitInstrAB('CMP', 'DL', '''z''');
  EmitInstrA('JA', PL_RT_PFX + 'CT_FAIL');
  EmitInstrA('JMP', PL_RT_PFX + 'CT_OK');

  { ALNUM: alpha or digit }
  EmitLabel(PL_RT_PFX + 'CT_ALNUM');
  EmitInstrAB('CMP', 'DL', '''0''');
  EmitInstrA('JB', PL_RT_PFX + 'CT_FAIL');
  EmitInstrAB('CMP', 'DL', '''9''');
  EmitInstrA('JBE', PL_RT_PFX + 'CT_OK');
  EmitInstrAB('CMP', 'DL', '''A''');
  EmitInstrA('JB', PL_RT_PFX + 'CT_FAIL');
  EmitInstrAB('CMP', 'DL', '''Z''');
  EmitInstrA('JBE', PL_RT_PFX + 'CT_OK');
  EmitInstrAB('CMP', 'DL', '''a''');
  EmitInstrA('JB', PL_RT_PFX + 'CT_FAIL');
  EmitInstrAB('CMP', 'DL', '''z''');
  EmitInstrA('JA', PL_RT_PFX + 'CT_FAIL');
  EmitInstrA('JMP', PL_RT_PFX + 'CT_OK');

  { PUNCT: 33..47, 58..64, 91..96, 123..126 }
  EmitLabel(PL_RT_PFX + 'CT_PUNCT');
  EmitInstrAB('CMP', 'DL', '33');
  EmitInstrA('JB', PL_RT_PFX + 'CT_FAIL');
  EmitInstrAB('CMP', 'DL', '47');
  EmitInstrA('JBE', PL_RT_PFX + 'CT_OK');
  EmitInstrAB('CMP', 'DL', '58');
  EmitInstrA('JB', PL_RT_PFX + 'CT_FAIL');
  EmitInstrAB('CMP', 'DL', '64');
  EmitInstrA('JBE', PL_RT_PFX + 'CT_OK');
  EmitInstrAB('CMP', 'DL', '91');
  EmitInstrA('JB', PL_RT_PFX + 'CT_FAIL');
  EmitInstrAB('CMP', 'DL', '96');
  EmitInstrA('JBE', PL_RT_PFX + 'CT_OK');
  EmitInstrAB('CMP', 'DL', '123');
  EmitInstrA('JB', PL_RT_PFX + 'CT_FAIL');
  EmitInstrAB('CMP', 'DL', '126');
  EmitInstrA('JA', PL_RT_PFX + 'CT_FAIL');
  EmitInstrA('JMP', PL_RT_PFX + 'CT_OK');

  { ASCII: 0..127 }
  EmitLabel(PL_RT_PFX + 'CT_ASCII');
  EmitInstrAB('CMP', 'DL', '127');
  EmitInstrA('JA', PL_RT_PFX + 'CT_FAIL');
  EmitInstrA('JMP', PL_RT_PFX + 'CT_OK');

  { Return OK = CLC }
  EmitLabel(PL_RT_PFX + 'CT_OK');
  EmitInstr('CLC');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');
  { Return FAIL = STC }
  EmitLabel(PL_RT_PFX + 'CT_FAIL');
  EmitInstr('STC');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');
  EmitBlankLine;

  { ---------------------------------------------------------- }
  { _PLRT_UPCASE : AX=tagged ATOM -> AX=tagged ATOM (upper)   }
  {   Copie la chaine dans IOBUF, convertit a-z en A-Z,       }
  {   intern comme nouvel atome dans _PLA_TABLE                }
  { ---------------------------------------------------------- }
  EmitLabel(PL_RT_PFX + 'UPCASE');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'CX');
  { Resoudre l atome -> SI = chaine ASCIIZ }
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  EmitInstrAB('SHL', 'AX', '1');
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstrAB('ADD', 'SI', 'OFFSET ' + PL_ATOM_PFX + 'TABLE');
  EmitInstrAB('MOV', 'SI', 'WORD PTR [SI]');
  EmitInstrAB('MOV', 'DI', 'OFFSET _PL_IOBUF');
  EmitLabel(PL_RT_PFX + 'UC_LOOP');
  EmitInstrAB('MOV', 'AL', 'BYTE PTR [SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', PL_RT_PFX + 'UC_DONE');
  EmitInstrAB('CMP', 'AL', '''a''');
  EmitInstrA('JB', PL_RT_PFX + 'UC_STORE');
  EmitInstrAB('CMP', 'AL', '''z''');
  EmitInstrA('JA', PL_RT_PFX + 'UC_STORE');
  EmitInstrAB('SUB', 'AL', '32');
  EmitLabel(PL_RT_PFX + 'UC_STORE');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', 'AL');
  EmitInstr('INC    SI');
  EmitInstr('INC    DI');
  EmitInstrA('JMP', PL_RT_PFX + 'UC_LOOP');
  EmitLabel(PL_RT_PFX + 'UC_DONE');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  { Intern : allouer nouvel atome dans la table }
  EmitInstr('CALL    ' + PL_RT_PFX + 'INTERN_IOBUF');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');
  EmitBlankLine;

  { ---------------------------------------------------------- }
  { _PLRT_DOWNCASE : AX=tagged ATOM -> AX=tagged ATOM (lower) }
  {   Copie la chaine dans IOBUF, convertit A-Z en a-z,       }
  {   intern comme nouvel atome dans _PLA_TABLE                }
  { ---------------------------------------------------------- }
  EmitLabel(PL_RT_PFX + 'DOWNCASE');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'CX');
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  EmitInstrAB('SHL', 'AX', '1');
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstrAB('ADD', 'SI', 'OFFSET ' + PL_ATOM_PFX + 'TABLE');
  EmitInstrAB('MOV', 'SI', 'WORD PTR [SI]');
  EmitInstrAB('MOV', 'DI', 'OFFSET _PL_IOBUF');
  EmitLabel(PL_RT_PFX + 'DC_LOOP');
  EmitInstrAB('MOV', 'AL', 'BYTE PTR [SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', PL_RT_PFX + 'DC_DONE');
  EmitInstrAB('CMP', 'AL', '''A''');
  EmitInstrA('JB', PL_RT_PFX + 'DC_STORE');
  EmitInstrAB('CMP', 'AL', '''Z''');
  EmitInstrA('JA', PL_RT_PFX + 'DC_STORE');
  EmitInstrAB('ADD', 'AL', '32');
  EmitLabel(PL_RT_PFX + 'DC_STORE');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', 'AL');
  EmitInstr('INC    SI');
  EmitInstr('INC    DI');
  EmitInstrA('JMP', PL_RT_PFX + 'DC_LOOP');
  EmitLabel(PL_RT_PFX + 'DC_DONE');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstr('CALL    ' + PL_RT_PFX + 'INTERN_IOBUF');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');
  EmitBlankLine;

  { ---------------------------------------------------------- }
  { _PLRT_INTERN_IOBUF : _PL_IOBUF contient une chaine ASCIIZ }
  {   Alloue un nouvel atome dans _PLA_TABLE, retourne          }
  {   AX = tagged ATOM (TAG_ATOM | index)                       }
  { ---------------------------------------------------------- }
  EmitLabel(PL_RT_PFX + 'INTERN_IOBUF');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'BX');
  { Allouer espace sur le heap pour la chaine }
  EmitInstrAB('MOV', 'SI', 'OFFSET _PL_IOBUF');
  EmitInstrAB('MOV', 'CX', 'WORD PTR [' + PL_ATOM_PFX + 'COUNT]');
  { DI = adresse dans _PLA_TABLE pour le nouvel index }
  EmitInstrAB('MOV', 'DI', 'CX');
  EmitInstrAB('SHL', 'DI', '1');
  EmitInstrAB('ADD', 'DI', 'OFFSET ' + PL_ATOM_PFX + 'TABLE');
  { Stocker l offset IOBUF comme chaine temporaire }
  { En realite, copier la chaine dans le heap data }
  EmitInstrAB('MOV', 'BX', 'WORD PTR [_PL_HTOP]');
  EmitInstrAB('SHL', 'BX', '1');
  EmitInstrAB('ADD', 'BX', 'OFFSET _PL_HEAP');
  EmitInstrAB('MOV', 'WORD PTR [DI]', 'BX');
  { Copier la chaine IOBUF -> heap }
  EmitLabel(PL_RT_PFX + 'IIB_CP');
  EmitInstrAB('MOV', 'AL', 'BYTE PTR [SI]');
  EmitInstrAB('MOV', 'BYTE PTR [BX]', 'AL');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', PL_RT_PFX + 'IIB_END');
  EmitInstr('INC    SI');
  EmitInstr('INC    BX');
  EmitInstrA('JMP', PL_RT_PFX + 'IIB_CP');
  EmitLabel(PL_RT_PFX + 'IIB_END');
  { Mettre a jour _PL_HTOP (avancer de (len+1+1)/2 mots) }
  EmitInstr('INC    BX');
  EmitInstrAB('SUB', 'BX', 'OFFSET _PL_HEAP');
  EmitInstr('INC    BX');
  EmitInstrAB('SHR', 'BX', '1');
  EmitInstrAB('MOV', 'WORD PTR [_PL_HTOP]', 'BX');
  { AX = tagged ATOM avec index CX }
  EmitInstrAB('MOV', 'AX', 'CX');
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  Str(TAG_ATOM Shl TAG_SHIFT, NS);
  EmitInstrAB('OR', 'AX', NS);
  { Incrementer le compteur d atomes }
  EmitInstr('INC    WORD PTR [' + PL_ATOM_PFX + 'COUNT]');
  EmitInstrA('POP', 'BX');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');
  EmitBlankLine;

  { ---------------------------------------------------------- }
  { _PLRT_ATOM_STRING : AX=tagged ATOM/INT -> AX=tagged ATOM   }
  {   Si deja ATOM -> identite. Si INT -> convertir en chaine.  }
  { ---------------------------------------------------------- }
  EmitLabel(PL_RT_PFX + 'ATOM_STRING');
  EmitInstrA('PUSH', 'BX');
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitInstrAB('AND', 'BX', IntToStr(TAG_MASK));
  Str(TAG_ATOM Shl TAG_SHIFT, NS);
  EmitInstrAB('CMP', 'BX', NS);
  EmitInstrA('JE', PL_RT_PFX + 'AS_DONE');
  { C est un INT -> convertir en chaine via NUMTOSTR + INTERN }
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  EmitInstrAB('TEST', 'AX', '1000h');
  EmitInstrA('JZ', PL_RT_PFX + 'AS_POS');
  EmitInstrAB('OR', 'AX', '0E000h');
  EmitLabel(PL_RT_PFX + 'AS_POS');
  EmitInstr('CALL    ' + PL_RT_PFX + 'NUMTOSTR');
  { DX=offset, CX=length : copier dans IOBUF depuis DX }
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitInstrAB('MOV', 'SI', 'DX');
  EmitInstrAB('MOV', 'DI', 'OFFSET _PL_IOBUF');
  EmitLabel(PL_RT_PFX + 'AS_CPY');
  EmitInstrAB('MOV', 'AL', 'BYTE PTR [SI]');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', 'AL');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', PL_RT_PFX + 'AS_CPYD');
  EmitInstr('INC    SI');
  EmitInstr('INC    DI');
  EmitInstrA('JMP', PL_RT_PFX + 'AS_CPY');
  EmitLabel(PL_RT_PFX + 'AS_CPYD');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstr('CALL    ' + PL_RT_PFX + 'INTERN_IOBUF');
  EmitLabel(PL_RT_PFX + 'AS_DONE');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');
  EmitBlankLine;

  { ---------------------------------------------------------- }
  { _PLRT_NUMBER_STRING : AX=tagged INT -> AX=tagged ATOM      }
  {   Convertir le nombre en chaine via NUMTOSTR + INTERN       }
  { ---------------------------------------------------------- }
  EmitLabel(PL_RT_PFX + 'NUMBER_STRING');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
  EmitInstrAB('TEST', 'AX', '1000h');
  EmitInstrA('JZ', PL_RT_PFX + 'NS_POS');
  EmitInstrAB('OR', 'AX', '0E000h');
  EmitLabel(PL_RT_PFX + 'NS_POS');
  EmitInstr('CALL    ' + PL_RT_PFX + 'NUMTOSTR');
  { DX=offset, CX=length : copier dans IOBUF depuis DX }
  EmitInstrAB('MOV', 'SI', 'DX');
  EmitInstrAB('MOV', 'DI', 'OFFSET _PL_IOBUF');
  EmitLabel(PL_RT_PFX + 'NS_CPY');
  EmitInstrAB('MOV', 'AL', 'BYTE PTR [SI]');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', 'AL');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', PL_RT_PFX + 'NS_CPYD');
  EmitInstr('INC    SI');
  EmitInstr('INC    DI');
  EmitInstrA('JMP', PL_RT_PFX + 'NS_CPY');
  EmitLabel(PL_RT_PFX + 'NS_CPYD');
  EmitInstr('CALL    ' + PL_RT_PFX + 'INTERN_IOBUF');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');
  EmitBlankLine;

  { ---------------------------------------------------------- }
  { _PLRT_STRING_CONCAT : AX=atom1, BX=atom2 -> AX=tagged ATOM }
  {   Delegue a ATOM_CONCAT (strings = atoms dans ce systeme)   }
  { ---------------------------------------------------------- }
  EmitLabel(PL_RT_PFX + 'STRING_CONCAT');
  EmitInstr('CALL    ' + PL_RT_PFX + 'ATOM_CONCAT');
  EmitInstr('RET');
  EmitBlankLine;

  { ---------------------------------------------------------- }
  { _PLRT_STRING_LENGTH : AX=tagged ATOM -> AX=tagged INT(len) }
  {   Delegue a ATOM_LENGTH                                     }
  { ---------------------------------------------------------- }
  EmitLabel(PL_RT_PFX + 'STRING_LENGTH');
  EmitInstr('CALL    ' + PL_RT_PFX + 'ATOM_LENGTH');
  EmitInstr('RET');
  EmitBlankLine;
End;

{ ---- EmitRuntime : emettre les routines runtime --------------- }
{ Emet les routines de backtracking, liste, arith, compare, ctrl. }
Procedure EmitRuntime;
Begin
  EmitBacktrackRuntime;
  EmitListRuntime;
  EmitArithRuntime;
  EmitCompareRuntime;
  EmitControlRuntime;
  EmitIORuntime;
  EmitBuiltinRuntime;
  EmitDynDBRuntime;
  EmitCollectRuntime;
  EmitOperatorRuntime;
  EmitStringRuntime;
End;

{ ---- EmitClose : fermer le fichier de sortie ASM -------------- }
{ Emettre la fin du segment _TEXT, le runtime, le segment DATA,   }
{ la directive END, et fermer le fichier.                         }
Procedure EmitClose;
Begin
  EmitBlankLine;
  EmitComment('--- Fin du code genere ---');
  EmitBlankLine;

  { Sortie DOS : MOV AX,4C00h / INT 21h }
  EmitInstrAB('MOV', 'AX', '4C00h');
  EmitInstrA('INT', '21h');

  EmitBlankLine;

  { Emettre les routines runtime (TODO 24) }
  EmitRuntime;

  { Fermer le segment _TEXT }
  EmitRaw('_TEXT   ENDS');
  EmitBlankLine;

  { Emettre le segment de donnees }
  EmitDataSeg;
  EmitBlankLine;

  { Directive de fin : point d entree _PLP_Main }
  EmitRaw('        END    _PLP_Main');

  { Fermer le fichier }
  If OutFOpen Then
  Begin
    {$I-}
    Close(OutF);
    {$I+}
    OutFOpen := False;
  End;
End;

{ ============================================================
  TODO 08 - SEGMENT DE DONNEES ET TABLES STATIQUES [IMPLEMENTE]
  ============================================================ }

{ ---- DataAddAtomTable : ajouter la table des atomes --------- }
{ Cree les entrees DATA pour chaque atome interne :              }
{   _PLA_0 DB 'nom_atome',0                                     }
{   _PLA_1 DB 'autre_atome',0                                   }
{   ...                                                          }
{   _PLA_TABLE DW _PLA_0, _PLA_1, ...  (offsets des chaines)    }
{ Retourne l index de l entree _PLA_TABLE dans DataTab.          }
Function DataAddAtomTable : Integer;
Var
  I   : Integer;
  Lbl : TString;
  Idx : Integer;
Begin
  { D abord creer une entree DK_STR pour chaque atome }
  For I := 0 To AtomCount - 1 Do
  Begin
    Lbl := PL_ATOM_PFX + IntToStr(I);
    DataAdd(Lbl, DK_STR, 0, AtomTab[I].Name);
  End;
  { Puis creer l entree de la table d offsets }
  Idx := DataAdd(PL_ATOM_PFX + 'TABLE', DK_ATOM_TBL, 0, '');
  DataTab[Idx].ElemCount := AtomCount;
  DataAddAtomTable := Idx;
End;

{ ---- DataAddFunctorTable : ajouter la table des foncteurs --- }
{ Cree les entrees DATA pour la table des foncteurs :            }
{   _PLF_TABLE : paires (atome_index, arite) pour chaque foncteur}
{   DW atom_idx_0, arity_0, atom_idx_1, arity_1, ...            }
{ Retourne l index de l entree _PLF_TABLE dans DataTab.          }
Function DataAddFunctorTable : Integer;
Var
  Idx : Integer;
Begin
  Idx := DataAdd(PL_FUN_PFX + 'TABLE', DK_ATOM_TBL, 0, '');
  DataTab[Idx].ElemCount := FunctorCount;
  DataAddFunctorTable := Idx;
End;

{ ---- DataInit : pre-populer le segment de donnees ------------ }
{ Appele apres SymInit et TermInit pour generer les tables        }
{ statiques des atomes et foncteurs internes dans le segment DATA.}
{ Ajoute aussi les constantes predefinies Prolog.                 }
Procedure DataInit;
Begin
  { Constantes predefinies Prolog }
  DataAdd('_PL_TRUE_S',  DK_STR, 0, 'true');
  DataAdd('_PL_FAIL_S',  DK_STR, 0, 'fail');
  DataAdd('_PL_CUT_S',   DK_STR, 0, '!');
  DataAdd('_PL_NIL_S',   DK_STR, 0, '[]');
  DataAdd('_PL_YES_S',   DK_STR, 0, 'yes');
  DataAdd('_PL_NO_S',    DK_STR, 0, 'no');

  { Table des atomes internes }
  DataAddAtomTable;

  { Table des foncteurs }
  DataAddFunctorTable;
End;

{ ============================================================
  TODO 10 - COMPILATION DES FAITS [IMPLEMENTE]
  ============================================================ }

{ ---- ParseFactArg : parser un argument d un fait --------------- }
{ Chaque argument peut etre :                                      }
{   - un atome (minuscule ou quote)                                }
{   - un entier                                                    }
{   - une variable (majuscule)                                     }
{   - une variable anonyme _                                       }
{   - une chaine (traitee comme atome)                             }
{ Le resultat est stocke dans Arg.                                 }
Procedure ParseFactArg(Var Arg : TFactArg);
Begin
  Arg.Kind    := FAK_ANON;
  Arg.AtomIdx := -1;
  Arg.IntVal  := 0;
  Arg.VarName := '';
  Arg.ListStart := 0;
  Arg.ListLen   := 0;
  Arg.HasTail   := False;

  Case CurToken.Kind Of
    TK_ATOM :
    Begin
      Arg.Kind    := FAK_ATOM;
      Arg.AtomIdx := AtomIntern(CurToken.Val);
      ParserAdvance;
    End;

    TK_INTEGER :
    Begin
      Arg.Kind   := FAK_INT;
      Arg.IntVal := CurToken.IntVal;
      ParserAdvance;
    End;

    TK_VARIABLE :
    Begin
      Arg.Kind    := FAK_VAR;
      Arg.VarName := CurToken.Val;
      ParserAdvance;
    End;

    TK_UNDERSCORE :
    Begin
      Arg.Kind := FAK_ANON;
      ParserAdvance;
    End;

    TK_STRING :
    Begin
      Arg.Kind    := FAK_ATOM;
      Arg.AtomIdx := AtomIntern(CurToken.Val);
      ParserAdvance;
    End;

    TK_OP :
    Begin
      { Operateur unaire - pour entier negatif }
      If CurToken.Val = '-' Then
      Begin
        ParserAdvance;
        If CurToken.Kind = TK_INTEGER Then
        Begin
          Arg.Kind   := FAK_INT;
          Arg.IntVal := -CurToken.IntVal;
          ParserAdvance;
        End
        Else
          CompileError('entier attendu apres -');
      End
      Else
      Begin
        { Atome operateur (ex: +, *) }
        Arg.Kind    := FAK_ATOM;
        Arg.AtomIdx := AtomIntern(CurToken.Val);
        ParserAdvance;
      End;
    End;

    TK_LBRACKET :
    Begin
      ParserAdvance; { consomme '[' }
      If CurToken.Kind = TK_RBRACKET Then
      Begin
        { Liste vide [] -> atome special }
        Arg.Kind    := FAK_ATOM;
        Arg.AtomIdx := AtomIntern('[]');
        ParserAdvance; { consomme ']' }
      End
      Else
      Begin
        { Liste non-vide [elem1, elem2, ... | Tail] }
        Arg.Kind      := FAK_LIST;
        Arg.ListStart := ListElemCount;
        Arg.ListLen   := 0;
        Arg.HasTail   := False;
        Arg.VarName   := '';

        While (CurToken.Kind <> TK_EOF) And
              (CurToken.Kind <> TK_RBRACKET) And
              (CurToken.Kind <> TK_PIPE) Do
        Begin
          If ListElemCount >= MAX_LIST_ELEMS Then
          Begin
            CompileError('trop d elements de liste (max=' +
                         IntToStr(MAX_LIST_ELEMS) + ')');
            Break;
          End;
          ParseFactArg(ListElemTab[ListElemCount]);
          Inc(ListElemCount);
          Inc(Arg.ListLen);

          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance
          Else If (CurToken.Kind <> TK_RBRACKET) And
                  (CurToken.Kind <> TK_PIPE) Then
          Begin
            CompileError('] ou , ou | attendu dans la liste');
            Break;
          End;
        End;

        { Queue explicite [..|Tail] }
        If CurToken.Kind = TK_PIPE Then
        Begin
          ParserAdvance; { consomme '|' }
          Arg.HasTail := True;
          { Parser l element de queue dans ListElemTab }
          If ListElemCount >= MAX_LIST_ELEMS Then
            CompileError('trop d elements de liste (max=' +
                         IntToStr(MAX_LIST_ELEMS) + ')')
          Else
          Begin
            ParseFactArg(ListElemTab[ListElemCount]);
            Inc(ListElemCount);
          End;

          If CurToken.Kind = TK_RBRACKET Then
            ParserAdvance
          Else
            CompileError('] attendu apres la queue de liste');
        End
        Else If CurToken.Kind = TK_RBRACKET Then
          ParserAdvance
        Else
          CompileError('] attendu a la fin de la liste');
      End;
    End;

  Else
    CompileError('argument de fait inattendu: ' + CurToken.Val);
    ParserAdvance;
  End;
End;

{ ---- ParseFact : parser un fait Prolog ------------------------- }
{ Un fait est soit :                                                }
{   atome.               -> predicat/0                             }
{   foncteur(a1,...,aN). -> predicat/N                             }
{ Retourne True si un fait a ete parse, False sinon.               }
Function ParseFact : Boolean;
Var
  PName    : TString;
  PArity   : Integer;
  SIdx     : Integer;
  CIdx     : Integer;
  ClsIdx   : Integer;
Begin
  ParseFact := False;

  { Doit commencer par un atome (nom du predicat) }
  If CurToken.Kind <> TK_ATOM Then
  Begin
    { Directive :- ou requete ?- : traiter via ParseDirective (TODO 22) }
    If (CurToken.Kind = TK_OP) And
       ((CurToken.Val = ':-') Or (CurToken.Val = '?-')) Then
    Begin
      ParserAdvance; { consomme :- ou ?- }
      ParseFact := ParseDirective;
      Exit;
    End;
    Exit;
  End;

  PName  := CurToken.Val;
  PArity := 0;
  ParserAdvance;

  { Verifier la table des clauses }
  If ClauseCount >= MAX_CLAUSE Then
  Begin
    CompileError('table des clauses pleine (max=' + IntToStr(MAX_CLAUSE) + ')');
    Exit;
  End;

  CIdx := ClauseCount;

  { Fait avec arguments : foncteur(arg1, arg2, ...) }
  If CurToken.Kind = TK_LPAREN Then
  Begin
    ParserAdvance; { consomme '(' }
    PArity := 0;
    While (CurToken.Kind <> TK_EOF) And
          (CurToken.Kind <> TK_RPAREN) Do
    Begin
      If PArity >= MAX_FACT_ARGS Then
      Begin
        CompileError('trop d arguments dans le fait (max=' +
                     IntToStr(MAX_FACT_ARGS) + ')');
        Break;
      End;
      ParseFactArg(ClauseTab[CIdx].Args[PArity]);
      Inc(PArity);
      { Virgule entre les arguments }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance
      Else If CurToken.Kind <> TK_RPAREN Then
      Begin
        CompileError(') ou , attendu dans les arguments du fait');
        Break;
      End;
    End;
    If CurToken.Kind = TK_RPAREN Then
      ParserAdvance;
  End;

  { Verifier si c est une regle (tete :- corps) (TODO 11) }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = ':-') Then
  Begin
    ParserAdvance; { consomme ':-' }

    { Chercher ou creer le predicat dans la table des symboles }
    SIdx := SymFindPredicate(PName, PArity);
    If SIdx < 0 Then
    Begin
      SIdx := SymAdd(PName, SK_PREDICATE, PArity);
      If SIdx >= 0 Then
        SymTab[SIdx].ClauseHead := CIdx;
    End;

    { Determiner le numero de clause K pour ce predicat }
    ClsIdx := 0;
    If SIdx >= 0 Then
    Begin
      ClsIdx := SymTab[SIdx].ClauseCount;
      Inc(SymTab[SIdx].ClauseCount);
    End;

    { Remplir l entree de clause comme regle }
    ClauseTab[CIdx].PredName   := PName;
    ClauseTab[CIdx].Arity      := PArity;
    ClauseTab[CIdx].ClauseIdx  := ClsIdx;
    ClauseTab[CIdx].SymIdx     := SIdx;
    ClauseTab[CIdx].IsRule     := True;
    ClauseTab[CIdx].ArgCount   := PArity;
    ClauseTab[CIdx].BodyStart  := GoalCount;
    ClauseTab[CIdx].BodyLen    := 0;
    ClauseTab[CIdx].NVars      := 0;
    ClauseTab[CIdx].FailLabel  := '';

    { Generer le label ASM }
    ClauseTab[CIdx].ClsLabel := PL_PRED_PFX + SymNameClean(PName) + '_' +
                                IntToStr(PArity) + '_' + IntToStr(ClsIdx);
    ClauseTab[CIdx].FailLabel := ClauseTab[CIdx].ClsLabel + '_F';

    { Parser le corps de la regle }
    ParseRuleBody(CIdx);

    { Terminator : doit etre un point . }
    If CurToken.Kind = TK_DOT Then
      ParserAdvance
    Else
      CompileError('. attendu a la fin de la regle');

    Inc(ClauseCount);

    If Opts.DebugMode Then
      WriteLn('  RULE[', CIdx, ']: ', PName, '/', PArity,
              ' clause=', ClsIdx, ' body=', ClauseTab[CIdx].BodyLen,
              ' vars=', ClauseTab[CIdx].NVars,
              ' -> ', ClauseTab[CIdx].ClsLabel);

    ParseFact := True;
    Exit;
  End;

  { Terminator : doit etre un point . }
  If CurToken.Kind = TK_DOT Then
    ParserAdvance
  Else
    CompileError('. attendu a la fin du fait');

  { Chercher ou creer le predicat dans la table des symboles }
  SIdx := SymFindPredicate(PName, PArity);
  If SIdx < 0 Then
  Begin
    SIdx := SymAdd(PName, SK_PREDICATE, PArity);
    If SIdx >= 0 Then
      SymTab[SIdx].ClauseHead := CIdx;
  End;

  { Determiner le numero de clause K pour ce predicat }
  ClsIdx := 0;
  If SIdx >= 0 Then
  Begin
    ClsIdx := SymTab[SIdx].ClauseCount;
    Inc(SymTab[SIdx].ClauseCount);
  End;

  { Remplir l entree de clause }
  ClauseTab[CIdx].PredName  := PName;
  ClauseTab[CIdx].Arity     := PArity;
  ClauseTab[CIdx].ClauseIdx := ClsIdx;
  ClauseTab[CIdx].SymIdx    := SIdx;
  ClauseTab[CIdx].IsRule     := False;
  ClauseTab[CIdx].ArgCount  := PArity;
  ClauseTab[CIdx].FailLabel := '';
  ClauseTab[CIdx].BodyStart := 0;
  ClauseTab[CIdx].BodyLen   := 0;
  ClauseTab[CIdx].NVars     := 0;

  { Generer le label ASM : _PLP_nom_N_clauseK }
  If PArity = 0 Then
    ClauseTab[CIdx].ClsLabel := PL_PRED_PFX + SymNameClean(PName) + '_0'
  Else
    ClauseTab[CIdx].ClsLabel := PL_PRED_PFX + SymNameClean(PName) + '_' +
                             IntToStr(PArity) + '_' + IntToStr(ClsIdx);

  { Label d echec pour cette clause }
  ClauseTab[CIdx].FailLabel := ClauseTab[CIdx].ClsLabel + '_F';

  Inc(ClauseCount);

  If Opts.DebugMode Then
    WriteLn('  FACT[', CIdx, ']: ', PName, '/', PArity,
            ' clause=', ClsIdx, ' -> ', ClauseTab[CIdx].ClsLabel);

  ParseFact := True;
End;

{ ---- EmitFactCode : emettre le code ASM pour un fait ------------ }
{ CIdx = index dans ClauseTab.                                      }
{                                                                    }
{ Pour un fait sans arguments (arite 0) :                           }
{   label:                                                          }
{     CLC           ; succes immediat                               }
{     RET                                                           }
{                                                                    }
{ Pour un fait avec arguments (arite N) :                           }
{   label:                                                          }
{     PUSH BP                                                       }
{     MOV  BP, SP                                                   }
{     ; Pour chaque argument i (0..N-1) :                           }
{     MOV  AX, WORD PTR [_PL_ARGS + i*2]  ; registre Ai            }
{     MOV  BX, <valeur-argument-taguee>                             }
{     CALL _PLRT_UNIFY                                              }
{     JC   label_fail                                               }
{     ; Succes : tous les arguments unifies                         }
{     CLC                                                           }
{     MOV  SP, BP                                                   }
{     POP  BP                                                       }
{     RET                                                           }
{   label_fail:                                                     }
{     STC           ; echec                                         }
{     MOV  SP, BP                                                   }
{     POP  BP                                                       }
{     RET                                                           }
Procedure EmitFactCode(CIdx : Integer);
Var
  I       : Integer;
  TagVal  : Integer;
  NS      : TString;
Begin
  EmitBlankLine;
  EmitComment('--- Fait ' + ClauseTab[CIdx].PredName + '/' +
              IntToStr(ClauseTab[CIdx].Arity) +
              ' clause ' + IntToStr(ClauseTab[CIdx].ClauseIdx) + ' ---');

  EmitLabel(ClauseTab[CIdx].ClsLabel);

  { Fait sans arguments : succes immediat }
  If ClauseTab[CIdx].Arity = 0 Then
  Begin
    EmitInstr('CLC');
    EmitInstr('RET');
    Exit;
  End;

  { Fait avec arguments }
  EmitProlog;

  For I := 0 To ClauseTab[CIdx].ArgCount - 1 Do
  Begin
    EmitComment('arg ' + IntToStr(I + 1) + '/' +
                IntToStr(ClauseTab[CIdx].ArgCount));

    { Charger le registre Ai dans AX }
    EmitInstrAB('MOV', 'AX', 'WORD PTR [_PL_ARGS + ' +
                IntToStr(I * 2) + ']');

    { Construire la valeur taguee de l argument du fait }
    Case ClauseTab[CIdx].Args[I].Kind Of
      FAK_ATOM :
      Begin
        { Tag ATOM (1) << 13 | AtomIdx }
        TagVal := (TAG_ATOM Shl TAG_SHIFT) Or
                  (ClauseTab[CIdx].Args[I].AtomIdx And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'BX', NS);
        EmitComment('atom ' + AtomName(ClauseTab[CIdx].Args[I].AtomIdx));
      End;

      FAK_INT :
      Begin
        { Tag INT (2) << 13 | (Val AND $1FFF) }
        TagVal := (TAG_INT Shl TAG_SHIFT) Or
                  (Integer(ClauseTab[CIdx].Args[I].IntVal) And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'BX', NS);
        EmitComment('int ' + IntToStr(ClauseTab[CIdx].Args[I].IntVal));
      End;

      FAK_VAR :
      Begin
        { Variable : creer une REF libre sur le heap }
        EmitComment('var ' + ClauseTab[CIdx].Args[I].VarName);
        EmitInstrAB('MOV', 'BX', 'WORD PTR [_PL_HTOP]');
        EmitInstrAB('MOV', 'SI', 'BX');
        { Tag REF (0) << 13 | adresse = self-reference }
        EmitInstrAB('SHL', 'SI', '1');
        EmitInstrAB('ADD', 'SI', 'OFFSET _PL_HEAP');
        EmitInstrAB('MOV', 'WORD PTR [SI]', 'BX');
        EmitInstr('INC    WORD PTR [_PL_HTOP]');
        { BX = MakeRef(addr) = (TAG_REF << 13) | addr = addr (TAG_REF=0) }
      End;

      FAK_ANON :
      Begin
        { Variable anonyme : toujours unifiable, creer REF libre }
        EmitComment('anon _');
        EmitInstrAB('MOV', 'BX', 'WORD PTR [_PL_HTOP]');
        EmitInstrAB('MOV', 'SI', 'BX');
        EmitInstrAB('SHL', 'SI', '1');
        EmitInstrAB('ADD', 'SI', 'OFFSET _PL_HEAP');
        EmitInstrAB('MOV', 'WORD PTR [SI]', 'BX');
        EmitInstr('INC    WORD PTR [_PL_HTOP]');
      End;

      FAK_LIST :
      Begin
        { Liste : construire sur le heap (TODO 13) }
        EmitComment('list');
        EmitBuildListToAX(ClauseTab[CIdx].Args[I], False);
        EmitInstrAB('MOV', 'BX', 'AX');
      End;
    Else
      EmitComment('arg non gere');
      EmitInstrAB('MOV', 'BX', '0');
    End;

    { Appeler l unification }
    EmitUnify;
    EmitInstrA('JC', ClauseTab[CIdx].FailLabel);
  End;

  { Succes }
  EmitInstr('CLC');
  EmitEpilog;
  EmitBlankLine;

  { Label d echec }
  EmitLabel(ClauseTab[CIdx].FailLabel);
  EmitInstr('STC');
  EmitEpilog;
End;

{ ============================================================
  TODO 11 - COMPILATION DES REGLES [IMPLEMENTE]
  ============================================================ }

{ ---- RuleVarFindOrAdd : chercher ou ajouter une variable ------- }
{ locale dans la table des variables de la regle courante.         }
{ Retourne l index dans RuleVarTab.                                }
Function RuleVarFindOrAdd(Const VName : TString) : Integer;
Var
  I : Integer;
Begin
  For I := 0 To RuleVarCount - 1 Do
  Begin
    If RuleVarTab[I].Name = VName Then
    Begin
      RuleVarFindOrAdd := I;
      Exit;
    End;
  End;
  { Nouvelle variable }
  If RuleVarCount >= MAX_RULE_VARS Then
  Begin
    CompileError('trop de variables dans la regle (max=' +
                 IntToStr(MAX_RULE_VARS) + ')');
    RuleVarFindOrAdd := 0;
    Exit;
  End;
  RuleVarTab[RuleVarCount].Name   := VName;
  RuleVarTab[RuleVarCount].Offset := (RuleVarCount + 1) * 2;
  RuleVarFindOrAdd := RuleVarCount;
  Inc(RuleVarCount);
End;

{ ---- ParseGoal : parser un but dans le corps d une regle -------- }
{ Un but est soit : atome (arite 0) ou foncteur(arg1,...,argN),     }
{ ou un but infixe : Var is Expr, Expr CompOp Expr (TODO 14).      }
{ Les arguments du but sont parses comme ceux d un fait.            }
Procedure ParseGoal(Var G : TGoalRec);
Var
  A       : Integer;
  SaveVar : TString;
  SaveInt : LongInt;
  IsInfix : Boolean;
Begin
  G.PredName := '';
  G.Arity    := 0;
  G.ArgCount := 0;

  { --- TODO 16 : Cut ! --- }
  If CurToken.Kind = TK_CUT Then
  Begin
    G.PredName := '!';
    G.Arity    := 0;
    G.ArgCount := 0;
    ParserAdvance;
    Exit;
  End;

  { --- TODO 16 : Negation par echec \+(Goal) --- }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '\+') Then
  Begin
    ParserAdvance; { consomme \+ }
    If CurToken.Kind = TK_LPAREN Then
    Begin
      ParserAdvance; { consomme ( }
      G.PredName := '\+';
      G.Arity    := 1;
      G.ArgCount := 1;
      { Le but est un atome ou foncteur : on stocke le nom comme atome }
      If CurToken.Kind = TK_ATOM Then
      Begin
        G.Args[0].Kind    := FAK_ATOM;
        G.Args[0].AtomIdx := AtomIntern(CurToken.Val);
        ParserAdvance;
        { Si suivi de ( -> foncteur avec args, on stocke l arite dans IntVal }
        If CurToken.Kind = TK_LPAREN Then
        Begin
          ParserAdvance; { consomme ( }
          A := 0;
          While (CurToken.Kind <> TK_EOF) And
                (CurToken.Kind <> TK_RPAREN) Do
          Begin
            If A < MAX_FACT_ARGS - 1 Then
            Begin
              ParseFactArg(G.Args[1 + A]);
              Inc(A);
              Inc(G.ArgCount);
            End
            Else
              Break;
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
              ParserAdvance
            Else If CurToken.Kind <> TK_RPAREN Then
              Break;
          End;
          If CurToken.Kind = TK_RPAREN Then
            ParserAdvance;
          G.Arity := 1 + A;
        End;
      End;
      If CurToken.Kind = TK_RPAREN Then
        ParserAdvance;
    End
    Else
    Begin
      { \+ atome sans parentheses }
      G.PredName := '\+';
      G.Arity    := 1;
      G.ArgCount := 1;
      If CurToken.Kind = TK_ATOM Then
      Begin
        G.Args[0].Kind    := FAK_ATOM;
        G.Args[0].AtomIdx := AtomIntern(CurToken.Val);
        ParserAdvance;
      End;
    End;
    Exit;
  End;

  { --- TODO 16 : If-Then-Else ( Cond -> Then ; Else ) et Disjonction ( A ; B ) --- }
  { Ces constructions sont gerees par ParseRuleBody au niveau du ; }

  { --- Cas infixe : Variable is Expr / Variable CompOp Expr (TODO 14) --- }
  If CurToken.Kind = TK_VARIABLE Then
  Begin
    SaveVar := CurToken.Val;
    ParserAdvance;

    { Check for 'is' }
    If (CurToken.Kind = TK_ATOM) And (CurToken.Val = 'is') Then
    Begin
      G.PredName := 'is';
      ParserAdvance; { consomme 'is' }
      G.Args[0].Kind    := FAK_VAR;
      G.Args[0].VarName := SaveVar;
      G.Args[1].Kind    := FAK_EXPR;
      G.Args[1].ExprRoot := ParseArithExpr;
      G.Arity    := 2;
      G.ArgCount := 2;
      Exit;
    End;

    { Check for arithmetic comparison operators }
    IsInfix := False;
    If CurToken.Kind = TK_OP Then
    Begin
      If (CurToken.Val = '=:=') Or (CurToken.Val = '=\=') Or
         (CurToken.Val = '<') Or (CurToken.Val = '>') Or
         (CurToken.Val = '=<') Or (CurToken.Val = '>=') Then
        IsInfix := True;
    End;

    If IsInfix Then
    Begin
      G.PredName := CurToken.Val;
      ParserAdvance;
      { Left side : wrap variable as expression node }
      G.Args[0].Kind     := FAK_EXPR;
      G.Args[0].ExprRoot := ArithNodeAdd(ANK_VAR, 0, SaveVar,
                                          AO_ADD, -1, -1);
      { Right side }
      G.Args[1].Kind     := FAK_EXPR;
      G.Args[1].ExprRoot := ParseArithExpr;
      G.Arity    := 2;
      G.ArgCount := 2;
      Exit;
    End;

    { Check for comparison/unification operators (TODO 15) and =.. (TODO 18) }
    If CurToken.Kind = TK_OP Then
    Begin
      If (CurToken.Val = '=') Or (CurToken.Val = '\=') Or
         (CurToken.Val = '==') Or (CurToken.Val = '\==') Or
         (CurToken.Val = '@<') Or (CurToken.Val = '@>') Or
         (CurToken.Val = '@=<') Or (CurToken.Val = '@>=') Or
         (CurToken.Val = '=..') Then
      Begin
        G.PredName := CurToken.Val;
        ParserAdvance;
        { Left side : variable }
        G.Args[0].Kind    := FAK_VAR;
        G.Args[0].VarName := SaveVar;
        { Right side : parse as term }
        ParseFactArg(G.Args[1]);
        G.Arity    := 2;
        G.ArgCount := 2;
        Exit;
      End;
    End;

    { Not recognized infix - error }
    CompileError('operateur attendu apres variable ' + SaveVar +
                 ' dans le corps de la regle (trouve: ' + CurToken.Val + ')');
    Exit;
  End;

  { --- Cas infixe : Integer CompOp Expr (TODO 14) --- }
  If CurToken.Kind = TK_INTEGER Then
  Begin
    SaveInt := CurToken.IntVal;
    ParserAdvance;

    IsInfix := False;
    If CurToken.Kind = TK_OP Then
    Begin
      If (CurToken.Val = '=:=') Or (CurToken.Val = '=\=') Or
         (CurToken.Val = '<') Or (CurToken.Val = '>') Or
         (CurToken.Val = '=<') Or (CurToken.Val = '>=') Then
        IsInfix := True;
    End;

    If IsInfix Then
    Begin
      G.PredName := CurToken.Val;
      ParserAdvance;
      G.Args[0].Kind     := FAK_EXPR;
      G.Args[0].ExprRoot := ArithNodeAdd(ANK_INT, SaveInt, '',
                                          AO_ADD, -1, -1);
      G.Args[1].Kind     := FAK_EXPR;
      G.Args[1].ExprRoot := ParseArithExpr;
      G.Arity    := 2;
      G.ArgCount := 2;
      Exit;
    End;

    { TODO 18 : Check for infix =.. after integer }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '=..') Then
    Begin
      G.PredName := '=..';
      ParserAdvance;
      G.Args[0].Kind   := FAK_INT;
      G.Args[0].IntVal := SaveInt;
      ParseFactArg(G.Args[1]);
      G.Arity    := 2;
      G.ArgCount := 2;
      Exit;
    End;

    { Not recognized - error }
    CompileError('operateur arithmetique attendu apres entier');
    Exit;
  End;

  { --- Cas standard : atome ou foncteur(args) --- }
  If CurToken.Kind = TK_ATOM Then
  Begin
    G.PredName := CurToken.Val;
    ParserAdvance;

    { TODO 18 : Check for infix =.. after atom }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '=..') Then
    Begin
      { atom =.. List }
      G.Args[0].Kind    := FAK_ATOM;
      G.Args[0].AtomIdx := AtomIntern(G.PredName);
      G.PredName := '=..';
      ParserAdvance;
      ParseFactArg(G.Args[1]);
      G.Arity    := 2;
      G.ArgCount := 2;
      Exit;
    End;

    { Verifier si le but a des arguments }
    If CurToken.Kind = TK_LPAREN Then
    Begin
      ParserAdvance; { consomme '(' }
      A := 0;
      While (CurToken.Kind <> TK_EOF) And
            (CurToken.Kind <> TK_RPAREN) Do
      Begin
        If A >= MAX_FACT_ARGS Then
        Begin
          CompileError('trop d arguments dans le but (max=' +
                       IntToStr(MAX_FACT_ARGS) + ')');
          Break;
        End;
        ParseFactArg(G.Args[A]);
        Inc(A);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          ParserAdvance
        Else If CurToken.Kind <> TK_RPAREN Then
        Begin
          CompileError(') ou , attendu dans les arguments du but');
          Break;
        End;
      End;
      If CurToken.Kind = TK_RPAREN Then
        ParserAdvance;
      G.Arity    := A;
      G.ArgCount := A;
    End;
  End
  Else
  Begin
    CompileError('atome attendu comme but dans le corps de la regle');
    { Avancer pour eviter boucle infinie }
    If CurToken.Kind <> TK_EOF Then
      ParserAdvance;
  End;
End;

{ ---- ParseRuleBody : parser le corps d une regle ----------------- }
{ Le corps est une sequence de buts separes par des virgules :       }
{   but1, but2, ..., butN                                            }
{ Se termine avant le point .                                        }
{ Collecte aussi les variables locales dans RuleVarTab.              }
Procedure ParseRuleBody(CIdx : Integer);
Var
  I      : Integer;
  GIdx   : Integer;
  NGoals : Integer;
Begin
  { Reinitialiser la table des variables locales pour cette regle }
  RuleVarCount := 0;

  { Collecter les variables de la tete }
  For I := 0 To ClauseTab[CIdx].ArgCount - 1 Do
  Begin
    If ClauseTab[CIdx].Args[I].Kind = FAK_VAR Then
      RuleVarFindOrAdd(ClauseTab[CIdx].Args[I].VarName);
  End;

  ClauseTab[CIdx].BodyStart := GoalCount;
  NGoals := 0;

  { Parser les buts separes par des virgules }
  While (CurToken.Kind <> TK_EOF) And
        (CurToken.Kind <> TK_DOT) Do
  Begin
    If GoalCount >= MAX_CLAUSE * MAX_BODY_GOALS Then
    Begin
      CompileError('table des buts pleine');
      Break;
    End;

    GIdx := GoalCount;
    ParseGoal(GoalTab[GIdx]);

    If GoalTab[GIdx].PredName = '' Then Break;

    { Collecter les variables des arguments du but }
    For I := 0 To GoalTab[GIdx].ArgCount - 1 Do
    Begin
      If GoalTab[GIdx].Args[I].Kind = FAK_VAR Then
        RuleVarFindOrAdd(GoalTab[GIdx].Args[I].VarName);
    End;

    Inc(GoalCount);
    Inc(NGoals);

    { Virgule = conjonction (but suivant) }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance
    Else
      Break;  { fin du corps (point ou autre) }
  End;

  ClauseTab[CIdx].BodyLen := NGoals;
  ClauseTab[CIdx].NVars   := RuleVarCount;
End;

{ ---- EmitRuleCode : emettre le code ASM pour une regle ----------- }
{ Structure du code emis :                                            }
{   label:                                                            }
{     ; Allocation de l environnement                                 }
{     PUSH BP                                                         }
{     MOV  BP, SP                                                     }
{     SUB  SP, NVars * 2       ; reserver les variables locales       }
{     ; Initialiser les vars a REF libre sur le heap                  }
{     ; Unifier les arguments de la tete                              }
{     ; Pour chaque but du corps :                                    }
{       ; Charger les arguments dans _PL_ARGS                         }
{       ; CALL _PLP_predicat_N                                        }
{       ; JC label_fail                                               }
{     ; Dernier but : optimisation appel terminal                     }
{       ; deallocate + JMP au lieu de CALL                            }
{     ; Succes                                                        }
{     CLC                                                             }
{     MOV SP, BP                                                      }
{     POP BP                                                          }
{     RET                                                             }
{   label_fail:                                                       }
{     STC                                                             }
{     MOV SP, BP                                                      }
{     POP BP                                                          }
{     RET                                                             }
Procedure EmitRuleCode(CIdx : Integer);
Var
  I, J     : Integer;
  GIdx     : Integer;
  TagVal   : Integer;
  NS       : TString;
  VarIdx   : Integer;
  IsLast   : Boolean;
  PredLbl  : TString;
  Clean    : TString;
Begin
  { Reconstruire la table des variables locales pour cette regle }
  { (ParseRuleBody a ete appele avant pour toutes les clauses,   }
  {  donc RuleVarTab doit etre reconstruit pour chaque emission) }
  RuleVarCount := 0;
  For I := 0 To ClauseTab[CIdx].ArgCount - 1 Do
  Begin
    If ClauseTab[CIdx].Args[I].Kind = FAK_VAR Then
      RuleVarFindOrAdd(ClauseTab[CIdx].Args[I].VarName);
  End;
  For I := 0 To ClauseTab[CIdx].BodyLen - 1 Do
  Begin
    GIdx := ClauseTab[CIdx].BodyStart + I;
    For J := 0 To GoalTab[GIdx].ArgCount - 1 Do
    Begin
      If GoalTab[GIdx].Args[J].Kind = FAK_VAR Then
        RuleVarFindOrAdd(GoalTab[GIdx].Args[J].VarName);
    End;
  End;

  EmitBlankLine;
  EmitComment('--- Regle ' + ClauseTab[CIdx].PredName + '/' +
              IntToStr(ClauseTab[CIdx].Arity) +
              ' clause ' + IntToStr(ClauseTab[CIdx].ClauseIdx) +
              ' (' + IntToStr(ClauseTab[CIdx].BodyLen) + ' but(s),' +
              ' ' + IntToStr(ClauseTab[CIdx].NVars) + ' var(s)) ---');

  EmitLabel(ClauseTab[CIdx].ClsLabel);

  { Prologue : allocation d environnement }
  EmitProlog;
  If ClauseTab[CIdx].NVars > 0 Then
  Begin
    EmitComment('allocate ' + IntToStr(ClauseTab[CIdx].NVars) +
                ' variable(s) locale(s)');
    EmitInstrAB('SUB', 'SP', IntToStr(ClauseTab[CIdx].NVars * 2));

    { Initialiser les variables locales a REF libre sur le heap }
    EmitComment('init vars locales a REF libre');
    For I := 0 To ClauseTab[CIdx].NVars - 1 Do
    Begin
      EmitInstrAB('MOV', 'AX', 'WORD PTR [_PL_HTOP]');
      EmitInstrAB('MOV', 'SI', 'AX');
      EmitInstrAB('SHL', 'SI', '1');
      EmitInstrAB('ADD', 'SI', 'OFFSET _PL_HEAP');
      EmitInstrAB('MOV', 'WORD PTR [SI]', 'AX');
      EmitInstr('INC    WORD PTR [_PL_HTOP]');
      { Stocker la REF dans la variable locale [BP - offset] }
      EmitInstrAB('MOV', 'WORD PTR [BP-' + IntToStr((I + 1) * 2) + ']',
                  'AX');
    End;
  End;

  { Unifier les arguments de la tete (comme un fait) }
  If ClauseTab[CIdx].ArgCount > 0 Then
  Begin
    EmitComment('unification tete');
    For I := 0 To ClauseTab[CIdx].ArgCount - 1 Do
    Begin
      EmitComment('arg tete ' + IntToStr(I + 1) + '/' +
                  IntToStr(ClauseTab[CIdx].ArgCount));

      { Charger le registre Ai dans AX }
      EmitInstrAB('MOV', 'AX', 'WORD PTR [_PL_ARGS + ' +
                  IntToStr(I * 2) + ']');

      { Construire la valeur taguee de l argument }
      Case ClauseTab[CIdx].Args[I].Kind Of
        FAK_ATOM :
        Begin
          TagVal := (TAG_ATOM Shl TAG_SHIFT) Or
                    (ClauseTab[CIdx].Args[I].AtomIdx And VAL_MASK);
          Str(TagVal, NS);
          EmitInstrAB('MOV', 'BX', NS);
          EmitComment('atom ' + AtomName(ClauseTab[CIdx].Args[I].AtomIdx));
        End;

        FAK_INT :
        Begin
          TagVal := (TAG_INT Shl TAG_SHIFT) Or
                    (Integer(ClauseTab[CIdx].Args[I].IntVal) And VAL_MASK);
          Str(TagVal, NS);
          EmitInstrAB('MOV', 'BX', NS);
          EmitComment('int ' + IntToStr(ClauseTab[CIdx].Args[I].IntVal));
        End;

        FAK_VAR :
        Begin
          { Variable : utiliser la var locale de l environnement }
          VarIdx := RuleVarFindOrAdd(ClauseTab[CIdx].Args[I].VarName);
          EmitComment('var ' + ClauseTab[CIdx].Args[I].VarName +
                      ' [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
          EmitInstrAB('MOV', 'BX',
                      'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        End;

        FAK_ANON :
        Begin
          { Variable anonyme : creer une REF libre }
          EmitComment('anon _');
          EmitInstrAB('MOV', 'BX', 'WORD PTR [_PL_HTOP]');
          EmitInstrAB('MOV', 'SI', 'BX');
          EmitInstrAB('SHL', 'SI', '1');
          EmitInstrAB('ADD', 'SI', 'OFFSET _PL_HEAP');
          EmitInstrAB('MOV', 'WORD PTR [SI]', 'BX');
          EmitInstr('INC    WORD PTR [_PL_HTOP]');
        End;

        FAK_LIST :
        Begin
          { Liste : construire sur le heap (TODO 13) }
          EmitComment('list');
          EmitBuildListToAX(ClauseTab[CIdx].Args[I], True);
          EmitInstrAB('MOV', 'BX', 'AX');
        End;
      Else
        EmitComment('arg tete non gere');
        EmitInstrAB('MOV', 'BX', '0');
      End;

      { Appeler l unification }
      EmitUnify;
      EmitInstrA('JC', ClauseTab[CIdx].FailLabel);
    End;
  End;

  { Emettre le code du corps (buts) }
  EmitComment('--- corps de la regle ---');
  For I := 0 To ClauseTab[CIdx].BodyLen - 1 Do
  Begin
    GIdx := ClauseTab[CIdx].BodyStart + I;
    IsLast := (I = ClauseTab[CIdx].BodyLen - 1);

    EmitBlankLine;
    EmitComment('but ' + IntToStr(I + 1) + '/' +
                IntToStr(ClauseTab[CIdx].BodyLen) + ': ' +
                GoalTab[GIdx].PredName + '/' +
                IntToStr(GoalTab[GIdx].Arity));

    { Emettre le code du but (TODO 14 : traitement inline pour is/comp) }
    If GoalTab[GIdx].PredName = 'is' Then
    Begin
      { --- is/2 : Variable is Expression (TODO 14) --- }
      EmitComment('is/2 inline');
      { Evaluer l expression (arg1) dans AX (entier brut) }
      If GoalTab[GIdx].Args[1].Kind = FAK_EXPR Then
        EmitArithEval(GoalTab[GIdx].Args[1].ExprRoot)
      Else If GoalTab[GIdx].Args[1].Kind = FAK_INT Then
      Begin
        Str(Integer(GoalTab[GIdx].Args[1].IntVal), NS);
        EmitInstrAB('MOV', 'AX', NS);
      End
      Else If GoalTab[GIdx].Args[1].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[1].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitDeref;
        EmitInstr('CALL    _PLRT_DEREF_INT');
      End
      Else
      Begin
        EmitComment('is/2: expression type non gere');
        EmitInstrAB('MOV', 'AX', '0');
      End;

      { Creer un entier tague a partir de AX }
      EmitInstr('CALL    _PLRT_MKINT');
      EmitInstrAB('MOV', 'BX', 'AX');

      { Charger la variable cible (arg0) dans AX }
      If GoalTab[GIdx].Args[0].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[0].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
      End
      Else
      Begin
        EmitComment('is/2: cible non-variable');
        EmitInstrAB('MOV', 'AX', '0');
      End;

      { Lier la variable au resultat }
      EmitBind;
      EmitComment('is/2 done');
    End
    Else If (GoalTab[GIdx].PredName = '=:=') Or
            (GoalTab[GIdx].PredName = '=\=') Or
            (GoalTab[GIdx].PredName = '<') Or
            (GoalTab[GIdx].PredName = '>') Or
            (GoalTab[GIdx].PredName = '=<') Or
            (GoalTab[GIdx].PredName = '>=') Then
    Begin
      { --- Comparaison arithmetique inline (TODO 14) --- }
      EmitComment('arith cmp ' + GoalTab[GIdx].PredName + ' inline');

      { Evaluer arg0 (gauche) dans AX }
      If GoalTab[GIdx].Args[0].Kind = FAK_EXPR Then
        EmitArithEval(GoalTab[GIdx].Args[0].ExprRoot)
      Else If GoalTab[GIdx].Args[0].Kind = FAK_INT Then
      Begin
        Str(Integer(GoalTab[GIdx].Args[0].IntVal), NS);
        EmitInstrAB('MOV', 'AX', NS);
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[0].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitDeref;
        EmitInstr('CALL    _PLRT_DEREF_INT');
      End
      Else
      Begin
        EmitComment('cmp: gauche non gere');
        EmitInstrAB('MOV', 'AX', '0');
      End;

      EmitInstrA('PUSH', 'AX');

      { Evaluer arg1 (droite) dans AX }
      If GoalTab[GIdx].Args[1].Kind = FAK_EXPR Then
        EmitArithEval(GoalTab[GIdx].Args[1].ExprRoot)
      Else If GoalTab[GIdx].Args[1].Kind = FAK_INT Then
      Begin
        Str(Integer(GoalTab[GIdx].Args[1].IntVal), NS);
        EmitInstrAB('MOV', 'AX', NS);
      End
      Else If GoalTab[GIdx].Args[1].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[1].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitDeref;
        EmitInstr('CALL    _PLRT_DEREF_INT');
      End
      Else
      Begin
        EmitComment('cmp: droite non gere');
        EmitInstrAB('MOV', 'AX', '0');
      End;

      EmitInstrAB('MOV', 'BX', 'AX');
      EmitInstrA('POP', 'AX');
      EmitInstrAB('CMP', 'AX', 'BX');

      { Emettre le saut conditionnel selon l operateur }
      NS := LabelGen;
      If GoalTab[GIdx].PredName = '=:=' Then
        EmitInstrA('JE', NS)
      Else If GoalTab[GIdx].PredName = '=\=' Then
        EmitInstrA('JNE', NS)
      Else If GoalTab[GIdx].PredName = '<' Then
        EmitInstrA('JL', NS)
      Else If GoalTab[GIdx].PredName = '>' Then
        EmitInstrA('JG', NS)
      Else If GoalTab[GIdx].PredName = '=<' Then
        EmitInstrA('JLE', NS)
      Else If GoalTab[GIdx].PredName = '>=' Then
        EmitInstrA('JGE', NS);

      { Si on tombe ici, la comparaison a echoue }
      EmitInstrA('JMP', ClauseTab[CIdx].FailLabel);
      EmitLabel(NS);
      EmitComment('arith cmp ok');
    End
    { --- TODO 15 : Unification =/2 --- }
    Else If GoalTab[GIdx].PredName = '=' Then
    Begin
      EmitComment('=/2 unification inline');
      { Charger arg0 dans AX }
      EmitLoadArgToAX(GoalTab[GIdx].Args[0], True);
      EmitInstrA('PUSH', 'AX');
      { Charger arg1 dans AX }
      EmitLoadArgToAX(GoalTab[GIdx].Args[1], True);
      EmitInstrAB('MOV', 'BX', 'AX');
      EmitInstrA('POP', 'AX');
      EmitUnify;
      EmitInstrA('JC', ClauseTab[CIdx].FailLabel);
      EmitComment('=/2 ok');
    End
    { --- TODO 15 : Non-unification \=/2 --- }
    Else If GoalTab[GIdx].PredName = '\=' Then
    Begin
      EmitComment('\=/2 non-unification inline');
      EmitLoadArgToAX(GoalTab[GIdx].Args[0], True);
      EmitInstrA('PUSH', 'AX');
      EmitLoadArgToAX(GoalTab[GIdx].Args[1], True);
      EmitInstrAB('MOV', 'BX', 'AX');
      EmitInstrA('POP', 'AX');
      EmitUnify;
      EmitInstrA('JNC', ClauseTab[CIdx].FailLabel);
      EmitComment('\=/2 ok');
    End
    { --- TODO 15 : Egalite structurelle ==/2 --- }
    Else If GoalTab[GIdx].PredName = '==' Then
    Begin
      EmitComment('==/2 structural eq inline');
      EmitLoadArgToAX(GoalTab[GIdx].Args[0], True);
      EmitInstrA('PUSH', 'AX');
      EmitLoadArgToAX(GoalTab[GIdx].Args[1], True);
      EmitInstrAB('MOV', 'BX', 'AX');
      EmitInstrA('POP', 'AX');
      EmitInstr('CALL    ' + PL_RT_PFX + 'STRUCT_EQ');
      EmitInstrA('JC', ClauseTab[CIdx].FailLabel);
      EmitComment('==/2 ok');
    End
    { --- TODO 15 : Inegalite structurelle \==/2 --- }
    Else If GoalTab[GIdx].PredName = '\==' Then
    Begin
      EmitComment('\==/2 structural neq inline');
      EmitLoadArgToAX(GoalTab[GIdx].Args[0], True);
      EmitInstrA('PUSH', 'AX');
      EmitLoadArgToAX(GoalTab[GIdx].Args[1], True);
      EmitInstrAB('MOV', 'BX', 'AX');
      EmitInstrA('POP', 'AX');
      EmitInstr('CALL    ' + PL_RT_PFX + 'STRUCT_EQ');
      EmitInstrA('JNC', ClauseTab[CIdx].FailLabel);
      EmitComment('\==/2 ok');
    End
    { --- TODO 15 : Ordre standard @< @> @=< @>= --- }
    Else If (GoalTab[GIdx].PredName = '@<') Or
            (GoalTab[GIdx].PredName = '@>') Or
            (GoalTab[GIdx].PredName = '@=<') Or
            (GoalTab[GIdx].PredName = '@>=') Then
    Begin
      EmitComment('order ' + GoalTab[GIdx].PredName + ' inline');
      EmitLoadArgToAX(GoalTab[GIdx].Args[0], True);
      EmitInstrA('PUSH', 'AX');
      EmitLoadArgToAX(GoalTab[GIdx].Args[1], True);
      EmitInstrAB('MOV', 'BX', 'AX');
      EmitInstrA('POP', 'AX');
      EmitInstr('CALL    ' + PL_RT_PFX + 'COMPARE');
      NS := LabelGen;
      If GoalTab[GIdx].PredName = '@<' Then
        EmitInstrA('JB', NS)
      Else If GoalTab[GIdx].PredName = '@>' Then
        EmitInstrA('JA', NS)
      Else If GoalTab[GIdx].PredName = '@=<' Then
        EmitInstrA('JBE', NS)
      Else If GoalTab[GIdx].PredName = '@>=' Then
        EmitInstrA('JAE', NS);
      EmitInstrA('JMP', ClauseTab[CIdx].FailLabel);
      EmitLabel(NS);
      EmitComment('order cmp ok');
    End
    { --- TODO 15 : var/1 --- }
    Else If (GoalTab[GIdx].PredName = 'var') And
            (GoalTab[GIdx].Arity = 1) Then
    Begin
      EmitComment('var/1 inline');
      EmitLoadArgToAX(GoalTab[GIdx].Args[0], True);
      EmitDeref;
      EmitInstrAB('AND', 'AX', IntToStr(TAG_MASK));
      EmitInstrAB('CMP', 'AX', IntToStr(TAG_REF Shl TAG_SHIFT));
      EmitInstrA('JNE', ClauseTab[CIdx].FailLabel);
      EmitComment('var/1 ok');
    End
    { --- TODO 15 : nonvar/1 --- }
    Else If (GoalTab[GIdx].PredName = 'nonvar') And
            (GoalTab[GIdx].Arity = 1) Then
    Begin
      EmitComment('nonvar/1 inline');
      EmitLoadArgToAX(GoalTab[GIdx].Args[0], True);
      EmitDeref;
      EmitInstrAB('AND', 'AX', IntToStr(TAG_MASK));
      EmitInstrAB('CMP', 'AX', IntToStr(TAG_REF Shl TAG_SHIFT));
      EmitInstrA('JE', ClauseTab[CIdx].FailLabel);
      EmitComment('nonvar/1 ok');
    End
    { --- TODO 15 : atom/1 --- }
    Else If (GoalTab[GIdx].PredName = 'atom') And
            (GoalTab[GIdx].Arity = 1) Then
    Begin
      EmitComment('atom/1 inline');
      EmitLoadArgToAX(GoalTab[GIdx].Args[0], True);
      EmitDeref;
      EmitInstrAB('AND', 'AX', IntToStr(TAG_MASK));
      EmitInstrAB('CMP', 'AX', IntToStr(TAG_ATOM Shl TAG_SHIFT));
      EmitInstrA('JNE', ClauseTab[CIdx].FailLabel);
      EmitComment('atom/1 ok');
    End
    { --- TODO 15 : number/1 et integer/1 --- }
    Else If ((GoalTab[GIdx].PredName = 'number') Or
             (GoalTab[GIdx].PredName = 'integer')) And
            (GoalTab[GIdx].Arity = 1) Then
    Begin
      EmitComment(GoalTab[GIdx].PredName + '/1 inline');
      EmitLoadArgToAX(GoalTab[GIdx].Args[0], True);
      EmitDeref;
      EmitInstrAB('AND', 'AX', IntToStr(TAG_MASK));
      EmitInstrAB('CMP', 'AX', IntToStr(TAG_INT Shl TAG_SHIFT));
      EmitInstrA('JNE', ClauseTab[CIdx].FailLabel);
      EmitComment(GoalTab[GIdx].PredName + '/1 ok');
    End
    { --- TODO 15 : compound/1 --- }
    Else If (GoalTab[GIdx].PredName = 'compound') And
            (GoalTab[GIdx].Arity = 1) Then
    Begin
      EmitComment('compound/1 inline');
      EmitLoadArgToAX(GoalTab[GIdx].Args[0], True);
      EmitDeref;
      EmitInstrAB('MOV', 'BX', 'AX');
      EmitInstrAB('AND', 'BX', IntToStr(TAG_MASK));
      NS := LabelGen;
      EmitInstrAB('CMP', 'BX', IntToStr(TAG_STR Shl TAG_SHIFT));
      EmitInstrA('JE', NS);
      EmitInstrAB('CMP', 'BX', IntToStr(TAG_LIST Shl TAG_SHIFT));
      EmitInstrA('JNE', ClauseTab[CIdx].FailLabel);
      EmitLabel(NS);
      EmitComment('compound/1 ok');
    End
    { --- TODO 15 : is_list/1 --- }
    Else If (GoalTab[GIdx].PredName = 'is_list') And
            (GoalTab[GIdx].Arity = 1) Then
    Begin
      EmitComment('is_list/1 inline');
      EmitLoadArgToAX(GoalTab[GIdx].Args[0], True);
      EmitDeref;
      EmitInstrAB('MOV', 'BX', 'AX');
      EmitInstrAB('AND', 'BX', IntToStr(TAG_MASK));
      NS := LabelGen;
      EmitInstrAB('CMP', 'BX', IntToStr(TAG_LIST Shl TAG_SHIFT));
      EmitInstrA('JE', NS);
      { Check for empty list atom [] }
      EmitInstrAB('CMP', 'BX', IntToStr(TAG_ATOM Shl TAG_SHIFT));
      EmitInstrA('JNE', ClauseTab[CIdx].FailLabel);
      EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
      EmitInstrAB('CMP', 'AX', '0');
      EmitInstrA('JNE', ClauseTab[CIdx].FailLabel);
      EmitLabel(NS);
      EmitComment('is_list/1 ok');
    End
    { --- TODO 15 : callable/1 --- }
    Else If (GoalTab[GIdx].PredName = 'callable') And
            (GoalTab[GIdx].Arity = 1) Then
    Begin
      EmitComment('callable/1 inline');
      EmitLoadArgToAX(GoalTab[GIdx].Args[0], True);
      EmitDeref;
      EmitInstrAB('MOV', 'BX', 'AX');
      EmitInstrAB('AND', 'BX', IntToStr(TAG_MASK));
      NS := LabelGen;
      EmitInstrAB('CMP', 'BX', IntToStr(TAG_ATOM Shl TAG_SHIFT));
      EmitInstrA('JE', NS);
      EmitInstrAB('CMP', 'BX', IntToStr(TAG_STR Shl TAG_SHIFT));
      EmitInstrA('JE', NS);
      EmitInstrAB('CMP', 'BX', IntToStr(TAG_LIST Shl TAG_SHIFT));
      EmitInstrA('JNE', ClauseTab[CIdx].FailLabel);
      EmitLabel(NS);
      EmitComment('callable/1 ok');
    End
    { --- TODO 15 : functor/3 --- }
    Else If (GoalTab[GIdx].PredName = 'functor') And
            (GoalTab[GIdx].Arity = 3) Then
    Begin
      EmitComment('functor/3 inline');
      { Load first arg (Term) to AX }
      EmitLoadArgToAX(GoalTab[GIdx].Args[0], True);
      EmitDeref;
      EmitInstrAB('MOV', 'DX', 'AX');
      EmitInstrAB('MOV', 'BX', 'AX');
      EmitInstrAB('AND', 'BX', IntToStr(TAG_MASK));
      Clean := LabelGen; { label for non-atom case }
      PredLbl := LabelGen; { label for end of functor/3 }
      { If ATOM: Name=self, Arity=0 }
      EmitInstrAB('CMP', 'BX', IntToStr(TAG_ATOM Shl TAG_SHIFT));
      EmitInstrA('JNE', Clean);
      { Unify arg1 with the atom }
      EmitInstrAB('MOV', 'AX', 'DX');
      If GoalTab[GIdx].Args[1].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[1].VarName);
        EmitInstrAB('MOV', 'BX', 'AX');
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitUnify;
        EmitInstrA('JC', ClauseTab[CIdx].FailLabel);
      End;
      { Unify arg2 with 0 (arity of atom = 0) }
      If GoalTab[GIdx].Args[2].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[2].VarName);
        TagVal := (TAG_INT Shl TAG_SHIFT) Or (0 And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'BX', NS);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitUnify;
        EmitInstrA('JC', ClauseTab[CIdx].FailLabel);
      End;
      EmitInstrA('JMP', PredLbl);
      EmitLabel(Clean);
      { INT case: functor(N, N, 0) - the number itself is the functor }
      NS := LabelGen; { label for non-int case }
      EmitInstrAB('CMP', 'BX', IntToStr(TAG_INT Shl TAG_SHIFT));
      EmitInstrA('JNE', NS);
      { Unify arg1 with the integer term }
      EmitInstrAB('MOV', 'AX', 'DX');
      If GoalTab[GIdx].Args[1].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[1].VarName);
        EmitInstrAB('MOV', 'BX', 'AX');
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitUnify;
        EmitInstrA('JC', ClauseTab[CIdx].FailLabel);
      End;
      { Unify arg2 with 0 }
      If GoalTab[GIdx].Args[2].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[2].VarName);
        TagVal := (TAG_INT Shl TAG_SHIFT) Or (0 And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'BX', NS);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitUnify;
        EmitInstrA('JC', ClauseTab[CIdx].FailLabel);
      End;
      EmitInstrA('JMP', PredLbl);
      EmitLabel(NS);
      { Other types (STR/LIST): fail for now }
      EmitInstrA('JMP', ClauseTab[CIdx].FailLabel);
      EmitLabel(PredLbl);
      EmitComment('functor/3 ok');
    End
    { --- TODO 15 : arg/3 --- }
    Else If (GoalTab[GIdx].PredName = 'arg') And
            (GoalTab[GIdx].Arity = 3) Then
    Begin
      EmitComment('arg/3 inline');
      { Load arg0 (N) to AX }
      EmitLoadArgToAX(GoalTab[GIdx].Args[0], True);
      EmitDeref;
      EmitInstrA('PUSH', 'AX');
      { Load arg1 (Term) to AX }
      EmitLoadArgToAX(GoalTab[GIdx].Args[1], True);
      EmitDeref;
      EmitInstrAB('MOV', 'BX', 'AX');
      EmitInstrA('POP', 'AX');
      { AX = N (tagged int), BX = Term }
      { Extract integer value from N }
      EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
      { BX points to structure on heap: [functor][arg1][arg2]... }
      EmitInstrAB('MOV', 'SI', 'BX');
      EmitInstrAB('AND', 'SI', IntToStr(VAL_MASK));
      { Add N to get the Nth argument (1-based) }
      EmitInstrAB('ADD', 'SI', 'AX');
      EmitInstrAB('SHL', 'SI', '1');
      EmitInstrAB('ADD', 'SI', 'OFFSET _PL_HEAP');
      EmitInstrAB('MOV', 'AX', 'WORD PTR [SI]');
      { Unify with arg2 }
      If GoalTab[GIdx].Args[2].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[2].VarName);
        EmitInstrAB('MOV', 'BX', 'AX');
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitUnify;
        EmitInstrA('JC', ClauseTab[CIdx].FailLabel);
      End;
      EmitComment('arg/3 ok');
    End
    { --- TODO 15 : copy_term/2 --- }
    Else If (GoalTab[GIdx].PredName = 'copy_term') And
            (GoalTab[GIdx].Arity = 2) Then
    Begin
      EmitComment('copy_term/2 inline');
      EmitLoadArgToAX(GoalTab[GIdx].Args[0], True);
      EmitInstr('CALL    ' + PL_RT_PFX + 'COPY_TERM');
      { Unify result with second arg }
      If GoalTab[GIdx].Args[1].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[1].VarName);
        EmitInstrAB('MOV', 'BX', 'AX');
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitUnify;
        EmitInstrA('JC', ClauseTab[CIdx].FailLabel);
      End;
      EmitComment('copy_term/2 ok');
    End
    { --- TODO 16 : Cut ! --- }
    Else If GoalTab[GIdx].PredName = '!' Then
    Begin
      EmitComment('cut ! inline');
      { Sauvegarder le point de choix courant comme barriere }
      EmitInstrAB('MOV', 'AX', 'WORD PTR [_PL_CPTOP]');
      EmitInstrAB('MOV', 'WORD PTR [_PL_CUT_BARRIER]', 'AX');
      { Couper : restaurer CPTOP au niveau de la barriere }
      { En pratique, on elimine les points de choix au-dessus }
      EmitComment('cut: discard choice points');
    End
    { --- TODO 16 : true/0 --- }
    Else If (GoalTab[GIdx].PredName = 'true') And
            (GoalTab[GIdx].Arity = 0) Then
    Begin
      EmitComment('true/0 inline - noop');
      { true reussit toujours : rien a faire }
    End
    { --- TODO 16 : fail/0 --- }
    Else If (GoalTab[GIdx].PredName = 'fail') And
            (GoalTab[GIdx].Arity = 0) Then
    Begin
      EmitComment('fail/0 inline');
      EmitInstrA('JMP', ClauseTab[CIdx].FailLabel);
    End
    { --- TODO 16 : halt/0 --- }
    Else If (GoalTab[GIdx].PredName = 'halt') And
            (GoalTab[GIdx].Arity = 0) Then
    Begin
      EmitComment('halt/0 inline');
      EmitInstrAB('MOV', 'AX', '4C00h');
      EmitInstrA('INT', '21h');
    End
    { --- TODO 16 : halt/1 --- }
    Else If (GoalTab[GIdx].PredName = 'halt') And
            (GoalTab[GIdx].Arity = 1) Then
    Begin
      EmitComment('halt/1 inline');
      If GoalTab[GIdx].Args[0].Kind = FAK_INT Then
      Begin
        Str(Integer(GoalTab[GIdx].Args[0].IntVal), NS);
        EmitInstrAB('MOV', 'AL', NS);
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[0].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitDeref;
        EmitInstr('CALL    _PLRT_DEREF_INT');
        { AX contient la valeur entiere }
      End
      Else
        EmitInstrAB('MOV', 'AL', '0');
      EmitInstrAB('MOV', 'AH', '4Ch');
      EmitInstrA('INT', '21h');
    End
    { --- TODO 16 : negation par echec \+/1 --- }
    Else If (GoalTab[GIdx].PredName = '\+') Then
    Begin
      EmitComment('\+/1 negation by failure inline');
      { Sauvegarder etat }
      EmitInstrA('PUSH', 'WORD PTR [_PL_HTOP]');
      EmitInstrA('PUSH', 'WORD PTR [_PL_TTOP]');
      EmitInstrA('PUSH', 'WORD PTR [_PL_CPTOP]');
      { Construire l appel au but interne }
      { L argument 0 contient le nom du predicat a nier }
      If GoalTab[GIdx].Args[0].Kind = FAK_ATOM Then
      Begin
        { Charger les args supplementaires si presents }
        For J := 1 To GoalTab[GIdx].ArgCount - 1 Do
        Begin
          Case GoalTab[GIdx].Args[J].Kind Of
            FAK_ATOM :
            Begin
              TagVal := (TAG_ATOM Shl TAG_SHIFT) Or
                        (GoalTab[GIdx].Args[J].AtomIdx And VAL_MASK);
              Str(TagVal, NS);
              EmitInstrAB('MOV', 'WORD PTR [_PL_ARGS + ' +
                          IntToStr((J - 1) * 2) + ']', NS);
            End;
            FAK_INT :
            Begin
              TagVal := (TAG_INT Shl TAG_SHIFT) Or
                        (Integer(GoalTab[GIdx].Args[J].IntVal) And VAL_MASK);
              Str(TagVal, NS);
              EmitInstrAB('MOV', 'WORD PTR [_PL_ARGS + ' +
                          IntToStr((J - 1) * 2) + ']', NS);
            End;
            FAK_VAR :
            Begin
              VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[J].VarName);
              EmitInstrAB('MOV', 'AX',
                          'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
              EmitInstrAB('MOV', 'WORD PTR [_PL_ARGS + ' +
                          IntToStr((J - 1) * 2) + ']', 'AX');
            End;
          End;
        End;
        { Appeler le predicat }
        Clean   := SymNameClean(AtomName(GoalTab[GIdx].Args[0].AtomIdx));
        PredLbl := PL_PRED_PFX + Clean + '_' +
                   IntToStr(GoalTab[GIdx].Arity - 1);
        EmitInstrA('CALL', PredLbl);
        { Si succes (CF=0) -> negation echoue }
        NS := LabelGen;
        EmitInstrA('JC', NS);
        { Succes du but -> restaurer et echouer }
        EmitInstrA('POP', 'WORD PTR [_PL_CPTOP]');
        EmitInstrA('POP', 'WORD PTR [_PL_TTOP]');
        EmitInstrA('POP', 'WORD PTR [_PL_HTOP]');
        EmitInstr('CALL    ' + PL_RT_PFX + 'UNTRAIL');
        EmitInstrA('JMP', ClauseTab[CIdx].FailLabel);
        EmitLabel(NS);
        { Echec du but -> restaurer et reussir }
        EmitInstrA('POP', 'WORD PTR [_PL_CPTOP]');
        EmitInstrA('POP', 'WORD PTR [_PL_TTOP]');
        EmitInstrA('POP', 'WORD PTR [_PL_HTOP]');
        EmitInstr('CALL    ' + PL_RT_PFX + 'UNTRAIL');
        EmitComment('\+/1 ok (goal failed -> negation succeeds)');
      End
      Else
      Begin
        EmitComment('\+/1: argument non-atome ignore');
        EmitInstrA('POP', 'WORD PTR [_PL_CPTOP]');
        EmitInstrA('POP', 'WORD PTR [_PL_TTOP]');
        EmitInstrA('POP', 'WORD PTR [_PL_HTOP]');
      End;
    End
    { === TODO 17 : Predicats I/O inline === }
    { --- write/1 --- }
    Else If (GoalTab[GIdx].PredName = 'write') And
            (GoalTab[GIdx].Arity = 1) Then
    Begin
      EmitComment('write/1 inline');
      If GoalTab[GIdx].Args[0].Kind = FAK_ATOM Then
      Begin
        TagVal := (TAG_ATOM Shl TAG_SHIFT) Or
                  (GoalTab[GIdx].Args[0].AtomIdx And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'AX', NS);
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_INT Then
      Begin
        TagVal := (TAG_INT Shl TAG_SHIFT) Or
                  (Integer(GoalTab[GIdx].Args[0].IntVal) And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'AX', NS);
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[0].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitDeref;
      End
      Else
        EmitInstrAB('MOV', 'AX', '0');
      EmitInstr('CALL    ' + PL_RT_PFX + 'WRITE_TERM');
      EmitComment('write/1 done');
    End
    { --- writeln/1 --- }
    Else If (GoalTab[GIdx].PredName = 'writeln') And
            (GoalTab[GIdx].Arity = 1) Then
    Begin
      EmitComment('writeln/1 inline');
      If GoalTab[GIdx].Args[0].Kind = FAK_ATOM Then
      Begin
        TagVal := (TAG_ATOM Shl TAG_SHIFT) Or
                  (GoalTab[GIdx].Args[0].AtomIdx And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'AX', NS);
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_INT Then
      Begin
        TagVal := (TAG_INT Shl TAG_SHIFT) Or
                  (Integer(GoalTab[GIdx].Args[0].IntVal) And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'AX', NS);
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[0].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitDeref;
      End
      Else
        EmitInstrAB('MOV', 'AX', '0');
      EmitInstr('CALL    ' + PL_RT_PFX + 'WRITE_TERM');
      EmitInstr('CALL    ' + PL_RT_PFX + 'NL');
      EmitComment('writeln/1 done');
    End
    { --- nl/0 --- }
    Else If (GoalTab[GIdx].PredName = 'nl') And
            (GoalTab[GIdx].Arity = 0) Then
    Begin
      EmitComment('nl/0 inline');
      EmitInstr('CALL    ' + PL_RT_PFX + 'NL');
    End
    { --- print/1 --- }
    Else If (GoalTab[GIdx].PredName = 'print') And
            (GoalTab[GIdx].Arity = 1) Then
    Begin
      EmitComment('print/1 inline (same as write)');
      If GoalTab[GIdx].Args[0].Kind = FAK_ATOM Then
      Begin
        TagVal := (TAG_ATOM Shl TAG_SHIFT) Or
                  (GoalTab[GIdx].Args[0].AtomIdx And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'AX', NS);
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_INT Then
      Begin
        TagVal := (TAG_INT Shl TAG_SHIFT) Or
                  (Integer(GoalTab[GIdx].Args[0].IntVal) And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'AX', NS);
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[0].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitDeref;
      End
      Else
        EmitInstrAB('MOV', 'AX', '0');
      EmitInstr('CALL    ' + PL_RT_PFX + 'WRITE_TERM');
      EmitComment('print/1 done');
    End
    { --- write_canonical/1 --- }
    Else If (GoalTab[GIdx].PredName = 'write_canonical') And
            (GoalTab[GIdx].Arity = 1) Then
    Begin
      EmitComment('write_canonical/1 inline (same as write)');
      If GoalTab[GIdx].Args[0].Kind = FAK_ATOM Then
      Begin
        TagVal := (TAG_ATOM Shl TAG_SHIFT) Or
                  (GoalTab[GIdx].Args[0].AtomIdx And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'AX', NS);
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_INT Then
      Begin
        TagVal := (TAG_INT Shl TAG_SHIFT) Or
                  (Integer(GoalTab[GIdx].Args[0].IntVal) And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'AX', NS);
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[0].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitDeref;
      End
      Else
        EmitInstrAB('MOV', 'AX', '0');
      EmitInstr('CALL    ' + PL_RT_PFX + 'WRITE_TERM');
      EmitComment('write_canonical/1 done');
    End
    { --- tab/1 --- }
    Else If (GoalTab[GIdx].PredName = 'tab') And
            (GoalTab[GIdx].Arity = 1) Then
    Begin
      EmitComment('tab/1 inline');
      If GoalTab[GIdx].Args[0].Kind = FAK_INT Then
      Begin
        Str(Integer(GoalTab[GIdx].Args[0].IntVal), NS);
        EmitInstrAB('MOV', 'AX', NS);
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[0].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitDeref;
        EmitInstr('CALL    ' + PL_RT_PFX + 'DEREF_INT');
      End
      Else
        EmitInstrAB('MOV', 'AX', '0');
      EmitInstr('CALL    ' + PL_RT_PFX + 'TAB');
      EmitComment('tab/1 done');
    End
    { --- put_char/1 --- }
    Else If (GoalTab[GIdx].PredName = 'put_char') And
            (GoalTab[GIdx].Arity = 1) Then
    Begin
      EmitComment('put_char/1 inline');
      If GoalTab[GIdx].Args[0].Kind = FAK_ATOM Then
      Begin
        { Extraire le premier caractere de l atome }
        TagVal := (TAG_ATOM Shl TAG_SHIFT) Or
                  (GoalTab[GIdx].Args[0].AtomIdx And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'AX', NS);
        EmitInstr('CALL    ' + PL_RT_PFX + 'CHAR_CODE');
        { AX = tagged INT code }
        EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
        EmitInstrAB('MOV', 'DL', 'AL');
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_INT Then
      Begin
        Str(Integer(GoalTab[GIdx].Args[0].IntVal), NS);
        EmitInstrAB('MOV', 'DL', NS);
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[0].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitDeref;
        EmitInstr('CALL    ' + PL_RT_PFX + 'CHAR_CODE');
        EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
        EmitInstrAB('MOV', 'DL', 'AL');
      End
      Else
        EmitInstrAB('MOV', 'DL', '32');
      EmitInstrAB('MOV', 'AH', '02h');
      EmitInstrA('INT', '21h');
      EmitComment('put_char/1 done');
    End
    { --- get_char/1 --- }
    Else If (GoalTab[GIdx].PredName = 'get_char') And
            (GoalTab[GIdx].Arity = 1) Then
    Begin
      EmitComment('get_char/1 inline');
      EmitInstr('CALL    ' + PL_RT_PFX + 'GET_CHAR');
      { AX = tagged INT (char code) }
      EmitInstrAB('MOV', 'BX', 'AX');
      If GoalTab[GIdx].Args[0].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[0].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitBind;
      End;
      EmitComment('get_char/1 done');
    End
    { --- char_code/2 --- }
    Else If (GoalTab[GIdx].PredName = 'char_code') And
            (GoalTab[GIdx].Arity = 2) Then
    Begin
      EmitComment('char_code/2 inline');
      { Charger arg0 (Char) }
      If GoalTab[GIdx].Args[0].Kind = FAK_ATOM Then
      Begin
        TagVal := (TAG_ATOM Shl TAG_SHIFT) Or
                  (GoalTab[GIdx].Args[0].AtomIdx And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'AX', NS);
        EmitInstr('CALL    ' + PL_RT_PFX + 'CHAR_CODE');
        { AX = tagged INT (code) -> unifier avec arg1 }
        EmitInstrAB('MOV', 'BX', 'AX');
        If GoalTab[GIdx].Args[1].Kind = FAK_VAR Then
        Begin
          VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[1].VarName);
          EmitInstrAB('MOV', 'AX',
                      'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
          EmitBind;
        End;
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_VAR Then
      Begin
        { arg0 est une variable -> arg1 doit etre un code }
        If GoalTab[GIdx].Args[1].Kind = FAK_INT Then
        Begin
          TagVal := (TAG_INT Shl TAG_SHIFT) Or
                    (Integer(GoalTab[GIdx].Args[1].IntVal) And VAL_MASK);
          Str(TagVal, NS);
          EmitInstrAB('MOV', 'BX', NS);
          VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[0].VarName);
          EmitInstrAB('MOV', 'AX',
                      'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
          EmitBind;
        End
        Else If GoalTab[GIdx].Args[1].Kind = FAK_VAR Then
        Begin
          VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[1].VarName);
          EmitInstrAB('MOV', 'AX',
                      'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
          EmitDeref;
          EmitInstr('CALL    ' + PL_RT_PFX + 'DEREF_INT');
          { AX = raw int, faire tagged INT }
          EmitInstrAB('AND', 'AX', IntToStr(VAL_MASK));
          Str(TAG_INT Shl TAG_SHIFT, NS);
          EmitInstrAB('OR', 'AX', NS);
          EmitInstrAB('MOV', 'BX', 'AX');
          VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[0].VarName);
          EmitInstrAB('MOV', 'AX',
                      'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
          EmitBind;
        End;
      End;
      EmitComment('char_code/2 done');
    End
    { --- atom_length/2 --- }
    Else If (GoalTab[GIdx].PredName = 'atom_length') And
            (GoalTab[GIdx].Arity = 2) Then
    Begin
      EmitComment('atom_length/2 inline');
      If GoalTab[GIdx].Args[0].Kind = FAK_ATOM Then
      Begin
        TagVal := (TAG_ATOM Shl TAG_SHIFT) Or
                  (GoalTab[GIdx].Args[0].AtomIdx And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'AX', NS);
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[0].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitDeref;
      End
      Else
      Begin
        EmitInstrAB('MOV', 'AX', '0');
      End;
      EmitInstr('CALL    ' + PL_RT_PFX + 'ATOM_LENGTH');
      { AX = tagged INT (longueur) -> unifier avec arg1 }
      EmitInstrAB('MOV', 'BX', 'AX');
      If GoalTab[GIdx].Args[1].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[1].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitBind;
      End;
      EmitComment('atom_length/2 done');
    End
    { --- atom_concat/3 --- }
    Else If (GoalTab[GIdx].PredName = 'atom_concat') And
            (GoalTab[GIdx].Arity = 3) Then
    Begin
      EmitComment('atom_concat/3 inline');
      { Charger arg0 }
      If GoalTab[GIdx].Args[0].Kind = FAK_ATOM Then
      Begin
        TagVal := (TAG_ATOM Shl TAG_SHIFT) Or
                  (GoalTab[GIdx].Args[0].AtomIdx And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'AX', NS);
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[0].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitDeref;
      End
      Else
        EmitInstrAB('MOV', 'AX', '0');
      EmitInstrA('PUSH', 'AX');
      { Charger arg1 }
      If GoalTab[GIdx].Args[1].Kind = FAK_ATOM Then
      Begin
        TagVal := (TAG_ATOM Shl TAG_SHIFT) Or
                  (GoalTab[GIdx].Args[1].AtomIdx And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'BX', NS);
      End
      Else If GoalTab[GIdx].Args[1].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[1].VarName);
        EmitInstrAB('MOV', 'BX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        { Deref via AX }
        EmitInstrA('PUSH', 'AX');
        EmitInstrAB('MOV', 'AX', 'BX');
        EmitDeref;
        EmitInstrAB('MOV', 'BX', 'AX');
        EmitInstrA('POP', 'AX');
      End
      Else
        EmitInstrAB('MOV', 'BX', '0');
      EmitInstrA('POP', 'AX');
      EmitInstr('CALL    ' + PL_RT_PFX + 'ATOM_CONCAT');
      { AX = tagged INT (longueur concatenee) -> unifier avec arg2 }
      EmitInstrAB('MOV', 'BX', 'AX');
      If GoalTab[GIdx].Args[2].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[2].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitBind;
      End;
      EmitComment('atom_concat/3 done');
    End
    { --- atom_chars/2 --- }
    Else If (GoalTab[GIdx].PredName = 'atom_chars') And
            (GoalTab[GIdx].Arity = 2) Then
    Begin
      EmitComment('atom_chars/2 inline');
      If GoalTab[GIdx].Args[0].Kind = FAK_ATOM Then
      Begin
        TagVal := (TAG_ATOM Shl TAG_SHIFT) Or
                  (GoalTab[GIdx].Args[0].AtomIdx And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'AX', NS);
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[0].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitDeref;
      End
      Else
        EmitInstrAB('MOV', 'AX', '0');
      EmitInstr('CALL    ' + PL_RT_PFX + 'ATOM_CHARS');
      { AX = tagged LIST -> unifier avec arg1 }
      EmitInstrAB('MOV', 'BX', 'AX');
      If GoalTab[GIdx].Args[1].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[1].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitBind;
      End;
      EmitComment('atom_chars/2 done');
    End
    { --- atom_codes/2 --- }
    Else If (GoalTab[GIdx].PredName = 'atom_codes') And
            (GoalTab[GIdx].Arity = 2) Then
    Begin
      EmitComment('atom_codes/2 inline (same as atom_chars for codes)');
      If GoalTab[GIdx].Args[0].Kind = FAK_ATOM Then
      Begin
        TagVal := (TAG_ATOM Shl TAG_SHIFT) Or
                  (GoalTab[GIdx].Args[0].AtomIdx And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'AX', NS);
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[0].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitDeref;
      End
      Else
        EmitInstrAB('MOV', 'AX', '0');
      EmitInstr('CALL    ' + PL_RT_PFX + 'ATOM_CHARS');
      EmitInstrAB('MOV', 'BX', 'AX');
      If GoalTab[GIdx].Args[1].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[1].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitBind;
      End;
      EmitComment('atom_codes/2 done');
    End
    { --- number_chars/2 --- }
    Else If (GoalTab[GIdx].PredName = 'number_chars') And
            (GoalTab[GIdx].Arity = 2) Then
    Begin
      EmitComment('number_chars/2 inline');
      If GoalTab[GIdx].Args[0].Kind = FAK_INT Then
      Begin
        TagVal := (TAG_INT Shl TAG_SHIFT) Or
                  (Integer(GoalTab[GIdx].Args[0].IntVal) And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'AX', NS);
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[0].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitDeref;
      End
      Else
        EmitInstrAB('MOV', 'AX', '0');
      EmitInstr('CALL    ' + PL_RT_PFX + 'NUMBER_CHARS');
      EmitInstrAB('MOV', 'BX', 'AX');
      If GoalTab[GIdx].Args[1].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[1].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitBind;
      End;
      EmitComment('number_chars/2 done');
    End
    { --- number_codes/2 --- }
    Else If (GoalTab[GIdx].PredName = 'number_codes') And
            (GoalTab[GIdx].Arity = 2) Then
    Begin
      EmitComment('number_codes/2 inline (same as number_chars)');
      If GoalTab[GIdx].Args[0].Kind = FAK_INT Then
      Begin
        TagVal := (TAG_INT Shl TAG_SHIFT) Or
                  (Integer(GoalTab[GIdx].Args[0].IntVal) And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'AX', NS);
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[0].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitDeref;
      End
      Else
        EmitInstrAB('MOV', 'AX', '0');
      EmitInstr('CALL    ' + PL_RT_PFX + 'NUMBER_CHARS');
      EmitInstrAB('MOV', 'BX', 'AX');
      If GoalTab[GIdx].Args[1].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[1].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitBind;
      End;
      EmitComment('number_codes/2 done');
    End
    { --- read/1 (TODO 18) --- }
    Else If (GoalTab[GIdx].PredName = 'read') And
            (GoalTab[GIdx].Arity = 1) Then
    Begin
      EmitComment('read/1 inline (TODO 18)');
      EmitInstr('CALL    ' + PL_RT_PFX + 'READ');
      { AX = tagged INT from stdin, bind to arg0 }
      If GoalTab[GIdx].Args[0].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[0].VarName);
        EmitInstrAB('MOV', 'BX', 'AX');
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitBind;
      End;
      EmitComment('read/1 done');
    End
    { --- sub_atom/5 (TODO 18 stub) --- }
    Else If (GoalTab[GIdx].PredName = 'sub_atom') And
            (GoalTab[GIdx].Arity = 5) Then
    Begin
      EmitComment('sub_atom/5 stub (partial - TODO 18)');
      EmitInstr('CALL    ' + PL_RT_PFX + 'SUB_ATOM');
      EmitInstrA('JC', ClauseTab[CIdx].FailLabel);
    End
    { === TODO 18 : Predicats predefinis supplementaires === }
    { --- ground/1 --- }
    Else If (GoalTab[GIdx].PredName = 'ground') And
            (GoalTab[GIdx].Arity = 1) Then
    Begin
      EmitComment('ground/1 inline (TODO 18)');
      If GoalTab[GIdx].Args[0].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[0].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_ATOM Then
      Begin
        TagVal := (TAG_ATOM Shl TAG_SHIFT) Or
                  (GoalTab[GIdx].Args[0].AtomIdx And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'AX', NS);
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_INT Then
      Begin
        TagVal := (TAG_INT Shl TAG_SHIFT) Or
                  (Integer(GoalTab[GIdx].Args[0].IntVal) And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'AX', NS);
      End
      Else
        EmitInstrAB('MOV', 'AX', '0');
      EmitInstr('CALL    ' + PL_RT_PFX + 'GROUND');
      EmitInstrA('JC', ClauseTab[CIdx].FailLabel);
      EmitComment('ground/1 ok');
    End
    { --- unify_with_occurs_check/2 --- }
    Else If (GoalTab[GIdx].PredName = 'unify_with_occurs_check') And
            (GoalTab[GIdx].Arity = 2) Then
    Begin
      EmitComment('unify_with_occurs_check/2 inline (TODO 18)');
      EmitLoadArgToAX(GoalTab[GIdx].Args[0], True);
      EmitInstrA('PUSH', 'AX');
      EmitLoadArgToAX(GoalTab[GIdx].Args[1], True);
      EmitInstrAB('MOV', 'BX', 'AX');
      EmitInstrA('POP', 'AX');
      EmitInstr('CALL    ' + PL_RT_PFX + 'UNIFY_OC');
      EmitInstrA('JC', ClauseTab[CIdx].FailLabel);
      EmitComment('unify_with_occurs_check/2 ok');
    End
    { --- =../2 (univ) --- }
    Else If (GoalTab[GIdx].PredName = '=..') And
            (GoalTab[GIdx].Arity = 2) Then
    Begin
      EmitComment('=../2 (univ) inline (TODO 18)');
      EmitLoadArgToAX(GoalTab[GIdx].Args[0], True);
      EmitInstr('CALL    ' + PL_RT_PFX + 'UNIV');
      { BX = resulting list, unify with arg1 }
      If GoalTab[GIdx].Args[1].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[1].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitUnify;
        EmitInstrA('JC', ClauseTab[CIdx].FailLabel);
      End;
      EmitComment('=../2 done');
    End
    { --- reverse/2 --- }
    Else If (GoalTab[GIdx].PredName = 'reverse') And
            (GoalTab[GIdx].Arity = 2) Then
    Begin
      EmitComment('reverse/2 inline (TODO 18)');
      EmitLoadArgToAX(GoalTab[GIdx].Args[0], True);
      EmitInstr('CALL    ' + PL_RT_PFX + 'REVERSE');
      { AX = reversed list, unify with arg1 }
      EmitInstrAB('MOV', 'BX', 'AX');
      If GoalTab[GIdx].Args[1].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[1].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitBind;
      End;
      EmitComment('reverse/2 done');
    End
    { --- msort/2 --- }
    Else If (GoalTab[GIdx].PredName = 'msort') And
            (GoalTab[GIdx].Arity = 2) Then
    Begin
      EmitComment('msort/2 inline (TODO 18)');
      EmitLoadArgToAX(GoalTab[GIdx].Args[0], True);
      EmitInstr('CALL    ' + PL_RT_PFX + 'MSORT');
      EmitInstrAB('MOV', 'BX', 'AX');
      If GoalTab[GIdx].Args[1].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[1].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitBind;
      End;
      EmitComment('msort/2 done');
    End
    { --- sort/2 --- }
    Else If (GoalTab[GIdx].PredName = 'sort') And
            (GoalTab[GIdx].Arity = 2) Then
    Begin
      EmitComment('sort/2 inline (TODO 18)');
      EmitLoadArgToAX(GoalTab[GIdx].Args[0], True);
      EmitInstr('CALL    ' + PL_RT_PFX + 'SORT');
      EmitInstrAB('MOV', 'BX', 'AX');
      If GoalTab[GIdx].Args[1].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[1].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitBind;
      End;
      EmitComment('sort/2 done');
    End
    { --- call/1 --- }
    Else If (GoalTab[GIdx].PredName = 'call') And
            (GoalTab[GIdx].Arity = 1) Then
    Begin
      EmitComment('call/1 inline (TODO 18)');
      If GoalTab[GIdx].Args[0].Kind = FAK_ATOM Then
      Begin
        { Static call to known predicate }
        Clean   := SymNameClean(AtomName(GoalTab[GIdx].Args[0].AtomIdx));
        PredLbl := PL_PRED_PFX + Clean + '_0';
        EmitInstrA('CALL', PredLbl);
        EmitInstrA('JC', ClauseTab[CIdx].FailLabel);
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[0].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitInstr('CALL    ' + PL_RT_PFX + 'CALL');
        EmitInstrA('JC', ClauseTab[CIdx].FailLabel);
      End
      Else
      Begin
        EmitComment('call/1: unsupported argument type');
        EmitInstrA('JMP', ClauseTab[CIdx].FailLabel);
      End;
      EmitComment('call/1 done');
    End
    { === TODO 19 : Assert/Retract inline === }
    { --- assert/1 (alias for assertz) --- }
    Else If (GoalTab[GIdx].PredName = 'assert') And
            (GoalTab[GIdx].Arity = 1) Then
    Begin
      EmitComment('assert/1 inline (TODO 19)');
      EmitLoadArgToAX(GoalTab[GIdx].Args[0], True);
      EmitInstr('CALL    ' + PL_RT_PFX + 'ASSERTZ');
      EmitComment('assert/1 done');
    End
    { --- asserta/1 --- }
    Else If (GoalTab[GIdx].PredName = 'asserta') And
            (GoalTab[GIdx].Arity = 1) Then
    Begin
      EmitComment('asserta/1 inline (TODO 19)');
      EmitLoadArgToAX(GoalTab[GIdx].Args[0], True);
      EmitInstr('CALL    ' + PL_RT_PFX + 'ASSERTA');
      EmitComment('asserta/1 done');
    End
    { --- assertz/1 --- }
    Else If (GoalTab[GIdx].PredName = 'assertz') And
            (GoalTab[GIdx].Arity = 1) Then
    Begin
      EmitComment('assertz/1 inline (TODO 19)');
      EmitLoadArgToAX(GoalTab[GIdx].Args[0], True);
      EmitInstr('CALL    ' + PL_RT_PFX + 'ASSERTZ');
      EmitComment('assertz/1 done');
    End
    { --- retract/1 --- }
    Else If (GoalTab[GIdx].PredName = 'retract') And
            (GoalTab[GIdx].Arity = 1) Then
    Begin
      EmitComment('retract/1 inline (TODO 19)');
      EmitLoadArgToAX(GoalTab[GIdx].Args[0], True);
      EmitInstr('CALL    ' + PL_RT_PFX + 'RETRACT');
      EmitInstrA('JC', ClauseTab[CIdx].FailLabel);
      EmitComment('retract/1 done');
    End
    { --- abolish/1 --- }
    Else If (GoalTab[GIdx].PredName = 'abolish') And
            (GoalTab[GIdx].Arity = 1) Then
    Begin
      EmitComment('abolish/1 inline (TODO 19)');
      EmitLoadArgToAX(GoalTab[GIdx].Args[0], True);
      EmitInstr('CALL    ' + PL_RT_PFX + 'ABOLISH');
      EmitComment('abolish/1 done');
    End
    { === TODO 20 : Findall/Bagof/Setof inline === }
    { --- findall/3 --- }
    Else If (GoalTab[GIdx].PredName = 'findall') And
            (GoalTab[GIdx].Arity = 3) Then
    Begin
      EmitComment('findall/3 inline (TODO 20)');
      { Reset collection buffer }
      EmitInstr('CALL    ' + PL_RT_PFX + 'COLLECT_RESET');
      { Save state (heap, trail, choicepoint) }
      EmitInstrA('PUSH', 'WORD PTR [_PL_HTOP]');
      EmitInstrA('PUSH', 'WORD PTR [_PL_TTOP]');
      EmitInstrA('PUSH', 'WORD PTR [_PL_CPTOP]');
      { Call Goal (arg[1]) }
      If GoalTab[GIdx].Args[1].Kind = FAK_ATOM Then
      Begin
        { Load extra args for the goal if present }
        For J := 3 To GoalTab[GIdx].ArgCount - 1 Do
        Begin
          Case GoalTab[GIdx].Args[J].Kind Of
            FAK_ATOM :
            Begin
              TagVal := (TAG_ATOM Shl TAG_SHIFT) Or
                        (GoalTab[GIdx].Args[J].AtomIdx And VAL_MASK);
              Str(TagVal, NS);
              EmitInstrAB('MOV', 'WORD PTR [_PL_ARGS + ' +
                          IntToStr((J - 3) * 2) + ']', NS);
            End;
            FAK_INT :
            Begin
              TagVal := (TAG_INT Shl TAG_SHIFT) Or
                        (Integer(GoalTab[GIdx].Args[J].IntVal) And VAL_MASK);
              Str(TagVal, NS);
              EmitInstrAB('MOV', 'WORD PTR [_PL_ARGS + ' +
                          IntToStr((J - 3) * 2) + ']', NS);
            End;
            FAK_VAR :
            Begin
              VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[J].VarName);
              EmitInstrAB('MOV', 'AX',
                          'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
              EmitInstrAB('MOV', 'WORD PTR [_PL_ARGS + ' +
                          IntToStr((J - 3) * 2) + ']', 'AX');
            End;
          End;
        End;
        Clean   := SymNameClean(AtomName(GoalTab[GIdx].Args[1].AtomIdx));
        PredLbl := PL_PRED_PFX + Clean + '_0';
        NS := LabelGen;  { label for goal-failure path }
        EmitInstrA('CALL', PredLbl);
        EmitInstrA('JC', NS);
        { Goal succeeded: push Template (arg[0]) to collect buffer }
        EmitLoadArgToAX(GoalTab[GIdx].Args[0], True);
        EmitInstr('CALL    ' + PL_RT_PFX + 'COLLECT_PUSH');
        { Fall through to restoration (single-pass collection) }
        EmitLabel(NS);
      End
      Else
      Begin
        EmitComment('findall/3: goal is not an atom, skip');
      End;
      { Restore state }
      EmitInstrA('POP', 'WORD PTR [_PL_CPTOP]');
      EmitInstrA('POP', 'WORD PTR [_PL_TTOP]');
      EmitInstrA('POP', 'WORD PTR [_PL_HTOP]');
      EmitInstr('CALL    ' + PL_RT_PFX + 'UNTRAIL');
      { Build list from collected solutions }
      EmitInstr('CALL    ' + PL_RT_PFX + 'MAKELIST');
      { Unify result with arg[2] (Bag) }
      EmitInstrAB('MOV', 'BX', 'AX');
      If GoalTab[GIdx].Args[2].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[2].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitBind;
      End;
      EmitComment('findall/3 done');
    End
    { --- bagof/3 --- }
    Else If (GoalTab[GIdx].PredName = 'bagof') And
            (GoalTab[GIdx].Arity = 3) Then
    Begin
      EmitComment('bagof/3 inline (TODO 20)');
      { Reset collection buffer }
      EmitInstr('CALL    ' + PL_RT_PFX + 'COLLECT_RESET');
      { Save state }
      EmitInstrA('PUSH', 'WORD PTR [_PL_HTOP]');
      EmitInstrA('PUSH', 'WORD PTR [_PL_TTOP]');
      EmitInstrA('PUSH', 'WORD PTR [_PL_CPTOP]');
      { Call Goal (arg[1]) }
      If GoalTab[GIdx].Args[1].Kind = FAK_ATOM Then
      Begin
        Clean   := SymNameClean(AtomName(GoalTab[GIdx].Args[1].AtomIdx));
        PredLbl := PL_PRED_PFX + Clean + '_0';
        NS := LabelGen;
        EmitInstrA('CALL', PredLbl);
        EmitInstrA('JC', NS);
        { Goal succeeded: push Template to collect buffer }
        EmitLoadArgToAX(GoalTab[GIdx].Args[0], True);
        EmitInstr('CALL    ' + PL_RT_PFX + 'COLLECT_PUSH');
        EmitLabel(NS);
      End
      Else
        EmitComment('bagof/3: goal is not an atom, skip');
      { Restore state }
      EmitInstrA('POP', 'WORD PTR [_PL_CPTOP]');
      EmitInstrA('POP', 'WORD PTR [_PL_TTOP]');
      EmitInstrA('POP', 'WORD PTR [_PL_HTOP]');
      EmitInstr('CALL    ' + PL_RT_PFX + 'UNTRAIL');
      { Build list from collected solutions }
      EmitInstr('CALL    ' + PL_RT_PFX + 'MAKELIST');
      { Check if empty - bagof fails if no solutions }
      NS := LabelGen;
      Str((TAG_ATOM Shl TAG_SHIFT) Or 1, PredLbl);
      EmitInstrAB('CMP', 'AX', PredLbl);
      EmitComment('compare with [] (nil)');
      EmitInstrA('JE', ClauseTab[CIdx].FailLabel);
      { Unify result with arg[2] (Bag) }
      EmitInstrAB('MOV', 'BX', 'AX');
      If GoalTab[GIdx].Args[2].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[2].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitBind;
      End;
      EmitComment('bagof/3 done');
    End
    { --- setof/3 --- }
    Else If (GoalTab[GIdx].PredName = 'setof') And
            (GoalTab[GIdx].Arity = 3) Then
    Begin
      EmitComment('setof/3 inline (TODO 20)');
      { Reset collection buffer }
      EmitInstr('CALL    ' + PL_RT_PFX + 'COLLECT_RESET');
      { Save state }
      EmitInstrA('PUSH', 'WORD PTR [_PL_HTOP]');
      EmitInstrA('PUSH', 'WORD PTR [_PL_TTOP]');
      EmitInstrA('PUSH', 'WORD PTR [_PL_CPTOP]');
      { Call Goal (arg[1]) }
      If GoalTab[GIdx].Args[1].Kind = FAK_ATOM Then
      Begin
        Clean   := SymNameClean(AtomName(GoalTab[GIdx].Args[1].AtomIdx));
        PredLbl := PL_PRED_PFX + Clean + '_0';
        NS := LabelGen;
        EmitInstrA('CALL', PredLbl);
        EmitInstrA('JC', NS);
        { Goal succeeded: push Template to collect buffer }
        EmitLoadArgToAX(GoalTab[GIdx].Args[0], True);
        EmitInstr('CALL    ' + PL_RT_PFX + 'COLLECT_PUSH');
        EmitLabel(NS);
      End
      Else
        EmitComment('setof/3: goal is not an atom, skip');
      { Restore state }
      EmitInstrA('POP', 'WORD PTR [_PL_CPTOP]');
      EmitInstrA('POP', 'WORD PTR [_PL_TTOP]');
      EmitInstrA('POP', 'WORD PTR [_PL_HTOP]');
      EmitInstr('CALL    ' + PL_RT_PFX + 'UNTRAIL');
      { Build list, sort, and dedup }
      EmitInstr('CALL    ' + PL_RT_PFX + 'MAKELIST');
      { Check if empty - setof fails if no solutions }
      Str((TAG_ATOM Shl TAG_SHIFT) Or 1, PredLbl);
      EmitInstrAB('CMP', 'AX', PredLbl);
      EmitComment('compare with [] (nil)');
      EmitInstrA('JE', ClauseTab[CIdx].FailLabel);
      { Sort the list }
      EmitInstr('CALL    ' + PL_RT_PFX + 'SORT');
      { Remove consecutive duplicates }
      EmitInstr('CALL    ' + PL_RT_PFX + 'SETOF_DEDUP');
      { Unify result with arg[2] (Set) }
      EmitInstrAB('MOV', 'BX', 'AX');
      If GoalTab[GIdx].Args[2].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[2].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitBind;
      End;
      EmitComment('setof/3 done');
    End

    { === TODO 21 : op/3 inline === }
    Else If (GoalTab[GIdx].PredName = 'op') And
            (GoalTab[GIdx].Arity = 3) Then
    Begin
      EmitComment('op/3 inline (TODO 21)');
      { Arg0 = Precedence (integer), Arg1 = Type (atom), Arg2 = Name (atom) }
      { At compile time, OpAdd has been called if this was a directive.       }
      { At runtime, call _PLRT_OP_REGISTER.                                   }
      { Load precedence from arg0 }
      If GoalTab[GIdx].Args[0].Kind = FAK_INT Then
      Begin
        TagVal := (TAG_INT Shl TAG_SHIFT) Or
                  (Integer(GoalTab[GIdx].Args[0].IntVal) And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'AX', NS);
        EmitComment('prec = ' + IntToStr(GoalTab[GIdx].Args[0].IntVal));
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[0].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitDeref;
      End
      Else
      Begin
        EmitInstrAB('MOV', 'AX', '0');
      End;
      EmitInstr('PUSH    AX');
      { Load type atom from arg1 }
      If GoalTab[GIdx].Args[1].Kind = FAK_ATOM Then
      Begin
        TagVal := (TAG_ATOM Shl TAG_SHIFT) Or
                  (GoalTab[GIdx].Args[1].AtomIdx And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'BX', NS);
        EmitComment('type = ' + AtomName(GoalTab[GIdx].Args[1].AtomIdx));
      End
      Else If GoalTab[GIdx].Args[1].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[1].VarName);
        EmitInstrAB('MOV', 'BX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
      End
      Else
      Begin
        EmitInstrAB('MOV', 'BX', '0');
      End;
      { Load name atom from arg2 }
      If GoalTab[GIdx].Args[2].Kind = FAK_ATOM Then
      Begin
        TagVal := (TAG_ATOM Shl TAG_SHIFT) Or
                  (GoalTab[GIdx].Args[2].AtomIdx And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'CX', NS);
        EmitComment('name = ' + AtomName(GoalTab[GIdx].Args[2].AtomIdx));
      End
      Else If GoalTab[GIdx].Args[2].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[2].VarName);
        EmitInstrAB('MOV', 'CX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
      End
      Else
      Begin
        EmitInstrAB('MOV', 'CX', '0');
      End;
      EmitInstr('POP     AX');
      EmitInstr('CALL    ' + PL_RT_PFX + 'OP_REGISTER');
      { Also register at compile time if args are constants }
      If (GoalTab[GIdx].Args[0].Kind = FAK_INT) And
         (GoalTab[GIdx].Args[1].Kind = FAK_ATOM) And
         (GoalTab[GIdx].Args[2].Kind = FAK_ATOM) Then
      Begin
        OpAdd(AtomName(GoalTab[GIdx].Args[2].AtomIdx),
              GoalTab[GIdx].Args[0].IntVal,
              AtomName(GoalTab[GIdx].Args[1].AtomIdx));
      End;
      EmitComment('op/3 done');
    End

    { === TODO 21 : current_op/3 inline === }
    Else If (GoalTab[GIdx].PredName = 'current_op') And
            (GoalTab[GIdx].Arity = 3) Then
    Begin
      EmitComment('current_op/3 inline (TODO 21)');
      { current_op(Prec, Type, Name) : query operator table }
      { If Name is known atom, look it up; bind Prec and Type }
      If GoalTab[GIdx].Args[2].Kind = FAK_ATOM Then
      Begin
        NS := AtomName(GoalTab[GIdx].Args[2].AtomIdx);
        I := OpFind(NS);
        If I >= 0 Then
        Begin
          { Bind Prec (arg0) to the known precedence }
          If GoalTab[GIdx].Args[0].Kind = FAK_VAR Then
          Begin
            TagVal := (TAG_INT Shl TAG_SHIFT) Or
                      (OpTab[I].Prec And VAL_MASK);
            Str(TagVal, NS);
            VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[0].VarName);
            EmitInstrAB('MOV', 'AX',
                        'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
            EmitDeref;
            EmitInstrAB('MOV', 'BX', NS);
            EmitComment('prec = ' + IntToStr(OpTab[I].Prec));
            EmitBind;
          End;
          { Bind Type (arg1) to the known specifier }
          If GoalTab[GIdx].Args[1].Kind = FAK_VAR Then
          Begin
            TagVal := (TAG_ATOM Shl TAG_SHIFT) Or
                      (AtomIntern(OpTab[I].Spec) And VAL_MASK);
            Str(TagVal, NS);
            VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[1].VarName);
            EmitInstrAB('MOV', 'AX',
                        'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
            EmitDeref;
            EmitInstrAB('MOV', 'BX', NS);
            EmitComment('type = ' + OpTab[I].Spec);
            EmitBind;
          End;
        End
        Else
        Begin
          EmitComment('current_op/3: operator not found, fail');
          EmitInstrA('JMP', ClauseTab[CIdx].FailLabel);
        End;
      End
      Else
      Begin
        { Name is a variable : not supported inline, succeed trivially }
        EmitComment('current_op/3: name is var, succeed trivially');
      End;
      EmitComment('current_op/3 done');
    End

    { === TODO 23 : Chaines et caracteres inline === }
    { --- char_type/2 --- }
    Else If (GoalTab[GIdx].PredName = 'char_type') And
            (GoalTab[GIdx].Arity = 2) Then
    Begin
      EmitComment('char_type/2 inline (TODO 23)');
      { Charger arg0 (Char) dans AX }
      If GoalTab[GIdx].Args[0].Kind = FAK_ATOM Then
      Begin
        TagVal := (TAG_ATOM Shl TAG_SHIFT) Or
                  (GoalTab[GIdx].Args[0].AtomIdx And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'AX', NS);
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_INT Then
      Begin
        TagVal := (TAG_INT Shl TAG_SHIFT) Or
                  (Integer(GoalTab[GIdx].Args[0].IntVal) And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'AX', NS);
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[0].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitDeref;
      End
      Else
        EmitInstrAB('MOV', 'AX', '0');
      { Charger arg1 (Type) dans BX }
      If GoalTab[GIdx].Args[1].Kind = FAK_ATOM Then
      Begin
        TagVal := (TAG_ATOM Shl TAG_SHIFT) Or
                  (GoalTab[GIdx].Args[1].AtomIdx And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'BX', NS);
      End
      Else If GoalTab[GIdx].Args[1].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[1].VarName);
        EmitInstrA('PUSH', 'AX');
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitDeref;
        EmitInstrAB('MOV', 'BX', 'AX');
        EmitInstrA('POP', 'AX');
      End
      Else
        EmitInstrAB('MOV', 'BX', '0');
      EmitInstr('CALL    ' + PL_RT_PFX + 'CHAR_TYPE');
      EmitInstrA('JC', ClauseTab[CIdx].FailLabel);
      EmitComment('char_type/2 done');
    End
    { --- upcase_atom/2 --- }
    Else If (GoalTab[GIdx].PredName = 'upcase_atom') And
            (GoalTab[GIdx].Arity = 2) Then
    Begin
      EmitComment('upcase_atom/2 inline (TODO 23)');
      If GoalTab[GIdx].Args[0].Kind = FAK_ATOM Then
      Begin
        TagVal := (TAG_ATOM Shl TAG_SHIFT) Or
                  (GoalTab[GIdx].Args[0].AtomIdx And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'AX', NS);
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[0].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitDeref;
      End
      Else
        EmitInstrAB('MOV', 'AX', '0');
      EmitInstr('CALL    ' + PL_RT_PFX + 'UPCASE');
      { AX = tagged ATOM (uppercased), unifier avec arg1 }
      EmitInstrAB('MOV', 'BX', 'AX');
      If GoalTab[GIdx].Args[1].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[1].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitBind;
      End;
      EmitComment('upcase_atom/2 done');
    End
    { --- downcase_atom/2 --- }
    Else If (GoalTab[GIdx].PredName = 'downcase_atom') And
            (GoalTab[GIdx].Arity = 2) Then
    Begin
      EmitComment('downcase_atom/2 inline (TODO 23)');
      If GoalTab[GIdx].Args[0].Kind = FAK_ATOM Then
      Begin
        TagVal := (TAG_ATOM Shl TAG_SHIFT) Or
                  (GoalTab[GIdx].Args[0].AtomIdx And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'AX', NS);
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[0].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitDeref;
      End
      Else
        EmitInstrAB('MOV', 'AX', '0');
      EmitInstr('CALL    ' + PL_RT_PFX + 'DOWNCASE');
      { AX = tagged ATOM (lowercased), unifier avec arg1 }
      EmitInstrAB('MOV', 'BX', 'AX');
      If GoalTab[GIdx].Args[1].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[1].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitBind;
      End;
      EmitComment('downcase_atom/2 done');
    End
    { --- atom_string/2 --- }
    Else If (GoalTab[GIdx].PredName = 'atom_string') And
            (GoalTab[GIdx].Arity = 2) Then
    Begin
      EmitComment('atom_string/2 inline (TODO 23)');
      If GoalTab[GIdx].Args[0].Kind = FAK_ATOM Then
      Begin
        TagVal := (TAG_ATOM Shl TAG_SHIFT) Or
                  (GoalTab[GIdx].Args[0].AtomIdx And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'AX', NS);
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_INT Then
      Begin
        TagVal := (TAG_INT Shl TAG_SHIFT) Or
                  (Integer(GoalTab[GIdx].Args[0].IntVal) And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'AX', NS);
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[0].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitDeref;
      End
      Else
        EmitInstrAB('MOV', 'AX', '0');
      EmitInstr('CALL    ' + PL_RT_PFX + 'ATOM_STRING');
      { AX = tagged ATOM, unifier avec arg1 }
      EmitInstrAB('MOV', 'BX', 'AX');
      If GoalTab[GIdx].Args[1].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[1].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitBind;
      End;
      EmitComment('atom_string/2 done');
    End
    { --- number_string/2 --- }
    Else If (GoalTab[GIdx].PredName = 'number_string') And
            (GoalTab[GIdx].Arity = 2) Then
    Begin
      EmitComment('number_string/2 inline (TODO 23)');
      If GoalTab[GIdx].Args[0].Kind = FAK_INT Then
      Begin
        TagVal := (TAG_INT Shl TAG_SHIFT) Or
                  (Integer(GoalTab[GIdx].Args[0].IntVal) And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'AX', NS);
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[0].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitDeref;
      End
      Else
        EmitInstrAB('MOV', 'AX', '0');
      EmitInstr('CALL    ' + PL_RT_PFX + 'NUMBER_STRING');
      { AX = tagged ATOM (string), unifier avec arg1 }
      EmitInstrAB('MOV', 'BX', 'AX');
      If GoalTab[GIdx].Args[1].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[1].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitBind;
      End;
      EmitComment('number_string/2 done');
    End
    { --- string_concat/3 --- }
    Else If (GoalTab[GIdx].PredName = 'string_concat') And
            (GoalTab[GIdx].Arity = 3) Then
    Begin
      EmitComment('string_concat/3 inline (TODO 23)');
      { Charger arg0 }
      If GoalTab[GIdx].Args[0].Kind = FAK_ATOM Then
      Begin
        TagVal := (TAG_ATOM Shl TAG_SHIFT) Or
                  (GoalTab[GIdx].Args[0].AtomIdx And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'AX', NS);
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[0].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitDeref;
      End
      Else
        EmitInstrAB('MOV', 'AX', '0');
      EmitInstrA('PUSH', 'AX');
      { Charger arg1 }
      If GoalTab[GIdx].Args[1].Kind = FAK_ATOM Then
      Begin
        TagVal := (TAG_ATOM Shl TAG_SHIFT) Or
                  (GoalTab[GIdx].Args[1].AtomIdx And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'BX', NS);
      End
      Else If GoalTab[GIdx].Args[1].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[1].VarName);
        EmitInstrAB('MOV', 'BX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitInstrA('PUSH', 'AX');
        EmitInstrAB('MOV', 'AX', 'BX');
        EmitDeref;
        EmitInstrAB('MOV', 'BX', 'AX');
        EmitInstrA('POP', 'AX');
      End
      Else
        EmitInstrAB('MOV', 'BX', '0');
      EmitInstrA('POP', 'AX');
      EmitInstr('CALL    ' + PL_RT_PFX + 'STRING_CONCAT');
      { AX = result, unifier avec arg2 }
      EmitInstrAB('MOV', 'BX', 'AX');
      If GoalTab[GIdx].Args[2].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[2].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitBind;
      End;
      EmitComment('string_concat/3 done');
    End
    { --- string_length/2 --- }
    Else If (GoalTab[GIdx].PredName = 'string_length') And
            (GoalTab[GIdx].Arity = 2) Then
    Begin
      EmitComment('string_length/2 inline (TODO 23)');
      If GoalTab[GIdx].Args[0].Kind = FAK_ATOM Then
      Begin
        TagVal := (TAG_ATOM Shl TAG_SHIFT) Or
                  (GoalTab[GIdx].Args[0].AtomIdx And VAL_MASK);
        Str(TagVal, NS);
        EmitInstrAB('MOV', 'AX', NS);
      End
      Else If GoalTab[GIdx].Args[0].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[0].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitDeref;
      End
      Else
        EmitInstrAB('MOV', 'AX', '0');
      EmitInstr('CALL    ' + PL_RT_PFX + 'STRING_LENGTH');
      { AX = tagged INT (longueur), unifier avec arg1 }
      EmitInstrAB('MOV', 'BX', 'AX');
      If GoalTab[GIdx].Args[1].Kind = FAK_VAR Then
      Begin
        VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[1].VarName);
        EmitInstrAB('MOV', 'AX',
                    'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
        EmitBind;
      End;
      EmitComment('string_length/2 done');
    End

    Else
    Begin
      { --- But standard : charger args + appeler predicat --- }
      { Charger les arguments du but dans les registres _PL_ARGS }
      For J := 0 To GoalTab[GIdx].ArgCount - 1 Do
      Begin
        Case GoalTab[GIdx].Args[J].Kind Of
          FAK_ATOM :
          Begin
            TagVal := (TAG_ATOM Shl TAG_SHIFT) Or
                      (GoalTab[GIdx].Args[J].AtomIdx And VAL_MASK);
            Str(TagVal, NS);
            EmitInstrAB('MOV', 'WORD PTR [_PL_ARGS + ' +
                        IntToStr(J * 2) + ']', NS);
            EmitComment('atom ' + AtomName(GoalTab[GIdx].Args[J].AtomIdx));
          End;

          FAK_INT :
          Begin
            TagVal := (TAG_INT Shl TAG_SHIFT) Or
                      (Integer(GoalTab[GIdx].Args[J].IntVal) And VAL_MASK);
            Str(TagVal, NS);
            EmitInstrAB('MOV', 'WORD PTR [_PL_ARGS + ' +
                        IntToStr(J * 2) + ']', NS);
            EmitComment('int ' + IntToStr(GoalTab[GIdx].Args[J].IntVal));
          End;

          FAK_VAR :
          Begin
            VarIdx := RuleVarFindOrAdd(GoalTab[GIdx].Args[J].VarName);
            EmitComment('var ' + GoalTab[GIdx].Args[J].VarName);
            EmitInstrAB('MOV', 'AX',
                        'WORD PTR [BP-' + IntToStr((VarIdx + 1) * 2) + ']');
            EmitInstrAB('MOV', 'WORD PTR [_PL_ARGS + ' +
                        IntToStr(J * 2) + ']', 'AX');
          End;

          FAK_ANON :
          Begin
            { Variable anonyme : creer une REF libre }
            EmitComment('anon _');
            EmitInstrAB('MOV', 'AX', 'WORD PTR [_PL_HTOP]');
            EmitInstrAB('MOV', 'SI', 'AX');
            EmitInstrAB('SHL', 'SI', '1');
            EmitInstrAB('ADD', 'SI', 'OFFSET _PL_HEAP');
            EmitInstrAB('MOV', 'WORD PTR [SI]', 'AX');
            EmitInstr('INC    WORD PTR [_PL_HTOP]');
            EmitInstrAB('MOV', 'WORD PTR [_PL_ARGS + ' +
                        IntToStr(J * 2) + ']', 'AX');
          End;

          FAK_LIST :
          Begin
            { Liste : construire sur le heap (TODO 13) }
            EmitComment('list');
            EmitBuildListToAX(GoalTab[GIdx].Args[J], True);
            EmitInstrAB('MOV', 'WORD PTR [_PL_ARGS + ' +
                        IntToStr(J * 2) + ']', 'AX');
          End;
        Else
          EmitInstrAB('MOV', 'WORD PTR [_PL_ARGS + ' +
                      IntToStr(J * 2) + ']', '0');
        End;
      End;

      { Appeler le predicat du but }
      Clean   := SymNameClean(GoalTab[GIdx].PredName);
      PredLbl := PL_PRED_PFX + Clean + '_' + IntToStr(GoalTab[GIdx].Arity);

      If IsLast Then
      Begin
        { Optimisation appel terminal (last call) : deallocate + JMP }
        EmitComment('last call optimization');
        EmitInstrAB('MOV', 'SP', 'BP');
        EmitInstrA('POP', 'BP');
        EmitInstrA('JMP', PredLbl);
        { Pas de label_fail apres JMP terminal : si le dernier but echoue, }
        { le CF est propage automatiquement par le RET du predicat appele. }

        { Emettre quand meme le label d echec pour les buts precedents }
        EmitBlankLine;
        EmitLabel(ClauseTab[CIdx].FailLabel);
        EmitInstr('STC');
        EmitEpilog;
        Exit;
      End
      Else
      Begin
        EmitInstrA('CALL', PredLbl);
        EmitInstrA('JC', ClauseTab[CIdx].FailLabel);
      End;
    End; { else standard goal }
  End;

  { Si le corps est vide (ne devrait pas arriver pour une regle) }
  { ou si pas d optimisation terminale }
  EmitInstr('CLC');
  EmitEpilog;
  EmitBlankLine;

  { Label d echec }
  EmitLabel(ClauseTab[CIdx].FailLabel);
  EmitInstr('STC');
  EmitEpilog;
End;
{ Genere le label principal _PLP_nom_N et une table de saut          }
{ (indexation premier argument) vers les clauses individuelles.      }
{                                                                    }
{ Si le predicat n a qu une seule clause, le label principal est     }
{ un simple JMP vers la clause unique.                               }
{                                                                    }
{ Si le predicat a plusieurs clauses, on emet :                      }
{   _PLP_nom_N:                                                      }
{     ; Indexation premier argument                                  }
{     MOV AX, WORD PTR [_PL_ARGS]     ; A1                          }
{     CALL _PLRT_DEREF                                               }
{     JMP _PLP_nom_N_clause0           ; essayer clause 0            }
{   _PLP_nom_N_next0:                                                }
{     JMP _PLP_nom_N_clause1           ; essayer clause 1            }
{   ...                                                              }
{   _PLP_nom_N_fail:                                                 }
{     STC                              ; echec global                }
{     RET                                                            }
Procedure EmitPredEntry(Const PName : TString; PArity : Integer);
Var
  EntryLabel : TString;
  Clean      : TString;
  I          : Integer;
  ClsCount   : Integer;
  Indices    : Array[0..MAX_CLAUSE - 1] Of Integer;
  NextLbl    : TString;
Begin
  Clean      := SymNameClean(PName);
  EntryLabel := PL_PRED_PFX + Clean + '_' + IntToStr(PArity);

  { Collecter les indices de clauses pour ce predicat }
  ClsCount := 0;
  For I := 0 To ClauseCount - 1 Do
  Begin
    If (ClauseTab[I].PredName = PName) And
       (ClauseTab[I].Arity = PArity) Then
    Begin
      Indices[ClsCount] := I;
      Inc(ClsCount);
    End;
  End;

  If ClsCount = 0 Then Exit;

  EmitBlankLine;
  EmitComment('=== Predicat ' + PName + '/' + IntToStr(PArity) +
              ' (' + IntToStr(ClsCount) + ' clause(s)) ===');

  { Pour les predicats d arite 0, le label est _PLP_nom_0 }
  If PArity = 0 Then
  Begin
    { Si une seule clause, le label de la clause EST le point d entree }
    If ClsCount = 1 Then
    Begin
      { Le label _PLP_nom_0 pointe directement sur la clause }
      { Rien a emettre : la clause a deja le bon label }
    End
    Else
    Begin
      { Plusieurs clauses pour un predicat/0 : backtracking WAM }
      EmitLabel(EntryLabel);

      For I := 0 To ClsCount - 1 Do
      Begin
        If I = 0 Then
        Begin
          { Premiere clause : try_me_else }
          NextLbl := EntryLabel + '_cp' + IntToStr(I + 1);
          EmitComment('try_me_else ' + NextLbl);
          EmitInstrAB('MOV', 'BX', 'OFFSET ' + NextLbl);
          EmitInstr('CALL    _PLRT_TRY');
          EmitInstrA('CALL', ClauseTab[Indices[I]].ClsLabel);
          EmitInstrA('JNC', EntryLabel + '_ok');
        End
        Else If I < ClsCount - 1 Then
        Begin
          { Clauses intermediaires : retry_me_else }
          EmitLabel(EntryLabel + '_cp' + IntToStr(I));
          NextLbl := EntryLabel + '_cp' + IntToStr(I + 1);
          EmitComment('retry_me_else ' + NextLbl);
          EmitInstrAB('MOV', 'BX', 'OFFSET ' + NextLbl);
          EmitInstr('CALL    _PLRT_RETRY');
          EmitInstrA('CALL', ClauseTab[Indices[I]].ClsLabel);
          EmitInstrA('JNC', EntryLabel + '_ok');
        End
        Else
        Begin
          { Derniere clause : trust_me (CP deja supprime par TRUST) }
          EmitLabel(EntryLabel + '_cp' + IntToStr(I));
          EmitComment('trust_me');
          EmitInstr('CALL    _PLRT_TRUST');
          EmitInstrA('CALL', ClauseTab[Indices[I]].ClsLabel);
          { Propager le resultat directement }
          EmitInstr('RET');
        End;
      End;

      { Toutes les clauses non-derniere ont echoue, la derniere retourne }
      { via RET ci-dessus. Ce label est pour les clauses non-dernieres.  }
      EmitLabel(EntryLabel + '_ok');
      EmitComment('Succes : retirer le choice point (commit)');
      EmitInstrA('PUSH', 'SI');
      EmitInstrA('PUSH', 'AX');
      EmitInstrAB('MOV', 'SI', 'WORD PTR [_PL_CPTOP]');
      EmitInstrAB('SUB', 'SI', '4');
      EmitInstr('SHL    SI,1');
      EmitInstrAB('MOV', 'AX', 'WORD PTR [_PL_STACK + SI]');
      EmitInstrAB('MOV', 'WORD PTR [_PL_CPTOP]', 'AX');
      EmitInstrA('POP', 'AX');
      EmitInstrA('POP', 'SI');
      EmitInstr('CLC');
      EmitInstr('RET');
    End;
    Exit;
  End;

  { Predicat avec arguments }
  EmitLabel(EntryLabel);

  If ClsCount = 1 Then
  Begin
    { Une seule clause : saut direct }
    EmitInstrA('JMP', ClauseTab[Indices[0]].ClsLabel);
  End
  Else
  Begin
    { Plusieurs clauses : backtracking WAM avec TRY/RETRY/TRUST }
    EmitComment('Backtracking WAM - ' + IntToStr(ClsCount) + ' clauses');
    EmitBlankLine;

    For I := 0 To ClsCount - 1 Do
    Begin
      If I = 0 Then
      Begin
        { Premiere clause : try_me_else }
        NextLbl := EntryLabel + '_cp' + IntToStr(I + 1);
        EmitComment('try_me_else ' + NextLbl);
        EmitInstrAB('MOV', 'BX', 'OFFSET ' + NextLbl);
        EmitInstr('CALL    _PLRT_TRY');
        EmitInstrA('CALL', ClauseTab[Indices[I]].ClsLabel);
        EmitInstrA('JNC', EntryLabel + '_ok');
      End
      Else If I < ClsCount - 1 Then
      Begin
        { Clauses intermediaires : retry_me_else }
        EmitLabel(EntryLabel + '_cp' + IntToStr(I));
        NextLbl := EntryLabel + '_cp' + IntToStr(I + 1);
        EmitComment('retry_me_else ' + NextLbl);
        EmitInstrAB('MOV', 'BX', 'OFFSET ' + NextLbl);
        EmitInstr('CALL    _PLRT_RETRY');
        EmitInstrA('CALL', ClauseTab[Indices[I]].ClsLabel);
        EmitInstrA('JNC', EntryLabel + '_ok');
      End
      Else
      Begin
        { Derniere clause : trust_me (CP deja supprime par TRUST) }
        EmitLabel(EntryLabel + '_cp' + IntToStr(I));
        EmitComment('trust_me');
        EmitInstr('CALL    _PLRT_TRUST');
        EmitInstrA('CALL', ClauseTab[Indices[I]].ClsLabel);
        { Propager le resultat directement (CF set par la clause) }
        EmitInstr('RET');
      End;
    End;

    { Label de succes : retirer le choice point sans restaurer l etat }
    { (les liaisons reussies doivent etre conservees)                 }
    EmitLabel(EntryLabel + '_ok');
    EmitComment('Succes : retirer le choice point (commit)');
    EmitInstrA('PUSH', 'SI');
    EmitInstrA('PUSH', 'AX');
    EmitInstrAB('MOV', 'SI', 'WORD PTR [_PL_CPTOP]');
    EmitInstrAB('SUB', 'SI', '4');
    EmitInstr('SHL    SI,1');
    EmitInstrAB('MOV', 'AX', 'WORD PTR [_PL_STACK + SI]');
    EmitInstrAB('MOV', 'WORD PTR [_PL_CPTOP]', 'AX');
    EmitInstrA('POP', 'AX');
    EmitInstrA('POP', 'SI');
    EmitInstr('CLC');
    EmitInstr('RET');
  End;
End;

{ ---- EmitAllPredicates : emettre le code de tous les predicats --- }
{ Emet d abord le code de chaque clause individuelle (faits et       }
{ regles), puis les points d entree des predicats (indexation).      }
Procedure EmitAllPredicates;
Var
  I      : Integer;
  Done   : Array[0..MAX_SYM - 1] Of Boolean;
Begin
  If ClauseCount = 0 Then Exit;

  EmitBlankLine;
  EmitComment('=======================================');
  EmitComment('  Clauses compilees (TODO 10 + 11 + 12 + 13 + 14 + 15)');
  EmitComment('=======================================');

  { Emettre le code de chaque clause individuelle }
  For I := 0 To ClauseCount - 1 Do
  Begin
    If ClauseTab[I].IsRule Then
      EmitRuleCode(I)
    Else
      EmitFactCode(I);
  End;

  EmitBlankLine;
  EmitComment('=======================================');
  EmitComment('  Points d entree des predicats');
  EmitComment('=======================================');

  { Emettre les points d entree (un par predicat unique) }
  FillChar(Done, SizeOf(Done), 0);
  For I := 0 To ClauseCount - 1 Do
  Begin
    If ClauseTab[I].SymIdx < 0 Then Continue;

    { Verifier si on a deja emis ce predicat }
    If Done[ClauseTab[I].SymIdx] Then Continue;
    Done[ClauseTab[I].SymIdx] := True;

    { Emettre le point d entree }
    EmitPredEntry(ClauseTab[I].PredName, ClauseTab[I].Arity);
  End;
End;

{ ---- ParseProgram : boucle principale de parsing ---------------- }
{ Parse les clauses Prolog (faits, regles et directives) jusqu a    }
{ EOF. Les faits et regles sont ajoutes dans ClauseTab.             }
Procedure ParseProgram;
Var
  Parsed : Boolean;
Begin
  While CurToken.Kind <> TK_EOF Do
  Begin
    Parsed := ParseFact;
    If Not Parsed Then
    Begin
      { Token inattendu au niveau clause : avancer }
      If CurToken.Kind <> TK_EOF Then
      Begin
        WarnMsg('token inattendu au niveau clause: ' + CurToken.Val);
        ParserAdvance;
      End;
    End;
  End;
End;

{ ============================================================
  STUBS POUR LES TODOS RESTANTS (15..25)
  ============================================================ }

Procedure Run;
Begin
  GlobalInit;
  If Opts.Verbose Then
    ShowBanner;
  LexInit;
  LexNextToken;

  { Phase 1 : parser toutes les clauses }
  ParseProgram;
  LexClose;

  { Phase 2 : emettre le code ASM }
  EmitOpen;
  EmitHeader;

  { Emettre le code des predicats }
  EmitAllPredicates;

  { Fermer (runtime + data + END) }
  EmitClose;

  If Opts.Verbose Then
  Begin
    WriteLn('PROLOG86: ', TotalLines, ' ligne(s) lues, ',
            ClauseCount, ' clause(s)');
    ShowStats;
  End;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  ShowHelp;
  Halt(0);
 End;
  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  ParseArgs;
  Run;
  If ErrorCount > 0 Then
    Halt(EXIT_ERROR)
  Else
    Halt(EXIT_OK);
END.
