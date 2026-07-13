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

  TODO 02 - LEXEUR (TOKENS OBJECT PASCAL / DELPHI)        [IMPLEMENTE]
         TTokenKind : TK_EOF, TK_INTEGER, TK_REAL, TK_STRING,
           TK_CHAR, TK_IDENT, TK_KEYWORD, TK_OP, TK_PUNCT
         Mots-cles reserves Turbo Pascal herites (voir TPCW32) plus
           mots-cles reserves Delphi additionnels :
           CLASS INTERFACE IMPLEMENTATION LIBRARY EXCEPT FINALLY
           TRY RAISE ON PROPERTY CONSTRUCTOR DESTRUCTOR INHERITED
           IS AS OUT INLINE RESOURCESTRING THREADVAR PACKED
           INITIALIZATION FINALIZATION EXPORTS
         Directives Delphi (IsDirective) : identificateurs valides
           ailleurs dans le programme (ex: property Name: ...),
           reconnus par leur texte seulement au bon endroit
           grammatical, pas comme mots reserves du lexeur :
           PRIVATE PROTECTED PUBLIC PUBLISHED AUTOMATED VIRTUAL
           DYNAMIC OVERRIDE OVERLOAD REINTRODUCE ABSTRACT SEALED
           ASSEMBLER REGISTER SAFECALL STDCALL CDECL PASCAL EXPORT
           DEFAULT STORED READ WRITE INDEX NAME NODEFAULT CONTAINS
           REQUIRES
         LexScanString : litteraux 'abc', concatenation implicite
           via #nn, echappement '' pour l apostrophe
         LexScanNumber : entiers, hexadecimaux $FF, reels 3.14/1.5E3
         Commentaires : accolades, paren-etoile et //
         Mode debug -d : affichage de chaque token

  TODO 03 - PREPROCESSEUR ET DIRECTIVES DE COMPILATION    [IMPLEMENTE]
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

  TODO 04 - LITTERAUX ET CONSTANTES                       [IMPLEMENTE]
         Entiers decimaux et hexadecimaux $FF
         Reels : 3.14, 1.5E3
         Caracteres : #65, #$41, 'A'
         Chaines litterales -> AnsiString (voir TODO 20)
         Constantes typees : const X: Integer = 42
         Constantes ensemblistes : [1, 3..7, 10]
         Nil, True, False
         Expressions constantes evaluees a la compilation

  TODO 05 - TABLE DES SYMBOLES ET PORTEES                 [IMPLEMENTE]
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

  TODO 06 - SYSTEME DE TYPES DELPHI                       [IMPLEMENTE]
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

  TODO 07 - EMETTEUR DE CODE ASM 80386                    [IMPLEMENTE]
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

  TODO 08 - SEGMENT DE DONNEES, VMT ET TABLES D INTERFACE [IMPLEMENTE]
         TDataRec : variables globales, constantes typees, chaines
         Table des methodes virtuelles (VMT) par classe :
           pointeur classe parente, nom de classe, taille d instance,
           table des methodes virtual/dynamic (offsets fixes)
         Table d interfaces par classe implementant une ou plusieurs
           interfaces : GUID, table de thunks vers les methodes
         Chaines litterales -> bloc AnsiString (voir TODO 20) avec
           label _DPK_N precedant les donnees

  TODO 09 - VARIABLES, AFFECTATIONS ET GESTION MEMOIRE    [IMPLEMENTE]
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

  TODO 10 - EXPRESSIONS PRIMAIRES                         [IMPLEMENTE]
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

  TODO 11 - EXPRESSIONS BINAIRES ET PRECEDENCE            [IMPLEMENTE]
         Precedence identique a Turbo Pascal (NOT/@/unaire, puis
           * / DIV MOD AND SHL SHR, puis + - OR XOR,
           puis = <> < > <= >= IN)
         ParseExprPrec (boucle de Pratt)
         Arithmetique entiere et flottante, court-circuit AND/OR
         Comparaison de classes via is, cast TClasseCible(expr)
         Comparaison et concatenation de AnsiString (voir TODO 20)

  TODO 12 - ENTREES/SORTIES ET RTL MINIMALE (System/SysUtils) [IMPLEMENTE]
         Write / WriteLn / Read / ReadLn sur la console (heritage
           Turbo Pascal, applications console $APPTYPE CONSOLE)
         Format(FmtStr, [args]) : sous-ensemble des specificateurs
           %d %s %f %x
         IntToStr, StrToInt, StrToIntDef, FloatToStr, StrToFloat
         Trim, UpperCase, LowerCase, CompareStr, CompareText

  TODO 13 - STRUCTURES DE CONTROLE                        [IMPLEMENTE]
         If/Case/While/Repeat/For (identiques a Turbo Pascal)
         For..In (Delphi) : iteration sur tableau, chaine ou
           ensemble via variable d iteration typee
         Break / Continue / Exit
         Try..Finally : bloc de nettoyage garanti (voir TODO 18)
         Try..Except..On E: Classe Do : gestionnaire type par classe
           d exception (voir TODO 18)

  TODO 14 - PROCEDURES, FONCTIONS ET SURCHARGE            [IMPLEMENTE]
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

  TODO 15 - CLASSES ET HERITAGE                           [IMPLEMENTE]
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

{ Retourne le repertoire d un chemin (avec le separateur final) }
Function ExtractDir(Const Path: TString): TString;
Var
 I, LastSep: Integer;
Begin
 LastSep := 0;
 For I := 1 To Length(Path) Do
  If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
   LastSep := I;
 If LastSep > 0 Then
  ExtractDir := Copy(Path, 1, LastSep)
 Else
  ExtractDir := '';
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

{ ============================================================ }
{ TODO 02 - LEXEUR (TOKENS OBJECT PASCAL / DELPHI)   [IMPLEMENTE] }
{ ============================================================ }

Const
 MAX_STR = 255;

Type
 TTokenKind = (
  TK_EOF,           { fin de fichier                       }
  TK_INTEGER,       { litteral entier 42 $FF               }
  TK_REAL,          { litteral reel 3.14 1.5E3             }
  TK_STRING,        { litteral chaine 'hello'              }
  TK_CHAR,          { litteral caractere #65 #$41          }
  TK_IDENT,         { identificateur (non-mot-cle)         }
  TK_KEYWORD,       { mot-cle Object Pascal reconnu        }
  TK_OP,            { operateur := + - * / = <> < > etc.   }
  TK_PUNCT          { ponctuation ; , ( ) [ ] . ..         }
 );

 TToken = Record
  Kind    : TTokenKind;
  Val     : TString;      { valeur textuelle brute             }
  IntVal  : LongInt;      { valeur entiere (TK_INTEGER/CHAR)   }
  RealVal : Real;         { valeur reelle (TK_REAL)            }
  Line    : Integer;      { ligne source (1-base)              }
  Col     : Integer;      { colonne source (1-base)            }
 End;

Var
 { Lexeur }
 LexSrcF   : Text;          { handle du fichier source           }
 LexOpened : Boolean;       { fichier ouvert ?                   }
 LexLine   : TString;       { ligne courante                     }
 LexLineNo : Integer;       { numero de ligne courante           }
 LexColNo  : Integer;       { colonne courante dans LexLine      }
 LexEOF    : Boolean;       { fin de fichier atteinte ?          }
 CurToken  : TToken;        { token courant                      }

 { TODO 03 : preprocesseur et inclusions }
 LexSrcFName    : TString;                  { chemin du fichier courant }
 DefineTab      : Array[0..63] Of TString;
 DefineCount    : Integer;
 IncSavedFName  : Array[0..7] Of TString;
 IncSavedLine   : Array[0..7] Of TString;
 IncSavedLineNo : Array[0..7] Of Integer;
 IncSavedColNo  : Array[0..7] Of Integer;
 IncSavedEOF    : Array[0..7] Of Boolean;
 IncTop         : Integer;
 OptIO          : Boolean;    { $I+/$I- : verification E/S           }
 OptRange       : Boolean;    { $R+/$R- : verification de plage      }
 OptBoolEval    : Boolean;    { $B+/$B- : evaluation booleenne       }
 OptOverflow    : Boolean;    { $Q+/$Q- : verification depassement   }
 OptAlign       : Boolean;    { $A+/$A- : alignement                 }
 OptLongStr     : Boolean;    { $H+/$H- : string = AnsiString        }
 OptRTTI        : Boolean;    { $M+/$M- : RTTI etendue                }
 EnumSize       : Integer;    { $Z1/$Z2/$Z4 : taille des enumerations }
 AppType        : TString;    { $APPTYPE CONSOLE (defaut) / GUI      }

{ Forward declarations TODO 03 }
Procedure LexHandleDollarDirective; Forward;
Procedure IncludePop; Forward;

{ ------------------------------------------------------------ }
{ Fonctions utilitaires supplementaires                        }
{ ------------------------------------------------------------ }

Function IntToStr_(V: LongInt): TString;
Var S: TString;
Begin
 Str(V, S);
 IntToStr_ := S;
End;

Function StrLowerCase(Const S: TString): TString;
Var
 I   : Integer;
 Tmp : TString;
Begin
 Tmp := S;
 For I := 1 To Length(Tmp) Do
  If (Tmp[I] >= 'A') And (Tmp[I] <= 'Z') Then
   Tmp[I] := Chr(Ord(Tmp[I]) + 32);
 StrLowerCase := Tmp;
End;

{ ------------------------------------------------------------ }
{ Fonctions de classification de caracteres                    }
{ ------------------------------------------------------------ }

Function IsIdentStart(Ch: Char): Boolean;
Begin
 IsIdentStart := ((Ch >= 'A') And (Ch <= 'Z')) Or
                 ((Ch >= 'a') And (Ch <= 'z')) Or
                 (Ch = '_');
End;

Function IsIdentCont(Ch: Char): Boolean;
Begin
 IsIdentCont := IsIdentStart(Ch) Or
                ((Ch >= '0') And (Ch <= '9'));
End;

Function IsHexDigit(Ch: Char): Boolean;
Begin
 IsHexDigit := ((Ch >= '0') And (Ch <= '9')) Or
               ((Ch >= 'A') And (Ch <= 'F')) Or
               ((Ch >= 'a') And (Ch <= 'f'));
End;

Function HexVal(Ch: Char): Integer;
Begin
 If (Ch >= '0') And (Ch <= '9') Then
  HexVal := Ord(Ch) - Ord('0')
 Else If (Ch >= 'A') And (Ch <= 'F') Then
  HexVal := Ord(Ch) - Ord('A') + 10
 Else
  HexVal := Ord(Ch) - Ord('a') + 10;
End;

{ ------------------------------------------------------------ }
{ IsKeyword : mots-cles reserves Object Pascal / Delphi          }
{ Herite des mots-cles Turbo Pascal (voir TPCW32) et ajoute les  }
{ mots-cles reserves propres a Delphi (classes, exceptions,      }
{ proprietes, etc.).                                              }
{ N INCLUT PAS les directives (private, public, virtual,         }
{ override, read, write, name, default, stdcall, register, ...) : }
{ celles-ci sont, dans la grammaire Delphi officielle, des        }
{ identificateurs ordinaires ailleurs (ex: property Name: ...),   }
{ et non des mots reserves. Elles seront reconnues par leur       }
{ texte au moment ou le contexte grammatical les attend (TODO 14, }
{ TODO 15, TODO 16, voir IsDirective ci-dessous).                 }
{ ------------------------------------------------------------ }

Function IsKeyword(Const S: TString): Boolean;
Var
 L : TString;
Begin
 L := StrLowerCase(S);
 IsKeyword :=
  { Mots-cles Turbo Pascal herites }
  (L = 'and')         Or (L = 'array')      Or (L = 'asm')        Or
  (L = 'begin')       Or (L = 'case')       Or (L = 'const')      Or
  (L = 'div')         Or (L = 'do')         Or (L = 'downto')     Or
  (L = 'else')        Or (L = 'end')        Or (L = 'file')       Or
  (L = 'for')         Or (L = 'function')   Or (L = 'goto')       Or
  (L = 'if')          Or (L = 'implementation') Or
  (L = 'in')          Or (L = 'inline')     Or (L = 'interface')  Or
  (L = 'label')       Or (L = 'mod')        Or (L = 'nil')        Or
  (L = 'not')         Or (L = 'object')     Or (L = 'of')         Or
  (L = 'or')          Or (L = 'packed')     Or (L = 'procedure')  Or
  (L = 'program')     Or (L = 'record')     Or (L = 'repeat')     Or
  (L = 'set')         Or (L = 'shl')        Or (L = 'shr')        Or
  (L = 'string')      Or (L = 'then')       Or (L = 'to')         Or
  (L = 'type')        Or (L = 'unit')       Or (L = 'until')      Or
  (L = 'uses')        Or (L = 'var')        Or (L = 'while')      Or
  (L = 'with')         Or (L = 'xor')        Or
  (L = 'inherited')   Or (L = 'constructor') Or (L = 'destructor') Or
  { Mots-cles reserves Delphi additionnels }
  (L = 'class')       Or (L = 'library')    Or (L = 'except')     Or
  (L = 'finally')     Or (L = 'try')        Or (L = 'raise')      Or
  (L = 'on')          Or (L = 'property')   Or (L = 'is')         Or
  (L = 'as')          Or (L = 'out')        Or
  (L = 'resourcestring') Or (L = 'threadvar') Or
  (L = 'initialization') Or (L = 'finalization') Or
  (L = 'exports');
End;

{ ------------------------------------------------------------ }
{ IsDirective : directives Delphi contextuelles                  }
{ Contrairement aux mots-cles, ces identificateurs restent        }
{ valides comme noms ordinaires (variable, champ, propriete...)   }
{ ailleurs dans le programme ; IsKeyword les classe donc en       }
{ TK_IDENT. Cette fonction sert au futur analyseur syntaxique      }
{ (TODO 14 conventions d appel, TODO 15 visibilite et methodes     }
{ virtuelles, TODO 16 proprietes) pour les reconnaitre uniquement  }
{ a l endroit grammatical ou elles sont attendues.                }
{ ------------------------------------------------------------ }

Function IsDirective(Const S: TString): Boolean;
Var
 L : TString;
Begin
 L := StrLowerCase(S);
 IsDirective :=
  (L = 'private')     Or (L = 'protected')   Or (L = 'public')      Or
  (L = 'published')   Or (L = 'automated')   Or (L = 'virtual')     Or
  (L = 'dynamic')     Or (L = 'override')    Or (L = 'overload')    Or
  (L = 'reintroduce') Or (L = 'abstract')    Or (L = 'sealed')      Or
  (L = 'assembler')   Or (L = 'register')    Or (L = 'safecall')    Or
  (L = 'stdcall')     Or (L = 'cdecl')       Or (L = 'pascal')      Or
  (L = 'export')      Or (L = 'default')     Or (L = 'stored')      Or
  (L = 'read')        Or (L = 'write')       Or (L = 'index')       Or
  (L = 'name')        Or (L = 'nodefault')   Or (L = 'contains')    Or
  (L = 'requires');
End;

{ ------------------------------------------------------------ }
{ PrintToken : affichage debug de chaque token                 }
{ ------------------------------------------------------------ }

Procedure PrintToken(Const T: TToken);
Begin
 If Not Opts.DebugMode Then Exit;
 Write('  [', T.Line, ',', T.Col, '] ');
 Case T.Kind Of
  TK_EOF     : Write('EOF');
  TK_INTEGER : Write('INT(', T.IntVal, ')');
  TK_REAL    : Write('REAL(', T.Val, ')');
  TK_STRING  : Write('STR(''', T.Val, ''')');
  TK_CHAR    : Write('CHAR(#', T.IntVal, ')');
  TK_IDENT   : Write('IDENT(', T.Val, ')');
  TK_KEYWORD : Write('KW(', T.Val, ')');
  TK_OP      : Write('OP(', T.Val, ')');
  TK_PUNCT   : Write('PUNCT(', T.Val, ')');
 End;
 WriteLn;
End;

{ ------------------------------------------------------------ }
{ LexInit, LexClose, LexNextLine                               }
{ ------------------------------------------------------------ }

Procedure LexNextLine;
Begin
 If LexEOF Then Exit;
 If EOF(LexSrcF) Then
 Begin
  { Si on est dans un fichier inclus, depiler (TODO 03) }
  If IncTop >= 0 Then
  Begin
   IncludePop;
   Exit;
  End;
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

Procedure LexClose;
Begin
 If LexOpened Then
 Begin
  Close(LexSrcF);
  LexOpened := False;
 End;
End;

{ ------------------------------------------------------------ }
{ Commentaires                                                 }
{ ------------------------------------------------------------ }

{ Sauter commentaire // jusqu a fin de ligne }
Procedure LexSkipLineComment;
Begin
 LexColNo := Length(LexLine) + 1;
End;

{ Sauter un commentaire entre accolades, ou traiter une directive }
{ de compilation (accolade suivie de $, voir TODO 03).             }
Procedure LexSkipBraceComment;
Begin
 If (LexColNo < Length(LexLine)) And
    (LexLine[LexColNo + 1] = '$') Then
 Begin
  LexHandleDollarDirective;
  Exit;
 End;
 Inc(LexColNo); { sauter accolade ouvrante }
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

{ Sauter commentaire (* ... *) }
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

{ ------------------------------------------------------------ }
{ LexScanIdent : identificateur ou mot-cle                     }
{ ------------------------------------------------------------ }

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
 Else
  CurToken.Kind := TK_IDENT;
End;

{ ------------------------------------------------------------ }
{ LexScanNumber : entier decimal ou reel                       }
{ Gere decimaux, reels (3.14, 1.5E3), token '..' vs '.'        }
{ ------------------------------------------------------------ }

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

 { Partie entiere decimale }
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
  Else If FltVal < -2147483647.0 Then N := -2147483647
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

{ ------------------------------------------------------------ }
{ LexScanHexNumber : $FF, $FFFF, $FFFFFFFF                     }
{ ------------------------------------------------------------ }

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

{ ------------------------------------------------------------ }
{ LexScanString : chaine Pascal entre apostrophes               }
{ Gere le doublement de quote : 'l''echo' -> l'echo             }
{ ------------------------------------------------------------ }

Procedure LexScanString;
Var
 S  : TString;
 Ch : Char;
 V  : LongInt;
Begin
 S := '';
 Inc(LexColNo); { sauter quote ouvrante }
 While LexColNo <= Length(LexLine) Do
 Begin
  Ch := LexLine[LexColNo];
  If Ch = '''' Then
  Begin
   Inc(LexColNo);
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

 { Concatenation implicite : 'abc'#13#10'def' }
 While (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '#') Do
 Begin
  Inc(LexColNo); { sauter '#' }
  V := 0;
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '$') Then
  Begin
   Inc(LexColNo);
   While (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Do
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

  { Si encore suivi d une chaine 'xxx', concatener aussi }
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '''') Then
  Begin
   Inc(LexColNo);
   While LexColNo <= Length(LexLine) Do
   Begin
    Ch := LexLine[LexColNo];
    If Ch = '''' Then
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
      S := S + Ch;
     Inc(LexColNo);
    End;
   End;
  End;
 End;

 CurToken.Kind    := TK_STRING;
 CurToken.Val     := S;
 CurToken.IntVal  := 0;
 CurToken.RealVal := 0.0;
 If Length(S) = 1 Then
  CurToken.IntVal := Ord(S[1]);
End;

{ ------------------------------------------------------------ }
{ LexScanCharLit : caractere #nn ou #$nn                        }
{ Gere aussi les sequences #13#10 et #13#10'text'               }
{ ------------------------------------------------------------ }

Procedure LexScanCharLit;
Var
 V  : LongInt;
 S  : TString;
 Ch : Char;
Begin
 S := '';
 While (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '#') Do
 Begin
  Inc(LexColNo); { sauter '#' }
  V := 0;
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '$') Then
  Begin
   Inc(LexColNo); { sauter '$' }
   While (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Do
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
 End;

 { Si suivi d une chaine 'xxx', concatener }
 If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '''') Then
 Begin
  Inc(LexColNo); { sauter quote ouvrante }
  While LexColNo <= Length(LexLine) Do
  Begin
   Ch := LexLine[LexColNo];
   If Ch = '''' Then
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
     S := S + Ch;
    Inc(LexColNo);
   End;
  End;
  { Peut etre suivi d un autre #nn }
  While (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '#') Do
  Begin
   Inc(LexColNo);
   V := 0;
   If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '$') Then
   Begin
    Inc(LexColNo);
    While (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Do
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

{ ------------------------------------------------------------ }
{ LexNextToken : produire le prochain token                    }
{ ------------------------------------------------------------ }

Procedure LexNextToken;
Var
 Ch       : Char;
 Scanning : Boolean;
Begin
 CurToken.IntVal  := 0;
 CurToken.RealVal := 0.0;

 Scanning := True;
 While Scanning Do
 Begin
  While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
   LexNextLine;

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
   Inc(LexColNo)

  { Commentaire // ligne }
  Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
          (LexLine[LexColNo + 1] = '/') Then
   LexSkipLineComment

  { Commentaire entre accolades (ou directive de compilation, TODO 03) }
  Else If Ch = '{' Then
   LexSkipBraceComment

  { Commentaire (* ... *) ou operateur '(' }
  Else If (Ch = '(') And (LexColNo < Length(LexLine)) And
          (LexLine[LexColNo + 1] = '*') Then
   LexSkipParenStarComment

  { Entier hexadecimal $FF }
  Else If (Ch = '$') And (LexColNo < Length(LexLine)) And
          IsHexDigit(LexLine[LexColNo + 1]) Then
  Begin
   LexScanHexNumber;
   Scanning := False;
  End

  { Caractere litteral #nn }
  Else If Ch = '#' Then
  Begin
   LexScanCharLit;
   Scanning := False;
  End

  { Chaine Pascal 'xxx' }
  Else If Ch = '''' Then
  Begin
   LexScanString;
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
          (Ch = '=') Or (Ch = '<') Or (Ch = '>') Or (Ch = '@') Or
          (Ch = '^') Then
  Begin
   CurToken.Kind := TK_OP;
   CurToken.Val  := Ch;
   Inc(LexColNo);
   Scanning := False;
  End

  { Ponctuation }
  Else If (Ch = ';') Or (Ch = ',') Or (Ch = '(') Or (Ch = ')') Or
          (Ch = '[') Or (Ch = ']') Or (Ch = '.') Or (Ch = ':') Then
  Begin
   CurToken.Kind := TK_PUNCT;
   CurToken.Val  := Ch;
   Inc(LexColNo);
   Scanning := False;
  End

  { Caractere inconnu }
  Else
  Begin
   WarnMsg('caractere inattendu: ' + Ch +
           ' (ord=' + IntToStr_(Ord(Ch)) + ') ligne ' +
           IntToStr_(LexLineNo));
   Inc(LexColNo);
  End;
 End;

 PrintToken(CurToken);
End;

{ ============================================================ }
{ TODO 03 - PREPROCESSEUR ET DIRECTIVES DE COMPILATION [IMPLEMENTE] }
{ ============================================================ }

Const
 MAX_DEFINE  = 64;    { nombre max de symboles de compilation }
 MAX_INCLUDE = 8;      { profondeur max d inclusion }

{ ---- DefineDefined : teste si un symbole est defini ---- }
Function DefineDefined(Const Name: TString): Boolean;
Var
 I : Integer;
 N : TString;
Begin
 N := StrUpperCase(Name);
 DefineDefined := False;
 For I := 0 To DefineCount - 1 Do
  If DefineTab[I] = N Then
  Begin
   DefineDefined := True;
   Exit;
  End;
End;

{ ---- DefineAdd : ajouter un symbole de compilation ---- }
Procedure DefineAdd(Const Name: TString);
Var
 N : TString;
Begin
 N := StrUpperCase(Name);
 If DefineDefined(N) Then Exit;
 If DefineCount >= MAX_DEFINE Then
 Begin
  WarnMsg('trop de symboles $DEFINE (max ' + IntToStr_(MAX_DEFINE) + ')');
  Exit;
 End;
 DefineTab[DefineCount] := N;
 Inc(DefineCount);
End;

{ ---- DefineRemove : supprimer un symbole ---- }
Procedure DefineRemove(Const Name: TString);
Var
 I : Integer;
 N : TString;
Begin
 N := StrUpperCase(Name);
 For I := 0 To DefineCount - 1 Do
  If DefineTab[I] = N Then
  Begin
   DefineTab[I] := DefineTab[DefineCount - 1];
   Dec(DefineCount);
   Exit;
  End;
End;

{ ---- IncludePush : empiler le fichier courant et ouvrir un include ---- }
Procedure IncludePush(Const FileName: TString);
Var
 FullPath : TString;
 SrcDir   : TString;
Begin
 If IncTop >= MAX_INCLUDE - 1 Then
 Begin
  WarnMsg('profondeur d''inclusion maximale atteinte');
  Exit;
 End;
 { Sauvegarder l etat du lexeur }
 Inc(IncTop);
 IncSavedFName[IncTop]  := LexSrcFName;
 IncSavedLine[IncTop]   := LexLine;
 IncSavedLineNo[IncTop] := LexLineNo;
 IncSavedColNo[IncTop]  := LexColNo;
 IncSavedEOF[IncTop]    := LexEOF;
 { Fermer le fichier courant }
 Close(LexSrcF);
 { Tenter d ouvrir le fichier inclus (chemin direct) }
 FullPath := FileName;
 {$I-}
 Assign(LexSrcF, FullPath);
 Reset(LexSrcF);
 {$I+}
 If IOResult <> 0 Then
 Begin
  { Tenter dans le repertoire du fichier source }
  SrcDir := ExtractDir(LexSrcFName);
  If Length(SrcDir) > 0 Then
  Begin
   FullPath := SrcDir + FileName;
   {$I-}
   Assign(LexSrcF, FullPath);
   Reset(LexSrcF);
   {$I+}
  End;
  If IOResult <> 0 Then
  Begin
   WarnMsg('impossible d''ouvrir le fichier include: ' + FileName);
   { Rouvrir le fichier precedent }
   Assign(LexSrcF, IncSavedFName[IncTop]);
   Reset(LexSrcF);
   Dec(IncTop);
   Exit;
  End;
 End;
 LexSrcFName := FullPath;
 LexOpened := True;
 LexLine   := '';
 LexLineNo := 0;
 LexColNo  := 1;
 LexEOF    := False;
 LexNextLine;
End;

{ ---- IncludePop : depiler et restaurer le fichier precedent ---- }
Procedure IncludePop;
Var
 I     : Integer;
 Dummy : TString;
Begin
 If IncTop < 0 Then Exit;
 Close(LexSrcF);
 { Rouvrir le fichier precedent et avancer jusqu a la bonne ligne }
 Assign(LexSrcF, IncSavedFName[IncTop]);
 Reset(LexSrcF);
 For I := 1 To IncSavedLineNo[IncTop] Do
  If Not EOF(LexSrcF) Then
   ReadLn(LexSrcF, Dummy);
 LexSrcFName := IncSavedFName[IncTop];
 LexLine     := IncSavedLine[IncTop];
 LexLineNo   := IncSavedLineNo[IncTop];
 LexColNo    := IncSavedColNo[IncTop];
 LexEOF      := IncSavedEOF[IncTop];
 Dec(IncTop);
End;

{ ---- LexSkipCondFalse : sauter le code dans un IFDEF/IFNDEF/IFOPT }
{ faux. Saute jusqu a trouver $ELSE ou $ENDIF/$IFEND au meme niveau. }
Procedure LexSkipCondFalse;
Var
 Depth : Integer;
 P     : Integer;
 Dir   : TString;
Begin
 Depth := 1;
 While (Depth > 0) And (Not LexEOF) Do
 Begin
  If LexColNo > Length(LexLine) Then
  Begin
   LexNextLine;
   Continue;
  End;
  If LexLine[LexColNo] = '{' Then
  Begin
   P := LexColNo + 1;
   If (P <= Length(LexLine)) And (LexLine[P] = '$') Then
   Begin
    Inc(P);
    Dir := '';
    While (P <= Length(LexLine)) And (LexLine[P] <> '}') And
          (LexLine[P] <> ' ') Do
    Begin
     Dir := Dir + UpCase(LexLine[P]);
     Inc(P);
    End;
    If (Dir = 'IFDEF') Or (Dir = 'IFNDEF') Or (Dir = 'IFOPT') Then
     Inc(Depth)
    Else If (Dir = 'ENDIF') Or (Dir = 'IFEND') Then
    Begin
     Dec(Depth);
     If Depth = 0 Then
     Begin
      While (P <= Length(LexLine)) And (LexLine[P] <> '}') Do
       Inc(P);
      LexColNo := P + 1;
      Exit;
     End;
    End
    Else If (Dir = 'ELSE') And (Depth = 1) Then
    Begin
     { $ELSE au meme niveau : reprendre la compilation }
     While (P <= Length(LexLine)) And (LexLine[P] <> '}') Do
      Inc(P);
     LexColNo := P + 1;
     Exit;
    End;
   End;
   { Sauter toute l accolade }
   While (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] <> '}') Do
    Inc(LexColNo);
   If LexColNo <= Length(LexLine) Then
    Inc(LexColNo);
  End
  Else
   Inc(LexColNo);
 End;
End;

{ ---- LexHandleDollarDirective : traiter une directive $ ---- }
{ Appelee quand LexColNo pointe sur l accolade et le caractere   }
{ suivant est $. Gere I/INCLUDE, DEFINE, UNDEF, IFDEF, IFNDEF,   }
{ IFOPT, ELSE, ENDIF, IFEND, APPTYPE, R (ressources), Z1/Z2/Z4,  }
{ et les commutations I+/I-/R+/R-/B+/B-/Q+/Q-/A+/A-/H+/H-/M+/M-. }
Procedure LexHandleDollarDirective;
Var
 Dir : TString;
 Arg : TString;
 Sw  : Char;
Begin
 Inc(LexColNo);  { sauter accolade ouvrante }
 Inc(LexColNo);  { sauter $ }
 { Lire le nom de la directive }
 Dir := '';
 While (LexColNo <= Length(LexLine)) And
       IsIdentCont(LexLine[LexColNo]) Do
 Begin
  Dir := Dir + UpCase(LexLine[LexColNo]);
  Inc(LexColNo);
 End;

 { Commutateurs une lettre : $I+ / $R- / $H+ / $M- etc. }
 If (Length(Dir) = 1) And (LexColNo <= Length(LexLine)) And
    ((LexLine[LexColNo] = '+') Or (LexLine[LexColNo] = '-')) Then
 Begin
  Sw := LexLine[LexColNo];
  Inc(LexColNo);
  While (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] <> '}') Do
   Inc(LexColNo);
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '}') Then
   Inc(LexColNo);
  Case Dir[1] Of
   'I' : OptIO       := (Sw = '+');
   'R' : OptRange    := (Sw = '+');
   'B' : OptBoolEval := (Sw = '+');
   'Q' : OptOverflow := (Sw = '+');
   'A' : OptAlign    := (Sw = '+');
   'H' : OptLongStr  := (Sw = '+');
   'M' : OptRTTI     := (Sw = '+');
  End;
  Exit;
 End;

 { Sauter espaces }
 While (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = ' ') Do
  Inc(LexColNo);
 { Lire l argument jusqu a l accolade fermante }
 Arg := '';
 While (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] <> '}') Do
 Begin
  Arg := Arg + LexLine[LexColNo];
  Inc(LexColNo);
 End;
 While (Length(Arg) > 0) And (Arg[Length(Arg)] = ' ') Do
  Delete(Arg, Length(Arg), 1);
 If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '}') Then
  Inc(LexColNo);

 { Dispatcher les directives }
 If (Dir = 'I') Or (Dir = 'INCLUDE') Then
 Begin
  If (Length(Arg) >= 2) And
     ((Arg[1] = '''') Or (Arg[1] = '"')) Then
  Begin
   Delete(Arg, 1, 1);
   If (Length(Arg) > 0) And
      ((Arg[Length(Arg)] = '''') Or (Arg[Length(Arg)] = '"')) Then
    Delete(Arg, Length(Arg), 1);
  End;
  If Length(Arg) > 0 Then
   IncludePush(Arg)
  Else
   WarnMsg('nom de fichier attendu pour $INCLUDE');
 End
 Else If Dir = 'DEFINE' Then
  DefineAdd(Arg)
 Else If Dir = 'UNDEF' Then
  DefineRemove(Arg)
 Else If Dir = 'IFDEF' Then
 Begin
  If Not DefineDefined(Arg) Then
   LexSkipCondFalse;
 End
 Else If Dir = 'IFNDEF' Then
 Begin
  If DefineDefined(Arg) Then
   LexSkipCondFalse;
 End
 Else If Dir = 'IFOPT' Then
 Begin
  { $IFOPT X+ ou $IFOPT X- : tester l etat d une option }
  If Length(Arg) >= 2 Then
  Begin
   Sw := UpCase(Arg[1]);
   If Arg[2] = '+' Then
   Begin
    Case Sw Of
     'I' : If Not OptIO Then LexSkipCondFalse;
     'R' : If Not OptRange Then LexSkipCondFalse;
     'B' : If Not OptBoolEval Then LexSkipCondFalse;
     'Q' : If Not OptOverflow Then LexSkipCondFalse;
     'A' : If Not OptAlign Then LexSkipCondFalse;
     'H' : If Not OptLongStr Then LexSkipCondFalse;
     'M' : If Not OptRTTI Then LexSkipCondFalse;
    Else
     LexSkipCondFalse;
    End;
   End
   Else
   Begin
    Case Sw Of
     'I' : If OptIO Then LexSkipCondFalse;
     'R' : If OptRange Then LexSkipCondFalse;
     'B' : If OptBoolEval Then LexSkipCondFalse;
     'Q' : If OptOverflow Then LexSkipCondFalse;
     'A' : If OptAlign Then LexSkipCondFalse;
     'H' : If OptLongStr Then LexSkipCondFalse;
     'M' : If OptRTTI Then LexSkipCondFalse;
    Else
     LexSkipCondFalse;
    End;
   End;
  End
  Else
   LexSkipCondFalse;
 End
 Else If Dir = 'ELSE' Then
  { On est dans la branche vraie : sauter jusqu a $ENDIF/$IFEND }
  LexSkipCondFalse
 Else If (Dir = 'ENDIF') Or (Dir = 'IFEND') Then
  { Fin de bloc conditionnel, rien a faire }
 Else If Dir = 'APPTYPE' Then
 Begin
  AppType := StrUpperCase(Arg);
  If (AppType <> 'CONSOLE') And (AppType <> 'GUI') Then
  Begin
   WarnMsg('$APPTYPE inconnu (attendu CONSOLE ou GUI): ' + Arg);
   AppType := 'CONSOLE';
  End;
 End
 Else If Dir = 'R' Then
  { $R fichier.res : ressources -> non supporte, ignore }
  WarnMsg('directive $R (ressources) non supportee, ignoree: ' + Arg)
 Else If Dir = 'Z1' Then
  EnumSize := 1
 Else If Dir = 'Z2' Then
  EnumSize := 2
 Else If Dir = 'Z4' Then
  EnumSize := 4;
 { Autres directives ($L, $O, etc.) : ignorees silencieusement }
End;

{ ---- PPInitDefines : initialiser les symboles predefinis et les }
{ options de commutation par defaut ---- }
Procedure PPInitDefines;
Begin
 DefineCount := 0;
 IncTop      := -1;

 OptIO       := True;   { $I+ }
 OptRange    := False;  { $R- }
 OptBoolEval := False;  { $B- : evaluation court-circuit }
 OptOverflow := False;  { $Q- }
 OptAlign    := True;   { $A+ }
 OptLongStr  := True;   { $H+ : string = AnsiString par defaut en Delphi }
 OptRTTI     := False;  { $M- }
 EnumSize    := 4;       { $Z4 : taille par defaut d une enumeration }
 AppType     := 'CONSOLE';

 { Symboles toujours definis pour la cible Win32 }
 DefineAdd('WIN32');
 DefineAdd('CPU386');
 DefineAdd('MSWINDOWS');
 DefineAdd('CONDITIONALEXPRESSIONS');
 DefineAdd('VER150');   { emule Delphi 7 }
End;

{ ============================================================ }
{ TODO 04 - LITTERAUX ET CONSTANTES                  [IMPLEMENTE] }
{ ============================================================ }

Const
 MAX_DATA   = {$IFDEF FPC}512{$ELSE}128{$ENDIF};
 MAX_TOKENS = {$IFDEF FPC}16384{$ELSE}4096{$ENDIF};
 MAX_SET_BYTES = 32;      { SET OF T : 256 elements max (32 octets)  }

 { Prefixe de mangling pour les constantes chaine (voir TODO 07/08) }
 DP_STR_PFX = '_DPK_';

 { Table des tailles des types primitifs Delphi (Win32, 32 bits) }
 MAX_DP_TYPE_SIZES = 24;

Type
 { Types d entrees dans le pool de donnees }
 TDataKind = (
  DK_STR,     { chaine ASCIIZ (DB 'xxx',0)                         }
  DK_DWORD,   { valeur 32 bits (DD nnn)                            }
  DK_BYTE,    { valeur 8 bits (DB nnn)                             }
  DK_ARRAY,   { tableau (DB ElemCount*ElemSize DUP(0))             }
  DK_RES,     { espace reserve (DB Size DUP(0))                    }
  DK_STRUCT,  { structure/record/VMT (DB Size DUP(0))              }
  DK_ZERO     { espace initialise a zero (DB Size DUP(0))          }
 );

 { Un enregistrement du pool de donnees }
 TDataRec = Record
  LblName   : TString;    { label ASM (ex: _DPK_1)                 }
  Kind      : TDataKind;
  IntVal    : LongInt;    { valeur entiere (DK_DWORD, DK_BYTE)      }
  StrVal    : TString;    { contenu chaine (DK_STR)                 }
  ElemCount : Integer;    { nombre d elements (DK_ARRAY)             }
  ElemSize  : Integer;    { taille d un element (DK_ARRAY)           }
 End;

 { Taille connue d un type primitif Delphi }
 TDPSizeInfo = Record
  Name : TString;
  Size : Integer;
 End;

 { Constante ensembliste : SET OF T, jusqu a 256 elements (0..255) }
 TSetVal = Array[0..MAX_SET_BYTES - 1] Of Byte;

Var
 { Pool de donnees (segment .DATA, voir TODO 08) }
 DataTab    : Array[0..MAX_DATA - 1] Of TDataRec;
 DataCount  : Integer;

 { Compteur de labels auto-generes }
 LabelGenSeq : Integer;

 { Pool de tokens accumules par le lexeur, pour le parseur futur }
 TokenPool  : Array[0..MAX_TOKENS - 1] Of TToken;
 TokenCount : Integer;

{ ---- Table des tailles de types Delphi (Win32, 32 bits) ---- }
Const
 DelphiTypeSizes: Array[0..MAX_DP_TYPE_SIZES - 1] Of TDPSizeInfo = (
  (Name: 'INTEGER';       Size: 4),   { entier signe 32 bits          }
  (Name: 'CARDINAL';      Size: 4),   { entier non signe 32 bits      }
  (Name: 'LONGINT';       Size: 4),
  (Name: 'LONGWORD';      Size: 4),
  (Name: 'INT64';         Size: 8),
  (Name: 'UINT64';        Size: 8),
  (Name: 'BYTE';          Size: 1),
  (Name: 'SHORTINT';      Size: 1),
  (Name: 'WORD';          Size: 2),   { 16 bits, contrairement a TP/W32 }
  (Name: 'SMALLINT';      Size: 2),
  (Name: 'BOOLEAN';       Size: 1),
  (Name: 'CHAR';          Size: 1),   { AnsiChar                       }
  (Name: 'ANSICHAR';      Size: 1),
  (Name: 'WIDECHAR';      Size: 2),
  (Name: 'SINGLE';        Size: 4),
  (Name: 'DOUBLE';        Size: 8),
  (Name: 'EXTENDED';      Size: 10),
  (Name: 'CURRENCY';      Size: 8),
  (Name: 'COMP';          Size: 8),
  (Name: 'POINTER';       Size: 4),
  (Name: 'PCHAR';         Size: 4),
  (Name: 'STRING';        Size: 4),   { AnsiString/UnicodeString: ptr  }
  (Name: 'ANSISTRING';    Size: 4),
  (Name: 'SHORTSTRING';   Size: 256)  { 255 + octet de longueur        }
 );

{ ---- DataInit : initialiser le pool de donnees ---- }
Procedure DataInit;
Var I: Integer;
Begin
 DataCount   := 0;
 LabelGenSeq := 0;
 TokenCount  := 0;
 For I := 0 To MAX_DATA - 1 Do
 Begin
  DataTab[I].LblName   := '';
  DataTab[I].Kind      := DK_STR;
  DataTab[I].IntVal    := 0;
  DataTab[I].StrVal    := '';
  DataTab[I].ElemCount := 0;
  DataTab[I].ElemSize  := 0;
 End;
End;

{ ---- DataAdd : ajouter une entree generique dans le pool ---- }
Function DataAdd(Const Lbl: TString; Kind: TDataKind;
 AIntVal: LongInt; Const AStrVal: TString;
 AElemCount, AElemSize: Integer): Integer;
Begin
 If DataCount >= MAX_DATA Then
 Begin
  WarnMsg('pool de donnees plein (MAX_DATA=' + IntToStr_(MAX_DATA) + ')');
  DataAdd := -1;
  Exit;
 End;
 DataTab[DataCount].LblName   := Lbl;
 DataTab[DataCount].Kind      := Kind;
 DataTab[DataCount].IntVal    := AIntVal;
 DataTab[DataCount].StrVal    := AStrVal;
 DataTab[DataCount].ElemCount := AElemCount;
 DataTab[DataCount].ElemSize  := AElemSize;
 DataAdd := DataCount;
 Inc(DataCount);
End;

{ ---- DataAddStr : ajouter une chaine avec label auto-genere ---- }
Function DataAddStr(Const S: TString): TString;
Var Lbl: TString;
Begin
 Inc(LabelGenSeq);
 Lbl := DP_STR_PFX + IntToStr_(LabelGenSeq);
 DataAdd(Lbl, DK_STR, 0, S, 0, 0);
 DataAddStr := Lbl;
End;

{ ---- DataFindStr : rechercher si une chaine est deja dans le pool ---- }
Function DataFindStr(Const S: TString): Integer;
Var I: Integer;
Begin
 DataFindStr := -1;
 For I := 0 To DataCount - 1 Do
  If (DataTab[I].Kind = DK_STR) And (DataTab[I].StrVal = S) Then
  Begin
   DataFindStr := I;
   Exit;
  End;
End;

{ ---- DataGetOrAddStr : deduplique les chaines litterales ---- }
Function DataGetOrAddStr(Const S: TString): TString;
Var Idx: Integer;
Begin
 Idx := DataFindStr(S);
 If Idx >= 0 Then
  DataGetOrAddStr := DataTab[Idx].LblName
 Else
  DataGetOrAddStr := DataAddStr(S);
End;

{ ---- DelphiTypeSizeof : taille d un type primitif Delphi, -1 si ---- }
{ inconnu. Tout type ^T ou PT (pointeur) vaut 4 octets.               }
Function DelphiTypeSizeof(Const TypeName: TString): Integer;
Var
 I : Integer;
 N : TString;
Begin
 DelphiTypeSizeof := -1;
 N := StrUpperCase(TypeName);
 For I := 0 To MAX_DP_TYPE_SIZES - 1 Do
  If DelphiTypeSizes[I].Name = N Then
  Begin
   DelphiTypeSizeof := DelphiTypeSizes[I].Size;
   Exit;
  End;
 If (Length(N) > 1) And (N[1] = '^') Then
  DelphiTypeSizeof := 4;
End;

{ ------------------------------------------------------------ }
{ ConstEval : evaluation d expressions constantes entieres      }
{ Supporte : entiers, hex, caracteres, Ord/Chr/SizeOf/Succ/Pred/ }
{ Abs/Lo/Hi/Swap, MaxInt/MaxLongInt/True/False/Nil, parentheses, }
{ operateurs + - * div mod and or xor shl shr et comparaisons.  }
{ Opere sur le texte brut de l expression (aucun parseur         }
{ complet n existe encore) : sert de brique pour les futures     }
{ TODO 09 (constantes typees) et TODO 14 (parametres par         }
{ defaut).                                                        }
{ ------------------------------------------------------------ }

Function ConstEvalExpr(Const S: TString; Var Pos: Integer): LongInt; Forward;

Function ConstEvalAtom(Const S: TString; Var Pos: Integer): LongInt;
Var
 N     : LongInt;
 Neg   : Boolean;
 Id    : TString;
 Sz    : Integer;
 Arg   : TString;
 Depth : Integer;
Begin
 N := 0;

 While (Pos <= Length(S)) And ((S[Pos] = ' ') Or (S[Pos] = #9)) Do
  Inc(Pos);

 If Pos > Length(S) Then Begin ConstEvalAtom := 0; Exit; End;

 Neg := False;
 If (Pos <= Length(S)) And (S[Pos] = '-') Then
 Begin
  Neg := True;
  Inc(Pos);
  While (Pos <= Length(S)) And ((S[Pos] = ' ') Or (S[Pos] = #9)) Do
   Inc(Pos);
 End;
 If (Pos <= Length(S)) And (S[Pos] = '+') Then
 Begin
  Inc(Pos);
  While (Pos <= Length(S)) And ((S[Pos] = ' ') Or (S[Pos] = #9)) Do
   Inc(Pos);
 End;

 { NOT : operateur unaire }
 If (Pos + 2 <= Length(S)) And
    (UpCase(S[Pos]) = 'N') And (UpCase(S[Pos + 1]) = 'O') And
    (UpCase(S[Pos + 2]) = 'T') And
    ((Pos + 3 > Length(S)) Or Not IsIdentCont(S[Pos + 3])) Then
 Begin
  Inc(Pos, 3);
  N := Not ConstEvalAtom(S, Pos);
  If Neg Then N := -N;
  ConstEvalAtom := N;
  Exit;
 End;

 { Parentheses }
 If (Pos <= Length(S)) And (S[Pos] = '(') Then
 Begin
  Inc(Pos);
  N := ConstEvalExpr(S, Pos);
  If (Pos <= Length(S)) And (S[Pos] = ')') Then
   Inc(Pos);
  If Neg Then N := -N;
  ConstEvalAtom := N;
  Exit;
 End;

 { Caractere #nn ou #$nn }
 If (Pos <= Length(S)) And (S[Pos] = '#') Then
 Begin
  Inc(Pos);
  N := 0;
  If (Pos <= Length(S)) And (S[Pos] = '$') Then
  Begin
   Inc(Pos);
   While (Pos <= Length(S)) And IsHexDigit(S[Pos]) Do
   Begin
    N := N * 16 + HexVal(S[Pos]);
    Inc(Pos);
   End;
  End
  Else
   While (Pos <= Length(S)) And (S[Pos] >= '0') And (S[Pos] <= '9') Do
   Begin
    N := N * 10 + (Ord(S[Pos]) - Ord('0'));
    Inc(Pos);
   End;
  If Neg Then N := -N;
  ConstEvalAtom := N;
  Exit;
 End;

 { Chaine d un seul caractere 'A' -> Ord('A') }
 If (Pos <= Length(S)) And (S[Pos] = '''') Then
 Begin
  Inc(Pos);
  If Pos <= Length(S) Then
  Begin
   N := Ord(S[Pos]);
   Inc(Pos);
  End;
  If (Pos <= Length(S)) And (S[Pos] = '''') Then
   Inc(Pos);
  If Neg Then N := -N;
  ConstEvalAtom := N;
  Exit;
 End;

 { Hex $FF }
 If (Pos <= Length(S)) And (S[Pos] = '$') Then
 Begin
  Inc(Pos);
  N := 0;
  While (Pos <= Length(S)) And IsHexDigit(S[Pos]) Do
  Begin
   N := N * 16 + HexVal(S[Pos]);
   Inc(Pos);
  End;
  If Neg Then N := -N;
  ConstEvalAtom := N;
  Exit;
 End;

 { Nombre decimal (partie decimale/exposant ignoree : entiers seulement) }
 If (Pos <= Length(S)) And (S[Pos] >= '0') And (S[Pos] <= '9') Then
 Begin
  N := 0;
  While (Pos <= Length(S)) And (S[Pos] >= '0') And (S[Pos] <= '9') Do
  Begin
   N := N * 10 + (Ord(S[Pos]) - Ord('0'));
   Inc(Pos);
  End;
  If (Pos <= Length(S)) And (S[Pos] = '.') And
     (Pos < Length(S)) And (S[Pos + 1] <> '.') Then
  Begin
   Inc(Pos);
   While (Pos <= Length(S)) And (S[Pos] >= '0') And (S[Pos] <= '9') Do
    Inc(Pos);
   If (Pos <= Length(S)) And (UpCase(S[Pos]) = 'E') Then
   Begin
    Inc(Pos);
    If (Pos <= Length(S)) And ((S[Pos] = '+') Or (S[Pos] = '-')) Then
     Inc(Pos);
    While (Pos <= Length(S)) And (S[Pos] >= '0') And (S[Pos] <= '9') Do
     Inc(Pos);
   End;
  End;
  If Neg Then N := -N;
  ConstEvalAtom := N;
  Exit;
 End;

 { Identificateur : constante predefinie ou fonction de conversion }
 If (Pos <= Length(S)) And IsIdentStart(S[Pos]) Then
 Begin
  Id := '';
  While (Pos <= Length(S)) And IsIdentCont(S[Pos]) Do
  Begin
   Id := Id + UpCase(S[Pos]);
   Inc(Pos);
  End;
  While (Pos <= Length(S)) And ((S[Pos] = ' ') Or (S[Pos] = #9)) Do
   Inc(Pos);

  If Id = 'TRUE' Then N := 1
  Else If Id = 'FALSE' Then N := 0
  Else If Id = 'NIL' Then N := 0
  Else If Id = 'MAXINT' Then N := 2147483647
  Else If Id = 'MAXLONGINT' Then N := 2147483647

  Else If Id = 'ORD' Then
  Begin
   If (Pos <= Length(S)) And (S[Pos] = '(') Then
   Begin
    Inc(Pos);
    N := ConstEvalExpr(S, Pos);
    If (Pos <= Length(S)) And (S[Pos] = ')') Then Inc(Pos);
   End;
  End
  Else If Id = 'CHR' Then
  Begin
   If (Pos <= Length(S)) And (S[Pos] = '(') Then
   Begin
    Inc(Pos);
    N := ConstEvalExpr(S, Pos) And $FF;
    If (Pos <= Length(S)) And (S[Pos] = ')') Then Inc(Pos);
   End;
  End
  Else If Id = 'SIZEOF' Then
  Begin
   If (Pos <= Length(S)) And (S[Pos] = '(') Then
   Begin
    Inc(Pos);
    While (Pos <= Length(S)) And ((S[Pos] = ' ') Or (S[Pos] = #9)) Do
     Inc(Pos);
    Arg := '';
    Depth := 1;
    While (Pos <= Length(S)) And (Depth > 0) Do
    Begin
     If S[Pos] = '(' Then Inc(Depth)
     Else If S[Pos] = ')' Then
     Begin
      Dec(Depth);
      If Depth = 0 Then Begin Inc(Pos); Break; End;
     End;
     Arg := Arg + S[Pos];
     Inc(Pos);
    End;
    While (Length(Arg) > 0) And (Arg[Length(Arg)] = ' ') Do
     Delete(Arg, Length(Arg), 1);
    Sz := DelphiTypeSizeof(Arg);
    If Sz >= 0 Then N := Sz Else N := 4;
   End;
  End
  Else If Id = 'SUCC' Then
  Begin
   If (Pos <= Length(S)) And (S[Pos] = '(') Then
   Begin
    Inc(Pos);
    N := ConstEvalExpr(S, Pos) + 1;
    If (Pos <= Length(S)) And (S[Pos] = ')') Then Inc(Pos);
   End;
  End
  Else If Id = 'PRED' Then
  Begin
   If (Pos <= Length(S)) And (S[Pos] = '(') Then
   Begin
    Inc(Pos);
    N := ConstEvalExpr(S, Pos) - 1;
    If (Pos <= Length(S)) And (S[Pos] = ')') Then Inc(Pos);
   End;
  End
  Else If Id = 'ABS' Then
  Begin
   If (Pos <= Length(S)) And (S[Pos] = '(') Then
   Begin
    Inc(Pos);
    N := ConstEvalExpr(S, Pos);
    If N < 0 Then N := -N;
    If (Pos <= Length(S)) And (S[Pos] = ')') Then Inc(Pos);
   End;
  End
  Else If Id = 'LO' Then
  Begin
   If (Pos <= Length(S)) And (S[Pos] = '(') Then
   Begin
    Inc(Pos);
    N := ConstEvalExpr(S, Pos) And $FF;
    If (Pos <= Length(S)) And (S[Pos] = ')') Then Inc(Pos);
   End;
  End
  Else If Id = 'HI' Then
  Begin
   If (Pos <= Length(S)) And (S[Pos] = '(') Then
   Begin
    Inc(Pos);
    N := (ConstEvalExpr(S, Pos) Shr 8) And $FF;
    If (Pos <= Length(S)) And (S[Pos] = ')') Then Inc(Pos);
   End;
  End
  Else If Id = 'SWAP' Then
  Begin
   If (Pos <= Length(S)) And (S[Pos] = '(') Then
   Begin
    Inc(Pos);
    N := ConstEvalExpr(S, Pos);
    N := ((N And $FF) Shl 8) Or ((N Shr 8) And $FF);
    If (Pos <= Length(S)) And (S[Pos] = ')') Then Inc(Pos);
   End;
  End
  Else
   N := 0;  { identificateur inconnu (variable, constante nommee...) }

  If Neg Then N := -N;
  ConstEvalAtom := N;
  Exit;
 End;

 ConstEvalAtom := 0;
End;

{ ---- Niveau multiplicatif : * div mod and shl shr (priorite haute) ---- }
Function ConstEvalMul(Const S: TString; Var Pos: Integer): LongInt;
Var
 L, R : LongInt;
 Op   : TString;
 Save : Integer;
Begin
 L := ConstEvalAtom(S, Pos);
 While Pos <= Length(S) Do
 Begin
  While (Pos <= Length(S)) And ((S[Pos] = ' ') Or (S[Pos] = #9)) Do
   Inc(Pos);
  If Pos > Length(S) Then Break;

  Op := '';
  If S[Pos] = '*' Then Begin Op := '*'; Inc(Pos); End
  Else If IsIdentStart(S[Pos]) Then
  Begin
   Save := Pos;
   Op := '';
   While (Pos <= Length(S)) And IsIdentCont(S[Pos]) Do
   Begin
    Op := Op + UpCase(S[Pos]);
    Inc(Pos);
   End;
   If (Op <> 'DIV') And (Op <> 'MOD') And (Op <> 'AND') And
      (Op <> 'SHL') And (Op <> 'SHR') Then
   Begin
    Pos := Save;
    Break;
   End;
  End
  Else
   Break;

  R := ConstEvalAtom(S, Pos);
  If Op = '*' Then L := L * R
  Else If Op = 'DIV' Then Begin If R <> 0 Then L := L Div R Else L := 0; End
  Else If Op = 'MOD' Then Begin If R <> 0 Then L := L Mod R Else L := 0; End
  Else If Op = 'AND' Then L := L And R
  Else If Op = 'SHL' Then L := L Shl R
  Else If Op = 'SHR' Then L := L Shr R;
 End;
 ConstEvalMul := L;
End;

{ ---- Niveau additif : + - or xor (priorite moyenne) ---- }
Function ConstEvalAdd(Const S: TString; Var Pos: Integer): LongInt;
Var
 L, R : LongInt;
 Op   : TString;
 Save : Integer;
Begin
 L := ConstEvalMul(S, Pos);
 While Pos <= Length(S) Do
 Begin
  While (Pos <= Length(S)) And ((S[Pos] = ' ') Or (S[Pos] = #9)) Do
   Inc(Pos);
  If Pos > Length(S) Then Break;

  Op := '';
  If S[Pos] = '+' Then Begin Op := '+'; Inc(Pos); End
  Else If S[Pos] = '-' Then Begin Op := '-'; Inc(Pos); End
  Else If IsIdentStart(S[Pos]) Then
  Begin
   Save := Pos;
   Op := '';
   While (Pos <= Length(S)) And IsIdentCont(S[Pos]) Do
   Begin
    Op := Op + UpCase(S[Pos]);
    Inc(Pos);
   End;
   If (Op <> 'OR') And (Op <> 'XOR') Then
   Begin
    Pos := Save;
    Break;
   End;
  End
  Else
   Break;

  R := ConstEvalMul(S, Pos);
  If Op = '+' Then L := L + R
  Else If Op = '-' Then L := L - R
  Else If Op = 'OR' Then L := L Or R
  Else If Op = 'XOR' Then L := L Xor R;
 End;
 ConstEvalAdd := L;
End;

{ ---- Niveau relationnel : = <> < > <= >= (priorite basse) ---- }
Function ConstEvalExpr(Const S: TString; Var Pos: Integer): LongInt;
Var
 L, R : LongInt;
 Op   : TString;
Begin
 L := ConstEvalAdd(S, Pos);

 While Pos <= Length(S) Do
 Begin
  While (Pos <= Length(S)) And ((S[Pos] = ' ') Or (S[Pos] = #9)) Do
   Inc(Pos);
  If Pos > Length(S) Then Break;

  Op := '';
  If (S[Pos] = '<') And (Pos < Length(S)) And (S[Pos + 1] = '>') Then
   Begin Op := '<>'; Inc(Pos, 2); End
  Else If (S[Pos] = '<') And (Pos < Length(S)) And (S[Pos + 1] = '=') Then
   Begin Op := '<='; Inc(Pos, 2); End
  Else If (S[Pos] = '>') And (Pos < Length(S)) And (S[Pos + 1] = '=') Then
   Begin Op := '>='; Inc(Pos, 2); End
  Else If S[Pos] = '<' Then Begin Op := '<'; Inc(Pos); End
  Else If S[Pos] = '>' Then Begin Op := '>'; Inc(Pos); End
  Else If S[Pos] = '=' Then Begin Op := '='; Inc(Pos); End
  Else
   Break;

  R := ConstEvalAdd(S, Pos);
  If Op = '=' Then Begin If L = R Then L := 1 Else L := 0; End
  Else If Op = '<>' Then Begin If L <> R Then L := 1 Else L := 0; End
  Else If Op = '<' Then Begin If L < R Then L := 1 Else L := 0; End
  Else If Op = '>' Then Begin If L > R Then L := 1 Else L := 0; End
  Else If Op = '<=' Then Begin If L <= R Then L := 1 Else L := 0; End
  Else If Op = '>=' Then Begin If L >= R Then L := 1 Else L := 0; End;
 End;

 ConstEvalExpr := L;
End;

{ ---- ConstEval : evaluer une expression constante entiere complete ---- }
Function ConstEval(Const S: TString): LongInt;
Var P: Integer;
Begin
 P := 1;
 ConstEval := ConstEvalExpr(S, P);
End;

{ ------------------------------------------------------------ }
{ Constantes ensemblistes : [1, 3..7, 10]                       }
{ ------------------------------------------------------------ }

Procedure SetValClear(Var SV: TSetVal);
Var I: Integer;
Begin
 For I := 0 To MAX_SET_BYTES - 1 Do SV[I] := 0;
End;

Procedure SetValInclude(Var SV: TSetVal; Elem: Integer);
Begin
 If (Elem < 0) Or (Elem > 255) Then Exit;
 SV[Elem Div 8] := SV[Elem Div 8] Or (1 Shl (Elem Mod 8));
End;

Function SetValContains(Const SV: TSetVal; Elem: Integer): Boolean;
Begin
 If (Elem < 0) Or (Elem > 255) Then
  SetValContains := False
 Else
  SetValContains := (SV[Elem Div 8] And (1 Shl (Elem Mod 8))) <> 0;
End;

{ ---- ConstEvalSet : evaluer une constante ensembliste [a, b..c, ...] ---- }
{ Chaque element ou borne de plage est evalue par ConstEvalExpr ;      }
{ virgule = union d elements, '..' = plage inclusive.                  }
Function ConstEvalSet(Const S: TString): TSetVal;
Var
 SV   : TSetVal;
 Pos  : Integer;
 Lo, Hi, I : LongInt;
Begin
 SetValClear(SV);
 Pos := 1;
 While (Pos <= Length(S)) And (S[Pos] <> '[') Do Inc(Pos);
 If Pos <= Length(S) Then Inc(Pos); { sauter '[' }

 While Pos <= Length(S) Do
 Begin
  While (Pos <= Length(S)) And
        ((S[Pos] = ' ') Or (S[Pos] = ',') Or (S[Pos] = #9)) Do
   Inc(Pos);
  If (Pos > Length(S)) Or (S[Pos] = ']') Then Break;

  Lo := ConstEvalExpr(S, Pos);
  Hi := Lo;

  While (Pos <= Length(S)) And (S[Pos] = ' ') Do Inc(Pos);
  If (Pos < Length(S)) And (S[Pos] = '.') And (S[Pos + 1] = '.') Then
  Begin
   Inc(Pos, 2);
   Hi := ConstEvalExpr(S, Pos);
  End;

  For I := Lo To Hi Do
   SetValInclude(SV, I);

  While (Pos <= Length(S)) And (S[Pos] = ' ') Do Inc(Pos);
  If (Pos <= Length(S)) And (S[Pos] = ',') Then Inc(Pos);
 End;

 ConstEvalSet := SV;
End;

{ ---- TokenPoolInit / TokenPoolAdd : accumulation des tokens lexes ---- }
{ pour le futur analyseur syntaxique (TODO 05 et suivants).            }
Procedure TokenPoolInit;
Begin
 TokenCount := 0;
End;

Procedure TokenPoolAdd(Const T: TToken);
Begin
 If TokenCount >= MAX_TOKENS Then
 Begin
  WarnMsg('pool de tokens plein (MAX_TOKENS=' + IntToStr_(MAX_TOKENS) + ')');
  Exit;
 End;
 TokenPool[TokenCount] := T;
 Inc(TokenCount);
End;

{ ---- TokenPoolRegisterStrings : enregistrer toutes les chaines du ---- }
{ pool de tokens dans le pool de donnees, en evitant les doublons.     }
Procedure TokenPoolRegisterStrings;
Var I: Integer;
Begin
 For I := 0 To TokenCount - 1 Do
  If TokenPool[I].Kind = TK_STRING Then
   DataGetOrAddStr(TokenPool[I].Val);
End;

{ ------------------------------------------------------------ }
{ ConstEvalSelfTest : verifie l evaluateur d expressions        }
{ constantes et de constantes ensemblistes avec des cas connus. }
{ S execute a chaque lancement (cout negligeable) pour garantir }
{ que cette brique reste correcte au fil des futurs TODOs qui   }
{ s appuieront dessus (TODO 09, TODO 14, TODO 19).               }
{ ------------------------------------------------------------ }

Procedure ConstAssertEq(Const Label_: TString; Got, Want: LongInt);
Begin
 If Got <> Want Then
  FatalError('ConstEvalSelfTest: ' + Label_ + ' attendu=' +
   IntToStr_(Want) + ' obtenu=' + IntToStr_(Got));
End;

Procedure ConstEvalSelfTest;
Var
 SV : TSetVal;
Begin
 ConstAssertEq('1+2*3',        ConstEval('1 + 2 * 3'), 7);
 ConstAssertEq('(1+2)*3',      ConstEval('(1 + 2) * 3'), 9);
 ConstAssertEq('2*3+4*5',      ConstEval('2 * 3 + 4 * 5'), 26);
 ConstAssertEq('10-2*3',       ConstEval('10 - 2 * 3'), 4);
 ConstAssertEq('1+2=3',        ConstEval('1 + 2 = 3'), 1);
 ConstAssertEq('1 or 2 and 3', ConstEval('1 or 2 and 3'), 3);
 ConstAssertEq('2+3>4',        ConstEval('2 + 3 > 4'), 1);
 ConstAssertEq('$FF',          ConstEval('$FF'), 255);
 ConstAssertEq('#65',          ConstEval('#65'), 65);
 ConstAssertEq('quote-A',      ConstEval(''''  + 'A' + ''''), 65);
 ConstAssertEq('Ord(A)',       ConstEval('Ord(''A'')'), 65);
 ConstAssertEq('Chr(65)',      ConstEval('Chr(65)'), 65);
 ConstAssertEq('SizeOf(Integer)', ConstEval('SizeOf(Integer)'), 4);
 ConstAssertEq('SizeOf(Word)', ConstEval('SizeOf(Word)'), 2);
 ConstAssertEq('SizeOf(Int64)', ConstEval('SizeOf(Int64)'), 8);
 ConstAssertEq('Succ(4)',      ConstEval('Succ(4)'), 5);
 ConstAssertEq('Pred(4)',      ConstEval('Pred(4)'), 3);
 ConstAssertEq('Abs(-7)',      ConstEval('Abs(-7)'), 7);
 ConstAssertEq('True',         ConstEval('True'), 1);
 ConstAssertEq('False',        ConstEval('False'), 0);
 ConstAssertEq('Nil',          ConstEval('Nil'), 0);
 ConstAssertEq('MaxInt',       ConstEval('MaxInt'), 2147483647);
 ConstAssertEq('10 div 3',     ConstEval('10 div 3'), 3);
 ConstAssertEq('10 mod 3',     ConstEval('10 mod 3'), 1);
 ConstAssertEq('5 shl 2',      ConstEval('5 shl 2'), 20);
 ConstAssertEq('20 shr 2',     ConstEval('20 shr 2'), 5);
 ConstAssertEq('3 = 3',        ConstEval('3 = 3'), 1);
 ConstAssertEq('3 <> 3',       ConstEval('3 <> 3'), 0);

 { Constante ensembliste [1, 3..5, 10] }
 SV := ConstEvalSet('[1, 3..5, 10]');
 If Not SetValContains(SV, 1) Then
  FatalError('ConstEvalSelfTest: [1,3..5,10] doit contenir 1');
 If SetValContains(SV, 2) Then
  FatalError('ConstEvalSelfTest: [1,3..5,10] ne doit pas contenir 2');
 If (Not SetValContains(SV, 3)) Or (Not SetValContains(SV, 4)) Or
    (Not SetValContains(SV, 5)) Then
  FatalError('ConstEvalSelfTest: [1,3..5,10] doit contenir 3..5');
 If Not SetValContains(SV, 10) Then
  FatalError('ConstEvalSelfTest: [1,3..5,10] doit contenir 10');
 If SetValContains(SV, 6) Or SetValContains(SV, 11) Then
  FatalError('ConstEvalSelfTest: [1,3..5,10] ne doit contenir que 1,3..5,10');
End;

{ ------------------------------------------------------------ }
{ Declarations anticipees de TODO 12 (RTL minimale) : les noms  }
{ mangled des fonctions RTL a corps runtime reel (IntToStr,      }
{ Trim, UpperCase...) sont fixes ici pour que SymRegisterBuiltins}
{ (TODO 05, plus bas) puisse les affecter directement comme      }
{ MangledName ; l implementation des routines elles-memes suit   }
{ le bloc TODO 11 en entier (EmitRuntimeLibrary).                 }
{ ------------------------------------------------------------ }

Const
 DPRT_STRLEN        = '_DPRT_STRLEN';
 DPRT_WRITESTR      = '_DPRT_WRITESTR';
 DPRT_WRITECHAR     = '_DPRT_WRITECHAR';
 DPRT_INTTOSTR      = '_DPRT_INTTOSTR';
 DPRT_STRTOINT      = '_DPRT_STRTOINT';
 DPRT_STRTOINTDEF   = '_DPRT_STRTOINTDEF';
 DPRT_FLOATTOSTR    = '_DPRT_FLOATTOSTR';
 DPRT_STRTOFLOAT    = '_DPRT_STRTOFLOAT';
 DPRT_READLINE      = '_DPRT_READLINE';
 DPRT_TRIM          = '_DPRT_TRIM';
 DPRT_UPPERCASE     = '_DPRT_UPPERCASE';
 DPRT_LOWERCASE     = '_DPRT_LOWERCASE';
 DPRT_COMPARESTR    = '_DPRT_COMPARESTR';
 DPRT_COMPARETEXT   = '_DPRT_COMPARETEXT';
 DPRT_INIT          = '_DPRT_INIT';

{ ------------------------------------------------------------ }
{ Declarations anticipees de TODO 06 (systeme de types) :       }
{ SymRegisterBuiltins, plus bas, doit lier chaque symbole       }
{ predefini (Integer, TObject, Exception...) a son type reel    }
{ dans TypeTab. La table et son API sont donc declarees ici,    }
{ leur implementation complete suit le bloc TODO 05 en entier.  }
{ ------------------------------------------------------------ }

Const
 MAX_TYPE         = {$IFDEF FPC}2048{$ELSE}256{$ENDIF};
 MAX_FIELD_POOL   = {$IFDEF FPC}4096{$ELSE}512{$ENDIF};  { champs de tous
                      les records/classes confondus              }
 MAX_ENUMVAL_POOL = {$IFDEF FPC}4096{$ELSE}512{$ENDIF};  { valeurs de
                      tous les types enumeres confondus           }

Type
 { Categories de types dans la table }
 TTypeKind = (
  TYK_INTEGER,   { ordinal entier (Integer, Cardinal, Byte, ...)  }
  TYK_CHAR,      { caractere (Char/AnsiChar 8 bits, WideChar 16)  }
  TYK_BOOLEAN,   { booleen                                        }
  TYK_STRING,    { chaine (AnsiString/String ou ShortString[n])   }
  TYK_REAL,      { flottant (Single/Double/Extended/Currency/Comp)}
  TYK_POINTER,   { pointeur generique                             }
  TYK_PCHAR,     { pointeur vers Char (PChar)                     }
  TYK_VARIANT,   { Variant (stub minimal, TODO 06)                }
  TYK_ARRAY,     { tableau statique ou dynamique                  }
  TYK_RECORD,    { record                                         }
  TYK_SET,       { SET OF T                                       }
  TYK_ENUM,      { enumeration                                    }
  TYK_SUBRANGE,  { sous-intervalle (lo..hi)                       }
  TYK_PROCTYPE,  { type procedure/fonction, avec ou sans of object}
  TYK_CLASS,     { classe (class ... end)                         }
  TYK_INTERFACE, { interface (interface ... end)                  }
  TYK_NIL        { constante nil                                  }
 );

 { Un champ de record ou de classe, dans le pool partage FieldPool }
 TFieldRec = Record
  Name    : TString;
  TypeIdx : Integer;
  Offset  : Integer;
 End;

 { Une valeur d une enumeration, dans le pool partage EnumValPool }
 TEnumValRec = Record
  Name  : TString;
  Value : LongInt;
 End;

 { Un enregistrement de la table des types }
 TTypeRec = Record
  Kind        : TTypeKind;
  Name        : TString;    { nom du type ('' si anonyme)          }
  Size        : Integer;    { taille en octets                     }
  Align       : Integer;    { alignement en octets                 }
  BaseTypeIdx : Integer;    { alias, element (array/set/pointeur), }
                             { ou ancetre (class/interface), -1=aucun}
  Lo, Hi      : LongInt;    { bornes (subrange, array statique)     }
  IsDynArray  : Boolean;    { ARRAY OF T dynamique (TODO 19) ?      }
  FieldFirst  : Integer;    { index de depart dans FieldPool        }
  FieldCount  : Integer;    { nombre de champs (record, classe)     }
  EnumFirst   : Integer;    { index de depart dans EnumValPool      }
  EnumCount   : Integer;    { nombre de valeurs (enum)              }
  IsUnsigned  : Boolean;    { ordinal non signe ?                   }
  IsMethodPtr : Boolean;    { type procedure "of object" ?          }
  ParamCount  : Integer;    { arite (TYK_PROCTYPE)                  }
  ClassSymIdx : Integer;    { SK_CLASS/SK_INTERFACE lie dans SymTab }
  VMTFirst    : Integer;    { SK_CLASS : index de depart dans        }
                             { VMTEntryPool (TODO 08), -1 si aucune   }
  VMTCount    : Integer;    { SK_CLASS : nombre d entrees virtuelles }
                             { (heritees + propres)                  }
  InstanceSize: Integer;    { SK_CLASS : taille de l instance (somme }
                             { des champs, TODO 09), distincte de Size}
                             { qui reste 4 (taille d une REFERENCE de }
                             { classe, utilisee pour les variables)  }
 End;

Var
 { Table des types }
 TypeTab   : Array[0..MAX_TYPE - 1] Of TTypeRec;
 TypeCount : Integer;

 { Pools partages (evite d avoir un tableau de champs/valeurs de     }
 { taille fixe dans chaque TTypeRec, qui gaspillerait la memoire)   }
 FieldPool      : Array[0..MAX_FIELD_POOL - 1] Of TFieldRec;
 FieldPoolCount : Integer;
 EnumValPool      : Array[0..MAX_ENUMVAL_POOL - 1] Of TEnumValRec;
 EnumValPoolCount : Integer;

Procedure TypeInit; Forward;
Function  TypeFindByName(Const AName: TString): Integer; Forward;
Function  TypeSizeofIdx(Idx: Integer): Integer; Forward;
Function  TypeResolve(Idx: Integer): Integer; Forward;
Function  TypeIsOrdinal(Idx: Integer): Boolean; Forward;
Function  TypeIsNumeric(Idx: Integer): Boolean; Forward;
Function  TypeIsPointer(Idx: Integer): Boolean; Forward;
Function  TypeIsString(Idx: Integer): Boolean; Forward;
Function  TypeIsReal(Idx: Integer): Boolean; Forward;
Function  TypeIsClass(Idx: Integer): Boolean; Forward;
Function  TypeIsInterface(Idx: Integer): Boolean; Forward;
Function  TypeCoerce(IdxA, IdxB: Integer): Integer; Forward;
Function  TypeIsAssignCompatible(FromIdx, ToIdx: Integer): Boolean; Forward;
Function  TypeIsCastCompatible(FromIdx, ToIdx: Integer): Boolean; Forward;
Function  TypeAddClass(Const Name: TString;
 ParentTypeIdx, AClassSymIdx: Integer): Integer; Forward;
Function  TypeAddInterface(Const Name: TString;
 ParentTypeIdx, AClassSymIdx: Integer): Integer; Forward;

{ ============================================================ }
{ TODO 05 - TABLE DES SYMBOLES ET PORTEES            [IMPLEMENTE] }
{ ============================================================ }

Const
 MAX_SYM   = {$IFDEF FPC}4096{$ELSE}512{$ENDIF};
 MAX_SCOPE = 64;      { profondeur max de portees imbriquees (unite,
                        classe, methode, bloc)                      }

 { Prefixes de mangling pour l emission ASM (voir TODO 07/08) }
 DP_VAR_PFX  = '_DPV_';   { variables                            }
 DP_LBL_PFX  = '_DPL_';   { labels internes                      }
 DP_FUNC_PFX = '_DPF_';   { procedures / fonctions / methodes    }
 DP_FLD_PFX  = '_DPFL_';  { champs de classe / record            }
 DP_CLS_PFX  = '_DPC_';   { VMT / RTTI d une classe (TODO 16)    }

Type
 { Categorie d un parametre de procedure/fonction/methode (TODO 09) }
 TParamKind = (
  PK_VALUE,  { par valeur (defaut)                                 }
  PK_VAR,    { VAR : par reference, lecture/ecriture                }
  PK_CONST,  { CONST : par reference (evite la copie), lecture seule}
  PK_OUT     { OUT : par reference, valeur initiale non garantie    }
 );

 { Categories de symboles dans la table }
 TSymKind = (
  SK_CONST,      { constante nommee (const X = 42)                }
  SK_TYPE,       { type defini (type T = ...)                     }
  SK_VAR,        { variable locale ou globale                     }
  SK_PARAM,      { parametre de procedure/fonction/methode         }
  SK_PROC,       { procedure                                      }
  SK_FUNC,       { fonction                                       }
  SK_FIELD,      { champ de record ou de classe                   }
  SK_METHOD,     { methode d une classe ou d une interface        }
  SK_UNIT,       { unite importee (uses)                          }
  SK_LABEL,      { label (label / goto)                           }
  SK_PROPERTY,   { propriete d une classe (TODO 15)                }
  SK_CLASS,      { classe (type class(...) ... end)                }
  SK_INTERFACE   { interface (type I... = interface ... end)       }
 );

 { Un enregistrement de la table des symboles }
 TSymRec = Record
  Name          : TString;   { nom original, normalise en majuscules }
  MangledName   : TString;   { nom mangled pour l emission ASM       }
  Kind          : TSymKind;  { categorie du symbole                  }
  TypeIdx       : Integer;   { index dans la table des types
                                (TODO 06), -1 si aucun/pas encore lie }
  Offset        : Integer;   { offset stack ou data segment          }
  ScopeLevel    : Integer;   { niveau de portee (0 = global/unite)   }
  ScopeId       : Integer;   { id unique de la portee qui le contient}
  IsGlobal      : Boolean;   { visible depuis tout le fichier ?      }
  IsExternal    : Boolean;   { forward / declare hors implementation }
  UnitName      : TString;   { unite d origine pour Unit.Ident, ''
                                si local au fichier courant           }
  ImmVal        : LongInt;   { valeur immediate (const, enum)        }
  ParamCount    : Integer;   { nombre de parametres (proc/func/meth) }
  ParentClassIdx: Integer;   { SK_CLASS/SK_INTERFACE : index de la
                                classe ancetre (-1 = aucune, ex.
                                TObject), utilise par 'inherited'      }
  MemberScopeId : Integer;   { SK_CLASS/SK_INTERFACE : id de la
                                portee contenant ses champs/methodes,
                                utilise par Self.Champ et Unit.Ident  }
  ParamKind     : TParamKind;{ SK_PARAM : valeur/VAR/CONST/OUT (TODO 09) }
  IsSealed      : Boolean;  { SK_CLASS : heritage interdit (TODO 15)   }
  IsConstructor : Boolean;  { SK_METHOD : constructeur (TODO 15) : le  }
                             { site d appel alloue l instance          }
  IsClassMethod : Boolean;  { SK_METHOD : class function/procedure     }
                             { (statique, pas de Self, TODO 15)         }
 End;

Var
 { Table des symboles }
 SymTab   : Array[0..MAX_SYM - 1] Of TSymRec;
 SymCount : Integer;

 { Pile des portees actives : unite (globale) -> classe -> methode ->
   bloc. ScopeStack[0..ScopeStackTop] contient les ScopeId visibles en
   plus de la portee globale (id 0), du plus externe au plus imbrique. }
 ScopeStack    : Array[0..MAX_SCOPE - 1] Of Integer;
 ScopeStackTop : Integer;    { -1 = seule la portee globale est active }
 CurScopeLevel : Integer;    { = ScopeStackTop + 1                     }
 CurScopeId    : Integer;    { = ScopeStack[ScopeStackTop], 0 si global}
 ScopeIdSeq    : Integer;    { sequence pour generer des ids uniques   }

{ ------------------------------------------------------------ }
{ SymInit : initialiser la table des symboles et enregistrer   }
{ les identificateurs predefinis de l unite System.             }
{ ------------------------------------------------------------ }

Procedure SymRegisterBuiltins; Forward;

Procedure SymInit;
Var I: Integer;
Begin
 { La table des types doit exister avant les symboles predefinis, }
 { qui se lient a elle (TypeIdx) dans SymRegisterBuiltins.         }
 TypeInit;

 SymCount      := 0;
 ScopeStackTop := -1;
 CurScopeLevel := 0;
 CurScopeId    := 0;
 ScopeIdSeq    := 0;
 For I := 0 To MAX_SYM - 1 Do
 Begin
  SymTab[I].Name           := '';
  SymTab[I].MangledName    := '';
  SymTab[I].Kind           := SK_VAR;
  SymTab[I].TypeIdx        := -1;
  SymTab[I].Offset         := 0;
  SymTab[I].ScopeLevel     := 0;
  SymTab[I].ScopeId        := 0;
  SymTab[I].IsGlobal       := False;
  SymTab[I].IsExternal     := False;
  SymTab[I].UnitName       := '';
  SymTab[I].ImmVal         := 0;
  SymTab[I].ParamCount     := 0;
  SymTab[I].ParentClassIdx := -1;
  SymTab[I].MemberScopeId  := -1;
  SymTab[I].ParamKind      := PK_VALUE;
  SymTab[I].IsSealed       := False;
  SymTab[I].IsConstructor  := False;
  SymTab[I].IsClassMethod  := False;
 End;
 SymRegisterBuiltins;
End;

{ ------------------------------------------------------------ }
{ SymMangle : generer un nom mangled pour un symbole selon sa   }
{ categorie, pour l emission ASM des TODO 07/08/16.             }
{ ------------------------------------------------------------ }

Function SymMangle(Const Name: TString; Kind: TSymKind): TString;
Begin
 Case Kind Of
  SK_CONST     : SymMangle := DP_VAR_PFX + Name;
  SK_TYPE      : SymMangle := Name;
  SK_VAR       : SymMangle := DP_VAR_PFX + Name;
  SK_PARAM     : SymMangle := DP_VAR_PFX + Name;
  SK_PROC      : SymMangle := DP_FUNC_PFX + Name;
  SK_FUNC      : SymMangle := DP_FUNC_PFX + Name;
  SK_FIELD     : SymMangle := DP_FLD_PFX + Name;
  SK_METHOD    : SymMangle := DP_FUNC_PFX + Name;
  SK_UNIT      : SymMangle := Name;
  SK_LABEL     : SymMangle := DP_LBL_PFX + Name;
  SK_PROPERTY  : SymMangle := Name;
  SK_CLASS     : SymMangle := DP_CLS_PFX + Name;
  SK_INTERFACE : SymMangle := DP_CLS_PFX + Name;
 Else
  SymMangle := DP_VAR_PFX + Name;
 End;
End;

{ ------------------------------------------------------------ }
{ ScopeIdActive : est-ce que ScopeId est la portee globale (0)  }
{ ou fait-il partie de la pile des portees actives ?            }
{ ------------------------------------------------------------ }

Function ScopeIdActive(Id: Integer): Boolean;
Var I: Integer;
Begin
 If Id = 0 Then
 Begin
  ScopeIdActive := True;
  Exit;
 End;
 For I := 0 To ScopeStackTop Do
  If ScopeStack[I] = Id Then
  Begin
   ScopeIdActive := True;
   Exit;
  End;
 ScopeIdActive := False;
End;

{ ------------------------------------------------------------ }
{ SymFindInScope : chercher un symbole dans une portee precise  }
{ (identifiee par son ScopeId, 0 = portee globale). Sert a      }
{ detecter les doublons de declaration et a resoudre            }
{ Self.Champ / les membres d une classe donnee.                 }
{ Comparaison insensible a la casse.                             }
{ ------------------------------------------------------------ }

Function SymFindInScope(Const Name: TString; TargetScopeId: Integer): Integer;
Var
 I  : Integer;
 Up : TString;
Begin
 Up := StrUpperCase(Name);
 For I := SymCount - 1 DownTo 0 Do
  If (SymTab[I].Name = Up) And (SymTab[I].ScopeId = TargetScopeId) Then
  Begin
   SymFindInScope := I;
   Exit;
  End;
 SymFindInScope := -1;
End;

{ ------------------------------------------------------------ }
{ SymFind : chercher un symbole visible depuis la portee        }
{ courante : la pile des portees actives, puis la portee        }
{ globale. Les portees les plus imbriquees masquent les portees }
{ externes (recherche de la fin vers le debut de la table).     }
{ ------------------------------------------------------------ }

Function SymFind(Const Name: TString): Integer;
Var
 I  : Integer;
 Up : TString;
Begin
 Up := StrUpperCase(Name);
 For I := SymCount - 1 DownTo 0 Do
  If (SymTab[I].Name = Up) And
     (SymTab[I].IsGlobal Or ScopeIdActive(SymTab[I].ScopeId)) Then
  Begin
   SymFind := I;
   Exit;
  End;
 SymFind := -1;
End;

{ ------------------------------------------------------------ }
{ SymFindInUnit : chercher un symbole qualifie par unite        }
{ Ex: SysUtils.Trim -> chercher TRIM avec UnitName='SYSUTILS'   }
{ ------------------------------------------------------------ }

Function SymFindInUnit(Const UName, Name: TString): Integer;
Var
 I  : Integer;
 Up : TString;
 UU : TString;
Begin
 Up := StrUpperCase(Name);
 UU := StrUpperCase(UName);
 For I := SymCount - 1 DownTo 0 Do
  If (SymTab[I].Name = Up) And (SymTab[I].UnitName = UU) Then
  Begin
   SymFindInUnit := I;
   Exit;
  End;
 SymFindInUnit := -1;
End;

{ ------------------------------------------------------------ }
{ SymFindInClass : chercher un membre (champ/methode/propriete) }
{ declare directement dans la classe ClassIdx. Sert a resoudre  }
{ Self.Champ et les acces qualifies Classe.Membre.               }
{ ------------------------------------------------------------ }

Function SymFindInClass(ClassIdx: Integer; Const Name: TString): Integer;
Begin
 If (ClassIdx < 0) Or (SymTab[ClassIdx].MemberScopeId < 0) Then
 Begin
  SymFindInClass := -1;
  Exit;
 End;
 SymFindInClass := SymFindInScope(Name, SymTab[ClassIdx].MemberScopeId);
End;

{ ------------------------------------------------------------ }
{ SymFindInherited : chercher un membre en remontant la chaine  }
{ des ancetres a partir de ClassIdx (sans regarder ClassIdx     }
{ lui-meme). Sert a resoudre 'inherited Methode'.                }
{ ------------------------------------------------------------ }

Function SymFindInherited(ClassIdx: Integer; Const Name: TString): Integer;
Var
 C, R: Integer;
Begin
 R := -1;
 If ClassIdx >= 0 Then
 Begin
  C := SymTab[ClassIdx].ParentClassIdx;
  While C >= 0 Do
  Begin
   R := SymFindInClass(C, Name);
   If R >= 0 Then Break;
   C := SymTab[C].ParentClassIdx;
  End;
 End;
 SymFindInherited := R;
End;

{ ------------------------------------------------------------ }
{ SymAdd : ajouter un symbole dans la table, dans la portee     }
{ courante. Retourne l index du symbole ajoute, ou -1 si erreur.}
{ ------------------------------------------------------------ }

Function SymAdd(Const Name: TString; Kind: TSymKind; TIdx: Integer): Integer;
Var
 Up  : TString;
 Dup : Integer;
Begin
 If SymCount >= MAX_SYM Then
 Begin
  WarnMsg('table des symboles pleine (MAX_SYM=' + IntToStr_(MAX_SYM) + ')');
  SymAdd := -1;
  Exit;
 End;

 Up  := StrUpperCase(Name);
 Dup := SymFindInScope(Up, CurScopeId);
 If Dup >= 0 Then
 Begin
  { Permettre la redefinition d une declaration forward/externe }
  If SymTab[Dup].IsExternal And (Kind In [SK_PROC, SK_FUNC, SK_METHOD]) Then
  Begin
   SymTab[Dup].Kind       := Kind;
   SymTab[Dup].TypeIdx    := TIdx;
   SymTab[Dup].IsExternal := False;
   SymAdd := Dup;
   Exit;
  End
  Else
  Begin
   WarnMsg('symbole deja defini dans cette portee: ' + Up);
   SymAdd := Dup;
   Exit;
  End;
 End;

 SymTab[SymCount].Name           := Up;
 SymTab[SymCount].MangledName    := SymMangle(Up, Kind);
 SymTab[SymCount].Kind           := Kind;
 SymTab[SymCount].TypeIdx        := TIdx;
 SymTab[SymCount].Offset         := 0;
 SymTab[SymCount].ScopeLevel     := CurScopeLevel;
 SymTab[SymCount].ScopeId        := CurScopeId;
 SymTab[SymCount].IsGlobal       := (CurScopeLevel = 0);
 SymTab[SymCount].IsExternal     := False;
 SymTab[SymCount].UnitName       := '';
 SymTab[SymCount].ImmVal         := 0;
 SymTab[SymCount].ParamCount     := 0;
 SymTab[SymCount].ParentClassIdx := -1;
 SymTab[SymCount].MemberScopeId  := -1;
 SymTab[SymCount].ParamKind      := PK_VALUE;
 SymTab[SymCount].IsSealed       := False;
 SymTab[SymCount].IsConstructor  := False;
 SymTab[SymCount].IsClassMethod  := False;

 SymAdd := SymCount;
 Inc(SymCount);
End;

{ ------------------------------------------------------------ }
{ SymEnterScope / SymLeaveScope : ouvrir/fermer une portee       }
{ anonyme (bloc, corps de procedure/methode). SymEnterNamedScope}
{ rouvre une portee existante (celle des membres d une classe)  }
{ pour compiler le corps d une methode declaree ailleurs dans   }
{ le fichier (section implementation) - c est ce qui permet a   }
{ Self.Champ de fonctionner sans imbrication lexicale reelle.   }
{ ------------------------------------------------------------ }

Procedure SymEnterNamedScope(Id: Integer);
Begin
 If ScopeStackTop >= MAX_SCOPE - 1 Then
 Begin
  WarnMsg('profondeur de portee maximale atteinte');
  Exit;
 End;
 Inc(ScopeStackTop);
 ScopeStack[ScopeStackTop] := Id;
 CurScopeLevel := ScopeStackTop + 1;
 CurScopeId    := Id;
 If Opts.DebugMode Then
  WriteLn('  SCOPE_ENTER: level=', CurScopeLevel, ' id=', CurScopeId);
End;

Procedure SymEnterScope;
Begin
 Inc(ScopeIdSeq);
 SymEnterNamedScope(ScopeIdSeq);
End;

Procedure SymEnterClassScope(ClassIdx: Integer);
Begin
 If (ClassIdx < 0) Or (SymTab[ClassIdx].MemberScopeId < 0) Then
 Begin
  WarnMsg('SymEnterClassScope: classe invalide');
  Exit;
 End;
 SymEnterNamedScope(SymTab[ClassIdx].MemberScopeId);
End;

Procedure SymLeaveScope;
Begin
 If ScopeStackTop < 0 Then
 Begin
  WarnMsg('tentative de quitter la portee globale');
  Exit;
 End;
 If Opts.DebugMode Then
  WriteLn('  SCOPE_LEAVE: level=', CurScopeLevel);
 Dec(ScopeStackTop);
 CurScopeLevel := ScopeStackTop + 1;
 If ScopeStackTop < 0 Then
  CurScopeId := 0
 Else
  CurScopeId := ScopeStack[ScopeStackTop];
End;

{ ------------------------------------------------------------ }
{ SymDeclareClass : enregistrer une classe ou une interface et  }
{ lui allouer sa propre portee de membres (champs/methodes).    }
{ ------------------------------------------------------------ }

Function SymDeclareClass(Const Name: TString; Kind: TSymKind;
 ParentIdx: Integer): Integer;
Var
 R, ParentTypeIdx : Integer;
Begin
 R := SymAdd(Name, Kind, -1);
 If R >= 0 Then
 Begin
  SymTab[R].IsGlobal       := True;
  SymTab[R].ParentClassIdx := ParentIdx;
  Inc(ScopeIdSeq);
  SymTab[R].MemberScopeId := ScopeIdSeq;

  If ParentIdx >= 0 Then
   ParentTypeIdx := SymTab[ParentIdx].TypeIdx
  Else
   ParentTypeIdx := -1;

  If Kind = SK_INTERFACE Then
   SymTab[R].TypeIdx := TypeAddInterface(Name, ParentTypeIdx, R)
  Else
   SymTab[R].TypeIdx := TypeAddClass(Name, ParentTypeIdx, R);
 End;
 SymDeclareClass := R;
End;

{ ------------------------------------------------------------ }
{ SymRegisterBuiltins : pre-enregistrer les types ordinaux, les }
{ constantes, les classes de base et les procedures/fonctions   }
{ predefinies de l unite System, toujours visibles sans 'uses'. }
{ Les procedures/fonctions de RTL plus specifiques (voir TODO   }
{ 22) seront ajoutees par les unites System.pas/SysUtils.pas    }
{ simulees dans un TODO ulterieur.                               }
{ ------------------------------------------------------------ }

Procedure SymRegisterBuiltins;
Var
 TObjectIdx, ExceptionIdx : Integer;

 Procedure RegType(Const Name: TString);
 Var R: Integer;
 Begin
  R := SymAdd(Name, SK_TYPE, TypeFindByName(Name));
  If R >= 0 Then SymTab[R].IsGlobal := True;
 End;

 Procedure RegConst(Const Name: TString; Val: LongInt);
 Var R: Integer;
 Begin
  R := SymAdd(Name, SK_CONST, -1);
  If R >= 0 Then
  Begin
   SymTab[R].ImmVal   := Val;
   SymTab[R].IsGlobal := True;
  End;
 End;

 Procedure RegProc(Const Name: TString);
 Var R: Integer;
 Begin
  R := SymAdd(Name, SK_PROC, -1);
  If R >= 0 Then
  Begin
   SymTab[R].IsGlobal   := True;
   SymTab[R].IsExternal := True;
  End;
 End;

 Procedure RegFunc(Const Name: TString);
 Var R: Integer;
 Begin
  R := SymAdd(Name, SK_FUNC, -1);
  If R >= 0 Then
  Begin
   SymTab[R].IsGlobal   := True;
   SymTab[R].IsExternal := True;
  End;
 End;

 { Enregistrer une fonction RTL (System/SysUtils, TODO 12) dotee d un }
 { corps runtime REEL (_DPRT_..., voir EmitRuntimeLibrary) : contrairement}
 { a RegFunc, le nom mangled pointe directement sur ce label, ce qui  }
 { permet a ParseCall (TODO 10, mecanisme d appel generique) de       }
 { l invoquer sans aucun code de dispatch special.                     }
 Procedure RegRTLFunc(Const Name, RuntimeLabel: TString);
 Var R: Integer;
 Begin
  R := SymAdd(Name, SK_FUNC, -1);
  If R >= 0 Then
  Begin
   SymTab[R].IsGlobal    := True;
   SymTab[R].IsExternal  := True;
   SymTab[R].MangledName := RuntimeLabel;
  End;
 End;

 { Enregistrer une methode dans la portee de membres de la classe
   couramment ouverte via SymEnterClassScope. Le nom mangled est
   qualifie par le nom de la classe (OwnerClassName) : deux classes
   differentes ayant chacune une methode de meme nom (frequent en
   POO, ex. Create/Destroy) ne doivent jamais partager le meme
   label ASM - contrairement au SymMangle par defaut (TODO 05), qui
   ne qualifie pas les methodes par leur classe (voir TODO 15,
   ParseClassMethodDecl, qui applique la meme regle aux classes
   utilisateur). Retourne l index du symbole (utile pour le
   cablage de la VMT, ex. Destroy dans ClassSystemInit). }
 Function RegMethod(Const OwnerClassName, Name: TString): Integer;
 Var R: Integer;
 Begin
  R := SymAdd(Name, SK_METHOD, -1);
  If R >= 0 Then
  Begin
   SymTab[R].IsExternal  := True;
   SymTab[R].MangledName := DP_FUNC_PFX + StrUpperCase(OwnerClassName) +
    '_' + StrUpperCase(Name);
  End;
  RegMethod := R;
 End;

Begin
 { -------------------------------------------------------- }
 { Types ordinaux et chaine predefinis (unite System)       }
 { -------------------------------------------------------- }
 RegType('INTEGER');   RegType('CARDINAL');
 RegType('LONGINT');   RegType('LONGWORD');
 RegType('INT64');     RegType('UINT64');
 RegType('BYTE');      RegType('SHORTINT');
 RegType('WORD');      RegType('SMALLINT');
 RegType('BOOLEAN');   RegType('CHAR');
 RegType('ANSICHAR');  RegType('WIDECHAR');
 RegType('STRING');    RegType('ANSISTRING');
 RegType('SHORTSTRING'); RegType('PCHAR');
 RegType('SINGLE');    RegType('DOUBLE');
 RegType('EXTENDED');  RegType('CURRENCY');
 RegType('POINTER');   RegType('VARIANT');
 RegType('TCLASS');    { reference de classe : class of TObject }

 { -------------------------------------------------------- }
 { Constantes predefinies                                    }
 { -------------------------------------------------------- }
 RegConst('TRUE', 1);
 RegConst('FALSE', 0);
 RegConst('NIL', 0);
 RegConst('MAXINT', 2147483647);

 { -------------------------------------------------------- }
 { TObject : racine de toute la hierarchie de classes        }
 { -------------------------------------------------------- }
 TObjectIdx := SymDeclareClass('TOBJECT', SK_CLASS, -1);
 SymEnterClassScope(TObjectIdx);
 RegMethod('TObject', 'CREATE');
 RegMethod('TObject', 'DESTROY');
 RegMethod('TObject', 'FREE');
 RegMethod('TObject', 'CLASSNAME');
 RegMethod('TObject', 'CLASSTYPE');
 SymLeaveScope;

 { -------------------------------------------------------- }
 { Exception : classe de base des exceptions (try/except)   }
 { herite de TObject, sans redefinir Create : SymFindInherited}
 { doit remonter jusqu a TObject.Create pour la resoudre.    }
 { -------------------------------------------------------- }
 ExceptionIdx := SymDeclareClass('EXCEPTION', SK_CLASS, TObjectIdx);
 SymEnterClassScope(ExceptionIdx);
 RegMethod('Exception', 'MESSAGE');
 SymLeaveScope;

 { -------------------------------------------------------- }
 { Procedures et fonctions de base, toujours disponibles     }
 { (le detail des signatures viendra avec TODO 22)           }
 { -------------------------------------------------------- }
 RegProc('WRITE');    RegProc('WRITELN');
 RegProc('READ');     RegProc('READLN');
 RegProc('INC');      RegProc('DEC');
 RegProc('EXIT');     RegProc('HALT');
 RegProc('NEW');      RegProc('DISPOSE');
 RegProc('GETMEM');   RegProc('FREEMEM');
 RegProc('FREEANDNIL'); RegProc('ASSERT');
 RegProc('BREAK');    RegProc('CONTINUE');   { TODO 13 }

 RegFunc('ORD');      RegFunc('CHR');
 RegFunc('SUCC');     RegFunc('PRED');
 RegFunc('LOW');      RegFunc('HIGH');
 RegFunc('SIZEOF');   RegFunc('LENGTH');
 RegFunc('ABS');      RegFunc('ASSIGNED');

 { -------------------------------------------------------- }
 { RTL minimale System/SysUtils (TODO 12), corps reels dans  }
 { EmitRuntimeLibrary. Write/WriteLn/Read/ReadLn restent des  }
 { RegProc simples : ils sont variadiques et routes par un    }
 { dispatch special dans ParsePrimary, pas par un CALL direct.}
 { -------------------------------------------------------- }
 RegRTLFunc('INTTOSTR', DPRT_INTTOSTR);
 RegRTLFunc('STRTOINT', DPRT_STRTOINT);
 RegRTLFunc('STRTOINTDEF', DPRT_STRTOINTDEF);
 RegRTLFunc('FLOATTOSTR', DPRT_FLOATTOSTR);
 RegRTLFunc('STRTOFLOAT', DPRT_STRTOFLOAT);
 RegRTLFunc('TRIM', DPRT_TRIM);
 RegRTLFunc('UPPERCASE', DPRT_UPPERCASE);
 RegRTLFunc('LOWERCASE', DPRT_LOWERCASE);
 RegRTLFunc('COMPARESTR', DPRT_COMPARESTR);
 RegRTLFunc('COMPARETEXT', DPRT_COMPARETEXT);
 RegProc('FORMAT');   { variadique ([args]) : stub, voir TODO 19 }
End;

{ ------------------------------------------------------------ }
{ SymAssert : verifie une condition attendue par SymSelfTest et }
{ arrete le compilateur avec un message clair en cas d echec.   }
{ ------------------------------------------------------------ }

Procedure SymAssert(Const Label_: TString; Cond: Boolean);
Begin
 If Not Cond Then
  FatalError('SymSelfTest: ' + Label_ + ' a echoue');
End;

{ ------------------------------------------------------------ }
{ SymSelfTest : verifie la table des symboles et la gestion des }
{ portees avec des cas connus (identificateurs predefinis,      }
{ imbrication de portees, masquage de variables, qualification  }
{ de classe et 'inherited'). Execute a chaque lancement (cout    }
{ negligeable) pour garantir que cette brique reste correcte au }
{ fil des futurs TODOs qui s appuieront dessus.                  }
{ ------------------------------------------------------------ }

Procedure SymSelfTest;
Var
 IntIdx, TObjIdx, ExcIdx, GlobalX, LocalX, CreateIdx, QualIdx : Integer;
Begin
 SymInit;

 { Identificateurs predefinis de System }
 IntIdx := SymFind('Integer');
 SymAssert('Integer trouve', IntIdx >= 0);
 SymAssert('Integer est un type', SymTab[IntIdx].Kind = SK_TYPE);
 SymAssert('True = 1', SymTab[SymFind('True')].ImmVal = 1);
 SymAssert('False trouve', SymFind('False') >= 0);

 TObjIdx := SymFind('TObject');
 SymAssert('TObject trouve', TObjIdx >= 0);
 SymAssert('TObject est une classe', SymTab[TObjIdx].Kind = SK_CLASS);
 SymAssert('TObject sans ancetre', SymTab[TObjIdx].ParentClassIdx = -1);

 ExcIdx := SymFind('Exception');
 SymAssert('Exception trouve', ExcIdx >= 0);
 SymAssert('Exception herite de TObject',
  SymTab[ExcIdx].ParentClassIdx = TObjIdx);

 { Self.Champ : les methodes de TObject sont dans sa portee de membres }
 SymAssert('TObject.Create (membre direct)',
  SymFindInClass(TObjIdx, 'Create') >= 0);
 SymAssert('Exception.Create absent en direct',
  SymFindInClass(ExcIdx, 'Create') < 0);

 { inherited Methode : Exception doit trouver Create via TObject }
 CreateIdx := SymFindInherited(ExcIdx, 'Create');
 SymAssert('inherited Create resolu via TObject', CreateIdx >= 0);
 SymAssert('inherited Create pointe le bon symbole',
  CreateIdx = SymFindInClass(TObjIdx, 'Create'));

 { Portees imbriquees et masquage (variable globale puis locale) }
 GlobalX := SymAdd('X', SK_VAR, -1);
 SymAssert('X global ajoute', GlobalX >= 0);
 SymAssert('X global visible', SymFind('X') = GlobalX);

 SymEnterScope;
  LocalX := SymAdd('X', SK_VAR, -1);
  SymAssert('X local ajoute', LocalX >= 0);
  SymAssert('X local masque X global', SymFind('X') = LocalX);
  SymEnterScope;
   SymAssert('X local visible depuis un bloc plus imbrique',
    SymFind('X') = LocalX);
  SymLeaveScope;
 SymLeaveScope;
 SymAssert('X global revisible apres sortie de portee',
  SymFind('X') = GlobalX);

 { Qualification Unit.Ident - un nom synthetique improbable est utilise }
 { pour ne pas dependre de ce qui est deja enregistre par ailleurs      }
 { (ex: TRIM, une vraie RTL depuis TODO 12), et l index retourne par    }
 { SymAdd est capture explicitement plutot que suppose = SymCount - 1  }
 { (faux des que SymAdd redefinit un symbole existant au lieu d en      }
 { ajouter un nouveau).                                                 }
 QualIdx := SymAdd('SYMSELFTESTQUALFUNC', SK_FUNC, -1);
 SymTab[QualIdx].UnitName := 'SYSUTILS';
 SymAssert('SysUtils.SymSelfTestQualFunc trouve par SymFindInUnit',
  SymFindInUnit('SysUtils', 'SymSelfTestQualFunc') >= 0);
 SymAssert('Nom qualifie introuvable dans une autre unite',
  SymFindInUnit('CRT', 'SymSelfTestQualFunc') < 0);

 SymInit;   { restaurer une table propre pour la vraie compilation }
End;

{ ============================================================ }
{ TODO 06 - SYSTEME DE TYPES DELPHI                  [IMPLEMENTE] }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ TypeAdd : ajouter un type dans la table, retourne son index   }
{ ou -1 si la table est pleine.                                 }
{ ------------------------------------------------------------ }

Function TypeAdd(Kind: TTypeKind; Const AName: TString;
 ASize, AAlign: Integer; AUnsigned: Boolean; ABaseTypeIdx: Integer): Integer;
Begin
 If TypeCount >= MAX_TYPE Then
 Begin
  WarnMsg('table des types pleine (MAX_TYPE=' + IntToStr_(MAX_TYPE) + ')');
  TypeAdd := -1;
  Exit;
 End;

 TypeTab[TypeCount].Kind        := Kind;
 TypeTab[TypeCount].Name        := StrUpperCase(AName);
 TypeTab[TypeCount].Size        := ASize;
 TypeTab[TypeCount].Align       := AAlign;
 TypeTab[TypeCount].BaseTypeIdx := ABaseTypeIdx;
 TypeTab[TypeCount].Lo          := 0;
 TypeTab[TypeCount].Hi          := 0;
 TypeTab[TypeCount].IsDynArray  := False;
 TypeTab[TypeCount].FieldFirst  := -1;
 TypeTab[TypeCount].FieldCount  := 0;
 TypeTab[TypeCount].EnumFirst   := -1;
 TypeTab[TypeCount].EnumCount   := 0;
 TypeTab[TypeCount].IsUnsigned  := AUnsigned;
 TypeTab[TypeCount].IsMethodPtr := False;
 TypeTab[TypeCount].ParamCount  := 0;
 TypeTab[TypeCount].ClassSymIdx := -1;
 TypeTab[TypeCount].VMTFirst    := -1;
 TypeTab[TypeCount].VMTCount    := 0;
 TypeTab[TypeCount].InstanceSize := 0;

 TypeAdd := TypeCount;
 Inc(TypeCount);
End;

{ ------------------------------------------------------------ }
{ DPTypeKindForName / DPTypeIsUnsigned : classifient un nom de  }
{ type primitif de DelphiTypeSizes (TODO 04) pour construire la }
{ table des types a partir de cette source unique de verite.    }
{ ------------------------------------------------------------ }

Function DPTypeKindForName(Const N: TString): TTypeKind;
Begin
 If (N = 'BOOLEAN') Then DPTypeKindForName := TYK_BOOLEAN
 Else If (N = 'CHAR') Or (N = 'ANSICHAR') Or (N = 'WIDECHAR') Then
  DPTypeKindForName := TYK_CHAR
 Else If (N = 'SINGLE') Or (N = 'DOUBLE') Or (N = 'EXTENDED') Or
         (N = 'CURRENCY') Or (N = 'COMP') Then
  DPTypeKindForName := TYK_REAL
 Else If (N = 'POINTER') Then DPTypeKindForName := TYK_POINTER
 Else If (N = 'PCHAR') Then DPTypeKindForName := TYK_PCHAR
 Else If (N = 'STRING') Or (N = 'ANSISTRING') Or (N = 'SHORTSTRING') Then
  DPTypeKindForName := TYK_STRING
 Else
  DPTypeKindForName := TYK_INTEGER;   { INTEGER, CARDINAL, LONGINT, ... }
End;

Function DPTypeIsUnsigned(Const N: TString): Boolean;
Begin
 DPTypeIsUnsigned :=
  (N = 'CARDINAL') Or (N = 'LONGWORD') Or (N = 'UINT64') Or
  (N = 'BYTE') Or (N = 'WORD') Or (N = 'BOOLEAN') Or
  (N = 'CHAR') Or (N = 'ANSICHAR') Or (N = 'WIDECHAR');
End;

{ ------------------------------------------------------------ }
{ TypeInit : initialiser la table des types avec les types      }
{ primitifs de Delphi (Win32, 32 bits), a partir de la table    }
{ DelphiTypeSizes deja posee au TODO 04 (source unique de       }
{ verite pour les tailles).                                     }
{ ------------------------------------------------------------ }

Procedure TypeInit;
Var
 I, TI : Integer;
 N     : TString;
 Al    : Integer;
Begin
 TypeCount        := 0;
 FieldPoolCount   := 0;
 EnumValPoolCount := 0;

 For I := 0 To MAX_DP_TYPE_SIZES - 1 Do
 Begin
  N := DelphiTypeSizes[I].Name;
  If N = 'SHORTSTRING' Then Al := 1
  Else If DelphiTypeSizes[I].Size < 4 Then Al := DelphiTypeSizes[I].Size
  Else Al := 4;
  TypeAdd(DPTypeKindForName(N), N, DelphiTypeSizes[I].Size, Al,
   DPTypeIsUnsigned(N), -1);
 End;

 { PChar pointe vers Char }
 TI := TypeFindByName('CHAR');
 I  := TypeFindByName('PCHAR');
 If (TI >= 0) And (I >= 0) Then TypeTab[I].BaseTypeIdx := TI;

 { Alias historiques Turbo Pascal : meme representation, nom different }
 TI := TypeFindByName('INTEGER');
 I  := TypeFindByName('LONGINT');
 If (TI >= 0) And (I >= 0) Then TypeTab[I].BaseTypeIdx := TI;

 TI := TypeFindByName('CARDINAL');
 I  := TypeFindByName('LONGWORD');
 If (TI >= 0) And (I >= 0) Then TypeTab[I].BaseTypeIdx := TI;

 TI := TypeFindByName('STRING');
 I  := TypeFindByName('ANSISTRING');
 If (TI >= 0) And (I >= 0) Then TypeTab[I].BaseTypeIdx := TI;

 { Types supplementaires non couverts par DelphiTypeSizes }
 TypeAdd(TYK_NIL, 'NIL', 4, 4, False, -1);
 TypeAdd(TYK_VARIANT, 'VARIANT', 16, 4, False, -1);   { stub minimal }
 TypeAdd(TYK_POINTER, 'TCLASS', 4, 4, False, -1);      { class of TObject }

 If Opts.DebugMode Then
  WriteLn('  [TypeInit] ', TypeCount, ' types primitifs enregistres');
End;

{ ------------------------------------------------------------ }
{ TypeFindByName : trouver un type par son nom exact, retourne  }
{ -1 si non trouve.                                             }
{ ------------------------------------------------------------ }

Function TypeFindByName(Const AName: TString): Integer;
Var
 I  : Integer;
 Up : TString;
Begin
 TypeFindByName := -1;
 Up := StrUpperCase(AName);
 For I := 0 To TypeCount - 1 Do
  If TypeTab[I].Name = Up Then
  Begin
   TypeFindByName := I;
   Exit;
  End;
End;

{ ------------------------------------------------------------ }
{ TypeSizeofIdx : taille d un type par son index, 4 par defaut  }
{ (DWORD) si l index est invalide.                              }
{ ------------------------------------------------------------ }

Function TypeSizeofIdx(Idx: Integer): Integer;
Begin
 If (Idx >= 0) And (Idx < TypeCount) Then
  TypeSizeofIdx := TypeTab[Idx].Size
 Else
  TypeSizeofIdx := 4;
End;

{ ------------------------------------------------------------ }
{ TypeResolve : suivre les alias (BaseTypeIdx) jusqu au type    }
{ reel. S arrete sur les types composes, ou BaseTypeIdx designe }
{ l element/ancetre et non un simple synonyme.                  }
{ ------------------------------------------------------------ }

Function TypeResolve(Idx: Integer): Integer;
Var
 Cur, Depth : Integer;
Begin
 Cur   := Idx;
 Depth := 0;
 While (Cur >= 0) And (Cur < TypeCount) And (Depth < 32) Do
 Begin
  If TypeTab[Cur].BaseTypeIdx < 0 Then Break;
  If TypeTab[Cur].Kind In [TYK_POINTER, TYK_PCHAR, TYK_ARRAY, TYK_RECORD,
     TYK_SET, TYK_ENUM, TYK_SUBRANGE, TYK_PROCTYPE, TYK_CLASS,
     TYK_INTERFACE] Then Break;
  Cur := TypeTab[Cur].BaseTypeIdx;
  Inc(Depth);
 End;
 TypeResolve := Cur;
End;

{ ------------------------------------------------------------ }
{ Predicats de classification de types (operent sur le type     }
{ resolu, donc transparents aux alias comme LongInt=Integer).   }
{ ------------------------------------------------------------ }

Function TypeIsOrdinal(Idx: Integer): Boolean;
Var R: Integer;
Begin
 R := TypeResolve(Idx);
 If (R < 0) Or (R >= TypeCount) Then
 Begin TypeIsOrdinal := False; Exit; End;
 TypeIsOrdinal := TypeTab[R].Kind In
  [TYK_INTEGER, TYK_CHAR, TYK_BOOLEAN, TYK_ENUM, TYK_SUBRANGE];
End;

Function TypeIsNumeric(Idx: Integer): Boolean;
Var R: Integer;
Begin
 R := TypeResolve(Idx);
 If (R < 0) Or (R >= TypeCount) Then
 Begin TypeIsNumeric := False; Exit; End;
 TypeIsNumeric := TypeTab[R].Kind In
  [TYK_INTEGER, TYK_CHAR, TYK_BOOLEAN, TYK_ENUM, TYK_SUBRANGE, TYK_REAL];
End;

Function TypeIsPointer(Idx: Integer): Boolean;
Var R: Integer;
Begin
 R := TypeResolve(Idx);
 If (R < 0) Or (R >= TypeCount) Then
 Begin TypeIsPointer := False; Exit; End;
 TypeIsPointer := TypeTab[R].Kind In [TYK_POINTER, TYK_PCHAR, TYK_NIL];
End;

Function TypeIsString(Idx: Integer): Boolean;
Var R: Integer;
Begin
 R := TypeResolve(Idx);
 If (R < 0) Or (R >= TypeCount) Then
 Begin TypeIsString := False; Exit; End;
 TypeIsString := TypeTab[R].Kind In [TYK_STRING, TYK_PCHAR];
End;

Function TypeIsReal(Idx: Integer): Boolean;
Var R: Integer;
Begin
 R := TypeResolve(Idx);
 If (R < 0) Or (R >= TypeCount) Then
 Begin TypeIsReal := False; Exit; End;
 TypeIsReal := TypeTab[R].Kind = TYK_REAL;
End;

{ TypeIsBoolean : distingue le ET/OU logique (court-circuit, Boolean) }
{ du ET/OU/OU-EXCLUSIF bit a bit (ordinaux) - meme operateur source,  }
{ deux semantiques, voir TODO 11.                                     }
Function TypeIsBoolean(Idx: Integer): Boolean;
Var R: Integer;
Begin
 R := TypeResolve(Idx);
 If (R < 0) Or (R >= TypeCount) Then
 Begin TypeIsBoolean := False; Exit; End;
 TypeIsBoolean := TypeTab[R].Kind = TYK_BOOLEAN;
End;

Function TypeIsClass(Idx: Integer): Boolean;
Var R: Integer;
Begin
 R := TypeResolve(Idx);
 If (R < 0) Or (R >= TypeCount) Then
 Begin TypeIsClass := False; Exit; End;
 TypeIsClass := TypeTab[R].Kind = TYK_CLASS;
End;

Function TypeIsInterface(Idx: Integer): Boolean;
Var R: Integer;
Begin
 R := TypeResolve(Idx);
 If (R < 0) Or (R >= TypeCount) Then
 Begin TypeIsInterface := False; Exit; End;
 TypeIsInterface := TypeTab[R].Kind = TYK_INTERFACE;
End;

{ ------------------------------------------------------------ }
{ TypeCoerce : type resultat d une operation binaire entre deux }
{ types (promotion Delphi) : reel > pointeur > ordinal, et pour }
{ deux ordinaux, le plus grand gagne (signe gagne a taille egale)}
{ ------------------------------------------------------------ }

Function TypeCoerce(IdxA, IdxB: Integer): Integer;
Var
 RA, RB : Integer;
Begin
 RA := TypeResolve(IdxA);
 RB := TypeResolve(IdxB);

 If (RA < 0) Or (RA >= TypeCount) Then Begin TypeCoerce := RB; Exit; End;
 If (RB < 0) Or (RB >= TypeCount) Then Begin TypeCoerce := RA; Exit; End;

 If TypeIsReal(RA) Or TypeIsReal(RB) Then
 Begin
  If Not TypeIsReal(RA) Then Begin TypeCoerce := RB; Exit; End;
  If Not TypeIsReal(RB) Then Begin TypeCoerce := RA; Exit; End;
  If TypeTab[RA].Size >= TypeTab[RB].Size Then TypeCoerce := RA
  Else TypeCoerce := RB;
  Exit;
 End;

 If TypeIsPointer(RA) Then Begin TypeCoerce := RA; Exit; End;
 If TypeIsPointer(RB) Then Begin TypeCoerce := RB; Exit; End;

 If TypeTab[RA].Size <> TypeTab[RB].Size Then
 Begin
  If TypeTab[RA].Size > TypeTab[RB].Size Then TypeCoerce := RA
  Else TypeCoerce := RB;
  Exit;
 End;

 If TypeTab[RA].IsUnsigned And Not TypeTab[RB].IsUnsigned Then
  TypeCoerce := RB
 Else
  TypeCoerce := RA;
End;

{ ------------------------------------------------------------ }
{ TypeAddPointer : creer (ou reutiliser) un type pointeur vers  }
{ BaseTypeIdx. Dedoublonne pour eviter de recreer '^T' a chaque }
{ appel.                                                         }
{ ------------------------------------------------------------ }

Function TypeAddPointer(BaseTypeIdx: Integer): Integer;
Var I: Integer;
Begin
 For I := 0 To TypeCount - 1 Do
  If (TypeTab[I].Kind = TYK_POINTER) And
     (TypeTab[I].BaseTypeIdx = BaseTypeIdx) Then
  Begin
   TypeAddPointer := I;
   Exit;
  End;
 TypeAddPointer := TypeAdd(TYK_POINTER, '', 4, 4, False, BaseTypeIdx);
End;

{ ------------------------------------------------------------ }
{ TypeAddSubrange : sous-intervalle Lo..Hi, meme representation }
{ que son type de base (ex: 1..100 occupe la taille d Integer). }
{ ------------------------------------------------------------ }

Function TypeAddSubrange(Lo, Hi: LongInt; BaseTypeIdx: Integer): Integer;
Var TI: Integer;
Begin
 TI := TypeAdd(TYK_SUBRANGE, '', TypeSizeofIdx(BaseTypeIdx), 4,
  False, BaseTypeIdx);
 If TI >= 0 Then
 Begin
  TypeTab[TI].Lo := Lo;
  TypeTab[TI].Hi := Hi;
 End;
 TypeAddSubrange := TI;
End;

{ ------------------------------------------------------------ }
{ TypeAddArray : ARRAY[Lo..Hi] OF T statique (Dynamic=False), ou}
{ ARRAY OF T dynamique (Dynamic=True, Lo/Hi ignores, taille = 4,}
{ un pointeur vers les donnees, voir TODO 19).                  }
{ ------------------------------------------------------------ }

Function TypeAddArray(BaseTypeIdx: Integer; Lo, Hi: LongInt;
 Dynamic: Boolean): Integer;
Var
 TI, Sz : Integer;
Begin
 If Dynamic Then Sz := 4
 Else Sz := (Hi - Lo + 1) * TypeSizeofIdx(BaseTypeIdx);
 TI := TypeAdd(TYK_ARRAY, '', Sz, 4, False, BaseTypeIdx);
 If TI >= 0 Then
 Begin
  TypeTab[TI].IsDynArray := Dynamic;
  If Not Dynamic Then
  Begin
   TypeTab[TI].Lo := Lo;
   TypeTab[TI].Hi := Hi;
  End;
 End;
 TypeAddArray := TI;
End;

{ ------------------------------------------------------------ }
{ TypeAddSet : SET OF T. Taille fixe MAX_SET_BYTES (TODO 04),    }
{ coherente avec le format TSetVal utilise par ConstEvalSet.    }
{ ------------------------------------------------------------ }

Function TypeAddSet(BaseTypeIdx: Integer): Integer;
Begin
 TypeAddSet := TypeAdd(TYK_SET, '', MAX_SET_BYTES, 1, False, BaseTypeIdx);
End;

{ ------------------------------------------------------------ }
{ TypeAddEnum / TypeAddEnumValue : enumeration construite de     }
{ facon incrementale (une valeur a la fois, comme le fera le    }
{ futur parseur en lisant TYPE T = (a, b, c)). La taille suit   }
{ la directive $Z1/$Z2/$Z4 (EnumSize, TODO 03).                 }
{ ------------------------------------------------------------ }

Function TypeAddEnum(Const Name: TString): Integer;
Begin
 TypeAddEnum := TypeAdd(TYK_ENUM, Name, EnumSize, EnumSize, False, -1);
End;

Function TypeAddEnumValue(EnumTypeIdx: Integer; Const ValName: TString;
 HasExplicitVal: Boolean; ExplicitVal: LongInt): Integer;
Var V: LongInt;
Begin
 If (EnumTypeIdx < 0) Or (EnumTypeIdx >= TypeCount) Or
    (EnumValPoolCount >= MAX_ENUMVAL_POOL) Then
 Begin
  TypeAddEnumValue := -1;
  Exit;
 End;

 If HasExplicitVal Then
  V := ExplicitVal
 Else If TypeTab[EnumTypeIdx].EnumCount = 0 Then
  V := 0
 Else
  V := EnumValPool[TypeTab[EnumTypeIdx].EnumFirst +
       TypeTab[EnumTypeIdx].EnumCount - 1].Value + 1;

 If TypeTab[EnumTypeIdx].EnumCount = 0 Then
  TypeTab[EnumTypeIdx].EnumFirst := EnumValPoolCount;

 EnumValPool[EnumValPoolCount].Name  := StrUpperCase(ValName);
 EnumValPool[EnumValPoolCount].Value := V;
 TypeAddEnumValue := EnumValPoolCount;
 Inc(EnumValPoolCount);
 Inc(TypeTab[EnumTypeIdx].EnumCount);
End;

{ ------------------------------------------------------------ }
{ TypeAddProc : type procedure/fonction. IsMethodPtr distingue  }
{ une simple procedure (pointeur code, 4 octets) d une methode  }
{ "of object" (paire pointeur-code/pointeur-Self, 8 octets).    }
{ ------------------------------------------------------------ }

Function TypeAddProc(Const Name: TString; IsMethodPtr: Boolean;
 AParamCount: Integer): Integer;
Var Sz, TI : Integer;
Begin
 If IsMethodPtr Then Sz := 8 Else Sz := 4;
 TI := TypeAdd(TYK_PROCTYPE, Name, Sz, 4, False, -1);
 If TI >= 0 Then
 Begin
  TypeTab[TI].IsMethodPtr := IsMethodPtr;
  TypeTab[TI].ParamCount  := AParamCount;
 End;
 TypeAddProc := TI;
End;

{ ------------------------------------------------------------ }
{ TypeAddRecord / TypeAddField : record construit de facon       }
{ incrementale. Chaque champ est aligne sur son propre          }
{ alignement (arrondi de l offset courant), et la taille et     }
{ l alignement du record sont mis a jour au fil des ajouts.     }
{ ------------------------------------------------------------ }

Function TypeAddRecord(Const Name: TString): Integer;
Begin
 TypeAddRecord := TypeAdd(TYK_RECORD, Name, 0, 1, False, -1);
End;

Function TypeAddField(RecTypeIdx: Integer; Const FieldName: TString;
 FieldTypeIdx: Integer): Integer;
Var
 FAlign, Off : Integer;
Begin
 If (RecTypeIdx < 0) Or (RecTypeIdx >= TypeCount) Or
    (FieldPoolCount >= MAX_FIELD_POOL) Then
 Begin
  TypeAddField := -1;
  Exit;
 End;

 FAlign := TypeSizeofIdx(FieldTypeIdx);
 If FAlign > 4 Then FAlign := 4;
 If FAlign < 1 Then FAlign := 1;

 { Une classe est representee par une reference de 4 octets (Size,   }
 { TODO 06) : cette valeur ne doit pas servir de curseur d offset des }
 { champs, qui utilise InstanceSize (taille reelle de l instance).   }
 { Un record n a pas cette distinction : Size est directement son     }
 { curseur/sa taille finale.                                          }
 If TypeTab[RecTypeIdx].Kind = TYK_CLASS Then
  Off := TypeTab[RecTypeIdx].InstanceSize
 Else
  Off := TypeTab[RecTypeIdx].Size;
 Off := ((Off + FAlign - 1) Div FAlign) * FAlign;

 If TypeTab[RecTypeIdx].FieldCount = 0 Then
  TypeTab[RecTypeIdx].FieldFirst := FieldPoolCount;

 FieldPool[FieldPoolCount].Name    := StrUpperCase(FieldName);
 FieldPool[FieldPoolCount].TypeIdx := FieldTypeIdx;
 FieldPool[FieldPoolCount].Offset  := Off;
 TypeAddField := FieldPoolCount;
 Inc(FieldPoolCount);
 Inc(TypeTab[RecTypeIdx].FieldCount);

 If TypeTab[RecTypeIdx].Kind = TYK_CLASS Then
  TypeTab[RecTypeIdx].InstanceSize := Off + TypeSizeofIdx(FieldTypeIdx)
 Else
  TypeTab[RecTypeIdx].Size := Off + TypeSizeofIdx(FieldTypeIdx);
 If FAlign > TypeTab[RecTypeIdx].Align Then
  TypeTab[RecTypeIdx].Align := FAlign;
End;

{ ------------------------------------------------------------ }
{ TypeAddClass / TypeAddInterface : classe ou interface, liee a }
{ son symbole SK_CLASS/SK_INTERFACE (AClassSymIdx) et a son     }
{ ancetre eventuel (ParentTypeIdx, -1 pour TObject). Une         }
{ instance de classe est representee par une reference (un      }
{ pointeur, 4 octets) comme en Delphi.                          }
{ ------------------------------------------------------------ }

Function TypeAddClass(Const Name: TString;
 ParentTypeIdx, AClassSymIdx: Integer): Integer;
Var TI: Integer;
Begin
 TI := TypeAdd(TYK_CLASS, Name, 4, 4, False, ParentTypeIdx);
 If TI >= 0 Then TypeTab[TI].ClassSymIdx := AClassSymIdx;
 TypeAddClass := TI;
End;

Function TypeAddInterface(Const Name: TString;
 ParentTypeIdx, AClassSymIdx: Integer): Integer;
Var TI: Integer;
Begin
 TI := TypeAdd(TYK_INTERFACE, Name, 4, 4, False, ParentTypeIdx);
 If TI >= 0 Then TypeTab[TI].ClassSymIdx := AClassSymIdx;
 TypeAddInterface := TI;
End;

{ ------------------------------------------------------------ }
{ TypeIsAssignCompatible : compatibilite d affectation implicite}
{ (Dest := Src). Couvre les promotions Delphi usuelles : meme    }
{ type, ordinal->ordinal, ordinal/reel->reel, nil->pointeur/     }
{ classe/interface, chaine<->chaine/char, et classe descendante  }
{ vers un de ses ancetres (polymorphisme).                       }
{ ------------------------------------------------------------ }

Function TypeIsAssignCompatible(FromIdx, ToIdx: Integer): Boolean;
Var
 RF, RT, C : Integer;
Begin
 RF := TypeResolve(FromIdx);
 RT := TypeResolve(ToIdx);

 If (RF < 0) Or (RF >= TypeCount) Or (RT < 0) Or (RT >= TypeCount) Then
 Begin TypeIsAssignCompatible := True; Exit; End;   { types inconnus : ne pas bloquer }

 If RF = RT Then Begin TypeIsAssignCompatible := True; Exit; End;

 If TypeTab[RF].Kind = TYK_NIL Then
 Begin
  TypeIsAssignCompatible := TypeIsPointer(RT) Or TypeIsClass(RT) Or
   TypeIsInterface(RT) Or (TypeTab[RT].Kind = TYK_PROCTYPE);
  Exit;
 End;

 If TypeIsOrdinal(RF) And TypeIsOrdinal(RT) Then
 Begin TypeIsAssignCompatible := True; Exit; End;

 If TypeIsNumeric(RF) And TypeIsReal(RT) Then
 Begin TypeIsAssignCompatible := True; Exit; End;

 If TypeIsReal(RF) And TypeIsReal(RT) Then
 Begin TypeIsAssignCompatible := True; Exit; End;

 If (TypeTab[RF].Kind In [TYK_STRING, TYK_CHAR]) And
    (TypeTab[RT].Kind = TYK_STRING) Then
 Begin TypeIsAssignCompatible := True; Exit; End;

 { Classe descendante -> reference a un de ses ancetres }
 If (TypeTab[RF].Kind = TYK_CLASS) And (TypeTab[RT].Kind = TYK_CLASS) Then
 Begin
  C := RF;
  While C >= 0 Do
  Begin
   If C = RT Then
   Begin TypeIsAssignCompatible := True; Exit; End;
   C := TypeTab[C].BaseTypeIdx;
  End;
  TypeIsAssignCompatible := False;
  Exit;
 End;

 If TypeIsPointer(RF) And TypeIsPointer(RT) Then
 Begin TypeIsAssignCompatible := True; Exit; End;

 TypeIsAssignCompatible := False;
End;

{ ------------------------------------------------------------ }
{ TypeIsCastCompatible : compatibilite pour un typecast EXPLICITE}
{ (plus permissif qu une affectation implicite) : ordinal<->    }
{ ordinal, reel<->reel, pointeur<->pointeur, classe<->classe,    }
{ interface<->interface, et ordinal<->pointeur de meme taille.  }
{ ------------------------------------------------------------ }

Function TypeIsCastCompatible(FromIdx, ToIdx: Integer): Boolean;
Var RF, RT: Integer;
Begin
 RF := TypeResolve(FromIdx);
 RT := TypeResolve(ToIdx);

 If (RF < 0) Or (RF >= TypeCount) Or (RT < 0) Or (RT >= TypeCount) Then
 Begin TypeIsCastCompatible := True; Exit; End;

 If RF = RT Then Begin TypeIsCastCompatible := True; Exit; End;

 If TypeIsOrdinal(RF) And TypeIsOrdinal(RT) Then
 Begin TypeIsCastCompatible := True; Exit; End;

 If TypeIsReal(RF) And TypeIsReal(RT) Then
 Begin TypeIsCastCompatible := True; Exit; End;

 If TypeIsPointer(RF) And TypeIsPointer(RT) Then
 Begin TypeIsCastCompatible := True; Exit; End;

 If (TypeTab[RF].Kind = TYK_CLASS) And (TypeTab[RT].Kind = TYK_CLASS) Then
 Begin TypeIsCastCompatible := True; Exit; End;

 If (TypeTab[RF].Kind = TYK_INTERFACE) And
    (TypeTab[RT].Kind = TYK_INTERFACE) Then
 Begin TypeIsCastCompatible := True; Exit; End;

 If (TypeIsOrdinal(RF) And TypeIsPointer(RT)) Or
    (TypeIsPointer(RF) And TypeIsOrdinal(RT)) Then
 Begin TypeIsCastCompatible := (TypeTab[RF].Size = TypeTab[RT].Size); Exit; End;

 TypeIsCastCompatible := False;
End;

{ ------------------------------------------------------------ }
{ TypeAssert / TypeSelfTest : verifient la table des types avec }
{ des cas connus (tailles primitives, alias, promotion, types   }
{ composes construits incrementalement, classes/heritage lies a }
{ SymTab). Execute a chaque lancement, comme ConstEvalSelfTest   }
{ et SymSelfTest, pour garantir que cette brique reste correcte  }
{ au fil des futurs TODOs qui s appuieront dessus.               }
{ ------------------------------------------------------------ }

Procedure TypeAssert(Const Label_: TString; Cond: Boolean);
Begin
 If Not Cond Then
  FatalError('TypeSelfTest: ' + Label_ + ' a echoue');
End;

Procedure TypeSelfTest;
Var
 IntIdx, LongIntIdx, WordIdx, CharIdx, StrIdx, DoubleIdx : Integer;
 PtrToInt, PtrToInt2, ArrIdx, DynArrIdx, SetIdx           : Integer;
 EnumIdx, V0, V1, V2                                      : Integer;
 RecIdx, F1, F2                                           : Integer;
 TObjIdx, ExcIdx, ButtonIdx                                : Integer;
Begin
 SymInit;   { appelle TypeInit et reconstruit les symboles predefinis }

 { Tailles et alias primitifs (coherents avec DelphiTypeSizeof) }
 IntIdx     := TypeFindByName('Integer');
 LongIntIdx := TypeFindByName('LongInt');
 WordIdx    := TypeFindByName('Word');
 CharIdx    := TypeFindByName('Char');
 StrIdx     := TypeFindByName('String');
 DoubleIdx  := TypeFindByName('Double');
 TypeAssert('Integer trouve', IntIdx >= 0);
 TypeAssert('SizeOf(Integer) = 4', TypeSizeofIdx(IntIdx) = 4);
 TypeAssert('SizeOf(Word) = 2', TypeSizeofIdx(WordIdx) = 2);
 TypeAssert('Word est non signe', TypeTab[WordIdx].IsUnsigned);
 TypeAssert('Integer est signe', Not TypeTab[IntIdx].IsUnsigned);
 TypeAssert('Integer est ordinal', TypeIsOrdinal(IntIdx));
 TypeAssert('Double est reel', TypeIsReal(DoubleIdx));
 TypeAssert('String est une chaine', TypeIsString(StrIdx));
 TypeAssert('Char n est pas un pointeur', Not TypeIsPointer(CharIdx));

 { TypeCoerce : promotion Integer/Double, Integer/Word }
 TypeAssert('TypeCoerce(Integer,Double) = Double',
  TypeCoerce(IntIdx, DoubleIdx) = DoubleIdx);
 TypeAssert('TypeCoerce(Integer,Word) = Integer (4 octets > 2)',
  TypeTab[TypeCoerce(IntIdx, WordIdx)].Size = 4);

 { Pointeurs : dedoublonnage }
 PtrToInt  := TypeAddPointer(IntIdx);
 PtrToInt2 := TypeAddPointer(IntIdx);
 TypeAssert('TypeAddPointer dedoublonne', PtrToInt = PtrToInt2);
 TypeAssert('^Integer est un pointeur', TypeIsPointer(PtrToInt));

 { Tableau statique : ARRAY[1..10] OF Integer -> 40 octets }
 ArrIdx := TypeAddArray(IntIdx, 1, 10, False);
 TypeAssert('ARRAY[1..10] OF Integer = 40 octets',
  TypeTab[ArrIdx].Size = 40);

 { Tableau dynamique : ARRAY OF Integer -> 4 octets (pointeur) }
 DynArrIdx := TypeAddArray(IntIdx, 0, 0, True);
 TypeAssert('ARRAY OF Integer dynamique = 4 octets',
  TypeTab[DynArrIdx].Size = 4);
 TypeAssert('ARRAY OF Integer est marque dynamique',
  TypeTab[DynArrIdx].IsDynArray);

 { Ensemble : SET OF Char }
 SetIdx := TypeAddSet(CharIdx);
 TypeAssert('SET OF Char = MAX_SET_BYTES octets',
  TypeTab[SetIdx].Size = MAX_SET_BYTES);

 { Enumeration incrementale, avec une valeur explicite au milieu }
 EnumIdx := TypeAddEnum('TCOULEUR');
 V0 := TypeAddEnumValue(EnumIdx, 'ROUGE', False, 0);
 V1 := TypeAddEnumValue(EnumIdx, 'VERT', True, 5);
 V2 := TypeAddEnumValue(EnumIdx, 'BLEU', False, 0);
 TypeAssert('3 valeurs dans TCouleur', TypeTab[EnumIdx].EnumCount = 3);
 TypeAssert('Rouge = 0', EnumValPool[V0].Value = 0);
 TypeAssert('Vert = 5 (explicite)', EnumValPool[V1].Value = 5);
 TypeAssert('Bleu = 6 (5 + 1)', EnumValPool[V2].Value = 6);
 TypeAssert('Enum suit la directive $Z (EnumSize)',
  TypeTab[EnumIdx].Size = EnumSize);

 { Record incremental avec alignement : Byte puis Integer }
 RecIdx := TypeAddRecord('TPOINT3');
 F1 := TypeAddField(RecIdx, 'FLAG', TypeFindByName('Byte'));
 F2 := TypeAddField(RecIdx, 'VALEUR', IntIdx);
 TypeAssert('FLAG a l offset 0', FieldPool[F1].Offset = 0);
 TypeAssert('VALEUR aligne sur 4 (apres un Byte)', FieldPool[F2].Offset = 4);
 TypeAssert('Record final = 8 octets (1 pad 3 + 4)',
  TypeTab[RecIdx].Size = 8);

 { Classes/heritage : lies aux symboles crees par SymRegisterBuiltins }
 TObjIdx := SymFind('TObject');
 ExcIdx  := SymFind('Exception');
 TypeAssert('TObject a un TypeIdx valide', SymTab[TObjIdx].TypeIdx >= 0);
 TypeAssert('Le type de TObject est bien TYK_CLASS',
  TypeTab[SymTab[TObjIdx].TypeIdx].Kind = TYK_CLASS);
 TypeAssert('Le type de TObject pointe vers son symbole',
  TypeTab[SymTab[TObjIdx].TypeIdx].ClassSymIdx = TObjIdx);
 TypeAssert('Exception herite de TObject au niveau des types',
  TypeTab[SymTab[ExcIdx].TypeIdx].BaseTypeIdx = SymTab[TObjIdx].TypeIdx);
 TypeAssert('Exception assignable a TObject (polymorphisme)',
  TypeIsAssignCompatible(SymTab[ExcIdx].TypeIdx, SymTab[TObjIdx].TypeIdx));
 TypeAssert('TObject non assignable a Exception (sens interdit)',
  Not TypeIsAssignCompatible(SymTab[TObjIdx].TypeIdx, SymTab[ExcIdx].TypeIdx));

 { Une classe utilisateur descendant d Exception, deux niveaux plus loin }
 ButtonIdx := SymDeclareClass('EBUTTONERROR', SK_CLASS, ExcIdx);
 TypeAssert('EButtonError assignable a TObject (deux niveaux)',
  TypeIsAssignCompatible(SymTab[ButtonIdx].TypeIdx, SymTab[TObjIdx].TypeIdx));

 { Compatibilite d affectation et de typecast de base }
 TypeAssert('Integer -> Double assignable', TypeIsAssignCompatible(IntIdx, DoubleIdx));
 TypeAssert('Double -> Integer non assignable implicitement',
  Not TypeIsAssignCompatible(DoubleIdx, IntIdx));
 TypeAssert('Integer <-> Char castable (ordinaux)',
  TypeIsCastCompatible(IntIdx, CharIdx));
 TypeAssert('LongInt et Integer sont le meme type resolu',
  TypeResolve(LongIntIdx) = TypeResolve(IntIdx));

 SymInit;   { restaurer une table propre (types + symboles) pour la
             vraie compilation }
End;

{ ============================================================ }
{ TODO 07 - EMETTEUR DE CODE ASM 80386                [IMPLEMENTE] }
{ ============================================================ }

Var
 { Compteur de labels internes a l emetteur (_DPL_NNNNN), distinct   }
 { de LabelGenSeq (TODO 04) qui numerote les constantes chaine      }
 { (_DPK_NNNNN) dans le pool de donnees.                            }
 EmitLabelSeq : Integer;

{ ------------------------------------------------------------ }
{ EmitOpen / EmitClose : ouvrir/fermer le fichier .ASM de       }
{ sortie. EmitClose ecrit la directive END <EntryLabel>, point   }
{ d entree du programme pour le lieur.                           }
{ ------------------------------------------------------------ }

Procedure EmitOpen(Const AsmFile: TString);
Begin
 Assign(OutF, AsmFile);
 {$I-}
 Rewrite(OutF);
 {$I+}
 If IOResult <> 0 Then
  FatalError('impossible d''ouvrir le fichier de sortie: ' + AsmFile);
 OutFOpen     := True;
 EmitLabelSeq := 0;
End;

Procedure EmitClose(Const EntryLabel: TString);
Begin
 If OutFOpen Then
 Begin
  WriteLn(OutF, 'END ', EntryLabel);
  Close(OutF);
  OutFOpen := False;
 End;
End;

{ ------------------------------------------------------------ }
{ EmitRaw / EmitLabel / EmitInstr / EmitComment / EmitBlankLine }
{ primitives d ecriture ligne par ligne dans le fichier .ASM.   }
{ ------------------------------------------------------------ }

Procedure EmitRaw(Const S: TString);
Begin
 If OutFOpen Then WriteLn(OutF, S);
End;

Procedure EmitLabel(Const Lbl: TString);
Begin
 If OutFOpen Then WriteLn(OutF, Lbl, ':');
End;

Procedure EmitInstr(Const S: TString);
Begin
 If OutFOpen Then WriteLn(OutF, '        ', S);
End;

Procedure EmitComment(Const S: TString);
Begin
 If OutFOpen Then WriteLn(OutF, '; ', S);
End;

Procedure EmitBlankLine;
Begin
 If OutFOpen Then WriteLn(OutF);
End;

{ ------------------------------------------------------------ }
{ LabelGen : generer un label interne unique _DPL_NNNNN, pour   }
{ les branchements (If/While/For, TODO 13) et autres besoins    }
{ du generateur de code.                                        }
{ ------------------------------------------------------------ }

Function LabelGen: TString;
Begin
 Inc(EmitLabelSeq);
 LabelGen := DP_LBL_PFX + IntToStr_(EmitLabelSeq);
End;

{ ------------------------------------------------------------ }
{ EmitHeader : en-tete ASM pour un programme Win32 80386 :       }
{ .386 / .MODEL FLAT, STDCALL, et les imports Win32 de base      }
{ (kernel32.dll) toujours necessaires quel que soit le programme.}
{ Les unites simulees (CRT/SysUtils/System, TODO 12/18/19/20/22) }
{ ajouteront leurs propres imports au fil de leur implementation.}
{ ------------------------------------------------------------ }

Procedure EmitHeader;
Begin
 EmitComment('DELPHI - Compilateur Delphi -> ASM 80386 Win32');
 EmitComment('Genere automatiquement a partir de : ' + Opts.SrcFile);
 EmitBlankLine;

 EmitRaw('.386');
 EmitRaw('.MODEL FLAT, STDCALL');
 EmitBlankLine;

 EmitComment('--- Imports Win32 de base (kernel32.dll) ---');
 EmitRaw('EXTRN _ExitProcess@4:NEAR');
 EmitRaw('EXTRN _GetStdHandle@4:NEAR');
 EmitRaw('EXTRN _WriteFile@20:NEAR');
 EmitRaw('EXTRN _ReadFile@20:NEAR');
 EmitRaw('EXTRN _GetProcessHeap@0:NEAR');
 EmitRaw('EXTRN _HeapAlloc@12:NEAR');
 EmitRaw('EXTRN _HeapFree@12:NEAR');
 EmitRaw('EXTRN _CloseHandle@4:NEAR');
 EmitBlankLine;
End;

{ Implementees au TODO 12 (variables/buffers et routines de la   }
{ RTL minimale : handles console, buffers de conversion, chaines }
{ TRUE/FALSE, Write/IntToStr/Trim...) mais appelees ici :          }
{ EmitDataSeg/EmitSkeletonProgram doivent les inclure avant les    }
{ donnees/code utilisateur, comme le fait TPCW32 pour les siennes.}
Procedure EmitRuntimeData; Forward;
Procedure EmitRuntimeLibrary; Forward;

{ Implementee au TODO 14 (imports EXTRN d une DLL declaree par une }
{ procedure/fonction 'external' du code source) mais appelee ici,   }
{ juste apres les imports Win32 de base.                             }
Procedure EmitUserExterns; Forward;

{ ------------------------------------------------------------ }
{ EmitDataSeg : emettre le segment .DATA avec toutes les        }
{ entrees du pool de donnees (TODO 04/08) : chaines regroupees   }
{ en litteraux imprimables coupes aux caracteres non-imprimables,}
{ valeurs immediates, tableaux et blocs reserves/zero.           }
{ ------------------------------------------------------------ }

Procedure EmitDataSeg;
Var
 I, J : Integer;
 S    : TString;
 C    : Char;
Begin
 EmitComment('--- Segment de donnees ---');
 EmitRaw('.DATA');
 EmitBlankLine;

 EmitRuntimeData;

 If DataCount > 0 Then
 Begin
  EmitComment('--- Constantes et donnees utilisateur ---');
  For I := 0 To DataCount - 1 Do
  Begin
   Case DataTab[I].Kind Of
    DK_STR:
    Begin
     S := '';
     J := 1;
     While J <= Length(DataTab[I].StrVal) Do
     Begin
      C := DataTab[I].StrVal[J];
      If (Ord(C) >= 32) And (Ord(C) < 127) And (C <> '''') Then
      Begin
       If S <> '' Then S := S + ',';
       S := S + '''';
       While J <= Length(DataTab[I].StrVal) Do
       Begin
        C := DataTab[I].StrVal[J];
        If (Ord(C) >= 32) And (Ord(C) < 127) And (C <> '''') Then
        Begin
         S := S + C;
         Inc(J);
        End
        Else Break;
       End;
       S := S + '''';
      End
      Else
      Begin
       If S <> '' Then S := S + ',';
       S := S + IntToStr_(Ord(C));
       Inc(J);
      End;
     End;
     If S = '' Then S := '0' Else S := S + ',0';
     EmitRaw(DataTab[I].LblName + '  DB ' + S);
    End;

    DK_DWORD:
     EmitRaw(DataTab[I].LblName + '  DD ' + IntToStr_(DataTab[I].IntVal));

    DK_BYTE:
     EmitRaw(DataTab[I].LblName + '  DB ' + IntToStr_(DataTab[I].IntVal));

    DK_ARRAY:
     If DataTab[I].ElemSize = 1 Then
      EmitRaw(DataTab[I].LblName + '  DB ' +
       IntToStr_(DataTab[I].ElemCount) + ' DUP(0)')
     Else
      EmitRaw(DataTab[I].LblName + '  DB ' +
       IntToStr_(DataTab[I].ElemCount * DataTab[I].ElemSize) + ' DUP(0)');

    DK_RES, DK_STRUCT, DK_ZERO:
     If DataTab[I].IntVal > 0 Then
      EmitRaw(DataTab[I].LblName + '  DB ' +
       IntToStr_(DataTab[I].IntVal) + ' DUP(0)')
     Else
      EmitRaw(DataTab[I].LblName + '  DD 0');
   End;
  End;
  EmitBlankLine;
 End;
End;

{ ------------------------------------------------------------ }
{ EmitCodeSeg : debut du segment .CODE                          }
{ ------------------------------------------------------------ }

Procedure EmitCodeSeg;
Begin
 EmitComment('--- Segment de code ---');
 EmitRaw('.CODE');
 EmitBlankLine;
End;

{ ------------------------------------------------------------ }
{ EmitProlog / EmitEpilog : prologue/epilogue standard d une    }
{ procedure/fonction/methode (convention EBP, voir TODO 09/14). }
{ ------------------------------------------------------------ }

Procedure EmitProlog(LocalSize: Integer);
Begin
 EmitInstr('PUSH EBP');
 EmitInstr('MOV EBP,ESP');
 If LocalSize > 0 Then
  EmitInstr('SUB ESP,' + IntToStr_(LocalSize));
End;

Procedure EmitEpilog;
Begin
 EmitInstr('MOV ESP,EBP');
 EmitInstr('POP EBP');
 EmitInstr('RET');
End;

{ ------------------------------------------------------------ }
{ EmitSkeletonProgram : assemble les briques ci-dessus en un    }
{ fichier .ASM complet et assemblable. Le corps reel du         }
{ programme (instructions issues du source Pascal) sera genere  }
{ par les TODO 13 et suivants ; pour l instant, le point d       }
{ entree se contente d arreter le processus proprement, ce qui   }
{ permet de deja produire, tester et assembler un squelette      }
{ valide (avec les vraies chaines litterales du source dans      }
{ .DATA) via le parametre -asm.                                  }
{ ------------------------------------------------------------ }

Procedure EmitSkeletonProgram(Const AsmFile: TString);
Var EntryLabel: TString;
Begin
 EntryLabel := DP_FUNC_PFX + 'MAIN';

 EmitOpen(AsmFile);
 EmitHeader;
 EmitUserExterns;
 EmitDataSeg;
 EmitCodeSeg;
 EmitRuntimeLibrary;
 EmitLabel(EntryLabel);
 EmitProlog(0);
 EmitInstr('CALL ' + DPRT_INIT);
 EmitComment('Corps du programme : voir TODO 23 et suivants');
 EmitComment('(analyseur syntaxique non encore implemente).');
 EmitInstr('PUSH 0');
 EmitInstr('CALL ExitProcess');
 EmitEpilog;
 EmitClose(EntryLabel);
End;

{ ------------------------------------------------------------ }
{ EmitAssert / EmitSelfTest : verifient l emetteur en generant  }
{ un squelette dans un fichier temporaire puis en relisant son   }
{ contenu, comme ConstEvalSelfTest/SymSelfTest/TypeSelfTest      }
{ verifient les briques precedentes. Le fichier temporaire est   }
{ supprime a la fin, qu il ait reussi ou echoue.                 }
{ ------------------------------------------------------------ }

Procedure EmitAssert(Const Label_: TString; Cond: Boolean);
Begin
 If Not Cond Then
  FatalError('EmitSelfTest: ' + Label_ + ' a echoue');
End;

Procedure EmitSelfTest;
Const
 TmpFile = 'DPEMITSELFTEST.$$$';
Var
 F        : Text;
 Line     : TString;
 Has386, HasModel, HasExtrn, HasData, HasCode, HasStr,
 HasEntry, HasProlog, HasCallExit, HasEpilog, HasEnd : Boolean;
Begin
 DataInit;
 DataAddStr('Bonjour');

 EmitSkeletonProgram(TmpFile);

 { On teste chaque ligne separement plutot que de tout concatener dans }
 { une seule TString : sous la directive H-, TString = ShortString    }
 { (255 octets max), et un .asm complet depasse largement cette limite}
 Has386      := False; HasModel  := False; HasExtrn := False;
 HasData     := False; HasCode   := False; HasStr   := False;
 HasEntry    := False; HasProlog := False; HasCallExit := False;
 HasEpilog   := False; HasEnd    := False;

 {$I-}
 Assign(F, TmpFile);
 Reset(F);
 {$I+}
 EmitAssert('fichier .asm relisible', IOResult = 0);

 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('.386', Line) > 0 Then Has386 := True;
  If Pos('.MODEL FLAT, STDCALL', Line) > 0 Then HasModel := True;
  If Pos('EXTRN _ExitProcess@4:NEAR', Line) > 0 Then HasExtrn := True;
  If Line = '.DATA' Then HasData := True;
  If Line = '.CODE' Then HasCode := True;
  If Pos('''Bonjour''', Line) > 0 Then HasStr := True;
  If Line = '_DPF_MAIN:' Then HasEntry := True;
  If Pos('PUSH EBP', Line) > 0 Then HasProlog := True;
  If Pos('CALL ExitProcess', Line) > 0 Then HasCallExit := True;
  If Pos('POP EBP', Line) > 0 Then HasEpilog := True;
  If Pos('END _DPF_MAIN', Line) > 0 Then HasEnd := True;
 End;
 Close(F);
 Erase(F);

 EmitAssert('.386 present', Has386);
 EmitAssert('.MODEL FLAT, STDCALL present', HasModel);
 EmitAssert('EXTRN ExitProcess present', HasExtrn);
 EmitAssert('.DATA present', HasData);
 EmitAssert('.CODE present', HasCode);
 EmitAssert('chaine litterale emise dans .DATA', HasStr);
 EmitAssert('label d entree present', HasEntry);
 EmitAssert('prologue present', HasProlog);
 EmitAssert('appel ExitProcess present', HasCallExit);
 EmitAssert('epilogue present', HasEpilog);
 EmitAssert('directive END presente', HasEnd);

 { LabelGen : unicite et prefixe }
 EmitAssert('LabelGen prefixe _DPL_', Pos(DP_LBL_PFX, LabelGen) = 1);
 EmitAssert('LabelGen genere des noms distincts', LabelGen <> LabelGen);

 DataInit;   { restaurer un pool de donnees propre pour la vraie compilation }
End;

{ ============================================================ }
{ TODO 08 - SEGMENT DE DONNEES, VMT ET TABLES D INTERFACE [IMPLEMENTE] }
{ ============================================================ }

Const
 MAX_VMT_POOL   = {$IFDEF FPC}2048{$ELSE}256{$ENDIF};  { entrees VMT de
                    toutes les classes confondues                   }
 MAX_IFACE_IMPL = {$IFDEF FPC}256{$ELSE}64{$ENDIF};     { implementations
                    d interface (classe, interface) confondues       }
 MAX_THUNK_POOL = {$IFDEF FPC}1024{$ELSE}256{$ENDIF};   { thunks de
                    toutes les implementations confondues            }

Type
 { Une entree de VMT : une methode virtuelle a un offset fixe }
 TVMTEntry = Record
  MethodName   : TString;
  MethodSymIdx : Integer;   { symbole SK_METHOD dans SymTab, -1 si    }
                             { pas encore resolu (abstract, TODO 15)  }
  Offset       : Integer;   { offset fixe dans la VMT (multiple de 4)}
 End;

 { Un thunk d interface : fait correspondre une methode d interface  }
 { a l offset VMT reel de la classe qui l implemente.                }
 TThunkRec = Record
  MethodName : TString;
  VMTOffset  : Integer;
 End;

 { Une classe implemente une interface : GUID + plage de thunks }
 TInterfaceImplRec = Record
  ClassTypeIdx     : Integer;
  InterfaceTypeIdx : Integer;
  GUID             : TString;
  ThunkFirst       : Integer;
  ThunkCount       : Integer;
 End;

Var
 { Pool partage des entrees de VMT (voir TTypeRec.VMTFirst/VMTCount,  }
 { TODO 06) }
 VMTEntryPool      : Array[0..MAX_VMT_POOL - 1] Of TVMTEntry;
 VMTEntryPoolCount : Integer;

 { Table des implementations d interface, et pool de thunks partage }
 IfaceImplTab   : Array[0..MAX_IFACE_IMPL - 1] Of TInterfaceImplRec;
 IfaceImplCount : Integer;
 ThunkPool      : Array[0..MAX_THUNK_POOL - 1] Of TThunkRec;
 ThunkPoolCount : Integer;

 { Compteur pour generer des labels de variables statiques uniques   }
 { (variables locales statiques, TODO 09/14)                         }
 StaticVarSeq : Integer;

{ ------------------------------------------------------------ }
{ DataInit2 : (re)initialiser les pools de TODO 08, en          }
{ complement de DataInit (TODO 04). Appele depuis DataSelfTest  }
{ pour repartir d un etat propre a chaque verification.          }
{ ------------------------------------------------------------ }

Procedure DataInit2;
Begin
 VMTEntryPoolCount := 0;
 IfaceImplCount     := 0;
 ThunkPoolCount      := 0;
 StaticVarSeq        := 0;
End;

{ ------------------------------------------------------------ }
{ DataAddGlobalVar : creer dans le pool de donnees l espace     }
{ reserve pour une variable globale (label _DPV_nom, coherent   }
{ avec SymMangle). TypeIdx vient de la table des types (TODO06).}
{ ------------------------------------------------------------ }

Function DataAddGlobalVar(Const Name: TString; TypeIdx: Integer;
 InitVal: LongInt): Integer;
Var
 Lbl : TString;
 Sz  : Integer;
Begin
 Lbl := DP_VAR_PFX + StrUpperCase(Name);
 Sz  := TypeSizeofIdx(TypeIdx);

 If TypeIsString(TypeIdx) Then
  DataAddGlobalVar := DataAdd(Lbl, DK_ARRAY, 0, '', Sz, 1)
 Else If Sz = 1 Then
  DataAddGlobalVar := DataAdd(Lbl, DK_BYTE, InitVal, '', 0, 0)
 Else If Sz <= 4 Then
  DataAddGlobalVar := DataAdd(Lbl, DK_DWORD, InitVal, '', 0, 0)
 Else
  DataAddGlobalVar := DataAdd(Lbl, DK_RES, Sz, '', 0, 0);
End;

{ ------------------------------------------------------------ }
{ DataAddTypedConst : creer dans le pool de donnees l espace    }
{ pour une constante typee (CONST X: Integer = 42), avec sa     }
{ valeur initiale (InitVal pour les ordinaux/pointeurs, InitStr  }
{ pour les chaines).                                             }
{ ------------------------------------------------------------ }

Function DataAddTypedConst(Const Name: TString; TypeIdx: Integer;
 InitVal: LongInt; Const InitStr: TString): Integer;
Var
 Lbl : TString;
 Sz  : Integer;
Begin
 Lbl := DP_VAR_PFX + StrUpperCase(Name);
 Sz  := TypeSizeofIdx(TypeIdx);

 If TypeIsString(TypeIdx) Then
 Begin
  If InitStr <> '' Then
   DataAddTypedConst := DataAdd(Lbl, DK_STR, 0, InitStr, 0, 0)
  Else
   DataAddTypedConst := DataAdd(Lbl, DK_ARRAY, 0, '', Sz, 1);
  Exit;
 End;

 If Sz = 1 Then
  DataAddTypedConst := DataAdd(Lbl, DK_BYTE, InitVal, '', 0, 0)
 Else If Sz <= 4 Then
  DataAddTypedConst := DataAdd(Lbl, DK_DWORD, InitVal, '', 0, 0)
 Else
  DataAddTypedConst := DataAdd(Lbl, DK_RES, Sz, '', 0, 0);
End;

{ ------------------------------------------------------------ }
{ DataAddStaticVar : creer une variable statique avec un label  }
{ unique _DPV_STATIC_N (variable locale conservant sa valeur    }
{ entre deux appels, TODO 09/14). Retourne le label genere.      }
{ ------------------------------------------------------------ }

Function DataAddStaticVar(TypeIdx: Integer; InitVal: LongInt): TString;
Var
 Lbl : TString;
 Sz  : Integer;
Begin
 Inc(StaticVarSeq);
 Lbl := DP_VAR_PFX + 'STATIC_' + IntToStr_(StaticVarSeq);
 Sz  := TypeSizeofIdx(TypeIdx);

 If TypeIsString(TypeIdx) Then
  DataAdd(Lbl, DK_ARRAY, 0, '', Sz, 1)
 Else If Sz = 1 Then
  DataAdd(Lbl, DK_BYTE, InitVal, '', 0, 0)
 Else If Sz <= 4 Then
  DataAdd(Lbl, DK_DWORD, InitVal, '', 0, 0)
 Else
  DataAdd(Lbl, DK_RES, Sz, '', 0, 0);

 DataAddStaticVar := Lbl;
End;

{ ------------------------------------------------------------ }
{ VMTInit : demarrer la VMT d une classe nouvellement creee (a   }
{ appeler une fois par TypeAddClass, TODO 15) en copiant celle   }
{ de son ancetre (memes offsets herites, condition necessaire au }
{ polymorphisme : un appel virtuel par offset doit fonctionner   }
{ identiquement pour la classe de base et ses descendants).      }
{ ------------------------------------------------------------ }

Procedure VMTInit(ClassTypeIdx: Integer);
Var
 ParentIdx, I : Integer;
Begin
 If (ClassTypeIdx < 0) Or (ClassTypeIdx >= TypeCount) Then Exit;

 TypeTab[ClassTypeIdx].VMTFirst := VMTEntryPoolCount;
 TypeTab[ClassTypeIdx].VMTCount := 0;

 ParentIdx := TypeTab[ClassTypeIdx].BaseTypeIdx;
 If (ParentIdx >= 0) And (TypeTab[ParentIdx].VMTFirst >= 0) Then
  For I := TypeTab[ParentIdx].VMTFirst To
   TypeTab[ParentIdx].VMTFirst + TypeTab[ParentIdx].VMTCount - 1 Do
  Begin
   If VMTEntryPoolCount >= MAX_VMT_POOL Then
   Begin
    WarnMsg('table des VMT pleine (MAX_VMT_POOL=' +
     IntToStr_(MAX_VMT_POOL) + ')');
    Exit;
   End;
   VMTEntryPool[VMTEntryPoolCount] := VMTEntryPool[I];
   Inc(VMTEntryPoolCount);
   Inc(TypeTab[ClassTypeIdx].VMTCount);
  End;
End;

{ ------------------------------------------------------------ }
{ VMTFindMethod : chercher une methode dans la VMT d une classe  }
{ (deja etendue par VMTInit avec les entrees heritees). Retourne }
{ son offset, ou -1 si cette methode n est pas virtuelle.        }
{ ------------------------------------------------------------ }

Function VMTFindMethod(ClassTypeIdx: Integer; Const MethodName: TString): Integer;
Var
 Up : TString;
 I  : Integer;
Begin
 VMTFindMethod := -1;
 If (ClassTypeIdx < 0) Or (ClassTypeIdx >= TypeCount) Or
    (TypeTab[ClassTypeIdx].VMTFirst < 0) Then Exit;
 Up := StrUpperCase(MethodName);
 For I := TypeTab[ClassTypeIdx].VMTFirst To
  TypeTab[ClassTypeIdx].VMTFirst + TypeTab[ClassTypeIdx].VMTCount - 1 Do
  If VMTEntryPool[I].MethodName = Up Then
  Begin
   VMTFindMethod := VMTEntryPool[I].Offset;
   Exit;
  End;
End;

{ ------------------------------------------------------------ }
{ VMTAddMethod : declarer une methode virtuelle sur une classe   }
{ deja initialisee par VMTInit. Si une methode du meme nom est   }
{ heritee, elle est remplacee (override) EN CONSERVANT SON       }
{ OFFSET ; sinon un nouveau slot est ajoute a la fin. Retourne   }
{ l offset (multiple de 4).                                      }
{ ------------------------------------------------------------ }

Function VMTAddMethod(ClassTypeIdx: Integer; Const MethodName: TString;
 MethodSymIdx: Integer): Integer;
Var
 First, Cnt, I : Integer;
 UpName : TString;
Begin
 UpName := StrUpperCase(MethodName);
 First  := TypeTab[ClassTypeIdx].VMTFirst;
 Cnt    := TypeTab[ClassTypeIdx].VMTCount;

 For I := First To First + Cnt - 1 Do
  If VMTEntryPool[I].MethodName = UpName Then
  Begin
   VMTEntryPool[I].MethodSymIdx := MethodSymIdx;
   VMTAddMethod := VMTEntryPool[I].Offset;
   Exit;
  End;

 If VMTEntryPoolCount >= MAX_VMT_POOL Then
 Begin
  WarnMsg('table des VMT pleine (MAX_VMT_POOL=' + IntToStr_(MAX_VMT_POOL) + ')');
  VMTAddMethod := -1;
  Exit;
 End;

 If TypeTab[ClassTypeIdx].VMTFirst < 0 Then
  TypeTab[ClassTypeIdx].VMTFirst := VMTEntryPoolCount;

 VMTEntryPool[VMTEntryPoolCount].MethodName   := UpName;
 VMTEntryPool[VMTEntryPoolCount].MethodSymIdx := MethodSymIdx;
 VMTEntryPool[VMTEntryPoolCount].Offset       := Cnt * 4;
 VMTAddMethod := Cnt * 4;
 Inc(VMTEntryPoolCount);
 Inc(TypeTab[ClassTypeIdx].VMTCount);
End;

{ ------------------------------------------------------------ }
{ IfaceImplAdd / IfaceImplAddThunk / IfaceImplFind : table des   }
{ interfaces implementees par une classe (TODO 17). Chaque      }
{ implementation associe un GUID et une plage de thunks (une     }
{ methode d interface -> l offset VMT reel de la classe qui      }
{ fournit son implementation).                                   }
{ ------------------------------------------------------------ }

Function IfaceImplAdd(ClassTypeIdx, InterfaceTypeIdx: Integer;
 Const GUID: TString): Integer;
Begin
 If IfaceImplCount >= MAX_IFACE_IMPL Then
 Begin
  WarnMsg('table des interfaces pleine (MAX_IFACE_IMPL=' +
   IntToStr_(MAX_IFACE_IMPL) + ')');
  IfaceImplAdd := -1;
  Exit;
 End;

 IfaceImplTab[IfaceImplCount].ClassTypeIdx     := ClassTypeIdx;
 IfaceImplTab[IfaceImplCount].InterfaceTypeIdx := InterfaceTypeIdx;
 IfaceImplTab[IfaceImplCount].GUID             := GUID;
 IfaceImplTab[IfaceImplCount].ThunkFirst       := ThunkPoolCount;
 IfaceImplTab[IfaceImplCount].ThunkCount       := 0;

 IfaceImplAdd := IfaceImplCount;
 Inc(IfaceImplCount);
End;

Function IfaceImplAddThunk(ImplIdx: Integer; Const MethodName: TString;
 VMTOffset: Integer): Integer;
Begin
 If (ImplIdx < 0) Or (ImplIdx >= IfaceImplCount) Or
    (ThunkPoolCount >= MAX_THUNK_POOL) Then
 Begin
  IfaceImplAddThunk := -1;
  Exit;
 End;

 ThunkPool[ThunkPoolCount].MethodName := StrUpperCase(MethodName);
 ThunkPool[ThunkPoolCount].VMTOffset  := VMTOffset;
 IfaceImplAddThunk := ThunkPoolCount;
 Inc(ThunkPoolCount);
 Inc(IfaceImplTab[ImplIdx].ThunkCount);
End;

Function IfaceImplFind(ClassTypeIdx, InterfaceTypeIdx: Integer): Integer;
Var I: Integer;
Begin
 IfaceImplFind := -1;
 For I := 0 To IfaceImplCount - 1 Do
  If (IfaceImplTab[I].ClassTypeIdx = ClassTypeIdx) And
     (IfaceImplTab[I].InterfaceTypeIdx = InterfaceTypeIdx) Then
  Begin
   IfaceImplFind := I;
   Exit;
  End;
End;

{ ------------------------------------------------------------ }
{ DataAssert / DataSelfTest : verifient les briques de TODO 08   }
{ (variables/constantes globales, VMT avec heritage et override, }
{ table d interfaces) avec des cas connus, comme les self-tests  }
{ des TODO precedents. Construit sa propre mini-hierarchie de    }
{ classes (TANIMAL/TCHIEN) plutot que d utiliser TObject/         }
{ Exception, pour ne pas dependre de leurs methodes predefinies. }
{ ------------------------------------------------------------ }

Procedure DataAssert(Const Label_: TString; Cond: Boolean);
Begin
 If Not Cond Then
  FatalError('DataSelfTest: ' + Label_ + ' a echoue');
End;

Procedure DataSelfTest;
Var
 IntIdx, ByteIdx, StrIdx, DoubleIdx      : Integer;
 GVar, TConst, TConstStr                 : Integer;
 Lbl1, Lbl2                              : TString;
 AnimalIdx, ChienIdx                     : Integer;
 AnimalSymIdx, ChienSymIdx               : Integer;
 OffSpeak, OffSpeak2, OffFetch           : Integer;
 IfaceIdx, ImplIdx                       : Integer;
Begin
 SymInit;      { types + symboles predefinis propres }
 DataInit;     { pool de donnees propre (TODO 04) }
 DataInit2;    { pools de TODO 08 propres }

 IntIdx    := TypeFindByName('Integer');
 ByteIdx   := TypeFindByName('Byte');
 StrIdx    := TypeFindByName('String');
 DoubleIdx := TypeFindByName('Double');

 { --- Variables et constantes globales --- }
 GVar := DataAddGlobalVar('Compteur', IntIdx, 0);
 DataAssert('variable globale Integer -> DD', DataTab[GVar].Kind = DK_DWORD);
 DataAssert('label _DPV_ pour variable globale',
  Pos(DP_VAR_PFX, DataTab[GVar].LblName) = 1);

 GVar := DataAddGlobalVar('Flag', ByteIdx, 1);
 DataAssert('variable globale Byte -> DB', DataTab[GVar].Kind = DK_BYTE);

 GVar := DataAddGlobalVar('Nom', StrIdx, 0);
 DataAssert('variable globale String -> reservation tableau',
  DataTab[GVar].Kind = DK_ARRAY);

 GVar := DataAddGlobalVar('Prix', DoubleIdx, 0);
 DataAssert('variable globale Double (8 octets) -> bloc reserve',
  (DataTab[GVar].Kind = DK_RES) And (DataTab[GVar].IntVal = 8));

 TConst := DataAddTypedConst('Reponse', IntIdx, 42, '');
 DataAssert('constante typee Integer conserve sa valeur',
  DataTab[TConst].IntVal = 42);

 TConstStr := DataAddTypedConst('Salutation', StrIdx, 0, 'Salut');
 DataAssert('constante typee chaine conserve son contenu',
  DataTab[TConstStr].StrVal = 'Salut');

 Lbl1 := DataAddStaticVar(IntIdx, 7);
 Lbl2 := DataAddStaticVar(IntIdx, 8);
 DataAssert('DataAddStaticVar genere des labels distincts', Lbl1 <> Lbl2);

 { --- VMT : heritage et override --- }
 AnimalSymIdx := SymDeclareClass('TANIMAL', SK_CLASS, -1);
 AnimalIdx    := SymTab[AnimalSymIdx].TypeIdx;
 VMTInit(AnimalIdx);
 OffSpeak := VMTAddMethod(AnimalIdx, 'PARLER', -1);
 DataAssert('premiere methode virtuelle a l offset 0', OffSpeak = 0);
 DataAssert('TAnimal a 1 entree de VMT', TypeTab[AnimalIdx].VMTCount = 1);

 ChienSymIdx := SymDeclareClass('TCHIEN', SK_CLASS, AnimalSymIdx);
 ChienIdx    := SymTab[ChienSymIdx].TypeIdx;
 VMTInit(ChienIdx);
 DataAssert('TChien herite de la VMT de TAnimal (1 entree)',
  TypeTab[ChienIdx].VMTCount = 1);

 OffSpeak2 := VMTAddMethod(ChienIdx, 'PARLER', -1);
 DataAssert('override : le meme offset est conserve', OffSpeak2 = OffSpeak);
 DataAssert('override : pas de nouvelle entree', TypeTab[ChienIdx].VMTCount = 1);

 OffFetch := VMTAddMethod(ChienIdx, 'RAPPORTER', -1);
 DataAssert('nouvelle methode virtuelle a l offset 4', OffFetch = 4);
 DataAssert('TChien a maintenant 2 entrees de VMT',
  TypeTab[ChienIdx].VMTCount = 2);
 DataAssert('TAnimal n est pas affecte par l ajout sur TChien',
  TypeTab[AnimalIdx].VMTCount = 1);
 DataAssert('VMTFindMethod retrouve Parler sur TChien',
  VMTFindMethod(ChienIdx, 'Parler') = OffSpeak);
 DataAssert('VMTFindMethod retrouve Rapporter sur TChien',
  VMTFindMethod(ChienIdx, 'Rapporter') = OffFetch);
 DataAssert('VMTFindMethod : Rapporter absent de TAnimal',
  VMTFindMethod(AnimalIdx, 'Rapporter') = -1);

 { --- Table d interfaces --- }
 IfaceIdx := TypeAddInterface('IPARLANT', -1, -1);
 ImplIdx  := IfaceImplAdd(ChienIdx, IfaceIdx, '{00000000-0000-0000-0000-000000000001}');
 DataAssert('implementation d interface ajoutee', ImplIdx >= 0);
 IfaceImplAddThunk(ImplIdx, 'PARLER', OffSpeak);
 DataAssert('thunk enregistre pour l implementation',
  IfaceImplTab[ImplIdx].ThunkCount = 1);
 DataAssert('IfaceImplFind retrouve l implementation',
  IfaceImplFind(ChienIdx, IfaceIdx) = ImplIdx);
 DataAssert('IfaceImplFind : TAnimal n implemente pas IParlant',
  IfaceImplFind(AnimalIdx, IfaceIdx) = -1);

 SymInit;      { restaurer un etat propre pour la vraie compilation }
 DataInit;
 DataInit2;
End;

{ ============================================================ }
{ TODO 09 - VARIABLES, AFFECTATIONS ET GESTION MEMOIRE [IMPLEMENTE] }
{ ============================================================ }

Const
 PARAM_BASE_OFS = 8;   { EBP+8 : 1er parametre (apres EBP sauve + adresse
                          de retour). Convention par defaut ici ; le
                          detail des conventions d appel (register,
                          stdcall, cdecl...) est traite au TODO 14. }

 { Runtime (_DPRT_, voir TODO 07) charge du comptage de references.  }
 { Le compilateur emet seulement l appel ; le corps de ces routines  }
 { est fourni par TODO 20 (AnsiString) et TODO 17/18 (interfaces).   }
 DPRT_STR_ASSIGN  = '_DPRT_STRASSIGN';   { StrAssign(NewVal, VAR Dest) }
 DPRT_INTF_ASSIGN = '_DPRT_INTFASSIGN';  { IntfAssign(NewVal, VAR Dest)}

Var
 { Cadre de pile courant (parametres/locales), voir FrameInit }
 CurFrameOffset : Integer;   { prochain offset locale disponible, < 0 }
 CurParamOffset : Integer;   { prochain offset parametre disponible   }

{ ------------------------------------------------------------ }
{ FrameInit : demarrer un nouveau cadre de pile, au debut de la  }
{ compilation du corps d une procedure/fonction/methode          }
{ (TODO 14). Les locales et parametres eux-memes sont ajoutes    }
{ dans la table des symboles (SymAdd), dans la portee ouverte    }
{ par l appelant via SymEnterScope (TODO 05).                    }
{ ------------------------------------------------------------ }

Procedure FrameInit;
Begin
 CurFrameOffset := 0;
 CurParamOffset := PARAM_BASE_OFS;
End;

{ ------------------------------------------------------------ }
{ LocalAdd : declarer une variable locale dans la portee/le      }
{ cadre courants. Retourne l index du symbole (SymTab) avec son  }
{ Offset [EBP-N] deja calcule (aligne sur 4 octets).             }
{ ------------------------------------------------------------ }

Function LocalAdd(Const Name: TString; TypeIdx: Integer): Integer;
Var
 Sz, R : Integer;
Begin
 Sz := TypeSizeofIdx(TypeIdx);
 CurFrameOffset := CurFrameOffset - Sz;
 { arrondir vers le bas (plus negatif) a un multiple de 4 }
 CurFrameOffset := -(((-CurFrameOffset) + 3) Div 4) * 4;

 R := SymAdd(Name, SK_VAR, TypeIdx);
 If R >= 0 Then SymTab[R].Offset := CurFrameOffset;
 LocalAdd := R;
End;

{ ------------------------------------------------------------ }
{ ParamAdd : declarer un parametre (valeur, VAR, CONST ou OUT)   }
{ dans la portee/le cadre courants. Chaque parametre occupe un   }
{ slot de 4 octets (valeur scalaire ou pointeur pour VAR/CONST/  }
{ OUT). Retourne l index du symbole (SymTab).                    }
{ ------------------------------------------------------------ }

Function ParamAdd(Const Name: TString; TypeIdx: Integer;
 Kind: TParamKind): Integer;
Var R: Integer;
Begin
 R := SymAdd(Name, SK_PARAM, TypeIdx);
 If R >= 0 Then
 Begin
  SymTab[R].Offset    := CurParamOffset;
  SymTab[R].ParamKind := Kind;
 End;
 CurParamOffset := CurParamOffset + 4;
 ParamAdd := R;
End;

{ ------------------------------------------------------------ }
{ GlobalVarDeclare : declarer une variable globale a la fois     }
{ dans le pool de donnees (TODO 08, reservation de l espace) et  }
{ dans la table des symboles (TODO 05, resolution par nom). Les  }
{ deux partagent le meme nom mangled (_DPV_nom) par construction.}
{ ------------------------------------------------------------ }

Function GlobalVarDeclare(Const Name: TString; TypeIdx: Integer;
 InitVal: LongInt): Integer;
Begin
 DataAddGlobalVar(Name, TypeIdx, InitVal);
 GlobalVarDeclare := SymAdd(Name, SK_VAR, TypeIdx);
End;

{ ------------------------------------------------------------ }
{ EBPOfs : operande ASM '[EBP+N]' ou '[EBP-N]'                  }
{ ------------------------------------------------------------ }

Function EBPOfs(Ofs: Integer): TString;
Begin
 If Ofs >= 0 Then
  EBPOfs := '[EBP+' + IntToStr_(Ofs) + ']'
 Else
  EBPOfs := '[EBP' + IntToStr_(Ofs) + ']';
End;

{ ------------------------------------------------------------ }
{ SizedPtr : prefixe de taille MASM (BYTE/WORD/DWORD PTR) adapte }
{ a la taille du type, pour qualifier un operande memoire.       }
{ ------------------------------------------------------------ }

Function SizedPtr(TypeIdx: Integer): TString;
Var Sz: Integer;
Begin
 Sz := TypeSizeofIdx(TypeIdx);
 If Sz = 1 Then SizedPtr := 'BYTE PTR '
 Else If Sz = 2 Then SizedPtr := 'WORD PTR '
 Else SizedPtr := 'DWORD PTR ';
End;

{ ------------------------------------------------------------ }
{ GenVarBracket : partie '[...]' (sans prefixe de taille) d une  }
{ reference a un symbole local/parametre/globale, adaptee a la  }
{ portee courante (SymFind, TODO 05). Chaine vide si inconnu.    }
{ Pour un parametre VAR/CONST/OUT, retourne le bracket DE LA     }
{ CASE elle-meme (qui contient un pointeur) - pas de la valeur   }
{ pointee ; c est GenLoadVar/GenVarAddr (TODO 10) qui interpretent}
{ ce pointeur selon le besoin (charger tel quel ou dereferencer).}
{ ------------------------------------------------------------ }

Function GenVarBracket(Const Name: TString): TString;
Var SI: Integer;
Begin
 GenVarBracket := '';
 SI := SymFind(Name);
 If SI < 0 Then Exit;

 If SymTab[SI].Kind = SK_PARAM Then
 Begin
  GenVarBracket := EBPOfs(SymTab[SI].Offset);
  Exit;
 End;

 If SymTab[SI].Kind = SK_VAR Then
 Begin
  If SymTab[SI].IsGlobal Then
   GenVarBracket := '[' + SymTab[SI].MangledName + ']'
  Else
   GenVarBracket := EBPOfs(SymTab[SI].Offset);
 End;
End;

{ ------------------------------------------------------------ }
{ GenVarRef : resoudre un nom en operande ASM complet (avec      }
{ prefixe de taille), en respectant la precedence de portee deja }
{ geree par SymFind (TODO 05). Chaine vide si inconnu (l         }
{ appelant, le futur parseur, signalera alors l erreur).          }
{ ------------------------------------------------------------ }

Function GenVarRef(Const Name: TString): TString;
Var SI: Integer;
Begin
 GenVarRef := '';
 SI := SymFind(Name);
 If SI < 0 Then Exit;

 If (SymTab[SI].Kind = SK_PARAM) And
    (SymTab[SI].ParamKind In [PK_VAR, PK_CONST, PK_OUT]) Then
 Begin
  { la case du cadre contient un pointeur vers la valeur reelle }
  GenVarRef := 'DWORD PTR ' + GenVarBracket(Name);
  Exit;
 End;

 GenVarRef := SizedPtr(SymTab[SI].TypeIdx) + GenVarBracket(Name);
End;

{ ------------------------------------------------------------ }
{ FieldInitInherit : demarrer le layout des champs d une classe  }
{ nouvellement creee (a appeler une fois, avant tout             }
{ TypeAddField sur cette classe) en copiant les champs de son    }
{ ancetre aux memes offsets - miroir de VMTInit (TODO 08) pour   }
{ les VMT, necessaire pour que les champs herites restent a un   }
{ offset stable depuis Self dans toute la hierarchie.             }
{ L offset 0 de toute instance est reserve au pointeur de VMT     }
{ (TODO 15, TypeAddClass/ConstructorAlloc) : une classe racine    }
{ (sans ancetre) demarre donc son InstanceSize a 4, pas 0 ; une   }
{ classe derivee herite simplement l InstanceSize de son parent,  }
{ qui inclut deja cette reservation transitivement.                }
{ ------------------------------------------------------------ }

Procedure FieldInitInherit(ClassTypeIdx: Integer);
Const
 VMT_PTR_SIZE = 4;
Var
 ParentIdx, I : Integer;
Begin
 If (ClassTypeIdx < 0) Or (ClassTypeIdx >= TypeCount) Then Exit;

 TypeTab[ClassTypeIdx].FieldFirst   := FieldPoolCount;
 TypeTab[ClassTypeIdx].FieldCount   := 0;
 TypeTab[ClassTypeIdx].InstanceSize := VMT_PTR_SIZE;

 ParentIdx := TypeTab[ClassTypeIdx].BaseTypeIdx;
 If (ParentIdx >= 0) And (TypeTab[ParentIdx].FieldFirst >= 0) Then
 Begin
  For I := TypeTab[ParentIdx].FieldFirst To
   TypeTab[ParentIdx].FieldFirst + TypeTab[ParentIdx].FieldCount - 1 Do
  Begin
   If FieldPoolCount >= MAX_FIELD_POOL Then Break;
   FieldPool[FieldPoolCount] := FieldPool[I];
   Inc(FieldPoolCount);
   Inc(TypeTab[ClassTypeIdx].FieldCount);
  End;
  TypeTab[ClassTypeIdx].InstanceSize := TypeTab[ParentIdx].InstanceSize;
  If TypeTab[ParentIdx].Align > TypeTab[ClassTypeIdx].Align Then
   TypeTab[ClassTypeIdx].Align := TypeTab[ParentIdx].Align;
 End;
End;

{ ------------------------------------------------------------ }
{ GenFieldRef : operande ASM pour acceder a un champ d instance  }
{ (propre ou herite via FieldInitInherit) a partir d un pointeur }
{ Self deja resolu par l appelant (registre ou reference         }
{ memoire, ex: 'ESI' ou 'EBP-4'). Chaine vide si le champ         }
{ n existe pas dans cette classe.                                 }
{ ------------------------------------------------------------ }

Function GenFieldRef(Const SelfOperand: TString; ClassTypeIdx: Integer;
 Const FieldName: TString): TString;
Var
 Up      : TString;
 I, First, Cnt : Integer;
Begin
 GenFieldRef := '';
 If (ClassTypeIdx < 0) Or (ClassTypeIdx >= TypeCount) Then Exit;
 Up    := StrUpperCase(FieldName);
 First := TypeTab[ClassTypeIdx].FieldFirst;
 Cnt   := TypeTab[ClassTypeIdx].FieldCount;
 If First < 0 Then Exit;

 For I := First To First + Cnt - 1 Do
  If FieldPool[I].Name = Up Then
  Begin
   If FieldPool[I].Offset = 0 Then
    GenFieldRef := SizedPtr(FieldPool[I].TypeIdx) + '[' + SelfOperand + ']'
   Else
    GenFieldRef := SizedPtr(FieldPool[I].TypeIdx) + '[' + SelfOperand +
     '+' + IntToStr_(FieldPool[I].Offset) + ']';
   Exit;
  End;
End;

{ ------------------------------------------------------------ }
{ EmitAssignScalar : affectation d un ordinal/reel/enum/         }
{ subrange : simple MOV, sur 1 ou 4 octets selon la taille.       }
{ ------------------------------------------------------------ }

Procedure EmitAssignScalar(Const DestOperand, SrcOperand: TString;
 SizeBytes: Integer);
Begin
 If SizeBytes = 1 Then
 Begin
  EmitInstr('MOV AL,' + SrcOperand);
  EmitInstr('MOV ' + DestOperand + ',AL');
 End
 Else
 Begin
  EmitInstr('MOV EAX,' + SrcOperand);
  EmitInstr('MOV ' + DestOperand + ',EAX');
 End;
End;

{ ------------------------------------------------------------ }
{ EmitAssignPointer : affectation d une reference d objet        }
{ (classe), d un pointeur generique ou d un type procedure :     }
{ simple copie de pointeur, sans comptage de references.         }
{ ------------------------------------------------------------ }

Procedure EmitAssignPointer(Const DestOperand, SrcOperand: TString);
Begin
 EmitComment('Affectation de reference (classe/pointeur), simple copie');
 EmitInstr('MOV EAX,' + SrcOperand);
 EmitInstr('MOV ' + DestOperand + ',EAX');
End;

{ ------------------------------------------------------------ }
{ EmitAssignString / EmitAssignInterface : affectation avec      }
{ comptage de references automatique. Le compilateur emet       }
{ seulement l appel au runtime (Inc la nouvelle valeur, Dec      }
{ l ancienne, libere si le compteur atteint zero) ; le corps de  }
{ StrAssign/IntfAssign est fourni par TODO 20 et TODO 17/18.     }
{ DestOperand doit deja etre une adresse (ex: 'OFFSET _DPV_S' ou }
{ un registre la contenant), calculee par l appelant.             }
{ ------------------------------------------------------------ }

Procedure EmitAssignString(Const DestAddrOperand, SrcOperand: TString);
Begin
 EmitComment('Affectation AnsiString : comptage de references (TODO 20)');
 EmitInstr('PUSH ' + SrcOperand);
 EmitInstr('PUSH ' + DestAddrOperand);
 EmitInstr('CALL ' + DPRT_STR_ASSIGN);
End;

Procedure EmitAssignInterface(Const DestAddrOperand, SrcOperand: TString);
Begin
 EmitComment('Affectation d interface : comptage de references (TODO 17/18)');
 EmitInstr('PUSH ' + SrcOperand);
 EmitInstr('PUSH ' + DestAddrOperand);
 EmitInstr('CALL ' + DPRT_INTF_ASSIGN);
End;

{ ------------------------------------------------------------ }
{ EmitAssignBlock : affectation de record ou de tableau statique }
{ (copie champ par champ realisee ici en bloc via REP MOVSD,     }
{ plus REP MOVSB pour le reliquat non multiple de 4). ESI/EDI    }
{ doivent deja pointer vers la source/destination.                }
{ ------------------------------------------------------------ }

Procedure EmitAssignBlock(Const DestAddrOperand, SrcAddrOperand: TString;
 SizeBytes: Integer);
Begin
 EmitComment('Affectation de bloc (record/tableau statique), ' +
  IntToStr_(SizeBytes) + ' octets');
 EmitInstr('MOV ESI,' + SrcAddrOperand);
 EmitInstr('MOV EDI,' + DestAddrOperand);
 If SizeBytes >= 4 Then
 Begin
  EmitInstr('MOV ECX,' + IntToStr_(SizeBytes Div 4));
  EmitInstr('REP MOVSD');
 End;
 If (SizeBytes Mod 4) <> 0 Then
 Begin
  EmitInstr('MOV ECX,' + IntToStr_(SizeBytes Mod 4));
  EmitInstr('REP MOVSB');
 End;
End;

{ ------------------------------------------------------------ }
{ EmitAssign : point d entree unique de l affectation := ; route }
{ vers la bonne strategie selon la categorie du type destination:}
{ chaine/interface -> comptage de references ; classe/pointeur/  }
{ type procedure -> simple copie ; record/tableau/ensemble ->    }
{ copie de bloc ; sinon (ordinal/reel/enum/subrange) -> MOV.     }
{ ------------------------------------------------------------ }

Procedure EmitAssign(Const DestOperand, SrcOperand: TString; TypeIdx: Integer);
Var
 R : Integer;
Begin
 R := TypeResolve(TypeIdx);
 If (R < 0) Or (R >= TypeCount) Then
 Begin
  EmitAssignScalar(DestOperand, SrcOperand, 4);
  Exit;
 End;

 Case TypeTab[R].Kind Of
  TYK_STRING:
   EmitAssignString(DestOperand, SrcOperand);
  TYK_INTERFACE:
   EmitAssignInterface(DestOperand, SrcOperand);
  TYK_CLASS, TYK_POINTER, TYK_PCHAR, TYK_PROCTYPE:
   EmitAssignPointer(DestOperand, SrcOperand);
  TYK_RECORD, TYK_ARRAY, TYK_SET:
   EmitAssignBlock(DestOperand, SrcOperand, TypeTab[R].Size);
 Else
  EmitAssignScalar(DestOperand, SrcOperand, TypeTab[R].Size);
 End;
End;

{ ------------------------------------------------------------ }
{ VarAssert / VarSelfTest : verifient le cadre de pile (locales/ }
{ parametres/globales), l adressage des champs d instance avec   }
{ heritage, et le dispatch de EmitAssign, avec des cas connus,   }
{ comme les self-tests des TODO precedents.                      }
{ ------------------------------------------------------------ }

Procedure VarAssert(Const Label_: TString; Cond: Boolean);
Begin
 If Not Cond Then
  FatalError('VarSelfTest: ' + Label_ + ' a echoue');
End;

Procedure VarSelfTest;
Const
 TmpFile = 'DPVARSELFTEST.$$$';
Var
 IntIdx, ByteIdx, StrIdx                    : Integer;
 P1, P2, L1, L2                             : Integer;
 AnimalSymIdx, ChienSymIdx, AnimalIdx, ChienIdx : Integer;
 FAge, FRace, RecIdx                        : Integer;
 Ref, FieldRef                              : TString;
 F                                          : Text;
 Line                                       : TString;
 HasStrCall, HasPtrCopy, HasMovsd, HasIntfCall : Boolean;
Begin
 SymInit;
 DataInit; DataInit2;

 IntIdx  := TypeFindByName('Integer');
 ByteIdx := TypeFindByName('Byte');
 StrIdx  := TypeFindByName('String');

 { --- Cadre de pile : parametres --- }
 FrameInit;
 P1 := ParamAdd('A', IntIdx, PK_VALUE);
 P2 := ParamAdd('B', IntIdx, PK_VAR);
 VarAssert('1er parametre a EBP+8', SymTab[P1].Offset = 8);
 VarAssert('2e parametre a EBP+12', SymTab[P2].Offset = 12);
 VarAssert('parametre VAR = DWORD PTR [EBP+12] (pointeur)',
  GenVarRef('B') = 'DWORD PTR [EBP+12]');

 { --- Cadre de pile : variables locales, dans une portee dediee --- }
 SymEnterScope;
  L1 := LocalAdd('X', IntIdx);
  L2 := LocalAdd('Y', ByteIdx);
  VarAssert('1ere locale a EBP-4', SymTab[L1].Offset = -4);
  VarAssert('2e locale suit, alignee sur 4 (EBP-8)', SymTab[L2].Offset = -8);

  Ref := GenVarRef('X');
  VarAssert('GenVarRef locale Integer = DWORD PTR [EBP-4]',
   Ref = 'DWORD PTR [EBP-4]');
  Ref := GenVarRef('Y');
  VarAssert('GenVarRef locale Byte = BYTE PTR [EBP-8]',
   Ref = 'BYTE PTR [EBP-8]');
  Ref := GenVarRef('A');
  VarAssert('GenVarRef parametre valeur = DWORD PTR [EBP+8]',
   Ref = 'DWORD PTR [EBP+8]');
 SymLeaveScope;

 { --- Variable globale --- }
 GlobalVarDeclare('Total', IntIdx, 0);
 VarAssert('GenVarRef globale utilise le label mangled _DPV_TOTAL',
  GenVarRef('Total') = 'DWORD PTR [_DPV_TOTAL]');

 { --- Champs d instance, avec heritage (offset stable depuis Self) --- }
 { Le premier champ d une classe racine commence a l offset 4, pas 0 : }
 { l offset 0 est reserve au pointeur de VMT (TODO 15).                }
 AnimalSymIdx := SymDeclareClass('TANIMAL2', SK_CLASS, -1);
 AnimalIdx    := SymTab[AnimalSymIdx].TypeIdx;
 FieldInitInherit(AnimalIdx);
 FAge := TypeAddField(AnimalIdx, 'AGE', IntIdx);
 VarAssert('champ Age a l offset 4 (0 reserve au pointeur de VMT)',
  FieldPool[FAge].Offset = 4);

 ChienSymIdx := SymDeclareClass('TCHIEN2', SK_CLASS, AnimalSymIdx);
 ChienIdx    := SymTab[ChienSymIdx].TypeIdx;
 FieldInitInherit(ChienIdx);
 VarAssert('TChien2 herite du champ Age de TAnimal2',
  TypeTab[ChienIdx].FieldCount = 1);
 FRace := TypeAddField(ChienIdx, 'RACE', ByteIdx);
 VarAssert('champ propre Race suit le champ herite (offset 8)',
  FieldPool[FRace].Offset = 8);

 FieldRef := GenFieldRef('ESI', ChienIdx, 'Age');
 VarAssert('GenFieldRef champ herite = DWORD PTR [ESI+4]',
  FieldRef = 'DWORD PTR [ESI+4]');
 FieldRef := GenFieldRef('ESI', ChienIdx, 'Race');
 VarAssert('GenFieldRef champ propre = BYTE PTR [ESI+8]',
  FieldRef = 'BYTE PTR [ESI+8]');

 { --- Dispatch de EmitAssign, verifie via un mini fichier .ASM --- }
 RecIdx := TypeAddRecord('TPAIRE9');
 TypeAddField(RecIdx, 'A', IntIdx);
 TypeAddField(RecIdx, 'B', IntIdx);

 EmitOpen(TmpFile);
 EmitAssign('DWORD PTR [EBP-4]', 'DWORD PTR [EBP-8]', IntIdx);
 EmitAssign('OFFSET _DPV_S1', 'DWORD PTR [_DPV_S2]', StrIdx);
 EmitAssign('DWORD PTR [EBP-12]', 'DWORD PTR [EBP-16]', AnimalIdx);
 EmitAssign('EBP-20', 'EBP-28', RecIdx);
 EmitClose('DPVARSELFTEST_END');

 HasStrCall := False; HasPtrCopy := False;
 HasMovsd   := False; HasIntfCall := False;
 {$I-}
 Assign(F, TmpFile);
 Reset(F);
 {$I+}
 VarAssert('fichier .asm de test relisible', IOResult = 0);
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL _DPRT_STRASSIGN', Line) > 0 Then HasStrCall := True;
  If Pos('CALL _DPRT_INTFASSIGN', Line) > 0 Then HasIntfCall := True;
  If Pos('Affectation de reference', Line) > 0 Then HasPtrCopy := True;
  If Pos('REP MOVSD', Line) > 0 Then HasMovsd := True;
 End;
 Close(F);
 Erase(F);

 VarAssert('affectation AnsiString emet un appel au runtime StrAssign',
  HasStrCall);
 VarAssert('affectation de classe emet une simple copie de pointeur',
  HasPtrCopy);
 VarAssert('affectation de record emet une copie de bloc (REP MOVSD)',
  HasMovsd);
 VarAssert('affectation d interface (non exercee ici) n est pas emise',
  Not HasIntfCall);

 SymInit;
 DataInit; DataInit2;
End;

{ ============================================================ }
{ TODO 10 - EXPRESSIONS PRIMAIRES                    [IMPLEMENTE] }
{ ============================================================ }

Const
 MAX_CALL_ARGS = 16;   { arguments max par appel (limite arbitraire,   }
                         { largement suffisante pour SAMPLES\DELPHI\*) }

Var
 { Curseur de lecture dans TokenPool (rempli par le lexeur, TODO 02/04)}
 PP : Integer;

 { Type et mode d acces (valeur/adresse) de la derniere expression     }
 { evaluee - sert au code appelant (affectation, TODO 11 et suivants)  }
 LastExprTypeIdx : Integer;
 LastExprIsAddr  : Boolean;

 { Classe de la methode en cours de compilation (Self implicite),      }
 { -1 hors d une methode. Fixe par le futur compilateur de methodes    }
 { (TODO 14/15) ; le self-test le fixe lui-meme pour tester            }
 { 'inherited' sans avoir besoin d un vrai parseur de methodes.        }
 CurSelfTypeIdx : Integer;

{ ------------------------------------------------------------ }
{ ParserInit : reinitialiser le curseur de parsing et le        }
{ contexte d expression avant de compiler un corps.              }
{ ------------------------------------------------------------ }

Procedure ParserInit;
Begin
 PP              := 0;
 LastExprTypeIdx := -1;
 LastExprIsAddr  := False;
 CurSelfTypeIdx  := -1;
End;

{ ------------------------------------------------------------ }
{ PPAtEnd / PPPeekVal / PPPeekKind / PPAdvance / PPMatch :       }
{ primitives de lecture du flux de tokens, dans le style deja   }
{ eprouve par ConstEval (TODO 04) mais sur TokenPool plutot que  }
{ sur du texte brut - le parseur travaille sur les tokens deja   }
{ produits par le lexeur.                                        }
{ ------------------------------------------------------------ }

Function PPAtEnd: Boolean;
Begin
 PPAtEnd := (PP < 0) Or (PP >= TokenCount) Or
  (TokenPool[PP].Kind = TK_EOF);
End;

Function PPPeekVal: TString;
Begin
 If PPAtEnd Then PPPeekVal := '' Else PPPeekVal := TokenPool[PP].Val;
End;

Function PPPeekKind: TTokenKind;
Begin
 If PPAtEnd Then PPPeekKind := TK_EOF Else PPPeekKind := TokenPool[PP].Kind;
End;

Procedure PPAdvance;
Begin
 If Not PPAtEnd Then Inc(PP);
End;

Function PPMatch(Const S: TString): Boolean;
Begin
 PPMatch := False;
 If PPAtEnd Then Exit;
 If StrUpperCase(TokenPool[PP].Val) = StrUpperCase(S) Then
 Begin
  PPAdvance;
  PPMatch := True;
 End;
End;

{ ------------------------------------------------------------ }
{ GenVarAddr : calculer l adresse d un symbole dans EDX et       }
{ retourner 'EDX', pour l utiliser comme operande d adresse       }
{ aupres de EmitAssign (chaines/interfaces/records/tableaux,     }
{ TODO 09). Pour un parametre VAR/CONST/OUT, la case contient     }
{ deja cette adresse (MOV) ; sinon elle est calculee (LEA).       }
{ ------------------------------------------------------------ }

Function GenVarAddr(Const Name: TString): TString;
Var SI: Integer;
Begin
 GenVarAddr := 'EDX';
 SI := SymFind(Name);
 If SI < 0 Then Exit;
 If (SymTab[SI].Kind = SK_PARAM) And
    (SymTab[SI].ParamKind In [PK_VAR, PK_CONST, PK_OUT]) Then
  EmitInstr('MOV EDX,DWORD PTR ' + GenVarBracket(Name))
 Else
  EmitInstr('LEA EDX,' + GenVarBracket(Name));
End;

{ ------------------------------------------------------------ }
{ GenLoadVar : charger la valeur (ou l adresse, pour un record/  }
{ tableau/ensemble) d un symbole dans EAX. Pour un parametre      }
{ VAR/CONST/OUT, la case contient l adresse reelle : un bloc s en}
{ contente (LastExprIsAddr), un scalaire doit encore etre         }
{ dereference une fois. Une AnsiString/classe/pointeur est un     }
{ scalaire de 4 octets (sa valeur EST une reference) : elle ne    }
{ requiert PAS d adresse supplementaire en lecture (voir          }
{ GenStoreVar pour l asymetrie a l ecriture, ou StrAssign a       }
{ besoin de l adresse de la case pour la reecrire).               }
{ ------------------------------------------------------------ }

Procedure GenLoadVar(Const Name: TString);
Var
 SI, RT : Integer;
 IsBlock : Boolean;
Begin
 LastExprIsAddr := False;
 SI := SymFind(Name);
 If SI < 0 Then
 Begin
  WarnMsg('identificateur inconnu: ' + Name);
  LastExprTypeIdx := -1;
  EmitInstr('XOR EAX,EAX');
  Exit;
 End;

 LastExprTypeIdx := SymTab[SI].TypeIdx;

 If SymTab[SI].Kind = SK_CONST Then
 Begin
  EmitInstr('MOV EAX,' + IntToStr_(SymTab[SI].ImmVal));
  Exit;
 End;

 RT      := TypeResolve(SymTab[SI].TypeIdx);
 IsBlock := (RT >= 0) And (RT < TypeCount) And
  (TypeTab[RT].Kind In [TYK_RECORD, TYK_ARRAY, TYK_SET]);

 If (SymTab[SI].Kind = SK_PARAM) And
    (SymTab[SI].ParamKind In [PK_VAR, PK_CONST, PK_OUT]) Then
 Begin
  EmitInstr('MOV EAX,DWORD PTR ' + GenVarBracket(Name));  { EAX = adresse reelle }
  If IsBlock Then
   LastExprIsAddr := True
  Else If TypeSizeofIdx(SymTab[SI].TypeIdx) = 1 Then
   EmitInstr('MOVZX EAX,BYTE PTR [EAX]')
  Else
   EmitInstr('MOV EAX,DWORD PTR [EAX]');
  Exit;
 End;

 If IsBlock Then
 Begin
  EmitInstr('LEA EAX,' + GenVarBracket(Name));
  LastExprIsAddr := True;
 End
 Else
  EmitInstr('MOV EAX,' + GenVarRef(Name));
End;

{ ------------------------------------------------------------ }
{ TypeNeedsDestAddr : les records/tableaux/ensembles (copie de   }
{ bloc) et les chaines/interfaces (StrAssign/IntfAssign a besoin }
{ de l adresse de la case pour la reecrire) recoivent l ADRESSE   }
{ de la destination pour EmitAssign ; les autres types recoivent }
{ directement l operande d ecriture. Partage entre GenStoreVar    }
{ (TODO 10) et l affectation de champ (Ident.Champ := ..., TODO  }
{ 13), qui construit son propre operande d adresse [base+offset].}
{ ------------------------------------------------------------ }

Function TypeNeedsDestAddr(TypeIdx: Integer): Boolean;
Var RT: Integer;
Begin
 RT := TypeResolve(TypeIdx);
 TypeNeedsDestAddr := (RT >= 0) And (RT < TypeCount) And
  (TypeTab[RT].Kind In [TYK_RECORD, TYK_ARRAY, TYK_SET, TYK_STRING, TYK_INTERFACE]);
End;

{ ------------------------------------------------------------ }
{ GenStoreVar : ranger SrcOperand (typiquement 'EAX') dans le    }
{ symbole Name, via EmitAssign (TODO 09) qui choisit deja la     }
{ bonne strategie (voir TypeNeedsDestAddr pour le choix entre     }
{ GenVarAddr et GenVarRef comme operande destination).            }
{ ------------------------------------------------------------ }

Procedure GenStoreVar(Const Name: TString; Const SrcOperand: TString);
Var SI: Integer;
Begin
 SI := SymFind(Name);
 If SI < 0 Then
 Begin
  WarnMsg('identificateur inconnu: ' + Name);
  Exit;
 End;
 If TypeNeedsDestAddr(SymTab[SI].TypeIdx) Then
  EmitAssign(GenVarAddr(Name), SrcOperand, SymTab[SI].TypeIdx)
 Else
  EmitAssign(GenVarRef(Name), SrcOperand, SymTab[SI].TypeIdx);
End;

{ ------------------------------------------------------------ }
{ VMTFindMethodSym : comme VMTFindMethod (TODO 08), mais         }
{ retourne l index du symbole (SymTab) de la methode plutot que  }
{ son offset - necessaire pour emettre un appel statique direct  }
{ par son nom mangled, en attendant l appel virtuel via VMT       }
{ reelle d instance (TODO 15).                                    }
{ ------------------------------------------------------------ }

Function VMTFindMethodSym(ClassTypeIdx: Integer; Const MethodName: TString): Integer;
Var
 Up : TString;
 I  : Integer;
Begin
 VMTFindMethodSym := -1;
 If (ClassTypeIdx < 0) Or (ClassTypeIdx >= TypeCount) Or
    (TypeTab[ClassTypeIdx].VMTFirst < 0) Then Exit;
 Up := StrUpperCase(MethodName);
 For I := TypeTab[ClassTypeIdx].VMTFirst To
  TypeTab[ClassTypeIdx].VMTFirst + TypeTab[ClassTypeIdx].VMTCount - 1 Do
  If VMTEntryPool[I].MethodName = Up Then
  Begin
   VMTFindMethodSym := VMTEntryPool[I].MethodSymIdx;
   Exit;
  End;
End;

{ Forward declarations : ParseExpr/ParsePrimary/ParsePostfix/         }
{ ParseCallArgs forment un cycle de recursion mutuelle                }
{ (sous-expressions entre parentheses, arguments d appel, acces       }
{ postfixes en chaine a.b.c, et un appel de methode dans ParsePostfix }
{ peut lui-meme comporter des arguments).                             }
Function ParseExpr: Integer; Forward;
Function ParsePrimary: Integer; Forward;
Function ParsePostfix(BaseTypeIdx: Integer): Integer; Forward;
Function ParseCallArgs: Integer; Forward;

{ Write/WriteLn/Read/ReadLn (TODO 12) sont variadiques et routees   }
{ depuis ParsePrimary avant meme d atteindre la table des symboles ; }
{ leur implementation appelle ParseExpr, d ou ce forward aussi.      }
Function ParseWrite(DoLn: Boolean): Integer; Forward;
Function ParseRead(DoLn: Boolean): Integer; Forward;

{ Halt/Inc/Dec (TODO 13) sont des intrinseques du compilateur (pas de }
{ vraie fonction runtime a appeler) : ils lisent/ecrivent directement }
{ la variable ou emettent l arret du processus, d ou un dispatch      }
{ special dans ParsePrimary comme New/Dispose/SizeOf.                  }
Function ParseHalt: Integer; Forward;
Function ParseIncDec(IsInc: Boolean): Integer; Forward;

{ Surcharge (TODO 14) : ParsePrimary doit resoudre l arite d un appel }
{ AVANT de choisir quel symbole (parmi d eventuels homonymes) appeler.}
Function PeekArgCount: Integer; Forward;
Function SymFindOverload(Const Name: TString; ArgCount: Integer): Integer; Forward;

{ TClasseCible.Membre (TODO 15) : ParsePrimary doit reconnaitre un    }
{ SK_CLASS avant de savoir s il s agit d un typecast (suivi de '(')   }
{ ou d un acces qualifie (suivi de '.', constructeur ou methode de    }
{ classe).                                                             }
Function ParseClassMemberAccess(ClassSymIdx: Integer): Integer; Forward;

{ ------------------------------------------------------------ }
{ ParseAddrOf : @expr - adresse d une expression. Pour une        }
{ variable, force le chargement de son adresse (LEA) meme si      }
{ GenLoadVar l aurait chargee par valeur (scalaire/pointeur).      }
{ ------------------------------------------------------------ }

Function ParseAddrOf: Integer;
Var
 Name : TString;
 SI   : Integer;
Begin
 If PPPeekKind <> TK_IDENT Then
 Begin
  WarnMsg('@ attend un identificateur');
  EmitInstr('XOR EAX,EAX');
  ParseAddrOf := -1;
  Exit;
 End;
 Name := TokenPool[PP].Val;
 PPAdvance;
 SI := SymFind(Name);
 If SI < 0 Then
 Begin
  WarnMsg('identificateur inconnu: ' + Name);
  EmitInstr('XOR EAX,EAX');
  ParseAddrOf := -1;
  Exit;
 End;
 If (SymTab[SI].Kind = SK_PARAM) And
    (SymTab[SI].ParamKind In [PK_VAR, PK_CONST, PK_OUT]) Then
  EmitInstr('MOV EAX,DWORD PTR ' + GenVarBracket(Name))  { deja une adresse }
 Else
  EmitInstr('LEA EAX,' + GenVarBracket(Name));
 LastExprIsAddr  := True;
 LastExprTypeIdx := TypeAddPointer(SymTab[SI].TypeIdx);
 ParseAddrOf := LastExprTypeIdx;
End;

{ Implementee au TODO 15 (classes et heritage) mais utilisee ici :  }
{ remonte la chaine des ancetres (BaseTypeIdx) pour retrouver une    }
{ methode ordinaire (non virtuelle) heritee, ex. TObject.Free.       }
Function SymFindInClassChain(ClassTypeIdx: Integer; Const Name: TString): Integer; Forward;

{ ------------------------------------------------------------ }
{ ParseFieldAccess : Base.FieldName, ou Base est deja evaluee    }
{ (son adresse - record - ou sa reference - classe - est dans    }
{ EAX). Cherche d abord un champ (FieldPool, TODO 06/09, deja     }
{ etendu aux champs herites par FieldInitInherit) ; a defaut, une }
{ methode : appel virtuel via la VMT de l instance si elle y est  }
{ presente (virtual/dynamic/override, TODO 15), sinon appel direct}
{ au nom mangled retrouve en remontant la hierarchie des classes.  }
{ Sinon, avertissement.                                            }
{ ------------------------------------------------------------ }

Function ParseFieldAccess(BaseTypeIdx: Integer; Const FieldName: TString): Integer;
Var
 Up          : TString;
 First, Cnt, I, MethodSym, ArgN, VMTOffset : Integer;
 FieldTypeR  : Integer;
Begin
 ParseFieldAccess := -1;
 If (BaseTypeIdx < 0) Or (BaseTypeIdx >= TypeCount) Then
 Begin
  WarnMsg('acces a un champ sur une expression de type inconnu: ' + FieldName);
  Exit;
 End;

 Up    := StrUpperCase(FieldName);
 First := TypeTab[BaseTypeIdx].FieldFirst;
 Cnt   := TypeTab[BaseTypeIdx].FieldCount;

 If First >= 0 Then
  For I := First To First + Cnt - 1 Do
   If FieldPool[I].Name = Up Then
   Begin
    FieldTypeR := TypeResolve(FieldPool[I].TypeIdx);
    If (FieldTypeR >= 0) And (FieldTypeR < TypeCount) And
       (TypeTab[FieldTypeR].Kind In [TYK_RECORD, TYK_ARRAY, TYK_SET]) Then
    Begin
     If FieldPool[I].Offset = 0 Then
      EmitInstr('LEA EAX,[EAX]')
     Else
      EmitInstr('LEA EAX,[EAX+' + IntToStr_(FieldPool[I].Offset) + ']');
     LastExprIsAddr := True;
    End
    Else
    Begin
     If FieldPool[I].Offset = 0 Then
      EmitInstr('MOV EAX,' + SizedPtr(FieldPool[I].TypeIdx) + '[EAX]')
     Else
      EmitInstr('MOV EAX,' + SizedPtr(FieldPool[I].TypeIdx) + '[EAX+' +
       IntToStr_(FieldPool[I].Offset) + ']');
     LastExprIsAddr := False;
    End;
    LastExprTypeIdx := FieldPool[I].TypeIdx;
    ParseFieldAccess := LastExprTypeIdx;
    Exit;
   End;

 { Pas un champ : methode d instance. VMTFindMethod(Sym) attend un    }
 { index de TYPE (BaseTypeIdx), contrairement a SymFindInClassChain   }
 { qui attend aussi un index de TYPE mais remonte la chaine des        }
 { ancetres (contrairement a SymFindInClass, limite a une seule       }
 { classe) - ne pas melanger avec l espace d index des SYMBOLES.       }
 { Une methode presente dans la VMT (virtual/dynamic/override, TODO   }
 { 15) est appelee INDIRECTEMENT via le pointeur de VMT stocke a       }
 { l offset 0 de l instance ; une methode ordinaire (jamais ajoutee   }
 { a la VMT, ex. TObject.Free) est appelee en dur, retrouvee en        }
 { remontant la hierarchie des classes.                                }
 VMTOffset := VMTFindMethod(BaseTypeIdx, Up);
 MethodSym := VMTFindMethodSym(BaseTypeIdx, Up);
 If MethodSym < 0 Then
  MethodSym := SymFindInClassChain(BaseTypeIdx, Up);

 If MethodSym >= 0 Then
 Begin
  { Self doit etre le DERNIER argument empile (donc le 1er parametre  }
  { chez l appele, EBP+8, ParamAdd/TODO 09) : sauvegarder EAX avant   }
  { d empiler les arguments reels, qui peuvent eux-memes utiliser EAX.}
  EmitInstr('MOV EBX,EAX');    { Self sauvegarde (EBX preserve ici) }
  ArgN := ParseCallArgs;       { empile les arguments reels s il y en a }
  EmitInstr('PUSH EBX');       { Self, en dernier }
  If VMTOffset >= 0 Then
  Begin
   EmitComment('Appel virtuel de ' + FieldName + ' via la VMT de l instance');
   EmitInstr('MOV EDX,DWORD PTR [EBX]');   { EDX = pointeur de VMT }
   EmitInstr('CALL DWORD PTR [EDX+' + IntToStr_(VMTOffset) + ']');
  End
  Else
   EmitInstr('CALL ' + SymTab[MethodSym].MangledName);
  EmitInstr('ADD ESP,' + IntToStr_((ArgN + 1) * 4));  { Self + arguments }
  LastExprTypeIdx := SymTab[MethodSym].TypeIdx;
  ParseFieldAccess := LastExprTypeIdx;
  Exit;
 End;

 WarnMsg('membre inconnu: ' + FieldName);
End;

{ ------------------------------------------------------------ }
{ ParsePostfix : boucle des acces postfixes '.', '^', et des     }
{ operateurs 'is'/'as' (approximation statique par la chaine     }
{ d ancetres ParentClassIdx/BaseTypeIdx - le vrai test dynamique  }
{ par RTTI d instance viendra avec la VMT reelle, TODO 15).       }
{ ------------------------------------------------------------ }

Function ParsePostfix(BaseTypeIdx: Integer): Integer;
Var
 CurType, C, TargetIdx : Integer;
 FieldName, ClassName_  : TString;
 Compatible : Boolean;
Begin
 CurType := BaseTypeIdx;
 While Not PPAtEnd Do
 Begin
  If (PPPeekKind = TK_PUNCT) And (PPPeekVal = '.') Then
  Begin
   PPAdvance;
   FieldName := TokenPool[PP].Val;
   PPAdvance;
   CurType := ParseFieldAccess(CurType, FieldName);
  End
  Else If (PPPeekKind = TK_OP) And (PPPeekVal = '^') Then
  Begin
   PPAdvance;
   EmitInstr('MOV EAX,[EAX]');
   If (CurType >= 0) And (CurType < TypeCount) Then
    CurType := TypeTab[TypeResolve(CurType)].BaseTypeIdx
   Else
    CurType := -1;
   LastExprTypeIdx := CurType;
   LastExprIsAddr  := False;
  End
  Else If (PPPeekKind = TK_KEYWORD) And
          ((StrUpperCase(PPPeekVal) = 'IS') Or (StrUpperCase(PPPeekVal) = 'AS')) Then
  Begin
   If StrUpperCase(PPPeekVal) = 'IS' Then
   Begin
    PPAdvance;
    ClassName_ := TokenPool[PP].Val;
    PPAdvance;
    TargetIdx := SymFind(ClassName_);
    If TargetIdx >= 0 Then TargetIdx := SymTab[TargetIdx].TypeIdx Else TargetIdx := -1;
    Compatible := False;
    C := CurType;
    While C >= 0 Do
    Begin
     If C = TargetIdx Then Begin Compatible := True; Break; End;
     C := TypeTab[C].BaseTypeIdx;
    End;
    EmitComment('is ' + ClassName_ +
     ' : approximation statique (RTTI d instance reelle -> TODO 15)');
    If Compatible Then EmitInstr('MOV EAX,1') Else EmitInstr('XOR EAX,EAX');
    CurType := TypeFindByName('Boolean');
    LastExprTypeIdx := CurType;
   End
   Else   { AS }
   Begin
    PPAdvance;
    ClassName_ := TokenPool[PP].Val;
    PPAdvance;
    TargetIdx := SymFind(ClassName_);
    If TargetIdx >= 0 Then TargetIdx := SymTab[TargetIdx].TypeIdx Else TargetIdx := -1;
    If Not TypeIsAssignCompatible(CurType, TargetIdx) Then
     WarnMsg('as : conversion de classe incompatible vers ' + ClassName_);
    EmitComment('as ' + ClassName_ +
     ' : verification statique seulement (exception a l exec. -> TODO 15/18)');
    CurType := TargetIdx;
    LastExprTypeIdx := CurType;
   End;
  End
  Else
   Break;
 End;
 ParsePostfix := CurType;
End;

{ ------------------------------------------------------------ }
{ ParseTypecast : NomDeType(expr). Verifie la compatibilite de   }
{ cast (TypeIsCastCompatible, TODO 06) ; la valeur en EAX n a pas }
{ besoin de conversion pour les cas geres aujourd hui (ordinaux/  }
{ pointeurs de meme taille) - une vraie conversion FPU/troncature }
{ viendra si necessaire avec les types reels.                     }
{ ------------------------------------------------------------ }

Function ParseTypecast(TargetTypeIdx: Integer): Integer;
Var SrcType: Integer;
Begin
 PPMatch('(');
 SrcType := ParseExpr;
 If Not TypeIsCastCompatible(SrcType, TargetTypeIdx) Then
  WarnMsg('typecast incompatible vers ' + TypeTab[TargetTypeIdx].Name);
 PPMatch(')');
 LastExprTypeIdx := TargetTypeIdx;
 ParseTypecast := TargetTypeIdx;
End;

{ ------------------------------------------------------------ }
{ ParseCallArgs : parse la liste d arguments d un appel (deja     }
{ positionne juste apres le nom de la fonction/procedure/methode).}
{ Les arguments sont d abord reperes (bornes de tokens) sans etre }
{ evalues, puis evalues et empiles de DROITE A GAUCHE : c est ce  }
{ qui permet, avec un seul accumulateur EAX et sans arbre de       }
{ syntaxe, que le PREMIER argument declare finisse a [EBP+8] chez  }
{ l appele (ParamAdd, TODO 09). Retourne le nombre d arguments.    }
{ ------------------------------------------------------------ }

Function ParseCallArgs: Integer;
Var
 ArgStart : Array[0..MAX_CALL_ARGS - 1] Of Integer;
 ArgCount, Depth, SavePP, I : Integer;
Begin
 ArgCount := 0;
 If Not PPMatch('(') Then Begin ParseCallArgs := 0; Exit; End;
 If PPMatch(')') Then Begin ParseCallArgs := 0; Exit; End;

 { Reperer les bornes de chaque argument sans les evaluer : la borne  }
 { de FIN n a pas besoin d etre memorisee, ParseExpr s arrete de      }
 { lui-meme sur la ',' ou le ')' qui suit (aujourd hui parce que      }
 { ParsePrimary/ParsePostfix ne consomment que leur propre expression,}
 { demain aussi une fois le grimpeur de precedence du TODO 11 en place)}
 ArgStart[0] := PP;
 Depth := 0;
 While Not PPAtEnd Do
 Begin
  If (PPPeekVal = '(') Or (PPPeekVal = '[') Then
   Inc(Depth)
  Else If (PPPeekVal = ')') Or (PPPeekVal = ']') Then
  Begin
   If Depth = 0 Then Break;
   Dec(Depth);
  End
  Else If (PPPeekVal = ',') And (Depth = 0) Then
  Begin
   Inc(ArgCount);
   PPAdvance;
   If ArgCount < MAX_CALL_ARGS Then ArgStart[ArgCount] := PP;
   Continue;
  End;
  PPAdvance;
 End;
 Inc(ArgCount);
 PPMatch(')');

 SavePP := PP;
 For I := ArgCount - 1 DownTo 0 Do
 Begin
  PP := ArgStart[I];
  ParseExpr;
  EmitInstr('PUSH EAX');
 End;
 PP := SavePP;

 ParseCallArgs := ArgCount;
End;

{ ------------------------------------------------------------ }
{ ParseCall : appel d une procedure/fonction/methode deja        }
{ resolue (CalleeSymIdx). Convention provisoire (cdecl-like,      }
{ nettoyage par l appelant) en attendant le choix reel des        }
{ conventions d appel (register/stdcall/cdecl, TODO 14).          }
{ ------------------------------------------------------------ }

Function ParseCall(CalleeSymIdx: Integer): Integer;
Var N: Integer;
Begin
 N := ParseCallArgs;
 EmitInstr('CALL ' + SymTab[CalleeSymIdx].MangledName);
 If N > 0 Then
  EmitInstr('ADD ESP,' + IntToStr_(N * 4));
 If SymTab[CalleeSymIdx].Kind = SK_FUNC Then
  LastExprTypeIdx := SymTab[CalleeSymIdx].TypeIdx
 Else
  LastExprTypeIdx := -1;
 ParseCall := LastExprTypeIdx;
End;

{ ------------------------------------------------------------ }
{ ParseNew : New(P) - alloue via HeapAlloc (imports Win32 de     }
{ base deja poses au TODO 07) un bloc de la taille du type pointe }
{ par P, et le range dans P.                                      }
{ ------------------------------------------------------------ }

Function ParseNew: Integer;
Var
 IdentTok : TString;
 VI, PointeeIdx, Sz : Integer;
Begin
 PPMatch('(');
 IdentTok := TokenPool[PP].Val;
 PPAdvance;
 PPMatch(')');

 VI := SymFind(IdentTok);
 If VI < 0 Then
 Begin
  WarnMsg('New: variable inconnue: ' + IdentTok);
  ParseNew := -1;
  Exit;
 End;

 PointeeIdx := -1;
 If (SymTab[VI].TypeIdx >= 0) And (SymTab[VI].TypeIdx < TypeCount) Then
  PointeeIdx := TypeTab[TypeResolve(SymTab[VI].TypeIdx)].BaseTypeIdx;
 Sz := TypeSizeofIdx(PointeeIdx);
 If Sz <= 0 Then Sz := 4;

 EmitComment('New(' + IdentTok + ') : allocation via HeapAlloc');
 EmitInstr('CALL GetProcessHeap');
 EmitInstr('PUSH ' + IntToStr_(Sz));
 EmitInstr('PUSH 0');
 EmitInstr('PUSH EAX');
 EmitInstr('CALL HeapAlloc');
 GenStoreVar(IdentTok, 'EAX');

 ParseNew := -1;
End;

{ ------------------------------------------------------------ }
{ ParseDispose : Dispose(P) - libere via HeapFree le bloc pointe }
{ par P.                                                          }
{ ------------------------------------------------------------ }

Function ParseDispose: Integer;
Var IdentTok: TString;
Begin
 PPMatch('(');
 IdentTok := TokenPool[PP].Val;
 PPAdvance;
 PPMatch(')');

 GenLoadVar(IdentTok);   { EAX := valeur du pointeur }
 EmitComment('Dispose(' + IdentTok + ') : liberation via HeapFree');
 EmitInstr('MOV ESI,EAX');
 EmitInstr('CALL GetProcessHeap');
 EmitInstr('PUSH ESI');
 EmitInstr('PUSH 0');
 EmitInstr('PUSH EAX');
 EmitInstr('CALL HeapFree');

 ParseDispose := -1;
End;

{ ------------------------------------------------------------ }
{ ParseSizeOf : SizeOf(X), ou X est un nom de type ou de         }
{ variable/constante. Resultat = constante entiere immediate.    }
{ ------------------------------------------------------------ }

Function ParseSizeOf: Integer;
Var
 IdentTok : TString;
 TI, VI   : Integer;
Begin
 PPMatch('(');
 IdentTok := TokenPool[PP].Val;
 PPAdvance;
 PPMatch(')');

 TI := TypeFindByName(IdentTok);
 If TI < 0 Then
 Begin
  VI := SymFind(IdentTok);
  If VI >= 0 Then TI := SymTab[VI].TypeIdx;
 End;

 EmitInstr('MOV EAX,' + IntToStr_(TypeSizeofIdx(TI)));
 LastExprTypeIdx := TypeFindByName('Integer');
 ParseSizeOf := LastExprTypeIdx;
End;

{ ------------------------------------------------------------ }
{ ParseInherited : inherited Methode - resout Methode dans la    }
{ classe ancetre de CurSelfTypeIdx (SymFindInherited, TODO 05) et }
{ l appelle en repassant Self. CurSelfTypeIdx est fixe par le     }
{ (futur) compilateur de methodes, TODO 14/15.                    }
{ ------------------------------------------------------------ }

Function ParseInherited: Integer;
Var
 MethodName : TString;
 MethodSym, ArgN : Integer;
Begin
 ParseInherited := -1;
 If CurSelfTypeIdx < 0 Then
 Begin
  WarnMsg('inherited utilise hors d une methode');
  Exit;
 End;
 MethodName := TokenPool[PP].Val;
 PPAdvance;

 MethodSym := SymFindInherited(TypeTab[CurSelfTypeIdx].ClassSymIdx, MethodName);
 If MethodSym < 0 Then
 Begin
  WarnMsg('inherited ' + MethodName + ' : methode absente des ancetres');
  Exit;
 End;

 EmitComment('inherited ' + MethodName);
 { Self (parametre implicite du cadre courant, EBP+8) doit etre le    }
 { DERNIER argument empile (voir ParseFieldAccess) : le sauvegarder   }
 { avant d empiler les arguments reels, qui peuvent utiliser EAX.     }
 EmitInstr('MOV EBX,DWORD PTR ' + EBPOfs(PARAM_BASE_OFS));
 ArgN := ParseCallArgs;
 EmitInstr('PUSH EBX');
 EmitInstr('CALL ' + SymTab[MethodSym].MangledName);
 EmitInstr('ADD ESP,' + IntToStr_((ArgN + 1) * 4));
 LastExprTypeIdx := SymTab[MethodSym].TypeIdx;
 ParseInherited := LastExprTypeIdx;
End;

{ ------------------------------------------------------------ }
{ ParsePrimary : litteral, identificateur (constante/variable/   }
{ parametre/type/procedure/fonction), New/Dispose/SizeOf,        }
{ parenthese, @adresse, inherited - puis les acces postfixes      }
{ (ParsePostfix : .champ, ^, is/as).                              }
{ ------------------------------------------------------------ }

Function ParsePrimary: Integer;
Var
 Name, Up, Lbl : TString;
 SI, OverloadSI : Integer;
 Base : Integer;
Begin
 LastExprIsAddr := False;

 If PPAtEnd Then
 Begin
  WarnMsg('expression attendue, fin de fichier');
  EmitInstr('XOR EAX,EAX');
  ParsePrimary := -1;
  Exit;
 End;

 { Litteraux }
 If PPPeekKind = TK_INTEGER Then
 Begin
  EmitInstr('MOV EAX,' + IntToStr_(TokenPool[PP].IntVal));
  PPAdvance;
  LastExprTypeIdx := TypeFindByName('Integer');
  ParsePrimary := ParsePostfix(LastExprTypeIdx);
  Exit;
 End;

 If PPPeekKind = TK_CHAR Then
 Begin
  EmitInstr('MOV EAX,' + IntToStr_(TokenPool[PP].IntVal));
  PPAdvance;
  LastExprTypeIdx := TypeFindByName('Char');
  ParsePrimary := ParsePostfix(LastExprTypeIdx);
  Exit;
 End;

 If PPPeekKind = TK_STRING Then
 Begin
  Lbl := DataGetOrAddStr(TokenPool[PP].Val);
  EmitInstr('LEA EAX,[' + Lbl + ']');
  PPAdvance;
  LastExprIsAddr  := True;
  LastExprTypeIdx := TypeFindByName('String');
  ParsePrimary := ParsePostfix(LastExprTypeIdx);
  Exit;
 End;

 If PPPeekKind = TK_REAL Then
 Begin
  WarnMsg('litteraux reels : representation FPU non encore implementee');
  EmitInstr('XOR EAX,EAX');
  PPAdvance;
  LastExprTypeIdx := TypeFindByName('Double');
  ParsePrimary := ParsePostfix(LastExprTypeIdx);
  Exit;
 End;

 { Sous-expression parenthesee }
 If (PPPeekKind = TK_PUNCT) And (PPPeekVal = '(') Then
 Begin
  PPAdvance;
  Base := ParseExpr;
  PPMatch(')');
  ParsePrimary := ParsePostfix(Base);
  Exit;
 End;

 { Adresse @expr }
 If (PPPeekKind = TK_OP) And (PPPeekVal = '@') Then
 Begin
  PPAdvance;
  ParsePrimary := ParsePostfix(ParseAddrOf);
  Exit;
 End;

 { inherited Methode }
 If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'INHERITED') Then
 Begin
  PPAdvance;
  ParsePrimary := ParsePostfix(ParseInherited);
  Exit;
 End;

 { Identificateur }
 If PPPeekKind = TK_IDENT Then
 Begin
  Name := TokenPool[PP].Val;
  Up   := StrUpperCase(Name);
  PPAdvance;

  If Up = 'NEW' Then Begin ParsePrimary := ParseNew; Exit; End;
  If Up = 'DISPOSE' Then Begin ParsePrimary := ParseDispose; Exit; End;
  If Up = 'SIZEOF' Then Begin ParsePrimary := ParsePostfix(ParseSizeOf); Exit; End;
  If Up = 'WRITE' Then Begin ParsePrimary := ParseWrite(False); Exit; End;
  If Up = 'WRITELN' Then Begin ParsePrimary := ParseWrite(True); Exit; End;
  If Up = 'READ' Then Begin ParsePrimary := ParseRead(False); Exit; End;
  If Up = 'READLN' Then Begin ParsePrimary := ParseRead(True); Exit; End;
  If Up = 'HALT' Then Begin ParsePrimary := ParseHalt; Exit; End;
  If Up = 'INC' Then Begin ParsePrimary := ParseIncDec(True); Exit; End;
  If Up = 'DEC' Then Begin ParsePrimary := ParseIncDec(False); Exit; End;

  SI := SymFind(Name);
  If SI < 0 Then
  Begin
   WarnMsg('identificateur inconnu: ' + Name);
   EmitInstr('XOR EAX,EAX');
   ParsePrimary := -1;
   Exit;
  End;

  If SymTab[SI].Kind = SK_TYPE Then
  Begin
   ParsePrimary := ParsePostfix(ParseTypecast(SymTab[SI].TypeIdx));
   Exit;
  End;

  If SymTab[SI].Kind = SK_CLASS Then
  Begin
   { TClasseCible(expr) : cast non verifie (comme pour SK_TYPE) - une }
   { classe n est jamais suivie de '(' pour un appel qualifie, qui     }
   { s ecrit toujours TClasse.Membre(...) ; TClasseCible.Membre(...)   }
   { (constructeur ou methode de classe) est gere par                  }
   { ParseClassMemberAccess (TODO 15).                                  }
   If (PPPeekKind = TK_PUNCT) And (PPPeekVal = '.') Then
    ParsePrimary := ParsePostfix(ParseClassMemberAccess(SI))
   Else
    ParsePrimary := ParsePostfix(ParseTypecast(SymTab[SI].TypeIdx));
   Exit;
  End;

  If SymTab[SI].Kind In [SK_PROC, SK_FUNC, SK_METHOD] Then
  Begin
   { Surcharge (TODO 14) : resolue par NOMBRE d arguments seulement   }
   { (simplification documentee - pas de verification de type) ;      }
   { SI reste le repli si aucune arite ne correspond exactement.       }
   OverloadSI := SymFindOverload(Name, PeekArgCount);
   If OverloadSI >= 0 Then SI := OverloadSI;
   ParsePrimary := ParsePostfix(ParseCall(SI));
   Exit;
  End;

  { SK_CONST, SK_VAR, SK_PARAM }
  GenLoadVar(Name);
  ParsePrimary := ParsePostfix(LastExprTypeIdx);
  Exit;
 End;

 WarnMsg('jeton inattendu dans une expression: ' + PPPeekVal);
 EmitInstr('XOR EAX,EAX');
 PPAdvance;
 ParsePrimary := -1;
End;

{ ------------------------------------------------------------ }
{ ParseAssert / ParseSelfTest : verifient ParsePrimary avec des  }
{ suites de tokens synthetiques (construites directement dans     }
{ TokenPool, sans passer par le lexeur), comme les self-tests des }
{ TODO precedents. Couvre litteraux, variables/parametres/        }
{ globales, champs (avec heritage), New/Dispose/SizeOf, typecast, }
{ appel de fonction, @adresse, ^dereference et inherited.          }
{ ------------------------------------------------------------ }

Procedure ParseAssert(Const Label_: TString; Cond: Boolean);
Begin
 If Not Cond Then
  FatalError('ParseSelfTest: ' + Label_ + ' a echoue');
End;

Procedure ParseSelfTest;
Const
 TmpFile = 'DPPARSESELFTEST.$$$';
Var
 IntIdx, PtrIntIdx : Integer;
 AnimalSymIdx, ChienSymIdx, AnimalIdx, ChienIdx, SpeakSymIdx : Integer;
 FuncSymIdx : Integer;
 F : Text;
 Line : TString;
 HasHeapAlloc, HasHeapFree, HasCallFunc, HasCallSpeak : Boolean;

 Procedure Tok(Kind: TTokenKind; Const Val: TString; IntVal: LongInt);
 Var T: TToken;
 Begin
  T.Kind := Kind; T.Val := Val; T.IntVal := IntVal; T.RealVal := 0.0;
  T.Line := 1; T.Col := 1;
  TokenPoolAdd(T);
 End;

Begin
 SymInit;
 DataInit; DataInit2;
 FrameInit;

 IntIdx := TypeFindByName('Integer');

 { --- Litteral entier --- }
 TokenPoolInit;
 Tok(TK_INTEGER, '42', 42);
 ParserInit;
 ParseAssert('litteral entier -> type Integer', ParsePrimary = IntIdx);

 { --- Variable globale --- }
 GlobalVarDeclare('CompteurPT', IntIdx, 0);
 TokenPoolInit;
 Tok(TK_IDENT, 'CompteurPT', 0);
 ParserInit;
 ParseAssert('identificateur variable -> type Integer',
  ParsePrimary = IntIdx);

 { --- Parametre VAR (double dereference pour un scalaire) --- }
 SymEnterScope;
  ParamAdd('P', IntIdx, PK_VAR);
  TokenPoolInit;
  Tok(TK_IDENT, 'P', 0);
  ParserInit;
  ParseAssert('parametre VAR scalaire -> type Integer',
   ParsePrimary = IntIdx);
 SymLeaveScope;

 { --- @adresse et pointeur --- }
 TokenPoolInit;
 Tok(TK_OP, '@', 0);
 Tok(TK_IDENT, 'CompteurPT', 0);
 ParserInit;
 PtrIntIdx := ParsePrimary;
 ParseAssert('@variable produit un type pointeur', TypeIsPointer(PtrIntIdx));

 { --- Champs d instance et methode virtuelle, sur l ancetre d abord --- }
 AnimalSymIdx := SymDeclareClass('TANIMALPT', SK_CLASS, -1);
 AnimalIdx    := SymTab[AnimalSymIdx].TypeIdx;
 FieldInitInherit(AnimalIdx);
 TypeAddField(AnimalIdx, 'AGE', IntIdx);
 VMTInit(AnimalIdx);
 { Enregistrer le symbole de la methode DANS la portee de membres de }
 { la classe (SymEnterClassScope, TODO 05) : c est ce qui permet a   }
 { SymFindInherited/SymFindInClass de le retrouver plus bas.          }
 SymEnterClassScope(AnimalSymIdx);
  SpeakSymIdx := SymAdd('PARLER', SK_METHOD, IntIdx);
 SymLeaveScope;
 VMTAddMethod(AnimalIdx, 'Parler', SpeakSymIdx);

 { Le descendant herite champs ET VMT : FieldInitInherit/VMTInit      }
 { doivent s executer APRES que l ancetre a fini de declarer les      }
 { siens (sinon la copie recupererait un layout encore vide).         }
 ChienSymIdx := SymDeclareClass('TCHIENPT', SK_CLASS, AnimalSymIdx);
 ChienIdx    := SymTab[ChienSymIdx].TypeIdx;
 FieldInitInherit(ChienIdx);
 VMTInit(ChienIdx);

 GlobalVarDeclare('REX', ChienIdx, 0);

 TokenPoolInit;
 Tok(TK_IDENT, 'Rex', 0);
 Tok(TK_PUNCT, '.', 0);
 Tok(TK_IDENT, 'Age', 0);
 ParserInit;
 ParseAssert('Rex.Age (champ herite) -> type Integer',
  ParsePrimary = IntIdx);

 { --- Methode virtuelle (Parler est dans la VMT) : appel INDIRECT   }
 { via le pointeur de VMT de l instance, pas un CALL statique - voir  }
 { ParseFieldAccess/VMTFindMethod, affine au TODO 15.                 }
 TokenPoolInit;
 Tok(TK_IDENT, 'Rex', 0);
 Tok(TK_PUNCT, '.', 0);
 Tok(TK_IDENT, 'Parler', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_PUNCT, ')', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPPARSESELFTEST_END');
 HasCallSpeak := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 ParseAssert('fichier de test (methode) relisible', IOResult = 0);
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('MOV EDX,DWORD PTR [EBX]', Line) > 0 Then HasCallSpeak := True;
 End;
 Close(F); Erase(F);
 ParseAssert('Rex.Parler() appelle via la VMT (methode virtuelle)',
  HasCallSpeak);

 { --- Typecast --- }
 TokenPoolInit;
 Tok(TK_IDENT, 'Integer', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_INTEGER, '65', 65);
 Tok(TK_PUNCT, ')', 0);
 ParserInit;
 ParseAssert('Integer(65) -> type Integer', ParsePrimary = IntIdx);

 { --- SizeOf --- }
 TokenPoolInit;
 Tok(TK_IDENT, 'SizeOf', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_IDENT, 'Integer', 0);
 Tok(TK_PUNCT, ')', 0);
 ParserInit;
 ParsePrimary;
 ParseAssert('SizeOf(Integer) -> type Integer', LastExprTypeIdx = IntIdx);

 { --- Appel de fonction avec arguments (ordre d empilement) --- }
 FuncSymIdx := SymAdd('AJOUTERPT', SK_FUNC, IntIdx);
 SymTab[FuncSymIdx].ParamCount := 2;
 TokenPoolInit;
 Tok(TK_IDENT, 'AjouterPT', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_INTEGER, '1', 1);
 Tok(TK_PUNCT, ',', 0);
 Tok(TK_INTEGER, '2', 2);
 Tok(TK_PUNCT, ')', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPPARSESELFTEST_END');
 HasCallFunc := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 ParseAssert('fichier de test (appel) relisible', IOResult = 0);
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL ' + SymTab[FuncSymIdx].MangledName, Line) > 0 Then
   HasCallFunc := True;
 End;
 Close(F); Erase(F);
 ParseAssert('appel de fonction emet CALL vers le nom mangled', HasCallFunc);

 { --- New / Dispose : verifient l usage de HeapAlloc/HeapFree --- }
 GlobalVarDeclare('PTRPT', PtrIntIdx, 0);
 TokenPoolInit;
 Tok(TK_IDENT, 'New', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_IDENT, 'PtrPT', 0);
 Tok(TK_PUNCT, ')', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPPARSESELFTEST_END');
 HasHeapAlloc := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL HeapAlloc', Line) > 0 Then HasHeapAlloc := True;
 End;
 Close(F); Erase(F);
 ParseAssert('New emet un appel a HeapAlloc', HasHeapAlloc);

 TokenPoolInit;
 Tok(TK_IDENT, 'Dispose', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_IDENT, 'PtrPT', 0);
 Tok(TK_PUNCT, ')', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPPARSESELFTEST_END');
 HasHeapFree := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL HeapFree', Line) > 0 Then HasHeapFree := True;
 End;
 Close(F); Erase(F);
 ParseAssert('Dispose emet un appel a HeapFree', HasHeapFree);

 { --- inherited : Self implicite (parametre nomme SELF) --- }
 { ParserInit remet CurSelfTypeIdx a -1 (nouveau contexte d expression}
 { "vierge") : il doit donc etre appele AVANT que le contexte de       }
 { methode courante soit etabli, pas apres.                            }
 SymEnterScope;
  ParamAdd('SELF', ChienIdx, PK_VALUE);
  TokenPoolInit;
  Tok(TK_KEYWORD, 'inherited', 0);
  Tok(TK_IDENT, 'Parler', 0);
  ParserInit;
  CurSelfTypeIdx := ChienIdx;
  ParseAssert('inherited Parler resout la methode de TAnimalPT',
   ParsePrimary = IntIdx);
 SymLeaveScope;
 CurSelfTypeIdx := -1;

 TokenPoolInit;
 SymInit;
 DataInit; DataInit2;
 FrameInit;
End;

{ ============================================================ }
{ TODO 11 - EXPRESSIONS BINAIRES ET PRECEDENCE       [IMPLEMENTE] }
{ ============================================================ }

Const
 { Runtime (_DPRT_, TODO 07/09) pour la concatenation et la          }
 { comparaison d AnsiString - corps reel fourni par TODO 20.          }
 DPRT_STR_CONCAT  = '_DPRT_STRCONCAT';   { Concat(A, B): Pointer      }
 DPRT_STR_COMPARE = '_DPRT_STRCOMPARE';  { Compare(A, B): Integer,    }
                                          { <0/0/>0 comme strcmp       }

{ ------------------------------------------------------------ }
{ BinOpPrec : niveau de precedence d un operateur binaire Pascal.}
{ 0 = pas un operateur binaire. Plus haut = lie plus fort :      }
{   3 : * / div mod and shl shr   (multiplicatif)                }
{   2 : + - or xor                (additif)                      }
{   1 : = <> < > <= >= in         (relationnel)                  }
{ ------------------------------------------------------------ }

Function BinOpPrec(Const Op: TString): Integer;
Begin
 If (Op = '*') Or (Op = '/') Or (Op = 'DIV') Or (Op = 'MOD') Or
    (Op = 'AND') Or (Op = 'SHL') Or (Op = 'SHR') Then
  BinOpPrec := 3
 Else If (Op = '+') Or (Op = '-') Or (Op = 'OR') Or (Op = 'XOR') Then
  BinOpPrec := 2
 Else If (Op = '=') Or (Op = '<>') Or (Op = '<') Or (Op = '>') Or
         (Op = '<=') Or (Op = '>=') Or (Op = 'IN') Then
  BinOpPrec := 1
 Else
  BinOpPrec := 0;
End;

{ ------------------------------------------------------------ }
{ EmitCompareJcc : motif commun aux comparaisons ordinales :     }
{ CMP EAX,EBX puis saut conditionnel Jcc -> resultat Boolean     }
{ (0 ou 1) dans EAX.                                              }
{ ------------------------------------------------------------ }

Procedure EmitCompareJcc(Const Jcc: TString);
Var LblT, LblE: TString;
Begin
 LblT := LabelGen;
 LblE := LabelGen;
 EmitInstr('CMP EAX,EBX');
 EmitInstr(Jcc + ' ' + LblT);
 EmitInstr('XOR EAX,EAX');
 EmitInstr('JMP ' + LblE);
 EmitLabel(LblT);
 EmitInstr('MOV EAX,1');
 EmitLabel(LblE);
End;

{ ------------------------------------------------------------ }
{ EmitCompareZeroJcc : meme motif que EmitCompareJcc, mais       }
{ compare EAX a 0 plutot qu a EBX - pour interpreter le resultat }
{ <0/0/>0 d un appel runtime de type strcmp (_DPRT_STRCOMPARE).  }
{ ------------------------------------------------------------ }

Procedure EmitCompareZeroJcc(Const Jcc: TString);
Var LblT, LblE: TString;
Begin
 LblT := LabelGen;
 LblE := LabelGen;
 EmitInstr('CMP EAX,0');
 EmitInstr(Jcc + ' ' + LblT);
 EmitInstr('XOR EAX,EAX');
 EmitInstr('JMP ' + LblE);
 EmitLabel(LblT);
 EmitInstr('MOV EAX,1');
 EmitLabel(LblE);
End;

{ ------------------------------------------------------------ }
{ EmitBinOp : emettre EAX := EAX op EBX (operandes ordinaux deja }
{ evalues) - arithmetique, decalages, bit a bit et comparaisons. }
{ Les cas chaine/court-circuit/IN sont geres en amont, dans       }
{ ParseExprPrec, avant d atteindre ce chemin generique.           }
{ ------------------------------------------------------------ }

Procedure EmitBinOp(Const Op: TString);
Begin
 If Op = '+' Then EmitInstr('ADD EAX,EBX')
 Else If Op = '-' Then EmitInstr('SUB EAX,EBX')
 Else If Op = '*' Then EmitInstr('IMUL EAX,EBX')
 Else If (Op = '/') Or (Op = 'DIV') Then
 Begin
  EmitInstr('CDQ');
  EmitInstr('IDIV EBX');
 End
 Else If Op = 'MOD' Then
 Begin
  EmitInstr('CDQ');
  EmitInstr('IDIV EBX');
  EmitInstr('MOV EAX,EDX');
 End
 Else If Op = 'SHL' Then
 Begin
  EmitInstr('MOV ECX,EBX');
  EmitInstr('SHL EAX,CL');
 End
 Else If Op = 'SHR' Then
 Begin
  EmitInstr('MOV ECX,EBX');
  EmitInstr('SHR EAX,CL');
 End
 Else If Op = 'AND' Then EmitInstr('AND EAX,EBX')
 Else If Op = 'OR' Then EmitInstr('OR EAX,EBX')
 Else If Op = 'XOR' Then EmitInstr('XOR EAX,EBX')
 Else If Op = '=' Then EmitCompareJcc('JE')
 Else If Op = '<>' Then EmitCompareJcc('JNE')
 Else If Op = '<' Then EmitCompareJcc('JL')
 Else If Op = '<=' Then EmitCompareJcc('JLE')
 Else If Op = '>' Then EmitCompareJcc('JG')
 Else If Op = '>=' Then EmitCompareJcc('JGE')
 Else
  EmitComment('operateur binaire inconnu: ' + Op);
End;

{ ------------------------------------------------------------ }
{ ParseUnary : NOT/@/unaire +/-, plus haute precedence. NOT et   }
{ AND/OR ont deux semantiques selon le type de l operande        }
{ (Boolean -> logique/court-circuit, ordinal -> bit a bit) ; a    }
{ la difference de TPCW32 (qui traite AND/OR uniformement en      }
{ court-circuit, ce qui est incorrect sur des entiers), NOT/AND/  }
{ OR verifient ici le type reel de l operande.                    }
{ ------------------------------------------------------------ }

Function ParseUnary: Integer;
Var
 R : Integer;
 LblT, LblE : TString;
Begin
 If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'NOT') Then
 Begin
  PPAdvance;
  R := ParseUnary;
  If TypeIsBoolean(R) Then
  Begin
   LblT := LabelGen;
   LblE := LabelGen;
   EmitInstr('CMP EAX,0');
   EmitInstr('JE ' + LblT);
   EmitInstr('XOR EAX,EAX');
   EmitInstr('JMP ' + LblE);
   EmitLabel(LblT);
   EmitInstr('MOV EAX,1');
   EmitLabel(LblE);
  End
  Else
   EmitInstr('NOT EAX');
  ParseUnary := R;
  Exit;
 End;

 If (PPPeekKind = TK_OP) And (PPPeekVal = '-') Then
 Begin
  PPAdvance;
  R := ParseUnary;
  EmitInstr('NEG EAX');
  ParseUnary := R;
  Exit;
 End;

 If (PPPeekKind = TK_OP) And (PPPeekVal = '+') Then
 Begin
  PPAdvance;
  R := ParseUnary;
  ParseUnary := R;
  Exit;
 End;

 ParseUnary := ParsePrimary;
End;

{ ------------------------------------------------------------ }
{ ParseExprPrec : grimpeur de precedence (Pratt) pour expressions}
{ binaires Pascal. MinPrec = precedence minimale a capturer.      }
{ Le resultat est toujours dans EAX, LastExprTypeIdx a jour.      }
{ Chaines et interfaces (comparaison/concatenation) sont routees  }
{ vers un appel runtime (_DPRT_, corps reel au TODO 20) plutot    }
{ que vers EmitBinOp, qui suppose des operandes ordinaux/reels.   }
{ ------------------------------------------------------------ }

Procedure ParseExprPrec(MinPrec: Integer);
Var
 Op       : TString;
 Prec     : Integer;
 LeftType : Integer;
 LblF, LblT, LblE : TString;
Begin
 ParseUnary;

 While Not PPAtEnd Do
 Begin
  Op := '';
  If (PPPeekKind = TK_OP) Or (PPPeekKind = TK_KEYWORD) Then
   Op := StrUpperCase(PPPeekVal);

  Prec := BinOpPrec(Op);
  If (Prec = 0) Or (Prec < MinPrec) Then Break;

  LeftType := LastExprTypeIdx;
  PPAdvance;

  { --- Chaines : + concatene, les autres comparent (TODO 20) --- }
  If TypeIsString(LeftType) Then
  Begin
   EmitInstr('PUSH EAX');
   ParseExprPrec(Prec + 1);
   EmitInstr('MOV EBX,EAX');
   EmitInstr('POP EAX');
   If Op = '+' Then
   Begin
    EmitComment('Concatenation AnsiString : runtime (TODO 20)');
    EmitInstr('PUSH EBX');
    EmitInstr('PUSH EAX');
    EmitInstr('CALL ' + DPRT_STR_CONCAT);
    LastExprTypeIdx := LeftType;
   End
   Else
   Begin
    EmitComment('Comparaison AnsiString : runtime (TODO 20)');
    EmitInstr('PUSH EBX');
    EmitInstr('PUSH EAX');
    EmitInstr('CALL ' + DPRT_STR_COMPARE);
    { EAX = <0 / 0 / >0 (comme strcmp) : traduire en Boolean via le }
    { meme motif Jcc que les comparaisons ordinaires, mais contre 0 }
    If Op = '=' Then EmitCompareZeroJcc('JE')
    Else If Op = '<>' Then EmitCompareZeroJcc('JNE')
    Else If Op = '<' Then EmitCompareZeroJcc('JL')
    Else If Op = '<=' Then EmitCompareZeroJcc('JLE')
    Else If Op = '>' Then EmitCompareZeroJcc('JG')
    Else If Op = '>=' Then EmitCompareZeroJcc('JGE');
    LastExprTypeIdx := TypeFindByName('Boolean');
   End;
   Continue;
  End;

  { --- Court-circuit AND/OR (Boolean uniquement) --- }
  If (Op = 'AND') And TypeIsBoolean(LeftType) Then
  Begin
   LblF := LabelGen;
   LblE := LabelGen;
   EmitInstr('TEST EAX,EAX');
   EmitInstr('JZ ' + LblF);
   ParseExprPrec(Prec + 1);
   EmitInstr('TEST EAX,EAX');
   EmitInstr('JZ ' + LblF);
   EmitInstr('MOV EAX,1');
   EmitInstr('JMP ' + LblE);
   EmitLabel(LblF);
   EmitInstr('XOR EAX,EAX');
   EmitLabel(LblE);
   LastExprTypeIdx := LeftType;
   Continue;
  End;

  If (Op = 'OR') And TypeIsBoolean(LeftType) Then
  Begin
   LblF := LabelGen;
   LblE := LabelGen;
   EmitInstr('TEST EAX,EAX');
   EmitInstr('JNZ ' + LblF);
   ParseExprPrec(Prec + 1);
   EmitInstr('TEST EAX,EAX');
   EmitInstr('JNZ ' + LblF);
   EmitInstr('XOR EAX,EAX');
   EmitInstr('JMP ' + LblE);
   EmitLabel(LblF);
   EmitInstr('MOV EAX,1');
   EmitLabel(LblE);
   LastExprTypeIdx := LeftType;
   Continue;
  End;

  { --- IN : test d appartenance a un ensemble (bit dans un bloc  }
  { de 32 octets, cf TSetVal/TODO 04 ; BT sur operande memoire     }
  { adresse au-dela de 32 bits, valide en x86) ---                }
  If Op = 'IN' Then
  Begin
   EmitInstr('PUSH EAX');
   ParseExprPrec(Prec + 1);   { EAX = adresse du set (bloc, GenLoadVar) }
   EmitInstr('MOV EBX,EAX');
   EmitInstr('POP EAX');
   LblT := LabelGen;
   LblE := LabelGen;
   EmitInstr('BT DWORD PTR [EBX],EAX');
   EmitInstr('JC ' + LblT);
   EmitInstr('XOR EAX,EAX');
   EmitInstr('JMP ' + LblE);
   EmitLabel(LblT);
   EmitInstr('MOV EAX,1');
   EmitLabel(LblE);
   LastExprTypeIdx := TypeFindByName('Boolean');
   Continue;
  End;

  If TypeIsReal(LeftType) Then
   WarnMsg('arithmetique flottante non encore implementee (FPU)');

  { --- Cas general : arithmetique/bit-a-bit/comparaison ordinaux --- }
  EmitInstr('PUSH EAX');
  ParseExprPrec(Prec + 1);
  EmitInstr('MOV EBX,EAX');
  EmitInstr('POP EAX');
  EmitBinOp(Op);

  If Prec = 1 Then
   LastExprTypeIdx := TypeFindByName('Boolean')
  Else
   LastExprTypeIdx := TypeCoerce(LeftType, LastExprTypeIdx);
 End;
End;

{ ------------------------------------------------------------ }
{ ParseExpr : point d entree d une expression complete           }
{ (precedence minimale 1) - remplace l implementation temporaire }
{ du TODO 10. Tous les appelants (parentheses, arguments d appel, }
{ typecast) beneficient automatiquement des operateurs binaires   }
{ sans avoir ete modifies.                                        }
{ ------------------------------------------------------------ }

Function ParseExpr: Integer;
Begin
 ParseExprPrec(1);
 ParseExpr := LastExprTypeIdx;
End;

{ ------------------------------------------------------------ }
{ BinAssert / BinSelfTest : verifient la precedence, les          }
{ parentheses, le court-circuit Boolean vs le bit-a-bit ordinal,  }
{ IN, et l unaire NOT/-, avec des cas connus, comme les self-tests}
{ des TODO precedents.                                            }
{ ------------------------------------------------------------ }

Procedure BinAssert(Const Label_: TString; Cond: Boolean);
Begin
 If Not Cond Then
  FatalError('BinSelfTest: ' + Label_ + ' a echoue');
End;

Procedure BinSelfTest;
Const
 TmpFile = 'DPBINSELFTEST.$$$';
Var
 IntIdx, BoolIdx, SetIdx : Integer;
 F : Text;
 Line : TString;
 LineNo, MulLine, AddLine, JzLine, AndLine, NotLine, BtLine, NegLine : Integer;

 Procedure Tok(Kind: TTokenKind; Const Val: TString; IntVal: LongInt);
 Var T: TToken;
 Begin
  T.Kind := Kind; T.Val := Val; T.IntVal := IntVal; T.RealVal := 0.0;
  T.Line := 1; T.Col := 1;
  TokenPoolAdd(T);
 End;

Begin
 SymInit;
 DataInit; DataInit2;
 FrameInit;

 IntIdx  := TypeFindByName('Integer');
 BoolIdx := TypeFindByName('Boolean');

 { --- Precedence : 2 + 3 * 4 -> IMUL doit apparaitre avant ADD --- }
 TokenPoolInit;
 Tok(TK_INTEGER, '2', 2);
 Tok(TK_OP, '+', 0);
 Tok(TK_INTEGER, '3', 3);
 Tok(TK_OP, '*', 0);
 Tok(TK_INTEGER, '4', 4);
 ParserInit;
 EmitOpen(TmpFile);
 BinAssert('2+3*4 -> type Integer', ParseExpr = IntIdx);
 EmitClose('DPBINSELFTEST_END');

 MulLine := -1; AddLine := -1; LineNo := 0;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 BinAssert('fichier de test (precedence) relisible', IOResult = 0);
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  Inc(LineNo);
  If (MulLine < 0) And (Pos('IMUL EAX,EBX', Line) > 0) Then MulLine := LineNo;
  If (AddLine < 0) And (Pos('ADD EAX,EBX', Line) > 0) Then AddLine := LineNo;
 End;
 Close(F); Erase(F);
 BinAssert('IMUL emis', MulLine >= 0);
 BinAssert('ADD emis', AddLine >= 0);
 BinAssert('2+3*4 : la multiplication est evaluee avant l addition',
  MulLine < AddLine);

 { --- Parentheses : (2 + 3) * 4 -> ADD doit apparaitre avant IMUL --- }
 TokenPoolInit;
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_INTEGER, '2', 2);
 Tok(TK_OP, '+', 0);
 Tok(TK_INTEGER, '3', 3);
 Tok(TK_PUNCT, ')', 0);
 Tok(TK_OP, '*', 0);
 Tok(TK_INTEGER, '4', 4);
 ParserInit;
 EmitOpen(TmpFile);
 ParseExpr;
 EmitClose('DPBINSELFTEST_END');

 MulLine := -1; AddLine := -1; LineNo := 0;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  Inc(LineNo);
  If (MulLine < 0) And (Pos('IMUL EAX,EBX', Line) > 0) Then MulLine := LineNo;
  If (AddLine < 0) And (Pos('ADD EAX,EBX', Line) > 0) Then AddLine := LineNo;
 End;
 Close(F); Erase(F);
 BinAssert('(2+3)*4 : les parentheses inversent l ordre', AddLine < MulLine);

 { --- Comparaison -> Boolean, motif Jcc --- }
 TokenPoolInit;
 Tok(TK_INTEGER, '1', 1);
 Tok(TK_OP, '=', 0);
 Tok(TK_INTEGER, '1', 1);
 ParserInit;
 BinAssert('1 = 1 -> type Boolean', ParseExpr = BoolIdx);

 { --- AND court-circuit (Boolean) vs bit-a-bit (Integer) --- }
 GlobalVarDeclare('BFLAGA', BoolIdx, 1);
 GlobalVarDeclare('BFLAGB', BoolIdx, 1);
 GlobalVarDeclare('NINTA', IntIdx, 6);
 GlobalVarDeclare('NINTB', IntIdx, 3);

 TokenPoolInit;
 Tok(TK_IDENT, 'BFlagA', 0);
 Tok(TK_KEYWORD, 'and', 0);
 Tok(TK_IDENT, 'BFlagB', 0);
 ParserInit;
 EmitOpen(TmpFile);
 BinAssert('BFlagA and BFlagB -> type Boolean', ParseExpr = BoolIdx);
 EmitClose('DPBINSELFTEST_END');
 JzLine := -1; AndLine := -1; LineNo := 0;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  Inc(LineNo);
  If Pos('JZ ', Line) > 0 Then JzLine := LineNo;
  If Pos('AND EAX,EBX', Line) > 0 Then AndLine := LineNo;
 End;
 Close(F); Erase(F);
 BinAssert('AND booleen utilise un saut court-circuit (JZ)', JzLine >= 0);
 BinAssert('AND booleen n emet pas AND EAX,EBX bit a bit', AndLine < 0);

 TokenPoolInit;
 Tok(TK_IDENT, 'NIntA', 0);
 Tok(TK_KEYWORD, 'and', 0);
 Tok(TK_IDENT, 'NIntB', 0);
 ParserInit;
 EmitOpen(TmpFile);
 BinAssert('NIntA and NIntB -> type Integer (bit a bit)', ParseExpr = IntIdx);
 EmitClose('DPBINSELFTEST_END');
 AndLine := -1;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('AND EAX,EBX', Line) > 0 Then AndLine := LineNo;
 End;
 Close(F); Erase(F);
 BinAssert('AND entier emet AND EAX,EBX (bit a bit, pas de court-circuit)',
  AndLine >= 0);

 { --- NOT : logique (Boolean) vs bit a bit (Integer) --- }
 TokenPoolInit;
 Tok(TK_KEYWORD, 'not', 0);
 Tok(TK_IDENT, 'BFlagA', 0);
 ParserInit;
 EmitOpen(TmpFile);
 BinAssert('not BFlagA -> type Boolean', ParseExpr = BoolIdx);
 EmitClose('DPBINSELFTEST_END');
 NotLine := -1;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('NOT EAX', Line) > 0 Then NotLine := 1;
 End;
 Close(F); Erase(F);
 BinAssert('not booleen n emet pas NOT EAX (logique, pas bit a bit)',
  NotLine < 0);

 TokenPoolInit;
 Tok(TK_KEYWORD, 'not', 0);
 Tok(TK_IDENT, 'NIntA', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParseExpr;
 EmitClose('DPBINSELFTEST_END');
 NotLine := -1;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('NOT EAX', Line) > 0 Then NotLine := 1;
 End;
 Close(F); Erase(F);
 BinAssert('not entier emet NOT EAX (bit a bit)', NotLine >= 0);

 { --- Unaire moins --- }
 TokenPoolInit;
 Tok(TK_OP, '-', 0);
 Tok(TK_IDENT, 'NIntA', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParseExpr;
 EmitClose('DPBINSELFTEST_END');
 NegLine := -1;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('NEG EAX', Line) > 0 Then NegLine := 1;
 End;
 Close(F); Erase(F);
 BinAssert('-NIntA emet NEG EAX', NegLine >= 0);

 { --- IN : test d appartenance a un ensemble --- }
 SetIdx := TypeAddSet(IntIdx);
 GlobalVarDeclare('MYSETBIN', SetIdx, 0);
 TokenPoolInit;
 Tok(TK_IDENT, 'NIntA', 0);
 Tok(TK_KEYWORD, 'in', 0);
 Tok(TK_IDENT, 'MySetBin', 0);
 ParserInit;
 EmitOpen(TmpFile);
 BinAssert('NIntA in MySetBin -> type Boolean', ParseExpr = BoolIdx);
 EmitClose('DPBINSELFTEST_END');
 BtLine := -1;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('BT DWORD PTR', Line) > 0 Then BtLine := 1;
 End;
 Close(F); Erase(F);
 BinAssert('in emet un test de bit (BT)', BtLine >= 0);

 SymInit;
 DataInit; DataInit2;
 FrameInit;
End;

{ ============================================================ }
{ TODO 12 - ENTREES/SORTIES ET RTL MINIMALE           [IMPLEMENTE] }
{ (System/SysUtils)                                              }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ EmitRuntimeData : variables et buffers de la RTL minimale,    }
{ emis inconditionnellement (comme les imports EXTRN du TODO 07)}
{ - simple, sur et coherent, meme si un programme donne n en    }
{ utilise pas la totalite.                                       }
{ ------------------------------------------------------------ }

Procedure EmitRuntimeData;
Begin
 EmitComment('--- Variables et buffers runtime (RTL minimale) ---');
 EmitRaw('DPRT_HSTDOUT       DD 0');
 EmitRaw('DPRT_HSTDIN        DD 0');
 EmitRaw('DPRT_BYTESWRITTEN  DD 0');
 EmitRaw('DPRT_BYTESREAD     DD 0');
 EmitRaw('DPRT_NUMBUF        DB 32 DUP(0)');   { IntToStr : entier -> texte }
 EmitRaw('DPRT_CHARBUF       DB 1 DUP(0)');    { WriteChar : un seul octet }
 EmitRaw('DPRT_LINEBUF       DB 256 DUP(0)');  { ReadLine : une ligne lue  }
 EmitRaw('DPRT_TRUESTR       DB ''TRUE'',0');
 EmitRaw('DPRT_FALSESTR      DB ''FALSE'',0');
 EmitRaw('DPRT_CRLF          DB 13,10,0');
 EmitRaw('DPRT_FLOATSTUB     DB ''0.0'',0');   { FloatToStr : FPU non geree }
 EmitBlankLine;
End;

{ ------------------------------------------------------------ }
{ EmitRuntimeLibrary : corps ASM des routines _DPRT_* utilisees }
{ par Write/WriteLn/Read/ReadLn et par les fonctions RTL         }
{ enregistrees dans SymRegisterBuiltins (RegRTLFunc, TODO 05).   }
{ Convention d appel : identique aux fonctions Pascal generees   }
{ par ce compilateur (cadre EBP standard, 1er parametre a        }
{ EBP+8, nettoyage de pile par l appelant) - PAS la convention    }
{ stdcall des API Win32 (GetStdHandle/WriteFile/ReadFile/         }
{ HeapAlloc/HeapFree, deja importees au TODO 07), qui nettoient    }
{ leur propre pile et ne doivent donc jamais recevoir de ADD ESP  }
{ apres leur CALL.                                                }
{ ------------------------------------------------------------ }

Procedure EmitRuntimeLibrary;
Var
 TObjIdx, CreateSym, DestroySym, FreeSym, DestroyVMTOffset : Integer;
Begin
 EmitComment('--- RTL minimale : _DPRT_INIT ---');
 EmitLabel(DPRT_INIT);
 EmitProlog(0);
 EmitInstr('PUSH -11');                          { STD_OUTPUT_HANDLE }
 EmitInstr('CALL GetStdHandle');
 EmitInstr('MOV DWORD PTR [DPRT_HSTDOUT],EAX');
 EmitInstr('PUSH -10');                          { STD_INPUT_HANDLE  }
 EmitInstr('CALL GetStdHandle');
 EmitInstr('MOV DWORD PTR [DPRT_HSTDIN],EAX');
 EmitEpilog;
 EmitBlankLine;

 EmitComment('--- _DPRT_STRLEN(P: Pointer): Integer ---');
 EmitLabel(DPRT_STRLEN);
 EmitProlog(0);
 EmitInstr('PUSH EDI');
 EmitInstr('MOV EDI,DWORD PTR [EBP+8]');
 EmitInstr('MOV ECX,0FFFFFFFFh');
 EmitInstr('XOR AL,AL');
 EmitInstr('REPNE SCASB');
 EmitInstr('NOT ECX');
 EmitInstr('DEC ECX');
 EmitInstr('MOV EAX,ECX');
 EmitInstr('POP EDI');
 EmitEpilog;
 EmitBlankLine;

 EmitComment('--- _DPRT_WRITESTR(P: Pointer) : ecrit P (ASCIIZ) sur stdout ---');
 EmitLabel(DPRT_WRITESTR);
 EmitProlog(0);
 EmitInstr('PUSH ESI');
 EmitInstr('PUSH EBX');
 EmitInstr('MOV ESI,DWORD PTR [EBP+8]');
 EmitInstr('PUSH ESI');
 EmitInstr('CALL ' + DPRT_STRLEN);
 EmitInstr('ADD ESP,4');
 EmitInstr('MOV EBX,EAX');
 EmitInstr('TEST EBX,EBX');
 EmitInstr('JZ DPRT_WRITESTR_DONE');
 EmitInstr('PUSH 0');
 EmitInstr('LEA EAX,[DPRT_BYTESWRITTEN]');
 EmitInstr('PUSH EAX');
 EmitInstr('PUSH EBX');
 EmitInstr('PUSH ESI');
 EmitInstr('PUSH DWORD PTR [DPRT_HSTDOUT]');
 EmitInstr('CALL WriteFile');
 EmitLabel('DPRT_WRITESTR_DONE');
 EmitInstr('POP EBX');
 EmitInstr('POP ESI');
 EmitEpilog;
 EmitBlankLine;

 EmitComment('--- _DPRT_WRITECHAR(C: Integer) : ecrit 1 caractere sur stdout ---');
 EmitLabel(DPRT_WRITECHAR);
 EmitProlog(0);
 EmitInstr('MOV AL,BYTE PTR [EBP+8]');
 EmitInstr('MOV BYTE PTR [DPRT_CHARBUF],AL');
 EmitInstr('PUSH 0');
 EmitInstr('LEA EAX,[DPRT_BYTESWRITTEN]');
 EmitInstr('PUSH EAX');
 EmitInstr('PUSH 1');
 EmitInstr('LEA EAX,[DPRT_CHARBUF]');
 EmitInstr('PUSH EAX');
 EmitInstr('PUSH DWORD PTR [DPRT_HSTDOUT]');
 EmitInstr('CALL WriteFile');
 EmitEpilog;
 EmitBlankLine;

 EmitComment('--- _DPRT_INTTOSTR(N: Integer): Pointer (buffer partage) ---');
 EmitLabel(DPRT_INTTOSTR);
 EmitProlog(0);
 EmitInstr('PUSH ESI');
 EmitInstr('PUSH EDI');
 EmitInstr('PUSH EBX');
 EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
 EmitInstr('LEA EDI,[DPRT_NUMBUF+31]');
 EmitInstr('MOV BYTE PTR [EDI],0');
 EmitInstr('XOR EBX,EBX');
 EmitInstr('CMP EAX,0');
 EmitInstr('JGE DPRT_ITS_POS');
 EmitInstr('MOV EBX,1');
 EmitInstr('NEG EAX');
 EmitLabel('DPRT_ITS_POS');
 EmitInstr('MOV ESI,10');
 EmitLabel('DPRT_ITS_LOOP');
 EmitInstr('XOR EDX,EDX');
 EmitInstr('DIV ESI');
 EmitInstr('ADD EDX,30h');           { '0' }
 EmitInstr('DEC EDI');
 EmitInstr('MOV BYTE PTR [EDI],DL');
 EmitInstr('TEST EAX,EAX');
 EmitInstr('JNZ DPRT_ITS_LOOP');
 EmitInstr('CMP EBX,0');
 EmitInstr('JE DPRT_ITS_DONE');
 EmitInstr('DEC EDI');
 EmitInstr('MOV BYTE PTR [EDI],2Dh');  { '-' }
 EmitLabel('DPRT_ITS_DONE');
 EmitInstr('MOV EAX,EDI');
 EmitInstr('POP EBX');
 EmitInstr('POP EDI');
 EmitInstr('POP ESI');
 EmitEpilog;
 EmitBlankLine;

 EmitComment('--- _DPRT_STRTOINT(P: Pointer): Integer ---');
 EmitLabel(DPRT_STRTOINT);
 EmitProlog(0);
 EmitInstr('PUSH ESI');
 EmitInstr('PUSH EDX');
 EmitInstr('MOV ESI,DWORD PTR [EBP+8]');
 EmitInstr('XOR EAX,EAX');
 EmitInstr('XOR EDX,EDX');
 EmitInstr('MOV CL,BYTE PTR [ESI]');
 EmitInstr('CMP CL,2Dh');            { '-' }
 EmitInstr('JNE DPRT_STI_NOSIGN');
 EmitInstr('MOV EDX,1');
 EmitInstr('INC ESI');
 EmitLabel('DPRT_STI_NOSIGN');
 EmitLabel('DPRT_STI_LOOP');
 EmitInstr('MOV CL,BYTE PTR [ESI]');
 EmitInstr('CMP CL,30h');            { '0' }
 EmitInstr('JL DPRT_STI_DONE');
 EmitInstr('CMP CL,39h');            { '9' }
 EmitInstr('JG DPRT_STI_DONE');
 EmitInstr('IMUL EAX,EAX,10');
 EmitInstr('MOVZX ECX,CL');
 EmitInstr('SUB ECX,30h');
 EmitInstr('ADD EAX,ECX');
 EmitInstr('INC ESI');
 EmitInstr('JMP DPRT_STI_LOOP');
 EmitLabel('DPRT_STI_DONE');
 EmitInstr('CMP EDX,1');
 EmitInstr('JNE DPRT_STI_RET');
 EmitInstr('NEG EAX');
 EmitLabel('DPRT_STI_RET');
 EmitInstr('POP EDX');
 EmitInstr('POP ESI');
 EmitEpilog;
 EmitBlankLine;

 EmitComment('--- _DPRT_STRTOINTDEF(P: Pointer; Def: Integer): Integer ---');
 EmitLabel(DPRT_STRTOINTDEF);
 EmitProlog(0);
 EmitInstr('PUSH ESI');
 EmitInstr('MOV ESI,DWORD PTR [EBP+8]');
 EmitInstr('MOV CL,BYTE PTR [ESI]');
 EmitInstr('CMP CL,2Dh');            { '-' }
 EmitInstr('JE DPRT_STID_OK');
 EmitInstr('CMP CL,30h');            { '0' }
 EmitInstr('JL DPRT_STID_FAIL');
 EmitInstr('CMP CL,39h');            { '9' }
 EmitInstr('JG DPRT_STID_FAIL');
 EmitLabel('DPRT_STID_OK');
 EmitInstr('PUSH DWORD PTR [EBP+8]');
 EmitInstr('CALL ' + DPRT_STRTOINT);
 EmitInstr('ADD ESP,4');
 EmitInstr('JMP DPRT_STID_DONE');
 EmitLabel('DPRT_STID_FAIL');
 EmitInstr('MOV EAX,DWORD PTR [EBP+12]');
 EmitLabel('DPRT_STID_DONE');
 EmitInstr('POP ESI');
 EmitEpilog;
 EmitBlankLine;

 EmitComment('--- _DPRT_FLOATTOSTR/_DPRT_STRTOFLOAT : stubs (FPU non geree) ---');
 EmitLabel(DPRT_FLOATTOSTR);
 EmitProlog(0);
 EmitComment('FloatToStr : arithmetique flottante non implementee');
 EmitInstr('LEA EAX,[DPRT_FLOATSTUB]');
 EmitEpilog;
 EmitBlankLine;

 EmitLabel(DPRT_STRTOFLOAT);
 EmitProlog(0);
 EmitComment('StrToFloat : arithmetique flottante non implementee');
 EmitInstr('XOR EAX,EAX');
 EmitEpilog;
 EmitBlankLine;

 EmitComment('--- _DPRT_READLINE : Pointer (lit une ligne depuis stdin) ---');
 EmitLabel(DPRT_READLINE);
 EmitProlog(0);
 EmitInstr('PUSH ESI');
 EmitInstr('PUSH EBX');
 EmitInstr('PUSH 0');
 EmitInstr('LEA EAX,[DPRT_BYTESREAD]');
 EmitInstr('PUSH EAX');
 EmitInstr('PUSH 255');
 EmitInstr('LEA EAX,[DPRT_LINEBUF]');
 EmitInstr('PUSH EAX');
 EmitInstr('PUSH DWORD PTR [DPRT_HSTDIN]');
 EmitInstr('CALL ReadFile');
 EmitInstr('MOV EBX,DWORD PTR [DPRT_BYTESREAD]');
 EmitInstr('LEA ESI,[DPRT_LINEBUF]');
 EmitInstr('ADD ESI,EBX');
 EmitInstr('MOV BYTE PTR [ESI],0');
 EmitLabel('DPRT_RL_STRIP');
 EmitInstr('CMP ESI,OFFSET DPRT_LINEBUF');
 EmitInstr('JE DPRT_RL_DONE');
 EmitInstr('MOV AL,BYTE PTR [ESI-1]');
 EmitInstr('CMP AL,13');
 EmitInstr('JE DPRT_RL_CUT');
 EmitInstr('CMP AL,10');
 EmitInstr('JE DPRT_RL_CUT');
 EmitInstr('JMP DPRT_RL_DONE');
 EmitLabel('DPRT_RL_CUT');
 EmitInstr('DEC ESI');
 EmitInstr('MOV BYTE PTR [ESI],0');
 EmitInstr('JMP DPRT_RL_STRIP');
 EmitLabel('DPRT_RL_DONE');
 EmitInstr('LEA EAX,[DPRT_LINEBUF]');
 EmitInstr('POP EBX');
 EmitInstr('POP ESI');
 EmitEpilog;
 EmitBlankLine;

 EmitComment('--- _DPRT_TRIM(P: Pointer): Pointer (nouveau buffer HeapAlloc) ---');
 EmitLabel(DPRT_TRIM);
 EmitProlog(0);
 EmitInstr('PUSH ESI');
 EmitInstr('PUSH EDI');
 EmitInstr('PUSH EBX');
 EmitInstr('MOV ESI,DWORD PTR [EBP+8]');
 EmitLabel('DPRT_TRIM_SKIPL');
 EmitInstr('MOV AL,BYTE PTR [ESI]');
 EmitInstr('CMP AL,20h');            { espace }
 EmitInstr('JNE DPRT_TRIM_FOUNDSTART');
 EmitInstr('CMP AL,0');
 EmitInstr('JE DPRT_TRIM_FOUNDSTART');
 EmitInstr('INC ESI');
 EmitInstr('JMP DPRT_TRIM_SKIPL');
 EmitLabel('DPRT_TRIM_FOUNDSTART');
 EmitInstr('PUSH ESI');
 EmitInstr('CALL ' + DPRT_STRLEN);
 EmitInstr('ADD ESP,4');
 EmitInstr('MOV EDI,ESI');
 EmitInstr('ADD EDI,EAX');
 EmitLabel('DPRT_TRIM_SKIPR');
 EmitInstr('CMP EDI,ESI');
 EmitInstr('JE DPRT_TRIM_FOUNDEND');
 EmitInstr('MOV AL,BYTE PTR [EDI-1]');
 EmitInstr('CMP AL,20h');
 EmitInstr('JNE DPRT_TRIM_FOUNDEND');
 EmitInstr('DEC EDI');
 EmitInstr('JMP DPRT_TRIM_SKIPR');
 EmitLabel('DPRT_TRIM_FOUNDEND');
 EmitInstr('MOV EBX,EDI');
 EmitInstr('SUB EBX,ESI');
 EmitInstr('MOV ECX,EBX');
 EmitInstr('INC ECX');
 EmitInstr('CALL GetProcessHeap');
 EmitInstr('PUSH ECX');
 EmitInstr('PUSH 0');
 EmitInstr('PUSH EAX');
 EmitInstr('CALL HeapAlloc');
 EmitInstr('MOV EDI,EAX');
 EmitInstr('MOV ECX,EBX');
 EmitInstr('CLD');
 EmitInstr('REP MOVSB');
 EmitInstr('MOV BYTE PTR [EDI],0');
 EmitInstr('MOV EAX,EDI');
 EmitInstr('SUB EAX,EBX');
 EmitInstr('POP EBX');
 EmitInstr('POP EDI');
 EmitInstr('POP ESI');
 EmitEpilog;
 EmitBlankLine;

 EmitComment('--- _DPRT_UPPERCASE/_DPRT_LOWERCASE(P): Pointer (nouveau buffer) ---');
 EmitLabel(DPRT_UPPERCASE);
 EmitProlog(0);
 EmitInstr('PUSH ESI');
 EmitInstr('PUSH EDI');
 EmitInstr('PUSH EBX');
 EmitInstr('MOV ESI,DWORD PTR [EBP+8]');
 EmitInstr('PUSH ESI');
 EmitInstr('CALL ' + DPRT_STRLEN);
 EmitInstr('ADD ESP,4');
 EmitInstr('MOV EBX,EAX');
 EmitInstr('MOV ECX,EBX');
 EmitInstr('INC ECX');
 EmitInstr('CALL GetProcessHeap');
 EmitInstr('PUSH ECX');
 EmitInstr('PUSH 0');
 EmitInstr('PUSH EAX');
 EmitInstr('CALL HeapAlloc');
 EmitInstr('MOV EDI,EAX');
 EmitInstr('MOV ECX,EBX');
 EmitInstr('TEST ECX,ECX');
 EmitInstr('JZ DPRT_UC_DONE');
 EmitLabel('DPRT_UC_LOOP');
 EmitInstr('MOV AL,BYTE PTR [ESI]');
 EmitInstr('CMP AL,61h');            { 'a' }
 EmitInstr('JL DPRT_UC_STORE');
 EmitInstr('CMP AL,7Ah');            { 'z' }
 EmitInstr('JG DPRT_UC_STORE');
 EmitInstr('SUB AL,20h');
 EmitLabel('DPRT_UC_STORE');
 EmitInstr('MOV BYTE PTR [EDI],AL');
 EmitInstr('INC ESI');
 EmitInstr('INC EDI');
 EmitInstr('DEC ECX');
 EmitInstr('JNZ DPRT_UC_LOOP');
 EmitLabel('DPRT_UC_DONE');
 EmitInstr('MOV BYTE PTR [EDI],0');
 EmitInstr('MOV EAX,EDI');
 EmitInstr('SUB EAX,EBX');
 EmitInstr('POP EBX');
 EmitInstr('POP EDI');
 EmitInstr('POP ESI');
 EmitEpilog;
 EmitBlankLine;

 EmitLabel(DPRT_LOWERCASE);
 EmitProlog(0);
 EmitInstr('PUSH ESI');
 EmitInstr('PUSH EDI');
 EmitInstr('PUSH EBX');
 EmitInstr('MOV ESI,DWORD PTR [EBP+8]');
 EmitInstr('PUSH ESI');
 EmitInstr('CALL ' + DPRT_STRLEN);
 EmitInstr('ADD ESP,4');
 EmitInstr('MOV EBX,EAX');
 EmitInstr('MOV ECX,EBX');
 EmitInstr('INC ECX');
 EmitInstr('CALL GetProcessHeap');
 EmitInstr('PUSH ECX');
 EmitInstr('PUSH 0');
 EmitInstr('PUSH EAX');
 EmitInstr('CALL HeapAlloc');
 EmitInstr('MOV EDI,EAX');
 EmitInstr('MOV ECX,EBX');
 EmitInstr('TEST ECX,ECX');
 EmitInstr('JZ DPRT_LC_DONE');
 EmitLabel('DPRT_LC_LOOP');
 EmitInstr('MOV AL,BYTE PTR [ESI]');
 EmitInstr('CMP AL,41h');            { 'A' }
 EmitInstr('JL DPRT_LC_STORE');
 EmitInstr('CMP AL,5Ah');            { 'Z' }
 EmitInstr('JG DPRT_LC_STORE');
 EmitInstr('ADD AL,20h');
 EmitLabel('DPRT_LC_STORE');
 EmitInstr('MOV BYTE PTR [EDI],AL');
 EmitInstr('INC ESI');
 EmitInstr('INC EDI');
 EmitInstr('DEC ECX');
 EmitInstr('JNZ DPRT_LC_LOOP');
 EmitLabel('DPRT_LC_DONE');
 EmitInstr('MOV BYTE PTR [EDI],0');
 EmitInstr('MOV EAX,EDI');
 EmitInstr('SUB EAX,EBX');
 EmitInstr('POP EBX');
 EmitInstr('POP EDI');
 EmitInstr('POP ESI');
 EmitEpilog;
 EmitBlankLine;

 EmitComment('--- _DPRT_COMPARESTR(A,B: Pointer): Integer (comme strcmp) ---');
 EmitLabel(DPRT_COMPARESTR);
 EmitProlog(0);
 EmitInstr('PUSH ESI');
 EmitInstr('PUSH EDI');
 EmitInstr('MOV ESI,DWORD PTR [EBP+8]');
 EmitInstr('MOV EDI,DWORD PTR [EBP+12]');
 EmitLabel('DPRT_CS_LOOP');
 EmitInstr('MOV AL,BYTE PTR [ESI]');
 EmitInstr('MOV DL,BYTE PTR [EDI]');
 EmitInstr('CMP AL,DL');
 EmitInstr('JNE DPRT_CS_DIFF');
 EmitInstr('TEST AL,AL');
 EmitInstr('JZ DPRT_CS_EQUAL');
 EmitInstr('INC ESI');
 EmitInstr('INC EDI');
 EmitInstr('JMP DPRT_CS_LOOP');
 EmitLabel('DPRT_CS_DIFF');
 EmitInstr('MOVZX EAX,AL');
 EmitInstr('MOVZX EDX,DL');
 EmitInstr('SUB EAX,EDX');
 EmitInstr('JMP DPRT_CS_DONE');
 EmitLabel('DPRT_CS_EQUAL');
 EmitInstr('XOR EAX,EAX');
 EmitLabel('DPRT_CS_DONE');
 EmitInstr('POP EDI');
 EmitInstr('POP ESI');
 EmitEpilog;
 EmitBlankLine;

 EmitComment('--- _DPRT_COMPARETEXT(A,B: Pointer): Integer (insensible casse) ---');
 EmitLabel(DPRT_COMPARETEXT);
 EmitProlog(8);
 EmitInstr('PUSH DWORD PTR [EBP+8]');
 EmitInstr('CALL ' + DPRT_UPPERCASE);
 EmitInstr('ADD ESP,4');
 EmitInstr('MOV DWORD PTR [EBP-4],EAX');
 EmitInstr('PUSH DWORD PTR [EBP+12]');
 EmitInstr('CALL ' + DPRT_UPPERCASE);
 EmitInstr('ADD ESP,4');
 EmitInstr('MOV DWORD PTR [EBP-8],EAX');
 EmitInstr('PUSH DWORD PTR [EBP-8]');
 EmitInstr('PUSH DWORD PTR [EBP-4]');
 EmitInstr('CALL ' + DPRT_COMPARESTR);
 EmitInstr('ADD ESP,8');
 EmitEpilog;
 EmitBlankLine;

 { --- TObject : corps reels de Create/Destroy/Free (TODO 15). Ces   }
 { symboles existent des le TODO 05 (SymRegisterBuiltins) ; leurs     }
 { noms mangled reels (qualifies par classe depuis le TODO 15) sont   }
 { retrouves ici dynamiquement, pas recopies en dur.                   }
 TObjIdx := SymFind('TObject');
 If TObjIdx >= 0 Then
 Begin
  CreateSym  := SymFindInClass(TObjIdx, 'CREATE');
  DestroySym := SymFindInClass(TObjIdx, 'DESTROY');
  FreeSym    := SymFindInClass(TObjIdx, 'FREE');

  If CreateSym >= 0 Then
  Begin
   EmitComment('--- TObject.Create : corps vide (l allocation elle-meme');
   EmitComment('    est faite au site d appel, ParseClassMemberAccess) ---');
   EmitLabel(SymTab[CreateSym].MangledName);
   EmitProlog(0);
   EmitEpilog;
   EmitBlankLine;
  End;

  If DestroySym >= 0 Then
  Begin
   EmitComment('--- TObject.Destroy (virtuelle) : corps vide par defaut ---');
   EmitLabel(SymTab[DestroySym].MangledName);
   EmitProlog(0);
   EmitEpilog;
   EmitBlankLine;
  End;

  If (FreeSym >= 0) And (DestroySym >= 0) Then
  Begin
   DestroyVMTOffset := VMTFindMethod(SymTab[TObjIdx].TypeIdx, 'DESTROY');
   EmitComment('--- TObject.Free(Self) : Destroy virtuel puis HeapFree ---');
   EmitLabel(SymTab[FreeSym].MangledName);
   EmitProlog(0);
   EmitInstr('MOV EBX,DWORD PTR [EBP+8]');
   EmitInstr('TEST EBX,EBX');
   EmitInstr('JZ DPRT_TOBJECT_FREE_DONE');
   If DestroyVMTOffset >= 0 Then
   Begin
    EmitInstr('MOV EDX,DWORD PTR [EBX]');
    EmitInstr('PUSH EBX');
    EmitInstr('CALL DWORD PTR [EDX+' + IntToStr_(DestroyVMTOffset) + ']');
   End
   Else
   Begin
    EmitInstr('PUSH EBX');
    EmitInstr('CALL ' + SymTab[DestroySym].MangledName);
   End;
   EmitInstr('ADD ESP,4');
   EmitInstr('CALL GetProcessHeap');
   EmitInstr('PUSH EBX');
   EmitInstr('PUSH 0');
   EmitInstr('PUSH EAX');
   EmitInstr('CALL HeapFree');
   EmitLabel('DPRT_TOBJECT_FREE_DONE');
   EmitEpilog;
   EmitBlankLine;
  End;
 End;
End;

{ ------------------------------------------------------------ }
{ EmitWriteArg : evalue une expression et emet le code pour     }
{ l afficher sur stdout, selon son type (Boolean -> 'TRUE'/     }
{ 'FALSE', String -> WRITESTR, Char -> WRITECHAR, autre         }
{ (ordinal) -> INTTOSTR puis WRITESTR).                          }
{ ------------------------------------------------------------ }

Procedure EmitWriteArg;
Var
 T, RT : Integer;
 LblF, LblE : TString;
Begin
 T  := ParseExpr;
 RT := TypeResolve(T);

 If (RT >= 0) And (RT < TypeCount) And (TypeTab[RT].Kind = TYK_BOOLEAN) Then
 Begin
  LblF := LabelGen;
  LblE := LabelGen;
  EmitInstr('CMP EAX,0');
  EmitInstr('JE ' + LblF);
  EmitInstr('MOV EAX,OFFSET DPRT_TRUESTR');
  EmitInstr('JMP ' + LblE);
  EmitLabel(LblF);
  EmitInstr('MOV EAX,OFFSET DPRT_FALSESTR');
  EmitLabel(LblE);
  EmitInstr('PUSH EAX');
  EmitInstr('CALL ' + DPRT_WRITESTR);
  EmitInstr('ADD ESP,4');
  Exit;
 End;

 If TypeIsString(RT) Then
 Begin
  EmitInstr('PUSH EAX');
  EmitInstr('CALL ' + DPRT_WRITESTR);
  EmitInstr('ADD ESP,4');
  Exit;
 End;

 If (RT >= 0) And (RT < TypeCount) And (TypeTab[RT].Kind = TYK_CHAR) Then
 Begin
  EmitInstr('PUSH EAX');
  EmitInstr('CALL ' + DPRT_WRITECHAR);
  EmitInstr('ADD ESP,4');
  Exit;
 End;

 { Par defaut : traiter comme un ordinal (Integer, Byte, enum...) }
 EmitInstr('PUSH EAX');
 EmitInstr('CALL ' + DPRT_INTTOSTR);
 EmitInstr('ADD ESP,4');
 EmitInstr('PUSH EAX');
 EmitInstr('CALL ' + DPRT_WRITESTR);
 EmitInstr('ADD ESP,4');
End;

{ ------------------------------------------------------------ }
{ ParseWrite : Write(...)/WriteLn(...), avec ou sans parametres.}
{ Chaque argument est affiche des qu il est evalue (pas besoin   }
{ de l ordre inverse de ParseCallArgs : les arguments de Write    }
{ n interagissent pas entre eux comme le ferait une vraie pile   }
{ de parametres).                                                 }
{ ------------------------------------------------------------ }

Function ParseWrite(DoLn: Boolean): Integer;
Begin
 ParseWrite := -1;
 If PPMatch('(') Then
 Begin
  If Not PPMatch(')') Then
  Begin
   Repeat
    EmitWriteArg;
   Until Not PPMatch(',');
   PPMatch(')');
  End;
 End;
 If DoLn Then
 Begin
  EmitInstr('PUSH OFFSET DPRT_CRLF');
  EmitInstr('CALL ' + DPRT_WRITESTR);
  EmitInstr('ADD ESP,4');
 End;
End;

{ ------------------------------------------------------------ }
{ ParseRead : Read(...)/ReadLn(...) - lit une ligne par variable }
{ (simplification : Read se comporte ici comme ReadLn, faute     }
{ d un flux de lecture continu entre plusieurs appels ; a         }
{ documenter/ameliorer si des exemples en dependent, TODO 25).    }
{ Convertit vers Integer via STRTOINT si la variable n est pas   }
{ une chaine.                                                     }
{ ------------------------------------------------------------ }

Function ParseRead(DoLn: Boolean): Integer;
Var
 IdentTok : TString;
 SI, RT   : Integer;
Begin
 ParseRead := -1;
 If PPMatch('(') Then
 Begin
  If Not PPMatch(')') Then
  Begin
   Repeat
    IdentTok := TokenPool[PP].Val;
    PPAdvance;
    EmitInstr('CALL ' + DPRT_READLINE);
    SI := SymFind(IdentTok);
    If SI < 0 Then
    Begin
     WarnMsg('Read: variable inconnue: ' + IdentTok);
    End
    Else
    Begin
     RT := TypeResolve(SymTab[SI].TypeIdx);
     If Not TypeIsString(RT) Then
     Begin
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ' + DPRT_STRTOINT);
      EmitInstr('ADD ESP,4');
     End;
     GenStoreVar(IdentTok, 'EAX');
    End;
   Until Not PPMatch(',');
   PPMatch(')');
  End;
 End;
End;

{ ------------------------------------------------------------ }
{ RTLAssert / RTLSelfTest : verifient le dispatch de Write/       }
{ WriteLn/Read/ReadLn et l enregistrement des fonctions RTL a     }
{ corps reel (IntToStr...), avec des cas connus, comme les        }
{ self-tests des TODO precedents.                                 }
{ ------------------------------------------------------------ }

Procedure RTLAssert(Const Label_: TString; Cond: Boolean);
Begin
 If Not Cond Then
  FatalError('RTLSelfTest: ' + Label_ + ' a echoue');
End;

Procedure RTLSelfTest;
Const
 TmpFile = 'DPRTLSELFTEST.$$$';
Var
 IntIdx, StrIdx, BoolIdx, CharIdx : Integer;
 IntToStrSym : Integer;
 F : Text;
 Line : TString;
 HasWriteStr, HasWriteChar, HasIntToStr, HasCrlf, HasTrueStr : Boolean;
 HasReadLine, HasStrToInt : Boolean;

 Procedure Tok(Kind: TTokenKind; Const Val: TString; IntVal: LongInt);
 Var T: TToken;
 Begin
  T.Kind := Kind; T.Val := Val; T.IntVal := IntVal; T.RealVal := 0.0;
  T.Line := 1; T.Col := 1;
  TokenPoolAdd(T);
 End;

Begin
 SymInit;
 DataInit; DataInit2;
 FrameInit;

 IntIdx  := TypeFindByName('Integer');
 StrIdx  := TypeFindByName('String');
 BoolIdx := TypeFindByName('Boolean');
 CharIdx := TypeFindByName('Char');

 { --- IntToStr est enregistree avec un nom mangled runtime reel --- }
 IntToStrSym := SymFind('IntToStr');
 RTLAssert('IntToStr enregistree comme fonction', IntToStrSym >= 0);
 RTLAssert('IntToStr pointe le runtime _DPRT_INTTOSTR',
  SymTab[IntToStrSym].MangledName = DPRT_INTTOSTR);

 { --- WriteLn('texte') : chaine + saut de ligne --- }
 GlobalVarDeclare('RTLDUMMYSTR', StrIdx, 0);
 TokenPoolInit;
 Tok(TK_IDENT, 'WriteLn', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_IDENT, 'RTLDummyStr', 0);
 Tok(TK_PUNCT, ')', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPRTLSELFTEST_END');

 HasWriteStr := False; HasCrlf := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 RTLAssert('fichier de test (WriteLn chaine) relisible', IOResult = 0);
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL ' + DPRT_WRITESTR, Line) > 0 Then HasWriteStr := True;
  If Pos('DPRT_CRLF', Line) > 0 Then HasCrlf := True;
 End;
 Close(F); Erase(F);
 RTLAssert('WriteLn(chaine) appelle WRITESTR', HasWriteStr);
 RTLAssert('WriteLn ajoute le saut de ligne (DPRT_CRLF)', HasCrlf);

 { --- Write(MonEntier) : conversion via INTTOSTR --- }
 GlobalVarDeclare('RTLDUMMYINT', IntIdx, 0);
 TokenPoolInit;
 Tok(TK_IDENT, 'Write', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_IDENT, 'RTLDummyInt', 0);
 Tok(TK_PUNCT, ')', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPRTLSELFTEST_END');

 HasIntToStr := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL ' + DPRT_INTTOSTR, Line) > 0 Then HasIntToStr := True;
 End;
 Close(F); Erase(F);
 RTLAssert('Write(entier) convertit via INTTOSTR', HasIntToStr);

 { --- Write(MonBooleen) : chaine TRUE/FALSE --- }
 GlobalVarDeclare('RTLDUMMYBOOL', BoolIdx, 1);
 TokenPoolInit;
 Tok(TK_IDENT, 'Write', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_IDENT, 'RTLDummyBool', 0);
 Tok(TK_PUNCT, ')', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPRTLSELFTEST_END');

 HasTrueStr := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('DPRT_TRUESTR', Line) > 0 Then HasTrueStr := True;
 End;
 Close(F); Erase(F);
 RTLAssert('Write(booleen) reference DPRT_TRUESTR/FALSESTR', HasTrueStr);

 { --- Write(MonChar) : appelle WRITECHAR, pas WRITESTR/INTTOSTR --- }
 GlobalVarDeclare('RTLDUMMYCHAR', CharIdx, 65);
 TokenPoolInit;
 Tok(TK_IDENT, 'Write', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_IDENT, 'RTLDummyChar', 0);
 Tok(TK_PUNCT, ')', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPRTLSELFTEST_END');

 HasWriteChar := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL ' + DPRT_WRITECHAR, Line) > 0 Then HasWriteChar := True;
 End;
 Close(F); Erase(F);
 RTLAssert('Write(caractere) appelle WRITECHAR', HasWriteChar);

 { --- ReadLn(MaVar) : lecture puis conversion Integer --- }
 TokenPoolInit;
 Tok(TK_IDENT, 'ReadLn', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_IDENT, 'RTLDummyInt', 0);
 Tok(TK_PUNCT, ')', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPRTLSELFTEST_END');

 HasReadLine := False; HasStrToInt := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL ' + DPRT_READLINE, Line) > 0 Then HasReadLine := True;
  If Pos('CALL ' + DPRT_STRTOINT, Line) > 0 Then HasStrToInt := True;
 End;
 Close(F); Erase(F);
 RTLAssert('ReadLn(entier) appelle READLINE', HasReadLine);
 RTLAssert('ReadLn(entier) convertit via STRTOINT', HasStrToInt);

 { --- Write() / WriteLn sans arguments (bornes) --- }
 TokenPoolInit;
 Tok(TK_IDENT, 'WriteLn', 0);
 ParserInit;
 ParsePrimary;   { ne doit pas planter sans '(' ni arguments }

 { --- Squelette complet : verifier que -asm produit un .asm     }
 { assemblable qui appelle bien _DPRT_INIT au demarrage --- }
 EmitSkeletonProgram(TmpFile);
 HasWriteStr := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 RTLAssert('squelette .asm relisible', IOResult = 0);
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL ' + DPRT_INIT, Line) > 0 Then HasWriteStr := True;
 End;
 Close(F); Erase(F);
 RTLAssert('le squelette de programme appelle _DPRT_INIT au demarrage',
  HasWriteStr);

 SymInit;
 DataInit; DataInit2;
 FrameInit;
End;

{ ============================================================ }
{ TODO 13 - STRUCTURES DE CONTROLE                   [IMPLEMENTE] }
{ ============================================================ }

Const
 MAX_LOOP_DEPTH = 32;

Var
 { Pile de boucles pour Break/Continue }
 LoopBreakLbl : Array[0..MAX_LOOP_DEPTH - 1] Of TString;
 LoopContLbl  : Array[0..MAX_LOOP_DEPTH - 1] Of TString;
 LoopTop      : Integer;    { -1 = aucune boucle active }

 { Label de retour de la procedure/fonction courante, pour Exit ;    }
 { '' = hors de tout corps compile. Fixe par le (futur) compilateur  }
 { de procedures/fonctions (TODO 14) ; le self-test le fixe lui-meme }
 { pour tester Exit sans avoir besoin d un vrai parseur de methodes. }
 CurRetLabel : TString;

Procedure StmtInit;
Begin
 LoopTop     := -1;
 CurRetLabel := '';
End;

Procedure LoopPush(Const LblBreak, LblCont: TString);
Begin
 If LoopTop >= MAX_LOOP_DEPTH - 1 Then
 Begin
  WarnMsg('trop de boucles imbriquees');
  Exit;
 End;
 Inc(LoopTop);
 LoopBreakLbl[LoopTop] := LblBreak;
 LoopContLbl[LoopTop]  := LblCont;
End;

Procedure LoopPop;
Begin
 If LoopTop >= 0 Then Dec(LoopTop);
End;

{ ------------------------------------------------------------ }
{ SkipOptSemi : consommer un ';' optionnel - separateur entre    }
{ instructions, jamais consomme par les fonctions de parsing     }
{ d instruction elles-memes (responsabilite de l appelant :       }
{ ParseCompoundStmt, le corps de Repeat, ou le pilote de plus     }
{ haut niveau qui appellera ParseStmt en boucle, TODO 14/23).      }
{ ------------------------------------------------------------ }

Procedure SkipOptSemi;
Begin
 If (PPPeekKind = TK_PUNCT) And (PPPeekVal = ';') Then PPAdvance;
End;

{ Forward declarations : ParseStmt et les differentes structures    }
{ de controle s appellent mutuellement (corps de boucle, branches    }
{ if/case, blocs Begin..End imbriques).                               }
Procedure ParseStmt; Forward;

{ ------------------------------------------------------------ }
{ SkipToMatchingEnd : avancer jusqu au END correspondant, en     }
{ tenant compte de l imbrication (BEGIN/CASE/TRY/RECORD ouvrent  }
{ un niveau, END le ferme). Utilise par ParseTryStmt (stub, TODO }
{ 18) pour ignorer un bloc try..except..finally..end en entier   }
{ sans en generer le code, tout en gardant le parseur synchronise.}
{ ------------------------------------------------------------ }

Procedure SkipToMatchingEnd;
Var Depth: Integer; U: TString;
Begin
 Depth := 1;
 While (Not PPAtEnd) And (Depth > 0) Do
 Begin
  If PPPeekKind = TK_KEYWORD Then
  Begin
   U := StrUpperCase(PPPeekVal);
   If (U = 'BEGIN') Or (U = 'CASE') Or (U = 'TRY') Or (U = 'RECORD') Then
    Inc(Depth)
   Else If U = 'END' Then
    Dec(Depth);
  End;
  PPAdvance;
 End;
End;

{ ------------------------------------------------------------ }
{ ParseHalt : Halt ou Halt(N) - arret immediat du processus.     }
{ Intrinseque du compilateur (comme New/Dispose/SizeOf, TODO 10):}
{ Halt() n est pas une vraie fonction runtime, la gestion de la  }
{ presence/absence de parametre doit se faire a l analyse.       }
{ ------------------------------------------------------------ }

Function ParseHalt: Integer;
Begin
 If PPMatch('(') Then
 Begin
  If Not PPMatch(')') Then
  Begin
   ParseExpr;
   PPMatch(')');
  End
  Else
   EmitInstr('XOR EAX,EAX');
 End
 Else
  EmitInstr('XOR EAX,EAX');
 EmitInstr('PUSH EAX');
 EmitInstr('CALL ExitProcess');
 ParseHalt := -1;
End;

{ ------------------------------------------------------------ }
{ ParseIncDec : Inc(X)/Inc(X,N)/Dec(X)/Dec(X,N) - lecture-       }
{ modification-ecriture directe de la variable, sans aucun       }
{ appel runtime (intrinseque, comme Halt ci-dessus).              }
{ ------------------------------------------------------------ }

Function ParseIncDec(IsInc: Boolean): Integer;
Var
 IdentTok  : TString;
 HasAmount : Boolean;
Begin
 PPMatch('(');
 IdentTok := TokenPool[PP].Val;
 PPAdvance;
 HasAmount := PPMatch(',');
 GenLoadVar(IdentTok);
 If HasAmount Then
 Begin
  EmitInstr('PUSH EAX');
  ParseExpr;
  EmitInstr('MOV EBX,EAX');
  EmitInstr('POP EAX');
  If IsInc Then EmitInstr('ADD EAX,EBX') Else EmitInstr('SUB EAX,EBX');
 End
 Else
 Begin
  If IsInc Then EmitInstr('INC EAX') Else EmitInstr('DEC EAX');
 End;
 PPMatch(')');
 GenStoreVar(IdentTok, 'EAX');
 ParseIncDec := -1;
End;

{ ------------------------------------------------------------ }
{ ParseCompoundStmt : BEGIN instr ; instr ; ... END              }
{ ------------------------------------------------------------ }

Procedure ParseCompoundStmt;
Var SavePP: Integer;
Begin
 PPAdvance;   { begin }
 While Not PPAtEnd Do
 Begin
  If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'END') Then
  Begin
   PPAdvance;
   Exit;
  End;
  SavePP := PP;
  ParseStmt;
  SkipOptSemi;
  If PP = SavePP Then PPAdvance;   { filet de securite anti-boucle infinie }
 End;
End;

{ ------------------------------------------------------------ }
{ ParseIfStmt : IF cond THEN stmt [ELSE stmt]                   }
{ ------------------------------------------------------------ }

Procedure ParseIfStmt;
Var LblElse, LblEndIf: TString;
Begin
 EmitComment('if');
 PPAdvance;   { if }
 ParseExpr;

 LblElse := LabelGen;
 LblEndIf := LabelGen;
 EmitInstr('TEST EAX,EAX');
 EmitInstr('JZ ' + LblElse);

 If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'THEN') Then
  PPAdvance;

 ParseStmt;

 If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'ELSE') Then
 Begin
  EmitInstr('JMP ' + LblEndIf);
  EmitLabel(LblElse);
  PPAdvance;   { else }
  ParseStmt;
  EmitLabel(LblEndIf);
 End
 Else
  EmitLabel(LblElse);
End;

{ ------------------------------------------------------------ }
{ ParseWhileStmt : WHILE cond DO stmt                            }
{ ------------------------------------------------------------ }

Procedure ParseWhileStmt;
Var LblTest, LblEnd: TString;
Begin
 EmitComment('while');
 PPAdvance;   { while }

 LblTest := LabelGen;
 LblEnd  := LabelGen;

 EmitLabel(LblTest);
 ParseExpr;
 EmitInstr('TEST EAX,EAX');
 EmitInstr('JZ ' + LblEnd);

 If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'DO') Then
  PPAdvance;

 LoopPush(LblEnd, LblTest);
 ParseStmt;
 LoopPop;

 EmitInstr('JMP ' + LblTest);
 EmitLabel(LblEnd);
End;

{ ------------------------------------------------------------ }
{ ParseRepeatStmt : REPEAT stmts UNTIL cond                      }
{ ------------------------------------------------------------ }

Procedure ParseRepeatStmt;
Var
 LblBeg, LblEnd : TString;
 SavePP : Integer;
Begin
 EmitComment('repeat');
 PPAdvance;   { repeat }

 LblBeg := LabelGen;
 LblEnd := LabelGen;
 EmitLabel(LblBeg);

 LoopPush(LblEnd, LblBeg);

 While Not PPAtEnd Do
 Begin
  If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'UNTIL') Then
   Break;
  SavePP := PP;
  ParseStmt;
  SkipOptSemi;
  If PP = SavePP Then PPAdvance;
 End;

 If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'UNTIL') Then
  PPAdvance;

 ParseExpr;
 EmitInstr('TEST EAX,EAX');
 EmitInstr('JZ ' + LblBeg);
 EmitLabel(LblEnd);

 LoopPop;
End;

{ ------------------------------------------------------------ }
{ ParseForStmt : FOR ident := lo TO|DOWNTO hi DO stmt            }
{ For..In (Delphi) est detecte mais non implemente (attend les   }
{ tableaux/chaines/ensembles iterables du TODO 19) : le corps     }
{ est parse (pour rester synchronise) mais aucune iteration       }
{ n est generee, avec un avertissement explicite.                 }
{ ------------------------------------------------------------ }

Procedure ParseForStmt;
Var
 VarName, LimLbl : TString;
 LblTest, LblEnd, LblCont : TString;
 IsDownTo : Boolean;
Begin
 EmitComment('for');
 PPAdvance;   { for }

 If PPPeekKind <> TK_IDENT Then
 Begin
  WarnMsg('for : identificateur de variable attendu');
  Exit;
 End;
 VarName := TokenPool[PP].Val;
 PPAdvance;

 If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'IN') Then
 Begin
  WarnMsg('for..in non encore implemente (attend TODO 19)');
  PPAdvance;
  ParseExpr;
  If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'DO') Then
   PPAdvance;
  ParseStmt;
  Exit;
 End;

 If Not ((PPPeekKind = TK_OP) And (PPPeekVal = ':=')) Then
 Begin
  WarnMsg('for : := attendu');
  Exit;
 End;
 PPAdvance;   { := }

 ParseExpr;
 GenStoreVar(VarName, 'EAX');

 IsDownTo := False;
 If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'TO') Then
  PPAdvance
 Else If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'DOWNTO') Then
 Begin
  IsDownTo := True;
  PPAdvance;
 End;

 ParseExpr;
 LimLbl := LabelGen;
 DataAdd(LimLbl, DK_DWORD, 0, '', 0, 0);
 EmitInstr('MOV DWORD PTR [' + LimLbl + '],EAX');

 LblTest := LabelGen;
 LblEnd  := LabelGen;
 LblCont := LabelGen;

 If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'DO') Then
  PPAdvance;

 EmitLabel(LblTest);
 GenLoadVar(VarName);
 EmitInstr('CMP EAX,DWORD PTR [' + LimLbl + ']');
 If IsDownTo Then EmitInstr('JL ' + LblEnd) Else EmitInstr('JG ' + LblEnd);

 LoopPush(LblEnd, LblCont);
 ParseStmt;
 LoopPop;

 EmitLabel(LblCont);
 GenLoadVar(VarName);
 If IsDownTo Then EmitInstr('DEC EAX') Else EmitInstr('INC EAX');
 GenStoreVar(VarName, 'EAX');
 EmitInstr('JMP ' + LblTest);
 EmitLabel(LblEnd);
End;

{ ------------------------------------------------------------ }
{ ParseCaseStmt : CASE expr OF val[,val...]: stmt; ... [ELSE     }
{ stmt; ...] END. Les valeurs litterales (entier/caractere) sont }
{ comparees directement ; toute autre expression est evaluee et  }
{ comparee dynamiquement. Plages val1..val2 supportees.           }
{ ------------------------------------------------------------ }

Procedure ParseCaseStmt;
Var
 LblEnd, LblNext, LblHit : TString;
 CaseVal, RangeHi : LongInt;
Begin
 EmitComment('case');
 PPAdvance;   { case }

 ParseExpr;
 EmitInstr('PUSH EAX');

 If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'OF') Then
  PPAdvance;

 LblEnd := LabelGen;

 While Not PPAtEnd Do
 Begin
  If (PPPeekKind = TK_KEYWORD) And
     ((StrUpperCase(PPPeekVal) = 'END') Or (StrUpperCase(PPPeekVal) = 'ELSE')) Then
   Break;
  If (PPPeekKind = TK_PUNCT) And (PPPeekVal = ';') Then
  Begin
   PPAdvance;
   Continue;
  End;

  LblNext := LabelGen;
  LblHit  := LabelGen;
  CaseVal := 0;

  While Not PPAtEnd Do
  Begin
   If (PPPeekKind = TK_PUNCT) And (PPPeekVal = ':') Then Break;

   If PPPeekKind = TK_INTEGER Then
   Begin
    CaseVal := TokenPool[PP].IntVal;
    PPAdvance;
   End
   Else If PPPeekKind = TK_CHAR Then
   Begin
    CaseVal := TokenPool[PP].IntVal;
    PPAdvance;
   End
   Else
   Begin
    ParseExpr;
    EmitInstr('MOV EBX,EAX');
    EmitInstr('MOV EAX,DWORD PTR [ESP]');
    EmitInstr('CMP EAX,EBX');
    EmitInstr('JE ' + LblHit);
    If (PPPeekKind = TK_PUNCT) And (PPPeekVal = ',') Then
    Begin
     PPAdvance;
     Continue;
    End
    Else
     Break;
   End;

   If (PPPeekKind = TK_PUNCT) And (PPPeekVal = '..') Then
   Begin
    PPAdvance;
    RangeHi := 0;
    If PPPeekKind = TK_INTEGER Then
    Begin
     RangeHi := TokenPool[PP].IntVal;
     PPAdvance;
    End;
    EmitInstr('MOV EAX,DWORD PTR [ESP]');
    EmitInstr('CMP EAX,' + IntToStr_(CaseVal));
    EmitInstr('JL ' + LblNext);
    EmitInstr('CMP EAX,' + IntToStr_(RangeHi));
    EmitInstr('JLE ' + LblHit);
    EmitInstr('JMP ' + LblNext);
   End
   Else
   Begin
    EmitInstr('MOV EAX,DWORD PTR [ESP]');
    EmitInstr('CMP EAX,' + IntToStr_(CaseVal));
    EmitInstr('JE ' + LblHit);
   End;

   If (PPPeekKind = TK_PUNCT) And (PPPeekVal = ',') Then
    PPAdvance
   Else
    Break;
  End;

  EmitInstr('JMP ' + LblNext);
  EmitLabel(LblHit);
  If (PPPeekKind = TK_PUNCT) And (PPPeekVal = ':') Then PPAdvance;
  ParseStmt;
  SkipOptSemi;
  EmitInstr('JMP ' + LblEnd);
  EmitLabel(LblNext);
 End;

 If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'ELSE') Then
 Begin
  PPAdvance;
  EmitComment('case else');
  While Not PPAtEnd Do
  Begin
   If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'END') Then
    Break;
   ParseStmt;
   SkipOptSemi;
  End;
 End;

 EmitLabel(LblEnd);
 EmitInstr('POP EAX');

 If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'END') Then
  PPAdvance;
End;

{ ------------------------------------------------------------ }
{ ParseTryStmt : Try..Finally / Try..Except..On E: Classe Do -   }
{ stub honnete (spec explicite : voir TODO 18) : le bloc entier  }
{ est ignore (aucun code de nettoyage/gestion d exception genere)}
{ mais le parseur reste synchronise grace a SkipToMatchingEnd.    }
{ ------------------------------------------------------------ }

Procedure ParseTryStmt;
Begin
 WarnMsg('try/except/finally non encore implemente (attend TODO 18) : ' +
  'bloc ignore');
 PPAdvance;   { try }
 SkipToMatchingEnd;
End;

{ ------------------------------------------------------------ }
{ ParseStmt : dispatch principal d une instruction. Implemente   }
{ ici l assignation (Ident := expr, et Ident.Champ := expr sur    }
{ une seule profondeur - une vraie notion de lvalue generale       }
{ (tableaux, chaines de champs profondes) attend TODO 15/19),     }
{ Break/Continue/Exit, et route vers les structures de controle   }
{ ci-dessus. Toute autre instruction (appel de procedure/fonction, }
{ ou expression dont la valeur est ignoree) passe par ParseExpr,   }
{ deja general grace aux TODO 09-12.                                }
{ ------------------------------------------------------------ }

Procedure ParseStmt;
Var
 Up, Name, FieldName : TString;
 SI, BaseTypeIdx, FI, First, Cnt : Integer;
 Found  : Boolean;
 DestOp : TString;
Begin
 If PPAtEnd Then Exit;

 If (PPPeekKind = TK_PUNCT) And (PPPeekVal = ';') Then Exit;
 If (PPPeekKind = TK_PUNCT) And (PPPeekVal = '.') Then Exit;

 If PPPeekKind = TK_KEYWORD Then
 Begin
  Up := StrUpperCase(PPPeekVal);

  If Up = 'END' Then Exit;
  If Up = 'UNTIL' Then Exit;
  If Up = 'ELSE' Then Exit;

  If Up = 'BEGIN' Then Begin ParseCompoundStmt; Exit; End;
  If Up = 'IF' Then Begin ParseIfStmt; Exit; End;
  If Up = 'WHILE' Then Begin ParseWhileStmt; Exit; End;
  If Up = 'REPEAT' Then Begin ParseRepeatStmt; Exit; End;
  If Up = 'FOR' Then Begin ParseForStmt; Exit; End;
  If Up = 'CASE' Then Begin ParseCaseStmt; Exit; End;
  If Up = 'TRY' Then Begin ParseTryStmt; Exit; End;

  WarnMsg('instruction non geree: ' + PPPeekVal);
  PPAdvance;
  Exit;
 End;

 If PPPeekKind = TK_IDENT Then
 Begin
  Name := TokenPool[PP].Val;
  Up   := StrUpperCase(Name);

  If Up = 'EXIT' Then
  Begin
   PPAdvance;
   If PPMatch('(') Then
   Begin
    If Not PPMatch(')') Then
    Begin
     ParseExpr;   { EAX = valeur de retour (convention EAX, TODO 10/14) }
     PPMatch(')');
    End;
   End;
   If CurRetLabel <> '' Then
    EmitInstr('JMP ' + CurRetLabel)
   Else
    WarnMsg('exit hors d un corps de procedure/fonction');
   Exit;
  End;

  If Up = 'BREAK' Then
  Begin
   PPAdvance;
   If LoopTop >= 0 Then
    EmitInstr('JMP ' + LoopBreakLbl[LoopTop])
   Else
    WarnMsg('break en dehors d une boucle');
   Exit;
  End;

  If Up = 'CONTINUE' Then
  Begin
   PPAdvance;
   If LoopTop >= 0 Then
    EmitInstr('JMP ' + LoopContLbl[LoopTop])
   Else
    WarnMsg('continue en dehors d une boucle');
   Exit;
  End;

  { Assignation simple : Ident := expr }
  If (PP + 1 < TokenCount) And (TokenPool[PP + 1].Kind = TK_OP) And
     (TokenPool[PP + 1].Val = ':=') Then
  Begin
   PPAdvance;   { ident }
   PPAdvance;   { := }
   ParseExpr;
   GenStoreVar(Name, 'EAX');
   Exit;
  End;

  { Assignation de champ, une seule profondeur : Ident.Champ := expr }
  If (PP + 1 < TokenCount) And (TokenPool[PP + 1].Kind = TK_PUNCT) And
     (TokenPool[PP + 1].Val = '.') And (PP + 3 < TokenCount) And
     (TokenPool[PP + 3].Kind = TK_OP) And (TokenPool[PP + 3].Val = ':=') Then
  Begin
   SI := SymFind(Name);
   If SI < 0 Then
   Begin
    WarnMsg('identificateur inconnu: ' + Name);
    PPAdvance; PPAdvance; PPAdvance; PPAdvance;
    ParseExpr;
    Exit;
   End;

   BaseTypeIdx := TypeResolve(SymTab[SI].TypeIdx);
   PPAdvance;                { ident }
   GenLoadVar(Name);          { EAX = reference/adresse de l objet }
   EmitInstr('MOV EBX,EAX');  { conserver pendant l evaluation du RHS }
   PPAdvance;                { . }
   FieldName := StrUpperCase(TokenPool[PP].Val);
   PPAdvance;                { champ }
   PPAdvance;                { := }

   Found := False;
   If (BaseTypeIdx >= 0) And (BaseTypeIdx < TypeCount) Then
   Begin
    First := TypeTab[BaseTypeIdx].FieldFirst;
    Cnt   := TypeTab[BaseTypeIdx].FieldCount;
    If First >= 0 Then
     For FI := First To First + Cnt - 1 Do
      If FieldPool[FI].Name = FieldName Then
      Begin
       Found := True;
       ParseExpr;   { EAX = valeur du membre droit }
       If TypeNeedsDestAddr(FieldPool[FI].TypeIdx) Then
       Begin
        If FieldPool[FI].Offset = 0 Then
         EmitInstr('MOV EDX,EBX')
        Else
         EmitInstr('LEA EDX,[EBX+' + IntToStr_(FieldPool[FI].Offset) + ']');
        EmitAssign('EDX', 'EAX', FieldPool[FI].TypeIdx);
       End
       Else
       Begin
        If FieldPool[FI].Offset = 0 Then
         DestOp := SizedPtr(FieldPool[FI].TypeIdx) + '[EBX]'
        Else
         DestOp := SizedPtr(FieldPool[FI].TypeIdx) + '[EBX+' +
          IntToStr_(FieldPool[FI].Offset) + ']';
        EmitAssign(DestOp, 'EAX', FieldPool[FI].TypeIdx);
       End;
       Break;
      End;
   End;

   If Not Found Then
   Begin
    WarnMsg('champ inconnu: ' + FieldName);
    ParseExpr;
   End;
   Exit;
  End;
 End;

 { Instruction-expression : appel de procedure/fonction, ou toute    }
 { autre expression dont la valeur resultante est ignoree.            }
 ParseExpr;
End;

{ ------------------------------------------------------------ }
{ StmtAssert / StmtSelfTest : verifient les structures de        }
{ controle (if/while/repeat/for/case, break/continue/exit,        }
{ assignation simple et de champ, try en stub) avec des suites    }
{ de tokens synthetiques, comme les self-tests des TODO           }
{ precedents.                                                      }
{ ------------------------------------------------------------ }

Procedure StmtAssert(Const Label_: TString; Cond: Boolean);
Begin
 If Not Cond Then
  FatalError('StmtSelfTest: ' + Label_ + ' a echoue');
End;

Procedure StmtSelfTest;
Const
 TmpFile = 'DPSTMTSELFTEST.$$$';
Var
 IntIdx : Integer;
 AnimalSymIdx, AnimalIdx, FAge : Integer;
 F : Text;
 Line : TString;
 Mov1Line, Mov2Line, LineNo : Integer;
 HasTest, HasJz, HasJmp, HasCmp1, HasCmp2 : Boolean;
 HasBreakJmp, HasContJmp, HasExitJmp, HasExit42, HasWriteStr : Boolean;
 HasFieldStore : Boolean;

 Procedure Tok(Kind: TTokenKind; Const Val: TString; IntVal: LongInt);
 Var T: TToken;
 Begin
  T.Kind := Kind; T.Val := Val; T.IntVal := IntVal; T.RealVal := 0.0;
  T.Line := 1; T.Col := 1;
  TokenPoolAdd(T);
 End;

Begin
 SymInit;
 DataInit; DataInit2;
 FrameInit;
 StmtInit;

 IntIdx := TypeFindByName('Integer');

 { --- If/Then/Else : ordre then-avant-else, JZ/JMP presents --- }
 GlobalVarDeclare('STMTCOND', IntIdx, 0);
 GlobalVarDeclare('STMTTARGET', IntIdx, 0);
 TokenPoolInit;
 Tok(TK_KEYWORD, 'if', 0);
 Tok(TK_IDENT, 'STMTCOND', 0);
 Tok(TK_KEYWORD, 'then', 0);
 Tok(TK_IDENT, 'STMTTARGET', 0);
 Tok(TK_OP, ':=', 0);
 Tok(TK_INTEGER, '1', 1);
 Tok(TK_KEYWORD, 'else', 0);
 Tok(TK_IDENT, 'STMTTARGET', 0);
 Tok(TK_OP, ':=', 0);
 Tok(TK_INTEGER, '2', 2);
 ParserInit;
 EmitOpen(TmpFile);
 ParseStmt;
 EmitClose('DPSTMTSELFTEST_END');
 StmtAssert('if/then/else consomme tous les tokens', PPAtEnd);

 HasTest := False; HasJz := False; HasJmp := False;
 Mov1Line := -1; Mov2Line := -1; LineNo := 0;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 StmtAssert('fichier de test (if) relisible', IOResult = 0);
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  Inc(LineNo);
  If Pos('TEST EAX,EAX', Line) > 0 Then HasTest := True;
  If Pos('JZ ', Line) > 0 Then HasJz := True;
  If Pos('JMP ', Line) > 0 Then HasJmp := True;
  If (Mov1Line < 0) And (Pos('MOV EAX,1', Line) > 0) Then Mov1Line := LineNo;
  If (Mov2Line < 0) And (Pos('MOV EAX,2', Line) > 0) Then Mov2Line := LineNo;
 End;
 Close(F); Erase(F);
 StmtAssert('if emet un test de condition (TEST EAX,EAX)', HasTest);
 StmtAssert('if emet un saut conditionnel (JZ)', HasJz);
 StmtAssert('if/else emet un saut de fin de branche (JMP)', HasJmp);
 StmtAssert('la branche then (1) precede la branche else (2)',
  (Mov1Line >= 0) And (Mov2Line >= 0) And (Mov1Line < Mov2Line));

 { --- While : test de condition + retour arriere --- }
 TokenPoolInit;
 Tok(TK_KEYWORD, 'while', 0);
 Tok(TK_IDENT, 'STMTCOND', 0);
 Tok(TK_KEYWORD, 'do', 0);
 Tok(TK_IDENT, 'STMTTARGET', 0);
 Tok(TK_OP, ':=', 0);
 Tok(TK_INTEGER, '3', 3);
 ParserInit;
 EmitOpen(TmpFile);
 ParseStmt;
 EmitClose('DPSTMTSELFTEST_END');
 StmtAssert('while consomme tous les tokens', PPAtEnd);

 HasTest := False; HasJz := False; HasJmp := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('TEST EAX,EAX', Line) > 0 Then HasTest := True;
  If Pos('JZ ', Line) > 0 Then HasJz := True;
  If Pos('JMP ', Line) > 0 Then HasJmp := True;
 End;
 Close(F); Erase(F);
 StmtAssert('while emet un test de condition', HasTest);
 StmtAssert('while emet un saut de sortie (JZ)', HasJz);
 StmtAssert('while emet un retour au test (JMP)', HasJmp);

 { --- Case : comparaisons des valeurs litterales --- }
 TokenPoolInit;
 Tok(TK_KEYWORD, 'case', 0);
 Tok(TK_IDENT, 'STMTCOND', 0);
 Tok(TK_KEYWORD, 'of', 0);
 Tok(TK_INTEGER, '1', 1);
 Tok(TK_PUNCT, ':', 0);
 Tok(TK_IDENT, 'STMTTARGET', 0);
 Tok(TK_OP, ':=', 0);
 Tok(TK_INTEGER, '10', 10);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_INTEGER, '2', 2);
 Tok(TK_PUNCT, ':', 0);
 Tok(TK_IDENT, 'STMTTARGET', 0);
 Tok(TK_OP, ':=', 0);
 Tok(TK_INTEGER, '20', 20);
 Tok(TK_KEYWORD, 'end', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParseStmt;
 EmitClose('DPSTMTSELFTEST_END');
 StmtAssert('case consomme tous les tokens', PPAtEnd);

 HasCmp1 := False; HasCmp2 := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CMP EAX,1', Line) > 0 Then HasCmp1 := True;
  If Pos('CMP EAX,2', Line) > 0 Then HasCmp2 := True;
 End;
 Close(F); Erase(F);
 StmtAssert('case compare a la 1ere valeur litterale', HasCmp1);
 StmtAssert('case compare a la 2e valeur litterale', HasCmp2);

 { --- Break / Continue : sautent vers les labels de la boucle active --- }
 LoopPush('STMTBREAKLBL', 'STMTCONTLBL');
 TokenPoolInit;
 Tok(TK_IDENT, 'Break', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParseStmt;
 EmitClose('DPSTMTSELFTEST_END');
 HasBreakJmp := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('JMP STMTBREAKLBL', Line) > 0 Then HasBreakJmp := True;
 End;
 Close(F); Erase(F);
 StmtAssert('break saute vers le label de sortie de la boucle active',
  HasBreakJmp);

 TokenPoolInit;
 Tok(TK_IDENT, 'Continue', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParseStmt;
 EmitClose('DPSTMTSELFTEST_END');
 HasContJmp := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('JMP STMTCONTLBL', Line) > 0 Then HasContJmp := True;
 End;
 Close(F); Erase(F);
 StmtAssert('continue saute vers le label de continuation de la boucle',
  HasContJmp);
 LoopPop;

 { --- Exit / Exit(N) : saute vers le label de retour courant --- }
 CurRetLabel := 'STMTRETLBL';
 TokenPoolInit;
 Tok(TK_IDENT, 'Exit', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParseStmt;
 EmitClose('DPSTMTSELFTEST_END');
 HasExitJmp := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('JMP STMTRETLBL', Line) > 0 Then HasExitJmp := True;
 End;
 Close(F); Erase(F);
 StmtAssert('exit saute vers le label de retour courant', HasExitJmp);

 TokenPoolInit;
 Tok(TK_IDENT, 'Exit', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_INTEGER, '42', 42);
 Tok(TK_PUNCT, ')', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParseStmt;
 EmitClose('DPSTMTSELFTEST_END');
 HasExit42 := False; HasExitJmp := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('MOV EAX,42', Line) > 0 Then HasExit42 := True;
  If Pos('JMP STMTRETLBL', Line) > 0 Then HasExitJmp := True;
 End;
 Close(F); Erase(F);
 StmtAssert('exit(42) charge 42 dans EAX (convention valeur de retour)',
  HasExit42);
 StmtAssert('exit(42) saute ensuite vers le label de retour', HasExitJmp);
 CurRetLabel := '';

 { --- Assignation de champ (une profondeur) : Ident.Champ := expr --- }
 { Age est le premier champ d une classe racine : offset 4, l offset  }
 { 0 etant reserve au pointeur de VMT (TODO 15).                       }
 AnimalSymIdx := SymDeclareClass('TANIMALSTMT', SK_CLASS, -1);
 AnimalIdx    := SymTab[AnimalSymIdx].TypeIdx;
 FieldInitInherit(AnimalIdx);
 FAge := TypeAddField(AnimalIdx, 'AGE', IntIdx);
 GlobalVarDeclare('REXSTMT', AnimalIdx, 0);

 TokenPoolInit;
 Tok(TK_IDENT, 'RexStmt', 0);
 Tok(TK_PUNCT, '.', 0);
 Tok(TK_IDENT, 'Age', 0);
 Tok(TK_OP, ':=', 0);
 Tok(TK_INTEGER, '9', 9);
 ParserInit;
 EmitOpen(TmpFile);
 ParseStmt;
 EmitClose('DPSTMTSELFTEST_END');
 StmtAssert('affectation de champ consomme tous les tokens', PPAtEnd);

 HasFieldStore := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If (Pos('MOV EAX,9', Line) > 0) Then HasFieldStore := True;
  If (Pos('DWORD PTR [EBX+4]', Line) > 0) And (Pos(',EAX', Line) > 0) Then
   HasFieldStore := True;
 End;
 Close(F); Erase(F);
 StmtAssert('RexStmt.Age := 9 stocke a l offset du champ', HasFieldStore);
 StmtAssert('champ Age a l offset 4 (0 reserve au pointeur de VMT)',
  FieldPool[FAge].Offset = 4);

 { --- Try : bloc entierement ignore, mais parseur synchronise --- }
 TokenPoolInit;
 Tok(TK_KEYWORD, 'try', 0);
 Tok(TK_IDENT, 'WriteLn', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_STRING, 'x', 0);
 Tok(TK_PUNCT, ')', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'finally', 0);
 Tok(TK_IDENT, 'WriteLn', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_STRING, 'y', 0);
 Tok(TK_PUNCT, ')', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'end', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParseStmt;
 EmitClose('DPSTMTSELFTEST_END');
 StmtAssert('try consomme tout le bloc jusqu au END correspondant', PPAtEnd);

 HasWriteStr := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL ' + DPRT_WRITESTR, Line) > 0 Then HasWriteStr := True;
 End;
 Close(F); Erase(F);
 StmtAssert('try (stub) n execute pas le contenu du bloc',
  Not HasWriteStr);

 SymInit;
 DataInit; DataInit2;
 FrameInit;
 StmtInit;
End;

{ ============================================================ }
{ TODO 14 - PROCEDURES, FONCTIONS ET SURCHARGE       [IMPLEMENTE] }
{ ============================================================ }

Const
 MAX_PARAM_GROUP  = 16;   { noms partageant un meme type dans un      }
                           { groupe de parametres, ex: (A, B: Integer)}
 MAX_USER_EXTERN  = 64;   { imports EXTRN declares par le code source }

Var
 { Imports EXTRN declares par des 'external' utilisateur (DLL), a    }
 { emettre en tete du fichier .ASM comme ceux du TODO 07. Le nom de  }
 { la DLL (s il est fourni) est conserve a part, en commentaire       }
 { seulement : il ne doit jamais se retrouver dans la ligne EXTRN     }
 { elle-meme, qui exige un type (':NEAR') apres le nom.                }
 UserExternNames   : Array[0..MAX_USER_EXTERN - 1] Of TString;
 UserExternDllName : Array[0..MAX_USER_EXTERN - 1] Of TString;
 UserExternCount   : Integer;

Procedure UserExternInit;
Begin
 UserExternCount := 0;
End;

Procedure UserExternAdd(Const ExternName: TString; Const DllName: TString);
Begin
 If UserExternCount >= MAX_USER_EXTERN Then
 Begin
  WarnMsg('table des imports externes pleine (MAX_USER_EXTERN=' +
   IntToStr_(MAX_USER_EXTERN) + ')');
  Exit;
 End;
 UserExternNames[UserExternCount]   := ExternName;
 UserExternDllName[UserExternCount] := DllName;
 Inc(UserExternCount);
End;

{ ------------------------------------------------------------ }
{ EmitUserExterns : emettre les EXTRN des DLL declarees par le   }
{ code source ('external', voir ParseProcOrFuncDecl plus bas).   }
{ Appele juste apres EmitHeader (TODO 07), dans le meme esprit    }
{ que ses propres imports Win32 de base.                          }
{ ------------------------------------------------------------ }

Procedure EmitUserExterns;
Var I: Integer;
Begin
 If UserExternCount = 0 Then Exit;
 EmitComment('--- Imports externes declares par le source (''external'') ---');
 For I := 0 To UserExternCount - 1 Do
 Begin
  If UserExternDllName[I] <> '' Then
   EmitComment(UserExternNames[I] + ' -> ' + UserExternDllName[I]);
  EmitRaw('EXTRN ' + UserExternNames[I] + ':NEAR');
 End;
 EmitBlankLine;
End;

{ ------------------------------------------------------------ }
{ SymAddForce : comme SymAdd (TODO 05), mais sans verification   }
{ de doublon - reserve a la surcharge de procedures/fonctions    }
{ (TODO 14), ou plusieurs symboles portant intentionnellement le }
{ meme nom doivent coexister dans la meme portee. ProcDeclare,    }
{ ci-dessous, est seul responsable de decider quand l utiliser.   }
{ ------------------------------------------------------------ }

Function SymAddForce(Const Name: TString; Kind: TSymKind; TIdx: Integer): Integer;
Var Up: TString;
Begin
 If SymCount >= MAX_SYM Then
 Begin
  WarnMsg('table des symboles pleine (MAX_SYM=' + IntToStr_(MAX_SYM) + ')');
  SymAddForce := -1;
  Exit;
 End;

 Up := StrUpperCase(Name);
 SymTab[SymCount].Name           := Up;
 SymTab[SymCount].MangledName    := SymMangle(Up, Kind);
 SymTab[SymCount].Kind           := Kind;
 SymTab[SymCount].TypeIdx        := TIdx;
 SymTab[SymCount].Offset         := 0;
 SymTab[SymCount].ScopeLevel     := CurScopeLevel;
 SymTab[SymCount].ScopeId        := CurScopeId;
 SymTab[SymCount].IsGlobal       := (CurScopeLevel = 0);
 SymTab[SymCount].IsExternal     := False;
 SymTab[SymCount].UnitName       := '';
 SymTab[SymCount].ImmVal         := 0;
 SymTab[SymCount].ParamCount     := 0;
 SymTab[SymCount].ParentClassIdx := -1;
 SymTab[SymCount].MemberScopeId  := -1;
 SymTab[SymCount].ParamKind      := PK_VALUE;
 SymTab[SymCount].IsSealed       := False;
 SymTab[SymCount].IsConstructor  := False;
 SymTab[SymCount].IsClassMethod  := False;

 SymAddForce := SymCount;
 Inc(SymCount);
End;

{ ------------------------------------------------------------ }
{ MangledNameInUse : un autre symbole (que ExceptIdx) utilise-t-il}
{ deja ce nom mangled ? Sert a donner un suffixe disambiguant aux }
{ surcharges (memes SymMangle par defaut pour toutes), TODO 14.   }
{ ------------------------------------------------------------ }

Function MangledNameInUse(Const MName: TString; ExceptIdx: Integer): Boolean;
Var I: Integer;
Begin
 MangledNameInUse := False;
 For I := 0 To SymCount - 1 Do
  If (I <> ExceptIdx) And (SymTab[I].MangledName = MName) Then
  Begin
   MangledNameInUse := True;
   Exit;
  End;
End;

{ ------------------------------------------------------------ }
{ ProcDeclare : enregistrer le symbole d une procedure/fonction. }
{ Reutilise une declaration FORWARD/EXTERNAL existante dans la    }
{ portee courante si elle correspond (meme mecanisme que SymAdd  }
{ pour les autres symboles) ; sinon, cree TOUJOURS un nouveau     }
{ symbole (SymAddForce) plutot que de signaler un doublon, pour   }
{ permettre la surcharge (plusieurs procedures/fonctions de meme  }
{ nom, distinguees par leur nombre de parametres - voir            }
{ SymFindOverload).                                                }
{ ------------------------------------------------------------ }

Function ProcDeclare(Const Name: TString; IsFunc: Boolean): Integer;
Var
 Up    : TString;
 I     : Integer;
 Found : Integer;
 Kind  : TSymKind;
Begin
 If IsFunc Then Kind := SK_FUNC Else Kind := SK_PROC;
 Up := StrUpperCase(Name);
 Found := -1;
 For I := SymCount - 1 DownTo 0 Do
  If (SymTab[I].Name = Up) And (SymTab[I].ScopeId = CurScopeId) And
     (SymTab[I].Kind In [SK_PROC, SK_FUNC]) And SymTab[I].IsExternal Then
  Begin
   Found := I;
   Break;
  End;

 If Found >= 0 Then
 Begin
  SymTab[Found].Kind       := Kind;
  SymTab[Found].IsExternal := False;
  ProcDeclare := Found;
 End
 Else
  ProcDeclare := SymAddForce(Name, Kind, -1);
End;

{ ------------------------------------------------------------ }
{ SymFindOverload : resoudre un appel a Name vers le symbole      }
{ SK_PROC/SK_FUNC dont le nombre de parametres correspond a       }
{ ArgCount. Simplification documentee (TODO 14) : la resolution   }
{ se fait par ARITE seulement, pas par type des arguments ; en    }
{ l absence de correspondance exacte, le premier symbole visible   }
{ portant ce nom sert de repli (comportement pre-TODO 14).         }
{ ------------------------------------------------------------ }

Function SymFindOverload(Const Name: TString; ArgCount: Integer): Integer;
Var
 Up   : TString;
 I    : Integer;
 Best : Integer;
Begin
 Up   := StrUpperCase(Name);
 Best := -1;
 For I := SymCount - 1 DownTo 0 Do
  If (SymTab[I].Name = Up) And (SymTab[I].Kind In [SK_PROC, SK_FUNC]) And
     (SymTab[I].IsGlobal Or ScopeIdActive(SymTab[I].ScopeId)) Then
  Begin
   If Best < 0 Then Best := I;
   If SymTab[I].ParamCount = ArgCount Then
   Begin
    SymFindOverload := I;
    Exit;
   End;
  End;
 SymFindOverload := Best;
End;

{ ------------------------------------------------------------ }
{ PeekArgCount : compter les arguments d un eventuel appel        }
{ '(' expr [, expr...] ')' commencant a la position courante,     }
{ sans rien consommer (utilise par SymFindOverload avant de       }
{ choisir quel symbole appeler). 0 si aucune parenthese ne suit.   }
{ ------------------------------------------------------------ }

Function PeekArgCount: Integer;
Var
 SavePP, Depth, Count : Integer;
Begin
 SavePP := PP;
 PeekArgCount := 0;
 If Not ((PPPeekKind = TK_PUNCT) And (PPPeekVal = '(')) Then Exit;
 PPAdvance;
 If (PPPeekKind = TK_PUNCT) And (PPPeekVal = ')') Then
 Begin
  PP := SavePP;
  Exit;
 End;
 Count := 1;
 Depth := 0;
 While Not PPAtEnd Do
 Begin
  If (PPPeekVal = '(') Or (PPPeekVal = '[') Then
   Inc(Depth)
  Else If (PPPeekVal = ')') Or (PPPeekVal = ']') Then
  Begin
   If Depth = 0 Then Break;
   Dec(Depth);
  End
  Else If (PPPeekVal = ',') And (Depth = 0) Then
   Inc(Count);
  PPAdvance;
 End;
 PP := SavePP;
 PeekArgCount := Count;
End;

{ Forward declarations : une procedure/fonction imbriquee (TODO 14)  }
{ apparait dans la meme position qu une section de declarations       }
{ locales - ParseProcOrFuncDecl et ParseDeclSection s appellent donc  }
{ mutuellement.                                                        }
Procedure ParseProcOrFuncDecl; Forward;

{ ------------------------------------------------------------ }
{ ParseDeclSection : sections Var (locales, TODO 09) et          }
{ procedures/fonctions imbriquees (TODO 14), dans n importe quel  }
{ ordre et repetees, jusqu a BEGIN. Les sections Const/Type       }
{ locales sont reconnues mais pas encore gerees (avertissement +  }
{ saut jusqu a la prochaine section reconnue, sans tenter de les   }
{ interpreter comme instructions).                                 }
{ ------------------------------------------------------------ }

Procedure ParseDeclSection;
Var
 Up    : TString;
 Names : Array[0..MAX_PARAM_GROUP - 1] Of TString;
 NCount, I, TIdx : Integer;
 TName : TString;
Begin
 While PPPeekKind = TK_KEYWORD Do
 Begin
  Up := StrUpperCase(PPPeekVal);

  If (Up = 'PROCEDURE') Or (Up = 'FUNCTION') Then
  Begin
   ParseProcOrFuncDecl;
   Continue;
  End;

  If (Up = 'CONST') Or (Up = 'TYPE') Then
  Begin
   WarnMsg('sections locales ' + Up + ' non encore gerees : ignorees');
   PPAdvance;
   While (Not PPAtEnd) And
         (Not ((PPPeekKind = TK_KEYWORD) And
               ((StrUpperCase(PPPeekVal) = 'VAR') Or
                (StrUpperCase(PPPeekVal) = 'BEGIN') Or
                (StrUpperCase(PPPeekVal) = 'CONST') Or
                (StrUpperCase(PPPeekVal) = 'TYPE') Or
                (StrUpperCase(PPPeekVal) = 'PROCEDURE') Or
                (StrUpperCase(PPPeekVal) = 'FUNCTION')))) Do
    PPAdvance;
   Continue;
  End;

  If Up <> 'VAR' Then Break;

  PPAdvance;   { var }
  While PPPeekKind = TK_IDENT Do
  Begin
   NCount := 0;
   Repeat
    If NCount < MAX_PARAM_GROUP Then
    Begin
     Names[NCount] := TokenPool[PP].Val;
     Inc(NCount);
    End;
    PPAdvance;
   Until Not PPMatch(',');

   PPMatch(':');
   TIdx := TypeFindByName('Integer');
   If PPPeekKind In [TK_IDENT, TK_KEYWORD] Then
   Begin
    TName := TokenPool[PP].Val;
    PPAdvance;
    TIdx := TypeFindByName(TName);
    If TIdx < 0 Then TIdx := TypeFindByName('Integer');
   End;

   For I := 0 To NCount - 1 Do LocalAdd(Names[I], TIdx);
   SkipOptSemi;
  End;
 End;
End;

{ ------------------------------------------------------------ }
{ ParseProcOrFuncDecl : PROCEDURE|FUNCTION Nom(params)[: Type];  }
{ [directives] ; (corps | forward | external ...).                }
{ ------------------------------------------------------------ }

Procedure ParseProcOrFuncDecl;
Var
 IsFunc            : Boolean;
 Name, Up, TName   : TString;
 ProcSymIdx        : Integer;
 RetTypeIdx        : Integer;
 SavedRetLabel     : TString;
 SavedFrameOffset, SavedParamOffset : Integer;
 MyRetLabel        : TString;
 IsForwardOnly, IsExternalOnly : Boolean;
 DllName, ExportName : TString;
 ResultIdx, AliasIdx : Integer;
 ParamNames        : Array[0..MAX_PARAM_GROUP - 1] Of TString;
 ParamCountLocal, GI, I : Integer;
 PKind             : TParamKind;
 PTypeIdx          : Integer;
 Suffix            : Integer;
 CandidateMangled  : TString;
Begin
 IsFunc := (StrUpperCase(PPPeekVal) = 'FUNCTION');
 PPAdvance;   { procedure|function }

 If PPPeekKind <> TK_IDENT Then
 Begin
  WarnMsg('nom de procedure/fonction attendu');
  Exit;
 End;
 Name := TokenPool[PP].Val;
 PPAdvance;

 ProcSymIdx := ProcDeclare(Name, IsFunc);

 SavedRetLabel    := CurRetLabel;
 SavedFrameOffset := CurFrameOffset;
 SavedParamOffset := CurParamOffset;

 SymEnterScope;
 FrameInit;
 ParamCountLocal := 0;

 { --- Liste de parametres --- }
 If PPMatch('(') Then
 Begin
  If Not PPMatch(')') Then
  Begin
   Repeat
    PKind := PK_VALUE;
    If PPPeekKind = TK_KEYWORD Then
    Begin
     Up := StrUpperCase(PPPeekVal);
     If Up = 'VAR' Then Begin PKind := PK_VAR; PPAdvance; End
     Else If Up = 'CONST' Then Begin PKind := PK_CONST; PPAdvance; End
     Else If Up = 'OUT' Then Begin PKind := PK_OUT; PPAdvance; End;
    End;

    GI := 0;
    Repeat
     If GI < MAX_PARAM_GROUP Then
     Begin
      ParamNames[GI] := TokenPool[PP].Val;
      Inc(GI);
     End;
     PPAdvance;
    Until Not PPMatch(',');

    PTypeIdx := TypeFindByName('Integer');
    If PPMatch(':') Then
    Begin
     TName := TokenPool[PP].Val;
     PPAdvance;
     PTypeIdx := TypeFindByName(TName);
     If PTypeIdx < 0 Then PTypeIdx := TypeFindByName('Integer');
    End;

    { Valeur par defaut : analysee (pour ne pas desynchroniser le     }
    { parseur) mais pas encore utilisee pour completer un appel avec  }
    { moins d arguments que de parametres declares - limitation        }
    { documentee (TODO 14).                                             }
    If PPMatch('=') Then ParseExpr;

    For I := 0 To GI - 1 Do
    Begin
     ParamAdd(ParamNames[I], PTypeIdx, PKind);
     Inc(ParamCountLocal);
    End;
   Until Not PPMatch(';');
   PPMatch(')');
  End;
 End;

 RetTypeIdx := TypeFindByName('Integer');
 If IsFunc And PPMatch(':') Then
 Begin
  TName := TokenPool[PP].Val;
  PPAdvance;
  RetTypeIdx := TypeFindByName(TName);
  If RetTypeIdx < 0 Then RetTypeIdx := TypeFindByName('Integer');
 End;

 SymTab[ProcSymIdx].TypeIdx    := RetTypeIdx;
 SymTab[ProcSymIdx].ParamCount := ParamCountLocal;

 { Desambiguer le nom mangled si une autre surcharge l utilise deja  }
 { (SymMangle donne le meme nom par defaut a tous les homonymes).    }
 If MangledNameInUse(SymTab[ProcSymIdx].MangledName, ProcSymIdx) Then
 Begin
  Suffix := 2;
  CandidateMangled := SymTab[ProcSymIdx].MangledName + '_' + IntToStr_(Suffix);
  While MangledNameInUse(CandidateMangled, ProcSymIdx) Do
  Begin
   Inc(Suffix);
   CandidateMangled := SymTab[ProcSymIdx].MangledName + '_' + IntToStr_(Suffix);
  End;
  SymTab[ProcSymIdx].MangledName := CandidateMangled;
 End;

 PPMatch(';');

 { --- Directives : forward / external / overload / conventions --- }
 IsForwardOnly  := False;
 IsExternalOnly := False;
 DllName        := '';
 ExportName     := Name;
 While PPPeekKind = TK_IDENT Do
 Begin
  Up := StrUpperCase(PPPeekVal);
  If Up = 'FORWARD' Then
  Begin
   IsForwardOnly := True;
   PPAdvance;
   PPMatch(';');
  End
  Else If Up = 'EXTERNAL' Then
  Begin
   IsExternalOnly := True;
   PPAdvance;
   If PPPeekKind = TK_STRING Then
   Begin
    DllName := TokenPool[PP].Val;
    PPAdvance;
   End;
   If (PPPeekKind = TK_IDENT) And (StrUpperCase(PPPeekVal) = 'NAME') Then
   Begin
    PPAdvance;
    If PPPeekKind = TK_STRING Then
    Begin
     ExportName := TokenPool[PP].Val;
     PPAdvance;
    End;
   End;
   PPMatch(';');
  End
  Else If (Up = 'OVERLOAD') Or (Up = 'REGISTER') Or (Up = 'STDCALL') Or
          (Up = 'CDECL') Or (Up = 'PASCAL') Or (Up = 'SAFECALL') Or
          (Up = 'INLINE') Then
  Begin
   { Reconnues syntaxiquement ; une seule convention d appel (cdecl-  }
   { like, nettoyage par l appelant, TODO 07/10) est utilisee pour     }
   { l instant, quelle que soit la directive - limitation documentee. }
   PPAdvance;
   PPMatch(';');
  End
  Else
   Break;
 End;

 If IsExternalOnly Then
 Begin
  SymTab[ProcSymIdx].MangledName := '_' + ExportName + '@' +
   IntToStr_(ParamCountLocal * 4);
  SymTab[ProcSymIdx].IsExternal := True;
  UserExternAdd(SymTab[ProcSymIdx].MangledName, DllName);
  SymLeaveScope;
  CurRetLabel    := SavedRetLabel;
  CurFrameOffset := SavedFrameOffset;
  CurParamOffset := SavedParamOffset;
  Exit;
 End;

 If IsForwardOnly Then
 Begin
  SymTab[ProcSymIdx].IsExternal := True;
  SymLeaveScope;
  CurRetLabel    := SavedRetLabel;
  CurFrameOffset := SavedFrameOffset;
  CurParamOffset := SavedParamOffset;
  Exit;
 End;

 { --- Corps reel --- }
 MyRetLabel  := LabelGen;
 CurRetLabel := MyRetLabel;

 If IsFunc Then
 Begin
  ResultIdx := LocalAdd('RESULT', RetTypeIdx);
  If ResultIdx >= 0 Then
  Begin
   AliasIdx := SymAdd(Name, SK_VAR, RetTypeIdx);
   If AliasIdx >= 0 Then SymTab[AliasIdx].Offset := SymTab[ResultIdx].Offset;
  End;
 End;

 ParseDeclSection;   { var locales + procedures/fonctions imbriquees }

 EmitBlankLine;
 EmitLabel(SymTab[ProcSymIdx].MangledName);
 EmitProlog(-CurFrameOffset);

 If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'BEGIN') Then
  ParseCompoundStmt
 Else
  WarnMsg('begin attendu pour le corps de ' + Name);

 SkipOptSemi;

 EmitLabel(MyRetLabel);
 If IsFunc Then GenLoadVar('RESULT');
 EmitEpilog;

 SymLeaveScope;
 CurRetLabel    := SavedRetLabel;
 CurFrameOffset := SavedFrameOffset;
 CurParamOffset := SavedParamOffset;
End;

{ ------------------------------------------------------------ }
{ ProcAssert / ProcSelfTest : verifient la declaration de        }
{ procedures/fonctions (parametres, Result, forward, external,   }
{ surcharge par arite, imbrication) avec des suites de tokens     }
{ synthetiques, comme les self-tests des TODO precedents.         }
{ ------------------------------------------------------------ }

Procedure ProcAssert(Const Label_: TString; Cond: Boolean);
Begin
 If Not Cond Then
  FatalError('ProcSelfTest: ' + Label_ + ' a echoue');
End;

Procedure ProcSelfTest;
Const
 TmpFile = 'DPPROCSELFTEST.$$$';
Var
 FooSym1, FooSym2, I, InterneSymIdx : Integer;
 F : Text;
 Line : TString;
 HasProlog, HasEpilog, HasResultLoad, HasCallFoo1, HasCallFoo2 : Boolean;
 HasExtrn, HasCallExternal, HasNestedCall : Boolean;

 Procedure Tok(Kind: TTokenKind; Const Val: TString; IntVal: LongInt);
 Var T: TToken;
 Begin
  T.Kind := Kind; T.Val := Val; T.IntVal := IntVal; T.RealVal := 0.0;
  T.Line := 1; T.Col := 1;
  TokenPoolAdd(T);
 End;

Begin
 SymInit;
 DataInit; DataInit2;
 FrameInit;
 StmtInit;
 UserExternInit;

 { --- Fonction simple avec Result, appelee via son propre nom --- }
 { function Carre(N: Integer): Integer; begin Carre := N * N; end; }
 TokenPoolInit;
 Tok(TK_KEYWORD, 'function', 0);
 Tok(TK_IDENT, 'Carre', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_IDENT, 'N', 0);
 Tok(TK_PUNCT, ':', 0);
 Tok(TK_IDENT, 'Integer', 0);
 Tok(TK_PUNCT, ')', 0);
 Tok(TK_PUNCT, ':', 0);
 Tok(TK_IDENT, 'Integer', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'begin', 0);
 Tok(TK_IDENT, 'Carre', 0);
 Tok(TK_OP, ':=', 0);
 Tok(TK_IDENT, 'N', 0);
 Tok(TK_OP, '*', 0);
 Tok(TK_IDENT, 'N', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'end', 0);
 Tok(TK_PUNCT, ';', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParseProcOrFuncDecl;
 EmitClose('DPPROCSELFTEST_END');
 ProcAssert('declaration de fonction consomme tous les tokens', PPAtEnd);

 HasProlog := False; HasEpilog := False; HasResultLoad := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 ProcAssert('fichier de test (fonction) relisible', IOResult = 0);
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('PUSH EBP', Line) > 0 Then HasProlog := True;
  If Pos('POP EBP', Line) > 0 Then HasEpilog := True;
  If Pos('MOV EAX,DWORD PTR [EBP-4]', Line) > 0 Then HasResultLoad := True;
 End;
 Close(F); Erase(F);
 ProcAssert('la fonction emet un prologue (PUSH EBP)', HasProlog);
 ProcAssert('la fonction emet un epilogue (POP EBP)', HasEpilog);
 ProcAssert('Carre := ... charge bien le resultat via l alias Result ' +
  '(EBP-4)', HasResultLoad);

 { --- Surcharge : Foo(Integer) et Foo(Integer, Integer) --- }
 { procedure Foo(A: Integer); begin end;                     }
 { procedure Foo(A, B: Integer); begin end;                  }
 TokenPoolInit;
 Tok(TK_KEYWORD, 'procedure', 0);
 Tok(TK_IDENT, 'Foo', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_IDENT, 'A', 0);
 Tok(TK_PUNCT, ':', 0);
 Tok(TK_IDENT, 'Integer', 0);
 Tok(TK_PUNCT, ')', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'begin', 0);
 Tok(TK_KEYWORD, 'end', 0);
 Tok(TK_PUNCT, ';', 0);
 ParserInit;
 ParseProcOrFuncDecl;
 ProcAssert('1ere surcharge de Foo consomme tous les tokens', PPAtEnd);
 FooSym1 := SymFindOverload('Foo', 1);
 ProcAssert('Foo/1 trouvee par arite', FooSym1 >= 0);
 ProcAssert('Foo/1 a bien 1 parametre', SymTab[FooSym1].ParamCount = 1);

 TokenPoolInit;
 Tok(TK_KEYWORD, 'procedure', 0);
 Tok(TK_IDENT, 'Foo', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_IDENT, 'A', 0);
 Tok(TK_PUNCT, ',', 0);
 Tok(TK_IDENT, 'B', 0);
 Tok(TK_PUNCT, ':', 0);
 Tok(TK_IDENT, 'Integer', 0);
 Tok(TK_PUNCT, ')', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'begin', 0);
 Tok(TK_KEYWORD, 'end', 0);
 Tok(TK_PUNCT, ';', 0);
 ParserInit;
 ParseProcOrFuncDecl;
 ProcAssert('2e surcharge de Foo consomme tous les tokens', PPAtEnd);
 FooSym2 := SymFindOverload('Foo', 2);
 ProcAssert('Foo/2 trouvee par arite', FooSym2 >= 0);
 ProcAssert('Foo/2 a bien 2 parametres', SymTab[FooSym2].ParamCount = 2);
 ProcAssert('Foo/1 et Foo/2 ont des noms mangled distincts',
  SymTab[FooSym1].MangledName <> SymTab[FooSym2].MangledName);

 { Appeler Foo(1) puis Foo(1,2) : chacun doit cibler SA surcharge }
 TokenPoolInit;
 Tok(TK_IDENT, 'Foo', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_INTEGER, '1', 1);
 Tok(TK_PUNCT, ')', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPPROCSELFTEST_END');
 HasCallFoo1 := False; HasCallFoo2 := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  { Egalite EXACTE, pas Pos() : le nom mangled de Foo/1 (ex. _DPF_FOO) }
  { est un prefixe litteral de celui de Foo/2 (ex. _DPF_FOO_2), donc   }
  { une recherche de sous-chaine donnerait un faux positif.            }
  If Line = '        CALL ' + SymTab[FooSym1].MangledName Then HasCallFoo1 := True;
  If Line = '        CALL ' + SymTab[FooSym2].MangledName Then HasCallFoo2 := True;
 End;
 Close(F); Erase(F);
 ProcAssert('Foo(1) appelle la surcharge a 1 parametre', HasCallFoo1);
 ProcAssert('Foo(1) n appelle pas la surcharge a 2 parametres', Not HasCallFoo2);

 TokenPoolInit;
 Tok(TK_IDENT, 'Foo', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_INTEGER, '1', 1);
 Tok(TK_PUNCT, ',', 0);
 Tok(TK_INTEGER, '2', 2);
 Tok(TK_PUNCT, ')', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPPROCSELFTEST_END');
 HasCallFoo1 := False; HasCallFoo2 := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Line = '        CALL ' + SymTab[FooSym1].MangledName Then HasCallFoo1 := True;
  If Line = '        CALL ' + SymTab[FooSym2].MangledName Then HasCallFoo2 := True;
 End;
 Close(F); Erase(F);
 ProcAssert('Foo(1,2) appelle la surcharge a 2 parametres', HasCallFoo2);
 ProcAssert('Foo(1,2) n appelle pas la surcharge a 1 parametre', Not HasCallFoo1);

 { --- Forward puis corps reel : meme symbole, meme nom mangled --- }
 TokenPoolInit;
 Tok(TK_KEYWORD, 'procedure', 0);
 Tok(TK_IDENT, 'Avance', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_IDENT, 'forward', 0);
 Tok(TK_PUNCT, ';', 0);
 ParserInit;
 ParseProcOrFuncDecl;
 ProcAssert('declaration forward consomme tous les tokens', PPAtEnd);
 ProcAssert('forward enregistre Avance comme externe (en attente de corps)',
  SymTab[SymFind('Avance')].IsExternal);

 TokenPoolInit;
 Tok(TK_KEYWORD, 'procedure', 0);
 Tok(TK_IDENT, 'Avance', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'begin', 0);
 Tok(TK_KEYWORD, 'end', 0);
 Tok(TK_PUNCT, ';', 0);
 ParserInit;
 ParseProcOrFuncDecl;
 ProcAssert('corps reel de Avance consomme tous les tokens', PPAtEnd);
 ProcAssert('le corps reel remplit la MEME declaration forward (pas de doublon)',
  Not SymTab[SymFind('Avance')].IsExternal);

 { --- External : EXTRN emis, appel vers le nom exporte --- }
 TokenPoolInit;
 Tok(TK_KEYWORD, 'procedure', 0);
 Tok(TK_IDENT, 'MessageBeep', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_IDENT, 'N', 0);
 Tok(TK_PUNCT, ':', 0);
 Tok(TK_IDENT, 'Integer', 0);
 Tok(TK_PUNCT, ')', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_IDENT, 'external', 0);
 Tok(TK_STRING, 'user32.dll', 0);
 Tok(TK_PUNCT, ';', 0);
 ParserInit;
 ParseProcOrFuncDecl;
 ProcAssert('declaration external consomme tous les tokens', PPAtEnd);
 { Le nom exporte par defaut (sans clause NAME) conserve la casse       }
 { d origine de l identificateur Pascal : les noms exportes d une DLL  }
 { sont sensibles a la casse (contrairement aux identificateurs Pascal }
 { eux-memes, ce que SymFind/SymMangle normalisent partout ailleurs).  }
 HasExtrn := False;
 For I := 0 To UserExternCount - 1 Do
  If Pos('_MessageBeep@4', UserExternNames[I]) > 0 Then HasExtrn := True;
 ProcAssert('external ajoute un import EXTRN decore stdcall', HasExtrn);

 TokenPoolInit;
 Tok(TK_IDENT, 'MessageBeep', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_INTEGER, '0', 0);
 Tok(TK_PUNCT, ')', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPPROCSELFTEST_END');
 HasCallExternal := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL _MessageBeep@4', Line) > 0 Then HasCallExternal := True;
 End;
 Close(F); Erase(F);
 ProcAssert('l appel a MessageBeep cible directement le symbole externe',
  HasCallExternal);

 { --- Procedure imbriquee : visible et appelable depuis l exterieure --- }
 { procedure Externe;                                                    }
 {  procedure Interne; begin end;                                        }
 { begin Interne; end;                                                   }
 TokenPoolInit;
 Tok(TK_KEYWORD, 'procedure', 0);
 Tok(TK_IDENT, 'Externe', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'procedure', 0);
 Tok(TK_IDENT, 'Interne', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'begin', 0);
 Tok(TK_KEYWORD, 'end', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'begin', 0);
 Tok(TK_IDENT, 'Interne', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'end', 0);
 Tok(TK_PUNCT, ';', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParseProcOrFuncDecl;
 EmitClose('DPPROCSELFTEST_END');
 ProcAssert('procedure avec imbriquee consomme tous les tokens', PPAtEnd);

 { SymFind('Interne') ne le retrouverait plus ici : sa portee (celle   }
 { d Externe) est deja refermee (SymLeaveScope, en sortie de           }
 { ParseProcOrFuncDecl), donc SymFind renverrait -1 et SymTab[-1]       }
 { serait un acces hors bornes. On cherche directement dans SymTab,     }
 { sans tenir compte de la visibilite de portee, pour la verification.  }
 InterneSymIdx := -1;
 For I := 0 To SymCount - 1 Do
  If SymTab[I].Name = 'INTERNE' Then
  Begin
   InterneSymIdx := I;
   Break;
  End;
 ProcAssert('le symbole Interne existe toujours dans SymTab',
  InterneSymIdx >= 0);

 HasNestedCall := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL ' + SymTab[InterneSymIdx].MangledName, Line) > 0 Then
   HasNestedCall := True;
 End;
 Close(F); Erase(F);
 ProcAssert('Externe appelle bien sa procedure imbriquee Interne',
  HasNestedCall);

 SymInit;
 DataInit; DataInit2;
 FrameInit;
 StmtInit;
 UserExternInit;
End;

{ ============================================================ }
{ TODO 15 - CLASSES ET HERITAGE                      [IMPLEMENTE] }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ ClassSystemInit : completer l enregistrement de TObject/       }
{ Exception (SymRegisterBuiltins, TODO 05) avec ce que seul le    }
{ TODO 15 sait construire : la reservation du pointeur de VMT     }
{ (FieldInitInherit) et la VMT elle-meme (VMTInit), avec Destroy   }
{ comme methode virtuelle. Idempotent : ne fait rien si deja       }
{ initialise (SymInit rappelle SymRegisterBuiltins a chaque fois,  }
{ donc ClassSystemInit doit etre rappelee juste apres).             }
{ ------------------------------------------------------------ }

Procedure ClassSystemInit;
Var
 TObjIdx, ExcIdx, TObjTypeIdx, ExcTypeIdx, DestroySym : Integer;
Begin
 TObjIdx := SymFind('TObject');
 If TObjIdx < 0 Then Exit;
 TObjTypeIdx := SymTab[TObjIdx].TypeIdx;
 If TypeTab[TObjTypeIdx].FieldFirst < 0 Then
 Begin
  FieldInitInherit(TObjTypeIdx);
  VMTInit(TObjTypeIdx);
  DestroySym := SymFindInClass(TObjIdx, 'DESTROY');
  If DestroySym >= 0 Then VMTAddMethod(TObjTypeIdx, 'DESTROY', DestroySym);
 End;

 ExcIdx := SymFind('Exception');
 If ExcIdx >= 0 Then
 Begin
  ExcTypeIdx := SymTab[ExcIdx].TypeIdx;
  If TypeTab[ExcTypeIdx].FieldFirst < 0 Then
  Begin
   FieldInitInherit(ExcTypeIdx);
   VMTInit(ExcTypeIdx);
  End;
 End;
End;

{ ------------------------------------------------------------ }
{ SymFindInClassChain : comme SymFindInClass (TODO 05), mais      }
{ remonte la chaine des ancetres (BaseTypeIdx, niveau TYPE) si    }
{ le membre n est pas trouve dans la classe elle-meme. Sert a      }
{ retrouver une methode ORDINAIRE (jamais ajoutee a la VMT, donc   }
{ non couverte par la copie faite dans VMTInit) heritee depuis un  }
{ ancetre - ex. TObject.Free, appele sur n importe quelle instance.}
{ ------------------------------------------------------------ }

Function SymFindInClassChain(ClassTypeIdx: Integer; Const Name: TString): Integer;
Var T, R: Integer;
Begin
 SymFindInClassChain := -1;
 T := ClassTypeIdx;
 While T >= 0 Do
 Begin
  R := SymFindInClass(TypeTab[T].ClassSymIdx, Name);
  If R >= 0 Then
  Begin
   SymFindInClassChain := R;
   Exit;
  End;
  T := TypeTab[T].BaseTypeIdx;
 End;
End;

{ ------------------------------------------------------------ }
{ ClassHasAbstractMethod : la classe a-t-elle, dans sa VMT        }
{ (heritee comprise), une methode virtuelle sans corps (jamais     }
{ remplie par ParseMethodBodyDecl, donc encore IsExternal) ?       }
{ Verifie a l instanciation (ParseClassMemberAccess) : Delphi       }
{ n empeche pas de COMPILER une classe abstraite, seulement de la  }
{ CREER - d ou un avertissement, pas une erreur bloquante.          }
{ ------------------------------------------------------------ }

Function ClassHasAbstractMethod(ClassTypeIdx: Integer): Boolean;
Var I: Integer;
Begin
 ClassHasAbstractMethod := False;
 If (ClassTypeIdx < 0) Or (ClassTypeIdx >= TypeCount) Or
    (TypeTab[ClassTypeIdx].VMTFirst < 0) Then Exit;
 For I := TypeTab[ClassTypeIdx].VMTFirst To
  TypeTab[ClassTypeIdx].VMTFirst + TypeTab[ClassTypeIdx].VMTCount - 1 Do
  If (VMTEntryPool[I].MethodSymIdx >= 0) And
     SymTab[VMTEntryPool[I].MethodSymIdx].IsExternal Then
  Begin
   ClassHasAbstractMethod := True;
   Exit;
  End;
End;

{ ------------------------------------------------------------ }
{ VMTLabelFor : nom de la donnee VMT d une classe (_DPC_Nom_VMT,  }
{ prefixe _DPC_ du TODO 07). La table elle-meme (une liste de       }
{ pointeurs de methode) est emise par EmitClassVMTs au TODO 24      }
{ (segment de donnees final, generation PE/OBJ) : ici, on se        }
{ contente de referencer ce label de facon deterministe, comme      }
{ tout symbole externe/avant, futur (EXTRN, RTL...).                }
{ ------------------------------------------------------------ }

Function VMTLabelFor(ClassTypeIdx: Integer): TString;
Begin
 VMTLabelFor := DP_CLS_PFX + SymTab[TypeTab[ClassTypeIdx].ClassSymIdx].Name +
  '_VMT';
End;

{ ------------------------------------------------------------ }
{ ParseClassFieldGroup : Nom[,Nom...]: Type; a l interieur d un   }
{ corps de classe - meme forme qu une section Var locale (TODO 14) }
{ mais ajoute au LAYOUT D INSTANCE de la classe (TypeAddField),    }
{ pas au cadre de pile.                                            }
{ ------------------------------------------------------------ }

Procedure ParseClassFieldGroup(ClassTypeIdx: Integer);
Var
 Names : Array[0..MAX_PARAM_GROUP - 1] Of TString;
 NCount, I, TIdx : Integer;
 TName : TString;
Begin
 NCount := 0;
 Repeat
  If NCount < MAX_PARAM_GROUP Then
  Begin
   Names[NCount] := TokenPool[PP].Val;
   Inc(NCount);
  End;
  PPAdvance;
 Until Not PPMatch(',');

 PPMatch(':');
 TIdx := TypeFindByName('Integer');
 If PPPeekKind In [TK_IDENT, TK_KEYWORD] Then
 Begin
  TName := TokenPool[PP].Val;
  PPAdvance;
  TIdx := TypeFindByName(TName);
  If TIdx < 0 Then TIdx := TypeFindByName('Integer');
 End;

 For I := 0 To NCount - 1 Do TypeAddField(ClassTypeIdx, Names[I], TIdx);
 SkipOptSemi;
End;

{ ------------------------------------------------------------ }
{ ParseClassMethodDecl : signature d une methode a l interieur    }
{ d un corps de classe (constructor/destructor/procedure/         }
{ function, eventuellement prefixee par CLASS pour une methode     }
{ statique). Enregistre le symbole dans la portee de membres de    }
{ la classe (SymEnterClassScope) SANS corps - celui-ci arrive       }
{ separement via TClasse.Methode (ParseMethodBodyDecl). Les         }
{ methodes virtual/dynamic/override sont ajoutees a la VMT ;        }
{ abstract est reconnue (ClassHasAbstractMethod fait la              }
{ verification reelle, a l instanciation) ; les autres directives    }
{ (overload/reintroduce/static/inline/conventions d appel) sont      }
{ reconnues mais n affectent pas encore le code genere (TODO 14).    }
{ ------------------------------------------------------------ }

Procedure ParseClassMethodDecl(ClassSymIdx, ClassTypeIdx: Integer);
Var
 Kind              : TString;
 IsCtor, IsDtor, IsFunc, IsStatic : Boolean;
 Name, Up, TName   : TString;
 MethodSymIdx, RetTypeIdx, PTypeIdx : Integer;
 GI, ParamCountLocal : Integer;
 IsVirtual, IsOverride : Boolean;
Begin
 IsStatic := False;
 Kind := StrUpperCase(PPPeekVal);
 If Kind = 'CLASS' Then
 Begin
  IsStatic := True;
  PPAdvance;
  Kind := StrUpperCase(PPPeekVal);
 End;

 IsCtor := (Kind = 'CONSTRUCTOR');
 IsDtor := (Kind = 'DESTRUCTOR');
 IsFunc := (Kind = 'FUNCTION');
 PPAdvance;   { constructor|destructor|procedure|function }

 Name := TokenPool[PP].Val;
 PPAdvance;

 SymEnterClassScope(ClassSymIdx);
 MethodSymIdx := SymAddForce(Name, SK_METHOD, -1);
 If MethodSymIdx >= 0 Then
 Begin
  SymTab[MethodSymIdx].IsExternal    := True;   { pas de corps ici }
  SymTab[MethodSymIdx].IsConstructor := IsCtor;
  SymTab[MethodSymIdx].IsClassMethod := IsStatic;
  SymTab[MethodSymIdx].MangledName   :=
   DP_FUNC_PFX + SymTab[ClassSymIdx].Name + '_' + StrUpperCase(Name);
 End;
 SymLeaveScope;

 ParamCountLocal := 0;
 If PPMatch('(') Then
 Begin
  If Not PPMatch(')') Then
  Begin
   { Seule l ARITE compte ici (pour l overload par nombre de           }
  { parametres, TODO 14) : les parametres eux-memes ne sont lies       }
  { (ParamAdd) que lors de la compilation du corps hors-ligne           }
  { (ParseMethodBodyDecl) - VAR/CONST/OUT n ont donc pas besoin d etre  }
  { retenus ici, seulement consommes.                                    }
  Repeat
    If PPPeekKind = TK_KEYWORD Then
    Begin
     Up := StrUpperCase(PPPeekVal);
     If (Up = 'VAR') Or (Up = 'CONST') Or (Up = 'OUT') Then PPAdvance;
    End;

    GI := 0;
    Repeat
     Inc(GI);
     PPAdvance;
    Until Not PPMatch(',');

    PTypeIdx := TypeFindByName('Integer');
    If PPMatch(':') Then
    Begin
     TName := TokenPool[PP].Val;
     PPAdvance;
     PTypeIdx := TypeFindByName(TName);
     If PTypeIdx < 0 Then PTypeIdx := TypeFindByName('Integer');
    End;

    If PPMatch('=') Then ParseExpr;   { defaut : analyse et jete, TODO 14 }

    ParamCountLocal := ParamCountLocal + GI;
   Until Not PPMatch(';');
   PPMatch(')');
  End;
 End;

 RetTypeIdx := TypeFindByName('Integer');
 If IsFunc And PPMatch(':') Then
 Begin
  TName := TokenPool[PP].Val;
  PPAdvance;
  RetTypeIdx := TypeFindByName(TName);
  If RetTypeIdx < 0 Then RetTypeIdx := TypeFindByName('Integer');
 End;
 If IsCtor Then RetTypeIdx := ClassTypeIdx;   { Create "renvoie" Self }

 If MethodSymIdx >= 0 Then
 Begin
  SymTab[MethodSymIdx].TypeIdx    := RetTypeIdx;
  SymTab[MethodSymIdx].ParamCount := ParamCountLocal;
 End;

 PPMatch(';');

 { --- Directives : virtual/dynamic/override/abstract/conventions --- }
 IsVirtual := False;
 IsOverride := False;
 Repeat
  If PPPeekKind <> TK_IDENT Then Break;
  Up := StrUpperCase(PPPeekVal);
  If (Up = 'VIRTUAL') Or (Up = 'DYNAMIC') Then
  Begin IsVirtual := True; PPAdvance; PPMatch(';'); End
  Else If Up = 'OVERRIDE' Then
  Begin IsOverride := True; PPAdvance; PPMatch(';'); End
  Else If (Up = 'ABSTRACT') Or (Up = 'OVERLOAD') Or (Up = 'REINTRODUCE') Or
          (Up = 'STATIC') Or (Up = 'INLINE') Or (Up = 'REGISTER') Or
          (Up = 'STDCALL') Or (Up = 'CDECL') Or (Up = 'PASCAL') Or
          (Up = 'SAFECALL') Then
   Begin PPAdvance; PPMatch(';'); End
  Else
   Break;
 Until False;

 { Un destructeur est TOUJOURS virtuel en Delphi reel (TObject.Destroy}
 { l est, et toute redefinition doit pouvoir etre atteinte depuis un   }
 { pointeur statiquement type sur un ancetre, ex. TObject.Free) meme   }
 { sans le mot-cle 'virtual'/'override' explicite.                     }
 If (IsVirtual Or IsOverride Or IsDtor) And (Not IsStatic) And
    (MethodSymIdx >= 0) Then
  VMTAddMethod(ClassTypeIdx, Name, MethodSymIdx);
End;

{ ------------------------------------------------------------ }
{ ParseClassDecl : CLASS[(Parent[, IInterface...])] [SEALED]      }
{ [ABSTRACT] <sections de visibilite/champs/methodes/proprietes>  }
{ END - le nom de la classe (ClassName) a deja ete lu par          }
{ l appelant (ParseTypeDecl). Sans ancetre explicite, herite de     }
{ TObject (comme en Delphi reel). Les sections de visibilite        }
{ (private/protected/public/published/automated) et les             }
{ proprietes (TODO 16) sont reconnues mais pas appliquees/           }
{ implementees - une seule "unite" existe pour l instant (TODO 23). }
{ Retourne le TypeIdx de la nouvelle classe.                         }
{ ------------------------------------------------------------ }

Function ParseClassDecl(Const ClassName: TString): Integer;
Var
 ParentName, Up : TString;
 ParentSymIdx, ClassSymIdx, ClassTypeIdx, Found : Integer;
Begin
 PPAdvance;   { class }

 ParentSymIdx := SymFind('TObject');
 If PPMatch('(') Then
 Begin
  ParentName := TokenPool[PP].Val;
  PPAdvance;
  Found := SymFind(ParentName);
  If Found >= 0 Then ParentSymIdx := Found
  Else WarnMsg('classe ancetre inconnue: ' + ParentName);
  { interfaces supplementaires (TODO 17) : reconnues, non geres }
  While PPMatch(',') Do PPAdvance;
  PPMatch(')');
 End;

 If (ParentSymIdx >= 0) And SymTab[ParentSymIdx].IsSealed Then
  WarnMsg('la classe ancetre ' + SymTab[ParentSymIdx].Name +
   ' est scellee (sealed) : heritage interdit');

 ClassSymIdx  := SymDeclareClass(ClassName, SK_CLASS, ParentSymIdx);
 ClassTypeIdx := SymTab[ClassSymIdx].TypeIdx;
 FieldInitInherit(ClassTypeIdx);
 VMTInit(ClassTypeIdx);

 If (PPPeekKind = TK_IDENT) And (StrUpperCase(PPPeekVal) = 'SEALED') Then
 Begin
  SymTab[ClassSymIdx].IsSealed := True;
  PPAdvance;
 End;
 If (PPPeekKind = TK_IDENT) And (StrUpperCase(PPPeekVal) = 'ABSTRACT') Then
  PPAdvance;   { reconnue ; ClassHasAbstractMethod verifie a l instanciation }

 While Not PPAtEnd Do
 Begin
  If PPPeekKind = TK_KEYWORD Then
  Begin
   Up := StrUpperCase(PPPeekVal);
   If Up = 'END' Then Break;

   If (Up = 'CONSTRUCTOR') Or (Up = 'DESTRUCTOR') Or (Up = 'PROCEDURE') Or
      (Up = 'FUNCTION') Or (Up = 'CLASS') Then
   Begin
    ParseClassMethodDecl(ClassSymIdx, ClassTypeIdx);
    Continue;
   End;

   If Up = 'PROPERTY' Then
   Begin
    { proprietes : TODO 16, reconnues et ignorees pour l instant }
    PPAdvance;
    While (Not PPAtEnd) And
          (Not ((PPPeekKind = TK_PUNCT) And (PPPeekVal = ';'))) Do
     PPAdvance;
    SkipOptSemi;
    Continue;
   End;

   { mot-cle non gere ici (ex: 'end' deja traite plus haut) }
   PPAdvance;
   Continue;
  End;

  If PPPeekKind = TK_IDENT Then
  Begin
   Up := StrUpperCase(PPPeekVal);
   If (Up = 'PRIVATE') Or (Up = 'PROTECTED') Or (Up = 'PUBLIC') Or
      (Up = 'PUBLISHED') Or (Up = 'AUTOMATED') Then
   Begin
    PPAdvance;
    Continue;
   End;
   ParseClassFieldGroup(ClassTypeIdx);
   Continue;
  End;

  Break;   { filet de securite anti-boucle infinie }
 End;

 PPMatch('end');
 SkipOptSemi;

 ParseClassDecl := ClassTypeIdx;
End;

{ ------------------------------------------------------------ }
{ ParseTypeDecl : TYPE Nom = ... ; point d entree de plus haut    }
{ niveau. Seules les declarations de classe sont geres (spec du    }
{ TODO 15) ; toute autre forme (record/enum/tableau/alias simple,  }
{ TODO 06/19) est reconnue mais ignoree avec avertissement, en      }
{ sautant jusqu au ';' de fin (en tenant compte d un RECORD..END    }
{ imbrique via SkipToMatchingEnd, TODO 13) pour rester synchronise. }
{ ------------------------------------------------------------ }

Procedure ParseTypeDecl;
Var Name: TString;
Begin
 PPAdvance;   { type }
 Name := TokenPool[PP].Val;
 PPAdvance;
 PPMatch('=');

 If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'CLASS') Then
 Begin
  ParseClassDecl(Name);
  Exit;
 End;

 WarnMsg('declaration de type non geree (seules les classes le sont, ' +
  'TODO 15) : ' + Name + ' ignoree');
 While (Not PPAtEnd) And
       (Not ((PPPeekKind = TK_PUNCT) And (PPPeekVal = ';'))) Do
 Begin
  If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'RECORD') Then
  Begin
   PPAdvance;
   SkipToMatchingEnd;
   Break;
  End;
  PPAdvance;
 End;
 SkipOptSemi;
End;

{ ------------------------------------------------------------ }
{ ParseMethodBodyDecl : PROCEDURE|FUNCTION|CONSTRUCTOR|DESTRUCTOR }
{ Classe.Methode(params)[: Type]; ... BEGIN ... END; - le corps    }
{ hors-ligne d une methode DEJA declaree dans le corps de la       }
{ classe (ParseClassMethodDecl). Reutilise le squelette de          }
{ ParseProcOrFuncDecl (cadre EBP, Result, declarations locales,     }
{ TODO 14) avec Self comme parametre implicite (1er, sauf pour      }
{ une methode de classe statique) et CurSelfTypeIdx (TODO 10) fixe  }
{ pour la duree du corps, ce qui rend Self.Champ et 'inherited'      }
{ operants sans aucun changement a ces deux mecanismes.              }
{ ------------------------------------------------------------ }

Procedure ParseMethodBodyDecl;
Var
 IsFunc                     : Boolean;
 Kind, ClassName, MethodName, Up, TName : TString;
 ClassSymIdx, ClassTypeIdx, MethodSymIdx : Integer;
 SavedRetLabel               : TString;
 SavedFrameOffset, SavedParamOffset, SavedSelfTypeIdx : Integer;
 MyRetLabel                  : TString;
 ResultIdx, AliasIdx          : Integer;
 ParamNames                  : Array[0..MAX_PARAM_GROUP - 1] Of TString;
 GI, I                        : Integer;
 PKind                        : TParamKind;
 PTypeIdx                     : Integer;
Begin
 Kind := StrUpperCase(PPPeekVal);
 IsFunc := (Kind = 'FUNCTION');
 PPAdvance;   { procedure|function|constructor|destructor }

 ClassName := TokenPool[PP].Val;
 PPAdvance;
 PPMatch('.');
 MethodName := TokenPool[PP].Val;
 PPAdvance;

 ClassSymIdx := SymFind(ClassName);
 If ClassSymIdx < 0 Then
 Begin
  WarnMsg('classe inconnue: ' + ClassName);
  Exit;
 End;
 ClassTypeIdx := SymTab[ClassSymIdx].TypeIdx;

 MethodSymIdx := SymFindInClass(ClassSymIdx, MethodName);
 If MethodSymIdx < 0 Then
 Begin
  WarnMsg('methode ' + ClassName + '.' + MethodName +
   ' non declaree dans le corps de la classe');
  Exit;
 End;

 SavedRetLabel    := CurRetLabel;
 SavedFrameOffset := CurFrameOffset;
 SavedParamOffset := CurParamOffset;
 SavedSelfTypeIdx := CurSelfTypeIdx;

 SymEnterScope;
 FrameInit;
 CurSelfTypeIdx := ClassTypeIdx;

 If Not SymTab[MethodSymIdx].IsClassMethod Then
  ParamAdd('SELF', ClassTypeIdx, PK_VALUE);

 If PPMatch('(') Then
 Begin
  If Not PPMatch(')') Then
  Begin
   Repeat
    PKind := PK_VALUE;
    If PPPeekKind = TK_KEYWORD Then
    Begin
     Up := StrUpperCase(PPPeekVal);
     If Up = 'VAR' Then Begin PKind := PK_VAR; PPAdvance; End
     Else If Up = 'CONST' Then Begin PKind := PK_CONST; PPAdvance; End
     Else If Up = 'OUT' Then Begin PKind := PK_OUT; PPAdvance; End;
    End;

    GI := 0;
    Repeat
     If GI < MAX_PARAM_GROUP Then
     Begin
      ParamNames[GI] := TokenPool[PP].Val;
      Inc(GI);
     End;
     PPAdvance;
    Until Not PPMatch(',');

    PTypeIdx := TypeFindByName('Integer');
    If PPMatch(':') Then
    Begin
     TName := TokenPool[PP].Val;
     PPAdvance;
     PTypeIdx := TypeFindByName(TName);
     If PTypeIdx < 0 Then PTypeIdx := TypeFindByName('Integer');
    End;

    If PPMatch('=') Then ParseExpr;

    For I := 0 To GI - 1 Do ParamAdd(ParamNames[I], PTypeIdx, PKind);
   Until Not PPMatch(';');
   PPMatch(')');
  End;
 End;

 If IsFunc And PPMatch(':') Then
 Begin
  { Le type de retour a deja ete fixe par ParseClassMethodDecl ; on   }
  { consomme seulement le texte ici pour rester synchronise.           }
  PPAdvance;
 End;

 PPMatch(';');

 While PPPeekKind = TK_IDENT Do
 Begin
  Up := StrUpperCase(PPPeekVal);
  If (Up = 'OVERRIDE') Or (Up = 'VIRTUAL') Or (Up = 'DYNAMIC') Or
     (Up = 'OVERLOAD') Or (Up = 'REINTRODUCE') Then
  Begin PPAdvance; PPMatch(';'); End
  Else
   Break;
 End;

 MyRetLabel  := LabelGen;
 CurRetLabel := MyRetLabel;

 If IsFunc Then
 Begin
  ResultIdx := LocalAdd('RESULT', SymTab[MethodSymIdx].TypeIdx);
  If ResultIdx >= 0 Then
  Begin
   AliasIdx := SymAdd(MethodName, SK_VAR, SymTab[MethodSymIdx].TypeIdx);
   If AliasIdx >= 0 Then SymTab[AliasIdx].Offset := SymTab[ResultIdx].Offset;
  End;
 End;

 ParseDeclSection;

 EmitBlankLine;
 EmitLabel(SymTab[MethodSymIdx].MangledName);
 EmitProlog(-CurFrameOffset);

 If (PPPeekKind = TK_KEYWORD) And (StrUpperCase(PPPeekVal) = 'BEGIN') Then
  ParseCompoundStmt
 Else
  WarnMsg('begin attendu pour le corps de ' + ClassName + '.' + MethodName);

 SkipOptSemi;

 EmitLabel(MyRetLabel);
 If SymTab[MethodSymIdx].IsConstructor Then
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]')   { Create "renvoie" Self, pas Result }
 Else If IsFunc Then
  GenLoadVar('RESULT');
 EmitEpilog;

 SymTab[MethodSymIdx].IsExternal := False;   { corps desormais fourni }

 SymLeaveScope;
 CurRetLabel    := SavedRetLabel;
 CurFrameOffset := SavedFrameOffset;
 CurParamOffset := SavedParamOffset;
 CurSelfTypeIdx := SavedSelfTypeIdx;
End;

{ ------------------------------------------------------------ }
{ ParseClassMemberAccess : TClasse.Membre(...) - acces qualifie   }
{ par un NOM DE CLASSE (pas une instance). Deux cas : un           }
{ constructeur (TClasse.Create(...)) alloue l instance             }
{ (HeapAlloc, dimensionnee par InstanceSize) et y ecrit le          }
{ pointeur de VMT AVANT d appeler le corps du constructeur avec     }
{ Self=la nouvelle instance ; une methode de classe (statique,       }
{ class function/procedure) est appelee directement, sans Self.     }
{ ------------------------------------------------------------ }

Function ParseClassMemberAccess(ClassSymIdx: Integer): Integer;
Var
 MemberName, Up : TString;
 MethodSymIdx, ClassTypeIdx, ArgN : Integer;
Begin
 ParseClassMemberAccess := -1;
 PPAdvance;   { . }
 MemberName := TokenPool[PP].Val;
 Up := StrUpperCase(MemberName);
 PPAdvance;

 ClassTypeIdx := SymTab[ClassSymIdx].TypeIdx;
 MethodSymIdx := SymFindInClassChain(ClassTypeIdx, Up);
 If MethodSymIdx < 0 Then
 Begin
  WarnMsg('membre de classe inconnu: ' + SymTab[ClassSymIdx].Name + '.' +
   MemberName);
  Exit;
 End;

 If SymTab[MethodSymIdx].IsConstructor Then
 Begin
  If ClassHasAbstractMethod(ClassTypeIdx) Then
   WarnMsg('instanciation d une classe avec methode(s) abstraite(s) sans ' +
    'corps: ' + SymTab[ClassSymIdx].Name);

  EmitComment(SymTab[ClassSymIdx].Name + '.Create : allocation de l ' +
   'instance (InstanceSize=' + IntToStr_(TypeTab[ClassTypeIdx].InstanceSize) +
   ')');
  EmitInstr('CALL GetProcessHeap');
  EmitInstr('PUSH ' + IntToStr_(TypeTab[ClassTypeIdx].InstanceSize));
  EmitInstr('PUSH 0');
  EmitInstr('PUSH EAX');
  EmitInstr('CALL HeapAlloc');
  EmitInstr('MOV EBX,EAX');   { EBX = nouvelle instance, conservee pendant l init }
  EmitComment('Pointeur de VMT (table de donnees emise au TODO 24)');
  EmitInstr('MOV DWORD PTR [EBX],OFFSET ' + VMTLabelFor(ClassTypeIdx));
  ArgN := ParseCallArgs;
  EmitInstr('PUSH EBX');   { Self, en dernier }
  EmitInstr('CALL ' + SymTab[MethodSymIdx].MangledName);
  EmitInstr('ADD ESP,' + IntToStr_((ArgN + 1) * 4));
  EmitInstr('MOV EAX,EBX');   { Create renvoie le pointeur d instance }
  LastExprTypeIdx := ClassTypeIdx;
  ParseClassMemberAccess := ClassTypeIdx;
  Exit;
 End;

 If SymTab[MethodSymIdx].IsClassMethod Then
 Begin
  ArgN := ParseCallArgs;
  EmitInstr('CALL ' + SymTab[MethodSymIdx].MangledName);
  If ArgN > 0 Then EmitInstr('ADD ESP,' + IntToStr_(ArgN * 4));
  LastExprTypeIdx := SymTab[MethodSymIdx].TypeIdx;
  ParseClassMemberAccess := LastExprTypeIdx;
  Exit;
 End;

 WarnMsg(SymTab[ClassSymIdx].Name + '.' + MemberName +
  ' n est ni un constructeur ni une methode de classe (necessite une ' +
  'instance)');
End;

{ ------------------------------------------------------------ }
{ ClassAssert / ClassSelfTest : verifient la declaration de       }
{ classes (champs, heritage, methode virtuelle/override), le      }
{ corps hors-ligne, l allocation du constructeur, l appel virtuel  }
{ via Free/Destroy, et sealed/abstract, avec des suites de tokens  }
{ synthetiques, comme les self-tests des TODO precedents.          }
{ ------------------------------------------------------------ }

Procedure ClassAssert(Const Label_: TString; Cond: Boolean);
Begin
 If Not Cond Then
  FatalError('ClassSelfTest: ' + Label_ + ' a echoue');
End;

Procedure ClassSelfTest;
Const
 TmpFile = 'DPCLASSSELFTEST.$$$';
Var
 AnimalSymIdx, AnimalTypeIdx, DogSymIdx, DogTypeIdx : Integer;
 SpeakSym, FAge : Integer;
 F : Text;
 Line : TString;
 HasHeapAlloc, HasVMTStore, HasCtorCall, HasVirtualSpeak : Boolean;
 HasStaticSpeak, HasFreeVirtualDestroy : Boolean;

 Procedure Tok(Kind: TTokenKind; Const Val: TString; IntVal: LongInt);
 Var T: TToken;
 Begin
  T.Kind := Kind; T.Val := Val; T.IntVal := IntVal; T.RealVal := 0.0;
  T.Line := 1; T.Col := 1;
  TokenPoolAdd(T);
 End;

Begin
 SymInit;
 ClassSystemInit;
 DataInit; DataInit2;
 FrameInit;
 StmtInit;
 UserExternInit;

 { --- TAnimalCT = class Age: Integer; constructor Create;          }
 {      procedure Speak; virtual; end;                               }
 TokenPoolInit;
 Tok(TK_KEYWORD, 'type', 0);
 Tok(TK_IDENT, 'TAnimalCT', 0);
 Tok(TK_OP, '=', 0);
 Tok(TK_KEYWORD, 'class', 0);
 Tok(TK_IDENT, 'Age', 0);
 Tok(TK_PUNCT, ':', 0);
 Tok(TK_IDENT, 'Integer', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'constructor', 0);
 Tok(TK_IDENT, 'Create', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'procedure', 0);
 Tok(TK_IDENT, 'Speak', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_IDENT, 'virtual', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'end', 0);
 Tok(TK_PUNCT, ';', 0);
 ParserInit;
 ParseTypeDecl;
 ClassAssert('declaration TAnimalCT consomme tous les tokens', PPAtEnd);

 AnimalSymIdx  := SymFind('TAnimalCT');
 ClassAssert('TAnimalCT enregistree comme classe', AnimalSymIdx >= 0);
 AnimalTypeIdx := SymTab[AnimalSymIdx].TypeIdx;
 ClassAssert('TAnimalCT herite implicitement de TObject',
  SymTab[AnimalSymIdx].ParentClassIdx = SymFind('TObject'));

 FAge := TypeTab[AnimalTypeIdx].FieldFirst;
 ClassAssert('le champ Age existe', TypeTab[AnimalTypeIdx].FieldCount = 1);
 ClassAssert('Age est a l offset 4 (0 = pointeur de VMT)',
  FieldPool[FAge].Offset = 4);

 SpeakSym := SymFindInClass(AnimalSymIdx, 'SPEAK');
 ClassAssert('Speak enregistree dans TAnimalCT', SpeakSym >= 0);
 ClassAssert('Speak est dans la VMT (virtual)',
  VMTFindMethod(AnimalTypeIdx, 'SPEAK') >= 0);

 { --- Corps hors-ligne : constructor TAnimalCT.Create; begin end; --- }
 TokenPoolInit;
 Tok(TK_KEYWORD, 'constructor', 0);
 Tok(TK_IDENT, 'TAnimalCT', 0);
 Tok(TK_PUNCT, '.', 0);
 Tok(TK_IDENT, 'Create', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'begin', 0);
 Tok(TK_KEYWORD, 'end', 0);
 Tok(TK_PUNCT, ';', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParseMethodBodyDecl;
 EmitClose('DPCLASSSELFTEST_END');
 ClassAssert('corps de TAnimalCT.Create consomme tous les tokens', PPAtEnd);
 ClassAssert('le corps fourni desactive IsExternal sur Create',
  Not SymTab[SymFindInClass(AnimalSymIdx, 'CREATE')].IsExternal);

 { --- Corps hors-ligne : procedure TAnimalCT.Speak; begin end; --- }
 TokenPoolInit;
 Tok(TK_KEYWORD, 'procedure', 0);
 Tok(TK_IDENT, 'TAnimalCT', 0);
 Tok(TK_PUNCT, '.', 0);
 Tok(TK_IDENT, 'Speak', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'begin', 0);
 Tok(TK_KEYWORD, 'end', 0);
 Tok(TK_PUNCT, ';', 0);
 ParserInit;
 ParseMethodBodyDecl;
 ClassAssert('corps de TAnimalCT.Speak consomme tous les tokens', PPAtEnd);

 { --- TDogCT = class(TAnimalCT) procedure Speak; override; end; --- }
 TokenPoolInit;
 Tok(TK_KEYWORD, 'type', 0);
 Tok(TK_IDENT, 'TDogCT', 0);
 Tok(TK_OP, '=', 0);
 Tok(TK_KEYWORD, 'class', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_IDENT, 'TAnimalCT', 0);
 Tok(TK_PUNCT, ')', 0);
 Tok(TK_KEYWORD, 'procedure', 0);
 Tok(TK_IDENT, 'Speak', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_IDENT, 'override', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'end', 0);
 Tok(TK_PUNCT, ';', 0);
 ParserInit;
 ParseTypeDecl;
 ClassAssert('declaration TDogCT consomme tous les tokens', PPAtEnd);

 DogSymIdx  := SymFind('TDogCT');
 DogTypeIdx := SymTab[DogSymIdx].TypeIdx;
 ClassAssert('TDogCT herite du champ Age', TypeTab[DogTypeIdx].FieldCount = 1);
 ClassAssert('Speak (override) garde le MEME offset de VMT que TAnimalCT',
  VMTFindMethod(DogTypeIdx, 'SPEAK') = VMTFindMethod(AnimalTypeIdx, 'SPEAK'));
 ClassAssert('TDogCT.Speak est un symbole distinct de TAnimalCT.Speak',
  SymFindInClass(DogSymIdx, 'SPEAK') <> SpeakSym);

 TokenPoolInit;
 Tok(TK_KEYWORD, 'procedure', 0);
 Tok(TK_IDENT, 'TDogCT', 0);
 Tok(TK_PUNCT, '.', 0);
 Tok(TK_IDENT, 'Speak', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'begin', 0);
 Tok(TK_KEYWORD, 'end', 0);
 Tok(TK_PUNCT, ';', 0);
 ParserInit;
 ParseMethodBodyDecl;
 ClassAssert('corps de TDogCT.Speak consomme tous les tokens', PPAtEnd);

 { --- TDogCT.Create(...) : allocation + pointeur de VMT + appel --- }
 TokenPoolInit;
 Tok(TK_IDENT, 'TDogCT', 0);
 Tok(TK_PUNCT, '.', 0);
 Tok(TK_IDENT, 'Create', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_PUNCT, ')', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPCLASSSELFTEST_END');
 ClassAssert('TDogCT.Create(...) consomme tous les tokens', PPAtEnd);

 HasHeapAlloc := False; HasVMTStore := False; HasCtorCall := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 ClassAssert('fichier de test (Create) relisible', IOResult = 0);
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL HeapAlloc', Line) > 0 Then HasHeapAlloc := True;
  If Pos('MOV DWORD PTR [EBX],OFFSET ' + VMTLabelFor(DogTypeIdx), Line) > 0 Then
   HasVMTStore := True;
  If Pos('CALL ' + SymTab[SymFindInClass(AnimalSymIdx, 'CREATE')].MangledName,
     Line) > 0 Then HasCtorCall := True;
 End;
 Close(F); Erase(F);
 ClassAssert('TDogCT.Create alloue l instance (HeapAlloc)', HasHeapAlloc);
 ClassAssert('TDogCT.Create ecrit le pointeur de VMT de TDogCT', HasVMTStore);
 ClassAssert('TDogCT.Create appelle le corps du constructeur herite',
  HasCtorCall);

 { --- Dog.Speak() sur une instance : appel VIRTUEL (VMT), pas statique --- }
 GlobalVarDeclare('CLASSCTDOG', DogTypeIdx, 0);
 TokenPoolInit;
 Tok(TK_IDENT, 'ClassCTDog', 0);
 Tok(TK_PUNCT, '.', 0);
 Tok(TK_IDENT, 'Speak', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_PUNCT, ')', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPCLASSSELFTEST_END');
 HasVirtualSpeak := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('MOV EDX,DWORD PTR [EBX]', Line) > 0 Then HasVirtualSpeak := True;
 End;
 Close(F); Erase(F);
 ClassAssert('ClassCTDog.Speak() appelle via la VMT (virtuelle)',
  HasVirtualSpeak);

 { --- ClassCTDog.Free : Destroy virtuel (herite de TObject) + HeapFree --- }
 TokenPoolInit;
 Tok(TK_IDENT, 'ClassCTDog', 0);
 Tok(TK_PUNCT, '.', 0);
 Tok(TK_IDENT, 'Free', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPCLASSSELFTEST_END');
 HasFreeVirtualDestroy := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL ' + SymTab[SymFindInClass(SymFind('TObject'), 'FREE')].MangledName,
     Line) > 0 Then HasFreeVirtualDestroy := True;
 End;
 Close(F); Erase(F);
 ClassAssert('ClassCTDog.Free (herite, non virtuel) appelle TObject.Free',
  HasFreeVirtualDestroy);

 { --- Sealed : heritage interdit, avertissement (pas d exception) --- }
 TokenPoolInit;
 Tok(TK_KEYWORD, 'type', 0);
 Tok(TK_IDENT, 'TSealedCT', 0);
 Tok(TK_OP, '=', 0);
 Tok(TK_KEYWORD, 'class', 0);
 Tok(TK_IDENT, 'sealed', 0);
 Tok(TK_KEYWORD, 'end', 0);
 Tok(TK_PUNCT, ';', 0);
 ParserInit;
 ParseTypeDecl;
 ClassAssert('TSealedCT (sealed) consomme tous les tokens', PPAtEnd);
 ClassAssert('TSealedCT est bien marquee scellee',
  SymTab[SymFind('TSealedCT')].IsSealed);

 { --- Methode de classe (statique, class procedure) --- }
 TokenPoolInit;
 Tok(TK_KEYWORD, 'type', 0);
 Tok(TK_IDENT, 'TUtilCT', 0);
 Tok(TK_OP, '=', 0);
 Tok(TK_KEYWORD, 'class', 0);
 Tok(TK_KEYWORD, 'class', 0);
 Tok(TK_KEYWORD, 'procedure', 0);
 Tok(TK_IDENT, 'Ping', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'end', 0);
 Tok(TK_PUNCT, ';', 0);
 ParserInit;
 ParseTypeDecl;
 ClassAssert('TUtilCT (methode de classe) consomme tous les tokens', PPAtEnd);
 ClassAssert('Ping est bien marquee methode de classe',
  SymTab[SymFindInClass(SymFind('TUtilCT'), 'PING')].IsClassMethod);

 TokenPoolInit;
 Tok(TK_KEYWORD, 'procedure', 0);
 Tok(TK_IDENT, 'TUtilCT', 0);
 Tok(TK_PUNCT, '.', 0);
 Tok(TK_IDENT, 'Ping', 0);
 Tok(TK_PUNCT, ';', 0);
 Tok(TK_KEYWORD, 'begin', 0);
 Tok(TK_KEYWORD, 'end', 0);
 Tok(TK_PUNCT, ';', 0);
 ParserInit;
 ParseMethodBodyDecl;
 ClassAssert('corps de TUtilCT.Ping consomme tous les tokens', PPAtEnd);

 TokenPoolInit;
 Tok(TK_IDENT, 'TUtilCT', 0);
 Tok(TK_PUNCT, '.', 0);
 Tok(TK_IDENT, 'Ping', 0);
 Tok(TK_PUNCT, '(', 0);
 Tok(TK_PUNCT, ')', 0);
 ParserInit;
 EmitOpen(TmpFile);
 ParsePrimary;
 EmitClose('DPCLASSSELFTEST_END');
 HasStaticSpeak := False;
 {$I-} Assign(F, TmpFile); Reset(F); {$I+}
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Pos('CALL ' + SymTab[SymFindInClass(SymFind('TUtilCT'), 'PING')].MangledName,
     Line) > 0 Then HasStaticSpeak := True;
 End;
 Close(F); Erase(F);
 ClassAssert('TUtilCT.Ping() appelle directement (methode de classe)',
  HasStaticSpeak);

 SymInit;
 ClassSystemInit;
 DataInit; DataInit2;
 FrameInit;
 StmtInit;
 UserExternInit;
End;

{ ------------------------------------------------------------ }
{ Run - point d entree de la compilation                       }
{ Le parseur de fichier programme complet (uses, section         }
{ principale) sera ajoute par les TODO 23 et suivants. Pour       }
{ l instant, Run verifie les briques deja posees (constantes,     }
{ symboles/portees, types, emetteur ASM, segment de donnees/VMT/  }
{ interfaces, variables/affectations, expressions primaires et    }
{ binaires, E/S et RTL minimale, structures de controle,          }
{ procedures/fonctions et surcharge, classes et heritage), fait   }
{ passer le lexeur sur tout le fichier source, genere un          }
{ squelette .ASM assemblable si -asm est demande, et annonce que  }
{ l analyse syntaxique n est pas encore implementee.              }
{ ------------------------------------------------------------ }

Procedure Run;
Begin
 ErrorCount := 0;
 WarnCount  := 0;
 TotalLines := 0;
 OutFOpen   := False;
 LexOpened  := False;

 { Verifier au demarrage que les briques deja posees restent correctes }
 ConstEvalSelfTest;
 SymSelfTest;
 TypeSelfTest;
 EmitSelfTest;
 DataSelfTest;
 VarSelfTest;
 ParseSelfTest;
 BinSelfTest;
 RTLSelfTest;
 StmtSelfTest;
 ProcSelfTest;
 ClassSelfTest;

 {$I-}
 Assign(LexSrcF, Opts.SrcFile);
 Reset(LexSrcF);
 {$I+}
 If IOResult <> 0 Then
  FatalError('impossible d''ouvrir le fichier source: ' + Opts.SrcFile);
 LexOpened   := True;
 LexSrcFName := Opts.SrcFile;

 ShowBanner;
 PPInitDefines;
 DataInit;
 DataInit2;
 FrameInit;
 StmtInit;
 UserExternInit;
 TokenPoolInit;
 SymInit;
 ClassSystemInit;
 ParserInit;
 LexInit;
 Repeat
  LexNextToken;
  If CurToken.Kind <> TK_EOF Then
   TokenPoolAdd(CurToken);
 Until CurToken.Kind = TK_EOF;
 LexClose;

 { Enregistrer toutes les chaines litterales dans le pool de donnees }
 TokenPoolRegisterStrings;

 { TODO 07 : produire un squelette .ASM assemblable si demande. Le    }
 { corps reel du programme viendra avec le parseur de fichier         }
 { programme complet (TODO 23 et suivants) : ParsePrimary/ParseExpr/  }
 { ParseStmt/ParseProcOrFuncDecl/ParseClassDecl (TODO 10/11/13/14/15) }
 { ne sont pour l instant exerces que par leurs self-tests, faute      }
 { d un point d entree de plus haut niveau (Program/Uses/section       }
 { principale) pour les piloter depuis un vrai fichier source.          }
 If Opts.AsmOutput Then
  EmitSkeletonProgram(ReplaceExt(Opts.OutFile, '.asm'));

 If Opts.Verbose Then
 Begin
  WriteLn('AppType  : ', AppType);
  WriteLn('Tokens   : ', TokenCount, '   Donnees (chaines) : ', DataCount);
  WriteLn('Symboles predefinis enregistres : ', SymCount);
  WriteLn('Types predefinis enregistres    : ', TypeCount);
 End;

 WriteLn('DELPHI: TODO 01 (infrastructure et options) implemente.');
 WriteLn('DELPHI: TODO 02 (lexeur) implemente.');
 WriteLn('DELPHI: TODO 03 (preprocesseur et directives) implemente.');
 WriteLn('DELPHI: TODO 04 (litteraux et constantes) implemente.');
 WriteLn('DELPHI: TODO 05 (table des symboles et portees) implemente.');
 WriteLn('DELPHI: TODO 06 (systeme de types Delphi) implemente.');
 WriteLn('DELPHI: TODO 07 (emetteur de code ASM 80386) implemente.');
 WriteLn('DELPHI: TODO 08 (segment de donnees, VMT et interfaces) ',
         'implemente.');
 WriteLn('DELPHI: TODO 09 (variables, affectations et gestion memoire) ',
         'implemente.');
 WriteLn('DELPHI: TODO 10 (expressions primaires) implemente.');
 WriteLn('DELPHI: TODO 11 (expressions binaires et precedence) ',
         'implemente.');
 WriteLn('DELPHI: TODO 12 (entrees/sorties et RTL minimale) ',
         'implemente.');
 WriteLn('DELPHI: TODO 13 (structures de controle) implemente.');
 WriteLn('DELPHI: TODO 14 (procedures, fonctions et surcharge) ',
         'implemente.');
 WriteLn('DELPHI: TODO 15 (classes et heritage) implemente.');
 WriteLn('DELPHI: analyseur syntaxique et generateur de code non ',
         'encore implementes (voir TODO 16 et suivants).');
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

