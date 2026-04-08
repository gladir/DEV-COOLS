{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 0.1
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Compilateur Python vers assembleur 80386 pour Windows 32 bits
  @license: MIT
}

(* ============================================================
  PYTHCW32.PAS - Compilateur Python vers assembleur
  80386 pour Windows 32 bits
  Free Pascal (-Mtp)
  Cible : MASM .386 / .MODEL FLAT, PE Win32

  Par defaut produit un fichier .EXE (PE Windows 32 bits).
  Avec le parametre -obj, produit uniquement un fichier .OBJ (COFF).
  Avec le parametre -asm, produit egalement un fichier .ASM lisible.
  Supporte toutes les exemples SAMPLES\PYTHON\*

  Voir DOC/TODO/PYTHCW32.txt pour la feuille de route complete.

  TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES PE/COFF [A FAIRE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings,
              EmitExe, EmitObj, EmitAsm)
            ParseArgs : analyser argv (source.py [-o sortie] [-v]
              [-d] [-w] [-obj] [-asm] [-h])
            Par defaut : produire un .EXE Windows 32 bits (PE)
            -obj : produire uniquement un .OBJ (format COFF 32 bits)
            -asm : produire egalement un listing assembleur .ASM lisible
            -o nom : specifier le nom du fichier de sortie
            FatalError, CompileError, WarnMsg
            EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .py du fichier source
            Version, Date, aide en ligne (option -h)
            ShowBanner, ShowUsage, ShowStats
            Constantes PE/COFF : PE_DOS_MAGIC ($5A4D), PE_PE_SIG,
              PE_MACHINE_I386, PE_OPT_SIZE, PE_MAGIC_32,
              PE_IMG_BASE ($00400000), PE_SEC_ALIGN (4096),
              PE_FILE_ALIGN (512), PE_SUBSYS_CUI (console)
            Constantes binaires : MAX_BIN_CODE (65536),
              MAX_BIN_DATA (65536), MAX_BIN_LBL (4096),
              MAX_BIN_FIX (8192)
            Limites internes (32 bits) : MAX_SYM=4096, MAX_LABEL=4096,
              MAX_SCOPE=64, MAX_DATA=512, MAX_PARAM=64,
              MAX_LOOP_NEST=32, MAX_TRY_NEST=16, MAX_ERRORS=30,
              MAX_STR=255, MAX_INDENT=64, MAX_DEDENT_Q=32,
              MAX_HASH_PAIRS=64, MAX_CLASS=64, MAX_CLS_ATTR=32,
              MAX_CLS_METH=32, MAX_IMPORT=32, MAX_COMP_BUF=64
            Prefixes de nommage ASM : _PYV_ (variable globale),
              _PYF_ (fonction def), _PYK_ (constante chaine),
              _PYRT_ (routine runtime), _PYL_ (label interne),
              _PYC_ (classe/vtable), _PYM_ (methode)
            Utilitaires : ItoS, UpCaseStr, StrLowerCase, BaseName,
              ReplaceExt, AsmIdent
            10 fonctions accesseurs

  TODO 02 - TOKENISEUR PYTHON (LEXER) [A FAIRE]
            Procedure LexInit : ouvrir le fichier source, initialiser
              l etat du lexeur (ligne, colonne, caractere courant)
            Procedure LexClose : fermer le fichier source
            Procedure LexNextChar / LexPeekChar
            Format libre avec indentation significative
            Commentaires Python : # jusqu a fin de ligne
            Procedure LexNextToken : reconnaitre les tokens Python :
              - Identificateurs : lettres, chiffres, souligne (_)
                Python est sensible a la casse
              - Litteraux entiers : 123, 0xFF, 0o77, 0b1010, 1_000
              - Litteraux flottants : 1.5, 3.14
              - Litteraux chaines : 'texte' ou "texte",
                triples '''...''' ou """..."""
                Prefixes : r (raw), b (bytes)
                Sequences d echappement : \n \t \r \\ \' \" \xNN
              - Operateurs : + - * / // % ** = == != < <= > >=
                & | ^ ~ << >> += -= *= //= %= **= &= |= ^= <<= >>=
              - Separateurs : ( ) [ ] { } , : ; . @
            Types de tokens (TK_EOF, TK_NEWLINE, TK_INDENT, TK_DEDENT,
              TK_INTEGER, TK_FLOAT, TK_STRING, TK_IDENT, TK_KEYWORD,
              TK_OP, TK_PUNCT, TK_COLON, TK_LBRACKET, TK_RBRACKET,
              TK_LBRACE, TK_RBRACE, TK_DOT, TK_AT, TK_ARROW)
            Stocker dans CurTokKind / CurTokStr / CurTokInt
            Gestion de l indentation : pile d indentation (stack),
              emettre TK_INDENT quand le niveau augmente,
              emettre TK_DEDENT quand le niveau diminue
            LexScanIdent, LexScanNumber, LexScanString, LexScanEscChar
            Gestion des lignes et numeros de ligne pour diagnostics
            ParserAdvance : lire token suivant avec PrintToken si -d
            10 fonctions accesseurs

  TODO 03 - RECONNAISSANCE DES MOTS-CLES PYTHON [A FAIRE]
            Tous les mots reserves Python 3 :
              Constantes : False, None, True
              Logiques : and, or, not
              Controle : if, elif, else, while, for, break,
                continue, pass, return, yield
              Definitions : def, class, lambda
              Exceptions : try, except, finally, raise, assert
              Importation : import, from, as
              Portee : global, nonlocal
              Operations : in, is, del, with
              Asynchrone : async, await (reserve mais non supporte)
            LookupKeyword : retourner KW_xxx ou TK_IDENT
            Constantes KW_FALSE..KW_YIELD pour chaque mot-cle
            Builtins reconnus comme identificateurs speciaux :
              print, input, len, str, int, float, bool, list,
              dict, tuple, range, abs, ord, chr, hex, oct, bin,
              type, isinstance, min, max, pow, round, sorted,
              reversed, enumerate, zip, map, filter, sum, any,
              all, hasattr, getattr, setattr, id, hash, repr, open
            10 fonctions accesseurs

  TODO 04 - TABLE DES SYMBOLES PYTHON (32 BITS) [A FAIRE]
            Enregistrement TSymRec :
              Name      : nom Python (x, my_func, MyClass)
              AsmName   : label ASM correspondant (_PYV_x, _PYF_my_func)
              Kind      : type de symbole (SK_VAR, SK_PARAM, SK_FUNC,
                SK_CLASS, SK_MODULE, SK_BUILTIN, SK_GLOBAL, SK_LOCAL)
              TypeIdx   : indice dans la table des types
              Offset    : offset dans le segment de donnees ou la pile
              ScopeLevel: niveau de portee imbrique
              IsGlobal  : True si declare avec instruction global
              IsNonlocal: True si declare avec instruction nonlocal
              IsImported: True si importe depuis un autre module
              DeclLine  : numero de ligne de declaration
            Procedures sur la table :
              SymInit, SymAdd, SymFind, SymFindInScope,
              SymCount, SymDump, SymNameClean, SymMangle
            Gestion de la portee : globale, locale (fonctions), classe
            CurScope : compteur de portee imbriquee (max MAX_SCOPE)
            ScopeStack / ScopeTop : pile pour SymEnterScope / SymLeaveScope
            Resolution des noms : local -> englobant -> global -> builtins
            Instruction global : marquer une variable comme globale
            Instruction nonlocal : marquer une variable de portee englobante
            10 fonctions accesseurs

  TODO 05 - SYSTEME DE TYPES DYNAMIQUE [A FAIRE]
            TTypeKind : TYK_INT (32 bits signe), TYK_BOOL (32 bits),
              TYK_STR (ptr chaine), TYK_NONE (nul),
              TYK_LIST (ptr tableau dynamique),
              TYK_DICT (ptr table de hachage),
              TYK_TUPLE (ptr tableau fixe), TYK_FUNC (ptr de code),
              TYK_OBJECT (ptr instance de classe),
              TYK_CLASS (descripteur de classe)
            TTypeRec : Name, Kind, Size
            TypeTab[MAX_TYPE], TypeCount
            Indices de types primitifs :
              TY_IDX_INT=0, TY_IDX_STR=1, TY_IDX_BOOL=2,
              TY_IDX_NONE=3, TY_IDX_LIST=4, TY_IDX_DICT=5,
              TY_IDX_FUNC=6, TY_IDX_CLASS=7, TY_IDX_TUPLE=8,
              TY_IDX_MODULE=9
            TypeInit : enregistrer les 10 types primitifs Python
            TypeKindOf(idx) : retourner le TTypeKind pour un indice
            TypeSizeOf(idx) : INT=4, BOOL=4, STR=4(ptr), LIST=4(ptr),
              DICT=4(ptr), TUPLE=4(ptr), FUNC=4(ptr), OBJECT=4(ptr),
              CLASS=4(ptr), NONE=0
            TypeFindByName(name) : rechercher un type par nom -> index
            TypeKindStr(kind) : nom textuel d un TTypeKind
            Typage dynamique simplifie : le compilateur infere un type
              statique quand c est possible (entier, chaine, None)
            isinstance(obj, cls) : verification de type -> EAX=0|1
            type(obj) : retourner le descripteur de type -> EAX=idx
            10 fonctions accesseurs

  TODO 06 - LITTERAUX ET CONSTANTES [A FAIRE]
            Entiers decimaux : 0..2147483647 (32 bits signe)
            Entiers hexadecimaux : 0xFF, octaux : 0o77, binaires : 0b1010
            Separateur de chiffres : 1_000_000 (ignore le souligne)
            Flottants : reconnus par le lexeur, tronques en entiers
            Chaines : 'abc' ou "abc" -> pointeur vers donnees DATA
              Chaines brutes r'...' ou r"..." (pas d echappement)
              Chaines triples '''...''' ou """...""" (multi-lignes)
              Prefixe b'...' (bytes) traite comme chaine normale
            None : constante speciale -> EAX=0
            True : constante booleenne -> EAX=1
            False : constante booleenne -> EAX=0
            TExprKind : EK_NONE, EK_IMM, EK_EAX, EK_MEM
            TExprVal : Kind, ImmVal, TypeIdx, Offset, SymIdx
            TDataKind : DK_DWORD, DK_BYTE, DK_STR, DK_ARRAY_BLK
            TDataRec : LblName, Kind, IntVal, StrVal, ElemCount
            DataAdd, DataAddStr, DataAddDWord : gestion du segment DATA
            ExprMakeImm, ExprMakeNone, ExprMakeBool, ExprMakeEAX
            LitEvalInt, LitEvalStr, LitEval
            LabelGen : generateur de labels uniques _PYL_N
            10 fonctions accesseurs

  TODO 07 - OPERATEURS ET PRECEDENCE [A FAIRE]
            Arithmetiques : + - * // % ** (// = division entiere,
              ** = puissance, / traite comme //)
            Comparaison : == != < <= > >= (chaines et entiers)
            Logiques : and or not (court-circuit, valeurs truthy/falsy)
            Bit a bit : & | ^ ~ << >> (AND, OR, XOR, NOT, decalages)
            Appartenance : in, not in (element dans liste/str/dict)
            Identite : is, is not (comparaison de references)
            Affectation : = += -= *= //= %= **= &= |= ^= <<= >>=
            Unaire : + - ~ not
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
            ParsePrimary, ParseUnary, ParseExprPrec, ParseExpr
            ExprFlushToEAX, ExprEmitBinOp
            Pliage de constantes pour expressions statiques
            10 fonctions accesseurs

  TODO 08 - PARSEUR : EXPRESSIONS PRIMAIRES ET APPELS [A FAIRE]
            ParsePrimary : literal entier, literal chaine, ident,
              appel de fonction, None, True, False
            Acces attribut : expr.attr -> offset dans instance de classe
            Acces index : expr[i] -> appel selon type (list/str/dict)
              Index negatif : expr[-1] -> len + index
            Acces slice : expr[a:b] -> appel _PYRT_SLICE
            Appel de fonction : func(args) ->
              PUSH args droite a gauche + CALL _PYF_func
              + ADD ESP, args_size
            Appel de methode : obj.method(args) ->
              PUSH self + PUSH args + CALL _PYM_cls_method
              + ADD ESP, (1+args)*4
            Parentheses : (expr) -> regroupement de priorite
            Liste literale : [e0, e1, e2] -> allocation + remplissage
            Tuple literal : (e0, e1, e2) -> allocation + remplissage
            Dict literal : {k0:v0, k1:v1} -> allocation + remplissage
            Builtins inline : len(x), abs(x), int(x), str(x),
              chr(x), ord(x), bool(x), type(x), isinstance(x, cls)
            10 fonctions accesseurs

  TODO 09 - PARSEUR : VARIABLES ET AFFECTATIONS [A FAIRE]
            Variables globales : segment DATA, acces par label _PYV_nom
              MOV EAX, DWORD [_PYV_nom] pour lecture
              MOV DWORD [_PYV_nom], EAX pour ecriture
            Variables locales : pile EBP, acces [EBP-offset]
            Parametres de fonction : pile EBP, acces [EBP+offset]
            Affectation simple : x = expr ->
              evaluer expr + MOV destination, EAX
            Affectation augmentee : x += expr -> charger x,
              evaluer expr, ADD EAX, resultat, stocker
              Supportees : += -= *= //= %= **= &= |= ^= <<= >>=
            Affectation multiple : a, b = expr1, expr2 ->
              evaluer puis stocker
            Echange : a, b = b, a -> via registre ou pile temporaire
            Unpacking simple : a, b, c = iterable ->
              extraire elements sequentiellement
            Instruction del : del x / del lst[i] / del d[key]
            Instruction global : marquer variable comme globale
            Instruction nonlocal : marquer variable de portee englobante
            EnsureVarInData : auto-declarer variable globale dans DATA
            10 fonctions accesseurs

  TODO 10 - PARSEUR : IF / ELIF / ELSE [A FAIRE]
            ParseIfStmt : if cond: bloc {elif cond: bloc} [else: bloc]
              Gestion de l indentation pour delimiter les blocs
              Emission : evaluer cond -> TEST EAX, EAX / JZ label
              Labels : _PYL_ELIF_N, _PYL_ELSE_N, _PYL_ENDIF_N
            Expressions conditionnelles (ternaire) :
              val = a if cond else b
              Emission : evaluer cond, JZ vers else-branch,
                evaluer a, JMP fin, label else, evaluer b, label fin
            Instruction pass : ne generer aucun code (NOP optionnel)
            Valeurs truthy/falsy : 0, None, '', [] sont falsy,
              tout le reste est truthy -> TEST EAX, EAX
            Conditions composees : and/or avec court-circuit
            10 fonctions accesseurs

  TODO 11 - PARSEUR : BOUCLES while / for / break / continue [A FAIRE]
            ParseWhileStmt : while cond: bloc [else: bloc]
              Labels : _PYL_WTEST_N, _PYL_WEND_N, _PYL_WELSE_N
              Emission : _PYL_WTEST_N: evaluer cond, JZ _PYL_WEND_N,
                corps, JMP _PYL_WTEST_N, _PYL_WEND_N:
            ParseForStmt : for var in iterable: bloc [else: bloc]
              for i in range(n) : boucle comptee 0..n-1
                MOV DWORD [var], 0 / _PYL_FTEST: CMP / JGE end /
                corps / INC DWORD [var] / JMP test
              for i in range(a, b) : boucle comptee a..b-1
              for i in range(a, b, step) : boucle avec pas
              for ch in string : iterer sur les caracteres
              for elem in list : iterer sur les elements
              Labels : _PYL_FTEST_N, _PYL_FINCR_N, _PYL_FEND_N
            break : JMP _PYL_WEND_N ou _PYL_FEND_N
            continue : JMP _PYL_WTEST_N ou _PYL_FINCR_N
            LoopPush / LoopPop : pile de labels pour break/continue
            Boucles imbriquees supportees (MAX_LOOP_NEST)
            10 fonctions accesseurs

  TODO 12 - PARSEUR : FONCTIONS (def) ET RETURN [A FAIRE]
            ParseDefStmt : def nom(params): bloc
            Parametres positionnels : passage par valeur sur la pile
            Parametres par defaut : def f(a, b=10):
              si argument manquant a l appel, empiler la valeur par defaut
            Convention d appel 80386 :
              Parametres empiles de droite a gauche (cdecl)
              Valeur de retour dans EAX
              L appelant nettoie la pile apres CALL
            Prologue : PUSH EBP / MOV EBP, ESP / SUB ESP, locals_size
              Variables locales accessibles via [EBP-offset]
              Parametres accessibles via [EBP+8], [EBP+12], ...
            Epilogue : MOV ESP, EBP / POP EBP / RET
            return expr : MOV EAX, valeur + JMP vers epilogue
            return sans valeur : XOR EAX, EAX (None=0) + JMP epilogue
            Recursion : supportee naturellement via la pile
            Fonctions imbriquees : non supportees (avertissement)
            Appel : PUSH args + CALL _PYF_nom + ADD ESP, n*4
            10 fonctions accesseurs

  TODO 13 - PARSEUR : ENTREES/SORTIES (print / input) [A FAIRE]
            print(*args, sep=' ', end='\n') :
              Evaluer chaque argument, convertir en chaine si necessaire
              Appeler _PYRT_WRITESTR pour chaque argument
              Inserer le separateur (espace par defaut) entre les args
              Ajouter le terminateur (CR+LF par defaut)
            print(n) avec entier : CALL _PYRT_ITOA + _PYRT_WRITESTR
            print(s) avec chaine : _PYRT_WRITESTR directement
            print(True/False) : ecrire 'True' ou 'False'
            print(None) : ecrire 'None'
            input([prompt]) :
              Afficher le prompt si present via _PYRT_WRITESTR
              Lire une ligne depuis STDIN via _PYRT_READLINE
              Retourner un pointeur vers la chaine lue -> EAX=ptr
            int(input()) : _PYRT_READLINE + _PYRT_ATOI -> EAX
            Fonctions de conversion affichables :
              hex(n), oct(n), bin(n) -> chaine formatee
            Win32 API pour les E/S console :
              GetStdHandle(STD_OUTPUT_HANDLE) pour ecriture
              GetStdHandle(STD_INPUT_HANDLE) pour lecture
              WriteFile pour l affichage
              ReadFile pour la saisie
            10 fonctions accesseurs

  TODO 14 - PARSEUR : LISTES (list) [A FAIRE]
            Liste vide : [] -> allocation d un bloc vide sur le heap
            Liste literale : [e0, e1, e2] -> allocation + stockage DD
              par element (chaque element est un DWORD 32 bits)
            Acces par index : lst[i] ->
              calcul offset + MOV EAX, [EBX+4+i*4]
              Index negatif : lst[-1] -> len + index
            Affectation par index : lst[i] = val ->
              MOV [EBX+4+i*4], EAX
            Slice : lst[a:b] -> CALL _PYRT_LISTSLICE -> EAX=ptr
            len(lst) : MOV EAX, [EBX] (compteur en tete de liste)
            lst.append(val) : CALL _PYRT_LISTAPPEND(ESI=lst, EAX=val)
            lst.pop() : CALL _PYRT_LISTPOP(ESI=lst) -> EAX=element
            Concatenation : lst1 + lst2 ->
              CALL _PYRT_LISTCONCAT -> EAX=ptr
            Repetition : lst * n -> CALL _PYRT_LISTMUL -> EAX=ptr
            Operateur in : val in lst ->
              CALL _PYRT_LISTCONTAINS -> EAX=0|1
            Layout memoire : [count DD][elem0 DD][elem1 DD]...
            Iteration for : acces sequentiel aux elements
            10 fonctions accesseurs

  TODO 15 - PARSEUR : DICTIONNAIRES (dict) [A FAIRE]
            Dict vide : {} -> allocation d une table de hachage vide
            Dict literal : {k0:v0, k1:v1} -> allocation + insertion
              des paires cle/valeur
            Acces par cle : d[key] ->
              CALL _PYRT_DICTGET(ESI=dict, EAX=key) -> EAX=val
              KeyError si cle absente -> _PYRT_PANIC
            Affectation par cle : d[key] = val ->
              CALL _PYRT_DICTSET(ESI=dict, EAX=key, EBX=val)
            d.get(key, default) : CALL _PYRT_DICTGETDEF -> EAX
            key in d : CALL _PYRT_DICTCONTAINS -> EAX=0|1
            len(d) : nombre de paires -> EAX
            d.keys() : retourner une liste des cles
            d.values() : retourner une liste des valeurs
            del d[key] : CALL _PYRT_DICTDEL(ESI=dict, EAX=key)
            Boucle for k in d : iterer sur les cles du dictionnaire
            Table de hachage interne : MAX_HASH_PAIRS paires par dict
            Layout memoire : [count DD][pairs...] avec paires
              [key DD][val DD]
            10 fonctions accesseurs

  TODO 16 - PARSEUR : TUPLES ET UNPACKING [A FAIRE]
            Tuple vide : () -> pointeur vers zone vide
            Tuple literal : (e0, e1, e2) -> allocation + stockage DD
              par element
            Tuple singleton : (e0,) -> virgule finale distingue
              du parenthesage
            Acces par index : tup[i] ->
              calcul offset + MOV EAX, [EBX+4+i*4]
              Index negatif : tup[-1] -> len + index
            Tuples immuables : pas d affectation par index
              (erreur de compilation)
            len(tup) : MOV EAX, [EBX] (compteur en tete)
            Unpacking : a, b, c = tup -> extraire chaque element
              vers variable
            Unpacking dans for : for a, b in list_of_tuples
            Concatenation : tup1 + tup2 ->
              CALL _PYRT_TUPLECONCAT -> EAX=ptr
            Repetition : tup * n -> CALL _PYRT_TUPLEMUL -> EAX=ptr
            Operateur in : val in tup ->
              CALL _PYRT_TUPLECONTAINS -> EAX=0|1
            Layout identique aux listes : [count DD][elem0 DD]...
            10 fonctions accesseurs

  TODO 17 - PARSEUR : CHAINES (str) OPERATIONS AVANCEES [A FAIRE]
            Concatenation : s1 + s2 ->
              CALL _PYRT_STRCONCAT -> EAX=ptr
            Repetition : s * n -> CALL _PYRT_STRMUL -> EAX=ptr
            Acces par index : s[i] -> MOVZX EAX, BYTE [ESI+i]
            Slice : s[a:b] -> CALL _PYRT_STRSLICE -> EAX=ptr
            len(s) : CALL _PYRT_STRLEN(ESI=str) -> EAX
            s.find(sub) : CALL _PYRT_STRFIND -> EAX=index ou -1
            s.upper() / s.lower() :
              CALL _PYRT_STRUPPER / _PYRT_STRLOWER -> EAX=ptr
            s.strip() : CALL _PYRT_STRSTRIP -> EAX=ptr
            s.replace(old, new) :
              CALL _PYRT_STRREPLACE -> EAX=ptr
            s.startswith(prefix) / s.endswith(suffix) -> EAX=0|1
            s.count(sub) : CALL _PYRT_STRCOUNT -> EAX
            chr(n) : entier -> caractere -> EAX=ptr chaine 1 octet
            ord(c) : caractere -> entier -> MOVZX EAX, BYTE [ptr]
            Operateur in : sub in s ->
              CALL _PYRT_STRCONTAINS -> EAX=0|1
            Comparaison : CALL _PYRT_STRCMP -> drapeaux ZF/CF
            10 fonctions accesseurs

  TODO 18 - PARSEUR : CLASSES ET OBJETS [A FAIRE]
            ParseClassStmt : class Nom: bloc
              ou class Nom(Parent): bloc
            Attributs d instance : stockes dans un bloc sur le heap
              Layout objet : [typecode DD][attr0 DD][attr1 DD]...
              Acces : self.attr ->
                MOV EBX, [EBP+8] / MOV EAX, [EBX+4+offset*4]
            Methodes : def methode(self, ...): bloc
              self est le premier parametre (pointeur vers instance)
              Label : _PYM_ClassName_method
            Constructeur __init__(self, ...):
              initialisation des attributs de l instance
            Allocation : Nom(args) ->
              CALL _PYRT_OBJNEW(ECX=taille)
              + CALL _PYM_ClassName___init__ -> EAX=ptr instance
            Heritage simple : class Enfant(Parent):
              Copie des attributs du parent + ajout des nouveaux
            Appel de methode : obj.method(args) ->
              PUSH self + PUSH args + CALL _PYM_cls_method
              + ADD ESP, (1+nargs)*4
            isinstance(obj, cls) : comparaison du typecode -> EAX=0|1
            Table des classes : MAX_CLASS entrees avec
              attributs et methodes
            10 fonctions accesseurs

  TODO 19 - PARSEUR : EXCEPTIONS (try / except / finally / raise) [A FAIRE]
            ParseTryStmt : try: bloc except [Type [as var]]: bloc
              [else: bloc] [finally: bloc]
            try: bloc -> sauvegarder handler courant, installer nouveau
            except ExceptionType: bloc -> label _PYL_EXCEPT_N,
              CMP code exception
            except ExceptionType as e: bloc ->
              stocker le message dans variable e
            except: bloc -> handler generique (attrape tout)
            else: bloc -> execute si aucune exception levee
            finally: bloc -> toujours execute (_PYL_FINALLY_N)
            raise ExceptionType(msg) : lever une exception
              EAX = code exception, EBX = ptr message
            raise sans argument : relever l exception courante
            Mecanisme d exceptions sans support OS :
              _PYX_HANDLER DD 0 dans DATA (ptr vers handler courant)
              _PYX_CODE DD 0 (code d exception actif)
              _PYX_MSG DD 0 (ptr message d exception)
            TRY : sauvegarder ancien handler, installer nouveau label
            EXCEPT : tester le code, router vers le bon handler
            FINALLY : toujours execute, puis restaurer handler
            RAISE sans handler : afficher 'Unhandled exception'
              + PUSH 1 / CALL ExitProcess
            Pile de try imbriques (MAX_TRY_NEST)
            10 fonctions accesseurs

  TODO 20 - PARSEUR : COMPREHENSIONS ET IMPORT [A FAIRE]
            List comprehension : [expr for var in iterable]
              -> allocation liste, boucle for, evaluer expr, append
            List comprehension avec filtre :
              [expr for var in iterable if cond]
              -> ajout d un test conditionnel dans la boucle
            Dict comprehension : {kexpr:vexpr for var in iterable}
              -> allocation dict, boucle for, evaluer paire, dictset
            Dict comprehension avec filtre :
              {k:v for var in iterable if cond}
            Generateurs : non supportes (avertissement a la compilation)
            Set comprehension : non supporte (avertissement)
            import module : importer un module Python externe
              Mecanisme simplifie : modules declares comme externes
            from module import nom : importation selective
              Ajouter le symbole dans la table avec IsImported=True
            Module math : abs, pow -> builtins ou runtime
            Module sys : sys.exit(code) ->
              PUSH code / CALL _ExitProcess@4
            Module os : non supporte (avertissement)
            Gestion des chemins d import : non supportee
            Tables d importation/exportation : symboles EXTRN/PUBLIC
            10 fonctions accesseurs

  TODO 21 - GENERATION DE CODE : SEGMENT DE DONNEES 80386 [A FAIRE]
            Section .data (variables initialisees) :
              Variable int : _PYV_nom DD 0
              Variable str : _PYV_nom DD _PYK_N (pointeur chaine)
              Variable bool : _PYV_nom DD 0
              Variable None : _PYV_nom DD 0
            Constantes chaines :
              _PYK_N DB 'texte', 0 (NUL-terminated)
            Constantes de format pour print :
              _PYK_FMT_N DB 'format...', 0
            Constantes speciales :
              _PYK_TRUE DB 'True', 0
              _PYK_FALSE DB 'False', 0
              _PYK_NONE DB 'None', 0
              _PYK_CRLF DB 13, 10, 0
              _PYK_SPACE DB ' ', 0
            Section .data? (BSS - variables non initialisees) :
              _PY_IOBUF DB 256 DUP(?)
              _PY_NUMBUF DB 32 DUP(?)
            Variables runtime :
              _PY_STDOUT DD ?  (handle console sortie)
              _PY_STDIN  DD ?  (handle console entree)
              _PY_WRITTEN DD ? (octets ecrits par WriteFile)
              _PY_READ   DD ?  (octets lus par ReadFile)
            Heap dynamique :
              _PY_HEAP DB 65536 DUP(0)
              _PY_HEAPTOP DD 0
            Listes/tuples/dicts dans DATA : blocs de DD
            Alignement des donnees sur 4 octets (DWORD)
            10 fonctions accesseurs

  TODO 22 - BIBLIOTHEQUE RUNTIME PYTHON (E/S, CONVERSIONS VIA WIN32) [A FAIRE]
            Routines de conversion :
              _PYRT_ITOA : entier 32 bits -> chaine decimale ASCII
                Utilisation de DIV par 10 en boucle
              _PYRT_ATOI : chaine ASCII -> entier 32 bits
                Utilisation de IMUL par 10 et ADD
              _PYRT_BOOLTOSTR : 0 -> 'False', <>0 -> 'True'
              _PYRT_NONETOSTR : -> 'None'
            Routines d E/S console :
              _PYRT_INITIO : initialiser les handles console
                PUSH STD_OUTPUT_HANDLE / CALL GetStdHandle
                MOV [_PY_STDOUT], EAX
                PUSH STD_INPUT_HANDLE / CALL GetStdHandle
                MOV [_PY_STDIN], EAX
              _PYRT_WRITESTR : ecrire chaine sur la console
                PUSH 0 / LEA EAX, [_PY_WRITTEN] / PUSH EAX
                PUSH longueur / PUSH adresse / PUSH [_PY_STDOUT]
                CALL WriteFile
              _PYRT_WRITECRLF : ecrire un retour a la ligne
              _PYRT_READLINE : lire une ligne depuis la console
                ReadFile + suppression CR/LF -> EAX=ptr chaine
            Routines chaines :
              _PYRT_STRLEN, _PYRT_STRCONCAT, _PYRT_STRCMP,
              _PYRT_STRMUL, _PYRT_STRSLICE, _PYRT_STRFIND,
              _PYRT_STRUPPER, _PYRT_STRLOWER, _PYRT_STRSTRIP,
              _PYRT_STRREPLACE, _PYRT_STRCONTAINS,
              _PYRT_STRCOUNT, _PYRT_STRSTARTSWITH, _PYRT_STRENDSWITH
            Routines collections :
              _PYRT_OBJNEW, _PYRT_HEAPALLOC,
              _PYRT_LISTAPPEND, _PYRT_LISTPOP, _PYRT_LISTCONCAT,
              _PYRT_LISTCONTAINS, _PYRT_LISTSLICE, _PYRT_LISTMUL,
              _PYRT_DICTGET, _PYRT_DICTSET, _PYRT_DICTDEL,
              _PYRT_DICTGETDEF, _PYRT_DICTCONTAINS,
              _PYRT_TUPLECONCAT, _PYRT_TUPLEMUL, _PYRT_TUPLECONTAINS
            Routines mathematiques :
              _PYRT_POW : exponentiation (boucle de multiplication)
              _PYRT_ABS : valeur absolue
                CDQ / XOR EAX, EDX / SUB EAX, EDX
            _PYRT_PANIC : affiche message erreur + ExitProcess(1)
            Heap allocation : _PYRT_HEAPALLOC(ECX=taille) -> EAX=ptr
            10 fonctions accesseurs

  TODO 23 - ECRIVAIN BINAIRE PE ET COFF .OBJ [A FAIRE]
            Ecrivain PE (.EXE) - structure PE32 complete :
              DOS Header (64 octets) avec DOS stub
              Signature PE "PE\0\0"
              COFF File Header (20 octets)
                Machine : $014C (i386), NumberOfSections : 3
              Optional Header (224 octets)
                Magic : $010B (PE32)
                ImageBase : $00400000
                SectionAlignment : $1000 (4096)
                FileAlignment : $0200 (512)
                Subsystem : 3 (CUI Console)
                DataDirectory[1] : Import Table RVA/Size
              Section Headers : .text, .rdata, .data
              Section .text : code machine 80386 genere
              Section .rdata : Import Directory, IAT, Hint/Name Table
              Section .data : variables et constantes
              Resolution des fixups (adresses relatives/absolues)
              Alignement sur FileAlignment / SectionAlignment
            Ecrivain COFF (.OBJ) - format compatible LINK.EXE :
              COFF File Header (Machine $014C)
              Sections .text, .data, .bss
              Table des relocations :
                IMAGE_REL_I386_DIR32 (adresse absolue)
                IMAGE_REL_I386_REL32 (adresse relative)
              Table des symboles :
                StorageClass : EXTERNAL (2), STATIC (3), LABEL (6)
                Symboles externes pour imports Win32
                Symboles definis pour fonctions/variables Python
              Table des chaines (noms > 8 caracteres)
            Mode -obj : appeler GenerateCoffObj au lieu de GeneratePeExe
            10 fonctions accesseurs

  TODO 24 - IMPORTS API WIN32 ET GENERATEUR LISTING ASM [A FAIRE]
            Imports kernel32.dll :
              ExitProcess : terminer le programme
              GetStdHandle : obtenir les handles console
              WriteFile : ecrire sur la console (print)
              ReadFile : lire depuis la console (input)
              GetProcessHeap, HeapAlloc, HeapFree :
                allocation dynamique (si heap statique insuffisant)
              GetCommandLineA : arguments de la ligne de commande
              GetLastError : code d erreur Win32
            Imports msvcrt.dll (optionnel) :
              sprintf, sscanf : formatage numerique avance
              memcpy, memset, memcmp : operations memoire
            Generer la table d importation PE :
              IMAGE_IMPORT_DESCRIPTOR par DLL
              Hint/Name Table avec noms de fonctions
              Import Address Table (IAT) avec thunks
            Generer les EXTERN et symboles pour le mode .OBJ
            Marquer les imports reellement utilises pour
              n inclure que le necessaire
            Generateur de listing ASM (parametre -asm) :
              Format MASM (.ASM) lisible et assemblable :
              .386
              .MODEL FLAT, STDCALL
              OPTION CASEMAP:NONE
              INCLUDELIB kernel32.lib
              EXTERN _ExitProcess@4:PROC
              EXTERN _GetStdHandle@4:PROC
              EXTERN _WriteFile@20:PROC
              EXTERN _ReadFile@20:PROC
              (autres imports Win32 utilises)
              Section .DATA, .DATA?, .CODE
              Point d entree _start
              Routines runtime (_PYRT_)
              Fonctions Python avec labels (_PYF_)
              Commentaires avec le code source Python
              Indentation et formatage lisible
            10 fonctions accesseurs

  TODO 25 - OPTIMISATIONS, TESTS FINAUX ET INTEGRATION SAMPLES\PYTHON\* [A FAIRE]
            Optimisations peephole :
              MOV EAX, 0 -> XOR EAX, EAX
              PUSH EAX / POP EAX -> (eliminer)
              MOV EAX, [x] / MOV [x], EAX -> (eliminer deuxieme)
              ADD EAX, 1 -> INC EAX
              SUB EAX, 1 -> DEC EAX
              IMUL EAX, 2 -> SHL EAX, 1
              IMUL EAX, 4 -> SHL EAX, 2
            Verification : compiler et executer les exemples
              SAMPLES\PYTHON\hello.py          - print, variables, chaines
              SAMPLES\PYTHON\math.py           - operateurs, fonctions, recursion
              SAMPLES\PYTHON\control.py        - if/elif/else, while, for, break
              SAMPLES\PYTHON\lists.py          - listes, append, pop, index, in
              SAMPLES\PYTHON\dicts.py          - dictionnaires, acces, keys, del
              SAMPLES\PYTHON\strings.py        - operations chaines, find, upper
              SAMPLES\PYTHON\classes.py        - class, __init__, heritage
              SAMPLES\PYTHON\except.py         - try/except/finally, raise
              SAMPLES\PYTHON\test_types.py     - types dynamiques, isinstance
              SAMPLES\PYTHON\test_operators.py - tous les operateurs
              SAMPLES\PYTHON\test_binexpr.py   - expressions binaires
              SAMPLES\PYTHON\test_io.py        - print/input, hex, oct, bin
              SAMPLES\PYTHON\test_variables.py - affectations, augmented
              SAMPLES\PYTHON\test_symbols.py   - portee, global, builtins
              SAMPLES\PYTHON\test_if.py        - conditions, ternaire, pass
              SAMPLES\PYTHON\test_loops.py     - while, for, range, break
              SAMPLES\PYTHON\test_expressions.py - builtins, appels
              SAMPLES\PYTHON\test_functions.py - def, return, recursion
              SAMPLES\PYTHON\test_lists.py     - operations listes
              SAMPLES\PYTHON\test_tuples.py    - tuples, unpacking
              SAMPLES\PYTHON\test_dicts.py     - operations dictionnaires
              SAMPLES\PYTHON\test_strings.py   - operations chaines
              SAMPLES\PYTHON\test_comprehensions.py - comprehensions
              SAMPLES\PYTHON\test_literals.py  - entiers, chaines, None, bool
              SAMPLES\PYTHON\test_exceptions.py - exceptions, raise
              SAMPLES\PYTHON\test_imports.py   - import, from import
              SAMPLES\PYTHON\test_lexer.py     - tokens, mots-cles
              SAMPLES\PYTHON\test_emitter.py   - generation code
              SAMPLES\PYTHON\test_runtime.py   - runtime, heap, collections
              SAMPLES\PYTHON\test_dataseg.py   - segment de donnees
              SAMPLES\PYTHON\test_classes.py   - classes, heritage, methodes
            Tests de regression pour chaque TODO
            Verification des 3 modes de sortie :
              .EXE (defaut), .OBJ (-obj), .ASM (-asm)
            Mesure de la taille des executables generes
            10 fonctions accesseurs

  ============================================================ *)

Program PYTHCW32;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

Begin
  WriteLn('PYTHCW32 - Compilateur Python vers Win32 (80386)');
  WriteLn('Version 0.1 - En cours de developpement');
End.
