{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 0.1
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Ada 83/95 (sous-ensemble) vers assembleur 80386 pour Windows 32 bits
  @license: MIT
}

(* ============================================================
  ADACW32.PAS - Compilateur Ada 83/95 (sous-ensemble) vers
  assembleur 80386 pour Windows 32 bits
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .386 / .MODEL FLAT, PE Win32

  Par defaut produit un fichier .EXE (PE Windows 32 bits).
  Avec le parametre -obj, produit uniquement un fichier .OBJ (COFF).
  Avec le parametre -asm, produit egalement un fichier .ASM lisible.
  Supporte toutes les instructions de ADA86.PAS et les exemples
  SAMPLES\ADA\*

  Voir DOC/TODO/ADACW32.txt pour la feuille de route complete.

  TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES PE/COFF [IMPLEMENTE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings,
              EmitExe, EmitObj, EmitAsm)
            ParseArgs : analyser argv (source.adb [-o sortie] [-v]
              [-d] [-w] [-obj] [-asm] [-h])
            Par defaut : produire un .EXE Windows 32 bits (PE)
            -obj : produire uniquement un .OBJ (format COFF 32 bits)
            -asm : produire egalement un listing assembleur .ASM lisible
            -o nom : specifier le nom du fichier de sortie
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .adb ou .ads du fichier source
            Version, Date, aide en ligne (option -h)
            Constantes PE/COFF : PE_DOS_MAGIC ($5A4D), PE_PE_SIG,
              PE_MACHINE_I386, PE_OPT_SIZE, PE_MAGIC_32,
              PE_IMG_BASE ($00400000), PE_SEC_ALIGN (4096),
              PE_FILE_ALIGN (512), PE_SUBSYS_CUI (console)
            Constantes binaires : MAX_BIN_CODE (65536),
              MAX_BIN_DATA (65536), MAX_BIN_LBL (4096),
              MAX_BIN_FIX (8192)
            Limites internes (32 bits) : MAX_SYM=2048, MAX_SUB=256,
              MAX_TYPE=128, MAX_PKG=32, MAX_PARAM=32, MAX_DEPTH=16,
              MAX_LABEL=2048, MAX_STR=255, MAX_FIELD=64,
              MAX_ENUM=64
            Prefixes de nommage ASM : _ADA_ (variable globale),
              _ADAF_ (procedure/function), _ADAK_ (constante chaine),
              _ADART_ (routine runtime), _ADAL_ (label interne),
              _ADAA_ (tableau), _ADAR_ (record),
              _ADAP_ (package), _ADAX_ (exception handler)
            Utilitaires : ItoS, ItoSI, UpCaseStr, AsmIdent

  TODO 02 - LEXEUR (TOKENS ADA) [IMPLEMENTE]
            Procedure LexInit : ouvrir le fichier source, initialiser
              l etat du lexeur (ligne, colonne, caractere courant)
            Procedure LexClose : fermer le fichier source
            SrcGetChar : lecture caractere par caractere, gestion colonnes,
              detection commentaires Ada (-- jusqu en fin de ligne)
            SkipWhitespace : espaces, tabulations, fin de ligne
            LexIdent : identifiant ou mot-cle (insensible a la casse
              -> upper)
            LexNumber : entier decimal, base#valeur# (2#1010#, 16#FF#),
              flottant (1.5, 1.5E3, 1.5E-3)
            LexChar : 'c' -> TOK_CHAR ('' => apostrophe)
            LexString : "..." -> TOK_STRING ("" => guillemet)
            LexSymbol : :=  /=  >=  <=  =>  ..  et symboles simples
            NextToken : dispatcher principal -> CurTokType / CurTokStr /
              CurTokNum / CurTokKw
            Types de tokens (TOK_IDENT, TOK_INTEGER, TOK_FLOAT,
              TOK_CHAR, TOK_STRING, TOK_OP, TOK_LPAREN, TOK_RPAREN,
              TOK_COMMA, TOK_SEMI, TOK_COLON, TOK_COLONASSIGN,
              TOK_DOT, TOK_DOTDOT, TOK_BAR, TOK_LT, TOK_GT,
              TOK_LE, TOK_GE, TOK_EQ, TOK_NEQ, TOK_ARROW, TOK_EOF,
              TOK_UNKNOWN)
            Consume, TokIsKw, TokIsOp, Expect, ExpectKw : helpers

  TODO 03 - MOTS-CLES ADA ET GESTION DES ERREURS [IMPLEMENTE]
            Function IsKeyword(Const s: String): Integer
            Mots-cles Ada complets a reconnaitre (KW_xxx) :
              PROCEDURE, FUNCTION, PACKAGE, BEGIN, END, IS, WITH,
              USE, TYPE, SUBTYPE, CONSTANT, ARRAY, RECORD, OF,
              RANGE, IF, THEN, ELSIF, ELSE, CASE, WHEN, OTHERS,
              LOOP, EXIT, WHILE, FOR, IN, REVERSE, RETURN, NULL,
              RAISE, EXCEPTION, PRAGMA, RENAMES, SEPARATE, ABSTRACT,
              PRIVATE, BODY, AND, OR, NOT, XOR, MOD, REM, NEW,
              ALL, ACCESS, OUT, DECLARE, DO, GOTO, ABS, DELTA,
              DIGITS, AT, ACCEPT, TASK, PROTECTED, GENERIC, LIMITED,
              TAGGED, SELECT, TERMINATE, DELAY, UNTIL, REQUEUE,
              ENTRY, INTERFACE, OVERRIDING, SYNCHRONIZED, SOME,
              TRUE, FALSE, AND THEN, OR ELSE, IN OUT
            Constantes KW_PROCEDURE..KW_INOUT (76 mots-cles)
            Error(msg) : incrementer error_count, afficher ligne + message
            Warning(msg) : avertissement non bloquant
            SkipToSemi : consommer jusqu a ';' pour resynchroniser
            SkipToEnd : consommer jusqu a END correspondant
            FatalError(msg) : afficher + Halt(1)
            BilanCompilation : afficher stats (symboles, types, erreurs)

  TODO 04 - TABLE DES SYMBOLES (32 BITS) [IMPLEMENTE]
            Type TSymEntry : Name (String[48]), AsmLabel (String[48]),
              TypeIdx (Integer), StoreClass (Integer),
              BpOffset (Integer), ArraySize (Integer),
              CharLen (Integer), IsConst (Boolean),
              ScopeLev (Integer), InitNum (LongInt),
              InitStr (String[64]), HasInit (Boolean)
            SymTab[0..MAX_SYM-1] / SymCount
            Procedure InitSymTable / Function FindSym / Function AddSym
            Function FindSymLocal : dans le scope courant uniquement
            AddSym : calcul automatique BpOffset pour STORE_AUTO
            Tailles 32 bits : Integer = DD (4 octets),
              Float = DQ (8 octets stub), Boolean = DB (1 octet),
              Character = DB (1 octet), String = DB n
            Classes d entreposage : STORE_AUTO (pile EBP),
              STORE_STATIC (segment .DATA), STORE_CONST (immediate),
              STORE_PARAM (EBP+n)
            Modes parametres : PARAM_IN, PARAM_OUT, PARAM_INOUT
            GetSymSize(sym_idx) : retourne la taille en octets

  TODO 05 - TABLES DES TYPES ET SOUS-PROGRAMMES (32 BITS) [IMPLEMENTE]
            Type TSubEntry : Name (String[48]), AsmLabel (String[48]),
              RetType (Integer), ParamCount (Integer),
              ParamNames[1..MAX_PARAM] of String[48],
              ParamTypes[1..MAX_PARAM] of Integer,
              ParamModes[1..MAX_PARAM] of Integer,
              IsForward (Boolean), IsFunction (Boolean),
              FrameSize (Integer)
            Type TTypeEntry : Name (String[48]), Kind (Integer),
              BaseType (Integer), LoBound (LongInt), HiBound (LongInt),
              FieldCount (Integer),
              FieldNames[1..MAX_FIELD] of String[48],
              FieldTypes[1..MAX_FIELD] of Integer,
              FieldOffs[1..MAX_FIELD] of Integer,
              ElemType (Integer), ElemSize (Integer),
              EnumCount (Integer),
              EnumNames[1..MAX_ENUM] of String[48],
              TotalSize (Integer)
            Type TPkgEntry : Name (String[48]), IsStandard (Boolean),
              UseActive (Boolean)
            SubTab[0..MAX_SUB-1] / SubCount
            TypeTab[0..MAX_TYPE-1] / TypeCount
            PkgTab[0..MAX_PKG-1] / PkgCount
            InitTypeTable, AddType, FindType
            InitSubTable, AddSub, FindSub
            InitPkgTable, AddPkg, FindPkg
            Types predefinis : INTEGER (DD 4), FLOAT (DQ 8),
              BOOLEAN (DB 1), CHARACTER (DB 1), STRING (DB n)
            Categorie de types : TK_PREDEF, TK_ENUM, TK_RANGE,
              TK_ARRAY, TK_RECORD, TK_ACCESS, TK_DERIVED
            GetTypeSize(type_idx) : taille en octets selon le type

  TODO 06 - GESTION DES SCOPES ET PILE DE SCOPES [IMPLEMENTE]
            Type TScopeEntry : Kind (Integer), SubIdx (Integer),
              BpTop (Integer), SymStart (Integer),
              LblExit (String[16]), LblCont (String[16]),
              LblEnd (String[16]),
              HasExcept (Boolean), LblExcept (String[16])
            Pile de scopes : chaque scope maintient ses propres
              variables locales, offset EBP courant, labels sortie
            Scopes supportes : SK_GLOBAL, SK_PROC, SK_FUNC,
              SK_BLOCK, SK_LOOP, SK_EXCEPT, SK_PACKAGE
            PushScope(kind, sub_idx) : empiler + initialiser champs
            PopScope : depiler, liberer les symboles locaux
            CurrentScope, CurrentSub : accesseurs
            AllocLocal(size) : incrementer bp_top, retourner bp_offset
            EnterLoop(lbl_cont, lbl_end) : enregistrer labels de boucle
            Offset EBP negatif pour locales [EBP-n]
            Offset EBP positif pour parametres [EBP+8], [EBP+12]...
            Convention STDCALL Win32 : parametres droite a gauche

  TODO 07 - GENERATEUR DE CODE BAS NIVEAU 80386 [IMPLEMENTE]
            Emit(s), EmitI(s), EmitLabel(lbl), EmitComment(s), EmitBlank
            NewLabel : generer _ADAL_xxxx (compteur label_counter)
            AsmStrLit(s) : ajouter litteral chaine dans str_table +
              retourner label _ADAK_1, _ADAK_2 ...
            GenLoadVar(sym_idx) : charger variable dans EAX
              STORE_STATIC -> MOV EAX, DWORD PTR [_ADA_x]
              STORE_AUTO   -> MOV EAX, DWORD PTR [EBP-n]
              STORE_PARAM  -> MOV EAX, DWORD PTR [EBP+n]
              TYPE Character/Boolean -> MOVZX EAX, BYTE PTR [...]
            GenStoreVar(sym_idx) : stocker EAX dans variable
              MOV DWORD PTR [...], EAX ou MOV BYTE PTR [...], AL
            GenLoadConst(val) : MOV EAX, val
            GenPrologue(frame_size) :
              PUSH EBP / MOV EBP, ESP / SUB ESP, n
            GenEpilogue(frame_size, param_bytes) :
              MOV ESP, EBP / POP EBP / RET n (callee-cleanup STDCALL)
            GenPushEAX, GenPopEAX, GenPushEBX, GenPopEBX
            GenCall(label) : CALL label

  TODO 08 - PARSEUR D'EXPRESSIONS : PRECEDENCES ADA (32 BITS) [IMPLEMENTE]
            Expression Ada (priorites croissantes) :
              Niveau 1 : and then | or else      (court-circuit)
              Niveau 2 : and | or | xor           (logique bit)
              Niveau 3 : not                      (unaire logique)
              Niveau 4 : = /= < <= > >=          (relationnels)
              Niveau 5 : .. (plage)
              Niveau 6 : + - &                    (additive + concat)
              Niveau 7 : unaire + -
              Niveau 8 : * / mod rem              (multiplicative)
              Niveau 9 : ** abs                   (puissance/abs)
              Niveau 10 : primaire (lit, ident, appel, (expr))
            ParseExpr -> ParseOrElse -> ParseAndThen -> ParseOr
              -> ParseAnd -> ParseNot -> ParseRelation -> ParseSimple
              -> ParseTerm -> ParseFactor -> ParsePrimary
            ParsePrimary : litteraux entiers/flottants/char/string,
              identifiants, appels de fonction, (expr), TRUE/FALSE
            Calculs en registres 32 bits (EAX, EBX, ECX, EDX) :
              GenBinOp : ADD/SUB/IMUL EAX,EBX / CDQ+IDIV EBX
              GenRelOp : CMP EAX,EBX + SETcc AL + MOVZX EAX,AL
              GenModOp : CDQ + IDIV EBX -> MOV EAX, EDX (reste)

  TODO 09 - PARSEUR : WITH ET USE [IMPLEMENTE]
            ParseWithUse : traiter WITH/USE en debut de programme
            WITH pkg1, pkg2, ... ;  -> enregistrer dans PkgTab
            USE pkg1, pkg2, ... ;   -> activer acces direct (UseActive)
            Packages standard reconnus :
              Ada.Text_IO, Ada.Integer_Text_IO, Ada.Float_Text_IO,
              Ada.Numerics, System
            Pour tout autre package : avertissement "package non
              implemente"
            Marquer les packages importes IsStandard := True

  TODO 10 - PARSEUR : DECLARATIONS DE TYPES UTILISATEUR [IMPLEMENTE]
            ParseTypeDecl :
              TYPE nom IS definition ;
            ParseSubtypeDecl :
              SUBTYPE nom IS base [RANGE lo .. hi] ;
            Definitions supportees :
              (enum1, enum2, ...)         -> type enumere
              RANGE lo .. hi              -> sous-type entier
              ARRAY (lo .. hi) OF type   -> tableau 1D borne fixe
              ARRAY (type RANGE <>) OF type -> non-contraint (stub)
              RECORD champ : type; ... END RECORD -> enregistrement
              NEW type                    -> derivation simple (alias)
              ACCESS type                 -> pointeur (32 bits)
            GenTypeData : pour tableaux/records -> espace .DATA ou pile
            Tailles 32 bits : tableaux = (hi-lo+1) * elem_size,
              records = somme des champs (alignes sur 4 octets)

  TODO 11 - PARSEUR : DECLARATIONS D'OBJETS (VARIABLES ET CONSTANTES)
            [IMPLEMENTE]
            ParseObjectDecl :
              nom [, nom2 ...] : [CONSTANT] type [:= expr] ;
            Detecter CONSTANT -> IsConst := True, STORE_CONST
            Variables globales (scope_lev = 0) -> STORE_STATIC, .DATA
              TYPE Integer : _ADA_nom DD 0
              TYPE Float   : _ADA_nom DQ 0
              TYPE Boolean : _ADA_nom DB 0
              TYPE Character : _ADA_nom DB 0
            Variables locales (scope_lev > 0) -> STORE_AUTO, pile EBP
            Evaluer l expression d initialisation si presente
            Pour tableaux : emettre DD/DB DUP(?) ou bloc d init
            Pour records : emettre champ par champ

  TODO 12 - PARSEUR : SIGNATURES PROCEDURE ET FUNCTION [IMPLEMENTE]
            ParseParamList(SubIdx) :
              ( nom [, nom2] : [IN | IN OUT | OUT] type [:= default] ;
                nom3 : type ; ... )
            ParseProcedureDecl :
              PROCEDURE nom [(params)] ;      => spec forward
              PROCEDURE nom [(params)] IS ... => body (skip pour TODO 13)
            ParseFunctionDecl :
              FUNCTION nom [(params)] RETURN type ;      => spec forward
              FUNCTION nom [(params)] RETURN type IS ... => body (skip)
            SkipProcBody : sauter un corps jusqu au END [nom] ;
            AddSub(nom, ...) avec IsForward := True pour les specs
            Enregistrer ParamNames, ParamTypes, ParamModes
            IN : passage par valeur (PUSH 32 bits)
            OUT / IN OUT : passage par adresse (LEA + PUSH)
            Convention STDCALL : parametres droite a gauche
            Boucle PROCEDURE/FUNCTION dans Run

  TODO 13 - PARSEUR : CORPS PROCEDURE ET FUNCTION (32 BITS) [IMPLEMENTE]
            ParseProcedureBody :
              PROCEDURE nom [(params)] IS
                declarative_part
              BEGIN
                statements
              [EXCEPTION
                exception_handlers]
              END [nom] ;
            ParseFunctionBody :
              FUNCTION nom [(params)] RETURN type IS
                declarative_part
              BEGIN
                statements
              [EXCEPTION
                exception_handlers]
              END [nom] ;
            PushScope(SK_PROC / SK_FUNC)
            ParseDeclarativePart : types, constantes, variables,
              sous-programmes imbriques
            GenPrologue : PUSH EBP / MOV EBP, ESP / SUB ESP, frame
            ParseSequenceOfStatements
            GenEpilogue : MOV ESP, EBP / POP EBP / RET n
            PopScope
            Resultat FUNCTION dans EAX (ou EDX:EAX pour 64 bits)

  TODO 14 - PARSEUR : PACKAGE SPEC ET BODY [IMPLEMENTE]
            ParsePackageSpec :
              PACKAGE nom IS
                [PRIVATE]
                declarations publiques
              END [nom] ;
            ParsePackageBody :
              PACKAGE BODY nom IS
                declarations privees
                [BEGIN init_statements END [nom] ;]
              END [nom] ;
            ParsePackageDecl : dispatcher spec vs body
            PackageSpec : enregistrer exports dans SubTab / TypeTab
            PackageBody : generer les corps des sous-programmes
            Init body : generer _ADAP_nom_INIT appelee au demarrage
            Packages Ada.Text_IO : generer stubs Put/Put_Line/Get/
              Get_Line en appelant les helpers runtime Win32
            Boucle PACKAGE dans Run

  TODO 15 - PARSEUR : DISPATCHER PRINCIPAL DES INSTRUCTIONS [IMPLEMENTE]
            Procedure ParseStatement
            Dispatcher selon le token courant :
              Identifiant + ':=' -> ParseAssignment (stub skip -> TODO 16)
              Identifiant + '(' ou sans -> ParseProcedureCall (stub skip -> TODO 16)
              IF           -> ParseIf (stub skip -> TODO 17)
              CASE         -> ParseCase (stub skip -> TODO 17)
              LOOP         -> ParseLoop (stub skip -> TODO 18)
              WHILE        -> ParseWhile (stub skip -> TODO 18)
              FOR          -> ParseFor (stub skip -> TODO 18)
              RETURN       -> ParseReturn (skip expr + ;)
              RAISE        -> ParseRaise (skip ident + ;)
              NULL         -> ParseNull (NULL + ;)
              EXIT         -> ParseExit (skip WHEN + ;)
              BEGIN        -> ParseBeginBlock (stmts + END ;)
              PRAGMA       -> ParsePragma (skip to ;)
              GOTO         -> ParseGoto (ident + ;)
              DECLARE      -> ParseDeclareBlock (decls + BEGIN stmts END ;)
            ParseSequenceOfStatements : boucle Until END/EXCEPTION/EOF
            Resynchronisation sur erreur : SkipToSemi
            Gestion du point-virgule terminateur

  TODO 16 - PARSEUR : AFFECTATION ET APPELS DE PROCEDURE [IMPLEMENTE]
            ParseAssignment :
              ident [.field | (index)] := expr ;
              GenLoadAddr(lhs) pour obtenir adresse destination
              ParseExpr pour RHS
              GenStoreAddr -> MOV [...], EAX
            ParseProcedureCall :
              nom [(arg1, arg2, ...)] ;
              FindSub -> verifier arguments vs parametres
              Pousser arguments 32 bits (IN par valeur PUSH EAX,
                OUT/IN OUT par adresse LEA EAX,[var] + PUSH EAX)
              CALL _ADAF_nom
              Convention STDCALL : callee-cleanup (RET n)
            ParseNomQualified : ident.ident (pkg.proc, rec.field)

  TODO 17 - PARSEUR : IF/ELSIF/ELSE ET CASE/WHEN/OTHERS (32 BITS) [IMPLEMENTE]
            ParseIf :
              IF cond THEN stmts
              [ELSIF cond THEN stmts] ...
              [ELSE stmts]
              END IF ;
              Evaluer condition -> EAX
              TEST EAX, EAX + JZ _ADAL_elsif ou _ADAL_else
              Chaine ELSIF avec labels de saut
              JMP _ADAL_endif apres chaque branche
            ParseCase :
              CASE expr IS
                WHEN valeur [| valeur2] => stmts
                [WHEN OTHERS => stmts]
              END CASE ;
              Charger expression -> EDX
              CMP EDX, imm32 / JNE _ADAL_next pour chaque WHEN
              WHEN val1 | val2 : serie CMP + JE _ADAL_match
              WHEN OTHERS = clause par defaut

  TODO 18 - PARSEUR : BOUCLES LOOP/WHILE/FOR ET EXIT (32 BITS) [IMPLEMENTE]
            ParseLoop :
              LOOP stmts END LOOP ;    (boucle infinie)
              _ADAL_top: corps + JMP _ADAL_top
            ParseWhile :
              WHILE cond LOOP stmts END LOOP ;
              _ADAL_top: evaluer cond -> TEST EAX,EAX + JZ _ADAL_end
            ParseFor :
              FOR ident IN [REVERSE] lo .. hi LOOP stmts END LOOP ;
              Variable de boucle implicite (STORE_AUTO, lecture seule)
              REVERSE : decrementer de hi vers lo
              Compteur en [EBP-n], CMP + JG/JL _ADAL_end
            ParseExit :
              EXIT [WHEN cond] ;
              JMP _ADAL_end (ou conditionnel TEST+JZ)
              Respecter les boucles imbriquees (scope_stack)
            ParseReturn :
              RETURN [expr] ;
              FUNCTION : stocker resultat dans EAX
              JMP _ADAL_exit

  TODO 19 - PARSEUR : EXCEPTIONS RAISE ET HANDLERS [IMPLEMENTE]
            Declarations : nom : EXCEPTION ;
            ParseRaise :
              RAISE [nom] ;
              MOV DWORD PTR [_ADART_CUREXC], id
              JMP _ADAX_handler (ou sortie programme)
            ParseExceptionHandler :
              BEGIN ... EXCEPTION
                WHEN nom => stmts
                WHEN OTHERS => stmts
              END ;
              Generer _ADAL_try, _ADAX_handler
              Mecanisme simple par table de sauts + CMP/JE
            Exceptions standard : CONSTRAINT_ERROR, PROGRAM_ERROR,
              STORAGE_ERROR, TASKING_ERROR (constantes predefinies)
            RegisterStandardExceptions : ajoute les 4 exceptions
              standard comme STORE_CONST dans InitSymTable
            NewExLabel : generer un label _ADAX_NNNN

  TODO 20 - PARSEUR : OPERATIONS SUR TABLEAUX (32 BITS) [IMPLEMENTE]
            Acces indexe : ident(index) (Ada utilise () pas [])
            Calcul d adresse 32 bits :
              base + (index - lo_bound) * elem_size
              LEA EAX, [_ADAA_x] / MOV EBX, index
              SUB EBX, lo / IMUL EBX, elem_size / acces [EAX+EBX]
            GenLoadElement : charger element dans EAX
            GenStoreElement : stocker EAX dans element
            Attributs tableau :
              T'FIRST  -> constante lo_bound
              T'LAST   -> constante hi_bound
              T'LENGTH -> hi_bound - lo_bound + 1
            Slices : T(a..b) -> stub (avertissement)

  TODO 21 - PARSEUR : OPERATIONS SUR RECORDS (32 BITS) [IMPLEMENTE]
            Acces champ : var.champ -> adresse base + offset_champ
            Calcul offset par sommation des tailles anterieures
              (alignement 4 octets)
            FindFieldIdx(TypeIdx, FieldName) : index du champ (1-base)
            GenLoadField(sym_idx, field_idx) :
              LEA EAX, [base] / MOV EAX, [EAX+offset]
            GenStoreField(sym_idx, field_idx) :
              LEA EBX, [base] / MOV [EBX+offset], EAX
            GenLoadFieldNested(sym_idx, base_off, fti) :
              LEA EAX, [base+base_off] / MOV EAX, [EAX+foff]
            GenStoreFieldNested(sym_idx, base_off, fti) :
              LEA EBX, [base+base_off] / MOV [EBX+foff], EAX
            Affectation agregat : (champ => val, ...) -> sequence init
            Records imbrique : var.champ.sous_champ (recursif)
            Attribut record : T'SIZE -> somme des tailles

  TODO 22 - STUBS ADA.TEXT_IO : SORTIE CONSOLE WIN32 [IMPLEMENTE]
            Generer des stubs helpers Win32 pour les appels Text_IO :
            Put(item) : afficher entier, flottant, char ou chaine
              TYPE Integer -> CALL _ADART_PRINTINT
              TYPE String  -> PUSH OFFSET str + CALL _ADART_PRINT
              TYPE Character -> CALL _ADART_PRINTCHR
            Put_Line(item) : Put + CALL _ADART_CRLF
            Get(var) : lire entier ou char depuis stdin (ReadFile)
            Get_Line(str, last) : lire chaine + retourner longueur
            New_Line [(n)] : emettre n CR+LF (defaut 1)
            Set_Col(n) : stub (avertissement "non implemente")
            Initialiser _ADART_HSTDOUT via GetStdHandle(-11)
            Initialiser _ADART_HSTDIN via GetStdHandle(-10)

  TODO 23 - GENERATION : EN-TETE ASSEMBLEUR 80386 ET SEGMENT .DATA [IMPLEMENTE]
            Procedure EmitOpen : ouvrir fichier .ASM, GenEnabled := True
            Procedure EmitClose : fermer fichier .ASM, GenEnabled := False
            Procedure EmitHeader :
              '; Generated by ADACW32 V0.1'
              '.386'
              '.MODEL FLAT, STDCALL'
              'OPTION CASEMAP:NONE'
              Declarations EXTRN pour API Win32 :
                ExitProcess, GetStdHandle, WriteFile, ReadFile,
                GetProcessHeap, HeapAlloc, HeapFree
              '.STACK 4096'
              '_TEXT SEGMENT DWORD PUBLIC ''CODE'''
              'ASSUME CS:_TEXT'
            Procedure EmitDataSeg :
              Variables globales Integer : _ADA_nom DD 0
              Variables globales Float   : _ADA_nom DQ 0
              Variables globales Boolean : _ADA_nom DB 0
              Variables globales Char    : _ADA_nom DB 0
              Tableaux : _ADAA_nom DD n DUP(0)
              Records  : _ADAR_nom DB total_size DUP(0)
              Chaines litterales : _ADAK_1, _ADAK_2... DB 'texte',0
              Tampons runtime : _ADART_NUMBUF, _ADART_STRBUF,
                _ADART_INPUTBUF, _ADART_CRLF_DATA, _ADART_HSTDOUT,
                _ADART_HSTDIN
            Mode -asm : ecrire fichier .ASM avec commentaires
            Run mis a jour : EmitOpen + EmitHeader avant parsing,
              EmitDataSeg + EmitClose apres parsing

  TODO 24 - GENERATION : POINT D'ENTREE WIN32 ET HELPERS RUNTIME [IMPLEMENTE]
            Procedure EmitEntryPoint :
              _ADAF_main:
              PUSH EBP / MOV EBP, ESP
              Initialiser stdout : PUSH -11 / CALL GetStdHandle
                MOV [_ADART_HSTDOUT], EAX
              Initialiser stdin : PUSH -10 / CALL GetStdHandle
                MOV [_ADART_HSTDIN], EAX
              Eventuels CALL _ADAP_xxx_INIT pour packages avec BEGIN
              CALL _ADAF_nom_procedure (procedure principale Ada)
              PUSH 0 / CALL ExitProcess
            Procedure EmitRuntimeHelpers :
              _ADART_CRLF     : ecrire CR+LF via WriteFile
              _ADART_PRINT    : EAX=ptr ASCIIZ -> WriteFile(hStdOut)
              _ADART_NUMTOSTR : EAX=entier -> ASCIIZ dans _ADART_NUMBUF
              _ADART_PRINTINT : EAX=entier -> NUMTOSTR + PRINT
              _ADART_PRINTCHR : AL=caractere -> WriteFile 1 octet
              _ADART_READINT  : ReadFile + parsing ASCII -> EAX
              _ADART_READSTR  : ReadFile -> copier dans buffer
              _ADART_STRLEN   : EAX=ptr ASCIIZ -> EAX=longueur
              _ADART_STRCOPY  : ESI=src, EDI=dst, ECX=max -> copie
              _ADART_STRCONCAT: coller ESI apres EDI (ASCIIZ)
              _ADART_CHKRANGE : verifier borne, sinon Constraint_Error
              _ADART_ERROR    : afficher message + ExitProcess(1)
            Procedure Compile :
              1. Valider ParamStr(1) = source .ADB ou .ADS
              2. Ouvrir source, creer fichier temporaire (.$$T)
              3. InitAll (New() pour toutes les tables sur le tas)
              4. Enregistrer types predefinis (TODO 05)
              5. NextToken ; parseur principal :
                   ParseWithUse* -> ParseDeclarativePart ->
                   ParseProcedureBody (programme Ada = procedure
                   de library unit avec Begin..End)
              6. Close fichier temporaire
              7. Ouvrir fichier sortie final
              8. EmitHeader ; EmitDataSeg ; EmitEntryPoint
              9. AppendFileToOutput(tmp) [corps des proc/func]
             10. EmitRuntimeHelpers ; EmitClose
             11. Close, Erase(tmp)
             12. Dispose() toutes les tables, BilanCompilation

  TODO 25 - GENERATION FINALE : LINKER PE, FICHIERS .OBJ ET EXEMPLES [IMPLEMENTE]
            Procedure EmitClose : finaliser l emission ASM
              EmitRuntimeHelpers + '_TEXT ENDS' + EmitDataSeg +
              'END _ADAF_main'
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
                HeapAlloc, HeapFree)
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
            Exemples de test : SAMPLES\ADA\*.ADB
              HELLO.ADB, T01_HELLO.ADB, T02_LOOPS.ADB,
              T03_VARS.ADB, T04_TYPES.ADB, T05_FUNC.ADB,
              T06_COND.ADB, TEST.ADB
            Rapport de compilation : 0 erreurs, N symboles, M types
*)

Program ADACW32;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================ }
{ CONSTANTES                                                   }
{ ============================================================ }

Const
  ADACW32_VERSION = '0.1';
  ADACW32_DATE    = '2026';

  { Limites internes }
  MAX_SYM       = {$IFDEF FPC}2048{$ELSE}256{$ENDIF};
  MAX_SUB       = {$IFDEF FPC}256{$ELSE}32{$ENDIF};
  MAX_TYPE      = {$IFDEF FPC}128{$ELSE}32{$ENDIF};
  MAX_PKG       = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_LABEL     = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_PARAM     = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_DEPTH     = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_ERRORS    = {$IFDEF FPC}30{$ELSE}3{$ENDIF};
  MAX_STR       = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  MAX_FIELD     = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_ENUM      = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_DATA      = {$IFDEF FPC}512{$ELSE}64{$ENDIF};
  STACK_SIZE    = 4096;  { taille pile Win32 }

  { Types de tokens Ada }
  TOK_UNKNOWN     =  0;
  TOK_IDENT       =  1;   { identificateur ou mot-cle (upper)       }
  TOK_INTEGER     =  2;   { litteral entier : 123, 16#FF#           }
  TOK_FLOAT       =  3;   { litteral flottant : 1.5, 1.5E3          }
  TOK_CHAR        =  4;   { litteral caractere : 'A'                }
  TOK_STRING      =  5;   { litteral chaine : "texte"               }
  TOK_OP          =  6;   { operateur (reserve)                      }
  TOK_LPAREN      =  7;   { (                                        }
  TOK_RPAREN      =  8;   { )                                        }
  TOK_COMMA       =  9;   { ,                                        }
  TOK_SEMI        = 10;   { ;                                        }
  TOK_COLON       = 11;   { :                                        }
  TOK_COLONASSIGN = 12;   { :=                                       }
  TOK_DOT         = 13;   { .                                        }
  TOK_DOTDOT      = 14;   { ..                                       }
  TOK_BAR         = 15;   { |                                        }
  TOK_LT          = 16;   { <                                        }
  TOK_GT          = 17;   { >                                        }
  TOK_LE          = 18;   { <=                                       }
  TOK_GE          = 19;   { >=                                       }
  TOK_EQ          = 20;   { =                                        }
  TOK_NEQ         = 21;   { /=                                       }
  TOK_ARROW       = 22;   { =>                                       }
  TOK_PLUS        = 23;   { +                                        }
  TOK_MINUS       = 24;   { -                                        }
  TOK_STAR        = 25;   { *                                        }
  TOK_SLASH       = 26;   { /                                        }
  TOK_POWER       = 27;   { **                                       }
  TOK_AMPERSAND   = 28;   { &  (concatenation)                       }
  TOK_TICK        = 29;   { '  (attribut : T'FIRST)                  }
  TOK_EOF         = 99;

  MAX_IDENT    = 48;   { longueur max d un identificateur Ada       }

  { Codes des mots-cles Ada (KW_xxx) }
  KW_NONE         =  0;
  KW_PROCEDURE    =  1;
  KW_FUNCTION     =  2;
  KW_PACKAGE      =  3;
  KW_BEGIN        =  4;
  KW_END          =  5;
  KW_IS           =  6;
  KW_WITH         =  7;
  KW_USE          =  8;
  KW_TYPE         =  9;
  KW_SUBTYPE      = 10;
  KW_CONSTANT     = 11;
  KW_ARRAY        = 12;
  KW_RECORD       = 13;
  KW_OF           = 14;
  KW_RANGE        = 15;
  KW_IF           = 16;
  KW_THEN         = 17;
  KW_ELSIF        = 18;
  KW_ELSE         = 19;
  KW_CASE         = 20;
  KW_WHEN         = 21;
  KW_OTHERS       = 22;
  KW_LOOP         = 23;
  KW_EXIT         = 24;
  KW_WHILE        = 25;
  KW_FOR          = 26;
  KW_IN           = 27;
  KW_REVERSE      = 28;
  KW_RETURN       = 29;
  KW_NULL         = 30;
  KW_RAISE        = 31;
  KW_EXCEPTION    = 32;
  KW_PRAGMA       = 33;
  KW_RENAMES      = 34;
  KW_SEPARATE     = 35;
  KW_ABSTRACT     = 36;
  KW_PRIVATE      = 37;
  KW_BODY         = 38;
  KW_AND          = 39;
  KW_OR           = 40;
  KW_NOT          = 41;
  KW_XOR          = 42;
  KW_MOD          = 43;
  KW_REM          = 44;
  KW_NEW          = 45;
  KW_ALL          = 46;
  KW_ACCESS       = 47;
  KW_OUT          = 48;
  KW_DECLARE      = 49;
  KW_DO           = 50;
  KW_GOTO         = 51;
  KW_ABS          = 52;
  KW_DELTA        = 53;
  KW_DIGITS       = 54;
  KW_AT           = 55;
  KW_ACCEPT       = 56;
  KW_TASK         = 57;
  KW_PROTECTED    = 58;
  KW_GENERIC      = 59;
  KW_LIMITED      = 60;
  KW_TAGGED       = 61;
  KW_SELECT       = 62;
  KW_TERMINATE    = 63;
  KW_DELAY        = 64;
  KW_UNTIL        = 65;
  KW_REQUEUE      = 66;
  KW_ENTRY        = 67;
  KW_INTERFACE    = 68;
  KW_OVERRIDING   = 69;
  KW_SYNCHRONIZED = 70;
  KW_SOME         = 71;
  KW_TRUE         = 72;
  KW_FALSE        = 73;
  KW_ANDTHEN      = 74;   { AND THEN (compose)                       }
  KW_ORELSE       = 75;   { OR ELSE  (compose)                       }
  KW_INOUT        = 76;   { IN OUT   (compose)                       }

  { Types Ada internes }
  TYPE_UNKNOWN  =  0;
  TYPE_INT      =  1;   { Integer     : DD (4 octets)              }
  TYPE_FLOAT    =  2;   { Float       : DQ (8 octets, stub)        }
  TYPE_BOOL     =  3;   { Boolean     : DB (1 octet)               }
  TYPE_CHAR     =  4;   { Character   : DB (1 octet)               }
  TYPE_STR      =  5;   { String      : DB n octets                }
  TYPE_ENUM     =  6;   { Type enumere                             }
  TYPE_RANGE    =  7;   { Sous-type entier (RANGE lo..hi)          }
  TYPE_ARRAY    =  8;   { Tableau 1D borne fixe                    }
  TYPE_RECORD   =  9;   { Enregistrement (RECORD)                  }
  TYPE_ACCESS   = 10;   { Pointeur (ACCESS) : DD (4 octets)        }
  TYPE_DERIVED  = 11;   { Derivation simple (NEW type)             }
  TYPE_VOID     = 12;   { Pas de type de retour (procedure)        }

  { Categories de types }
  TK_PREDEF   = 0;   { type predefini (Integer, Float, etc.)    }
  TK_ENUM     = 1;   { enumeration                               }
  TK_RANGE    = 2;   { sous-type plage                           }
  TK_ARRAY    = 3;   { tableau                                   }
  TK_RECORD   = 4;   { enregistrement                            }
  TK_ACCESS   = 5;   { pointeur                                  }
  TK_DERIVED  = 6;   { derivation                                }

  { Classes d entreposage }
  STORE_AUTO     = 0;   { variable locale (pile EBP)               }
  STORE_STATIC   = 1;   { variable globale (segment .DATA)         }
  STORE_CONST    = 2;   { constante (valeur immediate)             }
  STORE_PARAM    = 3;   { parametre (EBP+n)                        }

  { Modes de parametre }
  PARAM_IN     = 0;   { passage par valeur                        }
  PARAM_OUT    = 1;   { passage par adresse (ecriture seule)      }
  PARAM_INOUT  = 2;   { passage par adresse (lecture/ecriture)    }

  { Types de scope }
  SK_GLOBAL   = 0;   { scope global (programme)                  }
  SK_PROC     = 1;   { procedure                                 }
  SK_FUNC     = 2;   { function                                  }
  SK_BLOCK    = 3;   { bloc BEGIN..END                           }
  SK_LOOP     = 4;   { boucle (LOOP/WHILE/FOR)                  }
  SK_EXCEPT   = 5;   { bloc exception                            }
  SK_PACKAGE  = 6;   { package                                   }

  { Prefixes de nommage ASM }
  ADA_VAR_PFX   = '_ADA_';       { variable globale              }
  ADA_FN_PFX    = '_ADAF_';      { procedure / function          }
  ADA_STR_PFX   = '_ADAK_';      { constante chaine litterale    }
  ADA_RT_PFX    = '_ADART_';     { routine runtime               }
  ADA_LBL_PFX   = '_ADAL_';      { label de saut interne         }
  ADA_ARR_PFX   = '_ADAA_';      { tableau                       }
  ADA_REC_PFX   = '_ADAR_';      { record                        }
  ADA_PKG_PFX   = '_ADAP_';      { package                       }
  ADA_EX_PFX    = '_ADAX_';      { exception handler             }

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
  PE_NUM_API      = 7;           { number of imported Win32 APIs      }
  COFF_RELOC_DIR32  = 6;         { IMAGE_REL_I386_DIR32               }
  COFF_RELOC_REL32  = 20;        { IMAGE_REL_I386_REL32               }
{$ENDIF}

{ ============================================================ }
{ TYPES                                                        }
{ ============================================================ }

Type
  TString = String[MAX_STR];

  { ---- Options de compilation ----------------------------- }
  TOptions = Record
    SrcFile   : TString;   { fichier source (.adb/.ads)           }
    OutFile   : TString;   { fichier de sortie (.exe/.obj/.asm)   }
    Verbose   : Boolean;   { -v : banniere et statistiques        }
    DebugMode : Boolean;   { -d : affichage de chaque token       }
    Warnings  : Boolean;   { -w : activer les avertissements      }
    EmitExe   : Boolean;   { produire un .EXE PE (defaut)         }
    EmitObj   : Boolean;   { -obj : produire uniquement un .OBJ   }
    EmitAsm   : Boolean;   { -asm : produire un listing .ASM      }
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

  { ---- Entree de la table des symboles (32 bits) ----------- }
  TSymEntry = Record
    Name        : String[48];   { Nom Ada (upper-case)               }
    AsmLabel    : String[48];   { Etiquette ASM : _ADA_nom           }
    TypeIdx     : Integer;       { TYPE_xxx                          }
    StoreClass  : Integer;       { STORE_xxx                         }
    BpOffset    : Integer;       { offset EBP si locale (negatif)    }
    ArraySize   : Integer;       { 0 si scalaire, n si tableau       }
    CharLen     : Integer;       { longueur pour TYPE_STR / TYPE_CHAR}
    IsConst     : Boolean;       { True si CONSTANT                  }
    ScopeLev    : Integer;       { niveau de scope (0 = global)      }
    InitNum     : LongInt;       { valeur initiale numerique         }
    InitStr     : String[64];    { valeur initiale chaine            }
    HasInit     : Boolean;       { True si initialisation specifiee  }
  End;

  { ---- Entree de la table des sous-programmes (TODO 05) ---- }
  TSubEntry = Record
    Name        : String[48];   { Nom Ada (upper-case)               }
    AsmLabel    : String[48];   { Etiquette ASM : _ADAF_nom          }
    RetType     : Integer;       { TYPE_xxx (TYPE_VOID si proc)      }
    ParamCount  : Integer;       { nombre de parametres               }
    ParamNames  : Array[1..MAX_PARAM] of String[48];
    ParamTypes  : Array[1..MAX_PARAM] of Integer;
    ParamModes  : Array[1..MAX_PARAM] of Integer;  { PARAM_xxx       }
    IsForward   : Boolean;       { True si forward declaration       }
    IsFunction  : Boolean;       { True si FUNCTION                  }
    FrameSize   : Integer;       { taille frame locale en octets     }
  End;

  { ---- Entree de la table des types (TODO 05) -------------- }
  TTypeEntry = Record
    Name        : String[48];   { Nom du type Ada (upper-case)       }
    Kind        : Integer;       { TK_xxx                            }
    BaseType    : Integer;       { type de base (derives/ranges)     }
    LoBound     : LongInt;       { borne inferieure (RANGE/ARRAY)    }
    HiBound     : LongInt;       { borne superieure                  }
    FieldCount  : Integer;       { nombre de champs (RECORD)         }
    FieldNames  : Array[1..MAX_FIELD] of String[48];
    FieldTypes  : Array[1..MAX_FIELD] of Integer;
    FieldOffs   : Array[1..MAX_FIELD] of Integer;  { offsets octets  }
    ElemType    : Integer;       { type des elements (ARRAY)         }
    ElemSize    : Integer;       { taille d un element en octets     }
    EnumCount   : Integer;       { nombre de litteraux (ENUM)        }
    EnumNames   : Array[1..MAX_ENUM] of String[48];
    TotalSize   : Integer;       { taille totale du type en octets   }
  End;

  { ---- Entree de la table des packages (TODO 05) ----------- }
  TPkgEntry = Record
    Name        : String[48];   { Nom du package (upper-case)        }
    IsStandard  : Boolean;       { True si package standard reconnu  }
    UseActive   : Boolean;       { True si USE active (acces direct) }
  End;

  { ---- Entree de la pile de scopes (TODO 06) ---------------- }
  TScopeEntry = Record
    Kind        : Integer;       { SK_xxx                            }
    SubIdx      : Integer;       { index SubTab (0 si global)        }
    BpTop       : Integer;       { prochain offset EBP libre (<=0)   }
    SymStart    : Integer;       { 1er index SymTab dans ce scope    }
    LblExit     : String[16];    { label sortie (RETURN / EXIT)      }
    LblCont     : String[16];    { label continuation (boucle)       }
    LblEnd      : String[16];    { label fin de bloc                 }
    HasExcept   : Boolean;       { True si EXCEPTION present         }
    LblExcept   : String[16];    { label handler EXCEPTION           }
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

  { Fichier de sortie }
  OutF       : Text;
  OutFOpen   : Boolean;

  { Lexeur }
  LexSrcF    : Text;       { handle du fichier source              }
  LexOpened  : Boolean;    { fichier source ouvert ?               }
  LexLine    : TString;    { ligne courante                        }
  LexLineNo  : Integer;    { numero de ligne courante (1-based)    }
  LexColNo   : Integer;    { colonne courante dans LexLine         }
  LexEOF     : Boolean;    { fin de fichier atteinte ?             }
  CurTokType : Integer;    { type du token courant (TOK_xxx)       }
  CurTokStr  : TString;    { valeur textuelle du token courant     }
  CurTokNum  : LongInt;    { valeur entiere (TOK_INTEGER)          }
  CurTokKw   : Integer;    { code mot-cle (KW_xxx) ou KW_NONE     }

  { Table des symboles (TODO 04) }
  SymTab     : Array[1..MAX_SYM] of TSymEntry;
  SymCount   : Integer;    { nombre de symboles enregistres         }
  ScopeTop   : Integer;    { niveau de scope courant (0 = global)   }

  { Table des types (TODO 05) }
  TypeTab    : Array[1..MAX_TYPE] of TTypeEntry;
  TypeCount  : Integer;    { nombre de types enregistres            }

  { Table des sous-programmes (TODO 05) }
  SubTab     : Array[1..MAX_SUB] of TSubEntry;
  SubCount   : Integer;    { nombre de sous-programmes enregistres  }

  { Table des packages (TODO 05) }
  PkgTab     : Array[1..MAX_PKG] of TPkgEntry;
  PkgCount   : Integer;    { nombre de packages enregistres         }

  { Pile de scopes (TODO 06) }
  ScopeStack : Array[0..MAX_DEPTH] of TScopeEntry;
  { ScopeTop deja declare plus haut avec SymTab }

  { Generateur de code bas niveau (TODO 07) }
  GenEnabled   : Boolean;     { True si generation de code active    }
  LabelCounter : Integer;     { compteur pour NewLabel               }
  AsmF         : Text;        { fichier .ASM en ecriture             }
  AsmOpened    : Boolean;     { fichier ASM ouvert ?                 }
  StrTab       : Array[1..MAX_DATA] of TString;  { litteraux chaines }
  StrLblTab    : Array[1..MAX_DATA] of TString;  { labels associes   }
  StrCount     : Integer;     { nombre de litteraux enregistres      }

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

  { TODO 24 : nom de la procedure principale Ada }
  MainProcName : TString;    { nom de la procedure de library unit   }

Const
{$IFDEF FPC}
  BinAPIDecorated : Array[0..PE_NUM_API - 1] Of String[32] = (
    '_ExitProcess@4', '_GetStdHandle@4', '_WriteFile@20',
    '_ReadFile@20', '_GetProcessHeap@0', '_HeapAlloc@12',
    '_HeapFree@12'
  );
  BinAPIName : Array[0..PE_NUM_API - 1] Of String[20] = (
    'ExitProcess', 'GetStdHandle', 'WriteFile', 'ReadFile',
    'GetProcessHeap', 'HeapAlloc', 'HeapFree'
  );
{$ENDIF}

{ ============================================================ }
{ DECLARATIONS FORWARD (GENERATION FINALE TODO 25)             }
{ ============================================================ }

{$IFDEF FPC}
Procedure BinInit; Forward;
Procedure BinEmitByte(B : Byte); Forward;
Procedure BinEmitWord(W : Word); Forward;
Procedure BinEmitDWord(D : LongInt); Forward;
Procedure BinEmitDataByte(B : Byte); Forward;
Procedure BinEmitDataWord(W : Word); Forward;
Procedure BinEmitDataDWord(D : LongInt); Forward;
Procedure BinAddLabel(AName : TString; AnOfs : LongInt); Forward;
Procedure BinAddFixup(AnOfs : LongInt; AKind : TBinFixKind;
                      ATarget : TString; AInCode : Boolean); Forward;
Function  BinFindLabel(AName : TString) : LongInt; Forward;
Procedure BinAssemble; Forward;
Procedure BinWriteObj; Forward;
Procedure BinWriteExe; Forward;
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
  WriteLn('ADACW32: FATAL: ', Msg);
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
  WriteLn('ADACW32: warning: ', Msg);
  Inc(WarnCount);
End;

{ ============================================================ }
{ LEXEUR ADA (TODO 02)                                         }
{ ============================================================ }

{ ---- Primitives de bas niveau ----------------------------- }

Function LexCurChar : Char;
Begin
  If LexEOF Or (LexColNo > Length(LexLine)) Then
    LexCurChar := #0
  Else
    LexCurChar := LexLine[LexColNo];
End;

Function LexPeek : Char;
Begin
  If LexEOF Or (LexColNo + 1 > Length(LexLine)) Then
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

Procedure LexError(Const Msg : TString);
Begin
  WriteLn('ADACW32: ligne ', LexLineNo, ': ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('trop d''erreurs, abandon');
End;

{ ---- LexSkipWS : sauter espaces, TABs et commentaires Ada (--)  }
Procedure LexSkipWS;
Var Done : Boolean;
Begin
  Done := False;
  While Not Done Do
  Begin
    Done := True;
    { Lire la prochaine ligne si necessaire }
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
      LexNextLine;
    If LexEOF Then Exit;
    { Sauter espaces et tabulations }
    While (LexColNo <= Length(LexLine)) And
          ((LexLine[LexColNo] = ' ') Or (LexLine[LexColNo] = #9)) Do
    Begin
      Inc(LexColNo);
      Done := False;
    End;
    { Commentaire Ada : -- jusqu a fin de ligne }
    If (LexColNo < Length(LexLine)) And
       (LexLine[LexColNo] = '-') And (LexLine[LexColNo + 1] = '-') Then
    Begin
      LexColNo := Length(LexLine) + 1;
      Done := False;
    End;
  End;
End;

{ ---- IsKeyword : table des 76 mots-cles Ada (KW_PROCEDURE..KW_INOUT) }
{ S doit etre en MAJUSCULES (garanti par le lexeur).                    }
Function IsKeyword(Const S : TString) : Integer;
Begin
  IsKeyword := KW_NONE;
  Case Length(S) of
    2: Begin
        If      S = 'AT' Then IsKeyword := KW_AT
        Else If S = 'DO' Then IsKeyword := KW_DO
        Else If S = 'IF' Then IsKeyword := KW_IF
        Else If S = 'IN' Then IsKeyword := KW_IN
        Else If S = 'IS' Then IsKeyword := KW_IS
        Else If S = 'OF' Then IsKeyword := KW_OF
        Else If S = 'OR' Then IsKeyword := KW_OR;
       End;
    3: Begin
        If      S = 'ABS' Then IsKeyword := KW_ABS
        Else If S = 'ALL' Then IsKeyword := KW_ALL
        Else If S = 'AND' Then IsKeyword := KW_AND
        Else If S = 'END' Then IsKeyword := KW_END
        Else If S = 'FOR' Then IsKeyword := KW_FOR
        Else If S = 'MOD' Then IsKeyword := KW_MOD
        Else If S = 'NEW' Then IsKeyword := KW_NEW
        Else If S = 'NOT' Then IsKeyword := KW_NOT
        Else If S = 'OUT' Then IsKeyword := KW_OUT
        Else If S = 'REM' Then IsKeyword := KW_REM
        Else If S = 'USE' Then IsKeyword := KW_USE
        Else If S = 'XOR' Then IsKeyword := KW_XOR;
       End;
    4: Begin
        If      S = 'BODY' Then IsKeyword := KW_BODY
        Else If S = 'CASE' Then IsKeyword := KW_CASE
        Else If S = 'ELSE' Then IsKeyword := KW_ELSE
        Else If S = 'EXIT' Then IsKeyword := KW_EXIT
        Else If S = 'GOTO' Then IsKeyword := KW_GOTO
        Else If S = 'LOOP' Then IsKeyword := KW_LOOP
        Else If S = 'NULL' Then IsKeyword := KW_NULL
        Else If S = 'SOME' Then IsKeyword := KW_SOME
        Else If S = 'TASK' Then IsKeyword := KW_TASK
        Else If S = 'THEN' Then IsKeyword := KW_THEN
        Else If S = 'TRUE' Then IsKeyword := KW_TRUE
        Else If S = 'TYPE' Then IsKeyword := KW_TYPE
        Else If S = 'WHEN' Then IsKeyword := KW_WHEN
        Else If S = 'WITH' Then IsKeyword := KW_WITH;
       End;
    5: Begin
        If      S = 'ARRAY' Then IsKeyword := KW_ARRAY
        Else If S = 'BEGIN' Then IsKeyword := KW_BEGIN
        Else If S = 'DELAY' Then IsKeyword := KW_DELAY
        Else If S = 'DELTA' Then IsKeyword := KW_DELTA
        Else If S = 'ELSIF' Then IsKeyword := KW_ELSIF
        Else If S = 'ENTRY' Then IsKeyword := KW_ENTRY
        Else If S = 'FALSE' Then IsKeyword := KW_FALSE
        Else If S = 'INOUT' Then IsKeyword := KW_INOUT
        Else If S = 'RAISE' Then IsKeyword := KW_RAISE
        Else If S = 'RANGE' Then IsKeyword := KW_RANGE
        Else If S = 'UNTIL' Then IsKeyword := KW_UNTIL
        Else If S = 'WHILE' Then IsKeyword := KW_WHILE;
       End;
    6: Begin
        If      S = 'ACCEPT' Then IsKeyword := KW_ACCEPT
        Else If S = 'ACCESS' Then IsKeyword := KW_ACCESS
        Else If S = 'DIGITS' Then IsKeyword := KW_DIGITS
        Else If S = 'OTHERS' Then IsKeyword := KW_OTHERS
        Else If S = 'PRAGMA' Then IsKeyword := KW_PRAGMA
        Else If S = 'RECORD' Then IsKeyword := KW_RECORD
        Else If S = 'RETURN' Then IsKeyword := KW_RETURN
        Else If S = 'SELECT' Then IsKeyword := KW_SELECT
        Else If S = 'TAGGED' Then IsKeyword := KW_TAGGED;
       End;
    7: Begin
        If      S = 'DECLARE' Then IsKeyword := KW_DECLARE
        Else If S = 'GENERIC' Then IsKeyword := KW_GENERIC
        Else If S = 'LIMITED' Then IsKeyword := KW_LIMITED
        Else If S = 'PACKAGE' Then IsKeyword := KW_PACKAGE
        Else If S = 'PRIVATE' Then IsKeyword := KW_PRIVATE
        Else If S = 'RENAMES' Then IsKeyword := KW_RENAMES
        Else If S = 'REQUEUE' Then IsKeyword := KW_REQUEUE
        Else If S = 'REVERSE' Then IsKeyword := KW_REVERSE
        Else If S = 'SUBTYPE' Then IsKeyword := KW_SUBTYPE;
       End;
    8: Begin
        If      S = 'ABSTRACT' Then IsKeyword := KW_ABSTRACT
        Else If S = 'CONSTANT' Then IsKeyword := KW_CONSTANT
        Else If S = 'FUNCTION' Then IsKeyword := KW_FUNCTION
        Else If S = 'SEPARATE' Then IsKeyword := KW_SEPARATE;
       End;
    9: Begin
        If      S = 'EXCEPTION' Then IsKeyword := KW_EXCEPTION
        Else If S = 'INTERFACE' Then IsKeyword := KW_INTERFACE
        Else If S = 'PROCEDURE' Then IsKeyword := KW_PROCEDURE
        Else If S = 'PROTECTED' Then IsKeyword := KW_PROTECTED
        Else If S = 'TERMINATE' Then IsKeyword := KW_TERMINATE;
       End;
    10: If S = 'OVERRIDING' Then IsKeyword := KW_OVERRIDING;
    12: If S = 'SYNCHRONIZED' Then IsKeyword := KW_SYNCHRONIZED;
  End;
End;

{ ---- LexIdent : scanner un identificateur ou mot-cle Ada ---- }
{ Ada est insensible a la casse : convertir en majuscules.       }
Procedure LexIdent;
Var
  S  : TString;
  C  : Char;
Begin
  S := '';
  While (LexColNo <= Length(LexLine)) Do
  Begin
    C := LexLine[LexColNo];
    If ((C >= 'A') And (C <= 'Z')) Or ((C >= 'a') And (C <= 'z')) Or
       ((C >= '0') And (C <= '9')) Or (C = '_') Then
    Begin
      If Length(S) < MAX_IDENT Then
      Begin
        If (C >= 'a') And (C <= 'z') Then
          S := S + Chr(Ord(C) - 32)
        Else
          S := S + C;
      End;
      LexAdvance;
    End
    Else
      Break;
  End;
  CurTokType := TOK_IDENT;
  CurTokStr  := S;
  CurTokKw   := IsKeyword(S);
End;

{ ---- LexNumber : scanner un litteral numerique Ada ----------- }
{ Entier decimal, base#valeur# (2#1010#, 16#FF#), flottant.      }
Procedure LexNumber;
Var
  S      : TString;
  IntVal : LongInt;
  Base   : Integer;
  C, C2  : Char;
  Dv     : Integer;
  IsFloat: Boolean;
  FltStr : TString;
Begin
  S       := '';
  IntVal  := 0;
  IsFloat := False;
  Base    := 10;

  { Accumuler les chiffres decimaux initiaux }
  While (LexColNo <= Length(LexLine)) Do
  Begin
    C := LexCurChar;
    If (C >= '0') And (C <= '9') Then
    Begin
      S      := S + C;
      IntVal := IntVal * 10 + (Ord(C) - Ord('0'));
      LexAdvance;
    End
    Else If C = '_' Then
      LexAdvance  { underscores autorises dans les nombres Ada }
    Else
      Break;
  End;

  { Litteral en base n#valeur# }
  If (LexColNo <= Length(LexLine)) And (LexCurChar = '#') Then
  Begin
    Base   := IntVal;
    IntVal := 0;
    S      := '';
    LexAdvance; { consommer le '#' }
    While (LexColNo <= Length(LexLine)) Do
    Begin
      C := LexCurChar;
      If C = '#' Then Begin LexAdvance; Break; End;
      If C = '_' Then Begin LexAdvance; Continue; End;
      { Calculer la valeur du chiffre dans la base }
      If (C >= '0') And (C <= '9') Then
        Dv := Ord(C) - Ord('0')
      Else If (C >= 'A') And (C <= 'F') Then
        Dv := Ord(C) - Ord('A') + 10
      Else If (C >= 'a') And (C <= 'f') Then
        Dv := Ord(C) - Ord('a') + 10
      Else
        Break;
      If Dv >= Base Then Break;
      S      := S + C;
      IntVal := IntVal * Base + Dv;
      LexAdvance;
    End;
    CurTokType := TOK_INTEGER;
    CurTokNum  := IntVal;
    CurTokStr  := IntToStr_(IntVal);
    Exit;
  End;

  { Flottant : partie decimale apres '.' }
  If (LexColNo <= Length(LexLine)) And (LexCurChar = '.') Then
  Begin
    C2 := LexPeek;
    If C2 = '.' Then
    Begin
      { operateur '..' : ne pas consommer le '.' }
      CurTokType := TOK_INTEGER;
      CurTokNum  := IntVal;
      CurTokStr  := S;
      Exit;
    End;
    IsFloat := True;
    FltStr  := S + '.';
    LexAdvance; { consommer le '.' }
    While (LexColNo <= Length(LexLine)) Do
    Begin
      C := LexCurChar;
      If (C >= '0') And (C <= '9') Then
      Begin
        FltStr := FltStr + C;
        LexAdvance;
      End
      Else If C = '_' Then
        LexAdvance
      Else
        Break;
    End;
  End;

  { Exposant E ou e }
  If (LexColNo <= Length(LexLine)) And
     ((LexCurChar = 'E') Or (LexCurChar = 'e')) Then
  Begin
    If Not IsFloat Then FltStr := S;
    IsFloat := True;
    FltStr  := FltStr + 'E';
    LexAdvance;
    If (LexColNo <= Length(LexLine)) And
       ((LexCurChar = '+') Or (LexCurChar = '-')) Then
    Begin
      FltStr := FltStr + LexCurChar;
      LexAdvance;
    End;
    While (LexColNo <= Length(LexLine)) And
          (LexCurChar >= '0') And (LexCurChar <= '9') Do
    Begin
      FltStr := FltStr + LexCurChar;
      LexAdvance;
    End;
  End;

  If IsFloat Then
  Begin
    CurTokType := TOK_FLOAT;
    CurTokStr  := FltStr;
    CurTokNum  := IntVal;
  End
  Else
  Begin
    CurTokType := TOK_INTEGER;
    CurTokNum  := IntVal;
    CurTokStr  := S;
  End;
End;

{ ---- LexCharOrTick : scanner 'c' ou tick d attribut --------- }
{ En Ada : 'c' est un Character literal.
  Le tick ' devant un ident est l attribut T'FIRST -> retourne TOK_TICK. }
Procedure LexCharOrTick;
Var Ch : Char;
Begin
  { On vient de consommer le premier ' }
  If LexColNo > Length(LexLine) Then
  Begin
    CurTokType := TOK_TICK;
    CurTokStr  := '''';
    Exit;
  End;
  Ch := LexCurChar;
  If (LexColNo + 1 <= Length(LexLine)) And
     (LexLine[LexColNo + 1] = '''') Then
  Begin
    { 'c' -> litteral caractere }
    CurTokType := TOK_CHAR;
    CurTokStr  := Ch;
    CurTokNum  := Ord(Ch);
    LexAdvance; { consommer le caractere }
    LexAdvance; { consommer le ' fermant }
  End
  Else
  Begin
    { tick d attribut : T'FIRST, T'LENGTH, etc. }
    CurTokType := TOK_TICK;
    CurTokStr  := '''';
  End;
End;

{ ---- LexString : scanner un litteral chaine "..." ----------- }
{ En Ada : "" a l interieur = guillemet inclus dans la chaine.   }
Procedure LexString;
Var
  S  : TString;
  C  : Char;
Begin
  S := '';
  While (LexColNo <= Length(LexLine)) Do
  Begin
    C := LexCurChar;
    If C = '"' Then
    Begin
      LexAdvance;
      { "" -> guillemet double inclus dans la chaine }
      If (LexColNo <= Length(LexLine)) And (LexCurChar = '"') Then
      Begin
        If Length(S) < MAX_STR Then
          S := S + '"';
        LexAdvance;
      End
      Else
        Break; { fin de la chaine }
    End
    Else
    Begin
      If Length(S) < MAX_STR Then
        S := S + C;
      LexAdvance;
    End;
  End;
  CurTokType := TOK_STRING;
  CurTokStr  := S;
End;

{ ---- LexNextToken : dispatcher principal du lexeur Ada ------- }
Procedure LexNextToken;
Var
  C : Char;
Begin
  CurTokStr  := '';
  CurTokNum  := 0;
  CurTokKw   := KW_NONE;

  LexSkipWS;

  { ---- EOF ---- }
  If LexEOF Or (LexColNo > Length(LexLine)) Then
  Begin
    CurTokType := TOK_EOF;
    CurTokStr  := '';
    Exit;
  End;

  C := LexCurChar;

  { ---- Identificateurs et mots-cles Ada ---- }
  If ((C >= 'A') And (C <= 'Z')) Or ((C >= 'a') And (C <= 'z')) Or
     (C = '_') Then
  Begin
    LexIdent;
    Exit;
  End;

  { ---- Litteraux numeriques ---- }
  If (C >= '0') And (C <= '9') Then
  Begin
    LexNumber;
    Exit;
  End;

  { ---- Litteral caractere ou tick d attribut ---- }
  If C = '''' Then
  Begin
    LexAdvance; { consommer le ' ouvrant }
    LexCharOrTick;
    Exit;
  End;

  { ---- Litteral chaine "..." ---- }
  If C = '"' Then
  Begin
    LexAdvance; { consommer le " ouvrant }
    LexString;
    Exit;
  End;

  { ---- Operateurs et separateurs ---- }
  LexAdvance; { consommer le caractere courant }

  Case C Of
    '(': Begin CurTokType := TOK_LPAREN;   CurTokStr := '('; End;
    ')': Begin CurTokType := TOK_RPAREN;   CurTokStr := ')'; End;
    ',': Begin CurTokType := TOK_COMMA;    CurTokStr := ','; End;
    ';': Begin CurTokType := TOK_SEMI;     CurTokStr := ';'; End;
    '|': Begin CurTokType := TOK_BAR;      CurTokStr := '|'; End;
    '+': Begin CurTokType := TOK_PLUS;     CurTokStr := '+'; End;
    '-': Begin CurTokType := TOK_MINUS;    CurTokStr := '-'; End;
    '&': Begin CurTokType := TOK_AMPERSAND;CurTokStr := '&'; End;
    ':': Begin
           If (LexColNo <= Length(LexLine)) And (LexCurChar = '=') Then
           Begin LexAdvance; CurTokType := TOK_COLONASSIGN; CurTokStr := ':='; End
           Else Begin CurTokType := TOK_COLON; CurTokStr := ':'; End;
         End;
    '/': Begin
           If (LexColNo <= Length(LexLine)) And (LexCurChar = '=') Then
           Begin LexAdvance; CurTokType := TOK_NEQ; CurTokStr := '/='; End
           Else Begin CurTokType := TOK_SLASH; CurTokStr := '/'; End;
         End;
    '>': Begin
           If (LexColNo <= Length(LexLine)) And (LexCurChar = '=') Then
           Begin LexAdvance; CurTokType := TOK_GE; CurTokStr := '>='; End
           Else Begin CurTokType := TOK_GT; CurTokStr := '>'; End;
         End;
    '<': Begin
           If (LexColNo <= Length(LexLine)) And (LexCurChar = '=') Then
           Begin LexAdvance; CurTokType := TOK_LE; CurTokStr := '<='; End
           Else Begin CurTokType := TOK_LT; CurTokStr := '<'; End;
         End;
    '=': Begin
           If (LexColNo <= Length(LexLine)) And (LexCurChar = '>') Then
           Begin LexAdvance; CurTokType := TOK_ARROW; CurTokStr := '=>'; End
           Else Begin CurTokType := TOK_EQ; CurTokStr := '='; End;
         End;
    '.': Begin
           If (LexColNo <= Length(LexLine)) And (LexCurChar = '.') Then
           Begin LexAdvance; CurTokType := TOK_DOTDOT; CurTokStr := '..'; End
           Else Begin CurTokType := TOK_DOT; CurTokStr := '.'; End;
         End;
    '*': Begin
           If (LexColNo <= Length(LexLine)) And (LexCurChar = '*') Then
           Begin LexAdvance; CurTokType := TOK_POWER; CurTokStr := '**'; End
           Else Begin CurTokType := TOK_STAR; CurTokStr := '*'; End;
         End;
    Else Begin
           CurTokType := TOK_UNKNOWN;
           CurTokStr  := C;
         End;
  End;
End;

{ ---- PrintToken : afficher le token courant (mode debug) ---- }
Procedure PrintToken;
Var Kind : TString;
Begin
  Case CurTokType Of
    TOK_IDENT       : Kind := 'IDENT';
    TOK_INTEGER     : Kind := 'INTEGER';
    TOK_FLOAT       : Kind := 'FLOAT';
    TOK_CHAR        : Kind := 'CHAR';
    TOK_STRING      : Kind := 'STRING';
    TOK_LPAREN      : Kind := 'LPAREN';
    TOK_RPAREN      : Kind := 'RPAREN';
    TOK_COMMA       : Kind := 'COMMA';
    TOK_SEMI        : Kind := 'SEMI';
    TOK_COLON       : Kind := 'COLON';
    TOK_COLONASSIGN : Kind := 'COLONASSIGN';
    TOK_DOT         : Kind := 'DOT';
    TOK_DOTDOT      : Kind := 'DOTDOT';
    TOK_BAR         : Kind := 'BAR';
    TOK_LT          : Kind := 'LT';
    TOK_GT          : Kind := 'GT';
    TOK_LE          : Kind := 'LE';
    TOK_GE          : Kind := 'GE';
    TOK_EQ          : Kind := 'EQ';
    TOK_NEQ         : Kind := 'NEQ';
    TOK_ARROW       : Kind := 'ARROW';
    TOK_PLUS        : Kind := 'PLUS';
    TOK_MINUS       : Kind := 'MINUS';
    TOK_STAR        : Kind := 'STAR';
    TOK_SLASH       : Kind := 'SLASH';
    TOK_POWER       : Kind := 'POWER';
    TOK_AMPERSAND   : Kind := 'AMPERSAND';
    TOK_TICK        : Kind := 'TICK';
    TOK_EOF         : Kind := 'EOF';
    Else              Kind := 'UNKNOWN';
  End;
  Write('[', LexLineNo, ':', LexColNo, '] ', Kind);
  If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_STRING) Or
     (CurTokType = TOK_INTEGER) Or (CurTokType = TOK_FLOAT) Or
     (CurTokType = TOK_CHAR) Then
    Write(' <', CurTokStr, '>');
  If (CurTokType = TOK_IDENT) And (CurTokKw <> KW_NONE) Then
    Write(' kw=', CurTokKw);
  WriteLn;
End;

{ ---- Helpers de parsing ------------------------------------ }

Function TokIsKw(Kw : Integer) : Boolean;
Begin
  TokIsKw := (CurTokType = TOK_IDENT) And (CurTokKw = Kw);
End;

Function TokIsOp(Tok : Integer) : Boolean;
Begin
  TokIsOp := (CurTokType = Tok);
End;

Procedure Consume;
Begin
  LexNextToken;
End;

Procedure Expect(TT : Integer; Const What : TString);
Begin
  If CurTokType <> TT Then
    LexError('Attendu ' + What + ', trouve: ''' + CurTokStr + '''');
  Consume;
End;

Procedure ExpectKw(Kw : Integer; Const What : TString);
Begin
  If Not TokIsKw(Kw) Then
    LexError('Attendu ' + What + ', trouve: ''' + CurTokStr + '''');
  Consume;
End;

{ ---- SkipToSemi : consommer jusqu a ';' pour resynchroniser -- }
Procedure SkipToSemi;
Begin
  While (CurTokType <> TOK_SEMI) And (CurTokType <> TOK_EOF) Do
    Consume;
  If CurTokType = TOK_SEMI Then Consume;
End;

{ ============================================================ }
{ MOTS-CLES ADA ET GESTION DES ERREURS (TODO 03)               }
{ ============================================================ }

{ ---- Error : erreur non fatale, incrementer ErrorCount ------- }
{ Affiche ligne + message, continue la compilation.              }
Procedure Error(Const Msg : TString);
Begin
  WriteLn('ADACW32: ERREUR ligne ', LexLineNo, ': ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('trop d''erreurs, abandon');
End;

{ ---- Warning : avertissement non bloquant -------------------- }
{ Affiche ligne + message, continue la compilation.              }
Procedure Warning(Const Msg : TString);
Begin
  WriteLn('ADACW32: ATTENTION ligne ', LexLineNo, ': ', Msg);
  Inc(WarnCount);
End;

{ ---- SkipToEnd : consommer jusqu a END correspondant --------- }
{ Gere les blocs imbriques en comptant BEGIN/DECLARE/LOOP/       }
{ RECORD vs END. Consomme le ';' final apres END si present.     }
Procedure SkipToEnd;
Var
  Depth : Integer;
Begin
  Depth := 1;
  While (CurTokType <> TOK_EOF) And (Depth > 0) Do
  Begin
    If TokIsKw(KW_BEGIN) Or TokIsKw(KW_DECLARE) Or
       TokIsKw(KW_LOOP) Or TokIsKw(KW_RECORD) Then
      Inc(Depth)
    Else If TokIsKw(KW_END) Then
      Dec(Depth);
    Consume;
  End;
  { Consommer l identificateur optionnel apres END (ex: END Hello;) }
  If CurTokType = TOK_IDENT Then Consume;
  { Consommer le ';' apres END si present }
  If CurTokType = TOK_SEMI Then Consume;
End;

{ ---- SkipToKw : sauter jusqu a un mot-cle specifique --------- }
{ Utilise pour resynchroniser apres une condition malformee.      }
Procedure SkipToKw(Kw : Integer);
Begin
  While (CurTokType <> TOK_EOF) And (Not TokIsKw(Kw)) Do
    Consume;
End;

{ ---- BilanCompilation : afficher les statistiques ------------ }
Procedure BilanCompilation;
Begin
  WriteLn;
  WriteLn('ADACW32 - Compilation terminee');
  WriteLn('  Source     : ', Opts.SrcFile);
  WriteLn('  Sortie     : ', Opts.OutFile);
  WriteLn('  Lignes     : ', TotalLines);
  WriteLn('  Symboles   : ', SymCount);
  WriteLn('  Types      : ', TypeCount);
  WriteLn('  Sous-prog. : ', SubCount);
  WriteLn('  Packages   : ', PkgCount);
  WriteLn('  Scope      : ', ScopeTop);
  WriteLn('  Chaines    : ', StrCount);
  WriteLn('  Labels     : ', LabelCounter);
  WriteLn('  Erreurs    : ', ErrorCount);
  WriteLn('  Avertiss.  : ', WarnCount);
  If ErrorCount > 0 Then
    WriteLn('  *** COMPILATION AVEC ERREURS ***');
End;

{ ============================================================ }
{ TABLE DES SYMBOLES (TODO 04)                                  }
{ ============================================================ }

{ ---- PrimTypeSize32 : taille de base d un type predefini ----- }
{ Retourne la taille en octets pour les types predefinis Ada.     }
{ Pour les types utilisateur, retourne 4 par defaut (stub).       }
Function PrimTypeSize32(TypeId : Integer) : Integer;
Begin
  Case TypeId Of
    TYPE_INT    : PrimTypeSize32 := 4;   { Integer   : DD (4 octets)  }
    TYPE_FLOAT  : PrimTypeSize32 := 8;   { Float     : DQ (8 octets)  }
    TYPE_BOOL   : PrimTypeSize32 := 1;   { Boolean   : DB (1 octet)   }
    TYPE_CHAR   : PrimTypeSize32 := 1;   { Character : DB (1 octet)   }
    TYPE_STR    : PrimTypeSize32 := 4;   { String    : pointeur DD    }
    TYPE_ACCESS : PrimTypeSize32 := 4;   { Access    : pointeur DD    }
  Else
    PrimTypeSize32 := 4;                 { types utilisateur : stub   }
  End;
End;

{ ---- AlignDWord : aligner sur un multiple de 4 (pile 32 bits) }
Function AlignDWord(N : Integer) : Integer;
Begin
  If (N Mod 4) <> 0 Then
    AlignDWord := N + (4 - (N Mod 4))
  Else
    AlignDWord := N;
End;

{ ---- GetSymSize : taille en octets d un symbole -------------- }
{ Tient compte de ArraySize et CharLen pour les tableaux/chaines.}
Function GetSymSize(SymIdx : Integer) : Integer;
Var BaseSz : Integer;
Begin
  If (SymIdx < 1) Or (SymIdx > SymCount) Then
  Begin GetSymSize := 4; Exit; End;

  BaseSz := PrimTypeSize32(SymTab[SymIdx].TypeIdx);

  { TYPE_STR avec CharLen explicite : taille reelle en octets }
  If SymTab[SymIdx].TypeIdx = TYPE_STR Then
  Begin
    If SymTab[SymIdx].CharLen > 0 Then
      BaseSz := SymTab[SymIdx].CharLen + 1   { +1 pour terminateur 0 }
    Else
      BaseSz := 4;
  End;

  If SymTab[SymIdx].ArraySize > 0 Then
    GetSymSize := BaseSz * SymTab[SymIdx].ArraySize
  Else
    GetSymSize := BaseSz;
End;

{ ---- InitSymTable : initialiser la table des symboles -------- }
Procedure InitSymTable;
Var I : Integer;
Begin
  SymCount := 0;
  ScopeTop := 0;
  For I := 1 To MAX_SYM Do
  Begin
    SymTab[I].Name       := '';
    SymTab[I].AsmLabel   := '';
    SymTab[I].TypeIdx    := TYPE_UNKNOWN;
    SymTab[I].StoreClass := STORE_STATIC;
    SymTab[I].BpOffset   := 0;
    SymTab[I].ArraySize  := 0;
    SymTab[I].CharLen    := 0;
    SymTab[I].IsConst    := False;
    SymTab[I].ScopeLev   := 0;
    SymTab[I].InitNum    := 0;
    SymTab[I].InitStr    := '';
    SymTab[I].HasInit    := False;
  End;
End;

{ ---- FindSym : recherche dans toutes les portees ------------- }
{ Parcourt du plus recent au plus ancien pour respecter le       }
{ shadowing (portee la plus proche d abord).                     }
{ Retourne l index (1-base) du symbole, ou 0 si non trouve.      }
Function FindSym(Const Name : TString) : Integer;
Var
  I : Integer;
  U : TString;
Begin
  U := StrUpperCase(Name);
  For I := SymCount DownTo 1 Do
    If SymTab[I].Name = U Then
    Begin FindSym := I; Exit; End;
  FindSym := 0;
End;

{ ---- FindSymLocal : recherche dans le scope courant seul ----- }
{ Retourne l index (1-base) du symbole si trouve dans le scope    }
{ courant, ou 0 si non trouve.                                    }
Function FindSymLocal(Const Name : TString) : Integer;
Var
  I : Integer;
  U : TString;
Begin
  U := StrUpperCase(Name);
  For I := SymCount DownTo 1 Do
    If (SymTab[I].Name = U) And (SymTab[I].ScopeLev = ScopeTop) Then
    Begin FindSymLocal := I; Exit; End;
  FindSymLocal := 0;
End;

{ ---- AddSym : ajouter un symbole dans la table --------------- }
{ Retourne l index (1-base) du nouveau symbole, ou 0 si pleine.  }
{ Pour STORE_AUTO : calcule BpOffset en utilisant ScopeTop.       }
Function AddSym(Const Name : TString; TypeId, SC : Integer) : Integer;
Var
  U   : TString;
  Idx : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    Error('Table des symboles pleine (MAX_SYM=' +
          IntToStr_(MAX_SYM) + ')');
    AddSym := 0;
    Exit;
  End;
  U := StrUpperCase(Name);
  Inc(SymCount);
  Idx := SymCount;
  SymTab[Idx].Name       := U;
  SymTab[Idx].AsmLabel   := ADA_VAR_PFX + AsmIdent(U);
  SymTab[Idx].TypeIdx    := TypeId;
  SymTab[Idx].StoreClass := SC;
  SymTab[Idx].BpOffset   := 0;
  SymTab[Idx].ArraySize  := 0;
  SymTab[Idx].CharLen    := 0;
  SymTab[Idx].IsConst    := (SC = STORE_CONST);
  SymTab[Idx].ScopeLev   := ScopeTop;
  SymTab[Idx].InitNum    := 0;
  SymTab[Idx].InitStr    := '';
  SymTab[Idx].HasInit    := False;
  AddSym := Idx;
End;

{ ============================================================ }
{ TABLES DES TYPES ET SOUS-PROGRAMMES (TODO 05)                 }
{ ============================================================ }

{ ---- InitTypeTable : initialiser la table des types ---------- }
Procedure InitTypeTable;
Var I, J : Integer;
Begin
  TypeCount := 0;
  For I := 1 To MAX_TYPE Do
  Begin
    TypeTab[I].Name       := '';
    TypeTab[I].Kind       := TK_PREDEF;
    TypeTab[I].BaseType   := TYPE_UNKNOWN;
    TypeTab[I].LoBound    := 0;
    TypeTab[I].HiBound    := 0;
    TypeTab[I].FieldCount := 0;
    TypeTab[I].ElemType   := TYPE_UNKNOWN;
    TypeTab[I].ElemSize   := 4;
    TypeTab[I].EnumCount  := 0;
    TypeTab[I].TotalSize  := 4;
    For J := 1 To MAX_FIELD Do
    Begin
      TypeTab[I].FieldNames[J] := '';
      TypeTab[I].FieldTypes[J] := TYPE_UNKNOWN;
      TypeTab[I].FieldOffs[J]  := 0;
    End;
    For J := 1 To MAX_ENUM Do
      TypeTab[I].EnumNames[J] := '';
  End;
End;

{ ---- RegisterPredefinedTypes : enregistrer les types predefinis }
{ Occupe les slots TYPE_INT..TYPE_STR (indices 1 a 5).            }
{ Tailles en 32 bits : Integer=4, Float=8, Boolean=1, Char=1.     }
Procedure RegisterPredefinedTypes;
Var I : Integer;
Begin
  For I := 1 To 5 Do
  Begin
    TypeTab[I].Kind     := TK_PREDEF;
    TypeTab[I].BaseType := TYPE_UNKNOWN;
    TypeTab[I].LoBound  := 0;
    TypeTab[I].HiBound  := 0;
  End;

  { TYPE_INT = 1 : Integer 32 bits signe }
  TypeTab[TYPE_INT].Name      := 'INTEGER';
  TypeTab[TYPE_INT].TotalSize := 4;    { DD 4 octets }
  TypeTab[TYPE_INT].LoBound   := -2147483648;
  TypeTab[TYPE_INT].HiBound   :=  2147483647;
  TypeTab[TYPE_INT].Kind      := TK_RANGE;
  TypeTab[TYPE_INT].BaseType  := TYPE_INT;

  { TYPE_FLOAT = 2 : Float 64 bits (DQ 8 octets, stub) }
  TypeTab[TYPE_FLOAT].Name      := 'FLOAT';
  TypeTab[TYPE_FLOAT].TotalSize := 8;  { DQ 8 octets }
  TypeTab[TYPE_FLOAT].Kind      := TK_PREDEF;

  { TYPE_BOOL = 3 : Boolean (0=False, 1=True, DB 1 octet) }
  TypeTab[TYPE_BOOL].Name       := 'BOOLEAN';
  TypeTab[TYPE_BOOL].TotalSize  := 1;  { DB 1 octet }
  TypeTab[TYPE_BOOL].Kind       := TK_ENUM;
  TypeTab[TYPE_BOOL].EnumCount  := 2;
  TypeTab[TYPE_BOOL].EnumNames[1] := 'FALSE';
  TypeTab[TYPE_BOOL].EnumNames[2] := 'TRUE';

  { TYPE_CHAR = 4 : Character (ASCII 0..255, DB 1 octet) }
  TypeTab[TYPE_CHAR].Name      := 'CHARACTER';
  TypeTab[TYPE_CHAR].TotalSize := 1;   { DB 1 octet }
  TypeTab[TYPE_CHAR].Kind      := TK_RANGE;
  TypeTab[TYPE_CHAR].LoBound   := 0;
  TypeTab[TYPE_CHAR].HiBound   := 255;

  { TYPE_STR = 5 : String (pointeur DD 4 octets en 32 bits) }
  TypeTab[TYPE_STR].Name      := 'STRING';
  TypeTab[TYPE_STR].TotalSize := 4;    { pointeur 32 bits }
  TypeTab[TYPE_STR].Kind      := TK_ARRAY;
  TypeTab[TYPE_STR].ElemType  := TYPE_CHAR;
  TypeTab[TYPE_STR].ElemSize  := 1;

  { Les 5 premiers slots sont occupes par les types predefinis }
  TypeCount := 5;
End;

{ ---- RegisterStandardExceptions : exceptions Ada standard ---- }
{ Ajoute CONSTRAINT_ERROR, PROGRAM_ERROR, STORAGE_ERROR,         }
{ TASKING_ERROR comme constantes predefinies (TODO 19).            }
Procedure RegisterStandardExceptions;
Var Idx : Integer;
Begin
  Idx := AddSym('CONSTRAINT_ERROR', TYPE_INT, STORE_CONST);
  If Idx > 0 Then Begin SymTab[Idx].InitNum := 1;
    SymTab[Idx].HasInit := True; SymTab[Idx].IsConst := True; End;
  Idx := AddSym('PROGRAM_ERROR', TYPE_INT, STORE_CONST);
  If Idx > 0 Then Begin SymTab[Idx].InitNum := 2;
    SymTab[Idx].HasInit := True; SymTab[Idx].IsConst := True; End;
  Idx := AddSym('STORAGE_ERROR', TYPE_INT, STORE_CONST);
  If Idx > 0 Then Begin SymTab[Idx].InitNum := 3;
    SymTab[Idx].HasInit := True; SymTab[Idx].IsConst := True; End;
  Idx := AddSym('TASKING_ERROR', TYPE_INT, STORE_CONST);
  If Idx > 0 Then Begin SymTab[Idx].InitNum := 4;
    SymTab[Idx].HasInit := True; SymTab[Idx].IsConst := True; End;
End;

{ ---- AddType : ajouter un type dans la table ----------------- }
{ Retourne l index (1-base, > 5) ou 0 si table pleine.           }
Function AddType(Const Name : TString; Kind : Integer) : Integer;
Var
  U   : TString;
  Idx : Integer;
Begin
  If TypeCount >= MAX_TYPE Then
  Begin
    Error('Table des types pleine (MAX_TYPE=' +
          IntToStr_(MAX_TYPE) + ')');
    AddType := 0;
    Exit;
  End;
  U := StrUpperCase(Name);
  Inc(TypeCount);
  Idx := TypeCount;
  TypeTab[Idx].Name       := U;
  TypeTab[Idx].Kind       := Kind;
  TypeTab[Idx].BaseType   := TYPE_UNKNOWN;
  TypeTab[Idx].LoBound    := 0;
  TypeTab[Idx].HiBound    := 0;
  TypeTab[Idx].FieldCount := 0;
  TypeTab[Idx].ElemType   := TYPE_UNKNOWN;
  TypeTab[Idx].ElemSize   := 4;
  TypeTab[Idx].EnumCount  := 0;
  TypeTab[Idx].TotalSize  := 4;
  AddType := Idx;
End;

{ ---- FindType : recherche un type par nom -------------------- }
{ Retourne l index (1-base) ou 0 si non trouve.                   }
Function FindType(Const Name : TString) : Integer;
Var
  I : Integer;
  U : TString;
Begin
  U := StrUpperCase(Name);
  For I := TypeCount DownTo 1 Do
    If TypeTab[I].Name = U Then
    Begin FindType := I; Exit; End;
  FindType := 0;
End;

{ ---- GetTypeSize : taille en octets d un type ---------------- }
{ Retourne TotalSize du type, ou 4 par defaut si non resolu.     }
Function GetTypeSize(TypeIdx : Integer) : Integer;
Var Sz : Integer;
Begin
  If (TypeIdx < 1) Or (TypeIdx > TypeCount) Then
  Begin GetTypeSize := 4; Exit; End;

  Sz := TypeTab[TypeIdx].TotalSize;
  If Sz <= 0 Then Sz := 4;
  GetTypeSize := Sz;
End;

{ ---- InitSubTable : initialiser la table des sous-programmes - }
Procedure InitSubTable;
Var I, J : Integer;
Begin
  SubCount := 0;
  For I := 1 To MAX_SUB Do
  Begin
    SubTab[I].Name       := '';
    SubTab[I].AsmLabel   := '';
    SubTab[I].RetType    := TYPE_VOID;
    SubTab[I].ParamCount := 0;
    SubTab[I].IsForward  := False;
    SubTab[I].IsFunction := False;
    SubTab[I].FrameSize  := 0;
    For J := 1 To MAX_PARAM Do
    Begin
      SubTab[I].ParamNames[J] := '';
      SubTab[I].ParamTypes[J] := TYPE_UNKNOWN;
      SubTab[I].ParamModes[J] := PARAM_IN;
    End;
  End;
End;

{ ---- AddSub : ajouter un sous-programme ---------------------- }
{ Retourne l index (1-base) ou 0 si table pleine.                 }
Function AddSub(Const Name : TString;
                IsFunc : Boolean; RetTy : Integer) : Integer;
Var
  U   : TString;
  Idx : Integer;
Begin
  If SubCount >= MAX_SUB Then
  Begin
    Error('Table sous-programmes pleine (MAX_SUB=' +
          IntToStr_(MAX_SUB) + ')');
    AddSub := 0;
    Exit;
  End;
  U := StrUpperCase(Name);
  Inc(SubCount);
  Idx := SubCount;
  SubTab[Idx].Name       := U;
  SubTab[Idx].IsFunction := IsFunc;
  SubTab[Idx].RetType    := RetTy;
  SubTab[Idx].ParamCount := 0;
  SubTab[Idx].IsForward  := False;
  SubTab[Idx].FrameSize  := 0;
  If IsFunc Then
    SubTab[Idx].AsmLabel := ADA_FN_PFX + AsmIdent(U)
  Else
    SubTab[Idx].AsmLabel := ADA_FN_PFX + AsmIdent(U);
  AddSub := Idx;
End;

{ ---- FindSub : recherche un sous-programme par nom ----------- }
{ Retourne l index (1-base) ou 0 si non trouve.                   }
Function FindSub(Const Name : TString) : Integer;
Var
  I : Integer;
  U : TString;
Begin
  U := StrUpperCase(Name);
  For I := SubCount DownTo 1 Do
    If SubTab[I].Name = U Then
    Begin FindSub := I; Exit; End;
  FindSub := 0;
End;

{ ---- SubParamBytes32 : taille totale des params en octets ---- }
{ Pour le nettoyage de pile (callee-cleanup : RET n) en 32 bits.  }
{ OUT et INOUT passent par adresse -> toujours 4 octets (ptr 32). }
Function SubParamBytes32(SubIdx : Integer) : Integer;
Var
  I   : Integer;
  Tot : Integer;
Begin
  Tot := 0;
  If (SubIdx < 1) Or (SubIdx > SubCount) Then
  Begin SubParamBytes32 := 0; Exit; End;
  For I := 1 To SubTab[SubIdx].ParamCount Do
  Begin
    If (SubTab[SubIdx].ParamModes[I] = PARAM_OUT) Or
       (SubTab[SubIdx].ParamModes[I] = PARAM_INOUT) Then
      Inc(Tot, 4)   { adresse 32 bits }
    Else
      Inc(Tot, AlignDWord(GetTypeSize(SubTab[SubIdx].ParamTypes[I])));
  End;
  SubParamBytes32 := Tot;
End;

{ ---- InitPkgTable : initialiser la table des packages -------- }
Procedure InitPkgTable;
Var I : Integer;
Begin
  PkgCount := 0;
  For I := 1 To MAX_PKG Do
  Begin
    PkgTab[I].Name       := '';
    PkgTab[I].IsStandard := False;
    PkgTab[I].UseActive  := False;
  End;
End;

{ ---- AddPkg : enregistrer un package importe (WITH) ---------- }
{ Retourne l index (1-base) ou 0 si plein. Si deja present,       }
{ retourne l index existant.                                       }
Function AddPkg(Const Name : TString; IsStd : Boolean) : Integer;
Var
  U   : TString;
  I   : Integer;
  Idx : Integer;
Begin
  U := StrUpperCase(Name);
  { Verifier si deja present }
  For I := 1 To PkgCount Do
    If PkgTab[I].Name = U Then
    Begin AddPkg := I; Exit; End;
  If PkgCount >= MAX_PKG Then
  Begin
    Warning('Table packages pleine, ' + Name + ' ignore');
    AddPkg := 0;
    Exit;
  End;
  Inc(PkgCount);
  Idx := PkgCount;
  PkgTab[Idx].Name       := U;
  PkgTab[Idx].IsStandard := IsStd;
  PkgTab[Idx].UseActive  := False;
  AddPkg := Idx;
End;

{ ---- FindPkg : recherche un package par nom ------------------ }
{ Retourne l index (1-base) ou 0 si non trouve.                   }
Function FindPkg(Const Name : TString) : Integer;
Var
  I : Integer;
  U : TString;
Begin
  U := StrUpperCase(Name);
  For I := 1 To PkgCount Do
    If PkgTab[I].Name = U Then
    Begin FindPkg := I; Exit; End;
  FindPkg := 0;
End;

{ ============================================================ }
{ GESTION DES SCOPES ET PILE DE SCOPES (TODO 06)                }
{ ============================================================ }

{ ---- InitScopeStack : initialiser la pile de scopes ---------- }
{ Le scope global (niveau 0) est toujours present.                }
Procedure InitScopeStack;
Var I : Integer;
Begin
  ScopeTop := 0;
  For I := 0 To MAX_DEPTH Do
  Begin
    ScopeStack[I].Kind      := SK_GLOBAL;
    ScopeStack[I].SubIdx    := 0;
    ScopeStack[I].BpTop     := 0;
    ScopeStack[I].SymStart  := 1;
    ScopeStack[I].LblExit   := '';
    ScopeStack[I].LblCont   := '';
    ScopeStack[I].LblEnd    := '';
    ScopeStack[I].HasExcept := False;
    ScopeStack[I].LblExcept := '';
  End;
  { Scope global }
  ScopeStack[0].Kind     := SK_GLOBAL;
  ScopeStack[0].SubIdx   := 0;
  ScopeStack[0].BpTop    := 0;
  ScopeStack[0].SymStart := 1;
End;

{ ---- PushScope : empiler un nouveau scope -------------------- }
{ Kind = SK_xxx, SubIdx = index dans SubTab (0 si global/bloc).   }
Procedure PushScope(Kind, SubIdx : Integer);
Begin
  If ScopeTop >= MAX_DEPTH Then
  Begin
    Error('Profondeur de scopes depassee (MAX_DEPTH=' +
          IntToStr_(MAX_DEPTH) + ')');
    Exit;
  End;
  Inc(ScopeTop);
  ScopeStack[ScopeTop].Kind      := Kind;
  ScopeStack[ScopeTop].SubIdx    := SubIdx;
  ScopeStack[ScopeTop].BpTop     := 0;  { compte en negatif pour AUTO }
  ScopeStack[ScopeTop].SymStart  := SymCount + 1;
  ScopeStack[ScopeTop].LblExit   := '';
  ScopeStack[ScopeTop].LblCont   := '';
  ScopeStack[ScopeTop].LblEnd    := '';
  ScopeStack[ScopeTop].HasExcept := False;
  ScopeStack[ScopeTop].LblExcept := '';
End;

{ ---- PopScope : depiler le scope courant --------------------- }
{ Libere les symboles locaux du scope.                             }
{ Retourne la taille de frame allouee (valeur absolue).            }
Function PopScope : Integer;
Var Frame, St : Integer;
Begin
  If ScopeTop <= 0 Then
  Begin
    Error('PopScope : pile de scopes deja vide');
    PopScope := 0;
    Exit;
  End;
  Frame := -ScopeStack[ScopeTop].BpTop;  { taille frame locale }
  St    := ScopeStack[ScopeTop].SymStart;
  { Retirer les symboles locaux de ce scope }
  If St >= 1 Then
    SymCount := St - 1;
  Dec(ScopeTop);
  PopScope := Frame;
End;

{ ---- Accesseurs du scope courant ----------------------------- }

{ Retourne le type de scope courant (SK_xxx) }
Function CurrentScope : Integer;
Begin
  CurrentScope := ScopeStack[ScopeTop].Kind;
End;

{ Retourne l index SubTab du scope courant (0 si global) }
Function CurrentSub : Integer;
Begin
  CurrentSub := ScopeStack[ScopeTop].SubIdx;
End;

{ Remonte la pile pour trouver le sous-programme englobant       }
{ (ignore SK_BLOCK/SK_LOOP/SK_EXCEPT qui n ont pas de frame).    }
Function EnclosingSubIdx : Integer;
Var Lev : Integer;
Begin
  Lev := ScopeTop;
  While Lev > 0 Do
  Begin
    If ScopeStack[Lev].Kind In [SK_PROC, SK_FUNC, SK_PACKAGE] Then
    Begin EnclosingSubIdx := ScopeStack[Lev].SubIdx; Exit; End;
    Dec(Lev);
  End;
  EnclosingSubIdx := 0;
End;

{ Taille totale de la frame locale du sous-programme courant     }
{ (en valeur absolue). Remonte la pile pour trouver SK_PROC/FUNC.}
Function CurrentFrameSize : Integer;
Var Lev : Integer;
Begin
  Lev := ScopeTop;
  While Lev > 0 Do
  Begin
    If ScopeStack[Lev].Kind In [SK_PROC, SK_FUNC] Then
    Begin CurrentFrameSize := -ScopeStack[Lev].BpTop; Exit; End;
    Dec(Lev);
  End;
  CurrentFrameSize := 0;
End;

{ Niveau de scope courant (pour SymTab.ScopeLev) }
Function CurrentLevel : Integer;
Begin
  CurrentLevel := ScopeTop;
End;

{ ---- AllocLocal : allouer une variable locale sur la pile ---- }
{ Aligne sur 4 octets (pile 32 bits).                              }
{ Retourne l offset EBP negatif ou 0 si scope global.              }
Function AllocLocal(Size : Integer) : Integer;
Var Aligned : Integer;
Begin
  If ScopeTop <= 0 Then
  Begin AllocLocal := 0; Exit; End;
  Aligned := AlignDWord(Size);
  ScopeStack[ScopeTop].BpTop :=
    ScopeStack[ScopeTop].BpTop - Aligned;
  AllocLocal := ScopeStack[ScopeTop].BpTop;
End;

{ ---- Gestion des labels de boucle et de sortie --------------- }

{ Enregistre les labels de boucle dans le scope courant }
Procedure EnterLoop(Const LblCont_, LblEnd_ : TString);
Begin
  ScopeStack[ScopeTop].LblCont := LblCont_;
  ScopeStack[ScopeTop].LblEnd  := LblEnd_;
End;

{ Retourne le label de continuation de la boucle englobante      }
Function FindLoopCont : TString;
Var Lev : Integer;
Begin
  For Lev := ScopeTop DownTo 1 Do
    If ScopeStack[Lev].LblCont <> '' Then
    Begin FindLoopCont := ScopeStack[Lev].LblCont; Exit; End;
  FindLoopCont := '';
End;

{ Retourne le label de fin de la boucle englobante (pour EXIT)   }
Function FindLoopEnd : TString;
Var Lev : Integer;
Begin
  For Lev := ScopeTop DownTo 1 Do
    If ScopeStack[Lev].LblEnd <> '' Then
    Begin FindLoopEnd := ScopeStack[Lev].LblEnd; Exit; End;
  FindLoopEnd := '';
End;

{ Positionne le label de sortie (RETURN / procedure exit) }
Procedure SetExitLabel(Const Lbl : TString);
Begin
  ScopeStack[ScopeTop].LblExit := Lbl;
End;

{ Retourne le label de sortie du sous-programme courant          }
Function FindExitLabel : TString;
Var Lev : Integer;
Begin
  For Lev := ScopeTop DownTo 1 Do
    If ScopeStack[Lev].LblExit <> '' Then
    Begin FindExitLabel := ScopeStack[Lev].LblExit; Exit; End;
  FindExitLabel := '';
End;

{ ---- Gestion des exceptions --------------------------------- }

{ Positionne le label du handler EXCEPTION dans le scope courant }
Procedure SetExceptLabel(Const Lbl : TString);
Begin
  ScopeStack[ScopeTop].HasExcept := True;
  ScopeStack[ScopeTop].LblExcept := Lbl;
End;

{ Retourne le label du handler EXCEPTION le plus proche          }
Function FindExceptLabel : TString;
Var Lev : Integer;
Begin
  For Lev := ScopeTop DownTo 1 Do
    If ScopeStack[Lev].HasExcept Then
    Begin FindExceptLabel := ScopeStack[Lev].LblExcept; Exit; End;
  FindExceptLabel := '';
End;

{ ============================================================ }
{ GENERATEUR DE CODE BAS NIVEAU 80386 (TODO 07)                 }
{ ============================================================ }

{ ---- InitStrTable : initialiser la table des chaines --------- }
Procedure InitStrTable;
Begin
  StrCount     := 0;
  LabelCounter := 0;
  GenEnabled   := False;
  AsmOpened    := False;
End;

{ ---- Primitives d emission ASM ------------------------------- }

{ Emet une ligne brute dans le fichier de sortie }
Procedure Emit(Const S : TString);
Begin
  If Not GenEnabled Then Exit;
  WriteLn(OutF, S);
End;

{ Emet une instruction indentee (tabulation) }
Procedure EmitI(Const S : TString);
Begin
  If Not GenEnabled Then Exit;
  WriteLn(OutF, #9 + S);
End;

{ Emet un label suivi de ':' }
Procedure EmitLabel(Const Lbl : TString);
Begin
  If Not GenEnabled Then Exit;
  WriteLn(OutF, Lbl + ':');
End;

{ Emet un commentaire ASM }
Procedure EmitComment(Const S : TString);
Begin
  If Not GenEnabled Then Exit;
  WriteLn(OutF, '; ' + S);
End;

{ Emet une ligne vide }
Procedure EmitBlank;
Begin
  If Not GenEnabled Then Exit;
  WriteLn(OutF, '');
End;

{ ---- NewLabel : generer un label interne unique -------------- }
{ Retourne un label de la forme _ADAL_0001 (prefixe _ADAL_)      }
Function NewLabel : TString;
Var N : TString;
Begin
  Inc(LabelCounter);
  N := IntToStr_(LabelCounter);
  While Length(N) < 4 Do
    N := '0' + N;
  NewLabel := ADA_LBL_PFX + N;
End;

{ ---- NewExLabel : generer un label exception unique (TODO 19) -- }
{ Retourne un label de la forme _ADAX_0001 (prefixe _ADAX_)        }
Function NewExLabel : TString;
Var N : TString;
Begin
  Inc(LabelCounter);
  N := IntToStr_(LabelCounter);
  While Length(N) < 4 Do
    N := '0' + N;
  NewExLabel := ADA_EX_PFX + N;
End;

{ ---- AsmStrLit : ajouter un litteral chaine ------------------- }
{ Deduplication : si la chaine existe deja, retourne son label.    }
{ Sinon, l ajoute et retourne un nouveau label _ADAK_n.            }
Function AsmStrLit(Const S : TString) : TString;
Var
  I  : Integer;
  Lb : TString;
Begin
  { Deduplication }
  For I := 1 To StrCount Do
    If StrTab[I] = S Then
    Begin AsmStrLit := StrLblTab[I]; Exit; End;
  { Ajout nouveau }
  If StrCount >= MAX_DATA Then
  Begin
    Error('Table des chaines pleine (MAX_DATA=' +
          IntToStr_(MAX_DATA) + ')');
    AsmStrLit := ADA_STR_PFX + '0';
    Exit;
  End;
  Inc(StrCount);
  Lb := ADA_STR_PFX + IntToStr_(StrCount);
  StrTab[StrCount]    := S;
  StrLblTab[StrCount] := Lb;
  AsmStrLit := Lb;
End;

{ ---- EmitStringLiterals : emettre les litteraux dans .DATA --- }
{ Genere les DB pour chaque litteral chaine accumule.              }
Procedure EmitStringLiterals;
Var
  I, J : Integer;
  S    : TString;
Begin
  If StrCount = 0 Then Exit;
  EmitComment('--- litteraux chaines ---');
  For I := 1 To StrCount Do
  Begin
    S := StrTab[I];
    If Length(S) > 0 Then
    Begin
      Emit(StrLblTab[I] + ' DB ' + IntToStr_(Ord(S[1])));
      For J := 2 To Length(S) Do
        EmitI('DB ' + IntToStr_(Ord(S[J])));
    End
    Else
      Emit(StrLblTab[I] + ' DB 0');
    EmitI('DB 0');  { terminateur null }
  End;
End;

{ ============================================================ }
{ TODO 23 - GENERATION EN-TETE ASSEMBLEUR 80386 ET SEGMENT .DATA }
{ ============================================================ }

{ ---- EmitOpen : ouvrir le fichier de sortie .ASM ------------- }
{ Cree le fichier .ASM et active la generation de code.           }
Procedure EmitOpen(Const FileName : TString);
Begin
  Assign(OutF, FileName);
  Rewrite(OutF);
  OutFOpen   := True;
  GenEnabled := True;
End;

{ ---- EmitClose : fermer le fichier de sortie .ASM ------------ }
{ Desactive la generation de code et ferme le fichier.            }
Procedure EmitClose;
Begin
  If OutFOpen Then
  Begin
    GenEnabled := False;
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ---- EmitHeader : emettre l en-tete ASM 80386 MASM ---------- }
{ Genere les directives processeur, modele memoire, imports       }
{ Win32 et debut du segment de code.                              }
Procedure EmitHeader;
Var I : Integer;
Begin
  EmitComment('Generated by ADACW32 v' + ADACW32_VERSION +
              ' (' + ADACW32_DATE + ')');
  EmitComment('Source : ' + Opts.SrcFile);
  EmitBlank;
  Emit('.386');
  Emit('.MODEL FLAT, STDCALL');
  Emit('OPTION CASEMAP:NONE');
  EmitBlank;
  EmitComment('--- Imports Win32 (kernel32.dll) ---');
  For I := 0 To PE_NUM_API - 1 Do
    Emit('EXTRN ' + BinAPIDecorated[I] + ':NEAR');
  EmitBlank;
  Emit('.STACK 4096');
  EmitBlank;
  EmitComment('--- Segment de code ---');
  Emit('_TEXT SEGMENT DWORD PUBLIC ''CODE''');
  Emit('ASSUME CS:_TEXT');
  EmitBlank;
End;

{ ---- EmitDataSeg : emettre le segment .DATA ------------------- }
{ Genere les definitions de variables globales, tableaux, records,  }
{ litteraux chaines et tampons runtime.                             }
Procedure EmitDataSeg;
Var
  I    : Integer;
  Lbl  : TString;
  TI   : Integer;
  TSz  : Integer;
Begin
  EmitBlank;
  Emit('_TEXT ENDS');
  EmitBlank;
  EmitComment('--- Segment de donnees ---');
  Emit('_DATA SEGMENT DWORD PUBLIC ''DATA''');
  EmitBlank;

  { --- Variables globales (STORE_STATIC) --- }
  EmitComment('--- variables globales ---');
  For I := 1 To SymCount Do
  Begin
    If SymTab[I].StoreClass = STORE_STATIC Then
    Begin
      Lbl := SymTab[I].AsmLabel;
      TI  := SymTab[I].TypeIdx;
      If SymTab[I].ArraySize > 0 Then
      Begin
        { Tableau : DB total_bytes DUP(0) }
        TSz := SymTab[I].ArraySize;
        If TSz < 4 Then TSz := 4;
        EmitI(Lbl + ' DB ' + IntToStr_(TSz) + ' DUP(0)');
      End
      Else If TI = TYPE_FLOAT Then
      Begin
        { Float 64 bits : DQ 0 }
        EmitI(Lbl + ' DQ 0');
      End
      Else If (TI = TYPE_BOOL) Or (TI = TYPE_CHAR) Then
      Begin
        { Boolean / Character : DB 0 }
        If SymTab[I].HasInit Then
          EmitI(Lbl + ' DB ' + IntToStr_(SymTab[I].InitNum))
        Else
          EmitI(Lbl + ' DB 0');
      End
      Else If TI > TYPE_STR Then
      Begin
        { Type utilisateur : verifier si RECORD ou ARRAY dans TypeTab }
        If (TI <= TypeCount) And (TypeTab[TI].TotalSize > 0) Then
          EmitI(Lbl + ' DB ' + IntToStr_(TypeTab[TI].TotalSize) +
                ' DUP(0)')
        Else
        Begin
          If SymTab[I].HasInit Then
            EmitI(Lbl + ' DD ' + IntToStr_(SymTab[I].InitNum))
          Else
            EmitI(Lbl + ' DD 0');
        End;
      End
      Else
      Begin
        { Integer, String(ptr) et autres : DD }
        If SymTab[I].HasInit Then
          EmitI(Lbl + ' DD ' + IntToStr_(SymTab[I].InitNum))
        Else
          EmitI(Lbl + ' DD 0');
      End;
    End;
  End;
  EmitBlank;

  { --- Litteraux chaines --- }
  EmitStringLiterals;
  EmitBlank;

  { --- Tampons runtime --- }
  EmitComment('--- tampons et variables runtime ---');
  EmitI(ADA_RT_PFX + 'NUMBUF    DB 16 DUP(0)');
  EmitI(ADA_RT_PFX + 'STRBUF    DB 256 DUP(0)');
  EmitI(ADA_RT_PFX + 'INPUTBUF  DB 256 DUP(0)');
  EmitI(ADA_RT_PFX + 'CRLF_DATA DB 13, 10, 0');
  EmitI(ADA_RT_PFX + 'HSTDOUT   DD 0');
  EmitI(ADA_RT_PFX + 'HSTDIN    DD 0');
  EmitI(ADA_RT_PFX + 'WRITTEN   DD 0');
  EmitI(ADA_RT_PFX + 'READCNT   DD 0');
  EmitI(ADA_RT_PFX + 'CUREXC    DD 0');
  EmitBlank;

  { --- Messages d erreur runtime (TODO 24) --- }
  EmitComment('--- messages d''erreur runtime ---');
  EmitI(ADA_RT_PFX + 'ERR_RANGE DB ''Constraint_Error: valeur hors bornes'', 0');
  EmitI(ADA_RT_PFX + 'ERR_PROG  DB ''Program_Error: erreur programme'', 0');
  EmitBlank;

  Emit('_DATA ENDS');
  EmitBlank;
End;

{ ============================================================ }
{ TODO 24 - GENERATION : POINT D'ENTREE WIN32 ET HELPERS RUNTIME }
{ ============================================================ }

{ ---- EmitEntryPoint : emettre le point d entree Win32 -------- }
{ Genere _ADAF_main :                                              }
{   PUSH EBP / MOV EBP, ESP                                       }
{   Initialiser stdout : PUSH -11 / CALL GetStdHandle              }
{   Initialiser stdin  : PUSH -10 / CALL GetStdHandle              }
{   CALL _ADAF_nom_procedure (procedure principale Ada)            }
{   PUSH 0 / CALL ExitProcess                                     }
Procedure EmitEntryPoint;
Var
  MainLabel : TString;
Begin
  EmitBlank;
  EmitComment('========================================');
  EmitComment('Point d''entree Win32');
  EmitComment('========================================');
  EmitBlank;
  EmitLabel(ADA_FN_PFX + 'main');
  EmitI('PUSH EBP');
  EmitI('MOV  EBP, ESP');
  EmitBlank;
  { Initialiser stdout : GetStdHandle(STD_OUTPUT_HANDLE = -11) }
  EmitComment('Initialiser stdout');
  EmitI('PUSH -11');
  EmitI('CALL _GetStdHandle@4');
  EmitI('MOV  DWORD PTR [' + ADA_RT_PFX + 'HSTDOUT], EAX');
  EmitBlank;
  { Initialiser stdin : GetStdHandle(STD_INPUT_HANDLE = -10) }
  EmitComment('Initialiser stdin');
  EmitI('PUSH -10');
  EmitI('CALL _GetStdHandle@4');
  EmitI('MOV  DWORD PTR [' + ADA_RT_PFX + 'HSTDIN], EAX');
  EmitBlank;
  { Appeler la procedure principale Ada }
  If MainProcName <> '' Then
  Begin
    MainLabel := ADA_FN_PFX + AsmIdent(StrUpperCase(MainProcName));
    EmitComment('Appel de la procedure principale : ' + MainProcName);
    EmitI('CALL ' + MainLabel);
  End
  Else
    EmitComment('(aucune procedure principale detectee)');
  EmitBlank;
  { ExitProcess(0) }
  EmitComment('Terminer le processus');
  EmitI('PUSH 0');
  EmitI('CALL _ExitProcess@4');
  EmitBlank;
End;

{ ---- EmitRuntimeHelpers : emettre les helpers runtime --------- }
{ Genere les sous-programmes runtime :                              }
{   _ADART_CRLF      : ecrire CR+LF via WriteFile                 }
{   _ADART_PRINT     : EAX=ptr ASCIIZ -> WriteFile(hStdOut)        }
{   _ADART_NUMTOSTR  : EAX=entier -> ASCIIZ dans _ADART_NUMBUF    }
{   _ADART_PRINTINT  : EAX=entier -> NUMTOSTR + PRINT             }
{   _ADART_PRINTCHR  : AL=caractere -> WriteFile 1 octet           }
{   _ADART_READINT   : ReadFile + parsing ASCII -> EAX             }
{   _ADART_READSTR   : ReadFile -> copier dans buffer              }
{   _ADART_STRLEN    : EAX=ptr ASCIIZ -> EAX=longueur             }
{   _ADART_STRCOPY   : ESI=src, EDI=dst, ECX=max -> copie         }
{   _ADART_STRCONCAT : coller ESI apres EDI (ASCIIZ)              }
{   _ADART_CHKRANGE  : verifier borne, sinon Constraint_Error     }
{   _ADART_ERROR     : afficher message + ExitProcess(1)           }
Procedure EmitRuntimeHelpers;
Var
  LblDone, LblLoop, LblNeg, LblConv, LblDig  : TString;
  LblNotZero, LblReverse, LblRevDone          : TString;
  LblReadLoop, LblReadDone, LblReadSkip       : TString;
  LblCopyLoop, LblCatFnd, LblCatLoop          : TString;
  LblOk, LblErr                               : TString;
Begin
  EmitBlank;
  EmitComment('========================================');
  EmitComment('Helpers runtime ADACW32');
  EmitComment('========================================');

  { ---- _ADART_CRLF : ecrire CR+LF ---- }
  EmitBlank;
  EmitComment('--- _ADART_CRLF : ecrire CR+LF ---');
  EmitLabel(ADA_RT_PFX + 'CRLF');
  EmitI('PUSH EBP');
  EmitI('MOV  EBP, ESP');
  EmitI('SUB  ESP, 4');
  { WriteFile(hStdOut, @CRLF_DATA, 2, @written, 0) }
  EmitI('PUSH 0');
  EmitI('LEA  EAX, DWORD PTR [' + ADA_RT_PFX + 'WRITTEN]');
  EmitI('PUSH EAX');
  EmitI('PUSH 2');
  EmitI('LEA  EAX, DWORD PTR [' + ADA_RT_PFX + 'CRLF_DATA]');
  EmitI('PUSH EAX');
  EmitI('PUSH DWORD PTR [' + ADA_RT_PFX + 'HSTDOUT]');
  EmitI('CALL _WriteFile@20');
  EmitI('MOV  ESP, EBP');
  EmitI('POP  EBP');
  EmitI('RET');

  { ---- _ADART_PRINT : EAX=ptr ASCIIZ -> WriteFile ---- }
  EmitBlank;
  EmitComment('--- _ADART_PRINT : afficher chaine ASCIIZ ---');
  EmitComment('Entree : [ESP+4] = pointeur vers chaine ASCIIZ');
  EmitLabel(ADA_RT_PFX + 'PRINT');
  EmitI('PUSH EBP');
  EmitI('MOV  EBP, ESP');
  EmitI('PUSH ESI');
  EmitI('PUSH EDI');
  { Calculer la longueur de la chaine (strlen) }
  EmitI('MOV  ESI, DWORD PTR [EBP+8]');
  EmitI('XOR  ECX, ECX');
  LblLoop := NewLabel;
  LblDone := NewLabel;
  EmitLabel(LblLoop);
  EmitI('CMP  BYTE PTR [ESI+ECX], 0');
  EmitI('JE   ' + LblDone);
  EmitI('INC  ECX');
  EmitI('JMP  ' + LblLoop);
  EmitLabel(LblDone);
  { ECX = longueur. WriteFile(hStdOut, ESI, ECX, @written, 0) }
  EmitI('PUSH 0');
  EmitI('LEA  EAX, DWORD PTR [' + ADA_RT_PFX + 'WRITTEN]');
  EmitI('PUSH EAX');
  EmitI('PUSH ECX');
  EmitI('PUSH ESI');
  EmitI('PUSH DWORD PTR [' + ADA_RT_PFX + 'HSTDOUT]');
  EmitI('CALL _WriteFile@20');
  EmitI('POP  EDI');
  EmitI('POP  ESI');
  EmitI('POP  EBP');
  EmitI('RET  4');

  { ---- _ADART_NUMTOSTR : EAX=entier -> ASCIIZ dans NUMBUF ---- }
  EmitBlank;
  EmitComment('--- _ADART_NUMTOSTR : entier -> ASCIIZ ---');
  EmitComment('Entree : EAX = entier signe 32 bits');
  EmitComment('Sortie : EAX = pointeur vers _ADART_NUMBUF (ASCIIZ)');
  EmitLabel(ADA_RT_PFX + 'NUMTOSTR');
  EmitI('PUSH EBP');
  EmitI('MOV  EBP, ESP');
  EmitI('PUSH EBX');
  EmitI('PUSH ESI');
  EmitI('PUSH EDI');
  EmitI('MOV  ESI, EAX');           { ESI = valeur originale }
  EmitI('LEA  EDI, DWORD PTR [' + ADA_RT_PFX + 'NUMBUF]');
  { Gerer le signe negatif }
  LblNeg := NewLabel;
  LblConv := NewLabel;
  EmitI('TEST EAX, EAX');
  EmitI('JNS  ' + LblConv);
  { Negatif : stocker '-' et negation }
  EmitI('MOV  BYTE PTR [EDI], 45');  { '-' = 45 }
  EmitI('INC  EDI');
  EmitI('NEG  EAX');
  EmitLabel(LblConv);
  { Convertir EAX en digits decimaux (ordre inverse) }
  EmitI('XOR  ECX, ECX');           { compteur de digits }
  EmitI('MOV  EBX, 10');
  LblDig := NewLabel;
  LblNotZero := NewLabel;
  EmitI('TEST EAX, EAX');
  EmitI('JNZ  ' + LblDig);
  { Cas special : valeur = 0 }
  EmitI('MOV  BYTE PTR [EDI], 48');  { '0' = 48 }
  EmitI('MOV  BYTE PTR [EDI+1], 0');
  EmitI('JMP  ' + LblNotZero);
  EmitLabel(LblDig);
  { Boucle de division : EAX / 10, push le reste }
  EmitI('XOR  EDX, EDX');
  EmitI('DIV  EBX');                 { EAX = quotient, EDX = reste }
  EmitI('ADD  DL, 48');              { reste + '0' }
  EmitI('PUSH EDX');                 { empiler le digit }
  EmitI('INC  ECX');
  EmitI('TEST EAX, EAX');
  EmitI('JNZ  ' + LblDig);
  { Depiler les digits dans l ordre correct }
  LblReverse := NewLabel;
  LblRevDone := NewLabel;
  EmitLabel(LblReverse);
  EmitI('TEST ECX, ECX');
  EmitI('JZ   ' + LblRevDone);
  EmitI('POP  EAX');
  EmitI('MOV  BYTE PTR [EDI], AL');
  EmitI('INC  EDI');
  EmitI('DEC  ECX');
  EmitI('JMP  ' + LblReverse);
  EmitLabel(LblRevDone);
  { Terminer la chaine }
  EmitI('MOV  BYTE PTR [EDI], 0');
  EmitLabel(LblNotZero);
  { Retourner le pointeur vers NUMBUF }
  EmitI('LEA  EAX, DWORD PTR [' + ADA_RT_PFX + 'NUMBUF]');
  EmitI('POP  EDI');
  EmitI('POP  ESI');
  EmitI('POP  EBX');
  EmitI('POP  EBP');
  EmitI('RET');

  { ---- _ADART_PRINTINT : EAX=entier -> NUMTOSTR + PRINT ---- }
  EmitBlank;
  EmitComment('--- _ADART_PRINTINT : afficher entier ---');
  EmitComment('Entree : [ESP+4] = entier signe 32 bits');
  EmitLabel(ADA_RT_PFX + 'PRINTINT');
  EmitI('PUSH EBP');
  EmitI('MOV  EBP, ESP');
  EmitI('MOV  EAX, DWORD PTR [EBP+8]');
  EmitI('CALL ' + ADA_RT_PFX + 'NUMTOSTR');
  EmitI('PUSH EAX');
  EmitI('CALL ' + ADA_RT_PFX + 'PRINT');
  EmitI('POP  EBP');
  EmitI('RET  4');

  { ---- _ADART_PRINTCHR : AL=caractere -> WriteFile 1 octet ---- }
  EmitBlank;
  EmitComment('--- _ADART_PRINTCHR : afficher un caractere ---');
  EmitComment('Entree : [ESP+4] = caractere (octet bas)');
  EmitLabel(ADA_RT_PFX + 'PRINTCHR');
  EmitI('PUSH EBP');
  EmitI('MOV  EBP, ESP');
  EmitI('SUB  ESP, 4');
  EmitI('MOV  EAX, DWORD PTR [EBP+8]');
  EmitI('MOV  BYTE PTR [EBP-4], AL');
  { WriteFile(hStdOut, @[EBP-4], 1, @written, 0) }
  EmitI('PUSH 0');
  EmitI('LEA  EAX, DWORD PTR [' + ADA_RT_PFX + 'WRITTEN]');
  EmitI('PUSH EAX');
  EmitI('PUSH 1');
  EmitI('LEA  EAX, DWORD PTR [EBP-4]');
  EmitI('PUSH EAX');
  EmitI('PUSH DWORD PTR [' + ADA_RT_PFX + 'HSTDOUT]');
  EmitI('CALL _WriteFile@20');
  EmitI('MOV  ESP, EBP');
  EmitI('POP  EBP');
  EmitI('RET  4');

  { ---- _ADART_READINT : lire un entier depuis stdin ---- }
  EmitBlank;
  EmitComment('--- _ADART_READINT : lire entier depuis stdin ---');
  EmitComment('Sortie : EAX = entier lu');
  EmitLabel(ADA_RT_PFX + 'READINT');
  EmitI('PUSH EBP');
  EmitI('MOV  EBP, ESP');
  EmitI('PUSH EBX');
  EmitI('PUSH ESI');
  { ReadFile(hStdIn, @INPUTBUF, 255, @READCNT, 0) }
  EmitI('PUSH 0');
  EmitI('LEA  EAX, DWORD PTR [' + ADA_RT_PFX + 'READCNT]');
  EmitI('PUSH EAX');
  EmitI('PUSH 255');
  EmitI('LEA  EAX, DWORD PTR [' + ADA_RT_PFX + 'INPUTBUF]');
  EmitI('PUSH EAX');
  EmitI('PUSH DWORD PTR [' + ADA_RT_PFX + 'HSTDIN]');
  EmitI('CALL _ReadFile@20');
  { Parser l ASCII : sauter espaces, lire digits, gerer signe }
  EmitI('LEA  ESI, DWORD PTR [' + ADA_RT_PFX + 'INPUTBUF]');
  EmitI('XOR  EAX, EAX');           { resultat }
  EmitI('XOR  EBX, EBX');           { flag negatif }
  { Sauter les espaces/CR/LF de tete }
  LblReadSkip := NewLabel;
  LblReadLoop := NewLabel;
  LblReadDone := NewLabel;
  EmitLabel(LblReadSkip);
  EmitI('MOVZX ECX, BYTE PTR [ESI]');
  EmitI('CMP  ECX, 32');             { espace }
  EmitI('JE   ' + LblReadSkip + '_NEXT');
  EmitI('CMP  ECX, 9');              { tab }
  EmitI('JE   ' + LblReadSkip + '_NEXT');
  EmitI('CMP  ECX, 13');             { CR }
  EmitI('JE   ' + LblReadSkip + '_NEXT');
  EmitI('CMP  ECX, 10');             { LF }
  EmitI('JNE  ' + LblReadLoop);
  EmitLabel(LblReadSkip + '_NEXT');
  EmitI('INC  ESI');
  EmitI('JMP  ' + LblReadSkip);
  { Verifier le signe }
  EmitLabel(LblReadLoop);
  EmitI('CMP  BYTE PTR [ESI], 45'); { '-' }
  LblNeg := NewLabel;
  EmitI('JNE  ' + LblNeg);
  EmitI('MOV  EBX, 1');
  EmitI('INC  ESI');
  EmitLabel(LblNeg);
  { Boucle de lecture des digits }
  LblDig := NewLabel;
  EmitLabel(LblDig);
  EmitI('MOVZX ECX, BYTE PTR [ESI]');
  EmitI('CMP  ECX, 48');            { '0' }
  EmitI('JB   ' + LblReadDone);
  EmitI('CMP  ECX, 57');            { '9' }
  EmitI('JA   ' + LblReadDone);
  EmitI('SUB  ECX, 48');
  EmitI('IMUL EAX, EAX, 10');
  EmitI('ADD  EAX, ECX');
  EmitI('INC  ESI');
  EmitI('JMP  ' + LblDig);
  EmitLabel(LblReadDone);
  { Appliquer le signe }
  EmitI('TEST EBX, EBX');
  LblOk := NewLabel;
  EmitI('JZ   ' + LblOk);
  EmitI('NEG  EAX');
  EmitLabel(LblOk);
  EmitI('POP  ESI');
  EmitI('POP  EBX');
  EmitI('POP  EBP');
  EmitI('RET');

  { ---- _ADART_READSTR : lire chaine depuis stdin ---- }
  EmitBlank;
  EmitComment('--- _ADART_READSTR : lire chaine depuis stdin ---');
  EmitComment('Entree : EAX = pointeur vers buffer destination');
  EmitComment('Sortie : chaine ASCIIZ dans le buffer');
  EmitLabel(ADA_RT_PFX + 'READSTR');
  EmitI('PUSH EBP');
  EmitI('MOV  EBP, ESP');
  EmitI('PUSH ESI');
  EmitI('PUSH EDI');
  EmitI('MOV  EDI, EAX');           { EDI = buffer destination }
  { ReadFile(hStdIn, @INPUTBUF, 255, @READCNT, 0) }
  EmitI('PUSH 0');
  EmitI('LEA  EAX, DWORD PTR [' + ADA_RT_PFX + 'READCNT]');
  EmitI('PUSH EAX');
  EmitI('PUSH 255');
  EmitI('LEA  EAX, DWORD PTR [' + ADA_RT_PFX + 'INPUTBUF]');
  EmitI('PUSH EAX');
  EmitI('PUSH DWORD PTR [' + ADA_RT_PFX + 'HSTDIN]');
  EmitI('CALL _ReadFile@20');
  { Copier INPUTBUF vers EDI, retirer CR/LF }
  EmitI('LEA  ESI, DWORD PTR [' + ADA_RT_PFX + 'INPUTBUF]');
  EmitI('MOV  ECX, DWORD PTR [' + ADA_RT_PFX + 'READCNT]');
  LblCopyLoop := NewLabel;
  LblDone := NewLabel;
  EmitLabel(LblCopyLoop);
  EmitI('TEST ECX, ECX');
  EmitI('JZ   ' + LblDone);
  EmitI('LODSB');                    { AL = [ESI], ESI++ }
  EmitI('CMP  AL, 13');             { CR ? }
  EmitI('JE   ' + LblDone);
  EmitI('CMP  AL, 10');             { LF ? }
  EmitI('JE   ' + LblDone);
  EmitI('STOSB');                    { [EDI] = AL, EDI++ }
  EmitI('DEC  ECX');
  EmitI('JMP  ' + LblCopyLoop);
  EmitLabel(LblDone);
  EmitI('MOV  BYTE PTR [EDI], 0');  { terminateur NUL }
  EmitI('POP  EDI');
  EmitI('POP  ESI');
  EmitI('POP  EBP');
  EmitI('RET');

  { ---- _ADART_STRLEN : longueur d une chaine ASCIIZ ---- }
  EmitBlank;
  EmitComment('--- _ADART_STRLEN : longueur chaine ASCIIZ ---');
  EmitComment('Entree : EAX = pointeur vers chaine ASCIIZ');
  EmitComment('Sortie : EAX = longueur');
  EmitLabel(ADA_RT_PFX + 'STRLEN');
  EmitI('PUSH ESI');
  EmitI('MOV  ESI, EAX');
  EmitI('XOR  EAX, EAX');
  LblLoop := NewLabel;
  LblDone := NewLabel;
  EmitLabel(LblLoop);
  EmitI('CMP  BYTE PTR [ESI], 0');
  EmitI('JE   ' + LblDone);
  EmitI('INC  ESI');
  EmitI('INC  EAX');
  EmitI('JMP  ' + LblLoop);
  EmitLabel(LblDone);
  EmitI('POP  ESI');
  EmitI('RET');

  { ---- _ADART_STRCOPY : copier chaine ASCIIZ ---- }
  EmitBlank;
  EmitComment('--- _ADART_STRCOPY : copier chaine ---');
  EmitComment('Entree : ESI=src, EDI=dst, ECX=max octets');
  EmitLabel(ADA_RT_PFX + 'STRCOPY');
  EmitI('PUSH EBX');
  LblLoop := NewLabel;
  LblDone := NewLabel;
  EmitLabel(LblLoop);
  EmitI('TEST ECX, ECX');
  EmitI('JZ   ' + LblDone);
  EmitI('LODSB');
  EmitI('STOSB');
  EmitI('TEST AL, AL');
  EmitI('JZ   ' + LblDone);
  EmitI('DEC  ECX');
  EmitI('JMP  ' + LblLoop);
  EmitLabel(LblDone);
  EmitI('POP  EBX');
  EmitI('RET');

  { ---- _ADART_STRCONCAT : concatener chaine ASCIIZ ---- }
  EmitBlank;
  EmitComment('--- _ADART_STRCONCAT : concatener ESI apres EDI ---');
  EmitComment('Entree : ESI=src, EDI=dst (ASCIIZ)');
  EmitLabel(ADA_RT_PFX + 'STRCONCAT');
  { Trouver la fin de EDI (destination) }
  LblCatFnd := NewLabel;
  LblCatLoop := NewLabel;
  LblDone := NewLabel;
  EmitLabel(LblCatFnd);
  EmitI('CMP  BYTE PTR [EDI], 0');
  EmitI('JE   ' + LblCatLoop);
  EmitI('INC  EDI');
  EmitI('JMP  ' + LblCatFnd);
  { Copier ESI vers EDI }
  EmitLabel(LblCatLoop);
  EmitI('LODSB');
  EmitI('STOSB');
  EmitI('TEST AL, AL');
  EmitI('JNZ  ' + LblCatLoop);
  EmitI('RET');

  { ---- _ADART_CHKRANGE : verifier bornes ---- }
  EmitBlank;
  EmitComment('--- _ADART_CHKRANGE : verifier borne ---');
  EmitComment('Entree : EAX=valeur, EBX=borne_min, ECX=borne_max');
  EmitComment('Si hors bornes : Constraint_Error');
  EmitLabel(ADA_RT_PFX + 'CHKRANGE');
  LblOk := NewLabel;
  LblErr := NewLabel;
  EmitI('CMP  EAX, EBX');
  EmitI('JL   ' + LblErr);
  EmitI('CMP  EAX, ECX');
  EmitI('JG   ' + LblErr);
  EmitI('RET');
  EmitLabel(LblErr);
  { Emettre un message d erreur et terminer }
  EmitI('PUSH OFFSET ' + ADA_RT_PFX + 'ERR_RANGE');
  EmitI('CALL ' + ADA_RT_PFX + 'ERROR');

  { ---- _ADART_ERROR : afficher message + ExitProcess(1) ---- }
  EmitBlank;
  EmitComment('--- _ADART_ERROR : erreur fatale + exit ---');
  EmitComment('Entree : [ESP+4] = pointeur vers message ASCIIZ');
  EmitLabel(ADA_RT_PFX + 'ERROR');
  EmitI('PUSH EBP');
  EmitI('MOV  EBP, ESP');
  EmitI('MOV  EAX, DWORD PTR [EBP+8]');
  EmitI('PUSH EAX');
  EmitI('CALL ' + ADA_RT_PFX + 'PRINT');
  EmitI('CALL ' + ADA_RT_PFX + 'CRLF');
  EmitI('PUSH 1');
  EmitI('CALL _ExitProcess@4');

  { ---- _ADART_GET : lire un caractere depuis stdin ---- }
  EmitBlank;
  EmitComment('--- _ADART_GET : lire un caractere ---');
  EmitComment('Entree : [ESP+4] = pointeur vers variable Character');
  EmitLabel(ADA_RT_PFX + 'GET');
  EmitI('PUSH EBP');
  EmitI('MOV  EBP, ESP');
  EmitI('PUSH EBX');
  EmitI('MOV  EBX, DWORD PTR [EBP+8]'); { EBX = ptr destination }
  { ReadFile(hStdIn, @INPUTBUF, 1, @READCNT, 0) }
  EmitI('PUSH 0');
  EmitI('LEA  EAX, DWORD PTR [' + ADA_RT_PFX + 'READCNT]');
  EmitI('PUSH EAX');
  EmitI('PUSH 1');
  EmitI('LEA  EAX, DWORD PTR [' + ADA_RT_PFX + 'INPUTBUF]');
  EmitI('PUSH EAX');
  EmitI('PUSH DWORD PTR [' + ADA_RT_PFX + 'HSTDIN]');
  EmitI('CALL _ReadFile@20');
  EmitI('MOVZX EAX, BYTE PTR [' + ADA_RT_PFX + 'INPUTBUF]');
  EmitI('MOV  BYTE PTR [EBX], AL');
  EmitI('POP  EBX');
  EmitI('POP  EBP');
  EmitI('RET  4');

  { ---- _ADART_GET_LINE : lire une ligne depuis stdin ---- }
  EmitBlank;
  EmitComment('--- _ADART_GET_LINE : lire une ligne ---');
  EmitComment('Entree : [ESP+4]=ptr buffer, [ESP+8]=ptr Last');
  EmitLabel(ADA_RT_PFX + 'GET_LINE');
  EmitI('PUSH EBP');
  EmitI('MOV  EBP, ESP');
  EmitI('MOV  EAX, DWORD PTR [EBP+8]'); { buffer destination }
  EmitI('CALL ' + ADA_RT_PFX + 'READSTR');
  { Stocker la longueur dans Last }
  EmitI('CALL ' + ADA_RT_PFX + 'STRLEN');
  EmitI('MOV  EBX, DWORD PTR [EBP+12]');
  EmitI('MOV  DWORD PTR [EBX], EAX');
  EmitI('POP  EBP');
  EmitI('RET  8');

  EmitBlank;
End;

{ ---- BpOff32 : formater un offset EBP en chaine -------------- }
{ Produit : -4 -> '-4'   +8 -> '+8'   0 -> ''                     }
Function BpOff32(Off : Integer) : TString;
Begin
  If Off < 0 Then BpOff32 := IntToStr_(Off)
  Else If Off > 0 Then BpOff32 := '+' + IntToStr_(Off)
  Else BpOff32 := '';
End;

{ ---- GenLoadVar : charger un symbole dans EAX ---------------- }
{ STORE_STATIC -> MOV EAX, DWORD PTR [_ADA_x]                     }
{ STORE_AUTO   -> MOV EAX, DWORD PTR [EBP-n]                      }
{ STORE_PARAM  -> MOV EAX, DWORD PTR [EBP+n]                      }
{ TYPE_CHAR / TYPE_BOOL -> MOVZX EAX, BYTE PTR [...]              }
Procedure GenLoadVar(SymIdx : Integer);
Var
  SC, Off, TI : Integer;
  Lbl         : TString;
  IsByte      : Boolean;
Begin
  SC  := SymTab[SymIdx].StoreClass;
  Off := SymTab[SymIdx].BpOffset;
  Lbl := SymTab[SymIdx].AsmLabel;
  TI  := SymTab[SymIdx].TypeIdx;
  IsByte := (TI = TYPE_CHAR) Or (TI = TYPE_BOOL);

  If SymTab[SymIdx].IsConst Then
  Begin
    { Constante : valeur immediate }
    EmitI('MOV EAX, ' + IntToStr_(SymTab[SymIdx].InitNum));
    Exit;
  End;

  Case SC Of
    STORE_STATIC :
    Begin
      If IsByte Then
        EmitI('MOVZX EAX, BYTE PTR [' + Lbl + ']')
      Else
        EmitI('MOV EAX, DWORD PTR [' + Lbl + ']');
    End;
    STORE_AUTO :
    Begin
      If IsByte Then
        EmitI('MOVZX EAX, BYTE PTR [EBP' + BpOff32(Off) + ']')
      Else
        EmitI('MOV EAX, DWORD PTR [EBP' + BpOff32(Off) + ']');
    End;
    STORE_PARAM :
    Begin
      If IsByte Then
        EmitI('MOVZX EAX, BYTE PTR [EBP' + BpOff32(Off) + ']')
      Else
        EmitI('MOV EAX, DWORD PTR [EBP' + BpOff32(Off) + ']');
    End;
    STORE_CONST :
      EmitI('MOV EAX, ' + IntToStr_(SymTab[SymIdx].InitNum));
  End;
End;

{ ---- GenStoreVar : stocker EAX dans un symbole --------------- }
{ MOV DWORD PTR [...], EAX  ou  MOV BYTE PTR [...], AL            }
Procedure GenStoreVar(SymIdx : Integer);
Var
  SC, Off, TI : Integer;
  Lbl         : TString;
  IsByte      : Boolean;
Begin
  If SymTab[SymIdx].IsConst Then
  Begin
    Error('Tentative d''assignation a une constante : ' +
          SymTab[SymIdx].Name);
    Exit;
  End;

  SC  := SymTab[SymIdx].StoreClass;
  Off := SymTab[SymIdx].BpOffset;
  Lbl := SymTab[SymIdx].AsmLabel;
  TI  := SymTab[SymIdx].TypeIdx;
  IsByte := (TI = TYPE_CHAR) Or (TI = TYPE_BOOL);

  Case SC Of
    STORE_STATIC :
    Begin
      If IsByte Then
        EmitI('MOV BYTE PTR [' + Lbl + '], AL')
      Else
        EmitI('MOV DWORD PTR [' + Lbl + '], EAX');
    End;
    STORE_AUTO :
    Begin
      If IsByte Then
        EmitI('MOV BYTE PTR [EBP' + BpOff32(Off) + '], AL')
      Else
        EmitI('MOV DWORD PTR [EBP' + BpOff32(Off) + '], EAX');
    End;
    STORE_PARAM :
    Begin
      If IsByte Then
        EmitI('MOV BYTE PTR [EBP' + BpOff32(Off) + '], AL')
      Else
        EmitI('MOV DWORD PTR [EBP' + BpOff32(Off) + '], EAX');
    End;
  End;
End;

{ ============================================================ }
{ TODO 20 - PARSEUR : OPERATIONS SUR TABLEAUX (32 BITS)         }
{ ============================================================ }

{ ---- GenLoadElement : charger un element de tableau dans EAX - }
{ Index deja dans EAX. Calcule base + (index-lo)*elemsize.       }
{ Resultat : valeur de l element dans EAX.                        }
Procedure GenLoadElement(SymIdx : Integer);
Var
  SC, Off, TI : Integer;
  Lbl         : TString;
  Lo, ESz     : LongInt;
  IsByte      : Boolean;
Begin
  SC  := SymTab[SymIdx].StoreClass;
  Off := SymTab[SymIdx].BpOffset;
  Lbl := SymTab[SymIdx].AsmLabel;
  TI  := SymTab[SymIdx].TypeIdx;
  Lo  := 0;
  ESz := 4;
  IsByte := False;
  If (TI > TYPE_STR) And (TI <= TypeCount) Then
  Begin
    Lo  := TypeTab[TI].LoBound;
    ESz := TypeTab[TI].ElemSize;
    If ESz <= 0 Then ESz := 4;
    IsByte := (TypeTab[TI].ElemType = TYPE_CHAR) Or
              (TypeTab[TI].ElemType = TYPE_BOOL);
  End;
  { EAX = index ; calculer offset dans EBX }
  EmitI('MOV  EBX, EAX');              { EBX = index              }
  If Lo <> 0 Then
    EmitI('SUB  EBX, ' + IntToStr_(Lo)); { EBX = index - lo_bound }
  If ESz <> 1 Then
    EmitI('IMUL EBX, ' + IntToStr_(ESz)); { EBX = (index-lo)*esz }
  { Charger adresse de base dans EAX }
  Case SC Of
    STORE_STATIC :
      EmitI('LEA  EAX, [' + Lbl + ']');
    STORE_AUTO :
      EmitI('LEA  EAX, [EBP' + BpOff32(Off) + ']');
    STORE_PARAM :
      EmitI('LEA  EAX, [EBP' + BpOff32(Off) + ']');
  End;
  { EAX = base + offset -> charger element }
  If IsByte Then
    EmitI('MOVZX EAX, BYTE PTR [EAX+EBX]')
  Else
    EmitI('MOV  EAX, DWORD PTR [EAX+EBX]');
End;

{ ---- GenStoreElement : stocker EAX dans un element de tableau - }
{ L index est sur la pile (PUSH avant appel). EAX = valeur.       }
{ Genere : POP EBX (index), calcule adresse, ecrit valeur.        }
Procedure GenStoreElement(SymIdx : Integer);
Var
  SC, Off, TI : Integer;
  Lbl         : TString;
  Lo, ESz     : LongInt;
  IsByte      : Boolean;
Begin
  SC  := SymTab[SymIdx].StoreClass;
  Off := SymTab[SymIdx].BpOffset;
  Lbl := SymTab[SymIdx].AsmLabel;
  TI  := SymTab[SymIdx].TypeIdx;
  Lo  := 0;
  ESz := 4;
  IsByte := False;
  If (TI > TYPE_STR) And (TI <= TypeCount) Then
  Begin
    Lo  := TypeTab[TI].LoBound;
    ESz := TypeTab[TI].ElemSize;
    If ESz <= 0 Then ESz := 4;
    IsByte := (TypeTab[TI].ElemType = TYPE_CHAR) Or
              (TypeTab[TI].ElemType = TYPE_BOOL);
  End;
  { EAX = valeur a stocker ; sauvegarder dans ECX }
  EmitI('MOV  ECX, EAX');              { ECX = valeur             }
  { Recuperer l index depuis la pile }
  EmitI('POP  EBX');                   { EBX = index              }
  If Lo <> 0 Then
    EmitI('SUB  EBX, ' + IntToStr_(Lo)); { EBX = index - lo_bound }
  If ESz <> 1 Then
    EmitI('IMUL EBX, ' + IntToStr_(ESz)); { EBX = (index-lo)*esz }
  { Charger adresse de base dans EAX }
  Case SC Of
    STORE_STATIC :
      EmitI('LEA  EAX, [' + Lbl + ']');
    STORE_AUTO :
      EmitI('LEA  EAX, [EBP' + BpOff32(Off) + ']');
    STORE_PARAM :
      EmitI('LEA  EAX, [EBP' + BpOff32(Off) + ']');
  End;
  { Ecrire la valeur a l adresse base + offset }
  If IsByte Then
    EmitI('MOV  BYTE PTR [EAX+EBX], CL')
  Else
    EmitI('MOV  DWORD PTR [EAX+EBX], ECX');
End;

{ ============================================================ }
{ TODO 21 - PARSEUR : OPERATIONS SUR RECORDS (32 BITS)          }
{ ============================================================ }

{ ---- FindFieldIdx : trouver l index d un champ dans un type -- }
{ Retourne l index (1-base) du champ, ou 0 si non trouve.        }
Function FindFieldIdx(TypeIdx : Integer; Const FieldName : TString) : Integer;
Var
  I : Integer;
  U : TString;
Begin
  FindFieldIdx := 0;
  If (TypeIdx < 1) Or (TypeIdx > TypeCount) Then Exit;
  If TypeTab[TypeIdx].Kind <> TK_RECORD Then Exit;
  U := StrUpperCase(FieldName);
  For I := 1 To TypeTab[TypeIdx].FieldCount Do
    If TypeTab[TypeIdx].FieldNames[I] = U Then
    Begin FindFieldIdx := I; Exit; End;
End;

{ ---- GenLoadField : charger un champ de record dans EAX ------ }
{ SymIdx = index du symbole record, FI = index du champ (1-base) }
{ Genere : LEA EAX, [base] / MOV EAX, [EAX+offset]              }
Procedure GenLoadField(SymIdx, FI : Integer);
Var
  SC, Off, TI, FOff, FTI : Integer;
  Lbl                     : TString;
  IsByte                  : Boolean;
Begin
  SC  := SymTab[SymIdx].StoreClass;
  Off := SymTab[SymIdx].BpOffset;
  Lbl := SymTab[SymIdx].AsmLabel;
  TI  := SymTab[SymIdx].TypeIdx;
  FOff := 0;
  IsByte := False;
  If (TI > TYPE_STR) And (TI <= TypeCount) Then
  Begin
    If (FI >= 1) And (FI <= TypeTab[TI].FieldCount) Then
    Begin
      FOff := TypeTab[TI].FieldOffs[FI];
      FTI  := TypeTab[TI].FieldTypes[FI];
      IsByte := (FTI = TYPE_CHAR) Or (FTI = TYPE_BOOL);
    End;
  End;
  { Charger adresse de base dans EAX }
  Case SC Of
    STORE_STATIC :
      EmitI('LEA  EAX, [' + Lbl + ']');
    STORE_AUTO :
      EmitI('LEA  EAX, [EBP' + BpOff32(Off) + ']');
    STORE_PARAM :
      EmitI('LEA  EAX, [EBP' + BpOff32(Off) + ']');
  End;
  { Charger le champ }
  If IsByte Then
    EmitI('MOVZX EAX, BYTE PTR [EAX+' + IntToStr_(FOff) + ']')
  Else
    EmitI('MOV  EAX, DWORD PTR [EAX+' + IntToStr_(FOff) + ']');
End;

{ ---- GenStoreField : stocker EAX dans un champ de record ----- }
{ SymIdx = index du symbole record, FI = index du champ (1-base) }
{ EAX = valeur a stocker.                                         }
{ Genere : MOV ECX,EAX / LEA EBX,[base] / MOV [EBX+off],ECX      }
Procedure GenStoreField(SymIdx, FI : Integer);
Var
  SC, Off, TI, FOff, FTI : Integer;
  Lbl                     : TString;
  IsByte                  : Boolean;
Begin
  SC  := SymTab[SymIdx].StoreClass;
  Off := SymTab[SymIdx].BpOffset;
  Lbl := SymTab[SymIdx].AsmLabel;
  TI  := SymTab[SymIdx].TypeIdx;
  FOff := 0;
  IsByte := False;
  If (TI > TYPE_STR) And (TI <= TypeCount) Then
  Begin
    If (FI >= 1) And (FI <= TypeTab[TI].FieldCount) Then
    Begin
      FOff := TypeTab[TI].FieldOffs[FI];
      FTI  := TypeTab[TI].FieldTypes[FI];
      IsByte := (FTI = TYPE_CHAR) Or (FTI = TYPE_BOOL);
    End;
  End;
  { Sauvegarder la valeur dans ECX }
  EmitI('MOV  ECX, EAX');
  { Charger adresse de base dans EBX }
  Case SC Of
    STORE_STATIC :
      EmitI('LEA  EBX, [' + Lbl + ']');
    STORE_AUTO :
      EmitI('LEA  EBX, [EBP' + BpOff32(Off) + ']');
    STORE_PARAM :
      EmitI('LEA  EBX, [EBP' + BpOff32(Off) + ']');
  End;
  { Ecrire la valeur dans le champ }
  If IsByte Then
    EmitI('MOV  BYTE PTR [EBX+' + IntToStr_(FOff) + '], CL')
  Else
    EmitI('MOV  DWORD PTR [EBX+' + IntToStr_(FOff) + '], ECX');
End;

{ ---- GenLoadFieldNested : champ imbrique base_off + field_off  }
{ Pour var.champ.sous_champ, base_off = offset du champ parent,  }
{ FTI = type du champ parent (record imbrique),                   }
{ FI2 = index du sous-champ dans FTI.                             }
{ EAX = base du symbole, ajouter base_off, puis lire sous-champ. }
Procedure GenLoadFieldNested(SymIdx, BaseOff, FTI, FI2 : Integer);
Var
  SC, Off, FOff2 : Integer;
  Lbl            : TString;
  IsByte         : Boolean;
  FTI2           : Integer;
Begin
  SC  := SymTab[SymIdx].StoreClass;
  Off := SymTab[SymIdx].BpOffset;
  Lbl := SymTab[SymIdx].AsmLabel;
  FOff2 := 0;
  IsByte := False;
  If (FTI >= 1) And (FTI <= TypeCount) And
     (FI2 >= 1) And (FI2 <= TypeTab[FTI].FieldCount) Then
  Begin
    FOff2 := TypeTab[FTI].FieldOffs[FI2];
    FTI2  := TypeTab[FTI].FieldTypes[FI2];
    IsByte := (FTI2 = TYPE_CHAR) Or (FTI2 = TYPE_BOOL);
  End;
  { Charger adresse de base dans EAX }
  Case SC Of
    STORE_STATIC :
      EmitI('LEA  EAX, [' + Lbl + ']');
    STORE_AUTO :
      EmitI('LEA  EAX, [EBP' + BpOff32(Off) + ']');
    STORE_PARAM :
      EmitI('LEA  EAX, [EBP' + BpOff32(Off) + ']');
  End;
  { Charger le sous-champ }
  If IsByte Then
    EmitI('MOVZX EAX, BYTE PTR [EAX+' +
          IntToStr_(BaseOff + FOff2) + ']')
  Else
    EmitI('MOV  EAX, DWORD PTR [EAX+' +
          IntToStr_(BaseOff + FOff2) + ']');
End;

{ ---- GenStoreFieldNested : stocker dans sous-champ imbrique -- }
{ EAX = valeur. SymIdx = record, BaseOff = off parent,           }
{ FTI = type parent, FI2 = index sous-champ.                     }
Procedure GenStoreFieldNested(SymIdx, BaseOff, FTI, FI2 : Integer);
Var
  SC, Off, FOff2 : Integer;
  Lbl            : TString;
  IsByte         : Boolean;
  FTI2           : Integer;
Begin
  SC  := SymTab[SymIdx].StoreClass;
  Off := SymTab[SymIdx].BpOffset;
  Lbl := SymTab[SymIdx].AsmLabel;
  FOff2 := 0;
  IsByte := False;
  If (FTI >= 1) And (FTI <= TypeCount) And
     (FI2 >= 1) And (FI2 <= TypeTab[FTI].FieldCount) Then
  Begin
    FOff2 := TypeTab[FTI].FieldOffs[FI2];
    FTI2  := TypeTab[FTI].FieldTypes[FI2];
    IsByte := (FTI2 = TYPE_CHAR) Or (FTI2 = TYPE_BOOL);
  End;
  { Sauvegarder la valeur dans ECX }
  EmitI('MOV  ECX, EAX');
  { Charger adresse de base dans EBX }
  Case SC Of
    STORE_STATIC :
      EmitI('LEA  EBX, [' + Lbl + ']');
    STORE_AUTO :
      EmitI('LEA  EBX, [EBP' + BpOff32(Off) + ']');
    STORE_PARAM :
      EmitI('LEA  EBX, [EBP' + BpOff32(Off) + ']');
  End;
  { Ecrire la valeur dans le sous-champ }
  If IsByte Then
    EmitI('MOV  BYTE PTR [EBX+' +
          IntToStr_(BaseOff + FOff2) + '], CL')
  Else
    EmitI('MOV  DWORD PTR [EBX+' +
          IntToStr_(BaseOff + FOff2) + '], ECX');
End;

{ ---- GenLoadConst : charger une constante dans EAX ----------- }
Procedure GenLoadConst(Val : LongInt);
Begin
  EmitI('MOV EAX, ' + IntToStr_(Val));
End;

{ ---- GenPrologue : prologue de sous-programme 32 bits --------- }
{ PUSH EBP / MOV EBP, ESP / SUB ESP, frame_size                   }
Procedure GenPrologue(FrameSize : Integer);
Begin
  EmitI('PUSH EBP');
  EmitI('MOV  EBP, ESP');
  If FrameSize > 0 Then
    EmitI('SUB  ESP, ' + IntToStr_(FrameSize));
End;

{ ---- GenEpilogue : epilogue de sous-programme 32 bits --------- }
{ MOV ESP, EBP / POP EBP / RET param_bytes (STDCALL callee-cleanup)}
Procedure GenEpilogue(FrameSize : Integer; ParamBytes : Integer);
Begin
  If FrameSize > 0 Then
    EmitI('MOV  ESP, EBP');
  EmitI('POP  EBP');
  If ParamBytes > 0 Then
    EmitI('RET  ' + IntToStr_(ParamBytes))
  Else
    EmitI('RET');
End;

{ ---- Helpers PUSH / POP 32 bits ------------------------------ }

Procedure GenPushEAX;
Begin EmitI('PUSH EAX'); End;

Procedure GenPopEAX;
Begin EmitI('POP  EAX'); End;

Procedure GenPushEBX;
Begin EmitI('PUSH EBX'); End;

Procedure GenPopEBX;
Begin EmitI('POP  EBX'); End;

{ ---- GenCall : appel de sous-programme ----------------------- }
Procedure GenCall(Const Lbl : TString);
Begin
  EmitI('CALL ' + Lbl);
End;

{ ============================================================ }
{ PARSEUR D'EXPRESSIONS : PRECEDENCES ADA (32 BITS) (TODO 08)  }
{ ============================================================ }

{ ---- Forward declaration ---- }
{ ParsePrimary appelle ParseExpr pour les sous-expressions      }
{ entre parentheses -> forward necessaire.                      }
Procedure ParseExpr; Forward;

{ ---- GenBinOp32 : operateur binaire arithmetique 32 bits ----- }
{ Pile : PUSH gauche. EAX = droite.                               }
{ Resultat dans EAX.                                              }
Procedure GenBinOp32(Op : Integer);
Begin
  Case Op Of
    TOK_PLUS :
    Begin
      EmitI('POP  EBX');
      EmitI('ADD  EAX, EBX');
    End;
    TOK_MINUS :
    Begin
      EmitI('MOV  EBX, EAX');   { EBX = droite                }
      EmitI('POP  EAX');        { EAX = gauche                 }
      EmitI('SUB  EAX, EBX');
    End;
    TOK_STAR :
    Begin
      EmitI('POP  EBX');
      EmitI('IMUL EAX, EBX');   { EAX = EAX * EBX (32 bits)   }
    End;
    TOK_SLASH :
    Begin
      EmitI('MOV  EBX, EAX');   { EBX = diviseur (droite)      }
      EmitI('POP  EAX');        { EAX = dividende (gauche)     }
      EmitI('CDQ');             { signe-etend EAX -> EDX:EAX   }
      EmitI('IDIV EBX');       { EAX = quotient               }
    End;
    KW_MOD :
    Begin
      EmitI('MOV  EBX, EAX');
      EmitI('POP  EAX');
      EmitI('CDQ');
      EmitI('IDIV EBX');       { EAX = quotient, EDX = reste   }
      EmitI('MOV  EAX, EDX');  { Ada REM d abord                }
      { Ada MOD : si signe(reste) <> signe(diviseur) -> +div    }
      EmitI('TEST EAX, EAX');
      EmitI('JE   ' + ADA_LBL_PFX + 'MOD_' + IntToStr_(LabelCounter + 1));
      EmitI('XOR  ECX, ECX');
      EmitI('TEST EBX, EBX');
      EmitI('SETL CL');
      EmitI('TEST EAX, EAX');
      EmitI('SETL CH');
      EmitI('CMP  CL, CH');
      EmitI('JE   ' + ADA_LBL_PFX + 'MOD_' + IntToStr_(LabelCounter + 1));
      EmitI('ADD  EAX, EBX');
      EmitLabel(ADA_LBL_PFX + 'MOD_' + IntToStr_(LabelCounter + 1));
      Inc(LabelCounter);
    End;
    KW_REM :
    Begin
      EmitI('MOV  EBX, EAX');
      EmitI('POP  EAX');
      EmitI('CDQ');
      EmitI('IDIV EBX');       { EAX = quotient, EDX = reste   }
      EmitI('MOV  EAX, EDX'); { Ada REM = reste C               }
    End;
    TOK_AMPERSAND :
    Begin
      { Concatenation chaines : stub -> appel helper runtime      }
      EmitI('POP  EBX');
      EmitI('PUSH EBX');       { arg 1 = gauche                  }
      EmitI('PUSH EAX');       { arg 2 = droite                  }
      EmitI('CALL ' + ADA_RT_PFX + 'STR_CAT');
      EmitI('ADD  ESP, 8');    { nettoyage pile (cdecl)           }
    End;
  End;
End;

{ ---- GenRelOp32 : CMP + SETcc AL + MOVZX, resultat 0/1 dans EAX }
{ Pile : PUSH gauche. EAX = droite. Resultat booleen dans EAX.     }
Procedure GenRelOp32(Op : Integer);
Begin
  EmitI('MOV  EBX, EAX');    { EBX = droite                    }
  EmitI('POP  EAX');          { EAX = gauche                    }
  EmitI('CMP  EAX, EBX');
  Case Op Of
    TOK_EQ  : EmitI('SETE  AL');
    TOK_NEQ : EmitI('SETNE AL');
    TOK_LT  : EmitI('SETL  AL');
    TOK_LE  : EmitI('SETLE AL');
    TOK_GT  : EmitI('SETG  AL');
    TOK_GE  : EmitI('SETGE AL');
  End;
  EmitI('MOVZX EAX, AL');
End;

{ ---- ParsePrimary : litteraux, idents, appels, (expr) ------- }
Procedure ParsePrimary;
Var
  Sym, Sub, TI : Integer;
  Nm, Lbl      : TString;
  AI           : Integer;
  I, J         : Integer;
  ArgCount     : Integer;
Begin
  { --- Litteral entier --- }
  If CurTokType = TOK_INTEGER Then
  Begin
    EmitI('MOV  EAX, ' + IntToStr_(CurTokNum));
    Consume;
    Exit;
  End;

  { --- Litteral flottant (stub 32 bits) --- }
  If CurTokType = TOK_FLOAT Then
  Begin
    EmitI('XOR  EAX, EAX');   { stub : float non encore supporte }
    Warning('Litteraux flottants non encore pleinement supportes');
    Consume;
    Exit;
  End;

  { --- Litteral caractere --- }
  If CurTokType = TOK_CHAR Then
  Begin
    If Length(CurTokStr) > 0 Then
      EmitI('MOV  EAX, ' + IntToStr_(Ord(CurTokStr[1])))
    Else
      EmitI('XOR  EAX, EAX');
    Consume;
    Exit;
  End;

  { --- Litteral chaine --- }
  If CurTokType = TOK_STRING Then
  Begin
    Lbl := AsmStrLit(CurTokStr);
    EmitI('MOV  EAX, OFFSET ' + Lbl);
    Consume;
    Exit;
  End;

  { --- TRUE / FALSE --- }
  If (CurTokType = TOK_IDENT) And (CurTokKw = KW_TRUE) Then
  Begin EmitI('MOV  EAX, 1'); Consume; Exit; End;
  If (CurTokType = TOK_IDENT) And (CurTokKw = KW_FALSE) Then
  Begin EmitI('XOR  EAX, EAX'); Consume; Exit; End;

  { --- NULL --- }
  If (CurTokType = TOK_IDENT) And (CurTokKw = KW_NULL) Then
  Begin EmitI('XOR  EAX, EAX'); Consume; Exit; End;

  { --- Identifiant : variable, constante, appel, attribut --- }
  If CurTokType = TOK_IDENT Then
  Begin
    Nm := CurTokStr;
    Consume;

    { Attribut : Nom'FIRST | LAST | LENGTH | SIZE }
    If CurTokType = TOK_TICK Then
    Begin
      Consume;
      AI := 0;
      If CurTokType = TOK_IDENT Then
      Begin
        If      CurTokStr = 'FIRST'  Then AI := 1
        Else If CurTokStr = 'LAST'   Then AI := 2
        Else If CurTokStr = 'LENGTH' Then AI := 3
        Else If CurTokStr = 'SIZE'   Then AI := 4
        Else Warning('Attribut Ada inconnu : ' + CurTokStr);
        Consume;
      End;
      TI := FindType(Nm);
      If TI > 0 Then
      Begin
        Case AI Of
          1 : EmitI('MOV  EAX, ' + IntToStr_(TypeTab[TI].LoBound));
          2 : EmitI('MOV  EAX, ' + IntToStr_(TypeTab[TI].HiBound));
          3 : EmitI('MOV  EAX, ' +
                IntToStr_(TypeTab[TI].HiBound - TypeTab[TI].LoBound + 1));
          4 : EmitI('MOV  EAX, ' + IntToStr_(TypeTab[TI].TotalSize));
        Else  EmitI('XOR  EAX, EAX');
        End;
      End
      Else
      Begin
        Sym := FindSym(Nm);
        If Sym > 0 Then
        Begin
          TI := SymTab[Sym].TypeIdx;
          If TI > 0 Then
          Case AI Of
            1 : EmitI('MOV  EAX, ' + IntToStr_(TypeTab[TI].LoBound));
            2 : EmitI('MOV  EAX, ' + IntToStr_(TypeTab[TI].HiBound));
            3 : EmitI('MOV  EAX, ' +
                  IntToStr_(TypeTab[TI].HiBound - TypeTab[TI].LoBound + 1));
            4 : EmitI('MOV  EAX, ' + IntToStr_(TypeTab[TI].TotalSize));
          Else  EmitI('XOR  EAX, EAX');
          End
          Else EmitI('XOR  EAX, EAX');
        End
        Else
        Begin
          Error('Nom inconnu pour attribut : ' + Nm);
          EmitI('XOR  EAX, EAX');
        End;
      End;
      Exit;
    End; { TOK_TICK }

    { Appel de fonction : Nom( args ) }
    If CurTokType = TOK_LPAREN Then
    Begin
      Sub := FindSub(Nm);
      If Sub > 0 Then
      Begin
        Consume; { ( }
        ArgCount := 0;
        While CurTokType <> TOK_RPAREN Do
        Begin
          If CurTokType = TOK_EOF Then Break;
          ParseExpr;
          GenPushEAX;
          Inc(ArgCount);
          If CurTokType = TOK_COMMA Then Consume;
        End;
        Expect(TOK_RPAREN, '`)` attendu apres arguments');
        EmitI('CALL ' + SubTab[Sub].AsmLabel);
        { callee-cleanup (STDCALL) -> pas de ADD ESP ici }
        Exit;
      End
      Else
      Begin
        { Acces tableau : Nom(index) -> GenLoadElement (TODO 20) }
        Sym := FindSym(Nm);
        If Sym <= 0 Then
        Begin
          Error('Identificateur inconnu : ' + Nm);
          Consume;
          ParseExpr;
          Expect(TOK_RPAREN, '`)` attendu');
          EmitI('XOR  EAX, EAX');
          Exit;
        End;
        Consume; { ( }
        ParseExpr;         { EAX = index }
        { Detecter les slices : ident(a..b) }
        If CurTokType = TOK_DOTDOT Then
        Begin
          Warning('Slices non supportes ; valeur ignoree');
          Consume; { .. }
          ParseExpr;       { skip borne haute }
          Expect(TOK_RPAREN, '`)` attendu apres slice');
          EmitI('XOR  EAX, EAX');
          Exit;
        End;
        Expect(TOK_RPAREN, '`)` attendu apres index');
        EmitComment('array load ' + Nm + '(index)');
        GenLoadElement(Sym);
        Exit;
      End;
    End; { TOK_LPAREN apres ident }

    { Acces champ record : var.champ [.sous_champ] (TODO 21) }
    If CurTokType = TOK_DOT Then
    Begin
      Sym := FindSym(Nm);
      If Sym > 0 Then
      Begin
        TI := SymTab[Sym].TypeIdx;
        If (TI > TYPE_STR) And (TI <= TypeCount) And
           (TypeTab[TI].Kind = TK_RECORD) Then
        Begin
          Consume; { . }
          If CurTokType <> TOK_IDENT Then
          Begin
            Error('Nom de champ attendu apres `.`');
            EmitI('XOR  EAX, EAX');
            Exit;
          End;
          I := FindFieldIdx(TI, CurTokStr);
          If I <= 0 Then
          Begin
            Error('Champ inconnu : ' + CurTokStr + ' dans ' + Nm);
            EmitI('XOR  EAX, EAX');
            Consume;
            Exit;
          End;
          Consume; { field name }
          { Verifier acces imbrique : var.champ.sous_champ }
          If CurTokType = TOK_DOT Then
          Begin
            { Champ imbrique : le champ courant doit etre un record }
            J := TypeTab[TI].FieldTypes[I];
            AI := TypeTab[TI].FieldOffs[I];
            If (J > TYPE_STR) And (J <= TypeCount) And
               (TypeTab[J].Kind = TK_RECORD) Then
            Begin
              Consume; { . }
              If CurTokType <> TOK_IDENT Then
              Begin
                Error('Nom de sous-champ attendu');
                EmitI('XOR  EAX, EAX');
                Exit;
              End;
              Sub := FindFieldIdx(J, CurTokStr);
              If Sub <= 0 Then
              Begin
                Error('Sous-champ inconnu : ' + CurTokStr);
                EmitI('XOR  EAX, EAX');
                Consume;
                Exit;
              End;
              Consume; { sub-field name }
              EmitComment('record nested load ' + Nm + '.field.subfield');
              GenLoadFieldNested(Sym, AI, J, Sub);
              Exit;
            End
            Else
            Begin
              { Pas un record imbrique : traiter comme nom qualifie }
              Warning('Acces imbrique non supporte pour ce type');
              EmitI('XOR  EAX, EAX');
              Consume; { . }
              If CurTokType = TOK_IDENT Then Consume;
              Exit;
            End;
          End;
          EmitComment('record load ' + Nm + '.' +
                      TypeTab[TI].FieldNames[I]);
          GenLoadField(Sym, I);
          Exit;
        End
        Else
        Begin
          { Pas un record : nom qualifie (pkg.proc) }
          { Construire le nom complet }
          While CurTokType = TOK_DOT Do
          Begin
            Consume; { . }
            If CurTokType = TOK_IDENT Then
            Begin Nm := Nm + '.' + CurTokStr; Consume; End;
          End;
          { Appel de fonction qualifiee }
          If CurTokType = TOK_LPAREN Then
          Begin
            Sub := FindSub(Nm);
            If Sub > 0 Then
            Begin
              Consume; { ( }
              ArgCount := 0;
              While CurTokType <> TOK_RPAREN Do
              Begin
                If CurTokType = TOK_EOF Then Break;
                ParseExpr;
                GenPushEAX;
                Inc(ArgCount);
                If CurTokType = TOK_COMMA Then Consume;
              End;
              Expect(TOK_RPAREN, '`)` attendu');
              EmitI('CALL ' + SubTab[Sub].AsmLabel);
              Exit;
            End;
          End;
          { Variable qualifiee ou enum }
          Sym := FindSym(Nm);
          If Sym > 0 Then GenLoadVar(Sym)
          Else
          Begin
            Error('Identificateur qualifie inconnu : ' + Nm);
            EmitI('XOR  EAX, EAX');
          End;
          Exit;
        End;
      End
      Else
      Begin
        { Symbole non trouve : nom qualifie (pkg.proc) }
        While CurTokType = TOK_DOT Do
        Begin
          Consume; { . }
          If CurTokType = TOK_IDENT Then
          Begin Nm := Nm + '.' + CurTokStr; Consume; End;
        End;
        Sym := FindSym(Nm);
        If Sym > 0 Then GenLoadVar(Sym)
        Else
        Begin
          Sub := FindSub(Nm);
          If (Sub > 0) And (CurTokType = TOK_LPAREN) Then
          Begin
            Consume; { ( }
            ArgCount := 0;
            While CurTokType <> TOK_RPAREN Do
            Begin
              If CurTokType = TOK_EOF Then Break;
              ParseExpr;
              GenPushEAX;
              Inc(ArgCount);
              If CurTokType = TOK_COMMA Then Consume;
            End;
            Expect(TOK_RPAREN, '`)` attendu');
            EmitI('CALL ' + SubTab[Sub].AsmLabel);
          End
          Else
          Begin
            Error('Identificateur inconnu : ' + Nm);
            EmitI('XOR  EAX, EAX');
          End;
        End;
        Exit;
      End;
    End; { TOK_DOT record field access }

    { Variable ou constante simple }
    Sym := FindSym(Nm);
    If Sym > 0 Then
      GenLoadVar(Sym)
    Else
    Begin
      { Litteral d enumeration : chercher dans les types }
      For I := 1 To TypeCount Do
        If TypeTab[I].Kind = TK_ENUM Then
          For J := 1 To TypeTab[I].EnumCount Do
            If TypeTab[I].EnumNames[J] = Nm Then
            Begin
              EmitI('MOV  EAX, ' + IntToStr_(J - 1));
              Exit;
            End;
      Error('Identificateur inconnu : ' + Nm);
      EmitI('XOR  EAX, EAX');
    End;
    Exit;
  End; { TOK_IDENT }

  { --- Sous-expression ( expr ) --- }
  If CurTokType = TOK_LPAREN Then
  Begin
    Consume;
    ParseExpr;
    Expect(TOK_RPAREN, '`)` attendu en fin de sous-expression');
    Exit;
  End;

  { Rien reconnu }
  Error('Primaire d''expression attendu, trouve: ''' + CurTokStr + '''');
  EmitI('XOR  EAX, EAX');
  Consume;
End;

{ ---- ParseFactor : ** et ABS --------------------------------- }
Procedure ParseFactor;
Var
  Lbl1, LblLoop : TString;
Begin
  { ABS unaire }
  If (CurTokType = TOK_IDENT) And (CurTokKw = KW_ABS) Then
  Begin
    Consume;
    ParseFactor;
    Lbl1 := NewLabel;
    EmitI('TEST EAX, EAX');
    EmitI('JGE  ' + Lbl1);
    EmitI('NEG  EAX');
    EmitLabel(Lbl1);
    Exit;
  End;
  ParsePrimary;
  { ** (puissance entiere iterative) }
  While CurTokType = TOK_POWER Do
  Begin
    GenPushEAX;                          { gauche sur pile          }
    Consume;
    ParsePrimary;                        { EAX = exposant           }
    EmitI('MOV  ECX, EAX');             { ECX = exposant           }
    EmitI('POP  EBX');                  { EBX = base               }
    Lbl1 := NewLabel;
    EmitI('MOV  EAX, 1');              { resultat = 1             }
    EmitI('TEST ECX, ECX');
    EmitI('JE   ' + Lbl1);
    LblLoop := NewLabel;
    EmitLabel(LblLoop);
    EmitI('IMUL EAX, EBX');
    EmitI('DEC  ECX');
    EmitI('JNZ  ' + LblLoop);
    EmitLabel(Lbl1);
  End;
End;

{ ---- ParseTerm : * / MOD REM --------------------------------- }
Procedure ParseTerm;
Var Op : Integer;
Begin
  ParseFactor;
  While (CurTokType = TOK_STAR) Or (CurTokType = TOK_SLASH)
     Or ((CurTokType = TOK_IDENT) And
         ((CurTokKw = KW_MOD) Or (CurTokKw = KW_REM))) Do
  Begin
    GenPushEAX;
    If CurTokType = TOK_IDENT Then Op := CurTokKw
    Else Op := CurTokType;
    Consume;
    ParseFactor;
    GenBinOp32(Op);
  End;
End;

{ ---- ParseSimple : + - & (unaire + ou - possible en tete) ---- }
Procedure ParseSimple;
Var
  Op   : Integer;
  UNeg : Boolean;
Begin
  UNeg := False;
  If CurTokType = TOK_MINUS Then
  Begin UNeg := True; Consume; End
  Else If CurTokType = TOK_PLUS Then Consume;
  ParseTerm;
  If UNeg Then EmitI('NEG  EAX');
  While (CurTokType = TOK_PLUS) Or (CurTokType = TOK_MINUS)
     Or (CurTokType = TOK_AMPERSAND) Do
  Begin
    GenPushEAX;
    Op := CurTokType;
    Consume;
    ParseTerm;
    GenBinOp32(Op);
  End;
End;

{ ---- ParseRelation : = /= < <= > >= -------------------------- }
Procedure ParseRelation;
Var Op : Integer;
Begin
  ParseSimple;
  If (CurTokType = TOK_EQ)  Or (CurTokType = TOK_NEQ) Or
     (CurTokType = TOK_LT)  Or (CurTokType = TOK_LE)  Or
     (CurTokType = TOK_GT)  Or (CurTokType = TOK_GE) Then
  Begin
    GenPushEAX;
    Op := CurTokType;
    Consume;
    ParseSimple;
    GenRelOp32(Op);
  End;
End;

{ ---- ParseNot : NOT unaire logique --------------------------- }
Procedure ParseNot;
Begin
  If (CurTokType = TOK_IDENT) And (CurTokKw = KW_NOT) Then
  Begin
    Consume;
    ParseRelation;
    EmitI('XOR  EAX, 1');   { NOT booleen : 0->1, 1->0         }
  End
  Else
    ParseRelation;
End;

{ ---- ParseAnd : AND (bit ou logique) ------------------------- }
Procedure ParseAnd;
Begin
  ParseNot;
  While (CurTokType = TOK_IDENT) And (CurTokKw = KW_AND) Do
  Begin
    GenPushEAX;
    Consume;
    ParseNot;
    EmitI('POP  EBX');
    EmitI('AND  EAX, EBX');
  End;
End;

{ ---- ParseOr : OR et XOR (bit ou logique) -------------------- }
Procedure ParseOr;
Var IsXor : Boolean;
Begin
  ParseAnd;
  While (CurTokType = TOK_IDENT) And
        ((CurTokKw = KW_OR) Or (CurTokKw = KW_XOR)) Do
  Begin
    GenPushEAX;
    IsXor := (CurTokKw = KW_XOR);
    Consume;
    ParseAnd;
    EmitI('POP  EBX');
    If IsXor Then EmitI('XOR  EAX, EBX')
    Else          EmitI('OR   EAX, EBX');
  End;
End;

{ ---- ParseAndThen : AND THEN (court-circuit) ----------------- }
Procedure ParseAndThen;
Var LblFalse : TString;
Begin
  ParseOr;
  While (CurTokType = TOK_IDENT) And (CurTokKw = KW_ANDTHEN) Do
  Begin
    LblFalse := NewLabel;
    Consume;
    EmitI('TEST EAX, EAX');
    EmitI('JE   ' + LblFalse);
    ParseOr;
    EmitI('AND  EAX, EAX');
    EmitLabel(LblFalse);
  End;
End;

{ ---- ParseOrElse : OR ELSE (court-circuit) ------------------- }
Procedure ParseOrElse;
Var LblTrue : TString;
Begin
  ParseAndThen;
  While (CurTokType = TOK_IDENT) And (CurTokKw = KW_ORELSE) Do
  Begin
    LblTrue := NewLabel;
    Consume;
    EmitI('TEST EAX, EAX');
    EmitI('JNE  ' + LblTrue);
    ParseAndThen;
    EmitI('OR   EAX, EAX');
    EmitLabel(LblTrue);
  End;
End;

{ ---- ParseExpr : point d entree principal des expressions ---- }
Procedure ParseExpr;
Begin
  ParseOrElse;
End;

{ ============================================================ }
{ PARSEUR : WITH ET USE (TODO 09)                               }
{ ============================================================ }

{ ---- IsStandardPackage : vrai si package reconnu standard ---- }
Function IsStandardPackage(Const U : TString) : Boolean;
Begin
  IsStandardPackage :=
    (U = 'ADA.TEXT_IO')                       Or
    (U = 'ADA.INTEGER_TEXT_IO')               Or
    (U = 'ADA.FLOAT_TEXT_IO')                 Or
    (U = 'ADA.NUMERICS')                      Or
    (U = 'ADA.NUMERICS.ELEMENTARY_FUNCTIONS') Or
    (U = 'SYSTEM')                            Or
    (U = 'TEXT_IO');
End;

{ ---- ParsePackageName : lire un nom qualifie A.B.C ---------- }
Function ParsePackageName : TString;
Var Res : TString;
Begin
  If CurTokType <> TOK_IDENT Then
  Begin
    Error('Nom de package attendu, trouve: ''' + CurTokStr + '''');
    ParsePackageName := '';
    Exit;
  End;
  Res := StrUpperCase(CurTokStr);
  Consume;
  While CurTokType = TOK_DOT Do
  Begin
    Consume;
    If CurTokType <> TOK_IDENT Then
    Begin
      Error('Identifiant attendu apres `.` dans nom de package');
      Break;
    End;
    Res := Res + '.' + StrUpperCase(CurTokStr);
    Consume;
  End;
  ParsePackageName := Res;
End;

{ ---- ParseWith : WITH pkg1, pkg2, ... ; ---------------------- }
Procedure ParseWith;
Var
  Nm  : TString;
  Idx : Integer;
Begin
  Consume; { consomme WITH }
  Repeat
    Nm := ParsePackageName;
    If Nm = '' Then Break;
    If IsStandardPackage(Nm) Then
      Idx := AddPkg(Nm, True)
    Else
    Begin
      Warning('Package non supporte, importe mais ignore : ' + Nm);
      Idx := AddPkg(Nm, False);
    End;
    If CurTokType = TOK_COMMA Then Consume
    Else Break;
  Until False;
  Expect(TOK_SEMI, '`;` attendu en fin de clause WITH');
End;

{ ---- ParseUse : USE pkg1, pkg2, ... ; ------------------------ }
Procedure ParseUse;
Var
  Nm  : TString;
  Idx : Integer;
Begin
  Consume; { consomme USE }
  Repeat
    Nm := ParsePackageName;
    If Nm = '' Then Break;
    Idx := FindPkg(Nm);
    If Idx = 0 Then
    Begin
      If IsStandardPackage(Nm) Then
        Idx := AddPkg(Nm, True)
      Else
      Begin
        Warning('USE sur package non importe via WITH : ' + Nm);
        Idx := AddPkg(Nm, False);
      End;
    End;
    If Idx > 0 Then
      PkgTab[Idx].UseActive := True;
    If CurTokType = TOK_COMMA Then Consume
    Else Break;
  Until False;
  Expect(TOK_SEMI, '`;` attendu en fin de clause USE');
End;

{ ---- ParseWithUseSection : boucle WITH/USE en debut ---------- }
Procedure ParseWithUseSection;
Begin
  While (CurTokType = TOK_IDENT) And
        ((CurTokKw = KW_WITH) Or (CurTokKw = KW_USE)) Do
  Begin
    If CurTokKw = KW_WITH Then ParseWith
    Else ParseUse;
  End;
End;

{ ============================================================ }
{ TODO 10 - PARSEUR : DECLARATIONS DE TYPES UTILISATEUR        }
{ ============================================================ }

{ ---- ParseTypeRef : resoudre un nom de type -> index --------- }
{ Gere les types predefinis (INTEGER, FLOAT, BOOLEAN, CHARACTER, }
{ STRING, NATURAL, POSITIVE) et les types utilisateur.           }
Function ParseTypeRef : Integer;
Var
  Nm : TString;
  Ti : Integer;
Begin
  If CurTokType <> TOK_IDENT Then
  Begin
    Error('Nom de type attendu');
    ParseTypeRef := TYPE_UNKNOWN; Exit;
  End;
  Nm := StrUpperCase(CurTokStr);
  Consume;
  If Nm = 'INTEGER'   Then Begin ParseTypeRef := TYPE_INT;   Exit; End;
  If Nm = 'FLOAT'     Then Begin ParseTypeRef := TYPE_FLOAT; Exit; End;
  If Nm = 'BOOLEAN'   Then Begin ParseTypeRef := TYPE_BOOL;  Exit; End;
  If Nm = 'CHARACTER' Then Begin ParseTypeRef := TYPE_CHAR;  Exit; End;
  If Nm = 'STRING'    Then Begin ParseTypeRef := TYPE_STR;   Exit; End;
  If Nm = 'NATURAL'   Then Begin ParseTypeRef := TYPE_INT;   Exit; End;
  If Nm = 'POSITIVE'  Then Begin ParseTypeRef := TYPE_INT;   Exit; End;
  Ti := FindType(Nm);
  If Ti > 0 Then Begin ParseTypeRef := Ti; Exit; End;
  Error('Type inconnu : ' + Nm);
  ParseTypeRef := TYPE_UNKNOWN;
End;

{ ---- ParseRangeBoundsEx : lire lo .. hi ---------------------- }
{ Supporte entiers, TRUE/FALSE, et litteraux d enumeration.      }
Procedure ParseRangeBoundsEx(Var Lo, Hi : LongInt; EnumTi : Integer);
Var
  LitNm : TString;
  I     : Integer;
Begin
  { --- Borne inferieure --- }
  If CurTokType = TOK_INTEGER Then
  Begin Lo := CurTokNum; Consume; End
  Else If CurTokType = TOK_MINUS Then
  Begin Consume;
    If CurTokType = TOK_INTEGER Then
    Begin Lo := -CurTokNum; Consume; End
    Else Begin Error('Entier attendu apres -'); Lo := 0; End;
  End
  Else If (CurTokType = TOK_IDENT) And (CurTokKw = KW_TRUE) Then
  Begin Lo := 1; Consume; End
  Else If (CurTokType = TOK_IDENT) And (CurTokKw = KW_FALSE) Then
  Begin Lo := 0; Consume; End
  Else If (CurTokType = TOK_IDENT) And (EnumTi > 0) And
          (TypeTab[EnumTi].Kind = TK_ENUM) Then
  Begin
    LitNm := StrUpperCase(CurTokStr);
    Lo := -1;
    For I := 1 To TypeTab[EnumTi].EnumCount Do
      If TypeTab[EnumTi].EnumNames[I] = LitNm Then
      Begin Lo := I - 1; Break; End;
    If Lo < 0 Then
    Begin Error('Litteral enumere inconnu : ' + LitNm); Lo := 0; End;
    Consume;
  End
  Else
  Begin Error('Borne inferieure entiere attendue'); Lo := 0;
    If CurTokType <> TOK_DOTDOT Then Consume;
  End;

  Expect(TOK_DOTDOT, '`..` attendu dans contrainte RANGE');

  { --- Borne superieure --- }
  If CurTokType = TOK_INTEGER Then
  Begin Hi := CurTokNum; Consume; End
  Else If CurTokType = TOK_MINUS Then
  Begin Consume;
    If CurTokType = TOK_INTEGER Then
    Begin Hi := -CurTokNum; Consume; End
    Else Begin Error('Entier attendu apres -'); Hi := Lo; End;
  End
  Else If (CurTokType = TOK_IDENT) And (CurTokKw = KW_TRUE) Then
  Begin Hi := 1; Consume; End
  Else If (CurTokType = TOK_IDENT) And (CurTokKw = KW_FALSE) Then
  Begin Hi := 0; Consume; End
  Else If (CurTokType = TOK_IDENT) And (EnumTi > 0) And
          (TypeTab[EnumTi].Kind = TK_ENUM) Then
  Begin
    LitNm := StrUpperCase(CurTokStr);
    Hi := -1;
    For I := 1 To TypeTab[EnumTi].EnumCount Do
      If TypeTab[EnumTi].EnumNames[I] = LitNm Then
      Begin Hi := I - 1; Break; End;
    If Hi < 0 Then
    Begin Error('Litteral enumere inconnu : ' + LitNm); Hi := Lo; End;
    Consume;
  End
  Else
  Begin Error('Borne superieure entiere attendue'); Hi := Lo;
    Consume;
  End;
End;

{ ---- ParseRangeBounds : lire lo .. hi (sans contexte enum) --- }
Procedure ParseRangeBounds(Var Lo, Hi : LongInt);
Begin
  ParseRangeBoundsEx(Lo, Hi, 0);
End;

{ ---- ParseEnumType : ( lit1, lit2, ... ) -> TK_ENUM ---------- }
Function ParseEnumType(Const TName : TString) : Integer;
Var
  Idx : Integer;
  Cnt : Integer;
Begin
  Idx := AddType(TName, TK_ENUM);
  TypeTab[Idx].EnumCount := 0;
  Consume; { ( }
  Cnt := 0;
  Repeat
    If CurTokType <> TOK_IDENT Then
    Begin Error('Litteral d''enumeration attendu'); Break; End;
    Inc(Cnt);
    If Cnt > MAX_ENUM Then
    Begin Error('Trop de litteraux dans enumeration'); Break; End;
    TypeTab[Idx].EnumNames[Cnt] := StrUpperCase(CurTokStr);
    Consume;
    If CurTokType = TOK_COMMA Then Consume Else Break;
  Until False;
  Expect(TOK_RPAREN, '`)` attendu en fin d''enumeration');
  TypeTab[Idx].EnumCount := Cnt;
  TypeTab[Idx].LoBound   := 0;
  TypeTab[Idx].HiBound   := Cnt - 1;
  TypeTab[Idx].TotalSize  := 4; { DWord - indice 32 bits }
  ParseEnumType := Idx;
End;

{ ---- ParseRangeType : RANGE lo .. hi -> TK_RANGE ------------- }
Function ParseRangeType(Const TName : TString;
                        BaseTi : Integer) : Integer;
Var
  Idx    : Integer;
  Lo, Hi : LongInt;
Begin
  ParseRangeBounds(Lo, Hi);
  Idx := AddType(TName, TK_RANGE);
  TypeTab[Idx].BaseType  := BaseTi;
  TypeTab[Idx].LoBound   := Lo;
  TypeTab[Idx].HiBound   := Hi;
  TypeTab[Idx].TotalSize := 4; { DWord 32 bits }
  ParseRangeType := Idx;
End;

{ ---- ParseArrayType : ARRAY ( lo..hi ) OF type -> TK_ARRAY -- }
Function ParseArrayType(Const TName : TString) : Integer;
Var
  Idx           : Integer;
  Lo, Hi        : LongInt;
  ElemTi        : Integer;
  Esz           : Integer;
  Unconstrained : Boolean;
  PeekName      : TString;
Begin
  Expect(TOK_LPAREN, '`(` attendu apres ARRAY');
  Unconstrained := False;
  If CurTokType = TOK_IDENT Then
  Begin
    PeekName := StrUpperCase(CurTokStr);
    Consume;
    If TokIsKw(KW_RANGE) Then
    Begin
      Consume; { RANGE }
      If CurTokType = TOK_LT Then
      Begin
        Consume;
        If CurTokType = TOK_GT Then Consume
        Else Error('`>` attendu dans ARRAY non contraint');
      End
      Else Error('`<>` attendu dans ARRAY non contraint');
      Unconstrained := True;
      Lo := 1; Hi := 0;
    End
    Else
    Begin
      { Fallback : c etait un entier ou debut lo..hi }
      Lo := 0; Hi := 0;
      ParseRangeBounds(Lo, Hi);
    End;
  End
  Else
  Begin
    Lo := 0; Hi := 0;
    ParseRangeBounds(Lo, Hi);
  End;
  Expect(TOK_RPAREN, '`)` attendu apres indices ARRAY');
  ExpectKw(KW_OF, 'OF');
  ElemTi := ParseTypeRef;
  Esz    := GetTypeSize(ElemTi);
  If Esz <= 0 Then Esz := 4;
  Idx := AddType(TName, TK_ARRAY);
  TypeTab[Idx].LoBound  := Lo;
  TypeTab[Idx].HiBound  := Hi;
  TypeTab[Idx].ElemType := ElemTi;
  TypeTab[Idx].ElemSize := Esz;
  If Unconstrained Then
    TypeTab[Idx].TotalSize := 0
  Else
    TypeTab[Idx].TotalSize := (Hi - Lo + 1) * Esz;
  ParseArrayType := Idx;
End;

{ ---- ParseRecordType : champ:type; ... END RECORD -> TK_REC - }
Function ParseRecordType(Const TName : TString) : Integer;
Var
  Idx   : Integer;
  Fi    : Integer;
  Fti   : Integer;
  Off   : Integer;
  Fsz   : Integer;
  FName : TString;
  J     : Integer;
Begin
  Idx := AddType(TName, TK_RECORD);
  Fi  := 0;
  Off := 0;
  While Not TokIsKw(KW_END) And (CurTokType <> TOK_EOF) Do
  Begin
    { NULL record : NULL ; }
    If TokIsKw(KW_NULL) Then
    Begin Consume; Expect(TOK_SEMI, '`;` attendu apres NULL');
      Continue; End;
    { Champ(s) }
    Repeat
      If CurTokType <> TOK_IDENT Then
      Begin Error('Nom de champ attendu'); Break; End;
      FName := StrUpperCase(CurTokStr);
      Consume;
      If CurTokType = TOK_COMMA Then
      Begin
        { Plusieurs noms : n1, n2 : type; -> stocker sans type }
        Inc(Fi);
        If Fi > MAX_FIELD Then
        Begin Error('Trop de champs dans RECORD'); Fi := MAX_FIELD; End;
        TypeTab[Idx].FieldNames[Fi] := FName;
        TypeTab[Idx].FieldTypes[Fi] := TYPE_UNKNOWN;
        TypeTab[Idx].FieldOffs[Fi]  := 0;
        Consume; { , }
        Continue;
      End;
      Expect(TOK_COLON, '`:` attendu apres nom de champ');
      Fti := ParseTypeRef;
      Fsz := GetTypeSize(Fti);
      If Fsz <= 0 Then Fsz := 4;
      Fsz := AlignDWord(Fsz);
      { Corriger les champs precedents sans type (multi-noms) }
      { n1, n2 : Integer; -> assigner type et offsets sequentiels }
      J := Fi;
      While (J >= 1) And
            (TypeTab[Idx].FieldTypes[J] = TYPE_UNKNOWN) Do Dec(J);
      Inc(J);
      While J <= Fi Do
      Begin
        TypeTab[Idx].FieldTypes[J] := Fti;
        TypeTab[Idx].FieldOffs[J]  := Off;
        Inc(Off, Fsz);
        Inc(J);
      End;
      { Ajouter le champ courant (dernier du groupe) }
      Inc(Fi);
      If Fi > MAX_FIELD Then
      Begin Error('Trop de champs dans RECORD'); Fi := MAX_FIELD; End;
      TypeTab[Idx].FieldNames[Fi] := FName;
      TypeTab[Idx].FieldTypes[Fi] := Fti;
      TypeTab[Idx].FieldOffs[Fi]  := Off;
      Inc(Off, Fsz);
      Break;
    Until False;
    Expect(TOK_SEMI, '`;` attendu apres declaration de champ');
  End;
  TypeTab[Idx].FieldCount := Fi;
  TypeTab[Idx].TotalSize  := AlignDWord(Off);
  ExpectKw(KW_END, 'END');
  ExpectKw(KW_RECORD, 'RECORD');
  ParseRecordType := Idx;
End;

{ ---- ParseTypeDecl : TYPE nom IS definition ; --------------- }
Procedure ParseTypeDecl;
Var
  TName : TString;
  Idx   : Integer;
  Base  : Integer;
Begin
  Consume; { TYPE }
  If CurTokType <> TOK_IDENT Then
  Begin Error('Nom de type attendu apres TYPE'); Exit; End;
  TName := StrUpperCase(CurTokStr);
  Consume;
  ExpectKw(KW_IS, 'IS');

  { Enumeration : ( lit1, lit2, ... ) }
  If CurTokType = TOK_LPAREN Then
    Idx := ParseEnumType(TName)

  { RANGE lo .. hi }
  Else If TokIsKw(KW_RANGE) Then
  Begin
    Consume; { RANGE }
    Idx := ParseRangeType(TName, TYPE_INT);
  End

  { ARRAY ( ... ) OF type }
  Else If TokIsKw(KW_ARRAY) Then
  Begin
    Consume; { ARRAY }
    Idx := ParseArrayType(TName);
  End

  { RECORD ... END RECORD }
  Else If TokIsKw(KW_RECORD) Then
  Begin
    Consume; { RECORD }
    Idx := ParseRecordType(TName);
  End

  { NEW basetype }
  Else If TokIsKw(KW_NEW) Then
  Begin
    Consume; { NEW }
    Base := ParseTypeRef;
    Idx  := AddType(TName, TK_DERIVED);
    TypeTab[Idx].BaseType  := Base;
    TypeTab[Idx].TotalSize := GetTypeSize(Base);
  End

  { ACCESS basetype }
  Else If TokIsKw(KW_ACCESS) Then
  Begin
    Consume; { ACCESS }
    Base := ParseTypeRef;
    Idx  := AddType(TName, TK_ACCESS);
    TypeTab[Idx].BaseType  := Base;
    TypeTab[Idx].TotalSize := 4; { pointeur 32 bits }
  End

  Else
  Begin
    Error('Definition de type inconnue apres IS');
    Idx := 0;
  End;

  Expect(TOK_SEMI, '`;` attendu en fin de declaration de type');
End;

{ ---- ParseSubtypeDecl : SUBTYPE nom IS base [RANGE] ; ------- }
Procedure ParseSubtypeDecl;
Var
  SName : TString;
  Base  : Integer;
  Idx   : Integer;
  Lo, Hi: LongInt;
Begin
  Consume; { SUBTYPE }
  If CurTokType <> TOK_IDENT Then
  Begin Error('Nom de sous-type attendu apres SUBTYPE'); Exit; End;
  SName := StrUpperCase(CurTokStr);
  Consume;
  ExpectKw(KW_IS, 'IS');
  Base := ParseTypeRef;

  { Contrainte RANGE optionnelle }
  If TokIsKw(KW_RANGE) Then
  Begin
    Consume; { RANGE }
    ParseRangeBoundsEx(Lo, Hi, Base);
    Idx := AddType(SName, TK_RANGE);
    TypeTab[Idx].BaseType  := Base;
    TypeTab[Idx].LoBound   := Lo;
    TypeTab[Idx].HiBound   := Hi;
    TypeTab[Idx].TotalSize := 4; { DWord 32 bits }
  End
  Else
  Begin
    Idx := AddType(SName, TK_DERIVED);
    TypeTab[Idx].BaseType  := Base;
    TypeTab[Idx].TotalSize := GetTypeSize(Base);
  End;

  Expect(TOK_SEMI, '`;` attendu en fin de declaration de sous-type');
End;

{ ============================================================ }
{ TODO 11 - PARSEUR : DECLARATIONS D'OBJETS                    }
{ (VARIABLES ET CONSTANTES) - 32 BITS                          }
{ ============================================================ }

{ ---- ParseConstExpr32 : evaluer une expression constante ----- }
{ Si l expression est un litteral simple (entier, char, TRUE,     }
{ FALSE, enum), met la valeur dans Val et retourne True.          }
{ Sinon, genere du code (ParseExpr) et retourne False             }
{ (valeur dans EAX a l execution).                                }
Function ParseConstExpr32(Var Val : LongInt) : Boolean;
Var
  Neg : Boolean;
Begin
  { Entier negatif }
  Neg := False;
  If CurTokType = TOK_MINUS Then
  Begin
    Neg := True;
    Consume;
    If CurTokType = TOK_INTEGER Then
    Begin
      Val := -CurTokNum;
      Consume;
      ParseConstExpr32 := True;
      Exit;
    End;
    { Pas un entier apres le '-', on genere du code }
    ParseExpr;
    Val := 0;
    ParseConstExpr32 := False;
    Exit;
  End;
  { Litteral entier }
  If CurTokType = TOK_INTEGER Then
  Begin
    Val := CurTokNum;
    Consume;
    ParseConstExpr32 := True;
    Exit;
  End;
  { Litteral caractere }
  If CurTokType = TOK_CHAR Then
  Begin
    If Length(CurTokStr) > 0 Then
      Val := Ord(CurTokStr[1])
    Else
      Val := 0;
    Consume;
    ParseConstExpr32 := True;
    Exit;
  End;
  { TRUE / FALSE }
  If (CurTokType = TOK_IDENT) And (CurTokKw = KW_TRUE) Then
  Begin
    Val := 1; Consume;
    ParseConstExpr32 := True;
    Exit;
  End;
  If (CurTokType = TOK_IDENT) And (CurTokKw = KW_FALSE) Then
  Begin
    Val := 0; Consume;
    ParseConstExpr32 := True;
    Exit;
  End;
  { Expression generale : generer du code via ParseExpr }
  ParseExpr;
  Val := 0;
  ParseConstExpr32 := False;
End;

{ ---- GenVarData32 : emettre la zone .DATA d une variable glob. }
{ Produit le label ASM suivi de DD/DQ/DB selon le type.           }
Procedure GenVarData32(SymIdx : Integer);
Var
  TI  : Integer;
  Sz  : Integer;
  N   : LongInt;
  K   : Integer;
Begin
  TI := SymTab[SymIdx].TypeIdx;
  Sz := GetSymSize(SymIdx);

  { Label ASM }
  Emit(SymTab[SymIdx].AsmLabel + ':');

  { Contenu selon le type }
  If TI = TYPE_FLOAT Then
  Begin
    { 8 octets (DQ) - valeur flottante stub, on emet 0 }
    N := SymTab[SymIdx].InitNum;
    EmitI('DQ 0');
  End
  Else If (TI = TYPE_CHAR) Or (TI = TYPE_BOOL) Then
  Begin
    N := SymTab[SymIdx].InitNum;
    EmitI('DB ' + IntToStr_(N));
    { Padding pour alignement DWORD }
    EmitI('DB 0, 0, 0');
  End
  Else If TI = TYPE_STR Then
  Begin
    N := SymTab[SymIdx].CharLen;
    If N <= 0 Then N := 1;
    EmitI('DB ' + IntToStr_(N) + ' DUP(0)');
  End
  Else
  Begin
    { Verifier si c est un type utilisateur }
    If (TI > TYPE_STR) And (TI <= TypeCount) Then
    Begin
      K := TypeTab[TI].Kind;
      If K = TK_ARRAY Then
      Begin
        { Tableau : TotalSize octets a zero }
        If Sz > 0 Then
        Begin
          If (Sz Mod 4) = 0 Then
            EmitI('DD ' + IntToStr_(Sz Div 4) + ' DUP(0)')
          Else
            EmitI('DB ' + IntToStr_(Sz) + ' DUP(0)');
        End
        Else
          EmitI('DD 0');
      End
      Else If K = TK_RECORD Then
      Begin
        If Sz > 0 Then
          EmitI('DB ' + IntToStr_(Sz) + ' DUP(0)')
        Else
          EmitI('DD 0');
      End
      Else If K = TK_ENUM Then
      Begin
        { Enumere : DWord (4 octets) }
        N := SymTab[SymIdx].InitNum;
        EmitI('DD ' + IntToStr_(N));
      End
      Else
      Begin
        { Range, Derived, Access, ... -> DD }
        N := SymTab[SymIdx].InitNum;
        EmitI('DD ' + IntToStr_(N));
      End;
    End
    Else
    Begin
      { Scalaire entier / enum / range / pointeur : DD }
      N := SymTab[SymIdx].InitNum;
      EmitI('DD ' + IntToStr_(N));
    End;
  End;
End;

{ ---- ParseObjectDecl : parseur d une declaration d objet ------ }
{ Syntaxe : nom [, nom2 ...] : [CONSTANT] type [:= expr] ;       }
{ Gere variables globales (.DATA), locales (pile), constantes.    }
Procedure ParseObjectDecl;
Var
  Names    : Array[1..16] of TString;
  NCount   : Integer;
  IsConst_ : Boolean;
  TI       : Integer;
  SC       : Integer;
  SymIdx   : Integer;
  HasInit_ : Boolean;
  InitVal  : LongInt;
  GotConst : Boolean;
  I        : Integer;
  Sz       : Integer;
  BaseTI   : Integer;
Begin
  { ===== Etape 1 : liste de noms (nom, nom2, ...) ===== }
  NCount := 0;
  Repeat
    If CurTokType <> TOK_IDENT Then
    Begin Error('Identifiant attendu dans declaration d''objet');
      Break; End;
    Inc(NCount);
    If NCount > 16 Then
    Begin Error('Trop de noms dans une declaration'); NCount := 16; End;
    Names[NCount] := StrUpperCase(CurTokStr);
    Consume;
    If CurTokType = TOK_COMMA Then Consume Else Break;
  Until False;

  Expect(TOK_COLON, '`:` attendu apres nom(s) de variable');

  { ===== Etape 2 : EXCEPTION (constante speciale) ===== }
  If TokIsKw(KW_EXCEPTION) Then
  Begin
    Consume; { EXCEPTION }
    For I := 1 To NCount Do
    Begin
      SymIdx := AddSym(Names[I], TYPE_INT, STORE_CONST);
      If SymIdx > 0 Then
      Begin
        SymTab[SymIdx].InitNum := I;
        SymTab[SymIdx].HasInit := True;
        SymTab[SymIdx].IsConst := True;
      End;
    End;
    Expect(TOK_SEMI, '`;` attendu apres declaration EXCEPTION');
    Exit;
  End;

  { ===== Etape 3 : detecter CONSTANT ===== }
  IsConst_ := False;
  If TokIsKw(KW_CONSTANT) Then
  Begin
    IsConst_ := True;
    Consume;
  End;

  { ===== Etape 4 : parser le type ===== }
  TI := ParseTypeRef;

  { ===== Etape 5 : classe d entreposage ===== }
  If IsConst_ Then
    SC := STORE_CONST
  Else If ScopeTop = 0 Then
    SC := STORE_STATIC
  Else
    SC := STORE_AUTO;

  { ===== Etape 6 : initialisation optionnelle [:= expr] ===== }
  HasInit_ := False;
  InitVal  := 0;
  GotConst := False;
  If CurTokType = TOK_COLONASSIGN Then
  Begin
    Consume;
    HasInit_  := True;
    GotConst  := ParseConstExpr32(InitVal);
  End;

  { ===== Etape 7 : creer les symboles ===== }
  For I := 1 To NCount Do
  Begin
    SymIdx := AddSym(Names[I], TI, SC);
    If SymIdx = 0 Then Continue;

    If HasInit_ Then
    Begin
      SymTab[SymIdx].HasInit := True;
      SymTab[SymIdx].InitNum := InitVal;
    End;

    { ===== Etape 8 : ajuster taille pour tableaux/records/strings }
    Sz := 4;
    If (TI > TYPE_STR) And (TI <= TypeCount) Then
      Sz := GetTypeSize(TI)
    Else
      Sz := PrimTypeSize32(TI);

    { Mise a jour ArraySize / CharLen pour types composites }
    BaseTI := TI;
    If (TI > TYPE_STR) And (TI <= TypeCount) Then
    Begin
      If TypeTab[TI].Kind = TK_ARRAY Then
      Begin
        SymTab[SymIdx].ArraySize := TypeTab[TI].HiBound -
                                     TypeTab[TI].LoBound + 1;
        SymTab[SymIdx].TypeIdx   := TypeTab[TI].ElemType;
        { Restaurer le TypeIdx au type utilisateur pour GenVarData }
        SymTab[SymIdx].TypeIdx   := TI;
      End
      Else If TypeTab[TI].Kind = TK_RECORD Then
      Begin
        { Rien de special, la taille est dans TotalSize }
      End;
    End
    Else If TI = TYPE_STR Then
    Begin
      SymTab[SymIdx].CharLen := Sz;
    End;

    { ===== Etape 9 : allouer espace pile pour variable locale ===== }
    If SC = STORE_AUTO Then
    Begin
      SymTab[SymIdx].BpOffset := AllocLocal(Sz);
    End;

    { ===== Etape 10 : emettre .DATA pour variable globale ===== }
    If SC = STORE_STATIC Then
      GenVarData32(SymIdx);
    { STORE_CONST : rien a emettre, valeur dans InitNum }
    { STORE_AUTO  : l espace est reserve par GenPrologue (SUB ESP, n) }
  End;

  Expect(TOK_SEMI, '`;` attendu en fin de declaration d''objet');
End;

{ ============================================================ }
{ TODO 12 - PARSEUR : SIGNATURES PROCEDURE ET FUNCTION          }
{ ============================================================ }

{ Forward declarations pour recursion mutuelle (TODO 12 / 13 / 14) }
Procedure ParseProcedureDecl; Forward;
Procedure ParseFunctionDecl; Forward;
Procedure ParseProcedureBody(SubIdx : Integer); Forward;
Procedure ParseFunctionBody(SubIdx : Integer); Forward;
Procedure ParsePackageDecl; Forward;
Procedure ParseSequenceOfStatements; Forward;

{ ---- ParseParamList : analyser la liste de parametres -------- }
{ Syntaxe Ada :                                                    }
{   ( nom [, nom2] : [IN | IN OUT | OUT] type [:= default] ;      }
{     nom3 : IN OUT type ; ... )                                   }
{ Remplit SubTab[SubIdx].ParamNames/ParamTypes/ParamModes.         }
Procedure ParseParamList(SubIdx : Integer);
Var
  Names     : Array[1..MAX_PARAM] of TString;
  NameCount : Integer;
  Mode      : Integer;
  TI        : Integer;
  I, Base   : Integer;
Begin
  If CurTokType <> TOK_LPAREN Then Exit;
  Consume; { skip '(' }

  While (CurTokType <> TOK_RPAREN) And (CurTokType <> TOK_EOF) Do
  Begin
    { Lire les noms de parametres separes par des virgules }
    NameCount := 0;
    While True Do
    Begin
      If CurTokType <> TOK_IDENT Then
      Begin Error('Nom de parametre attendu'); Exit; End;
      Inc(NameCount);
      If NameCount <= MAX_PARAM Then
        Names[NameCount] := CurTokStr;
      Consume;
      If CurTokType = TOK_COMMA Then Consume
      Else Break;
    End;

    { Attendre ':' }
    Expect(TOK_COLON, '`:`');

    { Mode optionnel : IN OUT / OUT / IN (defaut IN) }
    Mode := PARAM_IN;
    If TokIsKw(KW_INOUT) Then
    Begin Mode := PARAM_INOUT; Consume; End
    Else If TokIsKw(KW_OUT) Then
    Begin Mode := PARAM_OUT; Consume; End
    Else If TokIsKw(KW_IN) Then
    Begin
      Consume;
      { Verifier IN OUT (si le lexeur ne l a pas compose) }
      If TokIsKw(KW_OUT) Then
      Begin Mode := PARAM_INOUT; Consume; End;
    End;

    { Type du parametre }
    TI := ParseTypeRef;

    { Valeur par defaut optionnelle : := expr }
    If CurTokType = TOK_COLONASSIGN Then
    Begin
      Consume;
      Warning('Valeur par defaut de parametre ignoree (stub)');
      { Sauter l expression : avancer jusqu a ; ou ) }
      While (CurTokType <> TOK_SEMI) And (CurTokType <> TOK_RPAREN) And
            (CurTokType <> TOK_EOF) Do
        Consume;
    End;

    { Enregistrer chaque parametre dans SubTab }
    Base := SubTab[SubIdx].ParamCount;
    For I := 1 To NameCount Do
    Begin
      If Base + I <= MAX_PARAM Then
      Begin
        SubTab[SubIdx].ParamNames[Base + I] :=
          StrUpperCase(Names[I]);
        SubTab[SubIdx].ParamTypes[Base + I] := TI;
        SubTab[SubIdx].ParamModes[Base + I] := Mode;
      End;
    End;
    SubTab[SubIdx].ParamCount := Base + NameCount;

    { Separateur ';' entre groupes ou ')' pour finir }
    If CurTokType = TOK_SEMI Then Consume
    Else If CurTokType <> TOK_RPAREN Then
    Begin
      Error(''';'' ou '')'' attendu dans la liste de parametres');
      Exit;
    End;
  End;

  Expect(TOK_RPAREN, '`)`');
End;

{ ---- SkipProcBody : sauter un corps de sous-programme -------- }
{ Appele juste apres avoir consomme IS.                            }
{ Saute jusqu au END [nom] ; correspondant en gerant l imbrication }
{ des constructions Ada (IF, LOOP, CASE, DECLARE, nested subs).   }
Procedure SkipProcBody;
Var
  Depth  : Integer;
  PFWait : Boolean;
Begin
  Depth := 1;
  PFWait := False;
  While (CurTokType <> TOK_EOF) And (Depth > 0) Do
  Begin
    If TokIsKw(KW_PROCEDURE) Or TokIsKw(KW_FUNCTION) Or
       TokIsKw(KW_PACKAGE) Then
      PFWait := True
    Else If TokIsKw(KW_IS) And PFWait Then
    Begin
      Inc(Depth);
      PFWait := False;
    End
    Else If TokIsKw(KW_IF) Or TokIsKw(KW_LOOP) Or TokIsKw(KW_CASE) Or
            TokIsKw(KW_DECLARE) Or TokIsKw(KW_SELECT) Or
            TokIsKw(KW_RECORD) Then
    Begin
      Inc(Depth);
      PFWait := False;
    End
    Else If TokIsKw(KW_END) Then
    Begin
      Dec(Depth);
      PFWait := False;
      If Depth <= 0 Then
      Begin
        Consume; { END }
        { Sauter ce qui suit END : nom, IF, LOOP, CASE, etc. }
        While (CurTokType <> TOK_SEMI) And (CurTokType <> TOK_EOF) Do
          Consume;
        If CurTokType = TOK_SEMI Then Consume;
        Exit;
      End;
    End
    Else If CurTokType = TOK_SEMI Then
      PFWait := False;
    Consume;
  End;
End;

{ ============================================================ }
{ TODO 13 - PARSEUR : CORPS PROCEDURE ET FUNCTION (32 BITS)     }
{ ============================================================ }

{ ---- RegisterParams : enregistrer les parametres formels ----- }
{ Inscrit les parametres de SubTab[SubIdx] dans la table des       }
{ symboles comme STORE_PARAM avec des offsets EBP positifs.        }
{ Convention STDCALL : parametres empiles droite a gauche.          }
{ EBP+8 = premier parametre, EBP+12 = deuxieme, etc.              }
Procedure RegisterParams(SubIdx : Integer);
Var
  I, Off, SymIdx, TI, Mode : Integer;
Begin
  Off := 8;  { EBP+0 = old EBP, EBP+4 = ret addr, EBP+8 = 1st param }
  For I := 1 To SubTab[SubIdx].ParamCount Do
  Begin
    TI   := SubTab[SubIdx].ParamTypes[I];
    Mode := SubTab[SubIdx].ParamModes[I];

    SymIdx := AddSym(SubTab[SubIdx].ParamNames[I], TI, STORE_PARAM);
    If SymIdx > 0 Then
    Begin
      SymTab[SymIdx].BpOffset := Off;
      { OUT / INOUT : le parametre est une adresse (pointeur 32 bits) }
      If (Mode = PARAM_OUT) Or (Mode = PARAM_INOUT) Then
        Inc(Off, 4)
      Else
        Inc(Off, AlignDWord(GetTypeSize(TI)));
    End;
  End;
End;

{ ---- ParseDeclarativePart : partie declarative d un body ----- }
{ Parse entre IS (deja consomme) et BEGIN.                         }
{ Reconnaît : TYPE, SUBTYPE, declarations d objets (variables /    }
{ constantes), sous-programmes imbriques (PROCEDURE / FUNCTION),   }
{ et packages imbriques (PACKAGE).                                 }
Procedure ParseDeclarativePart;
Begin
  While (CurTokType <> TOK_EOF) And (Not TokIsKw(KW_BEGIN)) Do
  Begin
    If CurTokKw = KW_TYPE Then
      ParseTypeDecl
    Else If CurTokKw = KW_SUBTYPE Then
      ParseSubtypeDecl
    Else If CurTokKw = KW_PROCEDURE Then
      ParseProcedureDecl
    Else If CurTokKw = KW_FUNCTION Then
      ParseFunctionDecl
    Else If CurTokKw = KW_PACKAGE Then
      ParsePackageDecl
    Else If CurTokType = TOK_IDENT Then
      ParseObjectDecl
    Else
    Begin
      { Token inattendu dans la partie declarative }
      Error('Token inattendu dans la partie declarative : ' +
            CurTokStr);
      Consume;
    End;
  End;
End;

{ ---- SkipStatements : sauter les instructions jusqu a END ---- }
{ Saute les instructions d un bloc BEGIN..END en gerant les        }
{ constructions imbriquees : IF, LOOP, CASE, DECLARE, SELECT,     }
{ BEGIN, PROCEDURE/FUNCTION (body), EXCEPTION.                     }
{ S arrete juste avant END ou EXCEPTION (selon stop_at_except).    }
Procedure SkipStatements;
Var
  Depth  : Integer;
  PFWait : Boolean;
Begin
  Depth := 1;
  PFWait := False;
  While (CurTokType <> TOK_EOF) And (Depth > 0) Do
  Begin
    If TokIsKw(KW_PROCEDURE) Or TokIsKw(KW_FUNCTION) Or
       TokIsKw(KW_PACKAGE) Then
      PFWait := True
    Else If TokIsKw(KW_IS) And PFWait Then
    Begin
      Inc(Depth);
      PFWait := False;
    End
    Else If TokIsKw(KW_IF) Or TokIsKw(KW_LOOP) Or TokIsKw(KW_CASE) Or
            TokIsKw(KW_DECLARE) Or TokIsKw(KW_SELECT) Or
            TokIsKw(KW_BEGIN) Then
    Begin
      Inc(Depth);
      PFWait := False;
    End
    Else If TokIsKw(KW_END) Then
    Begin
      Dec(Depth);
      PFWait := False;
      If Depth <= 0 Then
        Exit;  { on s arrete AVANT de consommer END }
      { END intermediaire (END LOOP, END IF, END RECORD, etc.) :    }
      { consommer END puis sauter les tokens jusqu a ';'              }
      Consume; { END }
      While (CurTokType <> TOK_SEMI) And (CurTokType <> TOK_EOF) Do
        Consume;
      If CurTokType = TOK_SEMI Then Consume;
      Continue; { ne pas faire le Consume final }
    End
    Else If TokIsKw(KW_EXCEPTION) And (Depth = 1) Then
    Begin
      { EXCEPTION au niveau du bloc courant : on s arrete avant }
      Exit;
    End
    Else If CurTokType = TOK_SEMI Then
      PFWait := False;
    Consume;
  End;
End;

{ ============================================================ }
{ TODO 15 - PARSEUR : DISPATCHER PRINCIPAL DES INSTRUCTIONS    }
{ ============================================================ }

{ ---- IsEndBoundary : teste si le token courant est une fin --- }
{ Renvoie True si le token courant marque la fin d une sequence  }
{ d instructions : END, EXCEPTION, ELSIF, ELSE, WHEN, ou EOF.   }
Function IsEndBoundary : Boolean;
Begin
  IsEndBoundary :=
    (CurTokType = TOK_EOF) Or
    TokIsKw(KW_END) Or
    TokIsKw(KW_EXCEPTION) Or
    TokIsKw(KW_ELSIF) Or
    TokIsKw(KW_ELSE) Or
    TokIsKw(KW_WHEN);
End;

{ ---- ParseNull : instruction NULL ; -------------------------  }
Procedure ParseNull;
Begin
  Consume; { NULL }
  EmitComment('NULL;');
  Expect(TOK_SEMI, '`;` attendu apres NULL');
End;

{ ---- ParseReturn : instruction RETURN [expression] ; -------- }
{ Genere le code pour retourner d un sous-programme.              }
{ FUNCTION : evaluer expression -> EAX, JMP label_exit.          }
{ PROCEDURE : simple JMP label_exit.                             }
Procedure ParseReturn;
Var
  LblExit : TString;
Begin
  Consume; { RETURN }
  EmitComment('RETURN ...');
  LblExit := FindExitLabel;
  { Expression optionnelle (pour les fonctions) }
  If (CurTokType <> TOK_SEMI) And (CurTokType <> TOK_EOF) And
     (Not TokIsKw(KW_END)) And (Not TokIsKw(KW_EXCEPTION)) Then
  Begin
    ParseExpr;   { resultat dans EAX }
  End;
  { Sauter vers l epilogue }
  If LblExit <> '' Then
    EmitI('JMP  ' + LblExit)
  Else
    WarnMsg('RETURN en dehors d''un sous-programme');
  If CurTokType = TOK_SEMI Then Consume;
End;

{ ---- ParseRaise : instruction RAISE [exception_name] ; ------ }
{ Genere le code pour lever une exception (TODO 19).               }
{   RAISE nom ;   -> MOV [_ADART_CUREXC], id + JMP _ADAX_handler  }
{   RAISE ;       -> re-raise (JMP _ADAX_handler avec CUREXC actuel)}
Procedure ParseRaise;
Var
  LblEx   : TString;
  ExName  : TString;
  SymIdx  : Integer;
Begin
  Consume; { RAISE }
  LblEx := FindExceptLabel;
  If (CurTokType = TOK_IDENT) And (CurTokKw <> KW_END) And
     (CurTokKw <> KW_EXCEPTION) Then
  Begin
    ExName := StrUpperCase(CurTokStr);
    Consume; { nom de l exception }
    SymIdx := FindSym(ExName);
    If SymIdx > 0 Then
    Begin
      EmitComment('RAISE ' + ExName);
      EmitI('MOV  DWORD PTR [_ADART_CUREXC], ' +
            IntToStr_(SymTab[SymIdx].InitNum));
    End
    Else
    Begin
      WarnMsg('Exception inconnue : ' + ExName);
      EmitComment('RAISE ' + ExName + ' (inconnu)');
      EmitI('MOV  DWORD PTR [_ADART_CUREXC], 0');
    End;
  End
  Else
  Begin
    { RAISE sans nom : re-raise, garder CUREXC tel quel }
    EmitComment('RAISE (re-raise)');
  End;
  { Sauter vers le handler le plus proche }
  If LblEx <> '' Then
    EmitI('JMP  ' + LblEx)
  Else
  Begin
    { Pas de handler : terminer le programme avec ExitProcess(1) }
    EmitComment('(pas de handler - sortie programme)');
    EmitI('PUSH 1');
    EmitI('CALL ExitProcess');
  End;
  If CurTokType = TOK_SEMI Then Consume;
End;

{ ---- ParseExit : instruction EXIT [name] [WHEN cond] ; ------ }
{ Genere un saut vers le label de fin de la boucle englobante.    }
{ EXIT WHEN cond : saut conditionnel (TEST + JNZ).                }
Procedure ParseExit;
Var
  LblEnd : TString;
Begin
  Consume; { EXIT }
  EmitComment('EXIT ...');
  LblEnd := FindLoopEnd;
  { Skip optional loop name (identifier before WHEN or ;) }
  If (CurTokType = TOK_IDENT) And (CurTokKw <> KW_WHEN) Then
    Consume;
  If TokIsKw(KW_WHEN) Then
  Begin
    Consume; { WHEN }
    ParseExpr;
    EmitI('TEST EAX, EAX');
    If LblEnd <> '' Then
      EmitI('JNZ  ' + LblEnd)
    Else
      WarnMsg('EXIT WHEN en dehors d''une boucle');
  End
  Else
  Begin
    If LblEnd <> '' Then
      EmitI('JMP  ' + LblEnd)
    Else
      WarnMsg('EXIT en dehors d''une boucle');
  End;
  If CurTokType = TOK_SEMI Then Consume;
End;

{ ---- ParseGoto : instruction GOTO label ; -------------------- }
Procedure ParseGoto;
Begin
  Consume; { GOTO }
  EmitComment('GOTO ...');
  { Skip label name + ';' }
  While (CurTokType <> TOK_SEMI) And (CurTokType <> TOK_EOF) And
        (Not TokIsKw(KW_END)) And (Not TokIsKw(KW_EXCEPTION)) Do
    Consume;
  If CurTokType = TOK_SEMI Then Consume;
End;

{ ---- ParsePragma : instruction PRAGMA ident [(args)] ; ------- }
Procedure ParsePragma;
Begin
  Consume; { PRAGMA }
  EmitComment('PRAGMA ...');
  { Skip tout jusqu au ';' }
  While (CurTokType <> TOK_SEMI) And (CurTokType <> TOK_EOF) And
        (Not TokIsKw(KW_END)) And (Not TokIsKw(KW_EXCEPTION)) Do
    Consume;
  If CurTokType = TOK_SEMI Then Consume;
End;

{ ============================================================ }
{ TODO 17 - PARSEUR : IF/ELSIF/ELSE ET CASE/WHEN/OTHERS       }
{ ============================================================ }

{ ---- ParseIf : instruction IF / ELSIF / ELSE / END IF ------ }
{ Syntaxe Ada :                                                  }
{   IF condition THEN                                            }
{     sequence_of_statements                                     }
{   [ELSIF condition THEN                                        }
{     sequence_of_statements] ...                                }
{   [ELSE                                                        }
{     sequence_of_statements]                                    }
{   END IF ;                                                     }
{ Generation 32 bits :                                           }
{   ParseExpr -> EAX (condition)                                 }
{   TEST EAX, EAX + JZ label_next                                }
{   stmts + JMP label_endif                                      }
{   Chaine ELSIF/ELSE via labels successifs                      }
Procedure ParseIf;
Var
  LblNext   : TString;
  LblEndIf  : TString;
Begin
  EmitComment('IF ... THEN ... END IF');
  Consume; { IF }
  { Evaluer la condition -> EAX }
  ParseExpr;
  LblEndIf := NewLabel;
  LblNext  := NewLabel;
  EmitI('TEST EAX, EAX');
  EmitI('JZ   ' + LblNext);
  { Consommer THEN }
  ExpectKw(KW_THEN, 'THEN');
  { Parser le bloc THEN }
  ParseSequenceOfStatements;
  EmitI('JMP  ' + LblEndIf);
  EmitLabel(LblNext);
  { Chaine ELSIF }
  While TokIsKw(KW_ELSIF) Do
  Begin
    Consume; { ELSIF }
    EmitComment('ELSIF ...');
    ParseExpr;
    LblNext := NewLabel;
    EmitI('TEST EAX, EAX');
    EmitI('JZ   ' + LblNext);
    ExpectKw(KW_THEN, 'THEN');
    ParseSequenceOfStatements;
    EmitI('JMP  ' + LblEndIf);
    EmitLabel(LblNext);
  End;
  { Clause ELSE optionnelle }
  If TokIsKw(KW_ELSE) Then
  Begin
    Consume; { ELSE }
    EmitComment('ELSE');
    ParseSequenceOfStatements;
  End;
  EmitLabel(LblEndIf);
  { END IF ; }
  ExpectKw(KW_END, 'END');
  ExpectKw(KW_IF, 'IF');
  If CurTokType = TOK_SEMI Then Consume;
End;

{ ---- ParseCase : instruction CASE / WHEN / END CASE -------- }
{ Syntaxe Ada :                                                  }
{   CASE expression IS                                           }
{     WHEN valeur [| valeur2] => stmts                           }
{     [WHEN OTHERS => stmts]                                     }
{   END CASE ;                                                   }
{ Generation 32 bits :                                           }
{   ParseExpr -> EAX (expression selecteur)                      }
{   MOV EDX, EAX  (sauvegarder selecteur)                        }
{   Pour chaque WHEN : CMP EDX, imm / JE label_match             }
{   WHEN val1 | val2 : serie CMP + JE                            }
{   WHEN OTHERS = clause par defaut                              }
Procedure ParseCase;
Var
  LblNext   : TString;
  LblMatch  : TString;
  LblEndCase: TString;
  WVal      : LongInt;
  GotConst  : Boolean;
  HasOthers : Boolean;
Begin
  EmitComment('CASE ... IS ... END CASE');
  Consume; { CASE }
  { Evaluer l expression selecteur -> EAX }
  ParseExpr;
  EmitI('MOV  EDX, EAX');
  { Consommer IS }
  ExpectKw(KW_IS, 'IS');
  LblEndCase := NewLabel;
  HasOthers  := False;
  { Boucle WHEN }
  While TokIsKw(KW_WHEN) Do
  Begin
    Consume; { WHEN }
    { WHEN OTHERS => ... }
    If TokIsKw(KW_OTHERS) Then
    Begin
      Consume; { OTHERS }
      EmitComment('WHEN OTHERS =>');
      { Consommer => }
      If CurTokType = TOK_ARROW Then Consume;
      HasOthers := True;
      ParseSequenceOfStatements;
      EmitI('JMP  ' + LblEndCase);
    End
    Else
    Begin
      { WHEN valeur [| valeur2] => stmts }
      LblMatch := NewLabel;
      LblNext  := NewLabel;
      EmitComment('WHEN ...');
      { Premiere valeur }
      GotConst := ParseConstExpr32(WVal);
      If GotConst Then
      Begin
        EmitI('CMP  EDX, ' + IntToStr_(WVal));
        EmitI('JE   ' + LblMatch);
      End
      Else
      Begin
        { Valeur dynamique dans EAX }
        EmitI('CMP  EDX, EAX');
        EmitI('JE   ' + LblMatch);
      End;
      { Valeurs alternatives separees par | }
      While CurTokType = TOK_BAR Do
      Begin
        Consume; { | }
        GotConst := ParseConstExpr32(WVal);
        If GotConst Then
        Begin
          EmitI('CMP  EDX, ' + IntToStr_(WVal));
          EmitI('JE   ' + LblMatch);
        End
        Else
        Begin
          EmitI('CMP  EDX, EAX');
          EmitI('JE   ' + LblMatch);
        End;
      End;
      { Si aucune valeur ne correspond, sauter au prochain WHEN }
      EmitI('JMP  ' + LblNext);
      EmitLabel(LblMatch);
      { Consommer => }
      If CurTokType = TOK_ARROW Then Consume;
      ParseSequenceOfStatements;
      EmitI('JMP  ' + LblEndCase);
      EmitLabel(LblNext);
    End;
  End;
  EmitLabel(LblEndCase);
  { END CASE ; }
  ExpectKw(KW_END, 'END');
  ExpectKw(KW_CASE, 'CASE');
  If CurTokType = TOK_SEMI Then Consume;
End;

{ ============================================================ }
{ TODO 18 - PARSEUR : BOUCLES LOOP/WHILE/FOR ET EXIT           }
{ ============================================================ }

{ ---- ParseLoop : instruction LOOP ... END LOOP ; ------------ }
{ Syntaxe Ada :                                                  }
{   [label:] LOOP                                                }
{     sequence_of_statements                                     }
{   END LOOP [label] ;                                           }
{ Generation 32 bits :                                           }
{   _ADAL_top: corps + JMP _ADAL_top                              }
{   EXIT -> JMP _ADAL_end                                         }
Procedure ParseLoop;
Var
  LblTop  : TString;
  LblEnd  : TString;
Begin
  EmitComment('LOOP ... END LOOP');
  { Chercher LOOP keyword si pas encore consomme }
  While (CurTokType <> TOK_EOF) And (Not TokIsKw(KW_LOOP)) Do
    Consume;
  If TokIsKw(KW_LOOP) Then Consume; { LOOP }
  LblTop := NewLabel;
  LblEnd := NewLabel;
  { Enregistrer les labels de boucle pour EXIT }
  PushScope(SK_LOOP, 0);
  EnterLoop(LblTop, LblEnd);
  EmitLabel(LblTop);
  ParseSequenceOfStatements;
  EmitI('JMP  ' + LblTop);
  EmitLabel(LblEnd);
  PopScope;
  { END LOOP [name] ; }
  ExpectKw(KW_END, 'END');
  ExpectKw(KW_LOOP, 'LOOP');
  { Skip optional loop name }
  While (CurTokType <> TOK_SEMI) And (CurTokType <> TOK_EOF) Do
    Consume;
  If CurTokType = TOK_SEMI Then Consume;
End;

{ ---- ParseWhile : instruction WHILE ... LOOP ... END LOOP ; - }
{ Syntaxe Ada :                                                  }
{   WHILE condition LOOP                                         }
{     sequence_of_statements                                     }
{   END LOOP [label] ;                                           }
{ Generation 32 bits :                                           }
{   _ADAL_top: evaluer cond -> TEST EAX,EAX + JZ _ADAL_end       }
{   corps + JMP _ADAL_top                                         }
Procedure ParseWhile;
Var
  LblTop  : TString;
  LblEnd  : TString;
Begin
  EmitComment('WHILE ... LOOP ... END LOOP');
  Consume; { WHILE }
  LblTop := NewLabel;
  LblEnd := NewLabel;
  EmitLabel(LblTop);
  { Evaluer la condition -> EAX }
  ParseExpr;
  EmitI('TEST EAX, EAX');
  EmitI('JZ   ' + LblEnd);
  { Consommer LOOP }
  ExpectKw(KW_LOOP, 'LOOP');
  { Enregistrer labels pour EXIT }
  PushScope(SK_LOOP, 0);
  EnterLoop(LblTop, LblEnd);
  ParseSequenceOfStatements;
  EmitI('JMP  ' + LblTop);
  EmitLabel(LblEnd);
  PopScope;
  { END LOOP [name] ; }
  ExpectKw(KW_END, 'END');
  ExpectKw(KW_LOOP, 'LOOP');
  { Skip optional loop name }
  While (CurTokType <> TOK_SEMI) And (CurTokType <> TOK_EOF) Do
    Consume;
  If CurTokType = TOK_SEMI Then Consume;
End;

{ ---- ParseFor : instruction FOR ... IN ... LOOP ... END LOOP  }
{ Syntaxe Ada :                                                  }
{   FOR ident IN [REVERSE] lo .. hi LOOP                         }
{     sequence_of_statements                                     }
{   END LOOP [label] ;                                           }
{ Generation 32 bits :                                           }
{   Variable implicite [EBP-n] (STORE_AUTO)                       }
{   Normal: init=lo, CMP counter,hi + JG end, corps, INC, JMP top }
{   REVERSE: init=hi, CMP counter,lo + JL end, corps, DEC, JMP top}
Procedure ParseFor;
Var
  LblTop    : TString;
  LblEnd    : TString;
  VarName   : TString;
  SymIdx    : Integer;
  LoVal     : LongInt;
  HiVal     : LongInt;
  GotLo     : Boolean;
  GotHi     : Boolean;
  IsReverse : Boolean;
  Off       : Integer;
Begin
  EmitComment('FOR ... IN ... LOOP ... END LOOP');
  Consume; { FOR }
  { Nom de la variable de boucle }
  VarName := CurTokStr;
  Consume; { ident }
  ExpectKw(KW_IN, 'IN');
  { REVERSE optionnel }
  IsReverse := TokIsKw(KW_REVERSE);
  If IsReverse Then Consume; { REVERSE }
  { Bornes : lo .. hi }
  GotLo := ParseConstExpr32(LoVal);
  Expect(TOK_DOTDOT, '`..` attendu dans FOR');
  GotHi := ParseConstExpr32(HiVal);
  { Consommer LOOP }
  ExpectKw(KW_LOOP, 'LOOP');
  { Creer un scope de boucle }
  PushScope(SK_LOOP, 0);
  LblTop := NewLabel;
  LblEnd := NewLabel;
  EnterLoop(LblTop, LblEnd);
  { Creer la variable de boucle (STORE_AUTO, lecture seule) }
  SymIdx := AddSym(VarName, TYPE_INT, STORE_AUTO);
  Off := AllocLocal(4);
  SymTab[SymIdx].BpOffset := Off;
  { Initialiser le compteur }
  If IsReverse Then
  Begin
    { REVERSE : init = hi, decrementer vers lo }
    If GotHi Then
      EmitI('MOV  DWORD PTR [EBP' + BpOff32(Off) + '], ' + IntToStr_(HiVal))
    Else
    Begin
      { hi est dans EAX apres ParseConstExpr32 }
      EmitI('MOV  DWORD PTR [EBP' + BpOff32(Off) + '], EAX');
    End;
    EmitLabel(LblTop);
    { Condition : counter >= lo }
    EmitI('MOV  EAX, DWORD PTR [EBP' + BpOff32(Off) + ']');
    If GotLo Then
      EmitI('CMP  EAX, ' + IntToStr_(LoVal))
    Else
      EmitI('CMP  EAX, 0');   { fallback si lo non constante }
    EmitI('JL   ' + LblEnd);
  End
  Else
  Begin
    { Normal : init = lo, incrementer vers hi }
    If GotLo Then
      EmitI('MOV  DWORD PTR [EBP' + BpOff32(Off) + '], ' + IntToStr_(LoVal))
    Else
    Begin
      { lo est dans EAX }
      EmitI('MOV  DWORD PTR [EBP' + BpOff32(Off) + '], EAX');
    End;
    EmitLabel(LblTop);
    { Condition : counter <= hi }
    EmitI('MOV  EAX, DWORD PTR [EBP' + BpOff32(Off) + ']');
    If GotHi Then
      EmitI('CMP  EAX, ' + IntToStr_(HiVal))
    Else
      EmitI('CMP  EAX, 0');   { fallback si hi non constante }
    EmitI('JG   ' + LblEnd);
  End;
  { Corps de la boucle }
  ParseSequenceOfStatements;
  { Incrementer/decrementer le compteur }
  If IsReverse Then
    EmitI('DEC  DWORD PTR [EBP' + BpOff32(Off) + ']')
  Else
    EmitI('INC  DWORD PTR [EBP' + BpOff32(Off) + ']');
  EmitI('JMP  ' + LblTop);
  EmitLabel(LblEnd);
  PopScope;
  { END LOOP [name] ; }
  ExpectKw(KW_END, 'END');
  ExpectKw(KW_LOOP, 'LOOP');
  { Skip optional loop name }
  While (CurTokType <> TOK_SEMI) And (CurTokType <> TOK_EOF) Do
    Consume;
  If CurTokType = TOK_SEMI Then Consume;
End;

{ ---- ParseBeginBlock : bloc BEGIN ... END ; ------------------- }
{ Bloc anonyme imbrique dans une sequence d instructions.         }
Procedure ParseBeginBlock;
Var Depth : Integer;
Begin
  EmitComment('BEGIN block ...');
  Consume; { BEGIN }
  Depth := 1;
  While (CurTokType <> TOK_EOF) And (Depth > 0) Do
  Begin
    If TokIsKw(KW_BEGIN) Or TokIsKw(KW_IF) Or TokIsKw(KW_LOOP) Or
       TokIsKw(KW_CASE) Or TokIsKw(KW_DECLARE) Or
       TokIsKw(KW_SELECT) Then
      Inc(Depth)
    Else If TokIsKw(KW_END) Then
    Begin
      Dec(Depth);
      If Depth <= 0 Then
      Begin
        Consume; { END }
        { Skip optional name + ';' }
        While (CurTokType <> TOK_SEMI) And (CurTokType <> TOK_EOF) Do
          Consume;
        If CurTokType = TOK_SEMI Then Consume;
        Exit;
      End;
    End;
    Consume;
  End;
End;

{ ---- ParseDeclareBlock : DECLARE ... BEGIN ... END ; ---------- }
{ Bloc avec partie declarative locale.                            }
{ Structure : DECLARE decls BEGIN stmts END [name] ;              }
{ Le BEGIN fait partie de la structure DECLARE et ne cree pas      }
{ un niveau supplementaire.                                        }
Procedure ParseDeclareBlock;
Var
  Depth    : Integer;
  GotBegin : Boolean;
Begin
  EmitComment('DECLARE block ...');
  Consume; { DECLARE }
  Depth := 1;
  GotBegin := False;
  While (CurTokType <> TOK_EOF) And (Depth > 0) Do
  Begin
    If TokIsKw(KW_BEGIN) And (Not GotBegin) Then
    Begin
      { Le BEGIN du DECLARE : ne pas incrementer depth }
      GotBegin := True;
      Consume;
      Continue;
    End
    Else If TokIsKw(KW_BEGIN) Or TokIsKw(KW_IF) Or TokIsKw(KW_LOOP) Or
       TokIsKw(KW_CASE) Or TokIsKw(KW_DECLARE) Or
       TokIsKw(KW_SELECT) Then
      Inc(Depth)
    Else If TokIsKw(KW_END) Then
    Begin
      Dec(Depth);
      If Depth <= 0 Then
      Begin
        Consume; { END }
        While (CurTokType <> TOK_SEMI) And (CurTokType <> TOK_EOF) Do
          Consume;
        If CurTokType = TOK_SEMI Then Consume;
        Exit;
      End;
    End;
    Consume;
  End;
End;

{ ============================================================ }
{ TODO 16 - PARSEUR : AFFECTATION ET APPELS DE PROCEDURE        }
{ ============================================================ }

{ ---- GenLoadAddr : charger l adresse d un symbole dans EAX --- }
{ LEA EAX, [variable] pour passage par adresse (OUT/INOUT).      }
Procedure GenLoadAddr(SymIdx : Integer);
Var
  SC, Off : Integer;
  Lbl     : TString;
Begin
  SC  := SymTab[SymIdx].StoreClass;
  Off := SymTab[SymIdx].BpOffset;
  Lbl := SymTab[SymIdx].AsmLabel;
  Case SC Of
    STORE_STATIC :
      EmitI('LEA  EAX, [' + Lbl + ']');
    STORE_AUTO :
      EmitI('LEA  EAX, [EBP' + BpOff32(Off) + ']');
    STORE_PARAM :
      EmitI('LEA  EAX, [EBP' + BpOff32(Off) + ']');
  Else
    Error('Impossible d''obtenir l''adresse de : ' +
          SymTab[SymIdx].Name);
    EmitI('XOR  EAX, EAX');
  End;
End;

{ ---- ParseAssignment : affectation (TODO 16) ----------------- }
{ Syntaxe : target := expr ;                                      }
{ Le nom de la cible est deja lu et passe dans SavedName.         }
{ Le token ':=' a deja ete consomme.                              }
{ On parse l expression RHS puis on stocke dans la variable.      }
Procedure ParseAssignment(Const TargetName : TString);
Var
  Sym, TI, FI : Integer;
  FN           : TString;
Begin
  EmitComment('assign ' + TargetName + ' := ...');
  { Trouver le symbole cible }
  Sym := FindSym(TargetName);
  If Sym <= 0 Then
  Begin
    Error('Variable inconnue pour assignation : ' + TargetName);
    ParseExpr;
    If CurTokType = TOK_SEMI Then Consume;
    Exit;
  End;
  { Verifier affectation agregat record : Rec := (F1 => V1, ...) }
  TI := SymTab[Sym].TypeIdx;
  If (CurTokType = TOK_LPAREN) And
     (TI > TYPE_STR) And (TI <= TypeCount) And
     (TypeTab[TI].Kind = TK_RECORD) Then
  Begin
    { Tester si c est un agregat : ( ident => expr , ... ) }
    { Heuristique: on regarde si le prochain token apres ( est ident => }
    { On consomme ( et on traite champ par champ }
    EmitComment('record aggregate ' + TargetName + ' := (...)');
    Consume; { ( }
    While (CurTokType <> TOK_RPAREN) And (CurTokType <> TOK_EOF) Do
    Begin
      If CurTokType <> TOK_IDENT Then
      Begin
        { Pas un nom de champ : traiter comme expression }
        Warning('Nom de champ attendu dans agregat record');
        ParseExpr;
        If CurTokType = TOK_COMMA Then Consume;
        Continue;
      End;
      FN := CurTokStr;
      Consume; { field name }
      If CurTokType = TOK_ARROW Then
      Begin
        Consume; { => }
        FI := FindFieldIdx(TI, FN);
        If FI <= 0 Then
        Begin
          Error('Champ inconnu dans agregat : ' + FN);
          ParseExpr; { skip value }
        End
        Else
        Begin
          ParseExpr; { EAX = valeur }
          GenStoreField(Sym, FI);
        End;
      End
      Else
      Begin
        { Pas un =>  : probablement OTHERS => val }
        If StrUpperCase(FN) = 'OTHERS' Then
        Begin
          If CurTokType = TOK_ARROW Then Consume;
          ParseExpr;
          { Stocker dans tous les champs non encore initialises }
          For FI := 1 To TypeTab[TI].FieldCount Do
            GenStoreField(Sym, FI);
        End
        Else
        Begin
          Error('`=>` attendu apres nom de champ dans agregat');
          ParseExpr;
        End;
      End;
      If CurTokType = TOK_COMMA Then Consume;
    End;
    Expect(TOK_RPAREN, '`)` attendu apres agregat record');
    If CurTokType = TOK_SEMI Then Consume;
    Exit;
  End;
  { Assignation simple : evaluer RHS et stocker }
  ParseExpr;
  GenStoreVar(Sym);
  { Consommer le point-virgule }
  If CurTokType = TOK_SEMI Then Consume;
End;

{ ============================================================ }
{ TODO 22 - STUBS ADA.TEXT_IO : SORTIE CONSOLE WIN32           }
{ ============================================================ }

{ ---- DetectArgTypeForPut : detecter le type d argument ------- }
{ Examine le token courant pour determiner le type de l argument }
{ AVANT d appeler ParseExpr. Retourne TYPE_INT, TYPE_STR,        }
{ TYPE_CHAR ou TYPE_BOOL.                                        }
Function DetectArgTypeForPut : Integer;
Var
  Sym : Integer;
Begin
  Case CurTokType Of
    TOK_INTEGER : DetectArgTypeForPut := TYPE_INT;
    TOK_STRING  : DetectArgTypeForPut := TYPE_STR;
    TOK_CHAR    : DetectArgTypeForPut := TYPE_CHAR;
    TOK_IDENT   :
      Begin
        If (CurTokKw = KW_TRUE) Or (CurTokKw = KW_FALSE) Then
          DetectArgTypeForPut := TYPE_BOOL
        Else
        Begin
          Sym := FindSym(CurTokStr);
          If Sym > 0 Then
            DetectArgTypeForPut := SymTab[Sym].TypeIdx
          Else
            DetectArgTypeForPut := TYPE_INT;
        End;
      End;
  Else
    DetectArgTypeForPut := TYPE_INT;
  End;
End;

{ ---- GenTextIOPutInline : Put/Put_Line type-dispatched ------- }
{ Genere un appel inline a _ADART_PRINTINT, _ADART_PRINT ou     }
{ _ADART_PRINTCHR selon le type de l argument.                   }
{ Si IsLine est vrai, ajoute un CALL _ADART_CRLF apres.         }
Procedure GenTextIOPutInline(IsLine : Boolean);
Var
  ArgTy : Integer;
Begin
  If IsLine Then
    EmitComment('Ada.Text_IO.Put_Line (type-dispatched)')
  Else
    EmitComment('Ada.Text_IO.Put (type-dispatched)');

  If CurTokType = TOK_LPAREN Then
  Begin
    Consume; { ( }
    ArgTy := DetectArgTypeForPut;
    ParseExpr;
    Expect(TOK_RPAREN, '`)` attendu apres argument Put');
    { Dispatcher selon le type }
    Case ArgTy Of
      TYPE_STR :
        Begin
          EmitI('PUSH EAX');
          EmitI('CALL ' + ADA_RT_PFX + 'PRINT');
        End;
      TYPE_CHAR :
        Begin
          EmitI('PUSH EAX');
          EmitI('CALL ' + ADA_RT_PFX + 'PRINTCHR');
        End;
    Else
      Begin
        { Integer, Boolean, enum, etc. -> PRINTINT }
        EmitI('PUSH EAX');
        EmitI('CALL ' + ADA_RT_PFX + 'PRINTINT');
      End;
    End;
  End
  Else
  Begin
    { Put / Put_Line sans arguments -> New_Line equivalent }
    If IsLine Then
    Begin
      EmitI('CALL ' + ADA_RT_PFX + 'CRLF');
      If CurTokType = TOK_SEMI Then Consume;
      Exit;
    End;
  End;

  { Put_Line : ajouter retour a la ligne }
  If IsLine Then
    EmitI('CALL ' + ADA_RT_PFX + 'CRLF');

  If CurTokType = TOK_SEMI Then Consume;
End;

{ ---- GenTextIONewLineInline : New_Line [(n)] ----------------- }
{ Emettre n CR+LF via CALL _ADART_CRLF. Defaut n = 1.          }
Procedure GenTextIONewLineInline;
Var
  LblTop, LblEnd : TString;
Begin
  EmitComment('Ada.Text_IO.New_Line');
  If CurTokType = TOK_LPAREN Then
  Begin
    Consume; { ( }
    ParseExpr;  { EAX = nombre de lignes }
    Expect(TOK_RPAREN, '`)` attendu apres argument New_Line');
    { Boucle : repeter EAX fois CALL _ADART_CRLF }
    EmitI('MOV  ECX, EAX');
    LblTop := NewLabel;
    LblEnd := NewLabel;
    EmitLabel(LblTop);
    EmitI('TEST ECX, ECX');
    EmitI('JZ   ' + LblEnd);
    EmitI('PUSH ECX');
    EmitI('CALL ' + ADA_RT_PFX + 'CRLF');
    EmitI('POP  ECX');
    EmitI('DEC  ECX');
    EmitI('JMP  ' + LblTop);
    EmitLabel(LblEnd);
  End
  Else
    { Par defaut : 1 New_Line }
    EmitI('CALL ' + ADA_RT_PFX + 'CRLF');

  If CurTokType = TOK_SEMI Then Consume;
End;

{ ---- GenTextIOSetColInline : Set_Col (stub warning) ---------- }
{ Genere un avertissement : Set_Col non implemente.              }
Procedure GenTextIOSetColInline;
Begin
  EmitComment('Ada.Text_IO.Set_Col (stub)');
  Warning('Ada.Text_IO.Set_Col non implemente, appel ignore');
  If CurTokType = TOK_LPAREN Then
  Begin
    Consume; { ( }
    ParseExpr;  { skip l argument }
    Expect(TOK_RPAREN, '`)` attendu apres argument Set_Col');
  End;
  If CurTokType = TOK_SEMI Then Consume;
End;

{ ---- IsTextIOProc : detecter un appel Ada.Text_IO ------------ }
{ Retourne le nom court de la procedure Text_IO (PUT, PUT_LINE,  }
{ NEW_LINE, SET_COL, GET, GET_LINE) ou '' si ce n est pas un     }
{ appel Text_IO reconnu.                                         }
Function IsTextIOProc(Const ProcName : TString) : TString;
Var
  U : TString;
Begin
  U := StrUpperCase(ProcName);
  IsTextIOProc := '';
  { Formes : Ada.Text_IO.Put_Line, Text_IO.Put_Line, Put_Line }
  If Length(U) > 14 Then
    If Copy(U, 1, 14) = 'ADA.TEXT_IO.' Then
    Begin
      IsTextIOProc := Copy(U, 15, Length(U) - 14);
      Exit;
    End;
  If Length(U) > 8 Then
    If Copy(U, 1, 8) = 'TEXT_IO.' Then
    Begin
      IsTextIOProc := Copy(U, 9, Length(U) - 8);
      Exit;
    End;
  { Nom court direct (si enregistre dans SubTab via GenTextIOStubs) }
  If (U = 'PUT') Or (U = 'PUT_LINE') Or (U = 'NEW_LINE') Or
     (U = 'SET_COL') Then
    IsTextIOProc := U;
End;

{ ---- ParseProcedureCall : appel de procedure (TODO 16) ------- }
{ Syntaxe : nom [(arg1, arg2, ...)] ;                              }
{ Le nom de la procedure est deja lu et passe dans SavedName.     }
{ ParseExpr pour chaque argument. PUSH EAX pour IN,                }
{ LEA + PUSH pour OUT/INOUT. CALL label. STDCALL callee-cleanup.   }
{ TODO 22 : gestion type-dispatched pour Put/Put_Line/New_Line.    }
Procedure ParseProcedureCall(Const ProcName : TString);
Var
  Sub, I   : Integer;
  ArgCount : Integer;
  ArgSym   : Integer;
  ArgName  : TString;
  TIOProc  : TString;
Begin
  { TODO 22 : intercepter les appels Ada.Text_IO }
  TIOProc := IsTextIOProc(ProcName);
  If TIOProc <> '' Then
  Begin
    If TIOProc = 'PUT' Then
    Begin GenTextIOPutInline(False); Exit; End;
    If TIOProc = 'PUT_LINE' Then
    Begin GenTextIOPutInline(True); Exit; End;
    If TIOProc = 'NEW_LINE' Then
    Begin GenTextIONewLineInline; Exit; End;
    If TIOProc = 'SET_COL' Then
    Begin GenTextIOSetColInline; Exit; End;
    { GET / GET_LINE : passer au traitement normal (stubs existants) }
  End;

  Sub := FindSub(ProcName);
  If Sub > 0 Then
  Begin
    EmitComment('call ' + ProcName);
    ArgCount := 0;
    { Parser les arguments si ( est present }
    If CurTokType = TOK_LPAREN Then
    Begin
      Consume; { ( }
      While (CurTokType <> TOK_RPAREN) And (CurTokType <> TOK_EOF) Do
      Begin
        Inc(ArgCount);
        { Verifier le mode du parametre }
        If (ArgCount <= SubTab[Sub].ParamCount) And
           ((SubTab[Sub].ParamModes[ArgCount] = PARAM_OUT) Or
            (SubTab[Sub].ParamModes[ArgCount] = PARAM_INOUT)) Then
        Begin
          { Passage par adresse : LEA EAX, [var] + PUSH EAX }
          If CurTokType = TOK_IDENT Then
          Begin
            ArgName := CurTokStr;
            Consume;
            ArgSym := FindSym(ArgName);
            If ArgSym > 0 Then
              GenLoadAddr(ArgSym)
            Else
            Begin
              Error('Variable inconnue pour parametre OUT/INOUT : ' +
                    ArgName);
              EmitI('XOR  EAX, EAX');
            End;
          End
          Else
          Begin
            { Expression complexe pour OUT/INOUT : erreur }
            Error('Parametre OUT/INOUT doit etre une variable');
            ParseExpr;
          End;
          GenPushEAX;
        End
        Else
        Begin
          { Passage par valeur (IN) : evaluer et PUSH }
          ParseExpr;
          GenPushEAX;
        End;
        If CurTokType = TOK_COMMA Then Consume;
      End;
      Expect(TOK_RPAREN, '`)` attendu apres arguments');
    End;
    { Emettre l appel }
    EmitI('CALL ' + SubTab[Sub].AsmLabel);
    { STDCALL : callee-cleanup, pas de ADD ESP ici }
  End
  Else
  Begin
    { Procedure inconnue : avertir et skip les args }
    WarnMsg('Procedure non declaree : ' + ProcName +
            ' (appel genere sans verification)');
    EmitComment('call ' + ProcName + ' (undeclared)');
    ArgCount := 0;
    If CurTokType = TOK_LPAREN Then
    Begin
      Consume; { ( }
      While (CurTokType <> TOK_RPAREN) And (CurTokType <> TOK_EOF) Do
      Begin
        ParseExpr;
        GenPushEAX;
        Inc(ArgCount);
        If CurTokType = TOK_COMMA Then Consume;
      End;
      Expect(TOK_RPAREN, '`)` attendu apres arguments');
    End;
    { Generer un CALL avec le nom mangled par defaut }
    EmitI('CALL ' + ADA_FN_PFX + AsmIdent(StrUpperCase(ProcName)));
  End;
  { Consommer le point-virgule }
  If CurTokType = TOK_SEMI Then Consume;
End;

{ ---- ParseBareLoop : LOOP ... END LOOP ; (LOOP deja consomme) }
{ Appele quand le mot-cle LOOP a deja ete consomme.              }
{ Cree un scope SK_LOOP, genere le code de boucle infinie.       }
Procedure ParseBareLoop;
Var
  LblTop : TString;
  LblEnd : TString;
Begin
  LblTop := NewLabel;
  LblEnd := NewLabel;
  PushScope(SK_LOOP, 0);
  EnterLoop(LblTop, LblEnd);
  EmitLabel(LblTop);
  ParseSequenceOfStatements;
  EmitI('JMP  ' + LblTop);
  EmitLabel(LblEnd);
  PopScope;
  { END LOOP [name] ; }
  ExpectKw(KW_END, 'END');
  ExpectKw(KW_LOOP, 'LOOP');
  { Skip optional loop name }
  While (CurTokType <> TOK_SEMI) And (CurTokType <> TOK_EOF) Do
    Consume;
  If CurTokType = TOK_SEMI Then Consume;
End;

{ ============================================================ }
{ TODO 19 - PARSEUR : EXCEPTIONS RAISE ET HANDLERS             }
{ ============================================================ }

{ ---- ParseExceptionHandler : parser la clause EXCEPTION ---- }
{ Syntaxe :                                                      }
{   EXCEPTION                                                    }
{     WHEN nom [| nom2] => sequence_of_statements                }
{     WHEN OTHERS       => sequence_of_statements                }
{ Genere un mecanisme de saut par comparaison de _ADART_CUREXC.  }
{ Le token EXCEPTION est deja consomme par l appelant.            }
Procedure ParseExceptionHandler;
Var
  LblNext    : TString;
  LblSkip    : TString;
  LblEndExc  : TString;
  ExName     : TString;
  SymIdx     : Integer;
  ExVal      : Integer;
  GotVal     : Boolean;
Begin
  EmitComment('--- EXCEPTION handler ---');
  LblEndExc := NewLabel;

  { Boucle sur les clauses WHEN }
  While TokIsKw(KW_WHEN) Do
  Begin
    Consume; { WHEN }

    If TokIsKw(KW_OTHERS) Then
    Begin
      { WHEN OTHERS => stmts }
      Consume; { OTHERS }
      EmitComment('WHEN OTHERS =>');
      { Expect => (on utilise '=>' qui est TOK_ARROW) }
      If CurTokType = TOK_ARROW Then
        Consume
      Else
        Expect(TOK_ARROW, '`=>` attendu apres WHEN OTHERS');
      ParseSequenceOfStatements;
      EmitI('JMP  ' + LblEndExc);
    End
    Else
    Begin
      { WHEN nom [| nom2 ...] => stmts }
      LblNext := NewLabel;
      GotVal  := False;

      Repeat
        If CurTokType = TOK_IDENT Then
        Begin
          ExName := StrUpperCase(CurTokStr);
          Consume;
          SymIdx := FindSym(ExName);
          If (SymIdx > 0) And SymTab[SymIdx].IsConst Then
          Begin
            ExVal := SymTab[SymIdx].InitNum;
            EmitComment('WHEN ' + ExName + ' =>');
            EmitI('CMP  DWORD PTR [_ADART_CUREXC], ' +
                  IntToStr_(ExVal));
            EmitI('JE   ' + LblNext);
            GotVal := True;
          End
          Else
          Begin
            WarnMsg('Exception inconnue dans WHEN : ' + ExName);
            GotVal := True;
          End;
        End
        Else
        Begin
          WarnMsg('Nom d''exception attendu dans WHEN');
          Consume;
          GotVal := True;
        End;
        { Verifier s il y a un | pour alternative }
        If CurTokType = TOK_BAR Then
          Consume  { | }
        Else
          Break;
      Until False;

      { => : attend la fleche }
      If CurTokType = TOK_ARROW Then
        Consume
      Else
        Expect(TOK_ARROW, '`=>` attendu apres nom d''exception');

      If GotVal Then
      Begin
        LblSkip := NewLabel;
        EmitI('JMP  ' + LblSkip);
        EmitLabel(LblNext);
        ParseSequenceOfStatements;
        EmitI('JMP  ' + LblEndExc);
        EmitLabel(LblSkip);
      End;
    End;
  End;

  EmitLabel(LblEndExc);
End;

{ ---- ParseStatement : dispatcher principal des instructions -- }
{ Reconnaît le type d instruction selon le token courant et       }
{ appelle le sous-parseur correspondant.                          }
Procedure ParseStatement;
Var
  SavedName, Nm : TString;
  Sym           : Integer;
  I, J, AI, Sub : Integer;
Begin
  If TokIsKw(KW_NULL) Then
    ParseNull
  Else If TokIsKw(KW_RETURN) Then
    ParseReturn
  Else If TokIsKw(KW_RAISE) Then
    ParseRaise
  Else If TokIsKw(KW_EXIT) Then
    ParseExit
  Else If TokIsKw(KW_GOTO) Then
    ParseGoto
  Else If TokIsKw(KW_PRAGMA) Then
    ParsePragma
  Else If TokIsKw(KW_IF) Then
    ParseIf
  Else If TokIsKw(KW_CASE) Then
    ParseCase
  Else If TokIsKw(KW_LOOP) Then
  Begin
    EmitComment('LOOP ... END LOOP');
    Consume; { LOOP }
    ParseBareLoop;
  End
  Else If TokIsKw(KW_WHILE) Then
    ParseWhile
  Else If TokIsKw(KW_FOR) Then
    ParseFor
  Else If TokIsKw(KW_BEGIN) Then
    ParseBeginBlock
  Else If TokIsKw(KW_DECLARE) Then
    ParseDeclareBlock
  Else If CurTokType = TOK_IDENT Then
  Begin
    { Identifiant : assignation ou appel de procedure }
    SavedName := CurTokStr;
    Consume; { ident }
    { Verifier si c est une assignation }
    If CurTokType = TOK_COLONASSIGN Then
    Begin
      { Assignation : ident := expr ; }
      Consume; { := }
      ParseAssignment(SavedName);
    End
    Else If CurTokType = TOK_LPAREN Then
    Begin
      { Parenthese : appel de procedure/fonction OU acces tableau }
      { Verifier si c est un tableau (TODO 20) }
      Sym := FindSym(SavedName);
      If (Sym > 0) And
         ((SymTab[Sym].ArraySize > 0) Or
          ((SymTab[Sym].TypeIdx > TYPE_STR) And
           (SymTab[Sym].TypeIdx <= TypeCount) And
           (TypeTab[SymTab[Sym].TypeIdx].Kind = TK_ARRAY))) Then
      Begin
        { Assignation a un element de tableau : arr(index) := expr }
        Consume; { ( }
        ParseExpr;       { EAX = index }
        GenPushEAX;      { sauver index sur la pile }
        Expect(TOK_RPAREN, '`)` attendu apres index tableau');
        If CurTokType = TOK_COLONASSIGN Then
        Begin
          Consume; { := }
          EmitComment('array store ' + SavedName + '(index) := expr');
          ParseExpr;     { EAX = valeur a stocker }
          GenStoreElement(Sym);
          If CurTokType = TOK_SEMI Then Consume;
        End
        Else
        Begin
          { Appel de procedure avec meme nom qu un tableau ? }
          { Peu probable, mais resynchroniser }
          EmitI('POP  EBX'); { depiler l index inutilise }
          ParseProcedureCall(SavedName);
        End;
      End
      Else
      Begin
        { Appel de procedure : nom(args) ; }
        ParseProcedureCall(SavedName);
      End;
    End
    Else If CurTokType = TOK_DOT Then
    Begin
      { Nom qualifie : pkg.proc ou rec.field := ... (TODO 21) }
      { D abord verifier si SavedName est un record }
      Sym := FindSym(SavedName);
      If (Sym > 0) And (SymTab[Sym].TypeIdx > TYPE_STR) And
         (SymTab[Sym].TypeIdx <= TypeCount) And
         (TypeTab[SymTab[Sym].TypeIdx].Kind = TK_RECORD) Then
      Begin
        { Record : rec.field [:= expr] }
        Consume; { . }
        If CurTokType <> TOK_IDENT Then
        Begin Error('Nom de champ attendu apres `.`'); SkipToSemi; End
        Else
        Begin
          Nm := CurTokStr;
          Consume; { field name }
          I := FindFieldIdx(SymTab[Sym].TypeIdx, Nm);
          If I <= 0 Then
          Begin
            Error('Champ inconnu : ' + Nm + ' dans ' + SavedName);
            SkipToSemi;
          End
          Else If CurTokType = TOK_DOT Then
          Begin
            { Record imbrique : rec.field.subfield := expr }
            J := TypeTab[SymTab[Sym].TypeIdx].FieldTypes[I];
            AI := TypeTab[SymTab[Sym].TypeIdx].FieldOffs[I];
            If (J > TYPE_STR) And (J <= TypeCount) And
               (TypeTab[J].Kind = TK_RECORD) Then
            Begin
              Consume; { . }
              If CurTokType <> TOK_IDENT Then
              Begin Error('Nom de sous-champ attendu'); SkipToSemi; End
              Else
              Begin
                Sub := FindFieldIdx(J, CurTokStr);
                If Sub <= 0 Then
                Begin
                  Error('Sous-champ inconnu : ' + CurTokStr);
                  Consume;
                  SkipToSemi;
                End
                Else
                Begin
                  Consume; { subfield name }
                  If CurTokType = TOK_COLONASSIGN Then
                  Begin
                    Consume; { := }
                    EmitComment('record nested store ' +
                                SavedName + '.' + Nm + '.subfield := ...');
                    ParseExpr;
                    GenStoreFieldNested(Sym, AI, J, Sub);
                    If CurTokType = TOK_SEMI Then Consume;
                  End
                  Else
                  Begin
                    Error(':= attendu apres champ imbrique');
                    SkipToSemi;
                  End;
                End;
              End;
            End
            Else
            Begin
              Warning('Acces imbrique non supporte pour ce type');
              Consume; { . }
              If CurTokType = TOK_IDENT Then Consume;
              SkipToSemi;
            End;
          End
          Else If CurTokType = TOK_COLONASSIGN Then
          Begin
            Consume; { := }
            { Verifier affectation agregat : rec.field := (f => v, ...) }
            { Non, c est une affectation simple de champ }
            EmitComment('record store ' + SavedName + '.' + Nm +
                        ' := ...');
            ParseExpr;
            GenStoreField(Sym, I);
            If CurTokType = TOK_SEMI Then Consume;
          End
          Else
          Begin
            Error(':= attendu apres champ de record');
            SkipToSemi;
          End;
        End;
      End
      Else
      Begin
        { Pas un record : nom qualifie classique (pkg.proc) }
        While CurTokType = TOK_DOT Do
        Begin
          Consume; { . }
          If CurTokType = TOK_IDENT Then
          Begin
            SavedName := SavedName + '.' + CurTokStr;
            Consume;
          End;
        End;
        { Verifier si c est une assignation }
        If CurTokType = TOK_COLONASSIGN Then
        Begin
          Consume; { := }
          ParseAssignment(SavedName);
        End
        Else
          ParseProcedureCall(SavedName);
      End;
    End
    Else
    Begin
      { Appel de procedure : nom [(args)] ; }
      ParseProcedureCall(SavedName);
    End;
  End
  Else If CurTokType = TOK_SEMI Then
  Begin
    { Point-virgule isole - skip silencieusement }
    Consume;
  End
  Else
  Begin
    { Token inattendu : resynchroniser }
    Error('Instruction inattendue : ' + CurTokStr);
    SkipToSemi;
  End;
End;

{ ---- ParseSequenceOfStatements : parser la sequence d instr --- }
{ Boucle appelant ParseStatement jusqu a rencontrer END,           }
{ EXCEPTION, ELSIF, ELSE, WHEN ou EOF (IsEndBoundary).            }
Procedure ParseSequenceOfStatements;
Begin
  While Not IsEndBoundary Do
    ParseStatement;
End;

{ ---- ParseProcedureBody : corps complet d une PROCEDURE ------ }
{ Appele apres avoir consomme IS. SubIdx pointe dans SubTab.       }
{ Etapes :                                                          }
{   1. PushScope(SK_PROC)                                           }
{   2. RegisterParams (inscrire les parametres en STORE_PARAM)      }
{   3. ParseDeclarativePart (types, variables locales, etc.)        }
{   4. Expect BEGIN                                                 }
{   5. GenPrologue                                                  }
{   6. ParseSequenceOfStatements                                    }
{   7. [EXCEPTION : skip handler]                                   }
{   8. Expect END [nom] ;                                           }
{   9. GenEpilogue                                                  }
{  10. PopScope -> FrameSize pour GenPrologue/GenEpilogue            }
Procedure ParseProcedureBody(SubIdx : Integer);
Var
  FrameSz   : Integer;
  ParamSz   : Integer;
  LblExit_  : TString;
  LblExcept : TString;
  LblSkipEx : TString;
  SubName   : TString;
Begin
  SubName := SubTab[SubIdx].Name;

  { 1. Entrer dans le scope de la procedure }
  PushScope(SK_PROC, SubIdx);

  { 2. Enregistrer les parametres formels comme STORE_PARAM }
  RegisterParams(SubIdx);

  { Label de sortie (pour RETURN eventuel) }
  LblExit_ := NewLabel;
  SetExitLabel(LblExit_);

  { 3. Partie declarative (entre IS et BEGIN) }
  ParseDeclarativePart;

  { 4. Expect BEGIN }
  ExpectKw(KW_BEGIN, 'BEGIN');

  { 5. Prologue ASM : PUSH EBP / MOV EBP, ESP / SUB ESP, frame }
  { On emet le label de la procedure }
  EmitBlank;
  EmitComment('--- PROCEDURE ' + SubName + ' ---');
  EmitLabel(SubTab[SubIdx].AsmLabel);

  { Le frame size sera connu apres PopScope, on emet un stub }
  { On genere le prologue maintenant avec le FrameSize courant }
  { NB : les variables locales ont deja ete allouees par ParseObjectDecl }
  FrameSz := -ScopeStack[ScopeTop].BpTop;
  GenPrologue(FrameSz);

  { Preparer le label d exception si EXCEPTION sera present }
  LblExcept := NewExLabel;
  SetExceptLabel(LblExcept);

  { 6. Sequence d instructions }
  ParseSequenceOfStatements;

  { 7. EXCEPTION optionnel (TODO 19) }
  If TokIsKw(KW_EXCEPTION) Then
  Begin
    Consume; { EXCEPTION }
    { Sauter le handler si pas d exception levee }
    LblSkipEx := NewLabel;
    EmitI('JMP  ' + LblSkipEx);
    { Label d entree du handler }
    EmitLabel(LblExcept);
    { Parser les clauses WHEN }
    ParseExceptionHandler;
    EmitLabel(LblSkipEx);
  End;

  { 8. END [nom] ; }
  ExpectKw(KW_END, 'END');
  { Sauter le nom optionnel apres END }
  If (CurTokType = TOK_IDENT) And
     (StrUpperCase(CurTokStr) = SubName) Then
    Consume;
  Expect(TOK_SEMI, '`;` attendu apres END');

  { 9. Epilogue : label de sortie + MOV ESP, EBP / POP EBP / RET n }
  EmitLabel(LblExit_);
  ParamSz := SubParamBytes32(SubIdx);
  GenEpilogue(FrameSz, ParamSz);

  { 10. Depiler le scope }
  FrameSz := PopScope;
  SubTab[SubIdx].FrameSize := FrameSz;
End;

{ ---- ParseFunctionBody : corps complet d une FUNCTION --------- }
{ Identique a ParseProcedureBody sauf :                            }
{   - Le scope est SK_FUNC                                          }
{   - Le resultat de la fonction doit etre dans EAX                 }
{   - RETURN expr ; met la valeur dans EAX                          }
{ Pour l instant (stub), le corps est traverse sans generer de     }
{ code pour les instructions. La valeur par defaut est EAX = 0.    }
Procedure ParseFunctionBody(SubIdx : Integer);
Var
  FrameSz   : Integer;
  ParamSz   : Integer;
  LblExit_  : TString;
  LblExcept : TString;
  LblSkipEx : TString;
  SubName   : TString;
Begin
  SubName := SubTab[SubIdx].Name;

  { 1. Entrer dans le scope de la function }
  PushScope(SK_FUNC, SubIdx);

  { 2. Enregistrer les parametres formels }
  RegisterParams(SubIdx);

  { Label de sortie }
  LblExit_ := NewLabel;
  SetExitLabel(LblExit_);

  { 3. Partie declarative (entre IS et BEGIN) }
  ParseDeclarativePart;

  { 4. Expect BEGIN }
  ExpectKw(KW_BEGIN, 'BEGIN');

  { 5. Prologue ASM }
  EmitBlank;
  EmitComment('--- FUNCTION ' + SubName + ' ---');
  EmitLabel(SubTab[SubIdx].AsmLabel);

  FrameSz := -ScopeStack[ScopeTop].BpTop;
  GenPrologue(FrameSz);

  { Valeur de retour par defaut : EAX = 0 }
  EmitI('XOR  EAX, EAX');

  { Preparer le label d exception }
  LblExcept := NewExLabel;
  SetExceptLabel(LblExcept);

  { 6. Sequence d instructions }
  ParseSequenceOfStatements;

  { 7. EXCEPTION optionnel (TODO 19) }
  If TokIsKw(KW_EXCEPTION) Then
  Begin
    Consume; { EXCEPTION }
    { Sauter le handler si pas d exception levee }
    LblSkipEx := NewLabel;
    EmitI('JMP  ' + LblSkipEx);
    { Label d entree du handler }
    EmitLabel(LblExcept);
    { Parser les clauses WHEN }
    ParseExceptionHandler;
    EmitLabel(LblSkipEx);
  End;

  { 8. END [nom] ; }
  ExpectKw(KW_END, 'END');
  If (CurTokType = TOK_IDENT) And
     (StrUpperCase(CurTokStr) = SubName) Then
    Consume;
  Expect(TOK_SEMI, '`;` attendu apres END');

  { 9. Epilogue }
  EmitLabel(LblExit_);
  ParamSz := SubParamBytes32(SubIdx);
  GenEpilogue(FrameSz, ParamSz);

  { 10. Depiler le scope }
  FrameSz := PopScope;
  SubTab[SubIdx].FrameSize := FrameSz;
End;

{ ---- ParseProcedureDecl : declaration ou corps de PROCEDURE --- }
{ PROCEDURE nom [(params)] ;        => spec (forward declaration)  }
{ PROCEDURE nom [(params)] IS ...   => body                        }
Procedure ParseProcedureDecl;
Var
  Name : TString;
  Idx  : Integer;
Begin
  ExpectKw(KW_PROCEDURE, 'PROCEDURE');

  If CurTokType <> TOK_IDENT Then
  Begin Error('Nom de procedure attendu'); Exit; End;
  Name := CurTokStr;
  Consume;

  { Chercher si deja declaree (forward), sinon creer }
  Idx := FindSub(Name);
  If Idx = 0 Then
    Idx := AddSub(Name, False, TYPE_VOID);
  If Idx = 0 Then Exit; { table pleine }

  { Liste de parametres optionnelle }
  If CurTokType = TOK_LPAREN Then
    ParseParamList(Idx);

  { Spec ou body ? }
  If CurTokType = TOK_SEMI Then
  Begin
    { Forward declaration }
    SubTab[Idx].IsForward := True;
    Consume; { ; }
    If Opts.Verbose Then
      WriteLn('  Procedure spec: ', Name, ' (',
              SubTab[Idx].ParamCount, ' params)');
  End
  Else If TokIsKw(KW_IS) Then
  Begin
    { Corps de procedure }
    SubTab[Idx].IsForward := False;
    Consume; { IS }
    If Opts.Verbose Then
      WriteLn('  Procedure body: ', Name, ' (',
              SubTab[Idx].ParamCount, ' params)');
    ParseProcedureBody(Idx);
  End
  Else
    Error(''';'' ou ''IS'' attendu apres signature PROCEDURE');
End;

{ ---- ParseFunctionDecl : declaration ou corps de FUNCTION ----- }
{ FUNCTION nom [(params)] RETURN type ;        => spec (forward)   }
{ FUNCTION nom [(params)] RETURN type IS ...   => body (skip)      }
Procedure ParseFunctionDecl;
Var
  Name : TString;
  Idx  : Integer;
  RetT : Integer;
Begin
  ExpectKw(KW_FUNCTION, 'FUNCTION');

  If CurTokType <> TOK_IDENT Then
  Begin Error('Nom de function attendu'); Exit; End;
  Name := CurTokStr;
  Consume;

  { Creer ou trouver dans la table des sous-programmes }
  Idx := FindSub(Name);
  If Idx = 0 Then
    Idx := AddSub(Name, True, TYPE_VOID);
  If Idx = 0 Then Exit; { table pleine }

  { Liste de parametres optionnelle }
  If CurTokType = TOK_LPAREN Then
    ParseParamList(Idx);

  { RETURN type }
  ExpectKw(KW_RETURN, 'RETURN');
  RetT := ParseTypeRef;
  SubTab[Idx].RetType := RetT;

  { Spec ou body ? }
  If CurTokType = TOK_SEMI Then
  Begin
    { Forward declaration }
    SubTab[Idx].IsForward := True;
    Consume; { ; }
    If Opts.Verbose Then
      WriteLn('  Function spec: ', Name, ' (',
              SubTab[Idx].ParamCount, ' params) -> type #',
              RetT);
  End
  Else If TokIsKw(KW_IS) Then
  Begin
    { Corps de function }
    SubTab[Idx].IsForward := False;
    Consume; { IS }
    If Opts.Verbose Then
      WriteLn('  Function body: ', Name, ' (',
              SubTab[Idx].ParamCount, ' params) -> type #',
              RetT);
    ParseFunctionBody(Idx);
  End
  Else
    Error(''';'' ou ''IS'' attendu apres signature FUNCTION');
End;

{ ============================================================ }
{ TODO 14 - PARSEUR : PACKAGE SPEC ET BODY                      }
{ ============================================================ }

{ ---- GenTextIOStubs : generer les stubs Ada.Text_IO ---------- }
{ Enregistre Put, Put_Line, Get, Get_Line, New_Line, Set_Col     }
{ dans SubTab en tant que procedures standards.                   }
{ Genere du code ASM appelant les helpers runtime Win32           }
{ (_ADART_PUT, _ADART_PUT_LINE, _ADART_GET, _ADART_GET_LINE).   }
{ TODO 22 : Put/Put_Line type-dispatched inline (ParseProcCall).  }
{           New_Line et Set_Col ajoutes.                          }
Procedure GenTextIOStubs;
Var
  Idx : Integer;
Begin
  { --- Put (S : String) --- }
  { Note: Put et Put_Line sont maintenant geres inline par        }
  { GenTextIOPutInline via ParseProcedureCall (TODO 22).          }
  { Les stubs sont conserves pour compatibilite.                  }
  Idx := FindSub('PUT');
  If Idx = 0 Then
    Idx := AddSub('PUT', False, TYPE_VOID);
  If Idx > 0 Then
  Begin
    SubTab[Idx].IsForward  := False;
    SubTab[Idx].ParamCount := 1;
    SubTab[Idx].ParamNames[1] := 'ITEM';
    SubTab[Idx].ParamTypes[1] := TYPE_STR;
    SubTab[Idx].ParamModes[1] := PARAM_IN;
    EmitBlank;
    EmitComment('--- Ada.Text_IO.Put (stub) ---');
    EmitLabel(SubTab[Idx].AsmLabel);
    EmitI('PUSH EBP');
    EmitI('MOV  EBP, ESP');
    EmitI('MOV  EAX, DWORD PTR [EBP+8]');
    EmitI('PUSH EAX');
    EmitI('CALL ' + ADA_RT_PFX + 'PRINT');
    EmitI('POP  EBP');
    EmitI('RET  4');
  End;

  { --- Put_Line (S : String) --- }
  Idx := FindSub('PUT_LINE');
  If Idx = 0 Then
    Idx := AddSub('PUT_LINE', False, TYPE_VOID);
  If Idx > 0 Then
  Begin
    SubTab[Idx].IsForward  := False;
    SubTab[Idx].ParamCount := 1;
    SubTab[Idx].ParamNames[1] := 'ITEM';
    SubTab[Idx].ParamTypes[1] := TYPE_STR;
    SubTab[Idx].ParamModes[1] := PARAM_IN;
    EmitBlank;
    EmitComment('--- Ada.Text_IO.Put_Line (stub) ---');
    EmitLabel(SubTab[Idx].AsmLabel);
    EmitI('PUSH EBP');
    EmitI('MOV  EBP, ESP');
    EmitI('MOV  EAX, DWORD PTR [EBP+8]');
    EmitI('PUSH EAX');
    EmitI('CALL ' + ADA_RT_PFX + 'PRINT');
    EmitI('CALL ' + ADA_RT_PFX + 'CRLF');
    EmitI('POP  EBP');
    EmitI('RET  4');
  End;

  { --- Get (Item : out Character) --- }
  Idx := FindSub('GET');
  If Idx = 0 Then
    Idx := AddSub('GET', False, TYPE_VOID);
  If Idx > 0 Then
  Begin
    SubTab[Idx].IsForward  := False;
    SubTab[Idx].ParamCount := 1;
    SubTab[Idx].ParamNames[1] := 'ITEM';
    SubTab[Idx].ParamTypes[1] := TYPE_CHAR;
    SubTab[Idx].ParamModes[1] := PARAM_OUT;
    EmitBlank;
    EmitComment('--- Ada.Text_IO.Get (stub) ---');
    EmitLabel(SubTab[Idx].AsmLabel);
    EmitI('PUSH EBP');
    EmitI('MOV  EBP, ESP');
    EmitI('MOV  EAX, DWORD PTR [EBP+8]');
    EmitI('PUSH EAX');
    EmitI('CALL ' + ADA_RT_PFX + 'GET');
    EmitI('POP  EBP');
    EmitI('RET  4');
  End;

  { --- Get_Line (Item : out String; Last : out Natural) --- }
  Idx := FindSub('GET_LINE');
  If Idx = 0 Then
    Idx := AddSub('GET_LINE', False, TYPE_VOID);
  If Idx > 0 Then
  Begin
    SubTab[Idx].IsForward  := False;
    SubTab[Idx].ParamCount := 2;
    SubTab[Idx].ParamNames[1] := 'ITEM';
    SubTab[Idx].ParamTypes[1] := TYPE_STR;
    SubTab[Idx].ParamModes[1] := PARAM_OUT;
    SubTab[Idx].ParamNames[2] := 'LAST';
    SubTab[Idx].ParamTypes[2] := TYPE_INT;
    SubTab[Idx].ParamModes[2] := PARAM_OUT;
    EmitBlank;
    EmitComment('--- Ada.Text_IO.Get_Line (stub) ---');
    EmitLabel(SubTab[Idx].AsmLabel);
    EmitI('PUSH EBP');
    EmitI('MOV  EBP, ESP');
    EmitI('MOV  EAX, DWORD PTR [EBP+8]');
    EmitI('PUSH EAX');
    EmitI('MOV  EAX, DWORD PTR [EBP+12]');
    EmitI('PUSH EAX');
    EmitI('CALL ' + ADA_RT_PFX + 'GET_LINE');
    EmitI('POP  EBP');
    EmitI('RET  8');
  End;

  { --- New_Line [(Count : Natural)] --- (TODO 22) }
  Idx := FindSub('NEW_LINE');
  If Idx = 0 Then
    Idx := AddSub('NEW_LINE', False, TYPE_VOID);
  If Idx > 0 Then
  Begin
    SubTab[Idx].IsForward  := False;
    SubTab[Idx].ParamCount := 0;
    EmitBlank;
    EmitComment('--- Ada.Text_IO.New_Line (stub) ---');
    EmitLabel(SubTab[Idx].AsmLabel);
    EmitI('PUSH EBP');
    EmitI('MOV  EBP, ESP');
    EmitI('CALL ' + ADA_RT_PFX + 'CRLF');
    EmitI('POP  EBP');
    EmitI('RET');
  End;

  { --- Set_Col (To : Positive_Count) --- (TODO 22 stub) }
  Idx := FindSub('SET_COL');
  If Idx = 0 Then
    Idx := AddSub('SET_COL', False, TYPE_VOID);
  If Idx > 0 Then
  Begin
    SubTab[Idx].IsForward  := False;
    SubTab[Idx].ParamCount := 1;
    SubTab[Idx].ParamNames[1] := 'TO';
    SubTab[Idx].ParamTypes[1] := TYPE_INT;
    SubTab[Idx].ParamModes[1] := PARAM_IN;
    EmitBlank;
    EmitComment('--- Ada.Text_IO.Set_Col (stub - non implemente) ---');
    EmitLabel(SubTab[Idx].AsmLabel);
    EmitI('PUSH EBP');
    EmitI('MOV  EBP, ESP');
    EmitI('POP  EBP');
    EmitI('RET  4');
  End;
End;

{ ---- ParsePackageSpec : analyser une specification de package -- }
{ Syntaxe :                                                        }
{   PACKAGE nom IS                                                 }
{     [declarations publiques]                                     }
{     [PRIVATE                                                     }
{       declarations privees]                                      }
{   END [nom] ;                                                    }
{ Enregistre les declarations exportees dans SubTab / TypeTab.     }
Procedure ParsePackageSpec(Const PkgName : TString);
Var
  PIdx    : Integer;
  IsStd   : Boolean;
  UName   : TString;
Begin
  UName := StrUpperCase(PkgName);

  { Enregistrer le package s il n est pas deja connu }
  IsStd := IsStandardPackage(UName);
  PIdx  := FindPkg(UName);
  If PIdx = 0 Then
    PIdx := AddPkg(UName, IsStd);

  { Entrer dans le scope du package }
  PushScope(SK_PACKAGE, 0);

  If Opts.Verbose Then
    WriteLn('  Package spec: ', UName);

  { Parser les declarations publiques }
  While (CurTokType <> TOK_EOF) And
        (Not TokIsKw(KW_END)) And
        (Not TokIsKw(KW_PRIVATE)) Do
  Begin
    If CurTokKw = KW_TYPE Then
      ParseTypeDecl
    Else If CurTokKw = KW_SUBTYPE Then
      ParseSubtypeDecl
    Else If CurTokKw = KW_PROCEDURE Then
      ParseProcedureDecl
    Else If CurTokKw = KW_FUNCTION Then
      ParseFunctionDecl
    Else If CurTokType = TOK_IDENT Then
      ParseObjectDecl
    Else
    Begin
      Error('Token inattendu dans package spec : ' + CurTokStr);
      Consume;
    End;
  End;

  { Section PRIVATE optionnelle }
  If TokIsKw(KW_PRIVATE) Then
  Begin
    Consume; { PRIVATE }
    If Opts.Verbose Then
      WriteLn('    PRIVATE section');
    { Parser les declarations privees }
    While (CurTokType <> TOK_EOF) And (Not TokIsKw(KW_END)) Do
    Begin
      If CurTokKw = KW_TYPE Then
        ParseTypeDecl
      Else If CurTokKw = KW_SUBTYPE Then
        ParseSubtypeDecl
      Else If CurTokKw = KW_PROCEDURE Then
        ParseProcedureDecl
      Else If CurTokKw = KW_FUNCTION Then
        ParseFunctionDecl
      Else If CurTokType = TOK_IDENT Then
        ParseObjectDecl
      Else
      Begin
        Error('Token inattendu dans PRIVATE : ' + CurTokStr);
        Consume;
      End;
    End;
  End;

  { END [nom] ; }
  ExpectKw(KW_END, 'END');
  If (CurTokType = TOK_IDENT) And
     (StrUpperCase(CurTokStr) = UName) Then
    Consume;
  Expect(TOK_SEMI, '`;` attendu apres END du package spec');

  PopScope;

  { Pour Ada.Text_IO : generer stubs I/O }
  If (UName = 'ADA.TEXT_IO') Or (UName = 'TEXT_IO') Then
    GenTextIOStubs;
End;

{ ---- ParsePackageBody : analyser un corps de package ---------- }
{ Syntaxe :                                                        }
{   PACKAGE BODY nom IS                                            }
{     declarations privees                                         }
{     [BEGIN init_statements END [nom] ;]                          }
{   END [nom] ;                                                    }
{ Genere les corps des sous-programmes et l init optionnel.        }
Procedure ParsePackageBody(Const PkgName : TString);
Var
  PIdx      : Integer;
  IsStd     : Boolean;
  UName     : TString;
  InitLabel : TString;
  FrameSz   : Integer;
Begin
  UName := StrUpperCase(PkgName);

  { Enregistrer le package s il n est pas deja connu }
  IsStd := IsStandardPackage(UName);
  PIdx  := FindPkg(UName);
  If PIdx = 0 Then
    PIdx := AddPkg(UName, IsStd);

  { Entrer dans le scope du package }
  PushScope(SK_PACKAGE, 0);

  If Opts.Verbose Then
    WriteLn('  Package body: ', UName);

  { Partie declarative : types, variables, sous-programmes }
  While (CurTokType <> TOK_EOF) And
        (Not TokIsKw(KW_BEGIN)) And (Not TokIsKw(KW_END)) Do
  Begin
    If CurTokKw = KW_TYPE Then
      ParseTypeDecl
    Else If CurTokKw = KW_SUBTYPE Then
      ParseSubtypeDecl
    Else If CurTokKw = KW_PROCEDURE Then
      ParseProcedureDecl
    Else If CurTokKw = KW_FUNCTION Then
      ParseFunctionDecl
    Else If CurTokType = TOK_IDENT Then
      ParseObjectDecl
    Else
    Begin
      Error('Token inattendu dans package body : ' + CurTokStr);
      Consume;
    End;
  End;

  { Bloc d initialisation optionnel : BEGIN ... END [nom] ; }
  If TokIsKw(KW_BEGIN) Then
  Begin
    Consume; { BEGIN }
    If Opts.Verbose Then
      WriteLn('    Package init block: ', UName);
    { Generer le label d initialisation _ADAP_nom_INIT }
    InitLabel := ADA_PKG_PFX + AsmIdent(UName) + '_INIT';
    EmitBlank;
    EmitComment('--- Package ' + UName + ' initialization ---');
    EmitLabel(InitLabel);
    EmitI('PUSH EBP');
    EmitI('MOV  EBP, ESP');

    { Parser les instructions d initialisation (stub : skip) }
    SkipStatements;

    { EXCEPTION optionnel }
    If TokIsKw(KW_EXCEPTION) Then
    Begin
      Consume; { EXCEPTION }
      SkipStatements;
    End;

    EmitI('POP  EBP');
    EmitI('RET');

    { END [nom] ; du bloc BEGIN }
    { Note : le END principal du package body est gere apres }
  End;

  { END [nom] ; }
  ExpectKw(KW_END, 'END');
  If (CurTokType = TOK_IDENT) And
     (StrUpperCase(CurTokStr) = UName) Then
    Consume;
  Expect(TOK_SEMI, '`;` attendu apres END du package body');

  FrameSz := PopScope;
End;

{ ---- ParsePackageDecl : dispatcher spec ou body --------------- }
{ Reconnaît :                                                      }
{   PACKAGE nom IS ...              -> ParsePackageSpec             }
{   PACKAGE BODY nom IS ...         -> ParsePackageBody             }
Procedure ParsePackageDecl;
Var
  PkgName : TString;
Begin
  ExpectKw(KW_PACKAGE, 'PACKAGE');

  { PACKAGE BODY nom IS ... }
  If TokIsKw(KW_BODY) Then
  Begin
    Consume; { BODY }

    If CurTokType <> TOK_IDENT Then
    Begin Error('Nom de package attendu apres BODY'); Exit; End;
    PkgName := ParsePackageName;

    ExpectKw(KW_IS, 'IS');
    ParsePackageBody(PkgName);
  End
  Else
  Begin
    { PACKAGE nom IS ... }
    If CurTokType <> TOK_IDENT Then
    Begin Error('Nom de package attendu'); Exit; End;
    PkgName := ParsePackageName;

    ExpectKw(KW_IS, 'IS');
    ParsePackageSpec(PkgName);
  End;
End;

{ ---- LexInit : ouvrir le fichier source et lire le 1er token }
Procedure LexInit;
Begin
  LexOpened  := False;
  Assign(LexSrcF, Opts.SrcFile);
  Reset(LexSrcF);
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir: ' + Opts.SrcFile);
  LexOpened  := True;
  LexEOF     := False;
  LexLineNo  := 0;
  LexColNo   := 1;
  LexLine    := '';
  CurTokType := TOK_EOF;
  CurTokStr  := '';
  CurTokNum  := 0;
  CurTokKw   := KW_NONE;
  LexNextLine;
  LexNextToken;
End;

{ ---- LexClose : fermer le fichier source -------------------- }
Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
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
End;

{ ============================================================ }
{ AIDE EN LIGNE                                                }
{ ============================================================ }

Procedure ShowHelp;
Begin
  WriteLn('ADACW32 v', ADACW32_VERSION, ' (', ADACW32_DATE,
          ') - Compilateur Ada 83/95 vers 80386 (Windows PE 32 bits)');
  WriteLn('ADACW32 - Cette commande permet de lancer le compilateur ',
          'Ada 83/95 pour l''assembleur du microprocesseur 80386 (en ',
          'executable Windows 32 bits).');
  WriteLn;
  WriteLn('Syntaxe : ADACW32 <source.adb> [options]');
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
  WriteLn('  ADACW32 HELLO.ADB');
  WriteLn('  ADACW32 HELLO.ADB -v');
  WriteLn('  ADACW32 HELLO.ADB -asm');
  WriteLn('  ADACW32 HELLO.ADB -obj');
  WriteLn('  ADACW32 HELLO.ADB -o MONPROG.EXE');
  Halt(EXIT_OK);
End;

{ ============================================================ }
{ ANALYSE DES ARGUMENTS                                        }
{ ============================================================ }

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
    WriteLn('ADACW32: fichier source manquant');
    ShowHelp;
  End;

  { Verifier l extension .adb ou .ads }
  Ext := ExtractExt(Opts.SrcFile);
  If (Ext <> '.adb') And (Ext <> '.ads') And (Ext <> '.ada') Then
    WarnMsg('extension attendue .adb ou .ads, trouvee: ' + Ext);

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
  WriteLn('ADACW32 v', ADACW32_VERSION, ' (', ADACW32_DATE,
          ') - Compilateur Ada 83/95 -> 80386 PE Win32');
  WriteLn('Source   : ', Opts.SrcFile);
  WriteLn('Sortie   : ', Opts.OutFile);
  If Opts.EmitAsm Then
    WriteLn('ASM      : ', ReplaceExt(Opts.OutFile, '.asm'));
  If Opts.EmitObj Then
    WriteLn('Format   : OBJ (COFF)')
  Else
    WriteLn('Format   : EXE (PE Win32)');
  WriteLn;
End;

Procedure ShowStats;
Begin
  If Not Opts.Verbose Then Exit;
  WriteLn;
  WriteLn('--- Statistiques ---');
  WriteLn('Lignes analysees : ', TotalLines);
  WriteLn('Symboles         : ', SymCount);
  WriteLn('Types            : ', TypeCount);
  WriteLn('Sous-programmes  : ', SubCount);
  WriteLn('Packages         : ', PkgCount);
  WriteLn('Scope courant    : ', ScopeTop);
  WriteLn('Chaines          : ', StrCount);
  WriteLn('Labels generes   : ', LabelCounter);
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
{ PROCEDURE RUN                                                }
{ ============================================================ }


{ ============================================================ }
{ GENERATION FINALE (TODO 25)                                   }
{ ============================================================ }

{$IFDEF FPC}

Procedure BinInit;
Begin
  BinCodeLen  := 0;
  BinDataLen  := 0;
  BinLblCount := 0;
  BinFixCount := 0;
  BinInCode   := True;
End;

{ ---- BinEmitByte : ecrire un octet dans le tampon code ------- }
Procedure BinEmitByte(B : Byte);
Begin
  If BinCodeLen < MAX_BIN_CODE Then
  Begin
    BinCode[BinCodeLen] := B;
    Inc(BinCodeLen);
  End;
End;

{ ---- BinEmitWord : ecrire un mot 16 bits (little-endian) ----- }
Procedure BinEmitWord(W : Word);
Begin
  BinEmitByte(Lo(W));
  BinEmitByte(Hi(W));
End;

{ ---- BinEmitDWord : ecrire un double-mot 32 bits (LE) -------- }
Procedure BinEmitDWord(D : LongInt);
Begin
  BinEmitByte(Byte(D And $FF));
  BinEmitByte(Byte((D Shr 8) And $FF));
  BinEmitByte(Byte((D Shr 16) And $FF));
  BinEmitByte(Byte((D Shr 24) And $FF));
End;

{ ---- BinEmitDataByte : ecrire un octet dans le tampon data --- }
Procedure BinEmitDataByte(B : Byte);
Begin
  If BinDataLen < MAX_BIN_DATA Then
  Begin
    BinData[BinDataLen] := B;
    Inc(BinDataLen);
  End;
End;

{ ---- BinEmitDataWord : ecrire un mot 16 bits dans data ------- }
Procedure BinEmitDataWord(W : Word);
Begin
  BinEmitDataByte(Lo(W));
  BinEmitDataByte(Hi(W));
End;

{ ---- BinEmitDataDWord : ecrire un double-mot 32 bits data ---- }
Procedure BinEmitDataDWord(D : LongInt);
Begin
  BinEmitDataByte(Byte(D And $FF));
  BinEmitDataByte(Byte((D Shr 8) And $FF));
  BinEmitDataByte(Byte((D Shr 16) And $FF));
  BinEmitDataByte(Byte((D Shr 24) And $FF));
End;

{ ---- BinAddLabel : enregistrer un label dans la table -------- }
Procedure BinAddLabel(AName : TString; AnOfs : LongInt);
Begin
  If BinLblCount < MAX_BIN_LBL Then
  Begin
    BinLabels[BinLblCount].Name   := AName;
    BinLabels[BinLblCount].Offset := AnOfs;
    Inc(BinLblCount);
  End;
End;

{ ---- BinAddFixup : ajouter une relocation -------------------- }
Procedure BinAddFixup(AnOfs : LongInt; AKind : TBinFixKind;
                      ATarget : TString; AInCode : Boolean);
Begin
  If BinFixCount < MAX_BIN_FIX Then
  Begin
    BinFixups[BinFixCount].Offset := AnOfs;
    BinFixups[BinFixCount].Kind   := AKind;
    BinFixups[BinFixCount].Target := ATarget;
    BinFixups[BinFixCount].InCode := AInCode;
    Inc(BinFixCount);
  End;
End;

{ ---- BinFindLabel : trouver l offset d un label -------------- }
Function BinFindLabel(AName : TString) : LongInt;
Var I : Integer;
Begin
  BinFindLabel := -1;
  For I := 0 To BinLblCount - 1 Do
    If BinLabels[I].Name = AName Then
    Begin
      BinFindLabel := BinLabels[I].Offset;
      Exit;
    End;
End;

{ ---- WriteBinByte : ecrire un octet dans un fichier binaire -- }
Procedure WriteBinByte(Var F : File; B : Byte);
Begin
  BlockWrite(F, B, 1);
End;

{ ---- WriteBinWord : ecrire un mot 16 bits LE dans un fichier - }
Procedure WriteBinWord(Var F : File; W : Word);
Var Buf : Array[0..1] of Byte;
Begin
  Buf[0] := Lo(W);
  Buf[1] := Hi(W);
  BlockWrite(F, Buf, 2);
End;

{ ---- WriteBinDWord : ecrire un dword LE dans un fichier ------ }
Procedure WriteBinDWord(Var F : File; D : LongInt);
Var Buf : Array[0..3] of Byte;
Begin
  Buf[0] := Byte(D And $FF);
  Buf[1] := Byte((D Shr 8) And $FF);
  Buf[2] := Byte((D Shr 16) And $FF);
  Buf[3] := Byte((D Shr 24) And $FF);
  BlockWrite(F, Buf, 4);
End;

{ ---- WriteBinZeros : ecrire N octets nuls dans un fichier ---- }
Procedure WriteBinZeros(Var F : File; N : LongInt);
Var Zero : Byte;
    I    : LongInt;
Begin
  Zero := 0;
  For I := 1 To N Do
    BlockWrite(F, Zero, 1);
End;

{ ---- WriteBinString : ecrire une chaine ASCIIZ sans longueur - }
Procedure WriteBinString(Var F : File; S : TString);
Var I : Integer;
Begin
  For I := 1 To Length(S) Do
    WriteBinByte(F, Byte(S[I]));
  WriteBinByte(F, 0);
End;

{ ---- AlignUp : arrondir N au multiple de A superieur --------- }
Function AlignUp(N, A : LongInt) : LongInt;
Begin
  If (N Mod A) = 0 Then
    AlignUp := N
  Else
    AlignUp := N + A - (N Mod A);
End;

{ ============================================================ }

{ ============================================================ }
{ BinAssemble : Mini-assembleur x86 32 bits                    }
{ Lit le fichier .ASM genere et remplit BinCode[] / BinData[]  }
{ ============================================================ }

Function AsmRegIdx32(Const S : String) : Integer;
Begin
  If S = 'EAX' Then AsmRegIdx32 := 0
  Else If S = 'ECX' Then AsmRegIdx32 := 1
  Else If S = 'EDX' Then AsmRegIdx32 := 2
  Else If S = 'EBX' Then AsmRegIdx32 := 3
  Else If S = 'ESP' Then AsmRegIdx32 := 4
  Else If S = 'EBP' Then AsmRegIdx32 := 5
  Else If S = 'ESI' Then AsmRegIdx32 := 6
  Else If S = 'EDI' Then AsmRegIdx32 := 7
  Else AsmRegIdx32 := -1;
End;

Function AsmRegIdx8(Const S : String) : Integer;
Begin
  If S = 'AL' Then AsmRegIdx8 := 0
  Else If S = 'CL' Then AsmRegIdx8 := 1
  Else If S = 'DL' Then AsmRegIdx8 := 2
  Else If S = 'BL' Then AsmRegIdx8 := 3
  Else AsmRegIdx8 := -1;
End;

Function AsmFindAPI(Const S : String) : Integer;
Var I : Integer;
Begin
  AsmFindAPI := -1;
  For I := 0 To PE_NUM_API - 1 Do
    If S = BinAPIDecorated[I] Then
    Begin
      AsmFindAPI := I;
      Exit;
    End;
End;

Function AsmParseImm(Const S : String) : LongInt;
Var Code : Integer; V : LongInt;
Begin
  Val(S, V, Code);
  If Code = 0 Then AsmParseImm := V
  Else AsmParseImm := 0;
End;

{ Returns True if bracket contents reference a register (not a label) }
Function AsmIsRegBased(Const S : String) : Boolean;
Var Base : String;
    I : Integer;
Begin
  AsmIsRegBased := False;
  Base := S;
  For I := 1 To Length(Base) Do
    If (Base[I] = '+') Or (Base[I] = '-') Or (Base[I] = '*') Then
    Begin
      Base := Copy(Base, 1, I - 1);
      Break;
    End;
  While (Length(Base) > 0) And (Base[Length(Base)] = ' ') Do
    Delete(Base, Length(Base), 1);
  AsmIsRegBased := (AsmRegIdx32(Base) >= 0);
End;

Function AsmTrimLine(Const S : String) : String;
Var I, J, K : Integer; R : String;
Begin
  R := S;
  K := 0;
  For I := 1 To Length(R) Do
    If R[I] = ';' Then Begin K := I; Break; End;
  If K > 0 Then R := Copy(R, 1, K - 1);
  I := 1;
  While (I <= Length(R)) And ((R[I] = ' ') Or (R[I] = #9)) Do Inc(I);
  J := Length(R);
  While (J >= I) And ((R[J] = ' ') Or (R[J] = #9)) Do Dec(J);
  If I > J Then AsmTrimLine := ''
  Else AsmTrimLine := Copy(R, I, J - I + 1);
End;

Function AsmIsLabel(Const S : String) : Boolean;
Begin
  AsmIsLabel := (Length(S) > 1) And (S[Length(S)] = ':');
End;

Function AsmExtractLabel(Const S : String) : String;
Begin
  AsmExtractLabel := Copy(S, 1, Length(S) - 1);
End;

Function AsmStartsWith(Const S, Prefix : String) : Boolean;
Var I : Integer;
Begin
  AsmStartsWith := False;
  If Length(S) < Length(Prefix) Then Exit;
  For I := 1 To Length(Prefix) Do
    If S[I] <> Prefix[I] Then Exit;
  AsmStartsWith := True;
End;

Function AsmGetMnemonic(Const S : String) : String;
Var I : Integer;
Begin
  I := 1;
  While (I <= Length(S)) And (S[I] <> ' ') And (S[I] <> #9) Do Inc(I);
  AsmGetMnemonic := Copy(S, 1, I - 1);
End;

Function AsmGetOperands(Const S : String) : String;
Var I : Integer;
Begin
  I := 1;
  While (I <= Length(S)) And (S[I] <> ' ') And (S[I] <> #9) Do Inc(I);
  While (I <= Length(S)) And ((S[I] = ' ') Or (S[I] = #9)) Do Inc(I);
  If I > Length(S) Then AsmGetOperands := ''
  Else AsmGetOperands := Copy(S, I, Length(S) - I + 1);
End;

Procedure AsmSplitOps(Const S : String; Var Op1, Op2 : String);
Var I : Integer;
Begin
  Op1 := ''; Op2 := '';
  I := 1;
  While (I <= Length(S)) And (S[I] <> ',') Do
  Begin
    Op1 := Op1 + S[I];
    Inc(I);
  End;
  While (Length(Op1) > 0) And (Op1[Length(Op1)] = ' ') Do
    Delete(Op1, Length(Op1), 1);
  If I <= Length(S) Then
  Begin
    Inc(I);
    While (I <= Length(S)) And (S[I] = ' ') Do Inc(I);
    Op2 := Copy(S, I, Length(S) - I + 1);
    While (Length(Op2) > 0) And (Op2[Length(Op2)] = ' ') Do
      Delete(Op2, Length(Op2), 1);
  End;
End;

Function AsmExtractBracket(Const S : String) : String;
Var I, Start : Integer;
Begin
  AsmExtractBracket := '';
  Start := 0;
  For I := 1 To Length(S) Do
    If S[I] = '[' Then Begin Start := I + 1; Break; End;
  If Start = 0 Then Exit;
  I := Start;
  While (I <= Length(S)) And (S[I] <> ']') Do Inc(I);
  AsmExtractBracket := Copy(S, Start, I - Start);
End;

{ Encode a memory reference inside brackets.
  RegField = the reg field for the ModRM byte. }
Procedure AsmEncodeMemory(Const Bracket : String; RegField : Integer);
Var
  PlusPos, MinusPos, I : Integer;
  Base, Idx : String;
  BaseR, IdxR : Integer;
  Disp : LongInt;
  StarP, PlusP2, ScaleV, ScaleF : Integer;
  IdxName, ScaleAndRest, ScaleStr, DispStr : String;
Begin
  PlusPos := 0; MinusPos := 0;
  For I := 1 To Length(Bracket) Do
  Begin
    If (Bracket[I] = '+') And (PlusPos = 0) Then PlusPos := I;
    If (Bracket[I] = '-') And (MinusPos = 0) Then MinusPos := I;
  End;

  If (PlusPos = 0) And (MinusPos = 0) Then
  Begin
    { Simple: [reg] or [label] }
    BaseR := AsmRegIdx32(Bracket);
    If BaseR >= 0 Then
    Begin
      If BaseR = 5 Then
      Begin { [EBP] needs mod=01 disp8=0 }
        BinEmitByte((1 Shl 6) Or (RegField Shl 3) Or 5);
        BinEmitByte(0);
      End
      Else If BaseR = 4 Then
      Begin { [ESP] needs SIB }
        BinEmitByte((0 Shl 6) Or (RegField Shl 3) Or 4);
        BinEmitByte($24);
      End
      Else
        BinEmitByte((0 Shl 6) Or (RegField Shl 3) Or BaseR);
    End
    Else
    Begin { [label] = [disp32] }
      BinEmitByte((0 Shl 6) Or (RegField Shl 3) Or 5);
      BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
      BinEmitDWord(0);
    End;
  End
  Else If PlusPos > 0 Then
  Begin
    Base := Copy(Bracket, 1, PlusPos - 1);
    Idx := Copy(Bracket, PlusPos + 1, Length(Bracket) - PlusPos);
    While (Length(Base) > 0) And (Base[Length(Base)] = ' ') Do
      Delete(Base, Length(Base), 1);
    While (Length(Idx) > 0) And (Idx[1] = ' ') Do
      Delete(Idx, 1, 1);
    BaseR := AsmRegIdx32(Base);
    IdxR := AsmRegIdx32(Idx);
    If (BaseR >= 0) And (IdxR >= 0) Then
    Begin { [base+index] needs SIB }
      If BaseR = 5 Then
      Begin { [EBP+index] needs mod=01 disp8=0 }
        BinEmitByte((1 Shl 6) Or (RegField Shl 3) Or 4);
        BinEmitByte((0 Shl 6) Or (IdxR Shl 3) Or BaseR);
        BinEmitByte(0);
      End
      Else
      Begin
        BinEmitByte((0 Shl 6) Or (RegField Shl 3) Or 4);
        BinEmitByte((0 Shl 6) Or (IdxR Shl 3) Or BaseR);
      End;
    End
    Else If (BaseR >= 0) And (Pos('*', Idx) > 0) Then
    Begin { [base+index*scale] or [base+index*scale+disp] }
      { Parse index*scale and optional +disp }
      Disp := 0;
      StarP := Pos('*', Idx);
      IdxName := Copy(Idx, 1, StarP - 1);
      While (Length(IdxName) > 0) And (IdxName[Length(IdxName)] = ' ') Do
        Delete(IdxName, Length(IdxName), 1);
      ScaleAndRest := Copy(Idx, StarP + 1, Length(Idx) - StarP);
      While (Length(ScaleAndRest) > 0) And (ScaleAndRest[1] = ' ') Do
        Delete(ScaleAndRest, 1, 1);
      PlusP2 := Pos('+', ScaleAndRest);
      If PlusP2 > 0 Then
      Begin
        ScaleStr := Copy(ScaleAndRest, 1, PlusP2 - 1);
        DispStr := Copy(ScaleAndRest, PlusP2 + 1, Length(ScaleAndRest) - PlusP2);
        ScaleV := AsmParseImm(ScaleStr);
        Disp := AsmParseImm(DispStr);
      End
      Else
      Begin
        ScaleV := AsmParseImm(ScaleAndRest);
        Disp := 0;
      End;
      IdxR := AsmRegIdx32(IdxName);
      Case ScaleV Of
        1: ScaleF := 0;
        2: ScaleF := 1;
        4: ScaleF := 2;
        8: ScaleF := 3;
      Else ScaleF := 0;
      End;
      If (Disp = 0) And (BaseR <> 5) Then
      Begin
        BinEmitByte((0 Shl 6) Or (RegField Shl 3) Or 4);
        BinEmitByte((ScaleF Shl 6) Or (IdxR Shl 3) Or BaseR);
      End
      Else If (Disp >= -128) And (Disp <= 127) Then
      Begin
        BinEmitByte((1 Shl 6) Or (RegField Shl 3) Or 4);
        BinEmitByte((ScaleF Shl 6) Or (IdxR Shl 3) Or BaseR);
        BinEmitByte(Byte(Disp And $FF));
      End
      Else
      Begin
        BinEmitByte((2 Shl 6) Or (RegField Shl 3) Or 4);
        BinEmitByte((ScaleF Shl 6) Or (IdxR Shl 3) Or BaseR);
        BinEmitDWord(Disp);
      End;
    End
    Else If BaseR >= 0 Then
    Begin { [base+disp] }
      Disp := AsmParseImm(Idx);
      If (Disp >= -128) And (Disp <= 127) Then
      Begin
        If BaseR = 4 Then
        Begin
          BinEmitByte((1 Shl 6) Or (RegField Shl 3) Or 4);
          BinEmitByte($24);
        End
        Else
          BinEmitByte((1 Shl 6) Or (RegField Shl 3) Or BaseR);
        BinEmitByte(Byte(Disp And $FF));
      End
      Else
      Begin
        If BaseR = 4 Then
        Begin
          BinEmitByte((2 Shl 6) Or (RegField Shl 3) Or 4);
          BinEmitByte($24);
        End
        Else
          BinEmitByte((2 Shl 6) Or (RegField Shl 3) Or BaseR);
        BinEmitDWord(Disp);
      End;
    End;
  End
  Else
  Begin { [base-disp] }
    Base := Copy(Bracket, 1, MinusPos - 1);
    Idx := Copy(Bracket, MinusPos + 1, Length(Bracket) - MinusPos);
    While (Length(Base) > 0) And (Base[Length(Base)] = ' ') Do
      Delete(Base, Length(Base), 1);
    While (Length(Idx) > 0) And (Idx[1] = ' ') Do
      Delete(Idx, 1, 1);
    BaseR := AsmRegIdx32(Base);
    Disp := -AsmParseImm(Idx);
    If (Disp >= -128) And (Disp <= 127) Then
    Begin
      If BaseR = 4 Then
      Begin
        BinEmitByte((1 Shl 6) Or (RegField Shl 3) Or 4);
        BinEmitByte($24);
      End
      Else
        BinEmitByte((1 Shl 6) Or (RegField Shl 3) Or BaseR);
      BinEmitByte(Byte(Disp And $FF));
    End
    Else
    Begin
      If BaseR = 4 Then
      Begin
        BinEmitByte((2 Shl 6) Or (RegField Shl 3) Or 4);
        BinEmitByte($24);
      End
      Else
        BinEmitByte((2 Shl 6) Or (RegField Shl 3) Or BaseR);
      BinEmitDWord(Disp);
    End;
  End;
End;

{ ---- AsmEncodeInstr : encoder une instruction x86 ----------- }
Procedure AsmEncodeInstr(Const Line : String);
Var
  Mnem, Ops, Op1, Op2, Op3, Bracket : String;
  R1, R2, I, CommaPos : Integer;
  Imm : LongInt;
  ApiIdx : Integer;
Begin
  Mnem := AsmGetMnemonic(Line);
  Ops := AsmGetOperands(Line);
  AsmSplitOps(Ops, Op1, Op2);

  { ---- Simple single-byte instructions ---- }
  If Mnem = 'RET' Then
  Begin
    If Length(Op1) > 0 Then
    Begin { RET imm16 : C2 lo hi }
      Imm := AsmParseImm(Op1);
      BinEmitByte($C2);
      BinEmitByte(Byte(Imm And $FF));
      BinEmitByte(Byte((Imm Shr 8) And $FF));
    End
    Else
      BinEmitByte($C3);  { RET }
    Exit;
  End;
  If Mnem = 'LODSB' Then Begin BinEmitByte($AC); Exit; End;
  If Mnem = 'STOSB' Then Begin BinEmitByte($AA); Exit; End;
  If Mnem = 'MOVSB' Then Begin BinEmitByte($A4); Exit; End;
  If Mnem = 'CDQ' Then Begin BinEmitByte($99); Exit; End;

  { ---- PUSH ---- }
  If Mnem = 'PUSH' Then
  Begin
    If AsmStartsWith(Op1, 'DWORD PTR [') Then
    Begin
      Bracket := AsmExtractBracket(Op1);
      If AsmIsRegBased(Bracket) Then
      Begin { Register-based: FF /6 + ModRM/SIB }
        BinEmitByte($FF);
        AsmEncodeMemory(Bracket, 6);
      End
      Else
      Begin { Direct memory label }
        BinEmitByte($FF);
        BinEmitByte($35);
        BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
        BinEmitDWord(0);
      End;
      Exit;
    End;
    R1 := AsmRegIdx32(Op1);
    If R1 >= 0 Then
    Begin BinEmitByte($50 + R1); Exit; End;
    { PUSH OFFSET label -> fixup ABS32 }
    If AsmStartsWith(Op1, 'OFFSET ') Then
    Begin
      BinEmitByte($68);
      BinAddFixup(BinCodeLen, BFK_ABS32,
        Copy(Op1, 8, Length(Op1) - 7), True);
      BinEmitDWord(0);
      Exit;
    End;
    Imm := AsmParseImm(Op1);
    If (Imm >= -128) And (Imm <= 127) Then
    Begin
      BinEmitByte($6A);
      BinEmitByte(Byte(Imm And $FF));
    End
    Else
    Begin
      BinEmitByte($68);
      BinEmitDWord(Imm);
    End;
    Exit;
  End;

  { ---- POP ---- }
  If Mnem = 'POP' Then
  Begin
    R1 := AsmRegIdx32(Op1);
    If R1 >= 0 Then BinEmitByte($58 + R1);
    Exit;
  End;

  { ---- MOV ---- }
  If Mnem = 'MOV' Then
  Begin
    { MOV DWORD PTR [mem], reg32 or imm32 }
    If AsmStartsWith(Op1, 'DWORD PTR [') Then
    Begin
      Bracket := AsmExtractBracket(Op1);
      R2 := AsmRegIdx32(Op2);
      If R2 >= 0 Then
      Begin
        { MOV DWORD PTR [mem], reg32 }
        If AsmIsRegBased(Bracket) Then
        Begin { Register-based addressing: use 89 + ModRM/SIB }
          BinEmitByte($89);
          AsmEncodeMemory(Bracket, R2);
        End
        Else If R2 = 0 Then
        Begin { Direct memory with EAX: use A3 short form }
          BinEmitByte($A3);
          BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
          BinEmitDWord(0);
        End
        Else
        Begin
          BinEmitByte($89);
          BinEmitByte((0 Shl 6) Or (R2 Shl 3) Or 5);
          BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
          BinEmitDWord(0);
        End;
      End
      Else
      Begin
        { MOV DWORD PTR [mem], imm32 : opcode C7 /0 }
        Imm := AsmParseImm(Op2);
        If AsmIsRegBased(Bracket) Then
        Begin
          BinEmitByte($C7);
          AsmEncodeMemory(Bracket, 0); { /0 = reg field 0 }
          BinEmitDWord(Imm);
        End
        Else
        Begin
          BinEmitByte($C7);
          BinEmitByte($05); { mod=00, reg=0 (/0), r/m=5 (disp32) }
          BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
          BinEmitDWord(0);
          BinEmitDWord(Imm);
        End;
      End;
      Exit;
    End;
    { MOV BYTE PTR [mem], reg8/imm8 }
    If AsmStartsWith(Op1, 'BYTE PTR [') Then
    Begin
      Bracket := AsmExtractBracket(Op1);
      R2 := AsmRegIdx8(Op2);
      If R2 >= 0 Then
      Begin
        BinEmitByte($88);
        AsmEncodeMemory(Bracket, R2);
      End
      Else
      Begin
        Imm := AsmParseImm(Op2);
        BinEmitByte($C6);
        AsmEncodeMemory(Bracket, 0);
        BinEmitByte(Byte(Imm And $FF));
      End;
      Exit;
    End;
    { MOV reg, DWORD PTR [mem] }
    If AsmStartsWith(Op2, 'DWORD PTR [') Then
    Begin
      Bracket := AsmExtractBracket(Op2);
      R1 := AsmRegIdx32(Op1);
      If AsmIsRegBased(Bracket) Then
      Begin { Register-based addressing: use 8B + ModRM/SIB }
        BinEmitByte($8B);
        AsmEncodeMemory(Bracket, R1);
      End
      Else If R1 = 0 Then
      Begin { Direct memory with EAX: use A1 short form }
        BinEmitByte($A1);
        BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
        BinEmitDWord(0);
      End
      Else
      Begin { Direct memory with other reg }
        BinEmitByte($8B);
        BinEmitByte((0 Shl 6) Or (R1 Shl 3) Or 5);
        BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
        BinEmitDWord(0);
      End;
      Exit;
    End;
    { MOV reg8, BYTE PTR [mem] }
    If AsmStartsWith(Op2, 'BYTE PTR [') Then
    Begin
      Bracket := AsmExtractBracket(Op2);
      R1 := AsmRegIdx8(Op1);
      BinEmitByte($8A);
      AsmEncodeMemory(Bracket, R1);
      Exit;
    End;
    { MOV reg32, reg32 }
    R1 := AsmRegIdx32(Op1);
    R2 := AsmRegIdx32(Op2);
    If (R1 >= 0) And (R2 >= 0) Then
    Begin
      BinEmitByte($89);
      BinEmitByte((3 Shl 6) Or (R2 Shl 3) Or R1);
      Exit;
    End;
    { MOV reg32, OFFSET label -> fixup ABS32 }
    If (R1 >= 0) And AsmStartsWith(Op2, 'OFFSET ') Then
    Begin
      BinEmitByte($B8 + R1);
      BinAddFixup(BinCodeLen, BFK_ABS32,
        Copy(Op2, 8, Length(Op2) - 7), True);
      BinEmitDWord(0);
      Exit;
    End;
    { MOV reg32, imm32 }
    If R1 >= 0 Then
    Begin
      Imm := AsmParseImm(Op2);
      BinEmitByte($B8 + R1);
      BinEmitDWord(Imm);
      Exit;
    End;
    Exit;
  End;

  { ---- LEA ---- }
  If Mnem = 'LEA' Then
  Begin
    R1 := AsmRegIdx32(Op1);
    Bracket := AsmExtractBracket(Op2);
    If AsmIsRegBased(Bracket) Then
    Begin { Register-based: LEA reg, [reg+...] }
      BinEmitByte($8D);
      AsmEncodeMemory(Bracket, R1);
    End
    Else
    Begin { Label-based: LEA reg, [label] or LEA reg, [label+offset] }
      BinEmitByte($8D);
      BinEmitByte((0 Shl 6) Or (R1 Shl 3) Or 5);
      BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
      BinEmitDWord(0);
    End;
    Exit;
  End;

  { ---- CALL ---- }
  If Mnem = 'CALL' Then
  Begin
    ApiIdx := AsmFindAPI(Op1);
    If ApiIdx >= 0 Then
    Begin
      BinEmitByte($FF);
      BinEmitByte($15);
      BinAddFixup(BinCodeLen, BFK_IAT32, Op1, True);
      BinEmitDWord(0);
    End
    Else
    Begin
      BinEmitByte($E8);
      BinAddFixup(BinCodeLen, BFK_REL32, Op1, True);
      BinEmitDWord(0);
    End;
    Exit;
  End;

  { ---- JMP ---- }
  If Mnem = 'JMP' Then
  Begin
    BinEmitByte($E9);
    BinAddFixup(BinCodeLen, BFK_REL32, Op1, True);
    BinEmitDWord(0);
    Exit;
  End;

  { ---- Jcc (conditional jumps) ---- }
  If (Mnem = 'JZ') Or (Mnem = 'JE') Then
  Begin
    BinEmitByte($0F); BinEmitByte($84);
    BinAddFixup(BinCodeLen, BFK_REL32, Op1, True);
    BinEmitDWord(0); Exit;
  End;
  If (Mnem = 'JNZ') Or (Mnem = 'JNE') Then
  Begin
    BinEmitByte($0F); BinEmitByte($85);
    BinAddFixup(BinCodeLen, BFK_REL32, Op1, True);
    BinEmitDWord(0); Exit;
  End;
  If Mnem = 'JB' Then
  Begin
    BinEmitByte($0F); BinEmitByte($82);
    BinAddFixup(BinCodeLen, BFK_REL32, Op1, True);
    BinEmitDWord(0); Exit;
  End;
  If Mnem = 'JA' Then
  Begin
    BinEmitByte($0F); BinEmitByte($87);
    BinAddFixup(BinCodeLen, BFK_REL32, Op1, True);
    BinEmitDWord(0); Exit;
  End;
  If Mnem = 'JGE' Then
  Begin
    BinEmitByte($0F); BinEmitByte($8D);
    BinAddFixup(BinCodeLen, BFK_REL32, Op1, True);
    BinEmitDWord(0); Exit;
  End;
  If Mnem = 'JNS' Then
  Begin
    BinEmitByte($0F); BinEmitByte($89);
    BinAddFixup(BinCodeLen, BFK_REL32, Op1, True);
    BinEmitDWord(0); Exit;
  End;
  If Mnem = 'JG' Then
  Begin
    BinEmitByte($0F); BinEmitByte($8F);
    BinAddFixup(BinCodeLen, BFK_REL32, Op1, True);
    BinEmitDWord(0); Exit;
  End;
  If Mnem = 'JL' Then
  Begin
    BinEmitByte($0F); BinEmitByte($8C);
    BinAddFixup(BinCodeLen, BFK_REL32, Op1, True);
    BinEmitDWord(0); Exit;
  End;
  If (Mnem = 'JLE') Or (Mnem = 'JNG') Then
  Begin
    BinEmitByte($0F); BinEmitByte($8E);
    BinAddFixup(BinCodeLen, BFK_REL32, Op1, True);
    BinEmitDWord(0); Exit;
  End;
  If Mnem = 'JS' Then
  Begin
    BinEmitByte($0F); BinEmitByte($88);
    BinAddFixup(BinCodeLen, BFK_REL32, Op1, True);
    BinEmitDWord(0); Exit;
  End;

  { ---- ADD ---- }
  If Mnem = 'ADD' Then
  Begin
    If Op1 = 'AL' Then
    Begin
      BinEmitByte($04);
      BinEmitByte(Byte(AsmParseImm(Op2) And $FF));
      Exit;
    End;
    R1 := AsmRegIdx8(Op1);
    If R1 >= 0 Then
    Begin
      BinEmitByte($80);
      BinEmitByte($C0 Or R1);
      BinEmitByte(Byte(AsmParseImm(Op2) And $FF));
      Exit;
    End;
    R1 := AsmRegIdx32(Op1);
    R2 := AsmRegIdx32(Op2);
    If (R1 >= 0) And (R2 >= 0) Then
    Begin
      BinEmitByte($01);
      BinEmitByte((3 Shl 6) Or (R2 Shl 3) Or R1);
      Exit;
    End;
    If R1 >= 0 Then
    Begin
      Imm := AsmParseImm(Op2);
      BinEmitByte($83);
      BinEmitByte($C0 Or R1);
      BinEmitByte(Byte(Imm And $FF));
      Exit;
    End;
    Exit;
  End;

  { ---- SUB ---- }
  If Mnem = 'SUB' Then
  Begin
    If Op1 = 'AL' Then
    Begin
      BinEmitByte($2C);
      BinEmitByte(Byte(AsmParseImm(Op2) And $FF));
      Exit;
    End;
    R1 := AsmRegIdx8(Op1);
    If R1 >= 0 Then
    Begin
      BinEmitByte($80);
      BinEmitByte($E8 Or R1);
      BinEmitByte(Byte(AsmParseImm(Op2) And $FF));
      Exit;
    End;
    R1 := AsmRegIdx32(Op1);
    R2 := AsmRegIdx32(Op2);
    If (R1 >= 0) And (R2 >= 0) Then
    Begin
      BinEmitByte($29);
      BinEmitByte((3 Shl 6) Or (R2 Shl 3) Or R1);
      Exit;
    End;
    If R1 >= 0 Then
    Begin
      Imm := AsmParseImm(Op2);
      BinEmitByte($83);
      BinEmitByte($E8 Or R1);
      BinEmitByte(Byte(Imm And $FF));
      Exit;
    End;
    Exit;
  End;

  { ---- XOR ---- }
  If Mnem = 'XOR' Then
  Begin
    R1 := AsmRegIdx32(Op1);
    R2 := AsmRegIdx32(Op2);
    If (R1 >= 0) And (R2 >= 0) Then
    Begin
      BinEmitByte($31);
      BinEmitByte((3 Shl 6) Or (R2 Shl 3) Or R1);
    End;
    Exit;
  End;

  { ---- CMP ---- }
  If Mnem = 'CMP' Then
  Begin
    { CMP BYTE PTR [mem], imm8 }
    If AsmStartsWith(Op1, 'BYTE PTR [') Then
    Begin
      Bracket := AsmExtractBracket(Op1);
      Imm := AsmParseImm(Op2);
      BinEmitByte($80);
      AsmEncodeMemory(Bracket, 7);
      BinEmitByte(Byte(Imm And $FF));
      Exit;
    End;
    { CMP AL, imm8 }
    If Op1 = 'AL' Then
    Begin
      BinEmitByte($3C);
      BinEmitByte(Byte(AsmParseImm(Op2) And $FF));
      Exit;
    End;
    { CMP reg8, imm8 or CMP reg8, reg8 }
    R1 := AsmRegIdx8(Op1);
    If R1 >= 0 Then
    Begin
      R2 := AsmRegIdx8(Op2);
      If R2 >= 0 Then
      Begin { CMP reg8, reg8 }
        BinEmitByte($38);
        BinEmitByte((3 Shl 6) Or (R2 Shl 3) Or R1);
      End
      Else
      Begin { CMP reg8, imm8 }
        Imm := AsmParseImm(Op2);
        BinEmitByte($80);
        BinEmitByte($F8 Or R1);
        BinEmitByte(Byte(Imm And $FF));
      End;
      Exit;
    End;
    { CMP reg32, reg32 or CMP reg32, imm32 or CMP reg32, DWORD PTR [mem] }
    R1 := AsmRegIdx32(Op1);
    If R1 >= 0 Then
    Begin
      { CMP reg32, DWORD PTR [mem] }
      If AsmStartsWith(Op2, 'DWORD PTR [') Then
      Begin
        Bracket := AsmExtractBracket(Op2);
        BinEmitByte($3B);
        If AsmIsRegBased(Bracket) Then
          AsmEncodeMemory(Bracket, R1)
        Else
        Begin
          BinEmitByte((0 Shl 6) Or (R1 Shl 3) Or 5);
          BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
          BinEmitDWord(0);
        End;
        Exit;
      End;
      R2 := AsmRegIdx32(Op2);
      If R2 >= 0 Then
      Begin
        BinEmitByte($39);
        BinEmitByte((3 Shl 6) Or (R2 Shl 3) Or R1);
        Exit;
      End;
      { CMP reg32, imm32 }
      Imm := AsmParseImm(Op2);
      If R1 = 0 Then
      Begin { CMP EAX, imm32 (short form) }
        BinEmitByte($3D);
        BinEmitDWord(Imm);
      End
      Else
      Begin { CMP reg32, imm32 (general form) }
        BinEmitByte($81);
        BinEmitByte($F8 Or R1);
        BinEmitDWord(Imm);
      End;
      Exit;
    End;
    Exit;
  End;

  { ---- TEST ---- }
  If Mnem = 'TEST' Then
  Begin
    R1 := AsmRegIdx8(Op1);
    R2 := AsmRegIdx8(Op2);
    If (R1 >= 0) And (R2 >= 0) Then
    Begin
      BinEmitByte($84);
      BinEmitByte((3 Shl 6) Or (R2 Shl 3) Or R1);
      Exit;
    End;
    R1 := AsmRegIdx32(Op1);
    R2 := AsmRegIdx32(Op2);
    If (R1 >= 0) And (R2 >= 0) Then
    Begin
      BinEmitByte($85);
      BinEmitByte((3 Shl 6) Or (R2 Shl 3) Or R1);
    End;
    Exit;
  End;

  { ---- INC / DEC ---- }
  If Mnem = 'INC' Then
  Begin
    R1 := AsmRegIdx32(Op1);
    If R1 >= 0 Then
      BinEmitByte($40 + R1)
    Else If AsmStartsWith(Op1, 'DWORD PTR [') Then
    Begin
      { INC DWORD PTR [mem] : FF /0 }
      Bracket := AsmExtractBracket(Op1);
      BinEmitByte($FF);
      If AsmIsRegBased(Bracket) Then
        AsmEncodeMemory(Bracket, 0)
      Else
      Begin
        BinEmitByte($05); { mod=00, reg=0 (/0), r/m=5 (disp32) }
        BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
        BinEmitDWord(0);
      End;
    End;
    Exit;
  End;
  If Mnem = 'DEC' Then
  Begin
    R1 := AsmRegIdx32(Op1);
    If R1 >= 0 Then
      BinEmitByte($48 + R1)
    Else If AsmStartsWith(Op1, 'DWORD PTR [') Then
    Begin
      { DEC DWORD PTR [mem] : FF /1 }
      Bracket := AsmExtractBracket(Op1);
      BinEmitByte($FF);
      If AsmIsRegBased(Bracket) Then
        AsmEncodeMemory(Bracket, 1)
      Else
      Begin
        BinEmitByte($0D); { mod=00, reg=1 (/1), r/m=5 (disp32) }
        BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
        BinEmitDWord(0);
      End;
    End;
    Exit;
  End;

  { ---- NEG ---- }
  If Mnem = 'NEG' Then
  Begin
    R1 := AsmRegIdx32(Op1);
    If R1 >= 0 Then
    Begin BinEmitByte($F7); BinEmitByte($D8 Or R1); End;
    Exit;
  End;

  { ---- DIV ---- }
  If Mnem = 'DIV' Then
  Begin
    R1 := AsmRegIdx32(Op1);
    If R1 >= 0 Then
    Begin BinEmitByte($F7); BinEmitByte($F0 Or R1); End;
    Exit;
  End;

  { ---- IDIV ---- }
  If Mnem = 'IDIV' Then
  Begin
    R1 := AsmRegIdx32(Op1);
    If R1 >= 0 Then
    Begin BinEmitByte($F7); BinEmitByte($F8 Or R1); End;
    Exit;
  End;

  { ---- IMUL ---- }
  If Mnem = 'IMUL' Then
  Begin
    R1 := AsmRegIdx32(Op1);
    CommaPos := 0;
    For I := 1 To Length(Op2) Do
      If Op2[I] = ',' Then Begin CommaPos := I; Break; End;
    If CommaPos > 0 Then
    Begin
      { IMUL reg, reg, imm (3-operand form) }
      Op3 := Copy(Op2, CommaPos + 1, Length(Op2) - CommaPos);
      Op2 := Copy(Op2, 1, CommaPos - 1);
      While (Length(Op2) > 0) And (Op2[Length(Op2)] = ' ') Do
        Delete(Op2, Length(Op2), 1);
      While (Length(Op3) > 0) And (Op3[1] = ' ') Do
        Delete(Op3, 1, 1);
      R2 := AsmRegIdx32(Op2);
      Imm := AsmParseImm(Op3);
      If (Imm >= -128) And (Imm <= 127) Then
      Begin
        BinEmitByte($6B);
        BinEmitByte((3 Shl 6) Or (R1 Shl 3) Or R2);
        BinEmitByte(Byte(Imm And $FF));
      End
      Else
      Begin
        BinEmitByte($69);
        BinEmitByte((3 Shl 6) Or (R1 Shl 3) Or R2);
        BinEmitDWord(Imm);
      End;
    End
    Else If Length(Op2) > 0 Then
    Begin
      { IMUL reg, reg (2-operand form) : 0F AF /r }
      R2 := AsmRegIdx32(Op2);
      BinEmitByte($0F);
      BinEmitByte($AF);
      BinEmitByte((3 Shl 6) Or (R1 Shl 3) Or R2);
    End;
    Exit;
  End;

  { ---- SETcc ---- }
  If Mnem = 'SETE' Then
  Begin
    R1 := AsmRegIdx8(Op1);
    BinEmitByte($0F); BinEmitByte($94);
    BinEmitByte($C0 Or R1); Exit;
  End;
  If Mnem = 'SETNE' Then
  Begin
    R1 := AsmRegIdx8(Op1);
    BinEmitByte($0F); BinEmitByte($95);
    BinEmitByte($C0 Or R1); Exit;
  End;
  If Mnem = 'SETG' Then
  Begin
    R1 := AsmRegIdx8(Op1);
    BinEmitByte($0F); BinEmitByte($9F);
    BinEmitByte($C0 Or R1); Exit;
  End;
  If Mnem = 'SETGE' Then
  Begin
    R1 := AsmRegIdx8(Op1);
    BinEmitByte($0F); BinEmitByte($9D);
    BinEmitByte($C0 Or R1); Exit;
  End;
  If Mnem = 'SETL' Then
  Begin
    R1 := AsmRegIdx8(Op1);
    BinEmitByte($0F); BinEmitByte($9C);
    BinEmitByte($C0 Or R1); Exit;
  End;
  If Mnem = 'SETLE' Then
  Begin
    R1 := AsmRegIdx8(Op1);
    BinEmitByte($0F); BinEmitByte($9E);
    BinEmitByte($C0 Or R1); Exit;
  End;

  { ---- MOVZX ---- }
  If Mnem = 'MOVZX' Then
  Begin
    R1 := AsmRegIdx32(Op1);
    R2 := AsmRegIdx8(Op2);
    If R2 >= 0 Then
    Begin
      BinEmitByte($0F); BinEmitByte($B6);
      BinEmitByte((3 Shl 6) Or (R1 Shl 3) Or R2);
      Exit;
    End;
    If AsmStartsWith(Op2, 'BYTE PTR [') Then
    Begin
      Bracket := AsmExtractBracket(Op2);
      BinEmitByte($0F); BinEmitByte($B6);
      AsmEncodeMemory(Bracket, R1);
      Exit;
    End;
    Exit;
  End;
End;

{ ---- AsmEncodeData : encoder une directive de donnees -------- }
Procedure AsmEncodeData(Const Line : String);
Var
  I, J, DupPos : Integer;
  LabelName, Rest, Directive, Tok : String;
  DupCount, DupVal : LongInt;
  HasLabel : Boolean;
Begin
  { Extract first token }
  I := 1;
  While (I <= Length(Line)) And (Line[I] <> ' ') Do Inc(I);
  LabelName := Copy(Line, 1, I - 1);
  If (LabelName = 'ASSUME') Or (LabelName = '') Then Exit;

  { Check if first token is a directive (continuation line, no label) }
  HasLabel := Not ((LabelName = 'DB') Or (LabelName = 'DW') Or
                   (LabelName = 'DD'));

  If HasLabel Then
  Begin
    { Register data label }
    BinAddLabel(LabelName, BinDataLen);
    BinLabels[BinLblCount - 1].InCode := False;

    { Skip spaces }
    While (I <= Length(Line)) And (Line[I] = ' ') Do Inc(I);
    { Extract directive }
    J := I;
    While (J <= Length(Line)) And (Line[J] <> ' ') Do Inc(J);
    Directive := Copy(Line, I, J - I);
    { Skip spaces }
    I := J;
    While (I <= Length(Line)) And (Line[I] = ' ') Do Inc(I);
    Rest := Copy(Line, I, Length(Line) - I + 1);
  End
  Else
  Begin
    { No label: first token is the directive }
    Directive := LabelName;
    { Skip spaces after directive }
    While (I <= Length(Line)) And (Line[I] = ' ') Do Inc(I);
    Rest := Copy(Line, I, Length(Line) - I + 1);
  End;

  If Directive = 'DD' Then
  Begin
    { Check for DUP syntax: "n DUP(v)" }
    DupPos := Pos('DUP(', Rest);
    If DupPos > 0 Then
    Begin
      Tok := '';
      For I := 1 To DupPos - 1 Do
        If Rest[I] <> ' ' Then Tok := Tok + Rest[I];
      DupCount := AsmParseImm(Tok);
      I := DupPos + 4;
      Tok := '';
      While (I <= Length(Rest)) And (Rest[I] <> ')') Do
      Begin
        If Rest[I] <> ' ' Then Tok := Tok + Rest[I];
        Inc(I);
      End;
      DupVal := AsmParseImm(Tok);
      For J := 1 To DupCount Do
        BinEmitDataDWord(DupVal);
    End
    Else
      BinEmitDataDWord(AsmParseImm(Rest));
  End
  Else If Directive = 'DB' Then
  Begin
    { Check for DUP syntax: "n DUP(v)" }
    DupPos := Pos('DUP(', Rest);
    If DupPos > 0 Then
    Begin
      Tok := '';
      For I := 1 To DupPos - 1 Do
        If Rest[I] <> ' ' Then Tok := Tok + Rest[I];
      DupCount := AsmParseImm(Tok);
      I := DupPos + 4;
      Tok := '';
      While (I <= Length(Rest)) And (Rest[I] <> ')') Do
      Begin
        If Rest[I] <> ' ' Then Tok := Tok + Rest[I];
        Inc(I);
      End;
      DupVal := AsmParseImm(Tok);
      For J := 1 To DupCount Do
        BinEmitDataByte(Byte(DupVal And $FF));
      Inc(I); { skip ')' }
      { Parse trailing comma-separated values }
      While (I <= Length(Rest)) And ((Rest[I] = ' ') Or (Rest[I] = ',')) Do
        Inc(I);
      While I <= Length(Rest) Do
      Begin
        Tok := '';
        While (I <= Length(Rest)) And (Rest[I] <> ',') Do
        Begin
          If Rest[I] <> ' ' Then Tok := Tok + Rest[I];
          Inc(I);
        End;
        If Length(Tok) > 0 Then
          BinEmitDataByte(Byte(AsmParseImm(Tok) And $FF));
        If (I <= Length(Rest)) And (Rest[I] = ',') Then Inc(I);
        While (I <= Length(Rest)) And (Rest[I] = ' ') Do Inc(I);
      End;
    End
    Else If (Length(Rest) > 0) And (Rest[1] = '''') Then
    Begin
      { String literal: 'text',0 ... }
      I := 2;
      While I <= Length(Rest) Do
      Begin
        If Rest[I] = '''' Then
        Begin
          If (I + 1 <= Length(Rest)) And (Rest[I + 1] = '''') Then
          Begin
            BinEmitDataByte(Byte(Ord('''')));
            Inc(I, 2);
          End
          Else
          Begin
            Inc(I);
            Break;
          End;
        End
        Else
        Begin
          BinEmitDataByte(Byte(Ord(Rest[I])));
          Inc(I);
        End;
      End;
      { Parse remaining comma-separated values or strings }
      While (I <= Length(Rest)) And ((Rest[I] = ' ') Or (Rest[I] = ',')) Do
        Inc(I);
      While I <= Length(Rest) Do
      Begin
        If Rest[I] = '''' Then
        Begin
          Inc(I);
          While I <= Length(Rest) Do
          Begin
            If Rest[I] = '''' Then
            Begin
              If (I + 1 <= Length(Rest)) And (Rest[I + 1] = '''') Then
              Begin
                BinEmitDataByte(Byte(Ord('''')));
                Inc(I, 2);
              End
              Else
              Begin
                Inc(I);
                Break;
              End;
            End
            Else
            Begin
              BinEmitDataByte(Byte(Ord(Rest[I])));
              Inc(I);
            End;
          End;
        End
        Else
        Begin
          Tok := '';
          While (I <= Length(Rest)) And (Rest[I] <> ',') Do
          Begin
            If Rest[I] <> ' ' Then Tok := Tok + Rest[I];
            Inc(I);
          End;
          If Length(Tok) > 0 Then
            BinEmitDataByte(Byte(AsmParseImm(Tok) And $FF));
        End;
        If (I <= Length(Rest)) And (Rest[I] = ',') Then Inc(I);
        While (I <= Length(Rest)) And (Rest[I] = ' ') Do Inc(I);
      End;
    End
    Else
    Begin
      { Comma-separated byte values: v1, v2, v3 }
      I := 1;
      While I <= Length(Rest) Do
      Begin
        Tok := '';
        While (I <= Length(Rest)) And (Rest[I] <> ',') Do
        Begin
          If Rest[I] <> ' ' Then Tok := Tok + Rest[I];
          Inc(I);
        End;
        If Length(Tok) > 0 Then
          BinEmitDataByte(Byte(AsmParseImm(Tok) And $FF));
        If (I <= Length(Rest)) And (Rest[I] = ',') Then Inc(I);
        While (I <= Length(Rest)) And (Rest[I] = ' ') Do Inc(I);
      End;
    End;
  End;
End;

{ ---- AsmIsCodeData : verifier si la ligne est DD/DB en section code }
Function AsmIsCodeData(Const S : String) : Boolean;
Var I : Integer;
Begin
  AsmIsCodeData := False;
  I := 1;
  While (I <= Length(S)) And (S[I] <> ' ') Do Inc(I);
  While (I <= Length(S)) And (S[I] = ' ') Do Inc(I);
  If (I + 1 <= Length(S)) And (S[I] = 'D') Then
  Begin
    If (S[I+1] = 'D') Or (S[I+1] = 'B') Then
    Begin
      If (I + 2 > Length(S)) Or (S[I+2] = ' ') Then
        AsmIsCodeData := True;
    End;
  End;
End;

{ ---- AsmEncodeCodeData : encoder DD/DB inline dans BinCode[] - }
Procedure AsmEncodeCodeData(Const Line : String);
Var
  I, J, DupPos : Integer;
  LabelName, Rest, Directive, Tok : String;
  DupCount, DupVal : LongInt;
Begin
  I := 1;
  While (I <= Length(Line)) And (Line[I] <> ' ') Do Inc(I);
  LabelName := Copy(Line, 1, I - 1);

  BinAddLabel(LabelName, BinCodeLen);
  BinLabels[BinLblCount - 1].InCode := True;

  While (I <= Length(Line)) And (Line[I] = ' ') Do Inc(I);
  J := I;
  While (J <= Length(Line)) And (Line[J] <> ' ') Do Inc(J);
  Directive := Copy(Line, I, J - I);
  I := J;
  While (I <= Length(Line)) And (Line[I] = ' ') Do Inc(I);
  Rest := Copy(Line, I, Length(Line) - I + 1);

  If Directive = 'DD' Then
    BinEmitDWord(AsmParseImm(Rest))
  Else If Directive = 'DB' Then
  Begin
    DupPos := Pos('DUP(', Rest);
    If DupPos > 0 Then
    Begin
      Tok := '';
      For I := 1 To DupPos - 1 Do
        If Rest[I] <> ' ' Then Tok := Tok + Rest[I];
      DupCount := AsmParseImm(Tok);
      I := DupPos + 4;
      Tok := '';
      While (I <= Length(Rest)) And (Rest[I] <> ')') Do
      Begin
        If Rest[I] <> ' ' Then Tok := Tok + Rest[I];
        Inc(I);
      End;
      DupVal := AsmParseImm(Tok);
      For J := 1 To DupCount Do
        BinEmitByte(Byte(DupVal And $FF));
      Inc(I);
      While (I <= Length(Rest)) And ((Rest[I] = ' ') Or (Rest[I] = ',')) Do
        Inc(I);
      While I <= Length(Rest) Do
      Begin
        Tok := '';
        While (I <= Length(Rest)) And (Rest[I] <> ',') Do
        Begin
          If Rest[I] <> ' ' Then Tok := Tok + Rest[I];
          Inc(I);
        End;
        If Length(Tok) > 0 Then
          BinEmitByte(Byte(AsmParseImm(Tok) And $FF));
        If (I <= Length(Rest)) And (Rest[I] = ',') Then Inc(I);
        While (I <= Length(Rest)) And (Rest[I] = ' ') Do Inc(I);
      End;
    End
    Else
    Begin
      I := 1;
      While I <= Length(Rest) Do
      Begin
        Tok := '';
        While (I <= Length(Rest)) And (Rest[I] <> ',') Do
        Begin
          If Rest[I] <> ' ' Then Tok := Tok + Rest[I];
          Inc(I);
        End;
        If Length(Tok) > 0 Then
          BinEmitByte(Byte(AsmParseImm(Tok) And $FF));
        If (I <= Length(Rest)) And (Rest[I] = ',') Then Inc(I);
        While (I <= Length(Rest)) And (Rest[I] = ' ') Do Inc(I);
      End;
    End;
  End;
End;

{ ---- BinAssemble : lire le .ASM et remplir les tampons ------- }
Procedure BinAssemble;
Var
  AsmF : Text;
  AsmPath, Line, Trimmed : String;
  InCodeSec, InDataSec : Boolean;
Begin
  BinInit;
  AsmPath := ReplaceExt(Opts.SrcFile, '.asm');
  Assign(AsmF, AsmPath);
  {$I-}
  Reset(AsmF);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WriteLn('ADACW32: erreur assembleur: impossible de lire ', AsmPath);
    Exit;
  End;

  InCodeSec := False;
  InDataSec := False;

  While Not EOF(AsmF) Do
  Begin
    ReadLn(AsmF, Line);
    Trimmed := AsmTrimLine(Line);
    If Length(Trimmed) = 0 Then Continue;

    { Detect section boundaries (handles multiple spaces) }
    If AsmStartsWith(Trimmed, '_TEXT') And (Pos('SEGMENT', Trimmed) > 0) Then
    Begin InCodeSec := True; InDataSec := False; Continue; End;
    If AsmStartsWith(Trimmed, '_TEXT') And (Pos('ENDS', Trimmed) > 0) Then
    Begin InCodeSec := False; Continue; End;
    If AsmStartsWith(Trimmed, '_DATA') And (Pos('SEGMENT', Trimmed) > 0) Then
    Begin InDataSec := True; InCodeSec := False; Continue; End;
    If AsmStartsWith(Trimmed, '_DATA') And (Pos('ENDS', Trimmed) > 0) Then
    Begin InDataSec := False; Continue; End;

    { Skip directives }
    If AsmStartsWith(Trimmed, '.') Then Continue;
    If AsmStartsWith(Trimmed, 'ASSUME') Then Continue;
    If AsmStartsWith(Trimmed, 'EXTRN') Then Continue;
    If AsmStartsWith(Trimmed, 'OPTION') Then Continue;
    If AsmStartsWith(Trimmed, 'END ') Then Continue;
    If Trimmed = 'END' Then Continue;

    If InCodeSec Then
    Begin
      If AsmIsLabel(Trimmed) Then
      Begin
        BinAddLabel(AsmExtractLabel(Trimmed), BinCodeLen);
        BinLabels[BinLblCount - 1].InCode := True;
      End
      Else If AsmIsCodeData(Trimmed) Then
        AsmEncodeCodeData(Trimmed)
      Else
        AsmEncodeInstr(Trimmed);
    End
    Else If InDataSec Then
      AsmEncodeData(Trimmed);
  End;

  Close(AsmF);
  WriteLn('ADACW32: assemblage: ', BinCodeLen, ' octets code, ',
          BinDataLen, ' octets data, ', BinLblCount, ' labels, ',
          BinFixCount, ' fixups');
End;

{ ---- BinResolveFixups : resoudre les relocations PE ---------- }
Procedure BinResolveFixups(TextRVA, DataRVA, IdataRVA, IatOfs : LongInt);
Var
  I, J : Integer;
  TgtOfs : LongInt;
  TgtInCode : Boolean;
  Addr : LongInt;
  ApiIdx : Integer;
  TgtName : TString;
  LblExtraOfs : LongInt;
  PlusP : Integer;
Begin
  For I := 0 To BinFixCount - 1 Do
  Begin
    If BinFixups[I].Kind = BFK_IAT32 Then
    Begin
      ApiIdx := AsmFindAPI(BinFixups[I].Target);
      If ApiIdx >= 0 Then
      Begin
        Addr := PE_IMG_BASE + IdataRVA + IatOfs + ApiIdx * 4;
        BinCode[BinFixups[I].Offset]     := Byte(Addr And $FF);
        BinCode[BinFixups[I].Offset + 1] := Byte((Addr Shr 8) And $FF);
        BinCode[BinFixups[I].Offset + 2] := Byte((Addr Shr 16) And $FF);
        BinCode[BinFixups[I].Offset + 3] := Byte((Addr Shr 24) And $FF);
      End;
    End
    Else
    Begin
      { Parse label+offset if present (e.g. _ADART_NUMBUF+11) }
      TgtName := BinFixups[I].Target;
      LblExtraOfs := 0;
      PlusP := Pos('+', TgtName);
      If PlusP > 0 Then
      Begin
        LblExtraOfs := AsmParseImm(Copy(TgtName, PlusP + 1, Length(TgtName) - PlusP));
        TgtName := Copy(TgtName, 1, PlusP - 1);
      End;
      { Find target label }
      TgtOfs := -1;
      TgtInCode := True;
      For J := 0 To BinLblCount - 1 Do
        If BinLabels[J].Name = TgtName Then
        Begin
          TgtOfs := BinLabels[J].Offset;
          TgtInCode := BinLabels[J].InCode;
          Break;
        End;
      If TgtOfs < 0 Then Continue;

      TgtOfs := TgtOfs + LblExtraOfs;

      If BinFixups[I].Kind = BFK_REL32 Then
      Begin
        Addr := TgtOfs - (BinFixups[I].Offset + 4);
        BinCode[BinFixups[I].Offset]     := Byte(Addr And $FF);
        BinCode[BinFixups[I].Offset + 1] := Byte((Addr Shr 8) And $FF);
        BinCode[BinFixups[I].Offset + 2] := Byte((Addr Shr 16) And $FF);
        BinCode[BinFixups[I].Offset + 3] := Byte((Addr Shr 24) And $FF);
      End
      Else If BinFixups[I].Kind = BFK_ABS32 Then
      Begin
        If TgtInCode Then
          Addr := PE_IMG_BASE + TextRVA + TgtOfs
        Else
          Addr := PE_IMG_BASE + DataRVA + TgtOfs;
        BinCode[BinFixups[I].Offset]     := Byte(Addr And $FF);
        BinCode[BinFixups[I].Offset + 1] := Byte((Addr Shr 8) And $FF);
        BinCode[BinFixups[I].Offset + 2] := Byte((Addr Shr 16) And $FF);
        BinCode[BinFixups[I].Offset + 3] := Byte((Addr Shr 24) And $FF);
      End;
    End;
  End;
End;


{ BinWriteObj : generer un fichier COFF .OBJ 32 bits           }
{ ============================================================ }
{ Structure COFF .OBJ :                                         }
{   COFF Header (20 octets)                                     }
{   Section headers (2 x 40 octets : .text + .data)             }
{   Section .text raw data                                      }
{   Section .data raw data                                      }
{   Relocation table (10 octets par relocation)                  }
{   Symbol table + string table                                  }
Procedure BinWriteObj;
Var
  F           : File;
  ObjFile     : TString;
  NumSections : Word;
  HdrOfs      : LongInt;
  TextDataOfs : LongInt;
  DataDataOfs : LongInt;
  RelocOfs    : LongInt;
  SymTabOfs   : LongInt;
  NumSymbols  : LongInt;
  StrTabSize  : LongInt;
  I           : Integer;
  Pad         : LongInt;
  Zero        : Byte;
Begin
  ObjFile := Opts.OutFile;
  Assign(F, ObjFile);
  {$I-}
  Rewrite(F, 1);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WriteLn('ADACW32: erreur: impossible de creer ', ObjFile);
    Exit;
  End;

  BinInit;
  NumSections := 2; { .text + .data }

  { Generer des donnees binaires stub : }
  { .text = petit programme stub (INT3 = breakpoint) }
  BinEmitByte($CC);  { INT3 - breakpoint }
  BinEmitByte($C3);  { RET }

  { .data = quelques octets nuls }
  BinEmitDataDWord(0);  { placeholder }

  { Calculer les offsets }
  HdrOfs      := 0;      { COFF header }
  TextDataOfs := 20 + NumSections * 40;
  DataDataOfs := TextDataOfs + BinCodeLen;
  RelocOfs    := DataDataOfs + BinDataLen;
  NumSymbols  := 2; { .text et .data }
  SymTabOfs   := RelocOfs;  { pas de relocations pour le stub }

  { ---- COFF Header (20 octets) ---- }
  WriteBinWord(F, PE_MACHINE_I386);     { Machine = i386 }
  WriteBinWord(F, NumSections);         { NumberOfSections }
  WriteBinDWord(F, 0);                  { TimeDateStamp }
  WriteBinDWord(F, SymTabOfs);          { PointerToSymbolTable }
  WriteBinDWord(F, NumSymbols);         { NumberOfSymbols }
  WriteBinWord(F, 0);                   { SizeOfOptionalHeader }
  WriteBinWord(F, 0);                   { Characteristics }

  { ---- Section header: .text (40 octets) ---- }
  WriteBinString(F, '.text');     { Name (8 octets) }
  Pad := 8 - (Length('.text') + 1);
  If Pad > 0 Then WriteBinZeros(F, Pad);
  WriteBinDWord(F, BinCodeLen);   { VirtualSize }
  WriteBinDWord(F, 0);            { VirtualAddress (0 for .OBJ) }
  WriteBinDWord(F, BinCodeLen);   { SizeOfRawData }
  WriteBinDWord(F, TextDataOfs);  { PointerToRawData }
  WriteBinDWord(F, 0);            { PointerToRelocations }
  WriteBinDWord(F, 0);            { PointerToLinenumbers }
  WriteBinWord(F, 0);             { NumberOfRelocations }
  WriteBinWord(F, 0);             { NumberOfLinenumbers }
  WriteBinDWord(F, PE_SCN_TEXT);  { Characteristics }

  { ---- Section header: .data (40 octets) ---- }
  WriteBinString(F, '.data');     { Name (8 octets) }
  Pad := 8 - (Length('.data') + 1);
  If Pad > 0 Then WriteBinZeros(F, Pad);
  WriteBinDWord(F, BinDataLen);   { VirtualSize }
  WriteBinDWord(F, 0);            { VirtualAddress (0 for .OBJ) }
  WriteBinDWord(F, BinDataLen);   { SizeOfRawData }
  WriteBinDWord(F, DataDataOfs);  { PointerToRawData }
  WriteBinDWord(F, 0);            { PointerToRelocations }
  WriteBinDWord(F, 0);            { PointerToLinenumbers }
  WriteBinWord(F, 0);             { NumberOfRelocations }
  WriteBinWord(F, 0);             { NumberOfLinenumbers }
  WriteBinDWord(F, PE_SCN_BSS);   { Characteristics = INIT_DATA|READ|WRITE }

  { ---- Section .text raw data ---- }
  BlockWrite(F, BinCode, BinCodeLen);

  { ---- Section .data raw data ---- }
  BlockWrite(F, BinData, BinDataLen);

  { ---- Symbol table (18 octets par symbole) ---- }
  { Symbole 0 : .text }
  Zero := 0;
  WriteBinString(F, '.text');
  Pad := 8 - (Length('.text') + 1);
  If Pad > 0 Then WriteBinZeros(F, Pad);
  WriteBinDWord(F, 0);     { Value }
  WriteBinWord(F, 1);      { SectionNumber = 1 (.text) }
  WriteBinWord(F, 0);      { Type }
  WriteBinByte(F, 3);      { StorageClass = IMAGE_SYM_CLASS_STATIC }
  WriteBinByte(F, 0);      { NumberOfAuxSymbols }

  { Symbole 1 : .data }
  WriteBinString(F, '.data');
  Pad := 8 - (Length('.data') + 1);
  If Pad > 0 Then WriteBinZeros(F, Pad);
  WriteBinDWord(F, 0);     { Value }
  WriteBinWord(F, 2);      { SectionNumber = 2 (.data) }
  WriteBinWord(F, 0);      { Type }
  WriteBinByte(F, 3);      { StorageClass = IMAGE_SYM_CLASS_STATIC }
  WriteBinByte(F, 0);      { NumberOfAuxSymbols }

  { ---- String table (4 octets = taille, aucune chaine supp.) -- }
  StrTabSize := 4;
  WriteBinDWord(F, StrTabSize);

  Close(F);
  WriteLn('ADACW32: fichier OBJ genere: ', ObjFile);
  WriteLn('ADACW32: .text = ', BinCodeLen, ' octets');
  WriteLn('ADACW32: .data = ', BinDataLen, ' octets');
End;

{ ============================================================ }
{ BinWriteExe : generer un fichier PE .EXE 32 bits             }
{ ============================================================ }
{ Structure PE :                                                }
{   DOS Stub (128 octets)                                       }
{   PE Signature (4 octets)                                     }
{   COFF Header (20 octets)                                     }
{   Optional Header PE32 (224 octets)                           }
{   Section headers (3 x 40 : .text, .data, .idata)            }
{   Padding to file alignment                                   }
{   Section .text (code machine 80386)                          }
{   Section .data (variables et litteraux)                      }
{   Section .idata (Import Address Table)                       }
Procedure BinWriteExe;
Var
  F              : File;
  ExeFile        : TString;
  HdrSize        : LongInt;
  TextRVA        : LongInt;
  DataRVA        : LongInt;
  IdataRVA       : LongInt;
  TextFileOfs    : LongInt;
  DataFileOfs    : LongInt;
  IdataFileOfs   : LongInt;
  TextSize       : LongInt;
  DataSize       : LongInt;
  IdataSize      : LongInt;
  ImageSize      : LongInt;
  EntryRVA       : LongInt;
  NumSections    : Word;
  I              : Integer;
  Pad            : LongInt;
  IdataBuf       : Array[0..1023] of Byte;
  IdataBufLen    : LongInt;
  ApiNameOfs     : LongInt;
  IltOfs         : LongInt;
  IatOfs         : LongInt;
  DllNameOfs     : LongInt;
  HintOfs        : LongInt;
  CurHint        : LongInt;
  ApiIdx         : Integer;
  HintRVA        : LongInt;
  IltEntryOfs    : LongInt;
  IatEntryOfs    : LongInt;
  CurPos         : LongInt;
  PadN           : LongInt;
Begin
  ExeFile := Opts.OutFile;
  Assign(F, ExeFile);
  {$I-}
  Rewrite(F, 1);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WriteLn('ADACW32: erreur: impossible de creer ', ExeFile);
    Exit;
  End;

  NumSections := 3; { .text, .data, .idata }

  { Construire la table d imports (.idata) }
  { Structure simplifiee :                  }
  {   Import Directory Table (20 octets)    }
  {   Null entry (20 octets)                }
  {   ILT (PE_NUM_API * 4 + 4 octets)      }
  {   IAT (PE_NUM_API * 4 + 4 octets)      }
  {   Noms DLL + Hint/Name entries          }
  IdataBufLen := 0;

  { Offsets relatifs dans le buffer idata }
  IltOfs     := 40;  { apres les 2 directory entries }
  IatOfs     := IltOfs + (PE_NUM_API + 1) * 4;
  DllNameOfs := IatOfs + (PE_NUM_API + 1) * 4;
  HintOfs    := DllNameOfs + 13; { 'kernel32.dll' + NUL = 13 }

  { Import Directory Entry : kernel32.dll }
  { Champ OriginalFirstThunk (ILT RVA) - sera patche apres }
  For I := 0 To 3 Do Begin IdataBuf[IdataBufLen] := 0; Inc(IdataBufLen); End;
  { TimeDateStamp = 0 }
  For I := 0 To 3 Do Begin IdataBuf[IdataBufLen] := 0; Inc(IdataBufLen); End;
  { ForwarderChain = 0 }
  For I := 0 To 3 Do Begin IdataBuf[IdataBufLen] := 0; Inc(IdataBufLen); End;
  { Name RVA - sera patche }
  For I := 0 To 3 Do Begin IdataBuf[IdataBufLen] := 0; Inc(IdataBufLen); End;
  { FirstThunk (IAT RVA) - sera patche }
  For I := 0 To 3 Do Begin IdataBuf[IdataBufLen] := 0; Inc(IdataBufLen); End;

  { Null Import Directory Entry (20 octets nuls) }
  For I := 0 To 19 Do Begin IdataBuf[IdataBufLen] := 0; Inc(IdataBufLen); End;

  { ILT entries (pointeurs vers Hint/Name, terminee par 0) }
  For I := 0 To PE_NUM_API - 1 Do
  Begin
    { Placeholder = 0, sera patche }
    IdataBuf[IdataBufLen] := 0; Inc(IdataBufLen);
    IdataBuf[IdataBufLen] := 0; Inc(IdataBufLen);
    IdataBuf[IdataBufLen] := 0; Inc(IdataBufLen);
    IdataBuf[IdataBufLen] := 0; Inc(IdataBufLen);
  End;
  { Null terminateur ILT }
  For I := 0 To 3 Do Begin IdataBuf[IdataBufLen] := 0; Inc(IdataBufLen); End;

  { IAT entries (meme chose que ILT) }
  For I := 0 To PE_NUM_API - 1 Do
  Begin
    IdataBuf[IdataBufLen] := 0; Inc(IdataBufLen);
    IdataBuf[IdataBufLen] := 0; Inc(IdataBufLen);
    IdataBuf[IdataBufLen] := 0; Inc(IdataBufLen);
    IdataBuf[IdataBufLen] := 0; Inc(IdataBufLen);
  End;
  { Null terminateur IAT }
  For I := 0 To 3 Do Begin IdataBuf[IdataBufLen] := 0; Inc(IdataBufLen); End;

  { Nom DLL : 'kernel32.dll' + NUL }
  For I := 1 To Length('kernel32.dll') Do
  Begin
    IdataBuf[IdataBufLen] := Byte(Ord('kernel32.dll'[I]));
    Inc(IdataBufLen);
  End;
  IdataBuf[IdataBufLen] := 0; Inc(IdataBufLen);

  { Hint/Name entries pour chaque API }
  ApiNameOfs := IdataBufLen;
  For I := 0 To PE_NUM_API - 1 Do
  Begin
    { Hint = 0 (2 octets) }
    IdataBuf[IdataBufLen] := 0; Inc(IdataBufLen);
    IdataBuf[IdataBufLen] := 0; Inc(IdataBufLen);
    { Nom de l API + NUL }
    For Pad := 1 To Length(BinAPIName[I]) Do
    Begin
      IdataBuf[IdataBufLen] := Byte(Ord(BinAPIName[I][Pad]));
      Inc(IdataBufLen);
    End;
    IdataBuf[IdataBufLen] := 0; Inc(IdataBufLen);
    { Padding pair }
    If (IdataBufLen Mod 2) <> 0 Then
    Begin
      IdataBuf[IdataBufLen] := 0; Inc(IdataBufLen);
    End;
  End;

  IdataSize := AlignUp(IdataBufLen, LongInt(PE_FILE_ALIGN));

  { Calculer les tailles et offsets }
  HdrSize := AlignUp(128 + 4 + 20 + PE_OPT_SIZE + NumSections * 40,
                      LongInt(PE_FILE_ALIGN));
  TextRVA      := LongInt(PE_SEC_ALIGN);
  TextSize     := AlignUp(BinCodeLen, LongInt(PE_FILE_ALIGN));
  TextFileOfs  := HdrSize;
  DataRVA      := TextRVA + AlignUp(BinCodeLen, LongInt(PE_SEC_ALIGN));
  DataSize     := AlignUp(BinDataLen, LongInt(PE_FILE_ALIGN));
  DataFileOfs  := TextFileOfs + TextSize;
  IdataRVA     := DataRVA + AlignUp(BinDataLen, LongInt(PE_SEC_ALIGN));
  IdataFileOfs := DataFileOfs + DataSize;
  ImageSize    := IdataRVA + AlignUp(IdataBufLen, LongInt(PE_SEC_ALIGN));
  { Le point d entree est _ADAF_main, pas le debut de .text }
  EntryRVA := TextRVA + BinFindLabel('_ADAF_main');
  If BinFindLabel('_ADAF_main') < 0 Then
    EntryRVA := TextRVA;  { fallback: debut de .text }

  { Resoudre les fixups avec les adresses PE calculees }
  BinResolveFixups(TextRVA, DataRVA, IdataRVA, IatOfs);

  { Patcher les RVAs dans le buffer idata }
  { Import Directory Entry: OriginalFirstThunk = idata RVA + IltOfs }
  IdataBuf[0] := Byte((IdataRVA + IltOfs) And $FF);
  IdataBuf[1] := Byte(((IdataRVA + IltOfs) Shr 8) And $FF);
  IdataBuf[2] := Byte(((IdataRVA + IltOfs) Shr 16) And $FF);
  IdataBuf[3] := Byte(((IdataRVA + IltOfs) Shr 24) And $FF);
  { Name RVA }
  IdataBuf[12] := Byte((IdataRVA + DllNameOfs) And $FF);
  IdataBuf[13] := Byte(((IdataRVA + DllNameOfs) Shr 8) And $FF);
  IdataBuf[14] := Byte(((IdataRVA + DllNameOfs) Shr 16) And $FF);
  IdataBuf[15] := Byte(((IdataRVA + DllNameOfs) Shr 24) And $FF);
  { FirstThunk = IAT RVA }
  IdataBuf[16] := Byte((IdataRVA + IatOfs) And $FF);
  IdataBuf[17] := Byte(((IdataRVA + IatOfs) Shr 8) And $FF);
  IdataBuf[18] := Byte(((IdataRVA + IatOfs) Shr 16) And $FF);
  IdataBuf[19] := Byte(((IdataRVA + IatOfs) Shr 24) And $FF);

  { Patcher les ILT et IAT avec les RVAs Hint/Name }
  { On doit retrouver les offsets des Hint/Name entries }
  CurHint := ApiNameOfs;
  For ApiIdx := 0 To PE_NUM_API - 1 Do
  Begin
    HintRVA := IdataRVA + CurHint;
    { ILT entry }
    IltEntryOfs := IltOfs + ApiIdx * 4;
    IdataBuf[IltEntryOfs]     := Byte(HintRVA And $FF);
    IdataBuf[IltEntryOfs + 1] := Byte((HintRVA Shr 8) And $FF);
    IdataBuf[IltEntryOfs + 2] := Byte((HintRVA Shr 16) And $FF);
    IdataBuf[IltEntryOfs + 3] := Byte((HintRVA Shr 24) And $FF);
    { IAT entry }
    IatEntryOfs := IatOfs + ApiIdx * 4;
    IdataBuf[IatEntryOfs]     := Byte(HintRVA And $FF);
    IdataBuf[IatEntryOfs + 1] := Byte((HintRVA Shr 8) And $FF);
    IdataBuf[IatEntryOfs + 2] := Byte((HintRVA Shr 16) And $FF);
    IdataBuf[IatEntryOfs + 3] := Byte((HintRVA Shr 24) And $FF);
    { Avancer apres le Hint(2) + Nom + NUL + pad pair }
    CurHint := CurHint + 2 + Length(BinAPIName[ApiIdx]) + 1;
    If (CurHint Mod 2) <> 0 Then Inc(CurHint);
  End;

  { ==================== ECRITURE DU FICHIER PE ==================== }

  { ---- DOS Stub Header (128 octets) ---- }
  WriteBinWord(F, PE_DOS_MAGIC);          { e_magic = 'MZ' }
  For I := 1 To 29 Do WriteBinWord(F, 0); { champs DOS (58 octets nuls) }
  WriteBinDWord(F, 128);                  { e_lfanew = offset PE header }
  { Remplir le reste du stub DOS (128 - 64 = 64 octets) }
  { Message DOS stub }
  WriteBinZeros(F, 64);

  { ---- PE Signature ---- }
  WriteBinDWord(F, PE_PE_SIG);            { 'PE\0\0' }

  { ---- COFF Header (20 octets) ---- }
  WriteBinWord(F, PE_MACHINE_I386);       { Machine }
  WriteBinWord(F, NumSections);           { NumberOfSections }
  WriteBinDWord(F, 0);                    { TimeDateStamp }
  WriteBinDWord(F, 0);                    { PointerToSymbolTable }
  WriteBinDWord(F, 0);                    { NumberOfSymbols }
  WriteBinWord(F, PE_OPT_SIZE);           { SizeOfOptionalHeader }
  WriteBinWord(F, $0103);                 { Characteristics: EXEC|NO_RELOC|32BIT }

  { ---- Optional Header PE32 (224 octets) ---- }
  WriteBinWord(F, PE_MAGIC_32);           { Magic = PE32 }
  WriteBinByte(F, 1);                     { MajorLinkerVersion }
  WriteBinByte(F, 0);                     { MinorLinkerVersion }
  WriteBinDWord(F, TextSize);             { SizeOfCode }
  WriteBinDWord(F, DataSize + IdataSize); { SizeOfInitializedData }
  WriteBinDWord(F, 0);                    { SizeOfUninitializedData }
  WriteBinDWord(F, EntryRVA);             { AddressOfEntryPoint }
  WriteBinDWord(F, TextRVA);              { BaseOfCode }
  WriteBinDWord(F, DataRVA);              { BaseOfData }
  WriteBinDWord(F, PE_IMG_BASE);          { ImageBase }
  WriteBinDWord(F, PE_SEC_ALIGN);         { SectionAlignment }
  WriteBinDWord(F, PE_FILE_ALIGN);        { FileAlignment }
  WriteBinWord(F, 4);                     { MajorOperatingSystemVersion }
  WriteBinWord(F, 0);                     { MinorOperatingSystemVersion }
  WriteBinWord(F, 0);                     { MajorImageVersion }
  WriteBinWord(F, 0);                     { MinorImageVersion }
  WriteBinWord(F, 4);                     { MajorSubsystemVersion }
  WriteBinWord(F, 0);                     { MinorSubsystemVersion }
  WriteBinDWord(F, 0);                    { Win32VersionValue }
  WriteBinDWord(F, ImageSize);            { SizeOfImage }
  WriteBinDWord(F, HdrSize);              { SizeOfHeaders }
  WriteBinDWord(F, 0);                    { CheckSum }
  WriteBinWord(F, PE_SUBSYS_CUI);         { Subsystem = CONSOLE }
  WriteBinWord(F, 0);                     { DllCharacteristics }
  WriteBinDWord(F, $100000);              { SizeOfStackReserve (1 MB) }
  WriteBinDWord(F, $1000);                { SizeOfStackCommit (4 KB) }
  WriteBinDWord(F, $100000);              { SizeOfHeapReserve (1 MB) }
  WriteBinDWord(F, $1000);                { SizeOfHeapCommit (4 KB) }
  WriteBinDWord(F, 0);                    { LoaderFlags }
  WriteBinDWord(F, 16);                   { NumberOfRvaAndSizes }
  { Data Directories (16 entries x 8 octets = 128 octets) }
  { Entry 0 : Export Table = 0,0 }
  WriteBinDWord(F, 0); WriteBinDWord(F, 0);
  { Entry 1 : Import Table = idata RVA, taille }
  WriteBinDWord(F, IdataRVA); WriteBinDWord(F, IdataBufLen);
  { Entries 2-11 : toutes a zero }
  For I := 2 To 11 Do
  Begin
    WriteBinDWord(F, 0); WriteBinDWord(F, 0);
  End;
  { Entry 12 : Import Address Table (IAT) }
  WriteBinDWord(F, IdataRVA + IatOfs);
  WriteBinDWord(F, (PE_NUM_API + 1) * 4);
  { Entries 13-15 : toutes a zero }
  For I := 13 To 15 Do
  Begin
    WriteBinDWord(F, 0); WriteBinDWord(F, 0);
  End;

  { ---- Section Header: .text ---- }
  { Name (8 octets) }
  For I := 1 To Length('.text') Do WriteBinByte(F, Byte(Ord('.text'[I])));
  WriteBinZeros(F, 8 - Length('.text'));
  WriteBinDWord(F, BinCodeLen);         { VirtualSize }
  WriteBinDWord(F, TextRVA);            { VirtualAddress }
  WriteBinDWord(F, TextSize);           { SizeOfRawData }
  WriteBinDWord(F, TextFileOfs);        { PointerToRawData }
  WriteBinDWord(F, 0);                  { PointerToRelocations }
  WriteBinDWord(F, 0);                  { PointerToLinenumbers }
  WriteBinWord(F, 0);                   { NumberOfRelocations }
  WriteBinWord(F, 0);                   { NumberOfLinenumbers }
  WriteBinDWord(F, PE_SCN_TEXT);        { Characteristics }

  { ---- Section Header: .data ---- }
  For I := 1 To Length('.data') Do WriteBinByte(F, Byte(Ord('.data'[I])));
  WriteBinZeros(F, 8 - Length('.data'));
  WriteBinDWord(F, BinDataLen);         { VirtualSize }
  WriteBinDWord(F, DataRVA);            { VirtualAddress }
  WriteBinDWord(F, DataSize);           { SizeOfRawData }
  WriteBinDWord(F, DataFileOfs);        { PointerToRawData }
  WriteBinDWord(F, 0);
  WriteBinDWord(F, 0);
  WriteBinWord(F, 0);
  WriteBinWord(F, 0);
  WriteBinDWord(F, PE_SCN_BSS);         { READ|WRITE|INIT_DATA }

  { ---- Section Header: .idata ---- }
  For I := 1 To 6 Do WriteBinByte(F, Byte(Ord('.idata'[I])));
  WriteBinZeros(F, 8 - 6);
  WriteBinDWord(F, IdataBufLen);        { VirtualSize }
  WriteBinDWord(F, IdataRVA);           { VirtualAddress }
  WriteBinDWord(F, IdataSize);          { SizeOfRawData }
  WriteBinDWord(F, IdataFileOfs);       { PointerToRawData }
  WriteBinDWord(F, 0);
  WriteBinDWord(F, 0);
  WriteBinWord(F, 0);
  WriteBinWord(F, 0);
  WriteBinDWord(F, PE_SCN_BSS);         { READ|WRITE|INIT_DATA }

  { ---- Padding to file alignment ---- }
  CurPos := 128 + 4 + 20 + PE_OPT_SIZE + NumSections * 40;
  PadN := HdrSize - CurPos;
  If PadN > 0 Then WriteBinZeros(F, PadN);

  { ---- Section .text raw data ---- }
  BlockWrite(F, BinCode, BinCodeLen);
  Pad := TextSize - BinCodeLen;
  If Pad > 0 Then WriteBinZeros(F, Pad);

  { ---- Section .data raw data ---- }
  BlockWrite(F, BinData, BinDataLen);
  Pad := DataSize - BinDataLen;
  If Pad > 0 Then WriteBinZeros(F, Pad);

  { ---- Section .idata raw data ---- }
  BlockWrite(F, IdataBuf, IdataBufLen);
  Pad := IdataSize - IdataBufLen;
  If Pad > 0 Then WriteBinZeros(F, Pad);

  Close(F);
  WriteLn('ADACW32: fichier EXE genere: ', ExeFile);
  WriteLn('ADACW32: .text = ', BinCodeLen, ' octets (code)');
  WriteLn('ADACW32: .data = ', BinDataLen, ' octets (donnees)');
  WriteLn('ADACW32: .idata = ', IdataBufLen, ' octets (imports)');
  WriteLn('ADACW32: image totale = ', ImageSize, ' octets');
End;

{$ENDIF}

Procedure Run;
Var AsmFile : TString;
Begin
  InitSymTable;
  InitTypeTable;
  RegisterPredefinedTypes;
  RegisterStandardExceptions;
  InitSubTable;
  InitPkgTable;
  InitScopeStack;
  InitStrTable;
  MainProcName := '';
  LexInit;
  If Opts.DebugMode Then
  Begin
    { Mode debug : afficher tous les tokens }
    While CurTokType <> TOK_EOF Do
    Begin
      PrintToken;
      LexNextToken;
    End;
    PrintToken; { afficher le token EOF }
  End
  Else
  Begin
    WriteLn('ADACW32: compilation de ', Opts.SrcFile, ' ...');

    { TODO 23 : ouvrir fichier .ASM et emettre l en-tete }
    AsmFile := ReplaceExt(Opts.SrcFile, '.asm');
    EmitOpen(AsmFile);
    EmitHeader;

    ParseWithUseSection;
    { TODO 10 : boucle TYPE/SUBTYPE }
    While (CurTokType = TOK_IDENT) And
          ((CurTokKw = KW_TYPE) Or (CurTokKw = KW_SUBTYPE)) Do
    Begin
      If CurTokKw = KW_TYPE Then ParseTypeDecl
      Else ParseSubtypeDecl;
    End;
    { TODO 11 : boucle declarations d objets (variables/constantes) }
    While (CurTokType = TOK_IDENT) And
          (CurTokKw <> KW_PROCEDURE) And (CurTokKw <> KW_FUNCTION) And
          (CurTokKw <> KW_PACKAGE) And (CurTokKw <> KW_BEGIN) And
          (CurTokKw <> KW_TYPE) And (CurTokKw <> KW_SUBTYPE) And
          (CurTokType <> TOK_EOF) Do
    Begin
      ParseObjectDecl;
    End;

    { TODO 24 : Capturer le nom de la procedure principale Ada }
    { Dans un programme Ada, la library unit est la premiere PROCEDURE }
    If (CurTokType = TOK_IDENT) And (CurTokKw = KW_PROCEDURE) Then
    Begin
      { Lire le nom sans consommer le token PROCEDURE }
      { On le retrouvera via SubTab apres le parsing }
    End;

    { TODO 12 : boucle PROCEDURE / FUNCTION }
    While (CurTokType = TOK_IDENT) And
          ((CurTokKw = KW_PROCEDURE) Or (CurTokKw = KW_FUNCTION)) Do
    Begin
      If CurTokKw = KW_PROCEDURE Then ParseProcedureDecl
      Else ParseFunctionDecl;
    End;

    { TODO 24 : determiner le nom de la procedure principale }
    { La premiere procedure enregistree avec un body est la library unit }
    If SubCount > 0 Then
      MainProcName := SubTab[1].Name;

    { TODO 14 : boucle PACKAGE SPEC / PACKAGE BODY }
    While (CurTokType = TOK_IDENT) And (CurTokKw = KW_PACKAGE) Do
    Begin
      ParsePackageDecl;
    End;
    { TODO 13 : le programme principal (BEGIN ... END) ou fin }
    If TokIsKw(KW_BEGIN) Then
    Begin
      { Programme principal : BEGIN ... END [nom] ; }
      Consume; { BEGIN }
      { Stub : skip les instructions du corps principal }
      SkipStatements;
      If TokIsKw(KW_EXCEPTION) Then
      Begin
        Consume;
        SkipStatements;
      End;
      If TokIsKw(KW_END) Then
      Begin
        Consume; { END }
        { Sauter le nom optionnel }
        While (CurTokType <> TOK_SEMI) And (CurTokType <> TOK_EOF) Do
          Consume;
        If CurTokType = TOK_SEMI Then Consume;
      End;
    End;

    { TODO 24 : emettre point d entree Win32 et helpers runtime }
    EmitEntryPoint;
    GenTextIOStubs;
    EmitRuntimeHelpers;

    { TODO 23 : emettre segment .DATA et fermer le fichier }
    EmitDataSeg;
    Emit('END ' + ADA_FN_PFX + 'main');
    EmitClose;

    { TODO 25 : generer le fichier binaire PE/COFF }
  {$IFDEF FPC}
    BinAssemble;
    If Opts.EmitObj Then
      BinWriteObj
    Else If Opts.EmitExe Then
      BinWriteExe;
    { Supprimer le fichier ASM temporaire si non demande }
    If Not Opts.EmitAsm Then
    Begin
      Assign(OutF, ReplaceExt(Opts.SrcFile, '.asm'));
      {$I-}
      Erase(OutF);
      {$I+}
      If IOResult <> 0 Then; { ignorer }
    End;
  {$ENDIF}

  End;
  LexClose;
  BilanCompilation;
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
