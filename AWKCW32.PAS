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

  TODO 06 - PARSEUR : EXPRESSIONS ARITHMETIQUES ET LOGIQUES (32 BITS)
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
            Tous les calculs en registres 32 bits (EAX, EBX, ECX, EDX)

  TODO 07 - PARSEUR : CONCATENATION DE CHAINES ET COERCITION
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

  TODO 08 - GENERATION DE CODE : OPERATIONS ARITHMETIQUES 80386
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

  TODO 10 - PARSEUR : IF / ELSE
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

  TODO 11 - PARSEUR : WHILE, FOR, DO-WHILE, BREAK, CONTINUE
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
            Procedure ParseForIn
            Syntaxe : for (var in array) instruction | { instructions }
            Generation 32 bits :
              Initialiser iterateur sur le tableau associatif
              _AWL_top: CALL _AWRT_HASH_NEXT -> EAX (cle suivante)
              TEST EAX, EAX + JZ _AWL_end (plus de cles)
              Stocker cle dans var
              Corps + JMP _AWL_top + _AWL_end:
            Support break / continue dans for-in

  TODO 13 - PARSEUR : FONCTIONS UTILISATEUR (FUNCTION / RETURN)
            Procedure ParseFunctionDef
            Syntaxe :
              function nom(param1, param2, ...) { instructions }
            Convention d appel Win32 STDCALL :
              PUSH args droite a gauche (par valeur 32 bits)
              CALL _AWF_nom
              Prologue : PUSH EBP / MOV EBP, ESP / SUB ESP, locales
              Epilogue : MOV ESP, EBP / POP EBP / RET n
              Parametres a [EBP+8], [EBP+12], [EBP+16]...
              Variables locales a [EBP-4], [EBP-8]...
            Procedure ParseReturn
              return [expr] -> MOV EAX, val + JMP _AWL_exit
            Appel de fonction utilisateur :
              PUSH args + CALL _AWF_nom
              Resultat dans EAX
            Support de la recursion (pile d appels)
            Variables locales supplementaires declarees comme
              parametres extra (convention AWK) :
              function f(a, b,    c, d) -> c et d sont locales

  TODO 14 - PARSEUR : REGLES PATTERN-ACTION (BEGIN, END, /regex/, expr)
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

  TODO 15 - PARSEUR : CHAMPS $0..$NF ET SEPARATEURS FS, RS, OFS, ORS
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

  TODO 16 - PARSEUR : TABLEAUX ASSOCIATIFS ET OPERATEUR IN / DELETE
            Representation memoire :
              Chaque tableau = bloc de MAX_HASH_PAIRS paires (cle, val)
              Cle : pointeur vers chaine ASCIIZ
              Valeur : DWORD (nombre ou pointeur chaine)
            Procedure ParseArrayRef
              array[expr] -> CALL _AWRT_HASH_GET(array_ptr, cle) -> EAX
              array[expr] = val -> CALL _AWRT_HASH_SET(array_ptr, cle, val)
            Operateur in :
              (expr in array) -> CALL _AWRT_HASH_EXISTS -> 0/1
            Operateur delete :
              delete array[expr] -> CALL _AWRT_HASH_DEL
              delete array -> CALL _AWRT_HASH_CLEAR (vider tout)
            Indices multidimensionnels :
              array[i, j] -> concatener i SUBSEP j comme cle
            Routines runtime hash :
              _AWRT_HASH_GET, _AWRT_HASH_SET, _AWRT_HASH_EXISTS,
              _AWRT_HASH_DEL, _AWRT_HASH_CLEAR, _AWRT_HASH_NEXT
            Allocation dynamique des paires via HeapAlloc

  TODO 17 - PARSEUR : EXPRESSIONS REGULIERES ET MATCHING ~ / !~
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
            Fonctions utilisant des regex :
              sub(regex, repl, target)
              gsub(regex, repl, target)
              match(string, regex) -> met a jour RSTART, RLENGTH
              split(string, array, regex)
            Routines runtime regex :
              _AWRT_MATCH_RE : matcher une chaine contre un pattern
              _AWRT_REGEX_COMPILE : compiler un pattern (optionnel)

  TODO 18 - PARSEUR : FONCTIONS BUILTIN CHAINES
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

  TODO 19 - PARSEUR : FONCTIONS BUILTIN MATHEMATIQUES
            Procedure ParseBuiltinMath
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

  TODO 20 - PARSEUR : GETLINE ET REDIRECTIONS E/S
            Procedure ParseGetline
            Syntaxe :
              getline                  -> lire dans $0 depuis stdin
              getline var              -> lire dans var depuis stdin
              getline < "fichier"      -> lire depuis fichier
              getline var < "fichier"  -> lire var depuis fichier
              "cmd" | getline [var]    -> lire depuis pipe (stub)
            Generation 32 bits :
              CALL _AWRT_READLINE -> EAX (0=EOF, 1=succes)
              Mettre a jour NR, FNR, $0, NF
            Redirections de sortie (print/printf) :
              > "fichier"  -> CALL _AWRT_OPEN_WRITE + WriteFile
              >> "fichier" -> CALL _AWRT_OPEN_APPEND + WriteFile
              | "commande" -> stub
            Gestion des handles de fichier ouverts :
              Table de fichiers ouverts (nom -> handle Win32)
              CreateFileA / WriteFile / ReadFile / CloseHandle
            Procedure ParseInputFiles
              Traitement des fichiers passes en argument (ARGC/ARGV)
              Boucle : ouvrir chaque fichier, lire ligne par ligne

  TODO 21 - PARSEUR : VARIABLES BUILTIN AWK
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

  TODO 22 - GENERATION : EN-TETE ASSEMBLEUR 80386 ET SEGMENT .DATA
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
            ET HELPERS RUNTIME
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

  TODO 24 - PARSEUR : DISPATCHER ET BOUCLE PRINCIPALE
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

  TODO 25 - GENERATION FINALE : LINKER PE, FICHIERS .OBJ ET EXEMPLES
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

  { Table des symboles (TODO 04) }
  SymTab      : Array[0..MAX_SYM - 1] Of TSymEntry;
  SymCount    : Integer;      { nombre de symboles enregistres    }

  { Table des fonctions (TODO 04) }
  FuncTab     : Array[0..MAX_FUNC - 1] Of TFuncEntry;
  FuncCount   : Integer;      { nombre de fonctions enregistrees  }

  { Pile de scopes (TODO 05) }
  ScopeStack  : Array[0..MAX_SCOPE - 1] Of TScopeEntry;
  ScopeDepth  : Integer;      { profondeur courante               }
  LoopDepth   : Integer;      { profondeur des boucles imbriquees }
  LabelSeq    : Integer;      { sequence pour labels uniques      }

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
  LexNextToken(CurToken);
  If Opts.DebugMode Then
    PrintToken(CurToken);
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
  FuncCount := 0;
  { Declarer les 12 variables builtin AWK globales }
  AddSym('FS', TYK_STRING, STORE_GLOBAL, True);
  AddSym('RS', TYK_STRING, STORE_GLOBAL, True);
  AddSym('OFS', TYK_STRING, STORE_GLOBAL, True);
  AddSym('ORS', TYK_STRING, STORE_GLOBAL, True);
  AddSym('NR', TYK_NUMBER, STORE_GLOBAL, True);
  AddSym('NF', TYK_NUMBER, STORE_GLOBAL, True);
  AddSym('FNR', TYK_NUMBER, STORE_GLOBAL, True);
  AddSym('FILENAME', TYK_STRING, STORE_GLOBAL, True);
  AddSym('ARGC', TYK_NUMBER, STORE_GLOBAL, True);
  AddSym('RSTART', TYK_NUMBER, STORE_GLOBAL, True);
  AddSym('RLENGTH', TYK_NUMBER, STORE_GLOBAL, True);
  AddSym('SUBSEP', TYK_STRING, STORE_GLOBAL, True);
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
{ PROCEDURE RUN (STUB - sera complete par les TODOs suivants)  }
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
    { Parcourir les tokens pour compter (stub) }
    LexNextToken(CurToken);
    While CurToken.Kind <> TK_EOF Do
      LexNextToken(CurToken);
    WriteLn('AWKCW32: tokenisation terminee, ', TotalLines, ' lignes');
    WriteLn('AWKCW32: ', SymCount, ' symbole(s), ', FuncCount, ' fonction(s)');
    WriteLn('AWKCW32: scope depth=', ScopeDepth, ', loop depth=', LoopDepth);
    WriteLn('AWKCW32: TODO 06..25 non encore implementes.');
    WriteLn('AWKCW32: sortie prevue: ', Opts.OutFile);
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
