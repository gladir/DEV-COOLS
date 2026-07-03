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

  TODO 03 - LEXER X++ (TOKENISEUR)
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

  TODO 04 - MOTS-CLES ET TYPES DE BASE X++
            IsKeyword : class interface extends implements public
              private protected static void new this super if else
              switch case default break continue while do for return
              try catch throw finally delegate container select
              while select insert update delete ttsbegin ttscommit
              ttsabort order by group by exists join.
            Types scalaires : int, real, str, boolean, date, guid,
              anytype, void, container, enum.

  TODO 05 - DECLARATIONS DE CLASSES ET D'INTERFACES (PARSER)
            class Nom [extends Parent] [implements Iface1, Iface2] suivi
            d'un bloc, interface Nom regroupant des signatures de
            methodes, champs typés, methodes public/private/protected/
            static, constructeur new(parametres).

  TODO 06 - TABLE DES SYMBOLES ET PORTEES
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
  WriteLn('XPPCW32: infrastructure (TODO 01) en place - lexer/parser/',
          'codegen a venir (TODO 02 et suivants).');
  Halt(EXIT_OK);
END.
