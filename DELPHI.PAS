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
Var R: Integer;
Begin
 R := SymAdd(Name, Kind, -1);
 If R >= 0 Then
 Begin
  SymTab[R].IsGlobal       := True;
  SymTab[R].ParentClassIdx := ParentIdx;
  Inc(ScopeIdSeq);
  SymTab[R].MemberScopeId := ScopeIdSeq;
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
  R := SymAdd(Name, SK_TYPE, -1);
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

 { Enregistrer une methode dans la portee de membres de la classe
   couramment ouverte via SymEnterClassScope. }
 Procedure RegMethod(Const Name: TString);
 Var R: Integer;
 Begin
  R := SymAdd(Name, SK_METHOD, -1);
  If R >= 0 Then SymTab[R].IsExternal := True;
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
 RegMethod('CREATE');
 RegMethod('DESTROY');
 RegMethod('FREE');
 RegMethod('CLASSNAME');
 RegMethod('CLASSTYPE');
 SymLeaveScope;

 { -------------------------------------------------------- }
 { Exception : classe de base des exceptions (try/except)   }
 { herite de TObject, sans redefinir Create : SymFindInherited}
 { doit remonter jusqu a TObject.Create pour la resoudre.    }
 { -------------------------------------------------------- }
 ExceptionIdx := SymDeclareClass('EXCEPTION', SK_CLASS, TObjectIdx);
 SymEnterClassScope(ExceptionIdx);
 RegMethod('MESSAGE');
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

 RegFunc('ORD');      RegFunc('CHR');
 RegFunc('SUCC');     RegFunc('PRED');
 RegFunc('LOW');      RegFunc('HIGH');
 RegFunc('SIZEOF');   RegFunc('LENGTH');
 RegFunc('ABS');      RegFunc('ASSIGNED');
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
 IntIdx, TObjIdx, ExcIdx, GlobalX, LocalX, CreateIdx : Integer;
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

 { Qualification Unit.Ident }
 SymAdd('TRIM', SK_FUNC, -1);
 SymTab[SymCount - 1].UnitName := 'SYSUTILS';
 SymAssert('SysUtils.Trim trouve par SymFindInUnit',
  SymFindInUnit('SysUtils', 'Trim') >= 0);
 SymAssert('Trim non qualifie introuvable dans une autre unite',
  SymFindInUnit('CRT', 'Trim') < 0);

 SymInit;   { restaurer une table propre pour la vraie compilation }
End;

{ ------------------------------------------------------------ }
{ Run - point d entree de la compilation                       }
{ Le parseur et le generateur de code seront ajoutes par les   }
{ TODO 06 et suivants. Pour l instant, Run verifie les briques  }
{ deja posees (constantes, symboles/portees), fait passer le    }
{ lexeur sur tout le fichier source, et annonce que l analyse   }
{ syntaxique n est pas encore implementee.                      }
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
 TokenPoolInit;
 SymInit;
 LexInit;
 Repeat
  LexNextToken;
  If CurToken.Kind <> TK_EOF Then
   TokenPoolAdd(CurToken);
 Until CurToken.Kind = TK_EOF;
 LexClose;

 { Enregistrer toutes les chaines litterales dans le pool de donnees }
 TokenPoolRegisterStrings;

 If Opts.Verbose Then
 Begin
  WriteLn('AppType  : ', AppType);
  WriteLn('Tokens   : ', TokenCount, '   Donnees (chaines) : ', DataCount);
  WriteLn('Symboles predefinis enregistres : ', SymCount);
 End;

 WriteLn('DELPHI: TODO 01 (infrastructure et options) implemente.');
 WriteLn('DELPHI: TODO 02 (lexeur) implemente.');
 WriteLn('DELPHI: TODO 03 (preprocesseur et directives) implemente.');
 WriteLn('DELPHI: TODO 04 (litteraux et constantes) implemente.');
 WriteLn('DELPHI: TODO 05 (table des symboles et portees) implemente.');
 WriteLn('DELPHI: analyseur syntaxique et generateur de code non ',
         'encore implementes (voir TODO 06 et suivants).');
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

