{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Turbo Pascal vers JavaScript (.js)
}

(* ============================================================
   TP2JS.PAS - Compilateur Turbo Pascal vers JavaScript (.js)
   Turbo Pascal / Free Pascal (-Mtp)
   Cible : code JavaScript ES5+ (.js)

   Inspire du concept Pas2JS (Free Pascal) mais reecrit
   entierement pour cibler le Turbo Pascal 7.

   FEUILLE DE ROUTE - 25 TODOS
   ============================================================

   TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
             TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings,
               ModuleES6, Pretty)
             ParseArgs : analyser argv (source.pas [sortie.js] [-v] [-d] [-w]
               [-m] [-pretty] [-h])
             FatalError, CompileError, WarnMsg
             EXIT_OK / EXIT_ERROR / EXIT_USAGE
             Detecter l extension .pas du fichier source
             Sortie par defaut : meme nom avec extension .js
             Programme principal : validation des arguments et appel Run
             Version, Date, aide en ligne (option -h)
             Option -m (module ES6) : generer export/import au lieu de global
             Option -pretty : indentation du JavaScript genere
             ShowBanner, ShowUsage, ShowStats
             StrLowerCase, IntToStr_, BaseName, ReplaceExt
             InitOptions, Cleanup, GlobalInit
             Run (stub), programme principal ParseArgs + Run

   TODO 02 - LEXEUR (TOKENS TURBO PASCAL) [IMPLEMENTE]
             TTokenKind : TK_EOF, TK_INTEGER, TK_REAL, TK_STRING,
               TK_CHAR, TK_IDENT, TK_KEYWORD, TK_OP, TK_PUNCT,
               TK_DIRECTIVE
             LexInit, LexClose, LexNextToken, LexScanIdent, LexScanNumber
             LexScanString : chaine entre apostrophes 'abc'
               Apostrophe doublee : 'l''arbre' -> l'arbre
               Caracteres speciaux : #10 #13 #9 #0 #26 (codes ASCII)
               Chaines avec ^ : ^G (BEL), ^M (CR), etc.
             Commentaires : { ... } et (star...star) bloc, // ligne (TP7+)
             Mots-cles : AND ARRAY BEGIN CASE CONST DIV DO DOWNTO
               ELSE END FILE FOR FORWARD FUNCTION GOTO IF
               IMPLEMENTATION IN INHERITED INLINE INTERFACE LABEL
               MOD NIL NOT OBJECT OF OR PACKED PROCEDURE PROGRAM
               RECORD REPEAT SET SHL SHR STRING THEN TO TYPE
               UNIT UNTIL USES VAR WHILE WITH XOR
             Directives : ABSOLUTE ASSEMBLER EXTERNAL FAR INTERRUPT
               NEAR PRIVATE PUBLIC VIRTUAL
             Mode debug -d : affichage de chaque token avec PrintToken

   TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
             Entiers decimaux : 0..2147483647 (LongInt)
             Entiers hexadecimaux : $FF, $FFFF, $7FFFFFFF
             Reels : 3.14, 1.5E10, 2.0E-3 -> number en JavaScript
             Chaines : 'abc' -> chaine JS entre guillemets doubles "abc"
               Concatenation : 'Hello' + ' World' (via operateur +)
               Chaines avec codes : 'abc'#13#10 -> "abc\r\n" en JS
             Caracteres : #65 -> String.fromCharCode(65)
               'A' -> traite comme chaine de longueur 1
             Nil : constante pointeur nul -> null en JS
             True : constante booleenne -> true en JS
             False : constante booleenne -> false en JS
             Constantes typees : const X: Integer = 42 -> var X = 42
             Constantes ensembles : [1, 3..5] -> Set ou tableau JS

   TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
             Arithmetiques  : + - * / DIV MOD (entiers et reels)
               / -> division reelle en JS
               DIV -> Math.trunc(a / b) en JS
               MOD -> operateur % en JS
             Comparaison    : = <> < <= > >=
               = -> === en JS, <> -> !== en JS
             Logiques       : AND OR NOT XOR
               AND -> && en JS, OR -> || en JS, NOT -> ! en JS
               XOR -> (a ? !b : b) ou operateur bitwise ^ en JS
             Bitwise        : AND OR XOR NOT SHL SHR (sur entiers)
               SHL -> << en JS, SHR -> >> en JS
             Affectation    : := -> = en JS
             Concatenation  : + sur les chaines
             Ensembles      : + (union) * (intersection) - (difference)
               IN : appartenance a un ensemble
             Adresse        : @ (adresse de) -> reference en JS
             Precedence (du plus fort au plus faible) :
               1. NOT, @ , unaire +/-
               2. * / DIV MOD AND SHL SHR
               3. + - OR XOR
               4. = <> < > <= >= IN

   TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
             TSymKind : SK_CONST, SK_TYPE, SK_VAR, SK_PARAM, SK_FUNC,
               SK_PROC, SK_FIELD, SK_METHOD, SK_PROPERTY, SK_UNIT,
               SK_LABEL, SK_ENUMVAL
             TSymRec : Name, JSName (nom JavaScript genere), Kind, TypeIdx,
               Scope, IsPublic, IsPrivate, IsForward, IsExternal
             SymAdd, SymFind, SymFindInScope, SymGenJSName
             CurScope : compteur de portee imbriquee (max MAX_SCOPE)
             SymEnterScope / SymLeaveScope : gestion des portees imbriquees
             Qualificateurs : Unit.Ident -> recherche dans la portee de l unite
             Distinction INTERFACE / IMPLEMENTATION dans les unites
             Symboles predefinis : Integer, Word, Byte, Char, Boolean,
               Real, String, LongInt, ShortInt, Pointer, Text,
               Comp, Single, Double, Extended

   TODO 06 - SYSTEME DE TYPES [IMPLEMENTE]
             TTypeKind : TYK_INTEGER (16 bits signe), TYK_WORD (16 bits non signe),
               TYK_BYTE (8 bits non signe), TYK_SHORTINT (8 bits signe),
               TYK_LONGINT (32 bits signe), TYK_COMP (64 bits entier),
               TYK_BOOLEAN (8 bits), TYK_CHAR (8 bits),
               TYK_REAL (6 octets TP), TYK_SINGLE, TYK_DOUBLE, TYK_EXTENDED,
               TYK_STRING (chaine courte 255 car), TYK_PCHAR (ptr char),
               TYK_ARRAY, TYK_RECORD, TYK_SET, TYK_ENUM,
               TYK_FILE, TYK_TEXT, TYK_POINTER, TYK_OBJECT,
               TYK_SUBRANGE, TYK_PROCVAR
             TypeTab, TypeInit : enregistrer les types primitifs et utilisateur
             Correspondance vers JS :
               Integer/Word/Byte/ShortInt/LongInt -> number
               Real/Single/Double/Extended/Comp -> number
               Boolean -> boolean, Char -> string (1 car)
               String -> string, PChar -> string
               Array -> Array, Record -> object, Set -> Set ou Array
               File/Text -> objet fichier JS, Pointer -> reference
               Object -> class JS, ProcVar -> function

   TODO 07 - EMETTEUR DE CODE JAVASCRIPT [IMPLEMENTE]
             TEmitter : OutF (Text), OutFOpen, EmitOpen, EmitClose
             EmitRaw, EmitLine (avec indentation courante)
             EmitComment (// commentaire JS)
             EmitBlankLine
             IndentLevel : niveau d indentation courant
             IndentPush / IndentPop : gestion de l indentation
             Prefixes JS : _TPV_ (variable), _TPF_ (fonction), _TPC_ (constante),
               _TPT_ (type), _TPU_ (unite), _TPR_ (runtime)
             EmitHeader : commentaire /* Generated by TP2JS */ + "use strict";
             EmitModuleHeader : si option -m, generer en-tete module ES6
             EmitFooter : fermer les blocs ouverts, appel du programme principal

   TODO 08 - PROGRAMME PRINCIPAL (PROGRAM) [IMPLEMENTE]
             ParseProgram : PROGRAM nom [(params)]; uses; decls; BEGIN stmts END.
             Emission : function _main() { ... } en JS
               Appel automatique : _main(); a la fin du fichier
             Section USES : parser la liste d unites a importer
               Generer les imports ou includes correspondants en JS
             Sections de declaration : CONST, TYPE, VAR, LABEL
               Ordre libre des sections (plusieurs de chaque autorisees)
             BEGIN ... END. : corps principal -> contenu de _main()
             Compilation d un fichier .pas autonome (sans UNIT)
             Gestion du point final . (fin du programme)

   TODO 09 - VARIABLES ET AFFECTATIONS [IMPLEMENTE]
             Variables globales : section VAR -> var/let en JS
               var X: Integer; -> var X = 0;
               var S: String; -> var S = "";
             Variables locales : VAR dans procedure/fonction -> var/let en JS
             Initialisation par defaut selon le type :
               Integer/Word/Byte/LongInt -> 0
               Real/Single/Double -> 0.0
               Boolean -> false, Char -> '\0' (ou "")
               String -> "", Pointer -> null
               Array -> [], Record -> {}, Set -> new Set() ou []
             Affectation := -> = en JS
               X := 42; -> X = 42;
               S := 'Hello'; -> S = "Hello";
             Variables typees constantes : const X: Integer = 42 -> var X = 42;
               (mutables en Turbo Pascal malgre le mot-cle const)
             Affectation de record : copie champ par champ en JS
             Affectation de tableau : copie par slice() ou spread en JS

   TODO 10 - EXPRESSIONS PRIMAIRES [IMPLEMENTE]
             ParsePrimary : literal entier, literal reel, literal chaine,
               identificateur, appel de fonction/procedure
             Appel de fonction : Func(arg1, arg2) -> Func(arg1, arg2) en JS
             Acces champ record : Rec.Champ -> Rec.Champ en JS
             Acces index tableau : Arr[i] -> Arr[i - baseIdx] en JS
               (ajustement de l index de base si non zero)
             Dereferencement pointeur : Ptr^ -> traduction selon contexte
             Acces caractere chaine : S[i] -> S.charAt(i - 1) ou S[i - 1] en JS
               (index base 1 en Pascal, base 0 en JS)
             Transtypage : Integer(expr), Char(expr), Byte(expr)
               -> Math.trunc(expr), String.fromCharCode(expr), (expr & 0xFF)
             Parentheses : (expr) -> (expr) en JS
             Constantes predefinies : MaxInt -> 32767, MaxLongInt -> 2147483647
             Appel de methode objet : Obj.Method(args)
             Fonctions standards : Ord, Chr, Length, Abs, Sqr, Sqrt, Pred,
               Succ, Round, Trunc, Odd, UpCase, Lo, Hi, Pos, Copy, Concat,
               Inc, Dec, Sizeof

   TODO 11 - EXPRESSIONS BINAIRES ET UNAIRES [IMPLEMENTE]
             ParseExprPrec(MinPrec) : boucle de precedence (Pratt parser)
             Arithmetique : + - * / -> +, -, *, / en JS
               DIV -> Math.trunc(a / b)
               MOD -> a % b (ou ((a % b) + b) % b pour compatibilite Pascal)
             Comparaison : = -> ===, <> -> !==, < <= > >= identiques en JS
             Logique : AND -> &&, OR -> ||, NOT -> !
             Bitwise : AND -> &, OR -> |, XOR -> ^, NOT -> ~
               SHL -> <<, SHR -> >>
             Concatenation de chaines : + -> + en JS (naturel)
             Operateur IN : x IN S -> S.has(x) ou S.indexOf(x) >= 0
             Operateur @ : @variable -> reference (pas d equivalent direct en JS)
             Unaire : - (negation), + (identite), NOT (negation logique/bitwise)
             Operateur de type : expr AS type (Turbo Pascal objets)

   TODO 12 - ENTREES/SORTIES (Write / WriteLn / Read / ReadLn) [IMPLEMENTE]
             Write(args...) : ecriture sans retour de ligne
               Write('Hello') -> process.stdout.write("Hello") ou _TPR_Write("Hello")
               Write(42) -> _TPR_Write(String(42)) ou _TPR_WriteInt(42)
               Write(X:10) -> formatage avec largeur de champ
               Write(R:10:2) -> formatage reel avec decimales
               Write(F, data) -> ecriture dans fichier
             WriteLn(args...) : ecriture avec retour de ligne
               WriteLn -> _TPR_WriteLn() ou console.log()
               WriteLn('Hello') -> console.log("Hello")
             Read(args...) : lecture de valeurs
               Read(X) -> X = _TPR_ReadInt() ou prompt()
               Read(F, data) -> lecture depuis fichier
             ReadLn(args...) : lecture avec passage a la ligne suivante
             Formatage : Write(X:Width) et Write(R:Width:Decimals)
               -> String(X).padStart(Width) et R.toFixed(Decimals)
             Str(X, S) : conversion nombre vers chaine
               -> S = String(X)
             Str(X:W:D, S) : Str avec formatage
               -> S = X.toFixed(D).padStart(W)
             Val(S, X, Code) : conversion chaine vers nombre
               -> X = Number(S), Code = isNaN(X) ? 1 : 0

   TODO 13 - IF / CASE / GOTO [IMPLEMENTE]
             ParseIfStmt : IF cond THEN stmt [ELSE stmt]
               -> if (cond) { stmt } else { stmt } en JS
               IF imbrique : else if (cond) { ... }
             ParseCaseStmt : CASE expr OF
               val1: stmt;
               val2, val3: stmt;
               lo..hi: stmt;
               ELSE stmt END
               -> switch (expr) { case val1: ...; break; ... default: ... } en JS
               Intervalles lo..hi : generer plusieurs case ou condition if
             ParseGotoStmt : GOTO label
               Labels declares dans section LABEL
               Emission en JS : utilisation de boucle etiquetee + break
                 ou restructuration du flux de controle
               Avertissement : GOTO deconseille, traduction limitee

   TODO 14 - BOUCLES : FOR / WHILE / REPEAT / BREAK / CONTINUE [IMPLEMENTE]
             ParseForStmt : FOR i := lo TO hi DO stmt
               -> for (var i = lo; i <= hi; i++) { stmt } en JS
               FOR i := hi DOWNTO lo DO stmt
               -> for (var i = hi; i >= lo; i--) { stmt } en JS
             ParseWhileStmt : WHILE cond DO stmt
               -> while (cond) { stmt } en JS
             ParseRepeatStmt : REPEAT stmts UNTIL cond
               -> do { stmts } while (!(cond)); en JS
             Break : sortie de boucle -> break; en JS
               (Turbo Pascal 7 supporte Break dans les boucles)
             Continue : iteration suivante -> continue; en JS
             Exit : sortie de procedure/fonction -> return; en JS
             Halt / Halt(code) : arret du programme
               -> process.exit(code) ou throw new Error en JS

   TODO 15 - PROCEDURES ET FONCTIONS [IMPLEMENTE]
             ParseProcDecl : PROCEDURE nom[(params)]; [directives;] bloc;
             ParseFuncDecl : FUNCTION nom[(params)]: RetType; [directives;] bloc;
             Parametres valeur : procedure P(X: Integer)
               -> function P(X) { ... } en JS
             Parametres variable (VAR) : procedure P(var X: Integer)
               -> passage par objet wrapper { value: X } en JS
               Appel : P(X) -> P({value: X}); X = ref.value;
               ou utilisation de tableaux : P([X]); X = ref[0];
             Parametres constante (CONST) : comme valeur en JS (pas de copie)
             Variables locales : VAR dans le bloc -> var en JS
             Forward : declaration anticipee -> declaration JS differee
             Nested procedures : procedures imbriquees
               -> fonctions imbriquees en JS (closures naturelles)
             Exit : sortie anticipee -> return; en JS
             Exit(valeur) : retour avec valeur (TP7)
               -> return valeur; en JS
             Result : variable de retour implicite -> var Result; return Result;
             Directives : FAR, NEAR, INLINE, ASSEMBLER, EXTERNAL
               -> ignorer ou avertissement (non pertinent en JS)

   TODO 16 - TYPES STRUCTURES : ARRAY / RECORD / SET / STRING [IMPLEMENTE]
             ARRAY[lo..hi] OF T :
               -> new Array(hi - lo + 1) en JS, indexation ajustee
               Multidimensionnel : ARRAY[a..b, c..d] OF T -> tableaux imbriques
             RECORD champ1: T1; champ2: T2; END :
               -> objet literal { champ1: defaut1, champ2: defaut2 } en JS
               Variantes : CASE tag OF val1: (...); val2: (...); END
                 -> proprietes conditionnelles ou objet aplati
             SET OF T (T = type ordinal, max 256 elements) :
               -> new Set() en JS, ou tableau de booleens
               Operations : + (union), * (intersection), - (difference), IN
               -> Set.prototype methods ou operations sur tableaux
             STRING et STRING[N] (chaine courte) :
               -> string natif JS (pas de limite 255 en JS)
               Length(S) -> S.length en JS
               S[i] -> S.charAt(i - 1) ou S[i - 1] (base 0 en JS)
               Copy, Pos, Concat, Delete, Insert -> methodes String JS

   TODO 17 - OBJETS ET HERITAGE (OBJECT) [IMPLEMENTE]
             TYPE TNom = OBJECT [(TParent)]
               champ1: T1;
               CONSTRUCTOR Init(params);
               DESTRUCTOR Done; VIRTUAL;
               PROCEDURE Method(params); VIRTUAL;
               FUNCTION Func(params): T; VIRTUAL;
             END;
             Emission en JS : class TNom [extends TParent] {
               constructor(params) { ... }
               method(params) { ... }
             }
             Methodes virtuelles : VIRTUAL -> methodes de classe JS (naturel)
             Methodes statiques : sans VIRTUAL -> identiques en JS
             CONSTRUCTOR : -> constructor() en JS
             DESTRUCTOR : -> methode destroy() en JS (appel manuel)
             NEW(Ptr, Init(params)) : allocation + construction
               -> Ptr = new TNom(params) en JS
             DISPOSE(Ptr, Done) : destruction + liberation
               -> Ptr.Done(); Ptr = null; en JS
             INHERITED : appel methode parent -> super.method() en JS
             Champs PRIVATE : accessibles dans l unite seulement
               -> convention JS avec prefixe _ ou champs prives (#)

   TODO 18 - UNITE SYSTEM (IMPLICITE)
             Fonctions mathematiques :
               Abs(X) -> Math.abs(X)
               Sqr(X) -> (X * X) ou Math.pow(X, 2)
               Sqrt(X) -> Math.sqrt(X)
               Sin(X) -> Math.sin(X), Cos(X) -> Math.cos(X)
               ArcTan(X) -> Math.atan(X)
               Exp(X) -> Math.exp(X), Ln(X) -> Math.log(X)
               Int(X) -> Math.trunc(X), Frac(X) -> X - Math.trunc(X)
               Round(X) -> Math.round(X), Trunc(X) -> Math.trunc(X)
               Pi -> Math.PI
             Fonctions ordinales :
               Ord(X) -> X.charCodeAt(0) ou Number(X)
               Chr(X) -> String.fromCharCode(X)
               Succ(X) -> X + 1, Pred(X) -> X - 1
               Inc(X) -> X++, Dec(X) -> X--
               Inc(X, N) -> X += N, Dec(X, N) -> X -= N
               Lo(X) -> X & 0xFF, Hi(X) -> (X >> 8) & 0xFF
               Swap(X) -> ((X & 0xFF) << 8) | ((X >> 8) & 0xFF)
               Odd(X) -> (X % 2 !== 0)
             Fonctions de chaine :
               Length(S) -> S.length
               Copy(S, Pos, Len) -> S.substr(Pos - 1, Len)
               Pos(Sub, S) -> (S.indexOf(Sub) + 1) ou 0 si absent
               Concat(S1, S2, ...) -> S1 + S2 + ...
               Delete(S, Pos, Len) -> S = S.substring(0, Pos-1) + S.substring(Pos-1+Len)
               Insert(Src, S, Pos) -> S = S.substring(0, Pos-1) + Src + S.substring(Pos-1)
               UpCase(Ch) -> Ch.toUpperCase()
               Str(X, S) -> S = String(X)
               Val(S, X, Code) -> X = parseFloat(S); Code = isNaN(X) ? 1 : 0
             Fonctions de fichier :
               Assign(F, Name) -> F = { name: Name, ... }
               Reset(F) / Rewrite(F) -> ouverture fichier (stub ou API Node.js)
               Close(F) -> fermeture fichier
               Eof(F) -> fin de fichier, Eoln(F) -> fin de ligne
               Read(F, ...) / Write(F, ...) -> lecture/ecriture fichier
               Seek(F, Pos), FilePos(F), FileSize(F)
               Erase(F), Rename(F, NewName)
               BlockRead, BlockWrite : lecture/ecriture par blocs
             Fonctions memoire :
               New(P) -> P = {} ou P = new Type()
               Dispose(P) -> P = null
               GetMem(P, Size) / FreeMem(P, Size) -> allocation/liberation
               SizeOf(T) -> taille en octets (constante ou estimation)
               FillChar(Buf, Count, Val) -> remplissage memoire
               Move(Src, Dest, Count) -> copie memoire
             Autres :
               Random / Random(N) -> Math.random() ou Math.floor(Math.random() * N)
               Randomize -> (rien en JS, Random est deja pseudo-aleatoire)
               ParamCount -> _TPR_Args.length - 1
               ParamStr(N) -> _TPR_Args[N]
               Halt(Code) -> process.exit(Code)
               RunError(Code) -> throw new Error('Runtime error ' + Code)
               Addr(X) -> reference a X
               Assigned(P) -> (P !== null && P !== undefined)

   TODO 19 - UNITE CRT
             Constantes de couleur :
               Black=0, Blue=1, Green=2, Cyan=3, Red=4, Magenta=5,
               Brown=6, LightGray=7, DarkGray=8, LightBlue=9,
               LightGreen=10, LightCyan=11, LightRed=12, LightMagenta=13,
               Yellow=14, White=15, Blink=128
               -> constantes numeriques JS
             Variables :
               TextAttr, WindMin, WindMax, LastMode,
               DirectVideo, CheckBreak, CheckEOF, CheckSnow
             Procedures d ecran :
               ClrScr -> console.clear() ou sequence ANSI ESC[2J
               ClrEol -> sequence ANSI ESC[K
               GotoXY(X, Y) -> sequence ANSI ESC[Y;XH
               WhereX -> position X courante (stub)
               WhereY -> position Y courante (stub)
               TextColor(Color) -> sequence ANSI ESC[3Xm
               TextBackground(Color) -> sequence ANSI ESC[4Xm
               HighVideo / LowVideo / NormVideo -> sequences ANSI
               Window(X1, Y1, X2, Y2) -> definir fenetre (stub)
               InsLine / DelLine -> sequences ANSI insertion/suppression
             Procedures de clavier :
               KeyPressed -> verifier si touche disponible (stub ou event JS)
               ReadKey -> lire un caractere (prompt ou event handler)
             Procedures sonores :
               Sound(Hz) / NoSound -> Web Audio API ou stub
               Delay(Ms) -> setTimeout ou boucle d attente
             Modes ecran :
               TextMode(Mode) -> changer le mode texte (stub)
               CO80, BW80, CO40, BW40, Mono, Font8x8 -> constantes de mode

   TODO 20 - UNITE DOS
             Types :
               DateTime = record Year,Month,Day,Hour,Min,Sec: Word end
               SearchRec = record Attr,Time,Size,Name... end
               Registers = record AX,BX,CX,DX,BP,SI,DI,DS,ES,Flags end
             Constantes d attributs de fichier :
               ReadOnly=$01, Hidden=$02, SysFile=$04, VolumeID=$08,
               Directory=$10, Archive=$20, AnyFile=$3F
             Fonctions de date et heure :
               GetDate(Y,M,D,DOW) -> d = new Date(); Y=d.getFullYear(); ...
               GetTime(H,M,S,S100) -> d = new Date(); H=d.getHours(); ...
               SetDate / SetTime -> avertissement (non supporte en JS)
               PackTime(DT, Time) / UnpackTime(Time, DT) -> conversion
               GetFTime(F, Time) -> date de modification fichier (Node.js fs.stat)
               SetFTime(F, Time) -> modifier date (Node.js fs.utimes)
             Fonctions de fichier et repertoire :
               FindFirst(Path, Attr, SR) -> recherche de fichiers (Node.js glob)
               FindNext(SR) -> fichier suivant
               FSearch(Name, List) -> recherche dans PATH
               FExpand(Path) -> chemin absolu (Node.js path.resolve)
               FSplit(Path, Dir, Name, Ext) -> decomposition chemin
               GetDir(Drive, Dir) / SetDir(Dir) -> repertoire courant
               CreateDir(Dir) / RemoveDir(Dir) -> creer/supprimer repertoire
             Environnement et systeme :
               EnvCount -> Object.keys(process.env).length
               EnvStr(N) -> Object.entries(process.env)[N]
               GetEnv(Name) -> process.env[Name] || ''
               DosVersion -> { major: 7, minor: 0 } (stub)
               DiskFree(Drive) / DiskSize(Drive) -> stub ou Node.js
               GetCBreak / SetCBreak -> stub
               GetVerify / SetVerify -> stub
             Execution :
               Exec(Path, CmdLine) -> child_process.execSync (Node.js)
               DosExitCode -> code de retour du dernier Exec
               SwapVectors -> stub (non pertinent en JS)
               Keep(Code) -> stub (TSR non pertinent en JS)

   TODO 21 - UNITE OVERLAY
             OverlayInit(FileName) : initialiser le gestionnaire d overlay
               -> avertissement : overlays non pertinents en JS
               -> stub : function OvrInit(f) { /* no-op */ }
             OverlayInitEMS : utiliser EMS pour les overlays
               -> stub : function OvrInitEMS() { /* no-op */ }
             OvrGetBuf / OvrSetBuf : gerer la taille du buffer d overlay
               -> stub : retourner des constantes
             OvrGetRetry / OvrSetRetry : taille du cache de tentatives
               -> stub
             OvrClearBuf : vider le buffer d overlay
               -> stub
             OvrResult : code de retour des operations d overlay
               -> constante ovrOk = 0
             Constantes : ovrOk=0, ovrError=-1, ovrNotFound=-2,
               ovrNoMemory=-3, ovrIOError=-4, ovrNoEMSDriver=-5,
               ovrNoEMSMemory=-6
               -> constantes numeriques JS
             Emettre un avertissement a la compilation si USES Overlay
               indiquant que les overlays sont ignores en JavaScript

   TODO 22 - UNITE GRAPH
             Constantes de pilotes et modes :
               Detect=0, CGA=1, EGA=3, VGA=9, etc.
               -> constantes numeriques JS
               CGAHi=4, EGAHi=1, VGAHi=2, VGAMed=1, VGALo=0
             Constantes de couleur :
               Black=0 ... White=15 (memes que Crt)
               EGABlack..EGAWhite pour mode EGA
             Constantes de remplissage et style :
               EmptyFill=0, SolidFill=1, LineFill=2, ...
               SolidLn=0, DottedLn=1, CenterLn=2, DashedLn=3
               NormalPut=0, XORPut=1, OrPut=2, AndPut=3, NotPut=4
             Initialisation :
               InitGraph(Driver, Mode, Path) -> creer un <canvas> HTML
                 ou utiliser une librairie canvas Node.js
               CloseGraph -> detruire le contexte graphique
               DetectGraph(Driver, Mode) -> detection automatique (VGA stub)
               GraphResult / GraphErrorMsg -> codes d erreur graphique
               GetMaxX / GetMaxY -> dimensions du canvas
               GetMaxColor -> nombre de couleurs disponibles
             Dessin :
               PutPixel(X, Y, Color) -> ctx.fillRect(X, Y, 1, 1)
               GetPixel(X, Y) -> ctx.getImageData(X, Y, 1, 1)
               Line(X1, Y1, X2, Y2) -> ctx.beginPath(); ctx.moveTo/lineTo
               LineTo(X, Y) -> ctx.lineTo depuis position courante
               MoveTo(X, Y) -> mettre a jour position courante (CP)
               Circle(X, Y, R) -> ctx.arc(X, Y, R, 0, 2*PI)
               Arc(X, Y, SA, EA, R) -> ctx.arc avec angles
               Ellipse(X, Y, SA, EA, XR, YR) -> ctx.ellipse
               Rectangle(X1, Y1, X2, Y2) -> ctx.strokeRect
               Bar(X1, Y1, X2, Y2) -> ctx.fillRect
               Bar3D(X1, Y1, X2, Y2, Depth, Top) -> barre 3D (lignes)
               FillEllipse(X, Y, XR, YR) -> ctx.fill() apres ellipse
               FillPoly(NumPoints, PolyPoints) -> ctx.fill() apres path
               FloodFill(X, Y, Border) -> algorithme de remplissage
               Sector(X, Y, SA, EA, XR, YR) -> secteur rempli
               PieSlice(X, Y, SA, EA, R) -> secteur circulaire
             Texte graphique :
               OutText(S) -> ctx.fillText(S, CP.X, CP.Y)
               OutTextXY(X, Y, S) -> ctx.fillText(S, X, Y)
               SetTextStyle(Font, Direction, Size) -> ctx.font = ...
               SetTextJustify(Horiz, Vert) -> ctx.textAlign/textBaseline
               TextWidth(S) / TextHeight(S) -> ctx.measureText
             Style et couleur :
               SetColor(Color) -> ctx.strokeStyle = palette[Color]
               SetBkColor(Color) -> ctx.fillStyle pour fond
               GetColor / GetBkColor -> couleur courante
               SetFillStyle(Pattern, Color) -> remplissage courant
               SetFillPattern(Pattern, Color) -> motif personnalise
               SetLineStyle(Style, Pattern, Thick) -> ctx.setLineDash
               SetWriteMode(Mode) -> ctx.globalCompositeOperation
             Fenetrage et viewport :
               SetViewPort(X1, Y1, X2, Y2, Clip) -> ctx.save/clip
               ClearViewPort -> effacer le viewport courant
               ClearDevice -> effacer tout le canvas
               GetViewSettings -> retourner les parametres du viewport
             Image :
               ImageSize(X1, Y1, X2, Y2) -> taille du buffer image
               GetImage(X1, Y1, X2, Y2, Buf) -> ctx.getImageData
               PutImage(X, Y, Buf, Op) -> ctx.putImageData avec operation
             Palette :
               SetPalette(Index, Color) -> modifier une entree de palette
               SetAllPalette(Palette) -> modifier toute la palette
               GetPalette(Palette) -> lire la palette courante
               GetDefaultPalette(Palette) -> palette par defaut
               SetRGBPalette(Index, R, G, B) -> couleur RGB

   TODO 23 - UNITES UTILISATEUR ET COMPILATION SEPAREE
             ParseUnit : UNIT nom; INTERFACE ... IMPLEMENTATION ... [BEGIN ... ] END.
             Section INTERFACE :
               Declarations exportees (types, constantes, variables, procedures)
               Signatures de fonctions/procedures sans corps
             Section IMPLEMENTATION :
               Corps des procedures/fonctions declarees dans INTERFACE
               Declarations privees (non exportees)
             Section d initialisation : BEGIN ... END. (optionnel)
               -> code execute au chargement de l unite
               Emission JS : bloc d initialisation appele avant _main()
             USES dans les unites : dependances entre unites
               Resolution de l ordre d initialisation (topologique)
             Compilation separee :
               Chaque unite .pas -> un fichier .js separe
               Option -m : module ES6 avec export/import
               Option fichier unique : tout concatener dans un seul .js
             Resolution des references croisees :
               INTERFACE d une unite -> symboles disponibles pour les autres
               Chargement des declarations depuis .pas ou .tpu (stub)

   TODO 24 - RUNTIME JAVASCRIPT MINIMAL
             _TPR_Write(S) : ecriture sur stdout
               -> process.stdout.write(String(S)) (Node.js)
               -> document.write(S) (navigateur, si applicable)
             _TPR_WriteLn(S) : ecriture avec retour de ligne
               -> console.log(S)
             _TPR_ReadLn() : lecture d une ligne
               -> prompt() (navigateur) ou readline (Node.js)
             _TPR_WriteF(F, S) : ecriture dans un fichier
               -> fs.appendFileSync(F.name, S) (Node.js)
             _TPR_Halt(Code) : arret du programme
               -> process.exit(Code) (Node.js) ou throw (navigateur)
             _TPR_IntToStr(N, Width) : entier vers chaine formatee
               -> String(N).padStart(Width)
             _TPR_RealToStr(R, Width, Dec) : reel vers chaine formatee
               -> R.toFixed(Dec).padStart(Width)
             _TPR_StrToInt(S) : chaine vers entier
               -> parseInt(S, 10)
             _TPR_StrToReal(S) : chaine vers reel
               -> parseFloat(S)
             _TPR_SetOps : operations sur les ensembles
               _TPR_SetUnion(A, B), _TPR_SetInter(A, B),
               _TPR_SetDiff(A, B), _TPR_SetIn(Elem, S)
             _TPR_Copy(S, Pos, Len) : sous-chaine (base 1 -> base 0)
               -> S.substr(Pos - 1, Len)
             _TPR_Pos(Sub, S) : position de sous-chaine (base 1)
               -> (S.indexOf(Sub) + 1) || 0
             _TPR_Delete(S, Pos, Len) : suppression dans chaine
             _TPR_Insert(Src, S, Pos) : insertion dans chaine
             _TPR_FillChar(Buf, Count, Val) : remplissage tableau
             _TPR_Move(Src, Dest, Count) : copie tableau
             _TPR_Random(N) : nombre pseudo-aleatoire
               -> Math.floor(Math.random() * N) si N fourni
               -> Math.random() sinon
             _TPR_IOResult : variable globale code d erreur E/S
             _TPR_Args : tableau des arguments de ligne de commande
               -> process.argv.slice(2) (Node.js)
             RuntimeEmitted : flag pour n emettre le runtime qu une seule fois

   TODO 25 - GENERATION FINALE ET FICHIERS EXEMPLES
             EmitClose : ecrire l appel _main() a la fin du fichier .js
             Run : pipeline complet LexInit -> ParseProgram ou ParseUnit ->
               EmitRuntime -> EmitFooter -> fermeture du fichier
             Optimisations simples :
               Constantes evaluees a la compilation (constant folding)
               Suppression de code mort (branches if false)
               Variables non utilisees -> avertissement
             Fichiers SAMPLES\TURBOPASCAL\ a utiliser pour les tests :
               hello.pas    (WriteLn, variables, constantes, String)
               math.pas     (fonctions mathematiques, expressions, Real)
               control.pas  (IF/CASE, WHILE, FOR, REPEAT, GOTO)
               arrays.pas   (ARRAY fixe, multidimensionnel, String)
               records.pas  (RECORD, WITH, variantes, affectation)
               objects.pas  (OBJECT, CONSTRUCTOR, VIRTUAL, INHERITED)
               fileio.pas   (Assign, Reset, Rewrite, Read, Write, Close)
               crtdemo.pas  (uses Crt: ClrScr, GotoXY, TextColor, ReadKey)
               dosdemo.pas  (uses Dos: GetDate, GetTime, FindFirst, Exec)
               graphdemo.pas (uses Graph: InitGraph, Line, Circle, Bar)
               unitdemo.pas (UNIT + PROGRAM utilisant l unite)
             Smoke tests : TP2JS source.pas -v et execution node sortie.js

   ============================================================ *)

Program TP2JS;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES
  ============================================================ }
Const
  TP2JS_VERSION = '1.0';
  TP2JS_DATE    = '2026-03-10';

  MAX_STR       = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  MAX_ERRORS    = {$IFDEF FPC}30{$ELSE}3{$ENDIF};

  TP_VAR_PFX  = '_TPV_';
  TP_FN_PFX   = '_TPF_';
  TP_CST_PFX  = '_TPC_';
  TP_TYPE_PFX = '_TPT_';
  TP_UNIT_PFX = '_TPU_';
  TP_RT_PFX   = '_TPR_';

  MAX_TOKEN   = {$IFDEF FPC}16384{$ELSE}4096{$ENDIF};
  MAX_CONST   = 256;
  MAX_SYM     = {$IFDEF FPC}2048{$ELSE}512{$ENDIF};
  MAX_SCOPE   = 64;
  MAX_TYPE    = {$IFDEF FPC}512{$ELSE}128{$ENDIF};
  MAX_FIELD   = 64;

  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String[MAX_STR];

  TOptions = Record
    SrcFile   : TString;
    OutFile   : TString;
    Verbose   : Boolean;
    DebugMode : Boolean;
    Warnings  : Boolean;
    ModuleES6 : Boolean;
    Pretty    : Boolean;
  End;

  TTokenKind = (
    TK_EOF,            { fin de fichier                       }
    TK_INTEGER,        { literal entier 42 $FF                }
    TK_REAL,           { literal reel 3.14 1.5E3              }
    TK_STRING,         { literal chaine 'hello'               }
    TK_CHAR,           { literal caractere #65 #$41           }
    TK_IDENT,          { identificateur (non-mot-cle)         }
    TK_KEYWORD,        { mot-cle Turbo Pascal reconnu         }
    TK_OP,             { operateur := + - * / = <> < > etc.   }
    TK_PUNCT,          { ponctuation ; , ( ) [ ] . ..         }
    TK_DIRECTIVE       { directive (absolute, virtual, etc.)  }
  );

  TToken = Record
    Kind     : TTokenKind;
    Val      : TString;     { valeur textuelle brute           }
    IntVal   : LongInt;     { valeur entiere (TK_INTEGER)      }
    RealVal  : Real;        { valeur reelle (TK_REAL)          }
    Line     : Integer;     { ligne source (1-base)            }
    Col      : Integer;     { colonne source (1-base)          }
  End;

  TConstRec = Record
    Name    : TString;     { nom de la constante Pascal         }
    JSVal   : TString;     { valeur JavaScript generee          }
    Kind    : TTokenKind;  { type du litteral (INT/REAL/STR...) }
    IntVal  : LongInt;     { valeur entiere si applicable       }
    RealVal : Real;        { valeur reelle si applicable        }
    StrVal  : TString;     { valeur chaine si applicable        }
    IsTyped : Boolean;     { constante typee (const X: T = V)   }
  End;

  TSymKind = (
    SK_CONST,            { constante                            }
    SK_TYPE,             { type (Integer, Boolean, record, etc) }
    SK_VAR,              { variable                             }
    SK_PARAM,            { parametre de procedure/fonction      }
    SK_FUNC,             { fonction                             }
    SK_PROC,             { procedure                            }
    SK_FIELD,            { champ de record/object               }
    SK_METHOD,           { methode d objet                      }
    SK_PROPERTY,         { propriete d objet                    }
    SK_UNIT,             { unite (uses)                         }
    SK_LABEL,            { label (goto)                         }
    SK_ENUMVAL           { valeur d enumeration                 }
  );

  TSymRec = Record
    Name       : TString;    { nom Pascal (original)             }
    JSName     : TString;    { nom JavaScript genere              }
    Kind       : TSymKind;   { categorie du symbole               }
    TypeIdx    : Integer;    { index dans table des types (-1=NA) }
    Scope      : Integer;    { niveau de portee (0=global)        }
    ScopeId    : Integer;    { id unique de la portee             }
    IsPublic   : Boolean;    { visible dans INTERFACE             }
    IsPrivate  : Boolean;    { prive (PRIVATE dans objet)         }
    IsForward  : Boolean;    { declaration Forward                }
    IsExternal : Boolean;    { declaration External               }
  End;

  TTypeKind = (
    TYK_INTEGER,           { Integer : 16 bits signe              }
    TYK_WORD,              { Word    : 16 bits non signe           }
    TYK_BYTE,              { Byte    : 8 bits non signe            }
    TYK_SHORTINT,          { ShortInt: 8 bits signe                }
    TYK_LONGINT,           { LongInt : 32 bits signe               }
    TYK_COMP,              { Comp    : 64 bits entier              }
    TYK_BOOLEAN,           { Boolean : 8 bits                      }
    TYK_CHAR,              { Char    : 8 bits                      }
    TYK_REAL,              { Real    : 6 octets TP                 }
    TYK_SINGLE,            { Single  : 4 octets IEEE               }
    TYK_DOUBLE,            { Double  : 8 octets IEEE               }
    TYK_EXTENDED,          { Extended: 10 octets                   }
    TYK_STRING,            { String  : chaine courte 255 car       }
    TYK_PCHAR,             { PChar   : pointeur vers char          }
    TYK_ARRAY,             { Array   : tableau                     }
    TYK_RECORD,            { Record  : enregistrement              }
    TYK_SET,               { Set     : ensemble                    }
    TYK_ENUM,              { Enum    : enumeration                 }
    TYK_FILE,              { File    : fichier type                }
    TYK_TEXT,              { Text    : fichier texte               }
    TYK_POINTER,           { Pointer : pointeur generique          }
    TYK_OBJECT,            { Object  : objet TP                    }
    TYK_SUBRANGE,          { Subrange: sous-intervalle             }
    TYK_PROCVAR            { ProcVar : variable procedurale        }
  );

  TFieldRec = Record
    Name    : TString;     { nom du champ                         }
    TypeIdx : Integer;     { index du type du champ               }
  End;

  TTypeRec = Record
    Kind        : TTypeKind;   { categorie du type                }
    Name        : TString;     { nom du type (Pascal)             }
    Size        : Integer;     { taille en octets (TP)            }
    JSType      : TString;     { type JavaScript correspondant    }
    JSDefault   : TString;     { valeur par defaut en JS          }
    BaseTypeIdx : Integer;     { type de base (array/pointer/set) }
    ElemCount   : Integer;     { nombre d elements (array/enum)   }
    FieldCount  : Integer;     { nombre de champs (record/object) }
    Fields      : Array[0..MAX_FIELD - 1] Of TFieldRec;
    Low         : LongInt;     { borne inf (subrange/array)       }
    High        : LongInt;     { borne sup (subrange/array)       }
    IsUnsigned  : Boolean;     { type non signe                   }
  End;

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
Var
  Opts : TOptions;

  ErrorCount : Integer;
  WarnCount  : Integer;
  TotalLines : LongInt;

  OutF     : Text;
  OutFOpen : Boolean;

  { Lexeur }
  LexSrcF   : Text;
  LexOpened : Boolean;
  LexLine   : String;
  LexLineNo : Integer;
  LexColNo  : Integer;
  LexEOF    : Boolean;
  CurToken  : TToken;

  { Token pool pour traitement multi-passe }
  TokenPool  : Array[0..MAX_TOKEN - 1] Of TToken;
  TokenCount : Integer;

  { Table des constantes }
  ConstTab   : Array[0..MAX_CONST - 1] Of TConstRec;
  ConstCount : Integer;

  { Table des symboles }
  SymTab     : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount   : Integer;
  CurScope   : Integer;         { niveau de portee courant (0=global) }
  CurScopeId : Integer;         { id unique de la portee courante     }
  SymJSSeq   : Integer;         { compteur pour noms JS uniques       }
  BuiltinSymEnd : Integer;      { indice apres les symboles builtins  }

  { Table des types }
  TypeTab    : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount  : Integer;

  { Emetteur de code JavaScript (TODO 07) }
  IndentLevel : Integer;          { niveau d indentation courant (0=gauche) }

  { Parseur de programme (TODO 08) }
  ProgName    : TString;          { nom du programme PROGRAM xxx            }

{ ============================================================
  FORWARD DECLARATIONS
  ============================================================ }
Procedure LexClose; Forward;
Function ParseExpr(Var P : Integer) : TString; Forward;
Function ConstEvalExpr(Var P : Integer) : TString; Forward;
Function IsBooleanExpr(Const S : TString) : Boolean; Forward;
Function TypeFindByName(Const AName : TString) : Integer; Forward;
Function SymFind(Const AName : TString) : Integer; Forward;

{ ============================================================
  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
  ============================================================ }

Function IntToStr_(N : LongInt) : TString;
Var
  S : TString;
Begin
  Str(N, S);
  IntToStr_ := S;
End;

{ StrToLongIntDef : convertir une chaine en LongInt avec defaut }
Function StrToLongIntDef(Const S : TString; Def : LongInt) : LongInt;
Var
  N    : LongInt;
  Code : Integer;
Begin
  Val(S, N, Code);
  If Code = 0 Then
    StrToLongIntDef := N
  Else
    StrToLongIntDef := Def;
End;

Function StrLowerCase(Const S : TString) : TString;
Var
  I : Integer;
  R : TString;
Begin
  R := S;
  For I := 1 To Length(R) Do
    If (R[I] >= 'A') And (R[I] <= 'Z') Then
      R[I] := Chr(Ord(R[I]) + 32);
  StrLowerCase := R;
End;

Function BaseName(Const Path : TString) : TString;
Var
  I, LastSep, LastDot : Integer;
  S : TString;
Begin
  LastSep := 0;
  LastDot := 0;
  For I := 1 To Length(Path) Do
  Begin
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
    If Path[I] = '.' Then
      LastDot := I;
  End;
  If LastDot > LastSep Then
    S := Copy(Path, LastSep + 1, LastDot - LastSep - 1)
  Else
    S := Copy(Path, LastSep + 1, Length(Path));
  BaseName := S;
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

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('TP2JS: FATAL: ', Msg);
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
    {$I-}
    Assign(OutF, Opts.OutFile);
    Erase(OutF);
    {$I+}
  End;
  Halt(EXIT_ERROR);
End;

Procedure CompileError(Const Msg : TString);
Begin
  WriteLn('TP2JS: error: ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('trop d''erreurs, compilation arretee');
End;

Procedure WarnMsg(Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  WriteLn('TP2JS: warning: ', Msg);
  Inc(WarnCount);
End;

Procedure ShowBanner;
Begin
  WriteLn('TP2JS v', TP2JS_VERSION, ' (', TP2JS_DATE, ')');
  WriteLn('Compilateur Turbo Pascal -> JavaScript (.js)');
  WriteLn('Turbo Pascal / Free Pascal (-Mtp)');
  WriteLn;
End;

Procedure ShowUsage;
Begin
  WriteLn('Usage: TP2JS <source.pas> [sortie.js] [options]');
  WriteLn;
  WriteLn('  source.pas : fichier Turbo Pascal source');
  WriteLn('  sortie.js  : fichier JavaScript de sortie (defaut: source.js)');
  WriteLn;
  WriteLn('Options:');
  WriteLn('  -v         : mode verbeux (banniere + statistiques)');
  WriteLn('  -d         : debug tokens (affiche chaque token)');
  WriteLn('  -w         : activer les avertissements');
  WriteLn('  -m         : generer module ES6 (export/import)');
  WriteLn('  -pretty    : indentation du JavaScript genere');
  WriteLn('  -h, --help : cette aide');
  WriteLn;
  Halt(EXIT_USAGE);
End;

Procedure ShowStats;
Begin
  WriteLn;
  WriteLn('Compilation terminee : ', Opts.SrcFile, ' -> ', Opts.OutFile);
  WriteLn('  Lignes         : ', TotalLines);
  WriteLn('  Erreurs        : ', ErrorCount);
  WriteLn('  Avertissements : ', WarnCount);
End;

Procedure InitOptions;
Begin
  Opts.SrcFile   := '';
  Opts.OutFile   := '';
  Opts.Verbose   := False;
  Opts.DebugMode := False;
  Opts.Warnings  := False;
  Opts.ModuleES6 := False;
  Opts.Pretty    := False;
End;

Procedure ParseArgs;
Var
  I   : Integer;
  Arg : TString;
  Ext : TString;
Begin
  InitOptions;
  If ParamCount = 0 Then
    ShowUsage;

  For I := 1 To ParamCount Do
  Begin
    Arg := ParamStr(I);

    If (Arg = '-h') Or (Arg = '--help') Or (Arg = '/?') Then
      ShowUsage
    Else If (Arg = '-v') Or (Arg = '--verbose') Then
      Opts.Verbose := True
    Else If Arg = '-d' Then
      Opts.DebugMode := True
    Else If Arg = '-w' Then
      Opts.Warnings := True
    Else If Arg = '-m' Then
      Opts.ModuleES6 := True
    Else If Arg = '-pretty' Then
      Opts.Pretty := True
    Else If (Length(Arg) > 0) And (Arg[1] = '-') Then
    Begin
      WriteLn('TP2JS: option inconnue: ', Arg);
      ShowUsage;
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else If Opts.OutFile = '' Then
      Opts.OutFile := Arg
    Else
    Begin
      WriteLn('TP2JS: argument inattendu: ', Arg);
      ShowUsage;
    End;
  End;

  If Opts.SrcFile = '' Then
  Begin
    WriteLn('TP2JS: fichier source manquant');
    ShowUsage;
  End;

  { Verifier extension .pas }
  Ext := StrLowerCase(Opts.SrcFile);
  If (Length(Ext) < 4) Or
     (Copy(Ext, Length(Ext) - 3, 4) <> '.pas') Then
  Begin
    WriteLn('TP2JS: le fichier source doit avoir l''extension .pas');
    ShowUsage;
  End;

  { Sortie par defaut : meme nom avec extension .js }
  If Opts.OutFile = '' Then
    Opts.OutFile := ReplaceExt(Opts.SrcFile, '.js');
End;

Procedure Cleanup;
Begin
  If LexOpened Then
    LexClose;
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

Procedure GlobalInit;
Begin
  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  OutFOpen   := False;
  LexOpened  := False;
  LexEOF     := False;
  LexLineNo  := 0;
  LexColNo   := 1;
  LexLine    := '';
  CurToken.Kind    := TK_EOF;
  CurToken.Val     := '';
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;
  CurToken.Line    := 0;
  CurToken.Col     := 0;
  TokenCount := 0;
  ConstCount := 0;
  ProgName   := 'main';
End;

{ ============================================================
  TODO 02 - LEXEUR (TOKENS TURBO PASCAL) [IMPLEMENTE]
  ============================================================ }

Function StrUpperCase(Const S : TString) : TString;
Var
  I : Integer;
  R : TString;
Begin
  R := S;
  For I := 1 To Length(R) Do
    If (R[I] >= 'a') And (R[I] <= 'z') Then
      R[I] := Chr(Ord(R[I]) - 32);
  StrUpperCase := R;
End;

Function IsIdentStart(Ch : Char) : Boolean;
Begin
  IsIdentStart := ((Ch >= 'A') And (Ch <= 'Z')) Or
                  ((Ch >= 'a') And (Ch <= 'z')) Or
                  (Ch = '_');
End;

Function IsIdentCont(Ch : Char) : Boolean;
Begin
  IsIdentCont := IsIdentStart(Ch) Or ((Ch >= '0') And (Ch <= '9'));
End;

Function IsHexDigit(Ch : Char) : Boolean;
Begin
  IsHexDigit := ((Ch >= '0') And (Ch <= '9')) Or
                ((Ch >= 'A') And (Ch <= 'F')) Or
                ((Ch >= 'a') And (Ch <= 'f'));
End;

Function HexVal(Ch : Char) : Integer;
Begin
  If (Ch >= '0') And (Ch <= '9') Then HexVal := Ord(Ch) - Ord('0')
  Else If (Ch >= 'A') And (Ch <= 'F') Then HexVal := Ord(Ch) - Ord('A') + 10
  Else HexVal := Ord(Ch) - Ord('a') + 10;
End;

Function IsKeyword(Const S : TString) : Boolean;
Var
  L : TString;
Begin
  L := StrLowerCase(S);
  IsKeyword :=
    (L = 'and')            Or (L = 'array')      Or (L = 'begin')     Or
    (L = 'case')           Or (L = 'const')      Or (L = 'constructor') Or
    (L = 'destructor')     Or (L = 'div')        Or (L = 'do')        Or
    (L = 'downto')         Or (L = 'else')       Or (L = 'end')       Or
    (L = 'file')           Or (L = 'for')        Or (L = 'forward')   Or
    (L = 'function')       Or (L = 'goto')       Or (L = 'if')        Or
    (L = 'implementation') Or (L = 'in')         Or (L = 'inherited') Or
    (L = 'inline')         Or (L = 'interface')  Or (L = 'label')     Or
    (L = 'mod')            Or (L = 'nil')        Or (L = 'not')       Or
    (L = 'object')         Or (L = 'of')         Or (L = 'or')        Or
    (L = 'packed')         Or (L = 'procedure')  Or (L = 'program')   Or
    (L = 'record')         Or (L = 'repeat')     Or (L = 'set')       Or
    (L = 'shl')            Or (L = 'shr')        Or (L = 'string')    Or
    (L = 'then')           Or (L = 'to')         Or (L = 'type')      Or
    (L = 'unit')           Or (L = 'until')      Or (L = 'uses')      Or
    (L = 'var')            Or (L = 'while')      Or (L = 'with')      Or
    (L = 'xor');
End;

Function IsDirective(Const S : TString) : Boolean;
Var
  L : TString;
Begin
  L := StrLowerCase(S);
  IsDirective :=
    (L = 'absolute')   Or (L = 'assembler')  Or (L = 'external')  Or
    (L = 'far')        Or (L = 'interrupt')  Or (L = 'near')      Or
    (L = 'private')    Or (L = 'public')     Or (L = 'virtual');
End;

Procedure PrintToken(Const T : TToken);
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', T.Line, ',', T.Col, '] ');
  Case T.Kind Of
    TK_EOF       : Write('EOF');
    TK_INTEGER   : Write('INT(', T.IntVal, ')');
    TK_REAL      : Write('REAL(', T.Val, ')');
    TK_STRING    : Write('STR(''', T.Val, ''')');
    TK_CHAR      : Write('CHAR(#', T.IntVal, ')');
    TK_IDENT     : Write('IDENT(', T.Val, ')');
    TK_KEYWORD   : Write('KW(', T.Val, ')');
    TK_OP        : Write('OP(', T.Val, ')');
    TK_PUNCT     : Write('PUNCT(', T.Val, ')');
    TK_DIRECTIVE : Write('DIR(', T.Val, ')');
  End;
  WriteLn;
End;

{ ---- LexNextLine -------------------------------------------- }
Procedure LexNextLine;
Begin
  If LexEOF Then Exit;
  If EOF(LexSrcF) Then
  Begin
    LexEOF   := True;
    LexLine  := '';
    LexColNo := 1;
  End
  Else
  Begin
    ReadLn(LexSrcF, LexLine);
    Inc(LexLineNo);
    Inc(TotalLines);
    LexColNo := 1;
  End;
End;

{ ---- LexInit ------------------------------------------------ }
Procedure LexInit;
Begin
  LexLineNo := 0;
  LexColNo  := 1;
  LexEOF    := False;
  LexLine   := '';
  CurToken.Kind    := TK_EOF;
  CurToken.Val     := '';
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;
  CurToken.Line    := 0;
  CurToken.Col     := 0;
  LexNextLine;
End;

{ ---- LexClose ----------------------------------------------- }
Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
End;

(* ---- LexSkipBraceComment : sauter accolades commentaire --- *)
Procedure LexSkipBraceComment;
Begin
  Inc(LexColNo); (* sauter accolade ouvrante *)
  While Not LexEOF Do
  Begin
    If LexColNo > Length(LexLine) Then
      LexNextLine
    Else If LexLine[LexColNo] = '}' Then
    Begin
      Inc(LexColNo);
      Exit;
    End
    Else
      Inc(LexColNo);
  End;
End;

{ ---- LexSkipParenStarComment : sauter (* ... *) ------------- }
Procedure LexSkipParenStarComment;
Begin
  Inc(LexColNo); Inc(LexColNo); { sauter '(' et '*' }
  While Not LexEOF Do
  Begin
    If LexColNo > Length(LexLine) Then
      LexNextLine
    Else If (LexLine[LexColNo] = '*') And
            (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = ')') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      Exit;
    End
    Else
      Inc(LexColNo);
  End;
End;

{ ---- LexSkipLineComment : sauter // ... -------------------- }
Procedure LexSkipLineComment;
Begin
  LexColNo := Length(LexLine) + 1;
End;

{ ---- LexScanIdent : scanner un identificateur ou mot-cle --- }
Procedure LexScanIdent;
Var
  S : TString;
Begin
  S := '';
  While (LexColNo <= Length(LexLine)) And IsIdentCont(LexLine[LexColNo]) Do
  Begin
    If Length(S) < MAX_STR Then
      S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  CurToken.Val     := S;
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;
  If IsKeyword(S) Then
  Begin
    CurToken.Kind := TK_KEYWORD;
    CurToken.Val  := StrLowerCase(S);
  End
  Else If IsDirective(S) Then
  Begin
    CurToken.Kind := TK_DIRECTIVE;
    CurToken.Val  := StrLowerCase(S);
  End
  Else
    CurToken.Kind := TK_IDENT;
End;

{ ---- LexScanNumber : scanner un litteral numerique --------- }
Procedure LexScanNumber;
Var
  N       : LongInt;
  IsReal  : Boolean;
  NegExp  : Boolean;
  FracDiv : Real;
  FracVal : Real;
  ExpVal  : Integer;
  FltVal  : Real;
Begin
  N       := 0;
  IsReal  := False;
  NegExp  := False;
  FracVal := 0.0;
  FracDiv := 10.0;
  ExpVal  := 0;

  { Scanner la partie entiere decimale }
  While (LexColNo <= Length(LexLine)) And
        (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
  Begin
    N := N * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
    Inc(LexColNo);
  End;

  { Partie decimale .ddd (mais pas '..' qui est le token de plage) }
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '.') And
     (LexColNo < Length(LexLine)) And (LexLine[LexColNo + 1] <> '.') And
     (LexLine[LexColNo + 1] >= '0') And (LexLine[LexColNo + 1] <= '9') Then
  Begin
    IsReal := True;
    Inc(LexColNo); { sauter '.' }
    FracDiv := 10.0;
    FracVal := 0.0;
    While (LexColNo <= Length(LexLine)) And
          (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
    Begin
      FracVal := FracVal + (Ord(LexLine[LexColNo]) - Ord('0')) / FracDiv;
      FracDiv := FracDiv * 10.0;
      Inc(LexColNo);
    End;
  End;

  { Exposant E [+-] ddd }
  If (LexColNo <= Length(LexLine)) And
     ((LexLine[LexColNo] = 'E') Or (LexLine[LexColNo] = 'e')) Then
  Begin
    IsReal := True;
    Inc(LexColNo);
    NegExp := False;
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '-') Then
    Begin
      NegExp := True;
      Inc(LexColNo);
    End
    Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '+') Then
      Inc(LexColNo);
    ExpVal := 0;
    While (LexColNo <= Length(LexLine)) And
          (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
    Begin
      ExpVal := ExpVal * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
      Inc(LexColNo);
    End;
  End;

  If IsReal Then
  Begin
    FltVal := N + FracVal;
    While ExpVal > 0 Do
    Begin
      If NegExp Then FltVal := FltVal / 10.0
      Else           FltVal := FltVal * 10.0;
      Dec(ExpVal);
    End;
    CurToken.Kind    := TK_REAL;
    CurToken.RealVal := FltVal;
    If FltVal > 2147483647.0 Then N := 2147483647
    Else If FltVal < -2147483648.0 Then N := -2147483648
    Else N := Trunc(FltVal);
    CurToken.IntVal := N;
    Str(FltVal:0:6, CurToken.Val);
  End
  Else
  Begin
    CurToken.Kind    := TK_INTEGER;
    CurToken.IntVal  := N;
    CurToken.RealVal := 0.0;
    Str(N, CurToken.Val);
  End;
End;

{ ---- LexScanHexNumber : scanner $FF ------------------------ }
Procedure LexScanHexNumber;
Var
  N : LongInt;
Begin
  Inc(LexColNo); { sauter '$' }
  N := 0;
  While (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Do
  Begin
    N := N * 16 + HexVal(LexLine[LexColNo]);
    Inc(LexColNo);
  End;
  CurToken.Kind    := TK_INTEGER;
  CurToken.IntVal  := N;
  CurToken.RealVal := 0.0;
  Str(N, CurToken.Val);
End;

{ ---- LexScanString : scanner 'chaine' avec '' doublee ------ }
Procedure LexScanString;
Var
  S  : TString;
  Ch : Char;
Begin
  S := '';
  Inc(LexColNo); { sauter quote ouvrante }
  While LexColNo <= Length(LexLine) Do
  Begin
    Ch := LexLine[LexColNo];
    If Ch = '''' Then
    Begin
      Inc(LexColNo);
      { Quote doublee '' -> un seul caractere ' }
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '''') Then
      Begin
        If Length(S) < MAX_STR Then
          S := S + '''';
        Inc(LexColNo);
      End
      Else
        Break; { fin de chaine }
    End
    Else
    Begin
      If Length(S) < MAX_STR Then
        S := S + Ch;
      Inc(LexColNo);
    End;
  End;
  CurToken.Kind    := TK_STRING;
  CurToken.Val     := S;
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;
  { Si chaine de longueur 1, stocker aussi le code ASCII }
  If Length(S) = 1 Then
    CurToken.IntVal := Ord(S[1]);
End;

{ ---- LexScanCharLit : scanner #nn, #$nn, ^X ---------------- }
Procedure LexScanCharLit;
Var
  V : LongInt;
  S : TString;
Begin
  S := '';
  { Scanner une sequence de #nn / #$nn / ^X segments }
  While (LexColNo <= Length(LexLine)) And
        ((LexLine[LexColNo] = '#') Or (LexLine[LexColNo] = '^')) Do
  Begin
    If LexLine[LexColNo] = '#' Then
    Begin
      Inc(LexColNo); { sauter '#' }
      V := 0;
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '$') Then
      Begin
        Inc(LexColNo); { sauter '$' }
        While (LexColNo <= Length(LexLine)) And
              IsHexDigit(LexLine[LexColNo]) Do
        Begin
          V := V * 16 + HexVal(LexLine[LexColNo]);
          Inc(LexColNo);
        End;
      End
      Else
      Begin
        While (LexColNo <= Length(LexLine)) And
              (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
        Begin
          V := V * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
          Inc(LexColNo);
        End;
      End;
      If Length(S) < MAX_STR Then
        S := S + Chr(V And $FF);
    End
    Else { '^' control character }
    Begin
      Inc(LexColNo); { sauter '^' }
      If LexColNo <= Length(LexLine) Then
      Begin
        V := Ord(UpCase(LexLine[LexColNo])) - Ord('@');
        If (V < 0) Or (V > 31) Then V := 0;
        If Length(S) < MAX_STR Then
          S := S + Chr(V);
        Inc(LexColNo);
      End;
    End;
  End;

  { Si suivi d'une chaine 'xxx', concatener }
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '''') Then
  Begin
    Inc(LexColNo); { sauter quote ouvrante }
    While LexColNo <= Length(LexLine) Do
    Begin
      If LexLine[LexColNo] = '''' Then
      Begin
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '''') Then
        Begin
          If Length(S) < MAX_STR Then S := S + '''';
          Inc(LexColNo);
        End
        Else
          Break;
      End
      Else
      Begin
        If Length(S) < MAX_STR Then
          S := S + LexLine[LexColNo];
        Inc(LexColNo);
      End;
    End;
    { Peut etre suivi d'un autre #nn ou ^X }
    While (LexColNo <= Length(LexLine)) And
          ((LexLine[LexColNo] = '#') Or (LexLine[LexColNo] = '^')) Do
    Begin
      If LexLine[LexColNo] = '#' Then
      Begin
        Inc(LexColNo);
        V := 0;
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '$') Then
        Begin
          Inc(LexColNo);
          While (LexColNo <= Length(LexLine)) And
                IsHexDigit(LexLine[LexColNo]) Do
          Begin
            V := V * 16 + HexVal(LexLine[LexColNo]);
            Inc(LexColNo);
          End;
        End
        Else
        Begin
          While (LexColNo <= Length(LexLine)) And
                (LexLine[LexColNo] >= '0') And
                (LexLine[LexColNo] <= '9') Do
          Begin
            V := V * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
            Inc(LexColNo);
          End;
        End;
        If Length(S) < MAX_STR Then
          S := S + Chr(V And $FF);
      End
      Else { '^' }
      Begin
        Inc(LexColNo);
        If LexColNo <= Length(LexLine) Then
        Begin
          V := Ord(UpCase(LexLine[LexColNo])) - Ord('@');
          If (V < 0) Or (V > 31) Then V := 0;
          If Length(S) < MAX_STR Then
            S := S + Chr(V);
          Inc(LexColNo);
        End;
      End;
    End;
  End;

  { Si un seul caractere -> TK_CHAR, sinon TK_STRING }
  If Length(S) = 1 Then
  Begin
    CurToken.Kind   := TK_CHAR;
    CurToken.IntVal := Ord(S[1]);
  End
  Else
  Begin
    CurToken.Kind   := TK_STRING;
    CurToken.IntVal := 0;
  End;
  CurToken.Val     := S;
  CurToken.RealVal := 0.0;
End;

{ ---- LexNextToken : scanner principal ----------------------- }
Procedure LexNextToken;
Var
  Ch       : Char;
  Scanning : Boolean;
  SaveStr  : TString;
Begin
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;

  Scanning := True;
  While Scanning Do
  Begin
    { Avancer a la prochaine ligne si fin de ligne }
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
      LexNextLine;

    { Fin de fichier }
    If LexEOF Then
    Begin
      CurToken.Kind := TK_EOF;
      CurToken.Val  := '';
      CurToken.Line := LexLineNo;
      CurToken.Col  := LexColNo;
      Scanning := False;
      Break;
    End;

    CurToken.Line := LexLineNo;
    CurToken.Col  := LexColNo;
    Ch := LexLine[LexColNo];

    { Espaces blancs }
    If (Ch = ' ') Or (Ch = #9) Or (Ch = #13) Or (Ch = #12) Then
    Begin
      Inc(LexColNo);
    End

    { Commentaire // ligne (TP7+) }
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '/') Then
    Begin
      LexSkipLineComment;
    End

    (* Commentaire accolade *)
    Else If Ch = '{' Then
    Begin
      LexSkipBraceComment;
    End

    { Commentaire (* ... *) ou operateur '(' }
    Else If (Ch = '(') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '*') Then
    Begin
      LexSkipParenStarComment;
    End

    { Entier hexadecimal $FF }
    Else If (Ch = '$') And (LexColNo < Length(LexLine)) And
            IsHexDigit(LexLine[LexColNo + 1]) Then
    Begin
      LexScanHexNumber;
      Scanning := False;
    End

    { Caractere literal #nn ou controle ^X }
    Else If (Ch = '#') Or (Ch = '^') Then
    Begin
      LexScanCharLit;
      Scanning := False;
    End

    { Chaine Pascal 'xxx' }
    Else If Ch = '''' Then
    Begin
      LexScanString;
      { Si suivi de #nn ou ^X -> concatener avec la chaine }
      If (LexColNo <= Length(LexLine)) And
         ((LexLine[LexColNo] = '#') Or (LexLine[LexColNo] = '^')) Then
      Begin
        SaveStr := CurToken.Val;
        LexScanCharLit;
        CurToken.Val  := SaveStr + CurToken.Val;
        CurToken.Kind := TK_STRING;
        CurToken.IntVal := 0;
      End;
      Scanning := False;
    End

    { Identificateur ou mot-cle }
    Else If IsIdentStart(Ch) Then
    Begin
      LexScanIdent;
      Scanning := False;
    End

    { Nombre decimal }
    Else If (Ch >= '0') And (Ch <= '9') Then
    Begin
      LexScanNumber;
      Scanning := False;
    End

    { Operateur d affectation := }
    Else If (Ch = ':') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := ':=';
      Inc(LexColNo, 2);
      Scanning := False;
    End

    { Operateur <> }
    Else If (Ch = '<') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '>') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '<>';
      Inc(LexColNo, 2);
      Scanning := False;
    End

    { Operateur <= }
    Else If (Ch = '<') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '<=';
      Inc(LexColNo, 2);
      Scanning := False;
    End

    { Operateur >= }
    Else If (Ch = '>') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '>=';
      Inc(LexColNo, 2);
      Scanning := False;
    End

    { Token de plage .. }
    Else If (Ch = '.') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '.') Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := '..';
      Inc(LexColNo, 2);
      Scanning := False;
    End

    { Operateurs simples }
    Else If (Ch = '+') Or (Ch = '-') Or (Ch = '*') Or (Ch = '/') Or
            (Ch = '=') Or (Ch = '<') Or (Ch = '>') Or (Ch = '@') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := Ch;
      Inc(LexColNo);
      Scanning := False;
    End

    { Ponctuation }
    Else If (Ch = ';') Or (Ch = ',') Or (Ch = '(') Or (Ch = ')') Or
            (Ch = '[') Or (Ch = ']') Or (Ch = '.') Or (Ch = ':') Or
            (Ch = '^') Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := Ch;
      Inc(LexColNo);
      Scanning := False;
    End

    { Caractere inconnu : avancer et signaler }
    Else
    Begin
      WarnMsg('caractere inattendu: ' + Ch + ' (ord=' +
              IntToStr_(Ord(Ch)) + ')');
      Inc(LexColNo);
    End;
  End;

  PrintToken(CurToken);
End;

{ ============================================================
  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
  ============================================================ }

{ ---- HexByte : octet -> 2 chiffres hexa -------------------- }
Function HexByte(B : Integer) : TString;
Const
  HX : String[16] = '0123456789ABCDEF';
Begin
  HexByte := HX[(B Shr 4) And $F + 1] + HX[B And $F + 1];
End;

{ ---- StrToJS : convertir chaine Pascal -> litteral JS ------- }
{ 'abc' -> "abc"  /  'l''arbre' -> "l'arbre"                   }
{ Caracteres speciaux : #13 -> \r, #10 -> \n, #9 -> \t etc.    }
Function StrToJS(Const S : TString) : TString;
Var
  I : Integer;
  R : TString;
  Ch : Char;
Begin
  R := '"';
  For I := 1 To Length(S) Do
  Begin
    Ch := S[I];
    Case Ch Of
      '"'  : If Length(R) < MAX_STR - 2 Then R := R + '\"';
      '\'  : If Length(R) < MAX_STR - 2 Then R := R + '\\';
      #8   : If Length(R) < MAX_STR - 2 Then R := R + '\b';
      #9   : If Length(R) < MAX_STR - 2 Then R := R + '\t';
      #10  : If Length(R) < MAX_STR - 2 Then R := R + '\n';
      #12  : If Length(R) < MAX_STR - 2 Then R := R + '\f';
      #13  : If Length(R) < MAX_STR - 2 Then R := R + '\r';
      #0   : If Length(R) < MAX_STR - 4 Then R := R + '\x00';
      #26  : If Length(R) < MAX_STR - 4 Then R := R + '\x1A';
    Else
      If (Ord(Ch) < 32) Or (Ord(Ch) > 126) Then
      Begin
        If Length(R) < MAX_STR - 4 Then
          R := R + '\x' + HexByte(Ord(Ch));
      End
      Else
      Begin
        If Length(R) < MAX_STR - 1 Then
          R := R + Ch;
      End;
    End;
  End;
  If Length(R) < MAX_STR Then
    R := R + '"';
  StrToJS := R;
End;

{ ---- CharToJS : convertir code ASCII -> representation JS --- }
{ Caracteres courants retournes comme chaine JS d un caractere  }
{ Caracteres speciaux : #13 -> "\r", #10 -> "\n", etc.         }
Function CharToJS(Code : Integer) : TString;
Begin
  Case Code Of
    8  : CharToJS := '"\b"';
    9  : CharToJS := '"\t"';
    10 : CharToJS := '"\n"';
    12 : CharToJS := '"\f"';
    13 : CharToJS := '"\r"';
    0  : CharToJS := '"\x00"';
    26 : CharToJS := '"\x1A"';
    34 : CharToJS := '"\""';
    92 : CharToJS := '"\\\\"';
  Else
    If (Code >= 32) And (Code <= 126) Then
      CharToJS := '"' + Chr(Code) + '"'
    Else
      CharToJS := 'String.fromCharCode(' + IntToStr_(Code) + ')';
  End;
End;

{ ---- IntToJS : entier -> JavaScript ------------------------- }
Function IntToJS(N : LongInt) : TString;
Begin
  IntToJS := IntToStr_(N);
End;

{ ---- RealToJS : reel -> JavaScript -------------------------- }
Function RealToJS(R : Real) : TString;
Var
  S : TString;
Begin
  Str(R:0:10, S);
  { Supprimer les zeros inutiles a la fin }
  While (Length(S) > 1) And (S[Length(S)] = '0') And
        (S[Length(S) - 1] <> '.') Do
    Delete(S, Length(S), 1);
  RealToJS := S;
End;

{ ---- LitToJS : convertir un token litteral en JavaScript ---- }
{ Dispatche selon le type de token                              }
Function LitToJS(Const T : TToken) : TString;
Var
  L : TString;
Begin
  Case T.Kind Of
    TK_INTEGER : LitToJS := IntToJS(T.IntVal);
    TK_REAL    : LitToJS := RealToJS(T.RealVal);
    TK_STRING  : LitToJS := StrToJS(T.Val);
    TK_CHAR    : LitToJS := CharToJS(T.IntVal);
    TK_KEYWORD :
    Begin
      L := StrLowerCase(T.Val);
      If L = 'true'  Then LitToJS := 'true'
      Else If L = 'false' Then LitToJS := 'false'
      Else If L = 'nil'   Then LitToJS := 'null'
      Else LitToJS := T.Val;
    End;
    TK_IDENT :
    Begin
      L := StrLowerCase(T.Val);
      If L = 'true'  Then LitToJS := 'true'
      Else If L = 'false' Then LitToJS := 'false'
      Else If L = 'nil'   Then LitToJS := 'null'
      Else If L = 'maxint' Then LitToJS := '32767'
      Else If L = 'maxlongint' Then LitToJS := '2147483647'
      Else LitToJS := T.Val;
    End;
  Else
    LitToJS := T.Val;
  End;
End;

{ ---- TokenPoolInit : initialiser le pool de tokens ---------- }
Procedure TokenPoolInit;
Begin
  TokenCount := 0;
End;

{ ---- TokenPoolAdd : ajouter un token au pool ---------------- }
Procedure TokenPoolAdd(Const T : TToken);
Begin
  If TokenCount >= MAX_TOKEN Then
  Begin
    FatalError('pool de tokens sature (MAX_TOKEN=' +
               IntToStr_(MAX_TOKEN) + ')');
    Exit;
  End;
  TokenPool[TokenCount] := T;
  Inc(TokenCount);
End;

{ ---- TokenPoolFill : remplir le pool depuis le lexeur ------- }
{ Lex tous les tokens du fichier et les stocke dans TokenPool.  }
Procedure TokenPoolFill;
Begin
  TokenPoolInit;
  LexNextToken;
  While CurToken.Kind <> TK_EOF Do
  Begin
    TokenPoolAdd(CurToken);
    LexNextToken;
  End;
  { Ajouter le EOF final }
  TokenPoolAdd(CurToken);
End;

{ ---- ConstInit : initialiser la table des constantes -------- }
Procedure ConstInit;
Begin
  ConstCount := 0;
End;

{ ---- ConstAdd : ajouter une constante a la table ------------ }
Procedure ConstAdd(Const AName, AJSVal : TString;
                   AKind : TTokenKind;
                   AIntVal : LongInt; ARealVal : Real;
                   Const AStrVal : TString;
                   AIsTyped : Boolean);
Begin
  If ConstCount >= MAX_CONST Then
  Begin
    CompileError('table des constantes saturee (MAX_CONST=' +
                 IntToStr_(MAX_CONST) + ')');
    Exit;
  End;
  ConstTab[ConstCount].Name    := AName;
  ConstTab[ConstCount].JSVal   := AJSVal;
  ConstTab[ConstCount].Kind    := AKind;
  ConstTab[ConstCount].IntVal  := AIntVal;
  ConstTab[ConstCount].RealVal := ARealVal;
  ConstTab[ConstCount].StrVal  := AStrVal;
  ConstTab[ConstCount].IsTyped := AIsTyped;
  Inc(ConstCount);
End;

{ ---- ConstFind : chercher une constante par nom (insensible) }
{ Retourne l index dans ConstTab ou -1 si introuvable          }
Function ConstFind(Const AName : TString) : Integer;
Var
  I  : Integer;
  LN : TString;
  LC : TString;
Begin
  LN := StrLowerCase(AName);
  For I := 0 To ConstCount - 1 Do
  Begin
    LC := StrLowerCase(ConstTab[I].Name);
    If LC = LN Then
    Begin
      ConstFind := I;
      Exit;
    End;
  End;
  ConstFind := -1;
End;

{ ---- ConstFindIntVal : trouver la valeur entiere d une constante }
{ Retourne la valeur entiere de la constante ou le defaut.         }
Function ConstFindIntVal(Const AName : TString; Def : LongInt) : LongInt;
Var
  Idx : Integer;
Begin
  Idx := ConstFind(AName);
  If Idx >= 0 Then
    ConstFindIntVal := ConstTab[Idx].IntVal
  Else
    ConstFindIntVal := Def;
End;

{ ---- ConstRegisterBuiltins : constantes predefinies --------- }
{ True, False, MaxInt, MaxLongInt, nil                          }
Procedure ConstRegisterBuiltins;
Begin
  ConstAdd('True',       'true',          TK_KEYWORD, 1, 0.0, '', False);
  ConstAdd('False',      'false',         TK_KEYWORD, 0, 0.0, '', False);
  ConstAdd('MaxInt',     '32767',         TK_INTEGER, 32767, 0.0, '', False);
  ConstAdd('MaxLongInt', '2147483647',    TK_INTEGER, 2147483647, 0.0, '', False);
  ConstAdd('nil',        'null',          TK_KEYWORD, 0, 0.0, '', False);
  ConstAdd('Pi',         'Math.PI',       TK_REAL,    3, 3.14159265358979, '', False);
End;

{ ---- ConstEvalAtom : evaluer un atome constant -------------- }
{ Lit un token a la position P dans le TokenPool et retourne    }
{ sa valeur JavaScript. Avance P.                                }
Function ConstEvalAtom(Var P : Integer) : TString;
Var
  Neg  : Boolean;
  Idx  : Integer;
  L    : TString;
  Tmp  : TString;
  Tmp2 : TString;
Begin
  ConstEvalAtom := '0';
  If P >= TokenCount Then Exit;

  { Signe unaire + ou - }
  Neg := False;
  If (TokenPool[P].Kind = TK_OP) And (TokenPool[P].Val = '-') Then
  Begin
    Neg := True;
    Inc(P);
    If P >= TokenCount Then Exit;
  End
  Else If (TokenPool[P].Kind = TK_OP) And (TokenPool[P].Val = '+') Then
  Begin
    Inc(P);
    If P >= TokenCount Then Exit;
  End;

  { NOT unaire }
  If (TokenPool[P].Kind = TK_KEYWORD) And
     (StrLowerCase(TokenPool[P].Val) = 'not') Then
  Begin
    Inc(P);
    Tmp := ConstEvalAtom(P);
    ConstEvalAtom := '!' + Tmp;
    Exit;
  End;

  { Parentheses }
  If (TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = '(') Then
  Begin
    Inc(P);
    Tmp := ConstEvalExpr(P);
    { Consommer ')' }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = ')') Then
      Inc(P);
    If Neg Then
      ConstEvalAtom := '-(' + Tmp + ')'
    Else
      ConstEvalAtom := '(' + Tmp + ')';
    Exit;
  End;

  { Litteral entier }
  If TokenPool[P].Kind = TK_INTEGER Then
  Begin
    If Neg Then
      ConstEvalAtom := IntToStr_(-TokenPool[P].IntVal)
    Else
      ConstEvalAtom := IntToStr_(TokenPool[P].IntVal);
    Inc(P);
    Exit;
  End;

  { Litteral reel }
  If TokenPool[P].Kind = TK_REAL Then
  Begin
    If Neg Then
      ConstEvalAtom := '-' + RealToJS(TokenPool[P].RealVal)
    Else
      ConstEvalAtom := RealToJS(TokenPool[P].RealVal);
    Inc(P);
    Exit;
  End;

  { Litteral chaine }
  If TokenPool[P].Kind = TK_STRING Then
  Begin
    ConstEvalAtom := StrToJS(TokenPool[P].Val);
    Inc(P);
    Exit;
  End;

  { Litteral caractere }
  If TokenPool[P].Kind = TK_CHAR Then
  Begin
    ConstEvalAtom := CharToJS(TokenPool[P].IntVal);
    Inc(P);
    Exit;
  End;

  { Mot-cle booleens / nil }
  If TokenPool[P].Kind = TK_KEYWORD Then
  Begin
    L := StrLowerCase(TokenPool[P].Val);
    If L = 'true'  Then Begin ConstEvalAtom := 'true';  Inc(P); Exit; End;
    If L = 'false' Then Begin ConstEvalAtom := 'false'; Inc(P); Exit; End;
    If L = 'nil'   Then Begin ConstEvalAtom := 'null';  Inc(P); Exit; End;
    { ORD, CHR, etc. traites dans les TODOs suivants }
    ConstEvalAtom := TokenPool[P].Val;
    Inc(P);
    Exit;
  End;

  { Identificateur : chercher dans la table des constantes }
  If TokenPool[P].Kind = TK_IDENT Then
  Begin
    Idx := ConstFind(TokenPool[P].Val);
    If Idx >= 0 Then
    Begin
      If Neg Then
        ConstEvalAtom := '-' + ConstTab[Idx].JSVal
      Else
        ConstEvalAtom := ConstTab[Idx].JSVal;
    End
    Else
    Begin
      If Neg Then
        ConstEvalAtom := '-' + TokenPool[P].Val
      Else
        ConstEvalAtom := TokenPool[P].Val;
    End;
    Inc(P);
    Exit;
  End;

  { Ensemble [elem, elem..elem] }
  If (TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = '[') Then
  Begin
    Tmp := '[';
    Inc(P);
    While (P < TokenCount) And
          Not ((TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = ']')) Do
    Begin
      If (TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = ',') Then
      Begin
        Tmp := Tmp + ', ';
        Inc(P);
      End
      Else If (TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = '..') Then
      Begin
        Tmp := Tmp + '/*..*/';
        Inc(P);
      End
      Else
      Begin
        Tmp2 := LitToJS(TokenPool[P]);
        Tmp := Tmp + Tmp2;
        Inc(P);
      End;
    End;
    Tmp := Tmp + ']';
    If (P < TokenCount) And (TokenPool[P].Val = ']') Then
      Inc(P);
    ConstEvalAtom := Tmp;
    Exit;
  End;

  { Token non reconnu : retourner tel quel }
  ConstEvalAtom := TokenPool[P].Val;
  Inc(P);
End;

{ ---- ConstEvalTerm : niveau 2 (multiplicatif) pour constantes }
{ Gere les operateurs *, /, DIV, MOD, AND, SHL, SHR            }
Function ConstEvalTerm(Var P : Integer) : TString;
Var
  Left : TString;
  Op   : TString;
  Rght : TString;

  Function IsConstLevel2 : Boolean;
  Var LL : TString;
  Begin
    IsConstLevel2 := False;
    If P >= TokenCount Then Exit;
    If TokenPool[P].Kind = TK_OP Then
    Begin
      If (TokenPool[P].Val = '*') Or (TokenPool[P].Val = '/') Then
        IsConstLevel2 := True;
    End
    Else If TokenPool[P].Kind = TK_KEYWORD Then
    Begin
      LL := StrLowerCase(TokenPool[P].Val);
      If (LL = 'div') Or (LL = 'mod') Or (LL = 'and') Or
         (LL = 'shl') Or (LL = 'shr') Then
        IsConstLevel2 := True;
    End;
  End;

Begin
  Left := ConstEvalAtom(P);
  While (P < TokenCount) And IsConstLevel2 Do
  Begin
    Op := StrLowerCase(TokenPool[P].Val);
    Inc(P);
    Rght := ConstEvalAtom(P);

    If Op = '*'        Then Left := Left + ' * '  + Rght
    Else If Op = '/'   Then Left := Left + ' / '  + Rght
    Else If Op = 'div' Then Left := 'Math.trunc(' + Left + ' / ' + Rght + ')'
    Else If Op = 'mod' Then Left := Left + ' % '  + Rght
    Else If Op = 'and' Then
    Begin
      If IsBooleanExpr(Left) Or IsBooleanExpr(Rght) Then
        Left := Left + ' && ' + Rght
      Else
        Left := '(' + Left + ' & ' + Rght + ')';
    End
    Else If Op = 'shl' Then Left := Left + ' << ' + Rght
    Else If Op = 'shr' Then Left := Left + ' >> ' + Rght;
  End;
  ConstEvalTerm := Left;
End;

{ ---- ConstEvalSimple : niveau 3 (additif) pour constantes --- }
{ Gere les operateurs +, -, OR, XOR                             }
Function ConstEvalSimple(Var P : Integer) : TString;
Var
  Left : TString;
  Op   : TString;
  Rght : TString;

  Function IsConstLevel3 : Boolean;
  Var LL : TString;
  Begin
    IsConstLevel3 := False;
    If P >= TokenCount Then Exit;
    If TokenPool[P].Kind = TK_OP Then
    Begin
      If (TokenPool[P].Val = '+') Or (TokenPool[P].Val = '-') Then
        IsConstLevel3 := True;
    End
    Else If TokenPool[P].Kind = TK_KEYWORD Then
    Begin
      LL := StrLowerCase(TokenPool[P].Val);
      If (LL = 'or') Or (LL = 'xor') Then
        IsConstLevel3 := True;
    End;
  End;

Begin
  Left := ConstEvalTerm(P);
  While (P < TokenCount) And IsConstLevel3 Do
  Begin
    Op := StrLowerCase(TokenPool[P].Val);
    Inc(P);
    Rght := ConstEvalTerm(P);

    If Op = '+'        Then Left := Left + ' + ' + Rght
    Else If Op = '-'   Then Left := Left + ' - ' + Rght
    Else If Op = 'or' Then
    Begin
      If IsBooleanExpr(Left) Or IsBooleanExpr(Rght) Then
        Left := Left + ' || ' + Rght
      Else
        Left := '(' + Left + ' | ' + Rght + ')';
    End
    Else If Op = 'xor' Then Left := Left + ' ^ ' + Rght;
  End;
  ConstEvalSimple := Left;
End;

{ ---- ConstEvalExpr : niveau 4 (relationnel) pour constantes -- }
{ Gere les operateurs =, <>, <, >, <=, >=, IN                   }
{ Retourne la representation JavaScript de l expression          }
Function ConstEvalExpr;
Var
  Left : TString;
  Op   : TString;
  Rght : TString;

  Function IsConstLevel4 : Boolean;
  Var LL : TString;
  Begin
    IsConstLevel4 := False;
    If P >= TokenCount Then Exit;
    If TokenPool[P].Kind = TK_OP Then
    Begin
      If (TokenPool[P].Val = '=') Or (TokenPool[P].Val = '<>') Or
         (TokenPool[P].Val = '<') Or (TokenPool[P].Val = '>') Or
         (TokenPool[P].Val = '<=') Or (TokenPool[P].Val = '>=') Then
        IsConstLevel4 := True;
    End
    Else If TokenPool[P].Kind = TK_KEYWORD Then
    Begin
      LL := StrLowerCase(TokenPool[P].Val);
      If LL = 'in' Then IsConstLevel4 := True;
    End;
  End;

Begin
  Left := ConstEvalSimple(P);
  While (P < TokenCount) And IsConstLevel4 Do
  Begin
    Op := StrLowerCase(TokenPool[P].Val);
    Inc(P);
    Rght := ConstEvalSimple(P);

    If Op = '='        Then Left := Left + ' === ' + Rght
    Else If Op = '<>'  Then Left := Left + ' !== ' + Rght
    Else If Op = '<'   Then Left := Left + ' < '   + Rght
    Else If Op = '>'   Then Left := Left + ' > '   + Rght
    Else If Op = '<='  Then Left := Left + ' <= '  + Rght
    Else If Op = '>='  Then Left := Left + ' >= '  + Rght
    Else If Op = 'in'  Then Left := Rght + '.indexOf(' + Left + ') >= 0';
  End;
  ConstEvalExpr := Left;
End;

{ ============================================================
  TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
  ============================================================ }

{ ---- OpToJS : convertir operateur Pascal en JavaScript ------ }
{ Retourne la representation JavaScript de l operateur Pascal.  }
{ DIV -> Math.trunc(a / b), MOD -> %, = -> ===, <> -> !==,     }
{ AND -> &&, OR -> ||, NOT -> !, XOR -> ^, SHL -> <<, SHR -> >>}
{ := -> =                                                        }
Function OpToJS(Const Op : TString) : TString;
Var
  L : TString;
Begin
  L := StrLowerCase(Op);
  If L = ':='       Then OpToJS := ' = '
  Else If L = '='   Then OpToJS := ' === '
  Else If L = '<>'  Then OpToJS := ' !== '
  Else If L = '<'   Then OpToJS := ' < '
  Else If L = '>'   Then OpToJS := ' > '
  Else If L = '<='  Then OpToJS := ' <= '
  Else If L = '>='  Then OpToJS := ' >= '
  Else If L = '+'   Then OpToJS := ' + '
  Else If L = '-'   Then OpToJS := ' - '
  Else If L = '*'   Then OpToJS := ' * '
  Else If L = '/'   Then OpToJS := ' / '
  Else If L = 'div' Then OpToJS := ' div '
  Else If L = 'mod' Then OpToJS := ' % '
  Else If L = 'and' Then OpToJS := ' && '
  Else If L = 'or'  Then OpToJS := ' || '
  Else If L = 'not' Then OpToJS := '!'
  Else If L = 'xor' Then OpToJS := ' ^ '
  Else If L = 'shl' Then OpToJS := ' << '
  Else If L = 'shr' Then OpToJS := ' >> '
  Else If L = 'in'  Then OpToJS := ' in '
  Else If L = '@'   Then OpToJS := '@'
  Else OpToJS := ' ' + Op + ' ';
End;

{ ============================================================
  TODO 11 - EXPRESSIONS BINAIRES ET UNAIRES [IMPLEMENTE]
  ============================================================ }
{ Distinction bitwise vs logique pour AND/OR/NOT.               }
{ IsBooleanExpr : heuristique detectant si une expression       }
{ generee est booleenne. Utilise pour choisir entre && et &,    }
{ || et |, ! et ~ selon le contexte.                            }
{ Correction du bug ConstEvalAtom : parentheses utilisant       }
{ ConstEvalExpr pour evaluer les sous-expressions completes.    }
{ Ajout de l operateur AS pour le typage objet Turbo Pascal.    }

{ ---- IsBooleanExpr : detecte si l expression JS est booleenne }
{ Retourne True si l expression semble etre une comparaison,    }
{ un litteral booleen, ou contient des operateurs logiques.     }
{ Utilise pour choisir && vs & et || vs | dans AND/OR.          }
Function IsBooleanExpr(Const S : TString) : Boolean;
Var
  R : Boolean;
Begin
  R :=
    (Pos(' === ', S) > 0) Or
    (Pos(' !== ', S) > 0) Or
    (Pos(' >= ', S) > 0) Or
    (Pos(' <= ', S) > 0) Or
    (Pos(' && ', S) > 0) Or
    (Pos(' || ', S) > 0) Or
    (S = 'true') Or (S = 'false') Or
    ((Length(S) >= 2) And (S[1] = '(') And (S[2] = '!'));
  { Detecter < et > simples (sans << et >>) }
  If Not R Then
    If (Pos(' > ', S) > 0) And (Pos(' >> ', S) = 0) Then
      R := True;
  If Not R Then
    If (Pos(' < ', S) > 0) And (Pos(' << ', S) = 0) Then
      R := True;
  If Not R Then
    If (Pos('.indexOf(', S) > 0) And (Pos(') >= 0', S) > 0) Then
      R := True;
  IsBooleanExpr := R;
End;

{ ---- IsLevel2Op : niveau 2 de precedence Pascal ------------- }
{ Operateurs multiplicatifs : * / DIV MOD AND SHL SHR           }
Function IsLevel2Op(Const T : TToken) : Boolean;
Var
  L : TString;
Begin
  IsLevel2Op := False;
  If T.Kind = TK_OP Then
  Begin
    If (T.Val = '*') Or (T.Val = '/') Then
      IsLevel2Op := True;
  End
  Else If T.Kind = TK_KEYWORD Then
  Begin
    L := StrLowerCase(T.Val);
    If (L = 'div') Or (L = 'mod') Or (L = 'and') Or
       (L = 'shl') Or (L = 'shr') Then
      IsLevel2Op := True;
  End;
End;

{ ---- IsLevel3Op : niveau 3 de precedence Pascal ------------- }
{ Operateurs additifs : + - OR XOR                               }
Function IsLevel3Op(Const T : TToken) : Boolean;
Var
  L : TString;
Begin
  IsLevel3Op := False;
  If T.Kind = TK_OP Then
  Begin
    If (T.Val = '+') Or (T.Val = '-') Then
      IsLevel3Op := True;
  End
  Else If T.Kind = TK_KEYWORD Then
  Begin
    L := StrLowerCase(T.Val);
    If (L = 'or') Or (L = 'xor') Then
      IsLevel3Op := True;
  End;
End;

{ ---- IsLevel4Op : niveau 4 de precedence Pascal ------------- }
{ Operateurs relationnels : = <> < > <= >= IN                    }
Function IsLevel4Op(Const T : TToken) : Boolean;
Var
  L : TString;
Begin
  IsLevel4Op := False;
  If T.Kind = TK_OP Then
  Begin
    If (T.Val = '=') Or (T.Val = '<>') Or (T.Val = '<') Or
       (T.Val = '>') Or (T.Val = '<=') Or (T.Val = '>=') Then
      IsLevel4Op := True;
  End
  Else If T.Kind = TK_KEYWORD Then
  Begin
    L := StrLowerCase(T.Val);
    If (L = 'in') Or (L = 'as') Then
      IsLevel4Op := True;
  End;
End;

{ ============================================================
  TODO 10 - EXPRESSIONS PRIMAIRES [IMPLEMENTE]
  ============================================================ }
{ Transtypage, acces chaine/tableau, fonctions standard,         }
{ constantes predefinies, appels de methode objet.               }

{ ---- IsTypeCastName : retourne vrai si le nom est un type ---- }
{ connu pouvant servir de transtypage : Integer(x), Char(x)...   }
Function IsTypeCastName(Const AName : TString) : Boolean;
Var
  L : TString;
Begin
  L := StrLowerCase(AName);
  IsTypeCastName := (L = 'integer') Or (L = 'word') Or (L = 'byte') Or
                    (L = 'shortint') Or (L = 'longint') Or (L = 'char') Or
                    (L = 'boolean') Or (L = 'string') Or (L = 'comp');
End;

{ ---- EmitTypeCast : genere le transtypage en JS -------------- }
{ Integer(x) -> (x | 0), Char(x) -> String.fromCharCode(x)...   }
Function EmitTypeCast(Const AType : TString; Const AExpr : TString) : TString;
Var
  L : TString;
Begin
  L := StrLowerCase(AType);
  If (L = 'integer') Or (L = 'shortint') Or (L = 'longint') Or
     (L = 'comp') Then
    EmitTypeCast := '(' + AExpr + ' | 0)'
  Else If L = 'byte' Then
    EmitTypeCast := '((' + AExpr + ') & 0xFF)'
  Else If L = 'word' Then
    EmitTypeCast := '((' + AExpr + ') & 0xFFFF)'
  Else If L = 'char' Then
    EmitTypeCast := 'String.fromCharCode(' + AExpr + ')'
  Else If L = 'boolean' Then
    EmitTypeCast := '(!!(' + AExpr + '))'
  Else If L = 'string' Then
    EmitTypeCast := 'String(' + AExpr + ')'
  Else
    EmitTypeCast := AExpr;
End;

{ ---- IsBuiltinFunc : retourne vrai si le nom est une         }
{ fonction standard de Turbo Pascal necessitant une traduction  }
{ speciale en JavaScript.                                       }
Function IsBuiltinFunc(Const AName : TString) : Boolean;
Var
  L : TString;
Begin
  L := StrLowerCase(AName);
  IsBuiltinFunc := (L = 'ord') Or (L = 'chr') Or (L = 'length') Or
                   (L = 'abs') Or (L = 'sqr') Or (L = 'sqrt') Or
                   (L = 'pred') Or (L = 'succ') Or (L = 'round') Or
                   (L = 'trunc') Or (L = 'odd') Or (L = 'upcase') Or
                   (L = 'lo') Or (L = 'hi') Or (L = 'pos') Or
                   (L = 'copy') Or (L = 'concat') Or (L = 'sizeof') Or
                   (L = 'inc') Or (L = 'dec') Or (L = 'random') Or
                   (L = 'int') Or (L = 'frac') Or (L = 'sin') Or
                   (L = 'cos') Or (L = 'arctan') Or (L = 'ln') Or
                   (L = 'exp') Or (L = 'pi') Or (L = 'str') Or
                   (L = 'val') Or (L = 'halt') Or (L = 'exit') Or
                   (L = 'high') Or (L = 'low') Or (L = 'assigned') Or
                   (L = 'swap');
End;

{ ---- EmitBuiltinCall : genere l appel de fonction standard --- }
{ Convertit les fonctions standard TP en equivalent JavaScript.  }
Function EmitBuiltinCall(Const AName : TString;
                          Var P : Integer) : TString;
Var
  L     : TString;
  Arg1  : TString;
  Arg2  : TString;
  Arg3  : TString;
  Args  : TString;
Begin
  L := StrLowerCase(AName);
  EmitBuiltinCall := AName + '()';

  { Fonctions sans arguments }
  If L = 'pi' Then
  Begin
    { Pi peut etre appele sans parentheses }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = '(') Then
    Begin
      Inc(P); { ( }
      If (P < TokenCount) And (TokenPool[P].Val = ')') Then
        Inc(P); { ) }
    End;
    EmitBuiltinCall := 'Math.PI';
    Exit;
  End;

  If L = 'random' Then
  Begin
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = '(') Then
    Begin
      Inc(P);
      If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
         (TokenPool[P].Val = ')') Then
      Begin
        Inc(P);
        EmitBuiltinCall := 'Math.random()';
        Exit;
      End;
      Arg1 := ParseExpr(P);
      If (P < TokenCount) And (TokenPool[P].Val = ')') Then
        Inc(P);
      EmitBuiltinCall := 'Math.floor(Math.random() * ' + Arg1 + ')';
      Exit;
    End;
    EmitBuiltinCall := 'Math.random()';
    Exit;
  End;

  If L = 'halt' Then
  Begin
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = '(') Then
    Begin
      Inc(P);
      If (P < TokenCount) And Not ((TokenPool[P].Kind = TK_PUNCT) And
         (TokenPool[P].Val = ')')) Then
        Arg1 := ParseExpr(P)
      Else
        Arg1 := '0';
      If (P < TokenCount) And (TokenPool[P].Val = ')') Then
        Inc(P);
    End
    Else
      Arg1 := '0';
    EmitBuiltinCall := 'process.exit(' + Arg1 + ')';
    Exit;
  End;

  If L = 'exit' Then
  Begin
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = '(') Then
    Begin
      Inc(P);
      If (P < TokenCount) And (TokenPool[P].Val = ')') Then
        Inc(P);
    End;
    EmitBuiltinCall := 'return';
    Exit;
  End;

  { Fonctions avec un argument obligatoire entre parentheses }
  If Not ((P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
          (TokenPool[P].Val = '(')) Then
  Begin
    EmitBuiltinCall := AName;
    Exit;
  End;
  Inc(P); { consommer ( }

  Arg1 := ParseExpr(P);

  { Fonctions a 1 argument }
  If L = 'ord' Then
  Begin
    If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    EmitBuiltinCall := Arg1 + '.charCodeAt(0)';
    Exit;
  End;

  If L = 'chr' Then
  Begin
    If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    EmitBuiltinCall := 'String.fromCharCode(' + Arg1 + ')';
    Exit;
  End;

  If L = 'length' Then
  Begin
    If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    EmitBuiltinCall := Arg1 + '.length';
    Exit;
  End;

  If L = 'abs' Then
  Begin
    If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    EmitBuiltinCall := 'Math.abs(' + Arg1 + ')';
    Exit;
  End;

  If L = 'sqr' Then
  Begin
    If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    EmitBuiltinCall := '(' + Arg1 + ' * ' + Arg1 + ')';
    Exit;
  End;

  If L = 'sqrt' Then
  Begin
    If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    EmitBuiltinCall := 'Math.sqrt(' + Arg1 + ')';
    Exit;
  End;

  If L = 'pred' Then
  Begin
    If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    EmitBuiltinCall := '(' + Arg1 + ' - 1)';
    Exit;
  End;

  If L = 'succ' Then
  Begin
    If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    EmitBuiltinCall := '(' + Arg1 + ' + 1)';
    Exit;
  End;

  If L = 'round' Then
  Begin
    If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    EmitBuiltinCall := 'Math.round(' + Arg1 + ')';
    Exit;
  End;

  If (L = 'trunc') Or (L = 'int') Then
  Begin
    If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    EmitBuiltinCall := 'Math.trunc(' + Arg1 + ')';
    Exit;
  End;

  If L = 'frac' Then
  Begin
    If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    EmitBuiltinCall := '(' + Arg1 + ' - Math.trunc(' + Arg1 + '))';
    Exit;
  End;

  If L = 'odd' Then
  Begin
    If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    EmitBuiltinCall := '((' + Arg1 + ' & 1) !== 0)';
    Exit;
  End;

  If L = 'upcase' Then
  Begin
    If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    EmitBuiltinCall := Arg1 + '.toUpperCase()';
    Exit;
  End;

  If L = 'lo' Then
  Begin
    If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    EmitBuiltinCall := '((' + Arg1 + ') & 0xFF)';
    Exit;
  End;

  If L = 'hi' Then
  Begin
    If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    EmitBuiltinCall := '((' + Arg1 + ' >> 8) & 0xFF)';
    Exit;
  End;

  If L = 'swap' Then
  Begin
    If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    EmitBuiltinCall := '(((' + Arg1 + ' & 0xFF) << 8) | ((' + Arg1 +
                       ' >> 8) & 0xFF))';
    Exit;
  End;

  If L = 'sin' Then
  Begin
    If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    EmitBuiltinCall := 'Math.sin(' + Arg1 + ')';
    Exit;
  End;

  If L = 'cos' Then
  Begin
    If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    EmitBuiltinCall := 'Math.cos(' + Arg1 + ')';
    Exit;
  End;

  If L = 'arctan' Then
  Begin
    If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    EmitBuiltinCall := 'Math.atan(' + Arg1 + ')';
    Exit;
  End;

  If L = 'ln' Then
  Begin
    If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    EmitBuiltinCall := 'Math.log(' + Arg1 + ')';
    Exit;
  End;

  If L = 'exp' Then
  Begin
    If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    EmitBuiltinCall := 'Math.exp(' + Arg1 + ')';
    Exit;
  End;

  If L = 'sizeof' Then
  Begin
    If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    EmitBuiltinCall := '/* sizeof */ 0';
    Exit;
  End;

  If L = 'assigned' Then
  Begin
    If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    EmitBuiltinCall := '(' + Arg1 + ' !== null)';
    Exit;
  End;

  If (L = 'high') Or (L = 'low') Then
  Begin
    If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    If L = 'high' Then
      EmitBuiltinCall := '(' + Arg1 + '.length - 1)'
    Else
      EmitBuiltinCall := '0';
    Exit;
  End;

  If L = 'inc' Then
  Begin
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = ',') Then
    Begin
      Inc(P);
      Arg2 := ParseExpr(P);
      If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
      EmitBuiltinCall := Arg1 + ' += ' + Arg2;
    End
    Else
    Begin
      If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
      EmitBuiltinCall := Arg1 + '++';
    End;
    Exit;
  End;

  If L = 'dec' Then
  Begin
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = ',') Then
    Begin
      Inc(P);
      Arg2 := ParseExpr(P);
      If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
      EmitBuiltinCall := Arg1 + ' -= ' + Arg2;
    End
    Else
    Begin
      If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
      EmitBuiltinCall := Arg1 + '--';
    End;
    Exit;
  End;

  { Fonctions a 2+ arguments }
  If L = 'pos' Then
  Begin
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = ',') Then
    Begin
      Inc(P);
      Arg2 := ParseExpr(P);
    End
    Else
      Arg2 := '""';
    If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    EmitBuiltinCall := '(' + Arg2 + '.indexOf(' + Arg1 + ') + 1)';
    Exit;
  End;

  If L = 'copy' Then
  Begin
    Arg2 := '0'; Arg3 := '';
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = ',') Then
    Begin
      Inc(P);
      Arg2 := ParseExpr(P);
    End;
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = ',') Then
    Begin
      Inc(P);
      Arg3 := ParseExpr(P);
    End;
    If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    EmitBuiltinCall := Arg1 + '.substr((' + Arg2 + ') - 1, ' + Arg3 + ')';
    Exit;
  End;

  If L = 'concat' Then
  Begin
    Args := Arg1;
    While (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
          (TokenPool[P].Val = ',') Do
    Begin
      Inc(P);
      Args := Args + ' + ' + ParseExpr(P);
    End;
    If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    EmitBuiltinCall := '(' + Args + ')';
    Exit;
  End;

  If L = 'str' Then
  Begin
    { Str(expr[:Width[:Decs]], VarDest) }
    { Verifier si un format :Width suit le premier argument }
    Args := ''; Arg2 := ''; Arg3 := '';
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = ':') Then
    Begin
      Inc(P); { consommer : }
      Arg2 := ParseExpr(P); { Width }
      If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
         (TokenPool[P].Val = ':') Then
      Begin
        Inc(P); { consommer : }
        Arg3 := ParseExpr(P); { Decimals }
      End;
    End;
    { Lire la variable destination apres la virgule }
    Args := '';
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = ',') Then
    Begin
      Inc(P);
      Args := ParseExpr(P);
    End;
    If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    { Generer le code JS }
    If (Arg2 <> '') And (Arg3 <> '') Then
    Begin
      { Str(X:W:D, S) -> S = X.toFixed(D).padStart(W) }
      If Args <> '' Then
        EmitBuiltinCall := Args + ' = ' + Arg1 + '.toFixed(' + Arg3 +
                           ').padStart(' + Arg2 + ')'
      Else
        EmitBuiltinCall := Arg1 + '.toFixed(' + Arg3 + ').padStart(' +
                           Arg2 + ')';
    End
    Else If Arg2 <> '' Then
    Begin
      { Str(X:W, S) -> S = String(X).padStart(W) }
      If Args <> '' Then
        EmitBuiltinCall := Args + ' = String(' + Arg1 + ').padStart(' +
                           Arg2 + ')'
      Else
        EmitBuiltinCall := 'String(' + Arg1 + ').padStart(' + Arg2 + ')';
    End
    Else If Args <> '' Then
      EmitBuiltinCall := Args + ' = String(' + Arg1 + ')'
    Else
      EmitBuiltinCall := 'String(' + Arg1 + ')';
    Exit;
  End;

  If L = 'val' Then
  Begin
    { Val(S, X, Code) -> X = Number(S); Code = isNaN(X) ? 1 : 0 }
    Arg2 := ''; Arg3 := '';
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = ',') Then
    Begin
      Inc(P);
      Arg2 := ParseExpr(P);
    End;
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = ',') Then
    Begin
      Inc(P);
      Arg3 := ParseExpr(P);
    End;
    If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
    If (Arg2 <> '') And (Arg3 <> '') Then
      { Val(S, X, Code) : set both X and Code }
      EmitBuiltinCall := '(function() { ' + Arg2 + ' = Number(' + Arg1 +
                         '); ' + Arg3 + ' = isNaN(' + Arg2 + ') ? 1 : 0; })()'
    Else If Arg2 <> '' Then
      EmitBuiltinCall := Arg2 + ' = Number(' + Arg1 + ')'
    Else
      EmitBuiltinCall := 'Number(' + Arg1 + ')';
    Exit;
  End;

  { Fallback : appel generique }
  Args := Arg1;
  While (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
        (TokenPool[P].Val = ',') Do
  Begin
    Inc(P);
    Args := Args + ', ' + ParseExpr(P);
  End;
  If (P < TokenCount) And (TokenPool[P].Val = ')') Then Inc(P);
  EmitBuiltinCall := AName + '(' + Args + ')';
End;

{ ---- GetVarTypeKind : retourne le TTypeKind d une variable --- }
{ Cherche le symbole dans la table et retourne son TypeKind.     }
{ Retourne TYK_INTEGER par defaut si non trouve.                 }
Function GetVarTypeKind(Const AName : TString) : TTypeKind;
Var
  SI  : Integer;
  TI  : Integer;
Begin
  GetVarTypeKind := TYK_INTEGER;
  SI := SymFind(AName);
  If SI < 0 Then Exit;
  TI := SymTab[SI].TypeIdx;
  If (TI < 0) Or (TI >= TypeCount) Then Exit;
  GetVarTypeKind := TypeTab[TI].Kind;
End;

{ ---- GetArrayLowBound : retourne la borne inf d un tableau --- }
{ Retourne 0 par defaut si le symbole n est pas un tableau.      }
Function GetArrayLowBound(Const AName : TString) : LongInt;
Var
  SI  : Integer;
  TI  : Integer;
Begin
  GetArrayLowBound := 0;
  SI := SymFind(AName);
  If SI < 0 Then Exit;
  TI := SymTab[SI].TypeIdx;
  If (TI < 0) Or (TI >= TypeCount) Then Exit;
  If TypeTab[TI].Kind = TYK_ARRAY Then
    GetArrayLowBound := TypeTab[TI].Low;
End;

{ ---- ParseExprFactor : niveau 1 (le plus fort) -------------- }
{ NOT, @, unaire +/-, atomes (litteraux, idents, parentheses)   }
{ TODO 10 : transtypage, fonctions standard, acces chaine/tab.  }
Function ParseExprFactor(Var P : Integer) : TString;
Var
  Tmp    : TString;
  Idx    : Integer;
  L      : TString;
  Tmp2   : TString;
  IdName : TString;
  VTK    : TTypeKind;
  ALow   : LongInt;
Begin
  ParseExprFactor := '0';
  If P >= TokenCount Then Exit;

  { NOT unaire : ! (logique) ou ~ (bitwise) selon le contexte }
  If (TokenPool[P].Kind = TK_KEYWORD) And
     (StrLowerCase(TokenPool[P].Val) = 'not') Then
  Begin
    Inc(P);
    { Pre-detection du contexte : variable Boolean ? }
    VTK := TYK_INTEGER;
    If (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Then
      VTK := GetVarTypeKind(TokenPool[P].Val);
    Tmp := ParseExprFactor(P);
    If (VTK = TYK_BOOLEAN) Or IsBooleanExpr(Tmp) Then
      ParseExprFactor := '(!' + Tmp + ')'
    Else
      ParseExprFactor := '(~' + Tmp + ')';
    Exit;
  End;

  { @ operateur d adresse -> reference en JS }
  If (TokenPool[P].Kind = TK_OP) And (TokenPool[P].Val = '@') Then
  Begin
    Inc(P);
    Tmp := ParseExprFactor(P);
    ParseExprFactor := Tmp;
    Exit;
  End;

  { Unaire - }
  If (TokenPool[P].Kind = TK_OP) And (TokenPool[P].Val = '-') Then
  Begin
    Inc(P);
    Tmp := ParseExprFactor(P);
    ParseExprFactor := '(-' + Tmp + ')';
    Exit;
  End;

  { Unaire + }
  If (TokenPool[P].Kind = TK_OP) And (TokenPool[P].Val = '+') Then
  Begin
    Inc(P);
    Tmp := ParseExprFactor(P);
    ParseExprFactor := Tmp;
    Exit;
  End;

  { Parentheses }
  If (TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = '(') Then
  Begin
    Inc(P);
    Tmp := ParseExpr(P);
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = ')') Then
      Inc(P);
    ParseExprFactor := '(' + Tmp + ')';
    Exit;
  End;

  { Litteral entier }
  If TokenPool[P].Kind = TK_INTEGER Then
  Begin
    ParseExprFactor := IntToJS(TokenPool[P].IntVal);
    Inc(P);
    Exit;
  End;

  { Litteral reel }
  If TokenPool[P].Kind = TK_REAL Then
  Begin
    ParseExprFactor := RealToJS(TokenPool[P].RealVal);
    Inc(P);
    Exit;
  End;

  { Litteral chaine }
  If TokenPool[P].Kind = TK_STRING Then
  Begin
    ParseExprFactor := StrToJS(TokenPool[P].Val);
    Inc(P);
    Exit;
  End;

  { Litteral caractere }
  If TokenPool[P].Kind = TK_CHAR Then
  Begin
    ParseExprFactor := CharToJS(TokenPool[P].IntVal);
    Inc(P);
    Exit;
  End;

  { Mot-cle : true/false/nil }
  If TokenPool[P].Kind = TK_KEYWORD Then
  Begin
    L := StrLowerCase(TokenPool[P].Val);
    If L = 'true'  Then Begin ParseExprFactor := 'true';  Inc(P); Exit; End;
    If L = 'false' Then Begin ParseExprFactor := 'false'; Inc(P); Exit; End;
    If L = 'nil'   Then Begin ParseExprFactor := 'null';  Inc(P); Exit; End;

    { INHERITED : appel methode parent -> super.method() (TODO 17) }
    If L = 'inherited' Then
    Begin
      Inc(P); { consommer INHERITED }
      Tmp := 'super';
      { Verifier si un nom de methode suit }
      If (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Then
      Begin
        Tmp := Tmp + '.' + TokenPool[P].Val;
        Inc(P);
        { Verifier si des arguments suivent }
        If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
           (TokenPool[P].Val = '(') Then
        Begin
          Inc(P); { consommer ( }
          Tmp2 := '';
          While (P < TokenCount) And
                Not ((TokenPool[P].Kind = TK_PUNCT) And
                     (TokenPool[P].Val = ')')) Do
          Begin
            If (TokenPool[P].Kind = TK_PUNCT) And
               (TokenPool[P].Val = ',') Then
            Begin
              Tmp2 := Tmp2 + ', ';
              Inc(P);
            End
            Else
              Tmp2 := Tmp2 + ParseExpr(P);
          End;
          If (P < TokenCount) And (TokenPool[P].Val = ')') Then
            Inc(P);
          Tmp := Tmp + '(' + Tmp2 + ')';
        End
        Else
          Tmp := Tmp + '()';
      End;
      ParseExprFactor := Tmp;
      Exit;
    End;

    { Mot-cle String utilise comme transtypage : String(expr) }
    If L = 'string' Then
    Begin
      If (P + 1 < TokenCount) And (TokenPool[P + 1].Kind = TK_PUNCT) And
         (TokenPool[P + 1].Val = '(') Then
      Begin
        IdName := TokenPool[P].Val;
        Inc(P); Inc(P); { consommer String ( }
        Tmp := ParseExpr(P);
        If (P < TokenCount) And (TokenPool[P].Val = ')') Then
          Inc(P);
        ParseExprFactor := EmitTypeCast(IdName, Tmp);
        Exit;
      End;
    End;

    ParseExprFactor := TokenPool[P].Val;
    Inc(P);
    Exit;
  End;

  { Ensemble [elem, elem..elem] }
  If (TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = '[') Then
  Begin
    Tmp := '[';
    Inc(P);
    While (P < TokenCount) And
          Not ((TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = ']')) Do
    Begin
      If (TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = ',') Then
      Begin
        Tmp := Tmp + ', ';
        Inc(P);
      End
      Else If (TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = '..') Then
      Begin
        Tmp := Tmp + '/*..*/';
        Inc(P);
      End
      Else
      Begin
        Tmp2 := LitToJS(TokenPool[P]);
        Tmp := Tmp + Tmp2;
        Inc(P);
      End;
    End;
    Tmp := Tmp + ']';
    If (P < TokenCount) And (TokenPool[P].Val = ']') Then
      Inc(P);
    ParseExprFactor := Tmp;
    Exit;
  End;

  { Identificateur }
  If TokenPool[P].Kind = TK_IDENT Then
  Begin
    IdName := TokenPool[P].Val;
    L := StrLowerCase(IdName);

    { Transtypage : Integer(expr), Byte(expr), Char(expr), etc. }
    If IsTypeCastName(IdName) And (P + 1 < TokenCount) And
       (TokenPool[P + 1].Kind = TK_PUNCT) And
       (TokenPool[P + 1].Val = '(') Then
    Begin
      Inc(P); Inc(P); { consommer TypeName ( }
      Tmp := ParseExpr(P);
      If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
         (TokenPool[P].Val = ')') Then
        Inc(P);
      ParseExprFactor := EmitTypeCast(IdName, Tmp);
      Exit;
    End;

    { Fonctions standard : Ord, Chr, Length, Abs, etc. }
    { Verifier d abord si c est un symbole utilisateur (TODO 15) }
    { Les procs/funcs decl par l utilisateur (index >= BuiltinSymEnd) }
    { ont priorite sur les builtins.                                }
    If IsBuiltinFunc(IdName) Then
    Begin
      Idx := SymFind(IdName);
      If (Idx >= BuiltinSymEnd) And
         ((SymTab[Idx].Kind = SK_PROC) Or (SymTab[Idx].Kind = SK_FUNC)) Then
      Begin
        { Symbole utilisateur proc/func : priorite sur builtins }
      End
      Else
      Begin
        Inc(P); { consommer le nom de la fonction }
        ParseExprFactor := EmitBuiltinCall(IdName, P);
        Exit;
      End;
    End;

    { Constante utilisateur ou predefinie }
    Idx := ConstFind(IdName);
    If Idx >= 0 Then
      Tmp := ConstTab[Idx].JSVal
    Else
    Begin
      If L = 'true'  Then Tmp := 'true'
      Else If L = 'false' Then Tmp := 'false'
      Else If L = 'nil'   Then Tmp := 'null'
      Else If L = 'maxint' Then Tmp := '32767'
      Else If L = 'maxlongint' Then Tmp := '2147483647'
      Else
        Tmp := IdName;
    End;
    Inc(P);

    { Postfixes : appel de fonction, acces tableau, acces champ }
    While P < TokenCount Do
    Begin
      { Appel de fonction : ident(args) }
      If (TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = '(') Then
      Begin
        Inc(P); { consommer ( }
        Tmp2 := '';
        While (P < TokenCount) And
              Not ((TokenPool[P].Kind = TK_PUNCT) And
                   (TokenPool[P].Val = ')')) Do
        Begin
          If (TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = ',') Then
          Begin
            Tmp2 := Tmp2 + ', ';
            Inc(P);
          End
          Else
            Tmp2 := Tmp2 + ParseExpr(P);
        End;
        If (P < TokenCount) And (TokenPool[P].Val = ')') Then
          Inc(P);
        Tmp := Tmp + '(' + Tmp2 + ')';
      End
      { Acces index : ident[expr] avec ajustement selon le type }
      Else If (TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = '[') Then
      Begin
        Inc(P); { consommer [ }
        Tmp2 := ParseExpr(P);
        If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
           (TokenPool[P].Val = ']') Then
          Inc(P);

        { Acces caractere de chaine : S[i] -> S.charAt((i) - 1) }
        VTK := GetVarTypeKind(IdName);
        If (VTK = TYK_STRING) Or (VTK = TYK_PCHAR) Then
          Tmp := Tmp + '.charAt((' + Tmp2 + ') - 1)'
        { Acces tableau avec base non-zero : Arr[i] -> Arr[(i) - base] }
        Else If VTK = TYK_ARRAY Then
        Begin
          ALow := GetArrayLowBound(IdName);
          If ALow <> 0 Then
            Tmp := Tmp + '[(' + Tmp2 + ') - ' + IntToStr_(ALow) + ']'
          Else
            Tmp := Tmp + '[' + Tmp2 + ']';
        End
        Else
          Tmp := Tmp + '[' + Tmp2 + ']';
      End
      { Acces champ : ident.champ }
      Else If (TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = '.') Then
      Begin
        Inc(P); { consommer . }
        If (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Then
        Begin
          Tmp := Tmp + '.' + TokenPool[P].Val;
          Inc(P);
        End;
      End
      { Dereferencement : ident^ }
      Else If (TokenPool[P].Kind = TK_OP) And (TokenPool[P].Val = '^') Then
      Begin
        Inc(P); { consommer ^ }
        { En JS, pas de dereferencement direct - garder tel quel }
      End
      Else
        Break;
    End;

    { Ajouter () pour les procedures/fonctions sans parentheses (TODO 15) }
    Idx := SymFind(IdName);
    If (Idx >= 0) And
       ((SymTab[Idx].Kind = SK_PROC) Or (SymTab[Idx].Kind = SK_FUNC)) Then
    Begin
      { Si Tmp est juste le nom (pas de postfix ()), ajouter () }
      If Tmp = IdName Then
        Tmp := Tmp + '()';
    End;

    ParseExprFactor := Tmp;
    Exit;
  End;

  { Token non reconnu : retourner tel quel }
  ParseExprFactor := TokenPool[P].Val;
  Inc(P);
End;

{ ---- ParseExprTerm : niveau 2 (multiplicatif) --------------- }
{ * / DIV MOD AND SHL SHR                                       }
Function ParseExprTerm(Var P : Integer) : TString;
Var
  Left : TString;
  Op   : TString;
  Rght : TString;
Begin
  Left := ParseExprFactor(P);

  While (P < TokenCount) And IsLevel2Op(TokenPool[P]) Do
  Begin
    Op := StrLowerCase(TokenPool[P].Val);
    Inc(P);
    Rght := ParseExprFactor(P);

    If Op = 'div' Then
      Left := 'Math.trunc(' + Left + ' / ' + Rght + ')'
    Else If Op = '*' Then
      Left := Left + ' * ' + Rght
    Else If Op = '/' Then
      Left := Left + ' / ' + Rght
    Else If Op = 'mod' Then
      Left := Left + ' % ' + Rght
    Else If Op = 'and' Then
    Begin
      If IsBooleanExpr(Left) Or IsBooleanExpr(Rght) Then
        Left := Left + ' && ' + Rght
      Else
        Left := '(' + Left + ' & ' + Rght + ')';
    End
    Else If Op = 'shl' Then
      Left := Left + ' << ' + Rght
    Else If Op = 'shr' Then
      Left := Left + ' >> ' + Rght;
  End;

  ParseExprTerm := Left;
End;

{ ---- ParseExprSimple : niveau 3 (additif) ------------------- }
{ + - OR XOR                                                     }
Function ParseExprSimple(Var P : Integer) : TString;
Var
  Left : TString;
  Op   : TString;
  Rght : TString;
Begin
  Left := ParseExprTerm(P);

  While (P < TokenCount) And IsLevel3Op(TokenPool[P]) Do
  Begin
    Op := StrLowerCase(TokenPool[P].Val);
    Inc(P);
    Rght := ParseExprTerm(P);

    If Op = '+' Then
      Left := Left + ' + ' + Rght
    Else If Op = '-' Then
      Left := Left + ' - ' + Rght
    Else If Op = 'or' Then
    Begin
      If IsBooleanExpr(Left) Or IsBooleanExpr(Rght) Then
        Left := Left + ' || ' + Rght
      Else
        Left := '(' + Left + ' | ' + Rght + ')';
    End
    Else If Op = 'xor' Then
      Left := Left + ' ^ ' + Rght;
  End;

  ParseExprSimple := Left;
End;

{ ---- ParseExpr : niveau 4 (relationnel, le plus faible) ----- }
{ = <> < > <= >= IN                                              }
Function ParseExpr;
Var
  Left : TString;
  Op   : TString;
  Rght : TString;
Begin
  Left := ParseExprSimple(P);

  While (P < TokenCount) And IsLevel4Op(TokenPool[P]) Do
  Begin
    Op := StrLowerCase(TokenPool[P].Val);
    Inc(P);
    Rght := ParseExprSimple(P);

    If Op = '=' Then
      Left := Left + ' === ' + Rght
    Else If Op = '<>' Then
      Left := Left + ' !== ' + Rght
    Else If Op = '<' Then
      Left := Left + ' < ' + Rght
    Else If Op = '>' Then
      Left := Left + ' > ' + Rght
    Else If Op = '<=' Then
      Left := Left + ' <= ' + Rght
    Else If Op = '>=' Then
      Left := Left + ' >= ' + Rght
    Else If Op = 'in' Then
      Left := Rght + '.indexOf(' + Left + ') >= 0'
    Else If Op = 'as' Then
      Left := '/* as ' + Rght + ' */ ' + Left;
  End;

  ParseExpr := Left;
End;

{ ---- ParseAssign : gere l affectation := -------------------- }
{ Detecte l operateur := et genere lhs = rhs en JavaScript.     }
{ TODO 09 : copie de record (Object.assign) et tableau (.slice) }
Function ParseAssign(Var P : Integer) : TString;
Var
  Left       : TString;
  Rght       : TString;
  SymIdx     : Integer;
  TIdx       : Integer;
  SaveP      : Integer;
  IsElemAccess : Boolean;
Begin
  { Sauvegarder la position avant le parsing du LHS }
  SaveP := P;
  Left := ParseExpr(P);

  If (P < TokenCount) And (TokenPool[P].Kind = TK_OP) And
     (TokenPool[P].Val = ':=') Then
  Begin
    Inc(P);
    Rght := ParseExpr(P);

    { Verifier le type de la variable cible pour record/array }
    TIdx := -1;
    IsElemAccess := False;
    If (TokenPool[SaveP].Kind = TK_IDENT) Then
    Begin
      { Verifier si l ident est suivi de [ . ou ^ -> acces element }
      If (SaveP + 1 < TokenCount) And
         (TokenPool[SaveP + 1].Kind = TK_PUNCT) And
         ((TokenPool[SaveP + 1].Val = '[') Or
          (TokenPool[SaveP + 1].Val = '.')) Then
        IsElemAccess := True;
      If (SaveP + 1 < TokenCount) And
         (TokenPool[SaveP + 1].Kind = TK_OP) And
         (TokenPool[SaveP + 1].Val = '^') Then
        IsElemAccess := True;

      If Not IsElemAccess Then
      Begin
        SymIdx := SymFind(TokenPool[SaveP].Val);
        If SymIdx >= 0 Then
          TIdx := SymTab[SymIdx].TypeIdx;
      End;
    End;

    { Affectation de record entier : Object.assign(lhs, rhs) }
    If (TIdx >= 0) And (TIdx < TypeCount) And
       (TypeTab[TIdx].Kind = TYK_RECORD) Then
      ParseAssign := 'Object.assign(' + Left + ', ' + Rght + ')'
    { Affectation de tableau entier : lhs = rhs.slice() }
    Else If (TIdx >= 0) And (TIdx < TypeCount) And
            (TypeTab[TIdx].Kind = TYK_ARRAY) Then
      ParseAssign := Left + ' = ' + Rght + '.slice()'
    { Affectation au nom de fonction -> Result = valeur (TODO 15/17) }
    Else If (Not IsElemAccess) And (TokenPool[SaveP].Kind = TK_IDENT) And
            (SymIdx >= 0) And ((SymTab[SymIdx].Kind = SK_FUNC) Or
                               (SymTab[SymIdx].Kind = SK_METHOD)) Then
      ParseAssign := 'Result = ' + Rght
    { Affectation normale (y compris elements de tableau/record) }
    Else
      ParseAssign := Left + ' = ' + Rght;
  End
  Else
    ParseAssign := Left;
End;

{ ---- ExprToJS : point d entree pour convertir expressions ---- }
{ Convertit une expression Pascal a la position P dans           }
{ TokenPool en representation JavaScript. Gere l affectation.    }
Function ExprToJS(Var P : Integer) : TString;
Begin
  ExprToJS := ParseAssign(P);
End;

{ ============================================================
  TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
  ============================================================ }

{ ---- SymKindStr : nom textuel d un TSymKind ----------------- }
Function SymKindStr(K : TSymKind) : TString;
Begin
  Case K Of
    SK_CONST    : SymKindStr := 'CONST';
    SK_TYPE     : SymKindStr := 'TYPE';
    SK_VAR      : SymKindStr := 'VAR';
    SK_PARAM    : SymKindStr := 'PARAM';
    SK_FUNC     : SymKindStr := 'FUNC';
    SK_PROC     : SymKindStr := 'PROC';
    SK_FIELD    : SymKindStr := 'FIELD';
    SK_METHOD   : SymKindStr := 'METHOD';
    SK_PROPERTY : SymKindStr := 'PROPERTY';
    SK_UNIT     : SymKindStr := 'UNIT';
    SK_LABEL    : SymKindStr := 'LABEL';
    SK_ENUMVAL  : SymKindStr := 'ENUMVAL';
  Else
    SymKindStr := '?';
  End;
End;

{ ---- SymInit : initialiser la table des symboles ------------ }
Procedure SymInit;
Begin
  SymCount   := 0;
  CurScope   := 0;
  CurScopeId := 0;
  SymJSSeq   := 0;
  BuiltinSymEnd := 0;
End;

{ ---- SymGenJSName : generer un nom JavaScript unique -------- }
{ Prefixe selon le type du symbole, suffixe le nom Pascal.      }
{ Variables -> _TPV_name, fonctions -> _TPF_name, etc.          }
Function SymGenJSName(Const AName : TString; AKind : TSymKind) : TString;
Begin
  Case AKind Of
    SK_CONST   : SymGenJSName := TP_CST_PFX + AName;
    SK_TYPE    : SymGenJSName := TP_TYPE_PFX + AName;
    SK_VAR     : SymGenJSName := TP_VAR_PFX + AName;
    SK_PARAM   : SymGenJSName := AName;
    SK_FUNC    : SymGenJSName := TP_FN_PFX + AName;
    SK_PROC    : SymGenJSName := TP_FN_PFX + AName;
    SK_FIELD   : SymGenJSName := AName;
    SK_METHOD  : SymGenJSName := AName;
    SK_PROPERTY: SymGenJSName := AName;
    SK_UNIT    : SymGenJSName := TP_UNIT_PFX + AName;
    SK_LABEL   : SymGenJSName := '_TPL_' + AName;
    SK_ENUMVAL : SymGenJSName := TP_CST_PFX + AName;
  Else
    SymGenJSName := AName;
  End;
End;

{ ---- SymAdd : ajouter un symbole a la table ----------------- }
{ Retourne l index du nouveau symbole, ou -1 si table pleine.   }
Function SymAdd(Const AName : TString; AKind : TSymKind;
                ATypeIdx : Integer) : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    CompileError('table des symboles saturee (MAX_SYM=' +
                 IntToStr_(MAX_SYM) + ')');
    SymAdd := -1;
    Exit;
  End;
  SymTab[SymCount].Name       := AName;
  SymTab[SymCount].JSName     := SymGenJSName(AName, AKind);
  SymTab[SymCount].Kind       := AKind;
  SymTab[SymCount].TypeIdx    := ATypeIdx;
  SymTab[SymCount].Scope      := CurScope;
  SymTab[SymCount].ScopeId    := CurScopeId;
  SymTab[SymCount].IsPublic   := False;
  SymTab[SymCount].IsPrivate  := False;
  SymTab[SymCount].IsForward  := False;
  SymTab[SymCount].IsExternal := False;
  SymAdd := SymCount;
  Inc(SymCount);
End;

{ ---- SymFind : chercher un symbole par nom (insensible) ----- }
{ Parcourt la table du plus recent au plus ancien (portee        }
{ la plus interne en premier). Retourne l index ou -1.           }
Function SymFind(Const AName : TString) : Integer;
Var
  I  : Integer;
  LN : TString;
  LS : TString;
Begin
  LN := StrLowerCase(AName);
  For I := SymCount - 1 DownTo 0 Do
  Begin
    LS := StrLowerCase(SymTab[I].Name);
    If LS = LN Then
    Begin
      SymFind := I;
      Exit;
    End;
  End;
  SymFind := -1;
End;

{ ---- SymFindInScope : chercher dans une portee specifique --- }
{ Recherche un symbole par nom dans le scope donne seulement.   }
Function SymFindInScope(Const AName : TString;
                        AScope : Integer) : Integer;
Var
  I  : Integer;
  LN : TString;
  LS : TString;
Begin
  LN := StrLowerCase(AName);
  For I := SymCount - 1 DownTo 0 Do
  Begin
    If SymTab[I].Scope = AScope Then
    Begin
      LS := StrLowerCase(SymTab[I].Name);
      If LS = LN Then
      Begin
        SymFindInScope := I;
        Exit;
      End;
    End;
  End;
  SymFindInScope := -1;
End;

{ ---- SymEnterScope : entrer dans une portee imbriquee ------- }
Procedure SymEnterScope;
Begin
  If CurScope >= MAX_SCOPE Then
  Begin
    CompileError('portees imbriquees max atteint (MAX_SCOPE=' +
                 IntToStr_(MAX_SCOPE) + ')');
    Exit;
  End;
  Inc(CurScope);
  Inc(CurScopeId);
End;

{ ---- SymLeaveScope : quitter la portee courante ------------- }
{ Les symboles de la portee quittee restent dans la table mais   }
{ ne seront plus trouves par SymFind en priorite (portees        }
{ plus recentes sont cherchees en premier).                      }
Procedure SymLeaveScope;
Begin
  If CurScope > 0 Then
    Dec(CurScope);
End;

{ ---- SymRegisterBuiltins : types et symboles predefinis ----- }
{ Enregistre les types de base de Turbo Pascal dans la table     }
{ des symboles avec les vrais TypeIdx du systeme de types.       }
Procedure SymRegisterBuiltins;
Var
  TI : Integer;
Begin
  { Types entiers }
  TI := TypeFindByName('Integer');
  SymAdd('Integer',  SK_TYPE, TI);
  TI := TypeFindByName('Word');
  SymAdd('Word',     SK_TYPE, TI);
  TI := TypeFindByName('Byte');
  SymAdd('Byte',     SK_TYPE, TI);
  TI := TypeFindByName('ShortInt');
  SymAdd('ShortInt', SK_TYPE, TI);
  TI := TypeFindByName('LongInt');
  SymAdd('LongInt',  SK_TYPE, TI);
  TI := TypeFindByName('Comp');
  SymAdd('Comp',     SK_TYPE, TI);

  { Types booleens }
  TI := TypeFindByName('Boolean');
  SymAdd('Boolean',  SK_TYPE, TI);

  { Types caractere }
  TI := TypeFindByName('Char');
  SymAdd('Char',     SK_TYPE, TI);

  { Types reels }
  TI := TypeFindByName('Real');
  SymAdd('Real',     SK_TYPE, TI);
  TI := TypeFindByName('Single');
  SymAdd('Single',   SK_TYPE, TI);
  TI := TypeFindByName('Double');
  SymAdd('Double',   SK_TYPE, TI);
  TI := TypeFindByName('Extended');
  SymAdd('Extended', SK_TYPE, TI);

  { Types chaine }
  TI := TypeFindByName('String');
  SymAdd('String',   SK_TYPE, TI);
  TI := TypeFindByName('PChar');
  SymAdd('PChar',    SK_TYPE, TI);

  { Types pointeur }
  TI := TypeFindByName('Pointer');
  SymAdd('Pointer',  SK_TYPE, TI);

  { Types fichier }
  TI := TypeFindByName('Text');
  SymAdd('Text',     SK_TYPE, TI);
  TI := TypeFindByName('File');
  SymAdd('File',     SK_TYPE, TI);

  { Constantes predefinees }
  TI := TypeFindByName('Boolean');
  SymAdd('True',         SK_CONST, TI);
  SymAdd('False',        SK_CONST, TI);
  TI := TypeFindByName('Pointer');
  SymAdd('nil',          SK_CONST, TI);
  TI := TypeFindByName('Integer');
  SymAdd('MaxInt',       SK_CONST, TI);
  TI := TypeFindByName('LongInt');
  SymAdd('MaxLongInt',   SK_CONST, TI);
  TI := TypeFindByName('Real');
  SymAdd('Pi',           SK_CONST, TI);

  { Procedures/fonctions System predefinies }
  SymAdd('WriteLn',      SK_PROC,  -1);
  SymAdd('Write',        SK_PROC,  -1);
  SymAdd('ReadLn',       SK_PROC,  -1);
  SymAdd('Read',         SK_PROC,  -1);
  SymAdd('Inc',          SK_PROC,  -1);
  SymAdd('Dec',          SK_PROC,  -1);
  SymAdd('Halt',         SK_PROC,  -1);
  SymAdd('Exit',         SK_PROC,  -1);
  SymAdd('New',          SK_PROC,  -1);
  SymAdd('Dispose',      SK_PROC,  -1);
  SymAdd('GetMem',       SK_PROC,  -1);
  SymAdd('FreeMem',      SK_PROC,  -1);
  SymAdd('FillChar',     SK_PROC,  -1);
  SymAdd('Move',         SK_PROC,  -1);
  SymAdd('Assign',       SK_PROC,  -1);
  SymAdd('Reset',        SK_PROC,  -1);
  SymAdd('Rewrite',      SK_PROC,  -1);
  SymAdd('Close',        SK_PROC,  -1);
  SymAdd('Append',       SK_PROC,  -1);
  SymAdd('Str',          SK_PROC,  -1);
  SymAdd('Val',          SK_PROC,  -1);
  SymAdd('Delete',       SK_PROC,  -1);
  SymAdd('Insert',       SK_PROC,  -1);
  SymAdd('Randomize',    SK_PROC,  -1);
  SymAdd('SetLength',    SK_PROC,  -1);
  SymAdd('BlockRead',    SK_PROC,  -1);
  SymAdd('BlockWrite',   SK_PROC,  -1);
  SymAdd('Seek',         SK_PROC,  -1);
  SymAdd('Erase',        SK_PROC,  -1);
  SymAdd('Rename',       SK_PROC,  -1);
  SymAdd('ClrScr',       SK_PROC,  -1);
  SymAdd('GotoXY',       SK_PROC,  -1);
  SymAdd('TextColor',    SK_PROC,  -1);
  SymAdd('TextBackground', SK_PROC,  -1);
  SymAdd('Delay',        SK_PROC,  -1);
  SymAdd('Sound',        SK_PROC,  -1);
  SymAdd('NoSound',      SK_PROC,  -1);

  SymAdd('Ord',          SK_FUNC,  -1);
  SymAdd('Chr',          SK_FUNC,  -1);
  SymAdd('Abs',          SK_FUNC,  -1);
  SymAdd('Sqr',          SK_FUNC,  -1);
  SymAdd('Sqrt',         SK_FUNC,  -1);
  SymAdd('Sin',          SK_FUNC,  -1);
  SymAdd('Cos',          SK_FUNC,  -1);
  SymAdd('ArcTan',       SK_FUNC,  -1);
  SymAdd('Exp',          SK_FUNC,  -1);
  SymAdd('Ln',           SK_FUNC,  -1);
  SymAdd('Int',          SK_FUNC,  -1);
  SymAdd('Frac',         SK_FUNC,  -1);
  SymAdd('Round',        SK_FUNC,  -1);
  SymAdd('Trunc',        SK_FUNC,  -1);
  SymAdd('Succ',         SK_FUNC,  -1);
  SymAdd('Pred',         SK_FUNC,  -1);
  SymAdd('Odd',          SK_FUNC,  -1);
  SymAdd('Lo',           SK_FUNC,  -1);
  SymAdd('Hi',           SK_FUNC,  -1);
  SymAdd('Swap',         SK_FUNC,  -1);
  SymAdd('SizeOf',       SK_FUNC,  -1);
  SymAdd('Length',        SK_FUNC,  -1);
  SymAdd('Copy',         SK_FUNC,  -1);
  SymAdd('Pos',          SK_FUNC,  -1);
  SymAdd('Concat',       SK_FUNC,  -1);
  SymAdd('UpCase',       SK_FUNC,  -1);
  SymAdd('Random',       SK_FUNC,  -1);
  SymAdd('ParamCount',   SK_FUNC,  -1);
  SymAdd('ParamStr',     SK_FUNC,  -1);
  SymAdd('IOResult',     SK_FUNC,  -1);
  SymAdd('Eof',          SK_FUNC,  -1);
  SymAdd('Eoln',         SK_FUNC,  -1);
  SymAdd('FilePos',      SK_FUNC,  -1);
  SymAdd('FileSize',     SK_FUNC,  -1);
  SymAdd('Addr',         SK_FUNC,  -1);
  SymAdd('Assigned',     SK_FUNC,  -1);
  SymAdd('KeyPressed',   SK_FUNC,  -1);
  SymAdd('ReadKey',      SK_FUNC,  -1);
  SymAdd('WhereX',       SK_FUNC,  -1);
  SymAdd('WhereY',       SK_FUNC,  -1);
End;

{ ---- SymDump : afficher le contenu de la table (debug) ------ }
Procedure SymDump;
Var
  I : Integer;
Begin
  WriteLn('--- Table des symboles (', SymCount, ' entrees) ---');
  For I := 0 To SymCount - 1 Do
    WriteLn('  [', I, '] ', SymTab[I].Name, ' -> ',
            SymTab[I].JSName, ' (', SymKindStr(SymTab[I].Kind),
            ', scope=', SymTab[I].Scope,
            ', type=', SymTab[I].TypeIdx, ')');
  WriteLn('--- Fin de la table des symboles ---');
End;

{ ============================================================
  TODO 06 - SYSTEME DE TYPES [IMPLEMENTE]
  ============================================================ }

{ ---- TypeKindStr : nom textuel d un TTypeKind --------------- }
Function TypeKindStr(K : TTypeKind) : TString;
Begin
  Case K Of
    TYK_INTEGER  : TypeKindStr := 'INTEGER';
    TYK_WORD     : TypeKindStr := 'WORD';
    TYK_BYTE     : TypeKindStr := 'BYTE';
    TYK_SHORTINT : TypeKindStr := 'SHORTINT';
    TYK_LONGINT  : TypeKindStr := 'LONGINT';
    TYK_COMP     : TypeKindStr := 'COMP';
    TYK_BOOLEAN  : TypeKindStr := 'BOOLEAN';
    TYK_CHAR     : TypeKindStr := 'CHAR';
    TYK_REAL     : TypeKindStr := 'REAL';
    TYK_SINGLE   : TypeKindStr := 'SINGLE';
    TYK_DOUBLE   : TypeKindStr := 'DOUBLE';
    TYK_EXTENDED : TypeKindStr := 'EXTENDED';
    TYK_STRING   : TypeKindStr := 'STRING';
    TYK_PCHAR    : TypeKindStr := 'PCHAR';
    TYK_ARRAY    : TypeKindStr := 'ARRAY';
    TYK_RECORD   : TypeKindStr := 'RECORD';
    TYK_SET      : TypeKindStr := 'SET';
    TYK_ENUM     : TypeKindStr := 'ENUM';
    TYK_FILE     : TypeKindStr := 'FILE';
    TYK_TEXT     : TypeKindStr := 'TEXT';
    TYK_POINTER  : TypeKindStr := 'POINTER';
    TYK_OBJECT   : TypeKindStr := 'OBJECT';
    TYK_SUBRANGE : TypeKindStr := 'SUBRANGE';
    TYK_PROCVAR  : TypeKindStr := 'PROCVAR';
  Else
    TypeKindStr := '?';
  End;
End;

{ ---- TypeInit : initialiser la table des types -------------- }
Procedure TypeInit;
Begin
  TypeCount := 0;
End;

{ ---- TypeAdd : ajouter un type a la table ------------------- }
{ Retourne l index du nouveau type, ou -1 si table pleine.      }
Function TypeAdd(AKind : TTypeKind; Const AName : TString;
                 ASize : Integer; Const AJSType : TString;
                 Const AJSDefault : TString) : Integer;
Begin
  If TypeCount >= MAX_TYPE Then
  Begin
    CompileError('table des types saturee (MAX_TYPE=' +
                 IntToStr_(MAX_TYPE) + ')');
    TypeAdd := -1;
    Exit;
  End;
  TypeTab[TypeCount].Kind        := AKind;
  TypeTab[TypeCount].Name        := AName;
  TypeTab[TypeCount].Size        := ASize;
  TypeTab[TypeCount].JSType      := AJSType;
  TypeTab[TypeCount].JSDefault   := AJSDefault;
  TypeTab[TypeCount].BaseTypeIdx := -1;
  TypeTab[TypeCount].ElemCount   := 0;
  TypeTab[TypeCount].FieldCount  := 0;
  TypeTab[TypeCount].Low         := 0;
  TypeTab[TypeCount].High        := 0;
  TypeTab[TypeCount].IsUnsigned  := False;
  TypeAdd := TypeCount;
  Inc(TypeCount);
End;

{ ---- TypeFindByName : chercher un type par nom --------------- }
{ Comparaison insensible a la casse. Retourne l index ou -1.     }
Function TypeFindByName(Const AName : TString) : Integer;
Var
  I  : Integer;
  LN : TString;
  LT : TString;
Begin
  LN := StrLowerCase(AName);
  For I := 0 To TypeCount - 1 Do
  Begin
    LT := StrLowerCase(TypeTab[I].Name);
    If LT = LN Then
    Begin
      TypeFindByName := I;
      Exit;
    End;
  End;
  TypeFindByName := -1;
End;

{ ---- TypeToJS : correspondance type Pascal -> type JS ------- }
{ Retourne la chaine du type JavaScript correspondant.           }
Function TypeToJS(Idx : Integer) : TString;
Begin
  If (Idx < 0) Or (Idx >= TypeCount) Then
    TypeToJS := 'any'
  Else
    TypeToJS := TypeTab[Idx].JSType;
End;

{ ---- TypeDefaultJS : valeur par defaut JS pour un type ------ }
{ Retourne la valeur d initialisation par defaut en JS.          }
Function TypeDefaultJS(Idx : Integer) : TString;
Begin
  If (Idx < 0) Or (Idx >= TypeCount) Then
    TypeDefaultJS := 'null'
  Else
    TypeDefaultJS := TypeTab[Idx].JSDefault;
End;

{ ---- TypeIsNumeric : teste si le type est numerique --------- }
Function TypeIsNumeric(Idx : Integer) : Boolean;
Begin
  TypeIsNumeric := False;
  If (Idx < 0) Or (Idx >= TypeCount) Then Exit;
  Case TypeTab[Idx].Kind Of
    TYK_INTEGER, TYK_WORD, TYK_BYTE, TYK_SHORTINT,
    TYK_LONGINT, TYK_COMP, TYK_REAL, TYK_SINGLE,
    TYK_DOUBLE, TYK_EXTENDED :
      TypeIsNumeric := True;
  End;
End;

{ ---- TypeIsOrdinal : teste si le type est ordinal ----------- }
Function TypeIsOrdinal(Idx : Integer) : Boolean;
Begin
  TypeIsOrdinal := False;
  If (Idx < 0) Or (Idx >= TypeCount) Then Exit;
  Case TypeTab[Idx].Kind Of
    TYK_INTEGER, TYK_WORD, TYK_BYTE, TYK_SHORTINT,
    TYK_LONGINT, TYK_COMP, TYK_BOOLEAN, TYK_CHAR,
    TYK_ENUM, TYK_SUBRANGE :
      TypeIsOrdinal := True;
  End;
End;

{ ---- TypeIsInteger : teste si le type est entier ------------ }
Function TypeIsInteger(Idx : Integer) : Boolean;
Begin
  TypeIsInteger := False;
  If (Idx < 0) Or (Idx >= TypeCount) Then Exit;
  Case TypeTab[Idx].Kind Of
    TYK_INTEGER, TYK_WORD, TYK_BYTE, TYK_SHORTINT,
    TYK_LONGINT, TYK_COMP :
      TypeIsInteger := True;
  End;
End;

{ ---- TypeIsReal : teste si le type est reel ----------------- }
Function TypeIsReal(Idx : Integer) : Boolean;
Begin
  TypeIsReal := False;
  If (Idx < 0) Or (Idx >= TypeCount) Then Exit;
  Case TypeTab[Idx].Kind Of
    TYK_REAL, TYK_SINGLE, TYK_DOUBLE, TYK_EXTENDED :
      TypeIsReal := True;
  End;
End;

{ ---- TypeIsString : teste si le type est une chaine --------- }
Function TypeIsString(Idx : Integer) : Boolean;
Begin
  TypeIsString := False;
  If (Idx < 0) Or (Idx >= TypeCount) Then Exit;
  Case TypeTab[Idx].Kind Of
    TYK_STRING, TYK_PCHAR :
      TypeIsString := True;
  End;
End;

{ ---- TypeIsBoolean : teste si le type est booleen ----------- }
Function TypeIsBoolean(Idx : Integer) : Boolean;
Begin
  TypeIsBoolean := False;
  If (Idx < 0) Or (Idx >= TypeCount) Then Exit;
  TypeIsBoolean := (TypeTab[Idx].Kind = TYK_BOOLEAN);
End;

{ ---- TypeIsPointer : teste si le type est un pointeur ------- }
Function TypeIsPointer(Idx : Integer) : Boolean;
Begin
  TypeIsPointer := False;
  If (Idx < 0) Or (Idx >= TypeCount) Then Exit;
  Case TypeTab[Idx].Kind Of
    TYK_POINTER, TYK_PCHAR :
      TypeIsPointer := True;
  End;
End;

{ ---- TypeIsCompatible : teste la compatibilite de types ----- }
{ Retourne True si une valeur de type SrcIdx peut etre affectee  }
{ a une variable de type DstIdx (regles simplifiees TP).         }
Function TypeIsCompatible(DstIdx, SrcIdx : Integer) : Boolean;
Begin
  TypeIsCompatible := False;
  If (DstIdx < 0) Or (SrcIdx < 0) Then
  Begin
    TypeIsCompatible := True;
    Exit;
  End;
  If DstIdx = SrcIdx Then
  Begin
    TypeIsCompatible := True;
    Exit;
  End;
  { Numerique vers numerique : toujours compatible }
  If TypeIsNumeric(DstIdx) And TypeIsNumeric(SrcIdx) Then
  Begin
    TypeIsCompatible := True;
    Exit;
  End;
  { Chaine vers chaine }
  If TypeIsString(DstIdx) And TypeIsString(SrcIdx) Then
  Begin
    TypeIsCompatible := True;
    Exit;
  End;
  { Char vers String }
  If TypeIsString(DstIdx) And
     (TypeTab[SrcIdx].Kind = TYK_CHAR) Then
  Begin
    TypeIsCompatible := True;
    Exit;
  End;
  { Pointeur vers pointeur }
  If TypeIsPointer(DstIdx) And TypeIsPointer(SrcIdx) Then
  Begin
    TypeIsCompatible := True;
    Exit;
  End;
End;

{ ---- TypeAddField : ajouter un champ a un type record ------- }
Function TypeAddField(TIdx : Integer; Const FName : TString;
                      FTypeIdx : Integer) : Integer;
Begin
  TypeAddField := -1;
  If (TIdx < 0) Or (TIdx >= TypeCount) Then Exit;
  If TypeTab[TIdx].FieldCount >= MAX_FIELD Then
  Begin
    CompileError('trop de champs (MAX_FIELD=' +
                 IntToStr_(MAX_FIELD) + ')');
    Exit;
  End;
  TypeTab[TIdx].Fields[TypeTab[TIdx].FieldCount].Name    := FName;
  TypeTab[TIdx].Fields[TypeTab[TIdx].FieldCount].TypeIdx := FTypeIdx;
  TypeAddField := TypeTab[TIdx].FieldCount;
  Inc(TypeTab[TIdx].FieldCount);
End;

{ ---- TypeRegisterBuiltins : types primitifs Turbo Pascal ---- }
{ Enregistre les types de base dans la table des types et         }
{ retourne les index pour les utiliser dans SymRegisterBuiltins.  }
{ Correspondances JS :                                            }
{   Integer/Word/Byte/ShortInt/LongInt/Comp -> number (entier)    }
{   Real/Single/Double/Extended -> number (reel)                  }
{   Boolean -> boolean                                            }
{   Char -> string (1 car)                                        }
{   String/PChar -> string                                        }
{   Array -> Array, Record -> object, Set -> Array ou Set         }
{   File/Text -> objet fichier, Pointer -> reference              }
{   Object -> class, ProcVar -> function                          }
Procedure TypeRegisterBuiltins;
Var
  Idx : Integer;
Begin
  { Types entiers }
  Idx := TypeAdd(TYK_INTEGER,  'Integer',  2, 'number', '0');
  TypeTab[Idx].Low := -32768;
  TypeTab[Idx].High := 32767;
  Idx := TypeAdd(TYK_WORD,     'Word',     2, 'number', '0');
  TypeTab[Idx].IsUnsigned := True;
  TypeTab[Idx].Low := 0;
  TypeTab[Idx].High := 65535;
  Idx := TypeAdd(TYK_BYTE,     'Byte',     1, 'number', '0');
  TypeTab[Idx].IsUnsigned := True;
  TypeTab[Idx].Low := 0;
  TypeTab[Idx].High := 255;
  Idx := TypeAdd(TYK_SHORTINT, 'ShortInt', 1, 'number', '0');
  TypeTab[Idx].Low := -128;
  TypeTab[Idx].High := 127;
  Idx := TypeAdd(TYK_LONGINT,  'LongInt',  4, 'number', '0');
  TypeTab[Idx].Low := -2147483647 - 1;
  TypeTab[Idx].High := 2147483647;
  Idx := TypeAdd(TYK_COMP,     'Comp',     8, 'number', '0');

  { Types booleens }
  Idx := TypeAdd(TYK_BOOLEAN,  'Boolean',  1, 'boolean', 'false');
  TypeTab[Idx].Low := 0;
  TypeTab[Idx].High := 1;

  { Types caractere }
  Idx := TypeAdd(TYK_CHAR,     'Char',     1, 'string', '""');
  TypeTab[Idx].Low := 0;
  TypeTab[Idx].High := 255;

  { Types reels }
  TypeAdd(TYK_REAL,     'Real',     6, 'number', '0.0');
  TypeAdd(TYK_SINGLE,   'Single',   4, 'number', '0.0');
  TypeAdd(TYK_DOUBLE,   'Double',   8, 'number', '0.0');
  TypeAdd(TYK_EXTENDED, 'Extended', 10, 'number', '0.0');

  { Types chaine }
  TypeAdd(TYK_STRING,   'String',  256, 'string', '""');
  TypeAdd(TYK_PCHAR,    'PChar',     4, 'string', 'null');

  { Types pointeur }
  TypeAdd(TYK_POINTER,  'Pointer',   4, 'object', 'null');

  { Types fichier }
  TypeAdd(TYK_TEXT,     'Text',      0, 'object', 'null');
  TypeAdd(TYK_FILE,     'File',      0, 'object', 'null');
End;

{ ---- TypeDump : afficher la table des types (debug) --------- }
Procedure TypeDump;
Var
  I : Integer;
Begin
  WriteLn('--- Table des types (', TypeCount, ' entrees) ---');
  For I := 0 To TypeCount - 1 Do
    WriteLn('  [', I, '] ', TypeTab[I].Name,
            ' (', TypeKindStr(TypeTab[I].Kind),
            ', size=', TypeTab[I].Size,
            ', js=', TypeTab[I].JSType,
            ', default=', TypeTab[I].JSDefault, ')');
  WriteLn('--- Fin de la table des types ---');
End;

{ ============================================================
  TODO 07 - EMETTEUR DE CODE JAVASCRIPT [IMPLEMENTE]
  ============================================================ }

{ ---- IndentStr : retourner la chaine d indentation ---------- }
Function IndentStr : TString;
Var
  I : Integer;
  S : TString;
Begin
  S := '';
  For I := 1 To IndentLevel Do
    S := S + '  ';
  IndentStr := S;
End;

{ ---- IndentPush : augmenter le niveau d indentation --------- }
Procedure IndentPush;
Begin
  Inc(IndentLevel);
End;

{ ---- IndentPop : diminuer le niveau d indentation ----------- }
Procedure IndentPop;
Begin
  If IndentLevel > 0 Then
    Dec(IndentLevel);
End;

{ ---- EmitOpen : ouvrir le fichier .js de sortie ------------- }
{ Ouvre le fichier OutFile pour ecriture. Met OutFOpen a True.   }
Procedure EmitOpen;
Begin
  If OutFOpen Then Exit;
  Assign(OutF, Opts.OutFile);
  {$I-}
  Rewrite(OutF);
  {$I+}
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir le fichier de sortie: ' + Opts.OutFile);
  OutFOpen := True;
  IndentLevel := 0;
End;

{ ---- EmitClose : fermer le fichier .js de sortie ------------ }
Procedure EmitClose;
Begin
  If Not OutFOpen Then Exit;
  {$I-}
  Close(OutF);
  {$I+}
  If IOResult <> 0 Then
    WarnMsg('erreur a la fermeture du fichier de sortie');
  OutFOpen := False;
End;

{ ---- EmitRaw : ecrire texte brut sans indentation ----------- }
Procedure EmitRaw(Const S : TString);
Begin
  If Not OutFOpen Then Exit;
  Write(OutF, S);
End;

{ ---- EmitLine : ecrire une ligne avec indentation ----------- }
Procedure EmitLine(Const S : TString);
Begin
  If Not OutFOpen Then Exit;
  WriteLn(OutF, IndentStr + S);
End;

{ ---- EmitComment : ecrire un commentaire JS // -------------- }
Procedure EmitComment(Const S : TString);
Begin
  If Not OutFOpen Then Exit;
  WriteLn(OutF, IndentStr + '// ' + S);
End;

{ ---- EmitBlankLine : ecrire une ligne vide ------------------- }
Procedure EmitBlankLine;
Begin
  If Not OutFOpen Then Exit;
  WriteLn(OutF, '');
End;

{ ---- EmitHeader : en-tete du fichier JS genere -------------- }
{ Emet le commentaire d en-tete et "use strict";                 }
Procedure EmitHeader;
Begin
  EmitLine('/* Generated by TP2JS ' + TP2JS_VERSION +
           ' - ' + TP2JS_DATE + ' */');
  EmitLine('"use strict";');
  EmitBlankLine;
End;

{ ---- EmitModuleHeader : en-tete module ES6 si option -m ----- }
{ Si l option ModuleES6 est active, emet l en-tete pour module.  }
Procedure EmitModuleHeader;
Begin
  If Not Opts.ModuleES6 Then Exit;
  EmitComment('Module ES6');
  EmitBlankLine;
End;

{ ---- EmitFooter : pied de page du fichier JS genere --------- }
{ Emet l appel du programme principal _main() a la fin.          }
Procedure EmitFooter;
Begin
  EmitBlankLine;
  EmitComment('Programme principal');
  EmitLine('_main();');
End;

{ ============================================================
  TODO 08 - PROGRAMME PRINCIPAL (PROGRAM) [IMPLEMENTE]
  ============================================================ }

{ ---- ParseUsesClause : parser la clause USES ---------------- }
{ USES unit1, unit2, ..., unitN;                                 }
{ Genere des commentaires /* uses unit1 */ en JS.                }
Procedure ParseUsesClause(Var P : Integer);
Var
  UnitName : TString;
  Idx      : Integer;
Begin
  If P >= TokenCount Then Exit;
  If (TokenPool[P].Kind <> TK_KEYWORD) Or
     (StrLowerCase(TokenPool[P].Val) <> 'uses') Then Exit;
  Inc(P); { consommer USES }
  EmitComment('uses');
  While P < TokenCount Do
  Begin
    If TokenPool[P].Kind = TK_IDENT Then
    Begin
      UnitName := TokenPool[P].Val;
      EmitComment('  ' + UnitName);
      { Enregistrer l unite dans la table des symboles }
      Idx := SymAdd(UnitName, SK_UNIT, -1);
      Inc(P);
    End
    Else If (TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = ',') Then
      Inc(P)
    Else If (TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = ';') Then
    Begin
      Inc(P);
      Exit;
    End
    Else
    Begin
      { Token inattendu, avancer }
      Inc(P);
    End;
  End;
End;

{ ---- ParseConstSection : parser une section CONST ----------- }
{ CONST nom = expr; nom = expr; ...                              }
{ Genere : const nom = valeur; en JS.                            }
Procedure ParseConstSection(Var P : Integer);
Var
  CName   : TString;
  JSVal   : TString;
  IsTyped : Boolean;
  TypeName: TString;
  TIdx    : Integer;
  Idx     : Integer;
Begin
  If P >= TokenCount Then Exit;
  If (TokenPool[P].Kind <> TK_KEYWORD) Or
     (StrLowerCase(TokenPool[P].Val) <> 'const') Then Exit;
  Inc(P); { consommer CONST }

  { Boucle sur les declarations de constantes }
  While P < TokenCount Do
  Begin
    { Verifier si on est sur un autre mot-cle de section ou BEGIN }
    If TokenPool[P].Kind = TK_KEYWORD Then
    Begin
      If (StrLowerCase(TokenPool[P].Val) = 'const') Or
         (StrLowerCase(TokenPool[P].Val) = 'var') Or
         (StrLowerCase(TokenPool[P].Val) = 'type') Or
         (StrLowerCase(TokenPool[P].Val) = 'label') Or
         (StrLowerCase(TokenPool[P].Val) = 'begin') Or
         (StrLowerCase(TokenPool[P].Val) = 'procedure') Or
         (StrLowerCase(TokenPool[P].Val) = 'function') Or
         (StrLowerCase(TokenPool[P].Val) = 'constructor') Or
         (StrLowerCase(TokenPool[P].Val) = 'destructor') Then
        Exit;
    End;
    Inc(P);
    IsTyped := False;
    TIdx := -1;

    { Constante typee : nom : Type = valeur }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = ':') Then
    Begin
      Inc(P); { consommer : }
      IsTyped := True;
      If (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Then
      Begin
        TypeName := TokenPool[P].Val;
        TIdx := TypeFindByName(TypeName);
        Inc(P);
      End
      Else If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) Then
      Begin
        TypeName := TokenPool[P].Val;
        TIdx := TypeFindByName(TypeName);
        Inc(P);
      End;
    End;

    { Attendre = }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_OP) And
       (TokenPool[P].Val = '=') Then
    Begin
      Inc(P); { consommer = }
      JSVal := ConstEvalExpr(P);

      { Enregistrer dans la table des constantes }
      ConstAdd(CName, JSVal, TK_INTEGER, 0, 0.0, '', IsTyped);
      { Enregistrer dans la table des symboles }
      Idx := SymAdd(CName, SK_CONST, TIdx);

      { Emettre en JavaScript }
      If IsTyped Then
        EmitLine('var ' + CName + ' = ' + JSVal + ';')
      Else
        EmitLine('const ' + CName + ' = ' + JSVal + ';');
    End;

    { Consommer le point-virgule si present }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = ';') Then
      Inc(P);
  End;
End;

{ ============================================================
  TODO 09 - VARIABLES ET AFFECTATIONS [IMPLEMENTE]
  ============================================================ }

{ ---- ParseVarSection : parser une section VAR --------------- }
{ VAR nom1, nom2 : Type; nom3 : Type;                           }
{ Genere : var nom1 = default; var nom2 = default; en JS.       }
{ TODO 09 : support complet Array/Record/Set/initialisation.     }
Procedure ParseVarSection(Var P : Integer);
Var
  VarNames : Array[0..63] Of TString;
  VarCount : Integer;
  TypeName : TString;
  TIdx     : Integer;
  DefVal   : TString;
  I        : Integer;
  Idx      : Integer;
  L        : TString;
  Depth    : Integer;
Begin
  If P >= TokenCount Then Exit;
  If (TokenPool[P].Kind <> TK_KEYWORD) Or
     (StrLowerCase(TokenPool[P].Val) <> 'var') Then Exit;
  Inc(P); { consommer VAR }

  { Boucle sur les declarations de variables }
  While P < TokenCount Do
  Begin
    { Verifier si on est sur un autre mot-cle de section ou BEGIN }
    If TokenPool[P].Kind = TK_KEYWORD Then
    Begin
      L := StrLowerCase(TokenPool[P].Val);
      If (L = 'const') Or (L = 'var') Or (L = 'type') Or
         (L = 'label') Or (L = 'begin') Or
         (L = 'procedure') Or (L = 'function') Or
         (L = 'constructor') Or (L = 'destructor') Then
        Exit;
    End;

    { Attendre un identificateur }
    If TokenPool[P].Kind <> TK_IDENT Then
    Begin
      Inc(P);
      Continue;
    End;

    { Collecter les noms de variables separes par des virgules }
    VarCount := 0;
    While (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Do
    Begin
      If VarCount < 64 Then
      Begin
        VarNames[VarCount] := TokenPool[P].Val;
        Inc(VarCount);
      End;
      Inc(P);
      If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
         (TokenPool[P].Val = ',') Then
        Inc(P)
      Else
        Break;
    End;

    { Attendre : Type }
    TIdx := -1;
    DefVal := 'null';
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = ':') Then
    Begin
      Inc(P); { consommer : }
      If P < TokenCount Then
      Begin
        L := StrLowerCase(TokenPool[P].Val);

        { Array [...] of Type }
        If (TokenPool[P].Kind = TK_KEYWORD) And (L = 'array') Then
        Begin
          DefVal := '[]';
          Inc(P);
          { Parser [lo..hi] et enregistrer les bornes }
          If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
             (TokenPool[P].Val = '[') Then
          Begin
            Inc(P); { consommer [ }
            { Lire la borne inferieure }
            If (P < TokenCount) And (TokenPool[P].Kind = TK_INTEGER) Then
            Begin
              TIdx := TypeAdd(TYK_ARRAY, '', 0, 'Array', '[]');
              If TIdx >= 0 Then
              Begin
                TypeTab[TIdx].Low := TokenPool[P].IntVal;
                Inc(P);
                { Sauter .. }
                If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
                   (TokenPool[P].Val = '..') Then
                  Inc(P);
                { Lire la borne superieure }
                If (P < TokenCount) And (TokenPool[P].Kind = TK_INTEGER) Then
                Begin
                  TypeTab[TIdx].High := TokenPool[P].IntVal;
                  Inc(P);
                End;
              End
              Else
              Begin
                While (P < TokenCount) And
                      Not ((TokenPool[P].Kind = TK_PUNCT) And
                           (TokenPool[P].Val = ']')) Do
                  Inc(P);
              End;
            End
            Else
            Begin
              { Bornes non entier-litteral, sauter tout }
              TIdx := TypeAdd(TYK_ARRAY, '', 0, 'Array', '[]');
              While (P < TokenCount) And
                    Not ((TokenPool[P].Kind = TK_PUNCT) And
                         (TokenPool[P].Val = ']')) Do
                Inc(P);
            End;
            If (P < TokenCount) And (TokenPool[P].Val = ']') Then
              Inc(P); { consommer ] }
          End
          Else
            TIdx := TypeAdd(TYK_ARRAY, '', 0, 'Array', '[]');
          { Consommer OF }
          If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
             (StrLowerCase(TokenPool[P].Val) = 'of') Then
            Inc(P);
          { Consommer le nom du type element }
          If (P < TokenCount) And
             ((TokenPool[P].Kind = TK_IDENT) Or
              (TokenPool[P].Kind = TK_KEYWORD)) Then
            Inc(P);
        End
        { Record ... end }
        Else If (TokenPool[P].Kind = TK_KEYWORD) And (L = 'record') Then
        Begin
          DefVal := '{}';
          Depth := 1;
          Inc(P);
          While (P < TokenCount) And (Depth > 0) Do
          Begin
            If (TokenPool[P].Kind = TK_KEYWORD) And
               ((StrLowerCase(TokenPool[P].Val) = 'record') Or
                (StrLowerCase(TokenPool[P].Val) = 'object')) Then
              Inc(Depth)
            Else If (TokenPool[P].Kind = TK_KEYWORD) And
                    (StrLowerCase(TokenPool[P].Val) = 'end') Then
              Dec(Depth);
            Inc(P);
          End;
        End
        { Set of Type }
        Else If (TokenPool[P].Kind = TK_KEYWORD) And (L = 'set') Then
        Begin
          DefVal := '[]';
          Inc(P);
          { Consommer OF }
          If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
             (StrLowerCase(TokenPool[P].Val) = 'of') Then
            Inc(P);
          { Consommer le nom du type element }
          If (P < TokenCount) And
             ((TokenPool[P].Kind = TK_IDENT) Or
              (TokenPool[P].Kind = TK_KEYWORD)) Then
            Inc(P);
        End
        { String[N] }
        Else If (TokenPool[P].Kind = TK_KEYWORD) And (L = 'string') Then
        Begin
          TIdx := TypeFindByName('String');
          DefVal := TypeDefaultJS(TIdx);
          Inc(P);
          If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
             (TokenPool[P].Val = '[') Then
          Begin
            While (P < TokenCount) And
                  Not ((TokenPool[P].Kind = TK_PUNCT) And
                       (TokenPool[P].Val = ']')) Do
              Inc(P);
            If P < TokenCount Then Inc(P);
          End;
        End
        { Type simple (Integer, Boolean, etc.) ou type utilisateur }
        Else If (TokenPool[P].Kind = TK_IDENT) Or
                (TokenPool[P].Kind = TK_KEYWORD) Then
        Begin
          TypeName := TokenPool[P].Val;
          TIdx := TypeFindByName(TypeName);
          If (TIdx >= 0) And
             ((TypeTab[TIdx].Kind = TYK_RECORD) Or
              (TypeTab[TIdx].Kind = TYK_ARRAY)) Then
            DefVal := '_TPT_' + TypeTab[TIdx].Name + '()'
          Else
            DefVal := TypeDefaultJS(TIdx);
          Inc(P);
        End;
      End;
    End;

    { Emettre les variables en JavaScript }
    For I := 0 To VarCount - 1 Do
    Begin
      Idx := SymAdd(VarNames[I], SK_VAR, TIdx);
      EmitLine('var ' + VarNames[I] + ' = ' + DefVal + ';');
    End;

    { Consommer le point-virgule si present }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = ';') Then
      Inc(P);
  End;
End;

{ ============================================================
  TODO 16 - TYPES STRUCTURES : ARRAY / RECORD / SET / STRING
            [IMPLEMENTE]
  ============================================================ }
{ Types structures Turbo Pascal -> JavaScript.                   }
{ ARRAY[lo..hi] OF T -> fonction constructeur retournant Array   }
{ RECORD champ1: T1; ... END -> fonction constructeur retournant }
{ un objet litteral JS avec les champs et valeurs par defaut     }
{ SET OF T -> new Set() en JS                                    }
{ STRING[N] -> alias string en JS                                }
{ Type alias (T = ExistingType) -> lien vers le type de base     }

{ ---- ParseTypeArray : parser ARRAY[lo..hi] OF T -----------  }
{ P pointe sur le token suivant ARRAY.                           }
{ Retourne l index du type cree dans TypeTab.                    }
Function ParseTypeArray(Var P : Integer; Const TName : TString) : Integer;
Var
  TIdx      : Integer;
  LoVal     : LongInt;
  HiVal     : LongInt;
  ElemType  : TString;
  ElemTIdx  : Integer;
  ElemDef   : TString;
  ArrSize   : Integer;
  JSBody    : TString;
Begin
  LoVal := 0;
  HiVal := -1;
  ElemType := '';
  ElemTIdx := -1;

  { Parser [lo..hi] }
  If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
     (TokenPool[P].Val = '[') Then
  Begin
    Inc(P); { consommer [ }
    { Lire la borne inferieure }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_INTEGER) Then
    Begin
      LoVal := TokenPool[P].IntVal;
      Inc(P);
    End
    Else If (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Then
    Begin
      { Borne constante (ex: 1..MAX) }
      LoVal := ConstFindIntVal(TokenPool[P].Val, 0);
      Inc(P);
    End;
    { Sauter .. }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = '..') Then
      Inc(P);
    { Lire la borne superieure }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_INTEGER) Then
    Begin
      HiVal := TokenPool[P].IntVal;
      Inc(P);
    End
    Else If (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Then
    Begin
      HiVal := ConstFindIntVal(TokenPool[P].Val, 0);
      Inc(P);
    End;
    { Gerer les dimensions multiples (virgule) - sauter les extras }
    While (P < TokenCount) And
          Not ((TokenPool[P].Kind = TK_PUNCT) And
               (TokenPool[P].Val = ']')) Do
      Inc(P);
    If (P < TokenCount) And (TokenPool[P].Val = ']') Then
      Inc(P); { consommer ] }
  End;

  { Consommer OF }
  If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
     (StrLowerCase(TokenPool[P].Val) = 'of') Then
    Inc(P);

  { Lire le type des elements }
  If (P < TokenCount) And
     ((TokenPool[P].Kind = TK_IDENT) Or
      (TokenPool[P].Kind = TK_KEYWORD)) Then
  Begin
    ElemType := TokenPool[P].Val;
    ElemTIdx := TypeFindByName(ElemType);
    Inc(P);
  End;

  { Calculer la taille et la valeur par defaut }
  ArrSize := 0;
  If HiVal >= LoVal Then
    ArrSize := HiVal - LoVal + 1;
  ElemDef := TypeDefaultJS(ElemTIdx);
  If ElemDef = '' Then ElemDef := '0';

  { Creer le type dans la table }
  JSBody := 'new Array(' + IntToStr_(ArrSize) + ').fill(' + ElemDef + ')';
  TIdx := TypeAdd(TYK_ARRAY, TName, ArrSize * 2, 'Array', JSBody);
  If TIdx >= 0 Then
  Begin
    TypeTab[TIdx].Low := LoVal;
    TypeTab[TIdx].High := HiVal;
    TypeTab[TIdx].BaseTypeIdx := ElemTIdx;
    TypeTab[TIdx].ElemCount := ArrSize;
  End;

  { Emettre la fonction constructeur JS }
  EmitLine('function _TPT_' + TName + '() {');
  IndentPush;
  EmitLine('return ' + JSBody + ';');
  IndentPop;
  EmitLine('}');

  ParseTypeArray := TIdx;
End;

{ ---- ParseTypeRecord : parser RECORD ... END --------------- }
{ P pointe sur le token suivant RECORD.                          }
{ Retourne l index du type cree dans TypeTab.                    }
Function ParseTypeRecord(Var P : Integer; Const TName : TString) : Integer;
Var
  TIdx      : Integer;
  FNames    : Array[0..MAX_FIELD - 1] Of TString;
  FTypes    : Array[0..MAX_FIELD - 1] Of Integer;
  FCount    : Integer;
  FName     : TString;
  FTypeName : TString;
  FTIdx     : Integer;
  Depth     : Integer;
  I         : Integer;
  JSFields  : TString;
  L         : TString;
Begin
  FCount := 0;
  Depth := 1;

  { Parser les champs du record }
  While (P < TokenCount) And (Depth > 0) Do
  Begin
    { Verifier end }
    If (TokenPool[P].Kind = TK_KEYWORD) And
       (StrLowerCase(TokenPool[P].Val) = 'end') Then
    Begin
      Dec(Depth);
      Inc(P);
      Continue;
    End;
    { Verifier record/object imbrique }
    If (TokenPool[P].Kind = TK_KEYWORD) And
       ((StrLowerCase(TokenPool[P].Val) = 'record') Or
        (StrLowerCase(TokenPool[P].Val) = 'object')) Then
    Begin
      Inc(Depth);
      Inc(P);
      Continue;
    End;
    { Sauter CASE (variantes de record) }
    If (TokenPool[P].Kind = TK_KEYWORD) And
       (StrLowerCase(TokenPool[P].Val) = 'case') Then
    Begin
      { Sauter la partie variante jusqu au end }
      While (P < TokenCount) And (Depth > 0) Do
      Begin
        If (TokenPool[P].Kind = TK_KEYWORD) And
           (StrLowerCase(TokenPool[P].Val) = 'end') Then
          Dec(Depth);
        Inc(P);
      End;
      Continue;
    End;

    { Collecter les noms de champs (nom1, nom2 : Type) }
    If (TokenPool[P].Kind = TK_IDENT) And (Depth = 1) Then
    Begin
      { Verifier que c est bien un champ (suivi de , ou :) }
      If (P + 1 < TokenCount) And
         ((TokenPool[P + 1].Val = ',') Or (TokenPool[P + 1].Val = ':')) Then
      Begin
        { Collecter les noms separes par des virgules }
        While (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Do
        Begin
          If FCount < MAX_FIELD Then
          Begin
            FNames[FCount] := TokenPool[P].Val;
            FTypes[FCount] := -1;
            Inc(FCount);
          End;
          Inc(P);
          If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
             (TokenPool[P].Val = ',') Then
            Inc(P)
          Else
            Break;
        End;

        { Attendre : Type }
        If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
           (TokenPool[P].Val = ':') Then
        Begin
          Inc(P); { consommer : }
          FTIdx := -1;
          If (P < TokenCount) Then
          Begin
            L := StrLowerCase(TokenPool[P].Val);
            { Array inline }
            If (TokenPool[P].Kind = TK_KEYWORD) And (L = 'array') Then
            Begin
              FTIdx := TypeFindByName('Integer');
              Inc(P);
              { Sauter [lo..hi] }
              If (P < TokenCount) And (TokenPool[P].Val = '[') Then
              Begin
                While (P < TokenCount) And
                      Not ((TokenPool[P].Kind = TK_PUNCT) And
                           (TokenPool[P].Val = ']')) Do
                  Inc(P);
                If P < TokenCount Then Inc(P);
              End;
              { Sauter OF type }
              If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
                 (StrLowerCase(TokenPool[P].Val) = 'of') Then
                Inc(P);
              If (P < TokenCount) And
                 ((TokenPool[P].Kind = TK_IDENT) Or
                  (TokenPool[P].Kind = TK_KEYWORD)) Then
                Inc(P);
            End
            { String[N] }
            Else If (TokenPool[P].Kind = TK_KEYWORD) And (L = 'string') Then
            Begin
              FTIdx := TypeFindByName('String');
              Inc(P);
              If (P < TokenCount) And (TokenPool[P].Val = '[') Then
              Begin
                While (P < TokenCount) And
                      Not ((TokenPool[P].Val = ']')) Do
                  Inc(P);
                If P < TokenCount Then Inc(P);
              End;
            End
            { Type simple }
            Else If (TokenPool[P].Kind = TK_IDENT) Or
                    (TokenPool[P].Kind = TK_KEYWORD) Then
            Begin
              FTypeName := TokenPool[P].Val;
              FTIdx := TypeFindByName(FTypeName);
              Inc(P);
            End;
          End;
          { Mettre a jour les champs collectes }
          For I := FCount - 1 DownTo 0 Do
          Begin
            If FTypes[I] = -1 Then
              FTypes[I] := FTIdx;
          End;
        End;

        { Consommer ; }
        If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
           (TokenPool[P].Val = ';') Then
          Inc(P);
      End
      Else
        Inc(P);
    End
    Else
      Inc(P);
  End;

  { Creer le type dans la table }
  TIdx := TypeAdd(TYK_RECORD, TName, FCount * 2, 'object', '{}');
  If TIdx >= 0 Then
  Begin
    For I := 0 To FCount - 1 Do
      TypeAddField(TIdx, FNames[I], FTypes[I]);
  End;

  { Construire la valeur par defaut JS }
  JSFields := '';
  For I := 0 To FCount - 1 Do
  Begin
    If I > 0 Then JSFields := JSFields + ', ';
    JSFields := JSFields + FNames[I] + ': ' + TypeDefaultJS(FTypes[I]);
  End;

  { Mettre a jour le JSDefault du type }
  If TIdx >= 0 Then
    TypeTab[TIdx].JSDefault := '{' + JSFields + '}';

  { Emettre la fonction constructeur JS }
  EmitLine('function _TPT_' + TName + '() {');
  IndentPush;
  EmitLine('return {' + JSFields + '};');
  IndentPop;
  EmitLine('}');

  ParseTypeRecord := TIdx;
End;

{ ---- ParseTypeSet : parser SET OF T ------------------------ }
{ P pointe sur le token suivant SET.                             }
{ Retourne l index du type cree dans TypeTab.                    }
Function ParseTypeSet(Var P : Integer; Const TName : TString) : Integer;
Var
  TIdx     : Integer;
  ElemType : TString;
  ElemTIdx : Integer;
Begin
  ElemType := '';
  ElemTIdx := -1;

  { Consommer OF }
  If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
     (StrLowerCase(TokenPool[P].Val) = 'of') Then
    Inc(P);

  { Lire le type des elements }
  If (P < TokenCount) And
     ((TokenPool[P].Kind = TK_IDENT) Or
      (TokenPool[P].Kind = TK_KEYWORD)) Then
  Begin
    ElemType := TokenPool[P].Val;
    ElemTIdx := TypeFindByName(ElemType);
    Inc(P);
    { Gerer sous-intervalle inline : lo..hi }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = '..') Then
    Begin
      Inc(P);
      If P < TokenCount Then Inc(P);
    End;
  End;

  { Creer le type dans la table }
  TIdx := TypeAdd(TYK_SET, TName, 32, 'Set', 'new Set()');
  If TIdx >= 0 Then
    TypeTab[TIdx].BaseTypeIdx := ElemTIdx;

  { Emettre un commentaire JS }
  EmitComment('type ' + TName + ' = Set of ' + ElemType);

  ParseTypeSet := TIdx;
End;

{ ---- ParseTypeString : parser STRING[N] -------------------- }
{ P pointe sur le token suivant STRING.                          }
{ Retourne l index du type cree dans TypeTab.                    }
Function ParseTypeString(Var P : Integer; Const TName : TString) : Integer;
Var
  TIdx   : Integer;
  MaxLen : Integer;
Begin
  MaxLen := 255;

  { Parser [N] optionnel }
  If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
     (TokenPool[P].Val = '[') Then
  Begin
    Inc(P); { consommer [ }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_INTEGER) Then
    Begin
      MaxLen := TokenPool[P].IntVal;
      Inc(P);
    End
    Else If (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Then
    Begin
      MaxLen := ConstFindIntVal(TokenPool[P].Val, 255);
      Inc(P);
    End;
    If (P < TokenCount) And (TokenPool[P].Val = ']') Then
      Inc(P); { consommer ] }
  End;

  { Creer le type dans la table }
  TIdx := TypeAdd(TYK_STRING, TName, MaxLen + 1, 'string', '""');

  { Emettre un commentaire JS }
  EmitComment('type ' + TName + ' = String[' + IntToStr_(MaxLen) + ']');

  ParseTypeString := TIdx;
End;

{ ============================================================
  TODO 17 - OBJETS ET HERITAGE (OBJECT) [IMPLEMENTE]
  ============================================================ }
{ Types OBJECT Turbo Pascal -> classes JavaScript ES6.           }
{ TYPE TNom = OBJECT [(TParent)]                                 }
{   champ1: T1;                                                  }
{   CONSTRUCTOR Init(params);                                    }
{   DESTRUCTOR Done; VIRTUAL;                                    }
{   PROCEDURE Method(params); VIRTUAL;                           }
{   FUNCTION Func(params): T; VIRTUAL;                           }
{ END;                                                           }
(* -> class TNom [extends TParent] { constructor() ... }          *)
(* INHERITED -> super.method() en JS                              *)
(* NEW(Ptr, Init(args)) -> Ptr = new TNom(args)                  *)
(* DISPOSE(Ptr, Done) -> Ptr.Done(); Ptr = null                  *)

{ ---- ParseTypeObject : parser OBJECT [(TParent)] ... END ---- }
{ P pointe sur le token suivant OBJECT.                          }
{ Retourne l index du type cree dans TypeTab.                    }
Function ParseTypeObject(Var P : Integer; Const TName : TString) : Integer;
Var
  TIdx       : Integer;
  ParentName : TString;
  FNames     : Array[0..MAX_FIELD - 1] Of TString;
  FTypes     : Array[0..MAX_FIELD - 1] Of Integer;
  FCount     : Integer;
  MNames     : Array[0..MAX_FIELD - 1] Of TString;
  MKinds     : Array[0..MAX_FIELD - 1] Of TString;
  MParams    : Array[0..MAX_FIELD - 1] Of TString;
  MRetTypes  : Array[0..MAX_FIELD - 1] Of TString;
  MCount     : Integer;
  Depth      : Integer;
  L          : TString;
  FName      : TString;
  FTIdx      : Integer;
  FTypeName  : TString;
  MethName   : TString;
  MethKind   : TString;
  ParamStr_  : TString;
  RetType    : TString;
  I          : Integer;
  JSFields   : TString;
  InPrivate  : Boolean;
Begin
  ParentName := '';
  FCount := 0;
  MCount := 0;
  InPrivate := False;

  { Parser le parent optionnel : OBJECT(TParent) }
  If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
     (TokenPool[P].Val = '(') Then
  Begin
    Inc(P); { consommer ( }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Then
    Begin
      ParentName := TokenPool[P].Val;
      Inc(P);
    End;
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = ')') Then
      Inc(P); { consommer ) }
  End;

  { Parser les membres de l objet jusqu au END }
  Depth := 1;
  While (P < TokenCount) And (Depth > 0) Do
  Begin
    L := StrLowerCase(TokenPool[P].Val);

    { Verifier END }
    If (TokenPool[P].Kind = TK_KEYWORD) And (L = 'end') Then
    Begin
      Dec(Depth);
      Inc(P);
      Continue;
    End;

    { Verifier PRIVATE }
    If ((TokenPool[P].Kind = TK_DIRECTIVE) Or
        (TokenPool[P].Kind = TK_IDENT)) And (L = 'private') Then
    Begin
      InPrivate := True;
      Inc(P);
      Continue;
    End;
    { Verifier PUBLIC }
    If ((TokenPool[P].Kind = TK_DIRECTIVE) Or
        (TokenPool[P].Kind = TK_IDENT)) And (L = 'public') Then
    Begin
      InPrivate := False;
      Inc(P);
      Continue;
    End;

    { CONSTRUCTOR / DESTRUCTOR / PROCEDURE / FUNCTION }
    If (TokenPool[P].Kind = TK_KEYWORD) And
       ((L = 'constructor') Or (L = 'destructor') Or
        (L = 'procedure') Or (L = 'function')) Then
    Begin
      MethKind := L;
      Inc(P);
      { Lire le nom de la methode }
      MethName := '';
      If (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Then
      Begin
        MethName := TokenPool[P].Val;
        Inc(P);
      End;
      { Lire les parametres optionnels }
      ParamStr_ := '';
      If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
         (TokenPool[P].Val = '(') Then
      Begin
        Inc(P); { consommer ( }
        While (P < TokenCount) And
              Not ((TokenPool[P].Kind = TK_PUNCT) And
                   (TokenPool[P].Val = ')')) Do
        Begin
          { Sauter les qualificateurs VAR / CONST }
          If (TokenPool[P].Kind = TK_KEYWORD) And
             ((StrLowerCase(TokenPool[P].Val) = 'var') Or
              (StrLowerCase(TokenPool[P].Val) = 'const')) Then
          Begin
            Inc(P);
            Continue;
          End;
          { Collecter les noms de parametres (ident avant , ou :) }
          If (TokenPool[P].Kind = TK_IDENT) And
             (P + 1 < TokenCount) And
             ((TokenPool[P + 1].Val = ',') Or
              (TokenPool[P + 1].Val = ':') Or
              (TokenPool[P + 1].Val = ')')) Then
          Begin
            If ParamStr_ <> '' Then ParamStr_ := ParamStr_ + ', ';
            ParamStr_ := ParamStr_ + TokenPool[P].Val;
            Inc(P);
            { Consommer , si present }
            If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
               (TokenPool[P].Val = ',') Then
              Inc(P);
          End
          { Sauter : Type et ; separateur }
          Else If (TokenPool[P].Kind = TK_PUNCT) And
                  (TokenPool[P].Val = ':') Then
          Begin
            Inc(P); { consommer : }
            { Sauter le nom du type }
            If (P < TokenCount) And
               ((TokenPool[P].Kind = TK_IDENT) Or
                (TokenPool[P].Kind = TK_KEYWORD)) Then
              Inc(P);
          End
          Else If (TokenPool[P].Kind = TK_PUNCT) And
                  (TokenPool[P].Val = ';') Then
            Inc(P)
          Else
            Inc(P);
        End;
        If (P < TokenCount) And (TokenPool[P].Val = ')') Then
          Inc(P); { consommer ) }
      End;
      { Lire le type de retour pour FUNCTION }
      RetType := '';
      If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
         (TokenPool[P].Val = ':') Then
      Begin
        Inc(P); { consommer : }
        If (P < TokenCount) And
           ((TokenPool[P].Kind = TK_IDENT) Or
            (TokenPool[P].Kind = TK_KEYWORD)) Then
        Begin
          RetType := TokenPool[P].Val;
          Inc(P);
        End;
      End;
      { Consommer ; }
      If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
         (TokenPool[P].Val = ';') Then
        Inc(P);
      { Consommer VIRTUAL; si present (TK_DIRECTIVE ou TK_IDENT) }
      If (P < TokenCount) And
         ((TokenPool[P].Kind = TK_DIRECTIVE) Or
          (TokenPool[P].Kind = TK_IDENT)) And
         (StrLowerCase(TokenPool[P].Val) = 'virtual') Then
      Begin
        Inc(P);
        If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
           (TokenPool[P].Val = ';') Then
          Inc(P);
      End;
      { Consommer ABSTRACT; si present }
      If (P < TokenCount) And
         ((TokenPool[P].Kind = TK_DIRECTIVE) Or
          (TokenPool[P].Kind = TK_IDENT)) And
         (StrLowerCase(TokenPool[P].Val) = 'abstract') Then
      Begin
        Inc(P);
        If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
           (TokenPool[P].Val = ';') Then
          Inc(P);
      End;
      { Enregistrer la methode }
      If MCount < MAX_FIELD Then
      Begin
        MNames[MCount] := MethName;
        MKinds[MCount] := MethKind;
        MParams[MCount] := ParamStr_;
        MRetTypes[MCount] := RetType;
        Inc(MCount);
      End;
      Continue;
    End;

    { Champs de donnees : nom1, nom2 : Type }
    If (TokenPool[P].Kind = TK_IDENT) And (Depth = 1) Then
    Begin
      If (P + 1 < TokenCount) And
         ((TokenPool[P + 1].Val = ',') Or (TokenPool[P + 1].Val = ':')) Then
      Begin
        { Collecter les noms }
        While (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Do
        Begin
          If FCount < MAX_FIELD Then
          Begin
            FNames[FCount] := TokenPool[P].Val;
            FTypes[FCount] := -1;
            Inc(FCount);
          End;
          Inc(P);
          If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
             (TokenPool[P].Val = ',') Then
            Inc(P)
          Else
            Break;
        End;
        { Attendre : Type }
        If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
           (TokenPool[P].Val = ':') Then
        Begin
          Inc(P); { consommer : }
          FTIdx := -1;
          If (P < TokenCount) And
             ((TokenPool[P].Kind = TK_IDENT) Or
              (TokenPool[P].Kind = TK_KEYWORD)) Then
          Begin
            FTypeName := TokenPool[P].Val;
            FTIdx := TypeFindByName(FTypeName);
            Inc(P);
          End;
          For I := FCount - 1 DownTo 0 Do
          Begin
            If FTypes[I] = -1 Then
              FTypes[I] := FTIdx;
          End;
        End;
        { Consommer ; }
        If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
           (TokenPool[P].Val = ';') Then
          Inc(P);
        Continue;
      End;
    End;

    { Token non reconnu : avancer }
    Inc(P);
  End;

  { Creer le type dans la table }
  TIdx := TypeAdd(TYK_OBJECT, TName, FCount * 2, 'class', 'null');
  If TIdx >= 0 Then
  Begin
    For I := 0 To FCount - 1 Do
      TypeAddField(TIdx, FNames[I], FTypes[I]);
    If ParentName <> '' Then
      TypeTab[TIdx].BaseTypeIdx := TypeFindByName(ParentName);
  End;

  { Emettre la classe JavaScript }
  If ParentName <> '' Then
    EmitLine('class ' + TName + ' extends ' + ParentName + ' {')
  Else
    EmitLine('class ' + TName + ' {');
  IndentPush;

  { Emettre un constructeur par defaut si aucun constructor declare }
  { Ce constructeur initialise les champs avec les valeurs par defaut }
  JSFields := '';
  For I := 0 To FCount - 1 Do
  Begin
    If I > 0 Then JSFields := JSFields + ' ';
    JSFields := JSFields + 'this.' + FNames[I] + ' = ' +
                TypeDefaultJS(FTypes[I]) + ';';
  End;

  { Verifier si un constructeur est declare }
  FTIdx := -1;
  For I := 0 To MCount - 1 Do
  Begin
    If MKinds[I] = 'constructor' Then
    Begin
      FTIdx := I;
      Break;
    End;
  End;

  If FTIdx < 0 Then
  Begin
    { Pas de constructeur declare : generer un constructeur par defaut }
    EmitLine('constructor() {');
    IndentPush;
    If ParentName <> '' Then
      EmitLine('super();');
    For I := 0 To FCount - 1 Do
      EmitLine('this.' + FNames[I] + ' = ' + TypeDefaultJS(FTypes[I]) + ';');
    IndentPop;
    EmitLine('}');
  End;

  { Emettre les stubs de methodes (le corps sera genere dans           }
  { les implementations TypeName.MethodName)                            }
  For I := 0 To MCount - 1 Do
  Begin
    If MKinds[I] = 'constructor' Then
    Begin
      { Le constructeur sera emis lors de l implementation }
      EmitComment('constructor ' + MNames[I] +
                  '(' + MParams[I] + ') - implementation attendue');
    End
    Else If MKinds[I] = 'destructor' Then
    Begin
      EmitComment('destructor ' + MNames[I] + ' - implementation attendue');
    End
    Else If MKinds[I] = 'function' Then
    Begin
      EmitComment('method ' + MNames[I] +
                  '(' + MParams[I] + '): ' + MRetTypes[I] +
                  ' - implementation attendue');
    End
    Else
    Begin
      EmitComment('method ' + MNames[I] +
                  '(' + MParams[I] + ') - implementation attendue');
    End;
    { Enregistrer la methode dans la table des symboles }
    SymAdd(TName + '.' + MNames[I], SK_METHOD, TIdx);
  End;

  IndentPop;
  EmitLine('}');
  EmitBlankLine;

  ParseTypeObject := TIdx;
End;


{ Forward declarations pour methodes d objets (TODO 17) }
Procedure ParseMethodImpl(Var P : Integer; IsFunc : Boolean); Forward;
Function IsMethodImpl(P : Integer) : Boolean; Forward;

{ ---- ParseTypeSection : parser une section TYPE ------------- }
{ TYPE nom = definition;                                         }
{ Genere du code JS pour les types structures (TODO 16).         }
Procedure ParseTypeSection(Var P : Integer);
Var
  TName    : TString;
  L        : TString;
  TIdx     : Integer;
  Depth    : Integer;
  BaseTIdx : Integer;
Begin
  If P >= TokenCount Then Exit;
  If (TokenPool[P].Kind <> TK_KEYWORD) Or
     (StrLowerCase(TokenPool[P].Val) <> 'type') Then Exit;
  Inc(P); { consommer TYPE }

  While P < TokenCount Do
  Begin
    { Verifier si on est sur un autre mot-cle de section ou BEGIN }
    If TokenPool[P].Kind = TK_KEYWORD Then
    Begin
      L := StrLowerCase(TokenPool[P].Val);
      If (L = 'const') Or (L = 'var') Or (L = 'type') Or
         (L = 'label') Or (L = 'begin') Or
         (L = 'procedure') Or (L = 'function') Or
         (L = 'constructor') Or (L = 'destructor') Then
        Exit;
    End;

    { Attendre un identificateur }
    If TokenPool[P].Kind <> TK_IDENT Then
    Begin
      Inc(P);
      Continue;
    End;

    TName := TokenPool[P].Val;
    Inc(P);

    { Attendre = }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_OP) And
       (TokenPool[P].Val = '=') Then
    Begin
      Inc(P); { consommer = }

      If P >= TokenCount Then Continue;
      L := StrLowerCase(TokenPool[P].Val);

      { ARRAY[lo..hi] OF T }
      If (TokenPool[P].Kind = TK_KEYWORD) And (L = 'array') Then
      Begin
        Inc(P); { consommer ARRAY }
        TIdx := ParseTypeArray(P, TName);
        SymAdd(TName, SK_TYPE, TIdx);
      End
      { RECORD ... END }
      Else If (TokenPool[P].Kind = TK_KEYWORD) And (L = 'record') Then
      Begin
        Inc(P); { consommer RECORD }
        TIdx := ParseTypeRecord(P, TName);
        SymAdd(TName, SK_TYPE, TIdx);
      End
      { SET OF T }
      Else If (TokenPool[P].Kind = TK_KEYWORD) And (L = 'set') Then
      Begin
        Inc(P); { consommer SET }
        TIdx := ParseTypeSet(P, TName);
        SymAdd(TName, SK_TYPE, TIdx);
      End
      { STRING[N] }
      Else If (TokenPool[P].Kind = TK_KEYWORD) And (L = 'string') Then
      Begin
        Inc(P); { consommer STRING }
        TIdx := ParseTypeString(P, TName);
        SymAdd(TName, SK_TYPE, TIdx);
      End
      { OBJECT [(TParent)] ... END (TODO 17) }
      Else If (TokenPool[P].Kind = TK_KEYWORD) And (L = 'object') Then
      Begin
        Inc(P); { consommer OBJECT }
        TIdx := ParseTypeObject(P, TName);
        SymAdd(TName, SK_TYPE, TIdx);
      End
      { ^BaseType (pointeur) }
      Else If (TokenPool[P].Kind = TK_OP) And (TokenPool[P].Val = '^') Then
      Begin
        Inc(P); { consommer ^ }
        If (P < TokenCount) And
           ((TokenPool[P].Kind = TK_IDENT) Or
            (TokenPool[P].Kind = TK_KEYWORD)) Then
        Begin
          BaseTIdx := TypeFindByName(TokenPool[P].Val);
          Inc(P);
        End
        Else
          BaseTIdx := -1;
        TIdx := TypeAdd(TYK_POINTER, TName, 4, 'object', 'null');
        If TIdx >= 0 Then
          TypeTab[TIdx].BaseTypeIdx := BaseTIdx;
        SymAdd(TName, SK_TYPE, TIdx);
        EmitComment('type ' + TName + ' = ^...');
      End
      { Alias de type simple : T = ExistingType }
      Else If (TokenPool[P].Kind = TK_IDENT) Or
              (TokenPool[P].Kind = TK_KEYWORD) Then
      Begin
        BaseTIdx := TypeFindByName(TokenPool[P].Val);
        Inc(P);
        If BaseTIdx >= 0 Then
        Begin
          TIdx := TypeAdd(TypeTab[BaseTIdx].Kind, TName,
                         TypeTab[BaseTIdx].Size,
                         TypeTab[BaseTIdx].JSType,
                         TypeTab[BaseTIdx].JSDefault);
          SymAdd(TName, SK_TYPE, TIdx);
          EmitComment('type ' + TName + ' = ' +
                      TypeTab[BaseTIdx].Name);
        End
        Else
        Begin
          { Type inconnu, enregistrer comme alias generique }
          TIdx := TypeAdd(TYK_INTEGER, TName, 2, 'any', 'null');
          SymAdd(TName, SK_TYPE, TIdx);
          EmitComment('type ' + TName + ' = ...');
        End;
      End
      Else
      Begin
        { Definition non reconnue : sauter jusqu au ; }
        SymAdd(TName, SK_TYPE, -1);
        EmitComment('type ' + TName + ' = ...');
        Depth := 0;
        While P < TokenCount Do
        Begin
          If (TokenPool[P].Kind = TK_KEYWORD) And
             ((StrLowerCase(TokenPool[P].Val) = 'record') Or
              (StrLowerCase(TokenPool[P].Val) = 'object')) Then
            Inc(Depth)
          Else If (TokenPool[P].Kind = TK_KEYWORD) And
                  (StrLowerCase(TokenPool[P].Val) = 'end') Then
          Begin
            If Depth > 0 Then Dec(Depth);
          End;
          If (Depth = 0) And (TokenPool[P].Kind = TK_PUNCT) And
             (TokenPool[P].Val = ';') Then
            Break;
          Inc(P);
        End;
      End;

      { Consommer ; final }
      If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
         (TokenPool[P].Val = ';') Then
        Inc(P);
    End
    Else
    Begin
      { Pas de = : erreur de syntaxe, avancer jusqu au ; }
      While (P < TokenCount) And
            Not ((TokenPool[P].Kind = TK_PUNCT) And
                 (TokenPool[P].Val = ';')) Do
        Inc(P);
      If P < TokenCount Then Inc(P);
    End;
  End;
End;

{ ---- ParseLabelSection : parser une section LABEL ----------- }
{ LABEL label1, label2, ...;                                     }
{ Enregistre les labels dans la table des symboles (TODO 13).    }
Procedure ParseLabelSection(Var P : Integer);
Var
  LblName : TString;
Begin
  If P >= TokenCount Then Exit;
  If (TokenPool[P].Kind <> TK_KEYWORD) Or
     (StrLowerCase(TokenPool[P].Val) <> 'label') Then Exit;
  Inc(P); { consommer LABEL }
  EmitComment('label section');
  { Parser les noms de labels separes par des virgules }
  While (P < TokenCount) And
        Not ((TokenPool[P].Kind = TK_PUNCT) And
             (TokenPool[P].Val = ';')) Do
  Begin
    If (TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = ',') Then
    Begin
      Inc(P);
      Continue;
    End;
    If (TokenPool[P].Kind = TK_IDENT) Or
       (TokenPool[P].Kind = TK_INTEGER) Then
    Begin
      LblName := TokenPool[P].Val;
      SymAdd(LblName, SK_LABEL, -1);
      Inc(P);
    End
    Else
      Inc(P);
  End;
  If P < TokenCount Then Inc(P);
End;

{ Forward declarations pour procedures et fonctions (TODO 15) }
Procedure ParseProcDecl(Var P : Integer); Forward;
Procedure ParseFuncDecl(Var P : Integer); Forward;

{ ---- ParseDeclSections : parser les sections de declaration - }
{ Boucle sur CONST, TYPE, VAR, LABEL, PROCEDURE, FUNCTION.      }
{ Plusieurs sections de chaque type autorisees.                  }
Procedure ParseDeclSections(Var P : Integer);
Var
  L : TString;
Begin
  While P < TokenCount Do
  Begin
    If TokenPool[P].Kind <> TK_KEYWORD Then Exit;
    L := StrLowerCase(TokenPool[P].Val);
    If L = 'const' Then
      ParseConstSection(P)
    Else If L = 'var' Then
      ParseVarSection(P)
    Else If L = 'type' Then
      ParseTypeSection(P)
    Else If L = 'label' Then
      ParseLabelSection(P)
    Else If (L = 'procedure') Or (L = 'function') Or
            (L = 'constructor') Or (L = 'destructor') Then
    Begin
      { Verifier si c est une implementation de methode (TODO 17) }
      If IsMethodImpl(P) Then
        ParseMethodImpl(P, (L = 'function'))
      Else If L = 'procedure' Then
        ParseProcDecl(P)
      Else If L = 'function' Then
        ParseFuncDecl(P)
      Else If L = 'constructor' Then
        ParseMethodImpl(P, False)
      Else If L = 'destructor' Then
        ParseMethodImpl(P, False);
    End
    Else
      Exit; { mot-cle non reconnu comme section de declaration }
  End;
End;

{ ============================================================
  TODO 12 - ENTREES/SORTIES [IMPLEMENTE]
  ============================================================ }
{ Write/WriteLn avec formatage (expr:Width et expr:Width:Decimals). }
{ Read/ReadLn avec generation de code JavaScript reel.              }
{ Str avec formatage optionnel. Val avec code d erreur.             }

{ ---- ParseWriteArg : parser un argument de Write/WriteLn ----- }
{ Gere expr, expr:Width, et expr:Width:Decimals.                   }
{ Retourne la representation JS formatee de l argument.            }
Function ParseWriteArg(Var P : Integer) : TString;
Var
  Expr   : TString;
  Width  : TString;
  Decs   : TString;
Begin
  Expr := ParseExpr(P);
  Width := '';
  Decs := '';

  { Verifier si un format :Width suit }
  If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
     (TokenPool[P].Val = ':') Then
  Begin
    Inc(P); { consommer : }
    Width := ParseExpr(P);

    { Verifier si :Decimals suit }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = ':') Then
    Begin
      Inc(P); { consommer : }
      Decs := ParseExpr(P);
    End;
  End;

  { Generer le code JS selon le format }
  If (Width <> '') And (Decs <> '') Then
    { expr:Width:Decs -> expr.toFixed(Decs).padStart(Width) }
    ParseWriteArg := Expr + '.toFixed(' + Decs + ').padStart(' + Width + ')'
  Else If Width <> '' Then
    { expr:Width -> String(expr).padStart(Width) }
    ParseWriteArg := 'String(' + Expr + ').padStart(' + Width + ')'
  Else
    { expr -> expr tel quel }
    ParseWriteArg := Expr;
End;

{ ---- ParseWriteStmt : parser Write(...) ou WriteLn(...) ------ }
{ Gere les arguments multiples avec formatage optionnel.          }
{ IsLn=true pour WriteLn (console.log), false pour Write.         }
Procedure ParseWriteStmt(Var P : Integer; IsLn : Boolean);
Var
  JS     : TString;
  ArgJS  : TString;
  ArgCnt : Integer;
Begin
  Inc(P); { consommer Write/WriteLn }

  JS := '';
  ArgCnt := 0;

  If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
     (TokenPool[P].Val = '(') Then
  Begin
    Inc(P); { consommer ( }
    While (P < TokenCount) And
          Not ((TokenPool[P].Kind = TK_PUNCT) And
               (TokenPool[P].Val = ')')) Do
    Begin
      If (TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = ',') Then
      Begin
        Inc(P);
        Continue;
      End;
      ArgJS := ParseWriteArg(P);
      If JS <> '' Then
      Begin
        { Parentheser l argument pour preserver la precedence JS }
        { Evite "text" + 10 + 20 -> "text1020" au lieu de "text30" }
        JS := JS + ' + (' + ArgJS + ')';
      End
      Else
        JS := ArgJS;
      Inc(ArgCnt);
    End;
    If (P < TokenCount) And (TokenPool[P].Val = ')') Then
      Inc(P);
  End;

  If IsLn Then
  Begin
    If ArgCnt = 0 Then
      EmitLine('console.log("");')
    Else
      EmitLine('console.log(' + JS + ');');
  End
  Else
  Begin
    If ArgCnt = 0 Then
      EmitLine('process.stdout.write("");')
    Else
      EmitLine('process.stdout.write(String(' + JS + '));');
  End;
End;

{ ---- ParseReadStmt : parser Read(...) ou ReadLn(...) --------- }
{ Gere la lecture de variables depuis l entree standard.           }
{ IsLn=true pour ReadLn, false pour Read.                         }
Procedure ParseReadStmt(Var P : Integer; IsLn : Boolean);
Var
  VarName : TString;
  SI      : Integer;
  TI      : Integer;
  TK      : TTypeKind;
Begin
  Inc(P); { consommer Read/ReadLn }

  If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
     (TokenPool[P].Val = '(') Then
  Begin
    Inc(P); { consommer ( }
    While (P < TokenCount) And
          Not ((TokenPool[P].Kind = TK_PUNCT) And
               (TokenPool[P].Val = ')')) Do
    Begin
      If (TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = ',') Then
      Begin
        Inc(P);
        Continue;
      End;

      If (TokenPool[P].Kind = TK_IDENT) Then
      Begin
        VarName := TokenPool[P].Val;
        Inc(P);

        { Determiner le type de la variable pour choisir la conversion }
        TK := TYK_INTEGER;
        SI := SymFind(VarName);
        If SI >= 0 Then
        Begin
          TI := SymTab[SI].TypeIdx;
          If (TI >= 0) And (TI < TypeCount) Then
            TK := TypeTab[TI].Kind;
        End;

        Case TK Of
          TYK_INTEGER, TYK_BYTE, TYK_WORD, TYK_SHORTINT, TYK_LONGINT:
            EmitLine(VarName + ' = parseInt(prompt(""), 10);');
          TYK_REAL, TYK_SINGLE, TYK_DOUBLE, TYK_EXTENDED, TYK_COMP:
            EmitLine(VarName + ' = parseFloat(prompt(""));');
          TYK_CHAR:
            EmitLine(VarName + ' = prompt("").charAt(0);');
          TYK_STRING:
            EmitLine(VarName + ' = prompt("");');
        Else
          EmitLine(VarName + ' = prompt("");');
        End;
      End
      Else
        Inc(P); { sauter token inconnu }
    End;
    If (P < TokenCount) And (TokenPool[P].Val = ')') Then
      Inc(P);
  End
  Else
  Begin
    { ReadLn sans arguments : juste lire une ligne }
    If IsLn Then
      EmitLine('prompt("");');
  End;
End;

{ ============================================================
  TODO 13 - IF / CASE / GOTO [IMPLEMENTE]
  ============================================================ }
{ ParseIfStmt : IF cond THEN stmt [ELSE [IF ...]] avec chaines }
{ ParseCaseStmt : CASE expr OF ... END avec intervalles lo..hi  }
{ ParseGotoStmt : GOTO label (traduction limitee en JS)         }
{ Labels en corps : ident: reconnu et emis en commentaire JS    }

{ ---- ParseBeginEnd : parser BEGIN ... END. ------------------- }
{ Corps principal du programme -> contenu de _main()             }
{ Emet les instructions du corps principal en JavaScript.        }

{ Forward declaration pour recursion mutuelle }
Procedure ParseStmt(Var P : Integer); Forward;

{ ---- ParseStmtBlock : parser un bloc BEGIN...END ------------- }
Procedure ParseStmtBlock(Var P : Integer);
Begin
  If P >= TokenCount Then Exit;
  If (TokenPool[P].Kind = TK_KEYWORD) And
     (StrLowerCase(TokenPool[P].Val) = 'begin') Then
  Begin
    Inc(P); { consommer BEGIN }
    While (P < TokenCount) And
          Not ((TokenPool[P].Kind = TK_KEYWORD) And
               (StrLowerCase(TokenPool[P].Val) = 'end')) Do
    Begin
      ParseStmt(P);
      { Consommer ; si present }
      If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
         (TokenPool[P].Val = ';') Then
        Inc(P);
    End;
    If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
       (StrLowerCase(TokenPool[P].Val) = 'end') Then
      Inc(P);
  End
  Else
    { Une seule instruction }
    ParseStmt(P);
End;

{ ---- ParseIfStmt : parser IF...THEN...ELSE [IF...] --------- }
{ Gere les chaines ELSE IF sans imbrication excessive.           }
{ Genere: if (cond) ... else if (cond) ... else ...             }
Procedure ParseIfStmt(Var P : Integer);
Var
  JS    : TString;
  First : Boolean;
Begin
  First := True;
  While P < TokenCount Do
  Begin
    Inc(P); { consommer IF }
    JS := ExprToJS(P);
    { Consommer THEN }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
       (StrLowerCase(TokenPool[P].Val) = 'then') Then
      Inc(P);
    If First Then
    Begin
      EmitLine('if (' + JS + ') {');
      First := False;
    End
    Else
      EmitLine('} else if (' + JS + ') {');
    IndentPush;
    ParseStmtBlock(P);
    IndentPop;
    { Consommer ; optionnel avant ELSE }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = ';') Then
    Begin
      { Verifier si ELSE suit }
      If (P + 1 < TokenCount) And (TokenPool[P + 1].Kind = TK_KEYWORD) And
         (StrLowerCase(TokenPool[P + 1].Val) = 'else') Then
        Inc(P) { consommer ; avant else }
    End;
    { ELSE optionnel }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
       (StrLowerCase(TokenPool[P].Val) = 'else') Then
    Begin
      Inc(P); { consommer ELSE }
      { ELSE IF chaine }
      If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
         (StrLowerCase(TokenPool[P].Val) = 'if') Then
        Continue { boucler pour parser le IF suivant }
      Else
      Begin
        { ELSE simple }
        EmitLine('} else {');
        IndentPush;
        ParseStmtBlock(P);
        IndentPop;
        Break;
      End;
    End
    Else
      Break;
  End;
  EmitLine('}');
End;

{ ---- ParseCaseStmt : parser CASE...OF...END avec intervalles - }
{ Gere les valeurs multiples (val1, val2) et intervalles (lo..hi) }
{ Genere: switch (expr) case val: ... break; default: ...       }
Procedure ParseCaseStmt(Var P : Integer);
Var
  JS   : TString;
  L    : TString;
  Lo   : LongInt;
  Hi   : LongInt;
  I    : LongInt;
Begin
  Inc(P); { consommer CASE }
  JS := ExprToJS(P);
  { Consommer OF }
  If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
     (StrLowerCase(TokenPool[P].Val) = 'of') Then
    Inc(P);
  EmitLine('switch (' + JS + ') {');
  IndentPush;
  { Parser les branches du case }
  While (P < TokenCount) And
        Not ((TokenPool[P].Kind = TK_KEYWORD) And
             ((StrLowerCase(TokenPool[P].Val) = 'end') Or
              (StrLowerCase(TokenPool[P].Val) = 'else'))) Do
  Begin
    { Lire les valeurs du case (val1, val2, lo..hi) }
    While (P < TokenCount) And
          Not ((TokenPool[P].Kind = TK_PUNCT) And
               (TokenPool[P].Val = ':')) And
          Not ((TokenPool[P].Kind = TK_KEYWORD) And
               ((StrLowerCase(TokenPool[P].Val) = 'end') Or
                (StrLowerCase(TokenPool[P].Val) = 'else'))) Do
    Begin
      If (TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = ',') Then
      Begin
        Inc(P);
        Continue;
      End;
      { Lire la valeur }
      L := ExprToJS(P);
      { Verifier si c est un intervalle lo..hi }
      If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
         (TokenPool[P].Val = '..') Then
      Begin
        Inc(P); { consommer .. }
        { Lo est deja dans L, lire Hi }
        Lo := StrToLongIntDef(L, 0);
        Hi := StrToLongIntDef(ExprToJS(P), 0);
        { Generer case pour chaque valeur de l intervalle }
        If (Hi - Lo <= 256) And (Hi >= Lo) Then
        Begin
          I := Lo;
          While I <= Hi Do
          Begin
            EmitLine('case ' + IntToStr_(I) + ':');
            Inc(I);
          End;
        End
        Else
        Begin
          { Intervalle trop grand : generer un commentaire }
          EmitLine('case ' + L + ': /* .. ' + IntToStr_(Hi) + ' */');
        End;
      End
      Else
        EmitLine('case ' + L + ':');
    End;
    { Consommer : }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = ':') Then
    Begin
      Inc(P);
      IndentPush;
      ParseStmtBlock(P);
      EmitLine('break;');
      IndentPop;
    End;
    { Consommer ; si present }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = ';') Then
      Inc(P);
  End;
  { ELSE optionnel du case }
  If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
     (StrLowerCase(TokenPool[P].Val) = 'else') Then
  Begin
    Inc(P);
    EmitLine('default:');
    IndentPush;
    While (P < TokenCount) And
          Not ((TokenPool[P].Kind = TK_KEYWORD) And
               (StrLowerCase(TokenPool[P].Val) = 'end')) Do
    Begin
      ParseStmt(P);
      If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
         (TokenPool[P].Val = ';') Then
        Inc(P);
    End;
    EmitLine('break;');
    IndentPop;
  End;
  IndentPop;
  EmitLine('}');
  { Consommer END }
  If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
     (StrLowerCase(TokenPool[P].Val) = 'end') Then
    Inc(P);
End;

{ ---- ParseGotoStmt : parser GOTO label ----------------------- }
{ GOTO est deconseille et la traduction en JS est limitee.        }
{ Genere un commentaire d avertissement en JavaScript.            }
Procedure ParseGotoStmt(Var P : Integer);
Var
  LblName : TString;
Begin
  Inc(P); { consommer GOTO }
  LblName := '';
  If P < TokenCount Then
  Begin
    If (TokenPool[P].Kind = TK_IDENT) Or
       (TokenPool[P].Kind = TK_INTEGER) Then
    Begin
      LblName := TokenPool[P].Val;
      Inc(P);
    End;
  End;
  EmitComment('GOTO ' + LblName + ' - requires manual restructuring');
End;

{ ---- ParseStmt : parser une instruction unique --------------- }
Procedure ParseStmt;
Var
  L   : TString;
  JS  : TString;
Begin
  If P >= TokenCount Then Exit;

  { Point-virgule seul : instruction vide }
  If (TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = ';') Then
    Exit;

  { END : fin de bloc - ne pas consommer }
  If (TokenPool[P].Kind = TK_KEYWORD) And
     (StrLowerCase(TokenPool[P].Val) = 'end') Then
    Exit;

  { ELSE : ne pas consommer }
  If (TokenPool[P].Kind = TK_KEYWORD) And
     (StrLowerCase(TokenPool[P].Val) = 'else') Then
    Exit;

  { UNTIL : ne pas consommer }
  If (TokenPool[P].Kind = TK_KEYWORD) And
     (StrLowerCase(TokenPool[P].Val) = 'until') Then
    Exit;

  { BEGIN ... END : bloc d instructions }
  If (TokenPool[P].Kind = TK_KEYWORD) And
     (StrLowerCase(TokenPool[P].Val) = 'begin') Then
  Begin
    Inc(P); { consommer BEGIN }
    While (P < TokenCount) And
          Not ((TokenPool[P].Kind = TK_KEYWORD) And
               (StrLowerCase(TokenPool[P].Val) = 'end')) Do
    Begin
      ParseStmt(P);
      If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
         (TokenPool[P].Val = ';') Then
        Inc(P);
    End;
    If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
       (StrLowerCase(TokenPool[P].Val) = 'end') Then
      Inc(P);
    Exit;
  End;

  { WriteLn / Write (TODO 12 : formatage et args multiples) }
  If (TokenPool[P].Kind = TK_IDENT) And
     ((StrLowerCase(TokenPool[P].Val) = 'writeln') Or
      (StrLowerCase(TokenPool[P].Val) = 'write')) Then
  Begin
    L := StrLowerCase(TokenPool[P].Val);
    ParseWriteStmt(P, L = 'writeln');
    Exit;
  End;

  { ReadLn / Read (TODO 12 : lecture depuis l entree standard) }
  If (TokenPool[P].Kind = TK_IDENT) And
     ((StrLowerCase(TokenPool[P].Val) = 'readln') Or
      (StrLowerCase(TokenPool[P].Val) = 'read')) Then
  Begin
    L := StrLowerCase(TokenPool[P].Val);
    ParseReadStmt(P, L = 'readln');
    Exit;
  End;

  { IF ... THEN ... [ELSE [IF ...]] (TODO 13) }
  If (TokenPool[P].Kind = TK_KEYWORD) And
     (StrLowerCase(TokenPool[P].Val) = 'if') Then
  Begin
    ParseIfStmt(P);
    Exit;
  End;

  { ---- TODO 14 : BOUCLES ---------------------------------------- }

  { FOR ... TO/DOWNTO ... DO ... (TODO 14) }
  If (TokenPool[P].Kind = TK_KEYWORD) And
     (StrLowerCase(TokenPool[P].Val) = 'for') Then
  Begin
    Inc(P); { consommer FOR }
    JS := '';
    If (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Then
    Begin
      L := TokenPool[P].Val; { nom de la variable de boucle }
      Inc(P);
      { Consommer := }
      If (P < TokenCount) And (TokenPool[P].Kind = TK_OP) And
         (TokenPool[P].Val = ':=') Then
        Inc(P);
      { Lire la valeur initiale }
      JS := ExprToJS(P);
      { Determiner TO ou DOWNTO }
      If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
         (StrLowerCase(TokenPool[P].Val) = 'to') Then
      Begin
        Inc(P);
        JS := 'for (var ' + L + ' = ' + JS + '; ' + L + ' <= ' +
              ExprToJS(P) + '; ' + L + '++) {';
      End
      Else If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
              (StrLowerCase(TokenPool[P].Val) = 'downto') Then
      Begin
        Inc(P);
        JS := 'for (var ' + L + ' = ' + JS + '; ' + L + ' >= ' +
              ExprToJS(P) + '; ' + L + '--) {';
      End
      Else
        JS := 'for (;;) { /* error: missing TO/DOWNTO */';
    End;
    { Consommer DO }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
       (StrLowerCase(TokenPool[P].Val) = 'do') Then
      Inc(P);
    EmitLine(JS);
    IndentPush;
    ParseStmtBlock(P);
    IndentPop;
    EmitLine('}');
    Exit;
  End;

  { WHILE ... DO ... (TODO 14) }
  If (TokenPool[P].Kind = TK_KEYWORD) And
     (StrLowerCase(TokenPool[P].Val) = 'while') Then
  Begin
    Inc(P); { consommer WHILE }
    JS := ExprToJS(P);
    { Consommer DO }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
       (StrLowerCase(TokenPool[P].Val) = 'do') Then
      Inc(P);
    EmitLine('while (' + JS + ') {');
    IndentPush;
    ParseStmtBlock(P);
    IndentPop;
    EmitLine('}');
    Exit;
  End;

  { REPEAT ... UNTIL expr (TODO 14) }
  If (TokenPool[P].Kind = TK_KEYWORD) And
     (StrLowerCase(TokenPool[P].Val) = 'repeat') Then
  Begin
    Inc(P); { consommer REPEAT }
    EmitLine('do {');
    IndentPush;
    While (P < TokenCount) And
          Not ((TokenPool[P].Kind = TK_KEYWORD) And
               (StrLowerCase(TokenPool[P].Val) = 'until')) Do
    Begin
      ParseStmt(P);
      If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
         (TokenPool[P].Val = ';') Then
        Inc(P);
    End;
    IndentPop;
    { Consommer UNTIL et l expression }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
       (StrLowerCase(TokenPool[P].Val) = 'until') Then
    Begin
      Inc(P);
      JS := ExprToJS(P);
      EmitLine('} while (!(' + JS + '));');
    End
    Else
      EmitLine('} while (true);');
    Exit;
  End;

  { CASE expr OF ... END (TODO 13) }
  If (TokenPool[P].Kind = TK_KEYWORD) And
     (StrLowerCase(TokenPool[P].Val) = 'case') Then
  Begin
    ParseCaseStmt(P);
    Exit;
  End;

  { GOTO label (TODO 13) }
  If (TokenPool[P].Kind = TK_KEYWORD) And
     (StrLowerCase(TokenPool[P].Val) = 'goto') Then
  Begin
    ParseGotoStmt(P);
    Exit;
  End;

  { Label definition : ident: (TODO 13) }
  { Detecter label: quand ident est suivi de : et non de := }
  If (TokenPool[P].Kind = TK_IDENT) And
     (P + 1 < TokenCount) And
     (TokenPool[P + 1].Kind = TK_PUNCT) And
     (TokenPool[P + 1].Val = ':') Then
  Begin
    L := TokenPool[P].Val;
    If SymFind(L) >= 0 Then
    Begin
      EmitComment('label: ' + L);
      Inc(P, 2); { consommer ident et : }
      Exit;
    End;
  End;
  { Label definition numerique : 123: }
  If (TokenPool[P].Kind = TK_INTEGER) And
     (P + 1 < TokenCount) And
     (TokenPool[P + 1].Kind = TK_PUNCT) And
     (TokenPool[P + 1].Val = ':') Then
  Begin
    L := TokenPool[P].Val;
    EmitComment('label: ' + L);
    Inc(P, 2);
    Exit;
  End;

  { Break : sortie de boucle -> break; en JS (TODO 14) }
  If (TokenPool[P].Kind = TK_IDENT) And
     (StrLowerCase(TokenPool[P].Val) = 'break') Then
  Begin
    Inc(P);
    EmitLine('break;');
    Exit;
  End;

  { Continue : iteration suivante -> continue; en JS (TODO 14) }
  If (TokenPool[P].Kind = TK_IDENT) And
     (StrLowerCase(TokenPool[P].Val) = 'continue') Then
  Begin
    Inc(P);
    EmitLine('continue;');
    Exit;
  End;

  { ---- TODO 17 : OBJETS ET HERITAGE ----------------------------- }

  { NEW(Ptr, Init(args)) -> Ptr = new TypeName(args) (TODO 17) }
  If (TokenPool[P].Kind = TK_IDENT) And
     (StrLowerCase(TokenPool[P].Val) = 'new') Then
  Begin
    Inc(P); { consommer NEW }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = '(') Then
    Begin
      Inc(P); { consommer ( }
      L := '';
      { Lire le premier argument : le pointeur }
      If (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Then
      Begin
        L := TokenPool[P].Val;
        Inc(P);
      End;
      { Verifier s il y a un deuxieme argument apres la virgule }
      If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
         (TokenPool[P].Val = ',') Then
      Begin
        Inc(P); { consommer , }
        { Deuxieme argument : Init(args) }
        JS := '';
        If (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Then
        Begin
          JS := TokenPool[P].Val;
          Inc(P);
          { Lire les arguments du constructeur }
          If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
             (TokenPool[P].Val = '(') Then
          Begin
            Inc(P); { consommer ( }
            JS := '(';
            While (P < TokenCount) And
                  Not ((TokenPool[P].Kind = TK_PUNCT) And
                       (TokenPool[P].Val = ')')) Do
            Begin
              JS := JS + TokenPool[P].Val;
              Inc(P);
            End;
            JS := JS + ')';
            If (P < TokenCount) And (TokenPool[P].Val = ')') Then
              Inc(P);
          End
          Else
            JS := '()';
        End;
        { Consommer ) externe }
        If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
           (TokenPool[P].Val = ')') Then
          Inc(P);
        { Deduire le type depuis le symbole du pointeur }
        { Chercher le type de base du pointeur pour le new }
        EmitLine(L + ' = new Object' + JS + ';');
        EmitLine(L + '.' + StrLowerCase(Copy(JS, 1, Pos('(', JS) - 1)) + ';');
      End
      Else
      Begin
        (* NEW(Ptr) simple -> Ptr = empty object *)
        If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
           (TokenPool[P].Val = ')') Then
          Inc(P);
        EmitLine(L + ' = {};');
      End;
    End
    Else
    Begin
      { new sans parentheses - traiter comme expression }
      JS := 'new ' + ExprToJS(P);
      EmitLine(JS + ';');
    End;
    Exit;
  End;

  { DISPOSE(Ptr, Done) -> Ptr.Done(); Ptr = null (TODO 17) }
  If (TokenPool[P].Kind = TK_IDENT) And
     (StrLowerCase(TokenPool[P].Val) = 'dispose') Then
  Begin
    Inc(P); { consommer DISPOSE }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = '(') Then
    Begin
      Inc(P); { consommer ( }
      L := '';
      { Lire le premier argument : le pointeur }
      If (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Then
      Begin
        L := TokenPool[P].Val;
        Inc(P);
      End;
      { Verifier s il y a un deuxieme argument : le destructeur }
      If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
         (TokenPool[P].Val = ',') Then
      Begin
        Inc(P); { consommer , }
        JS := '';
        If (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Then
        Begin
          JS := TokenPool[P].Val;
          Inc(P);
        End;
        { Consommer ) }
        If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
           (TokenPool[P].Val = ')') Then
          Inc(P);
        { Emettre l appel au destructeur puis la mise a null }
        If JS <> '' Then
          EmitLine(L + '.' + JS + '();');
        EmitLine(L + ' = null;');
      End
      Else
      Begin
        { DISPOSE(Ptr) simple -> Ptr = null }
        If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
           (TokenPool[P].Val = ')') Then
          Inc(P);
        EmitLine(L + ' = null;');
      End;
    End;
    Exit;
  End;

  { INHERITED comme instruction (sans valeur de retour) (TODO 17) }
  If (TokenPool[P].Kind = TK_KEYWORD) And
     (StrLowerCase(TokenPool[P].Val) = 'inherited') Then
  Begin
    JS := ExprToJS(P);
    EmitLine(JS + ';');
    Exit;
  End;

  { Affectation ou appel de procedure : ident [:= expr] }
  If TokenPool[P].Kind = TK_IDENT Then
  Begin
    JS := ExprToJS(P);
    EmitLine(JS + ';');
    Exit;
  End;

  { Token non reconnu : avancer }
  Inc(P);
End;

{ ============================================================
  TODO 15 - PROCEDURES ET FONCTIONS [IMPLEMENTE]
  ============================================================ }
{ Procedures et fonctions Turbo Pascal -> fonctions JavaScript. }
{ Gestion des parametres valeur, VAR, CONST, variables locales, }
{ declarations imbriquees, Forward, Result, Exit.                }

{ ---- ParseParamList : parser la liste de parametres ---------- }
{ (param1: T1; var param2: T2; const param3: T3)                 }
{ Retourne la liste des noms JS separes par virgule.             }
{ VarParams recoit les noms des parametres VAR pour le           }
{ wrapper post-appel.                                            }
Function ParseParamList(Var P : Integer) : TString;
Var
  ParamNames : Array[0..31] Of TString;
  ParamIsVar : Array[0..31] Of Boolean;
  ParamCount : Integer;
  IsVar      : Boolean;
  IsConst    : Boolean;
  L          : TString;
  I          : Integer;
  Result_    : TString;
Begin
  ParamCount := 0;
  Result_ := '';
  If P >= TokenCount Then Begin ParseParamList := ''; Exit; End;
  If Not ((TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = '(')) Then
  Begin
    ParseParamList := '';
    Exit;
  End;
  Inc(P); { consommer ( }

  While (P < TokenCount) And
        Not ((TokenPool[P].Kind = TK_PUNCT) And
             (TokenPool[P].Val = ')')) Do
  Begin
    IsVar := False;
    IsConst := False;

    { Verifier les qualificateurs VAR / CONST }
    If (TokenPool[P].Kind = TK_KEYWORD) Then
    Begin
      L := StrLowerCase(TokenPool[P].Val);
      If L = 'var' Then
      Begin
        IsVar := True;
        Inc(P);
      End
      Else If L = 'const' Then
      Begin
        IsConst := True;
        Inc(P);
      End;
    End;

    { Collecter les noms de parametres separes par des virgules }
    While (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Do
    Begin
      If ParamCount < 32 Then
      Begin
        ParamNames[ParamCount] := TokenPool[P].Val;
        ParamIsVar[ParamCount] := IsVar;
        SymAdd(TokenPool[P].Val, SK_PARAM, -1);
        Inc(ParamCount);
      End;
      Inc(P);
      If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
         (TokenPool[P].Val = ',') Then
        Inc(P)
      Else
        Break;
    End;

    { Consommer : Type }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = ':') Then
    Begin
      Inc(P); { consommer : }
      { Sauter le nom du type (simple ou array of...) }
      If (P < TokenCount) And
         ((TokenPool[P].Kind = TK_IDENT) Or
          (TokenPool[P].Kind = TK_KEYWORD)) Then
        Inc(P);
    End;

    { Consommer ; separateur entre groupes de parametres }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = ';') Then
      Inc(P);
  End;

  { Consommer ) }
  If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
     (TokenPool[P].Val = ')') Then
    Inc(P);

  { Construire la liste des parametres JS }
  For I := 0 To ParamCount - 1 Do
  Begin
    If I > 0 Then Result_ := Result_ + ', ';
    Result_ := Result_ + ParamNames[I];
  End;

  ParseParamList := Result_;
End;

{ ---- SkipDirectives : sauter les directives de routine ------- }
{ FAR, NEAR, INLINE, ASSEMBLER, EXTERNAL, FORWARD, etc.          }
{ Retourne True si FORWARD a ete trouve.                          }
Function SkipDirectives(Var P : Integer) : Boolean;
Var
  L        : TString;
  IsForward : Boolean;
Begin
  IsForward := False;
  While (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Do
  Begin
    L := StrLowerCase(TokenPool[P].Val);
    If (L = 'far') Or (L = 'near') Or (L = 'inline') Or
       (L = 'assembler') Or (L = 'external') Or (L = 'register') Or
       (L = 'cdecl') Or (L = 'stdcall') Or (L = 'pascal') Or
       (L = 'safecall') Or (L = 'overload') Or (L = 'override') Or
       (L = 'virtual') Or (L = 'abstract') Or (L = 'reintroduce') Then
    Begin
      Inc(P);
      If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
         (TokenPool[P].Val = ';') Then
        Inc(P);
    End
    Else If L = 'forward' Then
    Begin
      IsForward := True;
      Inc(P);
      If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
         (TokenPool[P].Val = ';') Then
        Inc(P);
    End
    Else
      Break;
  End;
  { Also check keywords like EXTERNAL }
  While (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) Do
  Begin
    L := StrLowerCase(TokenPool[P].Val);
    If L = 'external' Then
    Begin
      Inc(P);
      { Skip external name/index if present }
      While (P < TokenCount) And
            Not ((TokenPool[P].Kind = TK_PUNCT) And
                 (TokenPool[P].Val = ';')) Do
        Inc(P);
      If (P < TokenCount) And (TokenPool[P].Val = ';') Then
        Inc(P);
    End
    Else
      Break;
  End;
  SkipDirectives := IsForward;
End;

{ ---- ParseProcDecl : parser PROCEDURE nom[(params)]; bloc ---- }
{ PROCEDURE nom[(params)]; [directives;] [decls] BEGIN...END;    }
{ Genere : function nom(params) en JavaScript.                    }
Procedure ParseProcDecl;
Var
  ProcName   : TString;
  Params     : TString;
  L          : TString;
  IsForward_ : Boolean;
Begin
  If P >= TokenCount Then Exit;
  If (TokenPool[P].Kind <> TK_KEYWORD) Or
     (StrLowerCase(TokenPool[P].Val) <> 'procedure') Then Exit;
  Inc(P); { consommer PROCEDURE }

  { Nom de la procedure }
  ProcName := '';
  If (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Then
  Begin
    ProcName := TokenPool[P].Val;
    Inc(P);
  End;

  { Enregistrer la procedure dans la table des symboles (scope global) }
  SymAdd(ProcName, SK_PROC, -1);

  { Entrer dans la portee de la procedure }
  SymEnterScope;

  { Parser la liste de parametres }
  Params := ParseParamList(P);

  { Consommer ; }
  If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
     (TokenPool[P].Val = ';') Then
    Inc(P);

  { Verifier les directives (FORWARD, FAR, NEAR, etc.) }
  IsForward_ := SkipDirectives(P);

  If IsForward_ Then
  Begin
    { Forward : pas de corps, declaration JS differee }
    EmitComment('forward: procedure ' + ProcName);
    SymLeaveScope;
    Exit;
  End;

  { Emettre la declaration JavaScript }
  EmitLine('function ' + ProcName + '(' + Params + ') {');
  IndentPush;

  { Parser les declarations locales (CONST, TYPE, VAR, LABEL) }
  While (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) Do
  Begin
    L := StrLowerCase(TokenPool[P].Val);
    If L = 'const' Then
      ParseConstSection(P)
    Else If L = 'var' Then
      ParseVarSection(P)
    Else If L = 'type' Then
      ParseTypeSection(P)
    Else If L = 'label' Then
      ParseLabelSection(P)
    Else If L = 'procedure' Then
      ParseProcDecl(P)
    Else If L = 'function' Then
      ParseFuncDecl(P)
    Else
      Break;
  End;

  { Parser le corps BEGIN...END }
  If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
     (StrLowerCase(TokenPool[P].Val) = 'begin') Then
  Begin
    Inc(P); { consommer BEGIN }
    While (P < TokenCount) And
          Not ((TokenPool[P].Kind = TK_KEYWORD) And
               (StrLowerCase(TokenPool[P].Val) = 'end')) Do
    Begin
      ParseStmt(P);
      If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
         (TokenPool[P].Val = ';') Then
        Inc(P);
    End;
    If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
       (StrLowerCase(TokenPool[P].Val) = 'end') Then
      Inc(P);
  End;

  IndentPop;
  EmitLine('}');
  EmitBlankLine;

  { Consommer ; final }
  If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
     (TokenPool[P].Val = ';') Then
    Inc(P);

  { Quitter la portee }
  SymLeaveScope;
End;

{ ---- ParseFuncDecl : parser FUNCTION nom[(params)]: Ret; bloc }
{ FUNCTION nom[(params)]: RetType; [directives;] [decls]         }
{ BEGIN...END;                                                    }
{ Genere : function nom(params) avec var Result; return Result;  }
Procedure ParseFuncDecl;
Var
  FuncName   : TString;
  Params     : TString;
  RetType    : TString;
  L          : TString;
  IsForward_ : Boolean;
Begin
  If P >= TokenCount Then Exit;
  If (TokenPool[P].Kind <> TK_KEYWORD) Or
     (StrLowerCase(TokenPool[P].Val) <> 'function') Then Exit;
  Inc(P); { consommer FUNCTION }

  { Nom de la fonction }
  FuncName := '';
  RetType := '';
  If (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Then
  Begin
    FuncName := TokenPool[P].Val;
    Inc(P);
  End;

  { Enregistrer la fonction dans la table des symboles (scope global) }
  SymAdd(FuncName, SK_FUNC, TypeFindByName(RetType));

  { Entrer dans la portee de la fonction }
  SymEnterScope;

  { Parser la liste de parametres }
  Params := ParseParamList(P);

  { Consommer : RetType }
  RetType := '';
  If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
     (TokenPool[P].Val = ':') Then
  Begin
    Inc(P); { consommer : }
    If (P < TokenCount) And
       ((TokenPool[P].Kind = TK_IDENT) Or
        (TokenPool[P].Kind = TK_KEYWORD)) Then
    Begin
      RetType := TokenPool[P].Val;
      Inc(P);
    End;
  End;

  { Consommer ; }
  If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
     (TokenPool[P].Val = ';') Then
    Inc(P);

  { Verifier les directives (FORWARD, FAR, NEAR, etc.) }
  IsForward_ := SkipDirectives(P);

  If IsForward_ Then
  Begin
    { Forward : pas de corps, declaration JS differee }
    EmitComment('forward: function ' + FuncName);
    SymLeaveScope;
    Exit;
  End;

  { Emettre la declaration JavaScript }
  EmitLine('function ' + FuncName + '(' + Params + ') {');
  IndentPush;

  { Variable Result implicite pour stocker la valeur de retour }
  { En TP, le nom de la fonction ou Result sert de valeur retour }
  EmitLine('var Result = null;');
  SymAdd('Result', SK_VAR, TypeFindByName(RetType));

  { Parser les declarations locales (CONST, TYPE, VAR, LABEL) }
  While (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) Do
  Begin
    L := StrLowerCase(TokenPool[P].Val);
    If L = 'const' Then
      ParseConstSection(P)
    Else If L = 'var' Then
      ParseVarSection(P)
    Else If L = 'type' Then
      ParseTypeSection(P)
    Else If L = 'label' Then
      ParseLabelSection(P)
    Else If L = 'procedure' Then
      ParseProcDecl(P)
    Else If L = 'function' Then
      ParseFuncDecl(P)
    Else
      Break;
  End;

  { Parser le corps BEGIN...END }
  If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
     (StrLowerCase(TokenPool[P].Val) = 'begin') Then
  Begin
    Inc(P); { consommer BEGIN }
    While (P < TokenCount) And
          Not ((TokenPool[P].Kind = TK_KEYWORD) And
               (StrLowerCase(TokenPool[P].Val) = 'end')) Do
    Begin
      ParseStmt(P);
      If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
         (TokenPool[P].Val = ';') Then
        Inc(P);
    End;
    If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
       (StrLowerCase(TokenPool[P].Val) = 'end') Then
      Inc(P);
  End;

  { Retourner la valeur de Result a la fin }
  EmitLine('return Result;');
  IndentPop;
  EmitLine('}');
  EmitBlankLine;

  { Consommer ; final }
  If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
     (TokenPool[P].Val = ';') Then
    Inc(P);

  { Quitter la portee }
  SymLeaveScope;
End;

{ ============================================================
  TODO 17 - IMPLEMENTATIONS DE METHODES D OBJETS
  ============================================================ }

{ ---- IsMethodImpl : detecte si on est sur TypeName.MethodName }
{ Regarde si la sequence courante est PROCEDURE/FUNCTION ident.  }
{ ident, ce qui indique une implementation de methode d objet.   }
Function IsMethodImpl;
Begin
  IsMethodImpl := False;
  If P + 2 >= TokenCount Then Exit;
  If (TokenPool[P].Kind <> TK_KEYWORD) Then Exit;
  If (StrLowerCase(TokenPool[P].Val) <> 'procedure') And
     (StrLowerCase(TokenPool[P].Val) <> 'function') And
     (StrLowerCase(TokenPool[P].Val) <> 'constructor') And
     (StrLowerCase(TokenPool[P].Val) <> 'destructor') Then Exit;
  { Verifier ident . ident }
  If (TokenPool[P + 1].Kind = TK_IDENT) And
     (P + 2 < TokenCount) And
     (TokenPool[P + 2].Kind = TK_PUNCT) And
     (TokenPool[P + 2].Val = '.') Then
    IsMethodImpl := True;
End;

{ ---- ParseMethodImpl : parser une implementation de methode -- }
{ TypeName.MethodName[(params)][: RetType]; [directives;]        }
{ [decls] BEGIN ... END;                                         }
{ Insere la methode dans le prototype de la classe JS.           }
Procedure ParseMethodImpl;
Var
  TypeName : TString;
  MethName : TString;
  Params   : TString;
  RetType  : TString;
  L        : TString;
  IsCtor   : Boolean;
  IsDtor   : Boolean;
  TIdx     : Integer;
Begin
  { Sauvegarder le mot-cle pour savoir si c est constructor/destructor }
  L := StrLowerCase(TokenPool[P].Val);
  IsCtor := (L = 'constructor');
  IsDtor := (L = 'destructor');
  Inc(P); { consommer PROCEDURE/FUNCTION/CONSTRUCTOR/DESTRUCTOR }

  { Lire TypeName.MethodName }
  TypeName := '';
  MethName := '';
  If (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Then
  Begin
    TypeName := TokenPool[P].Val;
    Inc(P);
  End;
  If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
     (TokenPool[P].Val = '.') Then
  Begin
    Inc(P); { consommer . }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Then
    Begin
      MethName := TokenPool[P].Val;
      Inc(P);
    End;
  End
  Else
  Begin
    { Pas de point : c est une proc/func normale, pas une methode }
    { Rembobiner et laisser ParseProcDecl/ParseFuncDecl gerer }
    P := P - 2; { revenir avant le nom }
    Exit;
  End;

  { Entrer dans la portee }
  SymEnterScope;

  { Parser les parametres }
  Params := ParseParamList(P);

  { Parser le type de retour pour les fonctions }
  RetType := '';
  If IsFunc And (P < TokenCount) And
     (TokenPool[P].Kind = TK_PUNCT) And (TokenPool[P].Val = ':') Then
  Begin
    Inc(P); { consommer : }
    If (P < TokenCount) And
       ((TokenPool[P].Kind = TK_IDENT) Or
        (TokenPool[P].Kind = TK_KEYWORD)) Then
    Begin
      RetType := TokenPool[P].Val;
      Inc(P);
    End;
  End;

  { Consommer ; }
  If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
     (TokenPool[P].Val = ';') Then
    Inc(P);

  { Sauter les directives (VIRTUAL, FAR, etc.) }
  SkipDirectives(P);

  TIdx := TypeFindByName(TypeName);

  { Emettre la methode dans le prototype JS }
  EmitLine(TypeName + '.prototype.' + MethName + ' = function(' +
           Params + ') {');
  IndentPush;

  If IsCtor Then
    EmitComment('constructor implementation');
  If IsDtor Then
    EmitComment('destructor implementation');

  { Variable Result pour les fonctions }
  If IsFunc Then
  Begin
    EmitLine('var Result = null;');
    SymAdd('Result', SK_VAR, TypeFindByName(RetType));
    { Enregistrer le nom de la methode comme SK_METHOD dans la portee }
    { pour que l affectation MethName := valeur devienne Result = valeur }
    SymAdd(MethName, SK_METHOD, TypeFindByName(RetType));
  End;

  { Parser les declarations locales }
  While (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) Do
  Begin
    L := StrLowerCase(TokenPool[P].Val);
    If L = 'const' Then
      ParseConstSection(P)
    Else If L = 'var' Then
      ParseVarSection(P)
    Else If L = 'type' Then
      ParseTypeSection(P)
    Else If L = 'label' Then
      ParseLabelSection(P)
    Else
      Break;
  End;

  { Parser le corps BEGIN...END }
  If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
     (StrLowerCase(TokenPool[P].Val) = 'begin') Then
  Begin
    Inc(P); { consommer BEGIN }
    While (P < TokenCount) And
          Not ((TokenPool[P].Kind = TK_KEYWORD) And
               (StrLowerCase(TokenPool[P].Val) = 'end')) Do
    Begin
      ParseStmt(P);
      If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
         (TokenPool[P].Val = ';') Then
        Inc(P);
    End;
    If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
       (StrLowerCase(TokenPool[P].Val) = 'end') Then
      Inc(P);
  End;

  If IsFunc Then
    EmitLine('return Result;');
  IndentPop;
  EmitLine('};');
  EmitBlankLine;

  { Consommer ; final }
  If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
     (TokenPool[P].Val = ';') Then
    Inc(P);

  { Quitter la portee }
  SymLeaveScope;
End;

{ ---- ParseBeginEndMain : parser le bloc principal ------------ }
{ BEGIN ... END. du programme principal                           }
Procedure ParseBeginEndMain(Var P : Integer);
Begin
  If P >= TokenCount Then Exit;
  If (TokenPool[P].Kind <> TK_KEYWORD) Or
     (StrLowerCase(TokenPool[P].Val) <> 'begin') Then Exit;
  Inc(P); { consommer BEGIN }

  While (P < TokenCount) And
        Not ((TokenPool[P].Kind = TK_KEYWORD) And
             (StrLowerCase(TokenPool[P].Val) = 'end')) Do
  Begin
    ParseStmt(P);
    { Consommer ; si present }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = ';') Then
      Inc(P);
  End;

  { Consommer END }
  If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
     (StrLowerCase(TokenPool[P].Val) = 'end') Then
    Inc(P);
  { Consommer le point final . }
  If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
     (TokenPool[P].Val = '.') Then
    Inc(P);
End;

{ ---- ParseProgram : parser un programme Pascal complet ------ }
{ PROGRAM nom [(params)]; [USES ...;] [decls] BEGIN ... END.    }
{ Genere le fichier JavaScript complet.                          }
Procedure ParseProgram(Var P : Integer);
Begin
  ProgName := 'main';

  { PROGRAM nom ; }
  If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
     (StrLowerCase(TokenPool[P].Val) = 'program') Then
  Begin
    Inc(P); { consommer PROGRAM }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_IDENT) Then
    Begin
      ProgName := TokenPool[P].Val;
      Inc(P);
    End;
    { Sauter les parametres de programme (output, input) }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = '(') Then
    Begin
      While (P < TokenCount) And
            Not ((TokenPool[P].Kind = TK_PUNCT) And
                 (TokenPool[P].Val = ')')) Do
        Inc(P);
      If P < TokenCount Then Inc(P);
    End;
    { Consommer ; }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = ';') Then
      Inc(P);
  End;

  EmitComment('Program ' + ProgName);
  EmitBlankLine;

  { Section USES optionnelle }
  If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
     (StrLowerCase(TokenPool[P].Val) = 'uses') Then
  Begin
    ParseUsesClause(P);
    EmitBlankLine;
  End;

  { Sections de declaration (CONST, TYPE, VAR, LABEL) }
  ParseDeclSections(P);
  EmitBlankLine;

  { Corps principal : BEGIN ... END. }
  EmitComment('Corps principal');
  EmitLine('function _main() {');
  IndentPush;

  If (P < TokenCount) And (TokenPool[P].Kind = TK_KEYWORD) And
     (StrLowerCase(TokenPool[P].Val) = 'begin') Then
    ParseBeginEndMain(P)
  Else
    EmitComment('pas de corps principal trouve');

  IndentPop;
  EmitLine('}');
End;

Procedure Run;
Var
  I   : Integer;
  P   : Integer;
  JS  : TString;
Begin
  GlobalInit;
  ConstInit;
  ConstRegisterBuiltins;
  TypeInit;
  TypeRegisterBuiltins;
  SymInit;
  SymRegisterBuiltins;
  BuiltinSymEnd := SymCount;
  If Opts.Verbose Then ShowBanner;

  { Ouvrir le fichier source }
  Assign(LexSrcF, Opts.SrcFile);
  {$I-}
  Reset(LexSrcF);
  {$I+}
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir le fichier source: ' + Opts.SrcFile);
  LexOpened := True;

  LexInit;

  { Remplir le token pool avec tous les tokens }
  TokenPoolFill;

  { Afficher les conversions JS des litteraux en mode debug }
  If Opts.DebugMode Then
  Begin
    WriteLn('--- Litteraux -> JavaScript ---');
    For I := 0 To TokenCount - 1 Do
    Begin
      If (TokenPool[I].Kind = TK_INTEGER) Or
         (TokenPool[I].Kind = TK_REAL) Or
         (TokenPool[I].Kind = TK_STRING) Or
         (TokenPool[I].Kind = TK_CHAR) Then
        WriteLn('  ', TokenPool[I].Val, ' -> ', LitToJS(TokenPool[I]))
      Else If (TokenPool[I].Kind = TK_KEYWORD) And
              ((StrLowerCase(TokenPool[I].Val) = 'true') Or
               (StrLowerCase(TokenPool[I].Val) = 'false') Or
               (StrLowerCase(TokenPool[I].Val) = 'nil')) Then
        WriteLn('  ', TokenPool[I].Val, ' -> ', LitToJS(TokenPool[I]))
      Else If (TokenPool[I].Kind = TK_IDENT) And
              ((StrLowerCase(TokenPool[I].Val) = 'true') Or
               (StrLowerCase(TokenPool[I].Val) = 'false')) Then
        WriteLn('  ', TokenPool[I].Val, ' -> ', LitToJS(TokenPool[I]));
    End;
    WriteLn('--- Fin des litteraux ---');

    { Afficher les conversions d operateurs }
    WriteLn('--- Operateurs -> JavaScript ---');
    WriteLn('  :=  -> ', OpToJS(':='));
    WriteLn('  =   -> ', OpToJS('='));
    WriteLn('  <>  -> ', OpToJS('<>'));
    WriteLn('  DIV -> ', OpToJS('DIV'));
    WriteLn('  MOD -> ', OpToJS('MOD'));
    WriteLn('  AND -> ', OpToJS('AND'));
    WriteLn('  OR  -> ', OpToJS('OR'));
    WriteLn('  NOT -> ', OpToJS('NOT'));
    WriteLn('  XOR -> ', OpToJS('XOR'));
    WriteLn('  SHL -> ', OpToJS('SHL'));
    WriteLn('  SHR -> ', OpToJS('SHR'));
    WriteLn('  IN  -> ', OpToJS('IN'));
    WriteLn('--- Fin des operateurs ---');

    { Tester le parseur d expressions sur les expressions trouvees }
    { Chercher les patterns ident := expr ; et ident = expr ;      }
    WriteLn('--- Expressions -> JavaScript ---');
    I := 0;
    While I < TokenCount - 2 Do
    Begin
      { Pattern: ident := expr ; }
      If (TokenPool[I].Kind = TK_IDENT) And
         (I + 1 < TokenCount) And
         (TokenPool[I + 1].Kind = TK_OP) And
         (TokenPool[I + 1].Val = ':=') Then
      Begin
        P := I;
        JS := ExprToJS(P);
        WriteLn('  ', TokenPool[I].Val, ' := ... -> ', JS);
        I := P;
      End
      { Pattern: ident = expr ; (constante) }
      Else If (TokenPool[I].Kind = TK_IDENT) And
              (I + 1 < TokenCount) And
              (TokenPool[I + 1].Kind = TK_OP) And
              (TokenPool[I + 1].Val = '=') And
              (I >= 1) And
              Not ((TokenPool[I - 1].Kind = TK_OP) Or
                   (TokenPool[I - 1].Kind = TK_KEYWORD)) Then
      Begin
        P := I;
        JS := ExprToJS(P);
        WriteLn('  ', TokenPool[I].Val, ' = ... -> ', JS);
        I := P;
      End
      Else
        Inc(I);
    End;
    WriteLn('--- Fin des expressions ---');

    WriteLn('Tokens dans le pool : ', TokenCount);
    WriteLn('Constantes predefinies : ', ConstCount);
    WriteLn('Types predefinis : ', TypeCount);
    WriteLn('Symboles predefinis : ', SymCount);

    TypeDump;
    SymDump;
  End;

  WriteLn('TP2JS: compilation de ', Opts.SrcFile, ' -> ', Opts.OutFile);

  { Ouvrir le fichier de sortie et emettre l en-tete }
  EmitOpen;
  EmitHeader;
  EmitModuleHeader;

  { Parser le programme Pascal et generer le JavaScript }
  P := 0;
  ParseProgram(P);

  { Emettre le pied de page et fermer }
  EmitFooter;
  EmitClose;

  WriteLn('TP2JS: fichier genere: ', Opts.OutFile);
  WriteLn('TP2JS: programme "', ProgName, '" compile.');
  If Opts.ModuleES6 Then
    WriteLn('TP2JS: mode module ES6 actif');
  If Opts.Pretty Then
    WriteLn('TP2JS: mode pretty-print actif');

  LexClose;
  If Opts.Verbose Then ShowStats;
  Cleanup;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Begin
  ParseArgs;
  Run;
  If ErrorCount > 0 Then
    Halt(EXIT_ERROR)
  Else
    Halt(EXIT_OK);
End.
