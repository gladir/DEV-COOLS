{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Agent conversationnel generateur de code Turbo Pascal
}

(* Voir DOC/TODO/PASCHAT.txt pour la feuille de route des 25 TODOs *)

Program PASCHAT;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
            TOptions (Verbose, DebugMode, LearnFiles)
            ParseArgs : analyser argv ([-v] [-d] [-h] [fichiers.txt...])
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Charger la liste des fichiers .txt d'apprentissage en ligne de commande
            Programme principal : validation des arguments et appel Run
            Version, Date, aide en ligne (option -h)
            InitOptState, GenOptLabel, OptTypeName
            DumpOptState, 10 accesseurs (IsOptInitialized, IsOptEmpty, ...)
  ============================================================ }

{ ============================================================
  TODO 02 - CHARGEMENT DES FICHIERS D'APPRENTISSAGE [IMPLEMENTE]
            TLearnFile : FileName, Content, LineCount
            LoadLearnFile(FileName) : charger un fichier .txt en memoire
            LearnFiles[0..MAX_LEARN-1], LearnCount
            Supporter les fichiers DOC/*.txt comme base de connaissances
            IndexLearnContent : indexer le contenu pour recherche rapide
            FindInLearnFiles(Query) : rechercher dans les fichiers charges
            InitLearnState, GenLrnLabel, LrnTypeName, DumpLearnState
            10 accesseurs (IsLrnInitialized, IsLrnEmpty, GetLrn*Count, ...)
  ============================================================ }

{ ============================================================
  TODO 03 - HISTORIQUE DE CONVERSATION [IMPLEMENTE]
            THistoryEntry : UserInput, BotResponse, Timestamp
            History[0..MAX_HISTORY-1], HistoryCount
            AddToHistory(User, Bot) : ajouter une entree a l'historique
            GetRecentHistory(N) : obtenir les N dernieres entrees
            ClearHistory : vider l'historique de conversation
            SaveHistory(FileName) : sauvegarder l'historique dans un fichier
            LoadHistory(FileName) : charger l'historique depuis un fichier
            InitHisState, GenHisLabel, HisTypeName, DumpHisState
            10 accesseurs (IsHisInitialized, IsHisEmpty, GetHis*Count, ...)
  ============================================================ }

{ ============================================================
  TODO 04 - ANALYSEUR DE REQUETES UTILISATEUR [A FAIRE]
            TIntentKind : IK_UNKNOWN, IK_HELLO, IK_PROGRAM, IK_UNIT,
              IK_PROCEDURE, IK_FUNCTION, IK_EXPLAIN, IK_HELP, IK_QUIT
            TIntent : Kind, Subject, Keywords, Params
            ParseUserInput(Input) : analyser l'entree utilisateur
            DetectIntent(Input) : determiner l'intention de l'utilisateur
            ExtractKeywords(Input) : extraire les mots-cles de la requete
            KeywordMatch(Input, Keywords) : verifier la presence de mots-cles
  ============================================================ }

{ ============================================================
  TODO 05 - GENERATEUR DE CODE PASCAL - STRUCTURES DE BASE [A FAIRE]
            GenProgramHeader(Name) : generer l'entete PROGRAM
            GenUnitHeader(Name) : generer l'entete UNIT
            GenUsesClause(Units) : generer la clause USES
            GenConstSection(Consts) : generer la section CONST
            GenVarSection(Vars) : generer la section VAR
            GenTypeSection(Types) : generer la section TYPE
            GenBeginEnd : generer le bloc BEGIN...END principal
  ============================================================ }

{ ============================================================
  TODO 06 - GENERATEUR DE CODE PASCAL - TYPES ET VARIABLES [A FAIRE]
            TTypeInfo : Name, Kind (TK_INTEGER, TK_STRING, TK_REAL,
              TK_BOOLEAN, TK_CHAR, TK_ARRAY, TK_RECORD, TK_POINTER)
            TVarInfo : Name, TypeName, InitValue
            GenVarDecl(Var) : generer une declaration de variable
            GenConstDecl(Name, Value) : generer une declaration de constante
            GenTypeDecl(Type) : generer une declaration de type
            GenArrayType(Name, Bounds, BaseType) : generer un type tableau
            GenRecordType(Name, Fields) : generer un type enregistrement
  ============================================================ }

{ ============================================================
  TODO 07 - GENERATEUR DE CODE PASCAL - EXPRESSIONS [A FAIRE]
            GenExpression(Expr) : generer une expression
            GenAssignment(Var, Expr) : generer une affectation
            GenArithExpr(Op, Left, Right) : generer une expression arithmetique
            GenCompareExpr(Op, Left, Right) : generer une comparaison
            GenLogicalExpr(Op, Left, Right) : generer une expression logique
            GenFunctionCall(Name, Args) : generer un appel de fonction
            GenStringExpr(Parts) : generer une concatenation de chaines
  ============================================================ }

{ ============================================================
  TODO 08 - GENERATEUR DE CODE PASCAL - STRUCTURES DE CONTROLE [A FAIRE]
            GenIfThenElse(Cond, ThenPart, ElsePart) : generer IF..THEN..ELSE
            GenForLoop(Var, Start, End, Body) : generer FOR..TO..DO
            GenWhileLoop(Cond, Body) : generer WHILE..DO
            GenRepeatUntil(Body, Cond) : generer REPEAT..UNTIL
            GenCaseOf(Expr, Cases) : generer CASE..OF
            GenWithDo(Vars, Body) : generer WITH..DO
  ============================================================ }

{ ============================================================
  TODO 09 - GENERATEUR DE CODE PASCAL - PROCEDURES ET FONCTIONS [A FAIRE]
            TProcInfo : Name, Params, LocalVars, Body, IsFunction, ReturnType
            TParamInfo : Name, TypeName, IsVar, IsConst
            GenProcedure(Proc) : generer une procedure
            GenFunction(Func) : generer une fonction
            GenParamList(Params) : generer la liste des parametres
            GenLocalVars(Vars) : generer les variables locales
            GenProcCall(Name, Args) : generer un appel de procedure
  ============================================================ }

{ ============================================================
  TODO 10 - GENERATEUR DE CODE PASCAL - UNITES (UNIT) [A FAIRE]
            TUnitInfo : Name, InterfaceSection, ImplementSection, InitSection
            GenUnitInterface(Unit) : generer la section INTERFACE
            GenUnitImplementation(Unit) : generer la section IMPLEMENTATION
            GenUnitInitialization(Unit) : generer la section INITIALIZATION
            GenUnitFinalization(Unit) : generer la section FINALIZATION
            GenCompleteUnit(Unit) : generer une unite complete
  ============================================================ }

{ ============================================================
  TODO 11 - BIBLIOTHEQUE DE TEMPLATES DE CODE [A FAIRE]
            TTemplate : Name, Description, Code, Parameters
            Templates[0..MAX_TEMPLATES-1], TemplateCount
            LoadBuiltinTemplates : charger les templates predefinies
            FindTemplate(Name) : chercher un template par nom
            ApplyTemplate(Template, Params) : appliquer un template avec parametres
            ListTemplates : lister les templates disponibles
  ============================================================ }

{ ============================================================
  TODO 12 - GENERATION DE PROGRAMMES "BONJOUR" [A FAIRE]
            GenHelloWorld : generer un programme "Bonjour le monde"
            GenHelloName(Name) : generer un programme avec nom personnalise
            GenHelloInteractive : generer un programme avec saisie du nom
            GenHelloMultilingual : generer un programme multilingue
            GenHelloGraphic : generer un programme avec affichage graphique
  ============================================================ }

{ ============================================================
  TODO 13 - GENERATION DE PROGRAMMES MATHEMATIQUES [A FAIRE]
            GenPrimeNumbers(N) : generer un programme affichant N premiers
            GenFibonacci(N) : generer un programme de suite de Fibonacci
            GenFactorial : generer un programme de calcul de factorielle
            GenGCD : generer un programme de calcul de PGCD
            GenCalculator : generer une calculatrice simple
            GenPrimeCheck : generer un verificateur de nombre premier
  ============================================================ }

{ ============================================================
  TODO 14 - GENERATION DE PROGRAMMES DATE/HEURE [A FAIRE]
            GenCurrentDateTime : generer un programme affichant date et heure
            GenDateFormat : generer un programme formatant une date
            GenTimeCalc : generer un programme de calcul de durees
            GenCalendar(Month, Year) : generer un calendrier mensuel
            GenStopwatch : generer un chronometre simple
            GenCountdown : generer un compte a rebours
  ============================================================ }

{ ============================================================
  TODO 15 - GENERATION D'UNITES PERSONNALISEES [A FAIRE]
            GenTimeUnit : generer une unite pour le temps
            GenStringUnit : generer une unite pour les chaines
            GenMathUnit : generer une unite mathematique etendue
            GenFileUnit : generer une unite pour les fichiers
            GenConsoleUnit : generer une unite pour la console
  ============================================================ }

{ ============================================================
  TODO 16 - INTERFACE DE CLAVARDAGE EN FRANCAIS [A FAIRE]
            InitChat : initialiser l'interface de clavardage
            ShowWelcome : afficher le message de bienvenue
            ShowPrompt : afficher l'invite de commande
            ReadUserInput : lire l'entree utilisateur
            DisplayResponse(Text) : afficher une reponse formatee
            DisplayCode(Code) : afficher du code avec coloration
            ShowGoodbye : afficher le message d'au revoir
  ============================================================ }

{ ============================================================
  TODO 17 - SYSTEME DE REPONSES CONTEXTUELLES [A FAIRE]
            TResponseKind : RK_TEXT, RK_CODE, RK_MIXED, RK_ERROR, RK_HELP
            TResponse : Kind, Text, Code, Suggestions
            GenerateResponse(Intent, Context) : generer une reponse
            GetContextualHelp(Topic) : obtenir de l'aide contextuelle
            SuggestRelated(Topic) : suggerer des sujets connexes
            FormatResponse(Response) : formater la reponse pour affichage
  ============================================================ }

{ ============================================================
  TODO 18 - FORMATAGE ET INDENTATION DU CODE GENERE [A FAIRE]
            TFormatOptions : IndentSize, MaxLineWidth, BraceStyle
            FormatCode(Code) : formater le code genere
            IndentCode(Code, Level) : indenter le code
            WrapLongLines(Code, MaxWidth) : couper les lignes trop longues
            AddComments(Code) : ajouter des commentaires explicatifs
            PrettyPrint(Code) : affichage elegant du code
  ============================================================ }

{ ============================================================
  TODO 19 - AIDE EN LIGNE ET EXEMPLES [A FAIRE]
            ShowHelp : afficher l'aide generale
            ShowExamples : afficher des exemples de requetes
            ShowSyntax(Topic) : afficher la syntaxe Pascal d'un element
            ShowKeywords : lister les mots-cles reconnus
            ShowCapabilities : lister les capacites du chatbot
  ============================================================ }

{ ============================================================
  TODO 20 - SAUVEGARDE DES PROGRAMMES GENERES [A FAIRE]
            SaveProgram(Code, FileName) : sauvegarder dans un fichier .pas
            AutoSuggestFileName(Code) : suggerer un nom de fichier
            CheckFileExists(FileName) : verifier si le fichier existe
            ConfirmOverwrite : demander confirmation pour ecrasement
            ListSavedPrograms : lister les programmes sauvegardes
  ============================================================ }

{ ============================================================
  TODO 21 - VALIDATION SYNTAXIQUE DU CODE GENERE [A FAIRE]
            ValidateSyntax(Code) : verifier la syntaxe du code genere
            CheckBalancedBlocks(Code) : verifier l'equilibrage BEGIN/END
            CheckSemicolons(Code) : verifier les points-virgules
            CheckIdentifiers(Code) : verifier les identificateurs
            ReportSyntaxErrors(Errors) : rapporter les erreurs trouvees
  ============================================================ }

{ ============================================================
  TODO 22 - SUGGESTIONS ET AUTO-COMPLETION [A FAIRE]
            TSuggestion : Text, Description, Priority
            GetSuggestions(PartialInput) : obtenir des suggestions
            AutoComplete(Input) : completer automatiquement l'entree
            ShowSuggestions(Suggestions) : afficher les suggestions
            ApplySuggestion(Index) : appliquer une suggestion
  ============================================================ }

{ ============================================================
  TODO 23 - MODE INTERACTIF AMELIORE [A FAIRE]
            TInteractiveMode : IM_NORMAL, IM_EDIT, IM_REVIEW, IM_LEARN
            SetMode(Mode) : changer de mode interactif
            EditLastCode : editer le dernier code genere
            ReviewCode(Code) : passer en revue le code ligne par ligne
            LearnFromUser(Input) : apprendre de l'utilisateur
  ============================================================ }

{ ============================================================
  TODO 24 - EXPORT ET HISTORIQUE DE SESSION [A FAIRE]
            ExportSession(FileName) : exporter la session complete
            ExportCode(FileName) : exporter uniquement le code genere
            ImportSession(FileName) : importer une session precedente
            ShowSessionStats : afficher les statistiques de session
            ClearSession : reinitialiser la session
  ============================================================ }

{ ============================================================
  TODO 25 - PROGRAMME PRINCIPAL ET BOUCLE DE CLAVARDAGE [A FAIRE]
            Run : lancer le chatbot
            MainLoop : boucle principale de clavardage
            ProcessCommand(Input) : traiter une commande utilisateur
            HandleSpecialCommands : gerer les commandes speciales (/help, /quit, /save)
            Cleanup : nettoyage avant sortie
            Programme principal : initialiser et demarrer le chatbot
  ============================================================ }

{ ============================================================
  CONSTANTES GLOBALES
  ============================================================ }
Const
  PASCHAT_VERSION = '1.0';
  PASCHAT_DATE    = '2026-04-08';

  { Limites des tableaux internes }
  MAX_LEARN      = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_HISTORY    = {$IFDEF FPC}256{$ELSE}64{$ENDIF};
  MAX_TEMPLATES  = {$IFDEF FPC}128{$ELSE}32{$ENDIF};
  MAX_KEYWORDS   = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_PARAMS     = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_VARS       = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_FIELDS     = {$IFDEF FPC}32{$ELSE}16{$ENDIF};
  MAX_UNITS      = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_SUGGESTIONS = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_ERRORS     = {$IFDEF FPC}30{$ELSE}10{$ENDIF};
  MAX_STR        = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  MAX_LINE_LEN   = 255;
  MAX_CODE_LINES = {$IFDEF FPC}1024{$ELSE}256{$ENDIF};
  MAX_LEARN_LINES = {$IFDEF FPC}4096{$ELSE}512{$ENDIF};

  { Codes de sortie }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Taille d'indentation par defaut }
  DEFAULT_INDENT = 2;

  { TODO 01 - Types d'options (OPT_*) }
  OPT_NONE       = 0;   { Aucune option }
  OPT_VERBOSE    = 1;   { Mode verbeux }
  OPT_DEBUG      = 2;   { Mode debogage }
  OPT_HELP       = 3;   { Afficher l'aide }
  OPT_VERSION    = 4;   { Afficher la version }
  OPT_LEARN      = 5;   { Fichier d'apprentissage }
  OPT_OUTPUT     = 6;   { Fichier de sortie }
  OPT_QUIET      = 7;   { Mode silencieux }
  OPT_MAX        = 8;   { Nombre maximum d'options }

  { Limites pour TODO 01 }
  OPT_MAX_FILES  = 64;  { Nombre max de fichiers en entree }

  { TODO 02 - Types de fichiers d'apprentissage (LRN_*) }
  LRN_NONE       = 0;   { Aucun fichier }
  LRN_TEXT       = 1;   { Fichier texte simple }
  LRN_DOC        = 2;   { Documentation }
  LRN_CODE       = 3;   { Code source Pascal }
  LRN_SYNTAX     = 4;   { Reference syntaxique }
  LRN_EXAMPLE    = 5;   { Exemples de code }
  LRN_KEYWORD    = 6;   { Mots-cles et commandes }
  LRN_INDEX      = 7;   { Index de contenu }
  LRN_MAX        = 8;   { Nombre maximum de types }

  { Limites pour TODO 02 }
  LRN_MAX_WORDS  = 256; { Nombre max de mots indexes par fichier }
  LRN_MIN_WORD   = 3;   { Longueur minimale pour indexation }

  { TODO 03 - Types d'entrees d'historique (HIS_*) }
  HIS_NONE       = 0;   { Aucune entree }
  HIS_USER       = 1;   { Entree utilisateur }
  HIS_BOT        = 2;   { Reponse bot }
  HIS_CODE       = 3;   { Code genere }
  HIS_ERROR      = 4;   { Message d'erreur }
  HIS_COMMAND    = 5;   { Commande speciale }
  HIS_CONTEXT    = 6;   { Information contextuelle }
  HIS_SYSTEM     = 7;   { Message systeme }
  HIS_MAX        = 8;   { Nombre maximum de types }

  { Limites pour TODO 03 }
  HIS_MAX_RECENT = 10;  { Nombre max d'entrees recentes }
  HIS_FILE_EXT   = '.his'; { Extension fichier historique }

{ ============================================================
  TYPES
  ============================================================ }
Type
  { Types de base }
  TString    = String[MAX_STR];
  TLongStr   = String[MAX_LINE_LEN];
  TCodeLine  = String[MAX_LINE_LEN];

  { TODO 01 - Options de ligne de commande }
  TOptions = Record
    Verbose   : Boolean;
    DebugMode : Boolean;
    ShowHelp  : Boolean;
    LearnFileCount : Integer;
    LearnFileNames : Array[1..MAX_LEARN] of TString;
  End;

  { TODO 02 - Fichiers d'apprentissage }
  TLearnLine = String[MAX_LINE_LEN];
  TLearnFile = Record
    FileName  : TString;
    Lines     : Array[1..MAX_LEARN_LINES] of ^TLearnLine;
    LineCount : Integer;
    Loaded    : Boolean;
  End;

  { TODO 03 - Historique de conversation }
  THistoryEntry = Record
    UserInput   : TLongStr;
    BotResponse : TLongStr;
    Timestamp   : LongInt;
    HasCode     : Boolean;
  End;

  { TODO 04 - Intention de l'utilisateur }
  TIntentKind = (
    IK_UNKNOWN,    { Intention non reconnue }
    IK_HELLO,      { Salutation }
    IK_PROGRAM,    { Demande de programme }
    IK_UNIT,       { Demande d'unite }
    IK_PROCEDURE,  { Demande de procedure }
    IK_FUNCTION,   { Demande de fonction }
    IK_EXPLAIN,    { Demande d'explication }
    IK_HELP,       { Demande d'aide }
    IK_SAVE,       { Commande de sauvegarde }
    IK_LIST,       { Demande de liste }
    IK_CLEAR,      { Commande d'effacement }
    IK_QUIT        { Commande de sortie }
  );

  TIntent = Record
    Kind     : TIntentKind;
    Subject  : TString;
    Keywords : Array[1..MAX_KEYWORDS] of TString;
    KeyCount : Integer;
    Params   : Array[1..MAX_PARAMS] of TString;
    ParamCnt : Integer;
  End;

  { TODO 06 - Types Pascal }
  TTypeKind = (
    TK_INTEGER,   { Entier }
    TK_WORD,      { Mot non signe }
    TK_LONGINT,   { Entier long }
    TK_REAL,      { Reel }
    TK_STRING,    { Chaine }
    TK_CHAR,      { Caractere }
    TK_BOOLEAN,   { Booleen }
    TK_BYTE,      { Octet }
    TK_ARRAY,     { Tableau }
    TK_RECORD,    { Enregistrement }
    TK_POINTER,   { Pointeur }
    TK_FILE,      { Fichier }
    TK_TEXT,      { Fichier texte }
    TK_ENUM,      { Enumeration }
    TK_SET,       { Ensemble }
    TK_CUSTOM     { Type personnalise }
  );

  TTypeInfo = Record
    Name     : TString;
    Kind     : TTypeKind;
    BaseType : TString;  { Pour Array, Pointer, etc. }
    LowBound : Integer;
    HighBound: Integer;
  End;

  TVarInfo = Record
    Name      : TString;
    TypeName  : TString;
    TypeKind  : TTypeKind;
    InitValue : TString;
    IsConst   : Boolean;
  End;

  { TODO 09 - Procedures et fonctions }
  TParamInfo = Record
    Name     : TString;
    TypeName : TString;
    IsVar    : Boolean;
    IsConst  : Boolean;
  End;

  TProcInfo = Record
    Name       : TString;
    Params     : Array[1..MAX_PARAMS] of TParamInfo;
    ParamCount : Integer;
    LocalVars  : Array[1..MAX_VARS] of TVarInfo;
    VarCount   : Integer;
    IsFunction : Boolean;
    ReturnType : TString;
  End;

  { TODO 10 - Unites }
  TUnitInfo = Record
    Name            : TString;
    UsesUnits       : Array[1..MAX_UNITS] of TString;
    UsesCount       : Integer;
    IntfProcs       : Array[1..MAX_PARAMS] of TProcInfo;
    IntfProcCount   : Integer;
    ImplProcs       : Array[1..MAX_PARAMS] of TProcInfo;
    ImplProcCount   : Integer;
    HasInit         : Boolean;
    HasFinal        : Boolean;
  End;

  { TODO 11 - Templates }
  TTemplate = Record
    Name        : TString;
    Description : TString;
    ParamNames  : Array[1..MAX_PARAMS] of TString;
    ParamCount  : Integer;
    CodeLines   : Array[1..MAX_CODE_LINES] of ^TCodeLine;
    LineCount   : Integer;
  End;

  { TODO 17 - Reponses }
  TResponseKind = (
    RK_TEXT,    { Texte simple }
    RK_CODE,    { Code uniquement }
    RK_MIXED,   { Texte et code }
    RK_ERROR,   { Message d'erreur }
    RK_HELP     { Aide }
  );

  TResponse = Record
    Kind        : TResponseKind;
    Text        : TLongStr;
    CodeLines   : Array[1..MAX_CODE_LINES] of ^TCodeLine;
    CodeCount   : Integer;
    Suggestions : Array[1..MAX_SUGGESTIONS] of TString;
    SuggestCnt  : Integer;
  End;

  { TODO 18 - Options de formatage }
  TFormatOptions = Record
    IndentSize   : Integer;
    MaxLineWidth : Integer;
    AddComments  : Boolean;
    UpperKeywords: Boolean;
  End;

  { TODO 22 - Suggestions }
  TSuggestion = Record
    Text        : TString;
    Description : TString;
    Priority    : Integer;
  End;

  { TODO 23 - Mode interactif }
  TInteractiveMode = (
    IM_NORMAL,  { Mode normal de conversation }
    IM_EDIT,    { Edition du code }
    IM_REVIEW,  { Revue du code }
    IM_LEARN    { Mode apprentissage }
  );

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
Var
  { TODO 01 - Options et etat }
  Options : TOptions;
  OptInitialized : Boolean;
  OptStateCount  : Integer;
  OptVerboseCount: Integer;
  OptDebugCount  : Integer;
  OptHelpCount   : Integer;
  OptVersionCount: Integer;
  OptLearnCount  : Integer;
  OptOutputCount : Integer;
  OptQuietCount  : Integer;
  OptErrorCount  : Integer;
  OptLabelNum    : Integer;

  { TODO 02 - Fichiers d'apprentissage et etat }
  LearnFiles : Array[1..MAX_LEARN] of TLearnFile;
  LearnCount : Integer;
  LrnInitialized : Boolean;
  LrnStateCount  : Integer;
  LrnLoadCount   : Integer;
  LrnTextCount   : Integer;
  LrnDocCount    : Integer;
  LrnCodeCount   : Integer;
  LrnSyntaxCount : Integer;
  LrnExampleCount: Integer;
  LrnIndexCount  : Integer;
  LrnErrorCount  : Integer;
  LrnLabelNum    : Integer;
  LrnTotalLines  : Integer;
  LrnSearchCount : Integer;

  { TODO 03 - Historique et etat }
  History      : Array[1..MAX_HISTORY] of THistoryEntry;
  HistoryCount : Integer;
  HisInitialized : Boolean;
  HisStateCount  : Integer;
  HisAddCount    : Integer;
  HisUserCount   : Integer;
  HisBotCount    : Integer;
  HisCodeCount   : Integer;
  HisErrorCount  : Integer;
  HisCommandCount: Integer;
  HisClearCount  : Integer;
  HisLabelNum    : Integer;
  HisSaveCount   : Integer;
  HisLoadCount   : Integer;

  { TODO 04 - Intention courante }
  CurrentIntent : TIntent;

  { TODO 11 - Templates }
  Templates     : Array[1..MAX_TEMPLATES] of TTemplate;
  TemplateCount : Integer;

  { TODO 17 - Reponse courante }
  CurrentResponse : TResponse;

  { TODO 18 - Options de formatage }
  FormatOpts : TFormatOptions;

  { TODO 20 - Code genere courant }
  GeneratedCode : Array[1..MAX_CODE_LINES] of TCodeLine;
  GeneratedCount: Integer;

  { TODO 23 - Mode courant }
  CurrentMode : TInteractiveMode;

  { TODO 25 - Controle de la boucle }
  Running     : Boolean;
  ErrorCount  : Integer;

{ ============================================================
  FONCTIONS UTILITAIRES
  ============================================================ }

Function UpCaseStr(S: String): String;
Var
  I: Integer;
  R: String;
Begin
  R := '';
  For I := 1 to Length(S) do
    R := R + UpCase(S[I]);
  UpCaseStr := R;
End;

Function LowerCaseStr(S: String): String;
Var
  I: Integer;
  R: String;
  C: Char;
Begin
  R := '';
  For I := 1 to Length(S) do Begin
    C := S[I];
    If (C >= 'A') and (C <= 'Z') Then
      C := Chr(Ord(C) + 32);
    R := R + C;
  End;
  LowerCaseStr := R;
End;

Function Trim(S: String): String;
Var
  I, J: Integer;
Begin
  I := 1;
  While (I <= Length(S)) and (S[I] = ' ') do
    Inc(I);
  J := Length(S);
  While (J >= I) and (S[J] = ' ') do
    Dec(J);
  Trim := Copy(S, I, J - I + 1);
End;

Function IntToStr(N: LongInt): String;
Var
  S: String;
Begin
  Str(N, S);
  IntToStr := S;
End;

Function StrToInt(S: String): LongInt;
Var
  N: LongInt;
  Code: Integer;
Begin
  Val(S, N, Code);
  If Code <> 0 Then
    N := 0;
  StrToInt := N;
End;

Function ContainsWord(S, W: String): Boolean;
Var
  US, UW: String;
  P: Integer;
Begin
  US := UpCaseStr(S);
  UW := UpCaseStr(W);
  P := Pos(UW, US);
  ContainsWord := P > 0;
End;

Function FileExists(FileName: String): Boolean;
Var
  F: File;
Begin
  Assign(F, FileName);
  {$I-}
  Reset(F);
  {$I+}
  If IOResult = 0 Then Begin
    Close(F);
    FileExists := True;
  End Else
    FileExists := False;
End;

Function MakeIndent(Level: Integer): String;
Var
  S: String;
  I: Integer;
Begin
  S := '';
  For I := 1 to Level * FormatOpts.IndentSize do
    S := S + ' ';
  MakeIndent := S;
End;

{ ============================================================
  TODO 01 - INFRASTRUCTURE ET OPTIONS
  ============================================================ }

Procedure FatalError(Msg: String);
Begin
  WriteLn('ERREUR: ', Msg);
  Halt(EXIT_ERROR);
End;

Procedure WarnMsg(Msg: String);
Begin
  If Options.Verbose Then
    WriteLn('AVERTISSEMENT: ', Msg);
End;

Procedure ShowVersion;
Begin
  WriteLn('PASCHAT - Agent conversationnel generateur de code Turbo Pascal');
  WriteLn('Version ', PASCHAT_VERSION, ' (', PASCHAT_DATE, ')');
  WriteLn('(c) 2026 Gladir.com - Licence MIT');
End;

Procedure ShowUsage;
Begin
  ShowVersion;
  WriteLn;
  WriteLn('Usage: PASCHAT [options] [fichiers.txt...]');
  WriteLn;
  WriteLn('Options:');
  WriteLn('  -h, --help     Afficher cette aide');
  WriteLn('  -v, --verbose  Mode verbeux');
  WriteLn('  -d, --debug    Mode debogage');
  WriteLn;
  WriteLn('Fichiers d''apprentissage:');
  WriteLn('  Les fichiers .txt passes en argument sont charges');
  WriteLn('  comme base de connaissances pour le chatbot.');
  WriteLn('  Exemple: PASCHAT DOC/TURBOPASCAL_SYSTEM.txt');
  WriteLn;
  WriteLn('Commandes interactives:');
  WriteLn('  /help    - Afficher l''aide');
  WriteLn('  /quit    - Quitter le programme');
  WriteLn('  /save    - Sauvegarder le dernier code genere');
  WriteLn('  /history - Afficher l''historique');
  WriteLn('  /clear   - Effacer l''historique');
End;

Procedure InitOptions;
Begin
  Options.Verbose := False;
  Options.DebugMode := False;
  Options.ShowHelp := False;
  Options.LearnFileCount := 0;
End;

Procedure ParseArgs;
Var
  I: Integer;
  Arg: String;
Begin
  InitOptions;
  I := 1;
  While I <= ParamCount do Begin
    Arg := ParamStr(I);
    If (Arg = '-h') or (Arg = '--help') Then
      Options.ShowHelp := True
    Else If (Arg = '-v') or (Arg = '--verbose') Then
      Options.Verbose := True
    Else If (Arg = '-d') or (Arg = '--debug') Then
      Options.DebugMode := True
    Else If Arg[1] <> '-' Then Begin
      { C'est un fichier d'apprentissage }
      If Options.LearnFileCount < MAX_LEARN Then Begin
        Inc(Options.LearnFileCount);
        Options.LearnFileNames[Options.LearnFileCount] := Arg;
      End Else
        WarnMsg('Trop de fichiers d''apprentissage, ignore: ' + Arg);
    End Else
      WarnMsg('Option inconnue: ' + Arg);
    Inc(I);
  End;
End;

{ --- TODO 01 : Fonctions d'initialisation et utilitaires --- }

Procedure InitOptState;
Begin
  OptInitialized := True;
  OptStateCount := 0;
  OptVerboseCount := 0;
  OptDebugCount := 0;
  OptHelpCount := 0;
  OptVersionCount := 0;
  OptLearnCount := 0;
  OptOutputCount := 0;
  OptQuietCount := 0;
  OptErrorCount := 0;
  OptLabelNum := 0;
End;

Function GenOptLabel: TString;
Var
  S: String;
Begin
  Inc(OptLabelNum);
  Str(OptLabelNum, S);
  GenOptLabel := '_OPT_L_' + S;
End;

Function OptTypeName(OptType: Integer): TString;
Begin
  Case OptType of
    OPT_NONE:    OptTypeName := 'NONE';
    OPT_VERBOSE: OptTypeName := 'VERBOSE';
    OPT_DEBUG:   OptTypeName := 'DEBUG';
    OPT_HELP:    OptTypeName := 'HELP';
    OPT_VERSION: OptTypeName := 'VERSION';
    OPT_LEARN:   OptTypeName := 'LEARN';
    OPT_OUTPUT:  OptTypeName := 'OUTPUT';
    OPT_QUIET:   OptTypeName := 'QUIET';
  Else
    OptTypeName := 'UNKNOWN';
  End;
End;

Procedure DumpOptState;
Begin
  WriteLn('=== TODO 01 - Infrastructure et Options ===');
  WriteLn('  OptInitialized : ', OptInitialized);
  WriteLn('  OptStateCount  : ', OptStateCount);
  WriteLn('  OptVerboseCount: ', OptVerboseCount);
  WriteLn('  OptDebugCount  : ', OptDebugCount);
  WriteLn('  OptHelpCount   : ', OptHelpCount);
  WriteLn('  OptVersionCount: ', OptVersionCount);
  WriteLn('  OptLearnCount  : ', OptLearnCount);
  WriteLn('  OptOutputCount : ', OptOutputCount);
  WriteLn('  OptQuietCount  : ', OptQuietCount);
  WriteLn('  OptErrorCount  : ', OptErrorCount);
  WriteLn('  OptLabelNum    : ', OptLabelNum);
  WriteLn('  Options.Verbose   : ', Options.Verbose);
  WriteLn('  Options.DebugMode : ', Options.DebugMode);
  WriteLn('  Options.ShowHelp  : ', Options.ShowHelp);
  WriteLn('  Options.LearnFileCount: ', Options.LearnFileCount);
End;

{ --- TODO 01 : 10 accesseurs standards --- }

Function IsOptInitialized: Boolean;
Begin
  IsOptInitialized := OptInitialized;
End;

Function IsOptEmpty: Boolean;
Begin
  IsOptEmpty := (OptStateCount = 0);
End;

Function GetOptStateCount: Integer;
Begin
  GetOptStateCount := OptStateCount;
End;

Function GetOptVerboseCount: Integer;
Begin
  GetOptVerboseCount := OptVerboseCount;
End;

Function GetOptDebugCount: Integer;
Begin
  GetOptDebugCount := OptDebugCount;
End;

Function GetOptHelpCount: Integer;
Begin
  GetOptHelpCount := OptHelpCount;
End;

Function GetOptLearnCount: Integer;
Begin
  GetOptLearnCount := OptLearnCount;
End;

Function GetOptOutputCount: Integer;
Begin
  GetOptOutputCount := OptOutputCount;
End;

Function GetOptErrorCount: Integer;
Begin
  GetOptErrorCount := OptErrorCount;
End;

Function GetOptLabelNum: Integer;
Begin
  GetOptLabelNum := OptLabelNum;
End;

{ ============================================================
  TODO 02 - CHARGEMENT DES FICHIERS D'APPRENTISSAGE
  ============================================================ }

Procedure InitLearnFiles;
Var
  I: Integer;
Begin
  LearnCount := 0;
  For I := 1 to MAX_LEARN do Begin
    LearnFiles[I].FileName := '';
    LearnFiles[I].LineCount := 0;
    LearnFiles[I].Loaded := False;
  End;
End;

Function LoadLearnFile(FileName: String): Boolean;
Var
  F: Text;
  Line: TLearnLine;
  Idx: Integer;
Begin
  LoadLearnFile := False;
  If LearnCount >= MAX_LEARN Then Exit;

  If Not FileExists(FileName) Then Begin
    WarnMsg('Fichier introuvable: ' + FileName);
    Exit;
  End;

  Assign(F, FileName);
  {$I-}
  Reset(F);
  {$I+}
  If IOResult <> 0 Then Begin
    WarnMsg('Impossible d''ouvrir: ' + FileName);
    Exit;
  End;

  Inc(LearnCount);
  Idx := LearnCount;
  LearnFiles[Idx].FileName := FileName;
  LearnFiles[Idx].LineCount := 0;

  While Not Eof(F) And (LearnFiles[Idx].LineCount < MAX_LEARN_LINES) do Begin
    ReadLn(F, Line);
    Inc(LearnFiles[Idx].LineCount);
    New(LearnFiles[Idx].Lines[LearnFiles[Idx].LineCount]);
    LearnFiles[Idx].Lines[LearnFiles[Idx].LineCount]^ := Line;
  End;

  Close(F);
  LearnFiles[Idx].Loaded := True;
  LoadLearnFile := True;

  If Options.Verbose Then
    WriteLn('Charge: ', FileName, ' (', LearnFiles[Idx].LineCount, ' lignes)');
End;

Procedure LoadAllLearnFiles;
Var
  I: Integer;
Begin
  For I := 1 to Options.LearnFileCount do
    LoadLearnFile(Options.LearnFileNames[I]);
End;

Function FindInLearnFiles(Query: String): TLongStr;
Var
  I, J: Integer;
  UQ: String;
  Found: TLongStr;
Begin
  Found := '';
  UQ := UpCaseStr(Query);

  For I := 1 to LearnCount do
    If LearnFiles[I].Loaded Then
      For J := 1 to LearnFiles[I].LineCount do
        If ContainsWord(LearnFiles[I].Lines[J]^, Query) Then Begin
          Found := LearnFiles[I].Lines[J]^;
          FindInLearnFiles := Found;
          Exit;
        End;

  FindInLearnFiles := Found;
End;

Procedure FreeLearnFiles;
Var
  I, J: Integer;
Begin
  For I := 1 to LearnCount do
    If LearnFiles[I].Loaded Then
      For J := 1 to LearnFiles[I].LineCount do
        If LearnFiles[I].Lines[J] <> nil Then
          Dispose(LearnFiles[I].Lines[J]);
End;

{ --- TODO 02 : Fonctions d'initialisation et utilitaires --- }

Procedure InitLearnState;
Begin
  LrnInitialized := True;
  LrnStateCount := 0;
  LrnLoadCount := 0;
  LrnTextCount := 0;
  LrnDocCount := 0;
  LrnCodeCount := 0;
  LrnSyntaxCount := 0;
  LrnExampleCount := 0;
  LrnIndexCount := 0;
  LrnErrorCount := 0;
  LrnLabelNum := 0;
  LrnTotalLines := 0;
  LrnSearchCount := 0;
End;

Function GenLrnLabel: TString;
Var
  S: String;
Begin
  Inc(LrnLabelNum);
  Str(LrnLabelNum, S);
  GenLrnLabel := '_LRN_L_' + S;
End;

Function LrnTypeName(LrnType: Integer): TString;
Begin
  Case LrnType of
    LRN_NONE:    LrnTypeName := 'NONE';
    LRN_TEXT:    LrnTypeName := 'TEXT';
    LRN_DOC:     LrnTypeName := 'DOC';
    LRN_CODE:    LrnTypeName := 'CODE';
    LRN_SYNTAX:  LrnTypeName := 'SYNTAX';
    LRN_EXAMPLE: LrnTypeName := 'EXAMPLE';
    LRN_KEYWORD: LrnTypeName := 'KEYWORD';
    LRN_INDEX:   LrnTypeName := 'INDEX';
  Else
    LrnTypeName := 'UNKNOWN';
  End;
End;

Function DetectLearnFileType(FileName: String): Integer;
Var
  UF: String;
Begin
  UF := UpCaseStr(FileName);
  If Pos('SYNTAX', UF) > 0 Then
    DetectLearnFileType := LRN_SYNTAX
  Else If Pos('EXAMPLE', UF) > 0 Then
    DetectLearnFileType := LRN_EXAMPLE
  Else If Pos('DOC', UF) > 0 Then
    DetectLearnFileType := LRN_DOC
  Else If (Pos('.PAS', UF) > 0) Or (Pos('CODE', UF) > 0) Then
    DetectLearnFileType := LRN_CODE
  Else If Pos('INDEX', UF) > 0 Then
    DetectLearnFileType := LRN_INDEX
  Else If Pos('KEYWORD', UF) > 0 Then
    DetectLearnFileType := LRN_KEYWORD
  Else
    DetectLearnFileType := LRN_TEXT;
End;

Procedure IndexLearnContent;
Var
  I: Integer;
  FType: Integer;
Begin
  { Indexe le contenu des fichiers charges }
  For I := 1 to LearnCount do Begin
    If LearnFiles[I].Loaded Then Begin
      FType := DetectLearnFileType(LearnFiles[I].FileName);
      Case FType of
        LRN_TEXT:    Inc(LrnTextCount);
        LRN_DOC:     Inc(LrnDocCount);
        LRN_CODE:    Inc(LrnCodeCount);
        LRN_SYNTAX:  Inc(LrnSyntaxCount);
        LRN_EXAMPLE: Inc(LrnExampleCount);
        LRN_INDEX:   Inc(LrnIndexCount);
      End;
      LrnTotalLines := LrnTotalLines + LearnFiles[I].LineCount;
      Inc(LrnLoadCount);
    End;
  End;
  Inc(LrnStateCount);
End;

Function FindAllInLearnFiles(Query: String): Integer;
Var
  I, J, Count: Integer;
Begin
  Count := 0;
  For I := 1 to LearnCount do
    If LearnFiles[I].Loaded Then
      For J := 1 to LearnFiles[I].LineCount do
        If ContainsWord(LearnFiles[I].Lines[J]^, Query) Then
          Inc(Count);
  Inc(LrnSearchCount);
  FindAllInLearnFiles := Count;
End;

Procedure DumpLearnState;
Begin
  WriteLn('=== TODO 02 - Chargement Fichiers Apprentissage ===');
  WriteLn('  LrnInitialized : ', LrnInitialized);
  WriteLn('  LrnStateCount  : ', LrnStateCount);
  WriteLn('  LrnLoadCount   : ', LrnLoadCount);
  WriteLn('  LrnTextCount   : ', LrnTextCount);
  WriteLn('  LrnDocCount    : ', LrnDocCount);
  WriteLn('  LrnCodeCount   : ', LrnCodeCount);
  WriteLn('  LrnSyntaxCount : ', LrnSyntaxCount);
  WriteLn('  LrnExampleCount: ', LrnExampleCount);
  WriteLn('  LrnIndexCount  : ', LrnIndexCount);
  WriteLn('  LrnErrorCount  : ', LrnErrorCount);
  WriteLn('  LrnLabelNum    : ', LrnLabelNum);
  WriteLn('  LrnTotalLines  : ', LrnTotalLines);
  WriteLn('  LrnSearchCount : ', LrnSearchCount);
  WriteLn('  LearnCount     : ', LearnCount);
End;

{ --- TODO 02 : 10 accesseurs standards --- }

Function IsLrnInitialized: Boolean;
Begin
  IsLrnInitialized := LrnInitialized;
End;

Function IsLrnEmpty: Boolean;
Begin
  IsLrnEmpty := (LearnCount = 0);
End;

Function GetLrnStateCount: Integer;
Begin
  GetLrnStateCount := LrnStateCount;
End;

Function GetLrnLoadCount: Integer;
Begin
  GetLrnLoadCount := LrnLoadCount;
End;

Function GetLrnTextCount: Integer;
Begin
  GetLrnTextCount := LrnTextCount;
End;

Function GetLrnDocCount: Integer;
Begin
  GetLrnDocCount := LrnDocCount;
End;

Function GetLrnCodeCount: Integer;
Begin
  GetLrnCodeCount := LrnCodeCount;
End;

Function GetLrnTotalLines: Integer;
Begin
  GetLrnTotalLines := LrnTotalLines;
End;

Function GetLrnErrorCount: Integer;
Begin
  GetLrnErrorCount := LrnErrorCount;
End;

Function GetLrnLabelNum: Integer;
Begin
  GetLrnLabelNum := LrnLabelNum;
End;

{ ============================================================
  TODO 03 - HISTORIQUE DE CONVERSATION
  ============================================================ }

{ --- TODO 03 : Fonctions d'initialisation et utilitaires --- }

Procedure InitHisState;
Begin
  HisInitialized := True;
  HisStateCount := 0;
  HisAddCount := 0;
  HisUserCount := 0;
  HisBotCount := 0;
  HisCodeCount := 0;
  HisErrorCount := 0;
  HisCommandCount := 0;
  HisClearCount := 0;
  HisLabelNum := 0;
  HisSaveCount := 0;
  HisLoadCount := 0;
End;

Function GenHisLabel: TString;
Var
  S: String;
Begin
  Inc(HisLabelNum);
  Str(HisLabelNum, S);
  GenHisLabel := '_HIS_L_' + S;
End;

Function HisTypeName(HisType: Integer): TString;
Begin
  Case HisType of
    HIS_NONE:    HisTypeName := 'NONE';
    HIS_USER:    HisTypeName := 'USER';
    HIS_BOT:     HisTypeName := 'BOT';
    HIS_CODE:    HisTypeName := 'CODE';
    HIS_ERROR:   HisTypeName := 'ERROR';
    HIS_COMMAND: HisTypeName := 'COMMAND';
    HIS_CONTEXT: HisTypeName := 'CONTEXT';
    HIS_SYSTEM:  HisTypeName := 'SYSTEM';
  Else
    HisTypeName := 'UNKNOWN';
  End;
End;

Procedure InitHistory;
Begin
  HistoryCount := 0;
  Inc(HisStateCount);
End;

Procedure AddToHistory(UserIn, BotOut: String; WithCode: Boolean);
Begin
  If HistoryCount >= MAX_HISTORY Then Begin
    { Decaler l'historique si plein }
    Move(History[2], History[1], SizeOf(THistoryEntry) * (MAX_HISTORY - 1));
    Dec(HistoryCount);
  End;

  Inc(HistoryCount);
  History[HistoryCount].UserInput := UserIn;
  History[HistoryCount].BotResponse := BotOut;
  History[HistoryCount].HasCode := WithCode;
  { Timestamp simplifie - pourrait utiliser GetTime de Dos unit }
  History[HistoryCount].Timestamp := HistoryCount;

  Inc(HisAddCount);
  Inc(HisUserCount);
  Inc(HisBotCount);
  If WithCode Then Inc(HisCodeCount);
End;

Function GetLastUserInput: String;
Begin
  If HistoryCount > 0 Then
    GetLastUserInput := History[HistoryCount].UserInput
  Else
    GetLastUserInput := '';
End;

Procedure GetRecentHistory(N: Integer);
Var
  I, StartIdx: Integer;
Begin
  If HistoryCount = 0 Then Begin
    WriteLn('L''historique est vide.');
    Exit;
  End;

  If N <= 0 Then N := HIS_MAX_RECENT;
  If N > HistoryCount Then N := HistoryCount;

  StartIdx := HistoryCount - N + 1;
  If StartIdx < 1 Then StartIdx := 1;

  WriteLn('=== ', N, ' dernieres entrees ===');
  For I := StartIdx to HistoryCount do Begin
    WriteLn('[', I, '] Vous: ', History[I].UserInput);
    WriteLn('    Bot: ', Copy(History[I].BotResponse, 1, 60));
    If Length(History[I].BotResponse) > 60 Then
      WriteLn('    ...');
  End;
End;

Procedure ShowHistory;
Var
  I: Integer;
Begin
  If HistoryCount = 0 Then Begin
    WriteLn('L''historique est vide.');
    Exit;
  End;

  WriteLn('=== Historique de conversation ===');
  For I := 1 to HistoryCount do Begin
    WriteLn('[', I, '] Vous: ', History[I].UserInput);
    WriteLn('    Bot: ', Copy(History[I].BotResponse, 1, 60));
    If Length(History[I].BotResponse) > 60 Then
      WriteLn('    ...');
  End;
End;

Procedure ClearHistory;
Begin
  HistoryCount := 0;
  Inc(HisClearCount);
  WriteLn('Historique efface.');
End;

Function SaveHistory(FileName: String): Boolean;
Var
  F: Text;
  I: Integer;
Begin
  SaveHistory := False;
  {$I-}
  Assign(F, FileName);
  Rewrite(F);
  {$I+}
  If IOResult <> 0 Then Begin
    WriteLn('Erreur: Impossible de creer le fichier ', FileName);
    Inc(HisErrorCount);
    Exit;
  End;

  WriteLn(F, '# PASCHAT History File');
  WriteLn(F, '# Version: ', PASCHAT_VERSION);
  WriteLn(F, '# Entries: ', HistoryCount);
  WriteLn(F, '---');

  For I := 1 to HistoryCount do Begin
    WriteLn(F, '[ENTRY ', I, ']');
    WriteLn(F, 'USER=', History[I].UserInput);
    WriteLn(F, 'BOT=', History[I].BotResponse);
    If History[I].HasCode Then
      WriteLn(F, 'CODE=TRUE')
    Else
      WriteLn(F, 'CODE=FALSE');
    WriteLn(F, 'TIME=', History[I].Timestamp);
    WriteLn(F, '---');
  End;

  Close(F);
  Inc(HisSaveCount);
  SaveHistory := True;
  WriteLn('Historique sauvegarde dans ', FileName);
End;

Function LoadHistory(FileName: String): Boolean;
Var
  F: Text;
  Line, Key, Value: String;
  I, P: Integer;
  InEntry: Boolean;
Begin
  LoadHistory := False;
  {$I-}
  Assign(F, FileName);
  Reset(F);
  {$I+}
  If IOResult <> 0 Then Begin
    WriteLn('Erreur: Fichier introuvable ', FileName);
    Inc(HisErrorCount);
    Exit;
  End;

  HistoryCount := 0;
  InEntry := False;

  While Not Eof(F) do Begin
    ReadLn(F, Line);
    If Line = '' Then Continue;
    If Line[1] = '#' Then Continue;
    If Line = '---' Then Begin
      InEntry := False;
      Continue;
    End;

    If Pos('[ENTRY ', Line) = 1 Then Begin
      InEntry := True;
      If HistoryCount < MAX_HISTORY Then Begin
        Inc(HistoryCount);
        History[HistoryCount].UserInput := '';
        History[HistoryCount].BotResponse := '';
        History[HistoryCount].HasCode := False;
        History[HistoryCount].Timestamp := HistoryCount;
      End;
      Continue;
    End;

    If InEntry and (HistoryCount > 0) Then Begin
      P := Pos('=', Line);
      If P > 0 Then Begin
        Key := Copy(Line, 1, P - 1);
        Value := Copy(Line, P + 1, Length(Line) - P);
        If Key = 'USER' Then
          History[HistoryCount].UserInput := Value
        Else If Key = 'BOT' Then
          History[HistoryCount].BotResponse := Value
        Else If Key = 'CODE' Then
          History[HistoryCount].HasCode := (Value = 'TRUE')
        Else If Key = 'TIME' Then Begin
          Val(Value, History[HistoryCount].Timestamp, I);
          If I <> 0 Then History[HistoryCount].Timestamp := HistoryCount;
        End;
      End;
    End;
  End;

  Close(F);
  Inc(HisLoadCount);
  LoadHistory := True;
  WriteLn('Historique charge depuis ', FileName, ' (', HistoryCount, ' entrees)');
End;

Procedure DumpHisState;
Begin
  WriteLn('=== TODO 03 - Historique de Conversation ===');
  WriteLn('  HisInitialized : ', HisInitialized);
  WriteLn('  HisStateCount  : ', HisStateCount);
  WriteLn('  HisAddCount    : ', HisAddCount);
  WriteLn('  HisUserCount   : ', HisUserCount);
  WriteLn('  HisBotCount    : ', HisBotCount);
  WriteLn('  HisCodeCount   : ', HisCodeCount);
  WriteLn('  HisErrorCount  : ', HisErrorCount);
  WriteLn('  HisCommandCount: ', HisCommandCount);
  WriteLn('  HisClearCount  : ', HisClearCount);
  WriteLn('  HisLabelNum    : ', HisLabelNum);
  WriteLn('  HisSaveCount   : ', HisSaveCount);
  WriteLn('  HisLoadCount   : ', HisLoadCount);
  WriteLn('  HistoryCount   : ', HistoryCount);
End;

{ --- TODO 03 : 10 accesseurs standards --- }

Function IsHisInitialized: Boolean;
Begin
  IsHisInitialized := HisInitialized;
End;

Function IsHisEmpty: Boolean;
Begin
  IsHisEmpty := (HistoryCount = 0);
End;

Function GetHisStateCount: Integer;
Begin
  GetHisStateCount := HisStateCount;
End;

Function GetHisAddCount: Integer;
Begin
  GetHisAddCount := HisAddCount;
End;

Function GetHisUserCount: Integer;
Begin
  GetHisUserCount := HisUserCount;
End;

Function GetHisBotCount: Integer;
Begin
  GetHisBotCount := HisBotCount;
End;

Function GetHisCodeCount: Integer;
Begin
  GetHisCodeCount := HisCodeCount;
End;

Function GetHisClearCount: Integer;
Begin
  GetHisClearCount := HisClearCount;
End;

Function GetHisErrorCount: Integer;
Begin
  GetHisErrorCount := HisErrorCount;
End;

Function GetHisLabelNum: Integer;
Begin
  GetHisLabelNum := HisLabelNum;
End;

{ ============================================================
  TODO 04 - ANALYSEUR DE REQUETES UTILISATEUR
  ============================================================ }

Procedure InitIntent;
Begin
  CurrentIntent.Kind := IK_UNKNOWN;
  CurrentIntent.Subject := '';
  CurrentIntent.KeyCount := 0;
  CurrentIntent.ParamCnt := 0;
End;

Procedure ExtractKeywords(Input: String);
Var
  S, Word: String;
  I: Integer;
  InWord: Boolean;
Begin
  CurrentIntent.KeyCount := 0;
  S := Input + ' ';
  Word := '';
  InWord := False;

  For I := 1 to Length(S) do Begin
    If S[I] in ['a'..'z', 'A'..'Z', '0'..'9', '_', '-'] Then Begin
      Word := Word + S[I];
      InWord := True;
    End Else If InWord Then Begin
      If (Length(Word) >= 2) and (CurrentIntent.KeyCount < MAX_KEYWORDS) Then Begin
        Inc(CurrentIntent.KeyCount);
        CurrentIntent.Keywords[CurrentIntent.KeyCount] := LowerCaseStr(Word);
      End;
      Word := '';
      InWord := False;
    End;
  End;
End;

Function DetectIntent(Input: String): TIntentKind;
Var
  UI: String;
Begin
  UI := UpCaseStr(Input);
  DetectIntent := IK_UNKNOWN;

  { Commandes speciales }
  If (Pos('/QUIT', UI) = 1) or (Pos('/EXIT', UI) = 1) or
     (Pos('QUITTER', UI) > 0) or (Pos('AU REVOIR', UI) > 0) Then
    DetectIntent := IK_QUIT
  Else If (Pos('/HELP', UI) = 1) or (Pos('/AIDE', UI) = 1) Then
    DetectIntent := IK_HELP
  Else If (Pos('/SAVE', UI) = 1) or (Pos('/SAUV', UI) = 1) Then
    DetectIntent := IK_SAVE
  Else If (Pos('/HISTORY', UI) = 1) or (Pos('/HIST', UI) = 1) Then
    DetectIntent := IK_LIST
  Else If (Pos('/CLEAR', UI) = 1) or (Pos('/EFF', UI) = 1) Then
    DetectIntent := IK_CLEAR
  { Demandes de programme - AVANT salutations pour eviter "programme bonjour" }
  Else If (Pos('PROGRAMME', UI) > 0) or (Pos('PROGRAM', UI) > 0) or
          (Pos('CODE', UI) > 0) or (Pos('ECRIS', UI) > 0) or
          (Pos('GENERE', UI) > 0) or (Pos('CREE', UI) > 0) or
          (Pos('FAIS', UI) > 0) or (Pos('SORS', UI) > 0) or
          (Pos('AFFICHE', UI) > 0) Then Begin
    If (Pos('UNITE', UI) > 0) or (Pos('UNIT', UI) > 0) Then
      DetectIntent := IK_UNIT
    Else If (Pos('PROCEDURE', UI) > 0) Then
      DetectIntent := IK_PROCEDURE
    Else If (Pos('FONCTION', UI) > 0) or (Pos('FUNCTION', UI) > 0) Then
      DetectIntent := IK_FUNCTION
    Else
      DetectIntent := IK_PROGRAM;
  End
  { Salutations - seulement si ce n'est pas une demande de programme }
  Else If (Pos('BONJOUR', UI) > 0) or (Pos('SALUT', UI) > 0) or
          (Pos('ALLO', UI) > 0) or (Pos('HELLO', UI) > 0) Then
    DetectIntent := IK_HELLO
  { Demandes d'explication }
  Else If (Pos('EXPLIQUE', UI) > 0) or (Pos('COMMENT', UI) > 0) or
          (Pos('QU''EST', UI) > 0) or (Pos('C''EST QUOI', UI) > 0) Then
    DetectIntent := IK_EXPLAIN
  { Demandes d'aide }
  Else If (Pos('AIDE', UI) > 0) or (Pos('HELP', UI) > 0) Then
    DetectIntent := IK_HELP;
End;

Procedure ParseUserInput(Input: String);
Begin
  InitIntent;
  CurrentIntent.Kind := DetectIntent(Input);
  CurrentIntent.Subject := Input;
  ExtractKeywords(Input);

  If Options.DebugMode Then Begin
    WriteLn('[DEBUG] Intent: ', Ord(CurrentIntent.Kind));
    WriteLn('[DEBUG] Keywords: ', CurrentIntent.KeyCount);
  End;
End;

{ ============================================================
  TODO 05 - GENERATEUR DE CODE PASCAL - STRUCTURES DE BASE
  ============================================================ }

Procedure InitGeneratedCode;
Begin
  GeneratedCount := 0;
End;

Procedure AddCodeLine(Line: String);
Begin
  If GeneratedCount < MAX_CODE_LINES Then Begin
    Inc(GeneratedCount);
    GeneratedCode[GeneratedCount] := Line;
  End;
End;

Procedure GenProgramHeader(Name: String);
Begin
  AddCodeLine('Program ' + Name + ';');
  AddCodeLine('');
End;

Procedure GenUnitHeader(Name: String);
Begin
  AddCodeLine('Unit ' + Name + ';');
  AddCodeLine('');
  AddCodeLine('Interface');
  AddCodeLine('');
End;

Procedure GenUsesClause(Units: String);
Begin
  If Units <> '' Then Begin
    AddCodeLine('Uses');
    AddCodeLine('  ' + Units + ';');
    AddCodeLine('');
  End;
End;

Procedure GenVarSection(VarList: String);
Begin
  If VarList <> '' Then Begin
    AddCodeLine('Var');
    AddCodeLine('  ' + VarList);
    AddCodeLine('');
  End;
End;

Procedure GenConstSection(ConstList: String);
Begin
  If ConstList <> '' Then Begin
    AddCodeLine('Const');
    AddCodeLine('  ' + ConstList);
    AddCodeLine('');
  End;
End;

Procedure GenBeginEnd;
Begin
  AddCodeLine('Begin');
End;

Procedure GenEnd;
Begin
  AddCodeLine('End.');
End;

Procedure GenEndNoPoint;
Begin
  AddCodeLine('End;');
End;

{ ============================================================
  TODO 12 - GENERATION DE PROGRAMMES "BONJOUR"
  ============================================================ }

Procedure GenHelloWorld;
Begin
  InitGeneratedCode;
  GenProgramHeader('Bonjour');
  GenBeginEnd;
  AddCodeLine('  WriteLn(''Bonjour le monde!'');');
  GenEnd;
End;

Procedure GenHelloName(Name: String);
Begin
  InitGeneratedCode;
  GenProgramHeader('BonjourNom');
  GenBeginEnd;
  AddCodeLine('  WriteLn(''Bonjour ' + Name + '!'');');
  GenEnd;
End;

Procedure GenHelloInteractive;
Begin
  InitGeneratedCode;
  GenProgramHeader('BonjourInteractif');
  AddCodeLine('Var');
  AddCodeLine('  Nom: String;');
  AddCodeLine('');
  GenBeginEnd;
  AddCodeLine('  Write(''Entrez votre nom: '');');
  AddCodeLine('  ReadLn(Nom);');
  AddCodeLine('  WriteLn(''Bonjour '', Nom, ''!'');');
  GenEnd;
End;

{ ============================================================
  TODO 13 - GENERATION DE PROGRAMMES MATHEMATIQUES
  ============================================================ }

Procedure GenPrimeNumbers(N: Integer);
Var
  NS: String;
Begin
  Str(N, NS);
  InitGeneratedCode;
  GenProgramHeader('NombresPremiers');
  AddCodeLine('Var');
  AddCodeLine('  I, J, Count: Integer;');
  AddCodeLine('  IsPrime: Boolean;');
  AddCodeLine('');
  GenBeginEnd;
  AddCodeLine('  WriteLn(''Les ' + NS + ' premiers nombres premiers:'');');
  AddCodeLine('  Count := 0;');
  AddCodeLine('  I := 2;');
  AddCodeLine('  While Count < ' + NS + ' do Begin');
  AddCodeLine('    IsPrime := True;');
  AddCodeLine('    For J := 2 to I - 1 do');
  AddCodeLine('      If I mod J = 0 Then');
  AddCodeLine('        IsPrime := False;');
  AddCodeLine('    If IsPrime Then Begin');
  AddCodeLine('      Write(I, '' '');');
  AddCodeLine('      Inc(Count);');
  AddCodeLine('    End;');
  AddCodeLine('    Inc(I);');
  AddCodeLine('  End;');
  AddCodeLine('  WriteLn;');
  GenEnd;
End;

Procedure GenFibonacci(N: Integer);
Var
  NS: String;
Begin
  Str(N, NS);
  InitGeneratedCode;
  GenProgramHeader('Fibonacci');
  AddCodeLine('Var');
  AddCodeLine('  I: Integer;');
  AddCodeLine('  A, B, C: LongInt;');
  AddCodeLine('');
  GenBeginEnd;
  AddCodeLine('  WriteLn(''Suite de Fibonacci (' + NS + ' termes):'');');
  AddCodeLine('  A := 0;');
  AddCodeLine('  B := 1;');
  AddCodeLine('  For I := 1 to ' + NS + ' do Begin');
  AddCodeLine('    Write(A, '' '');');
  AddCodeLine('    C := A + B;');
  AddCodeLine('    A := B;');
  AddCodeLine('    B := C;');
  AddCodeLine('  End;');
  AddCodeLine('  WriteLn;');
  GenEnd;
End;

Procedure GenFactorial;
Begin
  InitGeneratedCode;
  GenProgramHeader('Factorielle');
  AddCodeLine('Var');
  AddCodeLine('  N, I: Integer;');
  AddCodeLine('  Fact: LongInt;');
  AddCodeLine('');
  GenBeginEnd;
  AddCodeLine('  Write(''Entrez un nombre: '');');
  AddCodeLine('  ReadLn(N);');
  AddCodeLine('  Fact := 1;');
  AddCodeLine('  For I := 2 to N do');
  AddCodeLine('    Fact := Fact * I;');
  AddCodeLine('  WriteLn(N, ''! = '', Fact);');
  GenEnd;
End;

Procedure GenCalculator;
Begin
  InitGeneratedCode;
  GenProgramHeader('Calculatrice');
  AddCodeLine('Var');
  AddCodeLine('  A, B: Real;');
  AddCodeLine('  Op: Char;');
  AddCodeLine('  Resultat: Real;');
  AddCodeLine('');
  GenBeginEnd;
  AddCodeLine('  WriteLn(''Calculatrice simple'');');
  AddCodeLine('  Write(''Premier nombre: '');');
  AddCodeLine('  ReadLn(A);');
  AddCodeLine('  Write(''Operateur (+, -, *, /): '');');
  AddCodeLine('  ReadLn(Op);');
  AddCodeLine('  Write(''Deuxieme nombre: '');');
  AddCodeLine('  ReadLn(B);');
  AddCodeLine('  Case Op of');
  AddCodeLine('    ''+'': Resultat := A + B;');
  AddCodeLine('    ''-'': Resultat := A - B;');
  AddCodeLine('    ''*'': Resultat := A * B;');
  AddCodeLine('    ''/'': If B <> 0 Then Resultat := A / B;');
  AddCodeLine('  End;');
  AddCodeLine('  WriteLn(''Resultat: '', Resultat:0:2);');
  GenEnd;
End;

{ ============================================================
  TODO 14 - GENERATION DE PROGRAMMES DATE/HEURE
  ============================================================ }

Procedure GenCurrentDateTime;
Begin
  InitGeneratedCode;
  GenProgramHeader('DateHeure');
  AddCodeLine('Uses');
  AddCodeLine('  Dos;');
  AddCodeLine('');
  AddCodeLine('Var');
  AddCodeLine('  Annee, Mois, Jour, JourSem: Word;');
  AddCodeLine('  Heure, Minute, Seconde, Sec100: Word;');
  AddCodeLine('');
  GenBeginEnd;
  AddCodeLine('  GetDate(Annee, Mois, Jour, JourSem);');
  AddCodeLine('  GetTime(Heure, Minute, Seconde, Sec100);');
  AddCodeLine('  WriteLn(''Date: '', Jour, ''/'', Mois, ''/'', Annee);');
  AddCodeLine('  WriteLn(''Heure: '', Heure, '':'', Minute, '':'', Seconde);');
  GenEnd;
End;

Procedure GenCalendar;
Begin
  InitGeneratedCode;
  GenProgramHeader('Calendrier');
  AddCodeLine('Uses');
  AddCodeLine('  Dos;');
  AddCodeLine('');
  AddCodeLine('Var');
  AddCodeLine('  Annee, Mois: Word;');
  AddCodeLine('  Jour, JourSem, JoursMax: Integer;');
  AddCodeLine('');
  AddCodeLine('Function JoursDansMois(M, A: Word): Integer;');
  AddCodeLine('Begin');
  AddCodeLine('  Case M of');
  AddCodeLine('    1,3,5,7,8,10,12: JoursDansMois := 31;');
  AddCodeLine('    4,6,9,11: JoursDansMois := 30;');
  AddCodeLine('    2: If (A mod 4 = 0) and ((A mod 100 <> 0) or (A mod 400 = 0))');
  AddCodeLine('         Then JoursDansMois := 29');
  AddCodeLine('         Else JoursDansMois := 28;');
  AddCodeLine('  End;');
  AddCodeLine('End;');
  AddCodeLine('');
  GenBeginEnd;
  AddCodeLine('  Write(''Entrez l''''annee: '');');
  AddCodeLine('  ReadLn(Annee);');
  AddCodeLine('  Write(''Entrez le mois (1-12): '');');
  AddCodeLine('  ReadLn(Mois);');
  AddCodeLine('  JoursMax := JoursDansMois(Mois, Annee);');
  AddCodeLine('  WriteLn;');
  AddCodeLine('  WriteLn(''Calendrier '', Mois, ''/'', Annee);');
  AddCodeLine('  WriteLn(''Di Lu Ma Me Je Ve Sa'');');
  AddCodeLine('  For Jour := 1 to JoursMax do Begin');
  AddCodeLine('    Write(Jour:3);');
  AddCodeLine('    If Jour mod 7 = 0 Then WriteLn;');
  AddCodeLine('  End;');
  AddCodeLine('  WriteLn;');
  GenEnd;
End;

{ ============================================================
  TODO 15 - GENERATION D'UNITES PERSONNALISEES
  ============================================================ }

Procedure GenTimeUnit;
Begin
  InitGeneratedCode;
  GenUnitHeader('TempsUtils');
  AddCodeLine('Uses');
  AddCodeLine('  Dos;');
  AddCodeLine('');
  AddCodeLine('Function GetCurrentHour: Word;');
  AddCodeLine('Function GetCurrentMinute: Word;');
  AddCodeLine('Function GetCurrentSecond: Word;');
  AddCodeLine('Function FormatTime(H, M, S: Word): String;');
  AddCodeLine('Procedure WaitSeconds(N: Integer);');
  AddCodeLine('');
  AddCodeLine('Implementation');
  AddCodeLine('');
  AddCodeLine('Function GetCurrentHour: Word;');
  AddCodeLine('Var H, M, S, S100: Word;');
  AddCodeLine('Begin');
  AddCodeLine('  GetTime(H, M, S, S100);');
  AddCodeLine('  GetCurrentHour := H;');
  AddCodeLine('End;');
  AddCodeLine('');
  AddCodeLine('Function GetCurrentMinute: Word;');
  AddCodeLine('Var H, M, S, S100: Word;');
  AddCodeLine('Begin');
  AddCodeLine('  GetTime(H, M, S, S100);');
  AddCodeLine('  GetCurrentMinute := M;');
  AddCodeLine('End;');
  AddCodeLine('');
  AddCodeLine('Function GetCurrentSecond: Word;');
  AddCodeLine('Var H, M, S, S100: Word;');
  AddCodeLine('Begin');
  AddCodeLine('  GetTime(H, M, S, S100);');
  AddCodeLine('  GetCurrentSecond := S;');
  AddCodeLine('End;');
  AddCodeLine('');
  AddCodeLine('Function FormatTime(H, M, S: Word): String;');
  AddCodeLine('Var HS, MS, SS, R: String;');
  AddCodeLine('Begin');
  AddCodeLine('  Str(H:2, HS);');
  AddCodeLine('  Str(M:2, MS);');
  AddCodeLine('  Str(S:2, SS);');
  AddCodeLine('  R := HS + '':'' + MS + '':'' + SS;');
  AddCodeLine('  FormatTime := R;');
  AddCodeLine('End;');
  AddCodeLine('');
  AddCodeLine('Procedure WaitSeconds(N: Integer);');
  AddCodeLine('Var I: LongInt;');
  AddCodeLine('Begin');
  AddCodeLine('  For I := 1 to N * 100000 do ;');
  AddCodeLine('End;');
  AddCodeLine('');
  AddCodeLine('End.');
End;

Procedure GenStringUnit;
Begin
  InitGeneratedCode;
  GenUnitHeader('ChainesUtils');
  AddCodeLine('Function Reverse(S: String): String;');
  AddCodeLine('Function CountChar(S: String; C: Char): Integer;');
  AddCodeLine('Function PadLeft(S: String; Len: Integer; C: Char): String;');
  AddCodeLine('Function PadRight(S: String; Len: Integer; C: Char): String;');
  AddCodeLine('Function RemoveSpaces(S: String): String;');
  AddCodeLine('');
  AddCodeLine('Implementation');
  AddCodeLine('');
  AddCodeLine('Function Reverse(S: String): String;');
  AddCodeLine('Var I: Integer; R: String;');
  AddCodeLine('Begin');
  AddCodeLine('  R := '''';');
  AddCodeLine('  For I := Length(S) downto 1 do');
  AddCodeLine('    R := R + S[I];');
  AddCodeLine('  Reverse := R;');
  AddCodeLine('End;');
  AddCodeLine('');
  AddCodeLine('Function CountChar(S: String; C: Char): Integer;');
  AddCodeLine('Var I, N: Integer;');
  AddCodeLine('Begin');
  AddCodeLine('  N := 0;');
  AddCodeLine('  For I := 1 to Length(S) do');
  AddCodeLine('    If S[I] = C Then Inc(N);');
  AddCodeLine('  CountChar := N;');
  AddCodeLine('End;');
  AddCodeLine('');
  AddCodeLine('Function PadLeft(S: String; Len: Integer; C: Char): String;');
  AddCodeLine('Begin');
  AddCodeLine('  While Length(S) < Len do');
  AddCodeLine('    S := C + S;');
  AddCodeLine('  PadLeft := S;');
  AddCodeLine('End;');
  AddCodeLine('');
  AddCodeLine('Function PadRight(S: String; Len: Integer; C: Char): String;');
  AddCodeLine('Begin');
  AddCodeLine('  While Length(S) < Len do');
  AddCodeLine('    S := S + C;');
  AddCodeLine('  PadRight := S;');
  AddCodeLine('End;');
  AddCodeLine('');
  AddCodeLine('Function RemoveSpaces(S: String): String;');
  AddCodeLine('Var I: Integer; R: String;');
  AddCodeLine('Begin');
  AddCodeLine('  R := '''';');
  AddCodeLine('  For I := 1 to Length(S) do');
  AddCodeLine('    If S[I] <> '' '' Then R := R + S[I];');
  AddCodeLine('  RemoveSpaces := R;');
  AddCodeLine('End;');
  AddCodeLine('');
  AddCodeLine('End.');
End;

{ ============================================================
  TODO 16 - INTERFACE DE CLAVARDAGE EN FRANCAIS
  ============================================================ }

Procedure InitChat;
Begin
  InitHistory;
  InitLearnFiles;
  InitGeneratedCode;
  InitIntent;
  CurrentMode := IM_NORMAL;
  Running := True;
  ErrorCount := 0;

  { Initialiser les options de formatage }
  FormatOpts.IndentSize := DEFAULT_INDENT;
  FormatOpts.MaxLineWidth := 80;
  FormatOpts.AddComments := False;
  FormatOpts.UpperKeywords := True;
End;

Procedure ShowWelcome;
Begin
  WriteLn;
  WriteLn('========================================');
  WriteLn('  PASCHAT - Agent conversationnel');
  WriteLn('  Generateur de code Turbo Pascal');
  WriteLn('  Version ', PASCHAT_VERSION);
  WriteLn('========================================');
  WriteLn;
  WriteLn('Bonjour! Je suis PASCHAT, votre assistant pour');
  WriteLn('generer du code en Turbo Pascal.');
  WriteLn;
  WriteLn('Exemples de requetes:');
  WriteLn('  - Ecris-moi un programme bonjour en Pascal');
  WriteLn('  - Genere les 10 premiers nombres premiers');
  WriteLn('  - Affiche la date et l''heure');
  WriteLn('  - Ecris une unite sur le temps');
  WriteLn;
  WriteLn('Tapez /help pour l''aide ou /quit pour quitter.');
  WriteLn;
End;

Procedure ShowPrompt;
Begin
  Write('Vous> ');
End;

Function ReadUserInput: String;
Var
  Input: String;
Begin
  ReadLn(Input);
  ReadUserInput := Trim(Input);
End;

Procedure DisplayCode;
Var
  I: Integer;
Begin
  If GeneratedCount = 0 Then Begin
    WriteLn('(Aucun code genere)');
    Exit;
  End;

  WriteLn;
  WriteLn('--- Code Pascal genere ---');
  For I := 1 to GeneratedCount do
    WriteLn(GeneratedCode[I]);
  WriteLn('--- Fin du code ---');
  WriteLn;
End;

Procedure ShowGoodbye;
Begin
  WriteLn;
  WriteLn('Au revoir! Merci d''avoir utilise PASCHAT.');
  WriteLn('A bientot!');
End;

{ ============================================================
  TODO 17 - SYSTEME DE REPONSES CONTEXTUELLES
  ============================================================ }

Function GenerateTextResponse(Intent: TIntentKind): String;
Begin
  Case Intent of
    IK_HELLO:
      GenerateTextResponse := 'Bonjour! Comment puis-je vous aider avec le Turbo Pascal aujourd''hui?';
    IK_HELP:
      GenerateTextResponse := 'Je peux generer du code Pascal. Demandez-moi un programme!';
    IK_QUIT:
      GenerateTextResponse := 'Au revoir et a bientot!';
    IK_UNKNOWN:
      GenerateTextResponse := 'Je n''ai pas compris. Pouvez-vous reformuler votre demande?';
  Else
    GenerateTextResponse := 'Je vais generer le code demande...';
  End;
End;

Procedure ProcessProgramRequest;
Var
  UI: String;
  N: Integer;
Begin
  UI := UpCaseStr(CurrentIntent.Subject);

  { Detecter le type de programme demande }
  If (Pos('BONJOUR', UI) > 0) or (Pos('HELLO', UI) > 0) Then Begin
    If Pos('INTERACTIF', UI) > 0 Then
      GenHelloInteractive
    Else
      GenHelloWorld;
    WriteLn('Voici un programme "Bonjour" en Pascal:');
  End
  Else If (Pos('PREMIER', UI) > 0) or (Pos('PRIME', UI) > 0) Then Begin
    { Extraire le nombre si present }
    N := 10; { Par defaut }
    If Pos('10', UI) > 0 Then N := 10
    Else If Pos('20', UI) > 0 Then N := 20
    Else If Pos('5', UI) > 0 Then N := 5
    Else If Pos('100', UI) > 0 Then N := 100;
    GenPrimeNumbers(N);
    WriteLn('Voici un programme affichant les ', N, ' premiers nombres premiers:');
  End
  Else If (Pos('FIBONACCI', UI) > 0) Then Begin
    N := 10;
    If Pos('20', UI) > 0 Then N := 20
    Else If Pos('15', UI) > 0 Then N := 15;
    GenFibonacci(N);
    WriteLn('Voici un programme affichant la suite de Fibonacci:');
  End
  Else If (Pos('FACTORIELLE', UI) > 0) or (Pos('FACTORIAL', UI) > 0) Then Begin
    GenFactorial;
    WriteLn('Voici un programme calculant une factorielle:');
  End
  Else If (Pos('CALCULATRICE', UI) > 0) or (Pos('CALCULATOR', UI) > 0) or
          (Pos('CALCULER', UI) > 0) Then Begin
    GenCalculator;
    WriteLn('Voici une calculatrice simple:');
  End
  Else If (Pos('DATE', UI) > 0) or (Pos('HEURE', UI) > 0) or
          (Pos('TIME', UI) > 0) Then Begin
    GenCurrentDateTime;
    WriteLn('Voici un programme affichant la date et l''heure:');
  End
  Else If (Pos('CALENDRIER', UI) > 0) or (Pos('CALENDAR', UI) > 0) Then Begin
    GenCalendar;
    WriteLn('Voici un programme generant un calendrier:');
  End
  Else Begin
    { Programme generique }
    GenHelloWorld;
    WriteLn('Voici un programme de base. Precisez votre demande pour un code plus specifique:');
  End;

  DisplayCode;
End;

Procedure ProcessUnitRequest;
Var
  UI: String;
Begin
  UI := UpCaseStr(CurrentIntent.Subject);

  If (Pos('TEMPS', UI) > 0) or (Pos('TIME', UI) > 0) or
     (Pos('HEURE', UI) > 0) Then Begin
    GenTimeUnit;
    WriteLn('Voici une unite pour la gestion du temps:');
  End
  Else If (Pos('CHAINE', UI) > 0) or (Pos('STRING', UI) > 0) or
          (Pos('TEXTE', UI) > 0) Then Begin
    GenStringUnit;
    WriteLn('Voici une unite pour la manipulation de chaines:');
  End
  Else Begin
    GenTimeUnit;
    WriteLn('Voici une unite exemple. Precisez le type d''unite souhaitee:');
  End;

  DisplayCode;
End;

{ ============================================================
  TODO 19 - AIDE EN LIGNE ET EXEMPLES
  ============================================================ }

Procedure ShowHelpCommand;
Begin
  WriteLn;
  WriteLn('=== Aide PASCHAT ===');
  WriteLn;
  WriteLn('Commandes disponibles:');
  WriteLn('  /help, /aide   - Afficher cette aide');
  WriteLn('  /quit, /exit   - Quitter le programme');
  WriteLn('  /save [nom]    - Sauvegarder le dernier code');
  WriteLn('  /history       - Afficher l''historique');
  WriteLn('  /clear         - Effacer l''historique');
  WriteLn;
  WriteLn('Exemples de requetes:');
  WriteLn('  "Ecris-moi un programme bonjour en Pascal"');
  WriteLn('  "Genere les 10 premiers nombres premiers"');
  WriteLn('  "Affiche la date et l''heure"');
  WriteLn('  "Ecris une unite sur le temps"');
  WriteLn('  "Fais-moi une calculatrice"');
  WriteLn('  "Programme de suite de Fibonacci"');
  WriteLn;
End;

{ ============================================================
  TODO 20 - SAUVEGARDE DES PROGRAMMES GENERES
  ============================================================ }

Procedure SaveProgram(FileName: String);
Var
  F: Text;
  I: Integer;
Begin
  If GeneratedCount = 0 Then Begin
    WriteLn('Aucun code a sauvegarder.');
    Exit;
  End;

  If FileName = '' Then
    FileName := 'OUTPUT.PAS';

  Assign(F, FileName);
  {$I-}
  Rewrite(F);
  {$I+}
  If IOResult <> 0 Then Begin
    WriteLn('Erreur: Impossible de creer le fichier ', FileName);
    Exit;
  End;

  For I := 1 to GeneratedCount do
    WriteLn(F, GeneratedCode[I]);

  Close(F);
  WriteLn('Code sauvegarde dans: ', FileName);
End;

Procedure HandleSaveCommand(Input: String);
Var
  FileName: String;
  P: Integer;
Begin
  { Extraire le nom de fichier apres /save }
  P := Pos(' ', Input);
  If P > 0 Then
    FileName := Trim(Copy(Input, P + 1, Length(Input)))
  Else
    FileName := 'OUTPUT.PAS';

  { Ajouter l'extension si absente }
  If Pos('.', FileName) = 0 Then
    FileName := FileName + '.PAS';

  SaveProgram(FileName);
End;

{ ============================================================
  TODO 25 - PROGRAMME PRINCIPAL ET BOUCLE DE CLAVARDAGE
  ============================================================ }

Procedure ProcessCommand(Input: String);
Var
  Response: String;
Begin
  If Input = '' Then Exit;

  ParseUserInput(Input);

  Case CurrentIntent.Kind of
    IK_QUIT: Begin
      Running := False;
      ShowGoodbye;
    End;

    IK_HELP: Begin
      ShowHelpCommand;
      Response := 'Aide affichee.';
    End;

    IK_HELLO: Begin
      Response := GenerateTextResponse(IK_HELLO);
      WriteLn('PASCHAT> ', Response);
    End;

    IK_PROGRAM: Begin
      ProcessProgramRequest;
      Response := 'Code genere.';
    End;

    IK_UNIT: Begin
      ProcessUnitRequest;
      Response := 'Unite generee.';
    End;

    IK_SAVE: Begin
      HandleSaveCommand(Input);
      Response := 'Sauvegarde effectuee.';
    End;

    IK_LIST: Begin
      ShowHistory;
      Response := 'Historique affiche.';
    End;

    IK_CLEAR: Begin
      ClearHistory;
      Response := 'Historique efface.';
    End;

    IK_EXPLAIN: Begin
      { Rechercher dans les fichiers d'apprentissage }
      Response := FindInLearnFiles(Input);
      If Response = '' Then
        Response := 'Je n''ai pas trouve d''information sur ce sujet.';
      WriteLn('PASCHAT> ', Response);
    End;

  Else
    Response := GenerateTextResponse(IK_UNKNOWN);
    WriteLn('PASCHAT> ', Response);
    WriteLn('Tapez /help pour voir les commandes disponibles.');
  End;

  { Ajouter a l'historique }
  AddToHistory(Input, Response, GeneratedCount > 0);
End;

Procedure MainLoop;
Var
  Input: String;
Begin
  While Running do Begin
    ShowPrompt;
    Input := ReadUserInput;
    ProcessCommand(Input);
  End;
End;

Procedure Cleanup;
Begin
  FreeLearnFiles;
End;

Procedure Run;
Begin
  { Charger les fichiers d'apprentissage }
  LoadAllLearnFiles;

  { Indexer le contenu charge (TODO 02) }
  IndexLearnContent;

  { Initialiser l'interface }
  InitChat;

  { Afficher le message de bienvenue }
  ShowWelcome;

  { Boucle principale }
  MainLoop;

  { Nettoyage }
  Cleanup;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Begin
  { Initialiser l'etat des options (TODO 01) }
  OptInitialized := False;
  InitOptState;

  ParseArgs;

  { Mettre a jour les compteurs d'options }
  If Options.Verbose Then Inc(OptVerboseCount);
  If Options.DebugMode Then Inc(OptDebugCount);
  If Options.ShowHelp Then Inc(OptHelpCount);
  OptLearnCount := Options.LearnFileCount;
  Inc(OptStateCount);

  If Options.ShowHelp Then Begin
    ShowUsage;
    Halt(EXIT_OK);
  End;

  If Options.Verbose Then
    ShowVersion;

  { Initialiser l'etat des fichiers d'apprentissage (TODO 02) }
  LrnInitialized := False;
  InitLearnState;

  { Initialiser l'etat de l'historique (TODO 03) }
  HisInitialized := False;
  InitHisState;

  { Afficher l'etat des options en mode debug }
  If Options.DebugMode Then Begin
    DumpOptState;
    DumpLearnState;
    DumpHisState;
  End;

  Run;

  { Message de fin pour les TODOs }
  { TODOs 01-25 : Statut actuel }
  { 01 [IMPLEMENTE] - Infrastructure et options }
  { 02 [IMPLEMENTE] - Chargement fichiers apprentissage }
  { 03 [IMPLEMENTE] - Historique de conversation }
  { 04 [IMPLEMENTE] - Analyseur de requetes }
  { 05 [A FAIRE] - Generateur structures de base }
  { 06 [A FAIRE] - Types et variables }
  { 07 [A FAIRE] - Expressions }
  { 08 [A FAIRE] - Structures de controle }
  { 09 [A FAIRE] - Procedures et fonctions }
  { 10 [A FAIRE] - Unites (UNIT) }
  { 11 [A FAIRE] - Templates de code }
  { 12 [IMPLEMENTE] - Programmes Bonjour }
  { 13 [IMPLEMENTE] - Programmes mathematiques }
  { 14 [IMPLEMENTE] - Programmes date/heure }
  { 15 [IMPLEMENTE] - Unites personnalisees }
  { 16 [IMPLEMENTE] - Interface clavardage }
  { 17 [IMPLEMENTE] - Reponses contextuelles }
  { 18 [A FAIRE] - Formatage code }
  { 19 [IMPLEMENTE] - Aide en ligne }
  { 20 [IMPLEMENTE] - Sauvegarde programmes }
  { 21 [A FAIRE] - Validation syntaxique }
  { 22 [A FAIRE] - Suggestions }
  { 23 [A FAIRE] - Mode interactif ameliore }
  { 24 [A FAIRE] - Export session }
  { 25 [IMPLEMENTE] - Programme principal }
End.
