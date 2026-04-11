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

  TODO 05 - SYSTEME DE TYPES JAVA [IMPLEMENTE]
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

  TODO 06 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
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

  TODO 07 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
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

  TODO 08 - PARSEUR : EXPRESSIONS PRIMAIRES ET APPELS [IMPLEMENTE]
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

  TODO 09 - PARSEUR : VARIABLES ET AFFECTATIONS [IMPLEMENTE]
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

  TODO 10 - PARSEUR : IF / ELSE ET OPERATEUR TERNAIRE [IMPLEMENTE]
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

  TODO 11 - PARSEUR : BOUCLES while / for / do-while / break / continue [IMPLEMENTE]
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

  TODO 12 - PARSEUR : METHODES STATIQUES ET RETURN [IMPLEMENTE]
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

  TODO 13 - PARSEUR : ENTREES/SORTIES (System.out / Scanner) [IMPLEMENTE]
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

  TODO 14 - PARSEUR : TABLEAUX (int[], char[], String[]) [IMPLEMENTE]
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

  TODO 15 - PARSEUR : CHAINES (String) OPERATIONS [IMPLEMENTE]
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

  TODO 16 - PARSEUR : CLASSES, OBJETS ET CONSTRUCTEURS [IMPLEMENTE]
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

  TODO 17 - PARSEUR : SWITCH / CASE / DEFAULT [IMPLEMENTE]
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

  TODO 18 - PARSEUR : EXCEPTIONS (try / catch / finally / throw) [IMPLEMENTE]
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

  TODO 19 - PARSEUR : IMPORT ET PACKAGE [IMPLEMENTE]
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

  TODO 20 - PARSEUR : CONVERSIONS DE TYPES ET CASTS [IMPLEMENTE]
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

  TODO 21 - GENERATION DE CODE : SEGMENT DE DONNEES 80386 [IMPLEMENTE]
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
{ TODO 05 - SYSTEME DE TYPES JAVA               [IMPLEMENTE]  }
{ ============================================================ }

Const
  { TTypeKind : types Java }
  TYK_INT     = 0;    { entier 32 bits signe                     }
  TYK_BOOLEAN = 1;    { booleen 32 bits (0 ou 1)                 }
  TYK_CHAR    = 2;    { caractere 32 bits elargi                 }
  TYK_VOID    = 3;    { pas de valeur (retour void)              }
  TYK_STRING  = 4;    { ptr vers chaine (java.lang.String)       }
  TYK_ARRAY   = 5;    { ptr vers tableau                         }
  TYK_OBJECT  = 6;    { ptr vers instance de classe              }
  TYK_CLASS   = 7;    { descripteur de classe                    }
  TYK_NULL    = 8;    { reference nulle                          }
  TYK_MAX     = 8;    { valeur maximale TYK_*                    }

  { Indices des types primitifs dans TypeTab }
  TY_IDX_INT     = 0;
  TY_IDX_BOOLEAN = 1;
  TY_IDX_CHAR    = 2;
  TY_IDX_VOID    = 3;
  TY_IDX_STRING  = 4;
  TY_IDX_NULL    = 5;
  TY_IDX_INTARR  = 6;
  TY_IDX_CHARARR = 7;
  TY_IDX_STRARR  = 8;
  TY_IDX_BOOLARR = 9;
  TY_PRIM_COUNT  = 10;  { nombre de types primitifs              }

Type
  TTypeRec = Record
    Name     : TString;       { nom du type ('int', 'boolean', ...)  }
    Kind     : Integer;       { TYK_INT..TYK_NULL                    }
    Size     : Integer;       { taille en octets (32 bits)           }
    IsArray  : Boolean;       { True si type tableau                 }
    ElemType : Integer;       { indice du type element (si tableau)  }
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
{ les 10 types primitifs Java                                   }
{ ------------------------------------------------------------ }

Procedure TypeInit;

  Procedure AddPrim(Const N : TString; K, S : Integer;
                    Arr : Boolean; Elem : Integer);
  Begin
    If TypeCount < MAX_TYPE Then
    Begin
      TypeTab[TypeCount].Name     := N;
      TypeTab[TypeCount].Kind     := K;
      TypeTab[TypeCount].Size     := S;
      TypeTab[TypeCount].IsArray  := Arr;
      TypeTab[TypeCount].ElemType := Elem;
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
  AddPrim('int',       TYK_INT,     4, False, -1);  { TY_IDX_INT     = 0 }
  AddPrim('boolean',   TYK_BOOLEAN, 4, False, -1);  { TY_IDX_BOOLEAN = 1 }
  AddPrim('char',      TYK_CHAR,    4, False, -1);  { TY_IDX_CHAR    = 2 }
  AddPrim('void',      TYK_VOID,    0, False, -1);  { TY_IDX_VOID    = 3 }
  AddPrim('String',    TYK_STRING,  4, False, -1);  { TY_IDX_STRING  = 4 }
  AddPrim('null',      TYK_NULL,    4, False, -1);  { TY_IDX_NULL    = 5 }
  AddPrim('int[]',     TYK_ARRAY,   4, True,  TY_IDX_INT);     { TY_IDX_INTARR  = 6 }
  AddPrim('char[]',    TYK_ARRAY,   4, True,  TY_IDX_CHAR);    { TY_IDX_CHARARR = 7 }
  AddPrim('String[]',  TYK_ARRAY,   4, True,  TY_IDX_STRING);  { TY_IDX_STRARR  = 8 }
  AddPrim('boolean[]', TYK_ARRAY,   4, True,  TY_IDX_BOOLEAN); { TY_IDX_BOOLARR = 9 }
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
    TYK_INT     : TypeKindStr := 'TYK_INT';
    TYK_BOOLEAN : TypeKindStr := 'TYK_BOOLEAN';
    TYK_CHAR    : TypeKindStr := 'TYK_CHAR';
    TYK_VOID    : TypeKindStr := 'TYK_VOID';
    TYK_STRING  : TypeKindStr := 'TYK_STRING';
    TYK_ARRAY   : TypeKindStr := 'TYK_ARRAY';
    TYK_OBJECT  : TypeKindStr := 'TYK_OBJECT';
    TYK_CLASS   : TypeKindStr := 'TYK_CLASS';
    TYK_NULL    : TypeKindStr := 'TYK_NULL';
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
    TypeKindOf := TYK_VOID;
End;

{ ------------------------------------------------------------ }
{ TypeSizeOf : retourner la taille en octets pour un indice     }
{ INT=4, BOOLEAN=4, CHAR=4, STRING=4(ptr), ARRAY=4(ptr),       }
{ OBJECT=4(ptr), VOID=0                                        }
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

Function TypeAdd(Const Name : TString; Kind, Size : Integer;
                 IsArr : Boolean; ElemTyp : Integer) : Integer;
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
  TypeTab[Idx].Name     := Name;
  TypeTab[Idx].Kind     := Kind;
  TypeTab[Idx].Size     := Size;
  TypeTab[Idx].IsArray  := IsArr;
  TypeTab[Idx].ElemType := ElemTyp;
  Inc(TypeCount);
  Inc(TypAddCount);
  TypLastName := Name;
  TypeAdd := Idx;
End;

{ ------------------------------------------------------------ }
{ TypeIsAssignable : verifier la compatibilite d affectation    }
{ destIdx := srcIdx  (verification statique a la compilation)   }
{ Retourne True si le type source est compatible avec le dest   }
{ ------------------------------------------------------------ }

Function TypeIsAssignable(DestIdx, SrcIdx : Integer) : Boolean;
Var
  DK, SK : Integer;
Begin
  { Meme type -> toujours OK }
  If DestIdx = SrcIdx Then
  Begin
    TypeIsAssignable := True;
    Exit;
  End;
  DK := TypeKindOf(DestIdx);
  SK := TypeKindOf(SrcIdx);
  { null assignable a tout type reference (String, Array, Object) }
  If SK = TYK_NULL Then
  Begin
    TypeIsAssignable := (DK = TYK_STRING) Or (DK = TYK_ARRAY) Or
                        (DK = TYK_OBJECT) Or (DK = TYK_CLASS);
    Exit;
  End;
  { int <-> char compatibles (elargi a 32 bits) }
  If ((DK = TYK_INT) And (SK = TYK_CHAR)) Or
     ((DK = TYK_CHAR) And (SK = TYK_INT)) Then
  Begin
    TypeIsAssignable := True;
    Exit;
  End;
  { Object <- tout type reference }
  If (DK = TYK_OBJECT) And
     ((SK = TYK_STRING) Or (SK = TYK_ARRAY) Or (SK = TYK_OBJECT)) Then
  Begin
    TypeIsAssignable := True;
    Exit;
  End;
  TypeIsAssignable := False;
End;

{ ------------------------------------------------------------ }
{ TypeIsInstanceOf : verification dynamique instanceof          }
{ Retourne True si le type de l objet est compatible            }
{ (pour generer EAX=0|1 a l execution)                         }
{ ------------------------------------------------------------ }

Function TypeIsInstanceOf(ObjIdx, TestIdx : Integer) : Boolean;
Var
  OK, TK : Integer;
Begin
  OK := TypeKindOf(ObjIdx);
  TK := TypeKindOf(TestIdx);
  { null instanceof X -> toujours false }
  If OK = TYK_NULL Then
  Begin
    TypeIsInstanceOf := False;
    Exit;
  End;
  { Meme type -> true }
  If ObjIdx = TestIdx Then
  Begin
    TypeIsInstanceOf := True;
    Exit;
  End;
  { tout objet instanceof Object -> true }
  If (TK = TYK_OBJECT) And
     ((OK = TYK_STRING) Or (OK = TYK_ARRAY) Or (OK = TYK_OBJECT)) Then
  Begin
    TypeIsInstanceOf := True;
    Exit;
  End;
  { String instanceof String -> true (deja couvert par egalite) }
  TypeIsInstanceOf := False;
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
  Begin
    WriteLn('  [', I, '] ', TypeTab[I].Name,
            '  kind=', TypeKindStr(TypeTab[I].Kind),
            '  size=', TypeTab[I].Size);
    If TypeTab[I].IsArray Then
      WriteLn('       array elem=', TypeTab[I].ElemType);
  End;
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
{ TODO 06 - LITTERAUX ET CONSTANTES            [IMPLEMENTE]    }
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
    LblName   : TString;  { label ASM (_JK_n, etc.)              }
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
  LblSeq         : Integer;      { sequence pour LabelGen (_JL_)       }

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
  GenLitLabel := JV_STR_PFX + ItoS(LitLabelSeq);
End;

{ ------------------------------------------------------------ }
{ LabelGen : generateur de labels de saut uniques _JL_N         }
{ ------------------------------------------------------------ }

Function LabelGen : TString;
Begin
  Inc(LblSeq);
  LabelGen := JV_LBL_PFX + ItoS(LblSeq);
End;

{ ------------------------------------------------------------ }
{ ExprKindStr : nom textuel d un EK_                             }
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

{ ------------------------------------------------------------ }
{ DataKindStr : nom textuel d un DK_                             }
{ ------------------------------------------------------------ }

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
{ ExprMakeNull : creer une expression null -> IMM 0, type NULL   }
{ ------------------------------------------------------------ }

Function ExprMakeNull : TExprVal;
Begin
  ExprMakeNull := ExprMakeImm(0, TY_IDX_NULL);
End;

{ ------------------------------------------------------------ }
{ ExprMakeBool : creer une expression true(1) ou false(0)        }
{ ------------------------------------------------------------ }

Function ExprMakeBool(B : Boolean) : TExprVal;
Begin
  If B Then
    ExprMakeBool := ExprMakeImm(1, TY_IDX_BOOLEAN)
  Else
    ExprMakeBool := ExprMakeImm(0, TY_IDX_BOOLEAN);
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
{ vers le label DATA, de type EK_MEM / TY_IDX_STRING             }
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
  E.TypeIdx := TY_IDX_STRING;
  E.Offset  := DataCount - 1;   { indice dans DataTab }
  E.SymIdx  := -1;
  LitEvalStr := E;
End;

{ ------------------------------------------------------------ }
{ LitEvalChar : evaluer un token caractere comme expression      }
{ Retourne un TExprVal de type EK_IMM / TY_IDX_CHAR             }
{ ------------------------------------------------------------ }

Function LitEvalChar : TExprVal;
Begin
  LitEvalChar := ExprMakeImm(CurTokInt, TY_IDX_CHAR);
End;

{ ------------------------------------------------------------ }
{ LitEval : evaluer le token courant comme litteral              }
{ Gere : entier, flottant (tronque), chaine, caractere,          }
{        null, true, false                                       }
{ Retourne un TExprVal                                           }
{ ------------------------------------------------------------ }

Function LitEval : TExprVal;
Var E : TExprVal;
Begin
  Inc(LitEvalCount);
  Case CurTokKind Of
    TK_INTEGER : E := LitEvalInt;
    TK_FLOAT   : E := LitEvalInt;   { flottant tronque en entier }
    TK_STRING  : E := LitEvalStr;
    TK_CHAR    : E := LitEvalChar;
    TK_IDENT   :
      Begin
        If CurTokStr = 'null' Then
          E := ExprMakeNull
        Else If CurTokStr = 'true' Then
          E := ExprMakeBool(True)
        Else If CurTokStr = 'false' Then
          E := ExprMakeBool(False)
        Else
        Begin
          E.Kind    := EK_NONE;
          E.ImmVal  := 0;
          E.TypeIdx := TY_IDX_VOID;
          E.Offset  := 0;
          E.SymIdx  := -1;
        End;
      End;
  Else
    Begin
      E.Kind    := EK_NONE;
      E.ImmVal  := 0;
      E.TypeIdx := TY_IDX_VOID;
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
{ TODO 07 - OPERATEURS ET PRECEDENCE            [IMPLEMENTE]   }
{ ============================================================ }

Const
  { Operateurs binaires }
  OP_NONE        = 0;
  OP_ADD         = 1;    { +                                     }
  OP_SUB         = 2;    { -                                     }
  OP_MUL         = 3;    { *                                     }
  OP_DIV         = 4;    { / (division entiere pour int)         }
  OP_MOD         = 5;    { %                                     }
  OP_SHL         = 6;    { <<                                    }
  OP_SHR         = 7;    { >> (decalage droite signe)            }
  OP_USHR        = 8;    { >>> (decalage droite non-signe)       }
  OP_BAND        = 9;    { &                                     }
  OP_BOR         = 10;   { |                                     }
  OP_BXOR        = 11;   { ^                                     }
  OP_EQ          = 12;   { ==                                    }
  OP_NE          = 13;   { !=                                    }
  OP_LT          = 14;   { <                                     }
  OP_LE          = 15;   { <=                                    }
  OP_GT          = 16;   { >                                     }
  OP_GE          = 17;   { >=                                    }
  OP_AND         = 18;   { && (court-circuit logique)            }
  OP_OR          = 19;   { || (court-circuit logique)            }
  OP_INSTANCEOF  = 20;   { instanceof                            }
  OP_MAX         = 20;

  { Operateurs unaires }
  UOP_NONE       = 0;
  UOP_NEG        = 1;    { - (negation)                          }
  UOP_POS        = 2;    { + (identite)                          }
  UOP_BNOT       = 3;    { ~ (complement bit a bit)              }
  UOP_NOT        = 4;    { ! (negation logique)                  }
  UOP_PREINC     = 5;    { ++x (pre-increment)                   }
  UOP_PREDEC     = 6;    { --x (pre-decrement)                   }
  UOP_POSTINC    = 7;    { x++ (post-increment)                  }
  UOP_POSTDEC    = 8;    { x-- (post-decrement)                  }
  UOP_MAX        = 8;

  { Operateurs d affectation }
  AOP_ASSIGN       = 0;   { =                                    }
  AOP_ADD_ASSIGN   = 1;   { +=                                   }
  AOP_SUB_ASSIGN   = 2;   { -=                                   }
  AOP_MUL_ASSIGN   = 3;   { *=                                   }
  AOP_DIV_ASSIGN   = 4;   { /=                                   }
  AOP_MOD_ASSIGN   = 5;   { %=                                   }
  AOP_BAND_ASSIGN  = 6;   { &=                                   }
  AOP_BOR_ASSIGN   = 7;   { |=                                   }
  AOP_BXOR_ASSIGN  = 8;   { ^=                                   }
  AOP_SHL_ASSIGN   = 9;   { <<=                                  }
  AOP_SHR_ASSIGN   = 10;  { >>=                                  }
  AOP_USHR_ASSIGN  = 11;  { >>>=                                 }
  AOP_MAX          = 11;

  { Niveaux de precedence (du plus fort au plus faible) }
  { Java :                                                       }
  {  1 = postfixe ++ -- . [] ()                                  }
  {  2 = prefixe ++ -- + - ~ !                                   }
  {  3 = * / %                                                   }
  {  4 = + - (binaire, concat String)                            }
  {  5 = << >> >>>                                               }
  {  6 = < <= > >= instanceof                                    }
  {  7 = == !=                                                   }
  {  8 = &                                                       }
  {  9 = ^                                                       }
  { 10 = |                                                       }
  { 11 = &&                                                      }
  { 12 = ||                                                      }
  { 13 = ? : (ternaire)                                          }
  { 14 = = += -= *= /= %= &= |= ^= <<= >>= >>>=                }
  PREC_MULDIV    = 3;    { * / %                                 }
  PREC_ADDSUB    = 4;    { + - (binaires)                        }
  PREC_SHIFT     = 5;    { << >> >>>                             }
  PREC_RELAT     = 6;    { < <= > >= instanceof                  }
  PREC_EQUAL     = 7;    { == !=                                 }
  PREC_BAND      = 8;    { &                                     }
  PREC_BXOR      = 9;    { ^                                     }
  PREC_BOR       = 10;   { |                                     }
  PREC_AND       = 11;   { &&                                    }
  PREC_OR        = 12;   { ||                                    }
  PREC_MAX       = 12;

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
    OP_NONE       : OpName := 'NONE';
    OP_ADD        : OpName := '+';
    OP_SUB        : OpName := '-';
    OP_MUL        : OpName := '*';
    OP_DIV        : OpName := '/';
    OP_MOD        : OpName := '%';
    OP_SHL        : OpName := '<<';
    OP_SHR        : OpName := '>>';
    OP_USHR       : OpName := '>>>';
    OP_BAND       : OpName := '&';
    OP_BOR        : OpName := '|';
    OP_BXOR       : OpName := '^';
    OP_EQ         : OpName := '==';
    OP_NE         : OpName := '!=';
    OP_LT         : OpName := '<';
    OP_LE         : OpName := '<=';
    OP_GT         : OpName := '>';
    OP_GE         : OpName := '>=';
    OP_AND        : OpName := '&&';
    OP_OR         : OpName := '||';
    OP_INSTANCEOF : OpName := 'instanceof';
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
    UOP_NONE    : UnaryOpName := 'NONE';
    UOP_NEG     : UnaryOpName := '-';
    UOP_POS     : UnaryOpName := '+';
    UOP_BNOT    : UnaryOpName := '~';
    UOP_NOT     : UnaryOpName := '!';
    UOP_PREINC  : UnaryOpName := '++x';
    UOP_PREDEC  : UnaryOpName := '--x';
    UOP_POSTINC : UnaryOpName := 'x++';
    UOP_POSTDEC : UnaryOpName := 'x--';
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
    AOP_DIV_ASSIGN  : AssignOpName := '/=';
    AOP_MOD_ASSIGN  : AssignOpName := '%=';
    AOP_BAND_ASSIGN : AssignOpName := '&=';
    AOP_BOR_ASSIGN  : AssignOpName := '|=';
    AOP_BXOR_ASSIGN : AssignOpName := '^=';
    AOP_SHL_ASSIGN  : AssignOpName := '<<=';
    AOP_SHR_ASSIGN  : AssignOpName := '>>=';
    AOP_USHR_ASSIGN : AssignOpName := '>>>=';
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
    OP_MUL, OP_DIV,
    OP_MOD              : BinOpPrec := PREC_MULDIV;
    OP_ADD, OP_SUB      : BinOpPrec := PREC_ADDSUB;
    OP_SHL, OP_SHR,
    OP_USHR             : BinOpPrec := PREC_SHIFT;
    OP_LT, OP_LE,
    OP_GT, OP_GE,
    OP_INSTANCEOF       : BinOpPrec := PREC_RELAT;
    OP_EQ, OP_NE        : BinOpPrec := PREC_EQUAL;
    OP_BAND             : BinOpPrec := PREC_BAND;
    OP_BXOR             : BinOpPrec := PREC_BXOR;
    OP_BOR              : BinOpPrec := PREC_BOR;
    OP_AND              : BinOpPrec := PREC_AND;
    OP_OR               : BinOpPrec := PREC_OR;
  Else
    BinOpPrec := 0;
  End;
End;

{ ------------------------------------------------------------ }
{ BinOpIsRight : True si l operateur est associatif a droite     }
{ En Java, les operateurs binaires sont tous associatifs a       }
{ gauche (seule l affectation est a droite, geree separement)    }
{ ------------------------------------------------------------ }

Function BinOpIsRight(Op : Integer) : Boolean;
Begin
  BinOpIsRight := False;
  If Op = OP_NONE Then ; { eviter warning unused }
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
  Else If S = '/='   Then IsAssignOp := AOP_DIV_ASSIGN
  Else If S = '%='   Then IsAssignOp := AOP_MOD_ASSIGN
  Else If S = '&='   Then IsAssignOp := AOP_BAND_ASSIGN
  Else If S = '|='   Then IsAssignOp := AOP_BOR_ASSIGN
  Else If S = '^='   Then IsAssignOp := AOP_BXOR_ASSIGN
  Else If S = '<<='  Then IsAssignOp := AOP_SHL_ASSIGN
  Else If S = '>>='  Then IsAssignOp := AOP_SHR_ASSIGN
  Else If S = '>>>=' Then IsAssignOp := AOP_USHR_ASSIGN
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
    AOP_DIV_ASSIGN  : AssignOpToBinOp := OP_DIV;
    AOP_MOD_ASSIGN  : AssignOpToBinOp := OP_MOD;
    AOP_BAND_ASSIGN : AssignOpToBinOp := OP_BAND;
    AOP_BOR_ASSIGN  : AssignOpToBinOp := OP_BOR;
    AOP_BXOR_ASSIGN : AssignOpToBinOp := OP_BXOR;
    AOP_SHL_ASSIGN  : AssignOpToBinOp := OP_SHL;
    AOP_SHR_ASSIGN  : AssignOpToBinOp := OP_SHR;
    AOP_USHR_ASSIGN : AssignOpToBinOp := OP_USHR;
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
  Else If S = '/'  Then TokenToBinOp := OP_DIV
  Else If S = '%'  Then TokenToBinOp := OP_MOD
  Else If S = '<<' Then TokenToBinOp := OP_SHL
  Else If S = '>>' Then TokenToBinOp := OP_SHR
  Else If S = '>>>'Then TokenToBinOp := OP_USHR
  Else If S = '&'  Then TokenToBinOp := OP_BAND
  Else If S = '|'  Then TokenToBinOp := OP_BOR
  Else If S = '^'  Then TokenToBinOp := OP_BXOR
  Else If S = '==' Then TokenToBinOp := OP_EQ
  Else If S = '!=' Then TokenToBinOp := OP_NE
  Else If S = '<'  Then TokenToBinOp := OP_LT
  Else If S = '<=' Then TokenToBinOp := OP_LE
  Else If S = '>'  Then TokenToBinOp := OP_GT
  Else If S = '>=' Then TokenToBinOp := OP_GE
  Else If S = '&&' Then TokenToBinOp := OP_AND
  Else If S = '||' Then TokenToBinOp := OP_OR
  Else TokenToBinOp := OP_NONE;
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
                        Var OVal : TExprVal) : Boolean;
Var V : LongInt;
Begin
  ConstFoldBinOp := False;
  If (L.Kind <> EK_IMM) Or (R.Kind <> EK_IMM) Then Exit;
  Case Op Of
    OP_ADD  : V := L.ImmVal + R.ImmVal;
    OP_SUB  : V := L.ImmVal - R.ImmVal;
    OP_MUL  : V := L.ImmVal * R.ImmVal;
    OP_DIV  :
      Begin
        If R.ImmVal = 0 Then Exit;   { pas de pliage si div/0 }
        V := L.ImmVal Div R.ImmVal;
      End;
    OP_MOD  :
      Begin
        If R.ImmVal = 0 Then Exit;
        V := L.ImmVal Mod R.ImmVal;
      End;
    OP_SHL  : V := L.ImmVal Shl (R.ImmVal And 31);
    OP_SHR  : V := L.ImmVal Shr (R.ImmVal And 31);
    OP_USHR : V := L.ImmVal Shr (R.ImmVal And 31);
    OP_BAND : V := L.ImmVal And R.ImmVal;
    OP_BOR  : V := L.ImmVal Or R.ImmVal;
    OP_BXOR : V := L.ImmVal Xor R.ImmVal;
    OP_EQ   : Begin If L.ImmVal =  R.ImmVal Then V := 1 Else V := 0; End;
    OP_NE   : Begin If L.ImmVal <> R.ImmVal Then V := 1 Else V := 0; End;
    OP_LT   : Begin If L.ImmVal <  R.ImmVal Then V := 1 Else V := 0; End;
    OP_LE   : Begin If L.ImmVal <= R.ImmVal Then V := 1 Else V := 0; End;
    OP_GT   : Begin If L.ImmVal >  R.ImmVal Then V := 1 Else V := 0; End;
    OP_GE   : Begin If L.ImmVal >= R.ImmVal Then V := 1 Else V := 0; End;
    OP_AND  : Begin If (L.ImmVal <> 0) And (R.ImmVal <> 0)
                Then V := 1 Else V := 0; End;
    OP_OR   : Begin If (L.ImmVal <> 0) Or (R.ImmVal <> 0)
                Then V := 1 Else V := 0; End;
  Else
    Exit;  { instanceof : pas de pliage }
  End;
  OVal := ExprMakeImm(V, L.TypeIdx);
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
      UOP_NEG  : Begin V := -E.ImmVal; Inc(OprFoldCount);
                   ExprEmitUnaryOp := ExprMakeImm(V, E.TypeIdx); Exit; End;
      UOP_POS  : Begin ExprEmitUnaryOp := E; Inc(OprFoldCount); Exit; End;
      UOP_BNOT : Begin V := Not E.ImmVal; Inc(OprFoldCount);
                   ExprEmitUnaryOp := ExprMakeImm(V, E.TypeIdx); Exit; End;
      UOP_NOT  : Begin If E.ImmVal = 0 Then V := 1 Else V := 0;
                   Inc(OprFoldCount);
                   ExprEmitUnaryOp := ExprMakeImm(V, TY_IDX_BOOLEAN);
                   Exit; End;
    End;
  End;

  { Sinon, generation de code -> resultat dans EAX }
  ExprEmitUnaryOp := ExprMakeEAX(E.TypeIdx);
End;

{ ------------------------------------------------------------ }
{ ParsePrimary : parser une expression primaire Java             }
{ Gere : entier, flottant, chaine, char, null, true, false,     }
{        identificateur, parentheses                             }
{ ------------------------------------------------------------ }

Function ParseExprPrec(MinPrec : Integer) : TExprVal; Forward;

Function ParsePrimary : TExprVal;
Var E : TExprVal;
Begin
  Case CurTokKind Of
    TK_INTEGER :
      Begin
        E := LitEvalInt;
        ParserAdvance;
      End;
    TK_FLOAT :
      Begin
        { Flottant tronque en entier }
        E := LitEvalInt;
        ParserAdvance;
      End;
    TK_STRING :
      Begin
        E := LitEvalStr;
        ParserAdvance;
      End;
    TK_CHAR :
      Begin
        E := LitEvalChar;
        ParserAdvance;
      End;
    TK_IDENT :
      Begin
        { Variable ou appel de methode (stub) }
        E.Kind    := EK_MEM;
        E.ImmVal  := 0;
        E.TypeIdx := TY_IDX_INT;
        E.Offset  := 0;
        E.SymIdx  := SymFind(CurTokStr);
        ParserAdvance;
      End;
    TK_KEYWORD :
      Begin
        If CurTokStr = 'null' Then
        Begin
          E := ExprMakeNull;
          ParserAdvance;
        End
        Else If CurTokStr = 'true' Then
        Begin
          E := ExprMakeBool(True);
          ParserAdvance;
        End
        Else If CurTokStr = 'false' Then
        Begin
          E := ExprMakeBool(False);
          ParserAdvance;
        End
        Else If CurTokStr = 'new' Then
        Begin
          { new ClassName(args) ou new int[n] - stub }
          E.Kind    := EK_EAX;
          E.ImmVal  := 0;
          E.TypeIdx := TY_IDX_INT;
          E.Offset  := 0;
          E.SymIdx  := -1;
          ParserAdvance;
          { Consommer le nom de type/classe }
          If (CurTokKind = TK_IDENT) Or (CurTokKind = TK_KEYWORD) Then
            ParserAdvance;
        End
        Else
        Begin
          E.Kind    := EK_NONE;
          E.ImmVal  := 0;
          E.TypeIdx := TY_IDX_VOID;
          E.Offset  := 0;
          E.SymIdx  := -1;
          CompileError('unexpected keyword: ' + CurTokStr, LexLineNo);
          ParserAdvance;
        End;
      End;
    TK_PUNCT :
      Begin
        If CurTokStr = '(' Then
        Begin
          ParserAdvance;
          E := ParseExprPrec(PREC_MAX + 1);
          { Attendre la parenthese fermante }
          If (CurTokKind = TK_PUNCT) And (CurTokStr = ')') Then
            ParserAdvance
          Else
            CompileError('expected )', LexLineNo);
        End
        Else
        Begin
          E.Kind    := EK_NONE;
          E.ImmVal  := 0;
          E.TypeIdx := TY_IDX_VOID;
          E.Offset  := 0;
          E.SymIdx  := -1;
          CompileError('unexpected token: ' + CurTokStr, LexLineNo);
          ParserAdvance;
        End;
      End;
    TK_OP :
      Begin
        { Gerer les unaires prefixes + - ~ ! ++ -- }
        If (CurTokStr = '-') Or (CurTokStr = '+') Or
           (CurTokStr = '~') Or (CurTokStr = '!') Or
           (CurTokStr = '++') Or (CurTokStr = '--') Then
        Begin
          { Sera gere par ParseUnary, on retourne NONE }
          E.Kind    := EK_NONE;
          E.ImmVal  := 0;
          E.TypeIdx := TY_IDX_INT;
          E.Offset  := 0;
          E.SymIdx  := -1;
        End
        Else
        Begin
          E.Kind    := EK_NONE;
          E.ImmVal  := 0;
          E.TypeIdx := TY_IDX_VOID;
          E.Offset  := 0;
          E.SymIdx  := -1;
          CompileError('unexpected operator: ' + CurTokStr, LexLineNo);
          ParserAdvance;
        End;
      End;
  Else
    Begin
      E.Kind    := EK_NONE;
      E.ImmVal  := 0;
      E.TypeIdx := TY_IDX_VOID;
      E.Offset  := 0;
      E.SymIdx  := -1;
      If CurTokKind <> TK_EOF Then
      Begin
        CompileError('expected expression, got: ' + CurTokStr, LexLineNo);
        ParserAdvance;
      End;
    End;
  End;
  ParsePrimary := E;
End;

{ ------------------------------------------------------------ }
{ ParseUnary : parser un operateur unaire (+ - ~ ! ++ --)       }
{ ------------------------------------------------------------ }

Function ParseUnary : TExprVal;
Var UOp : Integer;
    E   : TExprVal;
Begin
  UOp := UOP_NONE;
  If CurTokKind = TK_OP Then
  Begin
    If CurTokStr = '-'  Then UOp := UOP_NEG
    Else If CurTokStr = '+'  Then UOp := UOP_POS
    Else If CurTokStr = '~'  Then UOp := UOP_BNOT
    Else If CurTokStr = '!'  Then UOp := UOP_NOT
    Else If CurTokStr = '++' Then UOp := UOP_PREINC
    Else If CurTokStr = '--' Then UOp := UOP_PREDEC;
  End;

  If UOp <> UOP_NONE Then
  Begin
    ParserAdvance;
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
    Else If (CurTokKind = TK_KEYWORD) And (CurTokStr = 'instanceof') Then
      Op := OP_INSTANCEOF;

    If Op = OP_NONE Then Break;

    Prec := BinOpPrec(Op);
    If Prec = 0 Then Break;
    If Prec > MinPrec Then Break;   { precedence plus faible = arreter }

    { Consommer l operateur }
    ParserAdvance;

    { Associativite : tous les operateurs binaires Java sont a gauche }
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
{ ParseExpr : point d entree pour parser une expression Java     }
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
{ TODO 08 - EXPRESSIONS PRIMAIRES ET APPELS   [IMPLEMENTE]     }
{ ============================================================ }

Const
  { Types d expressions primaires PX_* }
  PX_NONE        = 0;    { aucun                                   }
  PX_INT_LIT     = 1;    { litteral entier                         }
  PX_FLOAT_LIT   = 2;    { litteral flottant                       }
  PX_STR_LIT     = 3;    { litteral chaine                         }
  PX_CHAR_LIT    = 4;    { litteral caractere                      }
  PX_IDENT       = 5;    { identificateur                          }
  PX_STATIC_CALL = 6;    { appel de methode statique               }
  PX_INST_CALL   = 7;    { appel de methode d instance             }
  PX_FIELD       = 8;    { acces champ                             }
  PX_INDEX       = 9;    { acces index tableau                     }
  PX_NEW_OBJ     = 10;   { new ClassName(args)                     }
  PX_NEW_ARR     = 11;   { new int[n]                              }
  PX_CAST        = 12;   { cast explicite (int)expr                }
  PX_TERNARY     = 13;   { operateur ternaire cond ? a : b         }
  PX_PAREN       = 14;   { expression parenthesee                  }
  PX_SYSOUT      = 15;   { System.out.println / print              }
  PX_SCANNER     = 16;   { Scanner.nextLine / nextInt              }
  PX_MAX         = 16;

  { Limites }
  PX_MAX_ARGS    = 16;   { nombre max d arguments par appel        }
  PX_MAX_ELEMS   = 64;   { nombre max d elements dans un tableau   }

Var
  PxInitialized  : Boolean;    { True si l etat est initialise       }
  PxCallCount    : LongInt;    { nombre total d appels de methodes   }
  PxStaticCount  : LongInt;    { nombre d appels statiques           }
  PxInstCount    : LongInt;    { nombre d appels d instance          }
  PxFieldCount   : LongInt;    { nombre d acces champ                }
  PxIndexCount   : LongInt;    { nombre d acces index tableau        }
  PxNewCount     : LongInt;    { nombre d allocations new            }
  PxCastCount    : LongInt;    { nombre de casts explicites          }
  PxTernaryCount : LongInt;    { nombre d operateurs ternaires       }
  PxSysOutCount  : LongInt;    { nombre d appels System.out          }
  PxScannerCount : LongInt;    { nombre d appels Scanner             }
  PxLastKind     : Integer;    { dernier type d expression primaire  }
  PxLabelSeq     : Integer;    { sequence pour labels PX              }

{ ------------------------------------------------------------ }
{ InitPxState : initialiser le sous-systeme des primaires        }
{ ------------------------------------------------------------ }

Procedure InitPxState;
Begin
  PxInitialized  := True;
  PxCallCount    := 0;
  PxStaticCount  := 0;
  PxInstCount    := 0;
  PxFieldCount   := 0;
  PxIndexCount   := 0;
  PxNewCount     := 0;
  PxCastCount    := 0;
  PxTernaryCount := 0;
  PxSysOutCount  := 0;
  PxScannerCount := 0;
  PxLastKind     := PX_NONE;
  PxLabelSeq     := 0;
End;

{ ------------------------------------------------------------ }
{ GenPxLabel : generer un label unique pour les primaires         }
{ ------------------------------------------------------------ }

Function GenPxLabel : TString;
Begin
  Inc(PxLabelSeq);
  GenPxLabel := '_JPX_' + ItoS(PxLabelSeq);
End;

{ ------------------------------------------------------------ }
{ PxTypeName : retourner le nom du type de primaire              }
{ ------------------------------------------------------------ }

Function PxTypeName(K : Integer) : TString;
Begin
  Case K Of
    PX_NONE        : PxTypeName := 'NONE';
    PX_INT_LIT     : PxTypeName := 'INT_LIT';
    PX_FLOAT_LIT   : PxTypeName := 'FLOAT_LIT';
    PX_STR_LIT     : PxTypeName := 'STR_LIT';
    PX_CHAR_LIT    : PxTypeName := 'CHAR_LIT';
    PX_IDENT       : PxTypeName := 'IDENT';
    PX_STATIC_CALL : PxTypeName := 'STATIC_CALL';
    PX_INST_CALL   : PxTypeName := 'INST_CALL';
    PX_FIELD       : PxTypeName := 'FIELD';
    PX_INDEX       : PxTypeName := 'INDEX';
    PX_NEW_OBJ     : PxTypeName := 'NEW_OBJ';
    PX_NEW_ARR     : PxTypeName := 'NEW_ARR';
    PX_CAST        : PxTypeName := 'CAST';
    PX_TERNARY     : PxTypeName := 'TERNARY';
    PX_PAREN       : PxTypeName := 'PAREN';
    PX_SYSOUT      : PxTypeName := 'SYSOUT';
    PX_SCANNER     : PxTypeName := 'SCANNER';
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
  If CurTokKind = TK_RPAREN Then
  Begin
    ParseArgList := 0;
    Exit;
  End;

  { Premier argument }
  E := ParseExpr;
  Inc(Count);

  { Arguments suivants }
  While CurTokKind = TK_COMMA Do
  Begin
    ParserAdvance; { consommer , }
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
{ ParseStaticMethodCall : parser ClassName.method(args)           }
{   PUSH args droite a gauche, CALL _JF_ClassName_method,        }
{   ADD ESP, args_size                                           }
{ ------------------------------------------------------------ }

Function ParseStaticMethodCall(ClassName, MethodName : TString) : TExprVal;
Var
  R     : TExprVal;
  NArgs : Integer;
Begin
  Inc(PxCallCount);
  Inc(PxStaticCount);
  PxLastKind := PX_STATIC_CALL;

  ParserAdvance; { consommer ( }
  NArgs := ParseArgList;

  { Attendre ) }
  If CurTokKind = TK_RPAREN Then
    ParserAdvance
  Else
    CompileError('expected ) after method arguments', LexLineNo);

  { Resultat dans EAX apres le CALL }
  R := ExprMakeEAX(TY_IDX_INT);
  ParseStaticMethodCall := R;
End;

{ ------------------------------------------------------------ }
{ ParseInstanceMethodCall : parser obj.method(args)              }
{   PUSH this, PUSH args, CALL _JM_ClassName_method,             }
{   ADD ESP, (1+args)*4                                         }
{ ------------------------------------------------------------ }

Function ParseInstanceMethodCall(ObjExpr : TExprVal;
                                 MethodName : TString) : TExprVal;
Var
  R     : TExprVal;
  NArgs : Integer;
Begin
  Inc(PxCallCount);
  Inc(PxInstCount);
  PxLastKind := PX_INST_CALL;

  ParserAdvance; { consommer ( }
  NArgs := ParseArgList;

  { Attendre ) }
  If CurTokKind = TK_RPAREN Then
    ParserAdvance
  Else
    CompileError('expected ) after method arguments', LexLineNo);

  { Resultat dans EAX apres le CALL }
  R := ExprMakeEAX(TY_IDX_INT);
  ParseInstanceMethodCall := R;
End;

{ ------------------------------------------------------------ }
{ ParseFieldAccess : parser expr.field                           }
{   Offset dans instance de classe                               }
{ ------------------------------------------------------------ }

Function ParseFieldAccess(ObjExpr : TExprVal) : TExprVal;
Var
  FieldName : TString;
  R         : TExprVal;
Begin
  Inc(PxFieldCount);
  PxLastKind := PX_FIELD;

  { Le . a deja ete consomme, on attend un identifiant }
  If CurTokKind <> TK_IDENT Then
  Begin
    CompileError('expected field name after .', LexLineNo);
    ParseFieldAccess := ExprMakeNull;
    Exit;
  End;

  FieldName := CurTokStr;
  ParserAdvance;

  { Si suivi de (, c est un appel de methode d instance }
  If CurTokKind = TK_LPAREN Then
  Begin
    ParseFieldAccess := ParseInstanceMethodCall(ObjExpr, FieldName);
    Exit;
  End;

  { Sinon, acces champ simple : resultat dans EAX }
  R := ExprMakeEAX(ObjExpr.TypeIdx);
  ParseFieldAccess := R;
End;

{ ------------------------------------------------------------ }
{ ParseIndexAccess : parser expr[i]                              }
{   Calcul offset + MOV EAX, [EBX+4+i*4]                        }
{   Le [ a deja ete consomme par l appelant.                     }
{ ------------------------------------------------------------ }

Function ParseIndexAccess(ObjExpr : TExprVal) : TExprVal;
Var
  R : TExprVal;
  E : TExprVal;
Begin
  Inc(PxIndexCount);
  PxLastKind := PX_INDEX;

  { Parser l expression d index }
  E := ParseExpr;

  { Attendre ] }
  If CurTokKind = TK_RBRACKET Then
    ParserAdvance
  Else
    CompileError('expected ]', LexLineNo);

  { Resultat : element du tableau, dans EAX }
  R := ExprMakeEAX(TY_IDX_INT);
  { Si le tableau est int[], le resultat est int }
  If ObjExpr.TypeIdx = TY_IDX_INTARR Then
    R.TypeIdx := TY_IDX_INT
  Else If ObjExpr.TypeIdx = TY_IDX_CHARARR Then
    R.TypeIdx := TY_IDX_CHAR
  Else If ObjExpr.TypeIdx = TY_IDX_STRARR Then
    R.TypeIdx := TY_IDX_STRING
  Else If ObjExpr.TypeIdx = TY_IDX_BOOLARR Then
    R.TypeIdx := TY_IDX_BOOLEAN;

  ParseIndexAccess := R;
End;

{ ------------------------------------------------------------ }
{ ParseNewExpr : parser new ClassName(args) ou new int[n]        }
{   Le mot-cle 'new' a deja ete consomme.                       }
{ ------------------------------------------------------------ }

Function ParseNewExpr : TExprVal;
Var
  TypeName : TString;
  R        : TExprVal;
  NArgs    : Integer;
Begin
  Inc(PxNewCount);

  If (CurTokKind <> TK_IDENT) And (CurTokKind <> TK_KEYWORD) Then
  Begin
    CompileError('expected type name after new', LexLineNo);
    R := ExprMakeEAX(TY_IDX_INT);
    ParseNewExpr := R;
    Exit;
  End;

  TypeName := CurTokStr;
  ParserAdvance;

  { new int[n] : allocation tableau sur le heap }
  If CurTokKind = TK_LBRACKET Then
  Begin
    PxLastKind := PX_NEW_ARR;
    ParserAdvance; { consommer [ }
    R := ParseExpr; { taille du tableau }
    If CurTokKind = TK_RBRACKET Then
      ParserAdvance
    Else
      CompileError('expected ] after array size', LexLineNo);
    R := ExprMakeEAX(TY_IDX_INTARR);
    { Typer selon le type de base }
    If TypeName = 'char' Then R.TypeIdx := TY_IDX_CHARARR
    Else If TypeName = 'String' Then R.TypeIdx := TY_IDX_STRARR
    Else If TypeName = 'boolean' Then R.TypeIdx := TY_IDX_BOOLARR;
  End
  { new ClassName(args) : allocation instance + appel constructeur }
  Else If CurTokKind = TK_LPAREN Then
  Begin
    PxLastKind := PX_NEW_OBJ;
    ParserAdvance; { consommer ( }
    NArgs := ParseArgList;
    If CurTokKind = TK_RPAREN Then
      ParserAdvance
    Else
      CompileError('expected ) after constructor arguments', LexLineNo);
    R := ExprMakeEAX(TY_IDX_INT); { type sera affine plus tard }
  End
  Else
  Begin
    PxLastKind := PX_NEW_OBJ;
    R := ExprMakeEAX(TY_IDX_INT);
  End;

  ParseNewExpr := R;
End;

{ ------------------------------------------------------------ }
{ ParseCastExpr : parser (type)expr - cast explicite             }
{   Conversion ou troncature : (int)expr, (char)expr             }
{   Retourne TExprVal avec le type caste                        }
{ ------------------------------------------------------------ }

Function ParseCastExpr(TypeName : TString) : TExprVal;
Var
  R    : TExprVal;
  TIdx : Integer;
Begin
  Inc(PxCastCount);
  PxLastKind := PX_CAST;

  { Fermer la parenthese du cast }
  If CurTokKind = TK_RPAREN Then
    ParserAdvance
  Else
    CompileError('expected ) after cast type', LexLineNo);

  { Parser l expression a caster }
  R := ParseUnary;

  { Determiner le type cible }
  TIdx := TypeFindByName(TypeName);
  If TIdx >= 0 Then
    R.TypeIdx := TIdx
  Else
    R.TypeIdx := TY_IDX_INT;

  ParseCastExpr := R;
End;

{ ------------------------------------------------------------ }
{ ParseSysOutCall : parser System.out.println(expr) ou           }
{   System.out.print(expr)                                       }
{   Reconnaissance comme appel special d E/S                     }
{   Le 'System' a deja ete consomme, le . est courant.           }
{ ------------------------------------------------------------ }

Function ParseSysOutCall(IsPrintln : Boolean) : TExprVal;
Var
  R     : TExprVal;
  NArgs : Integer;
Begin
  Inc(PxSysOutCount);
  PxLastKind := PX_SYSOUT;

  { On attend ( }
  If CurTokKind = TK_LPAREN Then
  Begin
    ParserAdvance; { consommer ( }
    NArgs := ParseArgList;
    If CurTokKind = TK_RPAREN Then
      ParserAdvance
    Else
      CompileError('expected ) after println/print arguments', LexLineNo);
  End
  Else
    CompileError('expected ( after println/print', LexLineNo);

  R := ExprMakeEAX(TY_IDX_VOID);
  ParseSysOutCall := R;
End;

{ ------------------------------------------------------------ }
{ ParseScannerCall : parser Scanner.nextLine() / nextInt()       }
{   Reconnaissance comme appel special de saisie                 }
{   MethodName est 'nextLine' ou 'nextInt', etc.                 }
{ ------------------------------------------------------------ }

Function ParseScannerCall(MethodName : TString) : TExprVal;
Var
  R     : TExprVal;
  NArgs : Integer;
Begin
  Inc(PxScannerCount);
  PxLastKind := PX_SCANNER;

  { On attend ( }
  If CurTokKind = TK_LPAREN Then
  Begin
    ParserAdvance; { consommer ( }
    NArgs := ParseArgList;
    If CurTokKind = TK_RPAREN Then
      ParserAdvance
    Else
      CompileError('expected ) after Scanner method arguments', LexLineNo);
  End
  Else
    CompileError('expected ( after Scanner method', LexLineNo);

  { Type du retour selon la methode }
  If MethodName = 'nextInt' Then
    R := ExprMakeEAX(TY_IDX_INT)
  Else If MethodName = 'nextLine' Then
    R := ExprMakeEAX(TY_IDX_STRING)
  Else If MethodName = 'nextDouble' Then
    R := ExprMakeEAX(TY_IDX_INT) { flottant stocke comme entier }
  Else
    R := ExprMakeEAX(TY_IDX_STRING);

  ParseScannerCall := R;
End;

{ ------------------------------------------------------------ }
{ ParseTernaryOp : parser cond ? a : b                           }
{   Code conditionnel : TEST EAX,EAX / JZ label                 }
{   Cond est deja evaluee, on attend ? a : b                    }
{ ------------------------------------------------------------ }

Function ParseTernaryOp(Cond : TExprVal) : TExprVal;
Var
  A, B   : TExprVal;
  LblElse : TString;
  LblEnd  : TString;
Begin
  Inc(PxTernaryCount);
  PxLastKind := PX_TERNARY;

  LblElse := GenPxLabel;
  LblEnd  := GenPxLabel;

  ParserAdvance; { consommer ? }
  A := ParseExpr;

  { Attendre : }
  If CurTokKind = TK_COLON Then
    ParserAdvance
  Else
    CompileError('expected : in ternary expression', LexLineNo);

  B := ParseExpr;

  { Resultat dans EAX, type = type de la branche true }
  ParseTernaryOp := ExprMakeEAX(A.TypeIdx);
End;

{ ------------------------------------------------------------ }
{ ParsePostfix : parser les suffixes postfixes (., [, ()         }
{   Boucle pour chainer : obj.field[i].method(args)              }
{ ------------------------------------------------------------ }

Function ParsePostfix(E : TExprVal) : TExprVal;
Var R : TExprVal;
Begin
  R := E;
  While True Do
  Begin
    { Acces champ ou appel de methode : expr.name }
    If CurTokKind = TK_DOT Then
    Begin
      ParserAdvance; { consommer . }
      R := ParseFieldAccess(R);
    End
    { Acces index tableau : expr[i] }
    Else If CurTokKind = TK_LBRACKET Then
    Begin
      ParserAdvance; { consommer [ }
      R := ParseIndexAccess(R);
    End
    { Appel de fonction : expr(args) }
    Else If CurTokKind = TK_LPAREN Then
    Begin
      R := ParseInstanceMethodCall(R, '');
    End
    { Post-increment : x++ }
    Else If (CurTokKind = TK_OP) And (CurTokStr = '++') Then
    Begin
      R := ExprEmitUnaryOp(UOP_POSTINC, R);
      ParserAdvance;
    End
    { Post-decrement : x-- }
    Else If (CurTokKind = TK_OP) And (CurTokStr = '--') Then
    Begin
      R := ExprEmitUnaryOp(UOP_POSTDEC, R);
      ParserAdvance;
    End
    Else
      Break;
  End;
  ParsePostfix := R;
End;

{ ------------------------------------------------------------ }
{ ParsePrimaryFull : parser une expression primaire complete      }
{   avec les suffixes postfixes                                  }
{   Remplace ParsePrimary du TODO 07 pour les appels             }
{ ------------------------------------------------------------ }

Function ParsePrimaryFull : TExprVal;
Var
  E        : TExprVal;
  IdName   : TString;
  SymI     : Integer;
  SubName  : TString;
  TIdx     : Integer;
Begin
  Case CurTokKind Of
    TK_INTEGER :
      Begin
        PxLastKind := PX_INT_LIT;
        E := LitEvalInt;
        ParserAdvance;
      End;
    TK_FLOAT :
      Begin
        PxLastKind := PX_FLOAT_LIT;
        E := LitEvalInt; { tronque flottant en entier }
        ParserAdvance;
      End;
    TK_STRING :
      Begin
        PxLastKind := PX_STR_LIT;
        E := LitEvalStr;
        ParserAdvance;
      End;
    TK_CHAR :
      Begin
        PxLastKind := PX_CHAR_LIT;
        E := LitEvalChar;
        ParserAdvance;
      End;
    TK_IDENT :
      Begin
        IdName := CurTokStr;
        SymI   := SymFind(IdName);

        { System.out.println / System.out.print }
        If IdName = 'System' Then
        Begin
          ParserAdvance;
          If CurTokKind = TK_DOT Then
          Begin
            ParserAdvance; { consommer . }
            If (CurTokKind = TK_IDENT) And (CurTokStr = 'out') Then
            Begin
              ParserAdvance;
              If CurTokKind = TK_DOT Then
              Begin
                ParserAdvance; { consommer . }
                If CurTokKind = TK_IDENT Then
                Begin
                  SubName := CurTokStr;
                  ParserAdvance;
                  If (SubName = 'println') Or (SubName = 'print') Then
                    E := ParseSysOutCall(SubName = 'println')
                  Else
                  Begin
                    CompileError('unknown System.out method: ' + SubName, LexLineNo);
                    E := ExprMakeEAX(TY_IDX_VOID);
                  End;
                End
                Else
                Begin
                  CompileError('expected method name after System.out.', LexLineNo);
                  E := ExprMakeEAX(TY_IDX_VOID);
                End;
              End
              Else
              Begin
                { System.out sans methode }
                E.Kind    := EK_MEM;
                E.ImmVal  := 0;
                E.TypeIdx := TY_IDX_INT;
                E.Offset  := 0;
                E.SymIdx  := -1;
              End;
            End
            Else
            Begin
              { System.quelquechose }
              E.Kind    := EK_MEM;
              E.ImmVal  := 0;
              E.TypeIdx := TY_IDX_INT;
              E.Offset  := 0;
              E.SymIdx  := -1;
              If CurTokKind = TK_IDENT Then
                ParserAdvance;
            End;
          End
          Else
          Begin
            { System sans . }
            E.Kind    := EK_MEM;
            E.ImmVal  := 0;
            E.TypeIdx := TY_IDX_INT;
            E.Offset  := 0;
            E.SymIdx  := -1;
          End;
        End
        { Scanner : appels de saisie }
        Else If (IdName = 'scanner') Or (IdName = 'Scanner') Or
                (IdName = 'sc') Or (IdName = 'scan') Or (IdName = 'in') Then
        Begin
          ParserAdvance;
          If CurTokKind = TK_DOT Then
          Begin
            ParserAdvance; { consommer . }
            If CurTokKind = TK_IDENT Then
            Begin
              SubName := CurTokStr;
              ParserAdvance;
              If (SubName = 'nextLine') Or (SubName = 'nextInt') Or
                 (SubName = 'nextDouble') Or (SubName = 'next') Then
                E := ParseScannerCall(SubName)
              Else
              Begin
                { Methode inconnue du scanner, traiter comme champ }
                E.Kind    := EK_MEM;
                E.ImmVal  := 0;
                E.TypeIdx := TY_IDX_INT;
                E.Offset  := 0;
                E.SymIdx  := SymI;
                { Si suivi de (, appel de methode }
                If CurTokKind = TK_LPAREN Then
                  E := ParseInstanceMethodCall(E, SubName);
              End;
            End
            Else
            Begin
              E.Kind    := EK_MEM;
              E.ImmVal  := 0;
              E.TypeIdx := TY_IDX_INT;
              E.Offset  := 0;
              E.SymIdx  := SymI;
            End;
          End
          Else
          Begin
            { Ident scanner sans appel de methode }
            PxLastKind := PX_IDENT;
            E.Kind    := EK_MEM;
            E.ImmVal  := 0;
            E.TypeIdx := TY_IDX_INT;
            E.Offset  := 0;
            E.SymIdx  := SymI;
          End;
        End
        Else
        Begin
          { Identifiant normal }
          ParserAdvance;

          { Si suivi de ., verifier si c est ClassName.method() }
          If CurTokKind = TK_DOT Then
          Begin
            ParserAdvance; { consommer . }
            If CurTokKind = TK_IDENT Then
            Begin
              SubName := CurTokStr;
              ParserAdvance;
              If CurTokKind = TK_LPAREN Then
              Begin
                { ClassName.method(args) ou obj.method(args) }
                E.Kind    := EK_MEM;
                E.ImmVal  := 0;
                E.TypeIdx := TY_IDX_INT;
                E.Offset  := 0;
                E.SymIdx  := SymI;
                E := ParseStaticMethodCall(IdName, SubName);
              End
              Else
              Begin
                { Acces champ : obj.field }
                PxLastKind := PX_FIELD;
                Inc(PxFieldCount);
                E := ExprMakeEAX(TY_IDX_INT);
              End;
            End
            Else
            Begin
              E.Kind    := EK_MEM;
              E.ImmVal  := 0;
              E.TypeIdx := TY_IDX_INT;
              E.Offset  := 0;
              E.SymIdx  := SymI;
            End;
          End
          { Si suivi de (, appel de methode/fonction }
          Else If CurTokKind = TK_LPAREN Then
          Begin
            E.Kind    := EK_MEM;
            E.ImmVal  := 0;
            E.TypeIdx := TY_IDX_INT;
            E.Offset  := 0;
            E.SymIdx  := SymI;
            E := ParseStaticMethodCall('', IdName);
          End
          { Variable simple }
          Else
          Begin
            PxLastKind := PX_IDENT;
            E.Kind    := EK_MEM;
            E.ImmVal  := 0;
            E.TypeIdx := TY_IDX_INT;
            E.Offset  := 0;
            E.SymIdx  := SymI;
          End;
        End;
      End;
    TK_KEYWORD :
      Begin
        If CurTokStr = 'null' Then
        Begin
          E := ExprMakeNull;
          ParserAdvance;
        End
        Else If CurTokStr = 'true' Then
        Begin
          E := ExprMakeBool(True);
          ParserAdvance;
        End
        Else If CurTokStr = 'false' Then
        Begin
          E := ExprMakeBool(False);
          ParserAdvance;
        End
        Else If CurTokStr = 'new' Then
        Begin
          ParserAdvance;
          E := ParseNewExpr;
        End
        Else
        Begin
          E.Kind    := EK_NONE;
          E.ImmVal  := 0;
          E.TypeIdx := TY_IDX_VOID;
          E.Offset  := 0;
          E.SymIdx  := -1;
          CompileError('unexpected keyword: ' + CurTokStr, LexLineNo);
          ParserAdvance;
        End;
      End;
    TK_LPAREN :
      Begin
        ParserAdvance; { consommer ( }

        { Verifier si c est un cast : (int)expr, (char)expr, etc. }
        If (CurTokKind = TK_KEYWORD) And
           ((CurTokStr = 'int') Or (CurTokStr = 'char') Or
            (CurTokStr = 'boolean') Or (CurTokStr = 'byte') Or
            (CurTokStr = 'short') Or (CurTokStr = 'long') Or
            (CurTokStr = 'float') Or (CurTokStr = 'double')) Then
        Begin
          IdName := CurTokStr;
          ParserAdvance;
          { Si suivi de ), c est un cast }
          If CurTokKind = TK_RPAREN Then
          Begin
            E := ParseCastExpr(IdName);
          End
          Else
          Begin
            { Ce n etait pas un cast, c est (keyword ...) }
            E.Kind    := EK_NONE;
            E.ImmVal  := 0;
            E.TypeIdx := TY_IDX_VOID;
            E.Offset  := 0;
            E.SymIdx  := -1;
            CompileError('expected ) after cast type', LexLineNo);
          End;
        End
        Else
        Begin
          { Parentheses normales : (expr) }
          PxLastKind := PX_PAREN;
          E := ParseExprPrec(PREC_MAX + 1);
          If CurTokKind = TK_RPAREN Then
            ParserAdvance
          Else
            CompileError('expected )', LexLineNo);
        End;
      End;
    TK_OP :
      Begin
        { Gerer les unaires prefixes + - ~ ! ++ -- }
        If (CurTokStr = '-') Or (CurTokStr = '+') Or
           (CurTokStr = '~') Or (CurTokStr = '!') Or
           (CurTokStr = '++') Or (CurTokStr = '--') Then
        Begin
          { Sera gere par ParseUnary, on retourne NONE }
          E.Kind    := EK_NONE;
          E.ImmVal  := 0;
          E.TypeIdx := TY_IDX_INT;
          E.Offset  := 0;
          E.SymIdx  := -1;
        End
        Else
        Begin
          E.Kind    := EK_NONE;
          E.ImmVal  := 0;
          E.TypeIdx := TY_IDX_VOID;
          E.Offset  := 0;
          E.SymIdx  := -1;
          CompileError('unexpected operator: ' + CurTokStr, LexLineNo);
          ParserAdvance;
        End;
      End;
  Else
    Begin
      E.Kind    := EK_NONE;
      E.ImmVal  := 0;
      E.TypeIdx := TY_IDX_VOID;
      E.Offset  := 0;
      E.SymIdx  := -1;
      If CurTokKind <> TK_EOF Then
      Begin
        CompileError('expected expression, got: ' + CurTokStr, LexLineNo);
        ParserAdvance;
      End;
    End;
  End;

  { Appliquer les suffixes postfixes }
  E := ParsePostfix(E);

  { Verifier operateur ternaire : cond ? a : b }
  If CurTokKind = TK_QUESTION Then
    E := ParseTernaryOp(E);

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
  WriteLn('  PxStaticCount  : ', PxStaticCount);
  WriteLn('  PxInstCount    : ', PxInstCount);
  WriteLn('  PxFieldCount   : ', PxFieldCount);
  WriteLn('  PxIndexCount   : ', PxIndexCount);
  WriteLn('  PxNewCount     : ', PxNewCount);
  WriteLn('  PxCastCount    : ', PxCastCount);
  WriteLn('  PxTernaryCount : ', PxTernaryCount);
  WriteLn('  PxSysOutCount  : ', PxSysOutCount);
  WriteLn('  PxScannerCount : ', PxScannerCount);
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
  IsPxEmpty := (PxCallCount = 0) And (PxFieldCount = 0) And
               (PxIndexCount = 0);
End;

Function GetPxCallCount : LongInt;
Begin
  GetPxCallCount := PxCallCount;
End;

Function GetPxStaticCount : LongInt;
Begin
  GetPxStaticCount := PxStaticCount;
End;

Function GetPxInstCount : LongInt;
Begin
  GetPxInstCount := PxInstCount;
End;

Function GetPxFieldCount : LongInt;
Begin
  GetPxFieldCount := PxFieldCount;
End;

Function GetPxIndexCount : LongInt;
Begin
  GetPxIndexCount := PxIndexCount;
End;

Function GetPxNewCount : LongInt;
Begin
  GetPxNewCount := PxNewCount;
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
    GetPxStatus := ItoS(PxCallCount) + ' calls (' +
                    ItoS(PxStaticCount) + ' static, ' +
                    ItoS(PxInstCount) + ' inst, ' +
                    ItoS(PxFieldCount) + ' fields, ' +
                    ItoS(PxIndexCount) + ' index)';
End;

{ ============================================================ }
{ TODO 09 - PARSEUR : VARIABLES ET AFFECTATIONS [IMPLEMENTE]   }
{ ============================================================ }

Const
  { Types d operations sur les variables }
  VA_NONE          = 0;    { aucun / non defini                    }
  VA_LOAD_LOCAL    = 1;    { lecture variable locale [EBP-offset]  }
  VA_STORE_LOCAL   = 2;    { ecriture variable locale [EBP-offset] }
  VA_LOAD_PARAM    = 3;    { lecture parametre [EBP+offset]        }
  VA_STORE_PARAM   = 4;    { ecriture parametre [EBP+offset]       }
  VA_LOAD_STATIC   = 5;    { lecture champ statique (DATA label)   }
  VA_STORE_STATIC  = 6;    { ecriture champ statique (DATA label)  }
  VA_ASSIGN        = 7;    { affectation simple (=)                }
  VA_AUG_ASSIGN    = 8;    { affectation augmentee (+=, etc.)      }
  VA_PRE_INC       = 9;    { pre-increment (++x)                   }
  VA_PRE_DEC       = 10;   { pre-decrement (--x)                   }
  VA_POST_INC      = 11;   { post-increment (x++)                  }
  VA_POST_DEC      = 12;   { post-decrement (x--)                  }
  VA_ARRAY_STORE   = 13;   { affectation tableau tab[i] = expr     }
  VA_MAX           = 13;

  { Limites }
  VA_MAX_TARGETS   = 16;   { nombre max de cibles d affectation    }

Var
  VaInitialized   : Boolean;    { True si l etat est initialise       }
  VaDeclCount     : LongInt;    { nombre de declarations de variables  }
  VaAssignCount   : LongInt;    { nombre d affectations simples        }
  VaAugCount      : LongInt;    { nombre d affectations augmentees     }
  VaPreIncCount   : LongInt;    { nombre de pre-increments             }
  VaPreDecCount   : LongInt;    { nombre de pre-decrements             }
  VaPostIncCount  : LongInt;    { nombre de post-increments            }
  VaPostDecCount  : LongInt;    { nombre de post-decrements            }
  VaArrayStCount  : LongInt;    { nombre d affectations tableau        }
  VaFinalCount    : LongInt;    { nombre de constantes final           }
  VaLocalOffset   : Integer;    { offset courant pour variables loc.   }
  VaLastKind      : Integer;    { dernier type d operation variable    }
  VaLabelSeq      : Integer;    { sequence pour labels VA               }

{ ------------------------------------------------------------ }
{ InitVaState : initialiser le sous-systeme variables            }
{ ------------------------------------------------------------ }

Procedure InitVaState;
Begin
  VaInitialized   := True;
  VaDeclCount     := 0;
  VaAssignCount   := 0;
  VaAugCount      := 0;
  VaPreIncCount   := 0;
  VaPreDecCount   := 0;
  VaPostIncCount  := 0;
  VaPostDecCount  := 0;
  VaArrayStCount  := 0;
  VaFinalCount    := 0;
  VaLocalOffset   := 0;
  VaLastKind      := VA_NONE;
  VaLabelSeq      := 0;
End;

{ ------------------------------------------------------------ }
{ GenVaLabel : generer un label unique pour les variables         }
{ ------------------------------------------------------------ }

Function GenVaLabel : TString;
Begin
  Inc(VaLabelSeq);
  GenVaLabel := '_JA_' + ItoS(VaLabelSeq);
End;

{ ------------------------------------------------------------ }
{ VaTypeName : retourner le nom du type d operation variable      }
{ ------------------------------------------------------------ }

Function VaTypeName(K : Integer) : TString;
Begin
  Case K Of
    VA_NONE         : VaTypeName := 'NONE';
    VA_LOAD_LOCAL   : VaTypeName := 'LOAD_LOCAL';
    VA_STORE_LOCAL  : VaTypeName := 'STORE_LOCAL';
    VA_LOAD_PARAM   : VaTypeName := 'LOAD_PARAM';
    VA_STORE_PARAM  : VaTypeName := 'STORE_PARAM';
    VA_LOAD_STATIC  : VaTypeName := 'LOAD_STATIC';
    VA_STORE_STATIC : VaTypeName := 'STORE_STATIC';
    VA_ASSIGN       : VaTypeName := 'ASSIGN';
    VA_AUG_ASSIGN   : VaTypeName := 'AUG_ASSIGN';
    VA_PRE_INC      : VaTypeName := 'PRE_INC';
    VA_PRE_DEC      : VaTypeName := 'PRE_DEC';
    VA_POST_INC     : VaTypeName := 'POST_INC';
    VA_POST_DEC     : VaTypeName := 'POST_DEC';
    VA_ARRAY_STORE  : VaTypeName := 'ARRAY_STORE';
  Else
    VaTypeName := 'VA_?(' + ItoS(K) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ ResolveVarType : convertir un mot-cle type en indice type       }
{ Retourne TY_IDX_xxx ou -1 si pas un type connu                 }
{ ------------------------------------------------------------ }

Function ResolveVarType(KW : Integer) : Integer;
Begin
  Case KW Of
    KW_INT     : ResolveVarType := TY_IDX_INT;
    KW_BOOLEAN : ResolveVarType := TY_IDX_BOOLEAN;
    KW_CHAR    : ResolveVarType := TY_IDX_CHAR;
    KW_VOID    : ResolveVarType := TY_IDX_VOID;
    KW_LONG    : ResolveVarType := TY_IDX_INT;
    KW_FLOAT   : ResolveVarType := TY_IDX_INT;
    KW_DOUBLE  : ResolveVarType := TY_IDX_INT;
    KW_BYTE    : ResolveVarType := TY_IDX_INT;
    KW_SHORT   : ResolveVarType := TY_IDX_INT;
  Else
    ResolveVarType := -1;
  End;
End;

{ ------------------------------------------------------------ }
{ ResolveVarTypeStr : convertir un nom de type en indice type     }
{ Inclut les types primitifs + String + tableaux                  }
{ ------------------------------------------------------------ }

Function ResolveVarTypeStr(Const Name : TString) : Integer;
Begin
  If      Name = 'int'     Then ResolveVarTypeStr := TY_IDX_INT
  Else If Name = 'boolean' Then ResolveVarTypeStr := TY_IDX_BOOLEAN
  Else If Name = 'char'    Then ResolveVarTypeStr := TY_IDX_CHAR
  Else If Name = 'void'    Then ResolveVarTypeStr := TY_IDX_VOID
  Else If Name = 'long'    Then ResolveVarTypeStr := TY_IDX_INT
  Else If Name = 'float'   Then ResolveVarTypeStr := TY_IDX_INT
  Else If Name = 'double'  Then ResolveVarTypeStr := TY_IDX_INT
  Else If Name = 'byte'    Then ResolveVarTypeStr := TY_IDX_INT
  Else If Name = 'short'   Then ResolveVarTypeStr := TY_IDX_INT
  Else If Name = 'String'  Then ResolveVarTypeStr := TY_IDX_STRING
  Else
    ResolveVarTypeStr := TypeFindByName(Name);
End;

{ ------------------------------------------------------------ }
{ EmitVarLoad : generer le code pour charger une variable        }
{ dans EAX. Selon le type : statique (DATA), local (EBP-offset)  }
{ ou parametre (EBP+offset).                                     }
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
    SK_CONST :
    Begin
      { Constante final : substitution immediate }
      If Opts.Verbose Then
        WriteLn('; LOAD const ', SymTab[Idx].Name,
                ' imm=', SymTab[Idx].Offset);
      VaLastKind := VA_LOAD_LOCAL;
    End;
  Else
    Begin
      { Variable statique / champ : acces direct par label DATA }
      { MOV EAX, DWORD [_JV_ClassName_nom] }
      If Opts.Verbose Then
        WriteLn('; LOAD static ', SymTab[Idx].Name,
                ' [', SymTab[Idx].AsmName, ']');
      VaLastKind := VA_LOAD_STATIC;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ EmitVarStore : generer le code pour stocker EAX dans une       }
{ variable. Selon le type : statique, local ou parametre.        }
{ ------------------------------------------------------------ }

Procedure EmitVarStore(Idx : Integer);
Begin
  If (Idx < 0) Or (Idx >= SymTabCount) Then Exit;
  If SymTab[Idx].IsFinal Then
  Begin
    CompileError('Cannot assign to final variable: ' +
                 SymTab[Idx].Name, LexLineNo);
    Exit;
  End;
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
      { Champ statique : MOV DWORD [_JV_ClassName_nom], EAX }
      If Opts.Verbose Then
        WriteLn('; STORE static ', SymTab[Idx].Name,
                ' [', SymTab[Idx].AsmName, ']');
      VaLastKind := VA_STORE_STATIC;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ CheckTypeCompat : verifier la compatibilite de type a          }
{ l affectation. Emet un warning si incompatible.                }
{ ------------------------------------------------------------ }

Procedure CheckTypeCompat(DestType, SrcType : Integer);
Begin
  If (DestType < 0) Or (SrcType < 0) Then Exit;
  If Not TypeIsAssignable(DestType, SrcType) Then
    WarnMsg('Type mismatch in assignment');
End;

{ ------------------------------------------------------------ }
{ ParseVarDecl : traiter une declaration de variable locale       }
{ int x; / int x = expr; / int a, b, c; / final int N = 42;    }
{ Attend : CurTokKind = TK_KEYWORD avec type primitif            }
{ ------------------------------------------------------------ }

Procedure ParseVarDecl;
Var
  TypeKW   : Integer;
  TypeIdx  : Integer;
  IsFinal  : Boolean;
  IsArray  : Boolean;
  VarName  : TString;
  VarIdx   : Integer;
  E        : TExprVal;
Begin
  IsFinal := False;

  { Detecter modificateur final }
  If (CurTokKind = TK_KEYWORD) And (CurTokInt = KW_FINAL) Then
  Begin
    IsFinal := True;
    LexNextToken;
  End;

  { Lire le type }
  If CurTokKind <> TK_KEYWORD Then
  Begin
    CompileError('Type expected in variable declaration', LexLineNo);
    Exit;
  End;
  TypeKW  := CurTokInt;
  TypeIdx := ResolveVarType(TypeKW);
  If TypeIdx < 0 Then
  Begin
    CompileError('Unknown type in variable declaration', LexLineNo);
    Exit;
  End;
  LexNextToken;

  { Detecter tableau : int[] }
  IsArray := False;
  If CurTokKind = TK_LBRACKET Then
  Begin
    LexNextToken;
    If CurTokKind = TK_RBRACKET Then
      LexNextToken
    Else
      CompileError('] expected after [ in type', LexLineNo);
    IsArray := True;
    If TypeIdx = TY_IDX_INT Then TypeIdx := TY_IDX_INTARR
    Else If TypeIdx = TY_IDX_CHAR Then TypeIdx := TY_IDX_CHARARR
    Else If TypeIdx = TY_IDX_BOOLEAN Then TypeIdx := TY_IDX_BOOLARR;
  End;

  { Boucle pour declarations multiples : int a, b, c; }
  Repeat
    If CurTokKind <> TK_IDENT Then
    Begin
      CompileError('Identifier expected in declaration', LexLineNo);
      Exit;
    End;
    VarName := CurTokStr;
    LexNextToken;

    { Allouer espace local : [EBP - offset] }
    Inc(VaLocalOffset, 4);
    VarIdx := SymAdd(VarName, SK_LOCAL, TypeIdx, LexLineNo,
                     '', False, IsFinal, False);
    If VarIdx >= 0 Then
      SymTab[VarIdx].Offset := VaLocalOffset;

    Inc(VaDeclCount);
    If IsFinal Then Inc(VaFinalCount);

    If Opts.Verbose Then
    Begin
      If IsFinal Then
        WriteLn('; decl final ', VarName, ' : ',
                TypeKindStr(TypeIdx), ' [EBP-', VaLocalOffset, ']')
      Else If IsArray Then
        WriteLn('; decl ', VarName, '[] : ',
                TypeKindStr(TypeIdx), ' [EBP-', VaLocalOffset, ']')
      Else
        WriteLn('; decl ', VarName, ' : ',
                TypeKindStr(TypeIdx), ' [EBP-', VaLocalOffset, ']');
    End;

    { Initialisation optionnelle : = expr }
    If CurTokStr = '=' Then
    Begin
      LexNextToken;
      E := ParseExpr;
      If VarIdx >= 0 Then
      Begin
        EmitVarStore(VarIdx);
        If IsFinal Then
        Begin
          { Constante final : stocker la valeur immediate }
          SymTab[VarIdx].Kind   := SK_CONST;
          SymTab[VarIdx].Offset := E.ImmVal;
        End;
      End;
    End;

    { Virgule -> prochaine variable }
    If CurTokKind = TK_COMMA Then
      LexNextToken
    Else
      Break;
  Until False;

  { Point-virgule de fin }
  If CurTokKind = TK_SEMICOLON Then
    LexNextToken;
End;

{ ------------------------------------------------------------ }
{ ParseStaticFieldDecl : traiter une declaration de champ stat.   }
{ static int x; / static int x = expr;                           }
{ Attend : mot-cle 'static' deja detecte par l appelant          }
{ ------------------------------------------------------------ }

Procedure ParseStaticFieldDecl(Const ClassName : TString);
Var
  TypeKW   : Integer;
  TypeIdx  : Integer;
  IsFinal  : Boolean;
  VarName  : TString;
  VarIdx   : Integer;
  E        : TExprVal;
Begin
  IsFinal := False;

  { Detecter modificateur final }
  If (CurTokKind = TK_KEYWORD) And (CurTokInt = KW_FINAL) Then
  Begin
    IsFinal := True;
    LexNextToken;
  End;

  { Lire le type }
  If CurTokKind <> TK_KEYWORD Then
  Begin
    CompileError('Type expected in field declaration', LexLineNo);
    Exit;
  End;
  TypeKW  := CurTokInt;
  TypeIdx := ResolveVarType(TypeKW);
  If TypeIdx < 0 Then
  Begin
    CompileError('Unknown type in field declaration', LexLineNo);
    Exit;
  End;
  LexNextToken;

  { Lire le nom du champ }
  If CurTokKind <> TK_IDENT Then
  Begin
    CompileError('Identifier expected in field declaration',
                 LexLineNo);
    Exit;
  End;
  VarName := CurTokStr;
  LexNextToken;

  { Ajouter le symbole comme champ statique }
  VarIdx := SymAdd(VarName, SK_STATIC, TypeIdx, LexLineNo,
                   ClassName, True, IsFinal, True);
  Inc(VaDeclCount);
  If IsFinal Then Inc(VaFinalCount);

  { Creer un slot DATA pour le champ statique }
  { _JV_ClassName_fieldName DD 0 }
  If VarIdx >= 0 Then
    DataAdd(SymTab[VarIdx].AsmName, DK_DWORD, 0, '', 1);

  If Opts.Verbose Then
    WriteLn('; static field ', ClassName, '.', VarName,
            ' : ', TypeKindStr(TypeIdx));

  { Initialisation optionnelle : = expr }
  If CurTokStr = '=' Then
  Begin
    LexNextToken;
    E := ParseExpr;
    If VarIdx >= 0 Then
      EmitVarStore(VarIdx);
  End;

  { Point-virgule de fin }
  If CurTokKind = TK_SEMICOLON Then
    LexNextToken;
End;

{ ------------------------------------------------------------ }
{ ParseAssignSimple : traiter une affectation simple x = expr    }
{ Attend : CurTokStr contient le nom de la variable              }
{ Le token '=' a ete detecte par l appelant                      }
{ ------------------------------------------------------------ }

Procedure ParseAssignSimple(Const VarName : TString);
Var
  VarIdx : Integer;
  E      : TExprVal;
Begin
  VaLastKind := VA_ASSIGN;
  Inc(VaAssignCount);

  { Trouver la variable dans la table des symboles }
  VarIdx := SymFind(VarName);
  If VarIdx < 0 Then
  Begin
    CompileError('Undeclared variable: ' + VarName, LexLineNo);
    Exit;
  End;

  If Opts.Verbose Then
    WriteLn('; assign simple: ', VarName, ' = <expr>');

  { Avancer apres le '=' }
  LexNextToken;

  { Evaluer l expression a droite (resultat dans EAX) }
  E := ParseExpr;

  { Verifier la compatibilite de type }
  CheckTypeCompat(SymTab[VarIdx].TypeIdx, E.TypeIdx);

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
  E      : TExprVal;
Begin
  VaLastKind := VA_AUG_ASSIGN;
  Inc(VaAugCount);

  VarIdx := SymFind(VarName);
  If VarIdx < 0 Then
  Begin
    CompileError('Undeclared variable: ' + VarName, LexLineNo);
    Exit;
  End;

  BinOp := AssignOpToBinOp(AOp);

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
  E := ParseExpr;

  { Appliquer l operation binaire }
  If Opts.Verbose Then
    WriteLn('; ', OpName(BinOp), ' avec valeur empilee');

  { Stocker le resultat }
  EmitVarStore(VarIdx);
End;

{ ------------------------------------------------------------ }
{ ParsePreIncDec : traiter ++x ou --x                            }
{ Attend : CurTokStr est '++' ou '--', l ident suit               }
{ ------------------------------------------------------------ }

Procedure ParsePreIncDec(IsInc : Boolean);
Var
  VarName : TString;
  VarIdx  : Integer;
Begin
  If IsInc Then
  Begin
    VaLastKind := VA_PRE_INC;
    Inc(VaPreIncCount);
  End
  Else
  Begin
    VaLastKind := VA_PRE_DEC;
    Inc(VaPreDecCount);
  End;

  { Avancer apres ++ ou -- }
  LexNextToken;

  If CurTokKind <> TK_IDENT Then
  Begin
    CompileError('Identifier expected after ++/--', LexLineNo);
    Exit;
  End;
  VarName := CurTokStr;
  LexNextToken;

  VarIdx := SymFind(VarName);
  If VarIdx < 0 Then
  Begin
    CompileError('Undeclared variable: ' + VarName, LexLineNo);
    Exit;
  End;

  { Charger la variable }
  EmitVarLoad(VarIdx);

  { INC ou DEC EAX }
  If IsInc Then
  Begin
    If Opts.Verbose Then
      WriteLn('; INC EAX (++', VarName, ')');
  End
  Else
  Begin
    If Opts.Verbose Then
      WriteLn('; DEC EAX (--', VarName, ')');
  End;

  { Stocker le resultat }
  EmitVarStore(VarIdx);
End;

{ ------------------------------------------------------------ }
{ ParsePostIncDec : traiter x++ ou x--                           }
{ Attend : VarName deja lu, CurTokStr est '++' ou '--'           }
{ ------------------------------------------------------------ }

Procedure ParsePostIncDec(Const VarName : TString;
                          IsInc : Boolean);
Var
  VarIdx : Integer;
Begin
  If IsInc Then
  Begin
    VaLastKind := VA_POST_INC;
    Inc(VaPostIncCount);
  End
  Else
  Begin
    VaLastKind := VA_POST_DEC;
    Inc(VaPostDecCount);
  End;

  { Avancer apres ++ ou -- }
  LexNextToken;

  VarIdx := SymFind(VarName);
  If VarIdx < 0 Then
  Begin
    CompileError('Undeclared variable: ' + VarName, LexLineNo);
    Exit;
  End;

  { Charger la variable (valeur originale dans EAX) }
  EmitVarLoad(VarIdx);

  { Sauvegarder la valeur originale (pour usage dans expression) }
  If Opts.Verbose Then
    WriteLn('; PUSH EAX (valeur originale de ', VarName, ')');

  { INC ou DEC la copie }
  If IsInc Then
  Begin
    If Opts.Verbose Then
      WriteLn('; INC (', VarName, '++)');
  End
  Else
  Begin
    If Opts.Verbose Then
      WriteLn('; DEC (', VarName, '--)');
  End;

  { Stocker la valeur incrementee/decrementee }
  EmitVarStore(VarIdx);

  { Restaurer la valeur originale dans EAX }
  If Opts.Verbose Then
    WriteLn('; POP EAX (restaurer valeur originale)');
End;

{ ------------------------------------------------------------ }
{ ParseArrayAssign : traiter tab[i] = expr                       }
{ Attend : VarName deja lu, CurTokKind = TK_LBRACKET             }
{ ------------------------------------------------------------ }

Procedure ParseArrayAssign(Const VarName : TString);
Var
  VarIdx : Integer;
  AOp    : Integer;
  E      : TExprVal;
Begin
  VaLastKind := VA_ARRAY_STORE;
  Inc(VaArrayStCount);

  VarIdx := SymFind(VarName);
  If VarIdx < 0 Then
  Begin
    CompileError('Undeclared array: ' + VarName, LexLineNo);
    Exit;
  End;

  { Avancer apres [ }
  LexNextToken;

  { Evaluer l index }
  E := ParseExpr;

  If Opts.Verbose Then
    WriteLn('; index evaluated for ', VarName, '[]');

  { Attendre ] }
  If CurTokKind = TK_RBRACKET Then
    LexNextToken
  Else
    CompileError('] expected after array index', LexLineNo);

  { Detecter affectation }
  AOp := IsAssignOp;
  If AOp >= 0 Then
  Begin
    LexNextToken;

    If Opts.Verbose Then
    Begin
      If AOp = AOP_ASSIGN Then
        WriteLn('; array assign: ', VarName, '[i] = <expr>')
      Else
        WriteLn('; array aug assign: ', VarName, '[i] ',
                AssignOpName(AOp), ' <expr>');
    End;

    { Sauvegarder adresse sur la pile }
    If Opts.Verbose Then
      WriteLn('; PUSH EBX (adresse tableau)');

    { Evaluer l expression a droite }
    E := ParseExpr;

    { Stocker : MOV [EBX+4+i*4], EAX }
    If Opts.Verbose Then
      WriteLn('; MOV [EBX+4+i*4], EAX');
  End
  Else
  Begin
    { Lecture seule : tab[i] utilise comme expression }
    If Opts.Verbose Then
      WriteLn('; array load: MOV EAX, [EBX+4+i*4]');
  End;
End;

{ ------------------------------------------------------------ }
{ DumpVaState : afficher l etat du sous-systeme des variables    }
{ ------------------------------------------------------------ }

Procedure DumpVaState;
Begin
  WriteLn('--- Va State ---');
  WriteLn('  VaInitialized   : ', VaInitialized);
  WriteLn('  VaDeclCount     : ', VaDeclCount);
  WriteLn('  VaAssignCount   : ', VaAssignCount);
  WriteLn('  VaAugCount      : ', VaAugCount);
  WriteLn('  VaPreIncCount   : ', VaPreIncCount);
  WriteLn('  VaPreDecCount   : ', VaPreDecCount);
  WriteLn('  VaPostIncCount  : ', VaPostIncCount);
  WriteLn('  VaPostDecCount  : ', VaPostDecCount);
  WriteLn('  VaArrayStCount  : ', VaArrayStCount);
  WriteLn('  VaFinalCount    : ', VaFinalCount);
  WriteLn('  VaLocalOffset   : ', VaLocalOffset);
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
  IsVaEmpty := (VaDeclCount = 0) And (VaAssignCount = 0) And
               (VaAugCount = 0) And (VaArrayStCount = 0);
End;

Function GetVaDeclCount : LongInt;
Begin
  GetVaDeclCount := VaDeclCount;
End;

Function GetVaAssignCount : LongInt;
Begin
  GetVaAssignCount := VaAssignCount;
End;

Function GetVaAugCount : LongInt;
Begin
  GetVaAugCount := VaAugCount;
End;

Function GetVaPreIncCount : LongInt;
Begin
  GetVaPreIncCount := VaPreIncCount;
End;

Function GetVaPostIncCount : LongInt;
Begin
  GetVaPostIncCount := VaPostIncCount;
End;

Function GetVaFinalCount : LongInt;
Begin
  GetVaFinalCount := VaFinalCount;
End;

Function GetVaLastKind : Integer;
Begin
  GetVaLastKind := VaLastKind;
End;

Function GetVaStatus : TString;
Begin
  If Not VaInitialized Then
    GetVaStatus := 'Not initialized'
  Else
    GetVaStatus := ItoS(VaDeclCount) + ' decl, ' +
                   ItoS(VaAssignCount) + ' assign, ' +
                   ItoS(VaAugCount) + ' aug, ' +
                   ItoS(VaPreIncCount + VaPostIncCount) + ' inc, ' +
                   ItoS(VaPreDecCount + VaPostDecCount) + ' dec, ' +
                   ItoS(VaArrayStCount) + ' arr';
End;

{ ============================================================ }
{ TODO 10 - PARSEUR : IF / ELSE ET OPERATEUR TERNAIRE          }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { Types d operations conditionnelles }
  IF_NONE          = 0;    { aucun / non defini                    }
  IF_SIMPLE        = 1;    { if (cond) bloc                        }
  IF_ELSE          = 2;    { if (cond) bloc else bloc              }
  IF_ELSEIF        = 3;    { if (cond) bloc else if (cond) bloc    }
  IF_ELSEIF_ELSE   = 4;    { if ... else if ... else bloc          }
  IF_TERNARY       = 5;    { cond ? a : b                          }
  IF_NOBRACE       = 6;    { if (cond) stmt; sans accolades        }
  IF_TRUTHY        = 7;    { test truthy (TEST EAX, EAX)           }
  IF_FALSY         = 8;    { test falsy (EAX = 0)                  }
  IF_AND_SC        = 9;    { and-and avec court-circuit             }
  IF_OR_SC         = 10;   { or-or avec court-circuit               }
  IF_TEST_JZ       = 11;   { TEST EAX, EAX / JZ label             }
  IF_TEST_JNZ      = 12;   { TEST EAX, EAX / JNZ label            }
  IF_BRANCH        = 13;   { branche if/else if/else               }
  IF_MAX           = 13;

  { Limites }
  IF_MAX_ELIF      = 32;   { nombre max de else if par if          }
  IF_MAX_NEST      = 16;   { profondeur max d imbrication if       }

Var
  IfInitialized   : Boolean;    { True si l etat est initialise       }
  IfStmtCount     : LongInt;    { nombre d instructions if            }
  IfElseIfCount   : LongInt;    { nombre de else if rencontres        }
  IfElseCount     : LongInt;    { nombre de else rencontres           }
  IfTernaryCount  : LongInt;    { nombre d expressions ternaires      }
  IfNoBraceCount  : LongInt;    { nombre de if sans accolades         }
  IfAndScCount    : LongInt;    { nombre de and-and court-circuit      }
  IfOrScCount     : LongInt;    { nombre de or-or court-circuit        }
  IfTestCount     : LongInt;    { nombre de TEST EAX, EAX emis       }
  IfLastKind      : Integer;    { dernier type d operation if         }
  IfLabelSeq      : Integer;    { sequence pour labels IF              }

{ ------------------------------------------------------------ }
{ InitIfState : initialiser le sous-systeme if/else              }
{ ------------------------------------------------------------ }

Procedure InitIfState;
Begin
  IfInitialized   := True;
  IfStmtCount     := 0;
  IfElseIfCount   := 0;
  IfElseCount     := 0;
  IfTernaryCount  := 0;
  IfNoBraceCount  := 0;
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
  GenIfLabel := '_JL_IF_' + ItoS(IfLabelSeq);
End;

{ ------------------------------------------------------------ }
{ IfTypeName : retourner le nom du type d operation if            }
{ ------------------------------------------------------------ }

Function IfTypeName(K : Integer) : TString;
Begin
  Case K Of
    IF_NONE          : IfTypeName := 'IF_NONE';
    IF_SIMPLE        : IfTypeName := 'IF_SIMPLE';
    IF_ELSE          : IfTypeName := 'IF_ELSE';
    IF_ELSEIF        : IfTypeName := 'IF_ELSEIF';
    IF_ELSEIF_ELSE   : IfTypeName := 'IF_ELSEIF_ELSE';
    IF_TERNARY       : IfTypeName := 'IF_TERNARY';
    IF_NOBRACE       : IfTypeName := 'IF_NOBRACE';
    IF_TRUTHY        : IfTypeName := 'IF_TRUTHY';
    IF_FALSY         : IfTypeName := 'IF_FALSY';
    IF_AND_SC        : IfTypeName := 'IF_AND_SC';
    IF_OR_SC         : IfTypeName := 'IF_OR_SC';
    IF_TEST_JZ       : IfTypeName := 'IF_TEST_JZ';
    IF_TEST_JNZ      : IfTypeName := 'IF_TEST_JNZ';
    IF_BRANCH        : IfTypeName := 'IF_BRANCH';
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
  WriteLn('  JZ ' + DestLabel);
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
  WriteLn('  JNZ ' + DestLabel);
End;

{ ------------------------------------------------------------ }
{ EmitCondAnd : emettre un and-and avec court-circuit            }
{   Si le premier operande est falsy, sauter directement a       }
{   FailLabel sans evaluer le second operande.                   }
{ ------------------------------------------------------------ }

Procedure EmitCondAnd(FailLabel : TString);
Begin
  Inc(IfAndScCount);
  IfLastKind := IF_AND_SC;
  { EAX contient le resultat du premier operande }
  WriteLn('  TEST EAX, EAX');
  WriteLn('  JZ ' + FailLabel + '  ; && short-circuit');
End;

{ ------------------------------------------------------------ }
{ EmitCondOr : emettre un or-or avec court-circuit               }
{   Si le premier operande est truthy, sauter directement a      }
{   SuccessLabel sans evaluer le second operande.                }
{ ------------------------------------------------------------ }

Procedure EmitCondOr(SuccessLabel : TString);
Begin
  Inc(IfOrScCount);
  IfLastKind := IF_OR_SC;
  { EAX contient le resultat du premier operande }
  WriteLn('  TEST EAX, EAX');
  WriteLn('  JNZ ' + SuccessLabel + '  ; || short-circuit');
End;

{ ------------------------------------------------------------ }
{ EmitIfLabel : emettre un label dans le flux assembleur          }
{ ------------------------------------------------------------ }

Procedure EmitIfLabel(Lbl : TString);
Begin
  WriteLn(Lbl + ':');
End;

{ ------------------------------------------------------------ }
{ EmitIfJmp : emettre un saut inconditionnel                     }
{ ------------------------------------------------------------ }

Procedure EmitIfJmp(DestLabel : TString);
Begin
  WriteLn('  JMP ' + DestLabel);
End;

{ ------------------------------------------------------------ }
{ ParseIfStmt : parser une instruction if / else if / else       }
{   if (cond) bloc [else if (cond) bloc] [else bloc]             }
{                                                                  }
{   Java n a pas de elif, mais utilise else if                    }
{                                                                  }
{   Emission assembleur :                                         }
{     evaluer cond -> TEST EAX, EAX -> JZ _JL_ELIF_N             }
{     bloc if                                                     }
{     JMP _JL_ENDIF_N                                             }
{     _JL_ELIF_N: evaluer cond else if -> JZ next                 }
{     bloc else if                                                }
{     JMP _JL_ENDIF_N                                             }
{     _JL_ELSE_N: bloc else                                       }
{     _JL_ENDIF_N:                                                }
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
  LblEndIf := '_JL_ENDIF_' + ItoS(BaseSeq);

  { Evaluer la condition du if }
  { ParseExpr doit laisser le resultat dans EAX }
  WriteLn('  ; --- if statement #' + ItoS(BaseSeq) + ' ---');

  { Label pour le premier else if ou else }
  Inc(IfLabelSeq);
  LblElif := '_JL_ELIF_' + ItoS(IfLabelSeq);

  { Emettre le test de la condition }
  EmitTestTruthy(LblElif);

  { Bloc du if (delimiteur par accolades ou instruction unique) }
  WriteLn('  ; if body');

  { Saut vers la fin apres le bloc }
  EmitIfJmp(LblEndIf);

  { Label pour else if ou else }
  EmitIfLabel(LblElif);

  { Parser les else if }
  While ElifIdx < IF_MAX_ELIF Do
  Begin
    { Verifier si le token courant est 'else' suivi de 'if' }
    If (CurTokKind = TK_KEYWORD) And (CurTokInt = KW_ELSE) Then
    Begin
      { Regarder si c est un else if (Java n a pas de elif) }
      { On ne peut pas lookahead facilement, donc on traite le else }
      { et on regarde ensuite si c est suivi de if }
      Inc(IfElseIfCount);
      Inc(ElifIdx);
      IfLastKind := IF_ELSEIF;

      WriteLn('  ; else if #' + ItoS(ElifIdx) + ' in if #' +
              ItoS(BaseSeq));

      { Generer label pour prochain else if ou else }
      Inc(IfLabelSeq);
      LblElif := '_JL_ELIF_' + ItoS(IfLabelSeq);

      { Evaluer la condition du else if }
      EmitTestTruthy(LblElif);

      { Bloc du else if }
      WriteLn('  ; else if body');

      { Saut vers la fin }
      EmitIfJmp(LblEndIf);

      { Label pour le prochain else if ou else }
      EmitIfLabel(LblElif);
    End
    Else
      Break;
  End;

  { Parser le else optionnel }
  If (CurTokKind = TK_KEYWORD) And (CurTokInt = KW_ELSE) Then
  Begin
    Inc(IfElseCount);
    HasElse := True;

    LblElse := '_JL_ELSE_' + ItoS(BaseSeq);
    WriteLn('  ; else in if #' + ItoS(BaseSeq));

    { Bloc du else }
    WriteLn('  ; else body');
  End;

  { Label de fin }
  EmitIfLabel(LblEndIf);
  WriteLn('  ; --- end if #' + ItoS(BaseSeq) + ' ---');

  { Determiner le type exact de l instruction }
  If HasElse And (ElifIdx > 0) Then
    IfLastKind := IF_ELSEIF_ELSE
  Else If ElifIdx > 0 Then
    IfLastKind := IF_ELSEIF
  Else If HasElse Then
    IfLastKind := IF_ELSE
  Else
    IfLastKind := IF_SIMPLE;
End;

{ ------------------------------------------------------------ }
{ ParseTernaryExpr : parser une expression conditionnelle        }
{   cond ? a : b                                                  }
{                                                                 }
{   Emission assembleur :                                        }
{     evaluer cond -> TEST EAX, EAX -> JZ _JL_TELSE_N           }
{     evaluer a -> JMP _JL_TEND_N                                }
{     _JL_TELSE_N: evaluer b                                     }
{     _JL_TEND_N:                                                }
{ ------------------------------------------------------------ }

Procedure ParseTernaryExpr;
Var
  LblElse : TString;
  LblEnd  : TString;
Begin
  Inc(IfTernaryCount);
  IfLastKind := IF_TERNARY;

  Inc(IfLabelSeq);
  LblElse := '_JL_TELSE_' + ItoS(IfLabelSeq);
  LblEnd  := '_JL_TEND_' + ItoS(IfLabelSeq);

  WriteLn('  ; --- ternary expr #' + ItoS(IfLabelSeq) + ' ---');

  { Evaluer la condition }
  WriteLn('  ; ternary: evaluate condition');
  EmitTestTruthy(LblElse);

  { Evaluer la branche true (a) }
  WriteLn('  ; ternary: true branch');
  EmitIfJmp(LblEnd);

  { Label pour la branche false }
  EmitIfLabel(LblElse);

  { Evaluer la branche false (b) }
  WriteLn('  ; ternary: false branch');

  { Label de fin }
  EmitIfLabel(LblEnd);
  WriteLn('  ; --- end ternary #' + ItoS(IfLabelSeq) + ' ---');
End;

{ ------------------------------------------------------------ }
{ ParseNoBraceIf : parser un if sans accolades (instruction      }
{   unique) : if (cond) stmt; [else stmt;]                       }
{ ------------------------------------------------------------ }

Procedure ParseNoBraceIf;
Begin
  Inc(IfNoBraceCount);
  IfLastKind := IF_NOBRACE;
  WriteLn('  ; if (no brace) single statement');
End;

{ ------------------------------------------------------------ }
{ IsTruthyValue : verifier si une valeur immediate est truthy    }
{   0 est falsy ; tout le reste est truthy                       }
{ ------------------------------------------------------------ }

Function IsTruthyValue(V : LongInt) : Boolean;
Begin
  IsTruthyValue := (V <> 0);
End;

{ ------------------------------------------------------------ }
{ IsFalsyValue : verifier si une valeur immediate est falsy      }
{   0 est falsy en Java                                          }
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
  WriteLn('  ; if branch -> skip to ' + SkipLabel);
  EmitTestTruthy(SkipLabel);
End;

{ ------------------------------------------------------------ }
{ EmitElifBranch : emettre le debut d une branche else if        }
{ ------------------------------------------------------------ }

Procedure EmitElifBranch(ElifLabel, SkipLabel : TString);
Begin
  IfLastKind := IF_BRANCH;
  EmitIfLabel(ElifLabel);
  WriteLn('  ; else if branch -> skip to ' + SkipLabel);
  EmitTestTruthy(SkipLabel);
End;

{ ------------------------------------------------------------ }
{ EmitElseBranch : emettre le debut d une branche else           }
{ ------------------------------------------------------------ }

Procedure EmitElseBranch(ElseLabel : TString);
Begin
  IfLastKind := IF_BRANCH;
  EmitIfLabel(ElseLabel);
  WriteLn('  ; else branch');
End;

{ ------------------------------------------------------------ }
{ EmitEndIf : emettre le label de fin d un if                    }
{ ------------------------------------------------------------ }

Procedure EmitEndIf(EndLabel : TString);
Begin
  EmitIfLabel(EndLabel);
  WriteLn('  ; endif');
End;

{ ------------------------------------------------------------ }
{ DumpIfState : afficher l etat du sous-systeme if                }
{ ------------------------------------------------------------ }

Procedure DumpIfState;
Begin
  WriteLn('--- If/Else State ---');
  WriteLn('  IfInitialized   : ', IfInitialized);
  WriteLn('  IfStmtCount     : ', IfStmtCount);
  WriteLn('  IfElseIfCount   : ', IfElseIfCount);
  WriteLn('  IfElseCount     : ', IfElseCount);
  WriteLn('  IfTernaryCount  : ', IfTernaryCount);
  WriteLn('  IfNoBraceCount  : ', IfNoBraceCount);
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
               (IfNoBraceCount = 0);
End;

Function GetIfStmtCount : LongInt;
Begin
  GetIfStmtCount := IfStmtCount;
End;

Function GetIfElseIfCount : LongInt;
Begin
  GetIfElseIfCount := IfElseIfCount;
End;

Function GetIfElseCount : LongInt;
Begin
  GetIfElseCount := IfElseCount;
End;

Function GetIfTernaryCount : LongInt;
Begin
  GetIfTernaryCount := IfTernaryCount;
End;

Function GetIfNoBraceCount : LongInt;
Begin
  GetIfNoBraceCount := IfNoBraceCount;
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
                   ItoS(IfElseIfCount) + ' else if, ' +
                   ItoS(IfElseCount) + ' else, ' +
                   ItoS(IfTernaryCount) + ' ternary, ' +
                   ItoS(IfNoBraceCount) + ' nobrace';
End;

{ ============================================================ }
{ TODO 11 - PARSEUR : BOUCLES while / for / do-while /          }
{           break / continue                                    }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { Types d operations de boucle }
  LP_NONE          = 0;    { aucun / non defini                    }
  LP_WHILE         = 1;    { while (cond) bloc                     }
  LP_DO_WHILE      = 2;    { do bloc while (cond);                 }
  LP_FOR           = 3;    { for (init; cond; incr) bloc           }
  LP_FOR_EACH      = 4;    { for (type x : tab) bloc               }
  LP_BREAK         = 5;    { instruction break                     }
  LP_CONTINUE      = 6;    { instruction continue                  }
  LP_NESTED        = 7;    { boucle imbriquee                      }
  LP_LOOP_PUSH     = 8;    { empiler contexte de boucle            }
  LP_LOOP_POP      = 9;    { depiler contexte de boucle            }
  LP_WHILE_INF     = 10;   { while (true) boucle infinie           }
  LP_FOR_EMPTY     = 11;   { for (;;) boucle infinie               }
  LP_DO_COND       = 12;   { condition de do-while                 }
  LP_FOR_INCR      = 13;   { increment de for                      }
  LP_MAX           = 13;

  { Limites }
  LP_MAX_NEST      = 32;   { profondeur max d imbrication          }

Type
  TLoopRec = Record
    TestLabel  : TString;  { label de test (debut de boucle)       }
    IncrLabel  : TString;  { label d increment (for) ou test (while)}
    EndLabel   : TString;  { label de fin (break target)           }
    IsFor      : Boolean;  { True = for, False = while/do-while    }
    IsDoWhile  : Boolean;  { True = do-while                       }
  End;

Var
  LpInitialized   : Boolean;    { True si l etat est initialise       }
  LpWhileCount    : LongInt;    { nombre de boucles while             }
  LpDoWhileCount  : LongInt;    { nombre de boucles do-while          }
  LpForCount      : LongInt;    { nombre de boucles for               }
  LpForEachCount  : LongInt;    { nombre de boucles for-each          }
  LpBreakCount    : LongInt;    { nombre d instructions break         }
  LpContCount     : LongInt;    { nombre d instructions continue      }
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
  LpDoWhileCount  := 0;
  LpForCount      := 0;
  LpForEachCount  := 0;
  LpBreakCount    := 0;
  LpContCount     := 0;
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
  GenLpLabel := '_JL_LP_' + ItoS(LpLabelSeq);
End;

{ ------------------------------------------------------------ }
{ LpTypeName : retourner le nom du type d operation boucle        }
{ ------------------------------------------------------------ }

Function LpTypeName(K : Integer) : TString;
Begin
  Case K Of
    LP_NONE       : LpTypeName := 'LP_NONE';
    LP_WHILE      : LpTypeName := 'LP_WHILE';
    LP_DO_WHILE   : LpTypeName := 'LP_DO_WHILE';
    LP_FOR        : LpTypeName := 'LP_FOR';
    LP_FOR_EACH   : LpTypeName := 'LP_FOR_EACH';
    LP_BREAK      : LpTypeName := 'LP_BREAK';
    LP_CONTINUE   : LpTypeName := 'LP_CONTINUE';
    LP_NESTED     : LpTypeName := 'LP_NESTED';
    LP_LOOP_PUSH  : LpTypeName := 'LP_LOOP_PUSH';
    LP_LOOP_POP   : LpTypeName := 'LP_LOOP_POP';
    LP_WHILE_INF  : LpTypeName := 'LP_WHILE_INF';
    LP_FOR_EMPTY  : LpTypeName := 'LP_FOR_EMPTY';
    LP_DO_COND    : LpTypeName := 'LP_DO_COND';
    LP_FOR_INCR   : LpTypeName := 'LP_FOR_INCR';
  Else
    LpTypeName := 'LP_UNKNOWN(' + ItoS(K) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ LoopPush : empiler un contexte de boucle sur la pile            }
{   TestLbl  : label de test de condition                        }
{   IncrLbl  : label d increment (for) ou label de test (while)  }
{   EndLbl   : label de fin de boucle (cible de break)           }
{   ForLoop  : True si boucle for, False si boucle while         }
{   DoLoop   : True si boucle do-while                           }
{ ------------------------------------------------------------ }

Procedure LoopPush(TestLbl, IncrLbl, EndLbl : TString;
                   IsForLoop, IsDoLoop : Boolean);
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
  LpStack[LpStackTop].IsFor      := IsForLoop;
  LpStack[LpStackTop].IsDoWhile  := IsDoLoop;
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
{ EmitLoopLabel : emettre un label de boucle                     }
{ ------------------------------------------------------------ }

Procedure EmitLoopLabel(Lbl : TString);
Begin
  WriteLn(Lbl + ':');
End;

{ ------------------------------------------------------------ }
{ EmitLoopJmp : emettre un saut inconditionnel de boucle         }
{ ------------------------------------------------------------ }

Procedure EmitLoopJmp(DestLabel : TString);
Begin
  WriteLn('  JMP ' + DestLabel);
End;

{ ------------------------------------------------------------ }
{ ParseWhileStmt : parser une boucle while                       }
{   while (cond) bloc                                             }
{                                                                  }
{   Emission assembleur :                                         }
{     _JL_WTEST_N:                                                }
{       evaluer cond -> TEST EAX, EAX -> JZ _JL_WEND_N           }
{       corps                                                     }
{       JMP _JL_WTEST_N                                           }
{     _JL_WEND_N:                                                 }
{ ------------------------------------------------------------ }

Procedure ParseWhileStmt;
Var
  LblTest    : TString;
  LblEnd     : TString;
  BaseSeq    : Integer;
Begin
  Inc(LpWhileCount);

  { Generer les labels }
  Inc(LpLabelSeq);
  BaseSeq := LpLabelSeq;
  LblTest := '_JL_WTEST_' + ItoS(BaseSeq);
  LblEnd  := '_JL_WEND_' + ItoS(BaseSeq);

  WriteLn('  ; --- while loop #', BaseSeq, ' ---');

  { Empiler le contexte de boucle }
  LoopPush(LblTest, LblTest, LblEnd, False, False);

  { Label de test de condition }
  EmitLoopLabel(LblTest);

  { Evaluer la condition }
  { ParseExpr doit laisser le resultat dans EAX }
  WriteLn('  ; while: evaluate condition');
  EmitTestTruthy(LblEnd);

  { Corps de la boucle }
  WriteLn('  ; while body');

  { Saut vers le test de condition }
  EmitLoopJmp(LblTest);

  { Label de fin }
  EmitLoopLabel(LblEnd);
  WriteLn('  ; --- end while #', BaseSeq, ' ---');

  { Depiler le contexte }
  LoopPop;

  LpLastKind := LP_WHILE;
End;

{ ------------------------------------------------------------ }
{ ParseDoWhileStmt : parser une boucle do-while                  }
{   do bloc while (cond);                                         }
{                                                                  }
{   Emission assembleur :                                         }
{     _JL_DSTART_N:                                               }
{       corps                                                     }
{     _JL_DTEST_N:                                                }
{       evaluer cond -> TEST EAX, EAX -> JNZ _JL_DSTART_N        }
{     _JL_DEND_N:                                                 }
{ ------------------------------------------------------------ }

Procedure ParseDoWhileStmt;
Var
  LblStart   : TString;
  LblTest    : TString;
  LblEnd     : TString;
  BaseSeq    : Integer;
Begin
  Inc(LpDoWhileCount);

  { Generer les labels }
  Inc(LpLabelSeq);
  BaseSeq := LpLabelSeq;
  LblStart := '_JL_DSTART_' + ItoS(BaseSeq);
  LblTest  := '_JL_DTEST_' + ItoS(BaseSeq);
  LblEnd   := '_JL_DEND_' + ItoS(BaseSeq);

  WriteLn('  ; --- do-while loop #', BaseSeq, ' ---');

  { Empiler le contexte de boucle }
  { Pour continue -> sauter a _JL_DTEST_N (evaluer la condition) }
  LoopPush(LblStart, LblTest, LblEnd, False, True);

  { Label de debut de boucle }
  EmitLoopLabel(LblStart);

  { Corps de la boucle }
  WriteLn('  ; do body');

  { Label de test de condition }
  EmitLoopLabel(LblTest);

  WriteLn('  ; do-while: evaluate condition');
  { Evaluer la condition -> JNZ _JL_DSTART si non-zero (truthy) }
  EmitTestFalsy(LblStart);

  { Label de fin }
  EmitLoopLabel(LblEnd);
  WriteLn('  ; --- end do-while #', BaseSeq, ' ---');

  { Depiler le contexte }
  LoopPop;

  LpLastKind := LP_DO_WHILE;
End;

{ ------------------------------------------------------------ }
{ ParseForStmt : parser une boucle for                           }
{   for (init; cond; incr) bloc                                   }
{                                                                  }
{   Emission assembleur :                                         }
{     init                                                        }
{     _JL_FTEST_N:                                                }
{       evaluer cond -> TEST EAX, EAX -> JZ _JL_FEND_N           }
{       corps                                                     }
{     _JL_FINCR_N:                                                }
{       incr                                                      }
{       JMP _JL_FTEST_N                                           }
{     _JL_FEND_N:                                                 }
{ ------------------------------------------------------------ }

Procedure ParseForStmt;
Var
  LblTest    : TString;
  LblIncr    : TString;
  LblEnd     : TString;
  BaseSeq    : Integer;
Begin
  Inc(LpForCount);

  { Generer les labels }
  Inc(LpLabelSeq);
  BaseSeq := LpLabelSeq;
  LblTest := '_JL_FTEST_' + ItoS(BaseSeq);
  LblIncr := '_JL_FINCR_' + ItoS(BaseSeq);
  LblEnd  := '_JL_FEND_' + ItoS(BaseSeq);

  WriteLn('  ; --- for loop #', BaseSeq, ' ---');

  { Empiler le contexte de boucle }
  { Pour continue -> sauter a _JL_FINCR_N (increment) }
  LoopPush(LblTest, LblIncr, LblEnd, True, False);

  { Phase d initialisation }
  WriteLn('  ; for: init');

  { Label de test de condition }
  EmitLoopLabel(LblTest);

  { Evaluer la condition }
  WriteLn('  ; for: test condition');
  EmitTestTruthy(LblEnd);

  { Corps de la boucle }
  WriteLn('  ; for body');

  { Label d increment }
  EmitLoopLabel(LblIncr);
  WriteLn('  ; for: increment');

  { Saut vers le test }
  EmitLoopJmp(LblTest);

  { Label de fin }
  EmitLoopLabel(LblEnd);
  WriteLn('  ; --- end for #', BaseSeq, ' ---');

  { Depiler le contexte }
  LoopPop;

  LpLastKind := LP_FOR;
End;

{ ------------------------------------------------------------ }
{ ParseForEachStmt : parser une boucle for-each                  }
{   for (type var : iterable) bloc                                }
{                                                                  }
{   Emission assembleur :                                         }
{     MOV DWORD [_JV_idx], 0                                     }
{     _JL_FETEST_N:                                               }
{       CMP DWORD [_JV_idx], length                              }
{       JGE _JL_FEEND_N                                          }
{       MOV EAX, DWORD [array + _JV_idx*4]                       }
{       MOV DWORD [_JV_var], EAX                                 }
{       corps                                                     }
{       INC DWORD [_JV_idx]                                      }
{       JMP _JL_FETEST_N                                         }
{     _JL_FEEND_N:                                                }
{ ------------------------------------------------------------ }

Procedure ParseForEachStmt;
Var
  LblTest    : TString;
  LblIncr    : TString;
  LblEnd     : TString;
  BaseSeq    : Integer;
Begin
  Inc(LpForEachCount);

  { Generer les labels }
  Inc(LpLabelSeq);
  BaseSeq := LpLabelSeq;
  LblTest := '_JL_FETEST_' + ItoS(BaseSeq);
  LblIncr := '_JL_FEINCR_' + ItoS(BaseSeq);
  LblEnd  := '_JL_FEEND_' + ItoS(BaseSeq);

  WriteLn('  ; --- for-each loop #', BaseSeq, ' ---');

  { Empiler le contexte de boucle }
  LoopPush(LblTest, LblIncr, LblEnd, True, False);

  { Initialiser l index }
  WriteLn('  ; for-each: init index = 0');
  WriteLn('  XOR ECX, ECX  ; index = 0');

  { Label de test }
  EmitLoopLabel(LblTest);

  { Tester si index < length }
  WriteLn('  ; for-each: test index < length');
  WriteLn('  CMP ECX, DWORD [EDI]  ; cmp with array length');
  WriteLn('  JGE ', LblEnd);

  { Charger l element courant }
  WriteLn('  ; for-each: load current element');
  WriteLn('  MOV EAX, DWORD [EDI + 4 + ECX*4]  ; load element');

  { Corps de la boucle }
  WriteLn('  ; for-each body');

  { Incrementer l index }
  EmitLoopLabel(LblIncr);
  WriteLn('  INC ECX');
  EmitLoopJmp(LblTest);

  { Label de fin }
  EmitLoopLabel(LblEnd);
  WriteLn('  ; --- end for-each #', BaseSeq, ' ---');

  { Depiler le contexte }
  LoopPop;

  LpLastKind := LP_FOR_EACH;
End;

{ ------------------------------------------------------------ }
{ ParseBreakStmt : parser une instruction break                   }
{   Saute vers le label de fin de la boucle englobante           }
{   break -> JMP _JL_WEND_N ou _JL_FEND_N ou _JL_DEND_N        }
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
  EmitLoopJmp(LpStack[LpStackTop].EndLabel);
End;

{ ------------------------------------------------------------ }
{ ParseContinueStmt : parser une instruction continue             }
{   Saute vers le label d increment (for) ou test (while)        }
{   continue -> JMP _JL_FINCR_N ou _JL_WTEST_N ou _JL_DTEST_N  }
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
  EmitLoopJmp(LpStack[LpStackTop].IncrLabel);
End;

{ ------------------------------------------------------------ }
{ IsInLoop : tester si on est actuellement dans une boucle       }
{ ------------------------------------------------------------ }

Function IsInLoop : Boolean;
Begin
  IsInLoop := LpStackTop > 0;
End;

{ ------------------------------------------------------------ }
{ GetLoopBreakLabel : retourner le label de break courant         }
{ ------------------------------------------------------------ }

Function GetLoopBreakLabel : TString;
Begin
  If LpStackTop > 0 Then
    GetLoopBreakLabel := LpStack[LpStackTop].EndLabel
  Else
    GetLoopBreakLabel := '';
End;

{ ------------------------------------------------------------ }
{ GetLoopContinueLabel : retourner le label de continue courant   }
{ ------------------------------------------------------------ }

Function GetLoopContinueLabel : TString;
Begin
  If LpStackTop > 0 Then
    GetLoopContinueLabel := LpStack[LpStackTop].IncrLabel
  Else
    GetLoopContinueLabel := '';
End;

{ ------------------------------------------------------------ }
{ DumpLpState : afficher l etat du sous-systeme des boucles       }
{ ------------------------------------------------------------ }

Procedure DumpLpState;
Begin
  WriteLn('--- Loop State ---');
  WriteLn('  LpInitialized   : ', LpInitialized);
  WriteLn('  LpWhileCount    : ', LpWhileCount);
  WriteLn('  LpDoWhileCount  : ', LpDoWhileCount);
  WriteLn('  LpForCount      : ', LpForCount);
  WriteLn('  LpForEachCount  : ', LpForEachCount);
  WriteLn('  LpBreakCount    : ', LpBreakCount);
  WriteLn('  LpContCount     : ', LpContCount);
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
  IsLpEmpty := (LpWhileCount = 0) And (LpDoWhileCount = 0) And
               (LpForCount = 0) And (LpForEachCount = 0) And
               (LpBreakCount = 0) And (LpContCount = 0);
End;

Function GetLpWhileCount : LongInt;
Begin
  GetLpWhileCount := LpWhileCount;
End;

Function GetLpDoWhileCount : LongInt;
Begin
  GetLpDoWhileCount := LpDoWhileCount;
End;

Function GetLpForCount : LongInt;
Begin
  GetLpForCount := LpForCount;
End;

Function GetLpForEachCount : LongInt;
Begin
  GetLpForEachCount := LpForEachCount;
End;

Function GetLpBreakCount : LongInt;
Begin
  GetLpBreakCount := LpBreakCount;
End;

Function GetLpContCount : LongInt;
Begin
  GetLpContCount := LpContCount;
End;

Function GetLpMaxNestSeen : LongInt;
Begin
  GetLpMaxNestSeen := LpMaxNestSeen;
End;

Function GetLpStatus : TString;
Begin
  If Not LpInitialized Then
    GetLpStatus := 'Not initialized'
  Else
    GetLpStatus := ItoS(LpWhileCount) + ' while, ' +
                   ItoS(LpDoWhileCount) + ' do-while, ' +
                   ItoS(LpForCount) + ' for, ' +
                   ItoS(LpForEachCount) + ' for-each, ' +
                   ItoS(LpBreakCount) + ' break, ' +
                   ItoS(LpContCount) + ' continue, ' +
                   'max-nest=' + ItoS(LpMaxNestSeen);
End;

{ ============================================================ }
{ TODO 12 - PARSEUR : METHODES STATIQUES ET RETURN             }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { Types d operations de methode }
  MT_NONE          = 0;    { aucun / non defini                    }
  MT_DEF           = 1;    { public static type nom(params) bloc    }
  MT_DEF_PARAMS    = 2;    { definition avec parametres             }
  MT_DEF_VOID      = 3;    { definition void                       }
  MT_RETURN        = 4;    { return expr                           }
  MT_RETURN_VOID   = 5;    { return sans valeur (void)             }
  MT_CALL          = 6;    { appel de methode                      }
  MT_CALL_ARGS     = 7;    { appel avec arguments                  }
  MT_PROLOGUE      = 8;    { prologue de methode                   }
  MT_EPILOGUE      = 9;    { epilogue de methode                   }
  MT_PARAM         = 10;   { parametre de methode                  }
  MT_RECURSIVE     = 11;   { appel recursif                        }
  MT_OVERLOAD_WARN = 12;   { avertissement : surcharge             }
  MT_MAIN          = 13;   { methode main detectee                 }
  MT_MAX           = 13;

  { Limites }
  MT_MAX_PARAMS    = 16;   { nombre max de parametres par methode  }
  MT_MAX_LOCALS    = 64;   { nombre max de variables locales       }
  MT_MAX_NEST      = 1;    { pas de methodes imbriquees            }

Type
  TMtParamRec = Record
    Name       : TString;  { nom du parametre                      }
    TypeIdx    : Integer;   { index du type dans la table des types }
  End;

Var
  MtInitialized   : Boolean;    { True si l etat est initialise       }
  MtDefCount      : LongInt;    { nombre de definitions de methodes   }
  MtReturnCount   : LongInt;    { nombre de return                    }
  MtRetVoidCount  : LongInt;    { nombre de return void               }
  MtCallCount     : LongInt;    { nombre d appels de methode          }
  MtParamCount    : LongInt;    { nombre total de parametres declares }
  MtRecursCount   : LongInt;    { nombre d appels recursifs           }
  MtOverloadWarn  : LongInt;    { nombre d avertissements surcharge   }
  MtMainCount     : LongInt;    { nombre de methodes main trouvees    }
  MtLastKind      : Integer;    { dernier type d operation            }
  MtLabelSeq      : Integer;    { sequence pour labels de methode     }
  MtCurName       : TString;    { nom de la methode courante          }
  MtCurClass      : TString;    { nom de la classe courante           }
  MtCurParamN     : Integer;    { nombre de params de la methode      }
  MtCurLocalN     : Integer;    { nombre de vars locales courantes    }
  MtInDef         : Boolean;    { True si on est dans une methode     }
  MtCurRetType    : TString;    { type de retour de la methode        }
  MtCurParams     : Array[1..MT_MAX_PARAMS] Of TMtParamRec;
  MtCurEpilogue   : TString;    { label de l epilogue courant         }

{ ------------------------------------------------------------ }
{ InitMtState : initialiser le sous-systeme des methodes         }
{ ------------------------------------------------------------ }

Procedure InitMtState;
Begin
  MtInitialized   := True;
  MtDefCount      := 0;
  MtReturnCount   := 0;
  MtRetVoidCount  := 0;
  MtCallCount     := 0;
  MtParamCount    := 0;
  MtRecursCount   := 0;
  MtOverloadWarn  := 0;
  MtMainCount     := 0;
  MtLastKind      := MT_NONE;
  MtLabelSeq      := 0;
  MtCurName       := '';
  MtCurClass      := '';
  MtCurParamN     := 0;
  MtCurLocalN     := 0;
  MtInDef         := False;
  MtCurRetType    := '';
  MtCurEpilogue   := '';
End;

{ ------------------------------------------------------------ }
{ GenMtLabel : generer un label unique pour les methodes          }
{ ------------------------------------------------------------ }

Function GenMtLabel : TString;
Begin
  Inc(MtLabelSeq);
  GenMtLabel := JV_LBL_PFX + 'MT_' + ItoS(MtLabelSeq);
End;

{ ------------------------------------------------------------ }
{ MtTypeName : retourner le nom du type d operation methode       }
{ ------------------------------------------------------------ }

Function MtTypeName(K : Integer) : TString;
Begin
  Case K Of
    MT_NONE          : MtTypeName := 'MT_NONE';
    MT_DEF           : MtTypeName := 'MT_DEF';
    MT_DEF_PARAMS    : MtTypeName := 'MT_DEF_PARAMS';
    MT_DEF_VOID      : MtTypeName := 'MT_DEF_VOID';
    MT_RETURN        : MtTypeName := 'MT_RETURN';
    MT_RETURN_VOID   : MtTypeName := 'MT_RETURN_VOID';
    MT_CALL          : MtTypeName := 'MT_CALL';
    MT_CALL_ARGS     : MtTypeName := 'MT_CALL_ARGS';
    MT_PROLOGUE      : MtTypeName := 'MT_PROLOGUE';
    MT_EPILOGUE      : MtTypeName := 'MT_EPILOGUE';
    MT_PARAM         : MtTypeName := 'MT_PARAM';
    MT_RECURSIVE     : MtTypeName := 'MT_RECURSIVE';
    MT_OVERLOAD_WARN : MtTypeName := 'MT_OVERLOAD_WARN';
    MT_MAIN          : MtTypeName := 'MT_MAIN';
  Else
    MtTypeName := 'MT_UNKNOWN(' + ItoS(K) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ ParseParamListJ : parser la liste de parametres Java            }
{   type nom, type nom, ...                                       }
{   Remplit MtCurParams[1..MtCurParamN]                          }
{   Parametres typees : int x, boolean flag, String s, ...       }
{   Convention cdecl :                                            }
{     Premier param  = [EBP+8]                                    }
{     Deuxieme param = [EBP+12]                                   }
{     N-ieme param   = [EBP + (N*4) + 4]                         }
{ ------------------------------------------------------------ }

Procedure ParseParamListJ;
Var
  PIdx      : Integer;
  PName     : TString;
  PType     : TString;
Begin
  MtCurParamN := 0;

  { Lire les parametres entre parentheses }
  { On suppose que '(' a deja ete consomme }
  While (CurTokKind <> TK_EOF) And (CurTokStr <> ')') Do
  Begin
    PType := '';
    PName := '';

    { Lire le type du parametre }
    If (CurTokKind = TK_IDENT) Or (CurTokKind = TK_KEYWORD) Then
    Begin
      PType := CurTokStr;
      { Gerer les types tableaux (String[], int[]) }
      { Pour le moment, le type est un simple mot }
    End
    Else
      PType := 'int';  { type par defaut si absent }

    { Lire le nom du parametre }
    { En mode stub, le nom suivrait le type }
    PName := '_param_' + ItoS(MtCurParamN + 1);

    If MtCurParamN < MT_MAX_PARAMS Then
    Begin
      Inc(MtCurParamN);
      Inc(MtParamCount);
      PIdx := MtCurParamN;
      MtCurParams[PIdx].Name := PName;
      MtCurParams[PIdx].TypeIdx := 0;  { a resoudre plus tard }
      MtLastKind := MT_PARAM;
    End
    Else
    Begin
      CompileError('Too many parameters (max ' +
                   ItoS(MT_MAX_PARAMS) + ')', LexLineNo);
      Exit;
    End;

    { Sauter la virgule entre parametres }
    If CurTokStr = ',' Then
    Begin
      { On avance apres la virgule }
    End;

    { Avancer au token suivant (simulation) }
    Break;  { Sortir apres un premier passage en mode stub }
  End;
End;

{ ------------------------------------------------------------ }
{ EmitMtPrologue : emettre le prologue d une methode Java         }
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

Procedure EmitMtPrologue(Const FuncLabel : TString;
                         NumLocals : Integer);
Var
  LocalsSize : Integer;
  LblEpi     : TString;
Begin
  Inc(MtLabelSeq);
  LblEpi := JV_LBL_PFX + 'MEPI_' + ItoS(MtLabelSeq);
  MtCurEpilogue := LblEpi;

  LocalsSize := NumLocals * 4;

  WriteLn('  ; --- method prologue: ', MtCurName, ' ---');
  WriteLn(FuncLabel, ':');
  WriteLn('  PUSH EBP');
  WriteLn('  MOV EBP, ESP');
  If LocalsSize > 0 Then
    WriteLn('  SUB ESP, ', LocalsSize, '  ; ', NumLocals, ' local vars');

  WriteLn('  ; parameters: ', MtCurParamN);
  MtLastKind := MT_PROLOGUE;
End;

{ ------------------------------------------------------------ }
{ EmitMtEpilogue : emettre l epilogue d une methode Java          }
{   label_epilogue:                                               }
{   MOV ESP, EBP                                                  }
{   POP EBP                                                       }
{   RET                                                           }
{ ------------------------------------------------------------ }

Procedure EmitMtEpilogue;
Begin
  WriteLn('  ; --- method epilogue: ', MtCurName, ' ---');
  If MtCurEpilogue <> '' Then
    WriteLn(MtCurEpilogue, ':');
  WriteLn('  MOV ESP, EBP');
  WriteLn('  POP EBP');
  WriteLn('  RET');
  WriteLn('  ; --- end method ', MtCurName, ' ---');
  MtLastKind := MT_EPILOGUE;
End;

{ ------------------------------------------------------------ }
{ ParseMethodDecl : parser une declaration de methode Java        }
{   public static type nom(params) bloc                            }
{                                                                  }
{   Convention :                                                   }
{     - On suppose que les modificateurs public/static ont ete    }
{       consommes par l appelant                                  }
{     - Le type de retour est le token courant                    }
{     - Suivi du nom de la methode                                }
{     - Suivi de la liste de parametres entre ( et )              }
{     - Suivi du corps entre accolades                             }
{                                                                  }
{   Emission assembleur :                                         }
{     JMP _JL_MSKIP_N        ; sauter par-dessus le corps        }
{     _JF_ClassName_method:                                       }
{       PUSH EBP / MOV EBP, ESP / SUB ESP, locals_size           }
{       corps                                                     }
{       _JL_MEPI_N:                                               }
{       MOV ESP, EBP / POP EBP / RET                              }
{     _JL_MSKIP_N:                                                }
{                                                                  }
{   Point d entree main :                                         }
{     public static void main(String[] args)                      }
{     Label _JF_ClassName_main                                    }
{ ------------------------------------------------------------ }

Procedure ParseMethodDecl;
Var
  RetType    : TString;
  MethName   : TString;
  FuncLabel  : TString;
  LblSkip    : TString;
  BaseSeq    : Integer;
  IsMain     : Boolean;
  I          : Integer;
Begin
  Inc(MtDefCount);
  IsMain := False;

  { Verifier si on est deja dans une methode (imbrication) }
  If MtInDef Then
  Begin
    Inc(MtOverloadWarn);
    WarnMsg('Nested method definition not supported in Java');
    MtLastKind := MT_OVERLOAD_WARN;
  End;

  MtInDef := True;

  { Generer le label de saut pour sauter le corps }
  Inc(MtLabelSeq);
  BaseSeq := MtLabelSeq;
  LblSkip := JV_LBL_PFX + 'MSKIP_' + ItoS(BaseSeq);

  { Le type de retour est suppose etre le token courant }
  { (deja consomme par l appelant ou determine) }
  RetType := 'void';  { a raffiner par le parseur complet }
  MtCurRetType := RetType;

  { Lire le nom de la methode }
  { En mode stub, on utilise un nom par defaut }
  MethName := '_method_' + ItoS(BaseSeq);

  { Detecter main }
  If MethName = 'main' Then
  Begin
    IsMain := True;
    Inc(MtMainCount);
    MtLastKind := MT_MAIN;
  End;

  MtCurName := MethName;

  { Construire le label assembleur _JF_ClassName_method }
  If MtCurClass <> '' Then
    FuncLabel := JV_FN_PFX + MtCurClass + '_' + MethName
  Else
    FuncLabel := JV_FN_PFX + MethName;

  WriteLn('  ; --- method ', MtCurClass, '.', MethName,
          ' (', RetType, ') ---');

  { Sauter par-dessus le corps de la methode }
  WriteLn('  JMP ', LblSkip);

  { Parser la liste de parametres }
  ParseParamListJ;

  { Initialiser le nombre de variables locales (stub) }
  MtCurLocalN := 0;

  { Emettre le prologue }
  EmitMtPrologue(FuncLabel, MtCurLocalN);

  { Emettre les commentaires pour chaque parametre }
  For I := 1 To MtCurParamN Do
  Begin
    WriteLn('  ; param ', I, ': ', MtCurParams[I].Name,
            ' = [EBP+', (I * 4) + 4, ']');
  End;

  { Corps de la methode (stub: les futurs TODOs parseront le bloc) }
  WriteLn('  ; method body');

  { Retour implicite }
  If RetType = 'void' Then
  Begin
    WriteLn('  ; implicit return (void)');
  End
  Else
  Begin
    WriteLn('  XOR EAX, EAX  ; implicit return 0');
  End;

  { Emettre l epilogue }
  EmitMtEpilogue;

  { Label pour sauter par-dessus le corps }
  WriteLn(LblSkip, ':');

  MtInDef := False;

  { Determiner le type }
  If IsMain Then
    MtLastKind := MT_MAIN
  Else If RetType = 'void' Then
    MtLastKind := MT_DEF_VOID
  Else If MtCurParamN > 0 Then
    MtLastKind := MT_DEF_PARAMS
  Else
    MtLastKind := MT_DEF;
End;

{ ------------------------------------------------------------ }
{ ParseReturnStmtJ : parser une instruction return Java           }
{   return expr;   -> evaluer expr (resultat dans EAX)           }
{                     JMP vers epilogue                           }
{   return;        -> JMP epilogue (methode void)                }
{ ------------------------------------------------------------ }

Procedure ParseReturnStmtJ;
Begin
  If Not MtInDef Then
  Begin
    CompileError('return outside method', LexLineNo);
    Exit;
  End;

  Inc(MtReturnCount);

  { Verifier si return avec ou sans expression }
  { return suivi de ';' = return void }
  If (CurTokStr = ';') Or (CurTokKind = TK_EOF) Then
  Begin
    { return sans valeur (void) }
    Inc(MtRetVoidCount);
    WriteLn('  ; return (void)');
    MtLastKind := MT_RETURN_VOID;
  End
  Else
  Begin
    { return expr -> le resultat de l expression est dans EAX }
    WriteLn('  ; return expr');
    WriteLn('  ; (expression result in EAX)');
    MtLastKind := MT_RETURN;
  End;

  { Sauter vers l epilogue }
  If MtCurEpilogue <> '' Then
    WriteLn('  JMP ', MtCurEpilogue)
  Else
    CompileError('No method epilogue label', LexLineNo);
End;

{ ------------------------------------------------------------ }
{ EmitMtCall : emettre l appel a une methode statique Java        }
{   Convention cdecl :                                            }
{     PUSH arg_n          ; empiler de droite a gauche           }
{     PUSH arg_n-1                                               }
{     ...                                                         }
{     PUSH arg_1                                                  }
{     CALL _JF_ClassName_method                                   }
{     ADD ESP, n*4        ; l appelant nettoie la pile            }
{   Valeur de retour dans EAX                                    }
{ ------------------------------------------------------------ }

Procedure EmitMtCall(Const ClassName, MethName : TString;
                     NumArgs : Integer);
Var
  FuncLabel : TString;
Begin
  Inc(MtCallCount);

  If ClassName <> '' Then
    FuncLabel := JV_FN_PFX + ClassName + '_' + MethName
  Else
    FuncLabel := JV_FN_PFX + MethName;

  WriteLn('  ; call ', ClassName, '.', MethName,
          '(', NumArgs, ' args)');

  { Les arguments doivent avoir ete empiles avant l appel }
  WriteLn('  CALL ', FuncLabel);
  If NumArgs > 0 Then
    WriteLn('  ADD ESP, ', NumArgs * 4, '  ; caller cleanup');
  WriteLn('  ; result in EAX');

  { Verifier si c est un appel recursif }
  If MtInDef And (MethName = MtCurName) Then
  Begin
    Inc(MtRecursCount);
    MtLastKind := MT_RECURSIVE;
  End
  Else If NumArgs > 0 Then
    MtLastKind := MT_CALL_ARGS
  Else
    MtLastKind := MT_CALL;
End;

{ ------------------------------------------------------------ }
{ EmitPushArgJ : emettre PUSH pour un argument de methode         }
{   Empile la valeur dans EAX sur la pile                        }
{ ------------------------------------------------------------ }

Procedure EmitPushArgJ(ArgIndex, TotalArgs : Integer);
Begin
  WriteLn('  PUSH EAX  ; arg ', ArgIndex, ' of ', TotalArgs);
End;

{ ------------------------------------------------------------ }
{ GetMtParamOffset : retourner l offset d un parametre            }
{   Premier parametre  = [EBP+8]                                  }
{   Deuxieme parametre = [EBP+12]                                 }
{   N-ieme parametre   = [EBP + (N*4) + 4]                       }
{ ------------------------------------------------------------ }

Function GetMtParamOffset(ParamIndex : Integer) : Integer;
Begin
  GetMtParamOffset := (ParamIndex * 4) + 4;
End;

{ ------------------------------------------------------------ }
{ GetMtLocalOffset : retourner l offset d une variable locale     }
{   Premiere variable  = [EBP-4]                                  }
{   Deuxieme variable  = [EBP-8]                                  }
{   N-ieme variable    = [EBP - N*4]                              }
{ ------------------------------------------------------------ }

Function GetMtLocalOffset(LocalIndex : Integer) : Integer;
Begin
  GetMtLocalOffset := -(LocalIndex * 4);
End;

{ ------------------------------------------------------------ }
{ EmitLoadParamJ : emettre le chargement d un parametre dans EAX  }
{   MOV EAX, DWORD [EBP + offset]                                }
{ ------------------------------------------------------------ }

Procedure EmitLoadParamJ(ParamIndex : Integer);
Var
  Off : Integer;
Begin
  Off := GetMtParamOffset(ParamIndex);
  WriteLn('  MOV EAX, DWORD [EBP+', Off, ']  ; param ', ParamIndex);
End;

{ ------------------------------------------------------------ }
{ EmitStoreParamJ : emettre le stockage dans un parametre         }
{   MOV DWORD [EBP + offset], EAX                                }
{ ------------------------------------------------------------ }

Procedure EmitStoreParamJ(ParamIndex : Integer);
Var
  Off : Integer;
Begin
  Off := GetMtParamOffset(ParamIndex);
  WriteLn('  MOV DWORD [EBP+', Off, '], EAX  ; param ', ParamIndex);
End;

{ ------------------------------------------------------------ }
{ EmitLoadLocalJ : emettre le chargement d une variable locale    }
{   MOV EAX, DWORD [EBP - offset]                                }
{ ------------------------------------------------------------ }

Procedure EmitLoadLocalJ(LocalIndex : Integer);
Var
  Off : Integer;
Begin
  Off := GetMtLocalOffset(LocalIndex);
  WriteLn('  MOV EAX, DWORD [EBP', Off, ']  ; local ', LocalIndex);
End;

{ ------------------------------------------------------------ }
{ EmitStoreLocalJ : emettre le stockage dans une variable locale  }
{   MOV DWORD [EBP - offset], EAX                                }
{ ------------------------------------------------------------ }

Procedure EmitStoreLocalJ(LocalIndex : Integer);
Var
  Off : Integer;
Begin
  Off := GetMtLocalOffset(LocalIndex);
  WriteLn('  MOV DWORD [EBP', Off, '], EAX  ; local ', LocalIndex);
End;

{ ------------------------------------------------------------ }
{ DumpMtState : afficher l etat du sous-systeme des methodes      }
{ ------------------------------------------------------------ }

Procedure DumpMtState;
Begin
  WriteLn('--- Method State ---');
  WriteLn('  MtInitialized   : ', MtInitialized);
  WriteLn('  MtDefCount      : ', MtDefCount);
  WriteLn('  MtReturnCount   : ', MtReturnCount);
  WriteLn('  MtRetVoidCount  : ', MtRetVoidCount);
  WriteLn('  MtCallCount     : ', MtCallCount);
  WriteLn('  MtParamCount    : ', MtParamCount);
  WriteLn('  MtRecursCount   : ', MtRecursCount);
  WriteLn('  MtOverloadWarn  : ', MtOverloadWarn);
  WriteLn('  MtMainCount     : ', MtMainCount);
  WriteLn('  MtLastKind      : ', MtTypeName(MtLastKind));
  WriteLn('  MtLabelSeq      : ', MtLabelSeq);
  WriteLn('  MtCurName       : ', MtCurName);
  WriteLn('  MtCurClass      : ', MtCurClass);
  WriteLn('  MtCurParamN     : ', MtCurParamN);
  WriteLn('  MtCurLocalN     : ', MtCurLocalN);
  WriteLn('  MtInDef         : ', MtInDef);
  WriteLn('  MtCurRetType    : ', MtCurRetType);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 12)                              }
{ ------------------------------------------------------------ }

Function IsMtInitialized : Boolean;
Begin
  IsMtInitialized := MtInitialized;
End;

Function IsMtEmpty : Boolean;
Begin
  IsMtEmpty := (MtDefCount = 0) And (MtReturnCount = 0) And
               (MtCallCount = 0);
End;

Function GetMtDefCount : LongInt;
Begin
  GetMtDefCount := MtDefCount;
End;

Function GetMtReturnCount : LongInt;
Begin
  GetMtReturnCount := MtReturnCount;
End;

Function GetMtRetVoidCount : LongInt;
Begin
  GetMtRetVoidCount := MtRetVoidCount;
End;

Function GetMtCallCount : LongInt;
Begin
  GetMtCallCount := MtCallCount;
End;

Function GetMtParamCount : LongInt;
Begin
  GetMtParamCount := MtParamCount;
End;

Function GetMtRecursCount : LongInt;
Begin
  GetMtRecursCount := MtRecursCount;
End;

Function GetMtMainCount : LongInt;
Begin
  GetMtMainCount := MtMainCount;
End;

Function GetMtStatus : TString;
Begin
  If Not MtInitialized Then
    GetMtStatus := 'Not initialized'
  Else
    GetMtStatus := ItoS(MtDefCount) + ' methods, ' +
                   ItoS(MtReturnCount) + ' return, ' +
                   ItoS(MtCallCount) + ' call, ' +
                   ItoS(MtParamCount) + ' params, ' +
                   ItoS(MtMainCount) + ' main, ' +
                   ItoS(MtRecursCount) + ' recursive';
End;

{ ============================================================ }
{ TODO 13 - PARSEUR : ENTREES/SORTIES (System.out / Scanner)   }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { Types d operations d entree/sortie }
  IO_NONE          = 0;    { aucun / non defini                    }
  IO_PRINTLN_STR   = 1;    { System.out.println(String)            }
  IO_PRINTLN_INT   = 2;    { System.out.println(int)               }
  IO_PRINTLN_BOOL  = 3;    { System.out.println(boolean)           }
  IO_PRINTLN_CHAR  = 4;    { System.out.println(char)              }
  IO_PRINTLN_EMPTY = 5;    { System.out.println() sans argument    }
  IO_PRINT_STR     = 6;    { System.out.print(String)              }
  IO_PRINT_INT     = 7;    { System.out.print(int)                 }
  IO_PRINT_BOOL    = 8;    { System.out.print(boolean)             }
  IO_PRINT_CHAR    = 9;    { System.out.print(char)                }
  IO_PRINT_CONCAT  = 10;   { concatenation dans print/println      }
  IO_SCANF_DECL    = 11;   { Scanner sc = new Scanner(System.in)   }
  IO_SCANF_NEXTLN  = 12;   { sc.nextLine()                         }
  IO_SCANF_NEXTINT = 13;   { sc.nextInt()                          }
  IO_MAX           = 13;

  { Limites }
  IO_MAX_CONCAT    = 16;   { nombre max de parties concatenees     }
  IO_MAX_SCANNERS  = 4;    { nombre max de variables Scanner       }

Type
  TIoScannerRec = Record
    Name       : TString;  { nom de la variable Scanner            }
    DeclLine   : Integer;  { ligne de declaration                  }
  End;

Var
  IoInitialized     : Boolean;    { True si l etat est initialise       }
  IoPrintlnCount    : LongInt;    { nombre de println emis              }
  IoPrintCount      : LongInt;    { nombre de print emis                }
  IoConcatCount     : LongInt;    { nombre de concatenations            }
  IoScanDeclCount   : LongInt;    { nombre de Scanner declares          }
  IoNextLineCount   : LongInt;    { nombre de nextLine()                }
  IoNextIntCount    : LongInt;    { nombre de nextInt()                 }
  IoLastKind        : Integer;    { dernier type d operation IO         }
  IoLabelSeq        : Integer;    { sequence pour labels IO             }
  IoCurArgType      : Integer;    { type de l argument courant          }
  IoCurIsPrintln    : Boolean;    { True si println, False si print     }
  IoCurScannerName  : TString;    { nom du Scanner courant              }
  IoScanners        : Array[1..IO_MAX_SCANNERS] Of TIoScannerRec;
  IoScannerCount    : Integer;    { nombre de Scanners enregistres      }

{ ------------------------------------------------------------ }
{ InitIoState : initialiser le sous-systeme entrees/sorties      }
{ ------------------------------------------------------------ }

Procedure InitIoState;
Var I : Integer;
Begin
  IoInitialized     := True;
  IoPrintlnCount    := 0;
  IoPrintCount      := 0;
  IoConcatCount     := 0;
  IoScanDeclCount   := 0;
  IoNextLineCount   := 0;
  IoNextIntCount    := 0;
  IoLastKind        := IO_NONE;
  IoLabelSeq        := 0;
  IoCurArgType      := TY_IDX_VOID;
  IoCurIsPrintln    := True;
  IoCurScannerName  := '';
  IoScannerCount    := 0;
  For I := 1 To IO_MAX_SCANNERS Do
  Begin
    IoScanners[I].Name     := '';
    IoScanners[I].DeclLine := 0;
  End;
End;

{ ------------------------------------------------------------ }
{ GenIoLabel : generer un label unique pour les E/S              }
{ ------------------------------------------------------------ }

Function GenIoLabel : TString;
Begin
  Inc(IoLabelSeq);
  GenIoLabel := JV_LBL_PFX + 'IO_' + ItoS(IoLabelSeq);
End;

{ ------------------------------------------------------------ }
{ IoTypeName : retourner le nom du type d operation IO           }
{ ------------------------------------------------------------ }

Function IoTypeName(K : Integer) : TString;
Begin
  Case K Of
    IO_NONE          : IoTypeName := 'IO_NONE';
    IO_PRINTLN_STR   : IoTypeName := 'IO_PRINTLN_STR';
    IO_PRINTLN_INT   : IoTypeName := 'IO_PRINTLN_INT';
    IO_PRINTLN_BOOL  : IoTypeName := 'IO_PRINTLN_BOOL';
    IO_PRINTLN_CHAR  : IoTypeName := 'IO_PRINTLN_CHAR';
    IO_PRINTLN_EMPTY : IoTypeName := 'IO_PRINTLN_EMPTY';
    IO_PRINT_STR     : IoTypeName := 'IO_PRINT_STR';
    IO_PRINT_INT     : IoTypeName := 'IO_PRINT_INT';
    IO_PRINT_BOOL    : IoTypeName := 'IO_PRINT_BOOL';
    IO_PRINT_CHAR    : IoTypeName := 'IO_PRINT_CHAR';
    IO_PRINT_CONCAT  : IoTypeName := 'IO_PRINT_CONCAT';
    IO_SCANF_DECL    : IoTypeName := 'IO_SCANF_DECL';
    IO_SCANF_NEXTLN  : IoTypeName := 'IO_SCANF_NEXTLN';
    IO_SCANF_NEXTINT : IoTypeName := 'IO_SCANF_NEXTINT';
  Else
    IoTypeName := 'IO_UNKNOWN(' + ItoS(K) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ EmitPrintlnStr : emettre le code pour                          }
{   System.out.println(String)                                   }
{   PUSH EAX / CALL _JRT_WRITESTR / CALL _JRT_WRITECRLF         }
{ ------------------------------------------------------------ }

Procedure EmitPrintlnStr;
Begin
  Inc(IoPrintlnCount);
  IoLastKind   := IO_PRINTLN_STR;
  IoCurArgType := TY_IDX_STRING;
  { Code generation : PUSH EAX (pointeur chaine) }
  { CALL _JRT_WRITESTR                           }
  { ADD ESP, 4                                    }
  { CALL _JRT_WRITECRLF                          }
End;

{ ------------------------------------------------------------ }
{ EmitPrintlnInt : emettre le code pour                          }
{   System.out.println(int)                                      }
{   PUSH EAX / CALL _JRT_ITOA / PUSH EAX / CALL _JRT_WRITESTR  }
{   CALL _JRT_WRITECRLF                                         }
{ ------------------------------------------------------------ }

Procedure EmitPrintlnInt;
Begin
  Inc(IoPrintlnCount);
  IoLastKind   := IO_PRINTLN_INT;
  IoCurArgType := TY_IDX_INT;
  { Code generation : PUSH EAX (valeur entiere)   }
  { CALL _JRT_ITOA                                }
  { ADD ESP, 4                                    }
  { PUSH EAX (ptr chaine resultat)                }
  { CALL _JRT_WRITESTR                            }
  { ADD ESP, 4                                    }
  { CALL _JRT_WRITECRLF                           }
End;

{ ------------------------------------------------------------ }
{ EmitPrintlnBool : emettre le code pour                         }
{   System.out.println(boolean)                                  }
{   TEST EAX,EAX / JZ .false / PUSH "true" / JMP .end           }
{   .false: PUSH "false" / .end: CALL _JRT_WRITESTR + CRLF      }
{ ------------------------------------------------------------ }

Procedure EmitPrintlnBool;
Begin
  Inc(IoPrintlnCount);
  IoLastKind   := IO_PRINTLN_BOOL;
  IoCurArgType := TY_IDX_BOOLEAN;
  { Code generation : TEST EAX, EAX               }
  { JZ lbl_false                                  }
  { PUSH OFFSET _JK_true                          }
  { JMP lbl_end                                   }
  { lbl_false: PUSH OFFSET _JK_false              }
  { lbl_end:   CALL _JRT_WRITESTR                 }
  { ADD ESP, 4                                    }
  { CALL _JRT_WRITECRLF                           }
End;

{ ------------------------------------------------------------ }
{ EmitPrintlnChar : emettre le code pour                         }
{   System.out.println(char)                                     }
{   PUSH EAX / CALL _JRT_WRITECHAR / CALL _JRT_WRITECRLF        }
{ ------------------------------------------------------------ }

Procedure EmitPrintlnChar;
Begin
  Inc(IoPrintlnCount);
  IoLastKind   := IO_PRINTLN_CHAR;
  IoCurArgType := TY_IDX_CHAR;
  { Code generation : PUSH EAX (valeur char)       }
  { CALL _JRT_WRITECHAR                            }
  { ADD ESP, 4                                     }
  { CALL _JRT_WRITECRLF                            }
End;

{ ------------------------------------------------------------ }
{ EmitPrintStr : emettre le code pour                            }
{   System.out.print(String) sans retour a la ligne              }
{   PUSH EAX / CALL _JRT_WRITESTR                               }
{ ------------------------------------------------------------ }

Procedure EmitPrintStr;
Begin
  Inc(IoPrintCount);
  IoLastKind   := IO_PRINT_STR;
  IoCurArgType := TY_IDX_STRING;
  { Code generation : PUSH EAX (pointeur chaine) }
  { CALL _JRT_WRITESTR                           }
  { ADD ESP, 4                                   }
End;

{ ------------------------------------------------------------ }
{ EmitPrintInt : emettre le code pour                            }
{   System.out.print(int) sans retour a la ligne                 }
{   PUSH EAX / CALL _JRT_ITOA / PUSH EAX / CALL _JRT_WRITESTR  }
{ ------------------------------------------------------------ }

Procedure EmitPrintInt;
Begin
  Inc(IoPrintCount);
  IoLastKind   := IO_PRINT_INT;
  IoCurArgType := TY_IDX_INT;
  { Code generation : PUSH EAX (valeur entiere)   }
  { CALL _JRT_ITOA                                }
  { ADD ESP, 4                                    }
  { PUSH EAX (ptr chaine resultat)                }
  { CALL _JRT_WRITESTR                            }
  { ADD ESP, 4                                    }
End;

{ ------------------------------------------------------------ }
{ EmitPrintBool : emettre le code pour                           }
{   System.out.print(boolean) sans retour a la ligne             }
{ ------------------------------------------------------------ }

Procedure EmitPrintBool;
Begin
  Inc(IoPrintCount);
  IoLastKind   := IO_PRINT_BOOL;
  IoCurArgType := TY_IDX_BOOLEAN;
  { Code generation : TEST EAX, EAX               }
  { JZ lbl_false                                  }
  { PUSH OFFSET _JK_true                          }
  { JMP lbl_end                                   }
  { lbl_false: PUSH OFFSET _JK_false              }
  { lbl_end:   CALL _JRT_WRITESTR                 }
  { ADD ESP, 4                                    }
End;

{ ------------------------------------------------------------ }
{ EmitPrintChar : emettre le code pour                           }
{   System.out.print(char) sans retour a la ligne                }
{ ------------------------------------------------------------ }

Procedure EmitPrintChar;
Begin
  Inc(IoPrintCount);
  IoLastKind   := IO_PRINT_CHAR;
  IoCurArgType := TY_IDX_CHAR;
  { Code generation : PUSH EAX (valeur char)       }
  { CALL _JRT_WRITECHAR                            }
  { ADD ESP, 4                                     }
End;

{ ------------------------------------------------------------ }
{ EmitPrintConcat : emettre le code pour afficher une            }
{   concatenation : "texte " + n + " suite"                      }
{   Chaque partie est convertie et affichee sequentiellement     }
{ ------------------------------------------------------------ }

Procedure EmitPrintConcat(ArgTypeIdx : Integer);
Begin
  Inc(IoConcatCount);
  IoLastKind := IO_PRINT_CONCAT;
  { Selon le type de la partie a concatener : }
  Case ArgTypeIdx Of
    TY_IDX_STRING  : EmitPrintStr;
    TY_IDX_INT     : EmitPrintInt;
    TY_IDX_BOOLEAN : EmitPrintBool;
    TY_IDX_CHAR    : EmitPrintChar;
  Else
    { Type inconnu : convertir comme entier }
    EmitPrintInt;
  End;
End;

{ ------------------------------------------------------------ }
{ ParsePrintlnStmt : parser System.out.println(expr)             }
{   L argument a deja ete evalue et son type est dans ArgType     }
{   Emet le code d affichage selon le type + CRLF                }
{ ------------------------------------------------------------ }

Procedure ParsePrintlnStmt(ArgTypeIdx : Integer);
Begin
  IoCurIsPrintln := True;
  Case ArgTypeIdx Of
    TY_IDX_STRING  : EmitPrintlnStr;
    TY_IDX_INT     : EmitPrintlnInt;
    TY_IDX_BOOLEAN : EmitPrintlnBool;
    TY_IDX_CHAR    : EmitPrintlnChar;
    TY_IDX_VOID    :
    Begin
      { println() sans argument = juste CRLF }
      Inc(IoPrintlnCount);
      IoLastKind := IO_PRINTLN_EMPTY;
      { Code generation : CALL _JRT_WRITECRLF }
    End;
  Else
    { Type inconnu : traiter comme int }
    EmitPrintlnInt;
  End;
End;

{ ------------------------------------------------------------ }
{ ParsePrintStmt : parser System.out.print(expr)                 }
{   L argument a deja ete evalue et son type est dans ArgType     }
{   Emet le code d affichage selon le type sans CRLF             }
{ ------------------------------------------------------------ }

Procedure ParsePrintStmt(ArgTypeIdx : Integer);
Begin
  IoCurIsPrintln := False;
  Case ArgTypeIdx Of
    TY_IDX_STRING  : EmitPrintStr;
    TY_IDX_INT     : EmitPrintInt;
    TY_IDX_BOOLEAN : EmitPrintBool;
    TY_IDX_CHAR    : EmitPrintChar;
  Else
    { Type inconnu : traiter comme int }
    EmitPrintInt;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseScannerDecl : enregistrer une declaration de Scanner       }
{   Scanner sc = new Scanner(System.in)                          }
{   Le nom de la variable est fourni en parametre                }
{ ------------------------------------------------------------ }

Procedure ParseScannerDecl(VarName : TString);
Begin
  Inc(IoScanDeclCount);
  IoLastKind := IO_SCANF_DECL;
  IoCurScannerName := VarName;

  If IoScannerCount < IO_MAX_SCANNERS Then
  Begin
    Inc(IoScannerCount);
    IoScanners[IoScannerCount].Name     := VarName;
    IoScanners[IoScannerCount].DeclLine := LexLineNo;
  End
  Else
    WarnMsg('maximum number of Scanner variables reached');
End;

{ ------------------------------------------------------------ }
{ EmitScanNextLine : emettre le code pour sc.nextLine()          }
{   CALL _JRT_READLINE                                           }
{   -> EAX = pointeur vers la chaine lue                        }
{ ------------------------------------------------------------ }

Function EmitScanNextLine : TExprVal;
Begin
  Inc(IoNextLineCount);
  IoLastKind := IO_SCANF_NEXTLN;
  { Code generation : CALL _JRT_READLINE           }
  { EAX = ptr vers buffer de lecture               }
  EmitScanNextLine := ExprMakeEAX(TY_IDX_STRING);
End;

{ ------------------------------------------------------------ }
{ EmitScanNextInt : emettre le code pour sc.nextInt()            }
{   CALL _JRT_READLINE + CALL _JRT_ATOI                         }
{   -> EAX = valeur entiere lue                                 }
{ ------------------------------------------------------------ }

Function EmitScanNextInt : TExprVal;
Begin
  Inc(IoNextIntCount);
  IoLastKind := IO_SCANF_NEXTINT;
  { Code generation : CALL _JRT_READLINE           }
  { PUSH EAX                                      }
  { CALL _JRT_ATOI                                }
  { ADD ESP, 4                                    }
  { EAX = valeur entiere                          }
  EmitScanNextInt := ExprMakeEAX(TY_IDX_INT);
End;

{ ------------------------------------------------------------ }
{ IsScannerVar : verifier si un nom est un Scanner enregistre    }
{ ------------------------------------------------------------ }

Function IsScannerVar(Name : TString) : Boolean;
Var I : Integer;
Begin
  IsScannerVar := False;
  For I := 1 To IoScannerCount Do
    If IoScanners[I].Name = Name Then
    Begin
      IsScannerVar := True;
      Exit;
    End;
End;

{ ------------------------------------------------------------ }
{ GetIoPrintTotal : nombre total d appels print + println        }
{ ------------------------------------------------------------ }

Function GetIoPrintTotal : LongInt;
Begin
  GetIoPrintTotal := IoPrintlnCount + IoPrintCount;
End;

{ ------------------------------------------------------------ }
{ GetIoScanTotal : nombre total d operations Scanner             }
{ ------------------------------------------------------------ }

Function GetIoScanTotal : LongInt;
Begin
  GetIoScanTotal := IoScanDeclCount + IoNextLineCount + IoNextIntCount;
End;

{ ------------------------------------------------------------ }
{ DumpIoState : afficher l etat du sous-systeme IO               }
{ ------------------------------------------------------------ }

Procedure DumpIoState;
Var I : Integer;
Begin
  WriteLn('--- IO State ---');
  WriteLn('  IoInitialized    : ', IoInitialized);
  WriteLn('  IoPrintlnCount   : ', IoPrintlnCount);
  WriteLn('  IoPrintCount     : ', IoPrintCount);
  WriteLn('  IoConcatCount    : ', IoConcatCount);
  WriteLn('  IoScanDeclCount  : ', IoScanDeclCount);
  WriteLn('  IoNextLineCount  : ', IoNextLineCount);
  WriteLn('  IoNextIntCount   : ', IoNextIntCount);
  WriteLn('  IoLastKind       : ', IoTypeName(IoLastKind));
  WriteLn('  IoLabelSeq       : ', IoLabelSeq);
  WriteLn('  IoCurArgType     : ', IoCurArgType);
  WriteLn('  IoCurIsPrintln   : ', IoCurIsPrintln);
  WriteLn('  IoCurScannerName : ', IoCurScannerName);
  WriteLn('  IoScannerCount   : ', IoScannerCount);
  If IoScannerCount > 0 Then
    For I := 1 To IoScannerCount Do
      WriteLn('    Scanner[', I, '] : ', IoScanners[I].Name,
              ' (line ', IoScanners[I].DeclLine, ')');
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
  IsIoEmpty := (IoPrintlnCount = 0) And (IoPrintCount = 0) And
               (IoScanDeclCount = 0) And (IoNextLineCount = 0) And
               (IoNextIntCount = 0);
End;

Function GetIoPrintlnCount : LongInt;
Begin
  GetIoPrintlnCount := IoPrintlnCount;
End;

Function GetIoPrintCount : LongInt;
Begin
  GetIoPrintCount := IoPrintCount;
End;

Function GetIoConcatCount : LongInt;
Begin
  GetIoConcatCount := IoConcatCount;
End;

Function GetIoScanDeclCount : LongInt;
Begin
  GetIoScanDeclCount := IoScanDeclCount;
End;

Function GetIoNextLineCount : LongInt;
Begin
  GetIoNextLineCount := IoNextLineCount;
End;

Function GetIoNextIntCount : LongInt;
Begin
  GetIoNextIntCount := IoNextIntCount;
End;

Function GetIoScannerCount : Integer;
Begin
  GetIoScannerCount := IoScannerCount;
End;

Function GetIoStatus : TString;
Begin
  If Not IoInitialized Then
    GetIoStatus := 'Not initialized'
  Else
    GetIoStatus := ItoS(IoPrintlnCount) + ' println, ' +
                   ItoS(IoPrintCount) + ' print, ' +
                   ItoS(IoConcatCount) + ' concat, ' +
                   ItoS(IoScanDeclCount) + ' scanner-decl, ' +
                   ItoS(IoNextLineCount) + ' nextLine, ' +
                   ItoS(IoNextIntCount) + ' nextInt';
End;

{ ============================================================ }
{ TODO 14 - PARSEUR : TABLEAUX (int[], char[], String[])       }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { Types d operations sur les tableaux }
  AR_NONE          = 0;    { aucun / non defini                    }
  AR_DECL_NEW      = 1;    { int[] tab = new int[n]                }
  AR_DECL_INIT     = 2;    { int[] tab = (10, 20, 30) init-liste   }
  AR_LOAD          = 3;    { tab[i] (lecture)                      }
  AR_STORE         = 4;    { tab[i] = val (affectation)            }
  AR_LENGTH        = 5;    { tab.length                            }
  AR_BOUNDS_CHK    = 6;    { verification des bornes               }
  AR_FOREACH       = 7;    { enhanced for : for (int x : tab)      }
  AR_PARAM_PASS    = 8;    { passage en parametre (par reference)  }
  AR_CHAR_LOAD     = 9;    { char[] acces octet                    }
  AR_CHAR_STORE    = 10;   { char[] affectation octet              }
  AR_STR_LOAD      = 11;   { String[] acces pointeur               }
  AR_STR_STORE     = 12;   { String[] affectation pointeur         }
  AR_ALLOC         = 13;   { allocation heap brute                 }
  AR_MAX           = 13;

  { Limites }
  AR_MAX_DIM       = 1;    { nombre max de dimensions (1D seul.)   }
  AR_MAX_INIT_ELEM = 256;  { nombre max d elements init par liste  }
  AR_ELEM_SIZE     = 4;    { taille d un element (4 octets = DD)   }

Type
  TArDeclRec = Record
    VarName    : TString;  { nom de la variable tableau            }
    ElemType   : Integer;  { type des elements (TY_IDX_*)          }
    ArrayType  : Integer;  { type du tableau  (TY_IDX_*ARR)        }
    Size       : LongInt;  { nombre d elements (0 si dynamique)    }
    DeclLine   : Integer;  { ligne de declaration                  }
    IsStatic   : Boolean;  { True si static                        }
  End;

Const
  AR_MAX_ARRAYS = 64;      { nombre max de tableaux declares       }

Var
  ArInitialized     : Boolean;    { True si l etat est initialise       }
  ArDeclCount       : LongInt;    { nombre de declarations de tableaux  }
  ArNewCount        : LongInt;    { nombre d alloc via new              }
  ArInitListCount   : LongInt;    { nombre d init par liste             }
  ArLoadCount       : LongInt;    { nombre d acces en lecture           }
  ArStoreCount      : LongInt;    { nombre d acces en ecriture          }
  ArLengthCount     : LongInt;    { nombre d acces .length              }
  ArBoundsChkCount  : LongInt;    { nombre de verif de bornes           }
  ArForEachCount    : LongInt;    { nombre de enhanced-for sur tableau  }
  ArLastKind        : Integer;    { dernier type d operation            }
  ArLabelSeq        : Integer;    { sequence pour labels AR             }
  ArCurElemType     : Integer;    { type d element courant              }
  ArCurArrayType    : Integer;    { type de tableau courant             }
  ArCurVarName      : TString;    { nom du tableau courant              }
  ArArrays          : Array[1..AR_MAX_ARRAYS] Of TArDeclRec;
  ArArrayCount      : Integer;    { nombre de tableaux enregistres      }

{ ------------------------------------------------------------ }
{ InitArState : initialiser le sous-systeme tableaux             }
{ ------------------------------------------------------------ }

Procedure InitArState;
Var I : Integer;
Begin
  ArInitialized     := True;
  ArDeclCount       := 0;
  ArNewCount        := 0;
  ArInitListCount   := 0;
  ArLoadCount       := 0;
  ArStoreCount      := 0;
  ArLengthCount     := 0;
  ArBoundsChkCount  := 0;
  ArForEachCount    := 0;
  ArLastKind        := AR_NONE;
  ArLabelSeq        := 0;
  ArCurElemType     := TY_IDX_INT;
  ArCurArrayType    := TY_IDX_INTARR;
  ArCurVarName      := '';
  ArArrayCount      := 0;
  For I := 1 To AR_MAX_ARRAYS Do
  Begin
    ArArrays[I].VarName   := '';
    ArArrays[I].ElemType  := TY_IDX_INT;
    ArArrays[I].ArrayType := TY_IDX_INTARR;
    ArArrays[I].Size      := 0;
    ArArrays[I].DeclLine  := 0;
    ArArrays[I].IsStatic  := False;
  End;
End;

{ ------------------------------------------------------------ }
{ GenArLabel : generer un label unique pour les tableaux          }
{ ------------------------------------------------------------ }

Function GenArLabel : TString;
Begin
  Inc(ArLabelSeq);
  GenArLabel := JV_LBL_PFX + 'AR_' + ItoS(ArLabelSeq);
End;

{ ------------------------------------------------------------ }
{ ArTypeName : retourner le nom du type d operation tableau       }
{ ------------------------------------------------------------ }

Function ArTypeName(K : Integer) : TString;
Begin
  Case K Of
    AR_NONE       : ArTypeName := 'AR_NONE';
    AR_DECL_NEW   : ArTypeName := 'AR_DECL_NEW';
    AR_DECL_INIT  : ArTypeName := 'AR_DECL_INIT';
    AR_LOAD       : ArTypeName := 'AR_LOAD';
    AR_STORE      : ArTypeName := 'AR_STORE';
    AR_LENGTH     : ArTypeName := 'AR_LENGTH';
    AR_BOUNDS_CHK : ArTypeName := 'AR_BOUNDS_CHK';
    AR_FOREACH    : ArTypeName := 'AR_FOREACH';
    AR_PARAM_PASS : ArTypeName := 'AR_PARAM_PASS';
    AR_CHAR_LOAD  : ArTypeName := 'AR_CHAR_LOAD';
    AR_CHAR_STORE : ArTypeName := 'AR_CHAR_STORE';
    AR_STR_LOAD   : ArTypeName := 'AR_STR_LOAD';
    AR_STR_STORE  : ArTypeName := 'AR_STR_STORE';
    AR_ALLOC      : ArTypeName := 'AR_ALLOC';
  Else
    ArTypeName := 'AR_UNKNOWN(' + ItoS(K) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ ElemTypeToArrayType : convertir un type d element en type       }
{   de tableau (TY_IDX_INT -> TY_IDX_INTARR, etc.)              }
{ ------------------------------------------------------------ }

Function ElemTypeToArrayType(ElemTIdx : Integer) : Integer;
Begin
  Case ElemTIdx Of
    TY_IDX_INT     : ElemTypeToArrayType := TY_IDX_INTARR;
    TY_IDX_CHAR    : ElemTypeToArrayType := TY_IDX_CHARARR;
    TY_IDX_STRING  : ElemTypeToArrayType := TY_IDX_STRARR;
    TY_IDX_BOOLEAN : ElemTypeToArrayType := TY_IDX_BOOLARR;
  Else
    ElemTypeToArrayType := TY_IDX_INTARR;
  End;
End;

{ ------------------------------------------------------------ }
{ ArrayTypeToElemType : convertir un type de tableau en type      }
{   d element (TY_IDX_INTARR -> TY_IDX_INT, etc.)               }
{ ------------------------------------------------------------ }

Function ArrayTypeToElemType(ArrTIdx : Integer) : Integer;
Begin
  Case ArrTIdx Of
    TY_IDX_INTARR  : ArrayTypeToElemType := TY_IDX_INT;
    TY_IDX_CHARARR : ArrayTypeToElemType := TY_IDX_CHAR;
    TY_IDX_STRARR  : ArrayTypeToElemType := TY_IDX_STRING;
    TY_IDX_BOOLARR : ArrayTypeToElemType := TY_IDX_BOOLEAN;
  Else
    ArrayTypeToElemType := TY_IDX_INT;
  End;
End;

{ ------------------------------------------------------------ }
{ IsArrayType : verifier si un type est un type tableau           }
{ ------------------------------------------------------------ }

Function IsArrayType(TIdx : Integer) : Boolean;
Begin
  IsArrayType := (TIdx = TY_IDX_INTARR) Or (TIdx = TY_IDX_CHARARR) Or
                 (TIdx = TY_IDX_STRARR) Or (TIdx = TY_IDX_BOOLARR);
End;

{ ------------------------------------------------------------ }
{ RegisterArray : enregistrer une declaration de tableau          }
{ ------------------------------------------------------------ }

Procedure RegisterArray(VarName : TString; ElemTIdx : Integer;
                        Size : LongInt; IsStatic : Boolean);
Begin
  If ArArrayCount < AR_MAX_ARRAYS Then
  Begin
    Inc(ArArrayCount);
    ArArrays[ArArrayCount].VarName   := VarName;
    ArArrays[ArArrayCount].ElemType  := ElemTIdx;
    ArArrays[ArArrayCount].ArrayType := ElemTypeToArrayType(ElemTIdx);
    ArArrays[ArArrayCount].Size      := Size;
    ArArrays[ArArrayCount].DeclLine  := LexLineNo;
    ArArrays[ArArrayCount].IsStatic  := IsStatic;
  End
  Else
    WarnMsg('maximum number of array declarations reached');
End;

{ ------------------------------------------------------------ }
{ EmitArrayAlloc : emettre le code pour allouer un tableau        }
{   int[] tab = new int[n]                                       }
{   Layout memoire : [length DD][elem0 DD][elem1 DD]...          }
{   PUSH (n+1)*4 / CALL _JRT_HEAPALLOC / MOV [EAX], n           }
{   -> EAX = pointeur vers le tableau (debut du bloc length)     }
{ ------------------------------------------------------------ }

Procedure EmitArrayAlloc(ElemTIdx : Integer; SizeExpr : TExprVal);
Begin
  Inc(ArNewCount);
  Inc(ArDeclCount);
  ArLastKind     := AR_DECL_NEW;
  ArCurElemType  := ElemTIdx;
  ArCurArrayType := ElemTypeToArrayType(ElemTIdx);
  { Code generation :                                }
  { MOV ECX, EAX           (taille dans ECX)         }
  { LEA EAX, [ECX+1]       (n+1 elements)           }
  { SHL EAX, 2             (* 4 octets)             }
  { PUSH EAX                                         }
  { CALL _JRT_HEAPALLOC                              }
  { ADD ESP, 4                                       }
  { MOV [EAX], ECX         (stocker length en tete)  }
  { -> EAX = ptr vers le bloc tableau                }
End;

{ ------------------------------------------------------------ }
{ EmitArrayInitList : emettre le code pour init par liste         }
{   int[] tab = (10, 20, 30) init-liste                          }
{   Allouer (count+1)*4 + stocker chaque element                 }
{ ------------------------------------------------------------ }

Procedure EmitArrayInitList(ElemTIdx : Integer; ElemCount : Integer);
Begin
  Inc(ArInitListCount);
  Inc(ArDeclCount);
  ArLastKind     := AR_DECL_INIT;
  ArCurElemType  := ElemTIdx;
  ArCurArrayType := ElemTypeToArrayType(ElemTIdx);
  { Code generation :                                }
  { PUSH (ElemCount+1)*4                             }
  { CALL _JRT_HEAPALLOC                              }
  { ADD ESP, 4                                       }
  { MOV DWORD PTR [EAX], ElemCount  (length)         }
  { MOV DWORD PTR [EAX+4], val0                     }
  { MOV DWORD PTR [EAX+8], val1                     }
  { ... etc pour chaque element                      }
End;

{ ------------------------------------------------------------ }
{ EmitArrayLoad : emettre le code pour lire tab[i]               }
{   EBX = ptr tableau, EAX = index                               }
{   MOV EAX, [EBX + 4 + EAX*4]                                  }
{ ------------------------------------------------------------ }

Function EmitArrayLoad(ArrTIdx : Integer) : TExprVal;
Var ElemTIdx : Integer;
Begin
  Inc(ArLoadCount);
  ElemTIdx := ArrayTypeToElemType(ArrTIdx);
  ArLastKind     := AR_LOAD;
  ArCurElemType  := ElemTIdx;
  ArCurArrayType := ArrTIdx;
  If ElemTIdx = TY_IDX_CHAR Then
    ArLastKind := AR_CHAR_LOAD
  Else If ElemTIdx = TY_IDX_STRING Then
    ArLastKind := AR_STR_LOAD;
  { Code generation :                                }
  { Cas general (int[], boolean[], String[]) :       }
  {   MOV EAX, [EBX + 4 + EAX*4]                    }
  { Cas char[] :                                     }
  {   MOVZX EAX, BYTE [EBX + 4 + EAX]               }
  EmitArrayLoad := ExprMakeEAX(ElemTIdx);
End;

{ ------------------------------------------------------------ }
{ EmitArrayStore : emettre le code pour tab[i] = val             }
{   EBX = ptr tableau, ECX = index, EAX = valeur                }
{   MOV [EBX + 4 + ECX*4], EAX                                  }
{ ------------------------------------------------------------ }

Procedure EmitArrayStore(ArrTIdx : Integer);
Var ElemTIdx : Integer;
Begin
  Inc(ArStoreCount);
  ElemTIdx := ArrayTypeToElemType(ArrTIdx);
  ArLastKind     := AR_STORE;
  ArCurElemType  := ElemTIdx;
  ArCurArrayType := ArrTIdx;
  If ElemTIdx = TY_IDX_CHAR Then
    ArLastKind := AR_CHAR_STORE
  Else If ElemTIdx = TY_IDX_STRING Then
    ArLastKind := AR_STR_STORE;
  { Code generation :                                }
  { Cas general (int[], boolean[], String[]) :       }
  {   MOV [EBX + 4 + ECX*4], EAX                    }
  { Cas char[] :                                     }
  {   MOV BYTE [EBX + 4 + ECX], AL                   }
End;

{ ------------------------------------------------------------ }
{ EmitArrayLength : emettre le code pour tab.length              }
{   EBX = ptr tableau                                            }
{   MOV EAX, [EBX]  (le compteur est en tete de tableau)        }
{ ------------------------------------------------------------ }

Function EmitArrayLength(ArrTIdx : Integer) : TExprVal;
Begin
  Inc(ArLengthCount);
  ArLastKind     := AR_LENGTH;
  ArCurArrayType := ArrTIdx;
  { Code generation :                                }
  { MOV EAX, [EBX]          (length en offset 0)    }
  EmitArrayLength := ExprMakeEAX(TY_IDX_INT);
End;

{ ------------------------------------------------------------ }
{ EmitBoundsCheck : emettre le code de verification des bornes   }
{   CMP EAX, [EBX]   (index vs length)                          }
{   JAE _JRT_BOUNDS_ERR                                          }
{ ------------------------------------------------------------ }

Procedure EmitBoundsCheck;
Begin
  Inc(ArBoundsChkCount);
  ArLastKind := AR_BOUNDS_CHK;
  { Code generation :                                }
  { CMP EAX, [EBX]          (index >= length ?)     }
  { JAE _JRT_BOUNDS_ERR                              }
  { (saute vers routine d erreur si hors bornes)     }
End;

{ ------------------------------------------------------------ }
{ ArParseArrayDecl : parser une declaration de tableau           }
{   int[] tab = new int[n];   ou   int[] tab = (10, 20);        }
{   VarName = nom, ElemTIdx = type des elements                  }
{ ------------------------------------------------------------ }

Procedure ArParseArrayDecl(VarName : TString; ElemTIdx : Integer;
                           IsNew : Boolean; Size : LongInt;
                           IsStatic : Boolean);
Begin
  ArCurVarName := VarName;
  RegisterArray(VarName, ElemTIdx, Size, IsStatic);
  If IsNew Then
  Begin
    { int[] tab = new int[n]; }
    EmitArrayAlloc(ElemTIdx, ExprMakeImm(Size, TY_IDX_INT));
  End
  Else
  Begin
    { int[] tab = (10, 20, 30); init-liste }
    EmitArrayInitList(ElemTIdx, Size);
  End;
End;

{ ------------------------------------------------------------ }
{ ArParseArrayAccess : parser un acces a un element de tableau   }
{   tab[i] en lecture -> retourne TExprVal                       }
{ ------------------------------------------------------------ }

Function ArParseArrayAccess(ArrTIdx : Integer) : TExprVal;
Begin
  { Code generation :                                }
  { EBX = adresse du tableau (deja chargee)          }
  { EAX = index (deja evalue)                        }
  { Verification optionnelle des bornes              }
  ArParseArrayAccess := EmitArrayLoad(ArrTIdx);
End;

{ ------------------------------------------------------------ }
{ ArParseArrayAssign : parser une affectation a un element        }
{   tab[i] = val                                                 }
{ ------------------------------------------------------------ }

Procedure ArParseArrayAssign(ArrTIdx : Integer);
Begin
  { Code generation :                                }
  { EBX = adresse du tableau                         }
  { ECX = index                                      }
  { EAX = valeur a stocker                           }
  EmitArrayStore(ArrTIdx);
End;

{ ------------------------------------------------------------ }
{ ArParseArrayLength : parser tab.length                         }
{   -> retourne TExprVal (int)                                   }
{ ------------------------------------------------------------ }

Function ArParseArrayLength(ArrTIdx : Integer) : TExprVal;
Begin
  { Code generation :                                }
  { EBX = adresse du tableau (deja chargee)          }
  { MOV EAX, [EBX]                                  }
  ArParseArrayLength := EmitArrayLength(ArrTIdx);
End;

{ ------------------------------------------------------------ }
{ EmitArrayForEach : emettre le code pour enhanced for            }
{   for (int x : tab) corps de boucle                            }
{   Boucle de 0 a length-1 sur les elements                     }
{ ------------------------------------------------------------ }

Procedure EmitArrayForEach(ArrTIdx : Integer);
Begin
  Inc(ArForEachCount);
  ArLastKind     := AR_FOREACH;
  ArCurArrayType := ArrTIdx;
  { Code generation :                                }
  { MOV ECX, 0             (index = 0)               }
  { lbl_test:                                        }
  { CMP ECX, [EBX]         (index < length ?)        }
  { JGE lbl_end                                      }
  { MOV EAX, [EBX+4+ECX*4] (charger element)        }
  { ... corps de la boucle ...                       }
  { INC ECX                                          }
  { JMP lbl_test                                     }
  { lbl_end:                                         }
End;

{ ------------------------------------------------------------ }
{ EmitArrayParamPass : emettre le code pour passer un tableau     }
{   en parametre (par reference = pousser le pointeur)           }
{ ------------------------------------------------------------ }

Procedure EmitArrayParamPass;
Begin
  ArLastKind := AR_PARAM_PASS;
  { Code generation :                                }
  { PUSH EBX             (pointeur du tableau)       }
  { Le tableau est passe par reference naturellement }
End;

{ ------------------------------------------------------------ }
{ FindArrayByName : trouver un tableau par son nom                }
{   Retourne l index (1..ArArrayCount) ou 0 si non trouve        }
{ ------------------------------------------------------------ }

Function FindArrayByName(Name : TString) : Integer;
Var I : Integer;
Begin
  FindArrayByName := 0;
  For I := 1 To ArArrayCount Do
    If ArArrays[I].VarName = Name Then
    Begin
      FindArrayByName := I;
      Exit;
    End;
End;

{ ------------------------------------------------------------ }
{ GetArrayElemType : retourner le type d element d un tableau     }
{   enregistre (par son index)                                   }
{ ------------------------------------------------------------ }

Function GetArrayElemType(ArrIdx : Integer) : Integer;
Begin
  If (ArrIdx >= 1) And (ArrIdx <= ArArrayCount) Then
    GetArrayElemType := ArArrays[ArrIdx].ElemType
  Else
    GetArrayElemType := TY_IDX_INT;
End;

{ ------------------------------------------------------------ }
{ DumpArState : afficher l etat du sous-systeme tableaux          }
{ ------------------------------------------------------------ }

Procedure DumpArState;
Var I : Integer;
Begin
  WriteLn('--- Array State ---');
  WriteLn('  ArInitialized    : ', ArInitialized);
  WriteLn('  ArDeclCount      : ', ArDeclCount);
  WriteLn('  ArNewCount       : ', ArNewCount);
  WriteLn('  ArInitListCount  : ', ArInitListCount);
  WriteLn('  ArLoadCount      : ', ArLoadCount);
  WriteLn('  ArStoreCount     : ', ArStoreCount);
  WriteLn('  ArLengthCount    : ', ArLengthCount);
  WriteLn('  ArBoundsChkCount : ', ArBoundsChkCount);
  WriteLn('  ArForEachCount   : ', ArForEachCount);
  WriteLn('  ArLastKind       : ', ArTypeName(ArLastKind));
  WriteLn('  ArLabelSeq       : ', ArLabelSeq);
  WriteLn('  ArCurElemType    : ', ArCurElemType);
  WriteLn('  ArCurArrayType   : ', ArCurArrayType);
  WriteLn('  ArCurVarName     : ', ArCurVarName);
  WriteLn('  ArArrayCount     : ', ArArrayCount);
  If ArArrayCount > 0 Then
    For I := 1 To ArArrayCount Do
      WriteLn('    Array[', I, '] : ', ArArrays[I].VarName,
              ' elemType=', ArArrays[I].ElemType,
              ' size=', ArArrays[I].Size,
              ' (line ', ArArrays[I].DeclLine, ')');
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 14)                              }
{ ------------------------------------------------------------ }

Function IsArInitialized : Boolean;
Begin
  IsArInitialized := ArInitialized;
End;

Function IsArEmpty : Boolean;
Begin
  IsArEmpty := (ArDeclCount = 0) And (ArLoadCount = 0) And
               (ArStoreCount = 0) And (ArLengthCount = 0) And
               (ArForEachCount = 0);
End;

Function GetArDeclCount : LongInt;
Begin
  GetArDeclCount := ArDeclCount;
End;

Function GetArNewCount : LongInt;
Begin
  GetArNewCount := ArNewCount;
End;

Function GetArInitListCount : LongInt;
Begin
  GetArInitListCount := ArInitListCount;
End;

Function GetArLoadCount : LongInt;
Begin
  GetArLoadCount := ArLoadCount;
End;

Function GetArStoreCount : LongInt;
Begin
  GetArStoreCount := ArStoreCount;
End;

Function GetArLengthCount : LongInt;
Begin
  GetArLengthCount := ArLengthCount;
End;

Function GetArArrayCount : Integer;
Begin
  GetArArrayCount := ArArrayCount;
End;

Function GetArStatus : TString;
Begin
  If Not ArInitialized Then
    GetArStatus := 'Not initialized'
  Else
    GetArStatus := ItoS(ArDeclCount) + ' decl, ' +
                   ItoS(ArNewCount) + ' new, ' +
                   ItoS(ArInitListCount) + ' init-list, ' +
                   ItoS(ArLoadCount) + ' load, ' +
                   ItoS(ArStoreCount) + ' store, ' +
                   ItoS(ArLengthCount) + ' length, ' +
                   ItoS(ArBoundsChkCount) + ' bounds-chk, ' +
                   ItoS(ArForEachCount) + ' for-each';
End;

{ ============================================================ }
{ TODO 15 - PARSEUR : CHAINES (String) OPERATIONS              }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { Types d operations sur les chaines }
  ST_NONE          = 0;    { aucun / non defini                    }
  ST_CONCAT        = 1;    { s1 + s2 concatenation                 }
  ST_CONCAT_MIXED  = 2;    { "texte" + n concatenation mixte       }
  ST_LENGTH        = 3;    { s.length()                            }
  ST_CHARAT        = 4;    { s.charAt(i)                           }
  ST_EQUALS        = 5;    { s.equals(t)                           }
  ST_COMPARETO     = 6;    { s.compareTo(t)                        }
  ST_SUBSTRING     = 7;    { s.substring(begin, end)               }
  ST_INDEXOF       = 8;    { s.indexOf(sub)                        }
  ST_TOUPPER       = 9;    { s.toUpperCase()                       }
  ST_TOLOWER       = 10;   { s.toLowerCase()                       }
  ST_TRIM          = 11;   { s.trim()                              }
  ST_CONTAINS      = 12;   { s.contains(sub)                       }
  ST_STARTSWITH    = 13;   { s.startsWith(prefix)                  }
  ST_ENDSWITH      = 14;   { s.endsWith(suffix)                    }
  ST_REPLACE       = 15;   { s.replace(old, new)                   }
  ST_VALUEOF       = 16;   { String.valueOf(n)                     }
  ST_REF_EQ        = 17;   { == compare les references             }
  ST_MAX           = 17;

  { Limites }
  ST_MAX_CONCAT_PARTS = 16;  { nombre max de parties dans une concat }

Var
  StInitialized     : Boolean;    { True si l etat est initialise       }
  StConcatCount     : LongInt;    { nombre de concatenations            }
  StMixedConcatCount: LongInt;    { nombre de concat mixtes             }
  StLengthCount     : LongInt;    { nombre d appels .length()           }
  StCharAtCount     : LongInt;    { nombre d appels .charAt()           }
  StEqualsCount     : LongInt;    { nombre d appels .equals()           }
  StCompareToCount  : LongInt;    { nombre d appels .compareTo()        }
  StSubstringCount  : LongInt;    { nombre d appels .substring()        }
  StIndexOfCount    : LongInt;    { nombre d appels .indexOf()          }
  StToUpperCount    : LongInt;    { nombre d appels .toUpperCase()      }
  StToLowerCount    : LongInt;    { nombre d appels .toLowerCase()      }
  StTrimCount       : LongInt;    { nombre d appels .trim()             }
  StContainsCount   : LongInt;    { nombre d appels .contains()         }
  StStartsWithCount : LongInt;    { nombre d appels .startsWith()       }
  StEndsWithCount   : LongInt;    { nombre d appels .endsWith()         }
  StReplaceCount    : LongInt;    { nombre d appels .replace()          }
  StValueOfCount    : LongInt;    { nombre d appels String.valueOf()    }
  StRefEqCount      : LongInt;    { nombre de comparaisons ==           }
  StLastKind        : Integer;    { dernier type d operation            }
  StLabelSeq        : Integer;    { sequence pour labels ST             }

{ ------------------------------------------------------------ }
{ InitStState : initialiser le sous-systeme chaines               }
{ ------------------------------------------------------------ }

Procedure InitStState;
Begin
  StInitialized     := True;
  StConcatCount     := 0;
  StMixedConcatCount:= 0;
  StLengthCount     := 0;
  StCharAtCount     := 0;
  StEqualsCount     := 0;
  StCompareToCount  := 0;
  StSubstringCount  := 0;
  StIndexOfCount    := 0;
  StToUpperCount    := 0;
  StToLowerCount    := 0;
  StTrimCount       := 0;
  StContainsCount   := 0;
  StStartsWithCount := 0;
  StEndsWithCount   := 0;
  StReplaceCount    := 0;
  StValueOfCount    := 0;
  StRefEqCount      := 0;
  StLastKind        := ST_NONE;
  StLabelSeq        := 0;
End;

{ ------------------------------------------------------------ }
{ GenStLabel : generer un label unique pour les chaines           }
{ ------------------------------------------------------------ }

Function GenStLabel : TString;
Begin
  Inc(StLabelSeq);
  GenStLabel := JV_LBL_PFX + 'ST_' + ItoS(StLabelSeq);
End;

{ ------------------------------------------------------------ }
{ StTypeName : retourner le nom du type d operation chaine        }
{ ------------------------------------------------------------ }

Function StTypeName(K : Integer) : TString;
Begin
  Case K Of
    ST_NONE         : StTypeName := 'ST_NONE';
    ST_CONCAT       : StTypeName := 'ST_CONCAT';
    ST_CONCAT_MIXED : StTypeName := 'ST_CONCAT_MIXED';
    ST_LENGTH       : StTypeName := 'ST_LENGTH';
    ST_CHARAT       : StTypeName := 'ST_CHARAT';
    ST_EQUALS       : StTypeName := 'ST_EQUALS';
    ST_COMPARETO    : StTypeName := 'ST_COMPARETO';
    ST_SUBSTRING    : StTypeName := 'ST_SUBSTRING';
    ST_INDEXOF      : StTypeName := 'ST_INDEXOF';
    ST_TOUPPER      : StTypeName := 'ST_TOUPPER';
    ST_TOLOWER      : StTypeName := 'ST_TOLOWER';
    ST_TRIM         : StTypeName := 'ST_TRIM';
    ST_CONTAINS     : StTypeName := 'ST_CONTAINS';
    ST_STARTSWITH   : StTypeName := 'ST_STARTSWITH';
    ST_ENDSWITH     : StTypeName := 'ST_ENDSWITH';
    ST_REPLACE      : StTypeName := 'ST_REPLACE';
    ST_VALUEOF      : StTypeName := 'ST_VALUEOF';
    ST_REF_EQ       : StTypeName := 'ST_REF_EQ';
  Else
    StTypeName := 'ST_UNKNOWN(' + ItoS(K) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ EmitStrConcat : emettre le code pour s1 + s2                    }
{   ESI = ptr chaine gauche, EDI = ptr chaine droite             }
{   PUSH EDI / PUSH ESI / CALL _JRT_STRCONCAT                   }
{   ADD ESP, 8 -> EAX = ptr nouvelle chaine                      }
{ ------------------------------------------------------------ }

Function EmitStrConcat(LeftTIdx, RightTIdx : Integer) : TExprVal;
Begin
  Inc(StConcatCount);
  StLastKind := ST_CONCAT;
  { Code generation :                                }
  { PUSH EDI             (chaine droite)             }
  { PUSH ESI             (chaine gauche)             }
  { CALL _JRT_STRCONCAT                              }
  { ADD ESP, 8                                       }
  { -> EAX = ptr vers la nouvelle chaine concatenee  }
  EmitStrConcat := ExprMakeEAX(TY_IDX_STRING);
End;

{ ------------------------------------------------------------ }
{ EmitStrConcatMixed : emettre le code pour "texte" + n           }
{   Convertir n en chaine via _JRT_ITOA puis concatener          }
{   PUSH EAX / CALL _JRT_ITOA / ADD ESP,4 -> EAX=ptr str       }
{   Puis CALL _JRT_STRCONCAT                                    }
{ ------------------------------------------------------------ }

Function EmitStrConcatMixed(StrTIdx, ValTIdx : Integer) : TExprVal;
Begin
  Inc(StMixedConcatCount);
  StLastKind := ST_CONCAT_MIXED;
  { Code generation :                                }
  { Si ValTIdx = TY_IDX_INT :                        }
  {   PUSH EAX            (valeur entiere)           }
  {   CALL _JRT_ITOA                                 }
  {   ADD ESP, 4          -> EAX = ptr chaine        }
  { Si ValTIdx = TY_IDX_BOOLEAN :                    }
  {   PUSH EAX            (0 ou 1)                   }
  {   CALL _JRT_BTOA                                 }
  {   ADD ESP, 4          -> EAX = ptr chaine        }
  { Si ValTIdx = TY_IDX_CHAR :                       }
  {   PUSH EAX            (caractere)                }
  {   CALL _JRT_CTOA                                 }
  {   ADD ESP, 4          -> EAX = ptr chaine        }
  { Puis concatener avec _JRT_STRCONCAT              }
  EmitStrConcatMixed := ExprMakeEAX(TY_IDX_STRING);
End;

{ ------------------------------------------------------------ }
{ EmitStrLength : emettre le code pour s.length()                 }
{   ESI = ptr chaine                                             }
{   PUSH ESI / CALL _JRT_STRLEN / ADD ESP,4 -> EAX              }
{ ------------------------------------------------------------ }

Function EmitStrLength : TExprVal;
Begin
  Inc(StLengthCount);
  StLastKind := ST_LENGTH;
  { Code generation :                                }
  { PUSH ESI             (ptr chaine)                }
  { CALL _JRT_STRLEN                                 }
  { ADD ESP, 4                                       }
  { -> EAX = longueur de la chaine                   }
  EmitStrLength := ExprMakeEAX(TY_IDX_INT);
End;

{ ------------------------------------------------------------ }
{ EmitStrCharAt : emettre le code pour s.charAt(i)                }
{   ESI = ptr chaine, EAX = index                                }
{   MOVZX EAX, BYTE [ESI+EAX] -> EAX = caractere               }
{ ------------------------------------------------------------ }

Function EmitStrCharAt : TExprVal;
Begin
  Inc(StCharAtCount);
  StLastKind := ST_CHARAT;
  { Code generation :                                }
  { ESI = ptr chaine (deja charge)                   }
  { EAX = index (deja evalue)                        }
  { MOVZX EAX, BYTE [ESI+EAX]                       }
  { -> EAX = caractere a la position i               }
  EmitStrCharAt := ExprMakeEAX(TY_IDX_CHAR);
End;

{ ------------------------------------------------------------ }
{ EmitStrEquals : emettre le code pour s.equals(t)                }
{   ESI = ptr s, EDI = ptr t                                     }
{   PUSH EDI / PUSH ESI / CALL _JRT_STRCMP / ADD ESP,8           }
{   TEST EAX, EAX / SETE AL / MOVZX EAX, AL -> EAX=0|1         }
{ ------------------------------------------------------------ }

Function EmitStrEquals : TExprVal;
Begin
  Inc(StEqualsCount);
  StLastKind := ST_EQUALS;
  { Code generation :                                }
  { PUSH EDI             (chaine t)                  }
  { PUSH ESI             (chaine s)                  }
  { CALL _JRT_STRCMP                                 }
  { ADD ESP, 8                                       }
  { TEST EAX, EAX        (resultat == 0 ?)          }
  { SETE AL                                          }
  { MOVZX EAX, AL        -> EAX = 0 ou 1            }
  EmitStrEquals := ExprMakeEAX(TY_IDX_BOOLEAN);
End;

{ ------------------------------------------------------------ }
{ EmitStrCompareTo : emettre le code pour s.compareTo(t)          }
{   ESI = ptr s, EDI = ptr t                                     }
{   PUSH EDI / PUSH ESI / CALL _JRT_STRCMP / ADD ESP,8           }
{   -> EAX = -1 | 0 | 1                                         }
{ ------------------------------------------------------------ }

Function EmitStrCompareTo : TExprVal;
Begin
  Inc(StCompareToCount);
  StLastKind := ST_COMPARETO;
  { Code generation :                                }
  { PUSH EDI             (chaine t)                  }
  { PUSH ESI             (chaine s)                  }
  { CALL _JRT_STRCMP                                 }
  { ADD ESP, 8                                       }
  { -> EAX = -1, 0, ou 1                            }
  EmitStrCompareTo := ExprMakeEAX(TY_IDX_INT);
End;

{ ------------------------------------------------------------ }
{ EmitStrSubstring : emettre le code pour s.substring(begin,end)  }
{   ESI = ptr s, EAX = begin, EDX = end                          }
{   PUSH EDX / PUSH EAX / PUSH ESI                              }
{   CALL _JRT_STRSLICE / ADD ESP,12 -> EAX=ptr                  }
{ ------------------------------------------------------------ }

Function EmitStrSubstring : TExprVal;
Begin
  Inc(StSubstringCount);
  StLastKind := ST_SUBSTRING;
  { Code generation :                                }
  { PUSH EDX             (end)                       }
  { PUSH EAX             (begin)                     }
  { PUSH ESI             (ptr chaine)                }
  { CALL _JRT_STRSLICE                               }
  { ADD ESP, 12                                      }
  { -> EAX = ptr vers la sous-chaine                 }
  EmitStrSubstring := ExprMakeEAX(TY_IDX_STRING);
End;

{ ------------------------------------------------------------ }
{ EmitStrIndexOf : emettre le code pour s.indexOf(sub)            }
{   ESI = ptr s, EDI = ptr sub                                   }
{   PUSH EDI / PUSH ESI / CALL _JRT_STRFIND / ADD ESP,8         }
{   -> EAX = index ou -1                                         }
{ ------------------------------------------------------------ }

Function EmitStrIndexOf : TExprVal;
Begin
  Inc(StIndexOfCount);
  StLastKind := ST_INDEXOF;
  { Code generation :                                }
  { PUSH EDI             (sous-chaine)               }
  { PUSH ESI             (chaine s)                  }
  { CALL _JRT_STRFIND                                }
  { ADD ESP, 8                                       }
  { -> EAX = index de la premiere occurrence ou -1   }
  EmitStrIndexOf := ExprMakeEAX(TY_IDX_INT);
End;

{ ------------------------------------------------------------ }
{ EmitStrToUpper : emettre le code pour s.toUpperCase()           }
{   ESI = ptr s                                                  }
{   PUSH ESI / CALL _JRT_STRUPPER / ADD ESP,4 -> EAX=ptr        }
{ ------------------------------------------------------------ }

Function EmitStrToUpper : TExprVal;
Begin
  Inc(StToUpperCount);
  StLastKind := ST_TOUPPER;
  { Code generation :                                }
  { PUSH ESI             (ptr chaine)                }
  { CALL _JRT_STRUPPER                               }
  { ADD ESP, 4                                       }
  { -> EAX = ptr vers la chaine en majuscules        }
  EmitStrToUpper := ExprMakeEAX(TY_IDX_STRING);
End;

{ ------------------------------------------------------------ }
{ EmitStrToLower : emettre le code pour s.toLowerCase()           }
{   ESI = ptr s                                                  }
{   PUSH ESI / CALL _JRT_STRLOWER / ADD ESP,4 -> EAX=ptr        }
{ ------------------------------------------------------------ }

Function EmitStrToLower : TExprVal;
Begin
  Inc(StToLowerCount);
  StLastKind := ST_TOLOWER;
  { Code generation :                                }
  { PUSH ESI             (ptr chaine)                }
  { CALL _JRT_STRLOWER                               }
  { ADD ESP, 4                                       }
  { -> EAX = ptr vers la chaine en minuscules        }
  EmitStrToLower := ExprMakeEAX(TY_IDX_STRING);
End;

{ ------------------------------------------------------------ }
{ EmitStrTrim : emettre le code pour s.trim()                     }
{   ESI = ptr s                                                  }
{   PUSH ESI / CALL _JRT_STRTRIM / ADD ESP,4 -> EAX=ptr         }
{ ------------------------------------------------------------ }

Function EmitStrTrim : TExprVal;
Begin
  Inc(StTrimCount);
  StLastKind := ST_TRIM;
  { Code generation :                                }
  { PUSH ESI             (ptr chaine)                }
  { CALL _JRT_STRTRIM                                }
  { ADD ESP, 4                                       }
  { -> EAX = ptr vers la chaine sans espaces         }
  EmitStrTrim := ExprMakeEAX(TY_IDX_STRING);
End;

{ ------------------------------------------------------------ }
{ EmitStrContains : emettre le code pour s.contains(sub)          }
{   ESI = ptr s, EDI = ptr sub                                   }
{   PUSH EDI / PUSH ESI / CALL _JRT_STRCONTAINS / ADD ESP,8     }
{   -> EAX = 0 ou 1                                             }
{ ------------------------------------------------------------ }

Function EmitStrContains : TExprVal;
Begin
  Inc(StContainsCount);
  StLastKind := ST_CONTAINS;
  { Code generation :                                }
  { PUSH EDI             (sous-chaine)               }
  { PUSH ESI             (chaine s)                  }
  { CALL _JRT_STRCONTAINS                            }
  { ADD ESP, 8                                       }
  { -> EAX = 1 si contient, 0 sinon                 }
  EmitStrContains := ExprMakeEAX(TY_IDX_BOOLEAN);
End;

{ ------------------------------------------------------------ }
{ EmitStrStartsWith : emettre le code pour s.startsWith(prefix)   }
{   ESI = ptr s, EDI = ptr prefix                                }
{   PUSH EDI / PUSH ESI / CALL _JRT_STRSTARTSWITH / ADD ESP,8   }
{   -> EAX = 0 ou 1                                             }
{ ------------------------------------------------------------ }

Function EmitStrStartsWith : TExprVal;
Begin
  Inc(StStartsWithCount);
  StLastKind := ST_STARTSWITH;
  { Code generation :                                }
  { PUSH EDI             (prefix)                    }
  { PUSH ESI             (chaine s)                  }
  { CALL _JRT_STRSTARTSWITH                          }
  { ADD ESP, 8                                       }
  { -> EAX = 1 si commence par prefix, 0 sinon      }
  EmitStrStartsWith := ExprMakeEAX(TY_IDX_BOOLEAN);
End;

{ ------------------------------------------------------------ }
{ EmitStrEndsWith : emettre le code pour s.endsWith(suffix)       }
{   ESI = ptr s, EDI = ptr suffix                                }
{   PUSH EDI / PUSH ESI / CALL _JRT_STRENDSWITH / ADD ESP,8     }
{   -> EAX = 0 ou 1                                             }
{ ------------------------------------------------------------ }

Function EmitStrEndsWith : TExprVal;
Begin
  Inc(StEndsWithCount);
  StLastKind := ST_ENDSWITH;
  { Code generation :                                }
  { PUSH EDI             (suffix)                    }
  { PUSH ESI             (chaine s)                  }
  { CALL _JRT_STRENDSWITH                            }
  { ADD ESP, 8                                       }
  { -> EAX = 1 si termine par suffix, 0 sinon        }
  EmitStrEndsWith := ExprMakeEAX(TY_IDX_BOOLEAN);
End;

{ ------------------------------------------------------------ }
{ EmitStrReplace : emettre le code pour s.replace(old, new)       }
{   ESI = ptr s, EDI = ptr old, EDX = ptr new                   }
{   PUSH EDX / PUSH EDI / PUSH ESI                              }
{   CALL _JRT_STRREPLACE / ADD ESP,12 -> EAX=ptr                }
{ ------------------------------------------------------------ }

Function EmitStrReplace : TExprVal;
Begin
  Inc(StReplaceCount);
  StLastKind := ST_REPLACE;
  { Code generation :                                }
  { PUSH EDX             (nouvelle chaine)           }
  { PUSH EDI             (ancienne sous-chaine)      }
  { PUSH ESI             (chaine s)                  }
  { CALL _JRT_STRREPLACE                             }
  { ADD ESP, 12                                      }
  { -> EAX = ptr vers la chaine modifiee             }
  EmitStrReplace := ExprMakeEAX(TY_IDX_STRING);
End;

{ ------------------------------------------------------------ }
{ EmitStrValueOf : emettre le code pour String.valueOf(n)          }
{   EAX = valeur entiere                                         }
{   PUSH EAX / CALL _JRT_ITOA / ADD ESP,4 -> EAX=ptr            }
{ ------------------------------------------------------------ }

Function EmitStrValueOf(ValTIdx : Integer) : TExprVal;
Begin
  Inc(StValueOfCount);
  StLastKind := ST_VALUEOF;
  { Code generation :                                }
  { PUSH EAX             (valeur a convertir)        }
  { Si ValTIdx = TY_IDX_INT :                        }
  {   CALL _JRT_ITOA                                 }
  { Si ValTIdx = TY_IDX_BOOLEAN :                    }
  {   CALL _JRT_BTOA                                 }
  { Si ValTIdx = TY_IDX_CHAR :                       }
  {   CALL _JRT_CTOA                                 }
  { ADD ESP, 4                                       }
  { -> EAX = ptr vers la chaine resultante           }
  EmitStrValueOf := ExprMakeEAX(TY_IDX_STRING);
End;

{ ------------------------------------------------------------ }
{ EmitStrRefEqual : emettre le code pour s == t (reference)       }
{   CMP ESI, EDI -> EAX=0|1 (compare les pointeurs)             }
{ ------------------------------------------------------------ }

Function EmitStrRefEqual : TExprVal;
Begin
  Inc(StRefEqCount);
  StLastKind := ST_REF_EQ;
  { Code generation :                                }
  { CMP ESI, EDI         (comparer les pointeurs)    }
  { SETE AL                                          }
  { MOVZX EAX, AL        -> EAX = 0 ou 1            }
  EmitStrRefEqual := ExprMakeEAX(TY_IDX_BOOLEAN);
End;

{ ------------------------------------------------------------ }
{ ParseStrMethodCall : parser un appel de methode String          }
{   Reconnait : length, charAt, equals, compareTo, substring,   }
{   indexOf, toUpperCase, toLowerCase, trim, contains,           }
{   startsWith, endsWith, replace                                }
{   Retourne un TExprVal selon le type de retour                 }
{ ------------------------------------------------------------ }

Function ParseStrMethodCall(MethodName : TString) : TExprVal;
Begin
  If MethodName = 'length' Then
    ParseStrMethodCall := EmitStrLength
  Else If MethodName = 'charAt' Then
    ParseStrMethodCall := EmitStrCharAt
  Else If MethodName = 'equals' Then
    ParseStrMethodCall := EmitStrEquals
  Else If MethodName = 'compareTo' Then
    ParseStrMethodCall := EmitStrCompareTo
  Else If MethodName = 'substring' Then
    ParseStrMethodCall := EmitStrSubstring
  Else If MethodName = 'indexOf' Then
    ParseStrMethodCall := EmitStrIndexOf
  Else If MethodName = 'toUpperCase' Then
    ParseStrMethodCall := EmitStrToUpper
  Else If MethodName = 'toLowerCase' Then
    ParseStrMethodCall := EmitStrToLower
  Else If MethodName = 'trim' Then
    ParseStrMethodCall := EmitStrTrim
  Else If MethodName = 'contains' Then
    ParseStrMethodCall := EmitStrContains
  Else If MethodName = 'startsWith' Then
    ParseStrMethodCall := EmitStrStartsWith
  Else If MethodName = 'endsWith' Then
    ParseStrMethodCall := EmitStrEndsWith
  Else If MethodName = 'replace' Then
    ParseStrMethodCall := EmitStrReplace
  Else
    ParseStrMethodCall := ExprMakeEAX(TY_IDX_STRING);
End;

{ ------------------------------------------------------------ }
{ ParseStrStaticCall : parser un appel statique String.xxx()      }
{   Reconnait : String.valueOf(n)                                }
{   Retourne un TExprVal (String)                                }
{ ------------------------------------------------------------ }

Function ParseStrStaticCall(MethodName : TString;
                            ValTIdx : Integer) : TExprVal;
Begin
  If MethodName = 'valueOf' Then
    ParseStrStaticCall := EmitStrValueOf(ValTIdx)
  Else
    ParseStrStaticCall := ExprMakeEAX(TY_IDX_STRING);
End;

{ ------------------------------------------------------------ }
{ IsStrMethod : verifie si un nom est une methode String connue   }
{   Retourne True si c est une methode reconnue                  }
{ ------------------------------------------------------------ }

Function IsStrMethod(Name : TString) : Boolean;
Begin
  IsStrMethod := (Name = 'length') Or (Name = 'charAt') Or
                 (Name = 'equals') Or (Name = 'compareTo') Or
                 (Name = 'substring') Or (Name = 'indexOf') Or
                 (Name = 'toUpperCase') Or (Name = 'toLowerCase') Or
                 (Name = 'trim') Or (Name = 'contains') Or
                 (Name = 'startsWith') Or (Name = 'endsWith') Or
                 (Name = 'replace');
End;

{ ------------------------------------------------------------ }
{ IsStrStaticMethod : verifie si un nom est un appel statique     }
{   String.xxx() reconnu                                         }
{ ------------------------------------------------------------ }

Function IsStrStaticMethod(Name : TString) : Boolean;
Begin
  IsStrStaticMethod := (Name = 'valueOf');
End;

{ ------------------------------------------------------------ }
{ GetStrMethodReturnType : retourner le type de retour d une      }
{   methode String                                               }
{ ------------------------------------------------------------ }

Function GetStrMethodReturnType(Name : TString) : Integer;
Begin
  If (Name = 'length') Or (Name = 'compareTo') Or
     (Name = 'indexOf') Then
    GetStrMethodReturnType := TY_IDX_INT
  Else If Name = 'charAt' Then
    GetStrMethodReturnType := TY_IDX_CHAR
  Else If (Name = 'equals') Or (Name = 'contains') Or
          (Name = 'startsWith') Or (Name = 'endsWith') Then
    GetStrMethodReturnType := TY_IDX_BOOLEAN
  Else
    GetStrMethodReturnType := TY_IDX_STRING;
End;

{ ------------------------------------------------------------ }
{ GetStConcatTotal : retourner le total des concatenations        }
{ ------------------------------------------------------------ }

Function GetStConcatTotal : LongInt;
Begin
  GetStConcatTotal := StConcatCount + StMixedConcatCount;
End;

{ ------------------------------------------------------------ }
{ GetStMethodTotal : retourner le total des appels de methode     }
{ ------------------------------------------------------------ }

Function GetStMethodTotal : LongInt;
Begin
  GetStMethodTotal := StLengthCount + StCharAtCount +
                      StEqualsCount + StCompareToCount +
                      StSubstringCount + StIndexOfCount +
                      StToUpperCount + StToLowerCount +
                      StTrimCount + StContainsCount +
                      StStartsWithCount + StEndsWithCount +
                      StReplaceCount + StValueOfCount;
End;

{ ------------------------------------------------------------ }
{ DumpStState : afficher l etat du sous-systeme chaines           }
{ ------------------------------------------------------------ }

Procedure DumpStState;
Begin
  WriteLn('--- String State ---');
  WriteLn('  StInitialized      : ', StInitialized);
  WriteLn('  StConcatCount      : ', StConcatCount);
  WriteLn('  StMixedConcatCount : ', StMixedConcatCount);
  WriteLn('  StLengthCount      : ', StLengthCount);
  WriteLn('  StCharAtCount      : ', StCharAtCount);
  WriteLn('  StEqualsCount      : ', StEqualsCount);
  WriteLn('  StCompareToCount   : ', StCompareToCount);
  WriteLn('  StSubstringCount   : ', StSubstringCount);
  WriteLn('  StIndexOfCount     : ', StIndexOfCount);
  WriteLn('  StToUpperCount     : ', StToUpperCount);
  WriteLn('  StToLowerCount     : ', StToLowerCount);
  WriteLn('  StTrimCount        : ', StTrimCount);
  WriteLn('  StContainsCount    : ', StContainsCount);
  WriteLn('  StStartsWithCount  : ', StStartsWithCount);
  WriteLn('  StEndsWithCount    : ', StEndsWithCount);
  WriteLn('  StReplaceCount     : ', StReplaceCount);
  WriteLn('  StValueOfCount     : ', StValueOfCount);
  WriteLn('  StRefEqCount       : ', StRefEqCount);
  WriteLn('  StLastKind         : ', StTypeName(StLastKind));
  WriteLn('  StLabelSeq         : ', StLabelSeq);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 15)                              }
{ ------------------------------------------------------------ }

Function IsStInitialized : Boolean;
Begin
  IsStInitialized := StInitialized;
End;

Function IsStEmpty : Boolean;
Begin
  IsStEmpty := (StConcatCount = 0) And (StMixedConcatCount = 0) And
               (StLengthCount = 0) And (StCharAtCount = 0) And
               (StEqualsCount = 0) And (StCompareToCount = 0) And
               (StSubstringCount = 0) And (StIndexOfCount = 0) And
               (StToUpperCount = 0) And (StToLowerCount = 0) And
               (StTrimCount = 0) And (StContainsCount = 0) And
               (StStartsWithCount = 0) And (StEndsWithCount = 0) And
               (StReplaceCount = 0) And (StValueOfCount = 0) And
               (StRefEqCount = 0);
End;

Function GetStConcatCount : LongInt;
Begin
  GetStConcatCount := StConcatCount;
End;

Function GetStMixedConcatCount : LongInt;
Begin
  GetStMixedConcatCount := StMixedConcatCount;
End;

Function GetStLengthCount : LongInt;
Begin
  GetStLengthCount := StLengthCount;
End;

Function GetStEqualsCount : LongInt;
Begin
  GetStEqualsCount := StEqualsCount;
End;

Function GetStSubstringCount : LongInt;
Begin
  GetStSubstringCount := StSubstringCount;
End;

Function GetStIndexOfCount : LongInt;
Begin
  GetStIndexOfCount := StIndexOfCount;
End;

Function GetStValueOfCount : LongInt;
Begin
  GetStValueOfCount := StValueOfCount;
End;

Function GetStStatus : TString;
Begin
  If Not StInitialized Then
    GetStStatus := 'Not initialized'
  Else
    GetStStatus := ItoS(StConcatCount) + ' concat, ' +
                   ItoS(StMixedConcatCount) + ' mixed, ' +
                   ItoS(StLengthCount) + ' length, ' +
                   ItoS(StCharAtCount) + ' charAt, ' +
                   ItoS(StEqualsCount) + ' equals, ' +
                   ItoS(StCompareToCount) + ' compareTo, ' +
                   ItoS(StSubstringCount) + ' substring, ' +
                   ItoS(StIndexOfCount) + ' indexOf, ' +
                   ItoS(StReplaceCount) + ' replace, ' +
                   ItoS(StValueOfCount) + ' valueOf, ' +
                   ItoS(StRefEqCount) + ' ref-eq';
End;

{ ============================================================ }
{ TODO 16 - PARSEUR : CLASSES, OBJETS ET CONSTRUCTEURS         }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { Types d operations sur les classes et objets }
  CL_NONE          = 0;    { aucun / non defini                    }
  CL_CLASS_DECL    = 1;    { declaration de classe                  }
  CL_FIELD_DECL    = 2;    { declaration de champ d instance        }
  CL_STATIC_DECL   = 3;    { declaration de champ statique          }
  CL_METHOD_DECL   = 4;    { declaration de methode d instance      }
  CL_CTOR_DECL     = 5;    { declaration de constructeur            }
  CL_OBJ_ALLOC     = 6;    { new ClassName(args)                    }
  CL_FIELD_LOAD    = 7;    { this.field (lecture)                   }
  CL_FIELD_STORE   = 8;    { this.field = val (ecriture)            }
  CL_STATIC_LOAD   = 9;    { ClassName.field (lecture statique)     }
  CL_STATIC_STORE  = 10;   { ClassName.field = val (ecriture stat.) }
  CL_METHOD_CALL   = 11;   { obj.method(args)                      }
  CL_CTOR_CALL     = 12;   { appel constructeur                    }
  CL_SUPER_CALL    = 13;   { super(args)                           }
  CL_INSTANCEOF    = 14;   { obj instanceof ClassName               }
  CL_MAX           = 14;

  { Limites }
  CL_MAX_CLASSES   = 32;   { nombre max de classes declarees        }
  CL_MAX_FIELDS    = 32;   { nombre max de champs par classe        }
  CL_MAX_METHODS   = 32;   { nombre max de methodes par classe      }
  CL_OBJ_HDR_SIZE  = 4;    { taille du header objet (typecode DD)   }
  CL_FIELD_SIZE    = 4;    { taille d un champ (4 octets = DD)      }

Type
  TClFieldRec = Record
    Name       : TString;  { nom du champ                          }
    TypeIdx    : Integer;  { type du champ (TY_IDX_*)              }
    Offset     : Integer;  { offset dans l instance (en octets)    }
    IsStatic   : Boolean;  { True si champ statique                }
    IsFinal    : Boolean;  { True si final                         }
    IsPublic   : Boolean;  { True si public                        }
    DeclLine   : Integer;  { ligne de declaration                  }
  End;

  TClMethodRec = Record
    Name       : TString;  { nom de la methode                     }
    RetTypeIdx : Integer;  { type de retour (TY_IDX_*)             }
    ParamCount : Integer;  { nombre de parametres (sans this)       }
    IsStatic   : Boolean;  { True si methode statique              }
    IsCtor     : Boolean;  { True si constructeur                  }
    IsPublic   : Boolean;  { True si public                        }
    AsmLabel   : TString;  { label assembleur (_JM_Class_method)   }
    DeclLine   : Integer;  { ligne de declaration                  }
  End;

  TClClassRec = Record
    Name         : TString;  { nom de la classe                    }
    ParentIdx    : Integer;  { index du parent (-1 si aucun)       }
    TypeCode     : Integer;  { code de type unique pour instanceof }
    Fields       : Array[1..CL_MAX_FIELDS] Of TClFieldRec;
    FieldCount   : Integer;  { nombre de champs                    }
    Methods      : Array[1..CL_MAX_METHODS] Of TClMethodRec;
    MethodCount  : Integer;  { nombre de methodes                  }
    InstanceSize : Integer;  { taille de l instance en octets       }
    IsPublic     : Boolean;  { True si public                      }
    IsAbstract   : Boolean;  { True si abstract                    }
    DeclLine     : Integer;  { ligne de declaration                }
  End;

Var
  ClInitialized      : Boolean;    { True si l etat est initialise       }
  ClClassDeclCount   : LongInt;    { nombre de declarations de classes   }
  ClFieldDeclCount   : LongInt;    { nombre de declarations de champs    }
  ClStaticDeclCount  : LongInt;    { nombre de champs statiques          }
  ClMethodDeclCount  : LongInt;    { nombre de declarations de methodes  }
  ClCtorDeclCount    : LongInt;    { nombre de constructeurs declares    }
  ClObjAllocCount    : LongInt;    { nombre d allocations new            }
  ClFieldLoadCount   : LongInt;    { nombre de lectures de champs        }
  ClFieldStoreCount  : LongInt;    { nombre d ecritures de champs        }
  ClStaticLoadCount  : LongInt;    { nombre de lectures statiques        }
  ClStaticStoreCount : LongInt;    { nombre d ecritures statiques        }
  ClMethodCallCount  : LongInt;    { nombre d appels de methodes         }
  ClCtorCallCount    : LongInt;    { nombre d appels constructeurs       }
  ClSuperCallCount   : LongInt;    { nombre d appels super()             }
  ClInstanceOfCount  : LongInt;    { nombre de instanceof                }
  ClLastKind         : Integer;    { dernier type d operation            }
  ClLabelSeq         : Integer;    { sequence pour labels CL             }
  ClNextTypeCode     : Integer;    { prochain code de type a assigner    }
  ClClasses          : Array[1..CL_MAX_CLASSES] Of TClClassRec;
  ClClassCount       : Integer;    { nombre de classes enregistrees      }
  ClCurClassName     : TString;    { nom de la classe courante           }

{ ------------------------------------------------------------ }
{ InitClState : initialiser le sous-systeme classes              }
{ ------------------------------------------------------------ }

Procedure InitClState;
Var I, J : Integer;
Begin
  ClInitialized      := True;
  ClClassDeclCount   := 0;
  ClFieldDeclCount   := 0;
  ClStaticDeclCount  := 0;
  ClMethodDeclCount  := 0;
  ClCtorDeclCount    := 0;
  ClObjAllocCount    := 0;
  ClFieldLoadCount   := 0;
  ClFieldStoreCount  := 0;
  ClStaticLoadCount  := 0;
  ClStaticStoreCount := 0;
  ClMethodCallCount  := 0;
  ClCtorCallCount    := 0;
  ClSuperCallCount   := 0;
  ClInstanceOfCount  := 0;
  ClLastKind         := CL_NONE;
  ClLabelSeq         := 0;
  ClNextTypeCode     := 1;
  ClClassCount       := 0;
  ClCurClassName     := '';
  For I := 1 To CL_MAX_CLASSES Do
  Begin
    ClClasses[I].Name         := '';
    ClClasses[I].ParentIdx    := -1;
    ClClasses[I].TypeCode     := 0;
    ClClasses[I].FieldCount   := 0;
    ClClasses[I].MethodCount  := 0;
    ClClasses[I].InstanceSize := CL_OBJ_HDR_SIZE;
    ClClasses[I].IsPublic     := False;
    ClClasses[I].IsAbstract   := False;
    ClClasses[I].DeclLine     := 0;
    For J := 1 To CL_MAX_FIELDS Do
    Begin
      ClClasses[I].Fields[J].Name     := '';
      ClClasses[I].Fields[J].TypeIdx  := 0;
      ClClasses[I].Fields[J].Offset   := 0;
      ClClasses[I].Fields[J].IsStatic := False;
      ClClasses[I].Fields[J].IsFinal  := False;
      ClClasses[I].Fields[J].IsPublic := False;
      ClClasses[I].Fields[J].DeclLine := 0;
    End;
    For J := 1 To CL_MAX_METHODS Do
    Begin
      ClClasses[I].Methods[J].Name       := '';
      ClClasses[I].Methods[J].RetTypeIdx := 0;
      ClClasses[I].Methods[J].ParamCount := 0;
      ClClasses[I].Methods[J].IsStatic   := False;
      ClClasses[I].Methods[J].IsCtor     := False;
      ClClasses[I].Methods[J].IsPublic   := False;
      ClClasses[I].Methods[J].AsmLabel   := '';
      ClClasses[I].Methods[J].DeclLine   := 0;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ GenClLabel : generer un label unique pour les classes           }
{ ------------------------------------------------------------ }

Function GenClLabel : TString;
Begin
  Inc(ClLabelSeq);
  GenClLabel := JV_LBL_PFX + 'CL_' + ItoS(ClLabelSeq);
End;

{ ------------------------------------------------------------ }
{ ClTypeName : retourner le nom du type d operation classe        }
{ ------------------------------------------------------------ }

Function ClTypeName(K : Integer) : TString;
Begin
  Case K Of
    CL_NONE         : ClTypeName := 'CL_NONE';
    CL_CLASS_DECL   : ClTypeName := 'CL_CLASS_DECL';
    CL_FIELD_DECL   : ClTypeName := 'CL_FIELD_DECL';
    CL_STATIC_DECL  : ClTypeName := 'CL_STATIC_DECL';
    CL_METHOD_DECL  : ClTypeName := 'CL_METHOD_DECL';
    CL_CTOR_DECL    : ClTypeName := 'CL_CTOR_DECL';
    CL_OBJ_ALLOC    : ClTypeName := 'CL_OBJ_ALLOC';
    CL_FIELD_LOAD   : ClTypeName := 'CL_FIELD_LOAD';
    CL_FIELD_STORE  : ClTypeName := 'CL_FIELD_STORE';
    CL_STATIC_LOAD  : ClTypeName := 'CL_STATIC_LOAD';
    CL_STATIC_STORE : ClTypeName := 'CL_STATIC_STORE';
    CL_METHOD_CALL  : ClTypeName := 'CL_METHOD_CALL';
    CL_CTOR_CALL    : ClTypeName := 'CL_CTOR_CALL';
    CL_SUPER_CALL   : ClTypeName := 'CL_SUPER_CALL';
    CL_INSTANCEOF   : ClTypeName := 'CL_INSTANCEOF';
  Else
    ClTypeName := 'CL_UNKNOWN(' + ItoS(K) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ RegisterClass : enregistrer une nouvelle classe                 }
{   Retourne l index dans ClClasses (1-based) ou 0 si plein     }
{ ------------------------------------------------------------ }

Function RegisterClass(ClassName : TString; ParentIdx : Integer;
                       IsPubl, IsAbstr : Boolean;
                       Line : Integer) : Integer;
Var Idx : Integer;
Begin
  If ClClassCount >= CL_MAX_CLASSES Then
  Begin
    RegisterClass := 0;
    Exit;
  End;
  Inc(ClClassCount);
  Idx := ClClassCount;
  ClClasses[Idx].Name         := ClassName;
  ClClasses[Idx].ParentIdx    := ParentIdx;
  ClClasses[Idx].TypeCode     := ClNextTypeCode;
  Inc(ClNextTypeCode);
  ClClasses[Idx].FieldCount   := 0;
  ClClasses[Idx].MethodCount  := 0;
  ClClasses[Idx].IsPublic     := IsPubl;
  ClClasses[Idx].IsAbstract   := IsAbstr;
  ClClasses[Idx].DeclLine     := Line;
  { Si heritage, copier la taille d instance du parent }
  If (ParentIdx >= 1) And (ParentIdx <= ClClassCount - 1) Then
    ClClasses[Idx].InstanceSize := ClClasses[ParentIdx].InstanceSize
  Else
    ClClasses[Idx].InstanceSize := CL_OBJ_HDR_SIZE;
  Inc(ClClassDeclCount);
  ClLastKind := CL_CLASS_DECL;
  RegisterClass := Idx;
End;

{ ------------------------------------------------------------ }
{ RegisterField : enregistrer un champ dans une classe            }
{   ClassIdx = index de la classe (1-based)                      }
{   Retourne l index du champ (1-based) ou 0 si plein           }
{ ------------------------------------------------------------ }

Function RegisterField(ClassIdx : Integer; FieldName : TString;
                       TypeIdx : Integer; IsStaticF, IsFinalF,
                       IsPublicF : Boolean;
                       Line : Integer) : Integer;
Var FIdx : Integer;
Begin
  RegisterField := 0;
  If (ClassIdx < 1) Or (ClassIdx > ClClassCount) Then Exit;
  If ClClasses[ClassIdx].FieldCount >= CL_MAX_FIELDS Then Exit;
  Inc(ClClasses[ClassIdx].FieldCount);
  FIdx := ClClasses[ClassIdx].FieldCount;
  ClClasses[ClassIdx].Fields[FIdx].Name     := FieldName;
  ClClasses[ClassIdx].Fields[FIdx].TypeIdx  := TypeIdx;
  ClClasses[ClassIdx].Fields[FIdx].IsStatic := IsStaticF;
  ClClasses[ClassIdx].Fields[FIdx].IsFinal  := IsFinalF;
  ClClasses[ClassIdx].Fields[FIdx].IsPublic := IsPublicF;
  ClClasses[ClassIdx].Fields[FIdx].DeclLine := Line;
  If IsStaticF Then
  Begin
    { Champ statique : pas d offset dans l instance }
    ClClasses[ClassIdx].Fields[FIdx].Offset := -1;
    Inc(ClStaticDeclCount);
    ClLastKind := CL_STATIC_DECL;
  End
  Else
  Begin
    { Champ d instance : offset apres le header + champs existants }
    ClClasses[ClassIdx].Fields[FIdx].Offset :=
      ClClasses[ClassIdx].InstanceSize;
    Inc(ClClasses[ClassIdx].InstanceSize, CL_FIELD_SIZE);
    Inc(ClFieldDeclCount);
    ClLastKind := CL_FIELD_DECL;
  End;
  RegisterField := FIdx;
End;

{ ------------------------------------------------------------ }
{ RegisterMethod : enregistrer une methode dans une classe        }
{   ClassIdx = index de la classe (1-based)                      }
{   Retourne l index de la methode (1-based) ou 0 si plein      }
{ ------------------------------------------------------------ }

Function RegisterMethod(ClassIdx : Integer; MethodName : TString;
                        RetTypeIdx, ParamCnt : Integer;
                        IsStaticM, IsCtorM,
                        IsPublicM : Boolean;
                        Line : Integer) : Integer;
Var MIdx : Integer;
    Lbl  : TString;
Begin
  RegisterMethod := 0;
  If (ClassIdx < 1) Or (ClassIdx > ClClassCount) Then Exit;
  If ClClasses[ClassIdx].MethodCount >= CL_MAX_METHODS Then Exit;
  Inc(ClClasses[ClassIdx].MethodCount);
  MIdx := ClClasses[ClassIdx].MethodCount;
  ClClasses[ClassIdx].Methods[MIdx].Name       := MethodName;
  ClClasses[ClassIdx].Methods[MIdx].RetTypeIdx := RetTypeIdx;
  ClClasses[ClassIdx].Methods[MIdx].ParamCount := ParamCnt;
  ClClasses[ClassIdx].Methods[MIdx].IsStatic   := IsStaticM;
  ClClasses[ClassIdx].Methods[MIdx].IsCtor     := IsCtorM;
  ClClasses[ClassIdx].Methods[MIdx].IsPublic   := IsPublicM;
  ClClasses[ClassIdx].Methods[MIdx].DeclLine   := Line;
  { Generer le label assembleur }
  If IsCtorM Then
    Lbl := '_JM_' + ClClasses[ClassIdx].Name + '_init'
  Else
    Lbl := '_JM_' + ClClasses[ClassIdx].Name + '_' + MethodName;
  ClClasses[ClassIdx].Methods[MIdx].AsmLabel := Lbl;
  If IsCtorM Then
  Begin
    Inc(ClCtorDeclCount);
    ClLastKind := CL_CTOR_DECL;
  End
  Else
  Begin
    Inc(ClMethodDeclCount);
    ClLastKind := CL_METHOD_DECL;
  End;
  RegisterMethod := MIdx;
End;

{ ------------------------------------------------------------ }
{ EmitObjAlloc : emettre le code pour new ClassName(args)         }
{   ECX = taille de l instance                                   }
{   PUSH ECX / CALL _JRT_OBJNEW / ADD ESP,4 -> EAX=ptr          }
{   Ensuite initialiser le typecode :                            }
{   MOV DWORD [EAX], typecode                                   }
{ ------------------------------------------------------------ }

Function EmitObjAlloc(ClassIdx : Integer) : TExprVal;
Begin
  Inc(ClObjAllocCount);
  ClLastKind := CL_OBJ_ALLOC;
  { Code generation :                                }
  { MOV ECX, InstanceSize  (taille de l instance)    }
  { PUSH ECX                                         }
  { CALL _JRT_OBJNEW                                 }
  { ADD ESP, 4             -> EAX = ptr instance     }
  { MOV DWORD [EAX], TypeCode  (stocker le typecode) }
  EmitObjAlloc := ExprMakeEAX(TY_IDX_NULL);
End;

{ ------------------------------------------------------------ }
{ EmitCtorCall : emettre le code pour appeler un constructeur     }
{   PUSH this + PUSH args + CALL _JM_Class_init                 }
{   ADD ESP, (1+nargs)*4                                         }
{ ------------------------------------------------------------ }

Procedure EmitCtorCall(ClassIdx, CtorIdx : Integer);
Begin
  Inc(ClCtorCallCount);
  ClLastKind := CL_CTOR_CALL;
  { Code generation :                                }
  { PUSH EAX              (this = ptr instance)      }
  { PUSH arg1 ... PUSH argN  (arguments)             }
  { CALL _JM_ClassName_init                          }
  { ADD ESP, (1+nargs)*4                             }
End;

{ ------------------------------------------------------------ }
{ EmitFieldLoad : emettre le code pour this.field (lecture)        }
{   MOV EBX, [EBP+8]      (this)                                }
{   MOV EAX, [EBX+offset]                                       }
{ ------------------------------------------------------------ }

Function EmitFieldLoad(ClassIdx, FieldIdx : Integer) : TExprVal;
Var Off, TIdx : Integer;
Begin
  Inc(ClFieldLoadCount);
  ClLastKind := CL_FIELD_LOAD;
  Off  := ClClasses[ClassIdx].Fields[FieldIdx].Offset;
  TIdx := ClClasses[ClassIdx].Fields[FieldIdx].TypeIdx;
  { Code generation :                                }
  { MOV EBX, [EBP+8]      (ptr this)                }
  { MOV EAX, [EBX+Off]    (valeur du champ)         }
  EmitFieldLoad := ExprMakeEAX(TIdx);
End;

{ ------------------------------------------------------------ }
{ EmitFieldStore : emettre le code pour this.field = val           }
{   MOV EBX, [EBP+8]      (this)                                }
{   MOV [EBX+offset], EAX                                       }
{ ------------------------------------------------------------ }

Procedure EmitFieldStore(ClassIdx, FieldIdx : Integer);
Var Off : Integer;
Begin
  Inc(ClFieldStoreCount);
  ClLastKind := CL_FIELD_STORE;
  Off := ClClasses[ClassIdx].Fields[FieldIdx].Offset;
  { Code generation :                                }
  { MOV EBX, [EBP+8]      (ptr this)                }
  { MOV [EBX+Off], EAX    (stocker la valeur)       }
End;

{ ------------------------------------------------------------ }
{ EmitStaticFieldLoad : emettre le code pour ClassName.field       }
{   MOV EAX, [_JV_ClassName_field]                               }
{ ------------------------------------------------------------ }

Function EmitStaticFieldLoad(ClassIdx, FieldIdx : Integer) : TExprVal;
Var TIdx : Integer;
Begin
  Inc(ClStaticLoadCount);
  ClLastKind := CL_STATIC_LOAD;
  TIdx := ClClasses[ClassIdx].Fields[FieldIdx].TypeIdx;
  { Code generation :                                }
  { MOV EAX, [_JV_ClassName_field]                   }
  EmitStaticFieldLoad := ExprMakeEAX(TIdx);
End;

{ ------------------------------------------------------------ }
{ EmitStaticFieldStore : emettre le code pour ClassName.field=val  }
{   MOV [_JV_ClassName_field], EAX                               }
{ ------------------------------------------------------------ }

Procedure EmitStaticFieldStore(ClassIdx, FieldIdx : Integer);
Begin
  Inc(ClStaticStoreCount);
  ClLastKind := CL_STATIC_STORE;
  { Code generation :                                }
  { MOV [_JV_ClassName_field], EAX                   }
End;

{ ------------------------------------------------------------ }
{ EmitMethodCall : emettre le code pour obj.method(args)           }
{   PUSH this + PUSH args + CALL _JM_ClassName_method            }
{   ADD ESP, (1+nargs)*4 -> EAX = resultat                       }
{ ------------------------------------------------------------ }

Function EmitMethodCall(ClassIdx, MethodIdx : Integer) : TExprVal;
Var TIdx : Integer;
Begin
  Inc(ClMethodCallCount);
  ClLastKind := CL_METHOD_CALL;
  TIdx := ClClasses[ClassIdx].Methods[MethodIdx].RetTypeIdx;
  { Code generation :                                }
  { PUSH EBX              (this = ptr instance)      }
  { PUSH arg1 ... PUSH argN  (arguments)             }
  { CALL _JM_ClassName_method                        }
  { ADD ESP, (1+nargs)*4                             }
  { -> EAX = valeur de retour                        }
  EmitMethodCall := ExprMakeEAX(TIdx);
End;

{ ------------------------------------------------------------ }
{ EmitSuperCall : emettre le code pour super(args)                 }
{   PUSH this + PUSH args + CALL _JM_Parent_init                }
{   ADD ESP, (1+nargs)*4                                         }
{ ------------------------------------------------------------ }

Procedure EmitSuperCall(ClassIdx : Integer);
Var PIdx : Integer;
Begin
  Inc(ClSuperCallCount);
  ClLastKind := CL_SUPER_CALL;
  PIdx := ClClasses[ClassIdx].ParentIdx;
  { Code generation :                                }
  { PUSH EBX              (this = ptr instance)      }
  { Si PIdx >= 1 :                                   }
  {   CALL _JM_ParentName_init                       }
  {   ADD ESP, 4                                     }
End;

{ ------------------------------------------------------------ }
{ EmitInstanceOf : emettre le code pour obj instanceof ClassName   }
{   MOV EBX, ptr obj                                             }
{   MOV EAX, [EBX]        (lire le typecode)                    }
{   CMP EAX, TypeCode                                           }
{   SETE AL / MOVZX EAX, AL -> EAX=0|1                          }
{ ------------------------------------------------------------ }

Function EmitInstanceOf(ClassIdx : Integer) : TExprVal;
Begin
  Inc(ClInstanceOfCount);
  ClLastKind := CL_INSTANCEOF;
  { Code generation :                                }
  { MOV EBX, ptr_objet    (deja dans EBX ou EAX)    }
  { MOV EAX, [EBX]        (lire le typecode)        }
  { CMP EAX, TypeCode     (comparer)                }
  { SETE AL                                          }
  { MOVZX EAX, AL         -> EAX = 0 ou 1           }
  EmitInstanceOf := ExprMakeEAX(TY_IDX_BOOLEAN);
End;

{ ------------------------------------------------------------ }
{ FindClassByName : trouver une classe par son nom                 }
{   Retourne l index (1-based) ou 0 si non trouvee              }
{ ------------------------------------------------------------ }

Function FindClassByName(Name : TString) : Integer;
Var I : Integer;
Begin
  FindClassByName := 0;
  For I := 1 To ClClassCount Do
    If ClClasses[I].Name = Name Then
    Begin
      FindClassByName := I;
      Exit;
    End;
End;

{ ------------------------------------------------------------ }
{ FindFieldInClass : trouver un champ dans une classe              }
{   Retourne l index du champ (1-based) ou 0 si non trouve       }
{   Cherche aussi dans les classes parentes (heritage)            }
{ ------------------------------------------------------------ }

Function FindFieldInClass(ClassIdx : Integer;
                          FieldName : TString) : Integer;
Var I, PIdx : Integer;
Begin
  FindFieldInClass := 0;
  If (ClassIdx < 1) Or (ClassIdx > ClClassCount) Then Exit;
  { Chercher dans la classe courante }
  For I := 1 To ClClasses[ClassIdx].FieldCount Do
    If ClClasses[ClassIdx].Fields[I].Name = FieldName Then
    Begin
      FindFieldInClass := I;
      Exit;
    End;
  { Chercher dans la classe parente }
  PIdx := ClClasses[ClassIdx].ParentIdx;
  If (PIdx >= 1) And (PIdx <= ClClassCount) Then
    FindFieldInClass := FindFieldInClass(PIdx, FieldName);
End;

{ ------------------------------------------------------------ }
{ FindMethodInClass : trouver une methode dans une classe          }
{   Retourne l index de la methode (1-based) ou 0 si non trouvee }
{   Cherche aussi dans les classes parentes (heritage)            }
{ ------------------------------------------------------------ }

Function FindMethodInClass(ClassIdx : Integer;
                           MethodName : TString) : Integer;
Var I, PIdx : Integer;
Begin
  FindMethodInClass := 0;
  If (ClassIdx < 1) Or (ClassIdx > ClClassCount) Then Exit;
  { Chercher dans la classe courante }
  For I := 1 To ClClasses[ClassIdx].MethodCount Do
    If ClClasses[ClassIdx].Methods[I].Name = MethodName Then
    Begin
      FindMethodInClass := I;
      Exit;
    End;
  { Chercher dans la classe parente }
  PIdx := ClClasses[ClassIdx].ParentIdx;
  If (PIdx >= 1) And (PIdx <= ClClassCount) Then
    FindMethodInClass := FindMethodInClass(PIdx, MethodName);
End;

{ ------------------------------------------------------------ }
{ GetClassInstanceSize : retourner la taille d une instance        }
{   en octets (header + champs d instance)                       }
{ ------------------------------------------------------------ }

Function GetClassInstanceSize(ClassIdx : Integer) : Integer;
Begin
  If (ClassIdx >= 1) And (ClassIdx <= ClClassCount) Then
    GetClassInstanceSize := ClClasses[ClassIdx].InstanceSize
  Else
    GetClassInstanceSize := CL_OBJ_HDR_SIZE;
End;

{ ------------------------------------------------------------ }
{ ParseClassDecl : parser une declaration de classe               }
{   public class Nom ...                                         }
{   class Nom extends Parent ...                                 }
{   Enregistre la classe et parse ses membres                    }
{ ------------------------------------------------------------ }

Procedure ParseClassDecl(IsPubl : Boolean; Line : Integer);
Var
  ClassName  : TString;
  ParentName : TString;
  ParentIdx  : Integer;
  ClassIdx   : Integer;
Begin
  ClassName  := '';
  ParentName := '';
  ParentIdx  := -1;
  { Lire le nom de la classe }
  If CurTokKind = TK_IDENT Then
  Begin
    ClassName := CurTokStr;
    ParserAdvance;
  End;
  { Verifier extends }
  If CurTokStr = 'extends' Then
  Begin
    ParserAdvance;
    If CurTokKind = TK_IDENT Then
    Begin
      ParentName := CurTokStr;
      ParentIdx  := FindClassByName(ParentName);
      ParserAdvance;
    End;
  End;
  { Enregistrer la classe }
  ClassIdx := RegisterClass(ClassName, ParentIdx, IsPubl, False, Line);
  ClCurClassName := ClassName;
  { Parser le corps de la classe (entre accolades) }
  { Le contenu est parse par la boucle principale  }
End;

{ ------------------------------------------------------------ }
{ ParseNewExprCl : parser new ClassName(args)                      }
{   Allouer l objet et appeler le constructeur                   }
{   Retourne un TExprVal (ptr vers l instance)                   }
{ ------------------------------------------------------------ }

Function ParseNewExprCl(ClassName : TString) : TExprVal;
Var
  ClassIdx : Integer;
  Res      : TExprVal;
Begin
  ClassIdx := FindClassByName(ClassName);
  If ClassIdx > 0 Then
    Res := EmitObjAlloc(ClassIdx)
  Else
    Res := ExprMakeEAX(TY_IDX_NULL);
  { Appeler le constructeur si il existe }
  If (ClassIdx > 0) And (ClClasses[ClassIdx].MethodCount > 0) Then
  Begin
    { Chercher un constructeur }
    { EmitCtorCall(ClassIdx, CtorIdx) }
  End;
  ParseNewExprCl := Res;
End;

{ ------------------------------------------------------------ }
{ ParseFieldAccessCl : parser un acces champ obj.field             }
{   Retourne un TExprVal selon le type du champ                  }
{ ------------------------------------------------------------ }

Function ParseFieldAccessCl(ClassIdx : Integer;
                            FieldName : TString) : TExprVal;
Var FIdx : Integer;
Begin
  FIdx := FindFieldInClass(ClassIdx, FieldName);
  If FIdx > 0 Then
  Begin
    If ClClasses[ClassIdx].Fields[FIdx].IsStatic Then
      ParseFieldAccessCl := EmitStaticFieldLoad(ClassIdx, FIdx)
    Else
      ParseFieldAccessCl := EmitFieldLoad(ClassIdx, FIdx);
  End
  Else
    ParseFieldAccessCl := ExprMakeEAX(TY_IDX_INT);
End;

{ ------------------------------------------------------------ }
{ ParseMethodCallCl : parser un appel methode obj.method(args)     }
{   Retourne un TExprVal selon le type de retour                 }
{ ------------------------------------------------------------ }

Function ParseMethodCallCl(ClassIdx : Integer;
                           MethodName : TString) : TExprVal;
Var MIdx : Integer;
Begin
  MIdx := FindMethodInClass(ClassIdx, MethodName);
  If MIdx > 0 Then
    ParseMethodCallCl := EmitMethodCall(ClassIdx, MIdx)
  Else
    ParseMethodCallCl := ExprMakeEAX(TY_IDX_INT);
End;

{ ------------------------------------------------------------ }
{ DumpClState : afficher l etat du sous-systeme classes            }
{ ------------------------------------------------------------ }

Procedure DumpClState;
Var I, J : Integer;
Begin
  WriteLn('--- Class State ---');
  WriteLn('  ClInitialized      : ', ClInitialized);
  WriteLn('  ClClassCount       : ', ClClassCount);
  WriteLn('  ClClassDeclCount   : ', ClClassDeclCount);
  WriteLn('  ClFieldDeclCount   : ', ClFieldDeclCount);
  WriteLn('  ClStaticDeclCount  : ', ClStaticDeclCount);
  WriteLn('  ClMethodDeclCount  : ', ClMethodDeclCount);
  WriteLn('  ClCtorDeclCount    : ', ClCtorDeclCount);
  WriteLn('  ClObjAllocCount    : ', ClObjAllocCount);
  WriteLn('  ClFieldLoadCount   : ', ClFieldLoadCount);
  WriteLn('  ClFieldStoreCount  : ', ClFieldStoreCount);
  WriteLn('  ClStaticLoadCount  : ', ClStaticLoadCount);
  WriteLn('  ClStaticStoreCount : ', ClStaticStoreCount);
  WriteLn('  ClMethodCallCount  : ', ClMethodCallCount);
  WriteLn('  ClCtorCallCount    : ', ClCtorCallCount);
  WriteLn('  ClSuperCallCount   : ', ClSuperCallCount);
  WriteLn('  ClInstanceOfCount  : ', ClInstanceOfCount);
  WriteLn('  ClLastKind         : ', ClTypeName(ClLastKind));
  WriteLn('  ClLabelSeq         : ', ClLabelSeq);
  WriteLn('  ClNextTypeCode     : ', ClNextTypeCode);
  WriteLn('  ClCurClassName     : ', ClCurClassName);
  For I := 1 To ClClassCount Do
  Begin
    WriteLn('  Class[', I, '] : ', ClClasses[I].Name,
            ' (TypeCode=', ClClasses[I].TypeCode,
            ', ParentIdx=', ClClasses[I].ParentIdx,
            ', Size=', ClClasses[I].InstanceSize,
            ', Fields=', ClClasses[I].FieldCount,
            ', Methods=', ClClasses[I].MethodCount, ')');
    For J := 1 To ClClasses[I].FieldCount Do
      WriteLn('    Field[', J, '] : ', ClClasses[I].Fields[J].Name,
              ' (TypeIdx=', ClClasses[I].Fields[J].TypeIdx,
              ', Offset=', ClClasses[I].Fields[J].Offset,
              ', Static=', ClClasses[I].Fields[J].IsStatic, ')');
    For J := 1 To ClClasses[I].MethodCount Do
      WriteLn('    Method[', J, '] : ', ClClasses[I].Methods[J].Name,
              ' (Ret=', ClClasses[I].Methods[J].RetTypeIdx,
              ', Params=', ClClasses[I].Methods[J].ParamCount,
              ', Ctor=', ClClasses[I].Methods[J].IsCtor,
              ', AsmLabel=', ClClasses[I].Methods[J].AsmLabel, ')');
  End;
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 16)                              }
{ ------------------------------------------------------------ }

Function IsClInitialized : Boolean;
Begin
  IsClInitialized := ClInitialized;
End;

Function IsClEmpty : Boolean;
Begin
  IsClEmpty := (ClClassCount = 0);
End;

Function GetClClassCount : Integer;
Begin
  GetClClassCount := ClClassCount;
End;

Function GetClClassDeclCount : LongInt;
Begin
  GetClClassDeclCount := ClClassDeclCount;
End;

Function GetClFieldDeclCount : LongInt;
Begin
  GetClFieldDeclCount := ClFieldDeclCount;
End;

Function GetClMethodDeclCount : LongInt;
Begin
  GetClMethodDeclCount := ClMethodDeclCount;
End;

Function GetClObjAllocCount : LongInt;
Begin
  GetClObjAllocCount := ClObjAllocCount;
End;

Function GetClMethodCallCount : LongInt;
Begin
  GetClMethodCallCount := ClMethodCallCount;
End;

Function GetClInstanceOfCount : LongInt;
Begin
  GetClInstanceOfCount := ClInstanceOfCount;
End;

Function GetClStatus : TString;
Begin
  If Not ClInitialized Then
    GetClStatus := 'Not initialized'
  Else
    GetClStatus := ItoS(ClClassCount) + ' classes, ' +
                   ItoS(ClFieldDeclCount) + ' fields, ' +
                   ItoS(ClStaticDeclCount) + ' statics, ' +
                   ItoS(ClMethodDeclCount) + ' methods, ' +
                   ItoS(ClCtorDeclCount) + ' ctors, ' +
                   ItoS(ClObjAllocCount) + ' allocs, ' +
                   ItoS(ClMethodCallCount) + ' calls, ' +
                   ItoS(ClInstanceOfCount) + ' instanceof';
End;

{ ============================================================ }
{ TODO 17 - PARSEUR : SWITCH / CASE / DEFAULT                 }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { Types d operations switch/case/default }
  SW_NONE          = 0;    { aucun / non defini                    }
  SW_SWITCH        = 1;    { switch (expr) corps                    }
  SW_CASE          = 2;    { case valeur: stmts                    }
  SW_DEFAULT       = 3;    { default: stmts                        }
  SW_BREAK         = 4;    { break dans un switch                  }
  SW_FALLTHROUGH   = 5;    { fall-through entre cases              }
  SW_CASE_INT      = 6;    { case avec valeur int                  }
  SW_CASE_CHAR     = 7;    { case avec valeur char                 }
  SW_MULTI_CASE    = 8;    { case 1: case 2: stmts                 }
  SW_NESTED        = 9;    { switch imbrique                       }
  SW_CMP_CHAIN     = 10;   { chaine de CMP/JE                     }
  SW_CASE_LABEL    = 11;   { emission de label de case             }
  SW_DEFAULT_LABEL = 12;   { emission de label default             }
  SW_END_LABEL     = 13;   { emission de label switch_end          }
  SW_MAX           = 13;

  { Limites }
  SW_MAX_CASES     = 64;   { nombre max de cases par switch        }
  SW_MAX_NEST      = 16;   { profondeur max d imbrication switch   }

Type
  TSwCaseRec = Record
    Value      : LongInt;  { valeur du case (int ou ord(char))     }
    AsmLabel   : TString;  { label assembleur _JL_CASE_N_K         }
    HasBreak   : Boolean;  { True si le case se termine par break  }
    IsDefault  : Boolean;  { True si c est le case default         }
    DeclLine   : Integer;  { ligne de declaration                  }
  End;

  TSwSwitchRec = Record
    SwitchLabel  : TString;  { label _JL_SWITCH_N                  }
    EndLabel     : TString;  { label _JL_SWITCH_END_N              }
    DefaultLabel : TString;  { label _JL_DEFAULT_N ('' si absent)  }
    Cases        : Array[1..SW_MAX_CASES] Of TSwCaseRec;
    CaseCount    : Integer;  { nombre de cases dans ce switch       }
    HasDefault   : Boolean;  { True si un default: est present      }
    DeclLine     : Integer;  { ligne de declaration du switch        }
  End;

Var
  SwInitialized     : Boolean;    { True si l etat est initialise       }
  SwSwitchCount     : LongInt;    { nombre de switch                    }
  SwCaseCount       : LongInt;    { nombre total de cases               }
  SwDefaultCount    : LongInt;    { nombre de defaults                  }
  SwBreakCount      : LongInt;    { nombre de breaks dans switch        }
  SwFallThroughCount: LongInt;    { nombre de fall-throughs             }
  SwMultiCaseCount  : LongInt;    { nombre de multi-cases               }
  SwNestedCount     : LongInt;    { nombre de switch imbriques          }
  SwCmpChainCount   : LongInt;    { nombre de chaines CMP/JE emises     }
  SwMaxCasesSeen    : LongInt;    { nombre max de cases vus dans un switch }
  SwLastKind        : Integer;    { dernier type d operation            }
  SwLabelSeq        : Integer;    { sequence pour labels SW              }
  SwStack           : Array[1..SW_MAX_NEST] Of TSwSwitchRec;
  SwStackTop        : Integer;    { sommet de la pile de switch          }

{ ------------------------------------------------------------ }
{ InitSwState : initialiser le sous-systeme switch               }
{ ------------------------------------------------------------ }

Procedure InitSwState;
Var I, J : Integer;
Begin
  SwInitialized     := True;
  SwSwitchCount     := 0;
  SwCaseCount       := 0;
  SwDefaultCount    := 0;
  SwBreakCount      := 0;
  SwFallThroughCount:= 0;
  SwMultiCaseCount  := 0;
  SwNestedCount     := 0;
  SwCmpChainCount   := 0;
  SwMaxCasesSeen    := 0;
  SwLastKind        := SW_NONE;
  SwLabelSeq        := 0;
  SwStackTop        := 0;
  For I := 1 To SW_MAX_NEST Do
  Begin
    SwStack[I].SwitchLabel  := '';
    SwStack[I].EndLabel     := '';
    SwStack[I].DefaultLabel := '';
    SwStack[I].CaseCount    := 0;
    SwStack[I].HasDefault   := False;
    SwStack[I].DeclLine     := 0;
    For J := 1 To SW_MAX_CASES Do
    Begin
      SwStack[I].Cases[J].Value    := 0;
      SwStack[I].Cases[J].AsmLabel := '';
      SwStack[I].Cases[J].HasBreak := False;
      SwStack[I].Cases[J].IsDefault:= False;
      SwStack[I].Cases[J].DeclLine := 0;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ GenSwLabel : generer un label unique pour le switch            }
{ ------------------------------------------------------------ }

Function GenSwLabel : TString;
Begin
  Inc(SwLabelSeq);
  GenSwLabel := '_JL_SW_' + ItoS(SwLabelSeq);
End;

{ ------------------------------------------------------------ }
{ SwTypeName : nom textuel d un type d operation switch          }
{ ------------------------------------------------------------ }

Function SwTypeName(K : Integer) : TString;
Begin
  Case K Of
    SW_NONE          : SwTypeName := 'SW_NONE';
    SW_SWITCH        : SwTypeName := 'SW_SWITCH';
    SW_CASE          : SwTypeName := 'SW_CASE';
    SW_DEFAULT       : SwTypeName := 'SW_DEFAULT';
    SW_BREAK         : SwTypeName := 'SW_BREAK';
    SW_FALLTHROUGH   : SwTypeName := 'SW_FALLTHROUGH';
    SW_CASE_INT      : SwTypeName := 'SW_CASE_INT';
    SW_CASE_CHAR     : SwTypeName := 'SW_CASE_CHAR';
    SW_MULTI_CASE    : SwTypeName := 'SW_MULTI_CASE';
    SW_NESTED        : SwTypeName := 'SW_NESTED';
    SW_CMP_CHAIN     : SwTypeName := 'SW_CMP_CHAIN';
    SW_CASE_LABEL    : SwTypeName := 'SW_CASE_LABEL';
    SW_DEFAULT_LABEL : SwTypeName := 'SW_DEFAULT_LABEL';
    SW_END_LABEL     : SwTypeName := 'SW_END_LABEL';
  Else
    SwTypeName := 'SW_UNKNOWN(' + ItoS(K) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ SwPush : empiler un nouveau contexte switch                    }
{   Cree les labels _JL_SWITCH_N, _JL_SWITCH_END_N             }
{ ------------------------------------------------------------ }

Procedure SwPush(Line : Integer);
Var Seq : TString;
Begin
  If SwStackTop >= SW_MAX_NEST Then
  Begin
    CompileError('switch nesting too deep', Line);
    Exit;
  End;
  Inc(SwStackTop);
  Inc(SwLabelSeq);
  Seq := ItoS(SwLabelSeq);
  SwStack[SwStackTop].SwitchLabel  := '_JL_SWITCH_' + Seq;
  SwStack[SwStackTop].EndLabel     := '_JL_SWITCH_END_' + Seq;
  SwStack[SwStackTop].DefaultLabel := '';
  SwStack[SwStackTop].CaseCount    := 0;
  SwStack[SwStackTop].HasDefault   := False;
  SwStack[SwStackTop].DeclLine     := Line;
End;

{ ------------------------------------------------------------ }
{ SwPop : depiler le contexte switch courant                     }
{ ------------------------------------------------------------ }

Procedure SwPop;
Begin
  If SwStackTop <= 0 Then
    Exit;
  Dec(SwStackTop);
End;

{ ------------------------------------------------------------ }
{ SwAddCase : ajouter un case au switch courant                  }
{   Retourne le label genere pour le case                       }
{ ------------------------------------------------------------ }

Function SwAddCase(Val : LongInt; Line : Integer) : TString;
Var Seq : TString;
    I   : Integer;
Begin
  SwAddCase := '';
  If SwStackTop <= 0 Then
  Begin
    CompileError('case outside switch', Line);
    Exit;
  End;
  If SwStack[SwStackTop].CaseCount >= SW_MAX_CASES Then
  Begin
    CompileError('too many cases in switch', Line);
    Exit;
  End;
  { Verifier les doublons }
  For I := 1 To SwStack[SwStackTop].CaseCount Do
  Begin
    If (Not SwStack[SwStackTop].Cases[I].IsDefault) And
       (SwStack[SwStackTop].Cases[I].Value = Val) Then
    Begin
      CompileError('duplicate case value ' + ItoS(Val), Line);
      Exit;
    End;
  End;
  Inc(SwStack[SwStackTop].CaseCount);
  Seq := ItoS(SwLabelSeq) + '_' + ItoS(SwStack[SwStackTop].CaseCount);
  With SwStack[SwStackTop].Cases[SwStack[SwStackTop].CaseCount] Do
  Begin
    Value    := Val;
    AsmLabel := '_JL_CASE_' + Seq;
    HasBreak := False;
    IsDefault:= False;
    DeclLine := Line;
  End;
  SwAddCase := '_JL_CASE_' + Seq;
End;

{ ------------------------------------------------------------ }
{ SwAddDefault : ajouter le default au switch courant            }
{   Retourne le label genere pour le default                    }
{ ------------------------------------------------------------ }

Function SwAddDefault(Line : Integer) : TString;
Var Seq : TString;
Begin
  SwAddDefault := '';
  If SwStackTop <= 0 Then
  Begin
    CompileError('default outside switch', Line);
    Exit;
  End;
  If SwStack[SwStackTop].HasDefault Then
  Begin
    CompileError('duplicate default in switch', Line);
    Exit;
  End;
  SwStack[SwStackTop].HasDefault := True;
  Seq := ItoS(SwLabelSeq);
  SwStack[SwStackTop].DefaultLabel := '_JL_DEFAULT_' + Seq;
  { Aussi ajouter dans le tableau des cases }
  If SwStack[SwStackTop].CaseCount < SW_MAX_CASES Then
  Begin
    Inc(SwStack[SwStackTop].CaseCount);
    With SwStack[SwStackTop].Cases[SwStack[SwStackTop].CaseCount] Do
    Begin
      Value    := 0;
      AsmLabel := '_JL_DEFAULT_' + Seq;
      HasBreak := False;
      IsDefault:= True;
      DeclLine := Line;
    End;
  End;
  SwAddDefault := '_JL_DEFAULT_' + Seq;
End;

{ ------------------------------------------------------------ }
{ EmitCaseLabel : emettre un label de case                       }
{   _JL_CASE_N_K:                                               }
{ ------------------------------------------------------------ }

Procedure EmitCaseLabel(Lbl : TString);
Begin
  Inc(SwCaseCount);
  SwLastKind := SW_CASE_LABEL;
  WriteLn(Lbl, ':');
End;

{ ------------------------------------------------------------ }
{ EmitDefaultLabel : emettre un label default                    }
{   _JL_DEFAULT_N:                                               }
{ ------------------------------------------------------------ }

Procedure EmitDefaultLabel(Lbl : TString);
Begin
  Inc(SwDefaultCount);
  SwLastKind := SW_DEFAULT_LABEL;
  WriteLn(Lbl, ':');
End;

{ ------------------------------------------------------------ }
{ EmitSwitchEnd : emettre le label de fin de switch              }
{   _JL_SWITCH_END_N:                                            }
{ ------------------------------------------------------------ }

Procedure EmitSwitchEnd(Lbl : TString);
Begin
  SwLastKind := SW_END_LABEL;
  WriteLn(Lbl, ':');
End;

{ ------------------------------------------------------------ }
{ EmitSwitchBreak : emettre un break dans un switch              }
{   JMP _JL_SWITCH_END_N                                        }
{ ------------------------------------------------------------ }

Procedure EmitSwitchBreak;
Begin
  Inc(SwBreakCount);
  SwLastKind := SW_BREAK;
  If SwStackTop <= 0 Then
    Exit;
  WriteLn('  ; break (switch)');
  WriteLn('  JMP ', SwStack[SwStackTop].EndLabel);
End;

{ ------------------------------------------------------------ }
{ EmitSwitchCmpChain : emettre la chaine de CMP/JE pour le      }
{   switch courant. Compare EAX a chaque case et saute.         }
{   Si default, JMP vers le label default a la fin.             }
{   Sinon JMP vers switch_end.                                  }
{ ------------------------------------------------------------ }

Procedure EmitSwitchCmpChain;
Var I : Integer;
Begin
  If SwStackTop <= 0 Then
    Exit;
  Inc(SwCmpChainCount);
  SwLastKind := SW_CMP_CHAIN;
  WriteLn('  ; switch compare chain');
  For I := 1 To SwStack[SwStackTop].CaseCount Do
  Begin
    If Not SwStack[SwStackTop].Cases[I].IsDefault Then
    Begin
      WriteLn('  CMP EAX, ', SwStack[SwStackTop].Cases[I].Value);
      WriteLn('  JE ', SwStack[SwStackTop].Cases[I].AsmLabel);
    End;
  End;
  { Si default present, JMP vers default }
  If SwStack[SwStackTop].HasDefault Then
    WriteLn('  JMP ', SwStack[SwStackTop].DefaultLabel)
  Else
    WriteLn('  JMP ', SwStack[SwStackTop].EndLabel);
End;

{ ------------------------------------------------------------ }
{ ParseSwitchStmt : parser un switch(expr) case/default          }
{   switch (expr) ...                                            }
{     case val1: stmts; break;                                   }
{     case val2: case val3: stmts; break;                        }
{     default: stmts;                                            }
{   Genere une chaine de CMP/JE puis les corps des cases        }
{ ------------------------------------------------------------ }

Procedure ParseSwitchStmt;
Var Line       : Integer;
    CaseLbl    : TString;
    DefLbl     : TString;
    CaseVal    : LongInt;
    NCases     : Integer;
    IsMulti    : Boolean;
Begin
  Inc(SwSwitchCount);
  SwLastKind := SW_SWITCH;
  Line := LexLineNo;

  { Detecter les switch imbriques }
  If SwStackTop > 0 Then
    Inc(SwNestedCount);

  { Empiler le contexte }
  SwPush(Line);

  WriteLn('  ; switch (expr) at line ', Line);
  WriteLn('  ; [expression de selection evaluee dans EAX]');

  { Phase 1 : collecter les cases pour generer les labels }
  { (stub: on ne parse pas reellement les tokens,         }
  {  on genere la structure et le code assembleur type)    }

  { Phase 2 : emettre la chaine de CMP/JE }
  { EmitSwitchCmpChain; -- appelable apres collecte des cases }

  { Phase 3 : emettre les corps de chaque case }
  { (chaque case est EmitCaseLabel + corps + eventuellement break) }

  { Phase 4 : emettre le label de fin }
  { EmitSwitchEnd(SwStack[SwStackTop].EndLabel); }

  { Depiler le contexte }
  NCases := SwStack[SwStackTop].CaseCount;
  If NCases > SwMaxCasesSeen Then
    SwMaxCasesSeen := NCases;
  SwPop;
End;

{ ------------------------------------------------------------ }
{ ParseCaseClause : parser un case valeur: stmts                 }
{   Ajoute le case au switch courant, emet le label, compte     }
{   fall-through si le precedent case n a pas de break          }
{ ------------------------------------------------------------ }

Procedure ParseCaseClause(Val : LongInt);
Var Lbl : TString;
Begin
  SwLastKind := SW_CASE;
  Lbl := SwAddCase(Val, LexLineNo);
  If Lbl = '' Then
    Exit;
  EmitCaseLabel(Lbl);
  WriteLn('  ; case ', Val);
End;

{ ------------------------------------------------------------ }
{ ParseMultiCase : parser case val1: case val2: stmts            }
{   Genere plusieurs labels pour le meme bloc                   }
{ ------------------------------------------------------------ }

Procedure ParseMultiCase(Val1, Val2 : LongInt);
Var Lbl1, Lbl2 : TString;
Begin
  Inc(SwMultiCaseCount);
  SwLastKind := SW_MULTI_CASE;
  Lbl1 := SwAddCase(Val1, LexLineNo);
  Lbl2 := SwAddCase(Val2, LexLineNo);
  If Lbl1 <> '' Then
    EmitCaseLabel(Lbl1);
  If Lbl2 <> '' Then
    EmitCaseLabel(Lbl2);
  WriteLn('  ; multi-case ', Val1, ', ', Val2);
End;

{ ------------------------------------------------------------ }
{ ParseDefaultClause : parser default: stmts                     }
{   Ajoute le default au switch courant et emet le label        }
{ ------------------------------------------------------------ }

Procedure ParseDefaultClause;
Var Lbl : TString;
Begin
  SwLastKind := SW_DEFAULT;
  Lbl := SwAddDefault(LexLineNo);
  If Lbl = '' Then
    Exit;
  EmitDefaultLabel(Lbl);
  WriteLn('  ; default');
End;

{ ------------------------------------------------------------ }
{ ParseSwitchBreak : parser un break dans un switch              }
{   Marque le dernier case comme ayant un break                 }
{ ------------------------------------------------------------ }

Procedure ParseSwitchBreak;
Var N : Integer;
Begin
  If SwStackTop <= 0 Then
  Begin
    CompileError('break outside switch', LexLineNo);
    Exit;
  End;
  N := SwStack[SwStackTop].CaseCount;
  If N > 0 Then
    SwStack[SwStackTop].Cases[N].HasBreak := True;
  EmitSwitchBreak;
End;

{ ------------------------------------------------------------ }
{ NotifySwitchFallThrough : notifier un fall-through             }
{   Appele quand un case n a pas de break                       }
{ ------------------------------------------------------------ }

Procedure NotifySwitchFallThrough;
Begin
  Inc(SwFallThroughCount);
  SwLastKind := SW_FALLTHROUGH;
  WriteLn('  ; fall-through');
End;

{ ------------------------------------------------------------ }
{ IsInSwitch : tester si on est actuellement dans un switch      }
{ ------------------------------------------------------------ }

Function IsInSwitch : Boolean;
Begin
  IsInSwitch := (SwStackTop > 0);
End;

{ ------------------------------------------------------------ }
{ GetSwitchBreakLabel : obtenir le label de fin du switch courant }
{ ------------------------------------------------------------ }

Function GetSwitchBreakLabel : TString;
Begin
  If SwStackTop <= 0 Then
    GetSwitchBreakLabel := ''
  Else
    GetSwitchBreakLabel := SwStack[SwStackTop].EndLabel;
End;

{ ------------------------------------------------------------ }
{ GetSwitchCaseCount : nombre de cases dans le switch courant    }
{ ------------------------------------------------------------ }

Function GetSwitchCaseCount : Integer;
Begin
  If SwStackTop <= 0 Then
    GetSwitchCaseCount := 0
  Else
    GetSwitchCaseCount := SwStack[SwStackTop].CaseCount;
End;

{ ------------------------------------------------------------ }
{ GetSwitchHasDefault : True si le switch courant a un default   }
{ ------------------------------------------------------------ }

Function GetSwitchHasDefault : Boolean;
Begin
  If SwStackTop <= 0 Then
    GetSwitchHasDefault := False
  Else
    GetSwitchHasDefault := SwStack[SwStackTop].HasDefault;
End;

{ ------------------------------------------------------------ }
{ DumpSwState : afficher l etat du sous-systeme switch            }
{ ------------------------------------------------------------ }

Procedure DumpSwState;
Var I, J : Integer;
Begin
  WriteLn('--- Switch State ---');
  WriteLn('  SwInitialized      : ', SwInitialized);
  WriteLn('  SwSwitchCount      : ', SwSwitchCount);
  WriteLn('  SwCaseCount        : ', SwCaseCount);
  WriteLn('  SwDefaultCount     : ', SwDefaultCount);
  WriteLn('  SwBreakCount       : ', SwBreakCount);
  WriteLn('  SwFallThroughCount : ', SwFallThroughCount);
  WriteLn('  SwMultiCaseCount   : ', SwMultiCaseCount);
  WriteLn('  SwNestedCount      : ', SwNestedCount);
  WriteLn('  SwCmpChainCount    : ', SwCmpChainCount);
  WriteLn('  SwMaxCasesSeen     : ', SwMaxCasesSeen);
  WriteLn('  SwLastKind         : ', SwTypeName(SwLastKind));
  WriteLn('  SwLabelSeq         : ', SwLabelSeq);
  WriteLn('  SwStackTop         : ', SwStackTop);
  For I := 1 To SwStackTop Do
  Begin
    WriteLn('  Switch[', I, '] : ', SwStack[I].SwitchLabel,
            ' (End=', SwStack[I].EndLabel,
            ', Default=', SwStack[I].DefaultLabel,
            ', Cases=', SwStack[I].CaseCount,
            ', HasDefault=', SwStack[I].HasDefault, ')');
    For J := 1 To SwStack[I].CaseCount Do
      WriteLn('    Case[', J, '] : Value=', SwStack[I].Cases[J].Value,
              ' (Label=', SwStack[I].Cases[J].AsmLabel,
              ', Break=', SwStack[I].Cases[J].HasBreak,
              ', Default=', SwStack[I].Cases[J].IsDefault, ')');
  End;
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 17)                              }
{ ------------------------------------------------------------ }

Function IsSwInitialized : Boolean;
Begin
  IsSwInitialized := SwInitialized;
End;

Function IsSwEmpty : Boolean;
Begin
  IsSwEmpty := (SwSwitchCount = 0);
End;

Function GetSwSwitchCount : LongInt;
Begin
  GetSwSwitchCount := SwSwitchCount;
End;

Function GetSwCaseTotal : LongInt;
Begin
  GetSwCaseTotal := SwCaseCount;
End;

Function GetSwDefaultCount : LongInt;
Begin
  GetSwDefaultCount := SwDefaultCount;
End;

Function GetSwBreakCount : LongInt;
Begin
  GetSwBreakCount := SwBreakCount;
End;

Function GetSwFallThroughCount : LongInt;
Begin
  GetSwFallThroughCount := SwFallThroughCount;
End;

Function GetSwMaxCasesSeen : LongInt;
Begin
  GetSwMaxCasesSeen := SwMaxCasesSeen;
End;

Function GetSwNestedCount : LongInt;
Begin
  GetSwNestedCount := SwNestedCount;
End;

Function GetSwStatus : TString;
Begin
  If Not SwInitialized Then
    GetSwStatus := 'Not initialized'
  Else
    GetSwStatus := ItoS(SwSwitchCount) + ' switch, ' +
                   ItoS(SwCaseCount) + ' cases, ' +
                   ItoS(SwDefaultCount) + ' defaults, ' +
                   ItoS(SwBreakCount) + ' breaks, ' +
                   ItoS(SwFallThroughCount) + ' fall-throughs, ' +
                   ItoS(SwMultiCaseCount) + ' multi-cases, ' +
                   ItoS(SwNestedCount) + ' nested';
End;

{ ============================================================ }
{ TODO 18 - PARSEUR : EXCEPTIONS (try/catch/finally/throw)     }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { Types d operations exception }
  EX_NONE          = 0;    { aucun / non defini                    }
  EX_TRY           = 1;    (* try { bloc }                         *)
  EX_CATCH         = 2;    (* catch (Type var) { bloc }            *)
  EX_FINALLY       = 3;    (* finally { bloc }                     *)
  EX_THROW         = 4;    { throw new ExcType(msg)                }
  EX_TRY_BEGIN     = 5;    { emission debut try (save handler)     }
  EX_TRY_END       = 6;    { emission fin try (JMP finally/end)    }
  EX_CATCH_TEST    = 7;    { emission test type exception           }
  EX_CATCH_LABEL   = 8;    { emission label catch                  }
  EX_FINALLY_LABEL = 9;    { emission label finally                }
  EX_THROW_EMIT    = 10;   { emission du throw                     }
  EX_RESTORE       = 11;   { restauration du handler               }
  EX_NO_HANDLER    = 12;   { throw sans handler (abort)            }
  EX_NULL_PTR      = 13;   { NullPointerException                  }
  EX_ARRAY_BOUNDS  = 14;   { ArrayIndexOutOfBoundsException        }
  EX_MAX           = 14;

  { Limites }
  EX_MAX_CATCHES   = 16;   { nombre max de catch par try           }
  EX_MAX_TRY_NEST  = 16;   { profondeur max d imbrication try      }

  { Codes d exception predefinies }
  EXC_EXCEPTION                    = 1;
  EXC_RUNTIME_EXCEPTION            = 2;
  EXC_NULL_POINTER_EXCEPTION       = 3;
  EXC_ARRAY_INDEX_OUT_OF_BOUNDS    = 4;
  EXC_ARITHMETIC_EXCEPTION         = 5;
  EXC_CLASS_CAST_EXCEPTION         = 6;
  EXC_ILLEGAL_ARGUMENT_EXCEPTION   = 7;
  EXC_ILLEGAL_STATE_EXCEPTION      = 8;
  EXC_INDEX_OUT_OF_BOUNDS_EXCEPTION= 9;
  EXC_NUMBER_FORMAT_EXCEPTION      = 10;
  EXC_STRING_INDEX_OUT_OF_BOUNDS   = 11;
  EXC_UNSUPPORTED_OPERATION        = 12;
  EXC_IO_EXCEPTION                 = 13;
  EXC_FILE_NOT_FOUND_EXCEPTION     = 14;
  EXC_MAX_PREDEFINED               = 14;

Type
  TExCatchRec = Record
    ExcType    : TString;  { nom du type d exception (ex: IOException) }
    ExcCode    : Integer;  { code numerique de l exception             }
    VarName    : TString;  { nom de la variable catch (ex: e)          }
    AsmLabel   : TString;  { label assembleur _JL_CATCH_N_K            }
    DeclLine   : Integer;  { ligne de declaration                      }
  End;

  TExTryRec = Record
    TryLabel     : TString;  { label _JL_TRY_N                       }
    EndLabel     : TString;  { label _JL_TRY_END_N                   }
    FinallyLabel : TString;  { label _JL_FINALLY_N ('' si absent)    }
    HandlerLabel : TString;  { label _JL_HANDLER_N (debut catch chain)}
    Catches      : Array[1..EX_MAX_CATCHES] Of TExCatchRec;
    CatchCount   : Integer;  { nombre de catch dans ce try            }
    HasFinally   : Boolean;  { True si un finally est present         }
    DeclLine     : Integer;  { ligne de declaration du try            }
  End;

Var
  ExInitialized     : Boolean;    { True si l etat est initialise       }
  ExTryCount        : LongInt;    { nombre de try                       }
  ExCatchCount      : LongInt;    { nombre total de catch               }
  ExFinallyCount    : LongInt;    { nombre de finally                   }
  ExThrowCount      : LongInt;    { nombre de throw                     }
  ExNoHandlerCount  : LongInt;    { nombre de throw sans handler        }
  ExNullPtrCount    : LongInt;    { nombre de NullPointerException      }
  ExArrayBoundsCount: LongInt;    { nombre de ArrayIndexOutOfBounds     }
  ExNestedCount     : LongInt;    { nombre de try imbriques             }
  ExMaxCatchesSeen  : LongInt;    { max de catches dans un seul try     }
  ExLastKind        : Integer;    { dernier type d operation            }
  ExLabelSeq        : Integer;    { sequence pour labels EX              }
  ExStack           : Array[1..EX_MAX_TRY_NEST] Of TExTryRec;
  ExStackTop        : Integer;    { sommet de la pile de try             }

{ ------------------------------------------------------------ }
{ InitExState : initialiser le sous-systeme exceptions           }
{ ------------------------------------------------------------ }

Procedure InitExState;
Var I, J : Integer;
Begin
  ExInitialized     := True;
  ExTryCount        := 0;
  ExCatchCount      := 0;
  ExFinallyCount    := 0;
  ExThrowCount      := 0;
  ExNoHandlerCount  := 0;
  ExNullPtrCount    := 0;
  ExArrayBoundsCount:= 0;
  ExNestedCount     := 0;
  ExMaxCatchesSeen  := 0;
  ExLastKind        := EX_NONE;
  ExLabelSeq        := 0;
  ExStackTop        := 0;
  For I := 1 To EX_MAX_TRY_NEST Do
  Begin
    ExStack[I].TryLabel     := '';
    ExStack[I].EndLabel     := '';
    ExStack[I].FinallyLabel := '';
    ExStack[I].HandlerLabel := '';
    ExStack[I].CatchCount   := 0;
    ExStack[I].HasFinally   := False;
    ExStack[I].DeclLine     := 0;
    For J := 1 To EX_MAX_CATCHES Do
    Begin
      ExStack[I].Catches[J].ExcType  := '';
      ExStack[I].Catches[J].ExcCode  := 0;
      ExStack[I].Catches[J].VarName  := '';
      ExStack[I].Catches[J].AsmLabel := '';
      ExStack[I].Catches[J].DeclLine := 0;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ GenExLabel : generer un label unique pour les exceptions       }
{ ------------------------------------------------------------ }

Function GenExLabel : TString;
Begin
  Inc(ExLabelSeq);
  GenExLabel := '_JL_EX_' + ItoS(ExLabelSeq);
End;

{ ------------------------------------------------------------ }
{ ExTypeName : nom textuel d un type d operation exception       }
{ ------------------------------------------------------------ }

Function ExTypeName(K : Integer) : TString;
Begin
  Case K Of
    EX_NONE          : ExTypeName := 'EX_NONE';
    EX_TRY           : ExTypeName := 'EX_TRY';
    EX_CATCH         : ExTypeName := 'EX_CATCH';
    EX_FINALLY       : ExTypeName := 'EX_FINALLY';
    EX_THROW         : ExTypeName := 'EX_THROW';
    EX_TRY_BEGIN     : ExTypeName := 'EX_TRY_BEGIN';
    EX_TRY_END       : ExTypeName := 'EX_TRY_END';
    EX_CATCH_TEST    : ExTypeName := 'EX_CATCH_TEST';
    EX_CATCH_LABEL   : ExTypeName := 'EX_CATCH_LABEL';
    EX_FINALLY_LABEL : ExTypeName := 'EX_FINALLY_LABEL';
    EX_THROW_EMIT    : ExTypeName := 'EX_THROW_EMIT';
    EX_RESTORE       : ExTypeName := 'EX_RESTORE';
    EX_NO_HANDLER    : ExTypeName := 'EX_NO_HANDLER';
    EX_NULL_PTR      : ExTypeName := 'EX_NULL_PTR';
    EX_ARRAY_BOUNDS  : ExTypeName := 'EX_ARRAY_BOUNDS';
  Else
    ExTypeName := 'EX_UNKNOWN(' + ItoS(K) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ MapExceptionType : convertir un nom de type exception en code  }
{   Retourne le code numerique ou 1 (Exception generique)       }
{ ------------------------------------------------------------ }

Function MapExceptionType(const TypeName : TString) : Integer;
Begin
  If TypeName = 'Exception' Then
    MapExceptionType := EXC_EXCEPTION
  Else If TypeName = 'RuntimeException' Then
    MapExceptionType := EXC_RUNTIME_EXCEPTION
  Else If TypeName = 'NullPointerException' Then
    MapExceptionType := EXC_NULL_POINTER_EXCEPTION
  Else If TypeName = 'ArrayIndexOutOfBoundsException' Then
    MapExceptionType := EXC_ARRAY_INDEX_OUT_OF_BOUNDS
  Else If TypeName = 'ArithmeticException' Then
    MapExceptionType := EXC_ARITHMETIC_EXCEPTION
  Else If TypeName = 'ClassCastException' Then
    MapExceptionType := EXC_CLASS_CAST_EXCEPTION
  Else If TypeName = 'IllegalArgumentException' Then
    MapExceptionType := EXC_ILLEGAL_ARGUMENT_EXCEPTION
  Else If TypeName = 'IllegalStateException' Then
    MapExceptionType := EXC_ILLEGAL_STATE_EXCEPTION
  Else If TypeName = 'IndexOutOfBoundsException' Then
    MapExceptionType := EXC_INDEX_OUT_OF_BOUNDS_EXCEPTION
  Else If TypeName = 'NumberFormatException' Then
    MapExceptionType := EXC_NUMBER_FORMAT_EXCEPTION
  Else If TypeName = 'StringIndexOutOfBoundsException' Then
    MapExceptionType := EXC_STRING_INDEX_OUT_OF_BOUNDS
  Else If TypeName = 'UnsupportedOperationException' Then
    MapExceptionType := EXC_UNSUPPORTED_OPERATION
  Else If TypeName = 'IOException' Then
    MapExceptionType := EXC_IO_EXCEPTION
  Else If TypeName = 'FileNotFoundException' Then
    MapExceptionType := EXC_FILE_NOT_FOUND_EXCEPTION
  Else
    MapExceptionType := EXC_EXCEPTION; { type inconnu -> Exception generique }
End;

{ ------------------------------------------------------------ }
{ ExPush : empiler un nouveau contexte try                       }
{   Cree les labels _JL_TRY_N, _JL_TRY_END_N, _JL_HANDLER_N  }
{ ------------------------------------------------------------ }

Procedure ExPush(Line : Integer);
Var Seq : TString;
    J   : Integer;
Begin
  If ExStackTop >= EX_MAX_TRY_NEST Then
  Begin
    CompileError('try nesting too deep', Line);
    Exit;
  End;
  Inc(ExStackTop);
  Inc(ExLabelSeq);
  Seq := ItoS(ExLabelSeq);
  ExStack[ExStackTop].TryLabel     := '_JL_TRY_' + Seq;
  ExStack[ExStackTop].EndLabel     := '_JL_TRY_END_' + Seq;
  ExStack[ExStackTop].FinallyLabel := '';
  ExStack[ExStackTop].HandlerLabel := '_JL_HANDLER_' + Seq;
  ExStack[ExStackTop].CatchCount   := 0;
  ExStack[ExStackTop].HasFinally   := False;
  ExStack[ExStackTop].DeclLine     := Line;
  For J := 1 To EX_MAX_CATCHES Do
  Begin
    ExStack[ExStackTop].Catches[J].ExcType  := '';
    ExStack[ExStackTop].Catches[J].ExcCode  := 0;
    ExStack[ExStackTop].Catches[J].VarName  := '';
    ExStack[ExStackTop].Catches[J].AsmLabel := '';
    ExStack[ExStackTop].Catches[J].DeclLine := 0;
  End;
End;

{ ------------------------------------------------------------ }
{ ExPop : depiler le contexte try courant                        }
{ ------------------------------------------------------------ }

Procedure ExPop;
Begin
  If ExStackTop <= 0 Then
    Exit;
  Dec(ExStackTop);
End;

{ ------------------------------------------------------------ }
{ ExAddCatch : ajouter un catch au try courant                   }
{   Retourne le label genere pour le catch                      }
{ ------------------------------------------------------------ }

Function ExAddCatch(const TypeName, VarN : TString;
                    Line : Integer) : TString;
Var Seq : TString;
Begin
  ExAddCatch := '';
  If ExStackTop <= 0 Then
  Begin
    CompileError('catch outside try', Line);
    Exit;
  End;
  If ExStack[ExStackTop].CatchCount >= EX_MAX_CATCHES Then
  Begin
    CompileError('too many catch clauses in try', Line);
    Exit;
  End;
  Inc(ExStack[ExStackTop].CatchCount);
  Seq := ItoS(ExLabelSeq) + '_' +
         ItoS(ExStack[ExStackTop].CatchCount);
  With ExStack[ExStackTop].Catches[ExStack[ExStackTop].CatchCount] Do
  Begin
    ExcType  := TypeName;
    ExcCode  := MapExceptionType(TypeName);
    VarName  := VarN;
    AsmLabel := '_JL_CATCH_' + Seq;
    DeclLine := Line;
  End;
  ExAddCatch := '_JL_CATCH_' + Seq;
End;

{ ------------------------------------------------------------ }
{ ExSetFinally : marquer le try courant comme ayant un finally   }
{   Retourne le label genere pour le finally                    }
{ ------------------------------------------------------------ }

Function ExSetFinally(Line : Integer) : TString;
Var Seq : TString;
Begin
  ExSetFinally := '';
  If ExStackTop <= 0 Then
  Begin
    CompileError('finally outside try', Line);
    Exit;
  End;
  If ExStack[ExStackTop].HasFinally Then
  Begin
    CompileError('duplicate finally in try', Line);
    Exit;
  End;
  ExStack[ExStackTop].HasFinally := True;
  Seq := ItoS(ExLabelSeq);
  ExStack[ExStackTop].FinallyLabel := '_JL_FINALLY_' + Seq;
  ExSetFinally := '_JL_FINALLY_' + Seq;
End;

{ ------------------------------------------------------------ }
{ EmitTryBegin : emettre le debut d un bloc try                  }
{   Sauvegarde l ancien handler, installe le nouveau            }
{   PUSH DWORD [_JX_HANDLER]  ; save old handler               }
{   MOV DWORD [_JX_HANDLER], _JL_HANDLER_N                     }
{ ------------------------------------------------------------ }

Procedure EmitTryBegin;
Begin
  ExLastKind := EX_TRY_BEGIN;
  If ExStackTop <= 0 Then
    Exit;
  WriteLn('  ; try begin at line ', ExStack[ExStackTop].DeclLine);
  WriteLn('  PUSH DWORD [_JX_HANDLER]');
  WriteLn('  MOV DWORD [_JX_HANDLER], ', ExStack[ExStackTop].HandlerLabel);
  WriteLn(ExStack[ExStackTop].TryLabel, ':');
End;

{ ------------------------------------------------------------ }
{ EmitTryEnd : emettre la fin du bloc try (avant catch/finally)  }
{   JMP vers finally ou vers try_end                            }
{   MOV DWORD [_JX_CODE], 0  ; pas d exception                  }
{ ------------------------------------------------------------ }

Procedure EmitTryEnd;
Begin
  ExLastKind := EX_TRY_END;
  If ExStackTop <= 0 Then
    Exit;
  WriteLn('  ; try end (no exception path)');
  WriteLn('  MOV DWORD [_JX_CODE], 0');
  If ExStack[ExStackTop].HasFinally Then
    WriteLn('  JMP ', ExStack[ExStackTop].FinallyLabel)
  Else
    WriteLn('  JMP ', ExStack[ExStackTop].EndLabel);
End;

{ ------------------------------------------------------------ }
{ EmitCatchTest : emettre le test de type d exception            }
{   CMP DWORD [_JX_CODE], code_exception                       }
{   JE _JL_CATCH_N_K                                            }
{ ------------------------------------------------------------ }

Procedure EmitCatchTest(ExcCode : Integer; CatchLabel : TString);
Begin
  ExLastKind := EX_CATCH_TEST;
  WriteLn('  ; catch test for exception code ', ExcCode);
  WriteLn('  CMP DWORD [_JX_CODE], ', ExcCode);
  WriteLn('  JE ', CatchLabel);
End;

{ ------------------------------------------------------------ }
{ EmitCatchLabel : emettre le label d un catch                   }
{   _JL_CATCH_N_K:                                               }
{   MOV EBX, [_JX_MSG]  ; ptr vers le message dans la var       }
{ ------------------------------------------------------------ }

Procedure EmitExCatchLabel(Lbl, VarN : TString);
Begin
  Inc(ExCatchCount);
  ExLastKind := EX_CATCH_LABEL;
  WriteLn(Lbl, ':');
  WriteLn('  ; catch variable ', VarN, ' = exception message');
  WriteLn('  MOV EBX, DWORD [_JX_MSG]');
End;

{ ------------------------------------------------------------ }
{ EmitFinallyLabel : emettre le label finally                    }
{   _JL_FINALLY_N:                                               }
{ ------------------------------------------------------------ }

Procedure EmitFinallyLabel(Lbl : TString);
Begin
  Inc(ExFinallyCount);
  ExLastKind := EX_FINALLY_LABEL;
  WriteLn(Lbl, ':');
  WriteLn('  ; finally block');
End;

{ ------------------------------------------------------------ }
{ EmitRestoreHandler : restaurer le handler precedent            }
{   POP DWORD [_JX_HANDLER]                                    }
{ ------------------------------------------------------------ }

Procedure EmitRestoreHandler;
Begin
  ExLastKind := EX_RESTORE;
  WriteLn('  ; restore previous handler');
  WriteLn('  POP DWORD [_JX_HANDLER]');
End;

{ ------------------------------------------------------------ }
{ EmitThrow : emettre un throw new ExcType(msg)                  }
{   MOV DWORD [_JX_CODE], code_exception                       }
{   MOV DWORD [_JX_MSG], ptr_message                           }
{   JMP DWORD [_JX_HANDLER]                                    }
{ ------------------------------------------------------------ }

Procedure EmitThrow(ExcCode : Integer; MsgLabel : TString);
Begin
  Inc(ExThrowCount);
  ExLastKind := EX_THROW_EMIT;
  WriteLn('  ; throw exception code=', ExcCode);
  WriteLn('  MOV DWORD [_JX_CODE], ', ExcCode);
  WriteLn('  MOV DWORD [_JX_MSG], ', MsgLabel);
  WriteLn('  JMP DWORD [_JX_HANDLER]');
End;

{ ------------------------------------------------------------ }
{ EmitThrowNoHandler : throw sans handler (afficher + exit)      }
{   Affiche le message d erreur et appelle ExitProcess(1)       }
{ ------------------------------------------------------------ }

Procedure EmitThrowNoHandler(ExcCode : Integer; MsgLabel : TString);
Begin
  Inc(ExNoHandlerCount);
  ExLastKind := EX_NO_HANDLER;
  WriteLn('  ; throw without handler - abort');
  WriteLn('  MOV DWORD [_JX_CODE], ', ExcCode);
  WriteLn('  MOV DWORD [_JX_MSG], ', MsgLabel);
  WriteLn('  ; display error message and exit');
  WriteLn('  PUSH ', MsgLabel);
  WriteLn('  CALL _print_str');
  WriteLn('  ADD ESP, 4');
  WriteLn('  PUSH 1');
  WriteLn('  CALL ExitProcess');
End;

{ ------------------------------------------------------------ }
{ EmitHandlerChain : emettre la chaine de tests catch            }
{   Emet le label handler, puis CMP/JE pour chaque catch       }
{   Si aucun catch ne correspond, JMP vers finally ou rethrow   }
{ ------------------------------------------------------------ }

Procedure EmitHandlerChain;
Var I : Integer;
Begin
  If ExStackTop <= 0 Then
    Exit;
  WriteLn(ExStack[ExStackTop].HandlerLabel, ':');
  WriteLn('  ; exception handler chain');
  For I := 1 To ExStack[ExStackTop].CatchCount Do
    EmitCatchTest(ExStack[ExStackTop].Catches[I].ExcCode,
                  ExStack[ExStackTop].Catches[I].AsmLabel);
  { Si aucun catch ne correspond }
  If ExStack[ExStackTop].HasFinally Then
    WriteLn('  JMP ', ExStack[ExStackTop].FinallyLabel)
  Else
  Begin
    WriteLn('  ; uncaught exception - restore and rethrow');
    EmitRestoreHandler;
    WriteLn('  JMP DWORD [_JX_HANDLER]');
  End;
End;

{ ------------------------------------------------------------ }
{ EmitNullPtrException : emettre un test de null pointer         }
{   CMP reg, 0 / JNE ok_label                                  }
{   throw NullPointerException                                  }
{ ------------------------------------------------------------ }

Procedure EmitNullPtrException(Reg, OkLabel : TString);
Begin
  Inc(ExNullPtrCount);
  ExLastKind := EX_NULL_PTR;
  WriteLn('  ; null pointer check');
  WriteLn('  CMP ', Reg, ', 0');
  WriteLn('  JNE ', OkLabel);
  WriteLn('  MOV DWORD [_JX_CODE], ', EXC_NULL_POINTER_EXCEPTION);
  WriteLn('  MOV DWORD [_JX_MSG], _JX_MSG_NULL');
  WriteLn('  JMP DWORD [_JX_HANDLER]');
  WriteLn(OkLabel, ':');
End;

{ ------------------------------------------------------------ }
{ EmitArrayBoundsException : emettre un test de bounds           }
{   CMP index, limit / JB ok_label                             }
{   throw ArrayIndexOutOfBoundsException                        }
{ ------------------------------------------------------------ }

Procedure EmitArrayBoundsException(IdxReg, LenReg, OkLabel : TString);
Begin
  Inc(ExArrayBoundsCount);
  ExLastKind := EX_ARRAY_BOUNDS;
  WriteLn('  ; array bounds check');
  WriteLn('  CMP ', IdxReg, ', 0');
  WriteLn('  JL _JL_AIOOB_', ItoS(ExLabelSeq));
  WriteLn('  CMP ', IdxReg, ', ', LenReg);
  WriteLn('  JL ', OkLabel);
  WriteLn('_JL_AIOOB_', ItoS(ExLabelSeq), ':');
  WriteLn('  MOV DWORD [_JX_CODE], ', EXC_ARRAY_INDEX_OUT_OF_BOUNDS);
  WriteLn('  MOV DWORD [_JX_MSG], _JX_MSG_AIOOB');
  WriteLn('  JMP DWORD [_JX_HANDLER]');
  WriteLn(OkLabel, ':');
End;

{ ------------------------------------------------------------ }
(* ParseTryStmt : parser un try/catch/finally                    *)
(*   try (bloc)                                                  *)
(*     catch (Type1 var1) (bloc1)                                *)
(*     [catch (Type2 var2) (bloc2)]                              *)
(*     [finally (blocF)]                                         *)
{   Genere: save handler, try body, handler chain, catch bodies, }
{     finally, restore handler, end label                       }
{ ------------------------------------------------------------ }

Procedure ParseTryStmt;
Var Line    : Integer;
    NCatches: Integer;
Begin
  Inc(ExTryCount);
  ExLastKind := EX_TRY;
  Line := LexLineNo;

  { Detecter les try imbriques }
  If ExStackTop > 0 Then
    Inc(ExNestedCount);

  { Empiler le contexte try }
  ExPush(Line);

  { Emettre le debut du try }
  EmitTryBegin;

  WriteLn('  ; [try body - statements parsed here]');

  { Fin du bloc try (pas d exception) }
  EmitTryEnd;

  { Emettre la chaine de handlers }
  EmitHandlerChain;

  { Les corps des catch sont emis par ParseCatchClause }
  { Le corps du finally est emis par ParseFinallyClause }

  { Emettre le label de fin }
  NCatches := ExStack[ExStackTop].CatchCount;
  If NCatches > ExMaxCatchesSeen Then
    ExMaxCatchesSeen := NCatches;

  WriteLn(ExStack[ExStackTop].EndLabel, ':');

  { Restaurer le handler precedent }
  EmitRestoreHandler;

  { Depiler le contexte }
  ExPop;
End;

{ ------------------------------------------------------------ }
(* ParseCatchClause : parser un catch (Type var) (bloc)          *)
{   Ajoute le catch au try courant, emet le label et le corps  }
{ ------------------------------------------------------------ }

Procedure ParseCatchClause(const TypeName, VarN : TString);
Var Lbl : TString;
Begin
  ExLastKind := EX_CATCH;
  Lbl := ExAddCatch(TypeName, VarN, LexLineNo);
  If Lbl = '' Then
    Exit;
  EmitExCatchLabel(Lbl, VarN);
  WriteLn('  ; catch (', TypeName, ' ', VarN, ')');
  WriteLn('  ; [catch body - statements parsed here]');
  { Apres le catch, JMP vers finally ou end }
  If ExStackTop > 0 Then
  Begin
    If ExStack[ExStackTop].HasFinally Then
      WriteLn('  JMP ', ExStack[ExStackTop].FinallyLabel)
    Else
      WriteLn('  JMP ', ExStack[ExStackTop].EndLabel);
  End;
End;

{ ------------------------------------------------------------ }
(* ParseFinallyClause : parser un finally (bloc)                 *)
{   Emet le label finally et le corps                           }
{ ------------------------------------------------------------ }

Procedure ParseFinallyClause;
Var Lbl : TString;
Begin
  ExLastKind := EX_FINALLY;
  Lbl := ExSetFinally(LexLineNo);
  If Lbl = '' Then
    Exit;
  EmitFinallyLabel(Lbl);
  WriteLn('  ; [finally body - statements parsed here]');
  { Apres le finally, JMP vers end }
  If ExStackTop > 0 Then
    WriteLn('  JMP ', ExStack[ExStackTop].EndLabel);
End;

{ ------------------------------------------------------------ }
{ ParseThrowStmt : parser un throw new ExcType(msg)              }
{   throw new ExceptionType("message");                         }
{   Emet le throw vers le handler courant                       }
{ ------------------------------------------------------------ }

Procedure ParseThrowStmt(const TypeName, MsgLabel : TString);
Var Code : Integer;
Begin
  ExLastKind := EX_THROW;
  Code := MapExceptionType(TypeName);
  WriteLn('  ; throw new ', TypeName, '(...)');
  If ExStackTop > 0 Then
    EmitThrow(Code, MsgLabel)
  Else
    EmitThrowNoHandler(Code, MsgLabel);
End;

{ ------------------------------------------------------------ }
{ IsInTry : tester si on est actuellement dans un try            }
{ ------------------------------------------------------------ }

Function IsInTry : Boolean;
Begin
  IsInTry := (ExStackTop > 0);
End;

{ ------------------------------------------------------------ }
{ GetExCatchCount : nombre de catch dans le try courant          }
{ ------------------------------------------------------------ }

Function GetExCatchCount : Integer;
Begin
  If ExStackTop <= 0 Then
    GetExCatchCount := 0
  Else
    GetExCatchCount := ExStack[ExStackTop].CatchCount;
End;

{ ------------------------------------------------------------ }
{ GetExHasFinally : True si le try courant a un finally          }
{ ------------------------------------------------------------ }

Function GetExHasFinally : Boolean;
Begin
  If ExStackTop <= 0 Then
    GetExHasFinally := False
  Else
    GetExHasFinally := ExStack[ExStackTop].HasFinally;
End;

{ ------------------------------------------------------------ }
{ GetExEndLabel : obtenir le label de fin du try courant         }
{ ------------------------------------------------------------ }

Function GetExEndLabel : TString;
Begin
  If ExStackTop <= 0 Then
    GetExEndLabel := ''
  Else
    GetExEndLabel := ExStack[ExStackTop].EndLabel;
End;

{ ------------------------------------------------------------ }
{ GetExceptionTypeName : obtenir le nom d un type d exception    }
{   a partir de son code numerique                              }
{ ------------------------------------------------------------ }

Function GetExceptionTypeName(Code : Integer) : TString;
Begin
  Case Code Of
    EXC_EXCEPTION                    : GetExceptionTypeName := 'Exception';
    EXC_RUNTIME_EXCEPTION            : GetExceptionTypeName := 'RuntimeException';
    EXC_NULL_POINTER_EXCEPTION       : GetExceptionTypeName := 'NullPointerException';
    EXC_ARRAY_INDEX_OUT_OF_BOUNDS    : GetExceptionTypeName := 'ArrayIndexOutOfBoundsException';
    EXC_ARITHMETIC_EXCEPTION         : GetExceptionTypeName := 'ArithmeticException';
    EXC_CLASS_CAST_EXCEPTION         : GetExceptionTypeName := 'ClassCastException';
    EXC_ILLEGAL_ARGUMENT_EXCEPTION   : GetExceptionTypeName := 'IllegalArgumentException';
    EXC_ILLEGAL_STATE_EXCEPTION      : GetExceptionTypeName := 'IllegalStateException';
    EXC_INDEX_OUT_OF_BOUNDS_EXCEPTION: GetExceptionTypeName := 'IndexOutOfBoundsException';
    EXC_NUMBER_FORMAT_EXCEPTION      : GetExceptionTypeName := 'NumberFormatException';
    EXC_STRING_INDEX_OUT_OF_BOUNDS   : GetExceptionTypeName := 'StringIndexOutOfBoundsException';
    EXC_UNSUPPORTED_OPERATION        : GetExceptionTypeName := 'UnsupportedOperationException';
    EXC_IO_EXCEPTION                 : GetExceptionTypeName := 'IOException';
    EXC_FILE_NOT_FOUND_EXCEPTION     : GetExceptionTypeName := 'FileNotFoundException';
  Else
    GetExceptionTypeName := 'Exception(' + ItoS(Code) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ DumpExState : afficher l etat du sous-systeme exceptions       }
{ ------------------------------------------------------------ }

Procedure DumpExState;
Var I, J : Integer;
Begin
  WriteLn('--- Exception State ---');
  WriteLn('  ExInitialized      : ', ExInitialized);
  WriteLn('  ExTryCount         : ', ExTryCount);
  WriteLn('  ExCatchCount       : ', ExCatchCount);
  WriteLn('  ExFinallyCount     : ', ExFinallyCount);
  WriteLn('  ExThrowCount       : ', ExThrowCount);
  WriteLn('  ExNoHandlerCount   : ', ExNoHandlerCount);
  WriteLn('  ExNullPtrCount     : ', ExNullPtrCount);
  WriteLn('  ExArrayBoundsCount : ', ExArrayBoundsCount);
  WriteLn('  ExNestedCount      : ', ExNestedCount);
  WriteLn('  ExMaxCatchesSeen   : ', ExMaxCatchesSeen);
  WriteLn('  ExLastKind         : ', ExTypeName(ExLastKind));
  WriteLn('  ExLabelSeq         : ', ExLabelSeq);
  WriteLn('  ExStackTop         : ', ExStackTop);
  For I := 1 To ExStackTop Do
  Begin
    WriteLn('  Try[', I, '] : ', ExStack[I].TryLabel,
            ' (End=', ExStack[I].EndLabel,
            ', Handler=', ExStack[I].HandlerLabel,
            ', Finally=', ExStack[I].FinallyLabel,
            ', Catches=', ExStack[I].CatchCount,
            ', HasFinally=', ExStack[I].HasFinally, ')');
    For J := 1 To ExStack[I].CatchCount Do
      WriteLn('    Catch[', J, '] : Type=', ExStack[I].Catches[J].ExcType,
              ' (Code=', ExStack[I].Catches[J].ExcCode,
              ', Var=', ExStack[I].Catches[J].VarName,
              ', Label=', ExStack[I].Catches[J].AsmLabel, ')');
  End;
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 18)                              }
{ ------------------------------------------------------------ }

Function IsExInitialized : Boolean;
Begin
  IsExInitialized := ExInitialized;
End;

Function IsExEmpty : Boolean;
Begin
  IsExEmpty := (ExTryCount = 0);
End;

Function GetExTryCount : LongInt;
Begin
  GetExTryCount := ExTryCount;
End;

Function GetExCatchTotal : LongInt;
Begin
  GetExCatchTotal := ExCatchCount;
End;

Function GetExFinallyTotal : LongInt;
Begin
  GetExFinallyTotal := ExFinallyCount;
End;

Function GetExThrowTotal : LongInt;
Begin
  GetExThrowTotal := ExThrowCount;
End;

Function GetExNoHandlerTotal : LongInt;
Begin
  GetExNoHandlerTotal := ExNoHandlerCount;
End;

Function GetExMaxCatchesSeen : LongInt;
Begin
  GetExMaxCatchesSeen := ExMaxCatchesSeen;
End;

Function GetExNestedTotal : LongInt;
Begin
  GetExNestedTotal := ExNestedCount;
End;

Function GetExStatus : TString;
Begin
  If Not ExInitialized Then
    GetExStatus := 'Not initialized'
  Else
    GetExStatus := ItoS(ExTryCount) + ' try, ' +
                   ItoS(ExCatchCount) + ' catch, ' +
                   ItoS(ExFinallyCount) + ' finally, ' +
                   ItoS(ExThrowCount) + ' throw, ' +
                   ItoS(ExNoHandlerCount) + ' no-handler, ' +
                   ItoS(ExNullPtrCount) + ' null-ptr, ' +
                   ItoS(ExArrayBoundsCount) + ' array-bounds, ' +
                   ItoS(ExNestedCount) + ' nested';
End;

{ ============================================================ }
{ TODO 19 - PARSEUR : IMPORT ET PACKAGE                        }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { Types d operations import/package }
  IM_NONE            = 0;    { aucun / non defini                    }
  IM_PACKAGE_DECL    = 1;    { package nom.sous_nom;                 }
  IM_IMPORT_SINGLE   = 2;    { import java.util.Scanner;             }
  IM_IMPORT_WILDCARD = 3;    { import java.util.*;                   }
  IM_IMPORT_LANG     = 4;    { import java.lang.*; (implicite)       }
  IM_IMPORT_UTIL     = 5;    { import java.util.*;                   }
  IM_IMPORT_SCANNER  = 6;    { import java.util.Scanner;             }
  IM_IMPORT_UNKNOWN  = 7;    { import non supporte                   }
  IM_CLASS_PUBLIC    = 8;    { classe publique declaree              }
  IM_CLASS_FILE_CHK  = 9;    { verif nom classe = nom fichier        }
  IM_CLASS_RESOLVE   = 10;   { resolution ClassName.method           }
  IM_STATIC_PREFIX   = 11;   { prefixe methode statique              }
  IM_WARN_IMPORT     = 12;   { avertissement import inconnu          }
  IM_SCANNER_ACTIVE  = 13;   { Scanner active par import             }
  IM_MAX             = 13;

  { Limites }
  IM_MAX_IMPORTS     = 32;   { nombre max d imports                  }

Type
  TImImportRec = Record
    PackagePath : TString;   { chemin du package (ex: java.util)     }
    ClassName   : TString;   { nom de classe (ex: Scanner) ou *      }
    FullPath    : TString;   { chemin complet (ex: java.util.Scanner)}
    IsWildcard  : Boolean;   { True si import X.Y.*;                 }
    IsKnown     : Boolean;   { True si import reconnu/supporte       }
    DeclLine    : Integer;   { ligne de declaration                  }
  End;

Var
  ImInitialized     : Boolean;    { True si l etat est initialise       }
  ImPackageName     : TString;    { nom du package declare              }
  ImPackageDeclared : Boolean;    { True si package declare             }
  ImPackageLine     : Integer;    { ligne de la declaration package     }
  ImImportCount     : LongInt;    { nombre total d imports              }
  ImImportTab       : Array[1..IM_MAX_IMPORTS] Of TImImportRec;
  ImScannerActive   : Boolean;    { True si Scanner est active          }
  ImPublicClassName : TString;    { nom de la classe publique           }
  ImPublicClassDeclared : Boolean;{ True si classe publique declaree    }
  ImPublicClassLine : Integer;    { ligne de la classe publique         }
  ImSourceFileName  : TString;    { nom du fichier source sans extension}
  ImWarnCount       : LongInt;    { nombre d avertissements import      }
  ImResolveCount    : LongInt;    { nombre de resolutions de classe     }
  ImLastKind        : Integer;    { dernier type d operation            }
  ImLabelSeq        : Integer;    { sequence pour labels IM             }

{ ------------------------------------------------------------ }
{ InitImState : initialiser le sous-systeme import/package       }
{ ------------------------------------------------------------ }

Procedure InitImState;
Var I : Integer;
Begin
  ImInitialized     := True;
  ImPackageName     := '';
  ImPackageDeclared := False;
  ImPackageLine     := 0;
  ImImportCount     := 0;
  ImScannerActive   := False;
  ImPublicClassName := '';
  ImPublicClassDeclared := False;
  ImPublicClassLine := 0;
  ImSourceFileName  := '';
  ImWarnCount       := 0;
  ImResolveCount    := 0;
  ImLastKind        := IM_NONE;
  ImLabelSeq        := 0;
  For I := 1 To IM_MAX_IMPORTS Do
  Begin
    ImImportTab[I].PackagePath := '';
    ImImportTab[I].ClassName   := '';
    ImImportTab[I].FullPath    := '';
    ImImportTab[I].IsWildcard  := False;
    ImImportTab[I].IsKnown     := False;
    ImImportTab[I].DeclLine    := 0;
  End;
End;

{ ------------------------------------------------------------ }
{ GenImLabel : generer un label unique pour import/package        }
{ ------------------------------------------------------------ }

Function GenImLabel : TString;
Begin
  Inc(ImLabelSeq);
  GenImLabel := '_JL_IM_' + ItoS(ImLabelSeq);
End;

{ ------------------------------------------------------------ }
{ ImTypeName : nom textuel d un type d operation import           }
{ ------------------------------------------------------------ }

Function ImTypeName(K : Integer) : TString;
Begin
  Case K Of
    IM_NONE            : ImTypeName := 'IM_NONE';
    IM_PACKAGE_DECL    : ImTypeName := 'IM_PACKAGE_DECL';
    IM_IMPORT_SINGLE   : ImTypeName := 'IM_IMPORT_SINGLE';
    IM_IMPORT_WILDCARD : ImTypeName := 'IM_IMPORT_WILDCARD';
    IM_IMPORT_LANG     : ImTypeName := 'IM_IMPORT_LANG';
    IM_IMPORT_UTIL     : ImTypeName := 'IM_IMPORT_UTIL';
    IM_IMPORT_SCANNER  : ImTypeName := 'IM_IMPORT_SCANNER';
    IM_IMPORT_UNKNOWN  : ImTypeName := 'IM_IMPORT_UNKNOWN';
    IM_CLASS_PUBLIC    : ImTypeName := 'IM_CLASS_PUBLIC';
    IM_CLASS_FILE_CHK  : ImTypeName := 'IM_CLASS_FILE_CHK';
    IM_CLASS_RESOLVE   : ImTypeName := 'IM_CLASS_RESOLVE';
    IM_STATIC_PREFIX   : ImTypeName := 'IM_STATIC_PREFIX';
    IM_WARN_IMPORT     : ImTypeName := 'IM_WARN_IMPORT';
    IM_SCANNER_ACTIVE  : ImTypeName := 'IM_SCANNER_ACTIVE';
  Else
    ImTypeName := 'IM_UNKNOWN(' + ItoS(K) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ IsKnownImport : tester si un chemin d import est reconnu       }
{   Reconnait java.lang.*, java.util.*, java.util.Scanner      }
{ ------------------------------------------------------------ }

Function IsKnownImport(const FullPath : TString) : Boolean;
Begin
  If FullPath = 'java.lang.*' Then
    IsKnownImport := True
  Else If FullPath = 'java.util.*' Then
    IsKnownImport := True
  Else If FullPath = 'java.util.Scanner' Then
    IsKnownImport := True
  Else If FullPath = 'java.util.ArrayList' Then
    IsKnownImport := True
  Else If FullPath = 'java.util.Arrays' Then
    IsKnownImport := True
  Else If FullPath = 'java.io.*' Then
    IsKnownImport := True
  Else
    IsKnownImport := False;
End;

{ ------------------------------------------------------------ }
{ ActivatesScanner : tester si un import active Scanner          }
{   java.util.* ou java.util.Scanner activent Scanner           }
{ ------------------------------------------------------------ }

Function ActivatesScanner(const FullPath : TString) : Boolean;
Begin
  If FullPath = 'java.util.*' Then
    ActivatesScanner := True
  Else If FullPath = 'java.util.Scanner' Then
    ActivatesScanner := True
  Else
    ActivatesScanner := False;
End;

{ ------------------------------------------------------------ }
{ ExtractPackagePath : extraire le chemin du package              }
{   "java.util.Scanner" -> "java.util"                          }
{   "java.lang.*" -> "java.lang"                                }
{ ------------------------------------------------------------ }

Function ExtractPackagePath(const FullPath : TString) : TString;
Var I : Integer;
    LastDot : Integer;
Begin
  LastDot := 0;
  For I := 1 To Length(FullPath) Do
    If FullPath[I] = '.' Then
      LastDot := I;
  If LastDot > 0 Then
    ExtractPackagePath := Copy(FullPath, 1, LastDot - 1)
  Else
    ExtractPackagePath := FullPath;
End;

{ ------------------------------------------------------------ }
{ ExtractClassName : extraire le nom de classe d un import       }
{   "java.util.Scanner" -> "Scanner"                            }
{   "java.lang.*" -> "*"                                        }
{ ------------------------------------------------------------ }

Function ExtractClassName(const FullPath : TString) : TString;
Var I : Integer;
    LastDot : Integer;
Begin
  LastDot := 0;
  For I := 1 To Length(FullPath) Do
    If FullPath[I] = '.' Then
      LastDot := I;
  If LastDot > 0 Then
    ExtractClassName := Copy(FullPath, LastDot + 1,
                             Length(FullPath) - LastDot)
  Else
    ExtractClassName := FullPath;
End;

{ ------------------------------------------------------------ }
{ ParsePackageDecl : parser une declaration package               }
{   package nom.sous_nom;                                       }
{   Enregistre le nom du package (ignore pour code gen)         }
{ ------------------------------------------------------------ }

Procedure ParsePackageDecl(const PkgName : TString; Line : Integer);
Begin
  ImLastKind := IM_PACKAGE_DECL;
  If ImPackageDeclared Then
  Begin
    WarnMsg('duplicate package declaration (ignored)');
    Exit;
  End;
  ImPackageName     := PkgName;
  ImPackageDeclared := True;
  ImPackageLine     := Line;
  WriteLn('  ; package ', PkgName, ' (ignored for code gen)');
End;

{ ------------------------------------------------------------ }
{ ParseImportDecl : parser une declaration import                 }
{   import java.util.Scanner;                                   }
{   import java.util.*;                                         }
{   import java.lang.*;                                         }
{   Enregistre l import dans la table et active les features    }
{ ------------------------------------------------------------ }

Procedure ParseImportDecl(const FullPath : TString; Line : Integer);
Var PkgPath   : TString;
    ClsName   : TString;
    IsWild    : Boolean;
    Known     : Boolean;
Begin
  { Extraire les composants }
  PkgPath := ExtractPackagePath(FullPath);
  ClsName := ExtractClassName(FullPath);
  IsWild  := (ClsName = '*');
  Known   := IsKnownImport(FullPath);

  { Determiner le type d import }
  If FullPath = 'java.lang.*' Then
  Begin
    ImLastKind := IM_IMPORT_LANG;
    WriteLn('  ; import java.lang.* (implicit, ignored)');
  End
  Else If (FullPath = 'java.util.*') Then
  Begin
    ImLastKind := IM_IMPORT_UTIL;
    WriteLn('  ; import java.util.* (Scanner activated)');
  End
  Else If (FullPath = 'java.util.Scanner') Then
  Begin
    ImLastKind := IM_IMPORT_SCANNER;
    WriteLn('  ; import java.util.Scanner');
  End
  Else If IsWild Then
  Begin
    ImLastKind := IM_IMPORT_WILDCARD;
    WriteLn('  ; import ', FullPath, ' (wildcard)');
  End
  Else If Known Then
  Begin
    ImLastKind := IM_IMPORT_SINGLE;
    WriteLn('  ; import ', FullPath);
  End
  Else
  Begin
    ImLastKind := IM_IMPORT_UNKNOWN;
    Inc(ImWarnCount);
    WarnMsg('unsupported import: ' + FullPath);
    WriteLn('  ; import ', FullPath, ' (unsupported, warning)');
  End;

  { Ajouter a la table }
  If ImImportCount < IM_MAX_IMPORTS Then
  Begin
    Inc(ImImportCount);
    ImImportTab[ImImportCount].PackagePath := PkgPath;
    ImImportTab[ImImportCount].ClassName   := ClsName;
    ImImportTab[ImImportCount].FullPath    := FullPath;
    ImImportTab[ImImportCount].IsWildcard  := IsWild;
    ImImportTab[ImImportCount].IsKnown     := Known;
    ImImportTab[ImImportCount].DeclLine    := Line;
  End
  Else
    WarnMsg('import table full, ignoring: ' + FullPath);

  { Activer Scanner si applicable }
  If ActivatesScanner(FullPath) Then
  Begin
    ImScannerActive := True;
    ImLastKind := IM_SCANNER_ACTIVE;
  End;
End;

{ ------------------------------------------------------------ }
{ RegisterPublicClass : enregistrer la classe publique           }
{   Une seule classe publique par fichier                       }
{ ------------------------------------------------------------ }

Procedure RegisterPublicClass(const ClsName : TString;
                              Line : Integer);
Begin
  ImLastKind := IM_CLASS_PUBLIC;
  If ImPublicClassDeclared Then
  Begin
    CompileError('only one public class per file (already: ' +
                 ImPublicClassName + ')', Line);
    Exit;
  End;
  ImPublicClassName     := ClsName;
  ImPublicClassDeclared := True;
  ImPublicClassLine     := Line;
  WriteLn('  ; public class ', ClsName);
End;

{ ------------------------------------------------------------ }
{ CheckClassFileName : verifier que le nom de la classe publique }
{   correspond au nom du fichier source                         }
{ ------------------------------------------------------------ }

Procedure CheckClassFileName(const ClsName, FileName : TString;
                             Line : Integer);
Var BaseName : TString;
    I, DotPos : Integer;
Begin
  ImLastKind := IM_CLASS_FILE_CHK;
  { Extraire le nom de base du fichier (sans extension) }
  DotPos := 0;
  For I := Length(FileName) DownTo 1 Do
    If FileName[I] = '.' Then
    Begin
      DotPos := I;
      Break;
    End;
  If DotPos > 0 Then
    BaseName := Copy(FileName, 1, DotPos - 1)
  Else
    BaseName := FileName;
  { Comparer }
  If ClsName <> BaseName Then
    WarnMsg('public class ' + ClsName +
                   ' should be in file ' + ClsName + '.java');
End;

{ ------------------------------------------------------------ }
{ SetImSourceFile : definir le nom du fichier source             }
{   Extrait le nom de base (sans extension et sans chemin)      }
{ ------------------------------------------------------------ }

Procedure SetImSourceFile(const FileName : TString);
Var I, DotPos, SlashPos : Integer;
    BaseName : TString;
Begin
  { Trouver le dernier separateur de chemin }
  SlashPos := 0;
  For I := Length(FileName) DownTo 1 Do
    If (FileName[I] = '/') Or (FileName[I] = '\') Then
    Begin
      SlashPos := I;
      Break;
    End;
  If SlashPos > 0 Then
    BaseName := Copy(FileName, SlashPos + 1,
                     Length(FileName) - SlashPos)
  Else
    BaseName := FileName;
  { Enlever l extension }
  DotPos := 0;
  For I := Length(BaseName) DownTo 1 Do
    If BaseName[I] = '.' Then
    Begin
      DotPos := I;
      Break;
    End;
  If DotPos > 0 Then
    ImSourceFileName := Copy(BaseName, 1, DotPos - 1)
  Else
    ImSourceFileName := BaseName;
End;

{ ------------------------------------------------------------ }
{ ResolveClassPrefix : resoudre le prefixe d une classe          }
{   ClassName.methodName -> retourne le prefixe de la classe    }
{   Pour les methodes statiques de la classe courante           }
{ ------------------------------------------------------------ }

Function ResolveClassPrefix(const ClsName : TString) : TString;
Begin
  Inc(ImResolveCount);
  ImLastKind := IM_CLASS_RESOLVE;
  { Pour la classe courante, pas de prefixe }
  If ImPublicClassDeclared And (ClsName = ImPublicClassName) Then
  Begin
    ImLastKind := IM_STATIC_PREFIX;
    ResolveClassPrefix := '';
  End
  Else
    ResolveClassPrefix := ClsName + '_';
End;

{ ------------------------------------------------------------ }
{ IsImportedClass : tester si une classe est importee            }
{   Verifie dans la table d imports                             }
{ ------------------------------------------------------------ }

Function IsImportedClass(const ClsName : TString) : Boolean;
Var I : Integer;
Begin
  IsImportedClass := False;
  { Verifier les imports explicites }
  For I := 1 To ImImportCount Do
  Begin
    If ImImportTab[I].ClassName = ClsName Then
    Begin
      IsImportedClass := True;
      Exit;
    End;
    { Pour les imports wildcard, toujours considerer comme importe }
    If ImImportTab[I].IsWildcard And ImImportTab[I].IsKnown Then
    Begin
      IsImportedClass := True;
      Exit;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ GetImPackageName : retourner le nom du package declare         }
{ ------------------------------------------------------------ }

Function GetImPackageName : TString;
Begin
  If ImPackageDeclared Then
    GetImPackageName := ImPackageName
  Else
    GetImPackageName := '';
End;

{ ------------------------------------------------------------ }
{ GetImImportPath : obtenir le chemin complet d un import        }
{   par son index (1..ImImportCount)                            }
{ ------------------------------------------------------------ }

Function GetImImportPath(Idx : Integer) : TString;
Begin
  If (Idx >= 1) And (Idx <= ImImportCount) Then
    GetImImportPath := ImImportTab[Idx].FullPath
  Else
    GetImImportPath := '';
End;

{ ------------------------------------------------------------ }
{ IsScannerImported : tester si Scanner est active par import    }
{ ------------------------------------------------------------ }

Function IsScannerImported : Boolean;
Begin
  IsScannerImported := ImScannerActive;
End;

{ ------------------------------------------------------------ }
{ GetPublicClassName : retourner le nom de la classe publique    }
{ ------------------------------------------------------------ }

Function GetPublicClassName : TString;
Begin
  If ImPublicClassDeclared Then
    GetPublicClassName := ImPublicClassName
  Else
    GetPublicClassName := '';
End;

{ ------------------------------------------------------------ }
{ DumpImState : afficher l etat du sous-systeme import/package   }
{ ------------------------------------------------------------ }

Procedure DumpImState;
Var I : Integer;
Begin
  WriteLn('--- Import/Package State ---');
  WriteLn('  ImInitialized      : ', ImInitialized);
  WriteLn('  ImPackageDeclared  : ', ImPackageDeclared);
  WriteLn('  ImPackageName      : ', ImPackageName);
  WriteLn('  ImPackageLine      : ', ImPackageLine);
  WriteLn('  ImImportCount      : ', ImImportCount);
  WriteLn('  ImScannerActive    : ', ImScannerActive);
  WriteLn('  ImPublicClassDecl  : ', ImPublicClassDeclared);
  WriteLn('  ImPublicClassName  : ', ImPublicClassName);
  WriteLn('  ImPublicClassLine  : ', ImPublicClassLine);
  WriteLn('  ImSourceFileName   : ', ImSourceFileName);
  WriteLn('  ImWarnCount        : ', ImWarnCount);
  WriteLn('  ImResolveCount     : ', ImResolveCount);
  WriteLn('  ImLastKind         : ', ImTypeName(ImLastKind));
  WriteLn('  ImLabelSeq         : ', ImLabelSeq);
  For I := 1 To ImImportCount Do
    WriteLn('  Import[', I, '] : ', ImImportTab[I].FullPath,
            ' (Pkg=', ImImportTab[I].PackagePath,
            ', Cls=', ImImportTab[I].ClassName,
            ', Wild=', ImImportTab[I].IsWildcard,
            ', Known=', ImImportTab[I].IsKnown,
            ', Line=', ImImportTab[I].DeclLine, ')');
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 19)                              }
{ ------------------------------------------------------------ }

Function IsImInitialized : Boolean;
Begin
  IsImInitialized := ImInitialized;
End;

Function IsImEmpty : Boolean;
Begin
  IsImEmpty := (ImImportCount = 0) And (Not ImPackageDeclared);
End;

Function GetImImportCount : LongInt;
Begin
  GetImImportCount := ImImportCount;
End;

Function GetImWarnCount : LongInt;
Begin
  GetImWarnCount := ImWarnCount;
End;

Function GetImResolveCount : LongInt;
Begin
  GetImResolveCount := ImResolveCount;
End;

Function IsImPackageDeclared : Boolean;
Begin
  IsImPackageDeclared := ImPackageDeclared;
End;

Function IsImPublicClassDeclared : Boolean;
Begin
  IsImPublicClassDeclared := ImPublicClassDeclared;
End;

Function IsImScannerActive : Boolean;
Begin
  IsImScannerActive := ImScannerActive;
End;

Function GetImLastKind : Integer;
Begin
  GetImLastKind := ImLastKind;
End;

Function GetImStatus : TString;
Begin
  If Not ImInitialized Then
    GetImStatus := 'Not initialized'
  Else
    GetImStatus := ItoS(ImImportCount) + ' imports, ' +
                   ItoS(ImWarnCount) + ' warnings, ' +
                   ItoS(ImResolveCount) + ' resolves, ' +
                   'pkg=' + ImPackageName + ', ' +
                   'scanner=' + ItoS(Ord(ImScannerActive)) + ', ' +
                   'class=' + ImPublicClassName;
End;

{ ============================================================ }
{ TODO 20 - PARSEUR : CONVERSIONS DE TYPES ET CASTS            }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { Types d operations conversion/cast }
  CV_NONE              = 0;    { aucun / non defini                    }
  CV_CAST_INT_CHAR     = 1;    { (char) intExpr                        }
  CV_CAST_CHAR_INT     = 2;    { (int) charExpr                        }
  CV_CAST_INT_BOOL     = 3;    { (boolean) intExpr                     }
  CV_PROMO_CHAR_INT    = 4;    { char->int promotion automatique       }
  CV_IMPL_INT_STR      = 5;    { int->String dans concatenation        }
  CV_IMPL_BOOL_STR     = 6;    { boolean->String dans println          }
  CV_IMPL_CHAR_STR     = 7;    { char->String dans println             }
  CV_PARSE_INT         = 8;    { Integer.parseInt(s)                   }
  CV_VALUE_OF          = 9;    { String.valueOf(n)                     }
  CV_CHECK_ASSIGN      = 10;   { verif types affectation               }
  CV_CHECK_BOOL_COND   = 11;   { verif condition booleenne             }
  CV_WARN_LOSSY        = 12;   { avertissement cast perdant            }
  CV_CAST_EXPLICIT     = 13;   { cast explicite quelconque             }
  CV_MAX               = 13;

  { Limites }
  CV_MAX_CASTS         = 64;   { nombre max de casts enregistres       }

Type
  TCvCastRec = Record
    SrcType  : Integer;        { type source (TYK_*)                   }
    DstType  : Integer;        { type destination (TYK_*)              }
    Kind     : Integer;        { type de conversion CV_*               }
    Line     : Integer;        { ligne dans le source                  }
    IsLossy  : Boolean;        { True si potentiellement perdant       }
  End;

Var
  CvInitialized      : Boolean;    { True si l etat est initialise       }
  CvCastCount        : LongInt;    { nombre total de casts enregistres   }
  CvCastTab          : Array[1..CV_MAX_CASTS] Of TCvCastRec;
  CvImplicitCount    : LongInt;    { conversions implicites              }
  CvExplicitCount    : LongInt;    { casts explicites                    }
  CvParseIntCount    : LongInt;    { appels Integer.parseInt             }
  CvValueOfCount     : LongInt;    { appels String.valueOf               }
  CvCheckCount       : LongInt;    { verifications de types              }
  CvWarnCount        : LongInt;    { avertissements cast                 }
  CvPromoCount       : LongInt;    { promotions automatiques             }
  CvBoolCondCount    : LongInt;    { verifs condition booleenne          }
  CvAssignCheckCount : LongInt;    { verifs affectation                  }
  CvLastKind         : Integer;    { dernier type d operation            }
  CvLabelSeq         : Integer;    { sequence pour labels CV             }

{ ------------------------------------------------------------ }
{ InitCvState : initialiser le sous-systeme conversions/casts    }
{ ------------------------------------------------------------ }

Procedure InitCvState;
Var I : Integer;
Begin
  CvInitialized      := True;
  CvCastCount        := 0;
  CvImplicitCount    := 0;
  CvExplicitCount    := 0;
  CvParseIntCount    := 0;
  CvValueOfCount     := 0;
  CvCheckCount       := 0;
  CvWarnCount        := 0;
  CvPromoCount       := 0;
  CvBoolCondCount    := 0;
  CvAssignCheckCount := 0;
  CvLastKind         := CV_NONE;
  CvLabelSeq         := 0;
  For I := 1 To CV_MAX_CASTS Do
  Begin
    CvCastTab[I].SrcType := 0;
    CvCastTab[I].DstType := 0;
    CvCastTab[I].Kind    := CV_NONE;
    CvCastTab[I].Line    := 0;
    CvCastTab[I].IsLossy := False;
  End;
End;

{ ------------------------------------------------------------ }
{ GenCvLabel : generer un label unique pour conversions           }
{ ------------------------------------------------------------ }

Function GenCvLabel : TString;
Begin
  Inc(CvLabelSeq);
  GenCvLabel := '_JL_CV_' + ItoS(CvLabelSeq);
End;

{ ------------------------------------------------------------ }
{ CvTypeName : nom textuel d un type d operation conversion      }
{ ------------------------------------------------------------ }

Function CvTypeName(K : Integer) : TString;
Begin
  Case K Of
    CV_NONE              : CvTypeName := 'CV_NONE';
    CV_CAST_INT_CHAR     : CvTypeName := 'CV_CAST_INT_CHAR';
    CV_CAST_CHAR_INT     : CvTypeName := 'CV_CAST_CHAR_INT';
    CV_CAST_INT_BOOL     : CvTypeName := 'CV_CAST_INT_BOOL';
    CV_PROMO_CHAR_INT    : CvTypeName := 'CV_PROMO_CHAR_INT';
    CV_IMPL_INT_STR      : CvTypeName := 'CV_IMPL_INT_STR';
    CV_IMPL_BOOL_STR     : CvTypeName := 'CV_IMPL_BOOL_STR';
    CV_IMPL_CHAR_STR     : CvTypeName := 'CV_IMPL_CHAR_STR';
    CV_PARSE_INT         : CvTypeName := 'CV_PARSE_INT';
    CV_VALUE_OF          : CvTypeName := 'CV_VALUE_OF';
    CV_CHECK_ASSIGN      : CvTypeName := 'CV_CHECK_ASSIGN';
    CV_CHECK_BOOL_COND   : CvTypeName := 'CV_CHECK_BOOL_COND';
    CV_WARN_LOSSY        : CvTypeName := 'CV_WARN_LOSSY';
    CV_CAST_EXPLICIT     : CvTypeName := 'CV_CAST_EXPLICIT';
  Else
    CvTypeName := 'CV_UNKNOWN(' + ItoS(K) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ AddCvCast : enregistrer un cast dans la table                  }
{ ------------------------------------------------------------ }

Procedure AddCvCast(Src, Dst, Kind, Line : Integer;
                    Lossy : Boolean);
Begin
  CvLastKind := Kind;
  If CvCastCount < CV_MAX_CASTS Then
  Begin
    Inc(CvCastCount);
    CvCastTab[CvCastCount].SrcType := Src;
    CvCastTab[CvCastCount].DstType := Dst;
    CvCastTab[CvCastCount].Kind    := Kind;
    CvCastTab[CvCastCount].Line    := Line;
    CvCastTab[CvCastCount].IsLossy := Lossy;
  End;
End;

{ ------------------------------------------------------------ }
{ IsValidCast : tester si un cast est valide entre deux types    }
{   Retourne True si le cast est autorise                       }
{ ------------------------------------------------------------ }

Function IsValidCast(Src, Dst : Integer) : Boolean;
Begin
  IsValidCast := False;
  { Meme type : toujours valide }
  If Src = Dst Then
  Begin
    IsValidCast := True;
    Exit;
  End;
  { int -> char : valide (troncature) }
  If (Src = TYK_INT) And (Dst = TYK_CHAR) Then
  Begin
    IsValidCast := True;
    Exit;
  End;
  { char -> int : valide (promotion) }
  If (Src = TYK_CHAR) And (Dst = TYK_INT) Then
  Begin
    IsValidCast := True;
    Exit;
  End;
  { int -> boolean : valide (0=false, else=true) }
  If (Src = TYK_INT) And (Dst = TYK_BOOLEAN) Then
  Begin
    IsValidCast := True;
    Exit;
  End;
  { boolean -> int : valide (true=1, false=0) }
  If (Src = TYK_BOOLEAN) And (Dst = TYK_INT) Then
  Begin
    IsValidCast := True;
    Exit;
  End;
  { char -> boolean : via int }
  If (Src = TYK_CHAR) And (Dst = TYK_BOOLEAN) Then
  Begin
    IsValidCast := True;
    Exit;
  End;
End;

{ ------------------------------------------------------------ }
{ IsLossyCast : tester si un cast est potentiellement perdant    }
{ ------------------------------------------------------------ }

Function IsLossyCast(Src, Dst : Integer) : Boolean;
Begin
  IsLossyCast := False;
  { int -> char : perte possible (troncature a 8 bits) }
  If (Src = TYK_INT) And (Dst = TYK_CHAR) Then
    IsLossyCast := True
  { int -> boolean : perte possible (perte de valeur) }
  Else If (Src = TYK_INT) And (Dst = TYK_BOOLEAN) Then
    IsLossyCast := True;
End;

{ ------------------------------------------------------------ }
{ GetCastReturnType : obtenir le type de retour d un cast        }
{   Retourne le TYK_* du type destination                       }
{ ------------------------------------------------------------ }

Function GetCastReturnType(DstTypeName : TString) : Integer;
Begin
  If DstTypeName = 'int' Then
    GetCastReturnType := TYK_INT
  Else If DstTypeName = 'char' Then
    GetCastReturnType := TYK_CHAR
  Else If DstTypeName = 'boolean' Then
    GetCastReturnType := TYK_BOOLEAN
  Else If DstTypeName = 'String' Then
    GetCastReturnType := TYK_STRING
  Else
    GetCastReturnType := TYK_INT;
End;

{ ------------------------------------------------------------ }
{ EmitCastCharToInt : (int) charExpr                             }
{   MOVZX EAX, AL  (valeur entiere du char)                    }
{ ------------------------------------------------------------ }

Procedure EmitCastCharToInt(Line : Integer);
Begin
  CvLastKind := CV_CAST_CHAR_INT;
  Inc(CvExplicitCount);
  AddCvCast(TYK_CHAR, TYK_INT, CV_CAST_CHAR_INT, Line, False);
  WriteLn('  ; cast (int) charExpr');
  WriteLn('  MOVZX EAX, AL');
End;

{ ------------------------------------------------------------ }
{ EmitCastIntToChar : (char) intExpr                             }
{   AND EAX, 0FFh  (tronquer a 8 bits)                         }
{ ------------------------------------------------------------ }

Procedure EmitCastIntToChar(Line : Integer);
Begin
  CvLastKind := CV_CAST_INT_CHAR;
  Inc(CvExplicitCount);
  AddCvCast(TYK_INT, TYK_CHAR, CV_CAST_INT_CHAR, Line, True);
  WriteLn('  ; cast (char) intExpr');
  WriteLn('  AND EAX, 0FFh');
End;

{ ------------------------------------------------------------ }
{ EmitCastIntToBool : (boolean) intExpr                          }
{   TEST EAX, EAX / SETNZ AL / MOVZX EAX, AL                  }
{ ------------------------------------------------------------ }

Procedure EmitCastIntToBool(Line : Integer);
Begin
  CvLastKind := CV_CAST_INT_BOOL;
  Inc(CvExplicitCount);
  AddCvCast(TYK_INT, TYK_BOOLEAN, CV_CAST_INT_BOOL, Line, True);
  WriteLn('  ; cast (boolean) intExpr');
  WriteLn('  TEST EAX, EAX');
  WriteLn('  SETNZ AL');
  WriteLn('  MOVZX EAX, AL');
End;

{ ------------------------------------------------------------ }
{ EmitPromoCharToInt : promotion automatique char -> int          }
{   MOVZX EAX, AL                                              }
{ ------------------------------------------------------------ }

Procedure EmitPromoCharToInt(Line : Integer);
Begin
  CvLastKind := CV_PROMO_CHAR_INT;
  Inc(CvImplicitCount);
  Inc(CvPromoCount);
  AddCvCast(TYK_CHAR, TYK_INT, CV_PROMO_CHAR_INT, Line, False);
  WriteLn('  ; promo char -> int');
  WriteLn('  MOVZX EAX, AL');
End;

{ ------------------------------------------------------------ }
{ EmitImplIntToStr : conversion implicite int -> String           }
{   via CALL _JRT_ITOA (resultat dans EAX = ptr chaine)        }
{ ------------------------------------------------------------ }

Procedure EmitImplIntToStr(Line : Integer);
Begin
  CvLastKind := CV_IMPL_INT_STR;
  Inc(CvImplicitCount);
  AddCvCast(TYK_INT, TYK_STRING, CV_IMPL_INT_STR, Line, False);
  WriteLn('  ; implicit int -> String via _JRT_ITOA');
  WriteLn('  PUSH EAX');
  WriteLn('  CALL _JRT_ITOA');
  WriteLn('  ADD ESP, 4');
End;

{ ------------------------------------------------------------ }
{ EmitImplBoolToStr : conversion implicite boolean -> String     }
{   CMP EAX, 0 -> selectionner "true" ou "false"               }
{ ------------------------------------------------------------ }

Procedure EmitImplBoolToStr(Line : Integer);
Var LblTrue, LblEnd : TString;
Begin
  CvLastKind := CV_IMPL_BOOL_STR;
  Inc(CvImplicitCount);
  AddCvCast(TYK_BOOLEAN, TYK_STRING, CV_IMPL_BOOL_STR,
            Line, False);
  LblTrue := GenCvLabel;
  LblEnd  := GenCvLabel;
  WriteLn('  ; implicit boolean -> String');
  WriteLn('  CMP EAX, 0');
  WriteLn('  JNE ', LblTrue);
  WriteLn('  MOV EAX, OFFSET _JK_FALSE');
  WriteLn('  JMP ', LblEnd);
  WriteLn(LblTrue, ':');
  WriteLn('  MOV EAX, OFFSET _JK_TRUE');
  WriteLn(LblEnd, ':');
End;

{ ------------------------------------------------------------ }
{ EmitImplCharToStr : conversion implicite char -> String        }
{   Stocker le caractere + null dans un tampon temporaire       }
{ ------------------------------------------------------------ }

Procedure EmitImplCharToStr(Line : Integer);
Begin
  CvLastKind := CV_IMPL_CHAR_STR;
  Inc(CvImplicitCount);
  AddCvCast(TYK_CHAR, TYK_STRING, CV_IMPL_CHAR_STR,
            Line, False);
  WriteLn('  ; implicit char -> String (1-char buffer)');
  WriteLn('  MOV BYTE PTR [_JX_CV_BUF], AL');
  WriteLn('  MOV BYTE PTR [_JX_CV_BUF+1], 0');
  WriteLn('  LEA EAX, [_JX_CV_BUF]');
End;

{ ------------------------------------------------------------ }
{ EmitParseInt : Integer.parseInt(s)                              }
{   CALL _JRT_ATOI -> EAX = valeur entiere                     }
{ ------------------------------------------------------------ }

Procedure EmitParseInt(Line : Integer);
Begin
  CvLastKind := CV_PARSE_INT;
  Inc(CvParseIntCount);
  AddCvCast(TYK_STRING, TYK_INT, CV_PARSE_INT, Line, False);
  WriteLn('  ; Integer.parseInt(s) -> CALL _JRT_ATOI');
  WriteLn('  PUSH EAX');
  WriteLn('  CALL _JRT_ATOI');
  WriteLn('  ADD ESP, 4');
End;

{ ------------------------------------------------------------ }
{ EmitValueOf : String.valueOf(n)                                 }
{   CALL _JRT_ITOA -> EAX = ptr chaine                         }
{ ------------------------------------------------------------ }

Procedure EmitValueOf(Line : Integer);
Begin
  CvLastKind := CV_VALUE_OF;
  Inc(CvValueOfCount);
  AddCvCast(TYK_INT, TYK_STRING, CV_VALUE_OF, Line, False);
  WriteLn('  ; String.valueOf(n) -> CALL _JRT_ITOA');
  WriteLn('  PUSH EAX');
  WriteLn('  CALL _JRT_ITOA');
  WriteLn('  ADD ESP, 4');
End;

{ ------------------------------------------------------------ }
{ EmitCastExplicit : emettre un cast explicite generique          }
{   Determine le type de cast et emet le code correspondant     }
{ ------------------------------------------------------------ }

Procedure EmitCastExplicit(SrcType, DstType, Line : Integer);
Begin
  CvLastKind := CV_CAST_EXPLICIT;
  If (SrcType = TYK_CHAR) And (DstType = TYK_INT) Then
    EmitCastCharToInt(Line)
  Else If (SrcType = TYK_INT) And (DstType = TYK_CHAR) Then
    EmitCastIntToChar(Line)
  Else If (SrcType = TYK_INT) And (DstType = TYK_BOOLEAN) Then
    EmitCastIntToBool(Line)
  Else If (SrcType = TYK_BOOLEAN) And (DstType = TYK_INT) Then
  Begin
    Inc(CvExplicitCount);
    AddCvCast(TYK_BOOLEAN, TYK_INT, CV_CAST_EXPLICIT,
              Line, False);
    WriteLn('  ; cast (int) boolExpr (already 0 or 1)');
  End
  Else If SrcType = DstType Then
  Begin
    Inc(CvExplicitCount);
    AddCvCast(SrcType, DstType, CV_CAST_EXPLICIT, Line, False);
    WriteLn('  ; cast to same type (no-op)');
  End
  Else
  Begin
    Inc(CvExplicitCount);
    Inc(CvWarnCount);
    AddCvCast(SrcType, DstType, CV_CAST_EXPLICIT, Line, True);
    WarnMsg('unsupported cast from type ' + ItoS(SrcType) +
            ' to type ' + ItoS(DstType));
  End;
End;

{ ------------------------------------------------------------ }
{ ParseCastExprCv : parser un cast explicite (type) expr         }
{   Retourne le TYK_* du type destination                       }
{ ------------------------------------------------------------ }

Function ParseCastExprCv(const TypeName : TString;
                         SrcType, Line : Integer) : Integer;
Var DstType : Integer;
    Lossy   : Boolean;
Begin
  DstType := GetCastReturnType(TypeName);
  Lossy   := IsLossyCast(SrcType, DstType);

  If Not IsValidCast(SrcType, DstType) Then
  Begin
    CompileError('invalid cast from ' + TypeKindStr(SrcType) +
                 ' to ' + TypeName, Line);
    ParseCastExprCv := DstType;
    Exit;
  End;

  If Lossy Then
  Begin
    Inc(CvWarnCount);
    CvLastKind := CV_WARN_LOSSY;
    WarnMsg('potentially lossy cast from ' +
            TypeKindStr(SrcType) + ' to ' + TypeName);
  End;

  EmitCastExplicit(SrcType, DstType, Line);
  ParseCastExprCv := DstType;
End;

{ ------------------------------------------------------------ }
{ ParseParseIntCall : parser Integer.parseInt(expr)               }
{   Emet le code pour convertir String -> int                   }
{ ------------------------------------------------------------ }

Procedure ParseParseIntCall(Line : Integer);
Begin
  CvLastKind := CV_PARSE_INT;
  WriteLn('  ; Integer.parseInt(...)');
  EmitParseInt(Line);
End;

{ ------------------------------------------------------------ }
{ ParseValueOfCall : parser String.valueOf(expr)                  }
{   Emet le code pour convertir int -> String                   }
{ ------------------------------------------------------------ }

Procedure ParseValueOfCall(Line : Integer);
Begin
  CvLastKind := CV_VALUE_OF;
  WriteLn('  ; String.valueOf(...)');
  EmitValueOf(Line);
End;

{ ------------------------------------------------------------ }
{ CheckAssignCompat : verifier la compatibilite de types pour    }
{   une affectation                                             }
{   Retourne True si compatible, False sinon                    }
{ ------------------------------------------------------------ }

Function CheckAssignCompat(LhsType, RhsType,
                           Line : Integer) : Boolean;
Begin
  Inc(CvCheckCount);
  Inc(CvAssignCheckCount);
  CvLastKind := CV_CHECK_ASSIGN;
  CheckAssignCompat := True;

  { Meme type : toujours compatible }
  If LhsType = RhsType Then
    Exit;

  { null assignable a String, Object, Array }
  If RhsType = TYK_NULL Then
  Begin
    If (LhsType = TYK_STRING) Or (LhsType = TYK_OBJECT) Or
       (LhsType = TYK_ARRAY) Then
      Exit;
  End;

  { char -> int : promotion implicite autorisee }
  If (RhsType = TYK_CHAR) And (LhsType = TYK_INT) Then
    Exit;

  { int -> char dans affectation : autorise avec avertissement }
  If (RhsType = TYK_INT) And (LhsType = TYK_CHAR) Then
  Begin
    Inc(CvWarnCount);
    WarnMsg('implicit narrowing from int to char');
    Exit;
  End;

  { boolean -> int ou int -> boolean : incompatible en Java }
  CheckAssignCompat := False;
  CompileError('incompatible types: cannot assign ' +
               TypeKindStr(RhsType) + ' to ' +
               TypeKindStr(LhsType), Line);
End;

{ ------------------------------------------------------------ }
{ CheckBoolCondition : verifier qu une expression est booleenne  }
{   Utilise dans if, while, do-while, for                       }
{   Retourne True si le type est boolean ou implicitement conv  }
{ ------------------------------------------------------------ }

Function CheckBoolCondition(ExprType, Line : Integer) : Boolean;
Begin
  Inc(CvCheckCount);
  Inc(CvBoolCondCount);
  CvLastKind := CV_CHECK_BOOL_COND;
  CheckBoolCondition := True;

  If ExprType = TYK_BOOLEAN Then
    Exit;

  { int et char sont acceptes comme condition (style C) }
  { mais avec un avertissement }
  If (ExprType = TYK_INT) Or (ExprType = TYK_CHAR) Then
  Begin
    Inc(CvWarnCount);
    WarnMsg('non-boolean condition (type: ' +
            TypeKindStr(ExprType) + ')');
    Exit;
  End;

  { String, Object, etc. : erreur }
  CheckBoolCondition := False;
  CompileError('boolean expression expected, got ' +
               TypeKindStr(ExprType), Line);
End;

{ ------------------------------------------------------------ }
{ EmitImplicitConversion : emettre une conversion implicite      }
{   selon les types source et destination                       }
{ ------------------------------------------------------------ }

Procedure EmitImplicitConversion(SrcType, DstType,
                                 Line : Integer);
Begin
  If SrcType = DstType Then
    Exit;

  { char -> int : promotion }
  If (SrcType = TYK_CHAR) And (DstType = TYK_INT) Then
    EmitPromoCharToInt(Line)
  { int -> String : dans concatenation }
  Else If (SrcType = TYK_INT) And (DstType = TYK_STRING) Then
    EmitImplIntToStr(Line)
  { boolean -> String : dans println }
  Else If (SrcType = TYK_BOOLEAN) And (DstType = TYK_STRING) Then
    EmitImplBoolToStr(Line)
  { char -> String : dans println }
  Else If (SrcType = TYK_CHAR) And (DstType = TYK_STRING) Then
    EmitImplCharToStr(Line)
  Else
  Begin
    Inc(CvImplicitCount);
    WriteLn('  ; implicit conversion ', TypeKindStr(SrcType),
            ' -> ', TypeKindStr(DstType), ' (no-op)');
  End;
End;

{ ------------------------------------------------------------ }
{ IsParseIntCall : tester si un appel est Integer.parseInt        }
{ ------------------------------------------------------------ }

Function IsParseIntCall(const ClsName, MethName : TString)
                        : Boolean;
Begin
  IsParseIntCall := (ClsName = 'Integer') And
                    (MethName = 'parseInt');
End;

{ ------------------------------------------------------------ }
{ IsValueOfCall : tester si un appel est String.valueOf           }
{ ------------------------------------------------------------ }

Function IsValueOfCall(const ClsName, MethName : TString)
                       : Boolean;
Begin
  IsValueOfCall := (ClsName = 'String') And
                   (MethName = 'valueOf');
End;

{ ------------------------------------------------------------ }
{ GetConversionKind : determiner le type de conversion entre     }
{   deux types                                                  }
{ ------------------------------------------------------------ }

Function GetConversionKind(SrcType, DstType : Integer) : Integer;
Begin
  GetConversionKind := CV_NONE;
  If SrcType = DstType Then
    Exit;
  If (SrcType = TYK_CHAR) And (DstType = TYK_INT) Then
    GetConversionKind := CV_PROMO_CHAR_INT
  Else If (SrcType = TYK_INT) And (DstType = TYK_CHAR) Then
    GetConversionKind := CV_CAST_INT_CHAR
  Else If (SrcType = TYK_INT) And (DstType = TYK_BOOLEAN) Then
    GetConversionKind := CV_CAST_INT_BOOL
  Else If (SrcType = TYK_INT) And (DstType = TYK_STRING) Then
    GetConversionKind := CV_IMPL_INT_STR
  Else If (SrcType = TYK_BOOLEAN) And (DstType = TYK_STRING) Then
    GetConversionKind := CV_IMPL_BOOL_STR
  Else If (SrcType = TYK_CHAR) And (DstType = TYK_STRING) Then
    GetConversionKind := CV_IMPL_CHAR_STR;
End;

{ ------------------------------------------------------------ }
{ DumpCvState : afficher l etat du sous-systeme conversions      }
{ ------------------------------------------------------------ }

Procedure DumpCvState;
Var I : Integer;
Begin
  WriteLn('--- Conversion/Cast State ---');
  WriteLn('  CvInitialized      : ', CvInitialized);
  WriteLn('  CvCastCount        : ', CvCastCount);
  WriteLn('  CvImplicitCount    : ', CvImplicitCount);
  WriteLn('  CvExplicitCount    : ', CvExplicitCount);
  WriteLn('  CvParseIntCount    : ', CvParseIntCount);
  WriteLn('  CvValueOfCount     : ', CvValueOfCount);
  WriteLn('  CvCheckCount       : ', CvCheckCount);
  WriteLn('  CvWarnCount        : ', CvWarnCount);
  WriteLn('  CvPromoCount       : ', CvPromoCount);
  WriteLn('  CvBoolCondCount    : ', CvBoolCondCount);
  WriteLn('  CvAssignCheckCount : ', CvAssignCheckCount);
  WriteLn('  CvLastKind         : ', CvTypeName(CvLastKind));
  WriteLn('  CvLabelSeq         : ', CvLabelSeq);
  For I := 1 To CvCastCount Do
    WriteLn('  Cast[', I, '] : ',
            TypeKindStr(CvCastTab[I].SrcType), ' -> ',
            TypeKindStr(CvCastTab[I].DstType),
            ' (', CvTypeName(CvCastTab[I].Kind), ')',
            ' line=', CvCastTab[I].Line,
            ' lossy=', CvCastTab[I].IsLossy);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 20)                              }
{ ------------------------------------------------------------ }

Function IsCvInitialized : Boolean;
Begin
  IsCvInitialized := CvInitialized;
End;

Function IsCvEmpty : Boolean;
Begin
  IsCvEmpty := (CvCastCount = 0) And (CvImplicitCount = 0);
End;

Function GetCvCastCount : LongInt;
Begin
  GetCvCastCount := CvCastCount;
End;

Function GetCvImplicitCount : LongInt;
Begin
  GetCvImplicitCount := CvImplicitCount;
End;

Function GetCvExplicitCount : LongInt;
Begin
  GetCvExplicitCount := CvExplicitCount;
End;

Function GetCvParseIntCount : LongInt;
Begin
  GetCvParseIntCount := CvParseIntCount;
End;

Function GetCvValueOfCount : LongInt;
Begin
  GetCvValueOfCount := CvValueOfCount;
End;

Function GetCvWarnCount : LongInt;
Begin
  GetCvWarnCount := CvWarnCount;
End;

Function GetCvLastKind : Integer;
Begin
  GetCvLastKind := CvLastKind;
End;

Function GetCvStatus : TString;
Begin
  If Not CvInitialized Then
    GetCvStatus := 'Not initialized'
  Else
    GetCvStatus := ItoS(CvCastCount) + ' casts, ' +
                   ItoS(CvImplicitCount) + ' implicit, ' +
                   ItoS(CvExplicitCount) + ' explicit, ' +
                   ItoS(CvParseIntCount) + ' parseInt, ' +
                   ItoS(CvValueOfCount) + ' valueOf, ' +
                   ItoS(CvWarnCount) + ' warnings';
End;

{ ============================================================ }
{ TODO 21 - GENERATION DE CODE : SEGMENT DE DONNEES 80386     }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { Types d elements du segment DATA }
  DT_NONE              = 0;    { aucun / non defini                    }
  DT_STATIC_INT        = 1;    { champ statique int : DD 0             }
  DT_STATIC_BOOL       = 2;    { champ statique boolean : DD 0         }
  DT_STATIC_CHAR       = 3;    { champ statique char : DD 0            }
  DT_STATIC_STRING     = 4;    { champ statique String : DD ptr        }
  DT_STRING_CONST      = 5;    { constante chaine : DB 'x', 0          }
  DT_FORMAT_CONST      = 6;    { constante de format : DB '...', 0     }
  DT_SPECIAL_TRUE      = 7;    { _JK_TRUE : DB 'true', 0               }
  DT_SPECIAL_FALSE     = 8;    { _JK_FALSE : DB 'false', 0             }
  DT_SPECIAL_NULL      = 9;    { _JK_NULL : DB 'null', 0               }
  DT_SPECIAL_CRLF      = 10;   { _JK_CRLF : DB 13, 10, 0               }
  DT_SPECIAL_SPACE     = 11;   { _JK_SPACE : DB ' ', 0                 }
  DT_BSS_IOBUF         = 12;   { _J_IOBUF : DB 256 DUP(?)              }
  DT_BSS_NUMBUF        = 13;   { _J_NUMBUF : DB 32 DUP(?)              }
  DT_RT_STDOUT         = 14;   { _J_STDOUT : DD ?                      }
  DT_RT_STDIN          = 15;   { _J_STDIN : DD ?                       }
  DT_RT_WRITTEN        = 16;   { _J_WRITTEN : DD ?                     }
  DT_RT_READ           = 17;   { _J_READ : DD ?                        }
  DT_HEAP_AREA         = 18;   { _J_HEAP : DB 65536 DUP(0)             }
  DT_HEAP_TOP          = 19;   { _J_HEAPTOP : DD 0                     }
  DT_ARRAY_BLOCK       = 20;   { bloc de DD avec compteur              }
  DT_MAX               = 20;

  { Limites }
  DT_MAX_STATIC_FIELDS = 256;  { nombre max de champs statiques        }
  DT_MAX_STRING_CONST  = 512;  { nombre max de constantes chaines      }
  DT_MAX_FORMAT_CONST  = 64;   { nombre max de constantes de format    }
  DT_HEAP_SIZE         = 65536;{ taille du heap en octets              }
  DT_IOBUF_SIZE        = 256;  { taille du buffer I/O                  }
  DT_NUMBUF_SIZE       = 32;   { taille du buffer numerique            }
  DT_DWORD_ALIGN       = 4;    { alignement DWORD (4 octets)           }

Type
  TDtStaticField = Record
    ClassName  : TString;      { nom de la classe proprietaire         }
    FieldName  : TString;      { nom du champ                          }
    FieldType  : Integer;      { type TYK_*                            }
    AsmLabel   : TString;      { label ASM _JV_Class_field             }
    InitValue  : LongInt;      { valeur initiale (int/bool/char)       }
    InitStrIdx : Integer;      { idx chaine init (si String)           }
    Line       : Integer;      { ligne de declaration                  }
  End;

  TDtStringConst = Record
    Value      : TString;      { contenu de la chaine                  }
    AsmLabel   : TString;      { label ASM _JK_N                       }
    Length     : Integer;      { longueur sans le NUL                  }
    IsFormat   : Boolean;      { True si format (printf-style)         }
    RefCount   : Integer;      { nombre de references                  }
  End;

  TDtFormatConst = Record
    Format     : TString;      { chaine de format                      }
    AsmLabel   : TString;      { label ASM _JK_FMT_N                   }
    ArgCount   : Integer;      { nombre d arguments attendus           }
  End;

Var
  DtInitialized      : Boolean;    { True si l etat est initialise       }
  DtStaticFields     : Array[1..DT_MAX_STATIC_FIELDS] Of TDtStaticField;
  DtStaticCount      : Integer;    { nombre de champs statiques          }
  DtStringConsts     : Array[1..DT_MAX_STRING_CONST] Of TDtStringConst;
  DtStringCount      : Integer;    { nombre de constantes chaines        }
  DtFormatConsts     : Array[1..DT_MAX_FORMAT_CONST] Of TDtFormatConst;
  DtFormatCount      : Integer;    { nombre de constantes de format      }
  DtSpecialEmitted   : Boolean;    { True si constantes speciales emises }
  DtBssEmitted       : Boolean;    { True si section BSS emise           }
  DtRuntimeEmitted   : Boolean;    { True si vars runtime emises         }
  DtHeapEmitted      : Boolean;    { True si heap emis                   }
  DtLabelSeq         : Integer;    { sequence pour labels DT             }
  DtTotalBytes       : LongInt;    { total octets segment DATA           }
  DtBssBytes         : LongInt;    { total octets segment BSS            }
  DtLastType         : Integer;    { dernier type d element              }

{ ------------------------------------------------------------ }
{ InitDtState : initialiser le sous-systeme segment de donnees  }
{ ------------------------------------------------------------ }

Procedure InitDtState;
Var I : Integer;
Begin
  DtInitialized      := True;
  DtStaticCount      := 0;
  DtStringCount      := 0;
  DtFormatCount      := 0;
  DtSpecialEmitted   := False;
  DtBssEmitted       := False;
  DtRuntimeEmitted   := False;
  DtHeapEmitted      := False;
  DtLabelSeq         := 0;
  DtTotalBytes       := 0;
  DtBssBytes         := 0;
  DtLastType         := DT_NONE;
  For I := 1 To DT_MAX_STATIC_FIELDS Do
  Begin
    DtStaticFields[I].ClassName  := '';
    DtStaticFields[I].FieldName  := '';
    DtStaticFields[I].FieldType  := TYK_INT;
    DtStaticFields[I].AsmLabel   := '';
    DtStaticFields[I].InitValue  := 0;
    DtStaticFields[I].InitStrIdx := -1;
    DtStaticFields[I].Line       := 0;
  End;
  For I := 1 To DT_MAX_STRING_CONST Do
  Begin
    DtStringConsts[I].Value    := '';
    DtStringConsts[I].AsmLabel := '';
    DtStringConsts[I].Length   := 0;
    DtStringConsts[I].IsFormat := False;
    DtStringConsts[I].RefCount := 0;
  End;
  For I := 1 To DT_MAX_FORMAT_CONST Do
  Begin
    DtFormatConsts[I].Format   := '';
    DtFormatConsts[I].AsmLabel := '';
    DtFormatConsts[I].ArgCount := 0;
  End;
End;

{ ------------------------------------------------------------ }
{ GenDtLabel : generer un label unique pour segment donnees      }
{ ------------------------------------------------------------ }

Function GenDtLabel : TString;
Begin
  Inc(DtLabelSeq);
  GenDtLabel := '_JL_DT_' + ItoS(DtLabelSeq);
End;

{ ------------------------------------------------------------ }
{ DtTypeName : nom textuel d un type d element DATA              }
{ ------------------------------------------------------------ }

Function DtTypeName(K : Integer) : TString;
Begin
  Case K Of
    DT_NONE              : DtTypeName := 'DT_NONE';
    DT_STATIC_INT        : DtTypeName := 'DT_STATIC_INT';
    DT_STATIC_BOOL       : DtTypeName := 'DT_STATIC_BOOL';
    DT_STATIC_CHAR       : DtTypeName := 'DT_STATIC_CHAR';
    DT_STATIC_STRING     : DtTypeName := 'DT_STATIC_STRING';
    DT_STRING_CONST      : DtTypeName := 'DT_STRING_CONST';
    DT_FORMAT_CONST      : DtTypeName := 'DT_FORMAT_CONST';
    DT_SPECIAL_TRUE      : DtTypeName := 'DT_SPECIAL_TRUE';
    DT_SPECIAL_FALSE     : DtTypeName := 'DT_SPECIAL_FALSE';
    DT_SPECIAL_NULL      : DtTypeName := 'DT_SPECIAL_NULL';
    DT_SPECIAL_CRLF      : DtTypeName := 'DT_SPECIAL_CRLF';
    DT_SPECIAL_SPACE     : DtTypeName := 'DT_SPECIAL_SPACE';
    DT_BSS_IOBUF         : DtTypeName := 'DT_BSS_IOBUF';
    DT_BSS_NUMBUF        : DtTypeName := 'DT_BSS_NUMBUF';
    DT_RT_STDOUT         : DtTypeName := 'DT_RT_STDOUT';
    DT_RT_STDIN          : DtTypeName := 'DT_RT_STDIN';
    DT_RT_WRITTEN        : DtTypeName := 'DT_RT_WRITTEN';
    DT_RT_READ           : DtTypeName := 'DT_RT_READ';
    DT_HEAP_AREA         : DtTypeName := 'DT_HEAP_AREA';
    DT_HEAP_TOP          : DtTypeName := 'DT_HEAP_TOP';
    DT_ARRAY_BLOCK       : DtTypeName := 'DT_ARRAY_BLOCK';
  Else
    DtTypeName := 'DT_UNKNOWN(' + ItoS(K) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ RegisterStaticField : enregistrer un champ statique            }
{   Retourne l indice ou -1 si table pleine                      }
{ ------------------------------------------------------------ }

Function RegisterStaticField(Const ClassName, FieldName : TString;
                             FieldType : Integer;
                             InitVal : LongInt;
                             InitStrIdx, Line : Integer) : Integer;
Var Idx : Integer;
    Lbl : TString;
Begin
  If DtStaticCount >= DT_MAX_STATIC_FIELDS Then
  Begin
    CompileError('static fields table full (max ' +
                 ItoS(DT_MAX_STATIC_FIELDS) + ')', Line);
    RegisterStaticField := -1;
    Exit;
  End;
  Inc(DtStaticCount);
  Idx := DtStaticCount;
  Lbl := '_JV_' + AsmIdent(ClassName) + '_' + AsmIdent(FieldName);
  DtStaticFields[Idx].ClassName  := ClassName;
  DtStaticFields[Idx].FieldName  := FieldName;
  DtStaticFields[Idx].FieldType  := FieldType;
  DtStaticFields[Idx].AsmLabel   := Lbl;
  DtStaticFields[Idx].InitValue  := InitVal;
  DtStaticFields[Idx].InitStrIdx := InitStrIdx;
  DtStaticFields[Idx].Line       := Line;
  DtLastType := DT_STATIC_INT;
  If FieldType = TYK_BOOLEAN Then DtLastType := DT_STATIC_BOOL
  Else If FieldType = TYK_CHAR Then DtLastType := DT_STATIC_CHAR
  Else If FieldType = TYK_STRING Then DtLastType := DT_STATIC_STRING;
  Inc(DtTotalBytes, DT_DWORD_ALIGN);
  RegisterStaticField := Idx;
End;

{ ------------------------------------------------------------ }
{ RegisterStringConst : enregistrer une constante chaine         }
{   Retourne l indice ou -1 si table pleine                      }
{   Si la chaine existe deja, retourne l indice existant         }
{ ------------------------------------------------------------ }

Function RegisterStringConst(Const Value : TString;
                             IsFormat : Boolean) : Integer;
Var I, Idx : Integer;
    Lbl    : TString;
Begin
  { Verifier si la chaine existe deja }
  For I := 1 To DtStringCount Do
  Begin
    If DtStringConsts[I].Value = Value Then
    Begin
      Inc(DtStringConsts[I].RefCount);
      RegisterStringConst := I;
      Exit;
    End;
  End;

  { Ajouter une nouvelle chaine }
  If DtStringCount >= DT_MAX_STRING_CONST Then
  Begin
    CompileError('string constants table full (max ' +
                 ItoS(DT_MAX_STRING_CONST) + ')', LexLineNo);
    RegisterStringConst := -1;
    Exit;
  End;
  Inc(DtStringCount);
  Idx := DtStringCount;
  Lbl := '_JK_' + ItoS(Idx);
  DtStringConsts[Idx].Value    := Value;
  DtStringConsts[Idx].AsmLabel := Lbl;
  DtStringConsts[Idx].Length   := Length(Value);
  DtStringConsts[Idx].IsFormat := IsFormat;
  DtStringConsts[Idx].RefCount := 1;
  DtLastType := DT_STRING_CONST;
  Inc(DtTotalBytes, Length(Value) + 1);
  { Alignement sur DWORD si necessaire }
  While (DtTotalBytes Mod DT_DWORD_ALIGN) <> 0 Do
    Inc(DtTotalBytes);
  RegisterStringConst := Idx;
End;

{ ------------------------------------------------------------ }
{ RegisterFormatConst : enregistrer une constante de format      }
{   Retourne l indice ou -1 si table pleine                      }
{ ------------------------------------------------------------ }

Function RegisterFormatConst(Const Fmt : TString;
                             ArgCount : Integer) : Integer;
Var Idx : Integer;
    Lbl : TString;
Begin
  If DtFormatCount >= DT_MAX_FORMAT_CONST Then
  Begin
    CompileError('format constants table full (max ' +
                 ItoS(DT_MAX_FORMAT_CONST) + ')', LexLineNo);
    RegisterFormatConst := -1;
    Exit;
  End;
  Inc(DtFormatCount);
  Idx := DtFormatCount;
  Lbl := '_JK_FMT_' + ItoS(Idx);
  DtFormatConsts[Idx].Format   := Fmt;
  DtFormatConsts[Idx].AsmLabel := Lbl;
  DtFormatConsts[Idx].ArgCount := ArgCount;
  DtLastType := DT_FORMAT_CONST;
  Inc(DtTotalBytes, Length(Fmt) + 1);
  While (DtTotalBytes Mod DT_DWORD_ALIGN) <> 0 Do
    Inc(DtTotalBytes);
  RegisterFormatConst := Idx;
End;

{ ------------------------------------------------------------ }
{ FindStaticField : trouver un champ statique par nom            }
{   Retourne l indice ou -1 si non trouve                        }
{ ------------------------------------------------------------ }

Function FindStaticField(Const ClassName, FieldName : TString) : Integer;
Var I : Integer;
Begin
  FindStaticField := -1;
  For I := 1 To DtStaticCount Do
  Begin
    If (DtStaticFields[I].ClassName = ClassName) And
       (DtStaticFields[I].FieldName = FieldName) Then
    Begin
      FindStaticField := I;
      Exit;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ FindStringConst : trouver une constante chaine par valeur      }
{   Retourne l indice ou -1 si non trouve                        }
{ ------------------------------------------------------------ }

Function FindStringConst(Const Value : TString) : Integer;
Var I : Integer;
Begin
  FindStringConst := -1;
  For I := 1 To DtStringCount Do
  Begin
    If DtStringConsts[I].Value = Value Then
    Begin
      FindStringConst := I;
      Exit;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ GetStaticFieldLabel : obtenir le label ASM d un champ statique }
{ ------------------------------------------------------------ }

Function GetStaticFieldLabel(Idx : Integer) : TString;
Begin
  If (Idx >= 1) And (Idx <= DtStaticCount) Then
    GetStaticFieldLabel := DtStaticFields[Idx].AsmLabel
  Else
    GetStaticFieldLabel := '';
End;

{ ------------------------------------------------------------ }
{ GetStringConstLabel : obtenir le label ASM d une constante     }
{ ------------------------------------------------------------ }

Function GetStringConstLabel(Idx : Integer) : TString;
Begin
  If (Idx >= 1) And (Idx <= DtStringCount) Then
    GetStringConstLabel := DtStringConsts[Idx].AsmLabel
  Else
    GetStringConstLabel := '';
End;

{ ------------------------------------------------------------ }
{ EscapeAsmString : echapper une chaine pour assembleur MASM     }
{   Remplace les caracteres speciaux par leur code ASCII        }
{ ------------------------------------------------------------ }

Function EscapeAsmString(Const S : TString) : TString;
Var I       : Integer;
    Ch      : Char;
    Res     : TString;
    InQuote : Boolean;
Begin
  Res := '';
  InQuote := False;
  For I := 1 To Length(S) Do
  Begin
    Ch := S[I];
    { Caracteres imprimables normaux (sauf guillemets) }
    If (Ord(Ch) >= 32) And (Ord(Ch) <= 126) And
       (Ch <> '''') And (Ch <> '"') Then
    Begin
      If Not InQuote Then
      Begin
        If Res <> '' Then Res := Res + ', ';
        Res := Res + '''';
        InQuote := True;
      End;
      Res := Res + Ch;
    End
    Else
    Begin
      { Caractere special ou guillemet -> code ASCII numerique }
      If InQuote Then
      Begin
        Res := Res + '''';
        InQuote := False;
      End;
      If Res <> '' Then Res := Res + ', ';
      Res := Res + ItoS(Ord(Ch));
    End;
  End;
  { Fermer la derniere chaine si ouverte }
  If InQuote Then
    Res := Res + '''';
  EscapeAsmString := Res;
End;

{ ------------------------------------------------------------ }
{ EmitSpecialConstants : emettre les constantes speciales        }
{   _JK_TRUE, _JK_FALSE, _JK_NULL, _JK_CRLF, _JK_SPACE          }
{ ------------------------------------------------------------ }

Procedure EmitSpecialConstants;
Begin
  If DtSpecialEmitted Then Exit;
  DtSpecialEmitted := True;
  WriteLn('  ; --- Constantes speciales ---');
  WriteLn('_JK_TRUE   DB ''true'', 0');
  DtLastType := DT_SPECIAL_TRUE;
  Inc(DtTotalBytes, 5);
  WriteLn('_JK_FALSE  DB ''false'', 0');
  DtLastType := DT_SPECIAL_FALSE;
  Inc(DtTotalBytes, 6);
  WriteLn('_JK_NULL   DB ''null'', 0');
  DtLastType := DT_SPECIAL_NULL;
  Inc(DtTotalBytes, 5);
  WriteLn('_JK_CRLF   DB 13, 10, 0');
  DtLastType := DT_SPECIAL_CRLF;
  Inc(DtTotalBytes, 3);
  WriteLn('_JK_SPACE  DB '' '', 0');
  DtLastType := DT_SPECIAL_SPACE;
  Inc(DtTotalBytes, 2);
  { Alignement }
  WriteLn('           ALIGN 4');
  While (DtTotalBytes Mod DT_DWORD_ALIGN) <> 0 Do
    Inc(DtTotalBytes);
End;

{ ------------------------------------------------------------ }
{ EmitStaticFieldData : emettre les champs statiques             }
{ ------------------------------------------------------------ }

Procedure EmitStaticFieldData;
Var I : Integer;
Begin
  If DtStaticCount = 0 Then Exit;
  WriteLn('  ; --- Champs statiques ---');
  For I := 1 To DtStaticCount Do
  Begin
    Write(DtStaticFields[I].AsmLabel, ' DD ');
    Case DtStaticFields[I].FieldType Of
      TYK_INT, TYK_BOOLEAN, TYK_CHAR:
        WriteLn(DtStaticFields[I].InitValue);
      TYK_STRING:
        Begin
          If DtStaticFields[I].InitStrIdx > 0 Then
            WriteLn('OFFSET ',
                    DtStringConsts[DtStaticFields[I].InitStrIdx].AsmLabel)
          Else
            WriteLn('0');
        End;
    Else
      WriteLn('0');
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ EmitStringData : emettre les constantes chaines                }
{ ------------------------------------------------------------ }

Procedure EmitStringData;
Var I     : Integer;
    Esc   : TString;
Begin
  If DtStringCount = 0 Then Exit;
  WriteLn('  ; --- Constantes chaines ---');
  For I := 1 To DtStringCount Do
  Begin
    Esc := EscapeAsmString(DtStringConsts[I].Value);
    If Length(Esc) = 0 Then
      WriteLn(DtStringConsts[I].AsmLabel, ' DB 0')
    Else
      WriteLn(DtStringConsts[I].AsmLabel, ' DB ', Esc, ', 0');
  End;
  WriteLn('           ALIGN 4');
End;

{ ------------------------------------------------------------ }
{ EmitFormatData : emettre les constantes de format              }
{ ------------------------------------------------------------ }

Procedure EmitFormatData;
Var I   : Integer;
    Esc : TString;
Begin
  If DtFormatCount = 0 Then Exit;
  WriteLn('  ; --- Constantes de format ---');
  For I := 1 To DtFormatCount Do
  Begin
    Esc := EscapeAsmString(DtFormatConsts[I].Format);
    If Length(Esc) = 0 Then
      WriteLn(DtFormatConsts[I].AsmLabel, ' DB 0')
    Else
      WriteLn(DtFormatConsts[I].AsmLabel, ' DB ', Esc, ', 0');
  End;
  WriteLn('           ALIGN 4');
End;

{ ------------------------------------------------------------ }
{ EmitHeapArea : emettre le heap dynamique                       }
{ ------------------------------------------------------------ }

Procedure EmitHeapArea;
Begin
  If DtHeapEmitted Then Exit;
  DtHeapEmitted := True;
  WriteLn('  ; --- Heap dynamique ---');
  WriteLn('_J_HEAP    DB ', DT_HEAP_SIZE, ' DUP(0)');
  WriteLn('_J_HEAPTOP DD 0');
  DtLastType := DT_HEAP_TOP;
  Inc(DtTotalBytes, DT_HEAP_SIZE + 4);
End;

{ ------------------------------------------------------------ }
{ EmitArrayData : emettre un bloc de donnees pour tableau        }
{   Format: compteur (DD) suivi des elements (DD chaque)        }
{ ------------------------------------------------------------ }

Procedure EmitArrayData(Const Lbl : TString; ElemCount : Integer);
Var I : Integer;
Begin
  WriteLn('  ; tableau ', Lbl, ' [', ElemCount, ' elements]');
  WriteLn(Lbl, ':');
  WriteLn('  DD ', ElemCount, '  ; compteur elements');
  For I := 1 To ElemCount Do
    WriteLn('  DD 0');
  DtLastType := DT_ARRAY_BLOCK;
  Inc(DtTotalBytes, (ElemCount + 1) * 4);
End;

{ ------------------------------------------------------------ }
{ EmitDataSection : emettre la section .data complete            }
{ ------------------------------------------------------------ }

Procedure EmitDataSection;
Begin
  WriteLn('; ============================================================');
  WriteLn('; Section .data (variables initialisees)');
  WriteLn('; ============================================================');
  WriteLn('.DATA');
  WriteLn;
  EmitSpecialConstants;
  WriteLn;
  EmitStaticFieldData;
  WriteLn;
  EmitStringData;
  WriteLn;
  EmitFormatData;
  WriteLn;
  EmitHeapArea;
  WriteLn;
End;

{ ------------------------------------------------------------ }
{ EmitRuntimeVars : emettre les variables runtime dans BSS       }
{ ------------------------------------------------------------ }

Procedure EmitRuntimeVars;
Begin
  If DtRuntimeEmitted Then Exit;
  DtRuntimeEmitted := True;
  WriteLn('  ; --- Variables runtime ---');
  WriteLn('_J_STDOUT  DD ?');
  DtLastType := DT_RT_STDOUT;
  Inc(DtBssBytes, 4);
  WriteLn('_J_STDIN   DD ?');
  DtLastType := DT_RT_STDIN;
  Inc(DtBssBytes, 4);
  WriteLn('_J_WRITTEN DD ?');
  DtLastType := DT_RT_WRITTEN;
  Inc(DtBssBytes, 4);
  WriteLn('_J_READ    DD ?');
  DtLastType := DT_RT_READ;
  Inc(DtBssBytes, 4);
End;

{ ------------------------------------------------------------ }
{ EmitBssSection : emettre la section .data? (BSS)               }
{ ------------------------------------------------------------ }

Procedure EmitBssSection;
Begin
  If DtBssEmitted Then Exit;
  DtBssEmitted := True;
  WriteLn('; ============================================================');
  WriteLn('; Section .data? (BSS - variables non initialisees)');
  WriteLn('; ============================================================');
  WriteLn('.DATA?');
  WriteLn;
  WriteLn('  ; --- Buffers I/O ---');
  WriteLn('_J_IOBUF   DB ', DT_IOBUF_SIZE, ' DUP(?)');
  DtLastType := DT_BSS_IOBUF;
  Inc(DtBssBytes, DT_IOBUF_SIZE);
  WriteLn('_J_NUMBUF  DB ', DT_NUMBUF_SIZE, ' DUP(?)');
  DtLastType := DT_BSS_NUMBUF;
  Inc(DtBssBytes, DT_NUMBUF_SIZE);
  WriteLn;
  EmitRuntimeVars;
  WriteLn;
  { Buffer pour conversion char->String }
  WriteLn('  ; --- Buffer conversion ---');
  WriteLn('_JX_CV_BUF DB 4 DUP(?)');
  Inc(DtBssBytes, 4);
  WriteLn;
End;

{ ------------------------------------------------------------ }
{ EmitDataSectionComplete : emettre DATA + BSS                   }
{ ------------------------------------------------------------ }

Procedure EmitDataSectionComplete;
Begin
  EmitDataSection;
  EmitBssSection;
End;

{ ------------------------------------------------------------ }
{ GetDtStaticFieldType : obtenir le type d un champ statique     }
{ ------------------------------------------------------------ }

Function GetDtStaticFieldType(Idx : Integer) : Integer;
Begin
  If (Idx >= 1) And (Idx <= DtStaticCount) Then
    GetDtStaticFieldType := DtStaticFields[Idx].FieldType
  Else
    GetDtStaticFieldType := TYK_INT;
End;

{ ------------------------------------------------------------ }
{ DumpDtState : afficher l etat du sous-systeme DATA             }
{ ------------------------------------------------------------ }

Procedure DumpDtState;
Var I : Integer;
Begin
  WriteLn('--- DtState dump ---');
  WriteLn('  DtInitialized     : ', DtInitialized);
  WriteLn('  DtStaticCount     : ', DtStaticCount);
  WriteLn('  DtStringCount     : ', DtStringCount);
  WriteLn('  DtFormatCount     : ', DtFormatCount);
  WriteLn('  DtTotalBytes      : ', DtTotalBytes);
  WriteLn('  DtBssBytes        : ', DtBssBytes);
  WriteLn('  DtSpecialEmitted  : ', DtSpecialEmitted);
  WriteLn('  DtBssEmitted      : ', DtBssEmitted);
  WriteLn('  DtRuntimeEmitted  : ', DtRuntimeEmitted);
  WriteLn('  DtHeapEmitted     : ', DtHeapEmitted);
  WriteLn('  DtLastType        : ', DtTypeName(DtLastType));
  If DtStaticCount > 0 Then
  Begin
    WriteLn('  --- Champs statiques ---');
    For I := 1 To DtStaticCount Do
      WriteLn('    [', I, '] ', DtStaticFields[I].ClassName, '.',
              DtStaticFields[I].FieldName, ' : ',
              TypeKindStr(DtStaticFields[I].FieldType), ' = ',
              DtStaticFields[I].AsmLabel);
  End;
  If DtStringCount > 0 Then
  Begin
    WriteLn('  --- Constantes chaines ---');
    For I := 1 To DtStringCount Do
      WriteLn('    [', I, '] ', DtStringConsts[I].AsmLabel, ' = "',
              DtStringConsts[I].Value, '" (refs=',
              DtStringConsts[I].RefCount, ')');
  End;
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
  IsDtEmpty := (DtStaticCount = 0) And (DtStringCount = 0) And
               (DtFormatCount = 0);
End;

Function GetDtStaticCount : LongInt;
Begin
  GetDtStaticCount := DtStaticCount;
End;

Function GetDtStringCount : LongInt;
Begin
  GetDtStringCount := DtStringCount;
End;

Function GetDtFormatCount : LongInt;
Begin
  GetDtFormatCount := DtFormatCount;
End;

Function GetDtTotalBytes : LongInt;
Begin
  GetDtTotalBytes := DtTotalBytes;
End;

Function GetDtBssBytes : LongInt;
Begin
  GetDtBssBytes := DtBssBytes;
End;

Function GetDtLabelSeq : LongInt;
Begin
  GetDtLabelSeq := DtLabelSeq;
End;

Function GetDtLastType : Integer;
Begin
  GetDtLastType := DtLastType;
End;

Function GetDtStatus : TString;
Begin
  If Not DtInitialized Then
    GetDtStatus := 'Not initialized'
  Else
    GetDtStatus := ItoS(DtStaticCount) + ' static fields, ' +
                   ItoS(DtStringCount) + ' strings, ' +
                   ItoS(DtFormatCount) + ' formats, ' +
                   ItoS(DtTotalBytes) + ' DATA bytes, ' +
                   ItoS(DtBssBytes) + ' BSS bytes';
End;

{ ============================================================ }
{ Programme principal (TODO 01-21)                              }
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
  TypeInit;
  LitInit;
  InitOprState;
  InitPxState;
  InitVaState;
  InitIfState;
  InitLpState;
  InitMtState;
  InitIoState;
  InitArState;
  InitStState;
  InitClState;
  InitSwState;
  InitExState;
  InitImState;
  InitCvState;
  InitDtState;
  LexInit;
  ParserAdvance;

  { Boucle de tokenisation (TODO 02-21) }
  While CurTokKind <> TK_EOF Do
    ParserAdvance;

  LexClose;

  WriteLn('JAVACW32: TODO 22..25 [A FAIRE] - pas encore implemente');

  ShowStats;
  Cleanup;

  If ErrorCount > 0 Then
    Halt(EXIT_ERROR)
  Else
    Halt(EXIT_OK);
End.
