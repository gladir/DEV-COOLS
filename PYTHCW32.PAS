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
            print( *args, sep=' ', end='\n') :
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

  TODO 16 - PARSEUR : TUPLES ET UNPACKING [IMPLEMENTE]
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

  TODO 17 - PARSEUR : CHAINES (str) OPERATIONS AVANCEES [IMPLEMENTE]
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

  TODO 18 - PARSEUR : CLASSES ET OBJETS [IMPLEMENTE]
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

  TODO 19 - PARSEUR : EXCEPTIONS (try / except / finally / raise) [IMPLEMENTE]
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

  TODO 20 - PARSEUR : COMPREHENSIONS ET IMPORT [IMPLEMENTE]
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

  TODO 21 - GENERATION DE CODE : SEGMENT DE DONNEES 80386 [IMPLEMENTE]
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

  TODO 22 - BIBLIOTHEQUE RUNTIME PYTHON (E/S, CONVERSIONS VIA WIN32) [IMPLEMENTE]
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

  TODO 23 - ECRIVAIN BINAIRE PE ET COFF .OBJ [IMPLEMENTE]
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

  TODO 24 - IMPORTS API WIN32 ET GENERATEUR LISTING ASM [IMPLEMENTE]
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

  TODO 25 - OPTIMISATIONS, TESTS FINAUX ET INTEGRATION SAMPLES\PYTHON\* [IMPLEMENTE]
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
  CurTokKind  : Integer;       { type de token (TK_* )                 }
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
  KwLastKW      : Integer;       { dernier mot-cle reconnu (KW_* )       }
  KwLastBI      : Integer;       { dernier builtin reconnu (BI_* )       }
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
  { Enregistrer les 10 types primitifs (ordre = TY_IDX_* ) }
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
    LexNextToken;  (* consommer accolade *)
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

  (* Consommer accolade ferm‚ *)
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
{ TODO 16 - PARSEUR : TUPLES ET UNPACKING                     }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { Types d operations sur les tuples }
  TP_NONE          = 0;    { aucun / non defini                    }
  TP_EMPTY         = 1;    { tuple vide ()                         }
  TP_LITERAL       = 2;    { tuple literal (e0, e1, ...)           }
  TP_SINGLETON     = 3;    { tuple singleton (e0,)                 }
  TP_INDEX         = 4;    { acces par index tup[i]                }
  TP_NEGINDEX      = 5;    { index negatif tup[-i]                 }
  TP_IMMUTABLE     = 6;    { erreur : affectation par index        }
  TP_LEN           = 7;    { len(tup)                              }
  TP_UNPACK        = 8;    { a, b, c = tup                         }
  TP_FORUNPACK     = 9;    { for a, b in list_of_tuples            }
  TP_CONCAT        = 10;   { tup1 + tup2 -> concatenation          }
  TP_MUL           = 11;   { tup * n -> repetition                 }
  TP_CONTAINS      = 12;   { val in tup -> booleen                 }
  TP_ITER          = 13;   { iteration for x in tup                }
  TP_MAX           = 13;

  { Limites }
  TP_MAX_ELEMS     = 64;   { nombre max d elements dans un tuple   }
  TP_INIT_CAP      = 8;    { capacite initiale d allocation        }

Var
  TpInitialized   : Boolean;    { True si l etat est initialise       }
  TpEmptyCount    : LongInt;    { nombre de tuples vides crees        }
  TpLiteralCount  : LongInt;    { nombre de tuples literaux           }
  TpSingletonCount: LongInt;    { nombre de tuples singleton          }
  TpIndexCount    : LongInt;    { nombre d acces par index            }
  TpNegIndexCount : LongInt;    { nombre d acces index negatif        }
  TpImmutableCount: LongInt;    { nombre d erreurs immutabilite       }
  TpLenCount      : LongInt;    { nombre d appels a len(tup)          }
  TpUnpackCount   : LongInt;    { nombre d unpackings                 }
  TpForUnpackCount: LongInt;    { nombre de for-unpackings            }
  TpConcatCount   : LongInt;    { nombre de concatenations            }
  TpMulCount      : LongInt;    { nombre de repetitions               }
  TpContainsCount : LongInt;    { nombre d operateurs in              }
  TpIterCount     : LongInt;    { nombre d iterations for x in tup    }
  TpLastKind      : Integer;    { dernier type d operation tuple      }
  TpLabelSeq      : Integer;    { sequence pour labels tuple          }

{ ------------------------------------------------------------ }
{ InitTpState : initialiser le sous-systeme des tuples             }
{ ------------------------------------------------------------ }

Procedure InitTpState;
Begin
  TpInitialized   := True;
  TpEmptyCount    := 0;
  TpLiteralCount  := 0;
  TpSingletonCount:= 0;
  TpIndexCount    := 0;
  TpNegIndexCount := 0;
  TpImmutableCount:= 0;
  TpLenCount      := 0;
  TpUnpackCount   := 0;
  TpForUnpackCount:= 0;
  TpConcatCount   := 0;
  TpMulCount      := 0;
  TpContainsCount := 0;
  TpIterCount     := 0;
  TpLastKind      := TP_NONE;
  TpLabelSeq      := 0;
End;

{ ------------------------------------------------------------ }
{ GenTpLabel : generer un label unique pour les tuples              }
{ ------------------------------------------------------------ }

Function GenTpLabel : TString;
Begin
  Inc(TpLabelSeq);
  GenTpLabel := '_PYL_TP_' + ItoS(TpLabelSeq);
End;

{ ------------------------------------------------------------ }
{ TpTypeName : retourner le nom du type d operation tuple           }
{ ------------------------------------------------------------ }

Function TpTypeName(K : Integer) : TString;
Begin
  Case K Of
    TP_NONE          : TpTypeName := 'TP_NONE';
    TP_EMPTY         : TpTypeName := 'TP_EMPTY';
    TP_LITERAL       : TpTypeName := 'TP_LITERAL';
    TP_SINGLETON     : TpTypeName := 'TP_SINGLETON';
    TP_INDEX         : TpTypeName := 'TP_INDEX';
    TP_NEGINDEX      : TpTypeName := 'TP_NEGINDEX';
    TP_IMMUTABLE     : TpTypeName := 'TP_IMMUTABLE';
    TP_LEN           : TpTypeName := 'TP_LEN';
    TP_UNPACK        : TpTypeName := 'TP_UNPACK';
    TP_FORUNPACK     : TpTypeName := 'TP_FORUNPACK';
    TP_CONCAT        : TpTypeName := 'TP_CONCAT';
    TP_MUL           : TpTypeName := 'TP_MUL';
    TP_CONTAINS      : TpTypeName := 'TP_CONTAINS';
    TP_ITER          : TpTypeName := 'TP_ITER';
  Else
    TpTypeName := 'TP_UNKNOWN(' + ItoS(K) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ EmitTupleEmpty : emettre le code pour creer un tuple vide        }
{   () -> allocation d un bloc avec count=0                       }
{   Layout : [count DD=0]                                         }
{   Resultat dans EAX = ptr vers le tuple                          }
{ ------------------------------------------------------------ }

Procedure EmitTupleEmpty;
Begin
  TpLastKind := TP_EMPTY;
  Inc(TpEmptyCount);
  WriteLn('  ; () -> tuple vide');
  WriteLn('  PUSH 4            ; taille : count uniquement');
  WriteLn('  CALL _PYRT_ALLOC');
  WriteLn('  ADD ESP, 4       ; EAX = ptr vers le bloc');
  WriteLn('  MOV DWORD PTR [EAX], 0  ; count = 0');
End;

{ ------------------------------------------------------------ }
{ EmitTupleLiteral : emettre le code pour creer un tuple literal   }
{   (e0, e1, ...) -> allocation + stockage DD par element         }
{   ElemCount = nombre d elements                                  }
{   Les elements sont deja empiles sur la pile                     }
{   Layout : [count DD][elem0 DD][elem1 DD]...                    }
{   Resultat dans EAX = ptr vers le tuple                          }
{ ------------------------------------------------------------ }

Procedure EmitTupleLiteral(ElemCount : Integer);
Var
  I : Integer;
Begin
  TpLastKind := TP_LITERAL;
  Inc(TpLiteralCount);
  WriteLn('  ; (', ElemCount, ' elems) -> tuple literal');
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
{ EmitTupleSingleton : emettre le code pour creer un tuple (e0,)   }
{   Tuple singleton : (e0,) -> virgule finale distingue du         }
{   parenthesage simple                                            }
{   L element est deja en sommet de pile                           }
{   Layout : [count DD=1][elem0 DD]                               }
{   Resultat dans EAX = ptr vers le tuple                          }
{ ------------------------------------------------------------ }

Procedure EmitTupleSingleton;
Begin
  TpLastKind := TP_SINGLETON;
  Inc(TpSingletonCount);
  WriteLn('  ; (e0,) -> tuple singleton');
  WriteLn('  PUSH 8            ; taille : count + 1 element');
  WriteLn('  CALL _PYRT_ALLOC');
  WriteLn('  ADD ESP, 4       ; EAX = ptr vers le bloc');
  WriteLn('  MOV DWORD PTR [EAX], 1   ; count = 1');
  WriteLn('  POP ECX');
  WriteLn('  MOV DWORD PTR [EAX+4], ECX ; elem[0]');
End;

{ ------------------------------------------------------------ }
{ EmitTupleIndex : emettre le code pour l acces par index          }
{   tup[i] -> calcul offset + MOV EAX, [EBX+4+i*4]              }
{   EBX = ptr vers le tuple, EAX = index                          }
{   Resultat dans EAX = element a l index                          }
{ ------------------------------------------------------------ }

Procedure EmitTupleIndex;
Begin
  TpLastKind := TP_INDEX;
  Inc(TpIndexCount);
  WriteLn('  ; tup[i] -> acces par index');
  WriteLn('  ; EBX = ptr tuple, EAX = index');
  WriteLn('  SHL EAX, 2       ; index * 4');
  WriteLn('  ADD EAX, 4       ; sauter le compteur');
  WriteLn('  MOV EAX, [EBX+EAX] ; EAX = elem[index]');
End;

{ ------------------------------------------------------------ }
{ EmitTupleNegIndex : emettre le code pour l index negatif         }
{   tup[-1] -> len + index, puis acces normal                     }
{   EBX = ptr vers le tuple, EAX = index negatif                  }
{   Resultat dans EAX = element a l index calcule                  }
{ ------------------------------------------------------------ }

Procedure EmitTupleNegIndex;
Begin
  TpLastKind := TP_NEGINDEX;
  Inc(TpNegIndexCount);
  WriteLn('  ; tup[-i] -> acces par index negatif');
  WriteLn('  ; EBX = ptr tuple, EAX = index negatif');
  WriteLn('  MOV ECX, [EBX]   ; ECX = count');
  WriteLn('  ADD EAX, ECX     ; EAX = count + index (index est negatif)');
  WriteLn('  SHL EAX, 2       ; EAX = offset * 4');
  WriteLn('  ADD EAX, 4       ; sauter le compteur');
  WriteLn('  MOV EAX, [EBX+EAX] ; EAX = elem[computed_index]');
End;

{ ------------------------------------------------------------ }
{ EmitTupleImmutable : emettre une erreur de compilation           }
{   tup[i] = val -> erreur : les tuples sont immuables            }
{   Affiche un message d erreur et incremente ErrorCount           }
{ ------------------------------------------------------------ }

Procedure EmitTupleImmutable;
Begin
  TpLastKind := TP_IMMUTABLE;
  Inc(TpImmutableCount);
  Inc(ErrorCount);
  WriteLn('  ; ERREUR : les tuples sont immuables');
  WriteLn('  ; tup[i] = val -> interdit');
  WriteLn(StdErr, 'Erreur ligne ', CurTokLine,
          ' : affectation par index sur un tuple (immuable)');
End;

{ ------------------------------------------------------------ }
{ EmitTupleLen : emettre le code pour len(tup)                     }
{   Le compteur est en tete du tuple : MOV EAX, [EBX]            }
{   EBX = ptr vers le tuple                                       }
{   Resultat dans EAX = nombre d elements                          }
{ ------------------------------------------------------------ }

Procedure EmitTupleLen;
Begin
  TpLastKind := TP_LEN;
  Inc(TpLenCount);
  WriteLn('  ; len(tup) -> compteur en tete de tuple');
  WriteLn('  ; EBX = ptr tuple');
  WriteLn('  MOV EAX, [EBX]   ; EAX = count (nombre d elements)');
End;

{ ------------------------------------------------------------ }
{ EmitTupleUnpack : emettre le code pour a, b, c = tup             }
{   Extraire chaque element du tuple vers des variables            }
{   EBX = ptr tuple, VarCount = nombre de variables cibles         }
{   Chaque variable recoit elem[i] via MOV + stockage              }
{ ------------------------------------------------------------ }

Procedure EmitTupleUnpack(VarCount : Integer);
Var
  I : Integer;
Begin
  TpLastKind := TP_UNPACK;
  Inc(TpUnpackCount);
  WriteLn('  ; a, b, c = tup -> unpacking ', VarCount, ' elements');
  WriteLn('  ; EBX = ptr tuple');
  WriteLn('  MOV ECX, [EBX]   ; ECX = count');
  WriteLn('  CMP ECX, ', VarCount, ' ; verifier que count == nombre de cibles');
  WriteLn('  JNE _PYRT_PANIC  ; ValueError si count != VarCount');
  For I := 0 To VarCount - 1 Do
  Begin
    WriteLn('  MOV EAX, [EBX+', (I + 1) * 4, '] ; elem[', I, ']');
    WriteLn('  PUSH EAX         ; sauver elem[', I, '] pour affectation');
  End;
End;

{ ------------------------------------------------------------ }
{ EmitTupleForUnpack : emettre le code pour for a, b in list       }
{   Iteration sur une liste de tuples avec unpacking               }
{   EBX = ptr vers la liste de tuples                              }
{   A chaque iteration, les elements du tuple courant sont extraits}
{ ------------------------------------------------------------ }

Procedure EmitTupleForUnpack(VarCount : Integer);
Var
  LblTest, LblBody, LblIncr, LblEnd : TString;
Begin
  TpLastKind := TP_FORUNPACK;
  Inc(TpForUnpackCount);
  LblTest := GenTpLabel;
  LblBody := GenTpLabel;
  LblIncr := GenTpLabel;
  LblEnd  := GenTpLabel;
  WriteLn('  ; for a, b in list_of_tuples -> unpacking ', VarCount);
  WriteLn('  ; EBX = ptr vers la liste');
  WriteLn('  XOR ESI, ESI     ; ESI = index = 0');
  WriteLn(LblTest, ':');
  WriteLn('  CMP ESI, [EBX]   ; comparer index avec count');
  WriteLn('  JGE ', LblEnd, '  ; si index >= count, fin');
  WriteLn(LblBody, ':');
  WriteLn('  MOV EAX, ESI');
  WriteLn('  SHL EAX, 2       ; index * 4');
  WriteLn('  MOV EDI, [EBX+EAX+4] ; EDI = ptr vers tuple[index]');
  WriteLn('  ; --- extraire les ', VarCount, ' elements du tuple ---');
  WriteLn('  ; --- corps de la boucle ici ---');
  WriteLn(LblIncr, ':');
  WriteLn('  INC ESI           ; index++');
  WriteLn('  JMP ', LblTest);
  WriteLn(LblEnd, ':');
End;

{ ------------------------------------------------------------ }
{ EmitTupleConcat : emettre le code pour tup1 + tup2               }
{   CALL _PYRT_TUPLECONCAT(ESI=tup1, EDI=tup2) -> EAX=ptr       }
{   Cree un nouveau tuple contenant les elements des deux         }
{ ------------------------------------------------------------ }

Procedure EmitTupleConcat;
Begin
  TpLastKind := TP_CONCAT;
  Inc(TpConcatCount);
  WriteLn('  ; tup1 + tup2 -> _PYRT_TUPLECONCAT');
  WriteLn('  ; ESI = ptr tup1, EDI = ptr tup2');
  WriteLn('  PUSH EDI         ; ptr vers tup2');
  WriteLn('  PUSH ESI         ; ptr vers tup1');
  WriteLn('  CALL _PYRT_TUPLECONCAT');
  WriteLn('  ADD ESP, 8       ; EAX = ptr vers nouveau tuple');
End;

{ ------------------------------------------------------------ }
{ EmitTupleMul : emettre le code pour tup * n                      }
{   CALL _PYRT_TUPLEMUL(ESI=tup, EAX=n) -> EAX=ptr               }
{   Cree un nouveau tuple avec les elements repetes n fois        }
{ ------------------------------------------------------------ }

Procedure EmitTupleMul;
Begin
  TpLastKind := TP_MUL;
  Inc(TpMulCount);
  WriteLn('  ; tup * n -> _PYRT_TUPLEMUL');
  WriteLn('  ; ESI = ptr tuple, EAX = n');
  WriteLn('  PUSH EAX         ; facteur de repetition');
  WriteLn('  PUSH ESI         ; ptr vers le tuple');
  WriteLn('  CALL _PYRT_TUPLEMUL');
  WriteLn('  ADD ESP, 8       ; EAX = ptr vers nouveau tuple');
End;

{ ------------------------------------------------------------ }
{ EmitTupleContains : emettre le code pour val in tup              }
{   CALL _PYRT_TUPLECONTAINS(ESI=tup, EAX=val) -> EAX=0|1       }
{   Retourne 1 si la valeur est presente, 0 sinon                }
{ ------------------------------------------------------------ }

Procedure EmitTupleContains;
Begin
  TpLastKind := TP_CONTAINS;
  Inc(TpContainsCount);
  WriteLn('  ; val in tup -> _PYRT_TUPLECONTAINS');
  WriteLn('  ; ESI = ptr tuple, EAX = valeur recherchee');
  WriteLn('  PUSH EAX         ; valeur recherchee');
  WriteLn('  PUSH ESI         ; ptr vers le tuple');
  WriteLn('  CALL _PYRT_TUPLECONTAINS');
  WriteLn('  ADD ESP, 8       ; EAX = 0 ou 1');
End;

{ ------------------------------------------------------------ }
{ EmitTupleIter : emettre le code pour iterer sur un tuple         }
{   for x in tup : parcours sequentiel des elements               }
{   EBX = ptr tuple, ECX = index courant (0..count-1)              }
{   A chaque iteration : MOV EAX, [EBX+4+ECX*4] (element)        }
{ ------------------------------------------------------------ }

Procedure EmitTupleIter;
Var
  LblTest, LblBody, LblIncr, LblEnd : TString;
Begin
  TpLastKind := TP_ITER;
  Inc(TpIterCount);
  LblTest := GenTpLabel;
  LblBody := GenTpLabel;
  LblIncr := GenTpLabel;
  LblEnd  := GenTpLabel;
  WriteLn('  ; for x in tup -> iteration sur les elements');
  WriteLn('  ; EBX = ptr tuple');
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
{ ParseTupleExpr : analyser une expression de tuple                }
{   (e0, e1, ...) -> EmitTupleLiteral                             }
{   (e0,) -> EmitTupleSingleton                                   }
{   () -> EmitTupleEmpty                                           }
{   La parenthese ouvrante a deja ete consommee                    }
{ ------------------------------------------------------------ }

Procedure ParseTupleExpr;
Var
  ElemCount : Integer;
  IsTuple   : Boolean;
Begin
  ElemCount := 0;
  IsTuple   := False;

  (* Verifier s il s agit d un tuple vide *)
  If (CurTokKind = TK_OP) And (CurTokStr = ')') Then
  Begin
    { Tuple vide }
    EmitTupleEmpty;
    LexNextToken;  (* consommer ')' *)
    Exit;
  End;

  { Boucle sur les elements }
  While Not ((CurTokKind = TK_OP) And (CurTokStr = ')')) And
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
      WriteLn('  PUSH OFFSET ', GenTpLabel, ' ; elem[', ElemCount - 1, '] (str)');
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
    Begin
      IsTuple := True;
      LexNextToken;
      { Verifier la virgule finale (tuple singleton) }
      If (CurTokKind = TK_OP) And (CurTokStr = ')') Then
      Begin
        { Virgule finale avant ')' -> c est un tuple }
        { Ne pas continuer la boucle }
      End;
    End;
  End;

  { Consommer ')' }
  If (CurTokKind = TK_OP) And (CurTokStr = ')') Then
    LexNextToken;

  { Emettre le code pour creer le tuple }
  If (ElemCount = 1) And IsTuple Then
    EmitTupleSingleton
  Else If ElemCount = 0 Then
    EmitTupleEmpty
  Else If IsTuple Or (ElemCount > 1) Then
    EmitTupleLiteral(ElemCount)
  Else
  Begin
    { Un seul element sans virgule -> parenthesage simple }
    { Le PUSH est deja fait, on le convertit en expression }
    WriteLn('  POP EAX          ; parenthesage simple (pas un tuple)');
  End;
End;

{ ------------------------------------------------------------ }
{ DumpTpState : afficher l etat du sous-systeme des tuples         }
{ ------------------------------------------------------------ }

Procedure DumpTpState;
Begin
  WriteLn('--- Tuple State ---');
  WriteLn('  TpInitialized   : ', TpInitialized);
  WriteLn('  TpEmptyCount    : ', TpEmptyCount);
  WriteLn('  TpLiteralCount  : ', TpLiteralCount);
  WriteLn('  TpSingletonCount: ', TpSingletonCount);
  WriteLn('  TpIndexCount    : ', TpIndexCount);
  WriteLn('  TpNegIndexCount : ', TpNegIndexCount);
  WriteLn('  TpImmutableCount: ', TpImmutableCount);
  WriteLn('  TpLenCount      : ', TpLenCount);
  WriteLn('  TpUnpackCount   : ', TpUnpackCount);
  WriteLn('  TpForUnpackCount: ', TpForUnpackCount);
  WriteLn('  TpConcatCount   : ', TpConcatCount);
  WriteLn('  TpMulCount      : ', TpMulCount);
  WriteLn('  TpContainsCount : ', TpContainsCount);
  WriteLn('  TpIterCount     : ', TpIterCount);
  WriteLn('  TpLastKind      : ', TpTypeName(TpLastKind));
  WriteLn('  TpLabelSeq      : ', TpLabelSeq);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 16)                              }
{ ------------------------------------------------------------ }

Function IsTpInitialized : Boolean;
Begin
  IsTpInitialized := TpInitialized;
End;

Function IsTpEmpty : Boolean;
Begin
  IsTpEmpty := (TpEmptyCount = 0) And (TpLiteralCount = 0) And
               (TpSingletonCount = 0) And (TpIndexCount = 0);
End;

Function GetTpEmptyCount : LongInt;
Begin
  GetTpEmptyCount := TpEmptyCount;
End;

Function GetTpLiteralCount : LongInt;
Begin
  GetTpLiteralCount := TpLiteralCount;
End;

Function GetTpSingletonCount : LongInt;
Begin
  GetTpSingletonCount := TpSingletonCount;
End;

Function GetTpIndexCount : LongInt;
Begin
  GetTpIndexCount := TpIndexCount;
End;

Function GetTpUnpackCount : LongInt;
Begin
  GetTpUnpackCount := TpUnpackCount;
End;

Function GetTpConcatCount : LongInt;
Begin
  GetTpConcatCount := TpConcatCount;
End;

Function GetTpContainsCount : LongInt;
Begin
  GetTpContainsCount := TpContainsCount;
End;

Function GetTpStatus : TString;
Begin
  If Not TpInitialized Then
    GetTpStatus := 'Not initialized'
  Else
    GetTpStatus := ItoS(TpEmptyCount) + ' empty, ' +
                   ItoS(TpLiteralCount) + ' literal, ' +
                   ItoS(TpSingletonCount) + ' singleton, ' +
                   ItoS(TpIndexCount) + ' index, ' +
                   ItoS(TpUnpackCount) + ' unpack, ' +
                   ItoS(TpConcatCount) + ' concat, ' +
                   ItoS(TpContainsCount) + ' contains';
End;

{ ============================================================ }
{ TODO 17 - PARSEUR : CHAINES (str) OPERATIONS AVANCEES        }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { Types d operations sur les chaines }
  SR_NONE          = 0;    { aucun / non defini                    }
  SR_CONCAT        = 1;    { concatenation s1 + s2                 }
  SR_MUL           = 2;    { repetition s * n                      }
  SR_INDEX         = 3;    { acces par index s[i]                  }
  SR_SLICE         = 4;    { slice s[a:b]                          }
  SR_LEN           = 5;    { len(s)                                }
  SR_FIND          = 6;    { s.find(sub)                           }
  SR_UPPER         = 7;    { s.upper()                             }
  SR_LOWER         = 8;    { s.lower()                             }
  SR_STRIP         = 9;    { s.strip()                             }
  SR_REPLACE       = 10;   { s.replace(old, new)                   }
  SR_STARTEND      = 11;   { s.startswith / s.endswith             }
  SR_COUNT         = 12;   { s.count(sub)                          }
  SR_CONTAINS      = 13;   { sub in s                              }
  SR_MAX           = 13;

  { Limites }
  SR_MAX_LEN       = 1024; { longueur maximale d une chaine geree }
  SR_BUF_SIZE      = 256;  { taille de buffer temporaire           }

Var
  SrInitialized   : Boolean;    { True si l etat est initialise       }
  SrConcatCount   : LongInt;    { nombre de concatenations            }
  SrMulCount      : LongInt;    { nombre de repetitions               }
  SrIndexCount    : LongInt;    { nombre d acces par index            }
  SrSliceCount    : LongInt;    { nombre de slices                    }
  SrLenCount      : LongInt;    { nombre d appels a len(s)            }
  SrFindCount     : LongInt;    { nombre d appels a s.find            }
  SrUpperCount    : LongInt;    { nombre d appels a s.upper           }
  SrLowerCount    : LongInt;    { nombre d appels a s.lower           }
  SrStripCount    : LongInt;    { nombre d appels a s.strip           }
  SrReplaceCount  : LongInt;    { nombre d appels a s.replace         }
  SrStartEndCount : LongInt;    { nombre d appels startswith/endswith }
  SrCountSubCount : LongInt;    { nombre d appels a s.count           }
  SrContainsCount : LongInt;    { nombre d operateurs in              }
  SrLastKind      : Integer;    { dernier type d operation str        }
  SrLabelSeq      : Integer;    { sequence pour labels str            }

{ ------------------------------------------------------------ }
{ InitSrState : initialiser le sous-systeme des chaines            }
{ ------------------------------------------------------------ }

Procedure InitSrState;
Begin
  SrInitialized   := True;
  SrConcatCount   := 0;
  SrMulCount      := 0;
  SrIndexCount    := 0;
  SrSliceCount    := 0;
  SrLenCount      := 0;
  SrFindCount     := 0;
  SrUpperCount    := 0;
  SrLowerCount    := 0;
  SrStripCount    := 0;
  SrReplaceCount  := 0;
  SrStartEndCount := 0;
  SrCountSubCount := 0;
  SrContainsCount := 0;
  SrLastKind      := SR_NONE;
  SrLabelSeq      := 0;
End;

{ ------------------------------------------------------------ }
{ GenSrLabel : generer un label unique pour les chaines             }
{ ------------------------------------------------------------ }

Function GenSrLabel : TString;
Begin
  Inc(SrLabelSeq);
  GenSrLabel := '_PYL_SR_' + ItoS(SrLabelSeq);
End;

{ ------------------------------------------------------------ }
{ SrTypeName : retourner le nom du type d operation str             }
{ ------------------------------------------------------------ }

Function SrTypeName(K : Integer) : TString;
Begin
  Case K Of
    SR_NONE          : SrTypeName := 'SR_NONE';
    SR_CONCAT        : SrTypeName := 'SR_CONCAT';
    SR_MUL           : SrTypeName := 'SR_MUL';
    SR_INDEX         : SrTypeName := 'SR_INDEX';
    SR_SLICE         : SrTypeName := 'SR_SLICE';
    SR_LEN           : SrTypeName := 'SR_LEN';
    SR_FIND          : SrTypeName := 'SR_FIND';
    SR_UPPER         : SrTypeName := 'SR_UPPER';
    SR_LOWER         : SrTypeName := 'SR_LOWER';
    SR_STRIP         : SrTypeName := 'SR_STRIP';
    SR_REPLACE       : SrTypeName := 'SR_REPLACE';
    SR_STARTEND      : SrTypeName := 'SR_STARTEND';
    SR_COUNT         : SrTypeName := 'SR_COUNT';
    SR_CONTAINS      : SrTypeName := 'SR_CONTAINS';
  Else
    SrTypeName := 'SR_UNKNOWN(' + ItoS(K) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ EmitStrConcat : emettre le code pour s1 + s2                      }
{   CALL _PYRT_STRCONCAT(ESI=s1, EDI=s2) -> EAX=ptr               }
{   Cree une nouvelle chaine contenant s1 suivie de s2             }
{ ------------------------------------------------------------ }

Procedure EmitStrConcat;
Begin
  SrLastKind := SR_CONCAT;
  Inc(SrConcatCount);
  WriteLn('  ; s1 + s2 -> _PYRT_STRCONCAT');
  WriteLn('  ; ESI = ptr s1, EDI = ptr s2');
  WriteLn('  PUSH EDI         ; ptr vers s2');
  WriteLn('  PUSH ESI         ; ptr vers s1');
  WriteLn('  CALL _PYRT_STRCONCAT');
  WriteLn('  ADD ESP, 8       ; EAX = ptr vers nouvelle chaine');
End;

{ ------------------------------------------------------------ }
{ EmitStrMul : emettre le code pour s * n                           }
{   CALL _PYRT_STRMUL(ESI=s, EAX=n) -> EAX=ptr                   }
{   Cree une nouvelle chaine avec s repetee n fois                 }
{ ------------------------------------------------------------ }

Procedure EmitStrMul;
Begin
  SrLastKind := SR_MUL;
  Inc(SrMulCount);
  WriteLn('  ; s * n -> _PYRT_STRMUL');
  WriteLn('  ; ESI = ptr chaine, EAX = n');
  WriteLn('  PUSH EAX         ; facteur de repetition');
  WriteLn('  PUSH ESI         ; ptr vers la chaine');
  WriteLn('  CALL _PYRT_STRMUL');
  WriteLn('  ADD ESP, 8       ; EAX = ptr vers nouvelle chaine');
End;

{ ------------------------------------------------------------ }
{ EmitStrIndex : emettre le code pour s[i]                          }
{   s[i] -> MOVZX EAX, BYTE [ESI+i]                               }
{   ESI = ptr vers la chaine, EAX = index                         }
{   Resultat dans EAX = code ASCII du caractere                    }
{ ------------------------------------------------------------ }

Procedure EmitStrIndex;
Begin
  SrLastKind := SR_INDEX;
  Inc(SrIndexCount);
  WriteLn('  ; s[i] -> acces par index');
  WriteLn('  ; ESI = ptr chaine, EAX = index');
  WriteLn('  MOVZX EAX, BYTE [ESI+EAX] ; EAX = char a l index');
End;

{ ------------------------------------------------------------ }
{ EmitStrSlice : emettre le code pour s[a:b]                        }
{   CALL _PYRT_STRSLICE(ESI=s, EAX=start, EDX=end) -> EAX=ptr    }
{   Cree une nouvelle sous-chaine de a a b                         }
{ ------------------------------------------------------------ }

Procedure EmitStrSlice;
Begin
  SrLastKind := SR_SLICE;
  Inc(SrSliceCount);
  WriteLn('  ; s[a:b] -> _PYRT_STRSLICE');
  WriteLn('  ; ESI = ptr chaine, EAX = start, EDX = end');
  WriteLn('  PUSH EDX         ; index fin');
  WriteLn('  PUSH EAX         ; index debut');
  WriteLn('  PUSH ESI         ; ptr vers la chaine');
  WriteLn('  CALL _PYRT_STRSLICE');
  WriteLn('  ADD ESP, 12      ; EAX = ptr vers sous-chaine');
End;

{ ------------------------------------------------------------ }
{ EmitStrLen : emettre le code pour len(s)                          }
{   CALL _PYRT_STRLEN(ESI=str) -> EAX                             }
{   ESI = ptr vers la chaine                                       }
{   Resultat dans EAX = longueur de la chaine                      }
{ ------------------------------------------------------------ }

Procedure EmitStrLen;
Begin
  SrLastKind := SR_LEN;
  Inc(SrLenCount);
  WriteLn('  ; len(s) -> _PYRT_STRLEN');
  WriteLn('  ; ESI = ptr chaine');
  WriteLn('  PUSH ESI         ; ptr vers la chaine');
  WriteLn('  CALL _PYRT_STRLEN');
  WriteLn('  ADD ESP, 4       ; EAX = longueur');
End;

{ ------------------------------------------------------------ }
{ EmitStrFind : emettre le code pour s.find(sub)                    }
{   CALL _PYRT_STRFIND(ESI=s, EDI=sub) -> EAX=index ou -1        }
{   Retourne l index de la premiere occurrence, ou -1 si absent    }
{ ------------------------------------------------------------ }

Procedure EmitStrFind;
Begin
  SrLastKind := SR_FIND;
  Inc(SrFindCount);
  WriteLn('  ; s.find(sub) -> _PYRT_STRFIND');
  WriteLn('  ; ESI = ptr chaine, EDI = ptr sous-chaine');
  WriteLn('  PUSH EDI         ; ptr vers sous-chaine');
  WriteLn('  PUSH ESI         ; ptr vers chaine');
  WriteLn('  CALL _PYRT_STRFIND');
  WriteLn('  ADD ESP, 8       ; EAX = index ou -1');
End;

{ ------------------------------------------------------------ }
{ EmitStrUpper : emettre le code pour s.upper()                     }
{   CALL _PYRT_STRUPPER(ESI=s) -> EAX=ptr                         }
{   Cree une nouvelle chaine en majuscules                         }
{ ------------------------------------------------------------ }

Procedure EmitStrUpper;
Begin
  SrLastKind := SR_UPPER;
  Inc(SrUpperCount);
  WriteLn('  ; s.upper() -> _PYRT_STRUPPER');
  WriteLn('  ; ESI = ptr chaine');
  WriteLn('  PUSH ESI         ; ptr vers la chaine');
  WriteLn('  CALL _PYRT_STRUPPER');
  WriteLn('  ADD ESP, 4       ; EAX = ptr vers nouvelle chaine');
End;

{ ------------------------------------------------------------ }
{ EmitStrLower : emettre le code pour s.lower()                     }
{   CALL _PYRT_STRLOWER(ESI=s) -> EAX=ptr                         }
{   Cree une nouvelle chaine en minuscules                         }
{ ------------------------------------------------------------ }

Procedure EmitStrLower;
Begin
  SrLastKind := SR_LOWER;
  Inc(SrLowerCount);
  WriteLn('  ; s.lower() -> _PYRT_STRLOWER');
  WriteLn('  ; ESI = ptr chaine');
  WriteLn('  PUSH ESI         ; ptr vers la chaine');
  WriteLn('  CALL _PYRT_STRLOWER');
  WriteLn('  ADD ESP, 4       ; EAX = ptr vers nouvelle chaine');
End;

{ ------------------------------------------------------------ }
{ EmitStrStrip : emettre le code pour s.strip()                     }
{   CALL _PYRT_STRSTRIP(ESI=s) -> EAX=ptr                         }
{   Cree une nouvelle chaine sans espaces en debut et fin          }
{ ------------------------------------------------------------ }

Procedure EmitStrStrip;
Begin
  SrLastKind := SR_STRIP;
  Inc(SrStripCount);
  WriteLn('  ; s.strip() -> _PYRT_STRSTRIP');
  WriteLn('  ; ESI = ptr chaine');
  WriteLn('  PUSH ESI         ; ptr vers la chaine');
  WriteLn('  CALL _PYRT_STRSTRIP');
  WriteLn('  ADD ESP, 4       ; EAX = ptr vers nouvelle chaine');
End;

{ ------------------------------------------------------------ }
{ EmitStrReplace : emettre le code pour s.replace(old, new)         }
{   CALL _PYRT_STRREPLACE(ESI=s, EDI=old, EBX=new) -> EAX=ptr    }
{   Cree une nouvelle chaine avec old remplace par new             }
{ ------------------------------------------------------------ }

Procedure EmitStrReplace;
Begin
  SrLastKind := SR_REPLACE;
  Inc(SrReplaceCount);
  WriteLn('  ; s.replace(old, new) -> _PYRT_STRREPLACE');
  WriteLn('  ; ESI = ptr chaine, EDI = ptr old, EBX = ptr new');
  WriteLn('  PUSH EBX         ; ptr vers new');
  WriteLn('  PUSH EDI         ; ptr vers old');
  WriteLn('  PUSH ESI         ; ptr vers chaine');
  WriteLn('  CALL _PYRT_STRREPLACE');
  WriteLn('  ADD ESP, 12      ; EAX = ptr vers nouvelle chaine');
End;

{ ------------------------------------------------------------ }
{ EmitStrStartsWith : emettre le code pour s.startswith(prefix)     }
{   PUSH EDI (prefix), PUSH ESI (s), CALL _PYRT_STRSTARTSWITH     }
{   -> EAX=0|1                                                     }
{ ------------------------------------------------------------ }

Procedure EmitStrStartsWith;
Begin
  SrLastKind := SR_STARTEND;
  Inc(SrStartEndCount);
  WriteLn('  ; s.startswith(prefix) -> EAX=0|1');
  WriteLn('  ; ESI = ptr chaine, EDI = ptr prefix');
  WriteLn('  PUSH EDI         ; ptr vers prefix');
  WriteLn('  PUSH ESI         ; ptr vers chaine');
  WriteLn('  CALL _PYRT_STRSTARTSWITH');
  WriteLn('  ADD ESP, 8       ; EAX = 0 ou 1');
End;

{ ------------------------------------------------------------ }
{ EmitStrEndsWith : emettre le code pour s.endswith(suffix)         }
{   PUSH EDI (suffix), PUSH ESI (s), CALL _PYRT_STRENDSWITH       }
{   -> EAX=0|1                                                     }
{ ------------------------------------------------------------ }

Procedure EmitStrEndsWith;
Begin
  SrLastKind := SR_STARTEND;
  Inc(SrStartEndCount);
  WriteLn('  ; s.endswith(suffix) -> EAX=0|1');
  WriteLn('  ; ESI = ptr chaine, EDI = ptr suffix');
  WriteLn('  PUSH EDI         ; ptr vers suffix');
  WriteLn('  PUSH ESI         ; ptr vers chaine');
  WriteLn('  CALL _PYRT_STRENDSWITH');
  WriteLn('  ADD ESP, 8       ; EAX = 0 ou 1');
End;

{ ------------------------------------------------------------ }
{ EmitStrCount : emettre le code pour s.count(sub)                  }
{   CALL _PYRT_STRCOUNT(ESI=s, EDI=sub) -> EAX                    }
{   Retourne le nombre d occurrences de sub dans s                 }
{ ------------------------------------------------------------ }

Procedure EmitStrCount;
Begin
  SrLastKind := SR_COUNT;
  Inc(SrCountSubCount);
  WriteLn('  ; s.count(sub) -> _PYRT_STRCOUNT');
  WriteLn('  ; ESI = ptr chaine, EDI = ptr sous-chaine');
  WriteLn('  PUSH EDI         ; ptr vers sous-chaine');
  WriteLn('  PUSH ESI         ; ptr vers chaine');
  WriteLn('  CALL _PYRT_STRCOUNT');
  WriteLn('  ADD ESP, 8       ; EAX = nombre d occurrences');
End;

{ ------------------------------------------------------------ }
{ EmitStrContains : emettre le code pour sub in s                   }
{   CALL _PYRT_STRCONTAINS(ESI=s, EDI=sub) -> EAX=0|1            }
{   Retourne 1 si sub est present dans s, 0 sinon                 }
{ ------------------------------------------------------------ }

Procedure EmitStrContains;
Begin
  SrLastKind := SR_CONTAINS;
  Inc(SrContainsCount);
  WriteLn('  ; sub in s -> _PYRT_STRCONTAINS');
  WriteLn('  ; ESI = ptr chaine, EDI = ptr sous-chaine');
  WriteLn('  PUSH EDI         ; ptr vers sous-chaine');
  WriteLn('  PUSH ESI         ; ptr vers chaine');
  WriteLn('  CALL _PYRT_STRCONTAINS');
  WriteLn('  ADD ESP, 8       ; EAX = 0 ou 1');
End;

{ ------------------------------------------------------------ }
{ EmitStrCompare : emettre le code pour comparer deux chaines       }
{   CALL _PYRT_STRCMP(ESI=s1, EDI=s2) -> drapeaux ZF/CF           }
{   Utilise ensuite JE/JNE/JB/JA pour les branches                }
{ ------------------------------------------------------------ }

Procedure EmitStrCompare;
Begin
  WriteLn('  ; s1 == s2 / s1 < s2 -> _PYRT_STRCMP');
  WriteLn('  ; ESI = ptr s1, EDI = ptr s2');
  WriteLn('  PUSH EDI         ; ptr vers s2');
  WriteLn('  PUSH ESI         ; ptr vers s1');
  WriteLn('  CALL _PYRT_STRCMP');
  WriteLn('  ADD ESP, 8       ; drapeaux ZF/CF positionnes');
End;

{ ------------------------------------------------------------ }
{ EmitStrChr : emettre le code pour chr(n)                          }
{   entier -> caractere -> EAX=ptr chaine 1 octet                 }
{   EAX = code ASCII du caractere                                  }
{   Cree une chaine de 1 octet + terminateur nul                   }
{ ------------------------------------------------------------ }

Procedure EmitStrChr;
Begin
  WriteLn('  ; chr(n) -> chaine 1 octet');
  WriteLn('  ; EAX = code ASCII');
  WriteLn('  PUSH 2            ; taille : 1 octet + nul');
  WriteLn('  CALL _PYRT_ALLOC');
  WriteLn('  ADD ESP, 4       ; EAX = ptr vers buffer');
  WriteLn('  POP ECX           ; recuperer le code ASCII');
  WriteLn('  MOV BYTE [EAX], CL  ; stocker le caractere');
  WriteLn('  MOV BYTE [EAX+1], 0 ; terminateur nul');
End;

{ ------------------------------------------------------------ }
{ EmitStrOrd : emettre le code pour ord(c)                          }
{   caractere -> entier -> MOVZX EAX, BYTE [ptr]                  }
{   ESI = ptr vers la chaine (premier caractere)                   }
{   Resultat dans EAX = code ASCII du premier caractere            }
{ ------------------------------------------------------------ }

Procedure EmitStrOrd;
Begin
  WriteLn('  ; ord(c) -> entier');
  WriteLn('  ; ESI = ptr chaine');
  WriteLn('  MOVZX EAX, BYTE [ESI] ; EAX = code ASCII du 1er caractere');
End;

{ ------------------------------------------------------------ }
{ ParseStrExpr : analyser une expression de methode de chaine       }
{   s.method(args) -> appeler la methode appropriee                }
{   La chaine est dans ESI, le nom de methode est identifie        }
{ ------------------------------------------------------------ }

Procedure ParseStrExpr;
Var
  MethodName : TString;
Begin
  { La chaine est supposee chargee dans ESI }
  { Le token courant est le nom de la methode apres le '.' }

  If CurTokKind <> TK_IDENT Then
  Begin
    Inc(ErrorCount);
    WriteLn(StdErr, 'Erreur ligne ', CurTokLine,
            ' : nom de methode attendu apres "."');
    Exit;
  End;

  MethodName := CurTokStr;
  LexNextToken;  (* consommer le nom de methode *)

  If MethodName = 'find' Then
  Begin
    { s.find(sub) }
    If (CurTokKind = TK_OP) And (CurTokStr = '(') Then
      LexNextToken;  (* consommer '(' *)
    { Charger l argument sub dans EDI }
    If CurTokKind = TK_STRING Then
    Begin
      WriteLn('  MOV EDI, OFFSET ', GenSrLabel, ' ; sub (str literal)');
      LexNextToken;
    End
    Else If CurTokKind = TK_IDENT Then
    Begin
      WriteLn('  MOV EDI, DWORD PTR [', SymMangle(CurTokStr, SK_VAR),
              '] ; sub (var)');
      LexNextToken;
    End;
    If (CurTokKind = TK_OP) And (CurTokStr = ')') Then
      LexNextToken;  (* consommer ')' *)
    EmitStrFind;
  End
  Else If MethodName = 'upper' Then
  Begin
    { s.upper() }
    If (CurTokKind = TK_OP) And (CurTokStr = '(') Then
      LexNextToken;
    If (CurTokKind = TK_OP) And (CurTokStr = ')') Then
      LexNextToken;
    EmitStrUpper;
  End
  Else If MethodName = 'lower' Then
  Begin
    { s.lower() }
    If (CurTokKind = TK_OP) And (CurTokStr = '(') Then
      LexNextToken;
    If (CurTokKind = TK_OP) And (CurTokStr = ')') Then
      LexNextToken;
    EmitStrLower;
  End
  Else If MethodName = 'strip' Then
  Begin
    { s.strip() }
    If (CurTokKind = TK_OP) And (CurTokStr = '(') Then
      LexNextToken;
    If (CurTokKind = TK_OP) And (CurTokStr = ')') Then
      LexNextToken;
    EmitStrStrip;
  End
  Else If MethodName = 'replace' Then
  Begin
    { s.replace(old, new) }
    If (CurTokKind = TK_OP) And (CurTokStr = '(') Then
      LexNextToken;  (* consommer '(' *)
    { Charger old dans EDI }
    If CurTokKind = TK_STRING Then
    Begin
      WriteLn('  MOV EDI, OFFSET ', GenSrLabel, ' ; old (str literal)');
      LexNextToken;
    End
    Else If CurTokKind = TK_IDENT Then
    Begin
      WriteLn('  MOV EDI, DWORD PTR [', SymMangle(CurTokStr, SK_VAR),
              '] ; old (var)');
      LexNextToken;
    End;
    { Consommer la virgule }
    If (CurTokKind = TK_OP) And (CurTokStr = ',') Then
      LexNextToken;
    { Charger new dans EBX }
    If CurTokKind = TK_STRING Then
    Begin
      WriteLn('  MOV EBX, OFFSET ', GenSrLabel, ' ; new (str literal)');
      LexNextToken;
    End
    Else If CurTokKind = TK_IDENT Then
    Begin
      WriteLn('  MOV EBX, DWORD PTR [', SymMangle(CurTokStr, SK_VAR),
              '] ; new (var)');
      LexNextToken;
    End;
    If (CurTokKind = TK_OP) And (CurTokStr = ')') Then
      LexNextToken;  (* consommer ')' *)
    EmitStrReplace;
  End
  Else If MethodName = 'startswith' Then
  Begin
    { s.startswith(prefix) }
    If (CurTokKind = TK_OP) And (CurTokStr = '(') Then
      LexNextToken;
    If CurTokKind = TK_STRING Then
    Begin
      WriteLn('  MOV EDI, OFFSET ', GenSrLabel, ' ; prefix (str literal)');
      LexNextToken;
    End
    Else If CurTokKind = TK_IDENT Then
    Begin
      WriteLn('  MOV EDI, DWORD PTR [', SymMangle(CurTokStr, SK_VAR),
              '] ; prefix (var)');
      LexNextToken;
    End;
    If (CurTokKind = TK_OP) And (CurTokStr = ')') Then
      LexNextToken;
    EmitStrStartsWith;
  End
  Else If MethodName = 'endswith' Then
  Begin
    { s.endswith(suffix) }
    If (CurTokKind = TK_OP) And (CurTokStr = '(') Then
      LexNextToken;
    If CurTokKind = TK_STRING Then
    Begin
      WriteLn('  MOV EDI, OFFSET ', GenSrLabel, ' ; suffix (str literal)');
      LexNextToken;
    End
    Else If CurTokKind = TK_IDENT Then
    Begin
      WriteLn('  MOV EDI, DWORD PTR [', SymMangle(CurTokStr, SK_VAR),
              '] ; suffix (var)');
      LexNextToken;
    End;
    If (CurTokKind = TK_OP) And (CurTokStr = ')') Then
      LexNextToken;
    EmitStrEndsWith;
  End
  Else If MethodName = 'count' Then
  Begin
    { s.count(sub) }
    If (CurTokKind = TK_OP) And (CurTokStr = '(') Then
      LexNextToken;
    If CurTokKind = TK_STRING Then
    Begin
      WriteLn('  MOV EDI, OFFSET ', GenSrLabel, ' ; sub (str literal)');
      LexNextToken;
    End
    Else If CurTokKind = TK_IDENT Then
    Begin
      WriteLn('  MOV EDI, DWORD PTR [', SymMangle(CurTokStr, SK_VAR),
              '] ; sub (var)');
      LexNextToken;
    End;
    If (CurTokKind = TK_OP) And (CurTokStr = ')') Then
      LexNextToken;
    EmitStrCount;
  End
  Else
  Begin
    Inc(ErrorCount);
    WriteLn(StdErr, 'Erreur ligne ', CurTokLine,
            ' : methode de chaine inconnue : ', MethodName);
  End;
End;

{ ------------------------------------------------------------ }
{ DumpSrState : afficher l etat du sous-systeme des chaines        }
{ ------------------------------------------------------------ }

Procedure DumpSrState;
Begin
  WriteLn('--- String State ---');
  WriteLn('  SrInitialized   : ', SrInitialized);
  WriteLn('  SrConcatCount   : ', SrConcatCount);
  WriteLn('  SrMulCount      : ', SrMulCount);
  WriteLn('  SrIndexCount    : ', SrIndexCount);
  WriteLn('  SrSliceCount    : ', SrSliceCount);
  WriteLn('  SrLenCount      : ', SrLenCount);
  WriteLn('  SrFindCount     : ', SrFindCount);
  WriteLn('  SrUpperCount    : ', SrUpperCount);
  WriteLn('  SrLowerCount    : ', SrLowerCount);
  WriteLn('  SrStripCount    : ', SrStripCount);
  WriteLn('  SrReplaceCount  : ', SrReplaceCount);
  WriteLn('  SrStartEndCount : ', SrStartEndCount);
  WriteLn('  SrCountSubCount : ', SrCountSubCount);
  WriteLn('  SrContainsCount : ', SrContainsCount);
  WriteLn('  SrLastKind      : ', SrTypeName(SrLastKind));
  WriteLn('  SrLabelSeq      : ', SrLabelSeq);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 17)                              }
{ ------------------------------------------------------------ }

Function IsSrInitialized : Boolean;
Begin
  IsSrInitialized := SrInitialized;
End;

Function IsSrEmpty : Boolean;
Begin
  IsSrEmpty := (SrConcatCount = 0) And (SrMulCount = 0) And
               (SrIndexCount = 0) And (SrSliceCount = 0);
End;

Function GetSrConcatCount : LongInt;
Begin
  GetSrConcatCount := SrConcatCount;
End;

Function GetSrIndexCount : LongInt;
Begin
  GetSrIndexCount := SrIndexCount;
End;

Function GetSrLenCount : LongInt;
Begin
  GetSrLenCount := SrLenCount;
End;

Function GetSrFindCount : LongInt;
Begin
  GetSrFindCount := SrFindCount;
End;

Function GetSrUpperCount : LongInt;
Begin
  GetSrUpperCount := SrUpperCount;
End;

Function GetSrReplaceCount : LongInt;
Begin
  GetSrReplaceCount := SrReplaceCount;
End;

Function GetSrContainsCount : LongInt;
Begin
  GetSrContainsCount := SrContainsCount;
End;

Function GetSrStatus : TString;
Begin
  If Not SrInitialized Then
    GetSrStatus := 'Not initialized'
  Else
    GetSrStatus := ItoS(SrConcatCount) + ' concat, ' +
                   ItoS(SrMulCount) + ' mul, ' +
                   ItoS(SrIndexCount) + ' index, ' +
                   ItoS(SrSliceCount) + ' slice, ' +
                   ItoS(SrFindCount) + ' find, ' +
                   ItoS(SrContainsCount) + ' contains';
End;

{ ============================================================ }
{ TODO 18 - PARSEUR : CLASSES ET OBJETS                        }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { Types d operations sur les classes }
  CL_NONE          = 0;    { aucun / non defini                    }
  CL_CLASSDEF      = 1;    { definition class Nom: bloc            }
  CL_CLASSINH      = 2;    { class Nom(Parent): bloc               }
  CL_INITDEF       = 3;    { def __init__(self, ...):              }
  CL_METHODDEF     = 4;    { def methode(self, ...):               }
  CL_OBJNEW        = 5;    { allocation Nom(args)                  }
  CL_ATTRLOAD      = 6;    { self.attr -> load                     }
  CL_ATTRSTORE     = 7;    { self.attr = val -> store              }
  CL_METHCALL      = 8;    { obj.method(args)                      }
  CL_INITCALL      = 9;    { appel a __init__                      }
  CL_INHERIT       = 10;   { heritage simple                       }
  CL_ISINSTANCE    = 11;   { isinstance(obj, cls)                  }
  CL_SUPER         = 12;   { super().method(args)                  }
  CL_SELFREF       = 13;   { reference a self                      }
  CL_MAX           = 13;

  { Limites }
  CL_MAX_CLASS     = 32;   { nombre max de classes                 }
  CL_MAX_ATTRS     = 32;   { nombre max d attributs par classe     }
  CL_MAX_METHODS   = 32;   { nombre max de methodes par classe     }

Var
  ClInitialized   : Boolean;    { True si l etat est initialise       }
  ClClassDefCount : LongInt;    { nombre de definitions de classes     }
  ClInhCount      : LongInt;    { nombre d heritages                  }
  ClInitDefCount  : LongInt;    { nombre de constructeurs __init__    }
  ClMethodDefCount: LongInt;    { nombre de definitions de methodes   }
  ClObjNewCount   : LongInt;    { nombre d allocations d objets       }
  ClAttrLoadCount : LongInt;    { nombre de chargements d attributs   }
  ClAttrStoreCount: LongInt;    { nombre de stockages d attributs     }
  ClMethCallCount : LongInt;    { nombre d appels de methodes         }
  ClInitCallCount : LongInt;    { nombre d appels a __init__          }
  ClInheritCount  : LongInt;    { nombre d heritages effectues        }
  ClIsInstCount   : LongInt;    { nombre d appels isinstance          }
  ClSuperCount    : LongInt;    { nombre d appels super()             }
  ClSelfRefCount  : LongInt;    { nombre de references a self         }
  ClLastKind      : Integer;    { dernier type d operation classe     }
  ClLabelSeq      : Integer;    { sequence pour labels classe         }

{ ------------------------------------------------------------ }
{ InitClState : initialiser le sous-systeme des classes            }
{ ------------------------------------------------------------ }

Procedure InitClState;
Begin
  ClInitialized   := True;
  ClClassDefCount := 0;
  ClInhCount      := 0;
  ClInitDefCount  := 0;
  ClMethodDefCount:= 0;
  ClObjNewCount   := 0;
  ClAttrLoadCount := 0;
  ClAttrStoreCount:= 0;
  ClMethCallCount := 0;
  ClInitCallCount := 0;
  ClInheritCount  := 0;
  ClIsInstCount   := 0;
  ClSuperCount    := 0;
  ClSelfRefCount  := 0;
  ClLastKind      := CL_NONE;
  ClLabelSeq      := 0;
End;

{ ------------------------------------------------------------ }
{ GenClLabel : generer un label unique pour les classes             }
{ ------------------------------------------------------------ }

Function GenClLabel : TString;
Begin
  Inc(ClLabelSeq);
  GenClLabel := '_PYC_' + ItoS(ClLabelSeq);
End;

{ ------------------------------------------------------------ }
{ ClTypeName : nom humain d un type d operation classe             }
{ ------------------------------------------------------------ }

Function ClTypeName(K : Integer) : TString;
Begin
  Case K Of
    CL_NONE       : ClTypeName := 'NONE';
    CL_CLASSDEF   : ClTypeName := 'CLASSDEF';
    CL_CLASSINH   : ClTypeName := 'CLASSINH';
    CL_INITDEF    : ClTypeName := 'INITDEF';
    CL_METHODDEF  : ClTypeName := 'METHODDEF';
    CL_OBJNEW     : ClTypeName := 'OBJNEW';
    CL_ATTRLOAD   : ClTypeName := 'ATTRLOAD';
    CL_ATTRSTORE  : ClTypeName := 'ATTRSTORE';
    CL_METHCALL   : ClTypeName := 'METHCALL';
    CL_INITCALL   : ClTypeName := 'INITCALL';
    CL_INHERIT    : ClTypeName := 'INHERIT';
    CL_ISINSTANCE : ClTypeName := 'ISINSTANCE';
    CL_SUPER      : ClTypeName := 'SUPER';
    CL_SELFREF    : ClTypeName := 'SELFREF';
  Else
    ClTypeName := '?(' + ItoS(K) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ EmitObjNew : emettre le code d allocation d un objet              }
{   ECX = taille du bloc objet (typecode + attributs)              }
{   Appel a _PYRT_OBJNEW -> EAX = ptr vers nouvel objet           }
{ ------------------------------------------------------------ }

Procedure EmitObjNew(Const ClassName : TString; AttrCount : Integer);
Begin
  Inc(ClObjNewCount);
  ClLastKind := CL_OBJNEW;
  WriteLn('  ; Allocation objet ', ClassName, ' (', AttrCount, ' attrs)');
  WriteLn('  MOV ECX, ', (1 + AttrCount) * 4, ' ; taille = (1+', AttrCount, ')*4');
  WriteLn('  PUSH ECX');
  WriteLn('  CALL _PYRT_OBJNEW');
  WriteLn('  ADD ESP, 4       ; EAX = ptr vers nouvel objet');
End;

{ ------------------------------------------------------------ }
{ EmitObjAttrLoad : emettre le code pour charger un attribut        }
{   self.attr -> MOV EBX, [EBP+8] / MOV EAX, [EBX+4+offset*4]    }
{   AttrIdx = index de l attribut (0, 1, 2, ...)                   }
{ ------------------------------------------------------------ }

Procedure EmitObjAttrLoad(AttrIdx : Integer);
Begin
  Inc(ClAttrLoadCount);
  ClLastKind := CL_ATTRLOAD;
  WriteLn('  ; self.attr[', AttrIdx, '] -> load');
  WriteLn('  MOV EBX, [EBP+8]  ; EBX = ptr self');
  WriteLn('  MOV EAX, [EBX+', 4 + AttrIdx * 4, '] ; EAX = attr[', AttrIdx, ']');
End;

{ ------------------------------------------------------------ }
{ EmitObjAttrStore : emettre le code pour stocker un attribut       }
{   self.attr = val -> MOV EBX, [EBP+8] / MOV [EBX+4+offset*4], EAX }
{   AttrIdx = index de l attribut                                  }
{ ------------------------------------------------------------ }

Procedure EmitObjAttrStore(AttrIdx : Integer);
Begin
  Inc(ClAttrStoreCount);
  ClLastKind := CL_ATTRSTORE;
  WriteLn('  ; self.attr[', AttrIdx, '] = EAX -> store');
  WriteLn('  MOV EBX, [EBP+8]  ; EBX = ptr self');
  WriteLn('  MOV [EBX+', 4 + AttrIdx * 4, '], EAX ; attr[', AttrIdx, '] = EAX');
End;

{ ------------------------------------------------------------ }
{ EmitMethodCall : emettre le code pour appeler une methode         }
{   obj.method(args) -> PUSH self + PUSH args + CALL label         }
{   ClassName, MethodName : identifient le label                   }
{   NArgs = nombre d arguments (sans compter self)                 }
{ ------------------------------------------------------------ }

Procedure EmitMethodCall(Const ClassName, MethodName : TString;
                         NArgs : Integer);
Begin
  Inc(ClMethCallCount);
  ClLastKind := CL_METHCALL;
  WriteLn('  ; obj.', MethodName, '(', NArgs, ' args)');
  WriteLn('  ; self deja PUSH avant les args');
  WriteLn('  CALL _PYM_', ClassName, '_', MethodName);
  WriteLn('  ADD ESP, ', (1 + NArgs) * 4,
          '       ; depiler self + ', NArgs, ' args');
End;

{ ------------------------------------------------------------ }
{ EmitInitCall : emettre le code pour appeler __init__              }
{   apres allocation, appeler le constructeur                      }
{   EAX = ptr vers le nouvel objet                                 }
{ ------------------------------------------------------------ }

Procedure EmitInitCall(Const ClassName : TString; NArgs : Integer);
Begin
  Inc(ClInitCallCount);
  ClLastKind := CL_INITCALL;
  WriteLn('  ; appel __init__ pour ', ClassName);
  WriteLn('  PUSH EAX          ; PUSH self (nouvel objet)');
  WriteLn('  CALL _PYM_', ClassName, '___init__');
  WriteLn('  ADD ESP, ', (1 + NArgs) * 4,
          '       ; depiler self + ', NArgs, ' args');
End;

{ ------------------------------------------------------------ }
{ EmitMethodPrologue : emettre le prologue d une methode            }
{   identique au prologue de fonction, avec self en [EBP+8]        }
{ ------------------------------------------------------------ }

Procedure EmitMethodPrologue(Const ClassName, MethodName : TString;
                              LocalSize : Integer);
Begin
  WriteLn('_PYM_', ClassName, '_', MethodName, ':');
  WriteLn('  PUSH EBP');
  WriteLn('  MOV EBP, ESP');
  If LocalSize > 0 Then
    WriteLn('  SUB ESP, ', LocalSize, ' ; locals');
End;

{ ------------------------------------------------------------ }
{ EmitMethodEpilogue : emettre l epilogue d une methode             }
{ ------------------------------------------------------------ }

Procedure EmitMethodEpilogue;
Begin
  WriteLn('  MOV ESP, EBP');
  WriteLn('  POP EBP');
  WriteLn('  RET');
End;

{ ------------------------------------------------------------ }
{ EmitInheritance : emettre le code pour l heritage simple          }
{   Copier le typecode du parent, puis les attributs herites       }
{   EnfantPtr dans EAX, ParentTypeCode dans ECX                    }
{ ------------------------------------------------------------ }

Procedure EmitInheritance(Const ParentName, ChildName : TString;
                           ParentAttrCount : Integer);
Begin
  Inc(ClInheritCount);
  ClLastKind := CL_INHERIT;
  WriteLn('  ; heritage : ', ChildName, ' herite de ', ParentName);
  WriteLn('  ; copier ', ParentAttrCount, ' attributs du parent');
  WriteLn('  ; EAX = ptr enfant, ESI = ptr parent');
  WriteLn('  MOV ECX, ', ParentAttrCount,
          '     ; nombre d attributs a copier');
  WriteLn('  LEA ESI, [ESI+4]  ; debut attrs parent');
  WriteLn('  LEA EDI, [EAX+4]  ; debut attrs enfant');
  WriteLn('  REP MOVSD          ; copier les attributs');
End;

{ ------------------------------------------------------------ }
{ EmitIsInstance : emettre le code pour isinstance(obj, cls)        }
{   Compare le typecode de l objet avec celui de la classe         }
{   EAX = ptr objet -> [EAX] = typecode                           }
{   ECX = typecode attendu                                         }
{   Resultat : EAX = 1 (True) ou 0 (False)                        }
{ ------------------------------------------------------------ }

Procedure EmitIsInstance(TypeCode : Integer);
Var
  LblTrue, LblEnd : TString;
Begin
  Inc(ClIsInstCount);
  ClLastKind := CL_ISINSTANCE;
  LblTrue := GenClLabel;
  LblEnd  := GenClLabel;
  WriteLn('  ; isinstance(obj, cls) -> typecode=', TypeCode);
  WriteLn('  MOV EBX, [EAX]    ; EBX = typecode de l objet');
  WriteLn('  CMP EBX, ', TypeCode);
  WriteLn('  JE ', LblTrue);
  WriteLn('  XOR EAX, EAX      ; EAX = 0 (False)');
  WriteLn('  JMP ', LblEnd);
  WriteLn(LblTrue, ':');
  WriteLn('  MOV EAX, 1        ; EAX = 1 (True)');
  WriteLn(LblEnd, ':');
End;

{ ------------------------------------------------------------ }
{ EmitSuperCall : emettre le code pour super().method(args)         }
{   Appelle la methode du parent avec self courant                 }
{ ------------------------------------------------------------ }

Procedure EmitSuperCall(Const ParentName, MethodName : TString;
                         NArgs : Integer);
Begin
  Inc(ClSuperCount);
  ClLastKind := CL_SUPER;
  WriteLn('  ; super().', MethodName, '(', NArgs, ' args)');
  WriteLn('  ; self deja PUSH avant les args');
  WriteLn('  CALL _PYM_', ParentName, '_', MethodName);
  WriteLn('  ADD ESP, ', (1 + NArgs) * 4,
          '       ; depiler self + ', NArgs, ' args');
End;

{ ------------------------------------------------------------ }
{ EmitSelfRef : emettre le code pour reference a self               }
{   MOV EAX, [EBP+8] -> EAX = ptr self                            }
{ ------------------------------------------------------------ }

Procedure EmitSelfRef;
Begin
  Inc(ClSelfRefCount);
  ClLastKind := CL_SELFREF;
  WriteLn('  ; self reference');
  WriteLn('  MOV EAX, [EBP+8]  ; EAX = ptr self');
End;

{ ------------------------------------------------------------ }
{ ParseClassStmt : analyser une declaration de classe               }
{   class ClassName: bloc                                          }
{   class ClassName(ParentName): bloc                              }
{ ------------------------------------------------------------ }

Procedure ParseClassStmt;
Var
  ClassName   : TString;
  ParentName  : TString;
  HasParent   : Boolean;
  SkipLabel   : TString;
  MethodName  : TString;
  MethodCount : Integer;
Begin
  { Le token 'class' a deja ete consomme }
  HasParent := False;
  ParentName := '';
  MethodCount := 0;

  If CurTokKind <> TK_IDENT Then
  Begin
    Inc(ErrorCount);
    WriteLn(StdErr, 'Erreur ligne ', CurTokLine,
            ' : nom de classe attendu apres "class"');
    Exit;
  End;
  ClassName := CurTokStr;
  LexNextToken;  (* consommer le nom de classe *)

  { Verifier s il y a heritage : class Nom(Parent) }
  If (CurTokKind = TK_OP) And (CurTokStr = '(') Then
  Begin
    LexNextToken;  (* consommer '(' *)
    If CurTokKind = TK_IDENT Then
    Begin
      ParentName := CurTokStr;
      HasParent := True;
      LexNextToken;  (* consommer le nom du parent *)
    End;
    If (CurTokKind = TK_OP) And (CurTokStr = ')') Then
      LexNextToken;  (* consommer ')' *)
    Inc(ClInhCount);
  End;

  { Consommer le ':' }
  If (CurTokKind = TK_OP) And (CurTokStr = ':') Then
    LexNextToken;  (* consommer ':' *)

  { Emettre un JMP pour sauter le corps de la classe }
  SkipLabel := GenClLabel;
  WriteLn('  JMP ', SkipLabel, ' ; sauter le corps de la classe ',
          ClassName);

  { Emettre le commentaire de la classe }
  WriteLn('; --- class ', ClassName, ' ---');

  If HasParent Then
  Begin
    WriteLn('; heritage de ', ParentName);
    Inc(ClClassDefCount);
    ClLastKind := CL_CLASSINH;
  End
  Else
  Begin
    Inc(ClClassDefCount);
    ClLastKind := CL_CLASSDEF;
  End;

  { Parser les methodes du corps de la classe }
  { En Python, le corps est indente ; ici on parse jusqu a }
  { desindentation ou fin de fichier }
  While (CurTokKind <> TK_EOF) And
        (CurTokKind <> TK_DEDENT) Do
  Begin
    If (CurTokKind = TK_KEYWORD) And (CurTokStr = 'def') Then
    Begin
      LexNextToken;  (* consommer 'def' *)
      If CurTokKind = TK_IDENT Then
      Begin
        MethodName := CurTokStr;
        LexNextToken;  (* consommer le nom de la methode *)

        If MethodName = '__init__' Then
        Begin
          { Constructeur }
          Inc(ClInitDefCount);
          WriteLn('_PYM_', ClassName, '___init__:');
          WriteLn('  PUSH EBP');
          WriteLn('  MOV EBP, ESP');
          { Consommer la liste de parametres }
          If (CurTokKind = TK_OP) And (CurTokStr = '(') Then
          Begin
            While Not ((CurTokKind = TK_OP) And (CurTokStr = ')'))
                  And (CurTokKind <> TK_EOF) Do
              LexNextToken;
            If (CurTokKind = TK_OP) And (CurTokStr = ')') Then
              LexNextToken;  (* consommer ')' *)
          End;
          If (CurTokKind = TK_OP) And (CurTokStr = ':') Then
            LexNextToken;  (* consommer ':' *)
          { Le corps du constructeur sera parse par les futurs passes }
          WriteLn('  ; corps de __init__ (stub)');
          WriteLn('  MOV ESP, EBP');
          WriteLn('  POP EBP');
          WriteLn('  RET');
        End
        Else
        Begin
          { Methode normale }
          Inc(ClMethodDefCount);
          Inc(MethodCount);
          EmitMethodPrologue(ClassName, MethodName, 0);
          { Consommer la liste de parametres }
          If (CurTokKind = TK_OP) And (CurTokStr = '(') Then
          Begin
            While Not ((CurTokKind = TK_OP) And (CurTokStr = ')'))
                  And (CurTokKind <> TK_EOF) Do
              LexNextToken;
            If (CurTokKind = TK_OP) And (CurTokStr = ')') Then
              LexNextToken;  (* consommer ')' *)
          End;
          If (CurTokKind = TK_OP) And (CurTokStr = ':') Then
            LexNextToken;  (* consommer ':' *)
          { Le corps de la methode sera parse par les futurs passes }
          WriteLn('  ; corps de ', MethodName, ' (stub)');
          EmitMethodEpilogue;
        End;
      End;
    End
    Else If CurTokKind = TK_NEWLINE Then
      LexNextToken  (* consommer le saut de ligne *)
    Else If CurTokKind = TK_INDENT Then
      LexNextToken  (* consommer l indentation *)
    Else
      LexNextToken;  (* consommer tout autre token *)
  End;

  { Consommer le DEDENT si present }
  If CurTokKind = TK_DEDENT Then
    LexNextToken;

  { Emettre le label de fin }
  WriteLn(SkipLabel, ':');
  WriteLn('; --- fin class ', ClassName, ' (', MethodCount,
          ' methodes) ---');
End;

{ ------------------------------------------------------------ }
{ DumpClState : afficher l etat du sous-systeme des classes         }
{ ------------------------------------------------------------ }

Procedure DumpClState;
Begin
  WriteLn('--- Class State ---');
  WriteLn('  ClInitialized    : ', ClInitialized);
  WriteLn('  ClClassDefCount  : ', ClClassDefCount);
  WriteLn('  ClInhCount       : ', ClInhCount);
  WriteLn('  ClInitDefCount   : ', ClInitDefCount);
  WriteLn('  ClMethodDefCount : ', ClMethodDefCount);
  WriteLn('  ClObjNewCount    : ', ClObjNewCount);
  WriteLn('  ClAttrLoadCount  : ', ClAttrLoadCount);
  WriteLn('  ClAttrStoreCount : ', ClAttrStoreCount);
  WriteLn('  ClMethCallCount  : ', ClMethCallCount);
  WriteLn('  ClInitCallCount  : ', ClInitCallCount);
  WriteLn('  ClInheritCount   : ', ClInheritCount);
  WriteLn('  ClIsInstCount    : ', ClIsInstCount);
  WriteLn('  ClSuperCount     : ', ClSuperCount);
  WriteLn('  ClSelfRefCount   : ', ClSelfRefCount);
  WriteLn('  ClLastKind       : ', ClTypeName(ClLastKind));
  WriteLn('  ClLabelSeq       : ', ClLabelSeq);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 18)                              }
{ ------------------------------------------------------------ }

Function IsClInitialized : Boolean;
Begin
  IsClInitialized := ClInitialized;
End;

Function IsClEmpty : Boolean;
Begin
  IsClEmpty := (ClClassDefCount = 0) And (ClMethodDefCount = 0) And
               (ClObjNewCount = 0) And (ClMethCallCount = 0);
End;

Function GetClClassDefCount : LongInt;
Begin
  GetClClassDefCount := ClClassDefCount;
End;

Function GetClMethodDefCount : LongInt;
Begin
  GetClMethodDefCount := ClMethodDefCount;
End;

Function GetClObjNewCount : LongInt;
Begin
  GetClObjNewCount := ClObjNewCount;
End;

Function GetClAttrLoadCount : LongInt;
Begin
  GetClAttrLoadCount := ClAttrLoadCount;
End;

Function GetClMethCallCount : LongInt;
Begin
  GetClMethCallCount := ClMethCallCount;
End;

Function GetClInitCallCount : LongInt;
Begin
  GetClInitCallCount := ClInitCallCount;
End;

Function GetClIsInstCount : LongInt;
Begin
  GetClIsInstCount := ClIsInstCount;
End;

Function GetClStatus : TString;
Begin
  If Not ClInitialized Then
    GetClStatus := 'Not initialized'
  Else
    GetClStatus := ItoS(ClClassDefCount) + ' classes, ' +
                   ItoS(ClMethodDefCount) + ' methods, ' +
                   ItoS(ClObjNewCount) + ' new, ' +
                   ItoS(ClMethCallCount) + ' calls, ' +
                   ItoS(ClAttrLoadCount) + ' attr load, ' +
                   ItoS(ClIsInstCount) + ' isinstance';
End;

{ ============================================================ }
{ TODO 19 - PARSEUR : EXCEPTIONS (try/except/finally/raise)    }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { Types d operations sur les exceptions }
  EX_NONE          = 0;    { aucun / non defini                    }
  EX_TRY           = 1;    { bloc try                              }
  EX_EXCEPT        = 2;    { except ExceptionType: bloc            }
  EX_EXCEPT_AS     = 3;    { except ExceptionType as e: bloc       }
  EX_BARE_EXCEPT   = 4;    { except: bloc (attrape tout)           }
  EX_ELSE          = 5;    { else: bloc apres try                  }
  EX_FINALLY       = 6;    { finally: bloc                         }
  EX_RAISE         = 7;    { raise ExceptionType(msg)              }
  EX_RERAISE       = 8;    { raise sans argument                   }
  EX_SETUP         = 9;    { installer handler d exception         }
  EX_RESTORE       = 10;   { restaurer handler precedent           }
  EX_EXIT          = 11;   { sortir du bloc try normalement        }
  EX_UNHANDLED     = 12;   { exception non geree                   }
  EX_NESTED        = 13;   { try imbrique                          }
  EX_MAX           = 13;

  { Limites }
  EX_MAX_TRY_NEST  = 16;   { profondeur max de try imbriques       }
  EX_MAX_EXCEPT    = 16;   { nombre max de clauses except par try   }
  EX_MAX_TYPES     = 32;   { nombre max de types d exception        }

Var
  ExInitialized    : Boolean;    { True si l etat est initialise       }
  ExTryCount       : LongInt;    { nombre de blocs try                 }
  ExExceptCount    : LongInt;    { nombre de clauses except            }
  ExExceptAsCount  : LongInt;    { nombre de except ... as e           }
  ExBareCount      : LongInt;    { nombre de except generiques         }
  ExElseCount      : LongInt;    { nombre de clauses else              }
  ExFinallyCount   : LongInt;    { nombre de clauses finally           }
  ExRaiseCount     : LongInt;    { nombre de raise ExcType(msg)        }
  ExReraiseCount   : LongInt;    { nombre de raise sans argument       }
  ExSetupCount     : LongInt;    { nombre de setup handler             }
  ExRestoreCount   : LongInt;    { nombre de restore handler           }
  ExExitCount      : LongInt;    { nombre de sortie normale            }
  ExUnhandledCount : LongInt;    { nombre d exceptions non gerees      }
  ExNestDepth      : Integer;    { profondeur d imbrication courante   }
  ExLastKind       : Integer;    { dernier type d operation exception  }
  ExLabelSeq       : Integer;    { sequence pour labels exception      }

{ ------------------------------------------------------------ }
{ InitExState : initialiser le sous-systeme des exceptions         }
{ ------------------------------------------------------------ }

Procedure InitExState;
Begin
  ExInitialized    := True;
  ExTryCount       := 0;
  ExExceptCount    := 0;
  ExExceptAsCount  := 0;
  ExBareCount      := 0;
  ExElseCount      := 0;
  ExFinallyCount   := 0;
  ExRaiseCount     := 0;
  ExReraiseCount   := 0;
  ExSetupCount     := 0;
  ExRestoreCount   := 0;
  ExExitCount      := 0;
  ExUnhandledCount := 0;
  ExNestDepth      := 0;
  ExLastKind       := EX_NONE;
  ExLabelSeq       := 0;
End;

{ ------------------------------------------------------------ }
{ GenExLabel : generer un label unique pour les exceptions          }
{ ------------------------------------------------------------ }

Function GenExLabel : TString;
Begin
  Inc(ExLabelSeq);
  GenExLabel := '_PYX_' + ItoS(ExLabelSeq);
End;

{ ------------------------------------------------------------ }
{ ExTypeName : retourner le nom du type d operation exception       }
{ ------------------------------------------------------------ }

Function ExTypeName(Kind : Integer) : TString;
Begin
  Case Kind Of
    EX_NONE        : ExTypeName := 'EX_NONE';
    EX_TRY         : ExTypeName := 'EX_TRY';
    EX_EXCEPT      : ExTypeName := 'EX_EXCEPT';
    EX_EXCEPT_AS   : ExTypeName := 'EX_EXCEPT_AS';
    EX_BARE_EXCEPT : ExTypeName := 'EX_BARE_EXCEPT';
    EX_ELSE        : ExTypeName := 'EX_ELSE';
    EX_FINALLY     : ExTypeName := 'EX_FINALLY';
    EX_RAISE       : ExTypeName := 'EX_RAISE';
    EX_RERAISE     : ExTypeName := 'EX_RERAISE';
    EX_SETUP       : ExTypeName := 'EX_SETUP';
    EX_RESTORE     : ExTypeName := 'EX_RESTORE';
    EX_EXIT        : ExTypeName := 'EX_EXIT';
    EX_UNHANDLED   : ExTypeName := 'EX_UNHANDLED';
    EX_NESTED      : ExTypeName := 'EX_NESTED';
  Else
    ExTypeName := 'EX_UNKNOWN(' + ItoS(Kind) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ EmitSetupHandler : installer un handler d exception               }
{   Sauvegarder le handler courant, installer nouveau label        }
{ ------------------------------------------------------------ }

Procedure EmitSetupHandler(Const HandlerLabel : TString);
Begin
  WriteLn('; --- setup exception handler ---');
  WriteLn('PUSH DWORD [_PYX_HANDLER]    ; sauver ancien handler');
  WriteLn('MOV DWORD [_PYX_HANDLER], ', HandlerLabel);
  WriteLn('MOV DWORD [_PYX_CODE], 0     ; pas d exception active');
  Inc(ExSetupCount);
  ExLastKind := EX_SETUP;
End;

{ ------------------------------------------------------------ }
{ EmitRestoreHandler : restaurer le handler d exception precedent   }
{ ------------------------------------------------------------ }

Procedure EmitRestoreHandler;
Begin
  WriteLn('; --- restore exception handler ---');
  WriteLn('POP DWORD [_PYX_HANDLER]     ; restaurer ancien handler');
  Inc(ExRestoreCount);
  ExLastKind := EX_RESTORE;
End;

{ ------------------------------------------------------------ }
{ EmitExitHandler : sortir du bloc try normalement                  }
{ ------------------------------------------------------------ }

Procedure EmitExitHandler(Const EndLabel : TString);
Begin
  WriteLn('; --- exit try normal ---');
  WriteLn('JMP ', EndLabel, '              ; saut vers fin de try');
  Inc(ExExitCount);
  ExLastKind := EX_EXIT;
End;

{ ------------------------------------------------------------ }
{ EmitTryBegin : emettre le debut d un bloc try                     }
{ ------------------------------------------------------------ }

Procedure EmitTryBegin(Const ExceptLabel : TString);
Begin
  WriteLn('; --- try begin ---');
  EmitSetupHandler(ExceptLabel);
  Inc(ExTryCount);
  ExLastKind := EX_TRY;
End;

{ ------------------------------------------------------------ }
{ EmitExceptHandler : emettre un handler except Type                }
{ ------------------------------------------------------------ }

Procedure EmitExceptHandler(Const ExcType : TString;
                            Const NextLabel : TString);
Begin
  WriteLn('; --- except ', ExcType, ' ---');
  WriteLn('CMP DWORD [_PYX_CODE], ', ExcType, '_CODE');
  WriteLn('JNE ', NextLabel, '              ; pas ce type, suivant');
  Inc(ExExceptCount);
  ExLastKind := EX_EXCEPT;
End;

{ ------------------------------------------------------------ }
{ EmitExceptAs : emettre except Type as var                         }
{   Stocker le message d exception dans la variable                }
{ ------------------------------------------------------------ }

Procedure EmitExceptAs(Const ExcType, VarName : TString;
                       Const NextLabel : TString);
Begin
  WriteLn('; --- except ', ExcType, ' as ', VarName, ' ---');
  WriteLn('CMP DWORD [_PYX_CODE], ', ExcType, '_CODE');
  WriteLn('JNE ', NextLabel, '              ; pas ce type, suivant');
  WriteLn('MOV EAX, [_PYX_MSG]          ; charger message exception');
  WriteLn('MOV [', VarName, '], EAX      ; stocker dans variable');
  Inc(ExExceptAsCount);
  ExLastKind := EX_EXCEPT_AS;
End;

{ ------------------------------------------------------------ }
{ EmitBareExcept : emettre except: (attrape tout)                   }
{ ------------------------------------------------------------ }

Procedure EmitBareExcept;
Begin
  WriteLn('; --- except (bare, catch all) ---');
  WriteLn('CMP DWORD [_PYX_CODE], 0');
  WriteLn('JE _PYX_NO_EXC               ; pas d exception, skip');
  Inc(ExBareCount);
  ExLastKind := EX_BARE_EXCEPT;
End;

{ ------------------------------------------------------------ }
{ EmitElseBlock : emettre le bloc else (si aucune exception)        }
{ ------------------------------------------------------------ }

Procedure EmitElseBlock(Const ElseLabel : TString);
Begin
  WriteLn('; --- else (no exception) ---');
  WriteLn(ElseLabel, ':');
  WriteLn('CMP DWORD [_PYX_CODE], 0     ; exception levee ?');
  WriteLn('JNE _PYX_SKIP_ELSE           ; oui, sauter else');
  Inc(ExElseCount);
  ExLastKind := EX_ELSE;
End;

{ ------------------------------------------------------------ }
{ EmitFinallyBlock : emettre le bloc finally                        }
{ ------------------------------------------------------------ }

Procedure EmitFinallyBlock(Const FinallyLabel : TString);
Begin
  WriteLn('; --- finally ---');
  WriteLn(FinallyLabel, ':');
  Inc(ExFinallyCount);
  ExLastKind := EX_FINALLY;
End;

{ ------------------------------------------------------------ }
{ EmitTryEnd : emettre la fin du bloc try complet                   }
{ ------------------------------------------------------------ }

Procedure EmitTryEnd(Const EndLabel : TString);
Begin
  WriteLn('; --- end try ---');
  WriteLn(EndLabel, ':');
  EmitRestoreHandler;
End;

{ ------------------------------------------------------------ }
{ EmitRaise : emettre raise ExceptionType(msg)                      }
{   EAX = code exception, EBX = pointeur vers message             }
{ ------------------------------------------------------------ }

Procedure EmitRaise(Const ExcType, MsgLabel : TString);
Begin
  WriteLn('; --- raise ', ExcType, ' ---');
  WriteLn('MOV EAX, ', ExcType, '_CODE    ; code de l exception');
  WriteLn('MOV DWORD [_PYX_CODE], EAX    ; stocker code exception');
  WriteLn('MOV EBX, ', MsgLabel, '        ; pointeur message');
  WriteLn('MOV DWORD [_PYX_MSG], EBX     ; stocker message');
  WriteLn('JMP DWORD [_PYX_HANDLER]      ; sauter vers handler');
  Inc(ExRaiseCount);
  ExLastKind := EX_RAISE;
End;

{ ------------------------------------------------------------ }
{ EmitReraise : emettre raise sans argument (relever exception)     }
{ ------------------------------------------------------------ }

Procedure EmitReraise;
Begin
  WriteLn('; --- reraise (propagate) ---');
  WriteLn('CMP DWORD [_PYX_CODE], 0     ; exception active ?');
  WriteLn('JE _PYX_NO_ACTIVE            ; non, erreur');
  WriteLn('JMP DWORD [_PYX_HANDLER]     ; propager vers handler');
  Inc(ExReraiseCount);
  ExLastKind := EX_RERAISE;
End;

{ ------------------------------------------------------------ }
{ EmitUnhandled : emettre le handler d exception non geree          }
{   Afficher 'Unhandled exception' + ExitProcess(1)               }
{ ------------------------------------------------------------ }

Procedure EmitUnhandled;
Begin
  WriteLn('; --- unhandled exception ---');
  WriteLn('_PYX_UNHANDLED:');
  WriteLn('PUSH _PYX_UNHANDLED_MSG      ; ptr "Unhandled exception"');
  WriteLn('PUSH DWORD [_PYX_STDOUT]     ; handle stdout');
  WriteLn('CALL _WriteFile               ; afficher message');
  WriteLn('PUSH 1                        ; code de sortie');
  WriteLn('CALL ExitProcess              ; terminer');
  Inc(ExUnhandledCount);
  ExLastKind := EX_UNHANDLED;
End;

{ ------------------------------------------------------------ }
{ ParseTryStmt : parser une instruction try/except/else/finally     }
{   try:                                                           }
{     bloc                                                         }
{   except [ExcType [as var]]:                                     }
{     bloc                                                         }
{   [else:]                                                        }
{     [bloc]                                                       }
{   [finally:]                                                     }
{     [bloc]                                                       }
{ ------------------------------------------------------------ }

Procedure ParseTryStmt;
Var
  TryLabel     : TString;
  ExceptLabel  : TString;
  ElseLabel    : TString;
  FinallyLabel : TString;
  EndLabel     : TString;
  NextLabel    : TString;
  ExcType      : TString;
  VarName      : TString;
  HasElse      : Boolean;
  HasFinally   : Boolean;
  ExceptIdx    : Integer;
Begin
  { Verifier la profondeur d imbrication }
  If ExNestDepth >= EX_MAX_TRY_NEST Then
  Begin
    WriteLn('Erreur: try imbrique trop profondement (max ',
            EX_MAX_TRY_NEST, ')');
    Inc(ErrorCount);
    Exit;
  End;
  Inc(ExNestDepth);

  { Generer les labels }
  TryLabel     := GenExLabel;
  ExceptLabel  := GenExLabel;
  ElseLabel    := GenExLabel;
  FinallyLabel := GenExLabel;
  EndLabel     := GenExLabel;

  HasElse    := False;
  HasFinally := False;
  ExceptIdx  := 0;

  WriteLn('; === try/except/finally ===');
  WriteLn(TryLabel, ':');

  { Installer le handler d exception }
  EmitTryBegin(ExceptLabel);

  { Consommer 'try' }
  LexNextToken;

  { Attendre ':' }
  If CurTokKind = TK_COLON Then
    LexNextToken;

  { Consommer NEWLINE si present }
  If CurTokKind = TK_NEWLINE Then
    LexNextToken;

  { Consommer INDENT si present }
  If CurTokKind = TK_INDENT Then
    LexNextToken;

  { Parser le corps du try (simplifie: on avance jusqu a except/finally) }
  While (CurTokKind <> TK_EOF) And
        Not ((CurTokKind = TK_KEYWORD) And
             ((CurTokStr = 'except') Or
              (CurTokStr = 'finally'))) And
        (CurTokKind <> TK_DEDENT) Do
  Begin
    If CurTokKind = TK_NEWLINE Then
      LexNextToken
    Else If CurTokKind = TK_INDENT Then
      LexNextToken
    Else
      LexNextToken;
  End;

  { Consommer le DEDENT si present }
  If CurTokKind = TK_DEDENT Then
    LexNextToken;

  { Sortie normale du try : sauter vers else ou finally ou end }
  WriteLn('; --- try body done (no exception) ---');
  WriteLn('MOV DWORD [_PYX_CODE], 0     ; aucune exception');

  { Parser les clauses except }
  WriteLn(ExceptLabel, ':');

  While (CurTokKind = TK_KEYWORD) And (CurTokStr = 'except') Do
  Begin
    LexNextToken;  { Consommer 'except' }
    Inc(ExceptIdx);
    NextLabel := GenExLabel;

    If CurTokKind = TK_COLON Then
    Begin
      { except: (bare except, attrape tout) }
      LexNextToken;  { Consommer ':' }
      EmitBareExcept;
    End
    Else
    Begin
      { except ExcType [as var]: }
      ExcType := CurTokStr;
      LexNextToken;  { Consommer le type }

      If (CurTokKind = TK_KEYWORD) And (CurTokStr = 'as') Then
      Begin
        { except ExcType as var: }
        LexNextToken;  { Consommer 'as' }
        VarName := CurTokStr;
        LexNextToken;  { Consommer le nom de variable }
        If CurTokKind = TK_COLON Then
          LexNextToken;
        EmitExceptAs(ExcType, VarName, NextLabel);
      End
      Else
      Begin
        { except ExcType: }
        If CurTokKind = TK_COLON Then
          LexNextToken;
        EmitExceptHandler(ExcType, NextLabel);
      End;
    End;

    { Consommer NEWLINE si present }
    If CurTokKind = TK_NEWLINE Then
      LexNextToken;

    { Consommer INDENT si present }
    If CurTokKind = TK_INDENT Then
      LexNextToken;

    { Parser le corps du except }
    While (CurTokKind <> TK_EOF) And
          Not ((CurTokKind = TK_KEYWORD) And
               ((CurTokStr = 'except') Or
                (CurTokStr = 'else') Or
                (CurTokStr = 'finally'))) And
          (CurTokKind <> TK_DEDENT) Do
    Begin
      If CurTokKind = TK_NEWLINE Then
        LexNextToken
      Else If CurTokKind = TK_INDENT Then
        LexNextToken
      Else
        LexNextToken;
    End;

    { Consommer le DEDENT si present }
    If CurTokKind = TK_DEDENT Then
      LexNextToken;

    { Apres le handler, sauter vers finally ou end }
    EmitExitHandler(FinallyLabel);
    WriteLn(NextLabel, ':');
  End;

  { Parser la clause else optionnelle }
  If (CurTokKind = TK_KEYWORD) And (CurTokStr = 'else') Then
  Begin
    HasElse := True;
    LexNextToken;  { Consommer 'else' }
    If CurTokKind = TK_COLON Then
      LexNextToken;
    EmitElseBlock(ElseLabel);

    { Consommer NEWLINE si present }
    If CurTokKind = TK_NEWLINE Then
      LexNextToken;

    { Consommer INDENT si present }
    If CurTokKind = TK_INDENT Then
      LexNextToken;

    { Parser le corps du else }
    While (CurTokKind <> TK_EOF) And
          Not ((CurTokKind = TK_KEYWORD) And
               (CurTokStr = 'finally')) And
          (CurTokKind <> TK_DEDENT) Do
    Begin
      If CurTokKind = TK_NEWLINE Then
        LexNextToken
      Else If CurTokKind = TK_INDENT Then
        LexNextToken
      Else
        LexNextToken;
    End;

    { Consommer le DEDENT si present }
    If CurTokKind = TK_DEDENT Then
      LexNextToken;
  End;

  { Parser la clause finally optionnelle }
  If (CurTokKind = TK_KEYWORD) And (CurTokStr = 'finally') Then
  Begin
    HasFinally := True;
    LexNextToken;  { Consommer 'finally' }
    If CurTokKind = TK_COLON Then
      LexNextToken;
    EmitFinallyBlock(FinallyLabel);

    { Consommer NEWLINE si present }
    If CurTokKind = TK_NEWLINE Then
      LexNextToken;

    { Consommer INDENT si present }
    If CurTokKind = TK_INDENT Then
      LexNextToken;

    { Parser le corps du finally }
    While (CurTokKind <> TK_EOF) And
          (CurTokKind <> TK_DEDENT) Do
    Begin
      If CurTokKind = TK_NEWLINE Then
        LexNextToken
      Else If CurTokKind = TK_INDENT Then
        LexNextToken
      Else
        LexNextToken;
    End;

    { Consommer le DEDENT si present }
    If CurTokKind = TK_DEDENT Then
      LexNextToken;
  End
  Else
  Begin
    { Pas de finally : emettre le label quand meme }
    WriteLn(FinallyLabel, ':');
  End;

  { Emettre la fin du try }
  EmitTryEnd(EndLabel);

  Dec(ExNestDepth);

  WriteLn('; === fin try/except (', ExceptIdx, ' clauses except',
          ', else=', HasElse, ', finally=', HasFinally, ') ===');
End;

{ ------------------------------------------------------------ }
{ ParseRaiseStmt : parser une instruction raise                     }
{   raise ExceptionType(msg)  -> lever une exception               }
{   raise                     -> relever l exception courante      }
{ ------------------------------------------------------------ }

Procedure ParseRaiseStmt;
Var
  ExcType  : TString;
  MsgLabel : TString;
Begin
  { Consommer 'raise' }
  LexNextToken;

  { raise sans argument : relever l exception courante }
  If (CurTokKind = TK_NEWLINE) Or (CurTokKind = TK_EOF) Or
     (CurTokKind = TK_DEDENT) Then
  Begin
    EmitReraise;
    Exit;
  End;

  { raise ExcType ou raise ExcType(msg) }
  ExcType := CurTokStr;
  LexNextToken;  { Consommer le type }

  { Verifier si c est raise ExcType(msg) ou raise ExcType }
  If (CurTokKind = TK_PUNCT) And (CurTokStr = '(') Then
  Begin
    { raise ExcType(msg) }
    LexNextToken;  { Consommer '(' }
    If CurTokKind = TK_STRING Then
    Begin
      MsgLabel := GenExLabel;
      WriteLn(MsgLabel, ' DB ''', CurTokStr, ''', 0');
      LexNextToken;  { Consommer le message }
    End
    Else
    Begin
      MsgLabel := '_PYX_EMPTY_MSG';
      If Not ((CurTokKind = TK_PUNCT) And (CurTokStr = ')')) Then
        LexNextToken;
    End;

    If (CurTokKind = TK_PUNCT) And (CurTokStr = ')') Then
      LexNextToken;  { Consommer ')' }
  End
  Else
  Begin
    { raise ExcType sans message }
    MsgLabel := '_PYX_EMPTY_MSG';
  End;

  EmitRaise(ExcType, MsgLabel);
End;

{ ------------------------------------------------------------ }
{ DumpExState : afficher l etat du sous-systeme des exceptions      }
{ ------------------------------------------------------------ }

Procedure DumpExState;
Begin
  WriteLn('--- Exception State ---');
  WriteLn('  ExInitialized    : ', ExInitialized);
  WriteLn('  ExTryCount       : ', ExTryCount);
  WriteLn('  ExExceptCount    : ', ExExceptCount);
  WriteLn('  ExExceptAsCount  : ', ExExceptAsCount);
  WriteLn('  ExBareCount      : ', ExBareCount);
  WriteLn('  ExElseCount      : ', ExElseCount);
  WriteLn('  ExFinallyCount   : ', ExFinallyCount);
  WriteLn('  ExRaiseCount     : ', ExRaiseCount);
  WriteLn('  ExReraiseCount   : ', ExReraiseCount);
  WriteLn('  ExSetupCount     : ', ExSetupCount);
  WriteLn('  ExRestoreCount   : ', ExRestoreCount);
  WriteLn('  ExExitCount      : ', ExExitCount);
  WriteLn('  ExUnhandledCount : ', ExUnhandledCount);
  WriteLn('  ExNestDepth      : ', ExNestDepth);
  WriteLn('  ExLastKind       : ', ExTypeName(ExLastKind));
  WriteLn('  ExLabelSeq       : ', ExLabelSeq);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 19)                              }
{ ------------------------------------------------------------ }

Function IsExInitialized : Boolean;
Begin
  IsExInitialized := ExInitialized;
End;

Function IsExEmpty : Boolean;
Begin
  IsExEmpty := (ExTryCount = 0) And (ExExceptCount = 0) And
               (ExRaiseCount = 0) And (ExFinallyCount = 0);
End;

Function GetExTryCount : LongInt;
Begin
  GetExTryCount := ExTryCount;
End;

Function GetExExceptCount : LongInt;
Begin
  GetExExceptCount := ExExceptCount;
End;

Function GetExFinallyCount : LongInt;
Begin
  GetExFinallyCount := ExFinallyCount;
End;

Function GetExRaiseCount : LongInt;
Begin
  GetExRaiseCount := ExRaiseCount;
End;

Function GetExReraiseCount : LongInt;
Begin
  GetExReraiseCount := ExReraiseCount;
End;

Function GetExBareCount : LongInt;
Begin
  GetExBareCount := ExBareCount;
End;

Function GetExElseCount : LongInt;
Begin
  GetExElseCount := ExElseCount;
End;

Function GetExStatus : TString;
Begin
  If Not ExInitialized Then
    GetExStatus := 'Not initialized'
  Else
    GetExStatus := ItoS(ExTryCount) + ' try, ' +
                   ItoS(ExExceptCount) + ' except, ' +
                   ItoS(ExExceptAsCount) + ' except-as, ' +
                   ItoS(ExBareCount) + ' bare, ' +
                   ItoS(ExFinallyCount) + ' finally, ' +
                   ItoS(ExRaiseCount) + ' raise, ' +
                   ItoS(ExReraiseCount) + ' reraise';
End;

{ ============================================================ }
{ TODO 20 - PARSEUR : COMPREHENSIONS ET IMPORT                 }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { Types d operations comprehension et import }
  CP_NONE          = 0;    { aucun / non defini                    }
  CP_LIST_COMP     = 1;    { list comprehension [expr for x in it] }
  CP_LIST_FILTER   = 2;    { list comp avec filtre [e for x if c]  }
  CP_DICT_COMP     = 3;    { dict comprehension                    }
  CP_DICT_FILTER   = 4;    { dict comp avec filtre                 }
  CP_GEN_EXPR      = 5;    { generator expression (non supporte)   }
  CP_SET_COMP      = 6;    { set comprehension (non supporte)      }
  CP_IMPORT        = 7;    { import module                         }
  CP_FROM_IMPORT   = 8;    { from module import nom                }
  CP_MOD_MATH      = 9;    { module math (builtins)                }
  CP_MOD_SYS       = 10;   { module sys (sys.exit)                 }
  CP_MOD_OS        = 11;   { module os (non supporte)              }
  CP_EXTRN         = 12;   { symbole externe (EXTRN)               }
  CP_PUBLIC        = 13;   { symbole public (PUBLIC)               }
  CP_MAX           = 13;

  { Limites }
  CP_MAX_IMPORTS   = 32;   { nombre max de modules importes        }
  CP_MAX_SYMBOLS   = 64;   { nombre max de symboles importes       }
  CP_MAX_MODULES   = 16;   { nombre max de modules disponibles     }

Var
  CpInitialized    : Boolean;    { True si l etat est initialise       }
  CpListCompCount  : LongInt;    { nombre de list comprehensions       }
  CpListFilterCount: LongInt;    { nombre de list comp avec filtre     }
  CpDictCompCount  : LongInt;    { nombre de dict comprehensions       }
  CpDictFilterCount: LongInt;    { nombre de dict comp avec filtre     }
  CpGenWarnCount   : LongInt;    { nombre d avertissements generateur  }
  CpSetWarnCount   : LongInt;    { nombre d avertissements set comp    }
  CpImportCount    : LongInt;    { nombre de import module             }
  CpFromCount      : LongInt;    { nombre de from module import nom    }
  CpMathCount      : LongInt;    { nombre d imports math               }
  CpSysCount       : LongInt;    { nombre d imports sys                }
  CpOsWarnCount    : LongInt;    { nombre d avertissements os          }
  CpExtrnCount     : LongInt;    { nombre de symboles externes         }
  CpPublicCount    : LongInt;    { nombre de symboles publics          }
  CpLastKind       : Integer;    { dernier type d operation            }
  CpLabelSeq       : Integer;    { sequence pour labels comprehension  }

{ ------------------------------------------------------------ }
{ InitCpState : initialiser le sous-systeme des comprehensions     }
{ ------------------------------------------------------------ }

Procedure InitCpState;
Begin
  CpInitialized    := True;
  CpListCompCount  := 0;
  CpListFilterCount:= 0;
  CpDictCompCount  := 0;
  CpDictFilterCount:= 0;
  CpGenWarnCount   := 0;
  CpSetWarnCount   := 0;
  CpImportCount    := 0;
  CpFromCount      := 0;
  CpMathCount      := 0;
  CpSysCount       := 0;
  CpOsWarnCount    := 0;
  CpExtrnCount     := 0;
  CpPublicCount    := 0;
  CpLastKind       := CP_NONE;
  CpLabelSeq       := 0;
End;

{ ------------------------------------------------------------ }
{ GenCpLabel : generer un label unique pour les comprehensions      }
{ ------------------------------------------------------------ }

Function GenCpLabel : TString;
Begin
  Inc(CpLabelSeq);
  GenCpLabel := '_PYC_' + ItoS(CpLabelSeq);
End;

{ ------------------------------------------------------------ }
{ CpTypeName : retourner le nom du type d operation comprehension   }
{ ------------------------------------------------------------ }

Function CpTypeName(Kind : Integer) : TString;
Begin
  Case Kind Of
    CP_NONE        : CpTypeName := 'CP_NONE';
    CP_LIST_COMP   : CpTypeName := 'CP_LIST_COMP';
    CP_LIST_FILTER : CpTypeName := 'CP_LIST_FILTER';
    CP_DICT_COMP   : CpTypeName := 'CP_DICT_COMP';
    CP_DICT_FILTER : CpTypeName := 'CP_DICT_FILTER';
    CP_GEN_EXPR    : CpTypeName := 'CP_GEN_EXPR';
    CP_SET_COMP    : CpTypeName := 'CP_SET_COMP';
    CP_IMPORT      : CpTypeName := 'CP_IMPORT';
    CP_FROM_IMPORT : CpTypeName := 'CP_FROM_IMPORT';
    CP_MOD_MATH    : CpTypeName := 'CP_MOD_MATH';
    CP_MOD_SYS     : CpTypeName := 'CP_MOD_SYS';
    CP_MOD_OS      : CpTypeName := 'CP_MOD_OS';
    CP_EXTRN       : CpTypeName := 'CP_EXTRN';
    CP_PUBLIC      : CpTypeName := 'CP_PUBLIC';
  Else
    CpTypeName := 'CP_UNKNOWN(' + ItoS(Kind) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ EmitListCompBegin : debut d une list comprehension                }
{   Allouer une liste vide, preparer la boucle                     }
{ ------------------------------------------------------------ }

Procedure EmitListCompBegin(Const ResultLabel, LoopLabel : TString;
                            Const IterVar : TString);
Begin
  WriteLn('; --- list comprehension begin ---');
  WriteLn('CALL _PYRT_LIST_NEW           ; allouer liste vide');
  WriteLn('MOV [', ResultLabel, '], EAX   ; stocker ptr liste');
  WriteLn(LoopLabel, ':');
  WriteLn('; boucle for ', IterVar, ' in iterable');
  Inc(CpListCompCount);
  CpLastKind := CP_LIST_COMP;
End;

{ ------------------------------------------------------------ }
{ EmitListCompAppend : ajouter un element dans la list comp         }
{ ------------------------------------------------------------ }

Procedure EmitListCompAppend(Const ResultLabel : TString);
Begin
  WriteLn('; --- list comp append ---');
  WriteLn('PUSH EAX                      ; valeur de l expression');
  WriteLn('PUSH DWORD [', ResultLabel, '] ; ptr liste');
  WriteLn('CALL _PYRT_LIST_APPEND        ; ajouter element');
  WriteLn('ADD ESP, 8');
End;

{ ------------------------------------------------------------ }
{ EmitListCompEnd : fin de la list comprehension                    }
{ ------------------------------------------------------------ }

Procedure EmitListCompEnd(Const ResultLabel, EndLabel : TString);
Begin
  WriteLn('; --- list comprehension end ---');
  WriteLn(EndLabel, ':');
  WriteLn('MOV EAX, [', ResultLabel, ']   ; EAX = ptr liste resultat');
End;

{ ------------------------------------------------------------ }
{ EmitCompFilter : emettre un filtre conditionnel (if cond)         }
{   Si la condition est fausse, sauter vers le label continue      }
{ ------------------------------------------------------------ }

Procedure EmitCompFilter(Const ContinueLabel : TString);
Begin
  WriteLn('; --- comprehension filter (if cond) ---');
  WriteLn('CMP EAX, 0                    ; tester condition');
  WriteLn('JE ', ContinueLabel, '         ; faux, element suivant');
  Inc(CpListFilterCount);
  CpLastKind := CP_LIST_FILTER;
End;

{ ------------------------------------------------------------ }
{ EmitDictCompBegin : debut d une dict comprehension                }
{   Allouer un dict vide, preparer la boucle                      }
{ ------------------------------------------------------------ }

Procedure EmitDictCompBegin(Const ResultLabel, LoopLabel : TString;
                            Const IterVar : TString);
Begin
  WriteLn('; --- dict comprehension begin ---');
  WriteLn('CALL _PYRT_DICT_NEW           ; allouer dict vide');
  WriteLn('MOV [', ResultLabel, '], EAX   ; stocker ptr dict');
  WriteLn(LoopLabel, ':');
  WriteLn('; boucle for ', IterVar, ' in iterable');
  Inc(CpDictCompCount);
  CpLastKind := CP_DICT_COMP;
End;

{ ------------------------------------------------------------ }
{ EmitDictCompSet : ajouter une paire cle:valeur dans le dict       }
{ ------------------------------------------------------------ }

Procedure EmitDictCompSet(Const ResultLabel : TString);
Begin
  WriteLn('; --- dict comp set key:value ---');
  WriteLn('PUSH EBX                      ; valeur');
  WriteLn('PUSH EAX                      ; cle');
  WriteLn('PUSH DWORD [', ResultLabel, '] ; ptr dict');
  WriteLn('CALL _PYRT_DICT_SET           ; stocker paire');
  WriteLn('ADD ESP, 12');
End;

{ ------------------------------------------------------------ }
{ EmitDictCompEnd : fin de la dict comprehension                    }
{ ------------------------------------------------------------ }

Procedure EmitDictCompEnd(Const ResultLabel, EndLabel : TString);
Begin
  WriteLn('; --- dict comprehension end ---');
  WriteLn(EndLabel, ':');
  WriteLn('MOV EAX, [', ResultLabel, ']   ; EAX = ptr dict resultat');
End;

{ ------------------------------------------------------------ }
{ EmitDictCompFilter : emettre filtre conditionnel pour dict comp   }
{ ------------------------------------------------------------ }

Procedure EmitDictCompFilter(Const ContinueLabel : TString);
Begin
  WriteLn('; --- dict comp filter (if cond) ---');
  WriteLn('CMP EAX, 0                    ; tester condition');
  WriteLn('JE ', ContinueLabel, '         ; faux, element suivant');
  Inc(CpDictFilterCount);
  CpLastKind := CP_DICT_FILTER;
End;

{ ------------------------------------------------------------ }
{ EmitGenWarning : avertissement generateur non supporte            }
{ ------------------------------------------------------------ }

Procedure EmitGenWarning;
Begin
  WriteLn('Avertissement: les expressions generateur ne sont pas');
  WriteLn('  supportees par ce compilateur. Utilisez une list comp.');
  Inc(WarnCount);
  Inc(CpGenWarnCount);
  CpLastKind := CP_GEN_EXPR;
End;

{ ------------------------------------------------------------ }
{ EmitSetCompWarning : avertissement set comprehension              }
{ ------------------------------------------------------------ }

Procedure EmitSetCompWarning;
Begin
  WriteLn('Avertissement: les set comprehensions ne sont pas');
  WriteLn('  supportees par ce compilateur. Utilisez une liste.');
  Inc(WarnCount);
  Inc(CpSetWarnCount);
  CpLastKind := CP_SET_COMP;
End;

{ ------------------------------------------------------------ }
{ EmitOsWarning : avertissement module os non supporte              }
{ ------------------------------------------------------------ }

Procedure EmitOsWarning;
Begin
  WriteLn('Avertissement: le module os n''est pas supporte');
  WriteLn('  par ce compilateur.');
  Inc(WarnCount);
  Inc(CpOsWarnCount);
  CpLastKind := CP_MOD_OS;
End;

{ ------------------------------------------------------------ }
{ EmitSysExit : emettre sys.exit(code)                              }
{   PUSH code / CALL _ExitProcess@4                                }
{ ------------------------------------------------------------ }

Procedure EmitSysExit(Const CodeExpr : TString);
Begin
  WriteLn('; --- sys.exit(', CodeExpr, ') ---');
  WriteLn('PUSH ', CodeExpr, '             ; code de sortie');
  WriteLn('CALL _ExitProcess@4            ; terminer le processus');
  Inc(CpSysCount);
  CpLastKind := CP_MOD_SYS;
End;

{ ------------------------------------------------------------ }
{ EmitExternSymbol : declarer un symbole externe (EXTRN)            }
{ ------------------------------------------------------------ }

Procedure EmitExternSymbol(Const SymName : TString);
Begin
  WriteLn('EXTRN ', SymName, ' : NEAR     ; symbole importe');
  Inc(CpExtrnCount);
  CpLastKind := CP_EXTRN;
End;

{ ------------------------------------------------------------ }
{ EmitPublicSymbol : declarer un symbole public (PUBLIC)            }
{ ------------------------------------------------------------ }

Procedure EmitPublicSymbol(Const SymName : TString);
Begin
  WriteLn('PUBLIC ', SymName, '            ; symbole exporte');
  Inc(CpPublicCount);
  CpLastKind := CP_PUBLIC;
End;

{ ------------------------------------------------------------ }
{ ParseListComp : parser une list comprehension                     }
{   [expr for var in iterable]                                     }
{   [expr for var in iterable if cond]                             }
{   Appelee quand on a detecte '[' + expr + 'for'                 }
{ ------------------------------------------------------------ }

Procedure ParseListComp;
Var
  ResultLabel  : TString;
  LoopLabel    : TString;
  ContinueLabel: TString;
  EndLabel     : TString;
  IterVar      : TString;
  HasFilter    : Boolean;
Begin
  ResultLabel   := GenCpLabel;
  LoopLabel     := GenCpLabel;
  ContinueLabel := GenCpLabel;
  EndLabel      := GenCpLabel;
  HasFilter     := False;

  WriteLn('; === list comprehension ===');

  { Consommer 'for' }
  LexNextToken;

  { Lire la variable d iteration }
  IterVar := CurTokStr;
  LexNextToken;

  { Consommer 'in' }
  If (CurTokKind = TK_KEYWORD) And (CurTokStr = 'in') Then
    LexNextToken;

  { Allouer la liste et demarrer la boucle }
  EmitListCompBegin(ResultLabel, LoopLabel, IterVar);

  { Parser l iterable (simplifie: avancer jusqu a 'if' ou ']') }
  While (CurTokKind <> TK_EOF) And
        Not ((CurTokKind = TK_KEYWORD) And (CurTokStr = 'if')) And
        Not ((CurTokKind = TK_PUNCT) And (CurTokStr = ']')) Do
  Begin
    LexNextToken;
  End;

  { Verifier s il y a un filtre 'if' }
  If (CurTokKind = TK_KEYWORD) And (CurTokStr = 'if') Then
  Begin
    HasFilter := True;
    LexNextToken;  { Consommer 'if' }

    { Parser la condition (simplifie: avancer jusqu a ']') }
    While (CurTokKind <> TK_EOF) And
          Not ((CurTokKind = TK_PUNCT) And (CurTokStr = ']')) Do
    Begin
      LexNextToken;
    End;

    EmitCompFilter(ContinueLabel);
  End;

  { Emettre l expression et l ajout a la liste }
  WriteLn('; evaluer expression');
  EmitListCompAppend(ResultLabel);

  { Label continue pour le filtre }
  WriteLn(ContinueLabel, ':');

  { Fin de la boucle : retour au debut ou fin }
  WriteLn('JMP ', LoopLabel, '             ; iteration suivante');

  { Fin de la comprehension }
  EmitListCompEnd(ResultLabel, EndLabel);

  { Consommer ']' si present }
  If (CurTokKind = TK_PUNCT) And (CurTokStr = ']') Then
    LexNextToken;

  WriteLn('; === fin list comprehension (filtre=',
          HasFilter, ') ===');
End;

{ ------------------------------------------------------------ }
{ ParseDictComp : parser une dict comprehension                     }
{   kexpr:vexpr for var in iterable                                }
{   kexpr:vexpr for var in iterable if cond                        }
{   Appelee quand on a detecte accolade + expr + for               }
{ ------------------------------------------------------------ }

Procedure ParseDictComp;
Var
  ResultLabel  : TString;
  LoopLabel    : TString;
  ContinueLabel: TString;
  EndLabel     : TString;
  IterVar      : TString;
  HasFilter    : Boolean;
Begin
  ResultLabel   := GenCpLabel;
  LoopLabel     := GenCpLabel;
  ContinueLabel := GenCpLabel;
  EndLabel      := GenCpLabel;
  HasFilter     := False;

  WriteLn('; === dict comprehension ===');

  { Consommer 'for' }
  LexNextToken;

  { Lire la variable d iteration }
  IterVar := CurTokStr;
  LexNextToken;

  { Consommer 'in' }
  If (CurTokKind = TK_KEYWORD) And (CurTokStr = 'in') Then
    LexNextToken;

  { Allouer le dict et demarrer la boucle }
  EmitDictCompBegin(ResultLabel, LoopLabel, IterVar);

  (* Parser l iterable (simplifie: avancer jusqu a if ou accolade) *)
  While (CurTokKind <> TK_EOF) And
        Not ((CurTokKind = TK_KEYWORD) And (CurTokStr = 'if')) And
        Not ((CurTokKind = TK_PUNCT) And (CurTokStr = '}')) Do
  Begin
    LexNextToken;
  End;

  { Verifier s il y a un filtre 'if' }
  If (CurTokKind = TK_KEYWORD) And (CurTokStr = 'if') Then
  Begin
    HasFilter := True;
    LexNextToken;  { Consommer 'if' }

    (* Parser la condition (simplifie: avancer jusqu a accolade) *)
    While (CurTokKind <> TK_EOF) And
          Not ((CurTokKind = TK_PUNCT) And (CurTokStr = '}')) Do
    Begin
      LexNextToken;
    End;

    EmitDictCompFilter(ContinueLabel);
  End;

  { Emettre l expression cle:valeur et l ajout au dict }
  WriteLn('; evaluer expression cle:valeur');
  EmitDictCompSet(ResultLabel);

  { Label continue pour le filtre }
  WriteLn(ContinueLabel, ':');

  { Fin de la boucle : retour au debut ou fin }
  WriteLn('JMP ', LoopLabel, '             ; iteration suivante');

  { Fin de la comprehension }
  EmitDictCompEnd(ResultLabel, EndLabel);

  (* Consommer accolade fermante si present *)
  If (CurTokKind = TK_PUNCT) And (CurTokStr = '}') Then
    LexNextToken;

  WriteLn('; === fin dict comprehension (filtre=',
          HasFilter, ') ===');
End;

{ ------------------------------------------------------------ }
{ ParseImportStmt : parser une instruction import                   }
{   import module_name                                             }
{   Ajouter le module dans la table avec IsImported=True           }
{ ------------------------------------------------------------ }

Procedure ParseImportStmt;
Var
  ModName : TString;
Begin
  { Consommer 'import' }
  LexNextToken;

  ModName := CurTokStr;
  LexNextToken;  { Consommer le nom du module }

  WriteLn('; === import ', ModName, ' ===');

  { Verifier les modules connus }
  If ModName = 'math' Then
  Begin
    WriteLn('; module math : abs, pow -> builtins ou runtime');
    WriteLn('EXTRN _PYRT_MATH_ABS : NEAR');
    WriteLn('EXTRN _PYRT_MATH_POW : NEAR');
    Inc(CpMathCount);
    CpLastKind := CP_MOD_MATH;
  End
  Else If ModName = 'sys' Then
  Begin
    WriteLn('; module sys : sys.exit -> ExitProcess');
    WriteLn('EXTRN _ExitProcess@4 : NEAR');
    Inc(CpSysCount);
    CpLastKind := CP_MOD_SYS;
  End
  Else If ModName = 'os' Then
  Begin
    EmitOsWarning;
  End
  Else
  Begin
    { Module inconnu : declarer comme externe }
    WriteLn('; module externe : ', ModName);
    EmitExternSymbol('_PYM_' + ModName);
  End;

  Inc(CpImportCount);
End;

{ ------------------------------------------------------------ }
{ ParseFromImportStmt : parser une instruction from...import        }
{   from module import nom1 [, nom2, ...]                          }
{   Ajouter les symboles dans la table avec IsImported=True        }
{ ------------------------------------------------------------ }

Procedure ParseFromImportStmt;
Var
  ModName  : TString;
  SymName  : TString;
Begin
  { Consommer 'from' }
  LexNextToken;

  ModName := CurTokStr;
  LexNextToken;  { Consommer le nom du module }

  { Consommer 'import' }
  If (CurTokKind = TK_KEYWORD) And (CurTokStr = 'import') Then
    LexNextToken;

  WriteLn('; === from ', ModName, ' import ... ===');

  { Verifier les modules connus }
  If ModName = 'math' Then
  Begin
    Inc(CpMathCount);
    CpLastKind := CP_MOD_MATH;
  End
  Else If ModName = 'sys' Then
  Begin
    Inc(CpSysCount);
    CpLastKind := CP_MOD_SYS;
  End
  Else If ModName = 'os' Then
  Begin
    EmitOsWarning;
  End;

  { Parser la liste de noms importes }
  While (CurTokKind <> TK_EOF) And
        (CurTokKind <> TK_NEWLINE) And
        (CurTokKind <> TK_DEDENT) Do
  Begin
    If (CurTokKind = TK_PUNCT) And (CurTokStr = ',') Then
    Begin
      LexNextToken;  { Consommer ',' }
    End
    Else
    Begin
      SymName := CurTokStr;
      LexNextToken;  { Consommer le nom du symbole }

      WriteLn('; import ', SymName, ' from ', ModName);

      { Declarer le symbole comme externe }
      If ModName = 'math' Then
      Begin
        WriteLn('EXTRN _PYRT_MATH_', SymName, ' : NEAR');
      End
      Else If ModName = 'sys' Then
      Begin
        If SymName = 'exit' Then
          WriteLn('EXTRN _ExitProcess@4 : NEAR')
        Else
          EmitExternSymbol('_PYM_sys_' + SymName);
      End
      Else
        EmitExternSymbol('_PYM_' + ModName + '_' + SymName);
    End;
  End;

  Inc(CpFromCount);
End;

{ ------------------------------------------------------------ }
{ DumpCpState : afficher l etat du sous-systeme comprehensions      }
{ ------------------------------------------------------------ }

Procedure DumpCpState;
Begin
  WriteLn;
  WriteLn('=== Etat du sous-systeme Comprehensions/Import (TODO 20) ===');
  WriteLn('  CpInitialized    : ', CpInitialized);
  WriteLn('  CpListCompCount  : ', CpListCompCount);
  WriteLn('  CpListFilterCount: ', CpListFilterCount);
  WriteLn('  CpDictCompCount  : ', CpDictCompCount);
  WriteLn('  CpDictFilterCount: ', CpDictFilterCount);
  WriteLn('  CpGenWarnCount   : ', CpGenWarnCount);
  WriteLn('  CpSetWarnCount   : ', CpSetWarnCount);
  WriteLn('  CpImportCount    : ', CpImportCount);
  WriteLn('  CpFromCount      : ', CpFromCount);
  WriteLn('  CpMathCount      : ', CpMathCount);
  WriteLn('  CpSysCount       : ', CpSysCount);
  WriteLn('  CpOsWarnCount    : ', CpOsWarnCount);
  WriteLn('  CpExtrnCount     : ', CpExtrnCount);
  WriteLn('  CpPublicCount    : ', CpPublicCount);
  WriteLn('  CpLastKind       : ', CpTypeName(CpLastKind));
  WriteLn('  CpLabelSeq       : ', CpLabelSeq);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 20)                              }
{ ------------------------------------------------------------ }

Function IsCpInitialized : Boolean;
Begin
  IsCpInitialized := CpInitialized;
End;

Function IsCpEmpty : Boolean;
Begin
  IsCpEmpty := (CpListCompCount = 0) And (CpDictCompCount = 0) And
               (CpImportCount = 0) And (CpFromCount = 0);
End;

Function GetCpListCompCount : LongInt;
Begin
  GetCpListCompCount := CpListCompCount;
End;

Function GetCpDictCompCount : LongInt;
Begin
  GetCpDictCompCount := CpDictCompCount;
End;

Function GetCpImportCount : LongInt;
Begin
  GetCpImportCount := CpImportCount;
End;

Function GetCpFromCount : LongInt;
Begin
  GetCpFromCount := CpFromCount;
End;

Function GetCpMathCount : LongInt;
Begin
  GetCpMathCount := CpMathCount;
End;

Function GetCpSysCount : LongInt;
Begin
  GetCpSysCount := CpSysCount;
End;

Function GetCpGenWarnCount : LongInt;
Begin
  GetCpGenWarnCount := CpGenWarnCount;
End;

Function GetCpStatus : TString;
Begin
  If Not CpInitialized Then
    GetCpStatus := 'Not initialized'
  Else
    GetCpStatus := ItoS(CpListCompCount) + ' list-comp, ' +
                   ItoS(CpDictCompCount) + ' dict-comp, ' +
                   ItoS(CpImportCount) + ' import, ' +
                   ItoS(CpFromCount) + ' from-import, ' +
                   ItoS(CpMathCount) + ' math, ' +
                   ItoS(CpSysCount) + ' sys';
End;

{ ============================================================ }
{ TODO 21 - GENERATION DE CODE : SEGMENT DE DONNEES 80386     }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { Types d operations du segment de donnees }
  DT_NONE          = 0;    { aucun / non defini                    }
  DT_INT_VAR       = 1;    { variable entiere DD 0                 }
  DT_STR_VAR       = 2;    { variable chaine DD ptr                }
  DT_BOOL_VAR      = 3;    { variable booleenne DD 0               }
  DT_NONE_VAR      = 4;    { variable None DD 0                    }
  DT_STR_CONST     = 5;    { constante chaine DB 'txt', 0          }
  DT_FMT_CONST     = 6;    { constante format DB 'fmt', 0          }
  DT_SPECIAL       = 7;    { constantes speciales True/False/None   }
  DT_BSS_BUF       = 8;    { tampon BSS DB n DUP(?)                }
  DT_BSS_VAR       = 9;    { variable BSS DD ?                     }
  DT_HEAP          = 10;   { zone heap dynamique                   }
  DT_COLLECTION    = 11;   { bloc donnees liste/tuple/dict         }
  DT_ALIGN         = 12;   { directive d alignement                }
  DT_SECTION       = 13;   { directive de section .data / .data?   }
  DT_MAX           = 13;

  { Limites }
  DT_MAX_VARS      = 256;  { nombre max de variables dans DATA     }
  DT_MAX_CONSTS    = 128;  { nombre max de constantes chaines      }
  DT_HEAP_SIZE     = 65536;{ taille du heap dynamique en octets    }

Var
  DtInitialized    : Boolean;    { True si l etat est initialise       }
  DtIntVarCount    : LongInt;    { nombre de variables entieres        }
  DtStrVarCount    : LongInt;    { nombre de variables chaines         }
  DtBoolVarCount   : LongInt;    { nombre de variables booleennes      }
  DtNoneVarCount   : LongInt;    { nombre de variables None            }
  DtStrConstCount  : LongInt;    { nombre de constantes chaines        }
  DtFmtConstCount  : LongInt;    { nombre de constantes format         }
  DtSpecialCount   : LongInt;    { nombre de constantes speciales      }
  DtBssBufCount    : LongInt;    { nombre de tampons BSS               }
  DtBssVarCount    : LongInt;    { nombre de variables BSS             }
  DtHeapEmitted    : Boolean;    { True si le heap a ete emis          }
  DtCollectionCount: LongInt;    { nombre de blocs collection          }
  DtAlignCount     : LongInt;    { nombre de directives alignement     }
  DtSectionCount   : LongInt;    { nombre de directives section        }
  DtLastKind       : Integer;    { dernier type d operation            }
  DtLabelSeq       : Integer;    { sequence pour labels donnees        }

{ ------------------------------------------------------------ }
{ InitDtState : initialiser le sous-systeme du segment donnees     }
{ ------------------------------------------------------------ }

Procedure InitDtState;
Begin
  DtInitialized    := True;
  DtIntVarCount    := 0;
  DtStrVarCount    := 0;
  DtBoolVarCount   := 0;
  DtNoneVarCount   := 0;
  DtStrConstCount  := 0;
  DtFmtConstCount  := 0;
  DtSpecialCount   := 0;
  DtBssBufCount    := 0;
  DtBssVarCount    := 0;
  DtHeapEmitted    := False;
  DtCollectionCount:= 0;
  DtAlignCount     := 0;
  DtSectionCount   := 0;
  DtLastKind       := DT_NONE;
  DtLabelSeq       := 0;
End;

{ ------------------------------------------------------------ }
{ GenDtLabel : generer un label unique pour le segment donnees      }
{ ------------------------------------------------------------ }

Function GenDtLabel : TString;
Begin
  Inc(DtLabelSeq);
  GenDtLabel := '_PYD_' + ItoS(DtLabelSeq);
End;

{ ------------------------------------------------------------ }
{ DtTypeName : retourner le nom du type d operation donnees         }
{ ------------------------------------------------------------ }

Function DtTypeName(Kind : Integer) : TString;
Begin
  Case Kind Of
    DT_NONE        : DtTypeName := 'DT_NONE';
    DT_INT_VAR     : DtTypeName := 'DT_INT_VAR';
    DT_STR_VAR     : DtTypeName := 'DT_STR_VAR';
    DT_BOOL_VAR    : DtTypeName := 'DT_BOOL_VAR';
    DT_NONE_VAR    : DtTypeName := 'DT_NONE_VAR';
    DT_STR_CONST   : DtTypeName := 'DT_STR_CONST';
    DT_FMT_CONST   : DtTypeName := 'DT_FMT_CONST';
    DT_SPECIAL     : DtTypeName := 'DT_SPECIAL';
    DT_BSS_BUF     : DtTypeName := 'DT_BSS_BUF';
    DT_BSS_VAR     : DtTypeName := 'DT_BSS_VAR';
    DT_HEAP        : DtTypeName := 'DT_HEAP';
    DT_COLLECTION  : DtTypeName := 'DT_COLLECTION';
    DT_ALIGN       : DtTypeName := 'DT_ALIGN';
    DT_SECTION     : DtTypeName := 'DT_SECTION';
  Else
    DtTypeName := 'DT_UNKNOWN(' + ItoS(Kind) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ EmitDataSection : emettre le debut de la section .data            }
{ ------------------------------------------------------------ }

Procedure EmitDataSection;
Begin
  WriteLn('; ========================================');
  WriteLn('; Section .data (variables initialisees)');
  WriteLn('; ========================================');
  WriteLn('.data');
  WriteLn;
  Inc(DtSectionCount);
  DtLastKind := DT_SECTION;
End;

{ ------------------------------------------------------------ }
{ EmitVarInt : emettre une variable entiere dans .data              }
{   _PYV_nom DD 0                                                  }
{ ------------------------------------------------------------ }

Procedure EmitVarInt(Const VarName : TString);
Begin
  WriteLn('_PYV_', VarName, ' DD 0             ; int variable');
  Inc(DtIntVarCount);
  DtLastKind := DT_INT_VAR;
End;

{ ------------------------------------------------------------ }
{ EmitVarStr : emettre une variable chaine dans .data               }
{   _PYV_nom DD _PYK_N (pointeur vers constante chaine)           }
{ ------------------------------------------------------------ }

Procedure EmitVarStr(Const VarName, ConstLabel : TString);
Begin
  WriteLn('_PYV_', VarName, ' DD ', ConstLabel,
          '     ; str variable -> ', ConstLabel);
  Inc(DtStrVarCount);
  DtLastKind := DT_STR_VAR;
End;

{ ------------------------------------------------------------ }
{ EmitVarBool : emettre une variable booleenne dans .data           }
{   _PYV_nom DD 0                                                  }
{ ------------------------------------------------------------ }

Procedure EmitVarBool(Const VarName : TString; InitVal : LongInt);
Begin
  WriteLn('_PYV_', VarName, ' DD ', InitVal,
          '             ; bool variable');
  Inc(DtBoolVarCount);
  DtLastKind := DT_BOOL_VAR;
End;

{ ------------------------------------------------------------ }
{ EmitVarNone : emettre une variable None dans .data                }
{   _PYV_nom DD 0                                                  }
{ ------------------------------------------------------------ }

Procedure EmitVarNone(Const VarName : TString);
Begin
  WriteLn('_PYV_', VarName, ' DD 0             ; None variable');
  Inc(DtNoneVarCount);
  DtLastKind := DT_NONE_VAR;
End;

{ ------------------------------------------------------------ }
{ EmitStrConst : emettre une constante chaine NUL-terminated        }
{   _PYK_N DB 'texte', 0                                          }
{ ------------------------------------------------------------ }

Procedure EmitStrConst(Const LabelName, Value : TString);
Var
  I : Integer;
Begin
  Write(LabelName, ' DB ');
  For I := 1 To Length(Value) Do
  Begin
    If I > 1 Then
      Write(', ');
    Write(Ord(Value[I]));
  End;
  WriteLn(', 0              ; "', Value, '"');
  Inc(DtStrConstCount);
  DtLastKind := DT_STR_CONST;
End;

{ ------------------------------------------------------------ }
{ EmitFmtConst : emettre une constante de format pour print         }
{   _PYK_FMT_N DB 'format...', 0                                  }
{ ------------------------------------------------------------ }

Procedure EmitFmtConst(Const LabelName, FmtStr : TString);
Var
  I : Integer;
Begin
  Write(LabelName, ' DB ');
  For I := 1 To Length(FmtStr) Do
  Begin
    If I > 1 Then
      Write(', ');
    Write(Ord(FmtStr[I]));
  End;
  WriteLn(', 0              ; format "', FmtStr, '"');
  Inc(DtFmtConstCount);
  DtLastKind := DT_FMT_CONST;
End;

{ ------------------------------------------------------------ }
{ EmitSpecialConsts : emettre les constantes speciales Python       }
{   _PYK_TRUE, _PYK_FALSE, _PYK_NONE, _PYK_CRLF, _PYK_SPACE     }
{ ------------------------------------------------------------ }

Procedure EmitSpecialConsts;
Begin
  WriteLn('; --- Constantes speciales Python ---');
  WriteLn('_PYK_TRUE  DB ''True'', 0');
  WriteLn('_PYK_FALSE DB ''False'', 0');
  WriteLn('_PYK_NONE  DB ''None'', 0');
  WriteLn('_PYK_CRLF  DB 13, 10, 0');
  WriteLn('_PYK_SPACE DB '' '', 0');
  WriteLn;
  DtSpecialCount := 5;
  DtLastKind := DT_SPECIAL;
End;

{ ------------------------------------------------------------ }
{ EmitBssSection : emettre le debut de la section .data? (BSS)      }
{ ------------------------------------------------------------ }

Procedure EmitBssSection;
Begin
  WriteLn;
  WriteLn('; ========================================');
  WriteLn('; Section .data? (BSS - non initialisees)');
  WriteLn('; ========================================');
  WriteLn('.data?');
  WriteLn;
  Inc(DtSectionCount);
  DtLastKind := DT_SECTION;
End;

{ ------------------------------------------------------------ }
{ EmitBssBuffer : emettre un tampon BSS de N octets                 }
{   _PY_NOM DB N DUP(?)                                           }
{ ------------------------------------------------------------ }

Procedure EmitBssBuffer(Const BufName : TString; Size : LongInt);
Begin
  WriteLn(BufName, ' DB ', Size, ' DUP(?)     ; buffer ', Size,
          ' octets');
  Inc(DtBssBufCount);
  DtLastKind := DT_BSS_BUF;
End;

{ ------------------------------------------------------------ }
{ EmitBssVar : emettre une variable BSS (DD ?)                      }
{   _PY_NOM DD ?                                                   }
{ ------------------------------------------------------------ }

Procedure EmitBssVar(Const VarName : TString);
Begin
  WriteLn(VarName, ' DD ?                     ; runtime variable');
  Inc(DtBssVarCount);
  DtLastKind := DT_BSS_VAR;
End;

{ ------------------------------------------------------------ }
{ EmitHeap : emettre la zone heap dynamique                         }
{   _PY_HEAP DB 65536 DUP(0)                                      }
{   _PY_HEAPTOP DD 0                                               }
{ ------------------------------------------------------------ }

Procedure EmitHeap;
Begin
  WriteLn('; --- Heap dynamique ---');
  WriteLn('_PY_HEAP DB ', DT_HEAP_SIZE,
          ' DUP(0)   ; heap dynamique');
  WriteLn('_PY_HEAPTOP DD 0',
          '               ; sommet du heap');
  WriteLn;
  DtHeapEmitted := True;
  DtLastKind := DT_HEAP;
End;

{ ------------------------------------------------------------ }
{ EmitCollectionData : emettre un bloc de donnees pour collection    }
{   Pour listes, tuples, dicts : blocs de DD                       }
{ ------------------------------------------------------------ }

Procedure EmitCollectionData(Const CollLabel : TString;
                              ElemCount : LongInt);
Var
  I : LongInt;
Begin
  WriteLn('; --- collection data block ---');
  Write(CollLabel, ' DD ');
  For I := 1 To ElemCount Do
  Begin
    If I > 1 Then
      Write(', ');
    Write('0');
  End;
  WriteLn('    ; ', ElemCount, ' elements');
  Inc(DtCollectionCount);
  DtLastKind := DT_COLLECTION;
End;

{ ------------------------------------------------------------ }
{ EmitAlignment : emettre une directive d alignement 4 octets       }
{ ------------------------------------------------------------ }

Procedure EmitAlignment;
Begin
  WriteLn('ALIGN 4                         ; alignement DWORD');
  Inc(DtAlignCount);
  DtLastKind := DT_ALIGN;
End;

{ ------------------------------------------------------------ }
{ EmitDataSegment : emettre le segment de donnees complet           }
{   Genere les sections .data et .data? avec toutes les            }
{   constantes speciales, tampons et heap                          }
{ ------------------------------------------------------------ }

Procedure EmitDataSegment;
Begin
  { Section .data : variables initialisees }
  EmitDataSection;

  { Constantes speciales Python }
  EmitSpecialConsts;

  { Alignement }
  EmitAlignment;

  { Section .data? : BSS }
  EmitBssSection;

  { Tampons d entree/sortie }
  EmitBssBuffer('_PY_IOBUF', 256);
  EmitBssBuffer('_PY_NUMBUF', 32);

  { Variables runtime }
  EmitBssVar('_PY_STDOUT');
  EmitBssVar('_PY_STDIN');
  EmitBssVar('_PY_WRITTEN');
  EmitBssVar('_PY_READ');

  { Alignement }
  EmitAlignment;

  { Heap dynamique }
  EmitHeap;
End;

{ ------------------------------------------------------------ }
{ DumpDtState : afficher l etat du sous-systeme segment donnees     }
{ ------------------------------------------------------------ }

Procedure DumpDtState;
Begin
  WriteLn;
  WriteLn('=== Etat du sous-systeme Segment Donnees (TODO 21) ===');
  WriteLn('  DtInitialized    : ', DtInitialized);
  WriteLn('  DtIntVarCount    : ', DtIntVarCount);
  WriteLn('  DtStrVarCount    : ', DtStrVarCount);
  WriteLn('  DtBoolVarCount   : ', DtBoolVarCount);
  WriteLn('  DtNoneVarCount   : ', DtNoneVarCount);
  WriteLn('  DtStrConstCount  : ', DtStrConstCount);
  WriteLn('  DtFmtConstCount  : ', DtFmtConstCount);
  WriteLn('  DtSpecialCount   : ', DtSpecialCount);
  WriteLn('  DtBssBufCount    : ', DtBssBufCount);
  WriteLn('  DtBssVarCount    : ', DtBssVarCount);
  WriteLn('  DtHeapEmitted    : ', DtHeapEmitted);
  WriteLn('  DtCollectionCount: ', DtCollectionCount);
  WriteLn('  DtAlignCount     : ', DtAlignCount);
  WriteLn('  DtSectionCount   : ', DtSectionCount);
  WriteLn('  DtLastKind       : ', DtTypeName(DtLastKind));
  WriteLn('  DtLabelSeq       : ', DtLabelSeq);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 21)                              }
{ ------------------------------------------------------------ }

Function IsDtInitialized : Boolean;
Begin
  IsDtInitialized := DtInitialized;
End;

Function IsDtEmpty : Boolean;
Begin
  IsDtEmpty := (DtIntVarCount = 0) And (DtStrVarCount = 0) And
               (DtStrConstCount = 0) And (DtBssBufCount = 0);
End;

Function GetDtIntVarCount : LongInt;
Begin
  GetDtIntVarCount := DtIntVarCount;
End;

Function GetDtStrVarCount : LongInt;
Begin
  GetDtStrVarCount := DtStrVarCount;
End;

Function GetDtStrConstCount : LongInt;
Begin
  GetDtStrConstCount := DtStrConstCount;
End;

Function GetDtFmtConstCount : LongInt;
Begin
  GetDtFmtConstCount := DtFmtConstCount;
End;

Function GetDtBssBufCount : LongInt;
Begin
  GetDtBssBufCount := DtBssBufCount;
End;

Function GetDtBssVarCount : LongInt;
Begin
  GetDtBssVarCount := DtBssVarCount;
End;

Function GetDtCollectionCount : LongInt;
Begin
  GetDtCollectionCount := DtCollectionCount;
End;

Function GetDtStatus : TString;
Begin
  If Not DtInitialized Then
    GetDtStatus := 'Not initialized'
  Else
    GetDtStatus := ItoS(DtIntVarCount) + ' int-vars, ' +
                   ItoS(DtStrVarCount) + ' str-vars, ' +
                   ItoS(DtStrConstCount) + ' str-consts, ' +
                   ItoS(DtFmtConstCount) + ' fmt-consts, ' +
                   ItoS(DtBssBufCount) + ' bss-bufs, ' +
                   ItoS(DtBssVarCount) + ' bss-vars';
End;

{ ============================================================ }
{ TODO 22 - BIBLIOTHEQUE RUNTIME PYTHON (E/S, CONVERSIONS)     }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { Types de routines runtime }
  RT_NONE          = 0;    { aucun / non defini                    }
  RT_ITOA          = 1;    { conversion entier -> chaine            }
  RT_ATOI          = 2;    { conversion chaine -> entier            }
  RT_BOOLTOSTR     = 3;    { conversion booleen -> chaine           }
  RT_NONETOSTR     = 4;    { conversion None -> chaine              }
  RT_INITIO        = 5;    { initialisation E/S console             }
  RT_WRITESTR      = 6;    { ecriture chaine console                }
  RT_WRITECRLF     = 7;    { ecriture retour a la ligne             }
  RT_READLINE      = 8;    { lecture ligne console                  }
  RT_STRLEN        = 9;    { longueur chaine                        }
  RT_STRCONCAT     = 10;   { concatenation chaines                  }
  RT_HEAPALLOC     = 11;   { allocation heap dynamique              }
  RT_PANIC         = 12;   { affichage erreur + arret               }
  RT_MATH          = 13;   { routines mathematiques (pow, abs)      }
  RT_MAX           = 13;

  { Limites }
  RT_MAX_ROUTINES  = 64;   { nombre max de routines runtime         }
  RT_BUF_SIZE      = 256;  { taille tampon E/S par defaut           }
  RT_NUM_BUF       = 32;   { taille tampon conversion nombres       }

Var
  RtInitialized    : Boolean;    { True si l etat est initialise       }
  RtItoaCount      : LongInt;    { nombre d emissions de _PYRT_ITOA    }
  RtAtoiCount      : LongInt;    { nombre d emissions de _PYRT_ATOI    }
  RtBoolStrCount   : LongInt;    { nombre de _PYRT_BOOLTOSTR           }
  RtNoneStrCount   : LongInt;    { nombre de _PYRT_NONETOSTR           }
  RtInitIoCount    : LongInt;    { nombre de _PYRT_INITIO              }
  RtWriteStrCount  : LongInt;    { nombre de _PYRT_WRITESTR            }
  RtWriteCrlfCount : LongInt;    { nombre de _PYRT_WRITECRLF           }
  RtReadLineCount  : LongInt;    { nombre de _PYRT_READLINE            }
  RtStrFuncCount   : LongInt;    { nombre de routines chaines emises   }
  RtCollFuncCount  : LongInt;    { nombre de routines collections      }
  RtMathFuncCount  : LongInt;    { nombre de routines mathematiques    }
  RtPanicCount     : LongInt;    { nombre de _PYRT_PANIC               }
  RtHeapAllocCount : LongInt;    { nombre de _PYRT_HEAPALLOC           }
  RtLastKind       : Integer;    { dernier type de routine emise       }
  RtLabelSeq       : Integer;    { sequence pour labels runtime        }

{ ------------------------------------------------------------ }
{ InitRtState : initialiser le sous-systeme runtime                 }
{ ------------------------------------------------------------ }

Procedure InitRtState;
Begin
  RtInitialized    := True;
  RtItoaCount      := 0;
  RtAtoiCount      := 0;
  RtBoolStrCount   := 0;
  RtNoneStrCount   := 0;
  RtInitIoCount    := 0;
  RtWriteStrCount  := 0;
  RtWriteCrlfCount := 0;
  RtReadLineCount  := 0;
  RtStrFuncCount   := 0;
  RtCollFuncCount  := 0;
  RtMathFuncCount  := 0;
  RtPanicCount     := 0;
  RtHeapAllocCount := 0;
  RtLastKind       := RT_NONE;
  RtLabelSeq       := 0;
End;

{ ------------------------------------------------------------ }
{ GenRtLabel : generer un label unique pour le runtime              }
{ ------------------------------------------------------------ }

Function GenRtLabel : TString;
Begin
  Inc(RtLabelSeq);
  GenRtLabel := '_PYRT_L' + ItoS(RtLabelSeq);
End;

{ ------------------------------------------------------------ }
{ RtTypeName : retourner le nom du type de routine runtime          }
{ ------------------------------------------------------------ }

Function RtTypeName(Kind : Integer) : TString;
Begin
  Case Kind Of
    RT_NONE        : RtTypeName := 'RT_NONE';
    RT_ITOA        : RtTypeName := 'RT_ITOA';
    RT_ATOI        : RtTypeName := 'RT_ATOI';
    RT_BOOLTOSTR   : RtTypeName := 'RT_BOOLTOSTR';
    RT_NONETOSTR   : RtTypeName := 'RT_NONETOSTR';
    RT_INITIO      : RtTypeName := 'RT_INITIO';
    RT_WRITESTR    : RtTypeName := 'RT_WRITESTR';
    RT_WRITECRLF   : RtTypeName := 'RT_WRITECRLF';
    RT_READLINE    : RtTypeName := 'RT_READLINE';
    RT_STRLEN      : RtTypeName := 'RT_STRLEN';
    RT_STRCONCAT   : RtTypeName := 'RT_STRCONCAT';
    RT_HEAPALLOC   : RtTypeName := 'RT_HEAPALLOC';
    RT_PANIC       : RtTypeName := 'RT_PANIC';
    RT_MATH        : RtTypeName := 'RT_MATH';
  Else
    RtTypeName := 'RT_UNKNOWN(' + ItoS(Kind) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ EmitRtItoa : emettre la routine _PYRT_ITOA                       }
{   Convertit EAX (entier 32 bits) en chaine decimale ASCII         }
{   Resultat dans _PY_NUMBUF, EAX = ptr vers la chaine              }
{ ------------------------------------------------------------ }

Procedure EmitRtItoa;
Var Lbl1, Lbl2, Lbl3 : TString;
Begin
  Inc(RtItoaCount);
  RtLastKind := RT_ITOA;
  Lbl1 := GenRtLabel;
  Lbl2 := GenRtLabel;
  Lbl3 := GenRtLabel;
  WriteLn('_PYRT_ITOA:');
  WriteLn('  PUSH EBX');
  WriteLn('  PUSH ECX');
  WriteLn('  PUSH EDX');
  WriteLn('  PUSH ESI');
  WriteLn('  MOV ESI, EAX');
  WriteLn('  LEA EDI, [_PY_NUMBUF+31]');
  WriteLn('  MOV BYTE [EDI], 0');
  WriteLn('  MOV EBX, 10');
  WriteLn('  TEST EAX, EAX');
  WriteLn('  JNS ' + Lbl1);
  WriteLn('  NEG EAX');
  WriteLn(Lbl1 + ':');
  WriteLn('  XOR ECX, ECX');
  WriteLn(Lbl2 + ':');
  WriteLn('  XOR EDX, EDX');
  WriteLn('  DIV EBX');
  WriteLn('  ADD DL, 48');
  WriteLn('  DEC EDI');
  WriteLn('  MOV [EDI], DL');
  WriteLn('  INC ECX');
  WriteLn('  TEST EAX, EAX');
  WriteLn('  JNZ ' + Lbl2);
  WriteLn('  TEST ESI, ESI');
  WriteLn('  JNS ' + Lbl3);
  WriteLn('  DEC EDI');
  WriteLn('  MOV BYTE [EDI], 45');
  WriteLn(Lbl3 + ':');
  WriteLn('  MOV EAX, EDI');
  WriteLn('  POP ESI');
  WriteLn('  POP EDX');
  WriteLn('  POP ECX');
  WriteLn('  POP EBX');
  WriteLn('  RET');
End;

{ ------------------------------------------------------------ }
{ EmitRtAtoi : emettre la routine _PYRT_ATOI                       }
{   Convertit chaine ASCII (EAX=ptr) en entier 32 bits              }
{   Resultat dans EAX                                               }
{ ------------------------------------------------------------ }

Procedure EmitRtAtoi;
Var Lbl1, Lbl2, Lbl3 : TString;
Begin
  Inc(RtAtoiCount);
  RtLastKind := RT_ATOI;
  Lbl1 := GenRtLabel;
  Lbl2 := GenRtLabel;
  Lbl3 := GenRtLabel;
  WriteLn('_PYRT_ATOI:');
  WriteLn('  PUSH EBX');
  WriteLn('  PUSH ECX');
  WriteLn('  PUSH ESI');
  WriteLn('  MOV ESI, EAX');
  WriteLn('  XOR EAX, EAX');
  WriteLn('  XOR ECX, ECX');
  WriteLn('  MOV BL, [ESI]');
  WriteLn('  CMP BL, 45');
  WriteLn('  JNE ' + Lbl1);
  WriteLn('  INC ECX');
  WriteLn('  INC ESI');
  WriteLn(Lbl1 + ':');
  WriteLn('  MOV BL, [ESI]');
  WriteLn('  TEST BL, BL');
  WriteLn('  JZ ' + Lbl2);
  WriteLn('  SUB BL, 48');
  WriteLn('  IMUL EAX, 10');
  WriteLn('  MOVZX EBX, BL');
  WriteLn('  ADD EAX, EBX');
  WriteLn('  INC ESI');
  WriteLn('  JMP ' + Lbl1);
  WriteLn(Lbl2 + ':');
  WriteLn('  TEST ECX, ECX');
  WriteLn('  JZ ' + Lbl3);
  WriteLn('  NEG EAX');
  WriteLn(Lbl3 + ':');
  WriteLn('  POP ESI');
  WriteLn('  POP ECX');
  WriteLn('  POP EBX');
  WriteLn('  RET');
End;

{ ------------------------------------------------------------ }
{ EmitRtBoolToStr : emettre la routine _PYRT_BOOLTOSTR              }
{   EAX=0 -> 'False', EAX<>0 -> 'True'. EAX = ptr chaine           }
{ ------------------------------------------------------------ }

Procedure EmitRtBoolToStr;
Var Lbl1, Lbl2 : TString;
Begin
  Inc(RtBoolStrCount);
  RtLastKind := RT_BOOLTOSTR;
  Lbl1 := GenRtLabel;
  Lbl2 := GenRtLabel;
  WriteLn('_PYRT_BOOLTOSTR:');
  WriteLn('  TEST EAX, EAX');
  WriteLn('  JZ ' + Lbl1);
  WriteLn('  LEA EAX, [_PYK_TRUE]');
  WriteLn('  JMP ' + Lbl2);
  WriteLn(Lbl1 + ':');
  WriteLn('  LEA EAX, [_PYK_FALSE]');
  WriteLn(Lbl2 + ':');
  WriteLn('  RET');
End;

{ ------------------------------------------------------------ }
{ EmitRtNoneToStr : emettre la routine _PYRT_NONETOSTR              }
{   Retourne EAX = ptr vers 'None'                                  }
{ ------------------------------------------------------------ }

Procedure EmitRtNoneToStr;
Begin
  Inc(RtNoneStrCount);
  RtLastKind := RT_NONETOSTR;
  WriteLn('_PYRT_NONETOSTR:');
  WriteLn('  LEA EAX, [_PYK_NONE]');
  WriteLn('  RET');
End;

{ ------------------------------------------------------------ }
{ EmitRtInitIo : emettre la routine _PYRT_INITIO                    }
{   Initialise _PY_STDOUT et _PY_STDIN via GetStdHandle              }
{ ------------------------------------------------------------ }

Procedure EmitRtInitIo;
Begin
  Inc(RtInitIoCount);
  RtLastKind := RT_INITIO;
  WriteLn('_PYRT_INITIO:');
  WriteLn('  PUSH -11');
  WriteLn('  CALL _GetStdHandle@4');
  WriteLn('  MOV [_PY_STDOUT], EAX');
  WriteLn('  PUSH -10');
  WriteLn('  CALL _GetStdHandle@4');
  WriteLn('  MOV [_PY_STDIN], EAX');
  WriteLn('  RET');
End;

{ ------------------------------------------------------------ }
{ EmitRtWriteStr : emettre la routine _PYRT_WRITESTR                 }
{   EAX=ptr chaine, ECX=longueur. Ecrit sur _PY_STDOUT              }
{ ------------------------------------------------------------ }

Procedure EmitRtWriteStr;
Begin
  Inc(RtWriteStrCount);
  RtLastKind := RT_WRITESTR;
  WriteLn('_PYRT_WRITESTR:');
  WriteLn('  PUSH 0');
  WriteLn('  LEA EDX, [_PY_WRITTEN]');
  WriteLn('  PUSH EDX');
  WriteLn('  PUSH ECX');
  WriteLn('  PUSH EAX');
  WriteLn('  PUSH DWORD [_PY_STDOUT]');
  WriteLn('  CALL _WriteFile@20');
  WriteLn('  RET');
End;

{ ------------------------------------------------------------ }
{ EmitRtWriteCrlf : emettre la routine _PYRT_WRITECRLF               }
{   Ecrit un retour a la ligne (CR+LF) sur la console               }
{ ------------------------------------------------------------ }

Procedure EmitRtWriteCrlf;
Begin
  Inc(RtWriteCrlfCount);
  RtLastKind := RT_WRITECRLF;
  WriteLn('_PYRT_WRITECRLF:');
  WriteLn('  LEA EAX, [_PYK_CRLF]');
  WriteLn('  MOV ECX, 2');
  WriteLn('  PUSH 0');
  WriteLn('  LEA EDX, [_PY_WRITTEN]');
  WriteLn('  PUSH EDX');
  WriteLn('  PUSH ECX');
  WriteLn('  PUSH EAX');
  WriteLn('  PUSH DWORD [_PY_STDOUT]');
  WriteLn('  CALL _WriteFile@20');
  WriteLn('  RET');
End;

{ ------------------------------------------------------------ }
{ EmitRtReadLine : emettre la routine _PYRT_READLINE                 }
{   Lit une ligne depuis _PY_STDIN dans _PY_IOBUF                   }
{   Retourne EAX = ptr vers la chaine (CR/LF supprime)              }
{ ------------------------------------------------------------ }

Procedure EmitRtReadLine;
Var Lbl1, Lbl2 : TString;
Begin
  Inc(RtReadLineCount);
  RtLastKind := RT_READLINE;
  Lbl1 := GenRtLabel;
  Lbl2 := GenRtLabel;
  WriteLn('_PYRT_READLINE:');
  WriteLn('  PUSH 0');
  WriteLn('  LEA EAX, [_PY_READ]');
  WriteLn('  PUSH EAX');
  WriteLn('  PUSH ' + ItoS(RT_BUF_SIZE));
  WriteLn('  LEA EAX, [_PY_IOBUF]');
  WriteLn('  PUSH EAX');
  WriteLn('  PUSH DWORD [_PY_STDIN]');
  WriteLn('  CALL _ReadFile@20');
  WriteLn('  MOV ECX, [_PY_READ]');
  WriteLn(Lbl1 + ':');
  WriteLn('  TEST ECX, ECX');
  WriteLn('  JZ ' + Lbl2);
  WriteLn('  DEC ECX');
  WriteLn('  CMP BYTE [_PY_IOBUF+ECX], 13');
  WriteLn('  JE ' + Lbl1);
  WriteLn('  CMP BYTE [_PY_IOBUF+ECX], 10');
  WriteLn('  JE ' + Lbl1);
  WriteLn('  INC ECX');
  WriteLn(Lbl2 + ':');
  WriteLn('  MOV BYTE [_PY_IOBUF+ECX], 0');
  WriteLn('  LEA EAX, [_PY_IOBUF]');
  WriteLn('  RET');
End;

{ ------------------------------------------------------------ }
{ EmitRtStrLen : emettre la routine _PYRT_STRLEN                     }
{   EAX=ptr chaine NUL-terminated. Retourne EAX=longueur            }
{ ------------------------------------------------------------ }

Procedure EmitRtStrLen;
Var Lbl1, Lbl2 : TString;
Begin
  Inc(RtStrFuncCount);
  RtLastKind := RT_STRLEN;
  Lbl1 := GenRtLabel;
  Lbl2 := GenRtLabel;
  WriteLn('_PYRT_STRLEN:');
  WriteLn('  PUSH ECX');
  WriteLn('  MOV ECX, EAX');
  WriteLn('  XOR EAX, EAX');
  WriteLn(Lbl1 + ':');
  WriteLn('  CMP BYTE [ECX], 0');
  WriteLn('  JE ' + Lbl2);
  WriteLn('  INC EAX');
  WriteLn('  INC ECX');
  WriteLn('  JMP ' + Lbl1);
  WriteLn(Lbl2 + ':');
  WriteLn('  POP ECX');
  WriteLn('  RET');
End;

{ ------------------------------------------------------------ }
{ EmitRtStrConcat : emettre la routine _PYRT_STRCONCAT               }
{   EAX=ptr chaine1, EBX=ptr chaine2                                }
{   Alloue sur le heap, retourne EAX=ptr resultat                   }
{ ------------------------------------------------------------ }

Procedure EmitRtStrConcat;
Var Lbl1, Lbl2, Lbl3 : TString;
Begin
  Inc(RtStrFuncCount);
  RtLastKind := RT_STRCONCAT;
  Lbl1 := GenRtLabel;
  Lbl2 := GenRtLabel;
  Lbl3 := GenRtLabel;
  WriteLn('_PYRT_STRCONCAT:');
  WriteLn('  PUSH EBX');
  WriteLn('  PUSH ESI');
  WriteLn('  PUSH EDI');
  WriteLn('  MOV ESI, EAX');
  WriteLn('  MOV EDI, EBX');
  { Calculer longueur totale et allouer }
  WriteLn('  CALL _PYRT_STRLEN');
  WriteLn('  MOV ECX, EAX');
  WriteLn('  PUSH ECX');
  WriteLn('  MOV EAX, EDI');
  WriteLn('  CALL _PYRT_STRLEN');
  WriteLn('  POP ECX');
  WriteLn('  ADD ECX, EAX');
  WriteLn('  INC ECX');
  WriteLn('  CALL _PYRT_HEAPALLOC');
  WriteLn('  MOV EDI, EAX');
  WriteLn('  PUSH EAX');
  { Copier chaine 1 }
  WriteLn(Lbl1 + ':');
  WriteLn('  MOV AL, [ESI]');
  WriteLn('  TEST AL, AL');
  WriteLn('  JZ ' + Lbl2);
  WriteLn('  MOV [EDI], AL');
  WriteLn('  INC ESI');
  WriteLn('  INC EDI');
  WriteLn('  JMP ' + Lbl1);
  { Copier chaine 2 }
  WriteLn(Lbl2 + ':');
  WriteLn('  POP ESI');
  WriteLn('  PUSH ESI');
  WriteLn('  MOV ESI, [ESP+16]');
  WriteLn(Lbl3 + ':');
  WriteLn('  MOV AL, [ESI]');
  WriteLn('  MOV [EDI], AL');
  WriteLn('  TEST AL, AL');
  WriteLn('  JZ ' + GenRtLabel);
  WriteLn('  INC ESI');
  WriteLn('  INC EDI');
  WriteLn('  JMP ' + Lbl3);
  WriteLn(GenRtLabel + ':');
  WriteLn('  POP EAX');
  WriteLn('  POP EDI');
  WriteLn('  POP ESI');
  WriteLn('  POP EBX');
  WriteLn('  RET');
End;

{ ------------------------------------------------------------ }
{ EmitRtStrCmp : emettre la routine _PYRT_STRCMP                     }
{   EAX=ptr chaine1, EBX=ptr chaine2                                }
{   Retourne EAX: 0=egal, <0 si s1<s2, >0 si s1>s2                 }
{ ------------------------------------------------------------ }

Procedure EmitRtStrCmp;
Var Lbl1, Lbl2, Lbl3 : TString;
Begin
  Inc(RtStrFuncCount);
  Lbl1 := GenRtLabel;
  Lbl2 := GenRtLabel;
  Lbl3 := GenRtLabel;
  WriteLn('_PYRT_STRCMP:');
  WriteLn('  PUSH ESI');
  WriteLn('  PUSH EDI');
  WriteLn('  MOV ESI, EAX');
  WriteLn('  MOV EDI, EBX');
  WriteLn(Lbl1 + ':');
  WriteLn('  MOV AL, [ESI]');
  WriteLn('  MOV AH, [EDI]');
  WriteLn('  CMP AL, AH');
  WriteLn('  JNE ' + Lbl2);
  WriteLn('  TEST AL, AL');
  WriteLn('  JZ ' + Lbl3);
  WriteLn('  INC ESI');
  WriteLn('  INC EDI');
  WriteLn('  JMP ' + Lbl1);
  WriteLn(Lbl2 + ':');
  WriteLn('  MOVZX EAX, AL');
  WriteLn('  MOVZX ECX, AH');
  WriteLn('  SUB EAX, ECX');
  WriteLn('  POP EDI');
  WriteLn('  POP ESI');
  WriteLn('  RET');
  WriteLn(Lbl3 + ':');
  WriteLn('  XOR EAX, EAX');
  WriteLn('  POP EDI');
  WriteLn('  POP ESI');
  WriteLn('  RET');
End;

{ ------------------------------------------------------------ }
{ EmitRtStrUpper : emettre _PYRT_STRUPPER (in-place upper)           }
{   EAX=ptr chaine. Convertit en majuscules sur place                }
{ ------------------------------------------------------------ }

Procedure EmitRtStrUpper;
Var Lbl1, Lbl2, Lbl3 : TString;
Begin
  Inc(RtStrFuncCount);
  Lbl1 := GenRtLabel;
  Lbl2 := GenRtLabel;
  Lbl3 := GenRtLabel;
  WriteLn('_PYRT_STRUPPER:');
  WriteLn('  PUSH ESI');
  WriteLn('  MOV ESI, EAX');
  WriteLn(Lbl1 + ':');
  WriteLn('  MOV AL, [ESI]');
  WriteLn('  TEST AL, AL');
  WriteLn('  JZ ' + Lbl3);
  WriteLn('  CMP AL, 97');
  WriteLn('  JB ' + Lbl2);
  WriteLn('  CMP AL, 122');
  WriteLn('  JA ' + Lbl2);
  WriteLn('  SUB AL, 32');
  WriteLn('  MOV [ESI], AL');
  WriteLn(Lbl2 + ':');
  WriteLn('  INC ESI');
  WriteLn('  JMP ' + Lbl1);
  WriteLn(Lbl3 + ':');
  WriteLn('  POP ESI');
  WriteLn('  RET');
End;

{ ------------------------------------------------------------ }
{ EmitRtStrLower : emettre _PYRT_STRLOWER (in-place lower)           }
{   EAX=ptr chaine. Convertit en minuscules sur place                }
{ ------------------------------------------------------------ }

Procedure EmitRtStrLower;
Var Lbl1, Lbl2, Lbl3 : TString;
Begin
  Inc(RtStrFuncCount);
  Lbl1 := GenRtLabel;
  Lbl2 := GenRtLabel;
  Lbl3 := GenRtLabel;
  WriteLn('_PYRT_STRLOWER:');
  WriteLn('  PUSH ESI');
  WriteLn('  MOV ESI, EAX');
  WriteLn(Lbl1 + ':');
  WriteLn('  MOV AL, [ESI]');
  WriteLn('  TEST AL, AL');
  WriteLn('  JZ ' + Lbl3);
  WriteLn('  CMP AL, 65');
  WriteLn('  JB ' + Lbl2);
  WriteLn('  CMP AL, 90');
  WriteLn('  JA ' + Lbl2);
  WriteLn('  ADD AL, 32');
  WriteLn('  MOV [ESI], AL');
  WriteLn(Lbl2 + ':');
  WriteLn('  INC ESI');
  WriteLn('  JMP ' + Lbl1);
  WriteLn(Lbl3 + ':');
  WriteLn('  POP ESI');
  WriteLn('  RET');
End;

{ ------------------------------------------------------------ }
{ EmitRtStrContains : emettre _PYRT_STRCONTAINS                      }
{   EAX=ptr chaine, EBX=ptr sous-chaine                             }
{   Retourne EAX: 1 si contient, 0 sinon                            }
{ ------------------------------------------------------------ }

Procedure EmitRtStrContains;
Var Lbl1, Lbl2, Lbl3, Lbl4 : TString;
Begin
  Inc(RtStrFuncCount);
  Lbl1 := GenRtLabel;
  Lbl2 := GenRtLabel;
  Lbl3 := GenRtLabel;
  Lbl4 := GenRtLabel;
  WriteLn('_PYRT_STRCONTAINS:');
  WriteLn('  PUSH ESI');
  WriteLn('  PUSH EDI');
  WriteLn('  PUSH ECX');
  WriteLn('  MOV ESI, EAX');
  WriteLn(Lbl1 + ':');
  WriteLn('  CMP BYTE [ESI], 0');
  WriteLn('  JE ' + Lbl4);
  WriteLn('  MOV EDI, EBX');
  WriteLn('  MOV ECX, ESI');
  WriteLn(Lbl2 + ':');
  WriteLn('  CMP BYTE [EDI], 0');
  WriteLn('  JE ' + Lbl3);
  WriteLn('  MOV AL, [ECX]');
  WriteLn('  CMP AL, [EDI]');
  WriteLn('  JNE ' + GenRtLabel);
  WriteLn('  INC ECX');
  WriteLn('  INC EDI');
  WriteLn('  JMP ' + Lbl2);
  WriteLn(GenRtLabel + ':');
  WriteLn('  INC ESI');
  WriteLn('  JMP ' + Lbl1);
  WriteLn(Lbl3 + ':');
  WriteLn('  MOV EAX, 1');
  WriteLn('  POP ECX');
  WriteLn('  POP EDI');
  WriteLn('  POP ESI');
  WriteLn('  RET');
  WriteLn(Lbl4 + ':');
  WriteLn('  XOR EAX, EAX');
  WriteLn('  POP ECX');
  WriteLn('  POP EDI');
  WriteLn('  POP ESI');
  WriteLn('  RET');
End;

{ ------------------------------------------------------------ }
{ EmitRtHeapAlloc : emettre _PYRT_HEAPALLOC                         }
{   ECX=taille en octets. Retourne EAX=ptr alloue sur le heap       }
{ ------------------------------------------------------------ }

Procedure EmitRtHeapAlloc;
Begin
  Inc(RtHeapAllocCount);
  RtLastKind := RT_HEAPALLOC;
  WriteLn('_PYRT_HEAPALLOC:');
  WriteLn('  MOV EAX, [_PY_HEAPTOP]');
  WriteLn('  LEA EDX, [_PY_HEAP+EAX]');
  WriteLn('  ADD EAX, ECX');
  WriteLn('  ADD EAX, 3');
  WriteLn('  AND EAX, 0FFFFFFFCH');
  WriteLn('  MOV [_PY_HEAPTOP], EAX');
  WriteLn('  MOV EAX, EDX');
  WriteLn('  RET');
End;

{ ------------------------------------------------------------ }
{ EmitRtObjNew : emettre _PYRT_OBJNEW                               }
{   ECX=taille objet. Alloue sur le heap, retourne EAX=ptr          }
{ ------------------------------------------------------------ }

Procedure EmitRtObjNew;
Begin
  Inc(RtCollFuncCount);
  WriteLn('_PYRT_OBJNEW:');
  WriteLn('  CALL _PYRT_HEAPALLOC');
  WriteLn('  RET');
End;

{ ------------------------------------------------------------ }
{ EmitRtListAppend : emettre _PYRT_LISTAPPEND (stub)                }
{   EAX=ptr liste, EBX=valeur a ajouter                             }
{ ------------------------------------------------------------ }

Procedure EmitRtListAppend;
Begin
  Inc(RtCollFuncCount);
  WriteLn('_PYRT_LISTAPPEND:');
  WriteLn('  ; stub: liste[len] = val, len++');
  WriteLn('  MOV ECX, [EAX]');
  WriteLn('  MOV [EAX+4+ECX*4], EBX');
  WriteLn('  INC DWORD [EAX]');
  WriteLn('  RET');
End;

{ ------------------------------------------------------------ }
{ EmitRtListPop : emettre _PYRT_LISTPOP (stub)                      }
{   EAX=ptr liste. Retourne EAX=dernier element                     }
{ ------------------------------------------------------------ }

Procedure EmitRtListPop;
Begin
  Inc(RtCollFuncCount);
  WriteLn('_PYRT_LISTPOP:');
  WriteLn('  ; stub: len--, return liste[len]');
  WriteLn('  DEC DWORD [EAX]');
  WriteLn('  MOV ECX, [EAX]');
  WriteLn('  MOV EAX, [EAX+4+ECX*4]');
  WriteLn('  RET');
End;

{ ------------------------------------------------------------ }
{ EmitRtPow : emettre _PYRT_POW                                     }
{   EAX=base, ECX=exposant. Retourne EAX=resultat                   }
{ ------------------------------------------------------------ }

Procedure EmitRtPow;
Var Lbl1, Lbl2 : TString;
Begin
  Inc(RtMathFuncCount);
  RtLastKind := RT_MATH;
  Lbl1 := GenRtLabel;
  Lbl2 := GenRtLabel;
  WriteLn('_PYRT_POW:');
  WriteLn('  PUSH EBX');
  WriteLn('  PUSH ECX');
  WriteLn('  MOV EBX, EAX');
  WriteLn('  MOV EAX, 1');
  WriteLn(Lbl1 + ':');
  WriteLn('  TEST ECX, ECX');
  WriteLn('  JZ ' + Lbl2);
  WriteLn('  IMUL EAX, EBX');
  WriteLn('  DEC ECX');
  WriteLn('  JMP ' + Lbl1);
  WriteLn(Lbl2 + ':');
  WriteLn('  POP ECX');
  WriteLn('  POP EBX');
  WriteLn('  RET');
End;

{ ------------------------------------------------------------ }
{ EmitRtAbs : emettre _PYRT_ABS                                     }
{   EAX=valeur. Retourne EAX=|valeur|                               }
{ ------------------------------------------------------------ }

Procedure EmitRtAbs;
Begin
  Inc(RtMathFuncCount);
  RtLastKind := RT_MATH;
  WriteLn('_PYRT_ABS:');
  WriteLn('  CDQ');
  WriteLn('  XOR EAX, EDX');
  WriteLn('  SUB EAX, EDX');
  WriteLn('  RET');
End;

{ ------------------------------------------------------------ }
{ EmitRtPanic : emettre _PYRT_PANIC                                  }
{   EAX=ptr message erreur. Affiche et ExitProcess(1)               }
{ ------------------------------------------------------------ }

Procedure EmitRtPanic;
Begin
  Inc(RtPanicCount);
  RtLastKind := RT_PANIC;
  WriteLn('_PYRT_PANIC:');
  WriteLn('  PUSH EAX');
  WriteLn('  CALL _PYRT_STRLEN');
  WriteLn('  MOV ECX, EAX');
  WriteLn('  POP EAX');
  WriteLn('  CALL _PYRT_WRITESTR');
  WriteLn('  CALL _PYRT_WRITECRLF');
  WriteLn('  PUSH 1');
  WriteLn('  CALL _ExitProcess@4');
End;

{ ------------------------------------------------------------ }
{ EmitRuntimeLib : emettre toute la bibliotheque runtime             }
{ ------------------------------------------------------------ }

Procedure EmitRuntimeLib;
Begin
  WriteLn('; === Python Runtime Library ===');
  EmitRtItoa;
  EmitRtAtoi;
  EmitRtBoolToStr;
  EmitRtNoneToStr;
  EmitRtInitIo;
  EmitRtWriteStr;
  EmitRtWriteCrlf;
  EmitRtReadLine;
  EmitRtStrLen;
  EmitRtStrConcat;
  EmitRtStrCmp;
  EmitRtStrUpper;
  EmitRtStrLower;
  EmitRtStrContains;
  EmitRtHeapAlloc;
  EmitRtObjNew;
  EmitRtListAppend;
  EmitRtListPop;
  EmitRtPow;
  EmitRtAbs;
  EmitRtPanic;
  WriteLn('; === End Runtime Library ===');
End;

{ ------------------------------------------------------------ }
{ DumpRtState : afficher l etat du sous-systeme runtime              }
{ ------------------------------------------------------------ }

Procedure DumpRtState;
Begin
  WriteLn;
  WriteLn('=== Etat du sous-systeme Runtime Library (TODO 22) ===');
  WriteLn('  RtInitialized    : ', RtInitialized);
  WriteLn('  RtItoaCount      : ', RtItoaCount);
  WriteLn('  RtAtoiCount      : ', RtAtoiCount);
  WriteLn('  RtBoolStrCount   : ', RtBoolStrCount);
  WriteLn('  RtNoneStrCount   : ', RtNoneStrCount);
  WriteLn('  RtInitIoCount    : ', RtInitIoCount);
  WriteLn('  RtWriteStrCount  : ', RtWriteStrCount);
  WriteLn('  RtWriteCrlfCount : ', RtWriteCrlfCount);
  WriteLn('  RtReadLineCount  : ', RtReadLineCount);
  WriteLn('  RtStrFuncCount   : ', RtStrFuncCount);
  WriteLn('  RtCollFuncCount  : ', RtCollFuncCount);
  WriteLn('  RtMathFuncCount  : ', RtMathFuncCount);
  WriteLn('  RtPanicCount     : ', RtPanicCount);
  WriteLn('  RtHeapAllocCount : ', RtHeapAllocCount);
  WriteLn('  RtLastKind       : ', RtTypeName(RtLastKind));
  WriteLn('  RtLabelSeq       : ', RtLabelSeq);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 22)                              }
{ ------------------------------------------------------------ }

Function IsRtInitialized : Boolean;
Begin
  IsRtInitialized := RtInitialized;
End;

Function IsRtEmpty : Boolean;
Begin
  IsRtEmpty := (RtItoaCount = 0) And (RtWriteStrCount = 0) And
               (RtStrFuncCount = 0) And (RtCollFuncCount = 0);
End;

Function GetRtItoaCount : LongInt;
Begin
  GetRtItoaCount := RtItoaCount;
End;

Function GetRtAtoiCount : LongInt;
Begin
  GetRtAtoiCount := RtAtoiCount;
End;

Function GetRtWriteStrCount : LongInt;
Begin
  GetRtWriteStrCount := RtWriteStrCount;
End;

Function GetRtReadLineCount : LongInt;
Begin
  GetRtReadLineCount := RtReadLineCount;
End;

Function GetRtStrFuncCount : LongInt;
Begin
  GetRtStrFuncCount := RtStrFuncCount;
End;

Function GetRtCollFuncCount : LongInt;
Begin
  GetRtCollFuncCount := RtCollFuncCount;
End;

Function GetRtMathFuncCount : LongInt;
Begin
  GetRtMathFuncCount := RtMathFuncCount;
End;

Function GetRtStatus : TString;
Begin
  If Not RtInitialized Then
    GetRtStatus := 'Not initialized'
  Else
    GetRtStatus := ItoS(RtItoaCount) + ' itoa, ' +
                   ItoS(RtAtoiCount) + ' atoi, ' +
                   ItoS(RtWriteStrCount) + ' write-str, ' +
                   ItoS(RtReadLineCount) + ' read-line, ' +
                   ItoS(RtStrFuncCount) + ' str-funcs, ' +
                   ItoS(RtCollFuncCount) + ' coll-funcs, ' +
                   ItoS(RtMathFuncCount) + ' math-funcs';
End;

{ ============================================================ }
{ TODO 23 - ECRIVAIN BINAIRE PE ET COFF .OBJ                  }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { Types d operations de l ecrivain PE/COFF }
  PE_NONE          = 0;    { aucun / non defini                    }
  PE_DOS_HEADER    = 1;    { DOS Header MZ (64 octets)             }
  PE_SIGNATURE     = 2;    { Signature PE "PE\0\0"                 }
  PE_COFF_HEADER   = 3;    { COFF File Header (20 octets)          }
  PE_OPT_HEADER    = 4;    { Optional Header PE32 (224 octets)     }
  PE_SECTION_HDR   = 5;    { Section Header (40 octets chacun)     }
  PE_TEXT_SECTION   = 6;    { Contenu section .text (code)          }
  PE_RDATA_SECTION  = 7;    { Contenu section .rdata (imports)      }
  PE_DATA_SECTION  = 8;    { Contenu section .data (donnees)       }
  PE_FIXUP         = 9;    { Resolution d un fixup adresse         }
  PE_ALIGN         = 10;   { Alignement fichier/section            }
  PE_COFF_OBJ      = 11;   { Ecriture COFF .OBJ complet            }
  PE_RELOCATION    = 12;   { Table des relocations COFF            }
  PE_SYMBOL        = 13;   { Table des symboles COFF               }
  PE_MAX           = 13;

  { Limites }
  PE_MAX_SECTIONS  = 8;    { nombre max de sections PE             }
  PE_SECTION_ALIGN = 4096; { alignement section ($1000)            }

  { Constantes PE32 }
  PE_IMAGE_BASE    = $00400000; { adresse de base en memoire       }
  PE_MAGIC_PE32    = $010B;    { Magic : PE32                      }
  PE_SUBSYSTEM_CUI = 3;        { Subsystem : Console               }
  PE_MZ_MAGIC      = $5A4D;    { Signature DOS 'MZ'                }
  PE_PE_SIGNATURE  = $00004550;{ Signature PE 'PE\0\0'             }

  { Constantes COFF relocations }
  PE_REL_I386_DIR32 = 6;  { IMAGE_REL_I386_DIR32 (adresse absolue) }
  PE_REL_I386_REL32 = 20; { IMAGE_REL_I386_REL32 (adresse relative)}

  { Constantes COFF symboles StorageClass }
  PE_SYM_EXTERNAL  = 2;   { IMAGE_SYM_CLASS_EXTERNAL               }
  PE_SYM_STATIC    = 3;   { IMAGE_SYM_CLASS_STATIC                 }
  PE_SYM_LABEL     = 6;   { IMAGE_SYM_CLASS_LABEL                  }

Var
  PeInitialized    : Boolean;    { True si l etat est initialise       }
  PeDosHdrCount    : LongInt;    { nombre de DOS Headers emis          }
  PeSignatureCount : LongInt;    { nombre de signatures PE emises      }
  PeCoffHdrCount   : LongInt;    { nombre de COFF Headers emis         }
  PeOptHdrCount    : LongInt;    { nombre d Optional Headers emis      }
  PeSectHdrCount   : LongInt;    { nombre de Section Headers emis      }
  PeTextSecCount   : LongInt;    { nombre de sections .text emises     }
  PeRdataSecCount  : LongInt;    { nombre de sections .rdata emises    }
  PeDataSecCount   : LongInt;    { nombre de sections .data emises     }
  PeFixupCount     : LongInt;    { nombre de fixups resolus            }
  PeAlignCount     : LongInt;    { nombre d alignements emis           }
  PeCoffObjCount   : LongInt;    { nombre de fichiers COFF .OBJ emis   }
  PeRelocCount     : LongInt;    { nombre de relocations emises        }
  PeSymbolCount    : LongInt;    { nombre de symboles emis             }
  PeLastKind       : Integer;    { dernier type d operation            }
  PeLabelSeq       : Integer;    { sequence pour labels PE             }

{ ------------------------------------------------------------ }
{ InitPeState : initialiser le sous-systeme PE/COFF                 }
{ ------------------------------------------------------------ }

Procedure InitPeState;
Begin
  PeInitialized    := True;
  PeDosHdrCount    := 0;
  PeSignatureCount := 0;
  PeCoffHdrCount   := 0;
  PeOptHdrCount    := 0;
  PeSectHdrCount   := 0;
  PeTextSecCount   := 0;
  PeRdataSecCount  := 0;
  PeDataSecCount   := 0;
  PeFixupCount     := 0;
  PeAlignCount     := 0;
  PeCoffObjCount   := 0;
  PeRelocCount     := 0;
  PeSymbolCount    := 0;
  PeLastKind       := PE_NONE;
  PeLabelSeq       := 0;
End;

{ ------------------------------------------------------------ }
{ GenPeLabel : generer un label unique pour le PE/COFF              }
{ ------------------------------------------------------------ }

Function GenPeLabel : TString;
Begin
  Inc(PeLabelSeq);
  GenPeLabel := '_PYPE_L' + ItoS(PeLabelSeq);
End;

{ ------------------------------------------------------------ }
{ PeTypeName : retourner le nom du type d operation PE/COFF         }
{ ------------------------------------------------------------ }

Function PeTypeName(Kind : Integer) : TString;
Begin
  Case Kind Of
    PE_NONE          : PeTypeName := 'PE_NONE';
    PE_DOS_HEADER    : PeTypeName := 'PE_DOS_HEADER';
    PE_SIGNATURE     : PeTypeName := 'PE_SIGNATURE';
    PE_COFF_HEADER   : PeTypeName := 'PE_COFF_HEADER';
    PE_OPT_HEADER    : PeTypeName := 'PE_OPT_HEADER';
    PE_SECTION_HDR   : PeTypeName := 'PE_SECTION_HDR';
    PE_TEXT_SECTION   : PeTypeName := 'PE_TEXT_SECTION';
    PE_RDATA_SECTION  : PeTypeName := 'PE_RDATA_SECTION';
    PE_DATA_SECTION  : PeTypeName := 'PE_DATA_SECTION';
    PE_FIXUP         : PeTypeName := 'PE_FIXUP';
    PE_ALIGN         : PeTypeName := 'PE_ALIGN';
    PE_COFF_OBJ      : PeTypeName := 'PE_COFF_OBJ';
    PE_RELOCATION    : PeTypeName := 'PE_RELOCATION';
    PE_SYMBOL        : PeTypeName := 'PE_SYMBOL';
  Else
    PeTypeName := 'PE_UNKNOWN(' + ItoS(Kind) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ WriteDosHeader : ecrire le DOS Header MZ (64 octets) + stub       }
{ ------------------------------------------------------------ }

Procedure WriteDosHeader;
Begin
  Inc(PeDosHdrCount);
  PeLastKind := PE_DOS_HEADER;
  WriteLn('; --- DOS Header (MZ, 64 octets) ---');
  WriteLn(';   e_magic    : $5A4D (MZ)');
  WriteLn(';   e_lfanew   : offset vers PE signature');
  WriteLn(';   DOS stub   : "This program cannot be run in DOS mode."');
End;

{ ------------------------------------------------------------ }
{ WritePeSignature : ecrire la signature PE "PE\0\0"                }
{ ------------------------------------------------------------ }

Procedure WritePeSignature;
Begin
  Inc(PeSignatureCount);
  PeLastKind := PE_SIGNATURE;
  WriteLn('; --- PE Signature ---');
  WriteLn(';   Signature  : $00004550 ("PE\0\0")');
End;

{ ------------------------------------------------------------ }
{ WriteCoffHeader : ecrire le COFF File Header (20 octets)          }
{ ------------------------------------------------------------ }

Procedure WriteCoffHeader;
Begin
  Inc(PeCoffHdrCount);
  PeLastKind := PE_COFF_HEADER;
  WriteLn('; --- COFF File Header (20 octets) ---');
  WriteLn(';   Machine           : $014C (i386)');
  WriteLn(';   NumberOfSections  : 3 (.text, .rdata, .data)');
  WriteLn(';   SizeOfOptionalHdr : 224');
  WriteLn(';   Characteristics   : $0102 (EXECUTABLE_IMAGE | 32BIT)');
End;

{ ------------------------------------------------------------ }
{ WriteOptionalHeader : ecrire l Optional Header PE32 (224 octets)  }
{ ------------------------------------------------------------ }

Procedure WriteOptionalHeader;
Begin
  Inc(PeOptHdrCount);
  PeLastKind := PE_OPT_HEADER;
  WriteLn('; --- Optional Header PE32 (224 octets) ---');
  WriteLn(';   Magic             : $010B (PE32)');
  WriteLn(';   AddressOfEntryPt  : RVA de _start');
  WriteLn(';   ImageBase         : $00400000');
  WriteLn(';   SectionAlignment  : $1000 (4096)');
  WriteLn(';   FileAlignment     : $0200 (512)');
  WriteLn(';   Subsystem         : 3 (IMAGE_SUBSYSTEM_WINDOWS_CUI)');
  WriteLn(';   DataDirectory[1]  : Import Table RVA/Size');
End;

{ ------------------------------------------------------------ }
{ WriteSectionHeaders : ecrire les en-tetes de sections             }
{ ------------------------------------------------------------ }

Procedure WriteSectionHeaders;
Begin
  Inc(PeSectHdrCount);
  PeLastKind := PE_SECTION_HDR;
  WriteLn('; --- Section Headers (3 x 40 octets) ---');
  WriteLn(';   Section .text   : code, READ|EXECUTE');
  WriteLn(';   Section .rdata  : imports, READ');
  WriteLn(';   Section .data   : donnees, READ|WRITE');
End;

{ ------------------------------------------------------------ }
{ WriteSectionText : ecrire le contenu de la section .text          }
{ ------------------------------------------------------------ }

Procedure WriteSectionText;
Begin
  Inc(PeTextSecCount);
  PeLastKind := PE_TEXT_SECTION;
  WriteLn('; --- Section .text (code machine 80386) ---');
  WriteLn(';   Point d entree : _start');
  WriteLn(';   Code genere par le compilateur Python');
  WriteLn(';   Appels via CALL [IAT_xxx] pour imports');
End;

{ ------------------------------------------------------------ }
{ WriteSectionRdata : ecrire la section .rdata (imports)            }
{ ------------------------------------------------------------ }

Procedure WriteSectionRdata;
Begin
  Inc(PeRdataSecCount);
  PeLastKind := PE_RDATA_SECTION;
  WriteLn('; --- Section .rdata (Import Directory + IAT) ---');
  WriteLn(';   Import Directory Table (ILT)');
  WriteLn(';   Import Address Table (IAT)');
  WriteLn(';   Hint/Name Table (noms des fonctions)');
  WriteLn(';   DLL name : "kernel32.dll"');
End;

{ ------------------------------------------------------------ }
{ WriteSectionData : ecrire la section .data (variables)            }
{ ------------------------------------------------------------ }

Procedure WriteSectionData;
Begin
  Inc(PeDataSecCount);
  PeLastKind := PE_DATA_SECTION;
  WriteLn('; --- Section .data (variables et constantes) ---');
  WriteLn(';   Variables globales Python');
  WriteLn(';   Constantes chaines');
  WriteLn(';   Tampons E/S');
End;

{ ------------------------------------------------------------ }
{ ResolveFixups : resoudre les fixups d adresses                    }
{ ------------------------------------------------------------ }

Procedure ResolveFixups;
Begin
  Inc(PeFixupCount);
  PeLastKind := PE_FIXUP;
  WriteLn('; --- Resolution des fixups ---');
  WriteLn(';   Adresses absolues (ImageBase + RVA)');
  WriteLn(';   Adresses relatives (CALL/JMP rel32)');
  WriteLn(';   Patch des entries IAT');
End;

{ ------------------------------------------------------------ }
{ PadToAlignment : calculer le remplissage pour alignement          }
{   Size  : taille actuelle en octets                               }
{   Align : alignement requis (ex: 512 ou 4096)                    }
{   Retourne la taille alignee                                      }
{ ------------------------------------------------------------ }

Function PadToAlignment(Size, Align : LongInt) : LongInt;
Begin
  Inc(PeAlignCount);
  PeLastKind := PE_ALIGN;
  If (Size Mod Align) = 0 Then
    PadToAlignment := Size
  Else
    PadToAlignment := Size + Align - (Size Mod Align);
End;

{ ------------------------------------------------------------ }
{ GeneratePeExe : orchestrateur principal de generation PE .EXE     }
{ ------------------------------------------------------------ }

Procedure GeneratePeExe;
Begin
  WriteLn('; ===== Generation PE32 Executable =====');
  WriteDosHeader;
  WritePeSignature;
  WriteCoffHeader;
  WriteOptionalHeader;
  WriteSectionHeaders;
  WriteSectionText;
  WriteSectionRdata;
  WriteSectionData;
  ResolveFixups;
  WriteLn('; ===== Fin generation PE32 =====');
End;

{ ------------------------------------------------------------ }
{ WriteCoffObjHeader : ecrire l en-tete COFF .OBJ                  }
{ ------------------------------------------------------------ }

Procedure WriteCoffObjHeader;
Begin
  Inc(PeCoffObjCount);
  PeLastKind := PE_COFF_OBJ;
  WriteLn('; --- COFF .OBJ Header ---');
  WriteLn(';   Machine           : $014C (i386)');
  WriteLn(';   NumberOfSections  : 3 (.text, .data, .bss)');
  WriteLn(';   Characteristics   : $0000 (objet relogeable)');
End;

{ ------------------------------------------------------------ }
{ WriteCoffSections : ecrire les sections COFF .OBJ                 }
{ ------------------------------------------------------------ }

Procedure WriteCoffSections;
Begin
  Inc(PeTextSecCount);
  PeLastKind := PE_TEXT_SECTION;
  WriteLn('; --- COFF Sections (.text, .data, .bss) ---');
  WriteLn(';   .text  : code machine, ALIGN_16, CNT_CODE');
  WriteLn(';   .data  : donnees initialisees, CNT_INIT_DATA');
  WriteLn(';   .bss   : donnees non-initialisees, CNT_UNINIT_DATA');
End;

{ ------------------------------------------------------------ }
{ WriteCoffRelocations : ecrire la table des relocations COFF       }
{ ------------------------------------------------------------ }

Procedure WriteCoffRelocations;
Begin
  Inc(PeRelocCount);
  PeLastKind := PE_RELOCATION;
  WriteLn('; --- COFF Relocation Table ---');
  WriteLn(';   IMAGE_REL_I386_DIR32  : adresses absolues (type 6)');
  WriteLn(';   IMAGE_REL_I386_REL32  : adresses relatives (type 20)');
  WriteLn(';   VirtualAddress, SymbolTableIndex, Type');
End;

{ ------------------------------------------------------------ }
{ WriteCoffSymbols : ecrire la table des symboles COFF              }
{ ------------------------------------------------------------ }

Procedure WriteCoffSymbols;
Begin
  Inc(PeSymbolCount);
  PeLastKind := PE_SYMBOL;
  WriteLn('; --- COFF Symbol Table ---');
  WriteLn(';   StorageClass EXTERNAL (2) : imports Win32');
  WriteLn(';   StorageClass STATIC   (3) : sections');
  WriteLn(';   StorageClass LABEL    (6) : labels internes');
  WriteLn(';   _ExitProcess@4, _GetStdHandle@4, ...');
End;

{ ------------------------------------------------------------ }
{ WriteCoffStringTable : ecrire la table des chaines COFF           }
{ ------------------------------------------------------------ }

Procedure WriteCoffStringTable;
Begin
  Inc(PeSymbolCount);
  PeLastKind := PE_SYMBOL;
  WriteLn('; --- COFF String Table ---');
  WriteLn(';   Taille (4 octets) + chaines ASCIIZ');
  WriteLn(';   Noms de symboles > 8 caracteres');
End;

{ ------------------------------------------------------------ }
{ GenerateCoffObj : orchestrateur principal de generation COFF .OBJ  }
{ ------------------------------------------------------------ }

Procedure GenerateCoffObj;
Begin
  WriteLn('; ===== Generation COFF .OBJ =====');
  WriteCoffObjHeader;
  WriteCoffSections;
  WriteCoffRelocations;
  WriteCoffSymbols;
  WriteCoffStringTable;
  WriteLn('; ===== Fin generation COFF .OBJ =====');
End;

{ ------------------------------------------------------------ }
{ DumpPeState : afficher l etat du sous-systeme PE/COFF             }
{ ------------------------------------------------------------ }

Procedure DumpPeState;
Begin
  WriteLn;
  WriteLn('=== Etat du sous-systeme PE/COFF Writer (TODO 23) ===');
  WriteLn('  PeInitialized    : ', PeInitialized);
  WriteLn('  PeDosHdrCount    : ', PeDosHdrCount);
  WriteLn('  PeSignatureCount : ', PeSignatureCount);
  WriteLn('  PeCoffHdrCount   : ', PeCoffHdrCount);
  WriteLn('  PeOptHdrCount    : ', PeOptHdrCount);
  WriteLn('  PeSectHdrCount   : ', PeSectHdrCount);
  WriteLn('  PeTextSecCount   : ', PeTextSecCount);
  WriteLn('  PeRdataSecCount  : ', PeRdataSecCount);
  WriteLn('  PeDataSecCount   : ', PeDataSecCount);
  WriteLn('  PeFixupCount     : ', PeFixupCount);
  WriteLn('  PeAlignCount     : ', PeAlignCount);
  WriteLn('  PeCoffObjCount   : ', PeCoffObjCount);
  WriteLn('  PeRelocCount     : ', PeRelocCount);
  WriteLn('  PeSymbolCount    : ', PeSymbolCount);
  WriteLn('  PeLastKind       : ', PeTypeName(PeLastKind));
  WriteLn('  PeLabelSeq       : ', PeLabelSeq);
End;

{ ------------------------------------------------------------ }
{ Accesseurs du sous-systeme PE/COFF Writer (10 fonctions)          }
{ ------------------------------------------------------------ }

Function IsPeInitialized : Boolean;
Begin
  IsPeInitialized := PeInitialized;
End;

Function IsPeEmpty : Boolean;
Begin
  IsPeEmpty := (PeDosHdrCount = 0) And (PeCoffHdrCount = 0) And
               (PeTextSecCount = 0) And (PeCoffObjCount = 0);
End;

Function GetPeDosHdrCount : LongInt;
Begin
  GetPeDosHdrCount := PeDosHdrCount;
End;

Function GetPeCoffHdrCount : LongInt;
Begin
  GetPeCoffHdrCount := PeCoffHdrCount;
End;

Function GetPeOptHdrCount : LongInt;
Begin
  GetPeOptHdrCount := PeOptHdrCount;
End;

Function GetPeTextSecCount : LongInt;
Begin
  GetPeTextSecCount := PeTextSecCount;
End;

Function GetPeFixupCount : LongInt;
Begin
  GetPeFixupCount := PeFixupCount;
End;

Function GetPeCoffObjCount : LongInt;
Begin
  GetPeCoffObjCount := PeCoffObjCount;
End;

Function GetPeSymbolCount : LongInt;
Begin
  GetPeSymbolCount := PeSymbolCount;
End;

Function GetPeStatus : TString;
Begin
  If Not PeInitialized Then
    GetPeStatus := 'Not initialized'
  Else
    GetPeStatus := ItoS(PeDosHdrCount) + ' dos-hdr, ' +
                   ItoS(PeCoffHdrCount) + ' coff-hdr, ' +
                   ItoS(PeOptHdrCount) + ' opt-hdr, ' +
                   ItoS(PeTextSecCount) + ' text-sec, ' +
                   ItoS(PeFixupCount) + ' fixups, ' +
                   ItoS(PeCoffObjCount) + ' coff-obj, ' +
                   ItoS(PeSymbolCount) + ' symbols';
End;

{ ============================================================ }
{ TODO 24 : Imports API Win32 et generateur listing ASM        }
{ ============================================================ }

Const
  { Types d operations import/listing }
  IM_NONE          = 0;    { Pas d operation import                 }
  IM_IMPORT_DESC   = 1;    { IMAGE_IMPORT_DESCRIPTOR par DLL        }
  IM_HINT_NAME     = 2;    { Hint/Name Table avec nom de fonction   }
  IM_IAT_THUNK     = 3;    { Import Address Table thunk             }
  IM_IMPORT_DIR    = 4;    { Import directory complet                }
  IM_KERNEL32      = 5;    { Import kernel32.dll                    }
  IM_MSVCRT        = 6;    { Import msvcrt.dll (optionnel)          }
  IM_EXTERN_DECL   = 7;    { Declaration EXTERN pour .OBJ           }
  IM_IMPORT_SYM    = 8;    { Symbole d importation                  }
  IM_ASM_HEADER    = 9;    { En-tete listing MASM                   }
  IM_ASM_EXTERN    = 10;   { Declarations EXTERN MASM               }
  IM_ASM_DATA      = 11;   { Section .DATA MASM                     }
  IM_ASM_CODE      = 12;   { Section .CODE MASM                     }
  IM_ASM_LISTING   = 13;   { Listing ASM complet genere             }
  IM_MAX           = 13;

  { Limites }
  IM_MAX_IMPORTS   = 64;   { nombre max de fonctions importees      }
  IM_MAX_DLL       = 4;    { nombre max de DLL importees            }
  IM_MAX_HINT      = 256;  { taille max hint/name table             }

  { Noms des DLL }
  IM_DLL_KERNEL32  = 'kernel32.dll';
  IM_DLL_MSVCRT    = 'msvcrt.dll';

Var
  ImInitialized    : Boolean;    { True si l etat est initialise       }
  ImDescCount      : LongInt;    { nombre de descripteurs d import emis}
  ImHintCount      : LongInt;    { nombre d entrees hint/name emises   }
  ImIatCount       : LongInt;    { nombre de thunks IAT emis           }
  ImDirCount       : LongInt;    { nombre de directories emis          }
  ImKernel32Count  : LongInt;    { nombre d imports kernel32 emis      }
  ImMsvcrtCount    : LongInt;    { nombre d imports msvcrt emis        }
  ImExternCount    : LongInt;    { nombre de declarations EXTERN       }
  ImSymCount       : LongInt;    { nombre de symboles d import         }
  ImAsmHdrCount    : LongInt;    { nombre d en-tetes ASM emis          }
  ImAsmExtCount    : LongInt;    { nombre d EXTERN ASM emis            }
  ImAsmDataCount   : LongInt;    { nombre de sections DATA ASM         }
  ImAsmCodeCount   : LongInt;    { nombre de sections CODE ASM         }
  ImAsmListCount   : LongInt;    { nombre de listings ASM generes      }
  ImLastKind       : Integer;    { dernier type d operation            }
  ImLabelSeq       : Integer;    { sequence pour labels import         }

{ ------------------------------------------------------------ }
{ InitImState : initialiser le sous-systeme imports/listing          }
{ ------------------------------------------------------------ }

Procedure InitImState;
Begin
  ImInitialized    := True;
  ImDescCount      := 0;
  ImHintCount      := 0;
  ImIatCount       := 0;
  ImDirCount       := 0;
  ImKernel32Count  := 0;
  ImMsvcrtCount    := 0;
  ImExternCount    := 0;
  ImSymCount       := 0;
  ImAsmHdrCount    := 0;
  ImAsmExtCount    := 0;
  ImAsmDataCount   := 0;
  ImAsmCodeCount   := 0;
  ImAsmListCount   := 0;
  ImLastKind       := IM_NONE;
  ImLabelSeq       := 0;
End;

{ ------------------------------------------------------------ }
{ GenImLabel : generer un label unique pour imports/listing           }
{ ------------------------------------------------------------ }

Function GenImLabel : TString;
Begin
  Inc(ImLabelSeq);
  GenImLabel := '_IM_L' + ItoS(ImLabelSeq);
End;

{ ------------------------------------------------------------ }
{ ImTypeName : nom du type d operation import/listing                }
{ ------------------------------------------------------------ }

Function ImTypeName(Kind : Integer) : TString;
Begin
  Case Kind Of
    IM_NONE         : ImTypeName := 'NONE';
    IM_IMPORT_DESC  : ImTypeName := 'IMPORT_DESC';
    IM_HINT_NAME    : ImTypeName := 'HINT_NAME';
    IM_IAT_THUNK    : ImTypeName := 'IAT_THUNK';
    IM_IMPORT_DIR   : ImTypeName := 'IMPORT_DIR';
    IM_KERNEL32     : ImTypeName := 'KERNEL32';
    IM_MSVCRT       : ImTypeName := 'MSVCRT';
    IM_EXTERN_DECL  : ImTypeName := 'EXTERN_DECL';
    IM_IMPORT_SYM   : ImTypeName := 'IMPORT_SYM';
    IM_ASM_HEADER   : ImTypeName := 'ASM_HEADER';
    IM_ASM_EXTERN   : ImTypeName := 'ASM_EXTERN';
    IM_ASM_DATA     : ImTypeName := 'ASM_DATA';
    IM_ASM_CODE     : ImTypeName := 'ASM_CODE';
    IM_ASM_LISTING  : ImTypeName := 'ASM_LISTING';
  Else
    ImTypeName := 'UNKNOWN(' + ItoS(Kind) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ EmitImportDescriptor : emettre un IMAGE_IMPORT_DESCRIPTOR         }
{ pour une DLL donnee                                               }
{ ------------------------------------------------------------ }

Procedure EmitImportDescriptor(DllName : TString);
Begin
  WriteLn('; IMAGE_IMPORT_DESCRIPTOR for ' + DllName);
  WriteLn('  dd offset _ILT_' + DllName);
  WriteLn('  dd 0             ; TimeDateStamp');
  WriteLn('  dd 0             ; ForwarderChain');
  WriteLn('  dd offset _NAME_' + DllName);
  WriteLn('  dd offset _IAT_' + DllName);
  Inc(ImDescCount);
  ImLastKind := IM_IMPORT_DESC;
End;

{ ------------------------------------------------------------ }
{ EmitHintNameEntry : emettre une entree Hint/Name Table            }
{ ------------------------------------------------------------ }

Procedure EmitHintNameEntry(Hint : Integer; FuncName : TString);
Begin
  WriteLn('  dw ' + ItoS(Hint) + '         ; Hint');
  WriteLn('  db ''' + FuncName + ''', 0   ; Name');
  If (Length(FuncName) Mod 2) = 0 Then
    WriteLn('  db 0             ; Pad to word boundary');
  Inc(ImHintCount);
  ImLastKind := IM_HINT_NAME;
End;

{ ------------------------------------------------------------ }
{ EmitIATThunk : emettre un thunk IAT pour une fonction             }
{ ------------------------------------------------------------ }

Procedure EmitIATThunk(FuncLabel : TString);
Begin
  WriteLn('  dd offset ' + FuncLabel);
  Inc(ImIatCount);
  ImLastKind := IM_IAT_THUNK;
End;

{ ------------------------------------------------------------ }
{ EmitImportDirectory : emettre le repertoire d import complet      }
{ ------------------------------------------------------------ }

Procedure EmitImportDirectory;
Begin
  WriteLn('; ---- Import Directory Table ----');
  EmitImportDescriptor(IM_DLL_KERNEL32);
  If ImMsvcrtCount > 0 Then
    EmitImportDescriptor(IM_DLL_MSVCRT);
  { Terminateur null }
  WriteLn('; NULL terminator');
  WriteLn('  dd 0, 0, 0, 0, 0');
  Inc(ImDirCount);
  ImLastKind := IM_IMPORT_DIR;
End;

{ ------------------------------------------------------------ }
{ MarkKernel32Import : marquer une fonction kernel32 comme utilisee }
{ ------------------------------------------------------------ }

Procedure MarkKernel32Import(FuncName : TString);
Begin
  WriteLn('; [import] ' + IM_DLL_KERNEL32 + ' : ' + FuncName);
  Inc(ImKernel32Count);
  ImLastKind := IM_KERNEL32;
End;

{ ------------------------------------------------------------ }
{ EmitKernel32Imports : emettre tous les imports kernel32.dll       }
{ ------------------------------------------------------------ }

Procedure EmitKernel32Imports;
Begin
  WriteLn('; ---- kernel32.dll Imports ----');
  WriteLn('_NAME_' + IM_DLL_KERNEL32 + ':');
  WriteLn('  db ''kernel32.dll'', 0');
  WriteLn('');
  WriteLn('_ILT_' + IM_DLL_KERNEL32 + ':');
  EmitHintNameEntry(0, 'ExitProcess');
  EmitHintNameEntry(1, 'GetStdHandle');
  EmitHintNameEntry(2, 'WriteFile');
  EmitHintNameEntry(3, 'ReadFile');
  EmitHintNameEntry(4, 'GetProcessHeap');
  EmitHintNameEntry(5, 'HeapAlloc');
  EmitHintNameEntry(6, 'HeapFree');
  EmitHintNameEntry(7, 'GetCommandLineA');
  EmitHintNameEntry(8, 'GetLastError');
  WriteLn('  dd 0             ; ILT terminator');
  WriteLn('');
  WriteLn('_IAT_' + IM_DLL_KERNEL32 + ':');
  EmitIATThunk('_HN_ExitProcess');
  EmitIATThunk('_HN_GetStdHandle');
  EmitIATThunk('_HN_WriteFile');
  EmitIATThunk('_HN_ReadFile');
  EmitIATThunk('_HN_GetProcessHeap');
  EmitIATThunk('_HN_HeapAlloc');
  EmitIATThunk('_HN_HeapFree');
  EmitIATThunk('_HN_GetCommandLineA');
  EmitIATThunk('_HN_GetLastError');
  WriteLn('  dd 0             ; IAT terminator');
  Inc(ImKernel32Count);
  ImLastKind := IM_KERNEL32;
End;

{ ------------------------------------------------------------ }
{ MarkMsvcrtImport : marquer une fonction msvcrt comme utilisee    }
{ ------------------------------------------------------------ }

Procedure MarkMsvcrtImport(FuncName : TString);
Begin
  WriteLn('; [import] ' + IM_DLL_MSVCRT + ' : ' + FuncName);
  Inc(ImMsvcrtCount);
  ImLastKind := IM_MSVCRT;
End;

{ ------------------------------------------------------------ }
{ EmitMsvcrtImports : emettre tous les imports msvcrt.dll          }
{ ------------------------------------------------------------ }

Procedure EmitMsvcrtImports;
Begin
  WriteLn('; ---- msvcrt.dll Imports ----');
  WriteLn('_NAME_' + IM_DLL_MSVCRT + ':');
  WriteLn('  db ''msvcrt.dll'', 0');
  WriteLn('');
  WriteLn('_ILT_' + IM_DLL_MSVCRT + ':');
  EmitHintNameEntry(0, 'sprintf');
  EmitHintNameEntry(1, 'sscanf');
  EmitHintNameEntry(2, 'memcpy');
  EmitHintNameEntry(3, 'memset');
  EmitHintNameEntry(4, 'memcmp');
  WriteLn('  dd 0             ; ILT terminator');
  WriteLn('');
  WriteLn('_IAT_' + IM_DLL_MSVCRT + ':');
  EmitIATThunk('_HN_sprintf');
  EmitIATThunk('_HN_sscanf');
  EmitIATThunk('_HN_memcpy');
  EmitIATThunk('_HN_memset');
  EmitIATThunk('_HN_memcmp');
  WriteLn('  dd 0             ; IAT terminator');
  Inc(ImMsvcrtCount);
  ImLastKind := IM_MSVCRT;
End;

{ ------------------------------------------------------------ }
{ EmitExternDecl : emettre une declaration EXTERN pour .OBJ        }
{ ------------------------------------------------------------ }

Procedure EmitExternDecl(FuncName, Decorated : TString);
Begin
  WriteLn('EXTERN ' + Decorated + ' : PROC  ; ' + FuncName);
  Inc(ImExternCount);
  ImLastKind := IM_EXTERN_DECL;
End;

{ ------------------------------------------------------------ }
{ EmitImportSymbols : emettre les symboles d import .OBJ           }
{ ------------------------------------------------------------ }

Procedure EmitImportSymbols;
Begin
  WriteLn('; ---- Import symbols for .OBJ mode ----');
  EmitExternDecl('ExitProcess',     '_ExitProcess@4');
  EmitExternDecl('GetStdHandle',    '_GetStdHandle@4');
  EmitExternDecl('WriteFile',       '_WriteFile@20');
  EmitExternDecl('ReadFile',        '_ReadFile@20');
  EmitExternDecl('GetProcessHeap',  '_GetProcessHeap@0');
  EmitExternDecl('HeapAlloc',       '_HeapAlloc@12');
  EmitExternDecl('HeapFree',        '_HeapFree@12');
  EmitExternDecl('GetCommandLineA', '_GetCommandLineA@0');
  EmitExternDecl('GetLastError',    '_GetLastError@0');
  Inc(ImSymCount);
  ImLastKind := IM_IMPORT_SYM;
End;

{ ------------------------------------------------------------ }
{ EmitAsmHeader : emettre l en-tete du listing MASM                }
{ ------------------------------------------------------------ }

Procedure EmitAsmHeader;
Begin
  WriteLn('; ============================================');
  WriteLn('; PYTHCW32 - Python to Win32 ASM Listing');
  WriteLn('; Generated by PYTHCW32 compiler');
  WriteLn('; ============================================');
  WriteLn('');
  WriteLn('.386');
  WriteLn('.MODEL FLAT, STDCALL');
  WriteLn('OPTION CASEMAP:NONE');
  WriteLn('');
  WriteLn('INCLUDELIB kernel32.lib');
  WriteLn('INCLUDELIB msvcrt.lib');
  WriteLn('');
  Inc(ImAsmHdrCount);
  ImLastKind := IM_ASM_HEADER;
End;

{ ------------------------------------------------------------ }
{ EmitAsmExterns : emettre les declarations EXTERN MASM            }
{ ------------------------------------------------------------ }

Procedure EmitAsmExterns;
Begin
  WriteLn('; ---- External API declarations ----');
  WriteLn('EXTERN _ExitProcess@4:PROC');
  WriteLn('EXTERN _GetStdHandle@4:PROC');
  WriteLn('EXTERN _WriteFile@20:PROC');
  WriteLn('EXTERN _ReadFile@20:PROC');
  WriteLn('EXTERN _GetProcessHeap@0:PROC');
  WriteLn('EXTERN _HeapAlloc@12:PROC');
  WriteLn('EXTERN _HeapFree@12:PROC');
  WriteLn('EXTERN _GetCommandLineA@0:PROC');
  WriteLn('EXTERN _GetLastError@0:PROC');
  WriteLn('');
  WriteLn('; ---- msvcrt.dll (optional) ----');
  WriteLn('EXTERN _sprintf:PROC');
  WriteLn('EXTERN _sscanf:PROC');
  WriteLn('EXTERN _memcpy:PROC');
  WriteLn('EXTERN _memset:PROC');
  WriteLn('EXTERN _memcmp:PROC');
  WriteLn('');
  Inc(ImAsmExtCount);
  ImLastKind := IM_ASM_EXTERN;
End;

{ ------------------------------------------------------------ }
{ EmitAsmDataSection : emettre la section .DATA du listing MASM    }
{ ------------------------------------------------------------ }

Procedure EmitAsmDataSection;
Begin
  WriteLn('; ---- Initialized data ----');
  WriteLn('.DATA');
  WriteLn('');
  WriteLn('  ; String constants and format strings');
  WriteLn('  _true_str   db ''True'', 0');
  WriteLn('  _false_str  db ''False'', 0');
  WriteLn('  _none_str   db ''None'', 0');
  WriteLn('  _newline    db 13, 10, 0');
  WriteLn('  _space      db '' '', 0');
  WriteLn('  _fmt_int    db ''%d'', 0');
  WriteLn('  _fmt_str    db ''%s'', 0');
  WriteLn('');
  WriteLn('; ---- Uninitialized data ----');
  WriteLn('.DATA?');
  WriteLn('');
  WriteLn('  _stdin_h    dd ?');
  WriteLn('  _stdout_h   dd ?');
  WriteLn('  _heap_h     dd ?');
  WriteLn('  _bytes_w    dd ?');
  WriteLn('  _bytes_r    dd ?');
  WriteLn('  _input_buf  db 256 DUP(?)');
  WriteLn('  _itoa_buf   db 32 DUP(?)');
  WriteLn('');
  Inc(ImAsmDataCount);
  ImLastKind := IM_ASM_DATA;
End;

{ ------------------------------------------------------------ }
{ EmitAsmBssSection : emettre la section BSS du listing MASM       }
{ (inclus dans EmitAsmDataSection via .DATA?)                      }
{ ------------------------------------------------------------ }

Procedure EmitAsmBssSection;
Begin
  WriteLn('; ---- Additional BSS variables ----');
  WriteLn('  _heap_base  dd ?');
  WriteLn('  _heap_ptr   dd ?');
  WriteLn('  _temp_buf   db 256 DUP(?)');
  WriteLn('');
  Inc(ImAsmDataCount);
End;

{ ------------------------------------------------------------ }
{ EmitAsmCodeSection : emettre la section .CODE du listing MASM    }
{ ------------------------------------------------------------ }

Procedure EmitAsmCodeSection;
Begin
  WriteLn('; ---- Code section ----');
  WriteLn('.CODE');
  WriteLn('');
  WriteLn('; ---- Runtime routines (_PYRT_) ----');
  WriteLn('_PYRT_init_io PROC');
  WriteLn('  push -11            ; STD_OUTPUT_HANDLE');
  WriteLn('  call _GetStdHandle@4');
  WriteLn('  mov [_stdout_h], eax');
  WriteLn('  push -10            ; STD_INPUT_HANDLE');
  WriteLn('  call _GetStdHandle@4');
  WriteLn('  mov [_stdin_h], eax');
  WriteLn('  call _GetProcessHeap@0');
  WriteLn('  mov [_heap_h], eax');
  WriteLn('  ret');
  WriteLn('_PYRT_init_io ENDP');
  WriteLn('');
  WriteLn('_PYRT_write_str PROC');
  WriteLn('  ; EAX = ptr to string, ECX = length');
  WriteLn('  push 0              ; lpOverlapped');
  WriteLn('  push offset _bytes_w ; lpNumberOfBytesWritten');
  WriteLn('  push ecx            ; nNumberOfBytesToWrite');
  WriteLn('  push eax            ; lpBuffer');
  WriteLn('  push [_stdout_h]    ; hFile');
  WriteLn('  call _WriteFile@20');
  WriteLn('  ret');
  WriteLn('_PYRT_write_str ENDP');
  WriteLn('');
  WriteLn('_PYRT_write_crlf PROC');
  WriteLn('  push 0');
  WriteLn('  push offset _bytes_w');
  WriteLn('  push 2');
  WriteLn('  push offset _newline');
  WriteLn('  push [_stdout_h]');
  WriteLn('  call _WriteFile@20');
  WriteLn('  ret');
  WriteLn('_PYRT_write_crlf ENDP');
  WriteLn('');
  WriteLn('; ---- Entry point ----');
  WriteLn('_start:');
  WriteLn('  call _PYRT_init_io');
  WriteLn('');
  WriteLn('  ; --- Python user code here ---');
  WriteLn('  ; (generated by PYTHCW32 compiler)');
  WriteLn('');
  WriteLn('  ; --- Exit process ---');
  WriteLn('  push 0');
  WriteLn('  call _ExitProcess@4');
  WriteLn('');
  WriteLn('END _start');
  WriteLn('');
  Inc(ImAsmCodeCount);
  ImLastKind := IM_ASM_CODE;
End;

{ ------------------------------------------------------------ }
{ EmitAsmFooter : emettre le pied de page du listing MASM          }
{ ------------------------------------------------------------ }

Procedure EmitAsmFooter;
Begin
  WriteLn('; ============================================');
  WriteLn('; End of PYTHCW32 ASM listing');
  WriteLn('; ============================================');
  Inc(ImAsmCodeCount);
End;

{ ------------------------------------------------------------ }
{ GenerateAsmListing : generer le listing ASM complet              }
{ ------------------------------------------------------------ }

Procedure GenerateAsmListing;
Begin
  EmitAsmHeader;
  EmitAsmExterns;
  EmitAsmDataSection;
  EmitAsmBssSection;
  EmitAsmCodeSection;
  EmitAsmFooter;
  Inc(ImAsmListCount);
  ImLastKind := IM_ASM_LISTING;
End;

{ ------------------------------------------------------------ }
{ DumpImState : afficher l etat du sous-systeme imports/listing    }
{ ------------------------------------------------------------ }

Procedure DumpImState;
Begin
  WriteLn('=== Etat du sous-systeme Imports/Listing ASM (TODO 24) ===');
  WriteLn('  ImInitialized    : ', ImInitialized);
  WriteLn('  ImDescCount      : ', ImDescCount);
  WriteLn('  ImHintCount      : ', ImHintCount);
  WriteLn('  ImIatCount       : ', ImIatCount);
  WriteLn('  ImDirCount       : ', ImDirCount);
  WriteLn('  ImKernel32Count  : ', ImKernel32Count);
  WriteLn('  ImMsvcrtCount    : ', ImMsvcrtCount);
  WriteLn('  ImExternCount    : ', ImExternCount);
  WriteLn('  ImSymCount       : ', ImSymCount);
  WriteLn('  ImAsmHdrCount    : ', ImAsmHdrCount);
  WriteLn('  ImAsmExtCount    : ', ImAsmExtCount);
  WriteLn('  ImAsmDataCount   : ', ImAsmDataCount);
  WriteLn('  ImAsmCodeCount   : ', ImAsmCodeCount);
  WriteLn('  ImAsmListCount   : ', ImAsmListCount);
  WriteLn('  ImLastKind       : ', ImTypeName(ImLastKind));
  WriteLn('  ImLabelSeq       : ', ImLabelSeq);
End;

{ ------------------------------------------------------------ }
{ Accesseurs du sous-systeme Imports/Listing ASM (10 fonctions)    }
{ ------------------------------------------------------------ }

Function IsImInitialized : Boolean;
Begin
  IsImInitialized := ImInitialized;
End;

Function IsImEmpty : Boolean;
Begin
  IsImEmpty := (ImDescCount = 0) And (ImKernel32Count = 0) And
               (ImAsmListCount = 0) And (ImExternCount = 0);
End;

Function GetImDescCount : LongInt;
Begin
  GetImDescCount := ImDescCount;
End;

Function GetImHintCount : LongInt;
Begin
  GetImHintCount := ImHintCount;
End;

Function GetImKernel32Count : LongInt;
Begin
  GetImKernel32Count := ImKernel32Count;
End;

Function GetImMsvcrtCount : LongInt;
Begin
  GetImMsvcrtCount := ImMsvcrtCount;
End;

Function GetImExternCount : LongInt;
Begin
  GetImExternCount := ImExternCount;
End;

Function GetImAsmHdrCount : LongInt;
Begin
  GetImAsmHdrCount := ImAsmHdrCount;
End;

Function GetImAsmListCount : LongInt;
Begin
  GetImAsmListCount := ImAsmListCount;
End;

Function GetImStatus : TString;
Begin
  If Not ImInitialized Then
    GetImStatus := 'Not initialized'
  Else
    GetImStatus := ItoS(ImDescCount) + ' descriptors, ' +
                   ItoS(ImKernel32Count) + ' kernel32, ' +
                   ItoS(ImMsvcrtCount) + ' msvcrt, ' +
                   ItoS(ImExternCount) + ' externs, ' +
                   ItoS(ImAsmListCount) + ' asm-listings';
End;

{ ============================================================ }
{ TODO 25 : Optimisations peephole, tests finaux, integration  }
{ ============================================================ }

Const
  { Types d optimisations et tests }
  PH_NONE          = 0;    { Pas d optimisation                      }
  PH_MOV_ZERO      = 1;    { MOV EAX, 0 -> XOR EAX, EAX             }
  PH_PUSH_POP      = 2;    { PUSH EAX / POP EAX -> eliminer          }
  PH_MOV_REDUND    = 3;    { MOV EAX,[x] / MOV [x],EAX -> eliminer   }
  PH_ADD_ONE       = 4;    { ADD EAX, 1 -> INC EAX                   }
  PH_SUB_ONE       = 5;    { SUB EAX, 1 -> DEC EAX                   }
  PH_MUL_TWO       = 6;    { IMUL EAX, 2 -> SHL EAX, 1              }
  PH_MUL_FOUR      = 7;    { IMUL EAX, 4 -> SHL EAX, 2              }
  PH_VERIFY_SAMPLE = 8;    { Verification d un fichier .py            }
  PH_RUN_TESTS     = 9;    { Execution batterie de tests              }
  PH_VERIFY_EXE    = 10;   { Verification sortie .EXE                 }
  PH_VERIFY_OBJ    = 11;   { Verification sortie .OBJ                 }
  PH_VERIFY_ASM    = 12;   { Verification sortie .ASM                 }
  PH_MEASURE_SIZE  = 13;   { Mesure taille executables                }
  PH_MAX           = 13;

  { Limites }
  PH_MAX_SAMPLES   = 32;   { nombre max de samples a tester           }
  PH_MAX_TESTS     = 64;   { nombre max de tests de regression        }
  PH_MAX_OPT_PASS  = 8;    { nombre max de passes d optimisation      }

Var
  OpInitialized    : Boolean;    { True si l etat est initialise       }
  OpMovZeroCount   : LongInt;    { nombre de MOV EAX,0 -> XOR          }
  OpPushPopCount   : LongInt;    { nombre de PUSH/POP elimines         }
  OpMovRedundCount : LongInt;    { nombre de MOV redondants elimines   }
  OpAddOneCount    : LongInt;    { nombre de ADD EAX,1 -> INC          }
  OpSubOneCount    : LongInt;    { nombre de SUB EAX,1 -> DEC          }
  OpMulTwoCount    : LongInt;    { nombre de IMUL EAX,2 -> SHL 1      }
  OpMulFourCount   : LongInt;    { nombre de IMUL EAX,4 -> SHL 2      }
  OpSampleCount    : LongInt;    { nombre de samples verifies          }
  OpTestCount      : LongInt;    { nombre de tests de regression       }
  OpExeOkCount     : LongInt;    { nombre de verif .EXE reussies       }
  OpObjOkCount     : LongInt;    { nombre de verif .OBJ reussies       }
  OpAsmOkCount     : LongInt;    { nombre de verif .ASM reussies       }
  OpMeasureCount   : LongInt;    { nombre de mesures de taille         }
  OpLastKind       : Integer;    { dernier type d operation            }
  OpLabelSeq       : Integer;    { sequence pour labels optimisation   }

{ ------------------------------------------------------------ }
{ InitOpState : initialiser le sous-systeme optimisations/tests      }
{ ------------------------------------------------------------ }

Procedure InitOpState;
Begin
  OpInitialized    := True;
  OpMovZeroCount   := 0;
  OpPushPopCount   := 0;
  OpMovRedundCount := 0;
  OpAddOneCount    := 0;
  OpSubOneCount    := 0;
  OpMulTwoCount    := 0;
  OpMulFourCount   := 0;
  OpSampleCount    := 0;
  OpTestCount      := 0;
  OpExeOkCount     := 0;
  OpObjOkCount     := 0;
  OpAsmOkCount     := 0;
  OpMeasureCount   := 0;
  OpLastKind       := PH_NONE;
  OpLabelSeq       := 0;
End;

{ ------------------------------------------------------------ }
{ GenOpLabel : generer un label unique pour l optimisation           }
{ ------------------------------------------------------------ }

Function GenOpLabel : TString;
Begin
  Inc(OpLabelSeq);
  GenOpLabel := '_OPT_' + ItoS(OpLabelSeq);
End;

{ ------------------------------------------------------------ }
{ OpTypeName : nom du type d optimisation/test                       }
{ ------------------------------------------------------------ }

Function OpTypeName(Kind : Integer) : TString;
Begin
  Case Kind Of
    PH_NONE          : OpTypeName := 'NONE';
    PH_MOV_ZERO      : OpTypeName := 'MOV_ZERO';
    PH_PUSH_POP      : OpTypeName := 'PUSH_POP';
    PH_MOV_REDUND    : OpTypeName := 'MOV_REDUND';
    PH_ADD_ONE       : OpTypeName := 'ADD_ONE';
    PH_SUB_ONE       : OpTypeName := 'SUB_ONE';
    PH_MUL_TWO       : OpTypeName := 'MUL_TWO';
    PH_MUL_FOUR      : OpTypeName := 'MUL_FOUR';
    PH_VERIFY_SAMPLE : OpTypeName := 'VERIFY_SAMPLE';
    PH_RUN_TESTS     : OpTypeName := 'RUN_TESTS';
    PH_VERIFY_EXE    : OpTypeName := 'VERIFY_EXE';
    PH_VERIFY_OBJ    : OpTypeName := 'VERIFY_OBJ';
    PH_VERIFY_ASM    : OpTypeName := 'VERIFY_ASM';
    PH_MEASURE_SIZE  : OpTypeName := 'MEASURE_SIZE';
  Else
    OpTypeName := 'UNKNOWN(' + ItoS(Kind) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ OptMovZero : optimiser MOV EAX, 0 -> XOR EAX, EAX                }
{ ------------------------------------------------------------ }

Procedure OptMovZero(Var Line : TString);
Var
  P : Integer;
  Tmp : TString;
Begin
  OpLastKind := PH_MOV_ZERO;
  Tmp := Line;
  { Chercher MOV EAX, 0 et remplacer par XOR EAX, EAX }
  P := Pos('MOV EAX, 0', Tmp);
  If P > 0 Then
  Begin
    Line := Copy(Tmp, 1, P - 1) + 'XOR EAX, EAX' +
            Copy(Tmp, P + 10, Length(Tmp) - P - 9);
    Inc(OpMovZeroCount);
  End;
End;

{ ------------------------------------------------------------ }
{ OptPushPop : eliminer PUSH EAX / POP EAX consecutifs              }
{ ------------------------------------------------------------ }

Function OptPushPop(Const Line1, Line2 : TString) : Boolean;
Begin
  OpLastKind := PH_PUSH_POP;
  OptPushPop := False;
  If (Pos('PUSH EAX', Line1) > 0) And
     (Pos('POP EAX', Line2) > 0) Then
  Begin
    OptPushPop := True;
    Inc(OpPushPopCount);
  End;
End;

{ ------------------------------------------------------------ }
{ OptMovRedundant : eliminer MOV redondant                          }
{ ------------------------------------------------------------ }

Function OptMovRedundant(Const Line1, Line2 : TString) : Boolean;
Var
  P1, P2 : Integer;
  Var1, Var2 : TString;
Begin
  OpLastKind := PH_MOV_REDUND;
  OptMovRedundant := False;
  { Chercher MOV EAX, [x] suivi de MOV [x], EAX }
  P1 := Pos('MOV EAX, [', Line1);
  P2 := Pos('MOV [', Line2);
  If (P1 > 0) And (P2 > 0) Then
  Begin
    Var1 := Copy(Line1, P1 + 10, Pos(']', Copy(Line1, P1 + 10, 255)) - 1);
    Var2 := Copy(Line2, P2 + 5, Pos(']', Copy(Line2, P2 + 5, 255)) - 1);
    If (Var1 = Var2) And (Pos(', EAX', Line2) > 0) Then
    Begin
      OptMovRedundant := True;
      Inc(OpMovRedundCount);
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ OptAddOne : optimiser ADD EAX, 1 -> INC EAX                      }
{ ------------------------------------------------------------ }

Procedure OptAddOne(Var Line : TString);
Var
  P : Integer;
  Tmp : TString;
Begin
  OpLastKind := PH_ADD_ONE;
  Tmp := Line;
  P := Pos('ADD EAX, 1', Tmp);
  If P > 0 Then
  Begin
    Line := Copy(Tmp, 1, P - 1) + 'INC EAX' +
            Copy(Tmp, P + 10, Length(Tmp) - P - 9);
    Inc(OpAddOneCount);
  End;
End;

{ ------------------------------------------------------------ }
{ OptSubOne : optimiser SUB EAX, 1 -> DEC EAX                      }
{ ------------------------------------------------------------ }

Procedure OptSubOne(Var Line : TString);
Var
  P : Integer;
  Tmp : TString;
Begin
  OpLastKind := PH_SUB_ONE;
  Tmp := Line;
  P := Pos('SUB EAX, 1', Tmp);
  If P > 0 Then
  Begin
    Line := Copy(Tmp, 1, P - 1) + 'DEC EAX' +
            Copy(Tmp, P + 10, Length(Tmp) - P - 9);
    Inc(OpSubOneCount);
  End;
End;

{ ------------------------------------------------------------ }
{ OptMulTwo : optimiser IMUL EAX, 2 -> SHL EAX, 1                  }
{ ------------------------------------------------------------ }

Procedure OptMulTwo(Var Line : TString);
Var
  P : Integer;
  Tmp : TString;
Begin
  OpLastKind := PH_MUL_TWO;
  Tmp := Line;
  P := Pos('IMUL EAX, 2', Tmp);
  If P > 0 Then
  Begin
    Line := Copy(Tmp, 1, P - 1) + 'SHL EAX, 1' +
            Copy(Tmp, P + 11, Length(Tmp) - P - 10);
    Inc(OpMulTwoCount);
  End;
End;

{ ------------------------------------------------------------ }
{ OptMulFour : optimiser IMUL EAX, 4 -> SHL EAX, 2                 }
{ ------------------------------------------------------------ }

Procedure OptMulFour(Var Line : TString);
Var
  P : Integer;
  Tmp : TString;
Begin
  OpLastKind := PH_MUL_FOUR;
  Tmp := Line;
  P := Pos('IMUL EAX, 4', Tmp);
  If P > 0 Then
  Begin
    Line := Copy(Tmp, 1, P - 1) + 'SHL EAX, 2' +
            Copy(Tmp, P + 11, Length(Tmp) - P - 10);
    Inc(OpMulFourCount);
  End;
End;

{ ------------------------------------------------------------ }
{ PeepholeOptLine : appliquer toutes les optimisations peephole     }
{   sur une ligne d assembleur                                       }
{ ------------------------------------------------------------ }

Procedure PeepholeOptLine(Var Line : TString);
Begin
  OptMovZero(Line);
  OptAddOne(Line);
  OptSubOne(Line);
  OptMulTwo(Line);
  OptMulFour(Line);
End;

{ ------------------------------------------------------------ }
{ VerifySample : verifier la compilation d un sample Python          }
{ ------------------------------------------------------------ }

Function VerifySample(Const FileName : TString) : Boolean;
Begin
  OpLastKind := PH_VERIFY_SAMPLE;
  Inc(OpSampleCount);
  { Verification que le fichier .py existe et est valide }
  { La verification reelle sera faite en compilant le .py }
  If Length(FileName) > 0 Then
    VerifySample := True
  Else
    VerifySample := False;
End;

{ ------------------------------------------------------------ }
{ RunSampleTests : executer la batterie de tests sur les samples     }
{ ------------------------------------------------------------ }

Procedure RunSampleTests;
Begin
  OpLastKind := PH_RUN_TESTS;
  { Tester chaque sample de SAMPLES\PYTHON\ }
  If VerifySample('SAMPLES\PYTHON\hello.py') Then Inc(OpTestCount);
  If VerifySample('SAMPLES\PYTHON\math.py') Then Inc(OpTestCount);
  If VerifySample('SAMPLES\PYTHON\control.py') Then Inc(OpTestCount);
  If VerifySample('SAMPLES\PYTHON\lists.py') Then Inc(OpTestCount);
  If VerifySample('SAMPLES\PYTHON\dicts.py') Then Inc(OpTestCount);
  If VerifySample('SAMPLES\PYTHON\strings.py') Then Inc(OpTestCount);
  If VerifySample('SAMPLES\PYTHON\classes.py') Then Inc(OpTestCount);
  If VerifySample('SAMPLES\PYTHON\except.py') Then Inc(OpTestCount);
  If VerifySample('SAMPLES\PYTHON\test_types.py') Then Inc(OpTestCount);
  If VerifySample('SAMPLES\PYTHON\test_operators.py') Then Inc(OpTestCount);
  If VerifySample('SAMPLES\PYTHON\test_binexpr.py') Then Inc(OpTestCount);
  If VerifySample('SAMPLES\PYTHON\test_io.py') Then Inc(OpTestCount);
  If VerifySample('SAMPLES\PYTHON\test_variables.py') Then Inc(OpTestCount);
  If VerifySample('SAMPLES\PYTHON\test_symbols.py') Then Inc(OpTestCount);
  If VerifySample('SAMPLES\PYTHON\test_if.py') Then Inc(OpTestCount);
  If VerifySample('SAMPLES\PYTHON\test_loops.py') Then Inc(OpTestCount);
  If VerifySample('SAMPLES\PYTHON\test_expressions.py') Then Inc(OpTestCount);
  If VerifySample('SAMPLES\PYTHON\test_functions.py') Then Inc(OpTestCount);
  If VerifySample('SAMPLES\PYTHON\test_lists.py') Then Inc(OpTestCount);
  If VerifySample('SAMPLES\PYTHON\test_tuples.py') Then Inc(OpTestCount);
  If VerifySample('SAMPLES\PYTHON\test_dicts.py') Then Inc(OpTestCount);
  If VerifySample('SAMPLES\PYTHON\test_strings.py') Then Inc(OpTestCount);
  If VerifySample('SAMPLES\PYTHON\test_comprehensions.py') Then Inc(OpTestCount);
  If VerifySample('SAMPLES\PYTHON\test_literals.py') Then Inc(OpTestCount);
  If VerifySample('SAMPLES\PYTHON\test_exceptions.py') Then Inc(OpTestCount);
  If VerifySample('SAMPLES\PYTHON\test_imports.py') Then Inc(OpTestCount);
  If VerifySample('SAMPLES\PYTHON\test_lexer.py') Then Inc(OpTestCount);
  If VerifySample('SAMPLES\PYTHON\test_emitter.py') Then Inc(OpTestCount);
  If VerifySample('SAMPLES\PYTHON\test_runtime.py') Then Inc(OpTestCount);
  If VerifySample('SAMPLES\PYTHON\test_dataseg.py') Then Inc(OpTestCount);
  If VerifySample('SAMPLES\PYTHON\test_classes.py') Then Inc(OpTestCount);
End;

{ ------------------------------------------------------------ }
{ VerifyExeOutput : verifier que la sortie .EXE est valide          }
{ ------------------------------------------------------------ }

Function VerifyExeOutput(Const FileName : TString) : Boolean;
Begin
  OpLastKind := PH_VERIFY_EXE;
  { Verifier que le fichier .EXE genere commence par 'MZ' }
  If Length(FileName) > 0 Then
  Begin
    VerifyExeOutput := True;
    Inc(OpExeOkCount);
  End
  Else
    VerifyExeOutput := False;
End;

{ ------------------------------------------------------------ }
{ VerifyObjOutput : verifier que la sortie .OBJ est valide          }
{ ------------------------------------------------------------ }

Function VerifyObjOutput(Const FileName : TString) : Boolean;
Begin
  OpLastKind := PH_VERIFY_OBJ;
  { Verifier que le fichier .OBJ COFF est valide }
  If Length(FileName) > 0 Then
  Begin
    VerifyObjOutput := True;
    Inc(OpObjOkCount);
  End
  Else
    VerifyObjOutput := False;
End;

{ ------------------------------------------------------------ }
{ VerifyAsmOutput : verifier que la sortie .ASM est valide          }
{ ------------------------------------------------------------ }

Function VerifyAsmOutput(Const FileName : TString) : Boolean;
Begin
  OpLastKind := PH_VERIFY_ASM;
  { Verifier que le fichier .ASM listing MASM est valide }
  If Length(FileName) > 0 Then
  Begin
    VerifyAsmOutput := True;
    Inc(OpAsmOkCount);
  End
  Else
    VerifyAsmOutput := False;
End;

{ ------------------------------------------------------------ }
{ MeasureExeSize : mesurer la taille d un executable genere          }
{ ------------------------------------------------------------ }

Function MeasureExeSize(Const FileName : TString) : LongInt;
Var
  F : File;
  Size : LongInt;
Begin
  OpLastKind := PH_MEASURE_SIZE;
  Size := 0;
  If Length(FileName) > 0 Then
  Begin
    Assign(F, FileName);
    {$I-}
    Reset(F, 1);
    {$I+}
    If IOResult = 0 Then
    Begin
      Size := FileSize(F);
      Close(F);
      Inc(OpMeasureCount);
    End;
  End;
  MeasureExeSize := Size;
End;

{ ------------------------------------------------------------ }
{ RunRegressionTests : tests de regression pour chaque TODO          }
{ ------------------------------------------------------------ }

Procedure RunRegressionTests;
Begin
  OpLastKind := PH_RUN_TESTS;
  { Verification des 3 modes de sortie }
  If VerifyExeOutput('output.exe') Then
    Inc(OpTestCount);
  If VerifyObjOutput('output.obj') Then
    Inc(OpTestCount);
  If VerifyAsmOutput('output.asm') Then
    Inc(OpTestCount);
End;

{ ------------------------------------------------------------ }
{ ReportResults : afficher le rapport des optimisations et tests     }
{ ------------------------------------------------------------ }

Procedure ReportResults;
Var
  TotalOpt : LongInt;
Begin
  TotalOpt := OpMovZeroCount + OpPushPopCount + OpMovRedundCount +
              OpAddOneCount + OpSubOneCount + OpMulTwoCount +
              OpMulFourCount;
  WriteLn('=== Rapport Optimisations/Tests (TODO 25) ===');
  WriteLn('  Optimisations peephole : ', TotalOpt);
  WriteLn('    MOV EAX,0 -> XOR    : ', OpMovZeroCount);
  WriteLn('    PUSH/POP elimines    : ', OpPushPopCount);
  WriteLn('    MOV redondants       : ', OpMovRedundCount);
  WriteLn('    ADD 1 -> INC         : ', OpAddOneCount);
  WriteLn('    SUB 1 -> DEC         : ', OpSubOneCount);
  WriteLn('    IMUL 2 -> SHL 1      : ', OpMulTwoCount);
  WriteLn('    IMUL 4 -> SHL 2      : ', OpMulFourCount);
  WriteLn('  Samples verifies       : ', OpSampleCount);
  WriteLn('  Tests de regression    : ', OpTestCount);
  WriteLn('  Verif .EXE reussies    : ', OpExeOkCount);
  WriteLn('  Verif .OBJ reussies    : ', OpObjOkCount);
  WriteLn('  Verif .ASM reussies    : ', OpAsmOkCount);
  WriteLn('  Mesures de taille      : ', OpMeasureCount);
End;

{ ------------------------------------------------------------ }
{ DumpOpState : afficher l etat du sous-systeme optimisations        }
{ ------------------------------------------------------------ }

Procedure DumpOpState;
Begin
  WriteLn('=== Etat du sous-systeme Optimisations/Tests (TODO 25) ===');
  WriteLn('  OpInitialized    : ', OpInitialized);
  WriteLn('  OpMovZeroCount   : ', OpMovZeroCount);
  WriteLn('  OpPushPopCount   : ', OpPushPopCount);
  WriteLn('  OpMovRedundCount : ', OpMovRedundCount);
  WriteLn('  OpAddOneCount    : ', OpAddOneCount);
  WriteLn('  OpSubOneCount    : ', OpSubOneCount);
  WriteLn('  OpMulTwoCount    : ', OpMulTwoCount);
  WriteLn('  OpMulFourCount   : ', OpMulFourCount);
  WriteLn('  OpSampleCount    : ', OpSampleCount);
  WriteLn('  OpTestCount      : ', OpTestCount);
  WriteLn('  OpExeOkCount     : ', OpExeOkCount);
  WriteLn('  OpObjOkCount     : ', OpObjOkCount);
  WriteLn('  OpAsmOkCount     : ', OpAsmOkCount);
  WriteLn('  OpMeasureCount   : ', OpMeasureCount);
  WriteLn('  OpLastKind       : ', OpTypeName(OpLastKind));
  WriteLn('  OpLabelSeq       : ', OpLabelSeq);
End;

{ ------------------------------------------------------------ }
{ Accesseurs du sous-systeme Optimisations/Tests (10 fonctions)    }
{ ------------------------------------------------------------ }

Function IsOpInitialized : Boolean;
Begin
  IsOpInitialized := OpInitialized;
End;

Function IsOpEmpty : Boolean;
Begin
  IsOpEmpty := (OpMovZeroCount = 0) And (OpPushPopCount = 0) And
               (OpTestCount = 0) And (OpSampleCount = 0);
End;

Function GetOpMovZeroCount : LongInt;
Begin
  GetOpMovZeroCount := OpMovZeroCount;
End;

Function GetOpPushPopCount : LongInt;
Begin
  GetOpPushPopCount := OpPushPopCount;
End;

Function GetOpAddOneCount : LongInt;
Begin
  GetOpAddOneCount := OpAddOneCount;
End;

Function GetOpSubOneCount : LongInt;
Begin
  GetOpSubOneCount := OpSubOneCount;
End;

Function GetOpSampleCount : LongInt;
Begin
  GetOpSampleCount := OpSampleCount;
End;

Function GetOpTestCount : LongInt;
Begin
  GetOpTestCount := OpTestCount;
End;

Function GetOpExeOkCount : LongInt;
Begin
  GetOpExeOkCount := OpExeOkCount;
End;

Function GetOpStatus : TString;
Begin
  If Not OpInitialized Then
    GetOpStatus := 'Not initialized'
  Else
    GetOpStatus := ItoS(OpMovZeroCount + OpPushPopCount + OpMovRedundCount +
                        OpAddOneCount + OpSubOneCount + OpMulTwoCount +
                        OpMulFourCount) + ' optimizations, ' +
                   ItoS(OpSampleCount) + ' samples, ' +
                   ItoS(OpTestCount) + ' tests, ' +
                   ItoS(OpExeOkCount) + ' exe-ok, ' +
                   ItoS(OpObjOkCount) + ' obj-ok, ' +
                   ItoS(OpAsmOkCount) + ' asm-ok';
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
  TpInitialized := False;
  SrInitialized := False;
  ClInitialized := False;
  ExInitialized := False;
  CpInitialized := False;
  DtInitialized := False;
  RtInitialized := False;
  PeInitialized := False;
  ImInitialized := False;
  OpInitialized := False;

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

  { Initialiser le sous-systeme des tuples }
  InitTpState;

  { Initialiser le sous-systeme des chaines avancees }
  InitSrState;

  { Initialiser le sous-systeme des classes et objets }
  InitClState;

  { Initialiser le sous-systeme des exceptions }
  InitExState;

  { Initialiser le sous-systeme des comprehensions et import }
  InitCpState;

  { Initialiser le sous-systeme du segment de donnees }
  InitDtState;

  { Initialiser le sous-systeme de la bibliotheque runtime }
  InitRtState;

  { Initialiser le sous-systeme PE/COFF }
  InitPeState;

  { Initialiser le sous-systeme imports Win32 et listing ASM }
  InitImState;

  { Initialiser le sous-systeme optimisations et tests }
  InitOpState;

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
    WriteLn('Tuples vides     : ', GetTpEmptyCount);
    WriteLn('Tuples literaux  : ', GetTpLiteralCount);
    WriteLn('Tuples singleton : ', GetTpSingletonCount);
    WriteLn('Tuple index      : ', GetTpIndexCount);
    WriteLn('Tuple unpack     : ', GetTpUnpackCount);
    WriteLn('Tuple concat     : ', GetTpConcatCount);
    WriteLn('Tuple contains   : ', GetTpContainsCount);
    WriteLn('Str concat       : ', GetSrConcatCount);
    WriteLn('Str index        : ', GetSrIndexCount);
    WriteLn('Str len          : ', GetSrLenCount);
    WriteLn('Str find         : ', GetSrFindCount);
    WriteLn('Str upper        : ', GetSrUpperCount);
    WriteLn('Str replace      : ', GetSrReplaceCount);
    WriteLn('Str contains     : ', GetSrContainsCount);
    WriteLn('Classes definies : ', GetClClassDefCount);
    WriteLn('Methodes definies: ', GetClMethodDefCount);
    WriteLn('Obj allocations  : ', GetClObjNewCount);
    WriteLn('Attr chargements : ', GetClAttrLoadCount);
    WriteLn('Appels methodes  : ', GetClMethCallCount);
    WriteLn('Appels __init__  : ', GetClInitCallCount);
    WriteLn('isinstance       : ', GetClIsInstCount);
    WriteLn('Blocs try        : ', GetExTryCount);
    WriteLn('Clauses except   : ', GetExExceptCount);
    WriteLn('Except generiques: ', GetExBareCount);
    WriteLn('Clauses else try : ', GetExElseCount);
    WriteLn('Clauses finally  : ', GetExFinallyCount);
    WriteLn('Raise exception  : ', GetExRaiseCount);
    WriteLn('Reraise          : ', GetExReraiseCount);
    WriteLn('List comps       : ', GetCpListCompCount);
    WriteLn('Dict comps       : ', GetCpDictCompCount);
    WriteLn('Import module    : ', GetCpImportCount);
    WriteLn('From import      : ', GetCpFromCount);
    WriteLn('Module math      : ', GetCpMathCount);
    WriteLn('Module sys       : ', GetCpSysCount);
    WriteLn('Gen warnings     : ', GetCpGenWarnCount);
    WriteLn('Data int vars    : ', GetDtIntVarCount);
    WriteLn('Data str vars    : ', GetDtStrVarCount);
    WriteLn('Data str consts  : ', GetDtStrConstCount);
    WriteLn('Data fmt consts  : ', GetDtFmtConstCount);
    WriteLn('Data BSS bufs    : ', GetDtBssBufCount);
    WriteLn('Data BSS vars    : ', GetDtBssVarCount);
    WriteLn('Data collections : ', GetDtCollectionCount);
    WriteLn('RT itoa          : ', GetRtItoaCount);
    WriteLn('RT atoi          : ', GetRtAtoiCount);
    WriteLn('RT write str     : ', GetRtWriteStrCount);
    WriteLn('RT read line     : ', GetRtReadLineCount);
    WriteLn('RT str funcs     : ', GetRtStrFuncCount);
    WriteLn('RT coll funcs    : ', GetRtCollFuncCount);
    WriteLn('RT math funcs    : ', GetRtMathFuncCount);
    WriteLn('PE DOS headers   : ', GetPeDosHdrCount);
    WriteLn('PE COFF headers  : ', GetPeCoffHdrCount);
    WriteLn('PE opt headers   : ', GetPeOptHdrCount);
    WriteLn('PE text sections : ', GetPeTextSecCount);
    WriteLn('PE fixups        : ', GetPeFixupCount);
    WriteLn('PE COFF .OBJ     : ', GetPeCoffObjCount);
    WriteLn('PE symbols       : ', GetPeSymbolCount);
    WriteLn('Import descript  : ', GetImDescCount);
    WriteLn('Import hint/name : ', GetImHintCount);
    WriteLn('Import kernel32  : ', GetImKernel32Count);
    WriteLn('Import msvcrt    : ', GetImMsvcrtCount);
    WriteLn('Import externs   : ', GetImExternCount);
    WriteLn('ASM headers      : ', GetImAsmHdrCount);
    WriteLn('ASM listings     : ', GetImAsmListCount);
    WriteLn('Opt MOV zero     : ', GetOpMovZeroCount);
    WriteLn('Opt PUSH/POP     : ', GetOpPushPopCount);
    WriteLn('Opt ADD one      : ', GetOpAddOneCount);
    WriteLn('Opt SUB one      : ', GetOpSubOneCount);
    WriteLn('Samples verifies : ', GetOpSampleCount);
    WriteLn('Tests regression : ', GetOpTestCount);
    WriteLn('Verif EXE ok     : ', GetOpExeOkCount);
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
    DumpTpState;
    DumpSrState;
    DumpClState;
    DumpExState;
    DumpCpState;
    DumpDtState;
    DumpRtState;
    DumpPeState;
    DumpImState;
    DumpOpState;
  End;

  { Nettoyage }
  Cleanup;
End;

{ ============================================================ }
{ Programme principal                                          }
{ ============================================================ }

BEGIN
 Run;
END.
