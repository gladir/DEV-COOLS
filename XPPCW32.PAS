{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026-07-03
  @version: 0.1
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur X++ (Axapta / Microsoft Dynamics AX) vers
                assembleur 80386 pour Windows 32 bits
  @output: Win32 PE .EXE par defaut, COFF i386 .OBJ sur demande (-obj),
           .ASM 80386 optionnel sur demande explicite (-asm)
  @license: MIT
}

Program XPPCW32;

{$R-}
{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}

{ TODO XPPCW32 - Compilateur X++ (Axapta) vers 80386/Win32

  DONE 01 - INFRASTRUCTURE, PIPELINE ET OPTIONS DE LIGNE DE COMMANDE
            Definir le pipeline complet : source .xpp -> lexer -> parser ->
            tables semantiques (classes/interfaces/tables) -> IR -> ASM
            80386 optionnel -> OBJ COFF i386 -> EXE PE32 par defaut.
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings,
              EmitExe, EmitObj, EmitAsm, StrictMode).
            ParseArgs : argv source.xpp [-o out] [-v] [-d] [-w] [-obj]
              [-asm] [-h].
            Par defaut : produire un .EXE PE Win32 ; -obj : produire
              uniquement un .OBJ COFF (pas d'.EXE) ; -asm : produire en
              plus un .ASM 80386 lisible (jamais emis sans le parametre).
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE.
            Detecter l'extension .xpp.

  DONE 02 - MODELE CIBLE WIN32 ET CONSTANTES PE/COFF
            Mode plat 32 bits, sections .text/.data/.bss, alignements,
            convention d'appel interne (registres/pile), prologues et
            epilogues 80386.
            Constantes PE/COFF : PE_DOS_MAGIC ($5A4D), PE_PE_SIG,
              PE_MACHINE_I386, PE_IMG_BASE ($00400000), PE_SEC_ALIGN
              (4096), PE_FILE_ALIGN (512), PE_SUBSYS_CUI.
            Limites : MAX_SYM, MAX_CLASS, MAX_METHOD, MAX_LOCAL,
              MAX_PARAM, MAX_LABEL, MAX_STR, MAX_ERRORS.
            Prefixes ASM : _XPP_ (variable globale), _XPPF_ (methode),
              _XPPC_ (classe/vtable), _XPPK_ (chaine litterale),
              _XPPRT_ (runtime), _XPPL_ (label), _XPPT_ (table).

  DONE 03 - LEXER X++ (TOKENISEUR)
            LexInit, LexClose, LexNextChar, LexPeekChar, LexNextToken.
            Identificateurs (lettres, chiffres, _), sensibles a la casse.
            Litteraux numeriques (entiers, reels, notation scientifique),
              chaines "..." avec echappements, caracteres, dates
              'jj/mm/aaaa'.
            Commentaires // (fin de ligne) et /* ... */ (bloc).
            Operateurs : + - * / div mod ++ -- += -= *= /= == != < > <=
              >= && || ! & | ^ ~ << >> = -> :: .. et ponctuation :
              accolades, parentheses, crochets, point-virgule, virgule,
              deux-points, point.

  DONE 04 - MOTS-CLES ET TYPES DE BASE X++
            IsKeyword : class interface extends implements public
              private protected static void new this super if else
              switch case default break continue while do for return
              try catch throw finally delegate container select
              while select insert update delete delete_from ttsBegin
              ttsCommit ttsAbort order by group by exists join.
            Types scalaires : int, real, str, boolean, date, guid,
              anytype, void, container, enum.

  DONE 05 - DECLARATIONS DE CLASSES ET D'INTERFACES (PARSER)
            class Nom [extends Parent] [implements Iface1, Iface2] suivi
            d'un bloc, interface Nom regroupant des signatures de
            methodes, champs typés, methodes public/private/protected/
            static, constructeur new(parametres).

  DONE 06 - TABLE DES SYMBOLES ET PORTEES
            Portee globale, classe, methode, bloc ; resolution des
            membres herites, detection des doublons et des membres non
            definis, verification de la compatibilite extends/implements.

  DONE 07 - TYPES COMPOSES : TABLEAUX, CONTAINERS, ENUMS
            int/str/... tab[N] (tableaux fixes 1-indexes), container
            (liste heterogene, operateur +=, con2Str, conLen, conPeek,
            conIns, conDel), enum (valeurs nommees accedees via ::,
            ex. CustVendorBlocked::No).

  DONE 08 - VARIABLES, CONSTANTES ET ALLOCATION
            Declaration de variables locales (offsets EBP) et de champs
            de classe (offsets d'instance), valeurs par defaut (0, "",
            false, date nulle), litteraux, evaluation constante simple.

  DONE 09 - EXPRESSIONS ET OPERATEURS
            Priorites X++ (assignation, logique, comparaison, bit,
            additif, multiplicatif, unaire, acces membre/indexation),
            evaluation en IR typee, promotion int<->real.

  DONE 10 - INSTRUCTIONS DE BASE ET IF/ELSE
            Bloc d'instructions, affectation, appel de methode,
            instruction vide (;), if/else if/else, evaluation
            paresseuse de && et ||.

  DONE 11 - SWITCH/CASE
            switch(expr) suivi d'un bloc avec case val: ... break;
            case v1: case v2: ... default: ..., enchainement explicite
            (fall-through) et verification des valeurs constantes de
            case.

  DONE 12 - BOUCLES WHILE, DO-WHILE, FOR
            while(cond) suivi d'un bloc, do ... while(cond); suivi d'un
            bloc, for(init; cond; incr) suivi d'un bloc, break,
            continue, boucles imbriquees.

  DONE 13 - METHODES ET PARAMETRES
            Declaration de methodes (public/private/static), parametres
            typés, valeur de retour, recursion, verification d'arite et
            de types a chaque appel.

  DONE 14 - HERITAGE (EXTENDS) ET POLYMORPHISME
            extends, super(...), redefinition de methode, resolution
            dynamique via une table de methodes virtuelles par classe,
            appel du constructeur parent.

  DONE 15 - INTERFACES (IMPLEMENTS)
            Declaration d'interface, implements multiple, verification
            que toutes les methodes de l'interface sont implementees,
            appel polymorphe via une variable typee interface.

  DONE 16 - GESTION DES EXCEPTIONS (TRY/CATCH/THROW)
            try suivi d'un bloc, catch (Exception::Xxx) suivi d'un bloc,
            catch generique suivi d'un bloc, throw error("msg"),
            Exception::Error/Warning/Internal, deroulement de pile
            (unwind) lors de la propagation.

  DONE 17 - DELEGATES ET GESTIONNAIRES D'EVENEMENTS
            delegate void Nom(params) suivi d'un bloc, appel
            this.Nom(...), attribut SubscribesTo(classStr(Classe),
            delegateStr(Classe, Nom)) sur une methode static, table de
            liaison delegate->abonnes generee au link-time, invocation
            de tous les abonnes.

  DONE 18 - MODELE DE TABLE (AOT SIMULE) ET METADONNEES
            Definition interne minimale des tables standard utilisees
            par les samples (CustTable, CustGroup : champs et cles),
            tableNum/fieldNum, representation memoire d'un buffer
            d'enregistrement (recordbuffer).

  DONE 19 - WHILE SELECT / SELECT ET REQUETES SIMPLES
            while select var [order by champ] [where condition] suivi
            d'un bloc, select [forUpdate] var where condition;,
            traduction en boucle d'iteration sur un stockage de table
            interne (tableau/fichier en memoire).

  DONE 20 - CRUD ET TRANSACTIONS (INSERT/UPDATE/DELETE/TTS)
            .insert()/.update()/.delete()/.clear(), delete_from ...
            where ..., ttsBegin/ttsCommit/ttsAbort avec pile de
            transactions imbricables et retour arriere en memoire.

  DONE 21 - QUERY, QUERYBUILDDATASOURCE, QUERYRUN
            new Query(), addDataSource(tableNum), addRange(fieldNum),
            .value(), new QueryRun(query), .next(), .get(tableNum),
            SysQuery::valueNotEmpty minimal.

  DONE 22 - COLLECTIONS RUNTIME : MAP ET LIST
            new Map(Types::X, Types::Y) / new List(Types::X),
            insert/addEnd, getEnumerator, MapEnumerator/ListEnumerator,
            moveNext/current/currentKey/currentValue, elements().

  DONE 23 - FONCTIONS RUNTIME NATIVES (STR/DATE/DIVERS)
            strFmt, strLen, strUpr, strLwr, subStr, strFind, strDel,
            strIns, strLTrim, strRTrim, con2Str, str2Date, today,
            mthOfYr, mthName, newGuid, guid2Str, info(), print/pause
            herites d'Axapta 2.x.

  DONE 24 - GENERATION ASM 80386, OBJ COFF ET LIEN EXE (portee reduite,
            voir le commentaire en tete de la section TODO 24 plus bas)
            Writer ASM 80386 optionnel (labels stables, sections
            .text/.data/.bss, commentaires de diagnostic), writer OBJ
            COFF i386 minimal (sections, table de symboles, relocations
            REL32/DIR32), lien .OBJ -> .EXE PE32 par defaut avec point
            d'entree et imports minimaux (kernel32/msvcrt ou runtime
            interne).

  DONE 25 - SUITE DE VALIDATION SAMPLES\XPP\* ET STABILISATION
            Les 20 fichiers SAMPLES\XPP\*.xpp compilent sans erreur et
            s'executent (code de sortie 0) dans les trois modes : par
            defaut (.EXE PE32), -obj (.OBJ COFF seul, pas d'.EXE) et
            -asm (.ASM produit en plus de la sortie par defaut).
            Sorties info() verifiees : seuls 01_hello.xpp et
            15_try_catch.xpp appellent info() avec un litteral direct
            (les autres passent par strFmt, non modelise en TODO 24,
            donc silencieux par conception) ; les deux produisent
            exactement le texte attendu sur la console.
            Regression trouvee et corrigee : MAX_BIN (buffers de code/
            donnees binaires, TODO 24) valait 65536 sans garde de
            compilation conditionnelle IFDEF FPC, ce qui aurait
            depasse la limite de segment de 65520 octets d'un Turbo
            Pascal 7 reel ; reduit a 16384 hors FPC, comme les autres
            tables (MAX_IR_NODE et consorts) qui suivent deja ce
            garde-fou.

  DONE 26 - VRAI FORMATAGE strFmt/info (au-dela du stub de TODO 24)
            info(strFmt(gabarit_litteral, args...)) produit desormais
            une vraie sortie console : le gabarit est decompose a la
            compilation en fragments litteraux et substitutions %1..%9,
            chaque argument est imprime selon son type statique (int
            et real via un vrai convertisseur decimal 80386 ecrit en
            code machine, _XPPRT_PrintInt ; boolean via "true"/"false").
            Une chaine dynamique (resultat de guid2Str/concatenation...)
            reste silencieuse, faute de representation runtime des
            chaines (portee toujours reduite, voir TODO 24) ; c'est un
            "silence" delibere et documente, pas un manque detecte.
            Tous les litteraux imprimes (info() direct ou via strFmt)
            sont aussi transcodes de UTF-8 (encodage des .xpp) vers la
            page de code OEM CP850 par defaut de cmd.exe, pour un
            affichage correct des caracteres accentues sans manipuler
            la console (chcp).
}

{ ============================================================ }
{ TODO 01 - INFRASTRUCTURE, PIPELINE ET OPTIONS DE LIGNE DE COMMANDE }
{ ============================================================ }

{ Pipeline complet vise (mis en place progressivement, TODO 02 et +):
  source .xpp -> lexer -> parser -> tables semantiques (classes,
  interfaces, tables) -> IR -> ASM 80386 optionnel (-asm) ->
  OBJ COFF i386 -> EXE PE32 (par defaut, sauf -obj). }

Const
  XPPCW32_VERSION = '0.1';
  XPPCW32_DATE    = '2026';

  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

Type
  TOptions = Record
    SrcFile:    String;
    OutFile:    String;
    Verbose:    Boolean;
    DebugMode:  Boolean;
    Warnings:   Boolean;
    EmitExe:    Boolean;
    EmitObj:    Boolean;
    EmitAsm:    Boolean;
    StrictMode: Boolean;
  End;

Var
  Opt: TOptions;

Procedure FatalError(Msg: String); Forward;
Procedure WarnMsg(Msg: String); Forward;

Function UpCaseStr(S: String): String;
Var I: Integer;
Begin
  For I := 1 To Length(S) Do S[I] := UpCase(S[I]);
  UpCaseStr := S;
End;

Function IsPathSep(C: Char): Boolean;
Begin
  IsPathSep := (C = '\') Or (C = '/');
End;

Function FileExt(S: String): String;
Var I: Integer;
Begin
  FileExt := '';
  For I := Length(S) DownTo 1 Do Begin
    If S[I] = '.' Then Begin
      FileExt := Copy(S, I, Length(S) - I + 1);
      Exit;
    End;
    If IsPathSep(S[I]) Or (S[I] = ':') Then Exit;
  End;
End;

Function ChangeExt(S, NewExt: String): String;
Var I: Integer;
Begin
  For I := Length(S) DownTo 1 Do Begin
    If S[I] = '.' Then Begin
      ChangeExt := Copy(S, 1, I - 1) + NewExt;
      Exit;
    End;
    If IsPathSep(S[I]) Or (S[I] = ':') Then Break;
  End;
  ChangeExt := S + NewExt;
End;

Function IsXppSourceName(S: String): Boolean;
Begin
  IsXppSourceName := UpCaseStr(FileExt(S)) = '.XPP';
End;

Procedure Usage;
Begin
  WriteLn('XPPCW32 - Cette commande permet de lancer le compilateur X++ ',
          '(Axapta / Microsoft Dynamics AX) pour l''assembleur du ',
          'microprocesseur 80386 pour le systeme d''exploitation ',
          'Windows 32 bits (PE Win32).');
  WriteLn;
  WriteLn('Syntaxe: XPPCW32 source.xpp [-o out] [-v] [-d] [-w] [-obj] [-asm] [-h]');
  WriteLn;
  WriteLn('Options:');
  WriteLn('  -o out     Nom du fichier de sortie');
  WriteLn('  -v         Mode verbeux');
  WriteLn('  -d         Informations de debogage');
  WriteLn('  -w         Activer les avertissements');
  WriteLn('  -obj       Produire uniquement un .OBJ COFF 32 bits (pas de .EXE)');
  WriteLn('  -asm       Produire aussi un listing assembleur .ASM (jamais par defaut)');
  WriteLn('  -h         Afficher cette aide');
End;

Procedure FatalError(Msg: String);
Begin
  WriteLn('XPPCW32: erreur: ', Msg);
  Halt(EXIT_ERROR);
End;

Procedure WarnMsg(Msg: String);
Begin
  If Opt.Warnings Then WriteLn('XPPCW32: avertissement: ', Msg);
End;

Procedure InitOptions;
Begin
  FillChar(Opt, SizeOf(Opt), 0);
  Opt.Warnings   := False;
  Opt.EmitExe    := True;
  Opt.EmitObj    := False;
  Opt.EmitAsm    := False;
  Opt.StrictMode := False;
End;

Procedure ParseArgs;
Var
  I: Integer;
  A, U: String;
Begin
  InitOptions;
  I := 1;
  While I <= ParamCount Do Begin
    A := ParamStr(I);
    U := UpCaseStr(A);
    If (U = '-H') Or (U = '/H') Or (U = '-?') Or (U = '/?') Or
       (U = '--HELP') Then Begin
      Usage;
      Halt(EXIT_USAGE);
    End Else If U = '-OBJ' Then Begin
      Opt.EmitObj := True;
      Opt.EmitExe := False;
    End Else If U = '-ASM' Then Begin
      Opt.EmitAsm := True;
    End Else If U = '-O' Then Begin
      Inc(I);
      If I > ParamCount Then FatalError('option -o sans argument');
      Opt.OutFile := ParamStr(I);
    End Else If Copy(U, 1, 2) = '-O' Then Begin
      Opt.OutFile := Copy(A, 3, Length(A) - 2);
      If Opt.OutFile = '' Then FatalError('option -o sans argument');
    End Else If U = '-V' Then Begin
      Opt.Verbose := True;
    End Else If U = '-D' Then Begin
      Opt.DebugMode := True;
    End Else If U = '-W' Then Begin
      Opt.Warnings := True;
    End Else If (Length(A) > 0) And ((A[1] = '-') Or (A[1] = '/')) Then Begin
      FatalError('option inconnue: ' + A);
    End Else Begin
      If Opt.SrcFile <> '' Then FatalError('plusieurs fichiers source specifies');
      Opt.SrcFile := A;
    End;
    Inc(I);
  End;

  If Opt.SrcFile = '' Then Begin
    Usage;
    Halt(EXIT_USAGE);
  End;
  If Not IsXppSourceName(Opt.SrcFile) Then
    FatalError('extension source invalide (attendu .xpp)');

  If Opt.OutFile = '' Then Begin
    If Opt.EmitObj Then Opt.OutFile := ChangeExt(Opt.SrcFile, '.obj')
    Else Opt.OutFile := ChangeExt(Opt.SrcFile, '.exe');
  End;
End;

{ ============================================================ }
{ TODO 02 - MODELE CIBLE WIN32 ET CONSTANTES PE/COFF            }
{ ============================================================ }

Const
  { Constantes PE (Portable Executable) et COFF }
  PE_DOS_MAGIC            = $5A4D;
  PE_PE_SIG               = $00004550;
  PE_MACHINE_I386         = $014C;
  PE_IMG_BASE             = $00400000;
  PE_SEC_ALIGN            = 4096;
  PE_FILE_ALIGN           = 512;
  PE_SUBSYS_CUI           = 3;
  PE_SUBSYS_GUI           = 2;
  PE_OPT_MAGIC_PE32       = $010B;
  PE_SCN_CNT_CODE         = $00000020;
  PE_SCN_CNT_INIT_DATA    = $00000040;
  PE_SCN_CNT_UNINIT_DATA  = $00000080;
  PE_SCN_MEM_EXECUTE      = $20000000;
  PE_SCN_MEM_READ         = $40000000;
  PE_SCN_MEM_WRITE        = -2147483648;
  COFF_SYM_CLASS_EXTERNAL = 2;
  COFF_SYM_CLASS_STATIC   = 3;
  COFF_REL_I386_DIR32     = $0006;
  COFF_REL_I386_REL32     = $0014;
  BIN_SEC_TEXT            = 1;
  BIN_SEC_DATA            = 2;
  BIN_SEC_RDATA           = 3;
  BIN_SEC_BSS             = 4;
  BIN_FIX_REL32           = 1;
  BIN_FIX_ABS32           = 2;
  BIN_FIX_IMP32           = 3;

  { Modele plat 80386 / Win32 : alignements, tailles et sections }
  I386_STACK_SLOT_SIZE = 4;
  I386_ARG_BASE_OFFSET = 8;
  I386_STACK_ALIGN     = 4;
  I386_CODE_ALIGN      = 16;
  I386_DATA_ALIGN      = 4;
  I386_BSS_ALIGN       = 4;
  FLAT_TEXT_SECTION    = '.text';
  FLAT_DATA_SECTION    = '.data';
  FLAT_RDATA_SECTION   = '.rdata';
  FLAT_BSS_SECTION     = '.bss';

  { Limites internes du compilateur }
  MAX_SYM    = {$IFDEF FPC}4096{$ELSE}512{$ENDIF};
  MAX_CLASS  = {$IFDEF FPC}512{$ELSE}64{$ENDIF};
  MAX_METHOD = {$IFDEF FPC}2048{$ELSE}256{$ENDIF};
  MAX_LOCAL  = {$IFDEF FPC}256{$ELSE}32{$ENDIF};
  MAX_PARAM  = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_LABEL  = {$IFDEF FPC}4096{$ELSE}256{$ENDIF};
  MAX_STR    = 255;
  MAX_ERRORS = {$IFDEF FPC}30{$ELSE}5{$ENDIF};

  { Prefixes de nommage des symboles ASM generes }
  ASM_PFX_GVAR    = '_XPP_';     { variable globale                    }
  ASM_PFX_METHOD  = '_XPPF_';    { methode / fonction                  }
  ASM_PFX_CLASS   = '_XPPC_';    { classe / table de methodes virtuelles }
  ASM_PFX_STRING  = '_XPPK_';    { constante chaine litterale          }
  ASM_PFX_RUNTIME = '_XPPRT_';   { routine runtime                     }
  ASM_PFX_LABEL   = '_XPPL_';    { label de saut interne               }
  ASM_PFX_TABLE   = '_XPPT_';    { table AOT simulee                   }

{ ============================================================ }
{ TODO 03 - LEXER X++ (TOKENISEUR)                              }
{ ============================================================ }

Const
  { Types de tokens }
  TOK_EOF        = 0;
  TOK_IDENT      = 256;
  TOK_INTEGER    = 257;
  TOK_FLOAT      = 258;
  TOK_STRING     = 259;   { "..." }
  TOK_CHAR       = 260;   { 'x' un seul caractere }
  TOK_DATELIT    = 261;   { 'jj/mm/aaaa' }
  TOK_INCR       = 262;   { ++ }
  TOK_DECR       = 263;   { -- }
  TOK_PLUSEQ     = 264;   { += }
  TOK_MINUSEQ    = 265;   { -= }
  TOK_STAREQ     = 266;   { *= }
  TOK_SLASHEQ    = 267;   { /= }
  TOK_EQ         = 268;   { == }
  TOK_NE         = 269;   { != }
  TOK_LE         = 270;   { <= }
  TOK_GE         = 271;   { >= }
  TOK_ANDAND     = 272;   { && }
  TOK_OROR       = 273;   { || }
  TOK_SHL        = 274;   { << }
  TOK_SHR        = 275;   { >> }
  TOK_ARROW      = 276;   { -> }
  TOK_COLONCOLON = 277;   { :: }
  TOK_DOTDOT     = 278;   { .. }

Var
  SrcBuf:      Array[1..65535] Of Char;
  SrcLen:      LongInt;
  LexPos:      LongInt;
  LexLine:     LongInt;
  LexCol:      LongInt;
  CurTokType:  Integer;
  CurTokStr:   String;
  CurTokNum:   LongInt;
  CurTokFloat: Double;
  CurTokLine:  LongInt;
  CurTokCol:   LongInt;
  LastTokType: Integer;

Function IsKeyword(S: String): Integer; Forward;
Function KeywordName(K: Integer): String; Forward;
Procedure ParseEnumDecl; Forward;   { corps reel en TODO 07 }
Procedure ScanMethodBody(MIdx: Integer); Forward;   { corps reel en TODO 08 }
Function ParseExpression: Integer; Forward;   { corps reel en TODO 09 }
Function ShortCircuitConst(NodeIdx: Integer; Var Value: Boolean): Boolean; Forward;   { corps reel en TODO 10 }
Function ParseSwitchStatement(MIdx: Integer): Integer; Forward;   { corps reel en TODO 11 }
Function ParseWhileStatement(MIdx: Integer): Integer; Forward;    { corps reel en TODO 12 }
Function ParseDoWhileStatement(MIdx: Integer): Integer; Forward;  { corps reel en TODO 12 }
Function ParseForStatement(MIdx: Integer): Integer; Forward;      { corps reel en TODO 12 }
Function ParseBreakStatement: Integer; Forward;                   { corps reel en TODO 12 }
Function ParseContinueStatement: Integer; Forward;                { corps reel en TODO 12 }
Function ParseReturnStatement(MIdx: Integer): Integer; Forward;   { corps reel en TODO 13 }
Function TypeCompatible(ArgType, ParamType: String): Boolean; Forward;   { corps reel en TODO 13 }
Function CountCallArgs(ArgHead: Integer): Integer; Forward;              { corps reel en TODO 13 }
Procedure CheckCallArgs(MethodIdx, ArgHead: Integer; CalleeDesc: String); Forward;   { corps reel en TODO 13 }
Function ParseTryStatement(MIdx: Integer): Integer; Forward;   { corps reel en TODO 16 }
Function ParseThrowStatement(MIdx: Integer): Integer; Forward;   { corps reel en TODO 16 }
Procedure RegisterBuiltinEnums; Forward;   { corps reel en TODO 16 }
Procedure ParseAttribute(Var HasSubscribe: Boolean;
                          Var SubClassName, SubDelegateName: String); Forward;   { corps reel en TODO 17 }
Function FindAotTable(Name: String): Integer; Forward;                    { corps reel en TODO 18 }
Function FindAotField(TableIdx: Integer; Name: String): Integer; Forward; { corps reel en TODO 18 }
Function AotFieldTypeName(FieldIdx: Integer): String; Forward;            { corps reel en TODO 18 }
Procedure ResolveTableNumCall(CallNode, ArgHead: Integer); Forward;        { corps reel en TODO 18 }
Procedure ResolveFieldNumCall(CallNode, ArgHead: Integer); Forward;        { corps reel en TODO 18 }
Procedure RegisterBuiltinTables; Forward;                                  { corps reel en TODO 18 }
Function ParseWhileSelectStatement(MIdx: Integer): Integer; Forward;   { corps reel en TODO 19 }
Function ParseSelectStatement: Integer; Forward;                       { corps reel en TODO 19 }
Function ParseTtsBeginStatement: Integer; Forward;    { corps reel en TODO 20 }
Function ParseTtsCommitStatement: Integer; Forward;   { corps reel en TODO 20 }
Function ParseTtsAbortStatement: Integer; Forward;    { corps reel en TODO 20 }
Function ParseDeleteFromStatement: Integer; Forward;  { corps reel en TODO 20 }
Procedure RegisterBuiltinQueryClasses; Forward;   { corps reel en TODO 21 }
Function AotTableName(Idx: Integer): String; Forward;   { corps reel en TODO 21 }
Procedure RegisterBuiltinCollectionClasses; Forward;   { corps reel en TODO 22 }
Procedure RegisterBuiltinRuntimeFuncs; Forward;   { corps reel en TODO 23 }

Function ItoS(N: LongInt): String;
Var S: String;
Begin Str(N, S); ItoS := S; End;

Function IsAlpha(C: Char): Boolean;
Begin
  IsAlpha := ((C >= 'A') And (C <= 'Z')) Or ((C >= 'a') And (C <= 'z')) Or
             (C = '_');
End;

Function IsDigit(C: Char): Boolean;
Begin IsDigit := (C >= '0') And (C <= '9'); End;

Function IsIdentChar(C: Char): Boolean;
Begin IsIdentChar := IsAlpha(C) Or IsDigit(C); End;

Procedure AppendTok(C: Char);
Begin
  If Length(CurTokStr) < 255 Then CurTokStr := CurTokStr + C;
End;

Function LexPeekChar: Char;
Begin
  If LexPos > SrcLen Then LexPeekChar := #0
  Else LexPeekChar := SrcBuf[LexPos];
End;

Function LexPeekChar2: Char;
Begin
  If LexPos + 1 > SrcLen Then LexPeekChar2 := #0
  Else LexPeekChar2 := SrcBuf[LexPos + 1];
End;

Function LexNextChar: Char;
Var C: Char;
Begin
  If LexPos > SrcLen Then Begin LexNextChar := #0; Exit; End;
  C := SrcBuf[LexPos];
  Inc(LexPos);
  If C = #10 Then Begin Inc(LexLine); LexCol := 1; End
  Else If C <> #13 Then Inc(LexCol);
  LexNextChar := C;
End;

Procedure LexInit(FileName: String);
Var
  F: File;
  N: LongInt;
Begin
  SrcLen := 0;
  Assign(F, FileName);
  {$I-} Reset(F, 1); {$I+}
  If IOResult <> 0 Then FatalError('impossible d''ouvrir ' + FileName);
  BlockRead(F, SrcBuf, 65535, N);
  SrcLen := N;
  If Not Eof(F) Then Begin Close(F); FatalError('fichier source trop volumineux'); End;
  Close(F);
  LexPos  := 1; LexLine := 1; LexCol := 1;
  CurTokType  := TOK_EOF; CurTokStr := ''; CurTokNum := 0;
  CurTokFloat := 0; LastTokType := TOK_EOF;
End;

Procedure LexClose;
Begin
  SrcLen := 0; LexPos := 1; LexLine := 1; LexCol := 1;
End;

{ Ignore le reste de la ligne courante (commentaire //) }
Procedure SkipLineComment;
Begin
  While (LexPeekChar <> #0) And (LexPeekChar <> #10) Do LexNextChar;
End;

{ Ignore un commentaire de bloc /* ... */ }
Procedure SkipBlockComment;
Begin
  LexNextChar; LexNextChar; { consomme /* }
  While Not ((LexPeekChar = '*') And (LexPeekChar2 = '/')) Do Begin
    If LexPeekChar = #0 Then FatalError('commentaire de bloc non termine');
    LexNextChar;
  End;
  LexNextChar; LexNextChar; { consomme */ }
End;

{ Lit un identificateur et resout les mots-cles via IsKeyword (TODO 04) }
Procedure ReadIdent;
Var K: Integer;
Begin
  While IsIdentChar(LexPeekChar) Do AppendTok(LexNextChar);
  K := IsKeyword(CurTokStr);
  If K <> 0 Then CurTokType := K Else CurTokType := TOK_IDENT;
End;

{ Lit un nombre entier ou reel (notation scientifique incluse) }
Procedure ReadNumber;
Var
  IsFloat: Boolean;
  ValCode: Integer;
Begin
  CurTokType := TOK_INTEGER;
  CurTokNum  := 0;
  IsFloat    := False;
  While IsDigit(LexPeekChar) Do Begin
    CurTokNum := CurTokNum * 10 + (Ord(LexPeekChar) - Ord('0'));
    AppendTok(LexNextChar);
  End;
  If (LexPeekChar = '.') And IsDigit(LexPeekChar2) Then Begin
    IsFloat := True;
    AppendTok(LexNextChar);
    While IsDigit(LexPeekChar) Do AppendTok(LexNextChar);
  End;
  If (UpCase(LexPeekChar) = 'E') And
     (IsDigit(LexPeekChar2) Or (LexPeekChar2 = '+') Or (LexPeekChar2 = '-')) Then Begin
    IsFloat := True;
    AppendTok(LexNextChar);
    If (LexPeekChar = '+') Or (LexPeekChar = '-') Then AppendTok(LexNextChar);
    While IsDigit(LexPeekChar) Do AppendTok(LexNextChar);
  End;
  If IsFloat Then Begin
    CurTokType := TOK_FLOAT;
    Val(CurTokStr, CurTokFloat, ValCode);
  End;
End;

{ Lit une chaine "texte" avec echappements \n \t \r \\ \" \0 }
Procedure ReadDoubleString;
Var C: Char;
Begin
  CurTokType := TOK_STRING;
  LexNextChar; { consomme le guillemet ouvrant }
  While True Do Begin
    C := LexNextChar;
    If C = #0 Then FatalError('chaine non terminee');
    If C = '"' Then Break;
    If C = '\' Then Begin
      C := LexNextChar;
      If C = #0 Then FatalError('chaine non terminee');
      Case C Of
        'n': AppendTok(#10);
        't': AppendTok(#9);
        'r': AppendTok(#13);
        '0': AppendTok(#0);
        '\': AppendTok('\');
        '"': AppendTok('"');
      Else
        Begin AppendTok('\'); AppendTok(C); End;
      End;
    End Else AppendTok(C);
  End;
End;

{ Lit un litteral entre guillemets simples : caractere unique 'x' ou
  date 'jj/mm/aaaa' }
Procedure ReadCharOrDate;
Var
  C:         Char;
  Raw:       String;
  I:         Integer;
  SlashCnt:  Integer;
  DigitsOk:  Boolean;
Begin
  Raw := '';
  LexNextChar; { consomme le guillemet simple ouvrant }
  While True Do Begin
    C := LexNextChar;
    If C = #0 Then FatalError('litteral entre guillemets simples non termine');
    If C = '''' Then Break;
    If C = '\' Then Begin
      C := LexNextChar;
      If C = #0 Then FatalError('litteral entre guillemets simples non termine');
      If (C = '\') Or (C = '''') Then Raw := Raw + C
      Else Begin Raw := Raw + '\'; Raw := Raw + C; End;
    End Else Raw := Raw + C;
  End;
  CurTokStr := Raw;
  SlashCnt  := 0;
  DigitsOk  := Length(Raw) > 0;
  For I := 1 To Length(Raw) Do Begin
    If Raw[I] = '/' Then Inc(SlashCnt)
    Else If Not IsDigit(Raw[I]) Then DigitsOk := False;
  End;
  If (Length(Raw) = 1) And (SlashCnt = 0) Then
    CurTokType := TOK_CHAR
  Else If DigitsOk And (SlashCnt = 2) Then
    CurTokType := TOK_DATELIT
  Else
    FatalError('litteral entre guillemets simples invalide ' +
               '(attendu un caractere ou une date jj/mm/aaaa)');
End;

{ Analyse lexicale principale : produit le prochain token dans
  CurTokType / CurTokStr / CurTokNum / CurTokFloat }
Procedure LexNextToken;
Var
  C, C2: Char;
  Done:  Boolean;
Begin
  CurTokStr := ''; CurTokNum := 0; CurTokFloat := 0;
  Done := False;
  While Not Done Do Begin
    C := LexPeekChar;
    If (C = ' ') Or (C = #9) Or (C = #10) Or (C = #13) Then LexNextChar
    Else If (C = '/') And (LexPeekChar2 = '/') Then SkipLineComment
    Else If (C = '/') And (LexPeekChar2 = '*') Then SkipBlockComment
    Else Done := True;
  End;

  CurTokLine := LexLine; CurTokCol := LexCol;
  C  := LexPeekChar;
  C2 := LexPeekChar2;

  If C = #0 Then CurTokType := TOK_EOF
  Else If IsAlpha(C) Then ReadIdent
  Else If IsDigit(C) Then ReadNumber
  Else If (C = '.') And IsDigit(C2) Then ReadNumber
  Else If C = '"' Then ReadDoubleString
  Else If C = '''' Then ReadCharOrDate
  Else If (C = '+') And (C2 = '+') Then Begin
    CurTokType := TOK_INCR; AppendTok(LexNextChar); AppendTok(LexNextChar);
  End Else If (C = '+') And (C2 = '=') Then Begin
    CurTokType := TOK_PLUSEQ; AppendTok(LexNextChar); AppendTok(LexNextChar);
  End Else If C = '+' Then Begin
    CurTokType := Ord('+'); AppendTok(LexNextChar);
  End Else If (C = '-') And (C2 = '-') Then Begin
    CurTokType := TOK_DECR; AppendTok(LexNextChar); AppendTok(LexNextChar);
  End Else If (C = '-') And (C2 = '=') Then Begin
    CurTokType := TOK_MINUSEQ; AppendTok(LexNextChar); AppendTok(LexNextChar);
  End Else If (C = '-') And (C2 = '>') Then Begin
    CurTokType := TOK_ARROW; AppendTok(LexNextChar); AppendTok(LexNextChar);
  End Else If C = '-' Then Begin
    CurTokType := Ord('-'); AppendTok(LexNextChar);
  End Else If (C = '*') And (C2 = '=') Then Begin
    CurTokType := TOK_STAREQ; AppendTok(LexNextChar); AppendTok(LexNextChar);
  End Else If C = '*' Then Begin
    CurTokType := Ord('*'); AppendTok(LexNextChar);
  End Else If (C = '/') And (C2 = '=') Then Begin
    CurTokType := TOK_SLASHEQ; AppendTok(LexNextChar); AppendTok(LexNextChar);
  End Else If C = '/' Then Begin
    CurTokType := Ord('/'); AppendTok(LexNextChar);
  End Else If (C = '=') And (C2 = '=') Then Begin
    CurTokType := TOK_EQ; AppendTok(LexNextChar); AppendTok(LexNextChar);
  End Else If C = '=' Then Begin
    CurTokType := Ord('='); AppendTok(LexNextChar);
  End Else If (C = '!') And (C2 = '=') Then Begin
    CurTokType := TOK_NE; AppendTok(LexNextChar); AppendTok(LexNextChar);
  End Else If C = '!' Then Begin
    CurTokType := Ord('!'); AppendTok(LexNextChar);
  End Else If (C = '<') And (C2 = '=') Then Begin
    CurTokType := TOK_LE; AppendTok(LexNextChar); AppendTok(LexNextChar);
  End Else If (C = '<') And (C2 = '<') Then Begin
    CurTokType := TOK_SHL; AppendTok(LexNextChar); AppendTok(LexNextChar);
  End Else If C = '<' Then Begin
    CurTokType := Ord('<'); AppendTok(LexNextChar);
  End Else If (C = '>') And (C2 = '=') Then Begin
    CurTokType := TOK_GE; AppendTok(LexNextChar); AppendTok(LexNextChar);
  End Else If (C = '>') And (C2 = '>') Then Begin
    CurTokType := TOK_SHR; AppendTok(LexNextChar); AppendTok(LexNextChar);
  End Else If C = '>' Then Begin
    CurTokType := Ord('>'); AppendTok(LexNextChar);
  End Else If (C = '&') And (C2 = '&') Then Begin
    CurTokType := TOK_ANDAND; AppendTok(LexNextChar); AppendTok(LexNextChar);
  End Else If C = '&' Then Begin
    CurTokType := Ord('&'); AppendTok(LexNextChar);
  End Else If (C = '|') And (C2 = '|') Then Begin
    CurTokType := TOK_OROR; AppendTok(LexNextChar); AppendTok(LexNextChar);
  End Else If C = '|' Then Begin
    CurTokType := Ord('|'); AppendTok(LexNextChar);
  End Else If C = '^' Then Begin
    CurTokType := Ord('^'); AppendTok(LexNextChar);
  End Else If C = '~' Then Begin
    CurTokType := Ord('~'); AppendTok(LexNextChar);
  End Else If (C = ':') And (C2 = ':') Then Begin
    CurTokType := TOK_COLONCOLON; AppendTok(LexNextChar); AppendTok(LexNextChar);
  End Else If C = ':' Then Begin
    CurTokType := Ord(':'); AppendTok(LexNextChar);
  End Else If (C = '.') And (C2 = '.') Then Begin
    CurTokType := TOK_DOTDOT; AppendTok(LexNextChar); AppendTok(LexNextChar);
  End Else If C = '.' Then Begin
    CurTokType := Ord('.'); AppendTok(LexNextChar);
  End Else If (C = ';') Or (C = ',') Or (C = '(') Or (C = ')') Or
              (C = '[') Or (C = ']') Or (C = '{') Or (C = '}') Then Begin
    CurTokType := Ord(C); AppendTok(LexNextChar);
  End Else Begin
    FatalError('caractere inattendu (code ' + ItoS(Ord(C)) + ')');
  End;

  LastTokType := CurTokType;
End;

{ Nom lisible d'un token, utilise par le mode debug (-d) }
Function TokenName(T: Integer): String;
Begin
  Case T Of
    TOK_EOF:        TokenName := 'TOK_EOF';
    TOK_IDENT:      TokenName := 'TOK_IDENT';
    TOK_INTEGER:    TokenName := 'TOK_INTEGER';
    TOK_FLOAT:      TokenName := 'TOK_FLOAT';
    TOK_STRING:     TokenName := 'TOK_STRING';
    TOK_CHAR:       TokenName := 'TOK_CHAR';
    TOK_DATELIT:    TokenName := 'TOK_DATELIT';
    TOK_INCR:       TokenName := 'TOK_INCR';
    TOK_DECR:       TokenName := 'TOK_DECR';
    TOK_PLUSEQ:     TokenName := 'TOK_PLUSEQ';
    TOK_MINUSEQ:    TokenName := 'TOK_MINUSEQ';
    TOK_STAREQ:     TokenName := 'TOK_STAREQ';
    TOK_SLASHEQ:    TokenName := 'TOK_SLASHEQ';
    TOK_EQ:         TokenName := 'TOK_EQ';
    TOK_NE:         TokenName := 'TOK_NE';
    TOK_LE:         TokenName := 'TOK_LE';
    TOK_GE:         TokenName := 'TOK_GE';
    TOK_ANDAND:     TokenName := 'TOK_ANDAND';
    TOK_OROR:       TokenName := 'TOK_OROR';
    TOK_SHL:        TokenName := 'TOK_SHL';
    TOK_SHR:        TokenName := 'TOK_SHR';
    TOK_ARROW:      TokenName := 'TOK_ARROW';
    TOK_COLONCOLON: TokenName := 'TOK_COLONCOLON';
    TOK_DOTDOT:     TokenName := 'TOK_DOTDOT';
    Else
      If (T > 0) And (T < 128) Then TokenName := '''' + Chr(T) + ''''
      Else If T >= 1000 Then TokenName := KeywordName(T)
      Else TokenName := 'TOK_' + ItoS(T);
  End;
End;

{ Affiche tous les tokens du fichier source (mode -d, tant que le
  parser n'est pas encore branche) }
Procedure DumpTokens;
Begin
  LexInit(Opt.SrcFile);
  Repeat
    LexNextToken;
    WriteLn(CurTokLine:4, ':', CurTokCol:3, '  ', TokenName(CurTokType),
            '  [', CurTokStr, ']');
  Until CurTokType = TOK_EOF;
  LexClose;
End;

{ ============================================================ }
{ TODO 04 - MOTS-CLES ET TYPES DE BASE X++                      }
{ ============================================================ }

Const
  { Structure du langage : classes, interfaces, visibilite }
  KW_CLASS      = 1000;
  KW_INTERFACE  = 1001;
  KW_EXTENDS    = 1002;
  KW_IMPLEMENTS = 1003;
  KW_PUBLIC     = 1004;
  KW_PRIVATE    = 1005;
  KW_PROTECTED  = 1006;
  KW_STATIC     = 1007;
  KW_VOID       = 1008;
  KW_NEW        = 1009;
  KW_THIS       = 1010;
  KW_SUPER      = 1011;

  { Controle de flux }
  KW_IF       = 1012;
  KW_ELSE     = 1013;
  KW_SWITCH   = 1014;
  KW_CASE     = 1015;
  KW_DEFAULT  = 1016;
  KW_BREAK    = 1017;
  KW_CONTINUE = 1018;
  KW_WHILE    = 1019;
  KW_DO       = 1020;
  KW_FOR      = 1021;
  KW_RETURN   = 1022;

  { Exceptions et delegates }
  KW_TRY       = 1023;
  KW_CATCH     = 1024;
  KW_THROW     = 1025;
  KW_FINALLY   = 1026;
  KW_DELEGATE  = 1027;

  { Acces aux donnees (tables AOT simulees) }
  KW_CONTAINER    = 1028;
  KW_SELECT       = 1029;
  KW_INSERT       = 1030;
  KW_UPDATE       = 1031;
  KW_DELETE       = 1032;
  KW_DELETE_FROM  = 1033;
  KW_TTSBEGIN     = 1034;
  KW_TTSCOMMIT    = 1035;
  KW_TTSABORT     = 1036;
  KW_ORDER        = 1037;
  KW_BY           = 1038;
  KW_GROUP        = 1039;
  KW_EXISTS       = 1040;
  KW_JOIN         = 1041;

  { Operateurs mots-cles (comme en Pascal) }
  KW_DIV = 1042;
  KW_MOD = 1043;

  { Types scalaires de base }
  KW_INT      = 1044;
  KW_REAL     = 1045;
  KW_STR      = 1046;
  KW_BOOLEAN  = 1047;
  KW_DATE     = 1048;
  KW_GUID     = 1049;
  KW_ANYTYPE  = 1050;
  KW_ENUM     = 1051;

  { Litteraux booleens, ajoutes par TODO 08 pour les initialiseurs de
    variables (valeur par defaut "false" et litteraux "true"/"false") }
  KW_TRUE  = 1052;
  KW_FALSE = 1053;

  { Oublis de TODO 04 corriges par TODO 08 : ces deux mots doivent
    rester reserves pour que le scanner de corps de methode ne les
    confonde pas avec "Type Nom" (deux identificateurs qui se suivent) }
  KW_WHERE     = 1054;
  KW_FORUPDATE = 1055;

{ Resout un identificateur en mot-cle X++ (0 si identificateur libre).
  X++ est sensible a la casse : comparaison exacte, pas de UpCaseStr. }
Function IsKeyword(S: String): Integer;
Begin
  IsKeyword := 0;
  { --- Structure du langage --- }
  If      S = 'class'      Then IsKeyword := KW_CLASS
  Else If S = 'interface'  Then IsKeyword := KW_INTERFACE
  Else If S = 'extends'    Then IsKeyword := KW_EXTENDS
  Else If S = 'implements' Then IsKeyword := KW_IMPLEMENTS
  Else If S = 'public'     Then IsKeyword := KW_PUBLIC
  Else If S = 'private'    Then IsKeyword := KW_PRIVATE
  Else If S = 'protected'  Then IsKeyword := KW_PROTECTED
  Else If S = 'static'     Then IsKeyword := KW_STATIC
  Else If S = 'void'       Then IsKeyword := KW_VOID
  Else If S = 'new'        Then IsKeyword := KW_NEW
  Else If S = 'this'       Then IsKeyword := KW_THIS
  Else If S = 'super'      Then IsKeyword := KW_SUPER
  { --- Controle de flux --- }
  Else If S = 'if'         Then IsKeyword := KW_IF
  Else If S = 'else'       Then IsKeyword := KW_ELSE
  Else If S = 'switch'     Then IsKeyword := KW_SWITCH
  Else If S = 'case'       Then IsKeyword := KW_CASE
  Else If S = 'default'    Then IsKeyword := KW_DEFAULT
  Else If S = 'break'      Then IsKeyword := KW_BREAK
  Else If S = 'continue'   Then IsKeyword := KW_CONTINUE
  Else If S = 'while'      Then IsKeyword := KW_WHILE
  Else If S = 'do'         Then IsKeyword := KW_DO
  Else If S = 'for'        Then IsKeyword := KW_FOR
  Else If S = 'return'     Then IsKeyword := KW_RETURN
  { --- Exceptions et delegates --- }
  Else If S = 'try'        Then IsKeyword := KW_TRY
  Else If S = 'catch'      Then IsKeyword := KW_CATCH
  Else If S = 'throw'      Then IsKeyword := KW_THROW
  Else If S = 'finally'    Then IsKeyword := KW_FINALLY
  Else If S = 'delegate'   Then IsKeyword := KW_DELEGATE
  { --- Acces aux donnees --- }
  Else If S = 'container'    Then IsKeyword := KW_CONTAINER
  Else If S = 'select'       Then IsKeyword := KW_SELECT
  Else If S = 'insert'       Then IsKeyword := KW_INSERT
  Else If S = 'update'       Then IsKeyword := KW_UPDATE
  Else If S = 'delete'       Then IsKeyword := KW_DELETE
  Else If S = 'delete_from'  Then IsKeyword := KW_DELETE_FROM
  Else If S = 'ttsBegin'     Then IsKeyword := KW_TTSBEGIN
  Else If S = 'ttsCommit'    Then IsKeyword := KW_TTSCOMMIT
  Else If S = 'ttsAbort'     Then IsKeyword := KW_TTSABORT
  Else If S = 'order'        Then IsKeyword := KW_ORDER
  Else If S = 'by'           Then IsKeyword := KW_BY
  Else If S = 'group'        Then IsKeyword := KW_GROUP
  Else If S = 'exists'       Then IsKeyword := KW_EXISTS
  Else If S = 'join'         Then IsKeyword := KW_JOIN
  { --- Operateurs mots-cles --- }
  Else If S = 'div' Then IsKeyword := KW_DIV
  Else If S = 'mod' Then IsKeyword := KW_MOD
  { --- Types scalaires de base --- }
  Else If S = 'int'      Then IsKeyword := KW_INT
  Else If S = 'real'     Then IsKeyword := KW_REAL
  Else If S = 'str'      Then IsKeyword := KW_STR
  Else If S = 'boolean'  Then IsKeyword := KW_BOOLEAN
  Else If S = 'date'     Then IsKeyword := KW_DATE
  Else If S = 'guid'     Then IsKeyword := KW_GUID
  Else If S = 'anytype'  Then IsKeyword := KW_ANYTYPE
  Else If S = 'enum'     Then IsKeyword := KW_ENUM
  { --- Litteraux booleens --- }
  Else If S = 'true'     Then IsKeyword := KW_TRUE
  Else If S = 'false'    Then IsKeyword := KW_FALSE
  { --- Mots reserves des requetes, ajoutes par TODO 08 --- }
  Else If S = 'where'     Then IsKeyword := KW_WHERE
  Else If S = 'forUpdate' Then IsKeyword := KW_FORUPDATE;
End;

{ Nom lisible d'un mot-cle, utilise par le mode debug (-d) }
Function KeywordName(K: Integer): String;
Begin
  Case K Of
    KW_CLASS:      KeywordName := 'KW_CLASS';
    KW_INTERFACE:  KeywordName := 'KW_INTERFACE';
    KW_EXTENDS:    KeywordName := 'KW_EXTENDS';
    KW_IMPLEMENTS: KeywordName := 'KW_IMPLEMENTS';
    KW_PUBLIC:     KeywordName := 'KW_PUBLIC';
    KW_PRIVATE:    KeywordName := 'KW_PRIVATE';
    KW_PROTECTED:  KeywordName := 'KW_PROTECTED';
    KW_STATIC:     KeywordName := 'KW_STATIC';
    KW_VOID:       KeywordName := 'KW_VOID';
    KW_NEW:        KeywordName := 'KW_NEW';
    KW_THIS:       KeywordName := 'KW_THIS';
    KW_SUPER:      KeywordName := 'KW_SUPER';
    KW_IF:         KeywordName := 'KW_IF';
    KW_ELSE:       KeywordName := 'KW_ELSE';
    KW_SWITCH:     KeywordName := 'KW_SWITCH';
    KW_CASE:       KeywordName := 'KW_CASE';
    KW_DEFAULT:    KeywordName := 'KW_DEFAULT';
    KW_BREAK:      KeywordName := 'KW_BREAK';
    KW_CONTINUE:   KeywordName := 'KW_CONTINUE';
    KW_WHILE:      KeywordName := 'KW_WHILE';
    KW_DO:         KeywordName := 'KW_DO';
    KW_FOR:        KeywordName := 'KW_FOR';
    KW_RETURN:     KeywordName := 'KW_RETURN';
    KW_TRY:        KeywordName := 'KW_TRY';
    KW_CATCH:      KeywordName := 'KW_CATCH';
    KW_THROW:      KeywordName := 'KW_THROW';
    KW_FINALLY:    KeywordName := 'KW_FINALLY';
    KW_DELEGATE:   KeywordName := 'KW_DELEGATE';
    KW_CONTAINER:   KeywordName := 'KW_CONTAINER';
    KW_SELECT:      KeywordName := 'KW_SELECT';
    KW_INSERT:      KeywordName := 'KW_INSERT';
    KW_UPDATE:      KeywordName := 'KW_UPDATE';
    KW_DELETE:      KeywordName := 'KW_DELETE';
    KW_DELETE_FROM: KeywordName := 'KW_DELETE_FROM';
    KW_TTSBEGIN:    KeywordName := 'KW_TTSBEGIN';
    KW_TTSCOMMIT:   KeywordName := 'KW_TTSCOMMIT';
    KW_TTSABORT:    KeywordName := 'KW_TTSABORT';
    KW_ORDER:       KeywordName := 'KW_ORDER';
    KW_BY:          KeywordName := 'KW_BY';
    KW_GROUP:       KeywordName := 'KW_GROUP';
    KW_EXISTS:      KeywordName := 'KW_EXISTS';
    KW_JOIN:        KeywordName := 'KW_JOIN';
    KW_DIV: KeywordName := 'KW_DIV';
    KW_MOD: KeywordName := 'KW_MOD';
    KW_INT:      KeywordName := 'KW_INT';
    KW_REAL:     KeywordName := 'KW_REAL';
    KW_STR:      KeywordName := 'KW_STR';
    KW_BOOLEAN:  KeywordName := 'KW_BOOLEAN';
    KW_DATE:     KeywordName := 'KW_DATE';
    KW_GUID:     KeywordName := 'KW_GUID';
    KW_ANYTYPE:  KeywordName := 'KW_ANYTYPE';
    KW_ENUM:     KeywordName := 'KW_ENUM';
    KW_TRUE:     KeywordName := 'KW_TRUE';
    KW_FALSE:    KeywordName := 'KW_FALSE';
    KW_WHERE:     KeywordName := 'KW_WHERE';
    KW_FORUPDATE: KeywordName := 'KW_FORUPDATE';
  Else
    KeywordName := 'KW_' + ItoS(K);
  End;
End;

{ ============================================================ }
{ TODO 05 - DECLARATIONS DE CLASSES ET D'INTERFACES (PARSER)    }
{ ============================================================ }

Const
  MAX_FIELD_TOTAL      = {$IFDEF FPC}4096{$ELSE}256{$ENDIF};
  MAX_PARAM_TOTAL      = {$IFDEF FPC}4096{$ELSE}256{$ENDIF};
  MAX_IMPLEMENTS_TOTAL = {$IFDEF FPC}512{$ELSE}64{$ENDIF};
  { Types composes (TODO 07) : enums declares au niveau du programme }
  MAX_ENUM       = {$IFDEF FPC}256{$ELSE}32{$ENDIF};
  MAX_ENUM_VALUE = {$IFDEF FPC}4096{$ELSE}256{$ENDIF};
  { Variables locales (TODO 08), total toutes methodes confondues }
  MAX_LOCAL_TOTAL = {$IFDEF FPC}4096{$ELSE}256{$ENDIF};

Type
  TFieldInfo = Record
    ClassIdx:       Integer;
    Name:           String;
    TypeName:       String;
    IsArray:        Boolean;   { ajoute par TODO 07 : tableau fixe Type Nom[N] }
    ArraySize:      Integer;
    InstanceOffset: Integer;   { ajoute par TODO 08 : deplacement dans l'objet }
  End;
  TFieldTable = Array[1..MAX_FIELD_TOTAL] Of TFieldInfo;

  TParamInfo = Record
    Name:     String;
    TypeName: String;
  End;
  TParamTable = Array[1..MAX_PARAM_TOTAL] Of TParamInfo;

  TMethodInfo = Record
    ClassIdx:   Integer;
    Name:       String;
    RetType:    String;
    Visibility: Integer;   { KW_PUBLIC / KW_PRIVATE / KW_PROTECTED }
    IsStatic:   Boolean;
    IsCtor:     Boolean;
    IsDelegate: Boolean;
    ParamStart: Integer;
    ParamCount: Integer;
    LocalStart: Integer;   { ajoute par TODO 08 : variables locales }
    LocalCount: Integer;
    BodyStmt:   Integer;   { ajoute par TODO 10 : racine du bloc d'instructions }
    IsVariadic: Boolean;   { ajoute par TODO 23 : accepte des arguments en plus des parametres fixes (ex. strFmt) }
  End;
  TMethodTable = Array[1..MAX_METHOD] Of TMethodInfo;

  { Variables locales (TODO 08) : declarees dans un corps de methode,
    avec deplacement EBP-relatif et initialiseur optionnel }
  TLocalInfo = Record
    MethodIdx: Integer;
    Name:      String;
    TypeName:  String;
    IsArray:   Boolean;
    ArraySize: Integer;
    Offset:    Integer;   { EBP - Offset }
    HasInit:   Boolean;
    ExprNode:  Integer;   { ajoute par TODO 09 : indice dans IRNodes, 0 si aucun }
    InitType:  String;    { type infere de l'expression d'initialisation }
  End;
  TLocalTable = Array[1..MAX_LOCAL_TOTAL] Of TLocalInfo;

  TClassInfo = Record
    Name:        String;
    IsInterface: Boolean;
    ParentName:  String;   { chaine vide si aucun extends }
    ParentIdx:   Integer;  { resolu par TODO 06, 0 si aucun/inconnu }
    ImplStart:   Integer;
    ImplCount:   Integer;
    FieldStart:  Integer;
    FieldCount:  Integer;
    MethodStart: Integer;
    MethodCount: Integer;
    VTableStart: Integer;   { ajoute par TODO 14 : table des methodes virtuelles }
    VTableCount: Integer;
  End;
  TClassTable = Array[1..MAX_CLASS] Of TClassInfo;

  TImplementsEntry = Record
    Name:        String;
    ResolvedIdx: Integer;   { resolu par TODO 06, 0 tant qu'inconnu }
  End;
  TImplementsTable = Array[1..MAX_IMPLEMENTS_TOTAL] Of TImplementsEntry;

  { Types composes (TODO 07) : enum Nom suivi d'un bloc de valeurs,
    ex. Valeur1, Valeur2(N), ... }
  TEnumValueInfo = Record
    Name:    String;
    Ordinal: Integer;
  End;
  TEnumValueTable = Array[1..MAX_ENUM_VALUE] Of TEnumValueInfo;

  TEnumInfo = Record
    Name:       String;
    ValueStart: Integer;
    ValueCount: Integer;
  End;
  TEnumTable = Array[1..MAX_ENUM] Of TEnumInfo;

Var
  Classes:         TClassTable;
  ClassCount:      Integer;
  Fields:          TFieldTable;
  FieldCount:      Integer;
  Methods:         TMethodTable;
  MethodCount:     Integer;
  Params:          TParamTable;
  ParamCount:      Integer;
  Implements:      TImplementsTable;
  ImplementsCount: Integer;
  Enums:           TEnumTable;
  EnumCount:       Integer;
  EnumValues:      TEnumValueTable;
  EnumValueCount:  Integer;
  Locals:          TLocalTable;
  LocalCount:      Integer;
  { Profondeur d'imbrication courante des boucles/switch, utilisee
    par le switch (TODO 11) et les boucles/break/continue (TODO 12)
    pour verifier que break/continue apparaissent dans un contexte valide }
  LoopDepth:       Integer;
  SwitchDepth:     Integer;
  { Profondeur d'imbrication des transactions ttsBegin/ttsCommit
    (TODO 20), remise a zero et verifiee a chaque methode }
  TtsDepth:        Integer;
  { Classe fictive regroupant les fonctions runtime natives globales
    (TODO 23), non atteignable par le code utilisateur car son nom
    n'est pas un identificateur valide }
  GlobalFuncClassIdx: Integer;
  ParseErrors:     Integer;

Procedure ParseError(Msg: String);
Begin
  Inc(ParseErrors);
  WriteLn('XPPCW32: erreur ligne ', CurTokLine, ': ', Msg);
End;

{ Avale le token courant s'il correspond a T ; renvoie si oui/non }
Function AcceptTok(T: Integer): Boolean;
Begin
  If CurTokType = T Then Begin
    LexNextToken;
    AcceptTok := True;
  End Else
    AcceptTok := False;
End;

{ Exige le token T (sinon erreur signalee) puis avance dans tous les cas
  (recuperation simple : ne bloque jamais sur un token inattendu) }
Procedure Expect(T: Integer; What: String);
Begin
  If CurTokType <> T Then
    ParseError(What + ' attendu, trouve ' + TokenName(CurTokType));
  If CurTokType <> TOK_EOF Then LexNextToken;
End;

Function AddClass(Name: String; IsInterface: Boolean): Integer;
Begin
  If ClassCount >= MAX_CLASS Then
    FatalError('trop de classes/interfaces (limite ' + ItoS(MAX_CLASS) + ')');
  Inc(ClassCount);
  Classes[ClassCount].Name        := Name;
  Classes[ClassCount].IsInterface := IsInterface;
  Classes[ClassCount].ParentName  := '';
  Classes[ClassCount].ParentIdx   := 0;
  Classes[ClassCount].ImplStart   := ImplementsCount + 1;
  Classes[ClassCount].ImplCount   := 0;
  Classes[ClassCount].FieldStart  := FieldCount + 1;
  Classes[ClassCount].FieldCount  := 0;
  Classes[ClassCount].MethodStart := MethodCount + 1;
  Classes[ClassCount].MethodCount := 0;
  Classes[ClassCount].VTableStart := 0;
  Classes[ClassCount].VTableCount := 0;
  AddClass := ClassCount;
End;

Procedure AddImplements(ClassIdx: Integer; IName: String);
Begin
  If ImplementsCount >= MAX_IMPLEMENTS_TOTAL Then
    FatalError('trop d''interfaces implementees');
  Inc(ImplementsCount);
  Implements[ImplementsCount].Name        := IName;
  Implements[ImplementsCount].ResolvedIdx := 0;
  Inc(Classes[ClassIdx].ImplCount);
End;

Procedure AddField(ClassIdx: Integer; TypeName, FName: String;
                    IsArray: Boolean; ArraySize: Integer);
Begin
  If FieldCount >= MAX_FIELD_TOTAL Then
    FatalError('trop de champs declares (limite ' + ItoS(MAX_FIELD_TOTAL) + ')');
  Inc(FieldCount);
  Fields[FieldCount].ClassIdx  := ClassIdx;
  Fields[FieldCount].Name      := FName;
  Fields[FieldCount].TypeName  := TypeName;
  Fields[FieldCount].IsArray   := IsArray;
  Fields[FieldCount].ArraySize := ArraySize;
  Inc(Classes[ClassIdx].FieldCount);
End;

Function AddMethod(ClassIdx: Integer; RetType, MName: String;
                    Visibility: Integer; IsStatic: Boolean): Integer;
Begin
  If MethodCount >= MAX_METHOD Then
    FatalError('trop de methodes declarees (limite ' + ItoS(MAX_METHOD) + ')');
  Inc(MethodCount);
  Methods[MethodCount].ClassIdx   := ClassIdx;
  Methods[MethodCount].Name       := MName;
  Methods[MethodCount].RetType    := RetType;
  Methods[MethodCount].Visibility := Visibility;
  Methods[MethodCount].IsStatic   := IsStatic;
  Methods[MethodCount].IsCtor     := MName = 'new';
  Methods[MethodCount].IsDelegate := False;
  Methods[MethodCount].ParamStart := ParamCount + 1;
  Methods[MethodCount].ParamCount := 0;
  Methods[MethodCount].LocalStart := LocalCount + 1;
  Methods[MethodCount].LocalCount := 0;
  Methods[MethodCount].BodyStmt   := 0;
  Methods[MethodCount].IsVariadic := False;
  Inc(Classes[ClassIdx].MethodCount);
  AddMethod := MethodCount;
End;

Procedure AddParam(MIdx: Integer; TypeName, PName: String);
Begin
  If ParamCount >= MAX_PARAM_TOTAL Then
    FatalError('trop de parametres declares (limite ' + ItoS(MAX_PARAM_TOTAL) + ')');
  Inc(ParamCount);
  Params[ParamCount].Name     := PName;
  Params[ParamCount].TypeName := TypeName;
  Inc(Methods[MIdx].ParamCount);
End;

{ Type de base (mot-cle) ou nom de classe/interface (identificateur) }
Function ParseTypeName: String;
Var T: String;
Begin
  Case CurTokType Of
    KW_INT:       T := 'int';
    KW_REAL:      T := 'real';
    KW_STR:       T := 'str';
    KW_BOOLEAN:   T := 'boolean';
    KW_DATE:      T := 'date';
    KW_GUID:      T := 'guid';
    KW_ANYTYPE:   T := 'anytype';
    KW_CONTAINER: T := 'container';
    KW_VOID:      T := 'void';
    TOK_IDENT:    T := CurTokStr;
  Else
    Begin
      ParseError('type attendu, trouve ' + TokenName(CurTokType));
      T := 'int';
    End;
  End;
  If CurTokType <> TOK_EOF Then LexNextToken;
  ParseTypeName := T;
End;

{ Nom de champ ou de methode : un identificateur normal, ou le
  mot-cle new pour le constructeur }
Function ParseMemberName: String;
Begin
  If CurTokType = KW_NEW Then Begin
    ParseMemberName := 'new';
    LexNextToken;
  End Else If CurTokType = TOK_IDENT Then Begin
    ParseMemberName := CurTokStr;
    LexNextToken;
  End Else Begin
    ParseError('nom de champ ou de methode attendu, trouve ' +
               TokenName(CurTokType));
    ParseMemberName := '';
  End;
End;

{ Zero ou plusieurs modificateurs, dans n'importe quel ordre }
Procedure ParseModifiers(Var IsStatic: Boolean; Var Visibility: Integer);
Begin
  IsStatic   := False;
  Visibility := KW_PUBLIC;   { visibilite par defaut en X++ }
  While (CurTokType = KW_PUBLIC) Or (CurTokType = KW_PRIVATE) Or
        (CurTokType = KW_PROTECTED) Or (CurTokType = KW_STATIC) Do Begin
    If CurTokType = KW_STATIC Then IsStatic := True
    Else Visibility := CurTokType;
    LexNextToken;
  End;
End;

{ Le corps d'une methode : le brace ouvrant a deja ete consomme par
  l'appelant. ScanMethodBody (TODO 08, plus bas) reconnait les
  declarations de variables locales et ignore le reste tel quel,
  en attendant un vrai parseur d'instructions (TODO 10 a 12). }

{ Abonnements delegate -> gestionnaire (TODO 17), extraits de
  l'attribut [SubscribesTo(classStr(Classe), delegateStr(Classe, Nom))]
  au-dessus d'une methode. La resolution (existence du delegate,
  compatibilite de signature) se fait une fois le programme entier
  analyse : voir ResolveSubscriptions. }
Const
  MAX_SUBSCRIPTION = {$IFDEF FPC}512{$ELSE}64{$ENDIF};

Type
  TSubscription = Record
    TargetClassName:  String;
    DelegateName:     String;
    SubscriberMethod: Integer;   { indice dans Methods du gestionnaire }
  End;
  TSubscriptionTable = Array[1..MAX_SUBSCRIPTION] Of TSubscription;

Var
  Subscriptions:     TSubscriptionTable;
  SubscriptionCount: Integer;

Procedure AddSubscription(ClassNameStr, DelegateNameStr: String; MethodIdx: Integer);
Begin
  If SubscriptionCount >= MAX_SUBSCRIPTION Then
    FatalError('trop d''abonnements SubscribesTo (limite ' +
               ItoS(MAX_SUBSCRIPTION) + ')');
  Inc(SubscriptionCount);
  Subscriptions[SubscriptionCount].TargetClassName  := ClassNameStr;
  Subscriptions[SubscriptionCount].DelegateName     := DelegateNameStr;
  Subscriptions[SubscriptionCount].SubscriberMethod := MethodIdx;
End;

Procedure ParseParam(MIdx: Integer);
Var PType, PName: String;
Begin
  PType := ParseTypeName;
  If CurTokType = TOK_IDENT Then Begin
    PName := CurTokStr;
    LexNextToken;
  End Else Begin
    ParseError('nom de parametre attendu, trouve ' + TokenName(CurTokType));
    PName := '';
  End;
  AddParam(MIdx, PType, PName);
End;

{ Suffixe de tableau fixe optionnel apres un nom : Type Nom[N] ; les
  crochets ne s'appliquent qu'au nom qui les precede immediatement }
Procedure ParseArraySuffix(Var IsArray: Boolean; Var ArraySize: Integer);
Begin
  IsArray   := False;
  ArraySize := 0;
  If CurTokType = Ord('[') Then Begin
    LexNextToken;
    IsArray := True;
    If CurTokType = TOK_INTEGER Then Begin
      ArraySize := CurTokNum;
      LexNextToken;
    End Else
      ParseError('taille de tableau (entier) attendue, trouve ' +
                 TokenName(CurTokType));
    Expect(Ord(']'), ']');
    If ArraySize <= 0 Then
      ParseError('taille de tableau invalide (doit etre superieure a 0)');
  End;
End;

{ Champ : TypeName deja lu, Name est le premier nom ; accepte une
  liste separee par des virgules partageant le meme type, chaque nom
  pouvant recevoir son propre suffixe de tableau fixe }
Procedure ParseFieldRest(ClassIdx: Integer; TypeName, FirstName: String);
Var
  CurName:   String;
  IsArr:     Boolean;
  ArrSize:   Integer;
Begin
  CurName := FirstName;
  ParseArraySuffix(IsArr, ArrSize);
  AddField(ClassIdx, TypeName, CurName, IsArr, ArrSize);
  While AcceptTok(Ord(',')) Do Begin
    If CurTokType = TOK_IDENT Then Begin
      CurName := CurTokStr;
      LexNextToken;
      ParseArraySuffix(IsArr, ArrSize);
      AddField(ClassIdx, TypeName, CurName, IsArr, ArrSize);
    End Else
      ParseError('nom de champ attendu, trouve ' + TokenName(CurTokType));
  End;
  Expect(Ord(';'), ';');
End;

{ Methode : parametres entre parentheses, puis soit une simple
  signature terminee par ; (interface), soit un corps ignore.
  Renvoie l'indice de la methode ajoutee (utilise par TODO 17 pour
  rattacher un eventuel abonnement SubscribesTo). }
Function ParseMethodRest(ClassIdx: Integer; Visibility: Integer;
                          IsStatic: Boolean; RetType, Name: String): Integer;
Var MIdx: Integer;
Begin
  MIdx := AddMethod(ClassIdx, RetType, Name, Visibility, IsStatic);
  Expect(Ord('('), '(');
  If CurTokType <> Ord(')') Then Begin
    ParseParam(MIdx);
    While AcceptTok(Ord(',')) Do ParseParam(MIdx);
  End;
  Expect(Ord(')'), ')');
  If CurTokType = Ord(';') Then
    LexNextToken   { signature seule : methode d'interface }
  Else Begin
    Expect(Ord('{'), '{');
    ScanMethodBody(MIdx);
  End;
  ParseMethodRest := MIdx;
End;

{ Membre de classe/interface : attribut optionnel, delegate, ou
  membre normal (champ ou methode) selon ce qui suit le type/nom }
Procedure ParseMember(ClassIdx: Integer);
Var
  IsStatic:     Boolean;
  Visibility:   Integer;
  TypeName:     String;
  Name:         String;
  MIdx:         Integer;
  HasSubscribe: Boolean;
  SubClassName, SubDelegateName: String;
Begin
  HasSubscribe := False;
  If CurTokType = Ord('[') Then
    ParseAttribute(HasSubscribe, SubClassName, SubDelegateName);

  If CurTokType = KW_DELEGATE Then Begin
    LexNextToken;
    TypeName := ParseTypeName;
    Name     := ParseMemberName;
    MIdx     := AddMethod(ClassIdx, TypeName, Name, KW_PUBLIC, False);
    Methods[MIdx].IsDelegate := True;
    Expect(Ord('('), '(');
    If CurTokType <> Ord(')') Then Begin
      ParseParam(MIdx);
      While AcceptTok(Ord(',')) Do ParseParam(MIdx);
    End;
    Expect(Ord(')'), ')');
    Expect(Ord('{'), '{');
    ScanMethodBody(MIdx);
    If HasSubscribe Then
      ParseError('SubscribesTo sur un delegate n''a pas de sens (il faut ' +
                 'l''appliquer au gestionnaire qui s''y abonne)');
    Exit;
  End;

  ParseModifiers(IsStatic, Visibility);
  TypeName := ParseTypeName;
  Name     := ParseMemberName;

  If CurTokType = Ord('(') Then Begin
    MIdx := ParseMethodRest(ClassIdx, Visibility, IsStatic, TypeName, Name);
    If HasSubscribe Then AddSubscription(SubClassName, SubDelegateName, MIdx);
  End Else Begin
    ParseFieldRest(ClassIdx, TypeName, Name);
    If HasSubscribe Then
      ParseError('SubscribesTo ne peut s''appliquer qu''a une methode, pas a un champ');
  End;
End;

{ class Nom [extends Parent] [implements I1, I2, ...] suivi d'un bloc
  de membres, ou interface Nom suivi d'un bloc de signatures }
Procedure ParseClassOrInterface;
Var
  IsInterface: Boolean;
  ClassIdx:    Integer;
  Name:        String;
Begin
  IsInterface := CurTokType = KW_INTERFACE;
  If (CurTokType <> KW_CLASS) And (CurTokType <> KW_INTERFACE) Then Begin
    ParseError('class ou interface attendu, trouve ' + TokenName(CurTokType));
    LexNextToken;
    Exit;
  End;
  LexNextToken;   { consomme class / interface }

  If CurTokType = TOK_IDENT Then Begin
    Name := CurTokStr;
    LexNextToken;
  End Else Begin
    ParseError('nom de classe/interface attendu, trouve ' +
               TokenName(CurTokType));
    Name := '';
  End;

  ClassIdx := AddClass(Name, IsInterface);

  If CurTokType = KW_EXTENDS Then Begin
    LexNextToken;
    If CurTokType = TOK_IDENT Then Begin
      Classes[ClassIdx].ParentName := CurTokStr;
      LexNextToken;
    End Else
      ParseError('nom de classe parente attendu, trouve ' +
                 TokenName(CurTokType));
  End;

  If CurTokType = KW_IMPLEMENTS Then Begin
    LexNextToken;
    If CurTokType = TOK_IDENT Then Begin
      AddImplements(ClassIdx, CurTokStr);
      LexNextToken;
    End Else
      ParseError('nom d''interface attendu, trouve ' + TokenName(CurTokType));
    While AcceptTok(Ord(',')) Do Begin
      If CurTokType = TOK_IDENT Then Begin
        AddImplements(ClassIdx, CurTokStr);
        LexNextToken;
      End Else
        ParseError('nom d''interface attendu, trouve ' + TokenName(CurTokType));
    End;
  End;

  Expect(Ord('{'), '{');
  While (CurTokType <> Ord('}')) And (CurTokType <> TOK_EOF) Do
    ParseMember(ClassIdx);
  Expect(Ord('}'), '}');
End;

{ Point d'entree du parseur : une suite de class / interface }
Procedure ParseProgram;
Begin
  ClassCount      := 0;
  FieldCount      := 0;
  MethodCount     := 0;
  ParamCount      := 0;
  ImplementsCount := 0;
  EnumCount       := 0;
  EnumValueCount  := 0;
  LocalCount      := 0;
  LoopDepth       := 0;
  SwitchDepth     := 0;
  TtsDepth        := 0;
  SubscriptionCount := 0;
  ParseErrors     := 0;
  RegisterBuiltinEnums;
  RegisterBuiltinTables;
  RegisterBuiltinQueryClasses;
  RegisterBuiltinCollectionClasses;
  RegisterBuiltinRuntimeFuncs;
  LexInit(Opt.SrcFile);
  LexNextToken;
  While CurTokType <> TOK_EOF Do Begin
    If CurTokType = KW_ENUM Then ParseEnumDecl
    Else ParseClassOrInterface;
  End;
  LexClose;
End;

{ Recapitulatif lisible des classes/interfaces analysees (mode -v) }
Procedure DumpClasses;
Var
  I, J, Base: Integer;
Begin
  For I := 1 To ClassCount Do Begin
    If Classes[I].IsInterface Then Write('interface ')
    Else Write('class ');
    Write(Classes[I].Name);
    If Classes[I].ParentName <> '' Then Begin
      Write(' extends ', Classes[I].ParentName);
      If Classes[I].ParentIdx = 0 Then Write(' (non resolu)');
    End;
    Base := Classes[I].ImplStart;
    For J := 0 To Classes[I].ImplCount - 1 Do Begin
      If J = 0 Then Write(' implements ') Else Write(', ');
      Write(Implements[Base + J].Name);
      If Implements[Base + J].ResolvedIdx = 0 Then Write(' (non resolu)');
    End;
    WriteLn;

    Base := Classes[I].FieldStart;
    For J := 0 To Classes[I].FieldCount - 1 Do Begin
      Write('    champ   ', Fields[Base + J].TypeName, ' ', Fields[Base + J].Name);
      If Fields[Base + J].IsArray Then Write('[', Fields[Base + J].ArraySize, ']');
      Write(' (offset instance=', Fields[Base + J].InstanceOffset, ')');
      WriteLn;
    End;

    Base := Classes[I].MethodStart;
    For J := 0 To Classes[I].MethodCount - 1 Do Begin
      Write('    methode ', KeywordName(Methods[Base + J].Visibility), ' ');
      If Methods[Base + J].IsStatic Then Write('static ');
      If Methods[Base + J].IsDelegate Then Write('delegate ');
      Write(Methods[Base + J].RetType, ' ', Methods[Base + J].Name,
            ' (', Methods[Base + J].ParamCount, ' parametre(s))');
      If Methods[Base + J].IsCtor Then Write(' [constructeur]');
      WriteLn;
    End;
  End;
End;

{ ============================================================ }
{ TODO 06 - TABLE DES SYMBOLES ET PORTEES                       }
{ ============================================================ }

Const
  MEMBER_NONE   = 0;
  MEMBER_FIELD  = 1;
  MEMBER_METHOD = 2;

{ Portee globale : recherche une classe/interface par son nom
  (0 si introuvable) }
Function FindClass(Name: String): Integer;
Var I: Integer;
Begin
  FindClass := 0;
  For I := 1 To ClassCount Do
    If Classes[I].Name = Name Then Begin
      FindClass := I;
      Exit;
    End;
End;

{ Portee de classe, avec heritage : recherche un champ ou une methode
  en remontant la chaine extends (soi-meme d'abord, puis les ancetres) }
{ ParentIdx n'est calcule qu'apres l'analyse complete du programme
  (ResolveExtends, TODO 06). Comme la resolution d'appels (TODO 13)
  se fait pendant l'analyse (avant que ce calcul n'ait eu lieu), on
  retrouve ici le parent a la demande par son nom quand ParentIdx
  n'est pas encore renseigne, pour que l'heritage fonctionne des le
  premier passage tant que la classe parente est deja declaree. }
Function EffectiveParentIdx(ClassIdx: Integer): Integer;
Begin
  If Classes[ClassIdx].ParentIdx <> 0 Then
    EffectiveParentIdx := Classes[ClassIdx].ParentIdx
  Else If Classes[ClassIdx].ParentName <> '' Then
    EffectiveParentIdx := FindClass(Classes[ClassIdx].ParentName)
  Else
    EffectiveParentIdx := 0;
End;

Function FindMemberInChain(ClassIdx: Integer; Name: String;
                            Var OwnerClass, MemberIdx: Integer): Integer;
Var
  Cur, I, Base, Steps: Integer;
Begin
  FindMemberInChain := MEMBER_NONE;
  OwnerClass := 0;
  MemberIdx  := 0;
  Cur   := ClassIdx;
  Steps := 0;
  While (Cur <> 0) And (Steps <= ClassCount) Do Begin
    Base := Classes[Cur].FieldStart;
    For I := 0 To Classes[Cur].FieldCount - 1 Do
      If Fields[Base + I].Name = Name Then Begin
        FindMemberInChain := MEMBER_FIELD;
        OwnerClass := Cur;
        MemberIdx  := Base + I;
        Exit;
      End;
    Base := Classes[Cur].MethodStart;
    For I := 0 To Classes[Cur].MethodCount - 1 Do
      If Methods[Base + I].Name = Name Then Begin
        FindMemberInChain := MEMBER_METHOD;
        OwnerClass := Cur;
        MemberIdx  := Base + I;
        Exit;
      End;
    Cur := EffectiveParentIdx(Cur);
    Inc(Steps);
  End;
End;

{ Detecte les classes/interfaces declarees plus d'une fois }
Procedure CheckDuplicateClasses;
Var I, J: Integer;
Begin
  For I := 1 To ClassCount Do
    For J := I + 1 To ClassCount Do
      If Classes[I].Name = Classes[J].Name Then
        ParseError('classe/interface "' + Classes[J].Name + '" deja declaree');
End;

{ Champs et methodes en double au sein d'une meme classe ; champs et
  methodes partagent le meme espace de noms (X++ ne surcharge pas) }
Procedure CheckDuplicateMembers(ClassIdx: Integer);
Var
  I, J, FBase, MBase: Integer;
Begin
  FBase := Classes[ClassIdx].FieldStart;
  MBase := Classes[ClassIdx].MethodStart;

  For I := 0 To Classes[ClassIdx].FieldCount - 1 Do
    For J := I + 1 To Classes[ClassIdx].FieldCount - 1 Do
      If Fields[FBase + I].Name = Fields[FBase + J].Name Then
        ParseError('champ "' + Fields[FBase + J].Name + '" de "' +
                   Classes[ClassIdx].Name + '" deja declare');

  For I := 0 To Classes[ClassIdx].MethodCount - 1 Do
    For J := I + 1 To Classes[ClassIdx].MethodCount - 1 Do
      If Methods[MBase + I].Name = Methods[MBase + J].Name Then
        ParseError('methode "' + Methods[MBase + J].Name + '" de "' +
                   Classes[ClassIdx].Name + '" deja declaree ' +
                   '(X++ ne supporte pas la surcharge)');

  For I := 0 To Classes[ClassIdx].FieldCount - 1 Do
    For J := 0 To Classes[ClassIdx].MethodCount - 1 Do
      If Fields[FBase + I].Name = Methods[MBase + J].Name Then
        ParseError('"' + Fields[FBase + I].Name + '" de "' +
                   Classes[ClassIdx].Name +
                   '" designe a la fois un champ et une methode');
End;

{ Resout extends : doit exister, etre une classe (pas une interface).
  La detection de cycle se fait a part, une fois tout resolu. }
Procedure ResolveExtends(ClassIdx: Integer);
Var ParentIdx: Integer;
Begin
  If Classes[ClassIdx].ParentName = '' Then Exit;

  ParentIdx := FindClass(Classes[ClassIdx].ParentName);
  If ParentIdx = 0 Then Begin
    ParseError('classe parente "' + Classes[ClassIdx].ParentName +
               '" inconnue (extends de "' + Classes[ClassIdx].Name + '")');
    Exit;
  End;
  If Classes[ParentIdx].IsInterface Then Begin
    ParseError('"' + Classes[ClassIdx].ParentName +
               '" est une interface, extends attend une classe (dans "' +
               Classes[ClassIdx].Name + '")');
    Exit;
  End;
  Classes[ClassIdx].ParentIdx := ParentIdx;
End;

{ Detecte les cycles d'heritage une fois tous les ParentIdx resolus }
Procedure CheckInheritanceCycles;
Var I, Cur, Steps: Integer;
Begin
  For I := 1 To ClassCount Do Begin
    Cur   := Classes[I].ParentIdx;
    Steps := 0;
    While (Cur <> 0) And (Steps <= ClassCount) Do Begin
      If Cur = I Then Begin
        ParseError('heritage circulaire detecte sur "' + Classes[I].Name + '"');
        Classes[I].ParentIdx := 0;   { coupe le cycle pour la suite }
        Cur := 0;
      End Else Begin
        Cur := Classes[Cur].ParentIdx;
        Inc(Steps);
      End;
    End;
  End;
End;

{ Resout implements : chaque nom doit exister et designer une
  interface (pas une classe) }
Procedure ResolveImplements(ClassIdx: Integer);
Var I, IfaceIdx, Base: Integer;
Begin
  Base := Classes[ClassIdx].ImplStart;
  For I := 0 To Classes[ClassIdx].ImplCount - 1 Do Begin
    IfaceIdx := FindClass(Implements[Base + I].Name);
    If IfaceIdx = 0 Then
      ParseError('interface "' + Implements[Base + I].Name +
                 '" inconnue (implements de "' + Classes[ClassIdx].Name + '")')
    Else If Not Classes[IfaceIdx].IsInterface Then
      ParseError('"' + Implements[Base + I].Name +
                 '" n''est pas une interface (implements de "' +
                 Classes[ClassIdx].Name + '")')
    Else
      Implements[Base + I].ResolvedIdx := IfaceIdx;
  End;
End;

{ Passe semantique complete sur le resultat du parseur (TODO 05) :
  portees, heritage, implements et doublons. La verification que
  toutes les methodes d'une interface sont bien implementees viendra
  avec TODO 15 ; la resolution des membres references dans le corps
  des methodes viendra avec TODO 09 et suivants (expressions), une
  fois que SkipMethodBody sera remplace par un vrai parseur de bloc. }
Procedure ResolveProgram;
Var I: Integer;
Begin
  CheckDuplicateClasses;
  For I := 1 To ClassCount Do ResolveExtends(I);
  CheckInheritanceCycles;
  For I := 1 To ClassCount Do ResolveImplements(I);
  For I := 1 To ClassCount Do CheckDuplicateMembers(I);
End;

{ ============================================================ }
{ TODO 07 - TYPES COMPOSES : TABLEAUX, CONTAINERS, ENUMS        }
{ ============================================================ }

{ Les tableaux fixes (Type Nom[N]) sont geres directement dans les
  champs via ParseArraySuffix/AddField (voir TODO 05, plus haut).
  Le type container est deja reconnu comme type de base depuis
  TODO 04 (KW_CONTAINER) ; ses operations (+=, con2Str, conLen,
  conPeek, conIns, conDel) sont des expressions et seront traitees
  avec les expressions (TODO 09) et le runtime (TODO 23). Cette
  section ajoute la derniere piece : la declaration d'enum. }

Function AddEnum(Name: String): Integer;
Begin
  If EnumCount >= MAX_ENUM Then
    FatalError('trop d''enums declares (limite ' + ItoS(MAX_ENUM) + ')');
  Inc(EnumCount);
  Enums[EnumCount].Name       := Name;
  Enums[EnumCount].ValueStart := EnumValueCount + 1;
  Enums[EnumCount].ValueCount := 0;
  AddEnum := EnumCount;
End;

Procedure AddEnumValue(EnumIdx: Integer; Name: String; Ordinal: Integer);
Begin
  If EnumValueCount >= MAX_ENUM_VALUE Then
    FatalError('trop de valeurs d''enum declarees (limite ' +
               ItoS(MAX_ENUM_VALUE) + ')');
  Inc(EnumValueCount);
  EnumValues[EnumValueCount].Name    := Name;
  EnumValues[EnumValueCount].Ordinal := Ordinal;
  Inc(Enums[EnumIdx].ValueCount);
End;

Function FindEnum(Name: String): Integer;
Var I: Integer;
Begin
  FindEnum := 0;
  For I := 1 To EnumCount Do
    If Enums[I].Name = Name Then Begin
      FindEnum := I;
      Exit;
    End;
End;

{ Cherche une valeur nommee au sein d'un enum donne (utilise plus
  tard par la resolution de Enum::Valeur, TODO 09) }
Function FindEnumValue(EnumIdx: Integer; Name: String;
                        Var Ordinal: Integer): Boolean;
Var I, Base: Integer;
Begin
  FindEnumValue := False;
  Ordinal := 0;
  Base := Enums[EnumIdx].ValueStart;
  For I := 0 To Enums[EnumIdx].ValueCount - 1 Do
    If EnumValues[Base + I].Name = Name Then Begin
      Ordinal := EnumValues[Base + I].Ordinal;
      FindEnumValue := True;
      Exit;
    End;
End;

{ enum Nom suivi d'un bloc de valeurs separees par des virgules ;
  chaque valeur peut fixer explicitement son ordinal entre
  parentheses (sinon incrementation automatique a partir de 0) }
Procedure ParseEnumDecl;
Var
  Name:        String;
  EnumIdx:     Integer;
  NextOrdinal: Integer;
  ValName:     String;
  Ordinal:     Integer;
Begin
  LexNextToken;   { consomme enum }

  If CurTokType = TOK_IDENT Then Begin
    Name := CurTokStr;
    LexNextToken;
  End Else Begin
    ParseError('nom d''enum attendu, trouve ' + TokenName(CurTokType));
    Name := '';
  End;

  EnumIdx := AddEnum(Name);
  Expect(Ord('{'), '{');

  NextOrdinal := 0;
  If CurTokType <> Ord('}') Then
    While True Do Begin
      If CurTokType = TOK_IDENT Then Begin
        ValName := CurTokStr;
        LexNextToken;
      End Else Begin
        ParseError('nom de valeur d''enum attendu, trouve ' +
                   TokenName(CurTokType));
        ValName := '';
      End;

      Ordinal := NextOrdinal;
      If CurTokType = Ord('(') Then Begin
        LexNextToken;
        If CurTokType = TOK_INTEGER Then Begin
          Ordinal := CurTokNum;
          LexNextToken;
        End Else
          ParseError('valeur entiere attendue, trouve ' + TokenName(CurTokType));
        Expect(Ord(')'), ')');
      End;
      NextOrdinal := Ordinal + 1;

      AddEnumValue(EnumIdx, ValName, Ordinal);

      If Not AcceptTok(Ord(',')) Then Break;
      If CurTokType = Ord('}') Then Break;   { virgule finale toleree }
    End;

  Expect(Ord('}'), '}');
End;

Procedure CheckDuplicateEnums;
Var I, J: Integer;
Begin
  For I := 1 To EnumCount Do Begin
    If FindClass(Enums[I].Name) <> 0 Then
      ParseError('enum "' + Enums[I].Name +
                 '" porte le meme nom qu''une classe/interface');
    For J := I + 1 To EnumCount Do
      If Enums[I].Name = Enums[J].Name Then
        ParseError('enum "' + Enums[J].Name + '" deja declare');
  End;
End;

Procedure CheckDuplicateEnumValues(EnumIdx: Integer);
Var I, J, Base: Integer;
Begin
  Base := Enums[EnumIdx].ValueStart;
  For I := 0 To Enums[EnumIdx].ValueCount - 1 Do
    For J := I + 1 To Enums[EnumIdx].ValueCount - 1 Do
      If EnumValues[Base + I].Name = EnumValues[Base + J].Name Then
        ParseError('valeur "' + EnumValues[Base + J].Name +
                   '" de l''enum "' + Enums[EnumIdx].Name +
                   '" deja declaree');
End;

Procedure ResolveEnums;
Var I: Integer;
Begin
  CheckDuplicateEnums;
  For I := 1 To EnumCount Do CheckDuplicateEnumValues(I);
End;

{ Recapitulatif lisible des enums analyses (mode -v) }
Procedure DumpEnums;
Var I, J, Base: Integer;
Begin
  For I := 1 To EnumCount Do Begin
    WriteLn('enum ', Enums[I].Name);
    Base := Enums[I].ValueStart;
    For J := 0 To Enums[I].ValueCount - 1 Do
      WriteLn('    valeur  ', EnumValues[Base + J].Name, ' = ',
              EnumValues[Base + J].Ordinal);
  End;
End;

{ ============================================================ }
{ TODO 08 - VARIABLES, CONSTANTES ET ALLOCATION                 }
{ ============================================================ }

Const
  { Tailles en octets utilisees pour les offsets EBP (locales) et les
    offsets d'instance (champs), modele plat 80386 }
  SIZE_INT       = 4;
  SIZE_REAL      = 8;
  SIZE_BOOLEAN   = 4;
  SIZE_STR       = 4;    { reference vers une chaine allouee sur le tas }
  SIZE_DATE      = 4;    { entier : nombre de jours }
  SIZE_GUID      = 16;
  SIZE_ANYTYPE   = 8;    { valeur etiquetee : tag + donnee/pointeur }
  SIZE_CONTAINER = 4;    { reference vers un container aloue sur le tas }
  SIZE_OBJREF    = 4;    { reference vers une instance de classe/interface }
  OBJECT_HEADER_SIZE = 4;   { pointeur de table de methodes virtuelles }

Type
  { Sauvegarde/restauration de l'etat du lexeur, pour un lookahead
    d'un token sans perturber le flux principal }
  TLexState = Record
    LexPos:      LongInt;
    LexLine:     LongInt;
    LexCol:      LongInt;
    CurTokType:  Integer;
    CurTokStr:   String;
    CurTokNum:   LongInt;
    CurTokFloat: Double;
    CurTokLine:  LongInt;
    CurTokCol:   LongInt;
    LastTokType: Integer;
  End;

Var
  { Methode dont le corps est en cours d'analyse ; utilise par
    ResolveIdentType (TODO 09) pour retrouver le type declare d'un
    identificateur (locale, parametre ou champ) dans une expression }
  CurParsingMethod: Integer;

Const
  { Noeuds de l'arbre d'expressions (TODO 09), declares ici car
    ParseLocalInitializer (juste plus bas) construit deja des
    expressions completes pour les initialiseurs de variables locales }
  NK_NONE      = 0;
  NK_LIT_INT   = 1;
  NK_LIT_FLOAT = 2;
  NK_LIT_STR   = 3;
  NK_LIT_CHAR  = 4;
  NK_LIT_DATE  = 5;
  NK_LIT_BOOL  = 6;
  NK_IDENT     = 7;   { locale, parametre, champ ou classe : resolu par ResolveIdentType }
  NK_THIS      = 8;
  NK_SUPER     = 9;
  NK_UNARY     = 10;  { operateur unaire prefixe : - + ! ~ ++ -- }
  NK_POSTOP    = 11;  { ++ / -- postfixe }
  NK_BINARY    = 12;  { operateur binaire arithmetique/logique/bit/comparaison }
  NK_ASSIGN    = 13;  { = += -= *= /= }
  NK_MEMBER    = 14;  { a.b }
  NK_INDEX     = 15;  { a[i] }
  NK_CALL      = 16;  { a(args) }
  NK_NEW       = 17;  { new Type(args) }
  NK_ENUMVAL   = 18;  { Enum::Valeur }
  NK_CONTLIT   = 19;  { [elem, elem, ...] : litteral container }

  MAX_IR_NODE = {$IFDEF FPC}8192{$ELSE}512{$ENDIF};

Type
  TIRNode = Record
    Kind:     Integer;
    Tok:      Integer;    { operateur (TOK_xxx/Ord(caractere)) ou type de litteral }
    Text:     String;     { identificateur, texte de litteral chaine/char/date/enum }
    NumVal:   LongInt;    { valeur entiere/booleenne/ordinale }
    FloatVal: Double;     { valeur reelle }
    Left:     Integer;    { operande gauche / objet / operande unaire / callee }
    Right:    Integer;    { operande droit / indice / premier argument }
    NextArg:  Integer;    { argument suivant dans un appel ou un new(...) }
    TypeName: String;     { type infere de l'expression }
    Line:     Integer;
    ShortCircuit: Boolean;   { ajoute par TODO 10 : && / || decides par
                               la seule operande gauche constante }
    ResolvedMethod: Integer; { ajoute par TODO 24 : indice Methods de la
                               cible resolue d'un NK_CALL/NK_NEW, 0 sinon }
  End;
  TIRTable = Array[1..MAX_IR_NODE] Of TIRNode;

Var
  IRNodes: TIRTable;
  IRCount: Integer;

Const
  { Arbre d'instructions (TODO 10), declare ici car ParseLocalVarDecl
    (juste plus bas) construit deja des noeuds de declaration pour
    s'inserer dans la sequence d'instructions d'un bloc }
  SK_NONE    = 0;
  SK_BLOCK   = 1;
  SK_EXPR    = 2;
  SK_EMPTY   = 3;
  SK_IF      = 4;
  SK_VARDECL = 5;
  SK_SWITCH   = 6;   { ajoute par TODO 11 }
  SK_CASE     = 7;   { ajoute par TODO 11 : etiquette case/default }
  SK_WHILE    = 8;   { ajoute par TODO 12 }
  SK_DOWHILE  = 9;   { ajoute par TODO 12 }
  SK_FOR      = 10;  { ajoute par TODO 12 }
  SK_BREAK    = 11;  { ajoute par TODO 12 }
  SK_CONTINUE = 12;  { ajoute par TODO 12 }
  SK_RETURN   = 13;  { ajoute par TODO 13 }
  SK_TRY      = 14;  { ajoute par TODO 16 }
  SK_CATCH    = 15;  { ajoute par TODO 16 }
  SK_THROW    = 16;  { ajoute par TODO 16 }
  SK_WHILESELECT = 17;  { ajoute par TODO 19 : while select ... suivi d'un bloc }
  SK_SELECT      = 18;  { ajoute par TODO 19 : select ... ; }
  SK_TTSBEGIN    = 19;  { ajoute par TODO 20 }
  SK_TTSCOMMIT   = 20;  { ajoute par TODO 20 }
  SK_TTSABORT    = 21;  { ajoute par TODO 20 }
  SK_DELETEFROM  = 22;  { ajoute par TODO 20 : delete_from ... ; (SelectVar/ExprNode reutilises) }

  MAX_STMT_NODE = {$IFDEF FPC}8192{$ELSE}512{$ENDIF};

Type
  TStmtNode = Record
    Kind:       Integer;
    ExprNode:   Integer;   { SK_EXPR/SK_SWITCH/SK_WHILE/SK_DOWHILE/SK_FOR/SK_THROW : expression ;
                             SK_IF/SK_CASE : condition/valeur ; SK_CATCH : type attrape, 0 si generique ;
                             SK_WHILESELECT/SK_SELECT : condition where, 0 si absente }
    LocalIdx:   Integer;   { SK_VARDECL : indice dans Locals }
    FirstChild: Integer;   { SK_BLOCK/SK_SWITCH : premiere instruction du bloc/corps ;
                             SK_TRY : premier SK_CATCH, chaine via NextStmt }
    NextStmt:   Integer;   { instruction suivante dans le bloc englobant }
    ThenStmt:   Integer;   { SK_IF }
    ElseStmt:   Integer;   { SK_IF, 0 si absent }
    IsDefault:  Boolean;   { SK_CASE : etiquette default plutot que case }
    BodyStmt:   Integer;   { corps de SK_WHILE/SK_DOWHILE/SK_FOR/SK_TRY/SK_CATCH/SK_WHILESELECT }
    ForInit:    Integer;   { ajoute par TODO 12 : instruction d'initialisation du for, 0 si absente }
    ForIncr:    Integer;   { ajoute par TODO 12 : expression d'increment du for, 0 si absente }
    FinallyStmt: Integer;  { ajoute par TODO 16 : bloc finally d'un SK_TRY, 0 si absent }
    SelectVar:   Integer;  { ajoute par TODO 19 : noeud IR de la variable de table }
    OrderByHead: Integer;  { ajoute par TODO 19 : premier champ order by, chaine via NextArg }
    ForUpdate:   Boolean;  { ajoute par TODO 19 : select forUpdate }
    Line:       Integer;
  End;
  TStmtTable = Array[1..MAX_STMT_NODE] Of TStmtNode;

Var
  Stmts:     TStmtTable;
  StmtCount: Integer;

Function NewStmtNode(Kind: Integer): Integer;
Begin
  If StmtCount >= MAX_STMT_NODE Then
    FatalError('trop de noeuds d''instruction (limite ' + ItoS(MAX_STMT_NODE) + ')');
  Inc(StmtCount);
  Stmts[StmtCount].Kind       := Kind;
  Stmts[StmtCount].ExprNode   := 0;
  Stmts[StmtCount].LocalIdx   := 0;
  Stmts[StmtCount].FirstChild := 0;
  Stmts[StmtCount].NextStmt   := 0;
  Stmts[StmtCount].ThenStmt   := 0;
  Stmts[StmtCount].ElseStmt   := 0;
  Stmts[StmtCount].IsDefault  := False;
  Stmts[StmtCount].BodyStmt   := 0;
  Stmts[StmtCount].ForInit    := 0;
  Stmts[StmtCount].ForIncr    := 0;
  Stmts[StmtCount].FinallyStmt := 0;
  Stmts[StmtCount].SelectVar   := 0;
  Stmts[StmtCount].OrderByHead := 0;
  Stmts[StmtCount].ForUpdate   := False;
  Stmts[StmtCount].Line       := CurTokLine;
  NewStmtNode := StmtCount;
End;

Procedure SaveLexState(Var S: TLexState);
Begin
  S.LexPos      := LexPos;
  S.LexLine     := LexLine;
  S.LexCol      := LexCol;
  S.CurTokType  := CurTokType;
  S.CurTokStr   := CurTokStr;
  S.CurTokNum   := CurTokNum;
  S.CurTokFloat := CurTokFloat;
  S.CurTokLine  := CurTokLine;
  S.CurTokCol   := CurTokCol;
  S.LastTokType := LastTokType;
End;

Procedure RestoreLexState(Var S: TLexState);
Begin
  LexPos      := S.LexPos;
  LexLine     := S.LexLine;
  LexCol      := S.LexCol;
  CurTokType  := S.CurTokType;
  CurTokStr   := S.CurTokStr;
  CurTokNum   := S.CurTokNum;
  CurTokFloat := S.CurTokFloat;
  CurTokLine  := S.CurTokLine;
  CurTokCol   := S.CurTokCol;
  LastTokType := S.LastTokType;
End;

{ Lookahead d'un token, sans consommer le token courant }
Function PeekNextTokenType: Integer;
Var Saved: TLexState;
Begin
  SaveLexState(Saved);
  LexNextToken;
  PeekNextTokenType := CurTokType;
  RestoreLexState(Saved);
End;

{ Taille de stockage d'un type, utilisee pour les offsets EBP et les
  offsets d'instance ; toute identificateur non reconnu est traite
  comme une reference d'objet (classe/interface) sur 32 bits }
Function TypeSize(TypeName: String): Integer;
Begin
  If      TypeName = 'int'       Then TypeSize := SIZE_INT
  Else If TypeName = 'real'      Then TypeSize := SIZE_REAL
  Else If TypeName = 'boolean'   Then TypeSize := SIZE_BOOLEAN
  Else If TypeName = 'str'       Then TypeSize := SIZE_STR
  Else If TypeName = 'date'      Then TypeSize := SIZE_DATE
  Else If TypeName = 'guid'      Then TypeSize := SIZE_GUID
  Else If TypeName = 'anytype'   Then TypeSize := SIZE_ANYTYPE
  Else If TypeName = 'container' Then TypeSize := SIZE_CONTAINER
  Else If TypeName = 'void'      Then TypeSize := 0
  Else TypeSize := SIZE_OBJREF;
End;

{ Description lisible de la valeur par defaut d'un type, quand aucun
  initialiseur n'est fourni }
Function DefaultValueDesc(TypeName: String): String;
Begin
  If      TypeName = 'int'       Then DefaultValueDesc := '0'
  Else If TypeName = 'real'      Then DefaultValueDesc := '0.0'
  Else If TypeName = 'boolean'   Then DefaultValueDesc := 'false'
  Else If TypeName = 'str'       Then DefaultValueDesc := '"" (chaine vide)'
  Else If TypeName = 'date'      Then DefaultValueDesc := 'date nulle'
  Else If TypeName = 'guid'      Then DefaultValueDesc := 'guid nul'
  Else If TypeName = 'anytype'   Then DefaultValueDesc := 'undefined'
  Else If TypeName = 'container' Then DefaultValueDesc := '[] (vide)'
  Else DefaultValueDesc := 'null';
End;

{ Une declaration ressemble a Type Nom si le token courant est un
  mot-cle de type de base, ou si deux identificateurs se suivent
  (Type Nom ou Type est le nom d'une classe/interface) }
Function LooksLikeVarDecl: Boolean;
Begin
  Case CurTokType Of
    KW_INT, KW_REAL, KW_STR, KW_BOOLEAN, KW_DATE, KW_GUID,
    KW_ANYTYPE, KW_CONTAINER:
      LooksLikeVarDecl := True;
    TOK_IDENT:
      LooksLikeVarDecl := PeekNextTokenType = TOK_IDENT;
  Else
    LooksLikeVarDecl := False;
  End;
End;

Function AddLocalVar(MIdx: Integer; TypeName, LName: String;
                      IsArray: Boolean; ArraySize: Integer): Integer;
Begin
  If LocalCount >= MAX_LOCAL_TOTAL Then
    FatalError('trop de variables locales declarees (limite ' +
               ItoS(MAX_LOCAL_TOTAL) + ')');
  Inc(LocalCount);
  Locals[LocalCount].MethodIdx := MIdx;
  Locals[LocalCount].Name      := LName;
  Locals[LocalCount].TypeName  := TypeName;
  Locals[LocalCount].IsArray   := IsArray;
  Locals[LocalCount].ArraySize := ArraySize;
  Locals[LocalCount].Offset    := 0;   { calcule par ComputeLocalOffsets }
  Locals[LocalCount].HasInit   := False;
  Locals[LocalCount].ExprNode  := 0;
  Locals[LocalCount].InitType  := '';
  Inc(Methods[MIdx].LocalCount);
  AddLocalVar := LocalCount;
End;

{ Initialiseur d'une variable locale : un vrai parseur d'expressions
  (TODO 09) construit maintenant un noeud IR complet, quel que soit
  la complexite (litteral simple ou expression riche avec appels,
  new, operateurs...). Comme ParseExpression consomme exactement les
  tokens de l'expression (parentheses/crochets compris), la virgule
  ou le point-virgule qui suit est deja le bon delimiteur. }
Procedure ParseLocalInitializer(LIdx: Integer);
Var ExprIdx: Integer;
Begin
  ExprIdx := ParseExpression;
  Locals[LIdx].HasInit  := True;
  Locals[LIdx].ExprNode := ExprIdx;
  Locals[LIdx].InitType := IRNodes[ExprIdx].TypeName;
End;

{ Type Nom[N] = Init, Nom2[N2] = Init2, ... ; chaque nom peut avoir
  son propre suffixe de tableau et son propre initialiseur. Renvoie
  la premiere instruction SK_VARDECL d'une chaine (une par nom
  declare), reliees par NextStmt, pour s'inserer dans un bloc
  (TODO 10) comme n'importe quelle autre instruction. }
Function ParseLocalVarDecl(MIdx: Integer): Integer;
Var
  TypeName: String;
  Name:     String;
  IsArr:    Boolean;
  ArrSize:  Integer;
  LIdx:     Integer;
  Head, Tail, S: Integer;
Begin
  TypeName := ParseTypeName;
  Head := 0;
  Tail := 0;
  Repeat
    If CurTokType = TOK_IDENT Then Begin
      Name := CurTokStr;
      LexNextToken;
    End Else Begin
      ParseError('nom de variable attendu, trouve ' + TokenName(CurTokType));
      Name := '';
    End;
    ParseArraySuffix(IsArr, ArrSize);
    LIdx := AddLocalVar(MIdx, TypeName, Name, IsArr, ArrSize);
    If CurTokType = Ord('=') Then Begin
      LexNextToken;
      ParseLocalInitializer(LIdx);
    End;
    S := NewStmtNode(SK_VARDECL);
    Stmts[S].LocalIdx := LIdx;
    If Head = 0 Then Head := S Else Stmts[Tail].NextStmt := S;
    Tail := S;
  Until Not AcceptTok(Ord(','));
  Expect(Ord(';'), ';');
  ParseLocalVarDecl := Head;
End;

{ Corps d'une methode : le brace ouvrant a deja ete consomme par
  l'appelant. Le corps reel de ScanMethodBody est defini en TODO 10,
  plus bas, une fois le parseur d'instructions disponible. }

{ Offsets d'instance des champs d'une classe, recursif sur extends :
  chaque classe racine reserve l'entete d'objet (pointeur de table de
  methodes virtuelles), les classes derivees ajoutent leurs propres
  champs apres ceux de leur parent. Renvoie la taille totale. }
Function ComputeInstanceLayout(ClassIdx: Integer): Integer;
Var
  BaseSize, I, Base, FSize: Integer;
Begin
  If Classes[ClassIdx].ParentIdx <> 0 Then
    BaseSize := ComputeInstanceLayout(Classes[ClassIdx].ParentIdx)
  Else
    BaseSize := OBJECT_HEADER_SIZE;

  Base := Classes[ClassIdx].FieldStart;
  For I := 0 To Classes[ClassIdx].FieldCount - 1 Do Begin
    FSize := TypeSize(Fields[Base + I].TypeName);
    If Fields[Base + I].IsArray Then FSize := FSize * Fields[Base + I].ArraySize;
    Fields[Base + I].InstanceOffset := BaseSize;
    BaseSize := BaseSize + FSize;
  End;
  ComputeInstanceLayout := BaseSize;
End;

{ Offsets EBP des variables locales d'une methode : premiere locale a
  EBP-taille, chacune suivante empilee en dessous }
Procedure ComputeLocalOffsets(MIdx: Integer);
Var
  I, Base, Sz, Running: Integer;
Begin
  Base    := Methods[MIdx].LocalStart;
  Running := 0;
  For I := 0 To Methods[MIdx].LocalCount - 1 Do Begin
    Sz := TypeSize(Locals[Base + I].TypeName);
    If Locals[Base + I].IsArray Then Sz := Sz * Locals[Base + I].ArraySize;
    Running := Running + Sz;
    Locals[Base + I].Offset := -Running;
  End;
End;

{ Une variable locale ne doit pas porter le meme nom qu'une autre
  locale ou qu'un parametre de la meme methode }
Procedure CheckDuplicateLocals(MIdx: Integer);
Var
  I, J, LBase, PBase: Integer;
Begin
  LBase := Methods[MIdx].LocalStart;
  PBase := Methods[MIdx].ParamStart;

  For I := 0 To Methods[MIdx].LocalCount - 1 Do
    For J := I + 1 To Methods[MIdx].LocalCount - 1 Do
      If Locals[LBase + I].Name = Locals[LBase + J].Name Then
        ParseError('variable locale "' + Locals[LBase + J].Name +
                   '" de "' + Methods[MIdx].Name + '" deja declaree');

  For I := 0 To Methods[MIdx].LocalCount - 1 Do
    For J := 0 To Methods[MIdx].ParamCount - 1 Do
      If Locals[LBase + I].Name = Params[PBase + J].Name Then
        ParseError('variable locale "' + Locals[LBase + I].Name +
                   '" masque le parametre du meme nom dans "' +
                   Methods[MIdx].Name + '"');
End;

{ Calcule l'allocation (offsets d'instance et EBP) et verifie les
  doublons, une fois le programme entierement analyse (TODO 05-07) }
Procedure ResolveStorage;
Var I: Integer;
Begin
  For I := 1 To ClassCount Do
    If Not Classes[I].IsInterface Then ComputeInstanceLayout(I);
  For I := 1 To MethodCount Do Begin
    ComputeLocalOffsets(I);
    CheckDuplicateLocals(I);
  End;
End;

{ ============================================================ }
{ TODO 09 - EXPRESSIONS ET OPERATEURS                           }
{ ============================================================ }

{ Les types NK_xxx/TIRNode et la table IRNodes sont declares plus
  haut, dans le bloc Const/Type/Var de TODO 08 : ParseLocalInitializer
  (TODO 08) les utilise deja pour stocker le resultat des expressions
  d'initialisation, donc ils doivent exister avant ce point du fichier. }

Function ParseAssignExpr: Integer; Forward;

Function NewIRNode(Kind: Integer): Integer;
Begin
  If IRCount >= MAX_IR_NODE Then
    FatalError('trop de noeuds d''expression (limite ' + ItoS(MAX_IR_NODE) + ')');
  Inc(IRCount);
  IRNodes[IRCount].Kind     := Kind;
  IRNodes[IRCount].Tok      := 0;
  IRNodes[IRCount].Text     := '';
  IRNodes[IRCount].NumVal   := 0;
  IRNodes[IRCount].FloatVal := 0;
  IRNodes[IRCount].Left     := 0;
  IRNodes[IRCount].Right    := 0;
  IRNodes[IRCount].NextArg  := 0;
  IRNodes[IRCount].TypeName := 'anytype';
  IRNodes[IRCount].Line     := CurTokLine;
  IRNodes[IRCount].ShortCircuit := False;
  IRNodes[IRCount].ResolvedMethod := 0;
  NewIRNode := IRCount;
End;

{ Symbole imprimable d'un operateur/litteral, pour le mode debug }
Function TokenSymbol(Tok: Integer): String;
Begin
  Case Tok Of
    TOK_EQ:      TokenSymbol := '==';
    TOK_NE:      TokenSymbol := '!=';
    TOK_LE:      TokenSymbol := '<=';
    TOK_GE:      TokenSymbol := '>=';
    TOK_ANDAND:  TokenSymbol := '&&';
    TOK_OROR:    TokenSymbol := '||';
    TOK_SHL:     TokenSymbol := '<<';
    TOK_SHR:     TokenSymbol := '>>';
    TOK_INCR:    TokenSymbol := '++';
    TOK_DECR:    TokenSymbol := '--';
    TOK_PLUSEQ:  TokenSymbol := '+=';
    TOK_MINUSEQ: TokenSymbol := '-=';
    TOK_STAREQ:  TokenSymbol := '*=';
    TOK_SLASHEQ: TokenSymbol := '/=';
    KW_DIV:      TokenSymbol := 'div';
    KW_MOD:      TokenSymbol := 'mod';
  Else
    If (Tok > 0) And (Tok < 128) Then TokenSymbol := Chr(Tok)
    Else TokenSymbol := '?';
  End;
End;

{ Promotion de type simple pour les operateurs arithmetiques :
  int et real se combinent en real, deux types identiques se
  conservent, toute autre combinaison retombe sur anytype }
Function PromoteType(T1, T2: String): String;
Begin
  If (T1 = 'real') Or (T2 = 'real') Then PromoteType := 'real'
  Else If (T1 = 'int') And (T2 = 'int') Then PromoteType := 'int'
  Else If T1 = T2 Then PromoteType := T1
  Else PromoteType := 'anytype';
End;

{ Type declare d'un identificateur simple, cherche dans les locales
  et parametres de la methode en cours (TODO 08), puis dans les
  champs de sa classe en remontant l'heritage (TODO 06) }
Function ResolveIdentType(Name: String): String;
Var
  I, Base, OwnerCls, MemberIdx, Kind: Integer;
Begin
  ResolveIdentType := 'anytype';
  If CurParsingMethod = 0 Then Exit;

  Base := Methods[CurParsingMethod].LocalStart;
  For I := 0 To Methods[CurParsingMethod].LocalCount - 1 Do
    If Locals[Base + I].Name = Name Then Begin
      ResolveIdentType := Locals[Base + I].TypeName;
      Exit;
    End;

  Base := Methods[CurParsingMethod].ParamStart;
  For I := 0 To Methods[CurParsingMethod].ParamCount - 1 Do
    If Params[Base + I].Name = Name Then Begin
      ResolveIdentType := Params[Base + I].TypeName;
      Exit;
    End;

  Kind := FindMemberInChain(Methods[CurParsingMethod].ClassIdx, Name,
                             OwnerCls, MemberIdx);
  If Kind = MEMBER_FIELD Then
    ResolveIdentType := Fields[MemberIdx].TypeName
  Else If Kind = MEMBER_METHOD Then
    ResolveIdentType := Methods[MemberIdx].RetType;
End;

{ Le nom d'un membre est normalement un identificateur, mais insert/
  update/delete/select restent utilisables comme noms de methode sur
  un buffer de table (custGroup.insert(), custGroup.update()...),
  comme en X++ reel : ce sont des mots-cles reserves uniquement en
  position d'instruction, pas apres un point }
Function ParseMemberAccess(Obj: Integer): Integer;
Var
  N: Integer;
  MName: String;
  AotTableIdx, AotFieldIdx: Integer;
Begin
  If (CurTokType = TOK_IDENT) Or (CurTokType = KW_INSERT) Or
     (CurTokType = KW_UPDATE) Or (CurTokType = KW_DELETE) Or
     (CurTokType = KW_SELECT) Then Begin
    MName := CurTokStr;
    LexNextToken;
  End Else Begin
    ParseError('nom de membre attendu, trouve ' + TokenName(CurTokType));
    MName := '';
  End;
  N := NewIRNode(NK_MEMBER);
  IRNodes[N].Left     := Obj;
  IRNodes[N].Text     := MName;
  IRNodes[N].TypeName := 'anytype';   { resolution complete avec TODO 13 }

  { Si l'objet est une table AOT simulee connue (TODO 18) et que le
    nom designe un de ses champs, on retrouve le vrai type du champ ;
    un champ non modelise (notre AOT est volontairement minimal)
    reste anytype sans erreur, plutot que de rejeter du code valide }
  AotTableIdx := FindAotTable(IRNodes[Obj].TypeName);
  If AotTableIdx <> 0 Then Begin
    AotFieldIdx := FindAotField(AotTableIdx, MName);
    If AotFieldIdx <> 0 Then IRNodes[N].TypeName := AotFieldTypeName(AotFieldIdx);
  End;

  ParseMemberAccess := N;
End;

Function ParseIndex(Obj: Integer): Integer;
Var N, Idx: Integer;
Begin
  Idx := ParseExpression;
  Expect(Ord(']'), ']');
  N := NewIRNode(NK_INDEX);
  IRNodes[N].Left     := Obj;
  IRNodes[N].Right    := Idx;
  IRNodes[N].TypeName := IRNodes[Obj].TypeName;
  ParseIndex := N;
End;

{ Resout la cible d'un appel quand c'est possible : nom simple
  (implicitement this.Nom) ou obj.Nom lorsque le type statique de obj
  est une classe/interface declaree dans ce programme. Ne rapporte
  rien si la cible n'a pas ete resolue (fonction globale du runtime,
  table ou classe AOT externe...) : voir TODO 13. }
Function ParseCall(Callee: Integer): Integer;
Var
  N, ArgHead, ArgTail, ArgNode: Integer;
  OwnerCls, MemberIdx, Kind, TargetClass: Integer;
  CalleeName: String;
Begin
  ArgHead := 0;
  If CurTokType <> Ord(')') Then Begin
    ArgHead := ParseAssignExpr;
    ArgTail := ArgHead;
    While AcceptTok(Ord(',')) Do Begin
      ArgNode := ParseAssignExpr;
      IRNodes[ArgTail].NextArg := ArgNode;
      ArgTail := ArgNode;
    End;
  End;
  Expect(Ord(')'), ')');
  N := NewIRNode(NK_CALL);
  IRNodes[N].Left     := Callee;
  IRNodes[N].Right    := ArgHead;
  IRNodes[N].TypeName := 'anytype';

  { tableNum(Table) et fieldNum(Table, Champ) sont des pseudo-appels
    resolus au moment de la compilation contre le modele de table AOT
    simule (TODO 18), pas des methodes ordinaires }
  If (IRNodes[Callee].Kind = NK_IDENT) And (IRNodes[Callee].Text = 'tableNum') Then Begin
    ResolveTableNumCall(N, ArgHead);
    ParseCall := N;
    Exit;
  End Else If (IRNodes[Callee].Kind = NK_IDENT) And (IRNodes[Callee].Text = 'fieldNum') Then Begin
    ResolveFieldNumCall(N, ArgHead);
    ParseCall := N;
    Exit;
  End;

  Kind := MEMBER_NONE;
  CalleeName := '';
  If IRNodes[Callee].Kind = NK_IDENT Then Begin
    CalleeName := IRNodes[Callee].Text;
    If CurParsingMethod <> 0 Then
      Kind := FindMemberInChain(Methods[CurParsingMethod].ClassIdx, CalleeName,
                                 OwnerCls, MemberIdx);
    { pas une methode de la classe courante (ni heritee) : peut-etre
      une fonction runtime native globale (TODO 23), ex. strFmt/info }
    If (Kind = MEMBER_NONE) And (GlobalFuncClassIdx <> 0) Then
      Kind := FindMemberInChain(GlobalFuncClassIdx, CalleeName, OwnerCls, MemberIdx);
  End Else If IRNodes[Callee].Kind = NK_MEMBER Then Begin
    CalleeName := IRNodes[Callee].Text;
    TargetClass := FindClass(IRNodes[IRNodes[Callee].Left].TypeName);
    If TargetClass <> 0 Then
      Kind := FindMemberInChain(TargetClass, CalleeName, OwnerCls, MemberIdx)
    Else If FindAotTable(IRNodes[IRNodes[Callee].Left].TypeName) <> 0 Then Begin
      { methodes de buffer de table standard, simulees (TODO 20) :
        insert/update/delete/clear n'existent dans aucune classe
        utilisateur, elles sont reconnues directement ici }
      If (CalleeName = 'insert') Or (CalleeName = 'update') Or
         (CalleeName = 'delete') Or (CalleeName = 'clear') Then Begin
        If ArgHead <> 0 Then
          ParseError('"' + CalleeName +
                     '" ne prend pas d''argument sur un buffer de table');
        IRNodes[N].TypeName := 'void';
      End;
    End;
  End Else If IRNodes[Callee].Kind = NK_SUPER Then Begin
    { super(args) : appel explicite au constructeur de la classe parente }
    CalleeName := 'new';
    TargetClass := FindClass(IRNodes[Callee].TypeName);
    If TargetClass <> 0 Then
      Kind := FindMemberInChain(TargetClass, 'new', OwnerCls, MemberIdx);
  End;

  If Kind = MEMBER_METHOD Then Begin
    IRNodes[N].TypeName := Methods[MemberIdx].RetType;
    IRNodes[N].ResolvedMethod := MemberIdx;   { utilise par le codegen, TODO 24 }
    CheckCallArgs(MemberIdx, ArgHead, '"' + CalleeName + '"');

    { QueryRun.get(tableNum(X)) (TODO 21) : le type de retour reel
      depend de la table demandee, pas seulement de la signature
      generique (anytype) de get() }
    If (CalleeName = 'get') And (ArgHead <> 0) And
       (IRNodes[ArgHead].Kind = NK_CALL) And
       (IRNodes[ArgHead].TypeName = 'int') And
       (IRNodes[IRNodes[ArgHead].Left].Kind = NK_IDENT) And
       (IRNodes[IRNodes[ArgHead].Left].Text = 'tableNum') Then
      IRNodes[N].TypeName := AotTableName(IRNodes[ArgHead].NumVal);
  End;

  ParseCall := N;
End;

{ new Type(args) : le type de l'expression est Type lui-meme, pas un
  type de retour d'appel ordinaire }
Function ParseNewExpr: Integer;
Var
  N, ArgHead, ArgTail, ArgNode: Integer;
  ClassIdx, CtorIdx, OwnerCls, Kind: Integer;
  TypeNameStr: String;
Begin
  LexNextToken;   { consomme new }
  If CurTokType = TOK_IDENT Then Begin
    TypeNameStr := CurTokStr;
    LexNextToken;
  End Else Begin
    ParseError('nom de classe attendu apres new, trouve ' + TokenName(CurTokType));
    TypeNameStr := '';
  End;

  ArgHead := 0;
  If CurTokType = Ord('(') Then Begin
    LexNextToken;
    If CurTokType <> Ord(')') Then Begin
      ArgHead := ParseAssignExpr;
      ArgTail := ArgHead;
      While AcceptTok(Ord(',')) Do Begin
        ArgNode := ParseAssignExpr;
        IRNodes[ArgTail].NextArg := ArgNode;
        ArgTail := ArgNode;
      End;
    End;
    Expect(Ord(')'), ')');
  End;

  N := NewIRNode(NK_NEW);
  IRNodes[N].Text     := TypeNameStr;
  IRNodes[N].Right    := ArgHead;
  IRNodes[N].TypeName := TypeNameStr;

  { Verification d'arite/types du constructeur (TODO 13), uniquement
    pour les classes declarees dans ce programme ; un constructeur
    herite (via extends) est trouve normalement par FindMemberInChain.
    Si aucun constructeur explicite n'existe, le constructeur implicite
    n'accepte aucun argument. }
  ClassIdx := FindClass(TypeNameStr);
  If ClassIdx <> 0 Then Begin
    Kind := FindMemberInChain(ClassIdx, 'new', OwnerCls, CtorIdx);
    If Kind = MEMBER_METHOD Then Begin
      IRNodes[N].ResolvedMethod := CtorIdx;   { utilise par le codegen, TODO 24 }
      CheckCallArgs(CtorIdx, ArgHead, 'le constructeur de "' + TypeNameStr + '"');
    End
    Else If CountCallArgs(ArgHead) > 0 Then
      ParseError('"' + TypeNameStr +
                 '" n''a pas de constructeur acceptant des arguments');
  End;

  ParseNewExpr := N;
End;

{ Identificateur simple, ou Enum::Valeur }
Function ParseIdentOrEnum: Integer;
Var
  Name:    String;
  N:       Integer;
  EnumIdx: Integer;
  Ordinal: Integer;
Begin
  Name := CurTokStr;
  LexNextToken;

  If CurTokType = TOK_COLONCOLON Then Begin
    LexNextToken;
    EnumIdx := FindEnum(Name);
    N := NewIRNode(NK_ENUMVAL);
    If CurTokType = TOK_IDENT Then Begin
      IRNodes[N].Text := Name + '::' + CurTokStr;
      If EnumIdx <> 0 Then Begin
        If FindEnumValue(EnumIdx, CurTokStr, Ordinal) Then
          IRNodes[N].NumVal := Ordinal
        Else
          ParseError('valeur "' + CurTokStr + '" inconnue dans l''enum "' +
                     Name + '"');
      End;
      { EnumIdx = 0 : identificateur non declare localement (ex. un
        enum standard de l'AOT comme CustVendorBlocked) ; accepte
        sans verification, hors de portee de ce sous-ensemble }
      LexNextToken;
    End Else
      ParseError('nom de valeur d''enum attendu, trouve ' + TokenName(CurTokType));
    IRNodes[N].TypeName := Name;
    ParseIdentOrEnum := N;
    Exit;
  End;

  N := NewIRNode(NK_IDENT);
  IRNodes[N].Text     := Name;
  IRNodes[N].TypeName := ResolveIdentType(Name);
  ParseIdentOrEnum := N;
End;

{ [elem, elem, ...] : litteral container, elements chaines via NextArg
  comme les arguments d'un appel }
Function ParseContainerLit: Integer;
Var N, ElemHead, ElemTail, Elem: Integer;
Begin
  LexNextToken;   { consomme [ }
  ElemHead := 0;
  If CurTokType <> Ord(']') Then Begin
    ElemHead := ParseAssignExpr;
    ElemTail := ElemHead;
    While AcceptTok(Ord(',')) Do Begin
      Elem := ParseAssignExpr;
      IRNodes[ElemTail].NextArg := Elem;
      ElemTail := Elem;
    End;
  End;
  Expect(Ord(']'), ']');
  N := NewIRNode(NK_CONTLIT);
  IRNodes[N].Right    := ElemHead;
  IRNodes[N].TypeName := 'container';
  ParseContainerLit := N;
End;

Function ParsePrimary: Integer;
Var N: Integer;
Begin
  Case CurTokType Of
    TOK_INTEGER: Begin
      N := NewIRNode(NK_LIT_INT);
      IRNodes[N].NumVal   := CurTokNum;
      IRNodes[N].TypeName := 'int';
      LexNextToken;
    End;
    TOK_FLOAT: Begin
      N := NewIRNode(NK_LIT_FLOAT);
      IRNodes[N].Text     := CurTokStr;
      IRNodes[N].FloatVal := CurTokFloat;
      IRNodes[N].TypeName := 'real';
      LexNextToken;
    End;
    TOK_STRING: Begin
      N := NewIRNode(NK_LIT_STR);
      IRNodes[N].Text     := CurTokStr;
      IRNodes[N].TypeName := 'str';
      LexNextToken;
    End;
    TOK_CHAR: Begin
      N := NewIRNode(NK_LIT_CHAR);
      IRNodes[N].Text     := CurTokStr;
      IRNodes[N].TypeName := 'str';
      LexNextToken;
    End;
    TOK_DATELIT: Begin
      N := NewIRNode(NK_LIT_DATE);
      IRNodes[N].Text     := CurTokStr;
      IRNodes[N].TypeName := 'date';
      LexNextToken;
    End;
    KW_TRUE, KW_FALSE: Begin
      N := NewIRNode(NK_LIT_BOOL);
      If CurTokType = KW_TRUE Then IRNodes[N].NumVal := 1 Else IRNodes[N].NumVal := 0;
      IRNodes[N].TypeName := 'boolean';
      LexNextToken;
    End;
    KW_THIS: Begin
      { le type de "this" est la classe en cours d'analyse (TODO 17),
        pour que this.methode(...) se resolve comme n'importe quel
        appel obj.methode(...) }
      N := NewIRNode(NK_THIS);
      IRNodes[N].TypeName := 'anytype';
      If CurParsingMethod <> 0 Then
        IRNodes[N].TypeName := Classes[Methods[CurParsingMethod].ClassIdx].Name;
      LexNextToken;
    End;
    KW_SUPER: Begin
      { le type de "super" est la classe parente de la classe en
        cours d'analyse (TODO 14), pour que super.methode() et
        super(...) se resolvent comme un appel sur cette classe }
      N := NewIRNode(NK_SUPER);
      IRNodes[N].TypeName := 'anytype';
      If CurParsingMethod <> 0 Then Begin
        IRNodes[N].TypeName := Classes[Methods[CurParsingMethod].ClassIdx].ParentName;
        If IRNodes[N].TypeName = '' Then IRNodes[N].TypeName := 'anytype';
      End;
      LexNextToken;
    End;
    KW_NEW:
      N := ParseNewExpr;
    TOK_IDENT:
      N := ParseIdentOrEnum;
  Else
    If CurTokType = Ord('(') Then Begin
      LexNextToken;
      N := ParseExpression;
      Expect(Ord(')'), ')');
    End Else If CurTokType = Ord('[') Then Begin
      N := ParseContainerLit;
    End Else Begin
      ParseError('expression attendue, trouve ' + TokenName(CurTokType));
      N := NewIRNode(NK_NONE);
      If CurTokType <> TOK_EOF Then LexNextToken;
    End;
  End;
  ParsePrimary := N;
End;

Function ParsePostfix: Integer;
Var N, P: Integer;
Begin
  N := ParsePrimary;
  While True Do Begin
    If CurTokType = Ord('.') Then Begin
      LexNextToken;
      N := ParseMemberAccess(N);
    End Else If CurTokType = Ord('[') Then Begin
      LexNextToken;
      N := ParseIndex(N);
    End Else If CurTokType = Ord('(') Then Begin
      LexNextToken;
      N := ParseCall(N);
    End Else If (CurTokType = TOK_INCR) Or (CurTokType = TOK_DECR) Then Begin
      P := NewIRNode(NK_POSTOP);
      IRNodes[P].Tok      := CurTokType;
      IRNodes[P].Left     := N;
      IRNodes[P].TypeName := IRNodes[N].TypeName;
      LexNextToken;
      N := P;
      Break;
    End Else
      Break;
  End;
  ParsePostfix := N;
End;

Function ParseUnary: Integer;
Var N, Sub: Integer; Op: Integer;
Begin
  If (CurTokType = Ord('-')) Or (CurTokType = Ord('+')) Or
     (CurTokType = Ord('!')) Or (CurTokType = Ord('~')) Or
     (CurTokType = TOK_INCR) Or (CurTokType = TOK_DECR) Then Begin
    Op := CurTokType;
    LexNextToken;
    Sub := ParseUnary;
    N := NewIRNode(NK_UNARY);
    IRNodes[N].Tok  := Op;
    IRNodes[N].Left := Sub;
    If Op = Ord('!') Then IRNodes[N].TypeName := 'boolean'
    Else IRNodes[N].TypeName := IRNodes[Sub].TypeName;
    ParseUnary := N;
  End Else
    ParseUnary := ParsePostfix;
End;

Function ParseMultiplicative: Integer;
Var Left, Right, N, Op: Integer;
Begin
  Left := ParseUnary;
  While (CurTokType = Ord('*')) Or (CurTokType = Ord('/')) Or
        (CurTokType = KW_DIV) Or (CurTokType = KW_MOD) Do Begin
    Op := CurTokType;
    LexNextToken;
    Right := ParseUnary;
    N := NewIRNode(NK_BINARY);
    IRNodes[N].Tok   := Op;
    IRNodes[N].Left  := Left;
    IRNodes[N].Right := Right;
    If (Op = KW_DIV) Or (Op = KW_MOD) Then
      IRNodes[N].TypeName := 'int'
    Else
      IRNodes[N].TypeName := PromoteType(IRNodes[Left].TypeName, IRNodes[Right].TypeName);
    Left := N;
  End;
  ParseMultiplicative := Left;
End;

Function ParseAdditive: Integer;
Var Left, Right, N, Op: Integer;
Begin
  Left := ParseMultiplicative;
  While (CurTokType = Ord('+')) Or (CurTokType = Ord('-')) Do Begin
    Op := CurTokType;
    LexNextToken;
    Right := ParseMultiplicative;
    N := NewIRNode(NK_BINARY);
    IRNodes[N].Tok   := Op;
    IRNodes[N].Left  := Left;
    IRNodes[N].Right := Right;
    If (Op = Ord('+')) And
       ((IRNodes[Left].TypeName = 'str') Or (IRNodes[Right].TypeName = 'str')) Then
      IRNodes[N].TypeName := 'str'
    Else
      IRNodes[N].TypeName := PromoteType(IRNodes[Left].TypeName, IRNodes[Right].TypeName);
    Left := N;
  End;
  ParseAdditive := Left;
End;

Function ParseShift: Integer;
Var Left, Right, N, Op: Integer;
Begin
  Left := ParseAdditive;
  While (CurTokType = TOK_SHL) Or (CurTokType = TOK_SHR) Do Begin
    Op := CurTokType;
    LexNextToken;
    Right := ParseAdditive;
    N := NewIRNode(NK_BINARY);
    IRNodes[N].Tok      := Op;
    IRNodes[N].Left     := Left;
    IRNodes[N].Right    := Right;
    IRNodes[N].TypeName := 'int';
    Left := N;
  End;
  ParseShift := Left;
End;

Function ParseRelational: Integer;
Var Left, Right, N, Op: Integer;
Begin
  Left := ParseShift;
  While (CurTokType = Ord('<')) Or (CurTokType = Ord('>')) Or
        (CurTokType = TOK_LE) Or (CurTokType = TOK_GE) Do Begin
    Op := CurTokType;
    LexNextToken;
    Right := ParseShift;
    N := NewIRNode(NK_BINARY);
    IRNodes[N].Tok      := Op;
    IRNodes[N].Left     := Left;
    IRNodes[N].Right    := Right;
    IRNodes[N].TypeName := 'boolean';
    Left := N;
  End;
  ParseRelational := Left;
End;

Function ParseEquality: Integer;
Var Left, Right, N, Op: Integer;
Begin
  Left := ParseRelational;
  While (CurTokType = TOK_EQ) Or (CurTokType = TOK_NE) Do Begin
    Op := CurTokType;
    LexNextToken;
    Right := ParseRelational;
    N := NewIRNode(NK_BINARY);
    IRNodes[N].Tok      := Op;
    IRNodes[N].Left     := Left;
    IRNodes[N].Right    := Right;
    IRNodes[N].TypeName := 'boolean';
    Left := N;
  End;
  ParseEquality := Left;
End;

Function ParseBitAnd: Integer;
Var Left, Right, N: Integer;
Begin
  Left := ParseEquality;
  While CurTokType = Ord('&') Do Begin
    LexNextToken;
    Right := ParseEquality;
    N := NewIRNode(NK_BINARY);
    IRNodes[N].Tok      := Ord('&');
    IRNodes[N].Left     := Left;
    IRNodes[N].Right    := Right;
    IRNodes[N].TypeName := 'int';
    Left := N;
  End;
  ParseBitAnd := Left;
End;

Function ParseBitXor: Integer;
Var Left, Right, N: Integer;
Begin
  Left := ParseBitAnd;
  While CurTokType = Ord('^') Do Begin
    LexNextToken;
    Right := ParseBitAnd;
    N := NewIRNode(NK_BINARY);
    IRNodes[N].Tok      := Ord('^');
    IRNodes[N].Left     := Left;
    IRNodes[N].Right    := Right;
    IRNodes[N].TypeName := 'int';
    Left := N;
  End;
  ParseBitXor := Left;
End;

Function ParseBitOr: Integer;
Var Left, Right, N: Integer;
Begin
  Left := ParseBitXor;
  While CurTokType = Ord('|') Do Begin
    LexNextToken;
    Right := ParseBitXor;
    N := NewIRNode(NK_BINARY);
    IRNodes[N].Tok      := Ord('|');
    IRNodes[N].Left     := Left;
    IRNodes[N].Right    := Right;
    IRNodes[N].TypeName := 'int';
    Left := N;
  End;
  ParseBitOr := Left;
End;

Function ParseLogicalAnd: Integer;
Var Left, Right, N: Integer; SCVal: Boolean;
Begin
  Left := ParseBitOr;
  While CurTokType = TOK_ANDAND Do Begin
    LexNextToken;
    Right := ParseBitOr;
    N := NewIRNode(NK_BINARY);
    IRNodes[N].Tok      := TOK_ANDAND;
    IRNodes[N].Left     := Left;
    IRNodes[N].Right    := Right;
    IRNodes[N].TypeName := 'boolean';
    IRNodes[N].ShortCircuit := ShortCircuitConst(N, SCVal);
    Left := N;
  End;
  ParseLogicalAnd := Left;
End;

Function ParseLogicalOr: Integer;
Var Left, Right, N: Integer; SCVal: Boolean;
Begin
  Left := ParseLogicalAnd;
  While CurTokType = TOK_OROR Do Begin
    LexNextToken;
    Right := ParseLogicalAnd;
    N := NewIRNode(NK_BINARY);
    IRNodes[N].Tok      := TOK_OROR;
    IRNodes[N].Left     := Left;
    IRNodes[N].Right    := Right;
    IRNodes[N].TypeName := 'boolean';
    IRNodes[N].ShortCircuit := ShortCircuitConst(N, SCVal);
    Left := N;
  End;
  ParseLogicalOr := Left;
End;

{ = += -= *= /= : associatif a droite, priorite la plus basse }
Function ParseAssignExpr: Integer;
Var Left, Right, N, Op: Integer;
Begin
  Left := ParseLogicalOr;
  If (CurTokType = Ord('=')) Or (CurTokType = TOK_PLUSEQ) Or
     (CurTokType = TOK_MINUSEQ) Or (CurTokType = TOK_STAREQ) Or
     (CurTokType = TOK_SLASHEQ) Then Begin
    Op := CurTokType;
    LexNextToken;
    Right := ParseAssignExpr;
    N := NewIRNode(NK_ASSIGN);
    IRNodes[N].Tok      := Op;
    IRNodes[N].Left     := Left;
    IRNodes[N].Right    := Right;
    IRNodes[N].TypeName := IRNodes[Left].TypeName;
    ParseAssignExpr := N;
  End Else
    ParseAssignExpr := Left;
End;

Function ParseExpression: Integer;
Begin
  ParseExpression := ParseAssignExpr;
End;

{ Rendu textuel compact d'une expression, pour verification en mode -v }
Function DescribeExpr(NodeIdx: Integer): String;
Begin
  If NodeIdx = 0 Then Begin
    DescribeExpr := '?';
    Exit;
  End;
  Case IRNodes[NodeIdx].Kind Of
    NK_LIT_INT:   DescribeExpr := ItoS(IRNodes[NodeIdx].NumVal);
    NK_LIT_FLOAT: DescribeExpr := IRNodes[NodeIdx].Text;
    NK_LIT_STR:   DescribeExpr := '"' + IRNodes[NodeIdx].Text + '"';
    NK_LIT_CHAR:  DescribeExpr := '''' + IRNodes[NodeIdx].Text + '''';
    NK_LIT_DATE:  DescribeExpr := '''' + IRNodes[NodeIdx].Text + '''';
    NK_LIT_BOOL:
      If IRNodes[NodeIdx].NumVal <> 0 Then DescribeExpr := 'true'
      Else DescribeExpr := 'false';
    NK_IDENT:   DescribeExpr := IRNodes[NodeIdx].Text;
    NK_THIS:    DescribeExpr := 'this';
    NK_SUPER:   DescribeExpr := 'super';
    NK_ENUMVAL: DescribeExpr := IRNodes[NodeIdx].Text;
    NK_UNARY:
      DescribeExpr := TokenSymbol(IRNodes[NodeIdx].Tok) +
                      DescribeExpr(IRNodes[NodeIdx].Left);
    NK_POSTOP:
      DescribeExpr := DescribeExpr(IRNodes[NodeIdx].Left) +
                      TokenSymbol(IRNodes[NodeIdx].Tok);
    NK_BINARY:
      DescribeExpr := '(' + DescribeExpr(IRNodes[NodeIdx].Left) + ' ' +
                      TokenSymbol(IRNodes[NodeIdx].Tok) + ' ' +
                      DescribeExpr(IRNodes[NodeIdx].Right) + ')';
    NK_ASSIGN:
      DescribeExpr := DescribeExpr(IRNodes[NodeIdx].Left) + ' ' +
                      TokenSymbol(IRNodes[NodeIdx].Tok) + ' ' +
                      DescribeExpr(IRNodes[NodeIdx].Right);
    NK_MEMBER:
      DescribeExpr := DescribeExpr(IRNodes[NodeIdx].Left) + '.' +
                      IRNodes[NodeIdx].Text;
    NK_INDEX:
      DescribeExpr := DescribeExpr(IRNodes[NodeIdx].Left) + '[' +
                      DescribeExpr(IRNodes[NodeIdx].Right) + ']';
    NK_CALL:
      DescribeExpr := DescribeExpr(IRNodes[NodeIdx].Left) + '(...)';
    NK_NEW:
      DescribeExpr := 'new ' + IRNodes[NodeIdx].Text + '(...)';
    NK_CONTLIT:
      DescribeExpr := '[...]';
  Else
    DescribeExpr := '?';
  End;
End;

{ Recapitulatif lisible des variables locales de chaque methode,
  avec offset EBP, type infere et expression d'initialisation
  (litterale ou complexe, defaut sinon) (mode -v) }
Procedure DumpLocals;
Var
  M, I, Base: Integer;
Begin
  For M := 1 To MethodCount Do Begin
    If Methods[M].LocalCount = 0 Then Continue;
    WriteLn('methode ', Methods[M].Name, ' (', Classes[Methods[M].ClassIdx].Name, ')');
    Base := Methods[M].LocalStart;
    For I := 0 To Methods[M].LocalCount - 1 Do Begin
      Write('    locale  ', Locals[Base + I].TypeName, ' ', Locals[Base + I].Name);
      If Locals[Base + I].IsArray Then
        Write('[', Locals[Base + I].ArraySize, ']');
      Write(' (EBP', Locals[Base + I].Offset, ') = ');
      If Not Locals[Base + I].HasInit Then
        Write(DefaultValueDesc(Locals[Base + I].TypeName), ' (defaut)')
      Else
        Write(DescribeExpr(Locals[Base + I].ExprNode),
              ' : ', Locals[Base + I].InitType);
      WriteLn;
    End;
  End;
End;

{ ============================================================ }
{ TODO 10 - INSTRUCTIONS DE BASE ET IF/ELSE                     }
{ ============================================================ }

{ Determine si un && / || est decide par sa seule operande gauche,
  sans avoir besoin d'evaluer la droite (evaluation paresseuse) :
  false && X vaut toujours false, true || X vaut toujours true }
Function ShortCircuitConst(NodeIdx: Integer; Var Value: Boolean): Boolean;
Var LeftIdx: Integer;
Begin
  ShortCircuitConst := False;
  Value := False;
  If IRNodes[NodeIdx].Kind <> NK_BINARY Then Exit;
  LeftIdx := IRNodes[NodeIdx].Left;
  If (LeftIdx = 0) Or (IRNodes[LeftIdx].Kind <> NK_LIT_BOOL) Then Exit;

  If (IRNodes[NodeIdx].Tok = TOK_ANDAND) And (IRNodes[LeftIdx].NumVal = 0) Then Begin
    Value := False;
    ShortCircuitConst := True;
  End Else If (IRNodes[NodeIdx].Tok = TOK_OROR) And (IRNodes[LeftIdx].NumVal <> 0) Then Begin
    Value := True;
    ShortCircuitConst := True;
  End;
End;

Function ParseStatement(MIdx: Integer): Integer; Forward;
Function ParseStmtBlock(MIdx: Integer): Integer; Forward;

{ if (cond) instruction [else instruction] ; "else if" n'est qu'un
  else suivi d'une autre instruction if, geree par la recursion }
Function ParseIfStatement(MIdx: Integer): Integer;
Var
  N, CondExpr, ThenS, ElseS: Integer;
Begin
  LexNextToken;   { consomme if }
  Expect(Ord('('), '(');
  CondExpr := ParseExpression;
  Expect(Ord(')'), ')');
  ThenS := ParseStatement(MIdx);
  ElseS := 0;
  If CurTokType = KW_ELSE Then Begin
    LexNextToken;
    ElseS := ParseStatement(MIdx);
  End;
  N := NewStmtNode(SK_IF);
  Stmts[N].ExprNode := CondExpr;
  Stmts[N].ThenStmt := ThenS;
  Stmts[N].ElseStmt := ElseS;
  ParseIfStatement := N;
End;

{ Avale un "maillon" d'instruction non encore geree, en equilibrant
  parentheses et accolades, jusqu'a un point-virgule ou une accolade
  fermante de niveau 0 }
Procedure SkipStatementChunk;
Var ParenDepth, BraceDepth: Integer;
Begin
  ParenDepth := 0;
  BraceDepth := 0;
  While CurTokType <> TOK_EOF Do Begin
    If CurTokType = Ord('(') Then Begin
      Inc(ParenDepth);
      LexNextToken;
    End Else If CurTokType = Ord(')') Then Begin
      Dec(ParenDepth);
      LexNextToken;
    End Else If CurTokType = Ord('{') Then Begin
      Inc(BraceDepth);
      LexNextToken;
    End Else If CurTokType = Ord('}') Then Begin
      Dec(BraceDepth);
      LexNextToken;
      If (BraceDepth = 0) And (ParenDepth = 0) Then Exit;
    End Else If (CurTokType = Ord(';')) And (ParenDepth = 0) And (BraceDepth = 0) Then Begin
      LexNextToken;
      Exit;
    End Else
      LexNextToken;
  End;
End;

{ Ignore une instruction dont la grammaire n'est pas encore geree
  (while, do, for, switch, try, return, break, continue, tts*,
  select, delete_from...), en suivant les enchainements naturels
  (catch/finally apres try, while apres un do). Chaque construction
  garde ses parentheses et accolades equilibrees, donc l'instruction
  suivante reprend toujours au bon endroit ; le contenu detaille sera
  traite par les TODO consacres (11 : switch, 12 : boucles, etc). }
Function SkipUnknownStatement: Integer;
Begin
  SkipStatementChunk;
  While (CurTokType = KW_ELSE) Or (CurTokType = KW_CATCH) Or
        (CurTokType = KW_FINALLY) Or (CurTokType = KW_WHILE) Do Begin
    LexNextToken;
    SkipStatementChunk;
  End;
  SkipUnknownStatement := NewStmtNode(SK_EMPTY);
End;

{ Une instruction : bloc, vide, if/else, declaration de variable,
  ou instruction-expression (affectation, appel de methode) }
Function ParseStatement(MIdx: Integer): Integer;
Var N: Integer;
Begin
  If CurTokType = Ord('{') Then Begin
    LexNextToken;
    N := ParseStmtBlock(MIdx);
  End Else If CurTokType = Ord(';') Then Begin
    LexNextToken;
    N := NewStmtNode(SK_EMPTY);
  End Else If CurTokType = KW_IF Then
    N := ParseIfStatement(MIdx)
  Else If CurTokType = KW_SWITCH Then
    N := ParseSwitchStatement(MIdx)
  Else If CurTokType = KW_WHILE Then Begin
    { while(cond) est une boucle ; while select ... est la requete
      DSL (TODO 19), distinguees par lookahead }
    If PeekNextTokenType = Ord('(') Then N := ParseWhileStatement(MIdx)
    Else If PeekNextTokenType = KW_SELECT Then N := ParseWhileSelectStatement(MIdx)
    Else N := SkipUnknownStatement;
  End
  Else If CurTokType = KW_DO Then
    N := ParseDoWhileStatement(MIdx)
  Else If CurTokType = KW_FOR Then
    N := ParseForStatement(MIdx)
  Else If CurTokType = KW_BREAK Then
    N := ParseBreakStatement
  Else If CurTokType = KW_CONTINUE Then
    N := ParseContinueStatement
  Else If CurTokType = KW_RETURN Then
    N := ParseReturnStatement(MIdx)
  Else If CurTokType = KW_TRY Then
    N := ParseTryStatement(MIdx)
  Else If CurTokType = KW_THROW Then
    N := ParseThrowStatement(MIdx)
  Else If CurTokType = KW_SELECT Then
    N := ParseSelectStatement
  Else If CurTokType = KW_TTSBEGIN Then
    N := ParseTtsBeginStatement
  Else If CurTokType = KW_TTSCOMMIT Then
    N := ParseTtsCommitStatement
  Else If CurTokType = KW_TTSABORT Then
    N := ParseTtsAbortStatement
  Else If CurTokType = KW_DELETE_FROM Then
    N := ParseDeleteFromStatement
  Else If (CurTokType = TOK_IDENT) And
          ((CurTokStr = 'print') Or (CurTokStr = 'pause')) Then
    { syntaxe heritee d'Axapta 2.x : print "texte" ; et pause ; ne
      sont pas des appels de methode ordinaires (pas de parentheses) }
    N := SkipUnknownStatement
  Else If LooksLikeVarDecl Then
    N := ParseLocalVarDecl(MIdx)
  Else Begin
    N := NewStmtNode(SK_EXPR);
    Stmts[N].ExprNode := ParseExpression;
    Expect(Ord(';'), ';');
  End;
  ParseStatement := N;
End;

{ Bloc d'instructions : l'accolade ouvrante a deja ete consommee par
  l'appelant. Une instruction peut renvoyer plusieurs maillons
  chaines (declarations multi-noms) : on avance jusqu'au dernier
  avant de rattacher l'instruction suivante. }
Function ParseStmtBlock(MIdx: Integer): Integer;
Var Head, Tail, S: Integer;
Begin
  Head := NewStmtNode(SK_BLOCK);
  Tail := 0;
  While (CurTokType <> Ord('}')) And (CurTokType <> TOK_EOF) Do Begin
    S := ParseStatement(MIdx);
    If Tail = 0 Then Stmts[Head].FirstChild := S
    Else Stmts[Tail].NextStmt := S;
    Tail := S;
    While Stmts[Tail].NextStmt <> 0 Do Tail := Stmts[Tail].NextStmt;
  End;
  Expect(Ord('}'), '}');
  ParseStmtBlock := Head;
End;

{ Corps d'une methode : l'accolade ouvrante a deja ete consommee par
  l'appelant (voir TODO 05). Construit desormais un vrai arbre
  d'instructions au lieu de se contenter d'ignorer le contenu.
  Verifie aussi (TODO 20) que ttsBegin/ttsCommit sont equilibres dans
  la methode ; TtsDepth est restaure dans tous les cas pour ne pas
  contaminer l'analyse de la methode suivante en cas de desequilibre. }
Procedure ScanMethodBody(MIdx: Integer);
Var StartTtsDepth: Integer;
Begin
  CurParsingMethod := MIdx;
  StartTtsDepth := TtsDepth;
  Methods[MIdx].BodyStmt := ParseStmtBlock(MIdx);
  If TtsDepth <> StartTtsDepth Then
    ParseError('ttsBegin sans ttsCommit correspondant dans "' + Methods[MIdx].Name + '"');
  TtsDepth := StartTtsDepth;
  CurParsingMethod := 0;
End;

{ Rendu indente d'un arbre d'instructions, pour verification (mode -v) }
Procedure DumpStatement(NodeIdx: Integer; Indent: Integer);
Var
  Pad:   String;
  I, Ch: Integer;
Begin
  If NodeIdx = 0 Then Exit;
  Pad := '';
  For I := 1 To Indent Do Pad := Pad + '  ';
  Case Stmts[NodeIdx].Kind Of
    SK_BLOCK: Begin
      WriteLn(Pad, 'bloc');
      Ch := Stmts[NodeIdx].FirstChild;
      While Ch <> 0 Do Begin
        DumpStatement(Ch, Indent + 1);
        Ch := Stmts[Ch].NextStmt;
      End;
    End;
    SK_EMPTY: WriteLn(Pad, '; (vide ou non geree)');
    SK_VARDECL:
      WriteLn(Pad, 'declaration ', Locals[Stmts[NodeIdx].LocalIdx].TypeName,
              ' ', Locals[Stmts[NodeIdx].LocalIdx].Name);
    SK_EXPR:
      WriteLn(Pad, DescribeExpr(Stmts[NodeIdx].ExprNode), ' ;');
    SK_IF: Begin
      Write(Pad, 'if (', DescribeExpr(Stmts[NodeIdx].ExprNode), ')');
      If IRNodes[Stmts[NodeIdx].ExprNode].ShortCircuit Then
        Write(' [evaluation paresseuse]');
      WriteLn;
      DumpStatement(Stmts[NodeIdx].ThenStmt, Indent + 1);
      If Stmts[NodeIdx].ElseStmt <> 0 Then Begin
        WriteLn(Pad, 'else');
        DumpStatement(Stmts[NodeIdx].ElseStmt, Indent + 1);
      End;
    End;
    SK_SWITCH: Begin
      WriteLn(Pad, 'switch (', DescribeExpr(Stmts[NodeIdx].ExprNode), ')');
      Ch := Stmts[NodeIdx].FirstChild;
      While Ch <> 0 Do Begin
        DumpStatement(Ch, Indent + 1);
        Ch := Stmts[Ch].NextStmt;
      End;
    End;
    SK_CASE:
      If Stmts[NodeIdx].IsDefault Then WriteLn(Pad, 'default:')
      Else WriteLn(Pad, 'case ', DescribeExpr(Stmts[NodeIdx].ExprNode), ':');
    SK_WHILE: Begin
      WriteLn(Pad, 'while (', DescribeExpr(Stmts[NodeIdx].ExprNode), ')');
      DumpStatement(Stmts[NodeIdx].BodyStmt, Indent + 1);
    End;
    SK_DOWHILE: Begin
      WriteLn(Pad, 'do');
      DumpStatement(Stmts[NodeIdx].BodyStmt, Indent + 1);
      WriteLn(Pad, 'while (', DescribeExpr(Stmts[NodeIdx].ExprNode), ')');
    End;
    SK_FOR: Begin
      Write(Pad, 'for (');
      If Stmts[NodeIdx].ForInit = 0 Then Write('-') Else Write('init');
      Write('; ');
      If Stmts[NodeIdx].ExprNode = 0 Then Write('-')
      Else Write(DescribeExpr(Stmts[NodeIdx].ExprNode));
      Write('; ');
      If Stmts[NodeIdx].ForIncr = 0 Then Write('-')
      Else Write(DescribeExpr(Stmts[NodeIdx].ForIncr));
      WriteLn(')');
      If Stmts[NodeIdx].ForInit <> 0 Then
        DumpStatement(Stmts[NodeIdx].ForInit, Indent + 1);
      DumpStatement(Stmts[NodeIdx].BodyStmt, Indent + 1);
    End;
    SK_BREAK:    WriteLn(Pad, 'break ;');
    SK_CONTINUE: WriteLn(Pad, 'continue ;');
    SK_RETURN:
      If Stmts[NodeIdx].ExprNode = 0 Then WriteLn(Pad, 'return ;')
      Else WriteLn(Pad, 'return ', DescribeExpr(Stmts[NodeIdx].ExprNode), ' ;');
    SK_TRY: Begin
      WriteLn(Pad, 'try');
      DumpStatement(Stmts[NodeIdx].BodyStmt, Indent + 1);
      Ch := Stmts[NodeIdx].FirstChild;
      While Ch <> 0 Do Begin
        DumpStatement(Ch, Indent);
        Ch := Stmts[Ch].NextStmt;
      End;
      If Stmts[NodeIdx].FinallyStmt <> 0 Then Begin
        WriteLn(Pad, 'finally');
        DumpStatement(Stmts[NodeIdx].FinallyStmt, Indent + 1);
      End;
    End;
    SK_CATCH: Begin
      If Stmts[NodeIdx].ExprNode = 0 Then WriteLn(Pad, 'catch')
      Else WriteLn(Pad, 'catch (', DescribeExpr(Stmts[NodeIdx].ExprNode), ')');
      DumpStatement(Stmts[NodeIdx].BodyStmt, Indent + 1);
    End;
    SK_THROW:
      WriteLn(Pad, 'throw ', DescribeExpr(Stmts[NodeIdx].ExprNode), ' ;');
    SK_WHILESELECT: Begin
      Write(Pad, 'while select ');
      If Stmts[NodeIdx].ForUpdate Then Write('forUpdate ');
      Write(DescribeExpr(Stmts[NodeIdx].SelectVar));
      If Stmts[NodeIdx].OrderByHead <> 0 Then Write(' order by ...');
      If Stmts[NodeIdx].ExprNode <> 0 Then
        Write(' where ', DescribeExpr(Stmts[NodeIdx].ExprNode));
      WriteLn;
      DumpStatement(Stmts[NodeIdx].BodyStmt, Indent + 1);
    End;
    SK_SELECT: Begin
      Write(Pad, 'select ');
      If Stmts[NodeIdx].ForUpdate Then Write('forUpdate ');
      Write(DescribeExpr(Stmts[NodeIdx].SelectVar));
      If Stmts[NodeIdx].OrderByHead <> 0 Then Write(' order by ...');
      If Stmts[NodeIdx].ExprNode <> 0 Then
        Write(' where ', DescribeExpr(Stmts[NodeIdx].ExprNode));
      WriteLn(' ;');
    End;
    SK_TTSBEGIN:  WriteLn(Pad, 'ttsBegin ;');
    SK_TTSCOMMIT: WriteLn(Pad, 'ttsCommit ;');
    SK_TTSABORT:  WriteLn(Pad, 'ttsAbort ;');
    SK_DELETEFROM: Begin
      Write(Pad, 'delete_from ', DescribeExpr(Stmts[NodeIdx].SelectVar));
      If Stmts[NodeIdx].ExprNode <> 0 Then
        Write(' where ', DescribeExpr(Stmts[NodeIdx].ExprNode));
      WriteLn(' ;');
    End;
  End;
End;

{ Recapitulatif de l'arbre d'instructions de chaque methode (mode -v) }
Procedure DumpStatements;
Var M: Integer;
Begin
  For M := 1 To MethodCount Do Begin
    If Methods[M].BodyStmt = 0 Then Continue;
    WriteLn('methode ', Methods[M].Name, ' (', Classes[Methods[M].ClassIdx].Name, ')');
    DumpStatement(Methods[M].BodyStmt, 1);
  End;
End;

{ ============================================================ }
{ TODO 11 - SWITCH/CASE                                         }
{ ============================================================ }

{ Une valeur de case doit etre une constante : litteral direct, une
  valeur d'enum, ou un entier litteral precede d'un moins unaire }
Function IsConstExpr(NodeIdx: Integer): Boolean;
Begin
  IsConstExpr :=
    (IRNodes[NodeIdx].Kind = NK_LIT_INT)  Or
    (IRNodes[NodeIdx].Kind = NK_LIT_STR)  Or
    (IRNodes[NodeIdx].Kind = NK_LIT_CHAR) Or
    (IRNodes[NodeIdx].Kind = NK_LIT_BOOL) Or
    (IRNodes[NodeIdx].Kind = NK_LIT_DATE) Or
    (IRNodes[NodeIdx].Kind = NK_ENUMVAL)  Or
    ((IRNodes[NodeIdx].Kind = NK_UNARY) And (IRNodes[NodeIdx].Tok = Ord('-')) And
     (IRNodes[NodeIdx].Left <> 0) And (IRNodes[IRNodes[NodeIdx].Left].Kind = NK_LIT_INT));
End;

{ Cle de comparaison canonique d'une valeur de case constante, pour
  detecter les doublons independamment de la sorte de litteral }
Function ConstKey(NodeIdx: Integer): String;
Begin
  If (IRNodes[NodeIdx].Kind = NK_UNARY) And (IRNodes[NodeIdx].Tok = Ord('-')) Then Begin
    ConstKey := 'I:-' + ItoS(IRNodes[IRNodes[NodeIdx].Left].NumVal);
    Exit;
  End;
  Case IRNodes[NodeIdx].Kind Of
    NK_LIT_INT:  ConstKey := 'I:' + ItoS(IRNodes[NodeIdx].NumVal);
    NK_LIT_BOOL: ConstKey := 'B:' + ItoS(IRNodes[NodeIdx].NumVal);
    NK_LIT_STR:  ConstKey := 'S:' + IRNodes[NodeIdx].Text;
    NK_LIT_CHAR: ConstKey := 'C:' + IRNodes[NodeIdx].Text;
    NK_LIT_DATE: ConstKey := 'D:' + IRNodes[NodeIdx].Text;
    NK_ENUMVAL:  ConstKey := 'E:' + IRNodes[NodeIdx].Text;
  Else
    ConstKey := '?';
  End;
End;

{ Verifie qu'il n'y a qu'un seul default et aucune valeur de case
  dupliquee ou non constante, une fois le corps entierement analyse }
Procedure CheckSwitchCases(SwitchNode: Integer);
Var Ch1, Ch2, DefaultCount: Integer;
Begin
  DefaultCount := 0;
  Ch1 := Stmts[SwitchNode].FirstChild;
  While Ch1 <> 0 Do Begin
    If Stmts[Ch1].Kind = SK_CASE Then Begin
      If Stmts[Ch1].IsDefault Then Begin
        Inc(DefaultCount);
        If DefaultCount > 1 Then
          ParseError('plusieurs "default" dans le meme switch');
      End Else If Not IsConstExpr(Stmts[Ch1].ExprNode) Then
        ParseError('la valeur de case doit etre une constante')
      Else Begin
        Ch2 := Stmts[Ch1].NextStmt;
        While Ch2 <> 0 Do Begin
          If (Stmts[Ch2].Kind = SK_CASE) And (Not Stmts[Ch2].IsDefault) And
             IsConstExpr(Stmts[Ch2].ExprNode) And
             (ConstKey(Stmts[Ch1].ExprNode) = ConstKey(Stmts[Ch2].ExprNode)) Then
            ParseError('valeur de case dupliquee : ' + DescribeExpr(Stmts[Ch1].ExprNode));
          Ch2 := Stmts[Ch2].NextStmt;
        End;
      End;
    End;
    Ch1 := Stmts[Ch1].NextStmt;
  End;
End;

{ Corps d'un switch : une suite plate d'etiquettes case/default et
  d'instructions ordinaires ; l'absence de bloc entre etiquettes
  reproduit naturellement l'enchainement explicite (fall-through) }
Function ParseSwitchBody(MIdx: Integer): Integer;
Var Head, Tail, S: Integer;
Begin
  Head := 0;
  Tail := 0;
  While (CurTokType <> Ord('}')) And (CurTokType <> TOK_EOF) Do Begin
    If CurTokType = KW_CASE Then Begin
      LexNextToken;
      S := NewStmtNode(SK_CASE);
      Stmts[S].ExprNode := ParseExpression;
      Expect(Ord(':'), ':');
    End Else If CurTokType = KW_DEFAULT Then Begin
      LexNextToken;
      Expect(Ord(':'), ':');
      S := NewStmtNode(SK_CASE);
      Stmts[S].IsDefault := True;
    End Else
      S := ParseStatement(MIdx);

    If Head = 0 Then Head := S Else Stmts[Tail].NextStmt := S;
    Tail := S;
    While Stmts[Tail].NextStmt <> 0 Do Tail := Stmts[Tail].NextStmt;
  End;
  ParseSwitchBody := Head;
End;

{ switch (expr) suivi d'un bloc de case/default }
Function ParseSwitchStatement(MIdx: Integer): Integer;
Var N, CondExpr, Body: Integer;
Begin
  LexNextToken;   { consomme switch }
  Expect(Ord('('), '(');
  CondExpr := ParseExpression;
  Expect(Ord(')'), ')');
  Expect(Ord('{'), '{');
  Inc(SwitchDepth);
  Body := ParseSwitchBody(MIdx);
  Dec(SwitchDepth);
  Expect(Ord('}'), '}');
  N := NewStmtNode(SK_SWITCH);
  Stmts[N].ExprNode   := CondExpr;
  Stmts[N].FirstChild := Body;
  CheckSwitchCases(N);
  ParseSwitchStatement := N;
End;

{ ============================================================ }
{ TODO 12 - BOUCLES WHILE, DO-WHILE, FOR                        }
{ ============================================================ }

Function ParseBreakStatement: Integer;
Begin
  LexNextToken;   { consomme break }
  If (LoopDepth = 0) And (SwitchDepth = 0) Then
    ParseError('break en dehors d''une boucle ou d''un switch');
  Expect(Ord(';'), ';');
  ParseBreakStatement := NewStmtNode(SK_BREAK);
End;

Function ParseContinueStatement: Integer;
Begin
  LexNextToken;   { consomme continue }
  If LoopDepth = 0 Then
    ParseError('continue en dehors d''une boucle');
  Expect(Ord(';'), ';');
  ParseContinueStatement := NewStmtNode(SK_CONTINUE);
End;

{ while (cond) instruction }
Function ParseWhileStatement(MIdx: Integer): Integer;
Var N, CondExpr, Body: Integer;
Begin
  LexNextToken;   { consomme while }
  Expect(Ord('('), '(');
  CondExpr := ParseExpression;
  Expect(Ord(')'), ')');
  Inc(LoopDepth);
  Body := ParseStatement(MIdx);
  Dec(LoopDepth);
  N := NewStmtNode(SK_WHILE);
  Stmts[N].ExprNode := CondExpr;
  Stmts[N].BodyStmt := Body;
  ParseWhileStatement := N;
End;

{ do instruction while (cond) ; }
Function ParseDoWhileStatement(MIdx: Integer): Integer;
Var N, Body, CondExpr: Integer;
Begin
  LexNextToken;   { consomme do }
  Inc(LoopDepth);
  Body := ParseStatement(MIdx);
  Dec(LoopDepth);
  Expect(KW_WHILE, 'while');
  Expect(Ord('('), '(');
  CondExpr := ParseExpression;
  Expect(Ord(')'), ')');
  Expect(Ord(';'), ';');
  N := NewStmtNode(SK_DOWHILE);
  Stmts[N].ExprNode := CondExpr;
  Stmts[N].BodyStmt := Body;
  ParseDoWhileStatement := N;
End;

{ for (init; cond; incr) instruction ; chacune des trois clauses de
  l'entete est optionnelle (une condition absente vaut toujours vrai) }
Function ParseForStatement(MIdx: Integer): Integer;
Var N, InitS, CondExpr, IncrExpr, Body: Integer;
Begin
  LexNextToken;   { consomme for }
  Expect(Ord('('), '(');

  If CurTokType = Ord(';') Then Begin
    InitS := 0;
    LexNextToken;
  End Else If LooksLikeVarDecl Then
    InitS := ParseLocalVarDecl(MIdx)
  Else Begin
    InitS := NewStmtNode(SK_EXPR);
    Stmts[InitS].ExprNode := ParseExpression;
    Expect(Ord(';'), ';');
  End;

  If CurTokType = Ord(';') Then CondExpr := 0
  Else CondExpr := ParseExpression;
  Expect(Ord(';'), ';');

  If CurTokType = Ord(')') Then IncrExpr := 0
  Else IncrExpr := ParseExpression;
  Expect(Ord(')'), ')');

  Inc(LoopDepth);
  Body := ParseStatement(MIdx);
  Dec(LoopDepth);

  N := NewStmtNode(SK_FOR);
  Stmts[N].ForInit  := InitS;
  Stmts[N].ExprNode := CondExpr;
  Stmts[N].ForIncr  := IncrExpr;
  Stmts[N].BodyStmt := Body;
  ParseForStatement := N;
End;

{ ============================================================ }
{ TODO 13 - METHODES ET PARAMETRES                              }
{ ============================================================ }

{ Compatibilite simple type d'argument -> type de parametre :
  identite, promotion int/real, ou l'un des deux types n'a pas ete
  resolu (anytype) auquel cas on ne peut rien affirmer et on accepte }
Function TypeCompatible(ArgType, ParamType: String): Boolean;
Begin
  TypeCompatible :=
    (ArgType = ParamType) Or (ArgType = 'anytype') Or (ParamType = 'anytype') Or
    ((ArgType = 'int') And (ParamType = 'real')) Or
    ((ArgType = 'real') And (ParamType = 'int'));
End;

Function CountCallArgs(ArgHead: Integer): Integer;
Var N, Cnt: Integer;
Begin
  Cnt := 0;
  N := ArgHead;
  While N <> 0 Do Begin
    Inc(Cnt);
    N := IRNodes[N].NextArg;
  End;
  CountCallArgs := Cnt;
End;

{ Verifie l'arite puis, pour chaque argument, la compatibilite de
  type avec le parametre declare correspondant }
{ Une methode variadique (ex. strFmt, TODO 23) n'exige qu'une arite
  minimale : seuls les parametres fixes en tete sont types, les
  arguments supplementaires (les substitutions %1..%n) ne sont pas
  verifies puisqu'ils peuvent etre de n'importe quel type }
Procedure CheckCallArgs(MethodIdx, ArgHead: Integer; CalleeDesc: String);
Var
  ArgCount, I, PBase, ArgNode: Integer;
Begin
  ArgCount := CountCallArgs(ArgHead);
  If Methods[MethodIdx].IsVariadic Then Begin
    If ArgCount < Methods[MethodIdx].ParamCount Then Begin
      ParseError(CalleeDesc + ' attend au moins ' +
                 ItoS(Methods[MethodIdx].ParamCount) + ' parametre(s), ' +
                 ItoS(ArgCount) + ' fourni(s)');
      Exit;
    End;
  End Else If ArgCount <> Methods[MethodIdx].ParamCount Then Begin
    ParseError(CalleeDesc + ' attend ' + ItoS(Methods[MethodIdx].ParamCount) +
               ' parametre(s), ' + ItoS(ArgCount) + ' fourni(s)');
    Exit;
  End;
  PBase   := Methods[MethodIdx].ParamStart;
  ArgNode := ArgHead;
  For I := 0 To Methods[MethodIdx].ParamCount - 1 Do Begin
    If Not TypeCompatible(IRNodes[ArgNode].TypeName, Params[PBase + I].TypeName) Then
      ParseError(CalleeDesc + ' : argument ' + ItoS(I + 1) + ' de type ' +
                 IRNodes[ArgNode].TypeName + ' incompatible avec le parametre "' +
                 Params[PBase + I].Name + '" de type ' + Params[PBase + I].TypeName);
    ArgNode := IRNodes[ArgNode].NextArg;
  End;
End;

{ return [expression] ; verifie la coherence avec le type de retour
  declare de la methode en cours (void ou non, type compatible) }
Function ParseReturnStatement(MIdx: Integer): Integer;
Var
  N, ExprIdx: Integer;
  RetType: String;
Begin
  LexNextToken;   { consomme return }
  ExprIdx := 0;
  If CurTokType <> Ord(';') Then ExprIdx := ParseExpression;
  Expect(Ord(';'), ';');

  RetType := Methods[MIdx].RetType;
  If (RetType = 'void') And (ExprIdx <> 0) Then
    ParseError('"return" avec une valeur dans une methode void')
  Else If (RetType <> 'void') And (ExprIdx = 0) Then
    ParseError('"return" sans valeur dans une methode qui doit retourner ' + RetType)
  Else If (ExprIdx <> 0) And (Not TypeCompatible(IRNodes[ExprIdx].TypeName, RetType)) Then
    ParseError('type de retour ' + IRNodes[ExprIdx].TypeName +
               ' incompatible avec ' + RetType);

  N := NewStmtNode(SK_RETURN);
  Stmts[N].ExprNode := ExprIdx;
  ParseReturnStatement := N;
End;

{ ============================================================ }
{ TODO 14 - HERITAGE (EXTENDS) ET POLYMORPHISME                 }
{ ============================================================ }

Const
  MAX_VTABLE_ENTRY = {$IFDEF FPC}4096{$ELSE}256{$ENDIF};

Type
  { Une entree nommee de table de methodes virtuelles ; MethodIdx
    pointe vers l'implementation effective (propre a la classe ou
    heritee telle quelle d'un ancetre) }
  TVTableEntry = Record
    Name:      String;
    MethodIdx: Integer;
  End;
  TVTableEntryTable = Array[1..MAX_VTABLE_ENTRY] Of TVTableEntry;

Var
  VTableEntries:    TVTableEntryTable;
  VTableEntryCount: Integer;

{ Une methode qui en redefinit une autre doit garder la meme arite,
  les memes types de parametres et le meme type de retour }
Procedure CheckOverrideCompatible(ParentMethodIdx, ChildMethodIdx: Integer);
Var I, PBase, CBase: Integer;
Begin
  If Methods[ParentMethodIdx].RetType <> Methods[ChildMethodIdx].RetType Then
    ParseError('la redefinition de "' + Methods[ChildMethodIdx].Name +
               '" doit retourner ' + Methods[ParentMethodIdx].RetType +
               ' comme la methode heritee');

  If Methods[ParentMethodIdx].ParamCount <> Methods[ChildMethodIdx].ParamCount Then Begin
    ParseError('la redefinition de "' + Methods[ChildMethodIdx].Name +
               '" doit avoir ' + ItoS(Methods[ParentMethodIdx].ParamCount) +
               ' parametre(s) comme la methode heritee');
    Exit;
  End;

  PBase := Methods[ParentMethodIdx].ParamStart;
  CBase := Methods[ChildMethodIdx].ParamStart;
  For I := 0 To Methods[ParentMethodIdx].ParamCount - 1 Do
    If Params[PBase + I].TypeName <> Params[CBase + I].TypeName Then
      ParseError('la redefinition de "' + Methods[ChildMethodIdx].Name +
                 '" : le parametre ' + ItoS(I + 1) + ' doit etre de type ' +
                 Params[PBase + I].TypeName + ' comme la methode heritee');
End;

{ Construit la table des methodes virtuelles d'une classe : copie
  d'abord celle de son parent (recursion), puis redefinit ou ajoute
  les methodes propres (hors constructeur et delegates, qui ne sont
  pas polymorphes). Renvoie le nombre total d'entrees. }
Function BuildVTable(ClassIdx: Integer): Integer;
Var
  ParentIdx, ParentStart, ParentCount: Integer;
  I, MBase, J, ExistingIdx: Integer;
Begin
  ParentIdx := Classes[ClassIdx].ParentIdx;
  If ParentIdx <> 0 Then Begin
    BuildVTable(ParentIdx);
    ParentStart := Classes[ParentIdx].VTableStart;
    ParentCount := Classes[ParentIdx].VTableCount;
  End Else Begin
    ParentStart := 0;
    ParentCount := 0;
  End;

  Classes[ClassIdx].VTableStart := VTableEntryCount + 1;
  Classes[ClassIdx].VTableCount := 0;
  For I := 0 To ParentCount - 1 Do Begin
    If VTableEntryCount >= MAX_VTABLE_ENTRY Then
      FatalError('trop d''entrees de vtable (limite ' + ItoS(MAX_VTABLE_ENTRY) + ')');
    Inc(VTableEntryCount);
    VTableEntries[VTableEntryCount] := VTableEntries[ParentStart + I];
    Inc(Classes[ClassIdx].VTableCount);
  End;

  MBase := Classes[ClassIdx].MethodStart;
  For I := 0 To Classes[ClassIdx].MethodCount - 1 Do Begin
    If Methods[MBase + I].IsCtor Or Methods[MBase + I].IsDelegate Then Continue;

    ExistingIdx := 0;
    For J := 0 To Classes[ClassIdx].VTableCount - 1 Do
      If VTableEntries[Classes[ClassIdx].VTableStart + J].Name = Methods[MBase + I].Name Then Begin
        ExistingIdx := Classes[ClassIdx].VTableStart + J;
        Break;
      End;

    If ExistingIdx <> 0 Then Begin
      CheckOverrideCompatible(VTableEntries[ExistingIdx].MethodIdx, MBase + I);
      VTableEntries[ExistingIdx].MethodIdx := MBase + I;
    End Else Begin
      If VTableEntryCount >= MAX_VTABLE_ENTRY Then
        FatalError('trop d''entrees de vtable (limite ' + ItoS(MAX_VTABLE_ENTRY) + ')');
      Inc(VTableEntryCount);
      VTableEntries[VTableEntryCount].Name      := Methods[MBase + I].Name;
      VTableEntries[VTableEntryCount].MethodIdx := MBase + I;
      Inc(Classes[ClassIdx].VTableCount);
    End;
  End;

  BuildVTable := Classes[ClassIdx].VTableCount;
End;

{ Construit la vtable de chaque classe (pas les interfaces, qui
  n'ont pas d'instance ni d'implementation propre) }
Procedure ResolveVTables;
Var I: Integer;
Begin
  For I := 1 To ClassCount Do
    If Not Classes[I].IsInterface Then BuildVTable(I);
End;

{ Recapitulatif de la table des methodes virtuelles de chaque classe,
  utile pour verifier visuellement la resolution dynamique (mode -v) }
Procedure DumpVTables;
Var I, J, Base, Impl: Integer;
Begin
  For I := 1 To ClassCount Do Begin
    If Classes[I].IsInterface Then Continue;
    WriteLn('vtable ', Classes[I].Name);
    Base := Classes[I].VTableStart;
    For J := 0 To Classes[I].VTableCount - 1 Do Begin
      Impl := VTableEntries[Base + J].MethodIdx;
      WriteLn('    [', J, '] ', VTableEntries[Base + J].Name, ' -> ',
              Classes[Methods[Impl].ClassIdx].Name, '.', Methods[Impl].Name);
    End;
  End;
End;

{ ============================================================ }
{ TODO 15 - INTERFACES (IMPLEMENTS)                             }
{ ============================================================ }

{ Une methode d'interface implementee doit avoir le meme type de
  retour, la meme arite et les memes types de parametres que la
  signature declaree dans l'interface }
Procedure CheckInterfaceMethodSignature(IfaceMethodIdx, ClassMethodIdx: Integer;
                                         IfaceName, ClassName: String);
Var I, IBase, CBase: Integer;
Begin
  If Methods[IfaceMethodIdx].RetType <> Methods[ClassMethodIdx].RetType Then Begin
    ParseError('"' + ClassName + '.' + Methods[ClassMethodIdx].Name +
               '" doit retourner ' + Methods[IfaceMethodIdx].RetType +
               ' comme dans l''interface "' + IfaceName + '"');
    Exit;
  End;
  If Methods[IfaceMethodIdx].ParamCount <> Methods[ClassMethodIdx].ParamCount Then Begin
    ParseError('"' + ClassName + '.' + Methods[ClassMethodIdx].Name +
               '" doit avoir ' + ItoS(Methods[IfaceMethodIdx].ParamCount) +
               ' parametre(s) comme dans l''interface "' + IfaceName + '"');
    Exit;
  End;
  IBase := Methods[IfaceMethodIdx].ParamStart;
  CBase := Methods[ClassMethodIdx].ParamStart;
  For I := 0 To Methods[IfaceMethodIdx].ParamCount - 1 Do
    If Params[IBase + I].TypeName <> Params[CBase + I].TypeName Then
      ParseError('"' + ClassName + '.' + Methods[ClassMethodIdx].Name +
                 '" : le parametre ' + ItoS(I + 1) + ' doit etre de type ' +
                 Params[IBase + I].TypeName + ' comme dans l''interface "' +
                 IfaceName + '"');
End;

{ Chaque methode declaree par l'interface doit se retrouver, avec une
  signature compatible, dans la classe (directement ou via extends) }
Procedure CheckInterfaceImplemented(ClassIdx, InterfaceIdx: Integer);
Var
  I, MBase, OwnerCls, MemberIdx, Kind: Integer;
Begin
  MBase := Classes[InterfaceIdx].MethodStart;
  For I := 0 To Classes[InterfaceIdx].MethodCount - 1 Do Begin
    Kind := FindMemberInChain(ClassIdx, Methods[MBase + I].Name, OwnerCls, MemberIdx);
    If Kind <> MEMBER_METHOD Then
      ParseError('"' + Classes[ClassIdx].Name + '" n''implemente pas la methode "' +
                 Methods[MBase + I].Name + '" de l''interface "' +
                 Classes[InterfaceIdx].Name + '"')
    Else
      CheckInterfaceMethodSignature(MBase + I, MemberIdx,
                                     Classes[InterfaceIdx].Name, Classes[ClassIdx].Name);
  End;
End;

Procedure CheckInterfaceCoverage(ClassIdx: Integer);
Var I, IfaceIdx, Base: Integer;
Begin
  Base := Classes[ClassIdx].ImplStart;
  For I := 0 To Classes[ClassIdx].ImplCount - 1 Do Begin
    IfaceIdx := Implements[Base + I].ResolvedIdx;
    If IfaceIdx <> 0 Then CheckInterfaceImplemented(ClassIdx, IfaceIdx);
  End;
End;

{ Verifie la couverture d'interface de chaque classe (les interfaces
  elles-memes n'ont rien a implementer) }
Procedure ResolveInterfaceCoverage;
Var I: Integer;
Begin
  For I := 1 To ClassCount Do
    If Not Classes[I].IsInterface Then CheckInterfaceCoverage(I);
End;

{ ============================================================ }
{ TODO 16 - GESTION DES EXCEPTIONS (TRY/CATCH/THROW)            }
{ ============================================================ }

{ Enregistre l'enum Exception (Error/Warning/Internal) comme s'il
  avait ete declare par l'utilisateur, pour que Exception::Error et
  compagnie soient valides comme n'importe quelle valeur d'enum
  (typo detectee, cf. FindEnumValue) sans avoir a specialiser le
  reste du compilateur pour ce cas }
Procedure RegisterBuiltinEnums;
Var EnumIdx: Integer;
Begin
  EnumIdx := AddEnum('Exception');
  AddEnumValue(EnumIdx, 'Error', 0);
  AddEnumValue(EnumIdx, 'Warning', 1);
  AddEnumValue(EnumIdx, 'Internal', 2);
End;

{ catch (Exception::Xxx) instruction, ou catch generique (sans
  parentheses) instruction }
Function ParseCatchClause(MIdx: Integer): Integer;
Var N, TypeExpr, Body: Integer;
Begin
  LexNextToken;   { consomme catch }
  TypeExpr := 0;
  If CurTokType = Ord('(') Then Begin
    LexNextToken;
    TypeExpr := ParseExpression;
    Expect(Ord(')'), ')');
  End;
  Body := ParseStatement(MIdx);
  N := NewStmtNode(SK_CATCH);
  Stmts[N].ExprNode := TypeExpr;
  Stmts[N].BodyStmt := Body;
  ParseCatchClause := N;
End;

{ try instruction (catch instruction)* (finally instruction)? ; au
  moins un catch ou un finally est exige. Le deroulement de pile
  (unwind) lors de la propagation d'une exception est un mecanisme
  d'execution : sa mise en oeuvre reelle viendra avec le generateur
  de code (TODO 24), une fois qu'il y aura du code machine dans
  lequel derouler quoi que ce soit. }
Function ParseTryStatement(MIdx: Integer): Integer;
Var N, TryBody, CatchHead, CatchTail, C, FinallyBody: Integer;
Begin
  LexNextToken;   { consomme try }
  TryBody := ParseStatement(MIdx);

  CatchHead := 0;
  CatchTail := 0;
  While CurTokType = KW_CATCH Do Begin
    C := ParseCatchClause(MIdx);
    If CatchHead = 0 Then CatchHead := C Else Stmts[CatchTail].NextStmt := C;
    CatchTail := C;
  End;

  FinallyBody := 0;
  If CurTokType = KW_FINALLY Then Begin
    LexNextToken;
    FinallyBody := ParseStatement(MIdx);
  End;

  If (CatchHead = 0) And (FinallyBody = 0) Then
    ParseError('"try" doit etre suivi d''au moins un "catch" ou d''un "finally"');

  N := NewStmtNode(SK_TRY);
  Stmts[N].BodyStmt    := TryBody;
  Stmts[N].FirstChild  := CatchHead;
  Stmts[N].FinallyStmt := FinallyBody;
  ParseTryStatement := N;
End;

{ throw expression ; }
Function ParseThrowStatement(MIdx: Integer): Integer;
Var N, ExprIdx: Integer;
Begin
  LexNextToken;   { consomme throw }
  ExprIdx := ParseExpression;
  Expect(Ord(';'), ';');
  N := NewStmtNode(SK_THROW);
  Stmts[N].ExprNode := ExprIdx;
  ParseThrowStatement := N;
End;

{ ============================================================ }
{ TODO 17 - DELEGATES ET GESTIONNAIRES D'EVENEMENTS             }
{ ============================================================ }

{ Termine la lecture d'un attribut entre crochets a partir d'une
  profondeur de crochets/parentheses deja ouverts connue (StartDepth),
  utilise quand la forme SubscribesTo(...) attendue n'a pas ete
  reconnue : on ignore le reste tel quel jusqu'au ']' correspondant,
  comme le faisait l'ancien SkipAttribute generique. }
Procedure SkipToAttributeEnd(StartDepth: Integer);
Var Depth: Integer;
Begin
  Depth := StartDepth;
  While CurTokType <> TOK_EOF Do Begin
    If (CurTokType = Ord('[')) Or (CurTokType = Ord('(')) Then Inc(Depth)
    Else If CurTokType = Ord(')') Then Dec(Depth)
    Else If CurTokType = Ord(']') Then Begin
      Dec(Depth);
      If Depth <= 0 Then Begin LexNextToken; Exit; End;
    End;
    LexNextToken;
  End;
End;

{ Reconnait precisement [SubscribesTo(classStr(Classe),
  delegateStr(Classe, Nom))] ; toute autre forme d'attribut (ou une
  forme partiellement invalide) est ignoree comme avant, en retombant
  sur un depouillement generique equilibrant crochets/parentheses. }
Procedure ParseAttribute(Var HasSubscribe: Boolean;
                          Var SubClassName, SubDelegateName: String);
Var
  ClassArg, DelClassArg, DelNameArg: String;
  Ok:    Boolean;
  Depth: Integer;
Begin
  HasSubscribe := False;
  LexNextToken;   { consomme [ }
  Depth := 1;

  Ok := (CurTokType = TOK_IDENT) And (CurTokStr = 'SubscribesTo');
  If Ok Then LexNextToken;

  If Ok Then Ok := CurTokType = Ord('(');
  If Ok Then Begin Inc(Depth); LexNextToken; End;

  If Ok Then Ok := (CurTokType = TOK_IDENT) And (CurTokStr = 'classStr');
  If Ok Then LexNextToken;

  If Ok Then Ok := CurTokType = Ord('(');
  If Ok Then Begin Inc(Depth); LexNextToken; End;

  If Ok Then Ok := CurTokType = TOK_IDENT;
  If Ok Then Begin ClassArg := CurTokStr; LexNextToken; End;

  If Ok Then Ok := CurTokType = Ord(')');
  If Ok Then Begin Dec(Depth); LexNextToken; End;

  If Ok Then Ok := CurTokType = Ord(',');
  If Ok Then LexNextToken;

  If Ok Then Ok := (CurTokType = TOK_IDENT) And (CurTokStr = 'delegateStr');
  If Ok Then LexNextToken;

  If Ok Then Ok := CurTokType = Ord('(');
  If Ok Then Begin Inc(Depth); LexNextToken; End;

  If Ok Then Ok := CurTokType = TOK_IDENT;
  If Ok Then Begin DelClassArg := CurTokStr; LexNextToken; End;

  If Ok Then Ok := CurTokType = Ord(',');
  If Ok Then LexNextToken;

  If Ok Then Ok := CurTokType = TOK_IDENT;
  If Ok Then Begin DelNameArg := CurTokStr; LexNextToken; End;

  If Ok Then Ok := CurTokType = Ord(')');   { ferme delegateStr(...) }
  If Ok Then Begin Dec(Depth); LexNextToken; End;

  If Ok Then Ok := CurTokType = Ord(')');   { ferme SubscribesTo(...) }
  If Ok Then Begin Dec(Depth); LexNextToken; End;

  If Ok Then Ok := CurTokType = Ord(']');   { ferme l'attribut }
  If Ok Then Begin Dec(Depth); LexNextToken; End;

  If Ok Then Begin
    HasSubscribe    := True;
    SubClassName    := ClassArg;
    SubDelegateName := DelNameArg;
    If ClassArg <> DelClassArg Then
      ParseError('SubscribesTo : classStr et delegateStr doivent designer la meme classe');
  End Else
    SkipToAttributeEnd(Depth);
End;

{ Un abonnement doit designer un delegate reellement declare sur la
  classe visee, et le gestionnaire doit accepter exactement les
  memes parametres que ce delegate (il sera invoque avec les memes
  arguments lorsque le delegate sera declenche) }
Procedure ResolveSubscriptions;
Var
  I, TargetClass, DelIdx, OwnerCls, Kind, J, DBase, SBase: Integer;
Begin
  For I := 1 To SubscriptionCount Do Begin
    TargetClass := FindClass(Subscriptions[I].TargetClassName);
    If TargetClass = 0 Then Begin
      ParseError('SubscribesTo : classe "' + Subscriptions[I].TargetClassName +
                 '" inconnue');
      Continue;
    End;

    Kind := FindMemberInChain(TargetClass, Subscriptions[I].DelegateName,
                               OwnerCls, DelIdx);
    If (Kind <> MEMBER_METHOD) Or (Not Methods[DelIdx].IsDelegate) Then Begin
      ParseError('SubscribesTo : "' + Subscriptions[I].DelegateName +
                 '" n''est pas un delegate de la classe "' +
                 Subscriptions[I].TargetClassName + '"');
      Continue;
    End;

    SBase := Subscriptions[I].SubscriberMethod;
    If Not Methods[SBase].IsStatic Then
      ParseError('le gestionnaire "' + Methods[SBase].Name +
                 '" abonne a "' + Subscriptions[I].DelegateName +
                 '" doit etre static');

    If Methods[DelIdx].ParamCount <> Methods[SBase].ParamCount Then
      ParseError('le gestionnaire "' + Methods[SBase].Name +
                 '" doit accepter ' + ItoS(Methods[DelIdx].ParamCount) +
                 ' parametre(s) comme le delegate "' +
                 Subscriptions[I].DelegateName + '"')
    Else Begin
      DBase := Methods[DelIdx].ParamStart;
      For J := 0 To Methods[DelIdx].ParamCount - 1 Do
        If Params[DBase + J].TypeName <> Params[Methods[SBase].ParamStart + J].TypeName Then
          ParseError('le gestionnaire "' + Methods[SBase].Name +
                     '" : le parametre ' + ItoS(J + 1) + ' doit etre de type ' +
                     Params[DBase + J].TypeName + ' comme le delegate "' +
                     Subscriptions[I].DelegateName + '"');
    End;
  End;
End;

{ Recapitulatif des liaisons delegate -> abonnes (mode -v) }
Procedure DumpSubscriptions;
Var I, S: Integer;
Begin
  For I := 1 To SubscriptionCount Do Begin
    S := Subscriptions[I].SubscriberMethod;
    WriteLn('abonnement ', Subscriptions[I].TargetClassName, '::',
            Subscriptions[I].DelegateName, ' -> ',
            Classes[Methods[S].ClassIdx].Name, '.', Methods[S].Name);
  End;
End;

{ ============================================================ }
{ TODO 18 - MODELE DE TABLE (AOT SIMULE) ET METADONNEES         }
{ ============================================================ }

Const
  MAX_AOT_TABLE = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_AOT_FIELD = {$IFDEF FPC}512{$ELSE}64{$ENDIF};
  RECID_SIZE    = 8;   { RecId : entier 64 bits dans une vraie table AX }

Type
  TAotField = Record
    Name:     String;
    TypeName: String;
    Offset:   Integer;   { deplacement dans le buffer d'enregistrement }
  End;
  TAotFieldTable = Array[1..MAX_AOT_FIELD] Of TAotField;

  TAotTable = Record
    Name:         String;
    FieldStart:   Integer;
    FieldCount:   Integer;
    KeyFieldName: String;   { cle primaire, simplifiee a un seul champ }
    BufferSize:   Integer;  { taille totale du buffer d'enregistrement }
  End;
  TAotTableTable = Array[1..MAX_AOT_TABLE] Of TAotTable;

Var
  AotTables:     TAotTableTable;
  AotTableCount: Integer;
  AotFields:     TAotFieldTable;
  AotFieldCount: Integer;

Function AddAotTable(Name: String): Integer;
Begin
  If AotTableCount >= MAX_AOT_TABLE Then
    FatalError('trop de tables AOT simulees (limite ' + ItoS(MAX_AOT_TABLE) + ')');
  Inc(AotTableCount);
  AotTables[AotTableCount].Name         := Name;
  AotTables[AotTableCount].FieldStart   := AotFieldCount + 1;
  AotTables[AotTableCount].FieldCount   := 0;
  AotTables[AotTableCount].KeyFieldName := '';
  AotTables[AotTableCount].BufferSize   := 0;
  AddAotTable := AotTableCount;
End;

Procedure AddAotField(TableIdx: Integer; Name, TypeName: String);
Begin
  If AotFieldCount >= MAX_AOT_FIELD Then
    FatalError('trop de champs AOT simules (limite ' + ItoS(MAX_AOT_FIELD) + ')');
  Inc(AotFieldCount);
  AotFields[AotFieldCount].Name     := Name;
  AotFields[AotFieldCount].TypeName := TypeName;
  AotFields[AotFieldCount].Offset   := 0;
  Inc(AotTables[TableIdx].FieldCount);
End;

Function FindAotTable(Name: String): Integer;
Var I: Integer;
Begin
  FindAotTable := 0;
  For I := 1 To AotTableCount Do
    If AotTables[I].Name = Name Then Begin
      FindAotTable := I;
      Exit;
    End;
End;

Function FindAotField(TableIdx: Integer; Name: String): Integer;
Var I, Base: Integer;
Begin
  FindAotField := 0;
  If TableIdx = 0 Then Exit;
  Base := AotTables[TableIdx].FieldStart;
  For I := 0 To AotTables[TableIdx].FieldCount - 1 Do
    If AotFields[Base + I].Name = Name Then Begin
      FindAotField := Base + I;
      Exit;
    End;
End;

Function AotFieldTypeName(FieldIdx: Integer): String;
Begin
  AotFieldTypeName := AotFields[FieldIdx].TypeName;
End;

Procedure SetAotKey(TableIdx: Integer; KeyField: String);
Begin
  If FindAotField(TableIdx, KeyField) = 0 Then
    FatalError('cle "' + KeyField + '" inconnue dans la table "' +
               AotTables[TableIdx].Name + '"');
  AotTables[TableIdx].KeyFieldName := KeyField;
End;

{ Deplacement de chaque champ dans le buffer d'enregistrement : un
  RecId simule en tete (comme dans une vraie table AX), puis les
  champs declares les uns a la suite des autres }
Procedure ComputeAotTableLayout(TableIdx: Integer);
Var I, Base, Offset: Integer;
Begin
  Offset := RECID_SIZE;
  Base := AotTables[TableIdx].FieldStart;
  For I := 0 To AotTables[TableIdx].FieldCount - 1 Do Begin
    AotFields[Base + I].Offset := Offset;
    Offset := Offset + TypeSize(AotFields[Base + I].TypeName);
  End;
  AotTables[TableIdx].BufferSize := Offset;
End;

{ Definition interne minimale des tables standard utilisees par les
  samples ; volontairement incomplete (seuls les champs reellement
  references sont modelises) }
Procedure RegisterBuiltinTables;
Var T: Integer;
Begin
  T := AddAotTable('CustTable');
  AddAotField(T, 'AccountNum', 'str');
  AddAotField(T, 'Name', 'str');
  AddAotField(T, 'CustGroup', 'str');
  AddAotField(T, 'Blocked', 'int');
  AddAotField(T, 'Currency', 'str');
  SetAotKey(T, 'AccountNum');
  ComputeAotTableLayout(T);

  T := AddAotTable('CustGroup');
  AddAotField(T, 'CustGroup', 'str');
  AddAotField(T, 'Name', 'str');
  SetAotKey(T, 'CustGroup');
  ComputeAotTableLayout(T);
End;

{ tableNum(Table) : Table doit etre le nom (non entre guillemets)
  d'une table AOT connue ; renvoie un entier (l'indice interne, en
  guise d'identifiant simule faute de veritable table de liens) }
Procedure ResolveTableNumCall(CallNode, ArgHead: Integer);
Var TableIdx: Integer;
Begin
  If (ArgHead = 0) Or (IRNodes[ArgHead].NextArg <> 0) Then Begin
    ParseError('tableNum attend exactement un argument (le nom de la table)');
    Exit;
  End;
  If IRNodes[ArgHead].Kind <> NK_IDENT Then Begin
    ParseError('tableNum attend un nom de table, pas une expression');
    Exit;
  End;
  TableIdx := FindAotTable(IRNodes[ArgHead].Text);
  If TableIdx = 0 Then
    ParseError('table "' + IRNodes[ArgHead].Text + '" inconnue (tableNum)')
  Else Begin
    IRNodes[CallNode].TypeName := 'int';
    IRNodes[CallNode].NumVal   := TableIdx;
  End;
End;

{ fieldNum(Table, Champ) : les deux arguments sont des noms, pas des
  expressions ; verifie que le champ existe bien dans la table }
Procedure ResolveFieldNumCall(CallNode, ArgHead: Integer);
Var TableIdx, FieldIdx, Arg2: Integer;
Begin
  If (ArgHead = 0) Or (IRNodes[ArgHead].NextArg = 0) Or
     (IRNodes[IRNodes[ArgHead].NextArg].NextArg <> 0) Then Begin
    ParseError('fieldNum attend exactement deux arguments (table, champ)');
    Exit;
  End;
  Arg2 := IRNodes[ArgHead].NextArg;
  If (IRNodes[ArgHead].Kind <> NK_IDENT) Or (IRNodes[Arg2].Kind <> NK_IDENT) Then Begin
    ParseError('fieldNum attend des noms de table et de champ, pas des expressions');
    Exit;
  End;
  TableIdx := FindAotTable(IRNodes[ArgHead].Text);
  If TableIdx = 0 Then Begin
    ParseError('table "' + IRNodes[ArgHead].Text + '" inconnue (fieldNum)');
    Exit;
  End;
  FieldIdx := FindAotField(TableIdx, IRNodes[Arg2].Text);
  If FieldIdx = 0 Then
    ParseError('champ "' + IRNodes[Arg2].Text + '" inconnu dans la table "' +
               IRNodes[ArgHead].Text + '" (fieldNum)')
  Else Begin
    IRNodes[CallNode].TypeName := 'int';
    IRNodes[CallNode].NumVal   := FieldIdx;
  End;
End;

{ Recapitulatif des tables AOT simulees, avec deplacements du buffer
  d'enregistrement (mode -v) }
Procedure DumpAotTables;
Var I, J, Base: Integer;
Begin
  For I := 1 To AotTableCount Do Begin
    WriteLn('table ', AotTables[I].Name, ' (cle=', AotTables[I].KeyFieldName,
            ', taille buffer=', AotTables[I].BufferSize, ')');
    Base := AotTables[I].FieldStart;
    For J := 0 To AotTables[I].FieldCount - 1 Do
      WriteLn('    champ  ', AotFields[Base + J].TypeName, ' ',
              AotFields[Base + J].Name, ' (offset=', AotFields[Base + J].Offset, ')');
  End;
End;

{ ============================================================ }
{ TODO 19 - WHILE SELECT / SELECT ET REQUETES SIMPLES           }
{ ============================================================ }

{ Reconnait les clauses communes a while select et select :
  [forUpdate] Variable [order by Champ[, Champ...]] [where Condition].
  Variable est evaluee comme une expression ordinaire (generalement un
  simple identificateur) ; on verifie qu'elle designe bien une table
  AOT connue (TODO 18), sans quoi la requete ne pourrait pas
  s'executer une fois le stockage de table interne en place. }
Procedure ParseSelectClauses(Var TargetVar, OrderHead, WhereExpr: Integer;
                              Var ForUpdate: Boolean);
Var OrderTail, OrderNode: Integer;
Begin
  ForUpdate := False;
  OrderHead := 0;
  WhereExpr := 0;

  If CurTokType = KW_FORUPDATE Then Begin
    ForUpdate := True;
    LexNextToken;
  End;

  If CurTokType <> TOK_IDENT Then
    ParseError('nom de variable de table attendu apres select, trouve ' +
               TokenName(CurTokType));

  TargetVar := ParseExpression;

  If FindAotTable(IRNodes[TargetVar].TypeName) = 0 Then
    ParseError('"' + IRNodes[TargetVar].Text +
               '" n''est pas une table connue (select)');

  If CurTokType = KW_ORDER Then Begin
    LexNextToken;
    Expect(KW_BY, 'by');
    OrderNode := ParseExpression;
    OrderHead := OrderNode;
    OrderTail := OrderNode;
    While AcceptTok(Ord(',')) Do Begin
      OrderNode := ParseExpression;
      IRNodes[OrderTail].NextArg := OrderNode;
      OrderTail := OrderNode;
    End;
  End;

  If CurTokType = KW_WHERE Then Begin
    LexNextToken;
    WhereExpr := ParseExpression;
  End;
End;

{ while select ... suivi d'un bloc : boucle d'iteration sur la table.
  La traduction reelle en iteration sur un stockage de table interne
  (tableau/fichier en memoire) est un mecanisme d'execution qui
  viendra avec le generateur de code (TODO 24), une fois qu'il y aura
  un runtime dans lequel stocker des enregistrements. }
Function ParseWhileSelectStatement(MIdx: Integer): Integer;
Var
  N, TargetVar, OrderHead, WhereExpr, Body: Integer;
  ForUpdate: Boolean;
Begin
  LexNextToken;   { consomme while }
  LexNextToken;   { consomme select }
  ParseSelectClauses(TargetVar, OrderHead, WhereExpr, ForUpdate);
  Expect(Ord('{'), '{');
  Inc(LoopDepth);
  Body := ParseStmtBlock(MIdx);
  Dec(LoopDepth);
  N := NewStmtNode(SK_WHILESELECT);
  Stmts[N].SelectVar   := TargetVar;
  Stmts[N].OrderByHead := OrderHead;
  Stmts[N].ExprNode    := WhereExpr;
  Stmts[N].ForUpdate   := ForUpdate;
  Stmts[N].BodyStmt    := Body;
  ParseWhileSelectStatement := N;
End;

{ select [forUpdate] Variable [order by ...] [where Condition] ; :
  lecture d'un seul enregistrement, sans bloc }
Function ParseSelectStatement: Integer;
Var
  N, TargetVar, OrderHead, WhereExpr: Integer;
  ForUpdate: Boolean;
Begin
  LexNextToken;   { consomme select }
  ParseSelectClauses(TargetVar, OrderHead, WhereExpr, ForUpdate);
  Expect(Ord(';'), ';');
  N := NewStmtNode(SK_SELECT);
  Stmts[N].SelectVar   := TargetVar;
  Stmts[N].OrderByHead := OrderHead;
  Stmts[N].ExprNode    := WhereExpr;
  Stmts[N].ForUpdate   := ForUpdate;
  ParseSelectStatement := N;
End;

{ ============================================================ }
{ TODO 20 - CRUD ET TRANSACTIONS (INSERT/UPDATE/DELETE/TTS)     }
{ ============================================================ }

{ .insert()/.update()/.delete()/.clear() sont geres directement dans
  ParseCall (voir plus haut, TODO 09) des qu'un objet est reconnu
  comme une table AOT connue (TODO 18) : ce sont des methodes de
  buffer standard qui n'existent dans aucune classe utilisateur. }

Function ParseTtsBeginStatement: Integer;
Begin
  LexNextToken;   { consomme ttsBegin }
  Expect(Ord(';'), ';');
  Inc(TtsDepth);
  ParseTtsBeginStatement := NewStmtNode(SK_TTSBEGIN);
End;

Function ParseTtsCommitStatement: Integer;
Begin
  LexNextToken;   { consomme ttsCommit }
  If TtsDepth = 0 Then
    ParseError('ttsCommit sans ttsBegin correspondant')
  Else
    Dec(TtsDepth);
  Expect(Ord(';'), ';');
  ParseTtsCommitStatement := NewStmtNode(SK_TTSCOMMIT);
End;

{ ttsAbort deroule vers le ttsBegin le plus externe (comme une
  exception), quel que soit le niveau d'imbrication courant : la
  transaction entiere est annulee, pas seulement le dernier niveau }
Function ParseTtsAbortStatement: Integer;
Begin
  LexNextToken;   { consomme ttsAbort }
  If TtsDepth = 0 Then
    ParseError('ttsAbort sans ttsBegin correspondant')
  Else
    TtsDepth := 0;
  Expect(Ord(';'), ';');
  ParseTtsAbortStatement := NewStmtNode(SK_TTSABORT);
End;

{ delete_from Variable [where Condition] ; }
Function ParseDeleteFromStatement: Integer;
Var N, TargetVar, WhereExpr: Integer;
Begin
  LexNextToken;   { consomme delete_from }
  If CurTokType <> TOK_IDENT Then
    ParseError('nom de variable de table attendu apres delete_from, trouve ' +
               TokenName(CurTokType));
  TargetVar := ParseExpression;
  If FindAotTable(IRNodes[TargetVar].TypeName) = 0 Then
    ParseError('"' + IRNodes[TargetVar].Text +
               '" n''est pas une table connue (delete_from)');

  WhereExpr := 0;
  If CurTokType = KW_WHERE Then Begin
    LexNextToken;
    WhereExpr := ParseExpression;
  End;
  Expect(Ord(';'), ';');

  N := NewStmtNode(SK_DELETEFROM);
  Stmts[N].SelectVar := TargetVar;
  Stmts[N].ExprNode  := WhereExpr;
  ParseDeleteFromStatement := N;
End;

{ ============================================================ }
{ TODO 21 - QUERY, QUERYBUILDDATASOURCE, QUERYRUN               }
{ ============================================================ }

{ Nom d'une table AOT simulee (TODO 18) par son indice, utilise pour
  deduire le type de retour reel de QueryRun.get(tableNum(X)) }
Function AotTableName(Idx: Integer): String;
Begin
  If (Idx >= 1) And (Idx <= AotTableCount) Then
    AotTableName := AotTables[Idx].Name
  Else
    AotTableName := 'anytype';
End;

{ Query/QueryBuildDataSource/QueryBuildRange/QueryRun sont enregistres
  comme de veritables classes (memes tables Classes/Methods/Params
  que pour une classe utilisateur), pour que toute l'infrastructure
  deja en place (FindMemberInChain, CheckCallArgs, verification
  d'arite du constructeur...) s'applique sans code special, comme si
  l'utilisateur les avait declarees lui-meme. SysQuery::valueNotEmpty
  reste volontairement non modelise (comme tout ce qui utilise ::
  pour un appel statique plutot qu'une valeur d'enum) : l'appel reste
  anytype, ce qui suffit puisque QueryBuildRange.value() accepte tout
  type compatible. }
Procedure RegisterBuiltinQueryClasses;
Var C, M: Integer;
Begin
  C := AddClass('Query', False);
  M := AddMethod(C, 'void', 'new', KW_PUBLIC, False);
  M := AddMethod(C, 'QueryBuildDataSource', 'addDataSource', KW_PUBLIC, False);
  AddParam(M, 'int', 'tableId');

  C := AddClass('QueryBuildDataSource', False);
  M := AddMethod(C, 'QueryBuildRange', 'addRange', KW_PUBLIC, False);
  AddParam(M, 'int', 'fieldId');

  C := AddClass('QueryBuildRange', False);
  M := AddMethod(C, 'void', 'value', KW_PUBLIC, False);
  AddParam(M, 'str', 'val');

  C := AddClass('QueryRun', False);
  M := AddMethod(C, 'void', 'new', KW_PUBLIC, False);
  AddParam(M, 'Query', 'q');
  M := AddMethod(C, 'boolean', 'next', KW_PUBLIC, False);
  M := AddMethod(C, 'anytype', 'get', KW_PUBLIC, False);
  AddParam(M, 'int', 'tableId');
End;

{ ============================================================ }
{ TODO 22 - COLLECTIONS RUNTIME : MAP ET LIST                   }
{ ============================================================ }

{ Map/List/MapEnumerator/ListEnumerator sont enregistres comme de
  veritables classes, exactement comme Query et QueryRun (TODO 21) :
  meme infrastructure de resolution d'appel, aucun code special.
  Map et List sont generiques dans le vrai X++ (le type des elements
  depend des arguments Types::xxx passes a new) ; comme ce compilateur
  ne modelise pas de generiques (hors de portee de ce sous-ensemble),
  insert/addEnd/current/currentKey/currentValue restent anytype,
  compatibles avec n'importe quelle valeur passee ou lue. }
Procedure RegisterBuiltinCollectionClasses;
Var C, M, TypesEnum: Integer;
Begin
  TypesEnum := AddEnum('Types');
  AddEnumValue(TypesEnum, 'Integer',   0);
  AddEnumValue(TypesEnum, 'Real',      1);
  AddEnumValue(TypesEnum, 'String',    2);
  AddEnumValue(TypesEnum, 'Boolean',   3);
  AddEnumValue(TypesEnum, 'Date',      4);
  AddEnumValue(TypesEnum, 'Container', 5);
  AddEnumValue(TypesEnum, 'Class',     6);
  AddEnumValue(TypesEnum, 'Enum',      7);

  C := AddClass('Map', False);
  M := AddMethod(C, 'void', 'new', KW_PUBLIC, False);
  AddParam(M, 'Types', 'keyType');
  AddParam(M, 'Types', 'valType');
  M := AddMethod(C, 'void', 'insert', KW_PUBLIC, False);
  AddParam(M, 'anytype', 'key');
  AddParam(M, 'anytype', 'value');
  M := AddMethod(C, 'MapEnumerator', 'getEnumerator', KW_PUBLIC, False);

  C := AddClass('List', False);
  M := AddMethod(C, 'void', 'new', KW_PUBLIC, False);
  AddParam(M, 'Types', 'elementType');
  M := AddMethod(C, 'void', 'addEnd', KW_PUBLIC, False);
  AddParam(M, 'anytype', 'value');
  M := AddMethod(C, 'ListEnumerator', 'getEnumerator', KW_PUBLIC, False);
  M := AddMethod(C, 'int', 'elements', KW_PUBLIC, False);

  C := AddClass('MapEnumerator', False);
  M := AddMethod(C, 'boolean', 'moveNext', KW_PUBLIC, False);
  M := AddMethod(C, 'anytype', 'currentKey', KW_PUBLIC, False);
  M := AddMethod(C, 'anytype', 'currentValue', KW_PUBLIC, False);

  C := AddClass('ListEnumerator', False);
  M := AddMethod(C, 'boolean', 'moveNext', KW_PUBLIC, False);
  M := AddMethod(C, 'anytype', 'current', KW_PUBLIC, False);
End;

{ ============================================================ }
{ TODO 23 - FONCTIONS RUNTIME NATIVES (STR/DATE/DIVERS)         }
{ ============================================================ }

{ Les fonctions runtime globales n'appartiennent a aucune classe :
  elles sont rattachees a une classe fictive "$Global" (nom invalide
  en tant qu'identificateur X++, donc inaccessible au code utilisateur)
  pour reutiliser telles quelles CheckCallArgs/TypeCompatible ; voir
  le repli ajoute dans ParseCall (TODO 09) qui consulte cette classe
  quand un appel par identificateur simple n'est pas une methode de
  la classe courante. strFmt est la seule variadique (les substitutions
  %1..%n peuvent etre de n'importe quel type, non verifiees). }
Procedure RegisterBuiltinRuntimeFuncs;
Var C, M: Integer;
Begin
  C := AddClass('$Global', False);
  GlobalFuncClassIdx := C;

  M := AddMethod(C, 'str', 'strFmt', KW_PUBLIC, True);
  AddParam(M, 'str', 'fmt');
  Methods[M].IsVariadic := True;

  M := AddMethod(C, 'int', 'strLen', KW_PUBLIC, True);
  AddParam(M, 'str', 's');

  M := AddMethod(C, 'str', 'strUpr', KW_PUBLIC, True);
  AddParam(M, 'str', 's');

  M := AddMethod(C, 'str', 'strLwr', KW_PUBLIC, True);
  AddParam(M, 'str', 's');

  M := AddMethod(C, 'str', 'subStr', KW_PUBLIC, True);
  AddParam(M, 'str', 's');
  AddParam(M, 'int', 'start');
  AddParam(M, 'int', 'len');

  M := AddMethod(C, 'int', 'strFind', KW_PUBLIC, True);
  AddParam(M, 'str', 's');
  AddParam(M, 'str', 'sub');
  AddParam(M, 'int', 'startPos');
  AddParam(M, 'int', 'endPos');

  M := AddMethod(C, 'str', 'strDel', KW_PUBLIC, True);
  AddParam(M, 'str', 's');
  AddParam(M, 'int', 'start');
  AddParam(M, 'int', 'len');

  M := AddMethod(C, 'str', 'strIns', KW_PUBLIC, True);
  AddParam(M, 'str', 'insertStr');
  AddParam(M, 'str', 'sourceStr');
  AddParam(M, 'int', 'position');

  M := AddMethod(C, 'str', 'strLTrim', KW_PUBLIC, True);
  AddParam(M, 'str', 's');

  M := AddMethod(C, 'str', 'strRTrim', KW_PUBLIC, True);
  AddParam(M, 'str', 's');

  M := AddMethod(C, 'str', 'con2Str', KW_PUBLIC, True);
  AddParam(M, 'container', 'c');
  AddParam(M, 'str', 'delimiter');

  M := AddMethod(C, 'int', 'conLen', KW_PUBLIC, True);
  AddParam(M, 'container', 'c');

  M := AddMethod(C, 'anytype', 'conPeek', KW_PUBLIC, True);
  AddParam(M, 'container', 'c');
  AddParam(M, 'int', 'index');

  M := AddMethod(C, 'container', 'conIns', KW_PUBLIC, True);
  AddParam(M, 'container', 'c');
  AddParam(M, 'int', 'index');
  AddParam(M, 'anytype', 'value');

  M := AddMethod(C, 'container', 'conDel', KW_PUBLIC, True);
  AddParam(M, 'container', 'c');
  AddParam(M, 'int', 'index');
  AddParam(M, 'int', 'count');

  M := AddMethod(C, 'date', 'str2Date', KW_PUBLIC, True);
  AddParam(M, 'str', 's');
  AddParam(M, 'int', 'format');

  M := AddMethod(C, 'date', 'today', KW_PUBLIC, True);

  M := AddMethod(C, 'int', 'mthOfYr', KW_PUBLIC, True);
  AddParam(M, 'date', 'd');

  M := AddMethod(C, 'str', 'mthName', KW_PUBLIC, True);
  AddParam(M, 'int', 'month');

  M := AddMethod(C, 'guid', 'newGuid', KW_PUBLIC, True);

  M := AddMethod(C, 'str', 'guid2Str', KW_PUBLIC, True);
  AddParam(M, 'guid', 'g');

  M := AddMethod(C, 'void', 'info', KW_PUBLIC, True);
  AddParam(M, 'str', 'msg');
End;

{ ============================================================ }
{ TODO 24 - GENERATION ASM 80386, OBJ COFF ET LIEN EXE          }
{ ============================================================ }

{ Portee volontairement reduite face a l'ampleur reelle d'un
  generateur de code complet : le codegen ci-dessous produit du vrai
  code machine 80386 correct pour l'arithmetique entiere/booleenne,
  les variables locales/parametres scalaires, tout le controle de
  flux (if/else, while, do-while, for, switch/case, break, continue,
  return) et les appels entre methodes utilisateur (dispatch statique
  par etiquette, sans veritable "this" puisqu'aucune allocation
  d'objet reelle n'existe). info("litteral") produit un vrai affichage
  console (GetStdHandle/WriteFile/ExitProcess, KERNEL32). Tout ce qui
  suppose un runtime non ecrit (containers, Map/List/Query, tables
  AOT, delegates diffuses a leurs abonnes, exceptions qui deroulent
  reellement la pile, chaines autres que litterales passees a info)
  est genere de façon sure : les arguments sont evalues (effets de
  bord conserves) puis le resultat vaut simplement 0, sans jamais
  faire planter le programme. Les writers OBJ COFF et EXE PE32
  reprennent l'architecture bas niveau deja eprouvee dans
  PERLCW32.PAS (mêmes noms, mêmes constantes PE/COFF de TODO 02). }

Const
  { Sous Turbo Pascal 7 reel (16 bits), une variable/un tableau ne peut
    depasser 65520 octets (limite de segment) ; TBinBuffer (ci-dessous)
    est utilise trois fois (BinCode/BinData/BinRData), donc 65536 tel
    quel echouerait a la compilation en dehors de FPC (mode plat 32
    bits, sans cette limite) }
  MAX_BIN        = {$IFDEF FPC}65536{$ELSE}16384{$ENDIF};
  MAX_BIN_LABEL  = {$IFDEF FPC}2048{$ELSE}256{$ENDIF};
  MAX_BIN_FIXUP  = {$IFDEF FPC}4096{$ELSE}512{$ENDIF};

  REG_EAX = 0; REG_ECX = 1; REG_EDX = 2; REG_EBX = 3;
  REG_ESP = 4; REG_EBP = 5; REG_ESI = 6; REG_EDI = 7;

  CC_E  = 4;  CC_NE = 5;
  CC_L  = 12; CC_GE = 13; CC_LE = 14; CC_G = 15;

  CG_SWITCH_TEMP_SIZE = 4;

Type
  TBinBuffer = Array[0..MAX_BIN - 1] Of Byte;
  TBinLabel = Record
    Name:    String;
    Section: Integer;
    Offset:  LongInt;
    Defined: Boolean;
  End;
  TBinFixup = Record
    Section:  Integer;
    Offset:   LongInt;
    LabelRef: Integer;
    Kind:     Integer;
  End;
  TBinLabelTable = Array[1..MAX_BIN_LABEL] Of TBinLabel;
  TBinFixupTable = Array[1..MAX_BIN_FIXUP] Of TBinFixup;

Var
  BinCode, BinData, BinRData: TBinBuffer;
  BinCodeSize, BinDataSize, BinRDataSize, BinBssSize: LongInt;
  BinLabels:     TBinLabelTable;
  BinLabelCount: Integer;
  BinFixups:     TBinFixupTable;
  BinFixupCount: Integer;
  BinCurSec:     Integer;
  BinLabelSeq:   Integer;
  AsmOut:        Text;
  AsmActive:     Boolean;
  CgCurMethod:      Integer;
  CgEpilogueLabel:  String;
  CgBreakLabel:     String;
  CgContinueLabel:  String;
  CgSwitchTempOffset: Integer;

{ ------------------------------------------------------------ }
{ Sortie ASM textuelle optionnelle (-asm)                       }
{ ------------------------------------------------------------ }

Procedure AL(S: String);
Begin If AsmActive Then WriteLn(AsmOut, '        ', S); End;

Procedure ALLabel(S: String);
Begin If AsmActive Then WriteLn(AsmOut, S, ':'); End;

Procedure ALRaw(S: String);
Begin If AsmActive Then WriteLn(AsmOut, S); End;

Function RegName(R: Integer): String;
Begin
  Case R Of
    REG_EAX: RegName := 'eax'; REG_ECX: RegName := 'ecx';
    REG_EDX: RegName := 'edx'; REG_EBX: RegName := 'ebx';
    REG_ESP: RegName := 'esp'; REG_EBP: RegName := 'ebp';
    REG_ESI: RegName := 'esi'; REG_EDI: RegName := 'edi';
  Else RegName := '?';
  End;
End;

Function SignedDisp(D: LongInt): String;
Begin
  If D >= 0 Then SignedDisp := '+' + ItoS(D) Else SignedDisp := ItoS(D);
End;

Function JccMnemonic(CC: Integer): String;
Begin
  Case CC Of
    CC_E:  JccMnemonic := 'je';
    CC_NE: JccMnemonic := 'jne';
    CC_L:  JccMnemonic := 'jl';
    CC_GE: JccMnemonic := 'jge';
    CC_LE: JccMnemonic := 'jle';
    CC_G:  JccMnemonic := 'jg';
  Else JccMnemonic := 'j?';
  End;
End;

Function SetccMnemonic(CC: Integer): String;
Begin
  Case CC Of
    CC_E:  SetccMnemonic := 'sete';
    CC_NE: SetccMnemonic := 'setne';
    CC_L:  SetccMnemonic := 'setl';
    CC_GE: SetccMnemonic := 'setge';
    CC_LE: SetccMnemonic := 'setle';
    CC_G:  SetccMnemonic := 'setg';
  Else SetccMnemonic := 'set?';
  End;
End;

{ ------------------------------------------------------------ }
{ Primitives binaires (memes noms/structure que PERLCW32.PAS)   }
{ ------------------------------------------------------------ }

Procedure BinInit;
Begin
  BinCodeSize := 0; BinDataSize := 0; BinRDataSize := 0; BinBssSize := 0;
  BinLabelCount := 0; BinFixupCount := 0; BinCurSec := BIN_SEC_TEXT;
  BinLabelSeq := 0;
End;

Procedure BinEmit8(B: Byte);
Begin
  Case BinCurSec Of
    1: Begin BinCode[BinCodeSize]  := B; Inc(BinCodeSize);  End;
    2: Begin BinData[BinDataSize]  := B; Inc(BinDataSize);  End;
    3: Begin BinRData[BinRDataSize] := B; Inc(BinRDataSize); End;
  End;
End;

Procedure BinEmit32(D: LongInt);
Begin
  BinEmit8(D And $FF);          BinEmit8((D Shr 8)  And $FF);
  BinEmit8((D Shr 16) And $FF); BinEmit8((D Shr 24) And $FF);
End;

Procedure BinEmit16(W: Integer);
Begin
  BinEmit8(W And $FF); BinEmit8((W Shr 8) And $FF);
End;

Function BinCurOffset: LongInt;
Begin
  Case BinCurSec Of
    1: BinCurOffset := BinCodeSize;
    2: BinCurOffset := BinDataSize;
    3: BinCurOffset := BinRDataSize;
  Else BinCurOffset := 0;
  End;
End;

Function BinDefineLabel(LName: String): Integer;
Var I: Integer;
Begin
  For I := 1 To BinLabelCount Do
    If BinLabels[I].Name = LName Then Begin
      BinLabels[I].Section := BinCurSec;
      BinLabels[I].Offset  := BinCurOffset;
      BinLabels[I].Defined := True;
      ALLabel(LName);
      BinDefineLabel := I;
      Exit;
    End;
  Inc(BinLabelCount);
  BinLabels[BinLabelCount].Name    := LName;
  BinLabels[BinLabelCount].Section := BinCurSec;
  BinLabels[BinLabelCount].Offset  := BinCurOffset;
  BinLabels[BinLabelCount].Defined := True;
  ALLabel(LName);
  BinDefineLabel := BinLabelCount;
End;

Function BinLookupLabel(LName: String): Integer;
Var I: Integer;
Begin
  For I := 1 To BinLabelCount Do
    If BinLabels[I].Name = LName Then Begin BinLookupLabel := I; Exit; End;
  Inc(BinLabelCount);
  BinLabels[BinLabelCount].Name    := LName;
  BinLabels[BinLabelCount].Section := BinCurSec;
  BinLabels[BinLabelCount].Offset  := 0;
  BinLabels[BinLabelCount].Defined := False;
  BinLookupLabel := BinLabelCount;
End;

Procedure BinAddFixup(LIdx, Kind: Integer);
Begin
  If BinFixupCount >= MAX_BIN_FIXUP Then Exit;
  Inc(BinFixupCount);
  BinFixups[BinFixupCount].Section  := BinCurSec;
  BinFixups[BinFixupCount].Offset   := BinCurOffset;
  BinFixups[BinFixupCount].LabelRef := LIdx;
  BinFixups[BinFixupCount].Kind     := Kind;
End;

Procedure BinEmitRef32(LName: String; Kind: Integer);
Var LIdx: Integer;
Begin
  LIdx := BinLookupLabel(LName);
  BinAddFixup(LIdx, Kind);
  BinEmit32(0);
End;

Function NewBinLabel(Prefix: String): String;
Begin
  Inc(BinLabelSeq);
  NewBinLabel := '_XPPL_' + Prefix + ItoS(BinLabelSeq);
End;

Procedure BinPushReg(R: Integer);
Begin AL('push ' + RegName(R)); BinEmit8($50 + R); End;

Procedure BinPopReg(R: Integer);
Begin AL('pop ' + RegName(R)); BinEmit8($58 + R); End;

Procedure BinPushImm32(V: LongInt);
Begin AL('push ' + ItoS(V)); BinEmit8($68); BinEmit32(V); End;

Procedure BinMovRegImm32(Rd: Integer; V: LongInt);
Begin AL('mov ' + RegName(Rd) + ', ' + ItoS(V)); BinEmit8($B8 + Rd); BinEmit32(V); End;

Procedure BinMovRegReg(Rd, Rs: Integer);
Begin
  AL('mov ' + RegName(Rd) + ', ' + RegName(Rs));
  BinEmit8($8B); BinEmit8($C0 Or (Rd Shl 3) Or Rs);
End;

Procedure BinXorRegReg(R: Integer);
Begin AL('xor ' + RegName(R) + ', ' + RegName(R)); BinEmit8($33); BinEmit8($C0 Or (R Shl 3) Or R); End;

Procedure BinMovEaxEbpDisp(Disp: LongInt);
Begin
  AL('mov eax, [ebp' + SignedDisp(Disp) + ']');
  If (Disp >= -128) And (Disp <= 127) Then Begin
    BinEmit8($8B); BinEmit8($45); BinEmit8(Disp And $FF);
  End Else Begin
    BinEmit8($8B); BinEmit8($85); BinEmit32(Disp);
  End;
End;

Procedure BinMovEbpDispEax(Disp: LongInt);
Begin
  AL('mov [ebp' + SignedDisp(Disp) + '], eax');
  If (Disp >= -128) And (Disp <= 127) Then Begin
    BinEmit8($89); BinEmit8($45); BinEmit8(Disp And $FF);
  End Else Begin
    BinEmit8($89); BinEmit8($85); BinEmit32(Disp);
  End;
End;

{ mov byte ptr [ebp+Disp], al : reservees a la construction de petits
  tampons locaux d'un seul octet (ajoute par TODO 26, runtime str) }
Procedure BinMovEbpDispAl(Disp: LongInt);
Begin
  AL('mov byte ptr [ebp' + SignedDisp(Disp) + '], al');
  If (Disp >= -128) And (Disp <= 127) Then Begin
    BinEmit8($88); BinEmit8($45); BinEmit8(Disp And $FF);
  End Else Begin
    BinEmit8($88); BinEmit8($85); BinEmit32(Disp);
  End;
End;

{ lea Rd, [ebp+Disp] : adresse effective d'un emplacement EBP-relatif,
  utilisee pour obtenir un pointeur passable a WriteFile (ajoute par
  TODO 26) }
Procedure BinLeaRegEbpDisp(Rd, Disp: LongInt);
Begin
  AL('lea ' + RegName(Rd) + ', [ebp' + SignedDisp(Disp) + ']');
  If (Disp >= -128) And (Disp <= 127) Then Begin
    BinEmit8($8D); BinEmit8($45 Or (Rd Shl 3)); BinEmit8(Disp And $FF);
  End Else Begin
    BinEmit8($8D); BinEmit8($85 Or (Rd Shl 3)); BinEmit32(Disp);
  End;
End;

{ movzx Rd, word ptr [ebp+Disp] : lecture d'un champ WORD (16 bits)
  d'une structure Win32 (ex. SYSTEMTIME de GetLocalTime), etendue sans
  signe dans un registre 32 bits complet (ajoute pour la date reelle) }
Procedure BinMovzxRegEbpDispWord(Rd, Disp: LongInt);
Begin
  AL('movzx ' + RegName(Rd) + ', word ptr [ebp' + SignedDisp(Disp) + ']');
  BinEmit8($0F); BinEmit8($B7);
  If (Disp >= -128) And (Disp <= 127) Then Begin
    BinEmit8($45 Or (Rd Shl 3)); BinEmit8(Disp And $FF);
  End Else Begin
    BinEmit8($85 Or (Rd Shl 3)); BinEmit32(Disp);
  End;
End;

{ div R : division non signee EDX:EAX / R -> EAX=quotient, EDX=reste
  (ajoute par TODO 26, decomposition decimale de _XPPRT_PrintInt) }
Procedure BinDivReg(R: Integer);
Begin AL('div ' + RegName(R)); BinEmit8($F7); BinEmit8($F0 Or R); End;

{ cmp R, imm8 (etendu en signe) : comparaison generique a un registre
  autre que EAX (ajoute par TODO 26) }
Procedure BinCmpRegImm8(R: Integer; V: Integer);
Begin
  AL('cmp ' + RegName(R) + ', ' + ItoS(V));
  BinEmit8($83); BinEmit8($F8 Or R); BinEmit8(V And $FF);
End;

{ add al, imm8 : conversion chiffre (0..9) -> caractere ASCII
  (ajoute par TODO 26) }
Procedure BinAddAlImm8(V: Integer);
Begin AL('add al, ' + ItoS(V)); BinEmit8($04); BinEmit8(V And $FF); End;

Procedure BinSubEspImm32(N: LongInt);
Begin
  If N = 0 Then Exit;
  AL('sub esp, ' + ItoS(N));
  If (N > 0) And (N <= 127) Then Begin BinEmit8($83); BinEmit8($EC); BinEmit8(N); End
  Else Begin BinEmit8($81); BinEmit8($EC); BinEmit32(N); End;
End;

Procedure BinEmitPrologue(FrameSz: LongInt);
Begin
  BinPushReg(REG_EBP);
  AL('mov ebp, esp'); BinEmit8($8B); BinEmit8($EC);
  BinSubEspImm32(FrameSz);
End;

Procedure BinEmitEpilogueN(CleanBytes: Integer);
Begin
  AL('mov esp, ebp'); BinEmit8($8B); BinEmit8($E5);
  BinPopReg(REG_EBP);
  If CleanBytes = 0 Then Begin AL('ret'); BinEmit8($C3); End
  Else Begin AL('ret ' + ItoS(CleanBytes)); BinEmit8($C2); BinEmit16(CleanBytes); End;
End;

Procedure BinCallLabel(LName: String);
Begin AL('call ' + LName); BinEmit8($E8); BinEmitRef32(LName, BIN_FIX_REL32); End;

Procedure BinJmpLabel(LName: String);
Begin AL('jmp ' + LName); BinEmit8($E9); BinEmitRef32(LName, BIN_FIX_REL32); End;

Procedure BinJccLabel(CC: Integer; LName: String);
Begin
  AL(JccMnemonic(CC) + ' ' + LName);
  BinEmit8($0F); BinEmit8($80 Or CC);
  BinEmitRef32(LName, BIN_FIX_REL32);
End;

Procedure BinCmpEaxImm32(V: LongInt);
Begin AL('cmp eax, ' + ItoS(V)); BinEmit8($3D); BinEmit32(V); End;

Procedure BinCmpEaxEcx;
Begin AL('cmp eax, ecx'); BinEmit8($3B); BinEmit8($C1); End;

Procedure BinAddEaxEcx; Begin AL('add eax, ecx'); BinEmit8($03); BinEmit8($C1); End;
Procedure BinSubEaxEcx; Begin AL('sub eax, ecx'); BinEmit8($2B); BinEmit8($C1); End;
Procedure BinImulEaxEcx; Begin AL('imul eax, ecx'); BinEmit8($0F); BinEmit8($AF); BinEmit8($C1); End;
Procedure BinAndEaxEcx; Begin AL('and eax, ecx'); BinEmit8($23); BinEmit8($C1); End;
Procedure BinOrEaxEcx;  Begin AL('or eax, ecx');  BinEmit8($0B); BinEmit8($C1); End;
Procedure BinXorEaxEcxOp; Begin AL('xor eax, ecx'); BinEmit8($33); BinEmit8($C1); End;
Procedure BinShlEaxCl; Begin AL('shl eax, cl'); BinEmit8($D3); BinEmit8($E0); End;
Procedure BinSarEaxCl; Begin AL('sar eax, cl'); BinEmit8($D3); BinEmit8($F8); End;
Procedure BinNegEax;   Begin AL('neg eax'); BinEmit8($F7); BinEmit8($D8); End;
Procedure BinNotEax;   Begin AL('not eax'); BinEmit8($F7); BinEmit8($D0); End;
Procedure BinIncEax;   Begin AL('inc eax'); BinEmit8($40); End;
Procedure BinDecEax;   Begin AL('dec eax'); BinEmit8($48); End;

Procedure BinIdivEcx;
Begin AL('cdq'); AL('idiv ecx'); BinEmit8($99); BinEmit8($F7); BinEmit8($F9); End;

Procedure BinSetccAl(CC: Integer);
Begin AL(SetccMnemonic(CC) + ' al'); BinEmit8($0F); BinEmit8($90 Or CC); BinEmit8($C0); End;

Procedure BinMovzxEaxAl;
Begin AL('movzx eax, al'); BinEmit8($0F); BinEmit8($B6); BinEmit8($C0); End;

{ Appel d'une fonction KERNEL32 (__stdcall : c'est l'appelee qui
  nettoie la pile, aucun ajustement d'ESP requis ici) }
Procedure BinCallImportRaw(ProcName: String);
Begin
  AL('call dword ptr [__imp__' + ProcName + ']');
  BinEmit8($FF); BinEmit8($15);
  BinEmitRef32('__imp__' + ProcName, BIN_FIX_IMP32);
End;

{ Empile l'adresse absolue (patchee au moment du lien PE) d'un label
  de .data/.rdata : PUSH imm32 avec fixup ABS32 }
Procedure BinPushLabelAddr(LName: String);
Begin
  AL('push offset ' + LName);
  BinEmit8($68);
  BinEmitRef32(LName, BIN_FIX_ABS32);
End;

Procedure BinResolveFixups;
Var
  I, LIdx: Integer;
  Loc, Target, Rel: LongInt;
Begin
  For I := 1 To BinFixupCount Do Begin
    If BinFixups[I].Kind <> BIN_FIX_REL32 Then Continue;
    LIdx := BinFixups[I].LabelRef;
    If (LIdx = 0) Or (Not BinLabels[LIdx].Defined) Then Continue;
    If BinFixups[I].Section <> BinLabels[LIdx].Section Then Continue;
    If BinFixups[I].Section <> BIN_SEC_TEXT Then Continue;
    Loc    := BinFixups[I].Offset;
    Target := BinLabels[LIdx].Offset;
    Rel    := Target - (Loc + 4);
    BinCode[Loc]     := Rel And $FF;
    BinCode[Loc + 1] := (Rel Shr 8)  And $FF;
    BinCode[Loc + 2] := (Rel Shr 16) And $FF;
    BinCode[Loc + 3] := (Rel Shr 24) And $FF;
  End;
End;

Function AlignUp(N, AAlign: LongInt): LongInt;
Begin
  If (N Mod AAlign) = 0 Then AlignUp := N
  Else AlignUp := N + AAlign - (N Mod AAlign);
End;

Procedure WritePad(Var F: File; N: LongInt);
Var Z: Byte; I: LongInt;
Begin
  Z := 0;
  For I := 1 To N Do BlockWrite(F, Z, 1);
End;

Procedure WriteWord(Var F: File; W: Integer);
Var B: Byte;
Begin
  B := W And $FF; BlockWrite(F, B, 1);
  B := (W Shr 8) And $FF; BlockWrite(F, B, 1);
End;

Procedure WriteDWord(Var F: File; D: LongInt);
Var B: Byte;
Begin
  B := D And $FF; BlockWrite(F, B, 1);
  B := (D Shr 8)  And $FF; BlockWrite(F, B, 1);
  B := (D Shr 16) And $FF; BlockWrite(F, B, 1);
  B := (D Shr 24) And $FF; BlockWrite(F, B, 1);
End;

Procedure WriteStr8(Var F: File; S: String; Len: Integer);
Var I: Integer; Z: Byte;
Begin
  Z := 0;
  For I := 1 To Len Do Begin
    If I <= Length(S) Then BlockWrite(F, S[I], 1) Else BlockWrite(F, Z, 1);
  End;
End;

{ ------------------------------------------------------------ }
{ WriteCOFF : ecrit un fichier .OBJ COFF i386 minimal (-obj)    }
{ ------------------------------------------------------------ }

Procedure WriteCOFF(FileName: String);
Var
  F: File;
  SymOff: LongInt;
  TextOff, DataOff, RDataOff: LongInt;
  NSec, NSym: Integer;
  I: Integer;
  LI: LongInt;
  TextSz, DataSz, RDataSz: LongInt;
  Dummy: Byte;
Begin
  Assign(F, FileName); Rewrite(F, 1);
  TextSz  := AlignUp(BinCodeSize,  4);
  DataSz  := AlignUp(BinDataSize,  4);
  RDataSz := AlignUp(BinRDataSize, 4);
  NSec := 2;
  If BinDataSize  > 0 Then Inc(NSec);
  If BinRDataSize > 0 Then Inc(NSec);
  If BinBssSize   > 0 Then Inc(NSec);
  TextOff  := 20 + NSec * 40;
  DataOff  := TextOff  + TextSz;
  RDataOff := DataOff  + DataSz;
  SymOff   := RDataOff + RDataSz;
  NSym     := BinLabelCount + 4;

  WriteWord(F,  PE_MACHINE_I386);
  WriteWord(F,  NSec);
  WriteDWord(F, 0);
  WriteDWord(F, SymOff);
  WriteDWord(F, NSym);
  WriteWord(F,  0);
  WriteWord(F,  0);

  WriteStr8(F, '.text',  8);
  WriteDWord(F, BinCodeSize);  WriteDWord(F, 0);
  WriteDWord(F, TextSz);       WriteDWord(F, TextOff);
  WriteDWord(F, 0);            WriteDWord(F, 0);
  WriteWord(F, 0);             WriteWord(F, 0);
  WriteDWord(F, PE_SCN_CNT_CODE Or PE_SCN_MEM_EXECUTE Or PE_SCN_MEM_READ);

  WriteStr8(F, '.data',  8);
  WriteDWord(F, BinDataSize);  WriteDWord(F, 0);
  WriteDWord(F, DataSz);       WriteDWord(F, DataOff);
  WriteDWord(F, 0);            WriteDWord(F, 0);
  WriteWord(F, 0);             WriteWord(F, 0);
  WriteDWord(F, PE_SCN_CNT_INIT_DATA Or PE_SCN_MEM_READ Or PE_SCN_MEM_WRITE);

  If BinRDataSize > 0 Then Begin
    WriteStr8(F, '.rdata', 8);
    WriteDWord(F, BinRDataSize); WriteDWord(F, 0);
    WriteDWord(F, RDataSz);      WriteDWord(F, RDataOff);
    WriteDWord(F, 0);            WriteDWord(F, 0);
    WriteWord(F, 0);             WriteWord(F, 0);
    WriteDWord(F, PE_SCN_CNT_INIT_DATA Or PE_SCN_MEM_READ);
  End;

  If BinBssSize > 0 Then Begin
    WriteStr8(F, '.bss', 8);
    WriteDWord(F, BinBssSize);   WriteDWord(F, 0);
    WriteDWord(F, 0);            WriteDWord(F, 0);
    WriteDWord(F, 0);            WriteDWord(F, 0);
    WriteWord(F, 0);             WriteWord(F, 0);
    WriteDWord(F, PE_SCN_CNT_UNINIT_DATA Or PE_SCN_MEM_READ Or PE_SCN_MEM_WRITE);
  End;

  For LI := 0 To BinCodeSize - 1  Do BlockWrite(F, BinCode[LI],  1);
  WritePad(F, TextSz  - BinCodeSize);
  For LI := 0 To BinDataSize - 1  Do BlockWrite(F, BinData[LI],  1);
  WritePad(F, DataSz  - BinDataSize);
  If BinRDataSize > 0 Then Begin
    For LI := 0 To BinRDataSize - 1 Do BlockWrite(F, BinRData[LI], 1);
    WritePad(F, RDataSz - BinRDataSize);
  End;

  For I := 1 To BinLabelCount Do Begin
    If Not BinLabels[I].Defined Then Continue;
    WriteStr8(F, BinLabels[I].Name, 8);
    WriteDWord(F, BinLabels[I].Offset);
    WriteWord(F, BinLabels[I].Section);
    WriteWord(F, 0);
    Dummy := COFF_SYM_CLASS_EXTERNAL; BlockWrite(F, Dummy, 1);
    Dummy := 0; BlockWrite(F, Dummy, 1);
  End;

  WriteDWord(F, 4);
  Close(F);
End;

{ ------------------------------------------------------------ }
{ WritePE : ecrit un fichier .EXE PE32 Win32 (par defaut)       }
{ ------------------------------------------------------------ }

Procedure WritePE(FileName: String);
Const
  NK = 4;   { GetStdHandle, WriteFile, ExitProcess, GetLocalTime }
Var
  F: File;
  I, K: Integer;
  LI: LongInt;
  Dummy: Byte;

  ImageBase, FileAlign, SecAlign: LongInt;
  HdrsSz, TextSz, DataSz, RDataSz, IDataSz: LongInt;
  TextRVA, DataRVA, RDataRVA, BssRVA, IDataRVA: LongInt;
  TextFOff, DataFOff, RDataFOff, IDataFOff: LongInt;
  EntryRVA, ImageSz, CodeSz, InitDataSz: LongInt;

  IAT_Off, ILT_Off, IDT_Off, DllName_Off, HintBase_Off, IData_Raw: LongInt;
  FuncOff:  Array[1..4] Of LongInt;
  FuncName: Array[1..4] Of String;

  IDT_RVA, IDT_SZ, IAT_RVA, IAT_SZ: LongInt;

  FI, LIdx, Kidx, NL: Integer;
  Pname: String;
  IATVA, Loc: LongInt;
  TxtVirtSz, DatVirtSz, RdtVirtSz: LongInt;
Begin
  FuncName[1] := 'GetStdHandle';
  FuncName[2] := 'WriteFile';
  FuncName[3] := 'ExitProcess';
  FuncName[4] := 'GetLocalTime';

  ImageBase := PE_IMG_BASE;
  FileAlign := PE_FILE_ALIGN;
  SecAlign  := PE_SEC_ALIGN;

  IAT_Off     := 0;
  ILT_Off     := (NK + 1) * 4;
  IDT_Off     := ILT_Off + (NK + 1) * 4;
  DllName_Off := IDT_Off + 2 * 20;
  HintBase_Off:= DllName_Off + 14;
  FuncOff[1]  := HintBase_Off;
  For I := 2 To NK Do Begin
    NL := Length(FuncName[I - 1]);
    FuncOff[I] := FuncOff[I - 1] + 2 + NL + 1;
    If (FuncOff[I] Mod 2) <> 0 Then Inc(FuncOff[I]);
  End;
  NL := Length(FuncName[NK]);
  IData_Raw := FuncOff[NK] + 2 + NL + 1;
  If (IData_Raw Mod 2) <> 0 Then Inc(IData_Raw);

  HdrsSz  := 512;
  CodeSz  := AlignUp(BinCodeSize, FileAlign);
  If CodeSz = 0 Then CodeSz := FileAlign;
  TextSz  := CodeSz;
  DataSz  := AlignUp(BinDataSize, FileAlign);
  If DataSz  = 0 Then DataSz  := FileAlign;
  RDataSz := AlignUp(BinRDataSize, FileAlign);
  If RDataSz = 0 Then RDataSz := FileAlign;
  IDataSz := AlignUp(IData_Raw, FileAlign);
  If IDataSz = 0 Then IDataSz := FileAlign;

  TxtVirtSz := AlignUp(BinCodeSize,  SecAlign); If TxtVirtSz = 0 Then TxtVirtSz := SecAlign;
  DatVirtSz := AlignUp(BinDataSize,  SecAlign); If DatVirtSz = 0 Then DatVirtSz := SecAlign;
  RdtVirtSz := AlignUp(BinRDataSize, SecAlign); If RdtVirtSz = 0 Then RdtVirtSz := SecAlign;
  TextRVA  := SecAlign;
  DataRVA  := TextRVA  + TxtVirtSz;
  RDataRVA := DataRVA  + DatVirtSz;
  BssRVA   := RDataRVA + RdtVirtSz;
  IDataRVA := BssRVA   + SecAlign;
  ImageSz  := AlignUp(IDataRVA + IDataSz, SecAlign);
  InitDataSz := DataSz + RDataSz + IDataSz;

  TextFOff  := HdrsSz;
  DataFOff  := TextFOff  + TextSz;
  RDataFOff := DataFOff  + DataSz;
  IDataFOff := RDataFOff + RDataSz;
  EntryRVA  := TextRVA;

  IDT_RVA := IDataRVA + IDT_Off;
  IDT_SZ  := 2 * 20;
  IAT_RVA := IDataRVA + IAT_Off;
  IAT_SZ  := (NK + 1) * 4;

  { Patch des fixups IMP32 (appels KERNEL32) }
  For FI := 1 To BinFixupCount Do Begin
    If BinFixups[FI].Kind <> BIN_FIX_IMP32 Then Continue;
    If BinFixups[FI].Section <> BIN_SEC_TEXT Then Continue;
    LIdx := BinFixups[FI].LabelRef;
    If LIdx = 0 Then Continue;
    Pname := BinLabels[LIdx].Name;
    If (Length(Pname) > 7) And (Copy(Pname, 1, 7) = '__imp__') Then
      Pname := Copy(Pname, 8, 255);
    Kidx := 0;
    For K := 1 To NK Do If FuncName[K] = Pname Then Kidx := K;
    If Kidx = 0 Then Continue;
    IATVA := ImageBase + IAT_RVA + (Kidx - 1) * 4;
    Loc   := BinFixups[FI].Offset;
    BinCode[Loc]     := IATVA And $FF;
    BinCode[Loc + 1] := (IATVA Shr 8)  And $FF;
    BinCode[Loc + 2] := (IATVA Shr 16) And $FF;
    BinCode[Loc + 3] := (IATVA Shr 24) And $FF;
  End;

  { Patch des fixups ABS32 (adresses .data/.rdata referencees en .text) }
  For FI := 1 To BinFixupCount Do Begin
    If BinFixups[FI].Kind <> BIN_FIX_ABS32 Then Continue;
    LIdx := BinFixups[FI].LabelRef;
    If LIdx = 0 Then Continue;
    If Not BinLabels[LIdx].Defined Then Continue;
    Case BinLabels[LIdx].Section Of
      1: IATVA := ImageBase + TextRVA  + BinLabels[LIdx].Offset;
      2: IATVA := ImageBase + DataRVA  + BinLabels[LIdx].Offset;
      3: IATVA := ImageBase + RDataRVA + BinLabels[LIdx].Offset;
    Else Continue;
    End;
    Loc := BinFixups[FI].Offset;
    Case BinFixups[FI].Section Of
      1: Begin
        BinCode[Loc] := IATVA And $FF; BinCode[Loc+1] := (IATVA Shr 8) And $FF;
        BinCode[Loc+2] := (IATVA Shr 16) And $FF; BinCode[Loc+3] := (IATVA Shr 24) And $FF;
      End;
      2: Begin
        BinData[Loc] := IATVA And $FF; BinData[Loc+1] := (IATVA Shr 8) And $FF;
        BinData[Loc+2] := (IATVA Shr 16) And $FF; BinData[Loc+3] := (IATVA Shr 24) And $FF;
      End;
      3: Begin
        BinRData[Loc] := IATVA And $FF; BinRData[Loc+1] := (IATVA Shr 8) And $FF;
        BinRData[Loc+2] := (IATVA Shr 16) And $FF; BinRData[Loc+3] := (IATVA Shr 24) And $FF;
      End;
    End;
  End;

  Assign(F, FileName); Rewrite(F, 1);

  WriteWord(F, PE_DOS_MAGIC); WriteWord(F, $0090); WriteWord(F, 3); WriteWord(F, 0);
  WriteWord(F, 4); WriteWord(F, 0); WriteWord(F, -1); WriteWord(F, 0);
  WriteWord(F, 0); WriteWord(F, 0); WriteWord(F, 0); WriteWord(F, 0);
  WriteWord(F, 0); WriteWord(F, 0);
  For I := 1 To 16 Do WriteWord(F, 0);
  WriteDWord(F, 64);

  WriteDWord(F, PE_PE_SIG);

  WriteWord(F,  PE_MACHINE_I386);
  WriteWord(F,  5);
  WriteDWord(F, 0);
  WriteDWord(F, 0);
  WriteDWord(F, 0);
  WriteWord(F,  224);
  WriteWord(F,  $0102);

  WriteWord(F,  PE_OPT_MAGIC_PE32);
  WriteWord(F,  0);
  WriteDWord(F, CodeSz);
  WriteDWord(F, InitDataSz);
  WriteDWord(F, SecAlign);
  WriteDWord(F, EntryRVA);
  WriteDWord(F, TextRVA);
  WriteDWord(F, DataRVA);
  WriteDWord(F, ImageBase);
  WriteDWord(F, SecAlign);
  WriteDWord(F, FileAlign);
  WriteWord(F,  4); WriteWord(F, 0);
  WriteWord(F,  0); WriteWord(F, 0);
  WriteWord(F,  4); WriteWord(F, 0);
  WriteDWord(F, 0);
  WriteDWord(F, ImageSz);
  WriteDWord(F, HdrsSz);
  WriteDWord(F, 0);
  WriteWord(F,  PE_SUBSYS_CUI);
  WriteWord(F,  0);
  WriteDWord(F, $00100000);
  WriteDWord(F, $00001000);
  WriteDWord(F, $00100000);
  WriteDWord(F, $00001000);
  WriteDWord(F, 0);
  WriteDWord(F, 16);
  WriteDWord(F, 0); WriteDWord(F, 0);
  WriteDWord(F, IDT_RVA); WriteDWord(F, IDT_SZ);
  For I := 2 To 11 Do Begin WriteDWord(F, 0); WriteDWord(F, 0); End;
  WriteDWord(F, IAT_RVA); WriteDWord(F, IAT_SZ);
  WriteDWord(F, 0); WriteDWord(F, 0);
  WriteDWord(F, 0); WriteDWord(F, 0);
  WriteDWord(F, 0); WriteDWord(F, 0);

  WriteStr8(F, '.text',  8);
  WriteDWord(F, BinCodeSize); WriteDWord(F, TextRVA);
  WriteDWord(F, TextSz);      WriteDWord(F, TextFOff);
  WriteDWord(F, 0);           WriteDWord(F, 0);
  WriteWord(F,  0);           WriteWord(F,  0);
  WriteDWord(F, PE_SCN_CNT_CODE Or PE_SCN_MEM_EXECUTE Or PE_SCN_MEM_READ);

  WriteStr8(F, '.data',  8);
  WriteDWord(F, BinDataSize); WriteDWord(F, DataRVA);
  WriteDWord(F, DataSz);      WriteDWord(F, DataFOff);
  WriteDWord(F, 0);           WriteDWord(F, 0);
  WriteWord(F,  0);           WriteWord(F,  0);
  WriteDWord(F, PE_SCN_CNT_INIT_DATA Or PE_SCN_MEM_READ Or PE_SCN_MEM_WRITE);

  WriteStr8(F, '.rdata', 8);
  WriteDWord(F, BinRDataSize); WriteDWord(F, RDataRVA);
  WriteDWord(F, RDataSz);      WriteDWord(F, RDataFOff);
  WriteDWord(F, 0);            WriteDWord(F, 0);
  WriteWord(F,  0);            WriteWord(F,  0);
  WriteDWord(F, PE_SCN_CNT_INIT_DATA Or PE_SCN_MEM_READ);

  WriteStr8(F, '.bss',   8);
  WriteDWord(F, SecAlign);  WriteDWord(F, BssRVA);
  WriteDWord(F, 0);          WriteDWord(F, 0);
  WriteDWord(F, 0);          WriteDWord(F, 0);
  WriteWord(F,  0);          WriteWord(F,  0);
  WriteDWord(F, PE_SCN_CNT_UNINIT_DATA Or PE_SCN_MEM_READ Or PE_SCN_MEM_WRITE);

  WriteStr8(F, '.idata', 8);
  WriteDWord(F, IData_Raw);   WriteDWord(F, IDataRVA);
  WriteDWord(F, IDataSz);     WriteDWord(F, IDataFOff);
  WriteDWord(F, 0);           WriteDWord(F, 0);
  WriteWord(F,  0);           WriteWord(F,  0);
  WriteDWord(F, PE_SCN_CNT_INIT_DATA Or PE_SCN_MEM_READ Or PE_SCN_MEM_WRITE);

  WritePad(F, HdrsSz - 512);

  For LI := 0 To BinCodeSize - 1 Do BlockWrite(F, BinCode[LI], 1);
  WritePad(F, TextSz - BinCodeSize);

  For LI := 0 To BinDataSize - 1 Do BlockWrite(F, BinData[LI], 1);
  WritePad(F, DataSz - BinDataSize);

  For LI := 0 To BinRDataSize - 1 Do BlockWrite(F, BinRData[LI], 1);
  WritePad(F, RDataSz - BinRDataSize);

  For I := 1 To NK Do WriteDWord(F, IDataRVA + FuncOff[I]);
  WriteDWord(F, 0);

  For I := 1 To NK Do WriteDWord(F, IDataRVA + FuncOff[I]);
  WriteDWord(F, 0);

  WriteDWord(F, IDataRVA + ILT_Off);
  WriteDWord(F, 0);
  WriteDWord(F, 0);
  WriteDWord(F, IDataRVA + DllName_Off);
  WriteDWord(F, IDataRVA + IAT_Off);
  WriteDWord(F, 0); WriteDWord(F, 0); WriteDWord(F, 0);
  WriteDWord(F, 0); WriteDWord(F, 0);

  WriteStr8(F, 'KERNEL32.DLL', 13);
  Dummy := 0; BlockWrite(F, Dummy, 1);

  For I := 1 To NK Do Begin
    WriteWord(F, I);
    For K := 1 To Length(FuncName[I]) Do Begin
      Dummy := Ord(FuncName[I][K]); BlockWrite(F, Dummy, 1);
    End;
    Dummy := 0; BlockWrite(F, Dummy, 1);
    NL := Length(FuncName[I]);
    If (NL + 1) Mod 2 <> 0 Then Begin
      Dummy := 0; BlockWrite(F, Dummy, 1);
    End;
  End;

  WritePad(F, IDataSz - IData_Raw);
  Close(F);
End;

{ ------------------------------------------------------------ }
{ Generateur de code X++ -> 80386 (portee reduite, voir le       }
{ commentaire en tete de la section TODO 24 plus haut)           }
{ ------------------------------------------------------------ }

Function MethodLabel(MIdx: Integer): String;
Begin MethodLabel := '_XPPM_' + ItoS(MIdx); End;

Function CaseLabel(NodeIdx: Integer): String;
Begin CaseLabel := '_XPPSW_' + ItoS(NodeIdx); End;

Function CgFindLocal(Name: String; Var Offset: Integer): Boolean;
Var Base, I: Integer;
Begin
  CgFindLocal := False;
  Base := Methods[CgCurMethod].LocalStart;
  For I := 0 To Methods[CgCurMethod].LocalCount - 1 Do
    If Locals[Base + I].Name = Name Then Begin
      Offset := Locals[Base + I].Offset;
      CgFindLocal := True;
      Exit;
    End;
End;

{ Convention d'appel stdcall : les arguments sont evalues et empiles
  de droite a gauche (CodegenUserCall), si bien qu'apres le prologue
  (push ebp ; mov ebp, esp) le premier parametre declare se trouve
  toujours en [ebp+8], le second en [ebp+12], etc. }
Function CgFindParam(Name: String; Var Offset: Integer): Boolean;
Var Base, I: Integer;
Begin
  CgFindParam := False;
  Base := Methods[CgCurMethod].ParamStart;
  For I := 0 To Methods[CgCurMethod].ParamCount - 1 Do
    If Params[Base + I].Name = Name Then Begin
      Offset := 8 + 4 * I;
      CgFindParam := True;
      Exit;
    End;
End;

Function CgVarOffset(Name: String; Var Found: Boolean): Integer;
Var Off: Integer;
Begin
  If CgFindLocal(Name, Off) Then Begin Found := True; CgVarOffset := Off; Exit; End;
  If CgFindParam(Name, Off) Then Begin Found := True; CgVarOffset := Off; Exit; End;
  Found := False;
  CgVarOffset := 0;
End;

{ Charge une variable simple (locale/parametre) dans EAX ; toute
  autre cible (champ, this, objet...) n'est pas modelisee en memoire
  par ce codegen reduit et vaut simplement 0, sans jamais planter }
Procedure CgLoadVar(Name: String);
Var Off: Integer; Found: Boolean;
Begin
  Off := CgVarOffset(Name, Found);
  If Found Then BinMovEaxEbpDisp(Off) Else BinXorRegReg(REG_EAX);
End;

Procedure CgStoreVar(Name: String);
Var Off: Integer; Found: Boolean;
Begin
  Off := CgVarOffset(Name, Found);
  If Found Then BinMovEbpDispEax(Off);
End;

Procedure CodegenExpr(N: Integer); Forward;

{ Evalue une liste d'arguments pour leurs seuls effets de bord
  (appels imbriques, incrementations...) sans en garder les valeurs :
  utilise pour tout ce qui n'a pas de code machine reel (runtime non
  ecrit : containers, Map/List/Query, tables AOT...) }
Procedure CodegenArgSideEffects(ArgHead: Integer);
Var A: Integer;
Begin
  A := ArgHead;
  While A <> 0 Do Begin
    CodegenExpr(A);
    A := IRNodes[A].NextArg;
  End;
End;

{ Les fichiers .xpp sont enregistres en UTF-8, mais la console Windows
  (cmd.exe) affiche par defaut une page de code OEM (CP850 en France/
  Quebec) : ecrire les octets UTF-8 bruts y produit le charabia
  classique (ex. "g├®n├®r├®" au lieu de "généré"). Les litteraux
  imprimes sont donc transcodes UTF-8 -> CP850 a la compilation, une
  fois pour toutes, pour un affichage correct par defaut (ajoute par
  TODO 26). Tout code point hors de la table (au-dela du Latin-1
  usuel) devient '?' plutot que de planter ou d'ecrire n'importe quoi. }
Function DecodeUtf8Char(Const S: String; Var Pos: Integer): LongInt;
Var B0, B1, B2: Byte; CP: LongInt;
Begin
  B0 := Ord(S[Pos]);
  If B0 < $80 Then Begin
    DecodeUtf8Char := B0;
    Inc(Pos);
    Exit;
  End Else If ((B0 And $E0) = $C0) And (Pos < Length(S)) Then Begin
    B1 := Ord(S[Pos + 1]);
    CP := ((B0 And $1F) Shl 6) Or (B1 And $3F);
    Pos := Pos + 2;
    DecodeUtf8Char := CP;
    Exit;
  End Else If ((B0 And $F0) = $E0) And (Pos + 1 < Length(S)) Then Begin
    B1 := Ord(S[Pos + 1]);
    B2 := Ord(S[Pos + 2]);
    CP := ((B0 And $0F) Shl 12) Or ((B1 And $3F) Shl 6) Or (B2 And $3F);
    Pos := Pos + 3;
    DecodeUtf8Char := CP;
    Exit;
  End;
  DecodeUtf8Char := Ord('?');
  Inc(Pos);
End;

Function CodepointToCp850(CP: LongInt): Byte;
Begin
  If CP < $80 Then Begin CodepointToCp850 := CP; Exit; End;
  Case CP Of
    $00C7: CodepointToCp850 := $80; $00FC: CodepointToCp850 := $81;
    $00E9: CodepointToCp850 := $82; $00E2: CodepointToCp850 := $83;
    $00E4: CodepointToCp850 := $84; $00E0: CodepointToCp850 := $85;
    $00E5: CodepointToCp850 := $86; $00E7: CodepointToCp850 := $87;
    $00EA: CodepointToCp850 := $88; $00EB: CodepointToCp850 := $89;
    $00E8: CodepointToCp850 := $8A; $00EF: CodepointToCp850 := $8B;
    $00EE: CodepointToCp850 := $8C; $00EC: CodepointToCp850 := $8D;
    $00C4: CodepointToCp850 := $8E; $00C5: CodepointToCp850 := $8F;
    $00C9: CodepointToCp850 := $90; $00E6: CodepointToCp850 := $91;
    $00C6: CodepointToCp850 := $92; $00F4: CodepointToCp850 := $93;
    $00F6: CodepointToCp850 := $94; $00F2: CodepointToCp850 := $95;
    $00FB: CodepointToCp850 := $96; $00F9: CodepointToCp850 := $97;
    $00FF: CodepointToCp850 := $98; $00D6: CodepointToCp850 := $99;
    $00DC: CodepointToCp850 := $9A; $00F8: CodepointToCp850 := $9B;
    $00A3: CodepointToCp850 := $9C; $00D8: CodepointToCp850 := $9D;
    $00D7: CodepointToCp850 := $9E; $0192: CodepointToCp850 := $9F;
    $00E1: CodepointToCp850 := $A0; $00ED: CodepointToCp850 := $A1;
    $00F3: CodepointToCp850 := $A2; $00FA: CodepointToCp850 := $A3;
    $00F1: CodepointToCp850 := $A4; $00D1: CodepointToCp850 := $A5;
    $00AA: CodepointToCp850 := $A6; $00BA: CodepointToCp850 := $A7;
    $00BF: CodepointToCp850 := $A8; $00AE: CodepointToCp850 := $A9;
    $00AC: CodepointToCp850 := $AA; $00BD: CodepointToCp850 := $AB;
    $00BC: CodepointToCp850 := $AC; $00A1: CodepointToCp850 := $AD;
    $00AB: CodepointToCp850 := $AE; $00BB: CodepointToCp850 := $AF;
    $00C1: CodepointToCp850 := $B5; $00C2: CodepointToCp850 := $B6;
    $00C0: CodepointToCp850 := $B7; $00A9: CodepointToCp850 := $B8;
    $00A2: CodepointToCp850 := $BD; $00A5: CodepointToCp850 := $BE;
    $00E3: CodepointToCp850 := $C6; $00C3: CodepointToCp850 := $C7;
    $00A4: CodepointToCp850 := $CF; $00F0: CodepointToCp850 := $D0;
    $00D0: CodepointToCp850 := $D1; $00CA: CodepointToCp850 := $D2;
    $00CB: CodepointToCp850 := $D3; $00C8: CodepointToCp850 := $D4;
    $0131: CodepointToCp850 := $D5; $00CD: CodepointToCp850 := $D6;
    $00CE: CodepointToCp850 := $D7; $00CF: CodepointToCp850 := $D8;
    $00A6: CodepointToCp850 := $DD; $00CC: CodepointToCp850 := $DE;
    $00D3: CodepointToCp850 := $E0; $00DF: CodepointToCp850 := $E1;
    $00D4: CodepointToCp850 := $E2; $00D2: CodepointToCp850 := $E3;
    $00F5: CodepointToCp850 := $E4; $00D5: CodepointToCp850 := $E5;
    $00B5: CodepointToCp850 := $E6; $00FE: CodepointToCp850 := $E7;
    $00DE: CodepointToCp850 := $E8; $00DA: CodepointToCp850 := $E9;
    $00DB: CodepointToCp850 := $EA; $00D9: CodepointToCp850 := $EB;
    $00FD: CodepointToCp850 := $EC; $00DD: CodepointToCp850 := $ED;
    $00AF: CodepointToCp850 := $EE; $00B4: CodepointToCp850 := $EF;
    $00B1: CodepointToCp850 := $F1; $00BE: CodepointToCp850 := $F3;
    $00B6: CodepointToCp850 := $F4; $00A7: CodepointToCp850 := $F5;
    $00F7: CodepointToCp850 := $F6; $00B8: CodepointToCp850 := $F7;
    $00B0: CodepointToCp850 := $F8; $00A8: CodepointToCp850 := $F9;
    $00B7: CodepointToCp850 := $FA; $00B9: CodepointToCp850 := $FB;
    $00B3: CodepointToCp850 := $FC; $00B2: CodepointToCp850 := $FD;
    $00A0: CodepointToCp850 := $FF;
  Else
    CodepointToCp850 := Ord('?');
  End;
End;

Function ConvertUtf8ToCp850(Const S: String): String;
Var P: Integer; CP: LongInt; Res: String;
Begin
  Res := '';
  P := 1;
  While P <= Length(S) Do Begin
    CP := DecodeUtf8Char(S, P);
    Res := Res + Chr(CodepointToCp850(CP));
  End;
  ConvertUtf8ToCp850 := Res;
End;

{ Ecrit un fragment de chaine litterale (compilee en .rdata) sur la
  console, sans rien y ajouter (ni CRLF, ni longueur implicite) : le
  bloc de base reutilise par info("litteral") (TODO 24) et par le
  formatage reel de strFmt (TODO 26) }
Procedure CodegenPrintStringLiteral(S: String);
Var StrLbl: String; StrLen, K, SavedSec: Integer;
Begin
  S := ConvertUtf8ToCp850(S);
  If Length(S) = 0 Then Exit;
  SavedSec := BinCurSec;
  BinCurSec := BIN_SEC_RDATA;
  StrLbl := NewBinLabel('Str');
  BinDefineLabel(StrLbl);
  For K := 1 To Length(S) Do BinEmit8(Ord(S[K]));
  StrLen := Length(S);
  BinCurSec := SavedSec;

  BinPushImm32(-11);              { STD_OUTPUT_HANDLE }
  BinCallImportRaw('GetStdHandle');
  BinPushImm32(0);                { lpOverlapped }
  BinPushLabelAddr('_XPPD_Written'); { lpNumberOfBytesWritten }
  BinPushImm32(StrLen);            { nNumberOfBytesToWrite }
  BinPushLabelAddr(StrLbl);        { lpBuffer }
  BinPushReg(REG_EAX);             { hFile (survit aux push imm32/offset precedents) }
  BinCallImportRaw('WriteFile');
End;

{ info("litteral") : un vrai affichage console via trois imports
  KERNEL32 (GetStdHandle/WriteFile), CRLF final inclus }
Procedure CodegenInfoLiteral(S: String);
Begin
  CodegenPrintStringLiteral(S + Chr(13) + Chr(10));
End;

{ info(strFmt(gabarit_litteral, args...)) (TODO 26) : le gabarit est
  connu a la compilation (toujours un litteral dans les usages reels
  de strFmt), donc il est decompose ici en fragments litteraux et en
  substitutions %1..%9, chacune imprimee selon le type statique de
  l'argument correspondant :
    int/real  -> conversion decimale reelle via _XPPRT_PrintInt (les
                 reels sont deja arrondis a l'entier par ce codegen
                 reduit, TODO 24, faute d'arithmetique flottante)
    boolean   -> "true"/"false" choisi par un vrai branchement
    str       -> imprime si l'argument est lui-meme un litteral,
                 silencieux sinon (chaine dynamique non representee
                 en memoire par ce runtime reduit)
    autre     -> evalue pour effet de bord uniquement (silencieux) }
Procedure CodegenPrintFormatted(FmtText: String; ArgsHead: Integer);
Var
  I, ArgN, Idx, ArgNode: Integer;
  Pending: String;
  LFalse, LEnd: String;
Begin
  Pending := '';
  I := 1;
  While I <= Length(FmtText) Do Begin
    If (FmtText[I] = '%') And (I < Length(FmtText)) And
       (FmtText[I + 1] >= '1') And (FmtText[I + 1] <= '9') Then Begin
      CodegenPrintStringLiteral(Pending);
      Pending := '';
      ArgN := Ord(FmtText[I + 1]) - Ord('0');

      ArgNode := ArgsHead;
      Idx := 1;
      While (ArgNode <> 0) And (Idx < ArgN) Do Begin
        ArgNode := IRNodes[ArgNode].NextArg;
        Inc(Idx);
      End;

      If (ArgNode <> 0) And (Idx = ArgN) Then Begin
        If IRNodes[ArgNode].TypeName = 'boolean' Then Begin
          CodegenExpr(ArgNode);
          BinCmpEaxImm32(0);
          LFalse := NewBinLabel('BF');
          LEnd   := NewBinLabel('BE');
          BinJccLabel(CC_E, LFalse);
          CodegenPrintStringLiteral('true');
          BinJmpLabel(LEnd);
          BinDefineLabel(LFalse);
          CodegenPrintStringLiteral('false');
          BinDefineLabel(LEnd);
        End Else If IRNodes[ArgNode].TypeName = 'str' Then Begin
          If IRNodes[ArgNode].Kind = NK_LIT_STR Then
            CodegenPrintStringLiteral(IRNodes[ArgNode].Text)
          Else
            CodegenExpr(ArgNode);
        End Else If (IRNodes[ArgNode].TypeName = 'int') Or
                    (IRNodes[ArgNode].TypeName = 'real') Then Begin
          CodegenExpr(ArgNode);
          BinCallLabel('_XPPRT_PrintInt');
        End Else If IRNodes[ArgNode].TypeName = 'date' Then Begin
          CodegenExpr(ArgNode);
          BinCallLabel('_XPPRT_PrintDate');
        End Else
          CodegenExpr(ArgNode);
      End;
      I := I + 2;
    End Else Begin
      Pending := Pending + FmtText[I];
      Inc(I);
    End;
  End;
  CodegenPrintStringLiteral(Pending + Chr(13) + Chr(10));
End;

{ Appel d'une methode utilisateur (corps reellement compile) : les
  arguments sont evalues et empiles de droite a gauche (immediatement
  apres evaluation, a la maniere cdecl/stdcall classique), puis
  l'appelee nettoie elle-meme la pile (RET N) a son epilogue }
Procedure CodegenUserCall(MIdx, ArgHead: Integer);
Var Args: Array[1..64] Of Integer; NArgs, I, A: Integer;
Begin
  NArgs := 0;
  A := ArgHead;
  While (A <> 0) And (NArgs < 64) Do Begin
    Inc(NArgs);
    Args[NArgs] := A;
    A := IRNodes[A].NextArg;
  End;
  For I := NArgs DownTo 1 Do Begin
    CodegenExpr(Args[I]);
    BinPushReg(REG_EAX);
  End;
  BinCallLabel(MethodLabel(MIdx));
End;

Procedure CodegenCall(N: Integer);
Var Callee, MIdx, ArgHead, FmtCallMIdx, FmtNode: Integer;
Begin
  Callee  := IRNodes[N].Left;
  ArgHead := IRNodes[N].Right;

  { tableNum(...)/fieldNum(...) : deja resolus en entier constant par
    le parseur (TODO 18), aucun appel reel a generer }
  If (IRNodes[Callee].Kind = NK_IDENT) And
     ((IRNodes[Callee].Text = 'tableNum') Or (IRNodes[Callee].Text = 'fieldNum')) Then Begin
    BinMovRegImm32(REG_EAX, IRNodes[N].NumVal);
    Exit;
  End;

  MIdx := IRNodes[N].ResolvedMethod;

  If (MIdx <> 0) And (Methods[MIdx].ClassIdx = GlobalFuncClassIdx) And
     (Methods[MIdx].Name = 'info') And (ArgHead <> 0) Then Begin
    If IRNodes[ArgHead].Kind = NK_LIT_STR Then Begin
      CodegenInfoLiteral(IRNodes[ArgHead].Text);
      BinXorRegReg(REG_EAX);
      Exit;
    End;
    { info(strFmt(gabarit_litteral, args...)) : formatage reel (TODO 26) }
    If IRNodes[ArgHead].Kind = NK_CALL Then Begin
      FmtCallMIdx := IRNodes[ArgHead].ResolvedMethod;
      If (FmtCallMIdx <> 0) And (Methods[FmtCallMIdx].ClassIdx = GlobalFuncClassIdx) And
         (Methods[FmtCallMIdx].Name = 'strFmt') Then Begin
        FmtNode := IRNodes[ArgHead].Right;
        If (FmtNode <> 0) And (IRNodes[FmtNode].Kind = NK_LIT_STR) Then Begin
          CodegenPrintFormatted(IRNodes[FmtNode].Text, IRNodes[FmtNode].NextArg);
          BinXorRegReg(REG_EAX);
          Exit;
        End;
      End;
    End;
  End;

  { today() : vraie date systeme (extension apres TODO 26), via
    GetLocalTime encode en AAAAMMJJ par _XPPRT_Today ; ne pas ecraser
    EAX a 0 ensuite, contrairement au stub generique plus bas }
  If (MIdx <> 0) And (Methods[MIdx].ClassIdx = GlobalFuncClassIdx) And
     (Methods[MIdx].Name = 'today') Then Begin
    BinCallLabel('_XPPRT_Today');
    Exit;
  End;

  If (MIdx <> 0) And (Methods[MIdx].BodyStmt <> 0) Then Begin
    CodegenUserCall(MIdx, ArgHead);
    Exit;
  End;

  { fonction/methode non modelisee (runtime natif, collection, table,
    requete, delegate...) : les arguments sont evalues pour leurs
    effets de bord (ex. un appel a info() imbrique) puis le resultat
    vaut simplement 0 }
  CodegenArgSideEffects(ArgHead);
  BinXorRegReg(REG_EAX);
End;

Procedure CodegenNew(N: Integer);
Var MIdx, ArgHead: Integer;
Begin
  ArgHead := IRNodes[N].Right;
  MIdx    := IRNodes[N].ResolvedMethod;
  If (MIdx <> 0) And (Methods[MIdx].BodyStmt <> 0) Then
    CodegenUserCall(MIdx, ArgHead)
  Else
    CodegenArgSideEffects(ArgHead);
  BinXorRegReg(REG_EAX);   { reference d'objet non modelisee : toujours 0 }
End;

Procedure CodegenUnary(N: Integer);
Var Sub, Off: Integer; Found: Boolean;
Begin
  Sub := IRNodes[N].Left;
  Case IRNodes[N].Tok Of
    Ord('-'): Begin CodegenExpr(Sub); BinNegEax; End;
    Ord('+'): CodegenExpr(Sub);
    Ord('!'): Begin
      CodegenExpr(Sub);
      BinCmpEaxImm32(0);
      BinSetccAl(CC_E);
      BinMovzxEaxAl;
    End;
    Ord('~'): Begin CodegenExpr(Sub); BinNotEax; End;
    TOK_INCR, TOK_DECR: Begin
      If IRNodes[Sub].Kind = NK_IDENT Then Begin
        Off := CgVarOffset(IRNodes[Sub].Text, Found);
        If Found Then Begin
          BinMovEaxEbpDisp(Off);
          If IRNodes[N].Tok = TOK_INCR Then BinIncEax Else BinDecEax;
          BinMovEbpDispEax(Off);
          Exit;
        End;
      End;
      CodegenExpr(Sub);
    End;
  Else
    CodegenExpr(Sub);
  End;
End;

Procedure CodegenPostop(N: Integer);
Var Sub, Off: Integer; Found: Boolean;
Begin
  Sub := IRNodes[N].Left;
  If IRNodes[Sub].Kind = NK_IDENT Then Begin
    Off := CgVarOffset(IRNodes[Sub].Text, Found);
    If Found Then Begin
      BinMovEaxEbpDisp(Off);
      BinPushReg(REG_EAX);
      If IRNodes[N].Tok = TOK_INCR Then BinIncEax Else BinDecEax;
      BinMovEbpDispEax(Off);
      BinPopReg(REG_EAX);
      Exit;
    End;
  End;
  CodegenExpr(Sub);
End;

{ Division/modulo protegees : "throw" (TODO 16) ne deroule pas
  reellement la pile dans ce codegen reduit, si bien qu'un code X++
  qui suppose qu'une exception saute par-dessus une division continue
  en fait normalement jusqu'a elle (voir 15_try_catch.xpp : diviseur
  == 0 est cense etre intercepte par le throw, mais l'instruction
  suivante s'execute quand meme ici). Un vrai IDIV par zero declenche
  une exception CPU qui terminerait le processus : EAX/ECX sont deja
  en place (gauche/droite), on verifie ECX avant de diviser et on
  renvoie 0 plutot que de planter. }
Procedure CgSafeDivMod(WantRemainder: Boolean);
Var LSkip, LEnd: String;
Begin
  LSkip := NewBinLabel('DivZ');
  LEnd  := NewBinLabel('DivE');
  AL('cmp ecx, 0'); BinEmit8($83); BinEmit8($F9); BinEmit8($00);
  BinJccLabel(CC_E, LSkip);
  BinIdivEcx;
  If WantRemainder Then BinMovRegReg(REG_EAX, REG_EDX);
  BinJmpLabel(LEnd);
  BinDefineLabel(LSkip);
  BinXorRegReg(REG_EAX);
  BinDefineLabel(LEnd);
End;

Procedure CodegenBinary(N: Integer);
Var Op: Integer; LblFalse, LblEnd: String;
Begin
  Op := IRNodes[N].Tok;

  If Op = TOK_ANDAND Then Begin
    LblFalse := NewBinLabel('AndF');
    LblEnd   := NewBinLabel('AndE');
    CodegenExpr(IRNodes[N].Left);
    BinCmpEaxImm32(0);
    BinJccLabel(CC_E, LblFalse);
    CodegenExpr(IRNodes[N].Right);
    BinCmpEaxImm32(0);
    BinSetccAl(CC_NE);
    BinMovzxEaxAl;
    BinJmpLabel(LblEnd);
    BinDefineLabel(LblFalse);
    BinXorRegReg(REG_EAX);
    BinDefineLabel(LblEnd);
    Exit;
  End;

  If Op = TOK_OROR Then Begin
    LblFalse := NewBinLabel('OrF');
    LblEnd   := NewBinLabel('OrE');
    CodegenExpr(IRNodes[N].Left);
    BinCmpEaxImm32(0);
    BinJccLabel(CC_NE, LblFalse);
    CodegenExpr(IRNodes[N].Right);
    BinCmpEaxImm32(0);
    BinSetccAl(CC_NE);
    BinMovzxEaxAl;
    BinJmpLabel(LblEnd);
    BinDefineLabel(LblFalse);
    BinMovRegImm32(REG_EAX, 1);
    BinDefineLabel(LblEnd);
    Exit;
  End;

  CodegenExpr(IRNodes[N].Left);
  BinPushReg(REG_EAX);
  CodegenExpr(IRNodes[N].Right);
  BinMovRegReg(REG_ECX, REG_EAX);
  BinPopReg(REG_EAX);

  Case Op Of
    Ord('+'):  BinAddEaxEcx;
    Ord('-'):  BinSubEaxEcx;
    Ord('*'):  BinImulEaxEcx;
    Ord('/'), KW_DIV: CgSafeDivMod(False);
    KW_MOD:    CgSafeDivMod(True);
    Ord('&'):  BinAndEaxEcx;
    Ord('|'):  BinOrEaxEcx;
    Ord('^'):  BinXorEaxEcxOp;
    TOK_SHL:   BinShlEaxCl;
    TOK_SHR:   BinSarEaxCl;
    TOK_EQ:    Begin BinCmpEaxEcx; BinSetccAl(CC_E);  BinMovzxEaxAl; End;
    TOK_NE:    Begin BinCmpEaxEcx; BinSetccAl(CC_NE); BinMovzxEaxAl; End;
    Ord('<'):  Begin BinCmpEaxEcx; BinSetccAl(CC_L);  BinMovzxEaxAl; End;
    Ord('>'):  Begin BinCmpEaxEcx; BinSetccAl(CC_G);  BinMovzxEaxAl; End;
    TOK_LE:    Begin BinCmpEaxEcx; BinSetccAl(CC_LE); BinMovzxEaxAl; End;
    TOK_GE:    Begin BinCmpEaxEcx; BinSetccAl(CC_GE); BinMovzxEaxAl; End;
  Else
    BinXorRegReg(REG_EAX);
  End;
End;

Procedure CodegenAssign(N: Integer);
Var LeftNode, Off, Op: Integer; Found: Boolean;
Begin
  LeftNode := IRNodes[N].Left;
  Op       := IRNodes[N].Tok;

  If IRNodes[LeftNode].Kind <> NK_IDENT Then Begin
    { cible non modelisee (champ, indexation...) : les deux cotes sont
      evalues pour leurs effets de bord, la valeur de l'expression
      d'affectation reste celle du membre de droite }
    CodegenExpr(IRNodes[N].Right);
    Exit;
  End;

  Off := CgVarOffset(IRNodes[LeftNode].Text, Found);

  If Op = Ord('=') Then Begin
    CodegenExpr(IRNodes[N].Right);
    If Found Then BinMovEbpDispEax(Off);
    Exit;
  End;

  If Found Then BinMovEaxEbpDisp(Off) Else BinXorRegReg(REG_EAX);
  BinPushReg(REG_EAX);
  CodegenExpr(IRNodes[N].Right);
  BinMovRegReg(REG_ECX, REG_EAX);
  BinPopReg(REG_EAX);
  Case Op Of
    TOK_PLUSEQ:  BinAddEaxEcx;
    TOK_MINUSEQ: BinSubEaxEcx;
    TOK_STAREQ:  BinImulEaxEcx;
    TOK_SLASHEQ: CgSafeDivMod(False);
  End;
  If Found Then BinMovEbpDispEax(Off);
End;

Procedure CodegenExpr(N: Integer);
Var A: Integer;
Begin
  If N = 0 Then Begin BinXorRegReg(REG_EAX); Exit; End;
  Case IRNodes[N].Kind Of
    NK_LIT_INT, NK_LIT_BOOL, NK_ENUMVAL: BinMovRegImm32(REG_EAX, IRNodes[N].NumVal);
    NK_LIT_FLOAT: BinMovRegImm32(REG_EAX, Round(IRNodes[N].FloatVal));
    NK_LIT_STR, NK_LIT_CHAR, NK_LIT_DATE: BinXorRegReg(REG_EAX);
    NK_IDENT:  CgLoadVar(IRNodes[N].Text);
    NK_THIS, NK_SUPER: BinXorRegReg(REG_EAX);
    NK_UNARY:  CodegenUnary(N);
    NK_POSTOP: CodegenPostop(N);
    NK_BINARY: CodegenBinary(N);
    NK_ASSIGN: CodegenAssign(N);
    NK_MEMBER: Begin CodegenExpr(IRNodes[N].Left); BinXorRegReg(REG_EAX); End;
    NK_INDEX:  Begin
      CodegenExpr(IRNodes[N].Left);
      CodegenExpr(IRNodes[N].Right);
      BinXorRegReg(REG_EAX);
    End;
    NK_CALL: CodegenCall(N);
    NK_NEW:  CodegenNew(N);
    NK_CONTLIT: Begin
      A := IRNodes[N].Right;
      While A <> 0 Do Begin
        CodegenExpr(A);
        A := IRNodes[A].NextArg;
      End;
      BinXorRegReg(REG_EAX);
    End;
  Else
    BinXorRegReg(REG_EAX);
  End;
End;

Procedure CodegenStmt(N: Integer); Forward;

Procedure CodegenIf(N: Integer);
Var LElse, LEnd: String;
Begin
  CodegenExpr(Stmts[N].ExprNode);
  BinCmpEaxImm32(0);
  LEnd := NewBinLabel('IfE');
  If Stmts[N].ElseStmt <> 0 Then Begin
    LElse := NewBinLabel('IfL');
    BinJccLabel(CC_E, LElse);
    CodegenStmt(Stmts[N].ThenStmt);
    BinJmpLabel(LEnd);
    BinDefineLabel(LElse);
    CodegenStmt(Stmts[N].ElseStmt);
  End Else Begin
    BinJccLabel(CC_E, LEnd);
    CodegenStmt(Stmts[N].ThenStmt);
  End;
  BinDefineLabel(LEnd);
End;

Procedure CodegenWhile(N: Integer);
Var LStart, LEnd, OldBreak, OldCont: String;
Begin
  LStart := NewBinLabel('WhS');
  LEnd   := NewBinLabel('WhE');
  OldBreak := CgBreakLabel; OldCont := CgContinueLabel;
  CgBreakLabel := LEnd; CgContinueLabel := LStart;
  BinDefineLabel(LStart);
  CodegenExpr(Stmts[N].ExprNode);
  BinCmpEaxImm32(0);
  BinJccLabel(CC_E, LEnd);
  CodegenStmt(Stmts[N].BodyStmt);
  BinJmpLabel(LStart);
  BinDefineLabel(LEnd);
  CgBreakLabel := OldBreak; CgContinueLabel := OldCont;
End;

Procedure CodegenDoWhile(N: Integer);
Var LStart, LCont, LEnd, OldBreak, OldCont: String;
Begin
  LStart := NewBinLabel('DoS');
  LCont  := NewBinLabel('DoC');
  LEnd   := NewBinLabel('DoE');
  OldBreak := CgBreakLabel; OldCont := CgContinueLabel;
  CgBreakLabel := LEnd; CgContinueLabel := LCont;
  BinDefineLabel(LStart);
  CodegenStmt(Stmts[N].BodyStmt);
  BinDefineLabel(LCont);
  CodegenExpr(Stmts[N].ExprNode);
  BinCmpEaxImm32(0);
  BinJccLabel(CC_NE, LStart);
  BinDefineLabel(LEnd);
  CgBreakLabel := OldBreak; CgContinueLabel := OldCont;
End;

Procedure CodegenFor(N: Integer);
Var LStart, LCont, LEnd, OldBreak, OldCont: String;
Begin
  If Stmts[N].ForInit <> 0 Then CodegenStmt(Stmts[N].ForInit);
  LStart := NewBinLabel('ForS');
  LCont  := NewBinLabel('ForC');
  LEnd   := NewBinLabel('ForE');
  OldBreak := CgBreakLabel; OldCont := CgContinueLabel;
  CgBreakLabel := LEnd; CgContinueLabel := LCont;
  BinDefineLabel(LStart);
  If Stmts[N].ExprNode <> 0 Then Begin
    CodegenExpr(Stmts[N].ExprNode);
    BinCmpEaxImm32(0);
    BinJccLabel(CC_E, LEnd);
  End;
  CodegenStmt(Stmts[N].BodyStmt);
  BinDefineLabel(LCont);
  If Stmts[N].ForIncr <> 0 Then CodegenExpr(Stmts[N].ForIncr);
  BinJmpLabel(LStart);
  BinDefineLabel(LEnd);
  CgBreakLabel := OldBreak; CgContinueLabel := OldCont;
End;

{ switch/case a etiquettes a plat (TODO 11) : une seule passe pose les
  comparaisons de dispatch (avant le corps), une seconde emet le corps
  avec ses etiquettes, ce qui reproduit naturellement le fall-through.
  La valeur du switch est rangee dans un emplacement EBP fixe reserve
  par methode (CgSwitchTempOffset) plutot que sur la pile CPU, pour
  eviter tout desequilibre de pile en cas de switches imbriques
  (leurs dispatchs ne s'executent jamais en meme temps). }
Procedure CodegenSwitch(N: Integer);
Var LEnd, DefaultLabel, OldBreak: String;
    Cur: Integer;
    HasDefault: Boolean;
Begin
  LEnd := NewBinLabel('SwE');
  OldBreak := CgBreakLabel;
  CgBreakLabel := LEnd;

  CodegenExpr(Stmts[N].ExprNode);
  BinMovEbpDispEax(CgSwitchTempOffset);

  HasDefault  := False;
  DefaultLabel := '';
  Cur := Stmts[N].FirstChild;
  While Cur <> 0 Do Begin
    If Stmts[Cur].Kind = SK_CASE Then Begin
      If Stmts[Cur].IsDefault Then Begin
        HasDefault := True;
        DefaultLabel := CaseLabel(Cur);
      End Else Begin
        CodegenExpr(Stmts[Cur].ExprNode);
        BinMovRegReg(REG_ECX, REG_EAX);
        BinMovEaxEbpDisp(CgSwitchTempOffset);
        BinCmpEaxEcx;
        BinJccLabel(CC_E, CaseLabel(Cur));
      End;
    End;
    Cur := Stmts[Cur].NextStmt;
  End;
  If HasDefault Then BinJmpLabel(DefaultLabel) Else BinJmpLabel(LEnd);

  Cur := Stmts[N].FirstChild;
  While Cur <> 0 Do Begin
    If Stmts[Cur].Kind = SK_CASE Then BinDefineLabel(CaseLabel(Cur))
    Else CodegenStmt(Cur);
    Cur := Stmts[Cur].NextStmt;
  End;

  BinDefineLabel(LEnd);
  CgBreakLabel := OldBreak;
End;

Procedure CodegenStmt(N: Integer);
Var Cur: Integer;
Begin
  If N = 0 Then Exit;
  Case Stmts[N].Kind Of
    SK_NONE, SK_EMPTY, SK_CASE: ;
    SK_BLOCK: Begin
      Cur := Stmts[N].FirstChild;
      While Cur <> 0 Do Begin
        CodegenStmt(Cur);
        Cur := Stmts[Cur].NextStmt;
      End;
    End;
    SK_EXPR: CodegenExpr(Stmts[N].ExprNode);
    SK_VARDECL: If Locals[Stmts[N].LocalIdx].HasInit Then Begin
      CodegenExpr(Locals[Stmts[N].LocalIdx].ExprNode);
      BinMovEbpDispEax(Locals[Stmts[N].LocalIdx].Offset);
    End;
    SK_IF:       CodegenIf(N);
    SK_SWITCH:   CodegenSwitch(N);
    SK_WHILE:    CodegenWhile(N);
    SK_DOWHILE:  CodegenDoWhile(N);
    SK_FOR:      CodegenFor(N);
    SK_BREAK:    If CgBreakLabel <> '' Then BinJmpLabel(CgBreakLabel);
    SK_CONTINUE: If CgContinueLabel <> '' Then BinJmpLabel(CgContinueLabel);
    SK_RETURN: Begin
      If Stmts[N].ExprNode <> 0 Then CodegenExpr(Stmts[N].ExprNode)
      Else BinXorRegReg(REG_EAX);
      BinJmpLabel(CgEpilogueLabel);
    End;
    SK_TRY: Begin
      { pas de veritable deroulement d'exception (portee reduite) :
        le bloc try s'execute normalement ; finally s'execute toujours
        a la suite puisqu'aucun throw ne devie jamais ce chemin ici }
      CodegenStmt(Stmts[N].BodyStmt);
      If Stmts[N].FinallyStmt <> 0 Then CodegenStmt(Stmts[N].FinallyStmt);
    End;
    SK_THROW: CodegenExpr(Stmts[N].ExprNode);
    SK_WHILESELECT, SK_SELECT, SK_DELETEFROM,
    SK_TTSBEGIN, SK_TTSCOMMIT, SK_TTSABORT: ;
  End;
End;

{ Corps d'une methode utilisateur reelle (BodyStmt <> 0) : prologue,
  remise a zero des locales scalaires (secutite : toute lecture avant
  premiere affectation vaut 0 plutot qu'une valeur de pile aleatoire),
  corps, epilogue avec nettoyage stdcall des parametres }
Procedure CodegenMethod(MIdx: Integer);
Var Base, I, LocalsSize, FrameSize, Clean: Integer;
Begin
  CgCurMethod      := MIdx;
  CgEpilogueLabel  := NewBinLabel('Ret');
  CgBreakLabel     := '';
  CgContinueLabel  := '';
  BinCurSec := BIN_SEC_TEXT;
  BinDefineLabel(MethodLabel(MIdx));

  Base := Methods[MIdx].LocalStart;
  If Methods[MIdx].LocalCount > 0 Then
    LocalsSize := -Locals[Base + Methods[MIdx].LocalCount - 1].Offset
  Else
    LocalsSize := 0;
  CgSwitchTempOffset := -(LocalsSize + CG_SWITCH_TEMP_SIZE);
  FrameSize := LocalsSize + CG_SWITCH_TEMP_SIZE;

  BinEmitPrologue(FrameSize);

  For I := 0 To Methods[MIdx].LocalCount - 1 Do
    If Not Locals[Base + I].IsArray Then Begin
      BinXorRegReg(REG_EAX);
      BinMovEbpDispEax(Locals[Base + I].Offset);
    End;

  CodegenStmt(Methods[MIdx].BodyStmt);

  BinDefineLabel(CgEpilogueLabel);
  Clean := 4 * Methods[MIdx].ParamCount;
  BinEmitEpilogueN(Clean);

  CgCurMethod := 0;
End;

{ static void main(Args) : point d'entree du programme X++ (job AOT) }
Function FindEntryPointMethod: Integer;
Var I: Integer;
Begin
  FindEntryPointMethod := 0;
  For I := 1 To MethodCount Do
    If (Methods[I].Name = 'main') And Methods[I].IsStatic And
       (Methods[I].BodyStmt <> 0) Then Begin
      FindEntryPointMethod := I;
      Exit;
    End;
End;

Procedure BinInitRuntimeData;
Begin
  BinCurSec := BIN_SEC_DATA;
  BinDefineLabel('_XPPD_Written');
  BinEmit32(0);
  BinCurSec := BIN_SEC_TEXT;
End;

{ _XPPRT_PutChar (TODO 26) : imprime le caractere passe dans AL sur la
  console. Convention interne (pas stdcall) : aucun argument empile,
  aucun nettoyage de pile au retour ; un tampon local d'un octet sert
  de lpBuffer a WriteFile. }
Procedure EmitPutCharHelper;
Begin
  BinCurSec := BIN_SEC_TEXT;
  BinDefineLabel('_XPPRT_PutChar');
  BinEmitPrologue(4);
  BinMovEbpDispAl(-1);
  BinLeaRegEbpDisp(REG_EDI, -1);
  BinPushImm32(-11);
  BinCallImportRaw('GetStdHandle');
  BinPushImm32(0);
  BinPushLabelAddr('_XPPD_Written');
  BinPushImm32(1);
  BinPushReg(REG_EDI);
  BinPushReg(REG_EAX);
  BinCallImportRaw('WriteFile');
  BinEmitEpilogueN(0);
End;

{ _XPPRT_PrintInt (TODO 26) : imprime l'entier signe passe dans EAX en
  decimal, sans zeros de tete (mais "0" pour la valeur nulle), suivi
  d'aucun separateur. Decomposition par 10 divisions non signees
  successives par des puissances de dix decroissantes (deroulees a la
  compilation, pas de boucle ni d'adressage indirect necessaire au-
  dela d'EBX/ESI utilises comme accumulateurs). EBX/ESI sont
  preserves explicitement : ils survivent aux appels a _XPPRT_PutChar
  (qui ne les utilise pas, et GetStdHandle/WriteFile les preservent
  par convention stdcall), mais on les restaure par prudence. }
Procedure EmitPrintIntHelper;
Const
  NDIV = 10;
Var
  Divisors: Array[1..NDIV] Of LongInt;
  K: Integer;
  LNonNeg, LSetFlag, LPrint, LSkip: String;
Begin
  Divisors[1]  := 1000000000; Divisors[2] := 100000000; Divisors[3] := 10000000;
  Divisors[4]  := 1000000;    Divisors[5] := 100000;    Divisors[6] := 10000;
  Divisors[7]  := 1000;       Divisors[8] := 100;       Divisors[9] := 10;
  Divisors[10] := 1;

  BinCurSec := BIN_SEC_TEXT;
  BinDefineLabel('_XPPRT_PrintInt');
  BinEmitPrologue(0);
  BinPushReg(REG_EBX);
  BinPushReg(REG_ESI);

  BinCmpEaxImm32(0);
  LNonNeg := NewBinLabel('PiNN');
  BinJccLabel(CC_GE, LNonNeg);
  BinNegEax;
  BinPushReg(REG_EAX);
  BinMovRegImm32(REG_EAX, Ord('-'));
  BinCallLabel('_XPPRT_PutChar');
  BinPopReg(REG_EAX);
  BinDefineLabel(LNonNeg);

  BinMovRegReg(REG_EBX, REG_EAX);
  BinMovRegImm32(REG_ESI, 0);

  For K := 1 To NDIV Do Begin
    BinMovRegReg(REG_EAX, REG_EBX);
    BinXorRegReg(REG_EDX);
    BinMovRegImm32(REG_ECX, Divisors[K]);
    BinDivReg(REG_ECX);
    BinMovRegReg(REG_EBX, REG_EDX);

    If Divisors[K] = 1 Then Begin
      BinAddAlImm8(Ord('0'));
      BinCallLabel('_XPPRT_PutChar');
    End Else Begin
      LSetFlag := NewBinLabel('PiSF');
      LPrint   := NewBinLabel('PiPr');
      LSkip    := NewBinLabel('PiSk');
      BinCmpRegImm8(REG_ESI, 0);
      BinJccLabel(CC_NE, LPrint);
      BinCmpEaxImm32(0);
      BinJccLabel(CC_NE, LSetFlag);
      BinJmpLabel(LSkip);
      BinDefineLabel(LSetFlag);
      BinMovRegImm32(REG_ESI, 1);
      BinDefineLabel(LPrint);
      BinAddAlImm8(Ord('0'));
      BinCallLabel('_XPPRT_PutChar');
      BinDefineLabel(LSkip);
    End;
  End;

  BinPopReg(REG_ESI);
  BinPopReg(REG_EBX);
  BinEmitEpilogueN(0);
End;

{ _XPPRT_Today (date reelle, extension apres TODO 26) : appelle
  GetLocalTime (KERNEL32) dans un tampon SYSTEMTIME local de 16 octets
  et encode la date reelle du systeme en un entier AAAAMMJJ (ex.
  4 juillet 2026 -> 20260704) renvoye dans EAX. Convention interne :
  aucun argument, aucun nettoyage de pile au retour. }
Procedure EmitTodayHelper;
Begin
  BinCurSec := BIN_SEC_TEXT;
  BinDefineLabel('_XPPRT_Today');
  BinEmitPrologue(16);
  BinLeaRegEbpDisp(REG_EDI, -16);
  BinPushReg(REG_EDI);
  BinCallImportRaw('GetLocalTime');

  BinMovzxRegEbpDispWord(REG_EAX, -16);  { wYear, offset 0 }
  BinMovRegImm32(REG_ECX, 10000);
  BinImulEaxEcx;
  BinPushReg(REG_EAX);

  BinMovzxRegEbpDispWord(REG_EAX, -14);  { wMonth, offset 2 }
  BinMovRegImm32(REG_ECX, 100);
  BinImulEaxEcx;
  BinPopReg(REG_ECX);
  BinAddEaxEcx;
  BinPushReg(REG_EAX);

  BinMovzxRegEbpDispWord(REG_EAX, -10);  { wDay, offset 6 }
  BinPopReg(REG_ECX);
  BinAddEaxEcx;

  BinEmitEpilogueN(0);
End;

{ _XPPRT_PrintDate (extension apres TODO 26) : imprime un entier
  AAAAMMJJ (produit par _XPPRT_Today) au format J/M/AAAA, en
  reutilisant _XPPRT_PrintInt pour chaque partie numerique (pas de
  zero de tete sur le jour/mois, ex. "4/7/2026"). EBX survit aux
  appels a _XPPRT_PrintInt/_XPPRT_PutChar (tous deux le preservent). }
Procedure EmitPrintDateHelper;
Begin
  BinCurSec := BIN_SEC_TEXT;
  BinDefineLabel('_XPPRT_PrintDate');
  BinEmitPrologue(0);
  BinPushReg(REG_EBX);
  BinMovRegReg(REG_EBX, REG_EAX);

  BinMovRegReg(REG_EAX, REG_EBX);
  BinXorRegReg(REG_EDX);
  BinMovRegImm32(REG_ECX, 100);
  BinDivReg(REG_ECX);                 { eax=AAAAMM, edx=JJ }
  BinMovRegReg(REG_EBX, REG_EAX);
  BinMovRegReg(REG_EAX, REG_EDX);
  BinCallLabel('_XPPRT_PrintInt');
  BinMovRegImm32(REG_EAX, Ord('/'));
  BinCallLabel('_XPPRT_PutChar');

  BinMovRegReg(REG_EAX, REG_EBX);
  BinXorRegReg(REG_EDX);
  BinMovRegImm32(REG_ECX, 100);
  BinDivReg(REG_ECX);                 { eax=AAAA, edx=MM }
  BinMovRegReg(REG_EBX, REG_EAX);
  BinMovRegReg(REG_EAX, REG_EDX);
  BinCallLabel('_XPPRT_PrintInt');
  BinMovRegImm32(REG_EAX, Ord('/'));
  BinCallLabel('_XPPRT_PutChar');

  BinMovRegReg(REG_EAX, REG_EBX);
  BinCallLabel('_XPPRT_PrintInt');

  BinPopReg(REG_EBX);
  BinEmitEpilogueN(0);
End;

{ Point d'entree binaire "start" : trampoline vers static void main(),
  suivi d'un ExitProcess(0) propre. Emis en tout premier dans .text
  pour que start soit bien a l'adresse EntryRVA=TextRVA ecrite par
  WritePE. }
Procedure GenerateCode;
Var EntryM, I: Integer;
Begin
  BinInit;
  BinInitRuntimeData;

  EntryM := FindEntryPointMethod;
  If EntryM = 0 Then Begin
    WriteLn('XPPCW32: aucune methode "static void main(Args ...)" trouvee, ',
            'generation de code annulee');
    Exit;
  End;

  BinCurSec := BIN_SEC_TEXT;
  BinDefineLabel('start');
  For I := 1 To Methods[EntryM].ParamCount Do BinPushImm32(0);
  BinCallLabel(MethodLabel(EntryM));
  BinPushImm32(0);
  BinCallImportRaw('ExitProcess');

  EmitPutCharHelper;
  EmitPrintIntHelper;
  EmitTodayHelper;
  EmitPrintDateHelper;

  For I := 1 To MethodCount Do
    If Methods[I].BodyStmt <> 0 Then CodegenMethod(I);

  BinResolveFixups;
End;

BEGIN
  ParseArgs;
  WriteLn('XPPCW32 v', XPPCW32_VERSION, ' (', XPPCW32_DATE,
          ') - Compilateur X++ (Axapta) -> 80386 PE Win32');
  If Opt.Verbose Then Begin
    WriteLn('Source : ', Opt.SrcFile);
    WriteLn('Sortie : ', Opt.OutFile);
    If Opt.EmitObj Then WriteLn('Format : OBJ COFF 32 bits')
    Else WriteLn('Format : EXE PE Win32');
    If Opt.EmitAsm Then WriteLn('ASM    : oui');
    If Opt.DebugMode Then WriteLn('Debug  : oui');
    If Opt.Warnings Then WriteLn('Warnings : oui');
  End;
  If Opt.DebugMode Then Begin
    WriteLn('XPPCW32: mode debug - dump des tokens');
    DumpTokens;
    Halt(EXIT_OK);
  End;
  WriteLn('XPPCW32: analyse de ', Opt.SrcFile);
  ParseProgram;
  ResolveProgram;
  ResolveEnums;
  ResolveStorage;
  ResolveVTables;
  ResolveInterfaceCoverage;
  ResolveSubscriptions;
  If Opt.Verbose Then Begin
    DumpClasses;
    DumpEnums;
    DumpLocals;
    DumpStatements;
    DumpVTables;
    DumpSubscriptions;
    DumpAotTables;
  End;
  If ParseErrors > 0 Then Begin
    WriteLn('XPPCW32: ', ParseErrors, ' erreur(s), abandon');
    Halt(EXIT_ERROR);
  End;
  WriteLn('XPPCW32: ', ClassCount, ' classe(s)/interface(s) et ', EnumCount,
          ' enum(s) analyses, resolus, alloues, mis en instructions, ',
          'appels/heritage/interfaces/exceptions/delegates/tables/',
          'requetes/CRUD/Query/collections/runtime verifies (TODO 05-23).');

  AsmActive := Opt.EmitAsm;
  If AsmActive Then Begin
    Assign(AsmOut, ChangeExt(Opt.OutFile, '.asm'));
    Rewrite(AsmOut);
    WriteLn(AsmOut, '; genere par XPPCW32 v', XPPCW32_VERSION,
                    ' a partir de ', Opt.SrcFile);
  End;

  GenerateCode;

  If AsmActive Then Begin
    Close(AsmOut);
    AsmActive := False;
    WriteLn('XPPCW32: ASM ecrit dans ', ChangeExt(Opt.OutFile, '.asm'));
  End;

  If BinCodeSize = 0 Then Halt(EXIT_ERROR);

  If Opt.EmitObj Then Begin
    WriteCOFF(Opt.OutFile);
    WriteLn('XPPCW32: OBJ COFF ecrit dans ', Opt.OutFile,
            ' (', BinCodeSize, ' octet(s) de code)');
  End Else Begin
    WritePE(Opt.OutFile);
    WriteLn('XPPCW32: EXE PE32 ecrit dans ', Opt.OutFile,
            ' (', BinCodeSize, ' octet(s) de code)');
  End;

  Halt(EXIT_OK);
END.
