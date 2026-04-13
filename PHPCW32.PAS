{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 0.1
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Compilateur PHP vers assembleur 80386 pour Windows 32 bits
  @license: MIT
}

(* ============================================================
  PHPCW32.PAS - Compilateur PHP vers assembleur
  80386 pour Windows 32 bits
  Free Pascal (-Mtp)
  Cible : MASM .386 / .MODEL FLAT, PE Win32

  Par defaut produit un fichier .EXE (PE Windows 32 bits).
  Avec le parametre -obj, produit uniquement un fichier .OBJ (COFF).
  Avec le parametre -asm, produit egalement un fichier .ASM lisible.
  Supporte tous les exemples SAMPLES\PHP\*

  Voir DOC/TODO/PHPCW32.txt pour la feuille de route complete.

  TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES PE/COFF [IMPLEMENTE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings,
              EmitExe, EmitObj, EmitAsm)
            ParseArgs : analyser argv (source.php [-o sortie] [-v]
              [-d] [-w] [-obj] [-asm] [-h])
            Par defaut : produire un .EXE Windows 32 bits (PE)
            -obj : produire uniquement un .OBJ (format COFF 32 bits)
            -asm : produire egalement un listing assembleur .ASM lisible
            -o nom : specifier le nom du fichier de sortie
            FatalError, CompileError, WarnMsg
            EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .php du fichier source
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
              MAX_LOCAL=128, MAX_LOOP_NEST=32, MAX_FUNC_NEST=16,
              MAX_ERRORS=30, MAX_STR=255, MAX_CONST=256,
              MAX_FUNC=256, MAX_ARRAY=256, MAX_IMPORT=32
            Prefixes de nommage ASM : _PH_ (variable globale),
              _PF_ (fonction utilisateur), _PK_ (constante chaine),
              _PHRT_ (routine runtime), _PL_ (label interne),
              _PA_ (tableau)
            Utilitaires : ItoS, UpCaseStr, StrLowerCase, BaseName,
              ReplaceExt, AsmIdent
            10 fonctions accesseurs

  TODO 02 - TOKENISEUR PHP (LEXER) [IMPLEMENTE]
            Procedure LexInit : ouvrir le fichier source, initialiser
              l etat du lexeur (ligne, colonne, caractere courant)
            Procedure LexClose : fermer le fichier source
            Procedure LexNextChar / LexPeekChar
            Balises PHP : <?php ... ?> (mode PHP obligatoire)
              Ignorer le texte hors des balises PHP pour ce compilateur
            Commentaires PHP : // jusqu a fin de ligne,
              # jusqu a fin de ligne (style shell),
              /* ... */ bloc multi-lignes,
              /** ... */ commentaires PHPDoc (ignores)
            Procedure LexNextToken : reconnaitre les tokens PHP :
              - Identificateurs : lettres, chiffres, souligne (_)
                PHP est sensible a la casse pour les variables
                PHP est insensible a la casse pour fonctions/classes
              - Variables : $nom (prefixe $ obligatoire)
              - Litteraux entiers : 123, 0xFF, 0b1010, 0o777
              - Litteraux flottants : 1.5, 3.14, 1.2e5
                (reconnus, tronques en entiers pour cette version)
              - Litteraux chaines : "texte" ou 'texte'
                Guillemets doubles : interpolation $var ignoree ici
                Guillemets simples : pas d interpolation
                Sequences d echappement : \n \t \r \\ \" \' \$ \xNN
              - Operateurs : + - * / % = == === != !== < <= > >=
                & | ^ ~ << >> += -= *= /= %= .= &= |= ^= <<= >>=
                ++ -- && || ! ?? ?: <=> ** **=
                . (concatenation)
              - Separateurs : ( ) [ ] { } , ; : @ => ->
            Types de tokens (TK_EOF, TK_INTEGER, TK_FLOAT, TK_STRING,
              TK_IDENT, TK_VARIABLE, TK_KEYWORD, TK_OP, TK_PUNCT,
              TK_LBRACE, TK_RBRACE, TK_LBRACKET, TK_RBRACKET,
              TK_LPAREN, TK_RPAREN, TK_SEMICOLON, TK_COMMA,
              TK_COLON, TK_ARROW, TK_DOUBLE_ARROW, TK_CONCAT)
            Stocker dans CurTokKind / CurTokStr / CurTokInt
            LexScanIdent, LexScanVariable, LexScanNumber,
              LexScanString, LexScanEscChar
            Gestion des lignes et numeros de ligne pour diagnostics
            ParserAdvance : lire token suivant avec PrintToken si -d
            10 fonctions accesseurs

  TODO 03 - RECONNAISSANCE DES MOTS-CLES PHP [IMPLEMENTE]
            Tous les mots reserves PHP utilises dans ce sous-ensemble :
              Controle : if, elseif, else, while, for, foreach, do,
                switch, case, default, break, continue, return
              Fonctions : function, const, define
              Tableaux : array, as
              Logiques : true, false, null, and, or, xor
              Inclusion : include, require (non implemente)
            LookupKeyword : retourner KW_xxx ou TK_IDENT
            Constantes KW_IF..KW_REQUIRE pour chaque mot-cle
            Mots-cles de fonction et variable : insensibles a la casse
              pour les mots-cles seulement
            Constantes predefinies PHP :
              PHP_OS : systeme d exploitation ("WINNT")
              PHP_INT_MAX : valeur entiere maximale (2147483647)
              PHP_VERSION : version du compilateur ("8.0")
              PHP_EOL : fin de ligne (CRLF sur Windows)
            10 fonctions accesseurs

  TODO 04 - TABLE DES SYMBOLES PHP (32 BITS) [IMPLEMENTE]
            Enregistrement TSymRec :
              Name      : nom PHP ($x, maFonction, MA_CONST)
              AsmName   : label ASM correspondant (_PH_x, _PF_maFonction)
              Kind      : type de symbole (SK_LOCAL, SK_PARAM, SK_GLOBAL,
                SK_FUNC, SK_CONST, SK_ARRAY)
              TypeIdx   : indice dans la table des types
              Offset    : offset dans le segment de donnees ou la pile
              ScopeLevel: niveau de portee imbrique
              IsGlobal  : True si variable globale (hors fonction)
              IsConst   : True si constante define() ou const
              DeclLine  : numero de ligne de declaration
            Procedures sur la table :
              SymInit, SymAdd, SymFind, SymFindInScope,
              SymCount, SymDump, SymNameClean
            Gestion de la portee : globale vs fonction
            CurScope : compteur de portee imbriquee (max MAX_SCOPE)
            ScopeStack / ScopeTop : pile pour SymEnterScope / SymLeaveScope
            Resolution des noms : local -> global
            Variables super-globales : non supportees (hors scope)
            Mangling des noms de fonctions : _PF_nomfonction
            10 fonctions accesseurs

  TODO 05 - SYSTEME DE TYPES PHP [IMPLEMENTE]
            TTypeKind : TYK_INT (32 bits signe), TYK_FLOAT (tronque int),
              TYK_STRING (ptr chaine), TYK_BOOL (32 bits 0/1),
              TYK_ARRAY (ptr tableau), TYK_NULL (reference nulle),
              TYK_MIXED (type dynamique), TYK_VOID (pas de valeur)
            TTypeRec : Name, Kind, Size, IsArray, ElemType
            TypeTab[MAX_TYPE], TypeCount
            Indices de types primitifs :
              TY_IDX_INT=0, TY_IDX_FLOAT=1, TY_IDX_STRING=2,
              TY_IDX_BOOL=3, TY_IDX_ARRAY=4, TY_IDX_NULL=5,
              TY_IDX_MIXED=6, TY_IDX_VOID=7
            TypeInit : enregistrer les types primitifs PHP
            TypeKindOf(idx) : retourner le TTypeKind pour un indice
            TypeSizeOf(idx) : INT=4, FLOAT=4, STRING=4(ptr),
              BOOL=4, ARRAY=4(ptr), NULL=0, MIXED=4, VOID=0
            TypeFindByName(name) : rechercher un type par nom -> index
            TypeKindStr(kind) : nom textuel d un TTypeKind
            PHP est a typage dynamique : toutes les variables sont MIXED
              a la compilation, verification a l execution si necessaire
            Juggling de type automatique PHP :
              int <-> string, int <-> bool, string <-> bool
            10 fonctions accesseurs

  TODO 06 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
            Entiers decimaux : 0..2147483647 (32 bits signe)
            Entiers hexadecimaux : 0xFF, binaires : 0b1010, octaux : 0o777
            Separateur de chiffres : 1_000_000 (ignore le souligne)
            Flottants : reconnus par le lexeur, tronques en entiers
            Chaines guillemets simples : 'abc' (pas d echappement sauf \')
            Chaines guillemets doubles : "abc" -> pointeur vers DATA
              Sequences d echappement : \n \t \r \\ \" \$ \xNN
              Interpolation $var : non supportee (chaines litterales)
            null : constante reference nulle -> EAX=0
            true : constante booleenne -> EAX=1
            false : constante booleenne -> EAX=0
            Constantes define('NOM', valeur) :
              Enregistrer dans la table des symboles avec SK_CONST
              Valeur immediate a la compilation
            Constantes const NOM = valeur :
              Syntaxe alternative pour les constantes
            TExprKind : EK_NONE, EK_IMM, EK_EAX, EK_MEM
            TExprVal : Kind, ImmVal, TypeIdx, Offset, SymIdx
            TDataKind : DK_DWORD, DK_BYTE, DK_STR, DK_ARRAY_BLK
            TDataRec : LblName, Kind, IntVal, StrVal, ElemCount
            DataAdd, DataAddStr, DataAddDWord : gestion du segment DATA
            ExprMakeImm, ExprMakeNull, ExprMakeBool, ExprMakeEAX
            LitEvalInt, LitEvalStr, LitEval
            LabelGen : generateur de labels uniques _PL_N
            10 fonctions accesseurs

  TODO 07 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
            Arithmetiques : + - * / % ** (puissance)
            Comparaison : == != === !== < <= > >= <=> (spaceship)
              == egalite avec juggling, === egalite stricte
            Logiques : && || ! and or xor (court-circuit pour && ||)
              and/or sont des synonymes de &&/|| avec precedence plus basse
            Bit a bit : & | ^ ~ << >> (AND, OR, XOR, NOT, decalages)
            Unaire : + - ~ ! ++ -- (pre et post-increment/decrement)
            Concatenation : . (point) pour joindre les chaines
            Null coalescing : ?? (expr ?? default si expr est null)
            Affectation : = += -= *= /= %= .= &= |= ^= <<= >>= **=
            Precedence (du plus fort au plus faible) :
              1. ++ -- (postfixe)
              2. ** (puissance, associatif a droite)
              3. ++ -- (prefixe), + - ~ ! (unaires)
              4. * / %
              5. + - . (binaires, concatenation)
              6. << >>
              7. < <= > >= <=>
              8. == != === !==
              9. &
              10. ^
              11. |
              12. &&
              13. ||
              14. ??
              15. ? : (ternaire)
              16. = += -= *= /= %= .= &= |= ^= <<= >>= **=
              17. and
              18. xor
              19. or
            BinOpPrec, BinOpIsRight, IsAssignOp
            ParsePrimary, ParseUnary, ParseExprPrec, ParseExpr
            ExprFlushToEAX, ExprEmitBinOp
            Pliage de constantes pour expressions statiques
            10 fonctions accesseurs

  TODO 08 - PARSEUR : EXPRESSIONS PRIMAIRES ET APPELS [A FAIRE]
            ParsePrimary : literal entier, literal chaine,
              variable $nom, appel de fonction, null, true, false
            Variables : $nom -> acces memoire ou pile
            Constantes : NOM (sans $) -> valeur immediate ou memoire
            Appel de fonction : nom(args) ->
              PUSH args droite a gauche + CALL _PF_nom
              + ADD ESP, args_size
            Appel de fonction builtin : abs(), max(), min(), count()
              Reconnaissance speciale pour les fonctions PHP natives
            Acces index tableau : $tab[i] ->
              calcul offset + MOV EAX, [EBX+4+i*4]
            Acces par cle : $tab["cle"] (simplifie, cle ignoree)
            Parentheses : (expr) -> regroupement de priorite
            Concatenation implicite : echo "valeur:", $x;
              (virgule dans echo = concatenation avec espace implicite)
            Operateur ternaire : cond ? a : b -> code conditionnel
            Operateur null coalescing : $a ?? $b ->
              si $a est defini et non null, retourner $a, sinon $b
            10 fonctions accesseurs

  TODO 09 - PARSEUR : VARIABLES ET AFFECTATIONS [A FAIRE]
            Variables locales : pile EBP, acces [EBP-offset]
              Declaration implicite a la premiere affectation
              PHP ne requiert pas de declaration explicite
            Variables globales : segment DATA, acces par label _PH_nom
              MOV EAX, DWORD [_PH_x] pour lecture
              MOV DWORD [_PH_x], EAX pour ecriture
            Parametres de fonction : pile EBP, acces [EBP+offset]
            Mot-cle global : global $x; pour acceder a une globale
              depuis une fonction (non implemente, erreur)
            Affectation simple : $x = expr ->
              evaluer expr + MOV destination, EAX
            Affectation augmentee : $x += expr -> charger $x,
              evaluer expr, ADD EAX, resultat, stocker
              Supportees : += -= *= /= %= .= &= |= ^= <<= >>= **=
            Pre-increment/decrement : ++$x / --$x
            Post-increment/decrement : $x++ / $x--
            Affectation tableau : $tab[i] = expr ->
              calcul adresse + MOV [EBX+4+i*4], EAX
            Typage dynamique : pas de verification de type a l affectation
            10 fonctions accesseurs

  TODO 10 - PARSEUR : IF / ELSEIF / ELSE ET OPERATEUR TERNAIRE [A FAIRE]
            ParseIfStmt : if (cond) { bloc } [elseif (cond) { bloc }]
              [else { bloc }]
              Accolades obligatoires pour les blocs (style recommande)
              Emission : evaluer cond -> TEST EAX, EAX / JZ label
              Labels : _PL_ELIF_N, _PL_ELSE_N, _PL_ENDIF_N
            if sans accolades : instruction unique permise
              if (cond) stmt; elseif (cond) stmt; else stmt;
            Syntaxe alternative : if (cond): ... elseif: ... else: ... endif;
              (non supportee, utiliser la syntaxe avec accolades)
            Operateur ternaire (dans les expressions) :
              $val = $cond ? $a : $b
              Emission : evaluer cond, JZ vers else-branch,
                evaluer a, JMP fin, label else, evaluer b, label fin
            Operateur ternaire court : $val = $a ?: $b
              (equivalent a $a ? $a : $b)
            Conditions composees : && / || avec court-circuit
            Truthiness PHP : 0, "", "0", null, array() vide -> false
              Tout le reste -> true
            10 fonctions accesseurs

  TODO 11 - PARSEUR : BOUCLES while / for / do-while / foreach [A FAIRE]
            ParseWhileStmt : while (cond) { bloc }
              Labels : _PL_WTEST_N, _PL_WEND_N
              Emission : _PL_WTEST_N: evaluer cond, JZ _PL_WEND_N,
                corps, JMP _PL_WTEST_N, _PL_WEND_N:
            ParseDoWhileStmt : do { bloc } while (cond);
              Labels : _PL_DSTART_N, _PL_DTEST_N, _PL_DEND_N
              Emission : _PL_DSTART_N: corps, _PL_DTEST_N: evaluer cond,
                JNZ _PL_DSTART_N, _PL_DEND_N:
            ParseForStmt : for ($i = 0; $i < n; $i++) { bloc }
              Labels : _PL_FTEST_N, _PL_FINCR_N, _PL_FEND_N
              Emission : init, _PL_FTEST_N: evaluer cond,
                JZ _PL_FEND_N, corps, _PL_FINCR_N: incr,
                JMP _PL_FTEST_N, _PL_FEND_N:
            ParseForeachStmt : foreach ($tab as $val) { bloc }
              Iterer sur les elements d un tableau
              Labels : _PL_FETEST_N, _PL_FEEND_N
            foreach avec cle : foreach ($tab as $k => $v) { bloc }
              $k recoit l index, $v recoit la valeur
            break : JMP vers _PL_WEND_N ou _PL_FEND_N ou _PL_DEND_N
            continue : JMP vers _PL_WTEST_N ou _PL_FINCR_N ou _PL_DTEST_N
            LoopPush / LoopPop : pile de labels pour break/continue
            Boucles imbriquees supportees (MAX_LOOP_NEST)
            10 fonctions accesseurs

  TODO 12 - PARSEUR : FONCTIONS UTILISATEUR ET RETURN [A FAIRE]
            ParseFunctionDecl : function nom($params) { bloc }
            Parametres : passage par valeur sur la pile (cdecl)
              Liste de parametres : function f($a, $b, $c)
              Valeurs par defaut : function f($a, $b = 10)
                (non supporte initialement, erreur)
            Types de retour : mixed (toujours 32 bits dans EAX)
            Convention d appel 80386 :
              Parametres empiles de droite a gauche (cdecl)
              Valeur de retour dans EAX
              L appelant nettoie la pile apres CALL
            Prologue : PUSH EBP / MOV EBP, ESP / SUB ESP, locals_size
              Variables locales accessibles via [EBP-offset]
              Parametres accessibles via [EBP+8], [EBP+12], ...
            Epilogue : MOV ESP, EBP / POP EBP / RET
            return $expr : MOV EAX, valeur + JMP vers epilogue
            return sans valeur : EAX = null (0) + JMP epilogue
            Recursion : supportee naturellement via la pile
            Point d entree : code global hors fonctions
              Le code PHP s execute dans l ordre, pas de main()
              Point d entree ASM : _start
            Appel : PUSH args + CALL _PF_nom + ADD ESP, n*4
            10 fonctions accesseurs

  TODO 13 - PARSEUR : ENTREES/SORTIES (echo, print) [A FAIRE]
            echo expr1, expr2, ... :
              Evaluer chaque argument, convertir en chaine si necessaire
              Appeler _PHRT_WRITESTR pour afficher chacun
              Pas de retour a la ligne automatique
            echo "texte\n" : afficher avec retour a la ligne explicite
            print expr :
              Comme echo mais retourne toujours 1
              Accepte un seul argument
            echo avec entiers : CALL _PHRT_ITOA + _PHRT_WRITESTR
            echo avec chaines : _PHRT_WRITESTR directement
            echo avec booleens : ecrire "1" ou "" (chaine vide)
            Concatenation dans echo : echo "val: " . $n;
              Concatener puis afficher
            echo avec virgules : echo $a, " ", $b;
              Afficher chaque expression separement
            Win32 API pour les E/S console :
              GetStdHandle(STD_OUTPUT_HANDLE) pour ecriture
              WriteFile pour l affichage
            Pas de saisie utilisateur (fgets non supporte)
            10 fonctions accesseurs

  TODO 14 - PARSEUR : TABLEAUX (array) [A FAIRE]
            Declaration et allocation : $tab = array(10, 20, 30);
              ou syntaxe courte : $tab = [10, 20, 30];
              Allocation sur le heap : _PHRT_HEAPALLOC((n+1)*4)
              Layout memoire : [count DD][elem0 DD][elem1 DD]...
            Tableaux associatifs simplifies :
              $tab = array("a" => 1, "b" => 2);
              Non supporte : erreur si cles non numeriques
            Acces par index : $tab[i] ->
              verification des bornes optionnelle
              calcul offset + MOV EAX, [EBX+4+i*4]
            Affectation par index : $tab[i] = val ->
              MOV [EBX+4+i*4], EAX
            count($tab) : MOV EAX, [EBX] (compteur en tete de tableau)
            array_push : non supporte (taille fixe)
            foreach : for ($tab as $v) / for ($tab as $k => $v)
              Boucle sur les elements sequentiellement
            Verification des bornes optionnelle :
              CMP index, [EBX] / JAE _PHRT_BOUNDS_ERR
            Passage de tableau en parametre : par reference (pointeur)
            Tableaux multidimensionnels : non supportes
            10 fonctions accesseurs

  TODO 15 - PARSEUR : CHAINES (string) OPERATIONS [A FAIRE]
            Concatenation : $s1 . $s2 ->
              CALL _PHRT_STRCONCAT -> EAX=ptr
            Affectation concatenee : $s .= $s2 ->
              concatener et stocker le resultat
            strlen($s) : CALL _PHRT_STRLEN(ESI=str) -> EAX
            substr($s, $start, $len) :
              CALL _PHRT_STRSLICE -> EAX=ptr
            strpos($s, $needle) :
              CALL _PHRT_STRFIND -> EAX=index ou FALSE (0)
            strtoupper($s) / strtolower($s) :
              CALL _PHRT_STRUPPER / _PHRT_STRLOWER -> EAX=ptr
            trim($s) : CALL _PHRT_STRTRIM -> EAX=ptr
            str_replace($search, $replace, $subject) :
              CALL _PHRT_STRREPLACE -> EAX=ptr (simplifie)
            strcmp($s1, $s2) : CALL _PHRT_STRCMP -> EAX=<0|0|>0
            strncmp($s1, $s2, $n) : comparer n premiers caracteres
            Acces par index : $s[i] -> caractere a la position i
              MOVZX EAX, BYTE [ESI+i]
            Comparaison : == compare le contenu (avec juggling)
              === compare le contenu et le type
            Interpolation : non supportee (utiliser concatenation)
            10 fonctions accesseurs

  TODO 16 - PARSEUR : FONCTIONS MATHEMATIQUES BUILTIN [A FAIRE]
            abs($n) : valeur absolue
              TEST EAX, EAX / JNS done / NEG EAX / done:
            max($a, $b) : maximum de deux valeurs
              CMP EAX, EBX / JGE done / MOV EAX, EBX / done:
            min($a, $b) : minimum de deux valeurs
              CMP EAX, EBX / JLE done / MOV EAX, EBX / done:
            pow($base, $exp) : puissance entiere (operateur ^ en notation)
              Boucle de multiplication ou appel runtime
            sqrt($n) : racine carree (non supporte, erreur)
            floor($n) / ceil($n) / round($n) :
              Non supportes (valeurs entieres seulement)
            rand() / rand($min, $max) :
              Generateur pseudo-aleatoire simple (non supporte)
            intval($s) : CALL _PHRT_ATOI -> EAX
              Conversion chaine vers entier
            strval($n) : CALL _PHRT_ITOA -> EAX=ptr
              Conversion entier vers chaine
            Reconnaissance des appels builtin dans le parseur
            Emission de code inline pour abs/max/min
            10 fonctions accesseurs

  TODO 17 - PARSEUR : SWITCH / CASE / DEFAULT [A FAIRE]
            ParseSwitchStmt : switch ($expr) { case val: stmts; ... }
              Evaluer l expression de selection
              Generer une table de sauts ou une chaine de CMP/JE
            case valeur: stmts ->
              _PL_CASE_N: comparer et executer
              CMP EAX, valeur / JE _PL_CASE_N
            default: stmts ->
              _PL_DEFAULT_N: label pour le cas par defaut
              Execute si aucun case ne correspond
            break dans switch : JMP _PL_SWITCH_END_N
              Sans break, fall-through vers le case suivant
            Fall-through : comportement PHP standard entre les case
              si break est absent
            Cases multiples : case 1: case 2: stmts ->
              plusieurs labels pour le meme bloc
            Expression int ou string dans switch (int seulement supporte)
            Labels : _PL_SWITCH_N, _PL_CASE_N_K, _PL_DEFAULT_N,
              _PL_SWITCH_END_N
            Alternative : syntaxe switch(): ... endswitch;
              (non supportee, utiliser accolades)
            10 fonctions accesseurs

  TODO 18 - PARSEUR : CONSTANTES DEFINE() ET CONST [A FAIRE]
            define('NOM', valeur) : definir une constante globale
              Enregistrer dans SymTab avec SK_CONST
              NOM sans $ pour l acces : echo NOM;
              Valeur evaluee une seule fois a la definition
            define('NOM', valeur, true) :
              Troisieme parametre (case-insensitive) non supporte
            const NOM = valeur :
              Syntaxe alternative dans le scope global
              Similaire a define() mais syntaxe de declaration
            Constantes predefinies :
              PHP_OS : "WINNT" (string)
              PHP_INT_MAX : 2147483647 (int)
              PHP_VERSION : "8.0" (string)
              PHP_EOL : "\r\n" (string, Windows)
              TRUE / FALSE / NULL : constantes booleennes/null
            defined('NOM') : verifier si une constante existe
              Non supporte (retourner toujours false ou erreur)
            Constantes dans les expressions : substitution immediate
            Scope : constantes toujours globales
            10 fonctions accesseurs

  TODO 19 - PARSEUR : OPERATEURS SPECIAUX PHP [A FAIRE]
            Operateur de puissance ** :
              $a ** $b -> boucle de multiplication
              Associativite a droite : 2 ** 3 ** 2 = 2 ** 9 = 512
            Operateur spaceship <=> :
              $a <=> $b -> -1 si $a < $b, 0 si $a == $b, 1 si $a > $b
              Utile pour les fonctions de tri
            Operateur null coalescing ?? :
              $a ?? $b -> $a si $a est defini et non null, sinon $b
              Court-circuit : $b n est pas evalue si $a est valide
            Operateur ternaire court ?: :
              $a ?: $b -> $a si $a est truthy, sinon $b
              Court-circuit : $b n est pas evalue si $a est truthy
            Comparaison stricte === et !== :
              Comparer valeur ET type
              Pour les entiers : equivalent a ==
              Pour les chaines : comparaison byte par byte
            Pre/post increment sur chaines : non supporte
            Operateur @ (silence erreurs) : ignore (pas d erreurs PHP)
            Operateur de portee :: : non supporte (pas de classes)
            10 fonctions accesseurs

  TODO 20 - PARSEUR : CONVERSIONS DE TYPES (CAST ET JUGGLING) [A FAIRE]
            Cast explicite entre types :
              (int) $strExpr -> CALL _PHRT_ATOI
              (string) $intExpr -> CALL _PHRT_ITOA
              (bool) $expr -> TEST EAX, EAX / SETNZ AL / MOVZX
              (array) $expr -> non supporte (erreur)
              (float) $expr -> tronquer en int
            Juggling de types implicite dans les operations :
              string + int : convertir la chaine en int
              int . string : convertir l int en string
              bool dans contexte numerique : 0 ou 1
            Conversions dans echo :
              int -> appeler _PHRT_ITOA pour afficher
              bool -> afficher "1" (true) ou "" (false)
              null -> afficher "" (chaine vide)
            Truthiness pour les conditions :
              0, 0.0, "", "0", null, array() vide -> false
              Tout autre valeur -> true
            gettype($var) : non supporte (typage compile)
            is_int(), is_string(), etc. : non supportes
            settype($var, "type") : non supporte
            10 fonctions accesseurs

  TODO 21 - GENERATION DE CODE : SEGMENT DE DONNEES 80386 [A FAIRE]
            Section .data (variables initialisees) :
              Variable globale int : _PH_nom DD 0
              Variable globale string : _PH_nom DD _PK_N (ptr)
              Variable globale bool : _PH_nom DD 0
              Variable globale array : _PH_nom DD _PA_N (ptr)
            Constantes chaines :
              _PK_N DB 'texte', 0 (NUL-terminated)
            Constantes de format :
              _PK_FMT_N DB 'format...', 0
            Constantes speciales :
              _PK_TRUE DB '1', 0
              _PK_FALSE DB '', 0 (chaine vide)
              _PK_NULL DB '', 0 (chaine vide)
              _PK_CRLF DB 13, 10, 0
              _PK_SPACE DB ' ', 0
            Section .data? (BSS - variables non initialisees) :
              _PH_IOBUF DB 256 DUP(?)
              _PH_NUMBUF DB 32 DUP(?)
            Variables runtime :
              _PH_STDOUT DD ?  (handle console sortie)
              _PH_WRITTEN DD ? (octets ecrits par WriteFile)
            Heap dynamique :
              _PH_HEAP DB 65536 DUP(0)
              _PH_HEAPTOP DD 0
            Tableaux dans DATA : blocs de DD avec compteur en tete
            Alignement des donnees sur 4 octets (DWORD)
            10 fonctions accesseurs

  TODO 22 - BIBLIOTHEQUE RUNTIME PHP (E/S, CONVERSIONS VIA WIN32) [A FAIRE]
            Routines de conversion :
              _PHRT_ITOA : entier 32 bits -> chaine decimale ASCII
                Utilisation de DIV par 10 en boucle
              _PHRT_ATOI : chaine ASCII -> entier 32 bits
                Utilisation de IMUL par 10 et ADD
              _PHRT_BOOLTOSTR : 0 -> "" (vide), <>0 -> "1"
            Routines d E/S console :
              _PHRT_INITIO : initialiser le handle console
                PUSH STD_OUTPUT_HANDLE / CALL GetStdHandle
                MOV [_PH_STDOUT], EAX
              _PHRT_WRITESTR : ecrire chaine sur la console
                PUSH 0 / LEA EAX, [_PH_WRITTEN] / PUSH EAX
                PUSH longueur / PUSH adresse / PUSH [_PH_STDOUT]
                CALL WriteFile
              _PHRT_WRITECRLF : ecrire un retour a la ligne
            Routines chaines :
              _PHRT_STRLEN, _PHRT_STRCONCAT, _PHRT_STRCMP,
              _PHRT_STRSLICE, _PHRT_STRFIND,
              _PHRT_STRUPPER, _PHRT_STRLOWER, _PHRT_STRTRIM,
              _PHRT_STRREPLACE
            Routines tableaux :
              _PHRT_ARRALLOC : allocation tableau sur le heap
              _PHRT_ARRGET : lecture element avec verification bornes
              _PHRT_ARRSET : ecriture element avec verification bornes
              _PHRT_ARRLEN : retourner count() du tableau
            Routines mathematiques :
              _PHRT_POWER : calcul de puissance (base ** exp)
              _PHRT_ABS : valeur absolue
              _PHRT_MAX : maximum de deux valeurs
              _PHRT_MIN : minimum de deux valeurs
            _PHRT_PANIC : affiche message erreur + ExitProcess(1)
            _PHRT_BOUNDS_ERR : erreur d index tableau + exit
            Heap allocation : _PHRT_HEAPALLOC(ECX=taille) -> EAX=ptr
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
                Symboles definis pour fonctions/variables PHP
              Table des chaines (noms > 8 caracteres)
            Mode -obj : appeler GenerateCoffObj au lieu de GeneratePeExe
            10 fonctions accesseurs

  TODO 24 - IMPORTS API WIN32 ET GENERATEUR LISTING ASM [A FAIRE]
            Imports kernel32.dll :
              ExitProcess : terminer le programme
              GetStdHandle : obtenir le handle console
              WriteFile : ecrire sur la console (echo)
              GetProcessHeap, HeapAlloc, HeapFree :
                allocation dynamique (tableaux)
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
              (autres imports Win32 utilises)
              Section .DATA, .DATA?, .CODE
              Point d entree _start
              Routines runtime (_PHRT_)
              Fonctions PHP avec labels (_PF_)
              Commentaires avec le code source PHP
              Indentation et formatage lisible
            10 fonctions accesseurs

  TODO 25 - OPTIMISATIONS, TESTS FINAUX ET INTEGRATION SAMPLES\PHP\* [A FAIRE]
            Optimisations peephole :
              MOV EAX, 0 -> XOR EAX, EAX
              PUSH EAX / POP EAX -> (eliminer)
              MOV EAX, [x] / MOV [x], EAX -> (eliminer deuxieme)
              ADD EAX, 1 -> INC EAX
              SUB EAX, 1 -> DEC EAX
              IMUL EAX, 2 -> SHL EAX, 1
              IMUL EAX, 4 -> SHL EAX, 2
            Verification : compiler et executer les exemples
              SAMPLES\PHP\hello.php    - echo, variables, constantes,
                define(), const, arithmetique de base
              SAMPLES\PHP\control.php  - if/elseif/else, while, do-while,
                for, break, continue, switch/case, &&/||/!
              SAMPLES\PHP\math.php     - fonctions utilisateur, return,
                recursion, abs(), max(), min(), **
              SAMPLES\PHP\array.php    - array(), [], count(), $a[i],
                foreach, foreach avec cle
            Tests de regression pour chaque TODO
            Verification des 3 modes de sortie :
              .EXE (defaut), .OBJ (-obj), .ASM (-asm)
            Mesure de la taille des executables generes
            Verification de la compatibilite avec les exemples :
              Le compilateur doit produire des executables fonctionnels
              pour tous les fichiers dans SAMPLES\PHP\*.php
            10 fonctions accesseurs

  ============================================================ *)

Program PHPCW32;

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
  PHPCW32_VERSION = '0.1';
  PHPCW32_DATE    = '2026';

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
  MAX_FUNC_NEST  = 16;
  MAX_ERRORS     = 30;
  MAX_STR        = 255;
  MAX_CONST      = 256;
  MAX_FUNC       = 256;
  MAX_ARRAY      = 256;
  MAX_IMPORT     = 32;
  MAX_TYPE       = 64;

  { Limite pour les messages de sortie }
  MAX_OUTMSGS    = 256;

  { Types de valeurs de sortie (utilises par le code generation) }
  OMK_STRING   = 1;   { chaine litterale                          }
  OMK_INT      = 2;   { valeur entiere                            }
  OMK_BOOL     = 3;   { valeur booleenne                          }
  OMK_VAR_INT  = 4;   { variable entiere                          }
  OMK_VAR_BOOL = 5;   { variable booleenne                        }
  OMK_VAR_STR  = 6;   { variable chaine                           }

  { Prefixes de nommage ASM }
  PH_VAR_PFX  = '_PH_';     { variable globale                       }
  PH_FN_PFX   = '_PF_';     { fonction utilisateur                   }
  PH_STR_PFX  = '_PK_';     { constante chaine litterale             }
  PH_RT_PFX   = '_PHRT_';   { routine runtime                        }
  PH_LBL_PFX  = '_PL_';     { label de saut interne                  }
  PH_ARR_PFX  = '_PA_';     { tableau                                }

Type
  TString = String;

  TOptions = Record
    SrcFile    : TString;   { fichier source PHP (.php)              }
    OutFile    : TString;   { fichier sortie (.exe, .obj)            }
    Verbose    : Boolean;   { -v : banniere et statistiques          }
    DebugMode  : Boolean;   { -d : affichage de chaque token         }
    Warnings   : Boolean;   { -w : afficher les avertissements       }
    EmitExe    : Boolean;   { par defaut : produire un .EXE (PE)     }
    EmitObj    : Boolean;   { -obj : produire seulement un .OBJ      }
    EmitAsm    : Boolean;   { -asm : produire aussi un .ASM          }
  End;

  { Type pour les messages de sortie (echo) }
  TOutMsgRec = Record
    Kind       : Integer;  { OMK_STRING, OMK_INT, etc.              }
    StrVal     : TString;  { valeur si chaine                       }
    IntVal     : LongInt;  { valeur si entier                       }
    BoolVal    : Boolean;  { valeur si booleen                      }
    VarName    : TString;  { nom de variable si OMK_VAR_*           }
    AddNewLine : Boolean;  { True si ajouter un retour a la ligne   }
    Line       : Integer;  { ligne source                           }
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

  { Messages de sortie collectes (echo) }
  OutMsgs      : Array[1..MAX_OUTMSGS] Of TOutMsgRec;
  OutMsgCount  : Integer;

{ ------------------------------------------------------------ }
{ Fonctions utilitaires                                        }
{ ------------------------------------------------------------ }

Function ItoS(V : LongInt) : TString;
Var S : TString;
Begin
  Str(V, S);
  ItoS := S;
End;

{ StrToIntDef : convertir une chaine en entier avec defaut }
Function StrToIntDef(Const S : TString; Def : LongInt) : LongInt;
Var
  V    : LongInt;
  Code : Integer;
Begin
  Val(S, V, Code);
  If Code = 0 Then
    StrToIntDef := V
  Else
    StrToIntDef := Def;
End;

{ InitOutMsgs : initialiser le tableau des messages de sortie }
Procedure InitOutMsgs;
Var I : Integer;
Begin
  OutMsgCount := 0;
  For I := 1 To MAX_OUTMSGS Do
  Begin
    OutMsgs[I].Kind       := 0;
    OutMsgs[I].StrVal     := '';
    OutMsgs[I].IntVal     := 0;
    OutMsgs[I].BoolVal    := False;
    OutMsgs[I].VarName    := '';
    OutMsgs[I].AddNewLine := False;
    OutMsgs[I].Line       := 0;
  End;
End;

{ AddOutMsgStr : ajouter un message de sortie chaine }
Procedure AddOutMsgStr(Const S : TString; AddNewLine : Boolean; Ln : Integer);
Begin
  If OutMsgCount >= MAX_OUTMSGS Then Exit;
  Inc(OutMsgCount);
  OutMsgs[OutMsgCount].Kind       := OMK_STRING;
  OutMsgs[OutMsgCount].StrVal     := S;
  OutMsgs[OutMsgCount].IntVal     := 0;
  OutMsgs[OutMsgCount].BoolVal    := False;
  OutMsgs[OutMsgCount].VarName    := '';
  OutMsgs[OutMsgCount].AddNewLine := AddNewLine;
  OutMsgs[OutMsgCount].Line       := Ln;
End;

{ AddOutMsgInt : ajouter un message de sortie entier }
Procedure AddOutMsgInt(V : LongInt; AddNewLine : Boolean; Ln : Integer);
Begin
  If OutMsgCount >= MAX_OUTMSGS Then Exit;
  Inc(OutMsgCount);
  OutMsgs[OutMsgCount].Kind       := OMK_INT;
  OutMsgs[OutMsgCount].StrVal     := '';
  OutMsgs[OutMsgCount].IntVal     := V;
  OutMsgs[OutMsgCount].BoolVal    := False;
  OutMsgs[OutMsgCount].VarName    := '';
  OutMsgs[OutMsgCount].AddNewLine := AddNewLine;
  OutMsgs[OutMsgCount].Line       := Ln;
End;

{ AddOutMsgBool : ajouter un message de sortie booleen }
Procedure AddOutMsgBool(V : Boolean; AddNewLine : Boolean; Ln : Integer);
Begin
  If OutMsgCount >= MAX_OUTMSGS Then Exit;
  Inc(OutMsgCount);
  OutMsgs[OutMsgCount].Kind       := OMK_BOOL;
  OutMsgs[OutMsgCount].StrVal     := '';
  OutMsgs[OutMsgCount].IntVal     := 0;
  OutMsgs[OutMsgCount].BoolVal    := V;
  OutMsgs[OutMsgCount].VarName    := '';
  OutMsgs[OutMsgCount].AddNewLine := AddNewLine;
  OutMsgs[OutMsgCount].Line       := Ln;
End;

{ AddOutMsgVar : ajouter un message de sortie variable }
Procedure AddOutMsgVar(Const VarName : TString; VarKind : Integer;
                       AddNewLine : Boolean; Ln : Integer);
Begin
  If OutMsgCount >= MAX_OUTMSGS Then Exit;
  Inc(OutMsgCount);
  OutMsgs[OutMsgCount].Kind       := VarKind;
  OutMsgs[OutMsgCount].StrVal     := '';
  OutMsgs[OutMsgCount].IntVal     := 0;
  OutMsgs[OutMsgCount].BoolVal    := False;
  OutMsgs[OutMsgCount].VarName    := VarName;
  OutMsgs[OutMsgCount].AddNewLine := AddNewLine;
  OutMsgs[OutMsgCount].Line       := Ln;
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

{ Transforme un nom PHP en identifiant valide pour l assembleur }
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
  WriteLn('PHPCW32: FATAL: ', Msg);
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
  Halt(EXIT_ERROR);
End;

Procedure CompileError(Const Msg : TString; Line : Integer);
Begin
  Write('PHPCW32:');
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
  WriteLn('PHPCW32: warning: ', Msg);
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
  WriteLn('PHPCW32 v', PHPCW32_VERSION, ' (', PHPCW32_DATE,
          ') - Compilateur PHP vers 80386 (Windows PE 32 bits)');
  WriteLn('PHPCW32 - Cette commande permet de lancer le compilateur PHP ',
          'pour l''assembleur du microprocesseur 80386 (en executable ',
          'Windows 32 bits).');
  WriteLn;
  WriteLn('Syntaxe : PHPCW32 [options] <source.php> [options]');
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
  WriteLn('  PHPCW32 hello.php');
  WriteLn('  PHPCW32 hello.php -o hello.exe -v');
  WriteLn('  PHPCW32 control.php -asm');
  WriteLn('  PHPCW32 math.php -obj -w');
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
    WriteLn('PHPCW32: fichier source manquant');
    ShowHelp;
  End;

  { Verifier l extension .php }
  Ext := ExtractExt(Opts.SrcFile);
  If Ext <> '.php' Then
    WarnMsg('extension attendue .php, trouvee: ' + Ext);

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
  WriteLn('PHPCW32 v', PHPCW32_VERSION, ' (', PHPCW32_DATE,
          ') - Compilateur PHP -> 80386 PE Win32');
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
{ OutLn : ecrire une ligne dans le fichier de sortie ASM       }
{ ------------------------------------------------------------ }

Procedure OutLn(Const S : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, S);
End;

{ ------------------------------------------------------------ }
{ OutStr : ecrire une chaine sans saut de ligne                }
{ ------------------------------------------------------------ }

Procedure OutStr(Const S : TString);
Begin
  If OutFOpen Then
    Write(OutF, S);
End;

{ ------------------------------------------------------------ }
{ OutOpen : ouvrir le fichier de sortie ASM                    }
{ ------------------------------------------------------------ }

Procedure OutOpen(Const FileName : TString);
Begin
  If OutFOpen Then
    Close(OutF);
  Assign(OutF, FileName);
  Rewrite(OutF);
  OutFOpen := True;
End;

{ ------------------------------------------------------------ }
{ OutClose : fermer le fichier de sortie ASM                   }
{ ------------------------------------------------------------ }

Procedure OutClose;
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
  GetCompilerVersion := PHPCW32_VERSION;
End;

Function GetCompilerDate : TString;
Begin
  GetCompilerDate := PHPCW32_DATE;
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
{ TODO 02 - TOKENISEUR PHP (LEXER)                [IMPLEMENTE] }
{ ============================================================ }

Const
  { Types de tokens PHP }
  TK_EOF         = 0;    { fin de fichier                          }
  TK_INTEGER     = 1;    { litteral entier (42, 0xFF, 0b1010)      }
  TK_FLOAT       = 2;    { litteral flottant (3.14, 1.5e5)         }
  TK_STRING      = 3;    { litteral chaine "abc" ou 'abc'          }
  TK_IDENT       = 4;    { identificateur (non mot-cle)             }
  TK_VARIABLE    = 5;    (* variable PHP ($nom)                      *)
  TK_KEYWORD     = 6;    (* mot-cle PHP reconnu                     *)
  TK_OP          = 7;    (* operateur + - * / == != etc.             *)
  TK_PUNCT       = 8;    (* ponctuation generique                    *)
  TK_LBRACE      = 9;    (* accolade ouvrante                        *)
  TK_RBRACE      = 10;   (* accolade fermante                        *)
  TK_LBRACKET    = 11;   (* crochet ouvrant [                        *)
  TK_RBRACKET    = 12;   (* crochet fermant ]                        *)
  TK_LPAREN      = 13;   (* parenthese ouvrante (                    *)
  TK_RPAREN      = 14;   (* parenthese fermante )                    *)
  TK_SEMICOLON   = 15;   (* point-virgule ;                          *)
  TK_COMMA       = 16;   (* virgule ,                                *)
  TK_COLON       = 17;   (* deux-points :                            *)
  TK_ARROW       = 18;   (* fleche -> (acces membre)                 *)
  TK_DOUBLE_ARROW = 19;  (* double fleche => (tableaux assoc.)       *)
  TK_CONCAT      = 20;   (* operateur de concatenation .             *)
  TK_AT          = 21;   { arobase @ (suppression erreurs)          }
  TK_QUESTION    = 22;   { point d interrogation ?                  }
  TK_DOLLAR      = 23;   { dollar $ seul (variable variable)        }

  { Constante pour LookupKeyword (forward) }
  KW_NONE = 0;

Type
  { Noeud de liste chainee pour le buffer source }
  PLexSrcNode = ^TLexSrcNode;
  TLexSrcNode = Record
    Line : TString;            { contenu de la ligne source            }
    Next : PLexSrcNode;        { pointeur vers le noeud suivant        }
  End;

Var
  { Fichier source }
  LexSrcF     : Text;          { handle du fichier source              }
  LexOpened   : Boolean;       { fichier ouvert ?                      }
  LexLine     : TString;       { ligne courante                        }
  LexLineNo   : LongInt;       { numero de ligne courante              }
  LexColNo    : Integer;       { colonne courante dans LexLine         }
  LexEOF      : Boolean;       { fin de fichier atteinte ?             }

  { Mode PHP }
  LexInPhp    : Boolean;       { True si dans <?php ... ?>             }

  { Buffer source pour rewind (boucles while) - liste chainee }
  LexSrcHead  : PLexSrcNode;   { tete de la liste chainee              }
  LexSrcTail  : PLexSrcNode;   { queue de la liste (pour ajout rapide) }
  LexSrcCur   : PLexSrcNode;   { noeud courant (curseur de lecture)    }
  LexSrcCurNo : LongInt;       { numero de ligne du curseur courant    }
  LexSrcCount : LongInt;       { nombre de lignes dans le buffer       }
  LexUseBuffer: Boolean;       { True si on lit depuis le buffer       }

  { Token courant }
  CurTokKind  : Integer;       { type de token (TK_*)                  }
  CurTokStr   : TString;       { valeur textuelle du token             }
  CurTokInt   : LongInt;       { valeur numerique (entier)             }
  CurTokFloat : Real;          { valeur numerique (flottant)           }
  CurTokLine  : Integer;       { ligne du token                        }
  CurTokCol   : Integer;       { colonne du token                      }

  { Compteur de tokens }
  LexTokCount : LongInt;       { nombre total de tokens emis           }

Type
  { Etat sauvegarde du lexer pour rewind }
  TLexState = Record
    LineNo   : LongInt;
    ColNo    : Integer;
    IsEOF    : Boolean;
    Line     : TString;
    InPhp    : Boolean;
    TokKind  : Integer;
    TokStr   : TString;
    TokInt   : LongInt;
    TokLine  : Integer;
    TokCol   : Integer;
  End;

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
  { En PHP, les identificateurs commencent par lettre ou _ }
  IsIdentStart := IsAlpha(Ch) Or (Ch = '_');
End;

Function IsIdentCont(Ch : Char) : Boolean;
Begin
  { En PHP, les identificateurs peuvent contenir lettres, chiffres, _ }
  IsIdentCont := IsAlpha(Ch) Or IsDigit(Ch) Or (Ch = '_');
End;

Function IsHexDigit(Ch : Char) : Boolean;
Begin
  IsHexDigit := ((Ch >= '0') And (Ch <= '9')) Or
                ((Ch >= 'A') And (Ch <= 'F')) Or
                ((Ch >= 'a') And (Ch <= 'f'));
End;

Function IsOctDigit(Ch : Char) : Boolean;
Begin
  IsOctDigit := (Ch >= '0') And (Ch <= '7');
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
{ LexSrcSeek : positionner le curseur sur la ligne N           }
{ Optimise pour acces sequentiel (avance depuis la position    }
{ courante si possible, sinon repart de la tete)               }
{ ------------------------------------------------------------ }

Function LexSrcSeek(N : LongInt) : PLexSrcNode;
Var P : PLexSrcNode;
    I : LongInt;
Begin
  { Si le curseur est deja sur la bonne ligne }
  If (LexSrcCur <> Nil) And (LexSrcCurNo = N) Then
  Begin
    LexSrcSeek := LexSrcCur;
    Exit;
  End;
  { Si le curseur est avant la ligne demandee, avancer }
  If (LexSrcCur <> Nil) And (LexSrcCurNo < N) Then
  Begin
    P := LexSrcCur;
    I := LexSrcCurNo;
  End
  Else
  Begin
    P := LexSrcHead;
    I := 1;
  End;
  While (P <> Nil) And (I < N) Do
  Begin
    P := P^.Next;
    Inc(I);
  End;
  LexSrcCur   := P;
  LexSrcCurNo := N;
  LexSrcSeek  := P;
End;

{ ------------------------------------------------------------ }
{ LexNextLine : lire la prochaine ligne du fichier source      }
{ ------------------------------------------------------------ }

Procedure LexNextLine;
Var Node : PLexSrcNode;
Begin
  If LexEOF Then Exit;
  If LexUseBuffer Then
  Begin
    { Lire depuis la liste chainee }
    If LexLineNo >= LexSrcCount Then
    Begin
      LexEOF   := True;
      LexLine  := '';
      LexColNo := 1;
    End
    Else
    Begin
      Inc(LexLineNo);
      Node := LexSrcSeek(LexLineNo);
      If Node <> Nil Then
        LexLine := Node^.Line
      Else
      Begin
        LexEOF  := True;
        LexLine := '';
      End;
      LexColNo := 1;
    End;
  End
  Else
  Begin
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
End;

{ ------------------------------------------------------------ }
{ LexSaveState : sauvegarder l etat du lexer                   }
{ ------------------------------------------------------------ }

Procedure LexSaveState(Var St : TLexState);
Begin
  St.LineNo  := LexLineNo;
  St.ColNo   := LexColNo;
  St.IsEOF   := LexEOF;
  St.Line    := LexLine;
  St.InPhp   := LexInPhp;
  St.TokKind := CurTokKind;
  St.TokStr  := CurTokStr;
  St.TokInt  := CurTokInt;
  St.TokLine := CurTokLine;
  St.TokCol  := CurTokCol;
End;

{ ------------------------------------------------------------ }
{ LexRestoreState : restaurer l etat du lexer depuis buffer    }
{ ------------------------------------------------------------ }

Procedure LexRestoreState(Const St : TLexState);
Begin
  LexLineNo   := St.LineNo;
  LexColNo    := St.ColNo;
  LexEOF      := St.IsEOF;
  LexLine     := St.Line;
  LexInPhp    := St.InPhp;
  LexUseBuffer := True;
  { Repositionner le curseur sur la ligne restauree }
  LexSrcCur   := Nil;
  LexSrcCurNo := 0;
  CurTokKind  := St.TokKind;
  CurTokStr   := St.TokStr;
  CurTokInt   := St.TokInt;
  CurTokLine  := St.TokLine;
  CurTokCol   := St.TokCol;
End;

{ ------------------------------------------------------------ }
{ LexInit : ouvrir le fichier source et initialiser le lexeur  }
{ ------------------------------------------------------------ }

Procedure LexInit;
Var TmpLine : TString;
    Node    : PLexSrcNode;
Begin
  Assign(LexSrcF, Opts.SrcFile);
  {$I-}
  Reset(LexSrcF);
  {$I+}
  If IOResult <> 0 Then
    FatalError('Impossible d''ouvrir le fichier source: ' + Opts.SrcFile);
  LexOpened   := True;

  { Lire tout le fichier dans la liste chainee }
  LexSrcHead  := Nil;
  LexSrcTail  := Nil;
  LexSrcCur   := Nil;
  LexSrcCurNo := 0;
  LexSrcCount := 0;
  While Not EOF(LexSrcF) Do
  Begin
    ReadLn(LexSrcF, TmpLine);
    New(Node);
    Node^.Line := TmpLine;
    Node^.Next := Nil;
    If LexSrcHead = Nil Then
      LexSrcHead := Node
    Else
      LexSrcTail^.Next := Node;
    LexSrcTail := Node;
    Inc(LexSrcCount);
  End;
  Close(LexSrcF);
  LexOpened := False;

  { Initialiser le lexer en mode buffer }
  LexLineNo   := 0;
  LexColNo    := 1;
  LexEOF      := False;
  LexLine     := '';
  LexInPhp    := False;  { commence hors mode PHP }
  LexUseBuffer := True;
  LexSrcCur   := LexSrcHead;
  LexSrcCurNo := 1;
  TotalLines  := LexSrcCount;
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
Var
  P, Next : PLexSrcNode;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
  { Liberer la liste chainee }
  P := LexSrcHead;
  While P <> Nil Do
  Begin
    Next := P^.Next;
    Dispose(P);
    P := Next;
  End;
  LexSrcHead  := Nil;
  LexSrcTail  := Nil;
  LexSrcCur   := Nil;
  LexSrcCurNo := 0;
  LexSrcCount := 0;
End;

{ ------------------------------------------------------------ }
{ LexScanIdent : identificateur PHP (sensible a la casse pour  }
{                variables, insensible pour fonctions/classes) }
{ PHP accepte lettres, chiffres, _                              }
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

  { Tester si c est un mot-cle PHP (insensible a la casse) }
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
{ LexScanVariable : variable PHP $nom                          }
{ ------------------------------------------------------------ }

Procedure LexScanVariable;
Var
  S : TString;
Begin
  S := '$';
  Inc(LexColNo);  { sauter le $ }

  { Scanner le nom de la variable }
  While (LexColNo <= Length(LexLine)) And
        IsIdentCont(LexLine[LexColNo]) Do
  Begin
    If Length(S) < MAX_STR Then
      S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;

  CurTokKind  := TK_VARIABLE;
  CurTokStr   := S;
  CurTokInt   := 0;
  CurTokFloat := 0.0;
End;

{ ------------------------------------------------------------ }
{ LexScanNumber : litteral numerique PHP                       }
{ Entiers : 123, 0xFF, 0b1010, 0o777, 1_000                    }
{ Flottants : 1.5, 3.14e5 (tronques en entiers)               }
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

  { Detecter prefixe 0x 0b 0o }
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
    End
    Else If (Ch = 'o') Or (Ch = 'O') Then
    Begin
      Base := 8;
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
    Else If (Base = 8) And IsOctDigit(Ch) Then
    Begin
      N := N * 8 + (Ord(Ch) - Ord('0'));
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
{ LexScanEscChar : decoder une sequence d echappement PHP      }
{ Supporte : \n \t \r \\ \" \' \$ \xNN                        }
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
    '$'        : LexScanEscChar := '$';
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
{ LexScanStringDouble : chaine PHP "texte" avec echappement    }
{ ------------------------------------------------------------ }

Procedure LexScanStringDouble;
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
{ LexScanStringSingle : chaine PHP 'texte' (pas d echappement) }
{ Seul \' et \\ sont reconnus                                  }
{ ------------------------------------------------------------ }

Procedure LexScanStringSingle;
Var
  S  : TString;
  Ch : Char;
Begin
  S := '';
  Inc(LexColNo); { sauter le ' ouvrant }
  While LexColNo <= Length(LexLine) Do
  Begin
    Ch := LexLine[LexColNo];
    If Ch = '''' Then
    Begin
      Inc(LexColNo);
      Break;
    End
    Else If (Ch = '\') And (LexColNo < Length(LexLine)) Then
    Begin
      Ch := LexLine[LexColNo + 1];
      If Ch = '''' Then
      Begin
        Inc(LexColNo, 2);
        If Length(S) < MAX_STR Then S := S + '''';
      End
      Else If Ch = '\' Then
      Begin
        Inc(LexColNo, 2);
        If Length(S) < MAX_STR Then S := S + '\';
      End
      Else
      Begin
        If Length(S) < MAX_STR Then S := S + LexLine[LexColNo];
        Inc(LexColNo);
      End;
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
{ PrintToken : affichage debug de chaque token                 }
{ ------------------------------------------------------------ }

Procedure PrintToken;
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', CurTokLine, ',', CurTokCol, '] ');
  Case CurTokKind Of
    TK_EOF         : Write('EOF');
    TK_INTEGER     : Write('INT(', CurTokInt, ')');
    TK_FLOAT       : Write('FLOAT(', CurTokStr, ')');
    TK_STRING      : Write('STR("', CurTokStr, '")');
    TK_IDENT       : Write('IDENT(', CurTokStr, ')');
    TK_VARIABLE    : Write('VAR(', CurTokStr, ')');
    TK_KEYWORD     : Write('KW(', CurTokStr, ')');
    TK_OP          : Write('OP(', CurTokStr, ')');
    TK_PUNCT       : Write('PUNCT(', CurTokStr, ')');
    TK_LBRACE      : Write('LBRACE');
    TK_RBRACE      : Write('RBRACE');
    TK_LBRACKET    : Write('LBRACKET');
    TK_RBRACKET    : Write('RBRACKET');
    TK_LPAREN      : Write('LPAREN');
    TK_RPAREN      : Write('RPAREN');
    TK_SEMICOLON   : Write('SEMICOLON');
    TK_COMMA       : Write('COMMA');
    TK_COLON       : Write('COLON');
    TK_ARROW       : Write('ARROW');
    TK_DOUBLE_ARROW: Write('DOUBLE_ARROW');
    TK_CONCAT      : Write('CONCAT');
    TK_AT          : Write('AT');
    TK_QUESTION    : Write('QUESTION');
    TK_DOLLAR      : Write('DOLLAR');
  Else
    Write('TOK(', CurTokKind, ')');
  End;
  WriteLn;
End;

{ ------------------------------------------------------------ }
{ LexNextToken : reconnaitre le prochain token PHP             }
{ Gere les commentaires // # et /* */,                         }
{ les balises <?php ... ?>, tous les operateurs PHP            }
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

    { Detecter <?php pour entrer en mode PHP }
    If (Not LexInPhp) And (Ch = '<') And
       (LexColNo + 4 <= Length(LexLine)) And
       (LexLine[LexColNo + 1] = '?') And
       ((LexLine[LexColNo + 2] = 'p') Or (LexLine[LexColNo + 2] = 'P')) And
       ((LexLine[LexColNo + 3] = 'h') Or (LexLine[LexColNo + 3] = 'H')) And
       ((LexLine[LexColNo + 4] = 'p') Or (LexLine[LexColNo + 4] = 'P')) Then
    Begin
      LexInPhp := True;
      Inc(LexColNo, 5);
      { Sauter les espaces apres <?php }
      While (LexColNo <= Length(LexLine)) And
            ((LexLine[LexColNo] = ' ') Or (LexLine[LexColNo] = #9)) Do
        Inc(LexColNo);
      Continue;
    End;

    { Si on n est pas en mode PHP, avancer }
    If Not LexInPhp Then
    Begin
      Inc(LexColNo);
      Continue;
    End;

    { Detecter ?> pour sortir du mode PHP }
    If (Ch = '?') And (LexColNo < Length(LexLine)) And
       (LexLine[LexColNo + 1] = '>') Then
    Begin
      LexInPhp := False;
      Inc(LexColNo, 2);
      Continue;
    End;

    { Espaces et tabulations }
    If (Ch = ' ') Or (Ch = #9) Or (Ch = #13) Or (Ch = #12) Then
      Inc(LexColNo)

    { Commentaire // : jusqu a fin de ligne }
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '/') Then
      LexColNo := Length(LexLine) + 1

    { Commentaire # : jusqu a fin de ligne (style shell) }
    Else If Ch = '#' Then
      LexColNo := Length(LexLine) + 1

    { Commentaire /* ... */ et /** ... */ (PHPDoc) }
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

    { Variable PHP $nom }
    Else If Ch = '$' Then
    Begin
      If (LexColNo < Length(LexLine)) And
         IsIdentStart(LexLine[LexColNo + 1]) Then
      Begin
        LexScanVariable;
        Scanning := False;
      End
      Else
      Begin
        { Dollar seul }
        Inc(LexColNo);
        CurTokKind := TK_DOLLAR;
        CurTokStr  := '$';
        Scanning := False;
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
      LexScanStringDouble;
      Scanning := False;
    End

    { Chaine de caracteres '...' }
    Else If Ch = '''' Then
    Begin
      LexScanStringSingle;
      Scanning := False;
    End

    { **= }
    Else If (Ch = '*') And (LexColNo + 2 <= Length(LexLine)) And
            (LexLine[LexColNo + 1] = '*') And
            (LexLine[LexColNo + 2] = '=') Then
    Begin
      Inc(LexColNo, 3);
      CurTokKind := TK_OP; CurTokStr := '**=';
      Scanning := False;
    End

    { ** (puissance) }
    Else If (Ch = '*') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '*') Then
    Begin
      Inc(LexColNo, 2);
      CurTokKind := TK_OP; CurTokStr := '**';
      Scanning := False;
    End

    { <=> (spaceship) }
    Else If (Ch = '<') And (LexColNo + 2 <= Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') And
            (LexLine[LexColNo + 2] = '>') Then
    Begin
      Inc(LexColNo, 3);
      CurTokKind := TK_OP; CurTokStr := '<=>';
      Scanning := False;
    End

    { === }
    Else If (Ch = '=') And (LexColNo + 2 <= Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') And
            (LexLine[LexColNo + 2] = '=') Then
    Begin
      Inc(LexColNo, 3);
      CurTokKind := TK_OP; CurTokStr := '===';
      Scanning := False;
    End

    { !== }
    Else If (Ch = '!') And (LexColNo + 2 <= Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') And
            (LexLine[LexColNo + 2] = '=') Then
    Begin
      Inc(LexColNo, 3);
      CurTokKind := TK_OP; CurTokStr := '!==';
      Scanning := False;
    End

    { ?? (null coalescing) }
    Else If (Ch = '?') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '?') Then
    Begin
      Inc(LexColNo, 2);
      CurTokKind := TK_OP; CurTokStr := '??';
      Scanning := False;
    End

    { ?: (Elvis/ternary short) }
    Else If (Ch = '?') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = ':') Then
    Begin
      Inc(LexColNo, 2);
      CurTokKind := TK_OP; CurTokStr := '?:';
      Scanning := False;
    End

    { => (double arrow) }
    Else If (Ch = '=') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '>') Then
    Begin
      Inc(LexColNo, 2);
      CurTokKind := TK_DOUBLE_ARROW;
      CurTokStr  := '=>';
      Scanning := False;
    End

    { -> (arrow) }
    Else If (Ch = '-') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '>') Then
    Begin
      Inc(LexColNo, 2);
      CurTokKind := TK_ARROW;
      CurTokStr  := '->';
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

    { .= (concatenation avec assignation) }
    Else If (Ch = '.') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo, 2);
      CurTokKind := TK_OP; CurTokStr := '.=';
      Scanning := False;
    End

    { . (concatenation) }
    Else If Ch = '.' Then
    Begin
      Inc(LexColNo);
      CurTokKind := TK_CONCAT;
      CurTokStr  := '.';
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
  If Not LexOpened And (LexSrcHead = Nil) Then
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
{ TODO 03 - RECONNAISSANCE DES MOTS-CLES PHP      [IMPLEMENTE] }
{ ============================================================ }

Const
  (* Mots-cles PHP : controle *)
  KW_IF         = 1;    (* if                                       *)
  KW_ELSEIF     = 2;    (* elseif                                   *)
  KW_ELSE       = 3;    (* else                                     *)
  KW_WHILE      = 4;    (* while                                    *)
  KW_FOR        = 5;    (* for                                      *)
  KW_FOREACH    = 6;    (* foreach                                  *)
  KW_DO         = 7;    (* do                                       *)
  KW_SWITCH     = 8;    (* switch                                   *)
  KW_CASE       = 9;    (* case                                     *)
  KW_DEFAULT    = 10;   (* default                                  *)
  KW_BREAK      = 11;   (* break                                    *)
  KW_CONTINUE   = 12;   (* continue                                 *)
  KW_RETURN     = 13;   (* return                                   *)

  (* Mots-cles PHP : fonctions et constantes *)
  KW_FUNCTION   = 20;   (* function                                 *)
  KW_CONST      = 21;   (* const                                    *)
  KW_DEFINE     = 22;   (* define                                   *)

  (* Mots-cles PHP : tableaux *)
  KW_ARRAY      = 30;   (* array                                    *)
  KW_AS         = 31;   (* as                                       *)

  (* Mots-cles PHP : logiques *)
  KW_TRUE       = 40;   (* true                                     *)
  KW_FALSE      = 41;   (* false                                    *)
  KW_NULL       = 42;   (* null                                     *)
  KW_AND        = 43;   (* and                                      *)
  KW_OR         = 44;   (* or                                       *)
  KW_XOR        = 45;   (* xor                                      *)

  (* Mots-cles PHP : autres (non implementes pour l instant) *)
  KW_ECHO       = 50;   (* echo                                     *)
  KW_PRINT      = 51;   (* print                                    *)
  KW_INCLUDE    = 52;   (* include                                  *)
  KW_REQUIRE    = 53;   (* require                                  *)
  KW_CLASS      = 54;   (* class (non implemente)                   *)
  KW_NEW        = 55;   (* new (non implemente)                     *)

  KW_TOTAL_KEYWORDS = 26;  (* nombre total de mots-cles PHP         *)

  (* Constantes predefinies PHP *)
  PHP_CONST_OS      = 'WINNT';
  PHP_CONST_INT_MAX = 2147483647;
  PHP_CONST_VERSION = '8.0';
  PHP_CONST_EOL     = #13#10;     (* CRLF sur Windows *)

Var
  KwInitialized : Boolean;       (* True si etat initialise              *)
  KwLookupCount : LongInt;       (* nombre d appels a LookupKeyword      *)
  KwHitCount    : LongInt;       (* nombre de mots-cles reconnus         *)
  KwLabelSeq    : Integer;       (* sequence pour labels uniques         *)
  KwLastKW      : Integer;       (* dernier mot-cle reconnu - KW_x       *)
  KwTotalIdents : LongInt;       (* total d identificateurs testes       *)

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
    KW_IF         : KwTypeName := 'KW_IF';
    KW_ELSEIF     : KwTypeName := 'KW_ELSEIF';
    KW_ELSE       : KwTypeName := 'KW_ELSE';
    KW_WHILE      : KwTypeName := 'KW_WHILE';
    KW_FOR        : KwTypeName := 'KW_FOR';
    KW_FOREACH    : KwTypeName := 'KW_FOREACH';
    KW_DO         : KwTypeName := 'KW_DO';
    KW_SWITCH     : KwTypeName := 'KW_SWITCH';
    KW_CASE       : KwTypeName := 'KW_CASE';
    KW_DEFAULT    : KwTypeName := 'KW_DEFAULT';
    KW_BREAK      : KwTypeName := 'KW_BREAK';
    KW_CONTINUE   : KwTypeName := 'KW_CONTINUE';
    KW_RETURN     : KwTypeName := 'KW_RETURN';
    KW_FUNCTION   : KwTypeName := 'KW_FUNCTION';
    KW_CONST      : KwTypeName := 'KW_CONST';
    KW_DEFINE     : KwTypeName := 'KW_DEFINE';
    KW_ARRAY      : KwTypeName := 'KW_ARRAY';
    KW_AS         : KwTypeName := 'KW_AS';
    KW_TRUE       : KwTypeName := 'KW_TRUE';
    KW_FALSE      : KwTypeName := 'KW_FALSE';
    KW_NULL       : KwTypeName := 'KW_NULL';
    KW_AND        : KwTypeName := 'KW_AND';
    KW_OR         : KwTypeName := 'KW_OR';
    KW_XOR        : KwTypeName := 'KW_XOR';
    KW_ECHO       : KwTypeName := 'KW_ECHO';
    KW_PRINT      : KwTypeName := 'KW_PRINT';
    KW_INCLUDE    : KwTypeName := 'KW_INCLUDE';
    KW_REQUIRE    : KwTypeName := 'KW_REQUIRE';
    KW_CLASS      : KwTypeName := 'KW_CLASS';
    KW_NEW        : KwTypeName := 'KW_NEW';
  Else
    KwTypeName := 'KW_UNKNOWN(' + ItoS(KW) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ LookupKeyword : retourner KW_xxx ou KW_NONE si non reconnu   }
{ PHP est insensible a la casse pour les mots-cles             }
{ ------------------------------------------------------------ }

Function LookupKeyword(Const S : TString) : Integer;
Var
  R   : Integer;
  Lwr : TString;
Begin
  Inc(KwLookupCount);
  Inc(KwTotalIdents);
  R := 0;

  (* Convertir en minuscules pour comparaison insensible *)
  Lwr := StrLowerCase(S);

  (* Controle *)
  If      Lwr = 'if'        Then R := KW_IF
  Else If Lwr = 'elseif'    Then R := KW_ELSEIF
  Else If Lwr = 'else'      Then R := KW_ELSE
  Else If Lwr = 'while'     Then R := KW_WHILE
  Else If Lwr = 'for'       Then R := KW_FOR
  Else If Lwr = 'foreach'   Then R := KW_FOREACH
  Else If Lwr = 'do'        Then R := KW_DO
  Else If Lwr = 'switch'    Then R := KW_SWITCH
  Else If Lwr = 'case'      Then R := KW_CASE
  Else If Lwr = 'default'   Then R := KW_DEFAULT
  Else If Lwr = 'break'     Then R := KW_BREAK
  Else If Lwr = 'continue'  Then R := KW_CONTINUE
  Else If Lwr = 'return'    Then R := KW_RETURN

  (* Fonctions et constantes *)
  Else If Lwr = 'function'  Then R := KW_FUNCTION
  Else If Lwr = 'const'     Then R := KW_CONST
  Else If Lwr = 'define'    Then R := KW_DEFINE

  (* Tableaux *)
  Else If Lwr = 'array'     Then R := KW_ARRAY
  Else If Lwr = 'as'        Then R := KW_AS

  (* Logiques *)
  Else If Lwr = 'true'      Then R := KW_TRUE
  Else If Lwr = 'false'     Then R := KW_FALSE
  Else If Lwr = 'null'      Then R := KW_NULL
  Else If Lwr = 'and'       Then R := KW_AND
  Else If Lwr = 'or'        Then R := KW_OR
  Else If Lwr = 'xor'       Then R := KW_XOR

  (* Autres *)
  Else If Lwr = 'echo'      Then R := KW_ECHO
  Else If Lwr = 'print'     Then R := KW_PRINT
  Else If Lwr = 'include'   Then R := KW_INCLUDE
  Else If Lwr = 'require'   Then R := KW_REQUIRE
  Else If Lwr = 'class'     Then R := KW_CLASS
  Else If Lwr = 'new'       Then R := KW_NEW;

  If R <> 0 Then
  Begin
    Inc(KwHitCount);
    KwLastKW := R;
  End;

  LookupKeyword := R;
End;

{ ------------------------------------------------------------ }
{ GetKeywordName : retourner le mot-cle PHP pour un KW_*       }
{ ------------------------------------------------------------ }

Function GetKeywordName(KW : Integer) : TString;
Begin
  Case KW Of
    KW_IF         : GetKeywordName := 'if';
    KW_ELSEIF     : GetKeywordName := 'elseif';
    KW_ELSE       : GetKeywordName := 'else';
    KW_WHILE      : GetKeywordName := 'while';
    KW_FOR        : GetKeywordName := 'for';
    KW_FOREACH    : GetKeywordName := 'foreach';
    KW_DO         : GetKeywordName := 'do';
    KW_SWITCH     : GetKeywordName := 'switch';
    KW_CASE       : GetKeywordName := 'case';
    KW_DEFAULT    : GetKeywordName := 'default';
    KW_BREAK      : GetKeywordName := 'break';
    KW_CONTINUE   : GetKeywordName := 'continue';
    KW_RETURN     : GetKeywordName := 'return';
    KW_FUNCTION   : GetKeywordName := 'function';
    KW_CONST      : GetKeywordName := 'const';
    KW_DEFINE     : GetKeywordName := 'define';
    KW_ARRAY      : GetKeywordName := 'array';
    KW_AS         : GetKeywordName := 'as';
    KW_TRUE       : GetKeywordName := 'true';
    KW_FALSE      : GetKeywordName := 'false';
    KW_NULL       : GetKeywordName := 'null';
    KW_AND        : GetKeywordName := 'and';
    KW_OR         : GetKeywordName := 'or';
    KW_XOR        : GetKeywordName := 'xor';
    KW_ECHO       : GetKeywordName := 'echo';
    KW_PRINT      : GetKeywordName := 'print';
    KW_INCLUDE    : GetKeywordName := 'include';
    KW_REQUIRE    : GetKeywordName := 'require';
    KW_CLASS      : GetKeywordName := 'class';
    KW_NEW        : GetKeywordName := 'new';
  Else
    GetKeywordName := '?';
  End;
End;

{ ------------------------------------------------------------ }
{ IsKeyword : teste si un KW_* est valide (non zero)           }
{ ------------------------------------------------------------ }

Function IsKeyword(KW : Integer) : Boolean;
Begin
  IsKeyword := (KW > 0) And (KW <= KW_NEW);
End;

{ ------------------------------------------------------------ }
{ IsPHPConstant : teste si un identificateur est une constante }
{ predefinies PHP (PHP_OS, PHP_INT_MAX, etc.)                  }
{ ------------------------------------------------------------ }

Function IsPHPConstant(Const S : TString) : Boolean;
Begin
  IsPHPConstant := (S = 'PHP_OS') Or (S = 'PHP_INT_MAX') Or
                   (S = 'PHP_VERSION') Or (S = 'PHP_EOL');
End;

{ ------------------------------------------------------------ }
{ GetPHPConstantValue : retourner la valeur d une constante    }
{ predefinies PHP (version entiere)                            }
{ ------------------------------------------------------------ }

Function GetPHPConstantInt(Const S : TString) : LongInt;
Begin
  If S = 'PHP_INT_MAX' Then
    GetPHPConstantInt := PHP_CONST_INT_MAX
  Else
    GetPHPConstantInt := 0;
End;

{ ------------------------------------------------------------ }
{ GetPHPConstantStr : retourner la valeur d une constante      }
{ predefinies PHP (version chaine)                             }
{ ------------------------------------------------------------ }

Function GetPHPConstantStr(Const S : TString) : TString;
Begin
  If S = 'PHP_OS' Then
    GetPHPConstantStr := PHP_CONST_OS
  Else If S = 'PHP_VERSION' Then
    GetPHPConstantStr := PHP_CONST_VERSION
  Else If S = 'PHP_EOL' Then
    GetPHPConstantStr := PHP_CONST_EOL
  Else
    GetPHPConstantStr := '';
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
{ TODO 04 - TABLE DES SYMBOLES PHP (32 BITS)      [IMPLEMENTE] }
{ ============================================================ }

Const
  (* Types de symboles *)
  SK_NONE     = 0;    (* symbole non initialise                    *)
  SK_LOCAL    = 1;    (* variable locale (pile EBP-offset)         *)
  SK_PARAM    = 2;    (* parametre de fonction (pile EBP+offset)   *)
  SK_GLOBAL   = 3;    (* variable globale (segment DATA)           *)
  SK_FUNC     = 4;    (* fonction utilisateur                      *)
  SK_CONST    = 5;    (* constante define() ou const               *)
  SK_ARRAY    = 6;    (* tableau (pointeur vers bloc)              *)

Type
  (* Enregistrement pour un symbole PHP *)
  TSymRec = Record
    Name       : TString;   (* nom PHP ($x, maFonction, MA_CONST)    *)
    AsmName    : TString;   (* label ASM (_PH_x, _PF_maFonction)     *)
    Kind       : Integer;   (* type de symbole (SK_LOCAL, etc.)      *)
    TypeIdx    : Integer;   (* indice dans la table des types        *)
    Offset     : Integer;   (* offset pile ou segment DATA           *)
    ScopeLevel : Integer;   (* niveau de portee imbrique             *)
    IsGlobal   : Boolean;   (* True si variable globale              *)
    IsConst    : Boolean;   (* True si constante define() ou const   *)
    DeclLine   : Integer;   (* numero de ligne de declaration        *)
    ConstVal   : LongInt;   (* valeur si constante entiere           *)
    ConstStr   : TString;   (* valeur si constante chaine            *)
    ParamCount : Integer;   (* nombre de parametres si SK_FUNC       *)
  End;

  TSymArray = Array[1..MAX_SYM] Of TSymRec;

Var
  SymTab        : TSymArray;   (* table des symboles                  *)
  SymCount      : Integer;     (* nombre de symboles enregistres      *)
  SymInitialized: Boolean;     (* True si table initialisee           *)
  CurScope      : Integer;     (* niveau de portee courant            *)
  SymLabelSeq   : Integer;     (* sequence pour labels uniques        *)
  SymLastAdd    : Integer;     (* dernier symbole ajoute              *)
  SymGlobalOff  : Integer;     (* offset courant dans segment DATA    *)
  SymLocalOff   : Integer;     (* offset courant dans pile locale     *)
  SymParamOff   : Integer;     (* offset courant dans pile parametres *)
  SymScopeStack : Array[1..MAX_SCOPE] Of Integer;  (* pile de portees *)
  SymScopeTop   : Integer;     (* sommet de la pile de portees        *)
  SymFindCount  : LongInt;     (* nombre de recherches effectuees     *)
  SymAddCount   : LongInt;     (* nombre d ajouts effectues           *)

{ ------------------------------------------------------------ }
{ InitSymState : initialiser la table des symboles             }
{ ------------------------------------------------------------ }

Procedure InitSymState;
Var I : Integer;
Begin
  SymInitialized := True;
  SymCount       := 0;
  CurScope       := 0;
  SymLabelSeq    := 0;
  SymLastAdd     := 0;
  SymGlobalOff   := 0;
  SymLocalOff    := 0;
  SymParamOff    := 8;   (* EBP+8 pour premier parametre *)
  SymScopeTop    := 0;
  SymFindCount   := 0;
  SymAddCount    := 0;

  For I := 1 To MAX_SYM Do
  Begin
    SymTab[I].Name       := '';
    SymTab[I].AsmName    := '';
    SymTab[I].Kind       := SK_NONE;
    SymTab[I].TypeIdx    := 0;
    SymTab[I].Offset     := 0;
    SymTab[I].ScopeLevel := 0;
    SymTab[I].IsGlobal   := False;
    SymTab[I].IsConst    := False;
    SymTab[I].DeclLine   := 0;
    SymTab[I].ConstVal   := 0;
    SymTab[I].ConstStr   := '';
    SymTab[I].ParamCount := 0;
  End;

  For I := 1 To MAX_SCOPE Do
    SymScopeStack[I] := 0;
End;

{ ------------------------------------------------------------ }
{ GenSymLabel : generer un label unique _SY_N                   }
{ ------------------------------------------------------------ }

Function GenSymLabel : TString;
Begin
  Inc(SymLabelSeq);
  GenSymLabel := '_SY_' + ItoS(SymLabelSeq);
End;

{ ------------------------------------------------------------ }
{ SymTypeName : retourner le nom du type de symbole SK_*       }
{ ------------------------------------------------------------ }

Function SymTypeName(SK : Integer) : TString;
Begin
  Case SK Of
    SK_NONE   : SymTypeName := 'SK_NONE';
    SK_LOCAL  : SymTypeName := 'SK_LOCAL';
    SK_PARAM  : SymTypeName := 'SK_PARAM';
    SK_GLOBAL : SymTypeName := 'SK_GLOBAL';
    SK_FUNC   : SymTypeName := 'SK_FUNC';
    SK_CONST  : SymTypeName := 'SK_CONST';
    SK_ARRAY  : SymTypeName := 'SK_ARRAY';
  Else
    SymTypeName := 'SK_UNKNOWN(' + ItoS(SK) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ SymNameClean : nettoyer un nom de variable ($x -> x)          }
{ ------------------------------------------------------------ }

Function SymNameClean(Const S : TString) : TString;
Begin
  If (Length(S) > 0) And (S[1] = '$') Then
    SymNameClean := Copy(S, 2, Length(S) - 1)
  Else
    SymNameClean := S;
End;

{ ------------------------------------------------------------ }
{ SymMakeAsmName : generer le nom ASM pour un symbole          }
{ ------------------------------------------------------------ }

Function SymMakeAsmName(Const Name : TString; Kind : Integer) : TString;
Var Clean : TString;
Begin
  Clean := SymNameClean(Name);
  Clean := AsmIdent(Clean);

  Case Kind Of
    SK_LOCAL  : SymMakeAsmName := Clean;  (* local = nom simple *)
    SK_PARAM  : SymMakeAsmName := Clean;  (* param = nom simple *)
    SK_GLOBAL : SymMakeAsmName := PH_VAR_PFX + Clean;
    SK_FUNC   : SymMakeAsmName := PH_FN_PFX + Clean;
    SK_CONST  : SymMakeAsmName := PH_VAR_PFX + Clean;
    SK_ARRAY  : SymMakeAsmName := PH_ARR_PFX + Clean;
  Else
    SymMakeAsmName := Clean;
  End;
End;

{ ------------------------------------------------------------ }
{ SymFind : rechercher un symbole par nom dans toutes portees  }
{ Retourne l indice (1..SymCount) ou 0 si non trouve           }
{ Recherche du scope courant vers le global                    }
{ ------------------------------------------------------------ }

Function SymFind(Const Name : TString) : Integer;
Var
  I     : Integer;
  Found : Integer;
  Scope : Integer;
Begin
  Inc(SymFindCount);
  Found := 0;

  (* Recherche du scope courant vers le global *)
  For Scope := CurScope DownTo 0 Do
  Begin
    For I := 1 To SymCount Do
    Begin
      If (SymTab[I].Name = Name) And
         (SymTab[I].ScopeLevel = Scope) Then
      Begin
        Found := I;
        Break;
      End;
    End;
    If Found <> 0 Then Break;
  End;

  SymFind := Found;
End;

{ ------------------------------------------------------------ }
{ SymFindInScope : rechercher un symbole dans une portee donnee}
{ ------------------------------------------------------------ }

Function SymFindInScope(Const Name : TString; Scope : Integer) : Integer;
Var
  I     : Integer;
  Found : Integer;
Begin
  Inc(SymFindCount);
  Found := 0;

  For I := 1 To SymCount Do
  Begin
    If (SymTab[I].Name = Name) And
       (SymTab[I].ScopeLevel = Scope) Then
    Begin
      Found := I;
      Break;
    End;
  End;

  SymFindInScope := Found;
End;

{ ------------------------------------------------------------ }
{ SymFindGlobal : rechercher un symbole dans le scope global   }
{ ------------------------------------------------------------ }

Function SymFindGlobal(Const Name : TString) : Integer;
Begin
  SymFindGlobal := SymFindInScope(Name, 0);
End;

{ ------------------------------------------------------------ }
{ SymAdd : ajouter un symbole a la table                       }
{ Retourne l indice du nouveau symbole ou 0 si erreur          }
{ ------------------------------------------------------------ }

Function SymAdd(Const Name : TString; Kind : Integer;
                TypeIdx : Integer; DeclLine : Integer) : Integer;
Var
  Idx : Integer;
Begin
  Inc(SymAddCount);

  (* Verifier la limite *)
  If SymCount >= MAX_SYM Then
  Begin
    WarnMsg('Limite de symboles atteinte (' + ItoS(MAX_SYM) + ')');
    SymAdd := 0;
    Exit;
  End;

  (* Verifier si deja declare dans le scope courant *)
  Idx := SymFindInScope(Name, CurScope);
  If Idx <> 0 Then
  Begin
    WarnMsg('Symbole "' + Name + '" deja declare ligne ' +
            ItoS(SymTab[Idx].DeclLine));
    SymAdd := Idx;  (* retourner l existant *)
    Exit;
  End;

  (* Ajouter le nouveau symbole *)
  Inc(SymCount);
  Idx := SymCount;

  SymTab[Idx].Name       := Name;
  SymTab[Idx].AsmName    := SymMakeAsmName(Name, Kind);
  SymTab[Idx].Kind       := Kind;
  SymTab[Idx].TypeIdx    := TypeIdx;
  SymTab[Idx].ScopeLevel := CurScope;
  SymTab[Idx].DeclLine   := DeclLine;
  SymTab[Idx].ConstVal   := 0;
  SymTab[Idx].ConstStr   := '';
  SymTab[Idx].ParamCount := 0;

  (* Calculer l offset selon le type *)
  Case Kind Of
    SK_LOCAL:
    Begin
      Dec(SymLocalOff, 4);  (* 4 octets par variable locale *)
      SymTab[Idx].Offset   := SymLocalOff;
      SymTab[Idx].IsGlobal := False;
      SymTab[Idx].IsConst  := False;
    End;

    SK_PARAM:
    Begin
      SymTab[Idx].Offset   := SymParamOff;
      Inc(SymParamOff, 4);  (* 4 octets par parametre *)
      SymTab[Idx].IsGlobal := False;
      SymTab[Idx].IsConst  := False;
    End;

    SK_GLOBAL:
    Begin
      SymTab[Idx].Offset   := SymGlobalOff;
      Inc(SymGlobalOff, 4); (* 4 octets par variable globale *)
      SymTab[Idx].IsGlobal := True;
      SymTab[Idx].IsConst  := False;
    End;

    SK_FUNC:
    Begin
      SymTab[Idx].Offset   := 0;  (* fonctions n ont pas d offset *)
      SymTab[Idx].IsGlobal := True;
      SymTab[Idx].IsConst  := False;
    End;

    SK_CONST:
    Begin
      SymTab[Idx].Offset   := SymGlobalOff;
      Inc(SymGlobalOff, 4);
      SymTab[Idx].IsGlobal := True;
      SymTab[Idx].IsConst  := True;
    End;

    SK_ARRAY:
    Begin
      SymTab[Idx].Offset   := SymGlobalOff;
      Inc(SymGlobalOff, 4); (* pointeur vers le bloc tableau *)
      SymTab[Idx].IsGlobal := (CurScope = 0);
      SymTab[Idx].IsConst  := False;
    End;
  Else
    SymTab[Idx].Offset   := 0;
    SymTab[Idx].IsGlobal := False;
    SymTab[Idx].IsConst  := False;
  End;

  SymLastAdd := Idx;
  SymAdd := Idx;
End;

{ ------------------------------------------------------------ }
{ SymAddConst : ajouter une constante avec sa valeur           }
{ ------------------------------------------------------------ }

Function SymAddConst(Const Name : TString; IntVal : LongInt;
                     DeclLine : Integer) : Integer;
Var Idx : Integer;
Begin
  Idx := SymAdd(Name, SK_CONST, 0, DeclLine);
  If Idx > 0 Then
    SymTab[Idx].ConstVal := IntVal;
  SymAddConst := Idx;
End;

{ ------------------------------------------------------------ }
{ SymAddConstStr : ajouter une constante chaine                }
{ ------------------------------------------------------------ }

Function SymAddConstStr(Const Name : TString; Const StrVal : TString;
                        DeclLine : Integer) : Integer;
Var Idx : Integer;
Begin
  Idx := SymAdd(Name, SK_CONST, 0, DeclLine);
  If Idx > 0 Then
    SymTab[Idx].ConstStr := StrVal;
  SymAddConstStr := Idx;
End;

{ ------------------------------------------------------------ }
{ SymAddFunc : ajouter une fonction avec son nombre de params  }
{ ------------------------------------------------------------ }

Function SymAddFunc(Const Name : TString; ParamCount : Integer;
                    DeclLine : Integer) : Integer;
Var Idx : Integer;
Begin
  Idx := SymAdd(Name, SK_FUNC, 0, DeclLine);
  If Idx > 0 Then
    SymTab[Idx].ParamCount := ParamCount;
  SymAddFunc := Idx;
End;

{ ------------------------------------------------------------ }
{ SymEnterScope : entrer dans une nouvelle portee              }
{ ------------------------------------------------------------ }

Procedure SymEnterScope;
Begin
  If SymScopeTop >= MAX_SCOPE Then
  Begin
    WarnMsg('Profondeur de portee maximale atteinte');
    Exit;
  End;

  Inc(SymScopeTop);
  SymScopeStack[SymScopeTop] := CurScope;
  Inc(CurScope);

  (* Reinitialiser les offsets locaux pour la nouvelle portee *)
  SymLocalOff := 0;
  SymParamOff := 8;  (* EBP+8 pour premier parametre *)
End;

{ ------------------------------------------------------------ }
{ SymLeaveScope : quitter la portee courante                   }
{ ------------------------------------------------------------ }

Procedure SymLeaveScope;
Begin
  If SymScopeTop <= 0 Then
  Begin
    WarnMsg('Pas de portee a quitter');
    Exit;
  End;

  CurScope := SymScopeStack[SymScopeTop];
  Dec(SymScopeTop);
End;

{ ------------------------------------------------------------ }
{ SymGetByIndex : obtenir un symbole par son index             }
{ ------------------------------------------------------------ }

Function SymGetName(Idx : Integer) : TString;
Begin
  If (Idx >= 1) And (Idx <= SymCount) Then
    SymGetName := SymTab[Idx].Name
  Else
    SymGetName := '';
End;

Function SymGetAsmName(Idx : Integer) : TString;
Begin
  If (Idx >= 1) And (Idx <= SymCount) Then
    SymGetAsmName := SymTab[Idx].AsmName
  Else
    SymGetAsmName := '';
End;

Function SymGetKind(Idx : Integer) : Integer;
Begin
  If (Idx >= 1) And (Idx <= SymCount) Then
    SymGetKind := SymTab[Idx].Kind
  Else
    SymGetKind := SK_NONE;
End;

Function SymGetOffset(Idx : Integer) : Integer;
Begin
  If (Idx >= 1) And (Idx <= SymCount) Then
    SymGetOffset := SymTab[Idx].Offset
  Else
    SymGetOffset := 0;
End;

Function SymGetConstVal(Idx : Integer) : LongInt;
Begin
  If (Idx >= 1) And (Idx <= SymCount) Then
    SymGetConstVal := SymTab[Idx].ConstVal
  Else
    SymGetConstVal := 0;
End;

Function SymGetConstStr(Idx : Integer) : TString;
Begin
  If (Idx >= 1) And (Idx <= SymCount) Then
    SymGetConstStr := SymTab[Idx].ConstStr
  Else
    SymGetConstStr := '';
End;

Function SymIsGlobal(Idx : Integer) : Boolean;
Begin
  If (Idx >= 1) And (Idx <= SymCount) Then
    SymIsGlobal := SymTab[Idx].IsGlobal
  Else
    SymIsGlobal := False;
End;

Function SymIsConst(Idx : Integer) : Boolean;
Begin
  If (Idx >= 1) And (Idx <= SymCount) Then
    SymIsConst := SymTab[Idx].IsConst
  Else
    SymIsConst := False;
End;

{ ------------------------------------------------------------ }
{ DumpSymState : afficher l etat de la table des symboles      }
{ ------------------------------------------------------------ }

Procedure DumpSymState;
Var I : Integer;
Begin
  WriteLn('--- Symbol Table State ---');
  WriteLn('  SymInitialized : ', SymInitialized);
  WriteLn('  SymCount       : ', SymCount);
  WriteLn('  CurScope       : ', CurScope);
  WriteLn('  SymScopeTop    : ', SymScopeTop);
  WriteLn('  SymGlobalOff   : ', SymGlobalOff);
  WriteLn('  SymLocalOff    : ', SymLocalOff);
  WriteLn('  SymParamOff    : ', SymParamOff);
  WriteLn('  SymFindCount   : ', SymFindCount);
  WriteLn('  SymAddCount    : ', SymAddCount);

  If SymCount > 0 Then
  Begin
    WriteLn('--- Symbols ---');
    For I := 1 To SymCount Do
    Begin
      WriteLn('  [', I, '] ', SymTab[I].Name, ' -> ', SymTab[I].AsmName,
              ' (', SymTypeName(SymTab[I].Kind), ')',
              ' scope=', SymTab[I].ScopeLevel,
              ' off=', SymTab[I].Offset,
              ' line=', SymTab[I].DeclLine);
    End;
  End;
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
  IsSymEmpty := (SymCount = 0);
End;

Function GetSymCount : Integer;
Begin
  GetSymCount := SymCount;
End;

Function GetCurScope : Integer;
Begin
  GetCurScope := CurScope;
End;

Function GetSymGlobalOff : Integer;
Begin
  GetSymGlobalOff := SymGlobalOff;
End;

Function GetSymLocalOff : Integer;
Begin
  GetSymLocalOff := SymLocalOff;
End;

Function GetSymParamOff : Integer;
Begin
  GetSymParamOff := SymParamOff;
End;

Function GetSymFindCount : LongInt;
Begin
  GetSymFindCount := SymFindCount;
End;

Function GetSymAddCount : LongInt;
Begin
  GetSymAddCount := SymAddCount;
End;

Function GetSymStatus : TString;
Begin
  If Not SymInitialized Then
    GetSymStatus := 'Not initialized'
  Else
    GetSymStatus := ItoS(SymCount) + ' symbols, scope=' + ItoS(CurScope);
End;

{ ============================================================ }
{ TODO 05 - SYSTEME DE TYPES PHP                  [IMPLEMENTE] }
{ ============================================================ }

Const
  (* Types de donnees PHP (TTypeKind) *)
  TYK_INT     = 0;    (* entier 32 bits signe                      *)
  TYK_FLOAT   = 1;    (* flottant (tronque en entier)              *)
  TYK_STRING  = 2;    (* pointeur vers chaine                      *)
  TYK_BOOL    = 3;    (* booleen 32 bits (0/1)                     *)
  TYK_ARRAY   = 4;    (* pointeur vers tableau                     *)
  TYK_NULL    = 5;    (* reference nulle                           *)
  TYK_MIXED   = 6;    (* type dynamique                            *)
  TYK_VOID    = 7;    (* pas de valeur (retour fonction)           *)

  (* Indices des types primitifs dans TypeTab *)
  TY_IDX_INT    = 0;
  TY_IDX_FLOAT  = 1;
  TY_IDX_STRING = 2;
  TY_IDX_BOOL   = 3;
  TY_IDX_ARRAY  = 4;
  TY_IDX_NULL   = 5;
  TY_IDX_MIXED  = 6;
  TY_IDX_VOID   = 7;

  TY_PRIMITIVE_COUNT = 8;   (* nombre de types primitifs *)

Type
  (* Enregistrement pour un type PHP *)
  TTypeRec = Record
    Name     : TString;    (* nom du type (int, string, etc.)         *)
    Kind     : Integer;    (* TYK_INT, TYK_STRING, etc.               *)
    Size     : Integer;    (* taille en octets (4 pour 32 bits)       *)
    IsArray  : Boolean;    (* True si type tableau                    *)
    ElemType : Integer;    (* indice du type element si tableau       *)
  End;

  TTypeArray = Array[0..MAX_TYPE-1] Of TTypeRec;

Var
  TypeTab        : TTypeArray;  (* table des types                      *)
  TypeCount      : Integer;     (* nombre de types enregistres          *)
  TyInitialized  : Boolean;     (* True si table initialisee            *)
  TyLabelSeq     : Integer;     (* sequence pour labels uniques         *)
  TyLastAdd      : Integer;     (* dernier type ajoute                  *)
  TyFindCount    : LongInt;     (* nombre de recherches effectuees      *)
  TyAddCount     : LongInt;     (* nombre d ajouts effectues            *)

{ ------------------------------------------------------------ }
{ InitTypeState : initialiser la table des types primitifs     }
{ ------------------------------------------------------------ }

Procedure InitTypeState;
Var I : Integer;
Begin
  TyInitialized := True;
  TypeCount     := 0;
  TyLabelSeq    := 0;
  TyLastAdd     := -1;
  TyFindCount   := 0;
  TyAddCount    := 0;

  (* Initialiser tous les slots a vide *)
  For I := 0 To MAX_TYPE - 1 Do
  Begin
    TypeTab[I].Name     := '';
    TypeTab[I].Kind     := TYK_VOID;
    TypeTab[I].Size     := 0;
    TypeTab[I].IsArray  := False;
    TypeTab[I].ElemType := -1;
  End;

  (* Enregistrer les types primitifs PHP dans l ordre fixe *)
  (* Index 0 : int *)
  TypeTab[TY_IDX_INT].Name     := 'int';
  TypeTab[TY_IDX_INT].Kind     := TYK_INT;
  TypeTab[TY_IDX_INT].Size     := 4;
  TypeTab[TY_IDX_INT].IsArray  := False;
  TypeTab[TY_IDX_INT].ElemType := -1;

  (* Index 1 : float *)
  TypeTab[TY_IDX_FLOAT].Name     := 'float';
  TypeTab[TY_IDX_FLOAT].Kind     := TYK_FLOAT;
  TypeTab[TY_IDX_FLOAT].Size     := 4;  (* tronque en int 32 bits *)
  TypeTab[TY_IDX_FLOAT].IsArray  := False;
  TypeTab[TY_IDX_FLOAT].ElemType := -1;

  (* Index 2 : string *)
  TypeTab[TY_IDX_STRING].Name     := 'string';
  TypeTab[TY_IDX_STRING].Kind     := TYK_STRING;
  TypeTab[TY_IDX_STRING].Size     := 4;  (* pointeur 32 bits *)
  TypeTab[TY_IDX_STRING].IsArray  := False;
  TypeTab[TY_IDX_STRING].ElemType := -1;

  (* Index 3 : bool *)
  TypeTab[TY_IDX_BOOL].Name     := 'bool';
  TypeTab[TY_IDX_BOOL].Kind     := TYK_BOOL;
  TypeTab[TY_IDX_BOOL].Size     := 4;
  TypeTab[TY_IDX_BOOL].IsArray  := False;
  TypeTab[TY_IDX_BOOL].ElemType := -1;

  (* Index 4 : array *)
  TypeTab[TY_IDX_ARRAY].Name     := 'array';
  TypeTab[TY_IDX_ARRAY].Kind     := TYK_ARRAY;
  TypeTab[TY_IDX_ARRAY].Size     := 4;  (* pointeur 32 bits *)
  TypeTab[TY_IDX_ARRAY].IsArray  := True;
  TypeTab[TY_IDX_ARRAY].ElemType := TY_IDX_MIXED;

  (* Index 5 : null *)
  TypeTab[TY_IDX_NULL].Name     := 'null';
  TypeTab[TY_IDX_NULL].Kind     := TYK_NULL;
  TypeTab[TY_IDX_NULL].Size     := 0;
  TypeTab[TY_IDX_NULL].IsArray  := False;
  TypeTab[TY_IDX_NULL].ElemType := -1;

  (* Index 6 : mixed *)
  TypeTab[TY_IDX_MIXED].Name     := 'mixed';
  TypeTab[TY_IDX_MIXED].Kind     := TYK_MIXED;
  TypeTab[TY_IDX_MIXED].Size     := 4;
  TypeTab[TY_IDX_MIXED].IsArray  := False;
  TypeTab[TY_IDX_MIXED].ElemType := -1;

  (* Index 7 : void *)
  TypeTab[TY_IDX_VOID].Name     := 'void';
  TypeTab[TY_IDX_VOID].Kind     := TYK_VOID;
  TypeTab[TY_IDX_VOID].Size     := 0;
  TypeTab[TY_IDX_VOID].IsArray  := False;
  TypeTab[TY_IDX_VOID].ElemType := -1;

  TypeCount := TY_PRIMITIVE_COUNT;
End;

{ ------------------------------------------------------------ }
{ GenTyLabel : generer un label unique _TY_N                    }
{ ------------------------------------------------------------ }

Function GenTyLabel : TString;
Begin
  Inc(TyLabelSeq);
  GenTyLabel := '_TY_' + ItoS(TyLabelSeq);
End;

{ ------------------------------------------------------------ }
{ TyKindName : retourner le nom textuel d un TTypeKind         }
{ ------------------------------------------------------------ }

Function TyKindName(K : Integer) : TString;
Begin
  Case K Of
    TYK_INT    : TyKindName := 'TYK_INT';
    TYK_FLOAT  : TyKindName := 'TYK_FLOAT';
    TYK_STRING : TyKindName := 'TYK_STRING';
    TYK_BOOL   : TyKindName := 'TYK_BOOL';
    TYK_ARRAY  : TyKindName := 'TYK_ARRAY';
    TYK_NULL   : TyKindName := 'TYK_NULL';
    TYK_MIXED  : TyKindName := 'TYK_MIXED';
    TYK_VOID   : TyKindName := 'TYK_VOID';
  Else
    TyKindName := 'TYK_UNKNOWN(' + ItoS(K) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ TypeKindOf : retourner le TTypeKind pour un indice de type   }
{ ------------------------------------------------------------ }

Function TypeKindOf(Idx : Integer) : Integer;
Begin
  If (Idx >= 0) And (Idx < TypeCount) Then
    TypeKindOf := TypeTab[Idx].Kind
  Else
    TypeKindOf := TYK_VOID;
End;

{ ------------------------------------------------------------ }
{ TypeSizeOf : retourner la taille en octets d un type         }
{ ------------------------------------------------------------ }

Function TypeSizeOf(Idx : Integer) : Integer;
Begin
  If (Idx >= 0) And (Idx < TypeCount) Then
    TypeSizeOf := TypeTab[Idx].Size
  Else
    TypeSizeOf := 0;
End;

{ ------------------------------------------------------------ }
{ TypeNameOf : retourner le nom d un type par son indice       }
{ ------------------------------------------------------------ }

Function TypeNameOf(Idx : Integer) : TString;
Begin
  If (Idx >= 0) And (Idx < TypeCount) Then
    TypeNameOf := TypeTab[Idx].Name
  Else
    TypeNameOf := '?';
End;

{ ------------------------------------------------------------ }
{ TypeFindByName : rechercher un type par nom                  }
{ Retourne l indice ou -1 si non trouve                        }
{ ------------------------------------------------------------ }

Function TypeFindByName(Const Name : TString) : Integer;
Var
  I   : Integer;
  Lwr : TString;
Begin
  Inc(TyFindCount);
  Lwr := StrLowerCase(Name);

  For I := 0 To TypeCount - 1 Do
  Begin
    If StrLowerCase(TypeTab[I].Name) = Lwr Then
    Begin
      TypeFindByName := I;
      Exit;
    End;
  End;

  TypeFindByName := -1;
End;

{ ------------------------------------------------------------ }
{ TypeAdd : ajouter un nouveau type dans la table              }
{ Retourne l indice du nouveau type ou -1 si erreur            }
{ ------------------------------------------------------------ }

Function TypeAdd(Const Name : TString; Kind : Integer;
                 Size : Integer; IsArray : Boolean;
                 ElemType : Integer) : Integer;
Var Idx : Integer;
Begin
  Inc(TyAddCount);

  (* Verifier la limite *)
  If TypeCount >= MAX_TYPE Then
  Begin
    WarnMsg('Limite de types atteinte (' + ItoS(MAX_TYPE) + ')');
    TypeAdd := -1;
    Exit;
  End;

  (* Verifier si deja defini *)
  Idx := TypeFindByName(Name);
  If Idx >= 0 Then
  Begin
    TypeAdd := Idx;  (* retourner l existant *)
    Exit;
  End;

  (* Ajouter le nouveau type *)
  Idx := TypeCount;
  TypeTab[Idx].Name     := Name;
  TypeTab[Idx].Kind     := Kind;
  TypeTab[Idx].Size     := Size;
  TypeTab[Idx].IsArray  := IsArray;
  TypeTab[Idx].ElemType := ElemType;

  Inc(TypeCount);
  TyLastAdd := Idx;
  TypeAdd := Idx;
End;

{ ------------------------------------------------------------ }
{ TypeIsArray : teste si un type est un tableau                }
{ ------------------------------------------------------------ }

Function TypeIsArray(Idx : Integer) : Boolean;
Begin
  If (Idx >= 0) And (Idx < TypeCount) Then
    TypeIsArray := TypeTab[Idx].IsArray
  Else
    TypeIsArray := False;
End;

{ ------------------------------------------------------------ }
{ TypeGetElem : retourne l indice du type element (tableau)    }
{ ------------------------------------------------------------ }

Function TypeGetElem(Idx : Integer) : Integer;
Begin
  If (Idx >= 0) And (Idx < TypeCount) And TypeTab[Idx].IsArray Then
    TypeGetElem := TypeTab[Idx].ElemType
  Else
    TypeGetElem := -1;
End;

{ ------------------------------------------------------------ }
{ TypeCanJuggle : teste si le juggling est possible entre      }
{ deux types PHP (conversion implicite)                        }
{ ------------------------------------------------------------ }

Function TypeCanJuggle(FromIdx, ToIdx : Integer) : Boolean;
Var FromK, ToK : Integer;
Begin
  FromK := TypeKindOf(FromIdx);
  ToK   := TypeKindOf(ToIdx);

  (* Meme type : toujours OK *)
  If FromK = ToK Then
  Begin
    TypeCanJuggle := True;
    Exit;
  End;

  (* Regles de juggling PHP *)
  Case FromK Of
    TYK_INT:
      TypeCanJuggle := (ToK = TYK_FLOAT) Or (ToK = TYK_STRING) Or
                       (ToK = TYK_BOOL) Or (ToK = TYK_MIXED);
    TYK_FLOAT:
      TypeCanJuggle := (ToK = TYK_INT) Or (ToK = TYK_STRING) Or
                       (ToK = TYK_BOOL) Or (ToK = TYK_MIXED);
    TYK_STRING:
      TypeCanJuggle := (ToK = TYK_INT) Or (ToK = TYK_FLOAT) Or
                       (ToK = TYK_BOOL) Or (ToK = TYK_MIXED);
    TYK_BOOL:
      TypeCanJuggle := (ToK = TYK_INT) Or (ToK = TYK_STRING) Or
                       (ToK = TYK_MIXED);
    TYK_NULL:
      TypeCanJuggle := (ToK = TYK_BOOL) Or (ToK = TYK_STRING) Or
                       (ToK = TYK_MIXED);
    TYK_MIXED:
      TypeCanJuggle := True;  (* mixed accepte tout *)
  Else
    TypeCanJuggle := False;
  End;
End;

{ ------------------------------------------------------------ }
{ DumpTypeState : afficher l etat de la table des types        }
{ ------------------------------------------------------------ }

Procedure DumpTypeState;
Var I : Integer;
Begin
  WriteLn('--- Type State ---');
  WriteLn('  TyInitialized : ', TyInitialized);
  WriteLn('  TypeCount     : ', TypeCount);
  WriteLn('  TyLabelSeq    : ', TyLabelSeq);
  WriteLn('  TyFindCount   : ', TyFindCount);
  WriteLn('  TyAddCount    : ', TyAddCount);

  If TypeCount > 0 Then
  Begin
    WriteLn('--- Types ---');
    For I := 0 To TypeCount - 1 Do
    Begin
      Write('  [', I, '] ', TypeTab[I].Name, ' : ');
      Write(TyKindName(TypeTab[I].Kind));
      Write(', size=', TypeTab[I].Size);
      If TypeTab[I].IsArray Then
        Write(', array of [', TypeTab[I].ElemType, ']');
      WriteLn;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 05)                             }
{ ------------------------------------------------------------ }

Function IsTyInitialized : Boolean;
Begin
  IsTyInitialized := TyInitialized;
End;

Function IsTyEmpty : Boolean;
Begin
  IsTyEmpty := (TypeCount = 0);
End;

Function GetTypeCount : Integer;
Begin
  GetTypeCount := TypeCount;
End;

Function GetTyLabelSeq : Integer;
Begin
  GetTyLabelSeq := TyLabelSeq;
End;

Function GetTyLastAdd : Integer;
Begin
  GetTyLastAdd := TyLastAdd;
End;

Function GetTyFindCount : LongInt;
Begin
  GetTyFindCount := TyFindCount;
End;

Function GetTyAddCount : LongInt;
Begin
  GetTyAddCount := TyAddCount;
End;

Function GetTyPrimitiveCount : Integer;
Begin
  GetTyPrimitiveCount := TY_PRIMITIVE_COUNT;
End;

Function GetTyIdxMixed : Integer;
Begin
  GetTyIdxMixed := TY_IDX_MIXED;
End;

Function GetTyStatus : TString;
Begin
  If Not TyInitialized Then
    GetTyStatus := 'Not initialized'
  Else
    GetTyStatus := ItoS(TypeCount) + ' types (' +
                   ItoS(TY_PRIMITIVE_COUNT) + ' primitives)';
End;

{ ============================================================ }
{ TODO 06 - LITTERAUX ET CONSTANTES               [IMPLEMENTE] }
{ ============================================================ }

Const
  (* Types de resultats d expression (TExprKind) *)
  EK_NONE   = 0;    (* expression invalide ou non initialisee    *)
  EK_IMM    = 1;    (* valeur immediate (constante)              *)
  EK_EAX    = 2;    (* resultat dans EAX                         *)
  EK_MEM    = 3;    (* reference memoire (variable/tableau)      *)

  (* Types de donnees dans le segment DATA (TDataKind) *)
  DK_DWORD     = 0; (* DWORD (entier 32 bits)                    *)
  DK_BYTE      = 1; (* BYTE (octet)                              *)
  DK_STR       = 2; (* chaine terminee par $00                   *)
  DK_ARRAY_BLK = 3; (* bloc de tableau (size + elements)         *)

  (* Limites pour le segment DATA *)
  MAX_DATA_ENTRIES = 512;   (* nombre max d entrees DATA         *)
  MAX_DATA_STRSIZE = 4096;  (* taille max d une chaine DATA      *)

Type
  (* Valeur d expression evaluee *)
  TExprVal = Record
    Kind    : Integer;      (* EK_NONE, EK_IMM, EK_EAX, EK_MEM   *)
    ImmVal  : LongInt;      (* valeur immediate si EK_IMM        *)
    TypeIdx : Integer;      (* indice du type dans TypeTab       *)
    Offset  : Integer;      (* offset memoire si EK_MEM          *)
    SymIdx  : Integer;      (* indice symbole si EK_MEM          *)
  End;

  (* Entree dans le segment DATA *)
  TDataRec = Record
    LblName   : TString;    (* label ASM (_PK_0, _PA_1, etc.)    *)
    Kind      : Integer;    (* DK_DWORD, DK_STR, etc.            *)
    IntVal    : LongInt;    (* valeur si DK_DWORD                *)
    StrVal    : TString;    (* chaine si DK_STR                  *)
    ElemCount : Integer;    (* nombre d elements si DK_ARRAY_BLK *)
  End;

  TDataArray = Array[1..MAX_DATA_ENTRIES] Of TDataRec;

Var
  LtInitialized : Boolean;    (* True si module initialise         *)
  LtLabelSeq    : Integer;    (* sequence pour labels uniques      *)
  DataTab       : TDataArray; (* table des donnees DATA            *)
  DataCount     : Integer;    (* nombre d entrees DATA             *)
  LtLastLabel   : TString;    (* dernier label genere              *)
  LtStrCount    : Integer;    (* nombre de chaines ajoutees        *)
  LtDWordCount  : Integer;    (* nombre de DWORDs ajoutes          *)
  LtArrayCount  : Integer;    (* nombre de tableaux ajoutes        *)
  LtTotalBytes  : LongInt;    (* total octets segment DATA         *)
  LtFindCount   : LongInt;    (* nombre de recherches              *)
  LtAddCount    : LongInt;    (* nombre d ajouts                   *)

{ ------------------------------------------------------------ }
{ InitLitState : initialiser l etat des litteraux et DATA      }
{ ------------------------------------------------------------ }

Procedure InitLitState;
Var I : Integer;
Begin
  LtInitialized := True;
  LtLabelSeq    := 0;
  DataCount     := 0;
  LtLastLabel   := '';
  LtStrCount    := 0;
  LtDWordCount  := 0;
  LtArrayCount  := 0;
  LtTotalBytes  := 0;
  LtFindCount   := 0;
  LtAddCount    := 0;

  (* Initialiser la table DATA a vide *)
  For I := 1 To MAX_DATA_ENTRIES Do
  Begin
    DataTab[I].LblName   := '';
    DataTab[I].Kind      := DK_DWORD;
    DataTab[I].IntVal    := 0;
    DataTab[I].StrVal    := '';
    DataTab[I].ElemCount := 0;
  End;
End;

{ ------------------------------------------------------------ }
{ GenLtLabel : generer un label unique _PL_N                   }
{ ------------------------------------------------------------ }

Function GenLtLabel : TString;
Begin
  Inc(LtLabelSeq);
  LtLastLabel := '_PL_' + ItoS(LtLabelSeq);
  GenLtLabel := LtLastLabel;
End;

{ ------------------------------------------------------------ }
{ GenStrLabel : generer un label pour constante chaine _PK_N   }
{ ------------------------------------------------------------ }

Function GenStrLabel : TString;
Begin
  Inc(LtLabelSeq);
  LtLastLabel := '_PK_' + ItoS(LtLabelSeq);
  GenStrLabel := LtLastLabel;
End;

{ ------------------------------------------------------------ }
{ GenArrayLabel : generer un label pour tableau _PA_N          }
{ ------------------------------------------------------------ }

Function GenArrayLabel : TString;
Begin
  Inc(LtLabelSeq);
  LtLastLabel := '_PA_' + ItoS(LtLabelSeq);
  GenArrayLabel := LtLastLabel;
End;

{ ------------------------------------------------------------ }
{ LtExprKindName : nom textuel d un TExprKind                  }
{ ------------------------------------------------------------ }

Function LtExprKindName(K : Integer) : TString;
Begin
  Case K Of
    EK_NONE : LtExprKindName := 'EK_NONE';
    EK_IMM  : LtExprKindName := 'EK_IMM';
    EK_EAX  : LtExprKindName := 'EK_EAX';
    EK_MEM  : LtExprKindName := 'EK_MEM';
  Else
    LtExprKindName := 'EK_UNKNOWN(' + ItoS(K) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ LtDataKindName : nom textuel d un TDataKind                  }
{ ------------------------------------------------------------ }

Function LtDataKindName(K : Integer) : TString;
Begin
  Case K Of
    DK_DWORD     : LtDataKindName := 'DK_DWORD';
    DK_BYTE      : LtDataKindName := 'DK_BYTE';
    DK_STR       : LtDataKindName := 'DK_STR';
    DK_ARRAY_BLK : LtDataKindName := 'DK_ARRAY_BLK';
  Else
    LtDataKindName := 'DK_UNKNOWN(' + ItoS(K) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ DataAdd : ajouter une entree generique dans DATA             }
{ Retourne l indice de l entree ou -1 si erreur                }
{ ------------------------------------------------------------ }

Function DataAdd(Const LblName : TString; Kind : Integer;
                 IntVal : LongInt; Const StrVal : TString;
                 ElemCount : Integer) : Integer;
Var Idx : Integer;
Begin
  Inc(LtAddCount);

  (* Verifier la limite *)
  If DataCount >= MAX_DATA_ENTRIES Then
  Begin
    WarnMsg('Limite de donnees DATA atteinte (' +
            ItoS(MAX_DATA_ENTRIES) + ')');
    DataAdd := -1;
    Exit;
  End;

  (* Ajouter l entree *)
  Inc(DataCount);
  Idx := DataCount;
  DataTab[Idx].LblName   := LblName;
  DataTab[Idx].Kind      := Kind;
  DataTab[Idx].IntVal    := IntVal;
  DataTab[Idx].StrVal    := StrVal;
  DataTab[Idx].ElemCount := ElemCount;

  (* Mettre a jour les compteurs *)
  Case Kind Of
    DK_DWORD:
    Begin
      Inc(LtDWordCount);
      Inc(LtTotalBytes, 4);
    End;
    DK_BYTE:
      Inc(LtTotalBytes, 1);
    DK_STR:
    Begin
      Inc(LtStrCount);
      Inc(LtTotalBytes, Length(StrVal) + 1);  (* +1 pour $00 *)
    End;
    DK_ARRAY_BLK:
    Begin
      Inc(LtArrayCount);
      Inc(LtTotalBytes, 4 + ElemCount * 4);  (* size + elements *)
    End;
  End;

  DataAdd := Idx;
End;

{ ------------------------------------------------------------ }
{ DataAddStr : ajouter une chaine dans DATA                    }
{ Retourne le label ASM de la chaine                           }
{ ------------------------------------------------------------ }

Function DataAddStr(Const Str : TString) : TString;
Var
  Lbl : TString;
  Idx : Integer;
Begin
  Lbl := GenStrLabel;
  Idx := DataAdd(Lbl, DK_STR, 0, Str, 0);
  If Idx < 0 Then
    DataAddStr := ''
  Else
    DataAddStr := Lbl;
End;

{ ------------------------------------------------------------ }
{ DataAddDWord : ajouter un DWORD dans DATA                    }
{ Retourne le label ASM du DWORD                               }
{ ------------------------------------------------------------ }

Function DataAddDWord(Val : LongInt) : TString;
Var
  Lbl : TString;
  Idx : Integer;
Begin
  Lbl := GenLtLabel;
  Idx := DataAdd(Lbl, DK_DWORD, Val, '', 0);
  If Idx < 0 Then
    DataAddDWord := ''
  Else
    DataAddDWord := Lbl;
End;

{ ------------------------------------------------------------ }
{ DataAddArray : ajouter un bloc de tableau dans DATA          }
{ Retourne le label ASM du tableau                             }
{ ------------------------------------------------------------ }

Function DataAddArray(ElemCount : Integer) : TString;
Var
  Lbl : TString;
  Idx : Integer;
Begin
  Lbl := GenArrayLabel;
  Idx := DataAdd(Lbl, DK_ARRAY_BLK, 0, '', ElemCount);
  If Idx < 0 Then
    DataAddArray := ''
  Else
    DataAddArray := Lbl;
End;

{ ------------------------------------------------------------ }
{ DataFindStr : rechercher une chaine existante dans DATA      }
{ Retourne le label ASM ou '' si non trouvee                   }
{ ------------------------------------------------------------ }

Function DataFindStr(Const Str : TString) : TString;
Var I : Integer;
Begin
  Inc(LtFindCount);
  For I := 1 To DataCount Do
  Begin
    If (DataTab[I].Kind = DK_STR) And (DataTab[I].StrVal = Str) Then
    Begin
      DataFindStr := DataTab[I].LblName;
      Exit;
    End;
  End;
  DataFindStr := '';
End;

{ ------------------------------------------------------------ }
{ DataGetOrAddStr : obtenir ou ajouter une chaine dans DATA    }
{ Retourne le label ASM (reutilise si existante)               }
{ ------------------------------------------------------------ }

Function DataGetOrAddStr(Const Str : TString) : TString;
Var Lbl : TString;
Begin
  Lbl := DataFindStr(Str);
  If Lbl = '' Then
    Lbl := DataAddStr(Str);
  DataGetOrAddStr := Lbl;
End;

{ ------------------------------------------------------------ }
{ ExprMakeImm : creer une expression immediate (constante)     }
{ ------------------------------------------------------------ }

Function ExprMakeImm(Val : LongInt; TypeIdx : Integer) : TExprVal;
Var E : TExprVal;
Begin
  E.Kind    := EK_IMM;
  E.ImmVal  := Val;
  E.TypeIdx := TypeIdx;
  E.Offset  := 0;
  E.SymIdx  := -1;
  ExprMakeImm := E;
End;

{ ------------------------------------------------------------ }
{ ExprMakeNull : creer une expression null (PHP null)          }
{ ------------------------------------------------------------ }

Function ExprMakeNull : TExprVal;
Var E : TExprVal;
Begin
  E.Kind    := EK_IMM;
  E.ImmVal  := 0;
  E.TypeIdx := TY_IDX_NULL;
  E.Offset  := 0;
  E.SymIdx  := -1;
  ExprMakeNull := E;
End;

{ ------------------------------------------------------------ }
{ ExprMakeBool : creer une expression booleenne (true/false)   }
{ ------------------------------------------------------------ }

Function ExprMakeBool(Val : Boolean) : TExprVal;
Var E : TExprVal;
Begin
  E.Kind    := EK_IMM;
  If Val Then
    E.ImmVal := 1
  Else
    E.ImmVal := 0;
  E.TypeIdx := TY_IDX_BOOL;
  E.Offset  := 0;
  E.SymIdx  := -1;
  ExprMakeBool := E;
End;

{ ------------------------------------------------------------ }
{ ExprMakeEAX : creer une expression resultat dans EAX         }
{ ------------------------------------------------------------ }

Function ExprMakeEAX(TypeIdx : Integer) : TExprVal;
Var E : TExprVal;
Begin
  E.Kind    := EK_EAX;
  E.ImmVal  := 0;
  E.TypeIdx := TypeIdx;
  E.Offset  := 0;
  E.SymIdx  := -1;
  ExprMakeEAX := E;
End;

{ ------------------------------------------------------------ }
{ ExprMakeMem : creer une expression reference memoire         }
{ ------------------------------------------------------------ }

Function ExprMakeMem(Offset : Integer; SymIdx : Integer;
                     TypeIdx : Integer) : TExprVal;
Var E : TExprVal;
Begin
  E.Kind    := EK_MEM;
  E.ImmVal  := 0;
  E.TypeIdx := TypeIdx;
  E.Offset  := Offset;
  E.SymIdx  := SymIdx;
  ExprMakeMem := E;
End;

{ ------------------------------------------------------------ }
{ ExprMakeNone : creer une expression invalide/non initialisee }
{ ------------------------------------------------------------ }

Function ExprMakeNone : TExprVal;
Var E : TExprVal;
Begin
  E.Kind    := EK_NONE;
  E.ImmVal  := 0;
  E.TypeIdx := TY_IDX_VOID;
  E.Offset  := 0;
  E.SymIdx  := -1;
  ExprMakeNone := E;
End;

{ ------------------------------------------------------------ }
{ LitEvalInt : evaluer un litteral entier (decimal, hex, etc.) }
{ Retourne la valeur 32 bits signee                            }
{ ------------------------------------------------------------ }

Function LitEvalInt(Const S : TString) : LongInt;
Var
  I, Len : Integer;
  Val    : LongInt;
  Ch     : Char;
  Base   : Integer;
  Neg    : Boolean;
Begin
  Len := Length(S);
  If Len = 0 Then
  Begin
    LitEvalInt := 0;
    Exit;
  End;

  Val := 0;
  I   := 1;
  Neg := False;

  (* Gerer le signe negatif *)
  If S[1] = '-' Then
  Begin
    Neg := True;
    Inc(I);
  End
  Else If S[1] = '+' Then
    Inc(I);

  (* Determiner la base *)
  Base := 10;
  If (I <= Len - 1) And (S[I] = '0') Then
  Begin
    Ch := S[I + 1];
    If (Ch = 'x') Or (Ch = 'X') Then
    Begin
      Base := 16;
      Inc(I, 2);
    End
    Else If (Ch = 'b') Or (Ch = 'B') Then
    Begin
      Base := 2;
      Inc(I, 2);
    End
    Else If (Ch = 'o') Or (Ch = 'O') Then
    Begin
      Base := 8;
      Inc(I, 2);
    End;
  End;

  (* Parser les chiffres *)
  While I <= Len Do
  Begin
    Ch := S[I];
    (* Ignorer le separateur _ *)
    If Ch <> '_' Then
    Begin
      If (Ch >= '0') And (Ch <= '9') Then
        Val := Val * Base + (Ord(Ch) - Ord('0'))
      Else If (Ch >= 'a') And (Ch <= 'f') And (Base = 16) Then
        Val := Val * Base + (Ord(Ch) - Ord('a') + 10)
      Else If (Ch >= 'A') And (Ch <= 'F') And (Base = 16) Then
        Val := Val * Base + (Ord(Ch) - Ord('A') + 10);
    End;
    Inc(I);
  End;

  If Neg Then
    Val := -Val;

  LitEvalInt := Val;
End;

{ ------------------------------------------------------------ }
{ LitEvalStr : evaluer un litteral chaine avec echappements    }
{ Retourne la chaine avec sequences interpretees               }
{ ------------------------------------------------------------ }

Function LitEvalStr(Const S : TString) : TString;
Var
  I, Len : Integer;
  R      : TString;
  Ch     : Char;
  HexVal : Integer;
Begin
  Len := Length(S);
  R   := '';
  I   := 1;

  While I <= Len Do
  Begin
    Ch := S[I];
    If (Ch = '\') And (I < Len) Then
    Begin
      Inc(I);
      Case S[I] Of
        'n' : R := R + #10;
        't' : R := R + #9;
        'r' : R := R + #13;
        '\' : R := R + '\';
        '"' : R := R + '"';
        '''' : R := R + '''';
        '$' : R := R + '$';
        '0' : R := R + #0;
        'x', 'X' :
        Begin
          (* Sequence hexadecimale \xNN *)
          If I + 2 <= Len Then
          Begin
            HexVal := 0;
            Inc(I);
            If (S[I] >= '0') And (S[I] <= '9') Then
              HexVal := (Ord(S[I]) - Ord('0')) * 16
            Else If (S[I] >= 'a') And (S[I] <= 'f') Then
              HexVal := (Ord(S[I]) - Ord('a') + 10) * 16
            Else If (S[I] >= 'A') And (S[I] <= 'F') Then
              HexVal := (Ord(S[I]) - Ord('A') + 10) * 16;
            Inc(I);
            If (S[I] >= '0') And (S[I] <= '9') Then
              HexVal := HexVal + (Ord(S[I]) - Ord('0'))
            Else If (S[I] >= 'a') And (S[I] <= 'f') Then
              HexVal := HexVal + (Ord(S[I]) - Ord('a') + 10)
            Else If (S[I] >= 'A') And (S[I] <= 'F') Then
              HexVal := HexVal + (Ord(S[I]) - Ord('A') + 10);
            R := R + Chr(HexVal And $FF);
          End;
        End;
      Else
        R := R + S[I];  (* sequence inconnue : garder le caractere *)
      End;
    End
    Else
      R := R + Ch;
    Inc(I);
  End;

  LitEvalStr := R;
End;

{ ------------------------------------------------------------ }
{ LitEval : evaluer un litteral (entier ou chaine)             }
{ Retourne TExprVal avec le type et la valeur                  }
{ ------------------------------------------------------------ }

Function LitEval(Kind : Integer; Const S : TString;
                 IntVal : LongInt) : TExprVal;
Var
  E   : TExprVal;
  Lbl : TString;
Begin
  E.Kind   := EK_NONE;
  E.ImmVal := 0;
  E.Offset := 0;
  E.SymIdx := -1;

  Case Kind Of
    TK_INTEGER:
    Begin
      E.Kind    := EK_IMM;
      E.ImmVal  := IntVal;
      E.TypeIdx := TY_IDX_INT;
    End;
    TK_FLOAT:
    Begin
      (* Flottants tronques en entiers *)
      E.Kind    := EK_IMM;
      E.ImmVal  := IntVal;
      E.TypeIdx := TY_IDX_INT;
    End;
    TK_STRING:
    Begin
      (* Chaine : ajouter au segment DATA, retourner ptr *)
      Lbl := DataGetOrAddStr(LitEvalStr(S));
      E.Kind    := EK_MEM;
      E.ImmVal  := 0;
      E.TypeIdx := TY_IDX_STRING;
      (* Offset sera resolu plus tard par l emetteur *)
    End;
  Else
    E.TypeIdx := TY_IDX_VOID;
  End;

  LitEval := E;
End;

{ ------------------------------------------------------------ }
{ ExprIsImm : teste si une expression est immediate            }
{ ------------------------------------------------------------ }

Function ExprIsImm(Const E : TExprVal) : Boolean;
Begin
  ExprIsImm := (E.Kind = EK_IMM);
End;

{ ------------------------------------------------------------ }
{ ExprIsEAX : teste si une expression est dans EAX             }
{ ------------------------------------------------------------ }

Function ExprIsEAX(Const E : TExprVal) : Boolean;
Begin
  ExprIsEAX := (E.Kind = EK_EAX);
End;

{ ------------------------------------------------------------ }
{ ExprIsMem : teste si une expression est en memoire           }
{ ------------------------------------------------------------ }

Function ExprIsMem(Const E : TExprVal) : Boolean;
Begin
  ExprIsMem := (E.Kind = EK_MEM);
End;

{ ------------------------------------------------------------ }
{ DumpLitState : afficher l etat des litteraux et DATA         }
{ ------------------------------------------------------------ }

Procedure DumpLitState;
Var I : Integer;
Begin
  WriteLn('--- Literal State ---');
  WriteLn('  LtInitialized : ', LtInitialized);
  WriteLn('  LtLabelSeq    : ', LtLabelSeq);
  WriteLn('  DataCount     : ', DataCount);
  WriteLn('  LtStrCount    : ', LtStrCount);
  WriteLn('  LtDWordCount  : ', LtDWordCount);
  WriteLn('  LtArrayCount  : ', LtArrayCount);
  WriteLn('  LtTotalBytes  : ', LtTotalBytes);
  WriteLn('  LtFindCount   : ', LtFindCount);
  WriteLn('  LtAddCount    : ', LtAddCount);

  If DataCount > 0 Then
  Begin
    WriteLn('--- DATA Entries ---');
    For I := 1 To DataCount Do
    Begin
      Write('  [', I, '] ', DataTab[I].LblName, ' : ');
      Write(LtDataKindName(DataTab[I].Kind));
      Case DataTab[I].Kind Of
        DK_DWORD:
          Write(' = ', DataTab[I].IntVal);
        DK_STR:
          Write(' = "', DataTab[I].StrVal, '"');
        DK_ARRAY_BLK:
          Write(' [', DataTab[I].ElemCount, ' elements]');
      End;
      WriteLn;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 06)                             }
{ ------------------------------------------------------------ }

Function IsLtInitialized : Boolean;
Begin
  IsLtInitialized := LtInitialized;
End;

Function IsLtEmpty : Boolean;
Begin
  IsLtEmpty := (DataCount = 0);
End;

Function GetDataCount : Integer;
Begin
  GetDataCount := DataCount;
End;

Function GetLtLabelSeq : Integer;
Begin
  GetLtLabelSeq := LtLabelSeq;
End;

Function GetLtStrCount : Integer;
Begin
  GetLtStrCount := LtStrCount;
End;

Function GetLtDWordCount : Integer;
Begin
  GetLtDWordCount := LtDWordCount;
End;

Function GetLtArrayCount : Integer;
Begin
  GetLtArrayCount := LtArrayCount;
End;

Function GetLtTotalBytes : LongInt;
Begin
  GetLtTotalBytes := LtTotalBytes;
End;

Function GetLtLastLabel : TString;
Begin
  GetLtLastLabel := LtLastLabel;
End;

Function GetLtStatus : TString;
Begin
  If Not LtInitialized Then
    GetLtStatus := 'Not initialized'
  Else
    GetLtStatus := ItoS(DataCount) + ' entries, ' +
                   ItoS(LtTotalBytes) + ' bytes';
End;

{ ============================================================ }
{ TODO 07 - OPERATEURS ET PRECEDENCE              [IMPLEMENTE] }
{ ============================================================ }

Const
  (* Operateurs binaires (TBinOp) *)
  OP_NONE       = 0;    (* pas d operateur                       *)
  OP_ADD        = 1;    (* +  addition                           *)
  OP_SUB        = 2;    (* -  soustraction                       *)
  OP_MUL        = 3;    (* *  multiplication                     *)
  OP_DIV        = 4;    (* /  division                           *)
  OP_MOD        = 5;    (* %  modulo                             *)
  OP_POW        = 6;    (* ** puissance                          *)
  OP_CONCAT     = 7;    (* .  concatenation                      *)
  OP_EQ         = 8;    (* == egalite avec juggling              *)
  OP_NE         = 9;    (* != difference avec juggling           *)
  OP_EQQ        = 10;   (* === egalite stricte                   *)
  OP_NEQ        = 11;   (* !== difference stricte                *)
  OP_LT         = 12;   (* <  inferieur                          *)
  OP_LE         = 13;   (* <= inferieur ou egal                  *)
  OP_GT         = 14;   (* >  superieur                          *)
  OP_GE         = 15;   (* >= superieur ou egal                  *)
  OP_SPACESHIP  = 16;   (* <=> comparaison spaceship (-1,0,1)    *)
  OP_AND        = 17;   (* && et logique (court-circuit)         *)
  OP_OR         = 18;   (* || ou logique (court-circuit)         *)
  OP_XOR        = 19;   (* xor ou exclusif logique               *)
  OP_BIT_AND    = 20;   (* &  et bit a bit                       *)
  OP_BIT_OR     = 21;   (* |  ou bit a bit                       *)
  OP_BIT_XOR    = 22;   (* ^  ou exclusif bit a bit              *)
  OP_SHL        = 23;   (* << decalage gauche                    *)
  OP_SHR        = 24;   (* >> decalage droite                    *)
  OP_COALESCE   = 25;   (* ?? null coalescing                    *)

  (* Operateurs unaires (TUnaryOp) *)
  UOP_NONE      = 0;    (* pas d operateur                       *)
  UOP_PLUS      = 1;    (* + unaire (identite)                   *)
  UOP_NEG       = 2;    (* - unaire (negation)                   *)
  UOP_NOT       = 3;    (* ! negation logique                    *)
  UOP_BIT_NOT   = 4;    (* ~ negation bit a bit                  *)
  UOP_PREINC    = 5;    (* ++$x pre-increment                    *)
  UOP_PREDEC    = 6;    (* --$x pre-decrement                    *)
  UOP_POSTINC   = 7;    (* $x++ post-increment                   *)
  UOP_POSTDEC   = 8;    (* $x-- post-decrement                   *)

  (* Operateurs d affectation (TAssignOp) *)
  AOP_ASSIGN    = 0;    (* =   affectation simple                *)
  AOP_ADD       = 1;    (* +=  addition et affectation           *)
  AOP_SUB       = 2;    (* -=  soustraction et affectation       *)
  AOP_MUL       = 3;    (* *=  multiplication et affectation     *)
  AOP_DIV       = 4;    (* /=  division et affectation           *)
  AOP_MOD       = 5;    (* %=  modulo et affectation             *)
  AOP_CONCAT    = 6;    (* .=  concatenation et affectation      *)
  AOP_BIT_AND   = 7;    (* &=  et bit a bit et affectation       *)
  AOP_BIT_OR    = 8;    (* |=  ou bit a bit et affectation       *)
  AOP_BIT_XOR   = 9;    (* ^=  xor bit a bit et affectation      *)
  AOP_SHL       = 10;   (* <<= decalage gauche et affectation    *)
  AOP_SHR       = 11;   (* >>= decalage droite et affectation    *)
  AOP_POW       = 12;   (* **= puissance et affectation          *)

  (* Niveaux de precedence (du plus fort 1 au plus faible 19) *)
  PREC_POSTFIX  = 1;    (* ++ -- postfixe                        *)
  PREC_POW      = 2;    (* ** puissance (associatif a droite)    *)
  PREC_UNARY    = 3;    (* ++ -- prefixe, + - ~ ! unaires        *)
  PREC_MULDIV   = 4;    (* * / %                                 *)
  PREC_ADDSUB   = 5;    (* + - .                                 *)
  PREC_SHIFT    = 6;    (* << >>                                 *)
  PREC_CMP      = 7;    (* < <= > >= <=>                         *)
  PREC_EQUALITY = 8;    (* == != === !==                         *)
  PREC_BIT_AND  = 9;    (* &                                     *)
  PREC_BIT_XOR  = 10;   (* ^                                     *)
  PREC_BIT_OR   = 11;   (* |                                     *)
  PREC_LOG_AND  = 12;   (* &&                                    *)
  PREC_LOG_OR   = 13;   (* ||                                    *)
  PREC_COALESCE = 14;   (* ??                                    *)
  PREC_TERNARY  = 15;   (* ? :                                   *)
  PREC_ASSIGN   = 16;   (* = += -= etc. (associatif a droite)    *)
  PREC_LOG_AND2 = 17;   (* and                                   *)
  PREC_LOG_XOR  = 18;   (* xor                                   *)
  PREC_LOG_OR2  = 19;   (* or                                    *)

  (* Limites *)
  OP_MAX_STACK  = 64;   (* pile pour evaluation d expressions    *)
  OP_MAX_OPS    = 256;  (* nombre max d operations par expr      *)

Var
  OprInitialized : Boolean;   (* True si module initialise         *)
  OprLabelSeq    : Integer;   (* sequence pour labels uniques      *)
  OprLastLabel   : TString;   (* dernier label genere              *)
  OprBinCount    : LongInt;   (* nombre d ops binaires emis        *)
  OprUnaryCount  : LongInt;   (* nombre d ops unaires emis         *)
  OprAssignCount : LongInt;   (* nombre d affectations emises      *)
  OprConcatCount : LongInt;   (* nombre de concatenations          *)
  OprFoldCount   : LongInt;   (* nombre de pliages de constantes   *)
  OprExprCount   : LongInt;   (* nombre d expressions parsees      *)
  OprTernaryCount: LongInt;   (* nombre de ternaires               *)
  OprCoalesceCount:LongInt;   (* nombre de null coalescing         *)

{ ------------------------------------------------------------ }
{ InitOprState : initialiser l etat des operateurs             }
{ ------------------------------------------------------------ }

Procedure InitOprState;
Begin
  OprInitialized := True;
  OprLabelSeq    := 0;
  OprLastLabel   := '';
  OprBinCount    := 0;
  OprUnaryCount  := 0;
  OprAssignCount := 0;
  OprConcatCount := 0;
  OprFoldCount   := 0;
  OprExprCount   := 0;
  OprTernaryCount := 0;
  OprCoalesceCount := 0;
End;

{ ------------------------------------------------------------ }
{ GenOprLabel : generer un label unique _PO_N                  }
{ ------------------------------------------------------------ }

Function GenOprLabel : TString;
Begin
  Inc(OprLabelSeq);
  OprLastLabel := '_PO_' + ItoS(OprLabelSeq);
  GenOprLabel := OprLastLabel;
End;

{ ------------------------------------------------------------ }
{ OpName : nom textuel d un operateur binaire                  }
{ ------------------------------------------------------------ }

Function OpName(Op : Integer) : TString;
Begin
  Case Op Of
    OP_NONE      : OpName := 'NONE';
    OP_ADD       : OpName := '+';
    OP_SUB       : OpName := '-';
    OP_MUL       : OpName := '*';
    OP_DIV       : OpName := '/';
    OP_MOD       : OpName := '%';
    OP_POW       : OpName := '**';
    OP_CONCAT    : OpName := '.';
    OP_EQ        : OpName := '==';
    OP_NE        : OpName := '!=';
    OP_EQQ       : OpName := '===';
    OP_NEQ       : OpName := '!==';
    OP_LT        : OpName := '<';
    OP_LE        : OpName := '<=';
    OP_GT        : OpName := '>';
    OP_GE        : OpName := '>=';
    OP_SPACESHIP : OpName := '<=>';
    OP_AND       : OpName := '&&';
    OP_OR        : OpName := '||';
    OP_XOR       : OpName := 'xor';
    OP_BIT_AND   : OpName := '&';
    OP_BIT_OR    : OpName := '|';
    OP_BIT_XOR   : OpName := '^';
    OP_SHL       : OpName := '<<';
    OP_SHR       : OpName := '>>';
    OP_COALESCE  : OpName := '??';
  Else
    OpName := 'OP_UNKNOWN(' + ItoS(Op) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ UnaryOpName : nom textuel d un operateur unaire              }
{ ------------------------------------------------------------ }

Function UnaryOpName(Op : Integer) : TString;
Begin
  Case Op Of
    UOP_NONE    : UnaryOpName := 'NONE';
    UOP_PLUS    : UnaryOpName := '+';
    UOP_NEG     : UnaryOpName := '-';
    UOP_NOT     : UnaryOpName := '!';
    UOP_BIT_NOT : UnaryOpName := '~';
    UOP_PREINC  : UnaryOpName := '++';
    UOP_PREDEC  : UnaryOpName := '--';
    UOP_POSTINC : UnaryOpName := '++';
    UOP_POSTDEC : UnaryOpName := '--';
  Else
    UnaryOpName := 'UOP_UNKNOWN(' + ItoS(Op) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ AssignOpName : nom textuel d un operateur d affectation      }
{ ------------------------------------------------------------ }

Function AssignOpName(Op : Integer) : TString;
Begin
  Case Op Of
    AOP_ASSIGN  : AssignOpName := '=';
    AOP_ADD     : AssignOpName := '+=';
    AOP_SUB     : AssignOpName := '-=';
    AOP_MUL     : AssignOpName := '*=';
    AOP_DIV     : AssignOpName := '/=';
    AOP_MOD     : AssignOpName := '%=';
    AOP_CONCAT  : AssignOpName := '.=';
    AOP_BIT_AND : AssignOpName := '&=';
    AOP_BIT_OR  : AssignOpName := '|=';
    AOP_BIT_XOR : AssignOpName := '^=';
    AOP_SHL     : AssignOpName := '<<=';
    AOP_SHR     : AssignOpName := '>>=';
    AOP_POW     : AssignOpName := '**=';
  Else
    AssignOpName := 'AOP_UNKNOWN(' + ItoS(Op) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ BinOpPrec : retourner le niveau de precedence d un op binaire}
{ ------------------------------------------------------------ }

Function BinOpPrec(Op : Integer) : Integer;
Begin
  Case Op Of
    OP_POW       : BinOpPrec := PREC_POW;
    OP_MUL,
    OP_DIV,
    OP_MOD       : BinOpPrec := PREC_MULDIV;
    OP_ADD,
    OP_SUB,
    OP_CONCAT    : BinOpPrec := PREC_ADDSUB;
    OP_SHL,
    OP_SHR       : BinOpPrec := PREC_SHIFT;
    OP_LT,
    OP_LE,
    OP_GT,
    OP_GE,
    OP_SPACESHIP : BinOpPrec := PREC_CMP;
    OP_EQ,
    OP_NE,
    OP_EQQ,
    OP_NEQ       : BinOpPrec := PREC_EQUALITY;
    OP_BIT_AND   : BinOpPrec := PREC_BIT_AND;
    OP_BIT_XOR   : BinOpPrec := PREC_BIT_XOR;
    OP_BIT_OR    : BinOpPrec := PREC_BIT_OR;
    OP_AND       : BinOpPrec := PREC_LOG_AND;
    OP_OR        : BinOpPrec := PREC_LOG_OR;
    OP_XOR       : BinOpPrec := PREC_LOG_XOR;
    OP_COALESCE  : BinOpPrec := PREC_COALESCE;
  Else
    BinOpPrec := 0;  (* pas d operateur reconnu *)
  End;
End;

{ ------------------------------------------------------------ }
{ BinOpIsRight : True si l op est associatif a droite          }
{ ------------------------------------------------------------ }

Function BinOpIsRight(Op : Integer) : Boolean;
Begin
  (* En PHP, ** et ?? sont associatifs a droite *)
  BinOpIsRight := (Op = OP_POW) Or (Op = OP_COALESCE);
End;

{ ------------------------------------------------------------ }
{ IsAssignOp : True si le token courant est un op d affectation}
{ ------------------------------------------------------------ }

Function IsAssignOp : Boolean;
Begin
  If CurTokKind <> TK_OP Then
  Begin
    IsAssignOp := False;
    Exit;
  End;

  IsAssignOp := (CurTokStr = '=') Or
                (CurTokStr = '+=') Or (CurTokStr = '-=') Or
                (CurTokStr = '*=') Or (CurTokStr = '/=') Or
                (CurTokStr = '%=') Or (CurTokStr = '.=') Or
                (CurTokStr = '&=') Or (CurTokStr = '|=') Or
                (CurTokStr = '^=') Or (CurTokStr = '<<=') Or
                (CurTokStr = '>>=') Or (CurTokStr = '**=');
End;

{ ------------------------------------------------------------ }
{ TokenToBinOp : convertir le token courant en operateur binaire}
{ ------------------------------------------------------------ }

Function TokenToBinOp : Integer;
Begin
  If CurTokKind = TK_OP Then
  Begin
    If CurTokStr = '+'   Then TokenToBinOp := OP_ADD
    Else If CurTokStr = '-'   Then TokenToBinOp := OP_SUB
    Else If CurTokStr = '*'   Then TokenToBinOp := OP_MUL
    Else If CurTokStr = '/'   Then TokenToBinOp := OP_DIV
    Else If CurTokStr = '%'   Then TokenToBinOp := OP_MOD
    Else If CurTokStr = '**'  Then TokenToBinOp := OP_POW
    Else If CurTokStr = '=='  Then TokenToBinOp := OP_EQ
    Else If CurTokStr = '!='  Then TokenToBinOp := OP_NE
    Else If CurTokStr = '===' Then TokenToBinOp := OP_EQQ
    Else If CurTokStr = '!==' Then TokenToBinOp := OP_NEQ
    Else If CurTokStr = '<'   Then TokenToBinOp := OP_LT
    Else If CurTokStr = '<='  Then TokenToBinOp := OP_LE
    Else If CurTokStr = '>'   Then TokenToBinOp := OP_GT
    Else If CurTokStr = '>='  Then TokenToBinOp := OP_GE
    Else If CurTokStr = '<=>' Then TokenToBinOp := OP_SPACESHIP
    Else If CurTokStr = '&&'  Then TokenToBinOp := OP_AND
    Else If CurTokStr = '||'  Then TokenToBinOp := OP_OR
    Else If CurTokStr = '&'   Then TokenToBinOp := OP_BIT_AND
    Else If CurTokStr = '|'   Then TokenToBinOp := OP_BIT_OR
    Else If CurTokStr = '^'   Then TokenToBinOp := OP_BIT_XOR
    Else If CurTokStr = '<<'  Then TokenToBinOp := OP_SHL
    Else If CurTokStr = '>>'  Then TokenToBinOp := OP_SHR
    Else If CurTokStr = '??'  Then TokenToBinOp := OP_COALESCE
    Else TokenToBinOp := OP_NONE;
  End
  Else If CurTokKind = TK_CONCAT Then
    TokenToBinOp := OP_CONCAT
  Else If (CurTokKind = TK_KEYWORD) And (CurTokStr = 'xor') Then
    TokenToBinOp := OP_XOR
  Else If (CurTokKind = TK_KEYWORD) And (CurTokStr = 'and') Then
    TokenToBinOp := OP_AND
  Else If (CurTokKind = TK_KEYWORD) And (CurTokStr = 'or') Then
    TokenToBinOp := OP_OR
  Else
    TokenToBinOp := OP_NONE;
End;

{ ------------------------------------------------------------ }
{ TokenToUnaryOp : convertir le token courant en op unaire     }
{ ------------------------------------------------------------ }

Function TokenToUnaryOp : Integer;
Begin
  If CurTokKind = TK_OP Then
  Begin
    If CurTokStr = '+'  Then TokenToUnaryOp := UOP_PLUS
    Else If CurTokStr = '-'  Then TokenToUnaryOp := UOP_NEG
    Else If CurTokStr = '!'  Then TokenToUnaryOp := UOP_NOT
    Else If CurTokStr = '~'  Then TokenToUnaryOp := UOP_BIT_NOT
    Else If CurTokStr = '++' Then TokenToUnaryOp := UOP_PREINC
    Else If CurTokStr = '--' Then TokenToUnaryOp := UOP_PREDEC
    Else TokenToUnaryOp := UOP_NONE;
  End
  Else
    TokenToUnaryOp := UOP_NONE;
End;

{ ------------------------------------------------------------ }
{ TokenToAssignOp : convertir le token courant en op affectation}
{ ------------------------------------------------------------ }

Function TokenToAssignOp : Integer;
Begin
  If CurTokKind = TK_OP Then
  Begin
    If CurTokStr = '='   Then TokenToAssignOp := AOP_ASSIGN
    Else If CurTokStr = '+='  Then TokenToAssignOp := AOP_ADD
    Else If CurTokStr = '-='  Then TokenToAssignOp := AOP_SUB
    Else If CurTokStr = '*='  Then TokenToAssignOp := AOP_MUL
    Else If CurTokStr = '/='  Then TokenToAssignOp := AOP_DIV
    Else If CurTokStr = '%='  Then TokenToAssignOp := AOP_MOD
    Else If CurTokStr = '.='  Then TokenToAssignOp := AOP_CONCAT
    Else If CurTokStr = '&='  Then TokenToAssignOp := AOP_BIT_AND
    Else If CurTokStr = '|='  Then TokenToAssignOp := AOP_BIT_OR
    Else If CurTokStr = '^='  Then TokenToAssignOp := AOP_BIT_XOR
    Else If CurTokStr = '<<=' Then TokenToAssignOp := AOP_SHL
    Else If CurTokStr = '>>=' Then TokenToAssignOp := AOP_SHR
    Else If CurTokStr = '**=' Then TokenToAssignOp := AOP_POW
    Else TokenToAssignOp := -1;
  End
  Else
    TokenToAssignOp := -1;
End;

{ ------------------------------------------------------------ }
{ AssignOpToBinOp : convertir un op d affectation en op binaire}
{ ------------------------------------------------------------ }

Function AssignOpToBinOp(Aop : Integer) : Integer;
Begin
  Case Aop Of
    AOP_ADD     : AssignOpToBinOp := OP_ADD;
    AOP_SUB     : AssignOpToBinOp := OP_SUB;
    AOP_MUL     : AssignOpToBinOp := OP_MUL;
    AOP_DIV     : AssignOpToBinOp := OP_DIV;
    AOP_MOD     : AssignOpToBinOp := OP_MOD;
    AOP_CONCAT  : AssignOpToBinOp := OP_CONCAT;
    AOP_BIT_AND : AssignOpToBinOp := OP_BIT_AND;
    AOP_BIT_OR  : AssignOpToBinOp := OP_BIT_OR;
    AOP_BIT_XOR : AssignOpToBinOp := OP_BIT_XOR;
    AOP_SHL     : AssignOpToBinOp := OP_SHL;
    AOP_SHR     : AssignOpToBinOp := OP_SHR;
    AOP_POW     : AssignOpToBinOp := OP_POW;
  Else
    AssignOpToBinOp := OP_NONE;  (* = simple, pas d op binaire *)
  End;
End;

{ ------------------------------------------------------------ }
{ ConstFoldBinOp : pliage de constantes pour op binaire        }
{ Retourne True si le pliage est possible                      }
{ ------------------------------------------------------------ }

Function ConstFoldBinOp(Left, Right : LongInt; Op : Integer;
                        Var Result : LongInt) : Boolean;
Begin
  ConstFoldBinOp := True;
  Inc(OprFoldCount);

  Case Op Of
    OP_ADD:
      Result := Left + Right;
    OP_SUB:
      Result := Left - Right;
    OP_MUL:
      Result := Left * Right;
    OP_DIV:
    Begin
      If Right = 0 Then
      Begin
        WarnMsg('Division par zero');
        Result := 0;
        ConstFoldBinOp := False;
      End
      Else
        Result := Left Div Right;
    End;
    OP_MOD:
    Begin
      If Right = 0 Then
      Begin
        WarnMsg('Modulo par zero');
        Result := 0;
        ConstFoldBinOp := False;
      End
      Else
        Result := Left Mod Right;
    End;
    OP_POW:
    Begin
      (* Puissance simple pour entiers positifs *)
      If Right < 0 Then
      Begin
        Result := 0;
        ConstFoldBinOp := False;
      End
      Else If Right = 0 Then
        Result := 1
      Else
      Begin
        Result := 1;
        While Right > 0 Do
        Begin
          Result := Result * Left;
          Dec(Right);
        End;
      End;
    End;
    OP_EQ, OP_EQQ:
      If Left = Right Then Result := 1 Else Result := 0;
    OP_NE, OP_NEQ:
      If Left <> Right Then Result := 1 Else Result := 0;
    OP_LT:
      If Left < Right Then Result := 1 Else Result := 0;
    OP_LE:
      If Left <= Right Then Result := 1 Else Result := 0;
    OP_GT:
      If Left > Right Then Result := 1 Else Result := 0;
    OP_GE:
      If Left >= Right Then Result := 1 Else Result := 0;
    OP_SPACESHIP:
    Begin
      If Left < Right Then Result := -1
      Else If Left > Right Then Result := 1
      Else Result := 0;
    End;
    OP_AND:
      If (Left <> 0) And (Right <> 0) Then Result := 1 Else Result := 0;
    OP_OR:
      If (Left <> 0) Or (Right <> 0) Then Result := 1 Else Result := 0;
    OP_XOR:
      If ((Left <> 0) And (Right = 0)) Or
         ((Left = 0) And (Right <> 0)) Then Result := 1
      Else Result := 0;
    OP_BIT_AND:
      Result := Left And Right;
    OP_BIT_OR:
      Result := Left Or Right;
    OP_BIT_XOR:
      Result := Left Xor Right;
    OP_SHL:
      Result := Left Shl (Right And $1F);
    OP_SHR:
      Result := Left Shr (Right And $1F);
  Else
    ConstFoldBinOp := False;
    Dec(OprFoldCount);
  End;
End;

{ ------------------------------------------------------------ }
{ ConstFoldUnaryOp : pliage de constantes pour op unaire       }
{ Retourne True si le pliage est possible                      }
{ ------------------------------------------------------------ }

Function ConstFoldUnaryOp(Val : LongInt; Op : Integer;
                          Var Result : LongInt) : Boolean;
Begin
  ConstFoldUnaryOp := True;
  Inc(OprFoldCount);

  Case Op Of
    UOP_PLUS:
      Result := Val;
    UOP_NEG:
      Result := -Val;
    UOP_NOT:
      If Val = 0 Then Result := 1 Else Result := 0;
    UOP_BIT_NOT:
      Result := Not Val;
  Else
    ConstFoldUnaryOp := False;
    Dec(OprFoldCount);
  End;
End;

{ ------------------------------------------------------------ }
{ ExprFlushToEAX : materialiser le resultat d expr dans EAX    }
{ Si l expression est deja dans EAX, ne rien faire             }
{ Si c est une valeur immediate, generer MOV EAX, imm          }
{ Si c est en memoire, generer MOV EAX, [mem]                  }
{ ------------------------------------------------------------ }

Procedure ExprFlushToEAX(Const E : TExprVal);
Begin
  Case E.Kind Of
    EK_IMM:
      OutLn('        MOV     EAX, ' + ItoS(E.ImmVal));
    EK_EAX:
      (* deja dans EAX, rien a faire *);
    EK_MEM:
      OutLn('        MOV     EAX, [' + ItoS(E.Offset) + ']');
  End;
End;

{ ------------------------------------------------------------ }
{ ExprEmitBinOp : generer le code pour un operateur binaire    }
{ Left est dans EAX, Right est pousse sur la pile ou immediate }
{ Resultat dans EAX                                            }
{ ------------------------------------------------------------ }

Procedure ExprEmitBinOp(Op : Integer; RightImm : Boolean;
                        RightVal : LongInt);
Var
  Lbl1, Lbl2 : TString;
Begin
  Inc(OprBinCount);

  Case Op Of
    OP_ADD:
    Begin
      If RightImm Then
        OutLn('        ADD     EAX, ' + ItoS(RightVal))
      Else
      Begin
        OutLn('        POP     EBX');
        OutLn('        ADD     EAX, EBX');
      End;
    End;
    OP_SUB:
    Begin
      If RightImm Then
        OutLn('        SUB     EAX, ' + ItoS(RightVal))
      Else
      Begin
        OutLn('        POP     EBX');
        OutLn('        SUB     EBX, EAX');
        OutLn('        MOV     EAX, EBX');
      End;
    End;
    OP_MUL:
    Begin
      If RightImm Then
        OutLn('        IMUL    EAX, ' + ItoS(RightVal))
      Else
      Begin
        OutLn('        POP     EBX');
        OutLn('        IMUL    EAX, EBX');
      End;
    End;
    OP_DIV:
    Begin
      OutLn('        MOV     ECX, EAX');
      If RightImm Then
        OutLn('        MOV     EAX, ' + ItoS(RightVal))
      Else
        OutLn('        POP     EAX');
      OutLn('        CDQ');
      OutLn('        IDIV    ECX');
    End;
    OP_MOD:
    Begin
      OutLn('        MOV     ECX, EAX');
      If RightImm Then
        OutLn('        MOV     EAX, ' + ItoS(RightVal))
      Else
        OutLn('        POP     EAX');
      OutLn('        CDQ');
      OutLn('        IDIV    ECX');
      OutLn('        MOV     EAX, EDX');
    End;
    OP_EQ, OP_EQQ:
    Begin
      If RightImm Then
        OutLn('        CMP     EAX, ' + ItoS(RightVal))
      Else
      Begin
        OutLn('        POP     EBX');
        OutLn('        CMP     EBX, EAX');
      End;
      OutLn('        SETE    AL');
      OutLn('        MOVZX   EAX, AL');
    End;
    OP_NE, OP_NEQ:
    Begin
      If RightImm Then
        OutLn('        CMP     EAX, ' + ItoS(RightVal))
      Else
      Begin
        OutLn('        POP     EBX');
        OutLn('        CMP     EBX, EAX');
      End;
      OutLn('        SETNE   AL');
      OutLn('        MOVZX   EAX, AL');
    End;
    OP_LT:
    Begin
      If RightImm Then
        OutLn('        CMP     EAX, ' + ItoS(RightVal))
      Else
      Begin
        OutLn('        POP     EBX');
        OutLn('        CMP     EBX, EAX');
      End;
      OutLn('        SETL    AL');
      OutLn('        MOVZX   EAX, AL');
    End;
    OP_LE:
    Begin
      If RightImm Then
        OutLn('        CMP     EAX, ' + ItoS(RightVal))
      Else
      Begin
        OutLn('        POP     EBX');
        OutLn('        CMP     EBX, EAX');
      End;
      OutLn('        SETLE   AL');
      OutLn('        MOVZX   EAX, AL');
    End;
    OP_GT:
    Begin
      If RightImm Then
        OutLn('        CMP     EAX, ' + ItoS(RightVal))
      Else
      Begin
        OutLn('        POP     EBX');
        OutLn('        CMP     EBX, EAX');
      End;
      OutLn('        SETG    AL');
      OutLn('        MOVZX   EAX, AL');
    End;
    OP_GE:
    Begin
      If RightImm Then
        OutLn('        CMP     EAX, ' + ItoS(RightVal))
      Else
      Begin
        OutLn('        POP     EBX');
        OutLn('        CMP     EBX, EAX');
      End;
      OutLn('        SETGE   AL');
      OutLn('        MOVZX   EAX, AL');
    End;
    OP_SPACESHIP:
    Begin
      (* Comparaison spaceship: -1, 0, ou 1 *)
      Lbl1 := GenOprLabel;
      Lbl2 := GenOprLabel;
      If RightImm Then
        OutLn('        CMP     EAX, ' + ItoS(RightVal))
      Else
      Begin
        OutLn('        POP     EBX');
        OutLn('        CMP     EBX, EAX');
      End;
      OutLn('        JL      ' + Lbl1);
      OutLn('        JG      ' + Lbl2);
      OutLn('        XOR     EAX, EAX');
      OutLn('        JMP     SHORT @end_cmp');
      OutLn(Lbl1 + ':');
      OutLn('        MOV     EAX, -1');
      OutLn('        JMP     SHORT @end_cmp');
      OutLn(Lbl2 + ':');
      OutLn('        MOV     EAX, 1');
      OutLn('@end_cmp:');
    End;
    OP_AND:
    Begin
      (* && avec court-circuit deja gere au parsing *)
      OutLn('        TEST    EAX, EAX');
      OutLn('        SETNE   AL');
      OutLn('        MOVZX   EAX, AL');
    End;
    OP_OR:
    Begin
      (* || avec court-circuit deja gere au parsing *)
      OutLn('        TEST    EAX, EAX');
      OutLn('        SETNE   AL');
      OutLn('        MOVZX   EAX, AL');
    End;
    OP_BIT_AND:
    Begin
      If RightImm Then
        OutLn('        AND     EAX, ' + ItoS(RightVal))
      Else
      Begin
        OutLn('        POP     EBX');
        OutLn('        AND     EAX, EBX');
      End;
    End;
    OP_BIT_OR:
    Begin
      If RightImm Then
        OutLn('        OR      EAX, ' + ItoS(RightVal))
      Else
      Begin
        OutLn('        POP     EBX');
        OutLn('        OR      EAX, EBX');
      End;
    End;
    OP_BIT_XOR:
    Begin
      If RightImm Then
        OutLn('        XOR     EAX, ' + ItoS(RightVal))
      Else
      Begin
        OutLn('        POP     EBX');
        OutLn('        XOR     EAX, EBX');
      End;
    End;
    OP_SHL:
    Begin
      OutLn('        MOV     ECX, EAX');
      If RightImm Then
        OutLn('        MOV     EAX, ' + ItoS(RightVal))
      Else
        OutLn('        POP     EAX');
      OutLn('        SHL     EAX, CL');
    End;
    OP_SHR:
    Begin
      OutLn('        MOV     ECX, EAX');
      If RightImm Then
        OutLn('        MOV     EAX, ' + ItoS(RightVal))
      Else
        OutLn('        POP     EAX');
      OutLn('        SAR     EAX, CL');
    End;
    OP_CONCAT:
    Begin
      Inc(OprConcatCount);
      (* Concatenation de chaines : appel runtime *)
      OutLn('        PUSH    EAX');
      If RightImm Then
        OutLn('        PUSH    ' + ItoS(RightVal))
      Else
        OutLn('        ; droite deja sur pile');
      OutLn('        CALL    _PHRT_concat');
      OutLn('        ADD     ESP, 8');
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ ExprEmitUnaryOp : generer le code pour un operateur unaire   }
{ Operande dans EAX, resultat dans EAX                         }
{ ------------------------------------------------------------ }

Procedure ExprEmitUnaryOp(Op : Integer);
Begin
  Inc(OprUnaryCount);

  Case Op Of
    UOP_PLUS:
      (* rien a faire, identite *);
    UOP_NEG:
      OutLn('        NEG     EAX');
    UOP_NOT:
    Begin
      OutLn('        TEST    EAX, EAX');
      OutLn('        SETE    AL');
      OutLn('        MOVZX   EAX, AL');
    End;
    UOP_BIT_NOT:
      OutLn('        NOT     EAX');
    UOP_PREINC:
      OutLn('        INC     EAX');
    UOP_PREDEC:
      OutLn('        DEC     EAX');
    UOP_POSTINC:
      (* l ancienne valeur est deja dans EAX, on incremente la source apres *)
      OutLn('        ; post-increment');
    UOP_POSTDEC:
      (* l ancienne valeur est deja dans EAX, on decremente la source apres *)
      OutLn('        ; post-decrement');
  End;
End;

{ ------------------------------------------------------------ }
{ ParsePrimary : parser une expression primaire                }
{ ------------------------------------------------------------ }

(* Declaration forward pour recursion mutuelle *)
Function ParseExpr : TExprVal; Forward;

Function ParsePrimary : TExprVal;
Var
  E : TExprVal;
Begin
  E.Kind    := EK_NONE;
  E.ImmVal  := 0;
  E.TypeIdx := TY_IDX_VOID;
  E.Offset  := 0;
  E.SymIdx  := -1;

  Case CurTokKind Of
    TK_INTEGER:
    Begin
      E := ExprMakeImm(CurTokInt, TY_IDX_INT);
      LexNextToken;
    End;
    TK_FLOAT:
    Begin
      (* Flottants tronques en entiers *)
      E := ExprMakeImm(CurTokInt, TY_IDX_INT);
      LexNextToken;
    End;
    TK_STRING:
    Begin
      (* Chaine : ajouter au segment DATA *)
      E.Kind    := EK_MEM;
      E.TypeIdx := TY_IDX_STRING;
      LexNextToken;
    End;
    TK_KEYWORD:
    Begin
      If CurTokStr = 'null' Then
      Begin
        E := ExprMakeNull;
        LexNextToken;
      End
      Else If CurTokStr = 'true' Then
      Begin
        E := ExprMakeBool(True);
        LexNextToken;
      End
      Else If CurTokStr = 'false' Then
      Begin
        E := ExprMakeBool(False);
        LexNextToken;
      End
      Else
        CompileError('Expression attendue, mot-cle ' + CurTokStr +
                     ' inattendu', LexLineNo);
    End;
    TK_VARIABLE:
    Begin
      (* Variable $nom : reference memoire *)
      E.Kind    := EK_MEM;
      E.TypeIdx := TY_IDX_MIXED;
      LexNextToken;
    End;
    TK_IDENT:
    Begin
      (* Constante ou appel de fonction *)
      E.Kind    := EK_MEM;
      E.TypeIdx := TY_IDX_MIXED;
      LexNextToken;
    End;
    TK_LPAREN:
    Begin
      LexNextToken;
      E := ParseExpr;
      If CurTokKind <> TK_RPAREN Then
        CompileError(') attendu', LexLineNo);
      LexNextToken;
    End;
  Else
    CompileError('Expression attendue', LexLineNo);
  End;

  Inc(OprExprCount);
  ParsePrimary := E;
End;

{ ------------------------------------------------------------ }
{ ParseUnary : parser un operateur unaire                      }
{ ------------------------------------------------------------ }

Function ParseUnary : TExprVal;
Var
  Op    : Integer;
  E     : TExprVal;
  Res   : LongInt;
Begin
  Op := TokenToUnaryOp;
  If Op <> UOP_NONE Then
  Begin
    LexNextToken;
    E := ParseUnary;  (* recursif pour - - x etc. *)

    (* Pliage de constante si possible *)
    If E.Kind = EK_IMM Then
    Begin
      If ConstFoldUnaryOp(E.ImmVal, Op, Res) Then
      Begin
        E.ImmVal := Res;
        ParseUnary := E;
        Exit;
      End;
    End;

    (* Generer le code *)
    ExprFlushToEAX(E);
    ExprEmitUnaryOp(Op);
    ParseUnary := ExprMakeEAX(E.TypeIdx);
  End
  Else
    ParseUnary := ParsePrimary;
End;

{ ------------------------------------------------------------ }
{ ParseExprPrec : parser une expression avec precedence        }
{ Utilise l algorithme de Pratt / precedence climbing          }
{ ------------------------------------------------------------ }

Function ParseExprPrec(MinPrec : Integer) : TExprVal;
Var
  Left, Right : TExprVal;
  Op, Prec    : Integer;
  IsRight     : Boolean;
  Res         : LongInt;
Begin
  Left := ParseUnary;

  While True Do
  Begin
    Op := TokenToBinOp;
    If Op = OP_NONE Then
      Break;

    Prec := BinOpPrec(Op);
    If Prec = 0 Then
      Break;
    If Prec > MinPrec Then
      Break;

    IsRight := BinOpIsRight(Op);
    LexNextToken;

    (* Pour les ops associatifs a droite, on utilise la meme precedence *)
    If IsRight Then
      Right := ParseExprPrec(Prec)
    Else
      Right := ParseExprPrec(Prec - 1);

    (* Pliage de constantes si les deux operandes sont immediates *)
    If (Left.Kind = EK_IMM) And (Right.Kind = EK_IMM) Then
    Begin
      If ConstFoldBinOp(Left.ImmVal, Right.ImmVal, Op, Res) Then
      Begin
        Left.ImmVal := Res;
        Continue;
      End;
    End;

    (* Generer le code *)
    If Right.Kind = EK_IMM Then
    Begin
      ExprFlushToEAX(Left);
      ExprEmitBinOp(Op, True, Right.ImmVal);
    End
    Else
    Begin
      ExprFlushToEAX(Left);
      OutLn('        PUSH    EAX');
      ExprFlushToEAX(Right);
      ExprEmitBinOp(Op, False, 0);
    End;

    Left := ExprMakeEAX(TY_IDX_INT);
  End;

  ParseExprPrec := Left;
End;

{ ------------------------------------------------------------ }
{ ParseExpr : parser une expression complete                   }
{ ------------------------------------------------------------ }

Function ParseExpr : TExprVal;
Begin
  Inc(OprExprCount);
  ParseExpr := ParseExprPrec(PREC_LOG_OR2);
End;

{ ------------------------------------------------------------ }
{ DumpOprState : afficher l etat des operateurs                }
{ ------------------------------------------------------------ }

Procedure DumpOprState;
Begin
  WriteLn('--- Operator State ---');
  WriteLn('  OprInitialized  : ', OprInitialized);
  WriteLn('  OprLabelSeq     : ', OprLabelSeq);
  WriteLn('  OprBinCount     : ', OprBinCount);
  WriteLn('  OprUnaryCount   : ', OprUnaryCount);
  WriteLn('  OprAssignCount  : ', OprAssignCount);
  WriteLn('  OprConcatCount  : ', OprConcatCount);
  WriteLn('  OprFoldCount    : ', OprFoldCount);
  WriteLn('  OprExprCount    : ', OprExprCount);
  WriteLn('  OprTernaryCount : ', OprTernaryCount);
  WriteLn('  OprCoalesceCount: ', OprCoalesceCount);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 07)                            }
{ ------------------------------------------------------------ }

Function IsOprInitialized : Boolean;
Begin
  IsOprInitialized := OprInitialized;
End;

Function IsOprEmpty : Boolean;
Begin
  IsOprEmpty := (OprBinCount = 0) And (OprUnaryCount = 0);
End;

Function GetOprBinCount : LongInt;
Begin
  GetOprBinCount := OprBinCount;
End;

Function GetOprUnaryCount : LongInt;
Begin
  GetOprUnaryCount := OprUnaryCount;
End;

Function GetOprAssignCount : LongInt;
Begin
  GetOprAssignCount := OprAssignCount;
End;

Function GetOprConcatCount : LongInt;
Begin
  GetOprConcatCount := OprConcatCount;
End;

Function GetOprFoldCount : LongInt;
Begin
  GetOprFoldCount := OprFoldCount;
End;

Function GetOprExprCount : LongInt;
Begin
  GetOprExprCount := OprExprCount;
End;

Function GetOprLastLabel : TString;
Begin
  GetOprLastLabel := OprLastLabel;
End;

Function GetOprStatus : TString;
Begin
  If Not OprInitialized Then
    GetOprStatus := 'Not initialized'
  Else
    GetOprStatus := ItoS(OprBinCount) + ' bin, ' +
                    ItoS(OprUnaryCount) + ' unary, ' +
                    ItoS(OprFoldCount) + ' folded';
End;

{ ============================================================ }
{ Programme principal                                          }
{ ============================================================ }

Begin
  { Initialiser les compteurs }
  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  OutFOpen   := False;
  BcActive   := False;

  { Initialiser les messages de sortie }
  InitOutMsgs;

  { Initialiser la reconnaissance des mots-cles }
  InitKwState;

  { Initialiser la table des symboles }
  InitSymState;

  { Initialiser le systeme de types }
  InitTypeState;

  { Initialiser les litteraux et le segment DATA }
  InitLitState;

  { Initialiser les operateurs }
  InitOprState;

  { Analyser les arguments }
  ParseArgs;

  { Afficher la banniere si mode verbeux }
  ShowBanner;

  { Initialiser le lexer et lire le fichier source }
  LexInit;

  { Tokeniser tout le fichier pour test }
  If Opts.Verbose Then
    WriteLn('PHPCW32: Tokenisation de ', Opts.SrcFile, ' ...');

  { Lire le premier token }
  LexNextToken;

  { Parcourir tous les tokens }
  While CurTokKind <> TK_EOF Do
    LexNextToken;

  { Fermer le lexer }
  LexClose;

  { Message de succes }
  If Opts.Verbose Then
  Begin
    WriteLn('PHPCW32: Tokenisation terminee');
    WriteLn('PHPCW32: ', LexTokCount, ' tokens lus');
    WriteLn('PHPCW32: ', KwHitCount, ' mots-cles reconnus');
  End;

  WriteLn('PHPCW32: TODO 01-07 implementes');
  WriteLn('PHPCW32: Les TODOs 08-25 restent a implementer');

  { Afficher les statistiques si mode verbeux }
  ShowStats;

  { Nettoyage }
  Cleanup;

  { Code de sortie }
  If ErrorCount > 0 Then
    Halt(EXIT_ERROR)
  Else
    Halt(EXIT_OK);
End.
