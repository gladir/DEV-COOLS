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

  TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES PE/COFF [IMPLEMENTE]
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

  TODO 02 - TOKENISEUR PYTHON (LEXER) [IMPLEMENTE]
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

  TODO 03 - RECONNAISSANCE DES MOTS-CLES PYTHON [IMPLEMENTE]
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

  TODO 04 - TABLE DES SYMBOLES PYTHON (32 BITS) [IMPLEMENTE]
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

{ ============================================================ }
{ TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES    [IMPLEMENTE] }
{           PE/COFF                                              }
{ ============================================================ }

Const
  PYTHCW32_VERSION = '0.1';
  PYTHCW32_DATE    = '2026';

  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Constantes PE/COFF }
  PE_DOS_MAGIC    = $5A4D;    { 'MZ' }
  PE_PE_SIG       = $00004550; { 'PE\0\0' }
  PE_MACHINE_I386 = $014C;
  PE_OPT_SIZE     = $E0;      { 224 octets }
  PE_MAGIC_32     = $010B;
  PE_IMG_BASE     = $00400000;
  PE_SEC_ALIGN    = 4096;
  PE_FILE_ALIGN   = 512;
  PE_SUBSYS_CUI   = 3;  { Console }

  { Tailles des tampons binaires }
  MAX_BIN_CODE = 65536;
  MAX_BIN_DATA = 65536;
  MAX_BIN_LBL  = 4096;
  MAX_BIN_FIX  = 8192;

  { Limites internes (32 bits) }
  MAX_SYM        = 4096;
  MAX_LABEL      = 4096;
  MAX_SCOPE      = 64;
  MAX_DATA       = 512;
  MAX_PARAM      = 64;
  MAX_LOOP_NEST  = 32;
  MAX_TRY_NEST   = 16;
  MAX_ERRORS     = 30;
  MAX_STR        = 255;
  MAX_INDENT     = 64;
  MAX_DEDENT_Q   = 32;
  MAX_HASH_PAIRS = 64;
  MAX_CLASS      = 64;
  MAX_CLS_ATTR   = 32;
  MAX_CLS_METH   = 32;
  MAX_IMPORT     = 32;
  MAX_COMP_BUF   = 64;

  { Prefixes de nommage ASM }
  PY_VAR_PFX  = '_PYV_';    { variable globale/locale              }
  PY_FN_PFX   = '_PYF_';    { fonction def                         }
  PY_STR_PFX  = '_PYK_';    { constante chaine litterale           }
  PY_RT_PFX   = '_PYRT_';   { routine runtime                      }
  PY_LBL_PFX  = '_PYL_';    { label de saut interne                }
  PY_CLS_PFX  = '_PYC_';    { classe / vtable                      }
  PY_MTH_PFX  = '_PYM_';    { methode                              }

Type
  TString = String;

  TOptions = Record
    SrcFile    : TString;   { fichier source Python (.py)          }
    OutFile    : TString;   { fichier sortie (.exe, .obj)          }
    Verbose    : Boolean;   { -v : banniere et statistiques        }
    DebugMode  : Boolean;   { -d : affichage de chaque token       }
    Warnings   : Boolean;   { -w : afficher les avertissements     }
    EmitExe    : Boolean;   { par defaut : produire un .EXE (PE)   }
    EmitObj    : Boolean;   { -obj : produire seulement un .OBJ    }
    EmitAsm    : Boolean;   { -asm : produire aussi un .ASM        }
  End;

Var
  { Options }
  Opts : TOptions;

  { Compteurs generaux }
  ErrorCount : Integer;
  WarnCount  : Integer;
  TotalLines : LongInt;

  { Fichier de sortie interne (pour future emission) }
  OutF       : Text;
  OutFOpen   : Boolean;

  { Drapeau pour la generation binaire PE (mini-assembleur) }
  BcActive   : Boolean;

{ ------------------------------------------------------------ }
{ Fonctions utilitaires                                        }
{ ------------------------------------------------------------ }

Function ItoS(V : LongInt) : TString;
Var S : TString;
Begin
  Str(V, S);
  ItoS := S;
End;

Function HexNibble(V : Integer) : Char;
Begin
  V := V And $0F;
  If V < 10 Then
    HexNibble := Chr(Ord('0') + V)
  Else
    HexNibble := Chr(Ord('A') + V - 10);
End;

Function HexByte(V : Integer) : TString;
Begin
  HexByte := HexNibble(V Shr 4) + HexNibble(V);
End;

Function HexWord(V : Integer) : TString;
Begin
  HexWord := HexByte(V Shr 8) + HexByte(V);
End;

Function HexLong(V : LongInt) : TString;
Begin
  HexLong := HexWord(V Shr 16) + HexWord(V);
End;

Function UpCaseStr(Const S : TString) : TString;
Var
  I   : Integer;
  Tmp : TString;
Begin
  Tmp := S;
  For I := 1 To Length(Tmp) Do
    If (Tmp[I] >= 'a') And (Tmp[I] <= 'z') Then
      Tmp[I] := Chr(Ord(Tmp[I]) - 32);
  UpCaseStr := Tmp;
End;

Function StrLowerCase(Const S : TString) : TString;
Var
  I   : Integer;
  Tmp : TString;
Begin
  Tmp := S;
  For I := 1 To Length(Tmp) Do
    If (Tmp[I] >= 'A') And (Tmp[I] <= 'Z') Then
      Tmp[I] := Chr(Ord(Tmp[I]) + 32);
  StrLowerCase := Tmp;
End;

{ Transforme un nom Python en identifiant valide pour l assembleur }
Function AsmIdent(Const S : TString) : TString;
Var
  I   : Integer;
  Tmp : TString;
Begin
  Tmp := '';
  For I := 1 To Length(S) Do
  Begin
    If ((S[I] >= 'A') And (S[I] <= 'Z')) Or
       ((S[I] >= 'a') And (S[I] <= 'z')) Or
       ((S[I] >= '0') And (S[I] <= '9')) Or
       (S[I] = '_') Then
      Tmp := Tmp + S[I]
    Else
      Tmp := Tmp + '_';
  End;
  AsmIdent := Tmp;
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

{ Retourne l extension d un chemin (avec le point, en minuscules) }
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
    ExtractExt := StrLowerCase(Copy(Path, LastDot,
                     Length(Path) - LastDot + 1))
  Else
    ExtractExt := '';
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

{ Retourne le repertoire d un chemin (avec le separateur final) }
Function ExtractDir(Const Path : TString) : TString;
Var
  I, LastSep : Integer;
Begin
  LastSep := 0;
  For I := 1 To Length(Path) Do
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
  If LastSep > 0 Then
    ExtractDir := Copy(Path, 1, LastSep)
  Else
    ExtractDir := '';
End;

{ ------------------------------------------------------------ }
{ FatalError / CompileError / WarnMsg                          }
{ ------------------------------------------------------------ }

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('PYTHCW32: FATAL: ', Msg);
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
  Halt(EXIT_ERROR);
End;

Procedure CompileError(Const Msg : TString; Line : Integer);
Begin
  Write('PYTHCW32:');
  If Line > 0 Then
    Write(Opts.SrcFile, ':', Line, ': ');
  WriteLn('error: ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('trop d''erreurs, compilation arretee');
End;

Procedure WarnMsg(Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  WriteLn('PYTHCW32: warning: ', Msg);
  Inc(WarnCount);
End;

{ ------------------------------------------------------------ }
{ InitOptions                                                  }
{ ------------------------------------------------------------ }

Procedure InitOptions;
Begin
  Opts.SrcFile    := '';
  Opts.OutFile    := '';
  Opts.Verbose    := False;
  Opts.DebugMode  := False;
  Opts.Warnings   := False;
  Opts.EmitExe    := True;
  Opts.EmitObj    := False;
  Opts.EmitAsm    := False;
End;

{ ------------------------------------------------------------ }
{ ShowHelp                                                     }
{ ------------------------------------------------------------ }

Procedure ShowHelp;
Begin
  WriteLn('PYTHCW32 v', PYTHCW32_VERSION, ' (', PYTHCW32_DATE,
          ') - Compilateur Python vers 80386 (Windows PE 32 bits)');
  WriteLn('PYTHCW32 - Cette commande permet de lancer le compilateur Python ',
          'pour l''assembleur du microprocesseur 80386 (en executable ',
          'Windows 32 bits).');
  WriteLn;
  WriteLn('Syntaxe : PYTHCW32 [options] <source.py> [options]');
  WriteLn;
  WriteLn('Sortie :');
  WriteLn('  Par defaut un .EXE (PE Windows 32 bits)');
  WriteLn('  -obj           Produire seulement un fichier .OBJ (COFF)');
  WriteLn('  -asm           Produire egalement un fichier .ASM lisible');
  WriteLn('  -o <fichier>   Specifier le nom du fichier de sortie');
  WriteLn;
  WriteLn('General :');
  WriteLn('  -v             Mode verbeux (banniere + statistiques)');
  WriteLn('  -d             Debug tokens (affiche chaque token)');
  WriteLn('  -w             Afficher les avertissements');
  WriteLn('  -h, --help, /? Afficher cette aide');
  WriteLn;
  WriteLn('Exemples :');
  WriteLn('  PYTHCW32 hello.py');
  WriteLn('  PYTHCW32 hello.py -o hello.exe -v');
  WriteLn('  PYTHCW32 main.py -asm');
  WriteLn('  PYTHCW32 module.py -obj -w');
  Halt(EXIT_OK);
End;

{ ------------------------------------------------------------ }
{ ParseArgs                                                    }
{ ------------------------------------------------------------ }

Procedure ParseArgs;
Var
  I    : Integer;
  Arg  : TString;
  Ext  : TString;
Begin
  InitOptions;
  If ParamCount = 0 Then
    ShowHelp;

  I := 1;
  While I <= ParamCount Do
  Begin
    Arg := ParamStr(I);

    If (Arg = '-h') Or (Arg = '--help') Or (Arg = '/?') Or
       (Arg = '/h') Or (Arg = '/H') Then
      ShowHelp
    Else If Arg = '-v' Then
      Opts.Verbose := True
    Else If Arg = '-d' Then
      Opts.DebugMode := True
    Else If Arg = '-w' Then
      Opts.Warnings := True
    Else If Arg = '-asm' Then
      Opts.EmitAsm := True
    Else If Arg = '-obj' Then
    Begin
      Opts.EmitObj := True;
      Opts.EmitExe := False;
    End
    Else If Arg = '-o' Then
    Begin
      Inc(I);
      If I > ParamCount Then
        FatalError('-o necessite un nom de fichier');
      Opts.OutFile := ParamStr(I);
    End
    Else If (Length(Arg) > 0) And (Arg[1] = '-') Then
      FatalError('Option inconnue: ' + Arg)
    Else
    Begin
      { Argument positionnel : fichier source }
      If Opts.SrcFile = '' Then
        Opts.SrcFile := Arg
      Else
        FatalError('Argument inattendu: ' + Arg);
    End;

    Inc(I);
  End;

  { Validation : fichier source requis }
  If Opts.SrcFile = '' Then
  Begin
    WriteLn('PYTHCW32: fichier source manquant');
    ShowHelp;
  End;

  { Verifier l extension .py }
  Ext := ExtractExt(Opts.SrcFile);
  If Ext <> '.py' Then
    WarnMsg('extension attendue .py, trouvee: ' + Ext);

  { Fichier de sortie par defaut }
  If Opts.OutFile = '' Then
  Begin
    If Opts.EmitObj Then
      Opts.OutFile := ReplaceExt(Opts.SrcFile, '.obj')
    Else
      Opts.OutFile := ReplaceExt(Opts.SrcFile, '.exe');
  End;
End;

{ ------------------------------------------------------------ }
{ ShowBanner / ShowStats                                        }
{ ------------------------------------------------------------ }

Procedure ShowBanner;
Begin
  If Not Opts.Verbose Then Exit;
  WriteLn('PYTHCW32 v', PYTHCW32_VERSION, ' (', PYTHCW32_DATE,
          ') - Compilateur Python -> 80386 PE Win32');
  WriteLn('Source   : ', Opts.SrcFile);
  WriteLn('Sortie   : ', Opts.OutFile);
  If Opts.EmitAsm Then
    WriteLn('ASM      : ', ReplaceExt(Opts.OutFile, '.asm'));
  If Opts.EmitObj Then
    WriteLn('Mode     : OBJ (COFF 32 bits)')
  Else
    WriteLn('Mode     : EXE (PE Win32)');
  WriteLn;
End;

Procedure ShowStats;
Begin
  If Not Opts.Verbose Then Exit;
  WriteLn;
  WriteLn('--- Statistiques ---');
  WriteLn('Lignes analysees : ', TotalLines);
  WriteLn('Erreurs          : ', ErrorCount);
  WriteLn('Avertissements   : ', WarnCount);
End;

{ ------------------------------------------------------------ }
{ Cleanup                                                      }
{ ------------------------------------------------------------ }

Procedure Cleanup;
Begin
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 01)                             }
{ ------------------------------------------------------------ }

Function GetCompilerVersion : TString;
Begin
  GetCompilerVersion := PYTHCW32_VERSION;
End;

Function GetCompilerDate : TString;
Begin
  GetCompilerDate := PYTHCW32_DATE;
End;

Function IsEmitExe : Boolean;
Begin
  IsEmitExe := Opts.EmitExe;
End;

Function IsEmitObj : Boolean;
Begin
  IsEmitObj := Opts.EmitObj;
End;

Function IsEmitAsm : Boolean;
Begin
  IsEmitAsm := Opts.EmitAsm;
End;

Function IsVerbose : Boolean;
Begin
  IsVerbose := Opts.Verbose;
End;

Function IsDebugMode : Boolean;
Begin
  IsDebugMode := Opts.DebugMode;
End;

Function IsWarnings : Boolean;
Begin
  IsWarnings := Opts.Warnings;
End;

Function GetSrcFile : TString;
Begin
  GetSrcFile := Opts.SrcFile;
End;

Function GetOutFile : TString;
Begin
  GetOutFile := Opts.OutFile;
End;

{ ============================================================ }
{ TODO 02 - TOKENISEUR PYTHON (LEXER)             [IMPLEMENTE] }
{ ============================================================ }

Const
  { Types de tokens Python }
  TK_EOF      = 0;    { fin de fichier                          }
  TK_NEWLINE  = 1;    { fin de ligne logique                    }
  TK_INDENT   = 2;    { augmentation d indentation              }
  TK_DEDENT   = 3;    { diminution d indentation                }
  TK_INTEGER  = 4;    { litteral entier (42, 0xFF, 0o17, 0b101) }
  TK_FLOAT    = 5;    { litteral flottant (3.14, 1.5e3)         }
  TK_STRING   = 6;    { litteral chaine 'abc' ou "abc"          }
  TK_IDENT    = 7;    { identificateur (non mot-cle)            }
  TK_KEYWORD  = 8;    { mot-cle Python reconnu                  }
  TK_OP       = 9;    { operateur + - * / == != etc.            }
  TK_PUNCT    = 10;   { ponctuation , ( ) ; etc.                }
  TK_COLON    = 11;   { :                                       }
  TK_LBRACKET = 12;   { [                                       }
  TK_RBRACKET = 13;   { ]                                       }
  TK_LBRACE   = 14;   { accolade ouvrante                       }
  TK_RBRACE   = 15;   { accolade fermante                       }
  TK_DOT      = 16;   { .                                       }
  TK_AT       = 17;   { @                                       }
  TK_ARROW    = 18;   { ->                                      }

  { Constante pour LookupKeyword (forward) }
  KW_NONE = 0;

Var
  { Fichier source }
  LexSrcF     : Text;          { handle du fichier source              }
  LexOpened   : Boolean;       { fichier ouvert ?                      }
  LexLine     : TString;       { ligne courante                        }
  LexLineNo   : Integer;       { numero de ligne courante              }
  LexColNo    : Integer;       { colonne courante dans LexLine         }
  LexEOF      : Boolean;       { fin de fichier atteinte ?             }

  { Token courant }
  CurTokKind  : Integer;       { type de token (TK_*)                  }
  CurTokStr   : TString;       { valeur textuelle du token             }
  CurTokInt   : LongInt;       { valeur numerique (entier)             }
  CurTokFloat : Real;          { valeur numerique (flottant)           }
  CurTokLine  : Integer;       { ligne du token                        }
  CurTokCol   : Integer;       { colonne du token                      }

  { Compteur de tokens }
  LexTokCount : LongInt;       { nombre total de tokens emis           }

  { Pile d indentation Python }
  IndentStack : Array[0..MAX_INDENT - 1] Of Integer;
  IndentTop   : Integer;       { indice du sommet (0=base=colonne 0)   }
  DedentQueue : Integer;       { nombre de DEDENT en attente           }
  AtLineStart : Boolean;       { True = debut de ligne logique         }
  ParenDepth  : Integer;       { >0 = dans paren/crochet -> pas NEWLINE}

{ ------------------------------------------------------------ }
{ Fonctions de classification de caracteres                    }
{ ------------------------------------------------------------ }

Function IsDigit(Ch : Char) : Boolean;
Begin
  IsDigit := (Ch >= '0') And (Ch <= '9');
End;

Function IsAlpha(Ch : Char) : Boolean;
Begin
  IsAlpha := ((Ch >= 'A') And (Ch <= 'Z')) Or
             ((Ch >= 'a') And (Ch <= 'z'));
End;

Function IsIdentStart(Ch : Char) : Boolean;
Begin
  IsIdentStart := IsAlpha(Ch) Or (Ch = '_');
End;

Function IsIdentCont(Ch : Char) : Boolean;
Begin
  IsIdentCont := IsAlpha(Ch) Or IsDigit(Ch) Or (Ch = '_');
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

{ ------------------------------------------------------------ }
{ Forward declaration pour LookupKeyword (TODO 03)             }
{ ------------------------------------------------------------ }

Function LookupKeyword(Const S : TString) : Integer; Forward;

{ ------------------------------------------------------------ }
{ LexNextLine : lire la prochaine ligne du fichier source      }
{ ------------------------------------------------------------ }

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

{ ------------------------------------------------------------ }
{ LexInit : ouvrir le fichier source et initialiser le lexeur  }
{ ------------------------------------------------------------ }

Procedure LexInit;
Begin
  Assign(LexSrcF, Opts.SrcFile);
  {$I-}
  Reset(LexSrcF);
  {$I+}
  If IOResult <> 0 Then
    FatalError('Impossible d''ouvrir le fichier source: ' + Opts.SrcFile);
  LexOpened   := True;
  LexLineNo   := 0;
  LexColNo    := 1;
  LexEOF      := False;
  LexLine     := '';
  CurTokKind  := TK_EOF;
  CurTokStr   := '';
  CurTokInt   := 0;
  CurTokFloat := 0.0;
  CurTokLine  := 0;
  CurTokCol   := 0;
  LexTokCount := 0;
  IndentTop   := 0;
  IndentStack[0] := 0;
  DedentQueue := 0;
  AtLineStart := True;
  ParenDepth  := 0;
  LexNextLine;
  { Detecter shebang #!/... et le sauter }
  If (Not LexEOF) And (Length(LexLine) >= 2) And
     (LexLine[1] = '#') And (LexLine[2] = '!') Then
  Begin
    LexNextLine;
    AtLineStart := True;
  End;
End;

{ ------------------------------------------------------------ }
{ LexClose : fermer le fichier source                          }
{ ------------------------------------------------------------ }

Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
End;

{ ------------------------------------------------------------ }
{ LexScanIdent : identificateur Python (sensible a la casse)   }
{ ------------------------------------------------------------ }

Procedure LexScanIdent;
Var
  S  : TString;
  KW : Integer;
Begin
  S := '';
  While (LexColNo <= Length(LexLine)) And
        IsIdentCont(LexLine[LexColNo]) Do
  Begin
    If Length(S) < MAX_STR Then
      S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  CurTokStr   := S;
  CurTokFloat := 0.0;

  { Tester si c est un mot-cle Python }
  KW := LookupKeyword(S);
  If KW <> KW_NONE Then
  Begin
    CurTokKind := TK_KEYWORD;
    CurTokInt  := KW;
  End
  Else
  Begin
    CurTokKind := TK_IDENT;
    CurTokInt  := 0;
  End;
End;

{ ------------------------------------------------------------ }
{ LexScanNumber : litteral numerique Python                    }
{ Entiers : 123, 0xFF, 0o77, 0b1010, 1_000                    }
{ Flottants : 1.5, 3.14, 1.5e3, .5                            }
{ ------------------------------------------------------------ }

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
      Inc(LexColNo, 2);
    End
    Else If (Ch = 'o') Or (Ch = 'O') Then
    Begin
      Base := 8;
      Inc(LexColNo, 2);
    End
    Else If (Ch = 'b') Or (Ch = 'B') Then
    Begin
      Base := 2;
      Inc(LexColNo, 2);
    End;
  End;

  { Scanner la partie entiere }
  While LexColNo <= Length(LexLine) Do
  Begin
    Ch := LexLine[LexColNo];
    If Ch = '_' Then
      Inc(LexColNo)
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
     (LexLine[LexColNo + 1] >= '0') And
     (LexLine[LexColNo + 1] <= '9') Then
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
        FracVal := FracVal +
                   (Ord(LexLine[LexColNo]) - Ord('0')) / FracDiv;
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
    If (LexColNo <= Length(LexLine)) And
       (LexLine[LexColNo] = '-') Then
    Begin
      NegExp := True;
      Inc(LexColNo);
    End
    Else If (LexColNo <= Length(LexLine)) And
            (LexLine[LexColNo] = '+') Then
      Inc(LexColNo);
    ExpVal := 0;
    While (LexColNo <= Length(LexLine)) And
          (((LexLine[LexColNo] >= '0') And
            (LexLine[LexColNo] <= '9')) Or
           (LexLine[LexColNo] = '_')) Do
    Begin
      If LexLine[LexColNo] <> '_' Then
        ExpVal := ExpVal * 10 +
                  (Ord(LexLine[LexColNo]) - Ord('0'));
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
    CurTokFloat := FltVal;
    If FltVal > 2147483647.0 Then CurTokInt := 2147483647
    Else If FltVal < -2147483647.0 Then CurTokInt := -2147483647
    Else CurTokInt := Trunc(FltVal);
    CurTokKind := TK_FLOAT;
    Str(FltVal:0:6, CurTokStr);
  End
  Else
  Begin
    CurTokKind  := TK_INTEGER;
    CurTokInt   := N;
    CurTokFloat := 0.0;
    CurTokStr   := ItoS(N);
  End;
End;

{ ------------------------------------------------------------ }
{ LexScanEscChar : decoder une sequence d echappement Python   }
{ ------------------------------------------------------------ }

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
      If (LexColNo <= Length(LexLine)) And
         IsHexDigit(LexLine[LexColNo]) Then
      Begin
        V := HexVal(LexLine[LexColNo]);
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And
           IsHexDigit(LexLine[LexColNo]) Then
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

{ ------------------------------------------------------------ }
{ LexScanString : chaine Python simple/double/triple            }
{ Quote = caractere guillemet (' ou ")                          }
{ Triple = True pour ''' ou """                                 }
{ IsRaw = True pour r'...' (pas d echappement)                 }
{ ------------------------------------------------------------ }

Procedure LexScanString(Quote : Char; Triple, IsRaw : Boolean);
Var
  S  : TString;
  Ch : Char;
Begin
  S := '';
  If Triple Then
  Begin
    { Sauter les 3 guillemets ouvrants }
    Inc(LexColNo, 3);
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
        Inc(LexColNo, 3);
        Break;
      End
      Else If (Ch = '\') And (Not IsRaw) Then
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
    Inc(LexColNo);
    While LexColNo <= Length(LexLine) Do
    Begin
      Ch := LexLine[LexColNo];
      If Ch = Quote Then
      Begin
        Inc(LexColNo);
        Break;
      End
      Else If (Ch = '\') And (Not IsRaw) Then
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
  CurTokKind  := TK_STRING;
  CurTokStr   := S;
  CurTokInt   := 0;
  CurTokFloat := 0.0;
End;

{ ------------------------------------------------------------ }
{ PrintToken : affichage debug de chaque token                 }
{ ------------------------------------------------------------ }

Procedure PrintToken;
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', CurTokLine, ',', CurTokCol, '] ');
  Case CurTokKind Of
    TK_EOF      : Write('EOF');
    TK_NEWLINE  : Write('NEWLINE');
    TK_INDENT   : Write('INDENT');
    TK_DEDENT   : Write('DEDENT');
    TK_INTEGER  : Write('INT(', CurTokInt, ')');
    TK_FLOAT    : Write('FLOAT(', CurTokStr, ')');
    TK_STRING   : Write('STR(''', CurTokStr, ''')');
    TK_IDENT    : Write('IDENT(', CurTokStr, ')');
    TK_KEYWORD  : Write('KW(', CurTokStr, ')');
    TK_OP       : Write('OP(', CurTokStr, ')');
    TK_PUNCT    : Write('PUNCT(', CurTokStr, ')');
    TK_COLON    : Write('COLON');
    TK_LBRACKET : Write('LBRACKET');
    TK_RBRACKET : Write('RBRACKET');
    TK_LBRACE   : Write('LBRACE');
    TK_RBRACE   : Write('RBRACE');
    TK_DOT      : Write('DOT');
    TK_AT       : Write('AT');
    TK_ARROW    : Write('ARROW');
  Else
    Write('TOK(', CurTokKind, ')');
  End;
  WriteLn;
End;

{ ------------------------------------------------------------ }
{ LexNextToken : reconnaitre le prochain token Python           }
{ Gere l indentation (INDENT/DEDENT), les NEWLINE,              }
{ les commentaires #, et tous les operateurs Python             }
{ ------------------------------------------------------------ }

Procedure LexNextToken;
Var
  Ch       : Char;
  Indent   : Integer;
  IsTriple : Boolean;
  IsRaw    : Boolean;
  Scanning : Boolean;
Begin
  CurTokInt   := 0;
  CurTokFloat := 0.0;

  { 1) S il reste des DEDENT en file d attente, les emettre }
  If DedentQueue > 0 Then
  Begin
    Dec(DedentQueue);
    CurTokKind := TK_DEDENT;
    CurTokStr  := '';
    CurTokLine := LexLineNo;
    CurTokCol  := 1;
    Inc(LexTokCount);
    PrintToken;
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
        CurTokKind := TK_NEWLINE;
        CurTokStr  := '';
        CurTokLine := LexLineNo;
        CurTokCol  := LexColNo;
        AtLineStart := True;
        Scanning := False;
        Break;
      End;
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
        DedentQueue := IndentTop;
        IndentTop := 0;
        CurTokKind := TK_DEDENT;
        CurTokStr  := '';
        CurTokLine := LexLineNo;
        CurTokCol  := 1;
        Scanning := False;
        Break;
      End;
      CurTokKind := TK_EOF;
      CurTokStr  := '';
      CurTokLine := LexLineNo;
      CurTokCol  := LexColNo;
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
            ((LexLine[LexColNo] = ' ') Or
             (LexLine[LexColNo] = #9)) Do
      Begin
        If LexLine[LexColNo] = #9 Then
          Indent := ((Indent Div 8) + 1) * 8
        Else
          Inc(Indent);
        Inc(LexColNo);
      End;

      { Ligne vide ou commentaire seul : pas d INDENT/DEDENT }
      If (LexColNo > Length(LexLine)) Or
         (LexLine[LexColNo] = '#') Then
      Begin
        LexColNo := Length(LexLine) + 1;
        Continue;
      End;

      { Dans parentheses/crochets/accolades : pas d INDENT }
      If ParenDepth > 0 Then
        Continue;

      { Comparer avec le sommet de la pile d indentation }
      If Indent > IndentStack[IndentTop] Then
      Begin
        Inc(IndentTop);
        If IndentTop >= MAX_INDENT Then
          IndentTop := MAX_INDENT - 1;
        IndentStack[IndentTop] := Indent;
        CurTokKind := TK_INDENT;
        CurTokStr  := '';
        CurTokLine := LexLineNo;
        CurTokCol  := 1;
        Scanning := False;
        Break;
      End
      Else If Indent < IndentStack[IndentTop] Then
      Begin
        While (IndentTop > 0) And
              (Indent < IndentStack[IndentTop]) Do
        Begin
          Dec(IndentTop);
          Inc(DedentQueue);
        End;
        If Indent <> IndentStack[IndentTop] Then
          CompileError('indentation inconsistante', LexLineNo);
        If DedentQueue > 0 Then
        Begin
          Dec(DedentQueue);
          CurTokKind := TK_DEDENT;
          CurTokStr  := '';
          CurTokLine := LexLineNo;
          CurTokCol  := 1;
          Scanning := False;
          Break;
        End;
      End;
      Continue;
    End;

    CurTokLine := LexLineNo;
    CurTokCol  := LexColNo;
    Ch := LexLine[LexColNo];

    { Espaces }
    If (Ch = ' ') Or (Ch = #9) Or (Ch = #13) Or (Ch = #12) Then
      Inc(LexColNo)

    { Commentaire # -> fin de ligne }
    Else If Ch = '#' Then
      LexColNo := Length(LexLine) + 1

    { Continuation de ligne avec \ en fin de ligne }
    Else If (Ch = '\') And (LexColNo = Length(LexLine)) Then
    Begin
      LexNextLine;
    End

    { Identificateur ou mot-cle (ou prefixe chaine r/b/f) }
    Else If IsIdentStart(Ch) Then
    Begin
      { Prefixes de chaines : r'...' b'...' f'...' }
      IsRaw := (Ch = 'r') Or (Ch = 'R');
      If ((Ch = 'r') Or (Ch = 'R') Or (Ch = 'b') Or (Ch = 'B') Or
          (Ch = 'f') Or (Ch = 'F')) And
         (LexColNo < Length(LexLine)) And
         ((LexLine[LexColNo + 1] = '''') Or
          (LexLine[LexColNo + 1] = '"')) Then
      Begin
        Inc(LexColNo);
        Ch := LexLine[LexColNo];
        IsTriple := (LexColNo + 2 <= Length(LexLine)) And
                    (LexLine[LexColNo + 1] = Ch) And
                    (LexLine[LexColNo + 2] = Ch);
        LexScanString(Ch, IsTriple, IsRaw);
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
      IsTriple := (LexColNo + 2 <= Length(LexLine)) And
                  (LexLine[LexColNo + 1] = Ch) And
                  (LexLine[LexColNo + 2] = Ch);
      LexScanString(Ch, IsTriple, False);
      Scanning := False;
    End

    { ** et **= }
    Else If (Ch = '*') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '*') Then
    Begin
      Inc(LexColNo, 2);
      If (LexColNo <= Length(LexLine)) And
         (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurTokKind := TK_OP; CurTokStr := '**=';
      End
      Else
      Begin
        CurTokKind := TK_OP; CurTokStr := '**';
      End;
      Scanning := False;
    End

    { *= }
    Else If (Ch = '*') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo, 2);
      CurTokKind := TK_OP; CurTokStr := '*=';
      Scanning := False;
    End

    { * }
    Else If Ch = '*' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_OP; CurTokStr := '*';
      Scanning := False;
    End

    { // et //= }
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '/') Then
    Begin
      Inc(LexColNo, 2);
      If (LexColNo <= Length(LexLine)) And
         (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurTokKind := TK_OP; CurTokStr := '//=';
      End
      Else
      Begin
        CurTokKind := TK_OP; CurTokStr := '//';
      End;
      Scanning := False;
    End

    { /= }
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo, 2);
      CurTokKind := TK_OP; CurTokStr := '/=';
      Scanning := False;
    End

    { / }
    Else If Ch = '/' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_OP; CurTokStr := '/';
      Scanning := False;
    End

    { == }
    Else If (Ch = '=') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo, 2);
      CurTokKind := TK_OP; CurTokStr := '==';
      Scanning := False;
    End

    { = }
    Else If Ch = '=' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_OP; CurTokStr := '=';
      Scanning := False;
    End

    { != }
    Else If (Ch = '!') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo, 2);
      CurTokKind := TK_OP; CurTokStr := '!=';
      Scanning := False;
    End

    { << et <<= }
    Else If (Ch = '<') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '<') Then
    Begin
      Inc(LexColNo, 2);
      If (LexColNo <= Length(LexLine)) And
         (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurTokKind := TK_OP; CurTokStr := '<<=';
      End
      Else
      Begin
        CurTokKind := TK_OP; CurTokStr := '<<';
      End;
      Scanning := False;
    End

    { <= }
    Else If (Ch = '<') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo, 2);
      CurTokKind := TK_OP; CurTokStr := '<=';
      Scanning := False;
    End

    { < }
    Else If Ch = '<' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_OP; CurTokStr := '<';
      Scanning := False;
    End

    { >> et >>= }
    Else If (Ch = '>') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '>') Then
    Begin
      Inc(LexColNo, 2);
      If (LexColNo <= Length(LexLine)) And
         (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurTokKind := TK_OP; CurTokStr := '>>=';
      End
      Else
      Begin
        CurTokKind := TK_OP; CurTokStr := '>>';
      End;
      Scanning := False;
    End

    { >= }
    Else If (Ch = '>') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo, 2);
      CurTokKind := TK_OP; CurTokStr := '>=';
      Scanning := False;
    End

    { > }
    Else If Ch = '>' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_OP; CurTokStr := '>';
      Scanning := False;
    End

    { += }
    Else If (Ch = '+') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo, 2);
      CurTokKind := TK_OP; CurTokStr := '+=';
      Scanning := False;
    End

    { + }
    Else If Ch = '+' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_OP; CurTokStr := '+';
      Scanning := False;
    End

    { -= et -> }
    Else If (Ch = '-') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo, 2);
      CurTokKind := TK_OP; CurTokStr := '-=';
      Scanning := False;
    End
    Else If (Ch = '-') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '>') Then
    Begin
      Inc(LexColNo, 2);
      CurTokKind := TK_ARROW;
      CurTokStr  := '->';
      Scanning := False;
    End

    { - }
    Else If Ch = '-' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_OP; CurTokStr := '-';
      Scanning := False;
    End

    { %= }
    Else If (Ch = '%') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo, 2);
      CurTokKind := TK_OP; CurTokStr := '%=';
      Scanning := False;
    End

    { % }
    Else If Ch = '%' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_OP; CurTokStr := '%';
      Scanning := False;
    End

    { &= }
    Else If (Ch = '&') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo, 2);
      CurTokKind := TK_OP; CurTokStr := '&=';
      Scanning := False;
    End

    { & }
    Else If Ch = '&' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_OP; CurTokStr := '&';
      Scanning := False;
    End

    { |= }
    Else If (Ch = '|') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo, 2);
      CurTokKind := TK_OP; CurTokStr := '|=';
      Scanning := False;
    End

    { | }
    Else If Ch = '|' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_OP; CurTokStr := '|';
      Scanning := False;
    End

    { ^= }
    Else If (Ch = '^') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo, 2);
      CurTokKind := TK_OP; CurTokStr := '^=';
      Scanning := False;
    End

    { ^ }
    Else If Ch = '^' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_OP; CurTokStr := '^';
      Scanning := False;
    End

    { ~ }
    Else If Ch = '~' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_OP; CurTokStr := '~';
      Scanning := False;
    End

    { @ (decorateur) }
    Else If Ch = '@' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_AT;
      CurTokStr  := '@';
      Scanning := False;
    End

    { ... (Ellipsis) }
    Else If (Ch = '.') And (LexColNo + 2 <= Length(LexLine)) And
            (LexLine[LexColNo + 1] = '.') And
            (LexLine[LexColNo + 2] = '.') Then
    Begin
      Inc(LexColNo, 3);
      CurTokKind := TK_PUNCT; CurTokStr := '...';
      Scanning := False;
    End

    { . }
    Else If Ch = '.' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_DOT;
      CurTokStr  := '.';
      Scanning := False;
    End

    { : }
    Else If Ch = ':' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_COLON;
      CurTokStr  := ':';
      Scanning := False;
    End

    { ; }
    Else If Ch = ';' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_PUNCT; CurTokStr := ';';
      Scanning := False;
    End

    { , }
    Else If Ch = ',' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_PUNCT; CurTokStr := ',';
      Scanning := False;
    End

    { ( : parenthese ouvrante }
    Else If Ch = '(' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_PUNCT; CurTokStr := '(';
      Inc(ParenDepth);
      Scanning := False;
    End

    { ) : parenthese fermante }
    Else If Ch = ')' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_PUNCT; CurTokStr := ')';
      If ParenDepth > 0 Then Dec(ParenDepth);
      Scanning := False;
    End

    { [ : crochet ouvrant }
    Else If Ch = '[' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_LBRACKET;
      CurTokStr  := '[';
      Inc(ParenDepth);
      Scanning := False;
    End

    { ] : crochet fermant }
    Else If Ch = ']' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_RBRACKET;
      CurTokStr  := ']';
      If ParenDepth > 0 Then Dec(ParenDepth);
      Scanning := False;
    End

    { accolade ouvrante }
    Else If Ch = '{' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_LBRACE;
      CurTokStr  := '{';
      Inc(ParenDepth);
      Scanning := False;
    End

    { accolade fermante }
    Else If Ch = '}' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_RBRACE;
      CurTokStr  := '}';
      If ParenDepth > 0 Then Dec(ParenDepth);
      Scanning := False;
    End

    { Caractere inconnu : avertissement et avancer }
    Else
    Begin
      WarnMsg('caractere inattendu: ''' + Ch + ''' (ASCII ' +
              ItoS(Ord(Ch)) + ') ligne ' + ItoS(LexLineNo) +
              ' colonne ' + ItoS(LexColNo));
      Inc(LexColNo);
    End;
  End; { While Scanning }

  Inc(LexTokCount);
  PrintToken;
End;

{ ------------------------------------------------------------ }
{ ParserAdvance : lire le prochain token avec debug             }
{ ------------------------------------------------------------ }

Procedure ParserAdvance;
Begin
  LexNextToken;
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 02)                             }
{ ------------------------------------------------------------ }

Function IsLexOpened : Boolean;
Begin
  IsLexOpened := LexOpened;
End;

Function IsLexEOF : Boolean;
Begin
  IsLexEOF := LexEOF;
End;

Function GetLexLineNo : Integer;
Begin
  GetLexLineNo := LexLineNo;
End;

Function GetLexColNo : Integer;
Begin
  GetLexColNo := LexColNo;
End;

Function GetLexTokCount : LongInt;
Begin
  GetLexTokCount := LexTokCount;
End;

Function GetCurTokKind : Integer;
Begin
  GetCurTokKind := CurTokKind;
End;

Function GetCurTokStr : TString;
Begin
  GetCurTokStr := CurTokStr;
End;

Function GetCurTokInt : LongInt;
Begin
  GetCurTokInt := CurTokInt;
End;

Function GetCurTokLine : Integer;
Begin
  GetCurTokLine := CurTokLine;
End;

Function GetLexStatus : TString;
Begin
  If Not LexOpened Then
    GetLexStatus := 'Not opened'
  Else If LexEOF Then
    GetLexStatus := 'EOF at line ' + ItoS(LexLineNo) +
                    ' (' + ItoS(LexTokCount) + ' tokens)'
  Else
    GetLexStatus := 'Line ' + ItoS(LexLineNo) +
                    ' col ' + ItoS(LexColNo) +
                    ' (' + ItoS(LexTokCount) + ' tokens)';
End;

{ ============================================================ }
{ TODO 03 - RECONNAISSANCE DES MOTS-CLES PYTHON   [IMPLEMENTE] }
{ ============================================================ }

Const
  { Mots-cles Python 3 : constantes }
  KW_FALSE     = 1;    { False                                   }
  KW_PY_NONE   = 2;    { None                                    }
  KW_TRUE      = 3;    { True                                    }

  { Mots-cles Python 3 : logiques }
  KW_AND       = 10;   { and                                     }
  KW_OR        = 11;   { or                                      }
  KW_NOT       = 12;   { not                                     }

  { Mots-cles Python 3 : controle }
  KW_IF        = 20;   { if                                      }
  KW_ELIF      = 21;   { elif                                    }
  KW_ELSE      = 22;   { else                                    }
  KW_WHILE     = 23;   { while                                   }
  KW_FOR       = 24;   { for                                     }
  KW_BREAK     = 25;   { break                                   }
  KW_CONTINUE  = 26;   { continue                                }
  KW_PASS      = 27;   { pass                                    }
  KW_RETURN    = 28;   { return                                  }
  KW_YIELD     = 29;   { yield                                   }

  { Mots-cles Python 3 : definitions }
  KW_DEF       = 30;   { def                                     }
  KW_CLASS     = 31;   { class                                   }
  KW_LAMBDA    = 32;   { lambda                                  }

  { Mots-cles Python 3 : exceptions }
  KW_TRY       = 40;   { try                                     }
  KW_EXCEPT    = 41;   { except                                  }
  KW_FINALLY   = 42;   { finally                                 }
  KW_RAISE     = 43;   { raise                                   }
  KW_ASSERT    = 44;   { assert                                  }

  { Mots-cles Python 3 : importation }
  KW_IMPORT    = 50;   { import                                  }
  KW_FROM      = 51;   { from                                    }
  KW_AS        = 52;   { as                                      }

  { Mots-cles Python 3 : portee }
  KW_GLOBAL    = 60;   { global                                  }
  KW_NONLOCAL  = 61;   { nonlocal                                }

  { Mots-cles Python 3 : operations }
  KW_IN        = 70;   { in                                      }
  KW_IS        = 71;   { is                                      }
  KW_DEL       = 72;   { del                                     }
  KW_WITH      = 73;   { with                                    }

  { Mots-cles Python 3 : asynchrone (reserve, non supporte) }
  KW_ASYNC     = 80;   { async                                   }
  KW_AWAIT     = 81;   { await                                   }

  KW_TOTAL_KEYWORDS = 35;  { nombre total de mots-cles Python 3  }

  { Builtins Python reconnus comme identificateurs speciaux }
  BI_PRINT       = 1;
  BI_INPUT       = 2;
  BI_LEN         = 3;
  BI_STR         = 4;
  BI_INT         = 5;
  BI_FLOAT       = 6;
  BI_BOOL        = 7;
  BI_LIST        = 8;
  BI_DICT        = 9;
  BI_TUPLE       = 10;
  BI_RANGE       = 11;
  BI_ABS         = 12;
  BI_ORD         = 13;
  BI_CHR         = 14;
  BI_HEX         = 15;
  BI_OCT         = 16;
  BI_BIN         = 17;
  BI_TYPE        = 18;
  BI_ISINSTANCE  = 19;
  BI_MIN         = 20;
  BI_MAX         = 21;
  BI_POW         = 22;
  BI_ROUND       = 23;
  BI_SORTED      = 24;
  BI_REVERSED    = 25;
  BI_ENUMERATE   = 26;
  BI_ZIP         = 27;
  BI_MAP         = 28;
  BI_FILTER      = 29;
  BI_SUM         = 30;
  BI_ANY         = 31;
  BI_ALL         = 32;
  BI_HASATTR     = 33;
  BI_GETATTR     = 34;
  BI_SETATTR     = 35;
  BI_ID          = 36;
  BI_HASH        = 37;
  BI_REPR        = 38;
  BI_OPEN        = 39;

  BI_TOTAL_BUILTINS = 39; { nombre total de builtins reconnus    }

Var
  KwInitialized : Boolean;       { True si etat initialise               }
  KwLookupCount : LongInt;       { nombre d appels a LookupKeyword       }
  KwHitCount    : LongInt;       { nombre de mots-cles reconnus          }
  BiLookupCount : LongInt;       { nombre d appels a LookupBuiltin       }
  BiHitCount    : LongInt;       { nombre de builtins reconnus           }
  KwLabelSeq    : Integer;       { sequence pour labels uniques          }
  KwLastKW      : Integer;       { dernier mot-cle reconnu (KW_*)        }
  KwLastBI      : Integer;       { dernier builtin reconnu (BI_*)        }
  KwTotalIdents : LongInt;       { total d identificateurs testes        }

{ ------------------------------------------------------------ }
{ InitKwState : initialiser les compteurs de mots-cles         }
{ ------------------------------------------------------------ }

Procedure InitKwState;
Begin
  KwInitialized := True;
  KwLookupCount := 0;
  KwHitCount    := 0;
  BiLookupCount := 0;
  BiHitCount    := 0;
  KwLabelSeq    := 0;
  KwLastKW      := 0;
  KwLastBI      := 0;
  KwTotalIdents := 0;
End;

{ ------------------------------------------------------------ }
{ GenKwLabel : generer un label unique _KW_N                    }
{ ------------------------------------------------------------ }

Function GenKwLabel : TString;
Begin
  Inc(KwLabelSeq);
  GenKwLabel := '_KW_' + ItoS(KwLabelSeq);
End;

{ ------------------------------------------------------------ }
{ KwTypeName : retourner le nom du type de mot-cle KW_*        }
{ ------------------------------------------------------------ }

Function KwTypeName(KW : Integer) : TString;
Begin
  Case KW Of
    KW_FALSE     : KwTypeName := 'KW_FALSE';
    KW_PY_NONE   : KwTypeName := 'KW_PY_NONE';
    KW_TRUE      : KwTypeName := 'KW_TRUE';
    KW_AND       : KwTypeName := 'KW_AND';
    KW_OR        : KwTypeName := 'KW_OR';
    KW_NOT       : KwTypeName := 'KW_NOT';
    KW_IF        : KwTypeName := 'KW_IF';
    KW_ELIF      : KwTypeName := 'KW_ELIF';
    KW_ELSE      : KwTypeName := 'KW_ELSE';
    KW_WHILE     : KwTypeName := 'KW_WHILE';
    KW_FOR       : KwTypeName := 'KW_FOR';
    KW_BREAK     : KwTypeName := 'KW_BREAK';
    KW_CONTINUE  : KwTypeName := 'KW_CONTINUE';
    KW_PASS      : KwTypeName := 'KW_PASS';
    KW_RETURN    : KwTypeName := 'KW_RETURN';
    KW_YIELD     : KwTypeName := 'KW_YIELD';
    KW_DEF       : KwTypeName := 'KW_DEF';
    KW_CLASS     : KwTypeName := 'KW_CLASS';
    KW_LAMBDA    : KwTypeName := 'KW_LAMBDA';
    KW_TRY       : KwTypeName := 'KW_TRY';
    KW_EXCEPT    : KwTypeName := 'KW_EXCEPT';
    KW_FINALLY   : KwTypeName := 'KW_FINALLY';
    KW_RAISE     : KwTypeName := 'KW_RAISE';
    KW_ASSERT    : KwTypeName := 'KW_ASSERT';
    KW_IMPORT    : KwTypeName := 'KW_IMPORT';
    KW_FROM      : KwTypeName := 'KW_FROM';
    KW_AS        : KwTypeName := 'KW_AS';
    KW_GLOBAL    : KwTypeName := 'KW_GLOBAL';
    KW_NONLOCAL  : KwTypeName := 'KW_NONLOCAL';
    KW_IN        : KwTypeName := 'KW_IN';
    KW_IS        : KwTypeName := 'KW_IS';
    KW_DEL       : KwTypeName := 'KW_DEL';
    KW_WITH      : KwTypeName := 'KW_WITH';
    KW_ASYNC     : KwTypeName := 'KW_ASYNC';
    KW_AWAIT     : KwTypeName := 'KW_AWAIT';
  Else
    KwTypeName := 'KW_UNKNOWN(' + ItoS(KW) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ LookupKeyword : retourner KW_xxx ou KW_NONE si non reconnu   }
{ Python est sensible a la casse                                }
{ ------------------------------------------------------------ }

Function LookupKeyword(Const S : TString) : Integer;
Var
  R : Integer;
Begin
  Inc(KwLookupCount);
  Inc(KwTotalIdents);
  R := 0;

  { Constantes }
  If      S = 'False'    Then R := KW_FALSE
  Else If S = 'None'     Then R := KW_PY_NONE
  Else If S = 'True'     Then R := KW_TRUE

  { Logiques }
  Else If S = 'and'      Then R := KW_AND
  Else If S = 'or'       Then R := KW_OR
  Else If S = 'not'      Then R := KW_NOT

  { Controle }
  Else If S = 'if'       Then R := KW_IF
  Else If S = 'elif'     Then R := KW_ELIF
  Else If S = 'else'     Then R := KW_ELSE
  Else If S = 'while'    Then R := KW_WHILE
  Else If S = 'for'      Then R := KW_FOR
  Else If S = 'break'    Then R := KW_BREAK
  Else If S = 'continue' Then R := KW_CONTINUE
  Else If S = 'pass'     Then R := KW_PASS
  Else If S = 'return'   Then R := KW_RETURN
  Else If S = 'yield'    Then R := KW_YIELD

  { Definitions }
  Else If S = 'def'      Then R := KW_DEF
  Else If S = 'class'    Then R := KW_CLASS
  Else If S = 'lambda'   Then R := KW_LAMBDA

  { Exceptions }
  Else If S = 'try'      Then R := KW_TRY
  Else If S = 'except'   Then R := KW_EXCEPT
  Else If S = 'finally'  Then R := KW_FINALLY
  Else If S = 'raise'    Then R := KW_RAISE
  Else If S = 'assert'   Then R := KW_ASSERT

  { Importation }
  Else If S = 'import'   Then R := KW_IMPORT
  Else If S = 'from'     Then R := KW_FROM
  Else If S = 'as'       Then R := KW_AS

  { Portee }
  Else If S = 'global'   Then R := KW_GLOBAL
  Else If S = 'nonlocal' Then R := KW_NONLOCAL

  { Operations }
  Else If S = 'in'       Then R := KW_IN
  Else If S = 'is'       Then R := KW_IS
  Else If S = 'del'      Then R := KW_DEL
  Else If S = 'with'     Then R := KW_WITH

  { Asynchrone (reserve, non supporte) }
  Else If S = 'async'    Then R := KW_ASYNC
  Else If S = 'await'    Then R := KW_AWAIT;

  If R <> 0 Then
  Begin
    Inc(KwHitCount);
    KwLastKW := R;
  End;

  LookupKeyword := R;
End;

{ ------------------------------------------------------------ }
{ GetKeywordName : retourner le mot-cle Python pour un KW_*    }
{ ------------------------------------------------------------ }

Function GetKeywordName(KW : Integer) : TString;
Begin
  Case KW Of
    KW_FALSE     : GetKeywordName := 'False';
    KW_PY_NONE   : GetKeywordName := 'None';
    KW_TRUE      : GetKeywordName := 'True';
    KW_AND       : GetKeywordName := 'and';
    KW_OR        : GetKeywordName := 'or';
    KW_NOT       : GetKeywordName := 'not';
    KW_IF        : GetKeywordName := 'if';
    KW_ELIF      : GetKeywordName := 'elif';
    KW_ELSE      : GetKeywordName := 'else';
    KW_WHILE     : GetKeywordName := 'while';
    KW_FOR       : GetKeywordName := 'for';
    KW_BREAK     : GetKeywordName := 'break';
    KW_CONTINUE  : GetKeywordName := 'continue';
    KW_PASS      : GetKeywordName := 'pass';
    KW_RETURN    : GetKeywordName := 'return';
    KW_YIELD     : GetKeywordName := 'yield';
    KW_DEF       : GetKeywordName := 'def';
    KW_CLASS     : GetKeywordName := 'class';
    KW_LAMBDA    : GetKeywordName := 'lambda';
    KW_TRY       : GetKeywordName := 'try';
    KW_EXCEPT    : GetKeywordName := 'except';
    KW_FINALLY   : GetKeywordName := 'finally';
    KW_RAISE     : GetKeywordName := 'raise';
    KW_ASSERT    : GetKeywordName := 'assert';
    KW_IMPORT    : GetKeywordName := 'import';
    KW_FROM      : GetKeywordName := 'from';
    KW_AS        : GetKeywordName := 'as';
    KW_GLOBAL    : GetKeywordName := 'global';
    KW_NONLOCAL  : GetKeywordName := 'nonlocal';
    KW_IN        : GetKeywordName := 'in';
    KW_IS        : GetKeywordName := 'is';
    KW_DEL       : GetKeywordName := 'del';
    KW_WITH      : GetKeywordName := 'with';
    KW_ASYNC     : GetKeywordName := 'async';
    KW_AWAIT     : GetKeywordName := 'await';
  Else
    GetKeywordName := '?';
  End;
End;

{ ------------------------------------------------------------ }
{ LookupBuiltin : retourner BI_xxx ou 0 si non reconnu          }
{ Python est sensible a la casse                                }
{ ------------------------------------------------------------ }

Function LookupBuiltin(Const S : TString) : Integer;
Var
  R : Integer;
Begin
  Inc(BiLookupCount);
  R := 0;

  If      S = 'print'      Then R := BI_PRINT
  Else If S = 'input'      Then R := BI_INPUT
  Else If S = 'len'        Then R := BI_LEN
  Else If S = 'str'        Then R := BI_STR
  Else If S = 'int'        Then R := BI_INT
  Else If S = 'float'      Then R := BI_FLOAT
  Else If S = 'bool'       Then R := BI_BOOL
  Else If S = 'list'       Then R := BI_LIST
  Else If S = 'dict'       Then R := BI_DICT
  Else If S = 'tuple'      Then R := BI_TUPLE
  Else If S = 'range'      Then R := BI_RANGE
  Else If S = 'abs'        Then R := BI_ABS
  Else If S = 'ord'        Then R := BI_ORD
  Else If S = 'chr'        Then R := BI_CHR
  Else If S = 'hex'        Then R := BI_HEX
  Else If S = 'oct'        Then R := BI_OCT
  Else If S = 'bin'        Then R := BI_BIN
  Else If S = 'type'       Then R := BI_TYPE
  Else If S = 'isinstance' Then R := BI_ISINSTANCE
  Else If S = 'min'        Then R := BI_MIN
  Else If S = 'max'        Then R := BI_MAX
  Else If S = 'pow'        Then R := BI_POW
  Else If S = 'round'      Then R := BI_ROUND
  Else If S = 'sorted'     Then R := BI_SORTED
  Else If S = 'reversed'   Then R := BI_REVERSED
  Else If S = 'enumerate'  Then R := BI_ENUMERATE
  Else If S = 'zip'        Then R := BI_ZIP
  Else If S = 'map'        Then R := BI_MAP
  Else If S = 'filter'     Then R := BI_FILTER
  Else If S = 'sum'        Then R := BI_SUM
  Else If S = 'any'        Then R := BI_ANY
  Else If S = 'all'        Then R := BI_ALL
  Else If S = 'hasattr'    Then R := BI_HASATTR
  Else If S = 'getattr'    Then R := BI_GETATTR
  Else If S = 'setattr'    Then R := BI_SETATTR
  Else If S = 'id'         Then R := BI_ID
  Else If S = 'hash'       Then R := BI_HASH
  Else If S = 'repr'       Then R := BI_REPR
  Else If S = 'open'       Then R := BI_OPEN;

  If R <> 0 Then
  Begin
    Inc(BiHitCount);
    KwLastBI := R;
  End;

  LookupBuiltin := R;
End;

{ ------------------------------------------------------------ }
{ GetBuiltinName : retourner le nom Python pour un BI_*        }
{ ------------------------------------------------------------ }

Function GetBuiltinName(BI : Integer) : TString;
Begin
  Case BI Of
    BI_PRINT       : GetBuiltinName := 'print';
    BI_INPUT       : GetBuiltinName := 'input';
    BI_LEN         : GetBuiltinName := 'len';
    BI_STR         : GetBuiltinName := 'str';
    BI_INT         : GetBuiltinName := 'int';
    BI_FLOAT       : GetBuiltinName := 'float';
    BI_BOOL        : GetBuiltinName := 'bool';
    BI_LIST        : GetBuiltinName := 'list';
    BI_DICT        : GetBuiltinName := 'dict';
    BI_TUPLE       : GetBuiltinName := 'tuple';
    BI_RANGE       : GetBuiltinName := 'range';
    BI_ABS         : GetBuiltinName := 'abs';
    BI_ORD         : GetBuiltinName := 'ord';
    BI_CHR         : GetBuiltinName := 'chr';
    BI_HEX         : GetBuiltinName := 'hex';
    BI_OCT         : GetBuiltinName := 'oct';
    BI_BIN         : GetBuiltinName := 'bin';
    BI_TYPE        : GetBuiltinName := 'type';
    BI_ISINSTANCE  : GetBuiltinName := 'isinstance';
    BI_MIN         : GetBuiltinName := 'min';
    BI_MAX         : GetBuiltinName := 'max';
    BI_POW         : GetBuiltinName := 'pow';
    BI_ROUND       : GetBuiltinName := 'round';
    BI_SORTED      : GetBuiltinName := 'sorted';
    BI_REVERSED    : GetBuiltinName := 'reversed';
    BI_ENUMERATE   : GetBuiltinName := 'enumerate';
    BI_ZIP         : GetBuiltinName := 'zip';
    BI_MAP         : GetBuiltinName := 'map';
    BI_FILTER      : GetBuiltinName := 'filter';
    BI_SUM         : GetBuiltinName := 'sum';
    BI_ANY         : GetBuiltinName := 'any';
    BI_ALL         : GetBuiltinName := 'all';
    BI_HASATTR     : GetBuiltinName := 'hasattr';
    BI_GETATTR     : GetBuiltinName := 'getattr';
    BI_SETATTR     : GetBuiltinName := 'setattr';
    BI_ID          : GetBuiltinName := 'id';
    BI_HASH        : GetBuiltinName := 'hash';
    BI_REPR        : GetBuiltinName := 'repr';
    BI_OPEN        : GetBuiltinName := 'open';
  Else
    GetBuiltinName := '?';
  End;
End;

{ ------------------------------------------------------------ }
{ IsKeyword : teste si un KW_* est valide (non zero)           }
{ ------------------------------------------------------------ }

Function IsKeyword(KW : Integer) : Boolean;
Begin
  IsKeyword := (KW > 0) And (KW <= KW_AWAIT);
End;

{ ------------------------------------------------------------ }
{ IsBuiltin : teste si un BI_* est valide (non zero)           }
{ ------------------------------------------------------------ }

Function IsBuiltin(BI : Integer) : Boolean;
Begin
  IsBuiltin := (BI > 0) And (BI <= BI_TOTAL_BUILTINS);
End;

{ ------------------------------------------------------------ }
{ DumpKwState : afficher l etat de la reconnaissance           }
{ ------------------------------------------------------------ }

Procedure DumpKwState;
Begin
  WriteLn('--- KW State ---');
  WriteLn('  KwInitialized : ', KwInitialized);
  WriteLn('  KwLookupCount : ', KwLookupCount);
  WriteLn('  KwHitCount    : ', KwHitCount);
  WriteLn('  BiLookupCount : ', BiLookupCount);
  WriteLn('  BiHitCount    : ', BiHitCount);
  WriteLn('  KwTotalIdents : ', KwTotalIdents);
  WriteLn('  KwLastKW      : ', KwTypeName(KwLastKW));
  WriteLn('  KwLastBI      : ', GetBuiltinName(KwLastBI));
  WriteLn('  Keywords      : ', KW_TOTAL_KEYWORDS);
  WriteLn('  Builtins      : ', BI_TOTAL_BUILTINS);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 03)                             }
{ ------------------------------------------------------------ }

Function IsKwInitialized : Boolean;
Begin
  IsKwInitialized := KwInitialized;
End;

Function IsKwEmpty : Boolean;
Begin
  IsKwEmpty := (KwHitCount = 0) And (BiHitCount = 0);
End;

Function GetKwLookupCount : LongInt;
Begin
  GetKwLookupCount := KwLookupCount;
End;

Function GetKwHitCount : LongInt;
Begin
  GetKwHitCount := KwHitCount;
End;

Function GetBiLookupCount : LongInt;
Begin
  GetBiLookupCount := BiLookupCount;
End;

Function GetBiHitCount : LongInt;
Begin
  GetBiHitCount := BiHitCount;
End;

Function GetKwTotalIdents : LongInt;
Begin
  GetKwTotalIdents := KwTotalIdents;
End;

Function GetKwLastKW : Integer;
Begin
  GetKwLastKW := KwLastKW;
End;

Function GetKwLastBI : Integer;
Begin
  GetKwLastBI := KwLastBI;
End;

Function GetKwStatus : TString;
Begin
  If Not KwInitialized Then
    GetKwStatus := 'Not initialized'
  Else
    GetKwStatus := ItoS(KwHitCount) + ' keywords, ' +
                   ItoS(BiHitCount) + ' builtins (' +
                   ItoS(KwTotalIdents) + ' idents tested)';
End;

{ ============================================================ }
{ TODO 04 - TABLE DES SYMBOLES PYTHON (32 BITS) [IMPLEMENTE]   }
{ ============================================================ }

Const
  { Types de symboles SK_* }
  SK_NONE    = 0;    { aucun / non defini                       }
  SK_VAR     = 1;    { variable Python                          }
  SK_PARAM   = 2;    { parametre de fonction                    }
  SK_FUNC    = 3;    { fonction (def)                           }
  SK_CLASS   = 4;    { classe (class)                           }
  SK_MODULE  = 5;    { module importe                           }
  SK_BUILTIN = 6;    { builtin Python (print, len, ...)         }
  SK_GLOBAL  = 7;    { variable globale (instruction global)    }
  SK_LOCAL   = 8;    { variable locale explicite                }
  SK_MAX     = 8;    { valeur maximale SK_*                     }

Type
  TSymRec = Record
    Name       : TString;       { nom Python (x, my_func, MyClass)   }
    AsmName    : TString;       { label ASM (_PYV_x, _PYF_my_func)   }
    Kind       : Integer;       { SK_VAR..SK_LOCAL                    }
    TypeIdx    : Integer;       { indice dans la table des types      }
    Offset     : LongInt;       { offset segment data ou pile         }
    ScopeLevel : Integer;       { niveau de portee imbrique           }
    IsGlobal   : Boolean;       { True si 'global x'                  }
    IsNonlocal : Boolean;       { True si 'nonlocal x'                }
    IsImported : Boolean;       { True si importe (import/from)       }
    DeclLine   : Integer;       { numero de ligne de declaration      }
  End;

Var
  SymTab          : Array[0..MAX_SYM-1] Of TSymRec;
  SymTabCount     : Integer;       { nombre de symboles dans la table    }
  CurScope        : Integer;       { niveau de portee courant            }
  ScopeStack      : Array[0..MAX_SCOPE-1] Of Integer;
  ScopeTop        : Integer;       { sommet de la pile de portee         }
  SymInitialized  : Boolean;       { True si l etat est initialise       }
  SymLabelSeq     : Integer;       { sequence pour labels uniques        }
  SymAddCount     : LongInt;       { nombre total de SymAdd              }
  SymFindCount    : LongInt;       { nombre total de SymFind             }
  SymFindHit      : LongInt;       { nombre de SymFind avec resultat     }
  SymScopeEnter   : LongInt;       { nombre de SymEnterScope             }
  SymScopeLeave   : LongInt;       { nombre de SymLeaveScope             }
  SymLastName     : TString;       { dernier nom ajoute/cherche          }

{ ------------------------------------------------------------ }
{ SymInit : initialiser la table des symboles                   }
{ ------------------------------------------------------------ }

Procedure SymInit;
Var I : Integer;
Begin
  SymInitialized := True;
  SymTabCount    := 0;
  CurScope       := 0;
  ScopeTop       := 0;
  SymLabelSeq    := 0;
  SymAddCount    := 0;
  SymFindCount   := 0;
  SymFindHit     := 0;
  SymScopeEnter  := 0;
  SymScopeLeave  := 0;
  SymLastName    := '';
  For I := 0 To MAX_SCOPE - 1 Do
    ScopeStack[I] := 0;
End;

{ ------------------------------------------------------------ }
{ GenSymLabel : generer un label unique _SYM_N                  }
{ ------------------------------------------------------------ }

Function GenSymLabel : TString;
Begin
  Inc(SymLabelSeq);
  GenSymLabel := '_SYM_' + ItoS(SymLabelSeq);
End;

{ ------------------------------------------------------------ }
{ SymKindName : retourner le nom du type de symbole SK_*        }
{ ------------------------------------------------------------ }

Function SymKindName(K : Integer) : TString;
Begin
  Case K Of
    SK_NONE    : SymKindName := 'SK_NONE';
    SK_VAR     : SymKindName := 'SK_VAR';
    SK_PARAM   : SymKindName := 'SK_PARAM';
    SK_FUNC    : SymKindName := 'SK_FUNC';
    SK_CLASS   : SymKindName := 'SK_CLASS';
    SK_MODULE  : SymKindName := 'SK_MODULE';
    SK_BUILTIN : SymKindName := 'SK_BUILTIN';
    SK_GLOBAL  : SymKindName := 'SK_GLOBAL';
    SK_LOCAL   : SymKindName := 'SK_LOCAL';
  Else
    SymKindName := 'SK_?(' + ItoS(K) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ SymNameClean : nettoyer un nom Python pour usage ASM          }
{ Remplacer les caracteres non valides pour un label ASM        }
{ ------------------------------------------------------------ }

Function SymNameClean(Const S : TString) : TString;
Var
  R    : TString;
  I    : Integer;
  Ch   : Char;
Begin
  R := '';
  For I := 1 To Length(S) Do
  Begin
    Ch := S[I];
    If ((Ch >= 'A') And (Ch <= 'Z')) Or
       ((Ch >= 'a') And (Ch <= 'z')) Or
       ((Ch >= '0') And (Ch <= '9')) Or
       (Ch = '_') Then
      R := R + Ch
    Else
      R := R + '_';
  End;
  SymNameClean := R;
End;

{ ------------------------------------------------------------ }
{ SymMangle : generer le label ASM pour un symbole              }
{ Prefixe selon le type (SK_VAR -> _PYV_, SK_FUNC -> _PYF_...) }
{ ------------------------------------------------------------ }

Function SymMangle(Const Name : TString; Kind : Integer) : TString;
Var
  Clean : TString;
Begin
  Clean := SymNameClean(Name);
  Case Kind Of
    SK_FUNC    : SymMangle := PY_FN_PFX + Clean;
    SK_CLASS   : SymMangle := PY_CLS_PFX + Clean;
    SK_MODULE  : SymMangle := PY_VAR_PFX + 'mod_' + Clean;
    SK_BUILTIN : SymMangle := PY_RT_PFX + Clean;
  Else
    SymMangle := PY_VAR_PFX + Clean;
  End;
End;

{ ------------------------------------------------------------ }
{ SymAdd : ajouter un symbole a la table                        }
{ Retourne l indice du symbole ajoute, ou -1 si table pleine   }
{ ------------------------------------------------------------ }

Function SymAdd(Const Name : TString; Kind : Integer;
                TypeIdx : Integer; DeclLine : Integer) : Integer;
Var
  Idx : Integer;
Begin
  If SymTabCount >= MAX_SYM Then
  Begin
    CompileError('Symbol table full (max ' + ItoS(MAX_SYM) + ')',
                 DeclLine);
    SymAdd := -1;
    Exit;
  End;
  Idx := SymTabCount;
  SymTab[Idx].Name       := Name;
  SymTab[Idx].AsmName    := SymMangle(Name, Kind);
  SymTab[Idx].Kind       := Kind;
  SymTab[Idx].TypeIdx    := TypeIdx;
  SymTab[Idx].Offset     := 0;
  SymTab[Idx].ScopeLevel := CurScope;
  SymTab[Idx].IsGlobal   := False;
  SymTab[Idx].IsNonlocal := False;
  SymTab[Idx].IsImported := False;
  SymTab[Idx].DeclLine   := DeclLine;
  Inc(SymTabCount);
  Inc(SymAddCount);
  SymLastName := Name;
  SymAdd := Idx;
End;

{ ------------------------------------------------------------ }
{ SymFind : rechercher un symbole par nom (derniere occurrence) }
{ Resolution : local -> englobant -> global -> builtins         }
{ Retourne l indice ou -1 si non trouve                         }
{ ------------------------------------------------------------ }

Function SymFind(Const Name : TString) : Integer;
Var
  I      : Integer;
  Result : Integer;
Begin
  Inc(SymFindCount);
  SymLastName := Name;
  Result := -1;
  { Parcourir du dernier au premier (portee la plus recente) }
  For I := SymTabCount - 1 DownTo 0 Do
  Begin
    If SymTab[I].Name = Name Then
    Begin
      Result := I;
      Inc(SymFindHit);
      Break;
    End;
  End;
  SymFind := Result;
End;

{ ------------------------------------------------------------ }
{ SymFindInScope : rechercher un symbole dans une portee donnee }
{ Retourne l indice ou -1 si non trouve                         }
{ ------------------------------------------------------------ }

Function SymFindInScope(Const Name : TString;
                        Scope : Integer) : Integer;
Var
  I      : Integer;
  Result : Integer;
Begin
  Result := -1;
  For I := SymTabCount - 1 DownTo 0 Do
  Begin
    If (SymTab[I].Name = Name) And
       (SymTab[I].ScopeLevel = Scope) Then
    Begin
      Result := I;
      Break;
    End;
  End;
  SymFindInScope := Result;
End;

{ ------------------------------------------------------------ }
{ SymEnterScope : entrer dans une nouvelle portee               }
{ ------------------------------------------------------------ }

Procedure SymEnterScope;
Begin
  If ScopeTop >= MAX_SCOPE Then
  Begin
    CompileError('Scope nesting overflow (max ' +
                 ItoS(MAX_SCOPE) + ')', LexLineNo);
    Exit;
  End;
  ScopeStack[ScopeTop] := SymTabCount;
  Inc(ScopeTop);
  Inc(CurScope);
  Inc(SymScopeEnter);
End;

{ ------------------------------------------------------------ }
{ SymLeaveScope : quitter la portee courante                    }
{ Les symboles de la portee restent dans la table (pour debug)  }
{ mais ne seront plus trouves par SymFind si le scope est filtre}
{ ------------------------------------------------------------ }

Procedure SymLeaveScope;
Begin
  If ScopeTop <= 0 Then
  Begin
    CompileError('Scope underflow', LexLineNo);
    Exit;
  End;
  Dec(ScopeTop);
  Dec(CurScope);
  Inc(SymScopeLeave);
End;

{ ------------------------------------------------------------ }
{ GetSymCount : retourner le nombre de symboles dans la table   }
{ ------------------------------------------------------------ }

Function GetSymCount : Integer;
Begin
  GetSymCount := SymTabCount;
End;

{ ------------------------------------------------------------ }
{ SymDump : afficher tous les symboles de la table              }
{ ------------------------------------------------------------ }

Procedure SymDump;
Var I : Integer;
Begin
  WriteLn('--- Symbol Table (', SymTabCount, ' entries) ---');
  For I := 0 To SymTabCount - 1 Do
  Begin
    WriteLn('  [', I, '] ', SymTab[I].Name,
            ' -> ', SymTab[I].AsmName,
            '  kind=', SymKindName(SymTab[I].Kind),
            '  type=', SymTab[I].TypeIdx,
            '  scope=', SymTab[I].ScopeLevel,
            '  line=', SymTab[I].DeclLine);
    If SymTab[I].IsGlobal Then
      WriteLn('       global=True');
    If SymTab[I].IsNonlocal Then
      WriteLn('       nonlocal=True');
    If SymTab[I].IsImported Then
      WriteLn('       imported=True');
  End;
End;

{ ------------------------------------------------------------ }
{ DumpSymState : afficher l etat de la table des symboles       }
{ ------------------------------------------------------------ }

Procedure DumpSymState;
Begin
  WriteLn('--- Sym State ---');
  WriteLn('  SymInitialized : ', SymInitialized);
  WriteLn('  SymTabCount    : ', SymTabCount);
  WriteLn('  CurScope       : ', CurScope);
  WriteLn('  ScopeTop       : ', ScopeTop);
  WriteLn('  SymLabelSeq    : ', SymLabelSeq);
  WriteLn('  SymAddCount    : ', SymAddCount);
  WriteLn('  SymFindCount   : ', SymFindCount);
  WriteLn('  SymFindHit     : ', SymFindHit);
  WriteLn('  SymScopeEnter  : ', SymScopeEnter);
  WriteLn('  SymScopeLeave  : ', SymScopeLeave);
  WriteLn('  SymLastName    : ', SymLastName);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 04)                             }
{ ------------------------------------------------------------ }

Function IsSymInitialized : Boolean;
Begin
  IsSymInitialized := SymInitialized;
End;

Function IsSymEmpty : Boolean;
Begin
  IsSymEmpty := (SymTabCount = 0);
End;

Function GetSymTabCount : Integer;
Begin
  GetSymTabCount := SymTabCount;
End;

Function GetSymAddCount : LongInt;
Begin
  GetSymAddCount := SymAddCount;
End;

Function GetSymFindCount : LongInt;
Begin
  GetSymFindCount := SymFindCount;
End;

Function GetSymFindHit : LongInt;
Begin
  GetSymFindHit := SymFindHit;
End;

Function GetSymCurScope : Integer;
Begin
  GetSymCurScope := CurScope;
End;

Function GetSymScopeTop : Integer;
Begin
  GetSymScopeTop := ScopeTop;
End;

Function GetSymLastName : TString;
Begin
  GetSymLastName := SymLastName;
End;

Function GetSymStatus : TString;
Begin
  If Not SymInitialized Then
    GetSymStatus := 'Not initialized'
  Else
    GetSymStatus := ItoS(SymTabCount) + ' symbols, scope=' +
                    ItoS(CurScope) + ' (' +
                    ItoS(SymAddCount) + ' adds, ' +
                    ItoS(SymFindCount) + ' finds)';
End;

{ ============================================================ }
{ Procedure Run (stub pour les futurs TODOs)                   }
{ ============================================================ }

Procedure Run;
Begin
  { Initialisation des compteurs }
  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  OutFOpen   := False;
  BcActive   := False;
  LexOpened  := False;
  KwInitialized := False;
  SymInitialized := False;

  ParseArgs;

  { Affichage de la banniere en mode verbeux }
  ShowBanner;

  { Initialiser la reconnaissance des mots-cles }
  InitKwState;

  { Initialiser la table des symboles }
  SymInit;

  { Ouvrir le fichier source et initialiser le lexeur }
  LexInit;

  { Lire le premier token }
  LexNextToken;

  { --- Les futurs TODOs ajouteront ici le parseur Python --- }
  { --- et la generation de code, etc.                    --- }

  { Fermer le fichier source }
  LexClose;

  { Statistiques finales }
  ShowStats;
  If Opts.Verbose Then
  Begin
    WriteLn('Tokens analyses  : ', GetLexTokCount);
    WriteLn('Mots-cles trouves: ', GetKwHitCount);
    WriteLn('Builtins trouves : ', GetBiHitCount);
    WriteLn('Symboles definis : ', GetSymTabCount);
  End;

  If Opts.DebugMode Then
  Begin
    DumpKwState;
    DumpSymState;
  End;

  { Nettoyage }
  Cleanup;
End;

{ ============================================================ }
{ Programme principal                                          }
{ ============================================================ }

Begin
  Run;
End.
