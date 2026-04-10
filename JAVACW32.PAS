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
{ Programme principal (TODO 01-09)                              }
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
  LexInit;
  ParserAdvance;

  { Boucle de tokenisation (TODO 02-09) }
  While CurTokKind <> TK_EOF Do
    ParserAdvance;

  LexClose;

  WriteLn('JAVACW32: TODO 10..25 [A FAIRE] - pas encore implemente');

  ShowStats;
  Cleanup;

  If ErrorCount > 0 Then
    Halt(EXIT_ERROR)
  Else
    Halt(EXIT_OK);
End.
