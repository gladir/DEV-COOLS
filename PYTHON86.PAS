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

  TODO 01 - INFRASTRUCTURE ET OPTIONS
            TOptions (SrcFile, OutFile, Verbose, DebugMode)
            ParseArgs : analyser argv (source.py [sortie.asm] [-v] [-d])
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .py du fichier source
            Programme principal : validation des arguments et appel Run
            Version, Date, aide en ligne (option -h)

  TODO 02 - LEXEUR (TOKENS PYTHON)
            TTokenKind : TK_EOF, TK_NEWLINE, TK_INDENT, TK_DEDENT,
              TK_INTEGER, TK_STRING, TK_IDENT, TK_KEYWORD, TK_OP, TK_PUNCT
            LexInit, LexClose, LexNextToken, LexScanIdent, LexScanNumber
            LexScanString : chaines entre guillemets simples 'abc'
              ou doubles "abc", triples '''...''' ou """..."""
              Sequences d echappement : \n \t \r \\ \' \" \xNN
            Commentaires : # jusqu a fin de ligne
            Gestion de l indentation : pile d indentation (stack),
              emettre TK_INDENT quand le niveau augmente,
              emettre TK_DEDENT quand le niveau diminue
            Mots-cles : False None True and as assert async await
              break class continue def del elif else except
              finally for from global if import in is lambda
              not or pass raise return try while with yield
            Mode debug -d : affichage de chaque token avec PrintToken

  TODO 03 - LITTERAUX ET CONSTANTES
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

  TODO 04 - OPERATEURS ET PRECEDENCE
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

  TODO 05 - TABLE DES SYMBOLES
            TSymKind : SK_VAR, SK_PARAM, SK_FUNC, SK_CLASS, SK_MODULE,
              SK_BUILTIN, SK_GLOBAL, SK_LOCAL
            TSymRec : Name, MangledName, Kind, TypeIdx, Offset,
              Scope, IsGlobal
            SymAdd, SymFind, SymFindInScope, SymMangle
            CurScope : compteur de portee imbriquee (max MAX_SCOPE)
            SymEnterScope / SymLeaveScope : gestion des portees imbriquees
            Resolution des noms : local -> englobant -> global -> builtins
            Instruction global : marquer une variable comme globale
            Instruction nonlocal : marquer une variable de portee englobante

  TODO 06 - SYSTEME DE TYPES DYNAMIQUE
            TTypeKind : TYK_INT (16 bits signe), TYK_BOOL (8 bits),
              TYK_STR (ptr chaine), TYK_NONE (nul),
              TYK_LIST (ptr tableau dynamique), TYK_DICT (ptr table de hachage),
              TYK_TUPLE (ptr tableau fixe), TYK_FUNC (ptr de code),
              TYK_OBJECT (ptr instance de classe), TYK_CLASS (descripteur)
            Typage dynamique simplifie : le compilateur infere un type
              statique quand c est possible (entier, chaine, None)
            Verification de type a l execution pour les cas ambigus
            TypeTab, TypeInit : enregistrer les types primitifs
            TypeSizeof : INT=2, BOOL=1, STR=2(ptr), LIST=2(ptr), DICT=2(ptr)
            isinstance(obj, cls) : verification de type -> AX=0|1
            type(obj) : retourner le descripteur de type -> AX=idx

  TODO 07 - EMETTEUR DE CODE ASM
            TEmitter : OutF (Text), OutFOpen, EmitOpen, EmitClose
            EmitRaw, EmitLabel, EmitInstr (formatage 8 espaces)
            EmitComment, EmitBlankLine
            LabelGen global (compteur unique _PYL_NNNNN)
            Prefixes : _PYV_ (variable), _PYF_ (fonction), _PYK_ (chaine const),
              _PYRT_ (runtime), _PYL_ (label), _PYC_ (classe/vtable),
              _PYM_ (methode)
            EmitHeader : .MODEL SMALL / .STACK 1024 / _TEXT SEGMENT
            EmitProlog / EmitEpilog : PUSH BP / MOV BP,SP et MOV SP,BP / POP BP
            EmitDataSeg : ecrire _DATA SEGMENT ... _DATA ENDS

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES
            TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR/DK_LIST/DK_DICT),
              IntVal, StrVal, ElemCount
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr, DataAddList : variantes d ajout
            Variables globales : entrees DK_WORD dans DATA
            Chaines litterales : DB 'abc',0 dans DATA avec label _PYK_N
            Listes litterales : suite de DW dans DATA pour les elements
            Dictionnaires litteraux : paires cle/valeur dans DATA
            Heap statique : _PY_HEAP DB 4096 DUP(0) + _PY_HEAPTOP DW 0

  TODO 09 - VARIABLES ET AFFECTATIONS
            Variables globales : segment DATA, acces par label _PYV_nom
            Variables locales : pile BP, acces [BP-offset]
            Parametres de fonction : pile BP, acces [BP+offset]
            Affectation simple : x = expr -> ExprLoad + MOV destination, AX
            Affectation augmentee : x += expr -> charger x, evaluer expr,
              ADD AX, resultat, stocker
            Affectation multiple : a, b = expr1, expr2 -> evaluer puis stocker
            Echange : a, b = b, a -> via registre ou pile temporaire
            Unpacking simple : a, b, c = liste -> extraire elements

  TODO 10 - EXPRESSIONS PRIMAIRES
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

Begin
End.
