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
  TODO 04 - ANALYSEUR DE REQUETES UTILISATEUR [IMPLEMENTE]
            TIntentKind : IK_UNKNOWN, IK_HELLO, IK_PROGRAM, IK_UNIT,
              IK_PROCEDURE, IK_FUNCTION, IK_EXPLAIN, IK_HELP, IK_QUIT
            TIntent : Kind, Subject, Keywords, Params
            ParseUserInput(Input) : analyser l'entree utilisateur
            DetectIntent(Input) : determiner l'intention de l'utilisateur
            ExtractKeywords(Input) : extraire les mots-cles de la requete
            KeywordMatch(Input, Keywords) : verifier la presence de mots-cles
            InitIntState, GenIntLabel, IntTypeName, DumpIntState
            10 accesseurs (IsIntInitialized, IsIntEmpty, GetInt*Count, ...)
  ============================================================ }

{ ============================================================
  TODO 05 - GENERATEUR DE CODE PASCAL - STRUCTURES DE BASE [IMPLEMENTE]
            GenProgramHeader(Name) : generer l'entete PROGRAM
            GenUnitHeader(Name) : generer l'entete UNIT
            GenUsesClause(Units) : generer la clause USES
            GenConstSection(Consts) : generer la section CONST
            GenVarSection(Vars) : generer la section VAR
            GenTypeSection(Types) : generer la section TYPE
            GenBeginEnd : generer le bloc BEGIN...END principal
            InitGenState, GenGenLabel, GenTypeName, DumpGenState
            10 accesseurs (IsGenInitialized, IsGenEmpty, GetGen*Count, ...)
  ============================================================ }

{ ============================================================
  TODO 06 - GENERATEUR DE CODE PASCAL - TYPES ET VARIABLES [IMPLEMENTE]
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
  TODO 07 - GENERATEUR DE CODE PASCAL - EXPRESSIONS [IMPLEMENTE]
            GenExpression(Expr) : generer une expression
            GenAssignment(Var, Expr) : generer une affectation
            GenArithExpr(Op, Left, Right) : generer une expression arithmetique
            GenCompareExpr(Op, Left, Right) : generer une comparaison
            GenLogicalExpr(Op, Left, Right) : generer une expression logique
            GenFunctionCall(Name, Args) : generer un appel de fonction
            GenStringExpr(Parts) : generer une concatenation de chaines
  ============================================================ }

{ ============================================================
  TODO 08 - GENERATEUR DE CODE PASCAL - STRUCTURES DE CONTROLE [IMPLEMENTE]
            GenIfThenElse(Cond, ThenPart, ElsePart) : generer IF..THEN..ELSE
            GenForLoop(Var, Start, End, Body) : generer FOR..TO..DO
            GenWhileLoop(Cond, Body) : generer WHILE..DO
            GenRepeatUntil(Body, Cond) : generer REPEAT..UNTIL
            GenCaseOf(Expr, Cases) : generer CASE..OF
            GenWithDo(Vars, Body) : generer WITH..DO
  ============================================================ }

{ ============================================================
  TODO 09 - GENERATEUR DE CODE PASCAL - PROCEDURES ET FONCTIONS [IMPLEMENTE]
            PRC_NONE=0..PRC_MAX=13 : constantes types de procedures
            PRC_MAX_PARAMS=16, PRC_MAX_LOCALS=32, PRC_MAX_BODY=100 : limites
            PrcInitialized + 16 variables d'etat
            InitPrcState : initialiser l'etat
            GenPrcLabel : generer un label unique
            PrcTypeName : nom du type de procedure
            GenParamDecl(Name, Type, IsVar, IsConst) : declaration parametre
            GenParamListStr : liste des parametres en chaine
            GenLocalVar(Name, Type) : variable locale
            GenProcedureHeader(Name, Params) : entete procedure
            GenFunctionHeader(Name, Params, RetType) : entete fonction
            GenSimpleProcedure, GenSimpleFunction : procedures/fonctions simples
            GenProcedureWithParams, GenFunctionWithParams : avec parametres
            GenProcedureWithLocals, GenFunctionWithLocals : avec vars locales
            GenProcCall, GenFuncCall : appels de procedure/fonction
            GenForwardProcedure, GenForwardFunction : declarations forward
            GenExternalProcedure, GenExternalFunction : externes
            GenNearProcedure, GenFarProcedure : near/far
            GenInlineProcedure, GenAssemblerProcedure : inline/asm
            GenRecursiveFactorial, GenRecursiveFibonacci : exemples recursifs
            GenBubbleSortProcedure, GenLinearSearchFunction : exemples utiles
            DumpPrcState : afficher l'etat
            10 accesseurs : IsPrcInitialized, IsPrcEmpty, GetPrc*Count
  ============================================================ }

{ ============================================================
  TODO 10 - GENERATEUR DE CODE PASCAL - UNITES (UNIT) [IMPLEMENTE]
            UNT_NONE=0..UNT_MAX=13 : constantes types d'unites
            UNT_MAX_INTF_PROC=64, UNT_MAX_IMPL_PROC=128, UNT_MAX_USES=16 : limites
            UntInitialized + 15 variables d'etat
            InitUntState : initialiser l'etat
            GenUntLabel : generer un label unique
            UntTypeName : nom du type d'unite
            GenUnitHeader(Name) : generer l'entete UNIT
            GenUnitInterfaceBegin : debut section Interface
            GenUnitInterfaceUses, GenUnitInterfaceConst, GenUnitInterfaceType
            GenUnitInterfaceVar, GenUnitInterfaceProc, GenUnitInterfaceFunc
            GenUnitImplementationBegin, GenUnitImplementationUses
            GenUnitImplProcSimple, GenUnitImplProcWithParams
            GenUnitImplFuncSimple, GenUnitImplFuncWithParams
            GenUnitInitialization, GenUnitInitLine
            GenUnitFinalization, GenUnitFinalLine
            GenUnitEnd : fin de l'unite
            GenSimpleUnit, GenUnitWithUses, GenCompleteUnit
            GenCrtStyleUnit, GenStringUtilUnit, GenMathUtilUnit
            DumpUntState : afficher l'etat
            10 accesseurs : IsUntInitialized, IsUntEmpty, GetUnt*Count
  ============================================================ }

{ ============================================================
  TODO 11 - BIBLIOTHEQUE DE TEMPLATES DE CODE [IMPLEMENTE]
            TTemplate : Name, Description, Code, Parameters
            Templates[0..MAX_TEMPLATES-1], TemplateCount
            LoadBuiltinTemplates : charger les templates predefinies
            FindTemplate(Name) : chercher un template par nom
            ApplyTemplate(Template, Params) : appliquer un template avec parametres
            ListTemplates : lister les templates disponibles
  ============================================================ }

{ ============================================================
  TODO 12 - GENERATION DE PROGRAMMES "BONJOUR" [IMPLEMENTE]
            HLO_NONE=0..HLO_MAX=13 : constantes types de programmes
            HLO_MAX_LANGS=10, HLO_MAX_LINES=20 : limites
            HloInitialized + 15 variables d'etat
            InitHloState : initialiser l'etat
            GenHloLabel : generer un label unique
            HloTypeName : nom du type de programme Bonjour
            GenHelloWorld : generer un programme "Bonjour le monde"
            GenHelloName(Name) : generer un programme avec nom personnalise
            GenHelloInteractive : generer un programme avec saisie du nom
            GenHelloMultilingual : generer un programme multilingue
            GenHelloGraphic : generer un programme avec affichage graphique
            GenHelloBordered : generer un programme avec bordure
            GenHelloCentered : generer un programme centre
            GenHelloTimed : generer un programme avec heure
            GenHelloColored : generer un programme colore
            GenHelloAnimated : generer un programme anime
            GenHelloRandom : generer un programme aleatoire
            DumpHloState : afficher l'etat
            10 accesseurs : IsHloInitialized, IsHloEmpty, GetHlo*Count
  ============================================================ }

{ ============================================================
  TODO 13 - GENERATION DE PROGRAMMES MATHEMATIQUES [IMPLEMENTE]
            GenPrimeNumbers(N) : generer un programme affichant N premiers
            GenFibonacci(N) : generer un programme de suite de Fibonacci
            GenFactorial : generer un programme de calcul de factorielle
            GenGCD : generer un programme de calcul de PGCD
            GenCalculator : generer une calculatrice simple
            GenPrimeCheck : generer un verificateur de nombre premier
  ============================================================ }

{ ============================================================
  TODO 14 - GENERATION DE PROGRAMMES DATE/HEURE [IMPLEMENTE]
            DTM_NONE=0..DTM_MAX=13 : constantes types de programmes
            DTM_MAX_MONTHS=12, DTM_MAX_DAYS=31 : limites
            DtmInitialized + 15 variables d'etat
            InitDtmState : initialiser l'etat
            GenDtmLabel : generer un label unique
            DtmTypeName : nom du type de programme date/heure
            GenCurrentDateTime : generer un programme affichant date et heure
            GenDateFormat : generer un programme formatant une date
            GenTimeCalc : generer un programme de calcul de durees
            GenCalendar : generer un calendrier mensuel
            GenStopwatch : generer un chronometre simple
            GenCountdown : generer un compte a rebours
            DumpDtmState : afficher l'etat
            10 accesseurs : IsDtmInitialized, IsDtmEmpty, GetDtm*Count
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

  { TODO 04 - Types d'intentions utilisateur (INT_*) }
  INT_NONE       = 0;   { Aucune intention }
  INT_UNKNOWN    = 1;   { Intention non reconnue }
  INT_HELLO      = 2;   { Salutation }
  INT_PROGRAM    = 3;   { Demande de programme }
  INT_UNIT       = 4;   { Demande d'unite }
  INT_PROCEDURE  = 5;   { Demande de procedure }
  INT_FUNCTION   = 6;   { Demande de fonction }
  INT_EXPLAIN    = 7;   { Demande d'explication }
  INT_HELP       = 8;   { Demande d'aide }
  INT_SAVE       = 9;   { Commande de sauvegarde }
  INT_LIST       = 10;  { Demande de liste }
  INT_CLEAR      = 11;  { Commande d'effacement }
  INT_QUIT       = 12;  { Commande de sortie }
  INT_MAX        = 13;  { Nombre maximum de types }

  { Limites pour TODO 04 }
  INT_MAX_KEYWORDS = 64;  { Nombre max de mots-cles par requete }
  INT_MIN_KEYWORD  = 2;   { Longueur minimale d'un mot-cle }

  { TODO 05 - Types de generation de code (GEN_*) }
  GEN_NONE       = 0;   { Aucune generation }
  GEN_PROGRAM    = 1;   { Entete PROGRAM }
  GEN_UNIT       = 2;   { Entete UNIT }
  GEN_USES       = 3;   { Clause USES }
  GEN_CONST      = 4;   { Section CONST }
  GEN_TYPE       = 5;   { Section TYPE }
  GEN_VAR        = 6;   { Section VAR }
  GEN_BEGIN      = 7;   { Bloc BEGIN }
  GEN_END        = 8;   { Bloc END }
  GEN_INTERFACE  = 9;   { Section INTERFACE }
  GEN_IMPLEMENT  = 10;  { Section IMPLEMENTATION }
  GEN_COMMENT    = 11;  { Commentaire }
  GEN_MAX        = 12;  { Nombre maximum de types }

  { Limites pour TODO 05 }
  GEN_MAX_LINES  = 4096; { Nombre max de lignes generees }
  GEN_MAX_INDENT = 20;   { Niveau d'indentation maximum }

  { TODO 06 - Types de donnees Pascal (TYP_*) }
  TYP_NONE      = 0;   { Aucun type }
  TYP_INTEGER   = 1;   { Type Integer }
  TYP_STRING    = 2;   { Type String }
  TYP_REAL      = 3;   { Type Real }
  TYP_BOOLEAN   = 4;   { Type Boolean }
  TYP_CHAR      = 5;   { Type Char }
  TYP_BYTE      = 6;   { Type Byte }
  TYP_WORD      = 7;   { Type Word }
  TYP_LONGINT   = 8;   { Type LongInt }
  TYP_ARRAY     = 9;   { Type Array }
  TYP_RECORD    = 10;  { Type Record }
  TYP_POINTER   = 11;  { Type Pointer }
  TYP_FILE      = 12;  { Type File }
  TYP_MAX       = 13;  { Nombre maximum de types }

  { Limites pour TODO 06 }
  TYP_MAX_FIELDS = 32;  { Nombre max de champs dans un record }
  TYP_MAX_BOUNDS = 8;   { Nombre max de dimensions dans un array }

  { TODO 07 - Types d'expressions (EXP_*) }
  EXP_NONE        = 0;   { Aucune expression }
  EXP_LITERAL     = 1;   { Litterale (nombre, chaine) }
  EXP_IDENTIFIER  = 2;   { Identificateur (variable) }
  EXP_ARITHMETIC  = 3;   { Expression arithmetique }
  EXP_COMPARE     = 4;   { Expression de comparaison }
  EXP_LOGICAL     = 5;   { Expression logique }
  EXP_UNARY       = 6;   { Expression unaire (NOT, -) }
  EXP_FUNCALL     = 7;   { Appel de fonction }
  EXP_PARENTHESIS = 8;   { Expression entre parentheses }
  EXP_ARRAY_ACCESS= 9;   { Acces tableau (A[i]) }
  EXP_FIELD_ACCESS= 10;  { Acces champ (R.Field) }
  EXP_STRING_CAT  = 11;  { Concatenation de chaines }
  EXP_ASSIGNMENT  = 12;  { Affectation }
  EXP_MAX         = 13;  { Nombre maximum de types d'expressions }

  { Operateurs pour TODO 07 }
  OP_NONE  = 0;   { Aucun operateur }
  OP_ADD   = 1;   { + }
  OP_SUB   = 2;   { - }
  OP_MUL   = 3;   { * }
  OP_DIV   = 4;   { / }
  OP_IDIV  = 5;   { DIV }
  OP_MOD   = 6;   { MOD }
  OP_EQ    = 7;   { = }
  OP_NE    = 8;   { <> }
  OP_LT    = 9;   { < }
  OP_LE    = 10;  { <= }
  OP_GT    = 11;  { > }
  OP_GE    = 12;  { >= }
  OP_AND   = 13;  { AND }
  OP_OR    = 14;  { OR }
  OP_NOT   = 15;  { NOT }
  OP_XOR   = 16;  { XOR }
  OP_MAX   = 17;  { Nombre maximum d'operateurs }

  { Limites pour TODO 07 }
  EXP_MAX_ARGS   = 16;  { Nombre max d'arguments dans un appel }
  EXP_MAX_PARTS  = 32;  { Nombre max de parties dans une concatenation }

  { Types de structures de controle pour TODO 08 }
  CTL_NONE       = 0;   { Aucune structure }
  CTL_IF_THEN    = 1;   { IF..THEN }
  CTL_IF_ELSE    = 2;   { IF..THEN..ELSE }
  CTL_FOR_TO     = 3;   { FOR..TO..DO }
  CTL_FOR_DOWNTO = 4;   { FOR..DOWNTO..DO }
  CTL_WHILE      = 5;   { WHILE..DO }
  CTL_REPEAT     = 6;   { REPEAT..UNTIL }
  CTL_CASE       = 7;   { CASE..OF }
  CTL_WITH       = 8;   { WITH..DO }
  CTL_BREAK      = 9;   { Break (non-standard) }
  CTL_CONTINUE   = 10;  { Continue (non-standard) }
  CTL_EXIT       = 11;  { Exit }
  CTL_HALT       = 12;  { Halt }
  CTL_MAX        = 13;  { Nombre maximum de types de structures }

  { Limites pour TODO 08 }
  CTL_MAX_CASES  = 32;  { Nombre max de cas dans un CASE }
  CTL_MAX_VARS   = 16;  { Nombre max de variables dans un WITH }

  { Types de procedures/fonctions pour TODO 09 }
  PRC_NONE       = 0;   { Aucune procedure }
  PRC_PROCEDURE  = 1;   { Procedure simple }
  PRC_FUNCTION   = 2;   { Fonction }
  PRC_FORWARD    = 3;   { Declaration forward }
  PRC_EXTERNAL   = 4;   { Procedure externe }
  PRC_INLINE     = 5;   { Procedure inline }
  PRC_INTERRUPT  = 6;   { Procedure d'interruption }
  PRC_NEAR       = 7;   { Procedure near }
  PRC_FAR        = 8;   { Procedure far }
  PRC_ASSEMBLER  = 9;   { Procedure assembleur }
  PRC_VIRTUAL    = 10;  { Methode virtuelle }
  PRC_OVERRIDE   = 11;  { Methode override }
  PRC_ABSTRACT   = 12;  { Methode abstraite }
  PRC_MAX        = 13;  { Nombre maximum de types }

  { Limites pour TODO 09 }
  PRC_MAX_PARAMS = 16;  { Nombre max de parametres }
  PRC_MAX_LOCALS = 32;  { Nombre max de variables locales }
  PRC_MAX_BODY   = 100; { Nombre max de lignes dans le corps }

  { Types d'unites pour TODO 10 }
  UNT_NONE       = 0;   { Aucune unite }
  UNT_SIMPLE     = 1;   { Unite simple }
  UNT_WITH_USES  = 2;   { Unite avec clause Uses }
  UNT_WITH_INIT  = 3;   { Unite avec Initialization }
  UNT_WITH_FINAL = 4;   { Unite avec Finalization }
  UNT_COMPLETE   = 5;   { Unite complete }
  UNT_LIBRARY    = 6;   { Unite de type library }
  UNT_SYSTEM     = 7;   { Unite systeme }
  UNT_CRT        = 8;   { Unite CRT }
  UNT_DOS        = 9;   { Unite DOS }
  UNT_GRAPH      = 10;  { Unite Graph }
  UNT_STRINGS    = 11;  { Unite Strings }
  UNT_PRINTER    = 12;  { Unite Printer }
  UNT_MAX        = 13;  { Nombre maximum de types d'unites }

  { Limites pour TODO 10 }
  UNT_MAX_INTF_PROC = 64;  { Nombre max de declarations interface }
  UNT_MAX_IMPL_PROC = 128; { Nombre max de procedures implementation }
  UNT_MAX_USES      = 16;  { Nombre max d'unites dans Uses }

  { Types de templates pour TODO 11 }
  TPL_NONE       = 0;   { Aucun template }
  TPL_PROGRAM    = 1;   { Template de programme }
  TPL_UNIT       = 2;   { Template d'unite }
  TPL_PROCEDURE  = 3;   { Template de procedure }
  TPL_FUNCTION   = 4;   { Template de fonction }
  TPL_LOOP       = 5;   { Template de boucle }
  TPL_CONDITION  = 6;   { Template de condition }
  TPL_INPUT      = 7;   { Template de saisie }
  TPL_OUTPUT     = 8;   { Template d'affichage }
  TPL_FILE       = 9;   { Template de fichier }
  TPL_ARRAY      = 10;  { Template de tableau }
  TPL_RECORD     = 11;  { Template d'enregistrement }
  TPL_MENU       = 12;  { Template de menu }
  TPL_MAX        = 13;  { Nombre maximum de types de templates }

  { Limites pour TODO 11 }
  TPL_MAX_PARAMS = 8;    { Nombre max de parametres par template }
  TPL_MAX_LINES  = 50;   { Nombre max de lignes par template }
  TPL_MAX_BUILTIN = 20;  { Nombre max de templates predefinies }

  { Types de programmes Bonjour pour TODO 12 }
  HLO_NONE        = 0;   { Aucun type }
  HLO_WORLD       = 1;   { Bonjour le monde }
  HLO_NAME        = 2;   { Bonjour avec nom }
  HLO_INTERACTIVE = 3;   { Bonjour interactif }
  HLO_MULTILANG   = 4;   { Bonjour multilingue }
  HLO_GRAPHIC     = 5;   { Bonjour graphique }
  HLO_ANIMATED    = 6;   { Bonjour anime }
  HLO_COLORED     = 7;   { Bonjour colore }
  HLO_SOUND       = 8;   { Bonjour avec son }
  HLO_CENTERED    = 9;   { Bonjour centre }
  HLO_BORDERED    = 10;  { Bonjour avec bordure }
  HLO_TIMED       = 11;  { Bonjour avec heure }
  HLO_RANDOM      = 12;  { Bonjour aleatoire }
  HLO_MAX         = 13;  { Nombre maximum de types }

  { Limites pour TODO 12 }
  HLO_MAX_LANGS   = 10;  { Nombre max de langues }
  HLO_MAX_LINES   = 20;  { Nombre max de lignes pour bordures }

  { Types de programmes mathematiques pour TODO 13 }
  MTH_NONE        = 0;   { Aucun type }
  MTH_PRIMES      = 1;   { Nombres premiers }
  MTH_FIBONACCI   = 2;   { Suite de Fibonacci }
  MTH_FACTORIAL   = 3;   { Factorielle }
  MTH_GCD         = 4;   { PGCD }
  MTH_LCM         = 5;   { PPCM }
  MTH_CALCULATOR  = 6;   { Calculatrice }
  MTH_PRIMECHECK  = 7;   { Verification nombre premier }
  MTH_POWER       = 8;   { Puissance }
  MTH_SQRT        = 9;   { Racine carree }
  MTH_TRIANGLE    = 10;  { Triangle de Pascal }
  MTH_PERFECT     = 11;  { Nombres parfaits }
  MTH_ARMSTRONG   = 12;  { Nombres d'Armstrong }
  MTH_MAX         = 13;  { Nombre maximum de types }

  { Limites pour TODO 13 }
  MTH_MAX_TERMS   = 100; { Nombre max de termes }
  MTH_MAX_VALUE   = 1000; { Valeur max pour calculs }

  { Types de programmes date/heure pour TODO 14 }
  DTM_NONE        = 0;   { Aucun type }
  DTM_DATETIME    = 1;   { Date et heure }
  DTM_DATEFORMAT  = 2;   { Formatage de date }
  DTM_TIMECALC    = 3;   { Calcul de durees }
  DTM_CALENDAR    = 4;   { Calendrier }
  DTM_STOPWATCH   = 5;   { Chronometre }
  DTM_COUNTDOWN   = 6;   { Compte a rebours }
  DTM_DAYOFWEEK   = 7;   { Jour de la semaine }
  DTM_DATEDIFF    = 8;   { Difference de dates }
  DTM_ADDDAYS     = 9;   { Ajouter des jours }
  DTM_LEAPYEAR    = 10;  { Annee bissextile }
  DTM_AGECHECK    = 11;  { Calcul d'age }
  DTM_TIMEZONE    = 12;  { Fuseaux horaires }
  DTM_MAX         = 13;  { Nombre maximum de types }

  { Limites pour TODO 14 }
  DTM_MAX_MONTHS  = 12;  { Nombre max de mois }
  DTM_MAX_DAYS    = 31;  { Nombre max de jours }

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

  { TODO 04 - Intention courante et etat }
  CurrentIntent  : TIntent;
  IntInitialized : Boolean;
  IntStateCount  : Integer;
  IntParseCount  : Integer;
  IntUnknownCount: Integer;
  IntHelloCount  : Integer;
  IntProgramCount: Integer;
  IntUnitCount   : Integer;
  IntProcCount   : Integer;
  IntFuncCount   : Integer;
  IntExplainCount: Integer;
  IntHelpCount   : Integer;
  IntQuitCount   : Integer;
  IntKeywordCount: Integer;
  IntMatchCount  : Integer;
  IntErrorCount  : Integer;
  IntLabelNum    : Integer;

  { TODO 05 - Etat du generateur de code }
  GenInitialized  : Boolean;
  GenStateCount   : Integer;
  GenProgramCount : Integer;
  GenUnitCount    : Integer;
  GenUsesCount    : Integer;
  GenConstCount   : Integer;
  GenTypeCount    : Integer;
  GenVarCount     : Integer;
  GenBeginCount   : Integer;
  GenEndCount     : Integer;
  GenInterfaceCount : Integer;
  GenImplementCount : Integer;
  GenCommentCount : Integer;
  GenLineCount    : Integer;
  GenErrorCount   : Integer;
  GenLabelNum     : Integer;

  { TODO 06 - Etat du generateur de types et variables }
  TypInitialized  : Boolean;
  TypStateCount   : Integer;
  TypVarDeclCount : Integer;
  TypConstDeclCount: Integer;
  TypTypeDeclCount: Integer;
  TypArrayCount   : Integer;
  TypRecordCount  : Integer;
  TypPointerCount : Integer;
  TypFieldCount   : Integer;
  TypIntegerCount : Integer;
  TypStringCount  : Integer;
  TypBooleanCount : Integer;
  TypRealCount    : Integer;
  TypErrorCount   : Integer;
  TypLabelNum     : Integer;

  { TODO 07 - Variables d'etat du generateur d'expressions }
  ExpInitialized  : Boolean;
  ExpStateCount   : Integer;
  ExpLiteralCount : Integer;
  ExpIdentCount   : Integer;
  ExpArithCount   : Integer;
  ExpCompareCount : Integer;
  ExpLogicalCount : Integer;
  ExpUnaryCount   : Integer;
  ExpFunCallCount : Integer;
  ExpArrayAccCount: Integer;
  ExpFieldAccCount: Integer;
  ExpStringCatCount: Integer;
  ExpAssignCount  : Integer;
  ExpErrorCount   : Integer;
  ExpLabelNum     : Integer;

  { TODO 08 - Variables d'etat du generateur de structures de controle }
  CtlInitialized  : Boolean;
  CtlStateCount   : Integer;
  CtlIfThenCount  : Integer;
  CtlIfElseCount  : Integer;
  CtlForToCount   : Integer;
  CtlForDownCount : Integer;
  CtlWhileCount   : Integer;
  CtlRepeatCount  : Integer;
  CtlCaseCount    : Integer;
  CtlWithCount    : Integer;
  CtlBreakCount   : Integer;
  CtlExitCount    : Integer;
  CtlErrorCount   : Integer;
  CtlLabelNum     : Integer;

  { TODO 09 - Procedures et fonctions }
  PrcInitialized  : Boolean;
  PrcStateCount   : Integer;
  PrcProcCount    : Integer;
  PrcFuncCount    : Integer;
  PrcForwardCount : Integer;
  PrcExternalCount: Integer;
  PrcInlineCount  : Integer;
  PrcNearCount    : Integer;
  PrcFarCount     : Integer;
  PrcAsmCount     : Integer;
  PrcVirtualCount : Integer;
  PrcCallCount    : Integer;
  PrcParamCount   : Integer;
  PrcLocalCount   : Integer;
  PrcErrorCount   : Integer;
  PrcLabelNum     : Integer;

  { TODO 10 - Unites (UNIT) }
  UntInitialized  : Boolean;
  UntStateCount   : Integer;
  UntSimpleCount  : Integer;
  UntWithUsesCount: Integer;
  UntWithInitCount: Integer;
  UntWithFinalCount: Integer;
  UntCompleteCount: Integer;
  UntIntfProcCount: Integer;
  UntImplProcCount: Integer;
  UntUsesCount    : Integer;
  UntConstCount   : Integer;
  UntTypeCount    : Integer;
  UntVarCount     : Integer;
  UntErrorCount   : Integer;
  UntLabelNum     : Integer;

  { TODO 11 - Templates }
  Templates       : Array[1..MAX_TEMPLATES] of TTemplate;
  TemplateCount   : Integer;
  TplInitialized  : Boolean;
  TplStateCount   : Integer;
  TplProgramCount : Integer;
  TplUnitCount    : Integer;
  TplProcCount    : Integer;
  TplFuncCount    : Integer;
  TplLoopCount    : Integer;
  TplCondCount    : Integer;
  TplIOCount      : Integer;
  TplFileCount    : Integer;
  TplArrayCount   : Integer;
  TplRecordCount  : Integer;
  TplApplyCount   : Integer;
  TplFindCount    : Integer;
  TplErrorCount   : Integer;
  TplLabelNum     : Integer;

  { TODO 12 - Programmes Bonjour }
  HloInitialized  : Boolean;
  HloStateCount   : Integer;
  HloWorldCount   : Integer;
  HloNameCount    : Integer;
  HloInteractCount: Integer;
  HloMultiLangCount: Integer;
  HloGraphicCount : Integer;
  HloAnimatedCount: Integer;
  HloColoredCount : Integer;
  HloSoundCount   : Integer;
  HloCenteredCount: Integer;
  HloBorderedCount: Integer;
  HloTimedCount   : Integer;
  HloRandomCount  : Integer;
  HloErrorCount   : Integer;
  HloLabelNum     : Integer;

  { TODO 13 - Programmes mathematiques }
  MthInitialized  : Boolean;
  MthStateCount   : Integer;
  MthPrimesCount  : Integer;
  MthFiboCount    : Integer;
  MthFactCount    : Integer;
  MthGCDCount     : Integer;
  MthLCMCount     : Integer;
  MthCalcCount    : Integer;
  MthPrimeChkCount: Integer;
  MthPowerCount   : Integer;
  MthSqrtCount    : Integer;
  MthTriangleCount: Integer;
  MthPerfectCount : Integer;
  MthArmstrongCount: Integer;
  MthErrorCount   : Integer;
  MthLabelNum     : Integer;

  { TODO 14 - Programmes date/heure }
  DtmInitialized  : Boolean;
  DtmStateCount   : Integer;
  DtmDateTimeCount: Integer;
  DtmDateFmtCount : Integer;
  DtmTimeCalcCount: Integer;
  DtmCalendarCount: Integer;
  DtmStopwatchCount: Integer;
  DtmCountdownCount: Integer;
  DtmDayOfWeekCount: Integer;
  DtmDateDiffCount: Integer;
  DtmAddDaysCount : Integer;
  DtmLeapYearCount: Integer;
  DtmAgeCheckCount: Integer;
  DtmTimezoneCount: Integer;
  DtmErrorCount   : Integer;
  DtmLabelNum     : Integer;

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

  { Incrementer les compteurs selon le type d'intention }
  Inc(IntParseCount);
  Case CurrentIntent.Kind of
    IK_UNKNOWN   : Inc(IntUnknownCount);
    IK_HELLO     : Inc(IntHelloCount);
    IK_PROGRAM   : Inc(IntProgramCount);
    IK_UNIT      : Inc(IntUnitCount);
    IK_PROCEDURE : Inc(IntProcCount);
    IK_FUNCTION  : Inc(IntFuncCount);
    IK_EXPLAIN   : Inc(IntExplainCount);
    IK_HELP      : Inc(IntHelpCount);
    IK_QUIT      : Inc(IntQuitCount);
  End;
  IntKeywordCount := IntKeywordCount + CurrentIntent.KeyCount;

  If Options.DebugMode Then Begin
    WriteLn('[DEBUG] Intent: ', Ord(CurrentIntent.Kind));
    WriteLn('[DEBUG] Keywords: ', CurrentIntent.KeyCount);
  End;
End;

{ --- TODO 04 : InitIntState, GenIntLabel, IntTypeName --- }

Procedure InitIntState;
Begin
  IntInitialized := True;
  IntStateCount  := 0;
  IntParseCount  := 0;
  IntUnknownCount := 0;
  IntHelloCount  := 0;
  IntProgramCount := 0;
  IntUnitCount   := 0;
  IntProcCount   := 0;
  IntFuncCount   := 0;
  IntExplainCount := 0;
  IntHelpCount   := 0;
  IntQuitCount   := 0;
  IntKeywordCount := 0;
  IntMatchCount  := 0;
  IntErrorCount  := 0;
  IntLabelNum    := 0;
  Inc(IntStateCount);
End;

Function GenIntLabel: String;
Var
  S: String;
Begin
  Inc(IntLabelNum);
  Str(IntLabelNum, S);
  GenIntLabel := '_INT_L_' + S;
End;

Function IntTypeName(TypeCode: Integer): String;
Begin
  Case TypeCode of
    INT_NONE     : IntTypeName := 'NONE';
    INT_UNKNOWN  : IntTypeName := 'UNKNOWN';
    INT_HELLO    : IntTypeName := 'HELLO';
    INT_PROGRAM  : IntTypeName := 'PROGRAM';
    INT_UNIT     : IntTypeName := 'UNIT';
    INT_PROCEDURE: IntTypeName := 'PROCEDURE';
    INT_FUNCTION : IntTypeName := 'FUNCTION';
    INT_EXPLAIN  : IntTypeName := 'EXPLAIN';
    INT_HELP     : IntTypeName := 'HELP';
    INT_SAVE     : IntTypeName := 'SAVE';
    INT_LIST     : IntTypeName := 'LIST';
    INT_CLEAR    : IntTypeName := 'CLEAR';
    INT_QUIT     : IntTypeName := 'QUIT';
    Else IntTypeName := '???';
  End;
End;

Function KeywordMatch(Input: String; Keywords: Array of String): Boolean;
Var
  UI: String;
  I: Integer;
Begin
  UI := UpCaseStr(Input);
  KeywordMatch := False;
  For I := 0 to High(Keywords) do Begin
    If Pos(UpCaseStr(Keywords[I]), UI) > 0 Then Begin
      KeywordMatch := True;
      Inc(IntMatchCount);
      Exit;
    End;
  End;
End;

Procedure DumpIntState;
Begin
  WriteLn('=== TODO 04 - Analyseur de Requetes Utilisateur ===');
  WriteLn('  IntInitialized : ', IntInitialized);
  WriteLn('  IntStateCount  : ', IntStateCount);
  WriteLn('  IntParseCount  : ', IntParseCount);
  WriteLn('  IntUnknownCount: ', IntUnknownCount);
  WriteLn('  IntHelloCount  : ', IntHelloCount);
  WriteLn('  IntProgramCount: ', IntProgramCount);
  WriteLn('  IntUnitCount   : ', IntUnitCount);
  WriteLn('  IntProcCount   : ', IntProcCount);
  WriteLn('  IntFuncCount   : ', IntFuncCount);
  WriteLn('  IntExplainCount: ', IntExplainCount);
  WriteLn('  IntHelpCount   : ', IntHelpCount);
  WriteLn('  IntQuitCount   : ', IntQuitCount);
  WriteLn('  IntKeywordCount: ', IntKeywordCount);
  WriteLn('  IntMatchCount  : ', IntMatchCount);
  WriteLn('  IntErrorCount  : ', IntErrorCount);
  WriteLn('  IntLabelNum    : ', IntLabelNum);
End;

{ --- TODO 04 : 10 accesseurs standards --- }

Function IsIntInitialized: Boolean;
Begin
  IsIntInitialized := IntInitialized;
End;

Function IsIntEmpty: Boolean;
Begin
  IsIntEmpty := (IntParseCount = 0);
End;

Function GetIntStateCount: Integer;
Begin
  GetIntStateCount := IntStateCount;
End;

Function GetIntParseCount: Integer;
Begin
  GetIntParseCount := IntParseCount;
End;

Function GetIntUnknownCount: Integer;
Begin
  GetIntUnknownCount := IntUnknownCount;
End;

Function GetIntProgramCount: Integer;
Begin
  GetIntProgramCount := IntProgramCount;
End;

Function GetIntKeywordCount: Integer;
Begin
  GetIntKeywordCount := IntKeywordCount;
End;

Function GetIntMatchCount: Integer;
Begin
  GetIntMatchCount := IntMatchCount;
End;

Function GetIntErrorCount: Integer;
Begin
  GetIntErrorCount := IntErrorCount;
End;

Function GetIntLabelNum: Integer;
Begin
  GetIntLabelNum := IntLabelNum;
End;

{ ============================================================
  TODO 05 - GENERATEUR DE CODE PASCAL - STRUCTURES DE BASE
  ============================================================ }

{ --- TODO 05 : Fonctions d'initialisation et gestion d'etat --- }

Procedure InitGenState;
Begin
  GenInitialized := True;
  GenStateCount := 0;
  GenProgramCount := 0;
  GenUnitCount := 0;
  GenUsesCount := 0;
  GenConstCount := 0;
  GenTypeCount := 0;
  GenVarCount := 0;
  GenBeginCount := 0;
  GenEndCount := 0;
  GenInterfaceCount := 0;
  GenImplementCount := 0;
  GenCommentCount := 0;
  GenLineCount := 0;
  GenErrorCount := 0;
  GenLabelNum := 0;
  Inc(GenStateCount);
End;

Function GenGenLabel: String;
Var
  S: String;
Begin
  Inc(GenLabelNum);
  Str(GenLabelNum, S);
  GenGenLabel := '_GEN_L_' + S;
End;

Function GenTypeName(TypeCode: Integer): String;
Begin
  Case TypeCode of
    GEN_NONE      : GenTypeName := 'NONE';
    GEN_PROGRAM   : GenTypeName := 'PROGRAM';
    GEN_UNIT      : GenTypeName := 'UNIT';
    GEN_USES      : GenTypeName := 'USES';
    GEN_CONST     : GenTypeName := 'CONST';
    GEN_TYPE      : GenTypeName := 'TYPE';
    GEN_VAR       : GenTypeName := 'VAR';
    GEN_BEGIN     : GenTypeName := 'BEGIN';
    GEN_END       : GenTypeName := 'END';
    GEN_INTERFACE : GenTypeName := 'INTERFACE';
    GEN_IMPLEMENT : GenTypeName := 'IMPLEMENTATION';
    GEN_COMMENT   : GenTypeName := 'COMMENT';
  Else
    GenTypeName := 'UNKNOWN';
  End;
End;

{ --- TODO 05 : Fonctions de generation de code --- }

Procedure InitGeneratedCode;
Begin
  GeneratedCount := 0;
End;

Procedure AddCodeLine(Line: String);
Begin
  If GeneratedCount < MAX_CODE_LINES Then Begin
    Inc(GeneratedCount);
    GeneratedCode[GeneratedCount] := Line;
    Inc(GenLineCount);
  End;
End;

Procedure GenProgramHeader(Name: String);
Begin
  AddCodeLine('Program ' + Name + ';');
  AddCodeLine('');
  Inc(GenProgramCount);
End;

Procedure GenUnitHeader(Name: String);
Begin
  AddCodeLine('Unit ' + Name + ';');
  AddCodeLine('');
  AddCodeLine('Interface');
  AddCodeLine('');
  Inc(GenUnitCount);
  Inc(GenInterfaceCount);
End;

Procedure GenUsesClause(Units: String);
Begin
  If Units <> '' Then Begin
    AddCodeLine('Uses');
    AddCodeLine('  ' + Units + ';');
    AddCodeLine('');
    Inc(GenUsesCount);
  End;
End;

Procedure GenConstSection(ConstList: String);
Begin
  If ConstList <> '' Then Begin
    AddCodeLine('Const');
    AddCodeLine('  ' + ConstList);
    AddCodeLine('');
    Inc(GenConstCount);
  End;
End;

Procedure GenTypeSection(TypeList: String);
Begin
  If TypeList <> '' Then Begin
    AddCodeLine('Type');
    AddCodeLine('  ' + TypeList);
    AddCodeLine('');
    Inc(GenTypeCount);
  End;
End;

Procedure GenVarSection(VarList: String);
Begin
  If VarList <> '' Then Begin
    AddCodeLine('Var');
    AddCodeLine('  ' + VarList);
    AddCodeLine('');
    Inc(GenVarCount);
  End;
End;

Procedure GenBeginEnd;
Begin
  AddCodeLine('Begin');
  Inc(GenBeginCount);
End;

Procedure GenEnd;
Begin
  AddCodeLine('End.');
  Inc(GenEndCount);
End;

Procedure GenEndNoPoint;
Begin
  AddCodeLine('End;');
  Inc(GenEndCount);
End;

Procedure GenComment(Comment: String);
Begin
  AddCodeLine('{ ' + Comment + ' }');
  Inc(GenCommentCount);
End;

Procedure GenImplementation;
Begin
  AddCodeLine('');
  AddCodeLine('Implementation');
  AddCodeLine('');
  Inc(GenImplementCount);
End;

{ --- TODO 05 : Procedure DumpGenState --- }

Procedure DumpGenState;
Begin
  WriteLn('=== TODO 05 - Generateur de Code Pascal ===');
  WriteLn('  GenInitialized    : ', GenInitialized);
  WriteLn('  GenStateCount     : ', GenStateCount);
  WriteLn('  GenProgramCount   : ', GenProgramCount);
  WriteLn('  GenUnitCount      : ', GenUnitCount);
  WriteLn('  GenUsesCount      : ', GenUsesCount);
  WriteLn('  GenConstCount     : ', GenConstCount);
  WriteLn('  GenTypeCount      : ', GenTypeCount);
  WriteLn('  GenVarCount       : ', GenVarCount);
  WriteLn('  GenBeginCount     : ', GenBeginCount);
  WriteLn('  GenEndCount       : ', GenEndCount);
  WriteLn('  GenInterfaceCount : ', GenInterfaceCount);
  WriteLn('  GenImplementCount : ', GenImplementCount);
  WriteLn('  GenCommentCount   : ', GenCommentCount);
  WriteLn('  GenLineCount      : ', GenLineCount);
  WriteLn('  GenErrorCount     : ', GenErrorCount);
  WriteLn('  GenLabelNum       : ', GenLabelNum);
End;

{ --- TODO 05 : 10 accesseurs standards --- }

Function IsGenInitialized: Boolean;
Begin
  IsGenInitialized := GenInitialized;
End;

Function IsGenEmpty: Boolean;
Begin
  IsGenEmpty := (GenLineCount = 0);
End;

Function GetGenStateCount: Integer;
Begin
  GetGenStateCount := GenStateCount;
End;

Function GetGenProgramCount: Integer;
Begin
  GetGenProgramCount := GenProgramCount;
End;

Function GetGenUnitCount: Integer;
Begin
  GetGenUnitCount := GenUnitCount;
End;

Function GetGenLineCount: Integer;
Begin
  GetGenLineCount := GenLineCount;
End;

Function GetGenConstCount: Integer;
Begin
  GetGenConstCount := GenConstCount;
End;

Function GetGenVarCount: Integer;
Begin
  GetGenVarCount := GenVarCount;
End;

Function GetGenErrorCount: Integer;
Begin
  GetGenErrorCount := GenErrorCount;
End;

Function GetGenLabelNum: Integer;
Begin
  GetGenLabelNum := GenLabelNum;
End;

{ ============================================================
  TODO 06 - GENERATEUR DE CODE PASCAL - TYPES ET VARIABLES
  ============================================================ }

{ --- TODO 06 : Fonctions d'initialisation et gestion d'etat --- }

Procedure InitTypState;
Begin
  TypInitialized := True;
  TypStateCount := 0;
  TypVarDeclCount := 0;
  TypConstDeclCount := 0;
  TypTypeDeclCount := 0;
  TypArrayCount := 0;
  TypRecordCount := 0;
  TypPointerCount := 0;
  TypFieldCount := 0;
  TypIntegerCount := 0;
  TypStringCount := 0;
  TypBooleanCount := 0;
  TypRealCount := 0;
  TypErrorCount := 0;
  TypLabelNum := 0;
  Inc(TypStateCount);
End;

Function GenTypLabel: String;
Var
  S: String;
Begin
  Inc(TypLabelNum);
  Str(TypLabelNum, S);
  GenTypLabel := '_TYP_L_' + S;
End;

Function TypKindName(Kind: Integer): String;
Begin
  Case Kind of
    TYP_NONE     : TypKindName := 'NONE';
    TYP_INTEGER  : TypKindName := 'Integer';
    TYP_STRING   : TypKindName := 'String';
    TYP_REAL     : TypKindName := 'Real';
    TYP_BOOLEAN  : TypKindName := 'Boolean';
    TYP_CHAR     : TypKindName := 'Char';
    TYP_BYTE     : TypKindName := 'Byte';
    TYP_WORD     : TypKindName := 'Word';
    TYP_LONGINT  : TypKindName := 'LongInt';
    TYP_ARRAY    : TypKindName := 'Array';
    TYP_RECORD   : TypKindName := 'Record';
    TYP_POINTER  : TypKindName := 'Pointer';
    TYP_FILE     : TypKindName := 'File';
  Else
    TypKindName := 'Unknown';
  End;
End;

Function TypeKindToTyp(Kind: TTypeKind): Integer;
Begin
  Case Kind of
    TK_INTEGER : TypeKindToTyp := TYP_INTEGER;
    TK_STRING  : TypeKindToTyp := TYP_STRING;
    TK_REAL    : TypeKindToTyp := TYP_REAL;
    TK_BOOLEAN : TypeKindToTyp := TYP_BOOLEAN;
    TK_CHAR    : TypeKindToTyp := TYP_CHAR;
    TK_BYTE    : TypeKindToTyp := TYP_BYTE;
    TK_WORD    : TypeKindToTyp := TYP_WORD;
    TK_LONGINT : TypeKindToTyp := TYP_LONGINT;
    TK_ARRAY   : TypeKindToTyp := TYP_ARRAY;
    TK_RECORD  : TypeKindToTyp := TYP_RECORD;
    TK_POINTER : TypeKindToTyp := TYP_POINTER;
    TK_FILE    : TypeKindToTyp := TYP_FILE;
  Else
    TypeKindToTyp := TYP_NONE;
  End;
End;

{ --- TODO 06 : Fonctions de generation de declarations --- }

Function GenVarDecl(VarName, TypeName: String): String;
Begin
  GenVarDecl := '  ' + VarName + ': ' + TypeName + ';';
  Inc(TypVarDeclCount);
End;

Function GenVarDeclInit(VarName, TypeName, InitVal: String): String;
Begin
  If InitVal <> '' Then
    GenVarDeclInit := '  ' + VarName + ': ' + TypeName + ' = ' + InitVal + ';'
  Else
    GenVarDeclInit := '  ' + VarName + ': ' + TypeName + ';';
  Inc(TypVarDeclCount);
End;

Function GenConstDecl(ConstName, Value: String): String;
Begin
  GenConstDecl := '  ' + ConstName + ' = ' + Value + ';';
  Inc(TypConstDeclCount);
End;

Function GenConstDeclTyped(ConstName, TypeName, Value: String): String;
Begin
  GenConstDeclTyped := '  ' + ConstName + ': ' + TypeName + ' = ' + Value + ';';
  Inc(TypConstDeclCount);
End;

Function GenTypeDecl(TypeName, Definition: String): String;
Begin
  GenTypeDecl := '  ' + TypeName + ' = ' + Definition + ';';
  Inc(TypTypeDeclCount);
End;

Function GenArrayType(TypeName: String; Low, High: Integer; BaseType: String): String;
Var
  LowStr, HighStr: String;
Begin
  Str(Low, LowStr);
  Str(High, HighStr);
  GenArrayType := '  ' + TypeName + ' = Array[' + LowStr + '..' + HighStr + '] of ' + BaseType + ';';
  Inc(TypArrayCount);
  Inc(TypTypeDeclCount);
End;

Function GenArrayTypeStr(TypeName, Bounds, BaseType: String): String;
Begin
  GenArrayTypeStr := '  ' + TypeName + ' = Array[' + Bounds + '] of ' + BaseType + ';';
  Inc(TypArrayCount);
  Inc(TypTypeDeclCount);
End;

Procedure GenRecordTypeBegin(TypeName: String);
Begin
  AddCodeLine('  ' + TypeName + ' = Record');
  Inc(TypRecordCount);
  Inc(TypTypeDeclCount);
End;

Procedure GenRecordField(FieldName, FieldType: String);
Begin
  AddCodeLine('    ' + FieldName + ': ' + FieldType + ';');
  Inc(TypFieldCount);
End;

Procedure GenRecordTypeEnd;
Begin
  AddCodeLine('  End;');
End;

Function GenPointerType(TypeName, BaseType: String): String;
Begin
  GenPointerType := '  ' + TypeName + ' = ^' + BaseType + ';';
  Inc(TypPointerCount);
  Inc(TypTypeDeclCount);
End;

{ --- TODO 06 : Fonctions de generation avancees --- }

Procedure GenVarSectionMulti(Vars: Array of TVarInfo; VarCount: Integer);
Var
  I: Integer;
Begin
  If VarCount > 0 Then Begin
    AddCodeLine('Var');
    For I := 0 to VarCount - 1 do Begin
      If Vars[I].InitValue <> '' Then
        AddCodeLine('  ' + Vars[I].Name + ': ' + Vars[I].TypeName + ' = ' + Vars[I].InitValue + ';')
      Else
        AddCodeLine('  ' + Vars[I].Name + ': ' + Vars[I].TypeName + ';');
      Inc(TypVarDeclCount);
    End;
    AddCodeLine('');
  End;
End;

Procedure GenConstSectionMulti(Vars: Array of TVarInfo; VarCount: Integer);
Var
  I: Integer;
Begin
  If VarCount > 0 Then Begin
    AddCodeLine('Const');
    For I := 0 to VarCount - 1 do Begin
      If Vars[I].TypeName <> '' Then
        AddCodeLine('  ' + Vars[I].Name + ': ' + Vars[I].TypeName + ' = ' + Vars[I].InitValue + ';')
      Else
        AddCodeLine('  ' + Vars[I].Name + ' = ' + Vars[I].InitValue + ';');
      Inc(TypConstDeclCount);
    End;
    AddCodeLine('');
  End;
End;

{ --- TODO 06 : Fonctions utilitaires de types --- }

Function GetTypNameForKind(Kind: TTypeKind): String;
Begin
  Case Kind of
    TK_INTEGER : GetTypNameForKind := 'Integer';
    TK_WORD    : GetTypNameForKind := 'Word';
    TK_LONGINT : GetTypNameForKind := 'LongInt';
    TK_REAL    : GetTypNameForKind := 'Real';
    TK_STRING  : GetTypNameForKind := 'String';
    TK_CHAR    : GetTypNameForKind := 'Char';
    TK_BOOLEAN : GetTypNameForKind := 'Boolean';
    TK_BYTE    : GetTypNameForKind := 'Byte';
    TK_ARRAY   : GetTypNameForKind := 'Array';
    TK_RECORD  : GetTypNameForKind := 'Record';
    TK_POINTER : GetTypNameForKind := 'Pointer';
    TK_FILE    : GetTypNameForKind := 'File';
    TK_TEXT    : GetTypNameForKind := 'Text';
    TK_ENUM    : GetTypNameForKind := 'Enum';
    TK_SET     : GetTypNameForKind := 'Set';
    TK_CUSTOM  : GetTypNameForKind := 'Custom';
  Else
    GetTypNameForKind := 'Unknown';
  End;
End;

Function ParseTypeKind(TypeName: String): TTypeKind;
Var
  UpTypeName: String;
Begin
  UpTypeName := UpCaseStr(TypeName);
  If UpTypeName = 'INTEGER' Then
    ParseTypeKind := TK_INTEGER
  Else If UpTypeName = 'WORD' Then
    ParseTypeKind := TK_WORD
  Else If UpTypeName = 'LONGINT' Then
    ParseTypeKind := TK_LONGINT
  Else If UpTypeName = 'REAL' Then
    ParseTypeKind := TK_REAL
  Else If UpTypeName = 'STRING' Then
    ParseTypeKind := TK_STRING
  Else If UpTypeName = 'CHAR' Then
    ParseTypeKind := TK_CHAR
  Else If UpTypeName = 'BOOLEAN' Then
    ParseTypeKind := TK_BOOLEAN
  Else If UpTypeName = 'BYTE' Then
    ParseTypeKind := TK_BYTE
  Else If UpTypeName = 'TEXT' Then
    ParseTypeKind := TK_TEXT
  Else If UpTypeName = 'FILE' Then
    ParseTypeKind := TK_FILE
  Else If Pos('ARRAY', UpTypeName) = 1 Then
    ParseTypeKind := TK_ARRAY
  Else If Pos('RECORD', UpTypeName) = 1 Then
    ParseTypeKind := TK_RECORD
  Else If Pos('^', TypeName) = 1 Then
    ParseTypeKind := TK_POINTER
  Else
    ParseTypeKind := TK_CUSTOM;
End;

{ --- TODO 06 : Procedure DumpTypState --- }

Procedure DumpTypState;
Begin
  WriteLn('=== TODO 06 - Types et Variables Pascal ===');
  WriteLn('  TypInitialized   : ', TypInitialized);
  WriteLn('  TypStateCount    : ', TypStateCount);
  WriteLn('  TypVarDeclCount  : ', TypVarDeclCount);
  WriteLn('  TypConstDeclCount: ', TypConstDeclCount);
  WriteLn('  TypTypeDeclCount : ', TypTypeDeclCount);
  WriteLn('  TypArrayCount    : ', TypArrayCount);
  WriteLn('  TypRecordCount   : ', TypRecordCount);
  WriteLn('  TypPointerCount  : ', TypPointerCount);
  WriteLn('  TypFieldCount    : ', TypFieldCount);
  WriteLn('  TypIntegerCount  : ', TypIntegerCount);
  WriteLn('  TypStringCount   : ', TypStringCount);
  WriteLn('  TypBooleanCount  : ', TypBooleanCount);
  WriteLn('  TypRealCount     : ', TypRealCount);
  WriteLn('  TypErrorCount    : ', TypErrorCount);
  WriteLn('  TypLabelNum      : ', TypLabelNum);
End;

{ --- TODO 06 : 10 accesseurs standards --- }

Function IsTypInitialized: Boolean;
Begin
  IsTypInitialized := TypInitialized;
End;

Function IsTypEmpty: Boolean;
Begin
  IsTypEmpty := (TypVarDeclCount = 0) And (TypConstDeclCount = 0) And (TypTypeDeclCount = 0);
End;

Function GetTypStateCount: Integer;
Begin
  GetTypStateCount := TypStateCount;
End;

Function GetTypVarDeclCount: Integer;
Begin
  GetTypVarDeclCount := TypVarDeclCount;
End;

Function GetTypConstDeclCount: Integer;
Begin
  GetTypConstDeclCount := TypConstDeclCount;
End;

Function GetTypTypeDeclCount: Integer;
Begin
  GetTypTypeDeclCount := TypTypeDeclCount;
End;

Function GetTypArrayCount: Integer;
Begin
  GetTypArrayCount := TypArrayCount;
End;

Function GetTypRecordCount: Integer;
Begin
  GetTypRecordCount := TypRecordCount;
End;

Function GetTypErrorCount: Integer;
Begin
  GetTypErrorCount := TypErrorCount;
End;

Function GetTypLabelNum: Integer;
Begin
  GetTypLabelNum := TypLabelNum;
End;

{ ============================================================
  TODO 07 - GENERATEUR DE CODE PASCAL - EXPRESSIONS
  ============================================================ }

{ --- Initialisation de l'etat du generateur d'expressions --- }

Procedure InitExpState;
Begin
  ExpInitialized := True;
  ExpStateCount := 0;
  ExpLiteralCount := 0;
  ExpIdentCount := 0;
  ExpArithCount := 0;
  ExpCompareCount := 0;
  ExpLogicalCount := 0;
  ExpUnaryCount := 0;
  ExpFunCallCount := 0;
  ExpArrayAccCount := 0;
  ExpFieldAccCount := 0;
  ExpStringCatCount := 0;
  ExpAssignCount := 0;
  ExpErrorCount := 0;
  ExpLabelNum := 0;
  Inc(ExpStateCount);
End;

{ --- Generateur d'etiquettes pour expressions --- }

Function GenExpLabel: String;
Var
  S: String;
Begin
  Inc(ExpLabelNum);
  Str(ExpLabelNum, S);
  GenExpLabel := 'EXP' + S;
End;

{ --- Nom du type d'expression --- }

Function ExpTypeName(ExpType: Integer): String;
Begin
  Case ExpType of
    EXP_NONE:        ExpTypeName := 'NONE';
    EXP_LITERAL:     ExpTypeName := 'LITERAL';
    EXP_IDENTIFIER:  ExpTypeName := 'IDENTIFIER';
    EXP_ARITHMETIC:  ExpTypeName := 'ARITHMETIC';
    EXP_COMPARE:     ExpTypeName := 'COMPARE';
    EXP_LOGICAL:     ExpTypeName := 'LOGICAL';
    EXP_UNARY:       ExpTypeName := 'UNARY';
    EXP_FUNCALL:     ExpTypeName := 'FUNCALL';
    EXP_PARENTHESIS: ExpTypeName := 'PARENTHESIS';
    EXP_ARRAY_ACCESS:ExpTypeName := 'ARRAY_ACCESS';
    EXP_FIELD_ACCESS:ExpTypeName := 'FIELD_ACCESS';
    EXP_STRING_CAT:  ExpTypeName := 'STRING_CAT';
    EXP_ASSIGNMENT:  ExpTypeName := 'ASSIGNMENT';
  Else
    ExpTypeName := 'UNKNOWN';
  End;
End;

{ --- Nom de l'operateur --- }

Function OpName(Op: Integer): String;
Begin
  Case Op of
    OP_NONE:  OpName := '';
    OP_ADD:   OpName := '+';
    OP_SUB:   OpName := '-';
    OP_MUL:   OpName := '*';
    OP_DIV:   OpName := '/';
    OP_IDIV:  OpName := ' Div ';
    OP_MOD:   OpName := ' Mod ';
    OP_EQ:    OpName := ' = ';
    OP_NE:    OpName := ' <> ';
    OP_LT:    OpName := ' < ';
    OP_LE:    OpName := ' <= ';
    OP_GT:    OpName := ' > ';
    OP_GE:    OpName := ' >= ';
    OP_AND:   OpName := ' And ';
    OP_OR:    OpName := ' Or ';
    OP_NOT:   OpName := 'Not ';
    OP_XOR:   OpName := ' Xor ';
  Else
    OpName := '?';
  End;
End;

{ --- Generation d'une expression litterale --- }

Function GenLiteral(Value: String): String;
Begin
  Inc(ExpLiteralCount);
  GenLiteral := Value;
End;

{ --- Generation d'un identificateur --- }

Function GenIdentifier(Name: String): String;
Begin
  Inc(ExpIdentCount);
  GenIdentifier := Name;
End;

{ --- Generation d'une expression arithmetique --- }

Function GenArithExpr(Op: Integer; Left, Right: String): String;
Begin
  Inc(ExpArithCount);
  GenArithExpr := Left + OpName(Op) + Right;
End;

{ --- Generation d'une expression de comparaison --- }

Function GenCompareExpr(Op: Integer; Left, Right: String): String;
Begin
  Inc(ExpCompareCount);
  GenCompareExpr := Left + OpName(Op) + Right;
End;

{ --- Generation d'une expression logique --- }

Function GenLogicalExpr(Op: Integer; Left, Right: String): String;
Begin
  Inc(ExpLogicalCount);
  If Op = OP_NOT Then
    GenLogicalExpr := OpName(Op) + Left
  Else
    GenLogicalExpr := Left + OpName(Op) + Right;
End;

{ --- Generation d'une expression unaire --- }

Function GenUnaryExpr(Op: Integer; Operand: String): String;
Begin
  Inc(ExpUnaryCount);
  Case Op of
    OP_NOT: GenUnaryExpr := 'Not ' + Operand;
    OP_SUB: GenUnaryExpr := '-' + Operand;
  Else
    GenUnaryExpr := Operand;
  End;
End;

{ --- Generation d'un appel de fonction --- }

Function GenFunctionCall(Name: String; Args: String): String;
Begin
  Inc(ExpFunCallCount);
  If Args = '' Then
    GenFunctionCall := Name
  Else
    GenFunctionCall := Name + '(' + Args + ')';
End;

{ --- Generation d'une liste d'arguments --- }

Function GenArgList(Arg1, Arg2, Arg3, Arg4: String): String;
Var
  R: String;
Begin
  R := Arg1;
  If Arg2 <> '' Then R := R + ', ' + Arg2;
  If Arg3 <> '' Then R := R + ', ' + Arg3;
  If Arg4 <> '' Then R := R + ', ' + Arg4;
  GenArgList := R;
End;

{ --- Generation d'un acces tableau --- }

Function GenArrayAccess(ArrayName, Index: String): String;
Begin
  Inc(ExpArrayAccCount);
  GenArrayAccess := ArrayName + '[' + Index + ']';
End;

{ --- Generation d'un acces multi-dimensionnel --- }

Function GenArrayAccess2D(ArrayName, Index1, Index2: String): String;
Begin
  Inc(ExpArrayAccCount);
  GenArrayAccess2D := ArrayName + '[' + Index1 + ', ' + Index2 + ']';
End;

{ --- Generation d'un acces champ --- }

Function GenFieldAccess(RecordName, FieldName: String): String;
Begin
  Inc(ExpFieldAccCount);
  GenFieldAccess := RecordName + '.' + FieldName;
End;

{ --- Generation d'une concatenation de chaines --- }

Function GenStringExpr(Part1, Part2, Part3, Part4: String): String;
Var
  R: String;
Begin
  Inc(ExpStringCatCount);
  R := Part1;
  If Part2 <> '' Then R := R + ' + ' + Part2;
  If Part3 <> '' Then R := R + ' + ' + Part3;
  If Part4 <> '' Then R := R + ' + ' + Part4;
  GenStringExpr := R;
End;

{ --- Generation d'une expression entre parentheses --- }

Function GenParenExpr(Expr: String): String;
Begin
  GenParenExpr := '(' + Expr + ')';
End;

{ --- Generation d'une affectation simple --- }

Function GenAssignment(VarName, Expr: String): String;
Begin
  Inc(ExpAssignCount);
  GenAssignment := VarName + ' := ' + Expr;
End;

{ --- Generation d'une affectation avec operateur --- }

Function GenAssignOp(VarName: String; Op: Integer; Expr: String): String;
Begin
  Inc(ExpAssignCount);
  GenAssignOp := VarName + ' := ' + VarName + OpName(Op) + Expr;
End;

{ --- Generation d'une expression complete (wrapper general) --- }

Function GenExpression(Expr: String): String;
Begin
  GenExpression := Expr;
End;

{ --- Generation d'un Inc --- }

Function GenIncExpr(VarName: String): String;
Begin
  Inc(ExpAssignCount);
  GenIncExpr := 'Inc(' + VarName + ')';
End;

{ --- Generation d'un Inc avec valeur --- }

Function GenIncByExpr(VarName, Value: String): String;
Begin
  Inc(ExpAssignCount);
  GenIncByExpr := 'Inc(' + VarName + ', ' + Value + ')';
End;

{ --- Generation d'un Dec --- }

Function GenDecExpr(VarName: String): String;
Begin
  Inc(ExpAssignCount);
  GenDecExpr := 'Dec(' + VarName + ')';
End;

{ --- Generation d'un Dec avec valeur --- }

Function GenDecByExpr(VarName, Value: String): String;
Begin
  Inc(ExpAssignCount);
  GenDecByExpr := 'Dec(' + VarName + ', ' + Value + ')';
End;

{ --- Conversion operateur texte vers constante --- }

Function ParseOperator(OpStr: String): Integer;
Var
  U: String;
Begin
  U := UpCaseStr(Trim(OpStr));
  If U = '+' Then ParseOperator := OP_ADD
  Else If U = '-' Then ParseOperator := OP_SUB
  Else If U = '*' Then ParseOperator := OP_MUL
  Else If U = '/' Then ParseOperator := OP_DIV
  Else If U = 'DIV' Then ParseOperator := OP_IDIV
  Else If U = 'MOD' Then ParseOperator := OP_MOD
  Else If U = '=' Then ParseOperator := OP_EQ
  Else If U = '<>' Then ParseOperator := OP_NE
  Else If U = '<' Then ParseOperator := OP_LT
  Else If U = '<=' Then ParseOperator := OP_LE
  Else If U = '>' Then ParseOperator := OP_GT
  Else If U = '>=' Then ParseOperator := OP_GE
  Else If U = 'AND' Then ParseOperator := OP_AND
  Else If U = 'OR' Then ParseOperator := OP_OR
  Else If U = 'NOT' Then ParseOperator := OP_NOT
  Else If U = 'XOR' Then ParseOperator := OP_XOR
  Else Begin
    Inc(ExpErrorCount);
    ParseOperator := OP_NONE;
  End;
End;

{ --- Verification si un operateur est arithmetique --- }

Function IsArithOp(Op: Integer): Boolean;
Begin
  IsArithOp := (Op >= OP_ADD) And (Op <= OP_MOD);
End;

{ --- Verification si un operateur est de comparaison --- }

Function IsCompareOp(Op: Integer): Boolean;
Begin
  IsCompareOp := (Op >= OP_EQ) And (Op <= OP_GE);
End;

{ --- Verification si un operateur est logique --- }

Function IsLogicalOp(Op: Integer): Boolean;
Begin
  IsLogicalOp := (Op >= OP_AND) And (Op <= OP_XOR);
End;

{ --- Affichage de l'etat du generateur d'expressions --- }

Procedure DumpExpState;
Begin
  WriteLn('=== TODO 07 : Expression Generator State ===');
  WriteLn('  ExpInitialized   : ', ExpInitialized);
  WriteLn('  ExpStateCount    : ', ExpStateCount);
  WriteLn('  ExpLiteralCount  : ', ExpLiteralCount);
  WriteLn('  ExpIdentCount    : ', ExpIdentCount);
  WriteLn('  ExpArithCount    : ', ExpArithCount);
  WriteLn('  ExpCompareCount  : ', ExpCompareCount);
  WriteLn('  ExpLogicalCount  : ', ExpLogicalCount);
  WriteLn('  ExpUnaryCount    : ', ExpUnaryCount);
  WriteLn('  ExpFunCallCount  : ', ExpFunCallCount);
  WriteLn('  ExpArrayAccCount : ', ExpArrayAccCount);
  WriteLn('  ExpFieldAccCount : ', ExpFieldAccCount);
  WriteLn('  ExpStringCatCount: ', ExpStringCatCount);
  WriteLn('  ExpAssignCount   : ', ExpAssignCount);
  WriteLn('  ExpErrorCount    : ', ExpErrorCount);
  WriteLn('  ExpLabelNum      : ', ExpLabelNum);
End;

{ --- TODO 07 : 10 accesseurs standards --- }

Function IsExpInitialized: Boolean;
Begin
  IsExpInitialized := ExpInitialized;
End;

Function IsExpEmpty: Boolean;
Begin
  IsExpEmpty := (ExpLiteralCount = 0) And (ExpIdentCount = 0) And
                (ExpArithCount = 0) And (ExpCompareCount = 0) And
                (ExpLogicalCount = 0);
End;

Function GetExpStateCount: Integer;
Begin
  GetExpStateCount := ExpStateCount;
End;

Function GetExpLiteralCount: Integer;
Begin
  GetExpLiteralCount := ExpLiteralCount;
End;

Function GetExpArithCount: Integer;
Begin
  GetExpArithCount := ExpArithCount;
End;

Function GetExpCompareCount: Integer;
Begin
  GetExpCompareCount := ExpCompareCount;
End;

Function GetExpLogicalCount: Integer;
Begin
  GetExpLogicalCount := ExpLogicalCount;
End;

Function GetExpFunCallCount: Integer;
Begin
  GetExpFunCallCount := ExpFunCallCount;
End;

Function GetExpErrorCount: Integer;
Begin
  GetExpErrorCount := ExpErrorCount;
End;

Function GetExpLabelNum: Integer;
Begin
  GetExpLabelNum := ExpLabelNum;
End;

{ ============================================================
  TODO 08 - GENERATEUR DE CODE PASCAL - STRUCTURES DE CONTROLE
  ============================================================ }

{ --- Initialisation de l'etat du generateur de structures --- }

Procedure InitCtlState;
Begin
  CtlInitialized  := True;
  CtlStateCount   := 0;
  CtlIfThenCount  := 0;
  CtlIfElseCount  := 0;
  CtlForToCount   := 0;
  CtlForDownCount := 0;
  CtlWhileCount   := 0;
  CtlRepeatCount  := 0;
  CtlCaseCount    := 0;
  CtlWithCount    := 0;
  CtlBreakCount   := 0;
  CtlExitCount    := 0;
  CtlErrorCount   := 0;
  CtlLabelNum     := 0;
End;

{ --- Generation d'un label unique pour les structures --- }

Function GenCtlLabel: String;
Begin
  Inc(CtlLabelNum);
  GenCtlLabel := 'CTL' + IntToStr(CtlLabelNum);
End;

{ --- Nom du type de structure de controle --- }

Function CtlTypeName(CtlType: Integer): String;
Begin
  Case CtlType of
    CTL_NONE:       CtlTypeName := 'NONE';
    CTL_IF_THEN:    CtlTypeName := 'IF_THEN';
    CTL_IF_ELSE:    CtlTypeName := 'IF_THEN_ELSE';
    CTL_FOR_TO:     CtlTypeName := 'FOR_TO';
    CTL_FOR_DOWNTO: CtlTypeName := 'FOR_DOWNTO';
    CTL_WHILE:      CtlTypeName := 'WHILE';
    CTL_REPEAT:     CtlTypeName := 'REPEAT_UNTIL';
    CTL_CASE:       CtlTypeName := 'CASE';
    CTL_WITH:       CtlTypeName := 'WITH';
    CTL_BREAK:      CtlTypeName := 'BREAK';
    CTL_CONTINUE:   CtlTypeName := 'CONTINUE';
    CTL_EXIT:       CtlTypeName := 'EXIT';
    CTL_HALT:       CtlTypeName := 'HALT';
  Else
    CtlTypeName := 'UNKNOWN';
  End;
End;

{ --- Generation IF..THEN --- }

Function GenIfThen(Cond, ThenPart: String): String;
Begin
  Inc(CtlStateCount);
  Inc(CtlIfThenCount);
  GenIfThen := 'If ' + Cond + ' Then' + #13#10 +
               '  ' + ThenPart + ';';
End;

{ --- Generation IF..THEN avec bloc BEGIN..END --- }

Function GenIfThenBlock(Cond: String; ThenLines: Array of String): String;
Var
  I: Integer;
  R: String;
Begin
  Inc(CtlStateCount);
  Inc(CtlIfThenCount);
  R := 'If ' + Cond + ' Then Begin' + #13#10;
  For I := Low(ThenLines) to High(ThenLines) do
    R := R + '  ' + ThenLines[I] + #13#10;
  R := R + 'End;';
  GenIfThenBlock := R;
End;

{ --- Generation IF..THEN..ELSE --- }

Function GenIfThenElse(Cond, ThenPart, ElsePart: String): String;
Begin
  Inc(CtlStateCount);
  Inc(CtlIfElseCount);
  GenIfThenElse := 'If ' + Cond + ' Then' + #13#10 +
                   '  ' + ThenPart + #13#10 +
                   'Else' + #13#10 +
                   '  ' + ElsePart + ';';
End;

{ --- Generation IF..THEN..ELSE avec blocs BEGIN..END --- }

Function GenIfThenElseBlock(Cond: String; ThenLines, ElseLines: Array of String): String;
Var
  I: Integer;
  R: String;
Begin
  Inc(CtlStateCount);
  Inc(CtlIfElseCount);
  R := 'If ' + Cond + ' Then Begin' + #13#10;
  For I := Low(ThenLines) to High(ThenLines) do
    R := R + '  ' + ThenLines[I] + #13#10;
  R := R + 'End' + #13#10 + 'Else Begin' + #13#10;
  For I := Low(ElseLines) to High(ElseLines) do
    R := R + '  ' + ElseLines[I] + #13#10;
  R := R + 'End;';
  GenIfThenElseBlock := R;
End;

{ --- Generation FOR..TO..DO --- }

Function GenForLoop(VarName, StartVal, EndVal, Body: String): String;
Begin
  Inc(CtlStateCount);
  Inc(CtlForToCount);
  GenForLoop := 'For ' + VarName + ' := ' + StartVal + ' To ' + EndVal + ' Do' + #13#10 +
                '  ' + Body + ';';
End;

{ --- Generation FOR..TO..DO avec bloc BEGIN..END --- }

Function GenForLoopBlock(VarName, StartVal, EndVal: String; BodyLines: Array of String): String;
Var
  I: Integer;
  R: String;
Begin
  Inc(CtlStateCount);
  Inc(CtlForToCount);
  R := 'For ' + VarName + ' := ' + StartVal + ' To ' + EndVal + ' Do Begin' + #13#10;
  For I := Low(BodyLines) to High(BodyLines) do
    R := R + '  ' + BodyLines[I] + #13#10;
  R := R + 'End;';
  GenForLoopBlock := R;
End;

{ --- Generation FOR..DOWNTO..DO --- }

Function GenForDownTo(VarName, StartVal, EndVal, Body: String): String;
Begin
  Inc(CtlStateCount);
  Inc(CtlForDownCount);
  GenForDownTo := 'For ' + VarName + ' := ' + StartVal + ' DownTo ' + EndVal + ' Do' + #13#10 +
                  '  ' + Body + ';';
End;

{ --- Generation FOR..DOWNTO..DO avec bloc BEGIN..END --- }

Function GenForDownToBlock(VarName, StartVal, EndVal: String; BodyLines: Array of String): String;
Var
  I: Integer;
  R: String;
Begin
  Inc(CtlStateCount);
  Inc(CtlForDownCount);
  R := 'For ' + VarName + ' := ' + StartVal + ' DownTo ' + EndVal + ' Do Begin' + #13#10;
  For I := Low(BodyLines) to High(BodyLines) do
    R := R + '  ' + BodyLines[I] + #13#10;
  R := R + 'End;';
  GenForDownToBlock := R;
End;

{ --- Generation WHILE..DO --- }

Function GenWhileLoop(Cond, Body: String): String;
Begin
  Inc(CtlStateCount);
  Inc(CtlWhileCount);
  GenWhileLoop := 'While ' + Cond + ' Do' + #13#10 +
                  '  ' + Body + ';';
End;

{ --- Generation WHILE..DO avec bloc BEGIN..END --- }

Function GenWhileLoopBlock(Cond: String; BodyLines: Array of String): String;
Var
  I: Integer;
  R: String;
Begin
  Inc(CtlStateCount);
  Inc(CtlWhileCount);
  R := 'While ' + Cond + ' Do Begin' + #13#10;
  For I := Low(BodyLines) to High(BodyLines) do
    R := R + '  ' + BodyLines[I] + #13#10;
  R := R + 'End;';
  GenWhileLoopBlock := R;
End;

{ --- Generation REPEAT..UNTIL --- }

Function GenRepeatUntil(Body, Cond: String): String;
Begin
  Inc(CtlStateCount);
  Inc(CtlRepeatCount);
  GenRepeatUntil := 'Repeat' + #13#10 +
                    '  ' + Body + ';' + #13#10 +
                    'Until ' + Cond + ';';
End;

{ --- Generation REPEAT..UNTIL avec plusieurs lignes --- }

Function GenRepeatUntilBlock(BodyLines: Array of String; Cond: String): String;
Var
  I: Integer;
  R: String;
Begin
  Inc(CtlStateCount);
  Inc(CtlRepeatCount);
  R := 'Repeat' + #13#10;
  For I := Low(BodyLines) to High(BodyLines) do
    R := R + '  ' + BodyLines[I] + #13#10;
  R := R + 'Until ' + Cond + ';';
  GenRepeatUntilBlock := R;
End;

{ --- Generation CASE..OF simple --- }

Function GenCaseOf(Expr: String; CaseLabels, CaseActions: Array of String): String;
Var
  I: Integer;
  R: String;
Begin
  Inc(CtlStateCount);
  Inc(CtlCaseCount);
  R := 'Case ' + Expr + ' Of' + #13#10;
  For I := Low(CaseLabels) to High(CaseLabels) do
    If I <= High(CaseActions) Then
      R := R + '  ' + CaseLabels[I] + ': ' + CaseActions[I] + ';' + #13#10;
  R := R + 'End;';
  GenCaseOf := R;
End;

{ --- Generation CASE..OF avec ELSE --- }

Function GenCaseOfElse(Expr: String; CaseLabels, CaseActions: Array of String; ElseAction: String): String;
Var
  I: Integer;
  R: String;
Begin
  Inc(CtlStateCount);
  Inc(CtlCaseCount);
  R := 'Case ' + Expr + ' Of' + #13#10;
  For I := Low(CaseLabels) to High(CaseLabels) do
    If I <= High(CaseActions) Then
      R := R + '  ' + CaseLabels[I] + ': ' + CaseActions[I] + ';' + #13#10;
  R := R + 'Else' + #13#10 + '  ' + ElseAction + ';' + #13#10 + 'End;';
  GenCaseOfElse := R;
End;

{ --- Generation WITH..DO --- }

Function GenWithDo(VarName, Body: String): String;
Begin
  Inc(CtlStateCount);
  Inc(CtlWithCount);
  GenWithDo := 'With ' + VarName + ' Do' + #13#10 +
               '  ' + Body + ';';
End;

{ --- Generation WITH..DO avec bloc BEGIN..END --- }

Function GenWithDoBlock(VarName: String; BodyLines: Array of String): String;
Var
  I: Integer;
  R: String;
Begin
  Inc(CtlStateCount);
  Inc(CtlWithCount);
  R := 'With ' + VarName + ' Do Begin' + #13#10;
  For I := Low(BodyLines) to High(BodyLines) do
    R := R + '  ' + BodyLines[I] + #13#10;
  R := R + 'End;';
  GenWithDoBlock := R;
End;

{ --- Generation WITH multiples variables --- }

Function GenWithDoMulti(VarNames: Array of String; Body: String): String;
Var
  I: Integer;
  R: String;
Begin
  Inc(CtlStateCount);
  Inc(CtlWithCount);
  R := 'With ';
  For I := Low(VarNames) to High(VarNames) do Begin
    If I > Low(VarNames) Then R := R + ', ';
    R := R + VarNames[I];
  End;
  R := R + ' Do' + #13#10 + '  ' + Body + ';';
  GenWithDoMulti := R;
End;

{ --- Generation Break --- }

Function GenBreak: String;
Begin
  Inc(CtlStateCount);
  Inc(CtlBreakCount);
  GenBreak := 'Break;';
End;

{ --- Generation Exit --- }

Function GenExit: String;
Begin
  Inc(CtlStateCount);
  Inc(CtlExitCount);
  GenExit := 'Exit;';
End;

{ --- Generation Exit avec valeur --- }

Function GenExitValue(Value: String): String;
Begin
  Inc(CtlStateCount);
  Inc(CtlExitCount);
  GenExitValue := 'Exit(' + Value + ');';
End;

{ --- Generation Halt --- }

Function GenHalt: String;
Begin
  Inc(CtlStateCount);
  GenHalt := 'Halt;';
End;

{ --- Generation Halt avec code --- }

Function GenHaltCode(Code: String): String;
Begin
  Inc(CtlStateCount);
  GenHaltCode := 'Halt(' + Code + ');';
End;

{ --- Affichage de l'etat du generateur de structures --- }

Procedure DumpCtlState;
Begin
  WriteLn('=== TODO 08 : Control Structures Generator State ===');
  WriteLn('  CtlInitialized  : ', CtlInitialized);
  WriteLn('  CtlStateCount   : ', CtlStateCount);
  WriteLn('  CtlIfThenCount  : ', CtlIfThenCount);
  WriteLn('  CtlIfElseCount  : ', CtlIfElseCount);
  WriteLn('  CtlForToCount   : ', CtlForToCount);
  WriteLn('  CtlForDownCount : ', CtlForDownCount);
  WriteLn('  CtlWhileCount   : ', CtlWhileCount);
  WriteLn('  CtlRepeatCount  : ', CtlRepeatCount);
  WriteLn('  CtlCaseCount    : ', CtlCaseCount);
  WriteLn('  CtlWithCount    : ', CtlWithCount);
  WriteLn('  CtlBreakCount   : ', CtlBreakCount);
  WriteLn('  CtlExitCount    : ', CtlExitCount);
  WriteLn('  CtlErrorCount   : ', CtlErrorCount);
  WriteLn('  CtlLabelNum     : ', CtlLabelNum);
End;

{ --- TODO 08 : 10 accesseurs standards --- }

Function IsCtlInitialized: Boolean;
Begin
  IsCtlInitialized := CtlInitialized;
End;

Function IsCtlEmpty: Boolean;
Begin
  IsCtlEmpty := (CtlIfThenCount = 0) And (CtlIfElseCount = 0) And
                (CtlForToCount = 0) And (CtlWhileCount = 0) And
                (CtlRepeatCount = 0) And (CtlCaseCount = 0);
End;

Function GetCtlStateCount: Integer;
Begin
  GetCtlStateCount := CtlStateCount;
End;

Function GetCtlIfThenCount: Integer;
Begin
  GetCtlIfThenCount := CtlIfThenCount;
End;

Function GetCtlIfElseCount: Integer;
Begin
  GetCtlIfElseCount := CtlIfElseCount;
End;

Function GetCtlForToCount: Integer;
Begin
  GetCtlForToCount := CtlForToCount;
End;

Function GetCtlWhileCount: Integer;
Begin
  GetCtlWhileCount := CtlWhileCount;
End;

Function GetCtlRepeatCount: Integer;
Begin
  GetCtlRepeatCount := CtlRepeatCount;
End;

Function GetCtlErrorCount: Integer;
Begin
  GetCtlErrorCount := CtlErrorCount;
End;

Function GetCtlLabelNum: Integer;
Begin
  GetCtlLabelNum := CtlLabelNum;
End;

{ ============================================================
  TODO 09 - GENERATEUR DE CODE PASCAL - PROCEDURES ET FONCTIONS
            TProcInfo : Name, Params, LocalVars, Body, IsFunction, ReturnType
            TParamInfo : Name, TypeName, IsVar, IsConst
            GenProcedure(Proc) : generer une procedure
            GenFunction(Func) : generer une fonction
            GenParamList(Params) : generer la liste des parametres
            GenLocalVars(Vars) : generer les variables locales
            GenProcCall(Name, Args) : generer un appel de procedure
  ============================================================ }

Procedure InitPrcState;
Begin
  PrcInitialized := True;
  PrcStateCount := 0;
  PrcProcCount := 0;
  PrcFuncCount := 0;
  PrcForwardCount := 0;
  PrcExternalCount := 0;
  PrcInlineCount := 0;
  PrcNearCount := 0;
  PrcFarCount := 0;
  PrcAsmCount := 0;
  PrcVirtualCount := 0;
  PrcCallCount := 0;
  PrcParamCount := 0;
  PrcLocalCount := 0;
  PrcErrorCount := 0;
  PrcLabelNum := 0;
End;

Function GenPrcLabel: String;
Var
  S: String;
Begin
  Inc(PrcLabelNum);
  Str(PrcLabelNum, S);
  GenPrcLabel := 'PRC' + S;
End;

Function PrcTypeName(PrcType: Integer): String;
Begin
  Case PrcType of
    PRC_NONE:      PrcTypeName := 'NONE';
    PRC_PROCEDURE: PrcTypeName := 'PROCEDURE';
    PRC_FUNCTION:  PrcTypeName := 'FUNCTION';
    PRC_FORWARD:   PrcTypeName := 'FORWARD';
    PRC_EXTERNAL:  PrcTypeName := 'EXTERNAL';
    PRC_INLINE:    PrcTypeName := 'INLINE';
    PRC_INTERRUPT: PrcTypeName := 'INTERRUPT';
    PRC_NEAR:      PrcTypeName := 'NEAR';
    PRC_FAR:       PrcTypeName := 'FAR';
    PRC_ASSEMBLER: PrcTypeName := 'ASSEMBLER';
    PRC_VIRTUAL:   PrcTypeName := 'VIRTUAL';
    PRC_OVERRIDE:  PrcTypeName := 'OVERRIDE';
    PRC_ABSTRACT:  PrcTypeName := 'ABSTRACT';
  Else
    PrcTypeName := 'UNKNOWN';
  End;
End;

{ Generer une declaration de parametre }
Function GenParamDecl(ParamName, TypeName: String; IsVar, IsConst: Boolean): String;
Var
  R: String;
Begin
  R := '';
  If IsVar Then
    R := 'Var '
  Else If IsConst Then
    R := 'Const ';
  R := R + ParamName + ': ' + TypeName;
  Inc(PrcParamCount);
  GenParamDecl := R;
End;

{ Generer la liste des parametres (chaine) }
Function GenParamListStr(Names, Types: Array of String; 
                         VarFlags, ConstFlags: Array of Boolean;
                         Count: Integer): String;
Var
  R: String;
  I: Integer;
Begin
  R := '';
  For I := 0 to Count - 1 do Begin
    If I > 0 Then
      R := R + '; ';
    R := R + GenParamDecl(Names[I], Types[I], VarFlags[I], ConstFlags[I]);
  End;
  GenParamListStr := R;
End;

{ Generer une declaration de variable locale }
Procedure GenLocalVar(VarName, TypeName: String);
Begin
  AddCodeLine('  ' + VarName + ': ' + TypeName + ';');
  Inc(PrcLocalCount);
End;

{ Generer l'entete d'une procedure }
Procedure GenProcedureHeader(ProcName, ParamList: String);
Begin
  If ParamList = '' Then
    AddCodeLine('Procedure ' + ProcName + ';')
  Else
    AddCodeLine('Procedure ' + ProcName + '(' + ParamList + ');');
  Inc(PrcProcCount);
  Inc(PrcStateCount);
End;

{ Generer l'entete d'une fonction }
Procedure GenFunctionHeader(FuncName, ParamList, ReturnType: String);
Begin
  If ParamList = '' Then
    AddCodeLine('Function ' + FuncName + ': ' + ReturnType + ';')
  Else
    AddCodeLine('Function ' + FuncName + '(' + ParamList + '): ' + ReturnType + ';');
  Inc(PrcFuncCount);
  Inc(PrcStateCount);
End;

{ Generer la section VAR locale d'une procedure/fonction }
Procedure GenLocalVarSection;
Begin
  AddCodeLine('Var');
End;

{ Generer le debut du corps d'une procedure/fonction }
Procedure GenProcBegin;
Begin
  AddCodeLine('Begin');
End;

{ Generer la fin d'une procedure/fonction }
Procedure GenProcEnd;
Begin
  AddCodeLine('End;');
  AddCodeLine('');
End;

{ Generer une procedure complete simple (sans parametres, sans vars locales) }
Procedure GenSimpleProcedure(ProcName, BodyLine: String);
Begin
  GenProcedureHeader(ProcName, '');
  GenProcBegin;
  AddCodeLine('  ' + BodyLine);
  GenProcEnd;
End;

{ Generer une fonction complete simple }
Procedure GenSimpleFunction(FuncName, ReturnType, BodyLine, ResultExpr: String);
Begin
  GenFunctionHeader(FuncName, '', ReturnType);
  GenProcBegin;
  If BodyLine <> '' Then
    AddCodeLine('  ' + BodyLine);
  AddCodeLine('  ' + FuncName + ' := ' + ResultExpr + ';');
  GenProcEnd;
End;

{ Generer une procedure avec parametres }
Procedure GenProcedureWithParams(ProcName, ParamList, BodyLine: String);
Begin
  GenProcedureHeader(ProcName, ParamList);
  GenProcBegin;
  AddCodeLine('  ' + BodyLine);
  GenProcEnd;
End;

{ Generer une fonction avec parametres }
Procedure GenFunctionWithParams(FuncName, ParamList, ReturnType, BodyLine, ResultExpr: String);
Begin
  GenFunctionHeader(FuncName, ParamList, ReturnType);
  GenProcBegin;
  If BodyLine <> '' Then
    AddCodeLine('  ' + BodyLine);
  AddCodeLine('  ' + FuncName + ' := ' + ResultExpr + ';');
  GenProcEnd;
End;

{ Generer une procedure avec variables locales }
Procedure GenProcedureWithLocals(ProcName, ParamList: String; 
                                  LocalNames, LocalTypes: Array of String;
                                  LocalCount: Integer;
                                  BodyLine: String);
Var
  I: Integer;
Begin
  GenProcedureHeader(ProcName, ParamList);
  If LocalCount > 0 Then Begin
    GenLocalVarSection;
    For I := 0 to LocalCount - 1 do
      GenLocalVar(LocalNames[I], LocalTypes[I]);
  End;
  GenProcBegin;
  AddCodeLine('  ' + BodyLine);
  GenProcEnd;
End;

{ Generer une fonction avec variables locales }
Procedure GenFunctionWithLocals(FuncName, ParamList, ReturnType: String;
                                 LocalNames, LocalTypes: Array of String;
                                 LocalCount: Integer;
                                 BodyLine, ResultExpr: String);
Var
  I: Integer;
Begin
  GenFunctionHeader(FuncName, ParamList, ReturnType);
  If LocalCount > 0 Then Begin
    GenLocalVarSection;
    For I := 0 to LocalCount - 1 do
      GenLocalVar(LocalNames[I], LocalTypes[I]);
  End;
  GenProcBegin;
  If BodyLine <> '' Then
    AddCodeLine('  ' + BodyLine);
  AddCodeLine('  ' + FuncName + ' := ' + ResultExpr + ';');
  GenProcEnd;
End;

{ Generer un appel de procedure }
Function GenProcCall(ProcName: String; Args: Array of String; ArgCount: Integer): String;
Var
  R: String;
  I: Integer;
Begin
  R := ProcName;
  If ArgCount > 0 Then Begin
    R := R + '(';
    For I := 0 to ArgCount - 1 do Begin
      If I > 0 Then
        R := R + ', ';
      R := R + Args[I];
    End;
    R := R + ')';
  End;
  Inc(PrcCallCount);
  GenProcCall := R;
End;

{ Generer un appel de fonction (retourne l'expression) }
Function GenFuncCall(FuncName: String; Args: Array of String; ArgCount: Integer): String;
Begin
  { Identique a GenProcCall pour la syntaxe }
  GenFuncCall := GenProcCall(FuncName, Args, ArgCount);
End;

{ Generer une declaration forward de procedure }
Procedure GenForwardProcedure(ProcName, ParamList: String);
Begin
  If ParamList = '' Then
    AddCodeLine('Procedure ' + ProcName + '; Forward;')
  Else
    AddCodeLine('Procedure ' + ProcName + '(' + ParamList + '); Forward;');
  Inc(PrcForwardCount);
  Inc(PrcStateCount);
End;

{ Generer une declaration forward de fonction }
Procedure GenForwardFunction(FuncName, ParamList, ReturnType: String);
Begin
  If ParamList = '' Then
    AddCodeLine('Function ' + FuncName + ': ' + ReturnType + '; Forward;')
  Else
    AddCodeLine('Function ' + FuncName + '(' + ParamList + '): ' + ReturnType + '; Forward;');
  Inc(PrcForwardCount);
  Inc(PrcStateCount);
End;

{ Generer une procedure externe }
Procedure GenExternalProcedure(ProcName, ParamList, LibName, ExtName: String);
Begin
  If ParamList = '' Then
    AddCodeLine('Procedure ' + ProcName + '; External ''' + LibName + ''' Name ''' + ExtName + ''';')
  Else
    AddCodeLine('Procedure ' + ProcName + '(' + ParamList + '); External ''' + LibName + ''' Name ''' + ExtName + ''';');
  Inc(PrcExternalCount);
  Inc(PrcStateCount);
End;

{ Generer une fonction externe }
Procedure GenExternalFunction(FuncName, ParamList, ReturnType, LibName, ExtName: String);
Begin
  If ParamList = '' Then
    AddCodeLine('Function ' + FuncName + ': ' + ReturnType + '; External ''' + LibName + ''' Name ''' + ExtName + ''';')
  Else
    AddCodeLine('Function ' + FuncName + '(' + ParamList + '): ' + ReturnType + '; External ''' + LibName + ''' Name ''' + ExtName + ''';');
  Inc(PrcExternalCount);
  Inc(PrcStateCount);
End;

{ Generer une procedure near }
Procedure GenNearProcedure(ProcName, ParamList, BodyLine: String);
Begin
  If ParamList = '' Then
    AddCodeLine('Procedure ' + ProcName + '; Near;')
  Else
    AddCodeLine('Procedure ' + ProcName + '(' + ParamList + '); Near;');
  GenProcBegin;
  AddCodeLine('  ' + BodyLine);
  GenProcEnd;
  Inc(PrcNearCount);
  Inc(PrcStateCount);
End;

{ Generer une procedure far }
Procedure GenFarProcedure(ProcName, ParamList, BodyLine: String);
Begin
  If ParamList = '' Then
    AddCodeLine('Procedure ' + ProcName + '; Far;')
  Else
    AddCodeLine('Procedure ' + ProcName + '(' + ParamList + '); Far;');
  GenProcBegin;
  AddCodeLine('  ' + BodyLine);
  GenProcEnd;
  Inc(PrcFarCount);
  Inc(PrcStateCount);
End;

{ Generer une procedure inline (avec directive) }
Procedure GenInlineProcedure(ProcName, ParamList, BodyLine: String);
Begin
  If ParamList = '' Then
    AddCodeLine('Procedure ' + ProcName + '; Inline;')
  Else
    AddCodeLine('Procedure ' + ProcName + '(' + ParamList + '); Inline;');
  GenProcBegin;
  AddCodeLine('  ' + BodyLine);
  GenProcEnd;
  Inc(PrcInlineCount);
  Inc(PrcStateCount);
End;

{ Generer une procedure assembleur }
Procedure GenAssemblerProcedure(ProcName, ParamList, AsmCode: String);
Begin
  If ParamList = '' Then
    AddCodeLine('Procedure ' + ProcName + '; Assembler;')
  Else
    AddCodeLine('Procedure ' + ProcName + '(' + ParamList + '); Assembler;');
  AddCodeLine('Asm');
  AddCodeLine('  ' + AsmCode);
  AddCodeLine('End;');
  AddCodeLine('');
  Inc(PrcAsmCount);
  Inc(PrcStateCount);
End;

{ Generer une instruction d'appel de procedure }
Procedure GenProcCallStatement(ProcName: String; Args: Array of String; ArgCount: Integer);
Var
  S: String;
Begin
  S := GenProcCall(ProcName, Args, ArgCount);
  AddCodeLine('  ' + S + ';');
End;

{ Generer une procedure recursive (exemple: factorielle) }
Procedure GenRecursiveFactorial;
Begin
  AddCodeLine('Function Factorial(N: Integer): LongInt;');
  AddCodeLine('Begin');
  AddCodeLine('  If N <= 1 Then');
  AddCodeLine('    Factorial := 1');
  AddCodeLine('  Else');
  AddCodeLine('    Factorial := N * Factorial(N - 1);');
  AddCodeLine('End;');
  AddCodeLine('');
  Inc(PrcFuncCount);
  Inc(PrcStateCount);
End;

{ Generer une procedure recursive (exemple: Fibonacci) }
Procedure GenRecursiveFibonacci;
Begin
  AddCodeLine('Function Fibonacci(N: Integer): LongInt;');
  AddCodeLine('Begin');
  AddCodeLine('  If N <= 1 Then');
  AddCodeLine('    Fibonacci := N');
  AddCodeLine('  Else');
  AddCodeLine('    Fibonacci := Fibonacci(N - 1) + Fibonacci(N - 2);');
  AddCodeLine('End;');
  AddCodeLine('');
  Inc(PrcFuncCount);
  Inc(PrcStateCount);
End;

{ Generer une procedure de tri (exemple: BubbleSort) }
Procedure GenBubbleSortProcedure;
Begin
  AddCodeLine('Procedure BubbleSort(Var Arr: Array of Integer; N: Integer);');
  AddCodeLine('Var');
  AddCodeLine('  I, J, Temp: Integer;');
  AddCodeLine('Begin');
  AddCodeLine('  For I := 0 to N - 2 do');
  AddCodeLine('    For J := 0 to N - 2 - I do');
  AddCodeLine('      If Arr[J] > Arr[J + 1] Then Begin');
  AddCodeLine('        Temp := Arr[J];');
  AddCodeLine('        Arr[J] := Arr[J + 1];');
  AddCodeLine('        Arr[J + 1] := Temp;');
  AddCodeLine('      End;');
  AddCodeLine('End;');
  AddCodeLine('');
  Inc(PrcProcCount);
  Inc(PrcStateCount);
End;

{ Generer une fonction de recherche (exemple: recherche lineaire) }
Procedure GenLinearSearchFunction;
Begin
  AddCodeLine('Function LinearSearch(Arr: Array of Integer; N, Key: Integer): Integer;');
  AddCodeLine('Var');
  AddCodeLine('  I: Integer;');
  AddCodeLine('Begin');
  AddCodeLine('  LinearSearch := -1;');
  AddCodeLine('  For I := 0 to N - 1 do');
  AddCodeLine('    If Arr[I] = Key Then Begin');
  AddCodeLine('      LinearSearch := I;');
  AddCodeLine('      Exit;');
  AddCodeLine('    End;');
  AddCodeLine('End;');
  AddCodeLine('');
  Inc(PrcFuncCount);
  Inc(PrcStateCount);
End;

{ Afficher l'etat du generateur de procedures/fonctions }
Procedure DumpPrcState;
Begin
  WriteLn('=== Etat du generateur de procedures/fonctions (TODO 09) ===');
  WriteLn('  PrcInitialized  : ', PrcInitialized);
  WriteLn('  PrcStateCount   : ', PrcStateCount);
  WriteLn('  PrcProcCount    : ', PrcProcCount);
  WriteLn('  PrcFuncCount    : ', PrcFuncCount);
  WriteLn('  PrcForwardCount : ', PrcForwardCount);
  WriteLn('  PrcExternalCount: ', PrcExternalCount);
  WriteLn('  PrcInlineCount  : ', PrcInlineCount);
  WriteLn('  PrcNearCount    : ', PrcNearCount);
  WriteLn('  PrcFarCount     : ', PrcFarCount);
  WriteLn('  PrcAsmCount     : ', PrcAsmCount);
  WriteLn('  PrcVirtualCount : ', PrcVirtualCount);
  WriteLn('  PrcCallCount    : ', PrcCallCount);
  WriteLn('  PrcParamCount   : ', PrcParamCount);
  WriteLn('  PrcLocalCount   : ', PrcLocalCount);
  WriteLn('  PrcErrorCount   : ', PrcErrorCount);
  WriteLn('  PrcLabelNum     : ', PrcLabelNum);
End;

{ --- TODO 09 : 10 accesseurs standards --- }

Function IsPrcInitialized: Boolean;
Begin
  IsPrcInitialized := PrcInitialized;
End;

Function IsPrcEmpty: Boolean;
Begin
  IsPrcEmpty := (PrcProcCount = 0) And (PrcFuncCount = 0) And
                (PrcForwardCount = 0) And (PrcExternalCount = 0);
End;

Function GetPrcStateCount: Integer;
Begin
  GetPrcStateCount := PrcStateCount;
End;

Function GetPrcProcCount: Integer;
Begin
  GetPrcProcCount := PrcProcCount;
End;

Function GetPrcFuncCount: Integer;
Begin
  GetPrcFuncCount := PrcFuncCount;
End;

Function GetPrcForwardCount: Integer;
Begin
  GetPrcForwardCount := PrcForwardCount;
End;

Function GetPrcCallCount: Integer;
Begin
  GetPrcCallCount := PrcCallCount;
End;

Function GetPrcParamCount: Integer;
Begin
  GetPrcParamCount := PrcParamCount;
End;

Function GetPrcErrorCount: Integer;
Begin
  GetPrcErrorCount := PrcErrorCount;
End;

Function GetPrcLabelNum: Integer;
Begin
  GetPrcLabelNum := PrcLabelNum;
End;

{ ============================================================
  TODO 10 - GENERATEUR DE CODE PASCAL - UNITES (UNIT)
            TUnitInfo : Name, InterfaceSection, ImplementSection, InitSection
            GenUnitInterface(Unit) : generer la section INTERFACE
            GenUnitImplementation(Unit) : generer la section IMPLEMENTATION
            GenUnitInitialization(Unit) : generer la section INITIALIZATION
            GenUnitFinalization(Unit) : generer la section FINALIZATION
            GenCompleteUnit(Unit) : generer une unite complete
  ============================================================ }

Procedure InitUntState;
Begin
  UntInitialized := True;
  UntStateCount := 0;
  UntSimpleCount := 0;
  UntWithUsesCount := 0;
  UntWithInitCount := 0;
  UntWithFinalCount := 0;
  UntCompleteCount := 0;
  UntIntfProcCount := 0;
  UntImplProcCount := 0;
  UntUsesCount := 0;
  UntConstCount := 0;
  UntTypeCount := 0;
  UntVarCount := 0;
  UntErrorCount := 0;
  UntLabelNum := 0;
End;

Function GenUntLabel: String;
Var
  S: String;
Begin
  Inc(UntLabelNum);
  Str(UntLabelNum, S);
  GenUntLabel := 'UNT' + S;
End;

Function UntTypeName(UntType: Integer): String;
Begin
  Case UntType of
    UNT_NONE:       UntTypeName := 'NONE';
    UNT_SIMPLE:     UntTypeName := 'SIMPLE';
    UNT_WITH_USES:  UntTypeName := 'WITH_USES';
    UNT_WITH_INIT:  UntTypeName := 'WITH_INIT';
    UNT_WITH_FINAL: UntTypeName := 'WITH_FINAL';
    UNT_COMPLETE:   UntTypeName := 'COMPLETE';
    UNT_LIBRARY:    UntTypeName := 'LIBRARY';
    UNT_SYSTEM:     UntTypeName := 'SYSTEM';
    UNT_CRT:        UntTypeName := 'CRT';
    UNT_DOS:        UntTypeName := 'DOS';
    UNT_GRAPH:      UntTypeName := 'GRAPH';
    UNT_STRINGS:    UntTypeName := 'STRINGS';
    UNT_PRINTER:    UntTypeName := 'PRINTER';
  Else
    UntTypeName := 'UNKNOWN';
  End;
End;

{ Note: GenUnitHeader est defini dans TODO 05 }
{ Generer le debut de la section Interface (apres GenUnitHeader) }
Procedure GenUnitInterfaceBegin;
Begin
  AddCodeLine('Interface');
  AddCodeLine('');
  Inc(UntStateCount);
End;

{ Generer une clause Uses dans Interface }
Procedure GenUnitInterfaceUses(Units: String);
Begin
  AddCodeLine('Uses');
  AddCodeLine('  ' + Units + ';');
  AddCodeLine('');
  Inc(UntUsesCount);
  Inc(UntStateCount);
End;

{ Generer une declaration de constante dans Interface }
Procedure GenUnitInterfaceConst(Name, Value: String);
Begin
  AddCodeLine('Const');
  AddCodeLine('  ' + Name + ' = ' + Value + ';');
  AddCodeLine('');
  Inc(UntConstCount);
  Inc(UntIntfProcCount);
End;

{ Generer une declaration de type dans Interface }
Procedure GenUnitInterfaceType(Name, TypeDef: String);
Begin
  AddCodeLine('Type');
  AddCodeLine('  ' + Name + ' = ' + TypeDef + ';');
  AddCodeLine('');
  Inc(UntTypeCount);
  Inc(UntIntfProcCount);
End;

{ Generer une declaration de variable dans Interface }
Procedure GenUnitInterfaceVar(Name, TypeName: String);
Begin
  AddCodeLine('Var');
  AddCodeLine('  ' + Name + ': ' + TypeName + ';');
  AddCodeLine('');
  Inc(UntVarCount);
  Inc(UntIntfProcCount);
End;

{ Generer une declaration de procedure dans Interface }
Procedure GenUnitInterfaceProc(Name, Params: String);
Begin
  If Params = '' Then
    AddCodeLine('Procedure ' + Name + ';')
  Else
    AddCodeLine('Procedure ' + Name + '(' + Params + ');');
  Inc(UntIntfProcCount);
End;

{ Generer une declaration de fonction dans Interface }
Procedure GenUnitInterfaceFunc(Name, Params, RetType: String);
Begin
  If Params = '' Then
    AddCodeLine('Function ' + Name + ': ' + RetType + ';')
  Else
    AddCodeLine('Function ' + Name + '(' + Params + '): ' + RetType + ';');
  Inc(UntIntfProcCount);
End;

{ Generer le debut de la section Implementation }
Procedure GenUnitImplementationBegin;
Begin
  AddCodeLine('');
  AddCodeLine('Implementation');
  AddCodeLine('');
  Inc(UntStateCount);
End;

{ Generer une clause Uses dans Implementation }
Procedure GenUnitImplementationUses(Units: String);
Begin
  AddCodeLine('Uses');
  AddCodeLine('  ' + Units + ';');
  AddCodeLine('');
  Inc(UntUsesCount);
  Inc(UntStateCount);
End;

{ Generer une procedure simple dans Implementation }
Procedure GenUnitImplProcSimple(Name, Body: String);
Begin
  AddCodeLine('Procedure ' + Name + ';');
  AddCodeLine('Begin');
  AddCodeLine('  ' + Body);
  AddCodeLine('End;');
  AddCodeLine('');
  Inc(UntImplProcCount);
End;

{ Generer une procedure avec parametres dans Implementation }
Procedure GenUnitImplProcWithParams(Name, Params, Body: String);
Begin
  AddCodeLine('Procedure ' + Name + '(' + Params + ');');
  AddCodeLine('Begin');
  AddCodeLine('  ' + Body);
  AddCodeLine('End;');
  AddCodeLine('');
  Inc(UntImplProcCount);
End;

{ Generer une fonction simple dans Implementation }
Procedure GenUnitImplFuncSimple(Name, RetType, Body: String);
Begin
  AddCodeLine('Function ' + Name + ': ' + RetType + ';');
  AddCodeLine('Begin');
  AddCodeLine('  ' + Body);
  AddCodeLine('End;');
  AddCodeLine('');
  Inc(UntImplProcCount);
End;

{ Generer une fonction avec parametres dans Implementation }
Procedure GenUnitImplFuncWithParams(Name, Params, RetType, Body: String);
Begin
  AddCodeLine('Function ' + Name + '(' + Params + '): ' + RetType + ';');
  AddCodeLine('Begin');
  AddCodeLine('  ' + Body);
  AddCodeLine('End;');
  AddCodeLine('');
  Inc(UntImplProcCount);
End;

{ Generer la section Initialization }
Procedure GenUnitInitialization;
Begin
  AddCodeLine('Initialization');
  Inc(UntWithInitCount);
  Inc(UntStateCount);
End;

{ Generer une ligne dans Initialization }
Procedure GenUnitInitLine(Line: String);
Begin
  AddCodeLine('  ' + Line);
End;

{ Generer la section Finalization }
Procedure GenUnitFinalization;
Begin
  AddCodeLine('');
  AddCodeLine('Finalization');
  Inc(UntWithFinalCount);
  Inc(UntStateCount);
End;

{ Generer une ligne dans Finalization }
Procedure GenUnitFinalLine(Line: String);
Begin
  AddCodeLine('  ' + Line);
End;

{ Generer la fin de l'unite }
Procedure GenUnitEnd;
Begin
  AddCodeLine('');
  AddCodeLine('End.');
  Inc(UntStateCount);
End;

{ Generer une unite simple complete }
Procedure GenSimpleUnit(UnitName: String);
Begin
  InitGeneratedCode;
  GenUnitHeader(UnitName);
  { GenUnitHeader genere deja Interface }
  AddCodeLine('{ Interface publique }');
  AddCodeLine('');
  GenUnitImplementationBegin;
  AddCodeLine('{ Implementation privee }');
  GenUnitEnd;
  Inc(UntSimpleCount);
End;

{ Generer une unite avec clause Uses }
Procedure GenUnitWithUses(UnitName, IntfUses, ImplUses: String);
Begin
  InitGeneratedCode;
  GenUnitHeader(UnitName);
  { GenUnitHeader genere deja Interface }
  If IntfUses <> '' Then
    GenUnitInterfaceUses(IntfUses);
  AddCodeLine('{ Interface publique }');
  AddCodeLine('');
  GenUnitImplementationBegin;
  If ImplUses <> '' Then
    GenUnitImplementationUses(ImplUses);
  AddCodeLine('{ Implementation privee }');
  GenUnitEnd;
  Inc(UntWithUsesCount);
End;

{ Generer une unite complete avec Init et Final }
Procedure GenCompleteUnit(UnitName: String);
Begin
  InitGeneratedCode;
  GenUnitHeader(UnitName);
  { GenUnitHeader genere deja Interface }
  AddCodeLine('{ Constantes exportees }');
  AddCodeLine('');
  AddCodeLine('{ Types exportes }');
  AddCodeLine('');
  AddCodeLine('{ Variables exportees }');
  AddCodeLine('');
  AddCodeLine('{ Procedures et fonctions exportees }');
  AddCodeLine('');
  GenUnitImplementationBegin;
  AddCodeLine('{ Variables privees }');
  AddCodeLine('');
  AddCodeLine('{ Procedures et fonctions privees }');
  AddCodeLine('');
  AddCodeLine('{ Implementation des procedures/fonctions }');
  AddCodeLine('');
  GenUnitInitialization;
  AddCodeLine('  { Code d''initialisation }');
  GenUnitFinalization;
  AddCodeLine('  { Code de finalisation }');
  GenUnitEnd;
  Inc(UntCompleteCount);
End;

{ Generer une unite de type CRT }
Procedure GenCrtStyleUnit(UnitName: String);
Begin
  InitGeneratedCode;
  GenUnitHeader(UnitName);
  { GenUnitHeader genere deja Interface }
  AddCodeLine('Const');
  AddCodeLine('  Black         = 0;');
  AddCodeLine('  Blue          = 1;');
  AddCodeLine('  Green         = 2;');
  AddCodeLine('  Cyan          = 3;');
  AddCodeLine('  Red           = 4;');
  AddCodeLine('  Magenta       = 5;');
  AddCodeLine('  Brown         = 6;');
  AddCodeLine('  LightGray     = 7;');
  AddCodeLine('  DarkGray      = 8;');
  AddCodeLine('  LightBlue     = 9;');
  AddCodeLine('  LightGreen    = 10;');
  AddCodeLine('  LightCyan     = 11;');
  AddCodeLine('  LightRed      = 12;');
  AddCodeLine('  LightMagenta  = 13;');
  AddCodeLine('  Yellow        = 14;');
  AddCodeLine('  White         = 15;');
  AddCodeLine('');
  AddCodeLine('Var');
  AddCodeLine('  TextAttr: Byte;');
  AddCodeLine('');
  AddCodeLine('Procedure ClrScr;');
  AddCodeLine('Procedure GotoXY(X, Y: Integer);');
  AddCodeLine('Procedure TextColor(Color: Byte);');
  AddCodeLine('Procedure TextBackground(Color: Byte);');
  AddCodeLine('Function WhereX: Integer;');
  AddCodeLine('Function WhereY: Integer;');
  AddCodeLine('Function KeyPressed: Boolean;');
  AddCodeLine('Function ReadKey: Char;');
  AddCodeLine('');
  GenUnitImplementationBegin;
  AddCodeLine('Procedure ClrScr;');
  AddCodeLine('Begin');
  AddCodeLine('  { Effacer l''ecran }');
  AddCodeLine('End;');
  AddCodeLine('');
  AddCodeLine('Procedure GotoXY(X, Y: Integer);');
  AddCodeLine('Begin');
  AddCodeLine('  { Positionner le curseur }');
  AddCodeLine('End;');
  AddCodeLine('');
  AddCodeLine('Procedure TextColor(Color: Byte);');
  AddCodeLine('Begin');
  AddCodeLine('  TextAttr := (TextAttr And $F0) Or Color;');
  AddCodeLine('End;');
  AddCodeLine('');
  AddCodeLine('Procedure TextBackground(Color: Byte);');
  AddCodeLine('Begin');
  AddCodeLine('  TextAttr := (TextAttr And $0F) Or (Color Shl 4);');
  AddCodeLine('End;');
  AddCodeLine('');
  AddCodeLine('Function WhereX: Integer;');
  AddCodeLine('Begin');
  AddCodeLine('  WhereX := 1; { A implementer }');
  AddCodeLine('End;');
  AddCodeLine('');
  AddCodeLine('Function WhereY: Integer;');
  AddCodeLine('Begin');
  AddCodeLine('  WhereY := 1; { A implementer }');
  AddCodeLine('End;');
  AddCodeLine('');
  AddCodeLine('Function KeyPressed: Boolean;');
  AddCodeLine('Begin');
  AddCodeLine('  KeyPressed := False; { A implementer }');
  AddCodeLine('End;');
  AddCodeLine('');
  AddCodeLine('Function ReadKey: Char;');
  AddCodeLine('Begin');
  AddCodeLine('  ReadKey := #0; { A implementer }');
  AddCodeLine('End;');
  AddCodeLine('');
  GenUnitInitialization;
  AddCodeLine('  TextAttr := LightGray;');
  GenUnitEnd;
  Inc(UntStateCount);
End;

{ Generer une unite de type utilitaire pour chaines }
Procedure GenStringUtilUnit(UnitName: String);
Begin
  InitGeneratedCode;
  GenUnitHeader(UnitName);
  { GenUnitHeader genere deja Interface }
  AddCodeLine('Function StrToUpper(S: String): String;');
  AddCodeLine('Function StrToLower(S: String): String;');
  AddCodeLine('Function TrimLeft(S: String): String;');
  AddCodeLine('Function TrimRight(S: String): String;');
  AddCodeLine('Function TrimStr(S: String): String;');
  AddCodeLine('Function StrReverse(S: String): String;');
  AddCodeLine('Function StrRepeat(S: String; N: Integer): String;');
  AddCodeLine('Function StrPadLeft(S: String; Len: Integer; C: Char): String;');
  AddCodeLine('Function StrPadRight(S: String; Len: Integer; C: Char): String;');
  AddCodeLine('');
  GenUnitImplementationBegin;
  AddCodeLine('Function StrToUpper(S: String): String;');
  AddCodeLine('Var I: Integer; R: String;');
  AddCodeLine('Begin');
  AddCodeLine('  R := '''';');
  AddCodeLine('  For I := 1 to Length(S) do R := R + UpCase(S[I]);');
  AddCodeLine('  StrToUpper := R;');
  AddCodeLine('End;');
  AddCodeLine('');
  AddCodeLine('Function StrToLower(S: String): String;');
  AddCodeLine('Var I: Integer; R: String; C: Char;');
  AddCodeLine('Begin');
  AddCodeLine('  R := '''';');
  AddCodeLine('  For I := 1 to Length(S) do Begin');
  AddCodeLine('    C := S[I];');
  AddCodeLine('    If (C >= ''A'') and (C <= ''Z'') Then C := Chr(Ord(C) + 32);');
  AddCodeLine('    R := R + C;');
  AddCodeLine('  End;');
  AddCodeLine('  StrToLower := R;');
  AddCodeLine('End;');
  AddCodeLine('');
  AddCodeLine('Function TrimLeft(S: String): String;');
  AddCodeLine('Var I: Integer;');
  AddCodeLine('Begin');
  AddCodeLine('  I := 1;');
  AddCodeLine('  While (I <= Length(S)) and (S[I] = '' '') do Inc(I);');
  AddCodeLine('  TrimLeft := Copy(S, I, Length(S) - I + 1);');
  AddCodeLine('End;');
  AddCodeLine('');
  AddCodeLine('Function TrimRight(S: String): String;');
  AddCodeLine('Var I: Integer;');
  AddCodeLine('Begin');
  AddCodeLine('  I := Length(S);');
  AddCodeLine('  While (I > 0) and (S[I] = '' '') do Dec(I);');
  AddCodeLine('  TrimRight := Copy(S, 1, I);');
  AddCodeLine('End;');
  AddCodeLine('');
  AddCodeLine('Function TrimStr(S: String): String;');
  AddCodeLine('Begin');
  AddCodeLine('  TrimStr := TrimLeft(TrimRight(S));');
  AddCodeLine('End;');
  AddCodeLine('');
  AddCodeLine('Function StrReverse(S: String): String;');
  AddCodeLine('Var I: Integer; R: String;');
  AddCodeLine('Begin');
  AddCodeLine('  R := '''';');
  AddCodeLine('  For I := Length(S) downto 1 do R := R + S[I];');
  AddCodeLine('  StrReverse := R;');
  AddCodeLine('End;');
  AddCodeLine('');
  AddCodeLine('Function StrRepeat(S: String; N: Integer): String;');
  AddCodeLine('Var I: Integer; R: String;');
  AddCodeLine('Begin');
  AddCodeLine('  R := '''';');
  AddCodeLine('  For I := 1 to N do R := R + S;');
  AddCodeLine('  StrRepeat := R;');
  AddCodeLine('End;');
  AddCodeLine('');
  AddCodeLine('Function StrPadLeft(S: String; Len: Integer; C: Char): String;');
  AddCodeLine('Begin');
  AddCodeLine('  While Length(S) < Len do S := C + S;');
  AddCodeLine('  StrPadLeft := S;');
  AddCodeLine('End;');
  AddCodeLine('');
  AddCodeLine('Function StrPadRight(S: String; Len: Integer; C: Char): String;');
  AddCodeLine('Begin');
  AddCodeLine('  While Length(S) < Len do S := S + C;');
  AddCodeLine('  StrPadRight := S;');
  AddCodeLine('End;');
  AddCodeLine('');
  GenUnitEnd;
  Inc(UntStateCount);
End;

{ Generer une unite de type mathematique }
Procedure GenMathUtilUnit(UnitName: String);
Begin
  InitGeneratedCode;
  GenUnitHeader(UnitName);
  { GenUnitHeader genere deja Interface }
  AddCodeLine('Const');
  AddCodeLine('  PI = 3.14159265358979323846;');
  AddCodeLine('  E  = 2.71828182845904523536;');
  AddCodeLine('');
  AddCodeLine('Function Max(A, B: Integer): Integer;');
  AddCodeLine('Function Min(A, B: Integer): Integer;');
  AddCodeLine('Function Abs2(X: Integer): Integer;');
  AddCodeLine('Function Sign(X: Integer): Integer;');
  AddCodeLine('Function GCD(A, B: Integer): Integer;');
  AddCodeLine('Function LCM(A, B: Integer): Integer;');
  AddCodeLine('Function Power(Base: Real; Exp: Integer): Real;');
  AddCodeLine('Function Factorial(N: Integer): LongInt;');
  AddCodeLine('Function IsPrime(N: Integer): Boolean;');
  AddCodeLine('');
  GenUnitImplementationBegin;
  AddCodeLine('Function Max(A, B: Integer): Integer;');
  AddCodeLine('Begin If A > B Then Max := A Else Max := B; End;');
  AddCodeLine('');
  AddCodeLine('Function Min(A, B: Integer): Integer;');
  AddCodeLine('Begin If A < B Then Min := A Else Min := B; End;');
  AddCodeLine('');
  AddCodeLine('Function Abs2(X: Integer): Integer;');
  AddCodeLine('Begin If X < 0 Then Abs2 := -X Else Abs2 := X; End;');
  AddCodeLine('');
  AddCodeLine('Function Sign(X: Integer): Integer;');
  AddCodeLine('Begin');
  AddCodeLine('  If X > 0 Then Sign := 1');
  AddCodeLine('  Else If X < 0 Then Sign := -1');
  AddCodeLine('  Else Sign := 0;');
  AddCodeLine('End;');
  AddCodeLine('');
  AddCodeLine('Function GCD(A, B: Integer): Integer;');
  AddCodeLine('Begin');
  AddCodeLine('  While B <> 0 do Begin');
  AddCodeLine('    A := A mod B;');
  AddCodeLine('    If A = 0 Then Begin GCD := B; Exit; End;');
  AddCodeLine('    B := B mod A;');
  AddCodeLine('  End;');
  AddCodeLine('  GCD := A;');
  AddCodeLine('End;');
  AddCodeLine('');
  AddCodeLine('Function LCM(A, B: Integer): Integer;');
  AddCodeLine('Begin');
  AddCodeLine('  LCM := (A * B) div GCD(A, B);');
  AddCodeLine('End;');
  AddCodeLine('');
  AddCodeLine('Function Power(Base: Real; Exp: Integer): Real;');
  AddCodeLine('Var I: Integer; R: Real;');
  AddCodeLine('Begin');
  AddCodeLine('  R := 1;');
  AddCodeLine('  For I := 1 to Exp do R := R * Base;');
  AddCodeLine('  Power := R;');
  AddCodeLine('End;');
  AddCodeLine('');
  AddCodeLine('Function Factorial(N: Integer): LongInt;');
  AddCodeLine('Var I: Integer; R: LongInt;');
  AddCodeLine('Begin');
  AddCodeLine('  R := 1;');
  AddCodeLine('  For I := 2 to N do R := R * I;');
  AddCodeLine('  Factorial := R;');
  AddCodeLine('End;');
  AddCodeLine('');
  AddCodeLine('Function IsPrime(N: Integer): Boolean;');
  AddCodeLine('Var I: Integer;');
  AddCodeLine('Begin');
  AddCodeLine('  If N < 2 Then Begin IsPrime := False; Exit; End;');
  AddCodeLine('  If N = 2 Then Begin IsPrime := True; Exit; End;');
  AddCodeLine('  If N mod 2 = 0 Then Begin IsPrime := False; Exit; End;');
  AddCodeLine('  I := 3;');
  AddCodeLine('  While I * I <= N do Begin');
  AddCodeLine('    If N mod I = 0 Then Begin IsPrime := False; Exit; End;');
  AddCodeLine('    Inc(I, 2);');
  AddCodeLine('  End;');
  AddCodeLine('  IsPrime := True;');
  AddCodeLine('End;');
  AddCodeLine('');
  GenUnitEnd;
  Inc(UntStateCount);
End;

{ Afficher l'etat du generateur d'unites }
Procedure DumpUntState;
Begin
  WriteLn('=== Etat du generateur d''unites (TODO 10) ===');
  WriteLn('  UntInitialized   : ', UntInitialized);
  WriteLn('  UntStateCount    : ', UntStateCount);
  WriteLn('  UntSimpleCount   : ', UntSimpleCount);
  WriteLn('  UntWithUsesCount : ', UntWithUsesCount);
  WriteLn('  UntWithInitCount : ', UntWithInitCount);
  WriteLn('  UntWithFinalCount: ', UntWithFinalCount);
  WriteLn('  UntCompleteCount : ', UntCompleteCount);
  WriteLn('  UntIntfProcCount : ', UntIntfProcCount);
  WriteLn('  UntImplProcCount : ', UntImplProcCount);
  WriteLn('  UntUsesCount     : ', UntUsesCount);
  WriteLn('  UntConstCount    : ', UntConstCount);
  WriteLn('  UntTypeCount     : ', UntTypeCount);
  WriteLn('  UntVarCount      : ', UntVarCount);
  WriteLn('  UntErrorCount    : ', UntErrorCount);
  WriteLn('  UntLabelNum      : ', UntLabelNum);
End;

{ --- TODO 10 : 10 accesseurs standards --- }

Function IsUntInitialized: Boolean;
Begin
  IsUntInitialized := UntInitialized;
End;

Function IsUntEmpty: Boolean;
Begin
  IsUntEmpty := (UntSimpleCount = 0) And (UntWithUsesCount = 0) And
                (UntCompleteCount = 0) And (UntStateCount = 0);
End;

Function GetUntStateCount: Integer;
Begin
  GetUntStateCount := UntStateCount;
End;

Function GetUntSimpleCount: Integer;
Begin
  GetUntSimpleCount := UntSimpleCount;
End;

Function GetUntWithUsesCount: Integer;
Begin
  GetUntWithUsesCount := UntWithUsesCount;
End;

Function GetUntCompleteCount: Integer;
Begin
  GetUntCompleteCount := UntCompleteCount;
End;

Function GetUntIntfProcCount: Integer;
Begin
  GetUntIntfProcCount := UntIntfProcCount;
End;

Function GetUntImplProcCount: Integer;
Begin
  GetUntImplProcCount := UntImplProcCount;
End;

Function GetUntErrorCount: Integer;
Begin
  GetUntErrorCount := UntErrorCount;
End;

Function GetUntLabelNum: Integer;
Begin
  GetUntLabelNum := UntLabelNum;
End;

{ ============================================================
  TODO 11 - BIBLIOTHEQUE DE TEMPLATES DE CODE
  ============================================================ }

{ Initialiser l'etat du gestionnaire de templates }
Procedure InitTplState;
Var
  I: Integer;
Begin
  If TplInitialized Then Exit;
  TplInitialized  := True;
  TplStateCount   := 0;
  TplProgramCount := 0;
  TplUnitCount    := 0;
  TplProcCount    := 0;
  TplFuncCount    := 0;
  TplLoopCount    := 0;
  TplCondCount    := 0;
  TplIOCount      := 0;
  TplFileCount    := 0;
  TplArrayCount   := 0;
  TplRecordCount  := 0;
  TplApplyCount   := 0;
  TplFindCount    := 0;
  TplErrorCount   := 0;
  TplLabelNum     := 0;
  TemplateCount   := 0;
  For I := 1 to MAX_TEMPLATES do Begin
    Templates[I].Name := '';
    Templates[I].Description := '';
    Templates[I].ParamCount := 0;
    Templates[I].LineCount := 0;
  End;
End;

{ Generer un label unique pour les templates }
Function GenTplLabel: String;
Var
  S: String;
Begin
  Inc(TplLabelNum);
  Str(TplLabelNum, S);
  GenTplLabel := 'TPL' + S;
End;

{ Obtenir le nom du type de template }
Function TplTypeName(Kind: Integer): String;
Begin
  Case Kind of
    TPL_NONE:      TplTypeName := 'NONE';
    TPL_PROGRAM:   TplTypeName := 'PROGRAM';
    TPL_UNIT:      TplTypeName := 'UNIT';
    TPL_PROCEDURE: TplTypeName := 'PROCEDURE';
    TPL_FUNCTION:  TplTypeName := 'FUNCTION';
    TPL_LOOP:      TplTypeName := 'LOOP';
    TPL_CONDITION: TplTypeName := 'CONDITION';
    TPL_INPUT:     TplTypeName := 'INPUT';
    TPL_OUTPUT:    TplTypeName := 'OUTPUT';
    TPL_FILE:      TplTypeName := 'FILE';
    TPL_ARRAY:     TplTypeName := 'ARRAY';
    TPL_RECORD:    TplTypeName := 'RECORD';
    TPL_MENU:      TplTypeName := 'MENU';
  Else
    TplTypeName := 'UNKNOWN';
  End;
End;

{ Ajouter une ligne de code a un template }
Procedure AddTemplateCodeLine(Var T: TTemplate; S: String);
Var
  P: Pointer;
Begin
  If T.LineCount >= MAX_CODE_LINES Then Exit;
  Inc(T.LineCount);
  GetMem(P, SizeOf(TCodeLine));
  T.CodeLines[T.LineCount] := P;
  T.CodeLines[T.LineCount]^ := S;
End;

{ Creer un template de programme simple }
Procedure CreateProgramTemplate(Name, Desc: String);
Var
  T: TTemplate;
Begin
  If TemplateCount >= MAX_TEMPLATES Then Exit;
  T.Name := Name;
  T.Description := Desc;
  T.ParamCount := 1;
  T.ParamNames[1] := 'ProgramName';
  T.LineCount := 0;
  AddTemplateCodeLine(T, 'Program {ProgramName};');
  AddTemplateCodeLine(T, '');
  AddTemplateCodeLine(T, 'Begin');
  AddTemplateCodeLine(T, '  { Code principal ici }');
  AddTemplateCodeLine(T, 'End.');
  Inc(TemplateCount);
  Templates[TemplateCount] := T;
  Inc(TplProgramCount);
End;

{ Creer un template de procedure simple }
Procedure CreateProcedureTemplate(Name, Desc: String);
Var
  T: TTemplate;
Begin
  If TemplateCount >= MAX_TEMPLATES Then Exit;
  T.Name := Name;
  T.Description := Desc;
  T.ParamCount := 1;
  T.ParamNames[1] := 'ProcName';
  T.LineCount := 0;
  AddTemplateCodeLine(T, 'Procedure {ProcName};');
  AddTemplateCodeLine(T, 'Begin');
  AddTemplateCodeLine(T, '  { Corps de la procedure }');
  AddTemplateCodeLine(T, 'End;');
  Inc(TemplateCount);
  Templates[TemplateCount] := T;
  Inc(TplProcCount);
End;

{ Creer un template de fonction simple }
Procedure CreateFunctionTemplate(Name, Desc: String);
Var
  T: TTemplate;
Begin
  If TemplateCount >= MAX_TEMPLATES Then Exit;
  T.Name := Name;
  T.Description := Desc;
  T.ParamCount := 2;
  T.ParamNames[1] := 'FuncName';
  T.ParamNames[2] := 'ReturnType';
  T.LineCount := 0;
  AddTemplateCodeLine(T, 'Function {FuncName}: {ReturnType};');
  AddTemplateCodeLine(T, 'Begin');
  AddTemplateCodeLine(T, '  { Corps de la fonction }');
  AddTemplateCodeLine(T, '  {FuncName} := { valeur de retour };');
  AddTemplateCodeLine(T, 'End;');
  Inc(TemplateCount);
  Templates[TemplateCount] := T;
  Inc(TplFuncCount);
End;

{ Creer un template de boucle FOR }
Procedure CreateForLoopTemplate(Name, Desc: String);
Var
  T: TTemplate;
Begin
  If TemplateCount >= MAX_TEMPLATES Then Exit;
  T.Name := Name;
  T.Description := Desc;
  T.ParamCount := 3;
  T.ParamNames[1] := 'VarName';
  T.ParamNames[2] := 'StartVal';
  T.ParamNames[3] := 'EndVal';
  T.LineCount := 0;
  AddTemplateCodeLine(T, 'For {VarName} := {StartVal} to {EndVal} do Begin');
  AddTemplateCodeLine(T, '  { Corps de la boucle }');
  AddTemplateCodeLine(T, 'End;');
  Inc(TemplateCount);
  Templates[TemplateCount] := T;
  Inc(TplLoopCount);
End;

{ Creer un template de boucle WHILE }
Procedure CreateWhileLoopTemplate(Name, Desc: String);
Var
  T: TTemplate;
Begin
  If TemplateCount >= MAX_TEMPLATES Then Exit;
  T.Name := Name;
  T.Description := Desc;
  T.ParamCount := 1;
  T.ParamNames[1] := 'Condition';
  T.LineCount := 0;
  AddTemplateCodeLine(T, 'While {Condition} do Begin');
  AddTemplateCodeLine(T, '  { Corps de la boucle }');
  AddTemplateCodeLine(T, 'End;');
  Inc(TemplateCount);
  Templates[TemplateCount] := T;
  Inc(TplLoopCount);
End;

{ Creer un template IF-THEN-ELSE }
Procedure CreateIfThenElseTemplate(Name, Desc: String);
Var
  T: TTemplate;
Begin
  If TemplateCount >= MAX_TEMPLATES Then Exit;
  T.Name := Name;
  T.Description := Desc;
  T.ParamCount := 1;
  T.ParamNames[1] := 'Condition';
  T.LineCount := 0;
  AddTemplateCodeLine(T, 'If {Condition} Then Begin');
  AddTemplateCodeLine(T, '  { Partie THEN }');
  AddTemplateCodeLine(T, 'End');
  AddTemplateCodeLine(T, 'Else Begin');
  AddTemplateCodeLine(T, '  { Partie ELSE }');
  AddTemplateCodeLine(T, 'End;');
  Inc(TemplateCount);
  Templates[TemplateCount] := T;
  Inc(TplCondCount);
End;

{ Creer un template de saisie utilisateur }
Procedure CreateInputTemplate(Name, Desc: String);
Var
  T: TTemplate;
Begin
  If TemplateCount >= MAX_TEMPLATES Then Exit;
  T.Name := Name;
  T.Description := Desc;
  T.ParamCount := 2;
  T.ParamNames[1] := 'Prompt';
  T.ParamNames[2] := 'VarName';
  T.LineCount := 0;
  AddTemplateCodeLine(T, 'Write({Prompt});');
  AddTemplateCodeLine(T, 'ReadLn({VarName});');
  Inc(TemplateCount);
  Templates[TemplateCount] := T;
  Inc(TplIOCount);
End;

{ Creer un template de menu }
Procedure CreateMenuTemplate(Name, Desc: String);
Var
  T: TTemplate;
Begin
  If TemplateCount >= MAX_TEMPLATES Then Exit;
  T.Name := Name;
  T.Description := Desc;
  T.ParamCount := 1;
  T.ParamNames[1] := 'MenuTitle';
  T.LineCount := 0;
  AddTemplateCodeLine(T, 'Var');
  AddTemplateCodeLine(T, '  Choix: Char;');
  AddTemplateCodeLine(T, 'Begin');
  AddTemplateCodeLine(T, '  Repeat');
  AddTemplateCodeLine(T, '    ClrScr;');
  AddTemplateCodeLine(T, '    WriteLn(''{MenuTitle}'');');
  AddTemplateCodeLine(T, '    WriteLn(''===================='');');
  AddTemplateCodeLine(T, '    WriteLn(''1. Option 1'');');
  AddTemplateCodeLine(T, '    WriteLn(''2. Option 2'');');
  AddTemplateCodeLine(T, '    WriteLn(''3. Option 3'');');
  AddTemplateCodeLine(T, '    WriteLn(''Q. Quitter'');');
  AddTemplateCodeLine(T, '    WriteLn;');
  AddTemplateCodeLine(T, '    Write(''Votre choix: '');');
  AddTemplateCodeLine(T, '    ReadLn(Choix);');
  AddTemplateCodeLine(T, '    Case UpCase(Choix) of');
  AddTemplateCodeLine(T, '      ''1'': { Action 1 };');
  AddTemplateCodeLine(T, '      ''2'': { Action 2 };');
  AddTemplateCodeLine(T, '      ''3'': { Action 3 };');
  AddTemplateCodeLine(T, '    End;');
  AddTemplateCodeLine(T, '  Until UpCase(Choix) = ''Q'';');
  AddTemplateCodeLine(T, 'End.');
  Inc(TemplateCount);
  Templates[TemplateCount] := T;
  Inc(TplIOCount);
End;

{ Creer un template de lecture de fichier }
Procedure CreateFileReadTemplate(Name, Desc: String);
Var
  T: TTemplate;
Begin
  If TemplateCount >= MAX_TEMPLATES Then Exit;
  T.Name := Name;
  T.Description := Desc;
  T.ParamCount := 1;
  T.ParamNames[1] := 'FileName';
  T.LineCount := 0;
  AddTemplateCodeLine(T, 'Var');
  AddTemplateCodeLine(T, '  F: Text;');
  AddTemplateCodeLine(T, '  Line: String;');
  AddTemplateCodeLine(T, 'Begin');
  AddTemplateCodeLine(T, '  Assign(F, {FileName});');
  AddTemplateCodeLine(T, '  {$I-}');
  AddTemplateCodeLine(T, '  Reset(F);');
  AddTemplateCodeLine(T, '  {$I+}');
  AddTemplateCodeLine(T, '  If IOResult <> 0 Then Begin');
  AddTemplateCodeLine(T, '    WriteLn(''Erreur: fichier non trouve'');');
  AddTemplateCodeLine(T, '    Exit;');
  AddTemplateCodeLine(T, '  End;');
  AddTemplateCodeLine(T, '  While Not Eof(F) do Begin');
  AddTemplateCodeLine(T, '    ReadLn(F, Line);');
  AddTemplateCodeLine(T, '    WriteLn(Line);');
  AddTemplateCodeLine(T, '  End;');
  AddTemplateCodeLine(T, '  Close(F);');
  AddTemplateCodeLine(T, 'End;');
  Inc(TemplateCount);
  Templates[TemplateCount] := T;
  Inc(TplFileCount);
End;

{ Creer un template d'ecriture de fichier }
Procedure CreateFileWriteTemplate(Name, Desc: String);
Var
  T: TTemplate;
Begin
  If TemplateCount >= MAX_TEMPLATES Then Exit;
  T.Name := Name;
  T.Description := Desc;
  T.ParamCount := 1;
  T.ParamNames[1] := 'FileName';
  T.LineCount := 0;
  AddTemplateCodeLine(T, 'Var');
  AddTemplateCodeLine(T, '  F: Text;');
  AddTemplateCodeLine(T, 'Begin');
  AddTemplateCodeLine(T, '  Assign(F, {FileName});');
  AddTemplateCodeLine(T, '  Rewrite(F);');
  AddTemplateCodeLine(T, '  WriteLn(F, ''Contenu a ecrire'');');
  AddTemplateCodeLine(T, '  Close(F);');
  AddTemplateCodeLine(T, 'End;');
  Inc(TemplateCount);
  Templates[TemplateCount] := T;
  Inc(TplFileCount);
End;

{ Creer un template de tableau }
Procedure CreateArrayTemplate(Name, Desc: String);
Var
  T: TTemplate;
Begin
  If TemplateCount >= MAX_TEMPLATES Then Exit;
  T.Name := Name;
  T.Description := Desc;
  T.ParamCount := 3;
  T.ParamNames[1] := 'ArrayName';
  T.ParamNames[2] := 'Size';
  T.ParamNames[3] := 'Type';
  T.LineCount := 0;
  AddTemplateCodeLine(T, 'Var');
  AddTemplateCodeLine(T, '  {ArrayName}: Array[1..{Size}] of {Type};');
  AddTemplateCodeLine(T, '  I: Integer;');
  AddTemplateCodeLine(T, 'Begin');
  AddTemplateCodeLine(T, '  { Initialiser le tableau }');
  AddTemplateCodeLine(T, '  For I := 1 to {Size} do');
  AddTemplateCodeLine(T, '    {ArrayName}[I] := { valeur initiale };');
  AddTemplateCodeLine(T, 'End;');
  Inc(TemplateCount);
  Templates[TemplateCount] := T;
  Inc(TplArrayCount);
End;

{ Creer un template d'enregistrement }
Procedure CreateRecordTemplate(Name, Desc: String);
Var
  T: TTemplate;
Begin
  If TemplateCount >= MAX_TEMPLATES Then Exit;
  T.Name := Name;
  T.Description := Desc;
  T.ParamCount := 1;
  T.ParamNames[1] := 'RecordName';
  T.LineCount := 0;
  AddTemplateCodeLine(T, 'Type');
  AddTemplateCodeLine(T, '  {RecordName} = Record');
  AddTemplateCodeLine(T, '    Champ1: String;');
  AddTemplateCodeLine(T, '    Champ2: Integer;');
  AddTemplateCodeLine(T, '    Champ3: Boolean;');
  AddTemplateCodeLine(T, '  End;');
  AddTemplateCodeLine(T, '');
  AddTemplateCodeLine(T, 'Var');
  AddTemplateCodeLine(T, '  MonEnreg: {RecordName};');
  Inc(TemplateCount);
  Templates[TemplateCount] := T;
  Inc(TplRecordCount);
End;

{ Creer un template de programme avec Crt }
Procedure CreateCrtProgramTemplate(Name, Desc: String);
Var
  T: TTemplate;
Begin
  If TemplateCount >= MAX_TEMPLATES Then Exit;
  T.Name := Name;
  T.Description := Desc;
  T.ParamCount := 1;
  T.ParamNames[1] := 'ProgramName';
  T.LineCount := 0;
  AddTemplateCodeLine(T, 'Program {ProgramName};');
  AddTemplateCodeLine(T, '');
  AddTemplateCodeLine(T, 'Uses Crt;');
  AddTemplateCodeLine(T, '');
  AddTemplateCodeLine(T, 'Begin');
  AddTemplateCodeLine(T, '  ClrScr;');
  AddTemplateCodeLine(T, '  TextColor(Yellow);');
  AddTemplateCodeLine(T, '  WriteLn(''Bienvenue!'');');
  AddTemplateCodeLine(T, '  TextColor(White);');
  AddTemplateCodeLine(T, '  WriteLn;');
  AddTemplateCodeLine(T, '  { Code principal ici }');
  AddTemplateCodeLine(T, '  WriteLn;');
  AddTemplateCodeLine(T, '  Write(''Appuyez sur une touche...'');');
  AddTemplateCodeLine(T, '  ReadKey;');
  AddTemplateCodeLine(T, 'End.');
  Inc(TemplateCount);
  Templates[TemplateCount] := T;
  Inc(TplProgramCount);
End;

{ Creer un template d'unite }
Procedure CreateUnitTemplate(Name, Desc: String);
Var
  T: TTemplate;
Begin
  If TemplateCount >= MAX_TEMPLATES Then Exit;
  T.Name := Name;
  T.Description := Desc;
  T.ParamCount := 1;
  T.ParamNames[1] := 'UnitName';
  T.LineCount := 0;
  AddTemplateCodeLine(T, 'Unit {UnitName};');
  AddTemplateCodeLine(T, '');
  AddTemplateCodeLine(T, 'Interface');
  AddTemplateCodeLine(T, '');
  AddTemplateCodeLine(T, '{ Declarations publiques }');
  AddTemplateCodeLine(T, '');
  AddTemplateCodeLine(T, 'Implementation');
  AddTemplateCodeLine(T, '');
  AddTemplateCodeLine(T, '{ Implementation des fonctions }');
  AddTemplateCodeLine(T, '');
  AddTemplateCodeLine(T, 'End.');
  Inc(TemplateCount);
  Templates[TemplateCount] := T;
  Inc(TplUnitCount);
End;

{ Charger les templates predefinies }
Procedure LoadBuiltinTemplates;
Begin
  If Not TplInitialized Then InitTplState;
  
  { Templates de programmes }
  CreateProgramTemplate('program_simple', 'Programme Pascal simple');
  CreateCrtProgramTemplate('program_crt', 'Programme avec unite Crt');
  
  { Templates d''unites }
  CreateUnitTemplate('unit_simple', 'Unite Pascal simple');
  
  { Templates de procedures/fonctions }
  CreateProcedureTemplate('procedure_simple', 'Procedure simple');
  CreateFunctionTemplate('function_simple', 'Fonction simple');
  
  { Templates de boucles }
  CreateForLoopTemplate('for_loop', 'Boucle FOR..TO..DO');
  CreateWhileLoopTemplate('while_loop', 'Boucle WHILE..DO');
  
  { Templates de conditions }
  CreateIfThenElseTemplate('if_then_else', 'Structure IF..THEN..ELSE');
  
  { Templates d''entrees/sorties }
  CreateInputTemplate('input_simple', 'Saisie utilisateur simple');
  CreateMenuTemplate('menu_simple', 'Menu interactif simple');
  
  { Templates de fichiers }
  CreateFileReadTemplate('file_read', 'Lecture de fichier texte');
  CreateFileWriteTemplate('file_write', 'Ecriture de fichier texte');
  
  { Templates de structures de donnees }
  CreateArrayTemplate('array_simple', 'Declaration de tableau');
  CreateRecordTemplate('record_simple', 'Declaration d''enregistrement');
  
  Inc(TplStateCount);
End;

{ Chercher un template par nom }
Function FindTemplate(Name: String): Integer;
Var
  I: Integer;
  UName: String;
Begin
  Inc(TplFindCount);
  UName := UpCaseStr(Name);
  For I := 1 to TemplateCount do Begin
    If UpCaseStr(Templates[I].Name) = UName Then Begin
      FindTemplate := I;
      Exit;
    End;
  End;
  FindTemplate := 0;
End;

{ Remplacer les parametres dans une ligne de template }
Function ReplaceTemplateParams(Line: String; Params: Array of String;
                               ParamNames: Array of String; 
                               ParamCount: Integer): String;
Var
  I: Integer;
  R, ParamTag: String;
Begin
  R := Line;
  For I := 0 to ParamCount - 1 do Begin
    ParamTag := '{' + ParamNames[I] + '}';
    While Pos(ParamTag, R) > 0 do Begin
      Delete(R, Pos(ParamTag, R), Length(ParamTag));
      Insert(Params[I], R, Pos(ParamTag, R) + 1);
    End;
  End;
  ReplaceTemplateParams := R;
End;

{ Appliquer un template avec des parametres }
Procedure ApplyTemplate(Index: Integer; Params: Array of String);
Var
  I: Integer;
  Line: String;
  T: TTemplate;
  ParamArr: Array[1..MAX_PARAMS] of String;
Begin
  If (Index < 1) or (Index > TemplateCount) Then Begin
    Inc(TplErrorCount);
    Exit;
  End;
  
  Inc(TplApplyCount);
  T := Templates[Index];
  
  { Copier les parametres dans un tableau local }
  For I := 1 to T.ParamCount do
    If I <= High(Params) + 1 Then
      ParamArr[I] := Params[I - 1]
    Else
      ParamArr[I] := '';
  
  { Generer le code avec les parametres remplaces }
  InitGeneratedCode;
  For I := 1 to T.LineCount do Begin
    If T.CodeLines[I] <> Nil Then Begin
      Line := T.CodeLines[I]^;
      { Remplacer les parametres }
      Line := ReplaceTemplateParams(Line, Params, T.ParamNames, T.ParamCount);
      AddCodeLine(Line);
    End;
  End;
End;

{ Lister les templates disponibles }
Procedure ListTemplates;
Var
  I, J: Integer;
Begin
  WriteLn('=== Templates disponibles ===');
  WriteLn;
  For I := 1 to TemplateCount do Begin
    WriteLn(I:2, '. ', Templates[I].Name);
    WriteLn('    Description: ', Templates[I].Description);
    If Templates[I].ParamCount > 0 Then Begin
      Write('    Parametres: ');
      For J := 1 to Templates[I].ParamCount do Begin
        Write(Templates[I].ParamNames[J]);
        If J < Templates[I].ParamCount Then Write(', ');
      End;
      WriteLn;
    End;
    WriteLn;
  End;
  WriteLn('Total: ', TemplateCount, ' templates');
End;

{ Obtenir le code d'un template }
Procedure GetTemplateCode(Index: Integer);
Var
  I: Integer;
  T: TTemplate;
Begin
  If (Index < 1) or (Index > TemplateCount) Then Exit;
  
  T := Templates[Index];
  WriteLn('=== Template: ', T.Name, ' ===');
  WriteLn('Description: ', T.Description);
  WriteLn;
  For I := 1 to T.LineCount do
    If T.CodeLines[I] <> Nil Then
      WriteLn(T.CodeLines[I]^);
End;

{ Afficher l'etat du gestionnaire de templates }
Procedure DumpTplState;
Begin
  WriteLn('=== Etat du gestionnaire de templates (TODO 11) ===');
  WriteLn('  TplInitialized  : ', TplInitialized);
  WriteLn('  TplStateCount   : ', TplStateCount);
  WriteLn('  TplProgramCount : ', TplProgramCount);
  WriteLn('  TplUnitCount    : ', TplUnitCount);
  WriteLn('  TplProcCount    : ', TplProcCount);
  WriteLn('  TplFuncCount    : ', TplFuncCount);
  WriteLn('  TplLoopCount    : ', TplLoopCount);
  WriteLn('  TplCondCount    : ', TplCondCount);
  WriteLn('  TplIOCount      : ', TplIOCount);
  WriteLn('  TplFileCount    : ', TplFileCount);
  WriteLn('  TplArrayCount   : ', TplArrayCount);
  WriteLn('  TplRecordCount  : ', TplRecordCount);
  WriteLn('  TplApplyCount   : ', TplApplyCount);
  WriteLn('  TplFindCount    : ', TplFindCount);
  WriteLn('  TplErrorCount   : ', TplErrorCount);
  WriteLn('  TplLabelNum     : ', TplLabelNum);
  WriteLn('  TemplateCount   : ', TemplateCount);
End;

{ --- TODO 11 : 10 accesseurs standards --- }

Function IsTplInitialized: Boolean;
Begin
  IsTplInitialized := TplInitialized;
End;

Function IsTplEmpty: Boolean;
Begin
  IsTplEmpty := (TemplateCount = 0) And (TplStateCount = 0);
End;

Function GetTplStateCount: Integer;
Begin
  GetTplStateCount := TplStateCount;
End;

Function GetTplTemplateCount: Integer;
Begin
  GetTplTemplateCount := TemplateCount;
End;

Function GetTplProgramCount: Integer;
Begin
  GetTplProgramCount := TplProgramCount;
End;

Function GetTplProcCount: Integer;
Begin
  GetTplProcCount := TplProcCount;
End;

Function GetTplFuncCount: Integer;
Begin
  GetTplFuncCount := TplFuncCount;
End;

Function GetTplApplyCount: Integer;
Begin
  GetTplApplyCount := TplApplyCount;
End;

Function GetTplErrorCount: Integer;
Begin
  GetTplErrorCount := TplErrorCount;
End;

Function GetTplLabelNum: Integer;
Begin
  GetTplLabelNum := TplLabelNum;
End;

{ ============================================================
  TODO 12 - GENERATION DE PROGRAMMES "BONJOUR"
  ============================================================ }

{ Initialiser l'etat du generateur de programmes Bonjour }
Procedure InitHloState;
Begin
  HloInitialized  := True;
  HloStateCount   := 0;
  HloWorldCount   := 0;
  HloNameCount    := 0;
  HloInteractCount:= 0;
  HloMultiLangCount:= 0;
  HloGraphicCount := 0;
  HloAnimatedCount:= 0;
  HloColoredCount := 0;
  HloSoundCount   := 0;
  HloCenteredCount:= 0;
  HloBorderedCount:= 0;
  HloTimedCount   := 0;
  HloRandomCount  := 0;
  HloErrorCount   := 0;
  HloLabelNum     := 0;
End;

{ Generer un label unique pour TODO 12 }
Function GenHloLabel: String;
Var
  S: String;
Begin
  Inc(HloLabelNum);
  Str(HloLabelNum, S);
  GenHloLabel := '_HLO_' + S;
End;

{ Retourner le nom du type Bonjour }
Function HloTypeName(T: Integer): String;
Begin
  Case T of
    HLO_NONE:        HloTypeName := 'NONE';
    HLO_WORLD:       HloTypeName := 'WORLD';
    HLO_NAME:        HloTypeName := 'NAME';
    HLO_INTERACTIVE: HloTypeName := 'INTERACTIVE';
    HLO_MULTILANG:   HloTypeName := 'MULTILANG';
    HLO_GRAPHIC:     HloTypeName := 'GRAPHIC';
    HLO_ANIMATED:    HloTypeName := 'ANIMATED';
    HLO_COLORED:     HloTypeName := 'COLORED';
    HLO_SOUND:       HloTypeName := 'SOUND';
    HLO_CENTERED:    HloTypeName := 'CENTERED';
    HLO_BORDERED:    HloTypeName := 'BORDERED';
    HLO_TIMED:       HloTypeName := 'TIMED';
    HLO_RANDOM:      HloTypeName := 'RANDOM';
  Else
    HloTypeName := 'UNKNOWN';
  End;
End;

{ Generer un programme Bonjour le monde }
Procedure GenHelloWorld;
Begin
  Inc(HloStateCount);
  Inc(HloWorldCount);
  InitGeneratedCode;
  GenProgramHeader('Bonjour');
  GenBeginEnd;
  AddCodeLine('  WriteLn(''Bonjour le monde!'');');
  GenEnd;
End;

{ Generer un programme Bonjour avec nom personnalise }
Procedure GenHelloName(Name: String);
Begin
  Inc(HloStateCount);
  Inc(HloNameCount);
  InitGeneratedCode;
  GenProgramHeader('BonjourNom');
  GenBeginEnd;
  AddCodeLine('  WriteLn(''Bonjour ' + Name + '!'');');
  GenEnd;
End;

{ Generer un programme Bonjour interactif }
Procedure GenHelloInteractive;
Begin
  Inc(HloStateCount);
  Inc(HloInteractCount);
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

{ Generer un programme Bonjour multilingue }
Procedure GenHelloMultilingual;
Begin
  Inc(HloStateCount);
  Inc(HloMultiLangCount);
  InitGeneratedCode;
  GenProgramHeader('BonjourMultilingue');
  AddCodeLine('Const');
  AddCodeLine('  LANG_FR = 1;');
  AddCodeLine('  LANG_EN = 2;');
  AddCodeLine('  LANG_ES = 3;');
  AddCodeLine('  LANG_DE = 4;');
  AddCodeLine('  LANG_IT = 5;');
  AddCodeLine('');
  AddCodeLine('Var');
  AddCodeLine('  Choix: Integer;');
  AddCodeLine('');
  GenBeginEnd;
  AddCodeLine('  WriteLn(''Choisissez une langue / Choose a language:'');');
  AddCodeLine('  WriteLn(''  1. Francais'');');
  AddCodeLine('  WriteLn(''  2. English'');');
  AddCodeLine('  WriteLn(''  3. Espanol'');');
  AddCodeLine('  WriteLn(''  4. Deutsch'');');
  AddCodeLine('  WriteLn(''  5. Italiano'');');
  AddCodeLine('  Write(''Votre choix: '');');
  AddCodeLine('  ReadLn(Choix);');
  AddCodeLine('  WriteLn;');
  AddCodeLine('  Case Choix of');
  AddCodeLine('    LANG_FR: WriteLn(''Bonjour le monde!'');');
  AddCodeLine('    LANG_EN: WriteLn(''Hello world!'');');
  AddCodeLine('    LANG_ES: WriteLn(''Hola mundo!'');');
  AddCodeLine('    LANG_DE: WriteLn(''Hallo Welt!'');');
  AddCodeLine('    LANG_IT: WriteLn(''Ciao mondo!'');');
  AddCodeLine('  Else');
  AddCodeLine('    WriteLn(''Langue non reconnue / Unknown language'');');
  AddCodeLine('  End;');
  GenEnd;
End;

{ Generer un programme Bonjour avec affichage graphique }
Procedure GenHelloGraphic;
Begin
  Inc(HloStateCount);
  Inc(HloGraphicCount);
  InitGeneratedCode;
  GenProgramHeader('BonjourGraphique');
  AddCodeLine('Uses');
  AddCodeLine('  Graph;');
  AddCodeLine('');
  AddCodeLine('Var');
  AddCodeLine('  Gd, Gm: Integer;');
  AddCodeLine('  CenterX, CenterY: Integer;');
  AddCodeLine('');
  GenBeginEnd;
  AddCodeLine('  { Initialiser le mode graphique }');
  AddCodeLine('  Gd := Detect;');
  AddCodeLine('  InitGraph(Gd, Gm, '''');');
  AddCodeLine('  If GraphResult <> grOk Then Begin');
  AddCodeLine('    WriteLn(''Erreur graphique'');');
  AddCodeLine('    Halt(1);');
  AddCodeLine('  End;');
  AddCodeLine('');
  AddCodeLine('  { Calculer le centre de l''''ecran }');
  AddCodeLine('  CenterX := GetMaxX div 2;');
  AddCodeLine('  CenterY := GetMaxY div 2;');
  AddCodeLine('');
  AddCodeLine('  { Afficher le message au centre }');
  AddCodeLine('  SetTextStyle(DefaultFont, HorizDir, 2);');
  AddCodeLine('  SetColor(Yellow);');
  AddCodeLine('  OutTextXY(CenterX - 100, CenterY, ''Bonjour le monde!'');');
  AddCodeLine('');
  AddCodeLine('  { Dessiner un cadre decoratif }');
  AddCodeLine('  SetColor(Cyan);');
  AddCodeLine('  Rectangle(CenterX - 150, CenterY - 30, CenterX + 150, CenterY + 30);');
  AddCodeLine('');
  AddCodeLine('  { Attendre une touche }');
  AddCodeLine('  ReadLn;');
  AddCodeLine('  CloseGraph;');
  GenEnd;
End;

{ Generer un programme Bonjour avec bordure decorative }
Procedure GenHelloBordered;
Begin
  Inc(HloStateCount);
  Inc(HloBorderedCount);
  InitGeneratedCode;
  GenProgramHeader('BonjourBordure');
  AddCodeLine('Const');
  AddCodeLine('  Largeur = 40;');
  AddCodeLine('');
  AddCodeLine('Var');
  AddCodeLine('  I: Integer;');
  AddCodeLine('  Message: String;');
  AddCodeLine('  Padding: Integer;');
  AddCodeLine('');
  GenBeginEnd;
  AddCodeLine('  Message := ''Bonjour le monde!'';');
  AddCodeLine('  Padding := (Largeur - Length(Message) - 4) div 2;');
  AddCodeLine('');
  AddCodeLine('  { Ligne superieure }');
  AddCodeLine('  Write(''+'');');
  AddCodeLine('  For I := 1 to Largeur - 2 do Write(''-'');');
  AddCodeLine('  WriteLn(''+'');');
  AddCodeLine('');
  AddCodeLine('  { Ligne vide }');
  AddCodeLine('  Write(''|'');');
  AddCodeLine('  For I := 1 to Largeur - 2 do Write('' '');');
  AddCodeLine('  WriteLn(''|'');');
  AddCodeLine('');
  AddCodeLine('  { Ligne avec le message }');
  AddCodeLine('  Write(''| '');');
  AddCodeLine('  For I := 1 to Padding do Write('' '');');
  AddCodeLine('  Write(Message);');
  AddCodeLine('  For I := 1 to Largeur - Padding - Length(Message) - 4 do Write('' '');');
  AddCodeLine('  WriteLn('' |'');');
  AddCodeLine('');
  AddCodeLine('  { Ligne vide }');
  AddCodeLine('  Write(''|'');');
  AddCodeLine('  For I := 1 to Largeur - 2 do Write('' '');');
  AddCodeLine('  WriteLn(''|'');');
  AddCodeLine('');
  AddCodeLine('  { Ligne inferieure }');
  AddCodeLine('  Write(''+'');');
  AddCodeLine('  For I := 1 to Largeur - 2 do Write(''-'');');
  AddCodeLine('  WriteLn(''+'');');
  GenEnd;
End;

{ Generer un programme Bonjour centre a l'ecran }
Procedure GenHelloCentered;
Begin
  Inc(HloStateCount);
  Inc(HloCenteredCount);
  InitGeneratedCode;
  GenProgramHeader('BonjourCentre');
  AddCodeLine('Uses');
  AddCodeLine('  Crt;');
  AddCodeLine('');
  AddCodeLine('Const');
  AddCodeLine('  Message = ''Bonjour le monde!'';');
  AddCodeLine('');
  AddCodeLine('Var');
  AddCodeLine('  X, Y: Integer;');
  AddCodeLine('');
  GenBeginEnd;
  AddCodeLine('  ClrScr;');
  AddCodeLine('  X := (80 - Length(Message)) div 2;');
  AddCodeLine('  Y := 12;');
  AddCodeLine('  GotoXY(X, Y);');
  AddCodeLine('  WriteLn(Message);');
  AddCodeLine('  ReadLn;');
  GenEnd;
End;

{ Generer un programme Bonjour avec date et heure }
Procedure GenHelloTimed;
Begin
  Inc(HloStateCount);
  Inc(HloTimedCount);
  InitGeneratedCode;
  GenProgramHeader('BonjourHeure');
  AddCodeLine('Uses');
  AddCodeLine('  Dos;');
  AddCodeLine('');
  AddCodeLine('Var');
  AddCodeLine('  Heure, Minute, Seconde, Sec100: Word;');
  AddCodeLine('  Salutation: String;');
  AddCodeLine('');
  GenBeginEnd;
  AddCodeLine('  GetTime(Heure, Minute, Seconde, Sec100);');
  AddCodeLine('');
  AddCodeLine('  If Heure < 12 Then');
  AddCodeLine('    Salutation := ''Bonjour''');
  AddCodeLine('  Else If Heure < 18 Then');
  AddCodeLine('    Salutation := ''Bon apres-midi''');
  AddCodeLine('  Else');
  AddCodeLine('    Salutation := ''Bonsoir'';');
  AddCodeLine('');
  AddCodeLine('  WriteLn(Salutation, '' le monde!'');');
  AddCodeLine('  WriteLn(''Il est '', Heure, '':'', Minute, '':'', Seconde);');
  GenEnd;
End;

{ Generer un programme Bonjour avec couleurs }
Procedure GenHelloColored;
Begin
  Inc(HloStateCount);
  Inc(HloColoredCount);
  InitGeneratedCode;
  GenProgramHeader('BonjourCouleur');
  AddCodeLine('Uses');
  AddCodeLine('  Crt;');
  AddCodeLine('');
  GenBeginEnd;
  AddCodeLine('  ClrScr;');
  AddCodeLine('  TextColor(Red);');
  AddCodeLine('  Write(''B'');');
  AddCodeLine('  TextColor(Yellow);');
  AddCodeLine('  Write(''o'');');
  AddCodeLine('  TextColor(Green);');
  AddCodeLine('  Write(''n'');');
  AddCodeLine('  TextColor(Cyan);');
  AddCodeLine('  Write(''j'');');
  AddCodeLine('  TextColor(Blue);');
  AddCodeLine('  Write(''o'');');
  AddCodeLine('  TextColor(Magenta);');
  AddCodeLine('  Write(''u'');');
  AddCodeLine('  TextColor(White);');
  AddCodeLine('  Write(''r'');');
  AddCodeLine('  TextColor(LightGray);');
  AddCodeLine('  WriteLn('' le monde!'');');
  AddCodeLine('  TextColor(LightGray);');
  AddCodeLine('  ReadLn;');
  GenEnd;
End;

{ Generer un programme Bonjour anime }
Procedure GenHelloAnimated;
Begin
  Inc(HloStateCount);
  Inc(HloAnimatedCount);
  InitGeneratedCode;
  GenProgramHeader('BonjourAnime');
  AddCodeLine('Uses');
  AddCodeLine('  Crt;');
  AddCodeLine('');
  AddCodeLine('Const');
  AddCodeLine('  Message = ''Bonjour le monde!'';');
  AddCodeLine('');
  AddCodeLine('Var');
  AddCodeLine('  I: Integer;');
  AddCodeLine('');
  GenBeginEnd;
  AddCodeLine('  ClrScr;');
  AddCodeLine('  For I := 1 to Length(Message) do Begin');
  AddCodeLine('    Write(Message[I]);');
  AddCodeLine('    Delay(100);');
  AddCodeLine('  End;');
  AddCodeLine('  WriteLn;');
  AddCodeLine('  ReadLn;');
  GenEnd;
End;

{ Generer un programme Bonjour aleatoire }
Procedure GenHelloRandom;
Begin
  Inc(HloStateCount);
  Inc(HloRandomCount);
  InitGeneratedCode;
  GenProgramHeader('BonjourAleatoire');
  AddCodeLine('Const');
  AddCodeLine('  NbMessages = 5;');
  AddCodeLine('');
  AddCodeLine('Var');
  AddCodeLine('  Messages: Array[1..NbMessages] of String;');
  AddCodeLine('  Choix: Integer;');
  AddCodeLine('');
  GenBeginEnd;
  AddCodeLine('  Randomize;');
  AddCodeLine('  Messages[1] := ''Bonjour le monde!'';');
  AddCodeLine('  Messages[2] := ''Salut a tous!'';');
  AddCodeLine('  Messages[3] := ''Coucou!'';');
  AddCodeLine('  Messages[4] := ''Hello tout le monde!'';');
  AddCodeLine('  Messages[5] := ''Bien le bonjour!'';');
  AddCodeLine('  Choix := Random(NbMessages) + 1;');
  AddCodeLine('  WriteLn(Messages[Choix]);');
  GenEnd;
End;

{ Afficher l'etat du generateur de programmes Bonjour }
Procedure DumpHloState;
Begin
  WriteLn('=== Etat du generateur Bonjour (TODO 12) ===');
  WriteLn('  HloInitialized    : ', HloInitialized);
  WriteLn('  HloStateCount     : ', HloStateCount);
  WriteLn('  HloWorldCount     : ', HloWorldCount);
  WriteLn('  HloNameCount      : ', HloNameCount);
  WriteLn('  HloInteractCount  : ', HloInteractCount);
  WriteLn('  HloMultiLangCount : ', HloMultiLangCount);
  WriteLn('  HloGraphicCount   : ', HloGraphicCount);
  WriteLn('  HloAnimatedCount  : ', HloAnimatedCount);
  WriteLn('  HloColoredCount   : ', HloColoredCount);
  WriteLn('  HloSoundCount     : ', HloSoundCount);
  WriteLn('  HloCenteredCount  : ', HloCenteredCount);
  WriteLn('  HloBorderedCount  : ', HloBorderedCount);
  WriteLn('  HloTimedCount     : ', HloTimedCount);
  WriteLn('  HloRandomCount    : ', HloRandomCount);
  WriteLn('  HloErrorCount     : ', HloErrorCount);
  WriteLn('  HloLabelNum       : ', HloLabelNum);
End;

{ --- TODO 12 : 10 accesseurs standards --- }

Function IsHloInitialized: Boolean;
Begin
  IsHloInitialized := HloInitialized;
End;

Function IsHloEmpty: Boolean;
Begin
  IsHloEmpty := (HloStateCount = 0);
End;

Function GetHloStateCount: Integer;
Begin
  GetHloStateCount := HloStateCount;
End;

Function GetHloWorldCount: Integer;
Begin
  GetHloWorldCount := HloWorldCount;
End;

Function GetHloNameCount: Integer;
Begin
  GetHloNameCount := HloNameCount;
End;

Function GetHloInteractCount: Integer;
Begin
  GetHloInteractCount := HloInteractCount;
End;

Function GetHloMultiLangCount: Integer;
Begin
  GetHloMultiLangCount := HloMultiLangCount;
End;

Function GetHloGraphicCount: Integer;
Begin
  GetHloGraphicCount := HloGraphicCount;
End;

Function GetHloErrorCount: Integer;
Begin
  GetHloErrorCount := HloErrorCount;
End;

Function GetHloLabelNum: Integer;
Begin
  GetHloLabelNum := HloLabelNum;
End;

{ ============================================================
  TODO 13 - GENERATION DE PROGRAMMES MATHEMATIQUES
  ============================================================ }

{ Initialiser l'etat du generateur de programmes mathematiques }
Procedure InitMthState;
Begin
  MthInitialized  := True;
  MthStateCount   := 0;
  MthPrimesCount  := 0;
  MthFiboCount    := 0;
  MthFactCount    := 0;
  MthGCDCount     := 0;
  MthLCMCount     := 0;
  MthCalcCount    := 0;
  MthPrimeChkCount := 0;
  MthPowerCount   := 0;
  MthSqrtCount    := 0;
  MthTriangleCount := 0;
  MthPerfectCount := 0;
  MthArmstrongCount := 0;
  MthErrorCount   := 0;
  MthLabelNum     := 0;
End;

{ Generer un label unique pour les programmes mathematiques }
Function GenMthLabel: String;
Var
  S: String;
Begin
  Inc(MthLabelNum);
  Str(MthLabelNum, S);
  GenMthLabel := '_MTH_' + S;
End;

{ Retourner le nom du type de programme mathematique }
Function MthTypeName(T: Integer): String;
Begin
  Case T of
    MTH_NONE:       MthTypeName := 'AUCUN';
    MTH_PRIMES:     MthTypeName := 'NOMBRES PREMIERS';
    MTH_FIBONACCI:  MthTypeName := 'FIBONACCI';
    MTH_FACTORIAL:  MthTypeName := 'FACTORIELLE';
    MTH_GCD:        MthTypeName := 'PGCD';
    MTH_LCM:        MthTypeName := 'PPCM';
    MTH_CALCULATOR: MthTypeName := 'CALCULATRICE';
    MTH_PRIMECHECK: MthTypeName := 'VERIFICATION PREMIER';
    MTH_POWER:      MthTypeName := 'PUISSANCE';
    MTH_SQRT:       MthTypeName := 'RACINE CARREE';
    MTH_TRIANGLE:   MthTypeName := 'TRIANGLE PASCAL';
    MTH_PERFECT:    MthTypeName := 'NOMBRES PARFAITS';
    MTH_ARMSTRONG:  MthTypeName := 'NOMBRES ARMSTRONG';
  Else
    MthTypeName := 'INCONNU';
  End;
End;

{ Generer un programme affichant N nombres premiers }
Procedure GenPrimeNumbers(N: Integer);
Var
  NS: String;
Begin
  Inc(MthStateCount);
  Inc(MthPrimesCount);
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

{ Generer un programme de suite de Fibonacci }
Procedure GenFibonacci(N: Integer);
Var
  NS: String;
Begin
  Inc(MthStateCount);
  Inc(MthFiboCount);
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

{ Generer un programme de calcul de factorielle }
Procedure GenFactorial;
Begin
  Inc(MthStateCount);
  Inc(MthFactCount);
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

{ Generer un programme de calcul de PGCD }
Procedure GenGCD;
Begin
  Inc(MthStateCount);
  Inc(MthGCDCount);
  InitGeneratedCode;
  GenProgramHeader('PGCD');
  AddCodeLine('Var');
  AddCodeLine('  A, B, Reste: Integer;');
  AddCodeLine('');
  GenBeginEnd;
  AddCodeLine('  WriteLn(''Calcul du PGCD (Plus Grand Commun Diviseur)'');');
  AddCodeLine('  Write(''Entrez le premier nombre: '');');
  AddCodeLine('  ReadLn(A);');
  AddCodeLine('  Write(''Entrez le deuxieme nombre: '');');
  AddCodeLine('  ReadLn(B);');
  AddCodeLine('  While B <> 0 do Begin');
  AddCodeLine('    Reste := A mod B;');
  AddCodeLine('    A := B;');
  AddCodeLine('    B := Reste;');
  AddCodeLine('  End;');
  AddCodeLine('  WriteLn(''Le PGCD est: '', A);');
  GenEnd;
End;

{ Generer une calculatrice simple }
Procedure GenCalculator;
Begin
  Inc(MthStateCount);
  Inc(MthCalcCount);
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

{ Generer un verificateur de nombre premier }
Procedure GenPrimeCheck;
Begin
  Inc(MthStateCount);
  Inc(MthPrimeChkCount);
  InitGeneratedCode;
  GenProgramHeader('VerifPremier');
  AddCodeLine('Var');
  AddCodeLine('  N, I: Integer;');
  AddCodeLine('  EstPremier: Boolean;');
  AddCodeLine('');
  GenBeginEnd;
  AddCodeLine('  WriteLn(''Verificateur de nombre premier'');');
  AddCodeLine('  Write(''Entrez un nombre: '');');
  AddCodeLine('  ReadLn(N);');
  AddCodeLine('  EstPremier := True;');
  AddCodeLine('  If N < 2 Then');
  AddCodeLine('    EstPremier := False');
  AddCodeLine('  Else');
  AddCodeLine('    For I := 2 to N - 1 do');
  AddCodeLine('      If N mod I = 0 Then');
  AddCodeLine('        EstPremier := False;');
  AddCodeLine('  If EstPremier Then');
  AddCodeLine('    WriteLn(N, '' est un nombre premier.'')');
  AddCodeLine('  Else');
  AddCodeLine('    WriteLn(N, '' n''''est pas un nombre premier.'');');
  GenEnd;
End;

{ Afficher l'etat du generateur de programmes mathematiques }
Procedure DumpMthState;
Begin
  WriteLn('=== Etat du generateur mathematique (TODO 13) ===');
  WriteLn('  MthInitialized    : ', MthInitialized);
  WriteLn('  MthStateCount     : ', MthStateCount);
  WriteLn('  MthPrimesCount    : ', MthPrimesCount);
  WriteLn('  MthFiboCount      : ', MthFiboCount);
  WriteLn('  MthFactCount      : ', MthFactCount);
  WriteLn('  MthGCDCount       : ', MthGCDCount);
  WriteLn('  MthLCMCount       : ', MthLCMCount);
  WriteLn('  MthCalcCount      : ', MthCalcCount);
  WriteLn('  MthPrimeChkCount  : ', MthPrimeChkCount);
  WriteLn('  MthPowerCount     : ', MthPowerCount);
  WriteLn('  MthSqrtCount      : ', MthSqrtCount);
  WriteLn('  MthTriangleCount  : ', MthTriangleCount);
  WriteLn('  MthPerfectCount   : ', MthPerfectCount);
  WriteLn('  MthArmstrongCount : ', MthArmstrongCount);
  WriteLn('  MthErrorCount     : ', MthErrorCount);
  WriteLn('  MthLabelNum       : ', MthLabelNum);
End;

{ --- TODO 13 : 10 accesseurs standards --- }

Function IsMthInitialized: Boolean;
Begin
  IsMthInitialized := MthInitialized;
End;

Function IsMthEmpty: Boolean;
Begin
  IsMthEmpty := (MthStateCount = 0);
End;

Function GetMthStateCount: Integer;
Begin
  GetMthStateCount := MthStateCount;
End;

Function GetMthPrimesCount: Integer;
Begin
  GetMthPrimesCount := MthPrimesCount;
End;

Function GetMthFiboCount: Integer;
Begin
  GetMthFiboCount := MthFiboCount;
End;

Function GetMthFactCount: Integer;
Begin
  GetMthFactCount := MthFactCount;
End;

Function GetMthGCDCount: Integer;
Begin
  GetMthGCDCount := MthGCDCount;
End;

Function GetMthCalcCount: Integer;
Begin
  GetMthCalcCount := MthCalcCount;
End;

Function GetMthErrorCount: Integer;
Begin
  GetMthErrorCount := MthErrorCount;
End;

Function GetMthLabelNum: Integer;
Begin
  GetMthLabelNum := MthLabelNum;
End;

{ ============================================================
  TODO 14 - GENERATION DE PROGRAMMES DATE/HEURE
  ============================================================ }

{ Initialiser l'etat du generateur de programmes date/heure }
Procedure InitDtmState;
Begin
  DtmInitialized  := True;
  DtmStateCount   := 0;
  DtmDateTimeCount := 0;
  DtmDateFmtCount := 0;
  DtmTimeCalcCount := 0;
  DtmCalendarCount := 0;
  DtmStopwatchCount := 0;
  DtmCountdownCount := 0;
  DtmDayOfWeekCount := 0;
  DtmDateDiffCount := 0;
  DtmAddDaysCount := 0;
  DtmLeapYearCount := 0;
  DtmAgeCheckCount := 0;
  DtmTimezoneCount := 0;
  DtmErrorCount   := 0;
  DtmLabelNum     := 0;
End;

{ Generer un label unique pour les programmes date/heure }
Function GenDtmLabel: String;
Var
  S: String;
Begin
  Inc(DtmLabelNum);
  Str(DtmLabelNum, S);
  GenDtmLabel := '_DTM_' + S;
End;

{ Retourner le nom du type de programme date/heure }
Function DtmTypeName(T: Integer): String;
Begin
  Case T of
    DTM_NONE:       DtmTypeName := 'AUCUN';
    DTM_DATETIME:   DtmTypeName := 'DATE ET HEURE';
    DTM_DATEFORMAT: DtmTypeName := 'FORMATAGE DATE';
    DTM_TIMECALC:   DtmTypeName := 'CALCUL DUREES';
    DTM_CALENDAR:   DtmTypeName := 'CALENDRIER';
    DTM_STOPWATCH:  DtmTypeName := 'CHRONOMETRE';
    DTM_COUNTDOWN:  DtmTypeName := 'COMPTE A REBOURS';
    DTM_DAYOFWEEK:  DtmTypeName := 'JOUR SEMAINE';
    DTM_DATEDIFF:   DtmTypeName := 'DIFFERENCE DATES';
    DTM_ADDDAYS:    DtmTypeName := 'AJOUTER JOURS';
    DTM_LEAPYEAR:   DtmTypeName := 'ANNEE BISSEXTILE';
    DTM_AGECHECK:   DtmTypeName := 'CALCUL AGE';
    DTM_TIMEZONE:   DtmTypeName := 'FUSEAUX HORAIRES';
  Else
    DtmTypeName := 'INCONNU';
  End;
End;

{ Generer un programme affichant date et heure }
Procedure GenCurrentDateTime;
Begin
  Inc(DtmStateCount);
  Inc(DtmDateTimeCount);
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

{ Generer un programme formatant une date }
Procedure GenDateFormat;
Begin
  Inc(DtmStateCount);
  Inc(DtmDateFmtCount);
  InitGeneratedCode;
  GenProgramHeader('FormatDate');
  AddCodeLine('Uses');
  AddCodeLine('  Dos;');
  AddCodeLine('');
  AddCodeLine('Var');
  AddCodeLine('  Annee, Mois, Jour, JourSem: Word;');
  AddCodeLine('  NomMois: String;');
  AddCodeLine('  NomJour: String;');
  AddCodeLine('');
  AddCodeLine('Const');
  AddCodeLine('  Mois: Array[1..12] of String[10] = (');
  AddCodeLine('    ''Janvier'', ''Fevrier'', ''Mars'', ''Avril'',');
  AddCodeLine('    ''Mai'', ''Juin'', ''Juillet'', ''Aout'',');
  AddCodeLine('    ''Septembre'', ''Octobre'', ''Novembre'', ''Decembre'');');
  AddCodeLine('  Jours: Array[0..6] of String[10] = (');
  AddCodeLine('    ''Dimanche'', ''Lundi'', ''Mardi'', ''Mercredi'',');
  AddCodeLine('    ''Jeudi'', ''Vendredi'', ''Samedi'');');
  AddCodeLine('');
  GenBeginEnd;
  AddCodeLine('  GetDate(Annee, Mois, Jour, JourSem);');
  AddCodeLine('  NomMois := Mois[Mois];');
  AddCodeLine('  NomJour := Jours[JourSem];');
  AddCodeLine('  WriteLn(''Aujourd''''hui nous sommes le '');');
  AddCodeLine('  WriteLn(NomJour, '' '', Jour, '' '', NomMois, '' '', Annee);');
  GenEnd;
End;

{ Generer un programme de calcul de durees }
Procedure GenTimeCalc;
Begin
  Inc(DtmStateCount);
  Inc(DtmTimeCalcCount);
  InitGeneratedCode;
  GenProgramHeader('CalculDurees');
  AddCodeLine('Var');
  AddCodeLine('  H1, M1, S1: Integer;');
  AddCodeLine('  H2, M2, S2: Integer;');
  AddCodeLine('  TotalSec1, TotalSec2, Diff: LongInt;');
  AddCodeLine('  HD, MD, SD: Integer;');
  AddCodeLine('');
  GenBeginEnd;
  AddCodeLine('  WriteLn(''Calcul de duree entre deux heures'');');
  AddCodeLine('  WriteLn;');
  AddCodeLine('  WriteLn(''Heure de debut:'');');
  AddCodeLine('  Write(''  Heures: ''); ReadLn(H1);');
  AddCodeLine('  Write(''  Minutes: ''); ReadLn(M1);');
  AddCodeLine('  Write(''  Secondes: ''); ReadLn(S1);');
  AddCodeLine('  WriteLn(''Heure de fin:'');');
  AddCodeLine('  Write(''  Heures: ''); ReadLn(H2);');
  AddCodeLine('  Write(''  Minutes: ''); ReadLn(M2);');
  AddCodeLine('  Write(''  Secondes: ''); ReadLn(S2);');
  AddCodeLine('  TotalSec1 := LongInt(H1) * 3600 + M1 * 60 + S1;');
  AddCodeLine('  TotalSec2 := LongInt(H2) * 3600 + M2 * 60 + S2;');
  AddCodeLine('  Diff := TotalSec2 - TotalSec1;');
  AddCodeLine('  If Diff < 0 Then Diff := Diff + 86400;');
  AddCodeLine('  HD := Diff div 3600;');
  AddCodeLine('  MD := (Diff mod 3600) div 60;');
  AddCodeLine('  SD := Diff mod 60;');
  AddCodeLine('  WriteLn;');
  AddCodeLine('  WriteLn(''Duree: '', HD, ''h '', MD, ''m '', SD, ''s'');');
  GenEnd;
End;

{ Generer un calendrier mensuel }
Procedure GenCalendar;
Begin
  Inc(DtmStateCount);
  Inc(DtmCalendarCount);
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

{ Generer un chronometre simple }
Procedure GenStopwatch;
Begin
  Inc(DtmStateCount);
  Inc(DtmStopwatchCount);
  InitGeneratedCode;
  GenProgramHeader('Chronometre');
  AddCodeLine('Uses');
  AddCodeLine('  Crt, Dos;');
  AddCodeLine('');
  AddCodeLine('Var');
  AddCodeLine('  H1, M1, S1, Sec1: Word;');
  AddCodeLine('  H2, M2, S2, Sec2: Word;');
  AddCodeLine('  Start, Stop: LongInt;');
  AddCodeLine('  Elapsed: LongInt;');
  AddCodeLine('  ElapsedMin, ElapsedSec, ElapsedMs: Integer;');
  AddCodeLine('  Key: Char;');
  AddCodeLine('');
  GenBeginEnd;
  AddCodeLine('  WriteLn(''Chronometre simple'');');
  AddCodeLine('  WriteLn(''Appuyez sur une touche pour demarrer...'');');
  AddCodeLine('  Key := ReadKey;');
  AddCodeLine('  GetTime(H1, M1, S1, Sec1);');
  AddCodeLine('  Start := LongInt(H1)*360000 + LongInt(M1)*6000 + LongInt(S1)*100 + Sec1;');
  AddCodeLine('  WriteLn(''Chronometre demarre! Appuyez sur une touche pour arreter...'');');
  AddCodeLine('  Key := ReadKey;');
  AddCodeLine('  GetTime(H2, M2, S2, Sec2);');
  AddCodeLine('  Stop := LongInt(H2)*360000 + LongInt(M2)*6000 + LongInt(S2)*100 + Sec2;');
  AddCodeLine('  Elapsed := Stop - Start;');
  AddCodeLine('  If Elapsed < 0 Then Elapsed := Elapsed + 8640000;');
  AddCodeLine('  ElapsedMin := Elapsed div 6000;');
  AddCodeLine('  ElapsedSec := (Elapsed mod 6000) div 100;');
  AddCodeLine('  ElapsedMs := (Elapsed mod 100) * 10;');
  AddCodeLine('  WriteLn;');
  AddCodeLine('  WriteLn(''Temps ecoule: '', ElapsedMin, ''m '', ElapsedSec, ''s '', ElapsedMs, ''ms'');');
  GenEnd;
End;

{ Generer un compte a rebours }
Procedure GenCountdown;
Begin
  Inc(DtmStateCount);
  Inc(DtmCountdownCount);
  InitGeneratedCode;
  GenProgramHeader('CompteARebours');
  AddCodeLine('Uses');
  AddCodeLine('  Crt, Dos;');
  AddCodeLine('');
  AddCodeLine('Var');
  AddCodeLine('  Secondes: Integer;');
  AddCodeLine('  I: Integer;');
  AddCodeLine('  H, M, S, S100: Word;');
  AddCodeLine('  LastSec: Word;');
  AddCodeLine('');
  GenBeginEnd;
  AddCodeLine('  ClrScr;');
  AddCodeLine('  WriteLn(''Compte a rebours'');');
  AddCodeLine('  Write(''Entrez le nombre de secondes: '');');
  AddCodeLine('  ReadLn(Secondes);');
  AddCodeLine('  WriteLn;');
  AddCodeLine('  For I := Secondes downto 0 do Begin');
  AddCodeLine('    GotoXY(1, 4);');
  AddCodeLine('    WriteLn(''Temps restant: '', I, '' secondes   '');');
  AddCodeLine('    GetTime(H, M, S, S100);');
  AddCodeLine('    LastSec := S;');
  AddCodeLine('    Repeat');
  AddCodeLine('      GetTime(H, M, S, S100);');
  AddCodeLine('    Until S <> LastSec;');
  AddCodeLine('  End;');
  AddCodeLine('  WriteLn;');
  AddCodeLine('  WriteLn(''TEMPS ECOULE!'');');
  AddCodeLine('  Write(#7);');
  GenEnd;
End;

{ Afficher l'etat du generateur de programmes date/heure }
Procedure DumpDtmState;
Begin
  WriteLn('=== Etat du generateur date/heure (TODO 14) ===');
  WriteLn('  DtmInitialized    : ', DtmInitialized);
  WriteLn('  DtmStateCount     : ', DtmStateCount);
  WriteLn('  DtmDateTimeCount  : ', DtmDateTimeCount);
  WriteLn('  DtmDateFmtCount   : ', DtmDateFmtCount);
  WriteLn('  DtmTimeCalcCount  : ', DtmTimeCalcCount);
  WriteLn('  DtmCalendarCount  : ', DtmCalendarCount);
  WriteLn('  DtmStopwatchCount : ', DtmStopwatchCount);
  WriteLn('  DtmCountdownCount : ', DtmCountdownCount);
  WriteLn('  DtmDayOfWeekCount : ', DtmDayOfWeekCount);
  WriteLn('  DtmDateDiffCount  : ', DtmDateDiffCount);
  WriteLn('  DtmAddDaysCount   : ', DtmAddDaysCount);
  WriteLn('  DtmLeapYearCount  : ', DtmLeapYearCount);
  WriteLn('  DtmAgeCheckCount  : ', DtmAgeCheckCount);
  WriteLn('  DtmTimezoneCount  : ', DtmTimezoneCount);
  WriteLn('  DtmErrorCount     : ', DtmErrorCount);
  WriteLn('  DtmLabelNum       : ', DtmLabelNum);
End;

{ --- TODO 14 : 10 accesseurs standards --- }

Function IsDtmInitialized: Boolean;
Begin
  IsDtmInitialized := DtmInitialized;
End;

Function IsDtmEmpty: Boolean;
Begin
  IsDtmEmpty := (DtmStateCount = 0);
End;

Function GetDtmStateCount: Integer;
Begin
  GetDtmStateCount := DtmStateCount;
End;

Function GetDtmDateTimeCount: Integer;
Begin
  GetDtmDateTimeCount := DtmDateTimeCount;
End;

Function GetDtmCalendarCount: Integer;
Begin
  GetDtmCalendarCount := DtmCalendarCount;
End;

Function GetDtmStopwatchCount: Integer;
Begin
  GetDtmStopwatchCount := DtmStopwatchCount;
End;

Function GetDtmCountdownCount: Integer;
Begin
  GetDtmCountdownCount := DtmCountdownCount;
End;

Function GetDtmTimeCalcCount: Integer;
Begin
  GetDtmTimeCalcCount := DtmTimeCalcCount;
End;

Function GetDtmErrorCount: Integer;
Begin
  GetDtmErrorCount := DtmErrorCount;
End;

Function GetDtmLabelNum: Integer;
Begin
  GetDtmLabelNum := DtmLabelNum;
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

  { Initialiser l'etat de l'analyseur de requetes (TODO 04) }
  IntInitialized := False;
  InitIntState;

  { Initialiser l'etat du generateur de code (TODO 05) }
  GenInitialized := False;
  InitGenState;

  { Initialiser l'etat du generateur de types (TODO 06) }
  TypInitialized := False;
  InitTypState;

  { Initialiser l'etat du generateur d'expressions (TODO 07) }
  ExpInitialized := False;
  InitExpState;

  { Initialiser l'etat du generateur de structures de controle (TODO 08) }
  CtlInitialized := False;
  InitCtlState;

  { Initialiser l'etat du generateur de procedures/fonctions (TODO 09) }
  PrcInitialized := False;
  InitPrcState;

  { Initialiser l'etat du generateur d'unites (TODO 10) }
  UntInitialized := False;
  InitUntState;

  { Initialiser l'etat du gestionnaire de templates (TODO 11) }
  TplInitialized := False;
  InitTplState;
  LoadBuiltinTemplates;

  { Initialiser l'etat du generateur Bonjour (TODO 12) }
  HloInitialized := False;
  InitHloState;

  { Initialiser l'etat du generateur mathematique (TODO 13) }
  MthInitialized := False;
  InitMthState;

  { Initialiser l'etat du generateur date/heure (TODO 14) }
  DtmInitialized := False;
  InitDtmState;

  { Afficher l'etat des options en mode debug }
  If Options.DebugMode Then Begin
    DumpOptState;
    DumpLearnState;
    DumpHisState;
    DumpIntState;
    DumpGenState;
    DumpTypState;
    DumpExpState;
    DumpCtlState;
    DumpPrcState;
    DumpUntState;
    DumpTplState;
    DumpHloState;
    DumpMthState;
    DumpDtmState;
  End;

  Run;

  { Message de fin pour les TODOs }
  { TODOs 01-25 : Statut actuel }
  { 01 [IMPLEMENTE] - Infrastructure et options }
  { 02 [IMPLEMENTE] - Chargement fichiers apprentissage }
  { 03 [IMPLEMENTE] - Historique de conversation }
  { 04 [IMPLEMENTE] - Analyseur de requetes }
  { 05 [IMPLEMENTE] - Generateur structures de base }
  { 06 [IMPLEMENTE] - Types et variables }
  { 07 [IMPLEMENTE] - Expressions }
  { 08 [IMPLEMENTE] - Structures de controle }
  { 09 [IMPLEMENTE] - Procedures et fonctions }
  { 10 [IMPLEMENTE] - Unites (UNIT) }
  { 11 [IMPLEMENTE] - Templates de code }
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
