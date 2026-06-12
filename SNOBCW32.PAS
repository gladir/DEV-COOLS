{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 0.1
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Compilateur Snobol 4 vers assembleur 80386 pour Windows 32 bits
  @license: MIT
}

{ ============================================================ }
{ SNOBCW32.PAS - Compilateur SNOBOL4 -> 80386 PE Win32        }
{ Free Pascal {$MODE TP}                                       }
{ Usage : SNOBCW32 source.sbl [options]                       }
{   (defaut)  -> source.exe  (PE32 autonome)                  }
{   -obj      -> source.obj  (COFF relocatable)               }
{   -asm      -> source.asm  (texte MASM/JWasm, optionnel)    }
{ ============================================================ }
{
  TODO 01 - STRUCTURE GENERALE DU COMPILATEUR
            Point d entree principal : lire les arguments de la ligne
              de commande, determiner le fichier source (.sbl),
              le mode de sortie (EXE par defaut, OBJ, ASM),
              et le nom du fichier de sortie (derive du source).
            Sections globales : constantes, types, variables,
              procedures du lexeur, du parseur et du codegen.
            Organisation : {$MODE TP}, pas de classes ni de generiques.

  TODO 02 - LEXER / ANALYSEUR LEXICAL
            Lecture ligne par ligne du source SNOBOL4.
            Chaque ligne suit la forme :
              [LABEL]  [SUJET PATTERN] [= expression] [:goto]
            Colonne 1 non-blanc = debut de label.
            Commentaires : ligne dont le premier caractere non-blanc est *.
            Marqueur de fin : -END- (ou END) en colonne 1 ou indenté.
            LexLine : decoupe une ligne en tokens pour le parseur.
            LexNextToken, CurTokType, CurTokStr globaux.

  TODO 03 - TYPES DE TOKENS
            TOK_EOF, TOK_EOL, TOK_COMMENT
            TOK_LABEL   : identificateur en colonne 1
            TOK_IDENT   : identificateur (variable ou fonction)
            TOK_STRING  : litteral entre apostrophes 'texte'
            TOK_INTEGER : suite de chiffres
            TOK_ASSIGN  : signe egal =
            TOK_COLON   : debut de controle de flux :
            TOK_LPAREN, TOK_RPAREN
            TOK_COMMA   : separateur d arguments de fonction
            TOK_END     : marqueur -END-
            TOK_AMPERS  : & (pour &OUTPUT &INPUT &TRIM etc.)
            Mots-cles : DEFINE RETURN

  TODO 04 - PARSER / ANALYSEUR SYNTAXIQUE
            ParseProgram : boucle principale ligne par ligne jusqu a -END-.
            ParseLine    : label optionnel + corps de statement + goto optionnel.
            ParseStatement :
              - Affectation simple : VAR = expr
              - Affectation &OUTPUT = expr
              - Pattern matching   : expr1 expr2  (sans =)
              - DEFINE(proto)
              - RETURN
              - Ligne vide ou commentaire
            ParseExpr    : sequence de termes concatenes par juxtaposition.
            ParseTerm    : litteral | variable | appel de fonction | &KEYWORD.
            ParseGoto    : :(L) :S(L) :F(L) et combinaisons :S(L1) :F(L2).

  TODO 05 - AST (ARBRE SYNTAXIQUE ABSTRAIT)
            Representation par table fixe TAstNode (pas de pointeurs).
            Champs : Kind, Tok, Text, Left, Right, FirstChild, NextSibling,
              Line, SymRef.
            Noeuds principaux :
              NK_PROGRAM, NK_STMT, NK_ASSIGN, NK_OUTPUT, NK_INPUT
              NK_PATTERN  : subject + pattern (matching)
              NK_CONCAT   : concatenation de termes
              NK_LITERAL  : chaine ou entier constant
              NK_VAR      : variable utilisateur
              NK_CALL     : appel de fonction integree ou utilisateur
              NK_DEFINE   : declaration de fonction
              NK_RETURN   : retour de fonction
              NK_GOTO_U / NK_GOTO_S / NK_GOTO_F : sauts

  TODO 06 - TABLE DES SYMBOLES
            Variables : table SymTable, champs Name/Kind/Offset/AsmName.
            Kinds : SK_VAR (variable globale chaine), SK_LABEL (etiquette),
              SK_FUNC (fonction utilisateur), SK_PARAM (parametre de fonction).
            Labels : enregistres en passe 1 avec leur adresse de codegen.
            Fonctions utilisateur : nom, label d entree, liste de parametres.
            Variables systeme : &OUTPUT (SK_SYS_OUT), &INPUT (SK_SYS_IN),
              &TRIM (SK_SYS_TRIM), &ANCHOR (SK_SYS_ANCHOR).
            FindSym, AddSym, GetOrAddVar.

  TODO 07 - PASSES DU COMPILATEUR
            Passe 1 (CollectLabels) : parcours du source, enregistrement
              de tous les labels et des DEFINE dans la table des symboles.
              Necessite de connaitre les labels avant la generation de code
              pour resoudre les forward references des gotos.
            Passe 2 (CodegenProgram) : generation de code instruction par
              instruction, resolution des fixups labels au fur et a mesure.
            Fixups : liste de (offset_dans_BinCode, nom_label) a resoudre
              apres la passe 2, comme dans PERLCW32.

  TODO 08 - GENERATION PE32 BINAIRE (.EXE)
            Sections : BinCode (.text RX), BinData (.data RW),
              BinRData (.rdata R), BinBss (.bss RW), idata (IAT).
            Tableaux d octets : BinCode[0..MAX_CODE], BinData[], BinRData[].
            BinEmit8, BinEmit32, BinEmitRef32 (fixup ABS32 ou REL32).
            BinDefineLabel, BinResolveFixups.
            WritePE : produire le fichier .exe complet avec headers PE32,
              section headers, sections et IAT, calcul dynamique des RVAs.
            Entry point _SNSTART. ImageBase $00400000.

  TODO 09 - RUNTIME EMBARQUE : VARIABLES ET MEMOIRE
            Variables SNOBOL globales = pointeurs vers chaines heap.
            Table _SNV_TABLE : tableau de MAX_VARS pointeurs (initialises 0).
            Chaque variable declaree recoit un index compile en dur.
            _SNRT_var_set(idx, ptr) : stocke ptr dans _SNV_TABLE[idx].
            _SNRT_var_get(idx) -> EAX : charge ptr ou ptr vers chaine vide.
            Allocation via HeapAlloc(GetProcessHeap, HEAP_ZERO_MEMORY, n).
            Chaine vide globale : _SN_EMPTY = octet 0 en .rdata.

  TODO 10 - RUNTIME EMBARQUE : OPERATIONS SUR CHAINES
            _SNRT_str_concat(s1, s2) cdecl -> EAX = nouvelle chaine.
              strlen(s1) + strlen(s2) + 1, HeapAlloc, memcpy x2.
            _SNRT_str_len(s) cdecl -> EAX = longueur entiere.
            _SNRT_int_to_str(n) cdecl -> EAX = ptr chaine.
              Conversion entier -> chaine decimale (sans libc).
            _SNRT_str_to_int(s) cdecl -> EAX = valeur entiere.
              Parsing decimal simple, 0 si non numerique.
            _SNRT_str_eq(s1, s2) cdecl -> EAX = 1 si egaux, 0 sinon.

  TODO 11 - RUNTIME EMBARQUE : ENTREES / SORTIES
            _SNRT_output(str_ptr) cdecl :
              GetStdHandle(-11) si pas encore fait, WriteFile(stdout, s, len),
              WriteFile(stdout, '\r\n', 2).
            _SNRT_input() -> EAX = ptr chaine :
              ReadFile(GetStdHandle(-10), buf, MAX_LINE), stopper au \n,
              copier dans heap, retourner ptr.
            &OUTPUT = expr : codegen evalue expr -> EAX, appelle _SNRT_output.
            &INPUT          : codegen appelle _SNRT_input -> EAX.

  TODO 12 - RUNTIME EMBARQUE : PATTERN MATCHING
            Pattern SNOBOL4 v1 : correspondance de sous-chaine simple.
            _SNRT_pat_match(subject, pattern) cdecl -> EAX = 1/0.
              Recherche lineaire : pour chaque position i dans subject,
              comparer les strlen(pattern) premiers caracteres.
            Si EAX=1 : succes -> branche :S ; sinon echec -> branche :F.
            Extension future : ancres (^, $), classes de caracteres,
              operateurs SNOBOL (ARB, REM, SPAN, BREAK, ANY, NOTANY).

  TODO 13 - RUNTIME EMBARQUE : PREDICATS NUMERIQUES
            LT(a,b), LE(a,b), GT(a,b), GE(a,b), EQ(a,b), NE(a,b).
            Chaque predicat : convertir s1 et s2 en entiers via str_to_int,
              comparer, retourner EAX=1 (succes) ou EAX=0 (echec).
            _SNRT_pred_lt/le/gt/ge/eq/ne(s1, s2) cdecl -> EAX 1/0.
            En cas de succes, l appel de predicat ne modifie pas la variable
              cible (pas de valeur de retour utile) ; seul le flag compte.

  TODO 14 - RUNTIME EMBARQUE : PREDICATS DE CHAINES
            IDENT(s1, s2) : egalite exacte de chaines -> EAX=1/0.
              Appel interne a _SNRT_str_eq.
            DIFFER(s1, s2) : inegalite de chaines -> EAX = NOT IDENT.
            SIZE(s) -> EAX = ptr vers chaine representant la longueur.
              Appeler _SNRT_str_len puis _SNRT_int_to_str.
            Utilisation de SIZE dans une expression : valeur inseree comme
              chaine dans la concatenation.

  TODO 15 - CONTROLE DE FLUX : GOTO ET LABELS
            :(LABEL)  : JMP _SNL_LABEL (saut inconditionnel).
            :S(LABEL) : TEST EAX,EAX ; JNZ _SNL_LABEL (si succes).
            :F(LABEL) : TEST EAX,EAX ; JZ  _SNL_LABEL (si echec).
            Combinaisons : :S(L1) :F(L2) sur la meme instruction.
            Si pas de :F, echec = continuer a la ligne suivante.
            Si pas de :S, succes = continuer a la ligne suivante.
            BinJccLabel(CC, name), BinJmpLabel(name) avec fixups REL32.
            Labels emis comme BinDefineLabel('_SNL_' + LabelName).

  TODO 16 - FONCTIONS UTILISATEUR (DEFINE ET RETURN)
            DEFINE('NOM(P1,P2,...)') : enregistre NOM dans SymTable avec
              sa liste de parametres ; l entree de la fonction = label NOM.
            Appel NOM(a1,a2) : evaluer les args, stocker dans variables
              locales de la fonction (via frame EBP), JMP _SNL_NOM.
            Variables locales = parametres formels : alloues sur la pile
              comme dans PERLCW32 (SCOPE_LEXICAL, offset EBP negatif).
            RETURN : retour au site d appel via RET, valeur dans variable
              de meme nom que la fonction (convention SNOBOL4).
            Valeur retournee : variable NOM = valeur assignee avant RETURN.

  TODO 17 - CODEGEN : AFFECTATION ET CONCATENATION
            VAR = expr : BinCodegenExpr(expr) -> EAX = ptr chaine ;
              MOV [_SNV_TABLE + idx*4], EAX (ou via _SNRT_var_set).
            Concatenation : sequence de termes, appeler _SNRT_str_concat
              de gauche a droite ; resultat intermediaire en EAX.
            Terme litteral : stocker la chaine dans .rdata, MOV EAX, VA.
            Terme variable : MOV EAX, [_SNV_TABLE + idx*4] (ou var_get).
            Terme appel de fonction : generer l appel, EAX = resultat.

  TODO 18 - CODEGEN : PATTERN MATCHING ET BRANCHEMENT
            Instruction `SUBJECT PATTERN :S(L1) :F(L2)` :
              1. BinCodegenExpr(SUBJECT) -> EAX ; PUSH EAX (arg2).
              2. BinCodegenExpr(PATTERN) -> EAX ; PUSH EAX (arg1).
              3. CALL _SNRT_pat_match ; ADD ESP,8.
              4. TEST EAX,EAX.
              5. Si :S defini : JNZ _SNL_L1.
              6. Si :F defini : JZ  _SNL_L2.
              7. Sinon       : continuer.
            Le meme schema s applique aux predicats LT/EQ/IDENT etc.

  TODO 19 - CODEGEN : FONCTIONS INTEGREES
            Reconnaitre en parsant le nom de fonction : IDENT DIFFER SIZE
              LT LE GT GE EQ NE.
            Generer l appel au _SNRT_pred_* ou _SNRT_* correspondant.
            Gerer le cas SIZE dans une expression de concatenation :
              appel _SNRT_str_len + _SNRT_int_to_str, EAX = ptr chaine.
            Generer l appel aux fonctions utilisateur : evaluer les args,
              les passer en stack frame (CDECL interne), JMP vers label.

  TODO 20 - TABLE IAT ET IMPORTS WIN32
            kernel32.dll (minimum) :
              GetStdHandle, WriteFile, ReadFile, ExitProcess,
              HeapAlloc, HeapFree, GetProcessHeap.
            Structure IAT identique a PERLCW32 : section .idata,
              IMAGE_IMPORT_DESCRIPTOR, thunks d importation.
            BinCallImport('_GetStdHandle@4', 0) etc.
            BinEmitImport : emettre les entrees IAT dans BinIData[].
            BinWriteImports : finaliser la section .idata avant WritePE.

  TODO 21 - SORTIE .OBJ (COFF WIN32)
            Mode -obj : produire un fichier .obj COFF relocatable.
            IMAGE_FILE_HEADER : machine i386 (0x014C), sections, symtable.
            Sections : .text (code), .data (vars), .rdata (litteraux).
            Table des symboles COFF : entry point, labels exportes, imports.
            Table des relocations par section : R_I386_DIR32 pour abs32,
              R_I386_REL32 pour rel32.
            Table des chaines (string table) pour noms > 8 caracteres.
            Permettre le linkage avec link.exe ou jwlink.

  TODO 22 - SORTIE .ASM (MASM/JWASM) - OPTIONNEL
            Active uniquement avec le parametre -asm explicite.
            En-tete : .386 .MODEL FLAT,STDCALL OPTION CASEMAP:NONE
            Sections : .DATA, .CONST (.RDATA), .CODE
            EXTRN pour les imports kernel32.
            Emettre chaque instruction comme texte lisible avec commentaires.
            Labels : _SNL_XXX PROC / _SNL_XXX: selon le type.
            Ecriture dans un fichier texte ASCII via Assign/Rewrite/WriteLn.

  TODO 23 - GESTION DES ERREURS ET DIAGNOSTICS
            Erreurs fatales : fichier source introuvable, syntaxe invalide,
              label reference mais non defini, DEFINE mal forme.
            Avertissements : variable lue avant d etre assignee,
              label defini mais jamais reference, RETURN hors fonction.
            Format des messages : 'SNOBCW32: erreur ligne N: message'.
            Stopper la compilation a la premiere erreur fatale.
            Code de retour : 0 si succes, 1 si erreur (ExitProcess).

  TODO 24 - TESTS ET VALIDATION - SAMPLES SNOBOL
            hello.sbl        : &OUTPUT = 'BONJOUR MONDE'
            test01_hello     : meme avec indentation standard
            test02_vars      : variables, concatenation multi-termes
            test03_boucle    : boucle avec IDENT + :S/:F
            test03b_boucle   : boucle avec pattern matching + :(label)
            test04_pattern   : pattern matching de sous-chaine, :S :F
            test05_types     : LT, IDENT, SIZE, branches S/F enchainées
            test05b_types    : IDENT, pattern, branches S/F complexes
            test06_define    : DEFINE + appel + RETURN + valeur retournee
            test07_arith     : LT GT EQ NE + SIZE + EQ(SIZE(x),n)
            Chaque test documente sa sortie attendue en commentaire.

  TODO 25 - EXTENSIONS FUTURES (HORS SCOPE V1)
            Arithmetique directe : + - * / dans les expressions
              (actuellement simulee par predicats et SIZE).
            Operateurs de pattern avances : ARB REM SPAN BREAK ANY NOTANY.
            Tableaux SNOBOL (T = TABLE()).
            &ANCHOR : forcer le pattern matching en debut de chaine.
            &TRIM : supprimer les espaces en fin de chaine sur &OUTPUT.
            &STNO : numero de statement courant.
            Mode -obj compatible avec MASM/JWASM pour lien mixte.
            Optimisation : variables frequemment utilisees en registres.
}

Program SNOBCW32;
{$MODE TP}

{ ============================================================ }
{ TODO 01 - STRUCTURE GENERALE DU COMPILATEUR                  }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ Constantes globales                                          }
{ ------------------------------------------------------------ }
Const
  SNB_VERSION    = '0.1';
  SNB_YEAR       = '2026';

  { Modes de sortie }
  MODE_EXE       = 0;
  MODE_OBJ       = 1;
  MODE_ASM       = 2;

  { Limites des tables }
  MAX_LINE       = 1024;     { longueur max d une ligne source }
  MAX_TOKENS     = 128;      { tokens par ligne }
  MAX_AST        = 8192;     { noeuds AST }
  MAX_SYM        = 2048;     { entrees table des symboles }
  MAX_LABELS     = 1024;     { labels SNOBOL }
  MAX_FIXUPS     = 4096;     { fixups de relocation }
  MAX_CODE       = 524288;   { 512 Ko code .text }
  MAX_DATA       = 65536;    { 64 Ko .data }
  MAX_RDATA      = 131072;   { 128 Ko .rdata }
  MAX_IDATA      = 16384;    { 16 Ko .idata (IAT) }
  MAX_VARS       = 512;      { variables SNOBOL max }
  MAX_IMPORTS    = 64;       { entrees IAT max }
  MAX_FUNCS      = 128;      { fonctions utilisateur max }

  { Sections binaires }
  BIN_SEC_TEXT   = 0;
  BIN_SEC_DATA   = 1;
  BIN_SEC_RDATA  = 2;
  BIN_SEC_BSS    = 3;
  BIN_SEC_IDATA  = 4;

  { Types de fixup }
  BIN_FIX_ABS32  = 0;        { adresse absolue 32 bits }
  BIN_FIX_REL32  = 1;        { relative 32 bits (CALL/JMP) }
  BIN_FIX_IMP32  = 2;        { IAT import 32 bits }

  { Kinds de symboles }
  SK_NONE        = 0;
  SK_VAR         = 1;        { variable SNOBOL }
  SK_LABEL       = 2;        { etiquette de saut }
  SK_FUNC        = 3;        { fonction utilisateur }
  SK_PARAM       = 4;        { parametre de fonction }
  SK_SYS_OUT     = 5;        { &OUTPUT }
  SK_SYS_IN      = 6;        { &INPUT }
  SK_SYS_TRIM    = 7;        { &TRIM }
  SK_SYS_ANCHOR  = 8;        { &ANCHOR }
  { TODO 25 }
  SK_SYS_STNO    = 9;        { &STNO : numero de statement courant }
  SK_TABLE       = 10;       { tableau SNOBOL (TABLE()) }

{ ------------------------------------------------------------ }
{ Types                                                        }
{ ------------------------------------------------------------ }
Type
  { Entree de la table des symboles }
  TSym = Record
    Name    : String;
    Kind    : Integer;
    Offset  : LongInt;      { offset runtime/codegen generique }
    AsmName : String;       { nom ASM/PE stable }
    VarIdx  : Integer;      { index dans _SNV_TABLE (SK_VAR) }
    LblAddr : LongInt;      { adresse code compilee (SK_LABEL) }
    FuncLbl : String;       { label d entree (SK_FUNC) }
    ParamCnt: Integer;      { nb de parametres (SK_FUNC) }
    Params  : Array[0..7] Of String;
    RefCnt  : Integer;      { references labels / lectures variables }
    Assigned: Boolean;      { variable deja affectee }
    Warned  : Boolean;      { avertissement deja emis }
    DeclLine: Integer;      { ligne de declaration }
  End;

  { Noeud AST }
  TAstNode = Record
    Kind       : Integer;   { NK_xxx }
    Tok        : Integer;   { TOK_xxx }
    Text       : String;
    Left       : Integer;   { fils gauche ou premier enfant }
    Right      : Integer;   { fils droit }
    FirstChild : Integer;   { tete de liste d enfants }
    NextSibling: Integer;   { frere suivant dans une liste }
    Line       : Integer;   { ligne source }
    SymRef     : Integer;   { index SymTable }
    GotoS      : String;    { cible :S(label) }
    GotoF      : String;    { cible :F(label) }
    GotoU      : String;    { cible :(label) }
  End;

  { Fixup de relocation }
  TFixup = Record
    Offset  : LongInt;
    Section : Integer;
    Name    : String;
    Kind    : Integer;      { BIN_FIX_xxx }
  End;

  { Label defini }
  TLabel = Record
    Name    : String;
    Section : Integer;
    Offset  : LongInt;
  End;

  { Import Win32 }
  TImport = Record
    DllName : String;
    FuncName: String;
    IATOff  : LongInt;
    LabelNm : String;       { nom interne __imp__xxx }
  End;

{ ------------------------------------------------------------ }
{ Variables globales                                           }
{ ------------------------------------------------------------ }
Var
  { Fichiers et mode }
  SrcFile      : String;
  OutFile      : String;
  OutMode      : Integer;
  HasError     : Boolean;
  ErrorCount   : Integer;
  WarnCount    : Integer;

  { Table des symboles }
  SymTable     : Array[0..MAX_SYM-1]    Of TSym;
  SymCount     : Integer;

  { AST }
  AstTable     : Array[0..MAX_AST-1]    Of TAstNode;
  AstCount     : Integer;
  AstRoot      : Integer;

  { Variables SNOBOL : nom indexe }
  VarNames     : Array[0..MAX_VARS-1]   Of String;
  VarCount     : Integer;

  { Sections binaires }
  BinCode      : Array[0..MAX_CODE-1]   Of Byte;
  BinCodeSize  : LongInt;
  BinData      : Array[0..MAX_DATA-1]   Of Byte;
  BinDataSize  : LongInt;
  BinRData     : Array[0..MAX_RDATA-1]  Of Byte;
  BinRDataSize : LongInt;
  BinBssSize   : LongInt;
  BinIData     : Array[0..MAX_IDATA-1]  Of Byte;
  BinIDataSize : LongInt;
  BinCurSec    : Integer;

  { Labels et fixups }
  LabelTable   : Array[0..MAX_LABELS-1] Of TLabel;
  LabelCount   : Integer;
  FixupTable   : Array[0..MAX_FIXUPS-1] Of TFixup;
  FixupCount   : Integer;

  { Imports IAT }
  ImportTable  : Array[0..MAX_IMPORTS-1] Of TImport;
  ImportCount  : Integer;

  { Compteur de labels internes uniques }
  BinPLKCount  : Integer;

  { Variables systeme SNOBOL }
  SysAnchor    : Boolean;   { &ANCHOR }
  SysTrim      : Boolean;   { &TRIM }

  { Ligne source courante (diagnostics) }
  CurLineNum   : Integer;
  CodegenCurrentFunc : String;

{ ============================================================ }
{ Utilitaires generaux                                         }
{ ============================================================ }

Function IntToStr(N: LongInt): String;
Var S: String; Neg: Boolean;
Begin
  If N = 0 Then Begin IntToStr := '0'; Exit; End;
  Neg := (N < 0); If Neg Then N := -N;
  S := '';
  While N > 0 Do Begin
    S := Chr(Ord('0') + Integer(N Mod 10)) + S;
    N := N Div 10;
  End;
  If Neg Then S := '-' + S;
  IntToStr := S;
End;

Function FileExt(Const S: String): String;
Var I: Integer;
Begin
  FileExt := '';
  For I := Length(S) DownTo 1 Do
    If S[I] = '.' Then Begin FileExt := Copy(S, I, 255); Exit; End
    Else If (S[I] = '\') Or (S[I] = '/') Then Exit;
End;

Function FileBase(Const S: String): String;
Var I: Integer;
Begin
  FileBase := S;
  For I := Length(S) DownTo 1 Do
    If S[I] = '.' Then Begin FileBase := Copy(S, 1, I-1); Exit; End
    Else If (S[I] = '\') Or (S[I] = '/') Then Exit;
End;

Function ChangeExt(Const Path, NewExt: String): String;
Begin
  ChangeExt := FileBase(Path) + NewExt;
End;

Function FileExists(Const Name: String): Boolean;
Var F: File;
Begin
  Assign(F, Name);
  {$I-} Reset(F, 1); {$I+}
  If IOResult = 0 Then Begin Close(F); FileExists := True; End
  Else FileExists := False;
End;

Procedure CompileError(Const Msg: String);
Begin
  WriteLn('SNOBCW32: erreur ligne ', CurLineNum, ': ', Msg);
  HasError := True;
  Inc(ErrorCount);
End;

Procedure CompileWarn(Const Msg: String);
Begin
  WriteLn('SNOBCW32: avertissement ligne ', CurLineNum, ': ', Msg);
  Inc(WarnCount);
End;

{ ============================================================ }
{ Declarations anticipees (Forward) des sections TODO 02..22  }
{ ============================================================ }

{ TODO 02-03 : Lexer }
Procedure LexInit;                              Forward;
Procedure LexLine(Const S: String);            Forward;
Procedure LexNextToken;                         Forward;

{ TODO 04-05 : Parser / AST }
Procedure ParseProgram;                         Forward;

{ TODO 06 : Table des symboles }
Function  FindSym(Const Name: String; Kind: Integer): Integer; Forward;
Function  AddSym(Const Name: String; Kind: Integer): Integer;  Forward;
Function  GetOrAddVar(Const Name: String): Integer;            Forward;

{ TODO 07 : Passes }
Procedure CollectLabels;                        Forward;
Procedure CodegenProgram;                       Forward;

{ TODO 08 : Sortie PE32 }
Procedure WritePE(Const FileName: String);      Forward;
Function  BinCurOffset: LongInt;                Forward;
Procedure BinEmit8(B: Byte);                    Forward;
Procedure BinDefineLabel(Const Name: String);   Forward;
Function  BinAddImport(Const DllName, FuncName: String): Integer; Forward;
Procedure BinRegisterKernel32Imports;             Forward;
Procedure BinMovRegImm32(R: Integer; V: LongInt); Forward;
Procedure BinMovRegLabel(R: Integer; Const Name: String); Forward;
Procedure BinMovRegReg(Dst, Src: Integer);      Forward;
Procedure BinPushReg(R: Integer);               Forward;
Procedure BinPopReg(R: Integer);                Forward;
Procedure BinRet;                               Forward;
Procedure BinPushImm32(V: LongInt);             Forward;
Procedure BinAddEspImm8(N: Integer);            Forward;
Procedure BinCallLabel(Const Name: String);     Forward;
Procedure BinCallImport(Const FuncName: String); Forward;
Procedure BinJmpLabel(Const Name: String);      Forward;
Procedure BinJccLabel(CC: Integer; Const Name: String); Forward;

{ TODO 09 : Runtime variables / memoire }
Procedure EmitRuntimeMemory;                    Forward;

{ TODO 10 : Runtime operations chaines }
Procedure EmitRuntimeStrings;                   Forward;

{ TODO 11 : Runtime entrees / sorties }
Procedure EmitRuntimeIO;                        Forward;

{ TODO 12 : Runtime pattern matching }
Procedure EmitRuntimePattern;                   Forward;

{ TODO 13 : Runtime predicats numeriques }
Procedure EmitRuntimeNumericPredicates;         Forward;

{ TODO 14 : Runtime predicats de chaines }
Procedure EmitRuntimeStringPredicates;          Forward;

{ TODO 21 : Sortie OBJ COFF }
Procedure WriteCOFF(Const FileName: String);    Forward;

{ TODO 22 : Sortie ASM }
Procedure WriteASM(Const FileName: String);     Forward;

{ ============================================================ }
{ Initialisation des tables                                    }
{ ============================================================ }
Procedure InitTables;
Var I: Integer;
Begin
  SymCount     := 0;
  AstCount     := 0;
  AstRoot      := 0;
  VarCount     := 0;
  BinCodeSize  := 0;
  BinDataSize  := 0;
  BinRDataSize := 0;
  BinBssSize   := 0;
  BinIDataSize := 0;
  BinCurSec    := BIN_SEC_TEXT;
  LabelCount   := 0;
  FixupCount   := 0;
  ImportCount  := 0;
  BinPLKCount  := 0;
  SysAnchor    := False;
  SysTrim      := False;
  CurLineNum   := 0;
  CodegenCurrentFunc := '';
  HasError     := False;
  ErrorCount   := 0;
  WarnCount    := 0;
  For I := 0 To MAX_VARS-1 Do VarNames[I] := '';
  AddSym('&OUTPUT', SK_SYS_OUT);
  AddSym('&INPUT',  SK_SYS_IN);
  AddSym('&TRIM',   SK_SYS_TRIM);
  AddSym('&ANCHOR', SK_SYS_ANCHOR);
  AddSym('&STNO',   SK_SYS_STNO);
End;

{ ============================================================ }
{ TODO 02-03 - CONSTANTES, TYPES ET VARIABLES DU LEXER        }
{ ============================================================ }
Const
  { Types de tokens (TODO 03) }
  TOK_EOF     =  0;   { fin de fichier }
  TOK_EOL     =  1;   { fin de ligne }
  TOK_COMMENT =  2;   { commentaire (* en colonne 1) }
  TOK_LABEL   =  3;   { etiquette en colonne 1 }
  TOK_IDENT   =  4;   { identificateur }
  TOK_STRING  =  5;   { chaine 'texte' }
  TOK_INTEGER =  6;   { entier decimal }
  TOK_ASSIGN  =  7;   { = }
  TOK_COLON   =  8;   { : }
  TOK_LPAREN  =  9;   { ( }
  TOK_RPAREN  = 10;   { ) }
  TOK_COMMA   = 11;   { , }
  TOK_END     = 12;   { -END- ou END : fin de source }
  TOK_AMPERS  = 13;   { & : prefixe de variable systeme }
  KW_DEFINE   = 14;   { DEFINE }
  KW_RETURN   = 15;   { RETURN }

  { TODO 25 - tokens arithmetiques }
  TOK_PLUS    = 16;   { + addition }
  TOK_MINUS   = 17;   { - soustraction }
  TOK_STAR    = 18;   { * multiplication }
  TOK_SLASH   = 19;   { / division }

  { TODO 25 - mots-cles de pattern avances }
  KW_ARB      = 20;   { ARB    : match arbitraire }
  KW_REM      = 21;   { REM    : reste de la chaine }
  KW_SPAN     = 22;   { SPAN   : suite de chars d un ensemble }
  KW_BREAK    = 23;   { BREAK  : jusqu a un char de l ensemble }
  KW_ANY      = 24;   { ANY    : un char parmi un ensemble }
  KW_NOTANY   = 25;   { NOTANY : un char hors de l ensemble }
  KW_TABLE    = 26;   { TABLE  : creation de tableau associatif }

  LEX_TOKCAP  = 128;  { capacite du tampon de tokens par ligne }

Type
  TTokEntry = Record
    TokType : Integer;
    TokStr  : String;
  End;

Var
  LexSrcF    : Text;
  LexEOF     : Boolean;
  TokBuf     : Array[0..LEX_TOKCAP-1] Of TTokEntry;
  TokBufLen  : Integer;
  TokBufPos  : Integer;
  CurTokType : Integer;
  CurTokStr  : String;

{ ============================================================ }
{ Corps des stubs Forward (remplaces dans les TODO suivants)   }
{ ============================================================ }

{ --- TODO 02 : LexInit ------------------------------------- }
Procedure LexInit;
Begin
  Assign(LexSrcF, SrcFile);
  {$I-} Reset(LexSrcF); {$I+}
  If IOResult <> 0 Then Begin
    WriteLn('SNOBCW32: impossible d ouvrir : ', SrcFile);
    Halt(1);
  End;
  LexEOF     := False;
  TokBufLen  := 0;
  TokBufPos  := 0;
  CurTokType := TOK_EOF;
  CurTokStr  := '';
End;

{ --- TODO 02 : LexLine ------------------------------------- }
Procedure LexLine(Const S: String);
Var
  P, L : Integer;
  Ch   : Char;
  T    : String;

  Procedure AddTok(TType: Integer; Const TStr: String);
  Begin
    If TokBufLen < LEX_TOKCAP Then Begin
      TokBuf[TokBufLen].TokType := TType;
      TokBuf[TokBufLen].TokStr  := TStr;
      Inc(TokBufLen);
    End;
  End;

  Function IsAlpha(C: Char): Boolean;
  Begin
    IsAlpha := ((C >= 'A') And (C <= 'Z')) Or
               ((C >= 'a') And (C <= 'z')) Or (C = '_');
  End;

  Function IsAlNum(C: Char): Boolean;
  Begin
    IsAlNum := ((C >= 'A') And (C <= 'Z')) Or
               ((C >= 'a') And (C <= 'z')) Or
               ((C >= '0') And (C <= '9')) Or (C = '_');
  End;

  Function IsDigit(C: Char): Boolean;
  Begin IsDigit := (C >= '0') And (C <= '9'); End;

Begin
  TokBufLen := 0;
  TokBufPos := 0;
  L := Length(S);

  If L = 0 Then Begin AddTok(TOK_EOL, ''); Exit; End;

  { Commentaire : premier caractere est '*' }
  If S[1] = '*' Then Begin AddTok(TOK_COMMENT, ''); Exit; End;

  { Marqueur de fin -END- }
  If (L >= 5) And (Copy(S, 1, 5) = '-END-') Then Begin
    AddTok(TOK_END, '-END-'); AddTok(TOK_EOL, ''); Exit;
  End;

  P := 1;

  { Colonne 1 non-blanc = label ou mot-cle END }
  If (S[1] <> ' ') And (S[1] <> Chr(9)) Then Begin
    If IsAlpha(S[1]) Then Begin
      T := '';
      While (P <= L) And IsAlNum(S[P]) Do Begin T := T + S[P]; Inc(P); End;
      If T = 'END' Then Begin
        AddTok(TOK_END, 'END'); AddTok(TOK_EOL, ''); Exit;
      End;
      If T <> '' Then AddTok(TOK_LABEL, T);
    End;
  End;

  { Scan du corps de la ligne }
  While P <= L Do Begin
    Ch := S[P];
    If (Ch = ' ') Or (Ch = Chr(9)) Then
      Inc(P)
    Else If Ch = '=' Then Begin AddTok(TOK_ASSIGN, '=');  Inc(P); End
    Else If Ch = ':' Then Begin AddTok(TOK_COLON,  ':');  Inc(P); End
    Else If Ch = '(' Then Begin AddTok(TOK_LPAREN, '(');  Inc(P); End
    Else If Ch = ')' Then Begin AddTok(TOK_RPAREN, ')');  Inc(P); End
    Else If Ch = ',' Then Begin AddTok(TOK_COMMA,  ',');  Inc(P); End
    Else If Ch = '&' Then Begin AddTok(TOK_AMPERS, '&');  Inc(P); End
    Else If Ch = '+' Then Begin AddTok(TOK_PLUS,   '+');  Inc(P); End
    Else If Ch = '-' Then Begin AddTok(TOK_MINUS,  '-');  Inc(P); End
    Else If Ch = '*' Then Begin AddTok(TOK_STAR,   '*');  Inc(P); End
    Else If Ch = '/' Then Begin AddTok(TOK_SLASH,  '/');  Inc(P); End
    Else If Ch = '''' Then Begin
      Inc(P); T := '';
      While P <= L Do Begin
        If S[P] = '''' Then Begin
          Inc(P);
          If (P <= L) And (S[P] = '''') Then Begin T := T + ''''; Inc(P); End
          Else Break;
        End
        Else Begin T := T + S[P]; Inc(P); End;
      End;
      AddTok(TOK_STRING, T);
    End
    Else If IsDigit(Ch) Then Begin
      T := '';
      While (P <= L) And IsDigit(S[P]) Do Begin T := T + S[P]; Inc(P); End;
      AddTok(TOK_INTEGER, T);
    End
    Else If IsAlpha(Ch) Then Begin
      T := '';
      While (P <= L) And IsAlNum(S[P]) Do Begin T := T + S[P]; Inc(P); End;
      If      T = 'DEFINE'  Then AddTok(KW_DEFINE,  T)
      Else If T = 'RETURN'  Then AddTok(KW_RETURN,  T)
      Else If T = 'ARB'     Then AddTok(KW_ARB,     T)
      Else If T = 'REM'     Then AddTok(KW_REM,     T)
      Else If T = 'SPAN'    Then AddTok(KW_SPAN,    T)
      Else If T = 'BREAK'   Then AddTok(KW_BREAK,   T)
      Else If T = 'ANY'     Then AddTok(KW_ANY,     T)
      Else If T = 'NOTANY'  Then AddTok(KW_NOTANY,  T)
      Else If T = 'TABLE'   Then AddTok(KW_TABLE,   T)
      Else AddTok(TOK_IDENT, T);
    End
    Else Inc(P);
  End;

  AddTok(TOK_EOL, '');
End;

{ --- TODO 02 : LexNextToken -------------------------------- }
Procedure LexNextToken;
Begin
  If TokBufPos < TokBufLen Then Begin
    CurTokType := TokBuf[TokBufPos].TokType;
    CurTokStr  := TokBuf[TokBufPos].TokStr;
    Inc(TokBufPos);
  End
  Else Begin
    CurTokType := TOK_EOL;
    CurTokStr  := '';
  End;
End;

{ --- TODO 02 : LexReadLine --------------------------------- }
{ Lit la prochaine ligne du source ; retourne False en fin de fichier. }
Function LexReadLine(Var Line: String): Boolean;
Begin
  If LexEOF Or EOF(LexSrcF) Then Begin
    LexEOF := True; Line := ''; LexReadLine := False; Exit;
  End;
  ReadLn(LexSrcF, Line);
  Inc(CurLineNum);
  LexReadLine := True;
End;

{ --- TODO 02 : LexRewind ----------------------------------- }
{ Rebobine le source pour la passe 2 (apres CollectLabels). }
Procedure LexRewind;
Begin
  If Not LexEOF Then Close(LexSrcF);
  Assign(LexSrcF, SrcFile);
  {$I-} Reset(LexSrcF); {$I+}
  If IOResult <> 0 Then Begin
    WriteLn('SNOBCW32: erreur reouverture : ', SrcFile);
    Halt(1);
  End;
  LexEOF := False;
  CurLineNum := 0;
End;

{ --- TODO 02 : LexClose ------------------------------------ }
Procedure LexClose;
Begin
  If Not LexEOF Then Begin Close(LexSrcF); LexEOF := True; End;
End;

{ ============================================================ }
{ TODO 04-05 - CONSTANTES AST, HELPERS ET PARSER              }
{ ============================================================ }

Const
  { Kinds de noeuds AST (TODO 05) }
  NK_PROGRAM  =  1;   { racine du programme }
  NK_STMT     =  2;   { statement neutre (vide) }
  NK_ASSIGN   =  3;   { VAR = expr }
  NK_OUTPUT   =  4;   { &OUTPUT = expr }
  NK_INPUT    =  5;   { &INPUT }
  NK_PATTERN  =  6;   { SUBJECT PATTERN [= REPL] }
  NK_CONCAT   =  7;   { concatenation gauche + droite }
  NK_LITERAL  =  8;   { chaine ou entier constant }
  NK_VAR      =  9;   { variable utilisateur }
  NK_CALL     = 10;   { appel de fonction }
  NK_DEFINE   = 11;   { DEFINE(proto) }
  NK_RETURN   = 12;   { RETURN }
  NK_GOTO_U   = 13;   { :(label) inconditionnel }
  NK_GOTO_S   = 14;   { :S(label) }
  NK_GOTO_F   = 15;   { :F(label) }
  NK_SYSVAR   = 16;   { &KEYWORD }
  { TODO 25 - noeuds supplementaires }
  NK_ARITH    = 17;   { operation arithmetique Left op Right, Text = '+'/'-'/'*'/'/' }
  NK_PATOP    = 18;   { operateur de pattern avance (ARB/REM/SPAN/BREAK/ANY/NOTANY) }
  NK_TABLECRE = 19;   { creation TABLE() }
  NK_TABLEGET = 20;   { lecture tableau T<key> }
  NK_TABLESET = 21;   { ecriture tableau T<key> = val }

{ --- Helper : alloue un noeud AST -------------------- }
Function NewNode(Kind, Tok: Integer; Const Text: String): Integer;
Var N: Integer;
Begin
  If AstCount >= MAX_AST Then Begin
    CompileError('trop de noeuds AST'); NewNode := 0; Exit;
  End;
  N := AstCount; Inc(AstCount);
  AstTable[N].Kind        := Kind;  AstTable[N].Tok         := Tok;
  AstTable[N].Text        := Text;  AstTable[N].Left        := 0;
  AstTable[N].Right       := 0;     AstTable[N].FirstChild  := 0;
  AstTable[N].NextSibling := 0;     AstTable[N].Line        := CurLineNum;
  AstTable[N].SymRef      := -1;
  AstTable[N].GotoS       := '';    AstTable[N].GotoF       := '';
  AstTable[N].GotoU       := '';
  NewNode := N;
End;

{ --- Peek : prochain type de token sans consommer ---- }
Function PeekTokType: Integer;
Begin
  If TokBufPos < TokBufLen Then PeekTokType := TokBuf[TokBufPos].TokType
  Else PeekTokType := TOK_EOL;
End;

{ --- IsExprStart : CurTokType peut-il commencer un terme ? }
Function IsExprStart: Boolean;
Begin
  IsExprStart := (CurTokType = TOK_STRING)  Or (CurTokType = TOK_INTEGER) Or
                 (CurTokType = TOK_IDENT)   Or (CurTokType = TOK_AMPERS)  Or
                 (CurTokType = KW_TABLE)    Or
                 ((CurTokType >= KW_ARB) And (CurTokType <= KW_NOTANY));
End;

{ --- ParseGoto : clauses :S(L) :F(L) :(L) ------------ }
Procedure ParseGoto(StmtN: Integer);
Var Dir: Char; LblName: String; Again: Boolean;
Begin
  LexNextToken; { skip ':' }
  Again := True;
  While Again Do Begin
    Again := False;
    If (CurTokType = TOK_IDENT) And
       ((CurTokStr = 'S') Or (CurTokStr = 'F')) Then Begin
      Dir := CurTokStr[1]; LexNextToken;
      If CurTokType = TOK_LPAREN Then Begin
        LexNextToken; LblName := '';
        If CurTokType = TOK_IDENT Then Begin LblName := CurTokStr; LexNextToken; End;
        If CurTokType = TOK_RPAREN Then LexNextToken;
        If Dir = 'S' Then AstTable[StmtN].GotoS := LblName
        Else              AstTable[StmtN].GotoF := LblName;
      End;
      { Deuxieme branche eventuelle (avec ou sans ':') }
      If CurTokType = TOK_COLON Then Begin LexNextToken; Again := True; End
      Else If (CurTokType = TOK_IDENT) And
              ((CurTokStr = 'S') Or (CurTokStr = 'F')) Then Again := True;
    End
    Else If CurTokType = TOK_LPAREN Then Begin
      LexNextToken; LblName := '';
      If CurTokType = TOK_IDENT Then Begin LblName := CurTokStr; LexNextToken; End;
      If CurTokType = TOK_RPAREN Then LexNextToken;
      AstTable[StmtN].GotoU := LblName;
    End;
  End;
End;

{ Forward pour la recursion mutuelle ParseExpr <-> ParseTerm }
Function ParseExpr: Integer; Forward;

{ --- ParseTerm : un seul terme (litteral/var/appel/&kw) -- }
Function ParseTerm: Integer;
Var N, Last, ArgN: Integer; FName: String;
Begin
  ParseTerm := 0;
  If (CurTokType = TOK_STRING) Or (CurTokType = TOK_INTEGER) Then Begin
    N := NewNode(NK_LITERAL, CurTokType, CurTokStr); LexNextToken;
    ParseTerm := N;
  End
  Else If CurTokType = TOK_AMPERS Then Begin
    LexNextToken;
    If CurTokType = TOK_IDENT Then Begin
      N := NewNode(NK_SYSVAR, TOK_AMPERS, CurTokStr); LexNextToken;
      AstTable[N].SymRef := FindSym('&' + AstTable[N].Text, -1);
    End Else N := NewNode(NK_SYSVAR, TOK_AMPERS, '');
    ParseTerm := N;
  End
  Else If CurTokType = TOK_IDENT Then Begin
    FName := CurTokStr; LexNextToken;
    If CurTokType = TOK_LPAREN Then Begin
      N := NewNode(NK_CALL, TOK_IDENT, FName);
      LexNextToken; { skip ( }
      Last := 0;
      While (CurTokType <> TOK_RPAREN) And (CurTokType <> TOK_EOL) Do Begin
        ArgN := ParseExpr;
        If ArgN = 0 Then Break;
        If Last = 0 Then AstTable[N].FirstChild := ArgN
        Else AstTable[Last].NextSibling := ArgN;
        Last := ArgN;
        If CurTokType = TOK_COMMA Then LexNextToken;
      End;
      If CurTokType = TOK_RPAREN Then LexNextToken;
      ParseTerm := N;
    End Else Begin
      N := NewNode(NK_VAR, TOK_IDENT, FName);
      If GetOrAddVar(FName) >= 0 Then
        AstTable[N].SymRef := FindSym(FName, SK_VAR);
      ParseTerm := N;
    End;
  End
  Else If CurTokType = KW_TABLE Then Begin
    { TABLE() : creation d un tableau SNOBOL }
    LexNextToken;
    N := NewNode(NK_TABLECRE, 0, '');
    If CurTokType = TOK_LPAREN Then Begin
      LexNextToken;
      If CurTokType = TOK_RPAREN Then LexNextToken;
    End;
    ParseTerm := N;
  End
  Else If (CurTokType = KW_ARB)   Or (CurTokType = KW_REM)    Or
          (CurTokType = KW_SPAN)  Or (CurTokType = KW_BREAK)  Or
          (CurTokType = KW_ANY)   Or (CurTokType = KW_NOTANY) Then Begin
    { Operateur de pattern avance : ARB | REM | SPAN(cs) | BREAK(cs) | ANY(cs) | NOTANY(cs) }
    N := NewNode(NK_PATOP, CurTokType, CurTokStr);
    LexNextToken;
    If CurTokType = TOK_LPAREN Then Begin
      LexNextToken;
      If IsExprStart Then AstTable[N].Left := ParseExpr;
      If CurTokType = TOK_RPAREN Then LexNextToken;
    End;
    ParseTerm := N;
  End;
End;

{ --- ParseArith : terme optionnellement suivi de +/-/*//) terme -- }
Function ParseArith: Integer;
Var Left, Right, OpNode: Integer;
Begin
  Left := ParseTerm;
  If Left = 0 Then Begin ParseArith := 0; Exit; End;
  While (CurTokType = TOK_PLUS) Or (CurTokType = TOK_MINUS) Or
        (CurTokType = TOK_STAR) Or (CurTokType = TOK_SLASH) Do Begin
    OpNode := NewNode(NK_ARITH, CurTokType, CurTokStr);
    LexNextToken;
    Right := ParseTerm;
    If Right = 0 Then Break;
    AstTable[OpNode].Left  := Left;
    AstTable[OpNode].Right := Right;
    Left := OpNode;
  End;
  ParseArith := Left;
End;

{ --- ParseExpr : termes juxtaposes (concatenation) avec arithmetique }
Function ParseExpr: Integer;
Var Left, Right, CatN: Integer;
Begin
  Left := ParseArith;
  If Left = 0 Then Begin ParseExpr := 0; Exit; End;
  While IsExprStart Do Begin
    Right := ParseArith;
    If Right = 0 Then Break;
    CatN := NewNode(NK_CONCAT, 0, '');
    AstTable[CatN].Left  := Left;
    AstTable[CatN].Right := Right;
    Left := CatN;
  End;
  ParseExpr := Left;
End;

{ --- ParseStatement : corps de la ligne (hors label+goto) }
Procedure ParseStatement(StmtN: Integer);
Var SubjN, PatN, ExprN, LhsN: Integer; LhsName: String;
Begin
  AstTable[StmtN].Kind := NK_STMT;
  If (CurTokType = TOK_EOL) Or (CurTokType = TOK_COMMENT) Then Exit;

  { DEFINE(proto) }
  If CurTokType = KW_DEFINE Then Begin
    LexNextToken; AstTable[StmtN].Kind := NK_DEFINE;
    If CurTokType = TOK_LPAREN Then Begin
      LexNextToken;
      If (CurTokType = TOK_STRING) Or (CurTokType = TOK_IDENT) Then Begin
        AstTable[StmtN].Text := CurTokStr; LexNextToken;
      End;
      If CurTokType = TOK_RPAREN Then LexNextToken;
    End;
    Exit;
  End;

  { RETURN [expr] }
  If CurTokType = KW_RETURN Then Begin
    LexNextToken; AstTable[StmtN].Kind := NK_RETURN;
    If IsExprStart Then AstTable[StmtN].Left := ParseExpr;
    Exit;
  End;

  { &SYSVAR = expr | &OUTPUT = expr | &INPUT }
  If CurTokType = TOK_AMPERS Then Begin
    LexNextToken;
    If CurTokType <> TOK_IDENT Then Begin
      CompileError('identificateur attendu apres &'); Exit;
    End;
    LhsName := CurTokStr; LexNextToken;
    If CurTokType = TOK_ASSIGN Then Begin
      LexNextToken; ExprN := ParseExpr;
      LhsN := NewNode(NK_SYSVAR, TOK_AMPERS, LhsName);
      AstTable[LhsN].SymRef := FindSym('&' + LhsName, -1);
      AstTable[StmtN].Left  := LhsN;
      AstTable[StmtN].Right := ExprN;
      If LhsName = 'OUTPUT' Then AstTable[StmtN].Kind := NK_OUTPUT
      Else AstTable[StmtN].Kind := NK_ASSIGN;
    End Else If LhsName = 'INPUT' Then
      AstTable[StmtN].Kind := NK_INPUT
    Else Begin
      LhsN := NewNode(NK_SYSVAR, TOK_AMPERS, LhsName);
      AstTable[LhsN].SymRef := FindSym('&' + LhsName, -1);
      AstTable[StmtN].Kind := NK_PATTERN; AstTable[StmtN].Left := LhsN;
    End;
    Exit;
  End;

  { IDENT = expr : affectation simple (peek = next token is =) }
  If (CurTokType = TOK_IDENT) And (PeekTokType = TOK_ASSIGN) Then Begin
    LhsName := CurTokStr; LexNextToken; { skip IDENT }
    LexNextToken; { skip = }
  ExprN := ParseExpr;
  LhsN := NewNode(NK_VAR, TOK_IDENT, LhsName);
  If GetOrAddVar(LhsName) >= 0 Then
    AstTable[LhsN].SymRef := FindSym(LhsName, SK_VAR);
  AstTable[StmtN].Kind  := NK_ASSIGN;
    AstTable[StmtN].Left  := LhsN;
    AstTable[StmtN].Right := ExprN;
    Exit;
  End;

  { Pattern match : SUBJECT [PATTERN [= REPLACEMENT]] }
  SubjN := ParseTerm;
  If SubjN = 0 Then Exit;
  AstTable[StmtN].Kind := NK_PATTERN;
  AstTable[StmtN].Left := SubjN;
  If (CurTokType = TOK_EOL) Or (CurTokType = TOK_COLON) Then Exit;
  PatN := ParseExpr;
  AstTable[StmtN].Right := PatN;
  If CurTokType = TOK_ASSIGN Then Begin
    LexNextToken; ExprN := ParseExpr;
    AstTable[StmtN].FirstChild := ExprN; { remplacement }
  End;
End;

{ --- ParseLine : tokenise + parse une ligne ----------- }
Function ParseLine(Const Line: String): Integer;
Var StmtN: Integer;
Begin
  LexLine(Line); LexNextToken;
  StmtN := NewNode(NK_STMT, 0, '');
  If CurTokType = TOK_LABEL Then Begin
    AstTable[StmtN].Text := CurTokStr; LexNextToken;
  End;
  ParseStatement(StmtN);
  If CurTokType = TOK_COLON Then ParseGoto(StmtN);
  ParseLine := StmtN;
End;

{ --- ParseProgram : boucle principale ligne par ligne -- }
Procedure ParseProgram;
Var Line: String; StmtN, ProgN, Last: Integer;
Begin
  LexRewind;
  AstCount := 0;
  ProgN    := NewNode(NK_PROGRAM, 0, '');
  AstRoot  := ProgN;
  Last     := 0;
  While LexReadLine(Line) Do Begin
    { Pre-scan : detecter -END- et lignes vides/commentaires }
    LexLine(Line); LexNextToken;
    If CurTokType = TOK_END Then Break;
    If (CurTokType = TOK_EOL) Or (CurTokType = TOK_COMMENT) Then Continue;
    { Parse de la ligne }
    StmtN := ParseLine(Line);
    If Last = 0 Then AstTable[ProgN].FirstChild := StmtN
    Else AstTable[Last].NextSibling := StmtN;
    Last := StmtN;
  End;
End;

{ ============================================================ }
{ TODO 06 - TABLE DES SYMBOLES                                }
{ ============================================================ }

Function SymUpper(Const S: String): String;
Var I: Integer; R: String;
Begin
  R := S;
  For I := 1 To Length(R) Do
    R[I] := UpCase(R[I]);
  SymUpper := R;
End;

Function SymAsmSafe(Const S: String): String;
Var I: Integer; C: Char; R: String;
Begin
  R := '';
  For I := 1 To Length(S) Do Begin
    C := UpCase(S[I]);
    If ((C >= 'A') And (C <= 'Z')) Or ((C >= '0') And (C <= '9')) Then
      R := R + C
    Else
      R := R + '_';
  End;
  If R = '' Then R := 'NONAME';
  SymAsmSafe := R;
End;

Function SymAsmName(Const Name: String; Kind: Integer; VarIdx: Integer): String;
Var S: String;
Begin
  S := SymAsmSafe(Name);
  Case Kind Of
    SK_VAR:        SymAsmName := '_SNV_' + IntToStr(VarIdx) + '_' + S;
    SK_LABEL:      SymAsmName := '_SNL_' + S;
    SK_FUNC:       SymAsmName := '_SNF_' + S;
    SK_PARAM:      SymAsmName := '_SNP_' + S;
    SK_SYS_OUT,
    SK_SYS_IN,
    SK_SYS_TRIM,
    SK_SYS_ANCHOR,
    SK_SYS_STNO:   SymAsmName := '_SNS_' + S;
    SK_TABLE:      SymAsmName := '_SNT_' + S;
  Else
    SymAsmName := '_SNSYM_' + S;
  End;
End;

Procedure ClearSym(I: Integer);
Var K: Integer;
Begin
  SymTable[I].Name     := '';
  SymTable[I].Kind     := SK_NONE;
  SymTable[I].Offset   := 0;
  SymTable[I].AsmName  := '';
  SymTable[I].VarIdx   := -1;
  SymTable[I].LblAddr  := -1;
  SymTable[I].FuncLbl  := '';
  SymTable[I].ParamCnt := 0;
  SymTable[I].RefCnt   := 0;
  SymTable[I].Assigned := False;
  SymTable[I].Warned   := False;
  SymTable[I].DeclLine := 0;
  For K := 0 To 7 Do SymTable[I].Params[K] := '';
End;

{ FindSym : cherche un symbole par nom et kind.
  Kind = -1 accepte tout kind. Retourne l index ou -1. }
Function FindSym(Const Name: String; Kind: Integer): Integer;
Var I: Integer; U: String;
Begin
  U := SymUpper(Name);
  FindSym := -1;
  For I := 0 To SymCount - 1 Do
    If SymTable[I].Name = U Then
      If (Kind = -1) Or (SymTable[I].Kind = Kind) Then Begin
        FindSym := I; Exit;
      End;
End;

{ AddSym : ajoute une entree dans SymTable. Retourne l index ou -1. }
Function AddSym(Const Name: String; Kind: Integer): Integer;
Var I, Existing: Integer; U: String;
Begin
  U := SymUpper(Name);
  Existing := FindSym(U, Kind);
  If Existing >= 0 Then Begin AddSym := Existing; Exit; End;
  If SymCount >= MAX_SYM Then Begin
    CompileError('table des symboles pleine'); AddSym := -1; Exit;
  End;
  I := SymCount; Inc(SymCount);
  ClearSym(I);
  SymTable[I].Name     := U;
  SymTable[I].Kind     := Kind;
  SymTable[I].AsmName  := SymAsmName(U, Kind, 0);
  SymTable[I].DeclLine := CurLineNum;
  If Kind = SK_LABEL Then
    SymTable[I].FuncLbl := SymTable[I].AsmName
  Else If Kind = SK_FUNC Then
    SymTable[I].FuncLbl := '_SNL_' + SymAsmSafe(U);
  AddSym := I;
End;

{ GetOrAddVar : trouve ou cree une variable SK_VAR.
  Retourne le VarIdx (index dans _SNV_TABLE), ou -1 si erreur. }
Function GetOrAddVar(Const Name: String): Integer;
Var SI: Integer;
Begin
  SI := FindSym(Name, SK_VAR);
  If SI >= 0 Then Begin GetOrAddVar := SymTable[SI].VarIdx; Exit; End;
  SI := AddSym(Name, SK_VAR);
  If SI < 0 Then Begin GetOrAddVar := -1; Exit; End;
  If VarCount >= MAX_VARS Then Begin
    CompileError('trop de variables'); GetOrAddVar := -1; Exit;
  End;
  SymTable[SI].VarIdx  := VarCount;
  SymTable[SI].Offset  := VarCount * 4;
  SymTable[SI].AsmName := SymAsmName(SymTable[SI].Name, SK_VAR, VarCount);
  VarNames[VarCount]   := SymTable[SI].Name;
  Inc(VarCount);
  GetOrAddVar := SymTable[SI].VarIdx;
End;

{ ============================================================ }
{ TODO 07 - PASSE 1 : COLLECTE DES LABELS ET DEFINE           }
{ ============================================================ }

{ ParseDefineProto : extrait nom, params et label d entree
  d une chaine de prototype SNOBOL4 du type 'NOM(P1,P2,ENTRY)'. }
Procedure ParseDefineProto(Const Proto: String;
                           Var FName: String;
                           Var ParamCnt: Integer;
                           Var Params: Array Of String);
Var P, K: Integer;
Begin
  FName    := '';
  ParamCnt := 0;
  P := 1;
  { Nom de la fonction : jusqu au '(' ou fin }
  While (P <= Length(Proto)) And (Proto[P] <> '(') Do Begin
    FName := FName + Proto[P]; Inc(P);
  End;
  If (P > Length(Proto)) Or (Proto[P] <> '(') Then Exit;
  Inc(P); { saute '(' }
  K := 0;
  While (P <= Length(Proto)) And (Proto[P] <> ')') And (K <= High(Params)) Do Begin
    Params[K] := '';
    While (P <= Length(Proto)) And (Proto[P] <> ',') And (Proto[P] <> ')') Do Begin
      Params[K] := Params[K] + Proto[P]; Inc(P);
    End;
    If Params[K] <> '' Then Inc(K);
    If (P <= Length(Proto)) And (Proto[P] = ',') Then Inc(P);
  End;
  ParamCnt := K;
End;

{ CollectLabels : passe 1 - enregistre labels et DEFINE
  dans SymTable avant la generation de code. }
Procedure CollectLabels;
Var Line, Proto, FName: String;
    Params: Array[0..8] Of String;
    SI, ParamCnt, K: Integer;
Begin
  LexRewind;
  While LexReadLine(Line) Do Begin
    LexLine(Line); LexNextToken;
    If CurTokType = TOK_END Then Break;
    If (CurTokType = TOK_EOL) Or (CurTokType = TOK_COMMENT) Then Continue;

    { Label en colonne 1 }
    If CurTokType = TOK_LABEL Then Begin
      FName := CurTokStr; LexNextToken;
      If FindSym(FName, SK_LABEL) < 0 Then Begin
        SI := AddSym(FName, SK_LABEL);
        { LblAddr sera fixe lors de la generation de code }
      End
      Else If FindSym(FName, SK_FUNC) < 0 Then
        { Ne pas avertir si le label vient d un DEFINE precedent }
        CompileWarn('label duplique : ' + FName);
    End;

    { DEFINE('NOM(P1,P2,...)') }
    If CurTokType = KW_DEFINE Then Begin
      LexNextToken;
      If CurTokType <> TOK_LPAREN Then Begin
        CompileError('DEFINE mal forme : parenthese ouvrante attendue');
        Exit;
      End;
      LexNextToken;
      If Not ((CurTokType = TOK_STRING) Or (CurTokType = TOK_IDENT)) Then Begin
        CompileError('DEFINE mal forme : prototype attendu');
        Exit;
      End;
      Proto := CurTokStr; LexNextToken;
      ParseDefineProto(Proto, FName, ParamCnt, Params);
      If FName = '' Then Begin
        CompileError('DEFINE mal forme : prototype invalide');
        Exit;
      End;
      If CurTokType <> TOK_RPAREN Then Begin
        CompileError('DEFINE mal forme : parenthese fermante attendue');
        Exit;
      End;
      LexNextToken;

      If FindSym(FName, SK_FUNC) < 0 Then Begin
        SI := AddSym(FName, SK_FUNC);
        SymTable[SI].FuncLbl  := '_SNL_' + SymAsmSafe(FName);
        SymTable[SI].ParamCnt := ParamCnt;
        For K := 0 To ParamCnt - 1 Do
          SymTable[SI].Params[K] := SymUpper(Params[K]);
        GetOrAddVar(FName);
        For K := 0 To ParamCnt - 1 Do Begin
          GetOrAddVar(Params[K]);
          SI := FindSym(Params[K], SK_VAR);
          If SI >= 0 Then SymTable[SI].Assigned := True;
        End;
        { Enregistrer aussi le label d entree de la fonction }
        If FindSym(FName, SK_LABEL) < 0 Then Begin
          SI := AddSym(FName, SK_LABEL);
        End;
      End
      Else
        CompileWarn('fonction deja definie : ' + FName);
    End;
  End;
  { Pas de LexRewind ici : ParseProgram le fait a son debut }
End;

Function CodegenLabelName(Const Name: String): String;
Begin
  CodegenLabelName := '_SNL_' + SymAsmSafe(Name);
End;

Procedure CodegenDefineStmtLabel(Node: Integer);
Var SI: Integer; Lbl: String;
Begin
  If AstTable[Node].Text = '' Then Exit;
  Lbl := CodegenLabelName(AstTable[Node].Text);
  BinDefineLabel(Lbl);
  SI := FindSym(AstTable[Node].Text, SK_LABEL);
  If SI >= 0 Then Begin
    SymTable[SI].LblAddr := BinCurOffset;
    SymTable[SI].AsmName := Lbl;
    SymTable[SI].FuncLbl := Lbl;
  End;
  If FindSym(AstTable[Node].Text, SK_FUNC) >= 0 Then
    CodegenCurrentFunc := SymUpper(AstTable[Node].Text);
End;

Function CodegenCheckLabel(Const Name: String): Boolean;
Begin
  CodegenCheckLabel := True;
  If Name = '' Then Begin CodegenCheckLabel := False; Exit; End;
  If FindSym(Name, SK_LABEL) < 0 Then Begin
    CompileError('label reference mais non defini : ' + Name);
    CodegenCheckLabel := False;
  End Else Begin
    SymTable[FindSym(Name, SK_LABEL)].RefCnt :=
      SymTable[FindSym(Name, SK_LABEL)].RefCnt + 1;
  End;
End;

Procedure CodegenEmitGoto(Node: Integer);
Var HasTest: Boolean;
Begin
  If AstTable[Node].GotoU <> '' Then Begin
    If CodegenCheckLabel(AstTable[Node].GotoU) Then
      BinJmpLabel(CodegenLabelName(AstTable[Node].GotoU));
    Exit;
  End;

  HasTest := (AstTable[Node].GotoS <> '') Or (AstTable[Node].GotoF <> '');
  If HasTest Then Begin
    BinEmit8($85); BinEmit8($C0); { TEST EAX,EAX }
  End;
  If AstTable[Node].GotoS <> '' Then
    If CodegenCheckLabel(AstTable[Node].GotoS) Then
      BinJccLabel(5, CodegenLabelName(AstTable[Node].GotoS)); { JNZ }
  If AstTable[Node].GotoF <> '' Then
    If CodegenCheckLabel(AstTable[Node].GotoF) Then
      BinJccLabel(4, CodegenLabelName(AstTable[Node].GotoF)); { JZ }
End;

Function CodegenNewLocalLabel(Const Prefix: String): String;
Begin
  Inc(BinPLKCount);
  CodegenNewLocalLabel := Prefix + IntToStr(BinPLKCount);
End;

Function CodegenEmitStringLiteral(Const S: String): String;
Var
  OldSec : Integer;
  I      : Integer;
  Lbl    : String;
Begin
  Lbl := CodegenNewLocalLabel('_SNR_STR_');
  OldSec := BinCurSec;
  BinCurSec := BIN_SEC_RDATA;
  BinDefineLabel(Lbl);
  For I := 1 To Length(S) Do
    BinEmit8(Ord(S[I]));
  BinEmit8(0);
  BinCurSec := OldSec;
  CodegenEmitStringLiteral := Lbl;
End;

Procedure CodegenExpr(Node: Integer);
Var
  Lbl       : String;
  SI, FSI, PSI : Integer;
  Arg1, Arg2: Integer;
  ParamIdx  : Integer;
Begin
  If Node = 0 Then Begin
    BinMovRegLabel(0, '_SN_EMPTY');
    Exit;
  End;

  Case AstTable[Node].Kind Of
    NK_LITERAL:
      Begin
        Lbl := CodegenEmitStringLiteral(AstTable[Node].Text);
        BinMovRegLabel(0, Lbl);
      End;

    NK_VAR:
      Begin
        SI := AstTable[Node].SymRef;
        If SI >= 0 Then Begin
          Inc(SymTable[SI].RefCnt);
          If (Not SymTable[SI].Assigned) And (Not SymTable[SI].Warned) Then Begin
            CompileWarn('variable lue avant affectation : ' + SymTable[SI].Name);
            SymTable[SI].Warned := True;
          End;
          BinPushImm32(SymTable[SI].VarIdx);
          BinCallLabel('_SNRT_var_get');
          BinAddEspImm8(4);
        End Else
          BinMovRegLabel(0, '_SN_EMPTY');
      End;

    NK_SYSVAR:
      Begin
        If SymUpper(AstTable[Node].Text) = 'INPUT' Then
          BinCallLabel('_SNRT_input')
        Else
          BinMovRegLabel(0, '_SN_EMPTY');
      End;

    NK_CONCAT:
      Begin
        CodegenExpr(AstTable[Node].Left);
        BinPushReg(0);
        CodegenExpr(AstTable[Node].Right);
        BinMovRegReg(1, 0);
        BinPopReg(0);
        BinPushReg(1);
        BinPushReg(0);
        BinCallLabel('_SNRT_str_concat');
        BinAddEspImm8(8);
      End;

    NK_CALL:
      Begin
        Lbl := '';
        If SymUpper(AstTable[Node].Text) = 'LT' Then Lbl := '_SNRT_pred_lt'
        Else If SymUpper(AstTable[Node].Text) = 'LE' Then Lbl := '_SNRT_pred_le'
        Else If SymUpper(AstTable[Node].Text) = 'GT' Then Lbl := '_SNRT_pred_gt'
        Else If SymUpper(AstTable[Node].Text) = 'GE' Then Lbl := '_SNRT_pred_ge'
        Else If SymUpper(AstTable[Node].Text) = 'EQ' Then Lbl := '_SNRT_pred_eq'
        Else If SymUpper(AstTable[Node].Text) = 'NE' Then Lbl := '_SNRT_pred_ne'
        Else If SymUpper(AstTable[Node].Text) = 'IDENT' Then Lbl := '_SNRT_ident'
        Else If SymUpper(AstTable[Node].Text) = 'DIFFER' Then Lbl := '_SNRT_differ';

        If Lbl <> '' Then Begin
          Arg1 := AstTable[Node].FirstChild;
          If Arg1 <> 0 Then Arg2 := AstTable[Arg1].NextSibling Else Arg2 := 0;
          CodegenExpr(Arg2);
          BinPushReg(0);
          CodegenExpr(Arg1);
          BinPushReg(0);
          BinCallLabel(Lbl);
          BinAddEspImm8(8);
        End Else If SymUpper(AstTable[Node].Text) = 'SIZE' Then Begin
          Arg1 := AstTable[Node].FirstChild;
          CodegenExpr(Arg1);
          BinPushReg(0);
          BinCallLabel('_SNRT_size');
          BinAddEspImm8(4);
        End Else Begin
          FSI := FindSym(AstTable[Node].Text, SK_FUNC);
          If FSI >= 0 Then Begin
            Arg1 := AstTable[Node].FirstChild;
            ParamIdx := 0;
            While (Arg1 <> 0) And (ParamIdx < SymTable[FSI].ParamCnt) Do Begin
              PSI := FindSym(SymTable[FSI].Params[ParamIdx], SK_VAR);
              CodegenExpr(Arg1);
              If PSI >= 0 Then Begin
                BinPushReg(0);
                BinPushImm32(SymTable[PSI].VarIdx);
                BinCallLabel('_SNRT_var_set');
                BinAddEspImm8(8);
                SymTable[PSI].Assigned := True;
              End;
              Arg1 := AstTable[Arg1].NextSibling;
              Inc(ParamIdx);
            End;
            PSI := FindSym(AstTable[Node].Text, SK_LABEL);
            If PSI >= 0 Then Inc(SymTable[PSI].RefCnt);
            BinCallLabel(SymTable[FSI].FuncLbl);
            SI := FindSym(AstTable[Node].Text, SK_VAR);
            If SI >= 0 Then Begin
              BinPushImm32(SymTable[SI].VarIdx);
              BinCallLabel('_SNRT_var_get');
              BinAddEspImm8(4);
            End Else
              BinMovRegLabel(0, '_SN_EMPTY');
          End Else
            BinMovRegLabel(0, '_SN_EMPTY');
        End;
      End;

    Else
      BinMovRegLabel(0, '_SN_EMPTY');
  End;
End;

Procedure CodegenStmt(Node: Integer);
Var SI: Integer;
Begin
  CurLineNum := AstTable[Node].Line;
  CodegenDefineStmtLabel(Node);

  If AstTable[Node].Kind = NK_OUTPUT Then Begin
    CodegenExpr(AstTable[Node].Right);
    BinPushReg(0);
    BinCallLabel('_SNRT_output');
    BinAddEspImm8(4);
  End
  Else If AstTable[Node].Kind = NK_PATTERN Then Begin
    If (AstTable[Node].Left <> 0) And
       (AstTable[Node].Right = 0) And
       (AstTable[AstTable[Node].Left].Kind = NK_CALL) Then
      CodegenExpr(AstTable[Node].Left)
    Else Begin
      CodegenExpr(AstTable[Node].Right);
      BinPushReg(0);
      CodegenExpr(AstTable[Node].Left);
      BinPushReg(0);
      BinCallLabel('_SNRT_pat_match');
      BinAddEspImm8(8);
    End;
  End
  Else If AstTable[Node].Kind = NK_ASSIGN Then Begin
    CodegenExpr(AstTable[Node].Right);
    If AstTable[Node].Left <> 0 Then Begin
      SI := AstTable[AstTable[Node].Left].SymRef;
      If (SI >= 0) And (SymTable[SI].Kind = SK_VAR) Then Begin
        BinPushReg(0);
        BinPushImm32(SymTable[SI].VarIdx);
        BinCallLabel('_SNRT_var_set');
        BinAddEspImm8(8);
        SymTable[SI].Assigned := True;
      End;
    End;
    BinMovRegImm32(0, 1);
  End
  Else If AstTable[Node].Kind = NK_RETURN Then Begin
    If CodegenCurrentFunc = '' Then
      CompileWarn('RETURN hors fonction');
    If AstTable[Node].Left <> 0 Then Begin
      CodegenExpr(AstTable[Node].Left);
      If CodegenCurrentFunc <> '' Then Begin
        SI := FindSym(CodegenCurrentFunc, SK_VAR);
        If SI >= 0 Then Begin
          BinPushReg(0);
          BinPushImm32(SymTable[SI].VarIdx);
          BinCallLabel('_SNRT_var_set');
          BinAddEspImm8(8);
          SymTable[SI].Assigned := True;
        End;
      End;
    End;
    BinRet;
    Exit;
  End
  Else If AstTable[Node].Kind <> NK_STMT Then
    BinMovRegImm32(0, 1);

  CodegenEmitGoto(Node);
End;

Procedure WarnUnusedLabels;
Var I: Integer;
Begin
  For I := 0 To SymCount - 1 Do
    If (SymTable[I].Kind = SK_LABEL) And (SymTable[I].RefCnt = 0) Then Begin
      CurLineNum := SymTable[I].DeclLine;
      CompileWarn('label defini mais jamais reference : ' + SymTable[I].Name);
    End;
End;

{ CodegenProgram : passe 2 - parcours l AST et genere le squelette binaire. }
Procedure CodegenProgram;
Var Ch: Integer;
Begin
  BinCurSec := BIN_SEC_TEXT;
  BinRegisterKernel32Imports;
  If HasError Then Exit;

  EmitRuntimeMemory;
  EmitRuntimeStrings;
  EmitRuntimeIO;
  EmitRuntimePattern;
  EmitRuntimeNumericPredicates;
  EmitRuntimeStringPredicates;
  BinDefineLabel('_SNSTART');
  Ch := AstTable[AstRoot].FirstChild;
  While Ch <> 0 Do Begin
    CodegenStmt(Ch);
    Ch := AstTable[Ch].NextSibling;
  End;

  BinPushImm32(0);
  BinCallImport('ExitProcess');
  WarnUnusedLabels;
End;

{ ============================================================ }
{ TODO 08 - CONSTANTES x86/PE, PRIMITIVES BINAIRES, WritePE   }
{ ============================================================ }

Const
  REG_EAX = 0; REG_ECX = 1; REG_EDX = 2; REG_EBX = 3;
  REG_ESP = 4; REG_EBP = 5; REG_ESI = 6; REG_EDI = 7;
  CC_Z  =  4; CC_NZ =  5;
  CC_L  = 12; CC_GE = 13; CC_LE = 14; CC_G  = 15;
  IMAGE_BASE   = $00400000;
  SEC_ALIGN    = $1000;
  FILE_ALIGN   = $0200;
  HEADERS_SIZE = $0200;

{ --- Offset dans la section courante }
Function BinCurOffset: LongInt;
Begin
  Case BinCurSec Of
    BIN_SEC_TEXT:  BinCurOffset := BinCodeSize;
    BIN_SEC_RDATA: BinCurOffset := BinRDataSize;
    BIN_SEC_DATA:  BinCurOffset := BinDataSize;
    BIN_SEC_IDATA: BinCurOffset := BinIDataSize;
    Else BinCurOffset := 0;
  End;
End;

{ --- Emit un octet dans la section active }
Procedure BinEmit8(B: Byte);
Begin
  Case BinCurSec Of
    BIN_SEC_TEXT:  Begin If BinCodeSize  < MAX_CODE  Then Begin BinCode [BinCodeSize]  := B; Inc(BinCodeSize);  End; End;
    BIN_SEC_RDATA: Begin If BinRDataSize < MAX_RDATA Then Begin BinRData[BinRDataSize] := B; Inc(BinRDataSize); End; End;
    BIN_SEC_DATA:  Begin If BinDataSize  < MAX_DATA  Then Begin BinData [BinDataSize]  := B; Inc(BinDataSize);  End; End;
    BIN_SEC_IDATA: Begin If BinIDataSize < MAX_IDATA Then Begin BinIData[BinIDataSize] := B; Inc(BinIDataSize); End; End;
  End;
End;

{ --- Emit 4 octets little-endian }
Procedure BinEmit32(V: LongInt);
Begin
  BinEmit8(Byte(V And $FF));
  BinEmit8(Byte((V Shr  8) And $FF));
  BinEmit8(Byte((V Shr 16) And $FF));
  BinEmit8(Byte((V Shr 24) And $FF));
End;

{ --- Emit 4 octets + enregistre un fixup }
Procedure BinEmitRef32(Const Name: String; Kind: Integer);
Begin
  If FixupCount < MAX_FIXUPS Then Begin
    FixupTable[FixupCount].Offset  := BinCurOffset;
    FixupTable[FixupCount].Section := BinCurSec;
    FixupTable[FixupCount].Name    := Name;
    FixupTable[FixupCount].Kind    := Kind;
    Inc(FixupCount);
  End;
  BinEmit8(0); BinEmit8(0); BinEmit8(0); BinEmit8(0);
End;

{ --- Definit un label a la position courante }
Procedure BinDefineLabel(Const Name: String);
Begin
  If LabelCount < MAX_LABELS Then Begin
    LabelTable[LabelCount].Name    := Name;
    LabelTable[LabelCount].Section := BinCurSec;
    LabelTable[LabelCount].Offset  := BinCurOffset;
    Inc(LabelCount);
  End;
End;

{ --- Cherche un label ; retourne l index ou -1 }
Function BinFindLabel(Const Name: String): Integer;
Var I: Integer;
Begin
  BinFindLabel := -1;
  For I := 0 To LabelCount - 1 Do
    If LabelTable[I].Name = Name Then Begin BinFindLabel := I; Exit; End;
End;

{ --- Enregistre un import Win32 ; retourne l index }
Function BinAddImport(Const DllName, FuncName: String): Integer;
Var I: Integer;
Begin
  For I := 0 To ImportCount - 1 Do
    If (ImportTable[I].DllName = DllName) And
       (ImportTable[I].FuncName = FuncName) Then Begin BinAddImport := I; Exit; End;
  If ImportCount >= MAX_IMPORTS Then Begin BinAddImport := -1; Exit; End;
  I := ImportCount; Inc(ImportCount);
  ImportTable[I].DllName  := DllName;
  ImportTable[I].FuncName := FuncName;
  ImportTable[I].IATOff   := -1;
  ImportTable[I].LabelNm  := '__imp__' + FuncName;
  BinAddImport := I;
End;

Procedure BinRegisterKernel32Imports;
Begin
  If BinAddImport('kernel32.dll', 'ExitProcess') < 0 Then Begin CompileError('table des imports pleine'); Exit; End;
  If BinAddImport('kernel32.dll', 'GetProcessHeap') < 0 Then Begin CompileError('table des imports pleine'); Exit; End;
  If BinAddImport('kernel32.dll', 'HeapAlloc') < 0 Then Begin CompileError('table des imports pleine'); Exit; End;
  If BinAddImport('kernel32.dll', 'HeapFree') < 0 Then Begin CompileError('table des imports pleine'); Exit; End;
  If BinAddImport('kernel32.dll', 'GetStdHandle') < 0 Then Begin CompileError('table des imports pleine'); Exit; End;
  If BinAddImport('kernel32.dll', 'WriteFile') < 0 Then Begin CompileError('table des imports pleine'); Exit; End;
  If BinAddImport('kernel32.dll', 'ReadFile') < 0 Then Begin CompileError('table des imports pleine'); Exit; End;
End;

{ ============================================================ }
{ TODO 08 - HELPERS x86                                       }
{ ============================================================ }

Procedure BinPushReg(R: Integer);  Begin BinEmit8($50 Or R); End;
Procedure BinPopReg (R: Integer);  Begin BinEmit8($58 Or R); End;
Procedure BinRet;                  Begin BinEmit8($C3); End;

Procedure BinXorRegReg(R: Integer);
Begin BinEmit8($31); BinEmit8($C0 Or (R Shl 3) Or R); End;

Procedure BinMovRegImm32(R: Integer; V: LongInt);
Begin BinEmit8($B8 Or R); BinEmit32(V); End;

Procedure BinMovRegLabel(R: Integer; Const Name: String);
Begin BinEmit8($B8 Or R); BinEmitRef32(Name, BIN_FIX_ABS32); End;

Procedure BinPushImm32(V: LongInt);
Begin BinEmit8($68); BinEmit32(V); End;

Procedure BinPushLabel(Const Name: String);
Begin BinEmit8($68); BinEmitRef32(Name, BIN_FIX_ABS32); End;

Procedure BinAddEspImm8(N: Integer);
Begin BinEmit8($83); BinEmit8($C4); BinEmit8(Byte(N And $FF)); End;

Procedure BinCallLabel(Const Name: String);
Begin BinEmit8($E8); BinEmitRef32(Name, BIN_FIX_REL32); End;

{ CALL [__imp__FuncName]  (FF 15 <abs-va-iat-entry>) }
Procedure BinCallImport(Const FuncName: String);
Begin
  If BinAddImport('kernel32.dll', FuncName) < 0 Then Begin
    CompileError('table des imports pleine');
    Exit;
  End;
  BinEmit8($FF); BinEmit8($15);
  BinEmitRef32('__imp__' + FuncName, BIN_FIX_IMP32);
End;

Procedure BinJmpLabel(Const Name: String);
Begin BinEmit8($E9); BinEmitRef32(Name, BIN_FIX_REL32); End;

Procedure BinJccLabel(CC: Integer; Const Name: String);
Begin BinEmit8($0F); BinEmit8($80 Or CC); BinEmitRef32(Name, BIN_FIX_REL32); End;

{ MOV EAX, [EBP+off] }
Procedure BinMovEaxMemBpPos(Off: Integer);
Begin BinEmit8($8B); BinEmit8($45); BinEmit8(Byte(Off And $FF)); End;

{ MOV [EBP-off], EAX }
Procedure BinMovMemBpNegEax(Off: Integer);
Begin BinEmit8($89); BinEmit8($45); BinEmit8(Byte((-Off) And $FF)); End;

{ MOV EAX, [EBP-off] }
Procedure BinMovEaxMemBpNeg(Off: Integer);
Begin BinEmit8($8B); BinEmit8($45); BinEmit8(Byte((-Off) And $FF)); End;

{ PUSH EBP / MOV EBP,ESP }
Procedure BinPrologue;
Begin BinPushReg(REG_EBP); BinEmit8($89); BinEmit8($E5); End;

{ MOV ESP,EBP / POP EBP }
Procedure BinEpilogue;
Begin BinEmit8($89); BinEmit8($EC); BinPopReg(REG_EBP); End;

{ ============================================================ }
{ TODO 09 - RUNTIME EMBARQUE : VARIABLES ET MEMOIRE            }
{ ============================================================ }

Procedure BinPushMemBpPos(Off: Integer);
Begin BinEmit8($FF); BinEmit8($75); BinEmit8(Byte(Off And $FF)); End;

Procedure BinMovRegMemBpPos(R, Off: Integer);
Begin BinEmit8($8B); BinEmit8(Byte($45 Or ((R And 7) Shl 3))); BinEmit8(Byte(Off And $FF)); End;

{ MOV [_SNV_TABLE + ECX*4], EAX }
Procedure BinMovSnvTableEcxEax;
Begin
  BinEmit8($89); BinEmit8($04); BinEmit8($8D);
  BinEmitRef32('_SNV_TABLE', BIN_FIX_ABS32);
End;

{ MOV EAX, [_SNV_TABLE + ECX*4] }
Procedure BinMovEaxSnvTableEcx;
Begin
  BinEmit8($8B); BinEmit8($04); BinEmit8($8D);
  BinEmitRef32('_SNV_TABLE', BIN_FIX_ABS32);
End;

Procedure BinTestEaxEax;
Begin BinEmit8($85); BinEmit8($C0); End;

Procedure EmitRuntimeMemoryData;
Var
  OldSec : Integer;
  I      : Integer;
Begin
  OldSec := BinCurSec;

  BinCurSec := BIN_SEC_RDATA;
  BinDefineLabel('_SN_EMPTY');
  BinEmit8(0);

  BinCurSec := BIN_SEC_DATA;
  BinDefineLabel('_SNV_TABLE');
  For I := 0 To MAX_VARS - 1 Do
    BinEmit32(0);

  BinCurSec := OldSec;
End;

Procedure EmitRuntimeVarSet;
Begin
  BinDefineLabel('_SNRT_var_set');
  BinPrologue;
  BinMovRegMemBpPos(REG_ECX, 8);  { idx }
  BinMovRegMemBpPos(REG_EAX, 12); { ptr }
  BinMovSnvTableEcxEax;
  BinMovRegImm32(REG_EAX, 1);
  BinEpilogue;
  BinRet;
End;

Procedure EmitRuntimeVarGet;
Begin
  BinDefineLabel('_SNRT_var_get');
  BinPrologue;
  BinMovRegMemBpPos(REG_ECX, 8);  { idx }
  BinMovEaxSnvTableEcx;
  BinTestEaxEax;
  BinJccLabel(CC_NZ, '_SNRT_var_get_done');
  BinMovRegLabel(REG_EAX, '_SN_EMPTY');
  BinDefineLabel('_SNRT_var_get_done');
  BinEpilogue;
  BinRet;
End;

Procedure EmitRuntimeHeapAlloc;
Begin
  BinDefineLabel('_SNRT_heap_alloc');
  BinPrologue;
  BinCallImport('GetProcessHeap');
  BinPushMemBpPos(8);       { dwBytes }
  BinPushImm32(8);          { HEAP_ZERO_MEMORY }
  BinPushReg(REG_EAX);      { hHeap }
  BinCallImport('HeapAlloc');
  BinEpilogue;
  BinRet;
End;

Procedure EmitRuntimeMemory;
Begin
  EmitRuntimeMemoryData;
  BinCurSec := BIN_SEC_TEXT;
  EmitRuntimeVarSet;
  EmitRuntimeVarGet;
  EmitRuntimeHeapAlloc;
End;

{ ============================================================ }
{ TODO 10 - RUNTIME EMBARQUE : OPERATIONS SUR CHAINES          }
{ ============================================================ }

Procedure BinSubEspImm8(N: Integer);
Begin BinEmit8($83); BinEmit8($EC); BinEmit8(Byte(N And $FF)); End;

Procedure BinMovRegReg(Dst, Src: Integer);
Begin BinEmit8($89); BinEmit8(Byte($C0 Or ((Src And 7) Shl 3) Or (Dst And 7))); End;

Procedure BinMovRegMemBpNeg(R, Off: Integer);
Begin BinEmit8($8B); BinEmit8(Byte($45 Or ((R And 7) Shl 3))); BinEmit8(Byte((-Off) And $FF)); End;

Procedure BinMovMemBpNegReg(Off, R: Integer);
Begin BinEmit8($89); BinEmit8(Byte($45 Or ((R And 7) Shl 3))); BinEmit8(Byte((-Off) And $FF)); End;

Procedure BinMovRegMemReg(R, Base: Integer);
Begin BinEmit8($8B); BinEmit8(Byte((R Shl 3) Or Base)); End;

Procedure BinMovByteAlMemReg(Base: Integer);
Begin BinEmit8($8A); BinEmit8(Byte(Base And 7)); End;

Procedure BinMovByteDlMemReg(Base: Integer);
Begin BinEmit8($8A); BinEmit8(Byte($10 Or (Base And 7))); End;

Procedure BinMovByteMemRegAl(Base: Integer);
Begin BinEmit8($88); BinEmit8(Byte(Base And 7)); End;

Procedure BinMovByteMemRegDl(Base: Integer);
Begin BinEmit8($88); BinEmit8(Byte($10 Or (Base And 7))); End;

Procedure BinMovByteMemRegImm8(Base: Integer; V: Byte);
Begin BinEmit8($C6); BinEmit8(Byte(Base And 7)); BinEmit8(V); End;

Procedure BinMovzxRegByteMemReg(R, Base: Integer);
Begin BinEmit8($0F); BinEmit8($B6); BinEmit8(Byte((R Shl 3) Or Base)); End;

Procedure BinCmpAlDl;
Begin BinEmit8($38); BinEmit8($D0); End;

Procedure BinCmpClImm8(V: Byte);
Begin BinEmit8($80); BinEmit8($F9); BinEmit8(V); End;

Procedure BinCmpRegImm8(R: Integer; V: Byte);
Begin BinEmit8($83); BinEmit8(Byte($F8 Or (R And 7))); BinEmit8(V); End;

Procedure BinTestRegReg(R: Integer);
Begin BinEmit8($85); BinEmit8(Byte($C0 Or ((R And 7) Shl 3) Or (R And 7))); End;

Procedure BinIncReg(R: Integer);
Begin BinEmit8($40 Or (R And 7)); End;

Procedure BinDecReg(R: Integer);
Begin BinEmit8($48 Or (R And 7)); End;

Procedure BinNegReg(R: Integer);
Begin BinEmit8($F7); BinEmit8(Byte($D8 Or (R And 7))); End;

Procedure BinAddRegReg(Dst, Src: Integer);
Begin BinEmit8($01); BinEmit8(Byte($C0 Or ((Src And 7) Shl 3) Or (Dst And 7))); End;

Procedure BinAddRegImm8(R, N: Integer);
Begin BinEmit8($83); BinEmit8(Byte($C0 Or (R And 7))); BinEmit8(Byte(N And $FF)); End;

Procedure BinSubRegImm8(R, N: Integer);
Begin BinEmit8($83); BinEmit8(Byte($E8 Or (R And 7))); BinEmit8(Byte(N And $FF)); End;

Procedure BinImulRegRegImm8(Dst, Src, N: Integer);
Begin BinEmit8($6B); BinEmit8(Byte($C0 Or ((Dst And 7) Shl 3) Or (Src And 7))); BinEmit8(Byte(N And $FF)); End;

Procedure BinXorEdxEdx;
Begin BinEmit8($31); BinEmit8($D2); End;

Procedure BinDivReg(R: Integer);
Begin BinEmit8($F7); BinEmit8(Byte($F0 Or (R And 7))); End;

Procedure BinCmpByteMemSibEsiEaxImm8(V: Byte);
Begin BinEmit8($80); BinEmit8($3C); BinEmit8($06); BinEmit8(V); End;

Procedure EmitRuntimeStrLen;
Begin
  BinDefineLabel('_SNRT_str_len');
  BinPrologue;
  BinPushReg(REG_ESI);
  BinMovRegMemBpPos(REG_ESI, 8);
  BinTestRegReg(REG_ESI);
  BinJccLabel(CC_NZ, '_SNRT_strlen_have_ptr');
  BinMovRegLabel(REG_ESI, '_SN_EMPTY');
  BinDefineLabel('_SNRT_strlen_have_ptr');
  BinXorRegReg(REG_EAX);
  BinDefineLabel('_SNRT_strlen_loop');
  BinCmpByteMemSibEsiEaxImm8(0);
  BinJccLabel(CC_Z, '_SNRT_strlen_done');
  BinIncReg(REG_EAX);
  BinJmpLabel('_SNRT_strlen_loop');
  BinDefineLabel('_SNRT_strlen_done');
  BinPopReg(REG_ESI);
  BinEpilogue;
  BinRet;
End;

Procedure EmitRuntimeStrConcat;
Begin
  BinDefineLabel('_SNRT_str_concat');
  BinPrologue;
  BinSubEspImm8(12);
  BinPushReg(REG_EBX);
  BinPushReg(REG_ESI);
  BinPushReg(REG_EDI);

  BinMovEaxMemBpPos(8);
  BinTestEaxEax;
  BinJccLabel(CC_NZ, '_SNRT_concat_s1_ok');
  BinMovRegLabel(REG_EAX, '_SN_EMPTY');
  BinDefineLabel('_SNRT_concat_s1_ok');
  BinMovMemBpNegReg(4, REG_EAX);

  BinMovEaxMemBpPos(12);
  BinTestEaxEax;
  BinJccLabel(CC_NZ, '_SNRT_concat_s2_ok');
  BinMovRegLabel(REG_EAX, '_SN_EMPTY');
  BinDefineLabel('_SNRT_concat_s2_ok');
  BinMovMemBpNegReg(8, REG_EAX);

  BinPushMemBpPos(-4);
  BinCallLabel('_SNRT_str_len');
  BinAddEspImm8(4);
  BinMovRegReg(REG_EBX, REG_EAX);

  BinPushMemBpPos(-8);
  BinCallLabel('_SNRT_str_len');
  BinAddEspImm8(4);
  BinMovRegReg(REG_ECX, REG_EAX);

  BinMovRegReg(REG_EAX, REG_EBX);
  BinAddRegReg(REG_EAX, REG_ECX);
  BinIncReg(REG_EAX);
  BinPushReg(REG_EAX);
  BinCallLabel('_SNRT_heap_alloc');
  BinAddEspImm8(4);
  BinTestEaxEax;
  BinJccLabel(CC_NZ, '_SNRT_concat_alloc_ok');
  BinMovRegLabel(REG_EAX, '_SN_EMPTY');
  BinJmpLabel('_SNRT_concat_done');

  BinDefineLabel('_SNRT_concat_alloc_ok');
  BinMovMemBpNegReg(12, REG_EAX);
  BinMovRegMemBpNeg(REG_ESI, 4);
  BinMovRegMemBpNeg(REG_EDI, 12);
  BinDefineLabel('_SNRT_concat_copy1');
  BinMovByteAlMemReg(REG_ESI);
  BinEmit8($84); BinEmit8($C0); { TEST AL,AL }
  BinJccLabel(CC_Z, '_SNRT_concat_copy2_start');
  BinMovByteMemRegAl(REG_EDI);
  BinIncReg(REG_ESI);
  BinIncReg(REG_EDI);
  BinJmpLabel('_SNRT_concat_copy1');

  BinDefineLabel('_SNRT_concat_copy2_start');
  BinMovRegMemBpNeg(REG_ESI, 8);
  BinDefineLabel('_SNRT_concat_copy2');
  BinMovByteAlMemReg(REG_ESI);
  BinMovByteMemRegAl(REG_EDI);
  BinIncReg(REG_ESI);
  BinIncReg(REG_EDI);
  BinEmit8($84); BinEmit8($C0); { TEST AL,AL }
  BinJccLabel(CC_NZ, '_SNRT_concat_copy2');
  BinMovRegMemBpNeg(REG_EAX, 12);

  BinDefineLabel('_SNRT_concat_done');
  BinPopReg(REG_EDI);
  BinPopReg(REG_ESI);
  BinPopReg(REG_EBX);
  BinEpilogue;
  BinRet;
End;

Procedure EmitRuntimeIntToStr;
Begin
  BinDefineLabel('_SNRT_int_to_str');
  BinPrologue;
  BinSubEspImm8(4);
  BinPushReg(REG_EBX);
  BinPushReg(REG_EDI);

  BinPushImm32(12);
  BinCallLabel('_SNRT_heap_alloc');
  BinAddEspImm8(4);
  BinTestEaxEax;
  BinJccLabel(CC_NZ, '_SNRT_itos_alloc_ok');
  BinMovRegLabel(REG_EAX, '_SN_EMPTY');
  BinJmpLabel('_SNRT_itos_done');

  BinDefineLabel('_SNRT_itos_alloc_ok');
  BinMovMemBpNegReg(4, REG_EAX);
  BinMovRegReg(REG_EDI, REG_EAX);
  BinAddRegImm8(REG_EDI, 11);
  BinMovByteMemRegImm8(REG_EDI, 0);
  BinMovRegMemBpPos(REG_EBX, 8);
  BinXorRegReg(REG_ECX);
  BinTestRegReg(REG_EBX);
  BinJccLabel(9, '_SNRT_itos_abs_ready'); { JNS }
  BinMovRegImm32(REG_ECX, 1);
  BinNegReg(REG_EBX);
  BinDefineLabel('_SNRT_itos_abs_ready');

  BinTestRegReg(REG_EBX);
  BinJccLabel(CC_NZ, '_SNRT_itos_loop');
  BinDecReg(REG_EDI);
  BinMovByteMemRegImm8(REG_EDI, Ord('0'));
  BinJmpLabel('_SNRT_itos_sign');

  BinDefineLabel('_SNRT_itos_loop');
  BinMovRegReg(REG_EAX, REG_EBX);
  BinXorEdxEdx;
  BinMovRegImm32(REG_ECX, 10);
  BinDivReg(REG_ECX);
  BinAddRegImm8(REG_EDX, Ord('0'));
  BinDecReg(REG_EDI);
  BinMovByteMemRegDl(REG_EDI);
  BinMovRegReg(REG_EBX, REG_EAX);
  BinTestRegReg(REG_EBX);
  BinJccLabel(CC_NZ, '_SNRT_itos_loop');

  BinDefineLabel('_SNRT_itos_sign');
  BinMovRegMemBpPos(REG_EBX, 8);
  BinTestRegReg(REG_EBX);
  BinJccLabel(9, '_SNRT_itos_return'); { JNS }
  BinDecReg(REG_EDI);
  BinMovByteMemRegImm8(REG_EDI, Ord('-'));

  BinDefineLabel('_SNRT_itos_return');
  BinMovRegReg(REG_EAX, REG_EDI);

  BinDefineLabel('_SNRT_itos_done');
  BinPopReg(REG_EDI);
  BinPopReg(REG_EBX);
  BinEpilogue;
  BinRet;
End;

Procedure EmitRuntimeStrToInt;
Begin
  BinDefineLabel('_SNRT_str_to_int');
  BinPrologue;
  BinPushReg(REG_EBX);
  BinPushReg(REG_ESI);
  BinMovRegMemBpPos(REG_ESI, 8);
  BinTestRegReg(REG_ESI);
  BinJccLabel(CC_NZ, '_SNRT_atoi_have_ptr');
  BinMovRegLabel(REG_ESI, '_SN_EMPTY');
  BinDefineLabel('_SNRT_atoi_have_ptr');
  BinXorRegReg(REG_EAX);
  BinMovRegImm32(REG_EBX, 1);
  BinXorEdxEdx;
  BinMovByteAlMemReg(REG_ESI);
  BinCmpRegImm8(REG_EAX, Ord('-'));
  BinJccLabel(CC_NZ, '_SNRT_atoi_loop');
  BinMovRegImm32(REG_EBX, -1);
  BinIncReg(REG_ESI);
  BinXorRegReg(REG_EAX);

  BinDefineLabel('_SNRT_atoi_loop');
  BinMovzxRegByteMemReg(REG_ECX, REG_ESI);
  BinCmpClImm8(Ord('0'));
  BinJccLabel(CC_L, '_SNRT_atoi_finish');
  BinCmpClImm8(Ord('9'));
  BinJccLabel(CC_G, '_SNRT_atoi_finish');
  BinMovRegImm32(REG_EDX, 1);
  BinSubRegImm8(REG_ECX, Ord('0'));
  BinImulRegRegImm8(REG_EAX, REG_EAX, 10);
  BinAddRegReg(REG_EAX, REG_ECX);
  BinIncReg(REG_ESI);
  BinJmpLabel('_SNRT_atoi_loop');

  BinDefineLabel('_SNRT_atoi_finish');
  BinTestRegReg(REG_EDX);
  BinJccLabel(CC_NZ, '_SNRT_atoi_has_digit');
  BinXorRegReg(REG_EAX);
  BinJmpLabel('_SNRT_atoi_done');
  BinDefineLabel('_SNRT_atoi_has_digit');
  BinCmpRegImm8(REG_EBX, 1);
  BinJccLabel(CC_Z, '_SNRT_atoi_done');
  BinNegReg(REG_EAX);

  BinDefineLabel('_SNRT_atoi_done');
  BinPopReg(REG_ESI);
  BinPopReg(REG_EBX);
  BinEpilogue;
  BinRet;
End;

Procedure EmitRuntimeStrEq;
Begin
  BinDefineLabel('_SNRT_str_eq');
  BinPrologue;
  BinPushReg(REG_ESI);
  BinPushReg(REG_EDI);

  BinMovRegMemBpPos(REG_ESI, 8);
  BinTestRegReg(REG_ESI);
  BinJccLabel(CC_NZ, '_SNRT_streq_s1_ok');
  BinMovRegLabel(REG_ESI, '_SN_EMPTY');
  BinDefineLabel('_SNRT_streq_s1_ok');
  BinMovRegMemBpPos(REG_EDI, 12);
  BinTestRegReg(REG_EDI);
  BinJccLabel(CC_NZ, '_SNRT_streq_s2_ok');
  BinMovRegLabel(REG_EDI, '_SN_EMPTY');
  BinDefineLabel('_SNRT_streq_s2_ok');

  BinDefineLabel('_SNRT_streq_loop');
  BinMovByteAlMemReg(REG_ESI);
  BinMovByteDlMemReg(REG_EDI);
  BinCmpAlDl;
  BinJccLabel(CC_NZ, '_SNRT_streq_false');
  BinEmit8($84); BinEmit8($C0); { TEST AL,AL }
  BinJccLabel(CC_Z, '_SNRT_streq_true');
  BinIncReg(REG_ESI);
  BinIncReg(REG_EDI);
  BinJmpLabel('_SNRT_streq_loop');

  BinDefineLabel('_SNRT_streq_true');
  BinMovRegImm32(REG_EAX, 1);
  BinJmpLabel('_SNRT_streq_done');
  BinDefineLabel('_SNRT_streq_false');
  BinXorRegReg(REG_EAX);

  BinDefineLabel('_SNRT_streq_done');
  BinPopReg(REG_EDI);
  BinPopReg(REG_ESI);
  BinEpilogue;
  BinRet;
End;

Procedure EmitRuntimeStrings;
Begin
  BinCurSec := BIN_SEC_TEXT;
  EmitRuntimeStrLen;
  EmitRuntimeStrConcat;
  EmitRuntimeIntToStr;
  EmitRuntimeStrToInt;
  EmitRuntimeStrEq;
End;

{ ============================================================ }
{ TODO 11 - RUNTIME EMBARQUE : ENTREES / SORTIES               }
{ ============================================================ }

Procedure BinMovRegAbsLabel(R: Integer; Const Name: String);
Begin
  If R = REG_EAX Then Begin
    BinEmit8($A1);
    BinEmitRef32(Name, BIN_FIX_ABS32);
  End Else Begin
    BinEmit8($8B);
    BinEmit8(Byte($05 Or ((R And 7) Shl 3)));
    BinEmitRef32(Name, BIN_FIX_ABS32);
  End;
End;

Procedure BinMovAbsLabelReg(Const Name: String; R: Integer);
Begin
  If R = REG_EAX Then Begin
    BinEmit8($A3);
    BinEmitRef32(Name, BIN_FIX_ABS32);
  End Else Begin
    BinEmit8($89);
    BinEmit8(Byte($05 Or ((R And 7) Shl 3)));
    BinEmitRef32(Name, BIN_FIX_ABS32);
  End;
End;

Procedure BinPushAbsLabel(Const Name: String);
Begin
  BinEmit8($FF); BinEmit8($35);
  BinEmitRef32(Name, BIN_FIX_ABS32);
End;

Procedure BinCmpRegReg(Left, Right: Integer);
Begin BinEmit8($39); BinEmit8(Byte($C0 Or ((Right And 7) Shl 3) Or (Left And 7))); End;

Procedure BinMovDlMemSibEsiEax;
Begin BinEmit8($8A); BinEmit8($14); BinEmit8($06); End;

Procedure BinCmpDlImm8(V: Byte);
Begin BinEmit8($80); BinEmit8($FA); BinEmit8(V); End;

Procedure BinMovByteMemSibEsiEaxImm8(V: Byte);
Begin BinEmit8($C6); BinEmit8($04); BinEmit8($06); BinEmit8(V); End;

Procedure EmitRuntimeIOData;
Var
  OldSec : Integer;
  I      : Integer;
Begin
  OldSec := BinCurSec;

  BinCurSec := BIN_SEC_RDATA;
  BinDefineLabel('_SN_CRLF');
  BinEmit8(13); BinEmit8(10);

  BinCurSec := BIN_SEC_DATA;
  BinDefineLabel('_SNH_STDOUT'); BinEmit32(0);
  BinDefineLabel('_SNH_STDIN');  BinEmit32(0);
  BinDefineLabel('_SN_IO_COUNT'); BinEmit32(0);
  BinDefineLabel('_SN_INPUT_BUF');
  For I := 0 To MAX_LINE Do
    BinEmit8(0);

  BinCurSec := OldSec;
End;

Procedure EmitRuntimeOutput;
Begin
  BinDefineLabel('_SNRT_output');
  BinPrologue;
  BinPushReg(REG_EBX);

  BinMovRegMemBpPos(REG_EBX, 8);
  BinTestRegReg(REG_EBX);
  BinJccLabel(CC_NZ, '_SNRT_output_have_str');
  BinMovRegLabel(REG_EBX, '_SN_EMPTY');
  BinDefineLabel('_SNRT_output_have_str');

  BinMovRegAbsLabel(REG_EAX, '_SNH_STDOUT');
  BinTestEaxEax;
  BinJccLabel(CC_NZ, '_SNRT_output_have_handle');
  BinPushImm32(-11);
  BinCallImport('GetStdHandle');
  BinMovAbsLabelReg('_SNH_STDOUT', REG_EAX);
  BinDefineLabel('_SNRT_output_have_handle');

  BinPushReg(REG_EBX);
  BinCallLabel('_SNRT_str_len');
  BinAddEspImm8(4);

  BinPushImm32(0);
  BinPushLabel('_SN_IO_COUNT');
  BinPushReg(REG_EAX);
  BinPushReg(REG_EBX);
  BinPushAbsLabel('_SNH_STDOUT');
  BinCallImport('WriteFile');

  BinPushImm32(0);
  BinPushLabel('_SN_IO_COUNT');
  BinPushImm32(2);
  BinPushLabel('_SN_CRLF');
  BinPushAbsLabel('_SNH_STDOUT');
  BinCallImport('WriteFile');

  BinMovRegImm32(REG_EAX, 1);
  BinPopReg(REG_EBX);
  BinEpilogue;
  BinRet;
End;

Procedure EmitRuntimeInput;
Begin
  BinDefineLabel('_SNRT_input');
  BinPrologue;
  BinPushReg(REG_ESI);

  BinMovRegAbsLabel(REG_EAX, '_SNH_STDIN');
  BinTestEaxEax;
  BinJccLabel(CC_NZ, '_SNRT_input_have_handle');
  BinPushImm32(-10);
  BinCallImport('GetStdHandle');
  BinMovAbsLabelReg('_SNH_STDIN', REG_EAX);
  BinDefineLabel('_SNRT_input_have_handle');

  BinXorRegReg(REG_EAX);
  BinMovAbsLabelReg('_SN_IO_COUNT', REG_EAX);
  BinPushImm32(0);
  BinPushLabel('_SN_IO_COUNT');
  BinPushImm32(MAX_LINE);
  BinPushLabel('_SN_INPUT_BUF');
  BinPushAbsLabel('_SNH_STDIN');
  BinCallImport('ReadFile');

  BinMovRegLabel(REG_ESI, '_SN_INPUT_BUF');
  BinXorRegReg(REG_EAX);
  BinMovRegAbsLabel(REG_ECX, '_SN_IO_COUNT');

  BinDefineLabel('_SNRT_input_scan');
  BinCmpRegReg(REG_EAX, REG_ECX);
  BinJccLabel(CC_GE, '_SNRT_input_terminate');
  BinMovDlMemSibEsiEax;
  BinCmpDlImm8(13);
  BinJccLabel(CC_Z, '_SNRT_input_terminate');
  BinCmpDlImm8(10);
  BinJccLabel(CC_Z, '_SNRT_input_terminate');
  BinIncReg(REG_EAX);
  BinJmpLabel('_SNRT_input_scan');

  BinDefineLabel('_SNRT_input_terminate');
  BinMovByteMemSibEsiEaxImm8(0);
  BinPushLabel('_SN_INPUT_BUF');
  BinPushLabel('_SN_EMPTY');
  BinCallLabel('_SNRT_str_concat');
  BinAddEspImm8(8);

  BinPopReg(REG_ESI);
  BinEpilogue;
  BinRet;
End;

Procedure EmitRuntimeIO;
Begin
  EmitRuntimeIOData;
  BinCurSec := BIN_SEC_TEXT;
  EmitRuntimeOutput;
  EmitRuntimeInput;
End;

{ ============================================================ }
{ TODO 12 - RUNTIME EMBARQUE : PATTERN MATCHING                }
{ ============================================================ }

Procedure EmitRuntimePatMatch;
Begin
  BinDefineLabel('_SNRT_pat_match');
  BinPrologue;
  BinPushReg(REG_EBX);
  BinPushReg(REG_ESI);
  BinPushReg(REG_EDI);

  BinMovRegMemBpPos(REG_ESI, 8);  { subject }
  BinTestRegReg(REG_ESI);
  BinJccLabel(CC_NZ, '_SNRT_pat_subject_ok');
  BinMovRegLabel(REG_ESI, '_SN_EMPTY');
  BinDefineLabel('_SNRT_pat_subject_ok');

  BinMovRegMemBpPos(REG_EDI, 12); { pattern }
  BinTestRegReg(REG_EDI);
  BinJccLabel(CC_NZ, '_SNRT_pat_pattern_ok');
  BinMovRegLabel(REG_EDI, '_SN_EMPTY');
  BinDefineLabel('_SNRT_pat_pattern_ok');

  BinMovByteAlMemReg(REG_EDI);
  BinEmit8($84); BinEmit8($C0); { TEST AL,AL }
  BinJccLabel(CC_Z, '_SNRT_pat_true');

  BinDefineLabel('_SNRT_pat_outer');
  BinMovRegReg(REG_EBX, REG_ESI);
  BinMovRegMemBpPos(REG_EDI, 12);
  BinTestRegReg(REG_EDI);
  BinJccLabel(CC_NZ, '_SNRT_pat_inner');
  BinMovRegLabel(REG_EDI, '_SN_EMPTY');

  BinDefineLabel('_SNRT_pat_inner');
  BinMovByteDlMemReg(REG_EDI);
  BinCmpDlImm8(0);
  BinJccLabel(CC_Z, '_SNRT_pat_true');
  BinMovByteAlMemReg(REG_EBX);
  BinEmit8($84); BinEmit8($C0); { TEST AL,AL }
  BinJccLabel(CC_Z, '_SNRT_pat_false');
  BinCmpAlDl;
  BinJccLabel(CC_NZ, '_SNRT_pat_advance');
  BinIncReg(REG_EBX);
  BinIncReg(REG_EDI);
  BinJmpLabel('_SNRT_pat_inner');

  BinDefineLabel('_SNRT_pat_advance');
  BinMovByteAlMemReg(REG_ESI);
  BinEmit8($84); BinEmit8($C0); { TEST AL,AL }
  BinJccLabel(CC_Z, '_SNRT_pat_false');
  BinIncReg(REG_ESI);
  BinJmpLabel('_SNRT_pat_outer');

  BinDefineLabel('_SNRT_pat_true');
  BinMovRegImm32(REG_EAX, 1);
  BinJmpLabel('_SNRT_pat_done');

  BinDefineLabel('_SNRT_pat_false');
  BinXorRegReg(REG_EAX);

  BinDefineLabel('_SNRT_pat_done');
  BinPopReg(REG_EDI);
  BinPopReg(REG_ESI);
  BinPopReg(REG_EBX);
  BinEpilogue;
  BinRet;
End;

Procedure EmitRuntimePattern;
Begin
  BinCurSec := BIN_SEC_TEXT;
  EmitRuntimePatMatch;
End;

{ ============================================================ }
{ TODO 13 - RUNTIME EMBARQUE : PREDICATS NUMERIQUES            }
{ ============================================================ }

Procedure EmitRuntimeNumericPred(Const Name: String; CC: Integer);
Begin
  BinDefineLabel(Name);
  BinPrologue;
  BinPushReg(REG_EBX);

  BinPushMemBpPos(8);
  BinCallLabel('_SNRT_str_to_int');
  BinAddEspImm8(4);
  BinMovRegReg(REG_EBX, REG_EAX);

  BinPushMemBpPos(12);
  BinCallLabel('_SNRT_str_to_int');
  BinAddEspImm8(4);

  BinCmpRegReg(REG_EBX, REG_EAX);
  BinJccLabel(CC, Name + '_true');
  BinXorRegReg(REG_EAX);
  BinJmpLabel(Name + '_done');

  BinDefineLabel(Name + '_true');
  BinMovRegImm32(REG_EAX, 1);

  BinDefineLabel(Name + '_done');
  BinPopReg(REG_EBX);
  BinEpilogue;
  BinRet;
End;

Procedure EmitRuntimeNumericPredicates;
Begin
  BinCurSec := BIN_SEC_TEXT;
  EmitRuntimeNumericPred('_SNRT_pred_lt', CC_L);
  EmitRuntimeNumericPred('_SNRT_pred_le', CC_LE);
  EmitRuntimeNumericPred('_SNRT_pred_gt', CC_G);
  EmitRuntimeNumericPred('_SNRT_pred_ge', CC_GE);
  EmitRuntimeNumericPred('_SNRT_pred_eq', CC_Z);
  EmitRuntimeNumericPred('_SNRT_pred_ne', CC_NZ);
End;

{ ============================================================ }
{ TODO 14 - RUNTIME EMBARQUE : PREDICATS DE CHAINES            }
{ ============================================================ }

Procedure EmitRuntimeIdent;
Begin
  BinDefineLabel('_SNRT_ident');
  BinPrologue;
  BinPushMemBpPos(12);
  BinPushMemBpPos(8);
  BinCallLabel('_SNRT_str_eq');
  BinAddEspImm8(8);
  BinEpilogue;
  BinRet;
End;

Procedure EmitRuntimeDiffer;
Begin
  BinDefineLabel('_SNRT_differ');
  BinPrologue;
  BinPushMemBpPos(12);
  BinPushMemBpPos(8);
  BinCallLabel('_SNRT_str_eq');
  BinAddEspImm8(8);
  BinTestEaxEax;
  BinJccLabel(CC_Z, '_SNRT_differ_true');
  BinXorRegReg(REG_EAX);
  BinJmpLabel('_SNRT_differ_done');
  BinDefineLabel('_SNRT_differ_true');
  BinMovRegImm32(REG_EAX, 1);
  BinDefineLabel('_SNRT_differ_done');
  BinEpilogue;
  BinRet;
End;

Procedure EmitRuntimeSize;
Begin
  BinDefineLabel('_SNRT_size');
  BinPrologue;
  BinPushMemBpPos(8);
  BinCallLabel('_SNRT_str_len');
  BinAddEspImm8(4);
  BinPushReg(REG_EAX);
  BinCallLabel('_SNRT_int_to_str');
  BinAddEspImm8(4);
  BinEpilogue;
  BinRet;
End;

Procedure EmitRuntimeStringPredicates;
Begin
  BinCurSec := BIN_SEC_TEXT;
  EmitRuntimeIdent;
  EmitRuntimeDiffer;
  EmitRuntimeSize;
End;

{ ============================================================ }
{ TODO 08 - CONSTRUCTION SECTION .idata (IAT)                 }
{ ============================================================ }

Procedure BinBuildIData(IDataRVA: LongInt);
Var
  N, I, K         : Integer;
  OldSec           : Integer;
  OrigThunksStart,
  IATStart,
  NamesStart,
  DllNameStart     : LongInt;
  HintOff          : Array[0..MAX_IMPORTS-1] Of LongInt;
  P                : LongInt;
  S                : String;
Begin
  N := ImportCount;
  If N = 0 Then Exit;
  OldSec := BinCurSec;
  BinCurSec    := BIN_SEC_IDATA;
  BinIDataSize := 0;

  { Disposition :
    [0..39]            : 1 descriptor + 1 null = 40 octets
    [40..]             : OriginalFirstThunk (N+1 dwords)
    [40+(N+1)*4..]     : FirstThunk / IAT   (N+1 dwords)
    [40+(N+1)*8..]     : hint/name entries  }
  OrigThunksStart := 40;
  IATStart        := 40 + LongInt(N+1)*4;
  NamesStart      := 40 + LongInt(N+1)*8;

  { Calcul des offsets hint/name }
  P := NamesStart;
  For I := 0 To N-1 Do Begin
    HintOff[I] := P;
    Inc(P, 2 + Length(ImportTable[I].FuncName) + 1);
    If (P Mod 2) <> 0 Then Inc(P);
  End;
  DllNameStart := P;

  { IMAGE_IMPORT_DESCRIPTOR pour la DLL importee (20 octets) }
  BinEmit32(IDataRVA + OrigThunksStart); { OriginalFirstThunk (RVA) }
  BinEmit32(0);                          { TimeDateStamp }
  BinEmit32(0);                          { ForwarderChain }
  BinEmit32(IDataRVA + DllNameStart);    { Name (RVA) }
  BinEmit32(IDataRVA + IATStart);        { FirstThunk / IAT (RVA) }
  { Null descriptor }
  BinEmit32(0); BinEmit32(0); BinEmit32(0); BinEmit32(0); BinEmit32(0);

  { OriginalFirstThunk : RVAs vers hint/name }
  For I := 0 To N-1 Do BinEmit32(IDataRVA + HintOff[I]);
  BinEmit32(0);

  { IAT (FirstThunk) : idem initialement, patche par le loader }
  For I := 0 To N-1 Do Begin
    BinDefineLabel(ImportTable[I].LabelNm);
    ImportTable[I].IATOff := BinIDataSize;
    BinEmit32(IDataRVA + HintOff[I]);
  End;
  BinEmit32(0);

  { IMAGE_IMPORT_BY_NAME : hint(2) + nom + \0 (aligne sur WORD) }
  For I := 0 To N-1 Do Begin
    BinEmit8(0); BinEmit8(0);
    S := ImportTable[I].FuncName;
    For K := 1 To Length(S) Do BinEmit8(Ord(S[K]));
    BinEmit8(0);
    If (BinIDataSize Mod 2) <> 0 Then BinEmit8(0);
  End;

  { Nom de la DLL }
  S := ImportTable[0].DllName;
  For K := 1 To Length(S) Do BinEmit8(Ord(S[K]));
  BinEmit8(0);

  BinCurSec := OldSec;
End;

{ ============================================================ }
{ TODO 08 - RESOLUTION DES FIXUPS                             }
{ ============================================================ }

Procedure BinResolveFixups(TextRVA, RDataRVA, DataRVA, IDataRVA: LongInt);
Var I, LI: Integer; TargetRVA, FixupRVA, Value: LongInt;

  Procedure Patch4(Sec: Integer; Off, V: LongInt);
  Begin
    Case Sec Of
      BIN_SEC_TEXT:  Begin BinCode [Off]:=Byte(V); BinCode [Off+1]:=Byte(V Shr 8); BinCode [Off+2]:=Byte(V Shr 16); BinCode [Off+3]:=Byte(V Shr 24); End;
      BIN_SEC_RDATA: Begin BinRData[Off]:=Byte(V); BinRData[Off+1]:=Byte(V Shr 8); BinRData[Off+2]:=Byte(V Shr 16); BinRData[Off+3]:=Byte(V Shr 24); End;
      BIN_SEC_DATA:  Begin BinData [Off]:=Byte(V); BinData [Off+1]:=Byte(V Shr 8); BinData [Off+2]:=Byte(V Shr 16); BinData [Off+3]:=Byte(V Shr 24); End;
      BIN_SEC_IDATA: Begin BinIData[Off]:=Byte(V); BinIData[Off+1]:=Byte(V Shr 8); BinIData[Off+2]:=Byte(V Shr 16); BinIData[Off+3]:=Byte(V Shr 24); End;
    End;
  End;

  Function SecRVA(Sec: Integer): LongInt;
  Begin
    Case Sec Of
      BIN_SEC_TEXT:  SecRVA := TextRVA;
      BIN_SEC_RDATA: SecRVA := RDataRVA;
      BIN_SEC_DATA:  SecRVA := DataRVA;
      BIN_SEC_IDATA: SecRVA := IDataRVA;
      Else SecRVA := 0;
    End;
  End;

Begin
  For I := 0 To FixupCount - 1 Do Begin
    LI := BinFindLabel(FixupTable[I].Name);
    If LI < 0 Then Begin CompileError('label non resolu : ' + FixupTable[I].Name); Continue; End;
    TargetRVA := SecRVA(LabelTable[LI].Section) + LabelTable[LI].Offset;
    If FixupTable[I].Kind = BIN_FIX_REL32 Then Begin
      FixupRVA := SecRVA(FixupTable[I].Section) + FixupTable[I].Offset;
      Value    := (IMAGE_BASE + TargetRVA) - (IMAGE_BASE + FixupRVA + 4);
    End Else
      Value := IMAGE_BASE + TargetRVA;
    Patch4(FixupTable[I].Section, FixupTable[I].Offset, Value);
  End;
End;

{ ============================================================ }
{ TODO 08 - WritePE : produit le fichier .EXE PE32            }
{ ============================================================ }

Procedure WritePE(Const FileName: String);
Const N_SECTIONS = 4;
Var
  OutF     : File;
  TextRVA, RDataRVA, DataRVA, IDataRVA   : LongInt;
  TextFOff, RDataFOff, DataFOff, IDataFOff: LongInt;
  TextRaw, RDataRaw, DataRaw, IDataRaw    : LongInt;
  RDataVS, DataVS                         : LongInt;
  EntryRVA, ImageSize, FSize              : LongInt;
  LI, I                                   : Integer;
  PadBuf                                   : Byte;

  Function AlignUp(V, A: LongInt): LongInt;
  Begin
    If (V Mod A) = 0 Then AlignUp := V Else AlignUp := V + A - (V Mod A);
  End;

  Procedure W1(B: Byte);
  Var Tmp: Byte; Begin Tmp := B; BlockWrite(OutF, Tmp, 1); End;

  Procedure W2(V: Word);
  Var A: Array[0..1] Of Byte;
  Begin A[0]:=Byte(V); A[1]:=Byte(V Shr 8); BlockWrite(OutF, A, 2); End;

  Procedure W4(V: LongInt);
  Var A: Array[0..3] Of Byte;
  Begin A[0]:=Byte(V); A[1]:=Byte(V Shr 8); A[2]:=Byte(V Shr 16); A[3]:=Byte(V Shr 24); BlockWrite(OutF, A, 4); End;

  Procedure Pad(N: LongInt);
  Var B: Byte; J: LongInt;
  Begin B := 0; For J := 1 To N Do BlockWrite(OutF, B, 1); End;

  Procedure PadTo(Target: LongInt);
  Var B: Byte; Cur: LongInt;
  Begin B := 0; Cur := FilePos(OutF); While Cur < Target Do Begin BlockWrite(OutF, B, 1); Inc(Cur); End; End;

  Procedure SecHdr(Const Name8: String; VS, VA, RS, RO: LongInt; Chars: LongInt);
  Var K: Integer;
  Begin
    For K := 1 To 8 Do If K <= Length(Name8) Then W1(Ord(Name8[K])) Else W1(0);
    W4(VS); W4(VA); W4(RS); W4(RO);
    W4(0); W4(0); W2(0); W2(0);
    W4(Chars);
  End;

Begin
  { 1. Calcul des tailles et RVAs }
  TextRaw  := AlignUp(BinCodeSize,  FILE_ALIGN); If BinCodeSize  = 0 Then TextRaw  := FILE_ALIGN;
  RDataRaw := AlignUp(BinRDataSize, FILE_ALIGN); If BinRDataSize = 0 Then RDataRaw := FILE_ALIGN;
  DataRaw  := AlignUp(BinDataSize,  FILE_ALIGN); If BinDataSize  = 0 Then DataRaw  := FILE_ALIGN;
  RDataVS  := BinRDataSize; If RDataVS = 0 Then RDataVS := 1;
  DataVS   := BinDataSize;  If DataVS  = 0 Then DataVS  := 1;

  TextRVA  := $1000;
  RDataRVA := TextRVA  + AlignUp(BinCodeSize,  SEC_ALIGN); If BinCodeSize  = 0 Then RDataRVA := TextRVA  + SEC_ALIGN;
  DataRVA  := RDataRVA + AlignUp(BinRDataSize, SEC_ALIGN); If BinRDataSize = 0 Then DataRVA  := RDataRVA + SEC_ALIGN;
  IDataRVA := DataRVA  + AlignUp(BinDataSize,  SEC_ALIGN); If BinDataSize  = 0 Then IDataRVA := DataRVA  + SEC_ALIGN;

  { 2. Construire la section .idata (definit les labels __imp__xxx) }
  BinBuildIData(IDataRVA);
  IDataRaw := AlignUp(BinIDataSize, FILE_ALIGN); If BinIDataSize = 0 Then IDataRaw := 0;

  { 3. Resoudre tous les fixups }
  BinResolveFixups(TextRVA, RDataRVA, DataRVA, IDataRVA);

  { 4. Entry point }
  LI := BinFindLabel('_SNSTART');
  If LI >= 0 Then EntryRVA := TextRVA + LabelTable[LI].Offset
  Else Begin CompileError('_SNSTART non defini'); Exit; End;

  { 5. Taille image }
  ImageSize := IDataRVA + AlignUp(BinIDataSize, SEC_ALIGN);
  If ImageSize <= IDataRVA Then ImageSize := IDataRVA + SEC_ALIGN;

  { 6. Offsets fichier }
  TextFOff  := HEADERS_SIZE;
  RDataFOff := TextFOff  + TextRaw;
  DataFOff  := RDataFOff + RDataRaw;
  IDataFOff := DataFOff  + DataRaw;
  FSize     := IDataFOff + IDataRaw;

  { 7. Ouvrir le fichier de sortie }
  Assign(OutF, FileName);
  {$I-} Rewrite(OutF, 1); {$I+}
  If IOResult <> 0 Then Begin CompileError('impossible de creer : ' + FileName); Exit; End;

  { --- DOS Header (64 octets) --- }
  W2($5A4D);
  W2($0090); W2($0003); W2($0000); W2($0004);
  W2($0000); W2($FFFF); W2($0000); W2($00B8);
  W2($0000); W2($0000); W2($0000); W2($0040);
  W2($0000);
  W4(0); W4(0);         { e_res }
  W2(0); W2(0);         { e_oemid e_oeminfo }
  W4(0); W4(0); W4(0); W4(0); W4(0); { e_res2 }
  W4($00000040);        { e_lfanew }

  { --- PE signature --- }
  W1($50); W1($45); W1(0); W1(0);

  { --- IMAGE_FILE_HEADER --- }
  W2($014C);        { i386 }
  W2(N_SECTIONS);
  W4(0); W4(0); W4(0);
  W2($00E0);        { SizeOfOptionalHeader }
  W2($030F);        { RELOCS_STRIPPED | EXEC | stripped | 32BIT }

  { --- IMAGE_OPTIONAL_HEADER32 (224 octets) --- }
  W2($010B); W1(1); W1(0);
  W4(TextRaw);
  W4(RDataRaw + DataRaw + IDataRaw);
  W4(BinBssSize);
  W4(EntryRVA);
  W4(TextRVA); W4(DataRVA);
  W4(IMAGE_BASE);
  W4(SEC_ALIGN); W4(FILE_ALIGN);
  W2(4); W2(0);  { OS version }
  W2(0); W2(0);  { Image version }
  W2(4); W2(0);  { Subsystem version }
  W4(0);
  W4(ImageSize);
  W4(HEADERS_SIZE);
  W4(0);          { CheckSum }
  W2(3); W2(0);   { CUI, no DLL flags }
  W4($00100000); W4($00001000); { Stack reserve/commit }
  W4($00100000); W4($00001000); { Heap  reserve/commit }
  W4(0); W4(16);  { LoaderFlags, NumDataDir }
  W4(0); W4(0);   { export }
  W4(IDataRVA); W4(BinIDataSize); { import }
  For I := 2 To 15 Do Begin W4(0); W4(0); End;

  { --- Section headers --- }
  SecHdr('.text',  BinCodeSize,  TextRVA,  TextRaw,  TextFOff,  $60000020);
  SecHdr('.rdata', RDataVS, RDataRVA, RDataRaw, RDataFOff, $40000040);
  SecHdr('.data',  DataVS,  DataRVA,  DataRaw,  DataFOff,  LongInt($C0000040));
  SecHdr('.idata', BinIDataSize, IDataRVA, IDataRaw, IDataFOff, LongInt($C0000040));

  PadTo(HEADERS_SIZE);

  { --- Contenu des sections --- }
  If BinCodeSize  > 0 Then BlockWrite(OutF, BinCode[0],  BinCodeSize);  Pad(TextRaw  - BinCodeSize);
  If BinRDataSize > 0 Then BlockWrite(OutF, BinRData[0], BinRDataSize); Pad(RDataRaw - BinRDataSize);
  If BinDataSize  > 0 Then BlockWrite(OutF, BinData[0],  BinDataSize);  Pad(DataRaw  - BinDataSize);
  If BinIDataSize > 0 Then BlockWrite(OutF, BinIData[0], BinIDataSize); Pad(IDataRaw - BinIDataSize);

  Close(OutF);
  WriteLn('SNOBCW32: ', FileName, ' ecrit (', FSize, ' octets)');
End;

Procedure WriteCOFF(Const FileName: String);
Const
  COFF_SECTIONS = 3;
  COFF_SYM_UNDEF = 0;
  COFF_SYM_TEXT  = 1;
  COFF_SYM_RDATA = 2;
  COFF_SYM_DATA  = 3;
  COFF_REL_DIR32 = $0006;
  COFF_REL_REL32 = $0014;
Var
  OutF          : File;
  TextPtr,
  RDataPtr,
  DataPtr,
  TextRelPtr,
  RDataRelPtr,
  DataRelPtr,
  SymPtr        : LongInt;
  TextRelCnt,
  RDataRelCnt,
  DataRelCnt    : Integer;
  LabelSymIdx   : Array[0..MAX_LABELS-1] Of LongInt;
  ImportSymIdx  : Array[0..MAX_IMPORTS-1] Of LongInt;
  StrTab        : Array[0..65535] Of Byte;
  StrSize       : LongInt;
  NumSyms       : LongInt;
  I             : Integer;

  Procedure W1(B: Byte);
  Var Tmp: Byte;
  Begin Tmp := B; BlockWrite(OutF, Tmp, 1); End;

  Procedure W2(V: Word);
  Var A: Array[0..1] Of Byte;
  Begin
    A[0] := Byte(V);
    A[1] := Byte(V Shr 8);
    BlockWrite(OutF, A, 2);
  End;

  Procedure W4(V: LongInt);
  Var A: Array[0..3] Of Byte;
  Begin
    A[0] := Byte(V);
    A[1] := Byte(V Shr 8);
    A[2] := Byte(V Shr 16);
    A[3] := Byte(V Shr 24);
    BlockWrite(OutF, A, 4);
  End;

  Function SecIndex(Sec: Integer): Integer;
  Begin
    Case Sec Of
      BIN_SEC_TEXT:  SecIndex := COFF_SYM_TEXT;
      BIN_SEC_RDATA: SecIndex := COFF_SYM_RDATA;
      BIN_SEC_DATA:  SecIndex := COFF_SYM_DATA;
      Else SecIndex := COFF_SYM_UNDEF;
    End;
  End;

  Function SectionSize(Sec: Integer): LongInt;
  Begin
    Case Sec Of
      BIN_SEC_TEXT:  SectionSize := BinCodeSize;
      BIN_SEC_RDATA: SectionSize := BinRDataSize;
      BIN_SEC_DATA:  SectionSize := BinDataSize;
      Else SectionSize := 0;
    End;
  End;

  Function AddString(Const S: String): LongInt;
  Var K: Integer;
  Begin
    AddString := StrSize;
    If StrSize + Length(S) + 1 > SizeOf(StrTab) Then Begin
      CompileError('table des chaines COFF pleine');
      Exit;
    End;
    For K := 1 To Length(S) Do Begin
      StrTab[StrSize] := Ord(S[K]);
      Inc(StrSize);
    End;
    StrTab[StrSize] := 0;
    Inc(StrSize);
  End;

  Procedure WName(Const S: String);
  Var K: Integer; Off: LongInt;
  Begin
    If Length(S) <= 8 Then Begin
      For K := 1 To 8 Do
        If K <= Length(S) Then W1(Ord(S[K])) Else W1(0);
    End Else Begin
      Off := AddString(S);
      W4(0);
      W4(Off);
    End;
  End;

  Procedure WSectionHeader(Const Name8: String; Size, RawPtr, RelPtr: LongInt;
                           RelCnt: Integer; Chars: LongInt);
  Begin
    WName(Name8);
    W4(0);                  { VirtualSize }
    W4(0);                  { VirtualAddress }
    W4(Size);
    If Size > 0 Then W4(RawPtr) Else W4(0);
    If RelCnt > 0 Then W4(RelPtr) Else W4(0);
    W4(0);                  { PointerToLinenumbers }
    W2(Word(RelCnt));
    W2(0);                  { NumberOfLinenumbers }
    W4(Chars);
  End;

  Procedure WSymbol(Const Name: String; Value: LongInt; SecNum: Integer;
                    Typ: Word; Storage: Byte);
  Begin
    WName(Name);
    W4(Value);
    W2(Word(SecNum));
    W2(Typ);
    W1(Storage);
    W1(0);                  { NumberOfAuxSymbols }
  End;

  Function FindImportSymbol(Const Name: String): LongInt;
  Var K: Integer;
  Begin
    FindImportSymbol := -1;
    For K := 0 To ImportCount - 1 Do
      If ImportTable[K].LabelNm = Name Then Begin
        FindImportSymbol := ImportSymIdx[K];
        Exit;
      End;
  End;

  Function FindLabelSymbol(Const Name: String): LongInt;
  Var K: Integer;
  Begin
    FindLabelSymbol := -1;
    For K := 0 To LabelCount - 1 Do
      If LabelTable[K].Name = Name Then Begin
        FindLabelSymbol := LabelSymIdx[K];
        Exit;
      End;
  End;

  Function FixupSymbolIndex(Const Name: String): LongInt;
  Var R: LongInt;
  Begin
    R := FindLabelSymbol(Name);
    If R < 0 Then
      R := FindImportSymbol(Name);
    If R < 0 Then
      CompileError('symbole COFF non resolu : ' + Name);
    FixupSymbolIndex := R;
  End;

  Function FixupRelType(Kind: Integer): Word;
  Begin
    If Kind = BIN_FIX_REL32 Then FixupRelType := COFF_REL_REL32
    Else FixupRelType := COFF_REL_DIR32;
  End;

  Procedure CountRelocs;
  Var K: Integer;
  Begin
    TextRelCnt := 0;
    RDataRelCnt := 0;
    DataRelCnt := 0;
    For K := 0 To FixupCount - 1 Do
      Case FixupTable[K].Section Of
        BIN_SEC_TEXT:  Inc(TextRelCnt);
        BIN_SEC_RDATA: Inc(RDataRelCnt);
        BIN_SEC_DATA:  Inc(DataRelCnt);
      End;
  End;

  Procedure WriteRelocs(Sec: Integer);
  Var K: Integer; SymIdx: LongInt;
  Begin
    For K := 0 To FixupCount - 1 Do
      If FixupTable[K].Section = Sec Then Begin
        SymIdx := FixupSymbolIndex(FixupTable[K].Name);
        W4(FixupTable[K].Offset);
        W4(SymIdx);
        W2(FixupRelType(FixupTable[K].Kind));
      End;
  End;

  Function LabelStorageClass(Const Name: String): Byte;
  Begin
    If Name = '_SNSTART' Then LabelStorageClass := 2 { IMAGE_SYM_CLASS_EXTERNAL }
    Else LabelStorageClass := 3;                     { IMAGE_SYM_CLASS_STATIC }
  End;

Begin
  CountRelocs;

  TextPtr := 20 + COFF_SECTIONS * 40;
  RDataPtr := TextPtr + BinCodeSize;
  DataPtr := RDataPtr + BinRDataSize;
  TextRelPtr := DataPtr + BinDataSize;
  RDataRelPtr := TextRelPtr + LongInt(TextRelCnt) * 10;
  DataRelPtr := RDataRelPtr + LongInt(RDataRelCnt) * 10;
  SymPtr := DataRelPtr + LongInt(DataRelCnt) * 10;

  NumSyms := LabelCount + ImportCount;
  For I := 0 To LabelCount - 1 Do
    LabelSymIdx[I] := I;
  For I := 0 To ImportCount - 1 Do
    ImportSymIdx[I] := LabelCount + I;

  StrSize := 4;

  Assign(OutF, FileName);
  {$I-} Rewrite(OutF, 1); {$I+}
  If IOResult <> 0 Then Begin CompileError('impossible de creer : ' + FileName); Exit; End;

  { IMAGE_FILE_HEADER }
  W2($014C);               { IMAGE_FILE_MACHINE_I386 }
  W2(COFF_SECTIONS);
  W4(0);                   { TimeDateStamp }
  W4(SymPtr);
  W4(NumSyms);
  W2(0);                   { SizeOfOptionalHeader }
  W2(0);                   { Characteristics }

  { IMAGE_SECTION_HEADER x3 }
  WSectionHeader('.text',  BinCodeSize,  TextPtr,  TextRelPtr,  TextRelCnt,  $60500020);
  WSectionHeader('.rdata', BinRDataSize, RDataPtr, RDataRelPtr, RDataRelCnt, $40500040);
  WSectionHeader('.data',  BinDataSize,  DataPtr,  DataRelPtr,  DataRelCnt,  LongInt($C0500040));

  If BinCodeSize  > 0 Then BlockWrite(OutF, BinCode[0],  BinCodeSize);
  If BinRDataSize > 0 Then BlockWrite(OutF, BinRData[0], BinRDataSize);
  If BinDataSize  > 0 Then BlockWrite(OutF, BinData[0],  BinDataSize);

  WriteRelocs(BIN_SEC_TEXT);
  WriteRelocs(BIN_SEC_RDATA);
  WriteRelocs(BIN_SEC_DATA);
  If HasError Then Begin Close(OutF); Exit; End;

  For I := 0 To LabelCount - 1 Do
    WSymbol(LabelTable[I].Name, LabelTable[I].Offset,
            SecIndex(LabelTable[I].Section), 0,
            LabelStorageClass(LabelTable[I].Name));
  For I := 0 To ImportCount - 1 Do
    WSymbol(ImportTable[I].LabelNm, 0, COFF_SYM_UNDEF, 0,
            2);             { IMAGE_SYM_CLASS_EXTERNAL }

  W4(StrSize);
  If StrSize > 4 Then
    BlockWrite(OutF, StrTab[4], StrSize - 4);

  Close(OutF);
  WriteLn('SNOBCW32: ', FileName, ' ecrit (COFF OBJ)');
End;

Procedure WriteASM(Const FileName: String);
Var
  OutF : Text;
  I    : Integer;

  Function HexByte(B: Byte): String;
  Const H = '0123456789ABCDEF';
  Begin
    HexByte := H[(B Shr 4) + 1] + H[(B And $0F) + 1] + 'h';
  End;

  Function SectionSize(Sec: Integer): LongInt;
  Begin
    Case Sec Of
      BIN_SEC_TEXT:  SectionSize := BinCodeSize;
      BIN_SEC_RDATA: SectionSize := BinRDataSize;
      BIN_SEC_DATA:  SectionSize := BinDataSize;
      Else SectionSize := 0;
    End;
  End;

  Function SectionByte(Sec: Integer; Off: LongInt): Byte;
  Begin
    Case Sec Of
      BIN_SEC_TEXT:  SectionByte := BinCode[Off];
      BIN_SEC_RDATA: SectionByte := BinRData[Off];
      BIN_SEC_DATA:  SectionByte := BinData[Off];
      Else SectionByte := 0;
    End;
  End;

  Procedure EmitLabelsAt(Sec: Integer; Off: LongInt);
  Var K: Integer;
  Begin
    For K := 0 To LabelCount - 1 Do
      If (LabelTable[K].Section = Sec) And (LabelTable[K].Offset = Off) Then Begin
        If LabelTable[K].Name = '_SNSTART' Then
          WriteLn(OutF, 'PUBLIC ', LabelTable[K].Name);
        WriteLn(OutF, LabelTable[K].Name, ':');
      End;
  End;

  Function FixupAt(Sec: Integer; Off: LongInt): Integer;
  Var K: Integer;
  Begin
    FixupAt := -1;
    For K := 0 To FixupCount - 1 Do
      If (FixupTable[K].Section = Sec) And (FixupTable[K].Offset = Off) Then Begin
        FixupAt := K;
        Exit;
      End;
  End;

  Function HasLabelAt(Sec: Integer; Off: LongInt): Boolean;
  Var K: Integer;
  Begin
    HasLabelAt := False;
    For K := 0 To LabelCount - 1 Do
      If (LabelTable[K].Section = Sec) And (LabelTable[K].Offset = Off) Then Begin
        HasLabelAt := True;
        Exit;
      End;
  End;

  Procedure EmitDbRun(Sec: Integer; Var Off: LongInt);
  Var
    Cnt    : Integer;
    Line   : String;
    Size   : LongInt;
  Begin
    Size := SectionSize(Sec);
    Cnt := 0;
    Line := '  DB ';
    While (Off < Size) And (Cnt < 12) And
          (FixupAt(Sec, Off) < 0) And
          ((Cnt = 0) Or Not HasLabelAt(Sec, Off)) Do Begin
      If Cnt > 0 Then Line := Line + ',';
      Line := Line + HexByte(SectionByte(Sec, Off));
      Inc(Off);
      Inc(Cnt);
    End;
    If Cnt > 0 Then WriteLn(OutF, Line);
  End;

  Procedure EmitSectionBytes(Sec: Integer);
  Var
    Off  : LongInt;
    FI   : Integer;
    Expr : String;
  Begin
    Off := 0;
    While Off < SectionSize(Sec) Do Begin
      EmitLabelsAt(Sec, Off);
      FI := FixupAt(Sec, Off);
      If FI >= 0 Then Begin
        Expr := FixupTable[FI].Name;
        If FixupTable[FI].Kind = BIN_FIX_REL32 Then
          Expr := Expr + ' - ($ + 4)';
        WriteLn(OutF, '  DD ', Expr);
        Inc(Off, 4);
      End Else
        EmitDbRun(Sec, Off);
    End;
    EmitLabelsAt(Sec, Off);
  End;

Begin
  Assign(OutF, FileName);
  {$I-} Rewrite(OutF); {$I+}
  If IOResult <> 0 Then Begin CompileError('impossible de creer : ' + FileName); Exit; End;

  WriteLn(OutF, '; Genere par SNOBCW32 v', SNB_VERSION);
  WriteLn(OutF, '.386');
  WriteLn(OutF, '.MODEL FLAT, STDCALL');
  WriteLn(OutF, 'OPTION CASEMAP:NONE');
  WriteLn(OutF);

  For I := 0 To ImportCount - 1 Do
    WriteLn(OutF, 'EXTERN ', ImportTable[I].LabelNm, ':DWORD ; ',
            ImportTable[I].DllName, '!', ImportTable[I].FuncName);
  WriteLn(OutF);

  WriteLn(OutF, '.CONST');
  EmitSectionBytes(BIN_SEC_RDATA);
  WriteLn(OutF);

  WriteLn(OutF, '.DATA');
  EmitSectionBytes(BIN_SEC_DATA);
  WriteLn(OutF);

  WriteLn(OutF, '.CODE');
  EmitSectionBytes(BIN_SEC_TEXT);
  WriteLn(OutF, 'END _SNSTART');

  Close(OutF);
  WriteLn('SNOBCW32: ', FileName, ' ecrit (ASM MASM/JWASM)');
End;

{ ============================================================ }
{ TODO 25 - EXTENSIONS FUTURES                                 }
{ ============================================================ }

{ --- Stub codegen : arithmetique directe (+, -, *, /) --------- }
{ Protocole cdecl attendu (a implementer dans CodegenProgram) :
    NK_ARITH, Text='+' : PUSH Right -> PUSH Left -> CALL _SNRT_str_add  -> ADD ESP,8
    NK_ARITH, Text='-' : PUSH Right -> PUSH Left -> CALL _SNRT_str_sub  -> ADD ESP,8
    NK_ARITH, Text='*' : PUSH Right -> PUSH Left -> CALL _SNRT_str_mul  -> ADD ESP,8
    NK_ARITH, Text='/' : PUSH Right -> PUSH Left -> CALL _SNRT_str_div  -> ADD ESP,8
  Chaque _SNRT_str_xxx(s1,s2) : str_to_int x2, operation, int_to_str -> EAX
  Noms des imports runtime a enregistrer via BinAddImport('','_SNRT_str_add') etc. }
Procedure BinCodegenArith(N: Integer);
Begin
  CompileError('arithmetique directe non implementee (TODO 25)');
End;

{ --- Stub codegen : operateurs de pattern avances ------------- }
{ ARB    : _SNRT_pat_arb(subj) cdecl -> EAX=1 (match n importe quoi)
  REM    : _SNRT_pat_rem(subj) cdecl -> EAX=1 (reste de la chaine)
  SPAN   : _SNRT_pat_span(subj,cs) cdecl -> EAX=1/0 (1+ chars de l ensemble)
  BREAK  : _SNRT_pat_break(subj,cs) cdecl -> EAX=1/0 (jusqu a un char cs)
  ANY    : _SNRT_pat_any(subj,cs) cdecl -> EAX=1/0 (exactement 1 char de cs)
  NOTANY : _SNRT_pat_notany(subj,cs) cdecl -> EAX=1/0 (1 char hors de cs)
  L argument charset est le Left child du NK_PATOP (ou absent pour ARB/REM). }
Procedure BinCodegenPatOp(N: Integer);
Begin
  CompileError('operateurs de pattern avances non implementes (TODO 25)');
End;

{ --- Stub codegen : tableau SNOBOL (TABLE) --------------------- }
{ NK_TABLECRE : CALL _SNRT_table_new -> EAX = handle table heap
  NK_TABLEGET : PUSH key -> PUSH handle -> CALL _SNRT_table_get -> EAX
  NK_TABLESET : PUSH val -> PUSH key -> PUSH handle -> CALL _SNRT_table_set
  _SNRT_table_new() -> EAX : alloue un tableau associatif (chaine->chaine)
  _SNRT_table_get(handle,key) cdecl -> EAX = ptr valeur (ou _SN_EMPTY)
  _SNRT_table_set(handle,key,val) cdecl }
Procedure BinCodegenTable(N: Integer);
Begin
  CompileError('TABLE non implemente (TODO 25)');
End;

{ --- Stub codegen : &TRIM ------------------------------------- }
{ A integrer dans la generation de &OUTPUT = expr (TODO 11) :
    Apres BinCodegenExpr(expr) -> EAX = ptr chaine :
      Si SysTrim : PUSH EAX ; CALL _SNRT_str_rtrim ; ADD ESP,4
    _SNRT_str_rtrim(s) cdecl -> EAX = nouveau ptr sans espaces trailing }
Procedure BinCodegenTrimOutput;
Begin
  { stub - activer SysTrim = True via &TRIM = '1' dans le source }
End;

{ --- Stub codegen : &ANCHOR ----------------------------------- }
{ A integrer dans la generation de NK_PATTERN (TODO 12/18) :
    Si SysAnchor : utiliser _SNRT_pat_match_anchored au lieu de _SNRT_pat_match
    _SNRT_pat_match_anchored(subj,pat) cdecl -> EAX=1 si match en pos 0 seul }
Procedure BinCodegenAnchorPattern;
Begin
  { stub - activer SysAnchor = True via &ANCHOR = '1' dans le source }
End;

{ --- Stub codegen : &STNO ------------------------------------- }
{ Variable globale en .data : _SN_STNO DD 0
  Incrementee par CodegenProgram avant chaque statement.
  Lecture : MOV EAX,[_SN_STNO] ; CALL _SNRT_int_to_str -> EAX = ptr chaine
  Emission dans .data : BinDefineLabel('_SN_STNO') ; BinEmit32(0) }
Procedure BinCodegenStno;
Begin
  { stub - lecture de &STNO -> resultat EAX = ptr vers chaine du numero }
End;

{ ============================================================ }
{ TODO 01 - POINT D ENTREE PRINCIPAL                           }
{ ============================================================ }
Var
  I   : Integer;
  Arg : String;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('SNOBCW32 - Cette commande permet de lancer le compilateur SNOBOL4 ',
          'pour l''assembleur du microprocesseur 80386 pour le systeme ',
          'd''exploitation Windows 32 bits (PE Win32).');
  WriteLn;
  WriteLn('Syntaxe : SNOBCW32 source[.sbl] [-obj] [-asm]');
  WriteLn('  (defaut) -> source.exe   PE32 autonome');
  WriteLn('  -obj     -> source.obj   COFF relocatable');
  WriteLn('  -asm     -> source.asm   texte MASM/JWasm');
  Halt;
 End;
  WriteLn('SNOBCW32 v', SNB_VERSION, ' (', SNB_YEAR,
          ') - Compilateur SNOBOL4 -> 80386 PE Win32');

  SrcFile := '';
  OutFile := '';
  OutMode := MODE_EXE;

  { Parsing des arguments }
  I := 1;
  While I <= ParamCount Do Begin
    Arg := ParamStr(I);
    If Arg = '-obj' Then
      OutMode := MODE_OBJ
    Else If Arg = '-asm' Then
      OutMode := MODE_ASM
    Else If (Length(Arg) > 0) And (Arg[1] <> '-') Then Begin
      If SrcFile = '' Then
        SrcFile := Arg
      Else Begin
        WriteLn('SNOBCW32: argument superflu : ', Arg);
        Halt(1);
      End;
    End Else Begin
      WriteLn('SNOBCW32: option inconnue : ', Arg);
      Halt(1);
    End;
    Inc(I);
  End;

  { Source obligatoire }
  If SrcFile = '' Then Begin
    WriteLn('Syntaxe : SNOBCW32 source[.sbl] [-obj] [-asm]');
    WriteLn('  (defaut) -> source.exe   PE32 autonome');
    WriteLn('  -obj     -> source.obj   COFF relocatable');
    WriteLn('  -asm     -> source.asm   texte MASM/JWasm');
    Halt(1);
  End;

  { Ajouter .sbl si pas d extension }
  If FileExt(SrcFile) = '' Then SrcFile := SrcFile + '.sbl';

  { Verifier existence du source }
  If Not FileExists(SrcFile) Then Begin
    WriteLn('SNOBCW32: fichier source introuvable : ', SrcFile);
    Halt(1);
  End;

  { Deriver le nom de sortie }
  Case OutMode Of
    MODE_EXE : OutFile := ChangeExt(SrcFile, '.exe');
    MODE_OBJ : OutFile := ChangeExt(SrcFile, '.obj');
    MODE_ASM : OutFile := ChangeExt(SrcFile, '.asm');
  End;

  WriteLn('SNOBCW32: compilation de ', SrcFile);

  { Initialiser les tables }
  InitTables;
  LexInit;

  { Passe 1 : collecte des labels et DEFINE }
  CollectLabels;
  If HasError Then Halt(1);

  { Passe 2 : parsing + generation de code }
  ParseProgram;
  If HasError Then Halt(1);
  CodegenProgram;
  If HasError Then Halt(1);

  { Emission du fichier de sortie }
  Case OutMode Of
    MODE_EXE : WritePE(OutFile);
    MODE_OBJ : WriteCOFF(OutFile);
    MODE_ASM : WriteASM(OutFile);
  End;
  LexClose;
  If HasError Then Halt(1);

  WriteLn('SNOBCW32: ok');
END.
