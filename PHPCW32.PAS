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

  TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES PE/COFF [A FAIRE]
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

  TODO 02 - TOKENISEUR PHP (LEXER) [A FAIRE]
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

  TODO 03 - RECONNAISSANCE DES MOTS-CLES PHP [A FAIRE]
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

  TODO 04 - TABLE DES SYMBOLES PHP (32 BITS) [A FAIRE]
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

Begin
  WriteLn('PHPCW32 - Compilateur PHP vers Windows 32 bits');
  WriteLn('Version 0.1 - En cours de developpement');
  WriteLn('Voir les TODOs dans le fichier source pour la feuille de route.');
End.
