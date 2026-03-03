(* ============================================================================
  JOVIAL86.PAS - Compilateur JOVIAL 73 -> MASM 8086
  Version : 1.0    Date : 2026-03-03
  Auteur  : DEV-COOLS
  Langage : Turbo Pascal / Free Pascal (compatible)
  Cible   : MASM 8086, modele SMALL, convention near cdecl
  ============================================================================

  DESCRIPTION
  -----------
  JOVIAL86 est un compilateur mono-passe pour le sous-ensemble principal de
  JOVIAL 73 (Jules' Own Version of the International Algebraic Language),
  produisant directement du code assembleur MASM 8086.
  JOVIAL 73 est un langage de haut niveau derive d'ALGOL, utilise dans les
  systemes militaires et aerospatiaux.  Le modele memoire SMALL est cible :
  segment code <= 64 Ko, segment donnees <= 64 Ko.

  SOUS-ENSEMBLE JOVIAL 73 SUPPORTE
  ---------------------------------
  Types de donnees :
    ITEM name I n        : entier signe sur n bits  (8 ou 16 ou 32)
    ITEM name S n (...)  : statut (enumeration jusqu'a 16 valeurs)
    ITEM name B n        : champ de bits sur n bits (1 a 16)
    ITEM name F          : reel simple precision  (emulation logicielle 8086)
    TABLE name           : tableau ou agregat de champs ITEM imbriques
    COMPOOL name         : module de donnees partages (declarations globales)

  Expressions :
    Arithmetiques : + - * / ** (exposant entier)
    Relationnels  : EQ NEQ LSS LEQ GTR GEQ  (ou = /= < <= > >=)
    Logiques      : AND OR NOT XOR EQV
    Bit / champ   : acces par notation pointee TABLE.ITEM

  Instructions :
    Affectation       : var = expr
    Appel             : CALL name (args)
    Branchement       : GO TO label  /  GOTO label
    Sortie            : STOP
    Retour            : RETURN expr
    Entree            : INPUT (var [, var ...])
    Sortie            : OUTPUT (format, expr [, expr ...])

  Structures de controle :
    IF cond THEN stmt [ELSE stmt] END
    FOR var = start STEP step TO limit DO stmt END
    FOR var = start STEP step ST cond DO stmt END  (STEP UNTIL cond)
    WHILE cond DO stmt END
    DO stmt UNTIL cond

  Sous-programmes :
    PROCEDURE name [ (param, ...) ] ; bloc END
    FUNCTION name  [ (param, ...) ] type ; bloc END

  Compilation separee :
    MODULE name ; ... END MODULE
    COMPOOL exporte les declarations vers d'autres modules

  ARCHITECTURE DU COMPILATEUR
  ---------------------------
  Mono-passe avec resolution forward des etiquettes de branchement.
  Les corps de PROCEDURE et FUNCTION sont emis dans tmp_file pendant le
  parsing, puis fusionnes dans out_file apres le segment DATA.

  Segments generes (modele SMALL, MASM) :
    STACK  _STACK SEGMENT  PARA STACK 'STACK'  512 DUP(?)  _STACK ENDS
    DATA   _DATA  SEGMENT  WORD PUBLIC 'DATA'   ...         _DATA  ENDS
    CODE   _CODE  SEGMENT  WORD PUBLIC 'CODE'   ...         _CODE  ENDS
           END   START

  Convention d'appel near cdecl :
    Arguments empiles de droite a gauche.
    Valeur de retour dans AX (entier / statut / bit <= 16 bits),
    ou DX:AX (entier 32 bits / reel emule).
    L'appelant nettoie la pile apres CALL.

  ============================================================================
  PLAN DES 25 TODOS
  ============================================================================

  TODO 01 - TYPES DE BASE, CONSTANTES ET VARIABLES GLOBALES
  -----------------------------------------------------------
  Types Pascal internes du compilateur :
    TString  = String[128]   (noms, valeurs de tokens, etiquettes)
    TCharSet = Set of Char   (ensembles pour le lexer)

  Types de tokens JOVIAL 73 reconnus (TTokenKind) :
    TK_IDENT    : identifiant (nom d'ITEM, de TABLE, de procedure, ...)
    TK_INTEGER  : litteral entier decimal
    TK_REAL     : litteral reel (point decimal ou exposant E)
    TK_STRING   : chaine litterale delimitee par des apostrophes  ' ... '
    TK_KEYWORD  : mot-cle JOVIAL 73 reserve
    TK_OP       : operateur symbolique (+  -  *  /  **  =  /=  <  <=  >  >=)
    TK_PUNCT    : ponctuation  ( ) , ; . $ # @
    TK_EOL      : fin de ligne logique (JOVIAL 73 est sensible a la structure)
    TK_EOF      : fin de fichier source

  Record TToken :
    kind    : TTokenKind
    val     : TString         (representation brute du token)
    int_val : LongInt         (si TK_INTEGER : valeur entiere)
    real_val : Real           (si TK_REAL    : valeur reelle)
    line, col : Integer

  Types de donnees JOVIAL 73 (TItemType) :
    IT_INTEGER  : entier signe (ITEM x I n)
    IT_STATUS   : enumeration (ITEM x S n (val1, val2, ...))
    IT_BITS     : champ de bits (ITEM x B n)
    IT_REAL     : reel simple precision (ITEM x F)
    IT_TABLE    : agregat TABLE ou COMPOOL
    IT_PROC     : sous-programme sans valeur de retour
    IT_FUNC     : sous-programme avec valeur de retour
    IT_UNDEF    : type non encore resolu

  Portee des symboles (TScope) :
    SC_GLOBAL   : variable globale MODULE ou COMPOOL
    SC_LOCAL    : variable locale a une PROCEDURE / FUNCTION
    SC_PARAM    : parametre formel
    SC_CONST    : constante DEFINE ou valeur de STATUS

  Genre des entrees de table (TSymKind) :
    SK_ITEM     : variable scalaire (I / S / B / F)
    SK_TABLE    : agregat TABLE ou tableau uniforme
    SK_CONST    : constante nommee (DEFINE ou valeur STATUS)
    SK_PROC     : PROCEDURE
    SK_FUNC     : FUNCTION
    SK_LABEL    : etiquette de GOTO

  Record TSymbol :
    name       : TString       (nom JOVIAL tel que declare)
    kind       : TSymKind
    itype      : TItemType
    scope      : TScope
    bit_size   : Integer       (taille en bits : 8, 16, 32 pour I / 1..16 pour B)
    asm_label  : TString       (nom ASM correspondant : _JV_xxx)
    bp_offset  : Integer       (offset BP pour variable locale)
    is_array   : Boolean       (TABLE comme tableau uniforme)
    arr_count  : Integer       (nombre d'elements si is_array)
    enum_count : Integer       (nombre de valeurs si IT_STATUS)
    enum_vals  : Array[0..15] of TString  (noms des valeurs de statut)

  Record TProcRec (sous-programmes) :
    name         : TString
    asm_label    : TString     (ex : _JP_<module>_<nom>)
    return_itype : TItemType   (IT_UNDEF pour PROCEDURE)
    return_bits  : Integer
    param_count  : Integer
    params       : Array[1..MAX_PARAM] of TSymbol
    local_size   : Integer     (taille totale cadre local en octets)
    is_function  : Boolean

  Constantes de dimensionnement :
    MAX_SYM   = 512
    MAX_PROC  = 128
    MAX_CONST = 256
    MAX_PARAM = 16
    MAX_LABEL = 512

  Prefixes des labels ASM :
    JV_PFX  = '_JV_'    (variables et champs emis dans DATA)
    JP_PFX  = '_JP_'    (labels de PROCEDURE et FUNCTION)
    JL_PFX  = '_JL_'    (labels de controle de flot IF / FOR / WHILE / DO)
    JRT_PFX = '_JRT_'   (routines runtime : I/O, arithmetique, conversion)
    JK_PFX  = '_JK_'    (constantes de statut emises dans DATA)

  Variables globales du compilateur :
    sym_table   : ^TSymbolTable
    proc_table  : ^TProcTable
    src_file    : Text
    out_file, tmp_file : Text
    cur_out     : ^Text
    src_fname, out_fname, tmp_fname : TString
    sym_count, proc_count, label_count : Integer
    err_count, warn_count, instr_count : Integer
    lex_lineno, lex_colno : Integer
    cur_tok, peek_tok : TToken
    has_peek : Boolean
    cur_proc_idx : Integer
    module_name  : TString
    opt_verbose, opt_debug, opt_no_rt : Boolean
    scope_sp : Integer
    loop_depth : Integer
    break_stack, continue_stack : Array[1..32] of TString

  Constantes diverses :
    STACK_SIZE       = 512
    JOVIAL86_VERSION = '1.0'
    JOVIAL86_DATE    = '2026-03-03'

  TODO 02 - LEXER : RECONNAISSANCE DES TOKENS JOVIAL 73
  -------------------------------------------------------
  Le lexer fonctionne ligne par ligne : il lit src_file dans lex_line et
  avance caractere par caractere via lex_pos.

  JOVIAL 73 supporte deux styles de commentaires :
    $ texte $    (commentaire encadre par des signes dollar)
    % texte      (commentaire de fin de ligne, variante selon dialecte)

  Les identificateurs JOVIAL sont en majuscules par convention mais le
  compilateur accepte les minuscules et les normalise en majuscules.

  Predicats de caracteres :
    LexIsAlpha  LexIsDigit  LexIsAlNum  LexIsWS

  Gestion du flux de lecture :
    LexRefill        : lire la prochaine ligne dans lex_line
    LexCurChar       : retourner lex_line[lex_pos] ou #0 si fin
    LexPeekChar(n)   : anticiper n positions sans consommer
    LexAdvance       : avancer lex_pos
    LexSkipWS        : sauter espaces et tabulations
    LexSkipComment   : sauter un commentaire $ ... $
    LexSkipLineComment : sauter un commentaire % ... fin de ligne

  Mots-cles JOVIAL 73 reconnus (fonction LexIsKeyword) :
    Types / declarations :
      ITEM TABLE STATUS COMPOOL DEFINE MODULE BEGIN END
    Sous-programmes :
      PROCEDURE FUNCTION RETURN CALL
    Types de donnees :
      INTEGER REAL FLOAT BITS STATUS
    Controle :
      IF THEN ELSE FOR TO STEP ST DO WHILE UNTIL GOTO GO
    I/O :
      INPUT OUTPUT
    Divers :
      AND OR NOT XOR EQV TRUE FALSE STOP BY

  Lecteurs de tokens :
    LexReadIdent    : lire identifiant ou mot-cle (normalisation en majuscules)
    LexReadInteger  : lire entier decimal ou octal (JOVIAL 73 supporte O'nnnn')
    LexReadReal     : lire reel (dddd.dddd [E+/-nn])
    LexReadString   : lire chaine entre apostrophes  'texte'
                      La duplication '' represente une apostrophe litterale
    LexReadOp       : lire operateur : + - * / ** = /= < <= > >= , ; ( ) . :=
    LexMakeTok      : construire un TToken dans une variable Var

  API principale :
    LexInit(fname)   : ouvrir le source et lire le premier token
    LexClose         : fermer le fichier source
    LexNext          : avancer d'un token (Procedure, voir lex_cur_tok)
    LexPeek          : anticiper sans consommer (voir peek_tok / has_peek)
    LexExpect(val)   : consommer en verifiant la valeur ou signaler erreur
    LexExpectKind(k) : consommer en verifiant le kind

  TODO 03 - TABLES DES SYMBOLES, PROCEDURES ET CONSTANTES
  ---------------------------------------------------------
  Allocation :
    InitTables  : allouer dynamiquement sym_table et proc_table (New)
    FreeTables  : liberer (Dispose)

  Table des symboles (ITEMs, TABLEs, labels GOTO, DEFINE) :
    AddSym(name, kind, itype, scope) : Integer
    AddGlobalItem   : ITEM declare au niveau MODULE ou COMPOOL
    AddLocalItem    : ITEM declare dans un bloc de PROCEDURE (alias PROC) / FUNCTION (alias FUNC)
    AddParam        : parametre formel d'un sous-programme
    AddTableSym     : entree de TABLE (agregat ou tableau)
    AddLabel        : etiquette de GOTO
    FindSym(name)   : Integer  (cherche portee courante puis montante)
    FindGlobal(name): Integer  (force la recherche globale)

  Table des constantes (DEFINE et valeurs de STATUS) :
    AddConst(name, val_str, int_val) : Integer
    FindConst(name)                  : Integer
    EvalConst(name)                  : LongInt  (retourne la valeur entiere)

  Table des procedures / fonctions :
    AddProc(name, is_function, ret_type, ret_bits) : Integer
    FindProc(name)    : Integer
    SetProcLabel(pi)  : construire _JP_<module>_<name>

  Gestion de portee :
    ScopeEnter  ScopeLeave  (incrementer / decrementer scope_level)
    ClearLocalSymbols        (reinitialiser les symboles locaux apres END)

  Generateur de labels :
    NewLabel  : TString  (retourne '_JL_' + IntToStr(label_count++))

  Utilitaires generaux :
    IntToStr(n)         : LongInt -> TString  (sans Str() de FPC)
    StrToInt(s)         : TString -> LongInt
    AsmIdent(s)         : remplacer les caracteres non autorises en ASM
    StrUpper(s)         : TString majuscules
    StrLower(s)         : TString minuscules
    FileExtension(fn)   : extraire l'extension (ex : '.jov')
    ChangeExtension(fn, ext)

  Pile des labels de boucle :
    PushLoopLabels(lbl_break, lbl_cont)
    PopLoopLabels
    TopBreakLabel  TopContLabel

  TODO 04 - PRIMITIVES D'EMISSION ASSEMBLEUR
  -------------------------------------------
  cur_out pointe sur out_file ou tmp_file selon la phase en cours.

  Gestion des fichiers de sortie :
    InitOutput     : Rewrite(out_file) ; cur_out := @out_file
    OpenTmpFile    : Rewrite(tmp_file) ; (cur_out reste out_file)
    SwitchToTmp    : cur_out := @tmp_file
    SwitchToMain   : cur_out := @out_file
    MergeTmpToMain : copier tmp_file ligne a ligne -> out_file, effacer tmp
    CloseOutput    : Close(out_file)

  Primitives brutes :
    Emit(s)            : WriteLn(cur_out^, s)
    EmitBlank          : WriteLn(cur_out^)
    EmitComment(s)     : WriteLn(cur_out^, '; ', s)
    EmitSep            : EmitComment('-'*60)
    EmitLabel(lbl)     : WriteLn(cur_out^, lbl, ':')
    EmitLocalLabel(lbl): WriteLn(cur_out^, lbl, ':')  (lbl commence par @@)

  Emission d'instructions ASM (8 espaces d'indentation) :
    EmitI0(op)           : '        op'
    EmitI1(op, a)        : '        op  a'
    EmitI2(op, a, b)     : '        op  a, b'
    EmitI(op, a, b, cmt) : '        op  a, b  ; cmt'

  Emission de donnees (segment DATA) :
    EmitDB(lbl, v)  : 'lbl  DB  v'
    EmitDW(lbl, v)  : 'lbl  DW  v'
    EmitDD(lbl, v)  : 'lbl  DD  v'
    EmitDup(lbl, n, init, sz) : 'lbl  DBn  n DUP(init)'

  TODO 05 - STRUCTURE ASM : SEGMENTS STACK ET EN-TETE DATA
  ----------------------------------------------------------
  En-tete du fichier ASM :
    GenFileHeader    : bloc de commentaires (version, source, date, cible)
    GenModelDirectives : '.MODEL SMALL' + '.8086'
    GenStackSegment  : '_STACK SEGMENT PARA STACK ''STACK'''
                       '  DB  512 DUP (?)'
                       '_STACK ENDS'

  En-tete du segment de donnees :
    GenDataHeader    : '_DATA SEGMENT WORD PUBLIC ''DATA'''
    GenDataFooter    : '_DATA ENDS'

  Variables systeme emises au debut du segment DATA :
    GenSystemVarsData :
      _JV_OUTBUF    DB  256 DUP(0)    (buffer de sortie)
      _JV_INBUF     DB  128 DUP(0)    (buffer de lecture)
      _JV_INTBUF    DB  12  DUP(0)    (buffer conversion entier)
      _JV_CRLF      DB  0Dh, 0Ah, '$' (CRLF DOS)
      _JV_NULLSTR   DB  0             (chaine vide)
      _JV_TRUE      DB  'TRUE', 0
      _JV_FALSE     DB  'FALSE', 0

  TODO 06 - GENERATION DU SEGMENT DATA (CORPS : ITEMS ET TABLES)
  ---------------------------------------------------------------
  Emission des ITEMs globaux declares au niveau MODULE ou COMPOOL :
    GenOneItemData(i) : selon itype et bit_size :
      IT_INTEGER 8   -> DB  0
      IT_INTEGER 16  -> DW  0
      IT_INTEGER 32  -> DD  0
      IT_BITS n      -> DW  0  (avec un commentaire 'n bits')
      IT_STATUS n    -> DW  0  (valeur 0 = premier statut)
      IT_REAL        -> DD  0  (4 octets, reel emule)
    GenAllItemsData  : boucle sur sym_table, filtre SK_ITEM, SC_GLOBAL

  Emission des constantes de statut (valeurs nommees de STATUS) :
    GenStatusConsts(i) : pour chaque valeur de l'enumeration,
      emettre un EQU dans le DATA  _JK_<STATUS>_<VAL>  EQU  n

  Emission des TABLEs uniformes (tableaux d'ITEMs identiques) :
    GenTableData(i)  : '_JV_xxx  DB/DW/DD  N DUP(0)'

  Emission des TABLEs agregat (champs de types differents) :
    GenAggregatData(i) : emettre chaque champ membre comme un ITEM
                         avec un label derive : _JV_<table>_<membre>

  Emission des litteraux de chaines (syntaxe ' ... ') :
    GenOneStringLit(i)  : '_JK_xxx  DB  ''texte'', 0'
    GenAllStringLits    : boucle sur la table de litteraux

  GenDataSegment = GenDataHeader
                 + GenSystemVarsData
                 + GenAllItemsData
                 + GenAllStringLits
                 + GenDataFooter

  TODO 07 - PARSER : DECLARATIONS MODULE ET COMPOOL
  --------------------------------------------------
  ParseModule :
    'MODULE' ident ';' corps 'END' 'MODULE' ident
    Remplit module_name.
    Le corps contient des DEFINE, ITEM, TABLE, STATUS, COMPOOL,
    PROCEDURE, FUNCTION et le code du module principal.

  ParseCompool :
    'COMPOOL' ident ';' corps 'END' 'COMPOOL' ident
    Declare des ITEMs, TABLEs, STATUSes partages entre modules.
    En JOVIAL86 ces declarations sont traitees comme globales.
    Emet un commentaire dans le DATA pour marquer l'origine.

  ParseDefine :
    'DEFINE' ident '=' expr ';'
    Evaluation immediate si l'expression est constante.
    Enregistrement dans la table des constantes (SK_CONST).
    Substitution textuelle dans le lexer pour les occurrences suivantes.

  ParseItemDecl(scope) :
    'ITEM' ident type_spec [initial_value] ';'
    type_spec :
      'I' bit_size                         -> IT_INTEGER
      'S' bit_size '(' val1, val2, ... ')' -> IT_STATUS
      'B' bit_size                         -> IT_BITS
      'F'                                  -> IT_REAL
    initial_value : '=' const_expr

  ParseTableDecl :
    'TABLE' ident ['(' count ')'] ';' item_decls 'END'
    Si '(count)' present : tableau uniforme de ITEMs identiques.
    Sinon : agregat de champs ITEM heterogenes.

  ParseStatusDecl :
    'STATUS' ident '(' val1 [',' val2 ...] ')'
    Enregistrer les valeurs dans le tableau enum_vals du symbole.
    Assigner les valeurs entieres 0, 1, 2, ...

  ParseConstExpr : evaluer une expression constante au compile-time
    (entier, somme, difference, produit, valeur DEFINE)

  TODO 08 - PARSER : PROCEDURE ET FUNCTION
  -----------------------------------------
  ParseProcedureDecl :
    'PROCEDURE' ident ['(' ParamList ')'] ';'
    bloc
    'END'
    Enregistrer dans proc_table (is_function = False).
    Remettre SwitchToTmp pour emettre le code dans tmp_file.
    Generer le prologue et l'epilogue de la procedure.

  ParseFunctionDecl :
    'FUNCTION' ident ['(' ParamList ')'] type_spec ';'
    bloc
    'END'
    type_spec indique le type de retour (I n / S n / B n / F).
    Enregistrer dans proc_table (is_function = True, return_itype).

  ParseParamList :
    Liste de declarations : type_spec ident (',' type_spec ident)*
    Chaque parametre est empile par l'appelant (passage par valeur).
    Enregistrer dans proc_table^[pi].params et dans sym_table (SC_PARAM).
    Calculer bp_offset : BP+4, BP+6, BP+8, ...

  ParseLocalDecls :
    Dans le corps d'une procedure : zero ou plusieurs 'ITEM' locaux.
    Calculer bp_offset negatif : BP-2, BP-4, ... (variables locales).
    Allouer la pile : 'SUB SP, N' dans le prologue.

  Prologue / epilogue :
    GenProcPrologue(pi) :
      label de la procedure
      PUSH BP  /  MOV BP, SP
      SUB SP, local_size  (si local_size > 0)
      PUSH SI  PUSH DI  PUSH BX  (registres preserver)
    GenProcEpilogue(pi) :
      POP BX  POP DI  POP SI
      MOV SP, BP  POP BP
      RET  (near)

  TODO 09 - PARSER : EXPRESSIONS JOVIAL 73
  -----------------------------------------
  Hierarchie de precedence (du plus faible au plus fort) :
    ParseExpr        : point d'entree (operateurs logiques faibles)
    ParseExprLogOr   : OR  EQV
    ParseExprLogAnd  : AND
    ParseExprLogNot  : NOT
    ParseExprRel     : EQ  NEQ  LSS  LEQ  GTR  GEQ
                       (= /= < <= > >=)
    ParseExprAdd     : + -
    ParseExprMul     : * /
    ParseExprPow     : ** (exposant entier uniquement)
    ParseExprUnary   : -  NOT  (prefixe)
    ParseExprPostfix : expr '.' membre  (acces champ de TABLE)
                       expr '(' idx ')' (acces element de TABLE tableau)
    ParseExprPrimary : litteral entier / reel / chaine / True / False
                       identifiant (ITEM, constante DEFINE, valeur STATUS)
                       '(' expr ')'
                       appel de FUNCTION : ident '(' args ')'

  Contexte de type des expressions :
    ExprType        : TItemType  (type de l'expression courante)
    ExprBits        : Integer    (taille en bits)
    Passer ces contextes par Var dans chaque ParseExprXxx

  Conversions implicites :
    entier n bits -> entier m bits (extension ou troncature)
    statut   -> entier (valeur de l'enumeration)
    bits     -> entier
    Pas de conversion implicite reel <-> entier (erreur semantique)

  Helpers :
    ParseArgList(pi)    : '(' [expr (',' expr)*] ')'
                          Verifier count et types vs proc_table^[pi]
    IsRelOp(t)          : EQ NEQ LSS LEQ GTR GEQ = /= < <= > >=
    IsAddOp(t)          : + -
    IsMulOp(t)          : * /
    IsLogOp(t)          : AND OR XOR EQV
    IsConstExpr(expr)   : vrai si totalement evaluable au compile-time

  TODO 10 - PARSER : INSTRUCTIONS SIMPLES
  -----------------------------------------
  ParseStatement : dispatcher principal qui reconnait via le token courant :
    - identifiant suivi de '='  -> affectation
    - identifiant suivi de '('  -> appel de PROCEDURE
    - 'CALL' ident '(' args ')' -> appel explicite (JOVIAL 73)
    - 'GOTO' label              -> branchement
    - 'GO' 'TO' label           -> branchement (forme longue)
    - 'STOP'                    -> fin de programme
    - 'RETURN' [expr]           -> retour de PROCEDURE / FUNCTION
    - 'IF' ...                  -> branchement conditionnel
    - 'FOR' ...                 -> boucle FOR
    - 'WHILE' ...               -> boucle WHILE
    - 'DO' ...                  -> boucle DO / UNTIL
    - 'BEGIN' ...               -> bloc d'instructions
    - 'INPUT' ...               -> lecture de variables
    - 'OUTPUT' ...              -> ecriture formatee
    - 'ITEM' ...                -> declaration locale

  ParseAssignment :
    ident ['(' idx ')'] ['.' membre] '=' expr ';'
    Types compatibles verifies, code GenStore* correspondant.

  ParseCallStmt :
    [CALL] ident '(' [args] ')' ';'
    Verifier que le symbole est SK_PROC (sinon erreur).
    Emettre GenCallProc.

  ParseGoto :
    GOTO ident ';'  ou  GO TO ident ';'
    Emettre 'JMP _JL_<label>'.
    Le label cible doit exister dans la table ou etre resolu plus tard.

  ParseStop :
    'STOP' ';'
    Emettre CALL _JRT_EXIT0.

  ParseReturn :
    'RETURN' [expr] ';'
    Si FUNCTION : evaluer expr -> AX (ou DX:AX), puis epilogue + RET.
    Si PROCEDURE : epilogue + RET directement.

  ParseBlock :
    'BEGIN' {stmt}* 'END'
    Gestion du niveau de portee (ScopeEnter / ScopeLeave).
    Les declarations ITEM locales sont autorisees au debut du bloc.

  TODO 11 - PARSER : STRUCTURES DE CONTROLE (IF, GOTO MULTI-CIBLE)
  ------------------------------------------------------------------
  ParseIf :
    'IF' cond 'THEN' stmt_list ['ELSE' stmt_list] 'END'
    Generer :
      evaluation de cond                  (result dans AX)
      TEST AX, AX  /  JZ  lbl_else
      code THEN
      JMP  lbl_end
    lbl_else:
      code ELSE (si present)
    lbl_end:

  ParseGotoTarget :
    Une etiquette JOVIAL est un identifiant suivi de ' :'  (deux-points).
    Ex :  BOUCLE : BEGIN ... END
    Detecter dans ParseStatement si le token courant est IDENT suivi de ':'.
    Emettre le label ASM correspondant et l'enregistrer (SK_LABEL).

  ParseComputedGoto :
    'GOTO' '(' lbl1, lbl2, ... ')' ',' expr ';'
    Implements un branchement indexe sur une table de labels ASM.
    Emettre une table de mots en DATA + 'JMP WORD PTR [SI]' (ou similaire).

  TODO 12 - PARSER : BOUCLES FOR, WHILE, DO/UNTIL
  -------------------------------------------------
  ParseFor :
    'FOR' ident '=' start_expr 'STEP' step_expr 'TO' limit_expr 'DO' stmt 'END'
    Variante ST (STEP UNTIL) :
    'FOR' ident '=' start_expr 'STEP' step_expr 'ST' cond_expr 'DO' stmt 'END'
    Variante sans STEP (pas implicite de 1) :
    'FOR' ident '=' start_expr 'TO' limit_expr 'DO' stmt 'END'

    Code genere (forme TO, pas=1) :
      MOV [var], start
    lbl_top:
      CMP [var], limit
      JG  lbl_end           (si pas > 0)
      corps
    lbl_cont:
      ADD [var], step
      JMP lbl_top
    lbl_end:

    Gestion de PushLoopLabels / PopLoopLabels pour GOTO BREAK / CONTINUE
    (JOVIAL 73 n'a pas break/continue explicites mais des GOTO).

  ParseWhile :
    'WHILE' cond_expr 'DO' stmt 'END'
    Code genere :
    lbl_top:
      evaluation cond -> AX
      TEST AX, AX  /  JZ lbl_end
      corps
      JMP lbl_top
    lbl_end:

  ParseDoUntil :
    'DO' stmt 'UNTIL' cond_expr ';'
    Code genere :
    lbl_top:
      corps
      evaluation cond -> AX
      TEST AX, AX
      JZ lbl_top      (recommencer si condition fausse)

  TODO 13 - CODEGEN : ENTIERS (ITEM TYPE I)
  ------------------------------------------
  Toutes les valeurs intermediaires passent par le registre AX (16 bits)
  ou la paire DX:AX (32 bits).

  Chargement d'un ITEM entier dans AX (ou DX:AX) :
    GenLoadItemInt(i) :
      global 16 bits : MOV AX, [_JV_xxx]
      global 8 bits  : MOV AL, [_JV_xxx] / CBW
      global 32 bits : MOV AX, [_JV_xxx] / MOV DX, [_JV_xxx+2]
      local  16 bits : MOV AX, [BP-n]
      param  16 bits : MOV AX, [BP+n]

  Stockage dans un ITEM depuis AX (ou DX:AX) :
    GenStoreItemInt(i) :
      global 16 bits : MOV [_JV_xxx], AX
      global 8 bits  : MOV [_JV_xxx], AL
      global 32 bits : MOV [_JV_xxx], AX / MOV [_JV_xxx+2], DX
      local  16 bits : MOV [BP-n], AX

  Chargement d'un entier immediat :
    GenLoadImm(n, bits) :
      si n dans [-128..127] : MOV AX, n
      sinon                  : MOV AX, n  (MASM gere l'extension de signe)
      si 32 bits             : MOV DX, highword(n)

  Operations arithmetiques entier 16 bits :
    GenIntAdd  : POP BX  /  ADD AX, BX  (operande droite dans BX)
    GenIntSub  : POP BX  /  SUB AX, BX
    GenIntMul  : appel _JRT_IMUL (utilise IMUL DX:AX)
    GenIntDiv  : appel _JRT_IDIV (CWD puis IDIV BX)
    GenIntMod  : appel _JRT_IMOD (DX apres IDIV)
    GenIntNeg  : NEG AX

  Comparaisons entieres (resultat booleeen 0/1 dans AX) :
    GenIntCmpEQ  GenIntCmpNEQ  GenIntCmpLSS
    GenIntCmpLEQ GenIntCmpGTR  GenIntCmpGEQ
    CMP AX, BX + SETcc AL + MOVZX AX, AL  (ou sequence CMP/Jcc classique)

  Puissance entiere ( ** ) :
    GenIntPow : appel _JRT_IPOW (boucle de multiplication)

  TODO 14 - CODEGEN : STATUT ET BITS (ITEM TYPE S ET B)
  -------------------------------------------------------
  Un ITEM S (statut / enumeration) est stocke comme un entier 16 bits.
  Un ITEM B (champ de bits) est stocke comme un entier 16 bits sans signe.

  Chargement / stockage :
    GenLoadStatus(i)   : idem GenLoadItemInt 16 bits
    GenStoreStatus(i)  : idem GenStoreItemInt 16 bits
    GenLoadBits(i)     : MOV AX, [_JV_xxx]  +  AND AX, mask_n_bits
    GenStoreBits(i)    : AND AX, mask  /  MOV [_JV_xxx], AX

  Comparaison de statut :
    GenStatusCmpEQ(str_val) :
      CMP AX, _JK_<STATUS>_<VAL>  /  JE / JNE

  Operations sur bits :
    GenBitAnd   : AND AX, BX
    GenBitOr    : OR  AX, BX
    GenBitXor   : XOR AX, BX
    GenBitNot   : NOT AX  +  AND AX, mask
    GenBitShift : appel _JRT_SHIFT (SHL / SHR selon signe du decalage)

  Generation des constantes de statut dans le DATA :
    GenStatusEqu(enum_idx) :
      Pour chaque valeur k : '_JK_<STATUS>_<VAL>  EQU  k'

  TODO 15 - CODEGEN : REELS (ITEM TYPE F - EMULATION LOGICIELLE)
  ---------------------------------------------------------------
  JOVIAL 73 specifie des reels simple precision (32 bits).
  Le 8086 de base ne possede pas de FPU -> emulation logicielle.
  Les reels sont stockes en virgule flottante IEEE 754 32 bits dans
  deux mots consecutifs (low word / high word).

  Convention de passage :
    Valeur dans DX:AX (DX = mot de poids fort, AX = mot de poids faible).

  Chargement / stockage :
    GenLoadReal(i)  : MOV AX, [_JV_xxx] / MOV DX, [_JV_xxx+2]
    GenStoreReal(i) : MOV [_JV_xxx], AX / MOV [_JV_xxx+2], DX

  Litteraux reels :
    GenLoadRealLit(s) : convertir la chaine 's' en bits IEEE 754 32 bits
                        au compile-time, emettre deux DW imm dans DATA
                        puis charger l'adresse.

  Operations (chaque operation appelle une routine runtime dans _JRT_) :
    GenRealAdd  -> CALL _JRT_FADD
    GenRealSub  -> CALL _JRT_FSUB
    GenRealMul  -> CALL _JRT_FMUL
    GenRealDiv  -> CALL _JRT_FDIV
    GenRealNeg  -> CALL _JRT_FNEG
    GenRealPow  -> CALL _JRT_FPOW  (exposant entier : DX:AX = base, CX = exp)

  Comparaisons :
    GenRealCmp(op) -> CALL _JRT_FCMP  (resultat 0/1 dans AX)

  Conversions :
    GenInt2Real -> CALL _JRT_I2F  (AX -> DX:AX float)
    GenReal2Int -> CALL _JRT_F2I  (DX:AX float -> AX entier tronque)

  TODO 16 - CODEGEN : TABLE (TABLEAUX ET AGREGATS)
  -------------------------------------------------
  Acces a un element de TABLE tableau uniforme :
    GenTableElemLoad(ti, index_reg) :
      calc adresse = base + index * element_size
      MOV BX, [index_reg]
      si 1 octet  : ADD BX, BX [?] + MOV AL, [_JV_xxx + BX] / CBW
      si 2 octets : SHL BX, 1 / MOV AX, [_JV_xxx + BX]
      si 4 octets : SHL BX, 2 / MOV AX, [_JV_xxx + BX] + MOV DX, [_JV_xxx+BX+2]
    GenTableElemStore(ti, index_reg) : symetrique

  Verification de borne (optionnelle, desactivee par -ns) :
    GenBoundsCheck(ti) :
      CMP BX, arr_count
      JAE _JRT_ERRBOUND   (near call vers handler)

  Acces a un champ d'agregat TABLE :
    GenFieldLoad(ti, fi)  : charger le sous-item _JV_<TABLE>_<FIELD>
    GenFieldStore(ti, fi) : stocker le sous-item

  Initialisation d'une TABLE a zero :
    GenTableClear(ti) :
      MOV CX, (arr_count * elem_size) / 2
      MOV DI, OFFSET _JV_xxx
      XOR AX, AX
      REP STOSW

  TODO 17 - CODEGEN : APPELS DE PROCEDURE ET FUNCTION
  ----------------------------------------------------
  Passage des arguments (right-to-left, caller cleans) :
    GenPushArg(itype, bits) :
      entier 16 bits : PUSH AX
      entier 32 bits : PUSH DX  /  PUSH AX
      reel           : PUSH DX  /  PUSH AX
      statut / bits  : PUSH AX

  Appel d'une PROCEDURE :
    GenCallProc(pi) :
      emettre les PUSHes des arguments (apres evaluation de droite a gauche)
      CALL _JP_<module>_<name>
      ADD  SP, n * 2  (nettoyer la pile : n = nb mots empiles)

  Appel d'une FUNCTION :
    GenCallFunc(pi) :
      idem GenCallProc + resultat dans AX (ou DX:AX)

  Appel recursif :
    GenRecursiveCall(pi) : cas special : CALL sur le label de soi-meme

  Prologue / epilogue (voir aussi TODO 08) :
    GenProcPrologue(pi)
    GenProcEpilogue(pi)

  Gestion des parametres par valeur :
    Les ITEMs de type S, B, I 16 bits passent en un mot (PUSH AX).
    Les ITEMs 32 bits et reels passent en deux mots (PUSH DX  PUSH AX).
    Aucun passage par reference dans ce sous-ensemble.

  TODO 18 - CODEGEN : INPUT ET OUTPUT
  -------------------------------------
  Instruction OUTPUT de JOVIAL 73 :
    Syntaxe : OUTPUT (format_id, expr1 [, expr2, ...]) ';'
    format_id est soit une chaine litterale, soit un DEFINE chaine.
    Le format supporte les substitutions :
      $D   -> afficher un entier decimal
      $F   -> afficher un reel (emule)
      $S   -> afficher un statut (son nom textuel)
      $B   -> afficher un champ de bits en hexadecimal
      $$   -> signe dollar litteral

    GenOutput :
      Pour chaque segment fixe du format : CALL _JRT_WRITESTR
      Pour chaque $D  : CALL _JRT_WRITEINT
      Pour chaque $F  : CALL _JRT_WRITEFLOAT
      Pour chaque $S  : CALL _JRT_WRITESTATUS (affiche le nom du statut)
      En fin de format : CALL _JRT_WRITECRLF

  Instruction INPUT de JOVIAL 73 :
    Syntaxe : INPUT (var1 [, var2, ...]) ';'
    Lecture d'un mot par variable depuis stdin DOS.

    GenInput :
      Pour chaque variable de type I : CALL _JRT_READINT -> MOV [_JV_xxx], AX
      Pour chaque variable de type F : CALL _JRT_READFLOAT -> paire DX:AX
      Pour chaque variable de type S : CALL _JRT_READSTATUS -> AX

  TODO 19 - RUNTIME ARITHMETIQUE 8086
  -------------------------------------
  Les routines runtime sont emises apres le code utilisateur dans _CODE.
  Elles respectent la convention near cdecl (arguments sur pile, AX retour).

  Routines entier 16 bits :
    _JRT_IMUL   : [SP+4] * [SP+2] -> DX:AX  (preserv. registres)
    _JRT_IDIV   : [SP+4] / [SP+2] -> AX quotient  DX reste
    _JRT_IMOD   : [SP+4] % [SP+2] -> AX reste
    _JRT_INEG   : NEG AX
    _JRT_IABS   : TEST AX,AX / JNS +2 / NEG AX
    _JRT_IPOW   : boucle IMUL CX fois  (AX=base, CX=exp)  -> DX:AX

  Routines entier 32 bits :
    _JRT_LMUL   _JRT_LDIV   _JRT_LMOD  (DX:AX)

  Routines reelles (virgule flottante IEEE 754 emulation) :
    _JRT_FADD   _JRT_FSUB   _JRT_FMUL  _JRT_FDIV
    _JRT_FNEG   _JRT_FABS   _JRT_FPOW  _JRT_FCMP
    _JRT_I2F    _JRT_F2I
    _JRT_FSTR   : convertir DX:AX float -> chaine ASCII dans _JV_OUTBUF

  Gestion d'erreur :
    _JRT_ERRBOUND : afficher "ERREUR : debordement de tableau"  + STOP
    _JRT_ERRDIV0  : afficher "ERREUR : division par zero"       + STOP
    _JRT_ERRSTACK : afficher "ERREUR : debordement de pile"     + STOP

  Conversion entier <-> chaine :
    _JRT_INT2STR  : AX -> chaine ASCII null-terminee dans _JV_INTBUF
    _JRT_STR2INT  : chaine @ DS:SI -> AX entier signe

  Terminaison :
    _JRT_EXIT0 : MOV AH, 4Ch / MOV AL, 0 / INT 21h

  TODO 20 - RUNTIME INPUT/OUTPUT 8086
  -------------------------------------
  Entrees / sorties par interruptions DOS (INT 21h) et BIOS.

  Sorties caractere et chaine :
    _JRT_WRITECHR   : MOV DL, AL / MOV AH, 02h / INT 21h
    _JRT_WRITESTR   : afficher chaine null-terminee @ DS:DX via INT 21h fct 09h
                      (la chaine doit etre terminee par '$' pour fct 09h,
                      ou utiliser fct 40h sur handle 1 avec la longueur)
    _JRT_WRITECRLF  : CALL _JRT_WRITESTR (@ _JV_CRLF)
    _JRT_WRITEINT   : convertir AX en ASCII (_JRT_INT2STR) puis WRITESTR
    _JRT_WRITEFLOAT : convertir DX:AX en ASCII (_JRT_FSTR) puis WRITESTR
    _JRT_WRITESTATUS: AX = indice de statut -> table de noms -> WRITESTR
    _JRT_WRITEHEX   : afficher AX en hexadecimal 4 chiffres

  Entrees :
    _JRT_READLINE   : lire une ligne depuis stdin dans _JV_INBUF (fct 0Ah)
    _JRT_READINT    : READLINE puis STR2INT -> AX
    _JRT_READFLOAT  : READLINE puis conversion ASCII -> DX:AX float
    _JRT_READSTATUS : READLINE puis recherche dans table de noms -> AX indice

  Message d'erreur generique :
    _JRT_ERRMSG(addr) : afficher la chaine d'erreur @ addr + CRLF + EXIT 1

  TODO 21 - STRUCTURE ASM : SEGMENT CODE (EN-TETE, CORPS, PIED)
  ---------------------------------------------------------------
  En-tete du segment CODE :
    GenCodeSegmentHeader :
      '_CODE SEGMENT WORD PUBLIC ''CODE'''
      'ASSUME CS:_CODE, DS:_DATA, SS:_STACK'

  Bloc de demarrage (STARTUP) :
    GenStartupBlock :
      'START:'
      'MOV AX, _DATA'
      'MOV DS, AX'
      'MOV AX, _STACK'
      'MOV SS, AX'
      'MOV SP, OFFSET _STACK + 512'
      'CALL _JP_<module>_<main_proc>'   (point d'entree principal)
      'CALL _JRT_EXIT0'

  Pied du segment CODE :
    GenCodeSegmentFooter :
      '_CODE ENDS'
      'END START'

  Detection du point d'entree :
    DetectEntryPoint :
      Chercher une PROCEDURE dont le nom correspond au module principal
      (convention : procedure qui porte le meme nom que le MODULE).
      Enregistrer son asm_label dans first_instr_lbl.

  GenFullAssemblyHeader : GenFileHeader + GenModelDirectives + GenStackSegment
  GenFullAssemblyFooter : GenCodeSegmentFooter

  TODO 22 - GESTION DES ERREURS ET RAPPORT
  ------------------------------------------
  Prefixe de localisation :
    ErrPrefix : TString  ('fichier(ligne,col) ')

  Niveaux de message :
    LogVerbose(s)  : afficher si opt_verbose (WriteLn)
    LogDebugAsm(s) : emettre un commentaire ASM si opt_debug
    WarnMsg(s)     : incrementer warn_count, afficher avertissement
    ErrorMsg(s)    : incrementer err_count, afficher erreur, continuer
    SemError(s)    : erreur semantique (type incompatible, symbole inconnu...)
    SynError(s)    : erreur syntaxique (token inattendu)
    LexError(s)    : erreur lexicale (caractere illegal, fin de fichier inattendue)
    FatalError(s)  : afficher l'erreur et appeler Halt(1) immediatement

  Limite d'erreurs :
    CheckErrLimit  : si err_count > MAX_ERRORS (ex: 30) -> FatalError

  Rapport final :
    PrintSummary   : afficher
      'Compilation terminee.'
      'Erreurs   : err_count'
      'Avertissements : warn_count'
      'Symboles  : sym_count'
      'Procedures: proc_count'
      'Instructions analysees : instr_count'
      'Fichier ASM : out_fname'

  Assertion finale :
    AssertNoErrors : si err_count > 0 -> FatalError (n erreur(s) detectee(s))

  TODO 23 - INTERFACE LIGNE DE COMMANDE
  ---------------------------------------
  Utilitaires :
    StrUpper  StrLower  FileExtension  ChangeExtension

  Banniere :
    PrintBanner : 'JOVIAL86 v1.0 - compilateur JOVIAL 73 -> MASM 8086'

  Aide :
    PrintHelp :
      Usage : JOVIAL86 <source.jov> [<sortie.asm>] [options]
      Options :
        -v      Mode verbeux (statistiques apres compilation)
        -d      Mode debug   (commentaires supplementaires dans l'ASM)
        -ns     Ne pas emettre le runtime inline
        -nbc    Desactiver les verifications de borne de TABLE
        -h      Afficher cette aide

  Parsing des arguments :
    ParseCommandLine : Boolean
      Remplir src_fname, out_fname, tmp_fname
      Remplir opt_verbose, opt_debug, opt_no_rt
      Verifier extension '.jov' du fichier source
      Deduire out_fname (.asm) et tmp_fname (.tmp) si non specifies
      Retourner False si erreur ou -h demande

  Rapport final :
    PrintFinalReport : appeler PrintSummary si opt_verbose

  TODO 24 - ORCHESTRATEUR DE COMPILATION
  ----------------------------------------
  Procedure Compile :
    1. InitOutput       -> ouvrir out_file
    2. OpenTmpFile      -> ouvrir tmp_file (CODE des procedures)
    3. GenFullAssemblyHeader -> .MODEL .STACK
    4. GenDataHeader    -> debut segment _DATA
    5. GenSystemVarsData
    6. LexInit(src_fname)
    7. ParseModule      -> parse MODULE complet :
                           - DEFINE, ITEM, TABLE, STATUS globaux -> DATA
                           - PROCEDURE / FUNCTION -> CODE dans tmp
                           - DetectEntryPoint
    8. LexClose
    9. GenAllItemsData  -> ITEMs globaux dans DATA
   10. GenAllStringLits -> litteraux chaines dans DATA
   11. GenDataFooter    -> _DATA ENDS
   12. SwitchToMain
   13. GenCodeSegmentHeader -> .CODE + ASSUME
   14. GenStartupBlock  -> START: init segments + CALL main
   15. MergeTmpToMain   -> fusionner le CODE tmp dans out_file
   16. Si Not opt_no_rt :
         GenRtArithmetic
         GenRtIO
   17. GenCodeSegmentFooter -> _CODE ENDS + END START
   18. CloseOutput
   19. AssertNoErrors
   20. PrintFinalReport

  Programme principal :
    InitTables
    PrintBanner
    Si Not ParseCommandLine -> FreeTables + Halt(0)
    Compile
    FreeTables
    Si err_count > 0 -> Halt(1)

  TODO 25 - INTEGRATION, TESTS ET VALIDATION
  --------------------------------------------
  Creer 10 programmes de test JOVIAL 73 progressifs :

  test01_hello.jov   :
    MODULE HELLO;
      ITEM MSG S 16 ('BONJOUR');
      PROCEDURE HELLO;
        BEGIN
          OUTPUT ('BONJOUR MONDE$D', 0);
        END
    END HELLO

  test02_items.jov   : ITEM TYPE I (8 / 16 / 32 bits), affectations, OUTPUT $D

  test03_arith.jov   : +  -  *  /  **  expressions mixtes entiers

  test04_status.jov  : STATUS enumeration, comparaisons EQ / NEQ / LSS

  test05_bits.jov    : ITEM TYPE B, AND / OR / XOR / NOT / SHIFT

  test06_cond.jov    : IF / THEN / ELSE / END, conditions complexes

  test07_boucles.jov : FOR / TO / STEP, WHILE / DO, DO / UNTIL,
                       GOTO et etiquette, boucle imbrique

  test08_table.jov   : TABLE uniforme (tableau), acces par indice,
                       TABLE agregat (champs), verification de borne

  test09_procs.jov   : PROCEDURE avec parametres, FUNCTION avec retour,
                       appels imbriques, recursivite (factorielle)

  test10_reels.jov   : ITEM TYPE F, +  -  *  /  **,  comparaisons,
                       INPUT / OUTPUT $F, conversion I<->F

  Valider chaque test :
    - 0 erreur de compilation JOVIAL86 -> ASM genere
    - Labels coherents, conventions d'appel respectees
    - Pas de regression sur les tests precedents
  Mesurer :
    - Nombre de symboles / procedures / litteraux
    - Taille du fichier ASM genere

  ============================================================================ *)

Program JOVIAL86;

{ ============================================================================
  TODO 01 - TYPES DE BASE, CONSTANTES ET VARIABLES GLOBALES
  ============================================================================ }

{ --------------------------------------------------------------------------
  Types de base
  -------------------------------------------------------------------------- }
Type
  TString  = String[128];
  TCharSet = Set Of Char;

{ --------------------------------------------------------------------------
  Types de tokens JOVIAL 73
  -------------------------------------------------------------------------- }
  TTokenKind = (
    TK_IDENT,     { identifiant ou mot-cle non encore classe }
    TK_INTEGER,   { litteral entier decimal ou octal O'...' }
    TK_REAL,      { litteral reel avec point decimal ou exposant E }
    TK_STRING,    { chaine litterale delimitee par apostrophes '...' }
    TK_KEYWORD,   { mot-cle JOVIAL 73 reserve }
    TK_OP,        { operateur : + - * / ** = /= < <= > >= }
    TK_PUNCT,     { ponctuation : ( ) , ; . $ # @ }
    TK_EOL,       { fin de ligne logique }
    TK_EOF        { fin de fichier source }
  );

{ --------------------------------------------------------------------------
  Token JOVIAL 73
  -------------------------------------------------------------------------- }
  TToken = Record
    kind     : TTokenKind;
    val      : TString;       { representation brute du token }
    int_val  : LongInt;       { valeur si TK_INTEGER }
    real_val : Real;          { valeur si TK_REAL }
    line     : Integer;
    col      : Integer;
  End;

{ --------------------------------------------------------------------------
  Types de donnees JOVIAL 73
  -------------------------------------------------------------------------- }
  TItemType = (
    IT_INTEGER,  { ITEM x I n  : entier signe sur n bits }
    IT_STATUS,   { ITEM x S n  : enumeration (statut) }
    IT_BITS,     { ITEM x B n  : champ de bits sur n bits }
    IT_REAL,     { ITEM x F    : reel simple precision (IEEE 754 emule) }
    IT_TABLE,    { TABLE       : agregat ou tableau uniforme }
    IT_PROC,     { PROCEDURE   : sous-programme sans retour }
    IT_FUNC,     { FUNCTION    : sous-programme avec retour }
    IT_UNDEF     { type non encore resolu }
  );

{ --------------------------------------------------------------------------
  Portee des symboles
  -------------------------------------------------------------------------- }
  TScope = (
    SC_GLOBAL,  { variable ou constante de niveau MODULE ou COMPOOL }
    SC_LOCAL,   { variable locale d'une PROCEDURE ou FUNCTION }
    SC_PARAM,   { parametre formel }
    SC_CONST    { constante DEFINE ou valeur de STATUS }
  );

{ --------------------------------------------------------------------------
  Genre des entrees de table des symboles
  -------------------------------------------------------------------------- }
  TSymKind = (
    SK_ITEM,    { variable scalaire : I / S / B / F }
    SK_TABLE,   { agregat TABLE ou tableau uniforme }
    SK_CONST,   { constante nommee : DEFINE ou valeur STATUS }
    SK_PROC,    { PROCEDURE }
    SK_FUNC,    { FUNCTION }
    SK_LABEL    { etiquette de GOTO }
  );

{ --------------------------------------------------------------------------
  Symbole JOVIAL 73
  -------------------------------------------------------------------------- }
  TEnumVal = String[32];    { nom d'une valeur de STATUS (court) }

  TSymbol = Record
    name       : TString;
    kind       : TSymKind;
    itype      : TItemType;
    scope      : TScope;
    bit_size   : Integer;            { 8, 16 ou 32 pour I ; 1..16 pour B }
    asm_label  : TString;            { ex : _JV_MONITEM }
    bp_offset  : Integer;            { offset BP (local < 0, param > 0) }
    is_array   : Boolean;            { True si TABLE tableau uniforme }
    arr_count  : Integer;            { nombre d'elements (is_array=True) }
    enum_count : Integer;            { nombre de valeurs (IT_STATUS) }
    enum_vals  : Array[0..15] Of TEnumVal;  { noms des valeurs de statut }
  End;

{ --------------------------------------------------------------------------
  Parametre d'un sous-programme (version allege pour eviter la recursion
  de type : TProcRec contient des params, chacun etant un TParamRec)
  -------------------------------------------------------------------------- }
  TParamRec = Record
    name      : TString;
    itype     : TItemType;
    bit_size  : Integer;
    bp_offset : Integer;    { offset positif par rapport a BP (appel) }
    is_array  : Boolean;
    arr_count : Integer;
  End;

{ --------------------------------------------------------------------------
  Entree de table des procedures et fonctions
  -------------------------------------------------------------------------- }
  TProcRec = Record
    name         : TString;
    asm_label    : TString;                    { ex : _JP_MODULE_NOM }
    return_itype : TItemType;                  { IT_UNDEF si PROCEDURE }
    return_bits  : Integer;
    param_count  : Integer;
    params       : Array[1..16] Of TParamRec;  { MAX_PARAM = 16 }
    local_size   : Integer;                    { octets du cadre local }
    is_function  : Boolean;
  End;

{ --------------------------------------------------------------------------
  Entree de table des constantes (DEFINE et valeurs STATUS)
  -------------------------------------------------------------------------- }
  TConstRec = Record
    name    : TString;
    val_str : TString;    { valeur textuelle originale }
    int_val : LongInt;    { valeur entiere evaluee }
  End;

{ --------------------------------------------------------------------------
  Types tableaux pour allocation dynamique
  -------------------------------------------------------------------------- }
Const
  MAX_SYM   = 512;
  MAX_PROC  = 128;
  MAX_CONST = 256;
  MAX_PARAM = 16;
  MAX_LABEL = 512;

Type
  TSymbolTable = Array[1..MAX_SYM]   Of TSymbol;
  TProcTable   = Array[1..MAX_PROC]  Of TProcRec;
  TConstTable  = Array[1..MAX_CONST] Of TConstRec;

{ --------------------------------------------------------------------------
  Constantes du compilateur
  -------------------------------------------------------------------------- }
Const
  STACK_SIZE       = 512;
  JOVIAL86_VERSION = '1.0';
  JOVIAL86_DATE    = '2026-03-03';

  { Prefixes des labels ASM }
  JV_PFX  = '_JV_';    { variables et champs dans DATA }
  JP_PFX  = '_JP_';    { labels de PROCEDURE et FUNCTION }
  JL_PFX  = '_JL_';    { labels de controle de flot }
  JRT_PFX = '_JRT_';   { routines runtime }
  JK_PFX  = '_JK_';    { constantes de statut dans DATA }

  MAX_ERRORS = 30;      { limite avant arret fatal }

{ --------------------------------------------------------------------------
  Variables globales du compilateur
  -------------------------------------------------------------------------- }
Var
  { Tables des symboles (allocation dynamique via New) }
  sym_table    : ^TSymbolTable;
  proc_table   : ^TProcTable;
  const_table  : ^TConstTable;

  { Fichiers source et sortie }
  src_file     : Text;
  out_file     : Text;
  tmp_file     : Text;
  cur_out      : ^Text;       { pointe sur out_file ou tmp_file }
  tmp_open     : Boolean;     { True si tmp_file est ouvert }

  { Noms de fichiers }
  src_fname    : TString;
  out_fname    : TString;
  tmp_fname    : TString;

  { Compteurs }
  sym_count    : Integer;
  proc_count   : Integer;
  const_count  : Integer;
  label_count  : Integer;
  err_count    : Integer;
  warn_count   : Integer;
  instr_count  : Integer;

  { Lexer }
  lex_line     : TString;     { ligne courante lue depuis src_file }
  lex_pos      : Integer;     { position dans lex_line }
  lex_lineno   : Integer;     { numero de ligne source (1-base) }
  lex_colno    : Integer;     { numero de colonne source (1-base) }
  cur_tok      : TToken;      { token courant }
  peek_tok     : TToken;      { token anticipe (LexPeek) }
  has_peek     : Boolean;     { peek_tok est-il valide ? }
  lex_eof      : Boolean;     { fin de fichier atteinte }

  { Etat du compilateur }
  cur_proc_idx    : Integer;  { index dans proc_table (-1 si niveau global) }
  scope_sp        : Integer;  { profondeur de portee courante }
  scope_level     : Integer;  { niveau de bloc courant }
  module_name     : TString;  { nom du MODULE en cours de compilation }
  cur_module_pfx  : TString;  { prefixe de module pour les labels ASM }
  entry_proc_lbl  : TString;  { label ASM du point d'entree (END START) }

  { Options de compilation }
  opt_verbose  : Boolean;     { -v : statistiques en fin de compilation }
  opt_debug    : Boolean;     { -d : commentaires supplementaires dans ASM }
  opt_no_rt    : Boolean;     { -ns : ne pas emettre le runtime inline }
  opt_no_bc    : Boolean;     { -nbc : desactiver les verifications de borne }

  { Pile des labels de boucle (pour GOTO BREAK / CONTINUE implicites) }
  loop_depth      : Integer;
  break_stack     : Array[1..32] Of TString;
  continue_stack  : Array[1..32] Of TString;

{ ============================================================================
  TODO 02 - LEXER : RECONNAISSANCE DES TOKENS JOVIAL 73
  ============================================================================ }

{ --------------------------------------------------------------------------
  Predicats de caracteres
  -------------------------------------------------------------------------- }
Function LexIsAlpha(c : Char) : Boolean;
Begin
  LexIsAlpha := ((c >= 'A') And (c <= 'Z')) Or
                ((c >= 'a') And (c <= 'z')) Or (c = '_');
End;

Function LexIsDigit(c : Char) : Boolean;
Begin
  LexIsDigit := (c >= '0') And (c <= '9');
End;

Function LexIsAlNum(c : Char) : Boolean;
Begin
  LexIsAlNum := LexIsAlpha(c) Or LexIsDigit(c);
End;

Function LexIsWS(c : Char) : Boolean;
Begin
  LexIsWS := (c = ' ') Or (c = #9) Or (c = #13) Or (c = #10);
End;

Function LexIsHexDigit(c : Char) : Boolean;
Begin
  LexIsHexDigit := LexIsDigit(c) Or
                   ((c >= 'A') And (c <= 'F')) Or
                   ((c >= 'a') And (c <= 'f'));
End;

{ --------------------------------------------------------------------------
  Normalisation : convertir un caractere en majuscule
  -------------------------------------------------------------------------- }
Function UpChr(c : Char) : Char;
Begin
  If (c >= 'a') And (c <= 'z') Then
    UpChr := Chr(Ord(c) - 32)
  Else
    UpChr := c;
End;

{ --------------------------------------------------------------------------
  LexRefill : lire la prochaine ligne du fichier source dans lex_line.
  Met lex_eof a True si la fin de fichier est atteinte.
  -------------------------------------------------------------------------- }
Procedure LexRefill;
Begin
  If Eof(src_file) Then
  Begin
    lex_eof  := True;
    lex_line := '';
    lex_pos  := 1;
  End
  Else
  Begin
    ReadLn(src_file, lex_line);
    Inc(lex_lineno);
    lex_pos := 1;
  End;
End;

{ --------------------------------------------------------------------------
  LexCurChar : retourner le caractere courant ou #0 si fin de tampon.
  -------------------------------------------------------------------------- }
Function LexCurChar : Char;
Begin
  If lex_eof Then
    LexCurChar := #0
  Else If lex_pos > Length(lex_line) Then
    LexCurChar := #0
  Else
    LexCurChar := lex_line[lex_pos];
End;

{ --------------------------------------------------------------------------
  LexPeekChar : regarder le caractere a l'avance de n positions (1 = suivant).
  -------------------------------------------------------------------------- }
Function LexPeekChar(n : Integer) : Char;
Var p : Integer;
Begin
  p := lex_pos + n;
  If lex_eof Or (p < 1) Or (p > Length(lex_line)) Then
    LexPeekChar := #0
  Else
    LexPeekChar := lex_line[p];
End;

{ --------------------------------------------------------------------------
  LexAdvance : avancer d'un caractere dans lex_line.
  Si la fin de ligne est atteinte, lire la ligne suivante.
  -------------------------------------------------------------------------- }
Procedure LexAdvance;
Begin
  If Not lex_eof Then
  Begin
    Inc(lex_pos);
    Inc(lex_colno);
    If lex_pos > Length(lex_line) + 1 Then
      LexRefill;
  End;
End;

{ --------------------------------------------------------------------------
  LexSkipComment : sauter un commentaire encadre par des signes dollar  $ ... $
  On est positionne sur le premier '$' au moment de l'appel.
  -------------------------------------------------------------------------- }
Procedure LexSkipComment;
Begin
  LexAdvance;  { sauter le '$' ouvrant }
  While (Not lex_eof) And (LexCurChar <> '$') Do
  Begin
    If LexCurChar = #0 Then
      LexRefill
    Else
      LexAdvance;
  End;
  If LexCurChar = '$' Then
    LexAdvance;  { sauter le '$' fermant }
End;

{ --------------------------------------------------------------------------
  LexSkipLineComment : sauter un commentaire de fin de ligne introduit par '%'
  -------------------------------------------------------------------------- }
Procedure LexSkipLineComment;
Begin
  { Avancer jusqu'a la fin de la ligne courante }
  lex_pos := Length(lex_line) + 1;
End;

{ --------------------------------------------------------------------------
  LexSkipWS : sauter les espaces, tabulations et commentaires.
  -------------------------------------------------------------------------- }
Procedure LexSkipWS;
Begin
  Repeat
    { Sauter les espaces sur la ligne courante }
    While (Not lex_eof) And (LexCurChar <> #0) And LexIsWS(LexCurChar) Do
      LexAdvance;

    { Fin de ligne -> ligne suivante }
    If (Not lex_eof) And (LexCurChar = #0) Then
    Begin
      LexRefill;
      Continue;
    End;

    { Commentaire dollar $ ... $ }
    If LexCurChar = '$' Then
    Begin
      LexSkipComment;
      Continue;
    End;

    { Commentaire de fin de ligne % ... }
    If LexCurChar = '%' Then
    Begin
      LexSkipLineComment;
      Continue;
    End;

    Break;
  Until False;
End;

{ --------------------------------------------------------------------------
  LexIsKeyword : verifier si une chaine (deja en majuscules) est un mot-cle.
  -------------------------------------------------------------------------- }
Function LexIsKeyword(Const s : TString) : Boolean;
Begin
  LexIsKeyword :=
    (s = 'ITEM')      Or (s = 'TABLE')     Or (s = 'STATUS')   Or
    (s = 'COMPOOL')   Or (s = 'DEFINE')    Or (s = 'MODULE')   Or
    (s = 'BEGIN')     Or (s = 'END')       Or
    (s = 'PROCEDURE') Or (s = 'FUNCTION')  Or (s = 'RETURN')   Or
    (s = 'CALL')      Or
    (s = 'INTEGER')   Or (s = 'REAL')      Or (s = 'FLOAT')    Or
    (s = 'BITS')      Or
    (s = 'IF')        Or (s = 'THEN')      Or (s = 'ELSE')     Or
    (s = 'FOR')       Or (s = 'TO')        Or (s = 'STEP')     Or
    (s = 'ST')        Or (s = 'DO')        Or (s = 'WHILE')    Or
    (s = 'UNTIL')     Or (s = 'GOTO')      Or (s = 'GO')       Or
    (s = 'BY')        Or
    (s = 'INPUT')     Or (s = 'OUTPUT')    Or
    (s = 'AND')       Or (s = 'OR')        Or (s = 'NOT')      Or
    (s = 'XOR')       Or (s = 'EQV')       Or
    (s = 'TRUE')      Or (s = 'FALSE')     Or (s = 'STOP')     Or
    (s = 'EQ')        Or (s = 'NEQ')       Or (s = 'LSS')      Or
    (s = 'LEQ')       Or (s = 'GTR')       Or (s = 'GEQ');
End;

{ --------------------------------------------------------------------------
  LexMakeTok : initialiser un TToken passe par Var.
  -------------------------------------------------------------------------- }
Procedure LexMakeTok(Var t : TToken; k : TTokenKind; Const v : TString);
Begin
  t.kind     := k;
  t.val      := v;
  t.int_val  := 0;
  t.real_val := 0.0;
  t.line     := lex_lineno;
  t.col      := lex_colno;
End;

{ --------------------------------------------------------------------------
  LexReadIdent : lire un identifiant ou un mot-cle.
  Les identificateurs sont normalises en majuscules.
  -------------------------------------------------------------------------- }
Procedure LexReadIdent(Var t : TToken);
Var s : TString;
    c : Char;
Begin
  s := '';
  While (Not lex_eof) And LexIsAlNum(LexCurChar) Do
  Begin
    c := UpChr(LexCurChar);
    If Length(s) < 128 Then
      s := s + c;
    LexAdvance;
  End;
  If LexIsKeyword(s) Then
    LexMakeTok(t, TK_KEYWORD, s)
  Else
    LexMakeTok(t, TK_IDENT, s);
End;

{ --------------------------------------------------------------------------
  LexReadInteger : lire un entier decimal ou octal JOVIAL (O'nnn').
  Formes reconnues :
    dddd         decimal
    O'oooo'      octal (prefixe lettre O majuscule)
  -------------------------------------------------------------------------- }
Procedure LexReadInteger(Var t : TToken);
Var s   : TString;
    n   : LongInt;
Begin
  s := '';
  n := 0;

  { Cas octal : O'oooo' ou o'oooo' }
  If (UpChr(LexCurChar) = 'O') And (LexPeekChar(1) = '''') Then
  Begin
    LexAdvance;  { sauter 'O' }
    LexAdvance;  { sauter le guillemet ouvrant }
    s := 'O''';
    While (Not lex_eof) And (LexCurChar >= '0') And (LexCurChar <= '7') Do
    Begin
      n := n * 8 + (Ord(LexCurChar) - Ord('0'));
      s := s + LexCurChar;
      LexAdvance;
    End;
    If LexCurChar = '''' Then
    Begin
      s := s + '''';
      LexAdvance;  { sauter le guillemet fermant }
    End;
  End
  Else
  Begin
    { Decimal standard }
    While (Not lex_eof) And LexIsDigit(LexCurChar) Do
    Begin
      n := n * 10 + (Ord(LexCurChar) - Ord('0'));
      s := s + LexCurChar;
      LexAdvance;
    End;
  End;

  LexMakeTok(t, TK_INTEGER, s);
  t.int_val := n;
End;

{ --------------------------------------------------------------------------
  LexReadReal : lire un littereal reel  dddd.dddd [E[+/-]nn].
  On est positionne sur le premier chiffre apres le point.
  Le contexte appelant a deja lu la partie entiere dans 'prefix'.
  -------------------------------------------------------------------------- }
Procedure LexReadReal(Var t : TToken; Const prefix : TString);
Var s   : TString;
    r   : Real;
    exp : Integer;
Begin
  s := prefix;

  { Partie decimale (apres le '.') }
  If LexCurChar = '.' Then
  Begin
    s := s + '.';
    LexAdvance;
    While (Not lex_eof) And LexIsDigit(LexCurChar) Do
    Begin
      s := s + LexCurChar;
      LexAdvance;
    End;
  End;

  { Exposant E[+/-]nn }
  If (UpChr(LexCurChar) = 'E') Then
  Begin
    s := s + 'E';
    LexAdvance;
    If (LexCurChar = '+') Or (LexCurChar = '-') Then
    Begin
      s := s + LexCurChar;
      LexAdvance;
    End;
    While (Not lex_eof) And LexIsDigit(LexCurChar) Do
    Begin
      s := s + LexCurChar;
      LexAdvance;
    End;
  End;

  LexMakeTok(t, TK_REAL, s);
  { Conversion approximative : utiliser Val de Pascal }
  Val(s, r, exp);
  If exp = 0 Then t.real_val := r;
End;

{ --------------------------------------------------------------------------
  LexReadString : lire une chaine entre apostrophes  'texte'.
  La sequence '' represente une apostrophe litterale dans la chaine.
  -------------------------------------------------------------------------- }
Procedure LexReadString(Var t : TToken);
Var s : TString;
Begin
  s := '';
  LexAdvance;  { sauter l apostrophe ouvrante }
  While Not lex_eof Do
  Begin
    If LexCurChar = #0 Then
    Begin
      { Fin de ligne dans une chaine : erreur, arreter }
      Break;
    End
    Else If LexCurChar = '''' Then
    Begin
      LexAdvance;  { sauter l apostrophe }
      If LexCurChar = '''' Then
      Begin
        { Apostrophe doublee = apostrophe literale }
        If Length(s) < 128 Then s := s + '''';
        LexAdvance;
      End
      Else
        Break;  { fin de chaine }
    End
    Else
    Begin
      If Length(s) < 128 Then s := s + LexCurChar;
      LexAdvance;
    End;
  End;
  LexMakeTok(t, TK_STRING, s);
End;

{ --------------------------------------------------------------------------
  LexReadOp : lire un operateur ou un signe de ponctuation.
  Operateurs reconnus : + - * / ** = /= < <= > >= , ; ( ) . :=
  -------------------------------------------------------------------------- }
Procedure LexReadOp(Var t : TToken);
Var s : TString;
    c : Char;
Begin
  c := LexCurChar;
  s := c;
  LexAdvance;

  Case c Of
    '*' : If LexCurChar = '*' Then
          Begin
            s := '**';
            LexAdvance;
          End;
    '/' : If LexCurChar = '=' Then
          Begin
            s := '/=';
            LexAdvance;
          End;
    '<' : If LexCurChar = '=' Then
          Begin
            s := '<=';
            LexAdvance;
          End;
    '>' : If LexCurChar = '=' Then
          Begin
            s := '>=';
            LexAdvance;
          End;
    ':' : If LexCurChar = '=' Then
          Begin
            s := ':=';
            LexAdvance;
          End;
  End;

  { Classer ponctuation vs operateur }
  If (s = ',') Or (s = ';') Or (s = '(') Or (s = ')') Or (s = '.') Then
    LexMakeTok(t, TK_PUNCT, s)
  Else
    LexMakeTok(t, TK_OP, s);
End;

{ --------------------------------------------------------------------------
  LexNext : produire le token suivant dans cur_tok.
  Si has_peek est vrai, consommer peek_tok sans relire le source.
  -------------------------------------------------------------------------- }
Procedure LexNext;
Var prefix : TString;
    n      : LongInt;
Begin
  { Consommer le token anticipe si disponible }
  If has_peek Then
  Begin
    cur_tok  := peek_tok;
    has_peek := False;
    Inc(instr_count);
    Exit;
  End;

  LexSkipWS;
  lex_colno := lex_pos;

  If lex_eof Or (LexCurChar = #0) Then
  Begin
    LexMakeTok(cur_tok, TK_EOF, '');
    Exit;
  End;

  { Identifiant ou mot-cle }
  If LexIsAlpha(LexCurChar) Then
  Begin
    { Cas special : prefixe octal O'...' }
    If (UpChr(LexCurChar) = 'O') And (LexPeekChar(1) = '''') Then
      LexReadInteger(cur_tok)
    Else
      LexReadIdent(cur_tok);
    Inc(instr_count);
    Exit;
  End;

  { Litteral entier }
  If LexIsDigit(LexCurChar) Then
  Begin
    { Accumuler la partie entiere, puis voir si '.' ou 'E' suit }
    prefix := '';
    n := 0;
    While (Not lex_eof) And LexIsDigit(LexCurChar) Do
    Begin
      n := n * 10 + Ord(LexCurChar) - Ord('0');
      prefix := prefix + LexCurChar;
      LexAdvance;
    End;
    If (LexCurChar = '.') Or (UpChr(LexCurChar) = 'E') Then
      LexReadReal(cur_tok, prefix)
    Else
    Begin
      LexMakeTok(cur_tok, TK_INTEGER, prefix);
      cur_tok.int_val := n;
    End;
    Inc(instr_count);
    Exit;
  End;

  { Litteral chaine }
  If LexCurChar = '''' Then
  Begin
    LexReadString(cur_tok);
    Inc(instr_count);
    Exit;
  End;

  { Operateur ou ponctuation }
  LexReadOp(cur_tok);
  Inc(instr_count);
End;

{ --------------------------------------------------------------------------
  LexPeek : anticiper le token suivant sans consommer cur_tok.
  -------------------------------------------------------------------------- }
Procedure LexPeek;
Var saved_tok : TToken;
Begin
  If Not has_peek Then
  Begin
    saved_tok := cur_tok;
    LexNext;
    peek_tok   := cur_tok;
    cur_tok    := saved_tok;
    has_peek   := True;
  End;
End;

{ --------------------------------------------------------------------------
  LexExpect : consommer cur_tok en verifiant que sa valeur vaut 'val'.
  -------------------------------------------------------------------------- }
Procedure LexExpect(Const val : TString);
Begin
  If cur_tok.val <> val Then
    WriteLn('Erreur syntaxique ligne ', lex_lineno, ' col ', lex_colno,
            ' : attendu ''', val, ''' mais lu ''', cur_tok.val, '''');
  LexNext;
End;

{ --------------------------------------------------------------------------
  LexExpectKind : consommer cur_tok en verifiant son TTokenKind.
  -------------------------------------------------------------------------- }
Procedure LexExpectKind(k : TTokenKind);
Begin
  If cur_tok.kind <> k Then
    WriteLn('Erreur syntaxique ligne ', lex_lineno, ' col ', lex_colno,
            ' : type de token inattendu (lu : ''', cur_tok.val, ''')');
  LexNext;
End;

{ --------------------------------------------------------------------------
  LexInit : ouvrir le fichier source et lire le premier token.
  -------------------------------------------------------------------------- }
Procedure LexInit(Const fname : TString);
Begin
  Assign(src_file, fname);
  Reset(src_file);
  lex_line    := '';
  lex_pos     := 1;
  lex_lineno  := 0;
  lex_colno   := 1;
  lex_eof     := False;
  has_peek    := False;
  instr_count := 0;
  LexRefill;
  LexNext;  { charger le premier token dans cur_tok }
End;

{ --------------------------------------------------------------------------
  LexClose : fermer le fichier source.
  -------------------------------------------------------------------------- }
Procedure LexClose;
Begin
  If Not lex_eof Then
    Close(src_file);
End;

{ ============================================================================
  TODO 03 - TABLES DES SYMBOLES, PROCEDURES ET CONSTANTES
  ============================================================================ }

{ --------------------------------------------------------------------------
  Utilitaires generaux
  -------------------------------------------------------------------------- }
Function IntToStr(n : LongInt) : TString;
Var s : TString;
Begin
  Str(n, s);
  IntToStr := s;
End;

Function StrToInt(Const s : TString) : LongInt;
Var n : LongInt;
    e : Integer;
Begin
  Val(s, n, e);
  If e <> 0 Then n := 0;
  StrToInt := n;
End;

Function StrUpper(Const s : TString) : TString;
Var i   : Integer;
    res : TString;
Begin
  res := s;
  For i := 1 To Length(res) Do
    res[i] := UpChr(res[i]);
  StrUpper := res;
End;

Function StrLower(Const s : TString) : TString;
Var i   : Integer;
    res : TString;
    c   : Char;
Begin
  res := s;
  For i := 1 To Length(res) Do
  Begin
    c := res[i];
    If (c >= 'A') And (c <= 'Z') Then
      res[i] := Chr(Ord(c) + 32);
  End;
  StrLower := res;
End;

{ AsmIdent : remplacer les caracteres non autorises par '_' }
Function AsmIdent(Const s : TString) : TString;
Var i   : Integer;
    res : TString;
    c   : Char;
Begin
  res := '';
  For i := 1 To Length(s) Do
  Begin
    c := s[i];
    If LexIsAlNum(c) Or (c = '_') Then
      res := res + c
    Else
      res := res + '_';
  End;
  AsmIdent := res;
End;

Function FileExtension(Const fn : TString) : TString;
Var i : Integer;
Begin
  i := Length(fn);
  While (i > 0) And (fn[i] <> '.') And (fn[i] <> '\') And (fn[i] <> '/') Do
    Dec(i);
  If (i > 0) And (fn[i] = '.') Then
    FileExtension := Copy(fn, i, Length(fn) - i + 1)
  Else
    FileExtension := '';
End;

Function ChangeExtension(Const fn, ext : TString) : TString;
Var i : Integer;
Begin
  i := Length(fn);
  While (i > 0) And (fn[i] <> '.') And (fn[i] <> '\') And (fn[i] <> '/') Do
    Dec(i);
  If (i > 0) And (fn[i] = '.') Then
    ChangeExtension := Copy(fn, 1, i - 1) + ext
  Else
    ChangeExtension := fn + ext;
End;

{ --------------------------------------------------------------------------
  Gestion de portee : pile des bases de symboles locaux
  scope_sp = profondeur courante (0 = global)
  scope_base[k] = valeur de sym_count au moment de ScopeEnter niveau k
  -------------------------------------------------------------------------- }
Var
  scope_base : Array[0..32] Of Integer;

Procedure ScopeEnter;
Begin
  If scope_sp < 32 Then
  Begin
    Inc(scope_sp);
    scope_level := scope_sp;
    scope_base[scope_sp] := sym_count;
  End;
End;

Procedure ScopeLeave;
Begin
  If scope_sp > 0 Then
  Begin
    sym_count := scope_base[scope_sp];
    Dec(scope_sp);
    scope_level := scope_sp;
  End;
End;

{ ClearLocalSymbols : supprimer les symboles ajoutes depuis ScopeEnter
  (sans dechanger scope_sp - utile en fin de procedure avant FreeTables) }
Procedure ClearLocalSymbols;
Begin
  If scope_sp > 0 Then
    sym_count := scope_base[scope_sp];
End;

{ --------------------------------------------------------------------------
  InitTables / FreeTables
  -------------------------------------------------------------------------- }
Procedure InitTables;
Begin
  New(sym_table);
  New(proc_table);
  New(const_table);
  sym_count   := 0;
  proc_count  := 0;
  const_count := 0;
  label_count := 0;
  err_count   := 0;
  warn_count  := 0;
  instr_count := 0;
  scope_sp    := 0;
  scope_level := 0;
  loop_depth  := 0;
  cur_proc_idx    := -1;
  module_name     := '';
  cur_module_pfx  := '';
  entry_proc_lbl  := '';
End;

Procedure FreeTables;
Begin
  Dispose(sym_table);
  Dispose(proc_table);
  Dispose(const_table);
End;

{ --------------------------------------------------------------------------
  Table des symboles
  -------------------------------------------------------------------------- }
Function AddSym(Const name : TString; kind : TSymKind;
                itype : TItemType; scope : TScope) : Integer;
Var i : Integer;
Begin
  If sym_count >= MAX_SYM Then
  Begin
    WriteLn('Erreur fatale : table des symboles pleine (MAX_SYM=', MAX_SYM, ')');
    Halt(1);
  End;
  Inc(sym_count);
  i := sym_count;
  sym_table^[i].name       := StrUpper(name);
  sym_table^[i].kind       := kind;
  sym_table^[i].itype      := itype;
  sym_table^[i].scope      := scope;
  sym_table^[i].bit_size   := 16;
  sym_table^[i].asm_label  := '';
  sym_table^[i].bp_offset  := 0;
  sym_table^[i].is_array   := False;
  sym_table^[i].arr_count  := 0;
  sym_table^[i].enum_count := 0;
  AddSym := i;
End;

{ Ajouter un ITEM global (niveau MODULE / COMPOOL) }
Function AddGlobalItem(Const name : TString; itype : TItemType;
                       bits : Integer) : Integer;
Var i : Integer;
Begin
  i := AddSym(name, SK_ITEM, itype, SC_GLOBAL);
  sym_table^[i].bit_size  := bits;
  sym_table^[i].asm_label := JV_PFX + AsmIdent(StrUpper(name));
  AddGlobalItem := i;
End;

{ Ajouter un ITEM local (dans une PROCEDURE / FUNCTION) }
Function AddLocalItem(Const name : TString; itype : TItemType;
                      bits : Integer; bp_off : Integer) : Integer;
Var i : Integer;
Begin
  i := AddSym(name, SK_ITEM, itype, SC_LOCAL);
  sym_table^[i].bit_size  := bits;
  sym_table^[i].bp_offset := bp_off;
  sym_table^[i].asm_label := '';
  AddLocalItem := i;
End;

{ Ajouter un parametre formel }
Function AddParam(Const name : TString; itype : TItemType;
                  bits : Integer; bp_off : Integer) : Integer;
Var i : Integer;
Begin
  i := AddSym(name, SK_ITEM, itype, SC_PARAM);
  sym_table^[i].bit_size  := bits;
  sym_table^[i].bp_offset := bp_off;
  sym_table^[i].asm_label := '';
  AddParam := i;
End;

{ Ajouter une TABLE (agregat ou tableau uniforme) }
Function AddTableSym(Const name : TString; is_arr : Boolean;
                     count : Integer) : Integer;
Var i : Integer;
Begin
  i := AddSym(name, SK_TABLE, IT_TABLE, SC_GLOBAL);
  sym_table^[i].asm_label := JV_PFX + AsmIdent(StrUpper(name));
  sym_table^[i].is_array  := is_arr;
  sym_table^[i].arr_count := count;
  AddTableSym := i;
End;

{ Ajouter une etiquette de GOTO }
Function AddLabel(Const name : TString) : Integer;
Var i : Integer;
Begin
  i := AddSym(name, SK_LABEL, IT_UNDEF, SC_GLOBAL);
  sym_table^[i].asm_label := JL_PFX + AsmIdent(StrUpper(name));
  AddLabel := i;
End;

{ Rechercher un symbole (du plus recent au plus ancien) }
Function FindSym(Const name : TString) : Integer;
Var i    : Integer;
    uname: TString;
Begin
  uname := StrUpper(name);
  For i := sym_count DownTo 1 Do
    If sym_table^[i].name = uname Then
    Begin
      FindSym := i;
      Exit;
    End;
  FindSym := 0;
End;

{ Rechercher uniquement dans les symboles globaux }
Function FindGlobal(Const name : TString) : Integer;
Var i     : Integer;
    uname : TString;
Begin
  uname := StrUpper(name);
  For i := sym_count DownTo 1 Do
    If (sym_table^[i].name = uname) And
       (sym_table^[i].scope = SC_GLOBAL) Then
    Begin
      FindGlobal := i;
      Exit;
    End;
  FindGlobal := 0;
End;

{ --------------------------------------------------------------------------
  Table des constantes (DEFINE et valeurs STATUS)
  -------------------------------------------------------------------------- }
Function AddConst(Const name, val_str : TString; int_val : LongInt) : Integer;
Var i : Integer;
Begin
  If const_count >= MAX_CONST Then
  Begin
    WriteLn('Erreur fatale : table des constantes pleine (MAX_CONST=', MAX_CONST, ')');
    Halt(1);
  End;
  Inc(const_count);
  i := const_count;
  const_table^[i].name    := StrUpper(name);
  const_table^[i].val_str := val_str;
  const_table^[i].int_val := int_val;
  AddConst := i;
End;

Function FindConst(Const name : TString) : Integer;
Var i     : Integer;
    uname : TString;
Begin
  uname := StrUpper(name);
  For i := const_count DownTo 1 Do
    If const_table^[i].name = uname Then
    Begin
      FindConst := i;
      Exit;
    End;
  FindConst := 0;
End;

Function EvalConst(Const name : TString) : LongInt;
Var i : Integer;
Begin
  i := FindConst(name);
  If i > 0 Then
    EvalConst := const_table^[i].int_val
  Else
    EvalConst := 0;
End;

{ --------------------------------------------------------------------------
  Table des procedures et fonctions
  -------------------------------------------------------------------------- }
Function AddProc(Const name : TString; is_func : Boolean;
                 ret_type : TItemType; ret_bits : Integer) : Integer;
Var i : Integer;
Begin
  If proc_count >= MAX_PROC Then
  Begin
    WriteLn('Erreur fatale : table des procedures pleine (MAX_PROC=', MAX_PROC, ')');
    Halt(1);
  End;
  Inc(proc_count);
  i := proc_count;
  proc_table^[i].name         := StrUpper(name);
  proc_table^[i].asm_label    := '';
  proc_table^[i].return_itype := ret_type;
  proc_table^[i].return_bits  := ret_bits;
  proc_table^[i].param_count  := 0;
  proc_table^[i].local_size   := 0;
  proc_table^[i].is_function  := is_func;
  AddProc := i;
End;

Function FindProc(Const name : TString) : Integer;
Var i     : Integer;
    uname : TString;
Begin
  uname := StrUpper(name);
  For i := proc_count DownTo 1 Do
    If proc_table^[i].name = uname Then
    Begin
      FindProc := i;
      Exit;
    End;
  FindProc := 0;
End;

{ SetProcLabel : construire le label ASM  _JP_<module>_<nom> }
Procedure SetProcLabel(pi : Integer);
Var pfx : TString;
Begin
  If module_name <> '' Then
    pfx := JP_PFX + AsmIdent(StrUpper(module_name)) + '_'
  Else
    pfx := JP_PFX;
  proc_table^[pi].asm_label := pfx + AsmIdent(proc_table^[pi].name);
End;

{ --------------------------------------------------------------------------
  Generateur de labels uniques
  -------------------------------------------------------------------------- }
Function NewLabel : TString;
Begin
  Inc(label_count);
  NewLabel := JL_PFX + IntToStr(label_count);
End;

{ --------------------------------------------------------------------------
  Pile des labels de boucle  (break / continue implicites via GOTO)
  -------------------------------------------------------------------------- }
Procedure PushLoopLabels(Const lbl_break, lbl_cont : TString);
Begin
  If loop_depth < 32 Then
  Begin
    Inc(loop_depth);
    break_stack[loop_depth]    := lbl_break;
    continue_stack[loop_depth] := lbl_cont;
  End;
End;

Procedure PopLoopLabels;
Begin
  If loop_depth > 0 Then
    Dec(loop_depth);
End;

Function TopBreakLabel : TString;
Begin
  If loop_depth > 0 Then
    TopBreakLabel := break_stack[loop_depth]
  Else
    TopBreakLabel := '';
End;

Function TopContLabel : TString;
Begin
  If loop_depth > 0 Then
    TopContLabel := continue_stack[loop_depth]
  Else
    TopContLabel := '';
End;

{ ============================================================================
  TODO 04 - PRIMITIVES D'EMISSION ASSEMBLEUR
  ============================================================================ }

Const
  ASM_INDENT = '        ';   { 8 espaces d'indentation }
  SEP_LINE   = '; ------------------------------------------------------------';

{ --------------------------------------------------------------------------
  Gestion des fichiers de sortie
  -------------------------------------------------------------------------- }
Procedure InitOutput;
Begin
  Assign(out_file, out_fname);
  Rewrite(out_file);
  cur_out  := @out_file;
  tmp_open := False;
End;

Procedure OpenTmpFile;
Begin
  Assign(tmp_file, tmp_fname);
  Rewrite(tmp_file);
  tmp_open := True;
  { cur_out reste sur out_file : le DATA va dans out_file }
End;

Procedure SwitchToTmp;
Begin
  If tmp_open Then
    cur_out := @tmp_file;
End;

Procedure SwitchToMain;
Begin
  cur_out := @out_file;
End;

Procedure MergeTmpToMain;
Var line : String;
Begin
  If Not tmp_open Then Exit;
  { Refermer tmp_file pour pouvoir le lire }
  Close(tmp_file);
  tmp_open := False;
  { Rouvrir tmp_file en lecture }
  Assign(tmp_file, tmp_fname);
  Reset(tmp_file);
  { Copier ligne par ligne dans out_file }
  While Not Eof(tmp_file) Do
  Begin
    ReadLn(tmp_file, line);
    WriteLn(out_file, line);
  End;
  Close(tmp_file);
  { Supprimer le fichier temporaire }
  Assign(tmp_file, tmp_fname);
  Erase(tmp_file);
End;

Procedure CloseOutput;
Begin
  If tmp_open Then
  Begin
    Close(tmp_file);
    tmp_open := False;
  End;
  Close(out_file);
End;

{ --------------------------------------------------------------------------
  Primitives brutes d'emission dans cur_out
  -------------------------------------------------------------------------- }
Procedure Emit(Const s : TString);
Begin
  WriteLn(cur_out^, s);
End;

Procedure EmitBlank;
Begin
  WriteLn(cur_out^);
End;

Procedure EmitComment(Const s : TString);
Begin
  WriteLn(cur_out^, '; ', s);
End;

Procedure EmitSep;
Begin
  WriteLn(cur_out^, SEP_LINE);
End;

Procedure EmitLabel(Const lbl : TString);
Begin
  WriteLn(cur_out^, lbl, ':');
End;

Procedure EmitLocalLabel(Const lbl : TString);
Begin
  WriteLn(cur_out^, lbl, ':');
End;

{ --------------------------------------------------------------------------
  Emission d'instructions ASM (8 espaces d'indentation)
  -------------------------------------------------------------------------- }
Procedure EmitI0(Const op : TString);
Begin
  WriteLn(cur_out^, ASM_INDENT, op);
End;

Procedure EmitI1(Const op, a : TString);
Begin
  WriteLn(cur_out^, ASM_INDENT, op, '  ', a);
End;

Procedure EmitI2(Const op, a, b : TString);
Begin
  WriteLn(cur_out^, ASM_INDENT, op, '  ', a, ', ', b);
End;

Procedure EmitI(Const op, a, b, cmt : TString);
Begin
  If cmt = '' Then
    WriteLn(cur_out^, ASM_INDENT, op, '  ', a, ', ', b)
  Else
    WriteLn(cur_out^, ASM_INDENT, op, '  ', a, ', ', b, '  ; ', cmt);
End;

{ --------------------------------------------------------------------------
  Emission de donnees dans le segment DATA
  Alignement : les labels sont paddes a 24 caracteres pour la lisibilite.
  -------------------------------------------------------------------------- }
Function PadLabel(Const lbl : TString) : TString;
Var s : TString;
    i : Integer;
Begin
  s := lbl;
  For i := Length(s) To 23 Do
    s := s + ' ';
  PadLabel := s;
End;

Procedure EmitDB(Const lbl, v : TString);
Begin
  WriteLn(cur_out^, PadLabel(lbl), 'DB      ', v);
End;

Procedure EmitDW(Const lbl, v : TString);
Begin
  WriteLn(cur_out^, PadLabel(lbl), 'DW      ', v);
End;

Procedure EmitDD(Const lbl, v : TString);
Begin
  WriteLn(cur_out^, PadLabel(lbl), 'DD      ', v);
End;

{ EmitDup : emettre  lbl  DB/DW/DD  n DUP(init)
  sz = 1 -> DB, sz = 2 -> DW, sz = 4 -> DD }
Procedure EmitDup(Const lbl : TString; n : Integer;
                  Const init : TString; sz : Integer);
Var dir : TString;
Begin
  Case sz Of
    1 : dir := 'DB';
    4 : dir := 'DD';
  Else
    dir := 'DW';
  End;
  WriteLn(cur_out^, PadLabel(lbl), dir, '      ',
          IntToStr(n), ' DUP(', init, ')');
End;

{ ============================================================================
  TODO 05 - STRUCTURE ASM : SEGMENTS STACK ET EN-TETE DATA
  ============================================================================ }

{ --------------------------------------------------------------------------
  GenFileHeader : bloc de commentaires d'en-tete du fichier ASM genere.
  -------------------------------------------------------------------------- }
Procedure GenFileHeader;
Begin
  EmitSep;
  EmitComment(' Fichier genere par JOVIAL86 v' + JOVIAL86_VERSION);
  EmitComment(' Date    : ' + JOVIAL86_DATE);
  EmitComment(' Source  : ' + src_fname);
  EmitComment(' Module  : ' + module_name);
  EmitComment(' Cible   : MASM 8086, modele SMALL');
  EmitSep;
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenModelDirectives : directive de modele memoire et de processeur cible.
  -------------------------------------------------------------------------- }
Procedure GenModelDirectives;
Begin
  Emit('        .MODEL  SMALL');
  Emit('        .8086');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenStackSegment : segment de pile  _STACK SEGMENT ... _STACK ENDS
  -------------------------------------------------------------------------- }
Procedure GenStackSegment;
Begin
  EmitComment(' ----- Segment STACK -----');
  Emit('_STACK          SEGMENT PARA STACK ''STACK''');
  Emit('                DB      ' + IntToStr(STACK_SIZE) + ' DUP (?)');
  Emit('_STACK          ENDS');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenDataHeader : ouvrir le segment de donnees _DATA.
  -------------------------------------------------------------------------- }
Procedure GenDataHeader;
Begin
  EmitComment(' ----- Segment DATA -----');
  Emit('_DATA           SEGMENT WORD PUBLIC ''DATA''');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenDataFooter : fermer le segment de donnees _DATA.
  -------------------------------------------------------------------------- }
Procedure GenDataFooter;
Begin
  EmitBlank;
  Emit('_DATA           ENDS');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenSystemVarsData : variables systeme JOVIAL86 dans le segment DATA.
  Emises au debut de _DATA avant les ITEMs utilisateur.
  -------------------------------------------------------------------------- }
Procedure GenSystemVarsData;
Begin
  EmitComment(' ----- Variables systeme JOVIAL86 -----');
  { Buffer de sortie (OUTPUT) }
  EmitDup('_JV_OUTBUF', 256, '0', 1);
  { Buffer d'entree (INPUT) }
  EmitDup('_JV_INBUF', 128, '0', 1);
  { Buffer de conversion entier -> chaine }
  EmitDup('_JV_INTBUF', 12, '0', 1);
  { Fin de ligne DOS CRLF + '$' pour INT 21h fonction 09h }
  EmitDB('_JV_CRLF', '0Dh, 0Ah, ''$''');
  { Chaine nulle }
  EmitDB('_JV_NULLSTR', '0');
  { Litteraux booleens pour OUTPUT $S sur STATUS BOOLEAN }
  EmitDB('_JV_TRUE', '''TRUE'', 0');
  EmitDB('_JV_FALSE', '''FALSE'', 0');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenFullAssemblyHeader : en-tete complet du fichier ASM.
  Appele en debut de compilation, avant GenDataHeader.
  -------------------------------------------------------------------------- }
Procedure GenFullAssemblyHeader;
Begin
  GenFileHeader;
  GenModelDirectives;
  GenStackSegment;
End;

{ ============================================================================
  TODO 06 - GENERATION DU SEGMENT DATA (CORPS : ITEMS ET TABLES)
  ============================================================================ }

{ --------------------------------------------------------------------------
  GenOneItemData : emet la definition ASM d'un ITEM global.
  Dispatche selon itype et bit_size.
  -------------------------------------------------------------------------- }
Procedure GenOneItemData(i : Integer);
Var
  lbl : TString;
Begin
  lbl := sym_table^[i].asm_label;
  Case sym_table^[i].itype Of
    IT_INTEGER :
      Begin
        Case sym_table^[i].bit_size Of
          8  : EmitDB(lbl, '0');
          32 : EmitDD(lbl, '0');
        Else
          EmitDW(lbl, '0');      { 16 bits par defaut }
        End;
      End;
    IT_BITS :
      EmitDW(lbl, '0      ; ' + IntToStr(sym_table^[i].bit_size) + ' bits');
    IT_STATUS :
      EmitDW(lbl, '0');        { valeur 0 = premier statut }
    IT_REAL :
      EmitDD(lbl, '0');        { 4 octets, reel emule }
  Else
    EmitDW(lbl, '0');
  End;
End;

{ --------------------------------------------------------------------------
  GenStatusConsts : emet les EQU pour les valeurs nommees d'un STATUS.
  Produit : _JK_<STATUS>_<VAL>  EQU  n
  -------------------------------------------------------------------------- }
Procedure GenStatusConsts(i : Integer);
Var
  k   : Integer;
  lbl : TString;
Begin
  For k := 0 To sym_table^[i].enum_count - 1 Do
  Begin
    lbl := JK_PFX + sym_table^[i].name
         + '_' + sym_table^[i].enum_vals[k];
    WriteLn(cur_out^, PadLabel(lbl), 'EQU     ', IntToStr(k));
  End;
End;

{ --------------------------------------------------------------------------
  GenTableData : emet une TABLE uniforme comme N DUP(0).
  -------------------------------------------------------------------------- }
Procedure GenTableData(i : Integer);
Var
  sz : Integer;
Begin
  Case sym_table^[i].bit_size Of
    8  : sz := 1;
    32 : sz := 4;
  Else
    sz := 2;
  End;
  EmitDup(sym_table^[i].asm_label, sym_table^[i].arr_count, '0', sz);
End;

{ --------------------------------------------------------------------------
  GenAggregatData : emet les champs d'une TABLE agregat.
  Les champs sont les SK_ITEM suivants dont asm_label commence par
  _JV_<TABLE>_ (convention adoptee a l'ajout des champs).
  -------------------------------------------------------------------------- }
Procedure GenAggregatData(i : Integer);
Var
  j    : Integer;
  base : TString;
Begin
  base := sym_table^[i].asm_label + '_';
  For j := i + 1 To sym_count Do
  Begin
    If sym_table^[j].kind <> SK_ITEM Then Break;
    If Copy(sym_table^[j].asm_label, 1, Length(base)) <> base Then Break;
    Case sym_table^[j].bit_size Of
      8  : EmitDB(sym_table^[j].asm_label, '0');
      32 : EmitDD(sym_table^[j].asm_label, '0');
    Else
      EmitDW(sym_table^[j].asm_label, '0');
    End;
  End;
End;

{ --------------------------------------------------------------------------
  GenAllItemsData : parcourt sym_table et emet tous les SK_ITEM
  et SK_TABLE de portee SC_GLOBAL.
  -------------------------------------------------------------------------- }
Procedure GenAllItemsData;
Var
  i : Integer;
Begin
  EmitComment('Variables ITEM et TABLE globales');
  For i := 1 To sym_count Do
  Begin
    If sym_table^[i].scope = SC_GLOBAL Then
    Begin
      If sym_table^[i].kind = SK_ITEM Then
      Begin
        GenOneItemData(i);
        If sym_table^[i].itype = IT_STATUS Then
          GenStatusConsts(i);
      End
      Else If sym_table^[i].kind = SK_TABLE Then
      Begin
        If sym_table^[i].is_array Then
          GenTableData(i)
        Else
          GenAggregatData(i);
      End;
    End;
  End;
End;

{ --------------------------------------------------------------------------
  GenOneStringLit : emet un litteral de chaine depuis const_table.
  val_str contient le texte brut (apostrophes internes doublees).
  Produit : _JK_xxx  DB  'texte', 0
  -------------------------------------------------------------------------- }
Procedure GenOneStringLit(i : Integer);
Begin
  EmitDB(JK_PFX + const_table^[i].name,
         '''' + const_table^[i].val_str + ''', 0');
End;

{ --------------------------------------------------------------------------
  GenAllStringLits : boucle sur const_table, emet les litteraux string.
  Un litteral est reconnu si val_str[1] = apostrophe.
  -------------------------------------------------------------------------- }
Procedure GenAllStringLits;
Var
  i   : Integer;
  any : Boolean;
Begin
  any := False;
  For i := 1 To const_count Do
  Begin
    If (Length(const_table^[i].val_str) > 0) And
       (const_table^[i].val_str[1] = '''') Then
    Begin
      If Not any Then
      Begin
        EmitBlank;
        EmitComment('Litteraux de chaines');
        any := True;
      End;
      GenOneStringLit(i);
    End;
  End;
End;

{ --------------------------------------------------------------------------
  GenDataSegment : emet le segment DATA complet.
  GenDataHeader + GenSystemVarsData + GenAllItemsData
  + GenAllStringLits + GenDataFooter
  -------------------------------------------------------------------------- }
Procedure GenDataSegment;
Begin
  GenDataHeader;
  GenSystemVarsData;
  EmitBlank;
  GenAllItemsData;
  GenAllStringLits;
  EmitBlank;
  GenDataFooter;
End;

{ ============================================================================
  TODO 07 - PARSER : DECLARATIONS MODULE ET COMPOOL
  ============================================================================ }

{ --------------------------------------------------------------------------
  Forward declarations pour TODO 08 (procedures et fonctions)
  -------------------------------------------------------------------------- }
Procedure ParseProcedureDecl; Forward;
Procedure ParseFunctionDecl;  Forward;

{ --------------------------------------------------------------------------
  ParseConstExpr : evaluer une expression constante au compile-time.
  Grammaire : terme ('+' | '-' | '*') terme ...
  terme : entier | ident (DEFINE/constante)
  -------------------------------------------------------------------------- }
Function ParseConstExpr : LongInt;
Var
  v    : LongInt;
  op   : TString;
  rval : LongInt;
Begin
  { terme primaire }
  If cur_tok.kind = TK_INTEGER Then
  Begin
    v := StrToInt(cur_tok.val);
    LexNext;
  End
  Else If cur_tok.kind = TK_IDENT Then
  Begin
    v := EvalConst(cur_tok.val);
    LexNext;
  End
  Else
  Begin
    WriteLn('  Erreur ligne ', lex_lineno,
            ': expression constante attendue, lu ''', cur_tok.val, '''');
    v := 0;
    LexNext;
  End;
  { operateurs binaires simples }
  While (cur_tok.val = '+') Or (cur_tok.val = '-') Or (cur_tok.val = '*') Do
  Begin
    op := cur_tok.val;
    LexNext;
    If cur_tok.kind = TK_INTEGER Then
    Begin
      rval := StrToInt(cur_tok.val);
      LexNext;
    End
    Else
    Begin
      rval := EvalConst(cur_tok.val);
      LexNext;
    End;
    If op = '+' Then       v := v + rval
    Else If op = '-' Then  v := v - rval
    Else                   v := v * rval;
  End;
  ParseConstExpr := v;
End;

{ --------------------------------------------------------------------------
  ParseItemDecl : 'ITEM' ident type_spec ['=' const_expr] ';'
  type_spec : 'I' bits | 'S' bits '(' val,... ')' | 'B' bits | 'F'
  scope : SC_GLOBAL ou SC_LOCAL
  -------------------------------------------------------------------------- }
Procedure ParseItemDecl(scope : TScope);
Var
  iname : TString;
  itype : TItemType;
  bits  : Integer;
  si    : Integer;
  vc    : Integer;
  vname : TString;
Begin
  LexExpect('ITEM');
  iname := cur_tok.val;
  LexExpectKind(TK_IDENT);
  { type_spec : premier token = lettre de type }
  If cur_tok.val = 'I' Then
  Begin
    itype := IT_INTEGER;
    LexNext;
    bits := StrToInt(cur_tok.val);
    LexExpectKind(TK_INTEGER);
  End
  Else If cur_tok.val = 'S' Then
  Begin
    itype := IT_STATUS;
    LexNext;
    bits := StrToInt(cur_tok.val);
    LexExpectKind(TK_INTEGER);
  End
  Else If cur_tok.val = 'B' Then
  Begin
    itype := IT_BITS;
    LexNext;
    bits := StrToInt(cur_tok.val);
    LexExpectKind(TK_INTEGER);
  End
  Else If cur_tok.val = 'F' Then
  Begin
    itype := IT_REAL;
    bits  := 32;
    LexNext;
  End
  Else
  Begin
    WriteLn('  Erreur ligne ', lex_lineno,
            ': type_spec ITEM inconnu: ''', cur_tok.val, '''');
    itype := IT_INTEGER;
    bits  := 16;
  End;
  { enregistrement dans la table des symboles }
  If scope = SC_GLOBAL Then
    si := AddGlobalItem(iname, itype, bits)
  Else
    si := AddLocalItem(iname, itype, bits, 0);
  { valeurs STATUS : '(' val1 ',' val2 ... ')' }
  If itype = IT_STATUS Then
  Begin
    LexExpect('(');
    vc := 0;
    While (cur_tok.val <> ')') And (cur_tok.kind <> TK_EOF) Do
    Begin
      vname := cur_tok.val;
      LexExpectKind(TK_IDENT);
      If vc < 16 Then
      Begin
        sym_table^[si].enum_vals[vc] := StrUpper(vname);
        Inc(vc);
      End;
      AddConst(sym_table^[si].name + '_' + StrUpper(vname),
               IntToStr(vc - 1), vc - 1);
      If cur_tok.val = ',' Then LexNext;
    End;
    sym_table^[si].enum_count := vc;
    LexExpect(')');
  End;
  { valeur initiale optionnelle : '=' const_expr }
  If cur_tok.val = '=' Then
  Begin
    LexNext;
    ParseConstExpr;    { valeur ignoree : le DATA emet 0 ; sera ameliore }
  End;
  LexExpect(';');
End;

{ --------------------------------------------------------------------------
  ParseStatusDecl : 'STATUS' ident '(' val1 ',' val2 ... ')' ';'
  Declaration autonome d'un type statut (enregistre comme ITEM IT_STATUS).
  -------------------------------------------------------------------------- }
Procedure ParseStatusDecl;
Var
  iname : TString;
  si    : Integer;
  vc    : Integer;
  vname : TString;
Begin
  LexExpect('STATUS');
  iname := cur_tok.val;
  LexExpectKind(TK_IDENT);
  si := AddGlobalItem(iname, IT_STATUS, 16);
  LexExpect('(');
  vc := 0;
  While (cur_tok.val <> ')') And (cur_tok.kind <> TK_EOF) Do
  Begin
    vname := cur_tok.val;
    LexExpectKind(TK_IDENT);
    If vc < 16 Then
    Begin
      sym_table^[si].enum_vals[vc] := StrUpper(vname);
      Inc(vc);
    End;
    AddConst(sym_table^[si].name + '_' + StrUpper(vname),
             IntToStr(vc - 1), vc - 1);
    If cur_tok.val = ',' Then LexNext;
  End;
  sym_table^[si].enum_count := vc;
  LexExpect(')');
  LexExpect(';');
End;

{ --------------------------------------------------------------------------
  ParseTableDecl : 'TABLE' ident ['(' count ')'] ';' item_decls 'END' ';'
  Si '(count)' present : tableau uniforme.
  Sinon : agregat de champs ITEM heterogenes.
  -------------------------------------------------------------------------- }
Procedure ParseTableDecl;
Var
  tname : TString;
  ti    : Integer;
  cnt   : Integer;
  is_u  : Boolean;
  fbase : TString;
Begin
  LexExpect('TABLE');
  tname := cur_tok.val;
  LexExpectKind(TK_IDENT);
  { count optionnel }
  is_u := False;
  cnt  := 1;
  If cur_tok.val = '(' Then
  Begin
    is_u := True;
    LexNext;
    cnt := StrToInt(cur_tok.val);
    LexExpectKind(TK_INTEGER);
    LexExpect(')');
  End;
  ti    := AddTableSym(tname, is_u, cnt);
  fbase := sym_table^[ti].asm_label;
  LexExpect(';');
  { champs : ITEM declarations jusqu'a END }
  While (cur_tok.val <> 'END') And (cur_tok.kind <> TK_EOF) Do
  Begin
    If cur_tok.val = 'ITEM' Then
    Begin
      ParseItemDecl(SC_GLOBAL);
      { reajuster le label ASM : _JV_<TABLE>_<CHAMP> }
      sym_table^[sym_count].asm_label :=
        fbase + '_' + AsmIdent(sym_table^[sym_count].name);
    End
    Else
    Begin
      WriteLn('  Attention ligne ', lex_lineno,
              ': token inattendu dans TABLE ''', tname,
              ''' : ''', cur_tok.val, '''');
      LexNext;
    End;
  End;
  LexExpect('END');
  LexExpect(';');
End;

{ --------------------------------------------------------------------------
  ParseDefine : 'DEFINE' ident '=' const_expr ';'
  Enregistre dans la table des constantes (substitution compile-time).
  -------------------------------------------------------------------------- }
Procedure ParseDefine;
Var
  dname : TString;
  dval  : LongInt;
Begin
  LexExpect('DEFINE');
  dname := cur_tok.val;
  LexExpectKind(TK_IDENT);
  LexExpect('=');
  dval := ParseConstExpr;
  AddConst(dname, IntToStr(dval), dval);
  LexExpect(';');
End;

{ --------------------------------------------------------------------------
  ParseCompoolBody : declarations dans un COMPOOL
  -------------------------------------------------------------------------- }
Procedure ParseCompoolBody;
Begin
  While (cur_tok.val <> 'END') And (cur_tok.kind <> TK_EOF) Do
  Begin
    If      cur_tok.val = 'ITEM'   Then ParseItemDecl(SC_GLOBAL)
    Else If cur_tok.val = 'TABLE'  Then ParseTableDecl
    Else If cur_tok.val = 'STATUS' Then ParseStatusDecl
    Else If cur_tok.val = 'DEFINE' Then ParseDefine
    Else
    Begin
      WriteLn('  Attention ligne ', lex_lineno,
              ': token inattendu dans COMPOOL: ''', cur_tok.val, '''');
      LexNext;
    End;
  End;
End;

{ --------------------------------------------------------------------------
  ParseCompool : 'COMPOOL' ident ';' body 'END' 'COMPOOL' ident ';'
  Les declarations sont traitees comme globales.
  -------------------------------------------------------------------------- }
Procedure ParseCompool;
Var
  cpname : TString;
Begin
  LexExpect('COMPOOL');
  cpname := StrUpper(cur_tok.val);
  LexExpectKind(TK_IDENT);
  LexExpect(';');
  EmitComment(' COMPOOL ' + cpname);
  ScopeEnter;
  ParseCompoolBody;
  ScopeLeave;
  LexExpect('END');
  LexExpect('COMPOOL');
  If cur_tok.kind = TK_IDENT Then LexNext;    { ident de fermeture optionnel }
  LexExpect(';');
End;

{ --------------------------------------------------------------------------
  ParseModuleBody : declarations et code au sein d'un MODULE
  PROCEDURE et FUNCTION seront traitees a TODO 08.
  Instructions executables seront traitees a TODO 09-12.
  -------------------------------------------------------------------------- }
Procedure ParseModuleBody;
Begin
  While (cur_tok.val <> 'END') And (cur_tok.kind <> TK_EOF) Do
  Begin
    If      cur_tok.val = 'ITEM'      Then ParseItemDecl(SC_GLOBAL)
    Else If cur_tok.val = 'TABLE'     Then ParseTableDecl
    Else If cur_tok.val = 'STATUS'    Then ParseStatusDecl
    Else If cur_tok.val = 'DEFINE'    Then ParseDefine
    Else If cur_tok.val = 'COMPOOL'   Then ParseCompool
    Else If cur_tok.val = 'PROCEDURE' Then ParseProcedureDecl
    Else If cur_tok.val = 'FUNCTION'  Then ParseFunctionDecl
    Else
    Begin
      { instructions executables : placeholder jusqu'a TODO 09-12 }
      LexNext;
    End;
  End;
End;

{ --------------------------------------------------------------------------
  ParseModule : 'MODULE' ident ';' body 'END' 'MODULE' [ident] [';']
  Remplit module_name et cur_module_pfx.
  -------------------------------------------------------------------------- }
Procedure ParseModule;
Var
  mname : TString;
Begin
  LexExpect('MODULE');
  mname          := StrUpper(cur_tok.val);
  module_name    := mname;
  cur_module_pfx := mname;
  LexExpectKind(TK_IDENT);
  LexExpect(';');
  EmitComment(' MODULE ' + module_name);
  ScopeEnter;
  ParseModuleBody;
  ScopeLeave;
  LexExpect('END');
  LexExpect('MODULE');
  If cur_tok.kind = TK_IDENT Then LexNext;    { ident de fermeture optionnel }
  If cur_tok.val  = ';'      Then LexNext;
End;

{ --------------------------------------------------------------------------
  Stubs vides de TODO 08 (eviter les erreurs de link sur Forward)
  -------------------------------------------------------------------------- }
Procedure ParseProcedureDecl;
Begin
  { TODO 08 : sera implemente }
  While (cur_tok.val <> 'END') And (cur_tok.kind <> TK_EOF) Do
    LexNext;
  If cur_tok.val = 'END' Then LexNext;
  LexExpect(';');
End;

Procedure ParseFunctionDecl;
Begin
  { TODO 08 : sera implemente }
  While (cur_tok.val <> 'END') And (cur_tok.kind <> TK_EOF) Do
    LexNext;
  If cur_tok.val = 'END' Then LexNext;
  LexExpect(';');
End;

{ ============================================================================
  TODO 08 ... 25 : a implementer
  ============================================================================ }

Begin
  WriteLn('JOVIAL86 v', JOVIAL86_VERSION,
          ' - compilateur JOVIAL 73 -> MASM 8086');
  WriteLn('(TODO 08-25 non implementes)');
End.
