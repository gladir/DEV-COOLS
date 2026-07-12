{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 0.1
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7 / Free Pascal 3.2)
  @description: Compilateur Delphi (Object Pascal classique) vers
                assembleur 80386 pour Windows 32 bits
  @license: MIT
}

(* ============================================================
  DELPHI.PAS - Compilateur Delphi (Object Pascal) vers
  assembleur 80386 pour Windows 32 bits
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .386 / .MODEL FLAT, PE Win32

  Par defaut produit un fichier .EXE (PE Windows 32 bits).
  Avec le parametre -obj, produit uniquement un fichier .OBJ (COFF).
  La production d un fichier .ASM lisible est optionnelle : elle
  n est generee que si le parametre -asm est explicitement fourni
  (jamais par defaut, quel que soit le mode -obj ou .EXE).

  Doit supporter la compilation de tous les exemples fournis dans
  SAMPLES\DELPHI\* (.pas unites, .dpr projets).

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - INFRASTRUCTURE ET OPTIONS                    [IMPLEMENTE]
         TOptions : SrcFile (.pas/.dpr), OutFile, Verbose, DebugMode,
           Warnings, AsmOutput (-asm), ObjOnly (-obj)
         ParseArgs : analyser argv
           source.pas|source.dpr [sortie.exe] [-v] [-d] [-w]
           [-asm] [-obj]
         FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
         Detecter l extension .pas (unite ou programme) ou .dpr
           (fichier projet Delphi)
         Par defaut : sortie .EXE (PE Win32)
         Avec -obj : sortie .OBJ uniquement (COFF), pas de .EXE
         Avec -asm : generer en plus un fichier .ASM lisible
           (compatible avec -obj comme avec le mode .EXE par defaut)
         Programme principal : validation des arguments, appel Run
         Version, Date, aide en ligne (option -h)

  TODO 02 - LEXEUR (TOKENS OBJECT PASCAL / DELPHI)        [A FAIRE]
         TTokenKind : TK_EOF, TK_INTEGER, TK_REAL, TK_STRING,
           TK_CHAR, TK_IDENT, TK_KEYWORD, TK_OP, TK_PUNCT
         Mots-cles Turbo Pascal herites (voir TPCW32) plus mots-cles
           Delphi additionnels :
           CLASS INTERFACE IMPLEMENTATION LIBRARY EXCEPT FINALLY
           TRY RAISE ON PROPERTY CONSTRUCTOR DESTRUCTOR PRIVATE
           PROTECTED PUBLIC PUBLISHED AUTOMATED VIRTUAL DYNAMIC
           OVERRIDE OVERLOAD REINTRODUCE ABSTRACT SEALED INHERITED
           IS AS OUT INLINE ASSEMBLER REGISTER SAFECALL STDCALL
           CDECL PASCAL EXPORT RESOURCESTRING THREADVAR PACKED
           INITIALIZATION FINALIZATION DEFAULT STORED READ WRITE
           INDEX NAME NODEFAULT CONTAINS REQUIRES EXPORTS
         LexScanString : litteraux 'abc', concatenation implicite
           via #nn, echappement '' pour l apostrophe
         LexScanNumber : entiers, hexadecimaux $FF, reels 3.14/1.5E3
         Commentaires : accolades, paren-etoile et //
         Mode debug -d : affichage de chaque token

  TODO 03 - PREPROCESSEUR ET DIRECTIVES DE COMPILATION    [A FAIRE]
         $DEFINE symbole / $UNDEF symbole
         $IFDEF / $IFNDEF / $IFOPT / $ELSE / $ENDIF / $IFEND
         $I fichier.inc ou $INCLUDE fichier.inc
         $APPTYPE CONSOLE (defaut) / GUI
         $R fichier.res : ressources -> stub (ignore avec avertissement)
         $M+/$M- : RTTI etendu pour classes -> stub minimal
         $H+/$H- : chaines longues (AnsiString) par defaut en Delphi
         $Z1/$Z2/$Z4 : taille des enumerations -> defaut 4 octets
         Symboles predefinis : WIN32, CPU386, MSWINDOWS,
           CONDITIONALEXPRESSIONS, VER<nnn> (version Delphi emulee)

  TODO 04 - LITTERAUX ET CONSTANTES                       [A FAIRE]
         Entiers decimaux et hexadecimaux $FF
         Reels : 3.14, 1.5E3
         Caracteres : #65, #$41, 'A'
         Chaines litterales -> AnsiString (voir TODO 20)
         Constantes typees : const X: Integer = 42
         Constantes ensemblistes : [1, 3..7, 10]
         Nil, True, False
         Expressions constantes evaluees a la compilation

  TODO 05 - TABLE DES SYMBOLES ET PORTEES                 [A FAIRE]
         TSymKind : SK_CONST, SK_TYPE, SK_VAR, SK_PARAM, SK_PROC,
           SK_FUNC, SK_FIELD, SK_METHOD, SK_UNIT, SK_LABEL,
           SK_PROPERTY, SK_CLASS, SK_INTERFACE
         SymAdd, SymFind, SymFindInScope, SymMangle
         Portees imbriquees (unite, classe, methode, bloc)
         Qualification Unit.Ident, Self.Champ, inherited Methode
         Enregistrement des identificateurs predefinis System :
           Integer, Cardinal, Int64, Byte, Word, Boolean, Char,
           string, TObject, Exception, TClass
         Procedures/fonctions predefinies de base (voir TODO 22)

  TODO 06 - SYSTEME DE TYPES DELPHI                       [A FAIRE]
         Types ordinaux : Integer, Cardinal, Int64, UInt64, Byte,
           Word, LongWord, Shortint, Smallint, Boolean, Char,
           WideChar
         Types reels : Single, Double, Extended, Currency, Comp
         Types chaine : AnsiString, WideString, UnicodeString,
           ShortString[n], PChar, PWideChar
         Variant : stub minimal (TVarData simplifie)
         Pointer, types enumeres (avec ou sans valeurs explicites),
           sous-intervalles (subrange)
         Tableaux statiques ARRAY[lo..hi] OF T et dynamiques
           ARRAY OF T (voir TODO 19)
         SET OF T (max 256 elements)
         Types procedure et method (of object) -> paire
           pointeur-code / pointeur-Self
         Types classe (class), interface (interface), record
         Compatibilite et conversion de types, typecast explicite

  TODO 07 - EMETTEUR DE CODE ASM 80386                    [A FAIRE]
         EmitOpen, EmitClose, EmitRaw, EmitLabel, EmitInstr,
           EmitComment, EmitBlankLine
         LabelGen global (compteur unique _DPL_NNNNN)
         Prefixes ASM : _DPV_ (variable), _DPF_ (fonction/methode),
           _DPK_ (constante chaine), _DPRT_ (runtime), _DPL_ (label),
           _DPA_ (tableau), _DPR_ (record), _DPE_ (enumeration),
           _DPC_ (classe/VMT), _DPI_ (interface), _DPU_ (unite)
         EmitHeader : .386 / .MODEL FLAT, STDCALL, EXTRN API Windows
           (memes bases que TPCW32 : ExitProcess, GetStdHandle,
           WriteFile, ReadFile, HeapAlloc/HeapFree, etc.)
         EmitDataSeg / EmitCodeSeg, EmitProlog / EmitEpilog
         Generation conditionnelle du fichier .ASM selon -asm

  TODO 08 - SEGMENT DE DONNEES, VMT ET TABLES D INTERFACE [A FAIRE]
         TDataRec : variables globales, constantes typees, chaines
         Table des methodes virtuelles (VMT) par classe :
           pointeur classe parente, nom de classe, taille d instance,
           table des methodes virtual/dynamic (offsets fixes)
         Table d interfaces par classe implementant une ou plusieurs
           interfaces : GUID, table de thunks vers les methodes
         Chaines litterales -> bloc AnsiString (voir TODO 20) avec
           label _DPK_N precedant les donnees

  TODO 09 - VARIABLES, AFFECTATIONS ET GESTION MEMOIRE    [A FAIRE]
         Variables globales (.DATA), locales (pile EBP), champs
           d instance (offset depuis Self)
         Parametres par valeur, VAR, CONST, OUT
         Affectation := avec gestion automatique du comptage de
           references pour AnsiString et interfaces (Inc/Dec ref,
           liberation si le compteur atteint zero)
         Affectation d objet (class) : simple copie de pointeur,
           sans comptage de references
         Affectation de record et de tableau statique : copie
           champ par champ ou REP MOVSD

  TODO 10 - EXPRESSIONS PRIMAIRES                         [A FAIRE]
         ParsePrimary : litteral, ident, appel de fonction/methode,
           typecast, New/Dispose, SizeOf
         Acces champ (expr.champ), acces methode d instance
           (obj.Methode), acces propriete (obj.Prop -> routage
           getter/setter, voir TODO 16)
         Self (implicite dans une methode), inherited (appel de la
           version parente d une methode)
         Operateurs is (test de classe a l execution via VMT) et
           as (cast verifie, leve une exception si incompatible)
         Dereferencement expr^, adresse @expr

  TODO 11 - EXPRESSIONS BINAIRES ET PRECEDENCE            [A FAIRE]
         Precedence identique a Turbo Pascal (NOT/@/unaire, puis
           * / DIV MOD AND SHL SHR, puis + - OR XOR,
           puis = <> < > <= >= IN)
         ParseExprPrec (boucle de Pratt)
         Arithmetique entiere et flottante, court-circuit AND/OR
         Comparaison de classes via is, cast TClasseCible(expr)
         Comparaison et concatenation de AnsiString (voir TODO 20)

  TODO 12 - ENTREES/SORTIES ET RTL MINIMALE (System/SysUtils) [A FAIRE]
         Write / WriteLn / Read / ReadLn sur la console (heritage
           Turbo Pascal, applications console $APPTYPE CONSOLE)
         Format(FmtStr, [args]) : sous-ensemble des specificateurs
           %d %s %f %x
         IntToStr, StrToInt, StrToIntDef, FloatToStr, StrToFloat
         Trim, UpperCase, LowerCase, CompareStr, CompareText

  TODO 13 - STRUCTURES DE CONTROLE                        [A FAIRE]
         If/Case/While/Repeat/For (identiques a Turbo Pascal)
         For..In (Delphi) : iteration sur tableau, chaine ou
           ensemble via variable d iteration typee
         Break / Continue / Exit
         Try..Finally : bloc de nettoyage garanti (voir TODO 18)
         Try..Except..On E: Classe Do : gestionnaire type par classe
           d exception (voir TODO 18)

  TODO 14 - PROCEDURES, FONCTIONS ET SURCHARGE            [A FAIRE]
         ParseProcDecl / ParseFuncDecl, parametres par valeur,
           VAR, CONST, OUT, parametres avec valeur par defaut
         Surcharge (overload) : resolution par signature au nombre
           et type des parametres
         Conventions d appel : register (par defaut en Delphi),
           stdcall, cdecl, pascal, safecall
         Result : variable implicite representant la valeur de
           retour d une fonction (alternative au nom de fonction)
         Forward, external (DLL), procedures/fonctions imbriquees
         Types procedure/method (of object) : appel indirect avec
           transmission du pointeur Self si methode d instance

  TODO 15 - CLASSES ET HERITAGE                           [A FAIRE]
         class ... end, heritage simple class(TParent)
         Sections de visibilite : private, protected, public,
           published, automated
         Constructor Create, Destructor Destroy, methodes de classe
           (class function/class procedure), methodes statiques
         Methodes virtual/dynamic/override, VMT/DMT (dynamic method
           table), Self implicite, inherited
         TObject minimal : Create, Free, ClassName, ClassType,
           InstanceSize, ClassParent
         Abstract (methode sans corps, verification a l instanciation
           potentielle d une classe abstraite -> avertissement)
         Sealed (classe non derivable -> verification a la compilation)

  TODO 16 - PROPRIETES (PROPERTY)                          [A FAIRE]
         property Nom: Type read Getter write Setter;
         Lecture -> appel de la methode/du champ Getter
         Ecriture -> appel de la methode/du champ Setter
         Propriete indexee (property Items[i: Integer]: T ...)
         Propriete par defaut (default property, acces obj[i])
         Default, stored, nodefault : specificateurs -> stubs
           conserves pour compatibilite syntaxique seulement

  TODO 17 - INTERFACES ET COM DE BASE                     [A FAIRE]
         interface IXxx ['{GUID}'] ... end
         class(TObject, IXxx, ...) : implementation d interface(s)
         Generation automatique de QueryInterface, _AddRef, _Release
         Table de thunks par interface implementee (voir TODO 08)
         Variables de type interface : comptage de references
           automatique (voir TODO 09)

  TODO 18 - GESTION DES EXCEPTIONS                         [A FAIRE]
         Try..Except..Finally, Raise, Raise; (relance)
         Hierarchie Exception minimale : Exception, EXxx courantes
           (EDivByZero, EInvalidCast, EAccessViolation, ERangeError)
         Exception.Message, Exception.ClassName
         Implementation via Structured Exception Handling (SEH)
           Win32 natif ou, a defaut, table de gestionnaires geree
           par le runtime (_DPRT_) avec deroulement de pile explicite
         Liberation automatique des objets exception non geres ->
           message d erreur non traite + ExitProcess

  TODO 19 - TABLEAUX, RECORDS ET ENSEMBLES (STATIQUE/DYNAMIQUE) [A FAIRE]
         Tableaux statiques : identiques a Turbo Pascal
         Tableaux dynamiques (Array of T) : SetLength, Length,
           High/Low, comptage de references et reallocation via
           _DPRT_ (GetMem/FreeMem/Move)
         Tableaux ouverts en parametre (array of T sans bornes)
         Records simples champ par champ ; support minimal des
           "advanced records" (methodes dans un record) en stub
         Set of T : union, intersection, difference, test IN

  TODO 20 - CHAINES DE CARACTERES (ANSISTRING/WIDESTRING)  [A FAIRE]
         AnsiString : bloc precede d un en-tete cache (compteur de
           references, longueur), copy-on-write, liberation
           automatique quand le compteur atteint zero
         Fonctions : Length, Copy, Delete, Insert, Pos, Concat,
           UpperCase, LowerCase, Trim, CompareStr/CompareText
         Concatenation + et comparaison avec gestion du refcount
         Conversion ShortString <-> AnsiString <-> PChar
         WideString/UnicodeString : stub minimal (stockage UTF-16,
           conversions de base uniquement)

  TODO 21 - INSTRUCTION ASM (BLOC ASSEMBLEUR EN LIGNE)     [A FAIRE]
         ParseAsmBlock : asm ... end
         Assembleur 80386 natif (pas de traduction 8086 necessaire,
           contrairement a TPCW32, car Delphi cible directement le
           32 bits) : MOV, ADD, SUB, CALL, PUSH, POP, Jcc, etc.
         Acces depuis le bloc asm aux variables Pascal, aux champs
           d instance (via Self) et aux parametres de la methode
           courante

  TODO 22 - UNITES RTL MINIMALES (SYSTEM, SYSUTILS, CLASSES) [A FAIRE]
         System : New, Dispose, GetMem, FreeMem, ReallocMem, Move,
           FillChar, Inc, Dec, Ord, Chr, High, Low, SizeOf, Abs,
           Sqr, Sqrt, Round, Trunc, Assigned, FreeAndNil
         SysUtils minimal : voir TODO 12 (IntToStr, Format, etc.),
           Exception et descendantes (voir TODO 18)
         Classes minimal (stub optionnel) : TList, TStringList
           avec l ensemble minimal de methodes utilise par les
           exemples de SAMPLES\DELPHI

  TODO 23 - FICHIERS PROJET (.dpr) ET UNITES (.pas)        [A FAIRE]
         Detection Program (.dpr ou .pas) vs Unit (.pas avec
           Interface/Implementation) vs Library (.dpr avec
           Library au lieu de Program)
         Fichier .dpr : Program Nom; uses Unit1 in 'Unit1.pas', ...;
           begin ... end. -> compilation multi-fichiers (chaque
           Unit1.pas compile puis lie ensemble)
         Fichier .pas unite : Unit Nom; Interface uses ...
           Implementation ... [Initialization ... Finalization ...]
           End. -> genere un .OBJ lie au programme principal
         Fichiers .dfm (formulaires VCL) : hors perimetre (pas de
           VCL graphique) -> avertissement et ignore si rencontre

  TODO 24 - GENERATION PE/OBJ (EXE PAR DEFAUT, OBJ SUR DEMANDE) [A FAIRE]
         Mode EXE (par defaut, aucun parametre requis) :
           Fichier PE complet (en-tete MZ + en-tete PE + sections
           .text/.data/.idata), Import Address Table, point d entree
         Mode OBJ (-obj, exclusif du mode EXE) :
           Fichier COFF, symboles publics/externes, sections
           .text/.data/.bss, relocations DIR32/REL32 (pour liaison
           ulterieure avec LINK.EXE ou avec d autres unites .OBJ)
         Fichier ASM (-asm, optionnel, cumulable avec EXE ou OBJ) :
           Texte assembleur MASM lisible, jamais genere sans ce
           parametre explicite
         VMT, tables d interfaces et donnees des chaines dans .DATA

  TODO 25 - VALIDATION : SUPPORT COMPLET DE SAMPLES\DELPHI\* [A FAIRE]
         Le compilateur doit compiler avec succes tous les fichiers
           .pas et .dpr presents dans SAMPLES\DELPHI\*
         Creer les exemples manquants necessaires pour couvrir au
           minimum chaque grande fonctionnalite des TODO 01 a 24 :
           programme console minimal, unite avec Interface/
           Implementation, hierarchie de classes avec heritage et
           methodes virtuelles, proprietes, interfaces, gestion
           d exceptions, chaines AnsiString, tableaux dynamiques,
           bloc asm inline
         Verification par compilation reelle (fpc -Mtp DELPHI.PAS
           puis DELPHI.EXE sur chaque exemple) avant de considerer
           un TODO comme [IMPLEMENTE]

  ============================================================ *)

Program DELPHI;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================ }
{ TODO 01 - INFRASTRUCTURE ET OPTIONS                [IMPLEMENTE] }
{ ============================================================ }

Const
 DELPHI_VERSION = '0.1';
 DELPHI_DATE    = '2026';

 EXIT_OK    = 0;
 EXIT_ERROR = 1;
 EXIT_USAGE = 2;

Type
 TString = String;

 TOptions = Record
  SrcFile   : TString;   { fichier source (.pas ou .dpr)         }
  OutFile   : TString;   { fichier sortie (.exe ou .obj)         }
  Verbose   : Boolean;   { -v : banniere et statistiques         }
  DebugMode : Boolean;   { -d : affichage de chaque token        }
  Warnings  : Boolean;   { -w : afficher les avertissements      }
  AsmOutput : Boolean;   { -asm : produire aussi un .ASM lisible }
  ObjOnly   : Boolean;   { -obj : produire seulement un .OBJ     }
 End;

Var
 { Options }
 Opts : TOptions;

 { Compteurs generaux }
 ErrorCount : Integer;
 WarnCount  : Integer;
 TotalLines : LongInt;

 { Fichier de sortie interne (pour future emission) }
 OutF     : Text;
 OutFOpen : Boolean;

{ ------------------------------------------------------------ }
{ Fonctions utilitaires                                        }
{ ------------------------------------------------------------ }

Function StrUpperCase(Const S: TString): TString;
Var
 I   : Integer;
 Tmp : TString;
Begin
 Tmp := S;
 For I := 1 To Length(Tmp) Do
  If (Tmp[I] >= 'a') And (Tmp[I] <= 'z') Then
   Tmp[I] := Chr(Ord(Tmp[I]) - 32);
 StrUpperCase := Tmp;
End;

{ Retourne l extension d un chemin (avec le point, en minuscules) }
Function ExtractExt(Const Path: TString): TString;
Var
 I, LastDot, LastSep: Integer;
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
  ExtractExt := StrUpperCase(Copy(Path, LastDot,
                  Length(Path) - LastDot + 1))
 Else
  ExtractExt := '';
End;

{ Remplace l extension d un chemin }
Function ReplaceExt(Const Path, NewExt: TString): TString;
Var
 I, LastDot, LastSep: Integer;
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

{ ------------------------------------------------------------ }
{ FatalError / WarnMsg                                         }
{ ------------------------------------------------------------ }

Procedure FatalError(Const Msg: TString);
Begin
 WriteLn('DELPHI: FATAL: ', Msg);
 If OutFOpen Then
 Begin
  Close(OutF);
  OutFOpen := False;
 End;
 Halt(EXIT_ERROR);
End;

Procedure WarnMsg(Const Msg: TString);
Begin
 If Not Opts.Warnings Then Exit;
 WriteLn('DELPHI: warning: ', Msg);
 Inc(WarnCount);
End;

{ ------------------------------------------------------------ }
{ InitOptions                                                  }
{ ------------------------------------------------------------ }

Procedure InitOptions;
Begin
 Opts.SrcFile   := '';
 Opts.OutFile   := '';
 Opts.Verbose   := False;
 Opts.DebugMode := False;
 Opts.Warnings  := False;
 Opts.AsmOutput := False;
 Opts.ObjOnly   := False;
End;

{ ------------------------------------------------------------ }
{ ShowHelp                                                     }
{ ------------------------------------------------------------ }

Procedure ShowHelp;
Begin
 WriteLn('DELPHI v', DELPHI_VERSION, ' (', DELPHI_DATE,
         ') - Compilateur Delphi vers 80386 (Windows PE 32 bits)');
 WriteLn('DELPHI - Cette commande permet de lancer le compilateur ',
         'Delphi (Object Pascal) pour l''assembleur du microprocesseur ',
         '80386 (en executable Windows 32 bits).');
 WriteLn;
 WriteLn('Syntaxe : DELPHI [options] <source.pas|source.dpr> [options]');
 WriteLn;
 WriteLn('Sortie :');
 WriteLn('  Par defaut un .EXE (PE Windows 32 bits)');
 WriteLn('  -obj           Produire seulement un fichier .OBJ (COFF)');
 WriteLn('  -asm           Produire egalement un fichier .ASM lisible');
 WriteLn;
 WriteLn('General :');
 WriteLn('  -v             Mode verbeux (banniere + statistiques)');
 WriteLn('  -d             Debug tokens (affiche chaque token)');
 WriteLn('  -w             Afficher les avertissements');
 WriteLn('  -h, --help, /? Afficher cette aide');
 WriteLn;
 WriteLn('Exemples :');
 WriteLn('  DELPHI hello.pas');
 WriteLn('  DELPHI hello.pas hello.exe -v');
 WriteLn('  DELPHI project.dpr -asm');
 WriteLn('  DELPHI unit1.pas -obj -w');
 Halt(EXIT_OK);
End;

{ ------------------------------------------------------------ }
{ ParseArgs                                                    }
{ ------------------------------------------------------------ }

Procedure ParseArgs;
Var
 I   : Integer;
 Arg : TString;
 Ext : TString;
Begin
 InitOptions;
 If ParamCount = 0 Then
  ShowHelp;

 I := 1;
 While I <= ParamCount Do
 Begin
  Arg := ParamStr(I);

  If (Arg = '-h') Or (Arg = '--help') Or (Arg = '/?') Or
     (Arg = '/h') Or (Arg = '/H') Then
   ShowHelp
  Else If Arg = '-v' Then
   Opts.Verbose := True
  Else If Arg = '-d' Then
   Opts.DebugMode := True
  Else If Arg = '-w' Then
   Opts.Warnings := True
  Else If Arg = '-asm' Then
   Opts.AsmOutput := True
  Else If Arg = '-obj' Then
   Opts.ObjOnly := True
  Else If (Length(Arg) > 0) And (Arg[1] = '-') Then
   FatalError('Option inconnue: ' + Arg)
  Else
  Begin
   { Argument positionnel : fichier source ou sortie }
   If Opts.SrcFile = '' Then
    Opts.SrcFile := Arg
   Else If Opts.OutFile = '' Then
    Opts.OutFile := Arg
   Else
    FatalError('Argument inattendu: ' + Arg);
  End;

  Inc(I);
 End;

 { Validation : fichier source requis }
 If Opts.SrcFile = '' Then
 Begin
  WriteLn('DELPHI: fichier source manquant');
  ShowHelp;
 End;

 { Verifier l extension .pas ou .dpr }
 Ext := ExtractExt(Opts.SrcFile);
 If (Ext <> '.PAS') And (Ext <> '.DPR') Then
  WarnMsg('extension attendue .pas ou .dpr, trouvee: ' + Ext);

 { Fichier de sortie par defaut }
 If Opts.OutFile = '' Then
 Begin
  If Opts.ObjOnly Then
   Opts.OutFile := ReplaceExt(Opts.SrcFile, '.obj')
  Else
   Opts.OutFile := ReplaceExt(Opts.SrcFile, '.exe');
 End;
End;

{ ------------------------------------------------------------ }
{ ShowBanner / ShowStats                                       }
{ ------------------------------------------------------------ }

Procedure ShowBanner;
Begin
 If Not Opts.Verbose Then Exit;
 WriteLn('DELPHI v', DELPHI_VERSION, ' (', DELPHI_DATE,
         ') - Compilateur Delphi -> 80386 PE Win32');
 WriteLn('Source   : ', Opts.SrcFile);
 WriteLn('Sortie   : ', Opts.OutFile);
 If Opts.AsmOutput Then
  WriteLn('ASM      : ', ReplaceExt(Opts.OutFile, '.asm'));
 If Opts.ObjOnly Then
  WriteLn('Mode     : OBJ seulement (COFF)')
 Else
  WriteLn('Mode     : EXE (PE Win32)');
 WriteLn;
End;

Procedure ShowStats;
Begin
 If Not Opts.Verbose Then Exit;
 WriteLn;
 WriteLn('--- Statistiques ---');
 WriteLn('Lignes analysees : ', TotalLines);
 WriteLn('Erreurs          : ', ErrorCount);
 WriteLn('Avertissements   : ', WarnCount);
End;

{ ------------------------------------------------------------ }
{ Cleanup                                                      }
{ ------------------------------------------------------------ }

Procedure Cleanup;
Begin
 If OutFOpen Then
 Begin
  Close(OutF);
  OutFOpen := False;
 End;
End;

{ ------------------------------------------------------------ }
{ Run - point d entree de la compilation                       }
{ Lexeur, analyseur syntaxique et generateur de code seront     }
{ ajoutes par les TODO 02 et suivants. Pour l instant, Run se   }
{ contente de valider que le fichier source existe et d annoncer }
{ que la compilation elle-meme n est pas encore implementee.    }
{ ------------------------------------------------------------ }

Procedure Run;
Var
 SrcF : Text;
Begin
 ErrorCount := 0;
 WarnCount  := 0;
 TotalLines := 0;
 OutFOpen   := False;

 {$I-}
 Assign(SrcF, Opts.SrcFile);
 Reset(SrcF);
 {$I+}
 If IOResult <> 0 Then
  FatalError('impossible d''ouvrir le fichier source: ' + Opts.SrcFile);
 Close(SrcF);

 ShowBanner;
 WriteLn('DELPHI: TODO 01 (infrastructure et options) implemente.');
 WriteLn('DELPHI: lexeur/analyseur/generateur de code non encore ',
         'implementes (voir TODO 02 et suivants).');
 ShowStats;
 Cleanup;
End;

{ ============================================================ }
{ Programme principal                                          }
{ ============================================================ }

Begin
 ParseArgs;
 Run;
 Halt(EXIT_OK);
End.

