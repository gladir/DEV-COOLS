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

  TODO 13 - LISTES
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

  TODO 14 - ARITHMETIQUE (IS ET EVALUATION)
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

  TODO 15 - COMPARAISON ET TESTS DE TYPE
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

  TODO 16 - CONTROLE : CUT, IF-THEN-ELSE, NEGATION
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

  TODO 17 - ENTREES/SORTIES
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

  TODO 18 - PREDICATS PREDEFINIS (BUILT-IN)
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

  TODO 19 - ASSERT ET RETRACT (BASE DE DONNEES DYNAMIQUE)
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

  TODO 20 - FINDALL, BAGOF, SETOF (COLLECTE DE SOLUTIONS)
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

  TODO 21 - OPERATEURS UTILISATEUR (OP/3)
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

  TODO 22 - DIRECTIVES ET CHARGEMENT
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

  TODO 23 - CHAINES ET CARACTERES
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
    FAK_LIST       { liste [H|T] : stub pour TODO 13               }
  );

  TFactArg = Record
    Kind    : TFactArgKind;
    AtomIdx : Integer;   { FAK_ATOM : index atome                  }
    IntVal  : LongInt;   { FAK_INT : valeur entiere                }
    VarName : TString;   { FAK_VAR : nom de la variable            }
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
  { TODO 06 }
  TermInit;
  { TODO 08 }
  DataInit;
  { TODO 10 }
  ClauseCount := 0;
  { TODO 11 }
  GoalCount    := 0;
  RuleVarCount := 0;
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
    BinOpPrec := 0;
End;

{ ---- BinOpIsRight : operateur droit-associatif ? ------------ }
{ En Prolog ISO :                                                }
{   xfx : non associatif (=, ==, is, \=, ... -> gauche par def) }
{   xfy : associatif a droite (:-, ?-, ;, ->, ',', \+)          }
{   yfx : associatif a gauche (+, -, *, /, //, mod, rem, etc.)  }
Function BinOpIsRight(Const Op : TString) : Boolean;
Begin
  BinOpIsRight :=
    (Op = ':-') Or (Op = '?-') Or (Op = '-->') Or
    (Op = ';')  Or (Op = '->') Or
    (Op = ',')  Or
    (Op = '^');
End;

{ ---- OpSpecifier : retourner le type d operateur Prolog ------ }
{ fx/fy  : prefixe (non/associatif a droite)                    }
{ xfx    : infixe non-associatif                                }
{ xfy    : infixe droit-associatif                               }
{ yfx    : infixe gauche-associatif                              }
{ xf/yf  : postfixe (non utilise dans ISO standard)             }
Function OpSpecifier(Const Op : TString) : TString;
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
    OpSpecifier := 'yfx';
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

  { Predicats builtins ISO (controle) }
  SymAdd('true',      SK_BUILTIN, 0);
  SymAdd('fail',      SK_BUILTIN, 0);
  SymAdd('halt',      SK_BUILTIN, 0);
  SymAdd('halt',      SK_BUILTIN, 1);

  { Predicats builtins ISO (unification) }
  SymAdd('=',         SK_BUILTIN, 2);   { unification   }
  SymAdd('\=',        SK_BUILTIN, 2);   { non-unification }
  SymAdd('==',        SK_BUILTIN, 2);   { egalite stricte }
  SymAdd('\==',       SK_BUILTIN, 2);   { inegalite stricte }
  SymAdd('copy_term', SK_BUILTIN, 2);

  { Predicats builtins ISO (arithmetique) }
  SymAdd('is',        SK_BUILTIN, 2);   { evaluation arithmetique }
  SymAdd('=:=',       SK_BUILTIN, 2);   { egalite arithmetique }
  SymAdd('=\=',       SK_BUILTIN, 2);   { inegalite arithmetique }
  SymAdd('<',         SK_BUILTIN, 2);
  SymAdd('>',         SK_BUILTIN, 2);
  SymAdd('=<',        SK_BUILTIN, 2);
  SymAdd('>=',        SK_BUILTIN, 2);

  { Predicats builtins ISO (comparaison de termes) }
  SymAdd('@<',        SK_BUILTIN, 2);
  SymAdd('@>',        SK_BUILTIN, 2);
  SymAdd('@=<',       SK_BUILTIN, 2);
  SymAdd('@>=',       SK_BUILTIN, 2);
  SymAdd('compare',   SK_BUILTIN, 3);

  { Predicats builtins ISO (type checking) }
  SymAdd('var',       SK_BUILTIN, 1);
  SymAdd('nonvar',    SK_BUILTIN, 1);
  SymAdd('atom',      SK_BUILTIN, 1);
  SymAdd('number',    SK_BUILTIN, 1);
  SymAdd('integer',   SK_BUILTIN, 1);
  SymAdd('float',     SK_BUILTIN, 1);
  SymAdd('compound',  SK_BUILTIN, 1);
  SymAdd('callable',  SK_BUILTIN, 1);
  SymAdd('is_list',   SK_BUILTIN, 1);
  SymAdd('atomic',    SK_BUILTIN, 1);
  SymAdd('ground',    SK_BUILTIN, 1);

  { Predicats builtins ISO (decomposition de termes) }
  SymAdd('functor',   SK_BUILTIN, 3);
  SymAdd('arg',       SK_BUILTIN, 3);
  SymAdd('=..',       SK_BUILTIN, 2);   { univ }

  { Predicats builtins ISO (listes) }
  SymAdd('append',    SK_BUILTIN, 3);
  SymAdd('length',    SK_BUILTIN, 2);
  SymAdd('member',    SK_BUILTIN, 2);
  SymAdd('last',      SK_BUILTIN, 2);
  SymAdd('reverse',   SK_BUILTIN, 2);
  SymAdd('msort',     SK_BUILTIN, 2);
  SymAdd('sort',      SK_BUILTIN, 2);
  SymAdd('nth0',      SK_BUILTIN, 3);
  SymAdd('nth1',      SK_BUILTIN, 3);

  { Predicats builtins ISO (E/S) }
  SymAdd('write',     SK_BUILTIN, 1);
  SymAdd('writeln',   SK_BUILTIN, 1);
  SymAdd('write_canonical', SK_BUILTIN, 1);
  SymAdd('print',     SK_BUILTIN, 1);
  SymAdd('nl',        SK_BUILTIN, 0);
  SymAdd('read',      SK_BUILTIN, 1);
  SymAdd('read_term', SK_BUILTIN, 2);
  SymAdd('get_char',  SK_BUILTIN, 1);
  SymAdd('put_char',  SK_BUILTIN, 1);

  { Predicats builtins ISO (assert/retract) }
  SymAdd('assert',    SK_BUILTIN, 1);
  SymAdd('asserta',   SK_BUILTIN, 1);
  SymAdd('assertz',   SK_BUILTIN, 1);
  SymAdd('retract',   SK_BUILTIN, 1);
  SymAdd('abolish',   SK_BUILTIN, 1);

  { Predicats builtins ISO (controle) }
  SymAdd('call',      SK_BUILTIN, 1);
  SymAdd('not',       SK_BUILTIN, 1);  { negation par echec }
  SymAdd('findall',   SK_BUILTIN, 3);
  SymAdd('bagof',     SK_BUILTIN, 3);
  SymAdd('setof',     SK_BUILTIN, 3);
  SymAdd('between',   SK_BUILTIN, 3);

  { Predicats builtins ISO (atomes et chaines) }
  SymAdd('atom_length',  SK_BUILTIN, 2);
  SymAdd('atom_concat',  SK_BUILTIN, 3);
  SymAdd('atom_chars',   SK_BUILTIN, 2);
  SymAdd('atom_codes',   SK_BUILTIN, 2);
  SymAdd('atom_string',  SK_BUILTIN, 2);
  SymAdd('char_code',    SK_BUILTIN, 2);
  SymAdd('number_codes', SK_BUILTIN, 2);
  SymAdd('number_chars', SK_BUILTIN, 2);
  SymAdd('sub_atom',     SK_BUILTIN, 5);
  SymAdd('upcase_atom',  SK_BUILTIN, 2);
  SymAdd('downcase_atom', SK_BUILTIN, 2);
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
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'AX');
  EmitLabel('_PLRT_UNTR_LP');
  EmitInstrAB('MOV', 'AX', 'WORD PTR [_PL_TTOP]');
  EmitInstrAB('CMP', 'AX', 'CX');
  EmitInstrA('JLE', '_PLRT_UNTR_DONE');
  { Decrementer TTOP }
  EmitInstr('DEC    AX');
  EmitInstrAB('MOV', 'WORD PTR [_PL_TTOP]', 'AX');
  { Lire l adresse enregistree dans le trail }
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstr('SHL    SI,1');                { index -> offset octets }
  EmitInstrAB('MOV', 'DI', 'WORD PTR [_PL_TRAIL + SI]');
  { Remettre la cellule heap comme REF libre (auto-reference) }
  { TAG_REF=0, donc valeur = DI elle-meme }
  EmitInstr('SHL    DI,1');                { index -> offset octets }
  EmitInstrAB('MOV', 'AX', 'WORD PTR [_PL_TRAIL + SI]');
  { AX = adresse originale (index heap) }
  { Stocker AX comme valeur dans heap[AX] = MakeRef(AX) = AX (tag REF=0) }
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstr('SHL    SI,1');
  EmitInstrAB('MOV', 'WORD PTR [_PL_HEAP + SI]', 'AX');
  EmitInstrA('JMP', '_PLRT_UNTR_LP');
  EmitLabel('_PLRT_UNTR_DONE');
  EmitInstrA('POP', 'AX');
  EmitInstrA('POP', 'DI');
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

{ ---- EmitRuntime : emettre les routines runtime --------------- }
{ Emet les routines de backtracking (TODO 12) et sera complete   }
{ par TODO 24 (runtime WAM minimal).                              }
Procedure EmitRuntime;
Begin
  EmitBacktrackRuntime;
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
    { Directive :- ou requete ?- : pas un fait, ignorer pour l instant }
    If (CurToken.Kind = TK_OP) And
       ((CurToken.Val = ':-') Or (CurToken.Val = '?-')) Then
    Begin
      { Sauter la directive jusqu au . }
      While (CurToken.Kind <> TK_EOF) And (CurToken.Kind <> TK_DOT) Do
        ParserAdvance;
      If CurToken.Kind = TK_DOT Then
        ParserAdvance;
      ParseFact := True;
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
{ Un but est soit : atome (arite 0) ou foncteur(arg1,...,argN).     }
{ Les arguments du but sont parses comme ceux d un fait.            }
Procedure ParseGoal(Var G : TGoalRec);
Var
  A : Integer;
Begin
  G.PredName := '';
  G.Arity    := 0;
  G.ArgCount := 0;

  If CurToken.Kind = TK_ATOM Then
  Begin
    G.PredName := CurToken.Val;
    ParserAdvance;

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
          { Derniere clause : trust_me }
          EmitLabel(EntryLabel + '_cp' + IntToStr(I));
          EmitComment('trust_me');
          EmitInstr('CALL    _PLRT_TRUST');
          EmitInstrA('CALL', ClauseTab[Indices[I]].ClsLabel);
          EmitInstrA('JNC', EntryLabel + '_ok');
        End;
      End;

      { Toutes les clauses ont echoue }
      EmitInstr('STC');
      EmitInstr('RET');
      EmitLabel(EntryLabel + '_ok');
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
        { Derniere clause : trust_me }
        EmitLabel(EntryLabel + '_cp' + IntToStr(I));
        EmitComment('trust_me');
        EmitInstr('CALL    _PLRT_TRUST');
        EmitInstrA('CALL', ClauseTab[Indices[I]].ClsLabel);
        { Propager le resultat directement (pas de branche _ok) }
        EmitInstr('RET');
        EmitInstrA('JMP', EntryLabel + '_end');
      End;
    End;

    { Label de succes : depiler le choice point avant de retourner }
    EmitLabel(EntryLabel + '_ok');
    EmitComment('Succes : retirer le choice point');
    EmitInstr('CALL    _PLRT_TRUST');
    EmitInstr('CLC');
    EmitInstr('RET');

    EmitLabel(EntryLabel + '_end');
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
  EmitComment('  Clauses compilees (TODO 10 + 11 + 12)');
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
  STUBS POUR LES TODOS RESTANTS (13..25)
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
