{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 0.1
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Compilateur Java vers assembleur 80386 pour Windows 32 bits
  @license: MIT
}

(* ============================================================
  JAVACW32.PAS - Compilateur Java vers assembleur
  80386 pour Windows 32 bits
  Free Pascal (-Mtp)
  Cible : MASM .386 / .MODEL FLAT, PE Win32

  Par defaut produit un fichier .EXE (PE Windows 32 bits).
  Avec le parametre -obj, produit uniquement un fichier .OBJ (COFF).
  Avec le parametre -asm, produit egalement un fichier .ASM lisible.
  Supporte tous les exemples SAMPLES\JAVA\*

  Voir DOC/TODO/JAVACW32.txt pour la feuille de route complete.

  TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES PE/COFF [IMPLEMENTE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings,
              EmitExe, EmitObj, EmitAsm)
            ParseArgs : analyser argv (source.java [-o sortie] [-v]
              [-d] [-w] [-obj] [-asm] [-h])
            Par defaut : produire un .EXE Windows 32 bits (PE)
            -obj : produire uniquement un .OBJ (format COFF 32 bits)
            -asm : produire egalement un listing assembleur .ASM lisible
            -o nom : specifier le nom du fichier de sortie
            FatalError, CompileError, WarnMsg
            EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .java du fichier source
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
              MAX_LOCAL=128, MAX_LOOP_NEST=32, MAX_TRY_NEST=16,
              MAX_ERRORS=30, MAX_STR=255, MAX_CLASS=64,
              MAX_METHOD=256, MAX_FIELD=256, MAX_IMPORT=32
            Prefixes de nommage ASM : _JV_ (variable globale/champ),
              _JF_ (methode statique), _JK_ (constante chaine),
              _JRT_ (routine runtime), _JL_ (label interne),
              _JC_ (classe/vtable), _JM_ (methode d instance)
            Utilitaires : ItoS, UpCaseStr, StrLowerCase, BaseName,
              ReplaceExt, AsmIdent
            10 fonctions accesseurs

  TODO 02 - TOKENISEUR JAVA (LEXER) [IMPLEMENTE]
            Procedure LexInit : ouvrir le fichier source, initialiser
              l etat du lexeur (ligne, colonne, caractere courant)
            Procedure LexClose : fermer le fichier source
            Procedure LexNextChar / LexPeekChar
            Format libre avec accolades (pas d indentation significative)
            Commentaires Java : // jusqu a fin de ligne,
              /* ... */ bloc multi-lignes,
              /** ... */ commentaires Javadoc (ignores)
            Procedure LexNextToken : reconnaitre les tokens Java :
              - Identificateurs : lettres, chiffres, souligne (_), dollar ($)
                Java est sensible a la casse
              - Litteraux entiers : 123, 0xFF, 0b1010, 1_000, suffixe L
              - Litteraux flottants : 1.5, 3.14, suffixes f/d (reconnus,
                tronques en entiers pour cette version)
              - Litteraux chaines : "texte" avec echappement
                Sequences d echappement : \n \t \r \\ \" \' \0 \xNN \uNNNN
              - Litteraux caractere : 'A' (un seul caractere)
              - Operateurs : + - * / % = == != < <= > >=
                & | ^ ~ << >> >>> += -= *= /= %= &= |= ^= <<= >>= >>>=
                ++ -- && || ! ? :
              - Separateurs : ( ) [ ] { } , ; . @
            Types de tokens (TK_EOF, TK_INTEGER, TK_FLOAT, TK_STRING,
              TK_CHAR, TK_IDENT, TK_KEYWORD, TK_OP, TK_PUNCT,
              TK_LBRACE, TK_RBRACE, TK_LBRACKET, TK_RBRACKET,
              TK_LPAREN, TK_RPAREN, TK_SEMICOLON, TK_DOT, TK_COMMA,
              TK_COLON, TK_QUESTION, TK_AT)
            Stocker dans CurTokKind / CurTokStr / CurTokInt
            LexScanIdent, LexScanNumber, LexScanString, LexScanChar
            LexScanEscChar
            Gestion des lignes et numeros de ligne pour diagnostics
            ParserAdvance : lire token suivant avec PrintToken si -d
            10 fonctions accesseurs

  TODO 03 - RECONNAISSANCE DES MOTS-CLES JAVA [IMPLEMENTE]
            Tous les mots reserves Java utilises dans ce sous-ensemble :
              Types primitifs : int, boolean, char, void, long, float,
                double, byte, short
              Controle : if, else, while, for, do, switch, case,
                default, break, continue, return
              Classes : class, extends, implements, new, this, super,
                instanceof
              Modificateurs : public, private, protected, static,
                final, abstract
              Exceptions : try, catch, finally, throw, throws
              Logiques : true, false, null
              Importation : import, package
            LookupKeyword : retourner KW_xxx ou TK_IDENT
            Constantes KW_INT..KW_PACKAGE pour chaque mot-cle
            Types primitifs reconnus : int (32 bits), boolean (32 bits),
              char (32 bits elargi), void (pas de retour),
              String (pointeur chaine)
            10 fonctions accesseurs

  TODO 04 - TABLE DES SYMBOLES JAVA (32 BITS) [IMPLEMENTE]
            Enregistrement TSymRec :
              Name      : nom Java (x, myMethod, MyClass)
              AsmName   : label ASM correspondant (_JV_x, _JF_MyClass_myMethod)
              Kind      : type de symbole (SK_LOCAL, SK_PARAM, SK_FIELD,
                SK_METHOD, SK_CLASS, SK_CONST, SK_STATIC)
              TypeIdx   : indice dans la table des types
              Offset    : offset dans le segment de donnees ou la pile
              ScopeLevel: niveau de portee imbrique
              IsStatic  : True si declare avec modificateur static
              IsFinal   : True si declare avec modificateur final
              IsPublic  : True si declare public
              DeclLine  : numero de ligne de declaration
              ClassName : nom de la classe proprietaire
            Procedures sur la table :
              SymInit, SymAdd, SymFind, SymFindInScope,
              SymCount, SymDump, SymNameClean, SymMangle
            Gestion de la portee : globale, classe, methode, bloc
            CurScope : compteur de portee imbriquee (max MAX_SCOPE)
            ScopeStack / ScopeTop : pile pour SymEnterScope / SymLeaveScope
            Resolution des noms : local -> classe -> imports
            Mangling des noms de methodes :
              _JF_ClassName_methodName
            10 fonctions accesseurs

  TODO 05 - SYSTEME DE TYPES JAVA [A FAIRE]
            TTypeKind : TYK_INT (32 bits signe), TYK_BOOLEAN (32 bits),
              TYK_CHAR (32 bits elargi), TYK_VOID (pas de valeur),
              TYK_STRING (ptr chaine), TYK_ARRAY (ptr tableau),
              TYK_OBJECT (ptr instance de classe),
              TYK_CLASS (descripteur de classe), TYK_NULL (reference nulle)
            TTypeRec : Name, Kind, Size, IsArray, ElemType
            TypeTab[MAX_TYPE], TypeCount
            Indices de types primitifs :
              TY_IDX_INT=0, TY_IDX_BOOLEAN=1, TY_IDX_CHAR=2,
              TY_IDX_VOID=3, TY_IDX_STRING=4, TY_IDX_NULL=5,
              TY_IDX_INTARR=6, TY_IDX_CHARARR=7, TY_IDX_STRARR=8,
              TY_IDX_BOOLARR=9
            TypeInit : enregistrer les types primitifs Java
            TypeKindOf(idx) : retourner le TTypeKind pour un indice
            TypeSizeOf(idx) : INT=4, BOOLEAN=4, CHAR=4, STRING=4(ptr),
              ARRAY=4(ptr), OBJECT=4(ptr), VOID=0
            TypeFindByName(name) : rechercher un type par nom -> index
            TypeKindStr(kind) : nom textuel d un TTypeKind
            Verification de types statique a la compilation :
              compatibilite affectation, compatibilite operateurs
            instanceof : verification dynamique -> EAX=0|1
            Tableaux : int[], char[], boolean[], String[]
            10 fonctions accesseurs

  TODO 06 - LITTERAUX ET CONSTANTES [A FAIRE]
            Entiers decimaux : 0..2147483647 (32 bits signe)
            Entiers hexadecimaux : 0xFF, binaires : 0b1010
            Separateur de chiffres : 1_000_000 (ignore le souligne)
            Flottants : reconnus par le lexeur, tronques en entiers
            Chaines : "abc" -> pointeur vers donnees DATA
              Sequences d echappement : \n \t \r \\ \" \' \0 \xNN \uNNNN
            Caracteres : 'A' -> valeur entiere du caractere
            null : constante reference nulle -> EAX=0
            true : constante booleenne -> EAX=1
            false : constante booleenne -> EAX=0
            Constantes final : int final N = 42; -> valeur immediate
            TExprKind : EK_NONE, EK_IMM, EK_EAX, EK_MEM
            TExprVal : Kind, ImmVal, TypeIdx, Offset, SymIdx
            TDataKind : DK_DWORD, DK_BYTE, DK_STR, DK_ARRAY_BLK
            TDataRec : LblName, Kind, IntVal, StrVal, ElemCount
            DataAdd, DataAddStr, DataAddDWord : gestion du segment DATA
            ExprMakeImm, ExprMakeNull, ExprMakeBool, ExprMakeEAX
            LitEvalInt, LitEvalStr, LitEvalChar, LitEval
            LabelGen : generateur de labels uniques _JL_N
            10 fonctions accesseurs

  TODO 07 - OPERATEURS ET PRECEDENCE [A FAIRE]
            Arithmetiques : + - * / % (division entiere pour int)
            Comparaison : == != < <= > >= (int, char, references)
            Logiques : && || ! (court-circuit, evaluation booleenne)
            Bit a bit : & | ^ ~ << >> >>> (AND, OR, XOR, NOT,
              decalage gauche, droite signe, droite non-signe)
            Unaire : + - ~ ! ++ -- (pre et post-increment/decrement)
            Operateur ternaire : cond ? val_si_vrai : val_si_faux
            Concatenation de chaines : + avec au moins un String
            Affectation : = += -= *= /= %= &= |= ^= <<= >>= >>>=
            Precedence (du plus fort au plus faible) :
              1. ++ -- (postfixe), . [] ()
              2. ++ -- (prefixe), + - ~ ! (unaires)
              3. * / %
              4. + - (binaires, concatenation String)
              5. << >> >>>
              6. < <= > >= instanceof
              7. == !=
              8. &
              9. ^
              10. |
              11. &&
              12. ||
              13. ? : (ternaire)
              14. = += -= *= /= %= &= |= ^= <<= >>= >>>=
            BinOpPrec, BinOpIsRight, IsAssignOp
            ParsePrimary, ParseUnary, ParseExprPrec, ParseExpr
            ExprFlushToEAX, ExprEmitBinOp
            Pliage de constantes pour expressions statiques
            10 fonctions accesseurs

  TODO 08 - PARSEUR : EXPRESSIONS PRIMAIRES ET APPELS [A FAIRE]
            ParsePrimary : literal entier, literal chaine, literal char,
              ident, appel de methode, null, true, false
            Acces champ : expr.field -> offset dans instance de classe
            Acces index tableau : expr[i] ->
              calcul offset + MOV EAX, [EBX+4+i*4]
              Verification des bornes optionnelle
            Appel de methode statique : ClassName.method(args) ->
              PUSH args droite a gauche + CALL _JF_ClassName_method
              + ADD ESP, args_size
            Appel de methode d instance : obj.method(args) ->
              PUSH this + PUSH args + CALL _JM_ClassName_method
              + ADD ESP, (1+args)*4
            new ClassName(args) : allocation instance + appel constructeur
            new int[n] : allocation tableau sur le heap
            Parentheses : (expr) -> regroupement de priorite
            Cast explicite : (int)expr, (char)expr ->
              conversion ou troncature
            System.out.println(expr) / System.out.print(expr) :
              reconnaissance comme appel special d E/S
            Scanner.nextLine() / Scanner.nextInt() :
              reconnaissance comme appel special de saisie
            Operateur ternaire : cond ? a : b -> code conditionnel
            10 fonctions accesseurs

  TODO 09 - PARSEUR : VARIABLES ET AFFECTATIONS [A FAIRE]
            Variables locales : pile EBP, acces [EBP-offset]
              Declaration : int x; ou int x = expr;
              Plusieurs dans une ligne : int a, b, c;
            Parametres de methode : pile EBP, acces [EBP+offset]
            Champs statiques de classe : segment DATA, acces par label
              _JV_ClassName_fieldName
              MOV EAX, DWORD [_JV_ClassName_x] pour lecture
              MOV DWORD [_JV_ClassName_x], EAX pour ecriture
            Constantes final : int final N = 42; -> substitution immediate
            Affectation simple : x = expr ->
              evaluer expr + MOV destination, EAX
            Affectation augmentee : x += expr -> charger x,
              evaluer expr, ADD EAX, resultat, stocker
              Supportees : += -= *= /= %= &= |= ^= <<= >>= >>>=
            Pre-increment/decrement : ++x / --x
            Post-increment/decrement : x++ / x--
            Affectation tableau : tab[i] = expr ->
              calcul adresse + MOV [EBX+4+i*4], EAX
            Typage statique : verification de compatibilite de type
              a l affectation
            10 fonctions accesseurs

  TODO 10 - PARSEUR : IF / ELSE ET OPERATEUR TERNAIRE [A FAIRE]
            ParseIfStmt : if (cond) { bloc } [else if (cond) { bloc }]
              [else { bloc }]
              Accolades obligatoires pour les blocs
              Emission : evaluer cond -> TEST EAX, EAX / JZ label
              Labels : _JL_ELIF_N, _JL_ELSE_N, _JL_ENDIF_N
            if sans accolades : instruction unique permise
              if (cond) stmt; else stmt;
            Operateur ternaire (dans les expressions) :
              val = cond ? a : b
              Emission : evaluer cond, JZ vers else-branch,
                evaluer a, JMP fin, label else, evaluer b, label fin
            Conditions composees : && / || avec court-circuit
            Comparaisons chainees : non supportees en Java (correct)
            10 fonctions accesseurs

  TODO 11 - PARSEUR : BOUCLES while / for / do-while / break / continue [A FAIRE]
            ParseWhileStmt : while (cond) { bloc }
              Labels : _JL_WTEST_N, _JL_WEND_N
              Emission : _JL_WTEST_N: evaluer cond, JZ _JL_WEND_N,
                corps, JMP _JL_WTEST_N, _JL_WEND_N:
            ParseDoWhileStmt : do { bloc } while (cond);
              Labels : _JL_DSTART_N, _JL_DTEST_N, _JL_DEND_N
              Emission : _JL_DSTART_N: corps, _JL_DTEST_N: evaluer cond,
                JNZ _JL_DSTART_N, _JL_DEND_N:
            ParseForStmt : for (init; cond; incr) { bloc }
              Labels : _JL_FTEST_N, _JL_FINCR_N, _JL_FEND_N
              Emission : init, _JL_FTEST_N: evaluer cond,
                JZ _JL_FEND_N, corps, _JL_FINCR_N: incr,
                JMP _JL_FTEST_N, _JL_FEND_N:
            Enhanced for (for-each) : for (int x : tab) { bloc }
              Iterer sur les elements d un tableau
              Labels : _JL_FETEST_N, _JL_FEEND_N
            break : JMP vers _JL_WEND_N ou _JL_FEND_N ou _JL_DEND_N
            continue : JMP vers _JL_WTEST_N ou _JL_FINCR_N ou _JL_DTEST_N
            LoopPush / LoopPop : pile de labels pour break/continue
            Boucles imbriquees supportees (MAX_LOOP_NEST)
            10 fonctions accesseurs

  TODO 12 - PARSEUR : METHODES STATIQUES ET RETURN [A FAIRE]
            ParseMethodDecl : public static type nom(params) { bloc }
            Parametres : passage par valeur sur la pile (cdecl)
            Types de retour : int, boolean, char, void, String, int[]
            Convention d appel 80386 :
              Parametres empiles de droite a gauche (cdecl)
              Valeur de retour dans EAX
              L appelant nettoie la pile apres CALL
            Prologue : PUSH EBP / MOV EBP, ESP / SUB ESP, locals_size
              Variables locales accessibles via [EBP-offset]
              Parametres accessibles via [EBP+8], [EBP+12], ...
            Epilogue : MOV ESP, EBP / POP EBP / RET
            return expr : MOV EAX, valeur + JMP vers epilogue
            return sans valeur (void) : JMP epilogue
            Recursion : supportee naturellement via la pile
            Point d entree main :
              public static void main(String[] args)
              Label _JF_ClassName_main comme point d entree
            Surcharge de methodes : non supportee (avertissement)
            Appel : PUSH args + CALL _JF_ClassName_method + ADD ESP, n*4
            10 fonctions accesseurs

  TODO 13 - PARSEUR : ENTREES/SORTIES (System.out / Scanner) [A FAIRE]
            System.out.println(expr) :
              Evaluer l argument, convertir en chaine si necessaire
              Appeler _JRT_WRITESTR pour afficher
              Appeler _JRT_WRITECRLF pour le retour a la ligne
            System.out.print(expr) :
              Afficher sans retour a la ligne
            System.out.println(n) avec int : CALL _JRT_ITOA + _JRT_WRITESTR
            System.out.println(s) avec String : _JRT_WRITESTR directement
            System.out.println(true/false) : ecrire "true" ou "false"
            System.out.println(c) avec char : ecrire le caractere
            Concatenation dans println : "texte " + n ->
              convertir chaque partie, concatener, afficher
            Scanner input :
              Scanner sc = new Scanner(System.in) (reconnu)
              sc.nextLine() : CALL _JRT_READLINE -> EAX=ptr
              sc.nextInt() : CALL _JRT_READLINE + _JRT_ATOI -> EAX
            Win32 API pour les E/S console :
              GetStdHandle(STD_OUTPUT_HANDLE) pour ecriture
              GetStdHandle(STD_INPUT_HANDLE) pour lecture
              WriteFile pour l affichage
              ReadFile pour la saisie
            10 fonctions accesseurs

  TODO 14 - PARSEUR : TABLEAUX (int[], char[], String[]) [A FAIRE]
            Declaration et allocation : int[] tab = new int[n];
              Allocation sur le heap : _JRT_HEAPALLOC((n+1)*4)
              Layout memoire : [length DD][elem0 DD][elem1 DD]...
            Initialisation par liste : int[] tab = {10, 20, 30};
              Allocation + stockage des elements
            Acces par index : tab[i] ->
              verification des bornes optionnelle
              calcul offset + MOV EAX, [EBX+4+i*4]
            Affectation par index : tab[i] = val ->
              MOV [EBX+4+i*4], EAX
            tab.length : MOV EAX, [EBX] (compteur en tete de tableau)
            Enhanced for : for (int x : tab) { ... }
              Boucle sur les elements sequentiellement
            ArrayIndexOutOfBoundsException :
              verification optionnelle des bornes
              CMP index, [EBX] / JAE _JRT_BOUNDS_ERR
            Tableaux de char : char[] -> acces octet par octet
            Tableaux de String : String[] -> tableau de pointeurs
            Passage de tableau en parametre : par reference (pointeur)
            10 fonctions accesseurs

  TODO 15 - PARSEUR : CHAINES (String) OPERATIONS [A FAIRE]
            Concatenation : s1 + s2 ->
              CALL _JRT_STRCONCAT -> EAX=ptr
            Concatenation mixte : "texte" + n ->
              convertir n en chaine via _JRT_ITOA puis concatener
            s.length() : CALL _JRT_STRLEN(ESI=str) -> EAX
            s.charAt(i) : acces au caractere a la position i ->
              MOVZX EAX, BYTE [ESI+i]
            s.equals(t) : CALL _JRT_STRCMP -> EAX=0|1
            s.compareTo(t) : CALL _JRT_STRCMP -> EAX=-1|0|1
            s.substring(begin, end) : CALL _JRT_STRSLICE -> EAX=ptr
            s.indexOf(sub) : CALL _JRT_STRFIND -> EAX=index ou -1
            s.toUpperCase() / s.toLowerCase() :
              CALL _JRT_STRUPPER / _JRT_STRLOWER -> EAX=ptr
            s.trim() : CALL _JRT_STRTRIM -> EAX=ptr
            s.contains(sub) : CALL _JRT_STRCONTAINS -> EAX=0|1
            s.startsWith(prefix) / s.endsWith(suffix) -> EAX=0|1
            s.replace(old, new) : CALL _JRT_STRREPLACE -> EAX=ptr
            Comparaison : == compare les references,
              equals() compare le contenu
            String.valueOf(n) : conversion entier -> chaine
            10 fonctions accesseurs

  TODO 16 - PARSEUR : CLASSES, OBJETS ET CONSTRUCTEURS [A FAIRE]
            ParseClassDecl : public class Nom { corps }
              ou class Nom extends Parent { corps }
            Champs d instance : stockes dans un bloc sur le heap
              Layout objet : [typecode DD][field0 DD][field1 DD]...
              Acces : this.field ->
                MOV EBX, [EBP+8] / MOV EAX, [EBX+4+offset*4]
            Champs statiques : dans le segment DATA
              _JV_ClassName_field DD 0
            Methodes d instance : def methode(this + params)
              this est le premier parametre implicite (pointeur instance)
              Label : _JM_ClassName_method
            Constructeur : public ClassName(params) { ... }
              Allocation : new ClassName(args) ->
                CALL _JRT_OBJNEW(ECX=taille)
                + CALL _JM_ClassName_init -> EAX=ptr instance
            Heritage simple : class Enfant extends Parent
              Copie des champs du parent + ajout des nouveaux
            Appel super() : appeler le constructeur du parent
            Appel de methode : obj.method(args) ->
              PUSH this + PUSH args + CALL _JM_ClassName_method
              + ADD ESP, (1+nargs)*4
            instanceof : comparaison du typecode -> EAX=0|1
            Table des classes : MAX_CLASS entrees avec
              champs et methodes
            10 fonctions accesseurs

  TODO 17 - PARSEUR : SWITCH / CASE / DEFAULT [A FAIRE]
            ParseSwitchStmt : switch (expr) { case val: stmts; ... }
              Evaluer l expression de selection
              Generer une table de sauts ou une chaine de CMP/JE
            case valeur: stmts ->
              _JL_CASE_N: comparer et executer
              CMP EAX, valeur / JE _JL_CASE_N
            default: stmts ->
              _JL_DEFAULT_N: label pour le cas par defaut
              Execute si aucun case ne correspond
            break dans switch : JMP _JL_SWITCH_END_N
              Sans break, fall-through vers le case suivant
            Fall-through : comportement Java standard entre les case
              si break est absent
            Cases multiples : case 1: case 2: stmts ->
              plusieurs labels pour le meme bloc
            Expression int ou char seulement dans switch
            Labels : _JL_SWITCH_N, _JL_CASE_N_K, _JL_DEFAULT_N,
              _JL_SWITCH_END_N
            10 fonctions accesseurs

  TODO 18 - PARSEUR : EXCEPTIONS (try / catch / finally / throw) [A FAIRE]
            ParseTryStmt : try { bloc } catch (Type var) { bloc }
              [catch (Type2 var2) { bloc2 }] [finally { bloc }]
            try { bloc } -> sauvegarder handler courant, installer nouveau
            catch (ExceptionType e) { bloc } -> label _JL_CATCH_N,
              CMP code exception, executer le bloc correspondant
            Multiples catch : chaine de comparaisons de types
            finally { bloc } -> toujours execute (_JL_FINALLY_N)
            throw new ExceptionType(msg) : lever une exception
              EAX = code exception, EBX = ptr message
            Mecanisme d exceptions sans support OS :
              _JX_HANDLER DD 0 dans DATA (ptr vers handler courant)
              _JX_CODE DD 0 (code d exception actif)
              _JX_MSG DD 0 (ptr message d exception)
            TRY : sauvegarder ancien handler, installer nouveau label
            CATCH : tester le code, router vers le bon handler
            FINALLY : toujours execute, puis restaurer handler
            throw sans handler : afficher message d erreur
              + PUSH 1 / CALL ExitProcess
            Pile de try imbriques (MAX_TRY_NEST)
            NullPointerException : detection optionnelle des acces null
            ArrayIndexOutOfBoundsException : detection optionnelle
            10 fonctions accesseurs

  TODO 19 - PARSEUR : IMPORT ET PACKAGE [A FAIRE]
            package nom.sous_nom; : declaration du package
              Enregistrer le nom du package comme prefixe optionnel
              Package ignore pour la generation de code (flat namespace)
            import java.util.Scanner; : seul import fonctionnel
              Activer la reconnaissance de Scanner dans le parseur
              Scanner sc = new Scanner(System.in);
              sc.nextLine(), sc.nextInt()
            import java.lang.*; : implicite, ignore silencieusement
            import java.util.*; : reconnu, active Scanner
            Imports non supportes : emettre un avertissement
              pour les imports inconnus
            Gestion des classes publiques :
              Une seule classe publique par fichier .java
              Le nom de la classe publique doit correspondre au fichier
            Resolution de classe : ClassName.methodName
              Prefixe de la classe courante pour les methodes statiques
            Table d imports : MAX_IMPORT entrees
            10 fonctions accesseurs

  TODO 20 - PARSEUR : CONVERSIONS DE TYPES ET CASTS [A FAIRE]
            Cast explicite entre types primitifs :
              (int) charExpr -> MOVZX EAX (valeur entiere du char)
              (char) intExpr -> AND EAX, 0FFh (tronquer a 8 bits)
              (boolean) intExpr -> TEST EAX, EAX / SETNZ AL / MOVZX
            Conversions implicites dans les expressions :
              char vers int : promotion automatique dans les operations
              int vers String : conversion implicite dans la concatenation +
                via _JRT_ITOA
              boolean vers String : "true" ou "false" dans println
              char vers String : chaine d un caractere dans println
            Integer.parseInt(s) : CALL _JRT_ATOI -> EAX
              Conversion chaine vers entier
            String.valueOf(n) : CALL _JRT_ITOA -> EAX=ptr
              Conversion entier vers chaine
            Verification de types a la compilation :
              Erreur si types incompatibles dans une affectation
              Erreur si condition non booleenne dans if/while
              Avertissement pour les casts potentiellement perdants
            10 fonctions accesseurs

  TODO 21 - GENERATION DE CODE : SEGMENT DE DONNEES 80386 [A FAIRE]
            Section .data (variables initialisees) :
              Champ statique int : _JV_ClassName_field DD 0
              Champ statique String : _JV_ClassName_field DD _JK_N (ptr)
              Champ statique boolean : _JV_ClassName_field DD 0
              Champ statique char : _JV_ClassName_field DD 0
            Constantes chaines :
              _JK_N DB 'texte', 0 (NUL-terminated)
            Constantes de format :
              _JK_FMT_N DB 'format...', 0
            Constantes speciales :
              _JK_TRUE DB 'true', 0
              _JK_FALSE DB 'false', 0
              _JK_NULL DB 'null', 0
              _JK_CRLF DB 13, 10, 0
              _JK_SPACE DB ' ', 0
            Section .data? (BSS - variables non initialisees) :
              _J_IOBUF DB 256 DUP(?)
              _J_NUMBUF DB 32 DUP(?)
            Variables runtime :
              _J_STDOUT DD ?  (handle console sortie)
              _J_STDIN  DD ?  (handle console entree)
              _J_WRITTEN DD ? (octets ecrits par WriteFile)
              _J_READ   DD ?  (octets lus par ReadFile)
            Heap dynamique :
              _J_HEAP DB 65536 DUP(0)
              _J_HEAPTOP DD 0
            Tableaux dans DATA : blocs de DD avec compteur en tete
            Alignement des donnees sur 4 octets (DWORD)
            10 fonctions accesseurs

  TODO 22 - BIBLIOTHEQUE RUNTIME JAVA (E/S, CONVERSIONS VIA WIN32) [A FAIRE]
            Routines de conversion :
              _JRT_ITOA : entier 32 bits -> chaine decimale ASCII
                Utilisation de DIV par 10 en boucle
              _JRT_ATOI : chaine ASCII -> entier 32 bits
                Utilisation de IMUL par 10 et ADD
              _JRT_BOOLTOSTR : 0 -> "false", <>0 -> "true"
              _JRT_CHARTOSTR : valeur char -> chaine 1 caractere
              _JRT_NULLTOSTR : -> "null"
            Routines d E/S console :
              _JRT_INITIO : initialiser les handles console
                PUSH STD_OUTPUT_HANDLE / CALL GetStdHandle
                MOV [_J_STDOUT], EAX
                PUSH STD_INPUT_HANDLE / CALL GetStdHandle
                MOV [_J_STDIN], EAX
              _JRT_WRITESTR : ecrire chaine sur la console
                PUSH 0 / LEA EAX, [_J_WRITTEN] / PUSH EAX
                PUSH longueur / PUSH adresse / PUSH [_J_STDOUT]
                CALL WriteFile
              _JRT_WRITECRLF : ecrire un retour a la ligne
              _JRT_READLINE : lire une ligne depuis la console
                ReadFile + suppression CR/LF -> EAX=ptr chaine
            Routines chaines :
              _JRT_STRLEN, _JRT_STRCONCAT, _JRT_STRCMP,
              _JRT_STRSLICE, _JRT_STRFIND,
              _JRT_STRUPPER, _JRT_STRLOWER, _JRT_STRTRIM,
              _JRT_STRREPLACE, _JRT_STRCONTAINS,
              _JRT_STRSTARTSWITH, _JRT_STRENDSWITH
            Routines tableaux :
              _JRT_ARRALLOC : allocation tableau sur le heap
              _JRT_ARRGET : lecture element avec verification bornes
              _JRT_ARRSET : ecriture element avec verification bornes
              _JRT_ARRLEN : retourner la longueur du tableau
              _JRT_ARRCOPY : copier un tableau
            Routines objets :
              _JRT_OBJNEW : allocation instance sur le heap
              _JRT_HEAPALLOC : allocation generique sur le heap
            _JRT_PANIC : affiche message erreur + ExitProcess(1)
            _JRT_BOUNDS_ERR : ArrayIndexOutOfBoundsException + exit
            _JRT_NULL_ERR : NullPointerException + exit
            Heap allocation : _JRT_HEAPALLOC(ECX=taille) -> EAX=ptr
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
                Symboles definis pour methodes/champs Java
              Table des chaines (noms > 8 caracteres)
            Mode -obj : appeler GenerateCoffObj au lieu de GeneratePeExe
            10 fonctions accesseurs

  TODO 24 - IMPORTS API WIN32 ET GENERATEUR LISTING ASM [A FAIRE]
            Imports kernel32.dll :
              ExitProcess : terminer le programme
              GetStdHandle : obtenir les handles console
              WriteFile : ecrire sur la console (System.out)
              ReadFile : lire depuis la console (Scanner)
              GetProcessHeap, HeapAlloc, HeapFree :
                allocation dynamique (new, tableaux)
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
              Routines runtime (_JRT_)
              Methodes Java avec labels (_JF_, _JM_)
              Commentaires avec le code source Java
              Indentation et formatage lisible
            10 fonctions accesseurs

  TODO 25 - OPTIMISATIONS, TESTS FINAUX ET INTEGRATION SAMPLES\JAVA\* [A FAIRE]
            Optimisations peephole :
              MOV EAX, 0 -> XOR EAX, EAX
              PUSH EAX / POP EAX -> (eliminer)
              MOV EAX, [x] / MOV [x], EAX -> (eliminer deuxieme)
              ADD EAX, 1 -> INC EAX
              SUB EAX, 1 -> DEC EAX
              IMUL EAX, 2 -> SHL EAX, 1
              IMUL EAX, 4 -> SHL EAX, 2
            Verification : compiler et executer les exemples
              SAMPLES\JAVA\Hello.java          - hello world minimal
              SAMPLES\JAVA\test01_hello.java   - System.out.println, chaines
              SAMPLES\JAVA\test02_vars.java    - int, boolean, char, affectations
              SAMPLES\JAVA\test03_arith.java   - + - * / % += -= *= /= %= ++ --
              SAMPLES\JAVA\test04_cond.java    - if/else, == != < > <= >=, && || !
              SAMPLES\JAVA\test05_while.java   - while, break, continue
              SAMPLES\JAVA\test06_for.java     - for, boucles imbriquees, break
              SAMPLES\JAVA\test07_fonct.java   - methodes statiques, return, recursion
              SAMPLES\JAVA\test08_string.java  - concatenation, Scanner.nextLine
              SAMPLES\JAVA\test09_array.java   - int[], new, index, for-each, length
              SAMPLES\JAVA\test10_recurs.java  - fact, fib, recursion directe
            Tests de regression pour chaque TODO
            Verification des 3 modes de sortie :
              .EXE (defaut), .OBJ (-obj), .ASM (-asm)
            Mesure de la taille des executables generes
            10 fonctions accesseurs

  ============================================================ *)

Program JAVACW32;

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
  JAVACW32_VERSION = '0.1';
  JAVACW32_DATE    = '2026';

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
  MAX_LOCAL      = 128;
  MAX_LOOP_NEST  = 32;
  MAX_TRY_NEST   = 16;
  MAX_ERRORS     = 30;
  MAX_STR        = 255;
  MAX_CLASS      = 64;
  MAX_METHOD     = 256;
  MAX_FIELD      = 256;
  MAX_IMPORT     = 32;
  MAX_TYPE       = 64;

  { Prefixes de nommage ASM }
  JV_VAR_PFX  = '_JV_';     { variable globale / champ statique      }
  JV_FN_PFX   = '_JF_';     { methode statique                       }
  JV_STR_PFX  = '_JK_';     { constante chaine litterale             }
  JV_RT_PFX   = '_JRT_';    { routine runtime                        }
  JV_LBL_PFX  = '_JL_';     { label de saut interne                  }
  JV_CLS_PFX  = '_JC_';     { classe / vtable                        }
  JV_MTH_PFX  = '_JM_';     { methode d instance                     }

Type
  TString = String;

  TOptions = Record
    SrcFile    : TString;   { fichier source Java (.java)            }
    OutFile    : TString;   { fichier sortie (.exe, .obj)            }
    Verbose    : Boolean;   { -v : banniere et statistiques          }
    DebugMode  : Boolean;   { -d : affichage de chaque token         }
    Warnings   : Boolean;   { -w : afficher les avertissements       }
    EmitExe    : Boolean;   { par defaut : produire un .EXE (PE)     }
    EmitObj    : Boolean;   { -obj : produire seulement un .OBJ      }
    EmitAsm    : Boolean;   { -asm : produire aussi un .ASM          }
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

{ Transforme un nom Java en identifiant valide pour l assembleur }
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
  WriteLn('JAVACW32: FATAL: ', Msg);
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
  Halt(EXIT_ERROR);
End;

Procedure CompileError(Const Msg : TString; Line : Integer);
Begin
  Write('JAVACW32:');
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
  WriteLn('JAVACW32: warning: ', Msg);
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
  WriteLn('JAVACW32 v', JAVACW32_VERSION, ' (', JAVACW32_DATE,
          ') - Compilateur Java vers 80386 (Windows PE 32 bits)');
  WriteLn('JAVACW32 - Cette commande permet de lancer le compilateur Java ',
          'pour l''assembleur du microprocesseur 80386 (en executable ',
          'Windows 32 bits).');
  WriteLn;
  WriteLn('Syntaxe : JAVACW32 [options] <source.java> [options]');
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
  WriteLn('  JAVACW32 Hello.java');
  WriteLn('  JAVACW32 Hello.java -o Hello.exe -v');
  WriteLn('  JAVACW32 test01_hello.java -asm');
  WriteLn('  JAVACW32 test02_vars.java -obj -w');
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
    WriteLn('JAVACW32: fichier source manquant');
    ShowHelp;
  End;

  { Verifier l extension .java }
  Ext := ExtractExt(Opts.SrcFile);
  If Ext <> '.java' Then
    WarnMsg('extension attendue .java, trouvee: ' + Ext);

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
  WriteLn('JAVACW32 v', JAVACW32_VERSION, ' (', JAVACW32_DATE,
          ') - Compilateur Java -> 80386 PE Win32');
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
  GetCompilerVersion := JAVACW32_VERSION;
End;

Function GetCompilerDate : TString;
Begin
  GetCompilerDate := JAVACW32_DATE;
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
{ TODO 02 - TOKENISEUR JAVA (LEXER)               [IMPLEMENTE] }
{ ============================================================ }

Const
  { Types de tokens Java }
  TK_EOF       = 0;    { fin de fichier                          }
  TK_INTEGER   = 1;    { litteral entier (42, 0xFF, 0b1010)      }
  TK_FLOAT     = 2;    { litteral flottant (3.14, 1.5e3)         }
  TK_STRING    = 3;    { litteral chaine "abc"                    }
  TK_CHAR      = 4;    { litteral caractere 'A'                   }
  TK_IDENT     = 5;    { identificateur (non mot-cle)             }
  TK_KEYWORD   = 6;    { mot-cle Java reconnu                     }
  TK_OP        = 7;    { operateur + - * / == != etc.             }
  TK_PUNCT     = 8;    { ponctuation generique                    }
  TK_LBRACE    = 9;    { accolade ouvrante                        }
  TK_RBRACE    = 10;   { accolade fermante                        }
  TK_LBRACKET  = 11;   { [                                        }
  TK_RBRACKET  = 12;   { ]                                        }
  TK_LPAREN    = 13;   { (                                        }
  TK_RPAREN    = 14;   { )                                        }
  TK_SEMICOLON = 15;   { ;                                        }
  TK_DOT       = 16;   { .                                        }
  TK_COMMA     = 17;   { ,                                        }
  TK_COLON     = 18;   { :                                        }
  TK_QUESTION  = 19;   { ?                                        }
  TK_AT        = 20;   { @                                        }

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
  IsIdentStart := IsAlpha(Ch) Or (Ch = '_') Or (Ch = '$');
End;

Function IsIdentCont(Ch : Char) : Boolean;
Begin
  IsIdentCont := IsAlpha(Ch) Or IsDigit(Ch) Or
                 (Ch = '_') Or (Ch = '$');
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
  LexNextLine;
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
{ LexScanIdent : identificateur Java (sensible a la casse)     }
{ Java accepte lettres, chiffres, _ et $                        }
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

  { Tester si c est un mot-cle Java }
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
{ LexScanNumber : litteral numerique Java                      }
{ Entiers : 123, 0xFF, 0b1010, 1_000, suffixe L               }
{ Flottants : 1.5, 3.14, suffixes f/d (tronques en entiers)   }
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

  { Detecter prefixe 0x 0b }
  If (Ch = '0') And (LexColNo < Length(LexLine)) Then
  Begin
    Ch := LexLine[LexColNo + 1];
    If (Ch = 'x') Or (Ch = 'X') Then
    Begin
      Base := 16;
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

  { Suffixe L (long) : ignorer }
  If (LexColNo <= Length(LexLine)) And
     ((LexLine[LexColNo] = 'L') Or (LexLine[LexColNo] = 'l')) Then
    Inc(LexColNo);

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

  { Suffixe f/d (float/double) : ignorer, marquer comme float }
  If (LexColNo <= Length(LexLine)) And
     ((LexLine[LexColNo] = 'f') Or (LexLine[LexColNo] = 'F') Or
      (LexLine[LexColNo] = 'd') Or (LexLine[LexColNo] = 'D')) Then
  Begin
    IsFloat := True;
    Inc(LexColNo);
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
{ LexScanEscChar : decoder une sequence d echappement Java     }
{ Supporte : \n \t \r \\ \" \' \0 \xNN \uNNNN                 }
{ ------------------------------------------------------------ }

Function LexScanEscChar : Char;
Var
  Ch : Char;
  V  : Integer;
  I  : Integer;
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
    'u'       :
    Begin
      V := 0;
      For I := 1 To 4 Do
      Begin
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
{ LexScanString : chaine Java "texte" avec echappement         }
{ ------------------------------------------------------------ }

Procedure LexScanString;
Var
  S  : TString;
  Ch : Char;
Begin
  S := '';
  Inc(LexColNo); { sauter le " ouvrant }
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
      If Length(S) < MAX_STR Then S := S + Ch;
    End
    Else
    Begin
      If Length(S) < MAX_STR Then S := S + Ch;
      Inc(LexColNo);
    End;
  End;
  CurTokKind  := TK_STRING;
  CurTokStr   := S;
  CurTokInt   := 0;
  CurTokFloat := 0.0;
End;

{ ------------------------------------------------------------ }
{ LexScanChar : litteral caractere Java 'A'                    }
{ ------------------------------------------------------------ }

Procedure LexScanChar;
Var
  Ch : Char;
Begin
  Inc(LexColNo); { sauter le ' ouvrant }
  Ch := #0;
  If LexColNo <= Length(LexLine) Then
  Begin
    If LexLine[LexColNo] = '\' Then
    Begin
      Inc(LexColNo);
      Ch := LexScanEscChar;
    End
    Else
    Begin
      Ch := LexLine[LexColNo];
      Inc(LexColNo);
    End;
  End;
  { Sauter le ' fermant }
  If (LexColNo <= Length(LexLine)) And
     (LexLine[LexColNo] = '''') Then
    Inc(LexColNo);
  CurTokKind  := TK_CHAR;
  CurTokStr   := Ch;
  CurTokInt   := Ord(Ch);
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
    TK_EOF       : Write('EOF');
    TK_INTEGER   : Write('INT(', CurTokInt, ')');
    TK_FLOAT     : Write('FLOAT(', CurTokStr, ')');
    TK_STRING    : Write('STR("', CurTokStr, '")');
    TK_CHAR      : Write('CHAR(''', CurTokStr, ''')');
    TK_IDENT     : Write('IDENT(', CurTokStr, ')');
    TK_KEYWORD   : Write('KW(', CurTokStr, ')');
    TK_OP        : Write('OP(', CurTokStr, ')');
    TK_PUNCT     : Write('PUNCT(', CurTokStr, ')');
    TK_LBRACE    : Write('LBRACE');
    TK_RBRACE    : Write('RBRACE');
    TK_LBRACKET  : Write('LBRACKET');
    TK_RBRACKET  : Write('RBRACKET');
    TK_LPAREN    : Write('LPAREN');
    TK_RPAREN    : Write('RPAREN');
    TK_SEMICOLON : Write('SEMICOLON');
    TK_DOT       : Write('DOT');
    TK_COMMA     : Write('COMMA');
    TK_COLON     : Write('COLON');
    TK_QUESTION  : Write('QUESTION');
    TK_AT        : Write('AT');
  Else
    Write('TOK(', CurTokKind, ')');
  End;
  WriteLn;
End;

{ ------------------------------------------------------------ }
{ LexNextToken : reconnaitre le prochain token Java            }
{ Gere les commentaires // et /* */, tous les operateurs Java  }
{ ------------------------------------------------------------ }

Procedure LexNextToken;
Var
  Ch       : Char;
  Scanning : Boolean;
Begin
  CurTokInt   := 0;
  CurTokFloat := 0.0;

  Scanning := True;
  While Scanning Do
  Begin
    { Avancer si on est en fin de ligne }
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
      LexNextLine;

    { Fin de fichier }
    If LexEOF Then
    Begin
      CurTokKind := TK_EOF;
      CurTokStr  := '';
      CurTokLine := LexLineNo;
      CurTokCol  := LexColNo;
      Scanning := False;
      Break;
    End;

    CurTokLine := LexLineNo;
    CurTokCol  := LexColNo;
    Ch := LexLine[LexColNo];

    { Espaces et tabulations }
    If (Ch = ' ') Or (Ch = #9) Or (Ch = #13) Or (Ch = #12) Then
      Inc(LexColNo)

    { Commentaire // : jusqu a fin de ligne }
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '/') Then
      LexColNo := Length(LexLine) + 1

    { Commentaire /* ... */ et /** ... */ (Javadoc) }
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '*') Then
    Begin
      Inc(LexColNo, 2);
      While Not LexEOF Do
      Begin
        If LexColNo > Length(LexLine) Then
        Begin
          LexNextLine;
          Continue;
        End;
        If (LexLine[LexColNo] = '*') And
           (LexColNo < Length(LexLine)) And
           (LexLine[LexColNo + 1] = '/') Then
        Begin
          Inc(LexColNo, 2);
          Break;
        End;
        Inc(LexColNo);
      End;
    End

    { Identificateur ou mot-cle }
    Else If IsIdentStart(Ch) Then
    Begin
      LexScanIdent;
      Scanning := False;
    End

    { Nombre }
    Else If (Ch >= '0') And (Ch <= '9') Then
    Begin
      LexScanNumber;
      Scanning := False;
    End

    { Chaine de caracteres "..." }
    Else If Ch = '"' Then
    Begin
      LexScanString;
      Scanning := False;
    End

    { Litteral caractere '.' }
    Else If Ch = '''' Then
    Begin
      LexScanChar;
      Scanning := False;
    End

    { >>>= }
    Else If (Ch = '>') And (LexColNo + 3 <= Length(LexLine)) And
            (LexLine[LexColNo + 1] = '>') And
            (LexLine[LexColNo + 2] = '>') And
            (LexLine[LexColNo + 3] = '=') Then
    Begin
      Inc(LexColNo, 4);
      CurTokKind := TK_OP; CurTokStr := '>>>=';
      Scanning := False;
    End

    { >>> }
    Else If (Ch = '>') And (LexColNo + 2 <= Length(LexLine)) And
            (LexLine[LexColNo + 1] = '>') And
            (LexLine[LexColNo + 2] = '>') Then
    Begin
      Inc(LexColNo, 3);
      CurTokKind := TK_OP; CurTokStr := '>>>';
      Scanning := False;
    End

    { >>= }
    Else If (Ch = '>') And (LexColNo + 2 <= Length(LexLine)) And
            (LexLine[LexColNo + 1] = '>') And
            (LexLine[LexColNo + 2] = '=') Then
    Begin
      Inc(LexColNo, 3);
      CurTokKind := TK_OP; CurTokStr := '>>=';
      Scanning := False;
    End

    { >> }
    Else If (Ch = '>') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '>') Then
    Begin
      Inc(LexColNo, 2);
      CurTokKind := TK_OP; CurTokStr := '>>';
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

    { <<= }
    Else If (Ch = '<') And (LexColNo + 2 <= Length(LexLine)) And
            (LexLine[LexColNo + 1] = '<') And
            (LexLine[LexColNo + 2] = '=') Then
    Begin
      Inc(LexColNo, 3);
      CurTokKind := TK_OP; CurTokStr := '<<=';
      Scanning := False;
    End

    { << }
    Else If (Ch = '<') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '<') Then
    Begin
      Inc(LexColNo, 2);
      CurTokKind := TK_OP; CurTokStr := '<<';
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

    { ! }
    Else If Ch = '!' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_OP; CurTokStr := '!';
      Scanning := False;
    End

    { && }
    Else If (Ch = '&') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '&') Then
    Begin
      Inc(LexColNo, 2);
      CurTokKind := TK_OP; CurTokStr := '&&';
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

    { || }
    Else If (Ch = '|') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '|') Then
    Begin
      Inc(LexColNo, 2);
      CurTokKind := TK_OP; CurTokStr := '||';
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

    { ++ }
    Else If (Ch = '+') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '+') Then
    Begin
      Inc(LexColNo, 2);
      CurTokKind := TK_OP; CurTokStr := '++';
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

    { -- }
    Else If (Ch = '-') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '-') Then
    Begin
      Inc(LexColNo, 2);
      CurTokKind := TK_OP; CurTokStr := '--';
      Scanning := False;
    End

    { -= }
    Else If (Ch = '-') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo, 2);
      CurTokKind := TK_OP; CurTokStr := '-=';
      Scanning := False;
    End

    { - }
    Else If Ch = '-' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_OP; CurTokStr := '-';
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

    { /= (/ et // deja geres dans les commentaires) }
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

    { ? }
    Else If Ch = '?' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_QUESTION;
      CurTokStr  := '?';
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

    { @ }
    Else If Ch = '@' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_AT;
      CurTokStr  := '@';
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

    { , }
    Else If Ch = ',' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_COMMA;
      CurTokStr  := ',';
      Scanning := False;
    End

    { ; }
    Else If Ch = ';' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_SEMICOLON;
      CurTokStr  := ';';
      Scanning := False;
    End

    { ( }
    Else If Ch = '(' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_LPAREN;
      CurTokStr  := '(';
      Scanning := False;
    End

    { ) }
    Else If Ch = ')' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_RPAREN;
      CurTokStr  := ')';
      Scanning := False;
    End

    { [ }
    Else If Ch = '[' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_LBRACKET;
      CurTokStr  := '[';
      Scanning := False;
    End

    { ] }
    Else If Ch = ']' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_RBRACKET;
      CurTokStr  := ']';
      Scanning := False;
    End

    { accolade ouvrante }
    Else If Ch = '{' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_LBRACE;
      CurTokStr  := '{';
      Scanning := False;
    End

    { accolade fermante }
    Else If Ch = '}' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_RBRACE;
      CurTokStr  := '}';
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
{ TODO 03 - RECONNAISSANCE DES MOTS-CLES JAVA    [IMPLEMENTE] }
{ ============================================================ }

Const
  { Mots-cles Java : types primitifs }
  KW_INT        = 1;    { int                                      }
  KW_BOOLEAN    = 2;    { boolean                                  }
  KW_CHAR       = 3;    { char                                     }
  KW_VOID       = 4;    { void                                     }
  KW_LONG       = 5;    { long                                     }
  KW_FLOAT      = 6;    { float                                    }
  KW_DOUBLE     = 7;    { double                                   }
  KW_BYTE       = 8;    { byte                                     }
  KW_SHORT      = 9;    { short                                    }

  { Mots-cles Java : controle }
  KW_IF         = 20;   { if                                       }
  KW_ELSE       = 21;   { else                                     }
  KW_WHILE      = 22;   { while                                    }
  KW_FOR        = 23;   { for                                      }
  KW_DO         = 24;   { do                                       }
  KW_SWITCH     = 25;   { switch                                   }
  KW_CASE       = 26;   { case                                     }
  KW_DEFAULT    = 27;   { default                                  }
  KW_BREAK      = 28;   { break                                    }
  KW_CONTINUE   = 29;   { continue                                 }
  KW_RETURN     = 30;   { return                                   }

  { Mots-cles Java : classes }
  KW_CLASS      = 40;   { class                                    }
  KW_EXTENDS    = 41;   { extends                                  }
  KW_IMPLEMENTS = 42;   { implements                               }
  KW_NEW        = 43;   { new                                      }
  KW_THIS       = 44;   { this                                     }
  KW_SUPER      = 45;   { super                                    }
  KW_INSTANCEOF = 46;   { instanceof                               }

  { Mots-cles Java : modificateurs }
  KW_PUBLIC     = 50;   { public                                   }
  KW_PRIVATE    = 51;   { private                                  }
  KW_PROTECTED  = 52;   { protected                                }
  KW_STATIC     = 53;   { static                                   }
  KW_FINAL      = 54;   { final                                    }
  KW_ABSTRACT   = 55;   { abstract                                 }

  { Mots-cles Java : exceptions }
  KW_TRY        = 60;   { try                                      }
  KW_CATCH      = 61;   { catch                                    }
  KW_FINALLY    = 62;   { finally                                  }
  KW_THROW      = 63;   { throw                                    }
  KW_THROWS     = 64;   { throws                                   }

  { Mots-cles Java : logiques }
  KW_TRUE       = 70;   { true                                     }
  KW_FALSE      = 71;   { false                                    }
  KW_NULL       = 72;   { null                                     }

  { Mots-cles Java : importation }
  KW_IMPORT     = 80;   { import                                   }
  KW_PACKAGE    = 81;   { package                                  }

  KW_TOTAL_KEYWORDS = 38;  { nombre total de mots-cles Java        }

Var
  KwInitialized : Boolean;       { True si etat initialise               }
  KwLookupCount : LongInt;       { nombre d appels a LookupKeyword       }
  KwHitCount    : LongInt;       { nombre de mots-cles reconnus          }
  KwLabelSeq    : Integer;       { sequence pour labels uniques          }
  KwLastKW      : Integer;       { dernier mot-cle reconnu (KW_*)        }
  KwTotalIdents : LongInt;       { total d identificateurs testes        }

{ ------------------------------------------------------------ }
{ InitKwState : initialiser les compteurs de mots-cles         }
{ ------------------------------------------------------------ }

Procedure InitKwState;
Begin
  KwInitialized := True;
  KwLookupCount := 0;
  KwHitCount    := 0;
  KwLabelSeq    := 0;
  KwLastKW      := 0;
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
    KW_INT        : KwTypeName := 'KW_INT';
    KW_BOOLEAN    : KwTypeName := 'KW_BOOLEAN';
    KW_CHAR       : KwTypeName := 'KW_CHAR';
    KW_VOID       : KwTypeName := 'KW_VOID';
    KW_LONG       : KwTypeName := 'KW_LONG';
    KW_FLOAT      : KwTypeName := 'KW_FLOAT';
    KW_DOUBLE     : KwTypeName := 'KW_DOUBLE';
    KW_BYTE       : KwTypeName := 'KW_BYTE';
    KW_SHORT      : KwTypeName := 'KW_SHORT';
    KW_IF         : KwTypeName := 'KW_IF';
    KW_ELSE       : KwTypeName := 'KW_ELSE';
    KW_WHILE      : KwTypeName := 'KW_WHILE';
    KW_FOR        : KwTypeName := 'KW_FOR';
    KW_DO         : KwTypeName := 'KW_DO';
    KW_SWITCH     : KwTypeName := 'KW_SWITCH';
    KW_CASE       : KwTypeName := 'KW_CASE';
    KW_DEFAULT    : KwTypeName := 'KW_DEFAULT';
    KW_BREAK      : KwTypeName := 'KW_BREAK';
    KW_CONTINUE   : KwTypeName := 'KW_CONTINUE';
    KW_RETURN     : KwTypeName := 'KW_RETURN';
    KW_CLASS      : KwTypeName := 'KW_CLASS';
    KW_EXTENDS    : KwTypeName := 'KW_EXTENDS';
    KW_IMPLEMENTS : KwTypeName := 'KW_IMPLEMENTS';
    KW_NEW        : KwTypeName := 'KW_NEW';
    KW_THIS       : KwTypeName := 'KW_THIS';
    KW_SUPER      : KwTypeName := 'KW_SUPER';
    KW_INSTANCEOF : KwTypeName := 'KW_INSTANCEOF';
    KW_PUBLIC     : KwTypeName := 'KW_PUBLIC';
    KW_PRIVATE    : KwTypeName := 'KW_PRIVATE';
    KW_PROTECTED  : KwTypeName := 'KW_PROTECTED';
    KW_STATIC     : KwTypeName := 'KW_STATIC';
    KW_FINAL      : KwTypeName := 'KW_FINAL';
    KW_ABSTRACT   : KwTypeName := 'KW_ABSTRACT';
    KW_TRY        : KwTypeName := 'KW_TRY';
    KW_CATCH      : KwTypeName := 'KW_CATCH';
    KW_FINALLY    : KwTypeName := 'KW_FINALLY';
    KW_THROW      : KwTypeName := 'KW_THROW';
    KW_THROWS     : KwTypeName := 'KW_THROWS';
    KW_TRUE       : KwTypeName := 'KW_TRUE';
    KW_FALSE      : KwTypeName := 'KW_FALSE';
    KW_NULL       : KwTypeName := 'KW_NULL';
    KW_IMPORT     : KwTypeName := 'KW_IMPORT';
    KW_PACKAGE    : KwTypeName := 'KW_PACKAGE';
  Else
    KwTypeName := 'KW_UNKNOWN(' + ItoS(KW) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ LookupKeyword : retourner KW_xxx ou KW_NONE si non reconnu   }
{ Java est sensible a la casse                                  }
{ ------------------------------------------------------------ }

Function LookupKeyword(Const S : TString) : Integer;
Var
  R : Integer;
Begin
  Inc(KwLookupCount);
  Inc(KwTotalIdents);
  R := 0;

  { Types primitifs }
  If      S = 'int'        Then R := KW_INT
  Else If S = 'boolean'    Then R := KW_BOOLEAN
  Else If S = 'char'       Then R := KW_CHAR
  Else If S = 'void'       Then R := KW_VOID
  Else If S = 'long'       Then R := KW_LONG
  Else If S = 'float'      Then R := KW_FLOAT
  Else If S = 'double'     Then R := KW_DOUBLE
  Else If S = 'byte'       Then R := KW_BYTE
  Else If S = 'short'      Then R := KW_SHORT

  { Controle }
  Else If S = 'if'         Then R := KW_IF
  Else If S = 'else'       Then R := KW_ELSE
  Else If S = 'while'      Then R := KW_WHILE
  Else If S = 'for'        Then R := KW_FOR
  Else If S = 'do'         Then R := KW_DO
  Else If S = 'switch'     Then R := KW_SWITCH
  Else If S = 'case'       Then R := KW_CASE
  Else If S = 'default'    Then R := KW_DEFAULT
  Else If S = 'break'      Then R := KW_BREAK
  Else If S = 'continue'   Then R := KW_CONTINUE
  Else If S = 'return'     Then R := KW_RETURN

  { Classes }
  Else If S = 'class'      Then R := KW_CLASS
  Else If S = 'extends'    Then R := KW_EXTENDS
  Else If S = 'implements' Then R := KW_IMPLEMENTS
  Else If S = 'new'        Then R := KW_NEW
  Else If S = 'this'       Then R := KW_THIS
  Else If S = 'super'      Then R := KW_SUPER
  Else If S = 'instanceof' Then R := KW_INSTANCEOF

  { Modificateurs }
  Else If S = 'public'     Then R := KW_PUBLIC
  Else If S = 'private'    Then R := KW_PRIVATE
  Else If S = 'protected'  Then R := KW_PROTECTED
  Else If S = 'static'     Then R := KW_STATIC
  Else If S = 'final'      Then R := KW_FINAL
  Else If S = 'abstract'   Then R := KW_ABSTRACT

  { Exceptions }
  Else If S = 'try'        Then R := KW_TRY
  Else If S = 'catch'      Then R := KW_CATCH
  Else If S = 'finally'    Then R := KW_FINALLY
  Else If S = 'throw'      Then R := KW_THROW
  Else If S = 'throws'     Then R := KW_THROWS

  { Logiques }
  Else If S = 'true'       Then R := KW_TRUE
  Else If S = 'false'      Then R := KW_FALSE
  Else If S = 'null'       Then R := KW_NULL

  { Importation }
  Else If S = 'import'     Then R := KW_IMPORT
  Else If S = 'package'    Then R := KW_PACKAGE;

  If R <> 0 Then
  Begin
    Inc(KwHitCount);
    KwLastKW := R;
  End;

  LookupKeyword := R;
End;

{ ------------------------------------------------------------ }
{ GetKeywordName : retourner le mot-cle Java pour un KW_*      }
{ ------------------------------------------------------------ }

Function GetKeywordName(KW : Integer) : TString;
Begin
  Case KW Of
    KW_INT        : GetKeywordName := 'int';
    KW_BOOLEAN    : GetKeywordName := 'boolean';
    KW_CHAR       : GetKeywordName := 'char';
    KW_VOID       : GetKeywordName := 'void';
    KW_LONG       : GetKeywordName := 'long';
    KW_FLOAT      : GetKeywordName := 'float';
    KW_DOUBLE     : GetKeywordName := 'double';
    KW_BYTE       : GetKeywordName := 'byte';
    KW_SHORT      : GetKeywordName := 'short';
    KW_IF         : GetKeywordName := 'if';
    KW_ELSE       : GetKeywordName := 'else';
    KW_WHILE      : GetKeywordName := 'while';
    KW_FOR        : GetKeywordName := 'for';
    KW_DO         : GetKeywordName := 'do';
    KW_SWITCH     : GetKeywordName := 'switch';
    KW_CASE       : GetKeywordName := 'case';
    KW_DEFAULT    : GetKeywordName := 'default';
    KW_BREAK      : GetKeywordName := 'break';
    KW_CONTINUE   : GetKeywordName := 'continue';
    KW_RETURN     : GetKeywordName := 'return';
    KW_CLASS      : GetKeywordName := 'class';
    KW_EXTENDS    : GetKeywordName := 'extends';
    KW_IMPLEMENTS : GetKeywordName := 'implements';
    KW_NEW        : GetKeywordName := 'new';
    KW_THIS       : GetKeywordName := 'this';
    KW_SUPER      : GetKeywordName := 'super';
    KW_INSTANCEOF : GetKeywordName := 'instanceof';
    KW_PUBLIC     : GetKeywordName := 'public';
    KW_PRIVATE    : GetKeywordName := 'private';
    KW_PROTECTED  : GetKeywordName := 'protected';
    KW_STATIC     : GetKeywordName := 'static';
    KW_FINAL      : GetKeywordName := 'final';
    KW_ABSTRACT   : GetKeywordName := 'abstract';
    KW_TRY        : GetKeywordName := 'try';
    KW_CATCH      : GetKeywordName := 'catch';
    KW_FINALLY    : GetKeywordName := 'finally';
    KW_THROW      : GetKeywordName := 'throw';
    KW_THROWS     : GetKeywordName := 'throws';
    KW_TRUE       : GetKeywordName := 'true';
    KW_FALSE      : GetKeywordName := 'false';
    KW_NULL       : GetKeywordName := 'null';
    KW_IMPORT     : GetKeywordName := 'import';
    KW_PACKAGE    : GetKeywordName := 'package';
  Else
    GetKeywordName := '?';
  End;
End;

{ ------------------------------------------------------------ }
{ IsKeyword : teste si un KW_* est valide (non zero)           }
{ ------------------------------------------------------------ }

Function IsKeyword(KW : Integer) : Boolean;
Begin
  IsKeyword := (KW > 0) And (KW <= KW_PACKAGE);
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
  WriteLn('  KwTotalIdents : ', KwTotalIdents);
  WriteLn('  KwLastKW      : ', KwTypeName(KwLastKW));
  WriteLn('  Keywords      : ', KW_TOTAL_KEYWORDS);
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
  IsKwEmpty := (KwHitCount = 0);
End;

Function GetKwLookupCount : LongInt;
Begin
  GetKwLookupCount := KwLookupCount;
End;

Function GetKwHitCount : LongInt;
Begin
  GetKwHitCount := KwHitCount;
End;

Function GetKwTotalIdents : LongInt;
Begin
  GetKwTotalIdents := KwTotalIdents;
End;

Function GetKwLastKW : Integer;
Begin
  GetKwLastKW := KwLastKW;
End;

Function GetKwLabelSeq : Integer;
Begin
  GetKwLabelSeq := KwLabelSeq;
End;

Function GetKwTotalKeywords : Integer;
Begin
  GetKwTotalKeywords := KW_TOTAL_KEYWORDS;
End;

Function GetKwLastKWName : TString;
Begin
  If KwLastKW <> 0 Then
    GetKwLastKWName := GetKeywordName(KwLastKW)
  Else
    GetKwLastKWName := '(none)';
End;

Function GetKwStatus : TString;
Begin
  If Not KwInitialized Then
    GetKwStatus := 'Not initialized'
  Else
    GetKwStatus := ItoS(KwHitCount) + ' keywords (' +
                   ItoS(KwTotalIdents) + ' idents tested)';
End;

{ ============================================================ }
{ TODO 04 - TABLE DES SYMBOLES JAVA (32 BITS)    [IMPLEMENTE] }
{ ============================================================ }

Const
  { Types de symboles SK_* }
  SK_NONE    = 0;    { aucun / non defini                       }
  SK_LOCAL   = 1;    { variable locale (methode/bloc)            }
  SK_PARAM   = 2;    { parametre de methode                     }
  SK_FIELD   = 3;    { champ d instance de classe                }
  SK_METHOD  = 4;    { methode (statique ou d instance)          }
  SK_CLASS   = 5;    { classe                                    }
  SK_CONST   = 6;    { constante (final static)                  }
  SK_STATIC  = 7;    { champ statique de classe                  }
  SK_MAX     = 7;    { valeur maximale SK_*                     }

Type
  TSymRec = Record
    Name       : TString;       { nom Java (x, myMethod, MyClass)     }
    AsmName    : TString;       { label ASM (_JV_x, _JF_C_m)          }
    Kind       : Integer;       { SK_LOCAL..SK_STATIC                  }
    TypeIdx    : Integer;       { indice dans la table des types       }
    Offset     : LongInt;       { offset segment data ou pile          }
    ScopeLevel : Integer;       { niveau de portee imbrique            }
    IsStatic   : Boolean;       { True si declare static               }
    IsFinal    : Boolean;       { True si declare final                }
    IsPublic   : Boolean;       { True si declare public               }
    DeclLine   : Integer;       { numero de ligne de declaration       }
    ClassName  : TString;       { nom de la classe proprietaire        }
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
    SK_LOCAL   : SymKindName := 'SK_LOCAL';
    SK_PARAM   : SymKindName := 'SK_PARAM';
    SK_FIELD   : SymKindName := 'SK_FIELD';
    SK_METHOD  : SymKindName := 'SK_METHOD';
    SK_CLASS   : SymKindName := 'SK_CLASS';
    SK_CONST   : SymKindName := 'SK_CONST';
    SK_STATIC  : SymKindName := 'SK_STATIC';
  Else
    SymKindName := 'SK_?(' + ItoS(K) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ SymNameClean : nettoyer un nom Java pour usage ASM            }
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
{ SymMangle : generer le label ASM pour un symbole Java         }
{ Prefixe selon le type et la classe proprietaire               }
{   SK_METHOD  : _JF_ClassName_methodName (statique)            }
{                _JM_ClassName_methodName (instance)             }
{   SK_CLASS   : _JC_ClassName                                  }
{   SK_FIELD   : _JV_ClassName_fieldName                        }
{   SK_STATIC  : _JV_ClassName_fieldName                        }
{   SK_CONST   : _JV_ClassName_constName                        }
{   SK_LOCAL/SK_PARAM : _JV_name (pas de prefix classe)         }
{ ------------------------------------------------------------ }

Function SymMangle(Const Name : TString; Kind : Integer;
                   Const ClsName : TString;
                   Static : Boolean) : TString;
Var
  Clean    : TString;
  ClsClean : TString;
Begin
  Clean := SymNameClean(Name);
  ClsClean := SymNameClean(ClsName);
  Case Kind Of
    SK_METHOD :
      Begin
        If Static Then
          SymMangle := JV_FN_PFX + ClsClean + '_' + Clean
        Else
          SymMangle := JV_MTH_PFX + ClsClean + '_' + Clean;
      End;
    SK_CLASS :
      SymMangle := JV_CLS_PFX + Clean;
    SK_FIELD, SK_STATIC, SK_CONST :
      Begin
        If ClsClean <> '' Then
          SymMangle := JV_VAR_PFX + ClsClean + '_' + Clean
        Else
          SymMangle := JV_VAR_PFX + Clean;
      End;
  Else
    SymMangle := JV_VAR_PFX + Clean;
  End;
End;

{ ------------------------------------------------------------ }
{ SymAdd : ajouter un symbole a la table                        }
{ Retourne l indice du symbole ajoute, ou -1 si table pleine   }
{ ------------------------------------------------------------ }

Function SymAdd(Const Name : TString; Kind : Integer;
                TypeIdx : Integer; DeclLine : Integer;
                Const ClsName : TString;
                Static, Final, Pub : Boolean) : Integer;
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
  SymTab[Idx].AsmName    := SymMangle(Name, Kind, ClsName, Static);
  SymTab[Idx].Kind       := Kind;
  SymTab[Idx].TypeIdx    := TypeIdx;
  SymTab[Idx].Offset     := 0;
  SymTab[Idx].ScopeLevel := CurScope;
  SymTab[Idx].IsStatic   := Static;
  SymTab[Idx].IsFinal    := Final;
  SymTab[Idx].IsPublic   := Pub;
  SymTab[Idx].DeclLine   := DeclLine;
  SymTab[Idx].ClassName  := ClsName;
  Inc(SymTabCount);
  Inc(SymAddCount);
  SymLastName := Name;
  SymAdd := Idx;
End;

{ ------------------------------------------------------------ }
{ SymFind : rechercher un symbole par nom (derniere occurrence) }
{ Resolution : local -> classe -> imports                       }
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
{ (globale, classe, methode, bloc)                              }
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
    If SymTab[I].ClassName <> '' Then
      WriteLn('       class=', SymTab[I].ClassName);
    If SymTab[I].IsStatic Then
      WriteLn('       static=True');
    If SymTab[I].IsFinal Then
      WriteLn('       final=True');
    If SymTab[I].IsPublic Then
      WriteLn('       public=True');
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
{ Programme principal (TODO 01-04)                              }
{ ============================================================ }

Begin
  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  OutFOpen   := False;
  BcActive   := False;

  ParseArgs;
  ShowBanner;

  WriteLn('JAVACW32: compilation de ', Opts.SrcFile, ' ...');

  InitKwState;
  SymInit;
  LexInit;
  ParserAdvance;

  { Boucle de tokenisation (TODO 02-04) }
  While CurTokKind <> TK_EOF Do
    ParserAdvance;

  LexClose;

  WriteLn('JAVACW32: TODO 05..25 [A FAIRE] - pas encore implemente');

  ShowStats;
  Cleanup;

  If ErrorCount > 0 Then
    Halt(EXIT_ERROR)
  Else
    Halt(EXIT_OK);
End.
