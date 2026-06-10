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

{ ------------------------------------------------------------ }
{ Types                                                        }
{ ------------------------------------------------------------ }
Type
  { Entree de la table des symboles }
  TSym = Record
    Name    : String;
    Kind    : Integer;
    VarIdx  : Integer;      { index dans _SNV_TABLE (SK_VAR) }
    LblAddr : LongInt;      { adresse code compilee (SK_LABEL) }
    FuncLbl : String;       { label d entree (SK_FUNC) }
    ParamCnt: Integer;      { nb de parametres (SK_FUNC) }
    Params  : Array[0..7] Of String;
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
End;

Procedure CompileWarn(Const Msg: String);
Begin
  WriteLn('SNOBCW32: avertissement ligne ', CurLineNum, ': ', Msg);
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
  HasError     := False;
  For I := 0 To MAX_VARS-1 Do VarNames[I] := '';
End;

{ ============================================================ }
{ Corps des stubs Forward (remplaces dans les TODO suivants)   }
{ ============================================================ }
Procedure LexInit;   Begin End;
Procedure LexLine(Const S: String); Begin End;
Procedure LexNextToken; Begin End;

Procedure ParseProgram; Begin End;

Function FindSym(Const Name: String; Kind: Integer): Integer;
Begin FindSym := -1; End;

Function AddSym(Const Name: String; Kind: Integer): Integer;
Begin AddSym := -1; End;

Function GetOrAddVar(Const Name: String): Integer;
Begin GetOrAddVar := -1; End;

Procedure CollectLabels;  Begin End;
Procedure CodegenProgram; Begin End;

Procedure WritePE(Const FileName: String);
Begin WriteLn('SNOBCW32: WritePE non implemente'); End;

Procedure WriteCOFF(Const FileName: String);
Begin WriteLn('SNOBCW32: WriteCOFF non implemente'); End;

Procedure WriteASM(Const FileName: String);
Begin WriteLn('SNOBCW32: WriteASM non implemente'); End;

{ ============================================================ }
{ TODO 01 - POINT D ENTREE PRINCIPAL                           }
{ ============================================================ }
Var
  I   : Integer;
  Arg : String;
Begin
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
    WriteLn('SNOBCW32 - Cette commande permet de lancer le compilateur SNOBOL4 ',
          'pour l''assembleur du microprocesseur 80386 pour le systeme ',
          'd''exploitation Windows 32 bits (PE Win32).');
    WriteLn;  
    WriteLn('Usage : SNOBCW32 source[.sbl] [-obj] [-asm]');
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

  { Emission du fichier de sortie }
  Case OutMode Of
    MODE_EXE : WritePE(OutFile);
    MODE_OBJ : WriteCOFF(OutFile);
    MODE_ASM : WriteASM(OutFile);
  End;
  If HasError Then Halt(1);

  WriteLn('SNOBCW32: ok');
End.
