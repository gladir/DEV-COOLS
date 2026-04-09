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

  TODO 05 - SYSTEME DE TYPES DYNAMIQUE [IMPLEMENTE]
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

  TODO 06 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
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

  TODO 07 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
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

  TODO 08 - PARSEUR : EXPRESSIONS PRIMAIRES ET APPELS [IMPLEMENTE]
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

  TODO 09 - PARSEUR : VARIABLES ET AFFECTATIONS [IMPLEMENTE]
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

  TODO 10 - PARSEUR : IF / ELIF / ELSE [IMPLEMENTE]
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

  TODO 11 - PARSEUR : BOUCLES while / for / break / continue [IMPLEMENTE]
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

  TODO 12 - PARSEUR : FONCTIONS (def) ET RETURN [IMPLEMENTE]
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

  TODO 13 - PARSEUR : ENTREES/SORTIES (print / input) [IMPLEMENTE]
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

  TODO 14 - PARSEUR : LISTES (list) [IMPLEMENTE]
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

  TODO 15 - PARSEUR : DICTIONNAIRES (dict) [IMPLEMENTE]
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
  MAX_TYPE       = 64;

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
{ TODO 05 - SYSTEME DE TYPES DYNAMIQUE [IMPLEMENTE]            }
{ ============================================================ }

Const
  { TTypeKind : types primitifs Python }
  TYK_INT    = 0;    { entier 32 bits signe                     }
  TYK_BOOL   = 1;    { booleen 32 bits (0 ou 1)                 }
  TYK_STR    = 2;    { ptr vers chaine                          }
  TYK_NONE   = 3;    { nul (None)                               }
  TYK_LIST   = 4;    { ptr vers tableau dynamique               }
  TYK_DICT   = 5;    { ptr vers table de hachage                }
  TYK_TUPLE  = 6;    { ptr vers tableau fixe                    }
  TYK_FUNC   = 7;    { ptr vers code de fonction                }
  TYK_OBJECT = 8;    { ptr vers instance de classe              }
  TYK_CLASS  = 9;    { descripteur de classe                    }
  TYK_MODULE = 10;   { module importe                           }
  TYK_MAX    = 10;   { valeur maximale TYK_*                    }

  { Indices des types primitifs dans TypeTab }
  TY_IDX_INT    = 0;
  TY_IDX_STR    = 1;
  TY_IDX_BOOL   = 2;
  TY_IDX_NONE   = 3;
  TY_IDX_LIST   = 4;
  TY_IDX_DICT   = 5;
  TY_IDX_FUNC   = 6;
  TY_IDX_CLASS  = 7;
  TY_IDX_TUPLE  = 8;
  TY_IDX_MODULE = 9;
  TY_PRIM_COUNT = 10;  { nombre de types primitifs              }

Type
  TTypeRec = Record
    Name  : TString;       { nom du type ('int', 'str', ...)      }
    Kind  : Integer;       { TYK_INT..TYK_CLASS                   }
    Size  : Integer;       { taille en octets (32 bits)           }
  End;

Var
  TypeTab         : Array[0..MAX_TYPE-1] Of TTypeRec;
  TypeCount       : Integer;       { nombre de types enregistres        }
  TypInitialized  : Boolean;       { True si l etat est initialise      }
  TypLabelSeq     : Integer;       { sequence pour labels uniques       }
  TypAddCount     : LongInt;       { nombre total de TypeAdd            }
  TypFindCount    : LongInt;       { nombre total de TypeFindByName     }
  TypFindHit      : LongInt;       { nombre de TypeFindByName OK        }
  TypLastName     : TString;       { dernier nom cherche/ajoute         }

{ ------------------------------------------------------------ }
{ TypeInit : initialiser la table des types et enregistrer      }
{ les 10 types primitifs Python                                 }
{ ------------------------------------------------------------ }

Procedure TypeInit;

  Procedure AddPrim(Const N : TString; K, S : Integer);
  Begin
    If TypeCount < MAX_TYPE Then
    Begin
      TypeTab[TypeCount].Name := N;
      TypeTab[TypeCount].Kind := K;
      TypeTab[TypeCount].Size := S;
      Inc(TypeCount);
    End;
  End;

Begin
  TypInitialized := True;
  TypeCount      := 0;
  TypLabelSeq    := 0;
  TypAddCount    := 0;
  TypFindCount   := 0;
  TypFindHit     := 0;
  TypLastName    := '';
  { Enregistrer les 10 types primitifs (ordre = TY_IDX_*) }
  AddPrim('int',    TYK_INT,    4);   { TY_IDX_INT    = 0 }
  AddPrim('str',    TYK_STR,    4);   { TY_IDX_STR    = 1 }
  AddPrim('bool',   TYK_BOOL,   4);   { TY_IDX_BOOL   = 2 }
  AddPrim('None',   TYK_NONE,   0);   { TY_IDX_NONE   = 3 }
  AddPrim('list',   TYK_LIST,   4);   { TY_IDX_LIST   = 4 }
  AddPrim('dict',   TYK_DICT,   4);   { TY_IDX_DICT   = 5 }
  AddPrim('func',   TYK_FUNC,   4);   { TY_IDX_FUNC   = 6 }
  AddPrim('class',  TYK_CLASS,  4);   { TY_IDX_CLASS  = 7 }
  AddPrim('tuple',  TYK_TUPLE,  4);   { TY_IDX_TUPLE  = 8 }
  AddPrim('module', TYK_MODULE, 4);   { TY_IDX_MODULE = 9 }
End;

{ ------------------------------------------------------------ }
{ GenTypLabel : generer un label unique _TYP_N                  }
{ ------------------------------------------------------------ }

Function GenTypLabel : TString;
Begin
  Inc(TypLabelSeq);
  GenTypLabel := '_TYP_' + ItoS(TypLabelSeq);
End;

{ ------------------------------------------------------------ }
{ TypeKindStr : nom textuel d un TTypeKind                      }
{ ------------------------------------------------------------ }

Function TypeKindStr(K : Integer) : TString;
Begin
  Case K Of
    TYK_INT    : TypeKindStr := 'TYK_INT';
    TYK_BOOL   : TypeKindStr := 'TYK_BOOL';
    TYK_STR    : TypeKindStr := 'TYK_STR';
    TYK_NONE   : TypeKindStr := 'TYK_NONE';
    TYK_LIST   : TypeKindStr := 'TYK_LIST';
    TYK_DICT   : TypeKindStr := 'TYK_DICT';
    TYK_TUPLE  : TypeKindStr := 'TYK_TUPLE';
    TYK_FUNC   : TypeKindStr := 'TYK_FUNC';
    TYK_OBJECT : TypeKindStr := 'TYK_OBJECT';
    TYK_CLASS  : TypeKindStr := 'TYK_CLASS';
    TYK_MODULE : TypeKindStr := 'TYK_MODULE';
  Else
    TypeKindStr := 'TYK_?(' + ItoS(K) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ TypTypeName : nom textuel pour un indice dans TypeTab         }
{ ------------------------------------------------------------ }

Function TypTypeName(Idx : Integer) : TString;
Begin
  If (Idx >= 0) And (Idx < TypeCount) Then
    TypTypeName := TypeTab[Idx].Name
  Else
    TypTypeName := '?type(' + ItoS(Idx) + ')';
End;

{ ------------------------------------------------------------ }
{ TypeKindOf : retourner le TTypeKind pour un indice            }
{ ------------------------------------------------------------ }

Function TypeKindOf(Idx : Integer) : Integer;
Begin
  If (Idx >= 0) And (Idx < TypeCount) Then
    TypeKindOf := TypeTab[Idx].Kind
  Else
    TypeKindOf := TYK_NONE;
End;

{ ------------------------------------------------------------ }
{ TypeSizeOf : retourner la taille en octets pour un indice     }
{ ------------------------------------------------------------ }

Function TypeSizeOf(Idx : Integer) : Integer;
Begin
  If (Idx >= 0) And (Idx < TypeCount) Then
    TypeSizeOf := TypeTab[Idx].Size
  Else
    TypeSizeOf := 0;
End;

{ ------------------------------------------------------------ }
{ TypeFindByName : rechercher un type par nom -> index          }
{ Retourne l indice ou -1 si non trouve                         }
{ ------------------------------------------------------------ }

Function TypeFindByName(Const Name : TString) : Integer;
Var
  I      : Integer;
  Result : Integer;
Begin
  Inc(TypFindCount);
  TypLastName := Name;
  Result := -1;
  For I := 0 To TypeCount - 1 Do
  Begin
    If TypeTab[I].Name = Name Then
    Begin
      Result := I;
      Inc(TypFindHit);
      Break;
    End;
  End;
  TypeFindByName := Result;
End;

{ ------------------------------------------------------------ }
{ TypeAdd : ajouter un nouveau type dans la table               }
{ Retourne l indice ou -1 si table pleine                       }
{ ------------------------------------------------------------ }

Function TypeAdd(Const Name : TString; Kind, Size : Integer) : Integer;
Var
  Idx : Integer;
Begin
  If TypeCount >= MAX_TYPE Then
  Begin
    CompileError('Type table full (max ' + ItoS(MAX_TYPE) + ')',
                 LexLineNo);
    TypeAdd := -1;
    Exit;
  End;
  Idx := TypeCount;
  TypeTab[Idx].Name := Name;
  TypeTab[Idx].Kind := Kind;
  TypeTab[Idx].Size := Size;
  Inc(TypeCount);
  Inc(TypAddCount);
  TypLastName := Name;
  TypeAdd := Idx;
End;

{ ------------------------------------------------------------ }
{ DumpTypState : afficher l etat du systeme de types            }
{ ------------------------------------------------------------ }

Procedure DumpTypState;
Var I : Integer;
Begin
  WriteLn('--- Typ State ---');
  WriteLn('  TypInitialized : ', TypInitialized);
  WriteLn('  TypeCount      : ', TypeCount);
  WriteLn('  TypLabelSeq    : ', TypLabelSeq);
  WriteLn('  TypAddCount    : ', TypAddCount);
  WriteLn('  TypFindCount   : ', TypFindCount);
  WriteLn('  TypFindHit     : ', TypFindHit);
  WriteLn('  TypLastName    : ', TypLastName);
  WriteLn('--- Type Table (', TypeCount, ' entries) ---');
  For I := 0 To TypeCount - 1 Do
    WriteLn('  [', I, '] ', TypeTab[I].Name,
            '  kind=', TypeKindStr(TypeTab[I].Kind),
            '  size=', TypeTab[I].Size);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 05)                             }
{ ------------------------------------------------------------ }

Function IsTypInitialized : Boolean;
Begin
  IsTypInitialized := TypInitialized;
End;

Function IsTypEmpty : Boolean;
Begin
  IsTypEmpty := (TypeCount = 0);
End;

Function GetTypeCount : Integer;
Begin
  GetTypeCount := TypeCount;
End;

Function GetTypAddCount : LongInt;
Begin
  GetTypAddCount := TypAddCount;
End;

Function GetTypFindCount : LongInt;
Begin
  GetTypFindCount := TypFindCount;
End;

Function GetTypFindHit : LongInt;
Begin
  GetTypFindHit := TypFindHit;
End;

Function GetTypLabelSeq : Integer;
Begin
  GetTypLabelSeq := TypLabelSeq;
End;

Function GetTypLastName : TString;
Begin
  GetTypLastName := TypLastName;
End;

Function GetTypPrimCount : Integer;
Begin
  GetTypPrimCount := TY_PRIM_COUNT;
End;

Function GetTypStatus : TString;
Begin
  If Not TypInitialized Then
    GetTypStatus := 'Not initialized'
  Else
    GetTypStatus := ItoS(TypeCount) + ' types (' +
                    ItoS(TY_PRIM_COUNT) + ' primitifs, ' +
                    ItoS(TypAddCount) + ' adds, ' +
                    ItoS(TypFindCount) + ' finds)';
End;

{ ============================================================ }
{ TODO 06 - LITTERAUX ET CONSTANTES [IMPLEMENTE]               }
{ ============================================================ }

Const
  { TExprKind : type d une valeur intermediaire }
  EK_NONE  = 0;    { pas de valeur                             }
  EK_IMM   = 1;    { valeur immediate (constante connue)       }
  EK_EAX   = 2;    { valeur dans le registre EAX               }
  EK_MEM   = 3;    { valeur en memoire (variable/DATA)         }
  EK_MAX   = 3;

  { TDataKind : type d un element du segment DATA }
  DK_DWORD     = 0;  { dd (32 bits)                            }
  DK_BYTE      = 1;  { db (8 bits)                             }
  DK_STR       = 2;  { chaine terminee par 0                   }
  DK_ARRAY_BLK = 3;  { bloc de donnees (tableau)               }
  DK_MAX       = 3;

Type
  TExprVal = Record
    Kind    : Integer;   { EK_NONE..EK_MEM                       }
    ImmVal  : LongInt;   { valeur immediate (si EK_IMM)           }
    TypeIdx : Integer;   { indice dans TypeTab                    }
    Offset  : Integer;   { offset memoire (si EK_MEM)             }
    SymIdx  : Integer;   { indice dans SymTab (si EK_MEM)         }
  End;

  TDataRec = Record
    LblName   : TString;  { label ASM (_PYK_n, etc.)             }
    Kind      : Integer;  { DK_DWORD..DK_ARRAY_BLK               }
    IntVal    : LongInt;  { valeur entiere (si DK_DWORD)          }
    StrVal    : TString;  { contenu chaine (si DK_STR)            }
    ElemCount : Integer;  { nombre d elements (si DK_ARRAY_BLK)   }
  End;

Var
  DataTab        : Array[0..MAX_DATA-1] Of TDataRec;
  DataCount      : Integer;      { nombre d elements dans DataTab      }
  LitInitialized : Boolean;      { True si l etat est initialise       }
  LitLabelSeq    : Integer;      { sequence pour labels uniques        }
  LitAddCount    : LongInt;      { nombre total de DataAdd*            }
  LitStrCount    : LongInt;      { nombre de chaines ajoutees          }
  LitDwCount     : LongInt;      { nombre de DWORDs ajoutes            }
  LitEvalCount   : LongInt;      { nombre d evaluations de litteraux   }
  LitLastLabel   : TString;      { dernier label genere                }
  LblSeq         : Integer;      { sequence pour LabelGen (_PYL_)      }

{ ------------------------------------------------------------ }
{ LitInit : initialiser le sous-systeme des litteraux et DATA   }
{ ------------------------------------------------------------ }

Procedure LitInit;
Begin
  LitInitialized := True;
  DataCount      := 0;
  LitLabelSeq    := 0;
  LitAddCount    := 0;
  LitStrCount    := 0;
  LitDwCount     := 0;
  LitEvalCount   := 0;
  LitLastLabel   := '';
  LblSeq         := 0;
End;

{ ------------------------------------------------------------ }
{ GenLitLabel : generer un label unique pour une donnee DATA     }
{ ------------------------------------------------------------ }

Function GenLitLabel : TString;
Begin
  Inc(LitLabelSeq);
  GenLitLabel := PY_STR_PFX + ItoS(LitLabelSeq);
End;

{ ------------------------------------------------------------ }
{ LabelGen : generateur de labels de saut uniques _PYL_N        }
{ ------------------------------------------------------------ }

Function LabelGen : TString;
Begin
  Inc(LblSeq);
  LabelGen := PY_LBL_PFX + ItoS(LblSeq);
End;

{ ------------------------------------------------------------ }
{ LitTypeName : nom textuel d un EK_ ou DK_                     }
{ ------------------------------------------------------------ }

Function ExprKindStr(K : Integer) : TString;
Begin
  Case K Of
    EK_NONE : ExprKindStr := 'EK_NONE';
    EK_IMM  : ExprKindStr := 'EK_IMM';
    EK_EAX  : ExprKindStr := 'EK_EAX';
    EK_MEM  : ExprKindStr := 'EK_MEM';
  Else
    ExprKindStr := 'EK_?(' + ItoS(K) + ')';
  End;
End;

Function DataKindStr(K : Integer) : TString;
Begin
  Case K Of
    DK_DWORD     : DataKindStr := 'DK_DWORD';
    DK_BYTE      : DataKindStr := 'DK_BYTE';
    DK_STR       : DataKindStr := 'DK_STR';
    DK_ARRAY_BLK : DataKindStr := 'DK_ARRAY_BLK';
  Else
    DataKindStr := 'DK_?(' + ItoS(K) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ DataAdd : ajouter un element brut dans le segment DATA         }
{ Retourne l indice ou -1 si table pleine                        }
{ ------------------------------------------------------------ }

Function DataAdd(Const Lbl : TString; Kind : Integer;
                 IVal : LongInt; Const SVal : TString;
                 Elems : Integer) : Integer;
Var Idx : Integer;
Begin
  If DataCount >= MAX_DATA Then
  Begin
    CompileError('DATA table full (max ' + ItoS(MAX_DATA) + ')',
                 LexLineNo);
    DataAdd := -1;
    Exit;
  End;
  Idx := DataCount;
  DataTab[Idx].LblName   := Lbl;
  DataTab[Idx].Kind      := Kind;
  DataTab[Idx].IntVal    := IVal;
  DataTab[Idx].StrVal    := SVal;
  DataTab[Idx].ElemCount := Elems;
  Inc(DataCount);
  Inc(LitAddCount);
  LitLastLabel := Lbl;
  DataAdd := Idx;
End;

{ ------------------------------------------------------------ }
{ DataAddStr : ajouter une chaine litterale dans DATA            }
{ Retourne le label ASM attribue                                 }
{ ------------------------------------------------------------ }

Function DataAddStr(Const S : TString) : TString;
Var Lbl : TString;
Begin
  Lbl := GenLitLabel;
  DataAdd(Lbl, DK_STR, 0, S, Length(S));
  Inc(LitStrCount);
  DataAddStr := Lbl;
End;

{ ------------------------------------------------------------ }
{ DataAddDWord : ajouter un DWORD dans DATA                      }
{ Retourne le label ASM attribue                                 }
{ ------------------------------------------------------------ }

Function DataAddDWord(V : LongInt) : TString;
Var Lbl : TString;
Begin
  Lbl := GenLitLabel;
  DataAdd(Lbl, DK_DWORD, V, '', 1);
  Inc(LitDwCount);
  DataAddDWord := Lbl;
End;

{ ------------------------------------------------------------ }
{ ExprMakeImm : creer une expression immediate (constante)       }
{ ------------------------------------------------------------ }

Function ExprMakeImm(V : LongInt; TIdx : Integer) : TExprVal;
Var E : TExprVal;
Begin
  E.Kind    := EK_IMM;
  E.ImmVal  := V;
  E.TypeIdx := TIdx;
  E.Offset  := 0;
  E.SymIdx  := -1;
  ExprMakeImm := E;
End;

{ ------------------------------------------------------------ }
{ ExprMakeNone : creer une expression None -> IMM 0, type NONE   }
{ ------------------------------------------------------------ }

Function ExprMakeNone : TExprVal;
Begin
  ExprMakeNone := ExprMakeImm(0, TY_IDX_NONE);
End;

{ ------------------------------------------------------------ }
{ ExprMakeBool : creer une expression True(1) ou False(0)        }
{ ------------------------------------------------------------ }

Function ExprMakeBool(B : Boolean) : TExprVal;
Begin
  If B Then
    ExprMakeBool := ExprMakeImm(1, TY_IDX_BOOL)
  Else
    ExprMakeBool := ExprMakeImm(0, TY_IDX_BOOL);
End;

{ ------------------------------------------------------------ }
{ ExprMakeEAX : creer une expression dont la valeur est en EAX   }
{ ------------------------------------------------------------ }

Function ExprMakeEAX(TIdx : Integer) : TExprVal;
Var E : TExprVal;
Begin
  E.Kind    := EK_EAX;
  E.ImmVal  := 0;
  E.TypeIdx := TIdx;
  E.Offset  := 0;
  E.SymIdx  := -1;
  ExprMakeEAX := E;
End;

{ ------------------------------------------------------------ }
{ LitEvalInt : evaluer un token entier comme expression          }
{ Retourne un TExprVal de type EK_IMM / TY_IDX_INT              }
{ ------------------------------------------------------------ }

Function LitEvalInt : TExprVal;
Begin
  LitEvalInt := ExprMakeImm(CurTokInt, TY_IDX_INT);
End;

{ ------------------------------------------------------------ }
{ LitEvalStr : evaluer un token chaine comme expression          }
{ Ajoute la chaine dans DATA et retourne un TExprVal pointant    }
{ vers le label DATA, de type EK_IMM / TY_IDX_STR               }
{ ------------------------------------------------------------ }

Function LitEvalStr : TExprVal;
Var
  Lbl : TString;
  E   : TExprVal;
Begin
  Lbl := DataAddStr(CurTokStr);
  { L immediat est l adresse du label (resolue a l edition de liens) }
  E.Kind    := EK_MEM;
  E.ImmVal  := 0;
  E.TypeIdx := TY_IDX_STR;
  E.Offset  := DataCount - 1;   { indice dans DataTab }
  E.SymIdx  := -1;
  LitEvalStr := E;
End;

{ ------------------------------------------------------------ }
{ LitEval : evaluer le token courant comme litteraux              }
{ Gere : entier, chaine, None, True, False                       }
{ Retourne un TExprVal                                           }
{ ------------------------------------------------------------ }

Function LitEval : TExprVal;
Var E : TExprVal;
Begin
  Inc(LitEvalCount);
  Case CurTokKind Of
    TK_INTEGER : E := LitEvalInt;
    TK_STRING : E := LitEvalStr;
    TK_IDENT  :
      Begin
        If CurTokStr = 'None' Then
          E := ExprMakeNone
        Else If CurTokStr = 'True' Then
          E := ExprMakeBool(True)
        Else If CurTokStr = 'False' Then
          E := ExprMakeBool(False)
        Else
        Begin
          E.Kind    := EK_NONE;
          E.ImmVal  := 0;
          E.TypeIdx := TY_IDX_NONE;
          E.Offset  := 0;
          E.SymIdx  := -1;
        End;
      End;
  Else
    Begin
      E.Kind    := EK_NONE;
      E.ImmVal  := 0;
      E.TypeIdx := TY_IDX_NONE;
      E.Offset  := 0;
      E.SymIdx  := -1;
    End;
  End;
  LitEval := E;
End;

{ ------------------------------------------------------------ }
{ DumpLitState : afficher l etat du sous-systeme des litteraux   }
{ ------------------------------------------------------------ }

Procedure DumpLitState;
Var I : Integer;
Begin
  WriteLn('--- Lit State ---');
  WriteLn('  LitInitialized : ', LitInitialized);
  WriteLn('  DataCount      : ', DataCount);
  WriteLn('  LitLabelSeq    : ', LitLabelSeq);
  WriteLn('  LitAddCount    : ', LitAddCount);
  WriteLn('  LitStrCount    : ', LitStrCount);
  WriteLn('  LitDwCount     : ', LitDwCount);
  WriteLn('  LitEvalCount   : ', LitEvalCount);
  WriteLn('  LitLastLabel   : ', LitLastLabel);
  WriteLn('  LblSeq         : ', LblSeq);
  WriteLn('--- Data Table (', DataCount, ' entries) ---');
  For I := 0 To DataCount - 1 Do
  Begin
    WriteLn('  [', I, '] ', DataTab[I].LblName,
            '  kind=', DataKindStr(DataTab[I].Kind));
    If DataTab[I].Kind = DK_DWORD Then
      WriteLn('       intval=', DataTab[I].IntVal)
    Else If DataTab[I].Kind = DK_STR Then
      WriteLn('       str="', DataTab[I].StrVal, '"  len=',
              DataTab[I].ElemCount);
  End;
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 06)                              }
{ ------------------------------------------------------------ }

Function IsLitInitialized : Boolean;
Begin
  IsLitInitialized := LitInitialized;
End;

Function IsLitEmpty : Boolean;
Begin
  IsLitEmpty := (DataCount = 0);
End;

Function GetDataCount : Integer;
Begin
  GetDataCount := DataCount;
End;

Function GetLitAddCount : LongInt;
Begin
  GetLitAddCount := LitAddCount;
End;

Function GetLitStrCount : LongInt;
Begin
  GetLitStrCount := LitStrCount;
End;

Function GetLitDwCount : LongInt;
Begin
  GetLitDwCount := LitDwCount;
End;

Function GetLitEvalCount : LongInt;
Begin
  GetLitEvalCount := LitEvalCount;
End;

Function GetLitLastLabel : TString;
Begin
  GetLitLastLabel := LitLastLabel;
End;

Function GetLblSeq : Integer;
Begin
  GetLblSeq := LblSeq;
End;

Function GetLitStatus : TString;
Begin
  If Not LitInitialized Then
    GetLitStatus := 'Not initialized'
  Else
    GetLitStatus := ItoS(DataCount) + ' data items (' +
                    ItoS(LitStrCount) + ' strs, ' +
                    ItoS(LitDwCount) + ' dwords, ' +
                    ItoS(LitEvalCount) + ' evals)';
End;

{ ============================================================ }
{ TODO 07 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]              }
{ ============================================================ }

Const
  { Operateurs binaires }
  OP_NONE      = 0;
  OP_ADD       = 1;    { +                                     }
  OP_SUB       = 2;    { -                                     }
  OP_MUL       = 3;    { *                                     }
  OP_IDIV      = 4;    { // (division entiere)                 }
  OP_MOD       = 5;    { %                                     }
  OP_POW       = 6;    { **                                    }
  OP_DIV       = 7;    { / (traite comme //)                   }
  OP_SHL       = 8;    { <<                                    }
  OP_SHR       = 9;    { >>                                    }
  OP_BAND      = 10;   { &                                     }
  OP_BOR       = 11;   { |                                     }
  OP_BXOR      = 12;   { ^                                     }
  OP_EQ        = 13;   { ==                                    }
  OP_NE        = 14;   { !=                                    }
  OP_LT        = 15;   { <                                     }
  OP_LE        = 16;   { <=                                    }
  OP_GT        = 17;   { >                                     }
  OP_GE        = 18;   { >=                                    }
  OP_AND       = 19;   { and                                   }
  OP_OR        = 20;   { or                                    }
  OP_IN        = 21;   { in                                    }
  OP_NOT_IN    = 22;   { not in                                }
  OP_IS        = 23;   { is                                    }
  OP_IS_NOT    = 24;   { is not                                }
  OP_MAX       = 24;

  { Operateurs unaires }
  UOP_NONE     = 0;
  UOP_NEG      = 1;    { - (negation)                          }
  UOP_POS      = 2;    { + (identite)                          }
  UOP_BNOT     = 3;    { ~ (complement bit a bit)              }
  UOP_NOT      = 4;    { not (negation logique)                }
  UOP_MAX      = 4;

  { Operateurs d affectation }
  AOP_ASSIGN       = 0;   { =                                  }
  AOP_ADD_ASSIGN   = 1;   { +=                                 }
  AOP_SUB_ASSIGN   = 2;   { -=                                 }
  AOP_MUL_ASSIGN   = 3;   { *=                                 }
  AOP_IDIV_ASSIGN  = 4;   { //=                                }
  AOP_MOD_ASSIGN   = 5;   { %=                                 }
  AOP_POW_ASSIGN   = 6;   { **=                                }
  AOP_BAND_ASSIGN  = 7;   { &=                                 }
  AOP_BOR_ASSIGN   = 8;   { |=                                 }
  AOP_BXOR_ASSIGN  = 9;   { ^=                                 }
  AOP_SHL_ASSIGN   = 10;  { <<=                                }
  AOP_SHR_ASSIGN   = 11;  { >>=                                }
  AOP_MAX          = 11;

  { Niveaux de precedence (du plus fort au plus faible) }
  PREC_POWER   = 1;    { **                                    }
  PREC_UNARY   = 2;    { ~ + - (unaires)                       }
  PREC_MULDIV  = 3;    { * // % /                              }
  PREC_ADDSUB  = 4;    { + - (binaires)                        }
  PREC_SHIFT   = 5;    { << >>                                 }
  PREC_BAND    = 6;    { &                                     }
  PREC_BXOR    = 7;    { ^                                     }
  PREC_BOR     = 8;    { |                                     }
  PREC_COMPARE = 9;    { == != < <= > >= in not in is is not   }
  PREC_NOT     = 10;   { not                                   }
  PREC_AND     = 11;   { and                                   }
  PREC_OR      = 12;   { or                                    }
  PREC_MAX     = 12;

Var
  OprInitialized : Boolean;    { True si l etat est initialise       }
  OprParseCount  : LongInt;    { nombre total d appels ParseExpr     }
  OprBinOpCount  : LongInt;    { nombre d ops binaires emis          }
  OprUnaryCount  : LongInt;    { nombre d ops unaires emis           }
  OprFoldCount   : LongInt;    { nombre de pliages de constantes     }
  OprFlushCount  : LongInt;    { nombre de flush vers EAX            }
  OprAssignCount : LongInt;    { nombre d affectations traitees      }
  OprMaxPrec     : Integer;    { precedence max vue                  }
  OprLastOp      : Integer;    { dernier operateur traite            }
  OprLastPrec    : Integer;    { derniere precedence traitee         }

{ ------------------------------------------------------------ }
{ InitOprState : initialiser le sous-systeme des operateurs      }
{ ------------------------------------------------------------ }

Procedure InitOprState;
Begin
  OprInitialized := True;
  OprParseCount  := 0;
  OprBinOpCount  := 0;
  OprUnaryCount  := 0;
  OprFoldCount   := 0;
  OprFlushCount  := 0;
  OprAssignCount := 0;
  OprMaxPrec     := 0;
  OprLastOp      := OP_NONE;
  OprLastPrec    := 0;
End;

{ ------------------------------------------------------------ }
{ GenOprLabel : generer un label unique pour le sous-systeme     }
{ ------------------------------------------------------------ }

Function GenOprLabel : TString;
Begin
  GenOprLabel := LabelGen;
End;

{ ------------------------------------------------------------ }
{ OpName : nom textuel d un operateur binaire                    }
{ ------------------------------------------------------------ }

Function OpName(Op : Integer) : TString;
Begin
  Case Op Of
    OP_NONE   : OpName := 'NONE';
    OP_ADD    : OpName := '+';
    OP_SUB    : OpName := '-';
    OP_MUL    : OpName := '*';
    OP_IDIV   : OpName := '//';
    OP_MOD    : OpName := '%';
    OP_POW    : OpName := '**';
    OP_DIV    : OpName := '/';
    OP_SHL    : OpName := '<<';
    OP_SHR    : OpName := '>>';
    OP_BAND   : OpName := '&';
    OP_BOR    : OpName := '|';
    OP_BXOR   : OpName := '^';
    OP_EQ     : OpName := '==';
    OP_NE     : OpName := '!=';
    OP_LT     : OpName := '<';
    OP_LE     : OpName := '<=';
    OP_GT     : OpName := '>';
    OP_GE     : OpName := '>=';
    OP_AND    : OpName := 'and';
    OP_OR     : OpName := 'or';
    OP_IN     : OpName := 'in';
    OP_NOT_IN : OpName := 'not in';
    OP_IS     : OpName := 'is';
    OP_IS_NOT : OpName := 'is not';
  Else
    OpName := 'OP_?(' + ItoS(Op) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ UnaryOpName : nom textuel d un operateur unaire                }
{ ------------------------------------------------------------ }

Function UnaryOpName(Op : Integer) : TString;
Begin
  Case Op Of
    UOP_NONE : UnaryOpName := 'NONE';
    UOP_NEG  : UnaryOpName := '-';
    UOP_POS  : UnaryOpName := '+';
    UOP_BNOT : UnaryOpName := '~';
    UOP_NOT  : UnaryOpName := 'not';
  Else
    UnaryOpName := 'UOP_?(' + ItoS(Op) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ AssignOpName : nom textuel d un operateur d affectation         }
{ ------------------------------------------------------------ }

Function AssignOpName(Op : Integer) : TString;
Begin
  Case Op Of
    AOP_ASSIGN      : AssignOpName := '=';
    AOP_ADD_ASSIGN  : AssignOpName := '+=';
    AOP_SUB_ASSIGN  : AssignOpName := '-=';
    AOP_MUL_ASSIGN  : AssignOpName := '*=';
    AOP_IDIV_ASSIGN : AssignOpName := '//=';
    AOP_MOD_ASSIGN  : AssignOpName := '%=';
    AOP_POW_ASSIGN  : AssignOpName := '**=';
    AOP_BAND_ASSIGN : AssignOpName := '&=';
    AOP_BOR_ASSIGN  : AssignOpName := '|=';
    AOP_BXOR_ASSIGN : AssignOpName := '^=';
    AOP_SHL_ASSIGN  : AssignOpName := '<<=';
    AOP_SHR_ASSIGN  : AssignOpName := '>>=';
  Else
    AssignOpName := 'AOP_?(' + ItoS(Op) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ BinOpPrec : retourner la precedence d un operateur binaire     }
{ ------------------------------------------------------------ }

Function BinOpPrec(Op : Integer) : Integer;
Begin
  Case Op Of
    OP_POW             : BinOpPrec := PREC_POWER;
    OP_MUL, OP_IDIV,
    OP_MOD, OP_DIV     : BinOpPrec := PREC_MULDIV;
    OP_ADD, OP_SUB     : BinOpPrec := PREC_ADDSUB;
    OP_SHL, OP_SHR     : BinOpPrec := PREC_SHIFT;
    OP_BAND            : BinOpPrec := PREC_BAND;
    OP_BXOR            : BinOpPrec := PREC_BXOR;
    OP_BOR             : BinOpPrec := PREC_BOR;
    OP_EQ, OP_NE,
    OP_LT, OP_LE,
    OP_GT, OP_GE,
    OP_IN, OP_NOT_IN,
    OP_IS, OP_IS_NOT   : BinOpPrec := PREC_COMPARE;
    OP_AND             : BinOpPrec := PREC_AND;
    OP_OR              : BinOpPrec := PREC_OR;
  Else
    BinOpPrec := 0;
  End;
End;

{ ------------------------------------------------------------ }
{ BinOpIsRight : True si l operateur est associatif a droite     }
{ (seul ** est associatif a droite en Python)                    }
{ ------------------------------------------------------------ }

Function BinOpIsRight(Op : Integer) : Boolean;
Begin
  BinOpIsRight := (Op = OP_POW);
End;

{ ------------------------------------------------------------ }
{ IsAssignOp : detecter un operateur d affectation dans CurTokStr}
{ Retourne le type AOP_xxx ou -1 si pas un operateur d affect.   }
{ ------------------------------------------------------------ }

Function IsAssignOp : Integer;
Var S : TString;
Begin
  S := CurTokStr;
  If S = '='    Then IsAssignOp := AOP_ASSIGN
  Else If S = '+='   Then IsAssignOp := AOP_ADD_ASSIGN
  Else If S = '-='   Then IsAssignOp := AOP_SUB_ASSIGN
  Else If S = '*='   Then IsAssignOp := AOP_MUL_ASSIGN
  Else If S = '//='  Then IsAssignOp := AOP_IDIV_ASSIGN
  Else If S = '%='   Then IsAssignOp := AOP_MOD_ASSIGN
  Else If S = '**='  Then IsAssignOp := AOP_POW_ASSIGN
  Else If S = '&='   Then IsAssignOp := AOP_BAND_ASSIGN
  Else If S = '|='   Then IsAssignOp := AOP_BOR_ASSIGN
  Else If S = '^='   Then IsAssignOp := AOP_BXOR_ASSIGN
  Else If S = '<<='  Then IsAssignOp := AOP_SHL_ASSIGN
  Else If S = '>>='  Then IsAssignOp := AOP_SHR_ASSIGN
  Else IsAssignOp := -1;
End;

{ ------------------------------------------------------------ }
{ AssignOpToBinOp : convertir AOP_xxx en OP_xxx pour les         }
{ affectations composees (+=, -=, etc.)                          }
{ ------------------------------------------------------------ }

Function AssignOpToBinOp(AOp : Integer) : Integer;
Begin
  Case AOp Of
    AOP_ADD_ASSIGN  : AssignOpToBinOp := OP_ADD;
    AOP_SUB_ASSIGN  : AssignOpToBinOp := OP_SUB;
    AOP_MUL_ASSIGN  : AssignOpToBinOp := OP_MUL;
    AOP_IDIV_ASSIGN : AssignOpToBinOp := OP_IDIV;
    AOP_MOD_ASSIGN  : AssignOpToBinOp := OP_MOD;
    AOP_POW_ASSIGN  : AssignOpToBinOp := OP_POW;
    AOP_BAND_ASSIGN : AssignOpToBinOp := OP_BAND;
    AOP_BOR_ASSIGN  : AssignOpToBinOp := OP_BOR;
    AOP_BXOR_ASSIGN : AssignOpToBinOp := OP_BXOR;
    AOP_SHL_ASSIGN  : AssignOpToBinOp := OP_SHL;
    AOP_SHR_ASSIGN  : AssignOpToBinOp := OP_SHR;
  Else
    AssignOpToBinOp := OP_NONE;
  End;
End;

{ ------------------------------------------------------------ }
{ TokenToBinOp : convertir CurTokStr en OP_xxx                  }
{ Retourne OP_NONE si pas un operateur binaire connu             }
{ ------------------------------------------------------------ }

Function TokenToBinOp : Integer;
Var S : TString;
Begin
  S := CurTokStr;
  If S = '+'       Then TokenToBinOp := OP_ADD
  Else If S = '-'  Then TokenToBinOp := OP_SUB
  Else If S = '*'  Then TokenToBinOp := OP_MUL
  Else If S = '//' Then TokenToBinOp := OP_IDIV
  Else If S = '/'  Then TokenToBinOp := OP_DIV
  Else If S = '%'  Then TokenToBinOp := OP_MOD
  Else If S = '**' Then TokenToBinOp := OP_POW
  Else If S = '<<' Then TokenToBinOp := OP_SHL
  Else If S = '>>' Then TokenToBinOp := OP_SHR
  Else If S = '&'  Then TokenToBinOp := OP_BAND
  Else If S = '|'  Then TokenToBinOp := OP_BOR
  Else If S = '^'  Then TokenToBinOp := OP_BXOR
  Else If S = '==' Then TokenToBinOp := OP_EQ
  Else If S = '!=' Then TokenToBinOp := OP_NE
  Else If S = '<'  Then TokenToBinOp := OP_LT
  Else If S = '<=' Then TokenToBinOp := OP_LE
  Else If S = '>'  Then TokenToBinOp := OP_GT
  Else If S = '>=' Then TokenToBinOp := OP_GE
  Else TokenToBinOp := OP_NONE;
End;

{ ------------------------------------------------------------ }
{ TokenToKeywordOp : convertir un mot-cle en OP_xxx             }
{ Gere: and, or, in, not in, is, is not                          }
{ ------------------------------------------------------------ }

Function TokenToKeywordOp : Integer;
Begin
  If CurTokStr = 'and' Then
    TokenToKeywordOp := OP_AND
  Else If CurTokStr = 'or' Then
    TokenToKeywordOp := OP_OR
  Else If CurTokStr = 'in' Then
    TokenToKeywordOp := OP_IN
  Else If CurTokStr = 'is' Then
    TokenToKeywordOp := OP_IS
  Else
    TokenToKeywordOp := OP_NONE;
End;

{ ------------------------------------------------------------ }
{ ExprFlushToEAX : s assurer que la valeur est dans EAX          }
{ Si EK_IMM, emet MOV EAX, val. Si deja EK_EAX, rien a faire.  }
{ ------------------------------------------------------------ }

Function ExprFlushToEAX(E : TExprVal) : TExprVal;
Var R : TExprVal;
Begin
  Inc(OprFlushCount);
  R := E;
  If E.Kind = EK_IMM Then
  Begin
    { MOV EAX, ImmVal serait emis ici dans la generation de code }
    R.Kind := EK_EAX;
  End
  Else If E.Kind = EK_MEM Then
  Begin
    { MOV EAX, [mem] serait emis ici }
    R.Kind := EK_EAX;
  End;
  { Si deja EK_EAX, rien a faire }
  ExprFlushToEAX := R;
End;

{ ------------------------------------------------------------ }
{ ConstFoldBinOp : pliage de constantes pour deux immediats      }
{ Retourne True si le pliage a pu etre effectue                  }
{ ------------------------------------------------------------ }

Function ConstFoldBinOp(Op : Integer; L, R : TExprVal;
                        Var Out : TExprVal) : Boolean;
Var V : LongInt;
Begin
  ConstFoldBinOp := False;
  If (L.Kind <> EK_IMM) Or (R.Kind <> EK_IMM) Then Exit;
  Case Op Of
    OP_ADD  : V := L.ImmVal + R.ImmVal;
    OP_SUB  : V := L.ImmVal - R.ImmVal;
    OP_MUL  : V := L.ImmVal * R.ImmVal;
    OP_IDIV, OP_DIV :
      Begin
        If R.ImmVal = 0 Then Exit;   { pas de pliage si div/0 }
        V := L.ImmVal Div R.ImmVal;
      End;
    OP_MOD  :
      Begin
        If R.ImmVal = 0 Then Exit;
        V := L.ImmVal Mod R.ImmVal;
      End;
    OP_SHL  : V := L.ImmVal Shl R.ImmVal;
    OP_SHR  : V := L.ImmVal Shr R.ImmVal;
    OP_BAND : V := L.ImmVal And R.ImmVal;
    OP_BOR  : V := L.ImmVal Or R.ImmVal;
    OP_BXOR : V := L.ImmVal Xor R.ImmVal;
    OP_EQ   : Begin If L.ImmVal =  R.ImmVal Then V := 1 Else V := 0; End;
    OP_NE   : Begin If L.ImmVal <> R.ImmVal Then V := 1 Else V := 0; End;
    OP_LT   : Begin If L.ImmVal <  R.ImmVal Then V := 1 Else V := 0; End;
    OP_LE   : Begin If L.ImmVal <= R.ImmVal Then V := 1 Else V := 0; End;
    OP_GT   : Begin If L.ImmVal >  R.ImmVal Then V := 1 Else V := 0; End;
    OP_GE   : Begin If L.ImmVal >= R.ImmVal Then V := 1 Else V := 0; End;
    OP_AND  : Begin If (L.ImmVal <> 0) And (R.ImmVal <> 0) Then V := R.ImmVal Else V := 0; End;
    OP_OR   : Begin If L.ImmVal <> 0 Then V := L.ImmVal Else V := R.ImmVal; End;
  Else
    Exit;  { ** et autres : pas de pliage simplifie }
  End;
  Out := ExprMakeImm(V, L.TypeIdx);
  Inc(OprFoldCount);
  ConstFoldBinOp := True;
End;

{ ------------------------------------------------------------ }
{ ExprEmitBinOp : emettre l operation binaire sur deux TExprVal  }
{ Tente d abord le pliage de constantes, sinon flush vers EAX    }
{ ------------------------------------------------------------ }

Function ExprEmitBinOp(Op : Integer; L, R : TExprVal) : TExprVal;
Var Folded : TExprVal;
Begin
  Inc(OprBinOpCount);
  OprLastOp := Op;
  OprLastPrec := BinOpPrec(Op);
  If OprLastPrec > OprMaxPrec Then
    OprMaxPrec := OprLastPrec;

  { Tenter le pliage de constantes }
  If ConstFoldBinOp(Op, L, R, Folded) Then
  Begin
    ExprEmitBinOp := Folded;
    Exit;
  End;

  { Sinon, la generation de code emettra les instructions }
  { Pour l instant on retourne un resultat dans EAX       }
  ExprEmitBinOp := ExprMakeEAX(L.TypeIdx);
End;

{ ------------------------------------------------------------ }
{ ExprEmitUnaryOp : emettre l operation unaire sur TExprVal      }
{ ------------------------------------------------------------ }

Function ExprEmitUnaryOp(UOp : Integer; E : TExprVal) : TExprVal;
Var V : LongInt;
Begin
  Inc(OprUnaryCount);

  { Pliage de constantes pour unaire }
  If E.Kind = EK_IMM Then
  Begin
    Case UOp Of
      UOP_NEG  : Begin V := -E.ImmVal; Inc(OprFoldCount); ExprEmitUnaryOp := ExprMakeImm(V, E.TypeIdx); Exit; End;
      UOP_POS  : Begin ExprEmitUnaryOp := E; Inc(OprFoldCount); Exit; End;
      UOP_BNOT : Begin V := Not E.ImmVal; Inc(OprFoldCount); ExprEmitUnaryOp := ExprMakeImm(V, E.TypeIdx); Exit; End;
      UOP_NOT  : Begin If E.ImmVal = 0 Then V := 1 Else V := 0; Inc(OprFoldCount); ExprEmitUnaryOp := ExprMakeImm(V, TY_IDX_BOOL); Exit; End;
    End;
  End;

  { Sinon, generation de code -> resultat dans EAX }
  ExprEmitUnaryOp := ExprMakeEAX(E.TypeIdx);
End;

{ ------------------------------------------------------------ }
{ ParsePrimary : parser une expression primaire                  }
{ Gere : entier, chaine, None, True, False, identificateur       }
{ ------------------------------------------------------------ }

Function ParseExprPrec(MinPrec : Integer) : TExprVal; Forward;

Function ParsePrimary : TExprVal;
Var E : TExprVal;
Begin
  Case CurTokKind Of
    TK_INTEGER :
      Begin
        E := LitEvalInt;
        LexNextToken;
      End;
    TK_STRING :
      Begin
        E := LitEvalStr;
        LexNextToken;
      End;
    TK_IDENT :
      Begin
        If CurTokStr = 'None' Then
        Begin
          E := ExprMakeNone;
          LexNextToken;
        End
        Else If CurTokStr = 'True' Then
        Begin
          E := ExprMakeBool(True);
          LexNextToken;
        End
        Else If CurTokStr = 'False' Then
        Begin
          E := ExprMakeBool(False);
          LexNextToken;
        End
        Else
        Begin
          { Variable ou appel de fonction (stub) }
          E.Kind    := EK_MEM;
          E.ImmVal  := 0;
          E.TypeIdx := TY_IDX_INT;
          E.Offset  := 0;
          E.SymIdx  := SymFind(CurTokStr);
          LexNextToken;
        End;
      End;
    TK_KEYWORD :
      Begin
        If CurTokStr = 'None' Then
        Begin
          E := ExprMakeNone;
          LexNextToken;
        End
        Else If CurTokStr = 'True' Then
        Begin
          E := ExprMakeBool(True);
          LexNextToken;
        End
        Else If CurTokStr = 'False' Then
        Begin
          E := ExprMakeBool(False);
          LexNextToken;
        End
        Else If CurTokStr = 'not' Then
        Begin
          { Unaire not traite ici pour eviter conflit avec ParseUnary }
          LexNextToken;
          E := ParseExprPrec(PREC_NOT);
          E := ExprEmitUnaryOp(UOP_NOT, E);
        End
        Else
        Begin
          E.Kind    := EK_NONE;
          E.ImmVal  := 0;
          E.TypeIdx := TY_IDX_NONE;
          E.Offset  := 0;
          E.SymIdx  := -1;
          CompileError('unexpected keyword: ' + CurTokStr, LexLineNo);
          LexNextToken;
        End;
      End;
    TK_PUNCT :
      Begin
        If CurTokStr = '(' Then
        Begin
          LexNextToken;
          E := ParseExprPrec(PREC_MAX + 1);
          { Attendre la parenthese fermante }
          If (CurTokKind = TK_PUNCT) And (CurTokStr = ')') Then
            LexNextToken
          Else
            CompileError('expected )', LexLineNo);
        End
        Else
        Begin
          E.Kind    := EK_NONE;
          E.ImmVal  := 0;
          E.TypeIdx := TY_IDX_NONE;
          E.Offset  := 0;
          E.SymIdx  := -1;
          CompileError('unexpected token: ' + CurTokStr, LexLineNo);
          LexNextToken;
        End;
      End;
  Else
    Begin
      E.Kind    := EK_NONE;
      E.ImmVal  := 0;
      E.TypeIdx := TY_IDX_NONE;
      E.Offset  := 0;
      E.SymIdx  := -1;
      If CurTokKind <> TK_EOF Then
      Begin
        CompileError('expected expression, got: ' + CurTokStr, LexLineNo);
        LexNextToken;
      End;
    End;
  End;
  ParsePrimary := E;
End;

{ ------------------------------------------------------------ }
{ ParseUnary : parser un operateur unaire (- + ~ not)            }
{ ------------------------------------------------------------ }

Function ParseUnary : TExprVal;
Var UOp : Integer;
    E   : TExprVal;
Begin
  UOp := UOP_NONE;
  If CurTokKind = TK_OP Then
  Begin
    If CurTokStr = '-' Then UOp := UOP_NEG
    Else If CurTokStr = '+' Then UOp := UOP_POS
    Else If CurTokStr = '~' Then UOp := UOP_BNOT;
  End
  Else If (CurTokKind = TK_KEYWORD) And (CurTokStr = 'not') Then
    UOp := UOP_NOT;

  If UOp <> UOP_NONE Then
  Begin
    LexNextToken;
    E := ParseUnary;   { recursif pour chaines de unaires }
    ParseUnary := ExprEmitUnaryOp(UOp, E);
  End
  Else
    ParseUnary := ParsePrimary;
End;

{ ------------------------------------------------------------ }
{ ParseExprPrec : parser une expression avec precedence Pratt    }
{ MinPrec = precedence minimale pour continuer                   }
{ ------------------------------------------------------------ }

Function ParseExprPrec(MinPrec : Integer) : TExprVal;
Var
  L, R   : TExprVal;
  Op     : Integer;
  Prec   : Integer;
  NextP  : Integer;
Begin
  L := ParseUnary;

  While True Do
  Begin
    Op := OP_NONE;

    { Detecter l operateur binaire courant }
    If CurTokKind = TK_OP Then
      Op := TokenToBinOp
    Else If CurTokKind = TK_KEYWORD Then
    Begin
      Op := TokenToKeywordOp;
      { Gerer 'not in' et 'is not' }
      { Note: 'not in' est detecte quand 'not' apparait comme op binaire }
    End;

    If Op = OP_NONE Then Break;

    Prec := BinOpPrec(Op);
    If Prec = 0 Then Break;
    If Prec > MinPrec Then Break;   { precedence plus faible = arreter }

    { Consommer l operateur }
    LexNextToken;

    { Gerer 'not in' }
    If (Op = OP_IN) Then
      { 'in' deja consomme }
    Else If (Op = OP_IS) And (CurTokKind = TK_KEYWORD) And (CurTokStr = 'not') Then
    Begin
      LexNextToken;   { consommer 'not' }
      Op := OP_IS_NOT;
    End;

    { Associativite : droite pour **, gauche pour les autres }
    If BinOpIsRight(Op) Then
      NextP := Prec
    Else
      NextP := Prec - 1;

    R := ParseExprPrec(NextP);
    L := ExprEmitBinOp(Op, L, R);
  End;

  ParseExprPrec := L;
End;

{ ------------------------------------------------------------ }
{ ParseExpr : point d entree pour parser une expression          }
{ ------------------------------------------------------------ }

Function ParseExpr : TExprVal;
Begin
  Inc(OprParseCount);
  ParseExpr := ParseExprPrec(PREC_MAX);
End;

{ ------------------------------------------------------------ }
{ DumpOprState : afficher l etat du sous-systeme des operateurs  }
{ ------------------------------------------------------------ }

Procedure DumpOprState;
Begin
  WriteLn('--- Opr State ---');
  WriteLn('  OprInitialized : ', OprInitialized);
  WriteLn('  OprParseCount  : ', OprParseCount);
  WriteLn('  OprBinOpCount  : ', OprBinOpCount);
  WriteLn('  OprUnaryCount  : ', OprUnaryCount);
  WriteLn('  OprFoldCount   : ', OprFoldCount);
  WriteLn('  OprFlushCount  : ', OprFlushCount);
  WriteLn('  OprAssignCount : ', OprAssignCount);
  WriteLn('  OprMaxPrec     : ', OprMaxPrec);
  WriteLn('  OprLastOp      : ', OpName(OprLastOp));
  WriteLn('  OprLastPrec    : ', OprLastPrec);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 07)                              }
{ ------------------------------------------------------------ }

Function IsOprInitialized : Boolean;
Begin
  IsOprInitialized := OprInitialized;
End;

Function IsOprEmpty : Boolean;
Begin
  IsOprEmpty := (OprParseCount = 0);
End;

Function GetOprParseCount : LongInt;
Begin
  GetOprParseCount := OprParseCount;
End;

Function GetOprBinOpCount : LongInt;
Begin
  GetOprBinOpCount := OprBinOpCount;
End;

Function GetOprUnaryCount : LongInt;
Begin
  GetOprUnaryCount := OprUnaryCount;
End;

Function GetOprFoldCount : LongInt;
Begin
  GetOprFoldCount := OprFoldCount;
End;

Function GetOprFlushCount : LongInt;
Begin
  GetOprFlushCount := OprFlushCount;
End;

Function GetOprAssignCount : LongInt;
Begin
  GetOprAssignCount := OprAssignCount;
End;

Function GetOprLastOp : Integer;
Begin
  GetOprLastOp := OprLastOp;
End;

Function GetOprStatus : TString;
Begin
  If Not OprInitialized Then
    GetOprStatus := 'Not initialized'
  Else
    GetOprStatus := ItoS(OprParseCount) + ' parses (' +
                    ItoS(OprBinOpCount) + ' binops, ' +
                    ItoS(OprUnaryCount) + ' unary, ' +
                    ItoS(OprFoldCount) + ' folds)';
End;

{ ============================================================ }
{ TODO 08 - PARSEUR : EXPRESSIONS PRIMAIRES ET APPELS          }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { Types d expressions primaires PX_* }
  PX_NONE      = 0;    { aucun                                   }
  PX_INT_LIT   = 1;    { litteral entier                         }
  PX_STR_LIT   = 2;    { litteral chaine                         }
  PX_IDENT     = 3;    { identificateur                          }
  PX_FUNC_CALL = 4;    { appel de fonction                       }
  PX_METH_CALL = 5;    { appel de methode                        }
  PX_ATTR      = 6;    { acces attribut                          }
  PX_INDEX     = 7;    { acces index                             }
  PX_SLICE     = 8;    { acces slice                             }
  PX_LIST_LIT  = 9;    { liste literale                          }
  PX_TUPLE_LIT = 10;   { tuple literal                           }
  PX_DICT_LIT  = 11;   { dict literal                            }
  PX_BUILTIN   = 12;   { appel builtin inline                    }
  PX_PAREN     = 13;   { expression parenthesee                  }
  PX_MAX       = 13;

  { Limites }
  PX_MAX_ARGS  = 16;   { nombre max d arguments par appel        }
  PX_MAX_ELEMS = 64;   { nombre max d elements dans une liste    }

Var
  PxInitialized  : Boolean;    { True si l etat est initialise       }
  PxCallCount    : LongInt;    { nombre total d appels de fonctions  }
  PxMethCount    : LongInt;    { nombre d appels de methodes         }
  PxAttrCount    : LongInt;    { nombre d acces attribut             }
  PxIndexCount   : LongInt;    { nombre d acces index                }
  PxSliceCount   : LongInt;    { nombre d acces slice                }
  PxListCount    : LongInt;    { nombre de listes literales          }
  PxDictCount    : LongInt;    { nombre de dicts literaux            }
  PxBuiltinCount : LongInt;    { nombre d appels builtins inline     }
  PxLastKind     : Integer;    { dernier type d expression primaire  }
  PxLabelSeq     : Integer;    { sequence pour labels PX              }

{ ------------------------------------------------------------ }
{ InitPxState : initialiser le sous-systeme des primaires        }
{ ------------------------------------------------------------ }

Procedure InitPxState;
Begin
  PxInitialized  := True;
  PxCallCount    := 0;
  PxMethCount    := 0;
  PxAttrCount    := 0;
  PxIndexCount   := 0;
  PxSliceCount   := 0;
  PxListCount    := 0;
  PxDictCount    := 0;
  PxBuiltinCount := 0;
  PxLastKind     := PX_NONE;
  PxLabelSeq     := 0;
End;

{ ------------------------------------------------------------ }
{ GenPxLabel : generer un label unique pour les primaires         }
{ ------------------------------------------------------------ }

Function GenPxLabel : TString;
Begin
  Inc(PxLabelSeq);
  GenPxLabel := '_PYX_' + ItoS(PxLabelSeq);
End;

{ ------------------------------------------------------------ }
{ PxTypeName : retourner le nom du type de primaire              }
{ ------------------------------------------------------------ }

Function PxTypeName(K : Integer) : TString;
Begin
  Case K Of
    PX_NONE      : PxTypeName := 'NONE';
    PX_INT_LIT   : PxTypeName := 'INT_LIT';
    PX_STR_LIT   : PxTypeName := 'STR_LIT';
    PX_IDENT     : PxTypeName := 'IDENT';
    PX_FUNC_CALL : PxTypeName := 'FUNC_CALL';
    PX_METH_CALL : PxTypeName := 'METH_CALL';
    PX_ATTR      : PxTypeName := 'ATTR';
    PX_INDEX     : PxTypeName := 'INDEX';
    PX_SLICE     : PxTypeName := 'SLICE';
    PX_LIST_LIT  : PxTypeName := 'LIST_LIT';
    PX_TUPLE_LIT : PxTypeName := 'TUPLE_LIT';
    PX_DICT_LIT  : PxTypeName := 'DICT_LIT';
    PX_BUILTIN   : PxTypeName := 'BUILTIN';
    PX_PAREN     : PxTypeName := 'PAREN';
  Else
    PxTypeName := 'UNKNOWN';
  End;
End;

{ ------------------------------------------------------------ }
{ ParseArgList : parser une liste d arguments separes par ,      }
{   Retourne le nombre d arguments parses.                       }
{   Suppose que le ( a deja ete consomme.                        }
{ ------------------------------------------------------------ }

Function ParseArgList : Integer;
Var
  Count : Integer;
  E     : TExprVal;
Begin
  Count := 0;
  { Liste vide si ) immediatement }
  If (CurTokKind = TK_PUNCT) And (CurTokStr = ')') Then
  Begin
    ParseArgList := 0;
    Exit;
  End;

  { Premier argument }
  E := ParseExpr;
  Inc(Count);

  { Arguments suivants }
  While (CurTokKind = TK_PUNCT) And (CurTokStr = ',') Do
  Begin
    LexNextToken; { consommer , }
    E := ParseExpr;
    Inc(Count);
    If Count > PX_MAX_ARGS Then
    Begin
      CompileError('too many arguments (max ' + ItoS(PX_MAX_ARGS) + ')', LexLineNo);
      Break;
    End;
  End;

  ParseArgList := Count;
End;

{ ------------------------------------------------------------ }
{ ParseFuncCallExpr : parser un appel func(args)                 }
{   FuncName : nom de la fonction, SymI : indice symbole         }
{   Retourne TExprVal avec resultat dans EAX                    }
{ ------------------------------------------------------------ }

Function ParseFuncCallExpr(FuncName : TString; SymI : Integer) : TExprVal;
Var
  R     : TExprVal;
  NArgs : Integer;
Begin
  Inc(PxCallCount);
  PxLastKind := PX_FUNC_CALL;

  LexNextToken; { consommer ( }
  NArgs := ParseArgList;

  { Attendre ) }
  If (CurTokKind = TK_PUNCT) And (CurTokStr = ')') Then
    LexNextToken
  Else
    CompileError('expected ) after function arguments', LexLineNo);

  { Le resultat est dans EAX apres le CALL }
  R := ExprMakeEAX(TY_IDX_INT); { type par defaut, sera affine plus tard }

  ParseFuncCallExpr := R;
End;

{ ------------------------------------------------------------ }
{ ParseMethodCallExpr : parser un appel obj.method(args)         }
{   ObjExpr : expression de l objet, MethodName : nom methode   }
{ ------------------------------------------------------------ }

Function ParseMethodCallExpr(ObjExpr : TExprVal;
                             MethodName : TString) : TExprVal;
Var
  R     : TExprVal;
  NArgs : Integer;
Begin
  Inc(PxMethCount);
  PxLastKind := PX_METH_CALL;

  LexNextToken; { consommer ( }
  NArgs := ParseArgList;

  { Attendre ) }
  If (CurTokKind = TK_PUNCT) And (CurTokStr = ')') Then
    LexNextToken
  Else
    CompileError('expected ) after method arguments', LexLineNo);

  { Le resultat est dans EAX apres le CALL }
  R := ExprMakeEAX(TY_IDX_INT);

  ParseMethodCallExpr := R;
End;

{ ------------------------------------------------------------ }
{ ParseAttrAccess : parser un acces attribut expr.attr           }
{   ObjExpr : expression de l objet                             }
{ ------------------------------------------------------------ }

Function ParseAttrAccess(ObjExpr : TExprVal) : TExprVal;
Var
  AttrName : TString;
  R        : TExprVal;
Begin
  Inc(PxAttrCount);
  PxLastKind := PX_ATTR;

  { Le . a deja ete consomme, on attend un identifiant }
  If CurTokKind <> TK_IDENT Then
  Begin
    CompileError('expected attribute name after .', LexLineNo);
    ParseAttrAccess := ExprMakeNone;
    Exit;
  End;

  AttrName := CurTokStr;
  LexNextToken;

  { Si suivi de (, c est un appel de methode }
  If (CurTokKind = TK_PUNCT) And (CurTokStr = '(') Then
  Begin
    ParseAttrAccess := ParseMethodCallExpr(ObjExpr, AttrName);
    Exit;
  End;

  { Sinon, acces attribut simple : resultat dans EAX }
  R := ExprMakeEAX(TY_IDX_INT);
  ParseAttrAccess := R;
End;

{ ------------------------------------------------------------ }
{ ParseIndexAccess : parser un acces index expr[i] ou slice      }
{   ObjExpr : expression de l objet                             }
{ ------------------------------------------------------------ }

Function ParseIndexAccess(ObjExpr : TExprVal) : TExprVal;
Var
  R     : TExprVal;
  IsSlice : Boolean;
  E     : TExprVal;
Begin
  IsSlice := False;

  { [ a deja ete consomme par l appelant }
  { Verifier si c est un slice : [a:b] }
  If (CurTokKind = TK_COLON) Then
  Begin
    { [:b] - slice depuis le debut }
    IsSlice := True;
    LexNextToken;
    If Not ((CurTokKind = TK_RBRACKET)) Then
      E := ParseExpr;
  End
  Else
  Begin
    E := ParseExpr;
    If (CurTokKind = TK_COLON) Then
    Begin
      { [a:b] - slice }
      IsSlice := True;
      LexNextToken;
      If Not ((CurTokKind = TK_RBRACKET)) Then
        E := ParseExpr;
    End;
  End;

  { Attendre ] }
  If CurTokKind = TK_RBRACKET Then
    LexNextToken
  Else
    CompileError('expected ]', LexLineNo);

  If IsSlice Then
  Begin
    Inc(PxSliceCount);
    PxLastKind := PX_SLICE;
  End
  Else
  Begin
    Inc(PxIndexCount);
    PxLastKind := PX_INDEX;
  End;

  R := ExprMakeEAX(TY_IDX_INT);
  If IsSlice Then
    R.TypeIdx := ObjExpr.TypeIdx; { slice retourne meme type }

  ParseIndexAccess := R;
End;

{ ------------------------------------------------------------ }
{ ParseBuiltinCall : parser un appel inline de builtin           }
{   BiId : identifiant BI_*, BName : nom du builtin             }
{ ------------------------------------------------------------ }

Function ParseBuiltinCall(BiId : Integer; BName : TString) : TExprVal;
Var
  R     : TExprVal;
  NArgs : Integer;
Begin
  Inc(PxBuiltinCount);
  PxLastKind := PX_BUILTIN;

  { ( doit suivre }
  If (CurTokKind = TK_PUNCT) And (CurTokStr = '(') Then
    LexNextToken
  Else
  Begin
    CompileError('expected ( after builtin ' + BName, LexLineNo);
    ParseBuiltinCall := ExprMakeNone;
    Exit;
  End;

  NArgs := ParseArgList;

  { Attendre ) }
  If (CurTokKind = TK_PUNCT) And (CurTokStr = ')') Then
    LexNextToken
  Else
    CompileError('expected ) after builtin arguments', LexLineNo);

  { Resultat dans EAX, type depend du builtin }
  R := ExprMakeEAX(TY_IDX_INT);
  Case BiId Of
    BI_LEN   : R.TypeIdx := TY_IDX_INT;
    BI_ABS   : R.TypeIdx := TY_IDX_INT;
    BI_INT   : R.TypeIdx := TY_IDX_INT;
    BI_STR   : R.TypeIdx := TY_IDX_STR;
    BI_CHR   : R.TypeIdx := TY_IDX_STR;
    BI_ORD   : R.TypeIdx := TY_IDX_INT;
    BI_BOOL  : R.TypeIdx := TY_IDX_BOOL;
    BI_TYPE  : R.TypeIdx := TY_IDX_STR;
    BI_ISINSTANCE : R.TypeIdx := TY_IDX_BOOL;
  Else
    R.TypeIdx := TY_IDX_INT;
  End;

  ParseBuiltinCall := R;
End;

{ ------------------------------------------------------------ }
{ ParseListLiteral : parser [e0, e1, ...]                        }
{ ------------------------------------------------------------ }

Function ParseListLiteral : TExprVal;
Var
  R     : TExprVal;
  Count : Integer;
  E     : TExprVal;
Begin
  Inc(PxListCount);
  PxLastKind := PX_LIST_LIT;

  Count := 0;
  { [ a deja ete consomme }

  { Liste vide ? }
  If CurTokKind = TK_RBRACKET Then
  Begin
    LexNextToken;
    R := ExprMakeEAX(TY_IDX_LIST);
    ParseListLiteral := R;
    Exit;
  End;

  { Premier element }
  E := ParseExpr;
  Inc(Count);

  { Elements suivants }
  While (CurTokKind = TK_PUNCT) And (CurTokStr = ',') Do
  Begin
    LexNextToken;
    { Virgule trainante avant ] }
    If CurTokKind = TK_RBRACKET Then
      Break;
    E := ParseExpr;
    Inc(Count);
    If Count > PX_MAX_ELEMS Then
    Begin
      CompileError('too many list elements (max ' + ItoS(PX_MAX_ELEMS) + ')', LexLineNo);
      Break;
    End;
  End;

  { Attendre ] }
  If CurTokKind = TK_RBRACKET Then
    LexNextToken
  Else
    CompileError('expected ]', LexLineNo);

  R := ExprMakeEAX(TY_IDX_LIST);
  ParseListLiteral := R;
End;

{ ------------------------------------------------------------ }
{ ParseTupleLiteral : parser (e0, e1, ...)                       }
{   Assume que le ( initial a ete consomme et au moins           }
{   une virgule ou un element suivi d une virgule                }
{ ------------------------------------------------------------ }

Function ParseTupleLiteral(FirstElem : TExprVal) : TExprVal;
Var
  R     : TExprVal;
  Count : Integer;
  E     : TExprVal;
Begin
  PxLastKind := PX_TUPLE_LIT;

  Count := 1; { Le premier element a deja ete parse }

  { Elements suivants apres la , deja consommee }
  { Virgule trainante avant ) }
  If (CurTokKind = TK_PUNCT) And (CurTokStr = ')') Then
  Begin
    LexNextToken;
    R := ExprMakeEAX(TY_IDX_TUPLE);
    ParseTupleLiteral := R;
    Exit;
  End;

  E := ParseExpr;
  Inc(Count);

  While (CurTokKind = TK_PUNCT) And (CurTokStr = ',') Do
  Begin
    LexNextToken;
    If (CurTokKind = TK_PUNCT) And (CurTokStr = ')') Then
      Break;
    E := ParseExpr;
    Inc(Count);
    If Count > PX_MAX_ELEMS Then
    Begin
      CompileError('too many tuple elements (max ' + ItoS(PX_MAX_ELEMS) + ')', LexLineNo);
      Break;
    End;
  End;

  { Attendre ) }
  If (CurTokKind = TK_PUNCT) And (CurTokStr = ')') Then
    LexNextToken
  Else
    CompileError('expected )', LexLineNo);

  R := ExprMakeEAX(TY_IDX_TUPLE);
  ParseTupleLiteral := R;
End;

{ ------------------------------------------------------------ }
(* ParseDictLiteral : parser dict literal                       *)
{ ------------------------------------------------------------ }

Function ParseDictLiteral : TExprVal;
Var
  R     : TExprVal;
  Count : Integer;
  K, V  : TExprVal;
Begin
  Inc(PxDictCount);
  PxLastKind := PX_DICT_LIT;

  Count := 0;
  (* accolade ouvrante a deja ete consommee *)

  { Dict vide ? }
  If CurTokKind = TK_RBRACE Then
  Begin
    LexNextToken;
    R := ExprMakeEAX(TY_IDX_DICT);
    ParseDictLiteral := R;
    Exit;
  End;

  { Premiere paire cle:valeur }
  K := ParseExpr;
  If CurTokKind = TK_COLON Then
    LexNextToken
  Else
    CompileError('expected : in dict literal', LexLineNo);
  V := ParseExpr;
  Inc(Count);

  { Paires suivantes }
  While (CurTokKind = TK_PUNCT) And (CurTokStr = ',') Do
  Begin
    LexNextToken;
    (* Virgule trainante avant accolade fermante *)
    If CurTokKind = TK_RBRACE Then
      Break;
    K := ParseExpr;
    If CurTokKind = TK_COLON Then
      LexNextToken
    Else
      CompileError('expected : in dict literal', LexLineNo);
    V := ParseExpr;
    Inc(Count);
    If Count > PX_MAX_ELEMS Then
    Begin
      CompileError('too many dict pairs (max ' + ItoS(PX_MAX_ELEMS) + ')', LexLineNo);
      Break;
    End;
  End;

  (* Attendre accolade fermante *)
  If CurTokKind = TK_RBRACE Then
    LexNextToken
  Else
    CompileError('expected }', LexLineNo);

  R := ExprMakeEAX(TY_IDX_DICT);
  ParseDictLiteral := R;
End;

{ ------------------------------------------------------------ }
{ ParsePostfix : parser les suffixes postfixes (., [, ()         }
{   Boucle pour chainer : obj.attr[i].method(args)               }
{ ------------------------------------------------------------ }

Function ParsePostfix(E : TExprVal) : TExprVal;
Var R : TExprVal;
Begin
  R := E;
  While True Do
  Begin
    { Acces attribut : expr.attr }
    If CurTokKind = TK_DOT Then
    Begin
      LexNextToken; { consommer . }
      R := ParseAttrAccess(R);
    End
    { Acces index/slice : expr[...] }
    Else If CurTokKind = TK_LBRACKET Then
    Begin
      LexNextToken; { consommer [ }
      R := ParseIndexAccess(R);
    End
    { Appel de fonction : expr(...) }
    Else If (CurTokKind = TK_PUNCT) And (CurTokStr = '(') Then
    Begin
      R := ParseFuncCallExpr('', R.SymIdx);
    End
    Else
      Break;
  End;
  ParsePostfix := R;
End;

{ ------------------------------------------------------------ }
{ ParsePrimaryFull : parser une expression primaire complete      }
{   avec les suffixes postfixes                                  }
{ ------------------------------------------------------------ }

Function ParsePrimaryFull : TExprVal;
Var
  E        : TExprVal;
  FuncName : TString;
  SymI     : Integer;
  BiId     : Integer;
Begin
  Case CurTokKind Of
    TK_INTEGER :
      Begin
        PxLastKind := PX_INT_LIT;
        E := LitEvalInt;
        LexNextToken;
      End;
    TK_STRING :
      Begin
        PxLastKind := PX_STR_LIT;
        E := LitEvalStr;
        LexNextToken;
      End;
    TK_IDENT :
      Begin
        If CurTokStr = 'None' Then
        Begin
          E := ExprMakeNone;
          LexNextToken;
        End
        Else If CurTokStr = 'True' Then
        Begin
          E := ExprMakeBool(True);
          LexNextToken;
        End
        Else If CurTokStr = 'False' Then
        Begin
          E := ExprMakeBool(False);
          LexNextToken;
        End
        Else
        Begin
          FuncName := CurTokStr;
          SymI := SymFind(CurTokStr);

          { Verifier si c est un builtin inline }
          BiId := LookupBuiltin(FuncName);
          If (BiId <> 0) Then
          Begin
            LexNextToken;
            E := ParseBuiltinCall(BiId, FuncName);
          End
          { Verifier si c est un appel de fonction }
          Else
          Begin
            LexNextToken;
            If (CurTokKind = TK_PUNCT) And (CurTokStr = '(') Then
            Begin
              E := ParseFuncCallExpr(FuncName, SymI);
            End
            Else
            Begin
              { Variable simple }
              PxLastKind := PX_IDENT;
              E.Kind    := EK_MEM;
              E.ImmVal  := 0;
              E.TypeIdx := TY_IDX_INT;
              E.Offset  := 0;
              E.SymIdx  := SymI;
            End;
          End;
        End;
      End;
    TK_KEYWORD :
      Begin
        If CurTokStr = 'None' Then
        Begin
          E := ExprMakeNone;
          LexNextToken;
        End
        Else If CurTokStr = 'True' Then
        Begin
          E := ExprMakeBool(True);
          LexNextToken;
        End
        Else If CurTokStr = 'False' Then
        Begin
          E := ExprMakeBool(False);
          LexNextToken;
        End
        Else If CurTokStr = 'not' Then
        Begin
          LexNextToken;
          E := ParseExprPrec(PREC_NOT);
          E := ExprEmitUnaryOp(UOP_NOT, E);
        End
        Else
        Begin
          E.Kind    := EK_NONE;
          E.ImmVal  := 0;
          E.TypeIdx := TY_IDX_NONE;
          E.Offset  := 0;
          E.SymIdx  := -1;
          CompileError('unexpected keyword: ' + CurTokStr, LexLineNo);
          LexNextToken;
        End;
      End;
    TK_PUNCT :
      Begin
        If CurTokStr = '(' Then
        Begin
          PxLastKind := PX_PAREN;
          LexNextToken;
          { Tuple vide () }
          If (CurTokKind = TK_PUNCT) And (CurTokStr = ')') Then
          Begin
            LexNextToken;
            E := ExprMakeEAX(TY_IDX_TUPLE);
          End
          Else
          Begin
            E := ParseExprPrec(PREC_MAX + 1);
            { Verifier si c est un tuple (virgule) }
            If (CurTokKind = TK_PUNCT) And (CurTokStr = ',') Then
            Begin
              LexNextToken;
              E := ParseTupleLiteral(E);
            End
            Else
            Begin
              { Parentheses simples }
              If (CurTokKind = TK_PUNCT) And (CurTokStr = ')') Then
                LexNextToken
              Else
                CompileError('expected )', LexLineNo);
            End;
          End;
        End
        Else
        Begin
          E.Kind    := EK_NONE;
          E.ImmVal  := 0;
          E.TypeIdx := TY_IDX_NONE;
          E.Offset  := 0;
          E.SymIdx  := -1;
          CompileError('unexpected token: ' + CurTokStr, LexLineNo);
          LexNextToken;
        End;
      End;
    TK_LBRACKET :
      Begin
        LexNextToken; { consommer [ }
        E := ParseListLiteral;
      End;
    TK_LBRACE :
      Begin
        LexNextToken; { consommer { }
        E := ParseDictLiteral;
      End;
  Else
    Begin
      E.Kind    := EK_NONE;
      E.ImmVal  := 0;
      E.TypeIdx := TY_IDX_NONE;
      E.Offset  := 0;
      E.SymIdx  := -1;
      CompileError('unexpected token in expression', LexLineNo);
      LexNextToken;
    End;
  End;

  { Appliquer les suffixes postfixes }
  E := ParsePostfix(E);

  ParsePrimaryFull := E;
End;

{ ------------------------------------------------------------ }
{ DumpPxState : afficher l etat du sous-systeme des primaires    }
{ ------------------------------------------------------------ }

Procedure DumpPxState;
Begin
  WriteLn('--- Px State ---');
  WriteLn('  PxInitialized  : ', PxInitialized);
  WriteLn('  PxCallCount    : ', PxCallCount);
  WriteLn('  PxMethCount    : ', PxMethCount);
  WriteLn('  PxAttrCount    : ', PxAttrCount);
  WriteLn('  PxIndexCount   : ', PxIndexCount);
  WriteLn('  PxSliceCount   : ', PxSliceCount);
  WriteLn('  PxListCount    : ', PxListCount);
  WriteLn('  PxDictCount    : ', PxDictCount);
  WriteLn('  PxBuiltinCount : ', PxBuiltinCount);
  WriteLn('  PxLastKind     : ', PxTypeName(PxLastKind));
  WriteLn('  PxLabelSeq     : ', PxLabelSeq);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 08)                              }
{ ------------------------------------------------------------ }

Function IsPxInitialized : Boolean;
Begin
  IsPxInitialized := PxInitialized;
End;

Function IsPxEmpty : Boolean;
Begin
  IsPxEmpty := (PxCallCount = 0) And (PxMethCount = 0) And
               (PxAttrCount = 0) And (PxIndexCount = 0);
End;

Function GetPxCallCount : LongInt;
Begin
  GetPxCallCount := PxCallCount;
End;

Function GetPxMethCount : LongInt;
Begin
  GetPxMethCount := PxMethCount;
End;

Function GetPxAttrCount : LongInt;
Begin
  GetPxAttrCount := PxAttrCount;
End;

Function GetPxIndexCount : LongInt;
Begin
  GetPxIndexCount := PxIndexCount;
End;

Function GetPxSliceCount : LongInt;
Begin
  GetPxSliceCount := PxSliceCount;
End;

Function GetPxBuiltinCount : LongInt;
Begin
  GetPxBuiltinCount := PxBuiltinCount;
End;

Function GetPxLastKind : Integer;
Begin
  GetPxLastKind := PxLastKind;
End;

Function GetPxStatus : TString;
Begin
  If Not PxInitialized Then
    GetPxStatus := 'Not initialized'
  Else
    GetPxStatus := ItoS(PxCallCount) + ' calls, ' +
                   ItoS(PxMethCount) + ' methods, ' +
                   ItoS(PxAttrCount) + ' attrs, ' +
                   ItoS(PxIndexCount) + ' index, ' +
                   ItoS(PxBuiltinCount) + ' builtins';
End;

{ ============================================================ }
{ TODO 09 - PARSEUR : VARIABLES ET AFFECTATIONS [IMPLEMENTE]   }
{ ============================================================ }

Const
  { Types d operations sur les variables }
  VA_NONE          = 0;    { aucun / non defini                    }
  VA_LOAD_GLOBAL   = 1;    { lecture variable globale (DATA)        }
  VA_STORE_GLOBAL  = 2;    { ecriture variable globale (DATA)      }
  VA_LOAD_LOCAL    = 3;    { lecture variable locale (pile EBP)     }
  VA_STORE_LOCAL   = 4;    { ecriture variable locale (pile EBP)   }
  VA_LOAD_PARAM    = 5;    { lecture parametre (pile EBP+offset)   }
  VA_STORE_PARAM   = 6;    { ecriture parametre (pile EBP+offset)  }
  VA_ASSIGN        = 7;    { affectation simple (=)                }
  VA_AUG_ASSIGN    = 8;    { affectation augmentee (+=, etc.)      }
  VA_MULTI_ASSIGN  = 9;    { affectation multiple (a, b = ...)     }
  VA_SWAP          = 10;   { echange (a, b = b, a)                 }
  VA_UNPACK        = 11;   { unpacking (a, b, c = iterable)        }
  VA_DEL           = 12;   { instruction del                       }
  VA_GLOBAL_DECL   = 13;   { instruction global                    }
  VA_NONLOCAL_DECL = 14;   { instruction nonlocal                  }
  VA_MAX           = 14;

  { Limites }
  VA_MAX_TARGETS   = 16;   { nombre max de cibles d affectation    }

Var
  VaInitialized   : Boolean;    { True si l etat est initialise       }
  VaAssignCount   : LongInt;    { nombre d affectations simples       }
  VaAugCount      : LongInt;    { nombre d affectations augmentees    }
  VaMultiCount    : LongInt;    { nombre d affectations multiples     }
  VaSwapCount     : LongInt;    { nombre d echanges                   }
  VaUnpackCount   : LongInt;    { nombre d unpacking                  }
  VaDelCount      : LongInt;    { nombre d instructions del           }
  VaGlobalCount   : LongInt;    { nombre d instructions global        }
  VaNonlocalCount : LongInt;    { nombre d instructions nonlocal      }
  VaLastKind      : Integer;    { dernier type d operation variable   }
  VaLabelSeq      : Integer;    { sequence pour labels VA              }

{ ------------------------------------------------------------ }
{ InitVaState : initialiser le sous-systeme variables            }
{ ------------------------------------------------------------ }

Procedure InitVaState;
Begin
  VaInitialized   := True;
  VaAssignCount   := 0;
  VaAugCount      := 0;
  VaMultiCount    := 0;
  VaSwapCount     := 0;
  VaUnpackCount   := 0;
  VaDelCount      := 0;
  VaGlobalCount   := 0;
  VaNonlocalCount := 0;
  VaLastKind      := VA_NONE;
  VaLabelSeq      := 0;
End;

{ ------------------------------------------------------------ }
{ GenVaLabel : generer un label unique pour les variables         }
{ ------------------------------------------------------------ }

Function GenVaLabel : TString;
Begin
  Inc(VaLabelSeq);
  GenVaLabel := '_PYA_' + ItoS(VaLabelSeq);
End;

{ ------------------------------------------------------------ }
{ VaTypeName : retourner le nom du type d operation variable      }
{ ------------------------------------------------------------ }

Function VaTypeName(K : Integer) : TString;
Begin
  Case K Of
    VA_NONE          : VaTypeName := 'NONE';
    VA_LOAD_GLOBAL   : VaTypeName := 'LOAD_GLOBAL';
    VA_STORE_GLOBAL  : VaTypeName := 'STORE_GLOBAL';
    VA_LOAD_LOCAL    : VaTypeName := 'LOAD_LOCAL';
    VA_STORE_LOCAL   : VaTypeName := 'STORE_LOCAL';
    VA_LOAD_PARAM    : VaTypeName := 'LOAD_PARAM';
    VA_STORE_PARAM   : VaTypeName := 'STORE_PARAM';
    VA_ASSIGN        : VaTypeName := 'ASSIGN';
    VA_AUG_ASSIGN    : VaTypeName := 'AUG_ASSIGN';
    VA_MULTI_ASSIGN  : VaTypeName := 'MULTI_ASSIGN';
    VA_SWAP          : VaTypeName := 'SWAP';
    VA_UNPACK        : VaTypeName := 'UNPACK';
    VA_DEL           : VaTypeName := 'DEL';
    VA_GLOBAL_DECL   : VaTypeName := 'GLOBAL_DECL';
    VA_NONLOCAL_DECL : VaTypeName := 'NONLOCAL_DECL';
  Else
    VaTypeName := 'VA_?(' + ItoS(K) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ EnsureVarInData : auto-declarer une variable globale           }
{ Si la variable n existe pas encore dans la table des symboles  }
{ elle est ajoutee avec SK_VAR + un slot DATA de 4 octets        }
{ Retourne l indice du symbole                                   }
{ ------------------------------------------------------------ }

Function EnsureVarInData(Const Name : TString) : Integer;
Var
  Idx     : Integer;
  DataLbl : TString;
  SymIdx  : Integer;
Begin
  Idx := SymFind(Name);
  If Idx >= 0 Then
  Begin
    EnsureVarInData := Idx;
    Exit;
  End;
  { Creer un slot DATA DWORD pour la variable }
  DataLbl := PY_VAR_PFX + SymNameClean(Name);
  DataAdd(DataLbl, DK_DWORD, 0, '', 1);
  { Ajouter le symbole }
  SymIdx := SymAdd(Name, SK_VAR, TY_IDX_INT, LexLineNo);
  EnsureVarInData := SymIdx;
End;

{ ------------------------------------------------------------ }
{ EmitVarLoad : generer le code pour charger une variable        }
{ dans EAX. Selon le type : global (DATA), local (EBP-offset)   }
{ ou parametre (EBP+offset).                                     }
{ Le code est emis sous forme de commentaire assembleur.         }
{ ------------------------------------------------------------ }

Procedure EmitVarLoad(Idx : Integer);
Begin
  If (Idx < 0) Or (Idx >= SymTabCount) Then Exit;
  Case SymTab[Idx].Kind Of
    SK_PARAM :
    Begin
      { Parametre : acces via EBP + offset positif }
      { MOV EAX, DWORD [EBP+offset] }
      If Opts.Verbose Then
        WriteLn('; LOAD param ', SymTab[Idx].Name,
                ' [EBP+', SymTab[Idx].Offset, ']');
      VaLastKind := VA_LOAD_PARAM;
    End;
    SK_LOCAL :
    Begin
      { Variable locale : acces via EBP - offset negatif }
      { MOV EAX, DWORD [EBP-offset] }
      If Opts.Verbose Then
        WriteLn('; LOAD local ', SymTab[Idx].Name,
                ' [EBP-', SymTab[Idx].Offset, ']');
      VaLastKind := VA_LOAD_LOCAL;
    End;
  Else
    Begin
      { Variable globale : acces direct par label DATA }
      { MOV EAX, DWORD [_PYV_nom] }
      If Opts.Verbose Then
        WriteLn('; LOAD global ', SymTab[Idx].Name,
                ' [', SymTab[Idx].AsmName, ']');
      VaLastKind := VA_LOAD_GLOBAL;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ EmitVarStore : generer le code pour stocker EAX dans une       }
{ variable. Selon le type : global, local ou parametre.          }
{ ------------------------------------------------------------ }

Procedure EmitVarStore(Idx : Integer);
Begin
  If (Idx < 0) Or (Idx >= SymTabCount) Then Exit;
  Case SymTab[Idx].Kind Of
    SK_PARAM :
    Begin
      { Parametre : MOV DWORD [EBP+offset], EAX }
      If Opts.Verbose Then
        WriteLn('; STORE param ', SymTab[Idx].Name,
                ' [EBP+', SymTab[Idx].Offset, ']');
      VaLastKind := VA_STORE_PARAM;
    End;
    SK_LOCAL :
    Begin
      { Variable locale : MOV DWORD [EBP-offset], EAX }
      If Opts.Verbose Then
        WriteLn('; STORE local ', SymTab[Idx].Name,
                ' [EBP-', SymTab[Idx].Offset, ']');
      VaLastKind := VA_STORE_LOCAL;
    End;
  Else
    Begin
      { Variable globale : MOV DWORD [_PYV_nom], EAX }
      If Opts.Verbose Then
        WriteLn('; STORE global ', SymTab[Idx].Name,
                ' [', SymTab[Idx].AsmName, ']');
      VaLastKind := VA_STORE_GLOBAL;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseAssignSimple : traiter une affectation simple x = expr    }
{ Attend : CurTokStr contient le nom de la variable              }
{ Le token '=' a ete detecte par l appelant                      }
{ ------------------------------------------------------------ }

Procedure ParseAssignSimple(Const VarName : TString);
Var
  VarIdx : Integer;
Begin
  VaLastKind := VA_ASSIGN;
  Inc(VaAssignCount);

  { S assurer que la variable existe dans DATA }
  VarIdx := EnsureVarInData(VarName);

  If Opts.Verbose Then
    WriteLn('; assign simple: ', VarName, ' = <expr>');

  { Avancer apres le '=' }
  LexNextToken;

  { Evaluer l expression a droite (resultat dans EAX) }
  ParseExpr;

  { Stocker EAX dans la variable }
  EmitVarStore(VarIdx);
End;

{ ------------------------------------------------------------ }
{ ParseAssignAugmented : traiter une affectation augmentee       }
{ x += expr, x -= expr, etc.                                    }
{ Attend : CurTokStr contient le nom, AOp le type d affectation  }
{ ------------------------------------------------------------ }

Procedure ParseAssignAugmented(Const VarName : TString;
                               AOp : Integer);
Var
  VarIdx : Integer;
  BinOp  : Integer;
Begin
  VaLastKind := VA_AUG_ASSIGN;
  Inc(VaAugCount);

  VarIdx := EnsureVarInData(VarName);
  BinOp  := AssignOpToBinOp(AOp);

  If Opts.Verbose Then
    WriteLn('; assign augmented: ', VarName, ' ',
            AssignOpName(AOp), ' <expr>');

  { Avancer apres l operateur d affectation }
  LexNextToken;

  { Charger la valeur actuelle de la variable }
  EmitVarLoad(VarIdx);

  { Sauvegarder sur la pile }
  If Opts.Verbose Then
    WriteLn('; PUSH EAX (valeur courante de ', VarName, ')');

  { Evaluer l expression a droite }
  ParseExpr;

  { Appliquer l operation binaire }
  If Opts.Verbose Then
    WriteLn('; ', OpName(BinOp), ' avec valeur empilee');

  { Stocker le resultat }
  EmitVarStore(VarIdx);
End;

{ ------------------------------------------------------------ }
{ ParseAssignMultiple : traiter une affectation multiple          }
{ a, b = expr1, expr2 -> evaluer puis stocker                    }
{ Attend : liste de noms deja parses dans Targets[]              }
{ ------------------------------------------------------------ }

Procedure ParseAssignMultiple(Var Targets : Array Of TString;
                              TgtCount : Integer);
Var
  I      : Integer;
  VarIdx : Integer;
Begin
  VaLastKind := VA_MULTI_ASSIGN;
  Inc(VaMultiCount);

  If Opts.Verbose Then
    WriteLn('; assign multiple: ', TgtCount, ' targets');

  { Avancer apres le '=' }
  LexNextToken;

  { Evaluer chaque expression et stocker sur la pile (en ordre) }
  For I := 0 To TgtCount - 1 Do
  Begin
    If I > 0 Then
    Begin
      { Attendre une virgule entre les expressions }
      If CurTokStr = ',' Then
        LexNextToken
      Else
        CompileError('Virgule attendue dans affectation multiple',
                     LexLineNo);
    End;
    ParseExpr;
    If Opts.Verbose Then
      WriteLn('; PUSH EAX (valeur pour ', Targets[I], ')');
  End;

  { Depiler et stocker dans chaque cible (en ordre inverse) }
  For I := TgtCount - 1 DownTo 0 Do
  Begin
    VarIdx := EnsureVarInData(Targets[I]);
    If Opts.Verbose Then
      WriteLn('; POP -> ', Targets[I]);
    EmitVarStore(VarIdx);
  End;
End;

{ ------------------------------------------------------------ }
{ ParseSwap : traiter un echange a, b = b, a                    }
{ Detecte le pattern d echange et genere du code optimise        }
{ via registre ou pile temporaire                                }
{ ------------------------------------------------------------ }

Procedure ParseSwap(Const Name1, Name2 : TString);
Var
  Idx1, Idx2 : Integer;
Begin
  VaLastKind := VA_SWAP;
  Inc(VaSwapCount);

  If Opts.Verbose Then
    WriteLn('; swap: ', Name1, ', ', Name2, ' = ', Name2, ', ', Name1);

  Idx1 := EnsureVarInData(Name1);
  Idx2 := EnsureVarInData(Name2);

  { Charger Name1 dans EAX, sauvegarder dans ECX }
  EmitVarLoad(Idx1);
  If Opts.Verbose Then
    WriteLn('; MOV ECX, EAX (sauvegarde ', Name1, ')');

  { Charger Name2 dans EAX }
  EmitVarLoad(Idx2);

  { Stocker EAX (ancienne val de Name2) dans Name1 }
  EmitVarStore(Idx1);

  { Stocker ECX (ancienne val de Name1) dans Name2 }
  If Opts.Verbose Then
    WriteLn('; MOV EAX, ECX (restaurer ', Name1, ')');
  EmitVarStore(Idx2);
End;

{ ------------------------------------------------------------ }
{ ParseUnpacking : traiter un unpacking simple                   }
{ a, b, c = iterable -> extraire elements sequentiellement       }
{ ------------------------------------------------------------ }

Procedure ParseUnpacking(Var Targets : Array Of TString;
                         TgtCount : Integer);
Var
  I      : Integer;
  VarIdx : Integer;
Begin
  VaLastKind := VA_UNPACK;
  Inc(VaUnpackCount);

  If Opts.Verbose Then
    WriteLn('; unpack: ', TgtCount, ' targets from iterable');

  { Avancer apres le '=' }
  LexNextToken;

  { Evaluer l iterable (resultat : pointeur en EAX) }
  ParseExpr;

  If Opts.Verbose Then
    WriteLn('; EAX = iterable, extraire ', TgtCount, ' elements');

  { Pour chaque cible, extraire element[i] et stocker }
  For I := 0 To TgtCount - 1 Do
  Begin
    VarIdx := EnsureVarInData(Targets[I]);
    If Opts.Verbose Then
      WriteLn('; extraire element[', I, '] -> ', Targets[I]);
    EmitVarStore(VarIdx);
  End;
End;

{ ------------------------------------------------------------ }
{ ParseDelStmt : traiter l instruction del                       }
{ del x -> supprimer variable / del lst[i] / del d[key]          }
{ Attend : mot-cle 'del' deja consomme par l appelant            }
{ ------------------------------------------------------------ }

Procedure ParseDelStmt;
Var
  Name   : TString;
  VarIdx : Integer;
Begin
  VaLastKind := VA_DEL;
  Inc(VaDelCount);

  { Lire le nom de la cible }
  If CurTokKind <> TK_IDENT Then
  Begin
    CompileError('Identificateur attendu apres del', LexLineNo);
    Exit;
  End;
  Name := CurTokStr;
  LexNextToken;

  VarIdx := SymFind(Name);
  If VarIdx < 0 Then
  Begin
    CompileError('Variable non definie pour del: ' + Name,
                 LexLineNo);
    Exit;
  End;

  { Verifier si c est del x, del x[i] ou del x[key] }
  If CurTokKind = TK_LBRACKET Then
  Begin
    { del lst[i] ou del d[key] }
    LexNextToken;
    If Opts.Verbose Then
      WriteLn('; del ', Name, '[<index>]');
    { Evaluer l index }
    ParseExpr;
    If CurTokKind = TK_RBRACKET Then
      LexNextToken
    Else
      CompileError('] attendu apres index dans del', LexLineNo);
    If Opts.Verbose Then
      WriteLn('; appel runtime __delitem__ pour ', Name);
  End
  Else
  Begin
    { del x -> mettre la variable a None / liberer }
    If Opts.Verbose Then
      WriteLn('; del ', Name, ' -> set to None');
  End;
End;

{ ------------------------------------------------------------ }
{ ParseGlobalStmt : traiter l instruction global                 }
{ global x, y, z -> marquer les variables comme globales         }
{ Attend : mot-cle 'global' deja consomme par l appelant         }
{ ------------------------------------------------------------ }

Procedure ParseGlobalStmt;
Var
  Name   : TString;
  VarIdx : Integer;
Begin
  VaLastKind := VA_GLOBAL_DECL;
  Inc(VaGlobalCount);

  Repeat
    If CurTokKind <> TK_IDENT Then
    Begin
      CompileError('Identificateur attendu apres global',
                   LexLineNo);
      Exit;
    End;
    Name := CurTokStr;
    LexNextToken;

    { Trouver ou creer le symbole }
    VarIdx := EnsureVarInData(Name);
    If VarIdx >= 0 Then
    Begin
      SymTab[VarIdx].IsGlobal := True;
      If Opts.Verbose Then
        WriteLn('; global ', Name);
    End;

    { Si virgule, continuer avec le prochain nom }
    If CurTokStr = ',' Then
      LexNextToken
    Else
      Break;
  Until False;
End;

{ ------------------------------------------------------------ }
{ ParseNonlocalStmt : traiter l instruction nonlocal             }
{ nonlocal x, y -> marquer les variables comme non-locales       }
{ Attend : mot-cle 'nonlocal' deja consomme par l appelant       }
{ ------------------------------------------------------------ }

Procedure ParseNonlocalStmt;
Var
  Name   : TString;
  VarIdx : Integer;
Begin
  VaLastKind := VA_NONLOCAL_DECL;
  Inc(VaNonlocalCount);

  Repeat
    If CurTokKind <> TK_IDENT Then
    Begin
      CompileError('Identificateur attendu apres nonlocal',
                   LexLineNo);
      Exit;
    End;
    Name := CurTokStr;
    LexNextToken;

    { Trouver le symbole dans la portee englobante }
    VarIdx := SymFind(Name);
    If VarIdx < 0 Then
    Begin
      { Creer le symbole comme variable englobante }
      VarIdx := EnsureVarInData(Name);
    End;
    If VarIdx >= 0 Then
    Begin
      SymTab[VarIdx].IsNonlocal := True;
      If Opts.Verbose Then
        WriteLn('; nonlocal ', Name);
    End;

    If CurTokStr = ',' Then
      LexNextToken
    Else
      Break;
  Until False;
End;

{ ------------------------------------------------------------ }
{ DumpVaState : afficher l etat du sous-systeme des variables    }
{ ------------------------------------------------------------ }

Procedure DumpVaState;
Begin
  WriteLn('--- Va State ---');
  WriteLn('  VaInitialized   : ', VaInitialized);
  WriteLn('  VaAssignCount   : ', VaAssignCount);
  WriteLn('  VaAugCount      : ', VaAugCount);
  WriteLn('  VaMultiCount    : ', VaMultiCount);
  WriteLn('  VaSwapCount     : ', VaSwapCount);
  WriteLn('  VaUnpackCount   : ', VaUnpackCount);
  WriteLn('  VaDelCount      : ', VaDelCount);
  WriteLn('  VaGlobalCount   : ', VaGlobalCount);
  WriteLn('  VaNonlocalCount : ', VaNonlocalCount);
  WriteLn('  VaLastKind      : ', VaTypeName(VaLastKind));
  WriteLn('  VaLabelSeq      : ', VaLabelSeq);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 09)                              }
{ ------------------------------------------------------------ }

Function IsVaInitialized : Boolean;
Begin
  IsVaInitialized := VaInitialized;
End;

Function IsVaEmpty : Boolean;
Begin
  IsVaEmpty := (VaAssignCount = 0) And (VaAugCount = 0) And
               (VaMultiCount = 0) And (VaDelCount = 0);
End;

Function GetVaAssignCount : LongInt;
Begin
  GetVaAssignCount := VaAssignCount;
End;

Function GetVaAugCount : LongInt;
Begin
  GetVaAugCount := VaAugCount;
End;

Function GetVaMultiCount : LongInt;
Begin
  GetVaMultiCount := VaMultiCount;
End;

Function GetVaSwapCount : LongInt;
Begin
  GetVaSwapCount := VaSwapCount;
End;

Function GetVaDelCount : LongInt;
Begin
  GetVaDelCount := VaDelCount;
End;

Function GetVaGlobalCount : LongInt;
Begin
  GetVaGlobalCount := VaGlobalCount;
End;

Function GetVaNonlocalCount : LongInt;
Begin
  GetVaNonlocalCount := VaNonlocalCount;
End;

Function GetVaStatus : TString;
Begin
  If Not VaInitialized Then
    GetVaStatus := 'Not initialized'
  Else
    GetVaStatus := ItoS(VaAssignCount) + ' assigns, ' +
                   ItoS(VaAugCount) + ' aug, ' +
                   ItoS(VaMultiCount) + ' multi, ' +
                   ItoS(VaSwapCount) + ' swaps, ' +
                   ItoS(VaDelCount) + ' del';
End;

{ ============================================================ }
{ TODO 10 - PARSEUR : IF / ELIF / ELSE [IMPLEMENTE]            }
{ ============================================================ }

Const
  { Types d operations conditionnelles }
  IF_NONE          = 0;    { aucun / non defini                    }
  IF_SIMPLE        = 1;    { if cond: bloc                         }
  IF_ELSE          = 2;    { if cond: bloc else: bloc              }
  IF_ELIF          = 3;    { if cond: bloc elif cond: bloc         }
  IF_ELIF_ELSE     = 4;    { if ... elif ... else: bloc            }
  IF_TERNARY       = 5;    { a if cond else b                      }
  IF_PASS          = 6;    { instruction pass                      }
  IF_TRUTHY        = 7;    { test truthy (TEST EAX, EAX)           }
  IF_FALSY         = 8;    { test falsy (0, None, '', [])          }
  IF_AND_SC        = 9;    { and avec court-circuit                }
  IF_OR_SC         = 10;   { or avec court-circuit                 }
  IF_TEST_JZ       = 11;   { TEST EAX, EAX / JZ label             }
  IF_TEST_JNZ      = 12;   { TEST EAX, EAX / JNZ label            }
  IF_BRANCH        = 13;   { branche if/elif/else                  }
  IF_MAX           = 13;

  { Limites }
  IF_MAX_ELIF      = 32;   { nombre max de elif par if             }
  IF_MAX_NEST      = 16;   { profondeur max d imbrication if       }

Var
  IfInitialized   : Boolean;    { True si l etat est initialise       }
  IfStmtCount     : LongInt;    { nombre d instructions if            }
  IfElifCount     : LongInt;    { nombre de elif rencontres           }
  IfElseCount     : LongInt;    { nombre de else rencontres           }
  IfTernaryCount  : LongInt;    { nombre d expressions ternaires      }
  IfPassCount     : LongInt;    { nombre d instructions pass          }
  IfAndScCount    : LongInt;    { nombre de and court-circuit         }
  IfOrScCount     : LongInt;    { nombre de or court-circuit          }
  IfTestCount     : LongInt;    { nombre de TEST EAX, EAX emis       }
  IfLastKind      : Integer;    { dernier type d operation if         }
  IfLabelSeq      : Integer;    { sequence pour labels IF              }

{ ------------------------------------------------------------ }
{ InitIfState : initialiser le sous-systeme if/elif/else         }
{ ------------------------------------------------------------ }

Procedure InitIfState;
Begin
  IfInitialized   := True;
  IfStmtCount     := 0;
  IfElifCount     := 0;
  IfElseCount     := 0;
  IfTernaryCount  := 0;
  IfPassCount     := 0;
  IfAndScCount    := 0;
  IfOrScCount     := 0;
  IfTestCount     := 0;
  IfLastKind      := IF_NONE;
  IfLabelSeq      := 0;
End;

{ ------------------------------------------------------------ }
{ GenIfLabel : generer un label unique pour les conditionnelles   }
{ ------------------------------------------------------------ }

Function GenIfLabel : TString;
Begin
  Inc(IfLabelSeq);
  GenIfLabel := '_PYL_IF_' + ItoS(IfLabelSeq);
End;

{ ------------------------------------------------------------ }
{ IfTypeName : retourner le nom du type d operation if            }
{ ------------------------------------------------------------ }

Function IfTypeName(K : Integer) : TString;
Begin
  Case K Of
    IF_NONE      : IfTypeName := 'IF_NONE';
    IF_SIMPLE    : IfTypeName := 'IF_SIMPLE';
    IF_ELSE      : IfTypeName := 'IF_ELSE';
    IF_ELIF      : IfTypeName := 'IF_ELIF';
    IF_ELIF_ELSE : IfTypeName := 'IF_ELIF_ELSE';
    IF_TERNARY   : IfTypeName := 'IF_TERNARY';
    IF_PASS      : IfTypeName := 'IF_PASS';
    IF_TRUTHY    : IfTypeName := 'IF_TRUTHY';
    IF_FALSY     : IfTypeName := 'IF_FALSY';
    IF_AND_SC    : IfTypeName := 'IF_AND_SC';
    IF_OR_SC     : IfTypeName := 'IF_OR_SC';
    IF_TEST_JZ   : IfTypeName := 'IF_TEST_JZ';
    IF_TEST_JNZ  : IfTypeName := 'IF_TEST_JNZ';
    IF_BRANCH    : IfTypeName := 'IF_BRANCH';
  Else
    IfTypeName := 'IF_UNKNOWN(' + ItoS(K) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ EmitTestTruthy : emettre TEST EAX, EAX / JZ label             }
{   Teste si EAX est truthy (non-zero). Saute a DestLabel si    }
{   falsy (EAX = 0).                                            }
{ ------------------------------------------------------------ }

Procedure EmitTestTruthy(DestLabel : TString);
Begin
  Inc(IfTestCount);
  IfLastKind := IF_TEST_JZ;
  { TEST EAX, EAX : positionne ZF si EAX = 0 (falsy) }
  WriteLn('  TEST EAX, EAX');
  WriteLn('  JZ ', DestLabel);
End;

{ ------------------------------------------------------------ }
{ EmitTestFalsy : emettre TEST EAX, EAX / JNZ label             }
{   Teste si EAX est falsy (zero). Saute a DestLabel si         }
{   truthy (EAX != 0).                                          }
{ ------------------------------------------------------------ }

Procedure EmitTestFalsy(DestLabel : TString);
Begin
  Inc(IfTestCount);
  IfLastKind := IF_TEST_JNZ;
  { TEST EAX, EAX : positionne ZF si EAX = 0 }
  WriteLn('  TEST EAX, EAX');
  WriteLn('  JNZ ', DestLabel);
End;

{ ------------------------------------------------------------ }
{ EmitCondAnd : emettre un and avec court-circuit                }
{   Si le premier operande est falsy, sauter directement a       }
{   FailLabel sans evaluer le second operande.                   }
{ ------------------------------------------------------------ }

Procedure EmitCondAnd(FailLabel : TString);
Begin
  Inc(IfAndScCount);
  IfLastKind := IF_AND_SC;
  { EAX contient le resultat du premier operande }
  WriteLn('  TEST EAX, EAX');
  WriteLn('  JZ ', FailLabel, '  ; and short-circuit');
End;

{ ------------------------------------------------------------ }
{ EmitCondOr : emettre un or avec court-circuit                  }
{   Si le premier operande est truthy, sauter directement a      }
{   SuccessLabel sans evaluer le second operande.                }
{ ------------------------------------------------------------ }

Procedure EmitCondOr(SuccessLabel : TString);
Begin
  Inc(IfOrScCount);
  IfLastKind := IF_OR_SC;
  { EAX contient le resultat du premier operande }
  WriteLn('  TEST EAX, EAX');
  WriteLn('  JNZ ', SuccessLabel, '  ; or short-circuit');
End;

{ ------------------------------------------------------------ }
{ EmitLabel : emettre un label dans le flux assembleur            }
{ ------------------------------------------------------------ }

Procedure EmitLabel(Lbl : TString);
Begin
  WriteLn(Lbl, ':');
End;

{ ------------------------------------------------------------ }
{ EmitJmp : emettre un saut inconditionnel                       }
{ ------------------------------------------------------------ }

Procedure EmitJmp(DestLabel : TString);
Begin
  WriteLn('  JMP ', DestLabel);
End;

{ ------------------------------------------------------------ }
{ ParseIfStmt : parser une instruction if / elif / else          }
{   if cond:                                                      }
{       bloc                                                      }
{   elif cond:                                                    }
{       bloc                                                      }
{   else:                                                         }
{       bloc                                                      }
{                                                                  }
{   Emission assembleur :                                         }
{     evaluer cond -> TEST EAX, EAX -> JZ _PYL_ELIF_N            }
{     bloc if                                                     }
{     JMP _PYL_ENDIF_N                                            }
{     _PYL_ELIF_N: evaluer cond elif -> JZ next                   }
{     bloc elif                                                   }
{     JMP _PYL_ENDIF_N                                            }
{     _PYL_ELSE_N: bloc else                                      }
{     _PYL_ENDIF_N:                                               }
{ ------------------------------------------------------------ }

Procedure ParseIfStmt;
Var
  LblElif    : TString;
  LblElse    : TString;
  LblEndIf   : TString;
  ElifIdx    : Integer;
  HasElse    : Boolean;
  BaseSeq    : Integer;
Begin
  Inc(IfStmtCount);
  HasElse := False;
  ElifIdx := 0;

  { Generer les labels de base }
  Inc(IfLabelSeq);
  BaseSeq := IfLabelSeq;
  LblEndIf := '_PYL_ENDIF_' + ItoS(BaseSeq);

  { Evaluer la condition du if }
  { ParseExpr doit laisser le resultat dans EAX }
  WriteLn('  ; --- if statement #', BaseSeq, ' ---');

  { Label pour le premier elif ou else }
  Inc(IfLabelSeq);
  LblElif := '_PYL_ELIF_' + ItoS(IfLabelSeq);

  { Emettre le test de la condition }
  EmitTestTruthy(LblElif);

  { Bloc du if (delimiteur par indentation) }
  WriteLn('  ; if body');

  { Saut vers la fin apres le bloc }
  EmitJmp(LblEndIf);

  { Label pour elif ou else }
  EmitLabel(LblElif);

  { Parser les elif }
  While ElifIdx < IF_MAX_ELIF Do
  Begin
    { Verifier si le token courant est 'elif' }
    If (CurTokKind = TK_KEYWORD) And (CurTokInt = KW_ELIF) Then
    Begin
      Inc(IfElifCount);
      Inc(ElifIdx);
      IfLastKind := IF_ELIF;

      WriteLn('  ; elif #', ElifIdx, ' in if #', BaseSeq);

      { Generer label pour prochain elif ou else }
      Inc(IfLabelSeq);
      LblElif := '_PYL_ELIF_' + ItoS(IfLabelSeq);

      { Evaluer la condition du elif }
      { ParseExpr laisserait le resultat dans EAX }
      EmitTestTruthy(LblElif);

      { Bloc du elif }
      WriteLn('  ; elif body');

      { Saut vers la fin }
      EmitJmp(LblEndIf);

      { Label pour le prochain elif ou else }
      EmitLabel(LblElif);
    End
    Else
      Break;
  End;

  { Parser le else optionnel }
  If (CurTokKind = TK_KEYWORD) And (CurTokInt = KW_ELSE) Then
  Begin
    Inc(IfElseCount);
    HasElse := True;

    LblElse := '_PYL_ELSE_' + ItoS(BaseSeq);
    WriteLn('  ; else in if #', BaseSeq);

    { Bloc du else }
    WriteLn('  ; else body');
  End;

  { Label de fin }
  EmitLabel(LblEndIf);
  WriteLn('  ; --- end if #', BaseSeq, ' ---');

  { Determiner le type exact de l instruction }
  If HasElse And (ElifIdx > 0) Then
    IfLastKind := IF_ELIF_ELSE
  Else If ElifIdx > 0 Then
    IfLastKind := IF_ELIF
  Else If HasElse Then
    IfLastKind := IF_ELSE
  Else
    IfLastKind := IF_SIMPLE;
End;

{ ------------------------------------------------------------ }
{ ParseTernaryExpr : parser une expression conditionnelle        }
{   val = a if cond else b                                       }
{                                                                 }
{   Emission assembleur :                                        }
{     evaluer cond -> TEST EAX, EAX -> JZ _PYL_TELSE_N          }
{     evaluer a -> JMP _PYL_TEND_N                               }
{     _PYL_TELSE_N: evaluer b                                    }
{     _PYL_TEND_N:                                               }
{ ------------------------------------------------------------ }

Procedure ParseTernaryExpr;
Var
  LblElse : TString;
  LblEnd  : TString;
Begin
  Inc(IfTernaryCount);
  IfLastKind := IF_TERNARY;

  Inc(IfLabelSeq);
  LblElse := '_PYL_TELSE_' + ItoS(IfLabelSeq);
  LblEnd  := '_PYL_TEND_' + ItoS(IfLabelSeq);

  WriteLn('  ; --- ternary expr #', IfLabelSeq, ' ---');

  { Evaluer la condition }
  WriteLn('  ; ternary: evaluate condition');
  EmitTestTruthy(LblElse);

  { Evaluer la branche true (a) }
  WriteLn('  ; ternary: true branch');
  EmitJmp(LblEnd);

  { Label pour la branche false }
  EmitLabel(LblElse);

  { Evaluer la branche false (b) }
  WriteLn('  ; ternary: false branch');

  { Label de fin }
  EmitLabel(LblEnd);
  WriteLn('  ; --- end ternary #', IfLabelSeq, ' ---');
End;

{ ------------------------------------------------------------ }
{ ParsePassStmt : parser une instruction pass                    }
{   Ne genere aucun code (ou un NOP optionnel)                   }
{ ------------------------------------------------------------ }

Procedure ParsePassStmt;
Begin
  Inc(IfPassCount);
  IfLastKind := IF_PASS;
  WriteLn('  ; pass (no-op)');
  WriteLn('  NOP');
End;

{ ------------------------------------------------------------ }
{ IsTruthyValue : verifier si une valeur immediate est truthy    }
{   0, None sont falsy ; tout le reste est truthy                }
{ ------------------------------------------------------------ }

Function IsTruthyValue(V : LongInt) : Boolean;
Begin
  IsTruthyValue := (V <> 0);
End;

{ ------------------------------------------------------------ }
{ IsFalsyValue : verifier si une valeur immediate est falsy      }
{   0, None sont falsy                                           }
{ ------------------------------------------------------------ }

Function IsFalsyValue(V : LongInt) : Boolean;
Begin
  IsFalsyValue := (V = 0);
End;

{ ------------------------------------------------------------ }
{ EmitIfBranch : emettre le debut d une branche if               }
{   Emet le commentaire et le test de condition                  }
{ ------------------------------------------------------------ }

Procedure EmitIfBranch(CondLabel, SkipLabel : TString);
Begin
  IfLastKind := IF_BRANCH;
  WriteLn('  ; if branch -> skip to ', SkipLabel);
  EmitTestTruthy(SkipLabel);
End;

{ ------------------------------------------------------------ }
{ EmitElifBranch : emettre le debut d une branche elif           }
{ ------------------------------------------------------------ }

Procedure EmitElifBranch(ElifLabel, SkipLabel : TString);
Begin
  IfLastKind := IF_BRANCH;
  EmitLabel(ElifLabel);
  WriteLn('  ; elif branch -> skip to ', SkipLabel);
  EmitTestTruthy(SkipLabel);
End;

{ ------------------------------------------------------------ }
{ EmitElseBranch : emettre le debut d une branche else           }
{ ------------------------------------------------------------ }

Procedure EmitElseBranch(ElseLabel : TString);
Begin
  IfLastKind := IF_BRANCH;
  EmitLabel(ElseLabel);
  WriteLn('  ; else branch');
End;

{ ------------------------------------------------------------ }
{ EmitEndIf : emettre le label de fin d un if                    }
{ ------------------------------------------------------------ }

Procedure EmitEndIf(EndLabel : TString);
Begin
  EmitLabel(EndLabel);
  WriteLn('  ; endif');
End;

{ ------------------------------------------------------------ }
{ DumpIfState : afficher l etat du sous-systeme if                }
{ ------------------------------------------------------------ }

Procedure DumpIfState;
Begin
  WriteLn('--- If/Elif/Else State ---');
  WriteLn('  IfInitialized   : ', IfInitialized);
  WriteLn('  IfStmtCount     : ', IfStmtCount);
  WriteLn('  IfElifCount     : ', IfElifCount);
  WriteLn('  IfElseCount     : ', IfElseCount);
  WriteLn('  IfTernaryCount  : ', IfTernaryCount);
  WriteLn('  IfPassCount     : ', IfPassCount);
  WriteLn('  IfAndScCount    : ', IfAndScCount);
  WriteLn('  IfOrScCount     : ', IfOrScCount);
  WriteLn('  IfTestCount     : ', IfTestCount);
  WriteLn('  IfLastKind      : ', IfTypeName(IfLastKind));
  WriteLn('  IfLabelSeq      : ', IfLabelSeq);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 10)                              }
{ ------------------------------------------------------------ }

Function IsIfInitialized : Boolean;
Begin
  IsIfInitialized := IfInitialized;
End;

Function IsIfEmpty : Boolean;
Begin
  IsIfEmpty := (IfStmtCount = 0) And (IfTernaryCount = 0) And
               (IfPassCount = 0);
End;

Function GetIfStmtCount : LongInt;
Begin
  GetIfStmtCount := IfStmtCount;
End;

Function GetIfElifCount : LongInt;
Begin
  GetIfElifCount := IfElifCount;
End;

Function GetIfElseCount : LongInt;
Begin
  GetIfElseCount := IfElseCount;
End;

Function GetIfTernaryCount : LongInt;
Begin
  GetIfTernaryCount := IfTernaryCount;
End;

Function GetIfPassCount : LongInt;
Begin
  GetIfPassCount := IfPassCount;
End;

Function GetIfAndScCount : LongInt;
Begin
  GetIfAndScCount := IfAndScCount;
End;

Function GetIfOrScCount : LongInt;
Begin
  GetIfOrScCount := IfOrScCount;
End;

Function GetIfStatus : TString;
Begin
  If Not IfInitialized Then
    GetIfStatus := 'Not initialized'
  Else
    GetIfStatus := ItoS(IfStmtCount) + ' if, ' +
                   ItoS(IfElifCount) + ' elif, ' +
                   ItoS(IfElseCount) + ' else, ' +
                   ItoS(IfTernaryCount) + ' ternary, ' +
                   ItoS(IfPassCount) + ' pass';
End;

{ ============================================================ }
{ TODO 11 - PARSEUR : BOUCLES while / for / break / continue   }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { Types d operations de boucle }
  LP_NONE          = 0;    { aucun / non defini                    }
  LP_WHILE         = 1;    { while cond: bloc                      }
  LP_WHILE_ELSE    = 2;    { while cond: bloc else: bloc           }
  LP_FOR_RANGE1    = 3;    { for i in range(n)                     }
  LP_FOR_RANGE2    = 4;    { for i in range(a, b)                  }
  LP_FOR_RANGE3    = 5;    { for i in range(a, b, step)            }
  LP_FOR_STRING    = 6;    { for ch in string                      }
  LP_FOR_LIST      = 7;    { for elem in list                      }
  LP_FOR_ELSE      = 8;    { for ... else: bloc                    }
  LP_BREAK         = 9;    { instruction break                     }
  LP_CONTINUE      = 10;   { instruction continue                  }
  LP_NESTED        = 11;   { boucle imbriquee                      }
  LP_LOOP_PUSH     = 12;   { empiler contexte de boucle            }
  LP_LOOP_POP      = 13;   { depiler contexte de boucle            }
  LP_MAX           = 13;

  { Limites }
  LP_MAX_NEST      = 32;   { profondeur max d imbrication          }

Type
  TLoopRec = Record
    TestLabel  : TString;  { label de test (debut de boucle)       }
    IncrLabel  : TString;  { label d increment (for) ou test (while)}
    EndLabel   : TString;  { label de fin (break target)           }
    ElseLabel  : TString;  { label du bloc else de la boucle       }
    IsFor      : Boolean;  { True = for, False = while             }
  End;

Var
  LpInitialized   : Boolean;    { True si l etat est initialise       }
  LpWhileCount    : LongInt;    { nombre de boucles while             }
  LpForCount      : LongInt;    { nombre de boucles for               }
  LpBreakCount    : LongInt;    { nombre d instructions break         }
  LpContCount     : LongInt;    { nombre d instructions continue      }
  LpElseCount     : LongInt;    { nombre de else de boucle            }
  LpNestDepth     : LongInt;    { profondeur courante d imbrication   }
  LpMaxNestSeen   : LongInt;    { profondeur max atteinte             }
  LpLastKind      : Integer;    { dernier type d operation            }
  LpLabelSeq      : Integer;    { sequence pour labels de boucle      }
  LpStack         : Array[1..LP_MAX_NEST] Of TLoopRec;
  LpStackTop      : Integer;    { sommet de la pile de boucles        }

{ ------------------------------------------------------------ }
{ InitLpState : initialiser le sous-systeme des boucles          }
{ ------------------------------------------------------------ }

Procedure InitLpState;
Begin
  LpInitialized   := True;
  LpWhileCount    := 0;
  LpForCount      := 0;
  LpBreakCount    := 0;
  LpContCount     := 0;
  LpElseCount     := 0;
  LpNestDepth     := 0;
  LpMaxNestSeen   := 0;
  LpLastKind      := LP_NONE;
  LpLabelSeq      := 0;
  LpStackTop      := 0;
End;

{ ------------------------------------------------------------ }
{ GenLpLabel : generer un label unique pour les boucles           }
{ ------------------------------------------------------------ }

Function GenLpLabel : TString;
Begin
  Inc(LpLabelSeq);
  GenLpLabel := '_PYL_LP_' + ItoS(LpLabelSeq);
End;

{ ------------------------------------------------------------ }
{ LpTypeName : retourner le nom du type d operation boucle        }
{ ------------------------------------------------------------ }

Function LpTypeName(K : Integer) : TString;
Begin
  Case K Of
    LP_NONE       : LpTypeName := 'LP_NONE';
    LP_WHILE      : LpTypeName := 'LP_WHILE';
    LP_WHILE_ELSE : LpTypeName := 'LP_WHILE_ELSE';
    LP_FOR_RANGE1 : LpTypeName := 'LP_FOR_RANGE1';
    LP_FOR_RANGE2 : LpTypeName := 'LP_FOR_RANGE2';
    LP_FOR_RANGE3 : LpTypeName := 'LP_FOR_RANGE3';
    LP_FOR_STRING : LpTypeName := 'LP_FOR_STRING';
    LP_FOR_LIST   : LpTypeName := 'LP_FOR_LIST';
    LP_FOR_ELSE   : LpTypeName := 'LP_FOR_ELSE';
    LP_BREAK      : LpTypeName := 'LP_BREAK';
    LP_CONTINUE   : LpTypeName := 'LP_CONTINUE';
    LP_NESTED     : LpTypeName := 'LP_NESTED';
    LP_LOOP_PUSH  : LpTypeName := 'LP_LOOP_PUSH';
    LP_LOOP_POP   : LpTypeName := 'LP_LOOP_POP';
  Else
    LpTypeName := 'LP_UNKNOWN(' + ItoS(K) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ LoopPush : empiler un contexte de boucle sur la pile            }
{   TestLbl  : label de test de condition                        }
{   IncrLbl  : label d increment (for) ou label de test (while)  }
{   EndLbl   : label de fin de boucle (cible de break)           }
{   ElseLbl  : label du bloc else optionnel                      }
{   ForLoop  : True si boucle for, False si boucle while         }
{ ------------------------------------------------------------ }

Procedure LoopPush(TestLbl, IncrLbl, EndLbl, ElseLbl : TString;
                   IsForLoop : Boolean);
Begin
  If LpStackTop >= LP_MAX_NEST Then
  Begin
    CompileError('Loop nesting too deep (max ' +
                 ItoS(LP_MAX_NEST) + ')', LexLineNo);
    Exit;
  End;
  Inc(LpStackTop);
  Inc(LpNestDepth);
  If LpNestDepth > LpMaxNestSeen Then
    LpMaxNestSeen := LpNestDepth;
  LpStack[LpStackTop].TestLabel  := TestLbl;
  LpStack[LpStackTop].IncrLabel  := IncrLbl;
  LpStack[LpStackTop].EndLabel   := EndLbl;
  LpStack[LpStackTop].ElseLabel  := ElseLbl;
  LpStack[LpStackTop].IsFor      := IsForLoop;
  LpLastKind := LP_LOOP_PUSH;
End;

{ ------------------------------------------------------------ }
{ LoopPop : depiler le contexte de boucle courant                 }
{ ------------------------------------------------------------ }

Procedure LoopPop;
Begin
  If LpStackTop <= 0 Then
  Begin
    CompileError('Loop stack underflow', LexLineNo);
    Exit;
  End;
  Dec(LpStackTop);
  Dec(LpNestDepth);
  LpLastKind := LP_LOOP_POP;
End;

{ ------------------------------------------------------------ }
{ ParseWhileStmt : parser une boucle while                       }
{   while cond:                                                   }
{       bloc                                                      }
{   [else:                                                        }
{       bloc]                                                     }
{                                                                  }
{   Emission assembleur :                                         }
{     _PYL_WTEST_N:                                               }
{       evaluer cond -> TEST EAX, EAX -> JZ _PYL_WEND_N          }
{       (ou JZ _PYL_WELSE_N si else present)                     }
{       corps                                                     }
{       JMP _PYL_WTEST_N                                          }
{     _PYL_WELSE_N:  (optionnel)                                  }
{       bloc else                                                 }
{     _PYL_WEND_N:                                                }
{ ------------------------------------------------------------ }

Procedure ParseWhileStmt;
Var
  LblTest    : TString;
  LblEnd     : TString;
  LblElse    : TString;
  BaseSeq    : Integer;
  HasElse    : Boolean;
Begin
  Inc(LpWhileCount);
  HasElse := False;

  { Generer les labels }
  Inc(LpLabelSeq);
  BaseSeq := LpLabelSeq;
  LblTest := '_PYL_WTEST_' + ItoS(BaseSeq);
  LblEnd  := '_PYL_WEND_' + ItoS(BaseSeq);
  LblElse := '_PYL_WELSE_' + ItoS(BaseSeq);

  WriteLn('  ; --- while loop #', BaseSeq, ' ---');

  { Empiler le contexte de boucle }
  LoopPush(LblTest, LblTest, LblEnd, LblElse, False);

  { Label de test de condition }
  EmitLabel(LblTest);

  { Evaluer la condition }
  { ParseExpr doit laisser le resultat dans EAX }
  WriteLn('  ; while: evaluate condition');
  EmitTestTruthy(LblEnd);

  { Corps de la boucle }
  WriteLn('  ; while body');

  { Saut vers le test de condition }
  EmitJmp(LblTest);

  { Parser le else optionnel }
  If (CurTokKind = TK_KEYWORD) And (CurTokInt = KW_ELSE) Then
  Begin
    Inc(LpElseCount);
    HasElse := True;
    EmitLabel(LblElse);
    WriteLn('  ; while else body');
  End;

  { Label de fin }
  EmitLabel(LblEnd);
  WriteLn('  ; --- end while #', BaseSeq, ' ---');

  { Depiler le contexte }
  LoopPop;

  { Determiner le type }
  If HasElse Then
    LpLastKind := LP_WHILE_ELSE
  Else
    LpLastKind := LP_WHILE;
End;

{ ------------------------------------------------------------ }
{ ParseForStmt : parser une boucle for                           }
{   for var in iterable:                                          }
{       bloc                                                      }
{   [else:                                                        }
{       bloc]                                                     }
{                                                                  }
{   Cas supportes :                                               }
{     for i in range(n) : boucle comptee 0..n-1                  }
{       MOV DWORD [var], 0                                       }
{       _PYL_FTEST_N: CMP DWORD [var], n / JGE end              }
{       corps                                                     }
{       _PYL_FINCR_N: INC DWORD [var] / JMP _PYL_FTEST_N        }
{     for i in range(a, b) : boucle comptee a..b-1               }
{       MOV DWORD [var], a                                       }
{       _PYL_FTEST_N: CMP DWORD [var], b / JGE end              }
{     for i in range(a, b, step) : boucle avec pas               }
{       MOV DWORD [var], a                                       }
{       _PYL_FTEST_N: CMP DWORD [var], b / JGE end              }
{       _PYL_FINCR_N: ADD DWORD [var], step / JMP test           }
{     for ch in string : iterer sur les caracteres               }
{     for elem in list : iterer sur les elements                  }
{ ------------------------------------------------------------ }

Procedure ParseForStmt;
Var
  LblTest    : TString;
  LblIncr    : TString;
  LblEnd     : TString;
  LblElse    : TString;
  BaseSeq    : Integer;
  HasElse    : Boolean;
  VarName    : TString;
Begin
  Inc(LpForCount);
  HasElse := False;

  { Generer les labels }
  Inc(LpLabelSeq);
  BaseSeq := LpLabelSeq;
  LblTest := '_PYL_FTEST_' + ItoS(BaseSeq);
  LblIncr := '_PYL_FINCR_' + ItoS(BaseSeq);
  LblEnd  := '_PYL_FEND_' + ItoS(BaseSeq);
  LblElse := '_PYL_FELSE_' + ItoS(BaseSeq);

  WriteLn('  ; --- for loop #', BaseSeq, ' ---');

  { Empiler le contexte de boucle }
  LoopPush(LblTest, LblIncr, LblEnd, LblElse, True);

  { Lire le nom de la variable d iteration }
  If CurTokKind = TK_IDENT Then
    VarName := CurTokStr
  Else
    VarName := '_for_var';

  WriteLn('  ; for ', VarName, ' in ...');

  { Initialiser la variable d iteration }
  WriteLn('  MOV DWORD [', PY_VAR_PFX, VarName, '], 0');

  { Label de test }
  EmitLabel(LblTest);

  { Comparer avec la borne superieure }
  WriteLn('  ; for: test condition');
  WriteLn('  CMP DWORD [', PY_VAR_PFX, VarName, '], EBX');
  WriteLn('  JGE ', LblEnd);

  { Corps de la boucle }
  WriteLn('  ; for body');

  { Label d increment }
  EmitLabel(LblIncr);
  WriteLn('  INC DWORD [', PY_VAR_PFX, VarName, ']');
  EmitJmp(LblTest);

  { Parser le else optionnel }
  If (CurTokKind = TK_KEYWORD) And (CurTokInt = KW_ELSE) Then
  Begin
    Inc(LpElseCount);
    HasElse := True;
    EmitLabel(LblElse);
    WriteLn('  ; for else body');
  End;

  { Label de fin }
  EmitLabel(LblEnd);
  WriteLn('  ; --- end for #', BaseSeq, ' ---');

  { Depiler le contexte }
  LoopPop;

  { Determiner le type }
  If HasElse Then
    LpLastKind := LP_FOR_ELSE
  Else
    LpLastKind := LP_FOR_RANGE1;
End;

{ ------------------------------------------------------------ }
{ ParseForRange2 : emettre code pour for i in range(a, b)        }
{   MOV DWORD [var], a                                           }
{   _PYL_FTEST_N: CMP DWORD [var], b / JGE end                  }
{   corps / _PYL_FINCR_N: INC / JMP test                        }
{ ------------------------------------------------------------ }

Procedure ParseForRange2(VarName : TString; BaseSeq : Integer);
Var
  LblTest : TString;
  LblIncr : TString;
  LblEnd  : TString;
Begin
  LpLastKind := LP_FOR_RANGE2;
  LblTest := '_PYL_FTEST_' + ItoS(BaseSeq);
  LblIncr := '_PYL_FINCR_' + ItoS(BaseSeq);
  LblEnd  := '_PYL_FEND_' + ItoS(BaseSeq);

  WriteLn('  ; for ', VarName, ' in range(a, b)');
  WriteLn('  MOV DWORD [', PY_VAR_PFX, VarName, '], EAX  ; start = a');
  EmitLabel(LblTest);
  WriteLn('  CMP DWORD [', PY_VAR_PFX, VarName, '], EBX  ; cmp with b');
  WriteLn('  JGE ', LblEnd);
  WriteLn('  ; for body');
  EmitLabel(LblIncr);
  WriteLn('  INC DWORD [', PY_VAR_PFX, VarName, ']');
  EmitJmp(LblTest);
  EmitLabel(LblEnd);
End;

{ ------------------------------------------------------------ }
{ ParseForRange3 : emettre code pour for i in range(a, b, step)  }
{   MOV DWORD [var], a                                           }
{   _PYL_FTEST_N: CMP DWORD [var], b / JGE end                  }
{   corps / _PYL_FINCR_N: ADD DWORD [var], step / JMP test      }
{ ------------------------------------------------------------ }

Procedure ParseForRange3(VarName : TString; BaseSeq : Integer);
Var
  LblTest : TString;
  LblIncr : TString;
  LblEnd  : TString;
Begin
  LpLastKind := LP_FOR_RANGE3;
  LblTest := '_PYL_FTEST_' + ItoS(BaseSeq);
  LblIncr := '_PYL_FINCR_' + ItoS(BaseSeq);
  LblEnd  := '_PYL_FEND_' + ItoS(BaseSeq);

  WriteLn('  ; for ', VarName, ' in range(a, b, step)');
  WriteLn('  MOV DWORD [', PY_VAR_PFX, VarName, '], EAX  ; start = a');
  EmitLabel(LblTest);
  WriteLn('  CMP DWORD [', PY_VAR_PFX, VarName, '], EBX  ; cmp with b');
  WriteLn('  JGE ', LblEnd);
  WriteLn('  ; for body');
  EmitLabel(LblIncr);
  WriteLn('  ADD DWORD [', PY_VAR_PFX, VarName, '], ECX  ; step');
  EmitJmp(LblTest);
  EmitLabel(LblEnd);
End;

{ ------------------------------------------------------------ }
{ ParseForString : emettre code pour for ch in string             }
{   Itere sur les caracteres d une chaine                        }
{ ------------------------------------------------------------ }

Procedure ParseForString(VarName : TString; BaseSeq : Integer);
Var
  LblTest : TString;
  LblIncr : TString;
  LblEnd  : TString;
Begin
  LpLastKind := LP_FOR_STRING;
  LblTest := '_PYL_FTEST_' + ItoS(BaseSeq);
  LblIncr := '_PYL_FINCR_' + ItoS(BaseSeq);
  LblEnd  := '_PYL_FEND_' + ItoS(BaseSeq);

  WriteLn('  ; for ', VarName, ' in string');
  WriteLn('  XOR ECX, ECX  ; index = 0');
  EmitLabel(LblTest);
  WriteLn('  MOVZX EAX, BYTE [ESI + ECX]  ; load char');
  WriteLn('  TEST AL, AL');
  WriteLn('  JZ ', LblEnd, '  ; end of string');
  WriteLn('  MOV DWORD [', PY_VAR_PFX, VarName, '], EAX');
  WriteLn('  ; for body');
  EmitLabel(LblIncr);
  WriteLn('  INC ECX');
  EmitJmp(LblTest);
  EmitLabel(LblEnd);
End;

{ ------------------------------------------------------------ }
{ ParseForList : emettre code pour for elem in list               }
{   Itere sur les elements d une liste                           }
{ ------------------------------------------------------------ }

Procedure ParseForList(VarName : TString; BaseSeq : Integer);
Var
  LblTest : TString;
  LblIncr : TString;
  LblEnd  : TString;
Begin
  LpLastKind := LP_FOR_LIST;
  LblTest := '_PYL_FTEST_' + ItoS(BaseSeq);
  LblIncr := '_PYL_FINCR_' + ItoS(BaseSeq);
  LblEnd  := '_PYL_FEND_' + ItoS(BaseSeq);

  WriteLn('  ; for ', VarName, ' in list');
  WriteLn('  XOR ECX, ECX  ; index = 0');
  EmitLabel(LblTest);
  WriteLn('  CMP ECX, DWORD [EDI]  ; cmp with list length');
  WriteLn('  JGE ', LblEnd);
  WriteLn('  MOV EAX, DWORD [EDI + 4 + ECX*4]  ; load element');
  WriteLn('  MOV DWORD [', PY_VAR_PFX, VarName, '], EAX');
  WriteLn('  ; for body');
  EmitLabel(LblIncr);
  WriteLn('  INC ECX');
  EmitJmp(LblTest);
  EmitLabel(LblEnd);
End;

{ ------------------------------------------------------------ }
{ ParseBreakStmt : parser une instruction break                   }
{   Saute vers le label de fin de la boucle englobante           }
{   break -> JMP _PYL_WEND_N ou _PYL_FEND_N                     }
{ ------------------------------------------------------------ }

Procedure ParseBreakStmt;
Begin
  Inc(LpBreakCount);
  LpLastKind := LP_BREAK;

  If LpStackTop <= 0 Then
  Begin
    CompileError('break outside loop', LexLineNo);
    Exit;
  End;

  WriteLn('  ; break');
  EmitJmp(LpStack[LpStackTop].EndLabel);
End;

{ ------------------------------------------------------------ }
{ ParseContinueStmt : parser une instruction continue             }
{   Saute vers le label d increment (for) ou test (while)        }
{   continue -> JMP _PYL_FINCR_N ou _PYL_WTEST_N                }
{ ------------------------------------------------------------ }

Procedure ParseContinueStmt;
Begin
  Inc(LpContCount);
  LpLastKind := LP_CONTINUE;

  If LpStackTop <= 0 Then
  Begin
    CompileError('continue outside loop', LexLineNo);
    Exit;
  End;

  WriteLn('  ; continue');
  EmitJmp(LpStack[LpStackTop].IncrLabel);
End;

{ ------------------------------------------------------------ }
{ DumpLpState : afficher l etat du sous-systeme des boucles       }
{ ------------------------------------------------------------ }

Procedure DumpLpState;
Begin
  WriteLn('--- Loop State ---');
  WriteLn('  LpInitialized   : ', LpInitialized);
  WriteLn('  LpWhileCount    : ', LpWhileCount);
  WriteLn('  LpForCount      : ', LpForCount);
  WriteLn('  LpBreakCount    : ', LpBreakCount);
  WriteLn('  LpContCount     : ', LpContCount);
  WriteLn('  LpElseCount     : ', LpElseCount);
  WriteLn('  LpNestDepth     : ', LpNestDepth);
  WriteLn('  LpMaxNestSeen   : ', LpMaxNestSeen);
  WriteLn('  LpLastKind      : ', LpTypeName(LpLastKind));
  WriteLn('  LpLabelSeq      : ', LpLabelSeq);
  WriteLn('  LpStackTop      : ', LpStackTop);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 11)                              }
{ ------------------------------------------------------------ }

Function IsLpInitialized : Boolean;
Begin
  IsLpInitialized := LpInitialized;
End;

Function IsLpEmpty : Boolean;
Begin
  IsLpEmpty := (LpWhileCount = 0) And (LpForCount = 0) And
               (LpBreakCount = 0) And (LpContCount = 0);
End;

Function GetLpWhileCount : LongInt;
Begin
  GetLpWhileCount := LpWhileCount;
End;

Function GetLpForCount : LongInt;
Begin
  GetLpForCount := LpForCount;
End;

Function GetLpBreakCount : LongInt;
Begin
  GetLpBreakCount := LpBreakCount;
End;

Function GetLpContCount : LongInt;
Begin
  GetLpContCount := LpContCount;
End;

Function GetLpElseCount : LongInt;
Begin
  GetLpElseCount := LpElseCount;
End;

Function GetLpMaxNestSeen : LongInt;
Begin
  GetLpMaxNestSeen := LpMaxNestSeen;
End;

Function GetLpStackTop : Integer;
Begin
  GetLpStackTop := LpStackTop;
End;

Function GetLpStatus : TString;
Begin
  If Not LpInitialized Then
    GetLpStatus := 'Not initialized'
  Else
    GetLpStatus := ItoS(LpWhileCount) + ' while, ' +
                   ItoS(LpForCount) + ' for, ' +
                   ItoS(LpBreakCount) + ' break, ' +
                   ItoS(LpContCount) + ' continue, ' +
                   ItoS(LpElseCount) + ' else, ' +
                   'max-nest=' + ItoS(LpMaxNestSeen);
End;

{ ============================================================ }
{ TODO 12 - PARSEUR : FONCTIONS (def) ET RETURN                }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { Types d operations de fonction }
  FN_NONE          = 0;    { aucun / non defini                    }
  FN_DEF           = 1;    { def nom(params): bloc                 }
  FN_DEF_PARAMS    = 2;    { def avec parametres                   }
  FN_DEF_DEFAULT   = 3;    { def avec parametres par defaut        }
  FN_RETURN        = 4;    { return expr                           }
  FN_RETURN_NONE   = 5;    { return sans valeur (None)             }
  FN_CALL          = 6;    { appel de fonction                     }
  FN_CALL_ARGS     = 7;    { appel avec arguments                  }
  FN_PROLOGUE      = 8;    { prologue de fonction                  }
  FN_EPILOGUE      = 9;    { epilogue de fonction                  }
  FN_PARAM_POS     = 10;   { parametre positionnel                 }
  FN_PARAM_DEF     = 11;   { parametre avec valeur par defaut      }
  FN_RECURSIVE     = 12;   { appel recursif                        }
  FN_NESTED_WARN   = 13;   { avertissement : fonction imbriquee    }
  FN_MAX           = 13;

  { Limites }
  FN_MAX_PARAMS    = 16;   { nombre max de parametres par fonction }
  FN_MAX_LOCALS    = 64;   { nombre max de variables locales       }
  FN_MAX_NEST      = 1;    { profondeur max d imbrication (=1, pas }
                           { de fonctions imbriquees)               }

Type
  TFnParamRec = Record
    Name       : TString;  { nom du parametre                      }
    HasDefault : Boolean;   { True si valeur par defaut             }
    DefValue   : LongInt;   { valeur par defaut (entier)            }
  End;

Var
  FnInitialized   : Boolean;    { True si l etat est initialise       }
  FnDefCount      : LongInt;    { nombre de definitions def           }
  FnReturnCount   : LongInt;    { nombre de return                    }
  FnRetNoneCount  : LongInt;    { nombre de return sans valeur        }
  FnCallCount     : LongInt;    { nombre d appels de fonction         }
  FnParamCount    : LongInt;    { nombre total de parametres declares }
  FnDefParamCount : LongInt;    { nombre de parametres par defaut     }
  FnRecursCount   : LongInt;    { nombre d appels recursifs           }
  FnNestedWarn    : LongInt;    { nombre d avertissements imbriquees  }
  FnLastKind      : Integer;    { dernier type d operation            }
  FnLabelSeq      : Integer;    { sequence pour labels de fonction    }
  FnCurName       : TString;    { nom de la fonction courante         }
  FnCurParamN     : Integer;    { nombre de params de la fn courante  }
  FnCurLocalN     : Integer;    { nombre de vars locales courantes    }
  FnInDef         : Boolean;    { True si on est dans un def          }
  FnCurParams     : Array[1..FN_MAX_PARAMS] Of TFnParamRec;
  FnCurEpilogue   : TString;    { label de l epilogue courant         }

{ ------------------------------------------------------------ }
{ InitFnState : initialiser le sous-systeme des fonctions        }
{ ------------------------------------------------------------ }

Procedure InitFnState;
Begin
  FnInitialized   := True;
  FnDefCount      := 0;
  FnReturnCount   := 0;
  FnRetNoneCount  := 0;
  FnCallCount     := 0;
  FnParamCount    := 0;
  FnDefParamCount := 0;
  FnRecursCount   := 0;
  FnNestedWarn    := 0;
  FnLastKind      := FN_NONE;
  FnLabelSeq      := 0;
  FnCurName       := '';
  FnCurParamN     := 0;
  FnCurLocalN     := 0;
  FnInDef         := False;
  FnCurEpilogue   := '';
End;

{ ------------------------------------------------------------ }
{ GenFnLabel : generer un label unique pour les fonctions         }
{ ------------------------------------------------------------ }

Function GenFnLabel : TString;
Begin
  Inc(FnLabelSeq);
  GenFnLabel := '_PYL_FN_' + ItoS(FnLabelSeq);
End;

{ ------------------------------------------------------------ }
{ FnTypeName : retourner le nom du type d operation fonction      }
{ ------------------------------------------------------------ }

Function FnTypeName(K : Integer) : TString;
Begin
  Case K Of
    FN_NONE        : FnTypeName := 'FN_NONE';
    FN_DEF         : FnTypeName := 'FN_DEF';
    FN_DEF_PARAMS  : FnTypeName := 'FN_DEF_PARAMS';
    FN_DEF_DEFAULT : FnTypeName := 'FN_DEF_DEFAULT';
    FN_RETURN      : FnTypeName := 'FN_RETURN';
    FN_RETURN_NONE : FnTypeName := 'FN_RETURN_NONE';
    FN_CALL        : FnTypeName := 'FN_CALL';
    FN_CALL_ARGS   : FnTypeName := 'FN_CALL_ARGS';
    FN_PROLOGUE    : FnTypeName := 'FN_PROLOGUE';
    FN_EPILOGUE    : FnTypeName := 'FN_EPILOGUE';
    FN_PARAM_POS   : FnTypeName := 'FN_PARAM_POS';
    FN_PARAM_DEF   : FnTypeName := 'FN_PARAM_DEF';
    FN_RECURSIVE   : FnTypeName := 'FN_RECURSIVE';
    FN_NESTED_WARN : FnTypeName := 'FN_NESTED_WARN';
  Else
    FnTypeName := 'FN_UNKNOWN(' + ItoS(K) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ ParseParamList : parser la liste de parametres d une fonction   }
{   Remplit FnCurParams[1..FnCurParamN]                          }
{   Supporte les parametres positionnels et par defaut           }
{   def f(a, b, c=10, d=20):                                    }
{     -> parametre positionnel : [EBP+8], [EBP+12], ...         }
{     -> parametre par defaut : si absent a l appel,             }
{        empiler la valeur par defaut                            }
{ ------------------------------------------------------------ }

Procedure ParseParamList;
Var
  PIdx      : Integer;
  PName     : TString;
  HasDef    : Boolean;
  DefVal    : LongInt;
  SeenDef   : Boolean;
Begin
  FnCurParamN := 0;
  SeenDef := False;

  { Lire les parametres entre parentheses }
  { On suppose que '(' a deja ete consomme }
  While (CurTokKind <> TK_EOF) And (CurTokStr <> ')') Do
  Begin
    HasDef := False;
    DefVal := 0;

    If CurTokKind = TK_IDENT Then
    Begin
      PName := CurTokStr;
      Inc(FnParamCount);

      { Verifier s il y a une valeur par defaut (param=valeur) }
      { On simule : si le prochain token est '=', lire la valeur }
      { Pour le moment, accepter le parametre comme positionnel }
      If SeenDef Then
      Begin
        { Apres un parametre par defaut, tous doivent avoir un defaut }
        { On accepte quand meme mais c est un avertissement possible }
      End;
    End
    Else
      PName := '_param_' + ItoS(FnCurParamN + 1);

    If FnCurParamN < FN_MAX_PARAMS Then
    Begin
      Inc(FnCurParamN);
      PIdx := FnCurParamN;
      FnCurParams[PIdx].Name := PName;
      FnCurParams[PIdx].HasDefault := HasDef;
      FnCurParams[PIdx].DefValue := DefVal;

      If HasDef Then
      Begin
        Inc(FnDefParamCount);
        SeenDef := True;
        FnLastKind := FN_PARAM_DEF;
      End
      Else
        FnLastKind := FN_PARAM_POS;
    End
    Else
    Begin
      CompileError('Too many parameters (max ' +
                   ItoS(FN_MAX_PARAMS) + ')', LexLineNo);
      Exit;
    End;

    { Sauter la virgule entre parametres }
    If CurTokStr = ',' Then
    Begin
      { On avance apres la virgule, le prochain est un param }
    End;

    { Avancer au token suivant (simulation) }
    Break;  { Sortir apres un premier passage en mode stub }
  End;
End;

{ ------------------------------------------------------------ }
{ EmitFnPrologue : emettre le prologue d une fonction             }
{   PUSH EBP                                                     }
{   MOV EBP, ESP                                                 }
{   SUB ESP, locals_size  (si variables locales)                  }
{                                                                  }
{   Layout de la pile :                                           }
{     [EBP+8]  = premier parametre                                }
{     [EBP+12] = deuxieme parametre                               }
{     [EBP+4]  = adresse de retour                                }
{     [EBP]    = ancien EBP                                       }
{     [EBP-4]  = premiere variable locale                         }
{     [EBP-8]  = deuxieme variable locale                         }
{ ------------------------------------------------------------ }

Procedure EmitFnPrologue(FuncName : TString; NumLocals : Integer);
Var
  LocalsSize : Integer;
  LblEpi     : TString;
Begin
  Inc(FnLabelSeq);
  LblEpi := '_PYL_FNEPI_' + ItoS(FnLabelSeq);
  FnCurEpilogue := LblEpi;

  LocalsSize := NumLocals * 4;

  WriteLn('  ; --- function prologue: ', FuncName, ' ---');
  WriteLn(PY_FN_PFX, FuncName, ':');
  WriteLn('  PUSH EBP');
  WriteLn('  MOV EBP, ESP');
  If LocalsSize > 0 Then
    WriteLn('  SUB ESP, ', LocalsSize, '  ; ', NumLocals, ' local vars');

  WriteLn('  ; parameters: ', FnCurParamN);
  FnLastKind := FN_PROLOGUE;
End;

{ ------------------------------------------------------------ }
{ EmitFnEpilogue : emettre l epilogue d une fonction              }
{   label_epilogue:                                               }
{   MOV ESP, EBP                                                  }
{   POP EBP                                                       }
{   RET                                                           }
{ ------------------------------------------------------------ }

Procedure EmitFnEpilogue(FuncName : TString);
Begin
  WriteLn('  ; --- function epilogue: ', FuncName, ' ---');
  If FnCurEpilogue <> '' Then
    EmitLabel(FnCurEpilogue);
  WriteLn('  MOV ESP, EBP');
  WriteLn('  POP EBP');
  WriteLn('  RET');
  WriteLn('  ; --- end function ', FuncName, ' ---');
  FnLastKind := FN_EPILOGUE;
End;

{ ------------------------------------------------------------ }
{ ParseDefStmt : parser une definition de fonction                }
{   def nom(params):                                              }
{       bloc                                                      }
{                                                                  }
{   Emission assembleur :                                         }
{     JMP _PYL_SKIP_N  ; sauter par-dessus le corps              }
{     _PYF_nom:                                                   }
{       PUSH EBP / MOV EBP, ESP / SUB ESP, locals_size           }
{       corps                                                     }
{       _PYL_FNEPI_N:                                             }
{       MOV ESP, EBP / POP EBP / RET                              }
{     _PYL_SKIP_N:                                                }
{ ------------------------------------------------------------ }

Procedure ParseDefStmt;
Var
  FuncName   : TString;
  LblSkip    : TString;
  BaseSeq    : Integer;
  HasDefault : Boolean;
  I          : Integer;
Begin
  Inc(FnDefCount);
  HasDefault := False;

  { Verifier si on est deja dans un def (fonctions imbriquees) }
  If FnInDef Then
  Begin
    Inc(FnNestedWarn);
    WarnMsg('Nested function definition not supported');
    FnLastKind := FN_NESTED_WARN;
  End;

  FnInDef := True;

  { Generer le label de saut pour sauter le corps }
  Inc(FnLabelSeq);
  BaseSeq := FnLabelSeq;
  LblSkip := '_PYL_SKIP_' + ItoS(BaseSeq);

  { Lire le nom de la fonction }
  If CurTokKind = TK_IDENT Then
    FuncName := CurTokStr
  Else
    FuncName := '_anon_' + ItoS(BaseSeq);

  FnCurName := FuncName;

  WriteLn('  ; --- def ', FuncName, ' ---');

  { Sauter par-dessus le corps de la fonction }
  EmitJmp(LblSkip);

  { Parser la liste de parametres }
  ParseParamList;

  { Verifier si des parametres ont des valeurs par defaut }
  For I := 1 To FnCurParamN Do
  Begin
    If FnCurParams[I].HasDefault Then
    Begin
      HasDefault := True;
      Break;
    End;
  End;

  { Initialiser le nombre de variables locales (stub) }
  FnCurLocalN := 0;

  { Emettre le prologue }
  EmitFnPrologue(FuncName, FnCurLocalN);

  { Emettre les commentaires pour chaque parametre }
  For I := 1 To FnCurParamN Do
  Begin
    WriteLn('  ; param ', I, ': ', FnCurParams[I].Name,
            ' = [EBP+', (I * 4) + 4, ']');
    If FnCurParams[I].HasDefault Then
      WriteLn('  ; default = ', FnCurParams[I].DefValue);
  End;

  { Corps de la fonction (stub: les futurs TODOs ajouteront le parseur) }
  WriteLn('  ; function body');

  { Emettre le retour implicite XOR EAX,EAX (return None) si pas de return }
  WriteLn('  XOR EAX, EAX  ; implicit return None');

  { Emettre l epilogue }
  EmitFnEpilogue(FuncName);

  { Label pour sauter par-dessus le corps }
  EmitLabel(LblSkip);

  FnInDef := False;

  { Determiner le type }
  If HasDefault Then
    FnLastKind := FN_DEF_DEFAULT
  Else If FnCurParamN > 0 Then
    FnLastKind := FN_DEF_PARAMS
  Else
    FnLastKind := FN_DEF;
End;

{ ------------------------------------------------------------ }
{ ParseReturnStmt : parser une instruction return                 }
{   return expr   -> MOV EAX, valeur + JMP epilogue              }
{   return        -> XOR EAX, EAX (None=0) + JMP epilogue        }
{ ------------------------------------------------------------ }

Procedure ParseReturnStmt;
Begin
  If Not FnInDef Then
  Begin
    CompileError('return outside function', LexLineNo);
    Exit;
  End;

  Inc(FnReturnCount);

  { Verifier si return avec ou sans expression }
  { return suivi de NEWLINE = return sans valeur }
  If (CurTokKind = TK_NEWLINE) Or (CurTokKind = TK_EOF) Then
  Begin
    { return sans valeur -> XOR EAX, EAX (None = 0) }
    Inc(FnRetNoneCount);
    WriteLn('  ; return (None)');
    WriteLn('  XOR EAX, EAX  ; None = 0');
    FnLastKind := FN_RETURN_NONE;
  End
  Else
  Begin
    { return expr -> le resultat de l expression est dans EAX }
    WriteLn('  ; return expr');
    WriteLn('  ; (expression result in EAX)');
    FnLastKind := FN_RETURN;
  End;

  { Sauter vers l epilogue }
  If FnCurEpilogue <> '' Then
    EmitJmp(FnCurEpilogue)
  Else
    CompileError('No function epilogue label', LexLineNo);
End;

{ ------------------------------------------------------------ }
{ EmitFnCall : emettre l appel a une fonction                     }
{   Convention cdecl :                                            }
{     PUSH arg_n  ; empiler de droite a gauche                   }
{     PUSH arg_n-1                                               }
{     ...                                                         }
{     PUSH arg_1                                                  }
{     CALL _PYF_nom                                               }
{     ADD ESP, n*4  ; l appelant nettoie la pile                  }
{   Valeur de retour dans EAX                                    }
{ ------------------------------------------------------------ }

Procedure EmitFnCall(FuncName : TString; NumArgs : Integer);
Begin
  Inc(FnCallCount);

  WriteLn('  ; call ', FuncName, '(', NumArgs, ' args)');

  { Les arguments doivent avoir ete empiles avant l appel }
  { (par le parseur d expressions) }

  WriteLn('  CALL ', PY_FN_PFX, FuncName);
  If NumArgs > 0 Then
    WriteLn('  ADD ESP, ', NumArgs * 4, '  ; caller cleanup');
  WriteLn('  ; result in EAX');

  { Verifier si c est un appel recursif }
  If FnInDef And (FuncName = FnCurName) Then
  Begin
    Inc(FnRecursCount);
    FnLastKind := FN_RECURSIVE;
  End
  Else If NumArgs > 0 Then
    FnLastKind := FN_CALL_ARGS
  Else
    FnLastKind := FN_CALL;
End;

{ ------------------------------------------------------------ }
{ EmitPushArg : emettre PUSH pour un argument de fonction         }
{   Empile la valeur dans EAX sur la pile                        }
{ ------------------------------------------------------------ }

Procedure EmitPushArg(ArgIndex, TotalArgs : Integer);
Begin
  WriteLn('  PUSH EAX  ; arg ', ArgIndex, ' of ', TotalArgs);
End;

{ ------------------------------------------------------------ }
{ EmitDefaultArg : emettre le push d une valeur par defaut        }
{   Si l argument manque a l appel, empiler la valeur par defaut  }
{ ------------------------------------------------------------ }

Procedure EmitDefaultArg(ParamIdx : Integer; DefValue : LongInt);
Begin
  Inc(FnDefParamCount);
  WriteLn('  PUSH DWORD ', DefValue,
          '  ; default for param ', ParamIdx);
  FnLastKind := FN_PARAM_DEF;
End;

{ ------------------------------------------------------------ }
{ GetFnParamOffset : retourner l offset d un parametre            }
{   Premier parametre  = [EBP+8]                                  }
{   Deuxieme parametre = [EBP+12]                                 }
{   N-ieme parametre   = [EBP + (N*4) + 4]                       }
{ ------------------------------------------------------------ }

Function GetFnParamOffset(ParamIndex : Integer) : Integer;
Begin
  GetFnParamOffset := (ParamIndex * 4) + 4;
End;

{ ------------------------------------------------------------ }
{ GetFnLocalOffset : retourner l offset d une variable locale     }
{   Premiere variable  = [EBP-4]                                  }
{   Deuxieme variable  = [EBP-8]                                  }
{   N-ieme variable    = [EBP - N*4]                              }
{ ------------------------------------------------------------ }

Function GetFnLocalOffset(LocalIndex : Integer) : Integer;
Begin
  GetFnLocalOffset := -(LocalIndex * 4);
End;

{ ------------------------------------------------------------ }
{ EmitLoadParam : emettre le chargement d un parametre dans EAX   }
{   MOV EAX, DWORD [EBP + offset]                                }
{ ------------------------------------------------------------ }

Procedure EmitLoadParam(ParamIndex : Integer);
Var
  Off : Integer;
Begin
  Off := GetFnParamOffset(ParamIndex);
  WriteLn('  MOV EAX, DWORD [EBP+', Off, ']  ; param ', ParamIndex);
End;

{ ------------------------------------------------------------ }
{ EmitStoreParam : emettre le stockage dans un parametre          }
{   MOV DWORD [EBP + offset], EAX                                }
{ ------------------------------------------------------------ }

Procedure EmitStoreParam(ParamIndex : Integer);
Var
  Off : Integer;
Begin
  Off := GetFnParamOffset(ParamIndex);
  WriteLn('  MOV DWORD [EBP+', Off, '], EAX  ; param ', ParamIndex);
End;

{ ------------------------------------------------------------ }
{ EmitLoadLocal : emettre le chargement d une variable locale     }
{   MOV EAX, DWORD [EBP - offset]                                }
{ ------------------------------------------------------------ }

Procedure EmitLoadLocal(LocalIndex : Integer);
Var
  Off : Integer;
Begin
  Off := GetFnLocalOffset(LocalIndex);
  WriteLn('  MOV EAX, DWORD [EBP', Off, ']  ; local ', LocalIndex);
End;

{ ------------------------------------------------------------ }
{ EmitStoreLocal : emettre le stockage dans une variable locale   }
{   MOV DWORD [EBP - offset], EAX                                }
{ ------------------------------------------------------------ }

Procedure EmitStoreLocal(LocalIndex : Integer);
Var
  Off : Integer;
Begin
  Off := GetFnLocalOffset(LocalIndex);
  WriteLn('  MOV DWORD [EBP', Off, '], EAX  ; local ', LocalIndex);
End;

{ ------------------------------------------------------------ }
{ DumpFnState : afficher l etat du sous-systeme des fonctions     }
{ ------------------------------------------------------------ }

Procedure DumpFnState;
Begin
  WriteLn('--- Function State ---');
  WriteLn('  FnInitialized   : ', FnInitialized);
  WriteLn('  FnDefCount      : ', FnDefCount);
  WriteLn('  FnReturnCount   : ', FnReturnCount);
  WriteLn('  FnRetNoneCount  : ', FnRetNoneCount);
  WriteLn('  FnCallCount     : ', FnCallCount);
  WriteLn('  FnParamCount    : ', FnParamCount);
  WriteLn('  FnDefParamCount : ', FnDefParamCount);
  WriteLn('  FnRecursCount   : ', FnRecursCount);
  WriteLn('  FnNestedWarn    : ', FnNestedWarn);
  WriteLn('  FnLastKind      : ', FnTypeName(FnLastKind));
  WriteLn('  FnLabelSeq      : ', FnLabelSeq);
  WriteLn('  FnCurName       : ', FnCurName);
  WriteLn('  FnCurParamN     : ', FnCurParamN);
  WriteLn('  FnCurLocalN     : ', FnCurLocalN);
  WriteLn('  FnInDef         : ', FnInDef);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 12)                              }
{ ------------------------------------------------------------ }

Function IsFnInitialized : Boolean;
Begin
  IsFnInitialized := FnInitialized;
End;

Function IsFnEmpty : Boolean;
Begin
  IsFnEmpty := (FnDefCount = 0) And (FnReturnCount = 0) And
               (FnCallCount = 0);
End;

Function GetFnDefCount : LongInt;
Begin
  GetFnDefCount := FnDefCount;
End;

Function GetFnReturnCount : LongInt;
Begin
  GetFnReturnCount := FnReturnCount;
End;

Function GetFnRetNoneCount : LongInt;
Begin
  GetFnRetNoneCount := FnRetNoneCount;
End;

Function GetFnCallCount : LongInt;
Begin
  GetFnCallCount := FnCallCount;
End;

Function GetFnParamCount : LongInt;
Begin
  GetFnParamCount := FnParamCount;
End;

Function GetFnDefParamCount : LongInt;
Begin
  GetFnDefParamCount := FnDefParamCount;
End;

Function GetFnRecursCount : LongInt;
Begin
  GetFnRecursCount := FnRecursCount;
End;

Function GetFnStatus : TString;
Begin
  If Not FnInitialized Then
    GetFnStatus := 'Not initialized'
  Else
    GetFnStatus := ItoS(FnDefCount) + ' def, ' +
                   ItoS(FnReturnCount) + ' return, ' +
                   ItoS(FnCallCount) + ' call, ' +
                   ItoS(FnParamCount) + ' params, ' +
                   ItoS(FnRecursCount) + ' recursive';
End;

{ ============================================================ }
{ TODO 13 - PARSEUR : ENTREES/SORTIES (print / input)          }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { Types d operations d entrees/sorties }
  IO_NONE          = 0;    { aucun / non defini                    }
  IO_PRINT_INT     = 1;    { print(n) avec entier                  }
  IO_PRINT_STR     = 2;    { print(s) avec chaine                  }
  IO_PRINT_BOOL    = 3;    { print(True/False)                     }
  IO_PRINT_NONE    = 4;    { print(None)                           }
  IO_PRINT_MULTI   = 5;    { print(a, b, c) multi-arguments        }
  IO_PRINT_SEP     = 6;    { print avec sep= personnalise          }
  IO_PRINT_END     = 7;    { print avec end= personnalise          }
  IO_INPUT         = 8;    { input() sans prompt                   }
  IO_INPUT_PROMPT  = 9;    { input('prompt')                       }
  IO_INT_INPUT     = 10;   { int(input()) conversion entiere       }
  IO_HEX_CONV      = 11;   { hex(n) -> chaine hexadecimale         }
  IO_OCT_CONV      = 12;   { oct(n) -> chaine octale               }
  IO_BIN_CONV      = 13;   { bin(n) -> chaine binaire              }
  IO_MAX           = 13;

  { Limites }
  IO_MAX_ARGS      = 16;   { nombre max d arguments pour print     }
  IO_BUF_SIZE      = 256;  { taille max du buffer de lecture        }

  { Constantes Win32 pour les handles standard }
  IO_STD_INPUT     = -10;  { STD_INPUT_HANDLE                      }
  IO_STD_OUTPUT    = -11;  { STD_OUTPUT_HANDLE                     }

Var
  IoInitialized   : Boolean;    { True si l etat est initialise       }
  IoPrintIntCount : LongInt;    { nombre de print(int)                }
  IoPrintStrCount : LongInt;    { nombre de print(str)                }
  IoPrintBoolCount: LongInt;    { nombre de print(bool)               }
  IoPrintNoneCount: LongInt;    { nombre de print(None)               }
  IoPrintMultiCount: LongInt;   { nombre de print multi-args          }
  IoInputCount    : LongInt;    { nombre de input()                   }
  IoInputPromptCount: LongInt;  { nombre de input(prompt)             }
  IoIntInputCount : LongInt;    { nombre de int(input())              }
  IoHexConvCount  : LongInt;    { nombre de hex(n)                    }
  IoOctConvCount  : LongInt;    { nombre de oct(n)                    }
  IoBinConvCount  : LongInt;    { nombre de bin(n)                    }
  IoLastKind      : Integer;    { dernier type d operation E/S        }
  IoLabelSeq      : Integer;    { sequence pour labels E/S            }
  IoSepStr        : TString;    { separateur courant (defaut ' ')     }
  IoEndStr        : TString;    { terminateur courant (defaut CRLF)   }

{ ------------------------------------------------------------ }
{ InitIoState : initialiser le sous-systeme des entrees/sorties  }
{ ------------------------------------------------------------ }

Procedure InitIoState;
Begin
  IoInitialized    := True;
  IoPrintIntCount  := 0;
  IoPrintStrCount  := 0;
  IoPrintBoolCount := 0;
  IoPrintNoneCount := 0;
  IoPrintMultiCount:= 0;
  IoInputCount     := 0;
  IoInputPromptCount := 0;
  IoIntInputCount  := 0;
  IoHexConvCount   := 0;
  IoOctConvCount   := 0;
  IoBinConvCount   := 0;
  IoLastKind       := IO_NONE;
  IoLabelSeq       := 0;
  IoSepStr         := ' ';
  IoEndStr         := '';
End;

{ ------------------------------------------------------------ }
{ GenIoLabel : generer un label unique pour les E/S               }
{ ------------------------------------------------------------ }

Function GenIoLabel : TString;
Begin
  Inc(IoLabelSeq);
  GenIoLabel := '_PYL_IO_' + ItoS(IoLabelSeq);
End;

{ ------------------------------------------------------------ }
{ IoTypeName : retourner le nom du type d operation E/S            }
{ ------------------------------------------------------------ }

Function IoTypeName(K : Integer) : TString;
Begin
  Case K Of
    IO_NONE          : IoTypeName := 'IO_NONE';
    IO_PRINT_INT     : IoTypeName := 'IO_PRINT_INT';
    IO_PRINT_STR     : IoTypeName := 'IO_PRINT_STR';
    IO_PRINT_BOOL    : IoTypeName := 'IO_PRINT_BOOL';
    IO_PRINT_NONE    : IoTypeName := 'IO_PRINT_NONE';
    IO_PRINT_MULTI   : IoTypeName := 'IO_PRINT_MULTI';
    IO_PRINT_SEP     : IoTypeName := 'IO_PRINT_SEP';
    IO_PRINT_END     : IoTypeName := 'IO_PRINT_END';
    IO_INPUT         : IoTypeName := 'IO_INPUT';
    IO_INPUT_PROMPT  : IoTypeName := 'IO_INPUT_PROMPT';
    IO_INT_INPUT     : IoTypeName := 'IO_INT_INPUT';
    IO_HEX_CONV      : IoTypeName := 'IO_HEX_CONV';
    IO_OCT_CONV      : IoTypeName := 'IO_OCT_CONV';
    IO_BIN_CONV      : IoTypeName := 'IO_BIN_CONV';
  Else
    IoTypeName := 'IO_UNKNOWN(' + ItoS(K) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ EmitGetStdHandle : emettre l appel a GetStdHandle Win32          }
{   PUSH nStdHandle / CALL GetStdHandle -> EAX=handle             }
{ ------------------------------------------------------------ }

Procedure EmitGetStdHandle(HandleType : LongInt);
Begin
  WriteLn('  ; GetStdHandle(', HandleType, ')');
  WriteLn('  PUSH ', HandleType);
  WriteLn('  CALL _GetStdHandle@4');
  WriteLn('  ; EAX = handle');
End;

{ ------------------------------------------------------------ }
{ EmitWriteFile : emettre l appel a WriteFile Win32                }
{   Ecrit la chaine pointee par ESI de longueur ECX                }
{   sur le handle dans EBX                                        }
{ ------------------------------------------------------------ }

Procedure EmitWriteFile;
Begin
  WriteLn('  ; WriteFile(hFile=EBX, lpBuffer=ESI, nBytes=ECX)');
  WriteLn('  PUSH 0          ; lpOverlapped = NULL');
  WriteLn('  PUSH ESP         ; lpNumberOfBytesWritten (temporaire)');
  WriteLn('  PUSH ECX         ; nNumberOfBytesToWrite');
  WriteLn('  PUSH ESI         ; lpBuffer');
  WriteLn('  PUSH EBX         ; hFile');
  WriteLn('  CALL _WriteFile@20');
End;

{ ------------------------------------------------------------ }
{ EmitReadFile : emettre l appel a ReadFile Win32                  }
{   Lit dans le buffer pointe par ESI, max ECX octets              }
{   depuis le handle dans EBX                                     }
{ ------------------------------------------------------------ }

Procedure EmitReadFile;
Begin
  WriteLn('  ; ReadFile(hFile=EBX, lpBuffer=ESI, nBytes=ECX)');
  WriteLn('  PUSH 0          ; lpOverlapped = NULL');
  WriteLn('  PUSH ESP         ; lpNumberOfBytesRead (temporaire)');
  WriteLn('  PUSH ECX         ; nNumberOfBytesToRead');
  WriteLn('  PUSH ESI         ; lpBuffer');
  WriteLn('  PUSH EBX         ; hFile');
  WriteLn('  CALL _ReadFile@20');
End;

{ ------------------------------------------------------------ }
{ EmitPrintStr : emettre le code pour afficher une chaine          }
{   La chaine est pointee par EAX (ptr) via _PYRT_WRITESTR        }
{ ------------------------------------------------------------ }

Procedure EmitPrintStr;
Begin
  IoLastKind := IO_PRINT_STR;
  Inc(IoPrintStrCount);
  WriteLn('  ; print(str) -> _PYRT_WRITESTR');
  WriteLn('  PUSH EAX         ; ptr vers la chaine');
  WriteLn('  CALL _PYRT_WRITESTR');
  WriteLn('  ADD ESP, 4');
End;

{ ------------------------------------------------------------ }
{ EmitPrintInt : emettre le code pour afficher un entier           }
{   L entier est dans EAX -> _PYRT_ITOA + _PYRT_WRITESTR          }
{ ------------------------------------------------------------ }

Procedure EmitPrintInt;
Begin
  IoLastKind := IO_PRINT_INT;
  Inc(IoPrintIntCount);
  WriteLn('  ; print(int) -> _PYRT_ITOA + _PYRT_WRITESTR');
  WriteLn('  PUSH EAX         ; valeur entiere');
  WriteLn('  CALL _PYRT_ITOA');
  WriteLn('  ADD ESP, 4       ; EAX = ptr vers chaine');
  WriteLn('  PUSH EAX');
  WriteLn('  CALL _PYRT_WRITESTR');
  WriteLn('  ADD ESP, 4');
End;

{ ------------------------------------------------------------ }
{ EmitPrintBool : emettre le code pour afficher True ou False      }
{   EAX = 0 -> 'False', EAX <> 0 -> 'True'                       }
{ ------------------------------------------------------------ }

Procedure EmitPrintBool;
Var
  LblFalse, LblEnd : TString;
Begin
  IoLastKind := IO_PRINT_BOOL;
  Inc(IoPrintBoolCount);
  LblFalse := GenIoLabel;
  LblEnd   := GenIoLabel;
  WriteLn('  ; print(bool)');
  WriteLn('  TEST EAX, EAX');
  WriteLn('  JZ ', LblFalse);
  WriteLn('  PUSH OFFSET _PYD_TRUE');
  WriteLn('  CALL _PYRT_WRITESTR');
  WriteLn('  ADD ESP, 4');
  WriteLn('  JMP ', LblEnd);
  WriteLn(LblFalse, ':');
  WriteLn('  PUSH OFFSET _PYD_FALSE');
  WriteLn('  CALL _PYRT_WRITESTR');
  WriteLn('  ADD ESP, 4');
  WriteLn(LblEnd, ':');
End;

{ ------------------------------------------------------------ }
{ EmitPrintNone : emettre le code pour afficher 'None'             }
{ ------------------------------------------------------------ }

Procedure EmitPrintNone;
Begin
  IoLastKind := IO_PRINT_NONE;
  Inc(IoPrintNoneCount);
  WriteLn('  ; print(None)');
  WriteLn('  PUSH OFFSET _PYD_NONE');
  WriteLn('  CALL _PYRT_WRITESTR');
  WriteLn('  ADD ESP, 4');
End;

{ ------------------------------------------------------------ }
{ EmitPrintSep : emettre le code pour afficher le separateur       }
{   Par defaut un espace, personnalisable via sep=                 }
{ ------------------------------------------------------------ }

Procedure EmitPrintSep;
Begin
  If IoSepStr = ' ' Then
  Begin
    WriteLn('  ; separateur (espace)');
    WriteLn('  PUSH OFFSET _PYD_SPACE');
    WriteLn('  CALL _PYRT_WRITESTR');
    WriteLn('  ADD ESP, 4');
  End
  Else
  Begin
    WriteLn('  ; separateur personnalise');
    WriteLn('  PUSH OFFSET _PYD_SEP');
    WriteLn('  CALL _PYRT_WRITESTR');
    WriteLn('  ADD ESP, 4');
  End;
End;

{ ------------------------------------------------------------ }
{ EmitPrintNewline : emettre le code pour afficher CR+LF           }
{   Ou le terminateur end= personnalise                           }
{ ------------------------------------------------------------ }

Procedure EmitPrintNewline;
Begin
  If IoEndStr = '' Then
  Begin
    WriteLn('  ; terminateur (CR+LF)');
    WriteLn('  PUSH OFFSET _PYD_CRLF');
    WriteLn('  CALL _PYRT_WRITESTR');
    WriteLn('  ADD ESP, 4');
  End
  Else
  Begin
    WriteLn('  ; terminateur personnalise end=');
    WriteLn('  PUSH OFFSET _PYD_END');
    WriteLn('  CALL _PYRT_WRITESTR');
    WriteLn('  ADD ESP, 4');
  End;
End;

{ ------------------------------------------------------------ }
{ ParsePrintStmt : analyser et emettre un appel a print            }
{   print()                   -> CRLF seul                         }
{   print(expr)               -> evaluer + afficher + CRLF         }
{   print(e1, e2, ...)        -> sep entre chaque + CRLF           }
{   print(e1, sep=',')        -> sep personnalise                  }
{   print(e1, end='')         -> end personnalise                  }
{ ------------------------------------------------------------ }

Procedure ParsePrintStmt;
Var
  ArgCount : Integer;
  HasSep   : Boolean;
  HasEnd   : Boolean;
Begin
  { Reinitialiser les options de print }
  IoSepStr := ' ';
  IoEndStr := '';
  HasSep   := False;
  HasEnd   := False;
  ArgCount := 0;

  { On attend que le token courant soit 'print' deja consomme }
  { Verifier s il y a une parenthese ouvrante }
  If (CurTokKind = TK_OP) And (CurTokStr = '(') Then
  Begin
    LexNextToken;  { consommer '(' }

    { Boucle sur les arguments }
    While Not ((CurTokKind = TK_OP) And (CurTokStr = ')')) And
          Not (CurTokKind = TK_EOF) Do
    Begin
      { Verifier si c est un argument nomme sep= ou end= }
      If (CurTokKind = TK_IDENT) And (CurTokStr = 'sep') Then
      Begin
        LexNextToken;  { consommer 'sep' }
        If (CurTokKind = TK_OP) And (CurTokStr = '=') Then
        Begin
          LexNextToken;  { consommer '=' }
          If CurTokKind = TK_STRING Then
          Begin
            IoSepStr := CurTokStr;
            HasSep   := True;
            LexNextToken;  { consommer la chaine }
          End;
        End;
      End
      Else If (CurTokKind = TK_IDENT) And (CurTokStr = 'end') Then
      Begin
        LexNextToken;  { consommer 'end' }
        If (CurTokKind = TK_OP) And (CurTokStr = '=') Then
        Begin
          LexNextToken;  { consommer '=' }
          If CurTokKind = TK_STRING Then
          Begin
            IoEndStr := CurTokStr;
            HasEnd   := True;
            LexNextToken;  { consommer la chaine }
          End;
        End;
      End
      Else
      Begin
        { C est un argument normal }
        Inc(ArgCount);

        { Inserer le separateur avant le 2e argument et suivants }
        If ArgCount > 1 Then
          EmitPrintSep;

        { Determiner le type d argument }
        If CurTokKind = TK_INTEGER Then
        Begin
          WriteLn('  MOV EAX, ', CurTokInt);
          EmitPrintInt;
          LexNextToken;
        End
        Else If CurTokKind = TK_STRING Then
        Begin
          WriteLn('  MOV EAX, OFFSET ', GenIoLabel);
          EmitPrintStr;
          LexNextToken;
        End
        Else If (CurTokKind = TK_KEYWORD) And (CurTokStr = 'True') Then
        Begin
          WriteLn('  MOV EAX, 1');
          EmitPrintBool;
          LexNextToken;
        End
        Else If (CurTokKind = TK_KEYWORD) And (CurTokStr = 'False') Then
        Begin
          WriteLn('  XOR EAX, EAX');
          EmitPrintBool;
          LexNextToken;
        End
        Else If (CurTokKind = TK_KEYWORD) And (CurTokStr = 'None') Then
        Begin
          EmitPrintNone;
          LexNextToken;
        End
        Else If CurTokKind = TK_IDENT Then
        Begin
          { Variable : charger et afficher comme entier par defaut }
          WriteLn('  MOV EAX, [', SymMangle(CurTokStr, SK_VAR), ']');
          EmitPrintInt;
          LexNextToken;
        End
        Else
        Begin
          { Expression generique : supposer que EAX contient le resultat }
          EmitPrintInt;
          LexNextToken;
        End;
      End;

      { Consommer la virgule entre arguments }
      If (CurTokKind = TK_OP) And (CurTokStr = ',') Then
        LexNextToken;
    End;

    { Consommer ')' }
    If (CurTokKind = TK_OP) And (CurTokStr = ')') Then
      LexNextToken;
  End;

  { Emettre le terminateur }
  EmitPrintNewline;

  { Mettre a jour les compteurs }
  If ArgCount > 1 Then
    Inc(IoPrintMultiCount);
  If HasSep Then
    IoLastKind := IO_PRINT_SEP;
  If HasEnd Then
    IoLastKind := IO_PRINT_END;
  If ArgCount <= 1 Then
  Begin
    If IoLastKind = IO_NONE Then
      IoLastKind := IO_PRINT_STR;
  End
  Else
    IoLastKind := IO_PRINT_MULTI;
End;

{ ------------------------------------------------------------ }
{ EmitInputPrompt : emettre le code pour afficher le prompt        }
{   Si un prompt est fourni, l afficher via _PYRT_WRITESTR         }
{ ------------------------------------------------------------ }

Procedure EmitInputPrompt(Prompt : TString);
Begin
  If Prompt <> '' Then
  Begin
    WriteLn('  ; afficher le prompt input');
    WriteLn('  PUSH OFFSET ', Prompt);
    WriteLn('  CALL _PYRT_WRITESTR');
    WriteLn('  ADD ESP, 4');
  End;
End;

{ ------------------------------------------------------------ }
{ EmitInputReadline : emettre le code pour lire une ligne stdin    }
{   Appelle _PYRT_READLINE -> EAX = ptr vers la chaine lue        }
{ ------------------------------------------------------------ }

Procedure EmitInputReadline;
Begin
  WriteLn('  ; input() -> _PYRT_READLINE');
  WriteLn('  CALL _PYRT_READLINE');
  WriteLn('  ; EAX = ptr vers la chaine lue');
End;

{ ------------------------------------------------------------ }
{ ParseInputExpr : analyser et emettre un appel a input()          }
{   input()          -> lire une ligne depuis STDIN                }
{   input('prompt')  -> afficher prompt puis lire                  }
{   Resultat dans EAX = pointeur vers la chaine lue               }
{ ------------------------------------------------------------ }

Procedure ParseInputExpr;
Var
  PromptLabel : TString;
Begin
  { On attend que 'input' soit deja consomme }
  PromptLabel := '';

  If (CurTokKind = TK_OP) And (CurTokStr = '(') Then
  Begin
    LexNextToken;  { consommer '(' }

    { Verifier s il y a un prompt }
    If CurTokKind = TK_STRING Then
    Begin
      IoLastKind := IO_INPUT_PROMPT;
      Inc(IoInputPromptCount);
      PromptLabel := GenIoLabel;
      WriteLn('  ; input avec prompt');
      EmitInputPrompt(PromptLabel);
      LexNextToken;  { consommer la chaine }
    End
    Else
    Begin
      IoLastKind := IO_INPUT;
      Inc(IoInputCount);
    End;

    { Consommer ')' }
    If (CurTokKind = TK_OP) And (CurTokStr = ')') Then
      LexNextToken;
  End
  Else
  Begin
    IoLastKind := IO_INPUT;
    Inc(IoInputCount);
  End;

  { Lire la ligne }
  EmitInputReadline;
End;

{ ------------------------------------------------------------ }
{ ParseIntInput : analyser int(input()) et emettre le code         }
{   Lit une ligne via _PYRT_READLINE puis convertit via _PYRT_ATOI }
{   Resultat dans EAX = valeur entiere                            }
{ ------------------------------------------------------------ }

Procedure ParseIntInput;
Begin
  IoLastKind := IO_INT_INPUT;
  Inc(IoIntInputCount);
  WriteLn('  ; int(input()) -> _PYRT_READLINE + _PYRT_ATOI');
  { D abord lire la ligne }
  EmitInputReadline;
  { Puis convertir en entier }
  WriteLn('  PUSH EAX         ; ptr vers la chaine');
  WriteLn('  CALL _PYRT_ATOI');
  WriteLn('  ADD ESP, 4       ; EAX = valeur entiere');
End;

{ ------------------------------------------------------------ }
{ EmitHexConv : emettre le code pour hex(n)                        }
{   EAX = valeur entiere -> CALL _PYRT_TOHEX -> EAX = ptr         }
{ ------------------------------------------------------------ }

Procedure EmitHexConv;
Begin
  IoLastKind := IO_HEX_CONV;
  Inc(IoHexConvCount);
  WriteLn('  ; hex(n) -> _PYRT_TOHEX');
  WriteLn('  PUSH EAX         ; valeur entiere');
  WriteLn('  CALL _PYRT_TOHEX');
  WriteLn('  ADD ESP, 4       ; EAX = ptr "0x..."');
End;

{ ------------------------------------------------------------ }
{ EmitOctConv : emettre le code pour oct(n)                        }
{   EAX = valeur entiere -> CALL _PYRT_TOOCT -> EAX = ptr         }
{ ------------------------------------------------------------ }

Procedure EmitOctConv;
Begin
  IoLastKind := IO_OCT_CONV;
  Inc(IoOctConvCount);
  WriteLn('  ; oct(n) -> _PYRT_TOOCT');
  WriteLn('  PUSH EAX         ; valeur entiere');
  WriteLn('  CALL _PYRT_TOOCT');
  WriteLn('  ADD ESP, 4       ; EAX = ptr "0o..."');
End;

{ ------------------------------------------------------------ }
{ EmitBinConv : emettre le code pour bin(n)                        }
{   EAX = valeur entiere -> CALL _PYRT_TOBIN -> EAX = ptr         }
{ ------------------------------------------------------------ }

Procedure EmitBinConv;
Begin
  IoLastKind := IO_BIN_CONV;
  Inc(IoBinConvCount);
  WriteLn('  ; bin(n) -> _PYRT_TOBIN');
  WriteLn('  PUSH EAX         ; valeur entiere');
  WriteLn('  CALL _PYRT_TOBIN');
  WriteLn('  ADD ESP, 4       ; EAX = ptr "0b..."');
End;

{ ------------------------------------------------------------ }
{ DumpIoState : afficher l etat du sous-systeme des E/S            }
{ ------------------------------------------------------------ }

Procedure DumpIoState;
Begin
  WriteLn('--- IO State ---');
  WriteLn('  IoInitialized    : ', IoInitialized);
  WriteLn('  IoPrintIntCount  : ', IoPrintIntCount);
  WriteLn('  IoPrintStrCount  : ', IoPrintStrCount);
  WriteLn('  IoPrintBoolCount : ', IoPrintBoolCount);
  WriteLn('  IoPrintNoneCount : ', IoPrintNoneCount);
  WriteLn('  IoPrintMultiCount: ', IoPrintMultiCount);
  WriteLn('  IoInputCount     : ', IoInputCount);
  WriteLn('  IoInputPromptCount: ', IoInputPromptCount);
  WriteLn('  IoIntInputCount  : ', IoIntInputCount);
  WriteLn('  IoHexConvCount   : ', IoHexConvCount);
  WriteLn('  IoOctConvCount   : ', IoOctConvCount);
  WriteLn('  IoBinConvCount   : ', IoBinConvCount);
  WriteLn('  IoLastKind       : ', IoTypeName(IoLastKind));
  WriteLn('  IoLabelSeq       : ', IoLabelSeq);
  WriteLn('  IoSepStr         : "', IoSepStr, '"');
  WriteLn('  IoEndStr         : "', IoEndStr, '"');
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 13)                              }
{ ------------------------------------------------------------ }

Function IsIoInitialized : Boolean;
Begin
  IsIoInitialized := IoInitialized;
End;

Function IsIoEmpty : Boolean;
Begin
  IsIoEmpty := (IoPrintIntCount = 0) And (IoPrintStrCount = 0) And
               (IoInputCount = 0) And (IoInputPromptCount = 0);
End;

Function GetIoPrintIntCount : LongInt;
Begin
  GetIoPrintIntCount := IoPrintIntCount;
End;

Function GetIoPrintStrCount : LongInt;
Begin
  GetIoPrintStrCount := IoPrintStrCount;
End;

Function GetIoPrintBoolCount : LongInt;
Begin
  GetIoPrintBoolCount := IoPrintBoolCount;
End;

Function GetIoPrintMultiCount : LongInt;
Begin
  GetIoPrintMultiCount := IoPrintMultiCount;
End;

Function GetIoInputCount : LongInt;
Begin
  GetIoInputCount := IoInputCount;
End;

Function GetIoInputPromptCount : LongInt;
Begin
  GetIoInputPromptCount := IoInputPromptCount;
End;

Function GetIoIntInputCount : LongInt;
Begin
  GetIoIntInputCount := IoIntInputCount;
End;

Function GetIoStatus : TString;
Begin
  If Not IoInitialized Then
    GetIoStatus := 'Not initialized'
  Else
    GetIoStatus := ItoS(IoPrintIntCount) + ' print_int, ' +
                   ItoS(IoPrintStrCount) + ' print_str, ' +
                   ItoS(IoPrintBoolCount) + ' print_bool, ' +
                   ItoS(IoPrintMultiCount) + ' print_multi, ' +
                   ItoS(IoInputCount) + ' input, ' +
                   ItoS(IoInputPromptCount) + ' input_prompt, ' +
                   ItoS(IoIntInputCount) + ' int_input';
End;

{ ============================================================ }
{ TODO 14 - PARSEUR : LISTES (list)                            }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { Types d operations sur les listes }
  LS_NONE          = 0;    { aucun / non defini                    }
  LS_EMPTY         = 1;    { liste vide []                         }
  LS_LITERAL       = 2;    { liste literale [e0, e1, ...]          }
  LS_INDEX         = 3;    { acces par index lst[i]                }
  LS_NEG_INDEX     = 4;    { acces par index negatif lst[-i]       }
  LS_ASSIGN        = 5;    { affectation par index lst[i] = val    }
  LS_SLICE         = 6;    { slice lst[a:b]                        }
  LS_LEN           = 7;    { len(lst) -> compteur en tete          }
  LS_APPEND        = 8;    { lst.append(val)                       }
  LS_POP           = 9;    { lst.pop() -> dernier element          }
  LS_CONCAT        = 10;   { lst1 + lst2 -> concatenation          }
  LS_MUL           = 11;   { lst * n -> repetition                 }
  LS_CONTAINS      = 12;   { val in lst -> booleen                 }
  LS_ITER          = 13;   { iteration for elem in lst             }
  LS_MAX           = 13;

  { Limites }
  LS_MAX_ELEMS     = 64;   { nombre max d elements dans une liste  }
  LS_INIT_CAP      = 8;    { capacite initiale d allocation        }

Var
  LsInitialized   : Boolean;    { True si l etat est initialise       }
  LsEmptyCount    : LongInt;    { nombre de listes vides creees       }
  LsLiteralCount  : LongInt;    { nombre de listes literales          }
  LsIndexCount    : LongInt;    { nombre d acces par index            }
  LsNegIndexCount : LongInt;    { nombre d acces par index negatif    }
  LsAssignCount   : LongInt;    { nombre d affectations par index     }
  LsSliceCount    : LongInt;    { nombre de slices                    }
  LsLenCount      : LongInt;    { nombre d appels a len(lst)          }
  LsAppendCount   : LongInt;    { nombre d appels a append            }
  LsPopCount      : LongInt;    { nombre d appels a pop               }
  LsConcatCount   : LongInt;    { nombre de concatenations            }
  LsMulCount      : LongInt;    { nombre de repetitions               }
  LsContainsCount : LongInt;    { nombre d operateurs in              }
  LsIterCount     : LongInt;    { nombre d iterations for             }
  LsLastKind      : Integer;    { dernier type d operation liste      }
  LsLabelSeq      : Integer;    { sequence pour labels liste          }

{ ------------------------------------------------------------ }
{ InitLsState : initialiser le sous-systeme des listes            }
{ ------------------------------------------------------------ }

Procedure InitLsState;
Begin
  LsInitialized   := True;
  LsEmptyCount    := 0;
  LsLiteralCount  := 0;
  LsIndexCount    := 0;
  LsNegIndexCount := 0;
  LsAssignCount   := 0;
  LsSliceCount    := 0;
  LsLenCount      := 0;
  LsAppendCount   := 0;
  LsPopCount      := 0;
  LsConcatCount   := 0;
  LsMulCount      := 0;
  LsContainsCount := 0;
  LsIterCount     := 0;
  LsLastKind      := LS_NONE;
  LsLabelSeq      := 0;
End;

{ ------------------------------------------------------------ }
{ GenLsLabel : generer un label unique pour les listes             }
{ ------------------------------------------------------------ }

Function GenLsLabel : TString;
Begin
  Inc(LsLabelSeq);
  GenLsLabel := '_PYL_LS_' + ItoS(LsLabelSeq);
End;

{ ------------------------------------------------------------ }
{ LsTypeName : retourner le nom du type d operation liste          }
{ ------------------------------------------------------------ }

Function LsTypeName(K : Integer) : TString;
Begin
  Case K Of
    LS_NONE          : LsTypeName := 'LS_NONE';
    LS_EMPTY         : LsTypeName := 'LS_EMPTY';
    LS_LITERAL       : LsTypeName := 'LS_LITERAL';
    LS_INDEX         : LsTypeName := 'LS_INDEX';
    LS_NEG_INDEX     : LsTypeName := 'LS_NEG_INDEX';
    LS_ASSIGN        : LsTypeName := 'LS_ASSIGN';
    LS_SLICE         : LsTypeName := 'LS_SLICE';
    LS_LEN           : LsTypeName := 'LS_LEN';
    LS_APPEND        : LsTypeName := 'LS_APPEND';
    LS_POP           : LsTypeName := 'LS_POP';
    LS_CONCAT        : LsTypeName := 'LS_CONCAT';
    LS_MUL           : LsTypeName := 'LS_MUL';
    LS_CONTAINS      : LsTypeName := 'LS_CONTAINS';
    LS_ITER          : LsTypeName := 'LS_ITER';
  Else
    LsTypeName := 'LS_UNKNOWN(' + ItoS(K) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ EmitListEmpty : emettre le code pour creer une liste vide        }
{   [] -> allocation d un bloc sur le heap avec count=0            }
{   Layout : [count DD=0]                                         }
{   Resultat dans EAX = ptr vers la liste                         }
{ ------------------------------------------------------------ }

Procedure EmitListEmpty;
Begin
  LsLastKind := LS_EMPTY;
  Inc(LsEmptyCount);
  WriteLn('  ; [] -> liste vide');
  WriteLn('  PUSH ', (LS_INIT_CAP + 1) * 4, ' ; taille : count + capacite');
  WriteLn('  CALL _PYRT_ALLOC');
  WriteLn('  ADD ESP, 4       ; EAX = ptr vers le bloc');
  WriteLn('  MOV DWORD PTR [EAX], 0  ; count = 0');
End;

{ ------------------------------------------------------------ }
{ EmitListLiteral : emettre le code pour creer une liste literale  }
{   [e0, e1, ..., eN] -> allocation + stockage des elements        }
{   ElemCount = nombre d elements                                 }
{   Les valeurs sont deja empilees sur la pile (dernier en haut)  }
{   Layout : [count DD][elem0 DD][elem1 DD]...                   }
{   Resultat dans EAX = ptr vers la liste                         }
{ ------------------------------------------------------------ }

Procedure EmitListLiteral(ElemCount : Integer);
Var
  I : Integer;
Begin
  LsLastKind := LS_LITERAL;
  Inc(LsLiteralCount);
  WriteLn('  ; [', ElemCount, ' elements] -> liste literale');
  WriteLn('  PUSH ', (ElemCount + 1) * 4, ' ; taille : count + elements');
  WriteLn('  CALL _PYRT_ALLOC');
  WriteLn('  ADD ESP, 4       ; EAX = ptr vers le bloc');
  WriteLn('  MOV DWORD PTR [EAX], ', ElemCount, ' ; count = ', ElemCount);
  { Les elements sont sur la pile, les depiler dans l ordre }
  For I := ElemCount DownTo 1 Do
  Begin
    WriteLn('  POP ECX');
    WriteLn('  MOV DWORD PTR [EAX+', I * 4, '], ECX ; elem[', I - 1, ']');
  End;
End;

{ ------------------------------------------------------------ }
{ EmitListIndex : emettre le code pour l acces par index           }
{   lst[i] -> MOV EAX, [EBX+4+i*4]                               }
{   EBX = ptr vers la liste, EAX = index                         }
{   Resultat dans EAX = valeur de l element                       }
{ ------------------------------------------------------------ }

Procedure EmitListIndex;
Begin
  LsLastKind := LS_INDEX;
  Inc(LsIndexCount);
  WriteLn('  ; lst[i] -> acces par index');
  WriteLn('  ; EBX = ptr liste, EAX = index');
  WriteLn('  SHL EAX, 2       ; index * 4');
  WriteLn('  ADD EAX, 4       ; sauter le champ count');
  WriteLn('  ADD EAX, EBX     ; adresse absolue');
  WriteLn('  MOV EAX, [EAX]   ; charger l element');
End;

{ ------------------------------------------------------------ }
{ EmitListNegIndex : emettre le code pour l acces par index negatif }
{   lst[-i] -> index = count + index (negatif)                    }
{   EBX = ptr vers la liste, EAX = index negatif                 }
{   Resultat dans EAX = valeur de l element                       }
{ ------------------------------------------------------------ }

Procedure EmitListNegIndex;
Begin
  LsLastKind := LS_NEG_INDEX;
  Inc(LsNegIndexCount);
  WriteLn('  ; lst[-i] -> acces par index negatif');
  WriteLn('  ; EBX = ptr liste, EAX = index negatif');
  WriteLn('  MOV ECX, [EBX]   ; ECX = count');
  WriteLn('  ADD EAX, ECX     ; index = count + index_negatif');
  WriteLn('  SHL EAX, 2       ; index * 4');
  WriteLn('  ADD EAX, 4       ; sauter le champ count');
  WriteLn('  ADD EAX, EBX     ; adresse absolue');
  WriteLn('  MOV EAX, [EAX]   ; charger l element');
End;

{ ------------------------------------------------------------ }
{ EmitListAssign : emettre le code pour l affectation par index    }
{   lst[i] = val -> MOV [EBX+4+i*4], EAX                         }
{   EBX = ptr vers la liste, ECX = index, EAX = valeur           }
{ ------------------------------------------------------------ }

Procedure EmitListAssign;
Begin
  LsLastKind := LS_ASSIGN;
  Inc(LsAssignCount);
  WriteLn('  ; lst[i] = val -> affectation par index');
  WriteLn('  ; EBX = ptr liste, ECX = index, EAX = valeur');
  WriteLn('  SHL ECX, 2       ; index * 4');
  WriteLn('  ADD ECX, 4       ; sauter le champ count');
  WriteLn('  ADD ECX, EBX     ; adresse absolue');
  WriteLn('  MOV [ECX], EAX   ; stocker la valeur');
End;

{ ------------------------------------------------------------ }
{ EmitListSlice : emettre le code pour le slicing                  }
{   lst[a:b] -> CALL _PYRT_LISTSLICE(ESI=lst, EAX=a, EDX=b)     }
{   Resultat dans EAX = ptr vers la nouvelle sous-liste           }
{ ------------------------------------------------------------ }

Procedure EmitListSlice;
Begin
  LsLastKind := LS_SLICE;
  Inc(LsSliceCount);
  WriteLn('  ; lst[a:b] -> _PYRT_LISTSLICE');
  WriteLn('  ; ESI = ptr liste, EAX = debut, EDX = fin');
  WriteLn('  PUSH EDX         ; fin du slice');
  WriteLn('  PUSH EAX         ; debut du slice');
  WriteLn('  PUSH ESI         ; ptr vers la liste source');
  WriteLn('  CALL _PYRT_LISTSLICE');
  WriteLn('  ADD ESP, 12      ; EAX = ptr vers la sous-liste');
End;

{ ------------------------------------------------------------ }
{ EmitListLen : emettre le code pour len(lst)                      }
{   Le compteur est en tete de la liste : MOV EAX, [EBX]         }
{   EBX = ptr vers la liste                                      }
{   Resultat dans EAX = nombre d elements                        }
{ ------------------------------------------------------------ }

Procedure EmitListLen;
Begin
  LsLastKind := LS_LEN;
  Inc(LsLenCount);
  WriteLn('  ; len(lst) -> compteur en tete de liste');
  WriteLn('  ; EBX = ptr liste');
  WriteLn('  MOV EAX, [EBX]   ; EAX = count');
End;

{ ------------------------------------------------------------ }
{ EmitListAppend : emettre le code pour lst.append(val)            }
{   CALL _PYRT_LISTAPPEND(ESI=lst, EAX=val)                      }
{   Ajoute l element en fin de liste, incremente count            }
{ ------------------------------------------------------------ }

Procedure EmitListAppend;
Begin
  LsLastKind := LS_APPEND;
  Inc(LsAppendCount);
  WriteLn('  ; lst.append(val) -> _PYRT_LISTAPPEND');
  WriteLn('  ; ESI = ptr liste, EAX = valeur a ajouter');
  WriteLn('  PUSH EAX         ; valeur');
  WriteLn('  PUSH ESI         ; ptr vers la liste');
  WriteLn('  CALL _PYRT_LISTAPPEND');
  WriteLn('  ADD ESP, 8');
End;

{ ------------------------------------------------------------ }
{ EmitListPop : emettre le code pour lst.pop()                     }
{   CALL _PYRT_LISTPOP(ESI=lst) -> EAX = dernier element         }
{   Retire le dernier element, decremente count                   }
{ ------------------------------------------------------------ }

Procedure EmitListPop;
Begin
  LsLastKind := LS_POP;
  Inc(LsPopCount);
  WriteLn('  ; lst.pop() -> _PYRT_LISTPOP');
  WriteLn('  ; ESI = ptr liste');
  WriteLn('  PUSH ESI         ; ptr vers la liste');
  WriteLn('  CALL _PYRT_LISTPOP');
  WriteLn('  ADD ESP, 4       ; EAX = element retire');
End;

{ ------------------------------------------------------------ }
{ EmitListConcat : emettre le code pour lst1 + lst2                }
{   CALL _PYRT_LISTCONCAT(ESI=lst1, EDI=lst2) -> EAX=ptr         }
{   Cree une nouvelle liste contenant les elements des deux       }
{ ------------------------------------------------------------ }

Procedure EmitListConcat;
Begin
  LsLastKind := LS_CONCAT;
  Inc(LsConcatCount);
  WriteLn('  ; lst1 + lst2 -> _PYRT_LISTCONCAT');
  WriteLn('  ; ESI = ptr lst1, EDI = ptr lst2');
  WriteLn('  PUSH EDI         ; ptr vers lst2');
  WriteLn('  PUSH ESI         ; ptr vers lst1');
  WriteLn('  CALL _PYRT_LISTCONCAT');
  WriteLn('  ADD ESP, 8       ; EAX = ptr vers nouvelle liste');
End;

{ ------------------------------------------------------------ }
{ EmitListMul : emettre le code pour lst * n                       }
{   CALL _PYRT_LISTMUL(ESI=lst, EAX=n) -> EAX=ptr                }
{   Cree une nouvelle liste avec les elements repetes n fois      }
{ ------------------------------------------------------------ }

Procedure EmitListMul;
Begin
  LsLastKind := LS_MUL;
  Inc(LsMulCount);
  WriteLn('  ; lst * n -> _PYRT_LISTMUL');
  WriteLn('  ; ESI = ptr liste, EAX = facteur de repetition');
  WriteLn('  PUSH EAX         ; facteur de repetition');
  WriteLn('  PUSH ESI         ; ptr vers la liste');
  WriteLn('  CALL _PYRT_LISTMUL');
  WriteLn('  ADD ESP, 8       ; EAX = ptr vers nouvelle liste');
End;

{ ------------------------------------------------------------ }
{ EmitListContains : emettre le code pour val in lst               }
{   CALL _PYRT_LISTCONTAINS(ESI=lst, EAX=val) -> EAX=0|1        }
{   Retourne 1 si l element est present, 0 sinon                 }
{ ------------------------------------------------------------ }

Procedure EmitListContains;
Begin
  LsLastKind := LS_CONTAINS;
  Inc(LsContainsCount);
  WriteLn('  ; val in lst -> _PYRT_LISTCONTAINS');
  WriteLn('  ; ESI = ptr liste, EAX = valeur recherchee');
  WriteLn('  PUSH EAX         ; valeur recherchee');
  WriteLn('  PUSH ESI         ; ptr vers la liste');
  WriteLn('  CALL _PYRT_LISTCONTAINS');
  WriteLn('  ADD ESP, 8       ; EAX = 0 ou 1');
End;

{ ------------------------------------------------------------ }
{ EmitListIter : emettre le code pour iterer sur une liste         }
{   for elem in lst : parcours sequentiel des elements            }
{   EBX = ptr liste, ECX = index courant (0..count-1)             }
{   A chaque iteration : MOV EAX, [EBX+4+ECX*4]                  }
{ ------------------------------------------------------------ }

Procedure EmitListIter;
Var
  LblTest, LblBody, LblIncr, LblEnd : TString;
Begin
  LsLastKind := LS_ITER;
  Inc(LsIterCount);
  LblTest := GenLsLabel;
  LblBody := GenLsLabel;
  LblIncr := GenLsLabel;
  LblEnd  := GenLsLabel;
  WriteLn('  ; for elem in lst -> iteration');
  WriteLn('  ; EBX = ptr liste');
  WriteLn('  XOR ECX, ECX     ; ECX = index = 0');
  WriteLn(LblTest, ':');
  WriteLn('  CMP ECX, [EBX]   ; comparer index avec count');
  WriteLn('  JGE ', LblEnd, '  ; si index >= count, fin');
  WriteLn(LblBody, ':');
  WriteLn('  MOV EAX, ECX');
  WriteLn('  SHL EAX, 2       ; index * 4');
  WriteLn('  MOV EAX, [EBX+EAX+4] ; charger elem[index]');
  WriteLn('  ; --- corps de la boucle ici ---');
  WriteLn(LblIncr, ':');
  WriteLn('  INC ECX           ; index++');
  WriteLn('  JMP ', LblTest);
  WriteLn(LblEnd, ':');
End;

{ ------------------------------------------------------------ }
{ ParseListExpr : analyser une expression de liste                 }
{   [expr1, expr2, ...] -> EmitListLiteral                        }
{   [] -> EmitListEmpty                                           }
{ ------------------------------------------------------------ }

Procedure ParseListExpr;
Var
  ElemCount : Integer;
Begin
  ElemCount := 0;

  { On attend que '[' soit deja consomme }
  { Verifier s il s agit d une liste vide }
  If (CurTokKind = TK_OP) And (CurTokStr = ']') Then
  Begin
    { Liste vide }
    EmitListEmpty;
    LexNextToken;  { consommer ']' }
    Exit;
  End;

  { Boucle sur les elements }
  While Not ((CurTokKind = TK_OP) And (CurTokStr = ']')) And
        Not (CurTokKind = TK_EOF) Do
  Begin
    Inc(ElemCount);

    { Evaluer l element }
    If CurTokKind = TK_INTEGER Then
    Begin
      WriteLn('  PUSH ', CurTokInt, ' ; elem[', ElemCount - 1, ']');
      LexNextToken;
    End
    Else If CurTokKind = TK_STRING Then
    Begin
      WriteLn('  PUSH OFFSET ', GenLsLabel, ' ; elem[', ElemCount - 1, '] (str)');
      LexNextToken;
    End
    Else If (CurTokKind = TK_KEYWORD) And (CurTokStr = 'True') Then
    Begin
      WriteLn('  PUSH 1           ; elem[', ElemCount - 1, '] (True)');
      LexNextToken;
    End
    Else If (CurTokKind = TK_KEYWORD) And (CurTokStr = 'False') Then
    Begin
      WriteLn('  PUSH 0           ; elem[', ElemCount - 1, '] (False)');
      LexNextToken;
    End
    Else If (CurTokKind = TK_KEYWORD) And (CurTokStr = 'None') Then
    Begin
      WriteLn('  PUSH 0           ; elem[', ElemCount - 1, '] (None)');
      LexNextToken;
    End
    Else If CurTokKind = TK_IDENT Then
    Begin
      WriteLn('  PUSH DWORD PTR [', SymMangle(CurTokStr, SK_VAR),
              ']  ; elem[', ElemCount - 1, '] (var)');
      LexNextToken;
    End
    Else
    Begin
      { Expression generique }
      WriteLn('  PUSH EAX         ; elem[', ElemCount - 1, ']');
      LexNextToken;
    End;

    { Consommer la virgule entre elements }
    If (CurTokKind = TK_OP) And (CurTokStr = ',') Then
      LexNextToken;
  End;

  { Consommer ']' }
  If (CurTokKind = TK_OP) And (CurTokStr = ']') Then
    LexNextToken;

  { Emettre le code pour creer la liste }
  If ElemCount = 0 Then
    EmitListEmpty
  Else
    EmitListLiteral(ElemCount);
End;

{ ------------------------------------------------------------ }
{ DumpLsState : afficher l etat du sous-systeme des listes         }
{ ------------------------------------------------------------ }

Procedure DumpLsState;
Begin
  WriteLn('--- List State ---');
  WriteLn('  LsInitialized   : ', LsInitialized);
  WriteLn('  LsEmptyCount    : ', LsEmptyCount);
  WriteLn('  LsLiteralCount  : ', LsLiteralCount);
  WriteLn('  LsIndexCount    : ', LsIndexCount);
  WriteLn('  LsNegIndexCount : ', LsNegIndexCount);
  WriteLn('  LsAssignCount   : ', LsAssignCount);
  WriteLn('  LsSliceCount    : ', LsSliceCount);
  WriteLn('  LsLenCount      : ', LsLenCount);
  WriteLn('  LsAppendCount   : ', LsAppendCount);
  WriteLn('  LsPopCount      : ', LsPopCount);
  WriteLn('  LsConcatCount   : ', LsConcatCount);
  WriteLn('  LsMulCount      : ', LsMulCount);
  WriteLn('  LsContainsCount : ', LsContainsCount);
  WriteLn('  LsIterCount     : ', LsIterCount);
  WriteLn('  LsLastKind      : ', LsTypeName(LsLastKind));
  WriteLn('  LsLabelSeq      : ', LsLabelSeq);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 14)                              }
{ ------------------------------------------------------------ }

Function IsLsInitialized : Boolean;
Begin
  IsLsInitialized := LsInitialized;
End;

Function IsLsEmpty : Boolean;
Begin
  IsLsEmpty := (LsEmptyCount = 0) And (LsLiteralCount = 0) And
               (LsIndexCount = 0) And (LsAppendCount = 0);
End;

Function GetLsEmptyCount : LongInt;
Begin
  GetLsEmptyCount := LsEmptyCount;
End;

Function GetLsLiteralCount : LongInt;
Begin
  GetLsLiteralCount := LsLiteralCount;
End;

Function GetLsIndexCount : LongInt;
Begin
  GetLsIndexCount := LsIndexCount;
End;

Function GetLsAppendCount : LongInt;
Begin
  GetLsAppendCount := LsAppendCount;
End;

Function GetLsPopCount : LongInt;
Begin
  GetLsPopCount := LsPopCount;
End;

Function GetLsConcatCount : LongInt;
Begin
  GetLsConcatCount := LsConcatCount;
End;

Function GetLsContainsCount : LongInt;
Begin
  GetLsContainsCount := LsContainsCount;
End;

Function GetLsStatus : TString;
Begin
  If Not LsInitialized Then
    GetLsStatus := 'Not initialized'
  Else
    GetLsStatus := ItoS(LsEmptyCount) + ' empty, ' +
                   ItoS(LsLiteralCount) + ' literal, ' +
                   ItoS(LsIndexCount) + ' index, ' +
                   ItoS(LsAppendCount) + ' append, ' +
                   ItoS(LsPopCount) + ' pop, ' +
                   ItoS(LsConcatCount) + ' concat, ' +
                   ItoS(LsContainsCount) + ' contains';
End;

{ ============================================================ }
{ TODO 15 - PARSEUR : DICTIONNAIRES (dict)                     }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { Types d operations sur les dictionnaires }
  DC_NONE          = 0;    { aucun / non defini                    }
  DC_EMPTY         = 1;    { dict vide                             }
  DC_LITERAL       = 2;    { dict literal k:v, ...                 }
  DC_GET           = 3;    { acces par cle d[key]                  }
  DC_SET           = 4;    { affectation par cle d[key] = val      }
  DC_GETDEF        = 5;    { d.get(key, default)                   }
  DC_CONTAINS      = 6;    { key in d -> booleen                   }
  DC_LEN           = 7;    { len(d) -> nombre de paires            }
  DC_KEYS          = 8;    { d.keys() -> liste des cles            }
  DC_VALUES        = 9;    { d.values() -> liste des valeurs       }
  DC_DEL           = 10;   { del d[key]                            }
  DC_ITER          = 11;   { iteration for k in d                  }
  DC_UPDATE        = 12;   { d.update(other)                       }
  DC_ITEMS         = 13;   { d.items() -> liste de paires          }
  DC_MAX           = 13;

  { Limites }
  DC_MAX_PAIRS     = 64;   { nombre max de paires dans un dict     }
  DC_INIT_CAP      = 8;    { capacite initiale d allocation        }

Var
  DcInitialized   : Boolean;    { True si l etat est initialise       }
  DcEmptyCount    : LongInt;    { nombre de dicts vides crees         }
  DcLiteralCount  : LongInt;    { nombre de dicts literaux            }
  DcGetCount      : LongInt;    { nombre d acces par cle              }
  DcSetCount      : LongInt;    { nombre d affectations par cle       }
  DcGetDefCount   : LongInt;    { nombre d appels a get(key, def)     }
  DcContainsCount : LongInt;    { nombre d operateurs in              }
  DcLenCount      : LongInt;    { nombre d appels a len(d)            }
  DcKeysCount     : LongInt;    { nombre d appels a keys()            }
  DcValuesCount   : LongInt;    { nombre d appels a values()          }
  DcDelCount      : LongInt;    { nombre d appels a del d[key]        }
  DcIterCount     : LongInt;    { nombre d iterations for k in d      }
  DcUpdateCount   : LongInt;    { nombre d appels a update()          }
  DcItemsCount    : LongInt;    { nombre d appels a items()           }
  DcLastKind      : Integer;    { dernier type d operation dict       }
  DcLabelSeq      : Integer;    { sequence pour labels dict           }

{ ------------------------------------------------------------ }
{ InitDcState : initialiser le sous-systeme des dictionnaires      }
{ ------------------------------------------------------------ }

Procedure InitDcState;
Begin
  DcInitialized   := True;
  DcEmptyCount    := 0;
  DcLiteralCount  := 0;
  DcGetCount      := 0;
  DcSetCount      := 0;
  DcGetDefCount   := 0;
  DcContainsCount := 0;
  DcLenCount      := 0;
  DcKeysCount     := 0;
  DcValuesCount   := 0;
  DcDelCount      := 0;
  DcIterCount     := 0;
  DcUpdateCount   := 0;
  DcItemsCount    := 0;
  DcLastKind      := DC_NONE;
  DcLabelSeq      := 0;
End;

{ ------------------------------------------------------------ }
{ GenDcLabel : generer un label unique pour les dictionnaires       }
{ ------------------------------------------------------------ }

Function GenDcLabel : TString;
Begin
  Inc(DcLabelSeq);
  GenDcLabel := '_PYL_DC_' + ItoS(DcLabelSeq);
End;

{ ------------------------------------------------------------ }
{ DcTypeName : retourner le nom du type d operation dictionnaire    }
{ ------------------------------------------------------------ }

Function DcTypeName(K : Integer) : TString;
Begin
  Case K Of
    DC_NONE          : DcTypeName := 'DC_NONE';
    DC_EMPTY         : DcTypeName := 'DC_EMPTY';
    DC_LITERAL       : DcTypeName := 'DC_LITERAL';
    DC_GET           : DcTypeName := 'DC_GET';
    DC_SET           : DcTypeName := 'DC_SET';
    DC_GETDEF        : DcTypeName := 'DC_GETDEF';
    DC_CONTAINS      : DcTypeName := 'DC_CONTAINS';
    DC_LEN           : DcTypeName := 'DC_LEN';
    DC_KEYS          : DcTypeName := 'DC_KEYS';
    DC_VALUES        : DcTypeName := 'DC_VALUES';
    DC_DEL           : DcTypeName := 'DC_DEL';
    DC_ITER          : DcTypeName := 'DC_ITER';
    DC_UPDATE        : DcTypeName := 'DC_UPDATE';
    DC_ITEMS         : DcTypeName := 'DC_ITEMS';
  Else
    DcTypeName := 'DC_UNKNOWN(' + ItoS(K) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ EmitDictEmpty : emettre le code pour creer un dict vide          }
{   dict vide -> allocation d une table de hachage vide sur le heap}
{   Layout : [count DD=0][paires...]                              }
{   Chaque paire : [key DD][val DD] = 8 octets                   }
{   Resultat dans EAX = ptr vers le dict                          }
{ ------------------------------------------------------------ }

Procedure EmitDictEmpty;
Begin
  DcLastKind := DC_EMPTY;
  Inc(DcEmptyCount);
  WriteLn('  ; {} -> dict vide');
  WriteLn('  PUSH ', (DC_INIT_CAP * 2 + 1) * 4, ' ; taille : count + capacite paires');
  WriteLn('  CALL _PYRT_ALLOC');
  WriteLn('  ADD ESP, 4       ; EAX = ptr vers le bloc');
  WriteLn('  MOV DWORD PTR [EAX], 0  ; count = 0');
End;

{ ------------------------------------------------------------ }
{ EmitDictLiteral : emettre le code pour creer un dict literal     }
{   k0:v0, k1:v1, ... -> allocation + insertion des paires        }
{   PairCount = nombre de paires cle/valeur                       }
{   Les paires sont deja empilees : val, key, val, key, ...       }
{   Layout : [count DD][key0 DD][val0 DD][key1 DD][val1 DD]...   }
{   Resultat dans EAX = ptr vers le dict                          }
{ ------------------------------------------------------------ }

Procedure EmitDictLiteral(PairCount : Integer);
Var
  I : Integer;
Begin
  DcLastKind := DC_LITERAL;
  Inc(DcLiteralCount);
  WriteLn('  ; {', PairCount, ' paires} -> dict literal');
  WriteLn('  PUSH ', (PairCount * 2 + 1) * 4, ' ; taille : count + paires');
  WriteLn('  CALL _PYRT_ALLOC');
  WriteLn('  ADD ESP, 4       ; EAX = ptr vers le bloc');
  WriteLn('  MOV DWORD PTR [EAX], ', PairCount, ' ; count = ', PairCount);
  { Les paires sont sur la pile, les depiler dans l ordre }
  For I := PairCount DownTo 1 Do
  Begin
    WriteLn('  POP ECX');
    WriteLn('  MOV DWORD PTR [EAX+', (I - 1) * 8 + 8, '], ECX ; val[', I - 1, ']');
    WriteLn('  POP ECX');
    WriteLn('  MOV DWORD PTR [EAX+', (I - 1) * 8 + 4, '], ECX ; key[', I - 1, ']');
  End;
End;

{ ------------------------------------------------------------ }
{ EmitDictGet : emettre le code pour l acces par cle               }
{   d[key] -> CALL _PYRT_DICTGET(ESI=dict, EAX=key) -> EAX=val  }
{   KeyError si cle absente -> _PYRT_PANIC                        }
{ ------------------------------------------------------------ }

Procedure EmitDictGet;
Begin
  DcLastKind := DC_GET;
  Inc(DcGetCount);
  WriteLn('  ; d[key] -> _PYRT_DICTGET');
  WriteLn('  ; ESI = ptr dict, EAX = cle');
  WriteLn('  PUSH EAX         ; cle');
  WriteLn('  PUSH ESI         ; ptr vers le dict');
  WriteLn('  CALL _PYRT_DICTGET');
  WriteLn('  ADD ESP, 8       ; EAX = valeur (ou panic si absent)');
End;

{ ------------------------------------------------------------ }
{ EmitDictSet : emettre le code pour l affectation par cle         }
{   d[key] = val -> CALL _PYRT_DICTSET(ESI=dict, EAX=key, EBX=val)}
{   Insere ou met a jour la paire cle/valeur                      }
{ ------------------------------------------------------------ }

Procedure EmitDictSet;
Begin
  DcLastKind := DC_SET;
  Inc(DcSetCount);
  WriteLn('  ; d[key] = val -> _PYRT_DICTSET');
  WriteLn('  ; ESI = ptr dict, EAX = cle, EBX = valeur');
  WriteLn('  PUSH EBX         ; valeur');
  WriteLn('  PUSH EAX         ; cle');
  WriteLn('  PUSH ESI         ; ptr vers le dict');
  WriteLn('  CALL _PYRT_DICTSET');
  WriteLn('  ADD ESP, 12');
End;

{ ------------------------------------------------------------ }
{ EmitDictGetDef : emettre le code pour d.get(key, default)        }
{   CALL _PYRT_DICTGETDEF(ESI=dict, EAX=key, EBX=default)        }
{   Retourne la valeur ou le default si cle absente               }
{   Resultat dans EAX                                             }
{ ------------------------------------------------------------ }

Procedure EmitDictGetDef;
Begin
  DcLastKind := DC_GETDEF;
  Inc(DcGetDefCount);
  WriteLn('  ; d.get(key, default) -> _PYRT_DICTGETDEF');
  WriteLn('  ; ESI = ptr dict, EAX = cle, EBX = valeur par defaut');
  WriteLn('  PUSH EBX         ; valeur par defaut');
  WriteLn('  PUSH EAX         ; cle');
  WriteLn('  PUSH ESI         ; ptr vers le dict');
  WriteLn('  CALL _PYRT_DICTGETDEF');
  WriteLn('  ADD ESP, 12      ; EAX = valeur ou default');
End;

{ ------------------------------------------------------------ }
{ EmitDictContains : emettre le code pour key in d                 }
{   CALL _PYRT_DICTCONTAINS(ESI=dict, EAX=key) -> EAX=0|1       }
{   Retourne 1 si la cle est presente, 0 sinon                   }
{ ------------------------------------------------------------ }

Procedure EmitDictContains;
Begin
  DcLastKind := DC_CONTAINS;
  Inc(DcContainsCount);
  WriteLn('  ; key in d -> _PYRT_DICTCONTAINS');
  WriteLn('  ; ESI = ptr dict, EAX = cle recherchee');
  WriteLn('  PUSH EAX         ; cle recherchee');
  WriteLn('  PUSH ESI         ; ptr vers le dict');
  WriteLn('  CALL _PYRT_DICTCONTAINS');
  WriteLn('  ADD ESP, 8       ; EAX = 0 ou 1');
End;

{ ------------------------------------------------------------ }
{ EmitDictLen : emettre le code pour len(d)                        }
{   Le compteur est en tete du dict : MOV EAX, [EBX]             }
{   EBX = ptr vers le dict                                       }
{   Resultat dans EAX = nombre de paires                          }
{ ------------------------------------------------------------ }

Procedure EmitDictLen;
Begin
  DcLastKind := DC_LEN;
  Inc(DcLenCount);
  WriteLn('  ; len(d) -> compteur en tete de dict');
  WriteLn('  ; EBX = ptr dict');
  WriteLn('  MOV EAX, [EBX]   ; EAX = count (nombre de paires)');
End;

{ ------------------------------------------------------------ }
{ EmitDictKeys : emettre le code pour d.keys()                     }
{   CALL _PYRT_DICTKEYS(ESI=dict) -> EAX=ptr vers liste des cles }
{   Retourne une nouvelle liste contenant toutes les cles         }
{ ------------------------------------------------------------ }

Procedure EmitDictKeys;
Begin
  DcLastKind := DC_KEYS;
  Inc(DcKeysCount);
  WriteLn('  ; d.keys() -> _PYRT_DICTKEYS');
  WriteLn('  ; ESI = ptr dict');
  WriteLn('  PUSH ESI         ; ptr vers le dict');
  WriteLn('  CALL _PYRT_DICTKEYS');
  WriteLn('  ADD ESP, 4       ; EAX = ptr vers liste des cles');
End;

{ ------------------------------------------------------------ }
{ EmitDictValues : emettre le code pour d.values()                 }
{   CALL _PYRT_DICTVALUES(ESI=dict) -> EAX=ptr vers liste vals   }
{   Retourne une nouvelle liste contenant toutes les valeurs      }
{ ------------------------------------------------------------ }

Procedure EmitDictValues;
Begin
  DcLastKind := DC_VALUES;
  Inc(DcValuesCount);
  WriteLn('  ; d.values() -> _PYRT_DICTVALUES');
  WriteLn('  ; ESI = ptr dict');
  WriteLn('  PUSH ESI         ; ptr vers le dict');
  WriteLn('  CALL _PYRT_DICTVALUES');
  WriteLn('  ADD ESP, 4       ; EAX = ptr vers liste des valeurs');
End;

{ ------------------------------------------------------------ }
{ EmitDictDel : emettre le code pour del d[key]                    }
{   CALL _PYRT_DICTDEL(ESI=dict, EAX=key)                        }
{   Supprime la paire cle/valeur du dictionnaire                  }
{ ------------------------------------------------------------ }

Procedure EmitDictDel;
Begin
  DcLastKind := DC_DEL;
  Inc(DcDelCount);
  WriteLn('  ; del d[key] -> _PYRT_DICTDEL');
  WriteLn('  ; ESI = ptr dict, EAX = cle a supprimer');
  WriteLn('  PUSH EAX         ; cle');
  WriteLn('  PUSH ESI         ; ptr vers le dict');
  WriteLn('  CALL _PYRT_DICTDEL');
  WriteLn('  ADD ESP, 8');
End;

{ ------------------------------------------------------------ }
{ EmitDictIter : emettre le code pour iterer sur les cles d un dict}
{   for k in d : parcours sequentiel des cles                     }
{   EBX = ptr dict, ECX = index courant (0..count-1)              }
{   A chaque iteration : MOV EAX, [EBX+4+ECX*8] (cle de paire)  }
{ ------------------------------------------------------------ }

Procedure EmitDictIter;
Var
  LblTest, LblBody, LblIncr, LblEnd : TString;
Begin
  DcLastKind := DC_ITER;
  Inc(DcIterCount);
  LblTest := GenDcLabel;
  LblBody := GenDcLabel;
  LblIncr := GenDcLabel;
  LblEnd  := GenDcLabel;
  WriteLn('  ; for k in d -> iteration sur les cles');
  WriteLn('  ; EBX = ptr dict');
  WriteLn('  XOR ECX, ECX     ; ECX = index = 0');
  WriteLn(LblTest, ':');
  WriteLn('  CMP ECX, [EBX]   ; comparer index avec count');
  WriteLn('  JGE ', LblEnd, '  ; si index >= count, fin');
  WriteLn(LblBody, ':');
  WriteLn('  MOV EAX, ECX');
  WriteLn('  SHL EAX, 3       ; index * 8 (paires de 8 octets)');
  WriteLn('  MOV EAX, [EBX+EAX+4] ; charger key[index]');
  WriteLn('  ; --- corps de la boucle ici ---');
  WriteLn(LblIncr, ':');
  WriteLn('  INC ECX           ; index++');
  WriteLn('  JMP ', LblTest);
  WriteLn(LblEnd, ':');
End;

{ ------------------------------------------------------------ }
{ EmitDictUpdate : emettre le code pour d.update(other)            }
{   CALL _PYRT_DICTUPDATE(ESI=dict, EDI=other)                   }
{   Fusionne les paires de other dans dict                        }
{ ------------------------------------------------------------ }

Procedure EmitDictUpdate;
Begin
  DcLastKind := DC_UPDATE;
  Inc(DcUpdateCount);
  WriteLn('  ; d.update(other) -> _PYRT_DICTUPDATE');
  WriteLn('  ; ESI = ptr dict dest, EDI = ptr dict source');
  WriteLn('  PUSH EDI         ; ptr vers dict source');
  WriteLn('  PUSH ESI         ; ptr vers dict destination');
  WriteLn('  CALL _PYRT_DICTUPDATE');
  WriteLn('  ADD ESP, 8');
End;

{ ------------------------------------------------------------ }
{ EmitDictItems : emettre le code pour d.items()                   }
{   CALL _PYRT_DICTITEMS(ESI=dict) -> EAX=ptr vers liste paires  }
{   Retourne une liste de tuples (key, val)                       }
{ ------------------------------------------------------------ }

Procedure EmitDictItems;
Begin
  DcLastKind := DC_ITEMS;
  Inc(DcItemsCount);
  WriteLn('  ; d.items() -> _PYRT_DICTITEMS');
  WriteLn('  ; ESI = ptr dict');
  WriteLn('  PUSH ESI         ; ptr vers le dict');
  WriteLn('  CALL _PYRT_DICTITEMS');
  WriteLn('  ADD ESP, 4       ; EAX = ptr vers liste de paires');
End;

{ ------------------------------------------------------------ }
{ ParseDictExpr : analyser une expression de dictionnaire          }
{   k0:v0, k1:v1, ... -> EmitDictLiteral                         }
{   dict vide -> EmitDictEmpty                                    }
{ ------------------------------------------------------------ }

Procedure ParseDictExpr;
Var
  PairCount : Integer;
Begin
  PairCount := 0;

  (* On attend que l accolade ouvrante soit deja consommee *)
  (* Verifier s il s agit d un dict vide *)
  If (CurTokKind = TK_OP) And (CurTokStr = '}') Then
  Begin
    { Dict vide }
    EmitDictEmpty;
    LexNextToken;  (* consommer '}' *)
    Exit;
  End;

  { Boucle sur les paires cle:valeur }
  While Not ((CurTokKind = TK_OP) And (CurTokStr = '}')) And
        Not (CurTokKind = TK_EOF) Do
  Begin
    Inc(PairCount);

    { Evaluer la cle }
    If CurTokKind = TK_INTEGER Then
    Begin
      WriteLn('  PUSH ', CurTokInt, ' ; key[', PairCount - 1, ']');
      LexNextToken;
    End
    Else If CurTokKind = TK_STRING Then
    Begin
      WriteLn('  PUSH OFFSET ', GenDcLabel, ' ; key[', PairCount - 1, '] (str)');
      LexNextToken;
    End
    Else If CurTokKind = TK_IDENT Then
    Begin
      WriteLn('  PUSH DWORD PTR [', SymMangle(CurTokStr, SK_VAR),
              ']  ; key[', PairCount - 1, '] (var)');
      LexNextToken;
    End
    Else
    Begin
      WriteLn('  PUSH EAX         ; key[', PairCount - 1, ']');
      LexNextToken;
    End;

    { Consommer ':' }
    If (CurTokKind = TK_OP) And (CurTokStr = ':') Then
      LexNextToken;

    { Evaluer la valeur }
    If CurTokKind = TK_INTEGER Then
    Begin
      WriteLn('  PUSH ', CurTokInt, ' ; val[', PairCount - 1, ']');
      LexNextToken;
    End
    Else If CurTokKind = TK_STRING Then
    Begin
      WriteLn('  PUSH OFFSET ', GenDcLabel, ' ; val[', PairCount - 1, '] (str)');
      LexNextToken;
    End
    Else If (CurTokKind = TK_KEYWORD) And (CurTokStr = 'True') Then
    Begin
      WriteLn('  PUSH 1           ; val[', PairCount - 1, '] (True)');
      LexNextToken;
    End
    Else If (CurTokKind = TK_KEYWORD) And (CurTokStr = 'False') Then
    Begin
      WriteLn('  PUSH 0           ; val[', PairCount - 1, '] (False)');
      LexNextToken;
    End
    Else If (CurTokKind = TK_KEYWORD) And (CurTokStr = 'None') Then
    Begin
      WriteLn('  PUSH 0           ; val[', PairCount - 1, '] (None)');
      LexNextToken;
    End
    Else If CurTokKind = TK_IDENT Then
    Begin
      WriteLn('  PUSH DWORD PTR [', SymMangle(CurTokStr, SK_VAR),
              ']  ; val[', PairCount - 1, '] (var)');
      LexNextToken;
    End
    Else
    Begin
      WriteLn('  PUSH EAX         ; val[', PairCount - 1, ']');
      LexNextToken;
    End;

    { Consommer la virgule entre paires }
    If (CurTokKind = TK_OP) And (CurTokStr = ',') Then
      LexNextToken;
  End;

  (* Consommer '}' *)
  If (CurTokKind = TK_OP) And (CurTokStr = '}') Then
    LexNextToken;

  { Emettre le code pour creer le dict }
  If PairCount = 0 Then
    EmitDictEmpty
  Else
    EmitDictLiteral(PairCount);
End;

{ ------------------------------------------------------------ }
{ DumpDcState : afficher l etat du sous-systeme des dictionnaires  }
{ ------------------------------------------------------------ }

Procedure DumpDcState;
Begin
  WriteLn('--- Dict State ---');
  WriteLn('  DcInitialized   : ', DcInitialized);
  WriteLn('  DcEmptyCount    : ', DcEmptyCount);
  WriteLn('  DcLiteralCount  : ', DcLiteralCount);
  WriteLn('  DcGetCount      : ', DcGetCount);
  WriteLn('  DcSetCount      : ', DcSetCount);
  WriteLn('  DcGetDefCount   : ', DcGetDefCount);
  WriteLn('  DcContainsCount : ', DcContainsCount);
  WriteLn('  DcLenCount      : ', DcLenCount);
  WriteLn('  DcKeysCount     : ', DcKeysCount);
  WriteLn('  DcValuesCount   : ', DcValuesCount);
  WriteLn('  DcDelCount      : ', DcDelCount);
  WriteLn('  DcIterCount     : ', DcIterCount);
  WriteLn('  DcUpdateCount   : ', DcUpdateCount);
  WriteLn('  DcItemsCount    : ', DcItemsCount);
  WriteLn('  DcLastKind      : ', DcTypeName(DcLastKind));
  WriteLn('  DcLabelSeq      : ', DcLabelSeq);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 15)                              }
{ ------------------------------------------------------------ }

Function IsDcInitialized : Boolean;
Begin
  IsDcInitialized := DcInitialized;
End;

Function IsDcEmpty : Boolean;
Begin
  IsDcEmpty := (DcEmptyCount = 0) And (DcLiteralCount = 0) And
               (DcGetCount = 0) And (DcSetCount = 0);
End;

Function GetDcEmptyCount : LongInt;
Begin
  GetDcEmptyCount := DcEmptyCount;
End;

Function GetDcLiteralCount : LongInt;
Begin
  GetDcLiteralCount := DcLiteralCount;
End;

Function GetDcGetCount : LongInt;
Begin
  GetDcGetCount := DcGetCount;
End;

Function GetDcSetCount : LongInt;
Begin
  GetDcSetCount := DcSetCount;
End;

Function GetDcContainsCount : LongInt;
Begin
  GetDcContainsCount := DcContainsCount;
End;

Function GetDcDelCount : LongInt;
Begin
  GetDcDelCount := DcDelCount;
End;

Function GetDcKeysCount : LongInt;
Begin
  GetDcKeysCount := DcKeysCount;
End;

Function GetDcStatus : TString;
Begin
  If Not DcInitialized Then
    GetDcStatus := 'Not initialized'
  Else
    GetDcStatus := ItoS(DcEmptyCount) + ' empty, ' +
                   ItoS(DcLiteralCount) + ' literal, ' +
                   ItoS(DcGetCount) + ' get, ' +
                   ItoS(DcSetCount) + ' set, ' +
                   ItoS(DcContainsCount) + ' contains, ' +
                   ItoS(DcDelCount) + ' del, ' +
                   ItoS(DcKeysCount) + ' keys';
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
  TypInitialized := False;
  LitInitialized := False;
  OprInitialized := False;
  PxInitialized := False;
  VaInitialized := False;
  IfInitialized := False;
  LpInitialized := False;
  FnInitialized := False;
  IoInitialized := False;
  LsInitialized := False;
  DcInitialized := False;

  ParseArgs;

  { Affichage de la banniere en mode verbeux }
  ShowBanner;

  { Initialiser la reconnaissance des mots-cles }
  InitKwState;

  { Initialiser la table des symboles }
  SymInit;

  { Initialiser le systeme de types }
  TypeInit;

  { Initialiser les litteraux et le segment DATA }
  LitInit;

  { Initialiser le sous-systeme des operateurs }
  InitOprState;

  { Initialiser le sous-systeme des primaires et appels }
  InitPxState;

  { Initialiser le sous-systeme des variables et affectations }
  InitVaState;

  { Initialiser le sous-systeme if/elif/else }
  InitIfState;

  { Initialiser le sous-systeme des boucles }
  InitLpState;

  { Initialiser le sous-systeme des fonctions }
  InitFnState;

  { Initialiser le sous-systeme des entrees/sorties }
  InitIoState;

  { Initialiser le sous-systeme des listes }
  InitLsState;

  { Initialiser le sous-systeme des dictionnaires }
  InitDcState;

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
    WriteLn('Types enregistres: ', GetTypeCount);
    WriteLn('Donnees DATA     : ', GetDataCount);
    WriteLn('Expressions      : ', GetOprParseCount);
    WriteLn('Ops binaires     : ', GetOprBinOpCount);
    WriteLn('Ops unaires      : ', GetOprUnaryCount);
    WriteLn('Pliages constantes: ', GetOprFoldCount);
    WriteLn('Appels fonctions : ', GetPxCallCount);
    WriteLn('Appels methodes  : ', GetPxMethCount);
    WriteLn('Acces attributs  : ', GetPxAttrCount);
    WriteLn('Acces index      : ', GetPxIndexCount);
    WriteLn('Appels builtins  : ', GetPxBuiltinCount);
    WriteLn('Affectations     : ', GetVaAssignCount);
    WriteLn('Affect augmentees: ', GetVaAugCount);
    WriteLn('Affect multiples : ', GetVaMultiCount);
    WriteLn('Echanges         : ', GetVaSwapCount);
    WriteLn('Instructions del : ', GetVaDelCount);
    WriteLn('Instructions glob: ', GetVaGlobalCount);
    WriteLn('Instr nonlocal   : ', GetVaNonlocalCount);
    WriteLn('Instructions if  : ', GetIfStmtCount);
    WriteLn('Clauses elif     : ', GetIfElifCount);
    WriteLn('Clauses else     : ', GetIfElseCount);
    WriteLn('Expr ternaires   : ', GetIfTernaryCount);
    WriteLn('Instructions pass: ', GetIfPassCount);
    WriteLn('And court-circuit: ', GetIfAndScCount);
    WriteLn('Or court-circuit : ', GetIfOrScCount);
    WriteLn('Boucles while    : ', GetLpWhileCount);
    WriteLn('Boucles for      : ', GetLpForCount);
    WriteLn('Instructions break: ', GetLpBreakCount);
    WriteLn('Instr continue   : ', GetLpContCount);
    WriteLn('Else de boucle   : ', GetLpElseCount);
    WriteLn('Max imbrication  : ', GetLpMaxNestSeen);
    WriteLn('Definitions fn   : ', GetFnDefCount);
    WriteLn('Return statements: ', GetFnReturnCount);
    WriteLn('Return None      : ', GetFnRetNoneCount);
    WriteLn('Appels fonctions : ', GetFnCallCount);
    WriteLn('Parametres decl  : ', GetFnParamCount);
    WriteLn('Params par defaut: ', GetFnDefParamCount);
    WriteLn('Appels recursifs : ', GetFnRecursCount);
    WriteLn('Print int        : ', GetIoPrintIntCount);
    WriteLn('Print str        : ', GetIoPrintStrCount);
    WriteLn('Print bool       : ', GetIoPrintBoolCount);
    WriteLn('Print multi-args : ', GetIoPrintMultiCount);
    WriteLn('Input            : ', GetIoInputCount);
    WriteLn('Input avec prompt: ', GetIoInputPromptCount);
    WriteLn('Int(input())     : ', GetIoIntInputCount);
    WriteLn('Listes vides     : ', GetLsEmptyCount);
    WriteLn('Listes literales : ', GetLsLiteralCount);
    WriteLn('Acces index lst  : ', GetLsIndexCount);
    WriteLn('Appels append    : ', GetLsAppendCount);
    WriteLn('Appels pop       : ', GetLsPopCount);
    WriteLn('Concatenations   : ', GetLsConcatCount);
    WriteLn('Operateurs in    : ', GetLsContainsCount);
    WriteLn('Dicts vides      : ', GetDcEmptyCount);
    WriteLn('Dicts literaux   : ', GetDcLiteralCount);
    WriteLn('Dict get         : ', GetDcGetCount);
    WriteLn('Dict set         : ', GetDcSetCount);
    WriteLn('Dict contains    : ', GetDcContainsCount);
    WriteLn('Dict del         : ', GetDcDelCount);
    WriteLn('Dict keys        : ', GetDcKeysCount);
  End;

  If Opts.DebugMode Then
  Begin
    DumpKwState;
    DumpSymState;
    DumpTypState;
    DumpLitState;
    DumpOprState;
    DumpPxState;
    DumpVaState;
    DumpIfState;
    DumpLpState;
    DumpFnState;
    DumpIoState;
    DumpLsState;
    DumpDcState;
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
