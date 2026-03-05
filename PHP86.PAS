(* ============================================================
  PHP86.PAS - Compilateur PHP vers assembleur 8086
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .MODEL SMALL, DOS 16 bits

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - INFRASTRUCTURE ET OPTIONS
            TOptions (SrcFile, OutFile, Verbose, DebugMode)
            ParseArgs : analyser argv (fichier.php [sortie.asm] [-v] [-d])
            FatalError, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Programme principal : validation des arguments et appel Run

  TODO 02 - LEXEUR (TOKENS PHP)
            TTokenKind : TK_EOF, TK_INTEGER, TK_FLOAT, TK_STRING,
              TK_IDENT, TK_VAR (prefixe $), TK_KEYWORD, TK_OP, TK_PUNCT
            Balises PHP : <?php  ?>  (mode texte ignore sauf echo inline)
            LexInit, LexClose, LexNextToken, LexScanIdent, LexScanNumber
            LexScanString (guillemets simples et doubles avec interpolation)
            LexScanOp (. -> :: ===  !==  **  <=>  etc.)
            IsPhpKeyword : liste complete des mots-cles PHP
            Mode debug -d : affichage de chaque token avec PrintToken

  TODO 03 - LITTERAUX ET CONSTANTES
            Entiers decimaux, hexadecimaux (0x), octaux (0), binaires (0b)
            Flottants : reconnus par le lexeur, traites comme entiers (trunc)
            Chaines simple-quote : pas d'interpolation, sequences \\ et \'
            Chaines double-quote : interpolation de $var, sequences \n \t \r
            Heredoc / Nowdoc : syntaxe <<<LABEL et <<<'LABEL'
            true / false / null : constantes booleennes et null

  TODO 04 - OPERATEURS ET PRECEDENCE
            Arithmetiques   : + - * / % ** (puissance)
            Concatenation   : . et .=
            Comparaison     : == != === !== < <= > >= <=>
            Logiques        : && || ! and or not (deux niveaux de precedence)
            Bitwise         : & | ^ ~ << >>
            Ternaire        : cond ? a : b   et   expr ?: default (Elvis)
            Null-coalescing : ?? et ??=
            BinOpPrec : table de precedences Pratt pour ParseExprPrec

  TODO 05 - TABLE DES SYMBOLES
            TSymCat : SC_VAR (locale), SC_GLOBAL, SC_PARAM,
              SC_FN, SC_CLASS, SC_CONST
            TSymRec : Name, MangledName, Cat, TypeIdx, Offset, IsMut, IsRef
            SymAdd, SymFind, SymFindCat, SymMangle
            SymEnterScope / SymLeaveScope (gestion des portees imbriquees)
            Variables $var : le $ est consomme par le lexeur (TK_VAR)
            Constantes define() et const NAME = expr;

  TODO 06 - SYSTEME DE TYPES PHP
            TTypeKind : TKD_INT, TKD_FLOAT, TKD_STRING, TKD_BOOL,
              TKD_NULL, TKD_ARRAY, TKD_OBJECT, TKD_MIXED, TKD_VOID
            TypeTab, TypeInit : enregistrer les types primitifs
            TypeFind, TypeSizeof (int=2o, string=ptr 2o, bool=1o)
            TypeMangle : nom mangle du type pour les labels ASM
            Promotion automatique : bool et null -> int sur la pile

  TODO 07 - EMETTEUR DE CODE ASM
            TEmitter : OutF (Text), OutFOpen, EmitOpen, EmitClose
            EmitRaw, EmitLabel, EmitInstr (formatage 8 espaces)
            EmitComment, EmitBlankLine
            LabelGen global (compteur unique _PHL_NNNNN)
            Prefixes : _PHV_ (var), _PHF_ (fn), _PHK_ (string), _PHRT_ (runtime)

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES
            TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR), IntVal, StrVal
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd : enregistrer une entree dans DataTab
            EmitDataSeg : ecrire _DATA SEGMENT PUBLIC 'DATA' ... _DATA ENDS
            Chaines litterales echo "..." -> entree DK_STR automatique

  TODO 09 - VARIABLES ET AFFECTATIONS
            Variables locales $var : allouees sur la pile (SUB SP, 2)
            Variables globales : dans le segment DATA (DK_WORD)
            Affectation simple : $var = expr  -> ExprLoad + MOV [BP-n], AX
            Affectation par reference : $a = &$b  -> LEA + stockage pointeur
            global $var : lier au segment DATA depuis une fonction
            static $var : variable locale persistante entre appels

  TODO 10 - EXPRESSIONS PRIMAIRES
            ParsePrimary : literal entier, literal chaine, $var,
              operateurs unaires (- ! ~ ++ -- pre/post),
              groupement parenthese,
              cast (int) (string) (bool) (float)
            ExprMakeImm, ExprMakeNone : constructeurs TExprVal (Var Res)
            ExprLoad : materialiser la valeur dans AX

  TODO 11 - EXPRESSIONS BINAIRES (PRATT)
            ParseExprPrec(MinPrec, Var Res) : boucle Pratt
            ExprEmitBinOp : ADD/SUB/IMUL/IDIV, CMP+SETcc, AND/OR/XOR
            Concatenation . : appel _PHRT_CONCAT(SI=buf, DI=src, CX=len)
            Ternaire cond ? a : b : emission avec labels _PHL_TERN_N
            Null-coalescing ?? : test EK_NONE et branchement

  TODO 12 - ECHO / PRINT / VAR_DUMP
            ParseEchoStmt : echo $a, "str", 42; (liste d'expressions)
            Chaines constantes : MOV SI, OFFSET lbl + CALL _PHRT_PRINT
            Entiers : CALL _PHRT_ITOA puis _PHRT_PRINT
            print expr ; (une seule expression, retourne 1)
            var_dump(expr) : emet le type et la valeur (mode debug)
            Retour a la ligne implicite de println / echo "...\n"

  TODO 13 - IF / ELSEIF / ELSE
            ParseIfStmt : if (cond) BLOC [elseif (cond) BLOC]* [else BLOC]
            Labels _PHL_ELSEIF_N, _PHL_ELSE_N, _PHL_ENDIF_N
            Condition : ExprLoad + TEST AX, AX + JZ/JNZ
            if (isset($v)) et if (is_null($v)) : cas speciaux optimises
            Syntaxe alternative : if (): ... endif;

  TODO 14 - BOUCLES : while / do..while / for
            ParseWhileStmt : while (cond) BLOC
            ParseDoWhileStmt : do BLOC while (cond);
            ParseForStmt : for (init; cond; incr) BLOC (3 parties separees)
            LoopPush / LoopPop : pile de labels break/continue
            break N et continue N : sortie de N niveaux de boucle
            Syntaxes alternatives : while (): ... endwhile; etc.

  TODO 15 - FOREACH
            ParseForeachStmt : foreach ($arr as $val) et as $key => $val
            Tableaux indexes simples : iteration sur [0..n-1]
              MOV CX, taille / boucle INC index / acces $arr[idx]
            Variable de cle $k : entier incrementiel sur la pile
            break et continue dans foreach

  TODO 16 - SWITCH / CASE / DEFAULT
            ParseSwitchStmt : switch (expr) { case lit: ... default: ... }
            Sujet evalue dans BX (une seule fois avant la table)
            Chaque case : CMP BX, val + JNE suivant
            Fall-through naturel : pas de JMP entre cases consecutifs
            break obligatoire pour sortir, default en dernier
            Syntaxe alternative : switch (): ... endswitch;

  TODO 17 - FONCTIONS
            ParseFnDecl : function name($p1, $p2 = def, ...$rest)
            Parametres par defaut : test AX avec valeur sentinelle
            Parametres variadiques ...$args : non pris en charge (warning)
            Parametres par reference &$param : IsRef = True
            Valeur de retour : return expr; -> AX ou pile selon taille
            Fonctions anonymes / lambdas : function() use($x) {} (simplifie)
            ParseCallArgs, EmitCallSite (cdecl 16 bits)

  TODO 18 - PORTEE, PILE ET CADRES
            CurFrameSize : taille incrementale du cadre local
            Prologue : PUSH BP / MOV BP, SP
            Epilogue : MOV SP, BP / POP BP / RET
            Variables locales : SUB SP, 2 par $var declare
            Parametres : [BP+4] premier, [BP+6] deuxieme, ...
            Fermeture de portee : SymLeaveScope + restauration SP

  TODO 19 - TABLEAUX PHP
            array() et syntaxe courte [] : tableaux indexes
            Representation : pointeur vers bloc memoire en DATA ou pile
            Acces $a[i] (i constant) : calcul offset + MOV
            count($a) : retourne la taille stockee en [ptr-2]
            array_push($a, v) : appel _PHRT_ARRAY_PUSH
            Tableaux associatifs : keys dans DATA (non pris en charge, warning)

  TODO 20 - FONCTIONS INTEGREES (BUILTINS)
            strlen($s) -> CALL _PHRT_STRLEN (retourne CX puis AX)
            intval($s) -> CALL _PHRT_ATOI
            strval($n) -> CALL _PHRT_ITOA
            isset($v)  -> test EK_NONE dans SymTab (bool AX)
            is_null($v)-> idem
            defined(NAME) -> recherche dans SymTab constantes
            abs($n), min($a,$b), max($a,$b) -> implementation inline
            die/exit : MOV AX, 4C00h + INT 21h

  TODO 21 - CLASSES PHP (BASIQUE)
            ParseClassDecl : class Name [extends Parent] { membres }
            Proprietes : public/protected/private $prop = val
            Methodes : fonction avec $this implicite comme premier parametre
            new ClassName(args) : allocation sur la pile (taille fixe compile)
            Acces $obj->prop et $obj->method() : offset compile
            Pas d'heritage dynamique (avertissement si extends non trivial)

  TODO 22 - RUNTIME MINIMAL
            _PHRT_PRINT(SI=msg, CX=len) : INT 21h AH=40h BX=1
            _PHRT_PRINTLN : _PHRT_PRINT + emet Chr(13)+Chr(10)
            _PHRT_ITOA(AX=n, DI=buf) : conversion entier -> chaine ASCII
            _PHRT_STRLEN(SI=str) : compte octets jusqu'a 0 -> AX
            _PHRT_CONCAT(DI=dst, SI=src) : copie src dans dst
            _PHRT_PANIC(SI=msg) : affiche message + INT 21h AH=4Ch AL=1
            RuntimeEmitted : flag pour n'emettre le runtime qu'une fois

  TODO 23 - INCLUDE / REQUIRE
            ParseIncludeStmt : include / require / include_once / require_once
            Resolution du chemin au moment de la compilation (chemin relatif)
            Ouverture et analyse du fichier inclus comme sous-compilation
            Symboles du fichier inclus ajoutes a la table courante
            Garde d'inclusion unique (_once) : table des fichiers deja inclus
            Erreur fatale si require echoue ; avertissement pour include

  TODO 24 - PREPROCESSEUR ET CONSTANTES
            define('NOM', val) : ajout SC_CONST dans SymTab
            const NOM = val ; (niveau global et dans les classes)
            Macros PHP_INT_MAX, PHP_EOL, PHP_OS : constantes predefinis
            PHP_EOL -> entree DK_STR avec Chr(13)+Chr(10)
            Conditionnels : if (defined('NOM')) -> evaluation au compile
            __LINE__, __FILE__, __FUNCTION__ : constantes magiques

  TODO 25 - GENERATION FINALE ET FICHIERS EXEMPLES
            EmitHeader : .MODEL SMALL / .STACK 1024 / _TEXT SEGMENT
            Run : pipeline complet LexInit -> parse -> EmitRuntime ->
              _TEXT ENDS / EmitDataSeg / END _PHF_main
            Fichiers SAMPLES\PHP\ a creer :
              hello.php   (echo, variables, concatenation)
              math.php    (fonctions, arithmetique, return)
              control.php (if/elseif/else, while, for, switch)
              array.php   (tableaux, foreach, count, array_push)
            Smoke tests : RUST86.EXE -v SAMPLES\PHP\*.php
  ============================================================ *)

{ ============================================================
  PHP86 - Compilateur PHP -> assembleur 8086
  Version : 1.0  Date : 2026-03-05
  Auteur  : DEV-COOLS
  Compilation : ppc386 -O2 -Mtp PHP86.PAS
  ============================================================ }

Program PHP86;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES GLOBALES
  ============================================================ }
Const
  PHP86_VERSION  = '1.0';
  PHP86_DATE     = '2026-03-05';

  { Limites des tableaux internes }
  MAX_SYM        = 2048;
  MAX_PROC       = 256;
  MAX_LABEL      = 2048;
  MAX_SCOPE      = 64;
  MAX_DATA       = 256;
  MAX_TYPE       = 32;
  MAX_FIELD      = 64;
  MAX_METHOD     = 128;
  MAX_PARAM      = 32;
  MAX_LOOP_NEST  = 16;
  MAX_ERRORS     = 30;
  MAX_STR        = 255;
  MAX_INCLUDE    = 32;
  STACK_SIZE     = 1024;
  MAX_CLASS      = 16;   { nombre max de classes                 }
  MAX_CLASS_PROP = 16;   { proprietes max par classe             }
  MAX_CLASS_METH = 16;   { methodes max par classe               }

  { Prefixes de nommage ASM }
  PH_VAR_PFX   = '_PHV_';
  PH_FN_PFX    = '_PHF_';
  PH_STR_PFX   = '_PHK_';
  PH_RT_PFX    = '_PHRT_';
  PH_LBL_PFX  = '_PHL_';

  { Codes de sortie }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Indices de types primitifs PHP }
  TY_IDX_INT    = 0;
  TY_IDX_FLOAT  = 1;
  TY_IDX_STRING = 2;
  TY_IDX_BOOL   = 3;
  TY_IDX_NULL   = 4;
  TY_IDX_MIXED  = 5;
  TY_IDX_VOID   = 6;
  TY_PRIM_COUNT = 7;
  TY_UNKNOWN    = -1;

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String[MAX_STR];

  TTokenKind = (
    TK_EOF,        { fin de fichier }
    TK_IDENT,      { identificateur PHP }
    TK_KEYWORD,    { mot-cle PHP }
    TK_VAR,        { variable PHP prefixee $ }
    TK_INTEGER,    { litteral entier }
    TK_FLOAT,      { litteral flottant }
    TK_STRING,     { litteral chaine }
    TK_OP,         { operateur }
    TK_PUNCT       { ponctuation }
  );

  TToken = Record
    Kind     : TTokenKind;
    Val      : TString;
    IntVal   : LongInt;
    FloatVal : Real;
    Line     : Integer;
    Col      : Integer;
  End;

  TOptions = Record
    SrcFile    : TString;
    OutFile    : TString;
    Verbose    : Boolean;
    DebugTok   : Boolean;
    StrictMode : Boolean;  { strict_types=1 }
  End;

  TSymCat = (
    SC_VAR,     { variable locale $var }
    SC_GLOBAL,  { variable globale }
    SC_PARAM,   { parametre de fonction }
    SC_FN,      { fonction }
    SC_CLASS,   { classe }
    SC_CONST    { constante define() ou const }
  );

  TSymRec = Record
    Name        : TString;
    MangledName : TString;
    Cat         : TSymCat;
    TypeIdx     : Integer;  { indice dans TypeTab }
    ScopeLevel  : Integer;
    Offset      : Integer;  { offset BP pour locaux, offset DATA pour globals }
    IsRef       : Boolean;  { parametre passe par reference &$p }
    DeclLine    : Integer;
  End;

  TTypeKind = (
    TKD_INT,
    TKD_FLOAT,
    TKD_STRING,
    TKD_BOOL,
    TKD_NULL,
    TKD_ARRAY,
    TKD_OBJECT,
    TKD_MIXED,
    TKD_VOID,
    TKD_UNKNOWN
  );

  TTypeRec = Record
    Name    : TString;
    Kind    : TTypeKind;
    Size    : Integer;   { taille en octets : int=2, bool=1, string=2(ptr) }
    ElemIdx : Integer;   { pour TKD_ARRAY : type des elements }
    ClassSz : Integer;   { pour TKD_OBJECT : taille totale de l'objet }
  End;

  TExprKind = (
    EK_NONE,   { valeur nulle ou void }
    EK_IMM,    { immediat entier dans ImmVal }
    EK_AX,     { valeur dans le registre AX }
    EK_DXAX,   { valeur longue dans DX:AX }
    EK_MEM     { adresse memoire [BP+Offset] ou [_PHV_x] }
  );

  TExprVal = Record
    Kind    : TExprKind;
    ImmVal  : LongInt;
    TypeIdx : Integer;
    Offset  : Integer;
  End;

  TDataKind = (DK_WORD, DK_BYTE, DK_STR);

  TDataRec = Record
    LblName : TString;
    Kind    : TDataKind;
    IntVal  : LongInt;
    StrVal  : TString;
  End;

  TClassPropRec = Record
    PropName : TString;   { nom de la propriete (sans $)         }
    PropOff  : Integer;   { offset en octets depuis le debut obj  }
    PropType : Integer;   { TypeIdx                               }
  End;

  TClassRec = Record
    ClsName    : TString;
    ParentName : TString;
    PropCount  : Integer;
    Props      : Array[0..MAX_CLASS_PROP - 1] Of TClassPropRec;
    MethCount  : Integer;
    MethNames  : Array[0..MAX_CLASS_METH - 1] Of TString;
    ObjSize    : Integer;   { taille en octets = PropCount * 2   }
  End;

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
Var
  { Options de compilation }
  Opts       : TOptions;

  { Compteurs d'erreurs }
  ErrorCount : Integer;
  WarnCount  : Integer;
  TotalLines : LongInt;
  TotalSyms  : Integer;

  { Valeur fictive pour ignorer un retour TExprVal }
  GExprDummy : TExprVal;

  { Lexeur }
  LexSrcF   : Text;
  LexLine   : String;
  LexLineNo : Integer;
  LexColNo  : Integer;
  LexEOF    : Boolean;
  LexOpened : Boolean;
  CurToken  : TToken;

  { Table des symboles }
  SymTab    : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount  : Integer;
  ScopeStack: Array[0..MAX_SCOPE - 1] Of Integer;
  ScopeTop  : Integer;
  CurScope  : Integer;
  LabelSeq  : Integer;

  { Table des types }
  TypeTab   : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount : Integer;

  { Emetteur de code }
  OutF      : Text;
  OutFOpen  : Boolean;
  CurFrameSize : Integer;
  CurFnDepth   : Integer;    { 0 = global, >0 = dans une fonction }
  LoopTop      : Integer;
  LoopBreakLbl : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopContLbl  : Array[0..MAX_LOOP_NEST - 1] Of TString;

  { Segment de donnees }
  DataTab   : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount : Integer;

  { Etat general }
  RuntimeEmitted : Boolean;
  InPhpMode      : Boolean;  { True quand on est a l'interieur de <?php ... ?> }
  CurFnRetLbl    : TString;  { label epilogue de la fonction courante }

  { Classes }
  ClassTab   : Array[0..MAX_CLASS - 1] Of TClassRec;
  ClassCount : Integer;
  CurClsIdx  : Integer;   { -1 = hors classe, >= 0 = index dans ClassTab }

{ ============================================================
  FORWARD DECLARATIONS
  ============================================================ }
Procedure LexClose;      Forward;
Procedure EmitClose;     Forward;
Procedure ParserAdvance; Forward;
Procedure EmitDataSeg;   Forward;
Function  DataAddStr(Const S : TString) : Integer; Forward;
Function  DataAdd(Const ALbl : TString; AKind : TDataKind;
                  AInt : LongInt; Const AStr : TString) : Integer; Forward;
Function  AllocLocal(Const VarName : TString; TyIdx, DeclLine : Integer) : Integer; Forward;
Function  AllocGlobal(Const VarName : TString; TyIdx, DeclLine : Integer) : Integer; Forward;
Procedure VarStore(Idx : Integer); Forward;
Procedure VarLoadToAX(Idx : Integer); Forward;
Function  SymFind(Const AName : TString) : Integer; Forward;
Function  SymFindLocal(Const AName : TString) : Integer; Forward;
Function  SymFindCat(Const AName : TString; ACat : TSymCat) : Integer; Forward;
Function  SymAdd(Const AName : TString; ACat : TSymCat; ATypeIdx : Integer;
                 AIsRef : Boolean; AOffset : Integer; ADeclLine : Integer) : Integer; Forward;
Function  SymNewLabel(Const Prefix : TString) : TString; Forward;
Procedure ParseEchoStmt;    Forward;
Procedure ParsePrintStmt;   Forward;
Procedure ParseVarDumpStmt; Forward;
Procedure ParseStmt;        Forward;
Procedure ParseBlock;       Forward;
Procedure ParseIfStmt;      Forward;
Procedure ParseWhileStmt;   Forward;
Procedure ParseDoWhileStmt; Forward;
Procedure ParseForStmt;     Forward;
Procedure ParseBreakStmt;   Forward;
Procedure ParseContinueStmt; Forward;
Procedure ParseIfCond(Var E : TExprVal; Var JmpFalse : TString); Forward;
Procedure ParseForeachStmt;  Forward;
Procedure ParseSwitchStmt;   Forward;
Procedure ParseFnDecl;       Forward;
Procedure ParseReturnStmt;   Forward;
Procedure ParseCallExpr(Const FnName : TString; Var Res : TExprVal); Forward;
Function  BlockEnterScope : Integer; Forward;
Procedure BlockLeaveScope(SavedFrame : Integer); Forward;
Procedure ParseArrayLit(Var Res : TExprVal); Forward;
Procedure ParseClassDecl; Forward;
Procedure ParseNewExpr(Const ClsName : TString; Var Res : TExprVal); Forward;

{ ============================================================
  TODO 01 - INFRASTRUCTURE ET OPTIONS
  ============================================================ }

{ ---- Erreur fatale ---------------------------------------- }
Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('PHP86: ERREUR FATALE - ', Msg);
  Halt(EXIT_ERROR);
End;

{ ---- Aide en ligne ---------------------------------------- }
Procedure ShowHelp;
Begin
  WriteLn('Usage: PHP86 <source.php> [sortie.asm] [-v] [-d] [-s]');
  WriteLn('  -v   mode verbeux');
  WriteLn('  -d   debug tokens');
  WriteLn('  -s   strict_types');
  WriteLn('  -h   cette aide');
  Halt(EXIT_OK);
End;

{ ---- Initialisation des options --------------------------- }
Procedure InitOptions;
Begin
  Opts.SrcFile    := '';
  Opts.OutFile    := '';
  Opts.Verbose    := False;
  Opts.DebugTok   := False;
  Opts.StrictMode := False;
End;

{ ---- Construction du nom de sortie par defaut ------------- }
Procedure BuildOutName;
Var
  Base : TString;
  Ext  : TString;
  I    : Integer;
Begin
  Base := Opts.SrcFile;
  { Chercher la derniere extension }
  Ext := '';
  For I := Length(Base) DownTo 1 Do
  Begin
    If Base[I] = '.' Then
    Begin
      Ext  := Copy(Base, I, Length(Base) - I + 1);
      Base := Copy(Base, 1, I - 1);
      Break;
    End;
  End;
  If (Ext = '.php') Or (Ext = '.PHP') Then
    Opts.OutFile := Base + '.asm'
  Else
    Opts.OutFile := Opts.SrcFile + '.asm';
End;

{ ---- Analyse des arguments de la ligne de commande -------- }
Procedure ParseArgs;
Var
  I   : Integer;
  Arg : TString;
Begin
  If ParamCount = 0 Then
    ShowHelp;
  I := 1;
  While I <= ParamCount Do
  Begin
    Arg := ParamStr(I);
    If (Arg = '-h') Or (Arg = '--help') Then
      ShowHelp
    Else If (Arg = '-v') Or (Arg = '--verbose') Then
      Opts.Verbose := True
    Else If (Arg = '-d') Or (Arg = '--debug') Then
      Opts.DebugTok := True
    Else If (Arg = '-s') Or (Arg = '--strict') Then
      Opts.StrictMode := True
    Else If Arg[1] = '-' Then
    Begin
      WriteLn('PHP86: option inconnue : ', Arg);
      Halt(EXIT_USAGE);
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else If Opts.OutFile = '' Then
      Opts.OutFile := Arg
    Else
    Begin
      WriteLn('PHP86: argument inattendu : ', Arg);
      Halt(EXIT_USAGE);
    End;
    Inc(I);
  End;
  If Opts.SrcFile = '' Then
  Begin
    WriteLn('PHP86: aucun fichier source specifie.');
    Halt(EXIT_USAGE);
  End;
  If Opts.OutFile = '' Then
    BuildOutName;
End;

{ ---- Banniere verbose ------------------------------------- }
Procedure ShowBanner;
Begin
  If Not Opts.Verbose Then Exit;
  WriteLn('================================================');
  WriteLn(' PHP86 v', PHP86_VERSION, ' (', PHP86_DATE, ')');
  WriteLn('================================================');
  WriteLn(' Source  : ', Opts.SrcFile);
  WriteLn(' Sortie  : ', Opts.OutFile);
  If Opts.StrictMode Then
    WriteLn(' Mode    : strict_types=1');
  WriteLn('------------------------------------------------');
End;

{ ---- Statistiques finales --------------------------------- }
Procedure ShowStats;
Begin
  WriteLn('------------------------------------------------');
  WriteLn(' Lignes   : ', TotalLines);
  WriteLn(' Symboles : ', SymCount);
  WriteLn(' Erreurs  : ', ErrorCount);
  WriteLn(' Avert.   : ', WarnCount);
  If ErrorCount = 0 Then
    WriteLn(' Resultat : OK -> ', Opts.OutFile)
  Else
    WriteLn(' Resultat : ECHEC (', ErrorCount, ' erreur(s))');
  WriteLn('================================================');
End;

{ ---- Nettoyage des ressources ----------------------------- }
Procedure Cleanup;
Begin
  LexClose;
  EmitClose;
End;

{ ============================================================
  TODO 02 - LEXEUR (TOKENS PHP)
  ============================================================ }

{ ---- Primitives de bas niveau ----------------------------- }
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

{ ---- Erreur lexicale (non fatale) ------------------------- }
Procedure LexError(Const Msg : TString);
Begin
  WriteLn('PHP86:', LexLineNo, ':', LexColNo, ': Erreur: ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('Trop d''erreurs - compilation abandonnee');
End;

{ ---- Constructeur de token -------------------------------- }
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

{ ---- Commentaires ---------------------------------------- }
Procedure LexSkipLineComment;
Begin
  LexColNo := Length(LexLine) + 1;
End;

Procedure LexSkipBlockComment;
Var
  C : Char;
Begin
  While Not LexEOF Do
  Begin
    If LexColNo > Length(LexLine) Then
    Begin LexNextLine; Continue; End;
    C := LexCurChar;
    LexAdvance;
    If C = '*' Then
      If (LexColNo <= Length(LexLine)) And (LexCurChar = '/') Then
      Begin LexAdvance; Exit; End;
  End;
  LexError('Commentaire bloc non ferme en fin de fichier');
End;

{ ---- LexSkipToPhp : sauter texte HTML jusqu''a <?php ------ }
Procedure LexSkipToPhp;
Begin
  While Not LexEOF Do
  Begin
    If LexColNo > Length(LexLine) Then
    Begin LexNextLine; Continue; End;
    If LexCurChar <> '<' Then Begin LexAdvance; Continue; End;
    LexAdvance;
    If LexEOF Or (LexColNo > Length(LexLine)) Or (LexCurChar <> '?') Then Continue;
    LexAdvance;
    { <?= (echo) }
    If (LexColNo <= Length(LexLine)) And (LexCurChar = '=') Then
    Begin LexAdvance; InPhpMode := True; Exit; End;
    { <?php }
    If (LexColNo + 2 <= Length(LexLine)) And
       (LexLine[LexColNo]   = 'p') And
       (LexLine[LexColNo+1] = 'h') And
       (LexLine[LexColNo+2] = 'p') Then
    Begin
      LexColNo := LexColNo + 3;
      InPhpMode := True;
      Exit;
    End;
  End;
End;

{ ---- LexSkipWS : espaces, newlines et commentaires -------- }
Procedure LexSkipWS;
Var
  C : Char;
Begin
  Repeat
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
      LexNextLine;
    If LexEOF Then Exit;
    C := LexCurChar;
    If (C = ' ') Or (C = #9) Or (C = #13) Or (C = #10) Then
      LexAdvance
    Else If (C = '/') And (LexPeek = '/') Then
      LexSkipLineComment
    Else If C = '#' Then
      LexSkipLineComment
    Else If (C = '/') And (LexPeek = '*') Then
    Begin
      LexAdvance; LexAdvance;
      LexSkipBlockComment;
    End
    Else If (C = '?') And (LexPeek = '>') Then
    Begin
      LexAdvance; LexAdvance;
      InPhpMode := False;
      LexSkipToPhp;
    End
    Else
      Exit;
  Until False;
End;

{ ---- Utilitaires caracteres ------------------------------- }
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

Function HexVal(C : Char) : Integer;
Begin
  If   (C >= '0') And (C <= '9') Then HexVal := Ord(C) - Ord('0')
  Else If (C >= 'a') And (C <= 'f') Then HexVal := Ord(C) - Ord('a') + 10
  Else HexVal := Ord(C) - Ord('A') + 10;
End;

{ ---- Table des mots-cles PHP ------------------------------ }
Const
  PHP_KW_COUNT = 68;
  PHP_KW : Array[0..67] Of String[14] = (
    'if',           'else',         'elseif',       'endif',
    'while',        'endwhile',     'do',           'for',
    'endfor',       'foreach',      'endforeach',   'break',
    'continue',     'switch',       'endswitch',    'case',
    'default',      'return',       'match',
    'function',     'class',        'interface',    'abstract',
    'extends',      'implements',   'trait',        'new',
    'namespace',    'use',          'const',        'static',
    'public',       'protected',    'private',      'final',
    'readonly',     'enum',
    'int',          'float',        'string',       'bool',
    'null',         'void',         'array',        'object',
    'mixed',        'never',        'true',         'false',
    'TRUE',         'FALSE',        'NULL',
    'echo',         'print',        'var_dump',     'isset',
    'unset',        'empty',        'include',      'require',
    'include_once', 'require_once', 'global',       'list',
    'throw',        'try',          'catch',        'finally'
  );

Function IsPhpKeyword(Const S : TString) : Boolean;
Var
  I : Integer;
Begin
  IsPhpKeyword := False;
  For I := 0 To PHP_KW_COUNT - 1 Do
    If S = PHP_KW[I] Then
    Begin IsPhpKeyword := True; Exit; End;
End;

{ ---- LexScanIdent : identificateur ou mot-cle ------------- }
Procedure LexScanIdent(Var T : TToken; SL, SC : Integer);
Var
  S : TString;
Begin
  S := '';
  While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
        IsAlNum(LexCurChar) Do
  Begin
    If Length(S) < MAX_STR Then S := S + LexCurChar;
    LexAdvance;
  End;
  If IsPhpKeyword(S) Then
    MakeToken(T, TK_KEYWORD, S, SL, SC)
  Else
    MakeToken(T, TK_IDENT, S, SL, SC);
End;

{ ---- LexScanNumber : entier ou flottant ------------------- }
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
  If (C = '0') And (LexPeek <> #0) Then
  Begin
    Case LexPeek Of
      'x','X': Begin S := '0x'; LexAdvance; LexAdvance; Base := 16; End;
      'b','B': Begin S := '0b'; LexAdvance; LexAdvance; Base := 2;  End;
      'o','O': Begin S := '0o'; LexAdvance; LexAdvance; Base := 8;  End;
    Else
      Val := 0; S := '0'; LexAdvance;
    End;
  End Else
  Begin
    Val := Ord(C) - Ord('0');
    S   := C;
    LexAdvance;
  End;
  While (Not LexEOF) And (LexColNo <= Length(LexLine)) Do
  Begin
    C := LexCurChar;
    If C = '_' Then Begin LexAdvance; Continue; End;
    Case Base Of
      2  : If (C = '0') Or (C = '1') Then
           Begin Val := Val*2+(Ord(C)-Ord('0')); If Length(S)<MAX_STR Then S:=S+C; LexAdvance; End
           Else Break;
      8  : If (C >= '0') And (C <= '7') Then
           Begin Val := Val*8+(Ord(C)-Ord('0')); If Length(S)<MAX_STR Then S:=S+C; LexAdvance; End
           Else Break;
      10 : If IsDigit(C) Then
           Begin Val := Val*10+(Ord(C)-Ord('0')); If Length(S)<MAX_STR Then S:=S+C; LexAdvance; End
           Else Break;
      16 : If IsHexDigit(C) Then
           Begin Val := Val*16+HexVal(C); If Length(S)<MAX_STR Then S:=S+C; LexAdvance; End
           Else Break;
    End;
  End;
  { Detection flottant (base 10) }
  If (Base = 10) And (Not LexEOF) And (LexColNo <= Length(LexLine)) And
     (LexCurChar = '.') And IsDigit(LexPeek) Then
  Begin
    Fv    := Val * 1.0;
    Div10 := 10.0;
    If Length(S) < MAX_STR Then S := S + '.';
    LexAdvance;
    While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
          (IsDigit(LexCurChar) Or (LexCurChar = '_')) Do
    Begin
      If LexCurChar <> '_' Then
      Begin
        Fv    := Fv + (Ord(LexCurChar) - Ord('0')) / Div10;
        Div10 := Div10 * 10.0;
        If Length(S) < MAX_STR Then S := S + LexCurChar;
      End;
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
      While (Not LexEOF) And (LexColNo <= Length(LexLine)) And IsDigit(LexCurChar) Do
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
    End;
    MakeToken(T, TK_FLOAT, S, SL, SC);
    T.FloatVal := Fv;
    Exit;
  End;
  MakeToken(T, TK_INTEGER, S, SL, SC);
  T.IntVal := Val;
End;

{ ---- LexScanEscape : sequence d''echappement -------------- }
Function LexScanEscape(Var IntOut : LongInt) : Char;
Var
  C    : Char;
  Code : LongInt;
  I    : Integer;
Begin
  IntOut := 0;
  Code   := 0;
  If LexColNo > Length(LexLine) Then
  Begin
    LexError('Sequence d''echappement incomplete');
    LexScanEscape := '?';
    Exit;
  End;
  C := LexCurChar;
  LexAdvance;
  Case C Of
    'n' : Begin LexScanEscape := #10; IntOut := 10; End;
    't' : Begin LexScanEscape := #9;  IntOut := 9;  End;
    'r' : Begin LexScanEscape := #13; IntOut := 13; End;
    '0' : Begin LexScanEscape := #0;  IntOut := 0;  End;
    '"' : Begin LexScanEscape := '"'; IntOut := 34; End;
    '''': Begin LexScanEscape := ''''; IntOut := 39; End;
    '\' : Begin LexScanEscape := '\'; IntOut := 92; End;
    '$' : Begin LexScanEscape := '$'; IntOut := 36; End;
    'x' : Begin
            Code := 0;
            For I := 1 To 2 Do
            Begin
              If (LexColNo > Length(LexLine)) Or (Not IsHexDigit(LexCurChar)) Then
              Begin LexError('\x: 2 chiffres hexa attendus'); Break; End;
              Code := Code * 16 + HexVal(LexCurChar);
              LexAdvance;
            End;
            IntOut := Code;
            LexScanEscape := Chr(Code And $FF);
          End;
  Else
    LexScanEscape := C;
    IntOut := Ord(C);
  End;
End;

{ ---- LexScanStrSingle : chaine simple-quote --------------- }
Procedure LexScanStrSingle(Var T : TToken; SL, SC : Integer);
Var
  S    : TString;
  C    : Char;
  Done : Boolean;
Begin
  LexAdvance; { guillemet-simple ouverture }
  S    := '';
  Done := False;
  Repeat
    If LexColNo > Length(LexLine) Then
    Begin
      LexError('Chaine simple-quote non fermee en fin de ligne');
      Done := True;
    End Else
    Begin
      C := LexCurChar;
      If Ord(C) = 39 Then
      Begin
        LexAdvance; Done := True;
      End Else If Ord(C) = 92 Then
      Begin
        LexAdvance;
        If (LexColNo <= Length(LexLine)) And
           ((LexCurChar = #39) Or (LexCurChar = #92)) Then
        Begin
          If Length(S) < MAX_STR Then S := S + LexCurChar;
          LexAdvance;
        End Else
          If Length(S) < MAX_STR Then S := S + '\';
      End Else
      Begin
        If Length(S) < MAX_STR Then S := S + C;
        LexAdvance;
      End;
    End;
  Until Done;
  MakeToken(T, TK_STRING, S, SL, SC);
End;

{ ---- LexScanStrDouble : chaine double-quote --------------- }
{ Interpolation $var encodee comme #1+nom+#2 dans Val.Val    }
Procedure LexScanStrDouble(Var T : TToken; SL, SC : Integer);
Var
  S    : TString;
  C    : Char;
  IV   : LongInt;
  VN   : TString;
  Done : Boolean;
Begin
  LexAdvance; { guillemet-double ouverture }
  S    := '';
  Done := False;
  Repeat
    If LexColNo > Length(LexLine) Then
    Begin
      LexError('Chaine double-quote non fermee en fin de ligne');
      Done := True;
    End Else
    Begin
      C := LexCurChar;
      If Ord(C) = 34 Then
      Begin
        LexAdvance; Done := True;
      End Else If Ord(C) = 92 Then
      Begin
        LexAdvance;
        C := LexScanEscape(IV);
        If Length(S) < MAX_STR Then S := S + C;
      End Else If C = '$' Then
      Begin
        { Interpolation simple $var -> marque #1+nom+#2 }
        LexAdvance;
        VN := '';
        While (LexColNo <= Length(LexLine)) And IsAlNum(LexCurChar) Do
        Begin
          If Length(VN) < 30 Then VN := VN + LexCurChar;
          LexAdvance;
        End;
        If VN <> '' Then
        Begin
          If Length(S) < MAX_STR Then S := S + #1;
          If Length(S) + Length(VN) <= MAX_STR Then S := S + VN;
          If Length(S) < MAX_STR Then S := S + #2;
        End Else
          If Length(S) < MAX_STR Then S := S + '$';
      End Else
      Begin
        If Length(S) < MAX_STR Then S := S + C;
        LexAdvance;
      End;
    End;
  Until Done;
  MakeToken(T, TK_STRING, S, SL, SC);
End;

{ ---- LexScanOp : operateurs PHP (simples et composes) ----- }
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
         Else If P = '>' Then Begin S := '->'; LexAdvance; End
         Else If P = '=' Then Begin S := '-='; LexAdvance; End;
    '*': If P = '*' Then
         Begin
           S := '**'; LexAdvance;
           If LexCurChar = '=' Then Begin S := '**='; LexAdvance; End;
         End
         Else If P = '=' Then Begin S := '*='; LexAdvance; End;
    '/': If P = '=' Then Begin S := '/='; LexAdvance; End;
    '%': If P = '=' Then Begin S := '%='; LexAdvance; End;
    '.': If P = '=' Then Begin S := '.='; LexAdvance; End;
    '!': If P = '=' Then
         Begin
           S := '!='; LexAdvance;
           If LexCurChar = '=' Then Begin S := '!=='; LexAdvance; End;
         End;
    '=': If P = '=' Then
         Begin
           S := '=='; LexAdvance;
           If LexCurChar = '=' Then Begin S := '==='; LexAdvance; End;
         End
         Else If P = '>' Then Begin S := '=>'; LexAdvance; End;
    '<': If P = '=' Then
         Begin
           S := '<='; LexAdvance;
           If LexCurChar = '>' Then Begin S := '<=>'; LexAdvance; End;
         End
         Else If P = '<' Then
         Begin
           S := '<<'; LexAdvance;
           If LexCurChar = '=' Then Begin S := '<<='; LexAdvance; End;
         End;
    '>': If P = '=' Then Begin S := '>='; LexAdvance; End
         Else If P = '>' Then
         Begin
           S := '>>'; LexAdvance;
           If LexCurChar = '=' Then Begin S := '>>='; LexAdvance; End;
         End;
    '&': If P = '&' Then Begin S := '&&'; LexAdvance; End
         Else If P = '=' Then Begin S := '&='; LexAdvance; End;
    '|': If P = '|' Then Begin S := '||'; LexAdvance; End
         Else If P = '=' Then Begin S := '|='; LexAdvance; End;
    '^': If P = '=' Then Begin S := '^='; LexAdvance; End;
    ':': If P = ':' Then Begin S := '::'; LexAdvance; End;
    '?': If P = '?' Then
         Begin
           S := '??'; LexAdvance;
           If LexCurChar = '=' Then Begin S := '??='; LexAdvance; End;
         End;
  End;
  MakeToken(T, TK_OP, S, SL, SC);
End;

{ ---- LexScanPunct : caractere de ponctuation -------------- }
Procedure LexScanPunct(Var T : TToken; SL, SC : Integer);
Var
  S : TString;
Begin
  S := LexCurChar;
  LexAdvance;
  MakeToken(T, TK_PUNCT, S, SL, SC);
End;

{ ---- LexScanHeredoc : heredoc <<<LABEL et nowdoc <<<'LABEL' }
{ Le contenu est accumule tel quel (sans interpolation pour    }
{ nowdoc ; l''interpolation heredoc est traitee en ParsePrimary}
Procedure LexScanHeredoc(Var T : TToken; SL, SC : Integer);
Var
  Lbl      : TString;
  IsNowdoc : Boolean;
  S        : TString;
  LLen     : Integer;
Begin
  { Consommer les 3 '<' }
  LexAdvance; LexAdvance; LexAdvance;
  IsNowdoc := False;
  Lbl      := '';
  { Ignorer les espaces apres <<< }
  While (LexColNo <= Length(LexLine)) And (LexCurChar = ' ') Do LexAdvance;
  { Nowdoc : <<<'LABEL' }
  If (LexColNo <= Length(LexLine)) And (Ord(LexCurChar) = 39) Then
  Begin
    IsNowdoc := True;
    LexAdvance;  { guillemet-simple ouverture }
    While (LexColNo <= Length(LexLine)) And (Ord(LexCurChar) <> 39) Do
    Begin
      If Length(Lbl) < 30 Then Lbl := Lbl + LexCurChar;
      LexAdvance;
    End;
    If LexColNo <= Length(LexLine) Then LexAdvance; { guillemet-simple fermeture }
  End Else
  Begin
    { Heredoc : <<<LABEL }
    While (LexColNo <= Length(LexLine)) And IsAlNum(LexCurChar) Do
    Begin
      If Length(Lbl) < 30 Then Lbl := Lbl + LexCurChar;
      LexAdvance;
    End;
  End;
  If Lbl = '' Then
  Begin
    LexError('Heredoc: label manquant apres <<<');
    MakeToken(T, TK_STRING, '', SL, SC);
    Exit;
  End;
  { Passer a la premiere ligne de contenu (ignorer fin de ligne d''ouverture) }
  LexNextLine;
  S    := '';
  LLen := Length(Lbl);
  { Accumuler les lignes jusqu''au label de fermeture }
  While Not LexEOF Do
  Begin
    { Label de fermeture : la ligne commence exactement par Lbl puis ; ou espace }
    If (Length(LexLine) >= LLen) And
       (Copy(LexLine, 1, LLen) = Lbl) And
       ((Length(LexLine) = LLen) Or
        (LexLine[LLen + 1] = ';') Or
        (LexLine[LLen + 1] = ' ')) Then
    Begin
      { Positionner le curseur apres le label (laisse ';' pour le parseur) }
      LexColNo := LLen + 1;
      MakeToken(T, TK_STRING, S, SL, SC);
      Exit;
    End;
    { Heredoc avec interpolation : garder tel quel (simplifie) }
    If Length(S) + Length(LexLine) < MAX_STR Then S := S + LexLine;
    If Length(S) < MAX_STR Then S := S + #10;
    LexNextLine;
  End;
  LexError('Heredoc: label de fermeture "' + Lbl + '" introuvable en fin de fichier');
  MakeToken(T, TK_STRING, S, SL, SC);
End;

{ ---- LexNextToken : produire le prochain token ------------ }
Procedure LexNextToken(Var T : TToken);
Var
  SL, SC : Integer;
  C      : Char;
  S      : TString;
Begin
  LexSkipWS;
  If LexEOF Or (LexColNo > Length(LexLine)) Then
  Begin
    MakeToken(T, TK_EOF, '', LexLineNo, LexColNo);
    Exit;
  End;
  SL := LexLineNo;
  SC := LexColNo;
  C  := LexCurChar;
  { Variable PHP : $nom -> TK_VAR (Val = nom sans '$') }
  If C = '$' Then
  Begin
    LexAdvance;
    SC := LexColNo - 1;
    S  := '';
    If (Not LexEOF) And (LexColNo <= Length(LexLine)) And IsAlpha(LexCurChar) Then
    Begin
      While (Not LexEOF) And (LexColNo <= Length(LexLine)) And IsAlNum(LexCurChar) Do
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
    End;
    MakeToken(T, TK_VAR, S, SL, SC);
    Exit;
  End;
  { Identifiant ou mot-cle PHP }
  If IsAlpha(C) Then Begin LexScanIdent(T, SL, SC); Exit; End;
  { Litteraux numeriques }
  If IsDigit(C) Then Begin LexScanNumber(T, SL, SC); Exit; End;
  { Chaine simple-quote }
  If Ord(C) = 39 Then Begin LexScanStrSingle(T, SL, SC); Exit; End;
  { Chaine double-quote }
  If Ord(C) = 34 Then Begin LexScanStrDouble(T, SL, SC); Exit; End;
  { Heredoc/Nowdoc : <<< (detecter avant LexScanOp qui consomme '<') }
  If (C = '<') And (LexPeek = '<') And
     (LexColNo + 2 <= Length(LexLine)) And
     (LexLine[LexColNo + 2] = '<') Then
  Begin
    LexScanHeredoc(T, SL, SC); Exit;
  End;
  { Operateurs PHP }
  Case C Of
    '+','-','*','/','%','.',
    '!','=','<','>','&','|','^','~',
    ':','?': Begin LexScanOp(T, SL, SC); Exit; End;
  End;
  { Ponctuation }
  LexScanPunct(T, SL, SC);
End;

{ ---- LexInit : ouvrir le fichier et initialiser l''etat --- }
Procedure LexInit;
Begin
  LexOpened := False;
  Assign(LexSrcF, Opts.SrcFile);
  Reset(LexSrcF);
  If IOResult <> 0 Then
    FatalError('Impossible d''ouvrir: ' + Opts.SrcFile);
  LexOpened := True;
  LexEOF    := False;
  LexLineNo := 0;
  LexColNo  := 1;
  LexLine   := '';
  InPhpMode := False;
  LexNextLine;
  LexSkipToPhp;  { Sauter le texte HTML initial }
End;

{ ---- Fermeture lexeur ------------------------------------- }
Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
End;

{ ---- PrintToken : debug mode -d --------------------------- }
Procedure PrintToken(Const T : TToken);
Var
  KS : String[10];
  NS : TString;
Begin
  Case T.Kind Of
    TK_IDENT   : KS := 'IDENT  ';
    TK_KEYWORD : KS := 'KEYWORD';
    TK_VAR     : KS := 'VAR    ';
    TK_INTEGER : KS := 'INTEGER';
    TK_FLOAT   : KS := 'FLOAT  ';
    TK_STRING  : KS := 'STRING ';
    TK_OP      : KS := 'OP     ';
    TK_PUNCT   : KS := 'PUNCT  ';
    TK_EOF     : KS := 'EOF    ';
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
  End;
  WriteLn;
End;

{ ---- ParserAdvance : lire le prochain token du lexeur ----- }
Procedure ParserAdvance;
Begin
  LexNextToken(CurToken);
  If Opts.DebugTok Then
    PrintToken(CurToken);
End;

{ ============================================================
  TODO 03 - LITTERAUX ET CONSTANTES
  ============================================================ }

{ ---- ExprMakeImm : construire une valeur immediate -------- }
{ ATTENTION TP7 : ne pas retourner de Record - utiliser Var   }
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := AVal;
  Res.TypeIdx := ATypeIdx;
  Res.Offset  := 0;
End;

{ ---- ExprMakeNone : valeur invalide (void/erreur) --------- }
Procedure ExprMakeNone(Var Res : TExprVal);
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_UNKNOWN;
  Res.Offset  := 0;
End;

{ ---- LitEvalInt : convertir un token TK_INTEGER en valeur -- }
{ Handles : decimal, 0x hex, 0b binaire, 0o octal             }
{ (IntVal est deja calcule par LexScanNumber)                  }
Procedure LitEvalInt(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeImm(T.IntVal, TY_IDX_INT, Res);
End;

{ ---- LitEvalFloat : convertir TK_FLOAT -> int (trunc) ----- }
{ PHP cible 8086 : pas de FPU, les flottants sont tronques.   }
Procedure LitEvalFloat(Const T : TToken; Var Res : TExprVal);
Var
  IV : LongInt;
Begin
  IV := Trunc(T.FloatVal);
  ExprMakeImm(IV, TY_IDX_FLOAT, Res);
  WriteLn('PHP86:', T.Line, ':', T.Col,
          ': Avertissement: flottant tronque a ', IV,
          ' (pas de FPU sur 8086)');
  Inc(WarnCount);
End;

{ ---- LitEvalBool : true / TRUE / false / FALSE / null / NULL }
Procedure LitEvalBool(Const T : TToken; Var Res : TExprVal);
Begin
  If (T.Val = 'true') Or (T.Val = 'TRUE') Then
    ExprMakeImm(1, TY_IDX_BOOL, Res)
  Else If (T.Val = 'false') Or (T.Val = 'FALSE') Then
    ExprMakeImm(0, TY_IDX_BOOL, Res)
  Else { null / NULL }
    ExprMakeImm(0, TY_IDX_NULL, Res);
End;

{ ---- LitEval : dispatcher principal pour les litteraux ----- }
{ Types de tokens acceptes : TK_INTEGER, TK_FLOAT, TK_STRING, }
{ TK_KEYWORD (true/false/null).                               }
{ Pour TK_STRING : stubbed jusqu''a TODO 08 (DataAdd).        }
Procedure LitEval(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeNone(Res);  { valeur par defaut }
  Case T.Kind Of
    TK_INTEGER : LitEvalInt(T, Res);
    TK_FLOAT   : LitEvalFloat(T, Res);
    TK_STRING  :
    Begin
      Res.Kind    := EK_MEM;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_STRING;
      Res.Offset  := DataAddStr(T.Val);
    End;
    TK_KEYWORD :
    Begin
      If (T.Val = 'true')  Or (T.Val = 'TRUE')  Or
         (T.Val = 'false') Or (T.Val = 'FALSE') Or
         (T.Val = 'null')  Or (T.Val = 'NULL') Then
        LitEvalBool(T, Res)
      Else
      Begin
        WriteLn('PHP86:', T.Line, ':', T.Col,
                ': Erreur: mot-cle non utilisable comme litteral : ', T.Val);
        Inc(ErrorCount);
      End;
    End;
  Else
    WriteLn('PHP86:', T.Line, ':', T.Col,
            ': Erreur: token non litterale : ', T.Val);
    Inc(ErrorCount);
  End;
End;

{ ============================================================
  TODO 04 - OPERATEURS ET PRECEDENCE
  ============================================================ }

{ ---- EmitOpen : ouvrir le fichier de sortie en ecriture ----- }
Procedure EmitOpen;
Begin
  Assign(OutF, Opts.OutFile);
  {$I-}
  Rewrite(OutF);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WriteLn('PHP86: Erreur - impossible de creer ', Opts.OutFile);
    Inc(ErrorCount);
    OutFOpen := False;
    Exit;
  End;
  OutFOpen := True;
End;

{ ---- EmitBlankLine : ligne vide dans le fichier de sortie ---- }
Procedure EmitBlankLine;
Begin
  If OutFOpen Then WriteLn(OutF);
End;

{ ---- EmitRaw : ligne brute sans indentation ------------------ }
Procedure EmitRaw(Const S : TString);
Begin
  If OutFOpen Then WriteLn(OutF, S);
End;

{ ---- EmitInstr : instruction indentee (TAB mnem TAB ops) ----- }
Procedure EmitInstr(Const Mnem, Ops : TString);
Begin
  If Not OutFOpen Then Exit;
  If Ops <> '' Then WriteLn(OutF, #9, Mnem, #9, Ops)
  Else WriteLn(OutF, #9, Mnem);
End;

{ ---- EmitLabel : etiquette suivie de ':' --------------------- }
Procedure EmitLabel(Const Lbl : TString);
Begin
  If OutFOpen Then WriteLn(OutF, Lbl, ':');
End;

{ ---- EmitComment : commentaire ASM (prefixe '; ') ------------ }
Procedure EmitComment(Const Msg : TString);
Begin
  If OutFOpen Then WriteLn(OutF, '; ', Msg);
End;

{ ---- Generateur de label unique ---------------------------}
Function NextLabelSeq : TString;
Var S : TString;
Begin
  Inc(LabelSeq);
  Str(LabelSeq, S);
  NextLabelSeq := PH_LBL_PFX + S;
End;

{ ---- BinOpPrec : table de precedences PHP (echelle Pratt) -
  Retourne 0 si l'operateur n'est pas binaire.
  Niveaux (ordre croissant = priorite croissante) :
    or          -> 1     xor         -> 2     and         -> 3
    ??          -> 4     (null-coalesce, droit-associatif)
    ||          -> 5     &&          -> 6
    |           -> 7     ^           -> 8     &           -> 9
    == != === !== <=> -> 10
    < <= > >=   -> 11
    << >>       -> 12
    . + -       -> 13   (concat et addition)
    * / %       -> 14
    **          -> 15   (puissance, droit-associatif)       }
Function BinOpPrec(Const Op : TString) : Integer;
Begin
  If   Op = 'or'                                        Then BinOpPrec := 1
  Else If Op = 'xor'                                    Then BinOpPrec := 2
  Else If Op = 'and'                                    Then BinOpPrec := 3
  Else If Op = '??'                                     Then BinOpPrec := 4
  Else If Op = '||'                                     Then BinOpPrec := 5
  Else If Op = '&&'                                     Then BinOpPrec := 6
  Else If Op = '|'                                      Then BinOpPrec := 7
  Else If Op = '^'                                      Then BinOpPrec := 8
  Else If Op = '&'                                      Then BinOpPrec := 9
  Else If (Op = '==')  Or (Op = '!=')
       Or (Op = '===') Or (Op = '!==')
       Or (Op = '<=>')                                  Then BinOpPrec := 10
  Else If (Op = '<')  Or (Op = '<=')
       Or (Op = '>')  Or (Op = '>=')                   Then BinOpPrec := 11
  Else If (Op = '<<') Or (Op = '>>')                   Then BinOpPrec := 12
  Else If (Op = '.') Or (Op = '+') Or (Op = '-')       Then BinOpPrec := 13
  Else If (Op = '*') Or (Op = '/') Or (Op = '%')       Then BinOpPrec := 14
  Else If Op = '**'                                     Then BinOpPrec := 15
  Else                                                       BinOpPrec := 0;
End;

{ ---- IsRightAssoc : vrai si operateur droit-associatif --- }
Function IsRightAssoc(Const Op : TString) : Boolean;
Begin
  IsRightAssoc := (Op = '**') Or (Op = '??');
End;

{ ---- ExprLoad : materialiser la valeur dans AX ---------- }
Procedure ExprLoad(Var E : TExprVal);
Var S : TString;
Begin
  Case E.Kind Of
    EK_IMM  : Begin
                Str(E.ImmVal, S);
                EmitInstr('MOV', 'AX, ' + S);
                E.Kind := EK_AX;
              End;
    EK_MEM  : Begin
                { Chaine litterale : Offset = index DataTab -> OFFSET label }
                If E.TypeIdx = TY_IDX_STRING Then
                Begin
                  If (E.Offset >= 0) And (E.Offset < DataCount) Then
                    EmitInstr('MOV', 'AX, OFFSET ' + DataTab[E.Offset].LblName)
                  Else
                    EmitInstr('XOR', 'AX, AX');
                End
                { Variable locale : [BP-n] }
                Else If E.Offset < 0 Then
                Begin
                  Str(-E.Offset, S);
                  EmitInstr('MOV', 'AX, [BP-' + S + ']');
                End
                { Variable parametre/frame : [BP+n] }
                Else
                Begin
                  Str(E.Offset, S);
                  EmitInstr('MOV', 'AX, [BP+' + S + ']');
                End;
                E.Kind := EK_AX;
              End;
    EK_AX   : ;
    EK_DXAX : ;
    EK_NONE : ;
  End;
End;

{ ---- ExprEmitBinOp : generer le code 8086 d'un operateur --
  Pliage de constantes si L et R sont EK_IMM.
{ ============================================================
  TODO 11 - EXPRESSIONS BINAIRES (PRATT)
  ============================================================ }

{ ---- ExprEmitBinOp : generer le code 8086 d'un operateur --
  Pliage de constantes si L et R sont EK_IMM.
  Operateurs PHP couverts :
    + - * / % ** (arith)   . (concat)
    == != === !== <=> < <= > >= (comparaison)
    && || & | ^ << >> (logique/bitwise, avec court-circuit && ||)
    and or xor (mots-cles logiques)                           }
Procedure ExprEmitBinOp(Const Op : TString; Var L : TExprVal; Var R : TExprVal);
Var
  RS   : TString;
  Lbl1 : TString;
  Lbl2 : TString;
  LblE : TString;
  Acc  : LongInt;
  Exp  : LongInt;
Begin
  { ---- Pliage de constantes -------------------------------- }
  If (L.Kind = EK_IMM) And (R.Kind = EK_IMM) Then
  Begin
    If      Op = '+'   Then L.ImmVal := L.ImmVal + R.ImmVal
    Else If Op = '-'   Then L.ImmVal := L.ImmVal - R.ImmVal
    Else If Op = '*'   Then L.ImmVal := L.ImmVal * R.ImmVal
    Else If Op = '/'   Then
    Begin
      If R.ImmVal = 0 Then Begin WriteLn('PHP86: erreur: division par zero'); Inc(ErrorCount); End
      Else L.ImmVal := L.ImmVal Div R.ImmVal;
    End
    Else If Op = '%'   Then
    Begin
      If R.ImmVal = 0 Then Begin WriteLn('PHP86: erreur: modulo par zero'); Inc(ErrorCount); End
      Else L.ImmVal := L.ImmVal Mod R.ImmVal;
    End
    Else If Op = '**'  Then
    Begin
      Acc := 1; Exp := R.ImmVal;
      If Exp < 0 Then L.ImmVal := 0
      Else Begin
        While Exp > 0 Do Begin Acc := Acc * L.ImmVal; Dec(Exp); End;
        L.ImmVal := Acc;
      End;
    End
    Else If Op = '.'   Then L.ImmVal := 0  { concat de constantes : non supporte en IMM }
    Else If Op = '&'   Then L.ImmVal := L.ImmVal And R.ImmVal
    Else If Op = '|'   Then L.ImmVal := L.ImmVal Or  R.ImmVal
    Else If Op = '^'   Then L.ImmVal := L.ImmVal Xor R.ImmVal
    Else If Op = '<<'  Then L.ImmVal := L.ImmVal Shl Integer(R.ImmVal And 15)
    Else If Op = '>>'  Then L.ImmVal := L.ImmVal Shr Integer(R.ImmVal And 15)
    Else If Op = '=='  Then Begin If L.ImmVal =  R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '!='  Then Begin If L.ImmVal <> R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '===' Then Begin If L.ImmVal =  R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '!==' Then Begin If L.ImmVal <> R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '<'   Then Begin If L.ImmVal <  R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '<='  Then Begin If L.ImmVal <= R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '>'   Then Begin If L.ImmVal >  R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '>='  Then Begin If L.ImmVal >= R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '<=>' Then
    Begin
      If L.ImmVal < R.ImmVal Then L.ImmVal := -1
      Else If L.ImmVal > R.ImmVal Then L.ImmVal := 1
      Else L.ImmVal := 0;
    End
    Else If Op = '&&' Then Begin If (L.ImmVal<>0) And (R.ImmVal<>0) Then L.ImmVal:=1 Else L.ImmVal:=0; End
    Else If Op = '||' Then Begin If (L.ImmVal<>0) Or  (R.ImmVal<>0) Then L.ImmVal:=1 Else L.ImmVal:=0; End
    Else If Op = 'and'Then Begin If (L.ImmVal<>0) And (R.ImmVal<>0) Then L.ImmVal:=1 Else L.ImmVal:=0; End
    Else If Op = 'or' Then Begin If (L.ImmVal<>0) Or  (R.ImmVal<>0) Then L.ImmVal:=1 Else L.ImmVal:=0; End
    Else If Op = 'xor'Then
    Begin
      If ((L.ImmVal<>0) And (R.ImmVal=0)) Or ((L.ImmVal=0) And (R.ImmVal<>0)) Then
        L.ImmVal := 1 Else L.ImmVal := 0;
    End;
    L.TypeIdx := TY_IDX_INT;
    Exit;
  End;

  { ---- Court-circuit && ------------------------------------ }
  { AX = L; si 0 -> sauter R, resultat 0                      }
  If (Op = '&&') Or (Op = 'and') Then
  Begin
    LblE := SymNewLabel('SCAND');
    ExprLoad(L);
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('JZ',   LblE);
    ExprLoad(R);
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('MOV',  'AX, 0');
    EmitInstr('SETNE','AL');
    EmitLabel(LblE);
    L.Kind := EK_AX; L.TypeIdx := TY_IDX_BOOL;
    Exit;
  End;

  { ---- Court-circuit || ------------------------------------ }
  If (Op = '||') Or (Op = 'or') Then
  Begin
    LblE := SymNewLabel('SCOR');
    ExprLoad(L);
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('JNZ',  LblE);   { deja vrai : sauter R }
    ExprLoad(R);
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('MOV',  'AX, 0');
    EmitInstr('SETNE','AL');
    EmitLabel(LblE);
    L.Kind := EK_AX; L.TypeIdx := TY_IDX_BOOL;
    Exit;
  End;

  { ---- XOR logique ----------------------------------------- }
  If Op = 'xor' Then
  Begin
    ExprLoad(L);
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('MOV',  'BX, 0');
    EmitInstr('SETNE','BL');     { BL = (L<>0) }
    ExprLoad(R);
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('MOV',  'AX, 0');
    EmitInstr('SETNE','AL');     { AL = (R<>0) }
    EmitInstr('XOR',  'AX, BX');
    L.Kind := EK_AX; L.TypeIdx := TY_IDX_BOOL;
    Exit;
  End;

  { ---- Cas general : emission 8086 ------------------------- }
  ExprLoad(L);
  If R.Kind = EK_IMM Then
  Begin
    Str(R.ImmVal, RS);
    If      Op = '+'   Then EmitInstr('ADD',  'AX, ' + RS)
    Else If Op = '-'   Then EmitInstr('SUB',  'AX, ' + RS)
    Else If Op = '&'   Then EmitInstr('AND',  'AX, ' + RS)
    Else If Op = '|'   Then EmitInstr('OR',   'AX, ' + RS)
    Else If Op = '^'   Then EmitInstr('XOR',  'AX, ' + RS)
    Else If Op = '<<'  Then
    Begin
      EmitInstr('MOV', 'CL, ' + RS);
      EmitInstr('SHL', 'AX, CL');
    End
    Else If Op = '>>'  Then
    Begin
      EmitInstr('MOV', 'CL, ' + RS);
      EmitInstr('SAR', 'AX, CL');
    End
    Else If Op = '*'   Then EmitInstr('IMUL', RS)
    Else If Op = '**'  Then
    Begin
      EmitInstr('MOV',  'CX, ' + RS);
      EmitInstr('CALL', PH_RT_PFX + 'POWER');
    End
    Else If Op = '/'  Then
    Begin
      EmitInstr('MOV', 'BX, ' + RS);
      EmitInstr('CWD', '');
      EmitInstr('IDIV', 'BX');
    End
    Else If Op = '%'  Then
    Begin
      EmitInstr('MOV', 'BX, ' + RS);
      EmitInstr('CWD', '');
      EmitInstr('IDIV', 'BX');
      EmitInstr('MOV', 'AX, DX');
    End
    Else If Op = '.'  Then
    Begin
      { Concat : AX = dst (ptr chaine gauche), immediat non supporte ici }
      EmitInstr('MOV', 'SI, AX');
      EmitInstr('MOV', 'DI, ' + RS);
      EmitInstr('CALL', PH_RT_PFX + 'CONCAT');
    End
    Else If Op = '==' Then Begin EmitInstr('CMP','AX, '+RS); EmitInstr('MOV','AX, 0'); EmitInstr('SETE','AL'); End
    Else If Op = '!=' Then Begin EmitInstr('CMP','AX, '+RS); EmitInstr('MOV','AX, 0'); EmitInstr('SETNE','AL'); End
    Else If Op = '==='Then Begin EmitInstr('CMP','AX, '+RS); EmitInstr('MOV','AX, 0'); EmitInstr('SETE','AL'); End
    Else If Op = '!=='Then Begin EmitInstr('CMP','AX, '+RS); EmitInstr('MOV','AX, 0'); EmitInstr('SETNE','AL'); End
    Else If Op = '<'  Then Begin EmitInstr('CMP','AX, '+RS); EmitInstr('MOV','AX, 0'); EmitInstr('SETL','AL'); End
    Else If Op = '<=' Then Begin EmitInstr('CMP','AX, '+RS); EmitInstr('MOV','AX, 0'); EmitInstr('SETLE','AL'); End
    Else If Op = '>'  Then Begin EmitInstr('CMP','AX, '+RS); EmitInstr('MOV','AX, 0'); EmitInstr('SETG','AL'); End
    Else If Op = '>=' Then Begin EmitInstr('CMP','AX, '+RS); EmitInstr('MOV','AX, 0'); EmitInstr('SETGE','AL'); End
    Else If Op = '<=>'Then
    Begin
      Lbl1 := SymNewLabel('CMPLT'); Lbl2 := SymNewLabel('CMPGT'); LblE := SymNewLabel('CMPEND');
      EmitInstr('CMP',  'AX, ' + RS);
      EmitInstr('JL',   Lbl1);  EmitInstr('JG',  Lbl2);
      EmitInstr('MOV',  'AX, 0'); EmitInstr('JMP', LblE);
      EmitLabel(Lbl1); EmitInstr('MOV','AX, -1'); EmitInstr('JMP', LblE);
      EmitLabel(Lbl2); EmitInstr('MOV','AX, 1');
      EmitLabel(LblE);
    End;
  End
  Else
  Begin
    { R non immediat : sauvegarder L dans la pile, charger R dans BX }
    EmitInstr('PUSH', 'AX');
    ExprLoad(R);
    EmitInstr('MOV',  'BX, AX');
    EmitInstr('POP',  'AX');
    If      Op = '+'  Then EmitInstr('ADD',  'AX, BX')
    Else If Op = '-'  Then EmitInstr('SUB',  'AX, BX')
    Else If Op = '&'  Then EmitInstr('AND',  'AX, BX')
    Else If Op = '|'  Then EmitInstr('OR',   'AX, BX')
    Else If Op = '^'  Then EmitInstr('XOR',  'AX, BX')
    Else If Op = '<<' Then Begin EmitInstr('MOV','CX, BX'); EmitInstr('SHL','AX, CL'); End
    Else If Op = '>>' Then Begin EmitInstr('MOV','CX, BX'); EmitInstr('SAR','AX, CL'); End
    Else If Op = '*'  Then EmitInstr('IMUL', 'BX')
    Else If Op = '**' Then
    Begin
      EmitInstr('XCHG', 'AX, BX');  { AX=base, BX=exp -> swap pour POWER }
      EmitInstr('MOV',  'CX, BX');
      EmitInstr('MOV',  'AX, AX');
      EmitInstr('CALL', PH_RT_PFX + 'POWER');
    End
    Else If Op = '/'  Then Begin EmitInstr('CWD',''); EmitInstr('IDIV','BX'); End
    Else If Op = '%'  Then Begin EmitInstr('CWD',''); EmitInstr('IDIV','BX'); EmitInstr('MOV','AX, DX'); End
    Else If Op = '.'  Then
    Begin
      { Concat : AX=dst (gauche), BX=src (droite) }
      EmitInstr('MOV',  'SI, AX');
      EmitInstr('MOV',  'DI, BX');
      EmitInstr('CALL', PH_RT_PFX + 'CONCAT');
    End
    Else
    Begin
      EmitInstr('CMP', 'AX, BX');
      EmitInstr('MOV', 'AX, 0');
      If      Op = '===' Then EmitInstr('SETE','AL')
      Else If Op = '=='  Then EmitInstr('SETE','AL')
      Else If Op = '!==' Then EmitInstr('SETNE','AL')
      Else If Op = '!='  Then EmitInstr('SETNE','AL')
      Else If Op = '<'   Then EmitInstr('SETL','AL')
      Else If Op = '<='  Then EmitInstr('SETLE','AL')
      Else If Op = '>'   Then EmitInstr('SETG','AL')
      Else If Op = '>='  Then EmitInstr('SETGE','AL')
      Else If Op = '<=>' Then
      Begin
        Lbl1 := SymNewLabel('CMPLT'); Lbl2 := SymNewLabel('CMPGT'); LblE := SymNewLabel('CMPEND');
        EmitInstr('JL',  Lbl1);  EmitInstr('JG',  Lbl2);
        EmitInstr('MOV', 'AX, 0'); EmitInstr('JMP', LblE);
        EmitLabel(Lbl1); EmitInstr('MOV','AX, -1'); EmitInstr('JMP', LblE);
        EmitLabel(Lbl2); EmitInstr('MOV','AX, 1');
        EmitLabel(LblE);
      End;
    End;
  End;
  L.Kind := EK_AX;
End;

{ ---- Forward declarations -------------------------------- }
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal); Forward;

{ ============================================================
  TODO 10 - EXPRESSIONS PRIMAIRES
  ============================================================ }

{ ---- ParsePrimary : atome du parseur Pratt ----------------- }
{ Gere : literaux, $var, ++/-- pre/post, casts, groupement () }
Procedure ParsePrimary(Var Res : TExprVal);
Var
  Idx     : Integer;
  VNm     : TString;
  OfsStr  : TString;
  CastKw  : TString;
  E       : TExprVal;
  { TODO 21 : acces objet }
  MembNm  : TString;
  ClsNm   : TString;
  ClsIdx2 : Integer;
  PropOff2: Integer;
  ArgCnt2 : Integer;
  J       : Integer;
Begin
  ExprMakeNone(Res);
  Case CurToken.Kind Of

    { ---- Identificateur : appel de fonction ou builtin ---- }
    TK_IDENT :
    Begin
      VNm := CurToken.Val;
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        { Appel de fonction : name(args...) }
        ParseCallExpr(VNm, Res);
      End
      Else
      Begin
        { Identifiant simple sans appel : warning + EK_NONE }
        WriteLn('PHP86:', CurToken.Line, ': avert: identifiant ''', VNm, ''' utilise comme expression (non-supporte)');
        Inc(WarnCount);
        ExprMakeNone(Res);
      End;
    End;

    { ---- Litteraux entier / flottant / chaine ---- }
    TK_INTEGER : Begin LitEvalInt(CurToken, Res);    ParserAdvance; End;
    TK_FLOAT   : Begin LitEvalFloat(CurToken, Res);  ParserAdvance; End;
    TK_STRING  : Begin LitEval(CurToken, Res);       ParserAdvance; End;

    { ---- Variable $var ---- }
    TK_VAR :
    Begin
      VNm := CurToken.Val;
      ParserAdvance;
      { pre-increment/decrement deja traite dans TK_OP }
      Idx := SymFind(VNm);
      If Idx < 0 Then
        Idx := AllocLocal(VNm, TY_IDX_MIXED, CurToken.Line);
      { Charger la valeur : local -> EK_MEM, global -> EK_AX }
      If (SymTab[Idx].Cat = SC_VAR) Or (SymTab[Idx].Cat = SC_PARAM) Then
      Begin
        Res.Kind    := EK_MEM;
        Res.Offset  := SymTab[Idx].Offset;
        Res.TypeIdx := SymTab[Idx].TypeIdx;
        Res.ImmVal  := 0;
      End
      Else
      Begin
        VarLoadToAX(Idx);
        Res.Kind    := EK_AX;
        Res.TypeIdx := SymTab[Idx].TypeIdx;
        Res.Offset  := 0;
        Res.ImmVal  := 0;
      End;
      { Post-increment/decrement : $var++ ou $var-- }
      If CurToken.Kind = TK_OP Then
      Begin
        If CurToken.Val = '++' Then
        Begin
          ExprLoad(Res);   { AX = valeur courante (vraie retournee) }
          EmitInstr('PUSH', 'AX');   { sauvegarder l''ancienne valeur }
          EmitInstr('INC', 'AX');
          VarStore(Idx);
          EmitInstr('POP', 'AX');    { restaurer l''ancienne valeur }
          Res.Kind := EK_AX;
          ParserAdvance;
        End
        Else If CurToken.Val = '--' Then
        Begin
          ExprLoad(Res);
          EmitInstr('PUSH', 'AX');
          EmitInstr('DEC', 'AX');
          VarStore(Idx);
          EmitInstr('POP', 'AX');
          Res.Kind := EK_AX;
          ParserAdvance;
        End;
      End;
      { Acces tableau : $a[indice] }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[') Then
      Begin
        ParserAdvance;  { consommer '[' }
        ParseExprPrec(1, E);   { evaluer l''indice dans E }
        ExprLoad(Res);  { AX = base ptr du tableau }
        EmitInstr('MOV', 'SI, AX');
        ExprLoad(E);    { AX = valeur de l''indice }
        EmitInstr('MOV', 'BX, AX');
        EmitInstr('SHL', 'BX, 1');          { BX = indice * 2 }
        EmitInstr('MOV', 'AX, [SI+BX+2]'); { +2 pour sauter le mot count }
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_MIXED;
        Res.Offset  := 0;
        Res.ImmVal  := 0;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
          ParserAdvance;
      End;
      { Acces membre objet : $obj->prop ou $obj->method() }
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '->') Then
      Begin
        ExprLoad(Res);
        EmitInstr('MOV', 'SI, AX');
        ParserAdvance;  { consommer '->' }
        If CurToken.Kind = TK_IDENT Then
        Begin
          MembNm := CurToken.Val;
          ParserAdvance;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          Begin
            { Appel de methode : $obj->method(args) }
            If SymTab[Idx].TypeIdx >= TY_PRIM_COUNT Then
              ClsIdx2 := SymTab[Idx].TypeIdx - TY_PRIM_COUNT
            Else
              ClsIdx2 := -1;
            If (ClsIdx2 >= 0) And (ClsIdx2 < ClassCount) Then
              ClsNm := ClassTab[ClsIdx2].ClsName
            Else
              ClsNm := SymTab[Idx].MangledName;
            ParserAdvance;  { consommer '(' }
            ArgCnt2 := 0;
            While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')'))
                  And (CurToken.Kind <> TK_EOF) Do
            Begin
              ParseExprPrec(1, E);
              ExprLoad(E);
              EmitInstr('PUSH', 'AX');
              Inc(ArgCnt2);
              If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
                ParserAdvance;
            End;
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance;
            EmitInstr('PUSH', 'SI');   { $this en dernier }
            EmitInstr('CALL', PH_FN_PFX + ClsNm + '__' + MembNm);
            Str((ArgCnt2 + 1) * 2, OfsStr);
            EmitInstr('ADD', 'SP, ' + OfsStr);
          End
          Else
          Begin
            { Acces propriete : chercher l''offset dans ClassTab }
            PropOff2 := 0;
            If SymTab[Idx].TypeIdx >= TY_PRIM_COUNT Then
            Begin
              ClsIdx2 := SymTab[Idx].TypeIdx - TY_PRIM_COUNT;
              If (ClsIdx2 >= 0) And (ClsIdx2 < ClassCount) Then
                For J := 0 To ClassTab[ClsIdx2].PropCount - 1 Do
                  If ClassTab[ClsIdx2].Props[J].PropName = MembNm Then
                  Begin
                    PropOff2 := ClassTab[ClsIdx2].Props[J].PropOff;
                    Break;
                  End;
            End;
            Str(PropOff2, OfsStr);
            EmitInstr('MOV', 'AX, [SI+' + OfsStr + ']');
          End;
          Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_MIXED;
          Res.Offset := 0; Res.ImmVal := 0;
        End
        Else
        Begin
          WriteLn('PHP86:', CurToken.Line, ': erreur: membre attendu apres ->');
          Inc(ErrorCount);
          ExprMakeNone(Res);
        End;
      End;
    End;

    { ---- Mots-cles litteraux : true false null array isset empty ---- }
    TK_KEYWORD :
    Begin
      If (CurToken.Val = 'true')  Or (CurToken.Val = 'TRUE')  Or
         (CurToken.Val = 'false') Or (CurToken.Val = 'FALSE') Or
         (CurToken.Val = 'null')  Or (CurToken.Val = 'NULL') Then
      Begin
        LitEvalBool(CurToken, Res); ParserAdvance;
      End Else If (CurToken.Val = 'array') Or (CurToken.Val = 'Array') Then
        ParseArrayLit(Res)
      Else If CurToken.Val = 'isset' Then
      Begin
        { isset($v) -> AX = 1 si variable definie et != 0, 0 sinon }
        ParserAdvance;  { consommer 'isset' }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          ParserAdvance;
        If CurToken.Kind = TK_VAR Then
        Begin
          Idx := SymFind(CurToken.Val);
          If Idx < 0 Then
          Begin
            EmitInstr('MOV', 'AX, 0');  { variable inconnue -> false }
            ParserAdvance;
          End
          Else
          Begin
            ParseExprPrec(1, E); { charger la variable }
            ExprLoad(E);
            EmitInstr('TEST', 'AX, AX');
            EmitInstr('MOV',  'AX, 0');
            EmitInstr('SETNE','AL');
          End;
        End
        Else
        Begin
          ParseExprPrec(1, E); ExprLoad(E);
          EmitInstr('TEST', 'AX, AX');
          EmitInstr('MOV',  'AX, 0');
          EmitInstr('SETNE','AL');
        End;
        While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) And
              (CurToken.Kind <> TK_EOF) Do ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_BOOL;
        Res.Offset := 0; Res.ImmVal := 0;
      End Else If CurToken.Val = 'empty' Then
      Begin
        { empty($v) -> AX = 1 si variable vaut 0/false/null, 0 sinon }
        ParserAdvance;  { consommer 'empty' }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          ParserAdvance;
        ParseExprPrec(1, E); ExprLoad(E);
        While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) And
              (CurToken.Kind <> TK_EOF) Do ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        EmitInstr('TEST', 'AX, AX');
        EmitInstr('MOV',  'AX, 0');
        EmitInstr('SETE', 'AL');
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_BOOL;
        Res.Offset := 0; Res.ImmVal := 0;
      End Else If CurToken.Val = 'new' Then
      Begin
        { new ClassName(args) : allouer l''objet et appeler le constructeur }
        ParserAdvance;  { consommer 'new' }
        If CurToken.Kind = TK_IDENT Then
        Begin
          ClsNm := CurToken.Val;
          ParserAdvance;
          ParseNewExpr(ClsNm, Res);
        End
        Else
        Begin
          WriteLn('PHP86:', CurToken.Line, ': erreur: nom de classe attendu apres new');
          Inc(ErrorCount);
          ExprMakeNone(Res);
        End;
      End
      Else
      Begin
        WriteLn('PHP86:', CurToken.Line, ': erreur: expression attendue, mot-cle: ', CurToken.Val);
        Inc(ErrorCount); ParserAdvance;
      End;
    End;

    { ---- Operateurs unaires : - ! ~ ++$var --$var ---- }
    TK_OP :
    Begin
      If CurToken.Val = '-' Then
      Begin
        ParserAdvance; ParseExprPrec(14, Res);
        If Res.Kind = EK_IMM Then Res.ImmVal := -Res.ImmVal
        Else Begin ExprLoad(Res); EmitInstr('NEG', 'AX'); End;
      End
      Else If CurToken.Val = '+' Then
      Begin
        ParserAdvance; ParseExprPrec(14, Res);
        { unaire + : aucune operation, juste charger }
        If Res.Kind <> EK_IMM Then ExprLoad(Res);
      End
      Else If CurToken.Val = '!' Then
      Begin
        ParserAdvance; ParseExprPrec(14, Res);
        If Res.Kind = EK_IMM Then
        Begin
          If Res.ImmVal <> 0 Then Res.ImmVal := 0 Else Res.ImmVal := 1;
        End
        Else
        Begin
          ExprLoad(Res);
          EmitInstr('TEST', 'AX, AX');
          EmitInstr('MOV',  'AX, 0');
          EmitInstr('SETE', 'AL');
        End;
      End
      Else If CurToken.Val = '~' Then
      Begin
        ParserAdvance; ParseExprPrec(14, Res);
        If Res.Kind = EK_IMM Then Res.ImmVal := Not Res.ImmVal
        Else Begin ExprLoad(Res); EmitInstr('NOT', 'AX'); End;
      End
      Else If CurToken.Val = '++' Then
      Begin
        { Pre-increment : ++$var }
        ParserAdvance;
        If CurToken.Kind = TK_VAR Then
        Begin
          VNm := CurToken.Val;
          ParserAdvance;
          Idx := SymFind(VNm);
          If Idx < 0 Then Idx := AllocLocal(VNm, TY_IDX_MIXED, CurToken.Line);
          VarLoadToAX(Idx);
          EmitInstr('INC', 'AX');
          VarStore(Idx);
          Res.Kind    := EK_AX;
          Res.TypeIdx := SymTab[Idx].TypeIdx;
          Res.Offset  := 0;
          Res.ImmVal  := 0;
        End
        Else
        Begin
          WriteLn('PHP86:', CurToken.Line, ': erreur: $var attendu apres ++');
          Inc(ErrorCount);
          ExprMakeNone(Res);
        End;
      End
      Else If CurToken.Val = '--' Then
      Begin
        { Pre-decrement : --$var }
        ParserAdvance;
        If CurToken.Kind = TK_VAR Then
        Begin
          VNm := CurToken.Val;
          ParserAdvance;
          Idx := SymFind(VNm);
          If Idx < 0 Then Idx := AllocLocal(VNm, TY_IDX_MIXED, CurToken.Line);
          VarLoadToAX(Idx);
          EmitInstr('DEC', 'AX');
          VarStore(Idx);
          Res.Kind    := EK_AX;
          Res.TypeIdx := SymTab[Idx].TypeIdx;
          Res.Offset  := 0;
          Res.ImmVal  := 0;
        End
        Else
        Begin
          WriteLn('PHP86:', CurToken.Line, ': erreur: $var attendu apres --');
          Inc(ErrorCount);
          ExprMakeNone(Res);
        End;
      End
      Else
      Begin
        WriteLn('PHP86:', CurToken.Line, ': erreur: expression inattendue: ', CurToken.Val);
        Inc(ErrorCount); ParserAdvance;
      End;
    End;

    { ---- Groupement ( expr ) et casts ---- }
    TK_PUNCT :
    Begin
      If CurToken.Val = '(' Then
      Begin
        ParserAdvance;
        { Detecter un cast : (int) (float) (string) (bool) (array) }
        If CurToken.Kind = TK_KEYWORD Then
        Begin
          CastKw := CurToken.Val;
          If (CastKw = 'int')    Or (CastKw = 'float')  Or
             (CastKw = 'string') Or (CastKw = 'bool')   Or
             (CastKw = 'array')  Or (CastKw = 'object') Or
             (CastKw = 'unset') Then
          Begin
            ParserAdvance; { consommer le mot-cle de cast }
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            Begin
              ParserAdvance; { consommer ')' }
              ParseExprPrec(14, E);
              ExprLoad(E);
              { Effectuer la conversion }
              If CastKw = 'int' Then
              Begin
                { deja un entier ou converti en AX : rien a faire }
                Res.Kind    := EK_AX;
                Res.TypeIdx := TY_IDX_INT;
                Res.Offset  := 0;
                Res.ImmVal  := 0;
              End
              Else If CastKw = 'bool' Then
              Begin
                EmitInstr('TEST', 'AX, AX');
                EmitInstr('MOV',  'AX, 0');
                EmitInstr('SETNE','AL');
                Res.Kind    := EK_AX;
                Res.TypeIdx := TY_IDX_BOOL;
                Res.Offset  := 0;
                Res.ImmVal  := 0;
              End
              Else If CastKw = 'unset' Then
              Begin
                EmitInstr('XOR', 'AX, AX');
                Res.Kind    := EK_AX;
                Res.TypeIdx := TY_IDX_NULL;
                Res.Offset  := 0;
                Res.ImmVal  := 0;
              End
              Else
              Begin
                { (float) (string) (array) (object) : AX inchange, type change }
                Res.Kind    := EK_AX;
                If CastKw = 'float'  Then Res.TypeIdx := TY_IDX_FLOAT
                Else If CastKw = 'string' Then Res.TypeIdx := TY_IDX_STRING
                Else Res.TypeIdx := TY_IDX_MIXED;
                Res.Offset  := 0;
                Res.ImmVal  := 0;
              End;
              Exit; { eviter le groupement normal ci-dessous }
            End;
            { Pas de ')' apres le mot-cle -> revenir au groupement normal }
            { (ne peut pas reculer le token, on parse l''expression avec CastKw) }
            ExprMakeNone(Res);
            WriteLn('PHP86:', CurToken.Line, ': erreur: '')'' attendu apres cast');
            Inc(ErrorCount);
            Exit;
          End;
        End;
        { Groupement simple : ( expr ) }
        ParseExprPrec(1, Res);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance
        Else
        Begin
          WriteLn('PHP86:', CurToken.Line, ': erreur: '')'' manquant');
          Inc(ErrorCount);
        End;
      End Else If CurToken.Val = '[' Then
        ParseArrayLit(Res)
      Else
      Begin
        WriteLn('PHP86:', CurToken.Line, ': erreur: expression attendue: ', CurToken.Val);
        Inc(ErrorCount); ParserAdvance;
      End;
    End;

  Else
    WriteLn('PHP86:', CurToken.Line, ': erreur: expression attendue (token: ', CurToken.Val, ')');
    Inc(ErrorCount); ParserAdvance;
  End;
End;

{ ---- ParseExprPrec : boucle Pratt complete (TODO 11) ------ }
{ Gere : operateurs binaires, ternaire cond ? a : b, ??       }
Procedure ParseExprPrec; { corps du Forward : parametres MinPrec, Res utilises depuis la signature forward }
Var
  L     : TExprVal;
  R     : TExprVal;
  Alt   : TExprVal;
  Op    : TString;
  Prec  : Integer;
  LblElse : TString;
  LblEnd  : TString;
Begin
  ParsePrimary(L);
  { Boucle Pratt principale : operateurs TK_OP }
  While True Do
  Begin
    { ---- null-coalescing ?? ---- }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '??') Then
    Begin
      If BinOpPrec('??') < MinPrec Then Break;
      ParserAdvance;
      { Si L est IMM et vaut 0 (null) -> evaluer R }
      If L.Kind = EK_IMM Then
      Begin
        If L.ImmVal = 0 Then
        Begin
          ParseExprPrec(BinOpPrec('??'), R);
          L := R;
        End
        Else
          ParseExprPrec(BinOpPrec('??'), R);  { consommer R mais ignorer }
      End
      Else
      Begin
        { Emission : TEST AX, AX ; JNZ end ; evaluer R ; end: }
        LblEnd := SymNewLabel('NCEND');
        ExprLoad(L);
        EmitInstr('TEST', 'AX, AX');
        EmitInstr('JNZ',  LblEnd);
        ParseExprPrec(BinOpPrec('??'), R);
        ExprLoad(R);
        EmitLabel(LblEnd);
        L.Kind := EK_AX; L.TypeIdx := TY_IDX_MIXED;
      End;
      Continue;
    End;
    { ---- ternaire ? a : b ---- }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '?') Then
    Begin
      If 4 < MinPrec Then Break;  { precedence du ternaire = 4 }
      ParserAdvance;
      If L.Kind = EK_IMM Then
      Begin
        { Pliage : condition connue a la compilation }
        ParseExprPrec(1, R);     { branche then }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then ParserAdvance;
        ParseExprPrec(1, Alt);   { branche else }
        If L.ImmVal <> 0 Then L := R Else L := Alt;
      End
      Else
      Begin
        LblElse := SymNewLabel('TERN');
        LblEnd  := SymNewLabel('TERNEND');
        ExprLoad(L);
        EmitInstr('TEST', 'AX, AX');
        EmitInstr('JZ',   LblElse);
        ParseExprPrec(1, R);
        ExprLoad(R);
        EmitInstr('JMP',  LblEnd);
        EmitLabel(LblElse);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then ParserAdvance
        Else Begin WriteLn('PHP86:', CurToken.Line, ': erreur: '':'' attendu dans ternaire'); Inc(ErrorCount); End;
        ParseExprPrec(1, Alt);
        ExprLoad(Alt);
        EmitLabel(LblEnd);
        L.Kind := EK_AX; L.TypeIdx := TY_IDX_MIXED;
      End;
      Continue;
    End;
    { ---- operateurs binaires normaux ---- }
    If CurToken.Kind <> TK_OP Then Break;
    Op   := CurToken.Val;
    Prec := BinOpPrec(Op);
    If (Prec = 0) Or (Prec < MinPrec) Then Break;
    ParserAdvance;
    If IsRightAssoc(Op) Then
      ParseExprPrec(Prec, R)
    Else
      ParseExprPrec(Prec + 1, R);
    ExprEmitBinOp(Op, L, R);
  End;
  { ---- mots-cles binaires : and or xor ---- }
  While CurToken.Kind = TK_KEYWORD Do
  Begin
    Op   := CurToken.Val;
    Prec := BinOpPrec(Op);
    If Prec < MinPrec Then Break;
    If Prec = 0 Then Break;
    ParserAdvance;
    ParseExprPrec(Prec + 1, R);
    ExprEmitBinOp(Op, L, R);
  End;
  Res := L;
End;

{ ---- ParseExpr : point d''entree du parseur d''expressions }
Procedure ParseExpr(Var Res : TExprVal);
Begin
  ParseExprPrec(1, Res);
End;

{ ============================================================
  TODO 05 - TABLE DES SYMBOLES
  ============================================================ }

{ ---- SymInit : reinitialiser la table des symboles --------- }
Procedure SymInit;
Begin
  SymCount      := 0;
  ScopeTop      := 0;
  CurScope      := 0;
  LabelSeq      := 0;
  ScopeStack[0] := 0;
End;

{ ---- SymEnterScope : entrer dans une nouvelle portee ------- }
Procedure SymEnterScope;
Begin
  If ScopeTop >= MAX_SCOPE - 1 Then
  Begin
    LexError('Profondeur de portee maximale atteinte');
    Exit;
  End;
  Inc(CurScope);
  Inc(ScopeTop);
  ScopeStack[ScopeTop] := SymCount;
End;

{ ---- SymLeaveScope : quitter la portee courante ------------ }
{ Les symboles locaux (SC_VAR, SC_PARAM) sont retires.        }
Procedure SymLeaveScope;
Begin
  If ScopeTop <= 0 Then
  Begin
    LexError('Desequilibre de portees : LeaveScope sans EnterScope');
    Exit;
  End;
  SymCount := ScopeStack[ScopeTop];
  Dec(ScopeTop);
  Dec(CurScope);
End;

{ ---- SymMangle : construire l''etiquette ASM d''un symbole --
  SC_VAR    : variable locale -> pas d''etiquette (acces [BP-n])
  SC_GLOBAL : variable globale -> _PHV_ + name
  SC_PARAM  : parametre -> pas d''etiquette (acces [BP+n])
  SC_FN     : fonction -> _PHF_ + name
  SC_CLASS  : classe -> _PHF_ + name  (pour le constructeur)
  SC_CONST  : constante -> _PHV_ + name
  Remplace les caracteres non alphanumeriques par '_'.         }
Function SymMangle(ACat : TSymCat; Const AName : TString) : TString;
Var
  S : TString;
  I : Integer;
Begin
  S := AName;
  { Assainir : remplacer tout caractere non-ident par '_' }
  For I := 1 To Length(S) Do
    If Not (IsAlpha(S[I]) Or IsDigit(S[I])) Then S[I] := '_';
  Case ACat Of
    SC_VAR    : SymMangle := '';               { local : pas de label global }
    SC_GLOBAL : SymMangle := PH_VAR_PFX + S;
    SC_PARAM  : SymMangle := '';               { parametre : pas de label }
    SC_FN     : SymMangle := PH_FN_PFX  + S;
    SC_CLASS  : SymMangle := PH_FN_PFX  + S;  { constructeur de la classe }
    SC_CONST  : SymMangle := PH_VAR_PFX + S;
  Else
    SymMangle := PH_LBL_PFX + S;
  End;
End;

{ ---- SymAdd : enregistrer un symbole dans la table --------- }
{ Retourne l''index du symbole (0-base) ou -1 en cas d''erreur.}
{ AOffset : offset BP pour SC_VAR/SC_PARAM, 0 sinon.           }
{ AIsRef  : True pour un parametre passe par reference &$p.    }
Function SymAdd(Const AName : TString; ACat : TSymCat;
                ATypeIdx : Integer; AIsRef : Boolean;
                AOffset : Integer; ADeclLine : Integer) : Integer;
Var
  Idx : Integer;
  MN  : TString;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    LexError('Table des symboles pleine');
    SymAdd := -1;
    Exit;
  End;
  Idx := SymCount;
  SymTab[Idx].Name        := AName;
  SymTab[Idx].Cat         := ACat;
  SymTab[Idx].TypeIdx     := ATypeIdx;
  SymTab[Idx].ScopeLevel  := CurScope;
  SymTab[Idx].Offset      := AOffset;
  SymTab[Idx].IsRef       := AIsRef;
  SymTab[Idx].DeclLine    := ADeclLine;
  MN := SymMangle(ACat, AName);
  SymTab[Idx].MangledName := MN;
  Inc(SymCount);
  Inc(TotalSyms);
  SymAdd := Idx;
End;

{ ---- SymFindLocal : chercher dans la portee courante ------- }
{ Usages : detecter les redeclarations dans le meme scope.    }
{ Retourne l''index ou -1.                                    }
Function SymFindLocal(Const AName : TString) : Integer;
Var
  I     : Integer;
  Start : Integer;
Begin
  Start := ScopeStack[ScopeTop];
  For I := SymCount - 1 DownTo Start Do
    If SymTab[I].Name = AName Then
    Begin
      SymFindLocal := I;
      Exit;
    End;
  SymFindLocal := -1;
End;

{ ---- SymFind : chercher dans toutes les portees ------------ }
{ Retourne l''index du symbole le plus recent, ou -1.         }
Function SymFind(Const AName : TString) : Integer;
Var
  I : Integer;
Begin
  For I := SymCount - 1 DownTo 0 Do
    If SymTab[I].Name = AName Then
    Begin
      SymFind := I;
      Exit;
    End;
  SymFind := -1;
End;

{ ---- SymFindCat : chercher par categorie ------------------- }
Function SymFindCat(Const AName : TString; ACat : TSymCat) : Integer;
Var
  I : Integer;
Begin
  For I := SymCount - 1 DownTo 0 Do
    If (SymTab[I].Name = AName) And (SymTab[I].Cat = ACat) Then
    Begin
      SymFindCat := I;
      Exit;
    End;
  SymFindCat := -1;
End;

{ ---- SymNewLabel : generer un label interne unique ---------- }
Function SymNewLabel(Const Prefix : TString) : TString;
Var
  NS : TString;
Begin
  Inc(LabelSeq);
  Str(LabelSeq, NS);
  SymNewLabel := PH_LBL_PFX + Prefix + '_' + NS;
End;

{ ---- SymCatName : nom lisible d''une categorie (debug) ------ }
Function SymCatName(Cat : TSymCat) : TString;
Begin
  Case Cat Of
    SC_VAR    : SymCatName := 'var   ';
    SC_GLOBAL : SymCatName := 'global';
    SC_PARAM  : SymCatName := 'param ';
    SC_FN     : SymCatName := 'fn    ';
    SC_CLASS  : SymCatName := 'class ';
    SC_CONST  : SymCatName := 'const ';
  Else
    SymCatName := '?     ';
  End;
End;

{ ---- SymDump : afficher la table des symboles (mode -v) ---- }
Procedure SymDump;
Var
  I   : Integer;
  MN  : TString;
  OFS : String[8];
Begin
  WriteLn;
  WriteLn('--- Table des symboles PHP86 (', SymCount, ' entrees) ---');
  For I := 0 To SymCount - 1 Do
  Begin
    Str(SymTab[I].Offset, OFS);
    MN := SymTab[I].MangledName;
    If MN = '' Then
    Begin
      If SymTab[I].Offset >= 0 Then MN := '[BP+' + OFS + ']'
      Else MN := '[BP' + OFS + ']';
    End;
    Write('  [', I, '] sc=', SymTab[I].ScopeLevel,
          ' cat=', SymCatName(SymTab[I].Cat),
          ' ref=', SymTab[I].IsRef,
          ' line=', SymTab[I].DeclLine,
          ' $', SymTab[I].Name);
    If MN <> '' Then Write(' -> ', MN);
    WriteLn;
  End;
  WriteLn('---');
End;

{ ============================================================
  TODO 06 - SYSTEME DE TYPES PHP
  ============================================================ }

{ ---- TypeAddRec : enregistrer un type (usage interne) ------ }
{ Retourne l''index alloue ou -1 si table pleine.              }
Function TypeAddRec(AKind : TTypeKind; Const AName : TString;
                    ASize : Integer; AElemIdx : Integer;
                    AClassSz : Integer) : Integer;
Var
  Idx : Integer;
Begin
  If TypeCount >= MAX_TYPE Then
  Begin
    FatalError('Table de types pleine');
    TypeAddRec := -1;
    Exit;
  End;
  Idx := TypeCount;
  TypeTab[Idx].Kind    := AKind;
  TypeTab[Idx].Name    := AName;
  TypeTab[Idx].Size    := ASize;
  TypeTab[Idx].ElemIdx := AElemIdx;
  TypeTab[Idx].ClassSz := AClassSz;
  Inc(TypeCount);
  TypeAddRec := Idx;
End;

{ ---- TypeInit : enregistrer les types primitifs PHP -------- }
{ Doit etre appelee depuis SymInit / Run avant toute analyse.  }
{ Indices fixes : TY_IDX_INT=0 .. TY_IDX_VOID=6               }
{ Mapping 8086 :                                               }
{   int    = 2 octets (word, AX)                               }
{   float  = 4 octets (DX:AX)                                  }
{   string = 2 octets (pointeur near vers l''espace chaines)   }
{   bool   = 1 octet  (0=false, 1=true)                        }
{   null   = 0 octet  (pas de valeur sur la pile)              }
{   array  = 2 octets (pointeur vers tableau heap)             }
{   object = 2 octets (pointeur vers objet heap)               }
{   mixed  = 2 octets (valeur generique / taille AX)           }
{   void   = 0 octet  (aucune valeur de retour)                }
Procedure TypeInit;
Var
  I : Integer;
Begin
  TypeCount := 0;
  For I := 0 To MAX_TYPE - 1 Do
  Begin
    TypeTab[I].Kind    := TKD_UNKNOWN;
    TypeTab[I].Name    := '';
    TypeTab[I].Size    := 0;
    TypeTab[I].ElemIdx := TY_UNKNOWN;
    TypeTab[I].ClassSz := 0;
  End;
  { Indices fixes garantis par TY_IDX_* }
  TypeAddRec(TKD_INT,    'int',    2, TY_UNKNOWN, 0);  { TY_IDX_INT    = 0 }
  TypeAddRec(TKD_FLOAT,  'float',  4, TY_UNKNOWN, 0);  { TY_IDX_FLOAT  = 1 }
  TypeAddRec(TKD_STRING, 'string', 2, TY_UNKNOWN, 0);  { TY_IDX_STRING = 2 }
  TypeAddRec(TKD_BOOL,   'bool',   1, TY_UNKNOWN, 0);  { TY_IDX_BOOL   = 3 }
  TypeAddRec(TKD_NULL,   'null',   0, TY_UNKNOWN, 0);  { TY_IDX_NULL   = 4 }
  TypeAddRec(TKD_MIXED,  'mixed',  2, TY_UNKNOWN, 0);  { TY_IDX_MIXED  = 5 }
  TypeAddRec(TKD_VOID,   'void',   0, TY_UNKNOWN, 0);  { TY_IDX_VOID   = 6 }
  { TY_PRIM_COUNT = 7 : la suite peut accueillir des classes/tableaux }
End;

{ ---- TypeFind : chercher un type par nom ------------------- }
{ Retourne l''index ou TY_UNKNOWN.                             }
Function TypeFind(Const AName : TString) : Integer;
Var
  I : Integer;
Begin
  For I := 0 To TypeCount - 1 Do
    If TypeTab[I].Name = AName Then
    Begin
      TypeFind := I;
      Exit;
    End;
  TypeFind := TY_UNKNOWN;
End;

{ ---- TypeSizeof : taille en octets d''un type --------------- }
Function TypeSizeof(Idx : Integer) : Integer;
Begin
  If (Idx < 0) Or (Idx >= TypeCount) Then
    TypeSizeof := 2    { taille par defaut : word }
  Else
    TypeSizeof := TypeTab[Idx].Size;
End;

{ ---- TypeMangle : prefixe ASM utilise pour les labels ------ }
{ Utile pour distinguer methodes et variables de classe.       }
Function TypeMangle(Idx : Integer) : TString;
Var
  S : TString;
  J : Integer;
Begin
  If (Idx < 0) Or (Idx >= TypeCount) Or (TypeTab[Idx].Name = '') Then
  Begin
    TypeMangle := '_PHT_unknown';
    Exit;
  End;
  S := TypeTab[Idx].Name;
  { Assainir : remplacer les caracteres non-ident par '_' }
  For J := 1 To Length(S) Do
    If Not (IsAlpha(S[J]) Or IsDigit(S[J])) Then S[J] := '_';
  TypeMangle := '_PHT_' + S;
End;

{ ---- TypeIsNumeric : vrai si le type peut se placer dans AX -- }
{ int, bool, null et mixed sont tous representables dans AX.    }
Function TypeIsNumeric(Idx : Integer) : Boolean;
Begin
  If (Idx < 0) Or (Idx >= TypeCount) Then
  Begin
    TypeIsNumeric := False;
    Exit;
  End;
  Case TypeTab[Idx].Kind Of
    TKD_INT,
    TKD_BOOL,
    TKD_NULL   : TypeIsNumeric := True;
  Else
    TypeIsNumeric := False;
  End;
End;

{ ---- TypePromote : promotion bool/null -> int sur la pile --- }
{ Renvoie TY_IDX_INT si promotion necessaire, sinon Idx tel quel. }
{ Logique PHP : false/null=0, true=1 quand utilises en contexte  }
{ arithmetique.                                                  }
Function TypePromote(Idx : Integer) : Integer;
Begin
  If (Idx < 0) Or (Idx >= TypeCount) Then
  Begin
    TypePromote := TY_IDX_INT;
    Exit;
  End;
  Case TypeTab[Idx].Kind Of
    TKD_BOOL,
    TKD_NULL : TypePromote := TY_IDX_INT;
  Else
    TypePromote := Idx;
  End;
End;

{ ---- TypeKindName : nom lisible pour le debug -------------- }
Function TypeKindName(K : TTypeKind) : TString;
Begin
  Case K Of
    TKD_INT    : TypeKindName := 'int   ';
    TKD_FLOAT  : TypeKindName := 'float ';
    TKD_STRING : TypeKindName := 'string';
    TKD_BOOL   : TypeKindName := 'bool  ';
    TKD_NULL   : TypeKindName := 'null  ';
    TKD_ARRAY  : TypeKindName := 'array ';
    TKD_OBJECT : TypeKindName := 'object';
    TKD_MIXED  : TypeKindName := 'mixed ';
    TKD_VOID   : TypeKindName := 'void  ';
  Else
    TypeKindName := '?     ';
  End;
End;

{ ---- TypeDump : afficher la table de types (mode -v) ------- }
Procedure TypeDump;
Var
  I  : Integer;
  SZ : String[6];
Begin
  WriteLn;
  WriteLn('--- Table des types PHP86 (', TypeCount, ' entrees) ---');
  For I := 0 To TypeCount - 1 Do
  Begin
    Str(TypeTab[I].Size, SZ);
    Write('  [', I, '] kind=', TypeKindName(TypeTab[I].Kind),
          ' size=', SZ, 'o  name=', TypeTab[I].Name);
    If TypeTab[I].ElemIdx >= 0 Then
      Write(' elem=', TypeTab[I].ElemIdx);
    WriteLn;
  End;
  WriteLn('---');
End;

{ ============================================================
  TODO 07 - EMETTEUR DE CODE ASM
  ============================================================ }

{ ---- EmitHeader : en-tete MASM (.MODEL SMALL, _TEXT SEGMENT) - }
{ Doit etre appele juste apres EmitOpen, avant toute emission.  }
Procedure EmitHeader;
Var
  NS : TString;
Begin
  If Not OutFOpen Then Exit;
  WriteLn(OutF, '; Generated by PHP86 v', PHP86_VERSION,
                ' (', PHP86_DATE, ')');
  WriteLn(OutF, '; Source : ', Opts.SrcFile);
  WriteLn(OutF, '; Cible  : 8086 DOS (.MODEL SMALL)');
  Str(STACK_SIZE, NS);
  WriteLn(OutF, '; Pile   : ', NS, ' octets');
  WriteLn(OutF);
  WriteLn(OutF, '        .MODEL  SMALL');
  WriteLn(OutF, '        .STACK  ', NS);
  WriteLn(OutF);
  WriteLn(OutF, '_TEXT   SEGMENT PUBLIC ', #39, 'CODE', #39);
  WriteLn(OutF, '        ASSUME  CS:_TEXT');
  WriteLn(OutF);
End;

{ ---- EmitClose : fermer proprement le fichier de sortie ------ }
Procedure EmitClose;
Begin
  If OutFOpen Then
  Begin
    { Clore le segment TEXT si ouvert }
    EmitBlankLine;
    WriteLn(OutF, '_TEXT   ENDS');
    EmitDataSeg;
    WriteLn(OutF);
    WriteLn(OutF, '        END');
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ============================================================
  TODO 08 - SEGMENT DE DONNEES ET STATIQUES
  ============================================================ }

{ ---- DataAdd : enregistrer une entree dans DataTab ---------- }
{ Retourne l''index alloue ou -1 si table pleine.              }
Function DataAdd(Const ALbl : TString; AKind : TDataKind;
                 AInt : LongInt; Const AStr : TString) : Integer;
Var Idx : Integer;
Begin
  If DataCount >= MAX_DATA Then
  Begin
    FatalError('Table de donnees statiques pleine (MAX_DATA)');
    DataAdd := -1;
    Exit;
  End;
  Idx := DataCount;
  DataTab[Idx].LblName := ALbl;
  DataTab[Idx].Kind    := AKind;
  DataTab[Idx].IntVal  := AInt;
  DataTab[Idx].StrVal  := AStr;
  Inc(DataCount);
  DataAdd := Idx;
End;

{ ---- DataAddStr : creer une entree DK_STR pour une chaine --- }
{ Reutilise les doublons (meme contenu -> meme label).         }
{ Retourne l''index dans DataTab, utilise comme Offset EK_MEM. }
Function DataAddStr(Const S : TString) : Integer;
Var
  I   : Integer;
  Lbl : TString;
  NS  : TString;
Begin
  For I := 0 To DataCount - 1 Do
    If (DataTab[I].Kind = DK_STR) And (DataTab[I].StrVal = S) Then
    Begin
      DataAddStr := I;
      Exit;
    End;
  Inc(LabelSeq);
  Str(LabelSeq, NS);
  Lbl := PH_STR_PFX + NS;
  DataAddStr := DataAdd(Lbl, DK_STR, 0, S);
End;

{ ---- DataAddWord : enregistrer un mot (variable globale) ---- }
Function DataAddWord(Const ALbl : TString; AInit : LongInt) : Integer;
Begin
  DataAddWord := DataAdd(ALbl, DK_WORD, AInit, '');
End;

{ ---- EmitDataSeg : emettre le segment _DATA dans le .ASM --- }
{ Appele depuis EmitClose juste apres _TEXT ENDS, avant END.  }
Procedure EmitDataSeg;
Var
  I  : Integer;
  J  : Integer;
  B  : Byte;
  NS : String[6];
Begin
  If Not OutFOpen Then Exit;
  If DataCount = 0 Then Exit;
  WriteLn(OutF);
  WriteLn(OutF, '_DATA   SEGMENT PUBLIC ', #39, 'DATA', #39);
  WriteLn(OutF, '        ASSUME  DS:_DATA');
  For I := 0 To DataCount - 1 Do
  Begin
    WriteLn(OutF, DataTab[I].LblName, ':');
    Case DataTab[I].Kind Of
      DK_WORD :
      Begin
        Str(DataTab[I].IntVal, NS);
        WriteLn(OutF, '        DW      ', NS);
      End;
      DK_BYTE :
      Begin
        Str(DataTab[I].IntVal And $FF, NS);
        WriteLn(OutF, '        DB      ', NS);
      End;
      DK_STR  :
      Begin
        Write(OutF, '        DB      ');
        For J := 1 To Length(DataTab[I].StrVal) Do
        Begin
          B := Ord(DataTab[I].StrVal[J]);
          Str(B, NS);
          If J > 1 Then Write(OutF, ',');
          Write(OutF, NS);
        End;
        WriteLn(OutF, ',0');
      End;
    End;
  End;
  WriteLn(OutF, '_DATA   ENDS');
End;

{ ============================================================
  TODO 09 - VARIABLES ET AFFECTATIONS
  ============================================================ }

{ ---- AllocLocal : allouer une variable locale sur la pile -- }
{ Emet SUB SP,n ; enregistre dans SymTab (SC_VAR, offset<0).  }
{ Retourne l''index SymTab ou -1.                             }
Function AllocLocal(Const VarName : TString; TyIdx, DeclLine : Integer) : Integer;
Var
  VarSize : Integer;
  SZ      : TString;
Begin
  VarSize := TypeSizeof(TyIdx);
  If VarSize < 2 Then VarSize := 2;
  Dec(CurFrameSize, VarSize);
  Str(VarSize, SZ);
  EmitComment('local $' + VarName + ' [BP-' + SZ + ']');
  EmitInstr('SUB', 'SP, ' + SZ);
  AllocLocal := SymAdd(VarName, SC_VAR, TyIdx, False, CurFrameSize, DeclLine);
End;

{ ---- AllocGlobal : allouer une variable globale dans DATA -- }
{ Cree une entree DK_WORD (_PHV_name) et un symbole SC_GLOBAL. }
Function AllocGlobal(Const VarName : TString; TyIdx, DeclLine : Integer) : Integer;
Var
  Lbl  : TString;
  DIdx : Integer;
Begin
  Lbl  := PH_VAR_PFX + VarName;
  DIdx := DataAddWord(Lbl, 0);
  AllocGlobal := SymAdd(VarName, SC_GLOBAL, TyIdx, False, DIdx, DeclLine);
End;

{ ---- VarStore : stocker AX dans la variable d''indice Idx --- }
{ SC_VAR/SC_PARAM -> MOV [BP+-n], AX                          }
{ SC_GLOBAL/SC_CONST -> MOV [_PHV_name], AX                   }
Procedure VarStore(Idx : Integer);
Var
  OfsStr : TString;
Begin
  If (Idx < 0) Or (Idx >= SymCount) Then Exit;
  If (SymTab[Idx].Cat = SC_VAR) Or (SymTab[Idx].Cat = SC_PARAM) Then
  Begin
    If SymTab[Idx].Offset < 0 Then
    Begin
      Str(-SymTab[Idx].Offset, OfsStr);
      EmitInstr('MOV', '[BP-' + OfsStr + '], AX');
    End
    Else
    Begin
      Str(SymTab[Idx].Offset, OfsStr);
      EmitInstr('MOV', '[BP+' + OfsStr + '], AX');
    End;
  End
  Else If (SymTab[Idx].Cat = SC_GLOBAL) Or (SymTab[Idx].Cat = SC_CONST) Then
    EmitInstr('MOV', '[' + SymTab[Idx].MangledName + '], AX')
  Else
  Begin
    WriteLn('PHP86: VarStore: categorie non supportee pour $', SymTab[Idx].Name);
    Inc(ErrorCount);
  End;
End;

{ ---- VarLoadToAX : charger la variable d''indice Idx dans AX }
Procedure VarLoadToAX(Idx : Integer);
Var
  OfsStr : TString;
Begin
  If (Idx < 0) Or (Idx >= SymCount) Then
  Begin
    EmitInstr('XOR', 'AX, AX');
    Exit;
  End;
  If (SymTab[Idx].Cat = SC_VAR) Or (SymTab[Idx].Cat = SC_PARAM) Then
  Begin
    If SymTab[Idx].Offset < 0 Then
    Begin
      Str(-SymTab[Idx].Offset, OfsStr);
      EmitInstr('MOV', 'AX, [BP-' + OfsStr + ']');
    End
    Else
    Begin
      Str(SymTab[Idx].Offset, OfsStr);
      EmitInstr('MOV', 'AX, [BP+' + OfsStr + ']');
    End;
  End
  Else If (SymTab[Idx].Cat = SC_GLOBAL) Or (SymTab[Idx].Cat = SC_CONST) Then
    EmitInstr('MOV', 'AX, [' + SymTab[Idx].MangledName + ']')
  Else
    EmitInstr('XOR', 'AX, AX');
End;

{ ---- ParseAssignStmt : $var = expr; ou $var op= expr; ------- }
{ Appelable depuis ParseStmt quand CurToken = TK_VAR.          }
{ Alloue la variable si inconnue (locale par defaut).          }
Procedure ParseAssignStmt;
Var
  VarName : TString;
  Op      : TString;
  Idx     : Integer;
  SrcIdx  : Integer;
  E       : TExprVal;
  OfsStr  : TString;
  IsRef   : Boolean;
  SrcName : TString;
Begin
  VarName := CurToken.Val;
  ParserAdvance;
  If CurToken.Kind <> TK_OP Then Exit;
  Op := CurToken.Val;
  If (Op <> '=')   And (Op <> '+=')  And (Op <> '-=')  And
     (Op <> '*=')  And (Op <> '/=')  And (Op <> '%=')  And
     (Op <> '&=')  And (Op <> '|=')  And (Op <> '^=')  And
     (Op <> '.=')  And (Op <> '<<=') And (Op <> '>>=') Then Exit;
  ParserAdvance;
  { Detecter affectation par reference : $a = &$b }
  IsRef := False;
  If (Op = '=') And (CurToken.Kind = TK_OP) And (CurToken.Val = '&') Then
  Begin
    IsRef := True;
    ParserAdvance;
  End;
  { Chercher ou creer la variable cible }
  Idx := SymFind(VarName);
  If Idx < 0 Then
    Idx := AllocLocal(VarName, TY_IDX_MIXED, CurToken.Line);
  If IsRef Then
  Begin
    { $a = &$b : LEA adresse source dans AX }
    If CurToken.Kind = TK_VAR Then
    Begin
      SrcName := CurToken.Val;
      ParserAdvance;
      SrcIdx := SymFind(SrcName);
      If SrcIdx < 0 Then
        SrcIdx := AllocLocal(SrcName, TY_IDX_MIXED, CurToken.Line);
      If (SymTab[SrcIdx].Cat = SC_VAR) Or (SymTab[SrcIdx].Cat = SC_PARAM) Then
      Begin
        If SymTab[SrcIdx].Offset < 0 Then
        Begin
          Str(-SymTab[SrcIdx].Offset, OfsStr);
          EmitInstr('LEA', 'AX, [BP-' + OfsStr + ']');
        End
        Else
        Begin
          Str(SymTab[SrcIdx].Offset, OfsStr);
          EmitInstr('LEA', 'AX, [BP+' + OfsStr + ']');
        End;
      End
      Else
        EmitInstr('MOV', 'AX, OFFSET ' + SymTab[SrcIdx].MangledName);
    End
    Else
    Begin
      ParseExprPrec(1, E);
      ExprLoad(E);
    End;
  End
  Else If Op = '=' Then
  Begin
    ParseExprPrec(1, E);
    ExprLoad(E);
    { TODO 21 : propagation du type objet pour resolution -> }
    If E.TypeIdx >= TY_PRIM_COUNT Then
    Begin
      SymTab[Idx].TypeIdx := E.TypeIdx;
      If SymTab[Idx].Cat = SC_VAR Then
        If (E.TypeIdx - TY_PRIM_COUNT >= 0) And
           (E.TypeIdx - TY_PRIM_COUNT < ClassCount) Then
          SymTab[Idx].MangledName := ClassTab[E.TypeIdx - TY_PRIM_COUNT].ClsName;
    End;
  End
  Else
  Begin
    { Affectation composee : charger la valeur courante dans BX }
    VarLoadToAX(Idx);
    EmitInstr('MOV', 'BX, AX');
    ParseExprPrec(1, E);
    ExprLoad(E);
    If      Op = '+='  Then EmitInstr('ADD', 'BX, AX')
    Else If Op = '-='  Then EmitInstr('SUB', 'BX, AX')
    Else If Op = '*='  Then Begin EmitInstr('IMUL', 'BX'); EmitInstr('MOV', 'BX, AX'); End
    Else If Op = '&='  Then EmitInstr('AND', 'BX, AX')
    Else If Op = '|='  Then EmitInstr('OR',  'BX, AX')
    Else If Op = '^='  Then EmitInstr('XOR', 'BX, AX')
    Else If Op = '<<=' Then Begin EmitInstr('MOV', 'CX, AX'); EmitInstr('SHL', 'BX, CL'); End
    Else If Op = '>>=' Then Begin EmitInstr('MOV', 'CX, AX'); EmitInstr('SAR', 'BX, CL'); End
    Else
    Begin
      WriteLn('PHP86:', CurToken.Line, ': avertissement: ', Op, ' non supporte');
      Inc(WarnCount);
    End;
    EmitInstr('MOV', 'AX, BX');
  End;
  VarStore(Idx);
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance;
End;

{ ---- ParseGlobalDecl : global $var [, $var2 ...]; ----------- }
{ Lie les noms a des variables globales dans le segment DATA.  }
Procedure ParseGlobalDecl;
Var
  VarName : TString;
  GIdx    : Integer;
  LIdx    : Integer;
Begin
  ParserAdvance; { consommer 'global' }
  Repeat
    If CurToken.Kind <> TK_VAR Then
    Begin
      WriteLn('PHP86:', CurToken.Line, ': erreur: $var attendu apres global');
      Inc(ErrorCount);
      Exit;
    End;
    VarName := CurToken.Val;
    ParserAdvance;
    GIdx := SymFindCat(VarName, SC_GLOBAL);
    If GIdx < 0 Then
      GIdx := AllocGlobal(VarName, TY_IDX_MIXED, CurToken.Line);
    LIdx := SymFindLocal(VarName);
    If LIdx < 0 Then
      SymAdd(VarName, SC_GLOBAL, SymTab[GIdx].TypeIdx,
             False, SymTab[GIdx].Offset, CurToken.Line);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance
    Else
      Break;
  Until False;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance
  Else
  Begin
    WriteLn('PHP86:', CurToken.Line, ': erreur: '';'' attendu apres global');
    Inc(ErrorCount);
  End;
End;

{ ---- ParseStaticDecl : static $var [= expr]; ---------------- }
{ Variable locale persistante : stockee dans le segment DATA.  }
Procedure ParseStaticDecl;
Var
  VarName : TString;
  Lbl     : TString;
  NS      : TString;
  DIdx    : Integer;
  E       : TExprVal;
Begin
  ParserAdvance; { consommer 'static' }
  If CurToken.Kind <> TK_VAR Then
  Begin
    WriteLn('PHP86:', CurToken.Line, ': erreur: $var attendu apres static');
    Inc(ErrorCount);
    Exit;
  End;
  VarName := CurToken.Val;
  ParserAdvance;
  Inc(LabelSeq);
  Str(LabelSeq, NS);
  Lbl  := PH_VAR_PFX + VarName + '_S' + NS;
  DIdx := DataAddWord(Lbl, 0);
  SymAdd(VarName, SC_GLOBAL, TY_IDX_MIXED, False, DIdx, CurToken.Line);
  SymTab[SymCount - 1].MangledName := Lbl;
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
  Begin
    ParserAdvance;
    ParseExprPrec(1, E);
    If E.Kind = EK_IMM Then
      DataTab[DIdx].IntVal := E.ImmVal
    Else
    Begin
      ExprLoad(E);
      EmitInstr('MOV', '[' + Lbl + '], AX');
    End;
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance
  Else
  Begin
    WriteLn('PHP86:', CurToken.Line, ': erreur: '';'' attendu apres static');
    Inc(ErrorCount);
  End;
End;

{ ============================================================
  TODO 12 - ECHO / PRINT / VAR_DUMP
  ============================================================ }

{ ---- EmitPrintExpr : imprimer la valeur de E sur stdout --- }
{ Appelle ExprLoad (AX = valeur ou OFFSET chaine).           }
{ Chaines  : MOV SI, AX  + CALL _PHRT_PRINT                 }
{ Entiers  : CALL _PHRT_ITOA  + CALL _PHRT_PRINT             }
Procedure EmitPrintExpr(Var E : TExprVal);
Begin
  ExprLoad(E);       { materialiser dans AX }
  If E.TypeIdx = TY_IDX_STRING Then
  Begin
    { AX = OFFSET du buffer de chaine -> SI }
    EmitInstr('MOV',  'SI, AX');
    EmitInstr('CALL', PH_RT_PFX + 'PRINT');
  End
  Else
  Begin
    { entier / bool / float / autre : AX = valeur numerique }
    EmitInstr('CALL', PH_RT_PFX + 'ITOA');   { AX -> SI (buffer interne) }
    EmitInstr('CALL', PH_RT_PFX + 'PRINT');  { SI -> stdout }
  End;
End;

{ ---- ParseEchoStmt : echo expr [, expr]* ; --------------- }
{ CurToken = TK_KEYWORD 'echo' a l''entree.                   }
Procedure ParseEchoStmt;
Var
  E    : TExprVal;
  More : Boolean;
Begin
  ParserAdvance;   { consommer 'echo' }
  More := True;
  While More Do
  Begin
    ParseExpr(E);
    EmitComment('echo');
    EmitPrintExpr(E);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
    Begin
      ParserAdvance;   { consommer ',' }
      More := True;
    End
    Else
      More := False;
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance
  Else
  Begin
    WriteLn('PHP86:', CurToken.Line, ': erreur: '';'' attendu apres echo');
    Inc(ErrorCount);
  End;
End;

{ ---- ParsePrintStmt : print expr ; (retourne 1 dans AX) -- }
{ CurToken = TK_KEYWORD 'print' a l''entree.                  }
Procedure ParsePrintStmt;
Var
  E : TExprVal;
Begin
  ParserAdvance;   { consommer 'print' }
  ParseExpr(E);
  EmitComment('print');
  EmitPrintExpr(E);
  EmitInstr('MOV', 'AX, 1');   { print() retourne toujours 1 }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance
  Else
  Begin
    WriteLn('PHP86:', CurToken.Line, ': erreur: '';'' attendu apres print');
    Inc(ErrorCount);
  End;
End;

{ ---- ParseVarDumpStmt : var_dump(expr [, expr]*) ; ------- }
{ CurToken = TK_IDENT 'var_dump' a l''entree.               }
{ Emet : type(  puis valeur puis )\n pour chaque argument.  }
Procedure ParseVarDumpStmt;
Var
  E      : TExprVal;
  TName  : TString;
  TyLbl  : TString;
  More   : Boolean;
  TyIdx  : Integer;
Begin
  ParserAdvance;   { consommer 'var_dump' }
  If (CurToken.Kind <> TK_PUNCT) Or (CurToken.Val <> '(') Then
  Begin
    WriteLn('PHP86:', CurToken.Line, ': erreur: ''('' attendu apres var_dump');
    Inc(ErrorCount);
    Exit;
  End;
  ParserAdvance;   { consommer '(' }
  More := True;
  While More Do
  Begin
    ParseExpr(E);
    { determiner le nom du type cible }
    TyIdx := E.TypeIdx;
    If (TyIdx >= 0) And (TyIdx < TypeCount) Then
      TName := TypeTab[TyIdx].Name
    Else
      TName := 'unknown';
    EmitComment('var_dump: ' + TName);
    { Emettre le prefixe  type(  }  
    TyLbl := DataTab[DataAddStr(TName + '(')].LblName;
    EmitInstr('MOV',  'SI, OFFSET ' + TyLbl);
    EmitInstr('CALL', PH_RT_PFX + 'PRINT');
    { Emettre la valeur }
    EmitPrintExpr(E);
    { Emettre le suffixe  )\n  }
    TyLbl := DataTab[DataAddStr(')')].LblName;
    EmitInstr('MOV',  'SI, OFFSET ' + TyLbl);
    EmitInstr('CALL', PH_RT_PFX + 'PRINT');
    EmitInstr('CALL', PH_RT_PFX + 'NEWLINE');   { retour a la ligne }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
    Begin
      ParserAdvance;
      More := True;
    End
    Else
      More := False;
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance
  Else
  Begin
    WriteLn('PHP86:', CurToken.Line, ': erreur: '')'' attendu apres var_dump(...)');
    Inc(ErrorCount);
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance
  Else
  Begin
    WriteLn('PHP86:', CurToken.Line, ': erreur: '';'' attendu apres var_dump(...)');
    Inc(ErrorCount);
  End;
End;

{ ============================================================
  TODO 14 - BOUCLES : while / do..while / for
  ============================================================ }

{ ---- LoopPush : empiler les labels break/continue ---------- }
Procedure LoopPush(Const BrkLbl, CntLbl : TString);
Begin
  If LoopTop >= MAX_LOOP_NEST Then
  Begin
    WriteLn('PHP86: imbrication de boucles trop profonde (max ', MAX_LOOP_NEST, ')');
    Inc(ErrorCount);
    Exit;
  End;
  LoopBreakLbl[LoopTop] := BrkLbl;
  LoopContLbl [LoopTop] := CntLbl;
  Inc(LoopTop);
End;

{ ---- LoopPop : depiler les labels break/continue ----------- }
Procedure LoopPop;
Begin
  If LoopTop > 0 Then Dec(LoopTop);
End;

{ ---- ParseForExprItem : une expression dans for(init;cond;incr) }
{ Gere : $var = expr   $var op= expr   $var++  $var--   expr  }
Procedure ParseForExprItem;
Var
  E       : TExprVal;
  VarName : TString;
  Op      : TString;
  Idx     : Integer;
Begin
  If CurToken.Kind = TK_VAR Then
  Begin
    VarName := CurToken.Val;
    ParserAdvance;   { consommer $var }
    If CurToken.Kind = TK_OP Then
    Begin
      Op := CurToken.Val;
      If (Op = '=')  Or (Op = '+=') Or (Op = '-=') Or
         (Op = '*=') Or (Op = '/=') Or (Op = '%=') Or
         (Op = '.=') Then
      Begin
        ParserAdvance;  { consommer op }
        ParseExpr(E);
        ExprLoad(E);
        Idx := SymFind(VarName);
        If Idx < 0 Then
          Idx := AllocLocal(VarName, TY_IDX_INT, CurToken.Line);
        If Op = '=' Then
          VarStore(Idx)
        Else
        Begin
          { compound : charger var dans BX, RHS est dans AX }
          EmitInstr('MOV', 'BX, AX');   { BX = RHS }
          VarLoadToAX(Idx);             { AX = LHS }
          If      Op = '+=' Then EmitInstr('ADD',  'AX, BX')
          Else If Op = '-=' Then EmitInstr('SUB',  'AX, BX')
          Else If Op = '*=' Then EmitInstr('IMUL', 'BX')
          Else If Op = '.=' Then Begin EmitInstr('MOV', 'SI, AX'); EmitInstr('MOV', 'DI, BX'); EmitInstr('CALL', PH_RT_PFX + 'CONCAT'); End
          Else                   EmitInstr('ADD',  'AX, BX');  { fallback }
          VarStore(Idx);
        End;
        Exit;
      End;
      If Op = '++' Then
      Begin
        Idx := SymFind(VarName);
        If Idx < 0 Then Idx := AllocLocal(VarName, TY_IDX_INT, CurToken.Line);
        VarLoadToAX(Idx);
        EmitInstr('INC', 'AX');
        VarStore(Idx);
        ParserAdvance;   { consommer '++' }
        Exit;
      End;
      If Op = '--' Then
      Begin
        Idx := SymFind(VarName);
        If Idx < 0 Then Idx := AllocLocal(VarName, TY_IDX_INT, CurToken.Line);
        VarLoadToAX(Idx);
        EmitInstr('DEC', 'AX');
        VarStore(Idx);
        ParserAdvance;   { consommer '--' }
        Exit;
      End;
    End;
    { juste une reference de variable : charger dans AX }
    Idx := SymFind(VarName);
    If Idx >= 0 Then VarLoadToAX(Idx);
  End
  Else
  Begin
    ParseExpr(E);
    ExprLoad(E);
  End;
End;

{ ---- ParseForExprList : liste d''expr separees par , jusqu''a StopCh }
Procedure ParseForExprList(StopCh : Char);
Begin
  While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = StopCh))
        And (CurToken.Kind <> TK_EOF) Do
  Begin
    ParseForExprItem;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance;
  End;
End;

{ ---- ParseWhileStmt : while (cond) BLOC ou while (cond): ...endwhile; }
{ CurToken = TK_KEYWORD 'while' a l''entree.                          }
Procedure ParseWhileStmt;
Var
  TopLbl, EndLbl : TString;
  E              : TExprVal;
  JmpFalse       : TString;
  IsAlt          : Boolean;
Begin
  ParserAdvance;   { consommer 'while' }
  TopLbl := SymNewLabel('WHTOP');
  EndLbl := SymNewLabel('WHEND');
  LoopPush(EndLbl, TopLbl);   { break -> EndLbl, continue -> TopLbl }
  EmitLabel(TopLbl);
  { condition }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    ParserAdvance;
  ParseIfCond(E, JmpFalse);
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance;
  EmitInstr(JmpFalse, EndLbl);
  { syntaxe alternative : while (cond): }
  IsAlt := (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':');
  If IsAlt Then ParserAdvance;
  { corps }
  If Not IsAlt Then
    ParseBlock
  Else
    While Not ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'endwhile'))
          And (CurToken.Kind <> TK_EOF) Do
      ParseStmt;
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'endwhile') Then
  Begin
    ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      ParserAdvance;
  End;
  EmitInstr('JMP', TopLbl);
  EmitLabel(EndLbl);
  LoopPop;
End;

{ ---- ParseDoWhileStmt : do BLOC while (cond); --------------- }
{ CurToken = TK_KEYWORD 'do' a l''entree.                     }
Procedure ParseDoWhileStmt;
Var
  TopLbl, EndLbl, ContLbl : TString;
  E                       : TExprVal;
  JmpFalse                : TString;
Begin
  ParserAdvance;   { consommer 'do' }
  TopLbl  := SymNewLabel('DOTOP');
  EndLbl  := SymNewLabel('DOEND');
  ContLbl := SymNewLabel('DOCONT');
  LoopPush(EndLbl, ContLbl);   { break -> EndLbl, continue -> ContLbl }
  EmitLabel(TopLbl);
  { corps }
  ParseBlock;
  { ContLbl : point de re-test de la condition (cible de continue) }
  EmitLabel(ContLbl);
  { while (cond) }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'while') Then
    ParserAdvance;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    ParserAdvance;
  ParseIfCond(E, JmpFalse);
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance;
  { si condition vraie : repartir en haut (inverser JmpFalse) }
  If JmpFalse = 'JZ'  Then EmitInstr('JNZ', TopLbl)
  Else                      EmitInstr('JZ',  TopLbl);
  EmitLabel(EndLbl);
  LoopPop;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance;
End;

{ ---- ParseForStmt : for (init; cond; incr) BLOC ------------ }
{ Structure ASM emise :                                         }
{   INIT_code                                                   }
{   FORTOP: COND_check JmpFalse FOREND JMP FORBODY             }
{   FORINC: INCR_code JMP FORTOP                               }
{   FORBODY: BODY_code JMP FORINC                              }
{   FOREND:                                                     }
Procedure ParseForStmt;
Var
  TopLbl, EndLbl, IncrLbl, BodyLbl : TString;
  E                                : TExprVal;
  JmpFalse                         : TString;
  HasCond                          : Boolean;
  IsAlt                            : Boolean;
Begin
  ParserAdvance;   { consommer 'for' }
  TopLbl  := SymNewLabel('FORTOP');
  EndLbl  := SymNewLabel('FOREND');
  IncrLbl := SymNewLabel('FORINC');
  BodyLbl := SymNewLabel('FORBODY');
  LoopPush(EndLbl, IncrLbl);   { break -> EndLbl, continue -> IncrLbl }
  { consommer '(' }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    ParserAdvance;
  { section INIT : expr , expr... jusqu''au premier ';' }
  ParseForExprList(';');
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance;
  { label FORTOP : debut du test de condition }
  EmitLabel(TopLbl);
  { section COND : optionnelle }
  HasCond := Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';'));
  If HasCond Then
  Begin
    ParseIfCond(E, JmpFalse);
    EmitInstr(JmpFalse, EndLbl);
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance;
  { saut vers le corps (par dessus la section incr) }
  EmitInstr('JMP', BodyLbl);
  { label FORINC : cible de continue et debut de section incr }
  EmitLabel(IncrLbl);
  { section INCR : expr , expr... jusqu''au ')' }
  ParseForExprList(')');
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance;
  EmitInstr('JMP', TopLbl);   { reboucler vers le test }
  { label FORBODY : debut du corps }
  EmitLabel(BodyLbl);
  { syntaxe alternative : for (...): }
  IsAlt := (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':');
  If IsAlt Then ParserAdvance;
  If Not IsAlt Then
    ParseBlock
  Else
    While Not ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'endfor'))
          And (CurToken.Kind <> TK_EOF) Do
      ParseStmt;
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'endfor') Then
  Begin
    ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      ParserAdvance;
  End;
  EmitInstr('JMP', IncrLbl);   { fin de corps -> incrementeur }
  EmitLabel(EndLbl);
  LoopPop;
End;

{ ---- ParseBreakStmt : break [N]; --------------------------- }
{ CurToken = TK_KEYWORD 'break' a l''entree.                  }
{ break N : sort des N boucles les plus internes (PHP)        }
Procedure ParseBreakStmt;
Var
  Levels : Integer;
  TgtIdx : Integer;
  E      : TExprVal;
Begin
  ParserAdvance;   { consommer 'break' }
  Levels := 1;
  { N optionnel (entier) }
  If CurToken.Kind = TK_INTEGER Then
  Begin
    ParseExpr(E);
    If E.Kind = EK_IMM Then Levels := E.ImmVal;
  End;
  If LoopTop <= 0 Then
  Begin
    WriteLn('PHP86:', CurToken.Line, ': erreur: break hors d''une boucle');
    Inc(ErrorCount);
  End
  Else
  Begin
    TgtIdx := LoopTop - Levels;
    If TgtIdx < 0 Then TgtIdx := 0;
    EmitInstr('JMP', LoopBreakLbl[TgtIdx]);
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance;
End;

{ ---- ParseContinueStmt : continue [N]; --------------------- }
{ CurToken = TK_KEYWORD 'continue' a l''entree.               }
Procedure ParseContinueStmt;
Var
  Levels : Integer;
  TgtIdx : Integer;
  E      : TExprVal;
Begin
  ParserAdvance;   { consommer 'continue' }
  Levels := 1;
  If CurToken.Kind = TK_INTEGER Then
  Begin
    ParseExpr(E);
    If E.Kind = EK_IMM Then Levels := E.ImmVal;
  End;
  If LoopTop <= 0 Then
  Begin
    WriteLn('PHP86:', CurToken.Line, ': erreur: continue hors d''une boucle');
    Inc(ErrorCount);
  End
  Else
  Begin
    TgtIdx := LoopTop - Levels;
    If TgtIdx < 0 Then TgtIdx := 0;
    EmitInstr('JMP', LoopContLbl[TgtIdx]);
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance;
End;

{ ============================================================
  TODO 13 - IF / ELSEIF / ELSE  (suite : ParseStmt mis a jour)
  ============================================================ }

{ ---- ParseBlock : bloc accolades ou instruction simple ----- }
{ Un bloc ouvre une portee de symboles propre.                }
{ Sinon : un seul ParseStmt (syntaxe sans accolades)          }
Procedure ParseBlock;
Var
  SavedFrame : Integer;
Begin
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
  Begin
    ParserAdvance;   { consommer accolade ouvrante }
    SavedFrame := BlockEnterScope;
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}'))
          And (CurToken.Kind <> TK_EOF) Do
      ParseStmt;
    BlockLeaveScope(SavedFrame);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
      ParserAdvance
    Else
    Begin
      WriteLn('PHP86:', CurToken.Line, ': erreur: ''}'' attendu en fin de bloc');
      Inc(ErrorCount);
    End;
  End
  Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance   { instruction vide }
  Else
  Begin
    SavedFrame := BlockEnterScope;
    ParseStmt;
    BlockLeaveScope(SavedFrame);
  End;
End;

{ ---- ParseIfCond : parse interieur de cond, resultat AX      }
{ Retourne JmpFalse = instruction de saut si cond est FAUSSE.  }
{ Gere isset(v)   -> JZ si AX=0                               }
{ Gere is_null(v) -> JNZ si AX<>0 (condition vraie = AX=0)   }
Procedure ParseIfCond(Var E : TExprVal; Var JmpFalse : TString);
Var
  Fn : TString;
Begin
  JmpFalse := 'JZ';     { par defaut : saut si zero = false }
  Fn := '';
  { cas speciaux isset($v) / is_null($v) }
  If (CurToken.Kind = TK_IDENT) And
     ((CurToken.Val = 'isset') Or (CurToken.Val = 'is_null')) Then
  Begin
    Fn := CurToken.Val;
    ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      ParserAdvance;   { paren interne de isset ou is_null }
    ParseExpr(E);
    ExprLoad(E);
    EmitInstr('TEST', 'AX, AX');
    { is_null(v) est vraie quand AX=0 ; saut vers else si AX<>0 }
    If Fn = 'is_null' Then
      JmpFalse := 'JNZ';
    E.Kind := EK_AX; E.TypeIdx := TY_IDX_BOOL;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;   { paren fermante de isset ou is_null }
  End
  Else
  Begin
    ParseExpr(E);
    ExprLoad(E);
    EmitInstr('TEST', 'AX, AX');
  End;
End;

{ ---- ParseIfStmt : if [elseif]* [else] --------------------- }
{ CurToken = TK_KEYWORD 'if' a l''entree.                       }
{ Syntaxe normale  : if (c) BLOC elseif (c) BLOC else BLOC    }
{ Syntaxe alt.     : if (c): ... elseif(c): ... else: ... endif; }
Procedure ParseIfStmt;
Var
  EndLbl   : TString;
  NxtLbl   : TString;
  E        : TExprVal;
  IsAlt    : Boolean;
  JmpFalse : TString;
Begin
  ParserAdvance;   { consommer 'if' }
  EndLbl := SymNewLabel('ENDIF');
  { --- parse ( condition ) --- }
  If (CurToken.Kind <> TK_PUNCT) Or (CurToken.Val <> '(') Then
  Begin
    WriteLn('PHP86:', CurToken.Line, ': erreur: ''('' attendu apres if');
    Inc(ErrorCount);
    Exit;
  End;
  ParserAdvance;   { '(' }
  ParseIfCond(E, JmpFalse);
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance
  Else
  Begin
    WriteLn('PHP86:', CurToken.Line, ': erreur: '')'' attendu apres condition if');
    Inc(ErrorCount);
  End;
  { saut vers le premier label ELSE/ELSEIF/ENDIF si condition fausse }
  NxtLbl := SymNewLabel('ELSE');
  EmitInstr(JmpFalse, NxtLbl);
  { syntaxe alternative : if (cond): }
  IsAlt := (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':');
  If IsAlt Then
    ParserAdvance;
  { --- bloc THEN --- }
  If Not IsAlt Then
    ParseBlock
  Else
    While Not ((CurToken.Kind = TK_KEYWORD) And
               ((CurToken.Val = 'elseif') Or (CurToken.Val = 'else') Or
                (CurToken.Val = 'endif')))
          And (CurToken.Kind <> TK_EOF) Do
      ParseStmt;
  { --- chaine elseif --- }
  While (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'elseif') Do
  Begin
    EmitInstr('JMP', EndLbl);   { sauter hors du then }
    EmitLabel(NxtLbl);          { debut de ce elseif }
    ParserAdvance;              { consommer 'elseif' }
    { condition elseif }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      ParserAdvance;
    ParseIfCond(E, JmpFalse);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;
    NxtLbl := SymNewLabel('ELSE');
    EmitInstr(JmpFalse, NxtLbl);
    IsAlt := (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':');
    If IsAlt Then ParserAdvance;
    If Not IsAlt Then
      ParseBlock
    Else
      While Not ((CurToken.Kind = TK_KEYWORD) And
                 ((CurToken.Val = 'elseif') Or (CurToken.Val = 'else') Or
                  (CurToken.Val = 'endif')))
            And (CurToken.Kind <> TK_EOF) Do
        ParseStmt;
  End;
  { --- bloc ELSE --- }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'else') Then
  Begin
    EmitInstr('JMP', EndLbl);   { sauter hors du dernier then/elseif }
    EmitLabel(NxtLbl);          { entree de else }
    NxtLbl := EndLbl;           { endif = fin de else }
    ParserAdvance;              { consommer 'else' }
    IsAlt := (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':');
    If IsAlt Then ParserAdvance;
    If Not IsAlt Then
      ParseBlock
    Else
      While Not ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'endif'))
            And (CurToken.Kind <> TK_EOF) Do
        ParseStmt;
  End;
  { --- endif; pour syntaxe alternative --- }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'endif') Then
  Begin
    ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      ParserAdvance;
  End;
  { labels de fin : NxtLbl (si pas de else) puis EndLbl }
  If NxtLbl <> EndLbl Then
  Begin
    EmitLabel(NxtLbl);   { label else/endif quand il n''y avait pas de else }
    EmitLabel(EndLbl);
  End
  Else
    EmitLabel(EndLbl);   { cas avec else : NxtLbl = EndLbl, deja emis }
End;

{ ---- ParseStmt : dispatcher de statements (TODO 24 completera) }
{ Reconnait echo, print, var_dump, if, global, static, $var=... }
Procedure ParseStmt;
Begin
  If CurToken.Kind = TK_EOF Then Exit;
  { instruction vide }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
  Begin
    ParserAdvance;
    Exit;
  End;
  { bloc explicite }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
  Begin
    ParseBlock;
    Exit;
  End;
  { mots-cles }
  If CurToken.Kind = TK_KEYWORD Then
  Begin
    If CurToken.Val = 'echo'     Then Begin ParseEchoStmt;     Exit; End;
    If CurToken.Val = 'print'    Then Begin ParsePrintStmt;    Exit; End;
    If CurToken.Val = 'if'       Then Begin ParseIfStmt;       Exit; End;
    If CurToken.Val = 'while'    Then Begin ParseWhileStmt;    Exit; End;
    If CurToken.Val = 'do'       Then Begin ParseDoWhileStmt;  Exit; End;
    If CurToken.Val = 'for'      Then Begin ParseForStmt;      Exit; End;
    If CurToken.Val = 'foreach'   Then Begin ParseForeachStmt;  Exit; End;
    If CurToken.Val = 'switch'    Then Begin ParseSwitchStmt;   Exit; End;
    If CurToken.Val = 'break'    Then Begin ParseBreakStmt;    Exit; End;
    If CurToken.Val = 'continue' Then Begin ParseContinueStmt; Exit; End;
    If CurToken.Val = 'global'   Then Begin ParseGlobalDecl;   Exit; End;
    If CurToken.Val = 'static'   Then Begin ParseStaticDecl;   Exit; End;
    If CurToken.Val = 'function' Then Begin ParseFnDecl;       Exit; End;
    If CurToken.Val = 'return'   Then Begin ParseReturnStmt;   Exit; End;
    If CurToken.Val = 'class'    Then Begin ParseClassDecl;    Exit; End;
    { mot-cle non supporte a ce stade }
    WriteLn('PHP86:', CurToken.Line, ': avert: statement ''',
            CurToken.Val, ''' non supporte (TODO)');
    Inc(WarnCount);
    ParserAdvance;
    Exit;
  End;
  { identifiant : var_dump, die, exit ou appel inconnu }
  If CurToken.Kind = TK_IDENT Then
  Begin
    If CurToken.Val = 'var_dump' Then Begin ParseVarDumpStmt; Exit; End;
    { die/exit comme statement : die; die(0); exit; exit(1); }
    If (CurToken.Val = 'die') Or (CurToken.Val = 'exit') Then
    Begin
      ParserAdvance;  { consommer 'die'/'exit' }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        ParserAdvance;  { consommer '(' }
        If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
        Begin
          ParseExpr(GExprDummy); ExprLoad(GExprDummy);
          EmitInstr('MOV', 'AH, 4Ch');
        End
        Else
          EmitInstr('MOV', 'AX, 4C00h');
        While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) And
              (CurToken.Kind <> TK_EOF) Do ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
      End
      Else
        EmitInstr('MOV', 'AX, 4C00h');
      EmitInstr('INT', '21h');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        ParserAdvance;
      Exit;
    End;
    WriteLn('PHP86:', CurToken.Line, ': avert: appel ''',
            CurToken.Val, ''' non supporte (TODO)');
    Inc(WarnCount);
    ParserAdvance;
    Exit;
  End;
  { variable : assignation }
  If CurToken.Kind = TK_VAR Then
  Begin
    ParseAssignStmt;
    Exit;
  End;
  { token inattendu }
  WriteLn('PHP86:', CurToken.Line, ': avert: token inattendu ''',
          CurToken.Val, ''' dans statement');
  Inc(WarnCount);
  ParserAdvance;
End;

{ ============================================================
  TODO 15 - FOREACH
  ============================================================ }

{ ---- ParseForeachStmt : foreach ($arr as [$key =>] $val) ----}
{ Modele ASM pour tableaux indexes simples (count, data...) :  }
{   [SI]    = nombre d''elements (word)                        }
{   [SI+2].. = elements consecutifs (word chacun)              }
{ Temporaires locaux alloues dynamiquement :                   }
{   __feB_N = adresse de base du 1er element (SI+2)            }
{   __feI_N = index courant (0..count-1)                       }
{   __feE_N = nombre d''elements (borne exclusive)             }
Procedure ParseForeachStmt;
Var
  ValName : TString;
  KeyName : TString;
  HasKey  : Boolean;
  IsAlt   : Boolean;
  TopLbl  : TString;
  EndLbl  : TString;
  ContLbl : TString;
  BaseVar : Integer;
  IdxVar  : Integer;
  EndVar  : Integer;
  ValIdx  : Integer;
  KeyIdx  : Integer;
  BaseN   : TString;
  IdxN    : TString;
  EndN    : TString;
  UidStr  : TString;
  FirstName : TString;
  E       : TExprVal;
Begin
  ParserAdvance;   { consommer 'foreach' }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    ParserAdvance;
  { evaluer l''expression du tableau : AX = ptr vers struct [count,data...] }
  ParseExpr(E);
  ExprLoad(E);
  { noms uniques pour les temporaires de boucle }
  Inc(LabelSeq);
  Str(LabelSeq, UidStr);
  BaseN := '__feB' + UidStr;
  IdxN  := '__feI' + UidStr;
  EndN  := '__feE' + UidStr;
  BaseVar := AllocLocal(BaseN, TY_IDX_INT, CurToken.Line);
  IdxVar  := AllocLocal(IdxN,  TY_IDX_INT, CurToken.Line);
  EndVar  := AllocLocal(EndN,  TY_IDX_INT, CurToken.Line);
  { SI = pointeur tableau ; lire count ; avancer vers les donnees }
  EmitComment('foreach : init');
  EmitInstr('MOV', 'SI, AX');        { SI = ptr tableau }
  EmitInstr('MOV', 'AX, [SI]');      { AX = count }
  VarStore(EndVar);                  { __feE = count }
  EmitInstr('INC', 'SI');            { SI += 2 (en 2 fois pour 8086 strict) }
  EmitInstr('INC', 'SI');
  EmitInstr('MOV', 'AX, SI');        { AX = adresse du 1er element }
  VarStore(BaseVar);                 { __feB = &data[0] }
  EmitInstr('XOR', 'AX, AX');
  VarStore(IdxVar);                  { __feI = 0 }
  { consommer 'as' }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'as') Then
    ParserAdvance;
  { $FirstName  ou  $key => $val }
  HasKey    := False;
  ValName   := '';
  KeyName   := '';
  FirstName := '';
  If CurToken.Kind = TK_VAR Then
  Begin
    FirstName := CurToken.Val;
    ParserAdvance;
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '=>') Then
    Begin
      HasKey  := True;
      KeyName := FirstName;
      ParserAdvance;   { consommer '=>' }
      If CurToken.Kind = TK_VAR Then
      Begin
        ValName := CurToken.Val;
        ParserAdvance;
      End;
    End
    Else
      ValName := FirstName;
  End;
  { consommer ')' }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance;
  { creer/trouver les variables Val et Key }
  ValIdx := SymFind(ValName);
  If (ValName <> '') And (ValIdx < 0) Then
    ValIdx := AllocLocal(ValName, TY_IDX_MIXED, CurToken.Line);
  If HasKey Then
  Begin
    KeyIdx := SymFind(KeyName);
    If (KeyName <> '') And (KeyIdx < 0) Then
      KeyIdx := AllocLocal(KeyName, TY_IDX_INT, CurToken.Line);
  End
  Else
    KeyIdx := -1;
  { labels de boucle }
  TopLbl  := SymNewLabel('FETOP');
  EndLbl  := SymNewLabel('FEEND');
  ContLbl := SymNewLabel('FECONT');
  LoopPush(EndLbl, ContLbl);
  { FETOP: test idx < end }
  EmitLabel(TopLbl);
  EmitComment('foreach : test fin de tableau');
  VarLoadToAX(IdxVar);
  EmitInstr('MOV', 'BX, AX');    { BX = idx }
  VarLoadToAX(EndVar);
  EmitInstr('CMP', 'BX, AX');    { idx >= count ? }
  EmitInstr('JAE', EndLbl);
  { charger arr[idx] : adresse = BaseVar + idx*2, BX+SI }  
  EmitComment('foreach : charger arr[idx]');
  VarLoadToAX(BaseVar);
  EmitInstr('MOV', 'SI, AX');    { SI = base }
  VarLoadToAX(IdxVar);
  EmitInstr('SHL', 'AX, 1');     { AX = idx * 2 (octet offset) }
  EmitInstr('MOV', 'BX, AX');    { BX = offset }
  EmitInstr('MOV', 'AX, [SI+BX]'); { AX = arr[idx] }
  { stocker dans $val }
  If ValIdx >= 0 Then
    VarStore(ValIdx);
  { stocker idx dans $key si demande }
  If HasKey And (KeyIdx >= 0) Then
  Begin
    EmitComment('foreach : cle (index)');
    VarLoadToAX(IdxVar);
    VarStore(KeyIdx);
  End;
  { corps : syntaxe normale ou alternative }
  IsAlt := (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':');
  If IsAlt Then ParserAdvance;
  If Not IsAlt Then
    ParseBlock
  Else
    While Not ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'endforeach'))
          And (CurToken.Kind <> TK_EOF) Do
      ParseStmt;
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'endforeach') Then
  Begin
    ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      ParserAdvance;
  End;
  { FECONT : incrementer idx et reboucler }
  EmitLabel(ContLbl);
  EmitComment('foreach : incrementer index');
  VarLoadToAX(IdxVar);
  EmitInstr('INC', 'AX');
  VarStore(IdxVar);
  EmitInstr('JMP', TopLbl);
  EmitLabel(EndLbl);
  LoopPop;
End;

{ ============================================================
  TODO 16 - SWITCH / CASE / DEFAULT
  ============================================================ }

{ ---- ParseSwitchStmt : switch(expr) case/default/endswitch -- }
{ Structure ASM :                                              }
{   sujet -> local __swSN ; DX = flag match (0=non, 1=oui)    }
{   chaque case val: CMP BX,val + JNE skip ; MOV DX,1 ;       }
{                    TEST DX,DX + JZ corps_suivant             }
{   fall-through : quand le corps ne contient pas de break     }
{   default en dernier : label seul, corps toujours execute    }
{   break -> JMP SWEND via LoopBreakLbl                       }
Procedure ParseSwitchStmt;
Var
  EndLbl      : TString;
  SubjVar     : Integer;
  PendSkipLbl : TString;    { label a emettre au debut du prochain case }
  HasPend     : Boolean;
  NomatchLbl  : TString;
  UidStr      : TString;
  SubjN       : TString;
  E           : TExprVal;
  CaseE       : TExprVal;
  IsAlt       : Boolean;
  HasDefault  : Boolean;
Begin
  ParserAdvance;   { consommer 'switch' }
  { generer des identifiants uniques }
  Inc(LabelSeq);
  Str(LabelSeq, UidStr);
  EndLbl := PH_LBL_PFX + 'SWEND_' + UidStr;
  SubjN  := '__swS' + UidStr;
  { evaluer le sujet et le sauvegarder dans une variable locale }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    ParserAdvance;
  ParseExpr(E);
  ExprLoad(E);
  SubjVar := AllocLocal(SubjN, TY_IDX_INT, CurToken.Line);
  VarStore(SubjVar);
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance;
  { initialiser DX = 0 (flag : aucun case matche encore) }
  EmitComment('switch : init match flag DX=0');
  EmitInstr('XOR', 'DX, DX');
  { LoopPush : break -> EndLbl, continue -> EndLbl (idem en PHP) }
  LoopPush(EndLbl, EndLbl);
  { consommer l''ouvrant : soit '{' soit ':' (syntaxe alt.) }
  IsAlt := False;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
    ParserAdvance
  Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
  Begin
    IsAlt := True;
    ParserAdvance;
  End
  Else
  Begin
    WriteLn('PHP86:', CurToken.Line, ': erreur: accolade ou '':'' attendu apres switch()');
    Inc(ErrorCount);
  End;
  PendSkipLbl := '';
  HasPend     := False;
  HasDefault  := False;
  { boucle sur les clauses case / default }
  Repeat
    { fin de switch : accolade ou endswitch }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then Break;
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'endswitch') Then Break;
    If CurToken.Kind = TK_EOF Then Break;
    { cas : case expr: }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'case') Then
    Begin
      ParserAdvance;   { consommer 'case' }
      { emettre le label de saut du corps precedent }
      If HasPend Then EmitLabel(PendSkipLbl);
      { evaluer la valeur du case }
      ParseExpr(CaseE);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
        ParserAdvance;
      EmitComment('case');
      { recharger le sujet dans BX }
      VarLoadToAX(SubjVar);
      EmitInstr('MOV', 'BX, AX');
      { comparer sujet vs valeur du case }
      If (CaseE.TypeIdx = TY_IDX_STRING) And (CaseE.Kind = EK_MEM) Then
      Begin
        { cas chaine : CALL _PHRT_STREQ (SI=sujet, DI=case_val) }
        EmitInstr('MOV', 'SI, BX');
        If (CaseE.Offset >= 0) And (CaseE.Offset < DataCount) Then
          EmitInstr('MOV', 'DI, OFFSET ' + DataTab[CaseE.Offset].LblName)
        Else
          EmitInstr('XOR', 'DI, DI');
        NomatchLbl := PH_LBL_PFX + 'CSNE_' + UidStr + '_' + PendSkipLbl;
        If NomatchLbl = PendSkipLbl Then
        Begin
          Inc(LabelSeq); Str(LabelSeq, NomatchLbl);
          NomatchLbl := PH_LBL_PFX + 'CSNE_' + NomatchLbl;
        End;
        EmitInstr('CALL', PH_RT_PFX + 'STREQ');
        EmitInstr('TEST', 'AX, AX');
        EmitInstr('JZ',   NomatchLbl);   { pas egal -> pas de match }
        EmitInstr('MOV',  'DX, 1');      { mark as matched }
        EmitLabel(NomatchLbl);
      End
      Else
      Begin
        { cas scalaire (entier, bool, null) }
        If CaseE.Kind = EK_IMM Then
        Begin
          Str(CaseE.ImmVal, UidStr);
          EmitInstr('CMP', 'BX, ' + UidStr);
        End
        Else
        Begin
          ExprLoad(CaseE);
          EmitInstr('CMP', 'BX, AX');
        End;
        Inc(LabelSeq); Str(LabelSeq, UidStr);
        NomatchLbl := PH_LBL_PFX + 'CSNE_' + UidStr;
        EmitInstr('JNE',  NomatchLbl);   { different -> pas de match }
        EmitInstr('MOV',  'DX, 1');      { mark as matched }
        EmitLabel(NomatchLbl);
      End;
      { TEST DX,DX + JZ pendingSkipLabel : sauter le corps si non matche }
      EmitInstr('TEST', 'DX, DX');
      Inc(LabelSeq); Str(LabelSeq, UidStr);
      PendSkipLbl := PH_LBL_PFX + 'CSKP_' + UidStr;
      HasPend := True;
      EmitInstr('JZ', PendSkipLbl);
      { corps du case : statements jusqu''au prochain case/default/end }
      While Not ((CurToken.Kind = TK_KEYWORD) And
                 ((CurToken.Val = 'case') Or (CurToken.Val = 'default') Or
                  (CurToken.Val = 'endswitch')))
            And Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}'))
            And (CurToken.Kind <> TK_EOF) Do
        ParseStmt;
    End
    { clause : default: }
    Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'default') Then
    Begin
      ParserAdvance;   { consommer 'default' }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
        ParserAdvance;
      { emettre le label de saut du corps precedent }
      If HasPend Then EmitLabel(PendSkipLbl);
      HasPend    := False;
      HasDefault := True;
      EmitComment('default');
      { corps du default : statements jusqu''a la fermeture }
      While Not ((CurToken.Kind = TK_KEYWORD) And
                 ((CurToken.Val = 'case') Or (CurToken.Val = 'endswitch')))
            And Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}'))
            And (CurToken.Kind <> TK_EOF) Do
        ParseStmt;
    End
    Else
    Begin
      { token inattendu dans switch }
      WriteLn('PHP86:', CurToken.Line, ': erreur: case ou default attendu dans switch, token: ''', CurToken.Val, '''');
      Inc(ErrorCount);
      ParserAdvance;
    End;
  Until False;
  { emettre le dernier label de saut de corps si encore en attente }
  If HasPend Then EmitLabel(PendSkipLbl);
  { consommer le fermeture }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
    ParserAdvance
  Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'endswitch') Then
  Begin
    ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      ParserAdvance;
  End;
  EmitLabel(EndLbl);
  LoopPop;
End;

{ ============================================================
  TODO 17 - FONCTIONS
  ============================================================ }

{ ---- ParseCallExpr : emettre un appel de fonction ---------- }
{ FnName = nom PHP sans prefixe ; CurToken doit etre '('      }
{ Convention : appelant pousse args gauche->droite, nettoie.   }
Procedure ParseCallExpr(Const FnName : TString; Var Res : TExprVal);
Var
  ArgCount : Integer;
  E        : TExprVal;
  AStr     : TString;
  FnMang   : TString;
Begin
  { ---- Builtins speciaux (TODO 19) ---- }
  { count($a) : retourne le mot count stocke en [ptr] }
  If FnName = 'count' Then
  Begin
    ParserAdvance;  { consommer '(' }
    ParseExpr(E);
    ExprLoad(E);    { AX = adresse du tableau }
    EmitInstr('MOV', 'SI, AX');
    EmitInstr('MOV', 'AX, [SI]');   { mot count = premier mot }
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')'))
          And (CurToken.Kind <> TK_EOF) Do
      ParserAdvance;                 { drainer args superflus }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;
    Res.Kind    := EK_AX;
    Res.TypeIdx := TY_IDX_INT;
    Res.Offset  := 0;
    Res.ImmVal  := 0;
    Exit;
  End;
  { array_push($a, v) : appel runtime _PHRT_ARRAY_PUSH }
  If FnName = 'array_push' Then
  Begin
    ArgCount := 0;
    ParserAdvance;  { consommer '(' }
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')'))
          And (CurToken.Kind <> TK_EOF) Do
    Begin
      ParseExpr(E);
      ExprLoad(E);
      EmitInstr('PUSH', 'AX');
      Inc(ArgCount);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;
    EmitInstr('CALL', PH_RT_PFX + 'ARRAY_PUSH');
    If ArgCount > 0 Then
    Begin
      Str(ArgCount * 2, AStr);
      EmitInstr('ADD', 'SP, ' + AStr);
    End;
    Res.Kind    := EK_AX;
    Res.TypeIdx := TY_IDX_INT;
    Res.Offset  := 0;
    Res.ImmVal  := 0;
    Exit;
  End;
  { ============================================================
    TODO 20 - BUILTINS
    ============================================================ }

  { strlen($s) -> CALL _PHRT_STRLEN -> AX = longueur }
  If FnName = 'strlen' Then
  Begin
    ParserAdvance;
    ParseExpr(E); ExprLoad(E);
    EmitInstr('PUSH', 'AX');
    EmitInstr('CALL', PH_RT_PFX + 'STRLEN');
    EmitInstr('ADD',  'SP, 2');
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')'))
          And (CurToken.Kind <> TK_EOF) Do ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
    Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_INT;
    Res.Offset := 0; Res.ImmVal := 0; Exit;
  End;

  { intval($s) -> CALL _PHRT_ATOI -> AX = entier }
  If FnName = 'intval' Then
  Begin
    ParserAdvance;
    ParseExpr(E); ExprLoad(E);
    EmitInstr('PUSH', 'AX');
    EmitInstr('CALL', PH_RT_PFX + 'ATOI');
    EmitInstr('ADD',  'SP, 2');
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')'))
          And (CurToken.Kind <> TK_EOF) Do ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
    Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_INT;
    Res.Offset := 0; Res.ImmVal := 0; Exit;
  End;

  { strval($n) -> CALL _PHRT_ITOA -> AX = ptr chaine }
  If FnName = 'strval' Then
  Begin
    ParserAdvance;
    ParseExpr(E); ExprLoad(E);
    EmitInstr('PUSH', 'AX');
    EmitInstr('CALL', PH_RT_PFX + 'ITOA');
    EmitInstr('ADD',  'SP, 2');
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')'))
          And (CurToken.Kind <> TK_EOF) Do ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
    Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_STRING;
    Res.Offset := 0; Res.ImmVal := 0; Exit;
  End;

  { is_null($v) -> AX = (LoadedVal == 0) ? 1 : 0 }
  If FnName = 'is_null' Then
  Begin
    ParserAdvance;
    ParseExpr(E); ExprLoad(E);
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')'))
          And (CurToken.Kind <> TK_EOF) Do ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('MOV',  'AX, 0');
    EmitInstr('SETE', 'AL');
    Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_BOOL;
    Res.Offset := 0; Res.ImmVal := 0; Exit;
  End;

  { defined(NAME) -> AX = 1 si constante trouvee, 0 sinon }
  If FnName = 'defined' Then
  Begin
    ParserAdvance;
    If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_STRING) Then
    Begin
      If SymFindCat(CurToken.Val, SC_CONST) >= 0 Then
        EmitInstr('MOV', 'AX, 1')
      Else
        EmitInstr('MOV', 'AX, 0');
      ParserAdvance;
    End
    Else
      EmitInstr('MOV', 'AX, 0');
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')'))
          And (CurToken.Kind <> TK_EOF) Do ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
    Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_BOOL;
    Res.Offset := 0; Res.ImmVal := 0; Exit;
  End;

  { abs($n) -> inline via CWD : DX=masque signe, XOR+SUB }
  If FnName = 'abs' Then
  Begin
    ParserAdvance;
    ParseExpr(E); ExprLoad(E);
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')'))
          And (CurToken.Kind <> TK_EOF) Do ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
    EmitInstr('CWD',  '');
    EmitInstr('XOR',  'AX, DX');
    EmitInstr('SUB',  'AX, DX');
    Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_INT;
    Res.Offset := 0; Res.ImmVal := 0; Exit;
  End;

  { min($a,$b) -> inline : POP BX ; CMP BX,AX ; JLE done ; MOV AX,BX }
  If FnName = 'min' Then
  Begin
    ParserAdvance;
    ParseExpr(E); ExprLoad(E);
    EmitInstr('PUSH', 'AX');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then ParserAdvance;
    ParseExpr(E); ExprLoad(E);  { AX = b }
    EmitInstr('POP', 'BX');     { BX = a }
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')'))
          And (CurToken.Kind <> TK_EOF) Do ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
    AStr := SymNewLabel(PH_LBL_PFX + 'MIN');
    EmitInstr('CMP',  'AX, BX');  { b < a ? }
    EmitInstr('JLE',  AStr);      { b <= a : AX = b (garder AX) }
    EmitInstr('MOV',  'AX, BX');  { a < b : AX = a }
    EmitLabel(AStr);
    Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_INT;
    Res.Offset := 0; Res.ImmVal := 0; Exit;
  End;

  { max($a,$b) -> inline : POP BX ; CMP AX,BX ; JGE done ; MOV AX,BX }
  If FnName = 'max' Then
  Begin
    ParserAdvance;
    ParseExpr(E); ExprLoad(E);
    EmitInstr('PUSH', 'AX');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then ParserAdvance;
    ParseExpr(E); ExprLoad(E);  { AX = b }
    EmitInstr('POP', 'BX');     { BX = a }
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')'))
          And (CurToken.Kind <> TK_EOF) Do ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
    AStr := SymNewLabel(PH_LBL_PFX + 'MAX');
    EmitInstr('CMP',  'AX, BX');  { b > a ? }
    EmitInstr('JGE',  AStr);      { b >= a : AX = b (garder AX) }
    EmitInstr('MOV',  'AX, BX');  { a > b : AX = a }
    EmitLabel(AStr);
    Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_INT;
    Res.Offset := 0; Res.ImmVal := 0; Exit;
  End;

  { die/exit([code]) -> MOV AX,4C00h / INT 21h }
  If (FnName = 'die') Or (FnName = 'exit') Then
  Begin
    ParserAdvance;
    If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
    Begin
      ParseExpr(E); ExprLoad(E);
      EmitInstr('MOV', 'AH, 4Ch');
    End
    Else
      EmitInstr('MOV', 'AX, 4C00h');
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')'))
          And (CurToken.Kind <> TK_EOF) Do ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
    EmitInstr('INT',  '21h');
    ExprMakeImm(0, TY_IDX_INT, Res); Exit;
  End;

  { ---- Appel de fonction generique (cdecl) ---- }
  FnMang   := PH_FN_PFX + FnName;
  ArgCount := 0;
  ParserAdvance;   { consommer '(' }
  { Evaluer et pousser chaque argument de gauche a droite }
  While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')'))
        And (CurToken.Kind <> TK_EOF) Do
  Begin
    ParseExpr(E);
    ExprLoad(E);
    EmitInstr('PUSH', 'AX');        { AX = valeur de l''argument }
    Inc(ArgCount);
    If ArgCount >= MAX_PARAM Then
    Begin
      WriteLn('PHP86:', CurToken.Line, ': avert: trop d''arguments (max ', MAX_PARAM, ')');
      Inc(WarnCount); Break;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance;
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance;
  EmitInstr('CALL', FnMang);
  If ArgCount > 0 Then
  Begin
    Str(ArgCount * 2, AStr);
    EmitInstr('ADD', 'SP, ' + AStr);   { nettoyer la pile (cdecl caller) }
  End;
  { valeur de retour dans AX }
  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_MIXED;
  Res.Offset  := 0;
  Res.ImmVal  := 0;
End;

{ ---- ParseReturnStmt : return [expr]; ---------------------- }
{ CurToken = TK_KEYWORD 'return' a l''entree.                 }
Procedure ParseReturnStmt;
Var
  E : TExprVal;
Begin
  ParserAdvance;   { consommer 'return' }
  { Expression optionnelle }
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Then
  Begin
    ParseExpr(E);
    ExprLoad(E);   { valeur de retour dans AX }
  End
  Else
    EmitInstr('XOR', 'AX, AX');   { return; -> retourner 0 }
  { Saut vers l''epilogue de la fonction courante }
  If CurFnRetLbl <> '' Then
    EmitInstr('JMP', CurFnRetLbl)
  Else
  Begin
    WriteLn('PHP86:', CurToken.Line, ': erreur: return hors d''une fonction');
    Inc(ErrorCount);
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance;
End;

{ ---- ParseFnDecl : function name(params) corps -----------   }
{ CurToken = TK_KEYWORD 'function' a l''entree.               }
{ Convention cdecl : appelant PUSH args L->R, nettoie la pile. }
{   PUSH BP ; MOV BP,SP ; corps ; MOV SP,BP ; POP BP ; RET    }
{   $p1 au plus haut offset, $pN = [BP+4]                     }
Procedure ParseFnDecl;
Var
  FnName      : TString;
  FnMangled   : TString;
  RetLbl      : TString;
  EndLbl      : TString;
  PNames      : Array[0..MAX_PARAM - 1] Of TString;
  PRefs       : Array[0..MAX_PARAM - 1] Of Boolean;
  PCount      : Integer;
  I           : Integer;
  Idx         : Integer;
  POfStr      : TString;
  SaveRetLbl  : TString;
  SaveFrame   : Integer;
  NS          : TString;
  E           : TExprVal;
Begin
  ParserAdvance;   { consommer 'function' }
  { nom de la fonction }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    WriteLn('PHP86:', CurToken.Line, ': erreur: nom de fonction attendu');
    Inc(ErrorCount); Exit;
  End;
  FnName    := CurToken.Val;
  FnMangled := PH_FN_PFX + FnName;
  ParserAdvance;
  { enregistrer dans la table des symboles }
  If SymFindCat(FnName, SC_FN) < 0 Then
    Idx := SymAdd(FnName, SC_FN, TY_IDX_MIXED, False, 0, CurToken.Line);
  { labels }
  Inc(LabelSeq); Str(LabelSeq, NS);
  RetLbl := PH_LBL_PFX + 'FNRET_' + NS;
  EndLbl := FnMangled + '_END';
  { JMP par-dessus le corps (les fonctions sont definies inline) }
  EmitInstr('JMP', EndLbl);
  EmitBlankLine;
  EmitComment('function ' + FnName);
  EmitLabel(FnMangled);
  EmitInstr('PUSH', 'BP');
  EmitInstr('MOV',  'BP, SP');
  EmitComment('frame function ' + FnName + ' (locaux alloues incrementalement)');
  { analyser la liste des parametres }
  PCount := 0;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
  Begin
    ParserAdvance;   { '(' }
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')'))
          And (CurToken.Kind <> TK_EOF) Do
    Begin
      { parametre variadique ...$arg (non supporte) }
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '...') Then
      Begin
        WriteLn('PHP86:', CurToken.Line, ': avert: parametre variadique ignore');
        Inc(WarnCount);
        While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')'))
              And (CurToken.Kind <> TK_EOF) Do ParserAdvance;
        Break;
      End;
      { &$param : par reference }
      PRefs[PCount] := False;
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '&') Then
      Begin
        PRefs[PCount] := True;
        ParserAdvance;
      End;
      { $paramname }
      If CurToken.Kind = TK_VAR Then
      Begin
        PNames[PCount] := CurToken.Val;
        ParserAdvance;
        { valeur par defaut : $p = expr (on emet un aversion et on ignore) }
        If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
        Begin
          ParserAdvance;   { consommer '=' }
          EmitComment('parametre par defaut $' + PNames[PCount]);
          { consommer l''expression sans emettre de code utile }
          While Not ((CurToken.Kind = TK_PUNCT) And
                     ((CurToken.Val = ',') Or (CurToken.Val = ')')))
                And (CurToken.Kind <> TK_EOF) Do
            ParserAdvance;
        End;
        Inc(PCount);
        If PCount >= MAX_PARAM Then Break;
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;
  End;
  { sauvegarder contexte de la fonction englobante }
  SaveRetLbl := CurFnRetLbl;
  SaveFrame  := CurFrameSize;
  CurFnRetLbl  := RetLbl;
  CurFrameSize := 0;
  Inc(CurFnDepth);
  { entrer dans la portee de la fonction }
  SymEnterScope;
  { enregistrer les parametres : $p1 au plus haut offset, $pN au plus bas }
  { push gauche->droite : $p1 en premier, donc [BP+4+(n-1)*2] }
  For I := 0 To PCount - 1 Do
  Begin
    Idx := SymAdd(PNames[I], SC_PARAM, TY_IDX_MIXED,
                  PRefs[I], 4 + 2 * (PCount - 1 - I), CurToken.Line);
    Str(4 + 2 * (PCount - 1 - I), POfStr);
    EmitComment('param $' + PNames[I] + ' = [BP+' + POfStr + ']');
  End;
  { corps de la fonction }
  ParseBlock;
  { epilogue }
  EmitLabel(RetLbl);
  EmitInstr('MOV', 'SP, BP');   { restaurer SP (libere les locaux) }
  EmitInstr('POP', 'BP');
  EmitInstr('RET', '');
  { fermer la portee }
  SymLeaveScope;
  Dec(CurFnDepth);
  CurFnRetLbl  := SaveRetLbl;
  CurFrameSize := SaveFrame;
  EmitLabel(EndLbl);
  EmitBlankLine;
End;

{ ============================================================
  TODO 18 - PORTEE, PILE ET CADRES
  ============================================================ }

{ ---- BlockEnterScope : entrer dans un sous-bloc ------------ }
{ Sauvegarde CurFrameSize et ouvre une portee de symboles.    }
{ Retourne la taille du cadre avant ce bloc (pour BlockLeave).}
Function BlockEnterScope : Integer;
Begin
  SymEnterScope;
  BlockEnterScope := CurFrameSize;
End;

{ ---- BlockLeaveScope : quitter un sous-bloc ---------------- }
{ SavedFrame = valeur retournee par BlockEnterScope.          }
{ Ferme la portee de symboles et restaure CurFrameSize.       }
{ Si on est a l''exterieur d''une fonction (CurFnDepth=0)     }
{ ET que des octets ont ete alloues : emet ADD SP, delta.     }
{ A l''interieur d''une fonction, MOV SP,BP dans l''epilogue   }
{ restaure tout : pas besoin d''ADD SP par bloc.              }
Procedure BlockLeaveScope(SavedFrame : Integer);
Var
  Delta : Integer;
  DS    : TString;
Begin
  Delta := SavedFrame - CurFrameSize;   { octets alloues dans ce bloc }
  SymLeaveScope;
  CurFrameSize := SavedFrame;           { restaurer le compteur }
  If (Delta > 0) And (CurFnDepth = 0) Then
  Begin
    Str(Delta, DS);
    EmitInstr('ADD', 'SP, ' + DS);      { liberer les locaux hors-fonction }
  End;
End;

{ ============================================================
  TODO 19 - TABLEAUX : array(), [], $a[i], count, array_push
  ============================================================ }

{ ---- ParseArrayLit : array(v1,...) ou [v1,...] ------------- }
{ CurToken = 'array' (TK_KEYWORD) ou '[' (TK_PUNCT) a l''entree.  }
{ Disposition DATA : DW count, DW e0, DW e1, ...              }
{ Retourne EK_AX avec AX = OFFSET label (pointe sur count).   }
Procedure ParseArrayLit(Var Res : TExprVal);
Var
  Elems    : Array[0..63] Of LongInt;
  ECount   : Integer;
  I        : Integer;
  E        : TExprVal;
  ArrSeq   : TString;
  ArrLbl   : TString;
  ELbl     : TString;
  NS       : TString;
  CloseStr : TString;
Begin
  ExprMakeNone(Res);
  { Determiner syntaxe : array(...) ou [...] }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'array') Then
  Begin
    ParserAdvance;  { consommer 'array' }
    If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
    Begin
      WriteLn('PHP86:', CurToken.Line, ': erreur: ''('' attendu apres array');
      Inc(ErrorCount); Exit;
    End;
    ParserAdvance;  { consommer '(' }
    CloseStr := ')';
  End
  Else
  Begin
    ParserAdvance;  { consommer '[' }
    CloseStr := ']';
  End;
  ECount := 0;
  While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = CloseStr))
        And (CurToken.Kind <> TK_EOF) Do
  Begin
    ParseExpr(E);
    { Detection tableau associatif : expr => val }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '=>') Then
    Begin
      WriteLn('PHP86:', CurToken.Line,
              ': avert: tableau associatif non supporte, cle ignoree');
      Inc(WarnCount);
      ParserAdvance;  { consommer '=>' }
      ParseExpr(E);   { valeur (remplace la cle) }
    End;
    If ECount < 64 Then
    Begin
      If E.Kind = EK_IMM Then
        Elems[ECount] := E.ImmVal
      Else
      Begin
        WriteLn('PHP86:', CurToken.Line,
                ': avert: element tableau non-constant ignore, 0 emis');
        Inc(WarnCount);
        Elems[ECount] := 0;
      End;
      Inc(ECount);
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance;
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = CloseStr) Then
    ParserAdvance;
  { Generer label unique pour ce tableau }
  Str(LabelSeq, ArrSeq); Inc(LabelSeq);
  ArrLbl := PH_STR_PFX + 'ARR' + ArrSeq;
  { Premier mot DATA = count (avec le label du tableau) }
  DataAddWord(ArrLbl, ECount);
  { Mots suivants = elements (labels derives) }
  For I := 0 To ECount - 1 Do
  Begin
    Str(I, NS);
    ELbl := ArrLbl + '_' + NS;
    DataAddWord(ELbl, Elems[I]);
  End;
  { Retourner AX = OFFSET du label (pointe sur le mot count) }
  EmitInstr('MOV', 'AX, OFFSET ' + ArrLbl);
  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_MIXED;
  Res.Offset  := 0;
  Res.ImmVal  := 0;
End;

{ ============================================================
  TODO 21 - CLASSES PHP (BASIQUE)
  ============================================================ }

{ ---- ParseNewExpr : allouer un objet, appeler son constructeur }
{ ClsName = nom PHP de la classe ; CurToken est apres le nom.  }
{ Allocation sur la pile de l''appelant : SUB SP, ObjSize.     }
{ $this = SI = ptr objet. Convention : $this pousse EN DERNIER }
{   => methodeName([BP+4] = $this, [BP+6] = arg0, ...).        }
Procedure ParseNewExpr(Const ClsName : TString; Var Res : TExprVal);
Var
  CIdx     : Integer;
  I        : Integer;
  ArgCount : Integer;
  SzStr    : TString;
  AStr     : TString;
  CtorFn   : TString;
  E        : TExprVal;
Begin
  ExprMakeNone(Res);
  { Localiser la classe dans ClassTab }
  CIdx := -1;
  For I := 0 To ClassCount - 1 Do
    If ClassTab[I].ClsName = ClsName Then Begin CIdx := I; Break; End;
  If CIdx < 0 Then
  Begin
    WriteLn('PHP86:', CurToken.Line, ': avert: classe ''', ClsName, ''' inconnue, nil emis');
    Inc(WarnCount);
    EmitInstr('XOR', 'AX, AX');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      ParserAdvance;
      While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')'))
            And (CurToken.Kind <> TK_EOF) Do ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        ParserAdvance;
    End;
    Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_MIXED;
    Res.Offset := 0; Res.ImmVal := 0; Exit;
  End;
  { Allouer l''objet sur la pile (SUB SP, ObjSize) }
  If ClassTab[CIdx].ObjSize > 0 Then
  Begin
    Str(ClassTab[CIdx].ObjSize, SzStr);
    EmitInstr('SUB', 'SP, ' + SzStr);
    Inc(CurFrameSize, ClassTab[CIdx].ObjSize);
    { Zeroinit : effacer les mots de l''objet }
    EmitInstr('MOV', 'SI, SP');
    EmitComment('zeroinit: ' + ClsName + ' (' + SzStr + ' octets)');
    For I := 0 To ClassTab[CIdx].ObjSize Div 2 - 1 Do
    Begin
      Str(I * 2, AStr);
      EmitInstr('MOV', 'WORD PTR [SI+' + AStr + '], 0');
    End;
  End
  Else
    EmitInstr('MOV', 'SI, SP');
  { SI = ptr $this }
  { Verifier si un constructeur __construct existe }
  CtorFn := '';
  For I := 0 To ClassTab[CIdx].MethCount - 1 Do
    If ClassTab[CIdx].MethNames[I] = '__construct' Then
    Begin
      CtorFn := PH_FN_PFX + ClsName + '____construct';
      Break;
    End;
  { Parser et pousser les arguments du constructeur }
  ArgCount := 0;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
  Begin
    ParserAdvance;  { consommer '(' }
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')'))
          And (CurToken.Kind <> TK_EOF) Do
    Begin
      ParseExpr(E);
      ExprLoad(E);
      EmitInstr('PUSH', 'AX');
      Inc(ArgCount);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;
  End;
  If CtorFn <> '' Then
  Begin
    EmitInstr('PUSH', 'SI');           { $this en dernier = [BP+4] }
    EmitInstr('CALL', CtorFn);
    Str((ArgCount + 1) * 2, AStr);    { nettoyer args + $this }
    EmitInstr('ADD', 'SP, ' + AStr);
  End
  Else If ArgCount > 0 Then
  Begin
    WriteLn('PHP86:', CurToken.Line,
            ': avert: classe ''', ClsName,
            ''' sans __construct, ', ArgCount, ' arg(s) ignores');
    Inc(WarnCount);
    Str(ArgCount * 2, AStr);
    EmitInstr('ADD', 'SP, ' + AStr);
  End;
  EmitInstr('MOV', 'AX, SI');        { retourner le ptr objet }
  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_PRIM_COUNT + CIdx;   { encode la classe }
  Res.Offset  := 0;
  Res.ImmVal  := 0;
End;

{ ---- ParseClassDecl : class Name [extends P] with members -- }
{ CurToken = TK_KEYWORD 'class' a l''entree.                  }
{ Proprietes : enregistrees dans ClassTab, taille objet=2*n.  }
{ Methodes   : emises comme _PHF_ClsName__methName.           }
{   $this est le DERNIER argument depile = [BP+4].            }
Procedure ParseClassDecl;
Var
  ClsName     : TString;
  ParentNm    : TString;
  MethName    : TString;
  MethMangled : TString;
  CIdx        : Integer;
  PCount      : Integer;
  MCount      : Integer;
  ObjSz       : Integer;
  DeclLine    : Integer;
  PropName    : TString;
  E           : TExprVal;
  NS          : TString;
  I           : Integer;
  PNames      : Array[0..MAX_CLASS_METH - 1] Of TString;
  PRefs       : Array[0..MAX_CLASS_METH - 1] Of Boolean;
  PPCount     : Integer;
  POfStr      : TString;
  SaveRetLbl  : TString;
  SaveFrame   : Integer;
  SaveDepth   : Integer;
  RetLbl      : TString;
  EndLbl      : TString;
Begin
  ParserAdvance;   { consommer 'class' }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    WriteLn('PHP86:', CurToken.Line, ': erreur: nom de classe attendu');
    Inc(ErrorCount); Exit;
  End;
  ClsName  := CurToken.Val;
  DeclLine := CurToken.Line;
  ParserAdvance;
  ParentNm := '';
  { extends : heritage non supporte }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'extends') Then
  Begin
    ParserAdvance;
    If CurToken.Kind = TK_IDENT Then
    Begin
      ParentNm := CurToken.Val;
      WriteLn('PHP86:', DeclLine, ': avert: heritage de ''',
              ParentNm, ''' non supporte, ignore');
      Inc(WarnCount);
      ParserAdvance;
    End;
  End;
  { implements : ignore }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'implements') Then
  Begin
    WriteLn('PHP86:', DeclLine, ': avert: implements non supporte, ignore');
    Inc(WarnCount);
    ParserAdvance;
    While (CurToken.Kind = TK_IDENT) Or
          ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',')) Do
      ParserAdvance;
  End;
  { Creer l''entree dans ClassTab }
  If ClassCount >= MAX_CLASS Then
  Begin
    WriteLn('PHP86:', DeclLine, ': erreur: trop de classes (max ', MAX_CLASS, ')');
    Inc(ErrorCount); Exit;
  End;
  CIdx := ClassCount; Inc(ClassCount);
  ClassTab[CIdx].ClsName    := ClsName;
  ClassTab[CIdx].ParentName := ParentNm;
  ClassTab[CIdx].PropCount  := 0;
  ClassTab[CIdx].MethCount  := 0;
  ClassTab[CIdx].ObjSize    := 0;
  CurClsIdx := CIdx;
  { Enregistrer la classe dans SymTab }
  SymAdd(ClsName, SC_CLASS, TY_IDX_MIXED, False, CIdx, DeclLine);
  { Ouvrir le corps }
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{')) Then
  Begin
    WriteLn('PHP86:', CurToken.Line, ': erreur: ''{'' attendu apres nom de classe');
    Inc(ErrorCount); Exit;
  End;
  ParserAdvance;  { consommer '{' }
  ObjSz  := 0;  PCount := 0;  MCount := 0;
  While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}'))
        And (CurToken.Kind <> TK_EOF) Do
  Begin
    { Ignorer les modificateurs de visibilite }
    While (CurToken.Kind = TK_KEYWORD) And
          ((CurToken.Val = 'public')   Or (CurToken.Val = 'protected') Or
           (CurToken.Val = 'private')  Or (CurToken.Val = 'static')    Or
           (CurToken.Val = 'abstract') Or (CurToken.Val = 'final')     Or
           (CurToken.Val = 'readonly')) Do
      ParserAdvance;
    { Propriete : $prop [= val]; }
    If CurToken.Kind = TK_VAR Then
    Begin
      PropName := CurToken.Val;
      ParserAdvance;
      If PCount < MAX_CLASS_PROP Then
      Begin
        ClassTab[CIdx].Props[PCount].PropName := PropName;
        ClassTab[CIdx].Props[PCount].PropOff  := ObjSz;
        ClassTab[CIdx].Props[PCount].PropType := TY_IDX_MIXED;
        Inc(PCount); Inc(ObjSz, 2);
      End
      Else
      Begin
        WriteLn('PHP86:', CurToken.Line,
                ': avert: trop de proprietes dans ''', ClsName, '''');
        Inc(WarnCount);
      End;
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
      Begin
        ParserAdvance; ParseExpr(E);   { valeur initiale ignoree }
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        ParserAdvance;
    End
    { Methode : function methName(params) + body }
    Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'function') Then
    Begin
      ParserAdvance;  { consommer 'function' }
      If CurToken.Kind <> TK_IDENT Then
      Begin
        WriteLn('PHP86:', CurToken.Line, ': erreur: nom de methode attendu');
        Inc(ErrorCount); Break;
      End;
      MethName    := CurToken.Val;
      DeclLine    := CurToken.Line;
      MethMangled := PH_FN_PFX + ClsName + '__' + MethName;
      ParserAdvance;
      If MCount < MAX_CLASS_METH Then
      Begin
        ClassTab[CIdx].MethNames[MCount] := MethName;
        Inc(MCount);
      End;
      { Prologue : JMP over body + label + PUSH BP + MOV BP,SP }
      EndLbl := MethMangled + '_END';
      EmitInstr('JMP', EndLbl);
      EmitLabel(MethMangled);
      EmitInstr('PUSH', 'BP');
      EmitInstr('MOV',  'BP, SP');
      { Sauvegarder contexte }
      SaveRetLbl := CurFnRetLbl;
      SaveFrame  := CurFrameSize;
      SaveDepth  := CurFnDepth;
      Inc(LabelSeq); Str(LabelSeq, NS);
      RetLbl := PH_LBL_PFX + 'METR' + NS;
      CurFnRetLbl  := RetLbl;
      CurFrameSize := 0;
      CurFnDepth   := CurFnDepth + 1;
      SymEnterScope;
      { Parser les parametres explicites }
      PPCount := 0;
      If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
      Begin
        WriteLn('PHP86:', CurToken.Line, ': erreur: ''('' attendu');
        Inc(ErrorCount);
      End
      Else
      Begin
        ParserAdvance;  { consommer '(' }
        While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')'))
              And (CurToken.Kind <> TK_EOF) Do
        Begin
          If (CurToken.Kind = TK_OP) And (CurToken.Val = '&') Then
          Begin
            If PPCount < MAX_CLASS_METH Then PRefs[PPCount] := True;
            ParserAdvance;
          End
          Else
            If PPCount < MAX_CLASS_METH Then PRefs[PPCount] := False;
          If CurToken.Kind = TK_VAR Then
          Begin
            If PPCount < MAX_CLASS_METH Then PNames[PPCount] := CurToken.Val;
            Inc(PPCount);
            ParserAdvance;
          End;
          If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
          Begin
            ParserAdvance; ParseExpr(E);  { valeur par defaut ignoree }
          End;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
      End;
      { Enregistrer $this = [BP+4] (dernier pousse = le plus proche BP) }
      { Params : param[PPCount-1] = [BP+6], ..., param[0] = [BP+4+PPCount*2] }
      {          $this                             = [BP+4]                   }
      SymAdd('this', SC_PARAM, TY_PRIM_COUNT + CIdx, False, 4, DeclLine);
      For I := 0 To PPCount - 1 Do
      Begin
        Str(6 + I * 2, POfStr);
        SymAdd(PNames[I], SC_PARAM, TY_IDX_MIXED, PRefs[I],
               6 + I * 2, DeclLine);
      End;
      { Corps de la methode }
      ParseBlock;
      { Epilogue }
      EmitLabel(RetLbl);
      EmitInstr('MOV', 'SP, BP');
      EmitInstr('POP', 'BP');
      EmitInstr('RET', '');
      EmitLabel(EndLbl);
      SymLeaveScope;
      CurFnRetLbl  := SaveRetLbl;
      CurFrameSize := SaveFrame;
      CurFnDepth   := SaveDepth;
    End
    Else
    Begin
      { Membre non reconnu }
      If CurToken.Kind <> TK_EOF Then
      Begin
        WriteLn('PHP86:', CurToken.Line,
                ': avert: membre ''', CurToken.Val, ''' non reconnu dans ''',
                ClsName, ''', ignore');
        Inc(WarnCount);
        ParserAdvance;
      End;
    End;
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
    ParserAdvance;
  { Finaliser la classe }
  ClassTab[CIdx].PropCount := PCount;
  ClassTab[CIdx].MethCount := MCount;
  ClassTab[CIdx].ObjSize   := ObjSz;
  CurClsIdx := -1;
  If Opts.Verbose Then
    WriteLn('PHP86: classe ''', ClsName, ''' : ',
            PCount, ' prop., ', MCount, ' meth., taille=', ObjSz, 'o');
End;

{ ---- Compilation principale (stub -- completer TODO 19+) -- }
Procedure Run;
Begin
  TypeInit;
  SymInit;
  EmitOpen;
  If ErrorCount > 0 Then Exit;
  EmitHeader;
  LexInit;
  ParserAdvance;
  { En mode debug, consommer tous les tokens pour tester le lexeur }
  If Opts.DebugTok Then
    While CurToken.Kind <> TK_EOF Do
      ParserAdvance;
  { TODO 25 : boucle ParseTopLevel + EmitRuntime + EmitDataSeg }
  If Opts.Verbose Then
    WriteLn('PHP86: ', TotalLines, ' ligne(s) lues depuis ', Opts.SrcFile);
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Begin
  ErrorCount   := 0;
  WarnCount    := 0;
  TotalLines   := 0;
  TotalSyms    := 0;
  LexOpened    := False;
  OutFOpen     := False;
  InPhpMode    := False;
  SymCount     := 0;
  ScopeTop     := 0;
  CurScope     := 0;
  LabelSeq     := 0;
  TypeCount    := 0;
  DataCount    := 0;
  CurFrameSize := 0;
  CurFnDepth   := 0;
  LoopTop      := 0;
  CurFnRetLbl  := '';
  RuntimeEmitted := False;
  ClassCount   := 0;
  CurClsIdx    := -1;
  GExprDummy.Kind    := EK_NONE;
  GExprDummy.ImmVal  := 0;
  GExprDummy.TypeIdx := TY_UNKNOWN;
  GExprDummy.Offset  := 0;
  InitOptions;
  ParseArgs;
  ShowBanner;
  Run;
  Cleanup;
  If Opts.Verbose Then ShowStats;
  If ErrorCount > 0 Then
    Halt(EXIT_ERROR)
  Else
    Halt(EXIT_OK);
End.
