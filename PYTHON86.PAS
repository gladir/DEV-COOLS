{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Python vers assembleur 8086
}

(* ============================================================
  PYTHON86.PAS - Compilateur Python vers assembleur 8086
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .MODEL SMALL, DOS 16 bits

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings)
            ParseArgs : analyser argv (source.py [sortie.asm] [-v] [-d] [-w])
            FatalError, CompileError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .py du fichier source
            Programme principal : validation des arguments et appel Run
            Version, Date, aide en ligne (option -h)
            ShowBanner, ShowUsage, ShowStats
            StrLowerCase, IntToStr_, BaseName, ReplaceExt
            InitOptions, Cleanup, GlobalInit
            Run (stub), programme principal ParseArgs + Run

  TODO 02 - LEXEUR (TOKENS PYTHON) [IMPLEMENTE]
            TTokenKind : TK_EOF, TK_NEWLINE, TK_INDENT, TK_DEDENT,
              TK_INTEGER, TK_FLOAT, TK_STRING, TK_IDENT, TK_KEYWORD,
              TK_OP, TK_PUNCT
            LexInit, LexClose, LexNextToken, LexScanIdent, LexScanNumber
            LexScanString : chaines entre guillemets simples 'abc'
              ou doubles "abc", triples '''...''' ou """..."""
              Sequences d echappement : \n \t \r \\ \' \" \xNN
            LexScanEscChar : decodage des sequences d echappement
            Commentaires : # jusqu a fin de ligne
            Gestion de l indentation : pile d indentation (stack),
              emettre TK_INDENT quand le niveau augmente,
              emettre TK_DEDENT quand le niveau diminue
            Mots-cles : False None True and as assert async await
              break class continue def del elif else except
              finally for from global if import in is lambda
              not or pass raise return try while with yield
            Mode debug -d : affichage de chaque token avec PrintToken
            ParserAdvance : lire token suivant avec PrintToken si -d
            Run : LexInit + boucle de tokens + LexClose

  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
            Entiers decimaux : 0..65535 (positifs) ou -32768..32767 (signes)
            Entiers hexadecimaux : 0xFF, octaux : 0o77, binaires : 0b1010
            Flottants : reconnus par le lexeur, traites comme entiers (trunc)
            Chaines str : 'abc' ou "abc" -> pointeur vers donnees DATA
              Chaines brutes r'...' ou r"..." (pas d echappement)
              Prefixe b'...' (bytes) traite comme chaine normale
            None : constante speciale -> AX=0
            True : constante booleenne -> AX=1
            False : constante booleenne -> AX=0
            Concatenation de chaines : + entre deux str -> appel _PYRT_CONCAT
            Repetition de chaines : * entre str et int -> appel _PYRT_STRMUL
            TExprKind : EK_NONE, EK_IMM, EK_AX, EK_MEM
            TExprVal : Kind, ImmVal, TypeIdx, Offset, SymIdx
            TDataKind : DK_WORD, DK_BYTE, DK_STR, DK_ARRAY_BLK
            TDataRec : LblName, Kind, IntVal, StrVal, ElemCount
            DataAdd, DataAddStr, DataAddWord : gestion du segment DATA
            ExprMakeImm, ExprMakeNone, ExprMakeBool, ExprMakeAX
            LitEvalInt, LitEvalFloat, LitEvalStr, LitEval
            LabelGen : generateur de labels uniques _PYL_N
            EmitOpen, EmitHeader, EmitClose, EmitDataSeg, EmitRaw (stubs)
            Indices de types primitifs :
              TY_IDX_INT=0, TY_IDX_STR=1, TY_IDX_BOOL=2,
              TY_IDX_NONE=3, TY_IDX_LIST=4, TY_IDX_DICT=5,
              TY_IDX_FUNC=6, TY_IDX_CLASS=7

  TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
            Arithmetiques  : + - * // % ** (// = division entiere, ** = puissance)
                             / traite comme // (division entiere sur 8086)
            Comparaison    : == != < <= > >= (chaines et entiers)
            Logiques       : and or not (court-circuit, valeurs truthy/falsy)
            Bit a bit      : & | ^ ~ << >> (AND, OR, XOR, NOT, decalages)
            Appartenance   : in, not in (element dans liste/str)
            Identite       : is, is not (comparaison de references)
            Affectation    : = += -= *= //= %= **= &= |= ^= <<= >>=
            Unaire         : + - ~ not
            Precedence (du plus fort au plus faible) :
              1. ** (puissance)
              2. ~ + - (unaires)
              3. * // % /
              4. + - (binaires)
              5. << >>
              6. &
              7. ^
              8. |
              9. == != < <= > >= in not in is is not
              10. not
              11. and
              12. or
            BinOpPrec, BinOpIsRight, IsAssignOp
            EmitInstr, EmitLabel, EmitComment, EmitBlankLine
            ExprFlushToAX, ExprEmitBinOp (pliage de constantes + 8086)
            ParsePrimary, ParseUnary, ParseExprPrec, ParseExpr

  TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
            TSymKind : SK_VAR, SK_PARAM, SK_FUNC, SK_CLASS, SK_MODULE,
              SK_BUILTIN, SK_GLOBAL, SK_LOCAL
            TSymRec : Name, MangledName, Kind, TypeIdx, Offset,
              ScopeLevel, IsGlobal, IsNonlocal, DeclLine
            SymNameClean, SymMangle, SymAdd, SymFind, SymFindInScope
            SymInit : initialisation de la table des symboles
            CurScope : compteur de portee imbriquee (max MAX_SCOPE)
            ScopeStack / ScopeTop : pile pour SymEnterScope / SymLeaveScope
            Resolution des noms : local -> englobant -> global -> builtins
            Instruction global : marquer une variable comme globale
            Instruction nonlocal : marquer une variable de portee englobante

  TODO 06 - SYSTEME DE TYPES DYNAMIQUE [IMPLEMENTE]
            TTypeKind : TYK_INT (16 bits signe), TYK_BOOL (8 bits),
              TYK_STR (ptr chaine), TYK_NONE (nul),
              TYK_LIST (ptr tableau dynamique), TYK_DICT (ptr table de hachage),
              TYK_TUPLE (ptr tableau fixe), TYK_FUNC (ptr de code),
              TYK_OBJECT (ptr instance de classe), TYK_CLASS (descripteur)
            TTypeRec : Name, Kind, Size
            TypeTab[MAX_TYPE], TypeCount
            TypeInit : enregistrer les 10 types primitifs Python
            TypeKindOf(idx) : retourner le TTypeKind pour un indice
            TypeSizeof(idx) : INT=2, BOOL=2, STR=2(ptr), LIST=2(ptr),
              DICT=2(ptr), TUPLE=2(ptr), FUNC=2(ptr), OBJECT=2(ptr),
              CLASS=2(ptr), NONE=0
            TypeFindByName(name) : rechercher un type par nom -> index
            TypeKindStr(kind) : nom textuel d un TTypeKind
            TypeIdxFromExpr(e) : deduire l indice type d une expression
            Typage dynamique simplifie : le compilateur infere un type
              statique quand c est possible (entier, chaine, None)
            isinstance(obj, cls) : verification de type -> AX=0|1
            type(obj) : retourner le descripteur de type -> AX=idx

  TODO 07 - EMETTEUR DE CODE ASM [IMPLEMENTE]
            TEmitter : OutF (Text), OutFOpen, EmitOpen, EmitClose
            EmitRaw, EmitLabel, EmitInstr (formatage 8 espaces)
            EmitComment, EmitBlankLine
            LabelGen global (compteur unique _PYL_NNNNN)
            Prefixes : _PYV_ (variable), _PYF_ (fonction), _PYK_ (chaine const),
              _PYRT_ (runtime), _PYL_ (label), _PYC_ (classe/vtable),
              _PYM_ (methode)
            EmitHeader : .MODEL SMALL / .STACK 1024 / _TEXT SEGMENT
            EmitProlog(FrameSize) : PUSH BP / MOV BP,SP / SUB SP,N (si N>0)
            EmitEpilog : MOV SP,BP / POP BP / RET
            EmitDataSeg : ecrire _DATA SEGMENT ... _DATA ENDS
            Integration dans Run : point d entree _PYF_Main avec
              init DS, EmitProlog, code utilisateur, EmitEpilog,
              sortie DOS (MOV AX,4C00h / INT 21h)

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES [IMPLEMENTE]
            TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR/DK_LIST/DK_DICT),
              IntVal, StrVal, ElemCount
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr, DataAddList, DataAddDict : variantes d ajout
            Variables globales : entrees DK_WORD dans DATA
            Chaines litterales : DB 'abc',0 dans DATA avec label _PYK_N
            Listes litterales : suite de DW dans DATA pour les elements (DK_LIST)
            Dictionnaires litteraux : paires cle/valeur dans DATA (DK_DICT)
            Heap statique : _PY_HEAP DB 4096 DUP(0) + _PY_HEAPTOP DW 0

  TODO 09 - VARIABLES ET AFFECTATIONS [IMPLEMENTE]
            Variables globales : segment DATA, acces par label _PYV_nom
            Variables locales : pile BP, acces [BP-offset]
            Parametres de fonction : pile BP, acces [BP+offset]
            Affectation simple : x = expr -> ExprLoad + MOV destination, AX
            Affectation augmentee : x += expr -> charger x, evaluer expr,
              ADD AX, resultat, stocker
            Affectation multiple : a, b = expr1, expr2 -> evaluer puis stocker
            Echange : a, b = b, a -> via registre ou pile temporaire
            Unpacking simple : a, b, c = liste -> extraire elements
            ExprLoadToAX : charger variable (globale/locale/param) dans AX
            EmitStoreVar : stocker AX dans variable (globale/locale/param)
            ParseAssign : parser affectation simple, augmentee, multiple
            EnsureVarInData : auto-declarer globale dans segment DATA

  TODO 10 - EXPRESSIONS PRIMAIRES [IMPLEMENTE]
            ParsePrimary : literal entier, literal chaine, ident, appel de func
            Acces attribut : expr.attr -> offset dans instance de classe
            Acces index : expr[i] -> appel selon type (list/str/dict)
            Acces slice : expr[a:b] -> appel _PYRT_SLICE(SI=obj, AX=a, BX=b)
            Appel de fonction : func(args) -> PUSH args + CALL _PYF_func
            Parentheses : (expr) -> regroupement de priorite
            Liste literale : [e0, e1, e2] -> allocation et remplissage
            Tuple literal : (e0, e1, e2) -> allocation et remplissage
            Dict literal : {k0:v0, k1:v1} -> allocation et remplissage
            len(x), abs(x), int(x), str(x), chr(x), ord(x) : builtins

  TODO 11 - EXPRESSIONS BINAIRES
            ParseExprPrec(MinPrec) : boucle de precedence (Pratt)
            Arithmetique entiere : ADD/SUB/IMUL/IDIV pour +, -, *, //
            MOD : IDIV -> resultat dans DX (reste avec %)
            Puissance ** : boucle de multiplication (CALL _PYRT_POW)
            Concatenation str : + -> CALL _PYRT_CONCAT(SI=gauche, DI=droite) -> AX
            Comparaison : CMP + Jcc pour ==, !=, <, <=, >, >=
            Comparaison str : CALL _PYRT_STRCMP -> drapeaux
            Comparaison chainee : a < b < c -> a < b and b < c
            Logique and : court-circuit JZ vers false-branch (valeur truthy)
            Logique or : court-circuit JNZ vers true-branch (valeur truthy)
            Logique not : TEST AX,AX / SETZ AL / MOVZX AX,AL
            Bit a bit : AND/OR/XOR/NOT/SHL/SHR pour &, |, ^, ~, <<, >>
            Operateur in : CALL _PYRT_CONTAINS(SI=collection, AX=elem) -> AX=0|1

  TODO 12 - ENTREES/SORTIES (BUILTINS print / input)
            print(*args, sep=' ', end='\n') :
              Evaluer chaque argument, convertir en chaine si necessaire
              Appeler _PYRT_PRINT(BX=handle, SI=str, CX=len) pour chaque arg
              Inserer le separateur entre les arguments
              Ajouter le terminateur (CR+LF par defaut) -> INT 21h AH=40h
            print(n) avec entier : CALL _PYRT_NUMTOSTR + ecriture
            print(s) avec chaine : ecriture directe via INT 21h
            input([prompt]) :
              Afficher le prompt si present
              Lire une ligne depuis STDIN -> INT 21h AH=0Ah (lecture ligne)
              Retourner un pointeur vers la chaine lue -> AX=ptr
            input() converti en int : int(input()) -> _PYRT_STRTONUM
            open/read/write/close : stubs ou non implemente (avertissement)

  TODO 13 - IF / ELIF / ELSE
            ParseIfStmt : if cond: bloc {elif cond: bloc} [else: bloc]
              Gestion de l indentation pour delimiter les blocs
              Emission TEST AX,AX / JZ pour condition fausse
              Labels : _PYL_ELIF_N, _PYL_ELSE_N, _PYL_ENDIF_N
            Expressions conditionnelles (ternaire) :
              val = a if cond else b
              Emission : evaluer cond, JZ vers else-branch,
                evaluer a, JMP fin, label else, evaluer b, label fin
            Valeurs truthy/falsy : 0, None, '', [] sont falsy,
              tout le reste est truthy -> TEST AX,AX

  TODO 14 - BOUCLES : while / for / break / continue / else
            ParseWhileStmt : while cond: bloc [else: bloc]
              Labels : _PYL_WTEST_N, _PYL_WEND_N, _PYL_WELSE_N
              Le bloc else est execute si la boucle termine normalement
            ParseForStmt : for var in iterable: bloc [else: bloc]
              for i in range(n) : boucle comptee 0..n-1
                Variable locale, CMP + JGE pour le test, INC pour l increment
              for i in range(a, b) : boucle comptee a..b-1
              for i in range(a, b, step) : boucle avec pas
              for ch in string : iterer sur les caracteres d une chaine
              for elem in list : iterer sur les elements d une liste
              Labels : _PYL_FTEST_N, _PYL_FINCR_N, _PYL_FEND_N, _PYL_FELSE_N
            break : saut vers fin de la boucle englobante
              -> JMP _PYL_WEND_N ou _PYL_FEND_N (marque else comme ignore)
            continue : saut vers le test/increment de la boucle englobante
              -> JMP _PYL_WTEST_N ou _PYL_FINCR_N
            LoopPush / LoopPop : pile de labels pour break/continue

  TODO 15 - LISTES (list)
            Liste vide : [] -> allocation d un tableau vide sur le heap
            Liste literale : [e0, e1, e2] -> allocation + stockage DW par element
            Acces par index : lst[i] -> calcul offset + MOV AX,[BX+offset]
              Index negatif : lst[-1] -> len + index, acces au dernier element
            Affectation par index : lst[i] = val -> MOV [BX+offset], AX
            Slice : lst[a:b] -> CALL _PYRT_SLICE -> nouveau ptr liste
            len(lst) : nombre d elements -> AX (stocke en tete de la liste)
            lst.append(val) : CALL _PYRT_LISTAPPEND(SI=lst, AX=val)
            lst.pop() : CALL _PYRT_LISTPOP(SI=lst) -> AX=element
            lst.insert(i, val) : CALL _PYRT_LISTINSERT
            Concatenation : lst1 + lst2 -> CALL _PYRT_LISTCONCAT -> AX=ptr
            Repetition : lst * n -> CALL _PYRT_LISTMUL -> AX=ptr
            Operateur in : val in lst -> CALL _PYRT_LISTCONTAINS -> AX=0|1

  TODO 16 - DICTIONNAIRES (dict)
            Dict vide : {} -> allocation d une table de hachage vide
            Dict literal : {k0:v0, k1:v1} -> allocation + insertion des paires
            Acces par cle : d[key] -> CALL _PYRT_DICTGET(SI=dict, AX=key) -> AX=val
              KeyError si la cle n existe pas -> _PYRT_PANIC
            Affectation par cle : d[key] = val -> CALL _PYRT_DICTSET
            d.get(key, default) : CALL _PYRT_DICTGETDEF -> AX=val ou default
            key in d : CALL _PYRT_DICTCONTAINS(SI=dict, AX=key) -> AX=0|1
            len(d) : nombre de paires -> AX
            d.keys() : retourner une liste des cles
            d.values() : retourner une liste des valeurs
            del d[key] : CALL _PYRT_DICTDEL(SI=dict, AX=key)
            Boucle for k in d : iterer sur les cles du dictionnaire
            Table de hachage interne : MAX_HASH_PAIRS paires par dict

  TODO 17 - FONCTIONS (def) ET RETURN
            ParseDefStmt : def nom(params): bloc
            Parametres positionnels : passage par valeur sur la pile
            Parametres par defaut : def f(a, b=10): -> valeur par defaut
              si argument manquant a l appel, empiler la valeur par defaut
            Convention d appel : cdecl 16 bits, arguments empiles droite a gauche
            Prologue : PUSH BP / MOV BP,SP / SUB SP, locals_size
            Epilogue : MOV SP,BP / POP BP / RET
            return expr : MOV AX, valeur + JMP vers epilogue
            return sans valeur : AX=0 (None) + JMP vers epilogue
            Appel de fonction : PUSH args + CALL _PYF_nom + ADD SP, args_size
            Fonctions imbriquees : non supportees (avertissement)
            Recursion : supportee naturellement via la pile

  TODO 18 - CLASSES (class) ET OBJETS
            ParseClassStmt : class Nom: bloc ou class Nom(Parent): bloc
            Attributs d instance : stockes dans un bloc memoire alloue sur heap
              Acces : self.attr -> MOV BX,[BP+4] / MOV AX,[BX+offset]
            Methodes : def methode(self, ...): bloc
              self est le premier parametre (pointeur vers l instance)
            Constructeur __init__(self, ...): initialisation des attributs
            Allocation : Nom(args) -> CALL _PYRT_OBJNEW(CX=taille) + CALL __init__
            Table de methodes (vtable) :
              Chaque classe a une vtable dans DATA
              Entrees : DW offset de chaque methode
            Heritage simple : class Enfant(Parent):
              Copie de la vtable du parent + surcharges
              Acces aux attributs du parent par offset
            Appel de methode : obj.method(args)
              MOV BX,[AX] (ptr vtable) / CALL [BX+offset_methode]
              PUSH self comme premier argument avant l appel
            isinstance(obj, cls) : comparaison du typecode -> AX=0|1

  TODO 19 - TUPLES ET UNPACKING
            Tuple vide : () -> pointeur vers zone vide
            Tuple literal : (e0, e1, e2) -> allocation + stockage DW par element
            Tuple singleton : (e0,) -> la virgule finale distingue du parenthesage
            Acces par index : tup[i] -> calcul offset + MOV AX,[BX+offset]
              Index negatif : tup[-1] -> len + index
            Tuples immuables : pas d affectation par index (erreur compilation)
            len(tup) : nombre d elements -> AX
            Unpacking : a, b, c = tup -> extraire chaque element vers variable
            Unpacking dans for : for a, b in list_of_tuples: -> extraire paires
            Concatenation : tup1 + tup2 -> CALL _PYRT_TUPLECONCAT -> AX=ptr
            Operateur in : val in tup -> CALL _PYRT_TUPLECONTAINS -> AX=0|1

  TODO 20 - CHAINES (str) OPERATIONS AVANCEES
            Concatenation : s1 + s2 -> CALL _PYRT_CONCAT -> AX=ptr
            Repetition : s * n -> CALL _PYRT_STRMUL -> AX=ptr
            Acces par index : s[i] -> MOV AL,[SI+i] / MOVZX AX,AL
            Slice : s[a:b] -> CALL _PYRT_STRSLICE -> AX=ptr nouvelle chaine
            len(s) : CALL _PYRT_STRLEN(SI=str) -> AX
            s.find(sub) : CALL _PYRT_STRFIND -> AX=index ou -1
            s.upper() / s.lower() : CALL _PYRT_STRUPPER / _PYRT_STRLOWER
            s.strip() : CALL _PYRT_STRSTRIP -> AX=ptr
            s.split(sep) : CALL _PYRT_STRSPLIT -> AX=ptr liste
            s.replace(old, new) : CALL _PYRT_STRREPLACE -> AX=ptr
            s.startswith(prefix) / s.endswith(suffix) -> AX=0|1
            chr(n) : entier -> caractere (1 octet dans buffer) -> AX=ptr
            ord(c) : caractere -> entier -> AX
            Operateur in : sub in s -> CALL _PYRT_STRCONTAINS -> AX=0|1

  TODO 21 - GESTION DES EXCEPTIONS (try / except / finally / raise)
            ParseTryStmt : try: bloc except [Type [as var]]: bloc [finally: bloc]
              try: bloc -> sauvegarder handler courant, installer nouveau
              except ExceptionType: bloc -> label _PYL_EXCEPT_N, CMP code exception
              except ExceptionType as e: bloc -> stocker le message dans variable e
              except: bloc -> handler generique (attrape tout)
              finally: bloc -> toujours execute (label _PYL_FINALLY_N)
            raise ExceptionType(msg) : lever une exception
              AX = code exception, BX = ptr message
            raise sans argument : relever l exception courante
            Mecanisme sans support OS :
              _PYX_HANDLER DW 0 dans DATA (ptr vers handler courant)
              TRY : sauvegarder ancien handler, installer nouveau
              EXCEPT : tester le code d exception, router vers le bon handler
              FINALLY : execute dans tous les cas, puis restaurer handler
            RAISE sans handler : affiche 'Unhandled exception' + Halt

  TODO 22 - COMPREHENSIONS ET GENERATEURS (SIMPLIFIE)
            List comprehension : [expr for var in iterable]
              -> allocation liste, boucle for, evaluer expr, append
            List comprehension avec filtre : [expr for var in iterable if cond]
              -> ajout d un test conditionnel dans la boucle
            Dict comprehension : {kexpr:vexpr for var in iterable}
              -> allocation dict, boucle for, evaluer paire, dictset
            Generateurs : non supportes (avertissement a la compilation)
            Set comprehension : non supporte (avertissement)
            Expressions generatrices : non supportees (avertissement)

  TODO 23 - MODULES ET IMPORT (SIMPLIFIE)
            import module : importer un module Python externe
              Mecanisme simplifie : un seul fichier source compile a la fois
              Les modules importes sont declares comme externes (EXTRN en ASM)
            from module import nom : importation selective
              Ajouter le symbole dans la table avec IsImported=True
            Module math : abs, pow, min, max -> builtins ou runtime
            Module sys : sys.exit(code) -> MOV AX,4C00h+code / INT 21h
              sys.argv : non supporte (avertissement)
            Module os : non supporte (avertissement)
            Gestion des chemins d import : non supportee (un seul repertoire)
            Tables d importation/exportation : symboles EXTRN et PUBLIC

  TODO 24 - RUNTIME MINIMAL
            _PYRT_PRINT(BX=handle, SI=msg, CX=len) : INT 21h AH=40h
            _PYRT_PRINTLN : _PYRT_PRINT + CR+LF via _PY_CRLF DB 13,10,0
            _PYRT_STRLEN(SI=str) : compte octets jusqu a 0 -> AX
            _PYRT_NUMTOSTR(AX=n, DI=buf) : entier signe -> ASCII (itoa)
            _PYRT_STRTONUM(SI=str) : ASCII -> entier -> AX (atoi)
            _PYRT_CONCAT(SI=src1, DI=src2) : concatenation str -> AX=ptr buf
            _PYRT_STRCMP(SI=str1, DI=str2) : comparaison -> drapeaux ZF/CF
            _PYRT_STRSLICE(SI=str, AX=start, BX=end) : sous-chaine -> AX=ptr
            _PYRT_STRMUL(SI=str, CX=n) : repetition chaine -> AX=ptr
            _PYRT_POW(AX=base, CX=exp) : puissance entiere -> AX
            _PYRT_OBJNEW(CX=nb_octets) : allocation objet sur heap -> AX=ptr
            _PYRT_LISTAPPEND(SI=lst, AX=val) : ajouter element a la liste
            _PYRT_LISTPOP(SI=lst) : retirer dernier element -> AX
            _PYRT_DICTGET(SI=dict, AX=key) : obtenir valeur -> AX
            _PYRT_DICTSET(SI=dict, AX=key, BX=val) : definir paire
            _PYRT_CONTAINS(SI=collection, AX=elem) : test appartenance -> AX=0|1
            _PYRT_PANIC(SI=msg) : affiche message + MOV AX,4C01h + INT 21h
            RuntimeEmitted : flag pour n emettre le runtime qu une seule fois
            Heap statique : _PY_HEAP DB 4096 DUP(0) + _PY_HEAPTOP DW 0

  TODO 25 - GENERATION FINALE ET FICHIERS EXEMPLES
            EmitClose : END _PYF___main__ dans _TEXT ENDS / DATA ENDS
            Run : pipeline complet LexInit -> ParseModule ->
              EmitRuntime -> _TEXT ENDS / EmitDataSeg / END _PYF___main__
            Fichiers SAMPLES\PYTHON\ a creer :
              hello.py    (print, variables, chaines, entiers)
              math.py     (operateurs, fonctions, recursion, return)
              control.py  (if/elif/else, while, for, break, continue)
              lists.py    (listes, append, pop, index, slice, in)
              dicts.py    (dictionnaires, acces, keys, values, del)
              strings.py  (operations sur chaines, find, upper, split)
              classes.py  (class, __init__, methodes, heritage)
              except.py   (try/except/finally, raise)
            Smoke tests : PYTHON86.EXE -v SAMPLES\PYTHON\*.py

  ============================================================ *)

Program PYTHON86;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES GLOBALES
  ============================================================ }
Const
  PYTHON86_VERSION = '1.0';
  PYTHON86_DATE    = '2026-03-06';

  { Limites des tableaux internes }
  MAX_SYM        = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_LABEL      = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_SCOPE      = {$IFDEF FPC}64{$ELSE}32{$ENDIF};
  MAX_DATA       = {$IFDEF FPC}512{$ELSE}128{$ENDIF};
  MAX_TYPE       = {$IFDEF FPC}32{$ELSE}16{$ENDIF};
  MAX_PARAM      = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_LOOP_NEST  = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_ERRORS     = {$IFDEF FPC}30{$ELSE}3{$ENDIF};
  MAX_STR        = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  STACK_SIZE     = 1024;
  MAX_INDENT     = 64;     { profondeur max de l indentation        }
  MAX_DEDENT_Q   = 32;     { nombre max de DEDENT en attente        }

  { Prefixes de nommage ASM }
  PY_VAR_PFX  = '_PYV_';    { variable globale/locale              }
  PY_FN_PFX   = '_PYF_';    { fonction def                         }
  PY_STR_PFX  = '_PYK_';    { constante chaine litterale           }
  PY_RT_PFX   = '_PYRT_';   { routine runtime                      }
  PY_LBL_PFX  = '_PYL_';    { label de saut interne                }
  PY_CLS_PFX  = '_PYC_';    { classe / vtable                      }
  PY_MTH_PFX  = '_PYM_';    { methode                              }

  { Codes de sortie }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Indices de types primitifs Python (TODO 03) }
  TY_IDX_INT   = 0;   { entier 16 bits signe       }
  TY_IDX_STR   = 1;   { pointeur chaine DATA       }
  TY_IDX_BOOL  = 2;   { 0 ou 1 dans AX             }
  TY_IDX_NONE  = 3;   { None : AX=0                }
  TY_IDX_LIST  = 4;   { pointeur bloc DATA          }
  TY_IDX_DICT  = 5;   { pointeur bloc DATA          }
  TY_IDX_FUNC  = 6;   { pointeur de code            }
  TY_IDX_CLASS = 7;   { pointeur vtable             }
  TY_PRIM_COUNT = 8;
  TY_UNKNOWN   = -1;

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String[MAX_STR];

  { ---- Options de compilation ----------------------------- }
  TOptions = Record
    SrcFile   : TString;   { fichier source Python (.py)           }
    OutFile   : TString;   { fichier assembleur de sortie (.asm)   }
    Verbose   : Boolean;   { -v : banniere et statistiques         }
    DebugMode : Boolean;   { -d : affichage de chaque token        }
    Warnings  : Boolean;   { -w : activer les avertissements       }
  End;

  { ---- Tokens Python (TODO 02) ---------------------------- }
  TTokenKind = (
    TK_EOF,       { fin de fichier                          }
    TK_NEWLINE,   { fin de ligne logique                    }
    TK_INDENT,    { augmentation d indentation              }
    TK_DEDENT,    { diminution d indentation                }
    TK_INTEGER,   { literal entier 42 0xFF 0o17 0b101       }
    TK_FLOAT,     { literal flottant 3.14 1.5e3             }
    TK_STRING,    { literal chaine 'abc' ou "abc"           }
    TK_IDENT,     { identificateur (non-mot-cle)            }
    TK_KEYWORD,   { mot-cle Python reconnu                  }
    TK_OP,        { operateur + - * / == != etc.            }
    TK_PUNCT      { ponctuation , ( ) : . etc.              }
  );

  TToken = Record
    Kind     : TTokenKind;
    Val      : TString;     { valeur textuelle brute          }
    IntVal   : LongInt;     { valeur entiere (TK_INTEGER)     }
    FloatVal : Real;        { valeur flottante (TK_FLOAT)     }
    Line     : Integer;     { ligne source (1-base)           }
    Col      : Integer;     { colonne source (1-base)         }
  End;

  { ---- Valeurs d expression (TODO 03) ---------------------- }
  TExprKind = (
    EK_NONE,   { void / pas de valeur                      }
    EK_IMM,    { valeur immediate dans ImmVal               }
    EK_AX,     { valeur dans le registre AX                 }
    EK_MEM     { adresse memoire [BP+Offset] ou [_PYV_x]   }
  );

  TExprVal = Record
    Kind    : TExprKind;
    ImmVal  : LongInt;
    TypeIdx : Integer;   { indice type primitif            }
    Offset  : Integer;   { offset donnee/pile              }
    SymIdx  : Integer;   { indice SymTab (-1 = pas lvalue) }
  End;

  { ---- Segment de donnees (TODO 03) ------------------------ }
  TDataKind = (DK_WORD, DK_BYTE, DK_STR, DK_ARRAY_BLK, DK_LIST, DK_DICT);

  TDataRec = Record
    LblName   : TString;
    Kind      : TDataKind;
    IntVal    : LongInt;
    StrVal    : TString;
    ElemCount : Integer;
  End;

  { ---- Table des symboles (TODO 05) ------------------------- }
  TSymKind = (
    SK_VAR,       { variable (globale ou locale)               }
    SK_PARAM,     { parametre de fonction                      }
    SK_FUNC,      { fonction def                               }
    SK_CLASS,     { classe class                               }
    SK_MODULE,    { module importe                             }
    SK_BUILTIN,   { builtin (print, len, int, str ...)         }
    SK_GLOBAL,    { marqueur global (instruction global x)     }
    SK_LOCAL      { variable locale explicite                  }
  );

  TSymRec = Record
    Name        : TString;     { nom Python original              }
    MangledName : TString;     { label ASM (_PYV_x, _PYF_f ...)  }
    Kind        : TSymKind;
    TypeIdx     : Integer;     { indice type primitif (-1=unknown)}
    Offset      : Integer;     { offset pile BP- (locaux/params)  }
    ScopeLevel  : Integer;     { niveau de portee (0=global)      }
    IsGlobal    : Boolean;     { instruction global -> True       }
    IsNonlocal  : Boolean;     { instruction nonlocal -> True     }
    DeclLine    : Integer;     { ligne de declaration (debug)     }
  End;

  { ---- Systeme de types dynamique (TODO 06) ------------------ }
  TTypeKind = (
    TYK_INT,       { entier 16 bits signe                     }
    TYK_BOOL,      { booleen (0 ou 1)                         }
    TYK_STR,       { pointeur chaine terminee par 0           }
    TYK_NONE,      { None : valeur nulle                      }
    TYK_LIST,      { pointeur tableau dynamique               }
    TYK_DICT,      { pointeur table de hachage                }
    TYK_TUPLE,     { pointeur tableau fixe (immutable)        }
    TYK_FUNC,      { pointeur de code (fonction)              }
    TYK_OBJECT,    { pointeur instance de classe              }
    TYK_CLASS,     { descripteur de classe                    }
    TYK_UNKNOWN    { type indetermine                         }
  );

  TTypeRec = Record
    Name : TString;    { nom Python du type (int, str, ...) }
    Kind : TTypeKind;  { categorie de type                  }
    Size : Integer;    { taille en octets (2=mot, 0=void)   }
  End;

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
Var
  { Options de compilation }
  Opts       : TOptions;

  { Compteurs generaux }
  ErrorCount : Integer;
  WarnCount  : Integer;
  TotalLines : LongInt;
  TotalSyms  : Integer;

  { Lexeur (TODO 02) }
  LexSrcF    : Text;
  LexLine    : String;
  LexLineNo  : Integer;
  LexColNo   : Integer;
  LexEOF     : Boolean;
  LexOpened  : Boolean;
  CurToken   : TToken;

  { Pile d indentation }
  IndentStack : Array[0..MAX_INDENT - 1] Of Integer;
  IndentTop   : Integer;   { indice du sommet (0 = base = colonne 0) }
  DedentQueue : Integer;   { nombre de DEDENT en attente              }
  AtLineStart : Boolean;   { True = debut de ligne logique (indent)   }
  ParenDepth  : Integer;   { >0 = dans paren/crochet -> pas NEWLINE }

  { Segment de donnees (TODO 03) }
  DataTab     : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount   : Integer;
  LabelGenSeq : Integer;   { compteur pour labels uniques _PYL_N }
  GExprDummy  : TExprVal;  { valeur fictive pour ignorer un retour }

  { Fichier de sortie (TODO 03) }
  OutF        : Text;
  OutFOpen    : Boolean;

  { Table des symboles (TODO 05) }
  SymTab      : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount    : Integer;
  ScopeStack  : Array[0..MAX_SCOPE - 1] Of Integer;
  ScopeTop    : Integer;    { sommet de la pile des portees }
  CurScope    : Integer;    { niveau de portee courant (0 = global) }

  { Systeme de types (TODO 06) }
  TypeTab     : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount   : Integer;

{ ============================================================
  FORWARD DECLARATIONS
  ============================================================ }
Procedure LexInit;             Forward;
Procedure LexClose;            Forward;
Function  IsKeyword(Const S : TString) : Boolean; Forward;
Procedure PrintToken(Const T : TToken); Forward;
Procedure LexNextLine;         Forward;
Function  IsIdentStart(Ch : Char) : Boolean; Forward;
Function  IsIdentCont(Ch : Char) : Boolean; Forward;
Function  IsHexDigit(Ch : Char) : Boolean; Forward;
Function  HexVal(Ch : Char) : Integer; Forward;
Procedure LexScanIdent;        Forward;
Procedure LexScanNumber;       Forward;
Function  LexScanEscChar : Char; Forward;
Procedure LexScanString(Quote : Char; Triple : Boolean); Forward;
Procedure LexNextToken;        Forward;
Procedure ParserAdvance;       Forward;
{ TODO 03 - Forward declarations litteraux et constantes }
Function  LabelGen : TString;  Forward;
Procedure EmitRaw(Const S : String); Forward;
Function  DataAdd(Const Lbl : TString; Kind : TDataKind;
                  AIntVal : LongInt; Const AStrVal : TString) : Integer; Forward;
Function  DataAddStr(Const S : TString) : TString; Forward;
Function  DataAddWord(Const Lbl : TString;
                      AIntVal : LongInt) : Integer; Forward;
{ TODO 08 - Forward declarations segment de donnees }
Function  DataAddList(Const Lbl : TString;
                      AElemCount : Integer) : Integer; Forward;
Function  DataAddDict(Const Lbl : TString;
                      APairCount : Integer) : Integer; Forward;
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal); Forward;
Procedure ExprMakeNone(Var Res : TExprVal); Forward;
Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal); Forward;
Procedure ExprMakeAX(ATypeIdx : Integer; Var Res : TExprVal); Forward;
Procedure LitEvalInt(Const T : TToken; Var Res : TExprVal); Forward;
Procedure LitEvalFloat(Const T : TToken; Var Res : TExprVal); Forward;
Procedure LitEvalStr(Const T : TToken; Var Res : TExprVal); Forward;
Procedure LitEval(Const T : TToken; Var Res : TExprVal); Forward;
Procedure EmitOpen;            Forward;
Procedure EmitHeader;          Forward;
Procedure EmitDataSeg;         Forward;
Procedure EmitClose;           Forward;
{ TODO 07 - Forward declarations emetteur de code ASM }
Procedure EmitProlog(FrameSize : Integer);  Forward;
Procedure EmitEpilog;                       Forward;
{ TODO 04 - Forward declarations operateurs et precedence }
Procedure EmitInstr(Const S : TString);      Forward;
Procedure EmitLabel(Const Lbl : TString);    Forward;
Procedure EmitComment(Const Msg : TString);  Forward;
Procedure EmitBlankLine;                     Forward;
Function  BinOpPrec(Const Op : TString) : Integer; Forward;
Function  BinOpIsRight(Const Op : TString) : Boolean; Forward;
Function  IsAssignOp(Const Op : TString) : Boolean; Forward;
Procedure ExprFlushToAX(Var E : TExprVal);   Forward;
Procedure ExprEmitBinOp(Const Op : TString;
            Var L : TExprVal; Var R : TExprVal); Forward;
Procedure ParsePrimary(Var Res : TExprVal);  Forward;
Procedure ParseUnary(Var Res : TExprVal);    Forward;
Procedure ParseExprPrec(MinPrec : Integer;
            Var Res : TExprVal);             Forward;
Procedure ParseExpr(Var Res : TExprVal);     Forward;
{ TODO 05 - Forward declarations table des symboles }
Function  SymNameClean(Const Name : TString) : TString; Forward;
Function  SymMangle(Const Name : TString; Kind : TSymKind) : TString; Forward;
Function  SymFind(Const Name : TString) : Integer; Forward;
Function  SymFindInScope(Const Name : TString;
            Level : Integer) : Integer; Forward;
Function  SymAdd(Const Name : TString; Kind : TSymKind;
            TypeIdx, Offset : Integer) : Integer; Forward;
Procedure SymEnterScope;     Forward;
Procedure SymLeaveScope;     Forward;
Procedure SymInit;           Forward;
{ TODO 06 - Forward declarations systeme de types }
Procedure TypeInit;          Forward;
Function  TypeKindOf(TypeIdx : Integer) : TTypeKind; Forward;
Function  TypeSizeof(TypeIdx : Integer) : Integer; Forward;
Function  TypeFindByName(Const Name : TString) : Integer; Forward;
Function  TypeKindStr(K : TTypeKind) : TString; Forward;
Function  TypeIdxFromExpr(Const E : TExprVal) : Integer; Forward;
{ TODO 09 - Forward declarations variables et affectations }
Procedure ExprLoadToAX(SIdx : Integer);    Forward;
Procedure EmitStoreVar(SIdx : Integer);    Forward;
Procedure EnsureVarInData(SIdx : Integer); Forward;
Procedure ParseAssign(FirstSymIdx : Integer); Forward;
{ TODO 10 - Forward declarations expressions primaires }
Procedure ParseCallArgs(SIdx : Integer; Var Res : TExprVal); Forward;
Procedure EmitBuiltinCall(SIdx : Integer; Var Res : TExprVal); Forward;
Procedure ParseListLiteral(Var Res : TExprVal);  Forward;
Procedure ParseDictLiteral(Var Res : TExprVal);  Forward;

{ ============================================================
  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
  ============================================================ }

{ ---- Messages d erreur et d avertissement ---------------- }

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('PYTHON86: FATAL: ', Msg);
  Halt(EXIT_ERROR);
End;

Procedure CompileError(Const Msg : TString; Line : Integer);
Begin
  Write('PYTHON86:');
  If Line > 0 Then
    Write(Opts.SrcFile, ':', Line, ': ');
  WriteLn('error: ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('trop d''erreurs, compilation arretee');
End;

Procedure WarnMsg(Const Msg : TString; Line : Integer);
Begin
  If Not Opts.Warnings Then Exit;
  Write('PYTHON86:');
  If Line > 0 Then
    Write(Opts.SrcFile, ':', Line, ': ');
  WriteLn('warning: ', Msg);
  Inc(WarnCount);
End;

{ ---- Banniere ---------------------------------------------- }

Procedure ShowBanner;
Begin
  WriteLn('PYTHON86 v', PYTHON86_VERSION, ' (', PYTHON86_DATE, ')');
  WriteLn('Compilateur Python -> assembleur 8086 (MASM .MODEL SMALL)');
  WriteLn('Turbo Pascal / Free Pascal (-Mtp)');
  WriteLn;
End;

Procedure ShowUsage;
Begin
  WriteLn('Usage: PYTHON86 <source.py> [sortie.asm] [-v] [-d] [-w]');
  WriteLn;
  WriteLn('  source.py  : fichier Python source');
  WriteLn('  sortie.asm : fichier assembleur de sortie (defaut: source.asm)');
  WriteLn('  -v         : mode verbeux (banniere + statistiques)');
  WriteLn('  -d         : debug tokens (affiche chaque token)');
  WriteLn('  -w         : activer les avertissements');
  WriteLn('  -h, --help : cette aide');
  WriteLn;
  Halt(EXIT_USAGE);
End;

Procedure ShowStats;
Begin
  WriteLn('Compilation terminee : ', Opts.SrcFile, ' -> ', Opts.OutFile);
  WriteLn('  Lignes         : ', TotalLines);
  WriteLn('  Symboles       : ', TotalSyms);
  WriteLn('  Erreurs        : ', ErrorCount);
  WriteLn('  Avertissements : ', WarnCount);
End;

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

Function IntToStr_(N : LongInt) : TString;
Var
  S : TString;
Begin
  Str(N, S);
  IntToStr_ := S;
End;

{ Extrait le nom de base d un chemin (sans repertoire ni extension) }
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

{ Remplace l extension d un chemin }
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
      WriteLn('PYTHON86: option inconnue: ', Arg);
      ShowUsage;
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else If Opts.OutFile = '' Then
      Opts.OutFile := Arg
    Else
    Begin
      WriteLn('PYTHON86: argument inattendu: ', Arg);
      ShowUsage;
    End;
  End;

  If Opts.SrcFile = '' Then
  Begin
    WriteLn('PYTHON86: fichier source manquant');
    ShowUsage;
  End;

  If Opts.OutFile = '' Then
    Opts.OutFile := ReplaceExt(Opts.SrcFile, '.asm');
End;

{ ---- Nettoyage des ressources ------------------------------ }

Procedure Cleanup;
Begin
  If LexOpened Then LexClose;
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ---- Initialisation generale des variables globales -------- }

Procedure GlobalInit;
Begin
  ErrorCount  := 0;
  WarnCount   := 0;
  TotalLines  := 0;
  TotalSyms   := 0;
  LexOpened   := False;
  LexEOF      := False;
  LexLineNo   := 0;
  LexColNo    := 1;
  LexLine     := '';
  IndentTop   := 0;
  IndentStack[0] := 0;
  DedentQueue := 0;
  AtLineStart := True;
  ParenDepth  := 0;
  CurToken.Kind    := TK_EOF;
  CurToken.Val     := '';
  CurToken.IntVal  := 0;
  CurToken.FloatVal := 0.0;
  CurToken.Line    := 0;
  CurToken.Col     := 0;
  { TODO 03 : segment de donnees et sortie }
  DataCount   := 0;
  LabelGenSeq := 0;
  OutFOpen    := False;
  GExprDummy.Kind    := EK_NONE;
  GExprDummy.ImmVal  := 0;
  GExprDummy.TypeIdx := TY_UNKNOWN;
  GExprDummy.Offset  := 0;
  GExprDummy.SymIdx  := -1;
  { TODO 05 : table des symboles }
  SymCount  := 0;
  ScopeTop  := 0;
  CurScope  := 0;
End;

{ ============================================================
  TODO 02 - LEXEUR (TOKENS PYTHON) [IMPLEMENTE]
  ============================================================ }

{ ---- IsKeyword : teste si S est un mot-cle Python ---------- }
Function IsKeyword(Const S : TString) : Boolean;
Begin
  IsKeyword :=
    (S = 'False')    Or (S = 'None')     Or (S = 'True')      Or
    (S = 'and')      Or (S = 'as')       Or (S = 'assert')    Or
    (S = 'async')    Or (S = 'await')    Or (S = 'break')     Or
    (S = 'class')    Or (S = 'continue') Or (S = 'def')       Or
    (S = 'del')      Or (S = 'elif')     Or (S = 'else')      Or
    (S = 'except')   Or (S = 'finally')  Or (S = 'for')       Or
    (S = 'from')     Or (S = 'global')   Or (S = 'if')        Or
    (S = 'import')   Or (S = 'in')       Or (S = 'is')        Or
    (S = 'lambda')   Or (S = 'nonlocal') Or (S = 'not')       Or
    (S = 'or')       Or (S = 'pass')     Or (S = 'raise')     Or
    (S = 'return')   Or (S = 'try')      Or (S = 'while')     Or
    (S = 'with')     Or (S = 'yield');
End;

{ ---- PrintToken : affichage debug d un token --------------- }
Procedure PrintToken(Const T : TToken);
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', T.Line, ',', T.Col, '] ');
  Case T.Kind Of
    TK_EOF     : Write('EOF');
    TK_NEWLINE : Write('NEWLINE');
    TK_INDENT  : Write('INDENT');
    TK_DEDENT  : Write('DEDENT');
    TK_INTEGER : Write('INT(', T.IntVal, ')');
    TK_FLOAT   : Write('FLOAT(', T.Val, ')');
    TK_STRING  : Write('STR(''', T.Val, ''')');
    TK_IDENT   : Write('IDENT(', T.Val, ')');
    TK_KEYWORD : Write('KW(', T.Val, ')');
    TK_OP      : Write('OP(', T.Val, ')');
    TK_PUNCT   : Write('PUNCT(', T.Val, ')');
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

{ ---- Test de caracteres ------------------------------------- }

Function IsIdentStart(Ch : Char) : Boolean;
Begin
  IsIdentStart := ((Ch >= 'A') And (Ch <= 'Z')) Or
                  ((Ch >= 'a') And (Ch <= 'z')) Or
                  (Ch = '_');
End;

Function IsIdentCont(Ch : Char) : Boolean;
Begin
  IsIdentCont := IsIdentStart(Ch) Or ((Ch >= '0') And (Ch <= '9'));
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

{ ---- LexScanIdent : scanner un identificateur ou mot-cle --- }
Procedure LexScanIdent;
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
  If IsKeyword(S) Then
    CurToken.Kind := TK_KEYWORD
  Else
    CurToken.Kind := TK_IDENT;
End;

{ ---- LexScanNumber : scanner un litteral numerique ---------- }
{ Entiers decimaux, hex (0x), octaux (0o), binaires (0b),       }
{ flottants (3.14, 1.5e3), underscores dans les nombres (1_000) }
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

  { Detecter prefixe 0x 0o 0b }
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
    End;
  End;

  { Scanner la partie entiere }
  While LexColNo <= Length(LexLine) Do
  Begin
    Ch := LexLine[LexColNo];
    If Ch = '_' Then
    Begin
      Inc(LexColNo);
    End
    Else If (Base = 16) And IsHexDigit(Ch) Then
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
    Inc(LexColNo);
    FracDiv := 10.0;
    FracVal := 0.0;
    While (LexColNo <= Length(LexLine)) And
          (((LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9')) Or
           (LexLine[LexColNo] = '_')) Do
    Begin
      If LexLine[LexColNo] <> '_' Then
      Begin
        FracVal := FracVal + (Ord(LexLine[LexColNo]) - Ord('0')) / FracDiv;
        FracDiv := FracDiv * 10.0;
      End;
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
          (((LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9')) Or
           (LexLine[LexColNo] = '_')) Do
    Begin
      If LexLine[LexColNo] <> '_' Then
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
    CurToken.FloatVal := FltVal;
    If FltVal > 32767.0 Then N := 32767
    Else If FltVal < -32768.0 Then N := -32768
    Else N := Trunc(FltVal);
    CurToken.Kind := TK_FLOAT;
  End
  Else
    CurToken.Kind := TK_INTEGER;

  CurToken.IntVal := N;
  Str(N, CurToken.Val);
End;

{ ---- LexScanEscChar : decoder une sequence d echappement --- }
Function LexScanEscChar : Char;
Var
  Ch : Char;
  V  : Integer;
Begin
  If LexColNo > Length(LexLine) Then
  Begin
    LexScanEscChar := '\';
    Exit;
  End;
  Ch := LexLine[LexColNo];
  Inc(LexColNo);
  Case Ch Of
    'n'        : LexScanEscChar := #10;
    't'        : LexScanEscChar := #9;
    'r'        : LexScanEscChar := #13;
    '0'        : LexScanEscChar := #0;
    'a'        : LexScanEscChar := #7;
    'b'        : LexScanEscChar := #8;
    'f'        : LexScanEscChar := #12;
    'v'        : LexScanEscChar := #11;
    '\'        : LexScanEscChar := '\';
    ''''       : LexScanEscChar := '''';
    '"'        : LexScanEscChar := '"';
    'x', 'X'  :
    Begin
      V := 0;
      If (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Then
      Begin
        V := HexVal(LexLine[LexColNo]);
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Then
        Begin
          V := V * 16 + HexVal(LexLine[LexColNo]);
          Inc(LexColNo);
        End;
      End;
      LexScanEscChar := Chr(V And $FF);
    End;
  Else
    LexScanEscChar := Ch;
  End;
End;

{ ---- LexScanString : chaine simple/double/triple ------------ }
{ Quote = caractere de guillemet (' ou ")                        }
{ Triple = True pour les chaines triple-quote (''' ou """)       }
Procedure LexScanString(Quote : Char; Triple : Boolean);
Var
  S  : TString;
  Ch : Char;
Begin
  S := '';
  If Triple Then
  Begin
    { Sauter les 3 guillemets ouvrants }
    Inc(LexColNo); Inc(LexColNo); Inc(LexColNo);
    { Scanner jusqu a ''' ou """ }
    While Not LexEOF Do
    Begin
      If LexColNo > Length(LexLine) Then
      Begin
        If Length(S) < MAX_STR Then S := S + #10;
        LexNextLine;
        Continue;
      End;
      Ch := LexLine[LexColNo];
      { Detecter les 3 guillemets fermants }
      If (Ch = Quote) And (LexColNo + 2 <= Length(LexLine)) And
         (LexLine[LexColNo + 1] = Quote) And
         (LexLine[LexColNo + 2] = Quote) Then
      Begin
        Inc(LexColNo); Inc(LexColNo); Inc(LexColNo);
        Break;
      End
      Else If Ch = '\' Then
      Begin
        Inc(LexColNo);
        Ch := LexScanEscChar;
        If Length(S) < MAX_STR Then S := S + Ch;
      End
      Else
      Begin
        If Length(S) < MAX_STR Then S := S + Ch;
        Inc(LexColNo);
      End;
    End;
  End
  Else
  Begin
    { Chaine simple : un seul guillemet }
    Inc(LexColNo); { sauter guillemet ouvrant }
    While LexColNo <= Length(LexLine) Do
    Begin
      Ch := LexLine[LexColNo];
      If Ch = Quote Then
      Begin
        Inc(LexColNo);
        Break;
      End
      Else If Ch = '\' Then
      Begin
        Inc(LexColNo);
        Ch := LexScanEscChar;
        If Length(S) < MAX_STR Then S := S + Ch;
      End
      Else
      Begin
        If Length(S) < MAX_STR Then S := S + Ch;
        Inc(LexColNo);
      End;
    End;
  End;
  CurToken.Kind   := TK_STRING;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
End;

{ ---- LexInit : ouvrir le fichier source --------------------- }
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
  IndentTop  := 0;
  IndentStack[0] := 0;
  DedentQueue := 0;
  AtLineStart := True;
  ParenDepth  := 0;
  { Lire la premiere ligne }
  LexNextLine;
  { Detecter shebang #!/... et le sauter }
  If (Not LexEOF) And (Length(LexLine) >= 2) And
     (LexLine[1] = '#') And (LexLine[2] = '!') Then
  Begin
    LexNextLine;
    AtLineStart := True;
  End;
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

{ ---- LexNextToken : scanner le prochain token --------------- }
{ Gere l indentation Python (INDENT/DEDENT) et les NEWLINE      }
Procedure LexNextToken;
Var
  Ch       : Char;
  Indent  : Integer;
  IsTriple : Boolean;
  Scanning : Boolean;
Begin
  CurToken.IntVal   := 0;
  CurToken.FloatVal := 0.0;

  { 1) S il reste des DEDENT en file d attente, les emettre }
  If DedentQueue > 0 Then
  Begin
    Dec(DedentQueue);
    CurToken.Kind := TK_DEDENT;
    CurToken.Val  := '';
    CurToken.Line := LexLineNo;
    CurToken.Col  := 1;
    Exit;
  End;

  Scanning := True;
  While Scanning Do
  Begin
    { Avancer si on est en fin de ligne }
    If (Not LexEOF) And (LexColNo > Length(LexLine)) Then
    Begin
      { Emettre NEWLINE avant de passer a la ligne suivante }
      If (ParenDepth = 0) And (Not AtLineStart) Then
      Begin
        CurToken.Kind := TK_NEWLINE;
        CurToken.Val  := '';
        CurToken.Line := LexLineNo;
        CurToken.Col  := LexColNo;
        AtLineStart := True;
        Scanning := False;
        Break;
      End;
      { Passer les lignes }
      While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
      Begin
        LexNextLine;
        AtLineStart := True;
      End;
    End;

    { Fin de fichier : emettre les DEDENT restants puis EOF }
    If LexEOF Then
    Begin
      If IndentTop > 0 Then
      Begin
        Dec(IndentTop);
        DedentQueue := IndentTop; { les autres seront emis apres }
        IndentTop := 0;
        CurToken.Kind := TK_DEDENT;
        CurToken.Val  := '';
        CurToken.Line := LexLineNo;
        CurToken.Col  := 1;
        Scanning := False;
        Break;
      End;
      CurToken.Kind := TK_EOF;
      CurToken.Val  := '';
      CurToken.Line := LexLineNo;
      CurToken.Col  := LexColNo;
      Scanning := False;
      Break;
    End;

    { 2) Gestion de l indentation en debut de ligne }
    If AtLineStart Then
    Begin
      AtLineStart := False;

      { Calculer le niveau d indentation }
      Indent := 0;
      While (LexColNo <= Length(LexLine)) And
            ((LexLine[LexColNo] = ' ') Or (LexLine[LexColNo] = #9)) Do
      Begin
        If LexLine[LexColNo] = #9 Then
          Indent := ((Indent Div 8) + 1) * 8
        Else
          Inc(Indent);
        Inc(LexColNo);
      End;

      { Ligne vide ou commentaire seul : on ne genere pas INDENT/DEDENT }
      If (LexColNo > Length(LexLine)) Or (LexLine[LexColNo] = '#') Then
      Begin
        LexColNo := Length(LexLine) + 1; { passer la ligne }
        Continue;
      End;

      { Si on est dans des parentheses/crochets/accolades, pas d INDENT }
      If ParenDepth > 0 Then
        Continue;

      { Comparer avec le sommet de la pile d indentation }
      If Indent > IndentStack[IndentTop] Then
      Begin
        { Augmentation d indentation -> INDENT }
        Inc(IndentTop);
        If IndentTop >= MAX_INDENT Then
          IndentTop := MAX_INDENT - 1;
        IndentStack[IndentTop] := Indent;
        CurToken.Kind := TK_INDENT;
        CurToken.Val  := '';
        CurToken.Line := LexLineNo;
        CurToken.Col  := 1;
        Scanning := False;
        Break;
      End
      Else If Indent < IndentStack[IndentTop] Then
      Begin
        { Diminution d indentation -> DEDENT(s) }
        While (IndentTop > 0) And (Indent < IndentStack[IndentTop]) Do
        Begin
          Dec(IndentTop);
          Inc(DedentQueue);
        End;
        If Indent <> IndentStack[IndentTop] Then
          CompileError('indentation inconsistante', LexLineNo);
        { Emettre le premier DEDENT, les autres sont en file }
        If DedentQueue > 0 Then
        Begin
          Dec(DedentQueue);
          CurToken.Kind := TK_DEDENT;
          CurToken.Val  := '';
          CurToken.Line := LexLineNo;
          CurToken.Col  := 1;
          Scanning := False;
          Break;
        End;
      End;
      { Si indent = meme niveau, on continue normalement }
      Continue;
    End;

    CurToken.Line := LexLineNo;
    CurToken.Col  := LexColNo;
    Ch := LexLine[LexColNo];

    { Espaces }
    If (Ch = ' ') Or (Ch = #9) Or (Ch = #13) Or (Ch = #12) Then
    Begin
      Inc(LexColNo);
    End

    { Commentaire # -> fin de ligne }
    Else If Ch = '#' Then
    Begin
      LexColNo := Length(LexLine) + 1;
      { Le NEWLINE sera emis au prochain tour de boucle }
    End

    { Continuation de ligne avec \ en fin de ligne }
    Else If (Ch = '\') And (LexColNo = Length(LexLine)) Then
    Begin
      LexNextLine;
      { Pas de AtLineStart : la suite est la meme ligne logique }
    End

    { Identificateur ou mot-cle }
    Else If IsIdentStart(Ch) Then
    Begin
      { Prefixes de chaines : r'...' b'...' f'...' }
      If ((Ch = 'r') Or (Ch = 'R') Or (Ch = 'b') Or (Ch = 'B') Or
          (Ch = 'f') Or (Ch = 'F')) And
         (LexColNo < Length(LexLine)) And
         ((LexLine[LexColNo + 1] = '''') Or (LexLine[LexColNo + 1] = '"')) Then
      Begin
        Inc(LexColNo); { sauter le prefixe }
        Ch := LexLine[LexColNo];
        { Detecter triple-quote }
        IsTriple := (LexColNo + 2 <= Length(LexLine)) And
                    (LexLine[LexColNo + 1] = Ch) And
                    (LexLine[LexColNo + 2] = Ch);
        LexScanString(Ch, IsTriple);
        Scanning := False;
      End
      Else
      Begin
        LexScanIdent;
        Scanning := False;
      End;
    End

    { Nombre decimal }
    Else If (Ch >= '0') And (Ch <= '9') Then
    Begin
      LexScanNumber;
      Scanning := False;
    End

    { Nombre .5 (point suivi d un chiffre) }
    Else If (Ch = '.') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] >= '0') And
            (LexLine[LexColNo + 1] <= '9') Then
    Begin
      LexScanNumber;
      Scanning := False;
    End

    { Chaines de caracteres }
    Else If (Ch = '''') Or (Ch = '"') Then
    Begin
      { Detecter triple-quote }
      IsTriple := (LexColNo + 2 <= Length(LexLine)) And
                  (LexLine[LexColNo + 1] = Ch) And
                  (LexLine[LexColNo + 2] = Ch);
      LexScanString(Ch, IsTriple);
      Scanning := False;
    End

    { Operateurs multi-caracteres Python }

    { ** et **= }
    Else If (Ch = '*') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '*') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '**=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '**';
      End;
      Scanning := False;
    End

    { *= }
    Else If (Ch = '*') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '*=';
      Scanning := False;
    End

    { * }
    Else If Ch = '*' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '*';
      Scanning := False;
    End

    { // et //= }
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '/') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '//=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '//';
      End;
      Scanning := False;
    End

    { /= }
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '/=';
      Scanning := False;
    End

    { / }
    Else If Ch = '/' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '/';
      Scanning := False;
    End

    { == }
    Else If (Ch = '=') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '==';
      Scanning := False;
    End

    { = }
    Else If Ch = '=' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '=';
      Scanning := False;
    End

    { != }
    Else If (Ch = '!') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '!=';
      Scanning := False;
    End

    { << et <<= }
    Else If (Ch = '<') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '<') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '<<=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '<<';
      End;
      Scanning := False;
    End

    { <= }
    Else If (Ch = '<') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '<=';
      Scanning := False;
    End

    { < }
    Else If Ch = '<' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '<';
      Scanning := False;
    End

    { >> et >>= }
    Else If (Ch = '>') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '>') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '>>=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '>>';
      End;
      Scanning := False;
    End

    { >= }
    Else If (Ch = '>') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '>=';
      Scanning := False;
    End

    { > }
    Else If Ch = '>' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '>';
      Scanning := False;
    End

    { += }
    Else If (Ch = '+') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '+=';
      Scanning := False;
    End

    { + }
    Else If Ch = '+' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '+';
      Scanning := False;
    End

    { -= et -> }
    Else If (Ch = '-') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '-=';
      Scanning := False;
    End
    Else If (Ch = '-') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '>') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '->';
      Scanning := False;
    End

    { - }
    Else If Ch = '-' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '-';
      Scanning := False;
    End

    { %= }
    Else If (Ch = '%') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '%=';
      Scanning := False;
    End

    { % }
    Else If Ch = '%' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '%';
      Scanning := False;
    End

    { &= }
    Else If (Ch = '&') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '&=';
      Scanning := False;
    End

    { & }
    Else If Ch = '&' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '&';
      Scanning := False;
    End

    { |= }
    Else If (Ch = '|') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '|=';
      Scanning := False;
    End

    { | }
    Else If Ch = '|' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '|';
      Scanning := False;
    End

    { ^= }
    Else If (Ch = '^') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '^=';
      Scanning := False;
    End

    { ^ }
    Else If Ch = '^' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '^';
      Scanning := False;
    End

    { ~ }
    Else If Ch = '~' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '~';
      Scanning := False;
    End

    { @ (decorateur) }
    Else If Ch = '@' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '@';
      Scanning := False;
    End

    { ... (Ellipsis) }
    Else If (Ch = '.') And (LexColNo + 2 <= Length(LexLine)) And
            (LexLine[LexColNo + 1] = '.') And
            (LexLine[LexColNo + 2] = '.') Then
    Begin
      Inc(LexColNo); Inc(LexColNo); Inc(LexColNo);
      CurToken.Kind := TK_PUNCT; CurToken.Val := '...';
      Scanning := False;
    End

    { . }
    Else If Ch = '.' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_PUNCT; CurToken.Val := '.';
      Scanning := False;
    End

    { : }
    Else If Ch = ':' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_PUNCT; CurToken.Val := ':';
      Scanning := False;
    End

    { ; }
    Else If Ch = ';' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_PUNCT; CurToken.Val := ';';
      Scanning := False;
    End

    { , }
    Else If Ch = ',' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_PUNCT; CurToken.Val := ',';
      Scanning := False;
    End

    { ( [ { : ponctuation ouvrante -> incrementer ParenDepth }
    Else If (Ch = '(') Or (Ch = '[') Or (Ch = '{') Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := Ch;
      Inc(LexColNo);
      Inc(ParenDepth);
      Scanning := False;
    End

    { ponctuation fermante -> decrementer ParenDepth }
    Else If (Ch = ')') Or (Ch = ']') Or (Ch = '}') Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := Ch;
      Inc(LexColNo);
      If ParenDepth > 0 Then Dec(ParenDepth);
      Scanning := False;
    End

    { Caractere inconnu }
    Else
    Begin
      WarnMsg('caractere inconnu: ' + Ch, LexLineNo);
      Inc(LexColNo);
    End;

  End; { While Scanning }
End;

{ ---- ParserAdvance : lire le prochain token avec debug ------ }
Procedure ParserAdvance;
Begin
  LexNextToken;
  If Opts.DebugMode Then
    PrintToken(CurToken);
End;

{ ============================================================
  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
  ============================================================ }

{ ---- LabelGen : generateur de labels uniques _PYL_N -------- }
Function LabelGen : TString;
Begin
  Inc(LabelGenSeq);
  LabelGen := PY_LBL_PFX + IntToStr_(LabelGenSeq);
End;

{ ---- EmitRaw : ecrire une ligne brute dans le fichier ASM --- }
Procedure EmitRaw(Const S : String);
Begin
  If OutFOpen Then
    WriteLn(OutF, S);
End;

{ ---- DataAdd : ajouter une entree dans DataTab -------------- }
Function DataAdd(Const Lbl : TString; Kind : TDataKind;
                 AIntVal : LongInt; Const AStrVal : TString) : Integer;
Begin
  If DataCount >= MAX_DATA Then
    FatalError('DataTab pleine (MAX_DATA atteint)');
  DataTab[DataCount].LblName   := Lbl;
  DataTab[DataCount].Kind      := Kind;
  DataTab[DataCount].IntVal    := AIntVal;
  DataTab[DataCount].StrVal    := AStrVal;
  DataTab[DataCount].ElemCount := 0;
  DataAdd := DataCount;
  Inc(DataCount);
End;

{ DataAddStr : creer un label _PYK_N et stocker la chaine litterale }
Function DataAddStr(Const S : TString) : TString;
Var
  Lbl : TString;
Begin
  Inc(LabelGenSeq);
  Lbl := PY_STR_PFX + IntToStr_(LabelGenSeq);
  DataAdd(Lbl, DK_STR, 0, S);
  DataAddStr := Lbl;
End;

{ DataAddWord : ajouter un mot 16 bits dans le segment DATA }
Function DataAddWord(Const Lbl : TString; AIntVal : LongInt) : Integer;
Begin
  DataAddWord := DataAdd(Lbl, DK_WORD, AIntVal, '');
End;

{ ============================================================
  TODO 08 - SEGMENT DE DONNEES ET STATIQUES [IMPLEMENTE]
  ============================================================ }

{ DataAddList : creer une entree DK_LIST dans DataTab.            }
{ AElemCount elements de 16 bits (DW) seront reserves.            }
{ Les elements sont initialises a 0 ; le code generateur remplit  }
{ les valeurs effectives.                                          }
Function DataAddList(Const Lbl : TString;
                     AElemCount : Integer) : Integer;
Var
  Idx : Integer;
Begin
  If DataCount >= MAX_DATA Then
    FatalError('DataTab pleine (MAX_DATA atteint)');
  Idx := DataCount;
  DataTab[Idx].LblName   := Lbl;
  DataTab[Idx].Kind      := DK_LIST;
  DataTab[Idx].IntVal    := 0;
  DataTab[Idx].StrVal    := '';
  DataTab[Idx].ElemCount := AElemCount;
  Inc(DataCount);
  DataAddList := Idx;
End;

{ DataAddDict : creer une entree DK_DICT dans DataTab.            }
{ APairCount paires cle/valeur -> 2*APairCount mots de 16 bits.   }
Function DataAddDict(Const Lbl : TString;
                     APairCount : Integer) : Integer;
Var
  Idx : Integer;
Begin
  If DataCount >= MAX_DATA Then
    FatalError('DataTab pleine (MAX_DATA atteint)');
  Idx := DataCount;
  DataTab[Idx].LblName   := Lbl;
  DataTab[Idx].Kind      := DK_DICT;
  DataTab[Idx].IntVal    := 0;
  DataTab[Idx].StrVal    := '';
  DataTab[Idx].ElemCount := APairCount;
  Inc(DataCount);
  DataAddDict := Idx;
End;

{ ---- Constructeurs TExprVal --------------------------------- }

{ ExprMakeImm : valeur immediate constante }
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := AVal;
  Res.TypeIdx := ATypeIdx;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ExprMakeNone : valeur invalide (void / erreur) }
Procedure ExprMakeNone(Var Res : TExprVal);
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_UNKNOWN;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ExprMakeBool : valeur booleenne (0 ou 1) }
Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  If AVal <> 0 Then Res.ImmVal := 1 Else Res.ImmVal := 0;
  Res.TypeIdx := TY_IDX_BOOL;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ExprMakeAX : valeur dans le registre AX }
Procedure ExprMakeAX(ATypeIdx : Integer; Var Res : TExprVal);
Begin
  Res.Kind    := EK_AX;
  Res.ImmVal  := 0;
  Res.TypeIdx := ATypeIdx;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ---- Evaluateurs de litteraux ------------------------------- }

{ LitEvalInt : convertir un token TK_INTEGER en valeur         }
{ (IntVal est deja calcule par LexScanNumber)                   }
Procedure LitEvalInt(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeImm(T.IntVal, TY_IDX_INT, Res);
End;

{ LitEvalFloat : convertir un token TK_FLOAT en entier (trunc) }
{ Python n a pas de float natif 8086 : on tronque avec warning  }
Procedure LitEvalFloat(Const T : TToken; Var Res : TExprVal);
Var
  IV : LongInt;
Begin
  IV := Trunc(T.FloatVal);
  If IV > 32767 Then IV := 32767;
  If IV < -32768 Then IV := -32768;
  WarnMsg('flottant tronque en entier: ' + T.Val, T.Line);
  ExprMakeImm(IV, TY_IDX_INT, Res);
End;

{ LitEvalStr : stocker une chaine dans le segment DATA         }
{ Retourne un EK_MEM pointant vers le label de la chaine       }
Procedure LitEvalStr(Const T : TToken; Var Res : TExprVal);
Var
  Lbl : TString;
Begin
  Lbl := DataAddStr(T.Val);
  Res.Kind    := EK_MEM;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_IDX_STR;
  Res.Offset  := DataCount - 1;   { index de l entree DATA }
  Res.SymIdx  := -1;
End;

{ LitEval : dispatcher principal pour les litteraux Python     }
{ Tokens : TK_INTEGER, TK_FLOAT, TK_STRING, TK_KEYWORD        }
{ Mots-cles : True, False, None                                 }
Procedure LitEval(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeNone(Res);
  Case T.Kind Of
    TK_INTEGER :
      LitEvalInt(T, Res);
    TK_FLOAT :
      LitEvalFloat(T, Res);
    TK_STRING :
      LitEvalStr(T, Res);
    TK_KEYWORD :
    Begin
      If T.Val = 'True' Then
        ExprMakeBool(1, Res)
      Else If T.Val = 'False' Then
        ExprMakeBool(0, Res)
      Else If T.Val = 'None' Then
        ExprMakeImm(0, TY_IDX_NONE, Res)
      Else
        ExprMakeNone(Res);
    End;
  Else
    ExprMakeNone(Res);
  End;
End;

{ ---- Emission ASM (stubs pour TODOs suivants) --------------- }

Procedure EmitOpen;
Begin
  Assign(OutF, Opts.OutFile);
  Rewrite(OutF);
  If IOResult <> 0 Then
    FatalError('impossible de creer: ' + Opts.OutFile);
  OutFOpen := True;
End;

Procedure EmitHeader;
Begin
  EmitRaw('; Genere par PYTHON86 v' + PYTHON86_VERSION +
          ' - ' + Opts.SrcFile);
  EmitRaw('; Cible : MASM .MODEL SMALL, DOS 16 bits');
  EmitRaw('');
  EmitRaw('.MODEL SMALL');
  EmitRaw('.STACK ' + IntToStr_(STACK_SIZE));
  EmitRaw('');
  EmitRaw('_TEXT   SEGMENT WORD PUBLIC ''CODE''');
  EmitRaw('        ASSUME CS:_TEXT, DS:_DATA, SS:STACK');
  EmitRaw('');
End;

Procedure EmitDataSeg;
Var
  I, J : Integer;
  S    : TString;
Begin
  EmitRaw('');
  EmitRaw('_DATA   SEGMENT WORD PUBLIC ''DATA''');
  EmitRaw('');
  { Buffer de travail pour concatenation de chaines }
  EmitRaw('_PY_STRBUF  DB  256 DUP(0)');
  EmitRaw('');
  { Heap statique pour allocations dynamiques (listes, dicts, objets) }
  EmitRaw('_PY_HEAP    DB  4096 DUP(0)');
  EmitRaw('_PY_HEAPTOP DW  0');
  EmitRaw('');
  { Emettre toutes les entrees de DataTab }
  For I := 0 To DataCount - 1 Do
  Begin
    Case DataTab[I].Kind Of
      DK_WORD :
        EmitRaw(DataTab[I].LblName + '  DW  ' +
                IntToStr_(DataTab[I].IntVal));
      DK_BYTE :
        EmitRaw(DataTab[I].LblName + '  DB  ' +
                IntToStr_(DataTab[I].IntVal));
      DK_STR :
      Begin
        { Emettre la chaine comme DB 'c','h',...,0 }
        S := DataTab[I].StrVal;
        If Length(S) = 0 Then
          EmitRaw(DataTab[I].LblName + '  DB  0')
        Else
        Begin
          Write(OutF, DataTab[I].LblName, '  DB  ');
          For J := 1 To Length(S) Do
          Begin
            If J > 1 Then Write(OutF, ',');
            Write(OutF, Ord(S[J]));
          End;
          WriteLn(OutF, ',0');
        End;
      End;
      DK_ARRAY_BLK :
        EmitRaw(DataTab[I].LblName + '  DW  ' +
                IntToStr_(DataTab[I].ElemCount) + ' DUP(0)');
      DK_LIST :
      Begin
        { Liste litterale : ElemCount mots de 16 bits initialises a 0 }
        If DataTab[I].ElemCount <= 0 Then
          EmitRaw(DataTab[I].LblName + '  DW  0')
        Else
          EmitRaw(DataTab[I].LblName + '  DW  ' +
                  IntToStr_(DataTab[I].ElemCount) + ' DUP(0)');
      End;
      DK_DICT :
      Begin
        { Dictionnaire : 2*ElemCount mots (paires cle/valeur) }
        If DataTab[I].ElemCount <= 0 Then
          EmitRaw(DataTab[I].LblName + '  DW  0')
        Else
          EmitRaw(DataTab[I].LblName + '  DW  ' +
                  IntToStr_(DataTab[I].ElemCount * 2) + ' DUP(0)');
      End;
    End;
  End;
  EmitRaw('');
  EmitRaw('_DATA   ENDS');
End;

Procedure EmitClose;
Begin
  { Fermer le segment de code }
  EmitRaw('');
  EmitRaw('_TEXT   ENDS');
  EmitRaw('');
  { Segment de donnees }
  EmitDataSeg;
  EmitRaw('');
  EmitRaw('        END _PYF_Main');
  { Fermer le fichier }
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ============================================================
  TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
  ============================================================ }

{ ---- Helpers d emission ASM --------------------------------- }

{ EmitInstr : emettre une instruction indentee (8 espaces) }
Procedure EmitInstr(Const S : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, '        ', S);
End;

{ EmitLabel : emettre un label suivi de ':' }
Procedure EmitLabel(Const Lbl : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, Lbl, ':');
End;

{ EmitComment : emettre un commentaire ASM ('; msg') }
Procedure EmitComment(Const Msg : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, '; ', Msg);
End;

{ EmitBlankLine : ligne vide dans le fichier de sortie }
Procedure EmitBlankLine;
Begin
  If OutFOpen Then
    WriteLn(OutF);
End;

{ ---- ExprFlushToAX : materialiser la valeur dans AX --------- }
Procedure ExprFlushToAX(Var E : TExprVal);
Var
  S : TString;
Begin
  Case E.Kind Of
    EK_IMM :
    Begin
      If E.ImmVal = 0 Then
        EmitInstr('XOR    AX, AX')
      Else
      Begin
        Str(E.ImmVal, S);
        EmitInstr('MOV    AX, ' + S);
      End;
      E.Kind := EK_AX;
    End;
    EK_MEM :
    Begin
      { Chaine litterale : OFFSET label }
      If E.TypeIdx = TY_IDX_STR Then
      Begin
        If (E.Offset >= 0) And (E.Offset < DataCount) Then
          EmitInstr('MOV    AX, OFFSET ' + DataTab[E.Offset].LblName)
        Else If (E.SymIdx >= 0) And (E.SymIdx < SymCount) Then
          EmitInstr('MOV    AX, OFFSET ' + SymTab[E.SymIdx].MangledName)
        Else
          EmitInstr('XOR    AX, AX');
      End
      Else If (E.SymIdx >= 0) And (E.SymIdx < SymCount) Then
      Begin
        { Variable : charger depuis memoire (TODO 09) }
        ExprLoadToAX(E.SymIdx);
      End
      Else
        EmitInstr('XOR    AX, AX');
      E.Kind := EK_AX;
    End;
    EK_AX :
      ;  { deja dans AX }
    EK_NONE :
    Begin
      EmitInstr('XOR    AX, AX');
      E.Kind := EK_AX;
    End;
  End;
End;

{ ---- BinOpPrec : table de precedences Python (Pratt) --------
  Retourne 0 si l operateur n est pas binaire.
  Niveaux (ordre croissant = priorite croissante) :
    or           -> 1
    and          -> 2
    not          -> traite en unaire (ParseUnary)
    == != < <= > >= in is  -> 3
    |            -> 4
    ^            -> 5
    &            -> 6
    << >>        -> 7
    + - (binaire)-> 8
    * / // %     -> 9
    **           -> 10 (droit-associatif)                      }
Function BinOpPrec(Const Op : TString) : Integer;
Begin
  If Op = 'or' Then
    BinOpPrec := 1
  Else If Op = 'and' Then
    BinOpPrec := 2
  Else If (Op = '==') Or (Op = '!=') Or
          (Op = '<')  Or (Op = '<=') Or
          (Op = '>')  Or (Op = '>=') Or
          (Op = 'in') Or (Op = 'is') Or
          (Op = 'not in') Or (Op = 'is not') Then
    BinOpPrec := 3
  Else If Op = '|' Then
    BinOpPrec := 4
  Else If Op = '^' Then
    BinOpPrec := 5
  Else If Op = '&' Then
    BinOpPrec := 6
  Else If (Op = '<<') Or (Op = '>>') Then
    BinOpPrec := 7
  Else If (Op = '+') Or (Op = '-') Then
    BinOpPrec := 8
  Else If (Op = '*') Or (Op = '/') Or (Op = '//') Or (Op = '%') Then
    BinOpPrec := 9
  Else If Op = '**' Then
    BinOpPrec := 10
  Else
    BinOpPrec := 0;
End;

{ BinOpIsRight : ** est droit-associatif en Python }
Function BinOpIsRight(Const Op : TString) : Boolean;
Begin
  BinOpIsRight := (Op = '**');
End;

{ IsAssignOp : detecter les operateurs d affectation }
Function IsAssignOp(Const Op : TString) : Boolean;
Begin
  IsAssignOp := (Op = '=')   Or (Op = '+=')  Or (Op = '-=')  Or
                (Op = '*=')  Or (Op = '//=') Or (Op = '%=')  Or
                (Op = '**=') Or (Op = '&=')  Or (Op = '|=')  Or
                (Op = '^=')  Or (Op = '<<=') Or (Op = '>>=') Or
                (Op = '/=');
End;

{ ---- ExprEmitBinOp : generer le code 8086 d un operateur ----
  Pliage de constantes si L et R sont EK_IMM.
  Operateurs Python couverts :
    + - * / // % ** (arith)
    == != < <= > >= (comparaison)
    and or (logique, court-circuit)
    & | ^ << >> (bitwise)
    in, is (stub = comparaison)                                }
Procedure ExprEmitBinOp(Const Op : TString;
            Var L : TExprVal; Var R : TExprVal);
Var
  RS     : TString;
  LblEnd : TString;
  Acc    : LongInt;
  Exp    : LongInt;
Begin
  { ---- Pliage de constantes -------------------------------- }
  If (L.Kind = EK_IMM) And (R.Kind = EK_IMM) Then
  Begin
    If      Op = '+'   Then L.ImmVal := L.ImmVal + R.ImmVal
    Else If Op = '-'   Then L.ImmVal := L.ImmVal - R.ImmVal
    Else If Op = '*'   Then L.ImmVal := L.ImmVal * R.ImmVal
    Else If (Op = '/') Or (Op = '//') Then
    Begin
      If R.ImmVal = 0 Then
      Begin
        CompileError('division par zero', CurToken.Line);
        L.ImmVal := 0;
      End
      Else
        L.ImmVal := L.ImmVal Div R.ImmVal;
    End
    Else If Op = '%'   Then
    Begin
      If R.ImmVal = 0 Then
      Begin
        CompileError('modulo par zero', CurToken.Line);
        L.ImmVal := 0;
      End
      Else
        L.ImmVal := L.ImmVal Mod R.ImmVal;
    End
    Else If Op = '**'  Then
    Begin
      Acc := 1; Exp := R.ImmVal;
      If Exp < 0 Then L.ImmVal := 0
      Else Begin
        While Exp > 0 Do Begin Acc := Acc * L.ImmVal; Dec(Exp); End;
        L.ImmVal := Acc;
      End;
    End
    Else If Op = '&'   Then L.ImmVal := L.ImmVal And R.ImmVal
    Else If Op = '|'   Then L.ImmVal := L.ImmVal Or  R.ImmVal
    Else If Op = '^'   Then L.ImmVal := L.ImmVal Xor R.ImmVal
    Else If Op = '<<'  Then L.ImmVal := L.ImmVal Shl Integer(R.ImmVal And 15)
    Else If Op = '>>'  Then L.ImmVal := L.ImmVal Shr Integer(R.ImmVal And 15)
    Else If Op = '=='  Then Begin If L.ImmVal =  R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '!='  Then Begin If L.ImmVal <> R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '<'   Then Begin If L.ImmVal <  R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '<='  Then Begin If L.ImmVal <= R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '>'   Then Begin If L.ImmVal >  R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '>='  Then Begin If L.ImmVal >= R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = 'and' Then
    Begin
      If (L.ImmVal <> 0) And (R.ImmVal <> 0) Then L.ImmVal := R.ImmVal
      Else L.ImmVal := 0;
    End
    Else If Op = 'or'  Then
    Begin
      If L.ImmVal <> 0 Then { garde L }
      Else L.ImmVal := R.ImmVal;
    End
    Else If Op = 'in'      Then L.ImmVal := 0  { stub }
    Else If Op = 'not in'  Then L.ImmVal := 1  { stub }
    Else If Op = 'is'      Then
    Begin
      If L.ImmVal = R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0;
    End
    Else If Op = 'is not'  Then
    Begin
      If L.ImmVal <> R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0;
    End;
    L.TypeIdx := TY_IDX_INT;
    Exit;
  End;

  { ---- Court-circuit 'and' --------------------------------- }
  If Op = 'and' Then
  Begin
    LblEnd := LabelGen;
    ExprFlushToAX(L);
    EmitInstr('TEST   AX, AX');
    EmitInstr('JZ     ' + LblEnd);
    ExprFlushToAX(R);
    EmitLabel(LblEnd);
    L.Kind := EK_AX;
    L.TypeIdx := TY_IDX_INT;
    Exit;
  End;

  { ---- Court-circuit 'or' ---------------------------------- }
  If Op = 'or' Then
  Begin
    LblEnd := LabelGen;
    ExprFlushToAX(L);
    EmitInstr('TEST   AX, AX');
    EmitInstr('JNZ    ' + LblEnd);
    ExprFlushToAX(R);
    EmitLabel(LblEnd);
    L.Kind := EK_AX;
    L.TypeIdx := TY_IDX_INT;
    Exit;
  End;

  { ---- Cas general : emission 8086 ------------------------- }
  ExprFlushToAX(L);

  If R.Kind = EK_IMM Then
  Begin
    Str(R.ImmVal, RS);
    If      Op = '+'   Then EmitInstr('ADD    AX, ' + RS)
    Else If Op = '-'   Then EmitInstr('SUB    AX, ' + RS)
    Else If Op = '&'   Then EmitInstr('AND    AX, ' + RS)
    Else If Op = '|'   Then EmitInstr('OR     AX, ' + RS)
    Else If Op = '^'   Then EmitInstr('XOR    AX, ' + RS)
    Else If Op = '<<'  Then
    Begin
      EmitInstr('MOV    CL, ' + RS);
      EmitInstr('SHL    AX, CL');
    End
    Else If Op = '>>'  Then
    Begin
      EmitInstr('MOV    CL, ' + RS);
      EmitInstr('SAR    AX, CL');
    End
    Else If Op = '*'   Then
    Begin
      EmitInstr('MOV    BX, ' + RS);
      EmitInstr('IMUL   BX');
    End
    Else If Op = '**'  Then
    Begin
      EmitInstr('MOV    CX, ' + RS);
      EmitInstr('CALL   ' + PY_RT_PFX + 'POWER');
    End
    Else If (Op = '/') Or (Op = '//') Then
    Begin
      EmitInstr('MOV    BX, ' + RS);
      EmitInstr('CWD');
      EmitInstr('IDIV   BX');
    End
    Else If Op = '%'   Then
    Begin
      EmitInstr('MOV    BX, ' + RS);
      EmitInstr('CWD');
      EmitInstr('IDIV   BX');
      EmitInstr('MOV    AX, DX');
    End
    Else If Op = '=='  Then
    Begin
      EmitInstr('CMP    AX, ' + RS);
      EmitInstr('MOV    AX, 0');
      EmitInstr('JNE    $+4');
      EmitInstr('INC    AX');
    End
    Else If Op = '!='  Then
    Begin
      EmitInstr('CMP    AX, ' + RS);
      EmitInstr('MOV    AX, 0');
      EmitInstr('JE     $+4');
      EmitInstr('INC    AX');
    End
    Else If Op = '<'   Then
    Begin
      EmitInstr('CMP    AX, ' + RS);
      EmitInstr('MOV    AX, 0');
      EmitInstr('JGE    $+4');
      EmitInstr('INC    AX');
    End
    Else If Op = '<='  Then
    Begin
      EmitInstr('CMP    AX, ' + RS);
      EmitInstr('MOV    AX, 0');
      EmitInstr('JG     $+4');
      EmitInstr('INC    AX');
    End
    Else If Op = '>'   Then
    Begin
      EmitInstr('CMP    AX, ' + RS);
      EmitInstr('MOV    AX, 0');
      EmitInstr('JLE    $+4');
      EmitInstr('INC    AX');
    End
    Else If Op = '>='  Then
    Begin
      EmitInstr('CMP    AX, ' + RS);
      EmitInstr('MOV    AX, 0');
      EmitInstr('JL     $+4');
      EmitInstr('INC    AX');
    End
    Else If (Op = 'in') Or (Op = 'not in') Or
            (Op = 'is') Or (Op = 'is not') Then
    Begin
      { Stub : comparaison simple pour 'is', 0/1 pour 'in' }
      If (Op = 'is') Or (Op = 'is not') Then
      Begin
        EmitInstr('CMP    AX, ' + RS);
        EmitInstr('MOV    AX, 0');
        If Op = 'is' Then
          EmitInstr('JNE    $+4')
        Else
          EmitInstr('JE     $+4');
        EmitInstr('INC    AX');
      End
      Else
      Begin
        EmitInstr('XOR    AX, AX');   { stub in/not in }
        If Op = 'not in' Then EmitInstr('INC    AX');
      End;
    End;
  End
  Else
  Begin
    { R non immediat : sauvegarder L dans la pile, charger R dans BX }
    EmitInstr('PUSH   AX');
    ExprFlushToAX(R);
    EmitInstr('MOV    BX, AX');
    EmitInstr('POP    AX');
    If      Op = '+'  Then EmitInstr('ADD    AX, BX')
    Else If Op = '-'  Then EmitInstr('SUB    AX, BX')
    Else If Op = '&'  Then EmitInstr('AND    AX, BX')
    Else If Op = '|'  Then EmitInstr('OR     AX, BX')
    Else If Op = '^'  Then EmitInstr('XOR    AX, BX')
    Else If Op = '<<' Then
    Begin
      EmitInstr('MOV    CX, BX');
      EmitInstr('SHL    AX, CL');
    End
    Else If Op = '>>' Then
    Begin
      EmitInstr('MOV    CX, BX');
      EmitInstr('SAR    AX, CL');
    End
    Else If Op = '*'  Then EmitInstr('IMUL   BX')
    Else If Op = '**' Then
    Begin
      EmitInstr('MOV    CX, BX');
      EmitInstr('CALL   ' + PY_RT_PFX + 'POWER');
    End
    Else If (Op = '/') Or (Op = '//') Then
    Begin
      EmitInstr('CWD');
      EmitInstr('IDIV   BX');
    End
    Else If Op = '%' Then
    Begin
      EmitInstr('CWD');
      EmitInstr('IDIV   BX');
      EmitInstr('MOV    AX, DX');
    End
    Else
    Begin
      { Comparaison : CMP AX, BX + branchement conditionnel }
      EmitInstr('CMP    AX, BX');
      EmitInstr('MOV    AX, 0');
      If      Op = '=='     Then EmitInstr('JNE    $+4')
      Else If Op = '!='     Then EmitInstr('JE     $+4')
      Else If Op = '<'      Then EmitInstr('JGE    $+4')
      Else If Op = '<='     Then EmitInstr('JG     $+4')
      Else If Op = '>'      Then EmitInstr('JLE    $+4')
      Else If Op = '>='     Then EmitInstr('JL     $+4')
      Else If Op = 'is'     Then EmitInstr('JNE    $+4')
      Else If Op = 'is not' Then EmitInstr('JE     $+4')
      Else If Op = 'in'     Then EmitInstr('JMP    $+4')  { stub }
      Else If Op = 'not in' Then EmitInstr('JMP    $+2');  { stub }
      EmitInstr('INC    AX');
    End;
  End;
  L.Kind    := EK_AX;
  L.SymIdx  := -1;
End;

{ ---- ParsePrimary : atome du parseur Pratt (TODO 10) --------- }
{ Gere : litteraux entiers, flottants, chaines, True/False/None, }
{ identifiants + appel de fonction, parentheses / tuple,          }
{ liste literale, dict literale, postfixes [i], [a:b], .attr.     }
Procedure ParsePrimary(Var Res : TExprVal);
Var
  E      : TExprVal;
  IdxSym : Integer;
  IdxE   : TExprVal;
Begin
  ExprMakeNone(Res);
  Case CurToken.Kind Of

    { Litteraux : deleguer a LitEval }
    TK_INTEGER, TK_FLOAT, TK_STRING :
    Begin
      LitEval(CurToken, Res);
      ParserAdvance;
    End;

    { Mots-cles litteraux : True, False, None }
    TK_KEYWORD :
    Begin
      If (CurToken.Val = 'True') Or (CurToken.Val = 'False') Or
         (CurToken.Val = 'None') Then
      Begin
        LitEval(CurToken, Res);
        ParserAdvance;
      End
      Else
      Begin
        { Mot-cle non litterale : pas un atome d expression }
        ExprMakeNone(Res);
      End;
    End;

    { Identifiant : resolution via SymFind (TODO 05/09/10) }
    TK_IDENT :
    Begin
      IdxSym := SymFind(CurToken.Val);
      If IdxSym >= 0 Then
      Begin
        EmitComment('ident: ' + CurToken.Val +
                    ' [' + SymTab[IdxSym].MangledName + ']');
        Res.SymIdx := IdxSym;
        { Builtin ou fonction : gerer l appel (TODO 10) }
        If (SymTab[IdxSym].Kind = SK_BUILTIN) Or
           (SymTab[IdxSym].Kind = SK_FUNC) Then
        Begin
          ExprMakeImm(0, SymTab[IdxSym].TypeIdx, Res);
          Res.SymIdx := IdxSym;
        End
        Else
        Begin
          { Variable : retourner EK_MEM pour acces lecture/ecriture }
          Res.Kind    := EK_MEM;
          Res.TypeIdx := SymTab[IdxSym].TypeIdx;
          Res.Offset  := SymTab[IdxSym].Offset;
        End;
      End
      Else
      Begin
        { Identifiant inconnu : auto-declarer comme variable globale }
        EmitComment('ident (auto): ' + CurToken.Val);
        IdxSym := SymAdd(CurToken.Val, SK_VAR, TY_UNKNOWN, 0);
        Res.SymIdx := IdxSym;
        Res.Kind    := EK_MEM;
        Res.TypeIdx := TY_UNKNOWN;
        Res.Offset  := 0;
        If IdxSym < 0 Then Res.SymIdx := -1;
      End;
      ParserAdvance;
      { Appel de fonction / builtin : f(args) (TODO 10) }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        ParseCallArgs(Res.SymIdx, Res);
    End;

    { Parentheses de groupement ou tuple literal (TODO 10) }
    TK_PUNCT :
    Begin
      If CurToken.Val = '(' Then
      Begin
        ParserAdvance;
        { Tuple vide : () }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        Begin
          ParserAdvance;
          EmitComment('tuple vide');
          EmitInstr('XOR    AX, AX');
          ExprMakeAX(TY_IDX_LIST, Res);
        End
        Else
        Begin
          ParseExpr(E);
          { Verifier si c est un tuple : (e1, e2, ...) }
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          Begin
            EmitComment('tuple literal');
            ExprFlushToAX(E);
            EmitInstr('PUSH   AX');  { sauvegarder premier element }
            While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
            Begin
              ParserAdvance;
              If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
                Break;
              ParseExpr(IdxE);
              ExprFlushToAX(IdxE);
              EmitInstr('PUSH   AX');
            End;
            EmitInstr('POP    AX');  { valeur du dernier element dans AX }
            ExprMakeAX(TY_IDX_LIST, E);
          End;
          Res := E;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance
          Else
            CompileError(''')'' attendue', CurToken.Line);
        End;
      End
      Else If CurToken.Val = '[' Then
        ParseListLiteral(Res)
      Else If CurToken.Val = '{' Then
        ParseDictLiteral(Res)
      Else
        ExprMakeNone(Res);
    End;

  Else
    ExprMakeNone(Res);
  End;

  { Postfixes : index [i], slice [a:b], attribut .attr (TODO 10) }
  While (CurToken.Kind = TK_PUNCT) And
        ((CurToken.Val = '[') Or (CurToken.Val = '.')) Do
  Begin
    If CurToken.Val = '[' Then
    Begin
      { Acces index ou slice : expr[i] ou expr[a:b] }
      ExprFlushToAX(Res);
      EmitInstr('MOV    SI, AX');   { SI = objet }
      ParserAdvance;
      ParseExpr(IdxE);
      { Detecter slice : [a:b] }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      Begin
        { Slice : expr[a:b] }
        EmitComment('slice [a:b]');
        ExprFlushToAX(IdxE);
        EmitInstr('PUSH   AX');   { sauvegarder a }
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
        Begin
          EmitInstr('MOV    BX, 0FFFFh'); { b = fin }
          EmitInstr('POP    AX');         { AX = a }
        End
        Else
        Begin
          ParseExpr(E);
          ExprFlushToAX(E);
          EmitInstr('MOV    BX, AX');   { BX = b }
          EmitInstr('POP    AX');       { AX = a }
        End;
        EmitInstr('CALL   ' + PY_RT_PFX + 'SLICE');
      End
      Else
      Begin
        { Index simple : expr[i] }
        EmitComment('index [i]');
        ExprFlushToAX(IdxE);
        EmitInstr('SHL    AX, 1');     { AX = i * 2 (taille mot) }
        EmitInstr('ADD    SI, AX');
        EmitInstr('MOV    AX, [SI]');
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
        ParserAdvance
      Else
        CompileError(''']'' attendue', CurToken.Line);
      ExprMakeAX(TY_IDX_INT, Res);
    End
    Else If CurToken.Val = '.' Then
    Begin
      { Acces attribut : expr.attr }
      ExprFlushToAX(Res);
      EmitInstr('MOV    SI, AX');   { SI = instance }
      ParserAdvance;
      If CurToken.Kind = TK_IDENT Then
      Begin
        EmitComment('attr: .' + CurToken.Val);
        { Attribut stub : offset 0 pour l instant }
        EmitInstr('MOV    AX, [SI]');
        ParserAdvance;
        { Appel de methode : obj.method(args) }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          While (CurToken.Kind <> TK_EOF) And
                Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
            ParserAdvance;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
      End
      Else
        CompileError('identifiant attendu apres ''.''', CurToken.Line);
      ExprMakeAX(TY_IDX_INT, Res);
    End;
  End;
End;

{ ---- ParseUnary : operateurs unaires Python ------------------ }
{ Gere : - (negation), + (identite), ~ (complement bit a bit),  }
{ not (negation logique).                                         }
Procedure ParseUnary(Var Res : TExprVal);
Begin
  { Unaire '-' }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '-') Then
  Begin
    ParserAdvance;
    ParseUnary(Res);
    If Res.Kind = EK_IMM Then
      Res.ImmVal := -Res.ImmVal
    Else
    Begin
      ExprFlushToAX(Res);
      EmitInstr('NEG    AX');
      Res.Kind := EK_AX;
    End;
    Exit;
  End;

  { Unaire '+' : identite }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '+') Then
  Begin
    ParserAdvance;
    ParseUnary(Res);
    Exit;
  End;

  { Unaire '~' : complement bit a bit }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '~') Then
  Begin
    ParserAdvance;
    ParseUnary(Res);
    If Res.Kind = EK_IMM Then
      Res.ImmVal := Not Res.ImmVal
    Else
    Begin
      ExprFlushToAX(Res);
      EmitInstr('NOT    AX');
      Res.Kind := EK_AX;
    End;
    Exit;
  End;

  { Unaire 'not' : negation logique }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'not') Then
  Begin
    ParserAdvance;
    { Detecter 'not in' (operateur binaire combine) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'in') Then
    Begin
      { 'not in' sera gere comme operateur binaire par ParseExprPrec }
      { On recule : c est a ParseExprPrec de le gerer                }
      { Non - on parse l operande unaire 'not' normalement           }
      ParseUnary(Res);
      If Res.Kind = EK_IMM Then
      Begin
        If Res.ImmVal <> 0 Then Res.ImmVal := 0 Else Res.ImmVal := 1;
      End
      Else
      Begin
        ExprFlushToAX(Res);
        EmitInstr('TEST   AX, AX');
        EmitInstr('MOV    AX, 0');
        EmitInstr('JNZ    $+4');
        EmitInstr('INC    AX');
        Res.Kind := EK_AX;
      End;
      Res.TypeIdx := TY_IDX_BOOL;
      Exit;
    End;
    ParseUnary(Res);
    If Res.Kind = EK_IMM Then
    Begin
      If Res.ImmVal <> 0 Then Res.ImmVal := 0 Else Res.ImmVal := 1;
    End
    Else
    Begin
      ExprFlushToAX(Res);
      EmitInstr('TEST   AX, AX');
      EmitInstr('MOV    AX, 0');
      EmitInstr('JNZ    $+4');
      EmitInstr('INC    AX');
      Res.Kind := EK_AX;
    End;
    Res.TypeIdx := TY_IDX_BOOL;
    Exit;
  End;

  { Pas d operateur unaire : deleguer a ParsePrimary }
  ParsePrimary(Res);
End;

{ ---- ParseExprPrec : parseur Pratt pour expressions Python --- }
{ Boucle de montee de precedence pour operateurs binaires.       }
{ MinPrec = niveau de precedence minimal a capturer.             }
{ AX = gauche, BX = droite pour emission binaire.                }
{ Court-circuit pour and/or. Pliage de constantes via            }
{ ExprEmitBinOp.                                                  }
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal);
Var
  Op       : TString;
  Prec     : Integer;
  NextPrec : Integer;
  Right    : TExprVal;
Begin
  ParseUnary(Res);

  Repeat
    Op   := '';
    Prec := 0;

    { Detecter operateur binaire (TK_OP) }
    If CurToken.Kind = TK_OP Then
    Begin
      Op   := CurToken.Val;
      Prec := BinOpPrec(Op);
    End
    { Mots-cles operateurs : and, or, in, is, not (in) }
    Else If CurToken.Kind = TK_KEYWORD Then
    Begin
      If (CurToken.Val = 'and') Or (CurToken.Val = 'or') Then
      Begin
        Op   := CurToken.Val;
        Prec := BinOpPrec(Op);
      End
      Else If CurToken.Val = 'in' Then
      Begin
        Op   := 'in';
        Prec := BinOpPrec('in');
      End
      Else If CurToken.Val = 'is' Then
      Begin
        Op   := 'is';
        Prec := BinOpPrec('is');
      End
      Else If CurToken.Val = 'not' Then
      Begin
        { Lookahead pour 'not in' }
        Op := 'not';
        Prec := 0;
      End;
    End;

    { Verifier si la precedence est suffisante }
    If (Prec = 0) Or (Prec < MinPrec) Then Break;

    { Gerer 'is not' (deux tokens) }
    If Op = 'is' Then
    Begin
      ParserAdvance;
      If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'not') Then
      Begin
        Op := 'is not';
        ParserAdvance;
      End;
    End
    { Gerer 'not in' (deux tokens depuis 'not') }
    Else If Op = 'not' Then
    Begin
      ParserAdvance;
      If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'in') Then
      Begin
        Op := 'not in';
        Prec := BinOpPrec('not in');
        If Prec < MinPrec Then Break;
        ParserAdvance;
      End
      Else
      Begin
        { 'not' seul n est pas un operateur binaire ici }
        { On ne devrait pas arriver ici normalement      }
        Break;
      End;
    End
    Else
      ParserAdvance;  { consommer l operateur }

    { Calculer le seuil de precedence pour la droite }
    If BinOpIsRight(Op) Then
      NextPrec := Prec       { droit-associatif : meme niveau }
    Else
      NextPrec := Prec + 1;  { gauche-associatif : niveau + 1 }

    { Parser l operande droite }
    ParseExprPrec(NextPrec, Right);

    { Emettre le code binaire }
    ExprEmitBinOp(Op, Res, Right);

  Until False;
End;

{ ---- ParseExpr : parser une expression complete -------------- }
Procedure ParseExpr(Var Res : TExprVal);
Begin
  ParseExprPrec(1, Res);
End;

{ ============================================================
  TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
  ============================================================ }

{ ---- SymNameClean : nettoyer un nom pour l utiliser en ASM --- }
{ Supprime les caracteres non alphanumeriques sauf _ .           }
Function SymNameClean(Const Name : TString) : TString;
Var
  I : Integer;
  R : TString;
Begin
  R := '';
  For I := 1 To Length(Name) Do
    If ((Name[I] >= 'A') And (Name[I] <= 'Z')) Or
       ((Name[I] >= 'a') And (Name[I] <= 'z')) Or
       ((Name[I] >= '0') And (Name[I] <= '9')) Or
       (Name[I] = '_') Then
    Begin
      If Length(R) < MAX_STR Then
        R := R + Name[I];
    End
    Else
    Begin
      If Length(R) < MAX_STR Then
        R := R + '_';
    End;
  If R = '' Then R := '_anon';
  SymNameClean := R;
End;

{ ---- SymMangle : generer un label ASM depuis un symbole ------ }
{ Le prefixe depend de la categorie du symbole :                  }
{   SK_VAR / SK_LOCAL / SK_GLOBAL / SK_PARAM -> _PYV_             }
{   SK_FUNC   -> _PYF_                                            }
{   SK_CLASS  -> _PYC_                                             }
{   SK_MODULE -> _PYV_                                             }
{   SK_BUILTIN -> _PYRT_                                           }
Function SymMangle(Const Name : TString; Kind : TSymKind) : TString;
Var
  Clean : TString;
Begin
  Clean := SymNameClean(Name);
  Case Kind Of
    SK_FUNC    : SymMangle := PY_FN_PFX  + Clean;
    SK_CLASS   : SymMangle := PY_CLS_PFX + Clean;
    SK_BUILTIN : SymMangle := PY_RT_PFX  + Clean;
  Else
    SymMangle := PY_VAR_PFX + Clean;
  End;
End;

{ ---- SymFind : recherche MRU (Most Recently Used) ------------ }
{ Cherche du plus recent au plus ancien pour respecter le         }
{ masquage (shadowing) des variables dans les portees internes.   }
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

{ ---- SymFindInScope : recherche dans une portee specifique --- }
Function SymFindInScope(Const Name : TString;
                        Level : Integer) : Integer;
Var
  I : Integer;
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

{ ---- SymAdd : ajouter un symbole dans la table --------------- }
{ Retourne l indice du nouveau symbole (0-base) ou -1 si plein.  }
Function SymAdd(Const Name : TString; Kind : TSymKind;
                TypeIdx, Offset : Integer) : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    CompileError('table des symboles pleine (max=' +
                 IntToStr_(MAX_SYM) + ')', CurToken.Line);
    SymAdd := -1;
    Exit;
  End;
  SymTab[SymCount].Name        := Name;
  SymTab[SymCount].MangledName := SymMangle(Name, Kind);
  SymTab[SymCount].Kind        := Kind;
  SymTab[SymCount].TypeIdx     := TypeIdx;
  SymTab[SymCount].Offset      := Offset;
  SymTab[SymCount].ScopeLevel  := CurScope;
  SymTab[SymCount].IsGlobal    := False;
  SymTab[SymCount].IsNonlocal  := False;
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

{ ---- SymEnterScope : entrer dans une nouvelle portee --------- }
{ Chaque def, class, lambda cree un nouvel environnement.        }
Procedure SymEnterScope;
Begin
  If ScopeTop >= MAX_SCOPE Then
  Begin
    CompileError('portees trop imbriquees (max=' +
                 IntToStr_(MAX_SCOPE) + ')', CurToken.Line);
    Exit;
  End;
  ScopeStack[ScopeTop] := SymCount;
  Inc(ScopeTop);
  Inc(CurScope);
  If Opts.DebugMode Then
    WriteLn('  SCOPE_ENTER: level=', CurScope);
End;

{ ---- SymLeaveScope : quitter la portee courante -------------- }
{ Les symboles locaux de cette portee sont retires de la table.  }
Procedure SymLeaveScope;
Begin
  If ScopeTop <= 0 Then Exit;
  Dec(ScopeTop);
  SymCount := ScopeStack[ScopeTop];
  Dec(CurScope);
  If Opts.DebugMode Then
    WriteLn('  SCOPE_LEAVE: level=', CurScope);
End;

{ ---- SymInit : initialiser la table des symboles ------------- }
{ Enregistre les builtins Python (print, len, int, str, etc.)    }
Procedure SymInit;
Var
  I : Integer;
Begin
  SymCount  := 0;
  ScopeTop  := 0;
  CurScope  := 0;
  For I := 0 To MAX_SYM - 1 Do
  Begin
    SymTab[I].Name        := '';
    SymTab[I].MangledName := '';
    SymTab[I].Kind        := SK_VAR;
    SymTab[I].TypeIdx     := TY_UNKNOWN;
    SymTab[I].Offset      := 0;
    SymTab[I].ScopeLevel  := 0;
    SymTab[I].IsGlobal    := False;
    SymTab[I].IsNonlocal  := False;
    SymTab[I].DeclLine    := 0;
  End;
  { Enregistrer les builtins de base }
  SymAdd('print',     SK_BUILTIN, TY_IDX_NONE, 0);
  SymAdd('input',     SK_BUILTIN, TY_IDX_STR,  0);
  SymAdd('len',       SK_BUILTIN, TY_IDX_INT,  0);
  SymAdd('int',       SK_BUILTIN, TY_IDX_INT,  0);
  SymAdd('str',       SK_BUILTIN, TY_IDX_STR,  0);
  SymAdd('float',     SK_BUILTIN, TY_IDX_INT,  0);
  SymAdd('bool',      SK_BUILTIN, TY_IDX_BOOL, 0);
  SymAdd('abs',       SK_BUILTIN, TY_IDX_INT,  0);
  SymAdd('chr',       SK_BUILTIN, TY_IDX_STR,  0);
  SymAdd('ord',       SK_BUILTIN, TY_IDX_INT,  0);
  SymAdd('type',      SK_BUILTIN, TY_IDX_INT,  0);
  SymAdd('isinstance',SK_BUILTIN, TY_IDX_BOOL, 0);
  SymAdd('range',     SK_BUILTIN, TY_IDX_LIST, 0);
  SymAdd('list',      SK_BUILTIN, TY_IDX_LIST, 0);
  SymAdd('dict',      SK_BUILTIN, TY_IDX_DICT, 0);
  SymAdd('tuple',     SK_BUILTIN, TY_IDX_LIST, 0);
  SymAdd('set',       SK_BUILTIN, TY_IDX_LIST, 0);
  SymAdd('min',       SK_BUILTIN, TY_IDX_INT,  0);
  SymAdd('max',       SK_BUILTIN, TY_IDX_INT,  0);
  SymAdd('sum',       SK_BUILTIN, TY_IDX_INT,  0);
  SymAdd('sorted',    SK_BUILTIN, TY_IDX_LIST, 0);
  SymAdd('reversed',  SK_BUILTIN, TY_IDX_LIST, 0);
  SymAdd('enumerate', SK_BUILTIN, TY_IDX_LIST, 0);
  SymAdd('zip',       SK_BUILTIN, TY_IDX_LIST, 0);
  SymAdd('map',       SK_BUILTIN, TY_IDX_LIST, 0);
  SymAdd('filter',    SK_BUILTIN, TY_IDX_LIST, 0);
  SymAdd('hex',       SK_BUILTIN, TY_IDX_STR,  0);
  SymAdd('oct',       SK_BUILTIN, TY_IDX_STR,  0);
  SymAdd('bin',       SK_BUILTIN, TY_IDX_STR,  0);
  SymAdd('repr',      SK_BUILTIN, TY_IDX_STR,  0);
  SymAdd('id',        SK_BUILTIN, TY_IDX_INT,  0);
  SymAdd('hash',      SK_BUILTIN, TY_IDX_INT,  0);
  SymAdd('open',      SK_BUILTIN, TY_IDX_INT,  0);
End;

{ ============================================================
  TODO 06 - SYSTEME DE TYPES DYNAMIQUE [IMPLEMENTE]
  ============================================================ }

{ ---- TypeKindStr : nom textuel d un TTypeKind --------------- }
Function TypeKindStr(K : TTypeKind) : TString;
Begin
  Case K Of
    TYK_INT     : TypeKindStr := 'int';
    TYK_BOOL    : TypeKindStr := 'bool';
    TYK_STR     : TypeKindStr := 'str';
    TYK_NONE    : TypeKindStr := 'NoneType';
    TYK_LIST    : TypeKindStr := 'list';
    TYK_DICT    : TypeKindStr := 'dict';
    TYK_TUPLE   : TypeKindStr := 'tuple';
    TYK_FUNC    : TypeKindStr := 'function';
    TYK_OBJECT  : TypeKindStr := 'object';
    TYK_CLASS   : TypeKindStr := 'type';
    TYK_UNKNOWN : TypeKindStr := '<unknown>';
  Else
    TypeKindStr := '<unknown>';
  End;
End;

{ ---- TypeKindOf : retourner le TTypeKind pour un indice ----- }
{ Si l indice est invalide, retourne TYK_UNKNOWN.                }
Function TypeKindOf(TypeIdx : Integer) : TTypeKind;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeKindOf := TypeTab[TypeIdx].Kind
  Else
    TypeKindOf := TYK_UNKNOWN;
End;

{ ---- TypeSizeof : taille en octets d un type par son indice -- }
{ En architecture 16-bit, les pointeurs font 2 octets (un mot). }
{ INT=2, BOOL=2 (stocke sur un mot pour simplifier), STR=2,     }
{ LIST=2, DICT=2, TUPLE=2, FUNC=2, OBJECT=2, CLASS=2, NONE=0.  }
Function TypeSizeof(TypeIdx : Integer) : Integer;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeSizeof := TypeTab[TypeIdx].Size
  Else
    TypeSizeof := 2;  { taille par defaut : word (16 bits) }
End;

{ ---- TypeFindByName : rechercher un type par nom ------------- }
{ Retourne l indice dans TypeTab ou TY_UNKNOWN si non trouve.    }
Function TypeFindByName(Const Name : TString) : Integer;
Var I : Integer;
Begin
  For I := 0 To TypeCount - 1 Do
    If TypeTab[I].Name = Name Then
    Begin
      TypeFindByName := I;
      Exit;
    End;
  TypeFindByName := TY_UNKNOWN;
End;

{ ---- TypeIdxFromExpr : deduire l indice type d une expression  }
{ Utilise le champ TypeIdx de l expression si connu,              }
{ sinon retourne TY_UNKNOWN.                                      }
Function TypeIdxFromExpr(Const E : TExprVal) : Integer;
Begin
  If (E.TypeIdx >= 0) And (E.TypeIdx < TypeCount) Then
    TypeIdxFromExpr := E.TypeIdx
  Else
    TypeIdxFromExpr := TY_UNKNOWN;
End;

{ ---- TypeInit : enregistrer les types primitifs Python -------- }
{ Les indices correspondent a TY_IDX_INT=0 .. TY_IDX_CLASS=7.    }
{ Les types supplementaires (TUPLE, UNKNOWN) sont ajoutes apres.  }
Procedure TypeInit;
Var I : Integer;
Begin
  TypeCount := 0;
  For I := 0 To MAX_TYPE - 1 Do
  Begin
    TypeTab[I].Name := '';
    TypeTab[I].Kind := TYK_UNKNOWN;
    TypeTab[I].Size := 0;
  End;
  { TY_IDX_INT = 0 : entier 16 bits signe }
  TypeTab[0].Name := 'int';
  TypeTab[0].Kind := TYK_INT;
  TypeTab[0].Size := 2;
  { TY_IDX_STR = 1 : pointeur chaine }
  TypeTab[1].Name := 'str';
  TypeTab[1].Kind := TYK_STR;
  TypeTab[1].Size := 2;
  { TY_IDX_BOOL = 2 : booleen (stocke sur un mot) }
  TypeTab[2].Name := 'bool';
  TypeTab[2].Kind := TYK_BOOL;
  TypeTab[2].Size := 2;
  { TY_IDX_NONE = 3 : None (pas de taille) }
  TypeTab[3].Name := 'NoneType';
  TypeTab[3].Kind := TYK_NONE;
  TypeTab[3].Size := 0;
  { TY_IDX_LIST = 4 : liste dynamique (pointeur) }
  TypeTab[4].Name := 'list';
  TypeTab[4].Kind := TYK_LIST;
  TypeTab[4].Size := 2;
  { TY_IDX_DICT = 5 : dictionnaire (pointeur) }
  TypeTab[5].Name := 'dict';
  TypeTab[5].Kind := TYK_DICT;
  TypeTab[5].Size := 2;
  { TY_IDX_FUNC = 6 : fonction (pointeur de code) }
  TypeTab[6].Name := 'function';
  TypeTab[6].Kind := TYK_FUNC;
  TypeTab[6].Size := 2;
  { TY_IDX_CLASS = 7 : descripteur de classe }
  TypeTab[7].Name := 'type';
  TypeTab[7].Kind := TYK_CLASS;
  TypeTab[7].Size := 2;
  { 8 : tuple (pointeur tableau fixe) }
  TypeTab[8].Name := 'tuple';
  TypeTab[8].Kind := TYK_TUPLE;
  TypeTab[8].Size := 2;
  { 9 : object (instance de classe) }
  TypeTab[9].Name := 'object';
  TypeTab[9].Kind := TYK_OBJECT;
  TypeTab[9].Size := 2;
  TypeCount := 10;

  If Opts.DebugMode Then
    WriteLn('  Types enregistres : ', TypeCount);
End;

{ ============================================================
  TODO 07 - EMETTEUR DE CODE ASM [IMPLEMENTE]
  ============================================================ }

{ ---- EmitProlog : prologue de fonction ----------------------- }
{ PUSH BP / MOV BP,SP / SUB SP,FrameSize (si FrameSize > 0)     }
Procedure EmitProlog(FrameSize : Integer);
Begin
  EmitInstr('PUSH BP');
  EmitInstr('MOV BP,SP');
  If FrameSize > 0 Then
    EmitInstr('SUB SP,' + IntToStr_(FrameSize));
End;

{ ---- EmitEpilog : epilogue de fonction ----------------------- }
{ MOV SP,BP / POP BP / RET                                      }
Procedure EmitEpilog;
Begin
  EmitInstr('MOV SP,BP');
  EmitInstr('POP BP');
  EmitInstr('RET');
End;

{ ============================================================
  TODO 09 - VARIABLES ET AFFECTATIONS [IMPLEMENTE]
  ============================================================ }

{ ---- ExprLoadToAX : charger une variable dans AX ------------- }
{ Globale (scope=0) : MOV AX, [_PYV_x]                          }
{ Locale  (offset<0): MOV AX, [BP-offset]                       }
{ Param   (offset>0): MOV AX, [BP+offset]                       }
Procedure ExprLoadToAX(SIdx : Integer);
Var
  Off : Integer;
Begin
  If (SIdx < 0) Or (SIdx >= SymCount) Then
  Begin
    EmitInstr('XOR    AX, AX');
    Exit;
  End;
  If (SymTab[SIdx].ScopeLevel = 0) Or (SymTab[SIdx].IsGlobal) Then
  Begin
    { Variable globale : acces par label dans segment DATA }
    EnsureVarInData(SIdx);
    EmitInstr('MOV    AX, [' + SymTab[SIdx].MangledName + ']');
  End
  Else If SymTab[SIdx].Kind = SK_PARAM Then
  Begin
    { Parametre : [BP+offset] (offset positif, +4 pour ret addr+old BP) }
    Off := SymTab[SIdx].Offset;
    If Off >= 0 Then
      EmitInstr('MOV    AX, [BP+' + IntToStr_(Off) + ']')
    Else
      EmitInstr('MOV    AX, [BP' + IntToStr_(Off) + ']');
  End
  Else
  Begin
    { Variable locale : [BP-offset] (offset negatif ou 0) }
    Off := SymTab[SIdx].Offset;
    If Off = 0 Then
      EmitInstr('MOV    AX, [BP]')
    Else If Off > 0 Then
      EmitInstr('MOV    AX, [BP-' + IntToStr_(Off) + ']')
    Else
      EmitInstr('MOV    AX, [BP+' + IntToStr_(-Off) + ']');
  End;
End;

{ ---- EmitStoreVar : stocker AX dans une variable ------------- }
{ Globale (scope=0) : MOV [_PYV_x], AX                          }
{ Locale  (offset>0): MOV [BP-offset], AX                       }
{ Param   (offset>0): MOV [BP+offset], AX                       }
Procedure EmitStoreVar(SIdx : Integer);
Var
  Off : Integer;
Begin
  If (SIdx < 0) Or (SIdx >= SymCount) Then Exit;
  If (SymTab[SIdx].ScopeLevel = 0) Or (SymTab[SIdx].IsGlobal) Then
  Begin
    { Variable globale : stocker dans segment DATA }
    EnsureVarInData(SIdx);
    EmitInstr('MOV    [' + SymTab[SIdx].MangledName + '], AX');
  End
  Else If SymTab[SIdx].Kind = SK_PARAM Then
  Begin
    Off := SymTab[SIdx].Offset;
    If Off >= 0 Then
      EmitInstr('MOV    [BP+' + IntToStr_(Off) + '], AX')
    Else
      EmitInstr('MOV    [BP' + IntToStr_(Off) + '], AX');
  End
  Else
  Begin
    Off := SymTab[SIdx].Offset;
    If Off = 0 Then
      EmitInstr('MOV    [BP], AX')
    Else If Off > 0 Then
      EmitInstr('MOV    [BP-' + IntToStr_(Off) + '], AX')
    Else
      EmitInstr('MOV    [BP+' + IntToStr_(-Off) + '], AX');
  End;
End;

{ ---- EnsureVarInData : s assurer qu une globale a un DW ------ }
{ Si la variable globale n a pas encore d entree DATA, en creer   }
{ une (DK_WORD initialise a 0) avec le label _PYV_x.             }
Procedure EnsureVarInData(SIdx : Integer);
Var
  I : Integer;
  Lbl : TString;
Begin
  If (SIdx < 0) Or (SIdx >= SymCount) Then Exit;
  Lbl := SymTab[SIdx].MangledName;
  { Verifier si deja dans DataTab }
  For I := 0 To DataCount - 1 Do
    If DataTab[I].LblName = Lbl Then Exit;
  { Ajouter un DW 0 }
  DataAddWord(Lbl, 0);
End;

{ ---- ParseAssign : parser une affectation -------------------- }
{ Appelee quand on a un identifiant suivi de '=' ou op-assign.    }
{ Gere :                                                          }
{   x = expr           (affectation simple)                       }
{   x += expr          (affectation augmentee)                    }
{   a, b = e1, e2      (affectation multiple)                    }
{   a, b = b, a        (echange via pile temporaire)             }
Procedure ParseAssign(FirstSymIdx : Integer);
Var
  Op     : TString;
  RHS    : TExprVal;
  Targets : Array[0..MAX_PARAM - 1] Of Integer;  { indices symboles }
  NTargets : Integer;
  Vals   : Array[0..MAX_PARAM - 1] Of TExprVal;
  NVals  : Integer;
  VName  : TString;
  I, SIdx : Integer;
Begin
  NTargets := 1;
  Targets[0] := FirstSymIdx;

  { Collecter les cibles d affectation multiple : a, b, c = ... }
  While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
  Begin
    ParserAdvance;
    If CurToken.Kind = TK_IDENT Then
    Begin
      VName := CurToken.Val;
      SIdx := SymFind(VName);
      If SIdx < 0 Then
        SIdx := SymAdd(VName, SK_VAR, TY_UNKNOWN, 0);
      If NTargets < MAX_PARAM Then
      Begin
        Targets[NTargets] := SIdx;
        Inc(NTargets);
      End;
      ParserAdvance;
    End
    Else
      Break;
  End;

  { Determiner le type d affectation }
  If (CurToken.Kind = TK_OP) And IsAssignOp(CurToken.Val) Then
  Begin
    Op := CurToken.Val;
    ParserAdvance;

    If Op = '=' Then
    Begin
      { ---- Affectation simple ou multiple ---- }
      If NTargets = 1 Then
      Begin
        { Simple : x = expr }
        EmitComment('assign: ' + SymTab[Targets[0]].Name + ' = expr');
        ParseExpr(RHS);
        ExprFlushToAX(RHS);
        EmitStoreVar(Targets[0]);
      End
      Else
      Begin
        { Multiple : a, b = expr1, expr2 }
        EmitComment('assign multiple: ' + IntToStr_(NTargets) + ' targets');
        NVals := 0;
        For I := 0 To NTargets - 1 Do
        Begin
          If I > 0 Then
          Begin
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
              ParserAdvance;
          End;
          If NVals < MAX_PARAM Then
          Begin
            ParseExpr(Vals[NVals]);
            ExprFlushToAX(Vals[NVals]);
            EmitInstr('PUSH   AX');
            Inc(NVals);
          End;
        End;
        { Stocker en ordre inverse (dernier pousse = premier depile) }
        For I := NVals - 1 DownTo 0 Do
        Begin
          EmitInstr('POP    AX');
          EmitStoreVar(Targets[I]);
        End;
      End;
    End
    Else
    Begin
      { ---- Affectation augmentee : x += expr, x -= expr, etc. ---- }
      EmitComment('augmented assign: ' + SymTab[Targets[0]].Name +
                  ' ' + Op + ' expr');
      { Charger la valeur courante de la variable }
      ExprLoadToAX(Targets[0]);
      EmitInstr('PUSH   AX');
      { Evaluer l expression droite }
      ParseExpr(RHS);
      ExprFlushToAX(RHS);
      EmitInstr('MOV    BX, AX');
      EmitInstr('POP    AX');
      { Appliquer l operateur }
      If      Op = '+='  Then EmitInstr('ADD    AX, BX')
      Else If Op = '-='  Then EmitInstr('SUB    AX, BX')
      Else If Op = '*='  Then EmitInstr('IMUL   BX')
      Else If Op = '//=' Then
      Begin
        EmitInstr('CWD');
        EmitInstr('IDIV   BX');
      End
      Else If Op = '/='  Then
      Begin
        EmitInstr('CWD');
        EmitInstr('IDIV   BX');
      End
      Else If Op = '%='  Then
      Begin
        EmitInstr('CWD');
        EmitInstr('IDIV   BX');
        EmitInstr('MOV    AX, DX');
      End
      Else If Op = '&='  Then EmitInstr('AND    AX, BX')
      Else If Op = '|='  Then EmitInstr('OR     AX, BX')
      Else If Op = '^='  Then EmitInstr('XOR    AX, BX')
      Else If Op = '<<=' Then
      Begin
        EmitInstr('MOV    CX, BX');
        EmitInstr('SHL    AX, CL');
      End
      Else If Op = '>>=' Then
      Begin
        EmitInstr('MOV    CX, BX');
        EmitInstr('SAR    AX, CL');
      End
      Else If Op = '**=' Then
      Begin
        EmitInstr('MOV    CX, BX');
        EmitInstr('CALL   ' + PY_RT_PFX + 'POWER');
      End;
      { Stocker le resultat }
      EmitStoreVar(Targets[0]);
    End;
  End;
End;

{ ============================================================
  TODO 10 - EXPRESSIONS PRIMAIRES [IMPLEMENTE]
  ============================================================ }

{ ---- EmitBuiltinCall : emettre l appel d un builtin ---------- }
{ len(x) -> CALL _PYRT_LEN ; abs(x) -> CALL _PYRT_ABS ; etc.    }
{ L argument est dans AX a l entree ; resultat dans AX.           }
Procedure EmitBuiltinCall(SIdx : Integer; Var Res : TExprVal);
Var
  Name : TString;
Begin
  If (SIdx < 0) Or (SIdx >= SymCount) Then
  Begin
    EmitComment('builtin: unknown');
    ExprMakeAX(TY_IDX_INT, Res);
    Exit;
  End;
  Name := SymTab[SIdx].Name;
  EmitComment('builtin call: ' + Name);

  If Name = 'len' Then
  Begin
    EmitInstr('MOV    SI, AX');
    EmitInstr('CALL   ' + PY_RT_PFX + 'LEN');
    ExprMakeAX(TY_IDX_INT, Res);
  End
  Else If Name = 'abs' Then
  Begin
    { AX = valeur, resultat absolu dans AX }
    EmitInstr('CWD');
    EmitInstr('XOR    AX, DX');
    EmitInstr('SUB    AX, DX');
    ExprMakeAX(TY_IDX_INT, Res);
  End
  Else If Name = 'int' Then
  Begin
    { int(x) : deja entier dans AX pour notre cible 8086 }
    ExprMakeAX(TY_IDX_INT, Res);
  End
  Else If Name = 'str' Then
  Begin
    { str(x) : convertir entier -> chaine via runtime }
    EmitInstr('CALL   ' + PY_RT_PFX + 'INTTOSTR');
    ExprMakeAX(TY_IDX_STR, Res);
  End
  Else If Name = 'chr' Then
  Begin
    { chr(x) : caractere unique - stocker dans buffer }
    EmitInstr('MOV    BYTE PTR [_PY_STRBUF], AL');
    EmitInstr('MOV    BYTE PTR [_PY_STRBUF+1], 0');
    EmitInstr('MOV    AX, OFFSET _PY_STRBUF');
    ExprMakeAX(TY_IDX_STR, Res);
  End
  Else If Name = 'ord' Then
  Begin
    { ord(x) : premier caractere de la chaine -> entier }
    EmitInstr('MOV    SI, AX');
    EmitInstr('XOR    AH, AH');
    EmitInstr('MOV    AL, [SI]');
    ExprMakeAX(TY_IDX_INT, Res);
  End
  Else If Name = 'bool' Then
  Begin
    { bool(x) : 0->0, non-0->1 }
    EmitInstr('TEST   AX, AX');
    EmitInstr('MOV    AX, 0');
    EmitInstr('JZ     $+4');
    EmitInstr('INC    AX');
    ExprMakeAX(TY_IDX_BOOL, Res);
  End
  Else If Name = 'print' Then
  Begin
    { print(x) : appeler le runtime print }
    EmitInstr('CALL   ' + PY_RT_PFX + 'PRINT');
    ExprMakeAX(TY_IDX_NONE, Res);
  End
  Else If Name = 'input' Then
  Begin
    { input() : lire une ligne }
    EmitInstr('CALL   ' + PY_RT_PFX + 'INPUT');
    ExprMakeAX(TY_IDX_STR, Res);
  End
  Else If Name = 'hex' Then
  Begin
    EmitInstr('CALL   ' + PY_RT_PFX + 'TOHEX');
    ExprMakeAX(TY_IDX_STR, Res);
  End
  Else If Name = 'oct' Then
  Begin
    EmitInstr('CALL   ' + PY_RT_PFX + 'TOOCT');
    ExprMakeAX(TY_IDX_STR, Res);
  End
  Else If Name = 'bin' Then
  Begin
    EmitInstr('CALL   ' + PY_RT_PFX + 'TOBIN');
    ExprMakeAX(TY_IDX_STR, Res);
  End
  Else If (Name = 'min') Or (Name = 'max') Then
  Begin
    { min/max(a,b) : AX=premier arg deja pousse, BX disponible }
    { L appelant pousse les args ; on recupere le 2eme depuis BX }
    EmitInstr('POP    BX');  { 2eme argument }
    If Name = 'min' Then
    Begin
      EmitInstr('CMP    AX, BX');
      EmitInstr('JLE    $+4');
      EmitInstr('MOV    AX, BX');
    End
    Else
    Begin
      EmitInstr('CMP    AX, BX');
      EmitInstr('JGE    $+4');
      EmitInstr('MOV    AX, BX');
    End;
    ExprMakeAX(TY_IDX_INT, Res);
  End
  Else
  Begin
    { Appel builtin generique via CALL }
    EmitInstr('CALL   ' + SymTab[SIdx].MangledName);
    ExprMakeAX(SymTab[SIdx].TypeIdx, Res);
  End;
End;

{ ---- ParseCallArgs : parser les arguments d appel ------------ }
{ Appele quand CurToken = '(' apres un identifiant.              }
{ SIdx = indice du symbole de la fonction/builtin dans SymTab.   }
{ Emet PUSH pour chaque argument, puis CALL pour la fonction.    }
Procedure ParseCallArgs(SIdx : Integer; Var Res : TExprVal);
Var
  ArgE     : TExprVal;
  ArgCount : Integer;
  IsBuiltin: Boolean;
Begin
  { Consommer le '(' }
  ParserAdvance;
  ArgCount := 0;

  IsBuiltin := False;
  If (SIdx >= 0) And (SIdx < SymCount) Then
    IsBuiltin := (SymTab[SIdx].Kind = SK_BUILTIN);

  { Parser les arguments separes par des virgules }
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
  Begin
    { Premier argument }
    ParseExpr(ArgE);
    ExprFlushToAX(ArgE);
    EmitInstr('PUSH   AX');
    Inc(ArgCount);
    { Arguments suivants }
    While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
    Begin
      ParserAdvance;
      ParseExpr(ArgE);
      ExprFlushToAX(ArgE);
      EmitInstr('PUSH   AX');
      Inc(ArgCount);
    End;
  End;

  { Consommer le ')' }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance
  Else
    CompileError(''')'' attendue apres arguments', CurToken.Line);

  { Emettre l appel }
  If IsBuiltin Then
  Begin
    { Recuperer le premier argument (ou 0 si aucun) }
    If ArgCount > 0 Then
      EmitInstr('POP    AX')
    Else
      EmitInstr('XOR    AX, AX');
    { Appeler le builtin specifique }
    EmitBuiltinCall(SIdx, Res);
    { Nettoyer les arguments supplementaires }
    If ArgCount > 1 Then
      EmitInstr('ADD    SP, ' + IntToStr_((ArgCount - 1) * 2));
  End
  Else
  Begin
    { Appel de fonction utilisateur : CALL _PYF_func }
    If (SIdx >= 0) And (SIdx < SymCount) Then
    Begin
      EmitComment('call: ' + SymTab[SIdx].Name + ' (' +
                  IntToStr_(ArgCount) + ' args)');
      EmitInstr('CALL   ' + SymTab[SIdx].MangledName);
    End
    Else
    Begin
      EmitComment('call: unknown function');
      EmitInstr('XOR    AX, AX');
    End;
    { Nettoyer la pile des arguments }
    If ArgCount > 0 Then
      EmitInstr('ADD    SP, ' + IntToStr_(ArgCount * 2));
    If (SIdx >= 0) And (SIdx < SymCount) Then
      ExprMakeAX(SymTab[SIdx].TypeIdx, Res)
    Else
      ExprMakeAX(TY_IDX_INT, Res);
  End;
End;

{ ---- ParseListLiteral : [e0, e1, e2, ...] -------------------- }
{ Cree un bloc DK_LIST dans DataTab et remplit les elements.      }
Procedure ParseListLiteral(Var Res : TExprVal);
Var
  ElemE    : TExprVal;
  ElemCount: Integer;
Begin
  EmitComment('list literal');
  { Consommer le '[' }
  ParserAdvance;
  ElemCount := 0;

  { Liste vide : [] }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
  Begin
    ParserAdvance;
    EmitInstr('XOR    AX, AX');
    ExprMakeAX(TY_IDX_LIST, Res);
    Exit;
  End;

  { Allouer le bloc dans le heap : bump allocator }
  EmitInstr('MOV    DI, [_PY_HEAPTOP]');
  EmitInstr('ADD    DI, OFFSET _PY_HEAP');

  { Parser chaque element et stocker dans [DI + 2*i] }
  ParseExpr(ElemE);
  ExprFlushToAX(ElemE);
  EmitInstr('MOV    [DI], AX');
  Inc(ElemCount);
  While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
  Begin
    ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
      Break;  { virgule terminale }
    ParseExpr(ElemE);
    ExprFlushToAX(ElemE);
    EmitInstr('MOV    [DI+' + IntToStr_(ElemCount * 2) + '], AX');
    Inc(ElemCount);
  End;

  { Mettre a jour le HEAPTOP }
  EmitInstr('MOV    AX, ' + IntToStr_(ElemCount * 2));
  EmitInstr('ADD    [_PY_HEAPTOP], AX');
  { Retourner le pointeur vers le bloc }
  EmitInstr('MOV    AX, DI');

  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
    ParserAdvance
  Else
    CompileError(''']'' attendue', CurToken.Line);
  ExprMakeAX(TY_IDX_LIST, Res);
End;

{ ---- ParseDictLiteral : dict literal ------------------------- }
{ Cree un bloc DK_DICT dans le heap et remplit paires cle/val.   }
Procedure ParseDictLiteral(Var Res : TExprVal);
Var
  KeyE, ValE : TExprVal;
  PairCount  : Integer;
Begin
  EmitComment('dict literal');
  { Consommer le '{' }
  ParserAdvance;
  PairCount := 0;

  (* Dict vide : {} *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
  Begin
    ParserAdvance;
    EmitInstr('XOR    AX, AX');
    ExprMakeAX(TY_IDX_DICT, Res);
    Exit;
  End;

  { Allouer dans le heap }
  EmitInstr('MOV    DI, [_PY_HEAPTOP]');
  EmitInstr('ADD    DI, OFFSET _PY_HEAP');

  { Parser paire cle:valeur }
  ParseExpr(KeyE);
  ExprFlushToAX(KeyE);
  EmitInstr('MOV    [DI+' + IntToStr_(PairCount * 4) + '], AX');  { cle }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
    ParserAdvance
  Else
    CompileError(''':'' attendue dans dict literal', CurToken.Line);
  ParseExpr(ValE);
  ExprFlushToAX(ValE);
  EmitInstr('MOV    [DI+' + IntToStr_(PairCount * 4 + 2) + '], AX');  { val }
  Inc(PairCount);

  While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
  Begin
    ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
      Break;  { virgule terminale }
    ParseExpr(KeyE);
    ExprFlushToAX(KeyE);
    EmitInstr('MOV    [DI+' + IntToStr_(PairCount * 4) + '], AX');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      ParserAdvance
    Else
      CompileError(''':'' attendue dans dict literal', CurToken.Line);
    ParseExpr(ValE);
    ExprFlushToAX(ValE);
    EmitInstr('MOV    [DI+' + IntToStr_(PairCount * 4 + 2) + '], AX');
    Inc(PairCount);
  End;

  { Mettre a jour le HEAPTOP }
  EmitInstr('MOV    AX, ' + IntToStr_(PairCount * 4));
  EmitInstr('ADD    [_PY_HEAPTOP], AX');
  { Retourner le pointeur vers le bloc }
  EmitInstr('MOV    AX, DI');

  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
    ParserAdvance
  Else
    CompileError('''}'' attendue', CurToken.Line);
  ExprMakeAX(TY_IDX_DICT, Res);
End;

Procedure Run;
Var
  VarName : TString;
  Idx     : Integer;
Begin
  GlobalInit;
  SymInit;
  TypeInit;
  If Opts.Verbose Then ShowBanner;

  EmitOpen;
  EmitHeader;

  { Point d entree principal }
  EmitComment('-- Point d entree principal --');
  EmitLabel('_PYF_Main');
  EmitInstr('MOV AX,_DATA');
  EmitInstr('MOV DS,AX');
  EmitProlog(0);
  EmitBlankLine;

  LexInit;

  { Lire le premier token }
  ParserAdvance;

  { Boucle principale : parser des expressions (TODO 04+) }
  While CurToken.Kind <> TK_EOF Do
  Begin
    { Sauter les NEWLINE et INDENT/DEDENT entre instructions }
    If (CurToken.Kind = TK_NEWLINE) Or
       (CurToken.Kind = TK_INDENT) Or
       (CurToken.Kind = TK_DEDENT) Then
    Begin
      ParserAdvance;
      Continue;
    End;
    { Instruction global : marquer les variables comme globales }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'global') Then
    Begin
      ParserAdvance;
      While (CurToken.Kind <> TK_EOF) And
            (CurToken.Kind <> TK_NEWLINE) Do
      Begin
        If CurToken.Kind = TK_IDENT Then
        Begin
          VarName := CurToken.Val;
          Idx := SymFind(VarName);
          If Idx < 0 Then
            Idx := SymAdd(VarName, SK_VAR, TY_UNKNOWN, 0);
          If Idx >= 0 Then
            SymTab[Idx].IsGlobal := True;
        End;
        ParserAdvance;
        { Sauter les virgules }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          ParserAdvance;
      End;
      Continue;
    End;
    { Instruction nonlocal : marquer les variables comme nonlocal }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'nonlocal') Then
    Begin
      ParserAdvance;
      While (CurToken.Kind <> TK_EOF) And
            (CurToken.Kind <> TK_NEWLINE) Do
      Begin
        If CurToken.Kind = TK_IDENT Then
        Begin
          VarName := CurToken.Val;
          Idx := SymFind(VarName);
          If Idx < 0 Then
            Idx := SymAdd(VarName, SK_VAR, TY_UNKNOWN, 0);
          If Idx >= 0 Then
            SymTab[Idx].IsNonlocal := True;
        End;
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          ParserAdvance;
      End;
      Continue;
    End;
    { Mots-cles d instruction : stub (TODO 06+) - sauter la ligne }
    If (CurToken.Kind = TK_KEYWORD) And
       (CurToken.Val <> 'True') And (CurToken.Val <> 'False') And
       (CurToken.Val <> 'None') And (CurToken.Val <> 'not') Then
    Begin
      While (CurToken.Kind <> TK_EOF) And
            (CurToken.Kind <> TK_NEWLINE) Do
        ParserAdvance;
      Continue;
    End;
    { Affectation : ident = expr / ident += expr / a, b = e1, e2 (TODO 09) }
    If CurToken.Kind = TK_IDENT Then
    Begin
      VarName := CurToken.Val;
      Idx := SymFind(VarName);
      If Idx < 0 Then
        Idx := SymAdd(VarName, SK_VAR, TY_UNKNOWN, 0);
      ParserAdvance;
      { Detecter affectation simple/augmentee/multiple }
      If ((CurToken.Kind = TK_OP) And IsAssignOp(CurToken.Val)) Or
         ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',')) Then
      Begin
        ParseAssign(Idx);
        { Sauter les NEWLINE apres l affectation }
        If CurToken.Kind = TK_NEWLINE Then
          ParserAdvance;
        Continue;
      End
      Else
      Begin
        { Pas une affectation : c est une expression commencant par ident }
        { L identifiant est deja consomme, il faut le traiter }
        { On construit un EK_MEM pour le symbole et on continue le parseur }
        GExprDummy.Kind    := EK_MEM;
        GExprDummy.TypeIdx := SymTab[Idx].TypeIdx;
        GExprDummy.Offset  := SymTab[Idx].Offset;
        GExprDummy.SymIdx  := Idx;
        GExprDummy.ImmVal  := 0;
        { Appel de fonction : f(args) (TODO 10) }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          ParseCallArgs(Idx, GExprDummy);
        { Si un operateur binaire suit, continuer le parsing }
        If (CurToken.Kind = TK_OP) And (BinOpPrec(CurToken.Val) > 0) Then
        Begin
          ExprFlushToAX(GExprDummy);
          { Continuer avec ParseExprPrec en utilisant le resultat courant }
          { On reparse depuis la boucle precedente }
        End;
      End;
    End
    Else
    Begin
      { Parser une expression }
      ParseExpr(GExprDummy);
    End;
    { Garde de securite : si le token n a pas avance, forcer }
    If (CurToken.Kind <> TK_EOF) And
       (CurToken.Kind <> TK_NEWLINE) Then
      ParserAdvance;
    { Sauter les NEWLINE apres l expression }
    If CurToken.Kind = TK_NEWLINE Then
      ParserAdvance;
  End;

  LexClose;

  { Epilogue et sortie DOS }
  EmitBlankLine;
  EmitComment('-- Fin du programme --');
  EmitEpilog;
  EmitInstr('MOV AX,4C00h');
  EmitInstr('INT 21h');

  EmitClose;

  If Opts.Verbose Then ShowStats;

  Cleanup;

  If ErrorCount > 0 Then
    Halt(EXIT_ERROR)
  Else
    Halt(EXIT_OK);
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Begin
  ParseArgs;
  Run;
End.
