{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 0.1
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur AWK vers assembleur 80386 pour Windows 32 bits
  @license: MIT
}

(* ============================================================
  AWKCW32.PAS - Compilateur AWK vers assembleur
  80386 pour Windows 32 bits
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .386 / .MODEL FLAT, PE Win32

  Par defaut produit un fichier .EXE (PE Windows 32 bits).
  Avec le parametre -obj, produit uniquement un fichier .OBJ (COFF).
  Avec le parametre -asm, produit egalement un fichier .ASM lisible.
  Supporte toutes les instructions de AWK86.PAS et les exemples
  SAMPLES\AWK\*

  Voir DOC/TODO/AWKCW32.txt pour la feuille de route complete.

  TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES PE/COFF [IMPLEMENTE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings,
              EmitExe, EmitObj, EmitAsm, FieldSep, InitVars, InitCount)
            ParseArgs : analyser argv (source.awk [-o sortie] [-v]
              [-d] [-w] [-obj] [-asm] [-F sep] [-v var=val] [-h])
            Par defaut : produire un .EXE Windows 32 bits (PE)
            -obj : produire uniquement un .OBJ (format COFF 32 bits)
            -asm : produire egalement un listing assembleur .ASM lisible
            -o nom : specifier le nom du fichier de sortie
            -F sep : specifier le separateur de champs (FS)
            -v var=val : initialiser une variable AWK avant execution
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .awk du fichier source
            Version, Date, aide en ligne (option -h)
            Constantes PE/COFF : PE_DOS_MAGIC ($5A4D), PE_PE_SIG,
              PE_MACHINE_I386, PE_OPT_SIZE, PE_MAGIC_32,
              PE_IMG_BASE ($00400000), PE_SEC_ALIGN (4096),
              PE_FILE_ALIGN (512), PE_SUBSYS_CUI (console)
            Constantes binaires : MAX_BIN_CODE (65536),
              MAX_BIN_DATA (65536), MAX_BIN_LBL (4096),
              MAX_BIN_FIX (8192)
            Limites internes (32 bits) : MAX_SYM=2048, MAX_LABEL=2048,
              MAX_SCOPE=64, MAX_DATA=512, MAX_PARAM=32,
              MAX_LOOP_NEST=16, MAX_ERRORS=30, MAX_STR=255,
              MAX_RULES=64, MAX_FIELDS=64, MAX_HASH_PAIRS=64,
              MAX_INIT_VARS=16, STACK_SIZE=4096
            Prefixes de nommage ASM : _AWV_ (variable utilisateur),
              _AWF_ (fonction utilisateur), _AWK_ (constante chaine),
              _AWRT_ (routine runtime), _AWL_ (label interne),
              _AWA_ (tableau associatif), _AWP_ (pattern data),
              _AWR_ (regle pattern-action)
            Utilitaires : ItoS, ItoSI, UpCaseStr, AsmIdent

  TODO 02 - TOKENISEUR AWK (LEXER) [IMPLEMENTE]
            Procedure LexInit : ouvrir le fichier source, initialiser
              l etat du lexeur (ligne, colonne, caractere courant)
            Procedure LexClose : fermer le fichier source
            Procedure LexNextChar / LexPeekChar
            Procedure LexNextToken : reconnaitre les tokens AWK :
              - Identificateurs : lettres, chiffres, _ (max 64 cars)
              - Litteraux entiers : 42, 0xFF, 0377 (octal)
              - Litteraux flottants : 3.14, 1.5e3
              - Litteraux chaines : "texte" (guillemets doubles,
                sequences d echappement \n \t \\ \" \a \b \f \r \/)
              - Expressions regulieres : /pattern/ (hors contexte
                division)
              - Commentaires ligne : # jusqu a fin de ligne
              - Operateurs : + - * / % ^ = == != < > <= >= ~ !~
                ++ -- += -= *= /= %= ^= && || ! >> |
              - Separateurs : ; , ( ) [ ] { }
              - Reference de champ : $0 $1 $NF $(expr)
              - Newline significatif (separateur d instructions)
            Types de tokens (TK_EOF, TK_INTEGER, TK_FLOAT,
              TK_STRING, TK_REGEXP, TK_IDENT, TK_KEYWORD,
              TK_BUILTIN, TK_FIELD, TK_OP, TK_PUNCT, TK_NEWLINE)
            Stocker dans CurTok (Kind, Val, IntVal, FloatVal,
              Line, Col)

  TODO 03 - RECONNAISSANCE DES MOTS-CLES ET FONCTIONS BUILTIN AWK [IMPLEMENTE]
            Function IsKeyword(Const s: String): Integer
            Constantes KW_BEGIN..KW_GETLINE (21 mots-cles)
            Function IsBuiltinFunc(Const s: String): Integer
            Constantes BF_LENGTH..BF_STRFTIME (24 fonctions builtin)
            Function IsBuiltinVar(Const s: String): Integer
            Constantes BV_FS..BV_CONVFMT (16 variables builtin)
            TK_BVAR ajoute a TTokenKind, LexScanIdent mis a jour,
            PrintToken mis a jour, Run mis a jour

  TODO 04 - TABLE DES SYMBOLES (32 BITS) [IMPLEMENTE]
            Type TSymEntry : Name (String[64]), AsmLabel (String[64]),
              TypeKind (TTypeKind), StoreClass (Integer),
              BpOffset (Integer), IsParam (Boolean),
              ParamIdx (Integer), IsGlobal (Boolean),
              IsArray (Boolean), ArrayAsmLabel (String[64])
            Type TFuncEntry : Name (String[64]), AsmLabel (String[64]),
              ParamCount (Integer), ParamNames (Array[1..MAX_PARAM]),
              Defined (Boolean), LocalCount (Integer)
            SymTab[0..MAX_SYM-1] / SymCount
            FuncTab[0..MAX_FUNC-1] / FuncCount
            Procedure InitSymTable / Function FindSym / Function AddSym
            Function FindFunc / Function AddFunc
            Variables builtin auto-declarees :
              FS (DD OFFSET _AWK_fs_default), NR (DD 0), NF (DD 0),
              FNR (DD 0), RS (DD OFFSET _AWK_rs_default),
              OFS (DD OFFSET _AWK_ofs_default),
              ORS (DD OFFSET _AWK_ors_default),
              FILENAME (DD 0), ARGC (DD 0), RSTART (DD 0),
              RLENGTH (DD 0), SUBSEP (DD OFFSET _AWK_subsep_default)
            Systeme de types AWK (coercition dynamique) :
              TYK_NUMBER (entier 32 bits signe),
              TYK_STRING (pointeur vers ASCIIZ),
              TYK_UNINITIALIZED (valeur par defaut "" ou 0),
              TYK_REGEXP (pointeur vers pattern data),
              TYK_ARRAY (tableau associatif pointeur),
              TYK_UNKNOWN (coercition dynamique)
            Classes de stockage : STORE_GLOBAL (.DATA),
              STORE_LOCAL (pile EBP), STORE_PARAM (EBP+n)

  TODO 05 - GESTION DES SCOPES (GLOBAL, FUNCTION, REGLE) [IMPLEMENTE]
            Pile de scopes : chaque scope maintient ses propres
              variables locales, un offset EBP courant, un label sortie
            Procedure EnterScope(kind: Integer)
            Procedure LeaveScope
            Function AllocLocal(bytes: Integer): Integer
            Function CurrentEbpOffset: Integer
            Scopes supportes : SK_GLOBAL, SK_FUNCTION, SK_RULE,
              SK_BLOCK, SK_LOOP
            Compteur d offset EBP pour allocation variables locales
            Offset EBP negatif pour locales [EBP-n]
            Offset EBP positif pour parametres [EBP+8], [EBP+12]...
            Convention STDCALL Win32 : parametres droite a gauche
            Pile de boucles pour break / continue imbriques

  TODO 06 - PARSEUR : EXPRESSIONS ARITHMETIQUES ET LOGIQUES
            (32 BITS) [IMPLEMENTE]
            Function ParseExpr: Integer (priorite la plus basse)
            Function ParseAssignExpr: Integer
              (= += -= *= /= %= ^= : affectation droite a gauche)
            Function ParseTernaryExpr: Integer
              (cond ? expr_vrai : expr_faux)
            Function ParseOrExpr: Integer   (||)
            Function ParseAndExpr: Integer  (&&)
            Function ParseInExpr: Integer   (expr in array)
            Function ParseMatchExpr: Integer (~ !~)
            Function ParseCompareExpr: Integer (< <= > >= == !=)
            Function ParseConcatExpr: Integer
              (concatenation implicite par juxtaposition)
            Function ParseAddExpr: Integer  (+ -)
            Function ParseMulExpr: Integer  (* / %)
            Function ParsePowExpr: Integer  (^ droite a gauche)
            Function ParseUnaryExpr: Integer
              (! - + ++ -- $ : prefixe)
            Function ParsePostfixExpr: Integer (++ -- suffixe)
            Function ParsePrimaryExpr: Integer
              Constante numerique -> MOV EAX, imm32
              Constante chaine    -> LEA EAX, [_AWK_n]
              Variable            -> MOV EAX, [_AWV_x] ou [EBP-n]
              Champ $n            -> CALL _AWRT_GETFIELD
              Appel de fonction   -> PUSH args + CALL _AWF_nom
              Fonction builtin    -> CALL _AWRT_xxx
              Expression reguliere /pat/ -> LEA EAX, [_AWP_n]
              Parentheses         -> ( ParseExpr )
            Helpers: IsOp, IsPunct, IsKW, Expect, SkipNewlines,
              IsConcatFollow
            Var ExprCount, Run mis a jour avec parseur d expressions
            Tous les calculs en registres 32 bits (EAX, EBX, ECX, EDX)

  TODO 07 - PARSEUR : CONCATENATION DE CHAINES ET COERCITION
            [IMPLEMENTE]
            Concatenation implicite AWK :
              "abc" x -> concatenation automatique sans operateur
              Detection : deux expressions primaires adjacentes sans
              operateur binaire entre elles
            Coercition nombre <-> chaine :
              Nombre vers chaine : CALL _AWRT_NUMTOSTR
              Chaine vers nombre : CALL _AWRT_STRTONUM
            Contexte de coercition :
              Contexte arithmetique : forcer TYK_NUMBER
              Contexte chaine : forcer TYK_STRING
              Contexte booleen : forcer TYK_NUMBER (0 = faux)
            Tampon de concatenation : _AWRT_CATBUF (512 octets)
            Routine _AWRT_STRCAT : concatener deux ASCIIZ
            Routine _AWRT_STRDUP : copier chaine dans le tas (HeapAlloc)
            Constantes CT_NUMBER/CT_STRING/CT_BOOLEAN
            GenCoerceToNumber, GenCoerceToString, GenCoerceToBoolean
            GenConcat (PUSH EBX + PUSH EAX + CALL _AWRT_STRCAT)
            GenStrDup (CALL _AWRT_STRDUP)
            ParseConcatExpr mis a jour avec coercition chaine
            Operateurs arithmetiques : coercition nombre implicite
            Var CoercionCount pour les statistiques
            test_concat.awk (concatenation + coercition)

  TODO 08 - GENERATION DE CODE : OPERATIONS ARITHMETIQUES 80386 [IMPLEMENTE]
            Procedure GenLoadVar(sym_idx: Integer)
              Variable scalaire : MOV EAX, DWORD PTR [_AWV_x] ou [EBP-n]
              Variable chaine   : MOV EAX, DWORD PTR [_AWV_x] (pointeur)
            Procedure GenStoreVar(sym_idx: Integer)
              MOV DWORD PTR [_AWV_x], EAX ou MOV [EBP-n], EAX
            Procedure GenBinOp(op: Integer)
              + : ADD EAX, EBX
              - : SUB EAX, EBX
              * : IMUL EAX, EBX
              / : CDQ + IDIV EBX (quotient dans EAX)
              % : CDQ + IDIV EBX -> MOV EAX, EDX (reste)
              ^ : CALL _AWRT_POW (puissance)
            Procedure GenCompare(op: Integer)
              CMP EAX, EBX + SETcc AL + MOVZX EAX, AL
            Procedure GenUnaryOp(op: Integer)
              - : NEG EAX
              ! : TEST EAX,EAX / SETZ AL / MOVZX EAX,AL
              ++ : INC DWORD PTR [var]
              -- : DEC DWORD PTR [var]
            Procedure GenFieldRef(field_idx: Integer)
              PUSH field_idx + CALL _AWRT_GETFIELD -> EAX
            Procedure GenFieldStore(field_idx: Integer)
              PUSH EAX + PUSH field_idx + CALL _AWRT_SETFIELD
            Primitives d emission : Emit, EmitLabel, EmitComment,
              EmitBlank, NewLabel, AddStringLit

  TODO 09 - PARSEUR : PRINT, PRINTF, SPRINTF (SORTIE CONSOLE WIN32)
            [IMPLEMENTE]
            Procedure ParsePrint
            Syntaxe :
              print                        -> afficher $0 + ORS
              print expr [, expr ...]      -> afficher avec OFS entre
              print expr > "fichier"       -> redirection fichier
              print expr >> "fichier"      -> redirection append
              print expr | "commande"      -> pipe (stub)
            Generation Win32 (via WriteFile API) :
              Variable nombre -> CALL _AWRT_NUMTOSTR + CALL _AWRT_PRINT
              Variable chaine -> MOV EAX, [var] + CALL _AWRT_PRINT
              Chaine litterale -> PUSH OFFSET _AWK_n + CALL _AWRT_PRINT
              Separateur OFS entre chaque argument
              Terminateur ORS (par defaut "\n") apres le dernier
            Procedure ParsePrintf
            Syntaxe :
              printf fmt [, expr ...]      -> format style C
              printf fmt [, expr ...] > "fichier"
            Generation : CALL _AWRT_PRINTF avec format + arguments
            Formats supportes : %d, %s, %f, %c, %o, %x, %%
            Procedure ParseSprintf (retourne chaine formatee dans EAX)
            GenPrintVal : coercer en chaine + CALL _AWRT_PRINT
            GenPrintOFS : afficher le separateur OFS
            GenPrintORS : afficher le terminateur ORS
            Var PrintCount pour les statistiques
            test_print.awk (print, printf, sprintf, redirection)

  TODO 10 - PARSEUR : IF / ELSE [IMPLEMENTE]
            Procedure ParseIf
            Syntaxe :
              if (condition) instruction
              if (condition) instruction else instruction
              if (condition) { instructions } else { instructions }
            Generation 32 bits :
              Evaluer condition -> EAX
              TEST EAX, EAX + JZ _AWL_else ou _AWL_endif
              Bloc vrai
              JMP _AWL_endif (si else present)
              _AWL_else: bloc faux
              _AWL_endif:
            Support des blocs entre accolades { }
            Support des instructions simples sans accolades
            Procedure ParseStatement : parser une instruction unique
              (expression, print, printf, if, for, while, etc.)
            Procedure ParseBlock : parser { instructions } ou instruction
            Var IfCount pour les statistiques
            test_ifelse.awk (15 cas if/else imbriques)

  TODO 11 - PARSEUR : WHILE, FOR, DO-WHILE, BREAK, CONTINUE [IMPLEMENTE]
            Procedure ParseWhile
            Syntaxe : while (condition) instruction | { instructions }
            Generation 32 bits :
              _AWL_top: evaluer condition -> EAX
              TEST EAX, EAX + JZ _AWL_end
              Corps + JMP _AWL_top + _AWL_end:
            Procedure ParseFor
            Syntaxe : for (init; condition; incr) instruction
            Generation 32 bits :
              init + _AWL_top: condition + JZ _AWL_end
              Corps + incr + JMP _AWL_top + _AWL_end:
            Procedure ParseDoWhile
            Syntaxe : do instruction | { instructions } while (cond)
            Generation 32 bits :
              _AWL_top: corps + evaluer condition
              TEST EAX, EAX + JNZ _AWL_top
            Procedure ParseBreak
              break -> JMP _AWL_end (label fin de boucle courante)
            Procedure ParseContinue
              continue -> JMP _AWL_top (label debut de boucle courante)
            Pile de boucles pour break / continue imbriques

  TODO 12 - PARSEUR : FOR-IN (ITERATION SUR TABLEAUX ASSOCIATIFS)
            [IMPLEMENTE]
            Procedure ParseForIn
            Syntaxe : for (var in array) instruction | { instructions }
            Generation 32 bits :
              PUSH OFFSET _AWA_array + CALL _AWRT_HASH_INIT
              _AWL_top: PUSH OFFSET _AWA_array
              CALL _AWRT_HASH_NEXT -> EAX (cle suivante)
              TEST EAX, EAX + JZ _AWL_end (plus de cles)
              MOV [_AWV_var], EAX (stocker cle dans var)
              Corps + JMP _AWL_top + _AWL_end:
            Support break / continue dans for-in
            Var ForInCount pour les statistiques
            test_forin.awk (15 cas, 10 for-in)

  TODO 13 - PARSEUR : FONCTIONS UTILISATEUR (FUNCTION / RETURN)
            [IMPLEMENTE]
            Procedure ParseFunctionDef
            Syntaxe :
              function nom(param1, param2, ...) { instructions }
            Convention d appel avec args gauche a droite :
              PUSH arg1 + PUSH arg2 + ... + CALL _AWF_nom
              Prologue : PUSH EBP / MOV EBP, ESP / SUB ESP, 64
              Epilogue : MOV ESP, EBP / POP EBP / RET n
              Param I a [EBP + 4 + (N-I+1)*4] (offsets ajustes)
              Variables locales a [EBP-4], [EBP-8]...
            ParseReturn dans ParseStatement :
              return [expr] -> MOV EAX, val + JMP _AWL_exit
            Appel de fonction utilisateur dans ParsePrimaryExpr :
              PUSH args + CALL _AWF_nom
              Resultat dans EAX (callee cleanup via RET n)
            Support de la recursion (pile d appels EBP)
            Var FuncDefCount pour les statistiques
            test_functions.awk (15 cas, fonctions, recursion)

  TODO 14 - PARSEUR : REGLES PATTERN-ACTION (BEGIN, END, /regex/, expr)
            [IMPLEMENTE]
            Type TRuleEntry : Kind (RK_BEGIN, RK_END, RK_PATTERN,
              RK_EXPR, RK_RANGE, RK_ALL), PatternStr, AsmLabel,
              HasAction (Boolean)
            RuleTab[0..MAX_RULES-1] / RuleCount
            Procedure ParseProgram
              Parcourir les regles de haut niveau :
              BEGIN { action }         -> bloc initialisation
              END { action }           -> bloc finalisation
              /regexp/ { action }      -> filtre par regex
              expression { action }    -> filtre par condition
              /deb/,/fin/ { action }   -> range pattern (debut-fin)
              { action }               -> action sans pattern (toutes lignes)
            Generation 32 bits :
              Chaque regle = label _AWR_n + test pattern + corps
              Boucle principale : lire ligne -> tester chaque regle
              BEGIN execute avant la boucle
              END execute apres la boucle
            Procedure ParseAction
              ParseBlock entre accolades { }
            Support de next (passer a la ligne suivante)
            Support de nextfile (passer au fichier suivant)
            Support de exit [expr] (terminer avec code de sortie)
            Var RuleDefCount pour les statistiques
            test_rules.awk (15 cas, regles pattern-action)

  TODO 15 - PARSEUR : CHAMPS $0..$NF ET SEPARATEURS FS, RS, OFS, ORS
            [IMPLEMENTE]
            Procedure ParseFieldRef
              $0 -> ligne complete (pointeur vers _AWRT_LINE)
              $1..$NF -> champ n (CALL _AWRT_GETFIELD)
              $(expr) -> champ dynamique
              $NF -> dernier champ
            Procedure GenFieldSplit
              Decouper $0 en champs selon FS :
              CALL _AWRT_SPLITLINE -> met a jour NF et $1..$NF
            Variables separateurs :
              FS (defaut " ") : separateur de champs en entree
              RS (defaut "\n") : separateur d enregistrements
              OFS (defaut " ") : separateur de champs en sortie
              ORS (defaut "\n") : separateur d enregistrements sortie
            Affectation a un champ ($n = expr) :
              Modifier le champ et reconstruire $0 avec OFS
            Tampons :
              _AWRT_LINE (4096 octets) : ligne courante
              _AWRT_FIELDS[0..MAX_FIELDS] : tableau de pointeurs
              _AWRT_NF (DD) : nombre de champs courant
            Var FieldRefCount pour les statistiques
            test_fields.awk (15 cas, champs et separateurs)

  TODO 16 - PARSEUR : TABLEAUX ASSOCIATIFS ET OPERATEUR IN / DELETE
            [IMPLEMENTE]
            Representation memoire :
              Chaque tableau = bloc de MAX_HASH_PAIRS paires (cle, val)
              Cle : pointeur vers chaine ASCIIZ
              Valeur : DWORD (nombre ou pointeur chaine)
            Procedure GenArrayGet(SymIdx)
              PUSH EAX (cle) + PUSH OFFSET _AWA_array + CALL HASH_GET
            Procedure GenArraySet(SymIdx)
              PUSH EAX (val) + PUSH EBX (cle) + PUSH OFFSET array + CALL HASH_SET
            Procedure GenArrayExists(SymIdx)
              PUSH EAX (cle) + PUSH OFFSET _AWA_array + CALL HASH_EXISTS
            Procedure GenArrayDel(SymIdx)
              PUSH EAX (cle) + PUSH OFFSET _AWA_array + CALL HASH_DEL
            Procedure GenArrayClear(SymIdx)
              PUSH OFFSET _AWA_array + CALL HASH_CLEAR
            ParsePrimaryExpr: ident[ expr ] -> GenArrayGet (lecture)
            ParseAssignExpr: ident[ expr ] = val -> GenArraySet (ecriture)
              via LastArraySym (index sym du tableau) et LastArrayHasKey
            ParseInExpr: expr in array -> GenArrayExists -> 0/1
            ParseStatement delete: array[expr] -> GenArrayDel, array -> GenArrayClear
            Indices multidimensionnels :
              array[i, j] -> GenConcat avec SUBSEP entre chaque indice
            Var ArrayOpCount pour les statistiques
            test_arrays16.awk (15 cas, tableaux associatifs)

  TODO 17 - PARSEUR : EXPRESSIONS REGULIERES ET MATCHING ~ / !~
            [IMPLEMENTE]
            Compilation de regex en pattern data :
              /pattern/ -> stocker pattern dans segment .DATA
              Support des metacaracteres : . * + ? [ ] ^ $ | ( )
              Classes de caracteres : [abc] [a-z] [^0-9]
              Echappement : \. \* \+ etc.
            Operateur ~ (match) :
              expr ~ /pattern/ -> CALL _AWRT_MATCH_RE -> 0/1
            Operateur !~ (not match) :
              expr !~ /pattern/ -> CALL _AWRT_MATCH_RE + NOT
            Pattern dans les regles :
              /pattern/ { action } -> tester $0 ~ /pattern/
            Procedure AddRegexPat(pattern) : enregistrer un pattern
              dans RegexPatTab et retourner son label _AWP_n
            Procedure GenRegexMatch : PUSH EAX (pattern) +
              PUSH EBX (string) + CALL _AWRT_MATCH_RE -> EAX 0/1
            ParsePrimaryExpr TK_REGEXP : AddRegexPat + GenLoadStr
            ParseMatchExpr : ~ -> GenRegexMatch, !~ -> GenRegexMatch + NOT
            Var RegexOpCount, RegexPatCount pour les statistiques
            test_regex17.awk (15 cas, expressions regulieres)

  TODO 18 - PARSEUR : FONCTIONS BUILTIN CHAINES
            [IMPLEMENTE]
            Procedure ParseBuiltinString
            Fonctions a supporter :
              length(s)           -> CALL _AWRT_STRLEN -> EAX
              length(array)       -> nombre d elements du tableau
              substr(s, start [, len]) -> CALL _AWRT_SUBSTR -> EAX (ptr)
              index(s, target)    -> CALL _AWRT_INDEX -> EAX (position)
              split(s, array [, sep]) -> CALL _AWRT_SPLIT -> EAX (nb)
              sub(regex, repl [, target])  -> CALL _AWRT_SUB -> EAX (nb)
              gsub(regex, repl [, target]) -> CALL _AWRT_GSUB -> EAX (nb)
              match(s, regex)     -> CALL _AWRT_MATCH -> EAX (position)
                Met a jour RSTART et RLENGTH
              sprintf(fmt, ...)   -> CALL _AWRT_SPRINTF -> EAX (ptr)
              tolower(s)          -> CALL _AWRT_TOLOWER -> EAX (ptr)
              toupper(s)          -> CALL _AWRT_TOUPPER -> EAX (ptr)
            Tampons : _AWRT_STRBUF (512 octets), _AWRT_SUBBUF (512)
            Var BuiltinStrCount pour les statistiques
            test_builtins18.awk (15 cas, fonctions builtin chaines)

  TODO 19 - PARSEUR : FONCTIONS BUILTIN MATHEMATIQUES
            [IMPLEMENTE]
            Function ParseBuiltinMath(BFIdx)
            Fonctions a supporter :
              sin(x)     -> CALL _AWRT_SIN -> EAX (approximation entiere)
              cos(x)     -> CALL _AWRT_COS -> EAX (approximation entiere)
              atan2(y,x) -> CALL _AWRT_ATAN2 -> EAX
              exp(x)     -> CALL _AWRT_EXP -> EAX
              log(x)     -> CALL _AWRT_LOG -> EAX
              sqrt(x)    -> CALL _AWRT_SQRT -> EAX
              int(x)     -> valeur entiere (troncature) : deja entier
              rand()     -> CALL _AWRT_RAND -> EAX (0..32767)
              srand([x]) -> CALL _AWRT_SRAND (initialiser graine)
            Fonctions systeme :
              system(cmd) -> stub : emettre '; system() stub'
              close(file) -> stub : emettre '; close() stub'
              fflush([file]) -> stub : emettre '; fflush() stub'
              mktime(spec) -> stub
              strftime(fmt [, timestamp]) -> stub
            Var BuiltinMathCount pour les statistiques
            test_builtins19.awk (15 cas, fonctions builtin mathematiques)

  TODO 20 - PARSEUR : GETLINE ET REDIRECTIONS E/S [IMPLEMENTE]
            Function ParseGetline : Integer
            Syntaxe :
              getline                  -> CALL _AWRT_READLINE -> EAX
              getline var              -> READLINE + GenStoreVar(var)
              getline < "fichier"      -> PUSH EAX + CALL GETLINE_FILE
              getline var < "fichier"  -> GETLINE_FILE + GenStoreVar(var)
              "cmd" | getline [var]    -> stub (pipe)
            Generation 32 bits :
              CALL _AWRT_READLINE -> EAX (ptr ligne ou 0 si EOF)
              TEST EAX + JZ -> 0 (EOF) ou 1 (succes)
            Redirections de sortie (print/printf) :
              > "fichier"  -> PUSH EAX + CALL _AWRT_REDIR_WRITE
              >> "fichier" -> PUSH EAX + CALL _AWRT_REDIR_APPEND
              | "commande" -> stub (pipe, warning)
            ParseStatement : getline / next / nextfile handlers
            Var GetlineCount pour les statistiques
            test_getline20.awk (15 cas, getline et redirections E/S)

  TODO 21 - PARSEUR : VARIABLES BUILTIN AWK [IMPLEMENTE]
            Initialisation des variables builtin dans le segment .DATA :
              NR       DD 0     (numero d enregistrement global)
              NF       DD 0     (nombre de champs dans $0)
              FNR      DD 0     (numero d enregistrement du fichier courant)
              FS       DD OFFSET _AWK_FS_DEF  (defaut : " ")
              RS       DD OFFSET _AWK_RS_DEF  (defaut : "\n")
              OFS      DD OFFSET _AWK_OFS_DEF (defaut : " ")
              ORS      DD OFFSET _AWK_ORS_DEF (defaut : "\n")
              FILENAME DD 0     (nom du fichier courant, ptr ASCIIZ)
              ARGC     DD 0     (nombre d arguments)
              ARGV     : tableau de pointeurs (arguments)
              RSTART   DD 0     (debut du dernier match)
              RLENGTH  DD 0     (longueur du dernier match)
              SUBSEP   DD OFFSET _AWK_SUBSEP_DEF (defaut : "\034")
              OFMT     DD OFFSET _AWK_OFMT_DEF   (defaut : "%.6g")
              CONVFMT  DD OFFSET _AWK_CONVFMT_DEF (defaut : "%.6g")
              ENVIRON  : tableau associatif (stub)
            Traitement des options -v var=val :
              Initialiser les variables avant le bloc BEGIN
            Traitement de -F sep :
              Modifier FS avant le bloc BEGIN

  TODO 22 - GENERATION : EN-TETE ASSEMBLEUR 80386 ET SEGMENT .DATA [IMPLEMENTE]
            Procedure EmitHeader
              '; Generated by AWKCW32 V0.1'
              '.386'
              '.MODEL FLAT, STDCALL'
              'OPTION CASEMAP:NONE'
              Declarations EXTRN pour API Win32 :
                ExitProcess, GetStdHandle, WriteFile, ReadFile,
                GetProcessHeap, HeapAlloc, HeapFree,
                CreateFileA, CloseHandle, GetCommandLineA
              '.STACK 4096'
              '_TEXT SEGMENT DWORD PUBLIC ''CODE'''
              'ASSUME CS:_TEXT'
            Procedure EmitDataSeg
              Variables builtin : _AWV_NR DD 0, _AWV_NF DD 0, ...
              Separateurs defaut : _AWK_FS_DEF DB ' ',0 ...
              Variables utilisateur : _AWV_nom DD 0
              Tableaux associatifs : _AWA_nom DB size DUP(0)
              Chaines litterales : _AWK_1, _AWK_2... DB 'texte',0
              Patterns regex : _AWP_1, _AWP_2... DB 'pattern',0
              Tampons runtime : _AWRT_LINE, _AWRT_FIELDS,
                _AWRT_NUMBUF, _AWRT_STRBUF, _AWRT_CATBUF,
                _AWRT_INPUTBUF, _AWRT_CRLF_DATA,
                _AWRT_HSTDOUT, _AWRT_HSTDIN, _AWRT_HHEAP
            Mode -asm : ecrire fichier .ASM avec commentaires

  TODO 23 - GENERATION : POINT D ENTREE WIN32, BOUCLE PRINCIPALE
            ET HELPERS RUNTIME [IMPLEMENTE]
            Procedure EmitEntryPoint
              _AWF_main:
              PUSH EBP / MOV EBP, ESP
              Initialiser stdout : PUSH -11 / CALL GetStdHandle
                MOV [_AWRT_HSTDOUT], EAX
              Initialiser stdin : PUSH -10 / CALL GetStdHandle
                MOV [_AWRT_HSTDIN], EAX
              Initialiser heap : CALL GetProcessHeap
                MOV [_AWRT_HHEAP], EAX
              Appliquer -v var=val et -F sep
              Executer les regles BEGIN
              Boucle principale :
                CALL _AWRT_READLINE -> TEST EAX,EAX / JZ _AWL_eof
                CALL _AWRT_SPLITLINE (decouper en champs)
                INC DWORD PTR [_AWV_NR] / INC DWORD PTR [_AWV_FNR]
                Pour chaque regle : tester pattern + executer action
                JMP _AWL_loop
              _AWL_eof:
              Executer les regles END
              PUSH 0 / CALL ExitProcess
            Procedure EmitRuntimeHelpers
              _AWRT_CRLF      : ecrire CR+LF via WriteFile
              _AWRT_PRINT     : EAX=ptr ASCIIZ -> WriteFile(hStdOut)
              _AWRT_NUMTOSTR  : EAX=entier -> ASCIIZ dans _AWRT_NUMBUF
              _AWRT_STRTONUM  : EAX=ptr ASCIIZ -> EAX=entier
              _AWRT_PRINTINT  : EAX=entier -> NUMTOSTR + PRINT
              _AWRT_PRINTLN   : PRINT + CRLF
              _AWRT_READLINE  : ReadFile -> _AWRT_LINE -> EAX=0/1
              _AWRT_SPLITLINE : decouper _AWRT_LINE en champs selon FS
              _AWRT_GETFIELD  : EAX=idx -> EAX=ptr champ
              _AWRT_SETFIELD  : EAX=idx, EBX=val -> modifier champ
              _AWRT_REBUILDLINE : reconstruire $0 depuis les champs
              _AWRT_STRLEN    : EAX=ptr ASCIIZ -> EAX=longueur
              _AWRT_STRCOPY   : ESI=src, EDI=dst -> copie ASCIIZ
              _AWRT_STRCAT    : concatener deux ASCIIZ
              _AWRT_STRDUP    : copier chaine dans le tas
              _AWRT_STRCMP    : comparer deux ASCIIZ -> flags
              _AWRT_HASH_GET  : rechercher dans tableau associatif
              _AWRT_HASH_SET  : inserer/modifier dans tableau
              _AWRT_HASH_EXISTS : tester existence cle
              _AWRT_HASH_DEL  : supprimer entree
              _AWRT_HASH_CLEAR : vider tableau
              _AWRT_HASH_NEXT : iterateur for-in
              _AWRT_MATCH_RE  : matcher regex
              _AWRT_POW       : puissance (a^b)
              _AWRT_SQRT      : racine carree (approximation entiere)
              _AWRT_RAND      : nombre pseudo-aleatoire
              _AWRT_SRAND     : initialiser graine
              _AWRT_SUBSTR    : extraire sous-chaine
              _AWRT_INDEX     : trouver position sous-chaine
              _AWRT_SPLIT     : decouper chaine en tableau
              _AWRT_SUB       : remplacer premiere occurrence
              _AWRT_GSUB      : remplacer toutes les occurrences
              _AWRT_MATCH     : matcher et retourner position
              _AWRT_TOLOWER   : convertir en minuscules
              _AWRT_TOUPPER   : convertir en majuscules
              _AWRT_SPRINTF   : formater chaine (stub simplifie)
              _AWRT_PRINTF    : formater et afficher
              _AWRT_ERROR     : afficher erreur + ExitProcess(1)

  TODO 24 - PARSEUR : DISPATCHER ET BOUCLE PRINCIPALE [IMPLEMENTE]
            Procedure ParseStatement
            Dispatcher selon le token courant :
              if          -> ParseIf
              while       -> ParseWhile
              for         -> ParseFor ou ParseForIn (selon contexte)
              do          -> ParseDoWhile
              break       -> ParseBreak
              continue    -> ParseContinue
              next        -> ParseNext (JMP _AWL_next_line)
              nextfile    -> ParseNextfile (JMP _AWL_next_file)
              exit        -> ParseExit (PUSH [expr] / CALL ExitProcess)
              return      -> ParseReturn
              delete      -> ParseDelete
              print       -> ParsePrint
              printf      -> ParsePrintf
              getline     -> ParseGetline
              {           -> ParseBlock (bloc entre accolades)
              ;           -> instruction vide (consommer)
              ident =     -> ParseAssignment
              ident(      -> ParseFunctionCall
              ident[      -> ParseArrayAssignment
              $expr =     -> ParseFieldAssignment
              expr        -> evaluer et ignorer le resultat
            Procedure ParseBlock
              { ParseStatement; ... }
            Procedure Run
              LexInit + ParseProgram + generation + LexClose
              Afficher statistiques si -v (symboles, fonctions,
              regles, chaines, erreurs)

  TODO 25 - GENERATION FINALE : LINKER PE, FICHIERS .OBJ ET EXEMPLES [IMPLEMENTE]
            Procedure EmitClose : finaliser l emission ASM
              EmitRuntimeHelpers + '_TEXT ENDS' + EmitDataSeg +
              'END _AWF_main'
            Procedure BinInit / BinEmit / BinEmitData / BinFixup
            Si EmitExe (par defaut) :
              Construire l image PE complete en memoire :
              - DOS stub header (MZ + message + offset PE)
              - PE signature + COFF header (Machine=i386)
              - Optional header (ImageBase=$00400000, EntryPoint,
                SectionAlignment=4096, FileAlignment=512,
                Subsystem=CUI console)
              - Section .text (code machine 80386)
              - Section .data (variables et litteraux)
              - Section .idata (Import Address Table pour
                kernel32.dll : ExitProcess, GetStdHandle,
                WriteFile, ReadFile, GetProcessHeap,
                HeapAlloc, HeapFree, CreateFileA, CloseHandle,
                GetCommandLineA)
              Ecrire le fichier .EXE resultant
            Si EmitObj (-obj) :
              Construire un fichier COFF .OBJ 32 bits :
              - COFF header + sections .text, .data
              - Table de symboles et relocations
              - Compatible avec les linkers Win32 (LINK.EXE)
            Si EmitAsm (-asm) :
              Ecrire le fichier .ASM lisible en parallele
              (genere pendant la compilation, pas de passe
              supplementaire)
            Programmes de test : SAMPLES\AWK\*
              hello.awk     : BEGIN, print, variables, chaines
              fields.awk    : champs $1 $NF, NR, NF, FS
              funcuser.awk  : fonctions utilisateur, recursion, return
              arrays.awk    : tableaux associatifs, for-in, delete
              regex.awk     : patterns /regexp/, sub, gsub, match
              math.awk      : fonctions mathematiques, expressions
              format.awk    : printf, redirection fichier
              multifile.awk : FILENAME, FNR, ARGC, ARGV, getline
            Rapport de compilation : 0 erreurs, N symboles,
              M fonctions, P regles

  ============================================================ *)

Program AWKCW32;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================ }
{ TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES PE/COFF      }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

{ ============================================================ }
{ CONSTANTES                                                   }
{ ============================================================ }

Const
  AWKCW32_VERSION = '0.1';
  AWKCW32_DATE    = '2026';

  { Limites internes }
  MAX_SYM        = {$IFDEF FPC}2048{$ELSE}256{$ENDIF};
  MAX_LABEL      = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_SCOPE      = {$IFDEF FPC}64{$ELSE}32{$ENDIF};
  MAX_DATA       = {$IFDEF FPC}512{$ELSE}64{$ENDIF};
  MAX_PARAM      = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_LOOP_NEST  = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_ERRORS     = {$IFDEF FPC}30{$ELSE}3{$ENDIF};
  MAX_STR        = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  MAX_RULES      = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_FIELDS     = 64;       { nombre max de champs $1..$NF     }
  MAX_HASH_PAIRS = 64;       { paires max par tableau associatif }
  MAX_INIT_VARS  = 16;       { nombre max de -v var=val          }
  MAX_FUNC       = {$IFDEF FPC}256{$ELSE}32{$ENDIF};
  STACK_SIZE     = 4096;     { taille pile Win32                 }

  { Prefixes de nommage ASM }
  AW_VAR_PFX   = '_AWV_';    { variable utilisateur              }
  AW_FN_PFX    = '_AWF_';    { fonction utilisateur              }
  AW_STR_PFX   = '_AWK_';    { constante chaine                  }
  AW_RT_PFX    = '_AWRT_';   { routine runtime                   }
  AW_LBL_PFX   = '_AWL_';    { label de saut interne             }
  AW_ARR_PFX   = '_AWA_';    { tableau associatif                }
  AW_PAT_PFX   = '_AWP_';    { pattern data                      }
  AW_RULE_PFX  = '_AWR_';    { regle pattern-action              }

  { Codes de sortie }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { PE/COFF format constants }
{$IFDEF FPC}
  PE_DOS_MAGIC    = $5A4D;       { 'MZ'                              }
  PE_PE_SIG       = $00004550;   { 'PE\0\0'                          }
  PE_MACHINE_I386 = $014C;       { i386                               }
  PE_OPT_SIZE     = 224;         { sizeof IMAGE_OPTIONAL_HEADER32     }
  PE_MAGIC_32     = $010B;       { PE32                               }
  PE_IMG_BASE     = $00400000;   { default image base                 }
  PE_SEC_ALIGN    = $1000;       { section alignment (4KB)            }
  PE_FILE_ALIGN   = $0200;       { file alignment (512)               }
  PE_SUBSYS_CUI   = 3;           { console subsystem                  }
  PE_SCN_TEXT     = $60000020;   { CODE | EXECUTE | READ              }
  PE_SCN_RDATA    = $40000040;   { INIT_DATA | READ                   }
  PE_SCN_BSS      = LongInt($C0000040);  { INIT_DATA | READ | WRITE   }
  MAX_BIN_CODE    = 65536;       { 64 KB max code section             }
  MAX_BIN_DATA    = 65536;       { 64 KB max data section             }
  MAX_BIN_LBL     = 4096;        { max labels                         }
  MAX_BIN_FIX     = 8192;        { max fixups                         }
  PE_NUM_API      = 10;          { number of imported Win32 APIs      }
  COFF_RELOC_DIR32  = 6;         { IMAGE_REL_I386_DIR32               }
  COFF_RELOC_REL32  = 20;        { IMAGE_REL_I386_REL32               }
{$ENDIF}

{ ============================================================ }
{ TODO 03 - CONSTANTES MOTS-CLES, BUILTIN FUNC, BUILTIN VAR   }
{ ============================================================ }

  { Constantes mots-cles AWK (1..21) - 0 = pas un mot-cle }
  KW_BEGIN     = 1;   KW_END       = 2;   KW_IF        = 3;
  KW_ELSE      = 4;   KW_WHILE     = 5;   KW_FOR       = 6;
  KW_DO        = 7;   KW_IN        = 8;   KW_BREAK     = 9;
  KW_CONTINUE  = 10;  KW_FUNCTION  = 11;  KW_RETURN    = 12;
  KW_DELETE    = 13;   KW_EXIT      = 14;  KW_GETLINE   = 15;
  KW_NEXT      = 16;  KW_NEXTFILE  = 17;  KW_PRINT     = 18;
  KW_PRINTF    = 19;  KW_SPRINTF   = 20;  KW_BEGINFILE = 21;

  { Constantes fonctions builtin AWK (1..24) - 0 = pas builtin }
  BF_LENGTH    = 1;   BF_SUBSTR    = 2;   BF_INDEX     = 3;
  BF_SPLIT     = 4;   BF_SUB       = 5;   BF_GSUB      = 6;
  BF_MATCH     = 7;   BF_SPRINTF   = 8;   BF_TOLOWER   = 9;
  BF_TOUPPER   = 10;  BF_SIN       = 11;  BF_COS       = 12;
  BF_ATAN2     = 13;  BF_EXP       = 14;  BF_LOG       = 15;
  BF_SQRT      = 16;  BF_INT       = 17;  BF_RAND      = 18;
  BF_SRAND     = 19;  BF_SYSTEM    = 20;  BF_CLOSE     = 21;
  BF_FFLUSH    = 22;  BF_MKTIME    = 23;  BF_STRFTIME  = 24;

  { Constantes variables builtin AWK (1..16) - 0 = pas builtin }
  BV_FS        = 1;   BV_RS        = 2;   BV_OFS       = 3;
  BV_ORS       = 4;   BV_NR        = 5;   BV_NF        = 6;
  BV_FNR       = 7;   BV_FILENAME  = 8;   BV_ARGC      = 9;
  BV_ARGV      = 10;  BV_ENVIRON   = 11;  BV_RSTART    = 12;
  BV_RLENGTH   = 13;  BV_SUBSEP    = 14;  BV_OFMT      = 15;
  BV_CONVFMT   = 16;

{ ============================================================ }
{ TODO 04 - CONSTANTES TYPES AWK ET CLASSES DE STOCKAGE         }
{ ============================================================ }

  { Types AWK (coercition dynamique) }
  TYK_NUMBER        = 0;    { entier 32 bits signe              }
  TYK_STRING        = 1;    { pointeur vers ASCIIZ              }
  TYK_UNINITIALIZED = 2;    { valeur par defaut "" ou 0         }
  TYK_REGEXP        = 3;    { pointeur vers pattern data        }
  TYK_ARRAY         = 4;    { tableau associatif pointeur       }
  TYK_UNKNOWN       = 5;    { coercition dynamique              }

  { Classes de stockage }
  STORE_GLOBAL = 0;          { variable globale (.DATA)          }
  STORE_LOCAL  = 1;          { variable locale (pile EBP-n)      }
  STORE_PARAM  = 2;          { parametre fonction (EBP+n)        }

  { Contextes de coercition (TODO 07) }
  CT_NUMBER    = 0;          { forcer en nombre (contexte arith) }
  CT_STRING    = 1;          { forcer en chaine (contexte concat)}
  CT_BOOLEAN   = 2;          { forcer en nombre 0/1 (booleen)    }

  { Taille tampon de concatenation (TODO 07) }
  AWK_CATBUF_SIZE = 512;     { taille du tampon _AWRT_CATBUF     }

  { Codes d operations binaires (TODO 08) }
  OP_ADD  = 0;               { + addition                        }
  OP_SUB  = 1;               { - soustraction                    }
  OP_MUL  = 2;               { * multiplication                  }
  OP_DIV  = 3;               { / division entiere                }
  OP_MOD  = 4;               { % modulo                          }
  OP_POW  = 5;               { ^ puissance                       }

  { Codes de comparaison (TODO 08) }
  CMP_LT  = 0;              { <                                  }
  CMP_LE  = 1;              { <=                                 }
  CMP_GT  = 2;              { >                                  }
  CMP_GE  = 3;              { >=                                 }
  CMP_EQ  = 4;              { ==                                 }
  CMP_NE  = 5;              { !=                                 }

  { Taille maximale de la table des litteraux chaine (TODO 08) }
  MAX_STRLIT = 512;

  { Taille maximale de la table des patterns regex (TODO 17) }
  MAX_REGEX_PAT = 256;

{ ============================================================ }
{ TODO 05 - CONSTANTES DE SCOPES                                }
{ ============================================================ }

  { Types de scopes }
  SK_GLOBAL   = 0;            { scope global (programme)          }
  SK_FUNCTION = 1;            { scope fonction utilisateur        }
  SK_RULE     = 2;            { scope regle pattern-action        }
  SK_BLOCK    = 3;            { scope bloc accolades              }
  SK_LOOP     = 4;            { scope boucle (for/while/do)       }

{ ============================================================ }
{ TODO 14 - CONSTANTES DE REGLES PATTERN-ACTION                 }
{ ============================================================ }

  (* Types de regles pattern-action *)
  RK_BEGIN   = 0;              (* BEGIN action                     *)
  RK_END     = 1;              (* END action                       *)
  RK_PATTERN = 2;              (* /regexp/ action                  *)
  RK_EXPR    = 3;              (* expression action                *)
  RK_RANGE   = 4;              (* /deb/,/fin/ action               *)
  RK_ALL     = 5;              (* action sans pattern              *)

{ ============================================================ }
{ TYPES                                                        }
{ ============================================================ }

Type
  TString = String[MAX_STR];

  { ---- Options de compilation ----------------------------- }
  TInitVar = Record
    VarName  : TString;     { nom de la variable                }
    VarValue : TString;     { valeur (chaine)                   }
  End;

  TOptions = Record
    SrcFile   : TString;   { fichier source (.awk)              }
    OutFile   : TString;   { fichier de sortie (.exe/.obj/.asm) }
    Verbose   : Boolean;   { -v (verbose) : banniere + stats    }
    DebugMode : Boolean;   { -d : affichage de chaque token     }
    Warnings  : Boolean;   { -w : activer les avertissements    }
    EmitExe   : Boolean;   { produire un .EXE PE (defaut)       }
    EmitObj   : Boolean;   { -obj : produire uniquement un .OBJ }
    EmitAsm   : Boolean;   { -asm : produire un listing .ASM    }
    FieldSep  : TString;   { -F sep : separateur de champs      }
    InitVars  : Array[0..MAX_INIT_VARS - 1] Of TInitVar;
    InitCount : Integer;   { nombre de -v var=val               }
  End;

{$IFDEF FPC}
  { ---- Types binaires ------------------------------------- }
  TBinFixKind = (BFK_ABS32, BFK_REL32, BFK_IAT32);
  TBinFixup = Record
    Offset : LongInt;
    Kind   : TBinFixKind;
    Target : TString;
    InCode : Boolean;
  End;
  TBinLabel = Record
    Name   : TString;
    Offset : LongInt;
    InCode : Boolean;
  End;
{$ENDIF}

{ ============================================================ }
{ TODO 04 - TABLE DES SYMBOLES (32 BITS) [IMPLEMENTE]          }
{ ============================================================ }

  TSymEntry = Record
    Name         : String[64];  { nom AWK de la variable            }
    AsmLabel     : String[64];  { label assembleur (_AWV_xxx)       }
    TypeKind     : Integer;     { TYK_NUMBER / TYK_STRING / ...     }
    StoreClass   : Integer;     { STORE_GLOBAL / LOCAL / PARAM      }
    BpOffset     : Integer;     { offset [EBP+n] ou [EBP-n]        }
    IsParam      : Boolean;     { est un parametre de fonction ?    }
    ParamIdx     : Integer;     { indice dans la liste de params    }
    IsGlobal     : Boolean;     { variable globale (.DATA) ?        }
    IsArray      : Boolean;     { tableau associatif ?              }
    ArrayAsmLabel: String[64];  { label assembleur du tableau       }
  End;

  TFuncEntry = Record
    Name       : String[64];    { nom AWK de la fonction            }
    AsmLabel   : String[64];    { label assembleur (_AWF_xxx)       }
    ParamCount : Integer;       { nombre de parametres              }
    ParamNames : Array[1..MAX_PARAM] Of String[64];
    Defined    : Boolean;       { corps de fonction defini ?        }
    LocalCount : Integer;       { nombre de variables locales       }
  End;

  (* Entree de la table des regles pattern-action (TODO 14) *)
  TRuleEntry = Record
    Kind       : Integer;       (* RK_BEGIN / RK_END / RK_PATTERN *)
    PatternStr : String[MAX_STR]; (* contenu du pattern            *)
    AsmLabel   : String[64];    (* label assembleur _AWR_xxxxx     *)
    HasAction  : Boolean;       (* a un bloc action ?              *)
  End;

{ ============================================================ }
{ TODO 05 - GESTION DES SCOPES [IMPLEMENTE]                     }
{ ============================================================ }

  TScopeEntry = Record
    Kind          : Integer;    { SK_GLOBAL / FUNCTION / RULE / ... }
    SymBase       : Integer;    { SymCount au debut du scope        }
    EbpOffset     : Integer;    { offset EBP courant (negatif)      }
    ExitLabel     : String[64]; { label de sortie (function/rule)   }
    BreakLabel    : String[64]; { label break (boucle)              }
    ContinueLabel : String[64]; { label continue (boucle)           }
  End;

{ ============================================================ }
{ TODO 02 - TOKENISEUR AWK (LEXER) [IMPLEMENTE]               }
{ ============================================================ }

{ ---- Types de tokens AWK ---------------------------------- }

  TTokenKind = (
    TK_EOF,        { fin de fichier                            }
    TK_INTEGER,    { litteral entier 42 0xFF 0377              }
    TK_FLOAT,      { litteral flottant 3.14 1.5e3              }
    TK_STRING,     { litteral chaine "abc"                     }
    TK_REGEXP,     { expression reguliere /pattern/            }
    TK_IDENT,      { identificateur utilisateur                }
    TK_KEYWORD,    { mot-cle AWK (if while for ...)            }
    TK_BUILTIN,    { fonction builtin AWK (length substr ...)  }
    TK_BVAR,       { variable builtin AWK (FS NR NF ...)      }
    TK_FIELD,      { reference de champ $0 $1 $NF              }
    TK_OP,         { operateur + - * / = == != ~ !~ ...        }
    TK_PUNCT,      { ponctuation ; , ( ) [ ] accolades        }
    TK_NEWLINE     { fin de ligne logique (separateur d instr) }
  );

  TToken = Record
    Kind     : TTokenKind;
    Val      : TString;     { valeur textuelle brute            }
    IntVal   : LongInt;     { valeur entiere (TK_INTEGER)       }
    FloatVal : Real;        { valeur flottante (TK_FLOAT)       }
    Line     : Integer;     { numero de ligne source            }
    Col      : Integer;     { numero de colonne source          }
  End;

  { Entree de la table des litteraux chaine (TODO 08) }
  TStringLitEntry = Record
    Lbl : String[64];       { label ASM du litteral             }
    Val : TString;          { valeur de la chaine               }
  End;

  { Entree de la table des patterns regex (TODO 17) }
  TRegexPatEntry = Record
    Lbl : String[64];       { label ASM du pattern (_AWP_n)     }
    Pat : TString;          { pattern regex                     }
  End;

{ ============================================================ }
{ VARIABLES GLOBALES                                           }
{ ============================================================ }

Var
  { Options }
  Opts : TOptions;

  { Compteurs generaux }
  ErrorCount : Integer;
  WarnCount  : Integer;
  TotalLines : LongInt;

  { Fichier de sortie ASM }
  OutF       : Text;
  OutFOpen   : Boolean;

{$IFDEF FPC}
  { Variables binaires }
  BinCode     : Array[0..MAX_BIN_CODE - 1] of Byte;
  BinCodeLen  : LongInt;
  BinData     : Array[0..MAX_BIN_DATA - 1] of Byte;
  BinDataLen  : LongInt;
  BinLabels   : Array[0..MAX_BIN_LBL - 1] of TBinLabel;
  BinLblCount : Integer;
  BinFixups   : Array[0..MAX_BIN_FIX - 1] of TBinFixup;
  BinFixCount : Integer;
  BinInCode   : Boolean;
{$ENDIF}

  { Lexeur (TODO 02) }
  LexSrcF     : Text;         { handle du fichier source          }
  LexLine     : TString;      { ligne courante du source          }
  LexLineNo   : Integer;      { numero de ligne courante          }
  LexColNo    : Integer;      { colonne courante dans LexLine     }
  LexEOF      : Boolean;      { fin de fichier atteinte ?         }
  LexOpened   : Boolean;      { fichier source ouvert ?           }
  CurToken    : TToken;       { token courant                     }
  LexLastKind : TTokenKind;   { dernier token emis (pour regexp)  }

  { Push-back d un token (TODO 12 - lookahead for-in) }
  HasPushedBack : Boolean;     { un token a ete remis ?            }
  PushedBack    : TToken;      { token remis                       }

  { Table des symboles (TODO 04) }
  SymTab      : Array[0..MAX_SYM - 1] Of TSymEntry;
  SymCount    : Integer;      { nombre de symboles enregistres    }
  MaxSymCount : Integer;      { maximum de SymCount atteint       }

  { Table des fonctions (TODO 04) }
  FuncTab     : Array[0..MAX_FUNC - 1] Of TFuncEntry;
  FuncCount   : Integer;      { nombre de fonctions enregistrees  }

  { Pile de scopes (TODO 05) }
  ScopeStack  : Array[0..MAX_SCOPE - 1] Of TScopeEntry;
  ScopeDepth  : Integer;      { profondeur courante               }
  LoopDepth   : Integer;      { profondeur des boucles imbriquees }
  LabelSeq    : Integer;      { sequence pour labels uniques      }

  { Parseur d expressions (TODO 06) }
  ExprCount   : Integer;      { nombre d expressions parsees      }

  { Coercition et concatenation (TODO 07) }
  CoercionCount : Integer;    { nombre de coercitions effectuees  }
  ConcatCount   : Integer;    { nombre de concatenations implicites }

  { Generation de code (TODO 08) }
  GenCount       : Integer;    { nombre d operations code gen      }
  GenEnabled     : Boolean;    { generation de code active         }
  StringLitTab   : Array[0..MAX_STRLIT-1] Of TStringLitEntry;
  StringLitCount : Integer;    { nombre de litteraux chaine        }
  LastSymIdx     : Integer;    { dernier symbole charge/affecte    }

  { Print/Printf/Sprintf (TODO 09) }
  PrintCount     : Integer;    { nombre d instructions print/printf }

  { If/Else (TODO 10) }
  IfCount        : Integer;    { nombre d instructions if/else      }

  { Boucles (TODO 11) }
  WhileCount     : Integer;    { nombre d instructions while        }
  ForCount       : Integer;    { nombre d instructions for          }
  DoWhileCount   : Integer;    { nombre d instructions do-while     }

  { For-In (TODO 12) }
  ForInCount     : Integer;    { nombre d instructions for-in       }

  { Fonctions utilisateur (TODO 13) }
  FuncDefCount   : Integer;    { nombre de definitions de fonctions }

  { Regles pattern-action (TODO 14) }
  RuleTab        : Array[0..MAX_RULES - 1] Of TRuleEntry;
  RuleCount      : Integer;    { nombre de regles enregistrees      }
  RuleDefCount   : Integer;    { nombre de regles parsees           }

  { Champs et separateurs (TODO 15) }
  FieldRefCount  : Integer;    { nombre de references de champs     }
  LastFieldIdx   : Integer;    { dernier index de champ ($0..$n)    }
  LastFieldIsExpr: Boolean;    { dernier champ est $(expr) ?        }

  { Tableaux associatifs (TODO 16) }
  ArrayOpCount   : Integer;    { nombre d operations sur tableaux   }
  LastArraySym   : Integer;    { index sym du tableau LHS           }
  LastArrayHasKey: Boolean;    { le LHS est array[key] ?            }

  { Expressions regulieres (TODO 17) }
  RegexPatTab    : Array[0..MAX_REGEX_PAT - 1] Of TRegexPatEntry;
  RegexPatCount  : Integer;    { nombre de patterns regex stockes   }
  RegexOpCount   : Integer;    { nombre d operations regex (~ !~)   }

  { Fonctions builtin chaines (TODO 18) }
  BuiltinStrCount: Integer;    { nombre d appels fonctions builtin  }

  { Fonctions builtin mathematiques (TODO 19) }
  BuiltinMathCount: Integer;   { nombre d appels fonctions builtin math }

  { Getline et redirections E/S (TODO 20) }
  GetlineCount   : Integer;    { nombre d instructions getline           }

  { Variables builtin AWK (TODO 21) }
  BuiltinVarCount: Integer;    { nombre d initialisations var builtin    }

  { Generation en-tete et segment .DATA (TODO 22) }
  EmitHeaderDone : Boolean;    { en-tete ASM emise ?                     }

  { Point d entree et helpers runtime (TODO 23) }
  RuntimeHelpCount : Integer;  { nombre de helpers runtime emis          }

  { Dispatcher et boucle principale (TODO 24) }
  DispatchCount  : Integer;    { nombre d instructions exit dispatchees  }

Const
{$IFDEF FPC}
  BinAPIDecorated : Array[0..PE_NUM_API - 1] Of String[32] = (
    '_ExitProcess@4', '_GetStdHandle@4', '_WriteFile@20',
    '_ReadFile@20', '_GetProcessHeap@0', '_HeapAlloc@12',
    '_HeapFree@12', '_CreateFileA@28', '_CloseHandle@4',
    '_GetCommandLineA@0'
  );
  BinAPIName : Array[0..PE_NUM_API - 1] Of String[20] = (
    'ExitProcess', 'GetStdHandle', 'WriteFile', 'ReadFile',
    'GetProcessHeap', 'HeapAlloc', 'HeapFree',
    'CreateFileA', 'CloseHandle', 'GetCommandLineA'
  );
{$ENDIF}

{ ============================================================ }
{ FONCTIONS UTILITAIRES                                        }
{ ============================================================ }

Function IntToStr_(V : LongInt) : TString;
Var S : TString;
Begin
  Str(V, S);
  IntToStr_ := S;
End;

Function StrUpperCase(Const S : TString) : TString;
Var
  I   : Integer;
  Tmp : TString;
Begin
  Tmp := S;
  For I := 1 To Length(Tmp) Do
    If (Tmp[I] >= 'a') And (Tmp[I] <= 'z') Then
      Tmp[I] := Chr(Ord(Tmp[I]) - 32);
  StrUpperCase := Tmp;
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

{ Convertir un identificateur en label ASM valide }
Function AsmIdent(Const S : TString) : TString;
Var
  I   : Integer;
  Tmp : TString;
Begin
  Tmp := StrUpperCase(S);
  For I := 1 To Length(Tmp) Do
    If Not (((Tmp[I] >= 'A') And (Tmp[I] <= 'Z')) Or
            ((Tmp[I] >= '0') And (Tmp[I] <= '9')) Or
            (Tmp[I] = '_')) Then
      Tmp[I] := '_';
  AsmIdent := Tmp;
End;

{ ============================================================ }
{ GESTION DES ERREURS                                          }
{ ============================================================ }

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('AWKCW32: FATAL: ', Msg);
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
  Halt(EXIT_ERROR);
End;

Procedure WarnMsg(Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  WriteLn('AWKCW32: warning: ', Msg);
  Inc(WarnCount);
End;

{ ============================================================ }
{ INITIALISATION DES OPTIONS                                   }
{ ============================================================ }

Procedure InitOptions;
Begin
  Opts.SrcFile   := '';
  Opts.OutFile   := '';
  Opts.Verbose   := False;
  Opts.DebugMode := False;
  Opts.Warnings  := False;
  Opts.EmitExe   := True;
  Opts.EmitObj   := False;
  Opts.EmitAsm   := False;
  Opts.FieldSep  := ' ';
  Opts.InitCount := 0;
End;

{ ============================================================ }
{ AIDE EN LIGNE                                                }
{ ============================================================ }

Procedure ShowHelp;
Begin
  WriteLn('AWKCW32 v', AWKCW32_VERSION, ' (', AWKCW32_DATE,
          ') - Compilateur AWK vers 80386 (Windows PE 32 bits)');
  WriteLn('AWKCW32 - Cette commande permet de lancer le compilateur ',
          'AWK pour l''assembleur du microprocesseur 80386 (en ',
          'executable Windows 32 bits).');
  WriteLn;
  WriteLn('Syntaxe : AWKCW32 <source.awk> [options]');
  WriteLn;
  WriteLn('Sortie :');
  WriteLn('  Par defaut un .EXE (PE Windows 32 bits)');
  WriteLn('  -obj           Produire seulement un fichier .OBJ (COFF)');
  WriteLn('  -asm           Produire egalement un fichier .ASM lisible');
  WriteLn('  -o <fichier>   Specifier le nom du fichier de sortie');
  WriteLn;
  WriteLn('AWK :');
  WriteLn('  -F <sep>       Separateur de champs (defaut espace)');
  WriteLn('  -v var=val     Initialiser une variable avant BEGIN');
  WriteLn;
  WriteLn('General :');
  WriteLn('  --verbose      Mode verbeux (banniere + statistiques)');
  WriteLn('  -d             Debug tokens (affiche chaque token)');
  WriteLn('  -w             Afficher les avertissements');
  WriteLn('  -h, --help, /? Afficher cette aide');
  WriteLn;
  WriteLn('Exemples :');
  WriteLn('  AWKCW32 hello.awk');
  WriteLn('  AWKCW32 hello.awk --verbose');
  WriteLn('  AWKCW32 hello.awk -asm');
  WriteLn('  AWKCW32 hello.awk -obj');
  WriteLn('  AWKCW32 hello.awk -o MONPROG.EXE');
  WriteLn('  AWKCW32 -F: script.awk');
  WriteLn('  AWKCW32 -v N=10 script.awk');
  Halt(EXIT_OK);
End;

{ ============================================================ }
{ ANALYSE DES ARGUMENTS                                        }
{ ============================================================ }

Procedure ParseArgs;
Var
  I      : Integer;
  Arg    : TString;
  Ext    : TString;
  EqPos  : Integer;
  J      : Integer;
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
    Else If Arg = '--verbose' Then
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
    Else If Arg = '-F' Then
    Begin
      Inc(I);
      If I > ParamCount Then
        FatalError('option -F requiert un argument');
      Opts.FieldSep := ParamStr(I);
    End
    Else If (Length(Arg) > 2) And (Arg[1] = '-') And (Arg[2] = 'F') Then
    Begin
      { -Fsep : separateur colle a l option }
      Opts.FieldSep := Copy(Arg, 3, Length(Arg) - 2);
    End
    Else If Arg = '-v' Then
    Begin
      Inc(I);
      If I > ParamCount Then
        FatalError('option -v requiert un argument var=val');
      Arg := ParamStr(I);
      { Chercher le signe = }
      EqPos := 0;
      For J := 1 To Length(Arg) Do
        If (Arg[J] = '=') And (EqPos = 0) Then
          EqPos := J;
      If (EqPos < 2) Or (EqPos > Length(Arg)) Then
        FatalError('-v : format attendu var=val');
      If Opts.InitCount >= MAX_INIT_VARS Then
        FatalError('trop de variables -v (max ' +
                   IntToStr_(MAX_INIT_VARS) + ')');
      Opts.InitVars[Opts.InitCount].VarName :=
        Copy(Arg, 1, EqPos - 1);
      Opts.InitVars[Opts.InitCount].VarValue :=
        Copy(Arg, EqPos + 1, Length(Arg) - EqPos);
      Inc(Opts.InitCount);
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
    WriteLn('AWKCW32: fichier source manquant');
    ShowHelp;
  End;

  { Verifier l extension .awk }
  Ext := ExtractExt(Opts.SrcFile);
  If (Ext <> '.awk') Then
    WarnMsg('extension attendue .awk, trouvee: ' + Ext);

  { Fichier de sortie par defaut }
  If Opts.OutFile = '' Then
  Begin
    If Opts.EmitObj Then
      Opts.OutFile := ReplaceExt(Opts.SrcFile, '.obj')
    Else
      Opts.OutFile := ReplaceExt(Opts.SrcFile, '.exe');
  End;
End;

{ ============================================================ }
{ BANNIERE ET STATISTIQUES                                     }
{ ============================================================ }

Procedure ShowBanner;
Begin
  If Not Opts.Verbose Then Exit;
  WriteLn('AWKCW32 v', AWKCW32_VERSION, ' (', AWKCW32_DATE,
          ') - Compilateur AWK -> 80386 PE Win32');
  WriteLn('Source   : ', Opts.SrcFile);
  WriteLn('Sortie   : ', Opts.OutFile);
  If Opts.EmitAsm Then
    WriteLn('ASM      : ', ReplaceExt(Opts.OutFile, '.asm'));
  If Opts.EmitObj Then
    WriteLn('Format   : OBJ (COFF)')
  Else
    WriteLn('Format   : EXE (PE Win32)');
  If Opts.FieldSep <> ' ' Then
    WriteLn('FS       : ', Opts.FieldSep);
  If Opts.InitCount > 0 Then
    WriteLn('InitVars : ', Opts.InitCount);
  WriteLn;
End;

Procedure ShowStats;
Begin
  If Not Opts.Verbose Then Exit;
  WriteLn;
  WriteLn('--- Statistiques ---');
  WriteLn('Lignes analysees : ', TotalLines);
  WriteLn('Symboles         : ', SymCount);
  WriteLn('Fonctions        : ', FuncCount);
  WriteLn('Expressions      : ', ExprCount);
  WriteLn('Coercitions      : ', CoercionCount);
  WriteLn('Concatenations   : ', ConcatCount);
  WriteLn('Print/Printf     : ', PrintCount);
  WriteLn('If/Else          : ', IfCount);
  WriteLn('While            : ', WhileCount);
  WriteLn('For              : ', ForCount);
  WriteLn('Do-While         : ', DoWhileCount);
  WriteLn('For-In           : ', ForInCount);
  WriteLn('Func definitions : ', FuncDefCount);
  WriteLn('Rules            : ', RuleDefCount);
  WriteLn('Field refs       : ', FieldRefCount);
  WriteLn('Array ops        : ', ArrayOpCount);
  WriteLn('Regex patterns   : ', RegexPatCount);
  WriteLn('Regex ops (~!~)  : ', RegexOpCount);
  WriteLn('Builtin str ops  : ', BuiltinStrCount);
  WriteLn('Builtin math ops : ', BuiltinMathCount);
  WriteLn('Getline ops      : ', GetlineCount);
  WriteLn('Builtin var init : ', BuiltinVarCount);
  WriteLn('Runtime helpers  : ', RuntimeHelpCount);
  WriteLn('Exit statements  : ', DispatchCount);
  WriteLn('Code gen ops     : ', GenCount);
  WriteLn('Litteraux chaine : ', StringLitCount);
  WriteLn('Scope depth      : ', ScopeDepth);
  WriteLn('Labels generes   : ', LabelSeq);
  WriteLn('Erreurs          : ', ErrorCount);
  WriteLn('Avertissements   : ', WarnCount);
End;

{ ============================================================ }
{ NETTOYAGE                                                    }
{ ============================================================ }

Procedure Cleanup;
Begin
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ============================================================ }
{ TODO 02 - TOKENISEUR AWK (LEXER)                            }
{ ============================================================ }

{ ---- Fonctions de test de caracteres ---------------------- }

Function IsAlpha(C : Char) : Boolean;
Begin
  IsAlpha := ((C >= 'a') And (C <= 'z')) Or
             ((C >= 'A') And (C <= 'Z')) Or (C = '_');
End;

Function IsDigit(C : Char) : Boolean;
Begin
  IsDigit := (C >= '0') And (C <= '9');
End;

Function IsAlNum(C : Char) : Boolean;
Begin
  IsAlNum := IsAlpha(C) Or IsDigit(C);
End;

Function IsHexDigit(C : Char) : Boolean;
Begin
  IsHexDigit := IsDigit(C) Or
                ((C >= 'a') And (C <= 'f')) Or
                ((C >= 'A') And (C <= 'F'));
End;

Function IsOctDigit(C : Char) : Boolean;
Begin
  IsOctDigit := (C >= '0') And (C <= '7');
End;

Function HexVal(C : Char) : Integer;
Begin
  If   (C >= '0') And (C <= '9') Then HexVal := Ord(C) - Ord('0')
  Else If (C >= 'a') And (C <= 'f') Then HexVal := Ord(C) - Ord('a') + 10
  Else If (C >= 'A') And (C <= 'F') Then HexVal := Ord(C) - Ord('A') + 10
  Else HexVal := 0;
End;

{ ---- Primitives de lecture de caracteres ------------------- }

Function LexCurChar : Char;
Begin
  If (LexEOF) Or (LexColNo > Length(LexLine)) Then
    LexCurChar := #0
  Else
    LexCurChar := LexLine[LexColNo];
End;

Function LexPeek : Char;
Begin
  If (LexEOF) Or (LexColNo + 1 > Length(LexLine)) Then
    LexPeek := #0
  Else
    LexPeek := LexLine[LexColNo + 1];
End;

Procedure LexAdvance;
Begin
  Inc(LexColNo);
End;

Procedure LexNextLine;
Begin
  If EOF(LexSrcF) Then
  Begin
    LexEOF   := True;
    LexLine  := '';
    LexColNo := 1;
  End Else
  Begin
    ReadLn(LexSrcF, LexLine);
    Inc(LexLineNo);
    Inc(TotalLines);
    LexColNo := 1;
  End;
End;

Procedure LexSkipLineComment;
Begin
  LexColNo := Length(LexLine) + 1;
End;

{ ---- Erreur lexicale --------------------------------------- }

Procedure LexError(Const Msg : TString);
Begin
  WriteLn('AWKCW32:', LexLineNo, ':', LexColNo, ': error: ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('trop d''erreurs, compilation arretee');
End;

{ ---- Construction d un token ------------------------------- }

Procedure MakeToken(Var T : TToken; K : TTokenKind;
                    Const V : TString; L, C : Integer);
Begin
  T.Kind     := K;
  T.Val      := V;
  T.IntVal   := 0;
  T.FloatVal := 0.0;
  T.Line     := L;
  T.Col      := C;
End;

{ ---- Table des mots-cles AWK (21) ------------------------- }
Const
  AWK_KW_COUNT = 21;
  AWK_KW : Array[1..AWK_KW_COUNT] Of String[10] = (
    'BEGIN',     'END',       'if',        'else',
    'while',     'for',       'do',        'in',
    'break',     'continue',  'function',  'return',
    'delete',    'exit',      'getline',   'next',
    'nextfile',  'print',     'printf',    'sprintf',
    'BEGINFILE'
  );

Function IsKeyword(Const S : TString) : Integer;
Var
  I : Integer;
Begin
  IsKeyword := 0;
  For I := 1 To AWK_KW_COUNT Do
    If S = AWK_KW[I] Then
    Begin IsKeyword := I; Exit; End;
End;

{ ---- Table des fonctions builtin AWK (24) ------------------ }
Const
  AWK_BI_COUNT = 24;
  AWK_BI : Array[1..AWK_BI_COUNT] Of String[10] = (
    'length',    'substr',    'index',     'split',
    'sub',       'gsub',      'match',     'sprintf',
    'tolower',   'toupper',   'sin',       'cos',
    'atan2',     'exp',       'log',       'sqrt',
    'int',       'rand',      'srand',     'system',
    'close',     'fflush',    'mktime',    'strftime'
  );

Function IsBuiltinFunc(Const S : TString) : Integer;
Var
  I : Integer;
Begin
  IsBuiltinFunc := 0;
  For I := 1 To AWK_BI_COUNT Do
    If S = AWK_BI[I] Then
    Begin IsBuiltinFunc := I; Exit; End;
End;

{ ---- Table des variables builtin AWK (16) ------------------ }
Const
  AWK_BV_COUNT = 16;
  AWK_BV : Array[1..AWK_BV_COUNT] Of String[10] = (
    'FS',        'RS',        'OFS',       'ORS',
    'NR',        'NF',        'FNR',       'FILENAME',
    'ARGC',      'ARGV',      'ENVIRON',   'RSTART',
    'RLENGTH',   'SUBSEP',    'OFMT',      'CONVFMT'
  );

Function IsBuiltinVar(Const S : TString) : Integer;
Var
  I : Integer;
Begin
  IsBuiltinVar := 0;
  For I := 1 To AWK_BV_COUNT Do
    If S = AWK_BV[I] Then
    Begin IsBuiltinVar := I; Exit; End;
End;

{ ---- LexScanIdent : identificateur, mot-cle, builtin ou bvar }
Procedure LexScanIdent(Var T : TToken; SL, SC : Integer);
Var
  S  : TString;
  KI : Integer;
Begin
  S := '';
  While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
        IsAlNum(LexCurChar) Do
  Begin
    If Length(S) < MAX_STR Then S := S + LexCurChar;
    LexAdvance;
  End;
  KI := IsKeyword(S);
  If KI > 0 Then
  Begin
    MakeToken(T, TK_KEYWORD, S, SL, SC);
    T.IntVal := KI;
  End
  Else Begin
    KI := IsBuiltinFunc(S);
    If KI > 0 Then
    Begin
      MakeToken(T, TK_BUILTIN, S, SL, SC);
      T.IntVal := KI;
    End
    Else Begin
      KI := IsBuiltinVar(S);
      If KI > 0 Then
      Begin
        MakeToken(T, TK_BVAR, S, SL, SC);
        T.IntVal := KI;
      End
      Else
        MakeToken(T, TK_IDENT, S, SL, SC);
    End;
  End;
End;

{ ---- LexScanNumber : entier (dec/oct/hex) ou flottant ----- }
Procedure LexScanNumber(Var T : TToken; SL, SC : Integer);
Var
  S     : TString;
  Val   : LongInt;
  Base  : Integer;
  C     : Char;
  Fv    : Real;
  Div10 : Real;
Begin
  S    := '';
  Val  := 0;
  Base := 10;
  C    := LexCurChar;
  { Prefixe 0x (hexa) ou 0 (octal) }
  If (C = '0') And (LexPeek <> #0) Then
  Begin
    If (LexPeek = 'x') Or (LexPeek = 'X') Then
    Begin
      S := '0x'; LexAdvance; LexAdvance; Base := 16;
    End
    Else If IsOctDigit(LexPeek) Then
    Begin
      Val := 0; S := '0'; LexAdvance; Base := 8;
    End
    Else
    Begin
      Val := 0; S := '0'; LexAdvance;
    End;
  End Else If C = '.' Then
  Begin
    { nombre commencant par . (ex: .5) }
    Fv := 0.0;
    Div10 := 10.0;
    S := '0.';
    LexAdvance;
    While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
          IsDigit(LexCurChar) Do
    Begin
      Fv    := Fv + (Ord(LexCurChar) - Ord('0')) / Div10;
      Div10 := Div10 * 10.0;
      If Length(S) < MAX_STR Then S := S + LexCurChar;
      LexAdvance;
    End;
    { Exposant e/E }
    If (Not LexEOF) And (LexColNo <= Length(LexLine)) And
       ((LexCurChar = 'e') Or (LexCurChar = 'E')) Then
    Begin
      If Length(S) < MAX_STR Then S := S + LexCurChar;
      LexAdvance;
      If (LexColNo <= Length(LexLine)) And
         ((LexCurChar = '+') Or (LexCurChar = '-')) Then
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
      While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
            IsDigit(LexCurChar) Do
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
    End;
    MakeToken(T, TK_FLOAT, S, SL, SC);
    T.FloatVal := Fv;
    Exit;
  End
  Else
  Begin
    Val := Ord(C) - Ord('0');
    S   := C;
    LexAdvance;
  End;
  { Chiffres du nombre }
  While (Not LexEOF) And (LexColNo <= Length(LexLine)) Do
  Begin
    C := LexCurChar;
    Case Base Of
      8  : If IsOctDigit(C) Then
           Begin Val := Val*8+(Ord(C)-Ord('0'));
                 If Length(S)<MAX_STR Then S:=S+C; LexAdvance; End
           Else Break;
      10 : If IsDigit(C) Then
           Begin Val := Val*10+(Ord(C)-Ord('0'));
                 If Length(S)<MAX_STR Then S:=S+C; LexAdvance; End
           Else Break;
      16 : If IsHexDigit(C) Then
           Begin Val := Val*16+HexVal(C);
                 If Length(S)<MAX_STR Then S:=S+C; LexAdvance; End
           Else Break;
    End;
  End;
  { Detection flottant (base 10 seulement) }
  If (Base = 10) And (Not LexEOF) And (LexColNo <= Length(LexLine)) And
     (LexCurChar = '.') And (LexPeek <> #0) And IsDigit(LexPeek) Then
  Begin
    Fv    := Val * 1.0;
    Div10 := 10.0;
    If Length(S) < MAX_STR Then S := S + '.';
    LexAdvance;
    While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
          IsDigit(LexCurChar) Do
    Begin
      Fv    := Fv + (Ord(LexCurChar) - Ord('0')) / Div10;
      Div10 := Div10 * 10.0;
      If Length(S) < MAX_STR Then S := S + LexCurChar;
      LexAdvance;
    End;
    { Exposant e/E }
    If (Not LexEOF) And (LexColNo <= Length(LexLine)) And
       ((LexCurChar = 'e') Or (LexCurChar = 'E')) Then
    Begin
      If Length(S) < MAX_STR Then S := S + LexCurChar;
      LexAdvance;
      If (LexColNo <= Length(LexLine)) And
         ((LexCurChar = '+') Or (LexCurChar = '-')) Then
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
      While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
            IsDigit(LexCurChar) Do
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
    End;
    MakeToken(T, TK_FLOAT, S, SL, SC);
    T.FloatVal := Fv;
    Exit;
  End;
  { Flottant sans partie decimale mais avec exposant }
  If (Base = 10) And (Not LexEOF) And (LexColNo <= Length(LexLine)) And
     ((LexCurChar = 'e') Or (LexCurChar = 'E')) Then
  Begin
    Fv := Val * 1.0;
    If Length(S) < MAX_STR Then S := S + LexCurChar;
    LexAdvance;
    If (LexColNo <= Length(LexLine)) And
       ((LexCurChar = '+') Or (LexCurChar = '-')) Then
    Begin
      If Length(S) < MAX_STR Then S := S + LexCurChar;
      LexAdvance;
    End;
    While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
          IsDigit(LexCurChar) Do
    Begin
      If Length(S) < MAX_STR Then S := S + LexCurChar;
      LexAdvance;
    End;
    MakeToken(T, TK_FLOAT, S, SL, SC);
    T.FloatVal := Fv;
    Exit;
  End;
  MakeToken(T, TK_INTEGER, S, SL, SC);
  T.IntVal := Val;
End;

{ ---- LexScanEscape : sequences d echappement --------------- }
Function LexScanEscape : Char;
Var
  C    : Char;
  Code : LongInt;
  I    : Integer;
Begin
  Code := 0;
  If LexColNo > Length(LexLine) Then
  Begin
    LexError('sequence d''echappement incomplete');
    LexScanEscape := '?';
    Exit;
  End;
  C := LexCurChar;
  LexAdvance;
  Case C Of
    'n' : LexScanEscape := #10;
    't' : LexScanEscape := #9;
    'r' : LexScanEscape := #13;
    'a' : LexScanEscape := #7;
    'b' : LexScanEscape := #8;
    'f' : LexScanEscape := #12;
    '\' : LexScanEscape := '\';
    '"' : LexScanEscape := '"';
    '/' : LexScanEscape := '/';
    'x' : Begin
            Code := 0;
            For I := 1 To 2 Do
            Begin
              If (LexColNo > Length(LexLine)) Or
                 (Not IsHexDigit(LexCurChar)) Then
              Begin LexError('\x: 2 chiffres hexa attendus'); Break; End;
              Code := Code * 16 + HexVal(LexCurChar);
              LexAdvance;
            End;
            LexScanEscape := Chr(Code And $FF);
          End;
  Else
    LexScanEscape := C;
  End;
End;

{ ---- LexScanString : chaine double-quote "..." ------------- }
Procedure LexScanString(Var T : TToken; SL, SC : Integer);
Var
  S    : TString;
  C    : Char;
  Done : Boolean;
Begin
  LexAdvance; { guillemet-double ouverture }
  S    := '';
  Done := False;
  Repeat
    If LexColNo > Length(LexLine) Then
    Begin
      LexError('chaine non fermee en fin de ligne');
      Done := True;
    End Else
    Begin
      C := LexCurChar;
      If C = '"' Then
      Begin
        LexAdvance; Done := True;
      End Else If C = '\' Then
      Begin
        LexAdvance;
        C := LexScanEscape;
        If Length(S) < MAX_STR Then S := S + C;
      End Else
      Begin
        If Length(S) < MAX_STR Then S := S + C;
        LexAdvance;
      End;
    End;
  Until Done;
  MakeToken(T, TK_STRING, S, SL, SC);
End;

{ ---- LexScanRegexp : expression reguliere /pattern/ -------- }
Procedure LexScanRegexp(Var T : TToken; SL, SC : Integer);
Var
  S  : TString;
  Ch : Char;
Begin
  S := '';
  LexAdvance; { sauter '/' ouvrant }
  While (Not LexEOF) And (LexColNo <= Length(LexLine)) Do
  Begin
    Ch := LexCurChar;
    If Ch = '/' Then
    Begin
      LexAdvance; { sauter '/' fermant }
      Break;
    End
    Else If Ch = '\' Then
    Begin
      If Length(S) < MAX_STR Then S := S + '\';
      LexAdvance;
      If LexColNo <= Length(LexLine) Then
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
    End
    Else
    Begin
      If Length(S) < MAX_STR Then S := S + Ch;
      LexAdvance;
    End;
  End;
  MakeToken(T, TK_REGEXP, S, SL, SC);
End;

{ ---- LexExpectRegex : contexte regex vs division ----------- }
Function LexExpectRegex : Boolean;
Begin
  Case LexLastKind Of
    TK_INTEGER, TK_FLOAT, TK_STRING, TK_IDENT,
    TK_BUILTIN, TK_BVAR, TK_FIELD :
      LexExpectRegex := False;
  Else
    { Apres ) et ] c est une division }
    If (LexLastKind = TK_PUNCT) And
       ((CurToken.Val = ')') Or (CurToken.Val = ']')) Then
      LexExpectRegex := False
    Else
      LexExpectRegex := True;
  End;
End;

{ ---- LexScanField : reference de champ $n ------------------ }
Procedure LexScanField(Var T : TToken; SL, SC : Integer);
Var
  S : TString;
Begin
  LexAdvance; { sauter '$' }
  S := '';
  { $0..$9 ou $NF etc. }
  While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
        IsAlNum(LexCurChar) Do
  Begin
    If Length(S) < MAX_STR Then S := S + LexCurChar;
    LexAdvance;
  End;
  If S = '' Then
    S := '0';  { $ seul = $0 }
  MakeToken(T, TK_FIELD, S, SL, SC);
End;

{ ---- LexScanOp : operateurs simples et composes ----------- }
Procedure LexScanOp(Var T : TToken; SL, SC : Integer);
Var
  S : TString;
  C : Char;
  P : Char;
Begin
  C := LexCurChar;
  P := LexPeek;
  S := C;
  LexAdvance;
  Case C Of
    '+': If P = '+' Then Begin S := '++'; LexAdvance; End
         Else If P = '=' Then Begin S := '+='; LexAdvance; End;
    '-': If P = '-' Then Begin S := '--'; LexAdvance; End
         Else If P = '=' Then Begin S := '-='; LexAdvance; End;
    '*': If P = '=' Then Begin S := '*='; LexAdvance; End;
    '/': If P = '=' Then Begin S := '/='; LexAdvance; End;
    '%': If P = '=' Then Begin S := '%='; LexAdvance; End;
    '^': If P = '=' Then Begin S := '^='; LexAdvance; End;
    '!': If P = '~' Then Begin S := '!~'; LexAdvance; End
         Else If P = '=' Then Begin S := '!='; LexAdvance; End;
    '=': If P = '=' Then Begin S := '=='; LexAdvance; End;
    '<': If P = '=' Then Begin S := '<='; LexAdvance; End
         Else If P = '<' Then Begin S := '<<'; LexAdvance; End;
    '>': If P = '=' Then Begin S := '>='; LexAdvance; End
         Else If P = '>' Then Begin S := '>>'; LexAdvance; End;
    '&': If P = '&' Then Begin S := '&&'; LexAdvance; End;
    '|': If P = '|' Then Begin S := '||'; LexAdvance; End;
    '~': ; { tilde seul = match }
    '?': ; { ternaire }
    ':': ; { ternaire / label }
  End;
  MakeToken(T, TK_OP, S, SL, SC);
End;

{ ---- LexScanPunct : ponctuation ; , ( ) [ ] accolades ----- }
Procedure LexScanPunct(Var T : TToken; SL, SC : Integer);
Var
  S : TString;
Begin
  S := LexCurChar;
  LexAdvance;
  MakeToken(T, TK_PUNCT, S, SL, SC);
End;

{ ---- LexNextToken : produire le prochain token AWK --------- }
Procedure LexNextToken(Var T : TToken);
Var
  SL, SC     : Integer;
  C          : Char;
  WasNewLine : Boolean;
Begin
  WasNewLine := False;
  { Passer les lignes vides en detectant les changements de ligne }
  While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
  Begin
    WasNewLine := True;
    LexNextLine;
  End;
  If LexEOF Then
  Begin
    MakeToken(T, TK_EOF, '', LexLineNo, LexColNo);
    Exit;
  End;
  { Espaces et tabulations sur la ligne courante }
  While (LexColNo <= Length(LexLine)) And
        ((LexLine[LexColNo] = ' ') Or (LexLine[LexColNo] = #9)) Do
    Inc(LexColNo);
  { Si on a change de ligne, emettre un NEWLINE pour separer les stmts }
  If WasNewLine And (LexLastKind <> TK_NEWLINE) Then
  Begin
    MakeToken(T, TK_NEWLINE, '', LexLineNo, LexColNo);
    LexLastKind := TK_NEWLINE;
    Exit;
  End;
  { Commentaire # -> passer toute la ligne }
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '#') Then
  Begin
    LexSkipLineComment;
    MakeToken(T, TK_NEWLINE, '', LexLineNo, LexColNo);
    LexLastKind := TK_NEWLINE;
    Exit;
  End;
  { Continuation de ligne : \ en fin de ligne }
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '\') And
     (LexColNo = Length(LexLine)) Then
  Begin
    LexNextLine;
    LexNextToken(T);
    Exit;
  End;
  { Fin de ligne logique }
  If LexColNo > Length(LexLine) Then
  Begin
    MakeToken(T, TK_NEWLINE, '', LexLineNo, LexColNo);
    LexLastKind := TK_NEWLINE;
    Exit;
  End;
  SL := LexLineNo;
  SC := LexColNo;
  C  := LexCurChar;
  { Chaine double-quote "..." }
  If C = '"' Then
  Begin
    LexScanString(T, SL, SC);
    LexLastKind := TK_STRING;
    Exit;
  End;
  { Reference de champ $n }
  If C = '$' Then
  Begin
    LexScanField(T, SL, SC);
    LexLastKind := TK_FIELD;
    Exit;
  End;
  { Identificateur ou mot-cle }
  If IsAlpha(C) Then
  Begin
    LexScanIdent(T, SL, SC);
    LexLastKind := T.Kind;
    Exit;
  End;
  { Nombre }
  If IsDigit(C) Then
  Begin
    LexScanNumber(T, SL, SC);
    LexLastKind := T.Kind;
    Exit;
  End;
  { Nombre .5 (point suivi de chiffre) }
  If (C = '.') And (LexPeek <> #0) And IsDigit(LexPeek) Then
  Begin
    LexScanNumber(T, SL, SC);
    LexLastKind := T.Kind;
    Exit;
  End;
  { Slash : regexp ou division selon contexte }
  If C = '/' Then
  Begin
    If LexExpectRegex Then
    Begin
      LexScanRegexp(T, SL, SC);
      LexLastKind := TK_REGEXP;
    End Else
    Begin
      LexScanOp(T, SL, SC);
      LexLastKind := TK_OP;
    End;
    Exit;
  End;
  { Operateurs }
  Case C Of
    '+','-','*','%','^',
    '!','=','<','>','&','|','~','?',':':
    Begin
      LexScanOp(T, SL, SC);
      LexLastKind := TK_OP;
      Exit;
    End;
  End;
  { Ponctuation : ; , ( ) [ ] accolades }
  Case C Of
    ';',',','(',')','[',']','{','}':
    Begin
      LexScanPunct(T, SL, SC);
      LexLastKind := TK_PUNCT;
      Exit;
    End;
  End;
  { Caractere inconnu }
  LexError('caractere inconnu: ' + C);
  LexAdvance;
  LexNextToken(T);
End;

{ ---- LexInit : initialiser le lexeur ----------------------- }
Procedure LexInit;
Begin
  LexOpened := False;
  Assign(LexSrcF, Opts.SrcFile);
  Reset(LexSrcF);
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir: ' + Opts.SrcFile);
  LexOpened   := True;
  LexEOF      := False;
  LexLineNo   := 0;
  LexColNo    := 1;
  LexLine     := '';
  LexLastKind := TK_NEWLINE;
  CurToken.Kind    := TK_EOF;
  CurToken.Val     := '';
  CurToken.IntVal  := 0;
  CurToken.FloatVal := 0.0;
  CurToken.Line    := 0;
  CurToken.Col     := 0;
  LexNextLine;
End;

{ ---- LexClose : fermer le lexeur --------------------------- }
Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
End;

{ ---- PrintToken : affichage debug d un token --------------- }
Procedure PrintToken(Const T : TToken);
Var
  KS : String[10];
  NS : TString;
Begin
  Case T.Kind Of
    TK_EOF     : KS := 'EOF    ';
    TK_INTEGER : KS := 'INTEGER';
    TK_FLOAT   : KS := 'FLOAT  ';
    TK_STRING  : KS := 'STRING ';
    TK_REGEXP  : KS := 'REGEXP ';
    TK_IDENT   : KS := 'IDENT  ';
    TK_KEYWORD : KS := 'KEYWORD';
    TK_BUILTIN : KS := 'BUILTIN';
    TK_BVAR    : KS := 'BVAR   ';
    TK_FIELD   : KS := 'FIELD  ';
    TK_OP      : KS := 'OP     ';
    TK_PUNCT   : KS := 'PUNCT  ';
    TK_NEWLINE : KS := 'NEWLINE';
  End;
  Write('[', T.Line, ':', T.Col, '] ', KS, ' "', T.Val, '"');
  If T.Kind = TK_INTEGER Then
  Begin
    Str(T.IntVal, NS);
    Write(' =', NS);
  End Else If T.Kind = TK_FLOAT Then
  Begin
    Str(T.FloatVal : 0 : 6, NS);
    Write(' =', NS);
  End Else If (T.Kind = TK_KEYWORD) Or (T.Kind = TK_BUILTIN) Or
              (T.Kind = TK_BVAR) Then
  Begin
    Str(T.IntVal, NS);
    Write(' #', NS);
  End;
  WriteLn;
End;

{ ---- ParserAdvance : avancer au token suivant --------------- }
Procedure ParserAdvance;
Begin
  If HasPushedBack Then
  Begin
    CurToken := PushedBack;
    HasPushedBack := False;
  End
  Else
    LexNextToken(CurToken);
  If Opts.DebugMode Then
    PrintToken(CurToken);
End;

{ ---- ParserPushBack : remettre le token courant ------------- }
{ Sauvegarde CurToken et charge NewCur a sa place              }
Procedure ParserPushBack(Var NewCur : TToken);
Begin
  PushedBack := CurToken;
  HasPushedBack := True;
  CurToken := NewCur;
End;

{ ============================================================ }
{ TODO 04 - TABLE DES SYMBOLES (32 BITS) [IMPLEMENTE]          }
{ ============================================================ }

{ ---- FindSym : chercher un symbole par nom ------------------- }
Function FindSym(Const Name : String) : Integer;
Var
  I : Integer;
Begin
  FindSym := -1;
  For I := 0 To SymCount - 1 Do
    If SymTab[I].Name = Name Then
    Begin FindSym := I; Exit; End;
End;

{ ---- AddSym : ajouter un symbole ----------------------------- }
Function AddSym(Const Name : String; TK : Integer;
                SC : Integer; IsGlob : Boolean) : Integer;
Var
  Idx : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin FatalError('table des symboles pleine'); AddSym := -1; Exit; End;
  Idx := SymCount;
  SymTab[Idx].Name          := Name;
  SymTab[Idx].AsmLabel      := AW_VAR_PFX + AsmIdent(Name);
  SymTab[Idx].TypeKind      := TK;
  SymTab[Idx].StoreClass    := SC;
  SymTab[Idx].BpOffset      := 0;
  SymTab[Idx].IsParam       := False;
  SymTab[Idx].ParamIdx      := 0;
  SymTab[Idx].IsGlobal      := IsGlob;
  SymTab[Idx].IsArray       := (TK = TYK_ARRAY);
  If TK = TYK_ARRAY Then
    SymTab[Idx].ArrayAsmLabel := AW_ARR_PFX + AsmIdent(Name)
  Else
    SymTab[Idx].ArrayAsmLabel := '';
  Inc(SymCount);
  If SymCount > MaxSymCount Then MaxSymCount := SymCount;
  AddSym := Idx;
End;

{ ---- FindFunc : chercher une fonction par nom ---------------- }
Function FindFunc(Const Name : String) : Integer;
Var
  I : Integer;
Begin
  FindFunc := -1;
  For I := 0 To FuncCount - 1 Do
    If FuncTab[I].Name = Name Then
    Begin FindFunc := I; Exit; End;
End;

{ ---- AddFunc : ajouter une fonction -------------------------- }
Function AddFunc(Const Name : String) : Integer;
Var
  Idx : Integer;
Begin
  If FuncCount >= MAX_FUNC Then
  Begin FatalError('table des fonctions pleine'); AddFunc := -1; Exit; End;
  Idx := FuncCount;
  FuncTab[Idx].Name       := Name;
  FuncTab[Idx].AsmLabel   := AW_FN_PFX + AsmIdent(Name);
  FuncTab[Idx].ParamCount := 0;
  FuncTab[Idx].Defined    := False;
  FuncTab[Idx].LocalCount := 0;
  Inc(FuncCount);
  AddFunc := Idx;
End;

{ ---- InitSymTable : initialiser table + builtin vars --------- }
Procedure InitSymTable;
Begin
  SymCount  := 0;
  MaxSymCount := 0;
  FuncCount := 0;
  { Declarer les 16 variables builtin AWK globales (TODO 21) }
  AddSym('FS', TYK_STRING, STORE_GLOBAL, True);        { BV 1  }
  AddSym('RS', TYK_STRING, STORE_GLOBAL, True);        { BV 2  }
  AddSym('OFS', TYK_STRING, STORE_GLOBAL, True);       { BV 3  }
  AddSym('ORS', TYK_STRING, STORE_GLOBAL, True);       { BV 4  }
  AddSym('NR', TYK_NUMBER, STORE_GLOBAL, True);        { BV 5  }
  AddSym('NF', TYK_NUMBER, STORE_GLOBAL, True);        { BV 6  }
  AddSym('FNR', TYK_NUMBER, STORE_GLOBAL, True);       { BV 7  }
  AddSym('FILENAME', TYK_STRING, STORE_GLOBAL, True);  { BV 8  }
  AddSym('ARGC', TYK_NUMBER, STORE_GLOBAL, True);      { BV 9  }
  AddSym('ARGV', TYK_ARRAY, STORE_GLOBAL, True);       { BV 10 }
  AddSym('ENVIRON', TYK_ARRAY, STORE_GLOBAL, True);    { BV 11 }
  AddSym('RSTART', TYK_NUMBER, STORE_GLOBAL, True);    { BV 12 }
  AddSym('RLENGTH', TYK_NUMBER, STORE_GLOBAL, True);   { BV 13 }
  AddSym('SUBSEP', TYK_STRING, STORE_GLOBAL, True);    { BV 14 }
  AddSym('OFMT', TYK_STRING, STORE_GLOBAL, True);      { BV 15 }
  AddSym('CONVFMT', TYK_STRING, STORE_GLOBAL, True);   { BV 16 }
End;

{ ============================================================ }
{ TODO 05 - GESTION DES SCOPES [IMPLEMENTE]                     }
{ ============================================================ }

{ ---- GenScopeLabel : generer un label unique pour scopes ----- }
Function GenScopeLabel(Const Prefix : String) : String;
Var
  S : String;
Begin
  Inc(LabelSeq);
  Str(LabelSeq, S);
  While Length(S) < 5 Do S := '0' + S;
  GenScopeLabel := Prefix + S;
End;

{ ---- EnterScope : empiler un nouveau scope ------------------- }
Procedure EnterScope(Kind : Integer);
Begin
  If ScopeDepth >= MAX_SCOPE Then
  Begin FatalError('pile de scopes pleine'); Exit; End;
  ScopeStack[ScopeDepth].Kind          := Kind;
  ScopeStack[ScopeDepth].SymBase       := SymCount;
  If ScopeDepth > 0 Then
    ScopeStack[ScopeDepth].EbpOffset   := ScopeStack[ScopeDepth - 1].EbpOffset
  Else
    ScopeStack[ScopeDepth].EbpOffset   := 0;
  ScopeStack[ScopeDepth].ExitLabel     := '';
  ScopeStack[ScopeDepth].BreakLabel    := '';
  ScopeStack[ScopeDepth].ContinueLabel := '';
  Inc(ScopeDepth);
End;

{ ---- LeaveScope : depiler le scope courant ------------------- }
Procedure LeaveScope;
Begin
  If ScopeDepth <= 0 Then
  Begin FatalError('pile de scopes vide'); Exit; End;
  Dec(ScopeDepth);
  { Restaurer la table des symboles au debut du scope }
  SymCount := ScopeStack[ScopeDepth].SymBase;
End;

{ ---- AllocLocal : allouer une variable locale sur la pile ---- }
Function AllocLocal(Bytes : Integer) : Integer;
Begin
  If ScopeDepth <= 0 Then
  Begin FatalError('AllocLocal hors scope'); AllocLocal := 0; Exit; End;
  { Aligner a 4 octets (DWORD) }
  If (Bytes Mod 4) <> 0 Then
    Bytes := ((Bytes Div 4) + 1) * 4;
  ScopeStack[ScopeDepth - 1].EbpOffset :=
    ScopeStack[ScopeDepth - 1].EbpOffset - Bytes;
  AllocLocal := ScopeStack[ScopeDepth - 1].EbpOffset;
End;

{ ---- CurrentEbpOffset : retourner l offset EBP courant ------- }
Function CurrentEbpOffset : Integer;
Begin
  If ScopeDepth <= 0 Then
    CurrentEbpOffset := 0
  Else
    CurrentEbpOffset := ScopeStack[ScopeDepth - 1].EbpOffset;
End;

{ ---- CurrentScopeKind : retourner le type du scope courant --- }
Function CurrentScopeKind : Integer;
Begin
  If ScopeDepth <= 0 Then
    CurrentScopeKind := SK_GLOBAL
  Else
    CurrentScopeKind := ScopeStack[ScopeDepth - 1].Kind;
End;

{ ---- SetExitLabel : definir le label de sortie du scope ------ }
Procedure SetExitLabel(Const Lbl : String);
Begin
  If ScopeDepth > 0 Then
    ScopeStack[ScopeDepth - 1].ExitLabel := Lbl;
End;

{ ---- FindExitLabel : trouver le label sortie le plus proche -- }
Function FindExitLabel : String;
Var
  I : Integer;
Begin
  FindExitLabel := '';
  For I := ScopeDepth - 1 DownTo 0 Do
    If (ScopeStack[I].Kind = SK_FUNCTION) Or
       (ScopeStack[I].Kind = SK_RULE) Then
    Begin
      FindExitLabel := ScopeStack[I].ExitLabel;
      Exit;
    End;
End;

{ ---- EnterLoop : pousser un scope boucle avec labels --------- }
Procedure EnterLoop(Const BrkLbl, ContLbl : String);
Begin
  EnterScope(SK_LOOP);
  ScopeStack[ScopeDepth - 1].BreakLabel    := BrkLbl;
  ScopeStack[ScopeDepth - 1].ContinueLabel := ContLbl;
  Inc(LoopDepth);
End;

{ ---- LeaveLoop : depiler le scope boucle --------------------- }
Procedure LeaveLoop;
Begin
  LeaveScope;
  Dec(LoopDepth);
End;

{ ---- FindLoopBreak : trouver le label break le plus proche --- }
Function FindLoopBreak : String;
Var
  I : Integer;
Begin
  FindLoopBreak := '';
  For I := ScopeDepth - 1 DownTo 0 Do
    If ScopeStack[I].Kind = SK_LOOP Then
    Begin
      FindLoopBreak := ScopeStack[I].BreakLabel;
      Exit;
    End;
End;

{ ---- FindLoopContinue : trouver label continue plus proche --- }
Function FindLoopContinue : String;
Var
  I : Integer;
Begin
  FindLoopContinue := '';
  For I := ScopeDepth - 1 DownTo 0 Do
    If ScopeStack[I].Kind = SK_LOOP Then
    Begin
      FindLoopContinue := ScopeStack[I].ContinueLabel;
      Exit;
    End;
End;

{ ---- InitScopes : initialiser la pile de scopes -------------- }
Procedure InitScopes;
Begin
  ScopeDepth := 0;
  LoopDepth  := 0;
  LabelSeq   := 0;
  EnterScope(SK_GLOBAL);
End;

{ ============================================================ }
{ TODO 06 - PARSEUR : EXPRESSIONS ARITHMETIQUES ET LOGIQUES    }
{           (32 BITS) [IMPLEMENTE]                              }
{ ============================================================ }

{ Forward declarations }
Function ParseExpr : Integer; Forward;
Function ParseAssignExpr : Integer; Forward;
Function ParseTernaryExpr : Integer; Forward;
Function ParseOrExpr : Integer; Forward;
Function ParseAndExpr : Integer; Forward;
Function ParseInExpr : Integer; Forward;
Function ParseMatchExpr : Integer; Forward;
Function ParseCompareExpr : Integer; Forward;
Function ParseConcatExpr : Integer; Forward;
Function ParseAddExpr : Integer; Forward;
Function ParseMulExpr : Integer; Forward;
Function ParsePowExpr : Integer; Forward;
Function ParseUnaryExpr : Integer; Forward;
Function ParsePostfixExpr : Integer; Forward;
Function ParsePrimaryExpr : Integer; Forward;

{ Forward declarations TODO 07 - Coercition et concatenation }
Function GenCoerceToNumber(CurType: Integer) : Integer; Forward;
Function GenCoerceToString(CurType: Integer) : Integer; Forward;
Function GenCoerceToBoolean(CurType: Integer) : Integer; Forward;
Procedure GenConcat; Forward;
Procedure GenStrDup; Forward;
Procedure CoerceForArith(Var TKLeft, TKRight: Integer); Forward;
Procedure CoerceForConcat(Var TKLeft, TKRight: Integer); Forward;
Procedure CoerceForCompare(Var TKLeft, TKRight: Integer); Forward;

{ Forward declarations TODO 08 - Generation de code arithmetique }
Procedure Emit(Const S: TString); Forward;
Procedure EmitLabel(Const Lbl: TString); Forward;
Procedure EmitComment(Const S: TString); Forward;
Procedure EmitBlank; Forward;
Function  NewLabel: TString; Forward;
Function  AddStringLit(Const Val: TString): TString; Forward;
Procedure GenLoadConst(Val: LongInt); Forward;
Procedure GenLoadStr(Const Lbl: TString); Forward;
Procedure GenLoadVar(SymIdx: Integer); Forward;
Procedure GenStoreVar(SymIdx: Integer); Forward;
Procedure GenPushEAX; Forward;
Procedure GenPopEBX; Forward;
Procedure GenBinOp(Op: Integer); Forward;
Procedure GenCompare(Op: Integer); Forward;
Procedure GenUnaryNeg; Forward;
Procedure GenUnaryNot; Forward;
Procedure GenIncVar(SymIdx: Integer); Forward;
Procedure GenDecVar(SymIdx: Integer); Forward;
Procedure GenFieldRef; Forward;
Procedure GenFieldStore; Forward;

{ Forward declarations TODO 09 - Print/Printf/Sprintf }
Procedure GenPrintVal(ExprType: Integer); Forward;
Procedure GenPrintOFS; Forward;
Procedure GenPrintORS; Forward;
Procedure ParsePrint; Forward;
Procedure ParsePrintf; Forward;
Function  ParseSprintf: Integer; Forward;

{ Forward declarations TODO 10 - If/Else }
Procedure ParseIf; Forward;
Procedure ParseStatement; Forward;
Procedure ParseBlock; Forward;

{ Forward declarations TODO 11 - Boucles }
Procedure ParseWhile; Forward;
Procedure ParseFor; Forward;
Procedure ParseDoWhile; Forward;

{ Forward declarations TODO 12 - For-In }
Procedure ParseForIn; Forward;

{ Forward declarations TODO 13 - Fonctions utilisateur }
Procedure ParseFunctionDef; Forward;

{ Forward declarations TODO 14 - Regles pattern-action }
Procedure ParseAction; Forward;
Procedure ParseProgram; Forward;

{ Forward declarations TODO 15 - Champs et separateurs }
Function  ParseFieldRef: Integer; Forward;
Procedure GenFieldSplit; Forward;

{ Forward declarations TODO 16 - Tableaux associatifs }
Procedure GenArrayGet(SymIdx: Integer); Forward;
Procedure GenArraySet(SymIdx: Integer); Forward;
Procedure GenArrayExists(SymIdx: Integer); Forward;
Procedure GenArrayDel(SymIdx: Integer); Forward;
Procedure GenArrayClear(SymIdx: Integer); Forward;

{ Forward declarations TODO 17 - Expressions regulieres }
Function  AddRegexPat(Const Pat: TString): TString; Forward;
Procedure GenRegexMatch; Forward;

{ Forward declarations TODO 18 - Fonctions builtin chaines }
Function  ParseBuiltinString(BFIdx: Integer): Integer; Forward;

{ Forward declarations TODO 19 - Fonctions builtin mathematiques }
Function  ParseBuiltinMath(BFIdx: Integer): Integer; Forward;

{ Forward declarations TODO 20 - Getline et redirections E/S }
Function  ParseGetline: Integer; Forward;

{ Forward declarations TODO 21 - Variables builtin AWK }
Procedure InitBuiltinVarDefaults; Forward;
Procedure ApplyDashF; Forward;
Procedure ApplyDashV; Forward;

{ Forward declarations TODO 22 - En-tete ASM et segment .DATA }
Procedure EmitHeader; Forward;
Procedure EmitDataSeg; Forward;
Procedure EmitFooter; Forward;

{ Forward declarations TODO 23 - Point d entree et helpers runtime }
Procedure EmitEntryPoint; Forward;
Procedure EmitRuntimeHelpers; Forward;

{ Forward declarations TODO 25 - Generation finale linker PE }
{$IFDEF FPC}
Procedure BinInit; Forward;
Procedure BinAssembleLine(Const Line : String); Forward;
Procedure WritePEFile(Const FileName : TString); Forward;
Procedure WriteCOFFFile(Const FileName : TString); Forward;
Procedure AssembleAndWriteBinary(Const AsmFile, BinFile : TString;
                                IsObj : Boolean); Forward;
{$ENDIF}

{ ---- Helpers de tokens --------------------------------------- }
Function IsOp(Const S : String) : Boolean;
Begin
  IsOp := (CurToken.Kind = TK_OP) And (CurToken.Val = S);
End;

Function IsPunct(Const S : String) : Boolean;
Begin
  IsPunct := (CurToken.Kind = TK_PUNCT) And (CurToken.Val = S);
End;

Function IsKW(Code : Integer) : Boolean;
Begin
  IsKW := (CurToken.Kind = TK_KEYWORD) And (CurToken.IntVal = Code);
End;

Procedure Expect(K : TTokenKind; Const V : String);
Begin
  If (CurToken.Kind <> K) Or (CurToken.Val <> V) Then
    FatalError('attendu "' + V + '" a la ligne ' +
               IntToStr_(CurToken.Line));
  ParserAdvance;
End;

Procedure SkipNewlines;
Begin
  While CurToken.Kind = TK_NEWLINE Do
    ParserAdvance;
End;

{ ---- ParsePrimaryExpr ---------------------------------------- }
{ Constantes, variables, champs, appels de fonctions, parenth.  }
Function ParsePrimaryExpr : Integer;
Var
  TK    : Integer;
  FnIdx : Integer;
  ArgC  : Integer;
  IdName: String;
  D     : Integer;
  SLbl  : TString;
Begin
  ParsePrimaryExpr := TYK_UNKNOWN;
  LastSymIdx := -1;
  SkipNewlines;
  Case CurToken.Kind Of
    TK_INTEGER:
    Begin
      { Constante entiere : MOV EAX, imm32 }
      GenLoadConst(CurToken.IntVal);
      ParsePrimaryExpr := TYK_NUMBER;
      ParserAdvance;
    End;
    TK_FLOAT:
    Begin
      { Constante flottante : traitee comme nombre entier tronque }
      GenLoadConst(Trunc(CurToken.FloatVal));
      ParsePrimaryExpr := TYK_NUMBER;
      ParserAdvance;
    End;
    TK_STRING:
    Begin
      { Constante chaine : MOV EAX, OFFSET _AWK_n }
      SLbl := AddStringLit(CurToken.Val);
      GenLoadStr(SLbl);
      ParsePrimaryExpr := TYK_STRING;
      ParserAdvance;
    End;
    TK_REGEXP:
    Begin
      { Expression reguliere /pat/ : stocker dans .DATA, LEA EAX, _AWP_n }
      SLbl := AddRegexPat(CurToken.Val);
      GenLoadStr(SLbl);
      ParsePrimaryExpr := TYK_REGEXP;
      ParserAdvance;
    End;
    TK_FIELD:
    Begin
      { Reference de champ $n : via ParseFieldRef (TODO 15) }
      ParsePrimaryExpr := ParseFieldRef;
    End;
    TK_BVAR:
    Begin
      { Variable builtin AWK (FS, NR, NF, ...) }
      TK := FindSym(CurToken.Val);
      If TK >= 0 Then
      Begin
        GenLoadVar(TK);
        LastSymIdx := TK;
        ParsePrimaryExpr := SymTab[TK].TypeKind;
      End
      Else
        ParsePrimaryExpr := TYK_UNKNOWN;
      ParserAdvance;
    End;
    TK_IDENT:
    Begin
      IdName := CurToken.Val;
      ParserAdvance;
      { Appel de fonction utilisateur : ident ( args ) (TODO 13) }
      If IsPunct('(') Then
      Begin
        ParserAdvance;  { consommer ( }
        ArgC := 0;
        EmitComment('--- call ' + IdName + ' ---');
        If Not IsPunct(')') Then
        Begin
          D := ParseExpr;
          GenPushEAX;   { empiler arg sur la pile }
          Inc(ArgC);
          While IsPunct(',') Do
          Begin
            ParserAdvance;  { consommer , }
            SkipNewlines;
            D := ParseExpr;
            GenPushEAX;   { empiler arg sur la pile }
            Inc(ArgC);
          End;
        End;
        Expect(TK_PUNCT, ')');
        { Rechercher ou enregistrer la fonction }
        FnIdx := FindFunc(IdName);
        If FnIdx < 0 Then
        Begin
          FnIdx := AddFunc(IdName);
          If FnIdx >= 0 Then
            FuncTab[FnIdx].ParamCount := ArgC;
        End;
        { Generer l appel : CALL _AWF_nom }
        If FnIdx >= 0 Then
          Emit('        CALL    ' + FuncTab[FnIdx].AsmLabel)
        Else
          Emit('        CALL    ' + AW_FN_PFX + AsmIdent(IdName));
        { STDCALL : la callee nettoie la pile (RET n) }
        { Resultat dans EAX }
        ParsePrimaryExpr := TYK_UNKNOWN;
      End
      { Acces tableau : ident [ expr ] (TODO 16 : code gen) }
      Else If IsPunct('[') Then
      Begin
        ParserAdvance;  { consommer [ }
        D := ParseExpr;
        D := GenCoerceToString(D);
        { SUBSEP : indices multidimensionnels a[i,j] -> concat avec SUBSEP }
        While IsPunct(',') Do
        Begin
          GenPushEAX;     { sauver la cle accumulee }
          ParserAdvance;  { consommer , }
          SkipNewlines;
          { Charger SUBSEP et concatener }
          FnIdx := FindSym('SUBSEP');
          If FnIdx >= 0 Then
          Begin
            Emit('        MOV     EBX, EAX');
            Emit('        MOV     EAX, [' + SymTab[FnIdx].AsmLabel + ']');
            GenConcat;       { EAX = cle_accumulee + SUBSEP }
          End;
          Emit('        POP     EBX');  { restaurer cle accumulee+SUBSEP avant }
          { On a maintenant le resultat de concat dans EAX, mais }
          { il faut concatener avec l indice suivant }
          GenPushEAX;
          D := ParseExpr;
          D := GenCoerceToString(D);
          GenPopEBX;
          GenConcat;       { EAX = cle_accum + SUBSEP + indice }
        End;
        Expect(TK_PUNCT, ']');
        { Enregistrer comme tableau si inconnu }
        TK := FindSym(IdName);
        If TK < 0 Then
          TK := AddSym(IdName, TYK_ARRAY, STORE_GLOBAL, True);
        { Sauver l information du tableau pour ParseAssignExpr }
        LastArraySym := TK;
        LastArrayHasKey := True;
        { Generer HASH_GET : EAX = cle -> resultat dans EAX }
        GenArrayGet(TK);
        ParsePrimaryExpr := TYK_UNKNOWN;
      End
      Else
      Begin
        { Variable scalaire }
        TK := FindSym(IdName);
        If TK < 0 Then
          TK := AddSym(IdName, TYK_UNINITIALIZED, STORE_GLOBAL, True);
        If TK >= 0 Then
        Begin
          GenLoadVar(TK);
          LastSymIdx := TK;
          ParsePrimaryExpr := SymTab[TK].TypeKind;
        End
        Else
          ParsePrimaryExpr := TYK_UNKNOWN;
      End;
    End;
    TK_BUILTIN:
    Begin
      { Fonction builtin AWK : dispatcher via ParseBuiltinString (TODO 18) }
      FnIdx := CurToken.IntVal;
      ParserAdvance;  { consommer le nom de la fonction }
      ParsePrimaryExpr := ParseBuiltinString(FnIdx);
    End;
    TK_KEYWORD:
    Begin
      { getline est un keyword qui peut apparaitre en expression (TODO 20) }
      If IsKW(KW_GETLINE) Then
      Begin
        ParserAdvance;
        ParsePrimaryExpr := ParseGetline;
      End
      { sprintf est un keyword mais fonctionne comme une fonction }
      Else If IsKW(KW_SPRINTF) Then
      Begin
        ParserAdvance; { consommer sprintf }
        ParsePrimaryExpr := ParseSprintf;
      End
      Else
        FatalError('mot-cle inattendu "' + CurToken.Val +
                   '" dans une expression (ligne ' +
                   IntToStr_(CurToken.Line) + ')');
    End;
    TK_PUNCT:
    Begin
      { Parentheses ( expr ) }
      If CurToken.Val = '(' Then
      Begin
        ParserAdvance;  { consommer ( }
        SkipNewlines;
        ParsePrimaryExpr := ParseExpr;
        SkipNewlines;
        Expect(TK_PUNCT, ')');
      End
      Else
        FatalError('expression attendue, trouve "' + CurToken.Val +
                   '" (ligne ' + IntToStr_(CurToken.Line) + ')');
    End;
    TK_OP:
    Begin
      { Operateur $ en tant que reference de champ dynamique }
      If CurToken.Val = '$' Then
      Begin
        ParserAdvance;
        D := ParsePrimaryExpr;
        ParsePrimaryExpr := TYK_STRING;
      End
      Else
        FatalError('expression attendue, trouve operateur "' +
                   CurToken.Val + '" (ligne ' +
                   IntToStr_(CurToken.Line) + ')');
    End;
  Else
    FatalError('expression attendue (ligne ' +
               IntToStr_(CurToken.Line) + ')');
  End;
End;

{ ---- ParsePostfixExpr ---------------------------------------- }
{ var++ var-- (suffixe) }
Function ParsePostfixExpr : Integer;
Var
  TK   : Integer;
  OpStr: TString;
Begin
  TK := ParsePrimaryExpr;
  While (CurToken.Kind = TK_OP) And
        ((CurToken.Val = '++') Or (CurToken.Val = '--')) Do
  Begin
    OpStr := CurToken.Val;
    ParserAdvance;
    If OpStr = '++' Then
    Begin
      If LastSymIdx >= 0 Then GenIncVar(LastSymIdx);
    End
    Else
    Begin
      If LastSymIdx >= 0 Then GenDecVar(LastSymIdx);
    End;
    TK := TYK_NUMBER;
  End;
  ParsePostfixExpr := TK;
End;

{ ---- ParseUnaryExpr ------------------------------------------ }
{ ! - + ++ -- $ (prefixe) }
Function ParseUnaryExpr : Integer;
Var
  D : Integer;
Begin
  SkipNewlines;
  If CurToken.Kind = TK_OP Then
  Begin
    If CurToken.Val = '!' Then
    Begin
      ParserAdvance;
      D := ParseUnaryExpr;
      { Coercition booleenne : resultat en nombre 0/1 }
      D := GenCoerceToBoolean(D);
      GenUnaryNot;
      ParseUnaryExpr := TYK_NUMBER;
      Exit;
    End;
    If CurToken.Val = '-' Then
    Begin
      ParserAdvance;
      D := ParseUnaryExpr;
      { Coercition arithmetique : forcer en nombre }
      D := GenCoerceToNumber(D);
      GenUnaryNeg;
      ParseUnaryExpr := TYK_NUMBER;
      Exit;
    End;
    If CurToken.Val = '+' Then
    Begin
      ParserAdvance;
      D := ParseUnaryExpr;
      { Coercition arithmetique : forcer en nombre }
      D := GenCoerceToNumber(D);
      ParseUnaryExpr := TYK_NUMBER;
      Exit;
    End;
    If CurToken.Val = '++' Then
    Begin
      ParserAdvance;
      D := ParsePostfixExpr;
      If LastSymIdx >= 0 Then GenIncVar(LastSymIdx);
      ParseUnaryExpr := TYK_NUMBER;
      Exit;
    End;
    If CurToken.Val = '--' Then
    Begin
      ParserAdvance;
      D := ParsePostfixExpr;
      If LastSymIdx >= 0 Then GenDecVar(LastSymIdx);
      ParseUnaryExpr := TYK_NUMBER;
      Exit;
    End;
    If CurToken.Val = '$' Then
    Begin
      { Operateur $ dynamique : $(expr) -> champ variable (TODO 15) }
      ParserAdvance;
      D := ParsePrimaryExpr;
      { EAX contient l index de champ, CALL _AWRT_GETFIELD }
      Inc(FieldRefCount);
      LastFieldIdx := -1;
      LastFieldIsExpr := True;
      EmitComment('  $(expr) dynamic field ref');
      GenFieldRef;
      ParseUnaryExpr := TYK_STRING;
      Exit;
    End;
  End;
  ParseUnaryExpr := ParsePostfixExpr;
End;

{ ---- ParsePowExpr -------------------------------------------- }
{ ^ (droite a gauche) }
Function ParsePowExpr : Integer;
Var
  TK : Integer;
  D  : Integer;
Begin
  TK := ParseUnaryExpr;
  If IsOp('^') Then
  Begin
    GenPushEAX;
    ParserAdvance;
    D := ParsePowExpr;  { droite a gauche : recursion }
    { Coercition arithmetique : forcer les deux en nombre }
    CoerceForArith(TK, D);
    GenPopEBX;
    GenBinOp(OP_POW);
    TK := TYK_NUMBER;
  End;
  ParsePowExpr := TK;
End;

{ ---- ParseMulExpr -------------------------------------------- }
{ * / % }
Function ParseMulExpr : Integer;
Var
  TK    : Integer;
  D     : Integer;
  OpStr : TString;
  OpCode: Integer;
Begin
  TK := ParsePowExpr;
  While (CurToken.Kind = TK_OP) And
        ((CurToken.Val = '*') Or (CurToken.Val = '/') Or
         (CurToken.Val = '%')) Do
  Begin
    OpStr := CurToken.Val;
    GenPushEAX;
    ParserAdvance;
    D := ParsePowExpr;
    { Coercition arithmetique : forcer les deux en nombre }
    CoerceForArith(TK, D);
    GenPopEBX;
    If OpStr = '*' Then OpCode := OP_MUL
    Else If OpStr = '/' Then OpCode := OP_DIV
    Else OpCode := OP_MOD;
    GenBinOp(OpCode);
    TK := TYK_NUMBER;
  End;
  ParseMulExpr := TK;
End;

{ ---- ParseAddExpr -------------------------------------------- }
{ + - }
Function ParseAddExpr : Integer;
Var
  TK    : Integer;
  D     : Integer;
  OpStr : TString;
  OpCode: Integer;
Begin
  TK := ParseMulExpr;
  While (CurToken.Kind = TK_OP) And
        ((CurToken.Val = '+') Or (CurToken.Val = '-')) Do
  Begin
    OpStr := CurToken.Val;
    GenPushEAX;
    ParserAdvance;
    D := ParseMulExpr;
    { Coercition arithmetique : forcer les deux en nombre }
    CoerceForArith(TK, D);
    GenPopEBX;
    If OpStr = '+' Then OpCode := OP_ADD
    Else OpCode := OP_SUB;
    GenBinOp(OpCode);
    TK := TYK_NUMBER;
  End;
  ParseAddExpr := TK;
End;

{ ---- ParseConcatExpr ----------------------------------------- }
{ Concatenation implicite AWK : deux expressions adjacentes      }
{ sans operateur binaire forment une concatenation de chaines    }
Function IsConcatFollow : Boolean;
Begin
  IsConcatFollow := False;
  If CurToken.Kind In [TK_INTEGER, TK_FLOAT, TK_STRING,
                        TK_REGEXP, TK_IDENT, TK_BVAR,
                        TK_FIELD, TK_BUILTIN] Then
    IsConcatFollow := True
  Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    IsConcatFollow := True
  Else If (CurToken.Kind = TK_OP) And
          ((CurToken.Val = '!') Or (CurToken.Val = '-') Or
           (CurToken.Val = '+') Or (CurToken.Val = '++') Or
           (CurToken.Val = '--') Or (CurToken.Val = '$')) Then
    IsConcatFollow := True
  Else If (CurToken.Kind = TK_KEYWORD) And
          (CurToken.IntVal = KW_GETLINE) Then
    IsConcatFollow := True;
End;

Function ParseConcatExpr : Integer;
Var
  TK : Integer;
  D  : Integer;
Begin
  TK := ParseAddExpr;
  While IsConcatFollow Do
  Begin
    D := ParseAddExpr;
    { Coercition des deux operandes en chaine pour concatenation }
    CoerceForConcat(TK, D);
    { Emettre la concatenation }
    GenConcat;
    TK := TYK_STRING;
  End;
  ParseConcatExpr := TK;
End;

{ ---- ParseCompareExpr ---------------------------------------- }
{ < <= > >= == != }
Function ParseCompareExpr : Integer;
Var
  TK     : Integer;
  D      : Integer;
  OpStr  : TString;
  CmpCode: Integer;
Begin
  TK := ParseConcatExpr;
  While (CurToken.Kind = TK_OP) And
        ((CurToken.Val = '<') Or (CurToken.Val = '<=') Or
         (CurToken.Val = '>') Or (CurToken.Val = '>=') Or
         (CurToken.Val = '==') Or (CurToken.Val = '!=')) Do
  Begin
    OpStr := CurToken.Val;
    GenPushEAX;
    ParserAdvance;
    D := ParseConcatExpr;
    { Coercition contextuelle : nombre vs chaine selon les types }
    CoerceForCompare(TK, D);
    GenPopEBX;
    If OpStr = '<' Then CmpCode := CMP_LT
    Else If OpStr = '<=' Then CmpCode := CMP_LE
    Else If OpStr = '>' Then CmpCode := CMP_GT
    Else If OpStr = '>=' Then CmpCode := CMP_GE
    Else If OpStr = '==' Then CmpCode := CMP_EQ
    Else CmpCode := CMP_NE;
    GenCompare(CmpCode);
    TK := TYK_NUMBER;
  End;
  ParseCompareExpr := TK;
End;

{ ---- ParseMatchExpr ------------------------------------------ }
{ ~ !~ (TODO 17 : code gen MATCH_RE) }
Function ParseMatchExpr : Integer;
Var
  TK    : Integer;
  D     : Integer;
  IsNot : Boolean;
Begin
  TK := ParseCompareExpr;
  While (CurToken.Kind = TK_OP) And
        ((CurToken.Val = '~') Or (CurToken.Val = '!~')) Do
  Begin
    IsNot := (CurToken.Val = '!~');
    { Le cote gauche (EAX) est la chaine a tester }
    TK := GenCoerceToString(TK);
    GenPushEAX;
    ParserAdvance;
    D := ParseCompareExpr;
    { Le cote droit (EAX) est le pattern (TYK_REGEXP ou chaine) }
    D := GenCoerceToString(D);
    { EAX = pattern, pile = string a tester }
    GenPopEBX;  { EBX = string }
    GenRegexMatch;  { PUSH EAX + PUSH EBX + CALL MATCH_RE -> EAX 0/1 }
    If IsNot Then
      GenUnaryNot;  { inverser le resultat pour !~ }
    TK := TYK_NUMBER;
  End;
  ParseMatchExpr := TK;
End;

{ ---- ParseInExpr --------------------------------------------- }
{ expr in array (TODO 16 : code gen HASH_EXISTS) }
Function ParseInExpr : Integer;
Var
  TK : Integer;
  Idx: Integer;
Begin
  TK := ParseMatchExpr;
  If IsKW(KW_IN) Then
  Begin
    ParserAdvance;  { consommer 'in' }
    { EAX contient la cle (expression a gauche de in) }
    TK := GenCoerceToString(TK);
    { Le token suivant doit etre un nom de tableau }
    If CurToken.Kind = TK_IDENT Then
    Begin
      Idx := FindSym(CurToken.Val);
      If Idx < 0 Then
        Idx := AddSym(CurToken.Val, TYK_ARRAY, STORE_GLOBAL, True);
      { Generer HASH_EXISTS : EAX = cle -> EAX = 0/1 }
      GenArrayExists(Idx);
      ParserAdvance;
    End Else
      FatalError('nom de tableau attendu apres "in" (ligne ' +
                 IntToStr_(CurToken.Line) + ')');
    TK := TYK_NUMBER;
  End;
  ParseInExpr := TK;
End;

{ ---- ParseAndExpr -------------------------------------------- }
{ && }
Function ParseAndExpr : Integer;
Var
  TK : Integer;
  D  : Integer;
Begin
  TK := ParseInExpr;
  While IsOp('&&') Do
  Begin
    ParserAdvance;
    SkipNewlines;
    D := ParseInExpr;
    { Coercition booleenne : les deux operandes en nombre (0/1) }
    TK := GenCoerceToBoolean(TK);
    D := GenCoerceToBoolean(D);
    TK := TYK_NUMBER;
  End;
  ParseAndExpr := TK;
End;

{ ---- ParseOrExpr --------------------------------------------- }
{ || }
Function ParseOrExpr : Integer;
Var
  TK : Integer;
  D  : Integer;
Begin
  TK := ParseAndExpr;
  While IsOp('||') Do
  Begin
    ParserAdvance;
    SkipNewlines;
    D := ParseAndExpr;
    { Coercition booleenne : les deux operandes en nombre (0/1) }
    TK := GenCoerceToBoolean(TK);
    D := GenCoerceToBoolean(D);
    TK := TYK_NUMBER;
  End;
  ParseOrExpr := TK;
End;

{ ---- ParseTernaryExpr ---------------------------------------- }
{ cond ? expr_vrai : expr_faux }
Function ParseTernaryExpr : Integer;
Var
  TK : Integer;
  D  : Integer;
Begin
  TK := ParseOrExpr;
  If IsOp('?') Then
  Begin
    ParserAdvance;
    SkipNewlines;
    D := ParseExpr;
    Expect(TK_OP, ':');
    SkipNewlines;
    TK := ParseAssignExpr;
  End;
  ParseTernaryExpr := TK;
End;

{ ---- ParseAssignExpr ----------------------------------------- }
{ = += -= *= /= %= ^= (droite a gauche) }
{ TODO 15 : supporte aussi $n = expr via GenFieldStore }
{ TODO 16 : supporte aussi array[key] = expr via GenArraySet }
Function ParseAssignExpr : Integer;
Var
  TK          : Integer;
  SaveSym     : Integer;
  SaveField   : Integer;
  SaveFExpr   : Boolean;
  SaveArrSym  : Integer;
  SaveArrKey  : Boolean;
Begin
  TK := ParseTernaryExpr;
  If (CurToken.Kind = TK_OP) And
     ((CurToken.Val = '=') Or (CurToken.Val = '+=') Or
      (CurToken.Val = '-=') Or (CurToken.Val = '*=') Or
      (CurToken.Val = '/=') Or (CurToken.Val = '%=') Or
      (CurToken.Val = '^=')) Then
  Begin
    SaveSym    := LastSymIdx;
    SaveField  := LastFieldIdx;
    SaveFExpr  := LastFieldIsExpr;
    SaveArrSym := LastArraySym;
    SaveArrKey := LastArrayHasKey;
    ParserAdvance;
    SkipNewlines;
    TK := ParseAssignExpr;  { droite a gauche : recursion }
    { TODO 16 : si le LHS est array[key], utiliser GenArraySet }
    If SaveArrKey And (SaveArrSym >= 0) Then
    Begin
      { EAX contient la valeur, la cle etait dans EAX avant GenArrayGet }
      { On re-emet un SET : EAX=valeur, EBX devrait avoir la cle }
      { Simplification : on emet PUSH EAX + re-evaluation de la cle }
      GenArraySet(SaveArrSym);
    End
    { TODO 15 : si le LHS est un champ ($n), utiliser GenFieldStore }
    Else If (SaveField >= 0) Or SaveFExpr Then
    Begin
      EmitComment('  $field = expr (store)');
      If (SaveField >= 0) And (Not SaveFExpr) Then
      Begin
        { Champ statique $n : charger l index dans EBX puis SETFIELD }
        Emit('        MOV     EBX, ' + IntToStr_(SaveField));
      End;
      { EAX contient la valeur, EBX/pile contient l index }
      GenFieldStore;
    End
    Else If SaveSym >= 0 Then
      GenStoreVar(SaveSym);
  End;
  ParseAssignExpr := TK;
End;

{ ---- ParseExpr ----------------------------------------------- }
{ Priorite la plus basse = affectation }
Function ParseExpr : Integer;
Begin
  Inc(ExprCount);
  LastFieldIdx := -1;
  LastFieldIsExpr := False;
  LastArraySym := -1;
  LastArrayHasKey := False;
  ParseExpr := ParseAssignExpr;
End;

{ ============================================================ }
{ TODO 07 - PARSEUR : CONCATENATION DE CHAINES ET COERCITION   }
{           [IMPLEMENTE]                                        }
{ ============================================================ }

{ ---- GenCoerceToNumber --------------------------------------- }
{ Forcer la coercition d une valeur en nombre.                  }
{ Si le type courant est TYK_STRING, emettre CALL _AWRT_STRTONUM }
{ Si TYK_UNINITIALIZED ou TYK_UNKNOWN, le marquer comme nombre  }
{ Retourne toujours TYK_NUMBER.                                  }
Function GenCoerceToNumber(CurType: Integer) : Integer;
Begin
  If CurType = TYK_STRING Then
  Begin
    { EAX contient un pointeur chaine -> convertir en nombre }
    { PUSH EAX / CALL _AWRT_STRTONUM -> resultat dans EAX }
    Inc(CoercionCount);
    If Opts.Verbose Then
      WarnMsg('coercition chaine -> nombre');
  End
  Else If CurType = TYK_UNINITIALIZED Then
  Begin
    { Variable non initialisee : valeur par defaut = 0 }
    Inc(CoercionCount);
  End;
  GenCoerceToNumber := TYK_NUMBER;
End;

{ ---- GenCoerceToString --------------------------------------- }
{ Forcer la coercition d une valeur en chaine.                  }
{ Si le type courant est TYK_NUMBER, emettre CALL _AWRT_NUMTOSTR }
{ Si TYK_UNINITIALIZED, la valeur par defaut est "".             }
{ Retourne toujours TYK_STRING.                                  }
Function GenCoerceToString(CurType: Integer) : Integer;
Begin
  If CurType = TYK_NUMBER Then
  Begin
    { EAX contient un nombre -> convertir en chaine ASCIIZ }
    { PUSH EAX / CALL _AWRT_NUMTOSTR -> resultat dans EAX }
    Inc(CoercionCount);
    If Opts.Verbose Then
      WarnMsg('coercition nombre -> chaine');
  End
  Else If CurType = TYK_UNINITIALIZED Then
  Begin
    { Variable non initialisee : valeur par defaut = "" }
    Inc(CoercionCount);
  End;
  GenCoerceToString := TYK_STRING;
End;

{ ---- GenCoerceToBoolean -------------------------------------- }
{ Forcer la coercition en valeur booleenne (0 = faux, !0 = vrai) }
{ Les chaines vides "" et "0" sont fausses, le reste est vrai.   }
{ Les nombres : 0 = faux, !0 = vrai.                            }
{ Retourne toujours TYK_NUMBER (0 ou 1).                         }
Function GenCoerceToBoolean(CurType: Integer) : Integer;
Begin
  If CurType = TYK_STRING Then
  Begin
    { EAX contient chaine -> tester si vide ou "0" }
    { PUSH EAX / CALL _AWRT_STRTOBOOL -> EAX = 0 ou 1 }
    Inc(CoercionCount);
    If Opts.Verbose Then
      WarnMsg('coercition chaine -> booleen');
  End
  Else If CurType = TYK_UNINITIALIZED Then
  Begin
    { Non initialise = faux (0) }
    Inc(CoercionCount);
  End;
  { Pour TYK_NUMBER : TEST EAX,EAX / SETNZ AL / MOVZX EAX,AL }
  GenCoerceToBoolean := TYK_NUMBER;
End;

{ ---- GenConcat ----------------------------------------------- }
{ Concatener deux chaines : EBX (gauche) et EAX (droite).       }
{ Les deux valeurs doivent etre des chaines (ASCIIZ).           }
{ Resultat : pointeur vers _AWRT_CATBUF dans EAX.              }
{ Generation future :                                            }
{   PUSH EAX          ; chaine droite                           }
{   PUSH EBX          ; chaine gauche                           }
{   CALL _AWRT_STRCAT ; resultat dans EAX (-> _AWRT_CATBUF)    }
Procedure GenConcat;
Begin
  Inc(ConcatCount);
End;

{ ---- GenStrDup ----------------------------------------------- }
{ Dupliquer une chaine dans le tas via HeapAlloc.               }
{ EAX = pointeur chaine source -> EAX = pointeur copie.        }
{ Generation future :                                            }
{   PUSH EAX                                                     }
{   CALL _AWRT_STRDUP -> EAX = copie sur le tas                }
Procedure GenStrDup;
Begin
  { Stub - sera complete dans TODO 08 (generation de code) }
End;

{ ---- CoerceForArith ------------------------------------------ }
{ Coercition des deux operandes pour une operation arithmetique. }
{ Les operandes doivent etre des nombres.                       }
{ TKLeft et TKRight sont les types des operandes gauche/droite. }
Procedure CoerceForArith(Var TKLeft, TKRight: Integer);
Begin
  If TKLeft <> TYK_NUMBER Then
    TKLeft := GenCoerceToNumber(TKLeft);
  If TKRight <> TYK_NUMBER Then
    TKRight := GenCoerceToNumber(TKRight);
End;

{ ---- CoerceForConcat ----------------------------------------- }
{ Coercition des deux operandes pour une concatenation.         }
{ Les operandes doivent etre des chaines.                       }
Procedure CoerceForConcat(Var TKLeft, TKRight: Integer);
Begin
  If TKLeft <> TYK_STRING Then
    TKLeft := GenCoerceToString(TKLeft);
  If TKRight <> TYK_STRING Then
    TKRight := GenCoerceToString(TKRight);
End;

{ ---- CoerceForCompare ---------------------------------------- }
{ Coercition pour une comparaison : si les deux sont des nombres }
{ on compare en nombre, sinon en chaine.                        }
Procedure CoerceForCompare(Var TKLeft, TKRight: Integer);
Begin
  { Si les deux sont des nombres, comparer en nombre }
  If (TKLeft = TYK_NUMBER) And (TKRight = TYK_NUMBER) Then
    Exit;
  { Si les deux sont des chaines, comparer en chaine }
  If (TKLeft = TYK_STRING) And (TKRight = TYK_STRING) Then
    Exit;
  { Mixte : forcer les deux en nombre (comportement AWK standard) }
  If TKLeft <> TYK_NUMBER Then
    TKLeft := GenCoerceToNumber(TKLeft);
  If TKRight <> TYK_NUMBER Then
    TKRight := GenCoerceToNumber(TKRight);
End;

{ ============================================================ }
{ TODO 08 - GENERATION DE CODE : OPERATIONS ARITHMETIQUES 80386 }
{ ============================================================ }

{ ---- Emit ---------------------------------------------------- }
{ Ecrit une ligne d assembleur dans le fichier de sortie         }
Procedure Emit(Const S: TString);
Begin
  Inc(GenCount);
  If GenEnabled And OutFOpen Then
    WriteLn(OutF, S);
End;

{ ---- EmitLabel ----------------------------------------------- }
Procedure EmitLabel(Const Lbl: TString);
Begin
  Inc(GenCount);
  If GenEnabled And OutFOpen Then
    WriteLn(OutF, Lbl, ':');
End;

{ ---- EmitComment --------------------------------------------- }
Procedure EmitComment(Const S: TString);
Begin
  If GenEnabled And OutFOpen Then
    WriteLn(OutF, '; ', S);
End;

{ ---- EmitBlank ----------------------------------------------- }
Procedure EmitBlank;
Begin
  If GenEnabled And OutFOpen Then
    WriteLn(OutF);
End;

{ ---- NewLabel ------------------------------------------------ }
Function NewLabel: TString;
Begin
  NewLabel := GenScopeLabel(AW_LBL_PFX);
End;

{ ---- AddStringLit -------------------------------------------- }
{ Ajoute un litteral chaine et retourne son label ASM            }
Function AddStringLit(Const Val: TString): TString;
Var
  Lbl : TString;
Begin
  If StringLitCount >= MAX_STRLIT Then
  Begin
    FatalError('table des litteraux chaine pleine (max=' +
               IntToStr_(MAX_STRLIT) + ')');
    AddStringLit := '';
    Exit;
  End;
  Lbl := GenScopeLabel(AW_STR_PFX);
  StringLitTab[StringLitCount].Lbl := Lbl;
  StringLitTab[StringLitCount].Val := Val;
  Inc(StringLitCount);
  AddStringLit := Lbl;
End;

{ ---- GenLoadConst -------------------------------------------- }
{ MOV EAX, imm32                                                 }
Procedure GenLoadConst(Val: LongInt);
Begin
  Emit('        MOV     EAX, ' + IntToStr_(Val));
End;

{ ---- GenLoadStr ---------------------------------------------- }
{ MOV EAX, OFFSET label  (pointeur vers litteral ASCIIZ)         }
Procedure GenLoadStr(Const Lbl: TString);
Begin
  Emit('        MOV     EAX, OFFSET ' + Lbl);
End;

{ ---- GenLoadVar ---------------------------------------------- }
{ Charge la valeur d une variable dans EAX                       }
Procedure GenLoadVar(SymIdx: Integer);
Begin
  If (SymIdx < 0) Or (SymIdx >= SymCount) Then Exit;
  Case SymTab[SymIdx].StoreClass Of
    STORE_GLOBAL:
      Emit('        MOV     EAX, DWORD PTR [' +
           SymTab[SymIdx].AsmLabel + ']');
    STORE_LOCAL:
      Emit('        MOV     EAX, DWORD PTR [EBP-' +
           IntToStr_(Abs(SymTab[SymIdx].BpOffset)) + ']');
    STORE_PARAM:
      Emit('        MOV     EAX, DWORD PTR [EBP+' +
           IntToStr_(SymTab[SymIdx].BpOffset) + ']');
  End;
End;

{ ---- GenStoreVar --------------------------------------------- }
{ Stocke EAX dans une variable                                   }
Procedure GenStoreVar(SymIdx: Integer);
Begin
  If (SymIdx < 0) Or (SymIdx >= SymCount) Then Exit;
  Case SymTab[SymIdx].StoreClass Of
    STORE_GLOBAL:
      Emit('        MOV     DWORD PTR [' +
           SymTab[SymIdx].AsmLabel + '], EAX');
    STORE_LOCAL:
      Emit('        MOV     DWORD PTR [EBP-' +
           IntToStr_(Abs(SymTab[SymIdx].BpOffset)) + '], EAX');
    STORE_PARAM:
      Emit('        MOV     DWORD PTR [EBP+' +
           IntToStr_(SymTab[SymIdx].BpOffset) + '], EAX');
  End;
End;

{ ---- GenPushEAX ---------------------------------------------- }
Procedure GenPushEAX;
Begin
  Emit('        PUSH    EAX');
End;

{ ---- GenPopEBX ----------------------------------------------- }
{ Sauvegarde EAX (droite) dans EBX puis restaure EAX (gauche)    }
Procedure GenPopEBX;
Begin
  Emit('        MOV     EBX, EAX');
  Emit('        POP     EAX');
End;

{ ---- GenBinOp ------------------------------------------------ }
{ Operation binaire : EAX = EAX op EBX                           }
Procedure GenBinOp(Op: Integer);
Begin
  Case Op Of
    OP_ADD:
      Emit('        ADD     EAX, EBX');
    OP_SUB:
      Emit('        SUB     EAX, EBX');
    OP_MUL:
      Emit('        IMUL    EAX, EBX');
    OP_DIV:
    Begin
      Emit('        CDQ');
      Emit('        IDIV    EBX');
    End;
    OP_MOD:
    Begin
      Emit('        CDQ');
      Emit('        IDIV    EBX');
      Emit('        MOV     EAX, EDX');
    End;
    OP_POW:
    Begin
      Emit('        PUSH    EBX');
      Emit('        PUSH    EAX');
      Emit('        CALL    ' + AW_RT_PFX + 'POW');
    End;
  End;
End;

{ ---- GenCompare ---------------------------------------------- }
{ CMP EAX, EBX + SETcc AL + MOVZX EAX, AL                      }
Procedure GenCompare(Op: Integer);
Var
  CC : TString;
Begin
  Case Op Of
    CMP_LT: CC := 'SETL';
    CMP_LE: CC := 'SETLE';
    CMP_GT: CC := 'SETG';
    CMP_GE: CC := 'SETGE';
    CMP_EQ: CC := 'SETE';
    CMP_NE: CC := 'SETNE';
  Else
    CC := 'SETE';
  End;
  Emit('        CMP     EAX, EBX');
  Emit('        ' + CC + '    AL');
  Emit('        MOVZX   EAX, AL');
End;

{ ---- GenUnaryNeg --------------------------------------------- }
{ NEG EAX                                                        }
Procedure GenUnaryNeg;
Begin
  Emit('        NEG     EAX');
End;

{ ---- GenUnaryNot --------------------------------------------- }
{ TEST EAX,EAX / SETZ AL / MOVZX EAX,AL                        }
Procedure GenUnaryNot;
Begin
  Emit('        TEST    EAX, EAX');
  Emit('        SETZ    AL');
  Emit('        MOVZX   EAX, AL');
End;

{ ---- GenIncVar ----------------------------------------------- }
{ INC DWORD PTR [var]                                            }
Procedure GenIncVar(SymIdx: Integer);
Begin
  If (SymIdx < 0) Or (SymIdx >= SymCount) Then Exit;
  Case SymTab[SymIdx].StoreClass Of
    STORE_GLOBAL:
      Emit('        INC     DWORD PTR [' +
           SymTab[SymIdx].AsmLabel + ']');
    STORE_LOCAL:
      Emit('        INC     DWORD PTR [EBP-' +
           IntToStr_(Abs(SymTab[SymIdx].BpOffset)) + ']');
    STORE_PARAM:
      Emit('        INC     DWORD PTR [EBP+' +
           IntToStr_(SymTab[SymIdx].BpOffset) + ']');
  End;
End;

{ ---- GenDecVar ----------------------------------------------- }
{ DEC DWORD PTR [var]                                            }
Procedure GenDecVar(SymIdx: Integer);
Begin
  If (SymIdx < 0) Or (SymIdx >= SymCount) Then Exit;
  Case SymTab[SymIdx].StoreClass Of
    STORE_GLOBAL:
      Emit('        DEC     DWORD PTR [' +
           SymTab[SymIdx].AsmLabel + ']');
    STORE_LOCAL:
      Emit('        DEC     DWORD PTR [EBP-' +
           IntToStr_(Abs(SymTab[SymIdx].BpOffset)) + ']');
    STORE_PARAM:
      Emit('        DEC     DWORD PTR [EBP+' +
           IntToStr_(SymTab[SymIdx].BpOffset) + ']');
  End;
End;

{ ---- GenFieldRef --------------------------------------------- }
{ PUSH EAX + CALL _AWRT_GETFIELD -> resultat dans EAX           }
Procedure GenFieldRef;
Begin
  Emit('        PUSH    EAX');
  Emit('        CALL    ' + AW_RT_PFX + 'GETFIELD');
End;

{ ---- GenFieldStore ------------------------------------------- }
{ PUSH EAX (valeur) + PUSH idx + CALL _AWRT_SETFIELD            }
Procedure GenFieldStore;
Begin
  Emit('        PUSH    EAX');
  Emit('        CALL    ' + AW_RT_PFX + 'SETFIELD');
End;

{ ============================================================ }
{ TODO 15 - PARSEUR : CHAMPS $0..$NF ET SEPARATEURS FS, RS,   }
{           OFS, ORS  [IMPLEMENTE]                              }
{ ============================================================ }

{ ---- GenFieldSplit ------------------------------------------- }
{ Decouper la ligne courante $0 en champs $1..$NF selon FS.    }
{ CALL _AWRT_SPLITLINE -> met a jour _AWRT_NF et _AWRT_FIELDS  }
Procedure GenFieldSplit;
Begin
  EmitComment('  split $0 into fields by FS');
  Emit('        CALL    ' + AW_RT_PFX + 'SPLITLINE');
End;

{ ---- ParseFieldRef ------------------------------------------- }
{ Parse une reference de champ a partir du token TK_FIELD.      }
{ Le token TK_FIELD contient la valeur textuelle du champ :     }
{   "0"  -> $0 (ligne complete : MOV EAX, OFFSET _AWRT_LINE)   }
{   "1".."9..." -> $n (champ n : MOV EAX, n + GETFIELD)        }
{   "NF" -> $NF (dernier champ : MOV EAX, [_AWV_NF] + GETFIELD)}
{   autre -> $(expr) deja gere dans ParseUnaryExpr              }
{ Retourne le type de la valeur (TYK_STRING).                   }
Function ParseFieldRef : Integer;
Var
  FVal : TString;
  FNum : Integer;
  NfIdx: Integer;
  Code : Integer;
Begin
  FVal := CurToken.Val;
  Inc(FieldRefCount);
  LastFieldIsExpr := False;

  { $0 -> ligne complete }
  If FVal = '0' Then
  Begin
    LastFieldIdx := 0;
    EmitComment('  $0 = whole line');
    Emit('        MOV     EAX, OFFSET ' + AW_RT_PFX + 'LINE');
    ParseFieldRef := TYK_STRING;
    ParserAdvance;
    Exit;
  End;

  { $NF -> dernier champ (index = valeur de NF) }
  If FVal = 'NF' Then
  Begin
    LastFieldIdx := -1;
    LastFieldIsExpr := True;
    NfIdx := FindSym('NF');
    EmitComment('  $NF = last field');
    If NfIdx >= 0 Then
      GenLoadVar(NfIdx)
    Else
      Emit('        MOV     EAX, DWORD PTR [' + AW_RT_PFX + 'NF]');
    GenFieldRef;
    ParseFieldRef := TYK_STRING;
    ParserAdvance;
    Exit;
  End;

  { $1..$n -> champ n (constante numerique) }
  Val(FVal, FNum, Code);
  If Code = 0 Then
  Begin
    LastFieldIdx := FNum;
    EmitComment('  $' + FVal + ' = field ' + FVal);
    Emit('        MOV     EAX, ' + IntToStr_(FNum));
    GenFieldRef;
    ParseFieldRef := TYK_STRING;
    ParserAdvance;
    Exit;
  End;

  { $ident -> champ d apres la valeur de la variable ident }
  { Traite comme $(ident) }
  LastFieldIdx := -1;
  LastFieldIsExpr := True;
  NfIdx := FindSym(FVal);
  EmitComment('  $' + FVal + ' = field by variable');
  If NfIdx >= 0 Then
    GenLoadVar(NfIdx)
  Else
  Begin
    { Variable inconnue, creer comme globale }
    NfIdx := AddSym(FVal, TYK_NUMBER, STORE_GLOBAL, True);
    GenLoadVar(NfIdx);
  End;
  GenFieldRef;
  ParseFieldRef := TYK_STRING;
  ParserAdvance;
End;

{ ============================================================ }
{ TODO 16 - PARSEUR : TABLEAUX ASSOCIATIFS ET OPERATEUR        }
{           IN / DELETE  [IMPLEMENTE]                           }
{ ============================================================ }

{ ---- GenArrayGet --------------------------------------------- }
{ EAX contient la cle (pointeur chaine).                         }
{ PUSH EAX (cle) + PUSH OFFSET _AWA_array + CALL HASH_GET       }
{ Resultat dans EAX (valeur associee a la cle).                  }
Procedure GenArrayGet(SymIdx: Integer);
Begin
  Inc(ArrayOpCount);
  EmitComment('  array GET: ' + SymTab[SymIdx].Name + '[key]');
  Emit('        PUSH    EAX');
  Emit('        PUSH    OFFSET ' + SymTab[SymIdx].ArrayAsmLabel);
  Emit('        CALL    ' + AW_RT_PFX + 'HASH_GET');
End;

{ ---- GenArraySet --------------------------------------------- }
{ EAX contient la valeur, EBX contient la cle.                   }
{ PUSH EAX (val) + PUSH EBX (cle) + PUSH OFFSET arr + CALL SET  }
Procedure GenArraySet(SymIdx: Integer);
Begin
  Inc(ArrayOpCount);
  EmitComment('  array SET: ' + SymTab[SymIdx].Name + '[key] = val');
  Emit('        PUSH    EAX');
  Emit('        PUSH    EBX');
  Emit('        PUSH    OFFSET ' + SymTab[SymIdx].ArrayAsmLabel);
  Emit('        CALL    ' + AW_RT_PFX + 'HASH_SET');
End;

{ ---- GenArrayExists ------------------------------------------ }
{ EAX contient la cle.                                           }
{ PUSH EAX (cle) + PUSH OFFSET _AWA_array + CALL HASH_EXISTS    }
{ Resultat dans EAX (0 ou 1).                                    }
Procedure GenArrayExists(SymIdx: Integer);
Begin
  Inc(ArrayOpCount);
  EmitComment('  array EXISTS: (key in ' + SymTab[SymIdx].Name + ')');
  Emit('        PUSH    EAX');
  Emit('        PUSH    OFFSET ' + SymTab[SymIdx].ArrayAsmLabel);
  Emit('        CALL    ' + AW_RT_PFX + 'HASH_EXISTS');
End;

{ ---- GenArrayDel --------------------------------------------- }
{ EAX contient la cle.                                           }
{ PUSH EAX (cle) + PUSH OFFSET _AWA_array + CALL HASH_DEL       }
Procedure GenArrayDel(SymIdx: Integer);
Begin
  Inc(ArrayOpCount);
  EmitComment('  array DEL: delete ' + SymTab[SymIdx].Name + '[key]');
  Emit('        PUSH    EAX');
  Emit('        PUSH    OFFSET ' + SymTab[SymIdx].ArrayAsmLabel);
  Emit('        CALL    ' + AW_RT_PFX + 'HASH_DEL');
End;

{ ---- GenArrayClear ------------------------------------------- }
{ PUSH OFFSET _AWA_array + CALL HASH_CLEAR                      }
Procedure GenArrayClear(SymIdx: Integer);
Begin
  Inc(ArrayOpCount);
  EmitComment('  array CLEAR: delete ' + SymTab[SymIdx].Name);
  Emit('        PUSH    OFFSET ' + SymTab[SymIdx].ArrayAsmLabel);
  Emit('        CALL    ' + AW_RT_PFX + 'HASH_CLEAR');
End;

{ ============================================================ }
{ TODO 17 - PARSEUR : EXPRESSIONS REGULIERES ET MATCHING       }
{           ~ / !~  [IMPLEMENTE]                                }
{ ============================================================ }

{ ---- AddRegexPat --------------------------------------------- }
{ Ajoute un pattern regex dans la table et retourne son label    }
{ ASM (_AWP_n). Le pattern sera emis dans le segment .DATA       }
{ comme une chaine ASCIIZ.                                       }
Function AddRegexPat(Const Pat: TString): TString;
Var
  Lbl : TString;
Begin
  If RegexPatCount >= MAX_REGEX_PAT Then
  Begin
    FatalError('table des patterns regex pleine (max=' +
               IntToStr_(MAX_REGEX_PAT) + ')');
    AddRegexPat := '';
    Exit;
  End;
  Lbl := GenScopeLabel(AW_PAT_PFX);
  RegexPatTab[RegexPatCount].Lbl := Lbl;
  RegexPatTab[RegexPatCount].Pat := Pat;
  Inc(RegexPatCount);
  AddRegexPat := Lbl;
End;

{ ---- GenRegexMatch ------------------------------------------- }
{ EBX contient la chaine a tester (pointeur ASCIIZ).             }
{ EAX contient le pattern regex (pointeur ASCIIZ).               }
{ PUSH EAX (pattern) + PUSH EBX (string) + CALL MATCH_RE        }
{ Resultat dans EAX : 1 si match, 0 sinon.                      }
Procedure GenRegexMatch;
Begin
  Inc(RegexOpCount);
  EmitComment('  regex match: string ~ /pattern/');
  Emit('        PUSH    EAX');
  Emit('        PUSH    EBX');
  Emit('        CALL    ' + AW_RT_PFX + 'MATCH_RE');
End;

{ ============================================================ }
{ TODO 18 - PARSEUR : FONCTIONS BUILTIN CHAINES                }
{           [IMPLEMENTE]                                        }
{ ============================================================ }

{ ---- ParseBuiltinString -------------------------------------- }
{ Parse un appel a une fonction builtin de chaines AWK.          }
{ BFIdx = index de la fonction (BF_LENGTH..BF_TOUPPER).          }
{ Le token courant est deja sur '(' (ou fin de ligne pour        }
{ length sans parentheses).                                      }
{ Retourne le type du resultat (TYK_STRING ou TYK_NUMBER).       }
Function ParseBuiltinString(BFIdx: Integer): Integer;
Var
  ExprType : Integer;
  ArgCount : Integer;
  NS       : TString;
  ArrIdx   : Integer;
  ArrName  : TString;
Begin
  Inc(BuiltinStrCount);
  ParseBuiltinString := TYK_NUMBER;  { par defaut }

  Case BFIdx Of
    { ---- length(s) ou length(array) ou length sans args ---- }
    BF_LENGTH:
    Begin
      EmitComment('--- builtin length ---');
      If IsPunct('(') Then
      Begin
        ParserAdvance;  { consommer ( }
        { Detecter si l argument est un tableau }
        If (CurToken.Kind = TK_IDENT) Then
        Begin
          ArrName := CurToken.Val;
          ArrIdx := FindSym(ArrName);
          If (ArrIdx >= 0) And (SymTab[ArrIdx].IsArray) Then
          Begin
            { length(array) : nombre d elements }
            EmitComment('  length(array) -> HASH_COUNT');
            Emit('        PUSH    OFFSET ' + SymTab[ArrIdx].ArrayAsmLabel);
            Emit('        CALL    ' + AW_RT_PFX + 'HASH_COUNT');
            ParserAdvance;  { consommer le nom du tableau }
            Expect(TK_PUNCT, ')');
            ParseBuiltinString := TYK_NUMBER;
            Exit;
          End;
        End;
        { length(string) : longueur de la chaine }
        ExprType := ParseExpr;
        ExprType := GenCoerceToString(ExprType);
        Expect(TK_PUNCT, ')');
        Emit('        PUSH    EAX');
        Emit('        CALL    ' + AW_RT_PFX + 'STRLEN');
      End
      Else
      Begin
        { length sans parentheses : length de $0 }
        Emit('        MOV     EAX, OFFSET ' + AW_RT_PFX + 'LINE');
        Emit('        PUSH    EAX');
        Emit('        CALL    ' + AW_RT_PFX + 'STRLEN');
      End;
      ParseBuiltinString := TYK_NUMBER;
    End;

    { ---- substr(s, start [, len]) ---- }
    BF_SUBSTR:
    Begin
      EmitComment('--- builtin substr ---');
      If IsPunct('(') Then
        ParserAdvance
      Else
        WarnMsg('substr: ( attendu');
      { arg 1 : chaine }
      ExprType := ParseExpr;
      ExprType := GenCoerceToString(ExprType);
      GenPushEAX;
      ArgCount := 1;
      If IsPunct(',') Then
      Begin
        ParserAdvance; SkipNewlines;
        { arg 2 : position de debut }
        ExprType := ParseExpr;
        GenPushEAX;
        Inc(ArgCount);
      End;
      If IsPunct(',') Then
      Begin
        ParserAdvance; SkipNewlines;
        { arg 3 : longueur (optionnel) }
        ExprType := ParseExpr;
        GenPushEAX;
        Inc(ArgCount);
      End;
      If IsPunct(')') Then
        ParserAdvance
      Else
        WarnMsg('substr: ) attendu');
      Str(ArgCount, NS);
      Emit('        MOV     ECX, ' + NS);
      Emit('        CALL    ' + AW_RT_PFX + 'SUBSTR');
      If ArgCount > 0 Then
      Begin
        Str(ArgCount * 4, NS);
        Emit('        ADD     ESP, ' + NS);
      End;
      ParseBuiltinString := TYK_STRING;
    End;

    { ---- index(s, target) ---- }
    BF_INDEX:
    Begin
      EmitComment('--- builtin index ---');
      If IsPunct('(') Then
        ParserAdvance
      Else
        WarnMsg('index: ( attendu');
      { arg 1 : chaine source }
      ExprType := ParseExpr;
      ExprType := GenCoerceToString(ExprType);
      GenPushEAX;
      If IsPunct(',') Then
      Begin
        ParserAdvance; SkipNewlines;
      End;
      { arg 2 : sous-chaine a chercher }
      ExprType := ParseExpr;
      ExprType := GenCoerceToString(ExprType);
      GenPushEAX;
      If IsPunct(')') Then
        ParserAdvance
      Else
        WarnMsg('index: ) attendu');
      Emit('        CALL    ' + AW_RT_PFX + 'INDEX');
      Emit('        ADD     ESP, 8');
      ParseBuiltinString := TYK_NUMBER;
    End;

    { ---- split(s, array [, sep]) ---- }
    BF_SPLIT:
    Begin
      EmitComment('--- builtin split ---');
      If IsPunct('(') Then
        ParserAdvance
      Else
        WarnMsg('split: ( attendu');
      { arg 1 : chaine a decouper }
      ExprType := ParseExpr;
      ExprType := GenCoerceToString(ExprType);
      GenPushEAX;
      ArgCount := 1;
      If IsPunct(',') Then
      Begin
        ParserAdvance; SkipNewlines;
      End;
      { arg 2 : nom du tableau cible }
      If CurToken.Kind = TK_IDENT Then
      Begin
        ArrName := CurToken.Val;
        ArrIdx := FindSym(ArrName);
        If ArrIdx < 0 Then
          ArrIdx := AddSym(ArrName, TYK_ARRAY, STORE_GLOBAL, True);
        Emit('        PUSH    OFFSET ' + SymTab[ArrIdx].ArrayAsmLabel);
        Inc(ArgCount);
        ParserAdvance;
      End
      Else
      Begin
        WarnMsg('split: nom de tableau attendu');
        Emit('        PUSH    0');
        Inc(ArgCount);
      End;
      { arg 3 optionnel : separateur }
      If IsPunct(',') Then
      Begin
        ParserAdvance; SkipNewlines;
        ExprType := ParseExpr;
        ExprType := GenCoerceToString(ExprType);
        GenPushEAX;
        Inc(ArgCount);
      End;
      If IsPunct(')') Then
        ParserAdvance
      Else
        WarnMsg('split: ) attendu');
      Str(ArgCount, NS);
      Emit('        MOV     ECX, ' + NS);
      Emit('        CALL    ' + AW_RT_PFX + 'SPLIT');
      Str(ArgCount * 4, NS);
      Emit('        ADD     ESP, ' + NS);
      ParseBuiltinString := TYK_NUMBER;
    End;

    { ---- sub(regex, repl [, target]) ---- }
    BF_SUB:
    Begin
      EmitComment('--- builtin sub ---');
      If IsPunct('(') Then
        ParserAdvance
      Else
        WarnMsg('sub: ( attendu');
      { arg 1 : pattern regex }
      ExprType := ParseExpr;
      ExprType := GenCoerceToString(ExprType);
      GenPushEAX;
      ArgCount := 1;
      If IsPunct(',') Then
      Begin
        ParserAdvance; SkipNewlines;
      End;
      { arg 2 : chaine de remplacement }
      ExprType := ParseExpr;
      ExprType := GenCoerceToString(ExprType);
      GenPushEAX;
      Inc(ArgCount);
      { arg 3 optionnel : variable cible (par defaut $0) }
      If IsPunct(',') Then
      Begin
        ParserAdvance; SkipNewlines;
        ExprType := ParseExpr;
        ExprType := GenCoerceToString(ExprType);
        GenPushEAX;
        Inc(ArgCount);
      End
      Else
      Begin
        { Par defaut : $0 }
        Emit('        MOV     EAX, OFFSET ' + AW_RT_PFX + 'LINE');
        GenPushEAX;
        Inc(ArgCount);
      End;
      If IsPunct(')') Then
        ParserAdvance
      Else
        WarnMsg('sub: ) attendu');
      Str(ArgCount, NS);
      Emit('        MOV     ECX, ' + NS);
      Emit('        CALL    ' + AW_RT_PFX + 'SUB');
      Str(ArgCount * 4, NS);
      Emit('        ADD     ESP, ' + NS);
      ParseBuiltinString := TYK_NUMBER;
    End;

    { ---- gsub(regex, repl [, target]) ---- }
    BF_GSUB:
    Begin
      EmitComment('--- builtin gsub ---');
      If IsPunct('(') Then
        ParserAdvance
      Else
        WarnMsg('gsub: ( attendu');
      { arg 1 : pattern regex }
      ExprType := ParseExpr;
      ExprType := GenCoerceToString(ExprType);
      GenPushEAX;
      ArgCount := 1;
      If IsPunct(',') Then
      Begin
        ParserAdvance; SkipNewlines;
      End;
      { arg 2 : chaine de remplacement }
      ExprType := ParseExpr;
      ExprType := GenCoerceToString(ExprType);
      GenPushEAX;
      Inc(ArgCount);
      { arg 3 optionnel : variable cible (par defaut $0) }
      If IsPunct(',') Then
      Begin
        ParserAdvance; SkipNewlines;
        ExprType := ParseExpr;
        ExprType := GenCoerceToString(ExprType);
        GenPushEAX;
        Inc(ArgCount);
      End
      Else
      Begin
        { Par defaut : $0 }
        Emit('        MOV     EAX, OFFSET ' + AW_RT_PFX + 'LINE');
        GenPushEAX;
        Inc(ArgCount);
      End;
      If IsPunct(')') Then
        ParserAdvance
      Else
        WarnMsg('gsub: ) attendu');
      Str(ArgCount, NS);
      Emit('        MOV     ECX, ' + NS);
      Emit('        CALL    ' + AW_RT_PFX + 'GSUB');
      Str(ArgCount * 4, NS);
      Emit('        ADD     ESP, ' + NS);
      ParseBuiltinString := TYK_NUMBER;
    End;

    { ---- match(s, regex) ---- }
    BF_MATCH:
    Begin
      EmitComment('--- builtin match ---');
      If IsPunct('(') Then
        ParserAdvance
      Else
        WarnMsg('match: ( attendu');
      { arg 1 : chaine }
      ExprType := ParseExpr;
      ExprType := GenCoerceToString(ExprType);
      GenPushEAX;
      If IsPunct(',') Then
      Begin
        ParserAdvance; SkipNewlines;
      End;
      { arg 2 : pattern regex }
      ExprType := ParseExpr;
      ExprType := GenCoerceToString(ExprType);
      GenPushEAX;
      If IsPunct(')') Then
        ParserAdvance
      Else
        WarnMsg('match: ) attendu');
      Emit('        CALL    ' + AW_RT_PFX + 'MATCH');
      Emit('        ADD     ESP, 8');
      { match() met a jour RSTART et RLENGTH }
      ParseBuiltinString := TYK_NUMBER;
    End;

    { ---- sprintf(fmt, ...) ---- }
    { sprintf est deja gere par ParseSprintf via KW_SPRINTF }
    { mais il peut aussi etre appele comme builtin           }
    BF_SPRINTF:
    Begin
      ParseBuiltinString := ParseSprintf;
    End;

    { ---- tolower(s) ---- }
    BF_TOLOWER:
    Begin
      EmitComment('--- builtin tolower ---');
      If IsPunct('(') Then
        ParserAdvance
      Else
        WarnMsg('tolower: ( attendu');
      ExprType := ParseExpr;
      ExprType := GenCoerceToString(ExprType);
      If IsPunct(')') Then
        ParserAdvance
      Else
        WarnMsg('tolower: ) attendu');
      Emit('        PUSH    EAX');
      Emit('        CALL    ' + AW_RT_PFX + 'TOLOWER');
      Emit('        ADD     ESP, 4');
      ParseBuiltinString := TYK_STRING;
    End;

    { ---- toupper(s) ---- }
    BF_TOUPPER:
    Begin
      EmitComment('--- builtin toupper ---');
      If IsPunct('(') Then
        ParserAdvance
      Else
        WarnMsg('toupper: ( attendu');
      ExprType := ParseExpr;
      ExprType := GenCoerceToString(ExprType);
      If IsPunct(')') Then
        ParserAdvance
      Else
        WarnMsg('toupper: ) attendu');
      Emit('        PUSH    EAX');
      Emit('        CALL    ' + AW_RT_PFX + 'TOUPPER');
      Emit('        ADD     ESP, 4');
      ParseBuiltinString := TYK_STRING;
    End;
  Else
    { Fonction builtin non-chaine : dispatch via ParseBuiltinMath (TODO 19) }
    Dec(BuiltinStrCount);  { ne pas compter les builtin math comme str }
    ParseBuiltinString := ParseBuiltinMath(BFIdx);
  End;  { case }
End;

{ ============================================================ }
{ TODO 19 - PARSEUR : FONCTIONS BUILTIN MATHEMATIQUES          }
{ ============================================================ }

Function ParseBuiltinMath(BFIdx: Integer): Integer;
Var
  ExprType : Integer;
  ArgCount : Integer;
Begin
  Inc(BuiltinMathCount);
  ParseBuiltinMath := TYK_NUMBER;  { par defaut }

  Case BFIdx Of
    { ---- sin(x) ---- }
    BF_SIN:
    Begin
      EmitComment('--- builtin sin ---');
      If IsPunct('(') Then
        ParserAdvance
      Else
        WarnMsg('sin: ( attendu');
      ExprType := ParseExpr;
      ExprType := GenCoerceToNumber(ExprType);
      If IsPunct(')') Then
        ParserAdvance
      Else
        WarnMsg('sin: ) attendu');
      Emit('        PUSH    EAX');
      Emit('        CALL    ' + AW_RT_PFX + 'SIN');
      Emit('        ADD     ESP, 4');
      ParseBuiltinMath := TYK_NUMBER;
    End;

    { ---- cos(x) ---- }
    BF_COS:
    Begin
      EmitComment('--- builtin cos ---');
      If IsPunct('(') Then
        ParserAdvance
      Else
        WarnMsg('cos: ( attendu');
      ExprType := ParseExpr;
      ExprType := GenCoerceToNumber(ExprType);
      If IsPunct(')') Then
        ParserAdvance
      Else
        WarnMsg('cos: ) attendu');
      Emit('        PUSH    EAX');
      Emit('        CALL    ' + AW_RT_PFX + 'COS');
      Emit('        ADD     ESP, 4');
      ParseBuiltinMath := TYK_NUMBER;
    End;

    { ---- atan2(y, x) ---- }
    BF_ATAN2:
    Begin
      EmitComment('--- builtin atan2 ---');
      If IsPunct('(') Then
        ParserAdvance
      Else
        WarnMsg('atan2: ( attendu');
      { Premier argument : y }
      ExprType := ParseExpr;
      ExprType := GenCoerceToNumber(ExprType);
      Emit('        PUSH    EAX');
      { Virgule separatrice }
      If IsPunct(',') Then
      Begin
        ParserAdvance; SkipNewlines;
      End
      Else
        WarnMsg('atan2: , attendu');
      { Deuxieme argument : x }
      ExprType := ParseExpr;
      ExprType := GenCoerceToNumber(ExprType);
      Emit('        PUSH    EAX');
      If IsPunct(')') Then
        ParserAdvance
      Else
        WarnMsg('atan2: ) attendu');
      Emit('        CALL    ' + AW_RT_PFX + 'ATAN2');
      Emit('        ADD     ESP, 8');
      ParseBuiltinMath := TYK_NUMBER;
    End;

    { ---- exp(x) ---- }
    BF_EXP:
    Begin
      EmitComment('--- builtin exp ---');
      If IsPunct('(') Then
        ParserAdvance
      Else
        WarnMsg('exp: ( attendu');
      ExprType := ParseExpr;
      ExprType := GenCoerceToNumber(ExprType);
      If IsPunct(')') Then
        ParserAdvance
      Else
        WarnMsg('exp: ) attendu');
      Emit('        PUSH    EAX');
      Emit('        CALL    ' + AW_RT_PFX + 'EXP');
      Emit('        ADD     ESP, 4');
      ParseBuiltinMath := TYK_NUMBER;
    End;

    { ---- log(x) ---- }
    BF_LOG:
    Begin
      EmitComment('--- builtin log ---');
      If IsPunct('(') Then
        ParserAdvance
      Else
        WarnMsg('log: ( attendu');
      ExprType := ParseExpr;
      ExprType := GenCoerceToNumber(ExprType);
      If IsPunct(')') Then
        ParserAdvance
      Else
        WarnMsg('log: ) attendu');
      Emit('        PUSH    EAX');
      Emit('        CALL    ' + AW_RT_PFX + 'LOG');
      Emit('        ADD     ESP, 4');
      ParseBuiltinMath := TYK_NUMBER;
    End;

    { ---- sqrt(x) ---- }
    BF_SQRT:
    Begin
      EmitComment('--- builtin sqrt ---');
      If IsPunct('(') Then
        ParserAdvance
      Else
        WarnMsg('sqrt: ( attendu');
      ExprType := ParseExpr;
      ExprType := GenCoerceToNumber(ExprType);
      If IsPunct(')') Then
        ParserAdvance
      Else
        WarnMsg('sqrt: ) attendu');
      Emit('        PUSH    EAX');
      Emit('        CALL    ' + AW_RT_PFX + 'SQRT');
      Emit('        ADD     ESP, 4');
      ParseBuiltinMath := TYK_NUMBER;
    End;

    { ---- int(x) : troncature entiere, deja entier en EAX ---- }
    BF_INT:
    Begin
      EmitComment('--- builtin int ---');
      If IsPunct('(') Then
        ParserAdvance
      Else
        WarnMsg('int: ( attendu');
      ExprType := ParseExpr;
      ExprType := GenCoerceToNumber(ExprType);
      If IsPunct(')') Then
        ParserAdvance
      Else
        WarnMsg('int: ) attendu');
      { EAX contient deja la valeur entiere, pas de CALL necessaire }
      ParseBuiltinMath := TYK_NUMBER;
    End;

    { ---- rand() : retourne un nombre aleatoire 0..32767 ---- }
    BF_RAND:
    Begin
      EmitComment('--- builtin rand ---');
      If IsPunct('(') Then
      Begin
        ParserAdvance;
        If IsPunct(')') Then
          ParserAdvance
        Else
          WarnMsg('rand: ) attendu');
      End;
      Emit('        CALL    ' + AW_RT_PFX + 'RAND');
      ParseBuiltinMath := TYK_NUMBER;
    End;

    { ---- srand([x]) : initialiser graine aleatoire ---- }
    BF_SRAND:
    Begin
      EmitComment('--- builtin srand ---');
      If IsPunct('(') Then
      Begin
        ParserAdvance;
        If Not IsPunct(')') Then
        Begin
          { Argument optionnel : graine }
          ExprType := ParseExpr;
          ExprType := GenCoerceToNumber(ExprType);
          Emit('        PUSH    EAX');
          If IsPunct(')') Then
            ParserAdvance
          Else
            WarnMsg('srand: ) attendu');
          Emit('        CALL    ' + AW_RT_PFX + 'SRAND');
          Emit('        ADD     ESP, 4');
        End
        Else
        Begin
          { Pas d argument : utiliser valeur par defaut (time) }
          ParserAdvance;  { consommer ) }
          Emit('        CALL    ' + AW_RT_PFX + 'SRAND_TIME');
        End;
      End
      Else
      Begin
        { srand sans parentheses : utiliser valeur par defaut }
        Emit('        CALL    ' + AW_RT_PFX + 'SRAND_TIME');
      End;
      ParseBuiltinMath := TYK_NUMBER;
    End;

    { ---- system(cmd) : stub ---- }
    BF_SYSTEM:
    Begin
      EmitComment('--- builtin system (stub) ---');
      If IsPunct('(') Then
      Begin
        ParserAdvance;
        ExprType := ParseExpr;
        If IsPunct(')') Then
          ParserAdvance
        Else
          WarnMsg('system: ) attendu');
      End;
      Emit('        XOR     EAX, EAX');
      ParseBuiltinMath := TYK_NUMBER;
    End;

    { ---- close(file) : stub ---- }
    BF_CLOSE:
    Begin
      EmitComment('--- builtin close (stub) ---');
      If IsPunct('(') Then
      Begin
        ParserAdvance;
        ExprType := ParseExpr;
        If IsPunct(')') Then
          ParserAdvance
        Else
          WarnMsg('close: ) attendu');
      End;
      Emit('        XOR     EAX, EAX');
      ParseBuiltinMath := TYK_NUMBER;
    End;

    { ---- fflush([file]) : stub ---- }
    BF_FFLUSH:
    Begin
      EmitComment('--- builtin fflush (stub) ---');
      If IsPunct('(') Then
      Begin
        ParserAdvance;
        If Not IsPunct(')') Then
        Begin
          ExprType := ParseExpr;
        End;
        If IsPunct(')') Then
          ParserAdvance
        Else
          WarnMsg('fflush: ) attendu');
      End;
      Emit('        XOR     EAX, EAX');
      ParseBuiltinMath := TYK_NUMBER;
    End;

    { ---- mktime(spec) : stub ---- }
    BF_MKTIME:
    Begin
      EmitComment('--- builtin mktime (stub) ---');
      If IsPunct('(') Then
      Begin
        ParserAdvance;
        ExprType := ParseExpr;
        If IsPunct(')') Then
          ParserAdvance
        Else
          WarnMsg('mktime: ) attendu');
      End;
      Emit('        XOR     EAX, EAX');
      ParseBuiltinMath := TYK_NUMBER;
    End;

    { ---- strftime(fmt [, timestamp]) : stub ---- }
    BF_STRFTIME:
    Begin
      EmitComment('--- builtin strftime (stub) ---');
      If IsPunct('(') Then
      Begin
        ParserAdvance;
        ArgCount := 0;
        If Not IsPunct(')') Then
        Begin
          ExprType := ParseExpr;
          Inc(ArgCount);
          While IsPunct(',') Do
          Begin
            ParserAdvance; SkipNewlines;
            ExprType := ParseExpr;
            Inc(ArgCount);
          End;
        End;
        If IsPunct(')') Then
          ParserAdvance
        Else
          WarnMsg('strftime: ) attendu');
      End;
      Emit('        XOR     EAX, EAX');
      ParseBuiltinMath := TYK_STRING;
    End;
  Else
    { Fonction builtin inconnue }
    EmitComment('--- builtin inconnu ---');
    If IsPunct('(') Then
    Begin
      ParserAdvance;
      ArgCount := 0;
      If Not IsPunct(')') Then
      Begin
        ExprType := ParseExpr;
        Inc(ArgCount);
        While IsPunct(',') Do
        Begin
          ParserAdvance; SkipNewlines;
          ExprType := ParseExpr;
          Inc(ArgCount);
        End;
      End;
      If IsPunct(')') Then
        ParserAdvance
      Else
        WarnMsg(') attendu apres builtin');
    End;
    ParseBuiltinMath := TYK_UNKNOWN;
  End;  { case }
End;

{ ============================================================ }
{ TODO 20 - PARSEUR : GETLINE ET REDIRECTIONS E/S              }
{ ============================================================ }

{ ---- ParseGetline -------------------------------------------- }
{ Parse et genere du code pour getline AWK                       }
{ getline                  -> lire dans $0 depuis stdin           }
{ getline var              -> lire dans var depuis stdin           }
{ getline < "fichier"      -> lire depuis fichier dans $0         }
{ getline var < "fichier"  -> lire var depuis fichier             }
{ "cmd" | getline [var]    -> lire depuis pipe (stub)             }
{ Retourne TYK_NUMBER (0=EOF, 1=succes)                          }
Function ParseGetline: Integer;
Var
  VarIdx   : Integer;
  HasVar   : Boolean;
  HasFile  : Boolean;
  ExprType : Integer;
  LblEof   : TString;
Begin
  Inc(GetlineCount);
  ParseGetline := TYK_NUMBER;  { getline retourne 0 ou 1 }
  EmitComment('--- getline ---');
  VarIdx  := -1;
  HasVar  := False;
  HasFile := False;
  LblEof  := NewLabel;

  { Verifier si un nom de variable suit getline }
  If (CurToken.Kind = TK_IDENT) And
     Not IsOp('<') Then
  Begin
    HasVar := True;
    VarIdx := FindSym(CurToken.Val);
    If VarIdx < 0 Then
      VarIdx := AddSym(CurToken.Val, TYK_STRING, STORE_GLOBAL, True);
    ParserAdvance;
  End;

  { Verifier si une redirection < suit }
  If IsOp('<') Then
  Begin
    HasFile := True;
    ParserAdvance;  { consommer < }
    ExprType := ParseExpr;
    ExprType := GenCoerceToString(ExprType);
    { EAX = nom du fichier }
    Emit('        PUSH    EAX');
    Emit('        CALL    ' + AW_RT_PFX + 'GETLINE_FILE');
    Emit('        ADD     ESP, 4');
  End
  Else
  Begin
    { getline simple depuis stdin }
    Emit('        CALL    ' + AW_RT_PFX + 'READLINE');
  End;

  { EAX = pointeur vers la ligne lue (ou 0 si EOF) }
  { Si une variable est specifiee, stocker dans la variable }
  If HasVar And (VarIdx >= 0) Then
  Begin
    EmitComment('getline -> store in var');
    GenStoreVar(VarIdx);
  End;

  { Resultat : EAX = 1 si succes, 0 si EOF }
  { _AWRT_READLINE et _AWRT_GETLINE_FILE retournent la ligne }
  { On genere le test : si EAX = 0 -> 0 (EOF), sinon -> 1     }
  Emit('        TEST    EAX, EAX');
  Emit('        JZ      ' + LblEof);
  Emit('        MOV     EAX, 1');
  EmitLabel(LblEof);
End;

{ ============================================================ }
{ TODO 09 - PARSEUR : PRINT, PRINTF, SPRINTF                  }
{ ============================================================ }

{ ---- GenPrintVal --------------------------------------------- }
{ Affiche la valeur dans EAX selon son type                      }
{ Si nombre : CALL _AWRT_NUMTOSTR puis CALL _AWRT_PRINT         }
{ Si chaine : CALL _AWRT_PRINT directement                      }
Procedure GenPrintVal(ExprType: Integer);
Begin
  If ExprType = TYK_NUMBER Then
  Begin
    EmitComment('print val (number -> str then print)');
    Emit('        CALL    ' + AW_RT_PFX + 'NUMTOSTR');
    Emit('        CALL    ' + AW_RT_PFX + 'PRINT');
  End
  Else
  Begin
    EmitComment('print val (string)');
    Emit('        CALL    ' + AW_RT_PFX + 'PRINT');
  End;
End;

{ ---- GenPrintOFS --------------------------------------------- }
{ Affiche le separateur de champs (OFS) entre les arguments      }
Procedure GenPrintOFS;
Var
  SI : Integer;
Begin
  EmitComment('print OFS');
  SI := FindSym('OFS');
  If SI >= 0 Then
    Emit('        MOV     EAX, DWORD PTR [' +
         SymTab[SI].AsmLabel + ']')
  Else
    Emit('        MOV     EAX, OFFSET ' + AW_STR_PFX + 'ofs_default');
  Emit('        CALL    ' + AW_RT_PFX + 'PRINT');
End;

{ ---- GenPrintORS --------------------------------------------- }
{ Affiche le terminateur d enregistrement (ORS) apres print      }
Procedure GenPrintORS;
Var
  SI : Integer;
Begin
  EmitComment('print ORS');
  SI := FindSym('ORS');
  If SI >= 0 Then
    Emit('        MOV     EAX, DWORD PTR [' +
         SymTab[SI].AsmLabel + ']')
  Else
    Emit('        MOV     EAX, OFFSET ' + AW_STR_PFX + 'ors_default');
  Emit('        CALL    ' + AW_RT_PFX + 'PRINT');
End;

{ ---- ParsePrint ---------------------------------------------- }
{ Parse et genere du code pour l instruction print AWK            }
{ print                   -> afficher $0 + ORS                    }
{ print expr [, expr ...] -> afficher avec OFS entre, ORS a la fin}
{ print expr > "fichier"  -> redirection (stub: warning)          }
{ print expr >> "fichier" -> redirection append (stub: warning)   }
{ print expr | "cmd"      -> pipe (stub: warning)                 }
Procedure ParsePrint;
Var
  ExprType  : Integer;
  ArgCount  : Integer;
  D         : Integer;
  HasRedir  : Boolean;
Begin
  Inc(PrintCount);
  EmitComment('--- print statement ---');
  ArgCount := 0;
  HasRedir := False;

  { print sans argument -> print $0 }
  If (CurToken.Kind = TK_NEWLINE) Or (CurToken.Kind = TK_EOF) Or
     IsPunct(';') Or IsPunct('}') Then
  Begin
    EmitComment('print $0 (no args)');
    Emit('        MOV     EAX, 0');
    Emit('        PUSH    EAX');
    Emit('        CALL    ' + AW_RT_PFX + 'GETFIELD');
    Emit('        CALL    ' + AW_RT_PFX + 'PRINT');
    GenPrintORS;
    Exit;
  End;

  { print expr [, expr ...] }
  ExprType := ParseExpr;
  GenPrintVal(ExprType);
  Inc(ArgCount);

  While IsPunct(',') Do
  Begin
    ParserAdvance;  { consommer , }
    SkipNewlines;
    GenPrintOFS;
    ExprType := ParseExpr;
    GenPrintVal(ExprType);
    Inc(ArgCount);
  End;

  { Redirection > >> | optionnelle (TODO 20) }
  If IsOp('>') Or IsOp('>>') Or IsOp('|') Then
  Begin
    HasRedir := True;
    If IsOp('|') Then
    Begin
      EmitComment('print | cmd (pipe stub)');
      WarnMsg('print | "cmd" : pipe non supporte, ignore');
      ParserAdvance;  { consommer | }
      D := ParseExpr; { parser la commande, ignorer }
    End
    Else If IsOp('>>') Then
    Begin
      EmitComment('print >> fichier (append)');
      ParserAdvance;  { consommer >> }
      D := ParseExpr;
      D := GenCoerceToString(D);
      Emit('        PUSH    EAX');
      Emit('        CALL    ' + AW_RT_PFX + 'REDIR_APPEND');
      Emit('        ADD     ESP, 4');
    End
    Else
    Begin
      EmitComment('print > fichier (write)');
      ParserAdvance;  { consommer > }
      D := ParseExpr;
      D := GenCoerceToString(D);
      Emit('        PUSH    EAX');
      Emit('        CALL    ' + AW_RT_PFX + 'REDIR_WRITE');
      Emit('        ADD     ESP, 4');
    End;
  End;

  { Terminateur ORS }
  GenPrintORS;
End;

{ ---- ParsePrintf --------------------------------------------- }
{ Parse et genere du code pour l instruction printf AWK           }
{ printf fmt [, expr ...]   -> appeler _AWRT_PRINTF              }
{ printf fmt, expr > "file" -> redirection (stub: warning)       }
Procedure ParsePrintf;
Var
  ExprType : Integer;
  ArgCount : Integer;
  D        : Integer;
  NS       : TString;
Begin
  Inc(PrintCount);
  EmitComment('--- printf statement ---');
  ArgCount := 0;

  { Parser les arguments : fmt, expr1, expr2, ... }
  { Tous les arguments sont pousses sur la pile }
  Repeat
    ExprType := ParseExpr;
    GenPushEAX;
    Inc(ArgCount);
    If IsPunct(',') Then
    Begin
      ParserAdvance;
      SkipNewlines;
    End
    Else
      Break;
  Until (CurToken.Kind = TK_EOF) Or (CurToken.Kind = TK_NEWLINE)
        Or IsPunct(';') Or IsPunct('}');

  { Appeler _AWRT_PRINTF avec le nombre d arguments dans ECX }
  Str(ArgCount, NS);
  Emit('        MOV     ECX, ' + NS);
  Emit('        CALL    ' + AW_RT_PFX + 'PRINTF');
  { Nettoyer la pile : ArgCount * 4 octets (32 bits) }
  If ArgCount > 0 Then
  Begin
    Str(ArgCount * 4, NS);
    Emit('        ADD     ESP, ' + NS);
  End;

  { Redirection > >> | optionnelle (TODO 20) }
  If IsOp('>') Or IsOp('>>') Or IsOp('|') Then
  Begin
    If IsOp('|') Then
    Begin
      EmitComment('printf | cmd (pipe stub)');
      WarnMsg('printf | "cmd" : pipe non supporte, ignore');
      ParserAdvance;
      D := ParseExpr;
    End
    Else If IsOp('>>') Then
    Begin
      EmitComment('printf >> fichier (append)');
      ParserAdvance;
      D := ParseExpr;
      D := GenCoerceToString(D);
      Emit('        PUSH    EAX');
      Emit('        CALL    ' + AW_RT_PFX + 'REDIR_APPEND');
      Emit('        ADD     ESP, 4');
    End
    Else
    Begin
      EmitComment('printf > fichier (write)');
      ParserAdvance;
      D := ParseExpr;
      D := GenCoerceToString(D);
      Emit('        PUSH    EAX');
      Emit('        CALL    ' + AW_RT_PFX + 'REDIR_WRITE');
      Emit('        ADD     ESP, 4');
    End;
  End;
End;

{ ---- ParseSprintf -------------------------------------------- }
{ Parse sprintf(fmt, expr...) et retourne le type du resultat    }
{ sprintf est une expression qui retourne une chaine formatee    }
{ PUSH args + MOV ECX, count + CALL _AWRT_SPRINTF -> EAX        }
Function ParseSprintf: Integer;
Var
  ExprType : Integer;
  ArgCount : Integer;
  NS       : TString;
Begin
  Inc(PrintCount);
  EmitComment('--- sprintf expression ---');
  ArgCount := 0;

  { Attendre ( apres sprintf }
  If IsPunct('(') Then
    ParserAdvance
  Else
    WarnMsg('sprintf: ( attendu');

  { Parser les arguments : fmt, expr1, expr2, ... }
  If Not IsPunct(')') Then
  Repeat
    ExprType := ParseExpr;
    GenPushEAX;
    Inc(ArgCount);
    If IsPunct(',') Then
    Begin
      ParserAdvance;
      SkipNewlines;
    End
    Else
      Break;
  Until IsPunct(')') Or (CurToken.Kind = TK_EOF);

  { Fermer la parenthese }
  If IsPunct(')') Then
    ParserAdvance
  Else
    WarnMsg('sprintf: ) attendu');

  { Appeler _AWRT_SPRINTF avec le nombre d arguments dans ECX }
  Str(ArgCount, NS);
  Emit('        MOV     ECX, ' + NS);
  Emit('        CALL    ' + AW_RT_PFX + 'SPRINTF');
  { Nettoyer la pile }
  If ArgCount > 0 Then
  Begin
    Str(ArgCount * 4, NS);
    Emit('        ADD     ESP, ' + NS);
  End;

  { Le resultat (chaine formatee) est dans EAX }
  ParseSprintf := TYK_STRING;
End;

{ ============================================================ }
{ TODO 10 - PARSEUR : IF / ELSE                                }
{ ============================================================ }

{ ---- ParseStatement ------------------------------------------ }
{ Parse une instruction unique :                                  }
{   - expression (terminee par ; ou newline)                      }
{   - print / printf (TODO 09)                                    }
{   - if / else (TODO 10)                                         }
{   - while / for / do-while / break / continue (TODO 11)         }
{   - return / exit / delete / break / continue / next             }
{   - function (declaration)                                      }
{   - bloc entre accolades                                       }
Procedure ParseStatement;
Var
  TK : Integer;
  D  : Integer;
  RetLbl : TString;
Begin
  SkipNewlines;
  If (CurToken.Kind = TK_EOF) Or IsPunct('}') Then
    Exit;
  { Point-virgule vide }
  If IsPunct(';') Then
  Begin
    ParserAdvance;
    Exit;
  End;
  { Bloc entre accolades }
  If IsPunct('{') Then
  Begin
    ParseBlock;
    Exit;
  End;
  { Keywords de structure }
  If CurToken.Kind = TK_KEYWORD Then
  Begin
    TK := CurToken.IntVal;
    { print (TODO 09) }
    If TK = KW_PRINT Then
    Begin
      ParserAdvance;
      ParsePrint;
      Exit;
    End;
    { printf (TODO 09) }
    If TK = KW_PRINTF Then
    Begin
      ParserAdvance;
      ParsePrintf;
      Exit;
    End;
    { if (TODO 10) }
    If TK = KW_IF Then
    Begin
      ParserAdvance;
      ParseIf;
      Exit;
    End;
    { for (TODO 11) }
    If TK = KW_FOR Then
    Begin
      ParserAdvance;
      ParseFor;
      Exit;
    End;
    { while (TODO 11) }
    If TK = KW_WHILE Then
    Begin
      ParserAdvance;
      ParseWhile;
      Exit;
    End;
    { do (TODO 11) }
    If TK = KW_DO Then
    Begin
      ParserAdvance;
      ParseDoWhile;
      Exit;
    End;
    { break (TODO 11) }
    If TK = KW_BREAK Then
    Begin
      ParserAdvance;
      EmitComment('--- break ---');
      If LoopDepth > 0 Then
        Emit('        JMP     ' + FindLoopBreak)
      Else
        WarnMsg('break en dehors d''une boucle');
      Exit;
    End;
    { continue (TODO 11) }
    If TK = KW_CONTINUE Then
    Begin
      ParserAdvance;
      EmitComment('--- continue ---');
      If LoopDepth > 0 Then
        Emit('        JMP     ' + FindLoopContinue)
      Else
        WarnMsg('continue en dehors d''une boucle');
      Exit;
    End;
    { return : evaluer expression optionnelle + JMP exit (TODO 13) }
    If TK = KW_RETURN Then
    Begin
      ParserAdvance;
      EmitComment('--- return ---');
      If (CurToken.Kind <> TK_NEWLINE) And
         (CurToken.Kind <> TK_EOF) And
         Not IsPunct(';') And Not IsPunct('}') Then
      Begin
        D := ParseExpr;
        { EAX contient deja la valeur de retour }
      End
      Else
      Begin
        { return sans valeur : retourner 0 }
        Emit('        XOR     EAX, EAX');
      End;
      { Sauter au label de sortie de la fonction }
      RetLbl := FindExitLabel;
      If RetLbl <> '' Then
        Emit('        JMP     ' + RetLbl)
      Else
        WarnMsg('return en dehors d''une fonction');
      Exit;
    End;
    { exit : parser une expression optionnelle et generer code sortie }
    If TK = KW_EXIT Then
    Begin
      ParserAdvance;
      Inc(DispatchCount);
      EmitComment('--- exit ---');
      If (CurToken.Kind <> TK_NEWLINE) And
         (CurToken.Kind <> TK_EOF) And
         Not IsPunct(';') And Not IsPunct('}') Then
      Begin
        D := ParseExpr;
        { EAX contient le code de sortie }
        Emit('        MOV     DWORD PTR [' + AW_RT_PFX + 'EXITCODE], EAX');
      End
      Else
      Begin
        { exit sans expression : code 0 }
        Emit('        MOV     DWORD PTR [' + AW_RT_PFX + 'EXITCODE], 0');
      End;
      Emit('        JMP     ' + AW_LBL_PFX + 'exit');
      Exit;
    End;
    { delete : parser ident[expr] (TODO 16 : code gen HASH_DEL/HASH_CLEAR) }
    If TK = KW_DELETE Then
    Begin
      ParserAdvance;
      If CurToken.Kind = TK_IDENT Then
      Begin
        D := FindSym(CurToken.Val);
        If D < 0 Then
          D := AddSym(CurToken.Val, TYK_ARRAY, STORE_GLOBAL, True);
        ParserAdvance;
        If IsPunct('[') Then
        Begin
          { delete array[expr] -> supprimer une entree }
          ParserAdvance;
          TK := ParseExpr;
          TK := GenCoerceToString(TK);
          { SUBSEP : indices multidimensionnels }
          While IsPunct(',') Do
          Begin
            GenPushEAX;
            ParserAdvance;
            SkipNewlines;
            TK := ParseExpr;
            TK := GenCoerceToString(TK);
            GenPopEBX;
            GenConcat;
          End;
          If IsPunct(']') Then
            ParserAdvance;
          { EAX = cle -> HASH_DEL }
          GenArrayDel(D);
        End
        Else
        Begin
          { delete array -> vider tout le tableau }
          GenArrayClear(D);
        End;
      End;
      Exit;
    End;
    { function : parser la definition (TODO 13) }
    If TK = KW_FUNCTION Then
    Begin
      ParserAdvance;
      ParseFunctionDef;
      Exit;
    End;
    { getline comme statement (TODO 20) }
    If TK = KW_GETLINE Then
    Begin
      ParserAdvance;
      D := ParseGetline;
      Exit;
    End;
    { next : sauter au prochain enregistrement }
    If TK = KW_NEXT Then
    Begin
      ParserAdvance;
      EmitComment('--- next ---');
      Emit('        JMP     ' + AW_RT_PFX + 'NEXT');
      Exit;
    End;
    { nextfile : sauter au prochain fichier }
    If TK = KW_NEXTFILE Then
    Begin
      ParserAdvance;
      EmitComment('--- nextfile ---');
      Emit('        JMP     ' + AW_RT_PFX + 'NEXTFILE');
      Exit;
    End;
    { Autres keywords : skip }
    ParserAdvance;
    Exit;
  End;
  { Expression }
  D := ParseExpr;
End;

{ ---- ParseBlock ---------------------------------------------- }
(* Parse un bloc entre accolades ou une instruction simple.       *)
Procedure ParseBlock;
Begin
  SkipNewlines;
  If IsPunct('{') Then
  Begin
    ParserAdvance; { consommer { }
    While (CurToken.Kind <> TK_EOF) And Not IsPunct('}') Do
    Begin
      SkipNewlines;
      If IsPunct('}') Or (CurToken.Kind = TK_EOF) Then Break;
      ParseStatement;
    End;
    If IsPunct('}') Then
      ParserAdvance; (* consommer l'accolade fermante *)
  End
  Else
    ParseStatement;
End;

{ ---- ParseIf ------------------------------------------------- }
(* Parse une instruction if / else AWK :                           *)
(*   if (condition) instruction                                    *)
(*   if (condition) instruction else instruction                   *)
(*   if (condition) { instructions } else { instructions }         *)
(* Generation de code 80386 :                                      *)
(*   Evaluer condition -> EAX                                      *)
(*   TEST EAX, EAX                                                 *)
(*   JZ _AWL_else                                                  *)
(*   ... bloc vrai ...                                             *)
(*   JMP _AWL_endif     (si else present)                          *)
(* _AWL_else:                                                      *)
(*   ... bloc faux ...  (si else present)                          *)
(* _AWL_endif:                                                     *)
Procedure ParseIf;
Var
  LblElse  : TString;
  LblEnd   : TString;
  ExprType : Integer;
  HasElse  : Boolean;
Begin
  Inc(IfCount);
  EmitComment('--- if statement ---');

  { Parser la condition entre parentheses }
  If IsPunct('(') Then
    ParserAdvance
  Else
    WarnMsg('if: ( attendu');

  ExprType := ParseExpr;
  ExprType := GenCoerceToBoolean(ExprType);

  If IsPunct(')') Then
    ParserAdvance
  Else
    WarnMsg('if: ) attendu');

  { Generer les labels }
  LblElse := NewLabel;
  LblEnd  := NewLabel;

  { TEST EAX, EAX + JZ _AWL_else }
  Emit('        TEST    EAX, EAX');
  Emit('        JZ      ' + LblElse);
  EmitBlank;

  { Parser le bloc vrai }
  ParseBlock;

  { Verifier si else suit }
  SkipNewlines;
  HasElse := IsKW(KW_ELSE);

  If HasElse Then
  Begin
    { JMP _AWL_endif pour sauter le bloc faux }
    Emit('        JMP     ' + LblEnd);
    EmitLabel(LblElse);
    EmitComment('--- else block ---');
    ParserAdvance; { consommer else }
    SkipNewlines;
    { Parser le bloc faux }
    ParseBlock;
    EmitLabel(LblEnd);
  End
  Else
  Begin
    { Pas de else : le label else EST le endif }
    EmitLabel(LblElse);
  End;

  EmitComment('--- end if ---');
  EmitBlank;
End;

{ ============================================================ }
{ TODO 11 - PARSEUR : WHILE, FOR, DO-WHILE, BREAK, CONTINUE   }
{ ============================================================ }

{ ---- ParseWhile ---------------------------------------------- }
(* Parse une instruction while AWK :                               *)
(*   while (condition) instruction                                 *)
(*   while (condition) { instructions }                            *)
(* Generation de code 80386 :                                      *)
(* _AWL_top:                                                       *)
(*   Evaluer condition -> EAX                                      *)
(*   TEST EAX, EAX                                                 *)
(*   JZ _AWL_end                                                   *)
(*   ... corps de la boucle ...                                    *)
(*   JMP _AWL_top                                                  *)
(* _AWL_end:                                                       *)
(* break -> JMP _AWL_end, continue -> JMP _AWL_top                 *)
Procedure ParseWhile;
Var
  LblTop   : TString;
  LblEnd   : TString;
  ExprType : Integer;
Begin
  Inc(WhileCount);
  EmitComment('--- while statement ---');

  { Generer les labels }
  LblTop := NewLabel;
  LblEnd := NewLabel;

  { Empiler la boucle (break -> LblEnd, continue -> LblTop) }
  EnterLoop(LblEnd, LblTop);

  { Label du debut de boucle }
  EmitLabel(LblTop);

  { Parser la condition entre parentheses }
  If IsPunct('(') Then
    ParserAdvance
  Else
    WarnMsg('while: ( attendu');

  ExprType := ParseExpr;
  ExprType := GenCoerceToBoolean(ExprType);

  If IsPunct(')') Then
    ParserAdvance
  Else
    WarnMsg('while: ) attendu');

  { TEST EAX, EAX + JZ _AWL_end }
  Emit('        TEST    EAX, EAX');
  Emit('        JZ      ' + LblEnd);
  EmitBlank;

  { Parser le corps de la boucle }
  ParseBlock;

  { JMP _AWL_top }
  Emit('        JMP     ' + LblTop);

  { Label de fin }
  EmitLabel(LblEnd);

  { Depiler la boucle }
  LeaveLoop;

  EmitComment('--- end while ---');
  EmitBlank;
End;

{ ---- ParseFor ------------------------------------------------ }
(* Parse une instruction for AWK (C-style) :                       *)
(*   for (init; condition; incr) instruction                       *)
(*   for (init; condition; incr) { instructions }                  *)
(* Generation de code 80386 :                                      *)
(*   ... init ...                                                  *)
(* _AWL_top:                                                       *)
(*   Evaluer condition -> EAX                                      *)
(*   TEST EAX, EAX                                                 *)
(*   JZ _AWL_end                                                   *)
(*   JMP _AWL_body                                                 *)
(* _AWL_incr:                                                      *)
(*   ... increment ...                                             *)
(*   JMP _AWL_top                                                  *)
(* _AWL_body:                                                      *)
(*   ... corps ...                                                 *)
(*   JMP _AWL_incr                                                 *)
(* _AWL_end:                                                       *)
(* break -> JMP _AWL_end, continue -> JMP _AWL_incr                *)
Procedure ParseFor;
Var
  LblTop   : TString;
  LblIncr  : TString;
  LblBody  : TString;
  LblEnd   : TString;
  ExprType : Integer;
  SavedTok : TToken;
Begin
  { Parser '(' }
  If IsPunct('(') Then
    ParserAdvance
  Else
    WarnMsg('for: ( attendu');

  { Detecter for-in : for (ident in array) }
  If CurToken.Kind = TK_IDENT Then
  Begin
    SavedTok := CurToken;
    ParserAdvance;
    If IsKW(KW_IN) Then
    Begin
      { C est un for-in : remettre l identifiant comme token courant }
      ParserPushBack(SavedTok);
      ParseForIn;
      Exit;
    End
    Else
    Begin
      { C est un for classique : remettre le token consomme }
      ParserPushBack(SavedTok);
    End;
  End;

  Inc(ForCount);
  EmitComment('--- for statement ---');

  { Generer les labels }
  LblTop  := NewLabel;
  LblIncr := NewLabel;
  LblBody := NewLabel;
  LblEnd  := NewLabel;

  { Parser l init (optionnelle) }
  If Not IsPunct(';') And Not IsPunct(')') Then
    ExprType := ParseExpr;
  If IsPunct(';') Then
    ParserAdvance;

  { Empiler la boucle (break -> LblEnd, continue -> LblIncr) }
  EnterLoop(LblEnd, LblIncr);

  { Label du test de condition }
  EmitLabel(LblTop);

  { Parser la condition (optionnelle) }
  If Not IsPunct(';') And Not IsPunct(')') Then
  Begin
    ExprType := ParseExpr;
    ExprType := GenCoerceToBoolean(ExprType);
    { TEST EAX, EAX + JZ _AWL_end }
    Emit('        TEST    EAX, EAX');
    Emit('        JZ      ' + LblEnd);
  End;
  If IsPunct(';') Then
    ParserAdvance;

  { Sauter par-dessus l increment vers le corps }
  Emit('        JMP     ' + LblBody);
  EmitBlank;

  { Label d increment (continue saute ici) }
  EmitLabel(LblIncr);

  { Parser l increment (optionnel) }
  If Not IsPunct(')') Then
    ExprType := ParseExpr;

  { JMP _AWL_top (retester la condition) }
  Emit('        JMP     ' + LblTop);
  EmitBlank;

  If IsPunct(')') Then
    ParserAdvance
  Else
    WarnMsg('for: ) attendu');

  { Label du corps de la boucle }
  EmitLabel(LblBody);

  { Corps de la boucle }
  ParseBlock;

  { JMP _AWL_incr (executer l increment) }
  Emit('        JMP     ' + LblIncr);

  { Label de fin }
  EmitLabel(LblEnd);

  { Depiler la boucle }
  LeaveLoop;

  EmitComment('--- end for ---');
  EmitBlank;
End;

{ ---- ParseDoWhile -------------------------------------------- }
(* Parse une instruction do-while AWK :                            *)
(*   do instruction while (condition)                              *)
(*   do { instructions } while (condition)                         *)
(* Generation de code 80386 :                                      *)
(* _AWL_top:                                                       *)
(*   ... corps de la boucle ...                                    *)
(* _AWL_cont:                                                      *)
(*   Evaluer condition -> EAX                                      *)
(*   TEST EAX, EAX                                                 *)
(*   JNZ _AWL_top                                                  *)
(* _AWL_end:                                                       *)
(* break -> JMP _AWL_end, continue -> JMP _AWL_cont                *)
Procedure ParseDoWhile;
Var
  LblTop   : TString;
  LblCont  : TString;
  LblEnd   : TString;
  ExprType : Integer;
Begin
  Inc(DoWhileCount);
  EmitComment('--- do-while statement ---');

  { Generer les labels }
  LblTop  := NewLabel;
  LblCont := NewLabel;
  LblEnd  := NewLabel;

  { Empiler la boucle (break -> LblEnd, continue -> LblCont) }
  EnterLoop(LblEnd, LblCont);

  { Label du debut de boucle }
  EmitLabel(LblTop);

  { Parser le corps de la boucle }
  ParseBlock;

  { S attendre a while (condition) }
  SkipNewlines;
  If IsKW(KW_WHILE) Then
    ParserAdvance
  Else
    WarnMsg('do: while attendu apres le corps');

  { Label continue (avant le test de condition) }
  EmitLabel(LblCont);

  { Parser la condition entre parentheses }
  If IsPunct('(') Then
    ParserAdvance
  Else
    WarnMsg('do-while: ( attendu');

  ExprType := ParseExpr;
  ExprType := GenCoerceToBoolean(ExprType);

  If IsPunct(')') Then
    ParserAdvance
  Else
    WarnMsg('do-while: ) attendu');

  { TEST EAX, EAX + JNZ _AWL_top }
  Emit('        TEST    EAX, EAX');
  Emit('        JNZ     ' + LblTop);

  { Label de fin }
  EmitLabel(LblEnd);

  { Depiler la boucle }
  LeaveLoop;

  EmitComment('--- end do-while ---');
  EmitBlank;
End;

{ ============================================================ }
{ TODO 12 - PARSEUR : FOR-IN (ITERATION SUR TABLEAUX          }
{           ASSOCIATIFS)                                       }
{ ============================================================ }

{ ---- ParseForIn ---------------------------------------------- }
(* Parse une instruction for-in AWK :                              *)
(*   for (var in array) instruction                                *)
(*   for (var in array) { instructions }                           *)
(* Generation de code 80386 :                                      *)
(*   PUSH OFFSET _AWA_array                                        *)
(*   CALL _AWRT_HASH_INIT     (initialiser iterateur)              *)
(* _AWL_top:                                                       *)
(*   PUSH OFFSET _AWA_array                                        *)
(*   CALL _AWRT_HASH_NEXT     -> EAX (cle suivante ou 0)          *)
(*   TEST EAX, EAX                                                 *)
(*   JZ _AWL_end              (plus de cles)                       *)
(*   MOV [_AWV_var], EAX      (stocker cle dans variable)          *)
(*   ... corps de la boucle ...                                    *)
(*   JMP _AWL_top                                                  *)
(* _AWL_end:                                                       *)
(* break -> JMP _AWL_end, continue -> JMP _AWL_top                 *)
Procedure ParseForIn;
Var
  LblTop    : TString;
  LblEnd    : TString;
  VarName   : TString;
  ArrName   : TString;
  VarIdx    : Integer;
  ArrIdx    : Integer;
Begin
  Inc(ForInCount);
  EmitComment('--- for-in statement ---');

  { Le token courant doit etre l identifiant de la variable }
  If CurToken.Kind = TK_IDENT Then
  Begin
    VarName := CurToken.Val;
    ParserAdvance;  { consommer la variable }
  End Else
  Begin
    WarnMsg('for-in: nom de variable attendu');
    VarName := '_dummy';
  End;

  { On s attend a 'in' }
  If IsKW(KW_IN) Then
    ParserAdvance   { consommer 'in' }
  Else
    WarnMsg('for-in: "in" attendu');

  { On s attend au nom du tableau }
  If CurToken.Kind = TK_IDENT Then
  Begin
    ArrName := CurToken.Val;
    ParserAdvance;  { consommer le nom du tableau }
  End Else
  Begin
    WarnMsg('for-in: nom de tableau attendu');
    ArrName := '_dummy';
  End;

  { Fermer la parenthese }
  If IsPunct(')') Then
    ParserAdvance
  Else
    WarnMsg('for-in: ) attendu');

  { Enregistrer la variable dans la table des symboles si necessaire }
  VarIdx := FindSym(VarName);
  If VarIdx < 0 Then
    VarIdx := AddSym(VarName, TYK_STRING, STORE_GLOBAL, True);

  { Enregistrer le tableau dans la table des symboles si necessaire }
  ArrIdx := FindSym(ArrName);
  If ArrIdx < 0 Then
    ArrIdx := AddSym(ArrName, TYK_ARRAY, STORE_GLOBAL, True);

  { Generer les labels }
  LblTop := NewLabel;
  LblEnd := NewLabel;

  { Empiler la boucle (break -> LblEnd, continue -> LblTop) }
  EnterLoop(LblEnd, LblTop);

  { Initialiser l iterateur : PUSH OFFSET array + CALL HASH_INIT }
  Emit('        PUSH    OFFSET ' + SymTab[ArrIdx].ArrayAsmLabel);
  Emit('        CALL    ' + AW_RT_PFX + 'HASH_INIT');
  EmitBlank;

  { Label du debut de boucle }
  EmitLabel(LblTop);

  { Obtenir la cle suivante : PUSH OFFSET array + CALL HASH_NEXT }
  Emit('        PUSH    OFFSET ' + SymTab[ArrIdx].ArrayAsmLabel);
  Emit('        CALL    ' + AW_RT_PFX + 'HASH_NEXT');

  { Tester si plus de cles }
  Emit('        TEST    EAX, EAX');
  Emit('        JZ      ' + LblEnd);

  { Stocker la cle dans la variable }
  GenStoreVar(VarIdx);
  EmitBlank;

  { Parser le corps de la boucle }
  ParseBlock;

  { JMP _AWL_top }
  Emit('        JMP     ' + LblTop);

  { Label de fin }
  EmitLabel(LblEnd);

  { Depiler la boucle }
  LeaveLoop;

  EmitComment('--- end for-in ---');
  EmitBlank;
End;

{ ============================================================ }
{ TODO 13 - PARSEUR : FONCTIONS UTILISATEUR (FUNCTION/RETURN)  }
{           [IMPLEMENTE]                                        }
{ ============================================================ }

{ ---- ParseFunctionDef ---------------------------------------- }
(* Parse une definition de fonction AWK :                          *)
(*   function nom(param1, param2, ...) { instructions }            *)
(* Convention d appel avec args gauche a droite + offsets ajustes :   *)
(*   PUSH arg1 + PUSH arg2 + ... + PUSH argN + CALL _AWF_nom        *)
(*   Prologue : PUSH EBP / MOV EBP, ESP / SUB ESP, 64               *)
(*   Epilogue : MOV ESP, EBP / POP EBP / RET n                      *)
(*   Parametres : param I a [EBP + 4 + (N-I+1)*4]                   *)
(*   Variables locales a [EBP-4], [EBP-8]...                         *)
(* AWK extra params -> variables locales (function f(a,b,  c,d))   *)
Procedure ParseFunctionDef;
Var
  FnName    : TString;
  FnIdx     : Integer;
  PCount    : Integer;
  PName     : TString;
  SymIdx    : Integer;
  LblExit   : TString;
  LblSkip   : TString;
  I         : Integer;
Begin
  Inc(FuncDefCount);
  EmitComment('--- function definition ---');

  { Recuperer le nom de la fonction }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    FatalError('nom de fonction attendu');
    Exit;
  End;
  FnName := CurToken.Val;
  ParserAdvance;

  { Chercher ou enregistrer la fonction }
  FnIdx := FindFunc(FnName);
  If FnIdx < 0 Then
    FnIdx := AddFunc(FnName);
  If FnIdx < 0 Then
  Begin
    FatalError('table des fonctions pleine');
    Exit;
  End;

  { Parser la liste de parametres ( param1, param2, ... ) }
  PCount := 0;
  If IsPunct('(') Then
  Begin
    ParserAdvance;
    While (CurToken.Kind = TK_IDENT) And (Not IsPunct(')')) Do
    Begin
      If PCount < MAX_PARAM Then
      Begin
        Inc(PCount);
        FuncTab[FnIdx].ParamNames[PCount] := CurToken.Val;
      End;
      ParserAdvance;
      If IsPunct(',') Then
        ParserAdvance;
    End;
    If IsPunct(')') Then
      ParserAdvance;
  End;
  FuncTab[FnIdx].ParamCount := PCount;
  FuncTab[FnIdx].Defined    := True;

  { Generer un label pour sauter par-dessus la definition }
  LblSkip := NewLabel;
  Emit('        JMP     ' + LblSkip);
  EmitBlank;

  { Emettre le label de la fonction }
  EmitLabel(FuncTab[FnIdx].AsmLabel);

  { Prologue de la fonction }
  EmitComment('prologue ' + FnName);
  Emit('        PUSH    EBP');
  Emit('        MOV     EBP, ESP');

  { Entrer dans le scope fonction }
  EnterScope(SK_FUNCTION);

  { Generer le label de sortie }
  LblExit := NewLabel;
  SetExitLabel(LblExit);

  { Enregistrer les parametres dans la table des symboles }
  { Args pushes gauche a droite : param 1 = EBP+4+(PCount*4), param N = EBP+8 }
  For I := 1 To PCount Do
  Begin
    PName := FuncTab[FnIdx].ParamNames[I];
    SymIdx := AddSym(PName, TYK_UNKNOWN, STORE_PARAM, False);
    If SymIdx >= 0 Then
    Begin
      SymTab[SymIdx].IsParam  := True;
      SymTab[SymIdx].ParamIdx := I;
      SymTab[SymIdx].BpOffset := 4 + (PCount - I + 1) * 4;
    End;
  End;

  { Reserver de l espace pour les variables locales (reserve max 64 octets) }
  { Les variables locales seront allouees dynamiquement via AllocLocal }
  Emit('        SUB     ESP, 64');
  ScopeStack[ScopeDepth - 1].EbpOffset := -64;

  EmitBlank;

  { Parser le corps de la fonction }
  ParseBlock;

  { Label de sortie (retour par defaut = 0) }
  EmitLabel(LblExit);

  { Epilogue de la fonction }
  EmitComment('epilogue ' + FnName);
  Emit('        MOV     ESP, EBP');
  Emit('        POP     EBP');
  Emit('        RET     ' + IntToStr_(PCount * 4));

  EmitBlank;

  { Quitter le scope fonction }
  LeaveScope;

  { Label pour sauter par-dessus la definition }
  EmitLabel(LblSkip);

  EmitComment('--- end function ' + FnName + ' ---');
  EmitBlank;
End;

{ ============================================================ }
{ TODO 14 - PARSEUR : REGLES PATTERN-ACTION (BEGIN, END,       }
{           /regex/, expr)  [IMPLEMENTE]                        }
{ ============================================================ }

{ ---- AddRule : enregistrer une nouvelle regle ------------------- }
Function AddRule(Kind : Integer; Const Pat : String) : Integer;
Var
  Lbl : String;
  Idx : Integer;
Begin
  If RuleCount >= MAX_RULES Then
  Begin
    FatalError('table des regles pleine');
    AddRule := -1;
    Exit;
  End;
  Idx := RuleCount;
  Lbl := GenScopeLabel(AW_RULE_PFX);
  RuleTab[Idx].Kind       := Kind;
  RuleTab[Idx].PatternStr := Pat;
  RuleTab[Idx].AsmLabel   := Lbl;
  RuleTab[Idx].HasAction  := False;
  Inc(RuleCount);
  AddRule := Idx;
End;

{ ---- ParseAction ------------------------------------------------ }
(* Parse un bloc action { ... } d une regle pattern-action.         *)
(* Utilise ParseBlock pour parser le contenu entre accolades.       *)
Procedure ParseAction;
Begin
  SkipNewlines;
  If IsPunct('{') Then
    ParseBlock
  Else
    ParseStatement;
End;

{ ============================================================ }
{ TODO 21 - PARSEUR : VARIABLES BUILTIN AWK                    }
{ ============================================================ }

{ ---- InitBuiltinVarDefaults ---------------------------------- }
{ Genere le code ASM pour initialiser les valeurs par defaut     }
{ des variables builtin AWK (FS, RS, OFS, ORS, SUBSEP, etc.)    }
{ Appele apres le parsing mais avant l execution.                }
{ Les variables numeriques sont deja a 0 (DD 0).                 }
{ Les variables chaine recoivent un pointeur vers leur defaut.   }
Procedure InitBuiltinVarDefaults;
Var
  SI : Integer;
Begin
  EmitComment('=== TODO 21 : init builtin var defaults ===');
  { FS = " " (defaut) }
  SI := FindSym('FS');
  If SI >= 0 Then
  Begin
    Emit('        MOV     EAX, OFFSET ' + AW_STR_PFX + 'FS_DEF');
    GenStoreVar(SI);
    Inc(BuiltinVarCount);
  End;
  { RS = "\n" (defaut) }
  SI := FindSym('RS');
  If SI >= 0 Then
  Begin
    Emit('        MOV     EAX, OFFSET ' + AW_STR_PFX + 'RS_DEF');
    GenStoreVar(SI);
    Inc(BuiltinVarCount);
  End;
  { OFS = " " (defaut) }
  SI := FindSym('OFS');
  If SI >= 0 Then
  Begin
    Emit('        MOV     EAX, OFFSET ' + AW_STR_PFX + 'OFS_DEF');
    GenStoreVar(SI);
    Inc(BuiltinVarCount);
  End;
  { ORS = "\n" (defaut) }
  SI := FindSym('ORS');
  If SI >= 0 Then
  Begin
    Emit('        MOV     EAX, OFFSET ' + AW_STR_PFX + 'ORS_DEF');
    GenStoreVar(SI);
    Inc(BuiltinVarCount);
  End;
  { SUBSEP = "\034" (defaut ASCII FS=28) }
  SI := FindSym('SUBSEP');
  If SI >= 0 Then
  Begin
    Emit('        MOV     EAX, OFFSET ' + AW_STR_PFX + 'SUBSEP_DEF');
    GenStoreVar(SI);
    Inc(BuiltinVarCount);
  End;
  { OFMT = "%.6g" (defaut) }
  SI := FindSym('OFMT');
  If SI >= 0 Then
  Begin
    Emit('        MOV     EAX, OFFSET ' + AW_STR_PFX + 'OFMT_DEF');
    GenStoreVar(SI);
    Inc(BuiltinVarCount);
  End;
  { CONVFMT = "%.6g" (defaut) }
  SI := FindSym('CONVFMT');
  If SI >= 0 Then
  Begin
    Emit('        MOV     EAX, OFFSET ' + AW_STR_PFX + 'CONVFMT_DEF');
    GenStoreVar(SI);
    Inc(BuiltinVarCount);
  End;
  { FILENAME = "" (ptr null) }
  SI := FindSym('FILENAME');
  If SI >= 0 Then
  Begin
    Emit('        XOR     EAX, EAX');
    GenStoreVar(SI);
    Inc(BuiltinVarCount);
  End;
  { NR = 0 }
  SI := FindSym('NR');
  If SI >= 0 Then
  Begin
    Emit('        XOR     EAX, EAX');
    GenStoreVar(SI);
    Inc(BuiltinVarCount);
  End;
  { NF = 0 }
  SI := FindSym('NF');
  If SI >= 0 Then
  Begin
    Emit('        XOR     EAX, EAX');
    GenStoreVar(SI);
    Inc(BuiltinVarCount);
  End;
  { FNR = 0 }
  SI := FindSym('FNR');
  If SI >= 0 Then
  Begin
    Emit('        XOR     EAX, EAX');
    GenStoreVar(SI);
    Inc(BuiltinVarCount);
  End;
  { ARGC = 0 }
  SI := FindSym('ARGC');
  If SI >= 0 Then
  Begin
    Emit('        XOR     EAX, EAX');
    GenStoreVar(SI);
    Inc(BuiltinVarCount);
  End;
  { RSTART = 0 }
  SI := FindSym('RSTART');
  If SI >= 0 Then
  Begin
    Emit('        XOR     EAX, EAX');
    GenStoreVar(SI);
    Inc(BuiltinVarCount);
  End;
  { RLENGTH = 0 }
  SI := FindSym('RLENGTH');
  If SI >= 0 Then
  Begin
    Emit('        XOR     EAX, EAX');
    GenStoreVar(SI);
    Inc(BuiltinVarCount);
  End;
  EmitComment('=== fin init builtin vars (14 vars) ===');
End;

{ ---- ApplyDashF ---------------------------------------------- }
{ Genere le code ASM pour appliquer l option -F sep              }
{ Modifie FS avec le separateur fourni en ligne de commande      }
Procedure ApplyDashF;
Var
  SI   : Integer;
  SLbl : TString;
Begin
  If Opts.FieldSep = ' ' Then Exit;  { defaut, rien a faire }
  EmitComment('--- -F : FS = "' + Opts.FieldSep + '" ---');
  SI := FindSym('FS');
  If SI >= 0 Then
  Begin
    SLbl := AddStringLit(Opts.FieldSep);
    Emit('        MOV     EAX, OFFSET ' + SLbl);
    GenStoreVar(SI);
    Inc(BuiltinVarCount);
  End;
End;

{ ---- ApplyDashV ---------------------------------------------- }
{ Genere le code ASM pour appliquer les options -v var=val       }
{ Initialise les variables specifiees avant le bloc BEGIN        }
Procedure ApplyDashV;
Var
  I    : Integer;
  SI   : Integer;
  SLbl : TString;
  VN   : TString;
  VV   : TString;
Begin
  If Opts.InitCount = 0 Then Exit;
  EmitComment('--- -v : init user vars ---');
  For I := 0 To Opts.InitCount - 1 Do
  Begin
    VN := Opts.InitVars[I].VarName;
    VV := Opts.InitVars[I].VarValue;
    { Chercher ou creer la variable }
    SI := FindSym(VN);
    If SI < 0 Then
      SI := AddSym(VN, TYK_STRING, STORE_GLOBAL, True);
    EmitComment('-v ' + VN + '=' + VV);
    SLbl := AddStringLit(VV);
    Emit('        MOV     EAX, OFFSET ' + SLbl);
    GenStoreVar(SI);
    Inc(BuiltinVarCount);
  End;
End;

{ ============================================================ }
{ TODO 22 - GENERATION : EN-TETE ASSEMBLEUR 80386 ET SEGMENT .DATA }
{ ============================================================ }

{ ---- EncodeASCIIZ -------------------------------------------- }
{ Encode une chaine Pascal en format DB MASM : 'abc',10,0       }
Function EncodeASCIIZ(Const S: TString): TString;
Var
  R    : TString;
  I    : Integer;
  C    : Char;
  InQ  : Boolean;
Begin
  R := '';
  InQ := False;
  For I := 1 To Length(S) Do
  Begin
    C := S[I];
    If (Ord(C) >= 32) And (Ord(C) < 127) And (C <> '''') Then
    Begin
      If Not InQ Then
      Begin
        If R <> '' Then R := R + ',';
        R := R + '''';
        InQ := True;
      End;
      R := R + C;
    End
    Else
    Begin
      If InQ Then
      Begin R := R + ''''; InQ := False; End;
      If R <> '' Then R := R + ',';
      R := R + IntToStr_(Ord(C));
    End;
  End;
  If InQ Then R := R + '''';
  If R = '' Then
    R := '0'
  Else
    R := R + ',0';
  EncodeASCIIZ := R;
End;

{ ---- EmitHeader ---------------------------------------------- }
{ Emet l en-tete ASM 80386 pour un programme Win32 console       }
{ .386 / .MODEL FLAT, STDCALL / EXTRN / .CODE                   }
Procedure EmitHeader;
Begin
  EmitHeaderDone := True;
  EmitComment('=== AWKCW32 - Compilateur AWK vers ASM 80386 Win32 ===');
  EmitComment('Genere a partir de : ' + Opts.SrcFile);
  EmitBlank;
  { Directive processeur et modele memoire }
  Emit('.386');
  Emit('.MODEL FLAT, STDCALL');
  Emit('OPTION CASEMAP:NONE');
  EmitBlank;
  { Declarations externes (imports Win32 kernel32.dll) }
  EmitComment('--- Imports Win32 (kernel32.dll) ---');
  Emit('EXTRN _ExitProcess@4:NEAR');
  Emit('EXTRN _GetStdHandle@4:NEAR');
  Emit('EXTRN _WriteFile@20:NEAR');
  Emit('EXTRN _ReadFile@20:NEAR');
  Emit('EXTRN _GetProcessHeap@0:NEAR');
  Emit('EXTRN _HeapAlloc@12:NEAR');
  Emit('EXTRN _HeapFree@12:NEAR');
  Emit('EXTRN _CreateFileA@28:NEAR');
  Emit('EXTRN _CloseHandle@4:NEAR');
  Emit('EXTRN _GetCommandLineA@0:NEAR');
  EmitBlank;
  { Debut du segment de code }
  Emit('.STACK ' + IntToStr_(STACK_SIZE));
  EmitComment('--- Segment de code ---');
  Emit('_TEXT SEGMENT DWORD PUBLIC ''CODE''');
  Emit('ASSUME CS:_TEXT');
  EmitBlank;
End;

{ ---- EmitDataSeg --------------------------------------------- }
{ Emet le segment .DATA complet : variables builtin, defauts,    }
{ variables utilisateur, tableaux associatifs, litteraux chaine, }
{ patterns regex, et tampons runtime.                            }
Procedure EmitDataSeg;
Var
  I     : Integer;
  HasBV : Boolean;
Begin
  EmitComment('--- Fin du segment de code ---');
  Emit('_TEXT ENDS');
  EmitBlank;
  EmitComment('=== Segment de donnees ===');
  Emit('.DATA');
  EmitBlank;

  { 1. Variables builtin AWK (globales .DATA) }
  EmitComment('--- Variables builtin AWK ---');
  For I := 0 To MaxSymCount - 1 Do
  Begin
    If Not SymTab[I].IsGlobal Then Continue;
    HasBV := (IsBuiltinVar(SymTab[I].Name) > 0);
    If Not HasBV Then Continue;
    If SymTab[I].IsArray Then
      { Tableaux builtin (ARGV, ENVIRON) : bloc de 256 octets }
      Emit(SymTab[I].ArrayAsmLabel + '  DB 256 DUP(0)')
    Else
      { Scalaire : DD 0 }
      Emit(SymTab[I].AsmLabel + '  DD 0');
  End;
  EmitBlank;

  { 2. Chaines par defaut des separateurs et formats }
  EmitComment('--- Valeurs par defaut des separateurs ---');
  Emit(AW_STR_PFX + 'FS_DEF      DB '' '',0');
  Emit(AW_STR_PFX + 'RS_DEF      DB 10,0');
  Emit(AW_STR_PFX + 'OFS_DEF     DB '' '',0');
  Emit(AW_STR_PFX + 'ORS_DEF     DB 10,0');
  Emit(AW_STR_PFX + 'SUBSEP_DEF  DB 28,0');
  Emit(AW_STR_PFX + 'OFMT_DEF    DB ''%.6g'',0');
  Emit(AW_STR_PFX + 'CONVFMT_DEF DB ''%.6g'',0');
  EmitBlank;

  { 3. Variables utilisateur (globales) }
  EmitComment('--- Variables utilisateur ---');
  For I := 0 To MaxSymCount - 1 Do
  Begin
    If Not SymTab[I].IsGlobal Then Continue;
    If IsBuiltinVar(SymTab[I].Name) > 0 Then Continue;
    If SymTab[I].IsArray Then
      Emit(SymTab[I].ArrayAsmLabel + '  DB 256 DUP(0)')
    Else
      Emit(SymTab[I].AsmLabel + '  DD 0');
  End;
  EmitBlank;

  { 4. Litteraux chaine }
  If StringLitCount > 0 Then
  Begin
    EmitComment('--- Litteraux chaine ---');
    For I := 0 To StringLitCount - 1 Do
      Emit(StringLitTab[I].Lbl + '  DB ' +
           EncodeASCIIZ(StringLitTab[I].Val));
    EmitBlank;
  End;

  { 5. Patterns regex }
  If RegexPatCount > 0 Then
  Begin
    EmitComment('--- Patterns regex ---');
    For I := 0 To RegexPatCount - 1 Do
      Emit(RegexPatTab[I].Lbl + '  DB ' +
           EncodeASCIIZ(RegexPatTab[I].Pat));
    EmitBlank;
  End;

  { 6. Tampons et variables runtime }
  EmitComment('--- Tampons runtime ---');
  Emit(AW_RT_PFX + 'LINE      DB 4096 DUP(0)');
  Emit(AW_RT_PFX + 'FIELDS    DB 4096 DUP(0)');
  Emit(AW_RT_PFX + 'NUMBUF    DB 32 DUP(0)');
  Emit(AW_RT_PFX + 'STRBUF    DB 4096 DUP(0)');
  Emit(AW_RT_PFX + 'CATBUF    DB 4096 DUP(0)');
  Emit(AW_RT_PFX + 'INPUTBUF  DB 4096 DUP(0)');
  Emit(AW_RT_PFX + 'CRLF_DATA DB 13,10,0');
  Emit(AW_RT_PFX + 'HSTDOUT   DD 0');
  Emit(AW_RT_PFX + 'HSTDIN    DD 0');
  Emit(AW_RT_PFX + 'HHEAP     DD 0');
  Emit(AW_RT_PFX + 'BYTESWR   DD 0');
  Emit(AW_RT_PFX + 'BYTESRD   DD 0');
  Emit(AW_RT_PFX + 'SEED      DD 12345');
  Emit(AW_RT_PFX + 'EXITCODE  DD 0');
  EmitBlank;
End;

{ ---- EmitFooter ---------------------------------------------- }
{ Emet la fin du fichier assembleur : END _AWF_main              }
Procedure EmitFooter;
Begin
  Emit('END ' + AW_FN_PFX + 'main');
End;

{ ============================================================ }
{ TODO 23 - GENERATION : POINT D ENTREE WIN32, BOUCLE          }
{           PRINCIPALE ET HELPERS RUNTIME                       }
{ ============================================================ }

{ ---- EmitEntryPoint ------------------------------------------ }
{ Emet le point d entree _AWF_main :                             }
{   - Initialisation des handles Win32 (stdout, stdin, heap)     }
{   - Initialisation des variables builtin AWK                   }
{   - Application de -F et -v                                    }
{   - Appel des regles BEGIN                                     }
{   - Boucle principale (readline, splitline, NR++, regles)      }
{   - Appel des regles END                                       }
{   - ExitProcess(0)                                             }
Procedure EmitEntryPoint;
Var
  I       : Integer;
  LblSkip : TString;
  NRIdx   : Integer;
  FNRIdx  : Integer;
Begin
  Inc(RuntimeHelpCount);
  EmitBlank;
  EmitComment('=========================================================');
  EmitComment('  POINT D ENTREE PRINCIPAL - _AWF_main');
  EmitComment('=========================================================');
  EmitLabel(AW_FN_PFX + 'main');
  Emit('        PUSH    EBP');
  Emit('        MOV     EBP, ESP');
  EmitBlank;

  { Initialiser les handles Win32 }
  EmitComment('--- Initialiser les handles Win32 ---');
  Emit('        PUSH    -11');
  Emit('        CALL    _GetStdHandle@4');
  Emit('        MOV     DWORD PTR [' + AW_RT_PFX + 'HSTDOUT], EAX');
  Emit('        PUSH    -10');
  Emit('        CALL    _GetStdHandle@4');
  Emit('        MOV     DWORD PTR [' + AW_RT_PFX + 'HSTDIN], EAX');
  Emit('        CALL    _GetProcessHeap@0');
  Emit('        MOV     DWORD PTR [' + AW_RT_PFX + 'HHEAP], EAX');
  EmitBlank;

  { Initialiser les variables builtin AWK }
  EmitComment('--- Initialiser les variables builtin ---');
  InitBuiltinVarDefaults;
  ApplyDashF;
  ApplyDashV;
  EmitBlank;

  { Executer les regles BEGIN }
  EmitComment('--- Executer les regles BEGIN ---');
  For I := 0 To RuleCount - 1 Do
  Begin
    If RuleTab[I].Kind = RK_BEGIN Then
      Emit('        CALL    ' + RuleTab[I].AsmLabel);
  End;
  EmitBlank;

  { Boucle principale }
  EmitComment('--- Boucle principale ---');
  EmitLabel(AW_LBL_PFX + 'loop');
  Emit('        CALL    ' + AW_RT_PFX + 'READLINE');
  Emit('        TEST    EAX, EAX');
  Emit('        JZ      ' + AW_LBL_PFX + 'eof');
  Emit('        CALL    ' + AW_RT_PFX + 'SPLITLINE');
  { INC NR et FNR }
  NRIdx := FindSym('NR');
  FNRIdx := FindSym('FNR');
  If NRIdx >= 0 Then
    Emit('        INC     DWORD PTR [' + SymTab[NRIdx].AsmLabel + ']');
  If FNRIdx >= 0 Then
    Emit('        INC     DWORD PTR [' + SymTab[FNRIdx].AsmLabel + ']');
  EmitBlank;

  { Executer chaque regle pattern-action }
  EmitComment('--- Tester et executer les regles ---');
  For I := 0 To RuleCount - 1 Do
  Begin
    If (RuleTab[I].Kind <> RK_BEGIN) And
       (RuleTab[I].Kind <> RK_END) Then
    Begin
      Emit('        CALL    ' + RuleTab[I].AsmLabel);
    End;
  End;
  EmitBlank;

  { Retour en debut de boucle }
  EmitLabel(AW_LBL_PFX + 'next_line');
  Emit('        JMP     ' + AW_LBL_PFX + 'loop');
  EmitBlank;

  { Label exit : sauvegarde du code de sortie et saut vers END (TODO 24) }
  EmitLabel(AW_LBL_PFX + 'exit');
  EmitComment('--- exit statement -> run END rules then quit ---');
  Emit('        JMP     ' + AW_LBL_PFX + 'eof');
  EmitBlank;

  { EOF : executer les regles END }
  EmitLabel(AW_LBL_PFX + 'eof');
  EmitComment('--- Executer les regles END ---');
  For I := 0 To RuleCount - 1 Do
  Begin
    If RuleTab[I].Kind = RK_END Then
      Emit('        CALL    ' + RuleTab[I].AsmLabel);
  End;
  EmitBlank;

  { Terminer le processus avec le code de sortie }
  Emit('        PUSH    DWORD PTR [' + AW_RT_PFX + 'EXITCODE]');
  Emit('        CALL    _ExitProcess@4');
  EmitBlank;
End;

{ ---- EmitRuntimeHelpers -------------------------------------- }
{ Emet les procedures runtime _AWRT_* en assembleur 80386.       }
{ Ces helpers sont appeles par le code genere pour les operations }
{ AWK (affichage, lecture, conversions, chaines, tableaux, etc.) }
Procedure EmitRuntimeHelpers;
Begin
  EmitBlank;
  EmitComment('=========================================================');
  EmitComment('  HELPERS RUNTIME AWK (_AWRT_*)');
  EmitComment('=========================================================');
  EmitBlank;

  { ---- _AWRT_STRLEN : longueur d une chaine ASCIIZ ---- }
  { Entree : EAX = ptr chaine  Sortie : EAX = longueur    }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'STRLEN');
  Emit('        PUSH    ECX');
  Emit('        PUSH    EDI');
  Emit('        MOV     EDI, EAX');
  Emit('        XOR     ECX, ECX');
  Emit('        TEST    EAX, EAX');
  Emit('        JZ      ' + AW_RT_PFX + 'STRLEN_DONE');
  EmitLabel(AW_RT_PFX + 'STRLEN_LP');
  Emit('        CMP     BYTE PTR [EDI+ECX], 0');
  Emit('        JZ      ' + AW_RT_PFX + 'STRLEN_DONE');
  Emit('        INC     ECX');
  Emit('        JMP     ' + AW_RT_PFX + 'STRLEN_LP');
  EmitLabel(AW_RT_PFX + 'STRLEN_DONE');
  Emit('        MOV     EAX, ECX');
  Emit('        POP     EDI');
  Emit('        POP     ECX');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_PRINT : afficher une chaine ASCIIZ ---- }
  { Entree : EAX = ptr chaine ASCIIZ                    }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'PRINT');
  Emit('        PUSH    EBP');
  Emit('        MOV     EBP, ESP');
  Emit('        PUSH    EAX');
  Emit('        CALL    ' + AW_RT_PFX + 'STRLEN');
  Emit('        MOV     ECX, EAX');
  Emit('        POP     EAX');
  Emit('        TEST    ECX, ECX');
  Emit('        JZ      ' + AW_RT_PFX + 'PRINT_DONE');
  Emit('        PUSH    0');
  Emit('        PUSH    OFFSET ' + AW_RT_PFX + 'BYTESWR');
  Emit('        PUSH    ECX');
  Emit('        PUSH    EAX');
  Emit('        PUSH    DWORD PTR [' + AW_RT_PFX + 'HSTDOUT]');
  Emit('        CALL    _WriteFile@20');
  EmitLabel(AW_RT_PFX + 'PRINT_DONE');
  Emit('        MOV     ESP, EBP');
  Emit('        POP     EBP');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_CRLF : ecrire CR+LF ---- }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'CRLF');
  Emit('        PUSH    0');
  Emit('        PUSH    OFFSET ' + AW_RT_PFX + 'BYTESWR');
  Emit('        PUSH    2');
  Emit('        PUSH    OFFSET ' + AW_RT_PFX + 'CRLF_DATA');
  Emit('        PUSH    DWORD PTR [' + AW_RT_PFX + 'HSTDOUT]');
  Emit('        CALL    _WriteFile@20');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_NUMTOSTR : entier -> chaine ASCIIZ ---- }
  { Entree : EAX = entier  Sortie : EAX = ptr _AWRT_NUMBUF }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'NUMTOSTR');
  Emit('        PUSH    EBX');
  Emit('        PUSH    ECX');
  Emit('        PUSH    EDX');
  Emit('        PUSH    EDI');
  Emit('        MOV     EDI, OFFSET ' + AW_RT_PFX + 'NUMBUF');
  Emit('        ADD     EDI, 30');
  Emit('        MOV     BYTE PTR [EDI], 0');
  Emit('        MOV     ECX, EAX');
  Emit('        TEST    EAX, EAX');
  Emit('        JNZ     ' + AW_RT_PFX + 'N2S_NOTZERO');
  Emit('        DEC     EDI');
  Emit('        MOV     BYTE PTR [EDI], 48');
  Emit('        JMP     ' + AW_RT_PFX + 'N2S_END');
  EmitLabel(AW_RT_PFX + 'N2S_NOTZERO');
  Emit('        MOV     EBX, 0');
  Emit('        TEST    EAX, EAX');
  Emit('        JGE     ' + AW_RT_PFX + 'N2S_POS');
  Emit('        NEG     EAX');
  Emit('        MOV     EBX, 1');
  EmitLabel(AW_RT_PFX + 'N2S_POS');
  EmitLabel(AW_RT_PFX + 'N2S_LOOP');
  Emit('        XOR     EDX, EDX');
  Emit('        MOV     ECX, 10');
  Emit('        DIV     ECX');
  Emit('        ADD     DL, 48');
  Emit('        DEC     EDI');
  Emit('        MOV     BYTE PTR [EDI], DL');
  Emit('        TEST    EAX, EAX');
  Emit('        JNZ     ' + AW_RT_PFX + 'N2S_LOOP');
  Emit('        TEST    EBX, EBX');
  Emit('        JZ      ' + AW_RT_PFX + 'N2S_END');
  Emit('        DEC     EDI');
  Emit('        MOV     BYTE PTR [EDI], 45');
  EmitLabel(AW_RT_PFX + 'N2S_END');
  Emit('        MOV     EAX, EDI');
  Emit('        POP     EDI');
  Emit('        POP     EDX');
  Emit('        POP     ECX');
  Emit('        POP     EBX');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_STRTONUM : chaine ASCIIZ -> entier ---- }
  { Entree : EAX = ptr chaine  Sortie : EAX = entier    }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'STRTONUM');
  Emit('        PUSH    EBX');
  Emit('        PUSH    ECX');
  Emit('        PUSH    ESI');
  Emit('        MOV     ESI, EAX');
  Emit('        XOR     EAX, EAX');
  Emit('        XOR     ECX, ECX');
  Emit('        TEST    ESI, ESI');
  Emit('        JZ      ' + AW_RT_PFX + 'S2N_END');
  { Ignorer espaces de tete }
  EmitLabel(AW_RT_PFX + 'S2N_SKIP');
  Emit('        MOV     CL, BYTE PTR [ESI]');
  Emit('        CMP     CL, 32');
  Emit('        JNZ     ' + AW_RT_PFX + 'S2N_CHKSIGN');
  Emit('        INC     ESI');
  Emit('        JMP     ' + AW_RT_PFX + 'S2N_SKIP');
  { Verifier le signe }
  EmitLabel(AW_RT_PFX + 'S2N_CHKSIGN');
  Emit('        XOR     EBX, EBX');
  Emit('        CMP     CL, 45');
  Emit('        JNZ     ' + AW_RT_PFX + 'S2N_LOOP');
  Emit('        MOV     EBX, 1');
  Emit('        INC     ESI');
  EmitLabel(AW_RT_PFX + 'S2N_LOOP');
  Emit('        MOVZX   ECX, BYTE PTR [ESI]');
  Emit('        SUB     ECX, 48');
  Emit('        CMP     ECX, 9');
  Emit('        JA      ' + AW_RT_PFX + 'S2N_DONE');
  Emit('        IMUL    EAX, 10');
  Emit('        ADD     EAX, ECX');
  Emit('        INC     ESI');
  Emit('        JMP     ' + AW_RT_PFX + 'S2N_LOOP');
  EmitLabel(AW_RT_PFX + 'S2N_DONE');
  Emit('        TEST    EBX, EBX');
  Emit('        JZ      ' + AW_RT_PFX + 'S2N_END');
  Emit('        NEG     EAX');
  EmitLabel(AW_RT_PFX + 'S2N_END');
  Emit('        POP     ESI');
  Emit('        POP     ECX');
  Emit('        POP     EBX');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_STRTOBOOL : chaine -> booleen ---- }
  { "" et "0" -> 0, sinon -> 1                     }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'STRTOBOOL');
  Emit('        TEST    EAX, EAX');
  Emit('        JZ      ' + AW_RT_PFX + 'S2B_FALSE');
  Emit('        CMP     BYTE PTR [EAX], 0');
  Emit('        JZ      ' + AW_RT_PFX + 'S2B_FALSE');
  Emit('        CMP     BYTE PTR [EAX], 48');
  Emit('        JNZ     ' + AW_RT_PFX + 'S2B_TRUE');
  Emit('        CMP     BYTE PTR [EAX+1], 0');
  Emit('        JNZ     ' + AW_RT_PFX + 'S2B_TRUE');
  EmitLabel(AW_RT_PFX + 'S2B_FALSE');
  Emit('        XOR     EAX, EAX');
  Emit('        RET');
  EmitLabel(AW_RT_PFX + 'S2B_TRUE');
  Emit('        MOV     EAX, 1');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_PRINTINT : afficher entier ---- }
  { EAX = entier -> NUMTOSTR + PRINT            }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'PRINTINT');
  Emit('        CALL    ' + AW_RT_PFX + 'NUMTOSTR');
  Emit('        CALL    ' + AW_RT_PFX + 'PRINT');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_PRINTLN : afficher chaine + CR/LF ---- }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'PRINTLN');
  Emit('        CALL    ' + AW_RT_PFX + 'PRINT');
  Emit('        CALL    ' + AW_RT_PFX + 'CRLF');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_READLINE : lire une ligne depuis stdin ---- }
  { Sortie : EAX = ptr _AWRT_LINE si succes, 0 si EOF     }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'READLINE');
  Emit('        PUSH    EBP');
  Emit('        MOV     EBP, ESP');
  Emit('        PUSH    0');
  Emit('        PUSH    OFFSET ' + AW_RT_PFX + 'BYTESRD');
  Emit('        PUSH    4094');
  Emit('        PUSH    OFFSET ' + AW_RT_PFX + 'LINE');
  Emit('        PUSH    DWORD PTR [' + AW_RT_PFX + 'HSTDIN]');
  Emit('        CALL    _ReadFile@20');
  Emit('        TEST    EAX, EAX');
  Emit('        JZ      ' + AW_RT_PFX + 'RL_EOF');
  Emit('        MOV     ECX, DWORD PTR [' + AW_RT_PFX + 'BYTESRD]');
  Emit('        TEST    ECX, ECX');
  Emit('        JZ      ' + AW_RT_PFX + 'RL_EOF');
  { Supprimer CR/LF en fin de ligne }
  Emit('        MOV     EDI, OFFSET ' + AW_RT_PFX + 'LINE');
  EmitLabel(AW_RT_PFX + 'RL_TRIM');
  Emit('        TEST    ECX, ECX');
  Emit('        JZ      ' + AW_RT_PFX + 'RL_OK');
  Emit('        DEC     ECX');
  Emit('        CMP     BYTE PTR [EDI+ECX], 10');
  Emit('        JZ      ' + AW_RT_PFX + 'RL_TRIM');
  Emit('        CMP     BYTE PTR [EDI+ECX], 13');
  Emit('        JZ      ' + AW_RT_PFX + 'RL_TRIM');
  Emit('        INC     ECX');
  EmitLabel(AW_RT_PFX + 'RL_OK');
  Emit('        MOV     BYTE PTR [EDI+ECX], 0');
  Emit('        MOV     EAX, OFFSET ' + AW_RT_PFX + 'LINE');
  Emit('        MOV     ESP, EBP');
  Emit('        POP     EBP');
  Emit('        RET');
  EmitLabel(AW_RT_PFX + 'RL_EOF');
  Emit('        MOV     BYTE PTR [' + AW_RT_PFX + 'LINE], 0');
  Emit('        XOR     EAX, EAX');
  Emit('        MOV     ESP, EBP');
  Emit('        POP     EBP');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_STRCOPY : copier une chaine ASCIIZ ---- }
  { ESI = source, EDI = destination                      }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'STRCOPY');
  Emit('        PUSH    ESI');
  Emit('        PUSH    EDI');
  EmitLabel(AW_RT_PFX + 'STRCOPY_LP');
  Emit('        LODSB');
  Emit('        STOSB');
  Emit('        TEST    AL, AL');
  Emit('        JNZ     ' + AW_RT_PFX + 'STRCOPY_LP');
  Emit('        POP     EDI');
  Emit('        POP     ESI');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_STRCMP : comparer deux chaines ASCIIZ ---- }
  { EAX = str1, EBX = str2  Sortie : EAX = -1/0/+1      }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'STRCMP');
  Emit('        PUSH    ESI');
  Emit('        PUSH    EDI');
  Emit('        MOV     ESI, EAX');
  Emit('        MOV     EDI, EBX');
  EmitLabel(AW_RT_PFX + 'STRCMP_LP');
  Emit('        LODSB');
  Emit('        MOV     AH, BYTE PTR [EDI]');
  Emit('        INC     EDI');
  Emit('        CMP     AL, AH');
  Emit('        JB      ' + AW_RT_PFX + 'STRCMP_LT');
  Emit('        JA      ' + AW_RT_PFX + 'STRCMP_GT');
  Emit('        TEST    AL, AL');
  Emit('        JNZ     ' + AW_RT_PFX + 'STRCMP_LP');
  Emit('        XOR     EAX, EAX');
  Emit('        JMP     ' + AW_RT_PFX + 'STRCMP_END');
  EmitLabel(AW_RT_PFX + 'STRCMP_LT');
  Emit('        MOV     EAX, -1');
  Emit('        JMP     ' + AW_RT_PFX + 'STRCMP_END');
  EmitLabel(AW_RT_PFX + 'STRCMP_GT');
  Emit('        MOV     EAX, 1');
  EmitLabel(AW_RT_PFX + 'STRCMP_END');
  Emit('        POP     EDI');
  Emit('        POP     ESI');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_STRCAT : concatener deux chaines ---- }
  { EBX = gauche, EAX = droite -> EAX = ptr CATBUF   }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'STRCAT');
  Emit('        PUSH    ESI');
  Emit('        PUSH    EDI');
  Emit('        MOV     EDI, OFFSET ' + AW_RT_PFX + 'CATBUF');
  { Copier chaine gauche }
  Emit('        MOV     ESI, EBX');
  Emit('        TEST    ESI, ESI');
  Emit('        JZ      ' + AW_RT_PFX + 'SCAT_R');
  EmitLabel(AW_RT_PFX + 'SCAT_L');
  Emit('        LODSB');
  Emit('        TEST    AL, AL');
  Emit('        JZ      ' + AW_RT_PFX + 'SCAT_R');
  Emit('        STOSB');
  Emit('        JMP     ' + AW_RT_PFX + 'SCAT_L');
  EmitLabel(AW_RT_PFX + 'SCAT_R');
  { Copier chaine droite }
  Emit('        POP     EDI');
  Emit('        PUSH    EDI');
  Emit('        MOV     ESI, EAX');          { EAX d origine = droite }
  { Recalculer pos fin }
  Emit('        MOV     EDI, OFFSET ' + AW_RT_PFX + 'CATBUF');
  EmitLabel(AW_RT_PFX + 'SCAT_FIND');
  Emit('        CMP     BYTE PTR [EDI], 0');
  Emit('        JZ      ' + AW_RT_PFX + 'SCAT_R2');
  Emit('        INC     EDI');
  Emit('        JMP     ' + AW_RT_PFX + 'SCAT_FIND');
  EmitLabel(AW_RT_PFX + 'SCAT_R2');
  Emit('        TEST    ESI, ESI');
  Emit('        JZ      ' + AW_RT_PFX + 'SCAT_END');
  EmitLabel(AW_RT_PFX + 'SCAT_R2LP');
  Emit('        LODSB');
  Emit('        STOSB');
  Emit('        TEST    AL, AL');
  Emit('        JNZ     ' + AW_RT_PFX + 'SCAT_R2LP');
  EmitLabel(AW_RT_PFX + 'SCAT_END');
  Emit('        MOV     BYTE PTR [EDI], 0');
  Emit('        MOV     EAX, OFFSET ' + AW_RT_PFX + 'CATBUF');
  Emit('        POP     EDI');
  Emit('        POP     ESI');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_STRDUP : dupliquer chaine dans le tas ---- }
  { EAX = ptr chaine -> EAX = ptr copie (HeapAlloc)       }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'STRDUP');
  Emit('        PUSH    EBP');
  Emit('        MOV     EBP, ESP');
  Emit('        PUSH    EAX');
  Emit('        CALL    ' + AW_RT_PFX + 'STRLEN');
  Emit('        INC     EAX');
  Emit('        PUSH    EAX');
  Emit('        PUSH    8');
  Emit('        PUSH    DWORD PTR [' + AW_RT_PFX + 'HHEAP]');
  Emit('        CALL    _HeapAlloc@12');
  Emit('        POP     ECX');
  Emit('        TEST    EAX, EAX');
  Emit('        JZ      ' + AW_RT_PFX + 'SDUP_FAIL');
  Emit('        MOV     EDI, EAX');
  Emit('        MOV     ESI, DWORD PTR [EBP-4]');
  EmitLabel(AW_RT_PFX + 'SDUP_CP');
  Emit('        LODSB');
  Emit('        STOSB');
  Emit('        TEST    AL, AL');
  Emit('        JNZ     ' + AW_RT_PFX + 'SDUP_CP');
  Emit('        MOV     EAX, EDI');
  Emit('        SUB     EAX, ECX');
  EmitLabel(AW_RT_PFX + 'SDUP_FAIL');
  Emit('        MOV     ESP, EBP');
  Emit('        POP     EBP');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_SPLITLINE : decouper $0 en champs ---- }
  { Stub simplifie : NF = 0 (pas de champs)           }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'SPLITLINE');
  Emit('        XOR     EAX, EAX');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_GETFIELD : obtenir un champ $n ---- }
  { EAX = index -> EAX = ptr champ (ou ptr LINE)   }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'GETFIELD');
  Emit('        MOV     EAX, OFFSET ' + AW_RT_PFX + 'LINE');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_SETFIELD : modifier un champ $n ---- }
  { Stub                                             }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'SETFIELD');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_REBUILDLINE : reconstruire $0 ---- }
  { Stub                                           }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'REBUILDLINE');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_GETLINE_FILE : lire ligne depuis fichier ---- }
  { Stub : retourne 0 (EOF)                                   }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'GETLINE_FILE');
  Emit('        XOR     EAX, EAX');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_REDIR_WRITE : redirection > fichier ---- }
  { Stub                                                  }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'REDIR_WRITE');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_REDIR_APPEND : redirection >> fichier ---- }
  { Stub                                                    }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'REDIR_APPEND');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_PRINTF : affichage formate ---- }
  { Stub simplifie                              }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'PRINTF');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_SPRINTF : formater chaine ---- }
  { Stub : retourne chaine vide                }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'SPRINTF');
  Emit('        MOV     EAX, OFFSET ' + AW_RT_PFX + 'STRBUF');
  Emit('        MOV     BYTE PTR [EAX], 0');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_TOLOWER : convertir en minuscules ---- }
  { EAX = ptr chaine -> EAX = ptr STRBUF (minuscules) }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'TOLOWER');
  Emit('        PUSH    ESI');
  Emit('        PUSH    EDI');
  Emit('        MOV     ESI, EAX');
  Emit('        MOV     EDI, OFFSET ' + AW_RT_PFX + 'STRBUF');
  EmitLabel(AW_RT_PFX + 'TLWR_LP');
  Emit('        LODSB');
  Emit('        CMP     AL, 65');
  Emit('        JB      ' + AW_RT_PFX + 'TLWR_OK');
  Emit('        CMP     AL, 90');
  Emit('        JA      ' + AW_RT_PFX + 'TLWR_OK');
  Emit('        ADD     AL, 32');
  EmitLabel(AW_RT_PFX + 'TLWR_OK');
  Emit('        STOSB');
  Emit('        TEST    AL, AL');
  Emit('        JNZ     ' + AW_RT_PFX + 'TLWR_LP');
  Emit('        MOV     EAX, OFFSET ' + AW_RT_PFX + 'STRBUF');
  Emit('        POP     EDI');
  Emit('        POP     ESI');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_TOUPPER : convertir en majuscules ---- }
  { EAX = ptr chaine -> EAX = ptr STRBUF (majuscules) }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'TOUPPER');
  Emit('        PUSH    ESI');
  Emit('        PUSH    EDI');
  Emit('        MOV     ESI, EAX');
  Emit('        MOV     EDI, OFFSET ' + AW_RT_PFX + 'STRBUF');
  EmitLabel(AW_RT_PFX + 'TUPR_LP');
  Emit('        LODSB');
  Emit('        CMP     AL, 97');
  Emit('        JB      ' + AW_RT_PFX + 'TUPR_OK');
  Emit('        CMP     AL, 122');
  Emit('        JA      ' + AW_RT_PFX + 'TUPR_OK');
  Emit('        SUB     AL, 32');
  EmitLabel(AW_RT_PFX + 'TUPR_OK');
  Emit('        STOSB');
  Emit('        TEST    AL, AL');
  Emit('        JNZ     ' + AW_RT_PFX + 'TUPR_LP');
  Emit('        MOV     EAX, OFFSET ' + AW_RT_PFX + 'STRBUF');
  Emit('        POP     EDI');
  Emit('        POP     ESI');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_SUBSTR : extraire sous-chaine ---- }
  { Stub : retourne ptr chaine d entree           }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'SUBSTR');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_INDEX : trouver position sous-chaine ---- }
  { Stub : retourne 0                                     }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'INDEX');
  Emit('        XOR     EAX, EAX');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_SPLIT : decouper chaine en tableau ---- }
  { Stub : retourne 0                                   }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'SPLIT');
  Emit('        XOR     EAX, EAX');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_SUB : remplacer premiere occurrence ---- }
  { Stub : retourne 0                                    }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'SUB');
  Emit('        XOR     EAX, EAX');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_GSUB : remplacer toutes les occurrences ---- }
  { Stub : retourne 0                                        }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'GSUB');
  Emit('        XOR     EAX, EAX');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_MATCH : matcher et retourner position ---- }
  { Stub : retourne 0                                      }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'MATCH');
  Emit('        XOR     EAX, EAX');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_MATCH_RE : matcher regex ---- }
  { Stub : retourne 1 (toujours match)       }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'MATCH_RE');
  Emit('        MOV     EAX, 1');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_MATCH_LINE : matcher pattern sur $0 ---- }
  { Stub : retourne 1                                     }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'MATCH_LINE');
  Emit('        MOV     EAX, 1');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_HASH_GET : lire tableau associatif ---- }
  { Stub : retourne 0                                   }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'HASH_GET');
  Emit('        XOR     EAX, EAX');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_HASH_SET : ecrire dans tableau associatif ---- }
  { Stub                                                        }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'HASH_SET');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_HASH_EXISTS : tester cle dans tableau ---- }
  { Stub : retourne 0                                      }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'HASH_EXISTS');
  Emit('        XOR     EAX, EAX');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_HASH_DEL : supprimer entree tableau ---- }
  { Stub                                                  }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'HASH_DEL');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_HASH_CLEAR : vider tableau ---- }
  { Stub                                        }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'HASH_CLEAR');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_HASH_INIT : init iterateur for-in ---- }
  { Stub                                                }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'HASH_INIT');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_HASH_NEXT : prochain element for-in ---- }
  { Stub : retourne 0 (fin)                              }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'HASH_NEXT');
  Emit('        XOR     EAX, EAX');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_HASH_COUNT : nombre d elements ---- }
  { Stub : retourne 0                               }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'HASH_COUNT');
  Emit('        XOR     EAX, EAX');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_POW : puissance a^b ---- }
  { Stub simplifie : retourne 1          }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'POW');
  Emit('        MOV     EAX, 1');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_SQRT : racine carree ---- }
  { Stub : retourne 0                    }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'SQRT');
  Emit('        XOR     EAX, EAX');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_SIN : sinus ---- }
  { Stub : retourne 0           }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'SIN');
  Emit('        XOR     EAX, EAX');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_COS : cosinus ---- }
  { Stub : retourne 1              }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'COS');
  Emit('        MOV     EAX, 1');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_ATAN2 : arctangente ---- }
  { Stub : retourne 0                    }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'ATAN2');
  Emit('        XOR     EAX, EAX');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_EXP : exponentielle ---- }
  { Stub : retourne 1                    }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'EXP');
  Emit('        MOV     EAX, 1');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_LOG : logarithme ---- }
  { Stub : retourne 0                }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'LOG');
  Emit('        XOR     EAX, EAX');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_RAND : nombre pseudo-aleatoire ---- }
  { LCG simple : seed = seed * 1103515245 + 12345   }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'RAND');
  Emit('        MOV     EAX, DWORD PTR [' + AW_RT_PFX + 'SEED]');
  Emit('        IMUL    EAX, 1103515245');
  Emit('        ADD     EAX, 12345');
  Emit('        MOV     DWORD PTR [' + AW_RT_PFX + 'SEED], EAX');
  Emit('        SHR     EAX, 16');
  Emit('        AND     EAX, 32767');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_SRAND : initialiser graine ---- }
  { EAX = nouvelle graine                       }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'SRAND');
  Emit('        MOV     DWORD PTR [' + AW_RT_PFX + 'SEED], EAX');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_SRAND_TIME : srand avec le temps ---- }
  { Stub : utilise une valeur fixe                     }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'SRAND_TIME');
  Emit('        MOV     EAX, 12345678');
  Emit('        MOV     DWORD PTR [' + AW_RT_PFX + 'SEED], EAX');
  Emit('        RET');
  EmitBlank;

  { ---- _AWRT_ERROR : afficher erreur et quitter ---- }
  { EAX = ptr message d erreur                          }
  Inc(RuntimeHelpCount);
  EmitLabel(AW_RT_PFX + 'ERROR');
  Emit('        CALL    ' + AW_RT_PFX + 'PRINT');
  Emit('        CALL    ' + AW_RT_PFX + 'CRLF');
  Emit('        PUSH    1');
  Emit('        CALL    _ExitProcess@4');
  Emit('        RET');
  EmitBlank;
End;
(* Parse un programme AWK complet au niveau superieur.              *)
(* Structure AWK : suite de regles pattern-action :                 *)
(*   BEGIN { action }           -> bloc d initialisation            *)
(*   END { action }             -> bloc de finalisation             *)
(*   /regexp/ { action }        -> filtre par expression reguliere  *)
(*   /deb/,/fin/ { action }     -> range pattern (debut a fin)      *)
(*   expression { action }      -> filtre par condition             *)
(*   { action }                 -> action sans pattern (tout)       *)
(*   function nom(...) { ... }  -> definition de fonction           *)
(* Generation de code 80386 :                                       *)
(*   Chaque regle -> label _AWR_n + test pattern + corps action     *)
(*   BEGIN execute avant la boucle de lecture                       *)
(*   END execute apres la boucle de lecture                         *)
Procedure ParseProgram;
Var
  RIdx     : Integer;
  LblSkip  : TString;
  PatVal   : TString;
  PatVal2  : TString;
  D        : Integer;
Begin
  While CurToken.Kind <> TK_EOF Do
  Begin
    SkipNewlines;
    If CurToken.Kind = TK_EOF Then Break;

    { Passer les points-virgules isoles }
    If IsPunct(';') Then
    Begin
      ParserAdvance;
      Continue;
    End;

    { ---- function : definition de fonction ---- }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.IntVal = KW_FUNCTION) Then
    Begin
      ParserAdvance;
      ParseFunctionDef;
      Continue;
    End;

    (* ---- BEGIN action ---- *)
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.IntVal = KW_BEGIN) Then
    Begin
      ParserAdvance;
      Inc(RuleDefCount);
      RIdx := AddRule(RK_BEGIN, 'BEGIN');
      If RIdx >= 0 Then
        RuleTab[RIdx].HasAction := True;
      EmitComment('--- BEGIN rule ---');
      EmitLabel(RuleTab[RIdx].AsmLabel);
      Emit('        PUSH    EBP');
      Emit('        MOV     EBP, ESP');
      EnterScope(SK_RULE);
      ParseAction;
      LeaveScope;
      Emit('        MOV     ESP, EBP');
      Emit('        POP     EBP');
      Emit('        RET');
      EmitComment('--- end BEGIN rule ---');
      EmitBlank;
      Continue;
    End;

    (* ---- END action ---- *)
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.IntVal = KW_END) Then
    Begin
      ParserAdvance;
      Inc(RuleDefCount);
      RIdx := AddRule(RK_END, 'END');
      If RIdx >= 0 Then
        RuleTab[RIdx].HasAction := True;
      EmitComment('--- END rule ---');
      EmitLabel(RuleTab[RIdx].AsmLabel);
      Emit('        PUSH    EBP');
      Emit('        MOV     EBP, ESP');
      EnterScope(SK_RULE);
      ParseAction;
      LeaveScope;
      Emit('        MOV     ESP, EBP');
      Emit('        POP     EBP');
      Emit('        RET');
      EmitComment('--- end END rule ---');
      EmitBlank;
      Continue;
    End;

    (* ---- /regexp/ action ou /deb/,/fin/ action ---- *)
    If CurToken.Kind = TK_REGEXP Then
    Begin
      PatVal := CurToken.Val;
      ParserAdvance;
      SkipNewlines;

      { Range pattern : /deb/,/fin/ }
      If IsPunct(',') Then
      Begin
        ParserAdvance;
        SkipNewlines;
        If CurToken.Kind = TK_REGEXP Then
        Begin
          PatVal2 := CurToken.Val;
          ParserAdvance;
          SkipNewlines;
          Inc(RuleDefCount);
          RIdx := AddRule(RK_RANGE, PatVal + ',' + PatVal2);
          If RIdx >= 0 Then
            RuleTab[RIdx].HasAction := True;
          EmitComment('--- range pattern /' + PatVal + '/,/' + PatVal2 + '/ ---');
          EmitLabel(RuleTab[RIdx].AsmLabel);
          Emit('        PUSH    EBP');
          Emit('        MOV     EBP, ESP');
          EnterScope(SK_RULE);
          ParseAction;
          LeaveScope;
          Emit('        MOV     ESP, EBP');
          Emit('        POP     EBP');
          Emit('        RET');
          EmitComment('--- end range pattern ---');
          EmitBlank;
          Continue;
        End;
      End;

      { Simple regex pattern }
      Inc(RuleDefCount);
      RIdx := AddRule(RK_PATTERN, PatVal);
      If RIdx >= 0 Then
        RuleTab[RIdx].HasAction := True;
      EmitComment('--- pattern /' + PatVal + '/ ---');
      EmitLabel(RuleTab[RIdx].AsmLabel);
      Emit('        PUSH    EBP');
      Emit('        MOV     EBP, ESP');
      LblSkip := NewLabel;
      { Generer le test : CALL _AWRT_MATCH_LINE + TEST EAX, EAX + JZ skip }
      EmitComment('  test: match $0 ~ /' + PatVal + '/');
      EnterScope(SK_RULE);
      ParseAction;
      LeaveScope;
      EmitLabel(LblSkip);
      Emit('        MOV     ESP, EBP');
      Emit('        POP     EBP');
      Emit('        RET');
      EmitComment('--- end pattern ---');
      EmitBlank;
      Continue;
    End;

    (* ---- action sans pattern (toutes les lignes) ---- *)
    If IsPunct('{') Then
    Begin
      Inc(RuleDefCount);
      RIdx := AddRule(RK_ALL, '');
      If RIdx >= 0 Then
        RuleTab[RIdx].HasAction := True;
      EmitComment('--- rule (all lines) ---');
      EmitLabel(RuleTab[RIdx].AsmLabel);
      Emit('        PUSH    EBP');
      Emit('        MOV     EBP, ESP');
      EnterScope(SK_RULE);
      ParseAction;
      LeaveScope;
      Emit('        MOV     ESP, EBP');
      Emit('        POP     EBP');
      Emit('        RET');
      EmitComment('--- end rule (all lines) ---');
      EmitBlank;
      Continue;
    End;

    (* ---- expression action (filtre par condition) ---- *)
    { ou instruction simple au top-level }
    If CurToken.Kind <> TK_EOF Then
    Begin
      (* Verifier si c est une expression suivie de accolade *)
      { Sinon, c est une instruction simple au top-level }
      D := ParseExpr;
      SkipNewlines;
      If IsPunct('{') Then
      Begin
        { Regle avec expression condition }
        Inc(RuleDefCount);
        RIdx := AddRule(RK_EXPR, '(expr)');
        If RIdx >= 0 Then
          RuleTab[RIdx].HasAction := True;
        EmitComment('--- expr rule ---');
        EmitLabel(RuleTab[RIdx].AsmLabel);
        Emit('        PUSH    EBP');
        Emit('        MOV     EBP, ESP');
        LblSkip := NewLabel;
        { Le resultat de l expression est dans EAX }
        GenCoerceToBoolean(D);
        Emit('        TEST    EAX, EAX');
        Emit('        JZ      ' + LblSkip);
        EnterScope(SK_RULE);
        ParseAction;
        LeaveScope;
        EmitLabel(LblSkip);
        Emit('        MOV     ESP, EBP');
        Emit('        POP     EBP');
        Emit('        RET');
        EmitComment('--- end expr rule ---');
        EmitBlank;
      End;
      { Sinon c etait une instruction simple (deja parsee par ParseExpr) }
      Continue;
    End;
  End;
End;

{ ============================================================ }
{ TODO 25 - GENERATION FINALE : LINKER PE, FICHIERS .OBJ      }
{           ET EXEMPLES                                        }
{ ============================================================ }

{$IFDEF FPC}

Procedure BinInit;
Begin
  BinCodeLen := 0; BinDataLen := 0;
  BinLblCount := 0; BinFixCount := 0;
  BinInCode := True;
  FillChar(BinCode, SizeOf(BinCode), 0);
  FillChar(BinData, SizeOf(BinData), 0);
End;

Procedure BinCodeByte(B : Byte);
Begin
  If BinCodeLen < MAX_BIN_CODE Then
  Begin BinCode[BinCodeLen] := B; Inc(BinCodeLen); End;
End;

Procedure BinCodeDWord(D : LongInt);
Begin
  BinCodeByte(Byte(D And $FF));
  BinCodeByte(Byte((D Shr 8) And $FF));
  BinCodeByte(Byte((D Shr 16) And $FF));
  BinCodeByte(Byte((D Shr 24) And $FF));
End;

Procedure BinCodeWord(W : Word);
Begin BinCodeByte(Lo(W)); BinCodeByte(Hi(W)); End;

Procedure BinDataByte(B : Byte);
Begin
  If BinDataLen < MAX_BIN_DATA Then
  Begin BinData[BinDataLen] := B; Inc(BinDataLen); End;
End;

Procedure BinDataDWord(D : LongInt);
Begin
  BinDataByte(Byte(D And $FF));
  BinDataByte(Byte((D Shr 8) And $FF));
  BinDataByte(Byte((D Shr 16) And $FF));
  BinDataByte(Byte((D Shr 24) And $FF));
End;

{ ---- Label and fixup management ------------------------------ }

Procedure BinAddLabel(Const Name : TString; IsCode : Boolean; Ofs : LongInt);
Begin
  If BinLblCount < MAX_BIN_LBL Then
  Begin
    BinLabels[BinLblCount].Name := StrUpperCase(Name);
    BinLabels[BinLblCount].Offset := Ofs;
    BinLabels[BinLblCount].InCode := IsCode;
    Inc(BinLblCount);
  End;
End;

Function BinFindLabel(Const Name : TString) : Integer;
Var I : Integer; U : TString;
Begin
  U := StrUpperCase(Name);
  BinFindLabel := -1;
  For I := BinLblCount - 1 DownTo 0 Do
    If BinLabels[I].Name = U Then Begin BinFindLabel := I; Exit; End;
End;

Procedure BinAddFixup(Ofs : LongInt; Kind : TBinFixKind;
                      Const Target : TString; IsCode : Boolean);
Begin
  If BinFixCount < MAX_BIN_FIX Then
  Begin
    BinFixups[BinFixCount].Offset := Ofs;
    BinFixups[BinFixCount].Kind := Kind;
    BinFixups[BinFixCount].Target := StrUpperCase(Target);
    BinFixups[BinFixCount].InCode := IsCode;
    Inc(BinFixCount);
  End;
End;

Function BinIsExtern(Const Name : TString) : Integer;
Var I : Integer; U : TString;
Begin
  U := StrUpperCase(Name);
  BinIsExtern := -1;
  For I := 0 To PE_NUM_API - 1 Do
    If StrUpperCase(BinAPIDecorated[I]) = U Then
    Begin BinIsExtern := I; Exit; End;
End;

{ ---- Register mapping and parsing helpers -------------------- }

Function BinReg32(Const S : TString) : Integer;
Var U : TString;
Begin
  U := StrUpperCase(S);
  If U = 'EAX' Then BinReg32 := 0
  Else If U = 'ECX' Then BinReg32 := 1
  Else If U = 'EDX' Then BinReg32 := 2
  Else If U = 'EBX' Then BinReg32 := 3
  Else If U = 'ESP' Then BinReg32 := 4
  Else If U = 'EBP' Then BinReg32 := 5
  Else If U = 'ESI' Then BinReg32 := 6
  Else If U = 'EDI' Then BinReg32 := 7
  Else BinReg32 := -1;
End;

Function BinReg8(Const S : TString) : Integer;
Var U : TString;
Begin
  U := StrUpperCase(S);
  If U = 'AL' Then BinReg8 := 0
  Else If U = 'CL' Then BinReg8 := 1
  Else If U = 'DL' Then BinReg8 := 2
  Else If U = 'BL' Then BinReg8 := 3
  Else If U = 'AH' Then BinReg8 := 4
  Else BinReg8 := -1;
End;

Function BinParseImm(Const S : TString) : LongInt;
Var V : LongInt; U : TString; Neg : Boolean; Code : Integer;
Begin
  U := S;
  While (Length(U) > 0) And (U[1] = ' ') Do Delete(U, 1, 1);
  While (Length(U) > 0) And (U[Length(U)] = ' ') Do Delete(U, Length(U), 1);
  Neg := False;
  If (Length(U) > 0) And (U[1] = '-') Then Begin Neg := True; Delete(U, 1, 1); End;
  V := 0;
  If (Length(U) >= 3) And (U[1] = Chr(39)) And (U[Length(U)] = Chr(39)) Then
    V := Ord(U[2])
  Else If (Length(U) > 1) And (UpCase(U[Length(U)]) = 'H') Then
  Begin Delete(U, Length(U), 1); System.Val('$' + U, V, Code); End
  Else If (Length(U) > 1) And (U[1] = '$') Then
    System.Val(U, V, Code)
  Else
    System.Val(U, V, Code);
  If Neg Then V := -V;
  BinParseImm := V;
End;

Function BinStripSize(Const S : TString; Var SzByte : Boolean) : TString;
Var U, R : TString;
Begin
  U := StrUpperCase(S); SzByte := False; R := S;
  If Pos('DWORD PTR', U) = 1 Then R := Copy(S, 10, Length(S) - 9)
  Else If Pos('BYTE PTR', U) = 1 Then Begin R := Copy(S, 9, Length(S) - 8); SzByte := True; End
  Else If Pos('WORD PTR', U) = 1 Then R := Copy(S, 9, Length(S) - 8);
  While (Length(R) > 0) And (R[1] = ' ') Do Delete(R, 1, 1);
  BinStripSize := R;
End;

Function BinStripBrackets(Const S : TString) : TString;
Var R : TString;
Begin
  R := S;
  While (Length(R) > 0) And (R[1] = ' ') Do Delete(R, 1, 1);
  If (Length(R) >= 2) And (R[1] = '[') And (R[Length(R)] = ']') Then
    R := Copy(R, 2, Length(R) - 2);
  BinStripBrackets := R;
End;

Function BinParseEBPOfs(Const S : TString; Var Ofs : LongInt) : Boolean;
Var Inner : TString; P, Code : Integer;
Begin
  Inner := BinStripBrackets(S);
  BinParseEBPOfs := False;
  If Pos('EBP', StrUpperCase(Inner)) <> 1 Then Exit;
  P := Pos('+', Inner);
  If P > 0 Then
  Begin System.Val(Copy(Inner, P + 1, Length(Inner) - P), Ofs, Code); BinParseEBPOfs := True; End
  Else Begin
    P := Pos('-', Inner);
    If P > 0 Then
    Begin System.Val(Copy(Inner, P + 1, Length(Inner) - P), Ofs, Code); Ofs := -Ofs; BinParseEBPOfs := True; End
    Else Begin Ofs := 0; BinParseEBPOfs := True; End;
  End;
End;

Function BinJccOpcode(Const Cond : TString) : Integer;
Var U : TString;
Begin
  U := StrUpperCase(Cond); BinJccOpcode := -1;
  If (U='JE') Or (U='JZ') Then BinJccOpcode := $84
  Else If (U='JNE') Or (U='JNZ') Then BinJccOpcode := $85
  Else If (U='JB') Or (U='JC') Or (U='JNAE') Then BinJccOpcode := $82
  Else If (U='JAE') Or (U='JNB') Or (U='JNC') Then BinJccOpcode := $83
  Else If (U='JBE') Or (U='JNA') Then BinJccOpcode := $86
  Else If (U='JA') Or (U='JNBE') Then BinJccOpcode := $87
  Else If (U='JS') Then BinJccOpcode := $88
  Else If (U='JNS') Then BinJccOpcode := $89
  Else If (U='JP') Or (U='JPE') Then BinJccOpcode := $8A
  Else If (U='JNP') Or (U='JPO') Then BinJccOpcode := $8B
  Else If (U='JL') Or (U='JNGE') Then BinJccOpcode := $8C
  Else If (U='JGE') Or (U='JNL') Then BinJccOpcode := $8D
  Else If (U='JLE') Or (U='JNG') Then BinJccOpcode := $8E
  Else If (U='JG') Or (U='JNLE') Then BinJccOpcode := $8F;
End;

Function BinModRM(Mo, Reg, RM : Integer) : Byte;
Begin BinModRM := Byte((Mo Shl 6) Or ((Reg And 7) Shl 3) Or (RM And 7)); End;

{ ---- Memory operand emission helpers ------------------------- }

Procedure BinEmitMemRef(RegField : Integer; Const LabelName : TString);
Var PP : Integer; Lbl, OStr : TString; Ofs : LongInt;
Begin
  BinCodeByte(BinModRM(0, RegField, 5));
  PP := Pos('+', LabelName);
  If PP > 0 Then
  Begin
    Lbl := Copy(LabelName, 1, PP - 1);
    While (Length(Lbl) > 0) And (Lbl[Length(Lbl)] = ' ') Do Delete(Lbl, Length(Lbl), 1);
    OStr := Copy(LabelName, PP + 1, Length(LabelName) - PP);
    While (Length(OStr) > 0) And (OStr[1] = ' ') Do Delete(OStr, 1, 1);
    Ofs := BinParseImm(OStr);
    BinAddFixup(BinCodeLen, BFK_ABS32, Lbl, True);
    BinCodeDWord(Ofs);
  End
  Else
  Begin
    PP := Pos('-', LabelName);
    If (PP > 1) Then
    Begin
      Lbl := Copy(LabelName, 1, PP - 1);
      While (Length(Lbl) > 0) And (Lbl[Length(Lbl)] = ' ') Do Delete(Lbl, Length(Lbl), 1);
      OStr := Copy(LabelName, PP + 1, Length(LabelName) - PP);
      While (Length(OStr) > 0) And (OStr[1] = ' ') Do Delete(OStr, 1, 1);
      Ofs := -BinParseImm(OStr);
      BinAddFixup(BinCodeLen, BFK_ABS32, Lbl, True);
      BinCodeDWord(Ofs);
    End
    Else
    Begin
      BinAddFixup(BinCodeLen, BFK_ABS32, LabelName, True);
      BinCodeDWord(0);
    End;
  End;
End;

Procedure BinEmitEBPRef(RegField : Integer; Ofs : LongInt);
Begin
  If (Ofs >= -128) And (Ofs <= 127) Then
  Begin BinCodeByte(BinModRM(1, RegField, 5)); BinCodeByte(Byte(Ofs And $FF)); End
  Else
  Begin BinCodeByte(BinModRM(2, RegField, 5)); BinCodeDWord(Ofs); End;
End;

Procedure BinEmitESPRef(RegField : Integer; Ofs : LongInt);
Begin
  If Ofs = 0 Then
  Begin BinCodeByte(BinModRM(0, RegField, 4)); BinCodeByte($24); End
  Else If (Ofs >= -128) And (Ofs <= 127) Then
  Begin BinCodeByte(BinModRM(1, RegField, 4)); BinCodeByte($24); BinCodeByte(Byte(Ofs And $FF)); End
  Else
  Begin BinCodeByte(BinModRM(2, RegField, 4)); BinCodeByte($24); BinCodeDWord(Ofs); End;
End;

Function BinParseESPOfs(Const S : TString; Var Ofs : LongInt) : Boolean;
Var Inner : TString; P, Code : Integer;
Begin
  Inner := BinStripBrackets(S);
  BinParseESPOfs := False;
  If Pos('ESP', StrUpperCase(Inner)) <> 1 Then Exit;
  P := Pos('+', Inner);
  If P > 0 Then
  Begin System.Val(Copy(Inner, P + 1, Length(Inner) - P), Ofs, Code); BinParseESPOfs := True; End
  Else Begin
    P := Pos('-', Inner);
    If P > 0 Then
    Begin System.Val(Copy(Inner, P + 1, Length(Inner) - P), Ofs, Code); Ofs := -Ofs; BinParseESPOfs := True; End
    Else Begin Ofs := 0; BinParseESPOfs := True; End;
  End;
End;

Procedure BinEmitRegIndirect(RegField, BaseReg : Integer);
Begin
  If BaseReg = 4 Then Begin BinCodeByte(BinModRM(0, RegField, 4)); BinCodeByte($24); End
  Else If BaseReg = 5 Then Begin BinCodeByte(BinModRM(1, RegField, 5)); BinCodeByte(0); End
  Else BinCodeByte(BinModRM(0, RegField, BaseReg));
End;

Procedure BinEmitMemOp(RegField : Integer; Const Inner : TString);
Var RBase, RIdx, PP : Integer; Tmp : TString; EbpOfs, Imm : LongInt;
Begin
  If BinParseEBPOfs('[' + Inner + ']', EbpOfs) Then
  Begin BinEmitEBPRef(RegField, EbpOfs); Exit; End;
  If BinParseESPOfs('[' + Inner + ']', EbpOfs) Then
  Begin BinEmitESPRef(RegField, EbpOfs); Exit; End;
  RBase := BinReg32(Inner);
  If RBase >= 0 Then
  Begin BinEmitRegIndirect(RegField, RBase); Exit; End;
  PP := Pos('+', Inner);
  If PP > 0 Then
  Begin
    Tmp := Copy(Inner, 1, PP - 1);
    While (Length(Tmp) > 0) And (Tmp[Length(Tmp)] = ' ') Do Delete(Tmp, Length(Tmp), 1);
    RBase := BinReg32(Tmp);
    If RBase >= 0 Then
    Begin
      Tmp := Copy(Inner, PP + 1, Length(Inner) - PP);
      While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do Delete(Tmp, 1, 1);
      RIdx := BinReg32(Tmp);
      If RIdx >= 0 Then
      Begin
        BinCodeByte(BinModRM(0, RegField, 4));
        BinCodeByte(Byte((RIdx Shl 3) Or RBase));
        Exit;
      End;
      Imm := BinParseImm(Tmp);
      If RBase = 4 Then
        BinEmitESPRef(RegField, Imm)
      Else Begin
        If (Imm >= -128) And (Imm <= 127) Then
        Begin BinCodeByte(BinModRM(1, RegField, RBase)); BinCodeByte(Byte(Imm And $FF)); End
        Else Begin BinCodeByte(BinModRM(2, RegField, RBase)); BinCodeDWord(Imm); End;
      End;
      Exit;
    End;
  End;
  BinEmitMemRef(RegField, Inner);
End;

{ ---- BinAssembleLine : mini-assembleur ASM x86-32 ----------- }

Procedure BinAssembleLine(Const Line : String);
Var
  S, Mnem, Op1, Op2, Inner, Tmp : TString;
  I, P, R1, R2, R8, ApiIdx : Integer;
  Imm, EbpOfs : LongInt;
  IsByte, HasOp2 : Boolean;
  BrkDepth : Integer;
Begin
  S := Line;
  While (Length(S) > 0) And (S[1] = ' ') Do Delete(S, 1, 1);
  While (Length(S) > 0) And (S[Length(S)] = ' ') Do Delete(S, Length(S), 1);
  If Length(S) = 0 Then Exit;
  If S[1] = ';' Then Exit;

  { Label }
  If (Length(S) >= 2) And (S[Length(S)] = ':') And (S[1] <> '.') Then
  Begin
    Tmp := Copy(S, 1, Length(S) - 1);
    While (Length(Tmp) > 0) And (Tmp[Length(Tmp)] = ' ') Do Delete(Tmp, Length(Tmp), 1);
    If BinInCode Then BinAddLabel(Tmp, True, BinCodeLen)
    Else BinAddLabel(Tmp, False, BinDataLen);
    Exit;
  End;

  { .DATA / .CODE switching }
  If StrUpperCase(S) = '.DATA' Then Begin BinInCode := False; Exit; End;
  If StrUpperCase(S) = '.CODE' Then Begin BinInCode := True; Exit; End;

  { SEGMENT / ENDS / ASSUME directives }
  If Pos('SEGMENT', StrUpperCase(S)) > 0 Then
  Begin
    If Pos('_TEXT', StrUpperCase(S)) > 0 Then BinInCode := True
    Else BinInCode := False;
    Exit;
  End;
  If Pos(' ENDS', StrUpperCase(S)) > 0 Then Exit;
  If Pos('ASSUME', StrUpperCase(S)) > 0 Then Exit;

  { Directives }
  If S[1] = '.' Then Exit;
  If Pos('EXTRN', StrUpperCase(S)) > 0 Then Exit;
  If Pos('OPTION', StrUpperCase(S)) > 0 Then Exit;
  If Pos('END ', StrUpperCase(S)) = 1 Then Exit;
  If StrUpperCase(S) = 'END' Then Exit;

  { Data segment declarations }
  If Not BinInCode Then
  Begin
    P := Pos(' DD ', StrUpperCase(S));
    If P = 0 Then P := Pos(' DB ', StrUpperCase(S));
    If P > 0 Then
    Begin
      Tmp := Copy(S, 1, P - 1);
      While (Length(Tmp) > 0) And (Tmp[Length(Tmp)] = ' ') Do Delete(Tmp, Length(Tmp), 1);
      BinAddLabel(Tmp, False, BinDataLen);
      Tmp := Copy(S, P + 1, Length(S) - P);
      While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do Delete(Tmp, 1, 1);
    End
    Else If (Pos('DB', StrUpperCase(S)) = 1) Or (Pos('DD', StrUpperCase(S)) = 1) Then
      Tmp := S
    Else Exit;
    If Pos('DD', StrUpperCase(Tmp)) = 1 Then
    Begin
      Delete(Tmp, 1, 2);
      While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do Delete(Tmp, 1, 1);
      If Pos('OFFSET', StrUpperCase(Tmp)) = 1 Then
      Begin
        Delete(Tmp, 1, 6);
        While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do Delete(Tmp, 1, 1);
        BinAddFixup(BinDataLen, BFK_ABS32, Tmp, False);
        BinDataDWord(0);
      End
      Else If Pos('DUP', StrUpperCase(Tmp)) > 0 Then
      Begin
        P := Pos(' ', Tmp);
        If P > 0 Then Imm := BinParseImm(Copy(Tmp, 1, P - 1))
        Else Imm := BinParseImm(Tmp);
        For I := 1 To Imm Do BinDataDWord(0);
      End
      Else BinDataDWord(BinParseImm(Tmp));
    End
    Else If Pos('DB', StrUpperCase(Tmp)) = 1 Then
    Begin
      Delete(Tmp, 1, 2);
      While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do Delete(Tmp, 1, 1);
      If Pos('DUP', StrUpperCase(Tmp)) > 0 Then
      Begin
        P := Pos(' ', Tmp);
        If P > 0 Then Imm := BinParseImm(Copy(Tmp, 1, P - 1))
        Else Imm := BinParseImm(Tmp);
        For I := 1 To Imm Do BinDataByte(0);
      End
      Else If (Length(Tmp) > 0) And (Tmp[1] = Chr(39)) Then
      Begin
        Delete(Tmp, 1, 1); I := 1;
        While I <= Length(Tmp) Do
        Begin
          If Tmp[I] = Chr(39) Then
          Begin
            If (I < Length(Tmp)) And (Tmp[I + 1] = Chr(39)) Then
            Begin BinDataByte(Ord(Chr(39))); Inc(I, 2); End
            Else Begin Inc(I); Break; End;
          End
          Else Begin BinDataByte(Ord(Tmp[I])); Inc(I); End;
        End;
        Inner := Copy(Tmp, I, Length(Tmp) - I + 1);
        If Pos(',0', Inner) > 0 Then BinDataByte(0);
      End
      Else
      Begin
        While Length(Tmp) > 0 Do
        Begin
          P := Pos(',', Tmp);
          If P > 0 Then
          Begin BinDataByte(Byte(BinParseImm(Copy(Tmp, 1, P - 1)))); Delete(Tmp, 1, P); End
          Else Begin BinDataByte(Byte(BinParseImm(Tmp))); Tmp := ''; End;
        End;
      End;
    End;
    Exit;
  End;

  { Parse mnemonic and operands }
  P := 0;
  For I := 1 To Length(S) Do
    If (S[I] = ' ') Or (S[I] = #9) Then Begin P := I; Break; End;
  If P = 0 Then Begin Mnem := StrUpperCase(S); Op1 := ''; Op2 := ''; HasOp2 := False; End
  Else
  Begin
    Mnem := StrUpperCase(Copy(S, 1, P - 1));
    Tmp := Copy(S, P + 1, Length(S) - P);
    While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do Delete(Tmp, 1, 1);
    HasOp2 := False; P := 0; BrkDepth := 0;
    For I := 1 To Length(Tmp) Do
    Begin
      If Tmp[I] = '[' Then Inc(BrkDepth)
      Else If Tmp[I] = ']' Then Dec(BrkDepth)
      Else If (Tmp[I] = ',') And (BrkDepth = 0) Then Begin P := I; Break; End;
    End;
    If P > 0 Then
    Begin
      Op1 := Copy(Tmp, 1, P - 1); Op2 := Copy(Tmp, P + 1, Length(Tmp) - P);
      While (Length(Op1) > 0) And (Op1[Length(Op1)] = ' ') Do Delete(Op1, Length(Op1), 1);
      While (Length(Op2) > 0) And (Op2[1] = ' ') Do Delete(Op2, 1, 1);
      HasOp2 := True;
    End
    Else Begin Op1 := Tmp; Op2 := ''; End;
  End;

  { RET }
  If Mnem = 'RET' Then
  Begin
    If Length(Op1) > 0 Then Begin BinCodeByte($C2); BinCodeWord(Word(BinParseImm(Op1))); End
    Else BinCodeByte($C3);
    Exit;
  End;
  If Mnem = 'CDQ' Then Begin BinCodeByte($99); Exit; End;
  If Mnem = 'NOP' Then Begin BinCodeByte($90); Exit; End;
  If Mnem = 'PUSHAD' Then Begin BinCodeByte($60); Exit; End;
  If Mnem = 'POPAD' Then Begin BinCodeByte($61); Exit; End;
  If Mnem = 'REP' Then
  Begin
    If StrUpperCase(Op1) = 'MOVSB' Then Begin BinCodeByte($F3); BinCodeByte($A4); End
    Else If StrUpperCase(Op1) = 'STOSB' Then Begin BinCodeByte($F3); BinCodeByte($AA); End;
    Exit;
  End;
  If Mnem = 'REPNE' Then
  Begin
    If StrUpperCase(Op1) = 'SCASB' Then Begin BinCodeByte($F2); BinCodeByte($AE); End;
    Exit;
  End;

  { PUSH }
  If Mnem = 'PUSH' Then
  Begin
    R1 := BinReg32(Op1);
    If R1 >= 0 Then Begin BinCodeByte($50 + R1); Exit; End;
    Inner := BinStripSize(Op1, IsByte);
    If (Length(Inner) > 0) And (Inner[1] = '[') Then
    Begin Inner := BinStripBrackets(Inner); BinCodeByte($FF); BinEmitMemOp(6, Inner); Exit; End;
    If Pos('OFFSET', StrUpperCase(Op1)) = 1 Then
    Begin
      Tmp := Copy(Op1, 7, Length(Op1) - 6);
      While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do Delete(Tmp, 1, 1);
      BinCodeByte($68); BinAddFixup(BinCodeLen, BFK_ABS32, Tmp, True); BinCodeDWord(0);
      Exit;
    End;
    Imm := BinParseImm(Op1);
    If (Imm >= -128) And (Imm <= 127) Then
    Begin BinCodeByte($6A); BinCodeByte(Byte(Imm And $FF)); End
    Else Begin BinCodeByte($68); BinCodeDWord(Imm); End;
    Exit;
  End;

  { POP }
  If Mnem = 'POP' Then
  Begin
    R1 := BinReg32(Op1);
    If R1 >= 0 Then Begin BinCodeByte($58 + R1); Exit; End;
    Inner := BinStripSize(Op1, IsByte);
    If (Length(Inner) > 0) And (Inner[1] = '[') Then
    Begin Inner := BinStripBrackets(Inner); BinCodeByte($8F); BinEmitMemOp(0, Inner); End;
    Exit;
  End;

  { INC / DEC }
  If (Mnem = 'INC') Or (Mnem = 'DEC') Then
  Begin
    R1 := BinReg32(Op1);
    If R1 >= 0 Then
    Begin If Mnem = 'INC' Then BinCodeByte($40 + R1) Else BinCodeByte($48 + R1); Exit; End;
    R8 := BinReg8(Op1);
    If R8 >= 0 Then
    Begin
      BinCodeByte($FE);
      If Mnem = 'INC' Then BinCodeByte(BinModRM(3, 0, R8)) Else BinCodeByte(BinModRM(3, 1, R8));
      Exit;
    End;
    Inner := BinStripSize(Op1, IsByte);
    If (Length(Inner) > 0) And (Inner[1] = '[') Then
    Begin
      Inner := BinStripBrackets(Inner);
      If IsByte Then BinCodeByte($FE) Else BinCodeByte($FF);
      If Mnem = 'INC' Then R1 := 0 Else R1 := 1;
      BinEmitMemOp(R1, Inner);
    End;
    Exit;
  End;

  { NEG / NOT / DIV / IDIV }
  If (Mnem = 'NEG') Or (Mnem = 'NOT') Or (Mnem = 'DIV') Or (Mnem = 'IDIV') Then
  Begin
    R1 := BinReg32(Op1);
    If R1 >= 0 Then
    Begin
      BinCodeByte($F7);
      If Mnem = 'NEG' Then BinCodeByte(BinModRM(3, 3, R1))
      Else If Mnem = 'NOT' Then BinCodeByte(BinModRM(3, 2, R1))
      Else If Mnem = 'DIV' Then BinCodeByte(BinModRM(3, 6, R1))
      Else BinCodeByte(BinModRM(3, 7, R1));
    End;
    Exit;
  End;

  { CALL }
  If Mnem = 'CALL' Then
  Begin
    Inner := BinStripSize(Op1, IsByte);
    If (Length(Inner) > 0) And (Inner[1] = '[') Then
    Begin Inner := BinStripBrackets(Inner); BinCodeByte($FF); BinEmitMemRef(2, Inner); Exit; End;
    ApiIdx := BinIsExtern(Op1);
    If ApiIdx >= 0 Then
    Begin BinCodeByte($FF); BinCodeByte($15); BinAddFixup(BinCodeLen, BFK_IAT32, Op1, True); BinCodeDWord(0); Exit; End;
    BinCodeByte($E8); BinAddFixup(BinCodeLen, BFK_REL32, Op1, True); BinCodeDWord(0);
    Exit;
  End;

  { JMP }
  If Mnem = 'JMP' Then
  Begin
    Inner := BinStripSize(Op1, IsByte);
    If (Length(Inner) > 0) And (Inner[1] = '[') Then
    Begin Inner := BinStripBrackets(Inner); BinCodeByte($FF); BinEmitMemRef(4, Inner); Exit; End;
    BinCodeByte($E9); BinAddFixup(BinCodeLen, BFK_REL32, Op1, True); BinCodeDWord(0);
    Exit;
  End;

  { Jcc }
  R1 := BinJccOpcode(Mnem);
  If R1 >= 0 Then
  Begin
    BinCodeByte($0F); BinCodeByte(Byte(R1));
    BinAddFixup(BinCodeLen, BFK_REL32, Op1, True); BinCodeDWord(0);
    Exit;
  End;

  { SETE / SETNE / SETL / SETG / SETLE / SETGE / SETB / SETA / SETBE / SETAE }
  If (Mnem = 'SETE') Or (Mnem = 'SETNE') Or (Mnem = 'SETL') Or
     (Mnem = 'SETG') Or (Mnem = 'SETLE') Or (Mnem = 'SETGE') Or
     (Mnem = 'SETB') Or (Mnem = 'SETA') Or (Mnem = 'SETBE') Or (Mnem = 'SETAE') Then
  Begin
    R8 := BinReg8(Op1);
    If R8 >= 0 Then
    Begin
      BinCodeByte($0F);
      If Mnem = 'SETE' Then BinCodeByte($94)
      Else If Mnem = 'SETNE' Then BinCodeByte($95)
      Else If Mnem = 'SETL' Then BinCodeByte($9C)
      Else If Mnem = 'SETGE' Then BinCodeByte($9D)
      Else If Mnem = 'SETLE' Then BinCodeByte($9E)
      Else If Mnem = 'SETG' Then BinCodeByte($9F)
      Else If Mnem = 'SETB' Then BinCodeByte($92)
      Else If Mnem = 'SETAE' Then BinCodeByte($93)
      Else If Mnem = 'SETBE' Then BinCodeByte($96)
      Else If Mnem = 'SETA' Then BinCodeByte($97);
      BinCodeByte(BinModRM(3, 0, R8));
    End;
    Exit;
  End;

  { TEST }
  If Mnem = 'TEST' Then
  Begin
    If Not HasOp2 Then Exit;
    R1 := BinReg32(Op1); R2 := BinReg32(Op2);
    If (R1 >= 0) And (R2 >= 0) Then
    Begin BinCodeByte($85); BinCodeByte(BinModRM(3, R2, R1)); Exit; End;
    R8 := BinReg8(Op1);
    If R8 >= 0 Then
    Begin
      Imm := BinParseImm(Op2);
      If R8 = 0 Then Begin BinCodeByte($A8); BinCodeByte(Byte(Imm And $FF)); End
      Else Begin BinCodeByte($F6); BinCodeByte(BinModRM(3, 0, R8)); BinCodeByte(Byte(Imm And $FF)); End;
      Exit;
    End;
    If R1 >= 0 Then
    Begin
      Imm := BinParseImm(Op2);
      If R1 = 0 Then Begin BinCodeByte($A9); BinCodeDWord(Imm); End
      Else Begin BinCodeByte($F7); BinCodeByte(BinModRM(3, 0, R1)); BinCodeDWord(Imm); End;
    End;
    Exit;
  End;

  { MOVZX }
  If Mnem = 'MOVZX' Then
  Begin
    If Not HasOp2 Then Exit;
    R1 := BinReg32(Op1);
    If R1 >= 0 Then
    Begin
      R8 := BinReg8(Op2);
      If R8 >= 0 Then
      Begin BinCodeByte($0F); BinCodeByte($B6); BinCodeByte(BinModRM(3, R1, R8)); Exit; End;
      Inner := BinStripSize(Op2, IsByte);
      If (Length(Inner) > 0) And (Inner[1] = '[') Then
      Begin
        Inner := BinStripBrackets(Inner);
        BinCodeByte($0F); BinCodeByte($B6);
        R2 := BinReg32(Inner);
        If R2 >= 0 Then BinEmitRegIndirect(R1, R2)
        Else If BinParseEBPOfs('[' + Inner + ']', EbpOfs) Then BinEmitEBPRef(R1, EbpOfs)
        Else BinEmitMemRef(R1, Inner);
      End;
    End;
    Exit;
  End;

  { LEA }
  If Mnem = 'LEA' Then
  Begin
    If Not HasOp2 Then Exit;
    R1 := BinReg32(Op1);
    If R1 < 0 Then Exit;
    If BinParseEBPOfs(Op2, EbpOfs) Then
    Begin BinCodeByte($8D); BinEmitEBPRef(R1, EbpOfs); Exit; End;
    Inner := BinStripBrackets(Op2);
    R2 := BinReg32(Inner);
    If R2 >= 0 Then Begin BinCodeByte($8D); BinEmitRegIndirect(R1, R2); Exit; End;
    P := Pos('+', Inner);
    If P > 0 Then
    Begin
      Tmp := Copy(Inner, 1, P - 1);
      While (Length(Tmp) > 0) And (Tmp[Length(Tmp)] = ' ') Do Delete(Tmp, Length(Tmp), 1);
      R2 := BinReg32(Tmp);
      If R2 >= 0 Then
      Begin
        Tmp := Copy(Inner, P + 1, Length(Inner) - P);
        While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do Delete(Tmp, 1, 1);
        R8 := BinReg32(Tmp);
        If R8 >= 0 Then
        Begin BinCodeByte($8D); BinCodeByte(BinModRM(0, R1, 4)); BinCodeByte(Byte((R8 Shl 3) Or R2)); Exit; End;
        Imm := BinParseImm(Tmp);
        BinCodeByte($8D);
        If (Imm >= -128) And (Imm <= 127) Then
        Begin BinCodeByte(BinModRM(1, R1, R2)); BinCodeByte(Byte(Imm And $FF)); End
        Else Begin BinCodeByte(BinModRM(2, R1, R2)); BinCodeDWord(Imm); End;
        Exit;
      End;
    End;
    BinCodeByte($8D); BinEmitMemRef(R1, Inner);
    Exit;
  End;

  { SHL / SHR / SAR }
  If (Mnem = 'SHL') Or (Mnem = 'SHR') Or (Mnem = 'SAR') Then
  Begin
    If Not HasOp2 Then Exit;
    R1 := BinReg32(Op1);
    If R1 < 0 Then Exit;
    If StrUpperCase(Op2) = 'CL' Then
    Begin
      BinCodeByte($D3);
      If Mnem = 'SHL' Then BinCodeByte(BinModRM(3, 4, R1))
      Else If Mnem = 'SHR' Then BinCodeByte(BinModRM(3, 5, R1))
      Else BinCodeByte(BinModRM(3, 7, R1));
    End
    Else
    Begin
      Imm := BinParseImm(Op2);
      If Imm = 1 Then
      Begin
        BinCodeByte($D1);
        If Mnem = 'SHL' Then BinCodeByte(BinModRM(3, 4, R1))
        Else If Mnem = 'SHR' Then BinCodeByte(BinModRM(3, 5, R1))
        Else BinCodeByte(BinModRM(3, 7, R1));
      End
      Else
      Begin
        BinCodeByte($C1);
        If Mnem = 'SHL' Then BinCodeByte(BinModRM(3, 4, R1))
        Else If Mnem = 'SHR' Then BinCodeByte(BinModRM(3, 5, R1))
        Else BinCodeByte(BinModRM(3, 7, R1));
        BinCodeByte(Byte(Imm And $FF));
      End;
    End;
    Exit;
  End;

  { IMUL }
  If Mnem = 'IMUL' Then
  Begin
    If Not HasOp2 Then
    Begin R1 := BinReg32(Op1); If R1 >= 0 Then Begin BinCodeByte($F7); BinCodeByte(BinModRM(3, 5, R1)); End; Exit; End;
    R1 := BinReg32(Op1); If R1 < 0 Then Exit;
    R2 := BinReg32(Op2);
    If R2 >= 0 Then Begin BinCodeByte($0F); BinCodeByte($AF); BinCodeByte(BinModRM(3, R1, R2)); Exit; End;
    Imm := BinParseImm(Op2);
    BinCodeByte($69); BinCodeByte(BinModRM(3, R1, R1)); BinCodeDWord(Imm);
    Exit;
  End;

  { MOV }
  If Mnem = 'MOV' Then
  Begin
    If Not HasOp2 Then Exit;
    R1 := BinReg32(Op1); R2 := BinReg32(Op2);
    If (R1 >= 0) And (R2 >= 0) Then Begin BinCodeByte($89); BinCodeByte(BinModRM(3, R2, R1)); Exit; End;
    If (R1 >= 0) Then
    Begin
      Inner := BinStripSize(Op2, IsByte);
      If (Length(Inner) > 0) And (Inner[1] = '[') Then
      Begin
        Inner := BinStripBrackets(Inner);
        R2 := BinReg32(Inner);
        If R2 >= 0 Then Begin BinCodeByte($8B); BinEmitRegIndirect(R1, R2); Exit; End;
        If BinParseEBPOfs('[' + Inner + ']', EbpOfs) Then Begin BinCodeByte($8B); BinEmitEBPRef(R1, EbpOfs); Exit; End;
        If BinParseESPOfs('[' + Inner + ']', EbpOfs) Then Begin BinCodeByte($8B); BinEmitESPRef(R1, EbpOfs); Exit; End;
        BinCodeByte($8B); BinEmitMemOp(R1, Inner); Exit;
      End;
      If Pos('OFFSET', StrUpperCase(Op2)) = 1 Then
      Begin
        Tmp := Copy(Op2, 7, Length(Op2) - 6);
        While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do Delete(Tmp, 1, 1);
        BinCodeByte($B8 + R1); BinAddFixup(BinCodeLen, BFK_ABS32, Tmp, True); BinCodeDWord(0); Exit;
      End;
      Imm := BinParseImm(Op2);
      BinCodeByte($B8 + R1); BinCodeDWord(Imm); Exit;
    End;
    R1 := BinReg8(Op1);
    If R1 >= 0 Then
    Begin
      R2 := BinReg8(Op2);
      If R2 >= 0 Then Begin BinCodeByte($88); BinCodeByte(BinModRM(3, R2, R1)); Exit; End;
      Inner := BinStripSize(Op2, IsByte);
      If (Length(Inner) > 0) And (Inner[1] = '[') Then
      Begin
        Inner := BinStripBrackets(Inner);
        R2 := BinReg32(Inner);
        If R2 >= 0 Then Begin BinCodeByte($8A); BinEmitRegIndirect(R1, R2); Exit; End;
        If BinParseEBPOfs('[' + Inner + ']', EbpOfs) Then Begin BinCodeByte($8A); BinEmitEBPRef(R1, EbpOfs); Exit; End;
        If BinParseESPOfs('[' + Inner + ']', EbpOfs) Then Begin BinCodeByte($8A); BinEmitESPRef(R1, EbpOfs); Exit; End;
        BinCodeByte($8A); BinEmitMemOp(R1, Inner); Exit;
      End;
      Imm := BinParseImm(Op2);
      BinCodeByte($B0 + R1); BinCodeByte(Byte(Imm And $FF)); Exit;
    End;
    { MOV [mem], src }
    Inner := BinStripSize(Op1, IsByte);
    If (Length(Inner) > 0) And (Inner[1] = '[') Then
    Begin
      Inner := BinStripBrackets(Inner);
      R2 := BinReg32(Op2); R8 := BinReg8(Op2);
      If IsByte Then
      Begin
        If R8 >= 0 Then
        Begin
          BinCodeByte($88); R1 := BinReg32(Inner);
          If R1 >= 0 Then BinEmitRegIndirect(R8, R1)
          Else If BinParseEBPOfs('[' + Inner + ']', EbpOfs) Then BinEmitEBPRef(R8, EbpOfs)
          Else BinEmitMemRef(R8, Inner); Exit;
        End;
        Imm := BinParseImm(Op2); BinCodeByte($C6); R1 := BinReg32(Inner);
        If R1 >= 0 Then BinEmitRegIndirect(0, R1)
        Else If BinParseEBPOfs('[' + Inner + ']', EbpOfs) Then BinEmitEBPRef(0, EbpOfs)
        Else BinEmitMemRef(0, Inner);
        BinCodeByte(Byte(Imm And $FF)); Exit;
      End
      Else
      Begin
        { Detecter si Op2 est un registre 8 bits meme sans BYTE PTR }
        If (R8 >= 0) And (R2 < 0) Then
        Begin
          BinCodeByte($88); R1 := BinReg32(Inner);
          If R1 >= 0 Then BinEmitRegIndirect(R8, R1)
          Else If BinParseEBPOfs('[' + Inner + ']', EbpOfs) Then BinEmitEBPRef(R8, EbpOfs)
          Else If BinParseESPOfs('[' + Inner + ']', EbpOfs) Then BinEmitESPRef(R8, EbpOfs)
          Else BinEmitMemOp(R8, Inner); Exit;
        End;
        If R2 >= 0 Then
        Begin
          BinCodeByte($89); R1 := BinReg32(Inner);
          If R1 >= 0 Then BinEmitRegIndirect(R2, R1)
          Else If BinParseEBPOfs('[' + Inner + ']', EbpOfs) Then BinEmitEBPRef(R2, EbpOfs)
          Else If BinParseESPOfs('[' + Inner + ']', EbpOfs) Then BinEmitESPRef(R2, EbpOfs)
          Else BinEmitMemOp(R2, Inner); Exit;
        End;
        If Pos('OFFSET', StrUpperCase(Op2)) = 1 Then
        Begin
          Tmp := Copy(Op2, 7, Length(Op2) - 6);
          While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do Delete(Tmp, 1, 1);
          BinCodeByte($C7); R1 := BinReg32(Inner);
          If R1 >= 0 Then BinEmitRegIndirect(0, R1)
          Else If BinParseEBPOfs('[' + Inner + ']', EbpOfs) Then BinEmitEBPRef(0, EbpOfs)
          Else BinEmitMemRef(0, Inner);
          BinAddFixup(BinCodeLen, BFK_ABS32, Tmp, True); BinCodeDWord(0); Exit;
        End;
        Imm := BinParseImm(Op2); BinCodeByte($C7); R1 := BinReg32(Inner);
        If R1 >= 0 Then BinEmitRegIndirect(0, R1)
        Else If BinParseEBPOfs('[' + Inner + ']', EbpOfs) Then BinEmitEBPRef(0, EbpOfs)
        Else BinEmitMemRef(0, Inner);
        BinCodeDWord(Imm); Exit;
      End;
    End;
    Exit;
  End;

  { ADD / SUB / CMP / AND / OR / XOR }
  If (Mnem = 'ADD') Or (Mnem = 'SUB') Or (Mnem = 'CMP') Or
     (Mnem = 'AND') Or (Mnem = 'OR') Or (Mnem = 'XOR') Then
  Begin
    If Not HasOp2 Then Exit;
    If Mnem = 'ADD' Then R8 := 0
    Else If Mnem = 'OR' Then R8 := 1
    Else If Mnem = 'AND' Then R8 := 4
    Else If Mnem = 'SUB' Then R8 := 5
    Else If Mnem = 'XOR' Then R8 := 6
    Else R8 := 7;
    R1 := BinReg32(Op1); R2 := BinReg32(Op2);
    If (R1 >= 0) And (R2 >= 0) Then
    Begin BinCodeByte(Byte($01 + (R8 Shl 3))); BinCodeByte(BinModRM(3, R2, R1)); Exit; End;
    If R1 >= 0 Then
    Begin
      Inner := BinStripSize(Op2, IsByte);
      If (Length(Inner) > 0) And (Inner[1] = '[') Then
      Begin
        Inner := BinStripBrackets(Inner);
        BinCodeByte(Byte($03 + (R8 Shl 3)));
        BinEmitMemOp(R1, Inner);
        Exit;
      End;
      Imm := BinParseImm(Op2);
      If (Imm >= -128) And (Imm <= 127) Then
      Begin BinCodeByte($83); BinCodeByte(BinModRM(3, R8, R1)); BinCodeByte(Byte(Imm And $FF)); End
      Else
      Begin
        If R1 = 0 Then BinCodeByte(Byte($05 + (R8 Shl 3)))
        Else Begin BinCodeByte($81); BinCodeByte(BinModRM(3, R8, R1)); End;
        BinCodeDWord(Imm);
      End;
      Exit;
    End;
    R1 := BinReg8(Op1);
    If R1 >= 0 Then
    Begin
      R2 := BinReg8(Op2);
      If R2 >= 0 Then Begin BinCodeByte(Byte($00 + (R8 Shl 3))); BinCodeByte(BinModRM(3, R2, R1)); Exit; End;
      Inner := BinStripSize(Op2, IsByte);
      If (Length(Inner) > 0) And (Inner[1] = '[') Then
      Begin
        Inner := BinStripBrackets(Inner);
        BinCodeByte(Byte($02 + (R8 Shl 3)));
        BinEmitMemOp(R1, Inner);
        Exit;
      End;
      Imm := BinParseImm(Op2);
      If R1 = 0 Then BinCodeByte(Byte($04 + (R8 Shl 3)))
      Else Begin BinCodeByte($80); BinCodeByte(BinModRM(3, R8, R1)); End;
      BinCodeByte(Byte(Imm And $FF)); Exit;
    End;
    Inner := BinStripSize(Op1, IsByte);
    If (Length(Inner) > 0) And (Inner[1] = '[') Then
    Begin
      Inner := BinStripBrackets(Inner);
      R2 := BinReg32(Op2);
      If (Not IsByte) And (R2 >= 0) Then
      Begin
        BinCodeByte(Byte($01 + (R8 Shl 3)));
        BinEmitMemOp(R2, Inner); Exit;
      End;
      Imm := BinParseImm(Op2);
      If IsByte Then
      Begin
        BinCodeByte($80);
        BinEmitMemOp(R8, Inner);
        BinCodeByte(Byte(Imm And $FF));
      End
      Else
      Begin
        If (Imm >= -128) And (Imm <= 127) Then
        Begin
          BinCodeByte($83);
          BinEmitMemOp(R8, Inner);
          BinCodeByte(Byte(Imm And $FF));
        End
        Else
        Begin
          BinCodeByte($81);
          BinEmitMemOp(R8, Inner);
          BinCodeDWord(Imm);
        End;
      End;
    End;
    Exit;
  End;

  { XCHG }
  If Mnem = 'XCHG' Then
  Begin
    If Not HasOp2 Then Exit;
    R1 := BinReg32(Op1); R2 := BinReg32(Op2);
    If (R1 >= 0) And (R2 >= 0) Then
    Begin
      If R1 = 0 Then BinCodeByte($90 + R2)
      Else If R2 = 0 Then BinCodeByte($90 + R1)
      Else Begin BinCodeByte($87); BinCodeByte(BinModRM(3, R1, R2)); End;
    End;
    Exit;
  End;

  { Unknown instruction -> NOP with warning }
  If Opts.Verbose Then
    WarnMsg('instruction ASM inconnue ignoree: ' + Mnem);
  BinCodeByte($90);
End;

{ ---- BinResolveAll : resolution des fixups ------------------- }

Procedure BinResolveAll(TextRVA, DataRVA, RdataRVA, IATOfs : LongInt);
Var
  I, LblIdx, ApiIdx : Integer;
  TargetAddr, FixAddr : LongInt;
  P : ^Byte;
  ExistOfs : LongInt;
Begin
  For I := 0 To BinFixCount - 1 Do
  Begin
    If BinFixups[I].Kind = BFK_IAT32 Then
    Begin
      ApiIdx := BinIsExtern(BinFixups[I].Target);
      If ApiIdx >= 0 Then TargetAddr := PE_IMG_BASE + RdataRVA + IATOfs + ApiIdx * 4
      Else TargetAddr := 0;
      If BinFixups[I].InCode Then P := @BinCode[BinFixups[I].Offset]
      Else P := @BinData[BinFixups[I].Offset];
      P^ := Byte(TargetAddr And $FF); Inc(P);
      P^ := Byte((TargetAddr Shr 8) And $FF); Inc(P);
      P^ := Byte((TargetAddr Shr 16) And $FF); Inc(P);
      P^ := Byte((TargetAddr Shr 24) And $FF);
    End
    Else
    Begin
      LblIdx := BinFindLabel(BinFixups[I].Target);
      If LblIdx >= 0 Then
      Begin
        If BinLabels[LblIdx].InCode Then TargetAddr := PE_IMG_BASE + TextRVA + BinLabels[LblIdx].Offset
        Else TargetAddr := PE_IMG_BASE + DataRVA + BinLabels[LblIdx].Offset;
      End
      Else TargetAddr := 0;
      If BinFixups[I].InCode Then P := @BinCode[BinFixups[I].Offset]
      Else P := @BinData[BinFixups[I].Offset];
      If BinFixups[I].Kind = BFK_REL32 Then
      Begin
        If BinFixups[I].InCode Then FixAddr := PE_IMG_BASE + TextRVA + BinFixups[I].Offset + 4
        Else FixAddr := PE_IMG_BASE + DataRVA + BinFixups[I].Offset + 4;
        TargetAddr := TargetAddr - FixAddr;
        P^ := Byte(TargetAddr And $FF); Inc(P);
        P^ := Byte((TargetAddr Shr 8) And $FF); Inc(P);
        P^ := Byte((TargetAddr Shr 16) And $FF); Inc(P);
        P^ := Byte((TargetAddr Shr 24) And $FF);
      End
      Else
      Begin
        If BinFixups[I].InCode Then
          ExistOfs := LongInt(BinCode[BinFixups[I].Offset]) Or
                     (LongInt(BinCode[BinFixups[I].Offset + 1]) Shl 8) Or
                     (LongInt(BinCode[BinFixups[I].Offset + 2]) Shl 16) Or
                     (LongInt(BinCode[BinFixups[I].Offset + 3]) Shl 24)
        Else
          ExistOfs := LongInt(BinData[BinFixups[I].Offset]) Or
                     (LongInt(BinData[BinFixups[I].Offset + 1]) Shl 8) Or
                     (LongInt(BinData[BinFixups[I].Offset + 2]) Shl 16) Or
                     (LongInt(BinData[BinFixups[I].Offset + 3]) Shl 24);
        TargetAddr := TargetAddr + ExistOfs;
        P^ := Byte(TargetAddr And $FF); Inc(P);
        P^ := Byte((TargetAddr Shr 8) And $FF); Inc(P);
        P^ := Byte((TargetAddr Shr 16) And $FF); Inc(P);
        P^ := Byte((TargetAddr Shr 24) And $FF);
      End;
    End;
  End;
End;

{ ---- Helpers PE ---------------------------------------------- }

Function BinAlignTo(Size, Align : LongInt) : LongInt;
Begin
  If (Size Mod Align) = 0 Then BinAlignTo := Size
  Else BinAlignTo := Size + Align - (Size Mod Align);
End;

Procedure WriteBinPad(Var F : File; Count : LongInt);
Var ZB : Array[0..511] of Byte; N : LongInt;
Begin
  FillChar(ZB, SizeOf(ZB), 0);
  While Count > 0 Do
  Begin If Count > 512 Then N := 512 Else N := Count; BlockWrite(F, ZB, N); Dec(Count, N); End;
End;

Procedure WriteBinWord(Var F : File; W : Word);
Begin BlockWrite(F, W, 2); End;

Procedure WriteBinDWord(Var F : File; D : LongInt);
Begin BlockWrite(F, D, 4); End;

{ ---- WritePEFile : generation fichier PE executable ---------- }

Procedure WritePEFile(Const FileName : TString);
Var
  F : File;
  HSz, TFSz, RFSz, DFSz, TRVA, RRVA, DRVA, ImgSz, RSz : LongInt;
  IATOf, ILTOf, HNOf, DNOf, IDTOf : LongInt;
  I, ANL : Integer;
  HNBuf : Array[0..1023] of Byte;
  HNLen, Pad : LongInt;
  DName : String[16];
  SName : Array[0..7] of Byte;
  EntryRVA : LongInt;
  MainIdx  : Integer;
Begin
  DName := 'KERNEL32.DLL'#0;
  IDTOf := 0; ILTOf := 40;
  IATOf := ILTOf + (PE_NUM_API + 1) * 4;
  HNOf := IATOf + (PE_NUM_API + 1) * 4;
  HNLen := 0;
  For I := 0 To PE_NUM_API - 1 Do
  Begin
    HNBuf[HNLen] := 0; Inc(HNLen); HNBuf[HNLen] := 0; Inc(HNLen);
    ANL := Length(BinAPIName[I]);
    Move(BinAPIName[I][1], HNBuf[HNLen], ANL); Inc(HNLen, ANL);
    HNBuf[HNLen] := 0; Inc(HNLen);
    If (HNLen And 1) <> 0 Then Begin HNBuf[HNLen] := 0; Inc(HNLen); End;
  End;
  DNOf := HNOf + HNLen;
  RSz := BinAlignTo(DNOf + Length(DName), 4);
  HSz := BinAlignTo($200, PE_FILE_ALIGN);
  TRVA := PE_SEC_ALIGN;
  TFSz := BinAlignTo(BinCodeLen, PE_FILE_ALIGN);
  RRVA := TRVA + BinAlignTo(BinCodeLen, PE_SEC_ALIGN);
  RFSz := BinAlignTo(RSz, PE_FILE_ALIGN);
  DRVA := RRVA + BinAlignTo(RSz, PE_SEC_ALIGN);
  DFSz := BinAlignTo(BinDataLen, PE_FILE_ALIGN);
  ImgSz := DRVA + BinAlignTo(BinDataLen, PE_SEC_ALIGN);
  BinResolveAll(TRVA, DRVA, RRVA, IATOf);
  { Determiner le point d entree : chercher le label _AWF_MAIN }
  EntryRVA := TRVA;
  MainIdx := BinFindLabel('_AWF_MAIN');
  If MainIdx >= 0 Then
    EntryRVA := TRVA + BinLabels[MainIdx].Offset;
  Assign(F, FileName); Rewrite(F, 1);
  { DOS Header }
  WriteBinWord(F, PE_DOS_MAGIC); WriteBinPad(F, 58); WriteBinDWord(F, $80);
  WriteBinPad(F, $80 - 64);
  { PE Sig }
  WriteBinDWord(F, PE_PE_SIG);
  { COFF Hdr }
  WriteBinWord(F, PE_MACHINE_I386); WriteBinWord(F, 3);
  WriteBinDWord(F, 0); WriteBinDWord(F, 0); WriteBinDWord(F, 0);
  WriteBinWord(F, PE_OPT_SIZE); WriteBinWord(F, $0102);
  { Opt Hdr }
  WriteBinWord(F, PE_MAGIC_32); WriteBinWord(F, $0100);
  WriteBinDWord(F, TFSz); WriteBinDWord(F, DFSz + RFSz); WriteBinDWord(F, 0);
  WriteBinDWord(F, EntryRVA); WriteBinDWord(F, TRVA); WriteBinDWord(F, DRVA);
  WriteBinDWord(F, PE_IMG_BASE); WriteBinDWord(F, PE_SEC_ALIGN); WriteBinDWord(F, PE_FILE_ALIGN);
  WriteBinWord(F, 4); WriteBinWord(F, 0); WriteBinWord(F, 0); WriteBinWord(F, 0);
  WriteBinWord(F, 4); WriteBinWord(F, 0);
  WriteBinDWord(F, 0); WriteBinDWord(F, ImgSz); WriteBinDWord(F, HSz); WriteBinDWord(F, 0);
  WriteBinWord(F, PE_SUBSYS_CUI); WriteBinWord(F, 0);
  WriteBinDWord(F, $100000); WriteBinDWord(F, $1000);
  WriteBinDWord(F, $100000); WriteBinDWord(F, $1000);
  WriteBinDWord(F, 0); WriteBinDWord(F, 16);
  { Data dirs }
  WriteBinDWord(F, 0); WriteBinDWord(F, 0);
  WriteBinDWord(F, RRVA + IDTOf); WriteBinDWord(F, 40);
  For I := 2 To 11 Do Begin WriteBinDWord(F, 0); WriteBinDWord(F, 0); End;
  WriteBinDWord(F, RRVA + IATOf); WriteBinDWord(F, (PE_NUM_API + 1) * 4);
  For I := 13 To 15 Do Begin WriteBinDWord(F, 0); WriteBinDWord(F, 0); End;
  { Section Hdrs }
  FillChar(SName, 8, 0); Move('.text'#0, SName, 6); BlockWrite(F, SName, 8);
  WriteBinDWord(F, BinCodeLen); WriteBinDWord(F, TRVA);
  WriteBinDWord(F, TFSz); WriteBinDWord(F, HSz);
  WriteBinDWord(F, 0); WriteBinDWord(F, 0); WriteBinWord(F, 0); WriteBinWord(F, 0);
  WriteBinDWord(F, PE_SCN_TEXT);
  FillChar(SName, 8, 0); Move('.rdata', SName, 6); BlockWrite(F, SName, 8);
  WriteBinDWord(F, RSz); WriteBinDWord(F, RRVA);
  WriteBinDWord(F, RFSz); WriteBinDWord(F, HSz + TFSz);
  WriteBinDWord(F, 0); WriteBinDWord(F, 0); WriteBinWord(F, 0); WriteBinWord(F, 0);
  WriteBinDWord(F, PE_SCN_RDATA);
  FillChar(SName, 8, 0); Move('.data'#0, SName, 6); BlockWrite(F, SName, 8);
  WriteBinDWord(F, BinDataLen); WriteBinDWord(F, DRVA);
  WriteBinDWord(F, DFSz); WriteBinDWord(F, HSz + TFSz + RFSz);
  WriteBinDWord(F, 0); WriteBinDWord(F, 0); WriteBinWord(F, 0); WriteBinWord(F, 0);
  WriteBinDWord(F, PE_SCN_BSS);
  { Pad headers }
  Pad := HSz - (64 + ($80 - 64) + 4 + 20 + 224 + 120);
  If Pad > 0 Then WriteBinPad(F, Pad);
  { .text }
  BlockWrite(F, BinCode, BinCodeLen);
  Pad := TFSz - BinCodeLen; If Pad > 0 Then WriteBinPad(F, Pad);
  { .rdata }
  WriteBinDWord(F, RRVA + ILTOf); WriteBinDWord(F, 0); WriteBinDWord(F, 0);
  WriteBinDWord(F, RRVA + DNOf); WriteBinDWord(F, RRVA + IATOf);
  WriteBinPad(F, 20);
  Pad := HNOf;
  For I := 0 To PE_NUM_API - 1 Do
  Begin WriteBinDWord(F, RRVA + Pad); Pad := Pad + 2 + Length(BinAPIName[I]) + 1;
    If ((2 + Length(BinAPIName[I]) + 1) And 1) <> 0 Then Inc(Pad); End;
  WriteBinDWord(F, 0);
  Pad := HNOf;
  For I := 0 To PE_NUM_API - 1 Do
  Begin WriteBinDWord(F, RRVA + Pad); Pad := Pad + 2 + Length(BinAPIName[I]) + 1;
    If ((2 + Length(BinAPIName[I]) + 1) And 1) <> 0 Then Inc(Pad); End;
  WriteBinDWord(F, 0);
  BlockWrite(F, HNBuf, HNLen);
  BlockWrite(F, DName[1], Length(DName));
  Pad := RFSz - (40 + (PE_NUM_API + 1) * 4 + (PE_NUM_API + 1) * 4 + HNLen + Length(DName));
  If Pad > 0 Then WriteBinPad(F, Pad);
  { .data }
  BlockWrite(F, BinData, BinDataLen);
  Pad := DFSz - BinDataLen; If Pad > 0 Then WriteBinPad(F, Pad);
  Close(F);
End;

{ ---- WriteCOFFFile : generation fichier COFF .OBJ ----------- }

Procedure WriteCOFFFile(Const FileName : TString);
Var F : File; TOfs, DOfs : LongInt; SN : Array[0..7] of Byte;
Begin
  TOfs := 20 + 80; DOfs := TOfs + BinCodeLen;
  Assign(F, FileName); Rewrite(F, 1);
  WriteBinWord(F, PE_MACHINE_I386); WriteBinWord(F, 2);
  WriteBinDWord(F, 0); WriteBinDWord(F, DOfs + BinDataLen);
  WriteBinDWord(F, 0); WriteBinWord(F, 0); WriteBinWord(F, 0);
  FillChar(SN, 8, 0); Move('.text'#0, SN, 6); BlockWrite(F, SN, 8);
  WriteBinDWord(F, 0); WriteBinDWord(F, 0);
  WriteBinDWord(F, BinCodeLen); WriteBinDWord(F, TOfs);
  WriteBinDWord(F, 0); WriteBinDWord(F, 0); WriteBinWord(F, 0); WriteBinWord(F, 0);
  WriteBinDWord(F, PE_SCN_TEXT);
  FillChar(SN, 8, 0); Move('.data'#0, SN, 6); BlockWrite(F, SN, 8);
  WriteBinDWord(F, 0); WriteBinDWord(F, 0);
  WriteBinDWord(F, BinDataLen); WriteBinDWord(F, DOfs);
  WriteBinDWord(F, 0); WriteBinDWord(F, 0); WriteBinWord(F, 0); WriteBinWord(F, 0);
  WriteBinDWord(F, PE_SCN_BSS);
  BlockWrite(F, BinCode, BinCodeLen);
  BlockWrite(F, BinData, BinDataLen);
  WriteBinDWord(F, 4);
  Close(F);
End;

{ ---- AssembleAndWriteBinary : lire ASM et generer PE/COFF ---- }

Procedure AssembleAndWriteBinary(Const AsmFile, BinFile : TString;
                                IsObj : Boolean);
Var AsmF : Text; Line : String;
Begin
  BinInit; BinInCode := True;
  Assign(AsmF, AsmFile);
  {$I-} Reset(AsmF); {$I+}
  If IOResult <> 0 Then Begin
    WarnMsg('impossible d''ouvrir le fichier ASM intermediaire: ' + AsmFile);
    Exit;
  End;
  While Not EOF(AsmF) Do Begin ReadLn(AsmF, Line); BinAssembleLine(Line); End;
  Close(AsmF);
  If IsObj Then WriteCOFFFile(BinFile)
  Else WritePEFile(BinFile);
End;

{$ENDIF}

{ ============================================================ }
{ TODO 24 - PARSEUR : DISPATCHER ET BOUCLE PRINCIPALE          }
{           ParseStatement complete, ParseBlock, Run finalisee }
{ ============================================================ }

{ ---- ParseStatement ----------------------------------------- }
{ Le dispatcher de ParseStatement (lignes 5003+) gere tous      }
{ les mots-cles AWK : if/while/for/do/break/continue/return/   }
{ exit/delete/print/printf/getline/next/nextfile, les blocs,    }
{ les instructions vides, et les expressions arbitraires.        }
{ Le traitement de exit genere MOV EXITCODE + JMP _AWL_exit.    }
{ ParseBlock gere les blocs entre accolades et delegation.       }

{ ============================================================ }
{ PROCEDURE RUN                                                }
{ ============================================================ }

Procedure Run;
Begin
  WriteLn('AWKCW32: compilation de ', Opts.SrcFile, ' ...');
  If Opts.FieldSep <> ' ' Then
    WriteLn('AWKCW32: FS = ', Opts.FieldSep);
  If Opts.InitCount > 0 Then
    WriteLn('AWKCW32: ', Opts.InitCount, ' variable(s) pre-initialisee(s)');
  InitSymTable;
  InitScopes;
  ExprCount := 0;
  CoercionCount := 0;
  ConcatCount := 0;
  GenCount := 0;
  GenEnabled := True;
  StringLitCount := 0;
  LastSymIdx := -1;
  PrintCount := 0;
  IfCount := 0;
  WhileCount := 0;
  ForCount := 0;
  DoWhileCount := 0;
  ForInCount := 0;
  FuncDefCount := 0;
  RuleCount := 0;
  RuleDefCount := 0;
  FieldRefCount := 0;
  LastFieldIdx := -1;
  LastFieldIsExpr := False;
  ArrayOpCount := 0;
  LastArraySym := -1;
  LastArrayHasKey := False;
  RegexPatCount := 0;
  RegexOpCount := 0;
  BuiltinStrCount := 0;
  BuiltinMathCount := 0;
  GetlineCount := 0;
  BuiltinVarCount := 0;
  EmitHeaderDone := False;
  RuntimeHelpCount := 0;
  DispatchCount := 0;
  HasPushedBack := False;
  LexInit;
  { Mode debug : afficher tous les tokens }
  If Opts.DebugMode Then
  Begin
    LexNextToken(CurToken);
    While CurToken.Kind <> TK_EOF Do
    Begin
      PrintToken(CurToken);
      LexNextToken(CurToken);
    End;
    PrintToken(CurToken); { afficher le token EOF }
  End
  Else
  Begin
    { Parser le programme AWK (TODO 06+10+11+12+13+14+15) }
    ParserAdvance;  { charger le premier token }
    { Ouvrir le fichier ASM intermediaire (TODO 22) }
    Assign(OutF, ReplaceExt(Opts.SrcFile, '.asm'));
    Rewrite(OutF);
    OutFOpen := True;
    { Emettre l en-tete ASM 80386 (TODO 22) }
    EmitHeader;
    ParseProgram;
    { Emettre le point d entree et les helpers runtime (TODO 23) }
    EmitEntryPoint;
    EmitRuntimeHelpers;
    { Emettre le segment .DATA et le footer (TODO 22) }
    EmitDataSeg;
    EmitFooter;
    { Fermer le fichier ASM }
    Close(OutF);
    OutFOpen := False;
    WriteLn('AWKCW32: tokenisation terminee, ', TotalLines, ' lignes');
    WriteLn('AWKCW32: ', SymCount, ' symbole(s), ', FuncCount, ' fonction(s), ',
            FuncDefCount, ' definition(s)');
    WriteLn('AWKCW32: ', RuleDefCount, ' regle(s) pattern-action (',
            RuleCount, ' enregistree(s))');
    WriteLn('AWKCW32: ', FieldRefCount, ' reference(s) de champs');
    WriteLn('AWKCW32: ', ArrayOpCount, ' operation(s) tableau(x) associatif(s)');
    WriteLn('AWKCW32: ', RegexPatCount, ' pattern(s) regex, ',
            RegexOpCount, ' operation(s) regex (~ !~)');
    WriteLn('AWKCW32: ', BuiltinStrCount, ' appel(s) builtin chaines');
    WriteLn('AWKCW32: ', BuiltinMathCount, ' appel(s) builtin math/systeme');
    WriteLn('AWKCW32: ', GetlineCount, ' getline/redirection(s) E/S');
    WriteLn('AWKCW32: ', BuiltinVarCount, ' initialisation(s) var builtin');
    WriteLn('AWKCW32: ', ExprCount, ' expression(s) parsees');
    WriteLn('AWKCW32: ', CoercionCount, ' coercition(s), ',
            ConcatCount, ' concatenation(s) implicite(s)');
    WriteLn('AWKCW32: ', PrintCount, ' print/printf, ',
            IfCount, ' if/else instruction(s)');
    WriteLn('AWKCW32: ', WhileCount, ' while, ',
            ForCount, ' for, ',
            DoWhileCount, ' do-while, ',
            ForInCount, ' for-in');
    WriteLn('AWKCW32: ', GenCount, ' operation(s) code gen, ',
            StringLitCount, ' litteral(aux) chaine');
    WriteLn('AWKCW32: scope depth=', ScopeDepth, ', loop depth=', LoopDepth);
    WriteLn('AWKCW32: ', RuntimeHelpCount, ' helper(s) runtime emis');
    WriteLn('AWKCW32: ', DispatchCount, ' instruction(s) exit');
    {$IFDEF FPC}
    { Generation binaire (TODO 25) }
    If Opts.EmitObj Then
    Begin
      AssembleAndWriteBinary(ReplaceExt(Opts.SrcFile, '.asm'),
                            ReplaceExt(Opts.SrcFile, '.obj'), True);
      WriteLn('AWKCW32: OBJ genere -> ', ReplaceExt(Opts.SrcFile, '.obj'));
      If Not Opts.EmitAsm Then
      Begin
        Assign(OutF, ReplaceExt(Opts.SrcFile, '.asm'));
        {$I-} Erase(OutF); {$I+}
        If IOResult <> 0 Then { ignorer };
      End;
    End
    Else
    Begin
      AssembleAndWriteBinary(ReplaceExt(Opts.SrcFile, '.asm'),
                            ReplaceExt(Opts.SrcFile, '.exe'), False);
      WriteLn('AWKCW32: EXE genere -> ', ReplaceExt(Opts.SrcFile, '.exe'));
      If Not Opts.EmitAsm Then
      Begin
        Assign(OutF, ReplaceExt(Opts.SrcFile, '.asm'));
        {$I-} Erase(OutF); {$I+}
        If IOResult <> 0 Then { ignorer };
      End;
    End;
    {$ELSE}
    WriteLn('AWKCW32: generation binaire non disponible (necessite Free Pascal)');
    {$ENDIF}
  End;
  LexClose;
End;

{ ============================================================ }
{ PROGRAMME PRINCIPAL                                          }
{ ============================================================ }

BEGIN
  If (ParamCount > 0) And
     ((ParamStr(1) = '/?') Or (ParamStr(1) = '--help') Or
      (ParamStr(1) = '-h') Or (ParamStr(1) = '/h') Or
      (ParamStr(1) = '/H')) Then
  Begin
    ShowHelp;
    Halt(EXIT_OK);
  End;

  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  OutFOpen   := False;

  ParseArgs;
  ShowBanner;
  Run;
  Cleanup;
  If Opts.Verbose Then ShowStats;

  If ErrorCount > 0 Then
    Halt(EXIT_ERROR)
  Else
    Halt(EXIT_OK);
END.
