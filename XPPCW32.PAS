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

  TODO 07 - TYPES COMPOSES : TABLEAUX, CONTAINERS, ENUMS
            int/str/... tab[N] (tableaux fixes 1-indexes), container
            (liste heterogene, operateur +=, con2Str, conLen, conPeek,
            conIns, conDel), enum (valeurs nommees accedees via ::,
            ex. CustVendorBlocked::No).

  TODO 08 - VARIABLES, CONSTANTES ET ALLOCATION
            Declaration de variables locales (offsets EBP) et de champs
            de classe (offsets d'instance), valeurs par defaut (0, "",
            false, date nulle), litteraux, evaluation constante simple.

  TODO 09 - EXPRESSIONS ET OPERATEURS
            Priorites X++ (assignation, logique, comparaison, bit,
            additif, multiplicatif, unaire, acces membre/indexation),
            evaluation en IR typee, promotion int<->real.

  TODO 10 - INSTRUCTIONS DE BASE ET IF/ELSE
            Bloc d'instructions, affectation, appel de methode,
            instruction vide (;), if/else if/else, evaluation
            paresseuse de && et ||.

  TODO 11 - SWITCH/CASE
            switch(expr) suivi d'un bloc avec case val: ... break;
            case v1: case v2: ... default: ..., enchainement explicite
            (fall-through) et verification des valeurs constantes de
            case.

  TODO 12 - BOUCLES WHILE, DO-WHILE, FOR
            while(cond) suivi d'un bloc, do ... while(cond); suivi d'un
            bloc, for(init; cond; incr) suivi d'un bloc, break,
            continue, boucles imbriquees.

  TODO 13 - METHODES ET PARAMETRES
            Declaration de methodes (public/private/static), parametres
            typés, valeur de retour, recursion, verification d'arite et
            de types a chaque appel.

  TODO 14 - HERITAGE (EXTENDS) ET POLYMORPHISME
            extends, super(...), redefinition de methode, resolution
            dynamique via une table de methodes virtuelles par classe,
            appel du constructeur parent.

  TODO 15 - INTERFACES (IMPLEMENTS)
            Declaration d'interface, implements multiple, verification
            que toutes les methodes de l'interface sont implementees,
            appel polymorphe via une variable typee interface.

  TODO 16 - GESTION DES EXCEPTIONS (TRY/CATCH/THROW)
            try suivi d'un bloc, catch (Exception::Xxx) suivi d'un bloc,
            catch generique suivi d'un bloc, throw error("msg"),
            Exception::Error/Warning/Internal, deroulement de pile
            (unwind) lors de la propagation.

  TODO 17 - DELEGATES ET GESTIONNAIRES D'EVENEMENTS
            delegate void Nom(params) suivi d'un bloc, appel
            this.Nom(...), attribut SubscribesTo(classStr(Classe),
            delegateStr(Classe, Nom)) sur une methode static, table de
            liaison delegate->abonnes generee au link-time, invocation
            de tous les abonnes.

  TODO 18 - MODELE DE TABLE (AOT SIMULE) ET METADONNEES
            Definition interne minimale des tables standard utilisees
            par les samples (CustTable, CustGroup : champs et cles),
            tableNum/fieldNum, representation memoire d'un buffer
            d'enregistrement (recordbuffer).

  TODO 19 - WHILE SELECT / SELECT ET REQUETES SIMPLES
            while select var [order by champ] [where condition] suivi
            d'un bloc, select [forUpdate] var where condition;,
            traduction en boucle d'iteration sur un stockage de table
            interne (tableau/fichier en memoire).

  TODO 20 - CRUD ET TRANSACTIONS (INSERT/UPDATE/DELETE/TTS)
            .insert()/.update()/.delete()/.clear(), delete_from ...
            where ..., ttsBegin/ttsCommit/ttsAbort avec pile de
            transactions imbricables et retour arriere en memoire.

  TODO 21 - QUERY, QUERYBUILDDATASOURCE, QUERYRUN
            new Query(), addDataSource(tableNum), addRange(fieldNum),
            .value(), new QueryRun(query), .next(), .get(tableNum),
            SysQuery::valueNotEmpty minimal.

  TODO 22 - COLLECTIONS RUNTIME : MAP ET LIST
            new Map(Types::X, Types::Y) / new List(Types::X),
            insert/addEnd, getEnumerator, MapEnumerator/ListEnumerator,
            moveNext/current/currentKey/currentValue, elements().

  TODO 23 - FONCTIONS RUNTIME NATIVES (STR/DATE/DIVERS)
            strFmt, strLen, strUpr, strLwr, subStr, strFind, strDel,
            strIns, strLTrim, strRTrim, con2Str, str2Date, today,
            mthOfYr, mthName, newGuid, guid2Str, info(), print/pause
            herites d'Axapta 2.x.

  TODO 24 - GENERATION ASM 80386, OBJ COFF ET LIEN EXE
            Writer ASM 80386 optionnel (labels stables, sections
            .text/.data/.bss, commentaires de diagnostic), writer OBJ
            COFF i386 minimal (sections, table de symboles, relocations
            REL32/DIR32), lien .OBJ -> .EXE PE32 par defaut avec point
            d'entree et imports minimaux (kernel32/msvcrt ou runtime
            interne).

  TODO 25 - SUITE DE VALIDATION SAMPLES\XPP\* ET STABILISATION
            Compiler et executer les 20 fichiers SAMPLES\XPP\*.xpp
            (01_hello.xpp a 20_map_and_list.xpp), verifier le
            comportement par defaut (.EXE), -obj (.OBJ seul) et -asm
            (.ASM produit en plus), comparer les sorties info()
            attendues, garantir la compatibilite Turbo Pascal/Free
            Pascal (directive MODE TP) et corriger les regressions.
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
  Else If S = 'enum'     Then IsKeyword := KW_ENUM;
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

Type
  TFieldInfo = Record
    ClassIdx: Integer;
    Name:     String;
    TypeName: String;
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
  End;
  TMethodTable = Array[1..MAX_METHOD] Of TMethodInfo;

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
  End;
  TClassTable = Array[1..MAX_CLASS] Of TClassInfo;

  TImplementsEntry = Record
    Name:        String;
    ResolvedIdx: Integer;   { resolu par TODO 06, 0 tant qu'inconnu }
  End;
  TImplementsTable = Array[1..MAX_IMPLEMENTS_TOTAL] Of TImplementsEntry;

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

Procedure AddField(ClassIdx: Integer; TypeName, FName: String);
Begin
  If FieldCount >= MAX_FIELD_TOTAL Then
    FatalError('trop de champs declares (limite ' + ItoS(MAX_FIELD_TOTAL) + ')');
  Inc(FieldCount);
  Fields[FieldCount].ClassIdx := ClassIdx;
  Fields[FieldCount].Name     := FName;
  Fields[FieldCount].TypeName := TypeName;
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

{ Ignore le corps d'une methode : le brace ouvrant a deja ete consomme
  par l'appelant. Sera remplace par un vrai appel au parseur
  d'instructions une fois les TODO 10 a 12 en place. }
Procedure SkipMethodBody;
Var Depth: Integer;
Begin
  Depth := 1;
  While (Depth > 0) And (CurTokType <> TOK_EOF) Do Begin
    If CurTokType = Ord('{') Then Inc(Depth)
    Else If CurTokType = Ord('}') Then Dec(Depth);
    LexNextToken;
  End;
End;

{ Ignore un attribut entre crochets, ex. SubscribesTo(...) ; le
  cablage semantique reel viendra avec les delegates (TODO 17) }
Procedure SkipAttribute;
Var Depth: Integer;
Begin
  Depth := 0;
  Repeat
    If CurTokType = Ord('[') Then Inc(Depth)
    Else If CurTokType = Ord(']') Then Dec(Depth);
    LexNextToken;
  Until (Depth = 0) Or (CurTokType = TOK_EOF);
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

{ Champ : TypeName deja lu, Name est le premier nom ; accepte une
  liste separee par des virgules partageant le meme type }
Procedure ParseFieldRest(ClassIdx: Integer; TypeName, FirstName: String);
Begin
  AddField(ClassIdx, TypeName, FirstName);
  While AcceptTok(Ord(',')) Do Begin
    If CurTokType = TOK_IDENT Then Begin
      AddField(ClassIdx, TypeName, CurTokStr);
      LexNextToken;
    End Else
      ParseError('nom de champ attendu, trouve ' + TokenName(CurTokType));
  End;
  Expect(Ord(';'), ';');
End;

{ Methode : parametres entre parentheses, puis soit une simple
  signature terminee par ; (interface), soit un corps ignore }
Procedure ParseMethodRest(ClassIdx: Integer; Visibility: Integer;
                           IsStatic: Boolean; RetType, Name: String);
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
    SkipMethodBody;
  End;
End;

{ Membre de classe/interface : attribut optionnel, delegate, ou
  membre normal (champ ou methode) selon ce qui suit le type/nom }
Procedure ParseMember(ClassIdx: Integer);
Var
  IsStatic:   Boolean;
  Visibility: Integer;
  TypeName:   String;
  Name:       String;
  MIdx:       Integer;
Begin
  If CurTokType = Ord('[') Then SkipAttribute;

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
    SkipMethodBody;
    Exit;
  End;

  ParseModifiers(IsStatic, Visibility);
  TypeName := ParseTypeName;
  Name     := ParseMemberName;

  If CurTokType = Ord('(') Then
    ParseMethodRest(ClassIdx, Visibility, IsStatic, TypeName, Name)
  Else
    ParseFieldRest(ClassIdx, TypeName, Name);
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
  ParseErrors     := 0;
  LexInit(Opt.SrcFile);
  LexNextToken;
  While CurTokType <> TOK_EOF Do
    ParseClassOrInterface;
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
    For J := 0 To Classes[I].FieldCount - 1 Do
      WriteLn('    champ   ', Fields[Base + J].TypeName, ' ', Fields[Base + J].Name);

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
    Cur := Classes[Cur].ParentIdx;
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
  If Opt.Verbose Then DumpClasses;
  If ParseErrors > 0 Then Begin
    WriteLn('XPPCW32: ', ParseErrors, ' erreur(s), abandon');
    Halt(EXIT_ERROR);
  End;
  WriteLn('XPPCW32: ', ClassCount, ' classe(s)/interface(s) analysee(s) et ',
          'resolue(s) (TODO 05-06) - expressions/instructions/codegen a ',
          'venir (TODO 07 et suivants).');
  Halt(EXIT_OK);
END.
