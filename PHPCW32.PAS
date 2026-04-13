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

  TODO 05 - SYSTEME DE TYPES PHP [A FAIRE]
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

  TODO 06 - LITTERAUX ET CONSTANTES [A FAIRE]
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

  TODO 07 - OPERATEURS ET PRECEDENCE [A FAIRE]
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

  WriteLn('PHPCW32: TODO 01-04 implementes');
  WriteLn('PHPCW32: Les TODOs 05-25 restent a implementer');

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
