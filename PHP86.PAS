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
  LoopTop      : Integer;
  LoopBreakLbl : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopContLbl  : Array[0..MAX_LOOP_NEST - 1] Of TString;

  { Segment de donnees }
  DataTab   : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount : Integer;

  { Etat general }
  RuntimeEmitted : Boolean;
  InPhpMode      : Boolean;  { True quand on est a l'interieur de <?php ... ?> }

{ ============================================================
  FORWARD DECLARATIONS
  ============================================================ }
Procedure LexClose;      Forward;
Procedure EmitClose;     Forward;
Procedure ParserAdvance; Forward;

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
      { TODO 08 : DataAdd + MOV AX, OFFSET label }
      { Pour l''instant : valeur nulle en attente de l''emetteur }
      ExprMakeImm(0, TY_IDX_STRING, Res);
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
                If E.Offset >= 0 Then Begin
                  Str(E.Offset, S);
                  EmitInstr('MOV', 'AX, [BP+' + S + ']');
                End Else Begin
                  Str(-E.Offset, S);
                  EmitInstr('MOV', 'AX, [BP-' + S + ']');
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
  Operateurs PHP couverts :
    + - * / % ** (arith)   . (concat)
    == != === !== <=> < <= > >= (comparaison)
    && || & | ^ << >> (logique/bitwise)
    and or xor (mots-cles logiques)
    ?? (null-coalesce)                                      }
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
    Else If Op = '.'   Then L.ImmVal := 0  { concat constante : TODO 08 }
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
    End
    Else If Op = '??'  Then
    Begin
      If L.ImmVal = 0 Then L.ImmVal := R.ImmVal;  { simule null-coalesce }
    End;
    L.TypeIdx := TY_IDX_INT;
    Exit;
  End;

  { ---- Cas general : emission 8086 ------------------------ }
  ExprLoad(L);
  If R.Kind = EK_IMM Then
  Begin
    Str(R.ImmVal, RS);
    If      Op = '+'   Then EmitInstr('ADD',  'AX, ' + RS)
    Else If Op = '-'   Then EmitInstr('SUB',  'AX, ' + RS)
    Else If Op = '&'   Then EmitInstr('AND',  'AX, ' + RS)
    Else If Op = '|'   Then EmitInstr('OR',   'AX, ' + RS)
    Else If Op = '^'   Then EmitInstr('XOR',  'AX, ' + RS)
    Else If Op = '<<'  Then EmitInstr('SHL',  'AX, ' + RS)
    Else If Op = '>>'  Then EmitInstr('SHR',  'AX, ' + RS)
    Else If Op = '*'   Then EmitInstr('IMUL', RS)
    Else If Op = '**'  Then
    Begin
      EmitInstr('MOV', 'CX, ' + RS);
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
      EmitInstr('MOV', 'BX, ' + RS);
      EmitInstr('CALL', PH_RT_PFX + 'CONCAT');
    End
    Else If Op = '==' Then Begin EmitInstr('CMP','AX,'+RS); EmitInstr('MOV','AX,0'); EmitInstr('SETE','AL'); End
    Else If Op = '!=' Then Begin EmitInstr('CMP','AX,'+RS); EmitInstr('MOV','AX,0'); EmitInstr('SETNE','AL'); End
    Else If Op = '==='Then Begin EmitInstr('CMP','AX,'+RS); EmitInstr('MOV','AX,0'); EmitInstr('SETE','AL'); End
    Else If Op = '!=='Then Begin EmitInstr('CMP','AX,'+RS); EmitInstr('MOV','AX,0'); EmitInstr('SETNE','AL'); End
    Else If Op = '<'  Then Begin EmitInstr('CMP','AX,'+RS); EmitInstr('MOV','AX,0'); EmitInstr('SETL','AL'); End
    Else If Op = '<=' Then Begin EmitInstr('CMP','AX,'+RS); EmitInstr('MOV','AX,0'); EmitInstr('SETLE','AL'); End
    Else If Op = '>'  Then Begin EmitInstr('CMP','AX,'+RS); EmitInstr('MOV','AX,0'); EmitInstr('SETG','AL'); End
    Else If Op = '>=' Then Begin EmitInstr('CMP','AX,'+RS); EmitInstr('MOV','AX,0'); EmitInstr('SETGE','AL'); End
    Else If Op = '<=>'Then
    Begin
      Lbl1 := NextLabelSeq; Lbl2 := NextLabelSeq; LblE := NextLabelSeq;
      EmitInstr('CMP',  'AX, ' + RS);
      EmitInstr('JL',   Lbl1);
      EmitInstr('JG',   Lbl2);
      EmitInstr('MOV',  'AX, 0');
      EmitInstr('JMP',  LblE);
      EmitLabel(Lbl1); EmitInstr('MOV','AX, -1'); EmitInstr('JMP', LblE);
      EmitLabel(Lbl2); EmitInstr('MOV','AX, 1');
      EmitLabel(LblE);
    End
    Else If Op = '&&' Then EmitInstr('AND', 'AX, ' + RS)
    Else If Op = '||' Then EmitInstr('OR',  'AX, ' + RS)
    Else If (Op='and') Or (Op='or') Then EmitInstr('OR', 'AX, ' + RS);
  End Else
  Begin
    { R non immediat : sauvegarder L, charger R dans BX }
    EmitInstr('PUSH', 'AX');
    ExprLoad(R);
    EmitInstr('MOV',  'BX, AX');
    EmitInstr('POP',  'AX');
    If      Op = '+'  Then EmitInstr('ADD',  'AX, BX')
    Else If Op = '-'  Then EmitInstr('SUB',  'AX, BX')
    Else If Op = '&'  Then EmitInstr('AND',  'AX, BX')
    Else If Op = '|'  Then EmitInstr('OR',   'AX, BX')
    Else If Op = '^'  Then EmitInstr('XOR',  'AX, BX')
    Else If Op = '*'  Then EmitInstr('IMUL', 'BX')
    Else If Op = '**' Then EmitInstr('CALL', PH_RT_PFX + 'POWER')
    Else If Op = '/'  Then Begin EmitInstr('CWD',''); EmitInstr('IDIV','BX'); End
    Else If Op = '%'  Then Begin EmitInstr('CWD',''); EmitInstr('IDIV','BX'); EmitInstr('MOV','AX,DX'); End
    Else If Op = '.'  Then EmitInstr('CALL', PH_RT_PFX + 'CONCAT')
    Else
    Begin
      EmitInstr('CMP', 'AX, BX');
      EmitInstr('MOV', 'AX, 0');
      If      Op = '===' Then EmitInstr('SETE','AL')
      Else If Op = '==' Then EmitInstr('SETE','AL')
      Else If Op = '!==' Then EmitInstr('SETNE','AL')
      Else If Op = '!=' Then EmitInstr('SETNE','AL')
      Else If Op = '<'  Then EmitInstr('SETL','AL')
      Else If Op = '<=' Then EmitInstr('SETLE','AL')
      Else If Op = '>'  Then EmitInstr('SETG','AL')
      Else If Op = '>=' Then EmitInstr('SETGE','AL')
      Else If Op = '<=>'Then
      Begin
        Lbl1 := NextLabelSeq; Lbl2 := NextLabelSeq; LblE := NextLabelSeq;
        EmitInstr('JL',  Lbl1);
        EmitInstr('JG',  Lbl2);
        EmitInstr('MOV', 'AX, 0');
        EmitInstr('JMP', LblE);
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

{ ---- ParsePrimary (stub, TODO 10 completera) ------------ }
Procedure ParsePrimary(Var Res : TExprVal);
Begin
  ExprMakeNone(Res);
  Case CurToken.Kind Of
    TK_INTEGER : Begin LitEvalInt(CurToken, Res);   ParserAdvance; End;
    TK_FLOAT   : Begin LitEvalFloat(CurToken, Res);  ParserAdvance; End;
    TK_STRING  : Begin LitEval(CurToken, Res);       ParserAdvance; End;
    TK_KEYWORD :
    Begin
      If (CurToken.Val = 'true')  Or (CurToken.Val = 'TRUE')  Or
         (CurToken.Val = 'false') Or (CurToken.Val = 'FALSE') Or
         (CurToken.Val = 'null')  Or (CurToken.Val = 'NULL') Then
      Begin
        LitEvalBool(CurToken, Res); ParserAdvance;
      End Else
      Begin
        WriteLn('PHP86:', CurToken.Line, ': erreur: expression attendue, mot-cle: ', CurToken.Val);
        Inc(ErrorCount); ParserAdvance;
      End;
    End;
    TK_OP :
    Begin
      { Operateurs unaires : - ! ~ }
      If CurToken.Val = '-' Then
      Begin
        ParserAdvance; ParseExprPrec(14, Res);
        If Res.Kind = EK_IMM Then Res.ImmVal := -Res.ImmVal
        Else Begin ExprLoad(Res); EmitInstr('NEG', 'AX'); End;
      End Else If CurToken.Val = '!' Then
      Begin
        ParserAdvance; ParseExprPrec(14, Res);
        If Res.Kind = EK_IMM Then Begin If Res.ImmVal <> 0 Then Res.ImmVal := 0 Else Res.ImmVal := 1; End
        Else Begin ExprLoad(Res); EmitInstr('TEST','AX,AX'); EmitInstr('MOV','AX,0'); EmitInstr('SETE','AL'); End;
      End Else If CurToken.Val = '~' Then
      Begin
        ParserAdvance; ParseExprPrec(14, Res);
        If Res.Kind = EK_IMM Then Res.ImmVal := Not Res.ImmVal
        Else Begin ExprLoad(Res); EmitInstr('NOT', 'AX'); End;
      End Else
      Begin
        WriteLn('PHP86:', CurToken.Line, ': erreur: expression inattendue: ', CurToken.Val);
        Inc(ErrorCount); ParserAdvance;
      End;
    End;
    TK_PUNCT :
    Begin
      { Groupement ( expr ) }
      If CurToken.Val = '(' Then
      Begin
        ParserAdvance;
        ParseExprPrec(1, Res);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
      End Else
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

{ ---- ParseExprPrec : boucle Pratt (corps du Forward) ----- }
Procedure ParseExprPrec; { signatura uniquement via Forward }
Var
  L    : TExprVal;
  R    : TExprVal;
  Op   : TString;
  Prec : Integer;
Begin
  ParsePrimary(L);
  { Operateurs binaires TK_OP }
  While CurToken.Kind = TK_OP Do
  Begin
    Op   := CurToken.Val;
    Prec := BinOpPrec(Op);
    If Prec < MinPrec Then Break;
    ParserAdvance;
    If IsRightAssoc(Op) Then
      ParseExprPrec(Prec, R)
    Else
      ParseExprPrec(Prec + 1, R);
    ExprEmitBinOp(Op, L, R);
  End;
  { Mots-cles binaires : and or xor }
  While CurToken.Kind = TK_KEYWORD Do
  Begin
    Op   := CurToken.Val;
    Prec := BinOpPrec(Op);
    If Prec < MinPrec Then Break;
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
    WriteLn(OutF);
    WriteLn(OutF, '        END');
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ---- Compilation principale (stub -- completer TODO 07+) -- }
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
  LoopTop      := 0;
  RuntimeEmitted := False;
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
