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

  TODO 05 - TABLES DES TYPES ET SOUS-PROGRAMMES (32 BITS)
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

  TODO 06 - GESTION DES SCOPES ET PILE DE SCOPES
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

  TODO 07 - GENERATEUR DE CODE BAS NIVEAU 80386
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

  TODO 08 - PARSEUR D'EXPRESSIONS : PRECEDENCES ADA (32 BITS)
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

  TODO 09 - PARSEUR : WITH ET USE
            ParseWithUse : traiter WITH/USE en debut de programme
            WITH pkg1, pkg2, ... ;  -> enregistrer dans PkgTab
            USE pkg1, pkg2, ... ;   -> activer acces direct (UseActive)
            Packages standard reconnus :
              Ada.Text_IO, Ada.Integer_Text_IO, Ada.Float_Text_IO,
              Ada.Numerics, System
            Pour tout autre package : avertissement "package non
              implemente"
            Marquer les packages importes IsStandard := True

  TODO 10 - PARSEUR : DECLARATIONS DE TYPES UTILISATEUR
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

  TODO 12 - PARSEUR : SIGNATURES PROCEDURE ET FUNCTION
            ParseProcedureSpec :
              PROCEDURE nom [(params)] ;
            ParseFunctionSpec :
              FUNCTION nom [(params)] RETURN type ;
            Forme des parametres :
              nom [, nom2] : [IN | IN OUT | OUT] type [:= default]
            AddSub(nom, ...) avec IsForward := True
            Enregistrer ParamNames, ParamTypes, ParamModes
            IN : passage par valeur (PUSH 32 bits)
            OUT / IN OUT : passage par adresse (LEA + PUSH)
            Convention STDCALL : parametres droite a gauche

  TODO 13 - PARSEUR : CORPS PROCEDURE ET FUNCTION (32 BITS)
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

  TODO 14 - PARSEUR : PACKAGE SPEC ET BODY
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
            PackageSpec : enregistrer exports dans SubTab / TypeTab
            PackageBody : generer les corps des sous-programmes
            Init body : generer _ADAP_nom_INIT appelee au demarrage
            Packages Ada.Text_IO : generer stubs Put/Put_Line/Get/
              Get_Line en appelant les helpers runtime Win32

  TODO 15 - PARSEUR : DISPATCHER PRINCIPAL DES INSTRUCTIONS
            Procedure ParseStatement
            Dispatcher selon le token courant :
              Identifiant + ':=' -> ParseAssignment
              Identifiant + '(' ou sans -> ParseProcedureCall
              IF           -> ParseIf
              CASE         -> ParseCase
              LOOP         -> ParseLoop
              WHILE        -> ParseWhile
              FOR          -> ParseFor
              RETURN       -> ParseReturn
              RAISE        -> ParseRaise
              NULL         -> ParseNull
              EXIT         -> ParseExit
              BEGIN        -> ParseBeginBlock
              PRAGMA       -> ParsePragma
              GOTO         -> ParseGoto
              DECLARE      -> ParseDeclareBlock
            ParseSequenceOfStatements : boucle Until IsEndBoundary
            Resynchronisation sur erreur : SkipToSemi
            Gestion du point-virgule terminateur

  TODO 16 - PARSEUR : AFFECTATION ET APPELS DE PROCEDURE
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

  TODO 17 - PARSEUR : IF/ELSIF/ELSE ET CASE/WHEN/OTHERS (32 BITS)
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

  TODO 18 - PARSEUR : BOUCLES LOOP/WHILE/FOR ET EXIT (32 BITS)
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

  TODO 19 - PARSEUR : EXCEPTIONS RAISE ET HANDLERS
            Declarations : nom : EXCEPTION ;
            ParseRaise :
              RAISE [nom] ;
              JMP _ADAX_handler (ou sortie programme)
            ParseExceptionHandler :
              BEGIN ... EXCEPTION
                WHEN nom => stmts
                WHEN OTHERS => stmts
              END ;
              Generer _ADAL_try, _ADAX_handler
              Mecanisme simple par table de sauts
            Exceptions standard : CONSTRAINT_ERROR, PROGRAM_ERROR,
              STORAGE_ERROR, TASKING_ERROR (stubs)

  TODO 20 - PARSEUR : OPERATIONS SUR TABLEAUX (32 BITS)
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

  TODO 21 - PARSEUR : OPERATIONS SUR RECORDS (32 BITS)
            Acces champ : var.champ -> adresse base + offset_champ
            Calcul offset par sommation des tailles anterieures
              (alignement 4 octets)
            GenLoadField(sym_idx, field_idx) :
              LEA EAX, [base] / MOV EAX, [EAX+offset]
            GenStoreField(sym_idx, field_idx) :
              LEA EBX, [base] / MOV [EBX+offset], EAX
            Affectation agregat : (champ => val, ...) -> sequence init
            Records imbrique : var.champ.sous_champ (recursif)
            Attribut record : T'SIZE -> somme des tailles

  TODO 22 - STUBS ADA.TEXT_IO : SORTIE CONSOLE WIN32
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

  TODO 23 - GENERATION : EN-TETE ASSEMBLEUR 80386 ET SEGMENT .DATA
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

  TODO 24 - GENERATION : POINT D'ENTREE WIN32 ET HELPERS RUNTIME
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

  TODO 25 - GENERATION FINALE : LINKER PE, FICHIERS .OBJ ET EXEMPLES
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
{ PROCEDURE RUN (STUB - sera complete par les TODOs suivants)  }
{ ============================================================ }

Procedure Run;
Begin
  InitSymTable;
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
    WriteLn('ADACW32: TODO 05+ non encore implemente - table symboles OK');
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
