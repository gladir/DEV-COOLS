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

   TODO 01 - INFRASTRUCTURE ET OPTIONS
             TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings)
             ParseArgs : analyser argv (source.pas [sortie.js] [-v] [-d] [-w])
             FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
             Detecter l extension .pas du fichier source
             Sortie par defaut : meme nom avec extension .js
             Programme principal : validation des arguments et appel Run
             Version, Date, aide en ligne (option -h)
             Option -m (module ES6) : generer export/import au lieu de global
             Option -pretty : indentation du JavaScript genere

   TODO 02 - LEXEUR (TOKENS TURBO PASCAL)
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

   TODO 03 - LITTERAUX ET CONSTANTES
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

Begin
 WriteLn('TP2JS - Compilateur Turbo Pascal vers JavaScript (.js)');
 WriteLn('Version 1.0');
 WriteLn('Aucun TODO implemente pour le moment.');
End.
