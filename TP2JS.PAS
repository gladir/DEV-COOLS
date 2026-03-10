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

   TODO 04 - OPERATEURS ET PRECEDENCE
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

   TODO 05 - TABLE DES SYMBOLES
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

   TODO 06 - SYSTEME DE TYPES
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

   TODO 07 - EMETTEUR DE CODE JAVASCRIPT
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

   TODO 08 - PROGRAMME PRINCIPAL (PROGRAM)
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

   TODO 09 - VARIABLES ET AFFECTATIONS
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

   TODO 10 - EXPRESSIONS PRIMAIRES
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

   TODO 11 - EXPRESSIONS BINAIRES ET UNAIRES
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

   TODO 12 - ENTREES/SORTIES (Write / WriteLn / Read / ReadLn)
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
             Val(S, X, Code) : conversion chaine vers nombre
               -> X = parseInt(S) ou parseFloat(S), Code = isNaN(X) ? 1 : 0

   TODO 13 - IF / CASE / GOTO
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

   TODO 14 - BOUCLES : FOR / WHILE / REPEAT / BREAK / CONTINUE
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

   TODO 15 - PROCEDURES ET FONCTIONS
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

   TODO 16 - TYPES STRUCTURES : ARRAY / RECORD / SET / STRING
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

   TODO 17 - OBJETS ET HERITAGE (OBJECT)
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

{ ============================================================
  FORWARD DECLARATIONS
  ============================================================ }
Procedure LexClose; Forward;

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
    Tmp := ConstEvalAtom(P);
    { Consommer ')' }
    If (P < TokenCount) And (TokenPool[P].Kind = TK_PUNCT) And
       (TokenPool[P].Val = ')') Then
      Inc(P);
    If Neg Then
      ConstEvalAtom := '-(' + Tmp + ')'
    Else
      ConstEvalAtom := Tmp;
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

{ ---- ConstEvalExpr : evaluer une expression constante ------- }
{ Gere les operateurs +, -, *, /, DIV, MOD, AND, OR, XOR,      }
{ SHL, SHR, =, <>, <, >, <=, >= sur des constantes             }
{ Retourne la representation JavaScript de l expression          }
Function ConstEvalExpr(Var P : Integer) : TString;
Var
  Left : TString;
  Op   : TString;
  Rght : TString;
Begin
  Left := ConstEvalAtom(P);

  While (P < TokenCount) And
        ((TokenPool[P].Kind = TK_OP) Or
         ((TokenPool[P].Kind = TK_KEYWORD) And
          ((StrLowerCase(TokenPool[P].Val) = 'div') Or
           (StrLowerCase(TokenPool[P].Val) = 'mod') Or
           (StrLowerCase(TokenPool[P].Val) = 'and') Or
           (StrLowerCase(TokenPool[P].Val) = 'or')  Or
           (StrLowerCase(TokenPool[P].Val) = 'xor') Or
           (StrLowerCase(TokenPool[P].Val) = 'shl') Or
           (StrLowerCase(TokenPool[P].Val) = 'shr') Or
           (StrLowerCase(TokenPool[P].Val) = 'not') Or
           (StrLowerCase(TokenPool[P].Val) = 'in')))) Do
  Begin
    Op := StrLowerCase(TokenPool[P].Val);
    Inc(P);

    { Convertir l operateur Pascal en JavaScript }
    If Op = ':=' Then Break  { fin d expression constante }
    Else
    Begin
      Rght := ConstEvalAtom(P);
      If Op = '+'        Then Left := Left + ' + '   + Rght
      Else If Op = '-'   Then Left := Left + ' - '   + Rght
      Else If Op = '*'   Then Left := Left + ' * '   + Rght
      Else If Op = '/'   Then Left := Left + ' / '   + Rght
      Else If Op = '='   Then Left := Left + ' === '  + Rght
      Else If Op = '<>'  Then Left := Left + ' !== '  + Rght
      Else If Op = '<'   Then Left := Left + ' < '   + Rght
      Else If Op = '>'   Then Left := Left + ' > '   + Rght
      Else If Op = '<='  Then Left := Left + ' <= '  + Rght
      Else If Op = '>='  Then Left := Left + ' >= '  + Rght
      Else If Op = 'div' Then Left := 'Math.trunc(' + Left + ' / ' + Rght + ')'
      Else If Op = 'mod' Then Left := Left + ' % '   + Rght
      Else If Op = 'and' Then Left := Left + ' && '  + Rght
      Else If Op = 'or'  Then Left := Left + ' || '  + Rght
      Else If Op = 'xor' Then Left := Left + ' ^ '   + Rght
      Else If Op = 'shl' Then Left := Left + ' << '  + Rght
      Else If Op = 'shr' Then Left := Left + ' >> '  + Rght
      Else If Op = 'in'  Then Left := Rght + '.indexOf(' + Left + ') >= 0'
      Else Break;
    End;
  End;

  ConstEvalExpr := Left;
End;

{ ============================================================
  Run : tokenise le fichier source et teste la conversion
  ============================================================ }
Procedure Run;
Var
  I : Integer;
Begin
  GlobalInit;
  ConstInit;
  ConstRegisterBuiltins;
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
    WriteLn('Tokens dans le pool : ', TokenCount);
    WriteLn('Constantes predefinies : ', ConstCount);
  End;

  WriteLn('TP2JS: compilation de ', Opts.SrcFile, ' -> ', Opts.OutFile);
  WriteLn('TP2JS: TODO 04+ non implemente, rien a generer.');
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
